local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local common = require("Qing_Remaster_scripts.cards.oblivion_common")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Oblivion,
	own_key = "Thoth_cd00_Obl_",
	base_desc = nil,
	_hud_desc_state = nil,
	_physical_use_pending = {},
	_physical_overlay_sprite = nil,
	_debug_freeze_physical_progress = false,
	_debug_overlay_frame_override = nil,
}

local STATE_KEY = item.own_key .. "state"

local function ensure_state()
	save.elses[STATE_KEY] = save.elses[STATE_KEY] or {}
	return save.elses[STATE_KEY]
end

local function player_state(player)
	local idx = common.player_index(player)
	if idx == nil then return nil, nil end
	local bag = ensure_state()
	bag[idx] = bag[idx] or {
		physical = {progress = 0},
	}
	local st = bag[idx]
	st.physical = st.physical or {progress = 0}
	st.physical.progress = tonumber(st.physical.progress) or 0
	return st, idx
end

function item.hud_desc_cache()
	item._hud_desc_state = item._hud_desc_state or {
		active = false,
		stage = nil,
		language = nil,
	}
	return item._hud_desc_state
end

function item.capture_base_desc()
	if item.base_desc ~= nil then
		return
	end
	local cfg = common.get_config(item.entity)
	if cfg then
		item.base_desc = cfg.Description or ""
	end
end

function item.peek_player_state(player)
	if not player then
		return nil
	end
	local idx = player:GetData().__Index
	if idx == nil then
		return nil
	end
	local root = save.elses[STATE_KEY]
	if type(root) ~= "table" then
		return nil
	end
	return root[idx]
end

function item.restore_base_desc()
	local cache = item._hud_desc_state
	if not cache or not cache.active then
		return
	end
	item.capture_base_desc()
	local cfg = common.get_config(item.entity)
	if cfg and item.base_desc ~= nil then
		cfg.Description = item.base_desc
	end
	cache.active = false
	cache.stage = nil
	cache.language = nil
end

function item.force_restore_base_desc()
	item.capture_base_desc()
	local cfg = common.get_config(item.entity)
	if cfg and item.base_desc ~= nil then
		cfg.Description = item.base_desc
	end
	local cache = item.hud_desc_cache()
	cache.active = false
	cache.stage = nil
	cache.language = nil
end

-- Physical pocket-card alpha is not modified. Vanilla RenderPocketItem overwrites
-- HUD:GetCardsPillsSprite().Color, so forgetting is an opaque overlay on top.
function item.sync_physical_hud_description()
	item.capture_base_desc()
	local cache = item.hud_desc_cache()
	local player = Game():GetPlayer(0)

	if not player or not common.has_primary_card(player, item.entity) then
		if cache.active then
			item.restore_base_desc()
		end
		return
	end

	local st = item.peek_player_state(player)
	if not st or not st.physical then
		if cache.active then
			item.restore_base_desc()
		end
		return
	end

	local progress = st.physical.progress or 0
	local stage = common.desc_index_for_progress(progress)
	local language = common.desc_language_key()

	if cache.active and cache.stage == stage and cache.language == language then
		return
	end

	local cfg = common.get_config(item.entity)
	if not cfg then
		return
	end

	cfg.Description = common.desc_for_progress(progress)
	cache.active = true
	cache.stage = stage
	cache.language = language
end

function item.remove_primary_physical_card(player)
	if not common.has_primary_card(player, item.entity) then
		return false
	end

	local slot = PillCardSlot and PillCardSlot.PRIMARY or 0
	if player.RemovePocketItem then
		player:RemovePocketItem(slot)
	else
		player:SetCard(0, 0)
	end
	return true
end

function item.complete_physical_instance(player)
	if not item.remove_primary_physical_card(player) then
		return false
	end
	local st = player_state(player)
	if st and st.physical then
		st.physical.progress = 0
	end
	local rng = auxi.rng_for_sake(player:GetCardRNG(item.entity))
	local replacement_count = 1
	if auxi.has_have_coll(player, CollectibleType.COLLECTIBLE_TAROT_CLOTH) then
		replacement_count = 2
	end
	common.execute_forget(player, rng, {replacement_count = replacement_count})
	item.restore_base_desc()
	return true
end

function item.restore_after_manual_use(player, progress)
	if not player then
		return
	end
	local idx = common.player_index(player)
	if idx == nil then
		return
	end
	local kept = math.max(0, math.min(common.FORGET_FRAMES - 1, tonumber(progress) or 0))
	-- POST_UPDATE is 30 Hz. TimeD=1 waits one logic frame so vanilla pocket consume finishes first.
	delay_buffer.addeffe(function()
		if not auxi.check_all_exists(player) then
			return
		end
		if common.has_in_any_card_slot(player, item.entity) then
			return
		end
		player:AddCard(item.entity)
		local st = player_state(player)
		if st and st.physical then
			st.physical.progress = kept
		end
	end, {}, 1)
end

function item.update_player(player)
	if not auxi.check_all_exists(player) then return end
	if common.is_paused() then return end

	local owns_primary = common.has_primary_card(player, item.entity)
	local owns_any = common.has_in_any_card_slot(player, item.entity)
	local existing = item.peek_player_state(player)

	if not owns_any then
		if existing and existing.physical then
			existing.physical.progress = 0
		end
		return
	end

	local st = player_state(player)
	if not st then return end

	if owns_primary then
		if not item._debug_freeze_physical_progress then
			st.physical.progress = (st.physical.progress or 0) + 1
		end
		if st.physical.progress >= common.FORGET_FRAMES then
			item.complete_physical_instance(player)
		end
	end
end

function item.get_physical_overlay_sprite()
	if not item._physical_overlay_sprite then
		local spr = Sprite()
		spr:Load("gfx/ui/oblivion_forget_overlay.anm2", true)
		item._physical_overlay_sprite = spr
	end
	return item._physical_overlay_sprite
end

function item.render_physical_forget_overlay(player)
	if not player then
		return
	end
	if not common.has_primary_card(player, item.entity) then
		return
	end

	local st = item.peek_player_state(player)
	local progress = st and st.physical and st.physical.progress or 0
	local override = item._debug_overlay_frame_override
	if progress <= 0 and override == nil then
		return
	end

	local pos = ui.CardOverlayPos(player, "oblivion")
	if not pos then
		return
	end

	local spr = item.get_physical_overlay_sprite()
	if not spr or not spr:IsLoaded() then
		return
	end

	spr.Scale = Vector(1, 1)
	spr:Play("Forget", true)
	local hud_alpha = slot_render_holder.get_alpha()
	if override ~= nil then
		spr:SetFrame(override)
		spr.Color = Color(1, 1, 1, hud_alpha, 0, 0, 0)
		spr:Render(pos, Vector(0, 0), Vector(0, 0))
		return
	end

	local current, next_frame, blend = common.overlay_blend_for_progress(progress)
	spr:SetFrame(current)
	spr.Color = Color(1, 1, 1, hud_alpha, 0, 0, 0)
	spr:Render(pos, Vector(0, 0), Vector(0, 0))
	if next_frame ~= current and blend > 0 then
		spr:SetFrame(next_frame)
		spr.Color = Color(1, 1, 1, hud_alpha * blend, 0, 0, 0)
		spr:Render(pos, Vector(0, 0), Vector(0, 0))
	end
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		item.capture_base_desc()
		if not continue then
			save.elses[STATE_KEY] = {}
		end
		item._physical_use_pending = {}
		ensure_state()
		item.force_restore_base_desc()
	end,
})

if ModCallbacks.MC_PRE_GAME_EXIT then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
		params = nil,
		Function = function(_)
			item.force_restore_base_desc()
		end,
	})
end

if ModCallbacks.MC_POST_GAME_END then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_GAME_END,
		params = nil,
		Function = function(_)
			item.force_restore_base_desc()
		end,
	})
end

if ModCallbacks.MC_PRE_USE_CARD then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_USE_CARD,
		params = nil,
		Function = function(_, card, player, useFlags)
			if card ~= item.entity then
				return
			end
			if not common.has_primary_card(player, item.entity) then
				return
			end
			local idx = common.player_index(player)
			if idx == nil then
				return
			end
			local st = item.peek_player_state(player)
			item._physical_use_pending[idx] = {
				frame = Game():GetFrameCount(),
				progress = st and st.physical and st.physical.progress or 0,
			}
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = item.entity,
	Function = function(_, cardtype, player, useFlags)
		local idx = common.player_index(player)
		if idx == nil then
			return
		end
		local pending = item._physical_use_pending[idx]
		if not pending then
			return
		end
		local frame = Game():GetFrameCount()
		if math.abs(frame - (pending.frame or frame)) > 1 then
			item._physical_use_pending[idx] = nil
			return
		end
		item._physical_use_pending[idx] = nil
		item.restore_after_manual_use(player, pending.progress or 0)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PEFFECT_UPDATE,
	params = nil,
	Function = function(_, player)
		item.update_player(player)
	end,
})

if ModCallbacks.MC_POST_HUD_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_HUD_RENDER,
		params = nil,
		Function = function(_)
			local hud = Game():GetHUD()
			if hud and hud.IsVisible and not hud:IsVisible() then
				return
			end
			for i = 0, Game():GetNumPlayers() - 1 do
				local player = Game():GetPlayer(i)
				if player then
					item.render_physical_forget_overlay(player)
				end
			end
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function(_)
		item.sync_physical_hud_description()
	end,
})

function item.debug_get_player()
	return Game():GetPlayer(0)
end

function item.debug_get_state(player)
	player = player or Game():GetPlayer(0)
	if not player then
		return nil
	end

	local st = item.peek_player_state(player)
	local primary = common.get_primary_card(player)
	local progress = st and st.physical and st.physical.progress or 0
	local current, next_frame, blend = common.overlay_blend_for_progress(progress)

	return {
		primary_card = primary,
		is_oblivion = primary == item.entity,
		progress = progress,
		ratio = common.FORGET_FRAMES > 0 and progress / common.FORGET_FRAMES or 0,
		overlay_frame = current,
		overlay_next_frame = next_frame,
		overlay_blend = blend,
		desc_stage = common.desc_index_for_progress(progress),
	}
end

function item.debug_set_physical_progress(player, progress)
	player = player or Game():GetPlayer(0)
	if not player then
		return false
	end
	if not common.has_primary_card(player, item.entity) then
		return false
	end

	local st = player_state(player)
	if not st then
		return false
	end

	local value = math.floor(tonumber(progress) or 0)
	local cap = math.max(0, common.FORGET_FRAMES - 1)
	if value < 0 then value = 0 end
	if value > cap then value = cap end
	st.physical.progress = value
	item.sync_physical_hud_description()
	return true
end

function item.debug_set_physical_ratio(player, ratio)
	ratio = math.max(0, math.min(1, tonumber(ratio) or 0))
	return item.debug_set_physical_progress(player, math.floor(ratio * (common.FORGET_FRAMES - 1)))
end

function item.debug_complete_physical(player)
	player = player or Game():GetPlayer(0)
	if not player then
		return false
	end
	if not common.has_primary_card(player, item.entity) then
		return false
	end
	return item.complete_physical_instance(player)
end

function item.debug_reset_physical(player)
	player = player or Game():GetPlayer(0)
	if not player then
		return false
	end
	local st = item.peek_player_state(player)
	if st and st.physical then
		st.physical.progress = 0
	end
	item.restore_base_desc()
	return true
end

function item.debug_step_overlay(player, delta_frames)
	player = player or Game():GetPlayer(0)
	local st = item.peek_player_state(player)
	if not st or not st.physical then
		return false
	end
	local current = st.physical.progress or 0
	return item.debug_set_physical_progress(player, current + (tonumber(delta_frames) or 0))
end

function item.debug_set_freeze_progress(v)
	item._debug_freeze_physical_progress = v == true
end

function item.debug_get_freeze_progress()
	return item._debug_freeze_physical_progress == true
end

function item.debug_set_overlay_frame_override(frame)
	if frame == nil then
		item._debug_overlay_frame_override = nil
		return
	end
	frame = math.max(0, math.min(common.FORGET_OVERLAY_FRAMES - 1, math.floor(frame)))
	item._debug_overlay_frame_override = frame
end

function item.debug_get_overlay_frame_override()
	return item._debug_overlay_frame_override
end

return item

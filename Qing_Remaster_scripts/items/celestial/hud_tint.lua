-- Celestial History Extra HUD tint (via history_hud_render_holder) + physical trinket tint.
-- Extracted from runtime.lua to stay under Lua's 200-local main-chunk limit.
local item_hud_fx = require("Qing_Remaster_scripts.items.celestial.item_hud_fx")
local hud_targets = require("Qing_Remaster_scripts.items.celestial.hud_targets")
local history_hud = require("Qing_Remaster_scripts.callbacks.history_hud_render_holder")

local M = {}

local CONSUMER_NAME = "CelestialStars"

local function tint_for_mode(mode)
	return item_hud_fx.HUD_TINT[mode] or item_hud_fx.HUD_TINT.neutral
end

local function declare_effects_for_player(declare, player_index, effects, effect_is_live)
	for _, eff in pairs(effects) do
		if effect_is_live(eff) then
			if eff.kind == "rahu_block_item" and eff.item_id then
				declare.modifier({
					kind = "collectible",
					player_index = player_index,
					id = eff.item_id,
				}, function(_ctx, visual)
					visual.color = tint_for_mode("purple")
				end)
			elseif eff.kind == "rahu_block_trinket" and eff.trinket_id then
				declare.modifier({
					kind = "trinket",
					player_index = player_index,
					id = select(1, item_hud_fx.split_trinket_id(eff.trinket_id)),
				}, function(_ctx, visual)
					visual.color = tint_for_mode("purple")
				end)
			elseif eff.kind == "ketu_imitate_item" and eff.item_id and not eff.imitate_suppressed then
				local filter = {
					kind = "collectible",
					player_index = player_index,
					id = eff.item_id,
				}
				if eff.history_time ~= nil then
					filter.history_time = eff.history_time
				end
				if eff.history_occurrence ~= nil then
					filter.occurrence = eff.history_occurrence
				end
				declare.modifier(filter, function(_ctx, visual)
					visual.color = tint_for_mode("gold")
				end)
				-- ID-level HideCollectibles restores unmarked siblings via holder fallback.
			elseif eff.kind == "ketu_imitate_trinket" and eff.trinket_id and not eff.imitate_suppressed then
				local base = select(1, item_hud_fx.split_trinket_id(eff.trinket_id))
				local filter = {
					kind = "trinket",
					player_index = player_index,
					id = base,
				}
				if eff.history_time ~= nil then
					filter.history_time = eff.history_time
				end
				if eff.history_occurrence ~= nil then
					filter.occurrence = eff.history_occurrence
				end
				declare.modifier(filter, function(_ctx, visual)
					visual.color = tint_for_mode("gold")
				end)
			end
		end
	end
end

--- Wire HistoryHUD modifiers + physical trinket PRE into `host` (runtime module table).
--- `api` = { player_key, player_state, effect_is_live }
function M.register(host, api)
	if not REPENTOGON or not host or not api then
		return
	end
	host.ToCall = host.ToCall or {}

	history_hud.register_consumer(CONSUMER_NAME, {
		priority = 10,
		collect = function(context, declare)
			local seen = {}
			for i = 1, #context.slots do
				local slot = context.slots[i]
				local pindex = slot.player_index
				if pindex ~= nil and not seen[pindex] then
					seen[pindex] = true
					local player = slot.player
					local pkey = player and api.player_key(player)
					local st = pkey and api.player_state(pkey) or nil
					if st and type(st.effects) == "table" then
						declare_effects_for_player(declare, pindex, st.effects, api.effect_is_live)
					end
				end
			end
		end,
	})

	if ModCallbacks.MC_PRE_PLAYERHUD_TRINKET_RENDER then
		table.insert(host.ToCall, #host.ToCall + 1, {
			CallBack = ModCallbacks.MC_PRE_PLAYERHUD_TRINKET_RENDER,
			params = nil,
			Function = function(_, slot, position, scale, player, _)
				if type(slot) ~= "number" or not position or not player then return end
				local tid = player.GetTrinket and player:GetTrinket(slot) or 0
				hud_targets.note_trinket_render(player, slot, position, scale, tid)
				local base = select(1, item_hud_fx.split_trinket_id(tid))
				if base <= 0 then return end
				local pkey = api.player_key(player)
				if not pkey then return end
				local st = api.player_state(pkey)
				if not st then return end
				local mode = nil
				for _, eff in pairs(st.effects) do
					if api.effect_is_live(eff) then
						local eid = select(1, item_hud_fx.split_trinket_id(eff.trinket_id or 0))
						if eid == base then
							if eff.kind == "rahu_block_trinket" then
								mode = "purple"
								break
							elseif eff.kind == "ketu_imitate_trinket" and not eff.imitate_suppressed then
								if eff.trinket_slot == nil or tonumber(eff.trinket_slot) == slot then
									mode = "gold"
								else
									mode = mode or "neutral"
								end
							end
						end
					end
				end
				if mode then
					item_hud_fx.draw_trinket_hud_icon(tid, position, scale, mode)
					return true
				end
			end,
		})
	end
end

return M

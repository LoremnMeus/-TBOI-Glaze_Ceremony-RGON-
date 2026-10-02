local enums = require("Qing_Remaster_scripts.core.enums")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local C = require("Qing_Remaster_scripts.cards.sting_reversed.constants")
local link_mod = require("Qing_Remaster_scripts.cards.sting_reversed.link")
local blood_mod = require("Qing_Remaster_scripts.cards.sting_reversed.blood")
local visual = require("Qing_Remaster_scripts.cards.sting_reversed.visual")

-- 倒位密仪：独立法阵抓祭品（正位是玩家踩阵献祭）。
-- 玩法/数值不变：Boss 优先、MaxHP 排序、completed * 0.5 易伤（Boss 上限 1.5）、DAMAGE_CLONES。
-- 血球 / 连线仅为视觉；献祭进度只由 NPC death 推进。
-- 法阵为 room-lifetime：无目标 = idle/waiting，仅换房 / 再次用卡 / 显式 teardown 销毁。

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Sting_r,
	own_key = "Thoth_cd5r_Sti_",
}

-- ritual = {
--   owner, anchor, rng,
--   links = { [hash|retract_key] = link },
--   strands = { {anchor_local, curve_seed, sway_phase}, ... },
--   slot_count, active_count, link_count,
--   completed, limit,
--   blood_fill, blood_fill_visual,
-- }
local ritual = nil

local function is_valid_target(npc)
	return npc
		and npc:Exists()
		and not npc:IsDead()
		and npc:IsActiveEnemy(false)
		and npc:IsVulnerableEnemy()
end

local function is_marked(npc)
	if not ritual or not npc then
		return false
	end
	local link = ritual.links[GetPtrHash(npc)]
	return link ~= nil and link.state ~= "retracting"
end

local function find_link_for_npc(npc)
	if not ritual or not npc then
		return nil
	end
	return ritual.links[GetPtrHash(npc)]
end

local function primary_link()
	if not ritual then
		return nil
	end
	for _, link in pairs(ritual.links or {}) do
		if link.state ~= "retracting" and link.target then
			return link
		end
	end
	for _, link in pairs(ritual.links or {}) do
		return link
	end
	return nil
end

--- Read-only ritual / mark snapshot for diagnostics. Does not mutate state.
function item.get_debug_snapshot(npc)
	local snap = {
		active = ritual ~= nil,
		idle = ritual ~= nil and (ritual.link_count or 0) == 0,
		completed = ritual and (ritual.completed or 0) or 0,
		limit = ritual and ritual.limit or 0,
		slot_count = ritual and (ritual.slot_count or 0) or 0,
		active_count = ritual and (ritual.active_count or 0) or 0,
		link_count = ritual and (ritual.link_count or 0) or 0,
		strand_count = ritual and ritual.strands and #ritual.strands or 0,
		marked = false,
		link_state = nil,
		target_hash = nil,
		computed_bonus = 0,
	}
	if not ritual then
		return snap
	end

	local link = nil
	if npc then
		link = find_link_for_npc(npc)
		snap.marked = is_marked(npc)
	else
		link = primary_link()
	end
	if link then
		snap.link_state = link.state
		if link.target and link.target:Exists() then
			snap.target_hash = GetPtrHash(link.target)
		else
			snap.target_hash = link.target_hash
		end
	end

	local bonus = (ritual.completed or 0) * 0.5
	if npc and npc:IsBoss() then
		bonus = math.min(1.5, bonus)
	end
	snap.computed_bonus = bonus
	return snap
end

local function collect_candidates()
	local result = {}
	for _, entity in ipairs(Isaac.GetRoomEntities()) do
		local npc = entity:ToNPC()
		if is_valid_target(npc) and not is_marked(npc) then
			if ritual.links[GetPtrHash(npc)] == nil then
				result[#result + 1] = npc
			end
		end
	end
	table.sort(result, function(a, b)
		if a:IsBoss() ~= b:IsBoss() then
			return a:IsBoss()
		end
		return a.MaxHitPoints > b.MaxHitPoints
	end)
	return result
end

local function finish_ritual()
	if not ritual then
		return
	end
	blood_mod.clear_all()
	if ritual.anchor and ritual.anchor:Exists() then
		ritual.anchor:Remove()
	end
	ritual = nil
end

local function refresh_target_color(npc)
	if not is_valid_target(npc) then
		return
	end
	npc:SetColor(C.TARGET_COLOR, C.COLOR_REFRESH, 90, true, false)
end

local function recount_links()
	if not ritual then
		return
	end
	local slots = 0
	local active = 0
	local total = 0
	for _, link in pairs(ritual.links) do
		total = total + 1
		if link.occupies_slot ~= false then
			slots = slots + 1
		end
		if link.state ~= "retracting" then
			active = active + 1
		end
	end
	ritual.slot_count = slots
	ritual.active_count = active
	ritual.link_count = total
end

local function make_visual_rng(player, cardtype)
	local rng = RNG()
	local seed = 1
	if player and player.GetCardRNG then
		seed = player:GetCardRNG(cardtype):GetSeed()
	end
	seed = math.floor(tonumber(seed) or 1)
	if seed == 0 then
		seed = 1
	end
	rng:SetSeed(seed, 35)
	rng:Next()
	return rng
end

local function mark_target(npc)
	if not ritual or not is_valid_target(npc) or is_marked(npc) then
		return false
	end
	if (ritual.slot_count or 0) >= ritual.limit then
		return false
	end
	local hash = GetPtrHash(npc)
	if ritual.links[hash] then
		return false
	end
	link_mod.ensure_strands(ritual)
	ritual.links[hash] = link_mod.create_link(npc, ritual.rng)
	recount_links()
	refresh_target_color(npc)
	return true
end

local function begin_death_retract(npc)
	if not ritual or not npc then
		return
	end
	local hash = GetPtrHash(npc)
	local link = ritual.links[hash]
	if not link then
		return
	end
	link_mod.begin_retract(link, npc)
	link.occupies_slot = true
	ritual.links[hash] = nil
	local retract_key = "retract_" .. tostring(hash) .. "_" .. tostring(Game():GetFrameCount())
	link.target_hash = nil
	ritual.links[retract_key] = link
	ritual.completed = (ritual.completed or 0) + 1
	if ritual.anchor and ritual.anchor:Exists() then
		ritual.anchor:GetData().pulse = 1
	end
	recount_links()
end

local function tick_links()
	if not ritual then
		return
	end
	local next_links = {}
	local freed = false
	for key, link in pairs(ritual.links) do
		local status = link_mod.tick_link(link, ritual.anchor)
		if status == "gone" or status == "dead" then
			freed = true
		else
			local store_key = key
			if link.target and link.target:Exists() and link.state ~= "retracting" then
				store_key = GetPtrHash(link.target)
				refresh_target_color(link.target)
			end
			next_links[store_key] = link
		end
	end
	ritual.links = next_links
	recount_links()
	if freed then
		-- Unlock new strand roots only after full retract (no mid-retract pop-in).
		link_mod.ensure_strands(ritual)
	end
	return freed
end

local function fill_targets()
	if not ritual then
		return
	end
	if (ritual.slot_count or 0) >= ritual.limit then
		return
	end
	for _, npc in ipairs(collect_candidates()) do
		if (ritual.slot_count or 0) >= ritual.limit then
			break
		end
		mark_target(npc)
	end
	-- link_count == 0 means idle/waiting in this room, not ritual finished.
end

local function spawn_anchor(player)
	local room = Game():GetRoom()
	local anchor = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		enums.Entities.S_Pentagram_Reversed,
		0,
		room:GetCenterPos(),
		Vector.Zero,
		player
	):ToEffect()
	anchor.Velocity = Vector.Zero
	anchor.DepthOffset = -40
	anchor.SortingLayer = 0

	local s = anchor:GetSprite()
	if s:GetAnimation() ~= "Appear" then
		s:Play("Appear", true)
	end
	return anchor
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	params = nil,
	Function = function()
		finish_ritual()
	end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = nil,
	Function = function(_, ent, amount, flags, source, countdown)
		local npc = ent:ToNPC()
		if not npc or not is_marked(npc) then
			return
		end
		if flags & DamageFlag.DAMAGE_CLONES ~= 0 then
			return
		end
		local damage = tonumber(amount) or 0
		if damage <= 0 then
			return
		end

		blood_mod.spawn(ritual, npc, damage)

		local bonus = ritual.completed * 0.5
		if npc:IsBoss() then
			bonus = math.min(1.5, bonus)
		end
		if bonus > 0 then
			local extra = damage * bonus
			local pitch = C.EXTRA_DMG_SFX_PITCH_MIN
			if ritual.rng then
				pitch = C.EXTRA_DMG_SFX_PITCH_MIN
					+ ritual.rng:RandomFloat()
						* (C.EXTRA_DMG_SFX_PITCH_MAX - C.EXTRA_DMG_SFX_PITCH_MIN)
			end
			sound_tracker.PlayStackedSound(
				SoundEffect.SOUND_MEATY_DEATHS,
				C.EXTRA_DMG_SFX_VOL,
				pitch,
				false,
				0,
				2
			)
			npc:SetColor(C.HIT_FLASH_COLOR, C.HIT_FLASH_FRAMES, 80, true, false)
			npc:TakeDamage(
				extra,
				flags | DamageFlag.DAMAGE_CLONES,
				source,
				countdown
			)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_DEATH,
	params = nil,
	Function = function(_, npc)
		if not find_link_for_npc(npc) then
			return
		end
		if not is_marked(npc) then
			return
		end
		local owner = ritual and ritual.owner or nil
		local anchor = ritual and ritual.anchor or nil

		if anchor and anchor:Exists() then
			blood_mod.spawn_death_burst(ritual, npc)
		end

		begin_death_retract(npc)

		local poof = Isaac.Spawn(
			EntityType.ENTITY_EFFECT,
			EffectVariant.POOF01,
			0,
			npc.Position,
			Vector.Zero,
			owner
		):ToEffect()
		if poof then
			poof:SetColor(Color(1, 0.2, 0.2, 1, 0.3, 0, 0), 9999, 90, false, false)
			poof.Color = Color(1, 0.2, 0.2, 1, 0.3, 0, 0)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = item.entity,
	Function = function(_, cardtype, player, useFlags)
		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			return
		end

		finish_ritual()

		local anchor = spawn_anchor(player)
		ritual = {
			owner = player,
			anchor = anchor,
			rng = make_visual_rng(player, cardtype),
			links = {},
			strands = nil,
			slot_count = 0,
			active_count = 0,
			link_count = 0,
			completed = 0,
			limit = (player:GetData().tarot_cloth_used == cardtype) and 2 or 1,
		}
		link_mod.init_strands(ritual)
		visual.init_ritual(ritual)
		fill_targets()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
	params = enums.Entities.S_Pentagram_Reversed,
	Function = function(_, ent)
		if not ritual or GetPtrHash(ent) ~= GetPtrHash(ritual.anchor) then
			return
		end

		ent.Velocity = Vector.Zero
		local s = ent:GetSprite()
		if s:IsFinished("Appear") then
			s:Play("Idle", true)
		end

		visual.update_anchor(ritual, ent)
		local freed = tick_links()
		-- No targets = idle/waiting; keep looking for later spawns. Room exit tears down.
		if freed or (ritual and (ritual.slot_count or 0) < ritual.limit) then
			fill_targets()
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_RENDER,
	params = enums.Entities.S_Pentagram_Reversed,
	Function = function(_, ent, _offset)
		if not ritual or GetPtrHash(ent) ~= GetPtrHash(ritual.anchor) then
			return
		end
		link_mod.render_all(ritual)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
	params = enums.Entities.S_Sting_Reversed_Blood,
	Function = function(_, ent)
		blood_mod.update(ent)
	end,
})

return item

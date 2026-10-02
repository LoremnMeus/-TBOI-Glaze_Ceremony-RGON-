-- Runtime Stitch Native Mixture pair spawn / session owner.
-- v1 does NOT persist pairs through Save & Continue.

local enums = require("Qing_Remaster_scripts.core.enums")
local profiles = require("Qing_Remaster_scripts.config.runtime_stitch_enemy_profiles")
local controller = require("Qing_Remaster_scripts.auxiliary.native_mixture.controller")
local visual_adapter = require("Qing_Remaster_scripts.auxiliary.runtime_stitch_visual_adapter")

local M = {
	ToCall = {},
	post_ToCall = {},
}

local FRIEND_FLAG = controller.FRIEND_FLAG
local PERSIST = EntityFlag.FLAG_PERSISTENT
local TAG_KEY = controller.TAG_KEY

-- Room-local bookkeeping only. No Save & Continue restore.
local next_pair_id = 1
local session_id = 1
local active = {} -- PtrHash -> linker

-- Session-only Debug matrix state (never written to save).
local debug_state = {
	last_movement = nil,
	last_attack = nil,
	next_index = 1,
}

controller.set_visual_detach(function(linker)
	visual_adapter.detach(linker)
	if linker then
		active[GetPtrHash(linker)] = nil
	end
end)

local function linker_variant()
	local v = enums.Entities.Runtime_Stitch_Linker
	if v and v >= 0 then
		return v
	end
	return enums.Entities.Runtime_Stitch_Friend
end

local function owner_index_of(player)
	if not player then
		return 0
	end
	local d = player:GetData()
	if d and d.__Index ~= nil then
		return tonumber(d.__Index) or 0
	end
	return player.ControllerIndex or 0
end

local function spawn_npc(src, pos, spawner)
	if not src or src.type == nil then
		return nil
	end
	local ent = Isaac.Spawn(src.type, src.variant or 0, src.subtype or 0, pos, Vector(0, 0), spawner)
	return ent and ent:ToNPC() or nil
end

local function safe_remove(ent)
	if ent and ent.Exists and ent:Exists() then
		ent:ClearEntityFlags(FRIEND_FLAG | PERSIST)
		ent:Remove()
	end
end

local function copy_mixture(src)
	if type(src) ~= "table" then
		return {}
	end
	local out = {}
	for k, v in pairs(src) do
		out[k] = v
	end
	return out
end

local function has_suture_tag(ent)
	local tag = controller.get_tag(ent)
	return tag ~= nil and tag.session_id ~= nil
end

function M.clear_all_pairs(reason)
	reason = reason or "manual_cleanup"
	local room_ents = Isaac.GetRoomEntities()
	for i = 1, #room_ents do
		local e = room_ents[i]
		if controller.is_linker(e) and controller.get_effect(e) then
			-- destroy_pair detaches visual via set_visual_detach hook
			controller.destroy_pair(e, reason)
		elseif has_suture_tag(e) and controller.is_linkee(e) then
			-- Orphan linkee without live effect: release then remove.
			e:GetData()[TAG_KEY] = nil
			safe_remove(e)
		end
	end
	active = {}
end

function M.spawn_pair(player, move_id, attack_id)
	if not player then
		return nil
	end
	local move_p = profiles.get_movement(move_id)
	local atk_p = profiles.get_attack(attack_id)
	if not move_p or not atk_p then
		return nil
	end
	local variant = linker_variant()
	if not variant or variant < 0 then
		return nil
	end

	local spawned = {}
	local function fail()
		for i = 1, #spawned do
			safe_remove(spawned[i])
		end
		return nil
	end

	local pos = player.Position
	local left = spawn_npc(move_p.source, pos + Vector(-12, 0), player)
	if not left then
		return fail()
	end
	spawned[#spawned + 1] = left

	local right = spawn_npc(atk_p.source, pos + Vector(12, 0), player)
	if not right then
		return fail()
	end
	spawned[#spawned + 1] = right

	local linker_ent = Isaac.Spawn(996, variant, 0, pos, Vector(0, 0), player)
	local linker = linker_ent and linker_ent:ToNPC()
	if not linker then
		return fail()
	end
	spawned[#spawned + 1] = linker

	local pair_id = next_pair_id
	next_pair_id = next_pair_id + 1
	local owner_index = owner_index_of(player)

	local ok = controller.bind_pair(
		linker,
		left,
		right,
		copy_mixture(move_p.mixture),
		copy_mixture(atk_p.mixture),
		{
			pair_id = pair_id,
			session_id = session_id,
			owner_index = owner_index,
			friendly = true,
			initial_tg = "Left",
			hp_policy = {
				main_weight = 1,
				secondary_weight = 0,
				level_scale = 1,
			},
			left_profile = move_p,
			left_profile_kind = "movement",
			right_profile = atk_p,
			right_profile_kind = "attack",
		}
	)
	if not ok then
		return fail()
	end

	local effect = controller.get_effect(linker)
	if effect then
		effect.Left.geometry_prior = move_p.geometry_prior
		effect.Right.geometry_prior = atk_p.geometry_prior
		effect.Left.visual = move_p.visual
		effect.Right.visual = atk_p.visual
		effect.move_id = move_id
		effect.attack_id = attack_id
	end

	local vok = visual_adapter.attach(linker)
	if not vok then
		controller.destroy_pair(linker, "spawn_rollback")
		return nil
	end

	local flags = FRIEND_FLAG | PERSIST
	linker:AddEntityFlags(flags)
	left:AddEntityFlags(flags)
	right:AddEntityFlags(flags)

	active[GetPtrHash(linker)] = linker
	return linker
end

function M.get_debug_state()
	return {
		last_movement = debug_state.last_movement,
		last_attack = debug_state.last_attack,
		next_index = debug_state.next_index,
	}
end

--- Debug matrix: spawn without selection / charge. Clears existing pairs first.
function M.debug_spawn_combo(move_id, attack_id, opts)
	opts = opts or {}
	local player = opts.player or Isaac.GetPlayer(0)
	if not player then
		return nil
	end
	if opts.clear ~= false then
		M.clear_all_pairs("manual_cleanup")
	end
	local linker = M.spawn_pair(player, move_id, attack_id)
	if linker then
		debug_state.last_movement = move_id
		debug_state.last_attack = attack_id
		local moves = profiles.list_movement_ids()
		local attacks = profiles.list_attack_ids()
		local idx = 1
		for mi = 1, #moves do
			for ai = 1, #attacks do
				if moves[mi] == move_id and attacks[ai] == attack_id then
					debug_state.next_index = idx + 1
					if debug_state.next_index > (#moves * #attacks) then
						debug_state.next_index = 1
					end
					return linker
				end
				idx = idx + 1
			end
		end
	end
	return linker
end

function M.debug_respawn_last(opts)
	if not debug_state.last_movement or not debug_state.last_attack then
		return nil
	end
	return M.debug_spawn_combo(debug_state.last_movement, debug_state.last_attack, opts)
end

function M.debug_spawn_next(opts)
	local moves = profiles.list_movement_ids()
	local attacks = profiles.list_attack_ids()
	local total = #moves * #attacks
	if total <= 0 then
		return nil
	end
	local idx = debug_state.next_index or 1
	if idx < 1 or idx > total then
		idx = 1
	end
	local zero = idx - 1
	local mi = math.floor(zero / #attacks) + 1
	local ai = (zero % #attacks) + 1
	return M.debug_spawn_combo(moves[mi], attacks[ai], opts)
end

function M.invalidate_all_geometry(reason)
	reason = reason or "charm_filter_toggle"
	local splice = require("Qing_Remaster_scripts.auxiliary.sprite_splice")
	for _, linker in pairs(active) do
		if linker and linker.Exists and linker:Exists() then
			local data = linker:GetData()
			local vis = data and data.Qing_NativeMixture_Visual
			local pair = vis and vis.pair
			if pair and splice.invalidate_geometry then
				splice.invalidate_geometry(pair, reason)
			end
		end
	end
end

function M.get_pair_summaries()
	local out = {}
	for _, ent in pairs(active) do
		if ent and ent:Exists() and not ent:IsDead() then
			local effect = controller.get_effect(ent)
			if effect then
				local d = ent:GetData()
				local function side_sum(slot, side)
					if not slot or not slot.ent or not slot.ent:Exists() then
						local life = controller.get_side_lifecycle_diag
							and controller.get_side_lifecycle_diag(slot, ent, side)
						return {
							state = -1,
							anim = "",
							order_raw = nil,
							order = nil,
							exists = false,
							tagged = false,
							main = slot and slot.main or nil,
							lifecycle = life,
						}
					end
					local info = slot.info or {}
					local spr = slot.ent:GetSprite()
					local tag = controller.get_tag(slot.ent)
					local phys_snap = controller.read_physical_snapshot(slot.ent)
					local life = controller.get_side_lifecycle_diag
						and controller.get_side_lifecycle_diag(slot, ent, side)
					return {
						type = slot.ent.Type,
						variant = slot.ent.Variant,
						subtype = slot.ent.SubType,
						ptr = GetPtrHash(slot.ent),
						state = slot.ent.State,
						state_frame = slot.ent.StateFrame,
						anim = spr:GetAnimation(),
						frame = spr:GetFrame(),
						overlay = spr.GetOverlayAnimation and spr:GetOverlayAnimation() or "",
						overlay_frame = spr.GetOverlayFrame and spr:GetOverlayFrame() or -1,
						order_raw = controller.resolve_order(info.order, slot.ent, side, info),
						order = controller.get_order(info.order, slot.ent, side, info, true),
						size = slot.ent.Size,
						mass = slot.ent.Mass,
						collision_damage = slot.ent.CollisionDamage,
						shadow_size = phys_snap and phys_snap.shadow_size,
						grid_collision = slot.ent.GridCollisionClass,
						entity_collision = slot.ent.EntityCollisionClass,
						hp = slot.ent.HitPoints,
						max_hp = slot.ent.MaxHitPoints,
						po_y = slot.ent.PositionOffset and slot.ent.PositionOffset.Y or 0,
						exists = true,
						tagged = tag ~= nil and tag.side ~= nil,
						main = slot.main == true,
						visible = slot.ent.Visible ~= false,
						friendly = slot.ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == true,
						charm = slot.ent:HasEntityFlags(EntityFlag.FLAG_CHARM) == true,
						lifecycle = life,
						profile_id = slot.profile_id,
						mixture_group = slot.mixture_group,
						mixture_id = slot.mixture_id,
						rematch_count = slot.rematch_count,
						protected = slot.protected,
					}
				end
				local vis = visual_adapter.get_diagnostics(ent)
				local presentation = visual_adapter.get_presentation_diag
					and visual_adapter.get_presentation_diag(ent)
				local mortal = ent.HasMortalDamage and ent:HasMortalDamage() or false
				local phys = controller.get_physical_diagnostics(ent, effect)
				local linker_life = controller.get_linker_lifecycle_diag
					and controller.get_linker_lifecycle_diag(ent)
				local physics_probe = controller.get_physics_probe_diag
					and controller.get_physics_probe_diag(ent, effect)
				out[#out + 1] = {
					pair_id = effect.pair_id,
					session_id = effect.session_id,
					move = effect.move_id,
					attack = effect.attack_id,
					base_tg = effect.baseinfo and effect.baseinfo.tg,
					presentation = presentation or (vis and vis.presentation),
					physical_owner = (phys and phys.physical_owner) or effect.physical_owner or "Left",
					physical = phys,
					physics_probe = physics_probe,
					hp_main_left = effect.Left and effect.Left.main == true,
					hp_main_right = effect.Right and effect.Right.main == true,
					destroying = effect.destroying == true,
					destroy_reason = effect.destroy_reason,
					swap_counter = d[controller.OWN_KEY .. "swap_counter"],
					tg_swap_last_frame = d[controller.OWN_KEY .. "tg_swap_last_frame"],
					swap_vel_blend = d[controller.OWN_KEY .. "swap_vel_blend"] ~= nil,
					Left = side_sum(effect.Left, "Left"),
					Right = side_sum(effect.Right, "Right"),
					linker_hp = ent.HitPoints,
					linker_max_hp = ent.MaxHitPoints,
					linker_size = ent.Size,
					linker_mass = ent.Mass,
					linker_grid = ent.GridCollisionClass,
					linker_entcoll = ent.EntityCollisionClass,
					linker_coldmg = ent.CollisionDamage,
					linker_shadow = phys and phys.Linker and phys.Linker.shadow_size,
					linker_dead = ent:IsDead(),
					linker_mortal = mortal,
					linker_friendly = ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == true,
					linker_charm = ent:HasEntityFlags(EntityFlag.FLAG_CHARM) == true,
					linker_lifecycle = linker_life,
					mortal_probe_active = linker_life and linker_life.mortal_probe_active,
					health_needs_rebuild = effect.health_needs_rebuild == true,
					effect_present = true,
					live_registered = true,
					visual = vis,
					alive = true,
				}
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.pair_id or 0) < (b.pair_id or 0)
	end)
	return out
end

function M.count_pairs()
	local n = 0
	for _, ent in pairs(active) do
		if ent and ent:Exists() and controller.get_effect(ent) then
			n = n + 1
		end
	end
	return n
end

do
	local function append_calls(dst, src)
		if not src then
			return
		end
		for i = 1, #src do
			dst[#dst + 1] = src[i]
		end
	end
	append_calls(M.ToCall, controller.ToCall)
	append_calls(M.post_ToCall, controller.post_ToCall)
	append_calls(M.ToCall, visual_adapter.ToCall)
	append_calls(M.post_ToCall, visual_adapter.post_ToCall)
	for i = #controller.ToCall, 1, -1 do
		controller.ToCall[i] = nil
	end
	if controller.post_ToCall then
		for i = #controller.post_ToCall, 1, -1 do
			controller.post_ToCall[i] = nil
		end
	end
	for i = #visual_adapter.ToCall, 1, -1 do
		visual_adapter.ToCall[i] = nil
	end
	if visual_adapter.post_ToCall then
		for i = #visual_adapter.post_ToCall, 1, -1 do
			visual_adapter.post_ToCall[i] = nil
		end
	end
end

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function(_, _continued)
		-- v1: never restore pairs (including Continue).
		session_id = session_id + 1
		active = {}
		M.clear_all_pairs("new_run_cleanup")
		next_pair_id = 1
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function(_)
		M.clear_all_pairs("manual_cleanup")
		active = {}
		next_pair_id = 1
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		-- Rebuild room-local active index only. Persistent linkers keep VISUAL_KEY
		-- pair/RT/solution; render_linker already refreshes host/donor userdata.
		-- Unconditional attach() was destroying + force-capturing every room entry.
		active = {}
		local reused = 0
		local reattached = 0
		local room_ents = Isaac.GetRoomEntities()
		for i = 1, #room_ents do
			local e = room_ents[i]
			if controller.is_linker(e) and controller.get_effect(e) then
				active[GetPtrHash(e)] = e
				if visual_adapter.prepare(e) then
					if visual_adapter.rebind then
						visual_adapter.rebind(e)
					end
					reused = reused + 1
					if visual_adapter.note_room_reused_visual then
						visual_adapter.note_room_reused_visual()
					end
				else
					visual_adapter.attach(e)
					reattached = reattached + 1
					if visual_adapter.note_room_reattached_visual then
						visual_adapter.note_room_reattached_visual()
					end
				end
			end
		end
		if visual_adapter.note_room_transition then
			visual_adapter.note_room_transition(reused, reattached)
		end
	end,
})

return M

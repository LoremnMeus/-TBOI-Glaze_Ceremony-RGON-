-- Native Mixture Pair behavioral coordinator.
-- Contract: Mixturer Base C + native A/B coordination only.
-- Visual: never here (sprite_splice via runtime_stitch_visual_adapter).
-- No gfx/output, no handmade enemy AI.

local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local enums = require("Qing_Remaster_scripts.core.enums")
local catalog = require("Qing_Remaster_scripts.auxiliary.native_mixture.catalog")

local M = {
	ToCall = {},
	post_ToCall = {},
}

local OWN_KEY = "Qing_NativeMixture_"
local TAG_KEY = "QingSutureNativePair"
local SIDES = { "Left", "Right" }
-- Friendly AI requires CHARM as well as FRIENDLY (CHARM-only hearts are stripped
-- at Runtime Stitch pixel layer; do not Clear/Add flags around Entity:Render).
local FRIEND_FLAG = EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_CHARM
local LINKER_TYPE = 996
-- Temporary neutral Effect used only as TakeDamage Source for native death probes.
-- Must NOT be FRIENDLY|CHARM (linker/linkee are); must NOT be the player.
local NATIVE_DEATH_SOURCE_KEY = OWN_KEY .. "NativeDeathSource"

--- Permanent physical body owner for the linker (Size/Mass/Shadow/…).
--- Distinct from baseinfo.tg (current motion controller), which may swap.
local PHYSICAL_OWNER_SIDE = "Left"

-- Physics diagnostics: default OFF. Suture probe enables when active.
local physics_probe_enabled = false

-- Formal protect_self lethal Source. Default keeps current MeusNil marker path.
-- "legacy_linker" = old Stitch EntityRef(linker) + cooldown 666.
local native_death_source_mode = "current_meusnil"
-- MeusNil-only A/B: cooldown 0 (current) vs 666 (old linkee whitelist value).
local native_death_meusnil_cooldown = 0

function M.set_physics_probe_enabled(on)
	physics_probe_enabled = on == true
end

function M.is_physics_probe_enabled()
	return physics_probe_enabled == true
end

function M.set_native_death_source_mode(mode)
	if mode == "legacy_linker" then
		native_death_source_mode = "legacy_linker"
	else
		native_death_source_mode = "current_meusnil"
	end
	return native_death_source_mode
end

function M.get_native_death_source_mode()
	return native_death_source_mode
end

function M.set_native_death_meusnil_cooldown(cooldown)
	if tonumber(cooldown) == 666 then
		native_death_meusnil_cooldown = 666
	else
		native_death_meusnil_cooldown = 0
	end
	return native_death_meusnil_cooldown
end

function M.get_native_death_meusnil_cooldown()
	return native_death_meusnil_cooldown
end


local function physical_owner_slot(effect)
	if not effect then
		return nil, PHYSICAL_OWNER_SIDE
	end
	local name = effect.physical_owner or PHYSICAL_OWNER_SIDE
	return effect[name], name
end

local function read_shadow_size(ent)
	if not ent or not ent.GetShadowSize then
		return nil
	end
	local ok, v = pcall(function()
		return ent:GetShadowSize()
	end)
	if ok then
		return tonumber(v)
	end
	return nil
end

local function apply_shadow_size(ent, size)
	if not ent or not ent.SetShadowSize or size == nil then
		return false
	end
	local ok = pcall(function()
		ent:SetShadowSize(size)
	end)
	return ok == true
end

--- Snapshot physical fields for probes / equality checks.
function M.read_physical_snapshot(ent)
	if not auxi.check_exists(ent) then
		return nil
	end
	return {
		size = tonumber(ent.Size),
		mass = tonumber(ent.Mass),
		collision_damage = tonumber(ent.CollisionDamage),
		shadow_size = read_shadow_size(ent),
		grid_collision = ent.GridCollisionClass,
		entity_collision = ent.EntityCollisionClass,
	}
end

-- apply_physical_owner_defaults defined after side_alive()

-- Explicit contract: supported=true must have a real consumer; false = validator rejects.
M.CAPABILITIES = {
	order = true,
	rnds = true,
	rnds_add = true,
	on_swap = true,
	naturally_move_back = true,
	Reset_counter = true,
	prevent_velocity = true,
	AddVelocity = true,
	HelpVelocity = true,
	delta_pos = true,
	follow_gridcollision = true,
	check_collisionclass = true,
	CollisionDamage = true,
	SetMass = true,
	protect_pos = true,
	KeepTarget = true,
	KeepTarget_Special = true,
	special = true,
	special_on_own_update = true,
	special_damage = true,
	special_damage_over = true,
	on_damage = true,
	shared_link_hp = true, -- pair-local sync (linker + sides); multipart collector deferred
	special_collision = true,
	spawned_projectile_link = true,
	spawned_bomb_link = true,
	catch_laser = false,
	Catch_Laser = false,
	protect_self = true,
	protect_time = true,
	-- Same userdata Morph: rematch Extra_Mixture entry by current TVS (Stitch Edition).
	check_all_type = true,
	special_on_uncheck = true,
	on_death = true,
	on_kill = true,
	should_release = true,
	NoKill = true,
	protect_flip = true,
	protect_flipY = true,
	AutoRegen = true,
	HitPoints = true,
	InitTarget = false,
	-- Known Extra fields not yet consumed by Runtime Stitch (compat audit / TODO):
	-- release_self, Killnow, kill_self, Recheck/DealwithRecheck, full multipart shared_link_hp.
}

	-- Non-runtime / visual-only / profile-helper keys (not Mixture controller hooks).
M.NON_RUNTIME_METADATA = {
	CoverDetail = true,
	level = true,
	strength = true,
	alt = true,
	-- Extra_Mixture inheritance pointer (catalog.resolve consumes; controller does not).
	check = true,
	uid = true,
	group = true,
	id = true,
	type = true,
	variant = true,
	subtype = true,
	name = true,
	attrs = true,
	tg_layer = true,
	source_mixture_entry = true,
	anm2 = true,
	anm2_name = true,
	-- Profile-local helpers invoked from special / on_* (not controller-owned hooks).
	force_move = true,
	-- Tag/slot metadata (release path), not controller capability hooks.
	non_danger = true,
	-- Known Extra visual/reload/offset metadata not consumed by Runtime Stitch yet.
	-- (Do not invent controller behavior for these; catalog soft-audit only.)
	no_overlay = true,
	-- Appear is always cleared on bind for Linker + sides; Extra flag is catalog-only.
	no_appear_flag = true,
	reload = true,
	swap_weight = true,
	-- Deferred / unsupported Extra lifecycle fields (do not invent behavior).
	release_self = true,
	Killnow = true,
	kill_self = true,
	Recheck = true,
	DealwithRecheck = true,
}

local swap_move_info = {
	{ frame = 0, val = 1 },
	{ frame = 15, val = 0 },
}
local tg_swap_min_interval_frames = 90
local tg_swap_cooldown_order_threshold = 0.5
local grid_collision_val_map = {
	[0] = 10,
	[1] = 8,
	[2] = 8,
	[3] = 8,
	[4] = -4,
	[5] = 0,
	[6] = 4,
	[7] = -8,
}
local velocity_punishment = {
	{ frame = 0, val = 0 },
	{ frame = 30, val = 0 },
	{ frame = 60, val = -0.25 },
	{ frame = 90, val = -1 },
	{ frame = 150, val = -1.5 },
	{ frame = 300, val = -3 },
	{ frame = 600, val = -5 },
}
local velocity_punishment2 = {
	{ frame = 0, val = 0 },
	{ frame = 30, val = 0 },
	{ frame = 60, val = -0.25 },
	{ frame = 90, val = -1 },
	{ frame = 150, val = -2 },
	{ frame = 300, val = -5 },
	{ frame = 600, val = -10 },
}

M.OWN_KEY = OWN_KEY
M.TAG_KEY = TAG_KEY
M.SIDES = SIDES
M.FRIEND_FLAG = FRIEND_FLAG
M.PHYSICAL_OWNER_SIDE = PHYSICAL_OWNER_SIDE

--- Compare Left vs linker physical fields for probes (default profiles expect match).
function M.get_physical_diagnostics(linker, effect)
	effect = effect or (linker and M.get_effect(linker))
	if not linker or not effect then
		return nil
	end
	local phys_slot, phys_name = physical_owner_slot(effect)
	local left_snap = M.read_physical_snapshot(phys_slot and phys_slot.ent)
	local linker_snap = M.read_physical_snapshot(linker)
	local eq = {}
	if left_snap and linker_snap then
		eq.size = left_snap.size == linker_snap.size
		eq.mass = left_snap.mass == linker_snap.mass
		eq.collision_damage = left_snap.collision_damage == linker_snap.collision_damage
		eq.shadow_size = left_snap.shadow_size == linker_snap.shadow_size
			or (left_snap.shadow_size == nil and linker_snap.shadow_size == nil)
		eq.grid_collision = left_snap.grid_collision == linker_snap.grid_collision
		eq.entity_collision = left_snap.entity_collision == linker_snap.entity_collision
	end
	return {
		physical_owner = phys_name or PHYSICAL_OWNER_SIDE,
		motion_tg = effect.baseinfo and effect.baseinfo.tg,
		Left = left_snap,
		Linker = linker_snap,
		equal = eq,
	}
end

local PHYSICS_RING_MAX = 120

local function vec_xy(v)
	if not v then
		return nil
	end
	return { x = v.X, y = v.Y }
end

local function side_physics_snap(slot)
	if not slot or not auxi.check_exists(slot.ent) then
		return nil
	end
	local ent = slot.ent
	return {
		ptr = GetPtrHash(ent),
		position = vec_xy(ent.Position),
		velocity = vec_xy(ent.Velocity),
		mass = tonumber(ent.Mass),
		size = tonumber(ent.Size),
		entity_collision_class = ent.EntityCollisionClass,
		grid_collision_class = ent.GridCollisionClass,
	}
end

local function push_physics_ring(effect, sample)
	if not effect or not sample then
		return
	end
	effect.physics_ring = effect.physics_ring or {}
	local ring = effect.physics_ring
	ring[#ring + 1] = sample
	while #ring > PHYSICS_RING_MAX do
		table.remove(ring, 1)
	end
end

local function record_controller_physics_write(linker, effect, desired_pos, desired_vel, pre)
	if not linker or not effect then
		return
	end
	local snap_dist = nil
	if pre and pre.position and desired_pos then
		snap_dist = (desired_pos - pre.position):Length()
	end
	local vel_delta = nil
	if pre and pre.velocity and desired_vel then
		vel_delta = (desired_vel - pre.velocity):Length()
	end
	effect.physics_trace = {
		frame = Game():GetFrameCount(),
		pre_controller_position = pre and vec_xy(pre.position),
		pre_controller_velocity = pre and vec_xy(pre.velocity),
		pre_mass = pre and pre.mass,
		pre_size = pre and pre.size,
		desired_position_from_tg = vec_xy(desired_pos),
		desired_velocity_from_tg = vec_xy(desired_vel),
		post_controller_position = vec_xy(linker.Position),
		post_controller_velocity = vec_xy(linker.Velocity),
		post_mass = tonumber(linker.Mass),
		post_size = tonumber(linker.Size),
		position_snap_distance = snap_dist,
		velocity_override_delta = vel_delta,
	}
end

local function sample_physics_frame(linker, effect)
	if not physics_probe_enabled then
		return
	end
	if not linker or not effect then
		return
	end
	local tgname = effect.baseinfo and effect.baseinfo.tg
	local tg = tgname and effect[tgname]
	local tg_ent = tg and tg.ent
	local phys_name = effect.physical_owner or PHYSICAL_OWNER_SIDE
	local linker_pos = linker.Position
	local tg_pos = tg_ent and tg_ent.Position
	local linker_vel = linker.Velocity
	local tg_vel = tg_ent and tg_ent.Velocity
	local probe = effect.mortal_probe
	local left_slot = effect.Left
	local right_slot = effect.Right
	local sample = {
		frame = Game():GetFrameCount(),
		collision = effect.physics_collision_pending == true,
		base = {
			ptr = GetPtrHash(linker),
			position = vec_xy(linker_pos),
			velocity = vec_xy(linker_vel),
			mass = tonumber(linker.Mass),
			size = tonumber(linker.Size),
			collision_damage = tonumber(linker.CollisionDamage),
			entity_collision_class = linker.EntityCollisionClass,
			grid_collision_class = linker.GridCollisionClass,
			physical_owner = phys_name,
			motion_tg = tgname,
			tg_position = vec_xy(tg_pos),
			tg_velocity = vec_xy(tg_vel),
			position_error = tg_pos and vec_xy(linker_pos - tg_pos) or nil,
			velocity_error = tg_vel and vec_xy(linker_vel - tg_vel) or nil,
			position_error_len = tg_pos and (linker_pos - tg_pos):Length() or nil,
			velocity_error_len = tg_vel and (linker_vel - tg_vel):Length() or nil,
		},
		lifecycle = {
			linker_hp = tonumber(linker.HitPoints),
			linker_max_hp = tonumber(linker.MaxHitPoints),
			linker_mortal = linker.HasMortalDamage and linker:HasMortalDamage() or false,
			linker_dead = linker.IsDead and linker:IsDead() or false,
			mortal_probe_active = probe and probe.active == true or false,
		hp_write_log = effect and effect.hp_write_log or nil,
		mortal_invariants = probe and probe.invariants or nil,
			native_lethal_sent = probe and probe.native_lethal_sent == true or false,
			base_rescued = probe and probe.base_rescued == true or false,
			transition_confirmed = probe and probe.transition_confirmed == true or false,
			Left_tvs = left_slot and left_slot.ent and {
				type = left_slot.ent.Type,
				variant = left_slot.ent.Variant,
				subtype = left_slot.ent.SubType,
			} or nil,
			Left_rematch_count = left_slot and left_slot.rematch_count or nil,
			Right_tvs = right_slot and right_slot.ent and {
				type = right_slot.ent.Type,
				variant = right_slot.ent.Variant,
				subtype = right_slot.ent.SubType,
			} or nil,
			Right_rematch_count = right_slot and right_slot.rematch_count or nil,
		},
		Left = side_physics_snap(effect.Left),
		Right = side_physics_snap(effect.Right),
		controller_write = effect.physics_trace,
		last_collision = effect.physics_last_collision,
	}
	push_physics_ring(effect, sample)
	effect.physics_collision_pending = nil
	effect.physics_last_sample = sample
end

local function record_linker_npc_collision(linker, col)
	if not physics_probe_enabled then
		return
	end
	if not linker or not col or not auxi.check_exists(col) then
		return
	end
	if M.is_linker(col) or M.is_linkee(col) then
		return
	end
	local effect = M.get_effect(linker)
	if not effect then
		return
	end
	local delta = col.Position - linker.Position
	local distance = delta:Length()
	local normal = distance > 0.0001 and delta:Normalized() or Vector(0, 0)
	local rel = linker.Velocity - col.Velocity
	local expected = (tonumber(linker.Size) or 0) + (tonumber(col.Size) or 0)
	local penetration = expected - distance
	local n_speed = rel:Dot(normal)
	local tangent = Vector(-normal.Y, normal.X)
	local t_speed = rel:Dot(tangent)
	effect.physics_last_collision = {
		frame = Game():GetFrameCount(),
		other_ptr = GetPtrHash(col),
		other_type = col.Type,
		other_variant = col.Variant,
		other_subtype = col.SubType,
		linker_pos = vec_xy(linker.Position),
		other_pos = vec_xy(col.Position),
		delta = vec_xy(delta),
		distance = distance,
		expected_separation = expected,
		penetration = penetration,
		linker_velocity = vec_xy(linker.Velocity),
		other_velocity = vec_xy(col.Velocity),
		linker_mass = tonumber(linker.Mass),
		other_mass = tonumber(col.Mass),
		linker_size = tonumber(linker.Size),
		other_size = tonumber(col.Size),
		relative_velocity = vec_xy(rel),
		collision_normal = vec_xy(normal),
		normal_relative_speed = n_speed,
		tangent_relative_speed = t_speed,
	}
	effect.physics_collision_pending = true
end

--- opts.include_ring=true for dedicated Physics Trace export only.
--- Default summaries omit the 120-frame ring (keeps diagnosis clipboard small).
function M.get_physics_probe_diag(linker, effect, opts)
	opts = opts or {}
	effect = effect or (linker and M.get_effect(linker))
	if not effect then
		return nil
	end
	local out = {
		last_sample = effect.physics_last_sample,
		last_controller_write = effect.physics_trace,
		last_collision = effect.physics_last_collision,
		ring_len = effect.physics_ring and #effect.physics_ring or 0,
	}
	if opts.include_ring == true then
		out.ring = effect.physics_ring
	end
	return out
end


-- PtrHash(linker) → { linker, effect }. Survives GetData teardown for REMOVE orphan cleanup.
local live_pairs = {}

-- Optional visual detach (set by runtime_stitch_pair to avoid require cycles).
local visual_detach_fn = nil

function M.set_visual_detach(fn)
	visual_detach_fn = fn
end

function M.peek_live_pair(ptr)
	return live_pairs[ptr]
end

function M.iter_live_pairs()
	return pairs(live_pairs)
end

local function register_live_pair(linker, effect)
	if not linker or not effect then
		return
	end
	live_pairs[GetPtrHash(linker)] = {
		linker = linker,
		effect = effect,
	}
end

local function unregister_live_pair(linker)
	if not linker then
		return
	end
	live_pairs[GetPtrHash(linker)] = nil
end

local function linker_variant()
	local v = enums.Entities.Runtime_Stitch_Linker
	if v and v >= 0 then
		return v
	end
	return enums.Entities.Runtime_Stitch_Friend
end

function M.has_friend_flag(flags, flag2)
	if flag2 == nil then
		flag2 = FRIEND_FLAG
	end
	if flags == nil then
		return false
	end
	return flags & flag2 == flag2
end

function M.is_linker(ent)
	if not ent or ent.Type ~= LINKER_TYPE then
		return false
	end
	local v = linker_variant()
	if not v or v < 0 then
		return false
	end
	return ent.Variant == v
end

function M.get_effect(linker)
	if not linker then
		return nil
	end
	local d = linker:GetData()
	return d and d[OWN_KEY .. "effect"] or nil
end

function M.get_tag(ent)
	if not ent then
		return nil
	end
	local d = ent:GetData()
	return d and d[TAG_KEY] or nil
end

function M.is_linkee(ent)
	local tag = M.get_tag(ent)
	return tag ~= nil and tag.side ~= nil and not M.is_linker(ent)
end

--- linker for a Runtime Stitch participant.
--- linkee → its linker; linker → itself; unrelated → nil.
function M.get_linker_for(ent)
	if not auxi.check_exists(ent) then
		return nil
	end
	if M.is_linker(ent) then
		return ent
	end
	local tag = M.get_tag(ent)
	if tag and auxi.check_exists(tag.linker) then
		return tag.linker
	end
	return nil
end

--- Other side ents in the same Runtime Stitch pair (excludes `ent` itself).
function M.get_sibling_linkees(ent)
	local out = {}
	if not auxi.check_exists(ent) then
		return out
	end
	local linker = M.get_linker_for(ent)
	if not linker then
		return out
	end
	local effect = M.get_effect(linker)
	if not effect then
		return out
	end
	for _, side in ipairs(SIDES) do
		local slot = effect[side]
		if slot and auxi.check_exists(slot.ent) and auxi.check_for_the_same(slot.ent, ent) ~= true then
			out[#out + 1] = slot.ent
		end
	end
	return out
end

--- Neighbor entities for Parent_Collect_holder.search_for_linkage.
--- linker → Left/Right ents; linkee → linker + sibling side.
function M.get_linkage_neighbors(ent)
	local out = {}
	if not auxi.check_exists(ent) then
		return out
	end
	if M.is_linker(ent) then
		local effect = M.get_effect(ent)
		if effect then
			for _, side in ipairs(SIDES) do
				local slot = effect[side]
				if slot and auxi.check_exists(slot.ent) then
					out[#out + 1] = slot.ent
				end
			end
		end
		return out
	end
	local tag = M.get_tag(ent)
	if not tag or not tag.side then
		return out
	end
	local linker = tag.linker
	if auxi.check_exists(linker) then
		out[#out + 1] = linker
		local effect = M.get_effect(linker)
		if effect then
			for _, side in ipairs(SIDES) do
				if side ~= tag.side then
					local slot = effect[side]
					if slot and auxi.check_exists(slot.ent) then
						out[#out + 1] = slot.ent
					end
				end
			end
		end
	end
	return out
end

function M.elect_grid_collision(val1, val2)
	local v1 = grid_collision_val_map[val1] or 0
	local v2 = grid_collision_val_map[val2] or 0
	if v1 < v2 then
		return val2
	end
	return val1
end

--- Resolve order descriptor without velocity penalties.
function M.resolve_order(order, ent, side, info)
	local base = auxi.check_if_any(order, ent, info)
	if base == nil then
		return -1
	end
	if type(base) == "number" then
		return base
	end
	if type(base) == "table" then
		if type(base.order) == "number" then
			return base.order
		end
		if type(base.val) == "number" then
			return base.val
		end
		-- check-remap needs full targets registry; without it use explicit numeric fallback.
		if base.check ~= nil then
			return tonumber(base.fallback) or 0
		end
		return tonumber(base[1]) or 0
	end
	return -1
end

function M.get_order(order, ent, side, info, real)
	local baseinfo = M.resolve_order(order, ent, side, info)
	local veltime = ent:GetData()[OWN_KEY .. "Velocity_Punish"] or 0
	local veltime2 = ent:GetData()[OWN_KEY .. "Velocity_Punish2"] or 0
	local vel_adder = auxi.check_lerp(veltime, velocity_punishment).val
		+ auxi.check_lerp(veltime2, velocity_punishment2).val
	if baseinfo >= 2 then
		vel_adder = vel_adder / 15
	end
	if real then
		vel_adder = 0
	end
	return baseinfo + vel_adder
end



local HP_WRITE_LOG_MAX = 24

local function mortal_probe_active(effect)
	return effect and effect.mortal_probe and effect.mortal_probe.active == true
end

local function mortal_probe_side_locked(effect, side)
	if not mortal_probe_active(effect) then
		return false
	end
	local sp = effect.mortal_probe.sides and effect.mortal_probe.sides[side]
	return sp and sp.lethal_sent == true and sp.resolved ~= true
end

local function record_mortal_invariant(effect, code, detail)
	if not effect then
		return
	end
	effect.mortal_probe = effect.mortal_probe or {}
	local probe = effect.mortal_probe
	probe.invariants = probe.invariants or {}
	local row = {
		frame = Game():GetFrameCount(),
		code = code,
	}
	if type(detail) == "table" then
		for k, v in pairs(detail) do
			row[k] = v
		end
	end
	probe.invariants[#probe.invariants + 1] = row
	while #probe.invariants > 16 do
		table.remove(probe.invariants, 1)
	end
end

local function note_hp_write(effect, target, old_hp, new_hp, reason)
	if not effect then
		return
	end
	-- Regression: any write logged against a probing side is a FAIL.
	if (target == "Left" or target == "Right") and mortal_probe_side_locked(effect, target) then
		record_mortal_invariant(effect, "MORTAL_PROBE_SIDE_OVERWRITE", {
			side = target,
			old = old_hp,
			new = new_hp,
			reason = reason or "hp_write_while_locked",
		})
	end
	effect.hp_write_log = effect.hp_write_log or {}
	local log = effect.hp_write_log
	log[#log + 1] = {
		frame = Game():GetFrameCount(),
		target = target,
		old = tonumber(old_hp),
		new = tonumber(new_hp),
		reason = reason,
	}
	while #log > HP_WRITE_LOG_MAX do
		table.remove(log, 1)
	end
end

local function capture_hp_snapshot(linker, effect)
	local snap = {
		frame = Game():GetFrameCount(),
		linker_hp = tonumber(linker.HitPoints) or 0,
		linker_max_hp = tonumber(linker.MaxHitPoints) or 0,
		ratio = 1,
		sides = {},
	}
	if snap.linker_max_hp > 0.001 then
		snap.ratio = math.max(0, math.min(1, snap.linker_hp / snap.linker_max_hp))
	end
	for _, side in ipairs(SIDES) do
		local slot = effect and effect[side]
		local ent = slot and slot.ent
		if ent and ent:Exists() then
			snap.sides[side] = {
				hp = tonumber(ent.HitPoints) or 0,
				max = tonumber(ent.MaxHitPoints) or 0,
			}
		end
	end
	return snap
end

--- Pair-local shared HP ratio (linker + Left + Right). Multipart collector deferred.
--- Sides still locked in a native-death probe must never be read or written here.
local function apply_shared_link_hp(linker, effect, _tg)
	if not linker or not linker:Exists() or not effect then
		return
	end
	local group = { linker }
	for _, side in ipairs(SIDES) do
		if not mortal_probe_side_locked(effect, side) then
			local slot = effect[side]
			if slot and slot.ent and slot.ent:Exists() and not slot.ent:IsDead() then
				group[#group + 1] = slot.ent
			end
		end
	end
	if #group == 0 then
		return
	end
	for i = 1, #group do
		local n = group[i]
		if n:IsDead() or n.HitPoints <= 0 then
			for j = 1, #group do
				local o = group[j]
				if o:Exists() and not o:IsDead() then
					o:Kill()
				end
			end
			return
		end
	end
	local min_ratio = 1
	for i = 1, #group do
		local n = group[i]
		if n.MaxHitPoints > 0.001 then
			local r = n.HitPoints / n.MaxHitPoints
			if r < min_ratio then
				min_ratio = r
			end
		end
	end
	min_ratio = math.max(0, math.min(1, min_ratio))
	for i = 1, #group do
		local n = group[i]
		if n:Exists() and not n:IsDead() and n.MaxHitPoints > 0 then
			n.HitPoints = n.MaxHitPoints * min_ratio
		end
	end
end

local function side_alive(side_tbl)
	return side_tbl and auxi.check_all_exists(side_tbl.ent)
end

--- protect_self death→revive window: raw entity still Exists, but not fully alive yet.
local function side_in_protected_dead_window(effect, side)
	local slot = effect and effect[side]
	if not slot or not slot.ent then
		return false
	end
	local info = slot.info or {}
	return info.protect_self == true
		and auxi.check_exists(slot.ent)
		and not auxi.check_all_exists(slot.ent)
end

--- Apply selection profile + merged Mixture entry onto a bound slot.
--- profile_id stays fixed for the Suture Needle choice; mixture_* / info may rematch.
function M.apply_profile_to_slot(slot, profile, profile_kind)
	if type(slot) ~= "table" or type(profile) ~= "table" then
		return false
	end
	local entry = profile.source_mixture_entry or {}
	local side = profile.mixture_side
		or (profile_kind == "attack" and "Right")
		or "Left"
	slot.profile_id = profile.id
	slot.profile_kind = profile_kind
	slot.profile_mixture = profile.mixture
	slot.mixture_side = side
	slot.mixture_group = tonumber(entry.group)
	slot.mixture_id = tonumber(entry.id)
	slot.rematch_count = slot.rematch_count or 0
	slot.tvs_mismatch = false
	slot.catalog_match = nil
	local merged = nil
	if slot.mixture_group and slot.mixture_id then
		merged = catalog.get(side, slot.mixture_group, slot.mixture_id)
	end
	if merged then
		slot.info = catalog.merge_profile_hooks(merged, profile.mixture) or merged
	else
		slot.info = slot.info or {}
		if type(profile.mixture) == "table" then
			for k, v in pairs(profile.mixture) do
				if slot.info[k] == nil then
					slot.info[k] = v
				end
			end
		end
	end
	slot.runtime_info = slot.info
	local nd = false
	if type(entry) == "table" and entry.non_danger == true then
		nd = true
	elseif type(slot.info) == "table" and slot.info.non_danger == true then
		nd = true
	end
	slot.non_danger = nd
	return true
end

--- Stitch Edition check_all_type: same userdata, new TVS → rematch merged Mixture entry.
local function maybe_refresh_check_all_type(slot)
	if type(slot) ~= "table" then
		return false
	end
	local info = slot.info or {}
	if not info.check_all_type then
		slot.tvs_mismatch = false
		return false
	end
	local ent = slot.ent
	if not auxi.check_exists(ent) then
		return false
	end
	local side = slot.mixture_side or "Left"
	local match = catalog.find(side, ent.Type, ent.Variant, ent.SubType)
	slot.last_native_tvs = {
		type = ent.Type,
		variant = ent.Variant,
		subtype = ent.SubType,
		ptr = GetPtrHash(ent),
	}
	if not match then
		slot.tvs_mismatch = true
		slot.catalog_match = nil
		return false
	end
	local match_group = match.group or slot.mixture_group
	local match_id = match.id or slot.mixture_id
	slot.catalog_match = { group = match_group, id = match_id }
	local same = match_group == slot.mixture_group and match_id == slot.mixture_id
	if same then
		slot.tvs_mismatch = false
		return false
	end
	slot.tvs_mismatch = true
	if info.special_on_uncheck then
		auxi.check_if_any(info.special_on_uncheck, ent)
	end
	slot.mixture_group = match_group
	slot.mixture_id = match_id
	slot.info = catalog.merge_profile_hooks(match, slot.profile_mixture) or match
	slot.runtime_info = slot.info
	slot.non_danger = (type(slot.info) == "table" and slot.info.non_danger == true) or false
	slot.rematch_count = (slot.rematch_count or 0) + 1
	local tag = M.get_tag(ent)
	if tag then
		tag.mixture_group = match_group
		tag.mixture_id = match_id
		tag.non_danger = slot.non_danger
	end
	return true
end

local function side_forward_backlink_ok(linker, slot, side_name)
	if not slot or not auxi.check_exists(slot.ent) then
		return false, "missing_ent"
	end
	local tag = M.get_tag(slot.ent)
	if not tag or not tag.linker then
		return false, "no_tag"
	end
	if not auxi.check_for_the_same(tag.linker, linker) then
		return false, "linker_mismatch"
	end
	if tag.side ~= side_name then
		return false, "side_mismatch"
	end
	slot.backlink_ok = true
	slot.linker_forward_ok = true
	return true
end

local NATIVE_DEATH_TRACE_MAX = 48
local NATIVE_DEATH_HISTORY_MAX = 6
-- Recent completed chains (survives pair teardown). Newest last.
M._native_death_trace_history = {}
-- Compat alias: newest detached snapshot.
M._last_native_death_trace = nil

local function is_native_death_source(source)
	local ent = source and source.Entity
	if not ent then
		return false
	end
	local d = ent:GetData()
	return d and d[NATIVE_DEATH_SOURCE_KEY] == true
end

local function is_internal_linkee_damage(amt, flag, cooldown, source)
	-- Stitch Edition Boss_Mixturer linkee veto exceptions + native-death probe Source.
	return cooldown == 666
		or (amt == 1000 and flag == 0 and cooldown == 30)
		or is_native_death_source(source)
end

--- Buffered native death is authorized on the side for the whole death cycle.
--- Do NOT rely on MeusNil Source still existing at commit time.
local function is_native_lethal_authorized(effect, side)
	if not effect or not side then
		return false
	end
	local sp = effect.mortal_probe and effect.mortal_probe.sides and effect.mortal_probe.sides[side]
	return sp
		and sp.lethal_sent == true
		and sp.native_lethal_authorized == true
		and sp.resolved ~= true
end

local function clear_native_lethal_authorization(sp)
	if sp then
		sp.native_lethal_authorized = nil
	end
end

local function ent_anim_name(ent)
	if not ent or not ent.GetSprite then
		return nil
	end
	local ok, name = pcall(function()
		return ent:GetSprite():GetAnimation()
	end)
	if ok then
		return name
	end
	return nil
end

local function shallow_copy_table(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

local function copy_trace_rows(trace)
	local out = {}
	if type(trace) ~= "table" then
		return out
	end
	for i = 1, #trace do
		out[i] = shallow_copy_table(trace[i])
	end
	return out
end

local function death_phase_fields(ent, effect)
	local fields = {
		effect_init = effect and (effect.init == true) or nil,
	}
	if not ent then
		return fields
	end
	fields.flags = ent.GetEntityFlags and ent:GetEntityFlags() or nil
	local spawner = ent.SpawnerEntity
	if spawner then
		fields.spawner_type = spawner.Type
		fields.spawner_variant = spawner.Variant
		fields.spawner_subtype = spawner.SubType
	else
		fields.spawner_type = nil
		fields.spawner_variant = nil
		fields.spawner_subtype = nil
	end
	return fields
end

--- Narrow lifecycle trace for one native-death probe.
local function trace_native_death(effect, side, event, ent, extra)
	if not effect then
		return
	end
	effect.mortal_probe = effect.mortal_probe or {}
	local probe = effect.mortal_probe
	probe.trace = probe.trace or {}
	local row = {
		frame = Game():GetFrameCount(),
		event = event,
		side = side,
	}
	local phase = death_phase_fields(ent, effect)
	for k, v in pairs(phase) do
		row[k] = v
	end
	if ent then
		local ok_ptr, ptr = pcall(GetPtrHash, ent)
		row.ptr = ok_ptr and ptr or nil
		row.type = ent.Type
		row.variant = ent.Variant
		row.subtype = ent.SubType
		row.hp = ent.HitPoints
		row.max_hp = ent.MaxHitPoints
		row.mortal = ent.HasMortalDamage and ent:HasMortalDamage() or false
		row.dead = ent.IsDead and ent:IsDead() or false
		row.state = ent.State
		row.animation = ent_anim_name(ent)
	end
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			row[k] = v
		end
	end
	probe.trace[#probe.trace + 1] = row
	while #probe.trace > NATIVE_DEATH_TRACE_MAX do
		table.remove(probe.trace, 1)
	end
end

local function snapshot_native_death_trace(effect, outcome)
	if not effect or not effect.mortal_probe or not effect.mortal_probe.trace then
		return
	end
	local probe = effect.mortal_probe
	if #probe.trace <= 0 then
		return
	end
	local meta = shallow_copy_table(probe.trace_meta) or {}
	meta.side_aggregates = {}
	for _, side in ipairs(SIDES) do
		local sp = probe.sides and probe.sides[side]
		if sp and sp.lethal_sent then
			meta.side_aggregates[side] = {
				hp_sync_count = sp.hp_sync_count or 0,
				hp_sync_first_frame = sp.hp_sync_first_frame,
				hp_sync_last_frame = sp.hp_sync_last_frame,
				hp_sync_last_hp = sp.hp_sync_last_hp,
				seen_dead = sp.seen_dead == true,
				regen_seen = sp.regen_seen == true,
				mortal_cleared = sp.mortal_clear_traced == true,
			}
		end
	end
	local snap = {
		outcome = outcome,
		pair_id = effect.pair_id,
		meta = meta,
		trace = copy_trace_rows(probe.trace),
		frame = Game():GetFrameCount(),
	}
	M._native_death_trace_history = M._native_death_trace_history or {}
	local history = M._native_death_trace_history
	history[#history + 1] = snap
	while #history > NATIVE_DEATH_HISTORY_MAX do
		table.remove(history, 1)
	end
	M._last_native_death_trace = snap
end

-- Early lethal window: keep first N frames verbatim; then only state-change rows.
local NATIVE_PHASE_FORCE_SAMPLES = 5

local function side_phase_fingerprint(ent)
	if not ent then
		return "gone"
	end
	return string.format(
		"%s|%s|%s|%s|%s",
		tostring(ent.HitPoints),
		tostring(ent.HasMortalDamage and ent:HasMortalDamage()),
		tostring(ent.IsDead and ent:IsDead()),
		tostring(ent.State),
		tostring(ent_anim_name(ent))
	)
end

--- Sample SIDE_POST_UPDATE for every live pair with an open lethal probe.
local function sample_side_post_update_traces()
	if not M.iter_live_pairs then
		return
	end
	for _, entry in M.iter_live_pairs() do
		local linker = entry and entry.linker
		local effect = entry and entry.effect or (linker and M.get_effect(linker))
		local probe = effect and effect.mortal_probe
		if probe and probe.active and type(probe.sides) == "table" then
			for _, side in ipairs(SIDES) do
				local sp = probe.sides[side]
				local slot = effect[side]
				local ent = slot and slot.ent
				if sp and sp.lethal_sent and ent and ent.Exists and ent:Exists() then
					sp.post_update_samples = (sp.post_update_samples or 0) + 1
					local mortal = ent.HasMortalDamage and ent:HasMortalDamage() or false
					local dead = ent.IsDead and ent:IsDead() or false
					local anim = ent_anim_name(ent)
					local regen = type(anim) == "string" and string.sub(anim, 1, 5) == "ReGen"
					if sp.last_mortal == true and mortal == false and not sp.mortal_clear_traced then
						sp.mortal_clear_traced = true
						trace_native_death(effect, side, "SIDE_MORTAL_CLEARED", ent, {
							phase = "POST_UPDATE",
							post_update_index = sp.post_update_samples,
							native_updates_after_lethal = sp.native_updates_after_lethal or 0,
						})
					end
					sp.last_mortal = mortal
					local fp = side_phase_fingerprint(ent)
					local force = sp.post_update_samples <= NATIVE_PHASE_FORCE_SAMPLES
					if force or fp ~= sp.last_post_fp then
						sp.last_post_fp = fp
						trace_native_death(effect, side, "SIDE_POST_UPDATE", ent, {
							post_update_index = sp.post_update_samples,
							native_updates_after_lethal = sp.native_updates_after_lethal or 0,
							seen_dead = sp.seen_dead == true,
							regen_seen = (sp.regen_seen == true) or regen,
						})
					end
				end
			end
		end
	end
end

-- Debug/watchdog only: do not reuse protect_time (which is a revival-count budget).
local NATIVE_TRANSITION_WATCH_FRAMES = 30
local NATIVE_PROBE_WATCHDOG_UPDATES = 120

local function cleanup_deferred_native_source(effect, side, reason)
	local probe = effect and effect.mortal_probe
	local sp = probe and probe.sides and side and probe.sides[side]
	local source = sp and sp.native_source and sp.native_source.Ref
	if (not source or not source.Exists or not source:Exists())
		and effect
		and type(effect._deferred_native_sources) == "table"
	then
		for i = 1, #effect._deferred_native_sources do
			local row = effect._deferred_native_sources[i]
			if row and row.side == side and row.ptr and row.ptr.Ref then
				source = row.ptr.Ref
				break
			end
		end
	end
	if source and source.Exists and source:Exists() then
		source:Remove()
	end
	if sp then
		sp.source_removed_frame = Game():GetFrameCount()
		sp.source_remove_reason = reason or "deferred"
		sp.native_source = nil
	end
	if effect and type(effect._deferred_native_sources) == "table" then
		local kept = {}
		for i = 1, #effect._deferred_native_sources do
			local row = effect._deferred_native_sources[i]
			if row and row.side ~= side then
				kept[#kept + 1] = row
			end
		end
		effect._deferred_native_sources = kept
	end
end

local function cleanup_all_deferred_native_sources(effect, reason)
	if not effect then
		return
	end
	for _, side in ipairs(SIDES) do
		cleanup_deferred_native_source(effect, side, reason or "teardown")
	end
	if type(effect._deferred_native_sources) == "table" then
		for i = 1, #effect._deferred_native_sources do
			local row = effect._deferred_native_sources[i]
			local source = row and row.ptr and row.ptr.Ref
			if source and source.Exists and source:Exists() then
				source:Remove()
			end
		end
		effect._deferred_native_sources = {}
	end
end

-- Standalone / stitch shared deferred Source list (Remove after first native update of target).
local deferred_marked_sources = {}

local function spawn_marked_lethal_source(at_ent, source_kind)
	source_kind = source_kind or "meusnil"
	local pos = (at_ent and at_ent.Position) or Game():GetRoom():GetCenterPos()
	local source = nil
	if source_kind == "npc_10" then
		source = Isaac.Spawn(10, 0, 0, pos + Vector(80, 0), Vector.Zero, nil)
		if source and source.ToNPC then
			source = source:ToNPC() or source
		end
	else
		local nil_var = enums.Entities.ID_EFFECT_MeusNIL
		source = Isaac.Spawn(EntityType.ENTITY_EFFECT, nil_var, 0, pos, Vector.Zero, nil)
		if source then
			source.Visible = false
		end
	end
	if not source then
		return nil
	end
	source.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	source.Velocity = Vector.Zero
	source:GetData()[NATIVE_DEATH_SOURCE_KEY] = true
	source:GetData().QingSutureDeathProbeSource = true
	return source
end

local function queue_marked_source_defer(source, target_ent, effect, side)
	if not source then
		return nil
	end
	local spawn_frame = Game():GetFrameCount()
	local ptr = EntityPtr(source)
	local row = {
		ptr = ptr,
		target_hash = target_ent and GetPtrHash(target_ent) or nil,
		spawn_frame = spawn_frame,
		remove_after_frame = spawn_frame + 1,
		native_updates = 0,
		side = side,
		removed = false,
	}
	deferred_marked_sources[#deferred_marked_sources + 1] = row
	if effect then
		effect._deferred_native_sources = effect._deferred_native_sources or {}
		effect._deferred_native_sources[#effect._deferred_native_sources + 1] = {
			side = side,
			ptr = ptr,
			spawn_frame = spawn_frame,
		}
		effect.mortal_probe = effect.mortal_probe or {
			frame = spawn_frame,
			active = true,
			sides = {},
		}
		effect.mortal_probe.sides = effect.mortal_probe.sides or {}
		local sp = effect.mortal_probe.sides[side]
		if not sp then
			sp = {
				lethal_sent = true,
				native_updates_after_lethal = 0,
				seen_dead = false,
			}
			effect.mortal_probe.sides[side] = sp
		end
		sp.native_source = ptr
		sp.native_source_spawn_frame = spawn_frame
		sp.native_source_remove_after = spawn_frame + 1
	end
	return row
end

local function try_remove_deferred_marked_source_for_ent(ent)
	if not ent then
		return
	end
	local hash = GetPtrHash(ent)
	for i = 1, #deferred_marked_sources do
		local row = deferred_marked_sources[i]
		if row and not row.removed and row.target_hash == hash then
			row.native_updates = (row.native_updates or 0) + 1
			if row.native_updates == 1 then
				local source = row.ptr and row.ptr.Ref
				if source and source.Exists and source:Exists() then
					source:Remove()
				end
				row.removed = true
				row.source_removed_frame = Game():GetFrameCount()
			end
		end
	end
end

--- Force a native side through ordinary lethal TakeDamage without using
--- EntityRef(linker) (FRIENDLY|CHARM) or the player. Source is marked with
--- NATIVE_DEATH_SOURCE_KEY. opts.source_kind: "meusnil" (default) | "npc_10".
--- Do NOT Remove same-frame — buffered damage needs Source until first native update.
local function send_native_lethal_damage(ent, effect, side, opts)
	opts = opts or {}
	if not ent or not auxi.check_exists(ent) then
		return false, nil
	end
	local source_kind = opts.source_kind or "meusnil"
	if source_kind == "current_meusnil" then
		source_kind = "meusnil"
	end
	-- Old Stitch parity: EntityRef(linker) + cooldown 666 (already allowed by linkee veto).
	if source_kind == "legacy_linker" then
		local linker = opts.linker
		if not linker or not auxi.check_exists(linker) then
			return false, nil
		end
		trace_native_death(effect, side, "source_spawned", linker, {
			source_kind = source_kind,
			source_type = linker.Type,
			source_variant = linker.Variant,
			source_subtype = linker.SubType,
			source_exists = linker:Exists(),
			source_friendly = linker:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == true,
			source_charm = linker:HasEntityFlags(EntityFlag.FLAG_CHARM) == true,
			source_marker = false,
			cooldown = 666,
		})
		local result = ent:TakeDamage(1, 0, EntityRef(linker), 666)
		trace_native_death(effect, side, "after_take_damage", ent, {
			take_damage_return = result,
			take_damage_ok = result ~= false,
			source_kind = source_kind,
			cooldown = 666,
		})
		return result ~= false, {
			source_kind = source_kind,
			type = linker.Type,
			variant = linker.Variant,
			subtype = linker.SubType,
			friendly = linker:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == true,
			charm = linker:HasEntityFlags(EntityFlag.FLAG_CHARM) == true,
			marker = false,
			cooldown = 666,
			source_exists_after_take_damage = linker:Exists() == true,
		}
	end
	local source = spawn_marked_lethal_source(ent, source_kind)
	if not source then
		return false, nil
	end

	local marker = source:GetData()[NATIVE_DEATH_SOURCE_KEY] == true
	local spawn_frame = Game():GetFrameCount()
	trace_native_death(effect, side, "source_spawned", source, {
		source_kind = source_kind,
		source_type = source.Type,
		source_variant = source.Variant,
		source_subtype = source.SubType,
		source_exists = source:Exists(),
		source_friendly = source:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == true,
		source_charm = source:HasEntityFlags(EntityFlag.FLAG_CHARM) == true,
		source_spawner = source.SpawnerEntity and source.SpawnerEntity.Type or nil,
		source_marker = marker,
		source_spawn_frame = spawn_frame,
	})

	local cooldown = 0
	if source_kind == "meusnil" or source_kind == "npc_10" then
		cooldown = tonumber(opts.cooldown)
		if cooldown == nil then
			cooldown = (source_kind == "meusnil") and native_death_meusnil_cooldown or 0
		end
	end
	local result = ent:TakeDamage(1, 0, EntityRef(source), cooldown)
	local exists_after = source:Exists() == true

	trace_native_death(effect, side, "after_take_damage", ent, {
		take_damage_return = result,
		take_damage_ok = result ~= false,
		source_exists_after_take_damage = exists_after,
		source_kind = source_kind,
		cooldown = cooldown,
	})

	local meta = {
		source_kind = source_kind,
		type = source.Type,
		variant = source.Variant,
		subtype = source.SubType,
		friendly = source:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == true,
		charm = source:HasEntityFlags(EntityFlag.FLAG_CHARM) == true,
		marker = marker,
		cooldown = cooldown,
		source_exists_after_take_damage = exists_after,
		source_spawn_frame = spawn_frame,
	}

	local row = queue_marked_source_defer(source, ent, effect, side)
	if effect and side then
		effect.mortal_probe = effect.mortal_probe or { active = true, sides = {} }
		effect.mortal_probe.sides = effect.mortal_probe.sides or {}
		local sp = effect.mortal_probe.sides[side]
		if not sp then
			sp = {
				lethal_sent = true,
				native_updates_after_lethal = 0,
				seen_dead = false,
			}
			effect.mortal_probe.sides[side] = sp
		end
		sp.lethal_sent = true
		sp.native_lethal_authorized = true
		sp.source_exists_after_take_damage = exists_after
		sp.source_kind = source_kind
		effect.mortal_probe.active = true
	end
	if row then
		meta.deferred = true
	end
	return result ~= false, meta
end

--- Dev/probe API: stitch side lethal with selectable marked Source TVS.
function M.debug_send_native_lethal(linker, side, opts)
	opts = opts or {}
	if not linker or not side then
		return false, nil
	end
	local effect = M.get_effect(linker)
	local slot = effect and effect[side]
	if not slot or not auxi.check_exists(slot.ent) then
		return false, nil
	end
	local ent = slot.ent
	if opts.force_hp_neg ~= false then
		ent.HitPoints = -1
	end
	return send_native_lethal_damage(ent, effect, side, opts)
end

--- Dev/probe API: any entity (including non-stitched Globin). Same HP=-1 + TakeDamage(1).
function M.debug_send_marked_lethal(ent, opts)
	opts = opts or {}
	if not ent or not auxi.check_exists(ent) then
		return false, nil
	end
	if opts.force_hp_neg ~= false then
		ent.HitPoints = -1
	end
	return send_native_lethal_damage(ent, nil, opts.side or "Matrix", opts)
end

local function resolve_side_anm2(info)
	if type(info) ~= "table" then
		return nil
	end
	if type(info.real_anm2) == "string" and info.real_anm2 ~= "" then
		return info.real_anm2
	end
	if type(info.name) == "string" and info.name ~= "" then
		return "gfx/" .. info.name .. ".anm2"
	end
	return nil
end

--- Restore a hidden native side as a normal visible NPC (NoKill / should_release).
local function restore_native_presentation(ent, info, bind_size)
	if not auxi.check_exists(ent) then
		return false
	end
	info = info or {}
	local path = resolve_side_anm2(info)
	if path then
		local vs = ent:GetSprite()
		local anim = vs:GetAnimation()
		local fr = vs:GetFrame()
		local finished = vs:IsFinished(anim)
		local overlayanim = vs:GetOverlayAnimation()
		local overlayfr = vs:GetOverlayFrame()
		vs:Load(path, true)
		vs:Play(anim, true)
		vs:SetFrame(fr)
		if finished then
			vs:Update()
		end
		if overlayanim ~= "" and not info.NoOverlayonKill then
			vs:PlayOverlay(overlayanim, true)
			vs:SetOverlayFrame(overlayanim, overlayfr)
		end
	end
	ent.Visible = true
	if bind_size then
		ent.Size = bind_size
	end
	ent:ClearEntityFlags(FRIEND_FLAG | EntityFlag.FLAG_PERSISTENT)
	return true
end

local function read_linkee_release_context(ent, opts)
	opts = opts or {}
	local info = opts.info
	local bind_size = opts.bind_size
	local tag = M.get_tag(ent)
	if tag then
		bind_size = bind_size or tag.bind_size
		if not info then
			local linker = tag.linker
			local effect = linker and M.get_effect(linker) or nil
			local slot = effect and tag.side and effect[tag.side]
			if slot and slot.info then
				info = slot.info
				bind_size = bind_size or slot.bind_size
			elseif tag.mixture_group and tag.mixture_id then
				info = catalog.get(tag.side or "Left", tag.mixture_group, tag.mixture_id)
			end
		end
	end
	return info or {}, bind_size, tag
end

--- Unlink a native side: NoKill/should_release restore, else Kill+Update (+ Remove).
--- Kill path keeps TAG through Kill+Update so native deathrattles still see Mixture identity.
local function release_orphaned_linkee(ent, reason, opts)
	opts = opts or {}
	if not ent then
		return
	end
	local info, bind_size, tag = read_linkee_release_context(ent, opts)
	local d = ent.GetData and ent:GetData() or nil
	local non_danger = opts.non_danger
	if non_danger == nil then
		non_danger = (tag and tag.non_danger == true)
			or (opts.slot and opts.slot.non_danger == true)
			or info.non_danger == true
	end
	if d and d[OWN_KEY .. "GridCollision"] then
		Attribute_holder.try_rewind_attribute(ent, "GridCollisionClass", d[OWN_KEY .. "GridCollision"])
		d[OWN_KEY .. "GridCollision"] = nil
	end

	if not auxi.check_exists(ent) then
		if d then
			d[TAG_KEY] = nil
		end
		return
	end

	local function fire_on_death()
		if non_danger or opts.skip_on_death then
			return
		end
		if info.on_death then
			auxi.check_if_any(info.on_death, ent, info)
		end
	end

	local function clear_tag_now()
		if d then
			d[TAG_KEY] = nil
		end
	end

	-- NoKill / pure release: unlink first, then restore presentation (no Kill).
	if info.NoKill or opts.skip_kill == true then
		clear_tag_now()
		if info.NoKill or opts.force_release then
			restore_native_presentation(ent, info, bind_size)
		end
		fire_on_death()
		if d then
			d[OWN_KEY .. "released"] = true
		end
		return
	end

	-- Default deathrattle path: KEEP tag through Kill+Update.
	pcall(function()
		ent.HitPoints = 0
		ent:Kill()
		ent:Update()
	end)
	fire_on_death()

	local should_release = opts.force_release == true
		or info.should_release == true
		or reason == "stale_backlink"
		or reason == "linker_gone"
	if ent.Exists and ent:Exists() and should_release and ent.Visible == false then
		clear_tag_now()
		restore_native_presentation(ent, info, bind_size)
		if d then
			d[OWN_KEY .. "released"] = true
		end
		return
	end

	clear_tag_now()
	if ent.Exists and ent:Exists() then
		pcall(function()
			ent:Remove()
		end)
	end
end

--- Probe-oriented snapshot of one side's mixture / link identity.
function M.get_side_lifecycle_diag(slot, linker, side_name)
	if type(slot) ~= "table" then
		return nil
	end
	local ent = slot.ent
	local exists = auxi.check_exists(ent)
	local all_exists = auxi.check_all_exists(ent)
	local info = slot.info or {}
	local ri = slot.runtime_info or info
	local forward_ok = false
	if linker and side_name and exists then
		local ok = side_forward_backlink_ok(linker, slot, side_name)
		forward_ok = ok == true
	elseif slot.backlink_ok == true then
		forward_ok = true
	end
	local out = {
		profile_id = slot.profile_id,
		profile_kind = slot.profile_kind,
		mixture_side = slot.mixture_side,
		mixture_group = slot.mixture_group,
		mixture_id = slot.mixture_id,
		resolved_from = ri.resolved_from or (ri.check and ri.check) or nil,
		check_parent = type(ri.check) == "number" and ri.check or nil,
		check_all_type = info.check_all_type == true,
		protect_self = info.protect_self == true,
		protect_time = info.protect_time,
		protected = slot.protected or 0,
		NoKill = info.NoKill == true,
		should_release = info.should_release == true,
		released = (ent and ent.GetData and ent:GetData()[OWN_KEY .. "released"]) == true,
		tvs_mismatch = slot.tvs_mismatch == true,
		catalog_match = slot.catalog_match,
		rematch_count = slot.rematch_count or 0,
		backlink_ok = slot.backlink_ok == true or forward_ok == true,
		linker_forward_ok = slot.linker_forward_ok == true or forward_ok == true,
		native_lethal_sent = false,
		native = exists and {
			ptr = GetPtrHash(ent),
			type = ent.Type,
			variant = ent.Variant,
			subtype = ent.SubType,
			exists = true,
			is_dead = ent.IsDead and ent:IsDead() or false,
			check_all_exists = all_exists == true,
		} or {
			exists = false,
			check_all_exists = false,
		},
	}
	if linker then
		local eff = M.get_effect(linker)
		local probe = eff and eff.mortal_probe
		out.native_lethal_sent = probe and probe.native_lethal_sent == true or false
		if probe and probe.sides and probe.sides[side_name] then
			out.tvs_before_probe = probe.sides[side_name].tvs_before
			out.mortal_side_probe = probe.sides[side_name]
		elseif probe and probe["side_" .. tostring(side_name)] then
			out.tvs_before_probe = probe["side_" .. tostring(side_name)]
		end
	end
	return out
end

--- Probe-oriented Base/linker lifecycle snapshot.
function M.get_linker_lifecycle_diag(linker)
	if not linker then
		return nil
	end
	local effect = M.get_effect(linker)
	local ptr = GetPtrHash(linker)
	local live = live_pairs[ptr] ~= nil
	local mortal = linker.HasMortalDamage and linker:HasMortalDamage() or false
	local probe = effect and effect.mortal_probe or nil
	return {
		exists = auxi.check_exists(linker) == true,
		dead = linker.IsDead and linker:IsDead() or false,
		mortal = mortal,
		effect_present = effect ~= nil,
		live_registered = live,
		destroying = effect and effect.destroying == true or false,
		destroy_reason = effect and effect.destroy_reason or nil,
		health_needs_rebuild = effect and effect.health_needs_rebuild == true or false,
		death_probe_active = probe and probe.active == true or false,
		mortal_probe_active = probe and probe.active == true or false,
		mortal_probe_frame = probe and probe.frame or nil,
		transition_confirmed = probe and probe.transition_confirmed == true or false,
		base_rescued = probe and probe.base_rescued == true or false,
		mortal_probe = probe,
		native_death_trace_len = probe and probe.trace and #probe.trace or 0,
		frame_count = linker.FrameCount,
	}
end

local function format_native_death_trace_payload(payload, opts)
	opts = opts or {}
	if type(payload) ~= "table" or type(payload.trace) ~= "table" then
		return "Native Death Trace\n(no data)"
	end
	local meta = payload.meta or {}
	local title = opts.title or "Native Death Trace"
	local lines = {
		title,
		string.format("outcome=%s", tostring(payload.outcome or "—")),
		string.format("pair=%s", tostring(payload.pair_id or meta.pair_id or "—")),
		string.format("side=%s", tostring(meta.side or "—")),
		string.format("profile=%s", tostring(meta.profile or "—")),
		string.format(
			"protect_self=%s  check_all_type=%s  protect_time=%s  source_mode=%s  meusnil_cd=%s",
			tostring(meta.protect_self),
			tostring(meta.check_all_type),
			tostring(meta.protect_time),
			tostring(meta.source_mode or native_death_source_mode),
			tostring(meta.meusnil_cooldown or native_death_meusnil_cooldown)
		),
		"",
	}
	for _, row in ipairs(payload.trace) do
		lines[#lines + 1] = string.format("[%s] %s", tostring(row.frame), tostring(row.event))
		if row.side then
			lines[#lines + 1] = "side=" .. tostring(row.side)
		end
		if row.hp ~= nil then
			lines[#lines + 1] = string.format(
				"HP=%s/%s  Mortal=%s  Dead=%s  State=%s  effect.init=%s",
				tostring(row.hp),
				tostring(row.max_hp),
				tostring(row.mortal),
				tostring(row.dead),
				tostring(row.state),
				tostring(row.effect_init)
			)
		end
		if row.type ~= nil then
			lines[#lines + 1] = string.format(
				"TVS=%s.%s.%s  anim=%s",
				tostring(row.type),
				tostring(row.variant),
				tostring(row.subtype),
				tostring(row.animation)
			)
		end
		if row.flags ~= nil or row.spawner_type ~= nil then
			lines[#lines + 1] = string.format(
				"flags=%s  Spawner=%s.%s.%s",
				tostring(row.flags),
				tostring(row.spawner_type),
				tostring(row.spawner_variant),
				tostring(row.spawner_subtype)
			)
		end
		if row.event == "source_spawned" then
			lines[#lines + 1] = string.format(
				"Source=%s.%s.%s  Friendly=%s  Charm=%s  Marker=%s  cd=%s",
				tostring(row.source_type or row.type),
				tostring(row.source_variant or row.variant),
				tostring(row.source_subtype or row.subtype),
				tostring(row.source_friendly),
				tostring(row.source_charm),
				tostring(row.source_marker),
				tostring(row.cooldown)
			)
		elseif row.event == "damage_callback_enter"
			or row.event == "damage_callback_allowed"
			or row.event == "LINKLEE_DAMAGE_CALLBACK"
		then
			lines[#lines + 1] = string.format(
				"amt=%s  damage_flags=%s  cooldown=%s  decision=%s",
				tostring(row.amt),
				tostring(row.damage_flags),
				tostring(row.cooldown),
				tostring(row.decision or (row.internal and "allow" or "?"))
			)
			lines[#lines + 1] = string.format(
				"internal=%s  source_based=%s  cycle_auth=%s  locked=%s",
				tostring(row.internal),
				tostring(row.source_based),
				tostring(row.cycle_authorized),
				tostring(row.locked)
			)
			lines[#lines + 1] = string.format(
				"source_exists=%s  Source=%s.%s.%s  marker=%s",
				tostring(row.source_exists),
				tostring(row.source_type),
				tostring(row.source_variant),
				tostring(row.source_subtype),
				tostring(row.source_marker)
			)
		elseif row.event == "after_take_damage" then
			lines[#lines + 1] = string.format(
				"return=%s  cooldown=%s",
				tostring(row.take_damage_return),
				tostring(row.cooldown)
			)
		elseif row.event == "SIDE_NPC_UPDATE_END" or row.event == "SIDE_POST_UPDATE" then
			lines[#lines + 1] = string.format(
				"npc_updates=%s  post_i=%s  seen_dead=%s  regen=%s",
				tostring(row.native_updates_after_lethal),
				tostring(row.post_update_index),
				tostring(row.seen_dead),
				tostring(row.regen_seen)
			)
		elseif row.event == "SIDE_HP_SYNC_FIRST" or row.event == "SIDE_HP_SYNC_STATE" then
			lines[#lines + 1] = string.format(
				"old_hp=%s  new_hp=%s  Mortal %s→%s  sync_count=%s",
				tostring(row.old_hp),
				tostring(row.new_hp),
				tostring(row.mortal_before),
				tostring(row.mortal_after),
				tostring(row.hp_sync_count)
			)
		elseif row.event == "SIDE_MORTAL_CLEARED" then
			lines[#lines + 1] = string.format(
				"phase=%s  old_hp=%s  new_hp=%s",
				tostring(row.phase),
				tostring(row.old_hp),
				tostring(row.new_hp)
			)
		elseif row.event == "SIDE_PROTECTED_DEAD_WINDOW" or row.event == "SIDE_DEAD" then
			lines[#lines + 1] = string.format(
				"phase=%s  protected=%s/%s  seen_dead=%s",
				tostring(row.phase),
				tostring(row.protected_count),
				tostring(row.protect_limit),
				tostring(row.seen_dead)
			)
		elseif row.event == "LINKER_NATIVE_RECOVERY_HP" then
			lines[#lines + 1] = string.format(
				"side=%s/%s  ratio=%s  Linker HP %s→%s",
				tostring(row.side_hp),
				tostring(row.side_max),
				tostring(row.ratio),
				tostring(row.old_hp),
				tostring(row.new_hp)
			)
		elseif row.event == "probe_failed" or row.event == "probe_confirmed" then
			lines[#lines + 1] = string.format(
				"seen_dead=%s  updates=%s  tvs_changed=%s  rematched=%s  no_transition_frames=%s  final_dead=%s",
				tostring(row.seen_dead),
				tostring(row.native_updates_after_lethal),
				tostring(row.tvs_changed),
				tostring(row.rematched),
				tostring(row.no_transition_frames),
				tostring(row.final_dead)
			)
		end
		lines[#lines + 1] = ""
	end
	return table.concat(lines, "\n")
end

--- Summary for ImGui: survives pair teardown via history ring.
function M.get_native_death_trace_summary(linker)
	local effect = linker and M.get_effect(linker)
	local probe = effect and effect.mortal_probe
	local history_n = M._native_death_trace_history and #M._native_death_trace_history or 0
	if probe and type(probe.trace) == "table" and #probe.trace > 0 then
		local last = probe.trace[#probe.trace]
		return {
			has_data = true,
			count = #probe.trace,
			history = history_n,
			last_event = last and last.event,
			outcome = probe.transition_confirmed and "confirmed"
				or (probe.active and "pending" or "—"),
			source = "live",
		}
	end
	local snap = M._last_native_death_trace
	if snap and type(snap.trace) == "table" and #snap.trace > 0 then
		local last = snap.trace[#snap.trace]
		return {
			has_data = true,
			count = #snap.trace,
			history = history_n,
			last_event = last and last.event,
			outcome = snap.outcome or "—",
			source = "detached",
		}
	end
	if history_n > 0 then
		local last_hist = M._native_death_trace_history[history_n]
		local last = last_hist.trace and last_hist.trace[#last_hist.trace]
		return {
			has_data = true,
			count = last_hist.trace and #last_hist.trace or 0,
			history = history_n,
			last_event = last and last.event,
			outcome = last_hist.outcome or "—",
			source = "history",
		}
	end
	return { has_data = false, count = 0, history = 0, last_event = nil, outcome = "none", source = "none" }
end

--- Compact text: live chain (if any) + recent history (newest last).
function M.format_native_death_trace(linker)
	local effect = linker and M.get_effect(linker)
	local probe = effect and effect.mortal_probe
	local live_active = probe
		and probe.active == true
		and type(probe.trace) == "table"
		and #probe.trace > 0
	local chunks = {}
	local history = M._native_death_trace_history or {}
	if #history > 0 then
		chunks[#chunks + 1] = string.format(
			"Native Death Trace History  n=%d (max %d)",
			#history,
			NATIVE_DEATH_HISTORY_MAX
		)
		for i = 1, #history do
			chunks[#chunks + 1] = format_native_death_trace_payload(history[i], {
				title = string.format("=== history[%d] outcome=%s ===", i, tostring(history[i].outcome)),
			})
		end
	end
	if live_active then
		chunks[#chunks + 1] = format_native_death_trace_payload({
			outcome = probe.transition_confirmed and "confirmed" or "pending",
			pair_id = effect.pair_id,
			meta = probe.trace_meta,
			trace = probe.trace,
		}, { title = "=== LIVE (current mortal_probe) ===" })
		for _, side in ipairs(SIDES) do
			local sp = probe.sides and probe.sides[side]
			if sp and sp.lethal_sent then
				chunks[#chunks + 1] = string.format(
					"[%s aggregate] hp_sync_count=%s first_frame=%s last_frame=%s last_hp=%s seen_dead=%s regen=%s mortal_cleared=%s",
					tostring(side),
					tostring(sp.hp_sync_count or 0),
					tostring(sp.hp_sync_first_frame),
					tostring(sp.hp_sync_last_frame),
					tostring(sp.hp_sync_last_hp),
					tostring(sp.seen_dead == true),
					tostring(sp.regen_seen == true),
					tostring(sp.mortal_clear_traced == true)
				)
			end
		end
	elseif #chunks <= 0 then
		if probe and type(probe.trace) == "table" and #probe.trace > 0 then
			return format_native_death_trace_payload({
				outcome = probe.transition_confirmed and "confirmed" or "—",
				pair_id = effect.pair_id,
				meta = probe.trace_meta,
				trace = probe.trace,
			})
		end
		return "Native Death Trace\n尚未捕获死亡链。\n请先生成含 protect_self 的缝合体并执行「Linker 正常致死」。"
	end
	return table.concat(chunks, "\n")
end

function M.clear_native_death_trace(linker)
	M._last_native_death_trace = nil
	M._native_death_trace_history = {}
	local effect = linker and M.get_effect(linker)
	if effect and effect.mortal_probe then
		effect.mortal_probe.trace = {}
		effect.mortal_probe.trace_meta = nil
	end
	return true
end

--- Apply Movement/Left defaults onto the linker (bind-time and tick Size/shadow).
--- opts.apply_* = false skips that field (profile override already applied).
local function apply_physical_owner_defaults(linker, effect, opts)
	opts = opts or {}
	local slot, name = physical_owner_slot(effect)
	if not side_alive(slot) then
		return false
	end
	local src = slot.ent
	effect.physical_owner = name
	effect.size = src.Size or effect.size or 13
	effect.init_size = true
	linker.Size = effect.size
	if opts.apply_mass ~= false then
		linker.Mass = src.Mass
	end
	if opts.apply_collision_damage ~= false then
		linker.CollisionDamage = src.CollisionDamage
	end
	if opts.apply_entity_collision ~= false then
		linker.EntityCollisionClass = src.EntityCollisionClass
	end
	if opts.apply_grid_collision ~= false then
		linker.GridCollisionClass = src.GridCollisionClass
	end
	if opts.apply_shadow ~= false then
		local sh = read_shadow_size(src)
		if sh ~= nil then
			apply_shadow_size(linker, sh)
		end
	end
	return true
end

local function clear_side_tag(ent)
	if not ent then
		return
	end
	local d = ent:GetData()
	if d then
		d[TAG_KEY] = nil
	end
end

local function run_side_death_hooks(slot, reason)
	if not slot or not slot.ent then
		return
	end
	if reason ~= "pair_death" and reason ~= "orphaned" then
		return
	end
	if slot.non_danger == true then
		return
	end
	local info = slot.info or {}
	if info.non_danger then
		return
	end
	if info.on_death then
		auxi.check_if_any(info.on_death, slot.ent, reason)
	end
end

local function slot_is_hp_main(slot, side)
	if slot and slot.main ~= nil then
		return slot.main == true
	end
	-- Default suture: Left is HP main (independent of baseinfo.tg motion owner).
	return side == "Left"
end

--- Explicit HP policy (Stitch Edition main/nomain weights; no silent average).
--- HP main comes from slot.main — NEVER from baseinfo.tg (motion owner).
function M.compute_initial_health(effect, opts)
	opts = opts or {}
	local policy = opts.hp_policy or {}
	local main_weight = tonumber(policy.main_weight)
	local secondary_weight = tonumber(policy.secondary_weight)
	if main_weight == nil then
		main_weight = 1
	end
	if secondary_weight == nil then
		secondary_weight = 0
	end
	local level_scale = tonumber(policy.level_scale) or 1
	local hitpoints = 0
	local totalval = 0
	local totalval2 = 0
	local shield = 0
	for _, side in ipairs(SIDES) do
		local slot = effect[side]
		if slot and slot.ent then
			local info = slot.info or {}
			local basehp = slot.ent.MaxHitPoints or 0
			if info.HitPoints then
				basehp = auxi.check_if_any(info.HitPoints, basehp, slot.ent) or basehp
			end
			local mult = slot_is_hp_main(slot, side) and main_weight or secondary_weight
			hitpoints = hitpoints + basehp * mult
			if mult <= 0.01 then
				totalval2 = totalval2 + basehp
			end
			totalval = totalval + mult
			if REPENTOGON and slot.ent.GetShieldStrength then
				shield = math.max(shield, slot.ent:GetShieldStrength() or 0)
			end
		end
	end
	if totalval <= 0.01 then
		hitpoints = totalval2
		totalval = 1
	end
	local max_hp = (hitpoints / totalval) * level_scale
	if max_hp <= 0 then
		max_hp = 40
	end
	return {
		MaxHitPoints = max_hp,
		HitPoints = max_hp,
		Shield = shield,
		TotalVal = totalval,
	}
end

--- Stitch HP bar ownership: sides hide bars; Linker shows the authoritative bar.
local function apply_stitch_hp_bar_ownership(linker, effect)
	for _, side in ipairs(SIDES) do
		local slot = effect and effect[side]
		local ent = slot and slot.ent
		if ent and ent.Exists and ent:Exists() then
			if slot.original_hide_hp_bar == nil then
				slot.original_hide_hp_bar = ent:HasEntityFlags(EntityFlag.FLAG_HIDE_HP_BAR) == true
			end
			ent:AddEntityFlags(EntityFlag.FLAG_HIDE_HP_BAR)
		end
	end
	if linker and linker.Exists and linker:Exists() then
		linker:ClearEntityFlags(EntityFlag.FLAG_HIDE_HP_BAR)
	end
end

local function restore_side_hide_hp_bar(ent, slot)
	if not ent or not ent.Exists or not ent:Exists() then
		return
	end
	if slot and slot.original_hide_hp_bar == true then
		ent:AddEntityFlags(EntityFlag.FLAG_HIDE_HP_BAR)
	else
		ent:ClearEntityFlags(EntityFlag.FLAG_HIDE_HP_BAR)
	end
end

--- After protect_self native revive (e.g. Globin ReGen 10/33), crush Linker HP to that ratio.
--- Never raise Linker HP above its current value (extra damage during the window must stick).
local function apply_native_recovery_hp_to_linker(linker, effect, slot, side)
	if not linker or not slot or not auxi.check_exists(slot.ent) then
		return false
	end
	local ent = slot.ent
	local side_max = tonumber(ent.MaxHitPoints) or 0
	if side_max <= 0.001 then
		return false
	end
	local ratio = math.max(0, math.min(1, (tonumber(ent.HitPoints) or 0) / side_max))
	local linker_max = math.max(1, tonumber(linker.MaxHitPoints) or 1)
	local recovered = linker_max * ratio
	local old_hp = tonumber(linker.HitPoints) or 0
	local new_hp = math.min(old_hp, recovered)
	if new_hp + 0.001 >= old_hp then
		return false
	end
	linker.HitPoints = new_hp
	note_hp_write(effect, "Linker", old_hp, new_hp, "protect_self_native_recovery")
	trace_native_death(effect, side, "LINKER_NATIVE_RECOVERY_HP", linker, {
		side_hp = ent.HitPoints,
		side_max = side_max,
		ratio = ratio,
		old_hp = old_hp,
		new_hp = new_hp,
	})
	return true
end

--- Tear down a bound pair.
--- Contract:
---   REMOVE sides (default): keep Stitch tag until Kill/Remove finishes so PRE still suppresses.
---   RELEASE sides (keep_sides): clear tag then restore independent NPC.
---   pair_death: Kill+Update then Remove fallback; other reasons: Remove only.
---   Idempotent via effect.destroying.
function M.destroy_pair(linker, reason, opts)
	opts = opts or {}
	reason = reason or "manual_cleanup"
	if not linker then
		return
	end

	local ptr = GetPtrHash(linker)
	local rec = live_pairs[ptr]
	local d = linker.GetData and linker:GetData() or nil
	local effect = opts.effect
		or (d and d[OWN_KEY .. "effect"])
		or (rec and rec.effect)
	if not effect then
		return
	end
	if effect.destroying then
		return
	end
	effect.destroying = true
	effect.destroy_reason = reason
	cleanup_all_deferred_native_sources(effect, "destroy_pair:" .. tostring(reason or "?"))
	-- Detach death-chain evidence before sides/linker are torn down.
	if effect.mortal_probe and type(effect.mortal_probe.trace) == "table"
		and #effect.mortal_probe.trace > 0
	then
		snapshot_native_death_trace(effect, reason)
	end

	local fire_hooks = (reason == "pair_death" or reason == "orphaned")
	local use_kill = (reason == "pair_death")
	local keep_sides = opts.keep_sides == true

	for _, side in ipairs(SIDES) do
		local slot = effect[side]
		if slot and slot.ent then
			local side_ent = slot.ent
			local info = slot.info or {}
			if fire_hooks then
				run_side_death_hooks(slot, reason)
				if info.on_kill and reason == "pair_death" then
					auxi.check_if_any(info.on_kill, side_ent)
				end
			end
			if keep_sides then
				-- Explicit RELEASE: independent NPC, no death.
				local sd = side_ent.GetData and side_ent:GetData() or nil
				if sd and sd[OWN_KEY .. "GridCollision"] then
					Attribute_holder.try_rewind_attribute(
						side_ent,
						"GridCollisionClass",
						sd[OWN_KEY .. "GridCollision"]
					)
					sd[OWN_KEY .. "GridCollision"] = nil
				end
				clear_side_tag(side_ent)
				if side_ent.Exists and side_ent:Exists() then
					restore_native_presentation(side_ent, info, slot.bind_size)
					restore_side_hide_hp_bar(side_ent, slot)
				end
			elseif info.NoKill then
				release_orphaned_linkee(side_ent, reason, {
					info = info,
					bind_size = slot.bind_size,
					skip_on_death = fire_hooks,
				})
			elseif side_ent.Exists and side_ent:Exists() then
				side_ent:ClearEntityFlags(FRIEND_FLAG | EntityFlag.FLAG_PERSISTENT)
				if use_kill then
					-- REMOVE: tag stays until entity leaves so PRE suppress continues.
					if not side_ent:IsDead() then
						side_ent:Kill()
						if side_ent.Update then
							side_ent:Update()
						end
					end
					if side_ent:Exists() then
						if info.should_release and side_ent.Visible == false then
							-- Already Kill+Update'd with TAG intact; now restore without re-killing.
							release_orphaned_linkee(side_ent, reason, {
								info = info,
								bind_size = slot.bind_size,
								force_release = true,
								skip_kill = true,
								skip_on_death = true,
								non_danger = slot.non_danger,
								slot = slot,
							})
						else
							clear_side_tag(side_ent)
							side_ent:Remove()
						end
					end
				else
					side_ent:Remove()
				end
			end
			slot.ent = nil
		end
	end

	if visual_detach_fn then
		pcall(visual_detach_fn, linker)
	end

	unregister_live_pair(linker)
	if d then
		d[OWN_KEY .. "effect"] = nil
	end

	if not opts.keep_linker then
		clear_side_tag(linker)
		if linker.Exists and linker:Exists() then
			linker:ClearEntityFlags(FRIEND_FLAG | EntityFlag.FLAG_PERSISTENT)
			linker:Remove()
		end
	end
end

-- Compat alias — removes sides. Do NOT use for "release sides alive" experiments.
function M.release_pair(linker)
	M.destroy_pair(linker, "manual_cleanup")
end

local function capture_friend_flag_state(ent)
	if not ent or not ent.Exists or not ent:Exists() then
		return { friendly = false, charm = false, persistent = false }
	end
	return {
		friendly = ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == true,
		charm = ent:HasEntityFlags(EntityFlag.FLAG_CHARM) == true,
		persistent = ent:HasEntityFlags(EntityFlag.FLAG_PERSISTENT) == true,
	}
end

local function restore_friend_flag_state(ent, state)
	if not ent or not ent.Exists or not ent:Exists() or type(state) ~= "table" then
		return
	end
	if state.friendly then
		ent:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
	end
	if state.charm then
		ent:AddEntityFlags(EntityFlag.FLAG_CHARM)
	end
	if state.persistent then
		ent:AddEntityFlags(EntityFlag.FLAG_PERSISTENT)
	end
end

local function capture_split_identity(ent)
	if not ent or not ent.Exists or not ent:Exists() then
		return { exists = false }
	end
	local tag = M.get_tag(ent)
	local linker = tag and tag.linker
	return {
		exists = true,
		ptr = GetPtrHash(ent),
		init_seed = ent.InitSeed,
		type = ent.Type,
		variant = ent.Variant,
		subtype = ent.SubType,
		hp = tonumber(ent.HitPoints) or 0,
		max_hp = tonumber(ent.MaxHitPoints) or 0,
		flags = ent.GetEntityFlags and ent:GetEntityFlags() or nil,
		friendly = ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == true,
		charm = ent:HasEntityFlags(EntityFlag.FLAG_CHARM) == true,
		persistent = ent:HasEntityFlags(EntityFlag.FLAG_PERSISTENT) == true,
		tag = tag ~= nil,
		is_linkee = M.is_linkee(ent) == true,
		has_linker = linker ~= nil and auxi.check_exists(linker),
		spawner_type = ent.SpawnerEntity and ent.SpawnerEntity.Type or nil,
		spawner_variant = ent.SpawnerEntity and ent.SpawnerEntity.Variant or nil,
	}
end

--- Probe-only: tear down Linker/binding but keep both sides as independent NPCs,
--- restoring the FRIENDLY/CHARM/PERSISTENT flags that restore_native_presentation clears.
--- Returns { ok, left, right, before, after, same_left, same_right }.
function M.debug_split_pair_preserve_sides(linker)
	if not linker or not M.is_linker(linker) then
		return { ok = false, reason = "no_linker" }
	end
	local effect = M.get_effect(linker)
	if not effect or effect.destroying then
		return { ok = false, reason = "no_effect" }
	end
	local left = effect.Left and effect.Left.ent
	local right = effect.Right and effect.Right.ent
	if not auxi.check_exists(left) or not auxi.check_exists(right) then
		return { ok = false, reason = "missing_side" }
	end

	local left_flags = capture_friend_flag_state(left)
	local right_flags = capture_friend_flag_state(right)
	local before = {
		left = capture_split_identity(left),
		right = capture_split_identity(right),
		linker_ptr = GetPtrHash(linker),
		pair_id = effect.pair_id,
	}

	M.destroy_pair(linker, "probe_split", { keep_sides = true })

	-- destroy_pair → restore_native_presentation clears friend flags; put them back.
	restore_friend_flag_state(left, left_flags)
	restore_friend_flag_state(right, right_flags)

	local after = {
		left = capture_split_identity(left),
		right = capture_split_identity(right),
		linker_exists = linker.Exists and linker:Exists() == true,
	}
	local same_left = before.left.ptr == after.left.ptr
		and before.left.init_seed == after.left.init_seed
	local same_right = before.right.ptr == after.right.ptr
		and before.right.init_seed == after.right.init_seed

	return {
		ok = same_left == true and same_right == true
			and after.left.tag ~= true
			and after.left.is_linkee ~= true
			and after.linker_exists ~= true,
		left = left,
		right = right,
		left_ptr = EntityPtr(left),
		right_ptr = EntityPtr(right),
		before = before,
		after = after,
		same_left = same_left == true,
		same_right = same_right == true,
		friend_flags = { left = left_flags, right = right_flags },
	}
end

function M.bind_pair(linker, left_ent, right_ent, left_info, right_info, opts)
	opts = opts or {}
	if not linker or not left_ent or not right_ent then
		return false
	end
	linker = linker:ToNPC() or linker
	left_ent = left_ent:ToNPC() or left_ent
	right_ent = right_ent:ToNPC() or right_ent

	local friendly = opts.friendly ~= false
	local pair_id = opts.pair_id
	local session_id = opts.session_id
	local owner_index = opts.owner_index
	local initial_tg = opts.initial_tg or "Left"
	-- HP main is independent of motion owner (baseinfo.tg).
	local left_is_main = opts.left_is_main
	if left_is_main == nil then
		left_is_main = true
	end

	local d = linker:GetData()
	local effect = {
		Left = {
			info = left_info or {},
			ent = left_ent,
			spawned = true,
			main = left_is_main == true,
		},
		Right = {
			info = right_info or {},
			ent = right_ent,
			spawned = true,
			main = left_is_main ~= true,
		},
		baseinfo = { tg = initial_tg },
		pair_id = pair_id,
		session_id = session_id,
		owner_index = owner_index,
		destroying = false,
		destroy_reason = nil,
	}
	d[OWN_KEY .. "effect"] = effect

	if opts.left_profile then
		M.apply_profile_to_slot(effect.Left, opts.left_profile, opts.left_profile_kind or "movement")
	end
	if opts.right_profile then
		M.apply_profile_to_slot(effect.Right, opts.right_profile, opts.right_profile_kind or "attack")
	end

	-- Linker + sides share QingSutureNativePair tag (side distinguishes linkee).
	d[TAG_KEY] = {
		linker = true,
		pair_id = pair_id,
		session_id = session_id,
	}
	effect.Left.bind_size = left_ent.Size
	effect.Right.bind_size = right_ent.Size
	left_ent:GetData()[TAG_KEY] = {
		linker = linker,
		side = "Left",
		pair_id = pair_id,
		session_id = session_id,
		bind_size = left_ent.Size,
		mixture_group = effect.Left.mixture_group,
		mixture_id = effect.Left.mixture_id,
		non_danger = effect.Left.non_danger == true
			or (effect.Left.info and effect.Left.info.non_danger == true)
			or false,
	}
	right_ent:GetData()[TAG_KEY] = {
		linker = linker,
		side = "Right",
		pair_id = pair_id,
		session_id = session_id,
		bind_size = right_ent.Size,
		mixture_group = effect.Right.mixture_group,
		mixture_id = effect.Right.mixture_id,
		non_danger = effect.Right.non_danger == true
			or (effect.Right.info and effect.Right.info.non_danger == true)
			or false,
	}

	if friendly then
		local flags = FRIEND_FLAG | EntityFlag.FLAG_PERSISTENT
		linker:AddEntityFlags(flags)
		left_ent:AddEntityFlags(flags)
		right_ent:AddEntityFlags(flags)
	end

	local health = M.compute_initial_health(effect, opts)
	linker.MaxHitPoints = health.MaxHitPoints
	linker.HitPoints = health.HitPoints
	if REPENTOGON and linker.SetShieldStrength and health.Shield and health.Shield > 0 then
		linker:SetShieldStrength(health.Shield)
	end
	effect.init = true
	effect.TotalVal = health.TotalVal
	-- Physical body owned by Movement/Left for the whole lifetime (≠ baseinfo.tg).
	effect.physical_owner = PHYSICAL_OWNER_SIDE
	apply_physical_owner_defaults(linker, effect)
	-- Authoritative HP bar on Linker; hide misleading side NPC bars for the bind lifetime.
	apply_stitch_hp_bar_ownership(linker, effect)

	left_ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	right_ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	linker:ClearEntityFlags(EntityFlag.FLAG_APPEAR)

	register_live_pair(linker, effect)
	return true
end

local function get_order_rnd(order_val, rnd_val)
	local ret = order_val * 5 + rnd_val
	if -1 <= order_val and order_val <= 0 then
		ret = order_val * 0.5 + rnd_val
		if order_val <= -0.5 and ret > -0.15 then
			ret = -0.15
		end
	end
	return ret
end

local function source_belongs_to_linker(source_ent, linker)
	if not source_ent or not linker then
		return false
	end
	local tag = M.get_tag(source_ent)
	if tag and tag.side and auxi.check_for_the_same(tag.linker, linker) then
		return true
	end
	local se = source_ent.SpawnerEntity
	if se then
		local stag = M.get_tag(se)
		if stag and stag.side and auxi.check_for_the_same(stag.linker, linker) then
			return true
		end
	end
	return false
end

function M.handle_linker_damage(linker, amount, flags, source, cooldown)
	local effect = M.get_effect(linker)
	if not effect then
		return
	end
	local base_tg = (effect.baseinfo and effect.baseinfo.tg) or "Left"
	for _, side in ipairs(SIDES) do
		local slot = effect[side]
		if slot and side_alive(slot) then
			local info = slot.info or {}
			local ret = auxi.check_if_any(info.special_damage, linker, amount, flags, source, cooldown, slot.ent)
			if ret ~= nil then
				return ret
			end
			local over_owner = effect[base_tg]
			local over_info = over_owner and over_owner.info or {}
			if base_tg == nil or side == base_tg or over_info.special_damage_over == nil then
				local ret2 = auxi.check_if_any(
					info.special_damage_over,
					linker,
					amount,
					flags,
					source,
					cooldown,
					slot.ent
				)
				if ret2 ~= nil then
					return ret2
				end
			end
		end
	end
	if source and source.Entity and source_belongs_to_linker(source.Entity, linker) then
		return false
	end
end

function M.handle_linkee_npc_collision(ent, collider, low)
	local tag = M.get_tag(ent)
	if not tag or not tag.side then
		return true
	end
	local effect = tag.linker and M.get_effect(tag.linker) or nil
	local slot = effect and effect[tag.side]
	local info = (slot and slot.info) or {}
	local ret = auxi.check_if_any(info.special_collision, ent, collider, low, tag.linker)
	if type(ret) == "table" and ret.ret ~= nil then
		return ret.ret
	end
	if ret ~= nil then
		return ret
	end
	return true
end

function M.update_linkee_after_native(ent)
	if not M.is_linkee(ent) then
		return
	end
	local tag = M.get_tag(ent)
	if not tag then
		return
	end
	local linker = tag.linker
	if not auxi.check_exists(linker) then
		release_orphaned_linkee(ent, "linker_gone")
		return
	end
	local effect = M.get_effect(linker)
	local slot = effect and tag.side and effect[tag.side]
	if not slot or not slot.ent or not auxi.check_for_the_same(slot.ent, ent) then
		release_orphaned_linkee(ent, "stale_backlink")
		return
	end
	slot.backlink_ok = true
	-- Diagnostic only: observe native death / ReGen. Does not gate linker HP rebuild.
	local probe = effect and effect.mortal_probe
	local sp = probe and probe.sides and tag.side and probe.sides[tag.side]
	if sp and sp.lethal_sent then
		sp.native_updates_after_lethal = (sp.native_updates_after_lethal or 0) + 1
		if auxi.check_exists(ent) and not auxi.check_all_exists(ent) then
			if not sp.seen_dead then
				sp.seen_dead = true
				trace_native_death(effect, tag.side, "SIDE_DEAD", ent, {
					native_updates_after_lethal = sp.native_updates_after_lethal,
				})
			end
		end
		local anim = ent_anim_name(ent)
		if type(anim) == "string" and string.sub(anim, 1, 5) == "ReGen" then
			if not sp.regen_seen then
				sp.regen_seen = true
				trace_native_death(effect, tag.side, "SIDE_REGEN", ent, {
					animation = anim,
					native_updates_after_lethal = sp.native_updates_after_lethal,
				})
			end
		end
		-- Aligned phase sample: end of this NPC's own update (before Linker may sync HP).
		local src = sp.native_source and sp.native_source.Ref
		local source_exists = src and src.Exists and src:Exists() == true
		local mortal_now = ent.HasMortalDamage and ent:HasMortalDamage() or false
		if sp.last_mortal == true and mortal_now == false and not sp.mortal_clear_traced then
			sp.mortal_clear_traced = true
			trace_native_death(effect, tag.side, "SIDE_MORTAL_CLEARED", ent, {
				phase = "NPC_UPDATE",
				native_updates_after_lethal = sp.native_updates_after_lethal,
			})
		end
		sp.last_mortal = mortal_now
		local force_npc = (sp.native_updates_after_lethal or 0) <= NATIVE_PHASE_FORCE_SAMPLES
		local npc_fp = side_phase_fingerprint(ent)
		if force_npc or npc_fp ~= sp.last_npc_fp then
			sp.last_npc_fp = npc_fp
			trace_native_death(effect, tag.side, "SIDE_NPC_UPDATE_END", ent, {
				native_updates_after_lethal = sp.native_updates_after_lethal,
				seen_dead = sp.seen_dead == true,
				source_exists = source_exists == true,
			})
		end
		if sp.native_updates_after_lethal == 1 then
			sp.source_exists_at_native_update_1 = source_exists == true
			cleanup_deferred_native_source(effect, tag.side, "after_native_update_1")
			trace_native_death(effect, tag.side, "source_removed", ent, {
				source_removed_frame = sp.source_removed_frame,
				source_remove_reason = sp.source_remove_reason,
			})
		end
		if (sp.native_updates_after_lethal or 0) > NATIVE_PROBE_WATCHDOG_UPDATES then
			sp.watchdog_stalled = true
		end
	end
	local info = slot.info or {}
	if info.special_on_own_update then
		auxi.check_if_any(info.special_on_own_update, ent, info)
	end
end

local function any_protect_self_side(effect)
	for _, side in ipairs(SIDES) do
		local slot = effect[side]
		local info = slot and slot.info or {}
		if info.protect_self and slot and auxi.check_exists(slot.ent) then
			return true
		end
	end
	return false
end

local function snapshot_ent_tvs(ent)
	if not auxi.check_exists(ent) then
		return nil
	end
	return {
		ptr = GetPtrHash(ent),
		type = ent.Type,
		variant = ent.Variant,
		subtype = ent.SubType,
		hp = ent.HitPoints,
		flags = ent:GetEntityFlags(),
		dead = ent.IsDead and ent:IsDead() or false,
	}
end

local function tvs_changed(a, b)
	if not a or not b then
		return false
	end
	return a.type ~= b.type or a.variant ~= b.variant or a.subtype ~= b.subtype
end

--- Rebuild linker HP from current sides (old Stitch: if not effect.init then recompute).
--- Timing: next update_linker after sentinel, after buffered lethal has had a chance to land,
--- before side HP sync. Probe must not gate this.
local function rebuild_linker_health_from_sides(linker, effect, opts)
	opts = opts or {}
	local health = M.compute_initial_health(effect, {})
	linker.MaxHitPoints = health.MaxHitPoints
	linker.HitPoints = health.HitPoints
	effect.TotalVal = health.TotalVal
	effect.init = true
	if REPENTOGON and linker.SetShieldStrength and health.Shield and health.Shield > 0 then
		linker:SetShieldStrength(health.Shield)
	end
	effect.health_needs_rebuild = nil
	effect.linker_sentinel_set = nil
end

--- Observe protect_self native death (diagnostic only).
--- Must NOT gate linker HP rebuild and must NOT destroy_pair.
--- Two distinct machines (do not mix):
---   A. check_all_type: success = TVS change or catalog rematch; fail only after
---      ≥1 native NPC_UPDATE post-lethal and no transition within
---      NATIVE_TRANSITION_WATCH_FRAMES (NOT protect_time — that is a revival count).
---   B. protect_self without check_all_type: success = observed dead window
---      (seen_dead) then alive again; mere survival after TakeDamage is NOT recovery.
---      Watchdog may mark stalled; it does not auto-fail this round.
--- Returns: "pending" | "confirmed" | "failed"
local function evaluate_mortal_probe(effect)
	local probe = effect and effect.mortal_probe
	if not probe or not probe.active then
		return nil
	end
	probe.sides = probe.sides or {}
	local pending, confirmed, failed = false, false, false
	for _, side in ipairs(SIDES) do
		local slot = effect[side]
		local info = slot and slot.info or {}
		local sp = probe.sides[side]
		if sp and sp.lethal_sent and not sp.resolved then
			local exists = slot and auxi.check_exists(slot.ent)
			local alive = side_alive(slot)
			if alive then
				local after = snapshot_ent_tvs(slot.ent)
				sp.ptr_after = after and after.ptr
				sp.tvs_after = after
				sp.mixture_after = { group = slot.mixture_group, id = slot.mixture_id }
				local changed = tvs_changed(sp.tvs_before, after)
				local mix_changed = (sp.mixture_before and (
					sp.mixture_before.group ~= slot.mixture_group
					or sp.mixture_before.id ~= slot.mixture_id
				))
				local rematched = mix_changed or sp.rematched_this_frame == true
				sp.rematched_this_frame = nil
				if info.check_all_type then
					if changed or rematched then
						sp.recovered = true
						sp.rematched = rematched == true
						sp.tvs_changed = changed
						sp.resolved = true
						clear_native_lethal_authorization(sp)
						confirmed = true
					elseif (sp.native_updates_after_lethal or 0) == 0 then
						-- Gaper etc.: native death/Morph has not run yet — stay pending.
						pending = true
					else
						sp.no_transition_frames = (sp.no_transition_frames or 0) + 1
						if sp.no_transition_frames > NATIVE_TRANSITION_WATCH_FRAMES then
							sp.resolved = true
							sp.no_transition = true
							clear_native_lethal_authorization(sp)
							failed = true
						else
							pending = true
						end
					end
				else
					-- Globin etc.: require a real dead window before counting revival.
					if sp.seen_dead then
						sp.recovered = true
						sp.resolved = true
						clear_native_lethal_authorization(sp)
						confirmed = true
					else
						if sp.watchdog_stalled then
							-- Diagnostic only — do not force fail while Source lifecycle is under test.
							sp.watchdog_note = "native_updates>" .. tostring(NATIVE_PROBE_WATCHDOG_UPDATES)
						end
						pending = true
					end
				end
			elseif info.protect_self and exists then
				sp.seen_dead = true
				pending = true
			else
				sp.resolved = true
				sp.final_dead = true
				clear_native_lethal_authorization(sp)
				failed = true
			end
		end
	end
	if confirmed then
		probe.transition_confirmed = true
	end
	if failed and not pending and not confirmed then
		for _, side in ipairs(SIDES) do
			local sp = probe.sides[side]
			if sp and sp.lethal_sent then
				local slot = effect[side]
				trace_native_death(effect, side, "probe_failed", slot and slot.ent, {
					seen_dead = sp.seen_dead == true,
					native_updates_after_lethal = sp.native_updates_after_lethal or 0,
					tvs_changed = sp.tvs_changed == true,
					rematched = sp.rematched == true,
					no_transition_frames = sp.no_transition_frames or 0,
					final_dead = sp.final_dead == true,
					no_transition = sp.no_transition == true,
				})
			end
		end
		snapshot_native_death_trace(effect, "failed")
		return "failed"
	end
	if confirmed and not pending then
		for _, side in ipairs(SIDES) do
			local sp = probe.sides[side]
			if sp and sp.lethal_sent and sp.recovered then
				local slot = effect[side]
				trace_native_death(effect, side, "probe_confirmed", slot and slot.ent, {
					seen_dead = sp.seen_dead == true,
					native_updates_after_lethal = sp.native_updates_after_lethal or 0,
					tvs_changed = sp.tvs_changed == true,
					rematched = sp.rematched == true,
					no_transition_frames = sp.no_transition_frames or 0,
					final_dead = sp.final_dead == true,
				})
			end
		end
		snapshot_native_death_trace(effect, "confirmed")
		return "confirmed"
	end
	if pending or (probe.base_rescued and not probe.transition_confirmed) then
		return "pending"
	end
	return nil
end

function M.update_linker(linker)
	if not linker or not M.is_linker(linker) then
		return
	end
	local d = linker:GetData()
	local effect = d[OWN_KEY .. "effect"]
	if not effect or not effect.baseinfo then
		return
	end
	if effect.destroying then
		return
	end

	-- Base already dead: stop controller work; MC_POST_ENTITY_KILL owns teardown.
	-- Do NOT clear effect / sides from NPC_UPDATE (would leave an empty linker shell).
	if linker:IsDead() then
		return
	end

	-- Mortal without protect_self: allow engine Kill → POST_ENTITY_KILL.
	local linker_mortal = linker.HasMortalDamage and linker:HasMortalDamage()
	if linker_mortal and not any_protect_self_side(effect) then
		return
	end

	-- Old Stitch: if not effect.init then rebuild from sides (after buffered damage,
	-- before side HP sync). Probe never gates this.
	if not effect.init then
		trace_native_death(effect, "Linker", "NEXT_LINKER_UPDATE_ENTRY", linker, {
			effect_init = false,
		})
		rebuild_linker_health_from_sides(linker, effect, { full = true })
		trace_native_death(effect, "Linker", "LINKER_REINIT", linker, {
			effect_init = effect.init == true,
		})
		linker_mortal = linker.HasMortalDamage and linker:HasMortalDamage()
	end

	linker:ClearEntityFlags(EntityFlag.FLAG_APPEAR)

	for _, side in ipairs(SIDES) do
		local slot = effect[side]
		if not slot then
			M.destroy_pair(linker, "orphaned")
			return
		end

		-- Bidirectional invariant: effect[side].ent tag must point back here.
		if auxi.check_exists(slot.ent) then
			local ok = side_forward_backlink_ok(linker, slot, side)
			if not ok then
				slot.backlink_ok = false
				slot.linker_forward_ok = false
				M.destroy_pair(linker, "orphaned")
				return
			end
			-- check_all_type rematch BEFORE treating as permanently dead.
			local rematched = maybe_refresh_check_all_type(slot)
			if rematched and effect.mortal_probe then
				effect.mortal_probe.check_all_type_rematch = true
				effect.mortal_probe.sides = effect.mortal_probe.sides or {}
				local sp = effect.mortal_probe.sides[side]
				if sp then
					sp.rematched_this_frame = true
				end
			end
		end

		local info = slot.info or {}
		if side_alive(slot) then
			-- Just left protect_self dead window (e.g. Globin ReGen): crush Base HP to native ratio.
			if slot.protect_counted_this_cycle then
				apply_native_recovery_hp_to_linker(linker, effect, slot, side)
			end
			slot.protect_counted_this_cycle = nil
			slot.protect_window_traced = nil
			-- Do not clear lethal gate while linker mortal flag may still stick;
			-- only allow another side lethal after linker leaves mortal.
			if not linker_mortal then
				slot.protect_cycle_lethal_sent = nil
			end
		elseif info.protect_self and auxi.check_exists(slot.ent) then
			-- Legitimate native death→revive window (Globin etc.). Do NOT orphan.
			local probe = effect.mortal_probe
			local sp = probe and probe.sides and probe.sides[side]
			if sp and sp.lethal_sent then
				if not sp.seen_dead then
					sp.seen_dead = true
					trace_native_death(effect, side, "SIDE_DEAD", slot.ent, {
						phase = "LINKER_UPDATE",
						protected_count = slot.protected or 0,
						protect_limit = info.protect_time or 1,
					})
				end
			end
			-- Old timing: count a revival only after Globin is dead but raw entity exists.
			if not slot.protect_counted_this_cycle then
				slot.protected = (slot.protected or 0) + 1
				slot.protect_counted_this_cycle = true
			end
			if (slot.protected or 0) > (info.protect_time or 1) then
				M.destroy_pair(linker, "pair_death")
				return
			end
			if not slot.protect_window_traced then
				slot.protect_window_traced = true
				trace_native_death(effect, side, "SIDE_PROTECTED_DEAD_WINDOW", slot.ent, {
					protected_count = slot.protected or 0,
					protect_limit = info.protect_time or 1,
					seen_dead = sp and sp.seen_dead == true,
				})
			end
		else
			M.destroy_pair(linker, "pair_death")
			return
		end
	end

	-- Probe is diagnostic only: record seen_dead / regen / TVS. Do not gate HP rebuild
	-- and do not tear down the pair from probe_failed.
	evaluate_mortal_probe(effect)

	-- Size + shadow follow permanent physical owner (Left), never min(both) / never tg swap.
	do
		local phys_slot, phys_name = physical_owner_slot(effect)
		if side_alive(phys_slot) then
			effect.physical_owner = phys_name
			effect.size = phys_slot.ent.Size or effect.size or 13
			effect.init_size = true
			linker.Size = effect.size
			local sh = read_shadow_size(phys_slot.ent)
			if sh ~= nil then
				apply_shadow_size(linker, sh)
			end
		elseif effect.size then
			linker.Size = effect.size
		end
	end

	for _, side in ipairs(SIDES) do
		local this = effect[side]
		if side_alive(this) then
			local ve = this.ent
			local vd = ve:GetData()
			if ve.Velocity:Length() < 0.5 then
				vd[OWN_KEY .. "Velocity_Punish"] = (vd[OWN_KEY .. "Velocity_Punish"] or 0) + 1
			else
				vd[OWN_KEY .. "Velocity_Punish"] = nil
			end
			if ve.GridCollisionClass >= 4 then
				local room = Game():GetRoom()
				local gidx = room:GetGridIndex(ve.Position)
				if vd[OWN_KEY .. "gridpos"] == gidx then
					vd[OWN_KEY .. "Velocity_Punish2"] = (vd[OWN_KEY .. "Velocity_Punish2"] or 0) + 1
				else
					vd[OWN_KEY .. "Velocity_Punish2"] = (vd[OWN_KEY .. "Velocity_Punish2"] or 0) - 5
					if vd[OWN_KEY .. "Velocity_Punish2"] <= 0 then
						vd[OWN_KEY .. "Velocity_Punish2"] = nil
					end
				end
				if vd[OWN_KEY .. "Velocity_Punish2"] == nil then
					vd[OWN_KEY .. "gridpos"] = gidx
				end
			else
				vd[OWN_KEY .. "Velocity_Punish2"] = nil
			end
		end
	end

	local baseinfo = effect.baseinfo
	local tgname = baseinfo.tg
	local tg = effect[tgname]
	if not side_alive(tg) then
		-- Old Stitch: protect_self death window is not orphan — pause controller this frame.
		if side_in_protected_dead_window(effect, tgname) then
			return
		end
		M.destroy_pair(linker, "orphaned")
		return
	end
	local tginfo = tg.info or {}
	local largest_order = M.get_order(tginfo.order, tg.ent, tgname, tginfo)
	d[OWN_KEY .. "Updated"] = true
	d[OWN_KEY .. "swap_counter"] = (d[OWN_KEY .. "swap_counter"] or 0) + 1

	local should_protect = false
	for _, side in ipairs(SIDES) do
		local this = effect[side]
		if side_alive(this) then
			local thisd = this.ent:GetData()
			local thisinfo = this.info or {}
			thisd[OWN_KEY .. "state_swap_counter"] = (thisd[OWN_KEY .. "state_swap_counter"] or 0) + 1
			thisd[OWN_KEY .. "rnd"] = thisd[OWN_KEY .. "rnd"]
				or (auxi.random_1() * (auxi.check_if_any(thisinfo.rnds, this.ent) or 1)
					+ (auxi.check_if_any(thisinfo.rnds_add, this.ent) or 0))
			if (thisd[OWN_KEY .. "state"] or this.ent.State) ~= this.ent.State then
				thisd[OWN_KEY .. "state_updated"] = true
				if thisd[OWN_KEY .. "state_swap_counter"] > 30 then
					thisd[OWN_KEY .. "rnd"] = auxi.random_1() * (auxi.check_if_any(thisinfo.rnds, this.ent) or 1)
						+ (auxi.check_if_any(thisinfo.rnds_add, this.ent) or 0)
					thisd[OWN_KEY .. "state_swap_counter"] = 0
				end
			end
			if linker.FrameCount % 120 == 0
				and (thisd[OWN_KEY .. "state_updated"] ~= true or thisd[OWN_KEY .. "state_swap_counter"] > 180)
			then
				thisd[OWN_KEY .. "rnd"] = auxi.random_1() * (auxi.check_if_any(thisinfo.rnds, this.ent) or 1)
					+ (auxi.check_if_any(thisinfo.rnds_add, this.ent) or 0)
			end
			thisd[OWN_KEY .. "state"] = this.ent.State
		end
	end

	local order_rnd = get_order_rnd(largest_order, tg.ent:GetData()[OWN_KEY .. "rnd"] or 0)
	for _, side in ipairs(SIDES) do
		local this = effect[side]
		if side_alive(this) then
			local thisinfo = this.info or {}
			local thisorder = M.get_order(thisinfo.order, this.ent, side, thisinfo)
			local this_order_rnd = get_order_rnd(thisorder, this.ent:GetData()[OWN_KEY .. "rnd"] or 0)
			if this_order_rnd > order_rnd then
				local order_diff = math.abs(thisorder - largest_order)
				local thr = tg_swap_cooldown_order_threshold
				local gf = Game():GetFrameCount()
				local last_sw = d[OWN_KEY .. "tg_swap_last_frame"]
				local min_int = tg_swap_min_interval_frames
				local allow_swap = true
				if order_diff <= thr and largest_order <= 2 then
					if last_sw ~= nil and (gf - last_sw) < min_int then
						allow_swap = false
					end
				else
					d[OWN_KEY .. "tg_swap_last_frame"] = nil
				end
				if allow_swap then
					local prev_tg_ent = tg.ent
					auxi.check_if_any(thisinfo.on_swap, this.ent, thisinfo, true)
					auxi.check_if_any(tginfo.on_swap, tg.ent, tginfo, false)
					tg = this
					tgname = side
					tginfo = thisinfo
					largest_order = thisorder
					order_rnd = this_order_rnd
					d[OWN_KEY .. "swap_counter"] = 0
					d[OWN_KEY .. "swap_vel_blend"] = {
						frame = 1,
						old_velocity = Vector(prev_tg_ent.Velocity.X, prev_tg_ent.Velocity.Y),
					}
					if order_diff <= thr then
						d[OWN_KEY .. "tg_swap_last_frame"] = gf
					end
				end
			end
			if thisinfo.protect_self then
				should_protect = true
			end
			-- AutoRegen: Linker remains authoritative (old Mixturer). Heal amount is
			-- sized so the subsequent ratio mirror yields +1 HP on this side,
			-- independent of partner / Linker MaxHP.
			if thisinfo.AutoRegen and linker.FrameCount % 10 == 2 then
				local side_max = math.max(1, tonumber(this.ent.MaxHitPoints) or 1)
				local lmax = math.max(1, tonumber(linker.MaxHitPoints) or 1)
				local delta = lmax / side_max
				local old_lhp = tonumber(linker.HitPoints) or 0
				local new_lhp = math.min(lmax, old_lhp + delta)
				linker.HitPoints = new_lhp
				note_hp_write(effect, "Linker", old_lhp, new_lhp, "auto_regen_linker")
			end
		end
	end

	-- Healthy HP snapshot only while no sentinel / mortal cycle is open.
	if effect.init and not linker_mortal then
		effect._hp_snapshot = capture_hp_snapshot(linker, effect)
	end

	local should_protect_health = false
	local any_shared_link_hp = false
	local linker_max = math.max(1, tonumber(linker.MaxHitPoints) or 1)
	local linker_hp = tonumber(linker.HitPoints) or 0
	local linker_is_sentinel = linker_hp > linker_max * 2
	for _, side in ipairs(SIDES) do
		local this = effect[side]
		if side_alive(this) then
			local info = this.info or {}
			if info.shared_link_hp then
				any_shared_link_hp = true
			end
			if info.protect_self then
				should_protect_health = true
			end

			-- Never copy sentinel / un-rebuilt / native-death-locked HP onto sides.
			-- Locked sides keep HP=-1 Mortal until Dead→ReGen resolves the probe.
			local skip_side_sync = (effect.init ~= true)
				or linker_is_sentinel
				or mortal_probe_side_locked(effect, side)
			if skip_side_sync then
				-- Isolation only. Native side keeps its own HP.
			elseif info.AutoRegen then
				-- Old Mixturer: AutoRegen still uses ratio mirror; when any side has
				-- protect_self, non-probe sides (incl. Boil) get the +1 pad.
				local old_hp = tonumber(this.ent.HitPoints) or 0
				local new_hp = this.ent.MaxHitPoints * linker.HitPoints / linker.MaxHitPoints
				if should_protect then
					new_hp = new_hp + 1
				end
				this.ent.HitPoints = new_hp
				note_hp_write(effect, side, old_hp, new_hp, "auto_regen_ratio_mirror")
			elseif should_protect then
				if info.protect_self then
					local old_hp = tonumber(this.ent.HitPoints) or 0
					local new_hp = this.ent.MaxHitPoints * linker.HitPoints / linker.MaxHitPoints
					local mortal_before = this.ent.HasMortalDamage and this.ent:HasMortalDamage() or false
					this.ent.HitPoints = new_hp
					local mortal_after = this.ent.HasMortalDamage and this.ent:HasMortalDamage() or false
					note_hp_write(effect, side, old_hp, new_hp, "protect_self_sync_from_linker")
					do
						local sp = effect.mortal_probe
							and effect.mortal_probe.sides
							and effect.mortal_probe.sides[side]
						if sp and sp.lethal_sent then
							local frame = Game():GetFrameCount()
							sp.hp_sync_count = (sp.hp_sync_count or 0) + 1
							sp.hp_sync_last_frame = frame
							sp.hp_sync_last_hp = new_hp
							if not sp.hp_sync_first_traced then
								sp.hp_sync_first_traced = true
								sp.hp_sync_first_frame = frame
								trace_native_death(effect, side, "SIDE_HP_SYNC_FIRST", this.ent, {
									old_hp = old_hp,
									new_hp = new_hp,
									mortal_before = mortal_before,
									mortal_after = mortal_after,
									reason = "protect_self_sync_from_linker",
								})
								if mortal_before == true and mortal_after == false then
									sp.mortal_clear_traced = true
									trace_native_death(effect, side, "SIDE_MORTAL_CLEARED", this.ent, {
										phase = "HP_SYNC_FIRST",
										old_hp = old_hp,
										new_hp = new_hp,
									})
								end
							elseif (mortal_before ~= mortal_after)
								or ((old_hp <= 0) ~= (new_hp <= 0))
							then
								trace_native_death(effect, side, "SIDE_HP_SYNC_STATE", this.ent, {
									old_hp = old_hp,
									new_hp = new_hp,
									mortal_before = mortal_before,
									mortal_after = mortal_after,
									hp_sync_count = sp.hp_sync_count,
									reason = "protect_self_sync_from_linker",
								})
							end
						end
					end
					if linker_mortal or (linker.HasMortalDamage and linker:HasMortalDamage()) then
						if not this.protect_cycle_lethal_sent then
							this.protect_cycle_lethal_sent = true
							if not effect.linker_mortal_traced then
								effect.linker_mortal_traced = true
								trace_native_death(effect, "Linker", "LINKER_MORTAL_ENTER", linker, {
									effect_init = effect.init == true,
								})
							end
							local limit = info.protect_time or 1
							local before = snapshot_ent_tvs(this.ent)
							effect.mortal_probe = effect.mortal_probe or {
								frame = Game():GetFrameCount(),
								active = true,
								sides = {},
								trace = {},
							}
							-- Keep prior chain in history before starting a new lethal cycle.
							if type(effect.mortal_probe.trace) == "table"
								and #effect.mortal_probe.trace > 0
								and effect.mortal_probe.native_lethal_sent
							then
								snapshot_native_death_trace(effect, "superseded")
								effect.mortal_probe.trace = {}
							end
							effect.mortal_probe.active = true
							effect.mortal_probe.sides = effect.mortal_probe.sides or {}
							effect.mortal_probe.pre_mortal = effect.mortal_probe.pre_mortal
								or effect._hp_snapshot
								or capture_hp_snapshot(linker, effect)
							effect.mortal_probe.trace = effect.mortal_probe.trace or {}
							effect.mortal_probe.trace_meta = {
								pair_id = effect.pair_id,
								side = side,
								mixture_group = this.mixture_group,
								mixture_id = this.mixture_id,
								protect_self = true,
								check_all_type = info.check_all_type == true,
								protect_time = limit,
								profile = info.name or info.real_anm2,
								source_mode = M.get_native_death_source_mode(),
								meusnil_cooldown = M.get_native_death_meusnil_cooldown(),
							}
							local sp = {
								lethal_sent = false,
								native_updates_after_lethal = 0,
								seen_dead = false,
								protect_counted = false,
								protect_allowed = true,
								protected_count = this.protected or 0,
								protect_limit = limit,
								ptr_before = before and before.ptr,
								tvs_before = before,
								mixture_before = {
									group = this.mixture_group,
									id = this.mixture_id,
								},
								flags_before = before and before.flags,
								hp_before = before and before.hp,
							}
							effect.mortal_probe.sides[side] = sp
							local pre_lethal = tonumber(this.ent.HitPoints) or 0
							this.ent.HitPoints = -1
							note_hp_write(effect, side, pre_lethal, -1, "protect_self_force_lethal_hp")
							sp.lethal_sent = true
							-- Authorize the full buffered death cycle on the side (not MeusNil lifetime).
							sp.native_lethal_authorized = true
							local source_kind = M.get_native_death_source_mode()
							trace_native_death(effect, side, "SIDE_LETHAL_SENT", this.ent, {
								tvs = before,
								protected_count = this.protected or 0,
								protect_limit = limit,
								source_kind = source_kind,
								native_lethal_authorized = true,
							})
							local dmg_ok, src_meta = send_native_lethal_damage(this.ent, effect, side, {
								source_kind = source_kind,
								linker = linker,
							})
							local after_immediate = snapshot_ent_tvs(this.ent)
							sp.native_damage_taken = dmg_ok == true
							sp.native_source_type = src_meta and src_meta.type
							sp.native_source_variant = src_meta and src_meta.variant
							sp.native_source_friendly = src_meta and src_meta.friendly
							sp.native_source_charm = src_meta and src_meta.charm
							sp.source_exists_after_take_damage = src_meta and src_meta.source_exists_after_take_damage
							sp.hp_after = after_immediate and after_immediate.hp
							sp.dead_after = after_immediate and after_immediate.dead
							sp.tvs_immediate_after = after_immediate
							if after_immediate and after_immediate.dead then
								sp.seen_dead = true
							end
							effect.mortal_probe.native_lethal_sent = true
							-- Do NOT port old has_friend_flag → linker:Kill().
							if info.on_kill then
								auxi.check_if_any(info.on_kill, this.ent)
							end
						end
					end
				else
					local old_hp = tonumber(this.ent.HitPoints) or 0
					local new_hp = this.ent.MaxHitPoints * linker.HitPoints / linker.MaxHitPoints + 1
					this.ent.HitPoints = new_hp
					note_hp_write(effect, side, old_hp, new_hp, "protect_window_non_probe_side")
				end
			else
				local old_hp = tonumber(this.ent.HitPoints) or 0
				local new_hp = this.ent.MaxHitPoints * linker.HitPoints / linker.MaxHitPoints
				this.ent.HitPoints = new_hp
				note_hp_write(effect, side, old_hp, new_hp, "normal_sync_from_linker")
			end
		end
	end
	-- Never run shared-link min-ratio while linker is sentinel or a side is death-locked.
	-- apply_shared_link_hp also excludes locked sides internally.
	if any_shared_link_hp and effect.init and not linker_is_sentinel then
		apply_shared_link_hp(linker, effect, tg)
	end
	if should_protect_health and (linker_mortal or (linker.HasMortalDamage and linker:HasMortalDamage())) then
		-- Old Stitch: +99999 is a one-frame pad over queued lethal, then init=nil
		-- so the next update_linker rebuilds official HP.
		if not effect.linker_sentinel_set then
			local old_hp = tonumber(linker.HitPoints) or 0
			linker.HitPoints = old_hp + 99999
			note_hp_write(effect, "Linker", old_hp, linker.HitPoints, "protect_self_sentinel_99999")
			effect.init = nil
			effect.linker_sentinel_set = true
			effect.mortal_probe = effect.mortal_probe or {
				frame = Game():GetFrameCount(),
				active = true,
				sides = {},
			}
			effect.mortal_probe.active = true
			effect.mortal_probe.pre_mortal = effect.mortal_probe.pre_mortal
				or effect._hp_snapshot
				or capture_hp_snapshot(linker, effect)
			trace_native_death(effect, "Linker", "LINKER_SENTINEL_SET", linker, {
				effect_init = false,
			})
		end
	else
		effect.linker_mortal_traced = nil
	end

	if d[OWN_KEY .. "swap_counter"] == 0 then
		for _, side in ipairs(SIDES) do
			local this = effect[side]
			if side_alive(this) then
				local thisd = this.ent:GetData()
				if thisd[OWN_KEY .. "GridCollision"] then
					Attribute_holder.try_rewind_attribute(
						this.ent,
						"GridCollisionClass",
						thisd[OWN_KEY .. "GridCollision"]
					)
					thisd[OWN_KEY .. "GridCollision"] = nil
				end
			end
		end
	end

	effect.baseinfo.tg = tgname
	tg = effect[tgname]
	tginfo = tg.info or {}

	-- Physical defaults come from Movement/Left; tg only supplies motion + explicit overrides.
	local phys_slot, phys_name = physical_owner_slot(effect)
	local phys_ent = (side_alive(phys_slot) and phys_slot.ent) or tg.ent
	phys_name = phys_name or PHYSICAL_OWNER_SIDE

	local base_grid_collision = phys_ent.GridCollisionClass
	local add_vel = Vector(0, 0)
	for _, side in ipairs(SIDES) do
		local this = effect[side]
		if side_alive(this) then
			local info = this.info or {}
			local thisd = this.ent:GetData()
			if side ~= tgname then
				if info.follow_gridcollision then
					if auxi.check_if_any(info.follow_gridcollision, this.ent, tg.ent) then
						thisd[OWN_KEY .. "GridCollision"] = thisd[OWN_KEY .. "GridCollision"]
							or Attribute_holder.try_hold_attribute(
								this.ent,
								"GridCollisionClass",
								function(_ent)
									return tg.ent.GridCollisionClass
								end
							)
					elseif thisd[OWN_KEY .. "GridCollision"] then
						Attribute_holder.try_rewind_attribute(
							this.ent,
							"GridCollisionClass",
							thisd[OWN_KEY .. "GridCollision"]
						)
						thisd[OWN_KEY .. "GridCollision"] = nil
					end
				end
				auxi.check_if_any(info.special, this.ent, linker, false, info)
				add_vel = add_vel + (auxi.check_if_any(info.AddVelocity, this.ent) or Vector(0, 0))
			else
				auxi.check_if_any(info.special, this.ent, linker, true, info)
			end
			-- Merge non-owner grids into Left-seeded base (tg may contribute when ≠ Left).
			if side ~= phys_name then
				base_grid_collision = M.elect_grid_collision(base_grid_collision, this.ent.GridCollisionClass)
			end
		end
	end

	-- Position authority: linker keeps engine collision Position by default.
	-- naturally_move_back / AddVelocity adjust linker; delta_pos is explicit Extra override.
	if tginfo.naturally_move_back then
		local cnt = d[OWN_KEY .. "swap_counter"] or 0
		if tginfo.Reset_counter then
			cnt = math.min(cnt, tg.ent:GetData()[OWN_KEY .. "state_swap_counter"] or 0)
		end
		if type(tginfo.naturally_move_back) == "number" then
			cnt = cnt * tginfo.naturally_move_back
		end
		local mov_rate = auxi.check_lerp(cnt, swap_move_info).val
		local o_center_pos = Vector(0, 0)
		local ocnt = 0
		for _, side in ipairs(SIDES) do
			if side ~= tgname and side_alive(effect[side]) then
				o_center_pos = o_center_pos + effect[side].ent.Position
				ocnt = ocnt + 1
			end
		end
		if ocnt > 0 then
			o_center_pos = o_center_pos / ocnt
		else
			o_center_pos = linker.Position
		end
		linker.Position = mov_rate * o_center_pos + (1 - mov_rate) * linker.Position
	end
	if add_vel and (add_vel.X ~= 0 or add_vel.Y ~= 0) then
		linker.Position = linker.Position + add_vel
	end
	local delta_pos = auxi.check_if_any(tginfo.delta_pos, tg.ent)

	-- EntityCollisionClass: Left default; check_collisionclass on current tg may override.
	if tginfo.check_collisionclass then
		linker.EntityCollisionClass = auxi.check_if_any(
			tginfo.check_collisionclass,
			tg.ent,
			tg.ent.EntityCollisionClass
		) or phys_ent.EntityCollisionClass
	else
		linker.EntityCollisionClass = phys_ent.EntityCollisionClass
	end

	-- CollisionDamage: Left default; explicit CollisionDamage capability on tg may override.
	if tginfo.CollisionDamage then
		linker.CollisionDamage = auxi.check_if_any(tginfo.CollisionDamage, tg.ent)
			or phys_ent.CollisionDamage
	else
		linker.CollisionDamage = phys_ent.CollisionDamage
	end

	-- Mass: Left default; SetMass on tg may override for that profile.
	if auxi.check_if_any(tginfo.SetMass, tg.ent) then
		if not d[OWN_KEY .. "Mass"] then
			d[OWN_KEY .. "Mass"] = linker.Mass
		end
		linker.Mass = tg.ent.Mass
	else
		linker.Mass = phys_ent.Mass
		d[OWN_KEY .. "Mass"] = nil
	end

	linker.CanShutDoors = tg.ent.CanShutDoors
	linker.GridCollisionClass = base_grid_collision
	local phys_pre = {
		position = Vector(linker.Position.X, linker.Position.Y),
		velocity = Vector(linker.Velocity.X, linker.Velocity.Y),
		mass = tonumber(linker.Mass),
		size = tonumber(linker.Size),
	}
	-- Default: do NOT snap linker to tg. Explicit delta_pos Extra still may override.
	local desired_pos = Vector(linker.Position.X, linker.Position.Y)
	local position_authority = "linker"
	if delta_pos then
		desired_pos = tg.ent.Position + delta_pos
		linker.Position = desired_pos
		position_authority = "delta_pos"
	end
	linker.PositionOffset = tg.ent.PositionOffset

	local desired_vel = Vector(0, 0)
	if auxi.check_if_any(tginfo.prevent_velocity, tg.ent, tginfo) then
		desired_vel = Vector(0, 0)
		linker.Velocity = desired_vel
	else
		local finalVelocity = tg.ent.Velocity
		local blendState = d[OWN_KEY .. "swap_vel_blend"]
		local blendSnapThreshold = 7
		if largest_order and largest_order >= 0 then
			blendSnapThreshold = 14
		end
		if largest_order and largest_order >= 2 then
			desired_vel = finalVelocity
			linker.Velocity = desired_vel
			d[OWN_KEY .. "swap_vel_blend"] = nil
		elseif blendState and blendState.frame and blendState.frame <= 2 and blendState.old_velocity then
			local oldRatio, newRatio = 0.66, 0.33
			if blendState.frame == 2 then
				oldRatio, newRatio = 0.33, 0.66
			end
			local weightedVelocity = blendState.old_velocity * oldRatio + finalVelocity * newRatio
			if (weightedVelocity - finalVelocity):Length() < blendSnapThreshold then
				desired_vel = finalVelocity
				linker.Velocity = desired_vel
				d[OWN_KEY .. "swap_vel_blend"] = nil
			else
				desired_vel = weightedVelocity
				linker.Velocity = desired_vel
				blendState.frame = blendState.frame + 1
				if blendState.frame > 2 then
					d[OWN_KEY .. "swap_vel_blend"] = nil
				else
					d[OWN_KEY .. "swap_vel_blend"] = blendState
				end
			end
		else
			desired_vel = finalVelocity
			linker.Velocity = desired_vel
			d[OWN_KEY .. "swap_vel_blend"] = nil
		end
	end
	record_controller_physics_write(linker, effect, desired_pos, desired_vel, phys_pre)
	if effect.physics_trace then
		effect.physics_trace.position_authority = position_authority
	end

	-- Native sides follow linker Position (tg AI supplies Velocity only).
	local tgs = tg.ent:GetSprite()
	local anchor = linker.Position
	for _, side in ipairs(SIDES) do
		local this = effect[side]
		if side_alive(this) then
			local info = this.info or {}
			if side == tgname then
				this.ent.Size = linker.Size
				this.ent.Position = anchor
			else
				this.ent.Size = 0
				if info.protect_pos then
					if type(info.protect_pos) == "function" then
						auxi.check_if_any(info.protect_pos, this.ent, tginfo)
					else
						local room = Game():GetRoom()
						this.ent.Position = room:GetClampedPosition(anchor, 0)
					end
				else
					this.ent.Position = anchor
				end
				if auxi.check_if_any(info.KeepTarget, this.ent) then
					this.ent.TargetPosition = anchor
				end
				if auxi.check_if_any(info.HelpVelocity, this.ent) then
					this.ent.Velocity = linker.Velocity
				end
				-- Mixturer Flip sync (presentation-adjacent facing; does not write SpriteScale/Size).
				local thiss = this.ent:GetSprite()
				if auxi.check_if_any(info.protect_flip, this.ent) then
					tgs.FlipX = thiss.FlipX
				else
					thiss.FlipX = tgs.FlipX
				end
				if auxi.check_if_any(info.protect_flipY, this.ent) then
					tgs.FlipY = thiss.FlipY
				else
					thiss.FlipY = tgs.FlipY
				end
			end
			if auxi.check_if_any(info.KeepTarget_Special, this.ent) then
				this.ent.TargetPosition = linker.Position
			end
		end
	end

	if physics_probe_enabled then
		sample_physics_frame(linker, effect)
	end
end

-- --- Callbacks ---

-- Veto / filter only (Stitch Edition ToCall). on_damage fires in post_ToCall.
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = nil,
	Function = function(_, ent, amt, flag, source, cooldown)
		if M.is_linker(ent) then
			return M.handle_linker_damage(ent, amt, flag, source, cooldown)
		end
		if M.is_linkee(ent) then
			local tag = M.get_tag(ent)
			local side = tag and tag.side
			local linker = tag and tag.linker
			local effect = linker and M.get_effect(linker)
			local sp = effect and effect.mortal_probe and effect.mortal_probe.sides and side
				and effect.mortal_probe.sides[side]
			local source_based = is_internal_linkee_damage(amt, flag, cooldown, source)
			local cycle_authorized = is_native_lethal_authorized(effect, side)
			local locked = mortal_probe_side_locked(effect, side)
			-- Cycle token survives MeusNil Remove; needed for buffered lethal commit.
			local internal = source_based or cycle_authorized
			local src_ent = source and source.Entity
			local source_exists = src_ent and src_ent.Exists and src_ent:Exists() == true
			local source_marker = is_native_death_source(source)
			local decision = internal and "allow" or "veto"

			-- Log every callback while a native-death cycle is open (incl. nil Source).
			if locked or (sp and sp.lethal_sent) or source_based then
				trace_native_death(effect, side, "LINKLEE_DAMAGE_CALLBACK", ent, {
					amt = amt,
					damage_flags = flag,
					cooldown = cooldown,
					internal = internal == true,
					source_based = source_based == true,
					cycle_authorized = cycle_authorized == true,
					locked = locked == true,
					source_exists = source_exists == true,
					source_type = src_ent and src_ent.Type,
					source_variant = src_ent and src_ent.Variant,
					source_subtype = src_ent and src_ent.SubType,
					source_marker = source_marker == true,
					decision = decision,
				})
			end

			if not internal then
				return false
			end
		end
	end,
})

-- Stitch Edition post_ToCall: fire on_damage AFTER the damage veto callback stage.
table.insert(M.post_ToCall, #M.post_ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = LINKER_TYPE,
	Function = function(_, ent, amt, flag, source, cooldown)
		if not M.is_linker(ent) then
			return
		end
		local effect = M.get_effect(ent)
		if not effect or effect.destroying then
			return
		end
		for _, side in ipairs(SIDES) do
			local slot = effect[side]
			if slot and side_alive(slot) then
				local info = slot.info or {}
				auxi.check_if_any(info.on_damage, ent, amt, flag, source, cooldown, slot.ent)
			end
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_NPC_COLLISION,
	params = nil,
	Function = function(_, ent, col, low)
		if M.is_linkee(ent) then
			return M.handle_linkee_npc_collision(ent, col, low)
		end
		if M.is_linker(ent) then
			if M.is_linker(col) then
				return true
			end
			if M.is_linkee(col) then
				return true
			end
			if col and col.SpawnerEntity and source_belongs_to_linker(col, ent) then
				return true
			end
			if physics_probe_enabled then
				record_linker_npc_collision(ent, col)
			end
			local effect = M.get_effect(ent)
			if effect then
				for _, side in ipairs(SIDES) do
					local slot = effect[side]
					if slot and side_alive(slot) then
						local info = slot.info or {}
						local ret = auxi.check_if_any(info.special_collision, slot.ent, col, low, ent)
						if type(ret) == "table" and ret.ret ~= nil then
							return ret.ret
						end
						if ret ~= nil then
							return ret
						end
					end
				end
			end
		end
	end,
})

local function block_proj_vs_linkee_or_own_base(proj, col)
	if M.is_linkee(col) then
		return true
	end
	if M.is_linker(col) and proj and proj.SpawnerEntity and source_belongs_to_linker(proj, col) then
		return true
	end
end

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PROJECTILE_COLLISION,
	params = nil,
	Function = function(_, ent, col, _low)
		return block_proj_vs_linkee_or_own_base(ent, col)
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_BOMB_COLLISION,
	params = nil,
	Function = function(_, ent, col, _low)
		return block_proj_vs_linkee_or_own_base(ent, col)
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION,
	params = nil,
	Function = function(_, _ent, col, _low)
		if M.is_linkee(col) then
			return true
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_NPC_UPDATE,
	params = LINKER_TYPE,
	Function = function(_, ent)
		if not M.is_linker(ent) then
			return
		end
		local effect = M.get_effect(ent)
		if not effect then
			-- Empty tagged linker must not persist (spawn→bind same stack is FrameCount 0).
			if ent.FrameCount and ent.FrameCount > 0 then
				ent:Remove()
			end
			return
		end
		if effect.destroying then
			return
		end
		-- IsDead / HasMortalDamage: do not tear down here.
		-- protect_self mortal probe runs inside update_linker; final teardown is
		-- MC_POST_ENTITY_KILL (or side-grace failure → destroy_pair).
		if ent:IsDead() then
			return
		end
		M.update_linker(ent)
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_NPC_UPDATE,
	params = nil,
	Function = function(_, ent)
		M.update_linkee_after_native(ent)
		-- Standalone matrix sources (non-linkee) also need deferred Remove after first native update.
		try_remove_deferred_marked_source_for_ent(ent)
	end,
})

-- Later than all NPC updates: compare with SIDE_NPC_UPDATE_END to see same-frame HP sync.
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		sample_side_post_update_traces()
	end,
})

-- Authoritative Base death: tear down A/B, then Remove custom linker (no corpse).
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_KILL,
	params = LINKER_TYPE,
	Function = function(_, ent)
		if not M.is_linker(ent) then
			return
		end
		local effect = M.get_effect(ent)
		if not effect or effect.destroying then
			return
		end
		-- keep_linker=false: Type 996 has no native death presentation to preserve.
		M.destroy_pair(ent, "pair_death", { keep_linker = false })
	end,
})

-- Orphan fallback: Base removed without Kill (Morph / room / special cleanup).
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
	params = nil,
	Function = function(_, ent)
		if not ent then
			return
		end
		local ptr = GetPtrHash(ent)
		local rec = live_pairs[ptr]
		if not rec or not rec.effect then
			return
		end
		if rec.effect.destroying then
			return
		end
		-- Linker vanished; destroy sides with stored effect (GetData may be unreliable).
		M.destroy_pair(rec.linker or ent, "orphaned", {
			keep_linker = true,
			effect = rec.effect,
		})
	end,
})

return M

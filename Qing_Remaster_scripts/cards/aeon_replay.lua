-- Aeon attack snapshot / persistent track / special epic (replay).
-- Brimstone: FireBrimstone owns width; Tainted Azazel dm=0.5 → factory 0.1 then restore DM.
-- Tech X: FireTechXLaser(radius) owns ring+beam width; never SetScale after factory.
-- Technology: still may apply_recorded_laser_scale (untested width path).
-- Sword: Spirit Sword Mimic (geometry hit) for family=sword; Bone Club still fire_Sword.
-- Mimic/source follows Ghost; never force sword world Position onto Ghost.
local tear_snapshot = require("Qing_Remaster_scripts.auxiliary.tear_snapshot")
local laser_helper = require("Qing_Remaster_scripts.auxiliary.laser_helper")
local classifier = require("Qing_Remaster_scripts.callbacks.attack_source_classifier")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local SpiritSword = require("Qing_Remaster_scripts.mimics.Spirit_Sword_holder")
local LaserHolder = require("Qing_Remaster_scripts.mimics.Laser_holder")

local M = {}

local LASER_TIMEOUT_MARGIN = 8

local function encode_flags(flags)
	if flags == nil then return nil end
	local ok, tbl = pcall(function() return auxi.bit2table(flags) end)
	if ok then return tbl end
	return nil
end

local function decode_flags(tbl)
	if type(tbl) ~= "table" then return tbl end
	local ok, bits = pcall(function() return auxi.table2bit(tbl) end)
	if ok then return bits end
	return nil
end

local function vec_tbl(v)
	if not v then return {x = 0, y = 0} end
	return {x = tonumber(v.X) or 0, y = tonumber(v.Y) or 0}
end

local function tbl_vec(t)
	if type(t) ~= "table" then return Vector(0, 0) end
	return Vector(tonumber(t.x) or 0, tonumber(t.y) or 0)
end

local function color_tbl(c)
	if not c then return nil end
	local t = {
		r = c.R, g = c.G, b = c.B, a = c.A,
		ro = c.RO, go = c.GO, bo = c.BO,
	}
	if c.GetColorize then
		local ok, cz = pcall(function() return c:GetColorize() end)
		if ok and cz then
			t.cz_r = cz.R
			t.cz_g = cz.G
			t.cz_b = cz.B
			t.cz_a = cz.A
		end
	end
	return t
end

local function tbl_color(t)
	if type(t) ~= "table" then return Color(1, 1, 1, 1) end
	local col = Color(
		tonumber(t.r) or 1,
		tonumber(t.g) or 1,
		tonumber(t.b) or 1,
		tonumber(t.a) or 1,
		tonumber(t.ro) or 0,
		tonumber(t.go) or 0,
		tonumber(t.bo) or 0
	)
	if col.SetColorize and t.cz_r ~= nil then
		pcall(function()
			col:SetColorize(
				tonumber(t.cz_r) or 0,
				tonumber(t.cz_g) or 0,
				tonumber(t.cz_b) or 0,
				tonumber(t.cz_a) or 0
			)
		end)
	end
	return col
end

local function sprite_scale_tbl(ent)
	if not ent or not ent.SpriteScale then return nil end
	return vec_tbl(ent.SpriteScale)
end

local function entity_alive(ent)
	return ent and ent.Exists and ent:Exists() and not (ent.IsDead and ent:IsDead())
end

function M.member_role(attack, member)
	if not attack or not member then return nil end
	local hash = GetPtrHash(member)
	local rec = attack.bound_members and attack.bound_members[hash]
	return rec and rec.role or "primary"
end

local function club_hitbox_subtype()
	if KnifeSubType and KnifeSubType.CLUB_HITBOX then
		return KnifeSubType.CLUB_HITBOX
	end
	return 4
end

local function is_club_hitbox(member)
	return member
		and member.Type == EntityType.ENTITY_KNIFE
		and member.SubType == club_hitbox_subtype()
end

local function hitbox_parent_knife(member)
	if not member then return nil end
	if member.GetHitboxParentKnife then
		local ok, parent = pcall(function() return member:GetHitboxParentKnife() end)
		if ok and parent then return parent end
	end
	return nil
end

local function is_sword_beam_tear(member)
	if not member or member.Type ~= EntityType.ENTITY_TEAR then return false end
	local v = member.Variant or -1
	if TearVariant then
		if TearVariant.SWORD_BEAM and v == TearVariant.SWORD_BEAM then return true end
		if TearVariant.TECH_SWORD_BEAM and v == TearVariant.TECH_SWORD_BEAM then return true end
	end
	return v == 47 or v == 49
end

local function spirit_sword_variant(v)
	if KnifeVariant then
		if KnifeVariant.SPIRIT_SWORD and v == KnifeVariant.SPIRIT_SWORD then return true end
		if KnifeVariant.TECH_SWORD and v == KnifeVariant.TECH_SWORD then return true end
	end
	return v == 10 or v == 11
end

local function bone_club_variant(v)
	if KnifeVariant then
		if KnifeVariant.BONE_CLUB and v == KnifeVariant.BONE_CLUB then return true end
		if KnifeVariant.BONE_SCYTHE and v == KnifeVariant.BONE_SCYTHE then return true end
		if KnifeVariant.BERSERK_CLUB and v == KnifeVariant.BERSERK_CLUB then return true end
		if KnifeVariant.DONKEY_JAWBONE and v == KnifeVariant.DONKEY_JAWBONE then return true end
		if KnifeVariant.NOTCHED_AXE and v == KnifeVariant.NOTCHED_AXE then return true end
	end
	return v == 1 or v == 2 or v == 3 or v == 9
end

local function is_melee_swing_knife(member)
	if not member or member.Type ~= EntityType.ENTITY_KNIFE then return false end
	if is_club_hitbox(member) then return false end
	local v = member.Variant or -1
	return spirit_sword_variant(v) or bone_club_variant(v)
end

local function swing_anim_kind(knife)
	local spr = knife and knife.GetSprite and knife:GetSprite()
	local name = spr and spr.GetAnimation and spr:GetAnimation() or nil
	if type(name) ~= "string" then return "other", name end
	local lower = string.lower(name)
	if string.find(lower, "charged", 1, true) then
		return "charged", name
	end
	if string.find(lower, "spin", 1, true) then
		return "spin", name
	end
	if string.find(lower, "idle", 1, true) then
		return "idle", name
	end
	if string.find(lower, "attack", 1, true) or string.find(lower, "swing", 1, true) then
		return "attack", name
	end
	return "other", name
end

-- Fallback only. Vanilla Spirit Sword animation suffix is NOT direction authority.
local function direction_from_anim_name(name)
	if type(name) ~= "string" then
		return nil
	end
	local lower = string.lower(name)
	if string.find(lower, "left", 1, true) then
		return Vector(-1, 0)
	end
	if string.find(lower, "right", 1, true) then
		return Vector(1, 0)
	end
	if string.find(lower, "up", 1, true) then
		return Vector(0, -1)
	end
	if string.find(lower, "down", 1, true) then
		return Vector(0, 1)
	end
	return nil
end

local function melee_attack_still_open(ev)
	local id = ev and ev._attack_id
	if id == nil then return false end
	local ok, registry = pcall(require, "Qing_Remaster_scripts.callbacks.attack_registry")
	if not ok or not registry or not registry.GetAttack then return false end
	local attack = registry.GetAttack(id)
	return attack ~= nil and attack.active == true and attack.ending ~= true
end

function M.should_record_member(attack, member)
	if not member then return false end
	-- Derived hitbox / sword beams: never their own Aeon track.
	if is_club_hitbox(member) or hitbox_parent_knife(member) then
		return false
	end
	if is_sword_beam_tear(member) then
		return false
	end
	local role = M.member_role(attack, member)
	if role == "derived" then return false end
	return role == "primary" or role == "proxy"
end

local function is_meus_fetus(member)
	return member
		and member.Type == EntityType.ENTITY_EFFECT
		and member.Variant == enums.Entities.ID_EFFECT_MeusFetus
end

--- "snapshot" | "persistent" | "special" | "sword_action" | "melee_swing"(legacy)
function M.get_record_mode(member, event)
	if not member then return "snapshot" end
	local family = event and event.family

	if family == "epic" or is_meus_fetus(member) then
		return "special"
	end
	-- Spirit Sword / Bone Club: lightweight action events (normal / spin), not full state machine.
	if family == "sword" or family == "bone_club" then
		return "sword_action"
	end
	if is_melee_swing_knife(member) then
		return "sword_action"
	end
	if family == "knife" then
		return "persistent"
	end
	if family == "brimstone" or family == "technology" or family == "techx" then
		return "persistent"
	end
	if member.Type == EntityType.ENTITY_LASER then
		return "persistent"
	end
	if member.Type == EntityType.ENTITY_KNIFE then
		if is_club_hitbox(member) or is_melee_swing_knife(member) then
			return "sword_action"
		end
		return "persistent"
	end
	return "snapshot"
end

function M.snapshot_member(member, player, event)
	if not member or not player then return nil end
	local offset = member.Position - player.Position
	local family = (event and event.family) or "unknown"
	local kind = "generic"
	local payload = {
		type = member.Type,
		variant = member.Variant,
		subtype = member.SubType,
		velocity = vec_tbl(member.Velocity),
		collision_damage = member.CollisionDamage,
		color = color_tbl(member.Color),
	}

	if member.Type == EntityType.ENTITY_TEAR then
		kind = "tear"
		family = family ~= "unknown" and family or "tear"
		local snap = tear_snapshot.capture(member)
		payload.damage = (snap and snap.damage) or member.CollisionDamage
		payload.flags = encode_flags((snap and snap.flags) or member.TearFlags)
		payload.variant = (snap and snap.variant) or member.Variant
		payload.scale = (snap and snap.scale) or member.Scale
		if snap and snap.sprite_scale then
			payload.sprite_scale = vec_tbl(snap.sprite_scale)
		else
			payload.sprite_scale = sprite_scale_tbl(member)
		end
		payload.height = (snap and snap.height) or member.Height
		payload.falling_speed = (snap and snap.falling_speed) or member.FallingSpeed
		payload.falling_accel = (snap and snap.falling_accel) or member.FallingAcceleration
		payload.color = color_tbl((snap and snap.color) or member.Color)
		payload.velocity = vec_tbl((snap and snap.velocity) or member.Velocity)
		payload.mass = member.Mass
		payload.timeout = member.Timeout
		payload.sprite_rotation = member.SpriteRotation
		payload.collision_damage = nil
	elseif member.Type == EntityType.ENTITY_BOMB then
		kind = "bomb"
		family = family ~= "unknown" and family or "bomb"
		local bomb = member:ToBomb()
		if bomb then
			payload.explosion_damage = bomb.ExplosionDamage
			payload.radius_multiplier = bomb.RadiusMultiplier
			payload.flags = encode_flags(bomb.Flags)
			payload.is_fetus = bomb.IsFetus
			payload.timeout = bomb.Timeout
		end
	elseif member.Type == EntityType.ENTITY_LASER then
		-- Snapshot fallback only; preferred path is persistent track.
		kind = "laser"
		family = family ~= "unknown" and family or "laser"
		local laser = member:ToLaser()
		if laser then
			payload.angle = laser.Angle
			payload.max_distance = laser.MaxDistance
			payload.timeout = laser.Timeout
			payload.disable_follow_parent = laser.DisableFollowParent
			payload.tear_flags = encode_flags(laser.TearFlags)
			if laser.Radius then payload.radius = laser.Radius end
		end
	elseif member.Type == EntityType.ENTITY_KNIFE then
		kind = (family == "sword") and "sword" or "knife"
		family = family ~= "unknown" and family or kind
		local knife = member:ToKnife()
		if knife then
			payload.rotation = knife.Rotation
			payload.charge = knife.Charge
		end
	end

	return {
		mode = "snapshot",
		family = family,
		kind = kind,
		offset = vec_tbl(offset),
		payload = payload,
	}
end

local function laser_follow_parent(laser)
	if not laser then return false end
	local parent = laser.Parent
	if not parent or not parent.Exists or not parent:Exists() then
		return false
	end
	if laser.DisableFollowParent == true then
		return false
	end
	return true
end

local function laser_base(member, family, player)
	local laser = member:ToLaser()
	local follow = laser_follow_parent(laser)
	-- HomingType / CurveStrength: probe-only; not Replay authority.
	-- laser_scale / sprite_scale: diagnostic only for factory Brimstone/Tech X.
	-- Width for those families comes from Fire* factory inputs (DamageMultiplier / Radius).
	-- damage_multiplier: factory input. May be transient at init; sample lock after FirstUpdate.
	local owner_type = nil
	if player and player.GetPlayerType then
		local ok, pt = pcall(function() return player:GetPlayerType() end)
		if ok then owner_type = tonumber(pt) end
	end
	local base = {
		type = member.Type,
		variant = member.Variant,
		subtype = member.SubType,
		collision_damage = member.CollisionDamage,
		damage_multiplier = laser_helper.read_damage_multiplier(laser),
		owner_player_type = owner_type,
		color = color_tbl(member.Color),
		tear_flags = laser and encode_flags(laser.TearFlags) or nil,
		disable_follow_parent = not follow,
		anchor_mode = follow and "parent" or "world",
		laser_scale = laser_helper.read_laser_scale(laser),
		sprite_scale = sprite_scale_tbl(laser or member),
	}
	return base, laser
end

local function knife_base(member, family, kind)
	local knife = member:ToKnife()
	return {
		type = member.Type,
		variant = member.Variant,
		subtype = member.SubType,
		collision_damage = member.CollisionDamage,
		color = color_tbl(member.Color),
		scale = member.Scale,
		sprite_scale = sprite_scale_tbl(member),
		charge = knife and knife.Charge or nil,
		max_distance = knife and knife.MaxDistance or nil,
	}, knife
end

local function sample_laser_state(laser, player, family)
	local po = laser.PositionOffset or Vector.Zero
	local is_techx = family == "techx" or (laser.SubType == 2)
	local st = {
		visible = laser.Visible and true or false,
		-- Mouth / visual offset is independent of parent/world topology.
		pox = po.X,
		poy = po.Y,
	}
	-- Tech X: Angle / MaxDistance / SpriteRotation are not Replay authority.
	if not is_techx then
		st.angle = laser.Angle
		st.max_distance = laser.MaxDistance
		if laser.SpriteRotation ~= nil then
			st.sprite_rotation = laser.SpriteRotation
		end
	end
	if laser_follow_parent(laser) then
		-- Parent-driven: ox/oy = parent(anchor) relative to player.
		local parent = laser.Parent
		local aoff = parent.Position - player.Position
		st.ox = aoff.X
		st.oy = aoff.Y
		st.anchor_mode = "parent"
	else
		-- World-driven: ox/oy = laser world relative to player.
		local offset = laser.Position - player.Position
		st.ox = offset.X
		st.oy = offset.Y
		st.anchor_mode = "world"
	end
	if laser.Radius then
		st.radius = laser.Radius
	end
	-- FirstUpdate + DamageMultiplier samples (settle on finalize; do not invent from CollisionDamage).
	if laser.FirstUpdate ~= nil then
		st.first_update = laser.FirstUpdate and true or false
	end
	st.damage_multiplier = laser_helper.read_damage_multiplier(laser)
	-- Tech X: Velocity is FireTechXLaser direction input only (not post-spawn write-back).
	if is_techx then
		local vel = laser.Velocity or Vector.Zero
		st.vx = vel.X
		st.vy = vel.Y
	end
	return st
end

local function sample_knife_state(knife, player, kind)
	local offset = knife.Position - player.Position
	local po = knife.PositionOffset or Vector.Zero
	local flying = false
	if knife.IsFlying then
		local ok, v = pcall(function() return knife:IsFlying() end)
		flying = ok and v and true or false
	end
	local st = {
		ox = offset.X,
		oy = offset.Y,
		pox = po.X,
		poy = po.Y,
		rotation = knife.Rotation,
		charge = knife.Charge,
		path_offset = knife.PathOffset,
		path_follow_speed = knife.PathFollowSpeed,
		max_distance = knife.MaxDistance,
		is_flying = flying,
		collision_damage = knife.CollisionDamage,
		visible = knife.Visible and true or false,
	}
	if kind == "sword" then
		st.scale = knife.Scale
		st.sprite_scale = sprite_scale_tbl(knife)
	end
	return st
end

function M.begin_persistent_track(member, player, event, frame)
	if not member or not player then return nil end
	local family = (event and event.family) or "unknown"
	local kind = "generic"
	local base
	local first_state

	if member.Type == EntityType.ENTITY_LASER then
		kind = "laser"
		if family == "unknown" then family = "brimstone" end
		base = select(1, laser_base(member, family, player))
		first_state = sample_laser_state(member:ToLaser() or member, player, family)
	elseif member.Type == EntityType.ENTITY_KNIFE then
		-- Melee swings use begin_melee_swing_event; Mom's Knife only here.
		if is_club_hitbox(member) or is_melee_swing_knife(member) or family == "sword" or family == "bone_club" then
			return nil
		end
		kind = "knife"
		if family == "unknown" then family = "knife" end
		base = select(1, knife_base(member, family, kind))
		first_state = sample_knife_state(member:ToKnife() or member, player, kind)
	else
		return nil
	end

	return {
		mode = "persistent",
		family = family,
		kind = kind,
		start_frame = tonumber(frame) or 0,
		end_frame = nil,
		base = base,
		states = {first_state},
		-- Runtime only (not saved): latest wrapper + ptr
		_ptr = GetPtrHash(member),
		_entity = member,
	}
end

function M.sample_persistent_track(track, member, player)
	if not track or not player or not entity_alive(member) then
		return false
	end
	track._entity = member
	track._ptr = GetPtrHash(member)
	local st
	if track.kind == "laser" then
		local laser = member:ToLaser()
		if not laser then return false end
		st = sample_laser_state(laser, player, track.family)
		-- Capture factory DamageMultiplier on first post-init sample only.
		track.base = track.base or {}
		if track.base._damage_multiplier_locked ~= true
			and st
			and st.first_update == false
		then
			local dm = tonumber(st.damage_multiplier)
			if dm == nil then
				dm = laser_helper.read_damage_multiplier(laser)
			end
			if dm ~= nil then
				track.base.damage_multiplier = dm
			end
			-- Runtime-only lock; stripped on finalize (not saved).
			track.base._damage_multiplier_locked = true
		end
	elseif track.kind == "knife" or track.kind == "sword" then
		local knife = member:ToKnife()
		if not knife then return false end
		st = sample_knife_state(knife, player, track.kind)
	else
		return false
	end
	track.states[#track.states + 1] = st
	return true
end

--- Collapse laser PositionOffset init settle into base.position_offset.
--- Skip first ~2 frames; if remaining samples match last value (≥80%), treat as stable.
local function settle_laser_position_offset(track)
	local states = track and track.states
	if type(states) ~= "table" or #states < 1 then return end
	track.base = track.base or {}
	local base = track.base
	local samples = {}
	for i = 1, #states do
		local st = states[i]
		if st and st.pox ~= nil then
			samples[#samples + 1] = {
				x = tonumber(st.pox) or 0,
				y = tonumber(st.poy) or 0,
			}
		end
	end
	if #samples < 1 then return end
	local last = samples[#samples]
	local stable = {x = last.x, y = last.y}
	local eps = 0.25
	local start_i = (#samples >= 3) and 3 or 1
	local match, total = 0, 0
	for i = start_i, #samples do
		total = total + 1
		local s = samples[i]
		if math.abs(s.x - stable.x) <= eps and math.abs(s.y - stable.y) <= eps then
			match = match + 1
		end
	end
	local stable_ok = total < 1 or (match / total) >= 0.8
	base.position_offset = {x = stable.x, y = stable.y}
	if stable_ok then
		base.po_dynamic = false
		for i = 1, #states do
			states[i].pox = nil
			states[i].poy = nil
			states[i].dynamic_pox = nil
			states[i].dynamic_poy = nil
		end
	else
		base.po_dynamic = true
		for i = 1, #states do
			local st = states[i]
			if st and st.pox ~= nil then
				st.dynamic_pox = st.pox
				st.dynamic_poy = st.poy
			end
		end
	end
end

--- Collapse Tech X Radius init settle (often FirstUpdate placeholder) into base.techx_spawn_radius.
--- Do not use first-frame Radius as FireTechXLaser spawn argument.
local function settle_techx_radius(track)
	if not track or track.family ~= "techx" then return end
	local states = track.states
	if type(states) ~= "table" or #states < 1 then return end
	track.base = track.base or {}
	local base = track.base
	local eps = 0.25

	local samples = {}
	for i = 1, #states do
		local st = states[i]
		local r = st and tonumber(st.radius)
		if r ~= nil then
			samples[#samples + 1] = {
				i = i,
				r = r,
				fu = st.first_update,
			}
		end
	end
	if #samples < 1 then return end

	local spawn_r, spawn_idx = nil, nil
	-- Prefer first sample after FirstUpdate init (FirstUpdate == false).
	for si = 1, #samples do
		local s = samples[si]
		if s.fu == false then
			spawn_r = s.r
			spawn_idx = s.i
			break
		end
	end
	-- No FirstUpdate mark: skip first sample when a later radius exists (init settle).
	if spawn_r == nil then
		if #samples >= 2 then
			spawn_r = samples[2].r
			spawn_idx = samples[2].i
		else
			spawn_r = samples[1].r
			spawn_idx = samples[1].i
		end
	end
	if spawn_r == nil then return end

	-- Optional: if post-init window is mostly one value, prefer that as spawn (first stable).
	local match, total = 0, 0
	for si = 1, #samples do
		local s = samples[si]
		if s.i >= spawn_idx then
			total = total + 1
			if math.abs(s.r - spawn_r) <= eps then
				match = match + 1
			end
		end
	end
	-- If first post-init value is a brief blip, take longest-stable later value.
	if total >= 3 and (match / total) < 0.5 then
		local best_r, best_n = spawn_r, 0
		local cur_r, cur_n = nil, 0
		for si = 1, #samples do
			local s = samples[si]
			if s.i >= spawn_idx then
				if cur_r ~= nil and math.abs(s.r - cur_r) <= eps then
					cur_n = cur_n + 1
				else
					cur_r = s.r
					cur_n = 1
				end
				if cur_n > best_n then
					best_n = cur_n
					best_r = cur_r
				end
			end
		end
		spawn_r = best_r
	end

	base.techx_spawn_radius = spawn_r

	-- Drop init transient from state stream so replay never applies Radius=80 first.
	for i = 1, #states do
		local st = states[i]
		if st then
			if st.radius ~= nil and i <= spawn_idx then
				st.radius = spawn_r
			end
			st.first_update = nil
			st.radius_init = nil
		end
	end
end

--- Prefer first post-FirstUpdate GetDamageMultiplier. Never invent from CollisionDamage.
local function settle_laser_damage_multiplier(track)
	if not track or track.kind ~= "laser" then return end
	track.base = track.base or {}
	local base = track.base
	if tonumber(base.damage_multiplier) ~= nil then
		return
	end
	local states = track.states
	if type(states) ~= "table" then return end
	local fallback = nil
	for i = 1, #states do
		local st = states[i]
		local dm = st and tonumber(st.damage_multiplier)
		if dm ~= nil then
			if st.first_update == false then
				base.damage_multiplier = dm
				return
			end
			if fallback == nil and st.first_update ~= true then
				fallback = dm
			elseif fallback == nil and i >= 2 then
				fallback = dm
			end
		end
	end
	if fallback ~= nil then
		base.damage_multiplier = fallback
	end
end

function M.finalize_persistent_track(track, end_frame)
	if not track then return nil end
	track.end_frame = tonumber(end_frame) or track.start_frame
	track._entity = nil
	track._ptr = nil
	if track.end_frame < track.start_frame then
		track.end_frame = track.start_frame
	end
	-- Ensure at least one state
	if type(track.states) ~= "table" or #track.states < 1 then
		track.states = {{ox = 0, oy = 0}}
	end
	if track.kind == "laser" then
		settle_laser_position_offset(track)
		-- Before settle_techx_radius clears first_update marks.
		settle_laser_damage_multiplier(track)
		settle_techx_radius(track)
		if track.base then
			track.base._damage_multiplier_locked = nil
		end
	end
	return track
end

function M.begin_special_event(member, player, event, frame)
	if not member or not player then return nil end
	local family = (event and event.family) or "epic"
	local offset = member.Position - player.Position
	local d = member:GetData()
	local Epic_holder = require("Qing_Remaster_scripts.mimics.Epic_holder")
	local ok_key = Epic_holder.own_key
	local cooldown = tonumber(d[ok_key .. "Cooldown"]) or 0
	local damage = tonumber(d[ok_key .. "Damage"])
	local flags = d[ok_key .. "Tearflags"]
	local color = d[ok_key .. "Color"]
	local spr = member:GetSprite()
	local scale = spr and spr.Scale and vec_tbl(spr.Scale) or {x = 1, y = 1}

	return {
		mode = "special",
		kind = "epic",
		family = family,
		start_frame = tonumber(frame) or 0,
		impact_frame = nil,
		end_frame = nil,
		-- Final impact target (overwritten each sample; no trajectory stream).
		target_offset = vec_tbl(offset),
		base = {
			type = member.Type,
			variant = member.Variant,
			subtype = member.SubType,
			damage = damage or member.CollisionDamage,
			flags = encode_flags(flags),
			color = color_tbl(color or member.Color),
			scale = scale,
			cooldown = cooldown,
		},
		_ptr = GetPtrHash(member),
		_entity = member,
	}
end

function M.sample_special_event(ev, member, player)
	if not ev or not player or not entity_alive(member) then
		return false
	end
	ev._entity = member
	ev._ptr = GetPtrHash(member)
	local offset = member.Position - player.Position
	ev.target_offset = {x = offset.X, y = offset.Y}
	ev.states = nil
	return true
end

function M.finalize_special_event(ev, end_frame)
	if not ev then return nil end
	ev.end_frame = tonumber(end_frame) or ev.start_frame
	ev.impact_frame = ev.end_frame
	ev._entity = nil
	ev._ptr = nil
	ev.states = nil
	if type(ev.target_offset) ~= "table" then
		ev.target_offset = {x = 0, y = 0}
	end
	local start_f = tonumber(ev.start_frame) or 0
	local dur = math.max(0, (tonumber(ev.impact_frame) or start_f) - start_f)
	if type(ev.base) == "table" then
		ev.base.cooldown = dur
	end
	return ev
end

local MELEE_SWING_GRACE = 4

local function vec_from_any(v)
	if not v then return nil end
	if type(v) == "userdata" and v.X ~= nil then
		return Vector(v.X, v.Y)
	end
	if type(v) == "table" and (v.x ~= nil or v.X ~= nil) then
		return Vector(tonumber(v.x or v.X) or 0, tonumber(v.y or v.Y) or 0)
	end
	return nil
end

local function resolve_melee_fire_direction(member, player, event)
	-- Returns dir, source. source is diagnostic only (not saved).
	local dir = vec_from_any(event and event.direction)
	if dir and dir:Length() > 0.01 then
		return dir:Normalized(), "event"
	end
	local atk = event and event.attack
	dir = vec_from_any(atk and atk.direction)
	if dir and dir:Length() > 0.01 then
		return dir:Normalized(), "attack"
	end
	if player and player.GetAimDirection then
		local ok, aim = pcall(function()
			return player:GetAimDirection()
		end)
		if ok and aim and aim:Length() > 0.01 then
			return aim:Normalized(), "aim"
		end
	end
	if player and player.GetShootingJoystick then
		local ok, joy = pcall(function()
			return player:GetShootingJoystick()
		end)
		if ok and joy and joy:Length() > 0.01 then
			return joy:Normalized(), "joystick"
		end
	end
	local knife = member and (member.ToKnife and member:ToKnife() or member)
	local rot = knife and tonumber(knife.Rotation)
	if rot ~= nil then
		return auxi.get_by_rotate(Vector(1, 0), rot):Normalized(), "knife_rotation"
	end
	return nil, nil
end

function M.begin_sword_action_event(member, player, event, frame, action_kind)
	if not member or not player then return nil end
	local knife = member:ToKnife() or member
	local family = (event and event.family) or "sword"
	local variant = member.Variant or 0
	if bone_club_variant(variant) then
		family = "bone_club"
	elseif family == "unknown" or family == nil then
		family = "sword"
	end
	action_kind = action_kind or "normal"
	if action_kind ~= "spin" then
		action_kind = "normal"
	end
	local anim_class, anim_name = swing_anim_kind(knife)
	-- Authority: event/attack/aim/joystick/rotation → anim suffix only as last fallback.
	-- Do NOT let AttackRight / SpinRight overwrite a resolved aim.
	local dir, dir_source = resolve_melee_fire_direction(member, player, event)
	if not dir or dir:Length() <= 0.01 then
		dir = direction_from_anim_name(anim_name)
		dir_source = "anim_fallback"
	end
	if not dir or dir:Length() <= 0.01 then
		dir = Vector(1, 0)
		dir_source = "default_right"
	end
	dir = dir:Normalized()
	local rot = dir:GetAngleDegrees()
	local tech = false
	if KnifeVariant and KnifeVariant.TECH_SWORD and variant == KnifeVariant.TECH_SWORD then
		tech = true
	elseif variant == 11 then
		tech = true
	end
	local default_cd = (action_kind == "spin") and 15 or 8
	local start_f = tonumber(frame) or 0
	return {
		mode = "sword_action",
		kind = action_kind,
		family = family,
		start_frame = start_f,
		end_frame = start_f + default_cd,
		impact_frame = start_f + default_cd,
		target_offset = {x = 0, y = 0},
		base = {
			family = family,
			action_kind = action_kind,
			variant = variant,
			subtype = member.SubType,
			damage = member.CollisionDamage,
			rotation = rot,
			direction = vec_tbl(dir),
			-- anim is engine-reported only; may disagree with direction (e.g. AttackRight + Up).
			anim = anim_name,
			anim_class = anim_class,
			tech = tech,
			color = color_tbl(member.Color),
			scale = knife.Scale,
			sprite_scale = sprite_scale_tbl(knife),
			tear_flags = knife.TearFlags and encode_flags(knife.TearFlags) or nil,
			cooldown = default_cd,
		},
		_ptr = GetPtrHash(member),
		-- Runtime diagnostic only; never persisted by save codec.
		_direction_source = dir_source,
	}
end

--- Legacy name: POST_FIRE_SWORD → normal sword_action.
function M.begin_melee_swing_event(member, player, event, frame)
	return M.begin_sword_action_event(member, player, event, frame, "normal")
end

function M.sample_melee_swing_event(ev, member, player)
	-- sword_action is one-shot; no per-frame sampling.
	return true
end

function M.melee_swing_should_finalize(ev)
	return true
end

function M.finalize_melee_swing_event(ev, end_frame)
	if not ev then return nil end
	local start_f = tonumber(ev.start_frame) or 0
	local planned = tonumber(ev.end_frame)
	local ef = tonumber(end_frame)
	if ef == nil then ef = planned or start_f end
	-- sword_action is one-shot at record time; keep planned factory cooldown window.
	if (ev.mode == "sword_action" or ev.kind == "normal" or ev.kind == "spin")
		and planned ~= nil and planned > ef
	then
		ef = planned
	end
	if ef < start_f then ef = start_f end
	ev.end_frame = ef
	ev.impact_frame = ef
	ev._entity = nil
	ev._ptr = nil
	ev._attack_id = nil
	ev._start_isaac_frame = nil
	return ev
end

--- Cardinal head overlay name from aim vector (Isaac: Y<0 = Up).
function M.head_anim_from_direction(dir)
	if not dir or dir:Length() < 0.1 then
		return nil
	end
	if math.abs(dir.X) >= math.abs(dir.Y) then
		if dir.X < 0 then
			return "HeadLeft"
		end
		return "HeadRight"
	end
	if dir.Y < 0 then
		return "HeadUp"
	end
	return "HeadDown"
end

--- Runtime-only: lock Aeon recording head aim for a sword_action window (not saved).
function M.set_sword_visual_aim(rec, ev)
	if not rec or not ev then
		return
	end
	local base = ev.base or {}
	local d = base.direction
	local dir
	if type(d) == "table" then
		dir = Vector(tonumber(d.x) or 0, tonumber(d.y) or 0)
	elseif d then
		dir = d
	end
	if not dir or dir:Length() < 0.1 then
		return
	end
	dir = dir:Normalized()
	local until_f = tonumber(ev.end_frame) or tonumber(ev.start_frame) or 0
	rec.visual_aim = {
		direction = Vector(dir.X, dir.Y),
		until_frame = until_f,
		authority = "sword",
	}
	-- If pose for start_frame already captured earlier this tick, patch overlay.
	local sf = tonumber(ev.start_frame)
	local head = M.head_anim_from_direction(dir)
	if sf ~= nil and head and type(rec.frames) == "table" then
		local fr = rec.frames[sf]
		if fr and fr.overlay_anim ~= head then
			fr.overlay_anim = head
		end
	end
end

local function ensure_spirit_sword_weapon_watch(rec, player)
	if not rec or not player or not player.GetWeapon then
		return
	end
	local spirit_wt = (WeaponType and WeaponType.WEAPON_SPIRIT_SWORD) or 13
	local ok_w, weapon = pcall(function()
		return player:GetWeapon(1)
	end)
	if not ok_w or not weapon or not weapon.GetWeaponType or not weapon.GetMainEntity then
		return
	end
	local ok_t, wt = pcall(function()
		return weapon:GetWeaponType()
	end)
	if not ok_t or wt ~= spirit_wt then
		return
	end
	local ok_m, main = pcall(function()
		return weapon:GetMainEntity()
	end)
	if ok_m and main and main.Type == EntityType.ENTITY_KNIFE then
		-- Idempotent: will not reset last_class / spin_recorded for same InitSeed.
		M.note_sword_watch(rec, main)
	end
end

--- Watch main Spirit Sword anim for first non-spin → spin transition (one action).
--- Idempotent for the same EntityKnife ptr + InitSeed (persistent sword must keep transition history).
function M.note_sword_watch(rec, member)
	if not rec or not member or not is_melee_swing_knife(member) then
		return
	end
	rec.sword_watch = rec.sword_watch or {}
	local ptr = GetPtrHash(member)
	local seed = member.InitSeed
	local old = rec.sword_watch[ptr]
	local knife = member:ToKnife() or member
	local cls = select(1, swing_anim_kind(knife))

	if old and old.init_seed == seed then
		-- Same persistent sword: keep last_class / spin_recorded; only refresh wrapper.
		old.entity = member
		return
	end

	rec.sword_watch[ptr] = {
		entity = member,
		init_seed = seed,
		last_class = cls,
		spin_recorded = false,
	}
end

function M.sample_sword_watch(rec, player, frame)
	if not rec or not player then return end
	ensure_spirit_sword_weapon_watch(rec, player)
	local watch = rec.sword_watch
	if type(watch) ~= "table" then return end
	local max_n = tonumber(rec.max_events)
	local dead = {}
	for ptr, w in pairs(watch) do
		local ent = w and w.entity
		if not entity_alive(ent) then
			dead[#dead + 1] = ptr
		else
			-- Same native entity may yield a new wrapper; keep InitSeed identity.
			if w.init_seed ~= nil and ent.InitSeed ~= w.init_seed then
				dead[#dead + 1] = ptr
			else
				w.entity = ent
				local cls = select(1, swing_anim_kind(ent:ToKnife() or ent))
				local prev = w.last_class
				if prev ~= "spin" and cls == "spin" and not w.spin_recorded then
					local cur = #(rec.attacks or {}) + #(rec.persistent_tracks or {}) + #(rec.special_events or {})
					if max_n == nil or cur < max_n then
						local ev = M.begin_sword_action_event(ent, player, {family = "sword"}, frame, "spin")
						if ev then
							rec.next_sequence = (rec.next_sequence or 0) + 1
							ev.sequence = rec.next_sequence
							rec.special_events = rec.special_events or {}
							rec.special_events[#rec.special_events + 1] = ev
							w.spin_recorded = true
							M.set_sword_visual_aim(rec, ev)
						end
					end
				elseif cls ~= "spin" then
					w.spin_recorded = false
				end
				w.last_class = cls
			end
		end
	end
	for i = 1, #dead do
		watch[dead[i]] = nil
	end
end

local function mark_replay(ent, own_key)
	if not ent then return end
	local d = ent:GetData()
	d[own_key .. "replay"] = true
	classifier.MarkIgnore(ent)
end

function M.spawn_from_snapshot(entry, ghost, owner_player, own_key)
	if not entry or not ghost or not ghost:Exists() then return nil end
	local payload = entry.payload or {}
	local pos = ghost.Position + tbl_vec(entry.offset)
	local room = Game():GetRoom()
	if room and room.GetClampedPosition then
		pos = room:GetClampedPosition(pos, 0)
	end
	local vel = tbl_vec(payload.velocity)
	local typ = tonumber(payload.type)
	local variant = tonumber(payload.variant) or 0
	local subtype = tonumber(payload.subtype) or 0
	if not typ then return nil end

	local ent = Isaac.Spawn(typ, variant, subtype, pos, vel, owner_player)
	if not ent then return nil end
	mark_replay(ent, own_key)

	if typ == EntityType.ENTITY_TEAR then
		local tear = ent:ToTear()
		if tear then
			local tpay = type(payload.tear) == "table" and payload.tear or payload
			local ss = tpay.sprite_scale or payload.sprite_scale
			tear_snapshot.apply(tear, {
				damage = tpay.damage or payload.collision_damage,
				flags = decode_flags(tpay.flags or payload.tear_flags),
				variant = tpay.variant or variant,
				scale = tpay.scale or payload.scale,
				sprite_scale = ss,
				height = tpay.height or payload.height,
				falling_speed = tpay.falling_speed or payload.falling_speed,
				falling_accel = tpay.falling_accel or payload.falling_acceleration or tpay.falling_acceleration,
				color = tbl_color(tpay.color or payload.color),
			})
			tear.Velocity = vel
			if payload.mass ~= nil then tear.Mass = payload.mass end
			if payload.timeout ~= nil then tear.Timeout = payload.timeout end
			if payload.sprite_rotation ~= nil then tear.SpriteRotation = payload.sprite_rotation end
		end
	elseif typ == EntityType.ENTITY_LASER then
		local laser = ent:ToLaser()
		if laser then
			if payload.angle ~= nil then laser.Angle = payload.angle end
			if payload.max_distance ~= nil then laser.MaxDistance = payload.max_distance end
			if payload.timeout ~= nil then laser.Timeout = payload.timeout end
			if payload.disable_follow_parent ~= nil then
				laser.DisableFollowParent = payload.disable_follow_parent
			end
			local lf = decode_flags(payload.tear_flags)
			if lf ~= nil then laser.TearFlags = lf end
			if payload.collision_damage ~= nil then
				laser.CollisionDamage = payload.collision_damage
			end
			if payload.color then laser.Color = tbl_color(payload.color) end
			if payload.radius ~= nil and laser.Radius then laser.Radius = payload.radius end
			laser.Parent = nil
			laser.SpawnerEntity = owner_player
		end
	elseif typ == EntityType.ENTITY_BOMB then
		local bomb = ent:ToBomb()
		if bomb then
			if payload.explosion_damage ~= nil then bomb.ExplosionDamage = payload.explosion_damage end
			if payload.radius_multiplier ~= nil then bomb.RadiusMultiplier = payload.radius_multiplier end
			local bf = decode_flags(payload.flags)
			if bf ~= nil then bomb.Flags = bf end
			if payload.timeout ~= nil then bomb.Timeout = payload.timeout end
			if payload.collision_damage ~= nil then bomb.CollisionDamage = payload.collision_damage end
			if payload.color then bomb.Color = tbl_color(payload.color) end
		end
	elseif typ == EntityType.ENTITY_KNIFE then
		local knife = ent:ToKnife()
		if knife then
			if payload.rotation ~= nil then knife.Rotation = payload.rotation end
			if payload.charge ~= nil then knife.Charge = payload.charge end
			if payload.collision_damage ~= nil then knife.CollisionDamage = payload.collision_damage end
			if payload.color then knife.Color = tbl_color(payload.color) end
		end
	else
		if payload.collision_damage ~= nil then ent.CollisionDamage = payload.collision_damage end
		if payload.color then ent.Color = tbl_color(payload.color) end
	end

	return ent
end

local function track_state_at(track, t)
	local states = track.states
	if type(states) ~= "table" or #states < 1 then return nil end
	local start_f = tonumber(track.start_frame) or 0
	local idx = (tonumber(t) or 0) - start_f + 1
	if idx < 1 then idx = 1 end
	if idx > #states then idx = #states end
	return states[idx]
end

local function peak_knife_range(track)
	local best = 0
	local base = track and track.base
	if base and tonumber(base.max_distance) then
		best = math.max(best, tonumber(base.max_distance) or 0)
	end
	local states = track and track.states
	if type(states) == "table" then
		for i = 1, #states do
			local st = states[i]
			local md = st and tonumber(st.max_distance)
			local po = st and tonumber(st.path_offset)
			if md then best = math.max(best, md) end
			if po then best = math.max(best, math.abs(po)) end
		end
	end
	if best < 1 then best = 100 end
	return best
end

local function nearly_eq(a, b, eps)
	if a == nil and b == nil then return true end
	if a == nil or b == nil then return false end
	return math.abs(tonumber(a) - tonumber(b)) <= (eps or 0.01)
end

local function apply_position_offset(ent, st)
	if not ent or not st then return end
	local px = st.dynamic_pox ~= nil and tonumber(st.dynamic_pox) or tonumber(st.pox)
	local py = st.dynamic_poy ~= nil and tonumber(st.dynamic_poy) or tonumber(st.poy)
	if px == nil and py == nil then return end
	ent.PositionOffset = Vector(px or 0, py or 0)
end

local function request_laser_sample_recalc(laser)
	if not laser or not laser.RecalculateSamplesNextUpdate then return end
	pcall(function()
		laser:RecalculateSamplesNextUpdate()
	end)
end

local function laser_timeout_for(track, t)
	local end_f = tonumber(track.end_frame) or tonumber(track.start_frame) or 0
	local start_f = tonumber(track.start_frame) or 0
	local remain = math.max(1, end_f - (tonumber(t) or start_f) + 1)
	return remain + LASER_TIMEOUT_MARGIN
end

local function laser_desired_pos(ghost, st)
	return ghost.Position + Vector(tonumber(st.ox) or 0, tonumber(st.oy) or 0)
end

local function laser_fire_opts(reason, ghost)
	return {
		mode = "untracked",
		reason = reason,
		emitter = ghost,
		role = "derived",
		damage_multiplier = 1,
	}
end

--- Brimstone / Technology finish only. Never call for Tech X.
--- Default: no relocate_origin (factory already spawned at desired pos).
local function finish_replay_laser(laser, track, ghost, owner_player, own_key, st, t)
	if not laser then return nil end
	if track and track.family == "techx" then
		return nil
	end
	if laser.ToLaser then
		local as_laser = laser:ToLaser()
		if as_laser then laser = as_laser end
	end
	mark_replay(laser, own_key)
	-- Fire* may attach Parent via emitter; detach so Ghost owns world origin without sample relocate.
	laser_helper.detach_parent(laser)
	if laser.SpawnerEntity == nil and owner_player then
		laser.SpawnerEntity = owner_player
	end

	local base = track.base or {}
	local flags = decode_flags(base.tear_flags)
	laser_helper.apply_recorded_laser_stats(laser, base, flags)
	-- Do NOT write HomingType / CurveStrength / Velocity.

	if base.collision_damage ~= nil then
		laser.CollisionDamage = base.collision_damage
	end
	if base.color then
		laser.Color = tbl_color(base.color)
	end
	if base.variant ~= nil and tonumber(base.variant) ~= tonumber(laser.Variant) then
		laser_helper.apply_variant_skin(laser, tonumber(base.variant))
	end

	local timeout = laser_timeout_for(track, t)
	if laser.SetTimeout then
		pcall(function() laser:SetTimeout(timeout) end)
	else
		laser.Timeout = timeout
	end

	if st.visible ~= nil then
		laser.Visible = st.visible and true or false
	end
	laser_helper.apply_stable_position_offset(laser, base, st)
	-- Technology only: still apply recorded scale (Brimstone/Tech X must not — ResetSpriteScale).
	laser_helper.apply_recorded_laser_scale(laser, base)

	-- Explicit opt-in only. Current Aeon brim / tech factories spawn at target → false.
	if base.needs_post_spawn_relocation == true then
		laser_helper.relocate_origin(laser, laser_desired_pos(ghost, st))
	end

	local kd = laser:GetData()
	kd._QingAeonReplayLaser = true
	kd._QingAeonLaserFamily = track.family
	kd._QingAeonLaserPoDynamic = base.po_dynamic == true
	local po = laser.PositionOffset
	if po then
		kd._QingAeonLaserStablePo = Vector(po.X, po.Y)
	end
	kd._QingAeonLaserLastAngle = tonumber(st.angle)
	kd._QingAeonLaserLastMaxDist = tonumber(st.max_distance)
	kd._QingAeonLaserLastRadius = tonumber(st.radius)
	return laser
end

--- Tech X: MarkIgnore + frozen stats + PositionOffset.
--- Post-spawn DO NOT WRITE: MaxDistance, Angle, SpriteRotation, Radius, Velocity,
--- CurveStrength, HomingType, Parent, DisableFollowParent, Samples, EndPoint, SetScale.
--- Radius = ring factory input; beam width stays with FireTechXLaser (no SetScale reset).
local function finish_replay_techx(laser, track, ghost, owner_player, own_key, st, t)
	if not laser then return nil end
	if laser.ToLaser then
		local as_laser = laser:ToLaser()
		if as_laser then laser = as_laser end
	end
	mark_replay(laser, own_key)
	if laser.SpawnerEntity == nil and owner_player then
		laser.SpawnerEntity = owner_player
	end

	local base = track.base or {}

	if base.collision_damage ~= nil then
		laser.CollisionDamage = base.collision_damage
	end
	if base.color then
		laser.Color = tbl_color(base.color)
	end
	-- TearFlags: optional frozen intent (do not touch HomingType / CurveStrength).
	local flags = decode_flags(base.tear_flags)
	if flags ~= nil then
		laser_helper.apply_recorded_laser_stats(laser, base, flags)
	end

	local timeout = laser_timeout_for(track, t)
	if laser.SetTimeout then
		pcall(function() laser:SetTimeout(timeout) end)
	else
		laser.Timeout = timeout
	end
	if st.visible ~= nil then
		laser.Visible = st.visible and true or false
	end
	laser_helper.apply_stable_position_offset(laser, base, st)
	-- DO NOT apply_recorded_laser_scale: SetScale → ResetSpriteScale wipes factory width.

	local kd = laser:GetData()
	kd._QingAeonReplayLaser = true
	kd._QingAeonLaserFamily = "techx"
	kd._QingAeonLaserPoDynamic = base.po_dynamic == true
	local po = laser.PositionOffset
	if po then
		kd._QingAeonLaserStablePo = Vector(po.X, po.Y)
	end
	return laser
end

--- Aeon-only Brimstone width shim for Tainted Azazel.
-- Vanilla Tainted Azazel innate Brimstone visually behaves like a ~0.1
-- FireBrimstone factory multiplier while its actual damage multiplier is 0.5.
-- Use 0.1 only for factory initialization, then restore recorded DM post-spawn.
-- 0.1 is a compatibility factory value, not a claim that recorded DM was 0.1.
local function resolve_aeon_brimstone_factory_dm(base)
	local dm = tonumber(base and base.damage_multiplier)
	local az_b = (PlayerType and PlayerType.PLAYER_AZAZEL_B) or 28
	local owner_type = tonumber(base and base.owner_player_type)
	if owner_type == az_b
		and dm ~= nil
		and math.abs(dm - 0.5) < 0.001
	then
		return 0.1, dm, "tainted_azazel_thin"
	end
	return dm, nil, "normal"
end

--- Brimstone: FireBrimstone + MeusNil spatial source (Air Flight / Craft chain).
--- Returns laser, source. Never ShootAngle. Never CurveStrength / HomingType / relocate.
local function spawn_replay_brimstone(track, ghost, owner_player, own_key, t)
	local base = track.base or {}
	local st = track_state_at(track, t) or track.states[1] or {}
	local desired = laser_desired_pos(ghost, st)
	local angle = tonumber(st.angle) or 0
	local dir = Vector.FromAngle(angle)
	if dir:Length() < 0.01 then dir = Vector(1, 0) end
	local timeout = laser_timeout_for(track, t)
	local po = Vector.Zero
	if type(base.position_offset) == "table" then
		po = Vector(tonumber(base.position_offset.x) or 0, tonumber(base.position_offset.y) or 0)
	elseif st.pox ~= nil then
		po = Vector(tonumber(st.pox) or 0, tonumber(st.poy) or 0)
	end

	-- Replay spatial source (like Craft air). Finite Nil lifetime; Aeon drives Position each tick.
	local source = auxi.fire_nil(desired, Vector.Zero, {
		cooldown = math.max(8, timeout + LASER_TIMEOUT_MARGIN),
		player = owner_player,
	})
	if not source then return nil, nil end
	mark_replay(source, own_key)
	source.Visible = false
	source.Velocity = Vector.Zero
	local sd = source:GetData()
	sd._QingAeonBrimSource = true
	sd.skip_nil_distance_cull = true -- Ghost may leave player; still finite removecd.

	local attack_holder = auxi.get_attack_holder()
	-- Contract: Source = spatial intermediate; engine Spawner stays owner_player.
	local factory_dm, restore_dm, dm_profile = resolve_aeon_brimstone_factory_dm(base)
	local fire_opts = {
		mode = "untracked",
		reason = "aeon_replay_brimstone",
		family = "brimstone",
		Source = source,
		emitter = source,
	}
	if factory_dm ~= nil then
		fire_opts.damage_multiplier = factory_dm
	end
	local laser = attack_holder.FireBrimstone(owner_player, dir, fire_opts)
	if not laser then
		source:Remove()
		return nil, nil
	end
	if laser.ToLaser then
		local as_laser = laser:ToLaser()
		if as_laser then laser = as_laser end
	end
	mark_replay(laser, own_key)

	-- Mirror Craft spawn_craft_brimstone topology: Parent = spatial source, follow parent.
	laser.Parent = source
	laser.Position = desired
	if laser.PositionOffset ~= nil then
		laser.PositionOffset = po
	end
	if laser.ParentOffset ~= nil then
		laser.ParentOffset = Vector(0, 0)
	end
	if laser.SetDisableFollowParent then
		pcall(function() laser:SetDisableFollowParent(false) end)
	elseif laser.DisableFollowParent ~= nil then
		laser.DisableFollowParent = false
	end

	-- Tainted Azazel thin-beam shim: restore recorded DamageMultiplier after factory init.
	-- SetDamageMultiplier only writes _damageMultiplier (no ResetSpriteScale).
	if dm_profile == "tainted_azazel_thin"
		and restore_dm ~= nil
		and laser.SetDamageMultiplier
	then
		pcall(function()
			laser:SetDamageMultiplier(restore_dm)
		end)
	end

	if base.collision_damage ~= nil then
		laser.CollisionDamage = base.collision_damage
	end
	if base.color then
		laser.Color = tbl_color(base.color)
	end
	if base.variant ~= nil then
		laser_helper.apply_variant_skin(laser, tonumber(base.variant))
	end
	if laser.SetTimeout then
		pcall(function() laser:SetTimeout(timeout) end)
	else
		laser.Timeout = timeout
	end
	if st.visible ~= nil then
		laser.Visible = st.visible and true or false
	end
	-- DO NOT SetScale / SpriteScale: RGON SetScale calls ResetSpriteScale and wipes factory width.
	-- laser_scale / sprite_scale remain diagnostic in the save only.

	local kd = laser:GetData()
	kd._QingAeonReplayLaser = true
	kd._QingAeonLaserFamily = "brimstone"
	kd._QingAeonLaserPoDynamic = base.po_dynamic == true
	kd._QingAeonBrimSource = source
	kd._QingAeonLaserRecordDm = tonumber(base.damage_multiplier)
	kd._QingAeonLaserFactoryDm = factory_dm
	kd._QingAeonLaserDmProfile = dm_profile
	local spo = laser.PositionOffset
	if spo then
		kd._QingAeonLaserStablePo = Vector(spo.X, spo.Y)
	end
	return laser, source
end

local function spawn_replay_technology_linear(track, ghost, owner_player, own_key, t)
	local st = track_state_at(track, t) or track.states[1] or {}
	local dir = Vector.FromAngle(tonumber(st.angle) or 0)
	if dir:Length() < 0.01 then dir = Vector(1, 0) end
	local pos = laser_desired_pos(ghost, st)
	local attack_holder = auxi.get_attack_holder()
	local laser = attack_holder.FireTechLaser(owner_player, pos, dir, laser_fire_opts("aeon_replay_technology", ghost))
	-- FireTechLaser already receives pos → no relocate_origin.
	return finish_replay_laser(laser, track, ghost, owner_player, own_key, st, t), nil
end

--- Tech Sword companion ring (and similar): THIN_RED + RING_FOLLOW_PARENT.
--- Topology authority = SubType 3 + Parent/Anchor + Radius. Do not FireTechLaser / detach / scale.
local function spawn_replay_technology_follow_ring(track, ghost, owner_player, own_key, t)
	local base = track.base or {}
	local st = track_state_at(track, t) or track.states[1] or {}
	local desired = laser_desired_pos(ghost, st)
	local timeout = laser_timeout_for(track, t)

	local anchor = auxi.fire_nil(desired, Vector.Zero, {
		cooldown = math.max(8, timeout + LASER_TIMEOUT_MARGIN),
		player = owner_player,
	})
	if not anchor then
		return nil, nil
	end
	mark_replay(anchor, own_key)
	anchor.Visible = false
	anchor.Velocity = Vector.Zero
	local ad = anchor:GetData()
	ad._QingAeonTechRingAnchor = true
	ad.skip_nil_distance_cull = true

	local pos_offset = nil
	if type(base.position_offset) == "table" then
		pos_offset = Vector(
			tonumber(base.position_offset.x) or 0,
			tonumber(base.position_offset.y) or 0
		)
	elseif st.pox ~= nil or st.poy ~= nil then
		pos_offset = Vector(tonumber(st.pox) or 0, tonumber(st.poy) or 0)
	end

	local variant = tonumber(base.variant)
	if variant == nil then
		variant = (LaserVariant and LaserVariant.THIN_RED) or 2
	end
	local subtype = tonumber(base.subtype)
	if subtype == nil then
		subtype = (LaserSubType and LaserSubType.LASER_SUBTYPE_RING_FOLLOW_PARENT) or 3
	end
	local radius = tonumber(st.radius)
	if radius == nil then
		radius = tonumber(base.radius) or 40
	end

	local laser = LaserHolder.fire_follow_tech_ring({
		pos = desired,
		parent = anchor,
		source = owner_player,
		variant = variant,
		subtype = subtype,
		radius = radius,
		dmg = tonumber(base.collision_damage) or 3.5,
		timeout = timeout,
		pos_offset = pos_offset,
		color = base.color and tbl_color(base.color) or nil,
		tear_flags = decode_flags(base.tear_flags),
	})
	if not laser then
		anchor:Remove()
		return nil, nil
	end
	if laser.ToLaser then
		local as_laser = laser:ToLaser()
		if as_laser then laser = as_laser end
	end
	mark_replay(laser, own_key)
	if laser.SpawnerEntity == nil and owner_player then
		laser.SpawnerEntity = owner_player
	end

	-- Do NOT detach_parent / apply_recorded_laser_scale / Angle / MaxDistance.
	local kd = laser:GetData()
	kd._QingAeonReplayLaser = true
	kd._QingAeonLaserFamily = "technology"
	kd._QingAeonTechFollowRing = true
	kd._QingAeonTechRingAnchor = anchor
	kd._QingAeonLaserPoDynamic = base.po_dynamic == true
	local po = laser.PositionOffset
	if po then
		kd._QingAeonLaserStablePo = Vector(po.X, po.Y)
	end
	kd._QingAeonLaserLastRadius = radius
	return laser, anchor
end

local function spawn_replay_technology(track, ghost, owner_player, own_key, t)
	local base = track.base or {}
	local subtype = tonumber(base.subtype)
	local follow = (LaserSubType and LaserSubType.LASER_SUBTYPE_RING_FOLLOW_PARENT) or 3
	if subtype == follow then
		return spawn_replay_technology_follow_ring(track, ghost, owner_player, own_key, t)
	end
	-- subtype 1 (ludo) and other non-linear: FireTechLaser fallback until specialized.
	return spawn_replay_technology_linear(track, ghost, owner_player, own_key, t)
end

local function techx_fire_direction(track, st)
	local vx = tonumber(st.vx)
	local vy = tonumber(st.vy)
	if vx ~= nil and vy ~= nil then
		local vel = Vector(vx, vy)
		if vel:Length() > 0.001 then
			return vel
		end
	end
	-- Legacy fallback only (old recordings may lack vx/vy).
	return Vector.FromAngle(tonumber(st.angle) or 0)
end

local function spawn_replay_techx(track, ghost, owner_player, own_key, t)
	local st = track_state_at(track, t) or track.states[1] or {}
	local base = track.base or {}
	local pos = laser_desired_pos(ghost, st)
	local dir = techx_fire_direction(track, st)
	local radius = tonumber(base.techx_spawn_radius)
	if radius == nil then
		return nil, nil
	end
	if dir:Length() < 0.001 then
		dir = Vector(1, 0)
	end
	local attack_holder = auxi.get_attack_holder()
	local laser = attack_holder.FireTechXLaser(
		owner_player,
		pos,
		dir,
		radius,
		laser_fire_opts("aeon_replay_techx", ghost)
	)
	if not laser then
		return nil, nil
	end
	-- Factory owns ring geometry. No finish_replay_laser / relocate / Radius rewrite.
	return finish_replay_techx(laser, track, ghost, owner_player, own_key, st, t), nil
end

local function spawn_replay_generic_laser(track, ghost, owner_player, own_key, t)
	-- Unknown laser family: prefer Brimstone factory (legal player laser init).
	return spawn_replay_brimstone(track, ghost, owner_player, own_key, t)
end

--- Family-dispatched persistent laser factory.
--- Returns laser [, handle]. Brimstone handle = MeusNil spatial source.
function M.spawn_replay_laser(track, ghost, owner_player, own_key, t)
	if not track or track.kind ~= "laser" or not ghost or not ghost:Exists() then
		return nil, nil
	end
	if not owner_player then return nil, nil end
	local family = track.family
	if family == "brimstone" then
		return spawn_replay_brimstone(track, ghost, owner_player, own_key, t)
	end
	if family == "technology" then
		return spawn_replay_technology(track, ghost, owner_player, own_key, t)
	end
	if family == "techx" then
		return spawn_replay_techx(track, ghost, owner_player, own_key, t)
	end
	return spawn_replay_generic_laser(track, ghost, owner_player, own_key, t)
end

local function apply_directional_laser_state(track, laser, ghost, st, t)
	local kd = laser:GetData()
	-- Follow Ghost with Position only — do not relocate samples each tick.
	laser_helper.detach_parent(laser)
	local desired = laser_desired_pos(ghost, st)
	if laser.Position then
		laser.Position = desired
	end

	local need_recalc = false
	local new_angle = tonumber(st.angle)
	if new_angle ~= nil and not nearly_eq(new_angle, kd._QingAeonLaserLastAngle) then
		laser.Angle = new_angle
		kd._QingAeonLaserLastAngle = new_angle
		need_recalc = true
	end
	local new_md = tonumber(st.max_distance)
	if new_md ~= nil and not nearly_eq(new_md, kd._QingAeonLaserLastMaxDist, 0.25) then
		laser.MaxDistance = new_md
		kd._QingAeonLaserLastMaxDist = new_md
		need_recalc = true
	end
	local new_rd = tonumber(st.radius)
	if new_rd ~= nil and laser.Radius ~= nil and not nearly_eq(new_rd, kd._QingAeonLaserLastRadius, 0.25) then
		laser.Radius = new_rd
		kd._QingAeonLaserLastRadius = new_rd
		need_recalc = true
	end
	if need_recalc then
		request_laser_sample_recalc(laser)
	end
	if st.visible ~= nil then laser.Visible = st.visible and true or false end

	if kd._QingAeonLaserPoDynamic then
		apply_position_offset(laser, st)
	else
		laser_helper.reassert_stable_position_offset(laser, kd._QingAeonLaserStablePo)
	end
	local end_f = tonumber(track.end_frame) or t
	laser.Timeout = math.max(2, end_f - t + LASER_TIMEOUT_MARGIN)
	return true
end

--- Drive MeusNil source only. Engine owns beam samples / Mirror / Homing.
--- Forbidden: detach_parent, relocate, Angle/MaxDistance/Velocity/samples writes.
local function apply_brimstone_state(track, laser, ghost, st, t, handle)
	if not laser then return false end
	local kd = laser:GetData()
	local source = handle
	if not entity_alive(source) then
		source = kd._QingAeonBrimSource
	end
	local desired = laser_desired_pos(ghost, st)
	if entity_alive(source) then
		source.Position = desired
		source.Velocity = Vector.Zero
		local sd = source:GetData()
		local end_f = tonumber(track.end_frame) or t
		local remain = math.max(2, end_f - t + LASER_TIMEOUT_MARGIN)
		if sd.removecd ~= nil then
			sd.removecd = math.max(tonumber(sd.removecd) or 0, remain)
		end
	end
	if st.visible ~= nil then
		laser.Visible = st.visible and true or false
	end
	if kd._QingAeonLaserPoDynamic then
		apply_position_offset(laser, st)
	else
		laser_helper.reassert_stable_position_offset(laser, kd._QingAeonLaserStablePo)
	end
	local end_f = tonumber(track.end_frame) or t
	laser.Timeout = math.max(2, end_f - t + LASER_TIMEOUT_MARGIN)
	return true
end

local function apply_technology_state(track, laser, ghost, st, t)
	return apply_directional_laser_state(track, laser, ghost, st, t)
end

--- Follow-parent tech ring: drive Anchor position + Radius/PO/Visible only.
--- Forbidden: Angle / MaxDistance / EndPoint / detach / apply_recorded_laser_scale.
local function apply_follow_ring_state(track, laser, ghost, st, t, handle)
	if not laser then return false end
	local kd = laser:GetData()
	local anchor = handle
	if not entity_alive(anchor) then
		anchor = kd._QingAeonTechRingAnchor
	end
	local desired = laser_desired_pos(ghost, st)
	if entity_alive(anchor) then
		anchor.Position = desired
		anchor.Velocity = Vector.Zero
		local ad = anchor:GetData()
		local end_f = tonumber(track.end_frame) or t
		local remain = math.max(2, end_f - t + LASER_TIMEOUT_MARGIN)
		if ad.removecd ~= nil then
			ad.removecd = math.max(tonumber(ad.removecd) or 0, remain)
		end
	end
	if st.visible ~= nil then
		laser.Visible = st.visible and true or false
	end
	local radius = tonumber(st.radius)
	if radius ~= nil then
		laser.Radius = radius
		kd._QingAeonLaserLastRadius = radius
	end
	local base = track.base or {}
	local dmg = tonumber(st.collision_damage)
	if dmg == nil then
		dmg = tonumber(base.collision_damage)
	end
	if dmg ~= nil then
		laser.CollisionDamage = dmg
	end
	if base.color then
		laser.Color = tbl_color(base.color)
	end
	local flags = decode_flags(base.tear_flags)
	if flags ~= nil and laser.TearFlags ~= nil then
		laser.TearFlags = flags
	end
	if kd._QingAeonLaserPoDynamic then
		apply_position_offset(laser, st)
	elseif kd._QingAeonLaserStablePo then
		laser_helper.reassert_stable_position_offset(laser, kd._QingAeonLaserStablePo)
	end
	local end_f = tonumber(track.end_frame) or t
	laser.Timeout = math.max(2, end_f - t + LASER_TIMEOUT_MARGIN)
	return true
end

local function apply_techx_state(track, laser, ghost, st, t)
	-- First pass: Visible (+ stable PO reassert). No Radius / Angle / MaxDistance / relocate.
	if not laser then return false end
	local kd = laser:GetData()
	if st.visible ~= nil then
		laser.Visible = st.visible and true or false
	end
	if kd._QingAeonLaserPoDynamic then
		apply_position_offset(laser, st)
	elseif kd._QingAeonLaserStablePo then
		laser_helper.reassert_stable_position_offset(laser, kd._QingAeonLaserStablePo)
	end
	local end_f = tonumber(track.end_frame) or t
	laser.Timeout = math.max(2, end_f - t + LASER_TIMEOUT_MARGIN)
	return true
end

function M.sync_knife_handle(handle, ghost)
	if not entity_alive(handle) or not ghost or not ghost:Exists() then
		return
	end
	handle.Position = ghost.Position
	handle.Velocity = Vector.Zero
end

--- 30Hz: set handle lerp endpoints (Ghost world positions). Do not add knife ox/oy.
function M.refresh_knife_handle_driver(handle, current, next_pos)
	if not entity_alive(handle) then return end
	current = current or handle.Position
	next_pos = next_pos or current
	local now = Isaac.GetFrameCount()
	local hd = handle:GetData()
	local prev = hd._QingAeonKnifeDriver
	local from = Vector(current.X, current.Y)
	local from_frame = now
	if type(prev) == "table" and prev.active == true and prev.to then
		from = Vector(prev.to.X, prev.to.Y)
		from_frame = now
	end
	hd._QingAeonKnifeDriver = {
		from = from,
		to = Vector(next_pos.X, next_pos.Y),
		from_isaac_frame = from_frame,
		-- Next Aeon 30Hz tick ≈ 2 Isaac frames while knife updates at 60Hz.
		to_isaac_frame = now + 2,
		active = true,
	}
end

--- 60Hz MC_POST_KNIFE_UPDATE: interpolate MeusNil handle between 30Hz Ghost targets.
function M.tick_knife_handle_driver(knife)
	if not entity_alive(knife) then return false end
	local kd = knife:GetData()
	if kd._QingAeonKnifeSpatialDriver ~= true and kd._QingAeonEngineKnife ~= true then
		return false
	end
	local handle = kd._QingAeonKnifeHandle
	if not entity_alive(handle) then return false end
	local driver = handle:GetData()._QingAeonKnifeDriver
	if type(driver) ~= "table" or driver.active ~= true then
		return false
	end
	local now = Isaac.GetFrameCount()
	local from_f = tonumber(driver.from_isaac_frame) or now
	local to_f = tonumber(driver.to_isaac_frame) or (from_f + 2)
	local denom = math.max(1, to_f - from_f)
	local alpha = (now - from_f) / denom
	if alpha < 0 then alpha = 0 end
	if alpha > 1 then alpha = 1 end
	local cur = driver.from or driver.current or handle.Position
	local nxt = driver.to or driver.next or cur
	if cur.Lerp then
		handle.Position = cur:Lerp(nxt, alpha)
	else
		handle.Position = Vector(
			cur.X + (nxt.X - cur.X) * alpha,
			cur.Y + (nxt.Y - cur.Y) * alpha
		)
	end
	handle.Velocity = Vector.Zero
	return true
end

function M.knife_is_flying(knife)
	if not entity_alive(knife) or not knife.IsFlying then
		return false
	end
	local ok, v = pcall(function() return knife:IsFlying() end)
	return ok and v and true or false
end

function M.end_replay_knife(knife, handle, owned)
	handle = handle or (knife and knife.GetData and knife:GetData()._QingAeonKnifeHandle)
	if handle and handle.GetData then
		local ok, hd = pcall(function() return handle:GetData() end)
		if ok and hd and hd._QingAeonKnifeDriver then
			hd._QingAeonKnifeDriver.active = false
		end
	end
	local removed = {}
	local function remove_one(ent, label)
		if entity_alive(ent) then
			ent:Remove()
			removed[#removed + 1] = label or "ent"
		end
	end
	if type(owned) == "table" then
		for i = 1, #owned do
			remove_one(owned[i], "owned")
		end
	end
	remove_one(knife, "knife")
	remove_one(handle, "handle")
	return removed
end

local KNIFE_WATCHDOG_GRACE = 8

--- Mom's Knife: auxi.fire_engine_knife (finite MeusNil lifetime) + Shoot.
--- Factory / Nil_holder owns removecd. Aeon only drives anchor + watchdog.
--- Returns knife, handle.
function M.spawn_replay_knife(track, ghost, owner_player, own_key, t)
	if not track or track.kind ~= "knife" or not ghost or not ghost:Exists() then
		return nil, nil
	end
	local base = track.base or {}
	local st = track_state_at(track, t) or track.states[1] or {}
	local ang = tonumber(st.rotation) or 0
	local dir = auxi.get_by_rotate(Vector(1, 0), ang)
	local pos = ghost.Position
	local start_f = tonumber(track.start_frame) or 0
	local end_f = tonumber(track.end_frame) or start_f
	local track_duration = math.max(1, end_f - start_f + 1)
	-- Factory input only — never rewrite removecd after spawn.
	local cooldown = math.max(8, track_duration + KNIFE_WATCHDOG_GRACE)

	local dmg = tonumber(st.collision_damage) or tonumber(base.collision_damage) or 3.5
	local knife = auxi.fire_engine_knife(ghost, dir, dmg, {
		player = owner_player,
		position = pos,
		cooldown = cooldown,
		fire_mode = "untracked",
		reason = "aeon_replay_knife",
		Color = base.color and tbl_color(base.color) or nil,
		variant = tonumber(base.variant) or 0,
		subtype = tonumber(base.subtype) or 0,
		-- Aeon 60Hz spatial driver owns Position; do not Nil-follow Ghost.
		disable_follower = true,
	})
	if not knife then
		return nil, nil
	end
	local handle = knife.Parent
	if not entity_alive(handle) then
		knife:Remove()
		return nil, nil
	end
	mark_replay(knife, own_key)
	mark_replay(handle, own_key)
	handle.Visible = false
	handle.Velocity = Vector.Zero
	local hd = handle:GetData()
	hd._QingAeonKnifeHandle = true
	-- Do NOT set hd.removecd / skip_nil_distance_cull — factory owns lifetime.
	local now = Isaac.GetFrameCount()
	hd._QingAeonKnifeDriver = {
		from = Vector(handle.Position.X, handle.Position.Y),
		to = Vector(handle.Position.X, handle.Position.Y),
		from_isaac_frame = now,
		to_isaac_frame = now + 2,
		active = true,
	}

	apply_position_offset(knife, st)
	local charge = tonumber(st.charge)
	if charge == nil then charge = tonumber(base.charge) end
	if charge == nil then charge = 1 end
	local range = tonumber(st.max_distance) or tonumber(base.max_distance) or peak_knife_range(track)
	pcall(function()
		knife:Shoot(charge, range)
	end)
	local kd = knife:GetData()
	kd._QingAeonKnifeSpatialDriver = true
	kd._QingAeonEngineKnife = true -- legacy alias
	kd._QingAeonKnifeHandle = handle
	return knife, handle
end

--- Returns ent [, handle]. Knife/parent-laser return handle as 2nd value.
function M.spawn_persistent(track, ghost, owner_player, own_key, t)
	if not track or not ghost or not ghost:Exists() then return nil end
	if track.kind == "knife" then
		return M.spawn_replay_knife(track, ghost, owner_player, own_key, t)
	end
	if track.kind == "laser" then
		return M.spawn_replay_laser(track, ghost, owner_player, own_key, t)
	end
	-- Legacy sword persistent tracks → one-shot sword_action (normal).
	if track.kind == "sword" or track.family == "sword" or track.family == "bone_club" then
		local st = track_state_at(track, t) or (track.states and track.states[1]) or {}
		local base = track.base or {}
		local rot = tonumber(st.rotation) or 0
		local dir = auxi.get_by_rotate(Vector(1, 0), rot)
		local ev = {
			mode = "sword_action",
			kind = "normal",
			family = track.family or "sword",
			start_frame = track.start_frame,
			end_frame = track.end_frame,
			base = {
				family = track.family or "sword",
				action_kind = "normal",
				variant = base.variant,
				subtype = base.subtype,
				damage = tonumber(st.collision_damage) or base.collision_damage,
				rotation = rot,
				direction = vec_tbl(dir),
				tech = (tonumber(base.variant) == 11),
				color = base.color,
				scale = tonumber(st.scale) or base.scale,
				sprite_scale = st.sprite_scale or base.sprite_scale,
				cooldown = math.max(8, (tonumber(track.end_frame) or 0) - (tonumber(track.start_frame) or 0)),
			},
		}
		return M.spawn_sword_action(ev, ghost, owner_player, own_key, t)
	end
	return nil
end

function M.apply_persistent_state(track, ent, ghost, t, handle)
	if not track or not entity_alive(ent) or not ghost or not ghost:Exists() then
		return false
	end
	local st = track_state_at(track, t)
	if not st then return false end

	if track.kind == "knife" then
		local knife = ent:ToKnife()
		if not knife then return false end
		-- Spatial: 60Hz handle driver owns handle.Position (= Ghost). Do not add ox/oy.
		-- PathOffset / Rotation: engine Shoot() owns; do not force recorded path each tick.
		if st.collision_damage ~= nil then knife.CollisionDamage = st.collision_damage end
		if st.visible ~= nil then knife.Visible = st.visible and true or false end
		-- Stable mouth PO only when dynamic; otherwise leave spawn stamp.
		if track.base and track.base.po_dynamic then
			apply_position_offset(knife, st)
		end
		return true
	end

	if track.kind == "laser" then
		local laser = ent:ToLaser()
		if not laser then return false end
		local family = track.family or laser:GetData()._QingAeonLaserFamily
		if family == "techx" then
			return apply_techx_state(track, laser, ghost, st, t)
		end
		if family == "technology" then
			local kd = laser:GetData()
			if kd._QingAeonTechFollowRing then
				return apply_follow_ring_state(track, laser, ghost, st, t, handle)
			end
			return apply_technology_state(track, laser, ghost, st, t)
		end
		return apply_brimstone_state(track, laser, ghost, st, t, handle)
	end

	-- Legacy sword tracks: engine swing owns motion after spawn; no per-frame drive.
	return true
end

function M.end_persistent_entity(ent, handle)
	if handle then
		if entity_alive(ent) then ent:Remove() end
		if entity_alive(handle) then handle:Remove() end
		return
	end
	local is_engine = false
	local h = nil
	if ent and ent.GetData then
		local ok, d = pcall(function() return ent:GetData() end)
		if ok and d then
			is_engine = d._QingAeonKnifeSpatialDriver == true or d._QingAeonEngineKnife == true
			h = d._QingAeonKnifeHandle
		end
	end
	if is_engine or h then
		M.end_replay_knife(ent, h)
		return
	end
	if entity_alive(ent) then
		ent:Remove()
	end
end

--- Epic: fixed world target + LockCarrierXY (no trajectory tick).
--- character_action: one-shot; returns nil, nil so tick_replay does not track live_specials.
function M.spawn_special(entry, ghost, owner_player, own_key, t)
	if not entry or not ghost or not ghost:Exists() then
		return nil
	end
	if entry.mode == "character_action"
		or entry.kind == "character_action"
		or entry.family == "character_action"
	then
		M.spawn_character_action(entry, ghost, owner_player, own_key, t)
		return nil, nil
	end
	if entry.mode == "sword_action"
		or entry.kind == "sword_action"
		or entry.kind == "normal"
		or entry.kind == "spin"
		or entry.kind == "melee_swing"
		or entry.mode == "melee_swing"
	then
		return M.spawn_sword_action(entry, ghost, owner_player, own_key, t)
	end
	if entry.kind ~= "epic" then
		return nil
	end
	local base = entry.base or {}
	local to = entry.target_offset or {x = 0, y = 0}
	local pos = ghost.Position + Vector(tonumber(to.x) or 0, tonumber(to.y) or 0)
	local room = Game():GetRoom()
	if room and room.GetClampedPosition then
		pos = room:GetClampedPosition(pos, 0)
	end
	local start_f = tonumber(entry.start_frame) or 0
	local impact_f = tonumber(entry.impact_frame) or tonumber(entry.end_frame) or start_f
	local cooldown = math.max(0, impact_f - start_f)
	if cooldown <= 0 and base.cooldown ~= nil then
		cooldown = math.max(0, tonumber(base.cooldown) or 0)
	end
	local scale = base.scale
	local scale_vec = scale and tbl_vec(scale) or Vector(1, 1)
	local q = auxi.launch_Missile(pos, Vector.Zero, nil, nil, {
		Cooldown = cooldown,
		dmg = base.damage,
		tearflags = decode_flags(base.flags),
		color = base.color and tbl_color(base.color) or nil,
		scale = scale_vec,
		player = owner_player,
		Dontautocheck = true,
		LockCarrierXY = true,
	})
	if q then
		mark_replay(q, own_key)
		q.Position = pos
		q.Velocity = Vector.Zero
		local d = q:GetData()
		local Epic_holder = require("Qing_Remaster_scripts.mimics.Epic_holder")
		d[Epic_holder.own_key .. "ManualCarrierPosition"] = true
		d[Epic_holder.own_key .. "LockCarrierXY"] = true
	end
	return q
end

function M.end_special(ent)
	if entity_alive(ent) then
		ent:Remove()
	end
end

local function resolve_sword_action_kind(ev)
	if not ev then return "normal" end
	local base = ev.base or {}
	local kind = base.action_kind or ev.kind or ev.mode
	if kind == "spin" then
		return "spin"
	end
	-- Legacy melee_swing / attack / swing → normal.
	return "normal"
end

--- Spirit Sword: Spirit_Sword_holder Mimic. Bone Club: fire_Sword (engine club path).
--- Mimic follows Ghost as source; do not force world Position onto Ghost.
function M.spawn_sword_action(ev, ghost, owner_player, own_key, t)
	if not ev or not ghost or not ghost:Exists() then
		return nil, nil
	end
	local base = ev.base or {}
	local family = ev.family or base.family or "sword"
	local action_kind = resolve_sword_action_kind(ev)
	local dir = tbl_vec(base.direction)
	if dir:Length() < 0.01 then
		local rot = tonumber(base.rotation) or 0
		dir = auxi.get_by_rotate(Vector(1, 0), rot)
	end
	dir = dir:Normalized()
	local dmg = tonumber(base.damage) or 3.5
	local is_attack = action_kind ~= "spin"
	local start_f = tonumber(ev.start_frame) or 0
	local end_f = tonumber(ev.end_frame) or start_f
	local cooldown = tonumber(base.cooldown)
	if cooldown == nil then
		cooldown = math.max(is_attack and 8 or 15, end_f - start_f)
	end
	cooldown = math.max(1, cooldown)

	-- Bone Club keeps engine fire_Sword (CLUB_HITBOX / bone anm2).
	if family == "bone_club" then
		local rot = dir:GetAngleDegrees()
		local params = {
			cooldown = cooldown,
			Accerate = is_attack and -2 or -1,
			player = owner_player,
			tearflags = decode_flags(base.tear_flags),
			Color = base.color and tbl_color(base.color) or nil,
			Tech = false,
			Attack = is_attack and true or nil,
			RotationOffset = rot,
			fire_mode = "untracked",
			reason = is_attack and "aeon_replay_bone_club_normal" or "aeon_replay_bone_club_spin",
		}
		local sword = auxi.fire_Sword(ghost.Position, dir, dmg, nil, params)
		if not sword then
			return nil, nil
		end
		if action_kind == "spin" and type(base.anim) == "string" then
			local spr = sword:GetSprite()
			if spr and spr.Play then
				pcall(function()
					spr:Play(base.anim, true)
				end)
			end
		end
		mark_replay(sword, own_key)
		local anchor = sword.Parent
		if entity_alive(anchor) then
			mark_replay(anchor, own_key)
			local ad = anchor:GetData()
			ad.follower = nil
			ad._QingAeonMeleeAnchor = true
			local now = Isaac.GetFrameCount()
			local ap = anchor.Position
			ad._QingAeonKnifeDriver = {
				from = Vector(ap.X, ap.Y),
				to = Vector(ap.X, ap.Y),
				from_isaac_frame = now,
				to_isaac_frame = now + 2,
				active = true,
			}
		end
		if base.scale ~= nil then
			sword.Scale = base.scale
		end
		if base.sprite_scale and sword.SpriteScale then
			sword.SpriteScale = tbl_vec(base.sprite_scale)
		end
		local sd = sword:GetData()
		sd._QingAeonMeleeSwing = true
		sd._QingAeonSwordAction = action_kind
		sd._QingAeonKnifeHandle = anchor
		sd._QingAeonKnifeSpatialDriver = true
		return sword, anchor
	end

	-- Spirit Sword / Tech Sword → Mimic (no EntityKnife / CLUB_HITBOX).
	local tech_variant = (KnifeVariant and KnifeVariant.TECH_SWORD) or 11
	local is_tech = base.tech == true or tonumber(base.variant) == tech_variant
	local beam = nil
	if action_kind == "spin" then
		beam = {
			enabled = true,
			flags = decode_flags(base.tear_flags),
			damage = dmg,
			scale = base.scale,
		}
	end
	local controller, ctrl = SpiritSword.spawn({
		kind = is_attack and "attack" or "spin",
		owner = owner_player,
		source = ghost,
		position = ghost.Position,
		direction = dir,
		damage = dmg,
		tear_flags = decode_flags(base.tear_flags),
		scale = base.scale,
		tech = is_tech,
		beam = beam,
		fire_mode = "untracked",
		-- Replay must not shove the real player.
		apply_recoil = false,
		apply_knockback = true,
	})
	if not controller then
		return nil, nil
	end
	mark_replay(controller, own_key)
	local sd = controller:GetData()
	sd._QingAeonMeleeSwing = true
	sd._QingAeonSwordAction = action_kind
	sd._QingAeonSwordMimic = true
	if ctrl then
		sd._QingAeonSwordMimicCtrl = ctrl
	end
	-- No separate knife Parent; Mimic Nil follows Ghost via source=.
	return controller, nil
end

--- Legacy alias: old melee_swing saves → normal sword_action.
function M.spawn_melee_swing(ev, ghost, owner_player, own_key, t)
	return M.spawn_sword_action(ev, ghost, owner_player, own_key, t)
end

function M.end_melee_swing(sword, anchor, owned)
	return M.end_replay_knife(sword, anchor, owned)
end

function M.classify_sword_anim(member)
	if not member then return "other", nil end
	return swing_anim_kind(member:ToKnife() or member)
end

-- Expose helpers for Card lifecycle (identity-safe live registry).
M.entity_alive = entity_alive
M.encode_flags = encode_flags
M.decode_flags = decode_flags
M.melee_attack_still_open = melee_attack_still_open
M.MELEE_SWING_GRACE = MELEE_SWING_GRACE
M.KNIFE_WATCHDOG_GRACE = KNIFE_WATCHDOG_GRACE
M.vec_tbl = vec_tbl
M.tbl_vec = tbl_vec

--- attack_id + generation; never Game frame alone; never attack_id alone.
function M.attack_record_key(event)
	if not event then return "0:0" end
	return tostring(event.attack_id) .. ":" .. tostring(event.generation or 0)
end

--- One-shot character special. Top-level mode/kind/family fixed; subtype in base.attack_kind.
function M.begin_character_action_event(player, character_key, snapshot, frame, attack)
	if not player or type(snapshot) ~= "table" then return nil end
	local start_f = tonumber(frame) or 0
	local dir = snapshot.direction
	if type(dir) ~= "table" then
		dir = vec_tbl(attack and attack.direction)
	end
	return {
		mode = "character_action",
		kind = "character_action",
		family = "character_action",
		start_frame = start_f,
		end_frame = start_f,
		impact_frame = start_f,
		target_offset = {x = 0, y = 0},
		base = {
			character_key = character_key,
			player_type = player.GetPlayerType and player:GetPlayerType() or nil,
			attack_kind = snapshot.kind,
			direction = dir,
			snapshot = snapshot,
		},
	}
end

--- Fire character replay once; no Aeon-managed carrier (do not join live_specials).
function M.spawn_character_action(ev, ghost, owner_player, own_key, t)
	if not ev or not ghost or not ghost:Exists() then
		return nil, nil
	end
	local CharacterAttackCompat = require("Qing_Remaster_scripts.player.character_attack_compat")
	local base = ev.base or {}
	local snapshot = base.snapshot
	if type(snapshot) ~= "table" then
		return nil, nil
	end
	local dir = tbl_vec(base.direction or snapshot.direction)
	if dir:Length() < 0.01 then
		dir = Vector(0, 1)
	else
		dir = dir:Normalized()
	end
	local player_type = base.player_type
	local result = CharacterAttackCompat.dispatch_replay_attack(player_type or owner_player, owner_player, {
		snapshot = snapshot,
		origin = ghost.Position,
		aim_dir = dir,
		source = ghost,
		character_key = base.character_key,
		attack_kind = base.attack_kind,
		reason = "aeon_character_replay",
		fire_context = {mode = "untracked", reason = "aeon_character_replay"},
		own_key = own_key,
		replay_frame = t,
	})
	if result and result.spawned then
		for i = 1, #result.spawned do
			local ent = result.spawned[i]
			if entity_alive(ent) then
				mark_replay(ent, own_key)
			end
		end
	end
	return nil, nil
end

return M

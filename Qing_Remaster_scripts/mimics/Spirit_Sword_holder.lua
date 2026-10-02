-- Spirit Sword Mimic: reconstruct Attack / Spin results without EntityKnife damage.
-- Visual + Lua oriented hit geometry (spirit_sword_geometry) + optional Sword Beam.
-- Does NOT call auxi.fire_Sword / Weapon::FireSword / CLUB_HITBOX.
-- Aeon replay (family=sword) uses item.spawn via aeon_replay.spawn_sword_action.
local Geometry = require("Qing_Remaster_scripts.mimics.spirit_sword_geometry")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Nil = require("Qing_Remaster_scripts.others.Nil_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	own_key = "Spirit_Sword_holder_",
	draw_hitboxes = false,
	-- Ordinary Spirit Sword visual (same sheet as auxi.fire_Sword default).
	-- Geometry keys are AttackUp/SpinUp but Null data is AttackRight-local.
	-- Effect Sprite.Rotation uses facing_angle - 90 (see sprite_rotation_from_direction).
	anm2_normal = "gfx/player/qing/Qing_spirit_Sword.anm2",
	anm2_tech = "gfx/player/qing/Qing_tech_Sword.anm2",
	-- Legacy alias (sandbox / callers that still read item.anm2).
	anm2 = "gfx/player/qing/Qing_spirit_Sword.anm2",
	DEFAULT_BEAM_FRAME = 4,
	-- Feel-probe calibrated (codex_work/notes/spirit_sword_feel_probe.md).
	SFX_ATTACK = (SoundEffect and SoundEffect.SOUND_SHELLGAME) or 252,
	SFX_SPIN = (SoundEffect and SoundEffect.SOUND_SWORD_SPIN) or 538,
	ATTACK_SFX_FRAME = 1,
	SPIN_SFX_FRAME = 0,
	-- Approximate melee feel (not full vanilla recreate).
	-- Target kick ≈17 at Mass≈0; Epiphany-style mass factor (100-Mass)*0.01.
	KNOCKBACK_BASE = 17,
	-- Player recoil only on first monster hit this swing (pickups do not trigger).
	PLAYER_RECOIL = 4,
}

local active = {} -- GetPtrHash(controller) -> controller

local function entity_alive(ent)
	return ent and ent.Exists and ent:Exists() and not ent:IsDead()
end

-- AttackRight / SpinRight Null + layer arc is Right-local: Right → Down → Left.
-- On EntityKnife, RotationOffset aligns that local +X with a Knife-space forward.
-- On Effect Mimic, Sprite.Rotation must be facing - 90 so aim Right becomes
-- world Up → Right → Down (vanilla Spirit Sword facing-right slash).
local function sprite_rotation_from_direction(direction)
	if not direction or direction:Length() < 0.01 then
		return -90
	end
	return direction:GetAngleDegrees() - 90
end

-- Hit timeline keys in spirit_sword_geometry (AttackRight Null dump, keyed as AttackUp).
local function geometry_anim_for(kind)
	if kind == "spin" then
		return "SpinUp"
	end
	return "AttackUp"
end

-- Qing_spirit_Sword visual: Right clip + Sprite.Rotation (facing - 90).
local function visual_anim_for(kind)
	if kind == "spin" then
		return "SpinRight"
	end
	return "AttackRight"
end

local function hitbox_scale_for(kind)
	if kind == "spin" then
		return Geometry.PLAYER_SPIN_HITBOX_SCALE
	end
	return Geometry.PLAYER_ATTACK_HITBOX_SCALE
end

local function damage_flags(tear_flags)
	-- Keep melee simple; tear flags reserved for beam path.
	return 0
end

--- opts.play_sound / opts.sfx: false → mute. opts.mute_sfx / opts.mute: true → mute.
local function want_play_sound(opts)
	opts = opts or {}
	if opts.mute_sfx == true or opts.mute == true then
		return false
	end
	if opts.play_sound == false or opts.sfx == false then
		return false
	end
	return true
end

local function rand_pitch(lo, hi)
	lo = tonumber(lo) or 1
	hi = tonumber(hi) or lo
	if hi < lo then
		lo, hi = hi, lo
	end
	return lo + (hi - lo) * math.random()
end

local function try_play_swing_sfx(ctrl, frame)
	if not ctrl.play_sound or ctrl.sfx_swing_played then
		return
	end
	if ctrl.kind == "attack" then
		if frame < item.ATTACK_SFX_FRAME then
			return
		end
		sound_tracker.PlayStackedSound(
			item.SFX_ATTACK,
			1,
			rand_pitch(1.10, 1.30),
			false,
			0,
			1
		)
		ctrl.sfx_swing_played = true
	elseif ctrl.kind == "spin" then
		if frame < item.SPIN_SFX_FRAME then
			return
		end
		-- Vanilla feel probe: same Spin frame fires SOUND_SWORD_SPIN twice.
		sound_tracker.PlayStackedSound(item.SFX_SPIN, 1, rand_pitch(0.96, 1.10), false, 0, 2)
		sound_tracker.PlayStackedSound(item.SFX_SPIN, 1, rand_pitch(0.96, 1.10), false, 0, 2)
		ctrl.sfx_swing_played = true
	end
end

-- Epiphany-style: stationary Mass=100 → 0; light Mass → ~1.
local function mass_knockback_factor(mass)
	mass = tonumber(mass)
	if not mass then
		return 1
	end
	return math.max(0, (100 - mass) * 0.01)
end

local function knock_origin(ctrl)
	local owner = ctrl.owner
	if entity_alive(owner) then
		return owner.Position
	end
	local source = ctrl.source
	if entity_alive(source) then
		return source.Position
	end
	if entity_alive(ctrl.controller) then
		return ctrl.controller.Position
	end
	return nil
end

local function apply_target_knockback(ctrl, ent)
	if not ctrl.apply_knockback or not entity_alive(ent) then
		return
	end
	-- Once per swing per native entity (even if hit scan re-enters).
	ctrl.knocked_entities = ctrl.knocked_entities or {}
	local hash = GetPtrHash(ent)
	if ctrl.knocked_entities[hash] then
		return
	end
	local factor = mass_knockback_factor(ent.Mass)
	if factor <= 0 then
		return
	end
	local origin = knock_origin(ctrl)
	local dir
	if origin then
		dir = ent.Position - origin
	end
	if not dir or dir:Length() < 0.01 then
		dir = ctrl.direction
	end
	if not dir or dir:Length() < 0.01 then
		return
	end
	local base = tonumber(ctrl.knockback_base) or item.KNOCKBACK_BASE
	-- Mark before mutate so a re-entrant tick cannot stack impulse.
	ctrl.knocked_entities[hash] = true
	ent:AddVelocity(dir:Normalized() * (base * factor))
end

-- Once per swing, and only when a vulnerable enemy is hit (not pickups).
-- Recoil direction = away from that enemy (not opposite swing facing).
local function try_apply_player_recoil(ctrl, hit_ent)
	if not ctrl.apply_recoil or ctrl.player_recoil_applied then
		return
	end
	local owner = ctrl.owner
	if not entity_alive(owner) or not owner:ToPlayer() then
		return
	end
	local dir
	if entity_alive(hit_ent) then
		dir = owner.Position - hit_ent.Position
	end
	if not dir or dir:Length() < 0.01 then
		dir = ctrl.direction
		if dir and dir:Length() >= 0.01 then
			dir = dir:Normalized() * -1
		else
			return
		end
	else
		dir = dir:Normalized()
	end
	local amount = tonumber(ctrl.player_recoil) or item.PLAYER_RECOIL
	owner:AddVelocity(dir * amount)
	ctrl.player_recoil_applied = true
end

local function point_in_boxes(pos, boxes, radius)
	if not pos or type(boxes) ~= "table" then return false end
	radius = tonumber(radius) or 0
	for b = 1, #boxes do
		if Geometry.point_hits_box(pos, boxes[b], radius) then
			return true
		end
	end
	return false
end

local function entity_in_boxes(ent, boxes)
	if not ent then return false end
	return point_in_boxes(ent.Position, boxes, tonumber(ent.Size) or 0)
end

-- Spirit Sword Mimic terrain: poop / TNT via Hurt only (no try_destroy_grid).
-- Spiderwebs are NOT targets.
local SWORD_HURT_GRID = {
	[GridEntityType.GRID_POOP] = true,
	[GridEntityType.GRID_TNT] = true,
}

local function grid_type_of(grid)
	if not grid then return nil end
	local ok, gt = pcall(function()
		return grid:GetType()
	end)
	if ok then return gt end
	return nil
end

local function is_sword_hurt_grid(grid)
	local gt = grid_type_of(grid)
	if gt == nil then return false end
	if gt == GridEntityType.GRID_SPIDERWEB then
		return false
	end
	return SWORD_HURT_GRID[gt] == true
end

local function terrain_query_radius(ctrl)
	local scale = tonumber(ctrl.scale)
	if scale == nil or scale <= 0 then
		scale = 1
		local ent = ctrl.controller
		if entity_alive(ent) then
			local spr = ent:GetSprite()
			if spr and spr.Scale then
				scale = math.max(tonumber(spr.Scale.X) or 1, tonumber(spr.Scale.Y) or 1)
			end
		end
	end
	if ctrl.kind == "spin" then
		return 75 * scale
	end
	return 55 * scale
end

local function is_burning_fireplace(ent)
	if not entity_alive(ent) then return false end
	if ent.Type ~= EntityType.ENTITY_FIREPLACE then return false end
	if ent.Variant == 11 then return false end
	if ent:IsDead() then return false end
	if ent.State == 3 then return false end
	local anim = ""
	pcall(function()
		local spr = ent:GetSprite()
		if spr and spr.GetAnimation then
			anim = spr:GetAnimation() or ""
		end
	end)
	if string.sub(anim, 1, 6) == "NoFire" then return false end
	if string.sub(anim, 1, 9) == "Dissapear" then return false end
	return true
end

--- Canonical extinguish: full-HP TakeDamage so vanilla handles State/NoFire/loot.
--- Matches Item_Charon_s_Sign (no RGON Extinguish API). Returns true if still eligible when called.
local function extinguish_fireplace(ent, source_ref)
	if not is_burning_fireplace(ent) then
		return false
	end
	local hp = tonumber(ent.HitPoints) or 1
	local flags = (DamageFlag and DamageFlag.DAMAGE_IGNORE_ARMOR) or 0
	ent:TakeDamage(math.max(1, hp), flags, source_ref, 0)
	return true
end

local function try_hit_grid_terrain(ctrl, boxes)
	if not ctrl.hurt_grid then return end
	local origin = ctrl.controller and ctrl.controller.Position
	if not origin then return end
	ctrl.grid_hurt_frame = ctrl.grid_hurt_frame or {}
	local game_frame = Game():GetFrameCount()
	local near = auxi.get_near_grid_info(origin, terrain_query_radius(ctrl))
	for i = 1, #near do
		local info = near[i]
		local grid = info and info.grid
		local idx = info and info.idx
		if grid and idx ~= nil
			and is_sword_hurt_grid(grid)
			and point_in_boxes(grid.Position, boxes, 20)
			and ctrl.grid_hurt_frame[idx] ~= game_frame
		then
			ctrl.grid_hurt_frame[idx] = game_frame
			if grid.Hurt then
				grid:Hurt(1)
			end
		end
	end
end

local function try_extinguish_fireplace(ctrl, ent, source_ref)
	local hash = GetPtrHash(ent)
	ctrl.extinguished_fireplaces = ctrl.extinguished_fireplaces or {}
	if ctrl.extinguished_fireplaces[hash] then
		return
	end
	if not is_burning_fireplace(ent) then
		return
	end
	if extinguish_fireplace(ent, source_ref) then
		ctrl.extinguished_fireplaces[hash] = true
	end
end

local function try_hurt_type292(ctrl, ent, source_ref, game_frame)
	if ent.Type ~= 292 then
		return
	end
	ctrl.movable_hurt_frame = ctrl.movable_hurt_frame or {}
	local hash = GetPtrHash(ent)
	if ctrl.movable_hurt_frame[hash] == game_frame then
		return
	end
	ctrl.movable_hurt_frame[hash] = game_frame
	ent:TakeDamage(1, 0, source_ref, 0)
end

local function try_hit_movable_terrain(ctrl, boxes)
	if not ctrl.hurt_movable then return end
	local owner = ctrl.owner
	local source_ref = EntityRef(owner or ctrl.controller)
	local game_frame = Game():GetFrameCount()
	local room_ents = Isaac.GetRoomEntities()
	for i = 1, #room_ents do
		local ent = room_ents[i]
		if entity_alive(ent) and entity_in_boxes(ent, boxes) then
			if ent.Type == EntityType.ENTITY_FIREPLACE then
				try_extinguish_fireplace(ctrl, ent, source_ref)
			elseif ent.Type == 292 then
				try_hurt_type292(ctrl, ent, source_ref, game_frame)
			end
		end
	end
end

local function try_hit_terrain(ctrl, boxes)
	if type(boxes) ~= "table" or #boxes == 0 then return end
	try_hit_grid_terrain(ctrl, boxes)
	try_hit_movable_terrain(ctrl, boxes)
end

local function try_hit_targets(ctrl, boxes)
	if type(boxes) ~= "table" or #boxes == 0 then return end
	local damage = tonumber(ctrl.damage) or 3.5
	local owner = ctrl.owner
	local source_ref = EntityRef(owner or ctrl.controller)
	local pickup_type = EntityType and EntityType.ENTITY_PICKUP
	local room_ents = Isaac.GetRoomEntities()
	for i = 1, #room_ents do
		local ent = room_ents[i]
		if entity_alive(ent) then
			local is_enemy = ent.IsVulnerableEnemy and ent:IsVulnerableEnemy()
			local is_pickup = pickup_type ~= nil and ent.Type == pickup_type
			if is_enemy or is_pickup then
				local hash = GetPtrHash(ent)
				if not ctrl.hit_entities[hash] and entity_in_boxes(ent, boxes) then
					ctrl.hit_entities[hash] = true
					if is_enemy then
						ent:TakeDamage(damage, damage_flags(ctrl.tear_flags), source_ref, 0)
						apply_target_knockback(ctrl, ent)
						try_apply_player_recoil(ctrl, ent)
					else
						-- Pickups: knock away only; never player recoil.
						apply_target_knockback(ctrl, ent)
					end
				end
			end
		end
	end
end

local function spawn_beam(ctrl)
	if ctrl.beam_fired then return end
	local beam = ctrl.beam
	if type(beam) ~= "table" or beam.enabled == false then
		return
	end
	local owner = ctrl.owner
	if not owner then return end
	local attack_holder = auxi.get_attack_holder()
	local dir = ctrl.direction
	if not dir or dir:Length() < 0.01 then
		dir = Vector(1, 0)
	else
		dir = dir:Normalized()
	end
	local speed = tonumber(beam.speed) or 12
	local vel = beam.velocity
	if type(vel) == "table" then
		vel = Vector(tonumber(vel.x) or 0, tonumber(vel.y) or 0)
	elseif not vel then
		vel = dir * speed
	end
	local pos = ctrl.controller.Position + dir * 12
	local tear = attack_holder.FireTear(owner, pos, vel, {
		mode = "untracked",
		reason = "spirit_sword_mimic_beam",
		family = "sword_beam",
	})
	if not tear then return end
	ctrl.beam_fired = true
	local variant = tonumber(beam.variant)
	if variant == nil then
		if ctrl.tech and TearVariant and TearVariant.TECH_SWORD_BEAM then
			variant = TearVariant.TECH_SWORD_BEAM
		elseif TearVariant and TearVariant.SWORD_BEAM then
			variant = TearVariant.SWORD_BEAM
		end
	end
	if variant ~= nil and tear.ChangeVariant then
		pcall(function()
			tear:ChangeVariant(variant)
		end)
	end
	if beam.damage ~= nil then
		tear.CollisionDamage = beam.damage
	elseif ctrl.damage ~= nil then
		tear.CollisionDamage = ctrl.damage
	end
	if beam.flags ~= nil and tear.TearFlags ~= nil then
		tear.TearFlags = beam.flags
	elseif ctrl.tear_flags ~= nil and tear.TearFlags ~= nil then
		tear.TearFlags = ctrl.tear_flags
	end
	if tear.Scale ~= nil and beam.scale ~= nil then
		tear.Scale = beam.scale
	end
end

local function tick_controller(ctrl)
	local ent = ctrl.controller
	if not entity_alive(ent) then
		return true
	end
	local source = ctrl.source
	if entity_alive(source) then
		ent.Position = source.Position
		ent.Velocity = Vector.Zero
	end
	local spr = ent:GetSprite()
	local visual_anim = ctrl.visual_anim or visual_anim_for(ctrl.kind)
	if spr:IsFinished(visual_anim) then
		ent:Remove()
		return true
	end
	local frame = spr:GetFrame()
	ctrl.last_frame = frame
	try_play_swing_sfx(ctrl, frame)
	local boxes = Geometry.get_frame_and_previous_boxes({
		animation = ctrl.geometry_anim or geometry_anim_for(ctrl.kind),
		frame = frame,
		origin = ent.Position,
		rotation = spr.Rotation,
		scale = spr.Scale,
		flip_x = spr.FlipX == true,
		flip_y = spr.FlipY == true,
		hitbox_scale = hitbox_scale_for(ctrl.kind),
		position_scale = Geometry.PLAYER_POSITION_SCALE,
	})
	ctrl.last_boxes = boxes
	if type(boxes) == "table" and #boxes > 0 then
		try_hit_targets(ctrl, boxes)
		try_hit_terrain(ctrl, boxes)
	end

	local beam_frame = ctrl.beam and tonumber(ctrl.beam.frame)
	if beam_frame == nil then
		beam_frame = item.DEFAULT_BEAM_FRAME
	end
	if ctrl.kind == "spin" and ctrl.beam and ctrl.beam.enabled ~= false and frame >= beam_frame then
		spawn_beam(ctrl)
	end
	return false
end

--- opts: kind, owner, source, position, direction, damage, tear_flags, scale, beam, tech,
---       fire_mode, attack, play_sound / sfx / mute_sfx / mute,
---       apply_knockback / knockback, apply_recoil / recoil,
---       knockback_base, player_recoil,
---       hurt_grid / no_grid, hurt_movable
function item.spawn(opts)
	opts = opts or {}
	local kind = opts.kind == "spin" and "spin" or "attack"
	local owner = opts.owner
	local source = opts.source or owner
	local pos = opts.position
	if not pos and entity_alive(source) then
		pos = source.Position
	end
	if not pos then
		return nil
	end
	local direction = opts.direction or Vector(1, 0)
	if direction:Length() < 0.01 then
		direction = Vector(1, 0)
	else
		direction = direction:Normalized()
	end
	local geometry_anim = geometry_anim_for(kind)
	local visual_anim = visual_anim_for(kind)
	local frames = Geometry.animations[geometry_anim]
	-- Visual clips on Qing_spirit_Sword are slightly longer than geometry tables; pad for IsFinished.
	local lifetime = (type(frames) == "table" and #frames or 8) + 8
	local controller = auxi.fire_nil(pos, Vector.Zero, {
		cooldown = math.max(8, lifetime),
		player = owner,
	})
	if not controller then
		return nil
	end
	local tech = opts.tech == true
	local anm2 = tech and item.anm2_tech or item.anm2_normal
	local spr = controller:GetSprite()
	spr:Load(anm2, true)
	spr:Play(visual_anim, true)
	spr.Rotation = sprite_rotation_from_direction(direction)
	local sc_opt = tonumber(opts.scale)
	if sc_opt ~= nil then
		spr.Scale = Vector(sc_opt, sc_opt)
	end
	controller.PositionOffset = Vector(0, 0)
	controller.Visible = true
	-- MeusNil defaults collisionRadius=10; disable so the follow-nil cannot shove pickups every tick.
	controller.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	controller.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	controller.Size = 0

	local beam = opts.beam
	if beam == true then
		beam = {enabled = true}
	end

	local apply_knockback = opts.apply_knockback
	if apply_knockback == nil then
		apply_knockback = opts.knockback
	end
	if apply_knockback == nil then
		apply_knockback = true
	end
	local apply_recoil = opts.apply_recoil
	if apply_recoil == nil then
		apply_recoil = opts.recoil
	end
	if apply_recoil == nil then
		apply_recoil = true
	end

	local ctrl = {
		kind = kind,
		owner = owner,
		source = source,
		controller = controller,
		direction = direction,
		geometry_anim = geometry_anim,
		visual_anim = visual_anim,
		tech = tech,
		scale = sc_opt or 1,
		damage = tonumber(opts.damage) or (owner and owner.Damage) or 3.5,
		tear_flags = opts.tear_flags,
		beam = beam,
		beam_fired = false,
		play_sound = want_play_sound(opts),
		sfx_swing_played = false,
		apply_knockback = apply_knockback ~= false,
		apply_recoil = apply_recoil ~= false,
		knockback_base = tonumber(opts.knockback_base) or item.KNOCKBACK_BASE,
		player_recoil = tonumber(opts.player_recoil) or item.PLAYER_RECOIL,
		player_recoil_applied = false,
		hit_entities = {},
		knocked_entities = {},
		grid_hurt_frame = {},
		movable_hurt_frame = {},
		extinguished_fireplaces = {},
		hurt_grid = opts.hurt_grid ~= false and opts.no_grid ~= true,
		hurt_movable = opts.hurt_movable ~= false,
		fire_mode = opts.fire_mode or "untracked",
		attack = opts.attack,
		last_boxes = {},
		last_frame = 0,
	}
	local d = controller:GetData()
	d[item.own_key .. "ctrl"] = ctrl
	d[Nil.own_key .. "work"] = function(self)
		local c = self:GetData()[item.own_key .. "ctrl"]
		if not c then
			self:Remove()
			return
		end
		if tick_controller(c) then
			active[GetPtrHash(self)] = nil
		end
	end
	active[GetPtrHash(controller)] = ctrl
	return controller, ctrl
end

function item.spawn_attack(opts)
	opts = opts or {}
	opts.kind = "attack"
	return item.spawn(opts)
end

function item.spawn_spin(opts)
	opts = opts or {}
	opts.kind = "spin"
	return item.spawn(opts)
end

function item.clear(controller)
	if not controller then return end
	local ptr = GetPtrHash(controller)
	active[ptr] = nil
	if entity_alive(controller) then
		controller:Remove()
	end
end

function item.set_draw_hitboxes(on)
	item.draw_hitboxes = on == true
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function(_)
		if not item.draw_hitboxes then return end
		for ptr, ctrl in pairs(active) do
			if not entity_alive(ctrl.controller) then
				active[ptr] = nil
			else
				Geometry.draw_boxes(ctrl.last_boxes)
				local pos = ctrl.controller.Position
				if Isaac.DrawLine then
					local tip = pos + ctrl.direction * 24
					Isaac.DrawLine(
						Isaac.WorldToScreen(pos),
						Isaac.WorldToScreen(tip),
						KColor(0.2, 1, 0.4, 0.9),
						KColor(0.2, 1, 0.4, 0.9),
						1
					)
				end

			end
		end
	end,
})

return item

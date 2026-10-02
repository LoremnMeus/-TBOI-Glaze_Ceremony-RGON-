-- Reversed Sting blood orbs: spray → pull → absorb into pentagram (cosmetic only).
local enums = require("Qing_Remaster_scripts.core.enums")
local C = require("Qing_Remaster_scripts.cards.sting_reversed.constants")
local visual = require("Qing_Remaster_scripts.cards.sting_reversed.visual")
local trail_presets = require("Qing_Remaster_scripts.others.sprite_trail_presets")

local M = {}

local function random_vector(rng)
	return Vector.FromAngle(rng:RandomFloat() * 360)
end

local function absorb_offset(rng)
	return Vector(
		(rng:RandomFloat() * 2 - 1) * 30,
		(rng:RandomFloat() * 2 - 1) * 9
	)
end

local function sync_trail(effect)
	local d = effect:GetData()
	local trail = trail_presets.sync(effect, d, "trail", C.BLOOD_TRAIL)
	if trail then
		trail.PositionOffset = Vector.Zero
	end
	return trail
end

function M.clear_all()
	for _, ent in ipairs(Isaac.FindByType(
		EntityType.ENTITY_EFFECT,
		enums.Entities.S_Sting_Reversed_Blood,
		-1,
		false,
		false
	)) do
		local d = ent:GetData()
		trail_presets.clear(d, "trail")
		ent:Remove()
	end
end

function M.spawn(ritual, npc, amount, opts)
	if not ritual or not ritual.anchor or not ritual.anchor:Exists() then
		return nil
	end
	if not npc then
		return nil
	end
	opts = opts or {}
	if not opts.allow_dead and (not npc:Exists() or npc:IsDead()) then
		return nil
	end

	local rng = ritual.rng
	if not rng then
		return nil
	end

	local amount_n = tonumber(amount) or 0
	local scale = (0.55 + math.min(amount_n / 24, 0.35)) * C.BLOOD_SCALE_MUL
	if opts.scale_mul then
		scale = scale * opts.scale_mul
	end

	local offset = opts.offset or Vector.Zero
	local blood = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		enums.Entities.S_Sting_Reversed_Blood,
		0,
		npc.Position + offset,
		Vector.Zero,
		ritual.owner
	):ToEffect()
	if not blood then
		return nil
	end

	blood.DepthOffset = 5
	blood.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	blood:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	if blood.SetTimeout then
		blood:SetTimeout(45)
	end

	local launch = opts.launch
	if not launch then
		launch = random_vector(rng):Resized(2.8 + rng:RandomFloat() * 4.2)
	end
	blood.Velocity = launch

	local d = blood:GetData()
	d.anchor = ritual.anchor
	d.ritual = ritual
	d.age = 0
	d.max_life = opts.max_life or 36
	d.base_scale = scale
	d.phase = opts.phase or (rng:RandomFloat() * math.pi * 2)
	d.launch_dir = launch:Normalized()
	d.absorb_offset = absorb_offset(rng)
	d.fill_amount = opts.fill_amount or C.BLOOD_FILL_PER_ORB
	blood.SpriteScale = Vector(scale, scale)

	local s = blood:GetSprite()
	if s:GetAnimation() ~= "Idle" then
		s:Play("Idle", true)
	end
	s.Color = Color(1, 0.3, 0.3, 0.92, 0.2, 0, 0)
	sync_trail(blood)
	return blood
end

function M.spawn_death_burst(ritual, npc)
	if not ritual or not ritual.anchor or not ritual.anchor:Exists() or not npc then
		return
	end
	local rng = ritual.rng
	if not rng then
		return
	end
	local count = 4 + rng:RandomInt(5) -- 4..8
	for _ = 1, count do
		local rad = 4 + rng:RandomFloat() * 16
		M.spawn(ritual, npc, 12, {
			allow_dead = true,
			offset = random_vector(rng):Resized(rad),
			scale_mul = 1.05,
			max_life = 40,
			fill_amount = C.BLOOD_FILL_DEATH,
			launch = random_vector(rng):Resized(3.5 + rng:RandomFloat() * 5),
		})
	end
end

function M.update(effect)
	local d = effect:GetData()
	local anchor = d.anchor
	local ritual = d.ritual
	if not anchor or not anchor:Exists() then
		trail_presets.clear(d, "trail")
		effect:Remove()
		return
	end

	local age = (tonumber(d.age) or 0) + 1
	d.age = age
	local max_life = tonumber(d.max_life) or 36
	if age > max_life then
		trail_presets.clear(d, "trail")
		effect:Remove()
		return
	end

	local target = anchor.Position + (d.absorb_offset or Vector.Zero)
	local delta = target - effect.Position
	local distance = delta:Length()
	local target_dir = distance > 0.001 and (delta / distance) or Vector.Zero
	local launch_dir = d.launch_dir or target_dir
	if launch_dir:Length() < 0.001 then
		launch_dir = target_dir
	end

	if distance < 8 then
		visual.on_blood_absorbed(ritual, anchor, tonumber(d.fill_amount) or C.BLOOD_FILL_PER_ORB)
		trail_presets.clear(d, "trail")
		effect:Remove()
		return
	end

	local speed
	local desired
	if age <= C.BLOOD_SPRAY_FRAMES then
		speed = math.max(2.4, effect.Velocity:Length() * 0.94)
		desired = launch_dir * speed
	elseif distance < C.BLOOD_ABSORB_DIST then
		speed = math.min(22, 9 + (C.BLOOD_ABSORB_DIST - distance) * 0.4 + age * 0.22)
		desired = target_dir * speed
	else
		-- Mostly spray → target; tiny tangent so it does not read as Chiastolite snake.
		local t = math.min(1, math.max(0, (age - C.BLOOD_SPRAY_FRAMES) / (C.BLOOD_PULL_FRAMES - C.BLOOD_SPRAY_FRAMES)))
		local t2 = t * t
		local one_minus = 1 - t
		local one_minus2 = one_minus * one_minus
		local blended = launch_dir * one_minus2 + target_dir * t2
		if blended:Length() < 0.001 then
			blended = target_dir
		else
			blended = blended:Normalized()
		end
		speed = (effect.Velocity:Length() + 2.6) * 0.9
		speed = math.min(17, math.max(3.8, speed))
		desired = blended * speed
	end

	effect.Velocity = effect.Velocity * 0.32 + desired * 0.68

	local base = tonumber(d.base_scale) or 0.7
	local pulse = 1 + 0.04 * math.sin(age * 0.4 + (tonumber(d.phase) or 0))
	local fade = 1
	if age > max_life - 5 then
		fade = math.max(0.3, (max_life - age + 1) / 5)
	end
	local sc = base * pulse * fade
	effect.SpriteScale = Vector(sc, sc)
	sync_trail(effect)
end

return M

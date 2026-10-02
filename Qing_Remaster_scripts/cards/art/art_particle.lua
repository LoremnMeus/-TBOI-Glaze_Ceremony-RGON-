local enums = require("Qing_Remaster_scripts.core.enums")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")

local M = {}

M.VARIANT = enums.Entities.Art_Effect
M.STATE = {
	IDLE = "idle",
	ORBIT_IN = "orbit_in",
	ORBIT = "orbit",
	CHASE = "chase",
	PASSIVE = "passive",
	EXPIRE = "expire",
}

local CFG = {
	pigment_anm2 = "gfx/global_particle.anm2",
	pigment_anim = "RegularTear8",
	flash_anm2 = "gfx/effects/explosive_flash.anm2",
	pigment_scale = 0.72,
	pigment_lift = -12,
	glow_offset = Vector(0, -12),
	orbit_radius = 28,
	orbit_spin = 4,
	orbit_blend_frames = 30,
	idle_speed_cap = 5,
	expire_frames = 28,
	ghost_appear_squash = 4,
	ghost_appear_expand = 8,
}
M.CFG = CFG

local ghost_glow_sprite = nil

local function valid(ent)
	return ent and ent:Exists() and not ent:IsDead()
end
M.valid = valid

local function clamp(v, a, b)
	return math.max(a, math.min(b, v))
end

local function smoother(t)
	t = clamp(t, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function tint(seed, frame, alpha)
	local t = ((tonumber(seed) or 0.37) + (frame or 0) * 0.08) * 6.28318530718
	local r = 0.45 + 0.55 * math.sin(t)
	local g = 0.45 + 0.55 * math.sin(t + 2.094)
	local b = 0.45 + 0.55 * math.sin(t + 4.189)
	return Color(r, g, b, alpha == nil and 0.92 or alpha, r * 0.25, g * 0.25, b * 0.25)
end
M.tint = tint

local function set_entity_motion_sample(ent, current_pos, next_pos)
	ent.Position = current_pos
	ent.Velocity = next_pos - current_pos
end

function M.set_motion_sample(ent, current_pos, next_pos)
	if not valid(ent) then return end
	set_entity_motion_sample(ent, current_pos, next_pos)
end

function M.set_position_static(ent, pos)
	if not valid(ent) then return end
	ent.Position, ent.Velocity = pos, Vector.Zero
end

function M.set_glow_lift(ent, lift)
	if not valid(ent) then return end
	local art = ent:GetData().art
	if art then
		art.glow_lift = tonumber(lift) or 0
	end
end

local function ensure_ghost_glow_sprite()
	if ghost_glow_sprite then
		return ghost_glow_sprite
	end
	local spr = Sprite()
	spr:Load(CFG.flash_anm2, true)
	spr:Play("Idle", true)
	ghost_glow_sprite = spr
	return spr
end

-- Gospel / Watcher style: WorldToRenderPosition(world + PO) + callback offset.
local function ghost_render_pos(ent, offset)
	local art = ent:GetData().art
	return Isaac.WorldToRenderPosition(ent.Position + (ent.PositionOffset or Vector.Zero))
		+ (offset or Vector.Zero)
		+ CFG.glow_offset
		+ Vector(0, (art and art.glow_lift) or 0)
end

function M.render_ghost_glow(ent, offset)
	if not valid(ent) then
		return
	end
	local art = ent:GetData().art
	if not art then
		return
	end
	if art.kind ~= "ghost" and not art.render_as_ghost then
		return
	end
	local room = Game():GetRoom()
	if room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end

	local sprite = ensure_ghost_glow_sprite()
	local host_sprite = ent:GetSprite()
	local alpha = host_sprite.Color and host_sprite.Color.A or 1
	local fill = clamp(art.fill or 0.5, 0, 1)
	local pulse = alpha * 0.30 * (0.85 + 0.15 * math.sin(ent.FrameCount * 0.18))
	local scale = (0.19 + 0.06 * fill) * (0.92 + 0.08 * math.sin(ent.FrameCount * 0.11))
	sprite.Scale = Vector(scale, scale)
	sprite.Color = tint(art.seed, ent.FrameCount, pulse)
	sprite:Render(ghost_render_pos(ent, offset), Vector.Zero, Vector.Zero)
end

local function orbit_pos(center, angle, radius)
	return center + Vector.FromAngle(angle) * radius
end

local function init_common(ent, owner, kind, seed)
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	ent.DepthOffset = 15
	local d = ent:GetData()
	d.art = {
		kind = kind,
		owner = owner,
		seed = seed or 0.37,
		state = M.STATE.IDLE,
		state_age = 0,
		candidate_cooldown = 0,
		glow_lift = 0,
	}
	return d.art
end

function M.spawn_pigment(owner, pos, serial)
	local ent = Isaac.Spawn(EntityType.ENTITY_EFFECT, M.VARIANT, 0, pos, Vector.Zero, owner):ToEffect()
	local art = init_common(ent, owner, "pigment", ((serial or 1) * 0.173) % 1)
	art.serial = serial or 1
	local sprite = ent:GetSprite()
	sprite:Load(CFG.pigment_anm2, true)
	sprite:Play(CFG.pigment_anim, true)
	sprite.Scale = Vector(CFG.pigment_scale, CFG.pigment_scale)
	sprite.Offset = Vector(0, CFG.pigment_lift)
	sprite.Color = tint(art.seed, 0)
	return ent
end

function M.refresh_visual_center(ent)
	if not valid(ent) then return end
	local art = ent:GetData().art
	if art then art.visual_center_base = ui.SpriteVisualCenterOffset(ent:GetSprite(), 0) end
end

function M.init_ghost_sprite(ent, visual)
	if not valid(ent) then return end
	local art, sprite = ent:GetData().art, ent:GetSprite()
	if art.ghost_sprite_initialized and art.visual and art.visual.anm2 == visual.anm2 then return end
	sprite:Load(visual.anm2, true)
	sprite:Play("Idle", true)
	if not sprite:IsPlaying("Idle") then sprite:Play("Appear", true) end
	if sprite.SetFrame then sprite:SetFrame(0) end
	pcall(function() if sprite.StopOverlay then sprite:StopOverlay() end end)
	temp_hud.apply_sprite_shader(sprite, temp_hud.RAINBOW_CELLULAR_SHADER)
	art.visual, art.ghost_sprite_initialized = visual, true
	M.refresh_visual_center(ent)
end

function M.ghost_scale(fill)
	return CFG.pigment_scale * (0.92 + 0.16 * clamp(fill or 0.5, 0, 1))
end

function M.get_ghost_center_offset(ent, sx, sy, lift)
	if not valid(ent) then return Vector.Zero end
	local base = ent:GetData().art.visual_center_base or Vector.Zero
	return Vector(0, lift or CFG.pigment_lift) - Vector(base.X * sx, base.Y * sy)
end

function M.compute_ghost_visual(ent, fill, x_mul, y_mul, lift)
	local base = M.ghost_scale(fill)
	local sx, sy = base * (x_mul or 1), base * (y_mul or x_mul or 1)
	return {
		sx = sx,
		sy = sy,
		center_offset = M.get_ghost_center_offset(ent, sx, sy, lift),
	}
end

function M.apply_ghost_visual(ent, visual, fill, alpha, state)
	if not valid(ent) then return end
	local art, sprite = ent:GetData().art, ent:GetSprite()
	sprite.Scale = Vector(state.sx, state.sy)
	sprite.Offset = state.center_offset
	sprite.Color = temp_hud.make_rainbow_cellular_color(alpha or 1, (tonumber(visual.seed) or 0.41) % 1)
	art.render_center_offset = state.center_offset
	art.render_scale = Vector(state.sx, state.sy)
end

function M.update_ghost_visual_xy(ent, visual, fill, alpha, x_mul, y_mul, lift)
	M.apply_ghost_visual(ent, visual, fill, alpha, M.compute_ghost_visual(ent, fill, x_mul, y_mul, lift))
end

function M.update_ghost_visual(ent, visual, fill, alpha, scale_mul, lift)
	M.update_ghost_visual_xy(ent, visual, fill, alpha, scale_mul, scale_mul, lift)
end

-- Runtime rebuild helper only. Normal pigment-to-ghost crafting promotes the
-- existing subject in place so the pickup sprite and shader are not reloaded.
function M.spawn_ghost(owner, pos, visual, fill)
	local ent = Isaac.Spawn(EntityType.ENTITY_EFFECT, M.VARIANT, 0, pos, Vector.Zero, owner):ToEffect()
	local art = init_common(ent, owner, "ghost", visual.seed)
	art.state = M.STATE.ORBIT_IN
	art.orbit_from = Vector(pos.X, pos.Y)
	art.orbit_angle = 0
	art.orbit_radius0 = math.max(4, pos:Distance(owner.Position))
	art.visual = visual
	art.fill = fill or 0.5
	art.appear_age = 0
	art.glow_lift = 0
	M.init_ghost_sprite(ent, visual)
	M.update_ghost_visual(ent, visual, art.fill, 1, 1, CFG.pigment_lift)
	return ent
end

function M.promote_to_ghost(ent, owner, visual, fill)
	if not valid(ent) then return nil end
	local art = ent:GetData().art
	art.kind, art.owner, art.visual, art.fill = "ghost", owner, visual, fill or 0.5
	art.target, art.chase_profile, art.state_age = nil, nil, 0
	art.render_as_ghost = nil
	art.glow_lift = 0
	M.init_ghost_sprite(ent, visual)
	M.update_ghost_visual(ent, visual, art.fill, 1, 1, CFG.pigment_lift)
	return ent
end

function M.ghost_appear_scale(age, base)
	base = base or CFG.pigment_scale
	local squash, expand = CFG.ghost_appear_squash, CFG.ghost_appear_expand
	if age <= squash then
		local u = age / math.max(1, squash)
		local e = u * u * (3 - 2 * u)
		return Vector(base * (1 + 0.5 * e), base * (1 - 0.48 * e))
	end
	local u = clamp((age - squash) / math.max(1, expand), 0, 1)
	local e = u * u * (3 - 2 * u)
	local over = math.sin(e * math.pi) * 0.12
	local sx = 1.5 + (1 - 1.5) * e
	local sy = 0.52 + (1 - 0.52) * e
	return Vector(base * (sx - over * 0.5), base * (sy + over))
end

function M.spawn_flash(owner, pos, strong, initial_velocity)
	local ent = Isaac.Spawn(EntityType.ENTITY_EFFECT, M.VARIANT, 0, pos, initial_velocity or Vector.Zero, owner):ToEffect()
	local rng = ent:GetDropRNG()
	local seed = 0.05 + rng:RandomFloat() * 0.9
	local art = init_common(ent, owner, "flash", seed)
	art.expand = strong and 5 or 8
	art.fade = strong and 6 or 8
	art.life = art.expand + art.fade
	art.scale_start = strong and 0.2 or 0.08
	art.scale_peak = strong and 0.46 or 0.38
	art.alpha_peak = strong and 0.52 or 0.38
	art.ground = strong == true
	local sprite = ent:GetSprite()
	sprite:Load(CFG.flash_anm2, true)
	sprite:Play("Idle", true)
	sprite.Offset = strong and Vector.Zero or Vector(0, CFG.pigment_lift)
	-- Spawn 当帧可能早于第一次 Effect Update 渲染；首帧外观必须在这里原子初始化。
	local initial_alpha = strong and (art.alpha_peak * 0.55) or 0.08
	sprite.Scale = Vector(art.scale_start, art.scale_start)
	sprite.Color = tint(art.seed, 0, initial_alpha)
	ent.SortingLayer = 0
	ent.DepthOffset = -20
	return ent
end

function M.start_orbit(ent, owner)
	if not valid(ent) then return end
	local art = ent:GetData().art
	art.owner = owner
	art.state = M.STATE.ORBIT_IN
	art.state_age = 0
	art.orbit_from = Vector(ent.Position.X, ent.Position.Y)
	art.orbit_angle = (ent.Position - owner.Position):GetAngleDegrees()
	art.orbit_radius0 = math.max(4, ent.Position:Distance(owner.Position))
	art.target = nil
	art.chase_profile = nil
	art.glow_lift = 0
end

function M.start_chase(ent, target, profile)
	if not valid(ent) then return end
	local art = ent:GetData().art
	art.state = M.STATE.CHASE
	art.state_age = 0
	art.target = target
	art.chase_profile = profile or "default"
end

function M.set_passive(ent)
	if not valid(ent) then return end
	local art = ent:GetData().art
	art.state, art.state_age, art.target = M.STATE.PASSIVE, 0, nil
	art.chase_profile = nil
end

function M.set_idle(ent)
	if not valid(ent) then return end
	local art = ent:GetData().art
	art.state, art.state_age, art.target = M.STATE.IDLE, 0, nil
	art.chase_profile = nil
end

function M.release_candidate(ent, cooldown)
	if not valid(ent) then return end
	local art = ent:GetData().art
	M.set_idle(ent)
	art.candidate_cooldown = cooldown or 30
end

function M.expire(ent)
	if not valid(ent) then return end
	local art = ent:GetData().art
	art.state = M.STATE.EXPIRE
	art.state_age = 0
	art.expire_alpha = ent:GetSprite().Color.A
	ent.Velocity = ent.Velocity * 0.4
end

function M.remove(ent)
	if not valid(ent) then return end
	ent:Remove()
end

local function tick_orbit(ent, art)
	local owner = art.owner
	if not valid(owner) then M.expire(ent) return end
	art.orbit_angle = art.orbit_angle or 0
	local age = art.state_age
	local radius = CFG.orbit_radius
	if art.state == M.STATE.ORBIT_IN then
		local t0 = clamp(age / CFG.orbit_blend_frames, 0, 1)
		local t1 = clamp((age + 1) / CFG.orbit_blend_frames, 0, 1)
		local e0, e1 = smoother(t0), smoother(t1)
		local a0 = art.orbit_angle + CFG.orbit_spin * age
		local a1 = art.orbit_angle + CFG.orbit_spin * (age + 1)
		local target0 = orbit_pos(owner.Position, a0, radius)
		local target1 = orbit_pos(owner.Position + owner.Velocity, a1, radius)
		local current = art.orbit_from * (1 - e0) + target0 * e0
		local next_pos = art.orbit_from * (1 - e1) + target1 * e1
		M.set_motion_sample(ent, current, next_pos)
		if age >= CFG.orbit_blend_frames then
			art.state = M.STATE.ORBIT
			art.state_age = 0
			art.orbit_angle = a0
		end
	else
		local current = orbit_pos(owner.Position, art.orbit_angle, radius)
		local next_angle = art.orbit_angle + CFG.orbit_spin
		local next_pos = orbit_pos(owner.Position + owner.Velocity, next_angle, radius)
		M.set_motion_sample(ent, current, next_pos)
		art.orbit_angle = next_angle
	end
end

local function tick_idle(ent, art)
	local owner = art.owner
	if not valid(owner) then M.expire(ent) return end
	local to = owner.Position - ent.Position
	local dist = to:Length()
	local desired = Vector.Zero
	if dist > 0.1 then desired = to:Normalized() * math.min(4.5, 1.5 + dist * 0.025) end
	ent.Velocity = ent.Velocity * 0.82 + desired * 0.18
	if ent.Velocity:Length() > CFG.idle_speed_cap then ent.Velocity = ent.Velocity:Resized(CFG.idle_speed_cap) end
end

local function tick_chase(ent, art)
	local target = art.target
	if not valid(target) then M.release_candidate(ent, 15) return end
	local to = target.Position - ent.Position
	local dist = to:Length()
	local desired = dist > 0.1 and to:Normalized() * clamp(3 + dist * 0.06, 4, 9) or Vector.Zero
	ent.Velocity = ent.Velocity * 0.65 + desired * 0.35
end

local function tick_merge_chase(ent, art)
	local target = art.target
	if not valid(target) then M.release_candidate(ent, 15) return end
	local to = target.Position - ent.Position
	local dist = to:Length()
	if dist <= 0.1 then return end
	local speed = clamp(7 + dist * 0.075, 8, 14)
	local desired = to:Normalized() * speed
	ent.Velocity = ent.Velocity * 0.35 + desired * 0.65
end

function M.update(ent)
	local art = ent:GetData().art
	if not art then ent:Remove() return end
	art.state_age = (art.state_age or 0) + 1
	art.candidate_cooldown = math.max(0, (art.candidate_cooldown or 0) - 1)
	if art.kind == "flash" then
		local sprite = ent:GetSprite()
		local scale, alpha
		if art.state_age <= art.expand then
			local u = art.state_age / math.max(1, art.expand)
			local e = u * u * (3 - 2 * u)
			scale = art.scale_start + (art.scale_peak - art.scale_start) * e
			alpha = art.alpha_peak * (0.45 + 0.55 * e)
		else
			local u = clamp((art.state_age - art.expand) / math.max(1, art.fade), 0, 1)
			scale = art.scale_peak * (1 - 0.2 * u)
			alpha = art.alpha_peak * (1 - u) * (1 - u)
		end
		sprite.Scale = Vector(scale, scale)
		sprite.Color = tint(art.seed, art.state_age, math.max(0, alpha))
		if art.state_age >= art.life then ent:Remove() end
		return
	end
	if art.state == M.STATE.IDLE then tick_idle(ent, art)
	elseif art.state == M.STATE.ORBIT_IN or art.state == M.STATE.ORBIT then tick_orbit(ent, art)
	elseif art.state == M.STATE.CHASE then
		if art.chase_profile == "art_merge" then tick_merge_chase(ent, art) else tick_chase(ent, art) end
	elseif art.state == M.STATE.PASSIVE then return
	elseif art.state == M.STATE.EXPIRE then
		local alpha = 1 - clamp(art.state_age / CFG.expire_frames, 0, 1)
		ent.Velocity = ent.Velocity * 0.88
		if art.kind == "ghost" or art.render_as_ghost then
			local sprite = ent:GetSprite()
			temp_hud.apply_sprite_shader(sprite, temp_hud.RAINBOW_CELLULAR_SHADER)
			sprite.Color = temp_hud.make_rainbow_cellular_color(alpha * (art.expire_alpha or 1), (tonumber(art.seed) or 0.41) % 1)
		else
			ent:GetSprite().Color = tint(art.seed, ent.FrameCount, alpha * (art.expire_alpha or 1))
		end
		if art.state_age >= CFG.expire_frames then ent:Remove() end
	end
	if art.kind == "pigment" and not art.render_as_ghost and art.state ~= M.STATE.EXPIRE then
		ent:GetSprite().Color = tint(art.seed, ent.FrameCount)
	elseif (art.kind == "ghost" or art.render_as_ghost) and art.state ~= M.STATE.EXPIRE and art.appear_age ~= nil then
		art.appear_age = art.appear_age + 1
		local scale0 = M.ghost_appear_scale(art.appear_age, M.ghost_scale(art.fill))
		local state0 = {sx = scale0.X, sy = scale0.Y, center_offset = M.get_ghost_center_offset(ent, scale0.X, scale0.Y, CFG.pigment_lift)}
		M.apply_ghost_visual(ent, art.visual, art.fill, 1, state0)
		if art.appear_age >= CFG.ghost_appear_squash + CFG.ghost_appear_expand then art.appear_age = nil end
	end
end

return M

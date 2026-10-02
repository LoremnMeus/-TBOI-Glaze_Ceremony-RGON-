local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local particle = require("Qing_Remaster_scripts.cards.art.art_particle")

local M = {}
local KEY = "Thoth_cd14_Art_craft"
local CURRENT_SCHEMA = 2
local PROGRESS_EPSILON = 0.75
local STALL_LIMIT = 24
local CHASE_TIMEOUT = 90
local CANDIDATE_COOLDOWN = 30
local STICK_FRAMES = 5
local MORPH_FRAMES = 14
local MORPH_SQUASH_FRAMES = 5
local MORPH_EXPAND_FRAMES = 9
local MORPH_SWITCH_AGE = MORPH_SQUASH_FRAMES + math.floor(MORPH_EXPAND_FRAMES * 0.3 + 0.5)
local THIRD = {
	seek_engage_dist = 64, engage_frames = 10, engage_subject_step = 10,
	absorb_frames = 9, pop_frames = 5, drop_frames = 12,
	pop_height = 10, max_drop_distance = 80, seek_stall_limit = 40, seek_timeout = 120,
}

local PICKUP_VISUAL = {
	{variant = PickupVariant.PICKUP_HEART, subtype = HeartSubType.HEART_FULL, anm2 = "gfx/005.011_heart.anm2"},
	{variant = PickupVariant.PICKUP_COIN, subtype = CoinSubType.COIN_PENNY, anm2 = "gfx/005.021_penny.anm2"},
	{variant = PickupVariant.PICKUP_BOMB, subtype = BombSubType.BOMB_NORMAL, anm2 = "gfx/005.041_bomb.anm2"},
	{variant = PickupVariant.PICKUP_KEY, subtype = KeySubType.KEY_NORMAL, anm2 = "gfx/005.031_key.anm2"},
	{variant = PickupVariant.PICKUP_LIL_BATTERY, subtype = BatterySubType.BATTERY_NORMAL, anm2 = "gfx/005.090_littlebattery.anm2"},
}

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function valid(ent) return particle.valid(ent) end
local function copy_pos(v) return Vector(v.X, v.Y) end
local function smoothstep(t) t = clamp(t, 0, 1) return t * t * (3 - 2 * t) end
local function vec_lerp(a, b, t) return a * (1 - t) + b * t end
local function inertia_curve(velocity, t, strength) return velocity * (t * (1 - t) * strength) end
local function phase_samples(age, frames)
	local denom = math.max(1, frames - 1)
	return clamp((age - 1) / denom, 0, 1), clamp(age / denom, 0, 1)
end

local function find_art_drop_pos(anchor)
	local pos = Game():GetRoom():FindFreePickupSpawnPosition(anchor, 20, true) or anchor
	local delta = pos - anchor
	if delta:Length() > THIRD.max_drop_distance then return anchor + delta:Resized(THIRD.max_drop_distance) end
	return pos
end

function M.get(player)
	local d = player:GetData()
	if type(d[KEY]) ~= "table" then
		d[KEY] = {schema = CURRENT_SCHEMA, stage = 0, orbit = nil, ghost = nil, particles = {}, merge = nil, serial = 0, expiring = false, dirty = false}
	elseif d[KEY].schema ~= CURRENT_SCHEMA then
		local craft = d[KEY]
		if type(craft.particles) ~= "table" then
			local old_count = tonumber(craft.particles) or 0
			particle.remove(craft.orbit)
			particle.remove(craft.ghost)
			craft.stage = old_count >= 2 and 2 or (old_count == 1 and 1 or 0)
			craft.visual = craft.visual or craft.ghost_visual
			craft.particles, craft.orbit, craft.ghost, craft.merge = {}, nil, nil, nil
		end
		craft.ghost_visual = nil
		craft.serial = tonumber(craft.serial) or 0
		craft.expiring = false
		craft.pending_merger, craft.pending_result = nil, nil
		craft.merge_candidate, craft.merge_candidate_ent = nil, nil
		craft.schema, craft.dirty = CURRENT_SCHEMA, true
	end
	return d[KEY]
end

local function peek(player)
	return player:GetData()[KEY]
end

local function pick_visual(player)
	local rng = auxi.rng_for_sake(player:GetCardRNG(enums.Cards.Art))
	local index = rng:RandomInt(#PICKUP_VISUAL) + 1
	local src = PICKUP_VISUAL[index]
	return {variant = src.variant, subtype = src.subtype, anm2 = src.anm2, seed = rng:RandomFloat()}
end

local function register(craft, ent)
	craft.particles[GetPtrHash(ent)] = ent
	return ent
end

local function unregister(craft, ent)
	if ent then craft.particles[GetPtrHash(ent)] = nil end
end

local function prune(craft)
	for ptr, ent in pairs(craft.particles) do
		if not valid(ent) then craft.particles[ptr] = nil end
	end
end

local function each(craft, fn)
	prune(craft)
	for _, ent in pairs(craft.particles) do fn(ent, ent:GetData().art) end
end

-- craft.stage 已经单独代表环绕主体/虚影；这里只统计尚未提交转化的普通颜料。
-- 合成途中被 claim 的 incoming 仍属于可恢复颜料，退出或换房不能吞掉它。
local function recoverable_loose_count(craft)
	local orbit_ptr = valid(craft.orbit) and GetPtrHash(craft.orbit) or nil
	local count = 0
	each(craft, function(ent, art)
		if (not orbit_ptr or GetPtrHash(ent) ~= orbit_ptr)
			and art and art.kind == "pigment" and art.state ~= particle.STATE.EXPIRE then
			count = count + 1
		end
	end)
	return count
end

local function rebuild_loose_pigments(player, craft, count)
	count = math.max(0, math.floor(tonumber(count) or 0))
	for i = 1, count do
		craft.serial = (craft.serial or 0) + 1
		local angle = (i - 1) * 137.507764
		local radius = 34 + 6 * ((i - 1) % 4)
		local pos = player.Position + Vector.FromAngle(angle) * radius
		register(craft, particle.spawn_pigment(player, pos, craft.serial))
	end
end

function M.spawn_pigment(player, pos)
	local craft = M.get(player)
	if craft.expiring then return nil end
	craft.serial = (craft.serial or 0) + 1
	craft.dirty = true
	return register(craft, particle.spawn_pigment(player, pos, craft.serial))
end

local function choose_candidate(craft, target)
	if not valid(target) then return nil end
	local best, best_score
	each(craft, function(ent, art)
		if art and art.kind == "pigment" and art.state == particle.STATE.IDLE and (art.candidate_cooldown or 0) <= 0 then
			local score = ent.Position:Distance(target.Position)
			if best_score == nil or score < best_score or (score == best_score and (art.serial or 0) < (best:GetData().art.serial or 0)) then
				best, best_score = ent, score
			end
		end
	end)
	return best
end

local function choose_first(craft)
	local best, serial
	each(craft, function(ent, art)
		if art and art.kind == "pigment" and art.state == particle.STATE.IDLE then
			if serial == nil or (art.serial or 0) < serial then best, serial = ent, art.serial or 0 end
		end
	end)
	return best
end

local function begin_merge(player, craft, result, subject, incoming)
	if result == "pickup" then
		-- 第三轮必须分为 SEEK 与 ENGAGE：SEEK 让真实颜料从远处快速飞来，
		-- ENGAGE 再让 Ghost 主动响应；禁止选中 candidate 后直接进入预制动画。
		particle.start_chase(incoming, subject, "art_merge")
		craft.merge = {
			result = result, subject = subject, incoming = incoming,
			phase = "pickup_seek", age = 0, stall_frames = 0, best_dist = nil,
		}
		return
	else
		particle.set_passive(subject)
		particle.set_passive(incoming)
	end
	craft.merge = {
		result = result,
		subject = subject,
		incoming = incoming,
		phase = result == "ghost" and "approach" or "chase",
		age = 0,
		stall_frames = 0,
		last_dist = nil,
	}
end

local function abort_merge(craft)
	local m = craft.merge
	if m and valid(m.incoming) then particle.release_candidate(m.incoming, CANDIDATE_COOLDOWN) end
	if m and valid(m.subject) then
		particle.set_glow_lift(m.subject, 0)
		if m.result == "pickup" and m.phase == "pickup_seek" then
			-- 此阶段 Ghost 从未离开轨道，不能重新触发 ORBIT_IN。
			craft.ghost = m.subject
		else
			local art = m.subject:GetData().art
			particle.start_orbit(m.subject, art and art.owner)
			if m.result == "ghost" then craft.orbit = m.subject else craft.ghost = m.subject end
		end
	end
	craft.merge = nil
end

local function spawn_ghost(player, craft, pos)
	craft.visual = craft.visual or pick_visual(player)
	craft.ghost = particle.spawn_ghost(player, pos, craft.visual, 0.5)
	craft.stage = 2
	craft.dirty = true
end

local function spawn_pickup(player, craft, pos)
	local visual = craft.visual or pick_visual(player)
	local pickup = Isaac.Spawn(EntityType.ENTITY_PICKUP, visual.variant, visual.subtype, pos, Vector.Zero, player)
	if pickup then pickup:GetData().Thoth_cd14_Art_land_bounce = 0 end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1, 0.45, 1.08, false, 0, 2)
	craft.stage = 0
	craft.visual = nil
	craft.orbit = nil
	craft.ghost = nil
	craft.dirty = true
end

local function finish_ghost_merge(player, craft, m)
	if not valid(m.subject) then abort_merge(craft) return end
	if valid(m.incoming) then unregister(craft, m.incoming) particle.remove(m.incoming) end
	unregister(craft, m.subject)
	local ghost = particle.promote_to_ghost(m.subject, player, craft.visual, 0.5)
	craft.orbit, craft.ghost, craft.stage, craft.merge, craft.dirty = nil, ghost, 2, nil, true
	particle.start_orbit(ghost, player)
end

local function finish_pickup_merge(player, craft, m)
	local pos = m.drop_pos or m.subject.Position
	unregister(craft, m.incoming)
	particle.remove(m.incoming)
	particle.remove(m.subject)
	craft.merge = nil
	spawn_pickup(player, craft, pos)
end

local function tick_approach(craft, m)
	if not valid(m.subject) or not valid(m.incoming) then abort_merge(craft) return end
	m.age = m.age + 1
	local delta = m.incoming.Position - m.subject.Position
	local dist = delta:Length()
	local dir = dist > 0.01 and delta:Normalized() or Vector(1, 0)
	local speed_subject, speed_incoming
	if dist > 48 then speed_subject, speed_incoming = 9.5, 2.5
	elseif dist > 16 then speed_subject, speed_incoming = 4.5, 4.5
	else speed_subject, speed_incoming = 3, 3 end
	m.subject.Velocity = dir * speed_subject
	m.incoming.Velocity = dir * -speed_incoming
	if m.last_dist == nil or dist < m.last_dist - PROGRESS_EPSILON then m.stall_frames = 0
	else m.stall_frames = m.stall_frames + 1 end
	m.last_dist = dist
	if m.stall_frames >= STALL_LIMIT or m.age >= CHASE_TIMEOUT then abort_merge(craft) return end
	if dist <= 8 then
		m.phase = "stick"
		m.age = 0
		m.anchor = (m.subject.Position + m.incoming.Position) * 0.5
	end
end

local function tick_stick(craft, m)
	if not valid(m.subject) or not valid(m.incoming) then abort_merge(craft) return end
	m.age = m.age + 1
	local axis = m.subject.Position - m.incoming.Position
	if axis:Length() < 0.1 then axis = Vector(1, 0) else axis = axis:Normalized() end
	local spread = 5 * (1 - clamp(m.age / STICK_FRAMES, 0, 1))
	local a, b = m.anchor + axis * spread, m.anchor - axis * spread
	m.subject.Velocity = (a - m.subject.Position) * 0.55
	m.incoming.Velocity = (b - m.incoming.Position) * 0.55
	if m.age >= STICK_FRAMES then
		m.phase = "morph"
		m.age = 0
		m.anchor = (m.subject.Position + m.incoming.Position) * 0.5
		m.subject.Position, m.incoming.Position = m.anchor, m.anchor
		m.subject.Velocity, m.incoming.Velocity = Vector.Zero, Vector.Zero
		m.incoming.Visible = false
		craft.visual = craft.visual or pick_visual(m.subject:GetData().art.owner)
		craft.dirty = true
		particle.spawn_flash(m.subject:GetData().art.owner, m.anchor, false)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SOUL_PICKUP, 0.32, 1.12, false, 0, 2)
	end
end

local function morph_scale(age, base)
	if age <= MORPH_SQUASH_FRAMES then
		local u = age / MORPH_SQUASH_FRAMES
		local e = u * u * (3 - 2 * u)
		return Vector(base * (1 + 0.45 * e), base * (1 - 0.42 * e))
	end
	local u = clamp((age - MORPH_SQUASH_FRAMES) / MORPH_EXPAND_FRAMES, 0, 1)
	local e = u * u * (3 - 2 * u)
	local mul = 0.58 + (1.28 - 0.58) * math.sin(e * math.pi)
	if u >= 1 then mul = 1.05 end
	return Vector(base * mul, base * mul)
end

local function tick_morph(player, craft, m)
	if not valid(m.subject) then abort_merge(craft) return end
	m.age = m.age + 1
	particle.set_position_static(m.subject, m.anchor)
	if m.age >= MORPH_SWITCH_AGE and not m.switched then
		m.switched = true
		particle.init_ghost_sprite(m.subject, craft.visual)
		local art = m.subject:GetData().art
		art.render_as_ghost = true
		art.fill = 0.5
		art.glow_lift = 0
	end
	local base = m.switched and particle.ghost_scale(0.5) or 0.72
	local scale = morph_scale(m.age, base)
	if m.switched then
		local ghost_base = particle.ghost_scale(0.5)
		particle.update_ghost_visual_xy(m.subject, craft.visual, 0.5, 1,
			scale.X / ghost_base, scale.Y / ghost_base, particle.CFG.pigment_lift)
	else
		m.subject:GetSprite().Scale = scale
	end
	if m.age >= MORPH_FRAMES then finish_ghost_merge(player, craft, m) end
end

local function begin_pickup_engage(craft, m)
	if not valid(m.subject) or not valid(m.incoming) then abort_merge(craft) return end
	m.phase, m.age = "pickup_engage", 0
	m.subject_start_pos, m.subject_start_vel = copy_pos(m.subject.Position), copy_pos(m.subject.Velocity)
	m.incoming_start_pos, m.incoming_start_vel = copy_pos(m.incoming.Position), copy_pos(m.incoming.Velocity)
	local delta = m.incoming_start_pos - m.subject_start_pos
	local dir = delta:Length() > 0.01 and delta:Normalized() or Vector.Zero
	-- Ghost 只迎出一小段，主体中心仍明显由既有 Ghost 决定。
	m.anchor = m.subject_start_pos + dir * THIRD.engage_subject_step
	m.drop_pos = find_art_drop_pos(m.anchor)
	particle.set_passive(m.subject)
	particle.set_passive(m.incoming)
	particle.set_glow_lift(m.subject, 0)
end

local function tick_pickup_seek(craft, m)
	if not valid(m.subject) or not valid(m.incoming) then abort_merge(craft) return end
	m.age = m.age + 1
	local dist = m.incoming.Position:Distance(m.subject.Position)
	if m.best_dist == nil or dist < m.best_dist - 2 then
		m.best_dist = dist
		m.stall_frames = 0
	else
		m.stall_frames = m.stall_frames + 1
	end
	if m.stall_frames >= THIRD.seek_stall_limit or m.age >= THIRD.seek_timeout then abort_merge(craft) return end
	if dist <= THIRD.seek_engage_dist then begin_pickup_engage(craft, m) end
end

local function tick_pickup_engage(craft, m)
	if not valid(m.subject) or not valid(m.incoming) then abort_merge(craft) return end
	m.age = m.age + 1
	local t0, t1 = phase_samples(m.age, THIRD.engage_frames)
	local e0, e1 = smoothstep(t0), smoothstep(t1)
	local sc = vec_lerp(m.subject_start_pos, m.anchor, e0) + inertia_curve(m.subject_start_vel, t0, 0.90)
	local sn = vec_lerp(m.subject_start_pos, m.anchor, e1) + inertia_curve(m.subject_start_vel, t1, 0.90)
	local ic = vec_lerp(m.incoming_start_pos, m.anchor, e0) + inertia_curve(m.incoming_start_vel, t0, 0.35)
	local inn = vec_lerp(m.incoming_start_pos, m.anchor, e1) + inertia_curve(m.incoming_start_vel, t1, 0.35)
	particle.set_motion_sample(m.subject, sc, sn)
	particle.set_motion_sample(m.incoming, ic, inn)
	if m.age >= THIRD.engage_frames then
		m.phase, m.age, m.incoming_from = "absorb", 0, copy_pos(m.incoming.Position)
		particle.set_position_static(m.subject, m.anchor)
		particle.set_glow_lift(m.subject, 0)
	end
end

local function tick_pickup_absorb(player, craft, m)
	if not valid(m.subject) or not valid(m.incoming) then abort_merge(craft) return end
	m.age = m.age + 1
	local t0, t1 = phase_samples(m.age, THIRD.absorb_frames)
	local e0, e1 = t0 * t0, t1 * t1
	local current, next_pos = vec_lerp(m.incoming_from, m.anchor, e0), vec_lerp(m.incoming_from, m.anchor, e1)
	particle.set_motion_sample(m.incoming, current, next_pos)
	local incoming_sprite = m.incoming:GetSprite()
	local remain = 1 - e0
	local pigment_scale = particle.CFG.pigment_scale * (0.12 + 0.88 * remain)
	incoming_sprite.Scale = Vector(pigment_scale, pigment_scale)
	incoming_sprite.Color = particle.tint(m.incoming:GetData().art.seed, m.incoming.FrameCount, remain * remain)
	local fill0 = 0.5 + 0.5 * smoothstep(t0)
	local pulse0 = 1 + 0.06 * math.sin(math.pi * smoothstep(t0))
	local visual0 = particle.compute_ghost_visual(m.subject, fill0, pulse0, pulse0, particle.CFG.pigment_lift)
	particle.set_position_static(m.subject, m.anchor)
	particle.set_glow_lift(m.subject, 0)
	m.subject:GetData().art.fill = fill0
	particle.apply_ghost_visual(m.subject, craft.visual, fill0, 1, visual0)
	if m.age >= THIRD.absorb_frames then
		m.incoming.Visible = false
		m.phase = "pop"
		m.age = 0
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME, 0.22, 1.35, false, 0, 2)
	end
end

local function pop_scale(t)
	if t < 0.4 then local e = smoothstep(t / 0.4) return 1 + 0.14 * e, 1 - 0.12 * e end
	if t < 0.75 then local e = smoothstep((t - 0.4) / 0.35) return 1.14 * (1-e) + 0.96*e, 0.88*(1-e)+1.08*e end
	local e = smoothstep((t - 0.75) / 0.25) return 0.96*(1-e)+e, 1.08*(1-e)+e
end

local function tick_pickup_pop(craft, m)
	if not valid(m.subject) then abort_merge(craft) return end
	m.age = m.age + 1
	local t0 = phase_samples(m.age, THIRD.pop_frames)
	local sx, sy = pop_scale(t0)
	local lift = -THIRD.pop_height * math.sin(t0 * math.pi * 0.5)
	m.subject:GetData().art.fill = 1
	local visual0 = particle.compute_ghost_visual(m.subject, 1, sx, sy, particle.CFG.pigment_lift + lift)
	particle.set_position_static(m.subject, m.anchor)
	particle.set_glow_lift(m.subject, lift)
	particle.apply_ghost_visual(m.subject, craft.visual, 1, 1, visual0)
	if m.age >= THIRD.pop_frames then m.phase, m.age = "drop", 0 end
end

local function tick_pickup_drop(player, craft, m)
	if not valid(m.subject) then abort_merge(craft) return end
	m.age = m.age + 1
	local t0, t1 = phase_samples(m.age, THIRD.drop_frames)
	local current, next_pos = vec_lerp(m.anchor, m.drop_pos, smoothstep(t0)), vec_lerp(m.anchor, m.drop_pos, smoothstep(t1))
	local height0 = -THIRD.pop_height * (1 - t0 * t0)
	local visual0 = particle.compute_ghost_visual(m.subject, 1, 1, 1, particle.CFG.pigment_lift + height0)
	particle.set_motion_sample(m.subject, current, next_pos)
	particle.set_glow_lift(m.subject, height0)
	particle.apply_ghost_visual(m.subject, craft.visual, 1, 1, visual0)
	if m.age >= THIRD.drop_frames then finish_pickup_merge(player, craft, m) end
end

local function tick_merge(player, craft)
	local m = craft.merge
	if not m then return end
	if m.phase == "approach" then tick_approach(craft, m)
	elseif m.phase == "stick" then tick_stick(craft, m)
	elseif m.phase == "morph" then tick_morph(player, craft, m)
	elseif m.phase == "pickup_seek" then tick_pickup_seek(craft, m)
	elseif m.phase == "pickup_engage" then tick_pickup_engage(craft, m)
	elseif m.phase == "absorb" then tick_pickup_absorb(player, craft, m)
	elseif m.phase == "pop" then tick_pickup_pop(craft, m)
	elseif m.phase == "drop" then tick_pickup_drop(player, craft, m) end
end

local function schedule(player, craft)
	if craft.stage == 0 then
		local first = choose_first(craft)
		if first then
			craft.orbit = first
			craft.stage = 1
			craft.dirty = true
			particle.start_orbit(first, player)
		end
	elseif craft.stage == 1 and valid(craft.orbit) then
		local incoming = choose_candidate(craft, craft.orbit)
		if incoming then begin_merge(player, craft, "ghost", craft.orbit, incoming) end
	elseif craft.stage == 2 and valid(craft.ghost) then
		local incoming = choose_candidate(craft, craft.ghost)
		if incoming then begin_merge(player, craft, "pickup", craft.ghost, incoming) end
	end
end

local function rebuild_stage_entity(player, craft)
	if craft.stage == 1 then
		craft.serial = (craft.serial or 0) + 1
		local ent = register(craft, particle.spawn_pigment(player, player.Position + Vector(28, 0), craft.serial))
		craft.orbit = ent
		particle.start_orbit(ent, player)
	elseif craft.stage == 2 then
		craft.visual = craft.visual or pick_visual(player)
		craft.ghost = particle.spawn_ghost(player, player.Position + Vector(28, 0), craft.visual, 0.5)
	end
end

function M.tick(player, active)
	local craft = peek(player)
	if not craft then
		if not active then return end
		craft = M.get(player)
	end
	prune(craft)
	if not active then
		if not craft.expiring then
			craft.expiring = true
			craft.dirty = true
			craft.merge = nil
			each(craft, function(ent) particle.expire(ent) end)
			if valid(craft.ghost) then particle.expire(craft.ghost) end
		end
		local any = false
		each(craft, function() any = true end)
		if valid(craft.ghost) then any = true end
		if not any then
			craft.stage, craft.orbit, craft.ghost, craft.merge, craft.visual = 0, nil, nil, nil, nil
			craft.expiring = false
			craft.dirty = true
		end
		return
	end
	if craft.expiring then return end
	if craft.stage == 1 and not valid(craft.orbit) then
		rebuild_stage_entity(player, craft)
	elseif craft.stage == 2 and not valid(craft.ghost) then
		rebuild_stage_entity(player, craft)
	end
	if craft.merge then tick_merge(player, craft) else schedule(player, craft) end
end

function M.on_new_room(player)
	local craft = peek(player)
	if not craft then return end
	local loose_count = recoverable_loose_count(craft)
	each(craft, function(ent) particle.remove(ent) end)
	craft.particles = {}
	particle.remove(craft.ghost)
	craft.orbit, craft.ghost, craft.merge = nil, nil, nil
	rebuild_stage_entity(player, craft)
	rebuild_loose_pigments(player, craft, loose_count)
	craft.dirty = true
end

function M.is_dirty(player)
	local craft = peek(player)
	return craft and craft.dirty == true or false
end

function M.clear_dirty(player)
	local craft = peek(player)
	if craft then craft.dirty = false end
end

function M.snapshot(player)
	local craft = peek(player)
	if not craft then return nil end
	local loose_count = recoverable_loose_count(craft)
	if (tonumber(craft.stage) or 0) <= 0 and loose_count <= 0 then return nil end
	local visual = craft.visual
	return {
		stage = craft.stage,
		serial = tonumber(craft.serial) or 0,
		loose_count = loose_count,
		visual = visual and {
			variant = visual.variant,
			subtype = visual.subtype,
			anm2 = visual.anm2,
			seed = visual.seed,
		} or nil,
	}
end

function M.reset_runtime(player, persisted)
	local craft = M.get(player)
	craft.stage = persisted and math.max(0, math.min(2, tonumber(persisted.stage) or 0)) or 0
	craft.serial = persisted and (tonumber(persisted.serial) or 0) or 0
	craft.visual = persisted and persisted.visual or nil
	craft.particles, craft.orbit, craft.ghost, craft.merge = {}, nil, nil, nil, nil
	craft.expiring = false
	if craft.stage > 0 then rebuild_stage_entity(player, craft) end
	rebuild_loose_pigments(player, craft, persisted and persisted.loose_count or 0)
	craft.dirty = false
end

function M.tick_pickup_bounce(pickup)
	local d = pickup:GetData()
	local age = d.Thoth_cd14_Art_land_bounce
	if age == nil then return end
	age = age + 1
	d.Thoth_cd14_Art_land_bounce = age
	local sprite = pickup:GetSprite()
	if age == 1 then sprite.Scale = Vector(1.14, 0.82)
	elseif age == 2 then sprite.Scale = Vector(0.94, 1.10)
	elseif age == 3 then sprite.Scale = Vector(1.03, 0.97)
	else sprite.Scale = Vector(1, 1) d.Thoth_cd14_Art_land_bounce = nil end
end

return M

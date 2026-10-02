local P = require("Qing_Remaster_scripts.bosses.glaze.glaze_placeholder")
local G = require("Qing_Remaster_scripts.bosses.glaze.glaze_geometry")
local Mirror = require("Qing_Remaster_scripts.bosses.glaze.glaze_mirror")
local Shard = require("Qing_Remaster_scripts.bosses.glaze.glaze_shard")
local Attacks = require("Qing_Remaster_scripts.bosses.glaze.glaze_attacks")
local Story = require("Qing_Remaster_scripts.bosses.glaze.glaze_story_adapter")
local Palace = require("Qing_Remaster_scripts.bosses.glaze.glaze_palace")
local Assets = require("Qing_Remaster_scripts.bosses.glaze.glaze_visual_assets")
local M = {active = {}, key = "Boss_Glaze_v1"}

local function exists(e) return e and e:Exists() end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

function M.clear_transition_visuals(ctx)
	ctx.transition_shards = {}
end

function M.clear_objects(ctx)
	for _, shot in pairs(ctx.projectiles) do if exists(shot.entity) then shot.entity:Remove() end end
	P.clear(ctx)
	ctx.projectiles, ctx.mirrors, ctx.shards, ctx.echoes, ctx.field = {}, {}, {}, {}, nil
end

function M.cancel(ctx)
	local attack = Attacks.by_id[ctx.attack]
	if attack and attack.cleanup then attack.cleanup(ctx) end
	ctx.attack, ctx.work, ctx.attack_frame = nil, {}, 0
	ctx.boss.Velocity = Vector.Zero
end

function M.cleanup(ctx)
	M.cancel(ctx)
	M.clear_objects(ctx)
	M.clear_transition_visuals(ctx)
	Palace.cleanup(ctx)
	M.active[ctx.hash] = nil
	if exists(ctx.boss) then ctx.boss:GetData()[M.key] = nil end
end

function M.cleanup_all()
	local g = require("Qing_Remaster_scripts.core.globals")
	-- Exit teardown: drop Lua contexts only; do not Remove engine entities.
	if not g.is_gameplay_world_active() then
		M.active = {}
		return
	end
	for _, ctx in pairs(M.active) do M.cleanup(ctx) end
end

function M.init(boss)
	local hash = GetPtrHash(boss)
	local old = M.active[hash]
	if old then old.boss = boss; return old end
	local room = Game():GetRoom()
	local ctx = {boss = boss, hash = hash, room = room, center = room:GetCenterPos(),
		phase = 1, state = "appear", attack = nil, attack_frame = 0, phase_frame = 0,
		transition = nil, final_state = false, did_transition_1 = false, did_transition_2 = false,
		clock = 0, recovery = 30, serial = 0, last_shatter = -90, crown_visible = true,
		objects = {}, warnings = {}, mirrors = {}, shards = {}, echoes = {}, projectiles = {},
		work = {}, cooldowns = {}, remnant_positions = {}, transition_shards = {},
		debug_freeze = false, debug_step_frames = 0,
		rng = boss:GetDropRNG()}
	for i = 1, 5 do ctx.remnant_positions[i] = room:GetClampedPosition(ctx.center + Vector(180, 0):Rotated(i * 72), 45) end
	Palace.create(ctx)
	M.active[hash] = ctx
	boss:GetData()[M.key] = ctx
	boss.PositionOffset = Vector(0, -25)
	boss:AddEntityFlags(EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
	return ctx
end

local function spawn_transition_shard(ctx, pos, velocity, index)
	local info = Assets.crown_shard(index)
	local spr = Sprite()
	spr:Load(info.anm2, true)
	spr:Play(info.animation, true)
	ctx.transition_shards[#ctx.transition_shards + 1] = {
		sprite = spr,
		position = Vector(pos.X, pos.Y),
		velocity = velocity,
		rotation = index * 40,
		rotation_speed = 4 + index,
		age = 0,
		lifetime = 90,
	}
end

local function tick_transition_shards(ctx)
	for i = #ctx.transition_shards, 1, -1 do
		local s = ctx.transition_shards[i]
		s.age = s.age + 1
		s.position = s.position + s.velocity
		s.velocity = s.velocity * 0.96
		s.rotation = s.rotation + s.rotation_speed
		if s.sprite then s.sprite:Update() end
		if s.age >= s.lifetime then table.remove(ctx.transition_shards, i) end
	end
end

function M.render_transition_shards(ctx)
	if not ctx.transition_shards then return end
	local scroll = Game():GetRoom():GetRenderScrollOffset()
	for _, s in ipairs(ctx.transition_shards) do
		if s.sprite then
			local screen = Isaac.WorldToScreen(s.position) - scroll
			local fade = 1 - (s.age / math.max(1, s.lifetime))
			s.sprite.Rotation = s.rotation
			s.sprite.Color = Color(1, 1, 1, fade)
			s.sprite:Render(screen, Vector.Zero, Vector.Zero)
		end
	end
end

function M.transition(ctx, index)
	M.cancel(ctx); M.clear_objects(ctx); M.clear_transition_visuals(ctx)
	ctx.state, ctx.transition, ctx.transition_frame = "transition", index, 0
	ctx["did_transition_" .. index] = true
	ctx.crown_visible = index == 1
	ctx.crown_offset = Vector.Zero
	ctx.boss:GetSprite():Play("Idle", true)
	if not ctx.palace then Palace.create(ctx) end
	if index == 1 then
		Palace.reset(ctx)
	elseif index == 2 then
		if ctx.palace.build < 0.85 then
			Palace.set_build(ctx, 1)
			Palace.set_stability(ctx, 1)
		end
		for i, pos in ipairs(ctx.remnant_positions) do
			Mirror.spawn(ctx, pos, i % 2 == 0 and "VERTICAL" or "HORIZONTAL", 160, "MIRROR NODE")
		end
	end
end

local function transition_tick(ctx)
	ctx.transition_frame = ctx.transition_frame + 1
	local f, c = ctx.transition_frame, ctx.center
	ctx.boss.Velocity = (c - ctx.boss.Position) * .12
	tick_transition_shards(ctx)
	Palace.update(ctx)
	if ctx.transition == 1 then
		-- A stop / B crown highlight / C-D break / E shards fly / F palace build / G-H form / I P2
		if f >= 30 and f < 70 then
			ctx.crown_offset = Vector(14, 24) * math.min(1, (f - 30) / 25)
		end
		if f == 70 then
			ctx.crown_visible = false
			SFXManager():Play(SoundEffect.SOUND_GLASS_BREAK, 1, 0, false, 1)
			local origin = ctx.boss.Position + Vector(0, -40)
			for i = 1, 5 do
				local dir = Vector(0, 1):Rotated(i * 72)
				spawn_transition_shard(ctx, origin, dir * 6.5, i)
			end
		end
		if f == 80 then
			Palace.begin_build(ctx)
		end
		if f == 120 then
			for i, pos in ipairs(ctx.remnant_positions) do
				Mirror.spawn(ctx, pos, i % 2 == 0 and "VERTICAL" or "HORIZONTAL", 1800, "MIRROR NODE")
			end
		end
		-- Enter P2 once palace is readable; do not require exact 1.000.
		if f >= 150 and (not ctx.palace or ctx.palace.build >= 0.85) then
			if ctx.palace and ctx.palace.build < 1 then Palace.set_build(ctx, 1) end
			ctx.phase = 2; ctx.transition = nil; ctx.state = "recovery"; ctx.recovery = 45; ctx.phase_frame = 0
			M.clear_transition_visuals(ctx)
		end
	else
		if f == 30 then
			ctx.work.materials = {}
			for i, info in ipairs(Story.get_chapter1_material_visuals()) do
				ctx.work.materials[i] = P.spawn(ctx, "MATERIAL", c, {lifetime = 160, label = info.label})
			end
			P.spawn(ctx, "ALCHEMY", c, {lifetime = 150})
			Palace.set_palette(ctx, "broken")
		end
		if f >= 30 and f < 150 then
			for i, obj in ipairs(ctx.work.materials) do P.move(obj, c + Vector(80, 0):Rotated(i * 72 + (f - 30) * (f - 30) * .04)) end
		end
		if f == 90 then
			Palace.begin_collapse(ctx)
		end
		if f == 130 then
			for _, obj in pairs(ctx.objects) do if obj.kind ~= "MATERIAL" then P.label(obj, "CRACK") end end
		end
		if f == 150 then
			M.clear_objects(ctx)
			SFXManager():Play(SoundEffect.SOUND_MIRROR_BREAK, 1, 0, false, .8)
			Game():ShakeScreen(15)
			for _, pos in ipairs(ctx.remnant_positions) do Shard.spawn(ctx, pos, G.direction(pos, c), 900, "GLAZE SHARD") end
		end
		if f >= 210 then
			if ctx.palace then Palace.set_stability(ctx, 0) end
			ctx.phase = 3; ctx.transition = nil; ctx.state = "recovery"; ctx.recovery = 45; ctx.phase_frame = 0
		end
	end
end

function M.damage(ctx, amount)
	if ctx.state == "appear" or ctx.transition then return false end
	local ratio = not ctx.did_transition_1 and .65 or (not ctx.did_transition_2 and .32 or nil)
	if ratio then
		local allowed = math.max(0, ctx.boss.HitPoints - ctx.boss.MaxHitPoints * ratio)
		if amount >= allowed then
			ctx.pending_transition = ctx.did_transition_1 and 2 or 1
			if allowed == 0 then return false end
			return {Damage = allowed}
		end
	end
	if ctx.attack == "p3.shatter_crown" and not ctx.work.broken then
		-- At most two ticks per logic frame and thirty per build; earliest break remains 90f.
		local frame = Game():GetFrameCount()
		if ctx.damage_frame ~= frame then ctx.damage_frame = frame; ctx.damage_ticks = 0 end
		local extra = math.min(2 - ctx.damage_ticks, amount / math.max(1, ctx.boss.MaxHitPoints * .005))
		extra = math.max(0, extra)
		ctx.damage_ticks = ctx.damage_ticks + extra
		ctx.work.damage_progress = math.min(30, ctx.work.damage_progress + extra)
	end
end

local function tick_projectiles(ctx)
	for hash, shot in pairs(ctx.projectiles) do
		shot.lifetime = shot.lifetime - 1
		local alive = exists(shot.entity) and not shot.entity:IsDead()
		if alive and shot.lifetime > 0 and ctx.room:IsPositionInRoom(shot.entity.Position, -15) then Mirror.process(ctx, shot)
		else
			if shot.echo then
				ctx.echoes[#ctx.echoes + 1] = {pos = G.mirror_position(shot.origin, ctx.center),
					velocity = G.reflect_velocity(shot.velocity, "VERTICAL"), due = ctx.clock + 45}
			end
			if alive then shot.entity:Remove() end
			ctx.projectiles[hash] = nil
		end
	end
	for i = #ctx.echoes, 1, -1 do
		local echo = ctx.echoes[i]
		if ctx.clock == echo.due - 15 then
			P.spawn(ctx, "ECHO", echo.pos, {lifetime = 16})
			P.line(ctx, echo.pos, echo.pos + echo.velocity:Resized(600), 15, "ECHO")
		end
		if ctx.clock >= echo.due then Shard.fire(ctx, echo.pos, echo.velocity, {no_mirror = true}); table.remove(ctx.echoes, i) end
	end
end

function M.play_attack(ctx, id)
	local attack = Attacks.by_id[id]
	if not attack then return false, "Unknown attack: " .. tostring(id) end
	M.cancel(ctx); M.clear_objects(ctx)
	ctx.transition, ctx.pending_transition = nil, nil
	ctx.attack, ctx.state, ctx.move_frame = id, "move", 0
	ctx.destination = G.position(ctx.room, attack.preferred_position)
	return true
end

local function schedule(ctx)
	local pool = Attacks.pools[ctx.final_state and "finale" or ctx.phase]
	local choices, weight = {}, 0
	for _, a in ipairs(pool) do
		local allowed = a.id ~= ctx.previous_attack and (ctx.cooldowns[a.id] or 0) <= ctx.clock
		allowed = allowed and ctx.phase_frame >= a.min_phase_time
		if ctx.previous_tags and ctx.previous_tags.signature then allowed = allowed and a.tags.basic == true end
		if ctx.previous_tags and ctx.previous_tags.high_pressure then allowed = allowed and not a.tags.high_pressure end
		if allowed then choices[#choices + 1] = a; weight = weight + a.weight end
	end
	if #choices == 0 then ctx.recovery = 15; return end
	local roll = ctx.rng:RandomFloat() * weight
	local chosen = choices[#choices]
	for _, a in ipairs(choices) do roll = roll - a.weight; if roll <= 0 then chosen = a; break end end
	ctx.attack, ctx.state, ctx.move_frame = chosen.id, "move", 0
	ctx.work, ctx.attack_frame = {}, 0
	ctx.destination = G.position(ctx.room, chosen.preferred_position)
	-- No previous field may overlap a new attack, but palace anchors/remnants survive.
	if ctx.field then P.remove(ctx, ctx.field); ctx.field = nil; ctx.warnings = {} end
end

function M.tick(ctx)
	if not exists(ctx.boss) or ctx.boss:IsDead() then M.cleanup(ctx); return end
	-- Freeze only Boss simulation. Render / ImGui keep running.
	if ctx.debug_freeze then
		if (ctx.debug_step_frames or 0) <= 0 then return end
		ctx.debug_step_frames = ctx.debug_step_frames - 1
	end
	ctx.clock, ctx.phase_frame = ctx.clock + 1, ctx.phase_frame + 1
	P.tick(ctx); Mirror.tick(ctx); tick_projectiles(ctx)
	for id in pairs(ctx.shards) do if not ctx.objects[id] then ctx.shards[id] = nil end end
	if ctx.transition then transition_tick(ctx); return end
	Palace.update(ctx)
	local ratio = ctx.boss.HitPoints / math.max(1, ctx.boss.MaxHitPoints)
	if ctx.pending_transition or (not ctx.did_transition_1 and ratio <= .65) or (ctx.did_transition_1 and not ctx.did_transition_2 and ratio <= .32) then
		local index = ctx.pending_transition or (ctx.did_transition_1 and 2 or 1)
		ctx.pending_transition = nil; M.transition(ctx, index); return
	end
	if ctx.phase == 3 and ratio <= .1 and not ctx.final_state then
		M.cancel(ctx); M.clear_objects(ctx)
		ctx.final_state, ctx.state, ctx.recovery = true, "recovery", 30
		ctx.boss.PositionOffset = Vector(0, -8)
	end
	if ctx.state == "appear" then
		if ctx.clock >= 30 then ctx.state = "recovery" end
	elseif ctx.state == "recovery" then
		ctx.boss.Velocity = ctx.boss.Velocity * .7
		ctx.recovery = ctx.recovery - 1
		if ctx.recovery <= 0 then schedule(ctx) end
	elseif ctx.state == "move" then
		ctx.move_frame = ctx.move_frame + 1
		local delta = ctx.destination - ctx.boss.Position
		ctx.boss.Velocity = delta:Length() > 7 and delta:Resized(7) or delta * .3
		if delta:Length() < 8 or ctx.move_frame >= 90 then
			ctx.boss.Velocity = Vector.Zero
			ctx.state = "attack"
			ctx.boss:GetSprite():Play("Attack1", true)
			Attacks.by_id[ctx.attack].setup(ctx)
		end
	elseif ctx.state == "attack" then
		ctx.attack_frame = ctx.attack_frame + 1
		local a = Attacks.by_id[ctx.attack]
		a.update(ctx, ctx.attack_frame)
		if ctx.attack_frame >= a.duration then
			ctx.previous_attack, ctx.previous_tags = a.id, a.tags
			ctx.cooldowns[a.id] = ctx.clock + a.cooldown
			M.cancel(ctx)
			ctx.state, ctx.recovery = "recovery", a.recovery
		end
	end
end

function M.tick_all()
	for _, ctx in pairs(M.active) do M.tick(ctx) end
end

function M.inspect(ctx)
	local hp_ratio = ctx.boss.HitPoints / math.max(1, ctx.boss.MaxHitPoints)
	return {
		alive = true,
		phase = ctx.phase,
		state = ctx.state,
		attack = ctx.attack,
		current_attack = ctx.attack,
		attack_frame = ctx.attack_frame,
		hp = hp_ratio,
		hp_ratio = hp_ratio,
		mirrors = count(ctx.mirrors),
		shards = count(ctx.shards),
		fields = ctx.field and 1 or 0,
		echoes = #ctx.echoes,
		transition = ctx.transition,
		transition_frame = ctx.transition_frame,
		finale = ctx.final_state,
		final_state = ctx.final_state,
		crown_visible = ctx.crown_visible == true,
		frozen = ctx.debug_freeze == true,
		practice = ctx.practice == true,
		story_owned = ctx.story_owned == true,
		palace = Palace.inspect(ctx),
		objects = {
			mirrors = count(ctx.mirrors),
			shards = count(ctx.shards),
			fields = ctx.field and 1 or 0,
			echoes = #ctx.echoes,
		},
	}
end

return M

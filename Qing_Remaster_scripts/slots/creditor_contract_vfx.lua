local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local slot_offer_lift = require("Qing_Remaster_scripts.slots.slot_offer_lift")

local item = {
	particles = {},
	claims = {}, -- GetPtrHash -> claim state
	_last_sound_frame = -99,
}

local GAIN_KIND = {coin = "coin", key = "key", bomb = "bomb", heart = "soul"}
local ARRIVE_SOUND = {
	coin = SoundEffect.SOUND_PENNYPICKUP,
	key = SoundEffect.SOUND_KEYPICKUP,
	bomb = SoundEffect.SOUND_THUMBSUP,
	heart = SoundEffect.SOUND_HEARTOUT,
	soul = SoundEffect.SOUND_HEARTOUT,
}

local START_DELAY = 6
local SPAWN_STAGGER = 2
local MAX_VISIBLE = 12
local SCATTER_FRAMES = 10
local CRUISE_FRAMES = 34
local FLASH_FRAMES = 7
local HOVER_FRAMES = 16
local SCATTER_RADIUS_MIN = 18
local SCATTER_RADIUS_MAX = 34
local CRUISE_ARC = 32
local CRUISE_SCALE = 0.88 -- 相对 HUD icon 基准 scale 的飞行缩小倍率
local ARRIVE_SCALE = 1.28 -- 到达时相对基准 scale 的放大

local CLAIM_RESOLVE_FRAME = 7

local CLAIM_DATA_KEY = "creditor_debt_claim"

local function clamp01(t)
	return math.max(0, math.min(1, t))
end

local function ease_out_cubic(t)
	t = clamp01(t)
	return 1 - (1 - t) ^ 3
end

local function ease_out_quint(t)
	t = clamp01(t)
	return 1 - (1 - t) ^ 5
end

local function icon_center(player, kind, spawn_index)
	return slot_offer_lift.get_pickup_hud_screen_pos(player, GAIN_KIND[kind] or kind, spawn_index or 0)
end

local function hud_fly_scale(kind)
	return slot_offer_lift.get_creditor_hud_fly_scale(kind)
end

local function spawn_sound(kind)
	local frame = Game():GetFrameCount()
	if frame - item._last_sound_frame < 2 then return end
	item._last_sound_frame = frame
	local sid = ARRIVE_SOUND[GAIN_KIND[kind] or kind] or SoundEffect.SOUND_PENNYPICKUP
	sound_tracker.PlayStackedSound(sid, 0.35, 1.05, false, 0, 2)
end

local function apply_particle_look(p)
	local sprite = p.sprite
	if not sprite then return end
	local base_a = p.base_alpha or 1
	local bright = p.bright or 0
	local scale = (p.base_scale or 1) * (p.scale_mul or 1)
	sprite.Scale = Vector(scale, scale)
	sprite.Color = Color(1, 1, 1, base_a, bright * 0.55, bright * 0.5, bright * 0.35)
end

function item.spawn_soul_pickup(world_pos, vel)
	local room = Game():GetRoom()
	local pos = world_pos or Vector(0, 0)
	if room and room.FindFreePickupSpawnPosition then
		pos = room:FindFreePickupSpawnPosition(pos, 24, true)
	end
	vel = vel or Vector((math.random() - 0.5) * 2.5, 1.5 + math.random() * 1.5)
	local pickup = Isaac.Spawn(
		EntityType.ENTITY_PICKUP,
		PickupVariant.PICKUP_HEART,
		HeartSubType.HEART_SOUL,
		pos,
		vel,
		nil
	)
	if pickup then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_HEARTOUT, 0.55, 1, false, 0, 1)
	end
	return pickup
end

local function make_particle(player, ent, kind, spawn_index, spawn_total, on_arrive, opts)
	opts = opts or {}
	local world = ent.Position + Vector((math.random() - 0.5) * 10, -14 - math.random() * 6)
	local start = Isaac.WorldToScreen(world) + ui.GetHUDRenderOffset()
	local n = math.max(1, spawn_total or 1)
	local drop_floor = opts.drop_floor == true
	local final = icon_center(player, kind, spawn_index)
	local angle = (spawn_index / n) * math.pi * 2 + (math.random() - 0.5) * 0.35
	local radius = SCATTER_RADIUS_MIN + math.random() * (SCATTER_RADIUS_MAX - SCATTER_RADIUS_MIN)
	local scatter = start + Vector(math.cos(angle) * radius, math.sin(angle) * radius * 0.72 - 10)
	local mid = (scatter + final) * 0.5 + Vector(0, -CRUISE_ARC)
	local base_scale = hud_fly_scale(kind)
	local sprite = slot_offer_lift.make_creditor_hud_fly_sprite(kind, base_scale)
	local particle = {
		player = player,
		role = "gain",
		kind = kind,
		sprite = sprite,
		pos = Vector(start.X, start.Y),
		phase = "wait",
		frame = 0,
		wait_until = Game():GetFrameCount() + START_DELAY + spawn_index * SPAWN_STAGGER,
		fly_t = 0,
		start_pos = Vector(start.X, start.Y),
		scatter_pos = scatter,
		target = final,
		cruise_mid = mid,
		base_alpha = 1,
		base_scale = base_scale,
		bright = 0,
		scale_mul = 1,
		on_arrive = on_arrive,
		drop_floor = drop_floor,
		world_origin = Vector(ent.Position.X, ent.Position.Y),
		spawn_index = spawn_index,
		applied = false,
	}
	apply_particle_look(particle)
	table.insert(item.particles, particle)
end

local function apply_arrive(p)
	if p.applied then return end
	p.applied = true
	if p.drop_floor then
		local off = Vector((math.random() - 0.5) * 18, (math.random() - 0.5) * 10)
		item.spawn_soul_pickup(p.world_origin + off)
	else
		if p.on_arrive then p.on_arrive() end
		spawn_sound(p.kind)
	end
end

local function finish_particle(p)
	p.phase = "done"
	apply_arrive(p)
end

local function tick_particle(p)
	if p.phase == "wait" then
		if Game():GetFrameCount() < p.wait_until then return end
		p.phase = "scatter"
		p.frame = 0
	end
	if p.phase == "scatter" then
		p.frame = p.frame + 1
		local t = ease_out_cubic(p.frame / SCATTER_FRAMES)
		p.pos = p.start_pos + (p.scatter_pos - p.start_pos) * t
		p.bright = 0
		-- 散开阶段开始略缩
		p.scale_mul = 1 - t * (1 - CRUISE_SCALE) * 0.35
		apply_particle_look(p)
		if p.frame >= SCATTER_FRAMES then
			if p.drop_floor then
				p.phase = "hover"
				p.fly_t = 0
			else
				p.phase = "cruise"
				p.fly_t = 0
			end
		end
		return
	end
	if p.phase == "hover" then
		p.fly_t = p.fly_t + 1
		local bob = math.sin(p.fly_t * 0.35) * 1.4
		p.pos = p.scatter_pos + Vector(0, bob)
		p.bright = 0.1
		p.scale_mul = CRUISE_SCALE
		apply_particle_look(p)
		if p.fly_t >= HOVER_FRAMES then
			p.phase = "flash"
			p.fly_t = 0
			apply_arrive(p)
		end
		return
	end
	if p.phase == "cruise" then
		p.fly_t = p.fly_t + 1
		local t_raw = clamp01(p.fly_t / CRUISE_FRAMES)
		local t = ease_out_quint(t_raw)
		p.pos = auxi.Bezier4(p.scatter_pos, p.cruise_mid, p.cruise_mid, p.target, t)
		p.bright = 0.15 + t_raw * 0.45
		local scatter_scale = 1 - 0.2 * (1 - CRUISE_SCALE)
		p.scale_mul = scatter_scale + (CRUISE_SCALE - scatter_scale) * t_raw
		apply_particle_look(p)
		if p.fly_t >= CRUISE_FRAMES then
			p.pos = Vector(p.target.X, p.target.Y)
			p.phase = "flash"
			p.fly_t = 0
			p.scale_mul = ARRIVE_SCALE
			apply_arrive(p)
		end
		return
	end
	if p.phase == "flash" then
		p.fly_t = p.fly_t + 1
		local t = clamp01(p.fly_t / FLASH_FRAMES)
		p.bright = 1
		p.scale_mul = ARRIVE_SCALE * (1 + 0.08 * (1 - t))
		p.base_alpha = 1 - ease_out_cubic(t)
		apply_particle_look(p)
		if p.fly_t >= FLASH_FRAMES then
			finish_particle(p)
		end
	end
end

local function spawn_burst(player, ent, kind, total, on_unit, opts)
	if total <= 0 then return end
	local visible, unit = total, 1
	if total > MAX_VISIBLE then
		visible = MAX_VISIBLE
		unit = math.ceil(total / MAX_VISIBLE)
	end
	for i = 0, visible - 1 do
		make_particle(player, ent, kind, i, visible, function()
			for _ = 1, unit do
				if on_unit then on_unit() end
			end
		end, opts)
	end
end

local function spawn_white_smoke(pos)
	local poof = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, pos, Vector(0, 0), nil)
	if poof then
		poof = poof:ToEffect() or poof
		poof:SetColor(Color(1, 1, 1, 1, 0.85, 0.85, 0.85), 30, 1, false, false)
		local s = poof:GetSprite()
		if s then
			s.Color = Color(1, 1, 1, 1, 0.7, 0.7, 0.7)
			s.Scale = Vector(1.15, 1.15)
		end
	end
	local dust = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.DUST_CLOUD, 0, pos + Vector(0, -4), Vector(0, -0.4), nil)
	if dust then
		dust = dust:ToEffect() or dust
		dust:SetColor(Color(1, 1, 1, 0.85, 0.6, 0.6, 0.6), 20, 1, false, false)
		dust.SpriteScale = Vector(0.85, 0.85)
		local life = 18
		if dust.LifeSpan ~= nil then dust.LifeSpan = life end
		if dust.Timeout ~= nil then dust.Timeout = life end
	end
end

local function spawn_creditor_claim_pillar(pos)
	-- subtype 0 = 即时落下；2 为白马前摇版，勿用。
	local beam = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CRACK_THE_SKY, 0, pos, Vector(0, 0), nil)
	if not beam then return end
	beam = beam:ToEffect() or beam
	beam.CollisionDamage = 0
	local col = Color(0.12, 0.12, 0.16, 1, 0, 0, 0.65)
	if col.SetColorize then col:SetColorize(0.04, 0.04, 0.06, 1) end
	beam:SetColor(col, -1, 0, false, false)
	local s = beam:GetSprite()
	if s then
		s.Color = col
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_HOLY, 0.55, 0.92, false, 0, 1)
end

function item.is_claiming_pickup(ent)
	if not ent or not ent:Exists() then return false end
	if item.claims[GetPtrHash(ent)] then return true end
	local data = ent:GetData()
	return data and data[CLAIM_DATA_KEY] == true
end

local function mark_claim_pickup(ent)
	if not ent then return end
	ent:GetData()[CLAIM_DATA_KEY] = true
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	ent.Velocity = Vector(0, 0)
	local pickup = ent.ToPickup and ent:ToPickup()
	if pickup then
		pickup.Touched = true
	end
end

--- 掉落物被债务收走：短暂停留 → 黑圣光柱 + 白烟 → 移除。
function item.begin_debt_claim(ent, remaining, kind)
	if not ent or not ent:Exists() then return end
	local key = GetPtrHash(ent)
	if item.claims[key] then return end
	mark_claim_pickup(ent)
	item.claims[key] = {
		ent = ent,
		kind = kind or "coin",
		remaining = remaining or 0,
		frame = 0,
		done = false,
		world_pos = Vector(ent.Position.X, ent.Position.Y),
	}
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BIRD_FLAP, 0.45, 1.2, false, 0, 1)
end

local function resolve_claim_ent(hash)
	if not hash then return nil end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, false, false)) do
		if ent and ent:Exists() and GetPtrHash(ent) == hash then
			return ent
		end
	end
	return nil
end

local function tick_claim(key, c)
	local ent = resolve_claim_ent(key)
	if not ent then
		item.claims[key] = nil
		return
	end
	c.ent = ent
	c.frame = c.frame + 1
	c.world_pos = Vector(ent.Position.X, ent.Position.Y)
	mark_claim_pickup(ent)

	if c.frame < CLAIM_RESOLVE_FRAME then
		return
	end

	if not c.done then
		c.done = true
		local pos = Vector(ent.Position.X, ent.Position.Y)
		spawn_creditor_claim_pillar(pos)
		spawn_white_smoke(pos)
		ent.Visible = false
		ent:Remove()
		item.claims[key] = nil
	end
end

function item.queue_contract(player, ent, opt, gain_apply)
	if not player or not ent or not opt then return end
	local gain_units = ({
		coin = 10,
		key = 3,
		bomb = 3,
		heart = 2,
	})[opt.id] or 1
	local drop_floor = false
	if opt.id == "heart" and player.CanPickSoulHearts and not player:CanPickSoulHearts() then
		drop_floor = true
	end
	spawn_burst(player, ent, opt.id, gain_units, gain_apply, {
		drop_floor = drop_floor,
	})
end

function item.tick()
	for i = #item.particles, 1, -1 do
		local p = item.particles[i]
		if not p.player or not p.player:Exists() then
			table.remove(item.particles, i)
		else
			tick_particle(p)
			if p.phase == "done" then table.remove(item.particles, i) end
		end
	end
	for key, c in pairs(item.claims) do
		tick_claim(key, c)
	end
end

function item.render()
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	for _, p in ipairs(item.particles) do
		if p.sprite and p.phase ~= "wait" and p.phase ~= "done" then
			local scale = (p.base_scale or 1) * (p.scale_mul or 1)
			-- creditor_hud_fly.anm2：p.pos 即 pivot 落点；禁止 VisualCenterToRenderPos（会把框中心当目标并把 pivot 顶上去）
			p.sprite.Scale = Vector(scale, scale)
			p.sprite:Render(p.pos, Vector(0, 0), Vector(0, 0))
		end
	end
end

function item.render_hud_overlay()
	item.render()
end

function item.active()
	return #item.particles > 0 or next(item.claims) ~= nil
end

return item

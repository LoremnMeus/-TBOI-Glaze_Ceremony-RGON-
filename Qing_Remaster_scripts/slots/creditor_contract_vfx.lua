local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local slot_offer_lift = require("Qing_Remaster_scripts.slots.slot_offer_lift")

local item = {
	particles = {},
	pulse = {},
	_debt_bag_fn = nil,
	_last_sound_frame = -99,
}

local PENNY = "gfx/005.021_penny.anm2"
local KEY_ANM = "gfx/005.031_key.anm2"
local BOMB_ANM = "gfx/005.041_bomb.anm2"
local HEART_ANM = "gfx/005.011_heart.anm2"
local SOUL_ANM = "gfx/005.013_heart (soul).anm2"

local ROW_ORDER = {"coin", "key", "bomb", "heart"}
local ROW_ANM2 = {coin = PENNY, key = KEY_ANM, bomb = BOMB_ANM, heart = HEART_ANM}
local GAIN_KIND = {coin = "coin", key = "key", bomb = "bomb", heart = "soul"}
local ARRIVE_SOUND = {
	coin = SoundEffect.SOUND_PENNYPICKUP,
	key = SoundEffect.SOUND_KEYPICKUP,
	bomb = SoundEffect.SOUND_THUMBSUP,
	heart = SoundEffect.SOUND_HEARTOUT,
	soul = SoundEffect.SOUND_HEARTOUT,
}

local BURST_FRAMES = 7
local FLY_FRAMES = 26
local START_DELAY = 8
local SPAWN_STAGGER = 2
local MAX_VISIBLE = 12
local FLY_SCALE = 0.58

local function ease_out_cubic(t)
	t = math.max(0, math.min(1, t))
	return 1 - (1 - t) ^ 3
end

local function debt_hud_origin()
	return ui.GetScreenTopRight(0) + Vector(-92, 16) + ui.GetHUDRenderOffset()
end

local function debt_row_index(kind)
	for i, row in ipairs(ROW_ORDER) do
		if row == kind then return i - 1 end
	end
	return 0
end

local function debt_row_screen_pos(kind)
	local row = debt_row_index(kind)
	return debt_hud_origin() + Vector(0, row * 17)
end

local function fly_target(player, role, kind)
	if role == "debt" then
		return debt_row_screen_pos(kind) + Vector(10, 8)
	end
	return slot_offer_lift.get_pickup_hud_screen_pos(player, GAIN_KIND[kind] or kind) + Vector(6, 8)
end

local function spawn_sound(role, kind)
	local frame = Game():GetFrameCount()
	if frame - item._last_sound_frame < 2 then return end
	item._last_sound_frame = frame
	local sid = ARRIVE_SOUND[GAIN_KIND[kind] or kind] or SoundEffect.SOUND_PENNYPICKUP
	sound_tracker.PlayStackedSound(sid, 0.35, 1, false, 0, 1.05)
end

local function make_particle(player, ent, role, kind, anm2, spawn_index, on_arrive)
	local world = ent.Position + Vector((math.random() - 0.5) * 18, -18 - math.random() * 10)
	local start = Isaac.WorldToScreen(world) + ui.GetHUDRenderOffset()
	local angle = math.random() * math.pi * 2
	local speed = 2.2 + math.random() * 3.2
	local sprite = slot_offer_lift.make_pickup_fly_sprite(anm2, FLY_SCALE)
	local alpha = role == "debt" and 0.72 or 1
	sprite.Color = Color(1, 1, 1, alpha, 0, 0, 0)
	if role == "debt" then
		sprite.Color = Color(1, 0.55, 0.5, alpha, 0, 0, 0)
	end
	table.insert(item.particles, {
		player = player,
		role = role,
		kind = kind,
		sprite = sprite,
		pos = start,
		vel = Vector(math.cos(angle) * speed, math.sin(angle) * speed - 1.8),
		phase = "wait",
		frame = 0,
		wait_until = Game():GetFrameCount() + START_DELAY + spawn_index * SPAWN_STAGGER,
		bezier = nil,
		fly_t = 0,
		target = fly_target(player, role, kind),
		on_arrive = on_arrive,
	})
end

local function begin_fly(p)
	local target = p.target
	local p0 = p.pos
	local p1 = p.pos + p.vel * 4
	local mid = (p0 + target) * 0.5 + Vector((math.random() - 0.5) * 36, -48 - math.random() * 28)
	p.bezier = {p0, p1, mid, target}
	p.phase = "fly"
	p.fly_t = 0
	p.vel = Vector(0, 0)
end

local function tick_particle(p)
	if p.phase == "wait" then
		if Game():GetFrameCount() < p.wait_until then return end
		p.phase = "burst"
		p.frame = 0
	end
	if p.phase == "burst" then
		p.frame = p.frame + 1
		p.pos = p.pos + p.vel
		p.vel = p.vel * 0.86 + Vector(0, -0.08)
		if p.frame >= BURST_FRAMES then begin_fly(p) end
		return
	end
	if p.phase == "fly" then
		p.fly_t = p.fly_t + 1
		local t = p.fly_t / FLY_FRAMES
		if t >= 1 then
			p.phase = "done"
			if p.on_arrive then p.on_arrive() end
			item.pulse[p.role.."_"..p.kind] = Game():GetFrameCount()
			spawn_sound(p.role, p.kind)
			return
		end
		p.pos = auxi.Bezier4(p.bezier[1], p.bezier[2], p.bezier[3], p.bezier[4], ease_out_cubic(t))
	end
end

local function spawn_burst(player, ent, role, kind, anm2, total, on_unit)
	if total <= 0 then return end
	local visible, unit = total, 1
	if total > MAX_VISIBLE then
		visible = MAX_VISIBLE
		unit = math.ceil(total / MAX_VISIBLE)
	end
	for i = 0, visible - 1 do
		make_particle(player, ent, role, kind, anm2, i, function()
			for _ = 1, unit do
				if on_unit then on_unit() end
			end
		end)
	end
end

function item.setup(debt_bag_fn)
	item._debt_bag_fn = debt_bag_fn
end

function item.queue_contract(player, ent, opt, gain_apply, debt_apply)
	if not player or not ent or not opt then return end
	local gain_anm2 = opt.anm2
	local debt_anm2 = opt.debt_key == "heart" and HEART_ANM or gain_anm2
	local gain_units = ({
		coin = 10,
		key = 3,
		bomb = 3,
		heart = 2,
	})[opt.id] or 1
	local debt_units = opt.debt or 0
	spawn_burst(player, ent, "gain", opt.id, gain_anm2, gain_units, gain_apply)
	spawn_burst(player, ent, "debt", opt.debt_key or opt.id, debt_anm2, debt_units, debt_apply)
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
end

local function pulse_scale(key)
	local t = item.pulse[key]
	if not t then return 1 end
	local age = Game():GetFrameCount() - t
	if age > 12 then
		item.pulse[key] = nil
		return 1
	end
	return 1 + 0.28 * (1 - age / 12)
end

local function debt_total(bag)
	local sum = 0
	for _, kind in ipairs(ROW_ORDER) do
		sum = sum + (bag[kind] or 0)
	end
	return sum
end

function item.render_debt_hud()
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local bag_fn = item._debt_bag_fn
	if not bag_fn then return end
	local bag = bag_fn()
	if not bag or debt_total(bag) <= 0 then return end
	local origin = debt_hud_origin()
	for _, kind in ipairs(ROW_ORDER) do
		local val = bag[kind] or 0
		if val > 0 then
			local row = debt_row_index(kind)
			local pos = origin + Vector(0, row * 17)
			slot_offer_lift.draw_pickup_hud_icon(ROW_ANM2[kind], pos, 0.85, Color(1, 0.72, 0.68, 0.9, 0, 0, 0))
			local scale = pulse_scale("debt_"..kind)
			gui.draw_ch(pos + Vector(24, 0), tostring(val), scale, scale, KColor(1, 0.45, 0.4, 1), true)
		end
	end
end

function item.render()
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	for _, p in ipairs(item.particles) do
		if p.sprite and p.phase ~= "wait" and p.phase ~= "done" then
			p.sprite:Render(p.pos, Vector(0, 0), Vector(0, 0))
		end
	end
	item.render_debt_hud()
end

function item.active()
	return #item.particles > 0
end

return item

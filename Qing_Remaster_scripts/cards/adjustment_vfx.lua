-- VIII - 调节? VFX
-- 资源粒子契约对齐 creditor_contract_vfx：纯 screen-space，直接 Render(p.pos)。
-- 卡牌目标：HeldSprite 可见中心（POST_PLAYER_RENDER 捕获）；wait_anchor 后再造路径。

local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local slot_offer_lift = require("Qing_Remaster_scripts.slots.slot_offer_lift")

local item = {
	sessions = {},
	_last_kind_sound = {},
}

local MAX_VISIBLE = 8
local DETACH_FRAMES = 10
local CRUISE_FRAMES = 38
local ABSORB_FRAMES = 18
local STAGGER = 3
local KIND_WAVE = {coin = 0, key = 6, bomb = 12}
local KIND_ARC_MUL = {coin = 1.15, key = 0.95, bomb = 0.82}

local CARD_CHARGE_FRAMES = 12
local STAT_RELEASE_FRAMES = 10
local STAT_HOLD_FRAMES = 12
local STAT_APPLY_FRAMES = 10
-- POST_PLAYER_UPDATE ≈ 60Hz；约 0.5s 仍无 Held 中心则跳过资源飞行
local ANCHOR_TIMEOUT_FRAMES = 30

local REFUND_PAUSE = 6
local REFUND_RELEASE_FRAMES = 7
local REFUND_FLY_FRAMES = 30

-- Held card ANM2 (AnimateCard LiftItem → HudAnim):
-- path: resources/gfx/ui/content/ui_cardfronts.anm2
-- animation: "Adjustment r_" (pocketitems hud="Adjustment r_")
-- visible card layer: 0 ("ui")
-- frame 0 (sole / stable hold frame):
--   Pos=(0,0) Pivot=(8,12) Width=16 Height=20 Scale=100%
-- ANM2 geometric center vs HeldSprite render origin:
--   center = Pos + (W/2, H/2) - Pivot
--         = (0,0) + (8,10) - (8,12) = (0, -2)
-- 2026-09-10 实机：仅用 ANM2 (0,-2) 仍偏下；累计校准上移 24px
-- （首轮 +16，二轮 +8）→ 最终 = ANM2(-2) + (-24) = (0, -26)。
local HELD_CARD_VISUAL_OFFSET = Vector(0, -26)

-- 固定五维对称扇形（屏幕 px，相对卡面中心；禁止再压椭圆）
local STAT_LAYOUT = {
	Damage = Vector(-36, -12),
	Tears = Vector(-19, -31),
	Range = Vector(0, -39),
	Speed = Vector(19, -31),
	Luck = Vector(36, -12),
}

local EID_ANM2 = "gfx/ui/EID/eid_inline_icons.anm2"
local STAT_ICONS = {
	{name = "Damage", frame = 0},
	{name = "Tears", frame = 2},
	{name = "Range", frame = 3},
	{name = "Speed", frame = 1},
	{name = "Luck", frame = 5},
}

local KIND_SOUND = {
	coin = SoundEffect.SOUND_PENNYPICKUP,
	key = SoundEffect.SOUND_KEYPICKUP,
	bomb = SoundEffect.SOUND_THUMBSUP,
}

local function clamp01(t)
	return math.max(0, math.min(1, t))
end

local function ease_out_cubic(t)
	t = clamp01(t)
	return 1 - (1 - t) ^ 3
end

local function ease_in_cubic(t)
	t = clamp01(t)
	return t * t * t
end

local function smoothstep(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end

local function safe_normalized(v, fallback)
	if v and v:Length() > 0.001 then
		return v:Normalized()
	end
	return fallback or Vector(1, 0)
end

local function particle_fan_value(index, total)
	if total <= 1 then
		return 0
	end
	local center = (total - 1) * 0.5
	return (index - center) / math.max(1, center)
end

local function game_frame()
	return Game():GetFrameCount()
end

local function entity_screen_pos(ent, offset)
	local po = ent.PositionOffset or Vector(0, 0)
	local pos = Isaac.WorldToScreen(ent.Position + po)
	if offset then
		pos = pos + offset
	end
	local room = Game():GetRoom()
	if room and room.GetRenderScrollOffset then
		pos = pos - room:GetRenderScrollOffset()
	end
	return pos
end

-- VIII - 调节? 举卡演出目标：player render + Held.Offset + ANM2 卡面中心常量。
-- 禁止对 HeldSprite 运行时猜 layer0 / SpriteVisualCenterOffset（Held 容器 layer 不一定是卡面）。
local function get_adjustment_card_center(player, callback_offset)
	if not player then return nil end
	local origin = entity_screen_pos(player, callback_offset)
	if not player.GetHeldSprite then
		return nil
	end
	local ok, held = pcall(function()
		return player:GetHeldSprite()
	end)
	if not ok or not held then
		return nil
	end
	local held_offset = held.Offset
		and Vector(held.Offset.X, held.Offset.Y)
		or Vector(0, 0)
	local scale = held.Scale or Vector(1, 1)
	return origin
		+ held_offset
		+ Vector(
			HELD_CARD_VISUAL_OFFSET.X * scale.X,
			HELD_CARD_VISUAL_OFFSET.Y * scale.Y
		)
end

local function current_card_target(session)
	return session.card_visual_center
end

local function current_player_target(session)
	return session.player_render_pos or session.last_player_render_pos
end

local function hud_visible()
	local hud = Game():GetHUD()
	return hud and hud.IsVisible and hud:IsVisible()
end

local function visual_strength(total)
	local s = math.sqrt(math.max(0, total or 0)) / 8
	return math.max(0.55, math.min(1.35, s))
end

local function play_kind_sound(kind, vol)
	local now = game_frame()
	local last = item._last_kind_sound[kind] or -99
	if now - last < 2 then return end
	item._last_kind_sound[kind] = now
	local sid = KIND_SOUND[kind] or SoundEffect.SOUND_PENNYPICKUP
	sound_tracker.PlayStackedSound(sid, vol or 0.4, 1.05, false, 0, 2)
end

local function apply_hud_particle_look(p)
	local sprite = p.sprite
	if not sprite then return end
	local scale = (p.base_scale or 1) * (p.scale_mul or 1)
	sprite.Scale = Vector(scale, scale)
	local bright = p.bright or 0
	sprite.Color = Color(1, 1, 1, p.base_alpha or 1, bright * 0.55, bright * 0.45, bright * 0.25)
end

local function make_stat_sprite(frame)
	local sprite = Sprite()
	sprite:Load(EID_ANM2, true)
	sprite:SetFrame("Stats", frame)
	sprite.Scale = Vector(1.15, 1.15)
	return sprite
end

local function mark_absorb_done(session, p)
	if p.absorb_counted then return end
	p.absorb_counted = true
	session.absorbed_particles = (session.absorbed_particles or 0) + 1
end

local function hide_card(session)
	if not session or not session.holding_card then return end
	local player = session.player
	local card_id = session.card_id
	if player and player.Exists and player:Exists() and card_id
		and player.IsHoldingItem and player:IsHoldingItem() then
		player:AnimateCard(card_id, "HideItem")
	end
	session.holding_card = false
end

local function flush_refund(session)
	if not session or session.refund_applied then return end
	local refund = session.refund_pending
	if not refund then
		session.refund_applied = true
		return
	end
	local player = session.player
	if player and player.Exists and player:Exists() then
		if (refund.coin or 0) > 0 then player:AddCoins(refund.coin) end
		if (refund.key or 0) > 0 then player:AddKeys(refund.key) end
		if (refund.bomb or 0) > 0 then player:AddBombs(refund.bomb) end
	end
	session.refund_pending = nil
	session.refund_applied = true
end

local function finish_session(session)
	flush_refund(session)
	hide_card(session)
	session.phase = "done"
	session.particles = {}
	session.stats = {}
end

local function make_detach_pos(start, target, index, total)
	local to_target = safe_normalized(target - start, Vector(1, 0))
	local target_angle = to_target:GetAngleDegrees()
	local fan = particle_fan_value(index, total)
	local angle = target_angle + fan * 55 + (math.random() - 0.5) * 12
	local radius = 18 + math.random() * 16
	return start + auxi.MakeVector(angle) * radius
end

local function make_absorb_path(start, target, index, visible, kind)
	local delta = target - start
	local forward = safe_normalized(delta, Vector(1, 0))
	local side = Vector(-forward.Y, forward.X)
	local fan = particle_fan_value(index, visible)

	local detach_pos = make_detach_pos(start, target, index, visible)

	local approach_target = target
		- forward * (10 + math.random() * 6)
		+ side * (fan * 4 + (math.random() - 0.5) * 4)

	local arc_mul = KIND_ARC_MUL[kind] or 1
	local arc_amount = (fan * (24 + math.random() * 12) + (math.random() - 0.5) * 8) * arc_mul
	local arc_bias = (math.random() - 0.5) * 8

	return {
		detach_pos = detach_pos,
		approach_target = approach_target,
		arc_amount = arc_amount,
		arc_bias = arc_bias,
	}
end

local function make_refund_path(start, target, index, visible)
	local delta = target - start
	local forward = safe_normalized(delta, Vector(1, 0))
	local side = Vector(-forward.Y, forward.X)
	local fan = particle_fan_value(index, visible)
	local release_pos = start
		+ forward * 10
		+ side * (fan * 14 + (math.random() - 0.5) * 5)
	return {
		release_pos = release_pos,
		arc_amount = fan * 22 + (math.random() - 0.5) * 8,
		arc_bias = (math.random() - 0.5) * 8,
	}
end

local function get_cruise_control(p)
	local start = p.cruise_start or p.detach_pos
	local target = p.approach_target
	local delta = target - start
	local forward = safe_normalized(delta, Vector(1, 0))
	local side = Vector(-forward.Y, forward.X)
	return (start + target) * 0.5
		+ side * (p.arc_amount or 0)
		+ forward * (p.arc_bias or 0)
end

local function update_absorb_detach(p)
	p.phase_frame = p.phase_frame + 1
	local t = ease_out_cubic(p.phase_frame / DETACH_FRAMES)
	p.pos = p.start_pos + (p.detach_pos - p.start_pos) * t
	p.scale_mul = 1 + 0.06 * t
	p.bright = 0.08 * t
	p.base_alpha = 1
	apply_hud_particle_look(p)
	if p.phase_frame >= DETACH_FRAMES then
		p.phase = "cruise"
		p.phase_frame = 0
		p.cruise_start = Vector(p.pos.X, p.pos.Y)
	end
end

local function update_absorb_cruise(p)
	p.phase_frame = p.phase_frame + 1
	-- linear t：末端保持速度，避免 smoothstep 在 t→1 刹停后再进 Absorb
	local t = clamp01(p.phase_frame / CRUISE_FRAMES)
	local start = p.cruise_start or p.detach_pos
	local target = p.approach_target
	local mid = get_cruise_control(p)
	p.pos = auxi.Bezier4(start, mid, mid, target, t)
	p.scale_mul = 1.06 + (0.95 - 1.06) * t
	p.bright = 0.08 + 0.12 * t
	p.base_alpha = 1
	apply_hud_particle_look(p)
	if p.phase_frame >= CRUISE_FRAMES then
		p.phase = "absorb"
		p.phase_frame = 0
	end
end

local function update_absorb_final(p, session)
	p.phase_frame = p.phase_frame + 1
	local target = current_card_target(session)
	if not target then
		p.phase = "done"
		mark_absorb_done(session, p)
		return
	end

	local progress = clamp01(p.phase_frame / ABSORB_FRAMES)
	local k = 0.12 + 0.34 * smoothstep(progress)
	local diff = target - p.pos
	p.pos = p.pos + diff * k

	p.scale_mul = 0.95 + (0.34 - 0.95) * progress
	p.bright = 0.20 + 0.80 * progress
	p.base_alpha = 1 - 0.28 * progress
	apply_hud_particle_look(p)

	if diff:Length() <= 1.5 or p.phase_frame >= ABSORB_FRAMES then
		p.pos = Vector(target.X, target.Y)
		p.phase = "done"
		mark_absorb_done(session, p)
	end
end

local function tick_absorb_particle(p, session)
	if p.phase == "wait" then
		if game_frame() < p.wait_until then return end
		p.phase = "detach"
		p.phase_frame = 0
		if p.kind_sound_owner then
			play_kind_sound(p.kind, 0.35)
		end
	end
	if p.phase == "detach" then
		update_absorb_detach(p)
	elseif p.phase == "cruise" then
		update_absorb_cruise(p)
	elseif p.phase == "absorb" then
		update_absorb_final(p, session)
	end
end

local function update_refund_release(p)
	p.phase_frame = p.phase_frame + 1
	local t = ease_out_cubic(p.phase_frame / REFUND_RELEASE_FRAMES)
	p.pos = p.start_pos + (p.release_pos - p.start_pos) * t
	p.scale_mul = 0.9 + 0.08 * t
	p.bright = 0.2 * (1 - t * 0.4)
	p.base_alpha = 1
	apply_hud_particle_look(p)
	if p.phase_frame >= REFUND_RELEASE_FRAMES then
		p.phase = "refund_fly"
		p.phase_frame = 0
		p.release_pos = Vector(p.pos.X, p.pos.Y)
	end
end

local function update_refund_fly(p)
	p.phase_frame = p.phase_frame + 1
	local raw = clamp01(p.phase_frame / REFUND_FLY_FRAMES)
	local t = smoothstep(raw)
	local start = p.release_pos
	local target = p.target
	local delta = target - start
	local forward = safe_normalized(delta, Vector(1, 0))
	local side = Vector(-forward.Y, forward.X)
	local mid = (start + target) * 0.5
		+ side * (p.arc_amount or 0)
		+ forward * (p.arc_bias or 0)
	p.pos = auxi.Bezier4(start, mid, mid, target, t)
	p.scale_mul = 0.9 + 0.15 * t
	p.bright = 0.3 * (1 - t)
	apply_hud_particle_look(p)
	if p.phase_frame >= REFUND_FLY_FRAMES then
		p.pos = target
		p.phase = "done"
	end
end

local function tick_refund_particle(p)
	if p.phase == "wait" then
		if game_frame() < p.wait_until then return end
		p.phase = "release"
		p.phase_frame = 0
		if p.kind_sound_owner then
			play_kind_sound(p.kind, 0.4)
		end
	end
	if p.phase == "release" then
		update_refund_release(p)
	elseif p.phase == "refund_fly" then
		update_refund_fly(p)
	end
end

local function spawn_absorb_particles(session)
	local player = session.player
	local card_target = current_card_target(session)
	if not card_target then
		return false
	end
	local counts = {
		coin = session.coins or 0,
		key = session.keys or 0,
		bomb = session.bombs or 0,
	}
	local now = game_frame()
	session.particles = {}
	for _, kind in ipairs({"coin", "key", "bomb"}) do
		local total = counts[kind] or 0
		if total > 0 then
			local visible = math.min(total, MAX_VISIBLE)
			local wave = KIND_WAVE[kind] or 0
			local base_scale = slot_offer_lift.get_creditor_hud_fly_scale(kind)
			local hud = slot_offer_lift.get_pickup_hud_screen_pos(player, kind, 0)
			for i = 0, visible - 1 do
				local fan = particle_fan_value(i, visible)
				local start = hud + Vector(fan * 5, (math.random() - 0.5) * 3)
				local path = make_absorb_path(start, card_target, i, visible, kind)
				local sprite = slot_offer_lift.make_creditor_hud_fly_sprite(kind, base_scale)
				local p = {
					role = "absorb",
					kind = kind,
					sprite = sprite,
					pos = Vector(start.X, start.Y),
					start_pos = Vector(start.X, start.Y),
					detach_pos = path.detach_pos,
					approach_target = path.approach_target,
					arc_amount = path.arc_amount,
					arc_bias = path.arc_bias,
					wait_until = now + wave + i * STAGGER,
					phase = "wait",
					phase_frame = 0,
					base_scale = base_scale,
					scale_mul = 1,
					base_alpha = 1,
					bright = 0,
					kind_sound_owner = (i == 0),
					absorb_counted = false,
				}
				apply_hud_particle_look(p)
				table.insert(session.particles, p)
			end
		end
	end
	session.total_particles = #session.particles
	session.absorbed_particles = 0
	return #session.particles > 0
end

local function spawn_refund_particles(session)
	local player = session.player
	local refund = session.refund_pending
	local card_start = current_card_target(session)
	if not refund or not card_start then
		flush_refund(session)
		return
	end
	local now = game_frame()
	local counts = {coin = refund.coin or 0, key = refund.key or 0, bomb = refund.bomb or 0}
	local any = false
	for _, kind in ipairs({"coin", "key", "bomb"}) do
		local total = counts[kind] or 0
		if total > 0 then
			any = true
			local visible = math.min(total, MAX_VISIBLE)
			local wave = KIND_WAVE[kind] or 0
			local base_scale = slot_offer_lift.get_creditor_hud_fly_scale(kind)
			local hud = slot_offer_lift.get_pickup_hud_screen_pos(player, kind, 0)
			for i = 0, visible - 1 do
				local fan = particle_fan_value(i, visible)
				local target = hud + Vector(fan * 4, (math.random() - 0.5) * 2)
				local path = make_refund_path(card_start, target, i, visible)
				local sprite = slot_offer_lift.make_creditor_hud_fly_sprite(kind, base_scale)
				local p = {
					role = "refund",
					kind = kind,
					sprite = sprite,
					pos = Vector(card_start.X, card_start.Y),
					start_pos = Vector(card_start.X, card_start.Y),
					release_pos = path.release_pos,
					arc_amount = path.arc_amount,
					arc_bias = path.arc_bias,
					target = target,
					wait_until = now + wave + i * STAGGER,
					phase = "wait",
					phase_frame = 0,
					base_scale = base_scale,
					scale_mul = 0.9,
					base_alpha = 1,
					bright = 0.15,
					kind_sound_owner = (i == 0),
				}
				apply_hud_particle_look(p)
				table.insert(session.particles, p)
			end
		end
	end
	if not any then
		flush_refund(session)
	end
end

local function spawn_stat_icons(session)
	local strength = session.strength or 1
	local origin = current_card_target(session)
	if not origin then return end

	session.stats = {}
	local layout_scale = 0.95 + 0.08 * math.min(1.35, strength)

	for _, info in ipairs(STAT_ICONS) do
		local base_offset = STAT_LAYOUT[info.name] or Vector(0, 0)
		local dest = origin + base_offset * layout_scale
		local sprite = make_stat_sprite(info.frame)
		local scale = 0.95 + 0.35 * strength
		sprite.Scale = Vector(scale, scale)
		table.insert(session.stats, {
			sprite = sprite,
			pos = Vector(origin.X, origin.Y),
			origin = Vector(origin.X, origin.Y),
			hold_pos = dest,
			base_scale = scale,
			name = info.name,
		})
	end
end

local function begin_card_charge(session)
	session.phase = "card_charge"
	session.phase_start = game_frame()
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1, 0.5 + 0.2 * (session.strength or 1), 1.1, false, 0, 2)
end

local function begin_stat_release(session)
	session.phase = "stat_release"
	session.phase_start = game_frame()
	spawn_stat_icons(session)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP_SPEWER, 0.45, 1.15, false, 0, 2)
end

local function begin_refund_phase(session)
	if not session.refund_pending then
		finish_session(session)
		return
	end
	if not hud_visible() or not current_card_target(session) then
		flush_refund(session)
		finish_session(session)
		return
	end
	session.phase = "refund"
	session.particles = {}
	spawn_refund_particles(session)
end

local function tick_stats_release(session)
	local t = clamp01((game_frame() - session.phase_start) / STAT_RELEASE_FRAMES)
	local e = ease_out_cubic(t)
	for _, st in ipairs(session.stats or {}) do
		st.pos = st.origin + (st.hold_pos - st.origin) * e
		local sc = st.base_scale * (0.75 + 0.3 * e)
		st.sprite.Scale = Vector(sc, sc)
		st.sprite.Color = Color(1, 1, 1, 0.55 + 0.45 * e, 0.2 * (1 - e), 0.15 * (1 - e), 0.05)
	end
	if t >= 1 then
		session.phase = "stat_hold"
		session.phase_start = game_frame()
	end
end

local function tick_stats_hold(session)
	local age = game_frame() - session.phase_start
	for _, st in ipairs(session.stats or {}) do
		st.pos = Vector(st.hold_pos.X, st.hold_pos.Y)
		local pulse = 1 + math.sin(Isaac.GetFrameCount() * 0.22) * 0.035
		local sc = st.base_scale * pulse
		st.sprite.Scale = Vector(sc, sc)
		st.sprite.Color = Color(1, 1, 1, 1, 0.08, 0.06, 0.02)
	end
	if age >= STAT_HOLD_FRAMES then
		session.phase = "stat_apply"
		session.phase_start = game_frame()
		for _, st in ipairs(session.stats or {}) do
			st.apply_start = Vector(st.pos.X, st.pos.Y)
		end
	end
end

local function tick_stats_apply(session)
	local t = clamp01((game_frame() - session.phase_start) / STAT_APPLY_FRAMES)
	local e = ease_in_cubic(t)
	local target = current_player_target(session) or current_card_target(session)
	if not target then
		session.stats = {}
		finish_session(session)
		return
	end
	for _, st in ipairs(session.stats or {}) do
		local start = st.apply_start or st.hold_pos
		st.pos = start + (target - start) * e
		local sc = st.base_scale * (1 - 0.55 * e)
		st.sprite.Scale = Vector(sc, sc)
		st.sprite.Color = Color(1, 1, 1, 1 - 0.15 * e, 0.25 * e, 0.2 * e, 0.08 * e)
	end
	if t >= 1 then
		session.stats = {}
		if session.refund_pending then
			session.phase = "refund_wait"
			session.phase_start = game_frame()
		else
			finish_session(session)
		end
	end
end

local function prune_done_particles(session)
	for i = #session.particles, 1, -1 do
		if session.particles[i].phase == "done" then
			table.remove(session.particles, i)
		end
	end
end

local function try_start_absorb(session)
	if not session.anchor_ready or not session.card_visual_center then
		return
	end
	if not hud_visible() then
		begin_card_charge(session)
		if session.refund_pending then
			flush_refund(session)
		end
		return
	end
	if spawn_absorb_particles(session) then
		session.phase = "absorb"
	else
		begin_card_charge(session)
	end
end

local function tick_session(session)
	if not session or session.phase == "done" then return end
	local player = session.player
	if not player or not player.Exists or not player:Exists() or (player.IsDead and player:IsDead()) then
		finish_session(session)
		return
	end

	if session.phase == "wait_anchor" then
		try_start_absorb(session)
		if session.phase == "wait_anchor"
			and game_frame() - (session.start_frame or 0) >= ANCHOR_TIMEOUT_FRAMES then
			-- 异常保护：无真实 card center 时不建 Cruise，直接充能/结算
			begin_card_charge(session)
			if session.refund_pending then
				flush_refund(session)
			end
		end
		return
	end

	if session.phase == "absorb" then
		for _, p in ipairs(session.particles) do
			if p.phase ~= "done" then
				tick_absorb_particle(p, session)
			end
		end
		prune_done_particles(session)
		if #session.particles == 0 then
			begin_card_charge(session)
		end
		return
	end

	if session.phase == "card_charge" then
		if game_frame() - (session.phase_start or 0) >= CARD_CHARGE_FRAMES then
			begin_stat_release(session)
		end
		return
	end

	if session.phase == "stat_release" then
		tick_stats_release(session)
		return
	end

	if session.phase == "stat_hold" then
		tick_stats_hold(session)
		return
	end

	if session.phase == "stat_apply" then
		tick_stats_apply(session)
		return
	end

	if session.phase == "refund_wait" then
		if game_frame() - (session.phase_start or 0) >= REFUND_PAUSE then
			begin_refund_phase(session)
		end
		return
	end

	if session.phase == "refund" then
		for _, p in ipairs(session.particles) do
			if p.phase ~= "done" then
				tick_refund_particle(p)
			end
		end
		prune_done_particles(session)
		if #session.particles == 0 then
			flush_refund(session)
			finish_session(session)
		end
	end
end

function item.capture_player_render(player, offset)
	if not player then return end
	local session = item.sessions[GetPtrHash(player)]
	if not session or session.phase == "done" then return end

	local player_pos = entity_screen_pos(player, offset)
	session.player_render_pos = player_pos
	session.last_player_render_pos = player_pos

	local card_center = get_adjustment_card_center(player, offset)
	if card_center then
		session.card_visual_center = card_center
		session.last_card_visual_center = card_center
		session.anchor_ready = true
	end
end

local function render_resource_particle(p)
	if not p or not p.sprite or not p.pos then return end
	if p.phase == "wait" or p.phase == "done" then return end
	local scale = (p.base_scale or 1) * (p.scale_mul or 1)
	p.sprite.Scale = Vector(scale, scale)
	p.sprite:Render(p.pos, Vector(0, 0), Vector(0, 0))
end

function item.play(opts)
	opts = opts or {}
	local player = opts.player
	if not player then return end
	local key = GetPtrHash(player)
	local old = item.sessions[key]
	if old then
		finish_session(old)
	end

	local coins = opts.coins or 0
	local keys = opts.keys or 0
	local bombs = opts.bombs or 0
	local total = opts.total or 0
	local refund = opts.refund
	local card_id = opts.card_id
	local strength = visual_strength(total)

	-- LiftItem 由 Card_08r 唯一负责；此处只记录以便结束时 HideItem
	local session = {
		player = player,
		card_id = card_id,
		holding_card = card_id ~= nil,
		coins = coins,
		keys = keys,
		bombs = bombs,
		total = total,
		strength = strength,
		particles = {},
		stats = {},
		refund_pending = nil,
		refund_applied = false,
		phase = "wait_anchor",
		anchor_ready = false,
		start_frame = game_frame(),
		total_particles = 0,
		absorbed_particles = 0,
	}
	if refund and ((refund.coin or 0) > 0 or (refund.key or 0) > 0 or (refund.bomb or 0) > 0) then
		session.refund_pending = {
			coin = refund.coin or 0,
			key = refund.key or 0,
			bomb = refund.bomb or 0,
		}
	end

	item.sessions[key] = session

	local has_res = coins > 0 or keys > 0 or bombs > 0
	if not has_res then
		finish_session(session)
		item.sessions[key] = nil
		return
	end
end

function item.tick()
	for key, session in pairs(item.sessions) do
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and GetPtrHash(p) == key then
				session.player = p
				break
			end
		end
		tick_session(session)
		if session.phase == "done" then
			item.sessions[key] = nil
		end
	end
end

function item.render()
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	for _, session in pairs(item.sessions) do
		for _, p in ipairs(session.particles or {}) do
			render_resource_particle(p)
		end
		for _, st in ipairs(session.stats or {}) do
			if st.sprite and st.pos then
				local scale = st.sprite.Scale.X
				local render_pos = ui.VisualCenterToRenderPos(st.pos, st.sprite, scale, 0)
				st.sprite:Render(render_pos, Vector(0, 0), Vector(0, 0))
			end
		end
	end
end

function item.clear_all()
	for key, session in pairs(item.sessions) do
		finish_session(session)
		item.sessions[key] = nil
	end
end

function item.active()
	return next(item.sessions) ~= nil
end

return item

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local MEUS_NIL_VARIANT = enums.Entities.ID_EFFECT_MeusNIL
if not MEUS_NIL_VARIANT or MEUS_NIL_VARIANT < 0 then
	MEUS_NIL_VARIANT = 2338
end

local item = {
	ToCall = {},
	entity = enums.Items.The_Watcher,
	own_key = "Item_The_Watcher_",
	anm2 = "gfx/mimics/The_Watcher/the_watcher.anm2",
	target_anm2 = "gfx/mimics/The_Watcher/the_watcher_target.anm2",
	self_anm2 = "gfx/mimics/The_Watcher/the_watcher_self.anm2",
	min_speed = 1.5,
	safe_velocity = 4,
	player_limit = 240,
	player_decay = 2,
	-- 监视域：随自身进度扩张（非全屏）
	distance = 110, -- 兼容旧引用 = distance_min
	distance_min = 110,
	distance_max = 195,
	retention_mul = 1.35,
	move_freeze_frames = 24,
	move_decay_per_frame = 3,
	enemy_limit = 75,
	enemy_cooldown = 150,
	boss_cooldown = 210,
	explosion_mul = 4,
	explosion_flat = 20,
	awake_grace = 16,
	release_hold = 12,
	awake_meter_rate = 0.35,
	lock_filter_rate = 0.25,
	lock_height_frac = 0.30,
	closing_enemy_decay = 10,
	-- 飞行/落地强调用缩放；LOCK 后外尺寸固定，进度改由四角闭合表达
	enemy_scale_hi = 1.15,
	enemy_scale_lo = 1.05,
	self_scale_hi = 1.35,
	self_scale_lo = 1.25,
	enemy_display_scale = 1.05,
	self_display_scale = 1.28,
	enemy_corner_gap_open = 13,
	enemy_corner_gap_closed = 1.5,
	self_corner_gap_open = 17,
	self_corner_gap_closed = 1.5,
	lock_flash_frames = 10,
	track_shatter_frames = 10,
	base_layer = 0,
	eye_layer = 1,
	eye_default_down_deg = 90,
	eye_turn_rate = 0.18,
	max_fork_targets = 4,
	track_spawn_ratio = 0.05,
	track_spawn_frames = 4,
	track_travel_frames = 10,
	track_land_frames = 3,
	track_arc_px = 8,
	track_confirm_frames = 6,
	-- FADE 仅用于爆炸后的击中淡出，不再接在 Confirm 后面立刻删准星
	track_fade_frames = 10,
	enemy_blast_explode_frame = 12,
	track_retract_frames = 18,
	track_ttl = 120,
	self_fade_in_frames = 8,
	self_confirm_frames = 4,
	cam_shake_max = 1.7,
	shoot_explode_frame = 35,
	shoot_end_frame = 70,
	-- Halo_Watcher：144px / pivot72 → Scale=1 时半径 72px；按当前 acquisition 换算
	halo_anm2 = "gfx/effects/Halo/Halo_Watcher.anm2",
	halo_base_radius_px = 72,
	halo_fade_in = 0.12,
	halo_fade_out = 0.11, -- 关闭时光环比机身稍晚收完，避免一起掐断
	halo_alpha = 0.55,
	-- 关闭：先看清闭眼（约 6 帧），再整体溶掉；总淡出约 22 帧
	close_fade_frames = 22,
	-- 准星要盖在前方敌人身上
	nil_depth_offset = 280,
	-- 摄像头相对头顶锚点再上移（屏幕 px）
	cam_lift_px = 16,
	-- 地面底座：简化中立机关（不渲染摄像头，仅光圈 + 单目标准星）
	pedestal_range = 130,
	pedestal_lock_frames = 90,
	pedestal_damage = 30,
	pedestal_cooldown = 150,
	pedestal_blast_delay = 12,
	-- 道具贴图中心相对 pedestal Position 的上抬（世界单位）；Halo pivot 已在 72,72
	pedestal_center_lift = 14,
	pedestal_halo_alpha = 0.48,
}

auxi.add_to_seija(item.entity)

-- 摄像头：数值 warning/critical 仍用 phase 名，但贴图不再跟档切
local PHASE = {
	DORMANT = "DORMANT",
	AWAKE = "AWAKE",
	TRACKING = "TRACKING",
	WARNING = "WARNING",
	CRITICAL = "CRITICAL",
	CONFIRMING = "CONFIRMING",
	FIRING = "FIRING",
	RELEASING = "RELEASING",
	CLOSING = "CLOSING",
}

local TRACK = {
	SPAWN = "SPAWN",
	TRAVEL = "TRAVEL",
	LAND = "LAND",
	LOCK = "LOCK",
	CONFIRM = "CONFIRM",
	-- 已锁死、待轰炸：中心准星常驻，直到实际爆炸
	LOCKED = "LOCKED",
	FADE = "FADE",
	RETRACT = "RETRACT",
	SHATTER = "SHATTER",
}

-- Confirm / Locked / Fade：不可逆火力控制阶段
local function track_is_fire_locked(tr)
	local p = tr and tr.phase
	return p == TRACK.CONFIRM or p == TRACK.LOCKED or p == TRACK.FADE
end

local function watcher_damage(player)
	return player.Damage * item.explosion_mul + item.explosion_flat
end

local function visual_world(ent, is_player)
	if is_player then
		return ent.Position + player_offset_holder.GetVisualPositionOffset(ent)
	end
	return ent.Position + (ent.PositionOffset or Vector(0, 0))
end

local function size_radius(ent)
	local multi = ent.SizeMulti or Vector(1, 1)
	return ent.Size * (0.5 * ((multi.X or 1) + (multi.Y or 1)))
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerp_vec(a, b, t)
	return Vector(lerp(a.X, b.X, t), lerp(a.Y, b.Y, t))
end

local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

local function smoothstep(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end

local function ease_out_cubic(t)
	t = clamp01(t)
	local u = 1 - t
	return 1 - u * u * u
end

local function filter_pos(prev, cur, rate)
	if not prev then
		return Vector(cur.X, cur.Y)
	end
	rate = rate or item.lock_filter_rate
	return Vector(
		prev.X + (cur.X - prev.X) * rate,
		prev.Y + (cur.Y - prev.Y) * rate
	)
end

local function raw_lock_render_pos(ent, offset, is_player)
	offset = offset or Vector(0, 0)
	local world = visual_world(ent, is_player) + Vector(0, -size_radius(ent) * item.lock_height_frac)
	return Isaac.WorldToRenderPosition(world) + offset
end

local function camera_head_pos(player, offset)
	offset = offset or Vector(0, 0)
	local head = ui.GetEntityHeadAnchor(player, {
		top = true,
		centerX = true,
		paddingY = 6,
	})
	-- 屏幕坐标 Y 向下为正：负值 = 上移
	return Isaac.WorldToRenderPosition(visual_world(player, true)) + offset + head + Vector(0, -(item.cam_lift_px or 0))
end

local function angle_lerp(cur, want, rate)
	local d = (want - cur) % 360
	if d > 180 then d = d - 360 end
	if d < -180 then d = d + 360 end
	return cur + d * rate
end

local function eye_rotation_for_dir(dir)
	if not dir or dir:Length() < 0.5 then
		return 0
	end
	return dir:GetAngleDegrees() - item.eye_default_down_deg
end

-- 主锁定过程只靠连续缩放，不切图
local function lock_scale(ratio, hi, lo)
	local t = smoothstep((clamp01(ratio) - 0.10) / 0.90)
	return lerp(hi, lo, t)
end

local function lock_alpha(ratio)
	ratio = clamp01(ratio)
	if ratio < 0.12 then
		return lerp(0.4, 0.85, ratio / 0.12)
	end
	return lerp(0.85, 1.0, (ratio - 0.12) / 0.88)
end

local function phase_from_ratio(ratio, phase)
	if phase == PHASE.FIRING or phase == PHASE.CLOSING or phase == PHASE.AWAKE
		or phase == PHASE.RELEASING or phase == PHASE.CONFIRMING
	then
		return phase
	end
	if ratio >= 0.8 then return PHASE.CRITICAL end
	if ratio >= 0.5 then return PHASE.WARNING end
	if ratio > 0 then return PHASE.TRACKING end
	return PHASE.DORMANT
end

local function player_ratio_of(watch)
	return clamp01(((watch and watch.counter) or 0) / item.player_limit)
end

-- 自身进度 → acquisition：0/110 → 25%/140 → 50%/165 → 75%/185 → 100%/195
local function acquisition_range(watch, seija)
	if seija then return 10000 end
	-- 射击/确认期间冻结半径，避免 counter 清零后光环瞬间缩到起点
	if watch and watch.frozen_acq then
		return watch.frozen_acq
	end
	local t = player_ratio_of(watch)
	if t <= 0.25 then
		return lerp(item.distance_min, 140, t / 0.25)
	elseif t <= 0.5 then
		return lerp(140, 165, (t - 0.25) / 0.25)
	elseif t <= 0.75 then
		return lerp(165, 185, (t - 0.5) / 0.25)
	end
	return lerp(185, item.distance_max, (t - 0.75) / 0.25)
end

local function snapshot_frozen_acq(watch, seija)
	if not watch or watch.frozen_acq then return end
	local acq = acquisition_range(watch, seija)
	if seija then
		acq = item.distance_max
	end
	watch.frozen_acq = acq
end

local function clear_frozen_acq(watch)
	if watch then
		watch.frozen_acq = nil
	end
end

local function retention_range(acq)
	return acq * item.retention_mul
end

-- 距离越远锁定越慢；超出 acquisition 则 0（由调用方管 acquisition）
local function lock_speed_mul(dist)
	if dist <= 90 then
		return 1.25
	elseif dist <= 130 then
		return 1.0
	elseif dist <= 165 then
		return 0.7
	elseif dist <= item.distance_max + 8 then
		return 0.45
	end
	return 0
end

-- 仅低速时真正积累；RELEASING / CONFIRMING 不再加敌人进度（Confirm 只锁玩家）
local function camera_can_accumulate(phase)
	return phase == PHASE.AWAKE
		or phase == PHASE.TRACKING
		or phase == PHASE.WARNING
		or phase == PHASE.CRITICAL
end

local function camera_can_spawn_tracks(phase)
	return phase == PHASE.TRACKING
		or phase == PHASE.WARNING
		or phase == PHASE.CRITICAL
		or phase == PHASE.CONFIRMING
end

-- 短闪：RELEASING 且未超过缓冲帧 → 冻结已有锁定
local function camera_is_move_freeze(watch)
	return watch
		and watch.phase == PHASE.RELEASING
		and (watch.safe_streak or 0) <= item.move_freeze_frames
end

local function camera_is_move_decay(watch)
	return watch
		and watch.phase == PHASE.RELEASING
		and (watch.safe_streak or 0) > item.move_freeze_frames
end

local function surveillance_ranges(watch, seija)
	local acq = acquisition_range(watch, seija)
	local ret = retention_range(acq)
	if seija then
		ret = 10000
	end
	return acq, ret
end

local function is_boss_ent(ent)
	return ent and ((ent.IsBoss and ent:IsBoss()) or false)
end

-- 积极锁定槽：已有进度优先 → Boss → 进度高 → 近距
local function pick_active_lock_targets(player, watch, acq, ret, allow_new)
	local candidates = {}
	local out_of_ret = {}
	for _, v in pairs(auxi.getenemies()) do
		if auxi.check_all_exists(v) and not v:IsDead() then
			local d2 = v:GetData()
			if (d2[item.own_key.."cooldown"] or 0) <= 0 and not d2[item.own_key.."pending_blast"] then
				local dist = (v.Position - player.Position):Length()
				local fx = d2[item.own_key.."effect"]
				local counter = (fx and fx.counter) or 0
				local hash = GetPtrHash(v)
				local has_track = watch.tracks and watch.tracks[hash] ~= nil
				local has_lock = counter > 0 or has_track
				if has_lock and dist > ret then
					out_of_ret[#out_of_ret + 1] = {ent = v, d2 = d2, dist = dist, hash = hash}
				elseif has_lock and dist <= ret then
					candidates[#candidates + 1] = {
						ent = v,
						d2 = d2,
						dist = dist,
						hash = hash,
						counter = counter,
						has_lock = true,
						boss = is_boss_ent(v),
					}
				elseif allow_new and dist <= acq then
					candidates[#candidates + 1] = {
						ent = v,
						d2 = d2,
						dist = dist,
						hash = hash,
						counter = counter,
						has_lock = false,
						boss = is_boss_ent(v),
					}
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.has_lock ~= b.has_lock then
			return a.has_lock
		end
		if a.boss ~= b.boss then
			return a.boss
		end
		if a.counter ~= b.counter then
			return a.counter > b.counter
		end
		return a.dist < b.dist
	end)
	local selected = {}
	local selected_hash = {}
	for i = 1, #candidates do
		if #selected >= item.max_fork_targets then
			break
		end
		local c = candidates[i]
		selected[#selected + 1] = c
		selected_hash[c.hash] = true
	end
	return selected, selected_hash, out_of_ret
end

local function ensure_fx(store)
	if not store.sprite then
		store.sprite = Sprite()
		store.sprite:Load(item.anm2, true)
		store.sprite:Play("Watching", true)
	end
	store.eye_rot = store.eye_rot or 0
	store.tracks = store.tracks or {}
	return store
end

local function play_body(store, anim, force)
	ensure_fx(store)
	local s = store.sprite
	if force or not s:IsPlaying(anim) then
		s:Play(anim, true)
	end
	store.body_anim = anim
end

local function set_layer(sprite, layer_id, opts)
	local layer = sprite.GetLayer and sprite:GetLayer(layer_id)
	if not layer then return end
	opts = opts or {}
	if opts.visible ~= nil and layer.SetVisible then
		layer:SetVisible(opts.visible)
	end
	if opts.rotation ~= nil and layer.SetRotation then
		layer:SetRotation(opts.rotation)
	end
	if (opts.alpha ~= nil or opts.tint) and layer.SetColor then
		local tint = opts.tint or {}
		layer:SetColor(Color(
			tint.r or 1,
			tint.g or 1,
			tint.b or 1,
			opts.alpha or 1,
			tint.ro or 0,
			tint.go or 0,
			tint.bo or 0
		))
	end
end

local function world_radius_to_render_px(center_world, world_r, offset)
	offset = offset or Vector(0, 0)
	local a = Isaac.WorldToRenderPosition(center_world) + offset
	local b = Isaac.WorldToRenderPosition(center_world + Vector(world_r, 0)) + offset
	return (b - a):Length()
end

local function ensure_halo(watch)
	if not watch.halo_spr then
		watch.halo_spr = Sprite()
		watch.halo_spr:Load(item.halo_anm2, true)
		watch.halo_spr:Play("Idle", true)
	end
	watch.halo_t = watch.halo_t or 0
	watch.halo_target = watch.halo_target or 0
	return watch.halo_spr
end

local function tick_halo(watch, want_on)
	watch.halo_target = want_on and 1 or 0
	local cur = watch.halo_t or 0
	local target = watch.halo_target
	local rate = target > cur and item.halo_fade_in or item.halo_fade_out
	watch.halo_t = cur + (target - cur) * rate
	if target <= 0 and watch.halo_t < 0.01 then
		watch.halo_t = 0
	elseif target >= 1 and watch.halo_t > 0.99 then
		watch.halo_t = 1
	end
	if (watch.halo_t or 0) > 0.008 then
		local sp = ensure_halo(watch)
		local frame = Game():GetFrameCount()
		if watch._halo_clock ~= frame then
			sp:Update()
			watch._halo_clock = frame
		end
	end
end

-- 临界警告：danger 0~1，blink 0~1（偏红闪烁）
local function critical_warn(ratio, age, force)
	local danger = force and 1 or clamp01(((ratio or 0) - 0.8) / 0.2)
	if danger <= 0 then
		return 0, 0
	end
	local speed = 0.55 + 0.85 * danger
	local wave = 0.5 + 0.5 * math.sin((age or 0) * speed)
	local blink = wave * wave * (0.65 + 0.35 * danger)
	return danger, blink
end

local function critical_tint(blink)
	local k = blink or 0
	return {
		r = 1,
		g = 1 - 0.78 * k,
		b = 1 - 0.88 * k,
		ro = 0.62 * k,
		go = 0,
		bo = 0,
	}
end

-- 以眼睛（摄像头）为中心，半径 = 当前 acquisition range
local function render_halo(watch, player, cam_pos, offset, body_alpha, warn_blink)
	local mul = smoothstep(watch.halo_t or 0)
	if mul < 0.01 then return end
	local sp = ensure_halo(watch)
	local seija = auxi.should_do_Seija(player, true)
	local world_r = acquisition_range(watch, seija)
	-- Seija 全图判定时光环仍显示设计最大半径，避免撑满屏
	if seija then
		world_r = item.distance_max
	end
	local screen_r = world_radius_to_render_px(visual_world(player, true), world_r, offset)
	local scale = (screen_r / item.halo_base_radius_px) * mul
	local alpha = mul * item.halo_alpha * (body_alpha or 1)
	local k = warn_blink or 0
	sp.Color = Color(1, 1 - 0.55 * k, 1 - 0.7 * k, alpha, 0.45 * k, 0, 0)
	sp.Scale = Vector(scale, scale)
	sp:Render(cam_pos, Vector(0, 0), Vector(0, 0))
	sp.Scale = Vector(1, 1)
	sp.Color = Color(1, 1, 1, 1)
end

local function render_camera(store, cam_pos, opts)
	opts = opts or {}
	ensure_fx(store)
	local s = store.sprite
	local body_alpha = opts.body_alpha or 1
	local scale = opts.scale or 1
	local shake = math.min(item.cam_shake_max, opts.shake or 0)
	local eye_rot = opts.eye_rot
	if eye_rot == nil then eye_rot = store.eye_rot or 0 end
	local recoil = opts.recoil_y or 0
	local tint = opts.tint

	local shake_off = Vector(0, recoil)
	if shake > 0.01 then
		local t = (store.age or 0) * 1.35
		shake_off = shake_off + Vector(math.sin(t * 2.7) * shake, math.cos(t * 3.4) * shake * 0.85)
		shake_off = shake_off + Vector(math.sin(t * 7.1) * shake * 0.35, math.cos(t * 6.3) * shake * 0.28)
	end
	local pos = cam_pos + shake_off
	local prev_scale = s.Scale
	s.Scale = Vector(scale, scale)

	if not s.RenderLayer then
		local t = tint or {}
		s.Color = Color(t.r or 1, t.g or 1, t.b or 1, body_alpha, t.ro or 0, t.go or 0, t.bo or 0)
		s:Render(pos, Vector(0, 0), Vector(0, 0))
		s.Color = Color(1, 1, 1, 1)
		s.Scale = prev_scale or Vector(1, 1)
		return
	end

	set_layer(s, item.base_layer, {visible = true, alpha = body_alpha, rotation = 0, tint = tint})
	s:RenderLayer(item.base_layer, pos)
	set_layer(s, item.eye_layer, {visible = true, alpha = body_alpha, rotation = eye_rot, tint = tint})
	s:RenderLayer(item.eye_layer, pos)
	s.Scale = prev_scale or Vector(1, 1)
end

local function new_sprite(path, anim)
	local s = Sprite()
	s:Load(path, true)
	s:Play(anim or "Track", true)
	return s
end

local function play_anim(spr, anim, force, owner)
	if not spr or not anim then return end
	owner = owner or spr
	if force or owner._anim ~= anim then
		spr:Play(anim, true)
		owner._anim = anim
	end
end

-- Confirm（扣扳机）不得跨移动冻结；一旦脱离监视必须整段取消
local function cancel_confirming(watch)
	if not watch then return end
	local was = watch.phase == PHASE.CONFIRMING or watch.self_confirm_t ~= nil
	watch.self_confirm_t = nil
	clear_frozen_acq(watch)
	if was then
		watch.counter = math.min(watch.counter or 0, math.floor(item.player_limit * 0.95))
		if watch.self_spr then
			play_anim(watch.self_spr, "Watch", true, watch)
		end
	end
end

local function render_sprite(spr, pos, scale, alpha, tint)
	if not spr then return end
	if spr.Update then
		spr:Update()
	end
	local r, g, b = 1, 1, 1
	local ro, go, bo = 0, 0, 0
	if tint then
		r = tint.r or 1
		g = tint.g or 1
		b = tint.b or 1
		ro = tint.ro or 0
		go = tint.go or 0
		bo = tint.bo or 0
	end
	spr.Color = Color(r, g, b, alpha or 1, ro, go, bo)
	spr.Scale = Vector(scale or 1, scale or 1)
	spr:Render(pos, Vector(0, 0), Vector(0, 0))
	spr.Scale = Vector(1, 1)
	spr.Color = Color(1, 1, 1, 1)
end

local function progress_corner_gap(progress, gap_open, gap_closed)
	return lerp(gap_open, gap_closed, smoothstep(clamp01(progress)))
end

local function play_lock_click(vol, pitch)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_NOTE_APPEAR, vol or 0.85, pitch or 0.9, false, 0, 1)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BEEP, (vol or 0.85) * 0.45, (pitch or 0.9) * 1.7, false, 0, 1)
end

-- 四角闭合准星：外尺寸固定，progress 只改变角间距（可读的完成度）
local function render_bracket_reticle(spr, pos, scale, alpha, tint, progress, gap_open, gap_closed, opts)
	if not spr or (alpha or 0) <= 0.02 then return end
	opts = opts or {}
	if spr.Update and not opts.skip_update then
		spr:Update()
	end
	local r, g, b = 1, 1, 1
	local ro, go, bo = 0, 0, 0
	if tint then
		r = tint.r or 1
		g = tint.g or 1
		b = tint.b or 1
		ro = tint.ro or 0
		go = tint.go or 0
		bo = tint.bo or 0
	end
	local gap = progress_corner_gap(progress, gap_open, gap_closed)
	if opts.gap_mul then
		gap = gap * opts.gap_mul
	end
	local half = opts.half or 16
	local base_a = (opts.base_alpha or 0.22) * (alpha or 1)
	spr.Scale = Vector(scale or 1, scale or 1)
	if base_a > 0.02 then
		spr.Color = Color(r, g, b, base_a, ro, go, bo)
		spr:Render(pos, Vector(0, 0), Vector(0, 0))
	end
	spr.Color = Color(r, g, b, alpha or 1, ro, go, bo)
	spr:Render(pos + Vector(-gap, -gap), Vector(0, 0), Vector(half, half))
	spr:Render(pos + Vector(gap, -gap), Vector(half, 0), Vector(0, half))
	spr:Render(pos + Vector(-gap, gap), Vector(0, half), Vector(half, 0))
	spr:Render(pos + Vector(gap, gap), Vector(half, half), Vector(0, 0))
	spr.Scale = Vector(1, 1)
	spr.Color = Color(1, 1, 1, 1)
end


local function update_eye_look(store, cam_pos, look_pos)
	ensure_fx(store)
	local want = 0
	if look_pos then
		want = eye_rotation_for_dir(look_pos - cam_pos)
	end
	store.eye_rot = angle_lerp(store.eye_rot or 0, want, item.eye_turn_rate)
	return store.eye_rot
end

local function critical_tick_sound(store, ratio)
	if ratio < 0.8 then
		store._tick_cd = 0
		return
	end
	local t = (ratio - 0.8) / 0.2
	local interval = math.floor(lerp(18, 6, t))
	store._tick_cd = (store._tick_cd or 0) - 1
	if store._tick_cd <= 0 then
		store._tick_cd = interval
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_SCROLL, 0.22 + 0.18 * t, 1.4 + 0.35 * t, false, 0, 2)
	end
end

local function enemy_lock_info(ent)
	local d2 = ent:GetData()
	local fx = d2[item.own_key.."effect"]
	local pending = d2[item.own_key.."pending_blast"]
	if pending then
		-- 仍列入 locks，供已锁死 track 刷新 wrapper / 贴身；禁止新建 track（见 sync）
		return 1, 9999, true, true
	end
	if not fx then return 0, 0, false, false end
	local lim = fx.limit or item.enemy_limit
	local ratio = clamp01((fx.counter or 0) / lim)
	return ratio, fx.counter or 0, ratio > item.track_spawn_ratio, false
end

local function collect_active_enemies()
	local list = {}
	for _, v in pairs(auxi.getenemies()) do
		if auxi.check_all_exists(v) and not v:IsDead() then
			local ratio, counter, active, is_pending = enemy_lock_info(v)
			if active then
				list[#list + 1] = {
					ent = v,
					hash = GetPtrHash(v),
					ratio = ratio,
					counter = counter,
					pending = is_pending == true,
				}
			end
		end
	end
	table.sort(list, function(a, b)
		return a.counter > b.counter
	end)
	return list
end

local function resolve_primary_target(watch, locks)
	local cur = watch.primary_hash
	if cur then
		for i = 1, #locks do
			if locks[i].hash == cur then
				return locks[i]
			end
		end
		watch.primary_hash = nil
	end
	if #locks > 0 then
		watch.primary_hash = locks[1].hash
		return locks[1]
	end
	return nil
end

local function make_track(ent, hash, cam_pos)
	return {
		hash = hash,
		ent = ent,
		phase = TRACK.SPAWN,
		age = 0,
		life = 0,
		spawn_t = 0,
		travel_t = 0,
		land_t = 0,
		confirm_t = 0,
		fade_t = 0,
		retract_t = 0,
		start_pos = Vector(cam_pos.X, cam_pos.Y),
		ratio = 0,
		filtered_target_pos = nil,
		-- 敌人全程用 TR 方框四角；中心瞄准准星 = 已锁死待轰炸标记
		sprite = new_sprite(item.target_anm2, "Lock"),
		_anim = "Lock",
		aim_sprite = nil,
		confirmed = false,
		locked_t = 0,
	}
end

local function update_track_filter(tr, ent, offset)
	if not auxi.check_all_exists(ent) then
		return tr.filtered_target_pos
	end
	local raw = raw_lock_render_pos(ent, offset, tr.is_player == true)
	tr.filtered_target_pos = filter_pos(tr.filtered_target_pos, raw, item.lock_filter_rate)
	return tr.filtered_target_pos
end

-- 判决已下：确保敌人进入 pending_blast，准星才能钉到真实爆炸
local function ensure_enemy_pending_blast(tr)
	local ent = tr and tr.ent
	if not auxi.check_all_exists(ent) then return end
	local d2 = ent:GetData()
	if d2[item.own_key.."pending_blast"] then return end
	local fx = d2[item.own_key.."effect"]
	local player = (fx and fx.player) or auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
	d2[item.own_key.."pending_blast"] = {
		frame = 0,
		player = player,
	}
	d2[item.own_key.."effect"] = nil
end

local function begin_confirm(tr, opts)
	tr.phase = TRACK.CONFIRM
	tr.confirm_t = 0
	tr.confirmed = true
	-- CLICK：方框合死 + 中心瞄准准星出现 = 已锁定、待轰炸
	play_anim(tr.sprite, "Lock", true, tr)
	if not tr.aim_sprite then
		tr.aim_sprite = new_sprite(item.target_anm2, "Track")
	end
	play_anim(tr.aim_sprite, "Track", true, tr)
	tr._aim_anim = "Track"
	play_lock_click(0.55, 1.15)
	-- 地面底座用自有弱爆计时，不走持有后的 pending_blast
	if not (opts and opts.skip_pending_blast) then
		ensure_enemy_pending_blast(tr)
	end
end

local function begin_locked(tr, opts)
	tr.phase = TRACK.LOCKED
	tr.locked_t = 0
	play_anim(tr.sprite, "Lock", false, tr)
	if not tr.aim_sprite then
		tr.aim_sprite = new_sprite(item.target_anm2, "Track")
	end
	play_anim(tr.aim_sprite, "Track", false, tr)
	if not (opts and opts.skip_pending_blast) then
		ensure_enemy_pending_blast(tr)
	end
end

-- 爆炸发生后的击中淡出（不是 Confirm 后的立刻消失）
local function begin_fade(tr)
	tr.phase = TRACK.FADE
	tr.fade_t = 0
	play_anim(tr.sprite, "Lock", false, tr)
	if tr.aim_sprite then
		play_anim(tr.aim_sprite, "Track", false, tr)
	end
end

local function begin_retract(tr, end_pos)
	if track_is_fire_locked(tr) or tr.phase == TRACK.SHATTER then
		return
	end
	if tr.phase == TRACK.RETRACT then
		return
	end
	tr.phase = TRACK.RETRACT
	tr.retract_t = 0
	tr.end_reason = "lost"
	if end_pos then
		tr.retract_from = Vector(end_pos.X, end_pos.Y)
	elseif tr.filtered_target_pos then
		tr.retract_from = Vector(tr.filtered_target_pos.X, tr.filtered_target_pos.Y)
	end
	tr.retract_scale = item.enemy_display_scale
	tr.retract_progress = tr.ratio or 0
end

-- 目标死亡：碎散淡出（与“飞回摄像头”语义分离）
local function begin_shatter(tr)
	-- 已锁死阶段：目标死亡也只走击中淡出，不收回/不清准星语义
	if track_is_fire_locked(tr) then
		if tr.phase ~= TRACK.FADE then
			begin_fade(tr)
		end
		return
	end
	if tr.phase == TRACK.SHATTER or tr.phase == TRACK.RETRACT then
		return
	end
	tr.phase = TRACK.SHATTER
	tr.shatter_t = 0
	tr.end_reason = "dead"
	tr.shatter_scale = item.enemy_display_scale
	tr.shatter_progress = tr.ratio or 0
	tr.aim_sprite = nil
end

-- 返回 true = 删除 track
local function tick_track_logic(tr, enemy_ratio, alive, force_retract)
	tr.age = (tr.age or 0) + 1
	tr.life = (tr.life or 0) + 1
	tr.ratio = enemy_ratio or tr.ratio or 0

	-- 硬 TTL：未锁死的残留清掉；已锁死可等到爆炸淡出
	if track_is_fire_locked(tr) then
		if (tr.life or 0) > (item.track_ttl + 180) then
			return true
		end
	elseif (tr.life or 0) > item.track_ttl then
		return true
	end

	if force_retract then
		begin_retract(tr)
	elseif not alive then
		begin_shatter(tr)
	end

	if tr.phase == TRACK.SPAWN then
		-- 敌人全程 TR 方框四角（张开态飞出）
		play_anim(tr.sprite, "Lock", false, tr)
		tr.spawn_t = (tr.spawn_t or 0) + 1
		if tr.spawn_t >= item.track_spawn_frames then
			tr.phase = TRACK.TRAVEL
			tr.travel_t = 0
			tr._capture_start = true
		end
	elseif tr.phase == TRACK.TRAVEL then
		play_anim(tr.sprite, "Lock", false, tr)
		tr.travel_t = (tr.travel_t or 0) + 1
		if tr.travel_t >= item.track_travel_frames then
			tr.phase = TRACK.LAND
			tr.land_t = 0
		end
	elseif tr.phase == TRACK.LAND then
		play_anim(tr.sprite, "Lock", false, tr)
		tr.land_t = (tr.land_t or 0) + 1
		if tr.land_t >= item.track_land_frames then
			tr.phase = TRACK.LOCK
		end
	elseif tr.phase == TRACK.LOCK then
		play_anim(tr.sprite, "Lock", false, tr)
		if (tr.ratio or 0) >= 0.999 then
			begin_confirm(tr)
		end
	elseif tr.phase == TRACK.CONFIRM then
		-- 短确认动画：准星弹出；随后进入 LOCKED 常驻
		play_anim(tr.sprite, "Lock", false, tr)
		if tr.aim_sprite then
			play_anim(tr.aim_sprite, "Track", false, tr)
		end
		tr.confirm_t = (tr.confirm_t or 0) + 1
		ensure_enemy_pending_blast(tr)
		if tr.confirm_t >= item.track_confirm_frames then
			begin_locked(tr)
		end
	elseif tr.phase == TRACK.LOCKED then
		-- 中心准星钉住敌人，直到 pending_blast 真正爆炸
		play_anim(tr.sprite, "Lock", false, tr)
		if tr.aim_sprite then
			play_anim(tr.aim_sprite, "Track", false, tr)
		end
		tr.locked_t = (tr.locked_t or 0) + 1
		ensure_enemy_pending_blast(tr)
		local blasted = false
		if auxi.check_all_exists(tr.ent) then
			local blast = tr.ent:GetData()[item.own_key.."pending_blast"]
			if blast and (blast.frame or 0) >= (item.enemy_blast_explode_frame or 12) then
				blasted = true
			elseif not blast and (tr.locked_t or 0) > 2 and not tr.ent:GetData()[item.own_key.."effect"] then
				-- blast 已结算完毕（刚炸完被清掉）
				blasted = true
			end
		else
			blasted = true
		end
		if blasted then
			begin_fade(tr)
		end
	elseif tr.phase == TRACK.FADE then
		-- 爆炸后的强闪/淡出
		play_anim(tr.sprite, "Lock", false, tr)
		if tr.aim_sprite then
			play_anim(tr.aim_sprite, "Track", false, tr)
		end
		tr.fade_t = (tr.fade_t or 0) + 1
		if tr.fade_t >= item.track_fade_frames then
			return true
		end
	elseif tr.phase == TRACK.RETRACT then
		-- 丢失：方框张开飞回；清掉未确认的瞄准叠加
		tr.aim_sprite = nil
		play_anim(tr.sprite, "Lock", false, tr)
		tr.retract_t = (tr.retract_t or 0) + 1
		if tr.retract_t >= item.track_retract_frames then
			return true
		end
	elseif tr.phase == TRACK.SHATTER then
		tr.aim_sprite = nil
		play_anim(tr.sprite, "Lock", false, tr)
		tr.shatter_t = (tr.shatter_t or 0) + 1
		if tr.shatter_t >= item.track_shatter_frames then
			return true
		end
	end
	return false
end

local function eval_track_visual(tr, cam_pos, end_pos)
	local ratio = clamp01(tr.ratio or 0)
	if tr.phase == TRACK.SPAWN then
		local t = clamp01((tr.spawn_t or 0) / item.track_spawn_frames)
		return Vector(cam_pos.X, cam_pos.Y), lerp(0.45, 0.75, t), lerp(0.4, 0.85, t), 0
	elseif tr.phase == TRACK.TRAVEL then
		if tr._capture_start or not tr.start_pos then
			tr.start_pos = Vector(cam_pos.X, cam_pos.Y)
			tr._capture_start = false
		end
		local t = clamp01((tr.travel_t or 0) / item.track_travel_frames)
		local te = ease_out_cubic(t)
		local base = lerp_vec(tr.start_pos, end_pos, te)
		local arc = math.sin(math.pi * t) * item.track_arc_px
		return base + Vector(0, -arc), lerp(0.75, item.enemy_scale_hi, te), 0.95, 0
	elseif tr.phase == TRACK.LAND then
		local t = clamp01((tr.land_t or 0) / item.track_land_frames)
		local sc = lerp(item.enemy_scale_hi * 0.95, item.enemy_display_scale, ease_out_cubic(t))
		return Vector(end_pos.X, end_pos.Y), sc, 1, ratio
	elseif tr.phase == TRACK.LOCK then
		local pos = Vector(end_pos.X, end_pos.Y)
		local sc = item.enemy_display_scale
		local al = lock_alpha(ratio)
		-- 高进度轻颤：仍表示“可逃/未锁死”，但不靠缩小表达进度
		if ratio >= 0.8 then
			local shake = math.min(0.7, 0.15 + (ratio - 0.8) * 0.9)
			local tt = (tr.age or 0) * 1.3
			pos = pos + Vector(math.sin(tt * 3.1) * shake, math.cos(tt * 2.4) * shake)
			al = al * (0.88 + 0.12 * (0.5 + 0.5 * math.sin(tt * 4.2)))
		end
		return pos, sc, al, ratio
	elseif tr.phase == TRACK.CONFIRM then
		local t = clamp01((tr.confirm_t or 0) / item.track_confirm_frames)
		local sc = item.enemy_display_scale * lerp(1.0, 1.08, math.sin(t * math.pi))
		return Vector(end_pos.X, end_pos.Y), sc, 1, 1
	elseif tr.phase == TRACK.LOCKED then
		local pos = Vector(end_pos.X, end_pos.Y)
		local pulse = 0.5 + 0.5 * math.sin((tr.locked_t or 0) * 0.35)
		local sc = item.enemy_display_scale * (1.0 + 0.03 * pulse)
		return pos, sc, 0.92 + 0.08 * pulse, 1
	elseif tr.phase == TRACK.FADE then
		local t = smoothstep((tr.fade_t or 0) / item.track_fade_frames)
		-- 爆炸时准星先微扩再淡出
		local sc = item.enemy_display_scale * lerp(1.08, 1.35, t)
		return Vector(end_pos.X, end_pos.Y), sc, 1 - t, 1
	elseif tr.phase == TRACK.RETRACT then
		-- LOST：先张开四角，再完整飞回摄像头（不是原地淡掉）
		local t = smoothstep((tr.retract_t or 0) / item.track_retract_frames)
		local from = tr.retract_from or end_pos
		local open_t = clamp01(t / 0.22)
		local fly_t = clamp01((t - 0.15) / 0.85)
		local pos = lerp_vec(from, cam_pos, ease_out_cubic(fly_t))
		local sc0 = tr.retract_scale or item.enemy_display_scale
		local sc = lerp(sc0, sc0 * 0.62, fly_t)
		local al = 1 - fly_t * fly_t
		local prog = lerp(tr.retract_progress or ratio, 0, open_t)
		return pos, sc, al, prog
	elseif tr.phase == TRACK.SHATTER then
		local t = smoothstep((tr.shatter_t or 0) / item.track_shatter_frames)
		local pos = Vector(end_pos.X, end_pos.Y)
		local sc = (tr.shatter_scale or item.enemy_display_scale) * lerp(1.0, 1.45, t)
		return pos, sc, 1 - t, tr.shatter_progress or ratio
	end
	return Vector(cam_pos.X, cam_pos.Y), 1, 0, 0
end

local function retract_incomplete_tracks(watch)
	if not watch or not watch.tracks then return end
	for _, tr in pairs(watch.tracks) do
		-- 已锁死/淡出允许演完；其它未完成全部收回
		if not track_is_fire_locked(tr) then
			begin_retract(tr)
		end
	end
end

local function sync_enemy_tracks_update(watch, opts)
	opts = opts or {}
	ensure_fx(watch)
	watch.tracks = watch.tracks or {}
	local freeze = opts.freeze == true
	local allow_spawn = (opts.allow_spawn ~= false) and not freeze
	local force_retract = opts.force_retract_incomplete == true
	local player = opts.player
	local acq = opts.acq or opts.range or item.distance
	local ret = opts.ret or retention_range(acq)
	local locks = collect_active_enemies()
	local by_hash = {}
	for i = 1, #locks do
		by_hash[locks[i].hash] = locks[i]
	end

	if allow_spawn then
		local n_active = 0
		for i = 1, #locks do
			if n_active >= item.max_fork_targets then break end
			local L = locks[i]
			local tr = watch.tracks[L.hash]
			local dist = 0
			local in_acq = true
			local in_ret = true
			if player and auxi.check_all_exists(L.ent) then
				dist = (L.ent.Position - player.Position):Length()
				in_acq = dist <= acq
				in_ret = dist <= ret
			end
			-- 已锁死/淡出中的 track 不再被重建抢占，也不因超范围撤销
			if tr and track_is_fire_locked(tr) then
				tr.ent = L.ent
				tr.ratio = 1
				n_active = n_active + 1
			elseif tr and not in_ret then
				-- 已有锁定：超出 retention 才收回
				tr.ent = L.ent
				tr.ratio = L.ratio
				begin_retract(tr, tr.filtered_target_pos)
			elseif not tr then
				-- 新准星：必须在 acquisition 内；已排队轰炸的不再生新框
				if in_acq and not L.pending then
					watch.tracks[L.hash] = make_track(L.ent, L.hash, Vector(0, 0))
					tr = watch.tracks[L.hash]
					tr._capture_start = true
					n_active = n_active + 1
				end
			else
				tr.ent = L.ent
				n_active = n_active + 1
			end
		end
	else
		for hash, tr in pairs(watch.tracks) do
			local L = by_hash[hash]
			if L then
				tr.ent = L.ent
				tr.ratio = L.ratio
			end
		end
	end

	if force_retract then
		retract_incomplete_tracks(watch)
	end

	-- 已有 track：超出 retention 才柔和消失；短闪冻结时不因距离撤回
	if player and not freeze and not force_retract then
		for _, tr in pairs(watch.tracks) do
			if (not track_is_fire_locked(tr)) and tr.phase ~= TRACK.RETRACT then
				if auxi.check_all_exists(tr.ent) then
					if (tr.ent.Position - player.Position):Length() > ret then
						begin_retract(tr, tr.filtered_target_pos)
					end
				end
			end
		end
	end

	local remove = {}
	for hash, tr in pairs(watch.tracks) do
		local L = by_hash[hash]
		local alive = L ~= nil and auxi.check_all_exists(tr.ent) and not tr.ent:IsDead()
		local ratio = L and L.ratio or tr.ratio or 0
		-- 已锁死阶段后不再依赖敌人 effect 存活，也不因超范围撤回
		if track_is_fire_locked(tr) then
			alive = true
			ratio = 1
		elseif tr.phase == TRACK.RETRACT then
			alive = true
		end
		if tick_track_logic(tr, ratio, alive, false) then
			remove[#remove + 1] = hash
		end
	end
	for i = 1, #remove do
		watch.tracks[remove[i]] = nil
	end
	return locks
end

local function render_tracks(watch, cam_pos, offset)
	if not watch or not watch.tracks then return end
	for _, tr in pairs(watch.tracks) do
		if tr.sprite then
			local end_pos = cam_pos
			if auxi.check_all_exists(tr.ent) then
				end_pos = update_track_filter(tr, tr.ent, offset) or cam_pos
			elseif tr.filtered_target_pos then
				end_pos = tr.filtered_target_pos
			end
			local pos, sc, al, prog = eval_track_visual(tr, cam_pos, end_pos)
			if (al or 0) > 0.02 then
				-- 方框=正在锁定；中心准星=已锁死待轰炸（Confirm/Locked/爆炸淡出）
				local gap_mul = (tr.phase == TRACK.RETRACT) and 1.35 or 1
				local bracket_prog = prog or tr.ratio or 0
				if tr.phase == TRACK.SPAWN or tr.phase == TRACK.TRAVEL then
					bracket_prog = 0
				elseif track_is_fire_locked(tr) then
					bracket_prog = 1
				elseif tr.phase == TRACK.SHATTER then
					bracket_prog = tr.shatter_progress or bracket_prog
				end
				local tint = nil
				if track_is_fire_locked(tr) then
					tint = {r = 1, g = 0.85, b = 0.75, ro = 0.2, go = 0.04, bo = 0}
				end
				local bracket_al = al
				if tr.phase == TRACK.LOCKED then
					bracket_al = al * 0.55
				elseif tr.phase == TRACK.FADE then
					bracket_al = al * 0.35
				end
				render_bracket_reticle(
					tr.sprite, pos, sc or item.enemy_display_scale, bracket_al, tint,
					bracket_prog,
					item.enemy_corner_gap_open, item.enemy_corner_gap_closed,
					{base_alpha = 0.10, gap_mul = gap_mul}
				)
				if track_is_fire_locked(tr) and tr.aim_sprite then
					local aim_sc = (sc or item.enemy_display_scale) * 0.92
					if tr.phase == TRACK.CONFIRM then
						local t = clamp01((tr.confirm_t or 0) / math.max(1, item.track_confirm_frames))
						aim_sc = aim_sc * lerp(0.7, 1.08, math.sin(clamp01(t * 1.2) * math.pi * 0.5))
					elseif tr.phase == TRACK.LOCKED then
						local pulse = 0.5 + 0.5 * math.sin((tr.locked_t or 0) * 0.45)
						aim_sc = aim_sc * (0.96 + 0.06 * pulse)
					elseif tr.phase == TRACK.FADE then
						local t = clamp01((tr.fade_t or 0) / math.max(1, item.track_fade_frames))
						aim_sc = aim_sc * lerp(1.1, 1.45, t)
					end
					render_sprite(tr.aim_sprite, pos, aim_sc, al, tint)
				end
			end
		end
	end
end

-- 自身：Surveillance Ring —— 不飞、不切多档贴图，只淡入+连续收缩
local function ensure_self_spr(watch)
	if not watch.self_spr then
		watch.self_spr = new_sprite(item.self_anm2, "Watch")
		watch._self_anim = "Watch"
	end
	return watch.self_spr
end

local function tick_self_reticle(watch, ratio)
	if ratio <= 0.05 then
		watch.self_fade_t = 0
		watch.self_ready = false
		if watch.phase == PHASE.CONFIRMING or watch.self_confirm_t ~= nil then
			cancel_confirming(watch)
		else
			watch.self_confirm_t = nil
		end
		watch.self_filtered_pos = nil
		return
	end
	if not watch.self_ready then
		watch.self_fade_t = (watch.self_fade_t or 0) + 1
		if watch.self_fade_t >= item.self_fade_in_frames then
			watch.self_ready = true
		end
	end
end

local function begin_player_confirming(watch, player)
	watch.phase = PHASE.CONFIRMING
	watch.self_confirm_t = 0
	snapshot_frozen_acq(watch, auxi.should_do_Seija(player, true))
	ensure_self_spr(watch)
	play_anim(watch.self_spr, "Confirm", true, watch)
	watch.self_ready = true
end

local function advance_player_confirming(watch, player, d)
	watch.self_confirm_t = (watch.self_confirm_t or 0) + 1
	watch.self_ready = true
	if (watch.self_confirm_t or 0) < item.self_confirm_frames then
		return
	end
	-- FIRING 一旦进入不可取消：停抖本身 = LOCKED，必须立刻给出 click/闪光/准星锁死
	snapshot_frozen_acq(watch, auxi.should_do_Seija(player, true))
	watch.phase = PHASE.FIRING
	watch.counter = 0
	watch.self_confirm_t = nil
	watch.lock_flash_t = item.lock_flash_frames
	play_lock_click(1.0, 0.85)
	local shoot = d[item.own_key.."shoot"] or {frame = 0}
	d[item.own_key.."shoot"] = shoot
	shoot.sprite = watch.sprite
	shoot.frame = 0
	shoot.lock_flash_t = item.lock_flash_frames
	play_body(shoot, "Shoot", true)
end

local function render_self_reticle(watch, player, offset, ratio, opts)
	opts = opts or {}
	if ratio <= 0.05 and not opts.force and not opts.closing then return end
	local spr = ensure_self_spr(watch)
	local raw = raw_lock_render_pos(player, offset, true)
	watch.self_filtered_pos = filter_pos(watch.self_filtered_pos, raw, item.lock_filter_rate)
	local pos = Vector(watch.self_filtered_pos.X, watch.self_filtered_pos.Y)
	local sc = item.self_display_scale
	local al = 1
	local prog = clamp01(ratio)
	local warn_tint = nil

	if opts.firing then
		-- LOCKED：切到完整 X（TL），整图缩放撞击；不再裁四角
		play_anim(spr, "Confirm", (opts.fire_age or 0) <= 1, watch)
		local age = opts.fire_age or 0
		local punch = 1
		if age < 5 then
			punch = lerp(0.78, 1.18, age / 5)
		elseif age < 10 then
			punch = lerp(1.18, 1.0, (age - 5) / 5)
		end
		sc = item.self_display_scale * punch
		al = 1
		warn_tint = {r = 1, g = 0.55, b = 0.55, ro = 0.55, go = 0, bo = 0}
		if age < (item.lock_flash_frames or 10) then
			local flash = 1 - age / (item.lock_flash_frames or 10)
			warn_tint = {r = 1, g = 1 - 0.55 * flash, b = 1 - 0.65 * flash, ro = 0.85 * flash, go = 0.1 * flash, bo = 0.1 * flash}
		end
		if age > item.shoot_explode_frame - 4 then
			al = math.max(0, 1 - (age - (item.shoot_explode_frame - 4)) / 8)
		end
		render_sprite(spr, pos, sc, al, warn_tint)
		return
	elseif opts.confirming then
		-- 仍可逃：BL 十字四角已合拢 + 强抖；尚未换成 X
		play_anim(spr, "Watch", false, watch)
		local age = opts.confirm_age or 0
		prog = 1
		local _, blink = critical_warn(1, watch.age or age, true)
		local shake = 1.6 + 0.7 * blink
		local tt = (watch.age or 0) * 1.55
		pos = pos + Vector(math.sin(tt * 3.4) * shake, math.cos(tt * 2.9) * shake * 0.75)
		pos = pos + Vector(math.sin(tt * 8.2) * shake * 0.4, math.cos(tt * 7.1) * shake * 0.35)
		al = 0.75 + 0.25 * (0.5 + 0.5 * math.sin(tt * 5.5))
		warn_tint = critical_tint(0.55 + 0.45 * blink)
		render_bracket_reticle(
			spr, pos, sc, al, warn_tint, prog,
			item.self_corner_gap_open, item.self_corner_gap_closed,
			{base_alpha = 0.22}
		)
		return
	elseif opts.closing then
		play_anim(spr, "Watch", false, watch)
		local t = clamp01((opts.close_age or 0) / item.close_fade_frames)
		local fade = smoothstep(t)
		al = lock_alpha(ratio) * (1 - fade)
		prog = lerp(ratio, 0, fade)
		render_bracket_reticle(
			spr, pos, sc * (1 - 0.15 * fade), al, nil, prog,
			item.self_corner_gap_open, item.self_corner_gap_closed,
			{base_alpha = 0.2, gap_mul = 1 + 0.4 * fade}
		)
		return
	end

	-- 监视中：BL 十字四角随进度合拢
	play_anim(spr, "Watch", false, watch)
	local fade = clamp01((watch.self_fade_t or 0) / item.self_fade_in_frames)
	if not watch.self_ready then
		sc = lerp(item.self_display_scale * 1.08, item.self_display_scale, ease_out_cubic(fade))
		al = lerp(0, 0.7, fade)
		prog = 0
	else
		al = lock_alpha(ratio)
		if ratio >= 0.8 then
			local danger, blink = critical_warn(ratio, watch.age)
			local shake = 0.85 + danger * 1.7 + blink * 0.9
			local tt = (watch.age or 0) * 1.45
			pos = pos + Vector(math.sin(tt * 3.2) * shake, math.cos(tt * 2.6) * shake * 0.8)
			pos = pos + Vector(math.sin(tt * 7.8) * shake * 0.35, math.cos(tt * 6.6) * shake * 0.3)
			al = al * (0.7 + 0.3 * (0.5 + 0.5 * math.sin(tt * 5.2)))
			warn_tint = critical_tint(blink)
		end
	end
	render_bracket_reticle(
		spr, pos, sc, al, warn_tint, prog,
		item.self_corner_gap_open, item.self_corner_gap_closed,
		{base_alpha = 0.22}
	)
end

local function ensure_player_watch(d)
	d[item.own_key.."watch"] = d[item.own_key.."watch"] or {
		phase = PHASE.DORMANT,
		counter = 0,
		slow_streak = 0,
		safe_streak = 0,
		age = 0,
		body_alpha = 0,
		eye_rot = 0,
		tracks = {},
	}
	return ensure_fx(d[item.own_key.."watch"])
end

local function player_ratio(watch)
	return clamp01((watch.counter or 0) / item.player_limit)
end

-- 关闭淡出：前段多留一点实体感（配合闭眼），后段 smoothstep 溶掉
local function close_body_alpha(age)
	local t = clamp01((age or 0) / item.close_fade_frames)
	local u = clamp01((t - 0.12) / 0.88)
	return 1 - smoothstep(u)
end

local function close_body_scale(age)
	local t = clamp01((age or 0) / item.close_fade_frames)
	return lerp(1, 0.78, ease_out_cubic(t))
end

local function begin_closing(watch)
	if not watch then return end
	if watch.phase == PHASE.CLOSING then return end
	if watch.phase == PHASE.CONFIRMING or watch.self_confirm_t ~= nil then
		cancel_confirming(watch)
	else
		clear_frozen_acq(watch)
	end
	watch.phase = PHASE.CLOSING
	watch.close_age = 0
	watch.close_scale = 1
	watch.self_fade_t = 0
	watch.self_ready = false
	watch.halo_target = 0
	retract_incomplete_tracks(watch)
	play_body(watch, "Close", true)
end

local function decay_incomplete_enemy_meters()
	for _, v in pairs(auxi.getenemies()) do
		if auxi.check_all_exists(v) then
			local d2 = v:GetData()
			if not d2[item.own_key.."pending_blast"] then
				local fx = d2[item.own_key.."effect"]
				if fx then
					local lim = fx.limit or item.enemy_limit
					if (fx.counter or 0) < lim then
						fx.counter = math.max(0, (fx.counter or 0) - item.closing_enemy_decay)
						if (fx.counter or 0) <= 0 then
							d2[item.own_key.."effect"] = nil
						end
					end
				end
			end
		end
	end
end

local function clear_incomplete_tracks(watch)
	if not watch or not watch.tracks then return end
	local remove = {}
	for hash, tr in pairs(watch.tracks) do
		-- 让已锁死/淡出/收回演完
		if (not track_is_fire_locked(tr)) and tr.phase ~= TRACK.RETRACT then
			remove[#remove + 1] = hash
		end
	end
	for i = 1, #remove do
		watch.tracks[remove[i]] = nil
	end
end

-- 换房：硬清准星屏幕坐标，避免上一房 filtered 位置插值飞回
local function wipe_watch_reticles(watch)
	if not watch then return end
	watch.tracks = {}
	watch.primary_hash = nil
	watch.self_filtered_pos = nil
	watch.self_fade_t = 0
	watch.self_ready = false
	watch.self_confirm_t = nil
	clear_frozen_acq(watch)
end

local function tick_player_watch(player, d)
	local watch = ensure_player_watch(d)
	watch.age = (watch.age or 0) + 1
	local slow = player.Velocity:Length() <= item.safe_velocity
	local phase = watch.phase or PHASE.DORMANT

	if phase == PHASE.FIRING then
		watch.counter = 0
		watch.slow_streak = 0
		watch.safe_streak = 0
		return watch
	end

	if phase == PHASE.CLOSING then
		watch.sprite:Update()
		watch.close_age = (watch.close_age or 0) + 1
		watch.body_alpha = close_body_alpha(watch.close_age)
		watch.close_scale = close_body_scale(watch.close_age)
		watch.counter = math.max(0, (watch.counter or 0) - item.player_decay)
		watch.eye_rot = angle_lerp(watch.eye_rot or 0, 0, 0.28)
		tick_halo(watch, false)
		decay_incomplete_enemy_meters()
		sync_enemy_tracks_update(watch, {
			allow_spawn = false,
			force_retract_incomplete = true,
			player = player,
			acq = item.distance_min,
			ret = item.distance_min,
		})
		-- 等身体淡出走完，再等光环收尽；不要在 6~10 帧就掐断
		if watch.close_age >= item.close_fade_frames
			and (watch.halo_t or 0) <= 0.01
		then
			clear_incomplete_tracks(watch)
			watch.phase = PHASE.DORMANT
			watch.body_alpha = 0
			watch.close_scale = 1
			watch.counter = 0
			watch.slow_streak = 0
			watch.safe_streak = 0
			watch.close_age = 0
			watch.eye_rot = 0
			watch.primary_hash = nil
			watch.self_fade_t = 0
			watch.self_ready = false
			watch.self_filtered_pos = nil
			clear_frozen_acq(watch)
		end
		return watch
	end

	if slow then
		watch.safe_streak = 0
		watch.slow_streak = (watch.slow_streak or 0) + 1

		if phase == PHASE.DORMANT then
			watch.counter = math.min(item.player_limit, (watch.counter or 0) + item.awake_meter_rate)
			tick_halo(watch, false)
			if watch.slow_streak >= item.awake_grace then
				watch.phase = PHASE.AWAKE
				watch.appear_age = 0
				watch.body_alpha = 0.2
				play_body(watch, "Appear", true)
				tick_halo(watch, true)
			end
		elseif phase == PHASE.AWAKE then
			watch.sprite:Update()
			watch.appear_age = (watch.appear_age or 0) + 1
			watch.body_alpha = math.min(1, (watch.body_alpha or 0) + 0.2)
			watch.counter = math.min(item.player_limit, (watch.counter or 0) + item.awake_meter_rate)
			tick_halo(watch, true)
			if watch.sprite:IsFinished("Appear") or watch.appear_age >= 10 then
				watch.phase = PHASE.TRACKING
				play_body(watch, "Watching", true)
				watch.body_alpha = 1
			end
		elseif phase == PHASE.RELEASING then
			watch.phase = PHASE.TRACKING
			play_body(watch, "Watching", false)
			watch.body_alpha = 1
			watch.counter = math.min(item.player_limit, (watch.counter or 0) + 1)
			tick_halo(watch, true)
		elseif phase == PHASE.CONFIRMING then
			-- Confirm 必须连续保持危险：只推进确认计时，不再涨锁定
			watch.body_alpha = 1
			if watch.body_anim ~= "Watching" then
				play_body(watch, "Watching", true)
			end
			tick_halo(watch, true)
			advance_player_confirming(watch, player, d)
		else
			watch.counter = math.min(item.player_limit, (watch.counter or 0) + 1)
			watch.body_alpha = 1
			local ratio = player_ratio(watch)
			watch.phase = phase_from_ratio(ratio, PHASE.TRACKING)
			if watch.body_anim ~= "Watching" then
				play_body(watch, "Watching", true)
			end
			tick_halo(watch, true)
			if (watch.counter or 0) >= item.player_limit then
				begin_player_confirming(watch, player)
				advance_player_confirming(watch, player, d)
			else
				tick_self_reticle(watch, ratio)
				critical_tick_sound(watch, ratio)
			end
		end
	else
		watch.slow_streak = 0
		if phase == PHASE.DORMANT then
			watch.counter = math.max(0, (watch.counter or 0) - item.player_decay)
			tick_halo(watch, false)
			tick_self_reticle(watch, player_ratio(watch))
		elseif phase == PHASE.AWAKE then
			watch.phase = PHASE.RELEASING
			watch.safe_streak = 1
			-- 短闪缓冲内冻结自身进度
			play_body(watch, "Watching", false)
			tick_halo(watch, true)
		elseif phase == PHASE.CONFIRMING then
			-- 短闪可冻 0~99% 锁定，但不可保存“已扣扳机”的 Confirm
			cancel_confirming(watch)
			watch.phase = PHASE.RELEASING
			watch.safe_streak = 1
			watch.body_alpha = 1
			if watch.body_anim ~= "Watching" then
				play_body(watch, "Watching", false)
			end
			tick_halo(watch, true)
			tick_self_reticle(watch, player_ratio(watch))
		elseif phase == PHASE.TRACKING or phase == PHASE.WARNING or phase == PHASE.CRITICAL or phase == PHASE.RELEASING then
			watch.phase = PHASE.RELEASING
			watch.safe_streak = (watch.safe_streak or 0) + 1
			if watch.safe_streak > item.move_freeze_frames then
				watch.counter = math.max(0, (watch.counter or 0) - item.move_decay_per_frame)
			end
			watch.body_alpha = 1
			if watch.body_anim ~= "Watching" then
				play_body(watch, "Watching", false)
			end
			tick_halo(watch, true)
			local ratio = player_ratio(watch)
			tick_self_reticle(watch, ratio)
			-- 缓冲结束后再持有一小段，才真正闭眼
			if watch.safe_streak >= (item.move_freeze_frames + item.release_hold) and ratio <= 0.08 then
				begin_closing(watch)
			end
		end
	end

	return watch
end

local function ensure_enemy_fx(d2)
	d2[item.own_key.."effect"] = d2[item.own_key.."effect"] or {
		counter = 0,
		frame = 5,
		limit = item.enemy_limit,
		age = 0,
	}
	return d2[item.own_key.."effect"]
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = CacheFlag.CACHE_SPEED,
Function = function(_, player, cacheFlag)
	if cacheFlag == CacheFlag.CACHE_SPEED and auxi.has_have_coll(player, item.entity) then
		if player.MoveSpeed < item.min_speed then
			player.MoveSpeed = item.min_speed
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_, ent)
	local d = ent:GetData()
	if (d[item.own_key.."cooldown"] or 0) > 0 then
		d[item.own_key.."cooldown"] = d[item.own_key.."cooldown"] - 1
	end
	if d[item.own_key.."effect"] then
		local fx = d[item.own_key.."effect"]
		fx.age = (fx.age or 0) + 1
		fx.frame = (fx.frame or 0) - 1
		local lim = fx.limit or item.enemy_limit
		if (fx.counter or 0) > lim then
			d[item.own_key.."pending_blast"] = {
				frame = 0,
				player = fx.player or auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0),
			}
			d[item.own_key.."effect"] = nil
		elseif fx.frame <= 0 then
			fx.counter = math.max(0, (fx.counter or 0) - 5)
			if (fx.counter or 0) <= 0 then
				d[item.own_key.."effect"] = nil
			end
		end
	end
	if d[item.own_key.."pending_blast"] then
		local blast = d[item.own_key.."pending_blast"]
		blast.frame = (blast.frame or 0) + 1
		local explode_at = item.enemy_blast_explode_frame or 12
		if blast.frame == explode_at then
			local player = blast.player or auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
			Game():BombExplosionEffects(ent.Position, watcher_damage(player), TearFlags.TEAR_NORMAL, Color(1, 1, 1, 1, -1, -1, -1), player, 0.5, false, false, 0)
			d[item.own_key.."cooldown"] = ent:IsBoss() and item.boss_cooldown or item.enemy_cooldown
		end
		if blast.frame >= math.max(20, explode_at + 8) then
			d[item.own_key.."pending_blast"] = nil
		end
	end
end,
})

local function watch_needs_visual(watch, d)
	if not watch then return false end
	if d and d[item.own_key.."shoot"] then return true end
	local phase = watch.phase or PHASE.DORMANT
	if phase ~= PHASE.DORMANT then return true end
	if (watch.halo_t or 0) > 0.01 then return true end
	if watch.tracks then
		for _ in pairs(watch.tracks) do
			return true
		end
	end
	return false
end

local function get_valid_watcher_nil(watch)
	local ent = watch and watch.nil_ent
	-- Effect 不用 check_all_exists（IsDead 对特效不可靠）
	if not ent or not ent.Exists or not ent:Exists() then return nil end
	if ent.Type ~= EntityType.ENTITY_EFFECT then return nil end
	local variant = MEUS_NIL_VARIANT
	if variant and variant >= 0 and ent.Variant ~= variant then return nil end
	local nd = ent:GetData()
	if not nd[item.own_key.."cam"] then return nil end
	if watch.nil_ptr and GetPtrHash(ent) ~= watch.nil_ptr then
		return nil
	end
	watch.nil_ent = ent
	watch.nil_ptr = GetPtrHash(ent)
	return ent
end

local function release_watcher_nil(watch)
	local ent = watch and watch.nil_ent
	if ent and ent.Exists and ent:Exists() then
		local nd = ent:GetData()
		if nd[item.own_key.."cam"] then
			nd.removecd = 0
			nd[item.own_key.."cam"] = nil
			ent:Remove()
		end
	end
	if watch then
		watch.nil_ent = nil
		watch.nil_ptr = nil
	end
end

-- 视觉挂在 MeusNil 上，避开玩家无敌闪烁把摄像头/光环吃掉
local function ensure_watcher_nil(player, watch)
	if not watch then return nil end
	local ent = get_valid_watcher_nil(watch)
	if not ent then
		local variant = MEUS_NIL_VARIANT
		ent = Isaac.Spawn(
			EntityType.ENTITY_EFFECT,
			variant,
			0,
			player.Position,
			Vector(0, 0),
			player
		)
		if ent.ToEffect then
			ent = ent:ToEffect() or ent
		end
		ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
		ent.DepthOffset = item.nil_depth_offset
		ent.Visible = true
		-- 禁止 Scale=0 / 全透明：引擎可能跳过 Render 回调
		local spr = ent:GetSprite()
		spr.Color = Color(1, 1, 1, 0.01)
		spr.Scale = Vector(1, 1)
		local nd = ent:GetData()
		nd[item.own_key.."cam"] = true
		nd.nil_mode = "visual_only"
		nd.skip_nil_distance_cull = true
		nd.Params = nd.Params or {}
		nd.Params.player = player
		nd.removecd = 999999
		-- 跳过 Nil_holder 运动；渲染只走本模块 PRE/POST_EFFECT_RENDER
		nd[Nil_holder.own_key.."work"] = function() return true end
		watch.nil_ent = ent
		watch.nil_ptr = GetPtrHash(ent)
	end
	local nd = ent:GetData()
	nd.removecd = 999999
	nd.nil_mode = "visual_only"
	nd.skip_nil_distance_cull = true
	nd.Params = nd.Params or {}
	nd.Params.player = player
	nd[item.own_key.."cam"] = true
	nd[Nil_holder.own_key.."work"] = function() return true end
	ent.Visible = true
	ent.DepthOffset = item.nil_depth_offset
	-- 保持极低但不为 0 的 alpha，避免引擎整段跳过 Render
	local spr = ent:GetSprite()
	if spr then
		spr.Color = Color(1, 1, 1, 0.01)
		spr.Scale = Vector(1, 1)
	end
	ent.Position = player.Position
	ent.Velocity = player.Velocity
	watch.nil_ent = ent
	watch.nil_ptr = GetPtrHash(ent)
	return ent
end

local function maintain_watcher_nil(player, watch, d)
	if watch_needs_visual(watch, d) then
		ensure_watcher_nil(player, watch)
	else
		release_watcher_nil(watch)
	end
end

local function render_watcher_fx(player, watch, d, offset)
	if not watch then return end
	local cam = camera_head_pos(player, offset)

	if d[item.own_key.."shoot"] then
		local shoot = ensure_fx(d[item.own_key.."shoot"])
		local s = shoot.sprite
		s:SetFrame("Shoot", math.floor(shoot.frame or 0))
		local look = raw_lock_render_pos(player, offset, true)
		update_eye_look(shoot, cam, look)
		local recoil = 0
		local fr = shoot.frame or 0
		if fr < 8 then
			recoil = lerp(0, 2, fr / 8)
		elseif fr < 14 then
			recoil = lerp(2, 0, (fr - 8) / 6)
		end
		-- 视觉契约：shake=0 必须伴随 LOCKED 闪光，不能“安静后突然砰”
		local flash_t = fr
		local flash = 0
		if flash_t < (item.lock_flash_frames or 10) then
			flash = 1 - flash_t / (item.lock_flash_frames or 10)
		end
		local lock_tint = nil
		if flash > 0.02 then
			lock_tint = {
				r = 1,
				g = 1 - 0.35 * flash,
				b = 1 - 0.45 * flash,
				ro = 0.75 * flash,
				go = 0.12 * flash,
				bo = 0.08 * flash,
			}
		end
		-- 8~爆炸前：明显蓄力/后坐，让 Shoot 前摇可读
		if fr >= 8 and fr < item.shoot_explode_frame then
			local wind = (fr - 8) / math.max(1, item.shoot_explode_frame - 8)
			recoil = lerp(recoil, -1.8, wind * wind)
		end
		render_halo(watch, player, cam, offset, 1, flash * 0.85)
		render_camera(shoot, cam, {
			body_alpha = 1,
			shake = 0,
			eye_rot = shoot.eye_rot,
			recoil_y = recoil,
			tint = lock_tint,
			scale = (flash > 0) and lerp(1.08, 1.0, 1 - flash) or 1,
		})
		render_tracks(watch, cam, offset)
		render_self_reticle(watch, player, offset, 1, {
			force = true,
			firing = true,
			fire_age = fr,
		})
		return
	end

	local phase = watch.phase or PHASE.DORMANT
	local halo_vis = (watch.halo_t or 0) > 0.01
	local has_tracks = false
	if watch.tracks then
		for _ in pairs(watch.tracks) do
			has_tracks = true
			break
		end
	end
	if phase == PHASE.DORMANT and not halo_vis and not has_tracks then return end
	if (watch.body_alpha or 0) <= 0.02 and phase ~= PHASE.CLOSING and not halo_vis and not has_tracks then return end

	local ratio = player_ratio(watch)
	local show_self = phase == PHASE.TRACKING or phase == PHASE.WARNING
		or phase == PHASE.CRITICAL or phase == PHASE.CONFIRMING
		or phase == PHASE.RELEASING or phase == PHASE.CLOSING
		or watch.self_confirm_t ~= nil
	local show_enemy_tracks = show_self or phase == PHASE.FIRING or has_tracks

	local force_warn = phase == PHASE.CONFIRMING or watch.self_confirm_t ~= nil
	local danger, blink = critical_warn(ratio, watch.age, force_warn)
	local shake = 0
	if danger > 0 then
		shake = (0.95 + danger * 1.35 + blink * 0.7) * (force_warn and 1.15 or 1)
	end

	local locks = {}
	if show_enemy_tracks then
		locks = collect_active_enemies()
	end

	local primary = resolve_primary_target(watch, locks)
	local look = raw_lock_render_pos(player, offset, true)
	if primary and auxi.check_all_exists(primary.ent) then
		local tr = watch.tracks and watch.tracks[primary.hash]
		if tr and tr.filtered_target_pos then
			look = tr.filtered_target_pos
		else
			look = raw_lock_render_pos(primary.ent, offset, false)
		end
	end
	update_eye_look(watch, cam, look)

	local cam_tint = (blink > 0.02) and critical_tint(blink) or nil
	render_halo(watch, player, cam, offset, watch.body_alpha or 1, blink)

	if phase ~= PHASE.DORMANT and ((watch.body_alpha or 0) > 0.02 or phase == PHASE.CLOSING) then
		render_camera(watch, cam, {
			body_alpha = watch.body_alpha or 1,
			scale = watch.close_scale or 1,
			shake = shake,
			eye_rot = watch.eye_rot,
			tint = cam_tint,
		})
	end

	if show_enemy_tracks then
		render_tracks(watch, cam, offset)
	end
	if show_self and (ratio > 0.05 or phase == PHASE.CONFIRMING or watch.self_confirm_t) then
		if phase == PHASE.CONFIRMING or watch.self_confirm_t then
			render_self_reticle(watch, player, offset, 1, {
				force = true,
				confirming = true,
				confirm_age = watch.self_confirm_t or 0,
			})
		else
			render_self_reticle(watch, player, offset, ratio, {
				closing = phase == PHASE.CLOSING,
				close_age = watch.close_age or 0,
			})
		end
	end
end

local function resolve_watcher_player(ent, nd)
	local player = nd.Params and nd.Params.player
	if player and player.Exists and player:Exists() and player.ToPlayer then
		return player:ToPlayer() or player
	end
	local sp = ent.SpawnerEntity
	if sp and sp.ToPlayer then
		return sp:ToPlayer()
	end
	return nil
end

local function try_render_watcher_fx(ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return false
	end
	local nd = ent:GetData()
	if not nd[item.own_key.."cam"] then return nil end
	local player = resolve_watcher_player(ent, nd)
	if not player or not player.Exists or not player:Exists() then return false end
	if not auxi.has_have_coll(player, item.entity) then return false end
	local d = player:GetData()
	local watch = d[item.own_key.."watch"]
	if not watch then return false end
	if watch.nil_ptr and GetPtrHash(ent) ~= watch.nil_ptr then return false end

	watch.nil_ent = ent
	watch.nil_ptr = GetPtrHash(ent)
	render_watcher_fx(player, watch, d, offset or Vector(0, 0))
	-- PRE：取消 MeusNil 默认贴图；不要做“每帧只画一次”去重（双 Render 时会把真通道跳掉导致闪烁）
	return false
end

-- 位置/寿命放 UPDATE；渲染只在 RENDER（绝不在 Update 里画）
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = MEUS_NIL_VARIANT,
Function = function(_, ent)
	local nd = ent:GetData()
	if not nd[item.own_key.."cam"] then return end
	nd.removecd = 999999
	local player = resolve_watcher_player(ent, nd)
	if not player or not player.Exists or not player:Exists() then return end
	nd.Params = nd.Params or {}
	nd.Params.player = player
	ent.Position = player.Position
	ent.Velocity = player.Velocity
	local d = player:GetData()
	local watch = d[item.own_key.."watch"]
	if watch then
		watch.nil_ent = ent
		watch.nil_ptr = GetPtrHash(ent)
	end
end,
})

if ModCallbacks.MC_PRE_EFFECT_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_EFFECT_RENDER, params = MEUS_NIL_VARIANT,
	Function = function(_, ent, offset)
		return try_render_watcher_fx(ent, offset)
	end,
	})
else
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = MEUS_NIL_VARIANT,
	Function = function(_, ent, offset)
		try_render_watcher_fx(ent, offset)
	end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and auxi.has_have_coll(player, item.entity) then
			local d = player:GetData()
			wipe_watch_reticles(d[item.own_key.."watch"])
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	local d = player:GetData()
	if not auxi.has_have_coll(player, item.entity) then
		if d[item.own_key.."watch"] then
			release_watcher_nil(d[item.own_key.."watch"])
		end
		return
	end
	if Game():IsPaused() then return end

	if d[item.own_key.."shoot"] then
		local shoot = d[item.own_key.."shoot"]
		shoot.frame = (shoot.frame or 0) + 1
		local watch = ensure_player_watch(d)
		watch.phase = PHASE.FIRING
		watch.counter = 0
		tick_halo(watch, shoot.frame < item.shoot_explode_frame)
		local seija = auxi.should_do_Seija(player, true)
		local acq, ret = surveillance_ranges(watch, seija)
		sync_enemy_tracks_update(watch, {
			allow_spawn = false,
			force_retract_incomplete = false,
			player = player,
			acq = acq,
			ret = ret,
		})
		if shoot.frame == item.shoot_explode_frame then
			local damage_source = not auxi.should_do_Seija(player, true)
			Game():BombExplosionEffects(player.Position, watcher_damage(player), TearFlags.TEAR_NORMAL, Color(1, 1, 1, 1, -1, -1, -1), player, 0.5, false, damage_source)
		end
		if shoot.frame >= item.shoot_end_frame then
			d[item.own_key.."shoot"] = nil
			clear_incomplete_tracks(watch)
			watch.slow_streak = 0
			watch.safe_streak = 0
			watch.primary_hash = nil
			watch.self_fade_t = 0
			watch.self_ready = false
			watch.self_filtered_pos = nil
			watch.self_confirm_t = nil
			-- 射击结束后走关闭淡出，不要直接掐掉摄像头
			begin_closing(watch)
		end
	else
		tick_player_watch(player, d)
		local watch = d[item.own_key.."watch"]
		if watch then
			local phase = watch.phase
			local seija = auxi.should_do_Seija(player, true)
			local acq, ret = surveillance_ranges(watch, seija)
			if camera_can_spawn_tracks(phase) then
				sync_enemy_tracks_update(watch, {
					allow_spawn = true,
					player = player,
					acq = acq,
					ret = ret,
				})
			elseif camera_is_move_freeze(watch) then
				-- 短闪：保留已有准星，不新建、不因距离撤回
				sync_enemy_tracks_update(watch, {
					allow_spawn = false,
					freeze = true,
					player = player,
					acq = acq,
					ret = ret,
				})
			elseif camera_is_move_decay(watch) then
				-- 持续跑路：未完成准星开始收回
				sync_enemy_tracks_update(watch, {
					allow_spawn = false,
					force_retract_incomplete = true,
					player = player,
					acq = acq,
					ret = ret,
				})
			elseif phase == PHASE.AWAKE then
				sync_enemy_tracks_update(watch, {
					allow_spawn = false,
					player = player,
					acq = acq,
					ret = ret,
				})
			elseif phase == PHASE.DORMANT then
				tick_halo(watch, false)
				clear_incomplete_tracks(watch)
				if watch.tracks then
					sync_enemy_tracks_update(watch, {
						allow_spawn = false,
						player = player,
						acq = acq,
						ret = ret,
					})
				end
			end
		end
	end

	local watch = d[item.own_key.."watch"]
	local phase = watch and watch.phase or PHASE.DORMANT
	local seija = auxi.should_do_Seija(player, true)
	local acq, ret = surveillance_ranges(watch, seija)

	if camera_can_accumulate(phase) and watch then
		local selected, _, out_of_ret = pick_active_lock_targets(player, watch, acq, ret, true)
		for i = 1, #selected do
			local c = selected[i]
			-- Seija 全房仍套距离倍率；超出设计最大半径时保底最远档，避免远处锁速归零
			local mul = lock_speed_mul(c.dist)
			if seija and mul <= 0 then
				mul = 0.45
			end
			if mul > 0 then
				local fx = ensure_enemy_fx(c.d2)
				fx.counter = (fx.counter or 0) + mul
				fx.player = player
				fx.frame = 5
				fx.limit = item.enemy_limit
			end
		end
		for i = 1, #out_of_ret do
			local c = out_of_ret[i]
			local fx = c.d2[item.own_key.."effect"]
			if fx and not c.d2[item.own_key.."pending_blast"] then
				local lim = fx.limit or item.enemy_limit
				if (fx.counter or 0) < lim then
					fx.counter = math.max(0, (fx.counter or 0) - 8)
					fx.frame = 0
					if (fx.counter or 0) <= 0 then
						c.d2[item.own_key.."effect"] = nil
					end
				end
			end
		end
	elseif camera_is_move_freeze(watch) then
		-- 短闪：敌人锁定进度冻结（不增不减）
	elseif camera_is_move_decay(watch) then
		for _, v in pairs(auxi.getenemies()) do
			local d2 = v:GetData()
			local fx = d2[item.own_key.."effect"]
			if fx and not d2[item.own_key.."pending_blast"] then
				local lim = fx.limit or item.enemy_limit
				if (fx.counter or 0) < lim then
					fx.counter = math.max(0, (fx.counter or 0) - item.move_decay_per_frame)
					fx.frame = 0
					if (fx.counter or 0) <= 0 then
						d2[item.own_key.."effect"] = nil
					end
				end
			end
		end
	end

	-- 摄像头/准星/光环改由 MeusNil 渲染，避开玩家无敌闪烁
	maintain_watcher_nil(player, d[item.own_key.."watch"], d)
end,
})


-- ============================================================
-- 地面底座：简化中立监视（无摄像头，仅光圈 + 单目标准星）
-- ============================================================
local PED = {
	IDLE = "IDLE",
	LOCK = "LOCK",
	CONFIRM = "CONFIRM",
	LOCKED = "LOCKED",
	FADE = "FADE",
	COOLDOWN = "COOLDOWN",
}

local function pedestal_center_world(pickup)
	-- Halo_Watcher pivot=72,72（贴图正中）；对准道具贴图中心，而非底座脚底
	return pickup.Position + Vector(0, -(item.pedestal_center_lift or 14))
end

local function clear_pedestal_track(ped)
	if not ped then return end
	ped.track = nil
	ped.target_hash = nil
end

local function find_pedestal_target(origin, range)
	local best_ent, best_d, best_is_player = nil, range, false
	local game = Game()
	for i = 0, game:GetNumPlayers() - 1 do
		local pl = game:GetPlayer(i)
		if auxi.check_all_exists(pl) and not pl:IsDead() then
			local dist = origin:Distance(pl.Position)
			if dist <= best_d then
				best_d = dist
				best_ent = pl
				best_is_player = true
			end
		end
	end
	for _, e in pairs(auxi.getenemies()) do
		if auxi.check_all_exists(e) and not e:IsDead() then
			local dist = origin:Distance(e.Position)
			if dist <= best_d then
				best_d = dist
				best_ent = e
				best_is_player = false
			end
		end
	end
	if not best_ent then
		return nil, false
	end
	return best_ent, best_is_player
end

local function make_pedestal_track(ent, is_player, cam_pos)
	local hash = GetPtrHash(ent)
	local tr = make_track(ent, hash, cam_pos)
	tr.phase = TRACK.LOCK
	tr.is_player = is_player == true
	tr.ratio = 0
	tr.pedestal = true
	tr.target_hash = hash
	return tr
end

local function fire_pedestal_blast(pos)
	Game():BombExplosionEffects(
		pos,
		item.pedestal_damage or 30,
		TearFlags.TEAR_NORMAL,
		Color(1, 1, 1, 1, -1, -1, -1),
		nil,
		0.45,
		false,
		false,
		0
	)
end

local function render_halo_at(store, center_world, world_r, offset, body_alpha, warn_blink)
	local mul = smoothstep(store.halo_t or 0)
	if mul < 0.01 then return end
	local sp = ensure_halo(store)
	local screen_r = world_radius_to_render_px(center_world, world_r, offset)
	local scale = (screen_r / item.halo_base_radius_px) * mul
	local alpha = mul * (item.pedestal_halo_alpha or item.halo_alpha) * (body_alpha or 1)
	local k = warn_blink or 0
	sp.Color = Color(1, 1 - 0.55 * k, 1 - 0.7 * k, alpha, 0.45 * k, 0, 0)
	sp.Scale = Vector(scale, scale)
	local pos = Isaac.WorldToRenderPosition(center_world) + (offset or Vector(0, 0))
	sp:Render(pos, Vector(0, 0), Vector(0, 0))
	sp.Scale = Vector(1, 1)
	sp.Color = Color(1, 1, 1, 1)
end

local function get_pedestal_state(pickup)
	local d = pickup:GetData()
	local key = item.own_key .. "pedestal"
	local ped = d[key]
	if not ped then
		ped = {
			phase = PED.IDLE,
			cooldown = 0,
			lock_t = 0,
			blast_t = 0,
			halo_t = 0,
			halo_target = 0,
		}
		d[key] = ped
	end
	return ped
end

local function clear_pedestal_state(pickup)
	if not pickup then return end
	pickup:GetData()[item.own_key .. "pedestal"] = nil
end

local function refresh_pedestal_ent(tr)
	if not tr then return nil end
	local hash = tr.target_hash or tr.hash
	if not hash then return tr.ent end
	if tr.is_player then
		local game = Game()
		for i = 0, game:GetNumPlayers() - 1 do
			local pl = game:GetPlayer(i)
			if auxi.check_all_exists(pl) and GetPtrHash(pl) == hash then
				tr.ent = pl
				return pl
			end
		end
	else
		for _, e in pairs(auxi.getenemies()) do
			if auxi.check_all_exists(e) and GetPtrHash(e) == hash then
				tr.ent = e
				return e
			end
		end
	end
	return tr.ent
end

local function tick_pedestal(pickup)
	if not pickup or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		return
	end
	if pickup.SubType ~= item.entity then
		clear_pedestal_state(pickup)
		return
	end

	local ped = get_pedestal_state(pickup)
	local center = pedestal_center_world(pickup)
	local range = item.pedestal_range or 130
	tick_halo(ped, true)

	if ped.phase == PED.COOLDOWN then
		ped.cooldown = (ped.cooldown or 0) - 1
		clear_pedestal_track(ped)
		if (ped.cooldown or 0) <= 0 then
			ped.phase = PED.IDLE
		end
		return
	end

	if ped.phase == PED.IDLE then
		local ent, is_player = find_pedestal_target(pickup.Position, range)
		if ent then
			local cam_pos = Isaac.WorldToRenderPosition(center)
			ped.track = make_pedestal_track(ent, is_player, cam_pos)
			ped.lock_t = 0
			ped.phase = PED.LOCK
		end
		return
	end

	local tr = ped.track
	if not tr then
		ped.phase = PED.IDLE
		return
	end

	local ent = refresh_pedestal_ent(tr)
	local alive = auxi.check_all_exists(ent) and not ent:IsDead()
	if alive then
		ped.last_world_pos = Vector(ent.Position.X, ent.Position.Y)
	end

	if not alive then
		if ped.phase == PED.LOCKED then
			ped.blast_t = (ped.blast_t or 0) + 1
			play_anim(tr.sprite, "Lock", false, tr)
			if tr.aim_sprite then
				play_anim(tr.aim_sprite, "Track", false, tr)
			end
			if ped.blast_t >= (item.pedestal_blast_delay or 12) then
				fire_pedestal_blast(ped.last_world_pos or pickup.Position)
				begin_fade(tr)
				ped.phase = PED.FADE
			end
		elseif ped.phase == PED.CONFIRM then
			begin_fade(tr)
			ped.phase = PED.FADE
		elseif ped.phase == PED.FADE then
			tr.fade_t = (tr.fade_t or 0) + 1
			if tr.fade_t >= (item.track_fade_frames or 10) then
				clear_pedestal_track(ped)
				ped.cooldown = item.pedestal_cooldown or 150
				ped.phase = PED.COOLDOWN
			end
		else
			clear_pedestal_track(ped)
			ped.phase = PED.IDLE
		end
		return
	end

	local dist = pickup.Position:Distance(ent.Position)

	if ped.phase == PED.LOCK then
		if dist > range then
			clear_pedestal_track(ped)
			ped.phase = PED.IDLE
			return
		end
		ped.lock_t = (ped.lock_t or 0) + 1
		local lim = math.max(1, item.pedestal_lock_frames or 90)
		tr.ratio = clamp01(ped.lock_t / lim)
		tr.age = (tr.age or 0) + 1
		play_anim(tr.sprite, "Lock", false, tr)
		if tr.ratio >= 0.999 then
			begin_confirm(tr, {skip_pending_blast = true})
			ped.phase = PED.CONFIRM
		end
		return
	end

	if ped.phase == PED.CONFIRM then
		tr.confirm_t = (tr.confirm_t or 0) + 1
		tr.ratio = 1
		play_anim(tr.sprite, "Lock", false, tr)
		if tr.aim_sprite then
			play_anim(tr.aim_sprite, "Track", false, tr)
		end
		if tr.confirm_t >= (item.track_confirm_frames or 6) then
			begin_locked(tr, {skip_pending_blast = true})
			ped.blast_t = 0
			ped.phase = PED.LOCKED
		end
		return
	end

	if ped.phase == PED.LOCKED then
		tr.locked_t = (tr.locked_t or 0) + 1
		tr.ratio = 1
		play_anim(tr.sprite, "Lock", false, tr)
		if tr.aim_sprite then
			play_anim(tr.aim_sprite, "Track", false, tr)
		end
		ped.blast_t = (ped.blast_t or 0) + 1
		if ped.blast_t >= (item.pedestal_blast_delay or 12) then
			fire_pedestal_blast(ent.Position)
			begin_fade(tr)
			ped.phase = PED.FADE
		end
		return
	end

	if ped.phase == PED.FADE then
		tr.fade_t = (tr.fade_t or 0) + 1
		play_anim(tr.sprite, "Lock", false, tr)
		if tr.aim_sprite then
			play_anim(tr.aim_sprite, "Track", false, tr)
		end
		if tr.fade_t >= (item.track_fade_frames or 10) then
			clear_pedestal_track(ped)
			ped.cooldown = item.pedestal_cooldown or 150
			ped.phase = PED.COOLDOWN
		end
	end
end

local function render_pedestal(pickup, offset)
	if not pickup or pickup.SubType ~= item.entity then
		return
	end
	local ped = pickup:GetData()[item.own_key .. "pedestal"]
	if not ped then
		return
	end
	offset = offset or Vector(0, 0)
	local center = pedestal_center_world(pickup)
	render_halo_at(ped, center, item.pedestal_range or 130, offset, 1, 0)
	local tr = ped.track
	if tr and tr.sprite then
		local cam_pos = Isaac.WorldToRenderPosition(center) + offset
		render_tracks({tracks = {[tr.hash or 1] = tr}}, cam_pos, offset)
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = PickupVariant.PICKUP_COLLECTIBLE,
Function = function(_, pickup)
	tick_pedestal(pickup)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = PickupVariant.PICKUP_COLLECTIBLE,
Function = function(_, pickup, offset)
	render_pedestal(pickup, offset)
end,
})

return item

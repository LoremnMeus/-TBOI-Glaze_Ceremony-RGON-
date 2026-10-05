-- Death Field world visuals: ui_chargebar / smooth focus / hold-Drop progress
-- UPDATE（30Hz EFFECT）：tick focus_blend / charge_pulse / 写 Sprite 外观；唯一 Sprite:Update
-- RENDER：只读状态；充能/长按条入队，MC_POST_RENDER 再画（避免被后渲染实体挡住）
-- Proxy 本体由 Effect 自身渲染；这里仅修改 Sprite 外观，不 Sprite:Render 本体。
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local C = require("Qing_Remaster_scripts.cards.death_field.constants")
local state = require("Qing_Remaster_scripts.cards.death_field.state")
local charge = require("Qing_Remaster_scripts.cards.death_field.charge")

local M = {}

local OVERLAY_BY_MAX = {
	[1] = "BarOverlay1",
	[2] = "BarOverlay2",
	[3] = "BarOverlay3",
	[4] = "BarOverlay4",
	[5] = "BarOverlay5",
	[6] = "BarOverlay6",
	[8] = "BarOverlay8",
	[12] = "BarOverlay12",
}

-- 本帧待画 overlay（effect 回调排队，POST_RENDER flush）
local overlay_queue = {}

local function lerp(a, b, t)
	return a + (b - a) * t
end

--- 与实体引擎贴图对齐：W2S(Position+PO) + callbackOffset - scroll + SpriteOffset
--- scroll 已含 shake，禁止再减 ScreenShakeOffset（见 entity_render_scroll_offset_pitfalls.md）
function M.entity_screen_pos(ent, callback_offset)
	local room = Game():GetRoom()
	local world = ent.Position + (ent.PositionOffset or Vector.Zero)
	return Isaac.WorldToScreen(world)
		+ (callback_offset or Vector.Zero)
		- room:GetRenderScrollOffset()
		+ (ent.SpriteOffset or Vector.Zero)
end

--- 虚影贴图可见几何中心（非实体 pivot；dropping_collectible Idle 中心约在 pivot 上方）
local function proxy_visual_center_screen(ent, host_sprite, callback_offset)
	local base = M.entity_screen_pos(ent, callback_offset)
	if not host_sprite then
		return base
	end
	local scale = 1
	if host_sprite.Scale then
		scale = host_sprite.Scale.X or 1
	end
	local voff = ui.SpriteVisualCenterOffset(host_sprite, 0)
	return base + Vector(voff.X * scale, voff.Y * scale)
end

--- 旁挂条：Render 点使条的可见中心落在「虚影中心 + side_offset * proxy scale」
local function overlay_render_pos(ent, host_sprite, bar_sprite, callback_offset, side_offset, scale_x, scale_y)
	scale_x = tonumber(scale_x) or 1
	scale_y = tonumber(scale_y) or 1
	local center = proxy_visual_center_screen(ent, host_sprite, callback_offset)
	side_offset = side_offset or Vector.Zero
	local target = center + Vector(side_offset.X * scale_x, side_offset.Y * scale_y)
	if not bar_sprite then
		return target
	end
	local bar_voff = ui.SpriteVisualCenterOffset(bar_sprite, 0)
	return target - Vector(bar_voff.X * scale_x, bar_voff.Y * scale_y)
end

local function ensure_sprite(d, key, anm2, frame_anim)
	local spr = d[key]
	if spr == nil then
		spr = Sprite()
		spr:Load(anm2, true)
		if frame_anim then
			spr:SetFrame(frame_anim, 0)
		end
		d[key] = spr
	elseif frame_anim then
		local anim = spr.GetAnimation and spr:GetAnimation() or nil
		if not anim or anim == "" then
			spr:SetFrame(frame_anim, 0)
		end
	end
	return spr
end

--- 原版 ui_chargebar：Empty → 绿主条 → 黄 The Battery 过充 → Overlay
--- 两层各自 0..max，不是 0..2max 的一根连续条
local CHARGEBAR_FRAME_H = 26
local CHARGEBAR_FILL_H = 24

local function visible_fill_px(amount, maxc)
	amount = math.max(0, math.min(maxc, amount or 0))
	if amount <= 0 or maxc <= 0 then
		return 0
	end
	local visible = math.ceil(CHARGEBAR_FILL_H * amount / maxc)
	return math.max(1, math.min(CHARGEBAR_FILL_H, visible))
end

local function render_ui_chargebar(spr, main_charge, battery_charge, max_charge, screen, pulse, scale_x, scale_y)
	if not spr or not max_charge or max_charge <= 0 then
		return
	end
	local maxc = max_charge
	local main = math.max(0, math.min(maxc, main_charge or 0))
	local battery = math.max(0, math.min(maxc, battery_charge or 0))
	local boost = (pulse or 0) * (C.CHARGE_PULSE_BOOST or 0.45)
	scale_x = tonumber(scale_x) or 1
	scale_y = tonumber(scale_y) or 1
	spr.Scale = Vector(scale_x, scale_y)

	spr:SetFrame("BarEmpty", 0)
	spr.Color = Color(1, 1, 1, 1)
	spr:Render(screen, Vector.Zero, Vector.Zero)

	local visible_main = visible_fill_px(main, maxc)
	if visible_main > 0 then
		-- BarFull 本身是绿色；只加 pulse 亮度，不额外染绿
		spr.Color = Color(1, 1, 1, 1, boost, boost * 0.85, boost * 0.2)
		spr:SetFrame("BarFull", 0)
		spr:Render(screen, Vector(0, CHARGEBAR_FRAME_H - visible_main), Vector.Zero)
	end

	local visible_battery = visible_fill_px(battery, maxc)
	if visible_battery > 0 then
		local by = C.BATTERY_YELLOW or Color(1, 1, 1, 1, 0.85, 0.55, 0)
		spr.Color = Color(
			by.R,
			by.G,
			by.B,
			by.A,
			(by.RO or 0) + boost * 0.5,
			(by.GO or 0) + boost * 0.35,
			(by.BO or 0) + boost * 0.05
		)
		spr:SetFrame("BarFull", 0)
		spr:Render(screen, Vector(0, CHARGEBAR_FRAME_H - visible_battery), Vector.Zero)
	end

	spr.Color = Color(1, 1, 1, 1)
	local overlay = OVERLAY_BY_MAX[maxc]
	if overlay then
		spr:SetFrame(overlay, 0)
		spr:Render(screen, Vector.Zero, Vector.Zero)
	end
end

--- 解除进度：纯 SetFrame，不在 render 里 Sprite:Update
local function render_hold_bar(spr, percent, screen)
	percent = math.max(0, math.min(1, percent or 0))
	if percent <= 0 then
		return
	end
	spr:SetFrame("Charging", math.floor(percent * 100))
	spr:Render(screen, Vector.Zero, Vector.Zero)
end

function M.get_focus_blend(ent)
	return tonumber(ent:GetData()[C.FOCUS_BLEND_KEY]) or 0
end

function M.tick_focus_blend(ent, focused)
	local d = ent:GetData()
	local cur = tonumber(d[C.FOCUS_BLEND_KEY]) or 0
	local target = focused and 1 or 0
	local nextv = lerp(cur, target, C.FOCUS_BLEND_SPEED)
	if math.abs(nextv - target) < 0.01 then
		nextv = target
	end
	d[C.FOCUS_BLEND_KEY] = nextv
	return nextv
end

--- 仅 UPDATE 调用：写外观，不 Sprite:Update（由 Effect update 统一推进一次）
--- focused 与 activatable 独立：
--- activatable → strong focus（放大+强提亮）；否则 soft focus（不放大+轻度提亮）
function M.apply_proxy_appearance(ent, entry, blend, activatable)
	blend = math.max(0, math.min(1, blend or 0))
	if activatable == nil then
		activatable = true
	end
	local s = ent:GetSprite()

	local alpha_idle = C.ALPHA_IDLE
	if entry.kind == "active" then
		local main, _, maxc = charge.get_effective_charge(entry)
		if maxc > 0 and main < maxc then
			alpha_idle = C.ALPHA_UNCHARGED
		end
	end

	local alpha_focus = activatable and C.ALPHA_FOCUS or C.ALPHA_FOCUS_UNUSABLE
	local alpha = lerp(alpha_idle, alpha_focus, blend)
	local scale = lerp(C.PROXY_IDLE_SCALE or 0.78, C.PROXY_FOCUS_SCALE or 1.0, blend)
	local target_lift = activatable and C.FOCUS_LIFT or (C.FOCUS_LIFT_UNUSABLE or 0.12)
	local lift = target_lift * blend

	local bob = math.sin((Game():GetFrameCount() + (entry.uid or 0) * 13) * 0.12) * 3
	ent.SpriteOffset = Vector(0, bob)
	s.Scale = Vector(scale, scale)
	local col = Color(1, 1, 1, alpha, lift, lift * 0.85, lift * 0.35)
	if col.SetColorize then
		col:SetColorize(0, 0, 0, 0)
	end
	s.Color = col
	if ent.DepthOffset ~= nil then
		ent.DepthOffset = C.PROXY_DEPTH_OFFSET
	end
end

function M.tick_charge_pulse(entry)
	if not entry then
		return
	end
	local p = tonumber(entry.charge_pulse) or 0
	if p <= 0.01 then
		entry.charge_pulse = 0
		return
	end
	entry.charge_pulse = p * C.CHARGE_PULSE_DECAY
end

--- 30Hz 权威视觉更新：blend / pulse / appearance（调用方再 Sprite:Update 一次）
function M.update_proxy(ent, entry, focused, activatable)
	local blend = M.tick_focus_blend(ent, focused)
	M.tick_charge_pulse(entry)
	M.apply_proxy_appearance(ent, entry, blend, activatable ~= false)
	ent:GetData()[C.OWN_KEY .. "focus_activatable"] = activatable ~= false
	return blend
end

local function queue_ui_bar(spr, main_charge, battery_charge, maxc, screen, pulse, scale_x, scale_y)
	overlay_queue[#overlay_queue + 1] = {
		kind = "ui_bar",
		sprite = spr,
		main_charge = main_charge,
		battery_charge = battery_charge,
		maxc = maxc,
		screen = screen,
		pulse = pulse,
		scale_x = scale_x,
		scale_y = scale_y,
	}
end

local function queue_hold_bar(spr, percent, screen)
	overlay_queue[#overlay_queue + 1] = {
		kind = "hold_bar",
		sprite = spr,
		percent = percent,
		screen = screen,
	}
end

function M.note_charge_pulse(entry)
	if not entry then
		return
	end
	entry.charge_pulse = 1
end

--- EFFECT_RENDER：只排队充能/长按条；不绘制资源本体
function M.render_proxy(ent, d, s, player, callback_offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end

	local entry = d.death_field_entry
	if not entry then
		local uid = d[C.DATA_UID]
		local idx = d[C.DATA_OWNER]
		if not player or player:GetData().__Index ~= idx then
			player = d.Params and d.Params.player
		end
		if not player or not state.is_active(player) then
			return
		end
		entry = state.find_entry(player, uid)
		if not entry then
			return
		end
	else
		if not player then
			player = d.Params and d.Params.player
		end
	end

	local blend = M.get_focus_blend(ent)

	if entry.kind == "active" then
		local main, battery, maxc, ctype = charge.get_effective_charge(entry)
		if maxc > 0 and ctype ~= ItemConfig.CHARGE_SPECIAL then
			local pulse = tonumber(entry.charge_pulse) or 0
			local spr = ensure_sprite(d, C.OWN_KEY .. "ui_bar", C.UI_CHARGEBAR_ANM2, "BarEmpty")
			local sx, sy = 1, 1
			if s and s.Scale then
				sx = tonumber(s.Scale.X) or 1
				sy = tonumber(s.Scale.Y) or 1
			end
			queue_ui_bar(
				spr,
				main,
				battery,
				maxc,
				overlay_render_pos(ent, s, spr, callback_offset, C.UI_CHARGEBAR_OFFSET, sx, sy),
				pulse,
				sx,
				sy
			)
		end
	end

	local hold = 0
	if player then
		hold = tonumber(player:GetData()[C.HOLD_KEY]) or 0
	end
	if blend > 0.2 and hold > 0 then
		local spr = ensure_sprite(d, C.OWN_KEY .. "hold_spr", C.HOLD_CHARGEBAR_ANM2, "Charging")
		queue_hold_bar(
			spr,
			math.min(1, hold / C.HOLD_DROP_FRAMES),
			overlay_render_pos(ent, s, spr, callback_offset, C.HOLD_BAR_OFFSET)
		)
	end
end

--- MC_POST_RENDER：画出本帧充能/长按条
function M.flush_overlays()
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		overlay_queue = {}
		return
	end
	for i = 1, #overlay_queue do
		local job = overlay_queue[i]
		if job.kind == "ui_bar" then
			render_ui_chargebar(
				job.sprite,
				job.main_charge,
				job.battery_charge,
				job.maxc,
				job.screen,
				job.pulse,
				job.scale_x,
				job.scale_y
			)
		elseif job.kind == "hold_bar" then
			render_hold_bar(job.sprite, job.percent, job.screen)
		end
	end
	overlay_queue = {}
end

function M.clear_overlay_queue()
	overlay_queue = {}
end

return M

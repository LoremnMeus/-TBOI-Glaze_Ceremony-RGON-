-- 妖刀·逢魔 HUD 渲染：鬼头 / Beam 尾巴 / current·max 资源对 / Deal 列 / 选中 Overlay / debug。
-- 坐标 / 字体 / 格式一律来自 hud_nodes + hud_fonts（与 Probe Live 同源）。
-- 正式态不画框、标签、Spirit 文本；只让当前 target 数字原位换色。

local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local hud_nodes = require("Qing_Remaster_scripts.items.spectralsword.hud_nodes")
local hud_fonts = require("Qing_Remaster_scripts.items.spectralsword.hud_fonts")
local deal_semantics = require("Qing_Remaster_scripts.auxiliary.deal_chance_semantics")
local ghost_controller = require("Qing_Remaster_scripts.items.spectralsword.ghost_controller")
local spirit_vfx = require("Qing_Remaster_scripts.items.spectralsword.spirit_vfx")

local M = {}

local HEAD_ANM2 = "gfx/mimics/Spectralsword/ghost_debug.anm2"
local TAIL_ANM2 = "gfx/mimics/Spectralsword/tail_beam.anm2"
local ORB_ANM2 = "gfx/mimics/Spectralsword/spirit_orb.anm2"
local SHEET_Y = 32

-- current 覆盖原版资源数字；slash 略暗；cap 为附属上限。
local NORMAL_CURRENT_COLOR = KColor(1, 1, 1, 1)
local NORMAL_SLASH_COLOR = KColor(0.72, 0.75, 0.82, 0.78)
local NORMAL_CAP_COLOR = KColor(0.85, 0.88, 1, 0.85)
-- Deal 未选中：偏暗，与选中紫色 overlay 拉开对比
local NORMAL_DEAL_COLOR = KColor(0.58, 0.58, 0.66, 0.60)
local PLANETARIUM_DELTA_COLOR = KColor(0.55, 0.75, 0.85, 0.55)
local CONTROL_HINT_COLOR = KColor(0.85, 0.88, 0.95, 0.7)
local PLANETARIUM_DELTA_GAP = 2

local head_sprite
local orb_sprite
local beam
local beam_ready = false

local function ensure_sprites()
	if not head_sprite then
		head_sprite = Sprite()
		head_sprite:Load(HEAD_ANM2, true)
		head_sprite:Play("Idle", true)
	end
	if not orb_sprite then
		orb_sprite = Sprite()
		orb_sprite:Load(ORB_ANM2, true)
		orb_sprite:Play("Idle", true)
	end
	if not beam_ready then
		beam_ready = true
		if Beam then
			local spr = Sprite()
			spr:Load(TAIL_ANM2, true)
			spr:Play("Idle", true)
			beam = Beam(spr, "Tail", false, false)
		end
	end
	hud_fonts.ensure_loaded()
end

local function draw_cross(pos, size, col)
	size = size or 6
	col = col or KColor(1, 1, 1, 0.85)
	gui.draw_ch(pos + Vector(-size, -4), "+", 1, 1, col, true)
end

--- 星象：cached 主值 + 可选 signed (live-cached) 后缀；选中时两段同色。
local function draw_planetarium_pair_at(pos, view, base_col, delta_col)
	local base_text, delta_text = hud_fonts.format_planetarium_cached_delta(view)
	hud_fonts.draw_stat(base_text, pos.X, pos.Y, base_col, 1, hud_fonts.STAT_FONT_MODE)
	if delta_text then
		local base_w = hud_fonts.stat_width(base_text, hud_fonts.STAT_FONT_MODE)
		hud_fonts.draw_stat(
			delta_text,
			pos.X + base_w + PLANETARIUM_DELTA_GAP,
			pos.Y,
			delta_col or PLANETARIUM_DELTA_COLOR,
			1,
			hud_fonts.STAT_FONT_MODE
		)
	end
end

--- 会话期间绘制 current/max 三段资源对（Pickup Font）。
--- current 补零覆盖原版数字；cap 紧贴 slash；节点仍分 coins / max_coins。
local function draw_resource_pairs(player)
	if not player then return end
	if hud_nodes.get_debug_hide_custom_text("resource_pair") then return end
	for _, id in ipairs(hud_nodes.RESOURCE_KEYS) do
		local layout = hud_nodes.layout_resource_pair_for(player, id)
		if layout then
			hud_fonts.draw_pickup(layout.current_text, layout.current_pos.X, layout.current_pos.Y, NORMAL_CURRENT_COLOR, 1)
			hud_fonts.draw_pickup(layout.slash_text, layout.slash_pos.X, layout.slash_pos.Y, NORMAL_SLASH_COLOR, 1)
			hud_fonts.draw_pickup(layout.cap_text, layout.cap_pos.X, layout.cap_pos.Y, NORMAL_CAP_COLOR, 1)
		end
	end
end

--- Luck 下方自绘 Deal 列。Devil/Angel 仅 Found-HUD eligible；Planetarium 仅原生 Stat HUD 显示时。
--- Duality：只画合并 Deal（devil 行）+ Planetarium，Angel 行不占位。
local function draw_deal_overlays(player, deal_snap, planetarium_view)
	if not player then return end
	if not hud_nodes.found_hud_available() then return end
	if hud_nodes.get_debug_hide_custom_text("deal") then return end
	deal_snap = deal_snap or deal_semantics.snapshot({allow_getter_fallback = true})
	local eligible = deal_snap.eligibility and deal_snap.eligibility.found_hud_eligible == true
	local planetarium_ok = hud_nodes.planetarium_hud_available()
	local text_off = hud_nodes.get_deal_text_offset()
	for _, id in ipairs(hud_nodes.get_active_deal_rows()) do
		local show = false
		if id == "planetarium" then
			show = planetarium_ok
		elseif id == "angel" then
			show = eligible and not hud_nodes.has_duality()
		else
			show = eligible
		end
		if show then
			local node = hud_nodes.get(id)
			if node then
				local pos = node.get_anchor(player) + text_off
				if id == "planetarium" then
					draw_planetarium_pair_at(pos, planetarium_view, NORMAL_DEAL_COLOR, nil)
				else
					hud_fonts.draw_stat(
						hud_fonts.format_live_deal(id, hud_fonts.DEAL_PERCENT_MODE, deal_snap),
						pos.X, pos.Y, NORMAL_DEAL_COLOR, 1, hud_fonts.STAT_FONT_MODE
					)
				end
			end
		end
	end
end

--- 选中节点：只覆盖对应子串。resource → current；resource_cap → cap；slash 永不高亮。
local function draw_selected_value_overlay(player, ghost, deal_snap, planetarium_view)
	if not player or not ghost or not ghost.target_node then
		return
	end
	local id = ghost.target_node
	local node = hud_nodes.get(id)
	if not node then
		return
	end

	local text
	local pos
	local draw_kind
	local group = node.group

	if group == "resource" then
		if hud_nodes.get_debug_hide_custom_text("resource_pair") then
			return
		end
		local layout = hud_nodes.layout_resource_pair_for(player, id)
		if not layout then return end
		text = layout.current_text
		pos = layout.current_pos
		draw_kind = "pickup"
	elseif group == "resource_cap" then
		if hud_nodes.get_debug_hide_custom_text("resource_pair") then
			return
		end
		local layout = hud_nodes.layout_resource_pair_for(player, node.resource_id)
		if not layout then return end
		text = layout.cap_text
		pos = layout.cap_pos
		draw_kind = "pickup"
	elseif group == "stats" then
		text = hud_fonts.format_live_stat(player, id)
		pos = node.get_anchor(player) + hud_nodes.get_stat_text_offset()
		draw_kind = "stat"
	elseif group == "deal" then
		if hud_nodes.get_debug_hide_custom_text("deal") then
			return
		end
		deal_snap = deal_snap or deal_semantics.snapshot({allow_getter_fallback = true})
		pos = node.get_anchor(player) + hud_nodes.get_deal_text_offset()
		if id == "planetarium" then
			local a = 0.65 + 0.15 * math.sin(ghost.pulse or 0)
			local selected_col = KColor(0.85, 0.65, 1.0, a)
			draw_planetarium_pair_at(pos, planetarium_view, selected_col, selected_col)
			return
		end
		text = hud_fonts.format_live_deal(id, hud_fonts.DEAL_PERCENT_MODE, deal_snap)
		draw_kind = "stat"
	else
		return
	end

	local a = 0.65 + 0.15 * math.sin(ghost.pulse or 0)
	local selected_col = KColor(0.85, 0.65, 1.0, a)
	if draw_kind == "pickup" then
		hud_fonts.draw_pickup(text, pos.X, pos.Y, selected_col, 1)
	else
		hud_fonts.draw_stat(text, pos.X, pos.Y, selected_col, 1, hud_fonts.STAT_FONT_MODE)
	end
end

local function draw_tail(ghost)
	if not ghost or not ghost.segments then return end
	local pts = ghost_controller.get_render_points(ghost)
	if #pts < 2 then return end
	local a = ghost.alpha or 1
	if beam and beam.Add and beam.Render then
		local beam_spr = beam.GetSprite and beam:GetSprite() or nil
		if beam_spr then
			beam_spr.Color = Color(1, 1, 1, a, 0.15 * a, 0.1 * a, 0.25 * a)
			if beam_spr.SetFrame then
				pcall(function() beam_spr:SetFrame("Idle", 0) end)
			end
		end
		-- 先收集可见点：EMERGE/SINK 早期可能只剩 0/1 点；不足两点不 Render。
		-- 禁止 beam:SetPoints({})——RGON 同样要求 ≥2 点。Render(true) 会自动清点。
		local visible = {}
		local sheet = 0
		local sheet_step = SHEET_Y / math.max(1, #pts - 1)
		for i = 1, #pts do
			local p = pts[i]
			local ra = p.alpha or 1
			local w = (p.width or 0.5) * (0.85 + 0.15 * a)
			if ra > 0.001 and w > 0.001 then
				visible[#visible + 1] = {pos = p.pos, sheet = sheet, w = w}
			end
			sheet = sheet + sheet_step
		end
		if #visible < 2 then
			return
		end
		for i = 1, #visible do
			local v = visible[i]
			beam:Add(v.pos, v.sheet, v.w)
		end
		beam:Render(true)
		return
	end
	local orb_count = 0
	for i = 1, #pts do
		local p = pts[i]
		local ra = p.alpha or 1
		if ra > 0.001 then
			orb_count = orb_count + 1
		end
	end
	if orb_count < 2 then return end
	for i = 1, #pts do
		local p = pts[i]
		local ra = p.alpha or 1
		if ra > 0.001 then
			local s = 0.35 + (p.width or 0.5) * 0.5
			orb_sprite.Scale = Vector(s, s)
			orb_sprite.Color = Color(1, 1, 1, a * 0.7 * ra, 0, 0, 0)
			orb_sprite:Render(p.pos, Vector.Zero, Vector.Zero)
		end
	end
end

local function get_head_breath(ghost)
	local phase = (ghost.pulse or 0) * 0.75
	local breath = math.sin(phase)
	return {
		scale = 1.0 + breath * 0.025,
		alpha = 0.96 + breath * 0.04,
	}
end

local function head_action_scale(st)
	if st == ghost_controller.STATE.SLASH_WINDUP then
		return 1.03
	elseif st == ghost_controller.STATE.SLASH then
		return 1.06
	elseif st == ghost_controller.STATE.INJECT_WINDUP then
		return 0.97
	elseif st == ghost_controller.STATE.INJECT then
		return 1.03
	elseif st == ghost_controller.STATE.FAIL then
		return 0.96
	end
	-- HOVER / TRAVEL / ENTRY_TRAVEL / RETURN / EMERGE / SINK：贴图 1:1
	return 1.0
end

--- 贴图已含 Halo / 青色；代码只做低频呼吸 + 动作微缩放，无 aura / core / RGB offset。
local function draw_head(ghost)
	if not ghost or not ghost.head_pos then return end
	local a = ghost.alpha or 1
	local facing = ghost.facing or 1
	local breath = get_head_breath(ghost)
	local scale = breath.scale * head_action_scale(ghost.state)

	head_sprite.Scale = Vector(scale * facing, scale)
	head_sprite.Color = Color(1, 1, 1, a * breath.alpha, 0, 0, 0)
	head_sprite:Render(ghost.head_pos, Vector.Zero, Vector.Zero)
	head_sprite.Scale = Vector(1, 1)
end

local function orb_draw_color(p)
	local a = p.render_alpha or p.alpha or 1
	local kind = p.essence_kind or "stat"
	if kind == "resource" then
		-- 金白
		return Color(1.0, 0.92, 0.70, a, 0.20 * a, 0.12 * a, 0.02 * a)
	elseif kind == "chance" then
		-- 青白
		return Color(0.86, 0.98, 1.0, a, 0.04 * a, 0.14 * a, 0.16 * a)
	end
	-- 紫白（属性）
	return Color(0.96, 0.90, 1.0, a, 0.14 * a, 0.06 * a, 0.22 * a)
end

local function draw_orbs(vfx, layer)
	if not vfx then return end
	for _, p in ipairs(spirit_vfx.get_particles(vfx, layer)) do
		local s = p.render_scale or p.scale or 0.7
		orb_sprite.Scale = Vector(s, s)
		orb_sprite.Color = orb_draw_color(p)
		orb_sprite:Render(p.pos, Vector.Zero, Vector.Zero)
	end
	orb_sprite.Scale = Vector(1, 1)
end

local function draw_debug(ghost, player, essence)
	if not ghost or not ghost.debug then return end
	local info = ghost_controller.get_debug_info(ghost)
	local y = 40
	essence = essence or {}
	local lines = {
		"state=" .. tostring(info.state),
		"node=" .. tostring(info.node),
		"head=" .. tostring(info.head),
		"ghost_target=" .. tostring(info.target),
		string.format("essence 紫%d 金%d 青%d", essence.stat or 0, essence.resource or 0, essence.chance or 0),
	}
	for _, line in ipairs(lines) do
		gui.draw_ch(Vector(8, y), line, 1, 1, KColor(0.7, 1, 0.7, 0.9), true)
		y = y + 10
	end
	draw_cross(ghost.target_pos, 6, KColor(0.4, 1, 0.6, 0.95))
	if ghost.hud_anchor then
		gui.draw_ch(ghost.hud_anchor + Vector(-3, -5), "x", 1, 1, KColor(1, 0.4, 0.4, 0.95), true)
	end
	draw_cross(ghost.head_pos, 5, KColor(1, 1, 0.4, 0.9))
	if ghost.segments then
		for i, seg in ipairs(ghost.segments) do
			gui.draw_ch(seg.pos + Vector(-2, -4), tostring(i), 1, 1, KColor(0.6, 0.9, 1, 0.7), true)
		end
	end
	for _, id in ipairs(hud_nodes.list_ids()) do
		local node = hud_nodes.get(id)
		if node then
			local hud = node.get_anchor(player)
			gui.draw_ch(hud + Vector(-3, -5), "x", 1, 1, KColor(1, 0.5, 0.5, 0.35), true)
			if node.get_ghost_anchor then
				local g = node.get_ghost_anchor(player)
				gui.draw_ch(g + Vector(-3, -5), "o", 1, 1, KColor(0.5, 1, 0.6, 0.35), true)
			end
		end
	end
end

--- 底部操作提示：Q/E/Ctrl（方向移动可发现，不必写进 HUD）。不随选中节点闪烁。
local function draw_control_hint(session)
	local zh = session and session.zh
	local text = zh
		and "Q：抽取    E：注入    Ctrl：关闭"
		or "Q: Extract    E: Inject    Ctrl: Exit"
	local size = ui.GetScreenSize()
	local scale = 1
	local font = gui.f
	local width = 0
	if font and font.GetStringWidthUTF8 then
		width = font:GetStringWidthUTF8(text) * scale
	elseif font and font.GetStringWidth then
		width = font:GetStringWidth(text) * scale
	else
		width = #text * 6 * scale
	end
	local x = math.floor(size.X * 0.5 - width * 0.5 + 0.5)
	local y = math.floor(size.Y - 22 + 0.5)
	gui.draw_ch(Vector(x, y), text, scale, scale, CONTROL_HINT_COLOR, true)
end

--- session = { player, ghost, vfx, spirit, modifiers, planetarium_view, zh }
function M.render(session)
	if not session or not session.ghost or not session.ghost.active then return end
	ensure_sprites()
	local player = session.player
	local ghost = session.ghost
	local vfx = session.vfx
	draw_orbs(vfx, "back")
	draw_tail(ghost)
	draw_head(ghost)
	draw_orbs(vfx, "front")
	draw_resource_pairs(player)
	local deal_snap = deal_semantics.snapshot({allow_getter_fallback = true})
	local planetarium_view = session.planetarium_view
	draw_deal_overlays(player, deal_snap, planetarium_view)
	draw_selected_value_overlay(player, ghost, deal_snap, planetarium_view)
	draw_control_hint(session)
	draw_debug(ghost, player, session.essence)
end

return M

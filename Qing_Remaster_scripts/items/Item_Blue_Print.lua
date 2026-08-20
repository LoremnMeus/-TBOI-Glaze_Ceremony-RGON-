local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Mouse_UI = require("Qing_Remaster_scripts.others.Mouse_UI_holder")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")

local function get_bandwidth()
	return require("Qing_Remaster_scripts.mimics.Craft_Bandwidth_Manager")
end

local function get_tutorial()
	return require("Qing_Remaster_scripts.others.blueprint_tutorial")
end

local item = {
	ToCall = {},
	pre_ToCall = {},
	myToCall = {},
	entity = enums.Items.Blue_Print,
	own_key = "Item_Blue_Print_",
	panel = nil,
	suppress_open_until = -1,
	pending_reopen_until = nil, -- 换房/下层丢弃 panel 后，仍举着则自动重开
	_room_epoch = 0,
	_integrity_epoch_seen = {},
	-- 兼容旧字段；权威数据在 save.elses.Qing_Blue_Print
	crafted_list = {},
	crafted_uid = 0,
	bg_anm2 = "gfx/mimics/Blueprint/Blueprint.anm2",
	panel_size = Vector(420, 268),
	panel_offset = Vector(0, -10),
	content_pad = Vector(14, 14),
	tab_height = 18,
	tab_gap = 3,
	token_size = 28,
	slot_size = 34,
	bag_page_size = 24,
	open_rise_dur = 14, -- 升起+淡入时长（帧）；开场即开始，无停顿
	open_rise_distance = 72, -- 自下方升起的像素距离
	dot_offset_default = Vector(-2, -9), -- 框线 `.` 字形相对几何角点的修正（正X右、正Y下）
	bg_offset_default = Vector(0, 13), -- 背景精灵渲染偏移
	audit_text_y_default = 2, -- 效果描述相对目标图标再下移
	slot_count_default = 3, -- 旧调试滑条；材料槽数现由底座品质决定
	quality_anm2 = "gfx/ui/EID/eid_quality.anm2",
	quality_icon_offset = Vector(8, -12), -- 相对背包 token 中心，右上
	form_bench_page_size = 4,
	cost_offset_y_default = 21, -- 成本小槽相对目标图标中心下移（材料槽以此为分割线）
	cost_extra_count_default = 0, -- 成本小槽额外显示数量（便于测排版）
	cost_slot_size_default = 18, -- 实测合适；间距随尺寸 = size+2
	cost_slot_row_gap = 2, -- 成本多行时的行距
	cost_slot_max_cols = 8,
	cost_token_scale = 0.5,
	cost_qmark_offset_default = Vector(-2, 1),
	cost_qmark_path = "gfx/effects/questionmark_black.png",
	cost_attract_dist = 52,
	slot_ellipse_rx = 56, -- 材料槽椭圆半长轴（水平）
	slot_ellipse_ry = 28, -- 材料槽椭圆半短轴（垂直；勿高过道具名）
	craft_group_y_default = 14, -- 目标道具+材料槽(+成本) 整组 Y 偏移
	tag_col_offset_default = Vector(-36, 0), -- 标签列相对背包右缘；负 X 往背包内侧靠
	tag_col_width_default = 56,
	nav_delay = 10, -- 单次方向移动最小间隔（帧）
	nav_repeat_initial = 22, -- 长按：首次后等待再连发（仿输入法）
	nav_repeat_interval = 6, -- 长按连发间隔
	action_delay = 12, -- 开场锁定等；点击后改为“松手解除”
	snap_dist = 34,
	snap_anim_frames = 10,
	inertia_friction = 0.78,
	inertia_stop = 0.55,
	inertia_max = 7,
	debug_draw_regions = false,
	z_modal = 10,
	z_panel = 20,
	z_tab = 40,
	z_button = 50,
	z_slot = 55,
	z_bag = 60,
	z_token = 80,
	tabs = {
		{id = "formation", zh = "编队", en = "Formation"},
		{id = "build", zh = "制造", en = "Build"},
		{id = "inventory", zh = "仓库", en = "Stock"},
	},
	-- 可建造目标（暂两件）；显示名对接 CraftProfile.TARGET_BASE（空行/空怖）
	build_targets = {
		{
			id = enums.Items.Air_Flight,
			gfx = "gfx/items/collectibles/collectibles_Air_Flight.png",
			slots = {
				{ox = -48, oy = -8},
				{ox = 48, oy = -8},
				{ox = 0, oy = 42},
			},
		},
		{
			id = enums.Items.Air_Terror,
			gfx = "gfx/items/collectibles/collectibles_Air_Terror.png",
			slots = {
				{ox = -48, oy = 0},
				{ox = 48, oy = 0},
			},
		},
	},
}

local selection_key = item.own_key.."select"
local blocked_actions = {
	[ButtonAction.ACTION_LEFT] = true,
	[ButtonAction.ACTION_RIGHT] = true,
	[ButtonAction.ACTION_UP] = true,
	[ButtonAction.ACTION_DOWN] = true,
	[ButtonAction.ACTION_SHOOTLEFT] = true,
	[ButtonAction.ACTION_SHOOTRIGHT] = true,
	[ButtonAction.ACTION_SHOOTUP] = true,
	[ButtonAction.ACTION_SHOOTDOWN] = true,
	[ButtonAction.ACTION_DROP] = true,
	[ButtonAction.ACTION_PILLCARD] = true,
	[ButtonAction.ACTION_MAP] = true,
	[ButtonAction.ACTION_BOMB] = true,
	[ButtonAction.ACTION_ITEM] = true,
	[ButtonAction.ACTION_CONSOLE] = true,
	[ButtonAction.ACTION_MENUCONFIRM] = true,
	-- MENUBACK / ESC 放行：允许蓝图页唤起暂停菜单
	[ButtonAction.ACTION_MENULEFT] = true,
	[ButtonAction.ACTION_MENURIGHT] = true,
	[ButtonAction.ACTION_MENUUP] = true,
	[ButtonAction.ACTION_MENUDOWN] = true,
}

local function action_inputs_held(panel)
	if not panel or not panel.player then return false end
	local ctrlid = panel.player.ControllerIndex or 0
	if Input.IsActionPressed(ButtonAction.ACTION_MENUCONFIRM, ctrlid) then return true end
	if Input.IsActionPressed(ButtonAction.ACTION_ITEM, ctrlid) then return true end
	if Mouse_UI and (Mouse_UI.is_down(0) or Mouse_UI.is_down(1)) then return true end
	return false
end

-- 开场仍用 lock_until；操作后改为“触发一次，松手即结束锁定”，便于双击
local function input_locked(panel)
	if Game():GetFrameCount() < (panel.lock_until or 0) then return true end
	if panel.action_hold_lock then
		if action_inputs_held(panel) then return true end
		panel.action_hold_lock = false
	end
	return false
end

local function lock_actions(panel, frames)
	if not panel then return end
	if frames and frames > 0 and frames < (item.action_delay or 12) then
		-- 显式短锁（如翻页）仍按帧
		panel.lock_until = Game():GetFrameCount() + frames
		panel.action_hold_lock = false
		return
	end
	panel.action_hold_lock = true
end

local function focus_equals(panel, id)
	return panel and panel.focus_id == id
end

local function get_debug_number(key, default_value)
	local root = save.ModConfigSettings
	local debug_settings = root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
	return tonumber(debug_settings and debug_settings[key]) or default_value
end

local function get_debug_bool(key, default_value)
	local root = save.ModConfigSettings
	local debug_settings = root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
	local v = debug_settings and debug_settings[key]
	if v == nil then return default_value and true or false end
	return v == true
end

--- ImGui：显示材料来源角标（原/审）与来源描边；默认关闭
local function show_source_marks()
	return get_debug_bool("BlueprintShowSourceMarks", false)
end

local function get_dot_offset()
	local def = item.dot_offset_default or Vector(-2, -9)
	return Vector(
		get_debug_number("BlueprintDotOffsetX", def.X),
		get_debug_number("BlueprintDotOffsetY", def.Y)
	)
end

local function get_bg_offset()
	local def = item.bg_offset_default or Vector(0, 0)
	return Vector(
		get_debug_number("BlueprintBgOffsetX", def.X),
		get_debug_number("BlueprintBgOffsetY", def.Y)
	)
end

local function get_audit_text_y()
	return get_debug_number("BlueprintAuditTextY", item.audit_text_y_default or 2)
end

local function get_cost_y_offset()
	return get_debug_number("BlueprintCostOffsetY", item.cost_offset_y_default or 21)
end

local function get_craft_group_y()
	return get_debug_number("BlueprintCraftGroupY", item.craft_group_y_default or 14)
end

local function get_tag_col_offset()
	local def = item.tag_col_offset_default or Vector(-36, 0)
	return Vector(
		get_debug_number("BlueprintTagColOffsetX", def.X),
		get_debug_number("BlueprintTagColOffsetY", def.Y)
	)
end

local function get_tag_col_width()
	local n = get_debug_number("BlueprintTagColWidth", item.tag_col_width_default or 56)
	return math.max(40, math.min(96, n))
end

local function get_cost_token_scale()
	return get_debug_number("BlueprintCostTokenScale", item.cost_token_scale or 0.5)
end

local function get_cost_slot_size()
	local n = get_debug_number("BlueprintCostSlotSize", item.cost_slot_size_default or 18)
	return math.max(8, math.min(48, n))
end

local function get_cost_slot_spacing()
	-- 中心距随小槽尺寸：尺寸 + 2
	return get_cost_slot_size() + 2
end

local function get_cost_qmark_offset()
	local def = item.cost_qmark_offset_default or Vector(-2, 1)
	return Vector(
		get_debug_number("BlueprintCostQmarkOffsetX", def.X),
		get_debug_number("BlueprintCostQmarkOffsetY", def.Y)
	)
end

local function get_cost_extra_count()
	local n = math.floor(get_debug_number("BlueprintCostExtraCount", item.cost_extra_count_default or 0) + 0.5)
	return math.max(0, math.min(12, n))
end

local function get_slot_count()
	local n = math.floor(get_debug_number("BlueprintSlotCount", item.slot_count_default or 3) + 0.5)
	return math.max(1, math.min(7, n))
end

--- 本件制造锁定的成本槽数（编辑不跟「下一件」阶梯走）
local function locked_required_cost_from_rec(rec)
	if not rec then return 0 end
	local n = tonumber(rec.required_cost)
	if n ~= nil then return math.max(0, math.floor(n + 0.5)) end
	-- 旧存档未写 required_cost：按当时写入的成本条目数锁定
	return math.max(0, #(rec.cost_items or {}))
end

local function resolve_session_required_cost(player, edit_uid, edit_rec, draft)
	if edit_uid then
		local n = locked_required_cost_from_rec(edit_rec)
		if draft then
			local dn = tonumber(draft.required_cost)
			if dn ~= nil then n = math.max(n, math.floor(dn + 0.5)) end
			-- 草稿多塞了成本只影响显示 have；不抬高锁定 need
		end
		return math.max(0, n)
	end
	local n = item.get_required_cost(player)
	if draft then
		local dn = tonumber(draft.required_cost)
		if dn ~= nil then n = math.max(n, math.floor(dn + 0.5)) end
	end
	return math.max(0, n)
end

--- 始终至少 1 个灰色底座槽；确认是否必填仍看 required_cost
local function cost_display_count(craft)
	if not craft then return 1 end
	local need = craft.required_cost or 0
	local have = #(craft.cost_ids or {})
	return math.max(1, need, have) + get_cost_extra_count()
end

local function cost_cols_for_width(avail_w)
	local spacing = get_cost_slot_spacing()
	local max_cols = item.cost_slot_max_cols or 8
	return math.max(1, math.min(max_cols, math.floor(math.max(8, avail_w) / spacing)))
end

local function cost_row_count(n, cols)
	if n <= 0 then return 0 end
	return math.ceil(n / math.max(1, cols))
end

--- 成本带相对目标中心的顶/底 oy（材料槽整框不得侵入）；无成本时返回 nil
local function cost_band_oy_range(cost_n, avail_w)
	if not cost_n or cost_n <= 0 then return nil, nil, 0 end
	local size = get_cost_slot_size()
	local cost_y = get_cost_y_offset() -- 首行中心
	local cols = cost_cols_for_width(avail_w or 160)
	local rows = math.max(1, cost_row_count(cost_n, cols))
	local row_gap = item.cost_slot_row_gap or 2
	local top = cost_y - size * 0.5
	local bot = top + rows * size + (rows - 1) * row_gap
	return top, bot, rows
end

--- 材料槽椭圆环绕。底座至多 1 个、画在图标下方，不再为成本带预留整行。
local function make_slot_layout(n, _cost_n, _avail_w)
	n = math.max(0, math.min(7, n or 0))
	if n <= 0 then return {} end
	local rx = item.slot_ellipse_rx or 56
	local ry = item.slot_ellipse_ry or 28
	if n == 1 then return {{ox = rx, oy = 0}} end
	local start = (n % 2 == 0) and (-90 + 180 / n) or -90
	local out = {}
	for i = 1, n do
		local ang = math.rad(start + (i - 1) * (360 / n))
		out[i] = {ox = math.cos(ang) * rx, oy = math.sin(ang) * ry}
	end
	return out
end

--- 按当前成本行数刷新材料槽偏移（每帧，保证成本带始终占行）
local function refresh_slot_offsets(craft, avail_w)
	if not craft or not craft.slots then return end
	local n = #craft.slots
	local cost_n = cost_display_count(craft)
	local layout = make_slot_layout(n, cost_n, avail_w)
	for i, slot in ipairs(craft.slots) do
		local L = layout[i]
		if L then
			slot._to_ox = L.ox
			slot._to_oy = L.oy
			local anim_t = slot._anim_t
			if anim_t ~= nil and anim_t < 1 then
				anim_t = math.min(1, anim_t + 0.14)
				slot._anim_t = anim_t
				local t = anim_t * anim_t * (3 - 2 * anim_t)
				local fx = slot._from_ox or 0
				local fy = slot._from_oy or 0
				slot.ox = fx + (L.ox - fx) * t
				slot.oy = fy + (L.oy - fy) * t
			else
				slot.ox = L.ox
				slot.oy = L.oy
				slot._anim_t = nil
			end
		end
	end
end

local function ensure_cost_qmark_sprite()
	-- alchemy_pot_item：pivot 16,16 居中；贴图可单独替换
	local path = item.cost_qmark_path or "gfx/effects/questionmark_black.png"
	if item._cost_qmark and item._cost_qmark_ver == 3 and item._cost_qmark_path == path then
		return item._cost_qmark
	end
	local s = Sprite()
	s:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2", true)
	s:ReplaceSpritesheet(0, path)
	s:LoadGraphics()
	s:Play("Idle", true)
	item._cost_qmark = s
	item._cost_qmark_path = path
	item._cost_qmark_ver = 3
	return s
end

--- 下一件非「纯审计」制造所需成本
--- 里小青：无飞行器 0，已有至少一架则固定 1；其他：3,5,7… 中最小未占用
function item.get_required_cost(player)
	if player and player:GetPlayerType() == enums.Players.Spwq then
		local n = 0
		for _, rec in ipairs(item.get_craft_store(player)) do
			if rec.tutorial ~= true and not CraftProfile.craft_is_pure_audit_rec(rec) then
				n = n + 1
			end
		end
		if n <= 0 then return 0 end
		return 1
	end
	local used = {}
	for _, rec in ipairs(item.get_craft_store(player)) do
		if not CraftProfile.craft_is_pure_audit_rec(rec) then
			used[locked_required_cost_from_rec(rec)] = true
		end
	end
	local n = 3
	while used[n] do n = n + 2 end
	return n
end

local function migrate_required_cost_once(bucket)
	if type(bucket) ~= "table" or bucket.cost_migrated_v2 == true then return end
	for _, rec in ipairs(bucket) do
		if type(rec) == "table" then
			local n = locked_required_cost_from_rec(rec)
			if n > 1 then
				local kept = {}
				local kept_real = 0
				for _, entry in ipairs(rec.cost_items or {}) do
					if CraftProfile.is_real_entry(entry, rec.audit == true) then
						if kept_real < 1 then
							kept[#kept + 1] = entry
							kept_real = kept_real + 1
						end
					else
						kept[#kept + 1] = entry
					end
				end
				rec.cost_items = kept
				rec.required_cost = 1
			elseif n == 0 then
				rec.required_cost = 0
			else
				rec.required_cost = 1
			end
		end
	end
	bucket.cost_migrated_v2 = true
end

local function panel_alpha()
	local a = item._draw_alpha
	if a == nil then return 1 end
	return a
end

local function tint_kcolor(color, mul_a)
	color = color or KColor(1, 1, 1, 1)
	mul_a = mul_a or panel_alpha()
	return KColor(color.Red, color.Green, color.Blue, (color.Alpha or 1) * mul_a)
end

local function tint_color(r, g, b, a)
	return Color(r or 1, g or 1, b or 1, (a or 1) * panel_alpha())
end

local TUT_DIM = KColor(0.4, 0.4, 0.46, 0.42)
local function tut_dim_id(id, color)
	if get_tutorial().is_locking() and not get_tutorial().allows(id) then
		return TUT_DIM
	end
	return color
end

--- 成本小槽中的道具不参与配方效果：无论其原始状态，图标都显示为真灰度。
--- 这里只供 tok.cost 使用；背包/材料槽继续沿用原有 Tint 状态色。
local function cost_token_color()
	local a = panel_alpha()
	return auxi.table2color({R = 0.88, G = 0.88, B = 0.88, A = a * 0.88, RC = 1, GC = 1, BC = 1, AC = 1})
end

local function clear_sprite_color(spr)
	if not spr then return end
	spr.Color = auxi.table2color({R = 1, G = 1, B = 1, A = 1, RC = 0, GC = 0, BC = 0, AC = 0})
end

--- 在矩形内绘制文本（水平居中 + 垂直居中；可选左对齐留白）
local function draw_text_in_rect(rect, text, color, opts)
	if not rect or not text then return end
	opts = opts or {}
	local sx = opts.sx or 1
	local sy = opts.sy or 1
	local font = opts.font or gui.f
	local line_h = (font.GetLineHeight and font:GetLineHeight() or 12) * sy
	local pad_x = opts.pad_x or 0
	local y = rect.y + (opts.pad_y ~= nil and opts.pad_y or ((rect.h - line_h) * 0.5))
	local x = rect.x + pad_x
	local box_w = math.max(0, math.floor(rect.w - pad_x * 2))
	color = tint_kcolor(color)
	if opts.align == "left" then
		font:DrawStringScaledUTF8(text, x, y, sx, sy, color, 0, false)
	else
		font:DrawStringScaledUTF8(text, x, y, sx, sy, color, box_w, true)
	end
end

local function lang_is_zh()
	return Options.Language == "zh" or Options.Language == "zh_cn"
end

local function tab_label(tab)
	return lang_is_zh() and tab.zh or tab.en
end

local function next_serial_for_target(player, target, exclude_uid)
	local max_s = 0
	for _, rec in ipairs(item.get_crafted_list(player) or {}) do
		if rec.target == target and rec.uid ~= exclude_uid then
			local s = tonumber(rec.serial) or 0
			if s > max_s then max_s = s end
		end
	end
	return max_s + 1
end

--- 建造页：下一项序号的「空行XX号 / 空怖XX号」（不含附加型号）
local function target_label(info, player)
	if not info then return "?" end
	local serial = next_serial_for_target(player, info.id)
	return CraftProfile.build_display_name(info.id, serial, nil, lang_is_zh())
end

--- 材料 + 成本槽道具一并参与附加型号字母抽取
local function naming_ingredients(ingredients, cost_items)
	local merged = {}
	local n = 0
	for k, entry in pairs(ingredients or {}) do
		local idx = tonumber(k)
		if idx then
			merged[idx] = CraftProfile.ingredient_id(entry) or entry
			if idx > n then n = idx end
		end
	end
	for _, id in ipairs(cost_items or {}) do
		n = n + 1
		merged[n] = CraftProfile.ingredient_id(id) or id
	end
	return merged
end

local function ensure_rec_serial(player, rec)
	if not rec or tonumber(rec.serial) then return end
	local n = 0
	for _, r in ipairs(item.get_crafted_list(player) or {}) do
		if r.target == rec.target then
			n = n + 1
			if r.uid == rec.uid then
				rec.serial = n
				return
			end
		end
	end
	rec.serial = n + 1
end

local function refresh_rec_display_name(rec, player)
	if not rec then return end
	if player then ensure_rec_serial(player, rec) end
	local serial = tonumber(rec.serial) or 1
	local src = naming_ingredients(rec.ingredients, rec.cost_items)
	rec.display_name = CraftProfile.build_display_name(rec.target, serial, src, true)
	rec.display_name_en = CraftProfile.build_display_name(rec.target, serial, src, false)
end

local function rec_label(rec)
	if not rec then return "?" end
	local zh = lang_is_zh()
	local name = zh and rec.display_name or rec.display_name_en
	if not name or name == "" then
		name = CraftProfile.build_display_name(rec.target, rec.serial or 1, naming_ingredients(rec.ingredients, rec.cost_items), zh)
	end
	local tag = (rec.audit and rec.tutorial ~= true) and (zh and " [审]" or " [A]") or ""
	local bang = rec.broken and "!" or ""
	return bang .. name .. tag
end

local function rec_loadout_ids(rec)
	local base_id = nil
	local mods = {}
	if not rec then return base_id, mods end
	for _, entry in ipairs(rec.cost_items or {}) do
		local id = CraftProfile.ingredient_id(entry)
		if id and id > 0 then
			if not base_id then
				base_id = id
			else
				mods[#mods + 1] = id
			end
		end
	end
	local keys = {}
	for k, _ in pairs(rec.ingredients or {}) do
		local idx = tonumber(k) or k
		if type(idx) == "number" then keys[#keys + 1] = idx end
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local entry = rec.ingredients[k] or rec.ingredients[tostring(k)]
		local id = CraftProfile.ingredient_id(entry)
		if id and id > 0 then mods[#mods + 1] = id end
	end
	return base_id, mods
end

local function player_exists_safe(player)
	if not player then return false end
	local ok, exists = pcall(function() return player:Exists() end)
	return ok and exists == true
end

--- 面板是否仍绑定有效玩家（重启/换局后残留引用视为无效）
local function panel_is_alive()
	if item.panel == nil then return false end
	-- 重开后 FrameCount 回绕，但 Exists() 偶发仍对旧 userdata 返回 true
	local opened = item.panel.opened_frame
	if opened ~= nil and Game():GetFrameCount() < opened then
		item.panel = nil
		item.suppress_open_until = -1
		pcall(function() auxi.time_free(item.own_key) end)
		pcall(restore_eid_after_blueprint)
		return false
	end
	return player_exists_safe(item.panel.player)
end

local function same_panel_player(player)
	if not panel_is_alive() or not player then return false end
	local ok, same = pcall(function()
		return auxi.check_for_the_same(item.panel.player, player)
	end)
	return ok and same == true
end

local drop_held_blueprint, scrub_stale_panel -- forward decl（定义在 close_panel 之后）

local function get_target_info(col_id)
	for _, info in ipairs(item.build_targets) do
		if info.id == col_id then return info end
	end
end

local function player_key(player)
	if not player or not player_exists_safe(player) then return "0" end
	local ok, key = pcall(function()
		local data = player:GetData()
		return data.__Index or player.InitSeed
	end)
	return (ok and key ~= nil) and tostring(key) or "0"
end

-- pack 曾把 tostring 键误收成数字键；读档后 by_player[0] 有数据但运行时查 ["0"]。
local function merge_blueprint_bucket(dst, src)
	if type(dst) ~= "table" or type(src) ~= "table" then return dst or src end
	for i = 1, #src do
		table.insert(dst, src[i])
	end
	if type(src.prototypes) == "table" then
		dst.prototypes = dst.prototypes or {}
		for pk, pv in pairs(src.prototypes) do
			local sk = tostring(pk)
			if dst.prototypes[sk] == nil then dst.prototypes[sk] = pv end
		end
	end
	if type(src.drafts) == "table" then
		dst.drafts = dst.drafts or {}
		for dk, dv in pairs(src.drafts) do
			if dst.drafts[dk] == nil then dst.drafts[dk] = dv end
		end
	end
	if type(src.audit_ui) == "table" and dst.audit_ui == nil then
		dst.audit_ui = src.audit_ui
	end
	return dst
end

local function heal_string_keyed_map(map)
	if type(map) ~= "table" then return map end
	local moved = {}
	for k, v in pairs(map) do
		if type(k) == "number" and k == math.floor(k) then
			moved[#moved + 1] = {k, v}
		end
	end
	for i = 1, #moved do
		local nk, v = moved[i][1], moved[i][2]
		local sk = tostring(nk)
		if map[sk] == nil then
			map[sk] = v
		elseif type(map[sk]) == "table" and type(v) == "table" then
			-- 两边都有：合并字段，避免丢原型
			for fk, fv in pairs(v) do
				if map[sk][fk] == nil then map[sk][fk] = fv end
			end
		end
		map[nk] = nil
	end
	return map
end

local function heal_blueprint_root(root)
	if type(root) ~= "table" then return root end
	root.by_player = root.by_player or {}
	local bp = root.by_player
	local numeric = {}
	for k, bucket in pairs(bp) do
		if type(k) == "number" then
			numeric[#numeric + 1] = {k, bucket}
		end
	end
	for i = 1, #numeric do
		local nk, bucket = numeric[i][1], numeric[i][2]
		local sk = tostring(nk)
		if bp[sk] == nil then
			bp[sk] = bucket
		else
			bp[sk] = merge_blueprint_bucket(bp[sk], bucket)
		end
		bp[nk] = nil
	end
	for _, bucket in pairs(bp) do
		if type(bucket) == "table" then
			bucket.prototypes = heal_string_keyed_map(bucket.prototypes)
		end
	end
	return root
end

local function ensure_save()
	save.elses.Qing_Blue_Print = heal_blueprint_root(save.elses.Qing_Blue_Print or {
		uid_counter = 0,
		by_player = {},
	})
	return save.elses.Qing_Blue_Print
end

local function checkpoint_run_save(reason)
	if save.RuntimeLoaded ~= true or type(save.SaveModData) ~= "function" then return false end
	local ok, result = pcall(save.SaveModData, "blueprint:"..tostring(reason or "unknown"))
	if not ok then
		print("QING:: Blueprint checkpoint failed ("..tostring(reason or "unknown").."): "..tostring(result))
		return false
	end
	return result ~= false
end

local function get_player_bucket(player)
	local root = ensure_save()
	local key = player_key(player)
	root.by_player[key] = root.by_player[key] or {}
	return root.by_player[key]
end

function item.get_craft_store(player)
	local bucket = get_player_bucket(player)
	if player and player:GetPlayerType() == enums.Players.Spwq then
		migrate_required_cost_once(bucket)
	end
	return bucket
end

function item.count_crafts_for_target(player, target_id)
	target_id = tonumber(target_id)
	if not player or not target_id then return 0 end
	local n = 0
	for _, rec in ipairs(item.get_craft_store(player) or {}) do
		if rec and rec.target == target_id then
			n = n + 1
		end
	end
	return n
end

--- 旧档曾给每架成品发过对应收藏品；按成品数各扣一件，剩下的才是底座拾取。
function item.migrate_strip_granted_craft_items(player)
	if not player then return false end
	local bucket = get_player_bucket(player)
	if bucket.stripped_granted_craft_items then return false end
	bucket.stripped_granted_craft_items = true
	local removed = false
	for _, rec in ipairs(bucket) do
		local t = rec and rec.target
		if t == enums.Items.Air_Flight or t == enums.Items.Air_Terror then
			if player:HasCollectible(t, true) then
				player:RemoveCollectible(t)
				removed = true
			end
		end
	end
	if removed then
		checkpoint_run_save("strip_granted_craft_items")
	end
	return removed
end

--- CheckFamiliar 用：真实持有份数 + 蓝图库存份数（制造不再发收藏品）
function item.familiar_check_count(player, collectible_id)
	collectible_id = tonumber(collectible_id)
	if not player or not collectible_id then return 0 end
	item.migrate_strip_granted_craft_items(player)
	local held = player:GetCollectibleNum(collectible_id) or 0
	return held + item.count_crafts_for_target(player, collectible_id)
end

--- 原型全局元数据（清房保底、交易房限额等）
function item.ensure_prototype_root()
	local root = ensure_save()
	root.prototype_uid_counter = root.prototype_uid_counter or 0
	root.clean_streak = root.clean_streak or 0
	root.shop_proto_rooms = root.shop_proto_rooms or {}
	return root
end

local function get_prototype_inv(player)
	local bucket = get_player_bucket(player)
	bucket.prototypes = bucket.prototypes or {}
	return bucket.prototypes
end

function item.add_prototype(player, collectible_id, meta)
	if not player then return nil end
	collectible_id = tonumber(collectible_id)
	if not collectible_id or not CraftProfile.is_prototype_eligible(collectible_id) then
		return nil
	end
	local root = item.ensure_prototype_root()
	root.prototype_uid_counter = (root.prototype_uid_counter or 0) + 1
	local uid = root.prototype_uid_counter
	local inv = get_prototype_inv(player)
	inv[tostring(uid)] = {
		uid = uid,
		id = collectible_id,
		pool = meta and meta.pool,
		quality = meta and meta.quality,
		source = meta and meta.source or "pickup",
	}
	checkpoint_run_save("prototype_add")
	item.refresh_craft_integrity(player)
	return uid
end

function item.get_prototype(player, uid)
	if not player or uid == nil then return nil end
	return get_prototype_inv(player)[tostring(uid)]
end

function item.clear_prototypes(player)
	if not player then return end
	local bucket = get_player_bucket(player)
	bucket.prototypes = {}
	checkpoint_run_save("prototype_clear")
end

function item.list_free_prototypes(player, exclude_uid)
	local out = {}
	local used = item.count_allocated_prototypes(player, exclude_uid)
	for _, rec in pairs(get_prototype_inv(player)) do
		local uid = rec.uid or tonumber(rec.uid)
		if uid and not used[uid] and not used[tostring(uid)]
			and not CraftProfile.is_ingredient_banned(rec.id) then
			out[#out + 1] = {
				collectible = rec.id,
				source = "prototype",
				prototype_uid = uid,
			}
		end
	end
	table.sort(out, function(a, b)
		return (a.prototype_uid or 0) < (b.prototype_uid or 0)
	end)
	return out
end

function item.count_allocated_prototypes(player, exclude_uid)
	local used = {}
	for _, rec in ipairs(item.get_craft_store(player)) do
		-- 按条目占用：审计槽不占原型；混装配方里的原型仍占
		if rec.uid ~= exclude_uid and not CraftProfile.craft_revive_is_locked(rec) then
			for _, entry in pairs(rec.ingredients or {}) do
				if CraftProfile.is_prototype_entry(entry) then
					local uid = entry.prototype_uid
					used[uid] = true
					used[tostring(uid)] = true
				end
			end
		end
	end
	return used
end

local function draft_key(target_id, edit_uid)
	if edit_uid then return "e_"..tostring(edit_uid) end
	return "t_"..tostring(target_id or 0)
end

local function get_drafts(player)
	local bucket = get_player_bucket(player)
	bucket.drafts = bucket.drafts or {}
	return bucket.drafts
end

--- 审计全道具 UI 偏好（标签筛选等），跨打开复原
--- tag_status_schema=2：状态标签并入后，清掉旧「仅有效」迁移留下的 invalid/unimplemented=false
local AUDIT_TAG_STATUS_SCHEMA = 2
local function get_audit_ui_prefs(player)
	local bucket = get_player_bucket(player)
	bucket.audit_ui = bucket.audit_ui or {}
	local prefs = bucket.audit_ui
	if prefs.tag_status_schema ~= AUDIT_TAG_STATUS_SCHEMA then
		prefs.tag_status_schema = AUDIT_TAG_STATUS_SCHEMA
		if type(prefs.tag_enabled) == "table" then
			prefs.tag_enabled.valid = true
			prefs.tag_enabled.invalid = true
			prefs.tag_enabled.unimplemented = true
		end
		prefs.hide_gray = false
		prefs.audit_filter = "all"
	end
	return prefs
end

local function clear_craft_draft(player, target_id, edit_uid)
	if not player then return end
	local drafts = get_drafts(player)
	drafts[draft_key(target_id, edit_uid)] = nil
end

local filter_draft_items, save_craft_draft, refresh_craft_token_lost
local apply_module_slots_for_base

function item.get_crafted_list(player)
	return item.get_craft_store(player)
end

--- Collectible instances already locked into other crafts (items stay in bag, but cannot be reused).
function item.count_allocated(player, exclude_uid)
	local used = {}
	local function add_id(id)
		id = tonumber(id) or id
		if id and id ~= 0 then used[id] = (used[id] or 0) + 1 end
	end
	for _, rec in ipairs(item.get_craft_store(player)) do
		-- 仅 real 条目占背包配额；audit/prototype 不占
		-- 制造复活锁定：材料不占用配额，便于背包取回后改其它配方/手动修理
		if rec.uid ~= exclude_uid and not CraftProfile.craft_revive_is_locked(rec) then
			local fb = rec.audit == true
			for _, entry in pairs(rec.ingredients or {}) do
				if CraftProfile.is_real_entry(entry, fb) then
					add_id(CraftProfile.ingredient_id(entry))
				end
			end
			for _, entry in ipairs(rec.cost_items or {}) do
				if CraftProfile.is_real_entry(entry, fb) then
					add_id(CraftProfile.ingredient_id(entry))
				end
			end
		end
	end
	return used
end

--- 统计某配方需要的真实道具份数（不含原型/审计）
local function craft_need_real_counts(rec)
	local need = {}
	if not rec then return need end
	local fb = rec.audit == true
	local function add(id)
		id = tonumber(id)
		if id and id > 0 then need[id] = (need[id] or 0) + 1 end
	end
	for _, entry in pairs(rec.ingredients or {}) do
		if CraftProfile.is_real_entry(entry, fb) then
			add(CraftProfile.ingredient_id(entry))
		end
	end
	for _, entry in ipairs(rec.cost_items or {}) do
		if CraftProfile.is_real_entry(entry, fb) then
			add(CraftProfile.ingredient_id(entry))
		end
	end
	return need
end

local function craft_need_prototype_uids(rec)
	local uids = {}
	if not rec then return uids end
	for _, entry in pairs(rec.ingredients or {}) do
		if CraftProfile.is_prototype_entry(entry) then
			local uid = entry.prototype_uid
			if uid ~= nil then
				uids[uid] = true
				uids[tostring(uid)] = true
			end
		end
	end
	return uids
end

--- 同名多份匹配：优先「场上已绑定飞行器」的配方，其余按 uid 升序（先造先占）
function item.ordered_crafts_for_allocation(player)
	local bound = {}
	if player then
		for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, enums.Familiars.QingsAirs, -1, false, false)) do
			local p = auxi.check_spawner_player(fam)
			if p and auxi.check_for_the_same(p, player) and auxi.check_all_exists(fam) then
				local uid = fam:GetData()[item.own_key.."craft_uid"]
				if uid then bound[uid] = true end
			end
		end
	end
	local list = {}
	for _, rec in ipairs(item.get_craft_store(player) or {}) do
		-- 纯审计无 real/prototype 配额；混装仍参与完整性/分配
		if not CraftProfile.craft_is_pure_audit_rec(rec) then list[#list + 1] = rec end
	end
	table.sort(list, function(a, b)
		local ab = bound[a.uid] and 1 or 0
		local bb = bound[b.uid] and 1 or 0
		if ab ~= bb then return ab > bb end
		return (tonumber(a.uid) or 0) < (tonumber(b.uid) or 0)
	end)
	return list
end

--- 刷新配方完整性：缺真实材料或原型丢失 → rec.broken=true
--- 返回 map[uid]=broken
function item.refresh_craft_integrity(player)
	local result = {}
	if not player then return result end
	local fr = Game():GetFrameCount()
	local ptr = GetPtrHash(player)
	if item._integrity_fr == fr and item._integrity_player == ptr and item._integrity_result then
		return item._integrity_result
	end
	local store = item.get_craft_store(player)
	if not store or #store == 0 then
		item._integrity_fr = fr
		item._integrity_player = ptr
		item._integrity_result = result
		return result
	end
	local remain = {}
	local config = Isaac.GetItemConfig()
	local size = config and config:GetCollectibles() and config:GetCollectibles().Size or 0
	for id = 1, size do
		local n = player:GetCollectibleNum(id, true)
		if n and n > 0 then remain[id] = n end
	end
	local proto_inv = get_prototype_inv(player)
	local proto_ok = {}
	for _, prec in pairs(proto_inv or {}) do
		local uid = prec.uid
		if uid ~= nil then
			proto_ok[uid] = true
			proto_ok[tostring(uid)] = true
		end
	end
	for _, rec in ipairs(item.ordered_crafts_for_allocation(player)) do
		local locked = CraftProfile.craft_revive_is_locked(rec)
		local broken = false
		local missing = {}
		local need = craft_need_real_counts(rec)
		if locked then
			-- 有制造复活状态：材料即使齐也不自动修好/回填；且不扣 remain
			broken = true
			for id, n in pairs(need) do
				local have = remain[id] or 0
				if have < n then
					missing[id] = n - have
				end
			end
			missing.craft_revive_locked = true
			local seen_proto = {}
			for _, entry in pairs(rec.ingredients or {}) do
				if CraftProfile.is_prototype_entry(entry) then
					local uid = entry.prototype_uid
					local key = tostring(uid)
					if uid ~= nil and not seen_proto[key] then
						seen_proto[key] = true
						if not proto_ok[uid] and not proto_ok[key] then
							missing.prototype = true
							missing.prototype_uids = missing.prototype_uids or {}
							missing.prototype_uids[uid] = true
							missing.prototype_uids[key] = true
							local id = CraftProfile.ingredient_id(entry)
							if id then
								missing[id] = (missing[id] or 0) + 1
							end
						end
					end
				end
			end
		else
			for id, n in pairs(need) do
				local have = remain[id] or 0
				if have < n then
					broken = true
					missing[id] = n - have
					remain[id] = 0
				else
					remain[id] = have - n
				end
			end
			local seen_proto = {}
			for _, entry in pairs(rec.ingredients or {}) do
				if CraftProfile.is_prototype_entry(entry) then
					local uid = entry.prototype_uid
					local key = tostring(uid)
					if uid ~= nil and not seen_proto[key] then
						seen_proto[key] = true
						if not proto_ok[uid] and not proto_ok[key] then
							broken = true
							missing.prototype = true
							missing.prototype_uids = missing.prototype_uids or {}
							missing.prototype_uids[uid] = true
							missing.prototype_uids[key] = true
							local id = CraftProfile.ingredient_id(entry)
							if id then
								missing[id] = (missing[id] or 0) + 1
							end
						end
					end
				end
			end
		end
		rec.broken = broken
		rec.broken_missing = broken and missing or nil
		result[rec.uid] = broken
	end
	-- 缺料变化后重算 imitate：卸掉「普通配方失去材料却补发的临时宝宝」
	local parts = {}
	for uid, br in pairs(result) do
		parts[#parts + 1] = tostring(uid) .. (br and ":1" or ":0")
	end
	table.sort(parts)
	local sig = table.concat(parts, ",")
	item._integrity_sim_sig = item._integrity_sim_sig or {}
	if item._integrity_sim_sig[ptr] ~= sig then
		item._integrity_sim_sig[ptr] = sig
		Imitate_item_holder.Evaluate_Imitate_Items(player)
	end
	item._integrity_fr = fr
	item._integrity_player = ptr
	item._integrity_result = result
	return result
end

function item.is_craft_broken(player, uid)
	if not player or not uid then return false end
	-- 只读上次事件刷新的 rec.broken。禁止在 FAMILIAR_UPDATE / 面板渲染里再扫全道具表。
	local rec = item.find_craft(player, uid)
	return rec and rec.broken == true
end

function item.find_craft(player, uid)
	for _, rec in ipairs(item.get_craft_store(player)) do
		if rec.uid == uid then return rec end
	end
end

--- 从库存永久删除一件飞行器/空怖成品：释放宝宝、开放成本档位（不再扣收藏品）
function item.delete_craft(player, uid)
	if not player or uid == nil then return false end
	local store = item.get_craft_store(player)
	local idx, rec
	for i, r in ipairs(store) do
		if r.uid == uid then
			idx = i
			rec = r
			break
		end
	end
	if not rec or not idx then return false end

	local Craft_Familiar_holder = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
	local function release_bound_airs(variant)
		for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant, -1, false, false)) do
			local p = auxi.check_spawner_player(fam)
			if p and auxi.check_for_the_same(p, player) and auxi.check_all_exists(fam) then
				local d = fam:GetData()
				if d[item.own_key.."craft_uid"] == uid then
					if Craft_Familiar_holder.release_for_air then
						pcall(Craft_Familiar_holder.release_for_air, fam)
					end
					fam:Remove()
				end
			end
		end
	end
	if enums.Familiars.QingsAirs then
		release_bound_airs(enums.Familiars.QingsAirs)
	end
	if enums.Familiars.Air_Terror then
		release_bound_airs(enums.Familiars.Air_Terror)
	end

	table.remove(store, idx)
	clear_craft_draft(player, rec.target, uid)

	player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
	player:EvaluateItems()
	item.refresh_craft_integrity(player)
	checkpoint_run_save("craft_delete")
	pcall(function() get_bandwidth().on_craft_removed(player, uid) end)
	return true
end

function item.get_tutorial_save(player)
	local bucket = get_player_bucket(player)
	if type(bucket.tutorial) ~= "table" then
		bucket.tutorial = {offered = false, done = false, declined = false}
	end
	return bucket.tutorial
end

--- 审计练习机：不占真实配额。spec.skip_eval 时由调用方一次性 EvaluateItems。
function item.create_audit_craft(player, spec)
	spec = spec or {}
	if not player then return nil end
	local root = ensure_save()
	local store = item.get_craft_store(player)
	root.uid_counter = (root.uid_counter or 0) + 1
	local uid = root.uid_counter
	local target = spec.target or enums.Items.Air_Flight
	local rec = {
		uid = uid,
		target = target,
		ingredients = spec.ingredients or {},
		cost_items = spec.cost_items or {},
		required_cost = spec.required_cost or 0,
		audit = spec.audit ~= false,
		tutorial = spec.tutorial == true,
		lesson_kind = spec.lesson_kind,
		serial = spec.serial or next_serial_for_target(player, target),
		experimental = false,
		eye_phase = 0,
		base_quality = spec.base_quality,
		remembered_quality = spec.base_quality,
	}
	rec.profile = CraftProfile.build_profile(rec.ingredients, {
		player = player,
		rec = rec,
		commit_state = true,
		base_quality = spec.base_quality,
	})
	if spec.display_name then rec.display_name = spec.display_name end
	if spec.display_name_en then rec.display_name_en = spec.display_name_en end
	if not rec.display_name then
		refresh_rec_display_name(rec, player)
	end
	table.insert(store, rec)
	pcall(function() get_bandwidth().on_craft_added(player, uid) end)
	if spec.active == false then
		pcall(function() get_bandwidth().set_active(player, uid, false) end)
	end
	checkpoint_run_save("craft_tutorial_add")
	if spec.skip_eval ~= true then
		player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
		player:EvaluateItems()
	end
	return rec
end

function item.delete_tutorial_crafts(player)
	if not player then return 0 end
	local uids = {}
	for _, rec in ipairs(item.get_craft_store(player) or {}) do
		if type(rec) == "table" and rec.tutorial == true and rec.uid ~= nil then
			uids[#uids + 1] = rec.uid
		end
	end
	for i = 1, #uids do
		item.delete_craft(player, uids[i])
	end
	return #uids
end

--- opts = {air=, runtime=}；传入后合并动态属性（金币/嗜血/191 等）
function item.get_profile_for_uid(player, uid, opts)
	local rec = item.find_craft(player, uid)
	if not rec then return nil end
	opts = opts or {}
	-- 始终按当前配方重建，保证库存「更改」后立刻生效；动态项随所属玩家实时重算
	rec.profile = CraftProfile.build_profile(rec.ingredients, {
		player = player,
		rec = rec,
		air = opts.air,
		runtime = opts.runtime,
	})
	-- per-craft 设置（巧克力 / Tech X 蓄力）挂在 rec 上，重建后合并
	if rec.main_charge_ratio == nil then
		rec.main_charge_ratio = math.max(rec.chocolate_charge_ratio or 1, rec.techx_charge_ratio or 1)
	end
	CraftProfile.apply_craft_settings(rec.profile, {
		main_charge_ratio = rec.main_charge_ratio,
	})
	rec.profile.craft_uid = uid
	return rec.profile
end

local function clamp_charge_ratio(r)
	return CraftProfile.clamp_charge_ratio(r)
end

local function clamp_choco_ratio(r)
	return clamp_charge_ratio(r)
end

--- 当前配方需要显示的蓄力滑条（自下而上；不依赖后文 read_ingredients）
local function list_charge_sliders(craft)
	if not craft then return {} end
	local ings = {}
	for i, slot in ipairs(craft.slots or {}) do
		local tok = slot.token and craft.token_map and craft.token_map[slot.token]
		if tok and tok.collectible and tok.collectible ~= 0 then
			ings[i] = tok.collectible
		end
	end
	local live = CraftProfile.build_profile(ings)
	local out = {}
	local ex = live.extras or {}
	if ex.chocolate or ex.cursed_eye or (live.weapon or 1) == 9 then
		out[1] = {
			id = "main_charge_slider", key = "main_charge_ratio",
			zh = "主攻击蓄力", en = "Main charge",
			max_ratio = CraftProfile.charge_ratio_max(live),
			snap_marks = ex.cursed_eye == true,
			colors = {
				chocolate = KColor(0.95, 0.58, 0.25, 0.95),
				techx = KColor(0.35, 0.82, 1, 0.95),
				cursed = KColor(0.72, 0.35, 0.9, 0.95),
				mixed = KColor(0.95, 0.82, 0.38, 0.95),
			},
			color_key = ((ex.chocolate and ((live.weapon or 1) == 9 or ex.cursed_eye)) and "mixed")
				or (ex.cursed_eye and "cursed") or ((live.weapon or 1) == 9 and "techx") or "chocolate",
		}
	end
	return out
end

--- Next unbound Air Flight craft uid for this player (for familiar Init).
function item.claim_air_flight_uid(player)
	local store = item.get_craft_store(player)
	local bound = {}
	for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, enums.Familiars.QingsAirs, -1, false, false)) do
		local p = auxi.check_spawner_player(fam)
		if p and auxi.check_for_the_same(p, player) then
			local uid = fam:GetData()[item.own_key.."craft_uid"]
			if uid then bound[uid] = true end
		end
	end
	for _, rec in ipairs(store) do
		if rec.target == enums.Items.Air_Flight and not bound[rec.uid] then
			return rec.uid, item.get_profile_for_uid(player, rec.uid)
		end
	end
end

--- 开场进度 0→1（升起与淡入共用，无前置停顿）
function item.get_panel_open_t()
	local panel = item.panel
	if not panel then return 1 end
	local dur = math.max(1, item.open_rise_dur or 14)
	local u = (Game():GetFrameCount() - (panel.opened_frame or 0)) / dur
	if u <= 0 then return 0 end
	if u >= 1 then return 1 end
	return u
end

function item.get_panel_rise_offset()
	local t = item.get_panel_open_t()
	local dist = item.open_rise_distance or 72
	local e = 1 - (1 - t) ^ 3
	return (1 - e) * dist
end

function item.get_panel_alpha()
	local t = item.get_panel_open_t()
	-- 前半段更快显形，后半段稳住
	local a = t < 0.55 and (t / 0.55) or 1
	return a
end

function item.panel_rise_finished()
	return item.get_panel_open_t() >= 1
end

--- 蓝图面板是否打开（可选限定玩家）。时停期间小青标记仍可能读输入，调用方须自行屏蔽。
function item.is_panel_open(player)
	if not panel_is_alive() then return false end
	if player == nil then return true end
	return same_panel_player(player)
end

function item.get_panel_rect()
	local rise = item.get_panel_rise_offset()
	local center = gui.GetScreenCenter() + item.panel_offset + Vector(0, rise)
	local half = item.panel_size * 0.5
	return {
		x = center.X - half.X,
		y = center.Y - half.Y,
		w = item.panel_size.X,
		h = item.panel_size.Y,
		center = center,
	}
end

function item.get_tab_rects(panel_rect)
	local n = #item.tabs
	local pad = item.content_pad
	local avail_w = panel_rect.w - pad.X * 2
	local tab_w = (avail_w - item.tab_gap * (n - 1)) / n
	local y = panel_rect.y + pad.Y
	local rects = {}
	for i = 1, n do
		local x = panel_rect.x + pad.X + (i - 1) * (tab_w + item.tab_gap)
		rects[i] = Mouse_UI.make_rect(x, y, tab_w, item.tab_height)
	end
	return rects
end

function item.get_content_rect(panel_rect)
	local pad = item.content_pad
	local top = panel_rect.y + pad.Y + item.tab_height + 6
	return Mouse_UI.make_rect(
		panel_rect.x + pad.X,
		top,
		panel_rect.w - pad.X * 2,
		panel_rect.y + panel_rect.h - pad.Y - top
	)
end

local function ensure_bg_sprite()
	if item._bg_sprite == nil then
		local s = Sprite()
		s:Load(item.bg_anm2, true)
		s:Play("Idle", true)
		item._bg_sprite = s
	end
	return item._bg_sprite
end

local function ensure_charge_slider_sprite()
	if item._charge_slider_sprite == nil then
		local s = Sprite()
		s:Load("gfx/mimics/Blueprint/slider.anm2", true)
		s:SetFrame("Idle", 0)
		item._charge_slider_sprite = s
	end
	return item._charge_slider_sprite
end

local function slider_layer_color(kcolor, alpha_mul)
	kcolor = kcolor or KColor(1, 1, 1, 1)
	return Color(
		kcolor.Red, kcolor.Green, kcolor.Blue,
		(kcolor.Alpha or 1) * panel_alpha() * (alpha_mul or 1)
	)
end

local function load_col_sprite(col_id)
	if not col_id then return nil end
	item._col_spr_cache = item._col_spr_cache or {}
	local cached = item._col_spr_cache[col_id]
	if cached then return cached end
	local spr = auxi.load_item(col_id, {
		Anm = "gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",
	})
	item._col_spr_cache[col_id] = spr
	return spr
end

local function quality_to_frame(quality)
	local q = tonumber(quality)
	if q == nil then return 5 end
	if q >= 0 and q <= 4 then return math.floor(q) end
	if q < 0 then return 5 end
	return 6
end

local function get_quality_sprite()
	if item._quality_spr then return item._quality_spr end
	local s = Sprite()
	s:Load(item.quality_anm2, true)
	s:Play("Quality", true)
	item._quality_spr = s
	return s
end

local function render_token_quality_icon(tok)
	if not tok or tok.cost or tok.slot then return end
	if not tok.from_bag then return end
	local q = CraftProfile.collectible_quality(tok.collectible)
	if q == nil then return end
	local s = get_quality_sprite()
	s.Color = Color(1, 1, 1, panel_alpha())
	s:SetFrame("Quality", quality_to_frame(q))
	s:Render(tok.pos + (item.quality_icon_offset or Vector(8, -12)), Vector.Zero, Vector.Zero)
	s.Color = Color(1, 1, 1, 1)
end

local function craft_has_base(craft)
	if not craft then return false end
	for _, tid in ipairs(craft.cost_ids or {}) do
		local tok = craft.token_map and craft.token_map[tid]
		if tok and tok.cost then return true end
	end
	return false
end

local function sync_show_quality(craft)
	if not craft or craft.quality_user_set then return end
	-- 默认关；仅底座空着时自动打开，方便挑品质。
	craft.show_quality = not craft_has_base(craft)
end

local function toggle_show_quality(panel)
	local craft = panel and panel.craft
	if not craft then return end
	craft.quality_user_set = true
	craft.show_quality = not craft.show_quality
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.4, 1, false, 0, 2)
end

local function token_rect(tok)
	return Mouse_UI.make_rect_centered(tok.pos, item.token_size, item.token_size)
end

local function clamp_to_rect(pos, rect, half)
	half = half or item.token_size * 0.5
	return Vector(
		math.max(rect.x + half, math.min(rect.x + rect.w - half, pos.X)),
		math.max(rect.y + half, math.min(rect.y + rect.h - half, pos.Y))
	)
end

local function smoothstep(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

local function begin_snap_anim(tok, target_pos)
	if not tok or not target_pos then return end
	local from = Vector(tok.pos.X, tok.pos.Y)
	local to = Vector(target_pos.X, target_pos.Y)
	local dist = (from - to):Length()
	local dur = item.snap_anim_frames or 10
	-- 远距离略拉长，避免“瞬移感”
	if dist > 36 then
		dur = math.min(28, math.max(dur, math.floor(dur + dist / 18)))
	end
	tok.anim = {
		from = from,
		to = to,
		t = 0,
		dur = dur,
	}
	tok.vel = Vector(0, 0)
end

local function find_empty_ingredient_slot(craft, exclude_index)
	for i, slot in ipairs((craft and craft.slots) or {}) do
		if i ~= exclude_index and not slot.token then
			return i
		end
	end
	return nil
end

--- 被挤出槽位：优先落在当前页道具列下方的空隙，避免插进图标之间
local function bag_area_anchor(tok)
	local panel = item.panel
	local craft = panel and panel.craft
	local g = panel and panel.ui and panel.ui.craft_geom
	local bag = g and g.bag_inner
	if not bag then
		if tok then return Vector(tok.pos.X + 40, tok.pos.Y) end
		return Vector(0, 0)
	end

	local tsize = item.token_size or 28
	local cell = tsize + 4
	local cols = math.max(1, math.floor(bag.w / cell))

	-- 当前页背包图标占用的行数（与 bag_layout_positions 一致）
	local page_count = 0
	if craft then
		for _, t in ipairs(craft.tokens or {}) do
			if t.from_bag then page_count = page_count + 1 end
		end
	end
	local rows_used = (page_count > 0) and math.ceil(page_count / cols) or 0
	local free_top = bag.y + rows_used * cell + 2
	local free_bottom = bag.y + bag.h - 6
	if free_top > free_bottom - tsize then
		free_top = math.max(bag.y + 2, free_bottom - tsize)
	end

	-- 已在空隙带落脚的挤出物，横向错开
	local taken = {}
	if craft then
		for _, t in ipairs(craft.tokens or {}) do
			if t ~= tok and not t.from_bag and not t.slot and not t.cost then
				local p = t.home or (t.anim and t.anim.to) or t.pos
				if p and p.Y >= free_top - cell * 0.35 then
					taken[#taken + 1] = p
				end
			end
		end
	end

	local function blocked(px, py)
		for _, p in ipairs(taken) do
			if math.abs(p.X - px) < cell * 0.85 and math.abs(p.Y - py) < cell * 0.85 then
				return true
			end
		end
		return false
	end

	local y = free_top + tsize * 0.5
	local x0 = bag.x + tsize * 0.5 + 2
	local x = x0
	local guard = 0
	while blocked(x, y) and guard < 48 do
		x = x + cell
		if x > bag.x + bag.w - tsize * 0.5 then
			x = x0
			y = y + cell
			if y > free_bottom - tsize * 0.25 then
				y = free_top + tsize * 0.5
			end
		end
		guard = guard + 1
	end
	return Vector(x, y)
end

local function tick_token_anim(tok)
	local a = tok.anim
	if not a then return false end
	a.t = a.t + 1
	local u = smoothstep(a.t / a.dur)
	tok.pos = auxi.Lerp(a.from, a.to, u)
	if a.t >= a.dur then
		tok.pos = Vector(a.to.X, a.to.Y)
		tok.anim = nil
		return false
	end
	return true
end

local BAG_SKIP = nil
local function bag_skip_ids()
	if BAG_SKIP then return BAG_SKIP end
	BAG_SKIP = {
		[item.entity] = true,
		[enums.Items.Air_Flight] = true,
		[enums.Items.Air_Terror] = true,
		-- Gemini 已重新开放蓝图材料通道（探针采集期间需要可装配）。
	}
	return BAG_SKIP
end

local function collectible_eligible(col)
	return col and not col.Hidden
		and (col.Type == ItemType.ITEM_PASSIVE or col.Type == ItemType.ITEM_FAMILIAR or col.Type == ItemType.ITEM_ACTIVE)
end

-- ---------- 背包收集（真实持有 − 已分配给其他飞行器 − 当前槽占用）+ 空闲原型----------
-- 返回混合列表：number（真实）或 {collectible, source="prototype", prototype_uid}
local function collect_bag_items(player, exclude_uid, slot_reserve)
	local list = {}
	local used = item.count_allocated(player, exclude_uid)
	local reserve_real = slot_reserve and slot_reserve.real or slot_reserve or {}
	for id, n in pairs(reserve_real) do
		if type(id) == "number" or tonumber(id) then
			local nid = tonumber(id) or id
			used[nid] = (used[nid] or 0) + n
		end
	end
	local config = Isaac.GetItemConfig()
	local size = config:GetCollectibles().Size
	local skip = bag_skip_ids()
	for id = 1, size do
		if not skip[id] then
			local col = config:GetCollectible(id)
			if collectible_eligible(col) then
				local num = player:GetCollectibleNum(id, true) - (used[id] or 0)
				for _ = 1, num do
					table.insert(list, id)
				end
			end
		end
	end
	local reserved_proto = slot_reserve and slot_reserve.proto or {}
	for _, entry in ipairs(item.list_free_prototypes(player, exclude_uid)) do
		local uid = entry.prototype_uid
		if not reserved_proto[uid] and not reserved_proto[tostring(uid)] then
			list[#list + 1] = entry
		end
	end
	return list
end

local function bag_entry_collectible(entry)
	if type(entry) == "table" then return entry.collectible or entry.id end
	return entry
end

local function bag_entry_is_proto(entry)
	return type(entry) == "table" and entry.source == "prototype"
end

--- 全道具模式：配置表全部可显示道具（每种一份，便于审查兼容）。
local function collect_all_catalog_items()
	local list = {}
	local config = Isaac.GetItemConfig()
	local size = config:GetCollectibles().Size
	local skip = bag_skip_ids()
	for id = 1, size do
		if not skip[id] then
			local col = config:GetCollectible(id)
			if collectible_eligible(col) then
				list[#list + 1] = id
			end
		end
	end
	return list
end

local function page_slice(list, page, page_size)
	page = math.max(0, page or 0)
	page_size = page_size or item.bag_page_size
	local total = #list
	local pages = math.max(1, math.ceil(total / page_size))
	if page >= pages then page = pages - 1 end
	local from = page * page_size + 1
	local to = math.min(total, from + page_size - 1)
	local slice = {}
	for i = from, to do
		slice[#slice + 1] = list[i]
	end
	return slice, page, pages, total
end

local function slot_reserve_from_craft(craft)
	local reserve = {real = {}, proto = {}}
	if not craft then return reserve end
	local function add(tok)
		if not tok or not tok.collectible then return end
		if tok.source == "prototype" and tok.prototype_uid then
			reserve.proto[tok.prototype_uid] = true
			reserve.proto[tostring(tok.prototype_uid)] = true
		else
			local id = tok.collectible
			reserve.real[id] = (reserve.real[id] or 0) + 1
		end
	end
	for _, slot in ipairs(craft.slots or {}) do
		if slot.token then add(craft.token_map[slot.token]) end
	end
	for _, tid in ipairs(craft.cost_ids or {}) do
		add(craft.token_map[tid])
	end
	-- 非审计：拖出/动画中的已占用 token（未回槽也未 from_bag）也要计入，防同 id 虚增
	if not craft.all_items then
		for _, tok in ipairs(craft.tokens or {}) do
			if tok and not tok.slot and not tok.cost and not tok.from_bag then
				add(tok)
			end
		end
	end
	return reserve
end

local function bag_layout_positions(bag_rect, count)
	local positions = {}
	local cell = item.token_size + 4
	local cols = math.max(1, math.floor(bag_rect.w / cell))
	for i = 1, count do
		local idx = i - 1
		local cx = bag_rect.x + (idx % cols) * cell + item.token_size * 0.5 + 2
		local cy = bag_rect.y + math.floor(idx / cols) * cell + item.token_size * 0.5 + 2
		positions[i] = Vector(cx, cy)
	end
	return positions
end

-- ---------- 视图切换 ----------
local function set_tab(panel, idx)
	if idx < 1 or idx > #item.tabs then return end
	if panel.craft then save_craft_draft(panel) end
	panel.tab = idx
	panel.view = "list"
	panel.craft = nil
	panel.drag = nil
	panel.pad_carry = nil
	panel.delete_confirm_uid = nil
	panel.focus_id = "tab_"..idx
	panel.nav_group = "tabs"
	panel.body_focus_mem = nil
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_CLIP_CLOSE, 0.55, 1, false, 0, 2)
end

local function open_craft_view(panel, target_id, edit_uid)
	local info = get_target_info(target_id)
	if not info then return end
	local approx_w = 160
	local ingredients, cost_items = nil, nil
	local draft = get_drafts(panel.player)[draft_key(target_id, edit_uid)]
	local prefs = get_audit_ui_prefs(panel.player)
	local use_all_items = false
	-- 旧三态筛选仅用于迁移进标签；正式筛选走 tag_enabled
	local use_audit_filter = prefs.audit_filter or (prefs.hide_gray == true and "impl" or "all")
	local edit_rec = edit_uid and item.find_craft(panel.player, edit_uid) or nil
	local cost_n_hint = resolve_session_required_cost(panel.player, edit_uid, edit_rec, draft)
	local function rebuild_slots(n, cost_hint)
		local layout = make_slot_layout(n, cost_hint or cost_n_hint, approx_w)
		local slots = {}
		for i, s in ipairs(layout) do
			slots[i] = {ox = s.ox, oy = s.oy, token = nil}
		end
		return slots
	end
	-- 含审计材料的成品：默认打开全道具目录
	local edit_has_audit = edit_rec and CraftProfile.craft_has_any_audit_rec(edit_rec)
	if edit_has_audit then
		use_all_items = true
		use_audit_filter = edit_rec.audit_filter or use_audit_filter
	end
	if draft then
		if not edit_has_audit then
			use_all_items = draft.all_items == true
		end
		use_audit_filter = draft.audit_filter or use_audit_filter
		ingredients, cost_items = filter_draft_items(
			panel.player, draft.ingredients, draft.cost_items, edit_uid, use_all_items
		)
	elseif edit_rec then
		ingredients = edit_rec.ingredients
		cost_items = edit_rec.cost_items
	end
	local remembered = nil
	if draft and draft.remembered_quality ~= nil then
		remembered = CraftProfile.normalize_base_quality(draft.remembered_quality)
	elseif edit_rec then
		remembered = CraftProfile.normalize_base_quality(edit_rec.base_quality or edit_rec.remembered_quality)
	end
	if get_tutorial().uses_lesson_bag(edit_rec) then
		use_all_items = false
		if not edit_uid then
			ingredients, cost_items = nil, nil
			remembered = nil
			draft = nil
		end
	end
	local live_q = CraftProfile.quality_from_cost_items(cost_items)
	if live_q ~= nil then remembered = live_q end
	local slot_n = CraftProfile.slots_for_base_quality(remembered)
	local slots = rebuild_slots(slot_n, cost_n_hint)
	local main_ratio = 1
	if draft then main_ratio = draft.main_charge_ratio or draft.chocolate_charge_ratio or draft.techx_charge_ratio or 1
	elseif edit_rec then main_ratio = edit_rec.main_charge_ratio or edit_rec.chocolate_charge_ratio or edit_rec.techx_charge_ratio or 1 end
	main_ratio = clamp_charge_ratio(main_ratio)
	local tag_src = (edit_rec and edit_rec.tag_enabled)
		or (draft and draft.tag_enabled)
		or prefs.tag_enabled
	local use_tag_enabled = CraftProfile.normalize_audit_tag_enabled(tag_src, use_audit_filter)
	prefs.tag_enabled = use_tag_enabled
	prefs.audit_filter = "all"
	prefs.hide_gray = false
	panel.delete_confirm_uid = nil
	panel.view = edit_uid and "edit" or "craft"
	panel.craft = {
		target = target_id,
		info = info,
		edit_uid = edit_uid,
		slots = slots,
		slot_count = slot_n,
		cost_ids = {},
		tokens = {},
		token_map = {},
		snapshot = nil,
		all_items = use_all_items,
		tutorial_bag = get_tutorial().uses_lesson_bag(edit_rec),
		show_quality = false,
		quality_user_set = false,
		hide_gray = false,
		audit_filter = "all",
		tag_enabled = use_tag_enabled,
		bag_page = 0,
		_bag_dirty = true,
		_catalog = nil,
		_catalog_impl = nil,
		_catalog_missing_stat = nil,
		required_cost = cost_n_hint,
		main_charge_ratio = main_ratio,
		base_quality = live_q,
		remembered_quality = remembered,
	}
	if ingredients then
		local edit_fb = edit_rec and edit_rec.audit == true
		for i, entry in pairs(ingredients) do
			local idx = tonumber(i) or i
			local col = CraftProfile.ingredient_id(entry)
			local src = CraftProfile.ingredient_source(entry, edit_fb)
			local is_proto = src == "prototype"
			if slots[idx] and col and col ~= 0 then
				local tid = is_proto
					and ("slotfill_"..idx.."_p"..tostring(entry.prototype_uid))
					or ("slotfill_"..idx.."_"..col)
				local tok = {
					id = tid,
					collectible = col,
					source = src,
					prototype_uid = is_proto and entry.prototype_uid or nil,
					is_prototype = is_proto,
					pos = Vector(0, 0),
					vel = Vector(0, 0),
					slot = idx,
					from_bag = false,
					sprite = load_col_sprite(col),
					impl = CraftProfile.has_impl(col),
					gate_kind = CraftProfile.effect_gate_kind(col),
					visual_scale = 1,
				}
				panel.craft.tokens[#panel.craft.tokens + 1] = tok
				panel.craft.token_map[tid] = tok
				slots[idx].token = tid
			end
		end
		local snap = {}
		for k, v in pairs(ingredients) do snap[k] = v end
		panel.craft.snapshot = snap
	end
	if cost_items then
		local edit_fb = edit_rec and edit_rec.audit == true
		for ci, entry in ipairs(cost_items) do
			local col = CraftProfile.ingredient_id(entry)
			local src = CraftProfile.ingredient_source(entry, edit_fb)
			if col and col ~= 0 then
				local tid = "costfill_"..ci.."_"..col
				local tok = {
					id = tid,
					collectible = col,
					source = src,
					pos = Vector(0, 0),
					vel = Vector(0, 0),
					cost = true,
					from_bag = false,
					sprite = load_col_sprite(col),
					impl = CraftProfile.has_impl(col),
					gate_kind = CraftProfile.effect_gate_kind(col),
					visual_scale = get_cost_token_scale(),
				}
				panel.craft.tokens[#panel.craft.tokens + 1] = tok
				panel.craft.token_map[tid] = tok
				panel.craft.cost_ids[#panel.craft.cost_ids + 1] = tid
			end
		end
	end
	-- 草稿里放在背包区的失去道具：重进时仍显示为红色幽灵
	if draft and draft.bag_ghosts and not use_all_items then
		for gi, col in ipairs(draft.bag_ghosts) do
			col = tonumber(col) or col
			if col and col ~= 0 then
				local tid = "ghostbag_"..gi.."_"..tostring(col)
				local tok = {
					id = tid,
					collectible = col,
					pos = Vector(0, 0),
					vel = Vector(0, 0),
					from_bag = true,
					lost = true,
					lost_ghost = true,
					sprite = load_col_sprite(col),
					impl = CraftProfile.has_impl(col),
					gate_kind = CraftProfile.effect_gate_kind(col),
					visual_scale = 1,
				}
				panel.craft.tokens[#panel.craft.tokens + 1] = tok
				panel.craft.token_map[tid] = tok
			end
		end
	end
	refresh_craft_token_lost(panel.player, panel.craft)
	sync_show_quality(panel.craft)
	panel.drag = nil
	panel.pad_carry = nil
	panel.focus_id = "btn_confirm"
	panel.nav_group = "body"
	panel.body_focus_mem = "btn_confirm"
end

function item.open_tutorial_craft_view(panel)
	if not panel then return end
	open_craft_view(panel, enums.Items.Air_Flight, nil)
end

--- opts.clear_draft：确认成功后清草稿；opts.skip_draft：不再读写草稿
local function leave_craft_view(panel, opts)
	opts = opts or {}
	if panel and panel.craft and panel.player and not opts.skip_draft then
		if opts.clear_draft then
			clear_craft_draft(panel.player, panel.craft.target, panel.craft.edit_uid)
		else
			save_craft_draft(panel)
		end
	end
	panel.view = "list"
	panel.craft = nil
	panel.drag = nil
	panel.pad_carry = nil
	panel.focus_id = "tab_"..tostring(panel.tab or 1)
	panel.nav_group = "tabs"
	panel.body_focus_mem = nil
end

local function clear_blueprint_selection(player)
	pcall(function()
		local function safe_remove(p)
			if not player_exists_safe(p) then return end
			selection_holder.remove_select(p, selection_key)
		end
		if player then
			safe_remove(player)
			return
		end
		local n = Game():GetNumPlayers()
		if not n or n < 1 then return end
		for i = 0, n - 1 do
			safe_remove(Game():GetPlayer(i))
		end
	end)
end

-- 蓝图面板打开期间暂时隐藏 EID（关闭后恢复原状态）
local eid_hide_state = nil -- nil=未接管; bool=打开前 isHidden

local function hide_eid_for_blueprint()
	if not EID then return end
	if eid_hide_state == nil then
		eid_hide_state = EID.isHidden and true or false
	end
	EID.isHidden = true
end

local function restore_eid_after_blueprint()
	if eid_hide_state == nil then return end
	if EID then
		EID.isHidden = eid_hide_state
	end
	eid_hide_state = nil
end

local function close_panel(skip_draft)
	if not item.panel then
		-- 无面板时勿强行遍历玩家清选择（暂停重置途中不安全）
		pcall(function() auxi.time_free(item.own_key) end)
		restore_eid_after_blueprint()
		return
	end
	-- 重置/换房时 panel.player 可能已失效：只在仍 Exists 时碰 GetData
	local alive_player = player_exists_safe(item.panel.player) and item.panel.player or nil
	if not skip_draft and item.panel.craft and alive_player then
		pcall(function() save_craft_draft(item.panel) end)
	end
	pcall(function() get_tutorial().on_panel_closed(alive_player) end)
	-- 先清 panel，避免换房时实体失效导致半清理卡死
	item.panel = nil
	item.suppress_open_until = Game():GetFrameCount() + 2
	if alive_player then
		clear_blueprint_selection(alive_player)
		drop_held_blueprint(alive_player)
		pcall(function()
			local Spwq = require("Qing_Remaster_scripts.player.player_Spwq")
			if Spwq and Spwq.seed_formation_hold then
				Spwq.seed_formation_hold(alive_player)
			end
		end)
	end
	-- alive_player 为空时禁止遍历 GetPlayer：暂停菜单重置途中 userdata 上 GetData 会硬崩
	pcall(function() auxi.time_free(item.own_key) end)
	restore_eid_after_blueprint()
end

drop_held_blueprint = function(player)
	if not player_exists_safe(player) then return end
	pcall(function()
		if player:IsHoldingItem() then
			player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
		end
	end)
end

--- 清掉失效/残留面板（重启游戏后 module 级 item.panel 可能仍在）
scrub_stale_panel = function()
	if not item.panel then return false end
	if panel_is_alive() then return false end
	item.panel = nil
	item.suppress_open_until = -1
	-- 面板玩家已失效：禁止 clear_blueprint_selection(nil) / 遍历 GetPlayer（重置时 GetData 会崩）
	pcall(function() auxi.time_free(item.own_key) end)
	restore_eid_after_blueprint()
	return true
end

local function open_panel(player)
	scrub_stale_panel()
	if item.panel then close_panel() end
	-- 换房残留保险
	pcall(function() auxi.time_free(item.own_key) end)
	pcall(function() selection_holder.remove_select(player, selection_key) end)
	drop_held_blueprint(player)
	hide_eid_for_blueprint()
	item.panel = {
		player = player,
		tab = 1,
		view = "list",
		craft = nil,
		drag = nil,
		pad_carry = nil, -- {token_id} 四向模式搬运中
		focus_id = "tab_1",
		nav_group = "tabs",
		body_focus_mem = nil,
		nav_hold = nil,
		lock_until = Game():GetFrameCount() + item.action_delay + (item.open_rise_dur or 14),
		opened_frame = Game():GetFrameCount(),
		input_armed = false,
		wait_drop_release = true,
		was_paused = false,
		ui = {},
		list_selected = 1,
	}
	selection_holder.try_select(player, selection_key)
	player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
	auxi.time_stop(item.own_key)
	item.refresh_craft_integrity(player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 1, 1, false, 0, 2)
	pcall(function() get_tutorial().on_panel_opened(player) end)
end

function item.open_for_player(player)
	if not player then return false end
	scrub_stale_panel()
	if same_panel_player(player) then return true end
	if item.panel then close_panel() end
	open_panel(player)
	return true
end

-- ---------- 制造页几何 ----------
local function craft_geometry(panel_rect, content, craft)
	local mid = content.x + content.w * 0.42
	local left = Mouse_UI.make_rect(content.x, content.y, mid - content.x - 4, content.h)
	local right = Mouse_UI.make_rect(mid + 4, content.y, content.x + content.w - mid - 4, content.h)
	local target_pos = Vector(left.x + left.w * 0.5, left.y + 48 + get_craft_group_y())
	local confirm_rect = Mouse_UI.make_rect(left.x + 8, left.y + left.h - 22, left.w - 16, 18)
	-- 蓄力条固定 144×12，便于后续用同尺寸贴图替换字符占位绘制。
	local slider_w, slider_h, slider_gap = 144, 12, 3
	local charge_slider_rects = {}
	for i = 1, 2 do
		charge_slider_rects[i] = Mouse_UI.make_rect(
			left.x + (left.w - slider_w) * 0.5,
			confirm_rect.y - 18 - (i - 1) * (slider_h + slider_gap),
			slider_w,
			slider_h
		)
	end
	local back_rect = Mouse_UI.make_rect(panel_rect.x + 8, panel_rect.y + panel_rect.h - 18, 52, 14)
	local qbtn_w = 40
	local quality_rect = Mouse_UI.make_rect(right.x + 2, right.y, qbtn_w, 13)
	local mode_rect = Mouse_UI.make_rect(right.x + 4 + qbtn_w, right.y, right.w - 6 - qbtn_w, 13)
	local hide_gray_rect = nil -- 有效/无效/未实装已并入右侧标签列

	-- 全道具：标签列锚在背包右缘 + ImGui 偏移（默认负 X 靠内侧）；真实背包不占位
	local tag_col = nil
	local bag_right = right
	if craft and craft.all_items then
		local tag_defs = CraftProfile.audit_filter_tag_defs()
		local off = get_tag_col_offset()
		local tag_w = get_tag_col_width()
		local screen = gui.GetScreenSize()
		local screen_w = screen and screen.X or 480
		local tag_x = right.x + right.w + off.X
		local tag_y = right.y + off.Y
		if tag_x + tag_w > screen_w - 2 then
			tag_x = math.max(right.x + 4, screen_w - tag_w - 2)
			tag_w = math.max(40, math.min(tag_w, screen_w - 2 - tag_x))
		end
		if tag_x < 2 then tag_x = 2 end
		local tag_rect = Mouse_UI.make_rect(tag_x, tag_y, tag_w, right.h)
		local btn_h, btn_gap = 11, 2
		local all_rect = Mouse_UI.make_rect(tag_rect.x, tag_rect.y, (tag_w - btn_gap) * 0.5, btn_h)
		local inv_rect = Mouse_UI.make_rect(
			tag_rect.x + all_rect.w + btn_gap, tag_rect.y, tag_w - all_rect.w - btn_gap, btn_h
		)
		local tag_rects = {}
		local y = tag_rect.y + btn_h + 4
		local row_h = 12
		for _, def in ipairs(tag_defs) do
			tag_rects[def.key] = Mouse_UI.make_rect(tag_rect.x, y, tag_w, row_h)
			y = y + row_h + 1
		end
		tag_col = {
			rect = tag_rect,
			all_rect = all_rect,
			invert_rect = inv_rect,
			tag_rects = tag_rects,
			defs = tag_defs,
		}
	end

	local bag_inner = Mouse_UI.make_rect(bag_right.x, bag_right.y + 15, bag_right.w, bag_right.h - 28)
	local prev_rect = Mouse_UI.make_rect(bag_right.x + 2, bag_right.y + bag_right.h - 12, 26, 11)
	local next_rect = Mouse_UI.make_rect(bag_right.x + bag_right.w - 28, bag_right.y + bag_right.h - 12, 26, 11)
	local cost_size = get_cost_slot_size()
	local spacing = get_cost_slot_spacing()
	local row_gap = item.cost_slot_row_gap or 2
	-- 成本小槽在道具图标下方；过多时自动换行；底座槽始终显示
	local display_n = cost_display_count(craft)
	local cost_pos, cost_rect = nil, nil
	local cost_cols, cost_rows = 1, 0
	if display_n > 0 then
		cost_cols = cost_cols_for_width(left.w - 8)
		cost_rows = cost_row_count(display_n, cost_cols)
		cost_pos = Vector(target_pos.X, target_pos.Y + get_cost_y_offset())
		local cols_top = math.min(display_n, cost_cols)
		local block_w = (cols_top - 1) * spacing + cost_size
		local block_h = (cost_rows - 1) * (cost_size + row_gap) + cost_size
		cost_rect = Mouse_UI.make_rect(
			cost_pos.X - block_w * 0.5,
			cost_pos.Y - cost_size * 0.5,
			block_w,
			block_h
		)
	end
	return {
		left = left,
		right = right,
		bag_right = bag_right,
		tag_col = tag_col,
		target_pos = target_pos,
		confirm_rect = confirm_rect,
		charge_slider_rects = charge_slider_rects,
		main_charge_slider_rect = charge_slider_rects[1],
		back_rect = back_rect,
		quality_rect = quality_rect,
		mode_rect = mode_rect,
		hide_gray_rect = hide_gray_rect,
		bag_inner = bag_inner,
		prev_rect = prev_rect,
		next_rect = next_rect,
		cost_pos = cost_pos,
		cost_rect = cost_rect,
		cost_size = cost_size,
		cost_spacing = spacing,
		cost_row_gap = row_gap,
		cost_cols = cost_cols,
		cost_rows = cost_rows,
		cost_display_n = display_n,
	}
end

local function rebuild_bag_tokens(panel, bag_rect, player)
	local craft = panel.craft
	if not craft then return end
	-- 面板打开期间时间冻结，背包不会在外部变化；只在翻页/放回/切目录时重建。
	if craft._bag_dirty ~= true then return end
	craft._bag_dirty = false
	local kept = {}
	local kept_map = {}
	for _, tok in ipairs(craft.tokens) do
		local dragging = panel.drag and panel.drag.token_id == tok.id
		local carrying = panel.pad_carry and panel.pad_carry.token_id == tok.id
		local busy = tok.slot or tok.cost or dragging or carrying or tok.anim
			or (tok.vel and tok.vel:Length() > item.inertia_stop)
			or not tok.from_bag
			or tok.lost_ghost -- 失去幽灵留在背包页，禁止被库存重建冲掉
		if busy then
			kept[#kept + 1] = tok
			kept_map[tok.id] = tok
		end
	end
	local bag_ids
	local tut_ids = get_tutorial().bag_collectibles()
	if tut_ids ~= nil then
		bag_ids, craft.bag_page, craft.bag_pages, craft.bag_total = tut_ids, 0, 1, #tut_ids
	elseif craft.all_items then
		craft._catalog = craft._catalog or collect_all_catalog_items()
		local src = craft._catalog
		-- 标签筛选：状态组∩类别组（见 CraftProfile.collectible_matches_audit_tags）
		local tag_enabled = CraftProfile.normalize_audit_tag_enabled(craft.tag_enabled)
		craft.tag_enabled = tag_enabled
		local tagged = {}
		for _, id in ipairs(src) do
			if CraftProfile.collectible_matches_audit_tags(id, tag_enabled, player) then
				tagged[#tagged + 1] = id
			end
		end
		src = tagged
		bag_ids, craft.bag_page, craft.bag_pages, craft.bag_total = page_slice(src, craft.bag_page, item.bag_page_size)
	else
		local full = collect_bag_items(player, craft.edit_uid, slot_reserve_from_craft(craft))
		bag_ids, craft.bag_page, craft.bag_pages, craft.bag_total = page_slice(full, craft.bag_page, item.bag_page_size)
	end
	local positions = bag_layout_positions(bag_rect, #bag_ids)
	for i, entry in ipairs(bag_ids) do
		local col = bag_entry_collectible(entry)
		local is_proto = bag_entry_is_proto(entry)
		local proto_uid = is_proto and entry.prototype_uid or nil
		local tid
		if is_proto then
			tid = (craft.all_items and "all_" or "bag_")..tostring(craft.bag_page).."_"..i.."_p"..tostring(proto_uid)
		else
			tid = (craft.all_items and "all_" or "bag_")..tostring(craft.bag_page).."_"..i.."_"..tostring(col)
		end
		if kept_map[tid] then
			-- already busy
		else
			local old = craft.token_map and craft.token_map[tid]
			if old and kept_map[old.id] then old = nil end
			local tok = old or {
				id = tid,
				collectible = col,
				pos = positions[i],
				vel = Vector(0, 0),
				slot = nil,
				from_bag = true,
				sprite = load_col_sprite(col),
			}
			tok.id = tid
			tok.collectible = col
			-- 放置时打标：目录=audit，背包真实=real，原型=prototype；槽内已放 token 不走重建
			if is_proto then
				tok.source = "prototype"
			elseif tut_ids or craft.all_items then
				tok.source = "audit"
			else
				tok.source = "real"
			end
			tok.prototype_uid = proto_uid
			tok.is_prototype = is_proto or false
			tok.impl = CraftProfile.has_impl(col)
			tok.missing_stat = CraftProfile.missing_stat_delta(col)
			tok.gate_kind = CraftProfile.effect_gate_kind(col)
			tok.home = positions[i]
			if not old then
				tok.pos = positions[i]
			elseif not tok.anim and (not tok.vel or tok.vel:Length() < 0.2) then
				if (tok.pos - positions[i]):Length() > 18 then
					begin_snap_anim(tok, positions[i])
				elseif (tok.pos - positions[i]):Length() > 1 then
					tok.pos = positions[i]
				end
			end
			kept[#kept + 1] = tok
			kept_map[tid] = tok
		end
	end
	craft.tokens = kept
	craft.token_map = kept_map
	-- 失去幽灵无库存格位：排在当前页末尾显示
	local ghost_i = 0
	for _, tok in ipairs(craft.tokens) do
		if tok.lost_ghost and tok.from_bag and not tok.slot and not tok.cost then
			ghost_i = ghost_i + 1
			local idx = #bag_ids + ghost_i
			local positions_all = bag_layout_positions(bag_rect, idx)
			local dest = positions_all[idx]
			tok.home = dest
			if not tok.anim and (not tok.vel or tok.vel:Length() < 0.2) then
				if (tok.pos - dest):Length() > 18 then
					begin_snap_anim(tok, dest)
				else
					tok.pos = dest
				end
			end
		end
	end
	refresh_craft_token_lost(player, craft)
	craft._preview_sig = nil
end

local function remove_from_cost(craft, tok)
	if not craft or not tok then return end
	tok.cost = nil
	local ids = craft.cost_ids or {}
	for i = #ids, 1, -1 do
		if ids[i] == tok.id then table.remove(ids, i) end
	end
end

local function clear_token_slot(craft, tok)
	if tok.slot then
		local slot = craft.slots[tok.slot]
		if slot and slot.token == tok.id then slot.token = nil end
		tok.slot = nil
	end
	if tok.cost then
		remove_from_cost(craft, tok)
		-- 取出底座：记住品质并保留槽位，不立刻收起
		if craft then craft.base_quality = nil end
		sync_show_quality(craft)
	end
end

--- 保证每个材料槽最多一个 token；以 slot.token 为准，清掉多余占用者
local function reconcile_slot_occupancy(craft)
	if not craft or not craft.slots then return end
	-- 先按 slot.token 建权威占用
	local owner = {}
	for i, slot in ipairs(craft.slots) do
		local tid = slot.token
		if tid then
			local tok = craft.token_map[tid]
			if tok and not tok.cost then
				owner[i] = tok
				tok.slot = i
			else
				slot.token = nil
			end
		end
	end
	-- 踢掉仍自称在槽、但未被权威占用接纳的 token
	for _, tok in ipairs(craft.tokens or {}) do
		if tok.slot and not tok.cost then
			local slot = craft.slots[tok.slot]
			if not slot or slot.token ~= tok.id then
				tok.slot = nil
				if not (item.panel and item.panel.drag and item.panel.drag.token_id == tok.id)
					and not (item.panel and item.panel.pad_carry and item.panel.pad_carry.token_id == tok.id)
					and not tok.anim then
					local dest = bag_area_anchor(tok)
					tok.home = dest
					tok.from_bag = true
					if tok.lost or tok.lost_ghost then
						tok.lost_ghost = true
						tok.lost = true
					end
					begin_snap_anim(tok, dest)
				end
			end
		end
	end
	-- 再写回权威占用（防止中途被改）
	for i, tok in pairs(owner) do
		local slot = craft.slots[i]
		if slot then
			slot.token = tok.id
			tok.slot = i
		end
	end
end

--- 审计全道具：放入槽位/成本后断开背包身份，背包可再刷出同款以便叠层
--- 非审计：禁止改 from_bag——否则取出后既保留孤儿 token，又按库存补货同 id
local function detach_bag_identity(craft, tok)
	if not craft or not tok then return end
	if not craft.all_items then return end
	local looks_bag = tok.from_bag or (type(tok.id) == "string" and tok.id:sub(1, 4) == "all_")
	if not looks_bag then return end
	local old = tok.id
	local new_id = "inst_"..tostring(tok.collectible).."_"..tostring(Isaac.GetFrameCount()).."_"..tostring(math.random(100000))
	if craft.token_map[old] == tok then craft.token_map[old] = nil end
	-- 槽位引用随 id 一起改，避免旧 id 残留导致“同槽多道具”
	if tok.slot then
		local slot = craft.slots[tok.slot]
		if slot and slot.token == old then slot.token = new_id end
	end
	if tok.cost and craft.cost_ids then
		for i, tid in ipairs(craft.cost_ids) do
			if tid == old then craft.cost_ids[i] = new_id end
		end
	end
	tok.id = new_id
	tok.from_bag = false
	if tok.source ~= "prototype" then
		tok.source = "audit"
	end
	craft.token_map[new_id] = tok
end

local function cost_stack_pos(craft, geom, index)
	local base = geom and geom.cost_pos or Vector(0, 0)
	local total = (geom and geom.cost_display_n) or cost_display_count(craft)
	local n = math.max(1, total)
	local i = math.max(1, index or #(craft.cost_ids or {}))
	local size = (geom and geom.cost_size) or get_cost_slot_size()
	local spacing = (geom and geom.cost_spacing) or get_cost_slot_spacing()
	local row_gap = (geom and geom.cost_row_gap) or (item.cost_slot_row_gap or 2)
	local cols = (geom and geom.cost_cols) or cost_cols_for_width(160)
	cols = math.max(1, cols)
	local row = math.floor((i - 1) / cols)
	local col = (i - 1) % cols
	local row_start = row * cols + 1
	local row_count = math.min(cols, n - row_start + 1)
	local ox = (col + 1 - (row_count + 1) * 0.5) * spacing
	local oy = row * (size + row_gap)
	return base + Vector(ox, oy)
end

local function assign_token_cost(craft, tok, geom)
	if not craft or not tok then return end
	if get_tutorial().is_locking() and not get_tutorial().allows_cost_assign(tok) then
		if tok.home then begin_snap_anim(tok, tok.home) end
		return
	end
	-- 原型不能支付成本槽
	if tok.source == "prototype" or tok.is_prototype then
		clear_token_slot(craft, tok)
		if tok.home then begin_snap_anim(tok, tok.home) end
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.55, 1.1, false, 0, 2)
		return
	end
	detach_bag_identity(craft, tok)
	clear_token_slot(craft, tok)
	-- 底座槽只保留一件：旧底座滑回背包（取出不改槽数；换入才适配）
	craft.cost_ids = craft.cost_ids or {}
	for i = #craft.cost_ids, 1, -1 do
		local tid = craft.cost_ids[i]
		if tid ~= tok.id then
			local other = craft.token_map[tid]
			table.remove(craft.cost_ids, i)
			if other then
				other.cost = nil
				other.from_bag = true
				local dest = bag_area_anchor(other)
				other.home = dest
				if other.lost or other.lost_ghost then
					other.lost_ghost = true
					other.lost = true
				end
				begin_snap_anim(other, dest)
			end
		end
	end
	tok.cost = true
	tok.visual_scale = get_cost_token_scale()
	craft.cost_ids[#craft.cost_ids + 1] = tok.id
	local dest = cost_stack_pos(craft, geom, #craft.cost_ids)
	begin_snap_anim(tok, dest)
	local q = CraftProfile.collectible_quality(tok.collectible)
	craft.base_quality = q
	craft.remembered_quality = q
	apply_module_slots_for_base(craft, geom, {adapt = true})
	sync_show_quality(craft)
	craft._bag_dirty = true
end

--- 将占用者挪到其他材料槽，或滑回背包区（不瞬移、不删掉）
local function relocate_displaced_token(craft, other, from_slot_index, exclude_slot)
	if not craft or not other then return end
	other.cost = nil
	remove_from_cost(craft, other)
	other.slot = nil

	-- 1) 来自另一材料槽：互换回原槽
	if from_slot_index and from_slot_index ~= exclude_slot and craft.slots[from_slot_index] then
		local prev_slot = craft.slots[from_slot_index]
		local blocker_id = prev_slot.token
		if blocker_id and blocker_id ~= other.id then
			local blocker = craft.token_map[blocker_id]
			if blocker then
				prev_slot.token = nil
				blocker.slot = nil
				local bdest = bag_area_anchor(blocker)
				blocker.home = bdest
				begin_snap_anim(blocker, bdest)
			end
		end
		prev_slot.token = other.id
		other.slot = from_slot_index
		other.visual_scale = 1
		local dest = prev_slot._rect and Mouse_UI.rect_center(prev_slot._rect) or other.pos
		begin_snap_anim(other, dest)
		return
	end

	-- 2) 来自背包/成本/空闲：优先挪到其他空材料槽
	local empty_i = find_empty_ingredient_slot(craft, exclude_slot)
	if empty_i then
		local es = craft.slots[empty_i]
		es.token = other.id
		other.slot = empty_i
		other.visual_scale = 1
		local dest = es._rect and Mouse_UI.rect_center(es._rect) or other.pos
		begin_snap_anim(other, dest)
		return
	end

	-- 3) 无空槽：滑入背包区域，保留实体（失去道具记为幽灵，避免重建时消失）
	local dest = bag_area_anchor(other)
	other.home = dest
	other.from_bag = true
	if other.lost or other.lost_ghost then
		other.lost_ghost = true
		other.lost = true
	end
	begin_snap_anim(other, dest)
end

apply_module_slots_for_base = function(craft, geom, opts)
	if not craft then return end
	opts = opts or {}
	if not opts.adapt then return end
	local q = craft.base_quality
	if q == nil then q = craft.remembered_quality end
	local new_n = CraftProfile.slots_for_base_quality(q)
	local old_slots = craft.slots or {}
	if new_n == #old_slots then return end
	local displaced = {}
	if new_n < #old_slots then
		for i = new_n + 1, #old_slots do
			local slot = old_slots[i]
			if slot and slot.token then
				local tok = craft.token_map[slot.token]
				slot.token = nil
				if tok then
					tok.slot = nil
					displaced[#displaced + 1] = tok
				end
			end
		end
	end
	local avail_w = 160
	if geom and geom.left then avail_w = geom.left.w - 8 end
	local layout = make_slot_layout(new_n, cost_display_count(craft), avail_w)
	local slots = {}
	for i = 1, new_n do
		local prev = old_slots[i]
		local L = layout[i] or {ox = 0, oy = 0}
		local slot = prev or {token = nil, ox = 0, oy = 0}
		slot._from_ox = slot.ox or 0
		slot._from_oy = slot.oy or 0
		if not prev then
			slot._from_ox = 0
			slot._from_oy = 0
			slot.ox = 0
			slot.oy = 0
		end
		slot._to_ox = L.ox
		slot._to_oy = L.oy
		slot._anim_t = 0
		slots[i] = slot
	end
	craft.slots = slots
	craft.slot_count = new_n
	for _, tok in ipairs(displaced) do
		relocate_displaced_token(craft, tok, nil, nil)
	end
end

local function assign_token_slot(craft, tok, slot_index)
	local slot = craft.slots[slot_index]
	if not slot or not tok then return end
	if get_tutorial().is_locking() and not get_tutorial().allows_slot_assign(tok) then
		if tok.home then begin_snap_anim(tok, tok.home) end
		return
	end
	detach_bag_identity(craft, tok)
	if tok.slot == slot_index and slot.token == tok.id then
		local dest = slot._rect and Mouse_UI.rect_center(slot._rect) or tok.pos
		begin_snap_anim(tok, dest)
		return
	end

	local prev_index = tok.slot
	local other = nil
	if slot.token and slot.token ~= tok.id then
		other = craft.token_map[slot.token]
	end

	-- 先从原槽卸下当前 token（勿在写入互换结果后再 clear，否则会抹掉刚放回的占用）
	clear_token_slot(craft, tok)

	if other then
		-- 目标槽腾出 B，再按来源决定：互换 / 挪空槽 / 滑回背包区
		if slot.token == other.id then slot.token = nil end
		other.slot = nil
		relocate_displaced_token(craft, other, prev_index, slot_index)
	end

	slot.token = tok.id
	tok.slot = slot_index
	tok.cost = nil
	tok.visual_scale = 1
	local dest = slot._rect and Mouse_UI.rect_center(slot._rect) or tok.pos
	begin_snap_anim(tok, dest)
	reconcile_slot_occupancy(craft)
	craft._bag_dirty = true
end

local function find_snap_slot(craft, tok)
	local best, best_d = nil, nil
	local limit = item.snap_dist or 34
	for i, slot in ipairs(craft.slots) do
		if slot._rect then
			local c = Mouse_UI.rect_center(slot._rect)
			local d = (tok.pos - c):Length()
			if d <= limit and (best_d == nil or d < best_d) then
				best_d = d
				best = i
			end
		end
	end
	return best, best_d
end

local function find_snap_cost(craft, tok, geom)
	if not geom or not geom.cost_rect then return false, nil, false end
	local r = geom.cost_rect
	local c = Mouse_UI.rect_center(r)
	local reach = math.max(item.snap_dist or 34, math.max(r.w, r.h) * 0.55)
	local d = (tok.pos - c):Length()
	local inside = Mouse_UI.point_in_rect(tok.pos, r) == true
	if inside then return true, 0, true end
	if d <= reach then return true, d, false end
	return false, d, false
end

local function read_ingredients(craft)
	local ingredients = {}
	for i, slot in ipairs(craft.slots) do
		if slot.token then
			local tok = craft.token_map[slot.token]
			if tok and tok.collectible then
				local src = tok.source
				if src == "prototype" and tok.prototype_uid then
					ingredients[i] = {
						id = tok.collectible,
						source = "prototype",
						prototype_uid = tok.prototype_uid,
					}
				elseif src == "audit" then
					ingredients[i] = {
						id = tok.collectible,
						source = "audit",
					}
				else
					-- real：存 number 以兼容旧读法；来源由缺省 source 推断
					ingredients[i] = tok.collectible
				end
			end
		end
	end
	return ingredients
end

local function read_cost_items(craft)
	local list = {}
	for _, tid in ipairs(craft.cost_ids or {}) do
		local tok = craft.token_map[tid]
		if tok and tok.collectible then
			if tok.source == "audit" then
				list[#list + 1] = { id = tok.collectible, source = "audit" }
			else
				list[#list + 1] = tok.collectible
			end
		end
	end
	return list
end

local function craft_preview_name(craft, player)
	if not craft then return "" end
	local zh = lang_is_zh()
	local serial = 1
	if craft.edit_uid then
		local rec = item.find_craft(player, craft.edit_uid)
		serial = (rec and tonumber(rec.serial)) or 1
	else
		serial = next_serial_for_target(player, craft.target)
	end
	local src = naming_ingredients(read_ingredients(craft), read_cost_items(craft))
	return CraftProfile.build_display_name(craft.target, serial, src, zh)
end

--- 还原草稿材料/成本：未持有的也保留（失去态标红），禁止因缺料把槽位直接空置
--- all_items 仅作「无显式 source 的旧草稿」回退：目录模式草稿的纯 number 视为 audit
filter_draft_items = function(player, ingredients, cost_items, exclude_uid, all_items)
	ingredients = ingredients or {}
	cost_items = cost_items or {}
	local audit_fb = all_items == true
	local ing, cost = {}, {}
	local keys = {}
	for i, _ in pairs(ingredients) do
		local idx = tonumber(i) or i
		if type(idx) == "number" then keys[#keys + 1] = idx end
	end
	table.sort(keys)
	for _, idx in ipairs(keys) do
		local entry = ingredients[idx] or ingredients[tostring(idx)]
		local src = CraftProfile.ingredient_source(entry, audit_fb)
		local id = CraftProfile.ingredient_id(entry)
		if src == "prototype" then
			local uid = type(entry) == "table" and entry.prototype_uid or nil
			if uid ~= nil and id and id ~= 0 then
				ing[idx] = {
					id = id,
					source = "prototype",
					prototype_uid = uid,
				}
			end
		elseif src == "audit" then
			if id and id ~= 0 then
				ing[idx] = { id = id, source = "audit" }
			end
		else
			if id and id ~= 0 then
				ing[idx] = id
			end
		end
	end
	for _, entry in ipairs(cost_items) do
		local src = CraftProfile.ingredient_source(entry, audit_fb)
		local id = CraftProfile.ingredient_id(entry)
		if id and id ~= 0 then
			if src == "audit" then
				cost[#cost + 1] = { id = id, source = "audit" }
			else
				cost[#cost + 1] = id
			end
		end
	end
	return ing, cost
end

local function read_bag_ghosts(craft)
	local list = {}
	if not craft then return list end
	for _, tok in ipairs(craft.tokens or {}) do
		if tok and tok.collectible and tok.collectible ~= 0
			and not tok.slot and not tok.cost
			and (tok.lost_ghost or tok.lost)
			and not (tok.source == "prototype" or tok.is_prototype)
		then
			list[#list + 1] = tok.collectible
		end
	end
	return list
end

save_craft_draft = function(panel)
	if not panel or not panel.craft or not player_exists_safe(panel.player) then return end
	local craft = panel.craft
	local ingredients = read_ingredients(craft)
	local cost_items = read_cost_items(craft)
	local bag_ghosts = read_bag_ghosts(craft)
	local filled = 0
	for _, _ in pairs(ingredients) do filled = filled + 1 end
	local key = draft_key(craft.target, craft.edit_uid)
	local drafts = get_drafts(panel.player)
	if filled <= 0 and #cost_items <= 0 and #bag_ghosts <= 0 then
		drafts[key] = nil
		return
	end
	local ing_save = {}
	for i, col in pairs(ingredients) do
		ing_save[tostring(i)] = col
	end
	drafts[key] = {
		target = craft.target,
		edit_uid = craft.edit_uid,
		ingredients = ing_save,
		cost_items = cost_items,
		bag_ghosts = bag_ghosts,
		slot_count = craft.slot_count,
		required_cost = craft.required_cost or 0,
		base_quality = craft.base_quality,
		remembered_quality = craft.remembered_quality,
		all_items = craft.all_items == true,
		hide_gray = craft.hide_gray == true,
		audit_filter = craft.audit_filter or "all",
		main_charge_ratio = clamp_charge_ratio(craft.main_charge_ratio),
	}
end

--- 按 token 来源标失去态：audit 永不失去；real/prototype 按持有/UID
refresh_craft_token_lost = function(player, craft)
	if not craft or not player then return end
	local used = item.count_allocated(player, craft.edit_uid)
	local have = {}
	local function remaining(id)
		id = tonumber(id) or id
		if not id or id == 0 then return 0 end
		if have[id] == nil then
			local n = player:GetCollectibleNum(id, true) - (used[id] or 0)
			if id == item.entity then n = n - 1 end
			have[id] = math.max(0, n)
		end
		return have[id]
	end
	local function take(id)
		id = tonumber(id) or id
		local n = remaining(id)
		if n > 0 then
			have[id] = n - 1
			return true
		end
		return false
	end
	for _, tok in ipairs(craft.tokens or {}) do
		if not tok or not tok.collectible then
			-- skip
		elseif tok.source == "audit" then
			tok.lost = nil
			tok.lost_ghost = nil
		elseif tok.source == "prototype" or tok.is_prototype then
			local uid = tok.prototype_uid
			local prec = uid and item.get_prototype(player, uid) or nil
			local ok = prec and prec.id == tok.collectible
			tok.lost = not ok
			tok.lost_ghost = (not ok) or nil
		elseif tok.lost_ghost and tok.from_bag and not tok.slot and not tok.cost then
			-- 背包里的失去幽灵：不占库存，保持标红
			tok.lost = true
		elseif tok.from_bag and not tok.slot and not tok.cost then
			-- 真实背包库存
			tok.lost = false
			tok.lost_ghost = nil
		else
			if take(tok.collectible) then
				tok.lost = false
				tok.lost_ghost = nil
			else
				tok.lost = true
				tok.lost_ghost = true
			end
		end
	end
end

local function ingredients_fit_allocation(player, ingredients, exclude_uid, cost_items)
	local need_real = {}
	local need_proto = {}
	for _, entry in pairs(ingredients or {}) do
		local src = CraftProfile.ingredient_source(entry, false)
		if src == "prototype" then
			need_proto[entry.prototype_uid] = CraftProfile.ingredient_id(entry)
		elseif src == "real" then
			local id = CraftProfile.ingredient_id(entry)
			if id and id ~= 0 then need_real[id] = (need_real[id] or 0) + 1 end
		end
		-- audit：不占配额
	end
	for _, entry in ipairs(cost_items or {}) do
		if CraftProfile.ingredient_source(entry, false) == "real" then
			local id = CraftProfile.ingredient_id(entry)
			if id and id ~= 0 then need_real[id] = (need_real[id] or 0) + 1 end
		end
	end
	local used = item.count_allocated(player, exclude_uid)
	for id, n in pairs(need_real) do
		local have = player:GetCollectibleNum(id, true) - (used[id] or 0)
		if id == item.entity then have = have - 1 end
		if have < n then return false end
	end
	local used_proto = item.count_allocated_prototypes(player, exclude_uid)
	for uid, id in pairs(need_proto) do
		local inv = item.get_prototype(player, uid)
		if not inv or inv.id ~= id then return false end
		if used_proto[uid] or used_proto[tostring(uid)] then return false end
	end
	return true
end

local function rebind_air_flight_profile(player, uid, profile)
	local Craft_Familiar_holder = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
	local hit = false
	for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, enums.Familiars.QingsAirs, -1, false, false)) do
		local p = auxi.check_spawner_player(fam)
		if p and auxi.check_for_the_same(p, player) then
			local d = fam:GetData()
			if d[item.own_key.."craft_uid"] == uid then
				d[item.own_key.."craft_profile"] = profile
				-- 背包确认后立刻按新配方释放/认领宝宝并刷新复活 MeusNil
				if Craft_Familiar_holder.sync_air_flight then
					Craft_Familiar_holder.sync_air_flight(fam, player, profile)
				end
				hit = true
			end
		end
	end
	return hit
end

--- 蓝图属性/TearFlags/胎儿次级 flags 均脱钩；imitate 用于 audit/prototype 的制造宝宝实体。
--- real 材料失去后不得补发临时宝宝（否则会冒出假玛姬等）——由 collect 只扫 audit/prototype 保证。
--- 制造复活源例外：永不进玩家 innate；跟随源用真实体/MeusNil。
--- audit/prototype 份数与玩家真实持有无关：有真道具也照常 imitate，不得因 HasCollectible 整表清零。
local function is_audit_simulate_item(id)
	id = tonumber(id)
	if not id or id == 0 then return false end
	if CraftProfile.CRAFT_REVIVE_ID_SET and CraftProfile.CRAFT_REVIVE_ID_SET[id] then
		return false
	end
	local extra = CraftProfile.EXTRA_IMPL[id]
	return extra ~= nil
		and CraftProfile.CRAFT_FAMILIAR_EXTRAS_KEY_SET ~= nil
		and CraftProfile.CRAFT_FAMILIAR_EXTRAS_KEY_SET[extra] == true
end

function item.collect_audit_simulate_counts(player)
	local counts = {}
	for _, rec in ipairs(item.get_craft_store(player)) do
		local fb = rec.audit == true
		local seen_slot = {}
		for slot, entry in pairs(rec.ingredients or {}) do
			local sk = tostring(slot)
			if not seen_slot[sk] then
				seen_slot[sk] = true
				-- audit / prototype 可 imitate（制造宝宝 extras）；不把 prototype 记成审计模式
				local src = CraftProfile.ingredient_source(entry, fb)
				if src == "audit" or src == "prototype" then
					if src == "prototype" then
						local uid = type(entry) == "table" and entry.prototype_uid
						local prec = uid and item.get_prototype(player, uid) or nil
						local id = CraftProfile.ingredient_id(entry)
						if not prec or prec.id ~= id then
							-- 原型 UID 丢失：不 imitate
						elseif is_audit_simulate_item(id) then
							counts[id] = (counts[id] or 0) + 1
						end
					else
						local id = CraftProfile.ingredient_id(entry)
						if is_audit_simulate_item(id) then
							counts[id] = (counts[id] or 0) + 1
						end
					end
				end
			end
		end
	end
	return counts
end

local function refresh_audit_simulates(player)
	if not player then return end
	Imitate_item_holder.Evaluate_Imitate_Items(player)
	player:AddCacheFlags(
		CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_SHOTSPEED
		| CacheFlag.CACHE_RANGE | CacheFlag.CACHE_LUCK | CacheFlag.CACHE_SPEED
		| CacheFlag.CACHE_TEARFLAG | CacheFlag.CACHE_WEAPON | CacheFlag.CACHE_FAMILIARS
	)
	player:EvaluateItems()
end

--- 库存删除：首次点「删」进入确认，再点一次才真正删除
local function try_confirm_delete_stock(panel, craft_uid)
	if not panel or not panel.player or craft_uid == nil then return end
	if panel.delete_confirm_uid ~= craft_uid then
		panel.delete_confirm_uid = craft_uid
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.55, 0.95, false, 0, 2)
		return
	end
	panel.delete_confirm_uid = nil
	if item.delete_craft(panel.player, craft_uid) then
		refresh_audit_simulates(panel.player)
		panel.nav_graph = nil
		panel.focus_id = "tab_"..tostring(panel.tab or 2)
		panel.nav_group = "tabs"
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSDOWN, 0.85, 1, false, 0, 2)
		pcall(function() get_tutorial().on_craft_deleted(panel.player, craft_uid) end)
	else
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1, false, 0, 2)
	end
end

local function form_queue_insert_index(ui, mouse, drag_uid)
	local cards = (ui and ui.form_queue_cards) or {}
	local xs = {}
	for _, c in ipairs(cards) do
		if c.uid ~= drag_uid then
			xs[#xs + 1] = c.rect.x + c.rect.w * 0.5
		end
	end
	local idx = #xs + 1
	for i = 1, #xs do
		if mouse.X < xs[i] then
			idx = i
			break
		end
	end
	return idx
end

local function finish_form_drag(panel, ui)
	local drag = panel.drag
	panel.drag = nil
	if not drag or drag.kind ~= "form_card" or not panel.player then return end
	ui = ui or panel.ui
	local mouse = Mouse_UI.mouse
	local BW = get_bandwidth()
	if ui and ui.form_queue_rect and Mouse_UI.point_in_rect(mouse, ui.form_queue_rect) then
		local idx = form_queue_insert_index(ui, mouse, drag.uid)
		if not BW.place_as_active(panel.player, drag.uid, idx) then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1.1, false, 0, 2)
		else
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.75, 1, false, 0, 2)
		end
		return
	end
	if ui and ui.form_bench_rect and Mouse_UI.point_in_rect(mouse, ui.form_bench_rect) then
		BW.set_active(panel.player, drag.uid, false)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.5, 1, false, 0, 2)
		return
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.35, 1, false, 0, 2)
end

local function handle_formation_id(panel, id)
	if not panel or not id or not panel.player then return false end
	local BW = get_bandwidth()
	if id == "form_prev" then
		panel.form_bench_page = math.max(0, (panel.form_bench_page or 0) - 1)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
		return true
	end
	if id == "form_next" then
		local pages = math.max(1, panel._form_bench_pages or 1)
		panel.form_bench_page = math.min(pages - 1, (panel.form_bench_page or 0) + 1)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
		return true
	end
	for _, lay in ipairs((panel.ui and panel.ui.layouts) or {}) do
		local e = lay.entry
		if e and e.kind == "form_card" and e.rec and id == e.uid then
			if panel.form_carry then
				local carry_uid = panel.form_carry.uid
				panel.form_carry = nil
				if e.zone == "queue" then
					if not BW.place_as_active(panel.player, carry_uid, e.active_index or 1) then
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1.1, false, 0, 2)
					else
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.75, 1, false, 0, 2)
					end
				else
					BW.set_active(panel.player, carry_uid, false)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.5, 1, false, 0, 2)
				end
				return true
			end
			if e.zone == "bench" then
				if not BW.place_as_active(panel.player, e.rec.uid, 999) then
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1.1, false, 0, 2)
				else
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.75, 1, false, 0, 2)
				end
			else
				panel.form_carry = {uid = e.rec.uid}
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.45, 1, false, 0, 2)
			end
			return true
		end
	end
	if panel.form_carry then
		if id == "form_queue" then
			local uid = panel.form_carry.uid
			panel.form_carry = nil
			if not BW.place_as_active(panel.player, uid, 999) then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1.1, false, 0, 2)
			else
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.75, 1, false, 0, 2)
			end
			return true
		end
		if id == "form_bench" then
			BW.set_active(panel.player, panel.form_carry.uid, false)
			panel.form_carry = nil
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.5, 1, false, 0, 2)
			return true
		end
	end
	return false
end

local function confirm_craft(panel)
	local craft = panel.craft
	local player = panel.player
	if not craft or not player then return end
	if get_tutorial().is_locking() and not get_tutorial().allow_confirm(craft) then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1, false, 0, 2)
		return
	end
	local ingredients = read_ingredients(craft)
	local cost_items = read_cost_items(craft)
	-- 材料槽可选：允许空配方（基础面板）。里小青首件 required_cost=0 时无任何必填槽。
	-- 整机 audit：存在任一 audit 材料；纯审计才豁免成本与配额
	local has_audit = CraftProfile.craft_has_any_audit(ingredients, cost_items, false)
	local pure_audit = CraftProfile.craft_is_pure_audit(ingredients, cost_items, false)
	-- 编辑也按本件锁定的 required_cost 校验（不再因 edit_uid 豁免）
	local need_cost = craft.required_cost or 0
	if not craft.edit_uid and need_cost <= 0 then
		need_cost = item.get_required_cost(player)
	end
	local real_cost_n = 0
	for _, entry in ipairs(cost_items) do
		if CraftProfile.is_real_entry(entry, false) then
			real_cost_n = real_cost_n + 1
		end
	end
	if not pure_audit and real_cost_n < need_cost then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1, false, 0, 2)
		return
	end
	if not pure_audit and not ingredients_fit_allocation(player, ingredients, craft.edit_uid, cost_items) then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1, false, 0, 2)
		return
	end
	-- 成本道具不进入战斗档案；确认时写入含动态种子的档案快照（运行时仍会按玩家重算）
	local profile = CraftProfile.build_profile(ingredients, {
		player = player,
		rec = craft.edit_uid and item.find_craft(player, craft.edit_uid) or craft,
		commit_state = true,
		base_quality = craft.remembered_quality or craft.base_quality,
	})
	local max_ratio = CraftProfile.charge_ratio_max(profile)
	local main_ratio = CraftProfile.snap_charge_ratio(
		craft.main_charge_ratio, max_ratio, profile.extras and profile.extras.cursed_eye
	)
	CraftProfile.apply_craft_settings(profile, {
		main_charge_ratio = main_ratio,
	})
	local store = item.get_craft_store(player)
	local root = ensure_save()

	if craft.edit_uid then
		local rec = item.find_craft(player, craft.edit_uid)
		if not rec then return end
		local was_broken = rec.broken == true
		rec.ingredients = ingredients
		rec.cost_items = cost_items
		rec.required_cost = craft.required_cost or locked_required_cost_from_rec(rec)
		rec.base_quality = craft.remembered_quality or craft.base_quality or CraftProfile.quality_from_cost_items(cost_items)
		rec.remembered_quality = rec.base_quality
		rec.main_charge_ratio = main_ratio
		rec.experimental = craft.experimental or rec.experimental
		rec.eye_phase = craft.eye_phase or rec.eye_phase
		rec.profile = profile
		rec.audit = has_audit
		-- 手动确认修改：解除复活锁定；移出配方的复活源清 spent
		CraftProfile.craft_revive_on_confirm(rec, profile)
		if has_audit then
			rec.hide_gray = craft.hide_gray == true
			rec.audit_filter = craft.audit_filter or "all"
			get_audit_ui_prefs(player).hide_gray = rec.hide_gray
			get_audit_ui_prefs(player).audit_filter = rec.audit_filter
		end
		rec.serial = tonumber(rec.serial) or next_serial_for_target(player, rec.target, rec.uid)
		refresh_rec_display_name(rec, player)
		-- 先 integrity / imitate，再 rebind+sync，避免缺料时仍按旧 broken_missing 捕捉
		item.refresh_craft_integrity(player)
		if was_broken and rec.broken ~= true then
			CraftProfile.craft_revive_on_repaired(rec, profile)
		end
		refresh_audit_simulates(player)
		rebind_air_flight_profile(player, rec.uid, profile)
		pcall(function() get_bandwidth().on_craft_changed(player, rec.uid) end)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 1, 1, false, 0, 2)
		leave_craft_view(panel, {clear_draft = true})
		checkpoint_run_save("craft_edit")
		return
	end

	root.uid_counter = (root.uid_counter or 0) + 1
	local uid = root.uid_counter
	local rec = {
		uid = uid,
		target = craft.target,
		ingredients = ingredients,
		cost_items = cost_items,
		required_cost = craft.required_cost or need_cost,
		base_quality = craft.remembered_quality or craft.base_quality or CraftProfile.quality_from_cost_items(cost_items),
		remembered_quality = craft.remembered_quality or craft.base_quality,
		profile = profile,
		main_charge_ratio = main_ratio,
		experimental = craft.experimental,
		eye_phase = craft.eye_phase or 0,
		audit = has_audit,
		serial = next_serial_for_target(player, craft.target),
	}
	if has_audit then
		rec.hide_gray = craft.hide_gray == true
		rec.audit_filter = craft.audit_filter or "all"
		get_audit_ui_prefs(player).hide_gray = rec.hide_gray
		get_audit_ui_prefs(player).audit_filter = rec.audit_filter
	end
	refresh_rec_display_name(rec, player)
	if get_tutorial().is_active() then
		get_tutorial().on_craft_confirmed(rec)
	end
	table.insert(store, rec)
	clear_craft_draft(player, craft.target, nil)
	checkpoint_run_save("craft_add")
	pcall(function() get_bandwidth().on_craft_added(player, uid) end)
	panel.craft = nil -- 避免 close_panel 再把已确认内容存成草稿

	local gained = craft.target
	-- 不发放目标收藏品；飞行器数量由 CheckFamiliar(库存份数) 同步
	player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
	player:EvaluateItems()
	item.refresh_craft_integrity(player)

	-- 审计材料：挂 imitate（仅 source=audit 的宝宝类）
	refresh_audit_simulates(player)

	sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP, 1, 1, false, 0, 2)
	close_panel()
	-- Pickup 会自动放下；LiftItem 需再播 HideItem，否则一直举着
	if gained and gained > 0 then
		player:AnimateCollectible(gained, "Pickup", "PlayerPickupSparkle")
		local shown = lang_is_zh() and rec.display_name or rec.display_name_en
		if shown and shown ~= "" then
			local config = Isaac.GetItemConfig():GetCollectible(gained)
			local translated = item_displaying_holder.check_description(
				"Item",
				gained,
				auxi.check_name_data(config and config.Name or ""),
				auxi.check_name_data(config and config.Description or ""),
				player
			)
			local desc = (translated and translated.Description)
				or auxi.check_name_data(config and config.Description or "")
			-- ItemDesc：走模组公示通道，且不覆盖自定义型号名
			item_displaying_holder.check_and_description("ItemDesc", gained, shown, desc, player)
		end
	end
end

local function cancel_edit(panel)
	-- 退出时暂存草稿，下次进入自动填回
	leave_craft_view(panel)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.5, 1, false, 0, 2)
end

local function remove_token_entity(craft, tok)
	if not craft or not tok then return end
	clear_token_slot(craft, tok)
	craft.token_map[tok.id] = nil
	for i = #craft.tokens, 1, -1 do
		if craft.tokens[i] == tok or craft.tokens[i].id == tok.id then
			table.remove(craft.tokens, i)
		end
	end
end

-- ---------- 拖放 ----------
local function finish_drag(panel, content_right, geom)
	local drag = panel.drag
	if not drag or not panel.craft then return end
	local craft = panel.craft
	local tok = craft.token_map[drag.token_id]
	panel.drag = nil
	if not tok then return end
	craft._bag_dirty = true
	geom = geom or (panel.ui and panel.ui.craft_geom)

	local in_slot = nil
	for i, slot in ipairs(craft.slots) do
		if slot._rect and Mouse_UI.point_in_rect(tok.pos, slot._rect) then
			in_slot = i
			break
		end
	end
	local snap_i, slot_d = find_snap_slot(craft, tok)
	local cost_ok, cost_d, in_cost = find_snap_cost(craft, tok, geom)
	local use_cost = false
	local use_slot = nil
	-- 底座槽几乎贴着椭圆底部的模块槽；松手时必须先认框，再比距离，否则模块永远吸不进底座。
	if in_slot then
		use_slot = in_slot
	elseif in_cost then
		use_cost = true
	elseif cost_ok and snap_i then
		if (cost_d or 1e9) <= (slot_d or 1e9) then
			use_cost = true
		else
			use_slot = snap_i
		end
	elseif cost_ok then
		use_cost = true
	elseif snap_i then
		use_slot = snap_i
	end
	if use_slot then
		assign_token_slot(craft, tok, use_slot)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.7, 1.05, false, 0, 2)
	elseif use_cost then
		assign_token_cost(craft, tok, geom)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.65, 0.95, false, 0, 2)
	else
		clear_token_slot(craft, tok)
		if craft.all_items and not tok.from_bag and type(tok.id) == "string" and tok.id:sub(1, 5) == "inst_" then
			remove_token_entity(craft, tok)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.4, 1, false, 0, 2)
			return
		end
		-- 卸到背包区：非审计失去道具改为幽灵，重进草稿仍可还原
		if not craft.all_items then
			tok.from_bag = true
			if tok.lost or tok.lost_ghost then
				tok.lost_ghost = true
				tok.lost = true
			end
			local dest = bag_area_anchor(tok)
			tok.home = dest
		end
		local vel = tok.vel
		if vel:Length() < 0.8 then vel = Mouse_UI.mouse_delta end
		if vel:Length() > item.inertia_max then vel = vel:Resized(item.inertia_max) end
		tok.vel = vel * 0.65
		if tok.from_bag and tok.home then
			if tok.vel:Length() < 2.5 then
				begin_snap_anim(tok, tok.home)
			end
		end
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.4, 1, false, 0, 2)
	end
end

local function tick_tokens(panel, panel_rect, bag_rect, geom)
	local craft = panel.craft
	if not craft then return end
	reconcile_slot_occupancy(craft)
	local cost_pos = geom and geom.cost_pos
	local cost_center = cost_pos
	if geom and geom.cost_rect then
		cost_center = Mouse_UI.rect_center(geom.cost_rect)
	end
	local attract = item.cost_attract_dist or 52
	if geom and geom.cost_rect then
		attract = math.max(attract, math.max(geom.cost_rect.w, geom.cost_rect.h) * 0.55)
	end
	local cost_scale = get_cost_token_scale()
	for _, tok in ipairs(craft.tokens) do
		local near_cost = cost_center and (tok.pos - cost_center):Length() <= attract
		-- 材料槽内保持正常尺寸；仅成本占用或靠近成本带的游离 token 缩小
		local want_scale = 1
		if tok.cost then
			want_scale = cost_scale
		elseif not tok.slot and near_cost then
			want_scale = cost_scale
		end
		tok.visual_scale = (tok.visual_scale or 1) * 0.75 + want_scale * 0.25

		if panel.drag and panel.drag.token_id == tok.id then
			-- drag handled elsewhere
		elseif tick_token_anim(tok) then
			-- animating
		elseif tok.slot and craft.slots[tok.slot] and craft.slots[tok.slot]._rect then
			tok.pos = Mouse_UI.rect_center(craft.slots[tok.slot]._rect)
			tok.vel = Vector(0, 0)
		elseif tok.cost and cost_pos then
			local idx = 1
			for i, tid in ipairs(craft.cost_ids or {}) do
				if tid == tok.id then idx = i break end
			end
			tok.pos = cost_stack_pos(craft, geom, idx)
			tok.vel = Vector(0, 0)
		elseif not tok.slot and not tok.cost and cost_center and near_cost
			and not (tok.source == "prototype" or tok.is_prototype)
			and not (panel.pad_carry and panel.pad_carry.token_id == tok.id)
			and not (tok.from_bag and bag_rect and Mouse_UI.point_in_rect(tok.pos, bag_rect)
				and not (geom and geom.cost_rect and Mouse_UI.point_in_rect(tok.pos, geom.cost_rect)))
			and (not get_tutorial().is_locking() or get_tutorial().allows_cost_assign(tok)) then
			local pull = (cost_center - tok.pos) * 0.18
			tok.vel = (tok.vel + pull) * 0.85
			tok.pos = tok.pos + tok.vel
			if (tok.pos - cost_center):Length() <= item.snap_dist * 0.65 then
				assign_token_cost(craft, tok, geom)
			end
		elseif tok.vel:Length() > item.inertia_stop then
			tok.pos = tok.pos + tok.vel
			tok.vel = tok.vel * item.inertia_friction
			tok.pos = clamp_to_rect(tok.pos, panel_rect)
			if tok.vel:Length() <= item.inertia_stop then
				tok.vel = Vector(0, 0)
				if tok.from_bag and tok.home then
					begin_snap_anim(tok, tok.home)
				end
			end
		else
			tok.vel = Vector(0, 0)
		end
	end
end


-- ---------- UI 构建 ----------
local function draw_region_outline(rect, color, force)
	if not force and not item.debug_draw_regions then return end
	if not rect then return end
	color = tint_kcolor(color or KColor(0.4, 0.9, 0.6, 0.8))
	local off = get_dot_offset()
	local step = 8
	for x = 0, rect.w, step do
		gui.draw_ch(Vector(rect.x + x + off.X, rect.y + off.Y), ".", 1, 1, color, true)
		gui.draw_ch(Vector(rect.x + x + off.X, rect.y + rect.h - 2 + off.Y), ".", 1, 1, color, true)
	end
	for y = 0, rect.h, step do
		gui.draw_ch(Vector(rect.x + off.X, rect.y + y + off.Y), ".", 1, 1, color, true)
		gui.draw_ch(Vector(rect.x + rect.w - 2 + off.X, rect.y + y + off.Y), ".", 1, 1, color, true)
	end
end

local function build_list_ui(panel, panel_rect, content)
	local entries = {}
	local tab = item.tabs[panel.tab]
	local y0 = content.y + 4
	panel._bw_bar_rect = nil
	panel._form_bench_pages = 1
	if tab.id == "formation" then
		-- 编队页只读一次带宽快照；broken 由仓库/确认路径更新。
		local BW = get_bandwidth()
		local snap = BW.get_snapshot(panel.player)
		panel._bw_summary = {
			used_units = snap.used_units,
			capacity_units = snap.capacity_units,
			used_slots = snap.used_slots,
			capacity_slots = snap.capacity_slots,
			active = #(snap.active or {}),
			standby = #(snap.standby or {}),
		}
		panel._bw_bar_rect = Mouse_UI.make_rect(content.x + 4, y0, content.w - 8, 16)
		y0 = y0 + 20
		local remain_h = content.y + content.h - y0
		local queue_h = math.max(72, math.floor(remain_h * 0.58))
		local bench_h = math.max(56, remain_h - queue_h - 6)
		local queue_rect = Mouse_UI.make_rect(content.x + 4, y0, content.w - 8, queue_h)
		local bench_rect = Mouse_UI.make_rect(content.x + 4, y0 + queue_h + 4, content.w - 8, bench_h)
		local order = snap.order or {}
		local actives = {}
		local hangar = {}
		for _, uid in ipairs(order) do
			local rec = snap.rec_by_uid and snap.rec_by_uid[tostring(uid)]
			if rec then
				if not rec.display_name then refresh_rec_display_name(rec, panel.player) end
				if get_tutorial().should_show_rec(rec) then
					if snap.effective_active[tostring(rec.uid)] == true then
						actives[#actives + 1] = rec
					else
						hangar[#hangar + 1] = rec
					end
				end
			end
		end
		local sum = panel._bw_summary
		local cap_docks = math.max(3, math.floor((tonumber(sum and sum.capacity_slots) or 3) + 0.5))
		local dock_n = cap_docks
		local gap = 6
		local card_w = math.min(96, math.floor((queue_rect.w - gap * (dock_n + 1)) / math.max(1, dock_n)))
		local card_h = queue_rect.h - 16
		local queue_cards = {}
		local layouts = {}
		for i = 1, dock_n do
			local cx = queue_rect.x + gap + (i - 1) * (card_w + gap)
			local rect = Mouse_UI.make_rect(cx, queue_rect.y + 8, card_w, card_h)
			local rec = actives[i]
			if rec then
				local e = {
					uid = "form_q_"..rec.uid,
					kind = "form_card",
					zone = "queue",
					rec = rec,
					label = rec_label(rec),
					active = true,
					active_index = i,
				}
				layouts[#layouts + 1] = {entry = e, rect = rect}
				queue_cards[#queue_cards + 1] = {uid = rec.uid, rect = rect, active_index = i}
			else
				layouts[#layouts + 1] = {
					entry = {uid = "form_dock_"..i, kind = "form_dock", zone = "queue", active_index = i},
					rect = rect,
				}
			end
		end
		local page_size = item.form_bench_page_size or 4
		local pages = math.max(1, math.ceil(#hangar / page_size))
		local page = math.max(0, math.min(pages - 1, panel.form_bench_page or 0))
		panel.form_bench_page = page
		panel._form_bench_pages = pages
		local prev_rect = Mouse_UI.make_rect(bench_rect.x + 2, bench_rect.y + (bench_rect.h - 14) * 0.5, 16, 14)
		local next_rect = Mouse_UI.make_rect(bench_rect.x + bench_rect.w - 18, bench_rect.y + (bench_rect.h - 14) * 0.5, 16, 14)
		layouts[#layouts + 1] = {entry = {uid = "form_prev", kind = "form_page"}, rect = prev_rect}
		layouts[#layouts + 1] = {entry = {uid = "form_next", kind = "form_page"}, rect = next_rect}
		local inner_x = prev_rect.x + prev_rect.w + 4
		local inner_w = next_rect.x - inner_x - 4
		local b_gap = 5
		local b_w = math.min(78, math.floor((inner_w - b_gap * (page_size - 1)) / page_size))
		local b_h = bench_rect.h - 8
		local start_i = page * page_size + 1
		local bench_cards = {}
		for n = 0, page_size - 1 do
			local rec = hangar[start_i + n]
			local bx = inner_x + n * (b_w + b_gap)
			local rect = Mouse_UI.make_rect(bx, bench_rect.y + 4, b_w, b_h)
			if rec then
				local active = snap.effective_active[tostring(rec.uid)] == true
				local e = {
					uid = "form_b_"..rec.uid,
					kind = "form_card",
					zone = "bench",
					rec = rec,
					label = rec_label(rec),
					active = active == true,
				}
				layouts[#layouts + 1] = {entry = e, rect = rect}
				bench_cards[#bench_cards + 1] = {uid = rec.uid, rect = rect}
			end
		end
		panel._form_queue_rect = queue_rect
		panel._form_bench_rect = bench_rect
		panel._form_queue_cards = queue_cards
		panel._form_bench_cards = bench_cards
		return layouts
	elseif tab.id == "build" then
		for i, info in ipairs(item.build_targets) do
			entries[i] = {
				uid = "build_opt_"..i,
				kind = "build_target",
				target = info.id,
				label = target_label(info, panel.player),
				info = info,
			}
		end
	elseif tab.id == "inventory" then
		local del_w = 30
		for _, rec in ipairs(item.get_crafted_list(panel.player)) do
			if rec and rec.uid and get_tutorial().should_show_rec(rec) then
				if not rec.display_name then refresh_rec_display_name(rec, panel.player) end
				entries[#entries + 1] = {
					uid = "stock_"..rec.uid,
					del_uid = "stock_del_"..rec.uid,
					kind = "stock",
					rec = rec,
					label = rec_label(rec),
					broken = rec.broken == true,
				}
			end
		end
		-- del_w 在 layouts 里用
		panel._stock_del_w = del_w
	end

	local layouts = {}
	local y = y0
	local row_h = 28
	local del_w = panel._stock_del_w or 30
	for i, e in ipairs(entries) do
		local rect = Mouse_UI.make_rect(content.x + 4, y, content.w - 8, row_h)
		local del_rect = nil
		local tog_rect, up_rect, dn_rect, ed_rect = nil, nil, nil, nil
		if e.kind == "stock" and e.del_uid then
			del_rect = Mouse_UI.make_rect(rect.x + rect.w - del_w - 3, rect.y + 5, del_w, row_h - 10)
		elseif e.kind == "formation" then
			local bx = rect.x + rect.w - 3
			local bh = row_h - 10
			local by = rect.y + 5
			ed_rect = Mouse_UI.make_rect(bx - 28, by, 28, bh)
			dn_rect = Mouse_UI.make_rect(ed_rect.x - 16, by, 14, bh)
			up_rect = Mouse_UI.make_rect(dn_rect.x - 16, by, 14, bh)
			tog_rect = Mouse_UI.make_rect(up_rect.x - 36, by, 34, bh)
		end
		layouts[i] = {
			entry = e, rect = rect, del_rect = del_rect,
			tog_rect = tog_rect, up_rect = up_rect, dn_rect = dn_rect, ed_rect = ed_rect,
		}
		y = y + row_h + 4
	end
	return layouts
end

local function build_and_register_ui(panel)
	local screen = gui.GetScreenSize()
	local panel_rect = item.get_panel_rect()
	local tab_rects = item.get_tab_rects(panel_rect)
	local content = item.get_content_rect(panel_rect)
	local tab = item.tabs[panel.tab]

	Mouse_UI.begin_frame(panel.player)

	local function reg(id, rect, opts)
		opts = opts or {}
		if get_tutorial().is_locking() then
			local allow = get_tutorial().allows(id) == true
			opts.enabled = allow
			if not allow then opts.draggable = false end
		end
		Mouse_UI.register(id, rect, opts)
	end

	-- 拖动跟随
	if panel.drag and panel.craft then
		local tok = panel.craft.token_map[panel.drag.token_id]
		if tok then
			tok.pos = Mouse_UI.mouse - panel.drag.grab_offset
			tok.vel = Mouse_UI.mouse_delta * 0.85
			tok.pos = clamp_to_rect(tok.pos, panel_rect)
		end
	elseif panel.drag and panel.drag.kind == "form_card" then
		panel.drag.pos = Mouse_UI.mouse - panel.drag.grab_offset
	end

	reg("modal_dim", Mouse_UI.make_rect(0, 0, screen.X, screen.Y), {z = item.z_modal, block = true})
	reg("panel_body", panel_rect, {z = item.z_panel, block = true})

	for i = 1, #item.tabs do
		reg("tab_"..i, tab_rects[i], {z = item.z_tab, block = true})
	end

	local ui = {
		panel_rect = panel_rect,
		tab_rects = tab_rects,
		content = content,
		states = {},
		layouts = {},
		craft_geom = nil,
	}

	local in_craft = (panel.view == "craft" or panel.view == "edit") and panel.craft

	if in_craft then
		local g = craft_geometry(panel_rect, content, panel.craft)
		ui.craft_geom = g
		-- 按当前成本块高度刷新材料槽，保证成本行始终被占住
		refresh_slot_offsets(panel.craft, g.left.w - 8)
		rebuild_bag_tokens(panel, g.bag_inner, panel.player)
		-- 按当前槽位解析主武器，刷新条件亮起（炸弹→博士/史诗；剖腹产副武器→678）
		do
			local parts = {}
			for i, slot in ipairs(panel.craft.slots or {}) do
				local tok = slot.token and panel.craft.token_map and panel.craft.token_map[slot.token]
				parts[i] = tostring(tok and tok.collectible or 0)
			end
			local sig = table.concat(parts, ",")
			if panel.craft._preview_sig ~= sig then
				panel.craft._preview_sig = sig
				local ctx = CraftProfile.preview_weapon_context_from_craft(panel.craft, panel.player)
				panel.craft.preview_weapon = ctx.weapon
				panel.craft.preview_list = ctx.list
				for _, tok in ipairs(panel.craft.tokens or {}) do
					local col = tok.collectible
					if col then
						tok.gate_kind = CraftProfile.effect_gate_kind(col)
						tok.form_synergy = CraftProfile.form_synergy_for_collectible(col, panel.player)
						tok.lit = CraftProfile.is_effectively_lit(col, ctx)
					else
						tok.lit = true
						tok.form_synergy = nil
					end
				end
			end
		end
		-- 槽位世界矩形
		for i, slot in ipairs(panel.craft.slots) do
			slot._rect = Mouse_UI.make_rect_centered(
				Vector(g.target_pos.X + slot.ox, g.target_pos.Y + slot.oy),
				item.slot_size, item.slot_size
			)
		end
		tick_tokens(panel, panel_rect, g.bag_inner, g)

		reg("btn_back", g.back_rect, {z = item.z_button, block = true})
		reg("btn_confirm", g.confirm_rect, {z = item.z_button, block = true})
		if g.quality_rect then
			reg("btn_quality", g.quality_rect, {z = item.z_button, block = true})
		end
		if not (panel.craft and panel.craft.tutorial_bag) then
			reg("btn_mode", g.mode_rect, {z = item.z_button, block = true})
		end
		reg("btn_prev", g.prev_rect, {z = item.z_button, block = true})
		reg("btn_next", g.next_rect, {z = item.z_button, block = true})
		if g.tag_col then
			reg("btn_tag_all", g.tag_col.all_rect, {z = item.z_button, block = true})
			reg("btn_tag_invert", g.tag_col.invert_rect, {z = item.z_button, block = true})
			for key, rect in pairs(g.tag_col.tag_rects or {}) do
				reg("btn_tag_"..key, rect, {z = item.z_button, block = true})
			end
		end
		local charge_list = list_charge_sliders(panel.craft)
		ui.charge_sliders = charge_list
		for i, info in ipairs(charge_list) do
			local rect = g.charge_slider_rects and g.charge_slider_rects[i]
			if rect then
				info.rect = rect
				-- 球体在两端会贴住视觉槽边；交互区左右各外扩 8px，比例仍按原 144px 槽计算。
				local hit_rect = Mouse_UI.make_rect(rect.x - 8, rect.y, rect.w + 16, rect.h)
				reg(info.id, hit_rect, {z = item.z_button + 1, block = true})
			end
		end
		if g.cost_rect then
			reg("cost_slot", g.cost_rect, {z = item.z_slot, block = true, drop_target = true})
		end
		for i, slot in ipairs(panel.craft.slots) do
			reg("cslot_"..i, slot._rect, {z = item.z_slot, block = true, drop_target = true})
		end
		for _, tok in ipairs(panel.craft.tokens) do
			local z = item.z_token
			if panel.drag and panel.drag.token_id == tok.id then z = item.z_token + 5 end
			reg(tok.id, token_rect(tok), {z = z, block = true, draggable = true})
		end
	else
		ui.layouts = build_list_ui(panel, panel_rect, content)
		ui.form_queue_rect = panel._form_queue_rect
		ui.form_bench_rect = panel._form_bench_rect
		ui.form_queue_cards = panel._form_queue_cards
		ui.form_bench_cards = panel._form_bench_cards
		if ui.form_queue_rect then
			reg("form_queue", ui.form_queue_rect, {z = item.z_button - 2, block = true, drop_target = true})
		end
		if ui.form_bench_rect then
			reg("form_bench", ui.form_bench_rect, {z = item.z_button - 2, block = true, drop_target = true})
		end
		for _, lay in ipairs(ui.layouts) do
			local z = item.z_button
			local draggable = lay.entry.kind == "form_card"
			if panel.drag and panel.drag.kind == "form_card" and panel.drag.uid == (lay.entry.rec and lay.entry.rec.uid) then
				z = item.z_token + 5
			end
			reg(lay.entry.uid, lay.rect, {z = z, block = true, draggable = draggable})
			if lay.del_rect and lay.entry.del_uid then
				reg(lay.entry.del_uid, lay.del_rect, {z = item.z_button + 2, block = true})
			end
		end
	end

	ui.tut = get_tutorial().prepare_overlay(panel, panel_rect)
	if ui.tut then
		for _, b in ipairs(ui.tut.buttons or {}) do
			local r = b.rect
			reg(b.id, Mouse_UI.make_rect(r.x, r.y, r.w, r.h), {z = item.z_token + 20, block = true})
		end
	end

	Mouse_UI.end_frame()

	ui.hovered = Mouse_UI.get_hovered_id()
	for i = 1, #item.tabs do
		ui.states["tab_"..i] = Mouse_UI.get_state("tab_"..i)
	end
	ui.states.btn_back = Mouse_UI.get_state("btn_back")
	ui.states.btn_confirm = Mouse_UI.get_state("btn_confirm")
	ui.states.btn_quality = Mouse_UI.get_state("btn_quality")
	ui.states.btn_mode = Mouse_UI.get_state("btn_mode")
	ui.states.btn_prev = Mouse_UI.get_state("btn_prev")
	ui.states.btn_next = Mouse_UI.get_state("btn_next")
	ui.states.btn_tag_all = Mouse_UI.get_state("btn_tag_all")
	ui.states.btn_tag_invert = Mouse_UI.get_state("btn_tag_invert")
	if ui.craft_geom and ui.craft_geom.tag_col then
		for _, def in ipairs(ui.craft_geom.tag_col.defs or {}) do
			ui.states["btn_tag_"..def.key] = Mouse_UI.get_state("btn_tag_"..def.key)
		end
	end
	ui.states.main_charge_slider = Mouse_UI.get_state("main_charge_slider")
	ui.states.modal_dim = Mouse_UI.get_state("modal_dim")
	if panel.craft then
		for i = 1, #panel.craft.slots do
			ui.states["cslot_"..i] = Mouse_UI.get_state("cslot_"..i)
		end
		for _, tok in ipairs(panel.craft.tokens) do
			ui.states[tok.id] = Mouse_UI.get_state(tok.id)
		end
	end
	for _, lay in ipairs(ui.layouts) do
		ui.states[lay.entry.uid] = Mouse_UI.get_state(lay.entry.uid)
		if lay.entry.del_uid then
			ui.states[lay.entry.del_uid] = Mouse_UI.get_state(lay.entry.del_uid)
		end
	end
	if ui.tut then
		for _, b in ipairs(ui.tut.buttons or {}) do
			ui.states[b.id] = Mouse_UI.get_state(b.id)
		end
	end
	panel.ui = ui
	return ui
end

-- ---------- 分组四向导航（tabs 与内容分离；边缘前进回第一项）----------
local function nav_add(list, id, x, y, meta)
	if not id then return end
	list[#list + 1] = {id = id, x = x, y = y, meta = meta or {}}
end

local function index_of_id(list, id)
	for i, n in ipairs(list) do
		if n.id == id then return i end
	end
	return nil
end

local function sort_reading(list)
	table.sort(list, function(a, b)
		if math.abs(a.y - b.y) > 10 then return a.y < b.y end
		return a.x < b.x
	end)
end

--- 组内前进方向无目标时回到第一项；后退方向无目标时回到最后一项（不反向挪到邻轴）
local function pick_forward_or_edge(list, from, dirx, diry)
	local best_id, best = nil, math.huge
	for _, to in ipairs(list) do
		if to.id ~= from.id then
			local dx, dy = to.x - from.x, to.y - from.y
			local primary = dx * dirx + dy * diry
			local lateral = math.abs(dx * (-diry) + dy * dirx)
			if primary > 3 then
				local s = primary + lateral * 2.4
				if s < best then best, best_id = s, to.id end
			end
		end
	end
	if best_id then return best_id end
	if #list == 0 then return from.id end
	-- 右/下：回第一项；左/上：去最后一项
	if dirx > 0 or diry > 0 then
		return list[1].id
	end
	return list[#list].id
end

local function rebuild_nav_groups(panel, ui)
	local tabs = {}
	for i = 1, #item.tabs do
		local r = ui.tab_rects[i]
		if r then nav_add(tabs, "tab_"..i, r.x + r.w * 0.5, r.y + r.h * 0.5) end
	end

	local body = {}
	local craft = panel.craft
	local g = ui.craft_geom
	local body_name = "body"

	if craft and g then
		if panel.pad_carry then
			body_name = "carry"
			for i, slot in ipairs(craft.slots) do
				if slot._rect then
					local c = Mouse_UI.rect_center(slot._rect)
					nav_add(body, "cslot_"..i, c.X, c.Y, {slot = true})
				end
			end
			if g.cost_rect then
				nav_add(body, "cost_slot", g.cost_pos.X, g.cost_pos.Y, {cost = true})
			end
			for _, tok in ipairs(craft.tokens) do
				if tok.from_bag and tok.id ~= panel.pad_carry.token_id then
					local p = tok.home or tok.pos
					if p then nav_add(body, "dropbag_"..tok.id, p.X, p.Y, {bag = true}) end
				end
			end
			local has_bag = false
			for _, n in ipairs(body) do if n.meta.bag then has_bag = true break end end
			if not has_bag and g.bag_inner then
				nav_add(body, "bag_return", g.bag_inner.x + g.bag_inner.w * 0.5, g.bag_inner.y + g.bag_inner.h * 0.5, {bag = true})
			end
			nav_add(body, "btn_back", g.back_rect.x + g.back_rect.w * 0.5, g.back_rect.y + g.back_rect.h * 0.5)
		else
			if g.quality_rect then
				nav_add(body, "btn_quality", g.quality_rect.x + g.quality_rect.w * 0.5, g.quality_rect.y + g.quality_rect.h * 0.5)
			end
			if not craft.tutorial_bag then
				nav_add(body, "btn_mode", g.mode_rect.x + g.mode_rect.w * 0.5, g.mode_rect.y + g.mode_rect.h * 0.5)
			end
			if g.tag_col then
				nav_add(body, "btn_tag_all", g.tag_col.all_rect.x + g.tag_col.all_rect.w * 0.5, g.tag_col.all_rect.y + g.tag_col.all_rect.h * 0.5)
				nav_add(body, "btn_tag_invert", g.tag_col.invert_rect.x + g.tag_col.invert_rect.w * 0.5, g.tag_col.invert_rect.y + g.tag_col.invert_rect.h * 0.5)
				for _, def in ipairs(g.tag_col.defs or {}) do
					local r = g.tag_col.tag_rects and g.tag_col.tag_rects[def.key]
					if r then
						nav_add(body, "btn_tag_"..def.key, r.x + r.w * 0.5, r.y + r.h * 0.5)
					end
				end
			end
			nav_add(body, "btn_prev", g.prev_rect.x + g.prev_rect.w * 0.5, g.prev_rect.y + g.prev_rect.h * 0.5)
			nav_add(body, "btn_next", g.next_rect.x + g.next_rect.w * 0.5, g.next_rect.y + g.next_rect.h * 0.5)
			if g.cost_rect then
				nav_add(body, "cost_slot", g.cost_pos.X, g.cost_pos.Y, {cost = true})
			end
			for i, slot in ipairs(craft.slots) do
				if slot._rect and slot.token then
					local c = Mouse_UI.rect_center(slot._rect)
					nav_add(body, "cslot_"..i, c.X, c.Y, {slot = true})
				end
			end
			for _, tok in ipairs(craft.tokens) do
				if tok.from_bag and not tok.slot then
					local p = tok.pos or tok.home
					if p then nav_add(body, tok.id, p.X, p.Y, {token = true}) end
				end
			end
			nav_add(body, "btn_confirm", g.confirm_rect.x + g.confirm_rect.w * 0.5, g.confirm_rect.y + g.confirm_rect.h * 0.5)
			nav_add(body, "btn_back", g.back_rect.x + g.back_rect.w * 0.5, g.back_rect.y + g.back_rect.h * 0.5)
		end
	else
		for _, lay in ipairs(ui.layouts or {}) do
			local r = lay.rect
			if r and lay.entry and lay.entry.kind ~= "todo" then
				nav_add(body, lay.entry.uid, r.x + 40, r.y + r.h * 0.5, {list = true})
				if lay.del_rect and lay.entry.del_uid then
					local dr = lay.del_rect
					nav_add(body, lay.entry.del_uid, dr.x + dr.w * 0.5, dr.y + dr.h * 0.5, {list_del = true})
				end
			end
		end
	end

	sort_reading(tabs)
	sort_reading(body)

	if ui.tut then
		for _, b in ipairs(ui.tut.buttons or {}) do
			local r = b.rect
			if r then nav_add(body, b.id, r.x + r.w * 0.5, r.y + r.h * 0.5) end
		end
		sort_reading(body)
	end
	if get_tutorial().is_locking() then
		local function keep_allowed(list)
			local out = {}
			for _, n in ipairs(list) do
				if get_tutorial().allows(n.id) then out[#out + 1] = n end
			end
			return out
		end
		tabs = keep_allowed(tabs)
		body = keep_allowed(body)
	end

	-- 搬运模式只有 body 组；其它时候 tabs + body
	local groups = {}
	if body_name == "carry" then
		groups.carry = body
		panel.nav_group = "carry"
	else
		groups.tabs = tabs
		groups.body = body
		if panel.nav_group ~= "tabs" and panel.nav_group ~= "body" then
			panel.nav_group = panel.craft and "body" or "tabs"
		end
	end

	panel._nav_groups = groups
	panel._focus_nodes = body_name == "carry" and body or (panel.nav_group == "tabs" and tabs or body)

	-- 校正焦点落在当前组内
	local cur = groups[panel.nav_group]
	if not cur or #cur == 0 then
		if groups.tabs and #groups.tabs > 0 then
			panel.nav_group = "tabs"
			cur = groups.tabs
		elseif groups.body and #groups.body > 0 then
			panel.nav_group = "body"
			cur = groups.body
		elseif groups.carry and #groups.carry > 0 then
			panel.nav_group = "carry"
			cur = groups.carry
		end
	end
	if cur and #cur > 0 and not index_of_id(cur, panel.focus_id) then
		panel.focus_id = cur[1].id
	end
	return groups
end

local function rebuild_focus_graph(panel, ui)
	return rebuild_nav_groups(panel, ui)
end

local function is_top_row_of(list, id)
	local idx = index_of_id(list, id)
	if not idx then return true end
	local y0 = list[idx].y
	for i = 1, #list do
		if list[i].y < y0 - 10 then return false end
	end
	return true
end

local function move_focus(panel, dir)
	local groups = panel._nav_groups
	if not groups then return false end
	local gname = panel.nav_group or "tabs"
	local list = groups[gname]
	if not list or #list == 0 then return false end
	local idx = index_of_id(list, panel.focus_id) or 1
	local from = list[idx]

	-- 组切换：tabs ↔ body
	if gname == "tabs" then
		if dir == "down" and groups.body and #groups.body > 0 then
			panel.body_focus_mem = panel.body_focus_mem
			panel.nav_group = "body"
			local mem = panel.body_focus_mem
			if mem and index_of_id(groups.body, mem) then
				panel.focus_id = mem
			else
				panel.focus_id = groups.body[1].id
			end
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.25, 1.1, false, 0, 2)
			return true
		end
		if dir == "up" then return false end
		-- 左右只在 tabs 内；越界回第一/最后
		local dirx = (dir == "right" and 1) or (dir == "left" and -1) or 0
		if dirx == 0 then return false end
		-- 选项页用线性左右更直观
		local nidx
		if dir == "right" then
			nidx = (idx >= #list) and 1 or (idx + 1)
		else
			nidx = (idx <= 1) and #list or (idx - 1)
		end
		if list[nidx].id == panel.focus_id then return false end
		panel.focus_id = list[nidx].id
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.25, 1.1, false, 0, 2)
		return true
	end

	if (gname == "body" or gname == "carry") then
		if gname == "body" and dir == "up" and is_top_row_of(list, from.id) and groups.tabs and #groups.tabs > 0 then
			panel.body_focus_mem = panel.focus_id
			panel.nav_group = "tabs"
			panel.focus_id = "tab_"..tostring(panel.tab or 1)
			if not index_of_id(groups.tabs, panel.focus_id) then
				panel.focus_id = groups.tabs[1].id
			end
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.25, 1.1, false, 0, 2)
			return true
		end
		local dirx = (dir == "right" and 1) or (dir == "left" and -1) or 0
		local diry = (dir == "down" and 1) or (dir == "up" and -1) or 0
		local nxt = pick_forward_or_edge(list, from, dirx, diry)
		if not nxt or nxt == panel.focus_id then return false end
		panel.focus_id = nxt
		if gname == "body" then panel.body_focus_mem = nxt end
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.25, 1.1, false, 0, 2)
		return true
	end
	return false
end

local function get_held_nav_dir(ctrlid)
	local function down(a) return Input.IsActionPressed(a, ctrlid) end
	-- 同时按下时优先最近一次：按左/右/上/下固定优先级
	if down(ButtonAction.ACTION_LEFT) or down(ButtonAction.ACTION_MENULEFT) then return "left" end
	if down(ButtonAction.ACTION_RIGHT) or down(ButtonAction.ACTION_MENURIGHT) then return "right" end
	if down(ButtonAction.ACTION_UP) or down(ButtonAction.ACTION_MENUUP) then return "up" end
	if down(ButtonAction.ACTION_DOWN) or down(ButtonAction.ACTION_MENUDOWN) then return "down" end
	return nil
end

local function clear_bag_tokens_keep_busy(craft, panel)
	local kept, kept_map = {}, {}
	for _, tok in ipairs(craft.tokens) do
		if tok.slot or tok.cost or (panel.drag and panel.drag.token_id == tok.id)
			or (panel.pad_carry and panel.pad_carry.token_id == tok.id) then
			kept[#kept + 1] = tok
			kept_map[tok.id] = tok
		end
	end
	craft.tokens = kept
	craft.token_map = kept_map
	craft._bag_dirty = true
end

local function toggle_all_items_mode(panel)
	local craft = panel.craft
	if not craft or craft.tutorial_bag then return end
	craft.all_items = not craft.all_items
	craft.bag_page = 0
	craft._catalog = nil
	craft._catalog_impl = nil
	craft._catalog_missing_stat = nil
	if craft.all_items then
		local prefs = get_audit_ui_prefs(panel.player)
		craft.audit_filter = "all"
		craft.hide_gray = false
		craft.tag_enabled = CraftProfile.normalize_audit_tag_enabled(
			prefs.tag_enabled, prefs.audit_filter or (prefs.hide_gray and "impl" or "all")
		)
		prefs.tag_enabled = craft.tag_enabled
		prefs.audit_filter = "all"
		prefs.hide_gray = false
	end
	clear_bag_tokens_keep_busy(craft, panel)
	panel.nav_graph = nil
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.55, 1, false, 0, 2)
end

local function persist_craft_tag_prefs(panel, craft)
	local prefs = get_audit_ui_prefs(panel.player)
	prefs.tag_enabled = CraftProfile.normalize_audit_tag_enabled(craft.tag_enabled)
	craft.tag_enabled = prefs.tag_enabled
	prefs.audit_filter = "all"
	prefs.hide_gray = false
end

local function refresh_after_tag_change(panel, craft)
	craft.bag_page = 0
	clear_bag_tokens_keep_busy(craft, panel)
	panel.nav_graph = nil
	persist_craft_tag_prefs(panel, craft)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.4, 1, false, 0, 2)
end

local function toggle_audit_tag(panel, key)
	local craft = panel.craft
	if not craft or not craft.all_items or not key then return end
	craft.tag_enabled = CraftProfile.normalize_audit_tag_enabled(craft.tag_enabled)
	craft.tag_enabled[key] = not (craft.tag_enabled[key] == true)
	refresh_after_tag_change(panel, craft)
end

local function enable_all_audit_tags(panel)
	local craft = panel.craft
	if not craft or not craft.all_items then return end
	craft.tag_enabled = CraftProfile.default_audit_tag_enabled()
	refresh_after_tag_change(panel, craft)
end

local function invert_audit_tags(panel)
	local craft = panel.craft
	if not craft or not craft.all_items then return end
	craft.tag_enabled = CraftProfile.normalize_audit_tag_enabled(craft.tag_enabled)
	for _, def in ipairs(CraftProfile.audit_filter_tag_defs()) do
		craft.tag_enabled[def.key] = not (craft.tag_enabled[def.key] == true)
	end
	refresh_after_tag_change(panel, craft)
end

local function cancel_pad_carry(panel)
	local craft = panel.craft
	if not craft or not panel.pad_carry then return end
	local tok = craft.token_map[panel.pad_carry.token_id]
	panel.pad_carry = nil
	if tok then
		clear_token_slot(craft, tok)
		if tok.home then begin_snap_anim(tok, tok.home) end
	end
	panel.nav_group = "body"
	panel.focus_id = tok and tok.id or "btn_confirm"
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.4, 1, false, 0, 2)
end

-- 副手 = 口袋主动；此时面板内 Q ≡ Ctrl 退出（否则只拦 Q，防误用卡牌）
local function blueprint_is_pocket_active(player)
	if not player then return false end
	if player:GetActiveItem(ActiveSlot.SLOT_POCKET) == item.entity then return true end
	if ActiveSlot.SLOT_POCKET2 and player:GetActiveItem(ActiveSlot.SLOT_POCKET2) == item.entity then return true end
	return false
end

-- PILLCARD 被 MC_INPUT_ACTION 拦掉后，IsAction* 读不到真值；探测时放行一次并缓存本帧
local pillcard = {
	probe = false,
	cache_frame = -1,
	cache_trig = false,
	cache_held = false,
}

local function refresh_pillcard_cache(ctrlid)
	ctrlid = ctrlid or 0
	local frame = Game():GetFrameCount()
	if pillcard.cache_frame == frame then return end
	pillcard.cache_frame = frame
	pillcard.cache_trig = false
	pillcard.cache_held = false
	pillcard.probe = true
	pillcard.cache_trig = Input.IsActionTriggered(ButtonAction.ACTION_PILLCARD, ctrlid) == true
	pillcard.cache_held = Input.IsActionPressed(ButtonAction.ACTION_PILLCARD, ctrlid) == true
	pillcard.probe = false
end

local function pocket_q_exit_triggered(player, ctrlid)
	if not blueprint_is_pocket_active(player) then return false end
	refresh_pillcard_cache(ctrlid)
	if pillcard.cache_trig then return true end
	if Keyboard and Input.IsButtonTriggered(Keyboard.KEY_Q, 0) then return true end
	return false
end

local function pocket_q_exit_held(player, ctrlid)
	if not blueprint_is_pocket_active(player) then return false end
	refresh_pillcard_cache(ctrlid)
	if pillcard.cache_held then return true end
	if Keyboard and Input.IsButtonPressed(Keyboard.KEY_Q, 0) then return true end
	return false
end

--- ESC / CTRL(DROP) / MENUBACK /（口袋副手时）Q：逐级退出（搬运→制造页→关面板）
local function exit_key_triggered(ctrlid, player)
	ctrlid = ctrlid or 0
	if Input.IsActionTriggered(ButtonAction.ACTION_DROP, ctrlid) then return true end
	if Input.IsActionTriggered(ButtonAction.ACTION_MENUBACK, ctrlid) then return true end
	if Keyboard then
		if Input.IsButtonTriggered(Keyboard.KEY_ESCAPE, 0) then return true end
		if Input.IsButtonTriggered(Keyboard.KEY_LEFT_CONTROL, 0) then return true end
		if Input.IsButtonTriggered(Keyboard.KEY_RIGHT_CONTROL, 0) then return true end
	end
	if player and pocket_q_exit_triggered(player, ctrlid) then return true end
	return false
end

local function exit_key_held(ctrlid, player)
	ctrlid = ctrlid or 0
	if Input.IsActionPressed(ButtonAction.ACTION_DROP, ctrlid) then return true end
	if Input.IsActionPressed(ButtonAction.ACTION_MENUBACK, ctrlid) then return true end
	if Keyboard then
		if Input.IsButtonPressed(Keyboard.KEY_ESCAPE, 0) then return true end
		if Input.IsButtonPressed(Keyboard.KEY_LEFT_CONTROL, 0) then return true end
		if Input.IsButtonPressed(Keyboard.KEY_RIGHT_CONTROL, 0) then return true end
	end
	if player and pocket_q_exit_held(player, ctrlid) then return true end
	return false
end

local function panel_keys_held(ctrlid, player)
	ctrlid = ctrlid or 0
	if exit_key_held(ctrlid, player) then return true end
	if Input.IsActionPressed(ButtonAction.ACTION_ITEM, ctrlid) then return true end
	if Input.IsActionPressed(ButtonAction.ACTION_MENUCONFIRM, ctrlid) then return true end
	if Input.IsActionPressed(ButtonAction.ACTION_LEFT, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_RIGHT, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_UP, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_DOWN, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_SHOOTLEFT, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_SHOOTRIGHT, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_SHOOTUP, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_SHOOTDOWN, ctrlid)
	then
		return true
	end
	return false
end

local function pause_menu_open()
	return REPENTOGON and Game().IsPauseMenuOpen and Game():IsPauseMenuOpen()
end

--- 对齐逢魔：面板开着且未进暂停时拦截输入（含 ent==nil 的菜单查询）
local function blueprint_input_active()
	scrub_stale_panel()
	if not panel_is_alive() then return false end
	if pause_menu_open() then return false end
	return true
end

local function disarm_until_release(panel)
	if not panel then return end
	panel.input_armed = false
	panel.wait_drop_release = true
end

local function try_panel_exit(panel)
	if not panel or input_locked(panel) then return false end
	local tut = get_tutorial()
	local advanced = tut.note_close_attempt and tut.note_close_attempt(panel.player) == true
	if tut.blocks_close(panel.player) then
		if advanced then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.45, 1, false, 0, 2)
		else
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.45, 1.2, false, 0, 2)
		end
		lock_actions(panel)
		return true
	end
	if panel.pad_carry then
		cancel_pad_carry(panel)
		lock_actions(panel)
		return true
	end
	if panel.craft then
		if panel.view == "edit" then cancel_edit(panel) else leave_craft_view(panel) end
		lock_actions(panel)
		return true
	end
	close_panel()
	return true
end

local function start_pad_carry(panel, tok)
	if not tok then return end
	clear_token_slot(panel.craft, tok)
	panel.pad_carry = {token_id = tok.id}
	panel.drag = nil
	tok.anim = nil
	tok.vel = Vector(0, 0)
	panel.nav_group = "carry"
	panel.focus_id = "cslot_1"
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.45, 1, false, 0, 2)
end

local function activate_focus(panel, ui)
	local id = panel.focus_id
	if not id then return end
	if id == "tut_yes" then
		get_tutorial().accept(panel.player)
		lock_actions(panel)
		return
	end
	if id == "tut_no" then
		get_tutorial().decline(panel.player)
		lock_actions(panel)
		return
	end
	if get_tutorial().is_locking() and not get_tutorial().allows(id) then
		return
	end
	local craft = panel.craft

	if panel.pad_carry and craft then
		local tok = craft.token_map[panel.pad_carry.token_id]
		if not tok then
			panel.pad_carry = nil
			return
		end
		if id == "btn_back" then
			cancel_pad_carry(panel)
			lock_actions(panel)
			return
		end
		if id:sub(1, 6) == "cslot_" then
			local idx = tonumber(id:sub(7))
			if idx then
				assign_token_slot(craft, tok, idx)
				panel.pad_carry = nil
				panel.nav_group = "body"
				panel.focus_id = id
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.7, 1.05, false, 0, 2)
				lock_actions(panel)
			end
			return
		end
		if id == "cost_slot" then
			assign_token_cost(craft, tok, ui and ui.craft_geom)
			panel.pad_carry = nil
			panel.nav_group = "body"
			panel.focus_id = "cost_slot"
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.65, 0.95, false, 0, 2)
			lock_actions(panel)
			return
		end
		if id:sub(1, 8) == "dropbag_" or id == "bag_return" then
			clear_token_slot(craft, tok)
			if craft.all_items and type(tok.id) == "string" and tok.id:sub(1, 5) == "inst_" then
				remove_token_entity(craft, tok)
			else
				if not craft.all_items then
					tok.from_bag = true
					if tok.lost or tok.lost_ghost then
						tok.lost_ghost = true
						tok.lost = true
					end
				end
				local dest = tok.home or bag_area_anchor(tok)
				tok.home = dest
				begin_snap_anim(tok, dest)
			end
			panel.pad_carry = nil
			panel.nav_group = "body"
			panel.focus_id = (id:sub(1, 8) == "dropbag_") and id:sub(9) or "btn_confirm"
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.4, 1, false, 0, 2)
			lock_actions(panel)
			return
		end
		return
	end

	if id:sub(1, 4) == "tab_" then
		local idx = tonumber(id:sub(5))
		if idx then
			local tab_info = item.tabs[idx]
			-- 已在建造列表：再确认则聚焦下方第一项，便于连按空格进入制造
			if tab_info and tab_info.id == "build"
				and panel.tab == idx and not panel.craft
			then
				local body = panel._nav_groups and panel._nav_groups.body
				if body and #body > 0 then
					panel.nav_group = "body"
					panel.focus_id = body[1].id
					panel.body_focus_mem = body[1].id
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
					lock_actions(panel)
					return
				end
			end
			set_tab(panel, idx)
			lock_actions(panel)
		end
		return
	end

	if craft then
		if id == "btn_back" then
			if panel.view == "edit" then cancel_edit(panel) else leave_craft_view(panel) end
			lock_actions(panel)
			return
		end
		if id == "btn_confirm" then
			confirm_craft(panel)
			lock_actions(panel)
			return
		end
		if id == "btn_quality" then
			toggle_show_quality(panel)
			lock_actions(panel)
			return
		end
		if id == "btn_mode" then
			toggle_all_items_mode(panel)
			lock_actions(panel)
			return
		end
		if id == "btn_tag_all" then
			enable_all_audit_tags(panel)
			lock_actions(panel)
			return
		end
		if id == "btn_tag_invert" then
			invert_audit_tags(panel)
			lock_actions(panel)
			return
		end
		if type(id) == "string" and id:sub(1, 8) == "btn_tag_" then
			local key = id:sub(9)
			if key ~= "all" and key ~= "invert" then
				toggle_audit_tag(panel, key)
				lock_actions(panel)
			end
			return
		end
		if id == "btn_prev" then
			craft.bag_page = math.max(0, (craft.bag_page or 0) - 1)
			clear_bag_tokens_keep_busy(craft, panel)
			panel.nav_graph = nil
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
			lock_actions(panel)
			return
		end
		if id == "btn_next" then
			local pages = craft.bag_pages or 1
			craft.bag_page = math.min(pages - 1, (craft.bag_page or 0) + 1)
			clear_bag_tokens_keep_busy(craft, panel)
			panel.nav_graph = nil
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
			lock_actions(panel)
			return
		end
		if id == "cost_slot" then
			local ids = craft.cost_ids or {}
			local tid = ids[#ids]
			local ctok = tid and craft.token_map[tid]
			if ctok then start_pad_carry(panel, ctok) lock_actions(panel) end
			return
		end
		if id:sub(1, 6) == "cslot_" then
			local idx = tonumber(id:sub(7))
			local slot = idx and craft.slots[idx]
			if slot and slot.token then
				local tok = craft.token_map[slot.token]
				if tok then start_pad_carry(panel, tok) lock_actions(panel) end
			end
			return
		end
		local tok = craft.token_map[id]
		if tok then
			start_pad_carry(panel, tok)
			lock_actions(panel)
			return
		end
		return
	end

	if handle_formation_id(panel, id) then
		lock_actions(panel)
		return
	end

	for _, lay in ipairs(ui.layouts or {}) do
		if lay.entry and lay.entry.uid == id then
			local e = lay.entry
			panel.delete_confirm_uid = nil
			if e.kind == "build_target" then
				open_craft_view(panel, e.target, nil)
			elseif e.kind == "stock" then
				open_craft_view(panel, e.rec.target, e.rec.uid)
			end
			lock_actions(panel)
			return
		end
		if lay.entry and lay.entry.del_uid == id and lay.entry.kind == "stock" then
			try_confirm_delete_stock(panel, lay.entry.rec.uid)
			lock_actions(panel)
			return
		end
	end
end

local function handle_pad_actions(panel, ui)
	local player = panel.player
	if not player then return end
	local ctrlid = player.ControllerIndex
	rebuild_focus_graph(panel, ui)

	-- 搬运中：道具跟随焦点
	if panel.pad_carry and panel.craft then
		local tok = panel.craft.token_map[panel.pad_carry.token_id]
		local list = panel._nav_groups and panel._nav_groups.carry
		if tok and list then
			for _, n in ipairs(list) do
				if n.id == panel.focus_id then
					tok.pos = Vector(n.x, n.y)
					break
				end
			end
		end
	end

	-- 长按连发（仿输入法：首次立即，等待 initial，再按 interval 连发）
	local frame = Game():GetFrameCount()
	local held = get_held_nav_dir(ctrlid)
	local hold = panel.nav_hold
	if held then
		if not hold or hold.dir ~= held then
			panel.nav_hold = {dir = held, next_fire = frame + item.nav_repeat_initial}
			move_focus(panel, held)
		elseif frame >= (hold.next_fire or 0) then
			move_focus(panel, held)
			hold.next_fire = frame + item.nav_repeat_interval
		end
	else
		panel.nav_hold = nil
	end

	if input_locked(panel) then return end

	local function trig(a)
		return Input.IsActionTriggered(a, ctrlid)
	end
	if trig(ButtonAction.ACTION_MENUCONFIRM) or trig(ButtonAction.ACTION_ITEM) then
		activate_focus(panel, ui)
		return
	end
	-- 退出键统一在 update_panel_input（ESC/CTRL/DROP/MENUBACK），避免同帧双退
end

local function capture_mouse_wheel(panel, source)
	if not panel or not Input.GetMouseWheel then return end
	local ok, wheel = pcall(function() return Input.GetMouseWheel() end)
	if not ok or not wheel then
		return
	end
	local dy = tonumber(wheel.Y) or 0
	local dx = tonumber(wheel.X) or 0
	if dx ~= 0 or dy ~= 0 then
		panel.wheel_pending = {x = dx, y = dy, source = source, serial = panel.wheel_render_serial}
	end
end

local function try_mouse_wheel_page(panel, ui)
	if get_tutorial().is_locking() then return end
	if not panel.craft or not ui or not ui.craft_geom then return end
	-- 渲染帧率可高于 update；禁止用 Game frame 去重，否则会吞同一 update 帧内的滚轮脉冲。
	local serial = panel.wheel_render_serial or 0
	if panel.wheel_read_serial == serial then return end
	-- 制造页没有其他可滚动容器：面板打开期间，滚轮默认延拓给背包。
	-- 不再要求鼠标命中左右栏；移到面板外也能继续翻页。

	local wheel = panel.wheel_pending
	if not wheel then return end
	panel.wheel_pending = nil
	local dy = tonumber(wheel.y) or 0
	local dx = tonumber(wheel.x) or 0
	-- 少数设备把竖滚报到 X；优先 Y，否则用 X
	local delta = dy
	if delta == 0 then delta = dx end
	if delta == 0 then return end
	panel.wheel_read_serial = serial

	-- Windows 常见 ±120；高精度滚轮/触摸板可能只报小于 1 的非零量。
	-- 页面不是连续滚动容器，因此一次非零脉冲至少翻一页，避免第一下只充累加器。
	local notches
	if math.abs(delta) >= 40 then
		notches = delta / 120
		if math.abs(notches) < 1 then notches = delta > 0 and 1 or -1 end
	else
		notches = delta > 0 and 1 or -1
	end

	-- 描述区优先接管滚轮；移出后继续使用默认延拓的背包翻页。
	local audit_rect = panel.audit_scroll_rect
	local audit_max = math.max(0, tonumber(panel.audit_scroll_max) or 0)
	if audit_rect and Mouse_UI.point_in_rect(Mouse_UI.mouse, audit_rect) and audit_max > 0 then
		local old = math.max(0, math.min(audit_max, tonumber(panel.craft.audit_scroll) or 0))
		local steps = math.max(1, math.floor(math.abs(notches) + 0.5))
		local next_scroll = old + (notches > 0 and -steps or steps)
		next_scroll = math.max(0, math.min(audit_max, next_scroll))
		panel.craft.audit_scroll = next_scroll
		panel.wheel_accum = 0
		if next_scroll ~= old then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.22, 1.08, false, 0, 2)
		end
		return
	end
	panel.wheel_accum = (panel.wheel_accum or 0) + notches

	local pages = math.max(1, panel.craft.bag_pages or 1)
	local page = panel.craft.bag_page or 0
	local changed = false
	while panel.wheel_accum >= 1 do
		panel.wheel_accum = panel.wheel_accum - 1
		if page > 0 then
			page = page - 1
			changed = true
		end
	end
	while panel.wheel_accum <= -1 do
		panel.wheel_accum = panel.wheel_accum + 1
		if page < pages - 1 then
			page = page + 1
			changed = true
		end
	end
	-- 到边界仍继续滚时清空残余，避免粘滞后突然连翻
	if page <= 0 and panel.wheel_accum > 0 then panel.wheel_accum = 0 end
	if page >= pages - 1 and panel.wheel_accum < 0 then panel.wheel_accum = 0 end
	if not changed then
		return
	end

	panel.craft.bag_page = page
	clear_bag_tokens_keep_busy(panel.craft, panel)
	panel.ui = nil -- 同帧强制 rebuild，避免「滚了但页未刷新」
	panel.nav_graph = nil
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.3, 1, false, 0, 2)
end

local function try_mouse_wheel_formation(panel, ui)
	if get_tutorial().is_locking() then return end
	if not panel or panel.craft then return end
	local tab = item.tabs[panel.tab]
	if not tab or tab.id ~= "formation" then return end
	local serial = panel.wheel_render_serial or 0
	if panel.wheel_read_serial == serial then return end
	local wheel = panel.wheel_pending
	if not wheel then return end
	panel.wheel_pending = nil
	local dy = tonumber(wheel.y) or 0
	local dx = tonumber(wheel.x) or 0
	local delta = dy
	if delta == 0 then delta = dx end
	if delta == 0 then return end
	panel.wheel_read_serial = serial
	local pages = math.max(1, panel._form_bench_pages or 1)
	local page = panel.form_bench_page or 0
	if delta > 0 and page > 0 then
		panel.form_bench_page = page - 1
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.3, 1, false, 0, 2)
	elseif delta < 0 and page < pages - 1 then
		panel.form_bench_page = page + 1
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.3, 1, false, 0, 2)
	end
end

local function handle_mouse_actions(panel, ui)
	-- 滚轮由 render_panel 每帧集中读取；悬停/点击仍需鼠标权限。
	if not Mouse_UI.mouse_allowed(panel.player) then return end

	-- 鼠标悬停同步焦点与导航组
	local hovered = Mouse_UI.get_hovered_id()
	if hovered and hovered ~= "modal_dim" and hovered ~= "panel_body" then
		panel.focus_id = hovered
		if panel.pad_carry then
			panel.nav_group = "carry"
		elseif type(hovered) == "string" and hovered:sub(1, 4) == "tab_" then
			panel.nav_group = "tabs"
		else
			panel.nav_group = "body"
			panel.body_focus_mem = hovered
		end
	end

	if panel.drag then
		if panel.drag.kind == "form_card" then
			if Mouse_UI.was_released(0) then
				finish_form_drag(panel, ui)
				lock_actions(panel)
			end
			return
		end
		if Mouse_UI.was_released(0) or Mouse_UI.is_released(panel.drag.token_id) then
			finish_drag(panel, ui.craft_geom and ui.craft_geom.right, ui.craft_geom)
			lock_actions(panel)
		end
		return
	end

	-- 共用主蓄力条：按材料映射 25%..100/200/300%，100%以上吸附到每 50% 档位。
	if panel.craft and ui.charge_sliders then
		for _, info in ipairs(ui.charge_sliders) do
			if info.rect and (Mouse_UI.is_active(info.id) or Mouse_UI.is_pressed(info.id)) then
				local x = math.max(0, math.min(1, (Mouse_UI.mouse.X - info.rect.x) / math.max(1, info.rect.w)))
				-- 鼠标位置与贴图帧使用同一坐标系；槽左侧 0%..25% 全部钳制为最低 25%。
				local t = (info.max_ratio or 1) * x
				panel.craft[info.key] = CraftProfile.snap_charge_ratio(t, info.max_ratio, info.snap_marks)
				panel.focus_id = info.id
				panel.nav_group = "body"
				panel.body_focus_mem = info.id
				return
			end
		end
	end

	if input_locked(panel) then return end

	if Mouse_UI.is_pressed("tut_yes") then
		get_tutorial().accept(panel.player)
		lock_actions(panel)
		return
	end
	if Mouse_UI.is_pressed("tut_no") then
		get_tutorial().decline(panel.player)
		lock_actions(panel)
		return
	end

	if panel.craft then
		for _, tok in ipairs(panel.craft.tokens) do
			if Mouse_UI.is_pressed(tok.id) then
				panel.pad_carry = nil
				clear_token_slot(panel.craft, tok)
				panel.drag = {
					token_id = tok.id,
					grab_offset = Mouse_UI.mouse - tok.pos,
				}
				tok.anim = nil
				tok.vel = Vector(0, 0)
				panel.focus_id = tok.id
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.45, 1, false, 0, 2)
				lock_actions(panel)
				return
			end
		end
		if Mouse_UI.is_pressed("btn_back") then
			if panel.view == "edit" then cancel_edit(panel) else leave_craft_view(panel) end
			lock_actions(panel)
			return
		end
		if Mouse_UI.is_pressed("btn_confirm") then
			confirm_craft(panel)
			lock_actions(panel)
			return
		end
		if Mouse_UI.is_pressed("btn_quality") then
			toggle_show_quality(panel)
			lock_actions(panel)
			return
		end
		if Mouse_UI.is_pressed("btn_mode") then
			toggle_all_items_mode(panel)
			lock_actions(panel)
			return
		end
		if Mouse_UI.is_pressed("btn_tag_all") then
			enable_all_audit_tags(panel)
			lock_actions(panel)
			return
		end
		if Mouse_UI.is_pressed("btn_tag_invert") then
			invert_audit_tags(panel)
			lock_actions(panel)
			return
		end
		if panel.ui and panel.ui.craft_geom and panel.ui.craft_geom.tag_col then
			for _, def in ipairs(panel.ui.craft_geom.tag_col.defs or {}) do
				if Mouse_UI.is_pressed("btn_tag_"..def.key) then
					toggle_audit_tag(panel, def.key)
					lock_actions(panel)
					return
				end
			end
		end
		if Mouse_UI.is_pressed("btn_prev") then
			panel.craft.bag_page = math.max(0, (panel.craft.bag_page or 0) - 1)
			clear_bag_tokens_keep_busy(panel.craft, panel)
			panel.nav_graph = nil
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
			lock_actions(panel)
			return
		end
		if Mouse_UI.is_pressed("btn_next") then
			local pages = panel.craft.bag_pages or 1
			panel.craft.bag_page = math.min(pages - 1, (panel.craft.bag_page or 0) + 1)
			clear_bag_tokens_keep_busy(panel.craft, panel)
			panel.nav_graph = nil
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
			lock_actions(panel)
			return
		end
	end

	if Mouse_UI.was_clicked(1) or Mouse_UI.is_pressed("modal_dim") then
		local tut = get_tutorial()
		local advanced = tut.note_close_attempt and tut.note_close_attempt(panel.player) == true
		if tut.blocks_close(panel.player) then
			if advanced then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.45, 1, false, 0, 2)
			else
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.45, 1.2, false, 0, 2)
			end
			lock_actions(panel)
			return
		end
		if panel.pad_carry then
			cancel_pad_carry(panel)
			lock_actions(panel)
			return
		end
		if panel.craft then
			if panel.view == "edit" then cancel_edit(panel) else leave_craft_view(panel) end
		else
			close_panel()
		end
		lock_actions(panel)
		return
	end

	for i = 1, #item.tabs do
		if Mouse_UI.is_pressed("tab_"..i) then
			set_tab(panel, i)
			lock_actions(panel)
			return
		end
	end

	for _, lay in ipairs(ui.layouts) do
		local e = lay.entry
		if e and e.kind == "form_page" and Mouse_UI.is_pressed(e.uid) then
			handle_formation_id(panel, e.uid)
			lock_actions(panel)
			return
		end
		if e and e.kind == "form_dock" and Mouse_UI.is_pressed(e.uid) then
			if panel.form_carry then
				handle_formation_id(panel, "form_queue")
				lock_actions(panel)
			end
			return
		end
		if e and e.kind == "form_card" and Mouse_UI.is_pressed(e.uid) and e.rec then
			panel.form_carry = nil
			panel.drag = {
				kind = "form_card",
				uid = e.rec.uid,
				from = e.zone,
				grab_offset = Mouse_UI.mouse - Vector(lay.rect.x, lay.rect.y),
				pos = Vector(lay.rect.x, lay.rect.y),
				w = lay.rect.w,
				h = lay.rect.h,
				rec = e.rec,
				active = e.active,
			}
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.45, 1, false, 0, 2)
			lock_actions(panel)
			return
		end
		if e and e.del_uid and Mouse_UI.is_pressed(e.del_uid) then
			try_confirm_delete_stock(panel, e.rec.uid)
			lock_actions(panel)
			return
		end
		if e and Mouse_UI.is_pressed(e.uid) then
			panel.delete_confirm_uid = nil
			if e.kind == "build_target" then
				open_craft_view(panel, e.target, nil)
			elseif e.kind == "stock" then
				open_craft_view(panel, e.rec.target, e.rec.uid)
			end
			lock_actions(panel)
			return
		end
	end
end

-- ---------- 渲染 ----------
-- 渲染闭包单独成函数，避免本文件顶层 local 超过 Lua 200 上限。
item.render_panel, item.update_panel_input = (function()
local function render_tabs(ui, panel)
	for i, tab in ipairs(item.tabs) do
		local rect = ui.tab_rects[i]
		local st = ui.states["tab_"..i]
		local tid = "tab_"..i
		local on = panel.tab == i
		local focused = focus_equals(panel, tid)
		local color = on and KColor(1, 0.92, 0.45, 1)
			or ((focused or (st and st.hovered)) and KColor(0.9, 1, 1, 1) or KColor(0.65, 0.75, 0.85, 1))
		color = tut_dim_id(tid, color)
		if focused or (get_tutorial().is_locking() and get_tutorial().allows(tid)) then
			draw_region_outline(rect, KColor(1, 0.85, 0.35, 1), true)
		end
		draw_text_in_rect(rect, tab_label(tab), color)
	end
end

local function form_card_sprite_color(active, broken)
	local c
	if broken then
		c = Color(1, 0.32, 0.32, 1)
		c:SetColorize(1.55, 0.12, 0.08, 1)
	else
		-- 待命只靠卡框/标题区分；图标保持全彩，避免看起来像不能用。
		c = Color(1, 1, 1, active and 1 or 0.92)
	end
	return c
end

local function draw_form_col_icon(col_id, pos, scale, col)
	local spr = load_col_sprite(col_id)
	if not spr then return end
	spr.Scale = Vector(scale, scale)
	spr.Color = col
	spr:Render(pos, Vector.Zero, Vector.Zero)
	spr.Color = Color(1, 1, 1, 1)
	spr.Scale = Vector(1, 1)
end

local function draw_form_craft_card(rect, rec, active, focused)
	if not rect or not rec then return end
	local broken = rec.broken == true
	local outline = focused and KColor(1, 0.95, 0.45, 1)
		or (active and KColor(0.95, 0.9, 0.55, 0.95) or KColor(0.4, 0.42, 0.5, 0.65))
	draw_region_outline(rect, outline, true)
	local name_h = 12
	local name_rect = Mouse_UI.make_rect(rect.x + 2, rect.y + 1, rect.w - 4, name_h)
	local tcol = active and KColor(1, 0.96, 0.72, 1) or KColor(0.78, 0.8, 0.86, 1)
	if broken then tcol = KColor(1, 0.4, 0.38, 1) end
	draw_text_in_rect(name_rect, rec_label(rec), tcol)
	local craft_col = form_card_sprite_color(active, broken)
	local item_col = Color(1, 1, 1, 1)
	local base_id, mods = rec_loadout_ids(rec)
	local area = Mouse_UI.make_rect(rect.x + 4, rect.y + name_h + 2, rect.w - 8, rect.h - name_h - 6)
	local cx = area.x + area.w * 0.5
	local cy = area.y + area.h * 0.5
	local body_scale = math.min(1.05, math.min(area.w, area.h) * 0.42 / 32)
	if body_scale < 0.7 then body_scale = 0.7 end
	if rec.target then
		draw_form_col_icon(rec.target, Vector(cx, cy), body_scale, craft_col)
	end
	local n = #mods
	local radius = math.min(area.w, area.h) * 0.34
	if radius < 16 then radius = 16 end
	local item_scale = math.min(0.95, (radius * 0.85) / 32)
	if item_scale < 0.62 then item_scale = 0.62 end
	if base_id then
		draw_form_col_icon(base_id, Vector(cx, cy + math.max(10, radius * 0.42)), item_scale * 0.5, cost_token_color())
	end
	if n < 1 then return end
	for i = 1, n do
		local ang = -90 + (i - 1) * (360 / n)
		local rad = ang * math.pi / 180
		local px = cx + math.cos(rad) * radius
		local py = cy + math.sin(rad) * radius
		draw_form_col_icon(mods[i], Vector(px, py), item_scale, item_col)
	end
end

local function render_list(ui, panel)
	if panel._bw_bar_rect then
		local sum = panel._bw_summary or {used_slots = 0, capacity_slots = 3}
		local used = tonumber(sum.used_slots) or 0
		local cap = math.max(0.001, tonumber(sum.capacity_slots) or 3)
		local ratio = math.max(0, math.min(1, used / cap))
		local bar = panel._bw_bar_rect
		draw_region_outline(bar, KColor(0.55, 0.7, 0.85, 0.7), true)
		local fill_w = math.max(0, (bar.w - 4) * ratio)
		if fill_w > 1 then
			local fill = Mouse_UI.make_rect(bar.x + 2, bar.y + 2, fill_w, bar.h - 4)
			draw_region_outline(fill, KColor(0.45, 0.85, 1, 0.95), true)
		end
		local txt = lang_is_zh()
			and string.format("控制带宽：%.0f / %.0f", used, cap)
			or string.format("Bandwidth: %.0f / %.0f", used, cap)
		draw_text_in_rect(bar, txt, KColor(0.95, 0.97, 1, 1))
	end
	if ui.form_queue_rect then
		draw_region_outline(ui.form_queue_rect, KColor(0.45, 0.55, 0.7, 0.45), true)
	end
	if ui.form_bench_rect then
		draw_region_outline(ui.form_bench_rect, KColor(0.4, 0.45, 0.55, 0.4), true)
	end
	if #ui.layouts == 0 then
		local msg = lang_is_zh() and "（空）" or "(Empty)"
		draw_text_in_rect(ui.content, msg, KColor(0.7, 0.7, 0.75, 1), {align = "left", pad_x = 8})
		return
	end
	local drag = panel.drag
	for _, lay in ipairs(ui.layouts) do
		local st = ui.states[lay.entry.uid]
		local focused = focus_equals(panel, lay.entry.uid)
		local color = (focused or (st and st.hovered)) and KColor(1, 0.95, 0.55, 1) or KColor(0.8, 0.85, 0.95, 1)
		local e = lay.entry
		local dragging_this = drag and drag.kind == "form_card" and e.rec and drag.uid == e.rec.uid and e.zone == drag.from
		if e.kind == "form_card" then
			if not dragging_this then
				local hot = focused or (st and st.hovered) or (panel.form_carry and panel.form_carry.uid == e.rec.uid)
				draw_form_craft_card(lay.rect, e.rec, e.active, hot)
				if get_tutorial().is_locking() and get_tutorial().allows(e.uid) then
					draw_region_outline(lay.rect, KColor(1, 0.9, 0.35, 1), true)
				end
			end
		elseif e.kind == "form_dock" then
			draw_region_outline(lay.rect, (focused or (st and st.hovered)) and KColor(0.85, 0.9, 1, 0.7) or KColor(0.35, 0.4, 0.5, 0.45), true)
		elseif e.kind == "form_page" then
			local txt = (e.uid == "form_prev") and "<" or ">"
			draw_region_outline(lay.rect, (focused or (st and st.hovered)) and KColor(1, 0.85, 0.35, 1) or KColor(0.5, 0.6, 0.7, 0.5), true)
			draw_text_in_rect(lay.rect, txt, color)
		else
			draw_region_outline(lay.rect, (focused or (st and st.hovered)) and KColor(1, 1, 1, 0.9) or KColor(0.5, 0.6, 0.7, 0.5), true)
		if e.info and e.info.gfx then
			if not e._spr then
				e._spr = load_col_sprite(e.target)
			end
			e._spr.Scale = Vector(0.85, 0.85)
			e._spr.Color = tint_color(1, 1, 1, 1)
			e._spr:Render(Vector(lay.rect.x + 18, lay.rect.y + lay.rect.h * 0.5), Vector(0, 0), Vector(0, 0))
			e._spr.Color = Color(1, 1, 1, 1)
			local text_rect = Mouse_UI.make_rect(lay.rect.x + 34, lay.rect.y, lay.rect.w - 38, lay.rect.h)
			draw_text_in_rect(text_rect, e.label, color, {align = "left", pad_x = 2})
		elseif e.kind == "stock" then
			local info = get_target_info(e.rec.target)
			local broken = e.broken or (e.rec and e.rec.broken)
			local icon_tint = broken and tint_color(1, 0.25, 0.25, 1) or tint_color(1, 1, 1, 1)
			if info then
				if not e._spr then e._spr = load_col_sprite(e.rec.target) end
				e._spr.Scale = Vector(0.85, 0.85)
				e._spr.Color = icon_tint
				e._spr:Render(Vector(lay.rect.x + 18, lay.rect.y + lay.rect.h * 0.5), Vector(0, 0), Vector(0, 0))
				e._spr.Color = Color(1, 1, 1, 1)
			end
			local del_w = (lay.del_rect and lay.del_rect.w) or 30
			local text_rect = Mouse_UI.make_rect(lay.rect.x + 34, lay.rect.y, lay.rect.w - 38 - del_w - 4, lay.rect.h)
			local tcol = broken and KColor(1, 0.35, 0.35, 1)
				or ((focused or (st and st.hovered)) and KColor(1, 0.95, 0.55, 1) or KColor(0.8, 0.85, 0.95, 1))
			tcol = tut_dim_id(e.uid, tcol)
			if get_tutorial().is_locking() and get_tutorial().allows(e.uid) then
				draw_region_outline(lay.rect, KColor(1, 0.9, 0.35, 1), true)
			end
			if broken then
				draw_region_outline(lay.rect, KColor(1, 0.3, 0.3, 0.85), true)
			end
			draw_text_in_rect(text_rect, e.label, tcol, {align = "left", pad_x = 2})
			if lay.del_rect and e.del_uid then
				local dst = ui.states[e.del_uid]
				local del_focused = focus_equals(panel, e.del_uid)
				local armed = panel.delete_confirm_uid == e.rec.uid
				local dcol = armed and KColor(1, 0.35, 0.3, 1)
					or ((del_focused or (dst and dst.hovered)) and KColor(1, 0.7, 0.55, 1) or KColor(0.95, 0.55, 0.5, 0.95))
				dcol = tut_dim_id(e.del_uid, dcol)
				if get_tutorial().is_locking() and get_tutorial().allows(e.del_uid) then
					draw_region_outline(lay.del_rect, KColor(1, 0.45, 0.35, 1), true)
				else
					draw_region_outline(lay.del_rect, (del_focused or armed) and KColor(1, 0.45, 0.35, 1) or KColor(0.7, 0.35, 0.35, 0.7), true)
				end
				local dtxt = armed
					and (lang_is_zh() and "确认?" or "OK?")
					or (lang_is_zh() and "删" or "Del")
				draw_text_in_rect(lay.del_rect, dtxt, dcol)
			end
		else
			draw_text_in_rect(lay.rect, e.label, color, {align = "left", pad_x = 8})
		end
		end
	end
	if drag and drag.kind == "form_card" and drag.rec and drag.pos then
		local r = Mouse_UI.make_rect(drag.pos.X, drag.pos.Y, drag.w or 72, drag.h or 80)
		draw_form_craft_card(r, drag.rec, true, true)
	end
end

local function render_craft(ui, panel)
	local g = ui.craft_geom
	local craft = panel.craft
	local player = panel.player
	local zh = lang_is_zh()

	-- 背包左边：道具品质显示。默认关，底座空时自动开。
	if g.quality_rect then
		local qst = ui.states.btn_quality
		local q_focused = focus_equals(panel, "btn_quality")
		local q_on = craft.show_quality == true
		local q_txt = zh and (q_on and "品质开" or "品质关") or (q_on and "Q.On" or "Q.Off")
		local qc
		if q_focused or (qst and qst.hovered) then
			qc = KColor(1, 0.95, 0.5, 1)
		elseif q_on then
			qc = KColor(0.95, 0.85, 0.45, 1)
		else
			qc = KColor(0.55, 0.58, 0.62, 1)
		end
		if q_focused then draw_region_outline(g.quality_rect, KColor(1, 0.85, 0.35, 1), true) end
		draw_text_in_rect(g.quality_rect, q_txt, qc)
	end
	-- 背包 / 全道具切换；全道具下用右侧标签列筛选（有效/无效/未实装 + 类别）
	if not craft.tutorial_bag then
		local mst = ui.states.btn_mode
		local mode_focused = focus_equals(panel, "btn_mode")
		local mode_txt = craft.all_items
			and (zh and "全道具" or "ALL")
			or (zh and "背包" or "BAG")
		local mc = (mode_focused or (mst and mst.hovered)) and KColor(1, 0.95, 0.5, 1)
			or (craft.all_items and KColor(1, 0.75, 0.45, 1) or KColor(0.7, 0.9, 0.8, 1))
		if mode_focused then draw_region_outline(g.mode_rect, KColor(1, 0.85, 0.35, 1), true) end
		draw_text_in_rect(g.mode_rect, mode_txt, mc)
	else
		draw_text_in_rect(g.mode_rect, zh and "教学背包" or "LESSON", KColor(0.7, 0.82, 0.9, 1))
	end
	if g.tag_col then
		local enabled = craft.tag_enabled or CraftProfile.default_audit_tag_enabled()
		local all_st = ui.states.btn_tag_all
		local all_focused = focus_equals(panel, "btn_tag_all")
		local all_c = (all_focused or (all_st and all_st.hovered)) and KColor(1, 0.95, 0.5, 1) or KColor(0.85, 0.9, 1, 1)
		if all_focused then draw_region_outline(g.tag_col.all_rect, KColor(1, 0.85, 0.35, 1), true) end
		draw_text_in_rect(g.tag_col.all_rect, zh and "全开" or "All", all_c)
		local inv_st = ui.states.btn_tag_invert
		local inv_focused = focus_equals(panel, "btn_tag_invert")
		local inv_c = (inv_focused or (inv_st and inv_st.hovered)) and KColor(1, 0.95, 0.5, 1) or KColor(0.85, 0.9, 1, 1)
		if inv_focused then draw_region_outline(g.tag_col.invert_rect, KColor(1, 0.85, 0.35, 1), true) end
		draw_text_in_rect(g.tag_col.invert_rect, zh and "反转" or "Inv", inv_c)
		for _, def in ipairs(g.tag_col.defs or {}) do
			local rect = g.tag_col.tag_rects and g.tag_col.tag_rects[def.key]
			if rect then
				local bid = "btn_tag_"..def.key
				local st = ui.states[bid]
				local focused = focus_equals(panel, bid)
				local on = enabled[def.key] == true
				local label = zh and def.zh or def.en
				local tc
				if focused or (st and st.hovered) then
					tc = KColor(1, 0.95, 0.5, 1)
				elseif not on then
					tc = KColor(0.45, 0.45, 0.5, 0.85)
				elseif def.key == "valid" then
					tc = KColor(0.55, 0.95, 0.65, 1)
				elseif def.key == "invalid" then
					tc = KColor(0.75, 0.75, 0.8, 1)
				elseif def.key == "unimplemented" then
					tc = KColor(1, 0.82, 0.3, 1)
				else
					tc = KColor(0.7, 0.95, 0.85, 1)
				end
				if focused then draw_region_outline(rect, KColor(1, 0.85, 0.35, 1), true) end
				draw_text_in_rect(rect, label, tc, {align = "left", pad_x = 2})
			end
		end
	end
	if panel.pad_carry then
		local tip = Mouse_UI.make_rect(g.left.x, g.left.y + 12, g.left.w, 12)
		draw_text_in_rect(tip, zh and "搬运中:选槽位/背包放置" or "Carrying: slot/bag", KColor(1, 0.8, 0.4, 1), {align = "left", pad_x = 4})
	end

	-- 目标
	if not craft._target_spr then
		craft._target_spr = load_col_sprite(craft.target)
	end
	craft._target_spr.Scale = Vector(0.95, 0.95)
	craft._target_spr.Color = tint_color(1, 1, 1, 1)
	craft._target_spr:Render(g.target_pos, Vector(0, 0), Vector(0, 0))
	craft._target_spr.Color = Color(1, 1, 1, 1)
	local title_rect = Mouse_UI.make_rect(g.left.x, g.left.y, g.left.w, 14)
	local title_txt = craft_preview_name(craft, panel.player)
	if not title_txt or title_txt == "" then title_txt = target_label(craft.info, panel.player) end
	local title_broken = false
	if craft.edit_uid and panel.player then
		local erec = item.find_craft(panel.player, craft.edit_uid)
		title_broken = erec and erec.broken == true
		if title_broken then title_txt = "!" .. title_txt end
	end
	draw_text_in_rect(title_rect, title_txt, title_broken and KColor(1, 0.35, 0.35, 1) or KColor(1, 0.95, 0.7, 1))

	-- 成本小槽（可多行；空槽画问号；不显示成本文字）
	if g.cost_rect and (g.cost_display_n or 0) > 0 then
		local need = craft.required_cost or 0
		local have = #(craft.cost_ids or {})
		local real_cost_n = 0
		for _, tid in ipairs(craft.cost_ids or {}) do
			local tok = craft.token_map[tid]
			if tok and tok.source ~= "audit" then
				real_cost_n = real_cost_n + 1
			end
		end
		local pure_audit = CraftProfile.craft_is_pure_audit(
			read_ingredients(craft), read_cost_items(craft), false
		)
		local ok = pure_audit or real_cost_n >= need
		local ccol = ok and KColor(0.55, 0.9, 0.65, 0.95) or KColor(1, 0.55, 0.45, 0.95)
		local focus_cost = focus_equals(panel, "cost_slot")
		local display_n = g.cost_display_n or cost_display_count(craft)
		local cell = g.cost_size or get_cost_slot_size()
		local qmark = ensure_cost_qmark_sprite()
		local qscale = get_cost_token_scale()
		local qoff = get_cost_qmark_offset()
		for i = 1, display_n do
			local p = cost_stack_pos(craft, g, i)
			local cell_rect = Mouse_UI.make_rect_centered(p, cell, cell)
			local filled = i <= have
			local outline = focus_cost and KColor(1, 0.9, 0.35, 1)
				or (filled and KColor(0.55, 0.9, 0.65, 0.85) or ccol)
			-- 已放入道具时不画槽框，避免边框压在图标上；聚焦成本行时仍高亮
			if not filled or focus_cost then
				draw_region_outline(cell_rect, outline, true)
			end
			if not filled then
				qmark.Scale = Vector(qscale, qscale)
				qmark.Color = Color(1, 1, 1, 0.9)
				qmark:SetFrame("Idle", 0)
				qmark:Render(p + qoff, Vector(0, 0), Vector(0, 0))
				qmark.Color = Color(1, 1, 1, 1)
			end
		end
	end

	-- 槽位
	local lowest_y = g.target_pos.Y + 16
	for i, slot in ipairs(craft.slots) do
		local st = ui.states["cslot_"..i]
		local sid = "cslot_"..i
		local focused = focus_equals(panel, sid)
		local near = focused
		if panel.drag then
			local tok = craft.token_map[panel.drag.token_id]
			if tok and slot._rect and (tok.pos - Mouse_UI.rect_center(slot._rect)):Length() <= item.snap_dist then
				near = true
			end
		end
		if panel.pad_carry and focused then near = true end
		local filled = slot.token ~= nil
		local outline = near and KColor(1, 0.95, 0.4, 1)
			or ((st and st.hovered) and KColor(1, 1, 1, 0.9) or KColor(0.55, 0.7, 0.95, 0.85))
		-- 空槽常显框；满槽仅在靠近/聚焦/悬停时高亮，否则不画边框
		if not filled or near or focused or (st and st.hovered) then
			draw_region_outline(slot._rect, outline, true)
		end
		if not filled and not (panel.pad_carry and focused) then
			draw_text_in_rect(slot._rect, "+", KColor(0.5, 0.6, 0.75, 0.7))
		end
		if slot._rect then
			lowest_y = math.max(lowest_y, slot._rect.y + slot._rect.h)
		end
	end
	if g.cost_rect then
		lowest_y = math.max(lowest_y, g.cost_rect.y + g.cost_rect.h)
	end

	-- 实时档案审计：紧贴上方最低槽位/成本块下方（含所属玩家动态项）
	-- 红豆汤等持续状态预览只读；谷底石头在预览时立即比较并记录峰值。
	local live = CraftProfile.build_profile(read_ingredients(craft), {
		player = player,
		rec = craft.edit_uid and item.find_craft(player, craft.edit_uid) or craft,
		commit_state = false,
		commit_rock_bottom = true,
		base_quality = craft.remembered_quality or craft.base_quality,
	})
	live.craft_uid = craft.edit_uid
	CraftProfile.apply_craft_settings(live, {
		main_charge_ratio = craft.main_charge_ratio,
	})
	local lines = CraftProfile.audit_lines(live, zh, player)
	local charge_list = ui.charge_sliders or list_charge_sliders(craft)
	local n_charge = #charge_list
	local slider_top = g.confirm_rect.y - 12
	if n_charge > 0 and g.charge_slider_rects and g.charge_slider_rects[n_charge] then
		slider_top = g.charge_slider_rects[n_charge].y - 2
	end
	local audit_top = lowest_y + get_audit_text_y()
	local visible_count = math.max(0, math.floor((slider_top - audit_top) / 10) + 1)
	local audit_max = math.max(0, #lines - visible_count)
	local audit_scroll = math.max(0, math.min(audit_max, tonumber(craft.audit_scroll) or 0))
	craft.audit_scroll = audit_scroll
	panel.audit_scroll_max = audit_max
	panel.audit_scroll_rect = Mouse_UI.make_rect(
		g.left.x + 2,
		audit_top - 2,
		g.left.w - 4,
		math.max(0, slider_top - audit_top + 10)
	)
	local ay = audit_top
	for i = audit_scroll + 1, math.min(#lines, audit_scroll + visible_count) do
		gui.draw_ch(Vector(g.left.x + 4, ay), lines[i], 1, 1, tint_kcolor(KColor(0.78, 0.88, 0.95, 1)), true)
		ay = ay + 10
	end
	-- 只有确实存在隐藏行时提示可滚动，避免常驻装饰干扰数值。
	if audit_max > 0 then
		local hint_x = g.left.x + g.left.w - 8
		if audit_scroll > 0 then
			gui.draw_ch(Vector(hint_x, audit_top), "▲", 1, 1, tint_kcolor(KColor(0.7, 0.85, 1, 0.85)), true)
		end
		if audit_scroll < audit_max then
			gui.draw_ch(Vector(hint_x, slider_top), "▼", 1, 1, tint_kcolor(KColor(0.7, 0.85, 1, 0.85)), true)
		end
	end

	-- 主攻击蓄力条：素材已将 front/ball 插值预制为 Idle 0..99 帧，无需裁切或缩放。
	for i, info in ipairs(charge_list) do
		local rect = info.rect or (g.charge_slider_rects and g.charge_slider_rects[i])
		if rect then
			local r = CraftProfile.clamp_charge_ratio(craft[info.key], info.max_ratio)
			local st = ui.states[info.id]
			local focused = focus_equals(panel, info.id)
			local active = st and st.active
			local fill_col = (info.colors and info.colors[info.color_key]) or KColor(0.8, 0.65, 0.95, 0.95)
			local progress = math.max(0, math.min(1, r / math.max(1, info.max_ratio or 1)))
			local frame = math.max(0, math.min(99, math.floor(progress * 99 + 0.5)))
			local slider = ensure_charge_slider_sprite()
			slider:SetFrame("Idle", frame)
			local pos = Vector(rect.x + rect.w * 0.5, rect.y + rect.h * 0.5)
			-- back/front 均为白色素材；front 单独染色，main 保留黑边，ball 保留原色。
			slider.Color = slider_layer_color(KColor(1, 1, 1, 0.72))
			slider:RenderLayer(1, pos)
			slider.Color = slider_layer_color(fill_col)
			slider:RenderLayer(3, pos)
			slider.Color = slider_layer_color(KColor(1, 1, 1, 1))
			slider:RenderLayer(0, pos)
			slider:RenderLayer(2, pos)
			if focused or active or (st and st.hovered) then
				-- 聚焦反馈只加轻微暖色，不改帧和图层几何。
				slider.Color = slider_layer_color(KColor(1, 0.9, 0.55, 0.28))
				slider:RenderLayer(0, pos)
			end
			local pct = math.floor(r * 100 + 0.5)
			local label = (zh and info.zh or info.en) .. " " .. pct .. "%"
			draw_text_in_rect(
				Mouse_UI.make_rect(rect.x, rect.y - 1, rect.w, rect.h),
				label,
				KColor(1, 0.92, 0.75, 1),
				{align = "center"}
			)
		end
	end

	-- 确认 / 返回 / 翻页
	local cst = ui.states.btn_confirm
	local bst = ui.states.btn_back
	local confirm_txt = panel.view == "edit"
		and (zh and "更改" or "Apply")
		or (zh and (craft.all_items and "审计制造" or "确认制造") or (craft.all_items and "Audit Craft" or "Craft"))
	local back_txt = "< "..(zh and "返回" or "Back")
	local c_focus = focus_equals(panel, "btn_confirm")
	local b_focus = focus_equals(panel, "btn_back")
	local cc = (c_focus or (cst and cst.hovered)) and KColor(1, 0.95, 0.5, 1) or KColor(0.85, 0.9, 1, 1)
	local bc = (b_focus or (bst and bst.hovered)) and KColor(1, 0.95, 0.5, 1) or KColor(0.75, 0.8, 0.9, 1)
	cc = tut_dim_id("btn_confirm", cc)
	bc = tut_dim_id("btn_back", bc)
	if get_tutorial().is_locking() and get_tutorial().allows("btn_confirm") then
		draw_region_outline(g.confirm_rect, KColor(1, 0.9, 0.4, 1), true)
	else
		draw_region_outline(g.confirm_rect, (c_focus or (cst and cst.hovered)) and KColor(1, 0.9, 0.4, 1) or KColor(0.5, 0.65, 0.9, 0.7), true)
	end
	if b_focus then draw_region_outline(g.back_rect, KColor(1, 0.85, 0.35, 1), true) end
	draw_text_in_rect(g.confirm_rect, confirm_txt, cc)
	draw_text_in_rect(g.back_rect, back_txt, bc)

	local page = (craft.bag_page or 0) + 1
	local pages = craft.bag_pages or 1
	local pst = ui.states.btn_prev
	local nst = ui.states.btn_next
	local p_focus = focus_equals(panel, "btn_prev")
	local n_focus = focus_equals(panel, "btn_next")
	if p_focus then draw_region_outline(g.prev_rect, KColor(1, 0.85, 0.35, 1), true) end
	if n_focus then draw_region_outline(g.next_rect, KColor(1, 0.85, 0.35, 1), true) end
	draw_text_in_rect(g.prev_rect, "<", (p_focus or (pst and pst.hovered)) and KColor(1, 1, 0.6, 1) or KColor(0.75, 0.8, 0.9, 1))
	draw_text_in_rect(g.next_rect, ">", (n_focus or (nst and nst.hovered)) and KColor(1, 1, 0.6, 1) or KColor(0.75, 0.8, 0.9, 1))
	local page_rect = Mouse_UI.make_rect(g.prev_rect.x + g.prev_rect.w, g.prev_rect.y, g.next_rect.x - (g.prev_rect.x + g.prev_rect.w), g.prev_rect.h)
	draw_text_in_rect(page_rect, tostring(page).."/"..tostring(pages), KColor(0.65, 0.75, 0.85, 1))

	-- tokens（已实装偏绿，未实装偏灰，失去标红）；焦点/搬运高亮
	for _, tok in ipairs(craft.tokens) do
		local st = ui.states[tok.id]
		local spr = tok.sprite or load_col_sprite(tok.collectible)
		tok.sprite = spr
		local carrying = panel.pad_carry and panel.pad_carry.token_id == tok.id
		local focused = focus_equals(panel, tok.id) or (panel.pad_carry and focus_equals(panel, "dropbag_"..tok.id))
		local scale = 1
		if (panel.drag and panel.drag.token_id == tok.id) or carrying then scale = 1.14
		elseif focused or (st and st.hovered) then scale = 1.08 end
		scale = scale * (tok.visual_scale or 1)
		spr.Scale = Vector(scale, scale)
		local impl = tok.impl
		if impl == nil then impl = CraftProfile.has_impl(tok.collectible) tok.impl = impl end
		local missing_stat = tok.missing_stat
		if missing_stat == nil then
			missing_stat = CraftProfile.missing_stat_delta(tok.collectible)
			tok.missing_stat = missing_stat
		end
		local form_syn = tok.form_synergy
		local lit = tok.lit
		if lit == nil then lit = (impl or form_syn) and true or false tok.lit = lit end
		local gated_off = impl and tok.gate_kind and lit == false
		local lost = tok.lost == true or tok.lost_ghost == true
		if tok.cost then
			-- 成本仅用于支付，绝不生效；其视觉优先级高于 lost/prototype/impl 等状态。
			spr.Color = cost_token_color()
		elseif lost then
			-- 失去（背包/材料槽）：优先标红
			spr.Color = tint_color(1.0, 0.28, 0.28, 1)
		elseif tok.is_prototype or tok.source == "prototype" then
			spr.Color = tint_color(0.7, 0.9, 1.0, 1)
		elseif missing_stat then
			spr.Color = tint_color(1.0, 0.82, 0.35, 1)
		elseif gated_off then
			-- 已实装但当前配方不满足武器条件（如无博士/史诗的炸弹道具）
			spr.Color = tint_color(0.42, 0.4, 0.38, 0.72)
		elseif form_syn and not impl then
			-- 套装材料亮起（书套/猫套等），无独立接线也偏绿
			spr.Color = tint_color(0.8, 0.95, 1.0, 1)
		elseif impl or lit then
			spr.Color = tint_color(0.85, 1.0, 0.85, 1)
		else
			spr.Color = tint_color(0.45, 0.42, 0.42, 0.85)
		end
		if get_tutorial().is_locking() then
			local seated = tok.slot or tok.cost
			if not get_tutorial().allows_token(tok) and not seated then
				spr.Color = tint_color(0.32, 0.32, 0.36, 0.38)
			elseif get_tutorial().allows_token(tok) and not seated then
				draw_region_outline(Mouse_UI.make_rect_centered(tok.pos, item.slot_size, item.slot_size), KColor(1, 0.9, 0.35, 1), true)
			end
		end
		-- 与材料槽共用完全相同的边界尺寸；避免 32px 点阵步进越过边缘，看起来比 34px 槽框更大。
		local token_outline_rect = Mouse_UI.make_rect_centered(tok.pos, item.slot_size, item.slot_size)
		-- 成本 token 已由上方的小槽负责聚焦反馈；不能再套用正常 token 的大框。
		if not tok.cost and (focused or carrying) then
			draw_region_outline(token_outline_rect, KColor(1, 0.9, 0.35, 1), true)
		end
		if not tok.cost and lost then
			draw_region_outline(token_outline_rect, KColor(1, 0.3, 0.3, 0.9), true)
		elseif not tok.cost and show_source_marks() and (tok.is_prototype or tok.source == "prototype") then
			draw_region_outline(token_outline_rect, KColor(0.35, 0.85, 1, 0.95), true)
		elseif not tok.cost and show_source_marks() and tok.source == "audit" then
			draw_region_outline(token_outline_rect, KColor(1, 0.75, 0.4, 0.85), true)
		end
		spr:Render(tok.pos, Vector(0, 0), Vector(0, 0))
		clear_sprite_color(spr)
		if craft.show_quality then
			render_token_quality_icon(tok)
		end
		local show_src = show_source_marks()
		local mark = lost and "!"
			or (show_src and (tok.is_prototype or tok.source == "prototype") and (zh and "原" or "P")
			or (show_src and tok.source == "audit" and (zh and "审" or "A")
			or (missing_stat and "△"
			or (gated_off and (zh and "◎" or "o")
			or (form_syn and not impl and (zh and "套" or "F")
			or ((impl or lit) and (zh and "●" or "*") or (zh and "○" or ".")))))))
		local mk = lost and KColor(1, 0.35, 0.35, 1)
			or ((show_src and (tok.is_prototype or tok.source == "prototype")) and KColor(0.35, 0.85, 1, 1)
			or ((show_src and tok.source == "audit") and KColor(1, 0.75, 0.4, 1)
			or (missing_stat and KColor(1, 0.82, 0.2, 1)
			or (gated_off and KColor(0.7, 0.65, 0.55, 1)
			or (form_syn and not impl and KColor(0.45, 0.85, 1, 1)
			or ((impl or lit) and KColor(0.35, 0.95, 0.45, 1) or KColor(0.75, 0.35, 0.35, 0.95)))))))
		-- 成本槽只传达“灰色=不生效”，不叠加背包/材料状态标记。教学背包也不打这些记号。
		if not tok.cost and mark and mark ~= "" and not get_tutorial().bag_collectibles() then
			gui.draw_ch(tok.pos + Vector(8, -14), mark, 1, 1, tint_kcolor(mk), true)
		end
	end
end

local function render_tutorial_overlay(ui, panel)
	local tut = ui and ui.tut
	if not tut then return end
	local hint = tut.hint
	if tut.box then
		draw_region_outline(tut.box, KColor(1, 0.9, 0.45, 1), true)
		if hint and hint ~= "" then
			local y = tut.box.y + 8
			for line in string.gmatch(hint.."\n", "([^\n]*)\n") do
				if line ~= "" then
					draw_text_in_rect(Mouse_UI.make_rect(tut.box.x + 8, y, tut.box.w - 16, 12), line, KColor(1, 0.95, 0.75, 1))
					y = y + 13
				end
			end
		end
	elseif hint and hint ~= "" then
		-- 贴屏幕底部，避开页签、暂停选项和顶部拾取字幕
		get_tutorial().draw_bottom_hint(hint, KColor(1, 0.95, 0.75, 1))
	end
	for _, b in ipairs(tut.buttons or {}) do
		local st = ui.states[b.id]
		local hot = (st and st.hovered) or focus_equals(panel, b.id)
		draw_region_outline(b.rect, hot and KColor(1, 0.92, 0.4, 1) or KColor(0.7, 0.8, 0.95, 0.85), true)
		draw_text_in_rect(b.rect, b.label, hot and KColor(1, 0.95, 0.55, 1) or KColor(0.9, 0.93, 1, 1))
	end
end

local function render_panel()
	scrub_stale_panel()
	local panel = item.panel
	if not panel then return end
	if not panel_is_alive() then
		close_panel()
		return
	end

	-- 切屏等进暂停：不强制关菜单；标记 was_paused，回来后松手再响应（对齐逢魔）
	if pause_menu_open() then
		panel.was_paused = true
		return
	end

	item._draw_alpha = item.get_panel_alpha()
	pcall(function() get_tutorial().observe_panel(panel) end)
	if not item.panel then item._draw_alpha = nil return end
	local can_read_wheel = not panel.was_paused and not Game():IsPaused()
	local ui = build_and_register_ui(panel)
	-- 滚轮只改背包页 / 编队备选条；不需要等待升起动画或键盘 input_armed。
	if can_read_wheel then
		if panel.craft and ui.craft_geom then
			try_mouse_wheel_page(panel, ui)
		else
			try_mouse_wheel_formation(panel, ui)
		end
		if not item.panel then item._draw_alpha = nil return end
		ui = panel.ui or build_and_register_ui(panel)
	end
	local can_interact = panel.input_armed
		and item.panel_rise_finished()
		and Game():GetFrameCount() > panel.opened_frame
		and not Game():IsPaused()
		and not panel.was_paused
	if can_interact then
		handle_mouse_actions(panel, ui)
		if not item.panel then item._draw_alpha = nil return end
		ui = panel.ui or build_and_register_ui(panel)
		handle_pad_actions(panel, ui)
		if not item.panel then item._draw_alpha = nil return end
		ui = panel.ui or ui
	end

	local panel_rect = ui.panel_rect
	local bg = ensure_bg_sprite()
	local a = panel_alpha()
	bg.Color = Color(1, 1, 1, a)
	local bg_off = get_bg_offset()
	bg:Render(panel_rect.center + bg_off, Vector(0, 0), Vector(0, 0))
	bg.Color = Color(1, 1, 1, 1)
	render_tabs(ui, panel)

	local tab = item.tabs[panel.tab]
	local in_craft = (tab.id == "build" or tab.id == "inventory") and panel.craft and ui.craft_geom
	if in_craft then
		render_craft(ui, panel)
	else
		render_list(ui, panel)
	end
	render_tutorial_overlay(ui, panel)

	if item.debug_draw_regions then
		gui.draw_ch(Vector(8, 8), "hover="..tostring(ui.hovered or "-"), 1, 1, tint_kcolor(KColor(1, 1, 1, 0.7)), true)
	end
	item._draw_alpha = nil
end

local function update_panel_input(player)
	scrub_stale_panel()
	local panel = item.panel
	if not same_panel_player(player) then return end
	if Game():GetFrameCount() <= panel.opened_frame then return end
	local ctrlid = player.ControllerIndex

	-- 暂停被关掉后：按着的 ESC/确认/方向等一律不计入，松手前保持 was_paused 防连触
	if panel.was_paused then
		disarm_until_release(panel)
		if pause_menu_open() or panel_keys_held(ctrlid, player) then return end
		panel.was_paused = false
		panel.input_armed = true
		panel.wait_drop_release = false
		return
	end
	if pause_menu_open() or Game():IsPaused() then return end

	if not panel.input_armed then
		if not panel_keys_held(ctrlid, player) then panel.input_armed = true end
		return
	end

	if panel.wait_drop_release then
		if not exit_key_held(ctrlid, player) then
			panel.wait_drop_release = false
		end
	elseif exit_key_triggered(ctrlid, player) then
		try_panel_exit(panel)
	end
end

return render_panel, update_panel_input
end)()

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, _, rng, player, use_flags, active_slot)
	if use_flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return {Discharge = false, ShowAnim = false}
	end
	if use_flags & UseFlag.USE_OWNED ~= UseFlag.USE_OWNED then
		return {Discharge = false, ShowAnim = false}
	end
	-- 书包副槽不可打开；仅主主动 / 口袋副手
	if active_slot == ActiveSlot.SLOT_SECONDARY then
		return {Discharge = false, ShowAnim = false}
	end
	-- 先清失效面板（重启后残留），再判断是否本人已打开
	scrub_stale_panel()
	if same_panel_player(player) then
		-- 已开启：再次使用 = 关闭
		close_panel()
		return {Discharge = false, ShowAnim = false}
	end
	if item.panel then
		-- 其他人占用或异常占用：关掉再开
		close_panel()
	end
	if Game():GetFrameCount() <= (item.suppress_open_until or -1) then
		-- 刚关掉的抑制帧内允许立刻重开（toggle 除外已在上面处理）
		item.suppress_open_until = -1
	end
	if player:GetPlayerType() == enums.Players.Spwq then
		local Spwq = require("Qing_Remaster_scripts.player.player_Spwq")
		if Spwq and Spwq.begin_blueprint_hold then
			Spwq.begin_blueprint_hold(player)
		end
		return {Discharge = false, ShowAnim = false}
	end
	open_panel(player)
	return {Discharge = false, ShowAnim = false}
end,
})

-- 面板开启时挡移动/射击等；MENUBACK/ESC 放行以便唤起暂停
-- PILLCARD 始终拦截（防误用卡牌）；副手时退出键另用缓存探测真值
table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil, priority = -1000,
Function = function(_, ent, hook, button)
	if not blueprint_input_active() then return end
	if ent == nil then return end
	local player = ent:ToPlayer()
	if not player or not same_panel_player(player) then return end
	if button == ButtonAction.ACTION_PILLCARD and pillcard.probe then
		return -- 放行探测调用，拿到硬件真值
	end
	if not blocked_actions[button] then return end
	if hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED then
		return false
	elseif hook == InputHook.GET_ACTION_VALUE then
		return 0
	end
end,
})

-- 审计制造的特效材料 → 玩家 imitate 模拟道具
-- 签名必须与 Evaluate_Imitate_Items 一致：(_, player, colid, value)；少参会把 value 当成 nil 整段跳过
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM,
	params = nil,
	Function = function(_, player, colid, value)
		if not player or not value then return end
		local counts = item.collect_audit_simulate_counts(player)
		for id, n in pairs(counts) do
			Imitate_item_holder.add(value, id, n, {display = true, costume = false})
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	-- 换房回调本身不能触碰旧 Player；延迟到新房间玩家真正开始 Update 后，
	-- 再清除可能随玩家数据保留下来的选择锁。覆盖数帧以兼容联机玩家依次更新。
	if item.room_selection_cleanup_until then
		if Game():GetFrameCount() <= item.room_selection_cleanup_until then
			selection_holder.remove_select(player, selection_key)
		else
			item.room_selection_cleanup_until = nil
		end
	end
	scrub_stale_panel()

	-- 换房 epoch：每个玩家每个房间最多刷新一次完整性。禁止用 CurrentRoomIndex（换层/维度会复用）。
	item._integrity_epoch_seen = item._integrity_epoch_seen or {}
	local epoch = item._room_epoch or 0
	local ptr = GetPtrHash(player)
	if item._integrity_epoch_seen[ptr] ~= epoch then
		item._integrity_epoch_seen[ptr] = epoch
		item.refresh_craft_integrity(player)
	end

	-- 换房/下层：panel 已丢但角色仍举着 → 用新房间安全的 player 重开
	if item.pending_reopen_until then
		if Game():GetFrameCount() > item.pending_reopen_until then
			item.pending_reopen_until = nil
			if not item.panel and player:HasCollectible(item.entity) and player:IsHoldingItem() then
				drop_held_blueprint(player)
			end
		elseif not item.panel
			and player:HasCollectible(item.entity)
			and player:IsHoldingItem()
			and not pause_menu_open()
		then
			item.suppress_open_until = -1
			item.pending_reopen_until = nil
			open_panel(player)
			return
		end
	end

	if not same_panel_player(player) then return end
	-- 暂停菜单打开时不要继续 time_stop：从暂停重开会把 Attribute 强表 claim 带进新局，
	-- userdata 复用后准星等新实体会被 Position/FREEZE 钉死（玩家在 unstopable 里仍能转头）。
	if pause_menu_open() then
		if item.panel then item.panel.was_paused = true end
		return
	end
	-- 持续刷新冻结，覆盖新生成实体
	auxi.time_stop(item.own_key)
	if not player:IsHoldingItem() then
		player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
	end
	item.update_panel_input(player)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_)
	item.panel = nil
	item.pending_reopen_until = nil
	item.suppress_open_until = -1
	item._room_epoch = 0
	item._integrity_epoch_seen = {}
	pcall(function() auxi.time_free(item.own_key) end)
	pcall(function()
		local AH = require("Qing_Remaster_scripts.others.Attribute_holder")
		if AH.drop_all then AH.drop_all() end
	end)
	restore_eid_after_blueprint()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_)
	-- 续关/重开：module 级 panel 必须作废
	if item.panel then
		item.panel = nil
	end
	item.pending_reopen_until = nil
	item.suppress_open_until = -1
	clear_blueprint_selection(nil)
	pcall(function() auxi.time_free(item.own_key) end)
	pcall(function()
		local AH = require("Qing_Remaster_scripts.others.Attribute_holder")
		if AH.drop_all then AH.drop_all() end
	end)
	restore_eid_after_blueprint()
	item._room_epoch = 0
	item._integrity_epoch_seen = {}
	for i = 0, Game():GetNumPlayers() - 1 do
		drop_held_blueprint(Game():GetPlayer(i))
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	-- POST_NEW_ROOM 触发时 panel.player 可能仍对 Exists() 返回 true，但已是旧房间的悬空
	-- userdata；此时连 pcall 内 GetData() 都会在原生层硬崩。这里禁止走 close_panel、
	-- selection_holder、drop_held_blueprint 或任何玩家方法，只丢弃纯 Lua 面板状态。
	local was_open = item.panel ~= nil
	item.panel = nil
	item._room_epoch = (item._room_epoch or 0) + 1
	item.suppress_open_until = Game():GetFrameCount() + 2
	item.room_selection_cleanup_until = Game():GetFrameCount() + 2
	-- 仍举着时由 POST_PLAYER_UPDATE 用新 player 自动 open_panel
	item.pending_reopen_until = was_open and (Game():GetFrameCount() + 8) or nil
	pcall(function() auxi.time_free(item.own_key) end)
	restore_eid_after_blueprint()
end,
})

-- 滚轮必须在 Render 读取，且单独用极早优先级捕获。
-- 不能只在 render_panel 函数内「提前」：该函数所在的普通回调本身可能已晚于
-- 本模组或其他模组的鼠标输入回调，移动鼠标时 RGON/SDL 可丢失同帧滚轮脉冲。
table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	priority = -10000,
	Function = function(_)
		local panel = item.panel
		if not panel or panel.was_paused or Game():IsPaused() then return end
		if not panel.craft then
			local tab = item.tabs[panel.tab]
			if not tab or tab.id ~= "formation" then return end
		end
		panel.wheel_render_serial = (panel.wheel_render_serial or 0) + 1
		capture_mouse_wheel(panel, "post_render_priority#"..tostring(panel.wheel_render_serial))
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	scrub_stale_panel()
	if item.panel then hide_eid_for_blueprint() end
	item.render_panel()
end,
})

if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_ADD_COLLECTIBLE,
		params = nil,
		Function = function(_, _type, _charge, _first, _slot, _var, player)
			if player then item.refresh_craft_integrity(player) end
			if item.panel and item.panel.craft and same_panel_player(player) then
				item.panel.craft._bag_dirty = true
			end
		end,
	})
end
if ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED,
		params = nil,
		Function = function(_, player, _type)
			if player then item.refresh_craft_integrity(player) end
			if item.panel and item.panel.craft and same_panel_player(player) then
				item.panel.craft._bag_dirty = true
			end
		end,
	})
end

return item

local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Mouse_UI = require("Qing_Remaster_scripts.others.Mouse_UI_holder")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local CraftIdentity = require("Qing_Remaster_scripts.mimics.craft_identity")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")

local BP = {}

function BP.get_bandwidth()
	return require("Qing_Remaster_scripts.mimics.Craft_Bandwidth_Manager")
end

function BP.get_tutorial()
	return require("Qing_Remaster_scripts.others.blueprint_tutorial")
end

local item = {
	ToCall = {},
	pre_ToCall = {},
	myToCall = {},
	entity = enums.Items.Blue_Print,
	own_key = "Item_Blue_Print_",
	CRAFT_UID_KEY = CraftIdentity.CRAFT_UID_KEY,
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
	mirror_slot_oy = 54, -- 相对机体图标中心的镜像模块槽 Y 偏移
	quality_anm2 = "gfx/ui/EID/eid_quality.anm2",
	quality_icon_offset = Vector(8, -12), -- 相对背包 token 中心，右上
	form_bench_page_size = 4,
	form_orbit_spin_deg = 0.55, -- 编队卡环绕模块每帧转角（缓转）
	stock_loadout_icon_scale = 0.42, -- 仓库行右侧装配图标缩放
	stock_loadout_icon_step = 12, -- 仓库装配图标中心距
	cost_offset_y_default = 21, -- 成本小槽相对目标图标中心下移（材料槽以此为分割线）
	cost_extra_count_default = 0, -- 成本小槽额外显示数量（便于测排版）
	cost_slot_size_default = 18, -- 实测合适；间距随尺寸 = size+2
	cost_slot_row_gap = 2, -- 成本多行时的行距
	cost_slot_max_cols = 8,
	cost_token_scale = 0.5,
	mirror_shader = "shaders/qing_blueprint_mirror",
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
	-- 可建造底盘列表（扩展口：以后可再加第二种真正需要独立底盘的机体）。
	-- 当前仅 Air Flight；显示名对接 CraftProfile.TARGET_BASE（空行01号…）。
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

function BP.all_items_mode_allowed()
	local env = require("Qing_Remaster_scripts.core.dev_environment")
	return BP.get_debug_bool("BlueprintAllItemsModeEnabled", not env.is_public_release())
end

function BP.find_tab_index(tab_id)
	if not tab_id then return nil end
	for i, tab in ipairs(item.tabs) do
		if tab and tab.id == tab_id then
			return i
		end
	end
	return nil
end

--- 关闭权限时强制回 BAG（保留已有 audit 配方，仅禁止全道具目录）
function BP.enforce_all_items_gate(panel)
	local craft = panel and panel.craft
	if not craft then return end
	if craft.tutorial_bag then
		if craft.all_items then craft.all_items = false end
		return
	end
	if craft.all_items and not BP.all_items_mode_allowed() then
		craft.all_items = false
		craft.bag_page = 0
		craft._catalog = nil
		craft._catalog_impl = nil
		craft._catalog_missing_stat = nil
		BP.clear_bag_tokens_keep_busy(craft, panel)
		panel.nav_graph = nil
	end
end

function BP.get_target_info(col_id)
	for _, info in ipairs(item.build_targets) do
		if info.id == col_id then return info end
	end
end

local BlueprintStore = require("Qing_Remaster_scripts.others.blueprint.store")
BlueprintStore.attach(item, BP)

local BlueprintIntegrity = require("Qing_Remaster_scripts.others.blueprint.integrity")
BlueprintIntegrity.attach(item, BP)

local BlueprintEditor = require("Qing_Remaster_scripts.others.blueprint.editor")
BlueprintEditor.attach(item, BP)

local BlueprintPanel = require("Qing_Remaster_scripts.others.blueprint.panel")
BlueprintPanel.attach(item, BP)

local BlueprintPanelInput = require("Qing_Remaster_scripts.others.blueprint.panel_input")
BlueprintPanelInput.attach(item, BP)

local BlueprintPanelRender = require("Qing_Remaster_scripts.others.blueprint.panel_render")
BlueprintPanelRender.attach(item, BP)


function BP.live_charge_profile(craft)
	if not craft then
		return CraftProfile.build_profile({})
	end
	return CraftProfile.build_profile(BP.profile_ingredients(craft))
end

function BP.canonicalize_craft_charge(craft, raw)
	return CraftProfile.canonicalize_main_charge(BP.live_charge_profile(craft), raw)
end

function BP.clamp_charge_ratio(r)
	-- 无 profile 时仅作兜底外包络；正式路径请用 canonicalize_craft_charge。
	return CraftProfile.project_charge_to_domain(r, {
		intervals = { { 0.25, 3.0 } },
	})
end

function BP.clamp_choco_ratio(r)
	return CraftProfile.resolve_charge_for_mechanism(nil, "chocolate", r) or 1
end

--- 当前配方需要显示的蓄力滑条（自下而上；不依赖后文 read_ingredients）
function BP.list_charge_sliders(craft)
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
	local wpn = live.weapon or 1
	if ex.chocolate or ex.cursed_eye or wpn == 9 or wpn == 4 then
		local min_ratio, max_ratio = CraftProfile.get_charge_slider_range(live)
		out[1] = {
			id = "main_charge_slider", key = "main_charge_ratio",
			zh = "主攻击蓄力", en = "Main charge",
			profile = live,
			min_ratio = min_ratio,
			max_ratio = max_ratio,
			has_cursed = ex.cursed_eye == true,
			colors = {
				chocolate = KColor(0.95, 0.58, 0.25, 0.95),
				techx = KColor(0.35, 0.82, 1, 0.95),
				knife = KColor(0.85, 0.42, 0.48, 0.95),
				cursed = KColor(0.72, 0.35, 0.9, 0.95),
				mixed = KColor(0.95, 0.82, 0.38, 0.95),
			},
			color_key = ((ex.chocolate and (wpn == 9 or wpn == 4 or ex.cursed_eye)) and "mixed")
				or (ex.cursed_eye and "cursed") or (wpn == 9 and "techx") or (wpn == 4 and "knife") or "chocolate",
		}
	end
	return out
end

function BP.craft_has_base(craft)
	if not craft then return false end
	for _, tid in ipairs(craft.cost_ids or {}) do
		local tok = craft.token_map and craft.token_map[tid]
		if tok and tok.cost then return true end
	end
	return false
end

function BP.sync_show_quality(craft)
	if not craft or craft.quality_user_set then return end
	-- 默认关；仅底座空着时自动打开，方便挑品质。
	craft.show_quality = not BP.craft_has_base(craft)
end

function BP.toggle_show_quality(panel)
	local craft = panel and panel.craft
	if not craft then return end
	craft.quality_user_set = true
	craft.show_quality = not craft.show_quality
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.4, 1, false, 0, 2)
end

function BP.begin_snap_anim(tok, target_pos)
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

function BP.find_empty_ingredient_slot(craft, exclude_index)
	for i, slot in ipairs((craft and craft.slots) or {}) do
		if i ~= exclude_index and not slot.token then
			return i
		end
	end
	return nil
end

--- 被挤出槽位：优先落在当前页道具列下方的空隙，避免插进图标之间
function BP.tick_tokens(panel, panel_rect, bag_rect, geom)
	local craft = panel.craft
	if not craft then return end
	BP.reconcile_slot_occupancy(craft)
	local cost_pos = geom and geom.cost_pos
	local cost_center = cost_pos
	if geom and geom.cost_rect then
		cost_center = Mouse_UI.rect_center(geom.cost_rect)
	end
	local attract = item.cost_attract_dist or 52
	if geom and geom.cost_rect then
		attract = math.max(attract, math.max(geom.cost_rect.w, geom.cost_rect.h) * 0.55)
	end
	local cost_scale = BP.get_cost_token_scale()
	for _, tok in ipairs(craft.tokens) do
		local near_cost = cost_center and (tok.pos - cost_center):Length() <= attract
		-- 材料/镜像槽内保持正常尺寸；仅成本占用或靠近成本带的游离 token 缩小
		if tok.slot or tok.mirror_slot then
			tok.visual_scale = 1
		elseif tok.cost then
			tok.visual_scale = (tok.visual_scale or 1) * 0.75 + cost_scale * 0.25
		elseif near_cost then
			tok.visual_scale = (tok.visual_scale or 1) * 0.75 + cost_scale * 0.25
		else
			tok.visual_scale = (tok.visual_scale or 1) * 0.75 + 1 * 0.25
		end

		if panel.drag and panel.drag.token_id == tok.id then
			-- drag handled elsewhere
		elseif BP.tick_token_anim(tok) then
			-- animating
		elseif tok.slot and craft.slots[tok.slot] and craft.slots[tok.slot]._rect then
			tok.pos = Mouse_UI.rect_center(craft.slots[tok.slot]._rect)
			tok.vel = Vector(0, 0)
		elseif tok.mirror_slot and geom and geom.mirror_pos then
			tok.pos = geom.mirror_pos
			tok.vel = Vector(0, 0)
		elseif tok.cost and cost_pos then
			local idx = 1
			for i, tid in ipairs(craft.cost_ids or {}) do
				if tid == tok.id then idx = i break end
			end
			tok.pos = BP.cost_stack_pos(craft, geom, idx)
			tok.vel = Vector(0, 0)
		elseif not tok.slot and not tok.cost and cost_center and near_cost
			and not (tok.source == "prototype" or tok.is_prototype)
			and not (panel.pad_carry and panel.pad_carry.token_id == tok.id)
			and not (tok.from_bag and bag_rect and Mouse_UI.point_in_rect(tok.pos, bag_rect)
				and not (geom and geom.cost_rect and Mouse_UI.point_in_rect(tok.pos, geom.cost_rect)))
			and (not BP.get_tutorial().is_locking() or BP.get_tutorial().allows_cost_assign(tok)) then
			local pull = (cost_center - tok.pos) * 0.18
			tok.vel = (tok.vel + pull) * 0.85
			tok.pos = tok.pos + tok.vel
			if (tok.pos - cost_center):Length() <= item.snap_dist * 0.65 then
				BP.assign_token_cost(craft, tok, geom)
			end
		elseif tok.vel:Length() > item.inertia_stop then
			tok.pos = tok.pos + tok.vel
			tok.vel = tok.vel * item.inertia_friction
			tok.pos = BP.clamp_to_rect(tok.pos, panel_rect)
			if tok.vel:Length() <= item.inertia_stop then
				tok.vel = Vector(0, 0)
				if tok.from_bag and tok.home then
					BP.begin_snap_anim(tok, tok.home)
				end
			end
		else
			tok.vel = Vector(0, 0)
		end
	end
end


-- ---------- UI 构建 ----------
function BP.clear_bag_tokens_keep_busy(craft, panel)
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

-- 渲染闭包单独成函数，避免本文件顶层 local 超过 Lua 200 上限。
item.render_panel = BP.render_panel
item.update_panel_input = BP.update_panel_input

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
	BP.scrub_stale_panel()
	if BP.same_panel_player(player) then
		-- 已开启：再次使用 = 关闭
		BP.close_panel()
		return {Discharge = false, ShowAnim = false}
	end
	if item.panel then
		-- 其他人占用或异常占用：关掉再开
		BP.close_panel()
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
	BP.open_panel(player)
	return {Discharge = false, ShowAnim = false}
end,
})

-- 面板开启时挡移动/射击等；MENUBACK/ESC 放行以便唤起暂停
-- PILLCARD 始终拦截（防误用卡牌）；副手时退出键另用缓存探测真值
table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil, priority = -1000,
Function = function(_, ent, hook, button)
	if not BP.blueprint_input_active() then return end
	if ent == nil then return end
	local player = ent:ToPlayer()
	if not player or not BP.same_panel_player(player) then return end
	if button == ButtonAction.ACTION_PILLCARD and BP.pillcard_is_probing() then
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
	BP.scrub_stale_panel()

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
				BP.drop_held_blueprint(player)
			end
		elseif not item.panel
			and player:HasCollectible(item.entity)
			and player:IsHoldingItem()
			and not BP.pause_menu_open()
		then
			item.suppress_open_until = -1
			item.pending_reopen_until = nil
			BP.open_panel(player)
			return
		end
	end

	if not BP.same_panel_player(player) then return end
	-- 暂停菜单打开时不要继续 time_stop：从暂停重开会把 Attribute 强表 claim 带进新局，
	-- userdata 复用后准星等新实体会被 Position/FREEZE 钉死（玩家在 unstopable 里仍能转头）。
	if BP.pause_menu_open() then
		if item.panel then item.panel.was_paused = true end
		return
	end
	-- 面板打开时已完整冻结一次；这里只低频接管期间新生成的实体。
	-- 禁止每帧重复 time_stop 扫描整个房间（Flight/制造宝宝多时会明显卡顿）。
	auxi.refresh_time_stop(item.own_key, 15)
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
	BP.restore_eid_after_blueprint()
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
	BP.clear_blueprint_selection(nil)
	pcall(function() auxi.time_free(item.own_key) end)
	pcall(function()
		local AH = require("Qing_Remaster_scripts.others.Attribute_holder")
		if AH.drop_all then AH.drop_all() end
	end)
	BP.restore_eid_after_blueprint()
	item._room_epoch = 0
	item._integrity_epoch_seen = {}
	for i = 0, Game():GetNumPlayers() - 1 do
		BP.drop_held_blueprint(Game():GetPlayer(i))
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
	BP.restore_eid_after_blueprint()
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
		BP.capture_mouse_wheel(panel, "post_render_priority#"..tostring(panel.wheel_render_serial))
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	BP.scrub_stale_panel()
	if item.panel then BP.hide_eid_for_blueprint() end
	item.render_panel()
end,
})

if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_ADD_COLLECTIBLE,
		params = nil,
		Function = function(_, _type, _charge, _first, _slot, _var, player)
			if player then item.refresh_craft_integrity(player) end
			if item.panel and item.panel.craft and BP.same_panel_player(player) then
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
			if item.panel and item.panel.craft and BP.same_panel_player(player) then
				item.panel.craft._bag_dirty = true
			end
		end,
	})
end

return item

-- 妖刀·逢魔 HUD 节点：统一 extract/inject + 屏幕拓扑邻接。
-- 资源视觉为 current/max 三段合并；coins / max_coins 等节点仍独立。
-- get_anchor = HUD 数字本体（VFX）；get_ghost_anchor = 妖鬼停靠点。

local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local slot_offer_lift = require("Qing_Remaster_scripts.slots.slot_offer_lift")
local deal_chance_semantics = require("Qing_Remaster_scripts.auxiliary.deal_chance_semantics")
local angel_reshape = require("Qing_Remaster_scripts.items.spectralsword.angel_reshape")
local hud_fonts = require("Qing_Remaster_scripts.items.spectralsword.hud_fonts")

local M = {}

M.NODE_IDS = {
	"coins", "max_coins",
	"bombs", "max_bombs",
	"keys", "max_keys",
	"speed", "tears", "damage", "range", "shotspeed", "luck",
	"devil", "angel", "planetarium",
}

M.STAT_KEYS = {"speed", "tears", "damage", "range", "shotspeed", "luck"}
M.RESOURCE_KEYS = {"coins", "bombs", "keys"}
M.CAP_KEYS = {"max_coins", "max_bombs", "max_keys"}
-- 内部语义：deal / angel_conversion / planetarium；HUD 仍显示恶魔/天使/星象
M.DEAL_KEYS = {"devil", "angel", "planetarium"}

-- 正式基础值（不含 debug offset）；下列默认来自 Overlay 标定
local STAT_BASE = Vector(28, 88)
local STAT_ROW_SPACING_DEFAULT = 12

local function copy_layout(src)
	return {
		stat_base_offset = Vector(src.stat_base_offset.X, src.stat_base_offset.Y),
		stat_row_spacing = src.stat_row_spacing,
		stat_text_offset = Vector(src.stat_text_offset.X, src.stat_text_offset.Y),
		mode_header_y = tonumber(src.mode_header_y) or 16,
		-- Twin：逻辑行基准 / 行距；再对 split 项叠座位偏移（非整列平移）。
		twin_stat_base_offset = Vector(src.twin_stat_base_offset.X, src.twin_stat_base_offset.Y),
		twin_stat_row_spacing = tonumber(src.twin_stat_row_spacing) or 14,
		twin_stat_split_main_offset = Vector(src.twin_stat_split_main_offset.X, src.twin_stat_split_main_offset.Y),
		twin_stat_split_other_offset = Vector(src.twin_stat_split_other_offset.X, src.twin_stat_split_other_offset.Y),
		-- Twin Deal：整块附加偏移 + Twin 专用行距（与普通 deal_row_spacing 独立）。
		twin_deal_offset = Vector(src.twin_deal_offset.X, src.twin_deal_offset.Y),
		twin_deal_row_spacing = tonumber(src.twin_deal_row_spacing) or 14,
		-- pair 起点相对 pickup HUD base；cap 位置由 layout_resource_pair 动态计算。
		resource_value_offset = Vector(src.resource_value_offset.X, src.resource_value_offset.Y),
		-- deprecated：不再作为正式 cap 绘制列；仅 Debug/旧 Probe 兼容。
		resource_cap_offset = Vector(src.resource_cap_offset.X, src.resource_cap_offset.Y),
		resource_pair_gap_before_slash = src.resource_pair_gap_before_slash,
		resource_pair_gap_after_slash = src.resource_pair_gap_after_slash,
		cap_text_offset = Vector(src.cap_text_offset.X, src.cap_text_offset.Y),
		deal_base_offset = Vector(src.deal_base_offset.X, src.deal_base_offset.Y),
		deal_row_spacing = src.deal_row_spacing,
		deal_text_offset = Vector(src.deal_text_offset.X, src.deal_text_offset.Y),
		ghost_stat_offset = Vector(src.ghost_stat_offset.X, src.ghost_stat_offset.Y),
		ghost_resource_offset = Vector(src.ghost_resource_offset.X, src.ghost_resource_offset.Y),
		ghost_cap_offset = Vector(src.ghost_cap_offset.X, src.ghost_cap_offset.Y),
		ghost_deal_offset = Vector(src.ghost_deal_offset.X, src.ghost_deal_offset.Y),
	}
end

-- resource_value_offset = current/max pair 起点（覆盖原版资源数字）。
-- cap 子串位置 = pair base + current 宽 + slash 宽 + gaps（禁止再用固定第二列）。
local DEFAULT_LAYOUT = {
	stat_base_offset = Vector(-12, -14),
	stat_row_spacing = STAT_ROW_SPACING_DEFAULT,
	stat_text_offset = Vector(0, 0),
	-- Hard / Challenge / Greed 共享的额外模式行纵向偏移（标定后固化）。
	mode_header_y = 16,
	-- Twin 属性逻辑区 / 拆分座位 / Deal 整块修正（截图标定固化）。
	twin_stat_base_offset = Vector(0, 15),
	twin_stat_row_spacing = 14,
	twin_stat_split_main_offset = Vector(0, -5),
	twin_stat_split_other_offset = Vector(4, 2),
	twin_deal_offset = Vector(0, -1),
	twin_deal_row_spacing = 14,
	resource_value_offset = Vector(8, -7),
	resource_cap_offset = Vector(32, -7), -- deprecated display column
	resource_pair_gap_before_slash = 1,
	resource_pair_gap_after_slash = 1,
	cap_text_offset = Vector(0, 0),
	deal_base_offset = Vector(0, 1),
	deal_row_spacing = 12,
	deal_text_offset = Vector(0, 0),
	ghost_stat_offset = Vector(22, 0),
	ghost_resource_offset = Vector(-18, 0),
	ghost_cap_offset = Vector(20, 0),
	ghost_deal_offset = Vector(22, 0),
}

-- 运行时标定层；调准后可固化回 DEFAULT_LAYOUT
local LAYOUT = copy_layout(DEFAULT_LAYOUT)

-- Probe 模式可隐藏 production 自绘 resource pair / Deal（不 require probe）
local DEBUG_HIDE_CUSTOM = {
	cap_text = false, -- alias: resource_pair
	deal_text = false,
}

-- 兼容旧引用
M.MAX_ANCHOR_OFFSET = LAYOUT.resource_cap_offset
M.DEBUG_LAYOUT = LAYOUT
M.STAT_BASE = STAT_BASE

local STAT_STEP = {
	speed = 0.05, tears = 0.15, damage = 0.25, range = 0.75, shotspeed = 0.10, luck = 1.00,
}
-- 每步固定消耗 1 紫灵质（不再按属性差异计价）
local STAT_ESSENCE_COST = 1
local STAT_DELTA_MIN = {
	speed = -0.50, tears = -1.50, damage = -2.50, range = -7.50, shotspeed = -1.00, luck = -10.00,
}
local STAT_DELTA_MAX = {
	speed = 1.50, tears = 4.50, damage = 7.50, range = 22.50, shotspeed = 1.20, luck = 30.00,
}
local STAT_INDEX = {
	speed = 0, tears = 1, damage = 2, range = 3, shotspeed = 4, luck = 5,
}
local STAT_ID_BY_ROW = {
	[0] = "speed", [1] = "tears", [2] = "damage",
	[3] = "range", [4] = "shotspeed", [5] = "luck",
}
local STAT_LABEL = {
	speed = {zh = "速度", en = "Speed"},
	tears = {zh = "射速", en = "Tears"},
	damage = {zh = "攻击", en = "Damage"},
	range = {zh = "射程", en = "Range"},
	shotspeed = {zh = "弹速", en = "Shot Spd"},
	luck = {zh = "幸运", en = "Luck"},
}

--- Twin 属性：Speed 共享单行；其余逻辑行内拆 Main/Other。
local STAT_TWIN_LAYOUT = {
	speed = "shared",
	tears = "split",
	damage = "split",
	range = "split",
	shotspeed = "split",
	luck = "split",
}

--- Twin Deal：永远单列 shared（仅换行距，不拆座位）。
local DEAL_TWIN_LAYOUT = {
	devil = "shared",
	angel = "shared",
	planetarium = "shared",
}

-- Deal 相对属性列「理论第 7 行」(index 6) 的逻辑基准起算（禁止继承 Luck split）
local DEAL_INDEX = {
	devil = 0,
	angel = 1,
	planetarium = 2,
}

local DEAL_STEP = 0.05
local DEAL_ESSENCE_COST = 1
local DEAL_MOD_MIN = -1.0
local DEAL_MOD_MAX = 1.0

--- 资源 / 上限硬保护：RGON C++ int 边界（INT32_MAX）。设计上无人为封顶。
M.CAP_STORAGE_MAX = 2147483647

local function clamp_storage(v)
	v = math.floor(tonumber(v) or 0)
	if v < 0 then return 0 end
	if v > M.CAP_STORAGE_MAX then return M.CAP_STORAGE_MAX end
	return v
end

--- 安全增量：避免 cur+delta 越过 [0, CAP_STORAGE_MAX]。
function M.clamp_storage_delta(cur, delta)
	cur = clamp_storage(cur)
	delta = math.floor(tonumber(delta) or 0)
	if delta == 0 then return 0 end
	if delta > 0 then
		local room = M.CAP_STORAGE_MAX - cur
		if room <= 0 then return 0 end
		return math.min(delta, room)
	end
	return math.max(delta, -cur)
end

M.clamp_storage = clamp_storage

local RESOURCE_DEF = {
	coins = {
		kind = "coin",
		get = function(p) return clamp_storage(p:GetNumCoins()) end,
		get_max = function(p)
			if p.GetMaxCoins then return clamp_storage(p:GetMaxCoins()) end
			return 99
		end,
		add = function(p, n)
			n = M.clamp_storage_delta(p:GetNumCoins(), n)
			if n ~= 0 then p:AddCoins(n) end
		end,
		step = 1,
		label = {zh = "硬币", en = "Coins"},
	},
	bombs = {
		kind = "bomb",
		get = function(p) return clamp_storage(p:GetNumBombs()) end,
		get_max = function(p)
			if p.GetMaxBombs then return clamp_storage(p:GetMaxBombs()) end
			return 99
		end,
		add = function(p, n)
			n = M.clamp_storage_delta(p:GetNumBombs(), n)
			if n ~= 0 then p:AddBombs(n) end
		end,
		step = 1,
		label = {zh = "炸弹", en = "Bombs"},
	},
	keys = {
		kind = "key",
		get = function(p) return clamp_storage(p:GetNumKeys()) end,
		get_max = function(p)
			if p.GetMaxKeys then return clamp_storage(p:GetMaxKeys()) end
			return 99
		end,
		add = function(p, n)
			n = M.clamp_storage_delta(p:GetNumKeys(), n)
			if n ~= 0 then p:AddKeys(n) end
		end,
		step = 1,
		label = {zh = "钥匙", en = "Keys"},
	},
}

local RESOURCE_CAP_DEF = {
	max_coins = {
		resource = "coins", cache = "maxcoins", cap_key = "max_coins",
		label = {zh = "硬币上限", en = "Coin Cap"},
	},
	max_bombs = {
		resource = "bombs", cache = "maxbombs", cap_key = "max_bombs",
		label = {zh = "炸弹上限", en = "Bomb Cap"},
	},
	max_keys = {
		resource = "keys", cache = "maxkeys", cap_key = "max_keys",
		label = {zh = "钥匙上限", en = "Key Cap"},
	},
}

-- semantic:
--   UI label devil/angel/planetarium remain player-facing names.
--   Devil：总 Deal + 概率灵质；Angel：只改转化 modifier（分配重塑，无灵质）；
--   Planetarium：永久 modifiers.planetarium + 概率灵质；HUD 为 cached+(live-cached)。
local DEAL_DEF = {
	devil = {
		semantic = "deal",
		step = DEAL_STEP,
		retune_keep = nil,
		needs_split_retune = false,
		label = {zh = "恶魔", en = "Devil"},
	},
	angel = {
		semantic = "angel_conversion",
		step = DEAL_STEP,
		retune_keep = nil,
		needs_split_retune = false,
		label = {zh = "天使", en = "Angel"},
	},
	planetarium = {
		semantic = "planetarium",
		step = DEAL_STEP,
		retune_keep = nil,
		needs_split_retune = false,
		label = {zh = "星象", en = "Planetarium"},
	},
}

function M.found_hud_available()
	return Options ~= nil and Options.FoundHUD == true
end

--- SEED_NO_HUD：规则级无 HUD（≠ HUD:IsVisible 临时隐藏）。
function M.no_hud_seed_active()
	local seeds = Game():GetSeeds()
	if not seeds or not seeds.HasSeedEffect or SeedEffect == nil then
		return false
	end
	local flag = SeedEffect.SEED_NO_HUD
	if flag == nil then
		return false
	end
	local ok, on = pcall(function()
		return seeds:HasSeedEffect(flag)
	end)
	return ok and on == true
end

--- 统一 HUD 环境；导航 / 锚点 / 会话入口共用。
function M.get_hud_context(player)
	local no_hud = M.no_hud_seed_active()
	local hud_obj = Game():GetHUD()
	local hud_render_visible = true
	if hud_obj and hud_obj.IsVisible then
		local ok, vis = pcall(function()
			return hud_obj:IsVisible()
		end)
		if ok then
			hud_render_visible = vis == true
		end
	end
	local found = (not no_hud) and M.found_hud_available()
	local twin_role = "solo"
	if player and ui.GetPlayerHUDTwinRole then
		twin_role = ui.GetPlayerHUDTwinRole(player) or "solo"
	end
	local challenge = false
	if Game().GetChallenge and Challenge then
		local ok, ch = pcall(function()
			return Game():GetChallenge()
		end)
		if ok and Challenge.CHALLENGE_NULL ~= nil then
			challenge = ch ~= Challenge.CHALLENGE_NULL
		elseif ok then
			challenge = (tonumber(ch) or 0) ~= 0
		end
	end
	local greed = false
	if Game().IsGreedMode then
		local ok, g = pcall(function()
			return Game():IsGreedMode()
		end)
		greed = ok and g == true
	end
	local hard = false
	if Difficulty then
		local d = Game().Difficulty
		hard = d == Difficulty.DIFFICULTY_HARD
			or d == Difficulty.DIFFICULTY_GREEDIER
	end
	local mode_header = hard or challenge or greed
	return {
		hud_visible = (not no_hud) and hud_render_visible,
		no_hud_seed = no_hud,
		found_hud = found,
		planetarium = found and M.planetarium_hud_available_raw() or false,
		twin = twin_role ~= "solo",
		twin_role = twin_role,
		mode_header = mode_header,
		challenge = challenge,
		greed = greed,
		hard = hard,
	}
end

--- 与原生 Stat HUD 一致：StatHUDPlanetarium + Achievement 406（不含 FoundHUD）。
function M.planetarium_hud_available_raw()
	if not REPENTOGON then
		return false
	end
	if not Options or Options.StatHUDPlanetarium ~= true then
		return false
	end
	local pgd = Isaac.GetPersistentGameData and Isaac.GetPersistentGameData()
	if pgd and pgd.Unlocked then
		local ok, unlocked = pcall(function()
			return pgd:Unlocked(406)
		end)
		return ok and unlocked == true
	end
	return false
end

--- FoundHUD + StatHUDPlanetarium + Achievement 406。
function M.planetarium_hud_available()
	return M.found_hud_available() and M.planetarium_hud_available_raw()
end

function M.has_duality()
	return deal_chance_semantics.has_duality()
end

--- Deal 布局/导航行：普通 devil+angel+planetarium；Duality 时隐藏独立 Angel。
function M.get_active_deal_rows()
	if M.has_duality() then
		return {"devil", "planetarium"}
	end
	return {"devil", "angel", "planetarium"}
end

function M.get_deal_row_index(id)
	local rows = M.get_active_deal_rows()
	for i, rid in ipairs(rows) do
		if rid == id then
			return i - 1
		end
	end
	return DEAL_INDEX[id] or 0
end

local function current_planetarium_chance()
	local level = Game():GetLevel()
	if level and level.GetPlanetariumChance then
		local ok, v = pcall(function()
			return level:GetPlanetariumChance()
		end)
		if ok then
			return math.max(0, math.min(1, tonumber(v) or 0))
		end
	end
	local snap = deal_chance_semantics.snapshot({allow_getter_fallback = true})
	local v = tonumber(snap and snap.display and snap.display.planetarium) or 0
	return math.max(0, math.min(1, v))
end

local function current_deal_display(id)
	local snap = deal_chance_semantics.snapshot({allow_getter_fallback = true})
	if id == "devil" and deal_chance_semantics.has_duality() then
		return math.max(0, math.min(1, tonumber(snap and snap.display and snap.display.total) or 0))
	end
	return math.max(0, math.min(1, tonumber(snap and snap.display and snap.display[id]) or 0))
end

--- 资源上限：十进制全 9 边界阶梯（0–9 / 9–99 / 99–999 / …），设计上不设人为封顶。
--- 合法节点严格可逆：9↔19、99↔199、999↔1999…
--- 硬保护仅遵守 CAP_STORAGE_MAX（INT32_MAX）。
local function cap_step_up(v)
	v = math.max(0, math.floor(tonumber(v) or 0))
	local step = 1
	local boundary = 9
	while v >= boundary do
		if step >= M.CAP_STORAGE_MAX then
			break
		end
		step = step * 10
		boundary = boundary * 10 + 9
	end
	return step
end

local function cap_step_down(v)
	v = math.max(0, math.floor(tonumber(v) or 0))
	if v <= 9 then
		return 1
	end
	local step = 10
	local boundary = 99
	while v > boundary do
		if step >= M.CAP_STORAGE_MAX then
			break
		end
		step = step * 10
		boundary = boundary * 10 + 9
	end
	return step
end

--- @return number|nil 下一档；已在存储上限则 nil。
--- 下一阶梯会越界时钳到 CAP_STORAGE_MAX（允许到达 INT32，不拒绝进入）。
function M.cap_value_next_up(v)
	v = math.max(0, math.floor(tonumber(v) or 0))
	if v >= M.CAP_STORAGE_MAX then
		return nil
	end
	local step = cap_step_up(v)
	local next_v = v + step
	if next_v > M.CAP_STORAGE_MAX then
		return M.CAP_STORAGE_MAX
	end
	return next_v
end

function M.cap_value_next_down(v)
	v = math.max(0, math.floor(tonumber(v) or 0))
	if v <= 0 then
		return nil
	end
	return math.max(0, v - cap_step_down(v))
end

local function essence_amount(essence, kind)
	if not essence then return 0 end
	local v = essence[kind]
	if v == math.huge then return math.huge end
	return tonumber(v) or 0
end

local function has_essence(essence, kind, need)
	need = need or 1
	local have = essence_amount(essence, kind)
	if have == math.huge then return true end
	return have + 0.001 >= need
end

M.RESOURCE_DEF = RESOURCE_DEF
M.RESOURCE_CAP_DEF = RESOURCE_CAP_DEF
M.DEAL_DEF = DEAL_DEF
M.DEAL_STEP = DEAL_STEP
M.STAT_STEP = STAT_STEP
M.STAT_ESSENCE_COST = STAT_ESSENCE_COST
M.DEAL_ESSENCE_COST = DEAL_ESSENCE_COST
M.ESSENCE_KINDS = {"stat", "resource", "chance"}

-- 最终属性物理下限（抽取时检查）
M.STAT_PHYSICAL_FLOOR = {
	speed = 0.10,
	shotspeed = 0.60,
}

function M.empty_essence()
	return {stat = 0, resource = 0, chance = 0}
end

function M.copy_essence(src)
	local t = M.empty_essence()
	if not src then return t end
	for _, k in ipairs(M.ESSENCE_KINDS) do
		local v = src[k]
		if v == math.huge then
			t[k] = math.huge
		else
			t[k] = math.max(0, math.floor(tonumber(v) or 0))
		end
	end
	return t
end

function M.essence_total(ess)
	ess = ess or M.empty_essence()
	local n = 0
	for _, k in ipairs(M.ESSENCE_KINDS) do
		local v = ess[k] or 0
		if v == math.huge then return math.huge end
		n = n + v
	end
	return n
end

local function resource_anchor(player, kind)
	return slot_offer_lift.get_pickup_hud_screen_pos(player, kind, 0)
end

local function ghost_offset_for_group(group)
	if group == "resource" then
		return LAYOUT.ghost_resource_offset
	elseif group == "resource_cap" then
		return LAYOUT.ghost_cap_offset
	elseif group == "deal" then
		return LAYOUT.ghost_deal_offset
	end
	return LAYOUT.ghost_stat_offset
end

local function with_ghost_anchor(node)
	local base_get = node.get_anchor
	local group = node.group
	node.get_ghost_anchor = function(player)
		return base_get(player) + ghost_offset_for_group(group)
	end
	return node
end

local function mode_header_offset(ctx)
	ctx = ctx or {}
	if ctx.mode_header == true then
		return Vector(0, tonumber(LAYOUT.mode_header_y) or 16)
	end
	return Vector(0, 0)
end

function M.get_mode_header_offset(ctx)
	return mode_header_offset(ctx)
end

function M.get_stat_twin_layout(stat_id)
	return STAT_TWIN_LAYOUT[stat_id] or "shared"
end

function M.get_deal_twin_layout(deal_id)
	return DEAL_TWIN_LAYOUT[deal_id] or "shared"
end

function M.stat_id_from_row(row_index)
	return STAT_ID_BY_ROW[row_index or 0]
end

function M.get_stat_row_index(stat_id)
	return STAT_INDEX[stat_id]
end

local function resolve_ctx(opts)
	opts = opts or {}
	if opts.ctx then
		return opts.ctx
	end
	return M.get_hud_context(opts.player)
end

local function resolve_twin_role(opts, ctx)
	if opts and opts.twin_role then
		return opts.twin_role
	end
	ctx = ctx or resolve_ctx(opts)
	return (ctx and ctx.twin_role) or "solo"
end

local function twin_stat_row_spacing(ctx)
	if ctx and ctx.twin == true then
		return tonumber(LAYOUT.twin_stat_row_spacing) or LAYOUT.stat_row_spacing
	end
	return LAYOUT.stat_row_spacing
end

local function deal_row_spacing_for(ctx)
	if ctx and ctx.twin == true then
		return tonumber(LAYOUT.twin_deal_row_spacing) or LAYOUT.deal_row_spacing
	end
	return LAYOUT.deal_row_spacing
end

--- 属性逻辑行（不含 split）。row 6 = Deal 起点用的「Luck 下一逻辑行」。
function M.get_stat_logical_anchor_by_row(row_index, opts)
	opts = opts or {}
	local hud = opts.hud_offset
	if hud == nil then
		hud = Options.HUDOffset or 0
	end
	local include_shake = opts.include_shake == true
	local ctx = resolve_ctx(opts)
	local base = STAT_BASE
		+ LAYOUT.stat_base_offset
		+ Vector(hud * 20, hud * 12)
		+ mode_header_offset(ctx)
	if ctx and ctx.twin == true then
		base = base + LAYOUT.twin_stat_base_offset
	end
	if include_shake then
		base = base + ui.GetHUDRenderOffset()
	end
	return base + Vector(0, twin_stat_row_spacing(ctx) * (row_index or 0))
end

function M.get_stat_logical_anchor(stat_id, opts)
	local row = STAT_INDEX[stat_id]
	if row == nil then
		return M.get_stat_logical_anchor_by_row(0, opts)
	end
	return M.get_stat_logical_anchor_by_row(row, opts)
end

local function twin_stat_split_offset(role)
	if role == "main" then
		return LAYOUT.twin_stat_split_main_offset
	end
	if role == "other" then
		return LAYOUT.twin_stat_split_other_offset
	end
	return Vector(0, 0)
end

function M.get_twin_stat_split_offset(role)
	return twin_stat_split_offset(role)
end

--- 最终显示点：逻辑行 +（Twin split 项的座位偏移）。Speed / Solo 无 split。
function M.get_stat_display_anchor(stat_id, opts)
	opts = opts or {}
	local ctx = resolve_ctx(opts)
	local logical = M.get_stat_logical_anchor(stat_id, opts)
	if not (ctx and ctx.twin == true) then
		return logical
	end
	if M.get_stat_twin_layout(stat_id) ~= "split" then
		return logical
	end
	local role = resolve_twin_role(opts, ctx)
	return logical + twin_stat_split_offset(role)
end

--- 兼容旧签名：index → display。Deal 禁止用本函数取 Luck 子座位当起点。
function M.get_stat_layout_anchor(stat_index, opts)
	opts = opts or {}
	local id = STAT_ID_BY_ROW[stat_index or 0]
	if id then
		return M.get_stat_display_anchor(id, opts)
	end
	-- 非属性行（如 6）：仅逻辑行，无 split。
	return M.get_stat_logical_anchor_by_row(stat_index, opts)
end

--- 渲染用：含当前 HUD shake。
function M.get_stat_hud_anchor(stat_index, player)
	return M.get_stat_layout_anchor(stat_index, {
		include_shake = true,
		player = player,
	})
end

--- Deal：永远 shared。起点 = 属性逻辑 row6 + deal_base_offset；Twin 再叠整块 twin_deal_offset。
--- Twin 行距用 twin_deal_row_spacing；Solo 用 deal_row_spacing。禁止继承 Luck split。
function M.get_deal_layout_anchor(deal_index, opts)
	opts = opts or {}
	local ctx = resolve_ctx(opts)
	local base = M.get_stat_logical_anchor_by_row(6, opts) + LAYOUT.deal_base_offset
	if ctx and ctx.twin == true then
		base = base + LAYOUT.twin_deal_offset
	end
	return base + Vector(0, deal_row_spacing_for(ctx) * (deal_index or 0))
end

function M.get_deal_hud_anchor(deal_index, player)
	return M.get_deal_layout_anchor(deal_index, {
		include_shake = true,
		player = player,
	})
end

function M.get_layout_config()
	return {
		stat_base_raw_x = STAT_BASE.X,
		stat_base_raw_y = STAT_BASE.Y,
		stat_base_x = LAYOUT.stat_base_offset.X,
		stat_base_y = LAYOUT.stat_base_offset.Y,
		stat_row_spacing = LAYOUT.stat_row_spacing,
		stat_text_x = LAYOUT.stat_text_offset.X,
		stat_text_y = LAYOUT.stat_text_offset.Y,
		mode_header_y = LAYOUT.mode_header_y,
		twin_stat_base_x = LAYOUT.twin_stat_base_offset.X,
		twin_stat_base_y = LAYOUT.twin_stat_base_offset.Y,
		twin_stat_row_spacing = LAYOUT.twin_stat_row_spacing,
		twin_stat_split_main_x = LAYOUT.twin_stat_split_main_offset.X,
		twin_stat_split_main_y = LAYOUT.twin_stat_split_main_offset.Y,
		twin_stat_split_other_x = LAYOUT.twin_stat_split_other_offset.X,
		twin_stat_split_other_y = LAYOUT.twin_stat_split_other_offset.Y,
		twin_deal_x = LAYOUT.twin_deal_offset.X,
		twin_deal_y = LAYOUT.twin_deal_offset.Y,
		twin_deal_row_spacing = LAYOUT.twin_deal_row_spacing,
		resource_value_x = LAYOUT.resource_value_offset.X,
		resource_value_y = LAYOUT.resource_value_offset.Y,
		resource_pair_x = LAYOUT.resource_value_offset.X,
		resource_pair_y = LAYOUT.resource_value_offset.Y,
		resource_pair_gap_before_slash = LAYOUT.resource_pair_gap_before_slash,
		resource_pair_gap_after_slash = LAYOUT.resource_pair_gap_after_slash,
		-- deprecated：固定第二列；正式 cap 用 layout_resource_pair
		resource_cap_x = LAYOUT.resource_cap_offset.X,
		resource_cap_y = LAYOUT.resource_cap_offset.Y,
		-- 兼容旧 ImGui / summary 键名
		resource_text_x = LAYOUT.resource_value_offset.X,
		resource_text_y = LAYOUT.resource_value_offset.Y,
		cap_anchor_x = LAYOUT.resource_cap_offset.X,
		cap_anchor_y = LAYOUT.resource_cap_offset.Y,
		cap_text_x = LAYOUT.cap_text_offset.X,
		cap_text_y = LAYOUT.cap_text_offset.Y,
		deal_base_x = LAYOUT.deal_base_offset.X,
		deal_base_y = LAYOUT.deal_base_offset.Y,
		deal_row_spacing = LAYOUT.deal_row_spacing,
		deal_text_x = LAYOUT.deal_text_offset.X,
		deal_text_y = LAYOUT.deal_text_offset.Y,
		ghost_stat_x = LAYOUT.ghost_stat_offset.X,
		ghost_stat_y = LAYOUT.ghost_stat_offset.Y,
		ghost_resource_x = LAYOUT.ghost_resource_offset.X,
		ghost_resource_y = LAYOUT.ghost_resource_offset.Y,
		ghost_cap_x = LAYOUT.ghost_cap_offset.X,
		ghost_cap_y = LAYOUT.ghost_cap_offset.Y,
		ghost_deal_x = LAYOUT.ghost_deal_offset.X,
		ghost_deal_y = LAYOUT.ghost_deal_offset.Y,
	}
end

function M.get_debug_layout()
	return M.get_layout_config()
end

function M.get_stat_text_offset()
	return LAYOUT.stat_text_offset
end

function M.get_resource_value_offset()
	return LAYOUT.resource_value_offset
end

--- pair 起点；与 resource_value_offset 同一字段。
function M.get_resource_pair_offset()
	return LAYOUT.resource_value_offset
end

function M.get_resource_pair_gaps()
	return {
		gap_before_slash = LAYOUT.resource_pair_gap_before_slash or 1,
		gap_after_slash = LAYOUT.resource_pair_gap_after_slash or 1,
	}
end

--- deprecated：固定第二列偏移；正式 cap 用 layout_resource_pair_for。
function M.get_resource_cap_offset()
	return LAYOUT.resource_cap_offset
end

-- 兼容旧名
function M.get_resource_text_offset()
	return Vector(0, 0) -- 数字位置已并入 get_anchor；此为 font baseline 预留
end

function M.get_cap_text_offset()
	return LAYOUT.cap_text_offset
end

function M.get_deal_text_offset()
	return LAYOUT.deal_text_offset
end

--- 共享 current/max 布局（相对 pickup base + pair offset）。
function M.layout_resource_pair_for(player, resource_id)
	local def = RESOURCE_DEF[resource_id]
	if not def or not player then
		return nil
	end
	local base = resource_anchor(player, def.kind) + LAYOUT.resource_value_offset
	local gaps = M.get_resource_pair_gaps()
	return hud_fonts.layout_resource_pair(base, def.get(player), def.get_max(player), gaps)
end

function M.set_debug_hide_custom_text(group, hide)
	if group == "cap" or group == "cap_text" or group == "resource_pair" then
		DEBUG_HIDE_CUSTOM.cap_text = hide and true or false
	elseif group == "deal" or group == "deal_text" then
		DEBUG_HIDE_CUSTOM.deal_text = hide and true or false
	elseif group == "all" then
		DEBUG_HIDE_CUSTOM.cap_text = hide and true or false
		DEBUG_HIDE_CUSTOM.deal_text = hide and true or false
	end
end

function M.get_debug_hide_custom_text(group)
	if group == "cap" or group == "cap_text" or group == "resource_pair" then
		return DEBUG_HIDE_CUSTOM.cap_text == true
	elseif group == "deal" or group == "deal_text" then
		return DEBUG_HIDE_CUSTOM.deal_text == true
	end
	return DEBUG_HIDE_CUSTOM.cap_text == true or DEBUG_HIDE_CUSTOM.deal_text == true
end

local function set_vec_xy(field, axis, v)
	local cur = LAYOUT[field]
	if axis == "x" then
		LAYOUT[field] = Vector(tonumber(v) or 0, cur.Y)
	else
		LAYOUT[field] = Vector(cur.X, tonumber(v) or 0)
	end
end

local function sync_max_anchor()
	M.MAX_ANCHOR_OFFSET = LAYOUT.resource_cap_offset
end

local LAYOUT_SETTERS = {
	stat_base_x = function(v) set_vec_xy("stat_base_offset", "x", v) end,
	stat_base_y = function(v) set_vec_xy("stat_base_offset", "y", v) end,
	stat_row_spacing = function(v)
		LAYOUT.stat_row_spacing = tonumber(v) or STAT_ROW_SPACING_DEFAULT
	end,
	stat_text_x = function(v) set_vec_xy("stat_text_offset", "x", v) end,
	stat_text_y = function(v) set_vec_xy("stat_text_offset", "y", v) end,
	mode_header_y = function(v)
		LAYOUT.mode_header_y = tonumber(v) or 16
	end,
	twin_stat_base_x = function(v) set_vec_xy("twin_stat_base_offset", "x", v) end,
	twin_stat_base_y = function(v) set_vec_xy("twin_stat_base_offset", "y", v) end,
	twin_stat_row_spacing = function(v)
		LAYOUT.twin_stat_row_spacing = tonumber(v) or 14
	end,
	twin_stat_split_main_x = function(v) set_vec_xy("twin_stat_split_main_offset", "x", v) end,
	twin_stat_split_main_y = function(v) set_vec_xy("twin_stat_split_main_offset", "y", v) end,
	twin_stat_split_other_x = function(v) set_vec_xy("twin_stat_split_other_offset", "x", v) end,
	twin_stat_split_other_y = function(v) set_vec_xy("twin_stat_split_other_offset", "y", v) end,
	twin_deal_x = function(v) set_vec_xy("twin_deal_offset", "x", v) end,
	twin_deal_y = function(v) set_vec_xy("twin_deal_offset", "y", v) end,
	twin_deal_row_spacing = function(v)
		LAYOUT.twin_deal_row_spacing = tonumber(v) or 14
	end,
	resource_value_x = function(v) set_vec_xy("resource_value_offset", "x", v) end,
	resource_value_y = function(v) set_vec_xy("resource_value_offset", "y", v) end,
	resource_pair_x = function(v) LAYOUT_SETTERS.resource_value_x(v) end,
	resource_pair_y = function(v) LAYOUT_SETTERS.resource_value_y(v) end,
	resource_pair_gap_before_slash = function(v)
		LAYOUT.resource_pair_gap_before_slash = tonumber(v) or 1
	end,
	resource_pair_gap_after_slash = function(v)
		LAYOUT.resource_pair_gap_after_slash = tonumber(v) or 1
	end,
	resource_cap_x = function(v)
		set_vec_xy("resource_cap_offset", "x", v)
		sync_max_anchor()
	end,
	resource_cap_y = function(v)
		set_vec_xy("resource_cap_offset", "y", v)
		sync_max_anchor()
	end,
	-- 旧键名 → 新字段
	resource_text_x = function(v) LAYOUT_SETTERS.resource_value_x(v) end,
	resource_text_y = function(v) LAYOUT_SETTERS.resource_value_y(v) end,
	cap_anchor_x = function(v) LAYOUT_SETTERS.resource_cap_x(v) end,
	cap_anchor_y = function(v) LAYOUT_SETTERS.resource_cap_y(v) end,
	cap_text_x = function(v) set_vec_xy("cap_text_offset", "x", v) end,
	cap_text_y = function(v) set_vec_xy("cap_text_offset", "y", v) end,
	deal_base_x = function(v) set_vec_xy("deal_base_offset", "x", v) end,
	deal_base_y = function(v) set_vec_xy("deal_base_offset", "y", v) end,
	deal_row_spacing = function(v)
		LAYOUT.deal_row_spacing = tonumber(v) or 12
	end,
	deal_text_x = function(v) set_vec_xy("deal_text_offset", "x", v) end,
	deal_text_y = function(v) set_vec_xy("deal_text_offset", "y", v) end,
	ghost_stat_x = function(v) set_vec_xy("ghost_stat_offset", "x", v) end,
	ghost_stat_y = function(v) set_vec_xy("ghost_stat_offset", "y", v) end,
	ghost_resource_x = function(v) set_vec_xy("ghost_resource_offset", "x", v) end,
	ghost_resource_y = function(v) set_vec_xy("ghost_resource_offset", "y", v) end,
	ghost_cap_x = function(v) set_vec_xy("ghost_cap_offset", "x", v) end,
	ghost_cap_y = function(v) set_vec_xy("ghost_cap_offset", "y", v) end,
	ghost_deal_x = function(v) set_vec_xy("ghost_deal_offset", "x", v) end,
	ghost_deal_y = function(v) set_vec_xy("ghost_deal_offset", "y", v) end,
}

function M.set_debug_layout(key, value)
	local fn = LAYOUT_SETTERS[key]
	if not fn then return false end
	fn(value)
	return true
end

function M.reset_layout_config()
	LAYOUT = copy_layout(DEFAULT_LAYOUT)
	M.DEBUG_LAYOUT = LAYOUT
	sync_max_anchor()
end

--- 状态摘要用：区分稳定 layout 与含 shake 的 render。
function M.describe_layout_status(player)
	local cfg = M.get_layout_config()
	local hud = Options.HUDOffset or 0
	local ctx = M.get_hud_context(player)
	local layout_speed = M.get_stat_layout_anchor(0, {hud_offset = hud, include_shake = false, player = player, ctx = ctx})
	local render_speed = M.get_stat_layout_anchor(0, {hud_offset = hud, include_shake = true, player = player, ctx = ctx})
	local shake = ui.GetHUDRenderOffset()
	return {
		config = cfg,
		hud_offset = hud,
		shake_x = shake and shake.X or 0,
		shake_y = shake and shake.Y or 0,
		speed_layout_x = layout_speed.X,
		speed_layout_y = layout_speed.Y,
		speed_render_x = render_speed.X,
		speed_render_y = render_speed.Y,
		hud_context = ctx,
		devil_layout = M.get_deal_layout_anchor(M.get_deal_row_index("devil"), {hud_offset = hud, include_shake = false, player = player, ctx = ctx}),
		planetarium_layout = M.get_deal_layout_anchor(M.get_deal_row_index("planetarium"), {hud_offset = hud, include_shake = false, player = player, ctx = ctx}),
		cap_sample = player and (function()
			local layout = M.layout_resource_pair_for(player, "coins")
			return layout and layout.cap_pos or nil
		end)() or nil,
	}
end

function M.empty_modifiers()
	return {
		speed = 0, tears = 0, damage = 0, range = 0, shotspeed = 0, luck = 0,
		devil = 0, angel = 0, planetarium = 0,
	}
end

function M.empty_caps()
	return {max_coins = 0, max_bombs = 0, max_keys = 0}
end

function M.copy_modifiers(src)
	local t = M.empty_modifiers()
	if not src then return t end
	for k, _ in pairs(t) do
		t[k] = src[k] or 0
	end
	if src.deltas then
		for _, key in ipairs(M.STAT_KEYS) do
			t[key] = src.deltas[key] or t[key] or 0
		end
	end
	return t
end

function M.copy_caps(src)
	local t = M.empty_caps()
	if not src then return t end
	for _, key in ipairs(M.CAP_KEYS) do
		t[key] = src[key] or 0
	end
	return t
end

local function clamp_stat_delta(key, value)
	return math.max(STAT_DELTA_MIN[key], math.min(STAT_DELTA_MAX[key], value))
end

local function clamp_deal_mod(value)
	return math.max(DEAL_MOD_MIN, math.min(DEAL_MOD_MAX, tonumber(value) or 0))
end

function M.clamp_deal_mod(value)
	return clamp_deal_mod(value)
end

local function make_resource_node(id)
	local def = RESOURCE_DEF[id]
	return with_ghost_anchor({
		id = id,
		group = "resource",
		kind = "immediate",
		essence_kind = "resource",
		derived_anchor = false,
		enabled = true,
		locked = false,
		spirit_value = 1, -- 兼容旧 UI 文案：每步 1 球
		unit_amount = def.step,
		highlight_radius = 14,
		label = function(zh)
			return zh and def.label.zh or def.label.en
		end,
		get_anchor = function(player)
			return resource_anchor(player, def.kind) + LAYOUT.resource_value_offset
		end,
		read = function(player)
			return def.get(player)
		end,
		read_max = function(player)
			return def.get_max(player)
		end,
		can_extract = function(player, _modifiers, _caps)
			return def.get(player) >= def.step
		end,
		extract = function(player, _modifiers, _caps)
			def.add(player, -def.step)
			return 1
		end,
		can_inject = function(player, _modifiers, essence, _caps)
			if not has_essence(essence, "resource", 1) then return false end
			local cur = def.get(player)
			if cur + def.step > def.get_max(player) then return false end
			return M.clamp_storage_delta(cur, def.step) == def.step
		end,
		inject = function(player, _modifiers, _caps)
			def.add(player, def.step)
			return 1
		end,
	})
end

local function make_cap_node(id)
	local cdef = RESOURCE_CAP_DEF[id]
	local rdef = RESOURCE_DEF[cdef.resource]
	return with_ghost_anchor({
		id = id,
		group = "resource_cap",
		kind = "shared_cap",
		essence_kind = "resource",
		resource_id = cdef.resource,
		derived_anchor = true,
		enabled = true,
		locked = false,
		spirit_value = 1,
		unit_amount = 1,
		cache_tag = cdef.cache,
		cap_key = cdef.cap_key,
		highlight_radius = 12,
		label = function(zh)
			return zh and cdef.label.zh or cdef.label.en
		end,
		get_anchor = function(player)
			local layout = M.layout_resource_pair_for(player, cdef.resource)
			if layout then
				return layout.cap_pos
			end
			-- fallback：仅在 layout 失败时用旧固定列
			return resource_anchor(player, rdef.kind) + LAYOUT.resource_value_offset
		end,
		read = function(player)
			return rdef.get_max(player)
		end,
		can_extract = function(player, _modifiers, caps)
			caps = caps or M.empty_caps()
			local current_max = rdef.get_max(player)
			local target_max = M.cap_value_next_down(current_max)
			if target_max == nil then
				return false
			end
			local held = rdef.get(player)
			return held <= target_max + 1e-9
		end,
		extract = function(player, _modifiers, caps)
			caps = caps or M.empty_caps()
			local current_bonus = caps[cdef.cap_key] or 0
			local current_max = rdef.get_max(player)
			local target_max = M.cap_value_next_down(current_max)
			if target_max == nil then
				return 0, cdef.cache
			end
			local base_max = current_max - current_bonus
			caps[cdef.cap_key] = target_max - base_max
			return 1, cdef.cache
		end,
		can_inject = function(player, _modifiers, essence, _caps)
			if not has_essence(essence, "resource", 1) then return false end
			local current_max = rdef.get_max(player)
			return M.cap_value_next_up(current_max) ~= nil
		end,
		inject = function(player, _modifiers, caps)
			caps = caps or M.empty_caps()
			local current_bonus = caps[cdef.cap_key] or 0
			local current_max = rdef.get_max(player)
			local target_max = M.cap_value_next_up(current_max)
			if target_max == nil then
				return 0, cdef.cache
			end
			local base_max = current_max - current_bonus
			caps[cdef.cap_key] = target_max - base_max
			return 1, cdef.cache
		end,
	})
end

local function make_stat_node(id)
	local step = STAT_STEP[id]
	local floor_v = M.STAT_PHYSICAL_FLOOR[id]
	return with_ghost_anchor({
		id = id,
		group = "stats",
		kind = "persistent",
		essence_kind = "stat",
		twin_layout = STAT_TWIN_LAYOUT[id] or "shared",
		derived_anchor = false,
		enabled = true,
		locked = false,
		spirit_value = STAT_ESSENCE_COST,
		step = step,
		highlight_radius = 12,
		label = function(zh)
			local L = STAT_LABEL[id]
			return zh and L.zh or L.en
		end,
		get_twin_layout = function()
			return STAT_TWIN_LAYOUT[id] or "shared"
		end,
		get_logical_anchor = function(player)
			return M.get_stat_logical_anchor(id, {
				include_shake = true,
				player = player,
			})
		end,
		get_anchor = function(player)
			return M.get_stat_display_anchor(id, {
				include_shake = true,
				player = player,
			})
		end,
		read = function(_player, modifiers)
			return (modifiers and modifiers[id]) or 0
		end,
		can_extract = function(player, draft)
			local cur = (draft and draft[id]) or 0
			local next_val = clamp_stat_delta(id, cur - step)
			if next_val >= cur - 1e-6 then return false end
			-- 物理下限：当前实际值已经 <= floor 才拒绝（允许最后一刀砍到 floor）
			if floor_v and player then
				if id == "speed" and (player.MoveSpeed or 0) <= floor_v + 1e-6 then
					return false
				end
				if id == "shotspeed" and (player.ShotSpeed or 0) <= floor_v + 1e-6 then
					return false
				end
			end
			return true
		end,
		extract = function(_player, draft)
			local cur = draft[id] or 0
			draft[id] = clamp_stat_delta(id, cur - step)
			return STAT_ESSENCE_COST
		end,
		can_inject = function(_player, draft, essence)
			if not has_essence(essence, "stat", STAT_ESSENCE_COST) then return false end
			local cur = (draft and draft[id]) or 0
			local next_val = clamp_stat_delta(id, cur + step)
			return next_val > cur + 1e-6
		end,
		inject = function(_player, draft)
			local cur = draft[id] or 0
			draft[id] = clamp_stat_delta(id, cur + step)
			return STAT_ESSENCE_COST
		end,
	})
end

--- 恶魔：改总 Deal（概率灵质）。Duality 下该节点直接表示合并 Deal 总概率。
local function make_devil_node()
	local def = DEAL_DEF.devil
	return with_ghost_anchor({
		id = "devil",
		group = "deal",
		kind = "deal_mod",
		essence_kind = "chance",
		twin_layout = "shared",
		semantic = def.semantic,
		retune_keep = nil,
		needs_split_retune = false,
		derived_anchor = true,
		enabled = true,
		locked = false,
		spirit_value = DEAL_ESSENCE_COST,
		step = def.step,
		highlight_radius = 12,
		label = function(zh)
			return zh and def.label.zh or def.label.en
		end,
		get_twin_layout = function()
			return "shared"
		end,
		get_anchor = function(player)
			return M.get_deal_hud_anchor(M.get_deal_row_index("devil"), player)
		end,
		read = function(_player, modifiers)
			return (modifiers and modifiers.devil) or 0
		end,
		can_extract = function(_player, _draft)
			return current_deal_display("devil") > 1e-9
		end,
		extract = function(_player, _draft)
			return DEAL_ESSENCE_COST
		end,
		can_inject = function(_player, _draft, essence)
			if not has_essence(essence, "chance", DEAL_ESSENCE_COST) then return false end
			return current_deal_display("devil") < 1.0 - 1e-9
		end,
		inject = function(_player, _draft)
			return DEAL_ESSENCE_COST
		end,
	})
end

--- 天使：分配重塑器；无灵质。Duality 下从导航/绘制中移除。
local function angel_opts_from_ctx(ctx)
	ctx = ctx or {}
	return ctx.angel_reshape_opts or {}
end

local function make_angel_node()
	local def = DEAL_DEF.angel
	return with_ghost_anchor({
		id = "angel",
		group = "deal",
		kind = "deal_mod",
		essence_kind = nil,
		twin_layout = "shared",
		semantic = def.semantic,
		retune_keep = nil,
		needs_split_retune = false,
		derived_anchor = true,
		enabled = true,
		locked = false,
		spirit_value = 0,
		step = def.step,
		highlight_radius = 12,
		label = function(zh)
			return zh and def.label.zh or def.label.en
		end,
		get_twin_layout = function()
			return "shared"
		end,
		get_anchor = function(player)
			return M.get_deal_hud_anchor(M.get_deal_row_index("angel"), player)
		end,
		read = function(_player, modifiers)
			return (modifiers and modifiers.angel) or 0
		end,
		can_extract = function(_player, _draft, _caps, ctx)
			if M.has_duality() then return false end
			local ok = angel_reshape.can_adjust(-1, angel_opts_from_ctx(ctx))
			return ok
		end,
		extract = function(_player, _draft)
			return 0
		end,
		can_inject = function(_player, _draft, _essence, _caps, ctx)
			if M.has_duality() then return false end
			local ok = angel_reshape.can_adjust(1, angel_opts_from_ctx(ctx))
			return ok
		end,
		inject = function(_player, _draft)
			return 0
		end,
	})
end

--- 星象：永久 modifiers.planetarium；内部固定 ±DEAL_STEP；边界只看最终 chance 0%/100%。
--- 交互边界用实时 GetPlanetariumChance；显示用 Item 的 cached+(live-cached)。
local function make_planetarium_node()
	local def = DEAL_DEF.planetarium
	return with_ghost_anchor({
		id = "planetarium",
		group = "deal",
		kind = "deal_mod",
		essence_kind = "chance",
		twin_layout = "shared",
		semantic = def.semantic,
		retune_keep = nil,
		needs_split_retune = false,
		derived_anchor = true,
		enabled = true,
		locked = false,
		spirit_value = DEAL_ESSENCE_COST,
		step = def.step,
		highlight_radius = 12,
		label = function(zh)
			return zh and def.label.zh or def.label.en
		end,
		get_twin_layout = function()
			return "shared"
		end,
		get_anchor = function(player)
			return M.get_deal_hud_anchor(M.get_deal_row_index("planetarium"), player)
		end,
		read = function(_player, modifiers)
			return (modifiers and modifiers.planetarium) or 0
		end,
		can_extract = function(_player, draft)
			if not M.planetarium_hud_available() then return false end
			local cur = current_planetarium_chance()
			if cur <= 1e-9 then return false end
			local before = (draft and draft.planetarium) or 0
			local next_val = clamp_deal_mod(before - def.step)
			return next_val < before - 1e-12
		end,
		extract = function(_player, draft)
			local before = draft.planetarium or 0
			draft.planetarium = clamp_deal_mod(before - def.step)
			return DEAL_ESSENCE_COST
		end,
		can_inject = function(_player, draft, essence)
			if not M.planetarium_hud_available() then return false end
			if not has_essence(essence, "chance", DEAL_ESSENCE_COST) then return false end
			local cur = current_planetarium_chance()
			if cur >= 1.0 - 1e-9 then return false end
			local before = (draft and draft.planetarium) or 0
			local next_val = clamp_deal_mod(before + def.step)
			return next_val > before + 1e-12
		end,
		inject = function(_player, draft)
			local before = draft.planetarium or 0
			draft.planetarium = clamp_deal_mod(before + def.step)
			return DEAL_ESSENCE_COST
		end,
	})
end

-- Coin —— MaxCoin
--  │
-- Bomb —— MaxBomb
--  │
-- Key  —— MaxKey
--  │
-- Speed … Luck
--  │
-- Devil [/ Angel] / Planetarium   （Duality 时无独立 Angel 行）
-- 导航拓扑：Left/Right 横向跨行并全局循环；Up/Down 跨行首尾循环。
-- Deal 段由 get_active_deal_rows() 动态拼接，避免 Duality 留下空行。
local NAV_RESOURCE_ROWS = {
	{"coins", "max_coins"},
	{"bombs", "max_bombs"},
	{"keys", "max_keys"},
}

local NAV_STAT_ROWS = {
	{"speed"},
	{"tears"},
	{"damage"},
	{"range"},
	{"shotspeed"},
	{"luck"},
}

local function build_nav_rows(ctx)
	ctx = ctx or M.get_hud_context(nil)
	local rows = {}
	for _, row in ipairs(NAV_RESOURCE_ROWS) do
		rows[#rows + 1] = row
	end
	if ctx.found_hud then
		for _, row in ipairs(NAV_STAT_ROWS) do
			rows[#rows + 1] = row
		end
		for _, id in ipairs(M.get_active_deal_rows()) do
			if id ~= "planetarium" or M.planetarium_hud_available() then
				rows[#rows + 1] = {id}
			end
		end
	end
	return rows
end

local function nav_index_of(id, ctx)
	local rows = build_nav_rows(ctx)
	for r, row in ipairs(rows) do
		for c, nid in ipairs(row) do
			if nid == id then
				return {row = r, col = c}, rows
			end
		end
	end
	return nil, rows
end

M.NODES = {
	coins = make_resource_node("coins"),
	max_coins = make_cap_node("max_coins"),
	bombs = make_resource_node("bombs"),
	max_bombs = make_cap_node("max_bombs"),
	keys = make_resource_node("keys"),
	max_keys = make_cap_node("max_keys"),
	speed = make_stat_node("speed"),
	tears = make_stat_node("tears"),
	damage = make_stat_node("damage"),
	range = make_stat_node("range"),
	shotspeed = make_stat_node("shotspeed"),
	luck = make_stat_node("luck"),
	devil = make_devil_node(),
	angel = make_angel_node(),
	planetarium = make_planetarium_node(),
}

function M.get(id)
	return M.NODES[id]
end

--- 完整环绕拓扑：禁止再依赖节点手写 neighbors。
--- Found HUD 关闭时仅资源/上限；Duality / Planetarium 规则仍生效。
function M.is_node_navigable(id, ctx)
	ctx = ctx or M.get_hud_context(nil)
	if not M.NODES[id] then
		return false
	end
	if ctx.no_hud_seed then
		return false
	end
	local node = M.NODES[id]
	local group = node.group
	if (group == "stats" or group == "deal") and not ctx.found_hud then
		return false
	end
	if id == "angel" and M.has_duality() then
		return false
	end
	if id == "planetarium" then
		return M.planetarium_hud_available()
	end
	return true
end

local function raw_neighbor(id, direction, ctx)
	local idx, nav_rows = nav_index_of(id, ctx)
	if not idx then return nil end
	local r, c = idx.row, idx.col
	local nrows = #nav_rows
	if direction == "right" then
		local row = nav_rows[r]
		if c < #row then
			return row[c + 1]
		end
		local nr = (r % nrows) + 1
		return nav_rows[nr][1]
	elseif direction == "left" then
		if c > 1 then
			return nav_rows[r][c - 1]
		end
		local pr = r - 1
		if pr < 1 then pr = nrows end
		local prow = nav_rows[pr]
		return prow[#prow]
	elseif direction == "down" then
		local nr = (r % nrows) + 1
		local nrow = nav_rows[nr]
		return nrow[math.min(c, #nrow)]
	elseif direction == "up" then
		local pr = r - 1
		if pr < 1 then pr = nrows end
		local prow = nav_rows[pr]
		return prow[math.min(c, #prow)]
	end
	return nil
end

function M.neighbor(id, direction, ctx)
	ctx = ctx or M.get_hud_context(nil)
	local start = id
	local cur = id
	for _ = 1, 48 do
		cur = raw_neighbor(cur, direction, ctx)
		if not cur then
			return nil
		end
		if M.is_node_navigable(cur, ctx) then
			return cur
		end
		if cur == start then
			return M.is_node_navigable(start, ctx) and start or nil
		end
	end
	return nil
end

function M.default_node_id(ctx)
	ctx = ctx or M.get_hud_context(nil)
	if ctx.found_hud then
		return "damage"
	end
	return "coins"
end

--- 恢复上次节点；失效时按区域 fallback，不做几何猜点。
function M.resolve_start_node(last_node, player, ctx)
	ctx = ctx or M.get_hud_context(player)
	if ctx.no_hud_seed then
		return nil
	end
	if last_node and M.is_node_navigable(last_node, ctx) then
		return last_node
	end
	if last_node then
		local node = M.NODES[last_node]
		local group = node and node.group
		if group == "stats" or group == "deal" then
			if not ctx.found_hud then
				return "coins"
			end
			local fallback = M.neighbor(last_node, "up", ctx)
				or M.neighbor(last_node, "down", ctx)
			if fallback and M.is_node_navigable(fallback, ctx) then
				return fallback
			end
			return "damage"
		end
		if group == "resource_cap" then
			local map = {
				max_coins = "coins",
				max_bombs = "bombs",
				max_keys = "keys",
			}
			local res = map[last_node]
			if res and M.is_node_navigable(res, ctx) then
				return res
			end
		end
		if group == "resource" and M.is_node_navigable(last_node, ctx) then
			return last_node
		end
	end
	return M.default_node_id(ctx)
end

function M.list_ids()
	return M.NODE_IDS
end

--- Devil/Angel：无效 Deal 楼层禁止改；Duality 下 Angel 不可用；Planetarium：未显示于原生 HUD 时禁止。
local function node_action_available(node)
	if node.id == "angel" and M.has_duality() then
		return false
	end
	if node.id == "devil" or node.id == "angel" then
		local elig = deal_chance_semantics.get_found_hud_eligibility()
		return elig.found_hud_eligible == true
	end
	if node.id == "planetarium" then
		return M.planetarium_hud_available()
	end
	return true
end

function M.try_extract(player, node_id, ctx)
	ctx = ctx or {}
	local node = M.NODES[node_id]
	if not node then return {ok = false, reason = "missing"} end
	if node.locked or not node.enabled then
		return {ok = false, reason = "locked"}
	end
	if not node_action_available(node) then
		return {ok = false, reason = "unavailable"}
	end
	local caps = ctx.caps or M.empty_caps()
	local angel_plan = nil
	if node.id == "angel" then
		angel_plan = angel_reshape.find_angel_target(-1, ctx.angel_reshape_opts or {})
		if angel_plan.kind == "blocked" then
			return {ok = false, reason = "cannot"}
		end
	elseif not node.can_extract(player, ctx.modifiers, caps, ctx) then
		return {ok = false, reason = "cannot"}
	end
	local gained, cache_tag = node.extract(player, ctx.modifiers, caps)
	gained = gained or 0
	return {
		ok = true,
		essence_kind = node.essence_kind,
		essence_delta = gained,
		spirit_delta = gained, -- 兼容旧探针字段
		node = node,
		cache_tag = cache_tag,
		needs_stat_cache = node.kind == "persistent",
		needs_cap_cache = node.kind == "shared_cap",
		deal_semantic = node.semantic,
		retune_keep = node.retune_keep,
		needs_split_retune = node.needs_split_retune == true,
		angel_plan = angel_plan,
	}
end

function M.try_inject(player, node_id, ctx)
	ctx = ctx or {}
	local node = M.NODES[node_id]
	if not node then return {ok = false, reason = "missing"} end
	if node.locked or not node.enabled then
		return {ok = false, reason = "locked"}
	end
	if not node_action_available(node) then
		return {ok = false, reason = "unavailable"}
	end
	local caps = ctx.caps or M.empty_caps()
	local angel_plan = nil
	if node.id == "angel" then
		angel_plan = angel_reshape.find_angel_target(1, ctx.angel_reshape_opts or {})
		if angel_plan.kind == "blocked" then
			return {ok = false, reason = "cannot"}
		end
	elseif not node.can_inject(player, ctx.modifiers, ctx.essence, caps, ctx) then
		return {ok = false, reason = "cannot"}
	end
	local spent, cache_tag = node.inject(player, ctx.modifiers, caps)
	spent = spent or 0
	return {
		ok = true,
		essence_kind = node.essence_kind,
		essence_delta = -spent,
		spirit_delta = -spent,
		node = node,
		cache_tag = cache_tag,
		needs_stat_cache = node.kind == "persistent",
		needs_cap_cache = node.kind == "shared_cap",
		deal_semantic = node.semantic,
		retune_keep = node.retune_keep,
		needs_split_retune = node.needs_split_retune == true,
		angel_plan = angel_plan,
	}
end

return M

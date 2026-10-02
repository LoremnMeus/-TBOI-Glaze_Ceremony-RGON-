-- 妖刀·逢魔 HUD 字体：Pickup（资源上限）与 Stat（属性/概率列）共用加载点。
-- Probe 与正式 hud_render 必须引用本模块，避免调试字体与上线字体不一致。

local M = {}

M.PICKUP_PATH = "font/pftempestasevencondensed.fnt"
M.STAT_PLAIN_PATH = "font/luamini.fnt"
M.STAT_OUTLINE_PATH = "font/luaminioutlined.fnt"

local pickup
local stat_plain
local stat_outline
local loaded = false

local function safe_load(path)
	local font = Font()
	font:Load(path)
	return font
end

function M.ensure_loaded()
	if loaded then return true end
	pickup = safe_load(M.PICKUP_PATH)
	stat_plain = safe_load(M.STAT_PLAIN_PATH)
	stat_outline = safe_load(M.STAT_OUTLINE_PATH)
	loaded = true
	return true
end

function M.get_pickup()
	M.ensure_loaded()
	return pickup
end

function M.get_stat_plain()
	M.ensure_loaded()
	return stat_plain
end

function M.get_stat_outline()
	M.ensure_loaded()
	return stat_outline
end

function M.get_stat(mode)
	if mode == "plain" then
		return M.get_stat_plain()
	end
	return M.get_stat_outline()
end

local function font_geom(font)
	if not font then
		return {loaded = false, line_height = nil, baseline = nil}
	end
	local ok_loaded = false
	if font.IsLoaded then
		ok_loaded = font:IsLoaded() == true
	end
	local lh, bl = nil, nil
	if font.GetLineHeight then
		lh = font:GetLineHeight()
	end
	if font.GetBaselineHeight then
		bl = font:GetBaselineHeight()
	end
	return {loaded = ok_loaded, line_height = lh, baseline = bl}
end

function M.font_status()
	M.ensure_loaded()
	return {
		pickup = font_geom(pickup),
		stat_plain = font_geom(stat_plain),
		stat_outline = font_geom(stat_outline),
		paths = {
			pickup = M.PICKUP_PATH,
			stat_plain = M.STAT_PLAIN_PATH,
			stat_outline = M.STAT_OUTLINE_PATH,
		},
	}
end

local function draw_with(font, text, x, y, scale, color)
	if not font or text == nil then return end
	scale = scale or 1
	color = color or KColor(1, 1, 1, 1)
	if font.DrawStringScaled then
		font:DrawStringScaled(tostring(text), x, y, scale, scale, color, 0, false)
	elseif font.DrawStringScaledUTF8 then
		font:DrawStringScaledUTF8(tostring(text), x, y, scale, scale, color, 0, false)
	end
end

function M.draw_pickup(text, x, y, color, scale)
	draw_with(M.get_pickup(), text, x, y, scale, color)
end

function M.draw_stat(text, x, y, color, scale, mode)
	draw_with(M.get_stat(mode or M.STAT_FONT_MODE), text, x, y, scale, color)
end

-- Probe 与 Production 共用：禁止两边各自硬编码另一套。
M.STAT_FONT_MODE = "outlined"
M.DEAL_PERCENT_MODE = "one_decimal"

--- 资源当前值宽度跟随对应上限位数，左侧补 0；异常 current>max 时取两者较大位数。
function M.format_resource_value(value, max_value)
	value = math.max(0, math.floor(tonumber(value) or 0))
	max_value = math.max(0, math.floor(tonumber(max_value) or 0))
	local width = math.max(#tostring(value), #tostring(max_value), 1)
	return string.format("%0" .. tostring(width) .. "d", value)
end

--- 资源上限本身按自然位数显示，不补零。
function M.format_resource_cap(max_value)
	max_value = math.max(0, math.floor(tonumber(max_value) or 0))
	return tostring(max_value)
end

--- 正式 HUD 资源对：current（按 max 位数补零）+ "/" + cap（自然位数）。
--- 返回三段，供独立绘制与选中高亮；禁止拼成一次 DrawString。
function M.format_resource_pair(value, max_value)
	return M.format_resource_value(value, max_value), "/", M.format_resource_cap(max_value)
end

--- Pickup 字体字符串宽度（未缩放像素）。无 API 时回退到 condensed 近似。
function M.pickup_width(text)
	local font = M.get_pickup()
	text = tostring(text or "")
	if font and font.GetStringWidth then
		return font:GetStringWidth(text)
	end
	if font and font.GetStringWidthUTF8 then
		return font:GetStringWidthUTF8(text)
	end
	return #text * 6
end

--- Stat / Deal 字体字符串宽度（未缩放像素）。
function M.stat_width(text, mode)
	local font = M.get_stat(mode or M.STAT_FONT_MODE)
	text = tostring(text or "")
	if font and font.GetStringWidth then
		return font:GetStringWidth(text)
	end
	if font and font.GetStringWidthUTF8 then
		return font:GetStringWidthUTF8(text)
	end
	return #text * 6
end

--- 星象：主值=原生 HUD 镜像 cached；后缀=live-cached（含 +0.0%，始终绘制以便核对 delta 链）。
--- @return base_text, delta_text
function M.format_planetarium_cached_delta(view)
	view = view or {}
	local cached = math.max(0, math.min(1, tonumber(view.cached) or 0))
	local delta = tonumber(view.delta) or 0
	local base_text = M.format_percent(cached, M.DEAL_PERCENT_MODE)
	local delta_text = M.format_signed_percent(delta, M.DEAL_PERCENT_MODE)
	return base_text, delta_text
end

--- 共享布局：Probe / 正式 HUD / cap get_anchor / Spirit VFX 同源。
--- base_pos = pair 起点（current 左上角）。
--- opts: gap_before_slash, gap_after_slash, scale
function M.layout_resource_pair(base_pos, value, max_value, opts)
	opts = opts or {}
	local gap_before = tonumber(opts.gap_before_slash) or 1
	local gap_after = tonumber(opts.gap_after_slash) or 1
	local scale = tonumber(opts.scale) or 1
	local current_text, slash_text, cap_text = M.format_resource_pair(value, max_value)
	local x = base_pos.X
	local y = base_pos.Y
	local w_cur = M.pickup_width(current_text) * scale
	local w_slash = M.pickup_width(slash_text) * scale
	local w_cap = M.pickup_width(cap_text) * scale
	local current_pos = Vector(x, y)
	local slash_pos = Vector(x + w_cur + gap_before, y)
	local cap_pos = Vector(slash_pos.X + w_slash + gap_after, y)
	return {
		current_text = current_text,
		slash_text = slash_text,
		cap_text = cap_text,
		current_pos = current_pos,
		slash_pos = slash_pos,
		cap_pos = cap_pos,
		current_width = w_cur,
		slash_width = w_slash,
		cap_width = w_cap,
	}
end

-- Fixed 排版样本（宽度稳定，优先用于对齐）
M.FIXED_STAT_TEXT = {
	speed = "1.00",
	tears = "2.73",
	damage = "3.50",
	range = "6.50",
	shotspeed = "1.00",
	luck = "0.00",
}

M.FIXED_RESOURCE_TEXT = {
	coins = "08",
	bombs = "05",
	keys = "03",
}

-- Probe 用 current/max 样本（含 / 字形与多位数宽度）
M.FIXED_RESOURCE_PAIR_SAMPLES = {
	"8/9",
	"08/99",
	"99/99",
	"99/100",
	"008/100",
	"127/200",
}

M.FIXED_DEAL_TEXT = {
	devil = "33.3%",
	angel = "50.0%",
	planetarium = "1.0%",
}

M.FIXED_CAP_TEXT = {
	max_coins = "99",
	max_bombs = "99",
	max_keys = "99",
}

--- Found HUD 常见显示：Tears = 30/(MaxFireDelay+1)，Range = TearRange/40。
--- 仅作 Live 预览，不作权威公式源。
function M.format_live_stat(player, id)
	if not player then return "--" end
	if id == "speed" then
		return string.format("%.2f", player.MoveSpeed or 0)
	elseif id == "tears" then
		return string.format("%.2f", 30 / ((player.MaxFireDelay or 0) + 1))
	elseif id == "damage" then
		return string.format("%.2f", player.Damage or 0)
	elseif id == "range" then
		return string.format("%.2f", (player.TearRange or 0) / 40)
	elseif id == "shotspeed" then
		return string.format("%.2f", player.ShotSpeed or 0)
	elseif id == "luck" then
		return string.format("%.2f", player.Luck or 0)
	end
	return "--"
end

function M.format_percent(v, mode)
	v = tonumber(v) or 0
	if mode == "integer" then
		return string.format("%d%%", math.floor(v * 100 + 0.5))
	end
	return string.format("%.1f%%", v * 100)
end

function M.format_signed_percent(v, mode)
	v = tonumber(v) or 0
	local pct = v * 100
	if mode == "integer" then
		return string.format("%+.0f%%", pct)
	end
	return string.format("%+.1f%%", pct)
end

--- Found HUD Deal 文案；只格式化，不计算。
--- snapshot 可选；缺省时走 deal_chance_semantics（允许 getter fallback）。
function M.format_live_deal(id, percent_mode, snapshot)
	if not snapshot then
		local deal_semantics = require("Qing_Remaster_scripts.auxiliary.deal_chance_semantics")
		snapshot = deal_semantics.snapshot({allow_getter_fallback = true})
	end
	local display = snapshot and snapshot.display or {}
	local value
	if id == "devil" then
		value = display.devil
	elseif id == "angel" then
		value = display.angel
	elseif id == "planetarium" then
		value = display.planetarium
	else
		return "--"
	end
	return M.format_percent(value or 0, percent_mode or M.DEAL_PERCENT_MODE)
end

-- deprecated compatibility：旧 Probe / 调用点；请改用 deal_chance_semantics.snapshot()
function M.get_found_hud_deal_chances()
	local deal_semantics = require("Qing_Remaster_scripts.auxiliary.deal_chance_semantics")
	local snap = deal_semantics.snapshot({allow_getter_fallback = true})
	return {
		devil = snap.display.devil,
		angel = snap.display.angel,
		planetarium = snap.display.planetarium,
		total_deal = snap.internal.modified_total,
		total_deal_display = snap.display.total,
		devil_share = snap.split.devil_share,
		angel_share = snap.split.angel_share,
		source = snap.internal.source,
		found_hud_eligible = snap.eligibility.found_hud_eligible,
		eligibility_reason = snap.eligibility.reason,
	}
end

return M

local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local MAX_SLOTS = 4

local item = {
	ToCall = {},
	torsion_info = {},
	MAX_SLOTS = MAX_SLOTS,
}

local function count_active()
	local n = 0
	for i = 1, MAX_SLOTS do
		if item.torsion_info[i] then n = n + 1 end
	end
	return n
end

local function make_peak_envelope(peak, total, hold)
	peak = peak or 0.06
	total = total or 55
	hold = hold or 4
	return function(info)
		local c = info.counter or 0
		if c <= hold then return peak end
		local u = math.min(1, (c - hold) / math.max(1, total - hold))
		local e = 1 - u
		return peak * (e * e)
	end
end

local function resolve_slide(info)
	if info.slide ~= nil then
		return math.max(0, tonumber(auxi.check_if_any(info.slide, info)) or 0)
	end
	if info.peak ~= nil and info.alpha == nil then
		return make_peak_envelope(info.peak, info.total, info.hold)(info)
	end
	local a = tonumber(auxi.check_if_any(info.alpha, info)) or 0
	local step = tonumber(info.step) or 0.01
	return math.max(0, math.min(0.14, math.abs(a) * step * 0.35))
end

local function resolve_stretch(info, slide)
	if info.stretch ~= nil then
		local s = tonumber(auxi.check_if_any(info.stretch, info))
		if s ~= nil then return math.max(0, s) end
	end
	local ratio = tonumber(info.stretch_ratio) or 0.65
	return math.max(0, slide * ratio)
end

local function mirror_uv(u, v)
	if not Game():GetRoom():IsMirrorWorld() then return u, v end
	local m = auxi.check_screen_multi(Vector(1, 1)) * 256
	local size = auxi.GetScreenSize()
	local sz = size.X
	while sz > 256 do sz = sz / 2 end
	u = (sz / 256) - u
	return u, v
end

local function screen_to_uv(screen)
	local m = auxi.check_screen_multi(Vector(1, 1)) * 256
	local u = screen.X / m.X
	local v = screen.Y / m.Y
	return mirror_uv(u, v)
end

--- 保证有 from_uv/to_uv（有限线段）；无 from/to 时用长线段近似无限半平面。
local function ensure_segment_uv(params)
	if params.from_uv and params.to_uv then return end
	if params.from and params.to then
		local a, b = params.from, params.to
		if params.world_space then
			a = Isaac.WorldToScreen(a)
			b = Isaac.WorldToScreen(b)
		end
		local u0, v0 = screen_to_uv(a)
		local u1, v1 = screen_to_uv(b)
		params.from_uv = {u0, v0}
		params.to_uv = {u1, v1}
		return
	end
	-- 旧 API：pos+dir → 过点的长线段（≈无限）
	local pos = params.pos or (params.x and Vector(params.x, params.y))
	local dir = params.dir
	if not dir and params.a and params.b then dir = Vector(params.a, params.b) end
	if not pos then
		local size = auxi.GetScreenSize()
		pos = Vector(size.X * 0.5, size.Y * 0.5)
	end
	if not dir or (dir.X == 0 and dir.Y == 0) then
		local ang = (params.angle_deg or 35) * math.pi / 180
		dir = Vector(math.cos(ang), math.sin(ang))
	end
	if dir.Normalized then dir = dir:Normalized() end
	local u, v = screen_to_uv(pos)
	local m = auxi.check_screen_multi(Vector(1, 1)) * 256
	local tu = dir.X / m.X
	local tv = dir.Y / m.Y
	local tlen = math.sqrt(tu * tu + tv * tv)
	if tlen < 1e-8 then tu, tv, tlen = 1, 0, 1 end
	tu, tv = tu / tlen, tv / tlen
	local half = tonumber(params.half_len_uv) or 1.5 -- 很大 ≈ 全屏
	params.from_uv = {u - tu * half, v - tv * half}
	params.to_uv = {u + tu * half, v + tv * half}
end

--- from/to 定有限切开；half_len_uv 可再缩短有效错位段；slide_ang_deg 岔开切向的错位角（0=沿切开线，90=纯法向）。
--- band / band_px：垂直于切开线的作用半宽（超出则无撕裂）；默认很大以兼容旧半平面观感。
function item.Add_torsion(params)
	params = params or {}
	if params.no_overwrite and not params.force and count_active() >= MAX_SLOTS then
		return false
	end

	if params.dir and params.dir.Normalized then
		params.dir = params.dir:Normalized()
		params.a = params.dir.X
		params.b = params.dir.Y
	end
	if params.pos then
		params.x = params.pos.X
		params.y = params.pos.Y
	end

	ensure_segment_uv(params)

	-- 可选：把有效长度缩到 half_len_uv（相对中点）
	local hl = tonumber(params.half_len_uv)
	if hl and hl > 0 and params.from_uv and params.to_uv then
		local fu, fv = params.from_uv[1], params.from_uv[2]
		local tu, tv = params.to_uv[1], params.to_uv[2]
		local cx, cy = (fu + tu) * 0.5, (fv + tv) * 0.5
		local dx, dy = tu - fu, tv - fv
		local len = math.sqrt(dx * dx + dy * dy)
		if len > 1e-8 then
			dx, dy = dx / len, dy / len
			params.from_uv = {cx - dx * hl, cy - dy * hl}
			params.to_uv = {cx + dx * hl, cy + dy * hl}
		end
	end

	if params.band == nil and params.band_px then
		local m = auxi.check_screen_multi(Vector(1, 1)) * 256
		local scale = (m.X + m.Y) * 0.5
		if scale > 1e-6 then
			params.band = math.max(0.0005, tonumber(params.band_px) / scale)
		end
	end

	params.gap = params.gap or 0.00025
	params.soft = params.soft or 0.042
	-- 未指定时接近旧半平面；Anna 等路径应显式收窄
	params.band = tonumber(params.band) or 1.5
	params.total = params.total or 55
	params.hold = params.hold or 4
	params.slide_ang_deg = params.slide_ang_deg or 0
	if params.peak and params.slide == nil and params.alpha == nil then
		params.slide = make_peak_envelope(params.peak, params.total, params.hold)
	end

	table.insert(item.torsion_info, 1, params)
	item.torsion_info[MAX_SLOTS + 1] = nil
	return true
end

function item.Trigger_demo(opts)
	opts = opts or {}
	local size = auxi.GetScreenSize()
	local angle = opts.angle_deg
	if angle == nil then
		angle = 25 + auxi.random_1() * 130
	end
	local rad = angle * math.pi / 180
	local dir = Vector(math.cos(rad), math.sin(rad))
	local mid = Vector(size.X * 0.5, size.Y * 0.5)
	local half_px = opts.seg_half_px or 90
	item.Add_torsion({
		from = mid - dir * half_px,
		to = mid + dir * half_px,
		peak = opts.peak or 0.1,
		stretch = opts.stretch,
		stretch_ratio = opts.stretch_ratio or 0.7,
		gap = opts.gap or 0.00025,
		soft = opts.soft or 0.042,
		band = opts.band,
		band_px = opts.band_px or 70,
		slide_ang_deg = opts.slide_ang_deg or 28,
		total = opts.total or 60,
		hold = opts.hold or 5,
		P3A = opts.P3A or -1,
		force = true,
	})
end

local function empty_dual()
	return {
		P1 = {0, 0, 0, 0.00025},
		P2 = {0, 0, 0, 0},
		P3 = {0, 0, 0, 0.00025},
		P4 = {0, 0, 0, 0},
		P5 = {0.042, 0, 0.042, 0},
		P6 = {1.5, 1.5, 0, 0},
	}
end

local function pack_cut(slot)
	if not slot then
		return 0, 0, 0, 0.00025, 0, 0, 0, 0, 0.042, 0, 1.5, false
	end
	if slot.delay then
		slot.delay = slot.delay - 1
		if slot.delay > 0 then
			return 0, 0, 0, 0.00025, 0, 0, 0, 0, 0.042, 0, 1.5, false
		end
		slot.delay = nil
	end
	slot.counter = (slot.counter or 0) + 1
	local info = auxi.deepCopy(auxi.check_if_any(slot))
	for u, v in pairs(info) do
		info[u] = auxi.check_if_any(v, info)
	end
	ensure_segment_uv(info)
	local slide = resolve_slide(info)
	local stretch = resolve_stretch(info, slide)
	local en = 1
	if (tonumber(info.P3A) or 0) < 0 then en = 2 end
	local gap = math.max(0.00005, tonumber(info.gap) or 0.00025)
	local soft = math.max(0.0001, tonumber(info.soft) or 0.042)
	local band = math.max(soft + gap, tonumber(info.band) or 1.5)
	local ang = (tonumber(info.slide_ang_deg) or 0) * math.pi / 180
	local fu = info.from_uv[1]
	local fv = info.from_uv[2]
	local tu = info.to_uv[1]
	local tv = info.to_uv[2]
	local expired = slot.counter > (slot.total or 55)
	return en, slide, stretch, gap, fu, fv, tu, tv, soft, ang, band, expired
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		item.torsion_info = {}
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function()
		item.torsion_info = {}
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_GET_SHADER_PARAMS,
	params = nil,
	Function = function(_, name)
		local base = 0
		if name == "Qing_Torsion_1" then
			base = 0
		elseif name == "Qing_Torsion_2" then
			base = 2
		else
			return
		end
		if Game():IsPauseMenuOpen() then
			return empty_dual()
		end

		local e1, s1, t1, g1, fu1, fv1, tu1, tv1, soft1, ang1, band1, exp1 = pack_cut(item.torsion_info[base + 1])
		if exp1 then item.torsion_info[base + 1] = nil end
		local e2, s2, t2, g2, fu2, fv2, tu2, tv2, soft2, ang2, band2, exp2 = pack_cut(item.torsion_info[base + 2])
		if exp2 then item.torsion_info[base + 2] = nil end

		if e1 < 0.5 and e2 < 0.5 then
			return empty_dual()
		end

		return {
			P1 = {e1, s1, t1, g1},
			P2 = {fu1, fv1, tu1, tv1},
			P3 = {e2, s2, t2, g2},
			P4 = {fu2, fv2, tu2, tv2},
			P5 = {soft1, ang1, soft2, ang2},
			P6 = {band1, band2, 0, 0},
		}
	end,
})

return item

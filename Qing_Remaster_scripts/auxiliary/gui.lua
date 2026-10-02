local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

--- Canonical font / mod-resource path facility.
--- Custom Font:Load paths must resolve through the live mod root (not hard-coded folder names).
local item = {
	f = nil,
	f2 = nil,
	mod_root = nil,
	font_load_report = {},
}

local FONT_CONFIG = {
	latin = {
		mod = {
			"font/eid9/eid9_9px.fnt",
		},
		vanilla = {
			"font/mplus_10r.fnt",
		},
	},
	cjk = {
		mod = {
			-- Copied from External Item Descriptions (keep EID page filenames).
			"font/eidcn/eid_cn_default.fnt",
		},
		vanilla = {
			"font/cjk/lanapixel.fnt",
			"font/mplus_10r.fnt",
		},
	},
}

local function normalize_root(path)
	path = tostring(path or ""):gsub("\\", "/")
	path = path:gsub("/+", "/")
	if path ~= "" and path:sub(-1) ~= "/" then
		path = path .. "/"
	end
	return path
end

local function normalize_relative(relative_path)
	return tostring(relative_path or "")
		:gsub("\\", "/")
		:gsub("^/+", "")
end

--- Resolve live mod root. Cache success only; never cache nil/false.
function item.get_mod_root()
	if item.mod_root then
		return item.mod_root
	end

	-- 1. RGON: returns this mod's root directory directly.
	if Isaac and Isaac.GetCurrentModPath then
		local ok, path = pcall(function()
			return Isaac.GetCurrentModPath()
		end)
		if ok and type(path) == "string" and path ~= "" then
			item.mod_root = normalize_root(path)
			return item.mod_root
		end
	end

	-- 2. Legacy EID-style require("") path scrape (no hard-coded mod folder names).
	local ok, err = pcall(require, "")
	if not ok and type(err) == "string" then
		local normalized = err:gsub("\\", "/")
		local root = normalized:match("no file '([^']-/mods/[^/]+/)")
		if not root then
			-- Accept forms without trailing slash before ?.lua / ....
			root = normalized:match("no file '([^']-/mods/[^/]+)/")
			if root then
				root = root .. "/"
			end
		end
		if root then
			item.mod_root = normalize_root(root)
			return item.mod_root
		end
	end

	return nil
end

function item.resolve_mod_resource(relative_path)
	local root = item.get_mod_root()
	if not root then
		return nil
	end
	return root .. "resources/" .. normalize_relative(relative_path)
end

--- Load a BMFont from this mod's resources/. Second Load arg "" matches EID GoG compatibility.
--- Returns font or nil, plus a report table (never caches failed Font as success).
function item.load_mod_font(relative_path, opts)
	opts = opts or {}
	relative_path = normalize_relative(relative_path)
	local resolved = item.resolve_mod_resource(relative_path)
	local report = {
		source = "mod",
		relative = relative_path,
		resolved = resolved,
		loaded = false,
		call_ok = false,
		error = nil,
		reason = nil,
		mod_root = item.mod_root,
	}

	if not resolved then
		report.reason = "mod_root_unresolved"
		return nil, report
	end

	local font = Font()
	local ok, err = pcall(function()
		font:Load(resolved, "")
	end)
	report.call_ok = ok == true
	if not ok then
		report.error = tostring(err)
		report.reason = "load_pcall_failed"
		return nil, report
	end

	local loaded = font.IsLoaded and font:IsLoaded() == true
	report.loaded = loaded
	if not loaded then
		report.reason = "not_is_loaded"
		return nil, report
	end

	if opts.missing_character ~= nil and font.SetMissingCharacter then
		pcall(function()
			font:SetMissingCharacter(opts.missing_character)
		end)
	end

	return font, report
end

local function load_vanilla_font(relative_path, opts)
	opts = opts or {}
	relative_path = normalize_relative(relative_path)
	local report = {
		source = "vanilla",
		relative = relative_path,
		resolved = relative_path,
		loaded = false,
		call_ok = false,
		error = nil,
		reason = nil,
		mod_root = item.mod_root,
	}
	local font = Font()
	local ok, err = pcall(function()
		font:Load(relative_path, "")
	end)
	report.call_ok = ok == true
	if not ok then
		report.error = tostring(err)
		report.reason = "load_pcall_failed"
		return nil, report
	end
	local loaded = font.IsLoaded and font:IsLoaded() == true
	report.loaded = loaded
	if not loaded then
		report.reason = "not_is_loaded"
		return nil, report
	end
	if opts.missing_character ~= nil and font.SetMissingCharacter then
		pcall(function()
			font:SetMissingCharacter(opts.missing_character)
		end)
	end
	return font, report
end

local function load_font_slot(slot_name, config)
	local attempts = {}
	for _, rel in ipairs(config.mod or {}) do
		local font, report = item.load_mod_font(rel)
		attempts[#attempts + 1] = report
		if font then
			item.font_load_report[slot_name] = {
				slot = slot_name,
				loaded = true,
				chosen = report,
				attempts = attempts,
				mod_root = item.get_mod_root(),
			}
			return font
		end
	end
	for _, rel in ipairs(config.vanilla or {}) do
		local font, report = load_vanilla_font(rel)
		attempts[#attempts + 1] = report
		if font then
			item.font_load_report[slot_name] = {
				slot = slot_name,
				loaded = true,
				chosen = report,
				attempts = attempts,
				mod_root = item.get_mod_root(),
			}
			return font
		end
	end
	item.font_load_report[slot_name] = {
		slot = slot_name,
		loaded = false,
		chosen = nil,
		attempts = attempts,
		mod_root = item.get_mod_root(),
		reason = "all_candidates_failed",
	}
	return Font()
end

function item.get_font_load_report()
	return {
		mod_root = item.get_mod_root(),
		slots = item.font_load_report,
		f = item.font_load_report.f or item.font_load_report.latin,
		f2 = item.font_load_report.f2 or item.font_load_report.cjk,
	}
end

function item.format_font_load_report()
	local report = item.get_font_load_report()
	local lines = {
		"Mod Root:",
		tostring(report.mod_root or "(unresolved)"),
		"",
	}
	local function append_slot(label, key)
		local slot = item.font_load_report[key]
		lines[#lines + 1] = label .. ":"
		if not slot then
			lines[#lines + 1] = "  (no report)"
			lines[#lines + 1] = ""
			return
		end
		local chosen = slot.chosen
		if chosen then
			lines[#lines + 1] = "  requested: " .. tostring(chosen.relative)
			lines[#lines + 1] = "  resolved:  " .. tostring(chosen.resolved)
			lines[#lines + 1] = "  source:    " .. tostring(chosen.source)
			lines[#lines + 1] = "  loaded=" .. tostring(chosen.loaded)
		else
			lines[#lines + 1] = "  loaded=false"
			lines[#lines + 1] = "  reason=" .. tostring(slot.reason or "?")
			for i, attempt in ipairs(slot.attempts or {}) do
				lines[#lines + 1] = string.format(
					"  try[%d] %s %s loaded=%s (%s)",
					i,
					tostring(attempt.source),
					tostring(attempt.resolved or attempt.relative),
					tostring(attempt.loaded),
					tostring(attempt.reason or "")
				)
			end
		end
		lines[#lines + 1] = ""
	end
	append_slot("f", "f")
	append_slot("f2", "f2")
	return table.concat(lines, "\n")
end

if item.f == nil then
	item.f = load_font_slot("f", FONT_CONFIG.latin)
	item.f2 = load_font_slot("f2", FONT_CONFIG.cjk)
end

item.GetScreenSize = auxi.GetScreenSize
item.GetScreenCenter = auxi.GetScreenCenter

function item.draw_ch(pos,targ,sx,sy,Kcol,has_count_world,font)
	sx = sx or 2
	sy = sy or 2
	Kcol = Kcol or KColor(1,1,1,1)
	targ = targ or ""
	font = font or item.f
	if not has_count_world then pos = Isaac.WorldToScreen(pos) end
	font:DrawStringScaledUTF8(targ,pos.X,pos.Y,sx,sy,Kcol,0,false)
end

-- 屏幕空间探针十字：中心严格落在 pos（与 codex_work/probes/gemini_motion_probe.lua 一致）。
-- 禁止用 draw_ch("+") 或手调字形的 top-left 偏移冒充十字中心。
function item.draw_probe_cross(pos, color, size)
	if not pos or not Isaac.DrawLine then return end
	size = size or 5
	color = color or KColor(1, 1, 1, 1)
	Isaac.DrawLine(pos + Vector(-size, 0), pos + Vector(size, 0), color, color, 1)
	Isaac.DrawLine(pos + Vector(0, -size), pos + Vector(0, size), color, color, 1)
end

function item.draw_ch_with_time_to_move_out(startpos,dir,targ,params)		--sx,sy,R,G,B,A,take_screen_counter,render_on_shader,special,ignore_stop
	targ = targ or ""
	dir = dir or Vector(-5,0)
	startpos = startpos or (ui.GetScreenTopRight() + Vector(0,math.random(math.floor(ui.GetScreenCenter().Y * 0.6))))
	local out_pos = ui.GetScreenBottomRight()
	local tbl = {font = params.font or item.f,R = params.R or 1,G = params.G or 1,B = params.B or 1,A = params.A or 1,targ = targ,pos = startpos,dir = dir,sx = params.sx or 1,sy = params.sy or 1,tsc = params.tsc or true,
		ignore_stop = params.ignore_stop or false,special = params.special,}
	local adder = function(params)
		local Kcol = params.Kcol
		Kcol = KColor(params.R,params.G,params.B,params.A)
		local r_pos = params.pos
		if params.tsc ~= true then r_pos = Isaac.WorldToScreen(r_pos) end 
		params.font:DrawStringScaledUTF8(params.targ,r_pos.X,r_pos.Y,params.sx,params.sy,Kcol,0,false)
		if Game():IsPaused() ~= true or params.ignore_stop then	params.pos = params.pos + params.dir end
		auxi.check_if_any(params.special,params)
		if r_pos.X < -120 or r_pos.Y < -120 or r_pos.X > out_pos.X + 120 or r_pos.Y > out_pos.Y + 120 then return false
		else return true end
	end
	local inser = function(param,item,funct2)
		local ret = item(param)
		if ret then
			delay_buffer.addeffe(function(params)
				funct2(param,item,funct2)
			end,tbl,1,true,params.ros)
		end
	end
	inser(tbl,adder,inser)
end

function item.draw_ch_with_time_to_dispair(startpos,delatapos,targ,delay,params)		--sx,sy,R,G,B,tsc,ros,special,font
	params = params or {}
	targ = targ or ""
	delatapos = delatapos or Vector(0,-50)
	delay = delay or 25
	if delay == 0 then delay = 1 end
	local strlen = delatapos/delay
	for i = 1,delay do
		local tbl = {font = params.font or item.f,R = params.R or 1,G = params.G or 1,B = params.B or 1,targ = targ,pos = startpos + strlen * i,sx = params.sx or 1,sy = params.sy or 1,delay = delay,i = i,tsc = params.tsc or false,special = params.special,}
		delay_buffer.addeffe(function(params)
			local Kcol = params.Kcol
			Kcol = KColor(params.R,params.G,params.B,(params.delay - params.i + 1)/params.delay)
			local pos = params.pos
			if params.tsc ~= true then pos = Isaac.WorldToScreen(pos) end
			params.font:DrawStringScaledUTF8(params.targ,pos.X,pos.Y,params.sx,params.sy,Kcol,0,false)
			auxi.check_if_any(params.special,params)
		end,tbl,i,true,params.ros)
	end
end

function item.draw_ch_dis_pos(startpos,delatapos,targ,t_by_delay,delay,params)
	item.draw_ch_with_time_to_dispair(startpos + Vector(-(#targ)/2,0),delatapos,targ,t_by_delay * (#targ) + delay,params)
end

function item.draw_chs(pos1,pos2,targ,sx,sy,Kcol,cnt)
	local leng = auxi.GetLen(targ)
	if cnt <= 0 then cnt = 5 end
	for i = 0,leng/cnt do 
		item.f:DrawStringScaledUTF8(string.sub(targ,i*cnt + 1,math.min(leng,(i + 1) * cnt)),Isaac.WorldToScreen(pos1 + (pos2 - pos1)/leng * cnt * i).X,Isaac.WorldToScreen(pos1 + (pos2 - pos1)/leng * cnt * i).Y,sx,sy,Kcol,0,false)
	end
end

function item.draw_line(pos1,pos2,targ,cnt)
	local rpos1 = Isaac.WorldToScreen(pos1)
	local rpos2 = Isaac.WorldToScreen(pos2)
	if cnt == nil then
		if targ == "-" then
			cnt = (rpos2 - rpos1):Length() / 8
		end
		if targ == "|" then
			cnt = (rpos2 - rpos1):Length() / 30
		end
	end
	for i = 0,cnt do
		item.f:DrawStringScaledUTF8(targ,Isaac.WorldToScreen(pos1 + (pos2 - pos1)/cnt * i).X,Isaac.WorldToScreen(pos1 + (pos2 - pos1)/cnt * i).Y,2,2,KColor(1,1,1,1),0,false)
	end
end

function item.real_draw_line(pos1,pos2,targ,cnt,sx,sy,Kcol)
	if Kcol == nil then Kcol = KColor(1,1,1,1) end
	if sx == nil or sy == nil then
		if targ == "-" then
			sx = 1
			sy = 1
		elseif targ == "|" then
			sx = 1
			sy = 0.2
		else
			sx = 2
			sy = 2
		end
	end
	local rpos1 = Isaac.WorldToScreen(pos1)
	local rpos2 = Isaac.WorldToScreen(pos2)
	if targ == "-" then 
		rpos1 = rpos1 + (rpos2 - rpos1):Normalized() * 2
		rpos2 = rpos2 + (rpos1 - rpos2):Normalized() * 2
	elseif targ == "|" then
		rpos1 = rpos1 + (rpos2 - rpos1):Normalized() * 2
		rpos2 = rpos2 + (rpos1 - rpos2):Normalized() * 2
	end
	if cnt == nil then
		if targ == "-" then
			cnt = (rpos2 - rpos1):Length() / 4
		end
		if targ == "|" then
			cnt = (rpos2 - rpos1):Length() / 4
		end
	end
	if targ == "-" then
		for i = 0,cnt do
			item.f:DrawStringScaledUTF8(targ,(rpos1 + (rpos2 - rpos1)/cnt * i).X,(rpos1 + (rpos2 - rpos1)/cnt * i).Y,sx,sy,Kcol,0,false)
		end
	elseif targ == "|" then
		for i = 0,cnt do
			item.f:DrawStringScaledUTF8(targ,(rpos1 + (rpos2 - rpos1)/cnt * i).X,(rpos1 + (rpos2 - rpos1)/cnt * i).Y + 8,sx,sy,Kcol,0,false)
		end
	else
		for i = 0,cnt do
			item.f:DrawStringScaledUTF8(targ,(rpos1 + (rpos2 - rpos1)/cnt * i).X,(rpos1 + (rpos2 - rpos1)/cnt * i).Y,sx,sy,Kcol,0,false)
		end
	end
end

function item.draw_formax(pos1,pos2,lin,col)		--绘制一个普通的表格
	if lin <= 0 or col <= 0 then return end
	local dpos = pos2 - pos1
	local w = Vector(dpos.X,0)
	local h = Vector(0,dpos.Y)
	for i = 0,lin do
		item.real_draw_line(pos1 + h/lin * i,pos2 - h/lin * (lin - i),"-")
	end
	for i = 0,col  do
		item.real_draw_line(pos1 + w/col * i,pos2 - w/col * (col - i),"|")
	end
end

function item.general_speak(delatapos,targ,t_by_delay,delay,params)
	params = params or {}
	params.tsc = true
	local startpos = ui.GetScreenBottomLeft() + Vector(20,-50)
	item.draw_ch_with_time_to_dispair(startpos,delatapos,targ,t_by_delay * (#targ) + delay,params)
end

return item
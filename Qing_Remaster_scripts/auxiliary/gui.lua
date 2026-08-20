local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local item = {
	f = nil,
	f2 = nil,
	font_loader = {
		[1] = {
			function(path) return path .. "mods/qing_2787338237/resources/font/eid9/eid9_9px.fnt" end,
			function(path) return path .. "mods/Qing/resources/font/eid9/eid9_9px.fnt" end,
			"../mods/qing_2787338237/resources/font/eid9/eid9_9px.fnt",
			"../mods/Qing/resources/font/eid9/eid9_9px.fnt",
			"font/eid9/eid9_9px.fnt",
			"font/mplus_10r.fnt",
		},
		[2] = {
			function(path) return path .. "mods/qing_2787338237/resources/font/eidcn/eid_default_cn.fnt" end,
			function(path) return path .. "mods/Qing/resources/font/eidcn/eid_default_cn.fnt" end,
			"../mods/qing_2787338237/resources/font/eidcn/eid_default_cn.fnt",
			"../mods/Qing/resources/font/eidcn/eid_default_cn.fnt",
			"font/eidcn/eid_default_cn.fnt",
			"font/mplus_10r.fnt",
		},
	},
}

if item.f == nil then 
	item.f = Font()
	item.f2 = Font()
	local _, err = pcall(require, "")
	local basePathStart
	local modPathEnd
	local modPathStart
	if REPENTOGON then
		if _LUADEBUG then
			_, modPathStart = string.find(err, "no file '", 1)
			modPathEnd, _ = string.find(err, "mods", modPathStart)
		else
			_, basePathStart = string.find(err, "no file '", 1)
			_, modPathStart = string.find(err, "no file '", basePathStart)
			modPathEnd, _ = string.find(err, "mods", modPathStart)
		end
	else
		if os then
			_, modPathStart = string.find(err, "no file '", 1)
			modPathEnd, _ = string.find(err, "mods", modPathStart)
		else
			_, basePathStart = string.find(err, "no file '", 1)
			_, modPathStart = string.find(err, "no file '", basePathStart)
			modPathEnd, _ = string.find(err, "mods", modPathStart)
		end
	end
	local path = string.sub(err, modPathStart + 1, modPathEnd - 1)
	path = string.gsub(path, "\\", "/")
	path = string.gsub(path, "//", "/")
	path = string.gsub(path, ":/", ":\\")
	
	for u,v in pairs(item.font_loader[1]) do
		if not item.f:IsLoaded() then item.f:Load(auxi.check_if_any(v,path)) else end
	end
	for u,v in pairs(item.font_loader[2]) do
		if not item.f2:IsLoaded() then item.f2:Load(auxi.check_if_any(v,path)) end
	end
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
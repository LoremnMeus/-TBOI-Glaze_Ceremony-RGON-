local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local Input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

-- Dialog markup cheatsheet:
--   Existing usage is still valid:
--     Dialog_holder.add_word({data = {"Isaac:", "Hello!"}, header = {sprite_name = "Isaac"}, step_by = true})
--   Lightweight inline tags can be used in any dialog string:
--     "<red>text</red>", "<blue>text</blue>", "<gold>text</gold>", "<green>text</green>"
--     "<purple>text</purple>", "<gray>text</gray>", "<dim>text</dim>", "<qing>text</qing>"
--     "<c=#ffcc66>custom color</c>"
--     "<mark>highlighted text</mark>"       -- REPENTOGON only, draws a small quad behind the text.
--     "<shake>shaky text</shake>"
--     "<wave>wavy text</wave>"
--     "<tag=Note>annotated text</tag>"      -- renders as "[Note] annotated text".
--   Tags may be nested in simple cases, and step-by-step text reveal counts visible characters,
--   not markup bytes. There is no native Font rotation API in RGON/Repentance+; use sprites or
--   low-level custom rendering if true rotated text is ever needed.
local item = {
	ToCall = {},
	myToCall = {},
	word_scale = Vector(1,1),
	own_key = "Dialog_holder_",
	word_list = {},
	all_alpha = 0,
	time_stop = nil,
	header_map = {
		["Isaac"] = "gfx/ui/dialog/Header_Isaac.png",
		["Tecro"] = "gfx/ui/dialog/Header_Tecro.png",
		["Qing"] = "gfx/ui/dialog/Header_Qing.png",
		["WQing"] = "gfx/ui/dialog/Header_WQing.png",
		["WQing?"] = "gfx/ui/dialog/Header_WQing_.png",
		["Anna"] = "gfx/ui/dialog/Header_Anna.png",
		["Floraine"] = "gfx/ui/dialog/Header_Floraine.png",
		["Zennith"] = "gfx/ui/dialog/Header_Zennith.png",
		["Glaze"] = "gfx/ui/dialog/Header_Glaze.png",
		["Glaze_Doctor"] = "gfx/ui/dialog/Header_Glaze_Doctor.png",
	},
	recorder = nil,
	default_rolldown = 14,
	Colorinfo = {
		{frame = 0 * 6,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 6,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 6,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 6,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 6,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 6,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		
		{frame = 6 * 6,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 6,
	},
}

function item.clear_all()
	item.all_alpha = 0
	item.time_stop = nil
	item.word_list = {}
	item.recorder = nil
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.clear_all()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.clear_all()
end,
})

local s = Sprite()
s:Load("gfx/ui/dialog/dialog_box.anm2",true)
s:Play("Idle",true)
s.Scale = Vector(0.5,0.5)
local header = Sprite()
header:Load("gfx/ui/dialog/dialog_box.anm2",true)
header:Play("Header",true)
header.Scale = Vector(0.5,0.5)

function item.start(params)
	params = params or {}
	if params.no_stop ~= true then
		auxi.time_stop(item.own_key)
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local d = player:GetData()
			if d[item.own_key.."ctrl_succ"] then Attribute_holder.try_rewind_attribute(player,"ControlsEnabled",d[item.own_key.."ctrl_succ"]) end
			if d[item.own_key.."vel_succ"] then Attribute_holder.try_rewind_attribute(player,"Velocity",d[item.own_key.."vel_succ"]) end
			d[item.own_key.."ctrl_succ"] = Attribute_holder.try_hold_attribute(player,"ControlsEnabled",false)
			d[item.own_key.."vel_succ"] = Attribute_holder.try_hold_attribute(player,"Velocity",Vector(0,0))
		end
		item.time_stop = true
	end
end

function item.stop()
	auxi.time_free(item.own_key)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		if d[item.own_key.."ctrl_succ"] then Attribute_holder.try_rewind_attribute(player,"ControlsEnabled",d[item.own_key.."ctrl_succ"]) end d[item.own_key.."ctrl_succ"] = nil
		if d[item.own_key.."vel_succ"] then Attribute_holder.try_rewind_attribute(player,"Velocity",d[item.own_key.."vel_succ"]) end d[item.own_key.."vel_succ"] = nil
	end
end

function item.add_word(data,params)
	params = params or {}
	table.insert(item.word_list,data)
end

function item.force_clear()
	for u,v in pairs(item.word_list) do auxi.check_if_any(v.on_erase,v) end
	item.word_list = {}
	item.stop()
end

function item.is_clear()
	if #item.word_list == 0 then return true 
	else return false end
end

function item.remove_word(id)
	id = id or 1
	if item.word_list[id] == nil then return end
	item.recorder = item.word_list[id] 
	auxi.check_if_any(item.word_list[id].on_erase,item.word_list[id])
	table.remove(item.word_list,id) 
	if #item.word_list == 0 then item.stop() end
end

local markup_colors = {
	red = Color(1,0.25,0.25,1),
	blue = Color(0.35,0.65,1,1),
	gold = Color(1,0.78,0.25,1),
	green = Color(0.35,1,0.55,1),
	purple = Color(0.82,0.55,1,1),
	gray = Color(0.55,0.58,0.62,1),
	grey = Color(0.55,0.58,0.62,1),
	dim = Color(0.55,0.58,0.62,0.72),
	qing = Color(0.36,0.84,1,1),
}

local function copy_color(col)
	col = col or Color(1,1,1,1)
	return Color(col.R or 1,col.G or 1,col.B or 1,col.A or 1,col.RO or 0,col.GO or 0,col.BO or 0)
end

local function merge_style(base, add)
	local ret = {}
	for k,v in pairs(base or {}) do ret[k] = v end
	for k,v in pairs(add or {}) do ret[k] = v end
	return ret
end

local function parse_tag(tag)
	tag = tag or ""
	if string.sub(tag,1,1) == "/" then return {close = true} end
	local key,value = string.match(tag,"^([%w_%-]+)%s*=%s*(.+)$")
	key = key or tag
	key = string.lower(key)
	if key == "c" or key == "color" then key = string.lower(value or "") end
	local rr,gg,bb = string.match(key,"^#(%x%x)(%x%x)(%x%x)$")
	if rr then return {color = Color(tonumber(rr,16)/255,tonumber(gg,16)/255,tonumber(bb,16)/255,1),explicit_color = true} end
	if markup_colors[key] then return {color = markup_colors[key],explicit_color = true} end
	if key == "mark" or key == "hl" then return {mark = true} end
	if key == "shake" then return {shake = true} end
	if key == "wave" then return {wave = true} end
	if key == "tag" or key == "note" then return {tag = value or "note",color = markup_colors.gold,explicit_color = true} end
	return nil
end

function item.parse_markup(text,default_color)
	text = tostring(text or "")
	local runs = {}
	local stack = {{color = copy_color(default_color)}}
	local buffer = ""
	local function cur_style() return stack[#stack] or stack[1] end
	local function flush()
		if buffer ~= "" then
			local style = cur_style()
			local run_color = copy_color(style.color)
			if style.explicit_color and default_color then run_color.A = run_color.A * (default_color.A or 1) end
			table.insert(runs,{text = buffer,color = run_color,mark = style.mark,shake = style.shake,wave = style.wave,tag = style.tag})
			buffer = ""
		end
	end
	local i = 1
	while i <= #text do
		local ch = string.sub(text,i,i)
		if ch == "<" then
			local j = string.find(text,">",i + 1,true)
			if j then
				local parsed = parse_tag(string.sub(text,i + 1,j - 1))
				if parsed then
					flush()
					if parsed.close then
						if #stack > 1 then table.remove(stack,#stack) end
					else
						table.insert(stack,merge_style(cur_style(),parsed))
					end
					i = j + 1
				else
					buffer = buffer .. ch
					i = i + 1
				end
			else
				buffer = buffer .. ch
				i = i + 1
			end
		else
			buffer = buffer .. ch
			i = i + 1
		end
	end
	flush()
	return runs
end

function item.get_markup_text_length(text)
	local ret = 0
	for _,run in ipairs(item.parse_markup(text)) do
		ret = ret + auxi.get_string_real_length(run.text or "")
		if run.tag then ret = ret + auxi.get_string_real_length("["..tostring(run.tag).."] ") end
	end
	return ret
end

local function take_visible_chars(text,count)
	if count == nil then return text end
	if count <= 0 then return "" end
	local chars = auxi.spilt_string(text or "")
	local ret = ""
	for i = 1,math.min(count,#chars) do ret = ret .. chars[i] end
	return ret
end

function item.render_line(pos,text,sx,sy,color,visible_count,font)
	sx = sx or 1
	sy = sy or 1
	font = font or gui.f
	local x = pos.X
	local remain = visible_count
	for _,run in ipairs(item.parse_markup(text,color)) do
		local prefix = ""
		if run.tag then prefix = "["..tostring(run.tag).."] " end
		local chunk = prefix .. (run.text or "")
		if remain ~= nil then
			chunk = take_visible_chars(chunk,remain)
			remain = remain - auxi.get_string_real_length(chunk)
		end
		if chunk ~= "" then
			local rpos = Vector(x,pos.Y)
			if run.shake then rpos = rpos + Vector(math.random(-1,1),math.random(-1,1)) end
			if run.wave then rpos = rpos + Vector(0,math.sin((Game():GetFrameCount() + x) / 5) * 1.5) end
			if run.mark and REPENTOGON and Isaac.DrawQuad then
				local width = font:GetStringWidthUTF8(chunk) * sx
				local height = 9 * sy
				Isaac.DrawQuad(rpos + Vector(-2,1),rpos + Vector(width + 2,1),rpos + Vector(-2,height + 3),rpos + Vector(width + 2,height + 3),KColor(1,0.82,0.25,0.65),1)
			end
			font:DrawStringScaledUTF8(chunk,rpos.X,rpos.Y,sx,sy,auxi.Color_2_KColor(run.color),0,false)
			x = x + font:GetStringWidthUTF8(chunk) * sx
		end
		if remain ~= nil and remain <= 0 then break end
	end
end

function item.get_dialog_lines(data)
	if type(data) == "table" then return data end
	if data == nil then return {} end
	return {data}
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	if item.all_alpha > 0.2 then
		local tgpos = auxi.GetScreenCenter()
		local word_info = item.word_list[1] or item.recorder or {data = {},}		--{data = {"泰克罗：","你好！","谢谢！"},header = {sprite_name = "Qing"},}
		local offset = Vector(0,0)
		if word_info.header then 
			offset = Vector(s.Scale.X * 128,0)
			if word_info.right_header then offset = -offset end
		end
		local color = Color(1,1,1,item.all_alpha * (word_info.all_alpha_multi or 1))
		s.Color = color
		s:Render(Vector(tgpos.X - s.Scale.X * 744/2,tgpos.Y * 1.55 - s.Scale.Y * 232/2) + offset,Vector(0,0),Vector(0,0))
		s:Update()
		if word_info.header then 
			if word_info.header.sprite_name then header:ReplaceSpritesheet(3,item.header_map[word_info.header.sprite_name] or word_info.header.sprite_name) header:LoadGraphics() header:Play("Header",true) word_info.header.sprite_name = nil end
			header.Color = color
			if word_info.right_header then header:Render(Vector(tgpos.X + s.Scale.X * (744/2),tgpos.Y * 1.55 - s.Scale.Y * 232/2) + offset,Vector(0,0),Vector(0,0))
			else header:Render(Vector(tgpos.X - s.Scale.X * (744/2 + 256 - 16),tgpos.Y * 1.55 - s.Scale.Y * 232/2) + offset,Vector(0,0),Vector(0,0)) end
			header:Update()
		end
		if word_info.step_by then			--逐字呈现
			local total = word_info.base_counter or 0
			local step_multi = (word_info.step_multi or 4)
			total = total * step_multi
			local set_break = nil
			local delta_y = 0
			for u,v in ipairs(item.get_dialog_lines(word_info.data)) do
				local inner_info = {} local tg = v if type(v) == "table" then tg = (v.word or v[1]) inner_info = v end
				local scaler = inner_info.scaler or word_info.scaler or item.word_scale
				local colorword = inner_info.color or auxi.check_if_any(function(v) if v and type(v) == "table" then return v[u] else return v end end,word_info.color) or word_info.Defaultcolor or color
				if inner_info.colorful then colorword = auxi.table2color(auxi.check_lerp((word_info.base_counter + inner_info.colorful) % item.Colorinfo.total,item.Colorinfo)) end
				local word_length = item.get_markup_text_length(tg) * (inner_info.inner_step_multi or 1)
				local target_length = word_length + (inner_info.line_inside_delay or word_info.line_inside_delay or 10)
				if inner_info.on_finish and math.floor(total/step_multi) == math.floor((target_length - (inner_info.pre_finish_id or 0))/step_multi) then
					auxi.check_if_any(inner_info.on_finish,inner_info.on_finish_params)
				end
				local visible_count = nil
				if total < target_length then visible_count = math.ceil(total/(inner_info.inner_step_multi or 1)) set_break = true 
				else total = math.max(0,total - target_length) end
				local ddy = scaler.Y * (inner_info.roll_down_y or item.default_rolldown)
				item.render_line(Vector(tgpos.X - s.Scale.X * (744/2 - 32),tgpos.Y * 1.55 - s.Scale.Y * 232/2 + s.Scale.Y * 20 + delta_y) + offset,tg,scaler.X,scaler.Y,colorword,visible_count)
				delta_y = delta_y + ddy
				if set_break then 
					item.record_word_info = {scaler = scaler,}
					if visible_count and visible_count < item.get_markup_text_length(tg) then item.record_word_info.rendering = true end
					break 
				end
			end
			if not set_break then word_info.step_by_end = true end
		else
			for u,v in ipairs(item.get_dialog_lines(word_info.data)) do
				local inner_info = {} local tg = v if type(v) == "table" then tg = (v.word or v[1]) inner_info = v end
				local scaler = inner_info.scaler or word_info.scaler or item.word_scale
				local colorword = auxi.check_if_any(function(v) if v and type(v) == "table" then return v[u] else return v end end,word_info.color) or word_info.Defaultcolor or color
				item.render_line(Vector(tgpos.X - s.Scale.X * (744/2 - 32),tgpos.Y * 1.55 - s.Scale.Y * 232/2 + s.Scale.Y * 20 + (u - 1) * 10 * scaler.Y) + offset,tg,scaler.X,scaler.Y,colorword)
			end
		end
	end
end,
})

function item.is_all_nill()
	return Input.IsMouseBtnPressed(0) ~= true and Input.IsMouseBtnPressed(1) ~= true and Input_holder.all_all_nill()
end
--l local q = Isaac.Spawn(996,24037,0,Vector(200,200),Vector(0,0),nil):ToNPC() q:AddEntityFlags(EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_PERSISTENT | EntityFlag.FLAG_CHARM)
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if #item.word_list > 0 then
		item.all_alpha = math.min(1,math.max(item.all_alpha + 0.1,item.all_alpha * 1.3))
		local word_info = item.word_list[1]
		if item.all_alpha > 0.9 then
			word_info.base_counter = (word_info.base_counter or 0) + 1
			if word_info.step_by and not word_info.step_by_end then 
				if item.record_word_info and item.record_word_info.rendering and Game():GetFrameCount() % 2 == 1 then 
					local val = (item.record_word_info.scaler or item.word_scale):Length() / math.sqrt(2) * 0.5
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BEEP,val,0.75,false,0,0) 
				end 
			end
			if word_info.counter and word_info.counter > 0 then
				word_info.counter = word_info.counter - 1
				if word_info.counter <= 0 then item.remove_word() end
			elseif word_info.ignore_nil == nil and item.is_all_nill() then
			elseif word_info.base_counter < (word_info.base_limit or 20) then
			elseif word_info.step_by and not word_info.step_by_end then
			else item.remove_word() end
		end
	else item.all_alpha = math.max(0,math.min(item.all_alpha - 0.1,item.all_alpha * 0.7)) end
end,
})
--l local dialog = require("Qing_Remaster_scripts.others.Dialog_holder") dialog.add_word({data = {"小青：","你好！","谢谢！"},header = {sprite_name = "Qing"},step_by = true,})
--l local dialog = require("Qing_Remaster_scripts.others.Dialog_holder") dialog.add_word({data = {"泰克罗：","你好！","谢谢！"},header = {sprite_name = "Tecro"},step_by = true,})
--l local dialog = require("Qing_Remaster_scripts.others.Dialog_holder") dialog.add_word({data = {"安娜：","可恶！你真的该死啊！！！！","看这个！"},header = {sprite_name = "Anna"},step_by = true,})
--l local dialog = require("Qing_Remaster_scripts.others.Dialog_holder") dialog.add_word({data = {"芙拉：","看棋！"},header = {sprite_name = "Floraine	"},step_by = true,})
--l local dialog = require("Qing_Remaster_scripts.others.Dialog_holder") dialog.add_word({data = {"以撒：","好耶！"},header = {sprite_name = "Isaac"},step_by = true,})
--l local dialog = require("Qing_Remaster_scripts.others.Dialog_holder") dialog.start()
--l local dialog = require("Qing_Remaster_scripts.others.Dialog_holder") dialog.stop()
return item

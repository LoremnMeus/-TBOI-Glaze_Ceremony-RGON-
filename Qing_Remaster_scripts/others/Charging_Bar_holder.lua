local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")

local item = {
	ToCall = {},
	post_ToCall = {},
	id_counter = 10000,
	pos_ = {
		Vector(-8,-35),
		Vector(-16,-24),
		Vector(-18,-11),
	},
	else_pos_ext = Vector(-12,-3),
	to_render = {},
	add_to_render = {},
}

function item.try_get_charge_bar_pos(ent,id,acco_t_p)
	if ent == nil then return -1 end
	if id == nil then return -1 end
	local d = ent:GetData()
	if d.charge_bar_holder_i_list == nil then d.charge_bar_holder_i_list = {} end
	if d.charge_bar_holder_i_list[id] == nil then item.allocate_charge_bar_pos(ent,id) end
	for i = 1,#d.charge_bar_holder_list do
		if d.charge_bar_holder_list[i].id == id then
			local li = math.floor((i-1)/(#item.pos_))
			local ri = (i - 1) % (#item.pos_) + 1
			local ret = item.pos_[ri] + item.else_pos_ext * li
			if acco_t_p then
				ret = (ret - item.pos_[1]) + auxi.mul_t(item.pos_[1],auxi.ProtectVector(ent.SpriteScale))
			end
			return ret
		end
	end
	return -1
end

function item.get_charge_bar_pos(ent,id)
	if ent == nil then return -1 end
	if id == nil then return -1 end
	local d = ent:GetData()
	if d.charge_bar_holder_i_list == nil then d.charge_bar_holder_i_list = {} end
	if d.charge_bar_holder_i_list[id] == nil then return -1 end
	if d.charge_bar_holder_list == nil then d.charge_bar_holder_list = {} end
	for i = 1,#d.charge_bar_holder_list do
		if d.charge_bar_holder_list[i].id == id then
			local li = math.floor((i - 1) / #item.pos_)
			local ri = (i - 1) % #item.pos_ + 1
			return item.pos_[ri] + item.else_pos_ext * li
		end
	end
end

function item.remove_charge_bar(ent,id,skip)
	if ent == nil then return -1 end
	if id == nil then return -1 end
	if not skip then id = id .. "_C_B" end
	local d = ent:GetData()
	if d.charge_bar_holder_i_list == nil then d.charge_bar_holder_i_list = {} end
	if d.charge_bar_holder_i_list[id] == nil then return -1 end
	if d.charge_bar_holder_list == nil then d.charge_bar_holder_list = {} end
	for i = 1,#d.charge_bar_holder_list do
		if d.charge_bar_holder_list[i].id == id then
			d.charge_bar_holder_i_list[id] = nil
			table.remove(d.charge_bar_holder_list,i)
			break
		end
	end
	return 1
end

function item.allocate_charge_bar_pos(ent,id)
	if ent == nil then return -1 end
	if id == nil then return -1 end
	local d = ent:GetData()
	if d.charge_bar_holder_list == nil then d.charge_bar_holder_list = {} end
	if d.charge_bar_holder_i_list == nil then d.charge_bar_holder_i_list = {} end
	if d.charge_bar_holder_i_list[id] == nil then 
		local tab = {id = id,}
		table.insert(d.charge_bar_holder_list,#d.charge_bar_holder_list+1,tab)
		d.charge_bar_holder_i_list[id] = tab
	end
end

function item.render_me(ent,params)
	local room = Game():GetRoom()
	local d = ent:GetData()
	local name1 = (params.name1 or "") .. "_Charge_Bar_buff"
	local name2 = (params.name2 or params.name1 or "") .. "_Charge_Bar"
	local name3 = (params.name3 or params.name2 or params.name1 or "") .. "_C_B"
	local check1 = params.check1 or (function(val) return val > 5 end)
	local check2 = params.check2 or (function(val) return val >= 300 end)
	local check3 = params.check3 or (function(val) return math.ceil(val/3) end)
	local signal1 = params.signal1 or (function() end)
	local loadname = params.loadname or "gfx/effects/chargebar/chargebar_Qing.anm2"
	local init_pos = ent.Position
	if ent:ToPlayer() and params.NoOffset ~= true then init_pos = init_pos + player_offset_holder.GetPlayerOffset(ent:ToPlayer()) if ent:ToPlayer().CanFly then init_pos = init_pos + Vector(0,-6) end end
	init_pos = params.position or init_pos
	local pos = params.offset or item.try_get_charge_bar_pos(ent,name3,true)
	local posoffset = room:WorldToScreenPosition(init_pos) + pos - Game().ScreenShakeOffset
	if (Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT) then
		posoffset = auxi.GetWaterRenderOffset() + room:WorldToScreenPosition(init_pos) + Vector(pos.X,-pos.Y) - Game().ScreenShakeOffset
	end
	
	d[name1] = d[name1] or 0
	if (check1(d[name1],ent)) then
		if d[name2] == nil then 
			d[name2] = Sprite()
			d[name2]:Load(loadname,true)
			d[name2]:Play("Charging",true)
		end
		if check2(d[name1],ent) then
			if d[name2]:IsPlaying("Charging") or d[name2]:IsFinished("Charging") then
				d[name2]:Play("StartCharged",true)
				signal1(ent)
			elseif d[name2]:IsFinished("StartCharged") or d[name2]:IsPlaying("Disappear") or d[name2]:IsFinished("Disappear") then
				d[name2]:Play("Charged",true)
			end
			d[name2.."_Clock"] = d[name2.."_Clock"] or Game():GetFrameCount()
			if d[name2.."_Clock"] ~= Game():GetFrameCount() then d[name2]:Update() d[name2.."_Clock"] = Game():GetFrameCount() end
		else
			local frame = math.max(0, math.floor(tonumber(check3(d[name1],ent)) or 0))
			d[name2]:SetFrame("Charging",frame)
		end
		d[name2]:Render(posoffset,Vector(0,0),Vector(0,0))
	else
		if d[name2] == nil then
			d[name2] = Sprite()
			d[name2]:Load(loadname,true)
			d[name2]:SetFrame("Disappear",8)
		end
		if d[name2]:IsPlaying("Disappear") == false and d[name2]:IsFinished("Disappear") == false then
			d[name2]:Play("Disappear",true)
		end
		if d[name2]:IsPlaying("Disappear") == true then
			d[name2]:Render(posoffset,Vector(0,0),Vector(0,0))
			d[name2.."_Clock"] = d[name2.."_Clock"] or Game():GetFrameCount()
			if d[name2.."_Clock"] ~= Game():GetFrameCount() then d[name2]:Update() d[name2.."_Clock"] = Game():GetFrameCount() end
		else
			item.remove_charge_bar(ent,name3,true)
		end
	end
	return {pos = pos,}
end

return item

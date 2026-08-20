local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Multidimension_holder_",
	Colorinfo = {
		{frame = 0,A = 0,},
		{frame = 11,A = -1,},
		{frame = 22,A = -1,},
		total = 22,
	},
}
--local Multidimension_holder = require("Qing_Remaster_scripts.mimics.Multidimension_holder") Multidimension_holder.RenderMultidimension(ent,{Update = true,})

function item.RenderMultidimension(ent,params)
	if ent:GetData()[item.own_key.."Lock"] then return end
	ent:GetData()[item.own_key.."Lock"] = {}
	params = params or {}
	local cnt = auxi.inner_tick(ent:GetData(),item.own_key.."counter",item.Colorinfo.total,{Update = params.Update,Val = true,WithZero = true,})
	local c1 = auxi.color2table(ent:GetSprite().Color)
	local info = auxi.check_lerp(cnt,item.Colorinfo)
	ent:GetSprite().Color = auxi.table2color(info)
	ent:Render(params.rpos or Isaac.WorldToScreen(ent.Position),Vector(0,0),Vector(0,0))
	ent:GetSprite().Color = auxi.table2color(c1)
	ent:GetData()[item.own_key.."Lock"] = nil
end

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local item = {
	ToCall = {},
	myToCall = {},
	pre_ToCall = {},
	own_key = "Rest_h_",
}

function item.Try_restock(ent)
	local info = {vr = ent.Variant,st = ent.SubType,shopid = ent.ShopItemId,}
	if info.vr == 100 then info.st = 0 end
	local q = Isaac.Spawn(5,info.vr,info.st,ent.Position,Vector(0,0),nil):ToPickup()
	q:Morph(5,info.vr,info.st,true,true,true)
	Attribute_holder.try_hold_and_rewind_attribute(q,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE,30)
	Attribute_holder.try_hold_and_rewind_attribute(q,"Visible",false,30)
	q.Price = ent.Price		--不是很想再去调价格了，就这样吧
	q.ShopItemId = info.shopid
	delay_buffer.addeffe(function(params)
		if params.tg and auxi.check_all_exists(params.tg) then
			local e = Isaac.Spawn(1000,15,2,params.tg.Position,Vector(0,0),nil):ToEffect()
		end
	end,{tg = q,},29)
end

return item
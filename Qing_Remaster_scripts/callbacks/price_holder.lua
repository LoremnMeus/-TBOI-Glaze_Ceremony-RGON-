local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Assemble_holder = require("Qing_Remaster_scripts.others.Assemble_holder")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Price_holder_",
	move_price_basic = {
		["mx_heart"] = true,
		["gd_heart"] = true,
		["sl_heart"] = true,
		["bn_heart"] = true,
	},
}
Assemble_holder.register_on(item.own_key,item,{force = true,})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	d._Data = d._Data or {}
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ and ent.Price ~= 0 then		-- and 
		if d._Data[item.own_key]["set_the_price"] == nil or d._Data[item.own_key]["record_subtype"] ~= ent.SubType then 
			d._Data[item.own_key]["record_subtype"] = ent.SubType
			d._Data[item.own_key]["set_the_price"] = callback_manager.work_with_result("PRE_CHECK_PRICE",function(funct,params,value) if params == nil or params == ent.Variant then return funct(nil,ent,value) end end,ent.Price) or ent.Price
		end
		if ent.Price ~= d._Data[item.own_key]["set_the_price"] then
			ent.AutoUpdatePrice = false
			ent.Price = d._Data[item.own_key]["set_the_price"]
			consistance_holder.try_hold_entity(ent,item.own_key,{ignore_subtype = true,})
		end
	elseif d._Data[item.own_key] then
		ent.AutoUpdatePrice = true
		consistance_holder.try_remove_entity(ent,item.own_key,{ignore_subtype = true,})
	end
end,
})

function item.reset_price(ents)
	local n_pickup = ents or auxi.getothers(nil,5)
	for u,v in pairs(n_pickup) do
		local ent = v:ToPickup()
		local d = ent:GetData()
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ then
			ent.AutoUpdatePrice = true
			d._Data[item.own_key]["set_the_price"] = nil
			consistance_holder.try_hold_entity(ent,item.own_key,{ignore_subtype = true,})
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 5,
Function = function(_,ent)
	item.reset_price()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	item.reset_price()
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_TRINKET, params = nil,
Function = function(_,player,tkid,isgold)
	item.reset_price()
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,cnt)
	item.reset_price()
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_BASIC, params = nil,
Function = function(_,player,changetype,count)
	if item.move_price_basic[changetype] then
		item.reset_price()
	end
end,
})

function item.catch_price_over(ent)
	local d = ent:GetData()
	d._Data = d._Data or {}
	d._Data[item.own_key] = d._Data[item.own_key] or {}
	d._Data[item.own_key]["set_the_price"] = nil
	d._Data[item.own_key]["record_subtype"] = ent.SubType
	consistance_holder.try_hold_entity(ent,item.own_key,{ignore_subtype = true,})
end

function item.try_catch_price(ent,params)
	if not item.have_catched_price(ent) then
		item.catch_price_over(ent)
	end
end

function item.have_catched_price(ent)
	return consistance_holder.try_check_entity(ent,item.own_key)
end

return item
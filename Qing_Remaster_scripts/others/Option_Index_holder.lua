local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	own_key = "Option_Index_holder_",
}

function item.find_a_new_index()
	local ret = 0
	local banned = {}
	local n_entity = Isaac.GetRoomEntities()
	local n_pickups = auxi.getpickups(n_entity,false)
	for u,v in pairs(n_pickups) do
		local pk = v:ToPickup()
		if pk then
			if pk.OptionsPickupIndex then
				banned[pk.OptionsPickupIndex] = true
			end
		end
	end
	for i = 1,1000 do
		if banned[i] ~= true then
			return i
		end
	end
	return ret		--查询失败
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 100,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	-- will_pick_up 只表示动画/队列就绪，不含价格；买不起时不能提前拆掉 OptionsPickupIndex 组
	-- （虚无假眼伴生等商店四选一：碰一下却付不起会导致整组消失）
	if player and auxi.will_pick_up(player,ent) and auxi.can_buy(ent,player) and ent.OptionsPickupIndex ~= 0 then
		local d = ent:GetData()
		if d[item.own_key.."Remove"] then d[item.own_key.."Pick"] = true
		else
			local n_pickups = auxi.getpickups(nil,false)
			for u,v in pairs(n_pickups) do
				local p = v:ToPickup()
				if p and not auxi.check_for_the_same(p,ent) and p.OptionsPickupIndex == ent.OptionsPickupIndex then p:GetData()[item.own_key.."Remove"] = true end
			end
		end
	end
end,
})

return item

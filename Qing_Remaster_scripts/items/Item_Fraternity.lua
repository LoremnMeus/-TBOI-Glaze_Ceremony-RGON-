local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Fraternity,
	familiar = enums.Familiars.Fraternity,
	own_key = "Item_Fraternity_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	ent.PositionOffset = Vector(0,-10)
	ent.DepthOffset = -100
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local n_enemies = auxi.getenemies()
	if Game():GetRoom():GetFrameCount() > 1 then
		local stg,sstg = nil,nil
		for u,v in pairs(n_enemies) do
			if (v.Position - ent.Position):Length() < 40 * s.Scale:Length() then 
				if (stg == nil or ((v.Position - ent.Position):Length() < (stg.Position - ent.Position):Length())) and v:HasEntityFlags(EntityFlag.FLAG_CHARM) ~= true then stg = v	end
				if (sstg == nil or ((v.Position - ent.Position):Length() < (sstg.Position - ent.Position):Length())) and v:HasEntityFlags(EntityFlag.FLAG_CHARM) == true then sstg = v end
			end
		end
		if stg == nil and auxi.check_all_exists(d[item.own_key.."tg"]) ~= true and auxi.check_all_exists(sstg) then stg = sstg end
		if stg and auxi.check_for_the_same(stg,d[item.own_key.."tg"]) ~= true then d[item.own_key.."counter"] = 0 d[item.own_key.."tg"] = stg end
		local tg = player
		if auxi.check_all_exists(d[item.own_key.."tg"]) then 
			--d[item.own_key.."tg"]:AddCharmed(EntityRef(player),2 * 30)
			if d[item.own_key.."tg"]:HasEntityFlags(EntityFlag.FLAG_CHARM) ~= true then
				Attribute_holder.try_hold_and_rewind_attribute(d[item.own_key.."tg"],"EntityFlag_FLAG_CHARM",true,5 * 30,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_CHARM))
			end
			tg = d[item.own_key.."tg"]
		end
		d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
		local dir = (tg.Position + tg.PositionOffset - ent.Position)
		ent.Velocity = dir:Normalized() * math.min(40,dir:Length() * 0.4) * math.min(1,0.2 + d[item.own_key.."counter"]/60)
	end
end,
})

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Dyson_Star,
	familiar = enums.Familiars.Dyson_Star,
	own_key = "Item_Dyson_Star_",
}
--l local item = require("Qing_Remaster_scripts.items.Item_Dyson_Star") item.adder = 10
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cnt > 0 then cnt = cnt * 2 + 2 end
	local d = player:GetData()
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent)
	local s = ent:GetSprite() s.Scale = Vector(1,1) * 0.5 
	s:Play("Idle",true)
	ent:AddToOrbit(item.entity)
	ent.State = 0
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
    ent.OrbitSpeed = -0.05
    ent.OrbitDistance = Vector(40,25)
	local player = auxi.check_spawner_player(ent)
    ent.Velocity = player.Position + ent:GetOrbitPosition(Vector(0,0)) - ent.Position
	local s = ent:GetSprite() s.Scale = Vector(1,1) * 0.5 
	s.Rotation = ent:GetOrbitPosition(Vector(0,0)):GetAngleDegrees() - 90
end,
})

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local How_to_Fly = require("Qing_Remaster_scripts.items.Item_Book_of_How_to_Fly")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local Akeldama_holder = require("Qing_Remaster_scripts.mimics.Akeldama_holder")

local item = {
	ToCall = {},
	entity = enums.Challenges.Dragon_Flight,
	own_key = "Challenges_Dragon_Flight_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		if Game().Challenge == item.entity then
			local player = Game():GetPlayer(0)
			player:AddCollectible(enums.Items.Book_of_How_to_Fly)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	--print(ent.Height)
	--print(ent.FallingAcceleration)
	--print(ent.PositionOffset)
	if Game().Challenge == item.entity and d[How_to_Fly.own_key.."effect"] then
		local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
		ent.Height = auxi.offset2height(player_offset_holder.GetPlayerOffset(player),ent.FallingAcceleration) --ent.Height + auxi.get_limit(auxi.offset2height(player_offset_holder.GetPlayerOffset(player),ent.FallingAcceleration) - ent.Height,50)/50 * 4
		if ent.Height > -10 then 
			d[item.own_key.."effect"] = (d[item.own_key.."effect"] or 10) - 1
			if d[item.own_key.."effect"] > 0 then ent.Height = -10 end
		end
	end
end,
})
--l local q = Isaac.Spawn(2,0,0,Vector(200,200),Vector(0,0),nil):ToTear() q.FallingAcceleration = 0.5
return item
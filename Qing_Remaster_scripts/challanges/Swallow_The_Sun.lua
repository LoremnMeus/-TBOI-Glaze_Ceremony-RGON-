local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local console_holder = require("Qing_Remaster_scripts.others.Console_holder")
local player_anna = require("Qing_Remaster_scripts.player.player_Anna")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Challenges.Swallow_The_Sun,
	remove_type = {
		[2] = true,
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		--[7] = true,
		[8] = true,
		[9] = true,
		[10] = true,
		[11] = true,
		[12] = true,
		[13] = true,
		[14] = true,
		[18] = true,
		[21] = true,
		[22] = true,
		[24] = true,
		[25] = true,
		[26] = true,
		[27] = true,
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else	
		if Game().Challenge == item.entity then 
			local player = Game():GetPlayer(0)
			player:ChangePlayerType(enums.Players.Anna)
			player:AddMaxHearts(-6)
			player:AddBlackHearts(2)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	if Game().Challenge == item.entity then
		local player = Game():GetPlayer(0)
		player:AddBlackHearts(4)
		player:AddKeys(1)
		player:AddBombs(1)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil,
Function = function(_,ent,col,low)
	if Game().Challenge == item.entity then
		local player = col:ToPlayer()
		if player then return false end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_ANNAS_PORTAL_UPDATE, params = nil,
Function = function(_,ent,col,low)
	if Game().Challenge == item.entity then
		if col:IsBoss() then
			local catch = col:GetData()[player_anna.own_key.."Catch"]
			if catch then
				col:TakeDamage(math.max(6, col.MaxHitPoints * 0.012), 0, EntityRef(ent), 0)
			end
			return
		end
		local catch = col:GetData()[player_anna.own_key.."Catch"]
		if catch and catch["rScale"] and catch["rScale"]:Length() < 0.1 then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_VAMP_GULP,1,1,false,0,2)
			col:Remove()
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_ANNAS_PORTAL_COLLISION, params = nil,
Function = function(_,ent,col,val)
	if Game().Challenge == item.entity then
		if col.IsGrid then
			local gent = col:get_grid()
			if item.remove_type[gent:GetType()] then return true end
		end
	end
end,
})

return item

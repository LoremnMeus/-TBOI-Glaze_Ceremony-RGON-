local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")

local modReference
local item = {
	ToCall = {},
	myToCall = {},
	update_filter = nil,
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	save.elses.basis_holder_buffer = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	 if (continue) then
        for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
            local d = player:GetData()
			local idx = d.__Index
			save.elses.basis_holder_buffer[idx] = auxi.get_basic_counter(player)
        end
    end
	item.update_filter = true
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.update_filter = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
    if (item.update_filter) then 
        local d = player:GetData()
		local idx = d.__Index
		local new_tbl = auxi.get_basic_counter(player)
		save.elses.basis_holder_buffer[idx] = save.elses.basis_holder_buffer[idx] or new_tbl
		local succ = false
		for u,v in pairs(new_tbl) do
			if v.counter ~= save.elses.basis_holder_buffer[idx][u].counter then
				callback_manager.work("POST_CHANGE_BASIC",function(funct,params) if params == nil or params == v.name then funct(nil,player,v.name,v.counter - save.elses.basis_holder_buffer[idx][u].counter,new_tbl,save.elses.basis_holder_buffer[idx]) end end)
				succ = true
			end
		end
		if succ then 
			callback_manager.work("POST_CHANGE_ALL_BASIC",function(funct,params) if params == nil or params == v.name then funct(nil,player,new_tbl,save.elses.basis_holder_buffer[idx]) end end) 
			save.elses.basis_holder_buffer[idx] = new_tbl
		end
    end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	if item.should_recharge then
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
            local d = player:GetData()
			local idx = d.__Index
			save.elses.basis_holder_buffer[idx] = auxi.get_basic_counter(player)
        end
		item.update_filter = true
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS,
Function = function(_, colid, rng, player, flags, slot, data)
	item.should_recharge = true
	item.update_filter = nil
end,
})


return item

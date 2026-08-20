local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	own_key = "collectible_holder_",
	update_filter = nil,
	itemList = {},
	collectibles_size = 1,
	trinkets_size = 1,
	trinketList = {},
	trinket_at_hand = {},
}

function item.check_item_list()
	local config = Isaac:GetItemConfig()
	local collectibles = config:GetCollectibles()
	local size = collectibles.Size
	if size >= item.collectibles_size then 
		item.itemList = {}
		item.collectibles_size = size
		for i= 1, size do
			local collectible = config:GetCollectible(i)
			if collectible then
				table.insert(item.itemList,#item.itemList + 1,i)
			end
		end
	end
end
item.check_item_list()

function item.check_trinket_list()
	local config = Isaac:GetItemConfig()
	local trinkets = config:GetTrinkets()
	local size = trinkets.Size
	if size >= item.trinkets_size then 
		item.trinketList = {}
		item.trinkets_size = size
		for i= 1, size do
			local trinket = config:GetTrinket(i)
			if trinket then
				table.insert(item.trinketList,#item.trinketList + 1,i)
			end
		end
	end
end
item.check_trinket_list()

function item.compare_player_data(idx,player)
	if save.elses.collectible_counter[idx] then
		if player:GetCollectibleCount() ~= save.elses.collectible_counter[idx].num then return false end
		for u,v in pairs(save.elses.collectible_counter[idx].list) do
			if player:GetCollectibleNum(u,true) ~= v then return false end
		end
		return true
	end
end

function item.add_queued_data(player,colid,touched)
	local idx = player:GetData().__Index
	save.elses[item.own_key.."record"] = save.elses[item.own_key.."record"] or {}
	table.insert(save.elses[item.own_key.."record"],#save.elses[item.own_key.."record"] + 1,{idx = idx,id = colid,touched = touched,frame = Game():GetFrameCount(),})
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.check_item_list()
	item.check_trinket_list()
	if continue then
	else
		save.elses.collectible_counter = {}
		save.elses.trinket_counter = {}
	end
	save.elses.collectible_counter = save.elses.collectible_counter or {}
	save.elses.trinket_counter = save.elses.trinket_counter or {}
	save.elses.collectible_queue_item = {}
	save.elses.pocket_item_counter = {}
end,
})

--[[
table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = player:GetData().__Index
	if idx == nil then return end
	save.elses.collectible_counter[idx] = {num = player:GetCollectibleCount(),list = {},}
	for u,v in pairs(item.itemList) do
		if player:GetCollectibleNum(v, true) == 0 then save.elses.collectible_counter[idx].list[v] = nil
		else save.elses.collectible_counter[idx].list[v] = player:GetCollectibleNum(v,true) end
	end
end,
})
--]]
--
table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	save.elses.collectible_queue_item = save.elses.collectible_queue_item or {}
	save.elses.collectible_counter = save.elses.collectible_counter or {}
	save.elses.trinket_counter = save.elses.trinket_counter or {}
	if continue then
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
            local d = player:GetData()
			local idx = player:GetData().__Index
            save.elses.collectible_counter[idx] = {num = player:GetCollectibleCount(),list = {},}
			for u,v in pairs(item.itemList) do
				if player:GetCollectibleNum(v, true) == 0 then save.elses.collectible_counter[idx].list[v] = nil
				else save.elses.collectible_counter[idx].list[v] = player:GetCollectibleNum(v, true) end
			end
            save.elses.trinket_counter[idx] = {}
			for u,v in pairs(item.trinketList) do
				if player:GetTrinketMultiplier(v) ~= 0 then save.elses.trinket_counter[idx][v] = player:GetTrinketMultiplier(v)
				else save.elses.trinket_counter[idx][v] = nil end
			end
        end
    end
	--print("Filter Open")
	item.update_filter = true
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.update_filter = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,pickup)
    if (pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE) then
        local d = pickup:GetData()
		d.collectible_last_id = pickup.SubType
    end
end,
})

local function CheckCollectibleChanged(player)
    local d = player:GetData()
	local idx = player:GetData().__Index
    if save.elses.collectible_counter[idx].num ~= player:GetCollectibleCount() then
        return true
    end
	for u,v in pairs(item.itemList) do
        if (save.elses.collectible_counter[idx].list[v] or 0) ~= player:GetCollectibleNum(v, true) then
            return true
        end
    end
    return false
end

local function CheckTrinketChanged(player)
    local d = player:GetData()
	local idx = player:GetData().__Index
	save.elses.trinket_counter[idx] = save.elses.trinket_counter[idx] or {}
	for u,v in pairs(item.trinketList) do
		if player:GetTrinketMultiplier(v) ~= (save.elses.trinket_counter[idx][v] or 0) then return true end
	end
    return false
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local d = player:GetData()
	local idx = d.__Index
    if item.update_filter then 
		if idx == nil then return end
		if not (save.PERSISTENT_PLAYER_DATA[idx] or {}).__META then save.PERSISTENT_PLAYER_DATA[idx].__META = {player = player,Seed = player.InitSeed,Frame = Isaac.GetFrameCount(),PlayerType = player:GetPlayerType(),} end
		if d[save.own_key.."check"] then
			if save.elses.collectible_counter[idx] and item.compare_player_data(idx,player) ~= true then
				save.PERSISTENT_PLAYER_DATA[idx].__META.player = nil
				save.PERSISTENT_PLAYER_DATA[idx].__META.Seed = save.PERSISTENT_PLAYER_DATA[idx].__META.Seeded or save.PERSISTENT_PLAYER_DATA[idx].__META.Seed
				save.add_player(player,"Check")
			else
				save.PERSISTENT_PLAYER_DATA[idx].__META.Seed = player.InitSeed
			end
			d[save.own_key.."check"] = nil
		end
		save.elses.collectible_counter[idx] = save.elses.collectible_counter[idx] or {num = 0,list = {},}
		if ((save.elses.collectible_queue_item[idx] and player:IsItemQueueEmpty()) or (CheckCollectibleChanged(player))) then
			save.elses.collectible_counter[idx].num = player:GetCollectibleCount()
			local queuedItem = save.elses.collectible_queue_item[idx]
			local changed = false
			for u,v in pairs(item.itemList) do
				local curNum = save.elses.collectible_counter[idx].list[v] or 0
				local num = player:GetCollectibleNum(v, true)
				local diff = num - curNum
				if (diff ~= 0) then
					if (diff > 0) then
						local gained = diff
						if queuedItem then
							if (v == queuedItem.Item and queuedItem.Type ~= ItemType.ITEM_TRINKET) then
								callback_manager.work("POST_GAIN_COLLECTIBLE",function(funct,params) if params == nil or params == v then funct(nil,player,v,1,queuedItem.Touched,curNum,false) end end)
								gained = gained - 1
								save.elses.collectible_queue_item[idx] = nil
							end
						elseif save.elses[item.own_key.."record"] and #save.elses[item.own_key.."record"] > 0 then
							for i = #save.elses[item.own_key.."record"],1,-1 do
								local tv = save.elses[item.own_key.."record"][i]
								if math.abs(stv.frame - Game():GetFrameCount()) > 2 then table.remove(save.elses[item.own_key.."record"],i) 
								else
									if tv.idx == idx and tv.id == v then
										callback_manager.work("POST_GAIN_COLLECTIBLE",function(funct,params) if params == nil or params == v then funct(nil,player,v,1,v.touched,curNum,false) end end)
										gained = gained - 1
										if gained <= 0 then break end
									end
								end
							end
						end
						if (gained > 0) then
							callback_manager.work("POST_GAIN_COLLECTIBLE",function(funct,params) if params == nil or params == v then funct(nil,player,v,gained,false,curNum,true) end end)
						end
					else
						callback_manager.work("POST_LOSE_COLLECTIBLE",function(funct,params) if params == nil or params == v then funct(nil,player,v,-diff,curNum) end end)
					end
					callback_manager.work("POST_CHANGE_COLLECTIBLE",function(funct,params) if params == nil or params == v then funct(nil,player,v,diff,curNum) end end)
					save.elses.collectible_counter[idx].list[v] = num
					if num == 0 then save.elses.collectible_counter[idx].list[v] = nil end
					changed = true
				end
			end
			if changed then	callback_manager.work("POST_CHANGE_ALL_COLLECTIBLE",function(funct,params) funct(nil,player) end) end
			
        end
        if (save.elses.collectible_queue_item[idx] and player:IsItemQueueEmpty()) then 
            save.elses.collectible_queue_item[idx] = nil
        end
    end
end,
})

function item.tk_work()
	if item.Tkcnt == nil then
		item.Tkcnt = true
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			item.Do_Update(player)
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = EntityType.ENTITY_PICKUP,
Function = function(_,ent)
	if ent.Variant == 350 then
		table.insert(item.trinket_at_hand,{ID = ent.SubType,})
		if Game():GetRoom():GetFrameCount() == 0 and ent.FrameCount == 0 then item.tk_work() end
    end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
    for i = #(item.trinket_at_hand),1,-1 do
		local v = item.trinket_at_hand[i]
        if v.should_remove then	table.remove(item.trinket_at_hand,i)
        else v.should_remove = true end 
    end
	if Game():GetRoom():GetFrameCount() ~= 0 and item.Tkcnt ~= nil then item.Tkcnt = nil end
end,
})

function item.Do_Update(player)
	if (item.update_filter) then
		local d = player:GetData()
		local idx = player:GetData().__Index
        if (not player:IsItemQueueEmpty()) then
            if (not save.elses.collectible_queue_item[idx]) then
                local queued = player.QueuedItem
				local id = queued.Item.ID
				save.elses.collectible_queue_item[idx] = {Item = id,Type = queued.Item.Type,Touched = queued.Touched,}
				if (queued.Item.Type == ItemType.ITEM_TRINKET) then
					for u,v in pairs(item.trinket_at_hand) do
						if (v.ID == id or v.ID - 32768 == id) then
							callback_manager.work("POST_PICKUP_TRINKET",function(funct,params) if params == nil or params == id then funct(nil,player,id,id > 32768,queued.Touched) end end)
							table.remove(item.trinket_at_hand,u)
							local v = id % 32768
							if player:GetTrinketMultiplier(v) == ((save.elses.trinket_counter[idx] or {})[v] or 0) then
								local num = player:GetTrinketMultiplier(v)
								local diff = auxi.judge_by_trinket(player,id > 32768)
								diff = math.min(diff,num)
								callback_manager.work("POST_LOSE_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,diff,num) end end)
								callback_manager.work("POST_CHANGE_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,-diff,num) end end)
								callback_manager.work("POST_GAIN_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,1,queued.Touched,num - diff,true,id > 32768,diff) end end)
								callback_manager.work("POST_CHANGE_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,diff,num - diff) end end)
							end
							break
						end
					end
				else
					for i,ent in pairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)) do
						local d2 = ent:GetData()
						local idMatches = (d2 and d2.collectible_last_id == id)
						local swapped = ent.FrameCount <= 0
						local taken = (ent.SubType <= 0 and idMatches) or not ent:Exists()
						if (swapped or taken) then
							callback_manager.work("POST_PICKUP_COLLECTIBLE",function(funct,params) if params == nil or params == id then funct(nil,player,id,queued.Touched,ent) end end)
							break
						end
					end
				end
            end
        end
		local queuedItem = save.elses.collectible_queue_item[idx]
		if CheckTrinketChanged(player) then
			local changed = nil
			for u,v in pairs(item.trinketList) do
				if (save.elses.trinket_counter[idx][v] or 0) ~= player:GetTrinketMultiplier(v) then
					local curNum = save.elses.trinket_counter[idx][v] or 0
					local num = player:GetTrinketMultiplier(v)
					local diff = num - curNum
					if (diff ~= 0) then
						if (diff > 0) then
							local gained = diff
							if queuedItem and v == queuedItem.Item % 32768 and queuedItem.Type == ItemType.ITEM_TRINKET then
								callback_manager.work("POST_GAIN_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,1,queuedItem.Touched,curNum,true,queuedItem.Item > 32768,gained) end end)
								gained = 0
								--save.elses.collectible_queue_item[idx] = nil
							end
							if (gained > 0) then
								callback_manager.work("POST_GAIN_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,gained,false,curNum,false) end end)
							end
						else
							callback_manager.work("POST_LOSE_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,-diff,curNum) end end)
						end
						callback_manager.work("POST_CHANGE_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,diff,curNum) end end)
					end
					save.elses.trinket_counter[idx][v] = num
					changed = true
				end
			end
			if changed then	callback_manager.work("POST_CHANGE_ALL_TRINKET",function(funct,params) funct(nil,player) end) end
		end
		if not REPENTOGON and save.elses.pocket_item_counter[idx] ~= nil then
			for u,ent in pairs(save.elses.pocket_item_counter[idx]) do
				if (not ent:Exists() or ent:IsDead()) then
					for i = 0,3 do
						local tg = player:GetCard(i)
						if ent.Variant == 70 then tg = player:GetPill(i) end
						if (tg and tg == ent.SubType) then
							callback_manager.work("POST_PICKUP_POCKET_ITEM",function(funct,params) if params == nil or params == tg then funct(nil,player,ent.Variant,ent.SubType) end end)		--这里不管重复的编号。
							break
						end
					end
				end
			end
			save.elses.pocket_item_counter[idx] = nil
		end
		save.elses[item.own_key.."Pocket_Reminder"] = save.elses[item.own_key.."Pocket_Reminder"] or {}
		save.elses[item.own_key.."Pocket_Reminder"][idx] = save.elses[item.own_key.."Pocket_Reminder"][idx] or {}
		local tbl = {}
		for i = 0,3 do
			local cid = player:GetCard(i)
			if cid > 0 then tbl[cid] = (tbl[cid] or 0) + 1 end
			local pid = player:GetPill(i)
			if pid > 0 then tbl[-pid] = (tbl[-pid] or 0) + 1 end
		end
		if auxi.EqualTable(tbl,save.elses[item.own_key.."Pocket_Reminder"][idx]) ~= true then
			callback_manager.work("POST_CHANGE_POCKET_ITEM",function(funct,params) funct(nil,player,save.elses[item.own_key.."Pocket_Reminder"][idx]) end)
			save.elses[item.own_key.."Pocket_Reminder"][idx] = tbl
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	item.Do_Update(player)
end,
})
--[[
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GET_TELEPORT, params = "door",
Function = function(_,player,tp,data)
	delay_buffer.addeffe(function(params)
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			item.Do_Update(player)
		end
	end,{},6,true)
end,
})
--]]
table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil,
Function = function(_,ent, col, low)
	if REPENTOGON then return end
	if ent.Variant == 300 or ent.Variant == 70 then
		local player = col:ToPlayer()
		if player then
			local d = player:GetData()
			local idx = player:GetData().__Index
			save.elses.pocket_item_counter[idx] = save.elses.pocket_item_counter[idx] or {}
			table.insert(save.elses.pocket_item_counter[idx],ent)
			if player:GetPlayerType() == PlayerType.PLAYER_THESOUL_B then 		--里骨需要特判？
				for playerNum = 1, Game():GetNumPlayers() do
					local t_player = Game():GetPlayer(playerNum - 1)
					if t_player:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN_B then 
						local idx = t_player:GetData().__Index
						save.elses.pocket_item_counter[idx] = save.elses.pocket_item_counter[idx] or {}
						table.insert(save.elses.pocket_item_counter[idx],ent)
					end
				end
			end
		end
		--if Game():GetRoom():GetFrameCount() == 0 and ent.FrameCount == 0 then item.tk_work() end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	if item.should_recharge then
		 for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
            local d = player:GetData()
			local idx = player:GetData().__Index
			save.elses.collectible_counter[idx] = save.elses.collectible_counter[idx] or {num = 0,list = {},}
            save.elses.collectible_counter[idx].num = player:GetCollectibleCount()
			for u,v in pairs(item.itemList) do
				if player:GetCollectibleNum(v, true) == 0 then save.elses.collectible_counter[idx].list[v] = nil
				else save.elses.collectible_counter[idx].list[v] = player:GetCollectibleNum(v, true) end
			end
        end
		item.should_recharge = nil
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

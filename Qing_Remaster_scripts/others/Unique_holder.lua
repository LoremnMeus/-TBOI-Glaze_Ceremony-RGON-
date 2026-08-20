local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local item = {
	ToCall = {},
	myToCall = {},
	pre_ToCall = {},
	own_key = "Uni_h_",
	own_key2 = "Uni_h2_",
	signal_hash_table = {},
}

function item.quest_signal_hash(key)
	return item.signal_hash_table[key]
end

function item.signal_hash(key,val)
	item.signal_hash_table[key] = val
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."Appear2"] = {}
	end
	save.elses[item.own_key.."Appear2"] = save.elses[item.own_key.."Appear2"] or {}
	item.signal_hash_table = {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."Appear2"] = {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	save.elses[item.own_key.."Appear2"] = save.elses[item.own_key.."Appear2"] or {}
	save.elses[item.own_key.."Appear2"][desc.ListIndex] = (save.elses[item.own_key.."Appear2"][desc.ListIndex] or 0) + 1
	item[item.own_key.."shop_item"] = nil
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		player:GetData()[item.own_key.."PICKUP_TIME"] = -100
	end
end,
})

function item.clear_Appear2()
	save.elses[item.own_key.."Appear2"] = {}
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	save.elses[item.own_key.."Appear2"][desc.ListIndex] = 1
end

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 100,
Function = function(_,ent)
	local room = Game():GetRoom()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local d = ent:GetData()
	d[item.own_key.."PICKUP_TIME"] = room:GetFrameCount()
	if room:GetFrameCount() == -1 then
		if room:IsFirstVisit() then
			d.first_appear = true
			consistance_holder.try_hold_entity(ent,item.own_key,{ignore_subtype = true,one_room = true,})
		end
		save.elses[item.own_key.."Appear2"] = save.elses[item.own_key.."Appear2"] or {}
		if (save.elses[item.own_key.."Appear2"][desc.ListIndex] or 1) == 1 then	
			d.first_appear2 = true 
			consistance_holder.try_hold_entity(ent,item.own_key2,{one_room = true,})
		end
	else
		-- 房中途生成（玩家刷基座等）FrameCount != -1，但仍是首次出现。
		-- 引擎不提供「从未登记过」的 API：只能 Consistance miss → 当首次；命中 → 小退/重 INIT。
		-- 不改成「仅 FrameCount==-1」，否则中途生成永远拿不到 first_appear*。
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ then
		else
			d.first_appear = true
			consistance_holder.try_hold_entity(ent,item.own_key,{ignore_subtype = true,})
		end
		local succ = consistance_holder.try_check_entity(ent,item.own_key2)
		local d = ent:GetData()
		if succ then
		else
			d.first_appear2 = true
			consistance_holder.try_hold_entity(ent,item.own_key2)
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil, priority = -100,
Function = function(_,pool,decrease,seed)
	if item[item.own_key.."missing"] then return item[item.own_key.."missing"] or 33 end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		player:GetData()[item.own_key.."PICKUP_TIME"] = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player:GetData().should_evaluate_on_update_once then
			player:EvaluateItems()
			player:GetData().should_evaluate_on_update_once = nil
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_PICKUP_COLLECTIBLE, params = nil,
Function = function(_,player,colid,touched,ent)
	if ent:Exists() then 
		--print(Game():GetRoom():GetFrameCount().." "..ent.SubType.." "..ent.FrameCount)
		local colinfo = Isaac.GetItemConfig():GetCollectible(colid)
		if colinfo.Type == ItemType.ITEM_ACTIVE then player:GetData()[item.own_key.."PICKUP_TIME"] = Game():GetFrameCount() end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if player then
		local d = player:GetData()
		player:GetData()[item.own_key.."PICKUP_TIME"] = nil
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local player = Game():GetPlayer(0)
	local d = player:GetData()
	item.Room_Shift_offset = player.Position - auxi.ProtectVector(d[item.own_key.."RPos"] or player.Position)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local player = Game():GetPlayer(0)
	local d = player:GetData()
	d[item.own_key.."RPos"] = auxi.Vector2Table(player.Position)
end,
})

function item.try_spawn_shop_item()
	if item[item.own_key.."shop_item"] == nil then
		item[item.own_key.."shop_item"] = true
		item.Hold_for_missing(true)
		local q = Isaac.Spawn(5,150,0,Vector(0,0),Vector(0,0),nil)
		item.Hold_for_missing()
		q:Remove()
	end
end

function item.Hold_for_missing(val,id)
	if val then item[item.own_key.."missing"] = id or 33 
	else item[item.own_key.."missing"] = nil end
end
--local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 
--unique_holder.Hold_for_missing(true) 
--unique_holder.Hold_for_missing()

return item
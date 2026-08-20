local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.World_Arc,
	own_key = "Item_World_Arc_",
	start_pos = Vector(0,-50),
	mov_pos = Vector(15,0),
	mov_pos2 = Vector(0,15),
	limit = 100,
	dir_time_limit = 20,
	dirinfo = {
		[1] = {x = -1,spritename = "gfx/ui/math/pre_mark.png",},
		[2] = {x = 10,spritename = "gfx/ui/math/next_mark.png",},
	},
	banished = {
		[628] = true,
	},
}

if true then
	item.Item_list = {}
	local config = Isaac:GetItemConfig()
	local sz = config:GetCollectibles().Size
	for i = 1,sz do
		local col = config:GetCollectible(i)
		if col and (col.Hidden ~= true) and (col.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST) and col.Type ~= ItemType.ITEM_ACTIVE then
			table.insert(item.Item_list,#item.Item_list + 1,i)
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	local d = player:GetData()
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then		--由于提前移除所以不会触发
		local colid = auxi.random_in_table(item.Item_list,rng)
		table.insert(save.elses[item.own_key.."Record"][idx],#save.elses[item.own_key.."Record"][idx] + 1,colid)
		d[item.own_key.."Record"] = d[item.own_key.."Record"] or {}
		table.insert(d[item.own_key.."Record"],#d[item.own_key.."Record"] + 1,colid)
	else
		local idx = d.__Index
		save.elses[item.own_key.."Record"] = save.elses[item.own_key.."Record"] or {}
		save.elses[item.own_key.."Record"][idx] = save.elses[item.own_key.."Record"][idx] or {}
		local mul = 1
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CAR_BATTERY) then mul = mul + 1 end
		for i = 1,mul do
			local colid = auxi.random_in_table(item.Item_list,rng)
			if auxi.should_do_belial(player) then colid = auxi.get_item_from_pool(3,true,rng) end
			table.insert(save.elses[item.own_key.."Record"][idx],#save.elses[item.own_key.."Record"][idx] + 1,colid)
			d[item.own_key.."Record"] = d[item.own_key.."Record"] or {}
			table.insert(d[item.own_key.."Record"],#d[item.own_key.."Record"] + 1,colid)
		end
		Imitate_item_holder.Evaluate_Imitate_Items(player)
		save.elses[item.own_key.."Find"] = save.elses[item.own_key.."Find"] or {}
		local level = Game():GetLevel()
		local rooms = level:GetRooms()
		local dimen = auxi.GetDimension()
		local tgs = {}
		for i = 0, rooms.Size - 1 do
			local targ = rooms:Get(i)
			if targ ~= nil and targ.SafeGridIndex >= 0 and targ.ListIndex >= 0 and dimen == auxi.GetDimension(targ) then
				local desc = level:GetRoomByIdx(targ.SafeGridIndex,-1)
				if desc and desc.Data and desc.Data.Type ~= RoomType.ROOM_ULTRASECRET and desc.ListIndex ~= level:GetCurrentRoomDesc().ListIndex and desc.ListIndex == targ.ListIndex then
					table.insert(tgs,#tgs + 1,desc.ListIndex)
				end
			end
		end
		local sgid = auxi.random_in_table(tgs,rng)
		save.elses[item.own_key.."Find"][sgid] = (save.elses[item.own_key.."Find"][sgid] or 0) + 1
		if auxi.should_spawn_wisp(player) then 
			local colid = auxi.random_in_table(item.Item_list,rng)
			player:AddItemWisp(colid,player.Position,true)
		end
		return {Remove = true,ShowAnim = true,}
	end
	return ret
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	local d = player:GetData()
	local idx = d.__Index
	if save.elses[item.own_key.."Record"] and save.elses[item.own_key.."Record"][idx] then 
		for u,v in pairs(save.elses[item.own_key.."Record"][idx]) do value[v] = (value[v] or 0) + 1 end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."Record"] = nil
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local dimen = auxi.GetDimension()
	local rng = Game():GetPlayer(0):GetCollectibleRNG(item.entity)
	local tgs = {}
	for i = 0, rooms.Size - 1 do
		local targ = rooms:Get(i)
		if targ ~= nil and targ.SafeGridIndex >= 0 and targ.ListIndex >= 0 and dimen == auxi.GetDimension(targ) then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex,-1)
			if desc and desc.Data and desc.Data.Type ~= RoomType.ROOM_ULTRASECRET and desc.ListIndex ~= level:GetCurrentRoomDesc().ListIndex and desc.ListIndex == targ.ListIndex then
				table.insert(tgs,#tgs + 1,desc.ListIndex)
			end
		end
	end
	local tbl = {}
	for u,v in pairs(save.elses[item.own_key.."Find"] or {}) do
		local sgid = auxi.random_in_table(tgs,rng)
		tbl[sgid] = (tbl[sgid] or 0) + v
	end
	save.elses[item.own_key.."Find"] = tbl
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local ctrlid = player.ControllerIndex
	local d = player:GetData()
	local room = Game():GetRoom()
	if #(d[item.own_key.."Record"] or {}) > 0 and player:IsExtraAnimationFinished() then
		local id = d[item.own_key.."Record"][1]
		table.remove(d[item.own_key.."Record"],1)
		player:AnimateCollectible(id,"Pickup","PlayerPickup")
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	local lsid = desc.ListIndex 
	if lsid >= 0 and desc.SafeGridIndex >= 0 then
		if (save.elses[item.own_key.."Find"] or {})[lsid] then
			unique_holder.Hold_for_missing(true) 
			for i = 1,(save.elses[item.own_key.."Find"][lsid] or 0) do 
				local q = Isaac.Spawn(5,100,item.entity,room:FindFreePickupSpawnPosition(room:GetRandomPosition(0),10,true),Vector(0,0),nil):ToPickup()
				auxi.self_morph(q,{5,100,item.entity,})
			end
			unique_holder.Hold_for_missing() 
			save.elses[item.own_key.."Find"][lsid] = nil
		end
	end
end,
})

do
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	temp_hud.register_provider(function(player)
		local idx = player:GetData() and player:GetData().__Index
		if not idx then return end
		local record = save.elses[item.own_key.."Record"]
		local list = record and record[idx]
		if not list then return end
		local counts = {}
		for _,colid in pairs(list) do
			local cid = tonumber(colid)
			if cid and cid > 0 then
				counts[cid] = (counts[cid] or 0) + 1
			end
		end
		return counts
	end,{
		rainbow_cellular = true,
		rainbow_seed = 0.61,
		exclusive = true,
		source_item = item.entity,
	})
end

return item
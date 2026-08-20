local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Book_of_Future,
	goal = 50,
	pools = {[0] = {},[1] = {},[2] = {},[3] = {},[4] = {},},
	q2c = {
		[0] = Color(1,1,1,1),
		[1] = Color(0,1,0.5,1),
		[2] = Color(0,0.5,1,1),
		[3] = Color(0.5,0,1,1),
		[4] = Color(1,0.5,0,1),
	},
	special_pools = {		--记录一些首先删除的道具
		--[ItemPoolType.POOL_TREASURE] = {4,12,52,105,149,169,223,234,245,261,395,581,678,710,711,},		--
		[ItemPoolType.POOL_SHOP] = {232,619,347,716,enums.Items.More_Options___},		--
		[ItemPoolType.POOL_DEVIL] = {114,118,292,360,399,698,706,},		--441/477
		[ItemPoolType.POOL_ANGEL] = {98,108,182,313,331,415,643,691,},		--477
		[ItemPoolType.POOL_SECRET] = {168,489,625,628,636,664,689,723,},		--
		[ItemPoolType.POOL_GREED_DEVIL] = {114,118,292,360,399,698,706,},
		[ItemPoolType.POOL_GREED_ANGEL] = {98,108,182,313,331,415,643,691,},
	},
	pool_decrease = {
		[ItemPoolType.POOL_LIBRARY] = 0.1,
		[ItemPoolType.POOL_GOLDEN_CHEST] = 0.4,
		[ItemPoolType.POOL_RED_CHEST] = 0.4,
		[ItemPoolType.POOL_BEGGAR] = 0.5,
		[ItemPoolType.POOL_DEMON_BEGGAR] = 0.5,
		[ItemPoolType.POOL_CURSE] = 0.5,
		[ItemPoolType.POOL_KEY_MASTER] = 0.5,
		[ItemPoolType.POOL_BATTERY_BUM] = 0.5,
		[ItemPoolType.POOL_MOMS_CHEST] = 0.5,
		[ItemPoolType.POOL_GREED_CURSE] = 0.5,
		[ItemPoolType.POOL_CRANE_GAME] = 0.1,
		[ItemPoolType.POOL_ULTRA_SECRET] = 0.4,
		[ItemPoolType.POOL_BOMB_BUM] = 0.5,
		[ItemPoolType.POOL_OLD_CHEST] = 0.4,
	},
	has_removed = {},
	own_key = "Item_B_o_F",
}

if true then
	local itemConfig = Isaac.GetItemConfig()
	local sz = itemConfig:GetCollectibles().Size
	for id = 1,sz do
		local collectible = itemConfig:GetCollectible(id)
		if (collectible and not collectible.Hidden and not collectible:HasTags(1<<15)) then
			local qual = collectible.Quality
			table.insert(item.pools[qual],#item.pools[qual] + 1,{id = id,})
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	if coltyp == item.entity then
		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			local room = Game():GetRoom()
			for i = 1,2 do
				local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
				q.OptionsPickupIndex = save.elses.Book_of_Future_cnt
			end
			if save.elses.Book_of_Future_fail then
				player:AddBrokenHearts(2)
			end
		else
			local itemConfig = Isaac.GetItemConfig()
			local rng = player:GetCollectibleRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			local room = Game():GetRoom()
			local level = Game():GetLevel()
			local targets = {}
			local cnt = 0
			local qui = 0
			local roomPool = Game():GetItemPool():GetPoolForRoom(Game():GetRoom():GetType(),Game():GetLevel():GetCurrentRoomDesc().SpawnSeed)
			save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
			if item.special_pools[roomPool] then
				for u,v in pairs(item.special_pools[roomPool]) do
					if (save.elses[item.own_key.."counter"][v] or 0) < 0.99 then
						if qui >= item.goal then
							break
						end
						if rng:RandomInt(100) > 30 then
							table.insert(targets,#targets+1,{id = v,})
							cnt = cnt + 1
							qui = qui + itemConfig:GetCollectible(v).Quality
							save.elses[item.own_key.."counter"][v] = 1
						end
					end
				end
			end
			for qi = 4,0,-1 do
				if qui >= item.goal then
					break
				end
				local tg = {}
				for u,v in pairs(item.pools[qi]) do
					table.insert(tg,#tg+1,v.id)
				end
				local tar = auxi.randomTable(tg,rng)
				for u,v in pairs(tar) do
					if (save.elses[item.own_key.."counter"][v] or 0) < 0.99 then
						if qui >= item.goal then
							break
						end
						table.insert(targets,#targets+1,{id = v,})
						qui = qui + itemConfig:GetCollectible(v).Quality
						cnt = cnt + 1
						save.elses[item.own_key.."counter"][v] = 1
					end
				end
			end
			local i_cnt = 0
			local ii_cnt = 0
			local limi = rng:RandomInt(10) + 15
			for u,v in pairs(targets) do
				--Game():GetItemPool():RemoveCollectible(v.id)
				local mx_cnt = math.max(1,math.min(limi,cnt - ii_cnt * limi))
				local pos = player.Position + auxi.MakeVector(360/mx_cnt*i_cnt) * (100 * (ii_cnt * 0.3 + 1))
				
				auxi.spawn_item_dust(player,pos,v.id,item.q2c[itemConfig:GetCollectible(v.id).Quality],Color(0.2,0.2,0.2,0.3,-0.8,-0.8,-0.8))
				i_cnt = i_cnt + 1
				if i_cnt >= limi then
					i_cnt = 0 
					ii_cnt = ii_cnt + 1
				end
				
			end
			if qui < item.goal then
				save.elses.Book_of_Future_fail = true
			end
			local ndx = option_index_holder.find_a_new_index()
			for i = 1,4 do
				local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
				q.OptionsPickupIndex = ndx
			end
			if save.elses.Book_of_Future_fail then
				if qui == 0 then
					player:AddBrokenHearts(4)
				end
				player:AnimateSad()
				ret = false
			end
			if ret then 
				local q = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player)
				q.SpriteScale = Vector(2,2)
			end
			save.elses.Book_of_Future_cnt = ndx
			if auxi.should_spawn_wisp(player,useFlags) then
				local rnd = rng:RandomInt(#targets) + 1
				player:AddItemWisp(targets[rnd].id,player.Position,true)
			end
		end
		return ret
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,colid,count)
	save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
	save.elses[item.own_key.."counter"][colid] = 1
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GET_COLLECTIBLE, params = nil,
Function = function(_,colid,pooltp,decrease,seed)
	if decrease then
		local dc = item.pool_decrease[pooltp] 
		if dc == nil then dc = 1 end
		save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
		save.elses[item.own_key.."counter"][colid] = (save.elses[item.own_key.."counter"][colid] or 0) + dc
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses.Book_of_Future_cnt = 200
		save.elses.Book_of_Future_fail = false
		save.elses[item.own_key.."counter"] = {}
	end
	save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
end,
})

return item
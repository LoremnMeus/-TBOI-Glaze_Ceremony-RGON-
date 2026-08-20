local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Hierophant_r,
	own_key = "Thoth_cd5r_Hie_",
	chance_list = {
		[1] = {weigh = 6,work = function(player,rng,info)
			local cnt = rng:RandomInt(2) + 1
			local room = Game():GetRoom()
			for i = 1,cnt do 
				local q = Isaac.Spawn(5,10,6,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				q:Morph(5,10,6,true,true,true)
			end
		end,},
		[2] = {weigh = 55,work = function(player,rng,info)
			local cnt = 1
			local room = Game():GetRoom()
			local itempool = Game():GetItemPool()
			for i = 1,cnt do 
				local seed = rng:GetSeed()
				local colid = itempool:GetCollectible(3,true,seed)
				rng:Next()
				if colid and colid ~= 0 then
					local q = Isaac.Spawn(5,100,colid,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
					q:Morph(5,100,colid,true,true,true)
				end
			end
		end,},
		[3] = {weigh = 11,work = function(player,rng,info)
			local cnt = 2
			local room = Game():GetRoom()
			local itempool = Game():GetItemPool()
			for i = 1,cnt do 
				local seed = rng:GetSeed()
				local colid = itempool:GetCollectible(3,true,seed)
				rng:Next()
				if colid and colid ~= 0 then
					local q = Isaac.Spawn(5,100,colid,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
					q:Morph(5,100,colid,true,true,true)
				end
			end
		end,},
		[4] = {weigh = 1,work = function(player,rng,info,item)
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."dmgbuff"][idx] = (save.elses[item.own_key.."dmgbuff"][idx] or 0) + 6.66
			player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
			player:GetData().should_evaluate_on_update_once = true
		end,},
		[5] = {weigh = 6,work = function(player,rng,info,item)
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."dmgbuff"][idx] = (save.elses[item.own_key.."dmgbuff"][idx] or 0) + 0.66
			player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
			player:GetData().should_evaluate_on_update_once = true
		end,},
		[6] = {weigh = 1,work = function(player,rng,info,item)
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."speedbuff"][idx] = (save.elses[item.own_key.."speedbuff"][idx] or 0) + 0.66
			player:AddCacheFlags(CacheFlag.CACHE_SPEED)
			player:GetData().should_evaluate_on_update_once = true
		end,},
		[7] = {weigh = 6,work = function(player,rng,info,item)
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."speedbuff"][idx] = (save.elses[item.own_key.."speedbuff"][idx] or 0) + 0.11
			player:AddCacheFlags(CacheFlag.CACHE_SPEED)
			player:GetData().should_evaluate_on_update_once = true
		end,},
		[8] = {weigh = 1,work = function(player,rng,info)
			local cnt = 66
			local room = Game():GetRoom()
			for i = 1,cnt do
				delay_buffer.addeffe(function(params)
					local q = Isaac.Spawn(5,20,1,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
					q:Morph(5,20,1,true,true,true)
				end,{},i)
			end
		end,},
		[9] = {weigh = 6,work = function(player,rng,info)
			local cnt = 6
			local room = Game():GetRoom()
			for i = 1,cnt do
				delay_buffer.addeffe(function(params)
					local q = Isaac.Spawn(5,0,1,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				end,{},i)
			end
		end,},
		[10] = {weigh = 6,work = function(player,rng,info)
			local room = Game():GetRoom()
			local q = Isaac.Spawn(5,300,31,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
			q:Morph(5,300,31,true,true,true)
		end,},
		[11] = {weigh = 1,work = function(player,rng,info)
			if player:HasPlayerForm(PlayerForm.PLAYERFORM_EVIL_ANGEL) == false then
				for i = 1,3 do
					player:AddCollectible(51)
					player:RemoveCollectible(51,nil,nil,false)
				end
			end
		end,},
	},
}

local function reward(player)
	local rng = player:GetCardRNG(item.entity)
	local tbl = auxi.deepCopy(item.chance_list)
	local ret = auxi.random_in_weighed_table(tbl,rng)
	if ret and ret.work then ret.work(player,rng,ret,item) end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."effect3"] = {}
		save.elses[item.own_key.."effect2"] = {}
		save.elses[item.own_key.."dmgbuff"] = {}
		save.elses[item.own_key.."speedbuff"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."effect3"] = save.elses[item.own_key.."effect3"] or {}
	save.elses[item.own_key.."effect2"] = save.elses[item.own_key.."effect2"] or {}
	save.elses[item.own_key.."dmgbuff"] = save.elses[item.own_key.."dmgbuff"] or {}
	save.elses[item.own_key.."speedbuff"] = save.elses[item.own_key.."speedbuff"] or {}
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			save.elses[item.own_key.."dmgbuff"] = save.elses[item.own_key.."dmgbuff"] or {}
			player.Damage = player.Damage + (save.elses[item.own_key.."dmgbuff"][idx] or 0)
		end
		if cacheFlag == CacheFlag.CACHE_SPEED then
			save.elses[item.own_key.."speedbuff"] = save.elses[item.own_key.."speedbuff"] or {}
			player.MoveSpeed = player.MoveSpeed + (save.elses[item.own_key.."speedbuff"][idx] or 0)
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = nil,
Function = function(_,player,collid,cnt,touched)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
	local room = Game():GetRoom()
	if room:GetType() == RoomType.ROOM_ANGEL then
		save.elses[item.own_key.."effect"][idx][collid] = true
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	if save.elses[item.own_key.."effect2"][idx] then
		if player:IsExtraAnimationFinished() then
			local col = nil
			for u,v in pairs((save.elses[item.own_key.."effect"] or {})[idx] or {}) do
				local collid = tonumber(u)
				if collid then
					local cnt = player:GetCollectibleNum(collid,true)
					if cnt > 0 then col = collid break end
				end
			end
			if col then 
				player:AnimateCollectible(col,"LiftItem","PlayerPickup")
				delay_buffer.addeffe(function(params)
					if player:IsHoldingItem() then
						player:AnimateCollectible(col,"HideItem","PlayerPickup")
						player:RemoveCollectible(col)
						reward(player)
						if save.elses[item.own_key.."effect3"][idx] then
							local config = Isaac:GetItemConfig()
							local collectibleinfo = config:GetCollectible(col)
							if collectibleinfo and (collectibleinfo.Tags & ItemConfig.TAG_SUMMONABLE == ItemConfig.TAG_SUMMONABLE) then
								local q = player:AddItemWisp(col,player.Position,true)
								q.HitPoints = 1
							end
						end
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
						local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player)
						local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),player)
					end
				end,{},15)
			else
				save.elses[item.own_key.."effect3"][idx] = nil
				save.elses[item.own_key.."effect2"][idx] = nil
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		save.elses[item.own_key.."effect2"][idx] = true
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then save.elses[item.own_key.."effect3"][idx] = true end
	end
end,
})


return item
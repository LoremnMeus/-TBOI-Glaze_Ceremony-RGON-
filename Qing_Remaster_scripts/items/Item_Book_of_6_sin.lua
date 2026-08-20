local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_myToCall = {},
	post_ToCall = {},
	pre_ToCall = {},
	entity = enums.Items.Book_of_6_sin,
	own_key = "Item_Book_of_6_sin_",
	sins = {
		[46] = 5,
		[47] = 4,
		--[48] = 7,
		[49] = 6,
		[50] = 2,
		[51] = 1,
		[52] = 3,
	},
	sininfos = {
		[1] = function(player,item)
			player:AddCacheFlags(CacheFlag.CACHE_TEARFLAG)
			player:GetData().should_evaluate_on_update_once = true
		end,
		[2] = function(player,item)
			for i = 1,3 do 
				local q = Isaac.Spawn(5,300,0,player.Position,auxi.RoundVector(nil,5),player) 
			end
		end,
		[3] = function(player,item)
			local ndx = option_index_holder.find_a_new_index()
			if auxi.have_player_has_collectible(CollectibleType.COLLECTIBLE_CHAOS) then
			elseif not auxi.should_do_belial(player) then
				adder = true 
				Imitate_item_holder.assign_fake_item(player,CollectibleType.COLLECTIBLE_CHAOS,true)
			end
			local rng = player:GetCollectibleRNG(item.entity)
			local room = Game():GetRoom()
			for i = 1,3 do 
				local pid = 0
				if auxi.should_do_belial(player) then pid = 3 end
				local colid = auxi.get_item_from_pool(pid,true,rng)
				rng:Next()
				local q = Isaac.Spawn(5,100,colid,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
				q.OptionsPickupIndex = ndx
			end
			if adder then Imitate_item_holder.re_assign_fake_item() end
		end,
		[4] = function(player,item)
			local q = Isaac.Spawn(5,300,31,player.Position,auxi.RoundVector(nil,5),player) 
		end,
		[5] = function(player,item)
			local n_entity = auxi.getothers(5)
			for u,v in pairs(n_entity) do
				if v:ToPickup():IsShopItem() then price_holder.try_catch_price(v) end
			end
		end,
		[6] = function(player,item)
			for i = 1,2 do 
				local q = Isaac.Spawn(5,300,78,player.Position,auxi.RoundVector(nil,5),player) 
			end
		end,
	},
}

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		if cacheFlag == CacheFlag.CACHE_TEARFLAG then
			if save.elses[item.own_key.."record"] and save.elses[item.own_key.."record"][idx] and save.elses[item.own_key.."record"][idx][1] then
				player.TearFlags = player.TearFlags | BitSet128(1<<0,0) | BitSet128(1<<1,0)
			end
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player and auxi.has_have_coll(player,item.entity) then
		if flag & DamageFlag.DAMAGE_EXPLOSION == DamageFlag.DAMAGE_EXPLOSION then
			player:SetMinDamageCooldown(cooldown)
			return false
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	if auxi.has_have_coll(player,item.entity) and d[item.own_key.."effect"] and player:IsExtraAnimationFinished() then
		player:AnimateCollectible(item.entity,"UseItem","PlayerPickup")
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2)
		delay_buffer.addeffe(function(params)
			for u,v in pairs((d[item.own_key.."effect"] or {}).list or {}) do
				auxi.check_if_any(item.sininfos[v],player,item)
			end
			d[item.own_key.."effect"] = nil
		end,{},15)
	end
end,
})

table.insert(item.post_myToCall,#item.post_myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local v = val
	if val == -1000 then v = 0 end
	if v >= 0 and auxi.have_player_has_collectible(item.entity) and save.elses[item.own_key.."record"] then
		local succ = false
		for u,v in pairs(save.elses[item.own_key.."record"]) do
			if v[5] then succ = true break end
		end
		if succ then v = v - 1 end
		if v <= 0 then v = -1000 end
		return v
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	if ent:IsShopItem() and auxi.have_player_has_collectible(item.entity) and save.elses[item.own_key.."record"] then
		local succ = false
		for u,v in pairs(save.elses[item.own_key.."record"]) do
			if v[5] then succ = true break end
		end
		if succ then price_holder.try_catch_price(ent) end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,touched)
	save.elses[item.own_key.."Sins"] = save.elses[item.own_key.."Sins"] or {}
	local idx = player:GetData().__Index
	save.elses[item.own_key.."record"] = save.elses[item.own_key.."record"] or {}
	save.elses[item.own_key.."record"][idx] = save.elses[item.own_key.."record"][idx] or {}
	for u,v in pairs(save.elses[item.own_key.."Sins"]) do
		if save.elses[item.own_key.."record"][idx][u] == nil then
			save.elses[item.own_key.."record"][idx][u] = true
			item.do_id(player,u)
		end
	end
end,
})

function item.do_id(player,id)
	local d = player:GetData()
	d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
	d[item.own_key.."effect"].list = d[item.own_key.."effect"].list or {}
	table.insert(d[item.own_key.."effect"].list,#d[item.own_key.."effect"].list + 1,id)
end

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_,ent)
	if item.sins[ent.Type] then 
		local id = item.sins[ent.Type]
		save.elses[item.own_key.."Sins"] = save.elses[item.own_key.."Sins"] or {}
		if save.elses[item.own_key.."Sins"][id] ~= true then
			save.elses[item.own_key.."Sins"][id] = true
			save.elses[item.own_key.."record"] = save.elses[item.own_key.."record"] or {}
			if auxi.have_player_has_collectible(item.entity) then
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					local idx = player:GetData().__Index
					save.elses[item.own_key.."record"][idx] = save.elses[item.own_key.."record"][idx] or {}
					if auxi.has_have_coll(player,item.entity) and save.elses[item.own_key.."record"][idx][id] == nil then 
						save.elses[item.own_key.."record"][idx][id] = true
						item.do_id(player,id)
					end
				end
			end
		end
	end
end,
})

return item
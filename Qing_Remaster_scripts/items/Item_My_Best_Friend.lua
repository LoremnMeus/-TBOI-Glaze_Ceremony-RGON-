local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local item_pool_holder = require("Qing_Remaster_scripts.callbacks.item_pool_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.My_Best_Friend,
	own_key = "Item_My_Best_Friend_",
	chest_item_chance = 0.1,
	random_chests = {
		{Variant = PickupVariant.PICKUP_CHEST, SubType = 0, Weight = 4,},
		{Variant = PickupVariant.PICKUP_LOCKEDCHEST, SubType = 0, Weight = 3,},
		{Variant = PickupVariant.PICKUP_REDCHEST, SubType = 0, Weight = 3,},
		{Variant = PickupVariant.PICKUP_BOMBCHEST, SubType = 0, Weight = 2,},
		{Variant = PickupVariant.PICKUP_SPIKEDCHEST, SubType = 0, Weight = 2,},
		{Variant = PickupVariant.PICKUP_ETERNALCHEST, SubType = 0, Weight = 1,},
		{Variant = PickupVariant.PICKUP_OLDCHEST or 55, SubType = 0, Weight = 1,},
		{Variant = PickupVariant.PICKUP_WOODENCHEST or 56, SubType = 0, Weight = 1,},
		{Variant = PickupVariant.PICKUP_MEGACHEST or 57, SubType = 0, Weight = 0.2,},
	},
	target = {
		[CollectibleType.COLLECTIBLE_CRICKETS_HEAD] = {id = CollectibleType.COLLECTIBLE_CRICKETS_HEAD,weigh = 1,},
		[CollectibleType.COLLECTIBLE_TAMMYS_HEAD] = {id = CollectibleType.COLLECTIBLE_TAMMYS_HEAD,weigh = 2,},
		[CollectibleType.COLLECTIBLE_BOBS_ROTTEN_HEAD] = {id = CollectibleType.COLLECTIBLE_BOBS_ROTTEN_HEAD,weigh = 2,},
		[CollectibleType.COLLECTIBLE_STEVEN] = {id = CollectibleType.COLLECTIBLE_STEVEN,weigh = 2,},
		[CollectibleType.COLLECTIBLE_GUPPYS_HEAD] = {id = CollectibleType.COLLECTIBLE_GUPPYS_HEAD,weigh = 1,},
		[CollectibleType.COLLECTIBLE_ABEL] = {id = CollectibleType.COLLECTIBLE_ABEL,weigh = 2,},
		[CollectibleType.COLLECTIBLE_GOAT_HEAD] = {id = CollectibleType.COLLECTIBLE_GOAT_HEAD,weigh = 1,},
		[CollectibleType.COLLECTIBLE_FATES_REWARD] = {id = CollectibleType.COLLECTIBLE_FATES_REWARD,weigh = 2,},
		[CollectibleType.COLLECTIBLE_HEAD_OF_THE_KEEPER] = {id = CollectibleType.COLLECTIBLE_HEAD_OF_THE_KEEPER,weigh = 2,},
		[CollectibleType.COLLECTIBLE_VOODOO_HEAD] = {id = CollectibleType.COLLECTIBLE_VOODOO_HEAD,weigh = 2,},
		[CollectibleType.COLLECTIBLE_DECAP_ATTACK] = {id = CollectibleType.COLLECTIBLE_DECAP_ATTACK,weigh = 2,},
	},
	pending_golden_friend = {},
}

local friend_titles = {
	[CollectibleType.COLLECTIBLE_CRICKETS_HEAD] = {zh = "小狗朋友",en = "Puppy Friend"},
	[CollectibleType.COLLECTIBLE_TAMMYS_HEAD] = {zh = "塔米朋友",en = "Tammy Friend"},
	[CollectibleType.COLLECTIBLE_BOBS_ROTTEN_HEAD] = {zh = "鲍勃朋友",en = "Bob Friend"},
	[CollectibleType.COLLECTIBLE_STEVEN] = {zh = "史蒂文朋友",en = "Steven Friend"},
	[CollectibleType.COLLECTIBLE_GUPPYS_HEAD] = {zh = "嗝屁猫朋友",en = "Guppy Friend"},
	[CollectibleType.COLLECTIBLE_ABEL] = {zh = "亚伯朋友",en = "Abel Friend"},
	[CollectibleType.COLLECTIBLE_GOAT_HEAD] = {zh = "山羊朋友",en = "Goat Friend"},
	[CollectibleType.COLLECTIBLE_FATES_REWARD] = {zh = "命运朋友",en = "Fate Friend"},
	[CollectibleType.COLLECTIBLE_HEAD_OF_THE_KEEPER] = {zh = "店主朋友",en = "Keeper Friend"},
	[CollectibleType.COLLECTIBLE_VOODOO_HEAD] = {zh = "巫毒朋友",en = "Voodoo Friend"},
	[CollectibleType.COLLECTIBLE_DECAP_ATTACK] = {zh = "断头朋友",en = "Decap Friend"},
}

local function friend_feedback(pos,collectible)
	local poof = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.POOF01,0,pos,Vector.Zero,nil)
	if poof then poof:GetSprite().Color = Color(1,0.65,0.85,0.85,0.25,0.05,0.2) end
	SFXManager():Play(SoundEffect.SOUND_POWERUP1,0.85,0,false,1.08)
	local nearest,best
	for i = 0,Game():GetNumPlayers()-1 do local p=Game():GetPlayer(i) if p:HasCollectible(item.entity) then local dis=(p.Position-pos):Length() if not best or dis<best then nearest,best=p,dis end end end
	if nearest then nearest:AnimateHappy() end
end

local function choose_random_chest(rng)
	local total_weight = 0
	for _,info in ipairs(item.random_chests) do
		total_weight = total_weight + (info.Weight or 1)
	end
	local value = rng:RandomFloat() * total_weight
	for _,info in ipairs(item.random_chests) do
		value = value - (info.Weight or 1)
		if value < 0 then return info end
	end
	return item.random_chests[1]
end

local function get_head_collectible(rng,decrease)
	return item_pool_holder.get_coll_from(item.own_key,decrease,rng,{allow_miss = true,})
end

local function get_chest_loot_rng(pickup)
	local seed = pickup.DropSeed or pickup.InitSeed or 1
	return auxi.seed_rng(seed + item.entity * 101)
end

local function can_replace_chest_loot(pickup)
	return pickup and (pickup.Variant == PickupVariant.PICKUP_CHEST or pickup.Variant == PickupVariant.PICKUP_SPIKEDCHEST)
end

local function get_cached_chest_collectible(pickup)
	if not can_replace_chest_loot(pickup) then return end
	local d = pickup:GetData()
	local collectible_key = item.own_key.."chest_collectible"
	local missed_key = item.own_key.."chest_collectible_missed"
	if d[missed_key] then return end
	if d[collectible_key] then return d[collectible_key] end
	local rng = get_chest_loot_rng(pickup)
	if rng:RandomFloat() >= item.chest_item_chance then
		d[missed_key] = true
		return
	end
	local collectible = get_head_collectible(rng,false)
	if collectible == nil or collectible == 0 then
		d[missed_key] = true
		return
	end
	d[collectible_key] = collectible
	return collectible
end

local function has_fresh_collectible_near(pos,collectible)
	for _,ent in ipairs(Isaac.GetRoomEntities()) do
		if ent.Type == EntityType.ENTITY_PICKUP and ent.Variant == PickupVariant.PICKUP_COLLECTIBLE and ent.SubType == collectible then
			if ent.FrameCount <= 3 and (ent.Position - pos):Length() < 80 then
				return true
			end
		end
	end
end

local function spawn_chest_collectible(pos,collectible,seed)
	local room = Game():GetRoom()
	if has_fresh_collectible_near(pos,collectible) then return end
	local spawn_pos = room:FindFreePickupSpawnPosition(pos,10,true)
	Isaac.Spawn(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE,collectible,spawn_pos,Vector(0,0),nil)
	friend_feedback(spawn_pos,collectible)
end

local function spawn_random_chests(player)
	local room = Game():GetRoom()
	local rng = auxi.rng_for_sake(player:GetCollectibleRNG(item.entity))
	for i = 1,2 do
		local info = choose_random_chest(rng)
		local pos = room:FindFreePickupSpawnPosition(player.Position,10,true)
		local chest = Isaac.Spawn(EntityType.ENTITY_PICKUP,info.Variant,info.SubType,pos,auxi.RoundVector(rng,1,{leg2 = 3,}),player):ToPickup()
		if chest then
			chest:GetData()[item.own_key.."spawned_chest"] = true
		end
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_ITEMPOOL, params = nil,
Function = function(_,name,val)
	val[item.own_key] = {list = auxi.deepCopy(item.target),default = CollectibleType.COLLECTIBLE_STEVEN,}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil,
Function = function(_,pool,decrease,seed)
	if auxi.have_player_has_collectible(item.entity) and pool == ItemPoolType.POOL_GOLDEN_CHEST and Game():GetFrameCount() > 5 then
		local collectible = get_head_collectible(auxi.seed_rng(seed),decrease)
		if collectible and collectible ~= 0 then item.pending_golden_friend[collectible] = Game():GetFrameCount() end
		return collectible
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_COLLECTIBLE,
Function = function(_,pickup)
	local frame = item.pending_golden_friend[pickup.SubType]
	-- 金箱子的物品池选择早于开箱动画完成，不能只保留 3 帧。
	if frame and Game():GetFrameCount() - frame >= 0 and Game():GetFrameCount() - frame <= 90 then
		item.pending_golden_friend[pickup.SubType] = nil
		friend_feedback(pickup.Position,pickup.SubType)
	end
end,
})

if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ADD_COLLECTIBLE, params = item.entity,
Function = function(_,collid,charge,first_time,slot,var_data,player)
	if player then
		spawn_random_chests(player)
	end
end,
})
end

if ModCallbacks.MC_PRE_PICKUP_GET_LOOT_LIST then
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_GET_LOOT_LIST, params = nil,
Function = function(_,pickup,should_advance)
	if not can_replace_chest_loot(pickup) then return end
	if not auxi.have_player_has_collectible(item.entity) then return end
	local collectible = get_cached_chest_collectible(pickup)
	if collectible == nil or collectible == 0 then return end
	item.pending_golden_friend[collectible] = Game():GetFrameCount()
	local loot_list = LootList()
	local rng = get_chest_loot_rng(pickup)
	loot_list:PushEntry(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE,collectible,rng:GetSeed(),rng)
	return loot_list
end,
})
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = EntityType.ENTITY_PICKUP,
Function = function(_,ent)
	local pickup = ent and ent:ToPickup()
	if not can_replace_chest_loot(pickup) then return end
	local d = pickup:GetData()
	local collectible = d[item.own_key.."chest_collectible"]
	if collectible == nil and auxi.have_player_has_collectible(item.entity) then
		collectible = get_cached_chest_collectible(pickup)
	end
	if collectible == nil or collectible == 0 or d[item.own_key.."chest_collectible_spawned"] then return end
	if Game():GetRoom():GetFrameCount() == 0 then return end
	d[item.own_key.."chest_collectible_spawned"] = true
	local pos = pickup.Position
	local seed = pickup.DropSeed or pickup.InitSeed or 1
	delay_buffer.addeffe(function(params)
		spawn_chest_collectible(params.pos,params.collectible,params.seed)
	end,{pos = pos,collectible = collectible,seed = seed,},1)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = "Item",
Function = function(_,player,tp,id,value)
	local title = friend_titles[id]
	if title and player and player:HasCollectible(item.entity) then
		local language = Options and Options.Language or "en"
		value.Name = (language == "zh" or language == "zh_cn") and title.zh or title.en
		value.Description = (language == "zh" or language == "zh_cn") and "找到新朋友了！" or "A new friend!"
		return value
	end
end,
})

return item

local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Dragon_Tooth,
	own_key = "Item_Dragon_Tooth_",
	color_map = {
		{frame = 0,G = 1,B = 1,RO = 0,X = 1,Y = 1,},
		{frame = 5,G = 0,B = 0,RO = 0.5,X = 0.8,Y = 1.2,},
		{frame = 10,G = 0.3,B = 0.3,RO = 0.2,X = 0.8,Y = 0.8,},
		{frame = 20,G = 1,B = 1,RO = 0,X = 1,Y = 1,},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then else save.elses[item.own_key.."counter"] = {} end
	save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	local d = player:GetData()
	if auxi.has_have_coll(player,item.entity) then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage * 1.5 + (save.elses[item.own_key.."counter"].counter or 0)
		end
	end
end,
})

function item.should_trigger()
	if auxi.have_player_has_collectible(item.entity) then
		local cnt = auxi.get_player_have_collectible_num(item.entity)
		if (save.elses[item.own_key.."counter"].counter or 0) < cnt then return true end
	else return false end
end

function item.is_dragon_room()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
	save.elses[item.own_key.."counter"].roomlist = save.elses[item.own_key.."counter"].roomlist or {}
	for u,v in pairs(save.elses[item.own_key.."counter"].roomlist) do
		if desc.ListIndex == v.id then return true end
	end
	return false
end

function item.add_room()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	save.elses[item.own_key.."counter"].roomlist = save.elses[item.own_key.."counter"].roomlist or {}
	table.insert(save.elses[item.own_key.."counter"].roomlist,{id = desc.ListIndex,})
	save.elses[item.own_key.."counter"].counter = (save.elses[item.own_key.."counter"].counter or 0) + 1
	for playerNum = 1, Game():GetNumPlayers() do local player = Game():GetPlayer(playerNum - 1) player:AddCacheFlags(CacheFlag.CACHE_DAMAGE) player:GetData().should_evaluate_on_update_once = true end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."counter"].roomlist = {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	if room:GetType() == RoomType.ROOM_ANGEL then
		if room:IsFirstVisit() and item.should_trigger() then item.add_room() end
		if item.is_dragon_room() then
			for i = 1,10 do 
				local q = Isaac.Spawn(1000,7,0,room:GetRandomPosition(0),Vector(0,0),nil)
			end
		end
	end
	item.start_color = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = 9,
Function = function(_,ent)
	if ent.SubType == 0 and item.is_dragon_room() then
		local room = Game():GetRoom()
		local s = ent:GetSprite()
		s:Load("gfx/mimics/Dragon_Tooth/Dragon_angel_statue.anm2",true) s:Play("Idle",true)
		local q = Isaac.Spawn(1000,17,0,ent.Position,Vector(0,0),nil)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 272,
Function = function(_,ent)
	if ent.SubType == 0 and item.is_dragon_room() then
		ent.HitPoints = ent.HitPoints * 0.1
		ent:AddEntityFlags(EntityFlag.FLAG_BLEED_OUT)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 271,
Function = function(_,ent)
	if ent.SubType == 0 and item.is_dragon_room() then
		ent.HitPoints = ent.HitPoints * 0.1
		ent:AddEntityFlags(EntityFlag.FLAG_BLEED_OUT)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GET_COLLECTIBLE, params = nil,
Function = function(_,colid,pool,decrease,seed)
	if item.is_dragon_room() and pool == ItemPoolType.POOL_ANGEL and item.seted ~= true then
		item.seted = true
		local rng = RNG()
		rng:SetSeed(seed,1)
		ret = auxi.get_item_from_pool(3,decrease,rng)
		item.seted = nil
		if ret then return ret end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GRID_UPDATE, params = 16,
Function = function(_,idx,gent)
	local door = gent:ToDoor()
	if door and auxi.have_player_has_collectible(item.entity) then
		if item.start_color and door.Slot == item.start_color.id then
			local dir = auxi.GetDirVec(door.Direction)
			item.start_color.counter = (item.start_color.counter or 0) + 1
			local info = auxi.check_lerp(item.start_color.counter,item.color_map)
			local scale = auxi.ProtectVector(info)  --auxi.get_by_rotate(auxi.ProtectVector(info),dir:GetAngleDegrees())
			local color = auxi.table2color(info)
			door:GetSprite().Color = color
			door:GetSprite().Scale = scale
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GRID_INIT, params = 16,
Function = function(_,idx,gent)
	local room = Game():GetRoom()
	local door = gent:ToDoor()
	if door and auxi.have_player_has_collectible(item.entity) then
		if door.TargetRoomType == RoomType.ROOM_ANGEL and item.should_trigger() and room:GetFrameCount() > 1 then
			local pos = door.Position
			local dir = - auxi.GetDirVec(door.Direction) * 3
			local doorid = door.Slot
			delay_buffer.addeffe(function(params)
				Game():Darken(1,60)
			end,{},15,{remove_now = true,})
			delay_buffer.addeffe(function(params)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS_GURGLE_ROAR,2,0.8,false,0,2)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_HUSH_ROAR,1,0.8,false,0,2)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_ANGEL_WING,1,0.8,false,0,2)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_ANGEL_WING,1,0.8,false,0,4)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_ANGEL_BEAM,1,1,false,0,4)
			end,{},30,{remove_now = true,})
			delay_buffer.addeffe(function(params)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_DIVINE_INTERVENTION,1,1,false,0,2)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_BURST_LARGE,1,1,false,0,2)
				item.start_color = {counter = 0,id = doorid,}
			end,{},45,{remove_now = true,})
			delay_buffer.addeffe(function(params)
				for i = 1,10 do
					local q = Isaac.Spawn(1000,59,0,pos + auxi.random_v2() * 20,auxi.get_by_rotate(dir,auxi.random_2() * 32,dir:Length() * (1 + auxi.random_2() * 0.3)),nil):ToEffect()
					q.LifeSpan = math.ceil(30 + auxi.random_2() * 5) q.Timeout = math.ceil(20 + auxi.random_1() * 5)
					q:GetSprite().Color = Color(1,0,0,0.4 + auxi.random_2() * 0.3,0.3,0,0)
				end
			end,{},60,{remove_now = true,})
		end
	end
end,
})

--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local pos = Vector(200,200) local dir = Vector(1,0) * 5 for i = 1,5 do local q = Isaac.Spawn(1000,59,0,pos,dir,nil):ToEffect() q.LifeSpan = math.ceil(30 + auxi.random_2() * 5) q.Timeout = math.ceil(20 + auxi.random_1() * 5) q:GetSprite().Color = Color(1,0,0,1,0.3,0,0) end
--l local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker") sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS_GURGLE_ROAR,2,0.8,false,0,2) sound_tracker.PlayStackedSound(SoundEffect.SOUND_HUSH_ROAR,1,0.8,false,0,2) sound_tracker.PlayStackedSound(SoundEffect.SOUND_ANGEL_WING,1,0.8,false,0,2) sound_tracker.PlayStackedSound(SoundEffect.SOUND_ANGEL_BEAM,1,0.8,false,0,4)

return item
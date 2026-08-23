local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local danger_data = require("Qing_Remaster_scripts.others.Danger_Data")

local item = {
	ToCall = {},
	entity = enums.Items.Cloundy,
	familiar = enums.Familiars.Cloundy,
	own_key = "Item_Cloudy_",
	words = {
		zh = {
			[1] = "这个方向一定是隐藏房！",
			[2] = "我知道！这个房间里不可能有隐藏！",
			[3] = "我知道！叉石头会炸出石头底座",
			[4] = "别怂！打了！",
			[5] = "黑小孩，炸掉给基础！",
			[6] = "钥匙小孩，炸掉加开房率！",
			[7] = "卖血机没用，全部炸掉！",
			[8] = "没用，赶快炸了！",
			[9] = "小孩那么可爱，不要炸小孩！",
			[10] = "零元购喽！",
			[11] = "杀掉！必须杀掉！",
			[12] = "我教你一个白嫖陆夫人的技巧！",
			[13] = "roll机炸不坏的，我来帮忙！",
			[14] = "不！我不承认！你是如何找到隐藏房的！",
			[15] = "当当当！挑战降临！",
		},
		en = {
			[1] = "I know!The secret room!",
			[2] = "There can't the secret room here!",
			[3] = "Give me a Rock bottom!",
			[4] = "Take it!",
			[5] = "Blow up the black but!That offers pickups!",
			[6] = "Blow up key master and promote devil rate!",
			[7] = "Useless donate machine!I will bomb it up!",
			[8] = "Invalid slots!Leave it away!",
			[9] = "No!Don't blow up little beggars!",
			[10] = "Feel free to take!",
			[11] = "Kill it!We must kill it!",
			[12] = "I'm good at blow up bomb beggars!",
			[13] = "Rolling machine can't be blowed up!",
			[14] = "No!How do you find the secret room!",
			[15] = "Challenge comes！",
		},
	},
	Talking_Pos_Offset = Vector(20,-40),
	slots_info = {
		{id = 1,name = "Machine",},
		{id = 3,name = "Machine",},
		{id = 2,name = "Blood",},
		{id = 17,name = "Machine",},
		{id = 16,name = "Machine",},
		{id = 10,name = "Roll",},
		{id = 5,name = "Black",},
		{id = 15,name = "Black",},
		{id = 7,name = "Master",},
		{id = 9,name = "Bomb",},
		{id = 14,name = "Isaac",},
	},
	slot_info2word = {
		["Machine"] = 8,
		["Black"] = 5,
		["Roll"] = 13,
		["Master"] = 6,
		["Isaac"] = 11,
		["Bomb"] = 12,
		["Blood"] = 7,
	},
	prize_counts = {
		"prize_counter",
		"prize_counter2",
		"r_prize_counter",
		"r_prize_counter2",
	},
	eat_blacklist = {
		[996] = true,
		[EntityType.ENTITY_DOGMA] = true,
		[EntityType.ENTITY_BEAST] = true,
		[EntityType.ENTITY_MEGA_SATAN] = true,
		[EntityType.ENTITY_MEGA_SATAN_2] = true,
		[EntityType.ENTITY_DELIRIUM] = true,
		[EntityType.ENTITY_MOTHER] = true,
		[EntityType.ENTITY_ULTRA_GREED] = true,
	},
}
auxi.add_to_seija(item.entity)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if Game().Challenge == enums.Challenges.Pointing then cnt = cnt + 5 end
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	s:Play("Float",true)
end,
})

function local_try_speak(ent,id)
	local language = Options.Language
	if item.words[language] == nil then language = "en" end
	local word = item.words[language][id]
	local s_word = auxi.spilt_string(word)
	gui.draw_ch_with_time_to_dispair(ent.Position + item.Talking_Pos_Offset + Vector(-(#s_word)/2,0),Vector(0,-30),word,25)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local rng = ent:GetDropRNG()
	rng = auxi.rng_for_sake(rng)
	local room = Game():GetRoom()
	local player = auxi.check_spawner_player(ent)
	if d[item.own_key.."state"] == nil then d[item.own_key.."state"] = 0 end
	if s:IsPlaying("Float") and s:IsEventTriggered("Check") then
		local rnd = rng:RandomInt(4)
		local act = d[item.own_key.."action"] or ""
		d[item.own_key.."action"] = nil
		d[item.own_key.."filter"] = d[item.own_key.."filter"] or 0
		if d[item.own_key.."filter"] > 0 then d[item.own_key.."filter"] = d[item.own_key.."filter"] - 1 end
		local n_entity = Isaac.GetRoomEntities()
		local n_pickups = auxi.getpickups(n_entity,false)
		local tbl = {} 
		local tbl2 = {}
		for u,v in pairs(n_pickups) do
			if v.Variant ~= 340 and v.Variant ~= 370 and v.Variant ~= 100 then table.insert(tbl,v) end
			if v.Variant == 100 then table.insert(tbl2,v) end
		end
		if act == "Enemy" or act == "Pickups" or #tbl > 0 then rnd = 2 end
		if act == "Prize" then 
			for u,v in pairs(item.prize_counts) do if (d[item.own_key..v] or 0) > 0.5 then rnd = 7 break end end
		end
		if rnd == 1 then		--寻找隐藏
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ROCKET_IN_A_JAR) then s:ReplaceSpritesheet(2,"gfx/familiar/to_be_rocket.png")
			else s:ReplaceSpritesheet(2,"gfx/familiar/to_be_bomb.png") end
			s:LoadGraphics()
			s:Play("PutBomb",true)
			d[item.own_key.."blow_type"] = "Door"
			local n_slot = auxi.getothers_in_table(n_entity,6,0,nil)
			for u,v in pairs(item.slots_info) do
				local slot = n_slot[v.id]
				if slot and #slot > 0 then
					d[item.own_key.."target"] = slot[math.random(#slot)]
					d[item.own_key.."blow_type"] = v.name
					break
				end
			end
		elseif rnd == 2 then	--吞噬
			if #tbl2 > 0 and auxi.should_do_Seija(player,true) then d[item.own_key.."target"] = tbl2[math.random(#tbl2)] d[item.own_key.."action"] = "Pickups"
			elseif #tbl > 0 then d[item.own_key.."target"] = tbl[math.random(#tbl)]	d[item.own_key.."action"] = "Pickups"
			else
				if d[item.own_key.."filter"] <= 0 then 
					local n_enemy = auxi.getenemies(n_entity)
					local tbl = {}
					local tbl2 = {}
					for u,v in pairs(n_enemy) do
						if not item.eat_blacklist[v.Type] and v:Exists() and not v:IsDead() then
							if v:IsBoss() == false then table.insert(tbl,v)
							elseif not v:GetData()[item.own_key.."effect"] then table.insert(tbl2,v) end
						end
					end
					if #tbl2 > 0 and auxi.should_do_Seija(player,true) then 
						d[item.own_key.."target"] = tbl2[math.random(#tbl2)]
						d[item.own_key.."action"] = "Enemy"
						d[item.own_key.."filter"] = math.random(8) - 1
					elseif #tbl > 0 then
						d[item.own_key.."target"] = tbl[math.random(#tbl)]
						d[item.own_key.."action"] = "Enemy"
						d[item.own_key.."filter"] = math.random(8) - 1
					end
				end
			end
			if d[item.own_key.."target"] then
				s:Play("Eat",true)
				d[item.own_key.."remove"] = true
				d[item.own_key.."state"] = 1
			else
				for u,v in pairs(item.prize_counts) do if (d[item.own_key..v] or 0) > 0.5 then rnd = 7 break end end
			end
		end
		if rnd == 7 then		--提供奖励
			local succ = false
			for u,v in pairs(item.prize_counts) do if (d[item.own_key..v] or 0) > 0.5 then succ = true break end end
			if succ then
				s:Play("Prize",true)
				d[item.own_key.."state"] = 0
				d[item.own_key.."action"] = "Prize"
			end
		end
	end
	
	if s:IsPlaying("PutBomb") and s:IsEventTriggered("Throw") then
		if (d[item.own_key.."blow_type"] or "Door") == "Door" then 
			local tbl = {}
			local roomtype = room:GetType()
			local tbl_r_door = {}
			local tbl_i_door = {}
			if roomtype == RoomType.ROOM_SECRET or roomtype == RoomType.ROOM_SUPERSECRET or roomtype == RoomType.ROOM_ULTRASECRET then
				local_try_speak(ent,14)
				local q = player:FireBomb(ent.Position,auxi.MakeVector(math.random(3600)/10) * 10)
				q.PositionOffset = Vector(0,-35)
				q.Velocity = auxi.MakeVector(math.random(3600)/10) * 10
				q.ExplosionDamage = player.Damage
			else
				for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
					if room:IsDoorSlotAllowed(slot) then
						local door = room:GetDoor(slot)
						if door then
							if door:IsBusted() then
							else
								if door.TargetRoomType == RoomType.ROOM_SECRET or door.TargetRoomType == RoomType.ROOM_SUPERSECRET or door.TargetRoomType == RoomType.ROOM_ULTRASECRET then table.insert(tbl_i_door,slot)
								else table.insert(tbl_r_door,slot) end
							end
						else table.insert(tbl,slot) end
					end
				end
				if #tbl > 0 then
					local rnd = rng:RandomInt(#tbl) + 1
					local_try_speak(ent,1)
					local q = player:FireBomb(ent.Position,(room:GetDoorSlotPosition(tbl[rnd]) - ent.Position) * 0.05)
					q.PositionOffset = Vector(0,-35)
					q.Velocity = (room:GetDoorSlotPosition(tbl[rnd]) - ent.Position) * 0.05
					q.ExplosionDamage = player.Damage
				else
					local_try_speak(ent,2)
					if #tbl_r_door > 0 then
						local rnd = rng:RandomInt(#tbl_r_door) + 1
						local q = player:FireBomb(ent.Position,(room:GetDoorSlotPosition(tbl_r_door[rnd]) - ent.Position) * 0.05)
						q.PositionOffset = Vector(0,-35)
						q.Velocity = (room:GetDoorSlotPosition(tbl_r_door[rnd]) - ent.Position) * 0.05
						q.ExplosionDamage = player.Damage
					else
						local q = player:FireBomb(ent.Position,auxi.MakeVector(math.random(3600)/10) * 10)
						q.PositionOffset = Vector(0,-35)
						q.Velocity = auxi.MakeVector(math.random(3600)/10) * 10
						q.ExplosionDamage = player.Damage
					end
				end
			end
		else
			if auxi.check_all_exists(d[item.own_key.."target"]) then
				local pos = d[item.own_key.."target"].Position
				local q = player:FireBomb(ent.Position,(pos - ent.Position) * 0.05)
				q.PositionOffset = Vector(0,-35)
				q.ExplosionDamage = player.Damage
				local_try_speak(ent,item.slot_info2word[d[item.own_key.."blow_type"]] or 8)
				d[item.own_key.."target"] = nil
			end
		end
	end
	if s:IsPlaying("Eat") then
		if s:IsEventTriggered("Finish") then
			d[item.own_key.."target"] = nil
			d[item.own_key.."state"] = 0
		end
		if s:IsEventTriggered("Remove") then
			if d[item.own_key.."remove"] then
				if auxi.check_all_exists(d[item.own_key.."target"]) then
					if d[item.own_key.."target"]:ToPickup() then
						local tg = d[item.own_key.."target"]:ToPickup()
						tg:PlayPickupSound()
						if tg:IsShopItem() then local_try_speak(ent,10)	end
						if auxi.can_start_ambush(tg) and auxi.would_start_ambush() then local_try_speak(ent,4) auxi.try_start_ambush() end
						if auxi.should_do_Seija(player) and d[item.own_key.."target"].Variant == 100 then d[item.own_key.."r_prize_counter2"] = (d[item.own_key.."r_prize_counter2"] or 0) + 1 
						else d[item.own_key.."r_prize_counter"] = (d[item.own_key.."r_prize_counter"] or 0) + 1 end
					else
						if auxi.should_do_Seija(player) and d[item.own_key.."target"]:IsBoss() then d[item.own_key.."prize_counter2"] = (d[item.own_key.."prize_counter2"] or 0) + 1 
						else d[item.own_key.."prize_counter"] = (d[item.own_key.."prize_counter"] or 0) + 1 end
						d[item.own_key.."smash"] = true
					end
					d[item.own_key.."target"]:Kill()
					d[item.own_key.."target"]:Remove()
				end
				d[item.own_key.."remove"] = nil
			end
		end
		if s:IsEventTriggered("Fart") then
			if d[item.own_key.."fart"] then
				d[item.own_key.."fart"] = nil
				Game():Fart(ent.Position,30,ent,1,0)
			elseif d[item.own_key.."smash"] then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_BURST_SMALL,1,1,false,0,2)
				d[item.own_key.."smash"] = nil
			end
		end
	end
	if s:IsPlaying("Prize") then
		if s:IsEventTriggered("Prize") then
			if (d[item.own_key.."prize_counter2"] or 0) > 0.5 then
				local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(ent.Position),Vector(0,0),nil):ToPickup()
				d[item.own_key.."prize_counter2"] = d[item.own_key.."prize_counter2"] - 1
			elseif (d[item.own_key.."r_prize_counter2"] or 0) > 0.5 then
				local q = Isaac.Spawn(74,0,0,room:GetCenterPos(),Vector(0,0),nil):ToNPC()
				local infos = danger_data.check_and_morph_ent(q,true,{health_alpha = 0.3,ignore_hard = true,special_work = function(ent) ent:GetData()[item.own_key.."effect"] = true end})
				q:Remove()
				local_try_speak(ent,15)
				for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
					local door = room:GetDoor(slot)
					if (door) then
						door:Close()
					end
				end
				d[item.own_key.."r_prize_counter2"] = d[item.own_key.."r_prize_counter2"] - 1
			elseif (d[item.own_key.."prize_counter"] or 0) > 0.5 then
				local q = Isaac.Spawn(5,0,0,room:FindFreePickupSpawnPosition(ent.Position),Vector(0,0),nil):ToPickup()
				if q.Variant == 100 then q:Morph(5,40,7,true) end
				d[item.own_key.."prize_counter"] = d[item.own_key.."prize_counter"] - 1
			elseif (d[item.own_key.."r_prize_counter"] or 0) > 0.5 then
				local q = Isaac.Spawn(10,0,0,ent.Position,Vector(0,0),nil):ToNPC()
				if auxi.REPENTENCE_PLUS() then
					local infos = danger_data.check_and_morph_ent(q,true,{health_alpha = 0.3,ignore_hard = true,special_work = function(ent) ent:GetData()[item.own_key.."effect"] = true end})
					q:Remove()	
				else
					Game():RerollEnemy(q)
				end
				d[item.own_key.."r_prize_counter"] = d[item.own_key.."r_prize_counter"] - 1
			end
			local succ = false
			for u,v in pairs(item.prize_counts) do if (d[item.own_key..v] or 0) > 0.5 then succ = true break end end
			if not succ then d[item.own_key.."action"] = nil end
		end
	end
	if d[item.own_key.."state"] == 0 then		--飘向角色
		ent:FollowPosition(player.Position)
	elseif d[item.own_key.."state"] == 1 then
		if auxi.check_all_exists(d[item.own_key.."target"]) then
			if (ent.Position - d[item.own_key.."target"].Position):Length() > 150 then
				ent:FollowPosition(d[item.own_key.."target"].Position)
			else
				ent.Velocity = (d[item.own_key.."target"].Position - ent.Position) * 0.2
			end
		else
			d[item.own_key.."target"] = nil
			d[item.own_key.."state"] = 0
		end
	end
	if s:IsFinished("PutBomb") or s:IsFinished("Eat") or s:IsFinished("Prize") then
		s:Play("Float",true)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local tgs = auxi.getothers(nil,3,item.familiar)
	for u,v in pairs(tgs) do
		local d = v:GetData()
		d[item.own_key.."target"] = nil
		d[item.own_key.."state"] = 0
		v:GetSprite():Play("Float")
	end
end,
})

return item
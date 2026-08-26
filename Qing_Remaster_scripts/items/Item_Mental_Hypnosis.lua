local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local displaying_data2 = require("Qing_Remaster_scripts.translations.data2")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Mental_Hypnosis,
	now_render = {},
	offset = Vector(52,46),
	del_offset = Vector(0,10),
	own_key = "Item_Mental_Hy_",
	words = {
		buff = {
			zh = {
				[1] = {
					Name = "攻击上升",
					Description = "经验+3",
				},
				[2] = {
					Name = "射速上升",
					Description = "哭吧哭吧我的孩子",
				},
				[3] = {
					Name = "弹速上升",
					Description = "现在，要加速了！",
				},
				[4] = {
					Name = "射程上升",
					Description = "一寸长，一寸强",
				},
				[5] = {
					Name = "移速上升",
					Description = "你的双脚变得轻盈",
				},
				[6] = {
					Name = "幸运上升",
					Description = function(wd,player) 
						local rng = player:GetCollectibleRNG(33)
						rng = auxi.rng_for_sake(rng)
						local language = auxi.get_language_map(Options.Language)
						if displaying_data2[language] then
							local rnd = rng:RandomInt(8) + 1
							local data = displaying_data2[language]["#Entry_"..tostring(rnd)]
							if data then
								return data
							else
								return "恭喜！"
							end
						end
					end,
				},
				[7] = {
					Name = "身体变小了",
					Description = "享受这一刻吧！",
				},
			},
			en = {
				[1] = {
					Name = "Damage Up",
					Description = "Level UP!!!",
				},
				[2] = {
					Name = "Tear Up",
					Description = "Cry as you wish.",
				},
				[3] = {
					Name = "Shot Speed Up",
					Description = "Acceleration!!",
				},
				[4] = {
					Name = "Range Up",
					Description = "Larger reaches more.",
				},
				[5] = {
					Name = "Speed Up",
					Description = "May you be as swift as meteors.",
				},
				[6] = {
					Name = "Luck Up",
					Description = function(wd,player) 
						local rng = player:GetCollectibleRNG(33)
						rng = auxi.rng_for_sake(rng)
						local language = auxi.get_language_map(Options.Language)
						if displaying_data2[language] then
							local rnd = rng:RandomInt(8) + 1
							local data = displaying_data2[language]["#Entry_"..tostring(rnd)]
							if data then
								return data
							else
								return "That's good！"
							end
						end
					end,
				},
				[7] = {
					Name = "Size Down",
					Description = "I Reward You A Smaller Body",
				},
			},
		},
		debuff = {
			zh = {
				[1] = {
					Name = "攻击下降",
					Description = "平角裤平角裤",
				},
				[2] = {
					Name = "射速下降",
					Description = "失去就是力量",
				},
				[3] = {
					Name = "弹速下降",
					Description = "伪装成负面的正面效果",
				},
				[4] = {
					Name = "射程下降",
					Description = "一寸短，一寸险",
				},
				[5] = {
					Name = "移速下降",
					Description = "是时候表演不动的战斗了",
				},
				[6] = {
					Name = "幸运下降",
					Description = function(wd,player) 
						local rng = player:GetCollectibleRNG(33)
						rng = auxi.rng_for_sake(rng)
						local language = auxi.get_language_map(Options.Language)
						if displaying_data2[language] then
							local rnd = rng:RandomInt(8) + 1
							local data = displaying_data2[language]["#Entry_"..tostring(rnd)]
							if data then
								return data
							else
								return "幸运值：E-"
							end
						end
					end,
				},
				[7] = {
					Name = "身体变大了",
					Description = "享受这一刻吧！",
				},
			},
			en = {
				[1] = {
					Name = "Damage Down",
					Description = "Level Down!!!",
				},
				[2] = {
					Name = "Tear Down",
					Description = "Stop crying,now!",
				},
				[3] = {
					Name = "Shot Speed Down",
					Description = "Maybe it's not that bad?",
				},
				[4] = {
					Name = "Range Down",
					Description = "Future is close.",
				},
				[5] = {
					Name = "Speed Down",
					Description = "Cool down yourself!",
				},
				[6] = {
					Name = "Luck Down",
					Description = function(wd,player) 
						local rng = player:GetCollectibleRNG(33)
						rng = auxi.rng_for_sake(rng)
						local language = auxi.get_language_map(Options.Language)
						if displaying_data2[language] then
							local rnd = rng:RandomInt(8) + 1
							local data = displaying_data2[language]["#Entry_"..tostring(rnd)]
							if data then
								return data
							else
								return "That's bad！"
							end
						end
					end,
				},
				[7] = {
					Name = "Size Up",
					Description = "I Punish You A Bigger Body",
				},
			},
		},
	},
	ignore_roomtype = {
		[1] = true,
		[23] = true,
		[29] = true,
	},
	Colorinfo = {
		{frame = 0 * 18,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 18,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 18,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 18,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 18,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 18,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		
		{frame = 6 * 18,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 18,
	},
}

function item.is_secret_room_type(roomtype)
	return roomtype == RoomType.ROOM_SECRET
end

function item.get_late_secret_room_info(room_desc)
	if not (REPENTOGON and room_desc and room_desc.Data and item.is_secret_room_type(room_desc.Data.Type)) then return nil end
	if not room_desc.GetNeighboringRooms then return nil end
	local has_neighbor = false
	local neighbor_roomtypes = {}
	for _,neighbor_desc in pairs(room_desc:GetNeighboringRooms()) do
		if neighbor_desc and neighbor_desc.Data and neighbor_desc.SafeGridIndex >= 0 then
			has_neighbor = true
			if neighbor_desc.Data.Type == RoomType.ROOM_DEFAULT then return nil end
			if item.ignore_roomtype[neighbor_desc.Data.Type] ~= true then
				neighbor_roomtypes[neighbor_desc.Data.Type] = true
			end
		end
	end
	if not has_neighbor then return nil end
	return {roomtype = room_desc.Data.Type, neighbor_roomtypes = neighbor_roomtypes}
end

function item.insert_late_secret_room(target,late_info,rng)
	local first_neighbor_id = nil
	for i = 1,#target do
		if late_info.neighbor_roomtypes[target[i]] then
			first_neighbor_id = i
			break
		end
	end
	if first_neighbor_id then
		local insert_id = first_neighbor_id + 1 + rng:RandomInt(#target - first_neighbor_id + 1)
		table.insert(target,insert_id,late_info.roomtype)
	else
		table.insert(target,#target + 1,late_info.roomtype)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local idx = player:GetData().__Index
	save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
	if idx and save.elses[item.own_key.."buff"][idx] then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + (save.elses[item.own_key.."buff"][idx].damage or 0) * auxi.get_damage_multiplier(player)
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay , auxi.get_mxdelay_multiplier(player) * (save.elses[item.own_key.."buff"][idx].tear or 0))
		end
		if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + (save.elses[item.own_key.."buff"][idx].shotspeed or 0)
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + (save.elses[item.own_key.."buff"][idx].range or 0)
		end
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + (save.elses[item.own_key.."buff"][idx].speed or 0)
		end
		if cacheFlag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + (save.elses[item.own_key.."buff"][idx].luck or 0)
		end
		if cacheFlag == CacheFlag.CACHE_SIZE then
			player.SpriteScale = player.SpriteScale * (save.elses[item.own_key.."buff"][idx].size or 1)
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	local player = auxi.have_player_has_collectible(item.entity)
	save.elses[item.own_key.."target"] = {}
	save.elses[item.own_key.."nowconter"] = 1
	item.now_render = {}
	if player then
		local level = Game():GetLevel()
		local rooms = level:GetRooms()
		local rng = player:GetCollectibleRNG(item.entity)
		rng = auxi.rng_for_sake(rng)
		local tbl = {}
		local rd = {}
		local late_tbl = {}
		for i = 0, rooms.Size - 1 do
			local targ = rooms:Get(i)
			if targ ~= nil and targ.SafeGridIndex >= 0 then
				local tp = targ.Data.Type
				if item.ignore_roomtype[tp] ~= true then
					if Game():IsGreedMode() and (tp == 7 or tp == 8) then
						table.insert(rd,#rd + 1,tp)
					else
						local late_info = item.get_late_secret_room_info(targ)
						if late_info then
							table.insert(late_tbl,#late_tbl + 1,late_info)
						else
							table.insert(tbl,#tbl + 1,tp)
						end
					end
				end
			end
		end
		save.elses[item.own_key.."target"] = auxi.randomTable(tbl,rng)
		late_tbl = auxi.randomTable(late_tbl,rng)
		for u,v in pairs(late_tbl) do item.insert_late_secret_room(save.elses[item.own_key.."target"],v,rng) end
		for u,v in pairs(rd) do table.insert(save.elses[item.own_key.."target"],#save.elses[item.own_key.."target"] + 1,v) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_,name)
	if name == "Qing_HelpfulShader" and Game():GetHUD():IsVisible() then
		local player = auxi.have_player_has_collectible(item.entity)
		if player then
			if save.elses[item.own_key.."nowconter"] then
				save.elses[item.own_key.."target"] = save.elses[item.own_key.."target"] or {}
				local total = (#save.elses[item.own_key.."target"])
				if total > 0 and save.elses[item.own_key.."nowconter"] <= total then
					local s = Sprite()
					s:Load("gfx/mimics/Mental_Hypnosis/Black_Map_ui_inventory.anm2",true)
					s:Play("Idle",true)
					if Game():IsPaused() == true then
						s.Color = Color(1,1,1,0.3)
					else
						s.Color = Color(1,1,1,1)
					end
					s:Render(item.offset + Vector(6,6),Vector(0,0),Vector(0,0))
					for i = 1,(#save.elses[item.own_key.."target"]) do
						if i < save.elses[item.own_key.."nowconter"] then
						else
							if item.now_render[i] == nil then
								local s = Sprite()
								s:Load("gfx/mimics/Mental_Hypnosis/Black_Map_map_icons.anm2",true)
								local name = auxi.GetNameByRoomType(save.elses[item.own_key.."target"][i])
								if auxi.IsAmbushBoss() and save.elses[item.own_key.."target"][i] == 11 then
									name = "BossAmbushRoom"
								end
								s:Play("Icon"..name,true)
								item.now_render[i] = {sprite = s,pos = item.offset + (i - save.elses[item.own_key.."nowconter"])*item.del_offset,}
							end
							local s = item.now_render[i].sprite
							if item.now_render[i].pos ~= item.offset + (i - save.elses[item.own_key.."nowconter"]) * item.del_offset then
								item.now_render[i].pos = (item.now_render[i].pos) * 0.9 + (item.offset + (i - save.elses[item.own_key.."nowconter"])*item.del_offset) * 0.1
							end
							if Game():IsPaused() == true then
								s.Color = Color(1,1,1,0.3 * (total - i + save.elses[item.own_key.."nowconter"])/total)
							else
								s.Color = Color(1,1,1,1 * (total - i + save.elses[item.own_key.."nowconter"])/total)
							end
							s:Render(item.now_render[i].pos,Vector(0,0),Vector(0,0))
						end
					end
				end
			end
		end
	end
end,
})

local STAT_CACHE_FLAGS = {
	[1] = CacheFlag.CACHE_DAMAGE,
	[2] = CacheFlag.CACHE_FIREDELAY,
	[3] = CacheFlag.CACHE_SHOTSPEED,
	[4] = CacheFlag.CACHE_RANGE,
	[5] = CacheFlag.CACHE_SPEED,
	[6] = CacheFlag.CACHE_LUCK,
	[7] = CacheFlag.CACHE_SIZE,
}

local function reward(player)
	local idx = player:GetData().__Index
	local room = Game():GetRoom()
	local rng = player:GetCollectibleRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	if idx ~= nil then
		local stat_cache = 0
		local tg = {}
		table.insert(tg,#tg + 1,{name = "dmg",weigh = 5})
		table.insert(tg,#tg + 1,{name = "tear",weigh = 4})
		table.insert(tg,#tg + 1,{name = "shotspeed",weigh = 5})
		table.insert(tg,#tg + 1,{name = "range",weigh = 7})
		table.insert(tg,#tg + 1,{name = "speed",weigh = 7})
		table.insert(tg,#tg + 1,{name = "luck",weigh = 7})
		table.insert(tg,#tg + 1,{name = "size",weigh = 6})
		table.insert(tg,#tg + 1,{name = "money",weigh = 8})
		table.insert(tg,#tg + 1,{name = "key",weigh = 8})
		table.insert(tg,#tg + 1,{name = "bomb",weigh = 8})
		table.insert(tg,#tg + 1,{name = "battery",weigh = 4})
		table.insert(tg,#tg + 1,{name = "heart",weigh = 10})
		table.insert(tg,#tg + 1,{name = "collectible",weigh = 1})
		table.insert(tg,#tg + 1,{name = "card",weigh = 4})
		table.insert(tg,#tg + 1,{name = "pill",weigh = 4})
		table.insert(tg,#tg + 1,{name = "spider",weigh = 3})
		table.insert(tg,#tg + 1,{name = "fly",weigh = 3})
		table.insert(tg,#tg + 1,{name = "prettyfly",weigh = 1})
		table.insert(tg,#tg + 1,{name = "dip",weigh = 2})
		local stag = auxi.random_in_weighed_table(tg,rng)
		local Buff_holder_counter = 0
		save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
		save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
		if stag.name == "dmg" then
			save.elses[item.own_key.."buff"][idx].damage = (save.elses[item.own_key.."buff"][idx].damage or 0) + 0.5
			Buff_holder_counter = 1
			stat_cache = STAT_CACHE_FLAGS[1]
		elseif stag.name == "tear" then
			save.elses[item.own_key.."buff"][idx].tear = (save.elses[item.own_key.."buff"][idx].tear or 0) + 0.35
			Buff_holder_counter = 2
			stat_cache = STAT_CACHE_FLAGS[2]
		elseif stag.name == "shotspeed" then
			save.elses[item.own_key.."buff"][idx].shotspeed = (save.elses[item.own_key.."buff"][idx].shotspeed or 0) + 0.15
			Buff_holder_counter = 3
			stat_cache = STAT_CACHE_FLAGS[3]
		elseif stag.name == "range" then
			save.elses[item.own_key.."buff"][idx].range = (save.elses[item.own_key.."buff"][idx].range or 0) + 40
			Buff_holder_counter = 4
			stat_cache = STAT_CACHE_FLAGS[4]
		elseif stag.name == "luck" then
			save.elses[item.own_key.."buff"][idx].luck = (save.elses[item.own_key.."buff"][idx].luck or 0) + 1
			Buff_holder_counter = 6
			stat_cache = STAT_CACHE_FLAGS[6]
		elseif stag.name == "speed" then
			save.elses[item.own_key.."buff"][idx].speed = (save.elses[item.own_key.."buff"][idx].speed or 0) + 0.15
			Buff_holder_counter = 5
			stat_cache = STAT_CACHE_FLAGS[5]
		elseif stag.name == "size" then
			save.elses[item.own_key.."buff"][idx].size = (save.elses[item.own_key.."buff"][idx].size or 1) * 0.9
			Buff_holder_counter = 7
			stat_cache = STAT_CACHE_FLAGS[7]
		elseif stag.name == "money" then
			local rnd = rng:RandomInt(5) + 1
			for i = 1,rnd do
				local q = Isaac.Spawn(5,20,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil)
			end
		elseif stag.name == "bomb" then
			local rnd = rng:RandomInt(2) + 1
			for i = 1,rnd do
				local q = Isaac.Spawn(5,40,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil)
			end
		elseif stag.name == "key" then
			local rnd = rng:RandomInt(2) + 1
			for i = 1,rnd do
				local q = Isaac.Spawn(5,30,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil)
			end
		elseif stag.name == "battery" then
			local rnd = rng:RandomInt(2) + 1
			for i = 1,rnd do
				local q = Isaac.Spawn(5,90,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil)
			end
		elseif stag.name == "heart" then
			local rnd = rng:RandomInt(3) + 2
			for i = 1,rnd do
				local q = Isaac.Spawn(5,10,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil)
			end
		elseif stag.name == "collectible" then
			local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil)
		elseif stag.name == "card" then
			local q = Isaac.Spawn(5,300,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil)
		elseif stag.name == "pill" then
			local rnd = rng:RandomInt(2) + 1
			for i = 1,rnd do
				local q = Isaac.Spawn(5,70,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil)
			end
		elseif stag.name == "spider" then
			local rnd = rng:RandomInt(8) + 2
			for i = 1,rnd do
				local q = player:AddBlueSpider(player.Position)
			end
		elseif stag.name == "fly" then
			local rnd = rng:RandomInt(6) + 2
			for i = 1,rnd do
				local q = player:AddBlueFlies(1,player.Position,player)
			end
		elseif stag.name == "prettyfly" then
			player:AddPrettyFly()
		elseif stag.name == "dip" then
			local rnd = rng:RandomInt(5) + 2
			for i = 1,rnd do
				player:ThrowFriendlyDip(1,player.Position,Vector.Zero)
			end
		end
		if Buff_holder_counter ~= 0 then
			local language = Options.Language
			if item.words.buff[language] == nil then language = "en" end
			local word = item.words.buff[language][Buff_holder_counter]
			local name = word.Name
			local des = word.Description
			if type(name) == "function" then name = name(word,player) end
			if type(des) == "function" then des = des(word,player) end
			item_displaying_holder.check_and_description("ItemDesc",item.entity,name,des,player,true)
		end
		if player:Exists() then
			player:AnimateHappy()
			if stat_cache ~= 0 then
				player:AddCacheFlags(stat_cache)
			end
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end

local function punish(player)
	local idx = player:GetData().__Index
	local rng = player:GetCollectibleRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	if idx ~= nil then
		local stat_cache = 0
		local tg = {}
		local room = Game():GetRoom()
		table.insert(tg,#tg + 1,{name = "dmg",weigh = 10})
		table.insert(tg,#tg + 1,{name = "tear",weigh = 10})
		table.insert(tg,#tg + 1,{name = "shotspeed",weigh = 8})
		table.insert(tg,#tg + 1,{name = "range",weigh = 10})
		table.insert(tg,#tg + 1,{name = "speed",weigh = 10})
		table.insert(tg,#tg + 1,{name = "luck",weigh = 10})
		table.insert(tg,#tg + 1,{name = "size",weigh = 10})
		if player:GetNumCoins() > 10 then table.insert(tg,#tg + 1,{name = "money10",weigh = 5})
		else table.insert(tg,#tg + 1,{name = "money10",weigh = math.ceil(player:GetNumCoins()/3)}) end
		if player:HasGoldenBomb() == true then table.insert(tg,#tg + 1,{name = "goldenbomb",weigh = 5})	end
		if player:HasGoldenKey() == true then table.insert(tg,#tg + 1,{name = "goldenkey",weigh = 5}) end
		if player:GetNumBombs() >= 3 then table.insert(tg,#tg + 1,{name = "bomb",weigh = 8}) end
		if player:GetNumKeys() >= 3 then table.insert(tg,#tg + 1,{name = "key",weigh = 8}) end
		if player:GetNumCoins() > 1 then table.insert(tg,#tg + 1,{name = "luckycoin",weigh = 5}) end
		table.insert(tg,#tg + 1,{name = "trollbomb",weigh = 7})
		table.insert(tg,#tg + 1,{name = "bigtrollbomb",weigh = 2})
		table.insert(tg,#tg + 1,{name = "goldentrollbomb",weigh = 4})
		local stag = auxi.random_in_weighed_table(tg,rng)
		local Buff_holder_counter = 0
		save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
		save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
		if stag.name == "dmg" then
			save.elses[item.own_key.."buff"][idx].damage = (save.elses[item.own_key.."buff"][idx].damage or 0) - 0.2
			Buff_holder_counter = 1
			stat_cache = STAT_CACHE_FLAGS[1]
		elseif stag.name == "tear" then
			save.elses[item.own_key.."buff"][idx].tear = (save.elses[item.own_key.."buff"][idx].tear or 0) - 0.2
			Buff_holder_counter = 2
			stat_cache = STAT_CACHE_FLAGS[2]
		elseif stag.name == "shotspeed" then
			save.elses[item.own_key.."buff"][idx].shotspeed = (save.elses[item.own_key.."buff"][idx].shotspeed or 0) - 0.1
			Buff_holder_counter = 3
			stat_cache = STAT_CACHE_FLAGS[3]
		elseif stag.name == "range" then
			save.elses[item.own_key.."buff"][idx].range = (save.elses[item.own_key.."buff"][idx].range or 0) - 20
			Buff_holder_counter = 4
			stat_cache = STAT_CACHE_FLAGS[4]
		elseif stag.name == "luck" then
			save.elses[item.own_key.."buff"][idx].luck = (save.elses[item.own_key.."buff"][idx].luck or 0) - 0.5
			Buff_holder_counter = 6
			stat_cache = STAT_CACHE_FLAGS[6]
		elseif stag.name == "speed" then
			save.elses[item.own_key.."buff"][idx].speed = (save.elses[item.own_key.."buff"][idx].speed or 0) - 0.1
			Buff_holder_counter = 5
			stat_cache = STAT_CACHE_FLAGS[5]
		elseif stag.name == "size" then
			save.elses[item.own_key.."buff"][idx].size = (save.elses[item.own_key.."buff"][idx].size or 1) * 1.12
			Buff_holder_counter = 7
			stat_cache = STAT_CACHE_FLAGS[7]
		elseif stag.name == "money10" then
			player:AddCoins(-10)
			dropping_holder.try_drop(player.Position,nil,{load_name = "gfx/005.023_dime.anm2",})
		elseif stag.name == "goldenbomb" then
			player:RemoveGoldenBomb()
			dropping_holder.try_drop(player.Position,nil,{load_name = "gfx/005.043_golden bomb.anm2",})
		elseif stag.name == "goldenkey" then
			player:RemoveGoldenKey()
			dropping_holder.try_drop(player.Position,nil,{load_name = "gfx/005.032_golden key.anm2",})
		elseif stag.name == "bomb" then
			player:AddBombs(-3)
			for i = 1,3 do
				dropping_holder.try_drop(player.Position,nil,{load_name = "gfx/005.041_bomb.anm2",})
			end
		elseif stag.name == "key" then
			player:AddKeys(-3)
			for i = 1,3 do
				dropping_holder.try_drop(player.Position,nil,{load_name = "gfx/005.031_key.anm2",})
			end
		elseif stag.name == "luckycoin" then
			player:AddCoins(-1)
			save.elses[item.own_key.."buff"][idx].luck = (save.elses[item.own_key.."buff"][idx].luck or 0) - 1
			stat_cache = STAT_CACHE_FLAGS[6]
			dropping_holder.try_drop(player.Position,nil,{load_name = "gfx/005.026_lucky penny.anm2",})
		elseif stag.name == "trollbomb" then
			for i = 1,4 do
				local q = Isaac.Spawn(5,40,3,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil)
			end
		elseif stag.name == "bigtrollbomb" then
			for i = 1,2 do
				local q = Isaac.Spawn(5,40,6,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil)
			end
		elseif stag.name == "goldentrollbomb" then
			local q = Isaac.Spawn(4,17,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil)
		end
		if Buff_holder_counter ~= 0 then
			local language = Options.Language
			if item.words.debuff[language] == nil then language = "en" end
			local word = item.words.debuff[language][Buff_holder_counter]
			local name = word.Name
			local des = word.Description
			if type(name) == "function" then name = name(word,player) end
			if type(des) == "function" then des = des(word,player) end
			item_displaying_holder.check_and_description("ItemDesc",item.entity,name,des,player,true)
		end
		if player:Exists() then
			player:AnimateSad()
			if stat_cache ~= 0 then
				player:AddCacheFlags(stat_cache)
			end
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local should_count = false
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	local tp = desc.Data.Type
	local player = auxi.have_player_has_collectible(item.entity)
	if player then
		if item.ignore_roomtype[desc.Data.Type] ~= true and desc.SafeGridIndex > 0 and room:IsFirstVisit() == true then
			if save.elses[item.own_key.."nowconter"] then
				if #save.elses[item.own_key.."target"] > 0 and save.elses[item.own_key.."nowconter"] <= (#save.elses[item.own_key.."target"]) then
					if tp == (save.elses[item.own_key.."target"][save.elses[item.own_key.."nowconter"]] or -1) then
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							if auxi.has_have_coll(player,item.entity) then
								delay_buffer.addeffe(function(params)
									if player:Exists() then
										reward(player)
									end
								end,{},5)
							end
						end
					else
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							if auxi.has_have_coll(player,item.entity) then
								delay_buffer.addeffe(function(params)
									if player:Exists() then
										punish(player)
									end
								end,{},5)
							end
						end
					end
					save.elses[item.own_key.."nowconter"] = (save.elses[item.own_key.."nowconter"] or 1) + 1
				end
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."buff"] = {}
		save.elses[item.own_key.."target"] = {}
		save.elses[item.own_key.."nowconter"] = 1
	end
	save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
	save.elses[item.own_key.."target"] = save.elses[item.own_key.."target"] or {}
	save.elses[item.own_key.."nowconter"] = save.elses[item.own_key.."nowconter"] or 1
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local d = ent:GetData()
		d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
		ent:GetSprite().Color = auxi.table2color(auxi.check_lerp(d[item.own_key.."counter"] % item.Colorinfo.total,item.Colorinfo))
	end
end,
})

return item

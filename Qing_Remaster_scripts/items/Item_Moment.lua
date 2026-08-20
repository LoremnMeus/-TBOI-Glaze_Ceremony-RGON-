local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Moment,
	own_key = "Item_Moment_",
	words = {
		zh = {
			[1] = {
				Name = "零点反转",
				Description = "转反点零",
			},
			[2] = {
				Name = "晨星装置已启用",
				Description = "正在为您释放多余能量",
			},
			[3] = {
				Name = "!警告!",
				Description = "捕获到超频异常，正在检测到可能的能量过载",
			},
			[4] = {
				Name = "!!紧急警告!!",
				Description = "超频100%!停止永动机!",
			},
			[5] = {
				Name = "!!!危机警告!!!",
				Description = "粒子正在大量突破能垒，立即停止!",
			},
			[6] = {
				Name = "!!!!!!!!",
				Description = "崩溃即将发生",
			},
			[7] = {
				Name = "循环系统已就绪",
				Description = "正在重启永动机",
			},
			[8] = {
				Name = "晨星装置启动失败！",
				Description = "危险！多余能量无法释放！",
			},
		},
		en = {
			[1] = {
				Name = "Zero reversal!",
				Description = "!lasrever oreZ",
			},
			[2] = {
				Name = "Introduced Morning Star Device",
				Description = "Release energy automatically",
			},
			[3] = {
				Name = "!Caution!",
				Description = "Catching Exception.Now dealing...",
			},
			[4] = {
				Name = "!!OverClocking Caution!!",
				Description = "OverClocking 100% percent.Trying to stop.",
			},
			[5] = {
				Name = "!!!Danger!!!",
				Description = "Particles are exceeding energy base",
			},
			[6] = {
				Name = "!!!!!!!!",
				Description = "Collapsed",
			},
			[7] = {
				Name = "Cycle completed",
				Description = "Regenerating moment system",
			},
			[8] = {
				Name = "Fail to launch Morning Star Device！",
				Description = "Danger!!!",
			},
		},
	},
	buffs = {
		[1] = {name = "damage",weigh = 5,},
		[2] = {name = "tear",weigh = 4,},
		[3] = {name = "range",weigh = 7,},
		[4] = {name = "luck",weigh = 6,},
		[5] = {name = "speed",weigh = 6,},
	},
	not_reversable = {
		[1] = true,
	},
}
auxi.add_to_seija(item.entity)

local function reward(player)
	local rng = player:GetCollectibleRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	local idx = player:GetData().__Index
	local tbl = auxi.deepCopy(item.buffs)
	local rnd = auxi.random_in_weighed_table(tbl,rng)
	save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
	save.elses[item.own_key.."buff"][idx][rnd.name] = (save.elses[item.own_key.."buff"][idx][rnd.name] or 0) + 1
	player:AddCacheFlags(CacheFlag.CACHE_ALL)
	player:GetData().should_evaluate_on_update_once = true
end

local function reverse_grid(value)
	local room = Game():GetRoom()
	if value == nil then value = true end
	local size = room:GetGridSize()
	for i = 0,size - 1 do
		local gent = room:GetGridEntity(i)
		if (gent and gent:ToDoor() == nil) then
			local s = gent:GetSprite()
			s.FlipY = value
		end
	end
end

function item.should_reverse()
	save.elses[item.own_key.."reverse"] = save.elses[item.own_key.."reverse"] or {}
	for u,v in pairs(save.elses[item.own_key.."reverse"]) do if v == -1 then return true end end
	return false
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local idx = player:GetData().__Index
		if idx ~= nil then
			save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
			save.elses[item.own_key.."reverse"] = save.elses[item.own_key.."reverse"] or {}
			save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
			if cacheFlag == CacheFlag.CACHE_DAMAGE then
				player.Damage = player.Damage + auxi.get_damage_multiplier(player) * (math.sqrt((save.elses[item.own_key.."buff"][idx].damage or 0) + 16) - 4) * 0.34 * (save.elses[item.own_key.."reverse"][idx] or 1)
			end
			if cacheFlag == CacheFlag.CACHE_FIREDELAY then
				player.MaxFireDelay = math.min(300,auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * (math.sqrt((save.elses[item.own_key.."buff"][idx].tear or 0) + 16) - 4) * 0.3 * (save.elses[item.own_key.."reverse"][idx] or 1)))
			end
			if cacheFlag == CacheFlag.CACHE_RANGE then
				player.TearRange = player.TearRange + math.sqrt((save.elses[item.own_key.."buff"][idx].range or 0)) * (save.elses[item.own_key.."reverse"][idx] or 1) * 3
			end
			if cacheFlag == CacheFlag.CACHE_SPEED then
				player.MoveSpeed = player.MoveSpeed + math.sqrt((save.elses[item.own_key.."buff"][idx].speed or 0)) * 0.03 * (save.elses[item.own_key.."reverse"][idx] or 1)
			end
			if cacheFlag == CacheFlag.CACHE_LUCK then
				player.Luck = player.Luck + (math.sqrt((save.elses[item.own_key.."buff"][idx].luck or 0) + 16) - 4) * 0.28 * (save.elses[item.own_key.."reverse"][idx] or 1)
			end
			if cacheFlag == CacheFlag.CACHE_SIZE then
				player.SpriteScale = Vector(player.SpriteScale.X,player.SpriteScale.Y * (save.elses[item.own_key.."reverse"][idx] or 1))
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
		save.elses[item.own_key.."reverse"] = {}
		save.elses[item.own_key.."release"] = {}
		save.elses[item.own_key.."warming"] = {}
	end
	save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
	save.elses[item.own_key.."reverse"] = save.elses[item.own_key.."reverse"] or {}
	save.elses[item.own_key.."release"] = save.elses[item.own_key.."release"] or {}
	save.elses[item.own_key.."warming"] = save.elses[item.own_key.."warming"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d.moment_counter then d.moment_counter = d.moment_counter - 1 end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_KNIFE_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local player = auxi.check_spawner_player(ent)
	if player and auxi.has_have_coll(player,item.entity) and player:GetData().__Index and (save.elses[item.own_key.."reverse"][player:GetData().__Index] or 1) ~= -1 then
		if d.moment_counter == nil then d.moment_counter = 0 end
		d.moment_counter = d.moment_counter - 1
		if d.moment_counter <= 0 and col:IsVulnerableEnemy() and col:IsActiveEnemy() and (not col:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and col:CanShutDoors() == true then
			d.moment_counter = 15
			local pos = col.Position
			local q = Isaac.Spawn(2,0,0,pos,auxi.MakeVector(math.random(3600)/10) * (math.random(50)/10 + 2) + ent.Velocity * 0.5,player):ToTear() q.Mass = 0
			local s2 = q:GetSprite()
			s2.Color = auxi.AddColor(s.Color,Color(1,1,1,1,1,1,1),0.5,0.5)
			local d2 = q:GetData()
			d2.is_moment = true
			d2.Ignore_me_flag = true
			d2.ignore_field = true
			q.TearFlags = q.TearFlags | BitSet128(1<<1,0) | BitSet128(1<<0,0) 
			d2.target = player
			d2.moment_move_mode = 1
			q.CollisionDamage = 1.5
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_QINGS_KNIFE_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local player = auxi.check_spawner_player(ent)
	if player and auxi.has_have_coll(player,item.entity) and player:GetData().__Index and (save.elses[item.own_key.."reverse"][player:GetData().__Index] or 1) ~= -1 then
		if d.moment_counter == nil then d.moment_counter = 0 end
		d.moment_counter = d.moment_counter - 1
		if d.moment_counter <= 0 and not col.IsGrid and col:IsVulnerableEnemy() and col:IsActiveEnemy() and (not col:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and col:CanShutDoors() == true then
			d.moment_counter = 15
			local pos = col.Position
			local q = Isaac.Spawn(2,0,0,pos,auxi.MakeVector(math.random(3600)/10) * (math.random(50)/10 + 2) + ent.Velocity * 0.5,player):ToTear() q.Mass = 0
			local s2 = q:GetSprite()
			s2.Color = auxi.AddColor(s.Color,Color(1,1,1,1,1,1,1),0.5,0.5)
			local d2 = q:GetData()
			d2.is_moment = true
			d2.Ignore_me_flag = true
			d2.ignore_field = true
			q.TearFlags = q.TearFlags | BitSet128(1<<1,0) | BitSet128(1<<0,0) 
			d2.target = player
			d2.moment_move_mode = 1
			q.CollisionDamage = 1.5
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local player = auxi.check_spawner_player(ent)
	if player and auxi.has_have_coll(player,item.entity) and player:GetData().__Index and (save.elses[item.own_key.."reverse"][player:GetData().__Index] or 1) ~= -1 then
		local should_count = false
		if (ent:IsCircleLaser() and ent.FrameCount % 14 == 1) then should_count = true end
		if (ent:IsCircleLaser() == false and ent.FrameCount % 7 == 1) then should_count = true end
		if ent:GetData().should_ignore_modifier then should_count = false end
		if should_count then
			local cnt = 1
			if ent.Variant == 1 or ent.Variant == 3 or ent.Variant == 5 or ent.Variant == 6 or ent.Variant == 9 or ent.Variant == 11 or ent.Variant == 12 or ent.Variant == 14 or ent.Variant == 15 then cnt = cnt + 2 end
			if ent.Variant == 6 or ent.Variant == 9 or ent.Variant == 11 or ent.Variant == 12 or ent.Variant == 14 or ent.Variant == 15 then cnt = cnt + 2 end
			if ent.MaxDistance > 0 then 
				if ent.MaxDistance <= 35 then cnt = math.max(1,cnt - 2) end
				if ent.MaxDistance <= 100 then cnt = math.max(1,cnt - 1) end
			end
			local rate = math.min(1,ent.CollisionDamage/player.Damage) cnt = auxi.random_c(cnt * rate)
			local pos = ent.EndPoint
			local vel_offset = Vector(0,0)
			if ent:IsCircleLaser() then 
				pos = ent.Position 
				vel_offset = ent.Velocity
			end
			for i = 1,cnt do
				local q = Isaac.Spawn(2,0,0,pos,auxi.MakeVector(math.random(3600)/10) * (math.random(50)/10 + 1.5 + cnt * 0.5) + vel_offset,player):ToTear() q.Mass = 0
				local s2 = q:GetSprite()
				s2.Color = auxi.AddColor(s.Color,Color(1,0,0,1,1,0.3,0.3),0.6,0.4)
				local d2 = q:GetData()
				d2.is_moment = true
				d2.Ignore_me_flag = true
				d2.ignore_field = true
				q.TearFlags = q.TearFlags | BitSet128(1<<1,0) | BitSet128(1<<0,0) 
				d2.target = player
				d2.moment_move_mode = 1
				q.CollisionDamage = 1.5
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_BOMB_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local player = auxi.check_spawner_player(ent)
	if player and auxi.has_have_coll(player,item.entity) and player:GetData().__Index and (save.elses[item.own_key.."reverse"][player:GetData().__Index] or 1) ~= -1 then
		if s:IsPlaying("Explode") and s:GetFrame() == 0 then
			local cnt = 6
			for i = 1,cnt do
				local pos = ent.Position
				local q = Isaac.Spawn(2,0,0,pos,auxi.MakeVector(math.random(3600)/10) * (math.random(50)/10 + 2),player):ToTear() q.Mass = 0
				local s2 = q:GetSprite()
				s2.Color = auxi.AddColor(s.Color,Color(1,1,1,1,1,1,1),0.8,0.2)
				local d2 = q:GetData()
				d2.is_moment = true
				d2.ignore_field = true
				d2.Ignore_me_flag = true
				q.TearFlags = q.TearFlags | BitSet128(1<<1,0) | BitSet128(1<<0,0) 
				d2.target = player
				d2.moment_move_mode = 1
				q.CollisionDamage = 1.5
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 1000,
Function = function(_,ent)
	if ent.Variant == EffectVariant.ROCKET then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local player = auxi.check_spawner_player(ent)
		if player and auxi.has_have_coll(player,item.entity) and player:GetData().__Index and (save.elses[item.own_key.."reverse"][player:GetData().__Index] or 1) ~= -1 then
			local cnt = 6
			for i = 1,cnt do
				local pos = ent.Position
				local q = Isaac.Spawn(2,0,0,pos,auxi.MakeVector(math.random(3600)/10) * (math.random(50)/10 + 4),player):ToTear() q.Mass = 0
				local s2 = q:GetSprite()
				s2.Color = auxi.AddColor(s.Color,Color(1,1,1,1,1,1,1),0.8,0.2)
				local d2 = q:GetData()
				d2.is_moment = true
				d2.Ignore_me_flag = true
				q.TearFlags = q.TearFlags | BitSet128(1<<1,0) | BitSet128(1<<0,0) 
				d2.target = player
				d2.moment_move_mode = 1
				d2.ignore_field = true
				q.CollisionDamage = 1.5
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 2,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d.is_moment == nil then
		local player = Game():GetPlayer(0)
		local player = auxi.check_spawner_player(ent)
		if player and auxi.has_have_coll(player,item.entity) and player:GetData().__Index and ((save.elses[item.own_key.."reverse"] or {})[player:GetData().__Index] or 1) ~= -1 then
			local q = Isaac.Spawn(2,0,0,ent.Position,ent.Velocity,player):ToTear() q.Mass = 0
			local s2 = q:GetSprite()
			s2:Load(s:GetFilename(),true)
			s2:Play(s:GetAnimation(),true)
			s2:PlayOverlay(s:GetOverlayAnimation(),true)
			s2.Color = auxi.AddColor(s.Color,Color(1,1,1,0.5,1,1,1),0.5,0.5)
			local d2 = q:GetData()
			d2.is_moment = true
			d2.moment_move_mode = 0
			d2.Ignore_me_flag = true
			d2.ignore_field = true
			q.TearFlags = q.TearFlags | BitSet128(1<<1,0) | BitSet128(1<<0,0) 
			d2.target = player
			q.CollisionDamage = 1.5
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	if auxi.has_have_coll(player,item.entity) then
		local idx = player:GetData().__Index
		if idx and ((save.elses[item.own_key.."reverse"] or {})[idx] or 1) == -1 then
			local name = value.Name
			local des = value.Description
			return {Name = auxi.reverse_string(name),Description = auxi.reverse_string(des),}
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_EVERY_ENTITY_INIT, params = nil,
Function = function(_,ent)
	local should_count = item.should_reverse()
	if should_count and auxi.check_if_any(item.not_reversable[ent.Type],ent) ~= true then
		ent:GetData().moment_succ = Attribute_holder.try_hold_attribute(ent,"Sprite_FlipY",true,Attribute_holder.descriptors.sprite_field("FlipY"))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if item.should_reverse() then
		reverse_grid()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		if player.FrameCount % 5 == 1 then 
			local idx = player:GetData().__Index
			if idx then
				local total = 0
				save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
				if save.elses[item.own_key.."release"][idx] then
					if auxi.should_do_Seija(player) then
						for u,v in pairs(item.buffs) do
							total = total + (save.elses[item.own_key.."buff"][idx][v.name] or 0)
						end
					else
						for u,v in pairs(item.buffs) do
							if save.elses[item.own_key.."buff"][idx][v.name] then
								save.elses[item.own_key.."buff"][idx][v.name] = math.max(0,math.min(save.elses[item.own_key.."buff"][idx][v.name] - 0.08,save.elses[item.own_key.."buff"][idx][v.name] * 0.998))
								total = total + save.elses[item.own_key.."buff"][idx][v.name]
							end
						end
					end
					player:AddCacheFlags(CacheFlag.CACHE_ALL)
					player:GetData().should_evaluate_on_update_once = true
				else
					for u,v in pairs(item.buffs) do
						total = total + (save.elses[item.own_key.."buff"][idx][v.name] or 0)
					end
				end
				if total > 999 then
					if (save.elses[item.own_key.."reverse"][idx] or 1) ~= -1 then
						local room = Game():GetRoom()
						for i = 1,5 do
							delay_buffer.addeffe(function(params)
								player:AnimateCollectible(item.entity,"Pickup")
								local stack = (i - 1) * 3 + 1
								for j = 1,stack do
									room:MamaMegaExplosion(player.Position + auxi.MakeVector(math.random(360) + j * (360 / stack)) * i * 40)
								end
							end,{},(i - 1) * 7)
							delay_buffer.addeffe(function(params)
								player:AnimateSad()
								local stack = (i - 1) * 3 + 1
								for j = 1,stack do
									room:MamaMegaExplosion(player.Position + auxi.MakeVector(math.random(360) + j * (360 / stack)) * i * 40)
								end
							end,{},(i - 1) * 7 + 3)
						end
						local language = Options.Language
						if item.words[language] == nil then language = "en" end
						local word = item.words[language][1]
						local name = word.Name
						local des = word.Description
						item_displaying_holder.check_and_description("ItemDesc",item.entity,name,des,player)
						delay_buffer.addeffe(function(params)
							player:SetColor(Color(-1,-1,-1,1,-1,-1,-1),60,70,false,false)
							reverse_grid()
							local n_entity = Isaac.GetRoomEntities()
							for u,v in pairs(n_entity) do
								if v.Type ~= 1 then
							local succ = Attribute_holder.try_hold_attribute(v,"Sprite_FlipY",true,Attribute_holder.descriptors.sprite_field("FlipY"))
									if succ then v:GetData().moment_succ = succ end
								end
							end
						end,{},13)
						local level = Game():GetLevel()
						local rooms = level:GetRooms()
						for i = 1, rooms.Size do
							local room = rooms:Get(i - 1)
							if room and room.SafeGridIndex then
								local roomdesc = level:GetRoomByIdx(room.SafeGridIndex)
								if roomdesc then
									if math.random(100) > 70 then
										roomdesc.Flags = roomdesc.Flags | RoomDescriptor.FLAG_FLOODED
									end
								end
							end
						end
						save.elses[item.own_key.."reverse"][idx] = -1
						save.elses[item.own_key.."warming"][idx] = 7
					end
				elseif total > 300 then
					if save.elses[item.own_key.."release"][idx] ~= true then
						local language = Options.Language
						if item.words[language] == nil then language = "en" end
						local word = item.words[language][2]
						if auxi.should_do_Seija(player) then word = item.words[language][8] end
						local name = word.Name
						local des = word.Description
						item_displaying_holder.check_and_description("ItemDesc",item.entity,name,des,player)
						for i = 1,30 do
							delay_buffer.addeffe(function(params)
								sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE,1.5,i/40 + 0.5,false,0,2)
							end,{},i)
						end
						sound_tracker.PlayStackedSound(enums.SoundEffect.Machine,1,1,false,0,2)
						save.elses[item.own_key.."release"][idx] = true
					end
				elseif total < 3 then
					if (save.elses[item.own_key.."reverse"][idx] or 1) ~= 1 then
						local language = Options.Language
						if item.words[language] == nil then language = "en" end
						local word = item.words[language][7]
						local name = word.Name
						local des = word.Description
						item_displaying_holder.check_and_description("ItemDesc",item.entity,name,des,player)
					end
					save.elses[item.own_key.."release"][idx] = nil
					if (save.elses[item.own_key.."reverse"][idx] or 1) == -1 then
						player:AnimateCollectible(item.entity,"Pickup")
						player:SetColor(Color(1,1,1,1,0,0,0),60,70,false,false)
						local n_entity = Isaac.GetRoomEntities()
						for u,v in pairs(n_entity) do
							if v:GetData().moment_succ then
								local succ = Attribute_holder.try_rewind_attribute(v,"Sprite_FlipY",v:GetData().moment_succ,{toget = function(ent) return ent:GetSprite().FlipY end,tochange = function(ent,value) ent:GetSprite().FlipY = value end,})
							end
						end
						reverse_grid(false)
						save.elses[item.own_key.."reverse"][idx] = 1
						save.elses[item.own_key.."warming"][idx] = 0
					end
				end
				local should_desc = nil
				save.elses[item.own_key.."warming"][idx] = save.elses[item.own_key.."warming"][idx] or 0
				if (save.elses[item.own_key.."reverse"][idx] or 1) == 1 then
					if total > 950 and save.elses[item.own_key.."warming"][idx] < 6 then
						should_desc = 6
					elseif total > 885 and save.elses[item.own_key.."warming"][idx] < 5 then
						should_desc = 5
					elseif total > 800 and save.elses[item.own_key.."warming"][idx] < 4 then
						should_desc = 4
					elseif total > 550 and save.elses[item.own_key.."warming"][idx] < 3 then
						should_desc = 3
					end
				else
					if total < 550 and save.elses[item.own_key.."warming"][idx] > 3 then
						should_desc = 3
					elseif total < 800 and save.elses[item.own_key.."warming"][idx] > 4 then
						should_desc = 4
					elseif total < 885 and save.elses[item.own_key.."warming"][idx] > 5 then
						should_desc = 5
					elseif total < 950 and save.elses[item.own_key.."warming"][idx] > 6 then
						should_desc = 6
					end
				end
				if should_desc then
					save.elses[item.own_key.."warming"][idx] = should_desc
					local language = Options.Language
					if item.words[language] == nil then language = "en" end
					local word = item.words[language][should_desc]
					local name = word.Name
					local des = word.Description
					item_displaying_holder.check_and_description("ItemDesc",item.entity,name,des,player)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d.is_moment then
		local s = ent:GetSprite()
		local player = Game():GetPlayer(0)
		if ent.SpawnerEntity and ent.SpawnerEntity.Type == 1 and ent.SpawnerEntity:ToPlayer() then player = ent.SpawnerEntity:ToPlayer() end
		if d.tail and d.tail:Exists() and d.tail:IsDead() ~= true then
			d.tail.Position = ent.Position + Vector(0,-24)
		else
			local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL, 0, ent.Position, Vector(0,0), ent):ToEffect()
			d.tail = q
			q.MinRadius = 0.15
			q.MaxRadius = 0.15
			q.SpriteScale = Vector(2,2)
			q.Parent = ent
			q:SetColor(auxi.AddColor(s.Color,Color(1, 1, 1, 1, 1, 1, 1),0.5,0.5), -1, 0)
			ent.Child = q
		end
		s.Rotation = ent.Velocity:GetAngleDegrees()
		ent.FallingSpeed = 0
		ent.Height = - 24
		if d.target then
			if d.moment_move_mode == nil then d.moment_move_mode = 0 end
			if d.moment_move_mode == 1 then
				if (d.target.Position - ent.Position):Length() < 20 then
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SOUL_PICKUP,0.3,1,false,0,2)
					local player = d.target:ToPlayer()
					if player then 
						reward(player)
					end
					ent:Remove()
				elseif (d.target.Position - ent.Position):Length() < 50 then
					ent.Velocity = (d.target.Position - ent.Position):Normalized() * math.max(math.max(4,d.target.Velocity:Length() * 1.2),ent.Velocity:Length() * 0.98)
				else
					ent.Velocity = (ent.Velocity:Normalized() * math.max(0,1 - ent.FrameCount/50) + (d.target.Position - ent.Position):Normalized() * math.min(1,ent.FrameCount/50)):Normalized() * (ent.Velocity:Length() + 1.5) * 0.9
				end
			else
				if (d.target.Position - ent.Position):Length() < 20 then
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SOUL_PICKUP,0.3,1,false,0,2)
					local player = d.target:ToPlayer()
					if player and auxi.has_have_coll(player,item.entity) then
						reward(player)
					end
					ent:Remove()
				elseif (d.target.Position - ent.Position):Length() < 50 then
					ent.Velocity = (d.target.Position - ent.Position):Normalized() * math.max(math.max(4,d.target.Velocity:Length() * 1.2),ent.Velocity:Length() * 0.98)
				else
					ent.Velocity = (ent.Velocity:Normalized() + (d.target.Position - ent.Position) * 0.1):Normalized() * (ent.Velocity:Length() + 1.5) * 0.9
				end
			end
		end
	end
	if ent.TearFlags & BitSet128(0,1<<(127-64)) == BitSet128(0,1<<(127-64)) then
		local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
		if player and auxi.has_have_coll(player,item.entity) then
			if ent.FrameCount % 25 == 1 then
				local s = ent:GetSprite()
				if ent.Velocity:Length() > 0.5 then
					local pos = ent.Position
					local q = Isaac.Spawn(2,0,0,pos,auxi.MakeVector(math.random(60) - 30 + ent.Velocity:GetAngleDegrees()) * (math.random(50)/10 + 2),player):ToTear() q.Mass = 0
					local s2 = q:GetSprite()
					s2.Color = auxi.AddColor(s.Color,Color(1,1,1,1,1,1,1),0.8,0.2)
					local d2 = q:GetData()
					d2.is_moment = true
					d2.ignore_field = true
					d2.Ignore_me_flag = true
					q.TearFlags = q.TearFlags | BitSet128(1<<1,0) | BitSet128(1<<0,0) 
					d2.target = player
					d2.moment_move_mode = 1
					q.CollisionDamage = 1.5
				else
					local pos = ent.Position
					local q = Isaac.Spawn(2,0,0,pos,auxi.MakeVector(math.random(3600)/10) * (math.random(50)/10 + 2),player):ToTear() q.Mass = 0
					local s2 = q:GetSprite()
					s2.Color = auxi.AddColor(s.Color,Color(1,1,1,1,1,1,1),0.8,0.2)
					local d2 = q:GetData()
					d2.is_moment = true
					d2.ignore_field = true
					d2.Ignore_me_flag = true
					q.TearFlags = q.TearFlags | BitSet128(1<<1,0) | BitSet128(1<<0,0) 
					d2.target = player
					d2.moment_move_mode = 1
					q.CollisionDamage = 1.5
				end
			end
		end
	end
end,
})

return item

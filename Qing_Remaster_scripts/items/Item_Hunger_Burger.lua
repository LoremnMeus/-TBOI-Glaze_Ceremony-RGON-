local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	entity = enums.Items.Hunger_Burger,
	target = 2439,
	own_key = "Item_Hunger_Burger_",
	num2chance = {
		{frame = 0,val = 1,},
		{frame = 3,val = 0.3,},
		{frame = 5,val = 0.1,},
		{frame = 7,val = 0.01,},
	},
	Colorinfo = {
		{frame = 0 * 6,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 6,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 6,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 6,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 6,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 6,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 6 * 6,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 6,
	},
	dir_map = {
		[Direction.NO_DIRECTION] = "Up",
		[Direction.LEFT] = "Right",
		[Direction.UP] = "Up",
		[Direction.RIGHT] = "Right",
		[Direction.DOWN] = "Down",
	},
	description = {
		zh_cn = {
			[CollectibleType.COLLECTIBLE_BFFS] = {desc = "饿魔宝宝伤害翻倍",},
		},
		en_us = {
			[CollectibleType.COLLECTIBLE_BFFS] = {desc = "Double the demon babies' damage",},
		},
	},
}
auxi.add_EID_item_synic(item.entity,item.description,true)
auxi.add_to_seija(item.entity)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local cnt = player:GetCollectibleNum(item.entity)
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1 * auxi.get_damage_multiplier(player) * cnt
		end
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.3 * cnt
		end
	end
end,
})

function item.check_num()
	local n_ent = auxi.getothers(nil,3,228,item.target)
	return #n_ent
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_,ent)
	if auxi.have_player_has_collectible(item.entity) and ent:IsEnemy() then
		local player = auxi.have_player_has_collectible(item.entity)
		local rng = player:GetCollectibleRNG(item.entity)
		local num = item.check_num()/math.max(1,auxi.get_collectible_num_all(item.entity))
		local info = auxi.check_lerp(num,item.num2chance)
		if rng:RandomFloat() < info.val then		--应该根据持有的宝宝数量决定
			local q = Isaac.Spawn(3,228,item.target,ent.Position,Vector(0,0),player):ToFamiliar()
			local s = q:GetSprite()
			s:Load("gfx/mimics/Hunger_Burger/burger_miniisaac.anm2",true) s:Play("Appear",true)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = 228,
Function = function(_,ent)
	if ent.SubType == item.target then
		local s = ent:GetSprite() s:Load("gfx/mimics/Hunger_Burger/burger_miniisaac.anm2",true) s:Play("Appear",true)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = 228,
Function = function(_,ent)
	if ent.SubType == item.target then
		ent.State = -1
		ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
		ent.PositionOffset = Vector(0,-10)
		local s = ent:GetSprite()
		local player = auxi.check_spawner_player(ent) or auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0) 
		if s:GetOverlayFrame() == 0 then s:PlayOverlay(s:GetOverlayAnimation(),true) end
		local d = ent:GetData()
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {counter = 0,bonus = 0,}
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		local color = auxi.check_lerp(d[item.own_key.."effect"].counter % item.Colorinfo.total,item.Colorinfo)
		s.Color = auxi.UpColor(color,0.75 * d[item.own_key.."effect"].bonus)
		local cut_off = -5
		local target = auxi.get_nearest_enemy(nil,ent.Position)
		if target then d[item.own_key.."effect"].bonus = d[item.own_key.."effect"].bonus * 0.9 + 1 * 0.1
		else 
			target = player
			if auxi.should_do_Seija(player) then 
				if d[item.own_key.."effect"].counter % 15 == 5 then 
					ent:TakeDamage(1,0,EntityRef(player),0) 
					local e = Isaac.Spawn(1000,17,0,ent.Position,Vector(0,0),nil)
					if (player.Position - ent.Position):Length() < 10 + player.Size then 
						player:TakeDamage(1,0,EntityRef(ent),60)
					end
				end
				d[item.own_key.."effect"].bonus = d[item.own_key.."effect"].bonus * 0.9 + 1 * 0.1
			else
				cut_off = 10 
				d[item.own_key.."effect"].bonus = d[item.own_key.."effect"].bonus * 0.9
			end
		end
		if target then
			local dir = (target.Position - ent.Position)
			ent.Velocity = ent.Velocity * 0.8 + dir:Normalized() * math.max(0,math.min(16,(dir:Length() - cut_off)/2)) * 0.2
		end
		ent.Velocity = auxi.apply_friction(ent.Velocity,1)
		local anim = "Fly" .. auxi.Get_dir_name_by_vel(ent.Velocity,item.dir_map) s:Play(anim)
		if ent.Velocity.X < 0 then s.FlipX = true else s.FlipX = false end
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BFFS) then ent.CollisionDamage = player.Damage * 0.3
		else ent.CollisionDamage = player.Damage * 0.15 end
		
		local n_tgs = auxi.getothers(3,228,item.target)
		for u,v in pairs(n_tgs) do 
			if auxi.check_for_the_same(ent,v) ~= true then
				local dir = v.Position - ent.Position
				if (dir:Length() < 7) then v.Velocity = v.Velocity + math.min(7 - dir:Length(), 0.5) * dir:Normalized() end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = 228,
Function = function(_,ent,col,low)
	if ent.Type == 3 and ent.Variant == 228 and ent.SubType == item.target then
		local player = auxi.check_spawner_player(ent)
		if auxi.isenemies(col) then
			local rng = player:GetCollectibleRNG(item.entity)
			if rng:RandomFloat() < 0.1 then col:AddFear(EntityRef(player),3 * 60) end
		end
	end
end,
})

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Cursed_Mask,
	own_key = "Item_Cursed_Mask_",
	rotate_info = {
		{frame = 0,speed = 5,},
		{frame = 15 * 60,speed = 2.5,},
		{frame = 25 * 60,speed = 1,},
		total = 25 * 60,
	},
	dirs = {
		[4] = Vector(-1,0),
		[5] = Vector(1,0),
		[6] = Vector(0,-1),
		[7] = Vector(0,1),
	},
	description = {
		[CollectibleType.COLLECTIBLE_EPIC_FETUS] = {desc = "按上方向键准星沿线前进，按下方向键回收准星",},
		[CollectibleType.COLLECTIBLE_MARKED] = {desc = "按上方向键准星沿线前进，按下方向键回收准星",},
		[CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT] = {desc = "按上方向键准星沿线前进，按下方向键回收准星",},
		[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {desc = "按上方向键准星沿线前进，按下方向键回收准星",},
		[CollectibleType.COLLECTIBLE_BLACK_CANDLE] = {desc = "保留属性且失去旋转的负面效果",},
	},
}
auxi.add_EID_item_synic(item.entity,item.description)
auxi.add_to_seija(item.entity)

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	if auxi.has_have_coll(player,item.entity) then 
		value[465] = (value[465] or 0) + 1
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			local d = player:GetData()
			local cnt = player:GetCollectibleNum(item.entity)
			local idx = player:GetData().__Index
			player.Damage = player.Damage + cnt * auxi.get_damage_multiplier(player) * 2
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY and auxi.should_do_Seija(player,true) then
			local cnt = player:GetCollectibleNum(item.entity)
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * cnt * 2)
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_REASSIGN_IMITATE_ITEM, params = nil,
Function = function(_,player)
	local d = player:GetData()
	if auxi.has_have_coll(player,item.entity) then 
		local itemConfig = Isaac.GetItemConfig()
		player:RemoveCostume(itemConfig:GetCollectible(465))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	if auxi.has_have_coll(player,item.entity) and d[item.own_key.."effect"] and not auxi.has_have_coll(player,260) then
		local d = player:GetData()
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		local info = auxi.check_lerp(d[item.own_key.."effect"].counter,item.rotate_info)
		if auxi.should_do_Seija(player,true) then
			d[item.own_key.."effect"].ddir = auxi.get_by_rotate(d[item.own_key.."effect"].ddir or Vector(1,0),info.speed)
			local succ = false
			local tg = auxi.get_nearest_enemy(nil,player.Position)
			if tg then
				local ddir = (tg.Position - player.Position):Normalized()
				if auxi.do_t(ddir,d[item.own_key.."effect"].ddir) > 0.5 then 
					d[item.own_key.."effect"].dir = ddir 
					succ = true
				end
			end
			if not succ then
				d[item.own_key.."effect"].dir = d[item.own_key.."effect"].dir or d[item.own_key.."effect"].ddir
				local delta = auxi.checkrounded(d[item.own_key.."effect"].dir:GetAngleDegrees(),d[item.own_key.."effect"].ddir:GetAngleDegrees(),-0.5,0.5,360)
				if math.abs(delta) < 5 then d[item.own_key.."effect"].dir = d[item.own_key.."effect"].ddir
				else d[item.own_key.."effect"].dir = auxi.get_by_rotate(d[item.own_key.."effect"].dir,delta) end
			end
		else d[item.own_key.."effect"].dir = auxi.get_by_rotate(d[item.own_key.."effect"].dir or Vector(1,0),info.speed) end
		if auxi.check_all_exists(d[item.own_key.."effect"].linker) ~= true then
			local q = Isaac.Spawn(1000,enums.Entities.Cursed_Linker,0,player.Position,Vector(0,0),nil)
			d[item.own_key.."effect"].linker = q
			q.Parent = player
		else 
			local q = d[item.own_key.."effect"].linker
			q.Position = player.Position
			q:GetSprite().Rotation = d[item.own_key.."effect"].dir:GetAngleDegrees() - 90
			if d[item.own_key.."effect"].counter == item.rotate_info.total - 5 * 2 then q:GetSprite():Play("Remove",true) end
		end
		if d[item.own_key.."effect"].counter > item.rotate_info.total then d[item.own_key.."effect"] = nil end
	end
end,
})

function item.work_on_marked(ent,addvel)
	local player = auxi.check_spawner_player(ent)
	if player then
		local d = player:GetData()
		if auxi.has_have_coll(player,item.entity) and d[item.own_key.."effect"] and not auxi.has_have_coll(player,260) then
			d[item.own_key.."effect"].Targeter = ent
			local dir = d[item.own_key.."effect"].dir or Vector(1,0)
			ent.Velocity = Game():GetRoom():GetClampedPosition(player.Position + player.Velocity + auxi.get_by_rotate(dir,0,(ent.Position - player.Position):Length()),0) - ent.Position
			if ent.Velocity:Length() < 1 then ent.Velocity = ent.Velocity * 0.5 end
			if addvel then 
				local gdir = auxi.ggdir(player,true,nil,nil,nil,{real = true}) or Vector(0,0)
				if gdir.Y < -0.707 then ent.Velocity = ent.Velocity + dir * player.ShotSpeed * 10
				elseif gdir.Y > 0.707 then 
					ent.Velocity = ent.Velocity - dir * math.min(ent.Velocity:Length() * 0.9,player.ShotSpeed * 10)
				end
				ent.Velocity = Game():GetRoom():GetClampedPosition(ent.Velocity + ent.Position,0) - ent.Position
			end
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = EffectVariant.TARGET,
Function = function(_,ent)
	item.work_on_marked(ent)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = EffectVariant.OCCULT_TARGET,
Function = function(_,ent)
	item.work_on_marked(ent)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.QingsMarks,
Function = function(_,ent)
	item.work_on_marked(ent,true)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	if ent.TearFlags & BitSet128(0,1<<(127-64)) == BitSet128(0,1<<(127-64)) then item.work_on_marked(ent) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Cursed_Linker,
Function = function(_,ent)
	if auxi.check_all_exists(ent.Parent) ~= true then ent:Remove() return
	else
		local player = ent.Parent:ToPlayer()
		if player == nil or (auxi.has_have_coll(player,item.entity) and player:GetData()[item.own_key.."effect"] and not auxi.has_have_coll(player,260)) ~= true then ent:Remove() return end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		player:GetData()[item.own_key.."effect"] = {}
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if ent ~= nil then
		local player = ent:ToPlayer()
		if player and auxi.has_have_coll(player,item.entity) and not auxi.has_have_coll(player,260) then
			local d = player:GetData()
			if d[item.own_key.."effect"] then
				local dir = d[item.own_key.."effect"].dir or Vector(0,1)
				if Game():GetRoom():IsMirrorWorld() == true then dir = Vector(-dir.X,dir.Y) end
				local gdir = auxi.ggdir(player,true,nil,nil,nil,{real = true}) or Vector(0,0)
				if gdir:Length() > 0.05 then
					if item.dirs[button] then
						local info = item.dirs[button] or Vector(0,0)
						local val = info.X * dir.X + info.Y * dir.Y
						if (hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED) then
							if val > 0.707 then return true 
							else return false end
						elseif hook == InputHook.GET_ACTION_VALUE then 
							if auxi.check_all_exists(d[item.own_key.."effect"].Targeter) then 
								if val > 0.707 and gdir.Y < -0.707 then 
								elseif val < -0.707 and gdir.Y > 0.707 then val = - val 
								else val = val * 0.01 end
							end
							return val 
						end
					end
				else
					if item.dirs[button] then
						if (hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED) then return false end
					end
				end
			end
		end
	end
end,
})

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Risemara,
	buffs = {
		[1] = {name = "speed",cache = CacheFlag.CACHE_SPEED,
			toget = function(player) return player.MoveSpeed end,mul = 0.6,},
		[2] = {name = "tear",cache = CacheFlag.CACHE_FIREDELAY,
			toget = function(player) return 30 / (player.MaxFireDelay + 1) end,mul = 1.5,},
		[3] = {name = "damage",cache = CacheFlag.CACHE_DAMAGE,
			toget = function(player) return player.Damage end,mul = 3,},
		[4] = {name = "range",cache = CacheFlag.CACHE_RANGE,
			toget = function(player) return player.TearRange end,mul = 4.5 * 40,},
		[5] = {name = "shotspeed",cache = CacheFlag.CACHE_SHOTSPEED,
			toget = function(player) return player.ShotSpeed end,mul = 0.6,},
		[6] = {name = "luck",cache = CacheFlag.CACHE_LUCK,
			toget = function(player) return player.Luck end,mul = 6,},
	},
	ids = {
		[1] = {id = 0,weigh = 10,vi = 4,},
		[2] = {id = 1,weigh = 10,vi = 3,},
		[3] = {id = 2,weigh = 9,vi = 2,},
		[4] = {id = 3,weigh = 8,vi = 1,},
		[5] = {id = -1,weigh = 14,vi = 5,},
		[6] = {id = -2,weigh = 12,vi = 6,},
		[7] = {id = -3,weigh = 12,vi = 7,},
	},
	own_key = "Item_Risemara_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."buff"] = {}
		save.elses[item.own_key.."effect"] = nil
	end
	save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = nil
end,
})

function item.initialize_a_buff(player)
	local rng = player:GetCollectibleRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	local ret = {}
	local itdx = -90
	for u,v in pairs(item.buffs) do
		local info = auxi.random_in_weighed_table(item.ids,rng)
		ret[v.name] = info.id/3
		
		local q = auxi.fire_nil(player.Position,Vector(0,0),{cooldown = 60,})
		q.DepthOffset = 100
		local s = q:GetSprite()
		s:Load("gfx/mimics/Risemara/Risamara_grades.anm2",true)
		s:ReplaceSpritesheet(0,"gfx/effects/grades/grade_"..tostring(info.vi)..".png")
		s:ReplaceSpritesheet(2,"gfx/ui/status/"..(v.name)..".png")
		s:LoadGraphics()
		s.Offset = Vector(64,0) + Vector(0,itdx)
		itdx = itdx + 30
		s:Play("Idle",true)
		
		local d = q:GetData()
		d.nil_mode = "risemara"
		d[item.own_key.."effect"] = true
	end
	return ret
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 100,
Function = function(_,ent)
	if ent.SubType == item.entity then
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ then
		else
			consistance_holder.try_hold_entity(ent,item.own_key,{ignore_subtype = true,})
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 100,
Function = function(_,ent,col,low)
	if ent.SubType == 0 and col:ToPlayer() then
		local player = col:ToPlayer()
		local d2 = player:GetData()
		if d2[item.own_key.."effect"] then
			local succ = consistance_holder.try_check_entity(ent,item.own_key)
			if succ then
				player:RemoveCollectible(item.entity)
				player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
				d2[item.own_key.."effect"] = nil
				ent:Morph(5,100,item.entity,true,true,true)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if save.elses[item.own_key.."effect"] then
		local d = player:GetData()
		if auxi.has_have_coll(player,item.entity) then
			local n_pickup = auxi.getothers(nil,5,100,0,function(ent) if consistance_holder.try_check_entity(ent,item.own_key) and (ent.Position - player.Position):Length() < 80 then return true end end)
			if player:IsExtraAnimationFinished() then
				if #n_pickup > 0 then
					d[item.own_key.."effect"] = true
					player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
				end
			elseif d[item.own_key.."effect"] then
				if #n_pickup == 0 then
					player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
					d[item.own_key.."effect"] = nil
				end
			end
		else
			d[item.own_key.."effect"] = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local idx = player:GetData().__Index
		if idx ~= nil then
			save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
			if save.elses[item.own_key.."buff"][idx] then
				for u,v in pairs(save.elses[item.own_key.."buff"][idx]) do
					if cacheFlag == CacheFlag.CACHE_SPEED then
						player.MoveSpeed = player.MoveSpeed + (v.speed or 0) * item.buffs[1].mul
					end
					if cacheFlag == CacheFlag.CACHE_FIREDELAY then
						player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * (v.tear or 0) * item.buffs[2].mul)
					end
					if cacheFlag == CacheFlag.CACHE_DAMAGE then
						player.Damage = player.Damage + auxi.get_damage_multiplier(player) * (v.damage or 0) * item.buffs[3].mul
					end
					if cacheFlag == CacheFlag.CACHE_RANGE then
						player.TearRange = player.TearRange + (v.range or 0) * item.buffs[4].mul
					end
					if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
						player.ShotSpeed = player.ShotSpeed + (v.shotspeed or 0) * item.buffs[5].mul
					end
					if cacheFlag == CacheFlag.CACHE_LUCK then
						player.Luck = player.Luck + (v.luck or 0) * item.buffs[6].mul
					end
				end
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,count,curnum)
	local idx = player:GetData().__Index
	if idx then
		local num = curnum + count
		save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
		save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
		if #save.elses[item.own_key.."buff"][idx] < num then
			for i = #save.elses[item.own_key.."buff"][idx] + 1,num do
				save.elses[item.own_key.."buff"][idx][i] = item.initialize_a_buff(player)
			end
		else
			for i = #save.elses[item.own_key.."buff"][idx],num,-1 do
				table.remove(save.elses[item.own_key.."buff"][idx],i)
			end
		end
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
		save.elses[item.own_key.."effect"] = true
	end
end,
})

Nil_holder.register("risemara", {
	detect = function(d) return d[item.own_key.."effect"] end,
	update = function(ent, d, s, player)
		if s:IsFinished("Idle") then ent:Remove() return end
	end,
})

return item
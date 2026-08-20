local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local Baby_Anim = require("Qing_Remaster_scripts.others.Baby_Anim_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Baby_Anna,
	familiar = enums.Familiars.Baby_Anna,
	own_key = "Item_Baby_Anna_",
	max_charge = 60,
	min_charge = 30,
	speed = 20,
	max_speed = 40,
	acceleration = 0.5,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_FAMILIAR_RENDER, params = item.familiar,
Function = function(_,ent,offset)
	local d = ent:GetData()
	local cnt = (d[item.own_key.."charging"] or {}).progress or 0
	Charging_Bar_holder.render_me(ent,{name1 = item.own_key.."counter",name2 = item.own_key.."sprite",name3 = item.own_key,loadname = "gfx/effects/chargebar/chargebar_Baby_Tecro.anm2",
		check1 = function(val,ent)
			return cnt > 5
		end,
		check2 = function(val,ent) 
			return cnt >= item["max_charge"]
		end,
		check3 = function(val,ent)
			return math.ceil(cnt/item["max_charge"] * 100)
		end,
		signal1 = function(ent)
		end,
	})
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_, ent)
	local player = auxi.check_spawner_player(ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	
	if d[item.own_key.."launchData"] then
		-- 跟随逻辑
		if d[item.own_key.."IsFollow"] then
			ent:RemoveFromFollowers()
			d[item.own_key.."IsFollow"] = nil
		end
		local launchData = d[item.own_key.."launchData"]
		s.Rotation = launchData.direction:GetAngleDegrees() + 90
		
		for _ = 1,1 do if launchData.stop then
			ent.Velocity = Vector(0,0)
			launchData.counter = (launchData.counter or 0) + 1
			if launchData.counter > (launchData.mxcnt or 6) then 
				if auxi.check_if_any(d[item.own_key.."launchData"].tail) then
					d[item.own_key.."launchData"].tail:SetTimeout(1)
				end
				d[item.own_key.."launchData"] = nil
				Baby_Anim.reset(ent, item.own_key.."float")
				s:Play("Float", true)
				break
			end
		else
			if (launchData.speed < item.max_speed) then	launchData.speed = launchData.speed + launchData.acceleration end
			ent.Velocity = launchData.direction * launchData.speed
			
			-- 使用 find_dir 进行精确反弹
			local room = Game():GetRoom()
			if not room:IsPositionInRoom(ent.Position + ent.Velocity,launchData.margin or 0) then
				launchData.stop = true
				ent.Velocity = Vector(0,0)
			end
		end
		if not auxi.check_all_exists(d[item.own_key.."launchData"].tail) then
			local info = auxi.judge_by_brimstone(player)
			local q = Isaac.Spawn(7,info.tp,0,ent.Position,Vector(0,0),ent):ToLaser()
			delay_buffer.addeffe(function(params) SFXManager():Stop(7) end,{},1)
			q.CollisionDamage = info.dmg * 0.5
			q.Parent = ent
			d[item.own_key.."launchData"].tail = q
		end 
		local q = d[item.own_key.."launchData"].tail 
		q.Angle = 180 + launchData.direction:GetAngleDegrees()
		end
	else
		-- 跟随逻辑
		if not d[item.own_key.."IsFollow"] then
			ent:AddToFollowers()
			d[item.own_key.."IsFollow"] = true
		end
		Baby_Anim.tick_float_idle(ent, item.own_key.."float")
		if Baby_Anim.is_float_idle_anim(s:GetAnimation()) then
			ent:FollowParent()
		end
		s.Rotation = 0
		-- 初始化蓄力数据
		if not d[item.own_key.."charging"] then
			d[item.own_key.."charging"] = {
				progress = 0,
				maxCharge = item.max_charge,
				minCharge = item.min_charge,
				isCharged = false,
				lastInput = false,
				storedDir = Vector(0, 0)
			}
		end
		
		local chargeData = d[item.own_key.."charging"]
		
		-- 获取玩家输入方向
		local dir = auxi.ggdir(player, true, false, false, nil, {real = true})
		local isInput = dir:Length() > 0.1
		
		-- 按下时蓄力并记录方向
		if isInput then
			if not chargeData.lastInput then
				-- 刚开始按下
				chargeData.progress = 0
			end
			chargeData.storedDir = (dir * 2 + player.Velocity:Normalized()):Normalized()
			chargeData.progress = math.min(chargeData.progress + 1, chargeData.maxCharge)
		end
		
		-- 松开时发射
		if chargeData.lastInput and not isInput then
			-- 检查最小蓄力时间
			if chargeData.progress >= chargeData.minCharge then
				-- 发射
				local rate = (chargeData.progress / chargeData.maxCharge)
				Baby_Anim.reset(ent, item.own_key.."float")
				d[item.own_key.."launchData"] = {
					direction = chargeData.storedDir,
					speed = item.speed * math.sqrt(rate),
					acceleration = item.acceleration,
					mxcnt = 20 * rate * rate,
					bounces = 3,
					margin = 0,
				}
				--s:Play("Attack")
			end
			-- 重置蓄力
			chargeData.progress = 0
			chargeData.storedDir = Vector(0, 0)
		end
		
		-- 记录当前输入状态
		chargeData.lastInput = isInput
	end
end
})

return item
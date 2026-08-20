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
	entity = enums.Items.Baby_Tecro,
	familiar = enums.Familiars.Baby_Tecro,
	own_key = "Item_Baby_Tecro_",
	max_charge = 60,
	min_charge = 30,
	speed = 20,
	max_speed = 80,
	acceleration = 1,
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

function item.find_dir(pos,dir)
	local room = Game():GetRoom()
	local center = auxi.get_near_grid_position(pos)--room:GetGridPosition(room:GetGridIndex(pos))
	local ddir = pos - center
	local ret = dir
	local epsl = 0.0001
	if math.abs(ddir.X) > epsl and math.abs(ddir.Y) < epsl then ret = Vector(ret.X,-ret.Y)
	elseif math.abs(ddir.Y) > epsl and math.abs(ddir.X) < epsl then ret = Vector(-ret.X,ret.Y)
	else
		local succ = 0
		for u,v in pairs({Vector(-ret.X,-ret.Y),Vector(ret.X,-ret.Y),Vector(-ret.X,ret.Y),}) do
			for uu,vv in pairs({40,1}) do if room:IsPositionInRoom(pos + v * vv,-20) then succ = succ + 1 ret = v break end end
		end
		if succ == 3 then ret = Vector(-ret.X,-ret.Y) end
	end
	return ret
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_, ent)
	local player = auxi.check_spawner_player(ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	ent.CollisionDamage = ent.Velocity:Length()
	
	if d[item.own_key.."launchData"] then
		if d[item.own_key.."IsFollow"] then
			ent:RemoveFromFollowers()
			d[item.own_key.."IsFollow"] = nil
		end
		local launchData = d[item.own_key.."launchData"]
		if (launchData.speed < item.max_speed) then	launchData.speed = launchData.speed + launchData.acceleration end
		ent.Velocity = launchData.direction * launchData.speed
		ent.CollisionDamage = ent.Velocity:Length()/10 * 3.5
		s.Rotation = launchData.direction:GetAngleDegrees() + 90
		-- 使用 find_dir 进行精确反弹
		local room = Game():GetRoom()
		if not room:IsPositionInRoom(ent.Position + ent.Velocity,launchData.margin or -20) then
			launchData.bounceCountDelay = launchData.bounceCountDelay or 0
			local newDir = item.find_dir(ent.Position + ent.Velocity, launchData.direction)
			launchData.direction = newDir
			-- 防止卡墙
			ent.Position = ent.Position + newDir * 5
			
			-- 处理反弹计数
			if launchData.bounceCountDelay <= 0 then
				launchData.bounces = launchData.bounces - 1
				if launchData.bounces <= 0 then
					-- 返回玩家
					d[item.own_key.."launchData"] = nil
					ent.Velocity = Vector(0, 0)
					Baby_Anim.reset(ent, item.own_key.."float")
					s:Play("Float", true)
				else
					ent.Velocity = Vector(0,0)
					launchData.bounceCountDelay = 2
				end
			end
		end
		launchData.bounceCountDelay = (launchData.bounceCountDelay or 0) - 1
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
				Baby_Anim.reset(ent, item.own_key.."float")
				d[item.own_key.."launchData"] = {
					direction = chargeData.storedDir,
					speed = item.speed * math.sqrt(chargeData.progress / chargeData.maxCharge),
					acceleration = item.acceleration * chargeData.progress / chargeData.maxCharge,
					bounces = 3,
					margin = -20,
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
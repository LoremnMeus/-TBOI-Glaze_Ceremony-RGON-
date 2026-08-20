local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_myToCall = {},
	own_key = "tear_trigger_holder_",
	frame_trigger_side = {},
	framecheck_info = {
		["Tear"] = {frame = 1,},
		["Knifecollide"] = {frame = 3,banished = true,},
		["Knifefire"] = {frame = 1,},
		["Laser"] = {frame = 5,},
		["LaserStart"] = {frame = 1,},
		["LaserEnd"] = {frame = 1,},
		["Aquarius"] = {frame = function(player,item,params,Update) 
			if player then local succ = auxi.inner_tick(player:GetData(),item.own_key.."Aquarius_effect",30,{Update = Update,})
				if succ then return 1 end end
			return 30 end,},
		["SwordBlade"] = {frame = function(player,item,params,Update) 
			if player then local succ = auxi.inner_tick(player:GetData(),item.own_key.."SwordBlade_effect",5,{Update = Update,})
				if succ then return 1 end end
			return 30 end,},
		["Aquariuscollide"] = {frame = 3,},
		["Darkart"] = {frame = 1,},
		["Gello"] = {frame = 1,},
		["Brim"] = {frame = 5,banished = true,},
		["BrimStart"] = {frame = 5,},
		["BrimEnd"] = {frame = 5,},
		["BrimFire"] = {frame = 1,},
		["LaserLudo"] = {frame = function(player) if player then return player.MaxFireDelay * 1.5 else return 5 end end,},
		["LaserX"] = {frame = 1,},
		["Dr."] = {frame = 1,},
		["Epic"] = {frame = 1,},
		["Dr. Explode"] = {frame = 1,banished = true,},
		["Ludo"] = {frame = function(player) if player then return player.MaxFireDelay * 1.5 else return 5 end end,},
	},
	dir_info = {
		["Laser"] = function(ent,dir) return auxi.get_by_rotate(dir,auxi.random_2() * 45) end,
		["LaserStart"] = function(ent,dir) return dir end,
		["LaserEnd"] = function(ent,dir) return auxi.get_by_rotate(dir,auxi.random_2() * 45) end,
		["SwordSpin"] = function(ent,dir) return - dir * 0.5 + auxi.random_r() * 1.5 end,
		["Brim"] = function(ent,dir) 
			if ent.MaxDistance == 30 then return dir + auxi.random_r() * 0.3
			else return (- dir * 2 + auxi.random_r() * 1.5):Normalized() end
			end,
		["BrimStart"] = function(ent,dir) return dir end,
		["BrimEnd"] = function(ent,dir) 
			if ent.MaxDistance == 30 then return dir + auxi.random_r() * 0.3
			else return dir + auxi.random_r() * 0.75 end
			end,
	},
	multi_info = {
		["Laser"] = function(ent,player) 
			if ent.MaxDistance > 0 then return auxi.choose(0,0,1) 
			else return auxi.choose(0,1,2) end
		end,
		["LaserStart"] = function(ent,player) return {cnt = 1,} end,
		["LaserEnd"] = function(ent,player) return {cnt = 1,} end,
		["Brim"] = function(ent,player) 
			if ent.MaxDistance == 30 then return auxi.choose(0,0,0,1) 
			elseif ent.MaxDistance > 0 then return auxi.choose(0,1) 
			else return auxi.choose(0,1,2) end
		end,
		["BrimStart"] = function(ent,player) 
			if ent.MaxDistance == 30 then return auxi.choose(0,0,0,1) 
			elseif ent.MaxDistance > 0 then return auxi.choose(0,1) 
			else return auxi.choose(0,1,2) end
		end,
		["BrimEnd"] = function(ent,player) 
			if ent.MaxDistance == 30 then return auxi.choose(0,0,0,1) 
			elseif ent.MaxDistance > 0 then return auxi.choose(0,1) 
			else return auxi.choose(0,1,2) end
		end,
		["Ludo"] = function(ent,player) return auxi.choose(0,0,1,2) end,
		["Epic"] = function(ent,player) return auxi.choose(1,2,3,4) end,
		["SwordSpin"] = function(ent,player) return auxi.choose(3,4,5,6) end,
		["Anna2"] = function(ent,player) return auxi.choose(1,2,3) end,
	},
	knife_action_list = {
		["Swing"] = "Blade",
		["SwingDown"] = "Blade",
		["Swing2"] = "Blade",
		["SwingDown2"] = "Blade",
		Default = function(str,ent,player,item)
			local dir = nil
			for u,v in pairs(item.dir_map) do
				if string.sub(str,-(#u)) == u then 
					dir = u
					break
				end
			end
			if not dir then return end
			if string.sub(str,1,6) == "Attack" then return "SwordBlade"
			elseif string.sub(str,1,4) == "Spin" then return "SwordSpin" end
		end,
	},
	knife_action_rate_list = {
		["Blade"] = 0.5,
		["SwordBlade"] = 0.15,
		["SwordSpin"] = 1,
	},
	knife_blacklist = {[4] = true,},
	dir_map = {
		["Down"] = Vector(0,1),
		["Right"] = Vector(1,0),
		["Up"] = Vector(0,-1),
		["Left"] = Vector(-1,0),
	},
}
--需要达成的任务包含：1.检查“发射眼泪”的时机。2.检查“视为发射眼泪”的时机。
--约定：1.发射眼泪时触发1次。2.发射镭射时在发射点触发1次。3.发射长硫磺火时在发射点连续触发3-4次。（同剖）4.发射炸弹时触发1次。5.发射妈刀触发1次。6.导弹落地触发1次。7.悬浮/科技悬浮每1.5倍延迟触发1次。8.黑暗艺术每次命中触发1次。9.水迹生成时每生成60份触发1次。10.骨棒/英灵剑/镐子每次挥动时触发一次。11.发射格罗时触发一次。12.自由触发工具。
--另一份任务要求：1.检查“眼泪特效触发”的时机。2.检查“视为眼泪特效触发”的时机。3.该时机不采用“受到伤害时”机制（因为该机制无需改善）。
--约定：1.眼泪碰撞敌人时触发1次。2.发射镭射时在末端触发1次。3.硫磺火持续时间中在末端触发3-4次。4.炸弹引爆时触发1次。5.妈刀碰到敌人时触发1次。

function item.multi_check(tp,ent,player)
	local ret = auxi.check_if_any(item.multi_info[tp],ent,player)
	if type(ret) == "number" then ret = {cnt = ret,} end
	return ret or {cnt = 1,}
end

function item.dir_info_check(tp,ent,dir)
	if dir and dir:Length() < 0.01 then dir = auxi.random_r() end
	dir = (dir or auxi.random_r()):Normalized()
	return (auxi.check_if_any(item.dir_info[tp],ent,dir) or dir):Normalized()
end

function item.should_ignore_trigger(ent)
	if ent == nil then return false end
	local d = ent:GetData()
	return d.Ignore_me_flag == true 
		or d.Item_Tech_9_laser == true 
		or d.Item_Tech_9_techx_laser == true
end

function item.trigger_enabled(tp)
	local settings = ModConfig.ModConfigSettings or {}
	local map = {
		LaserStart = "Trigger_LaserStart",
		LaserEnd = "Trigger_LaserEnd",
		BrimStart = "Trigger_BrimStart",
		BrimEnd = "Trigger_BrimEnd",
	}
	local key = map[tp]
	if key == nil then return true end
	if settings[key] == nil and ModConfig.get_setting then return ModConfig.get_setting(key) ~= false end
	return settings[key] ~= false
end

function item.get_current_frame()
	local game = Game()
	if game then return game:GetFrameCount() end
	return 0
end

function item.choose_trigger_side(prefix)
	local start_tp = prefix.."Start"
	local end_tp = prefix.."End"
	local start_enabled = item.trigger_enabled(start_tp)
	local end_enabled = item.trigger_enabled(end_tp)
	if start_enabled and end_enabled then
		local frame = item.get_current_frame()
		local cache = item.frame_trigger_side
		if cache == nil or cache.frame ~= frame then
			item.frame_trigger_side = {frame = frame,side = auxi.choose("Start","End"),}
			cache = item.frame_trigger_side
		end
		return cache.side
	elseif start_enabled then
		return "Start"
	elseif end_enabled then
		return "End"
	else
		return nil
	end
end

function item.get_laser_trigger_side(ent,prefix)
	if ent == nil then return item.choose_trigger_side(prefix) end
	local d = ent:GetData()
	local key = item.own_key..prefix.."_trigger_side"
	d[key] = d[key] or item.choose_trigger_side(prefix)
	return d[key]
end

function item.get_laser_start_direction(ent)
	if ent == nil then return Vector(1,0) end
	local dir = auxi.get_by_rotate(Vector(1,0),ent.Angle)
	if dir:Length() < 0.01 and ent.Velocity then dir = ent.Velocity end
	if dir:Length() < 0.01 then dir = Vector(1,0) end
	return dir:Normalized()
end

function item.get_laser_end_tangent(ent,dir)
	local ret = nil
	if ent and ent.GetSamples then
		local samples = ent:GetSamples()
		local endpoint = ent:GetEndPoint()
		if samples and #samples > 0 then
			for i = #samples - 1,0,-1 do
				ret = endpoint - samples:Get(i)
				if ret:Length() >= 0.01 then break end
			end
		elseif ent.Position then
			ret = endpoint - ent.Position
		end
	end
	if ret == nil or ret:Length() < 0.01 then ret = dir end
	if ret == nil or ret:Length() < 0.01 then ret = auxi.get_by_rotate(Vector(1,0),ent and ent.Angle or 0) end
	return ret:Normalized()
end

function item.get_laser_end_direction(ent,dir)
	dir = dir or item.get_laser_start_direction(ent)
	if ent and ent.MaxDistance == 0 then return -dir:Normalized() end
	return item.get_laser_end_tangent(ent,dir)
end

function item.framecheck(tp,ent,player,params)
	params = params or {}
	player = player or auxi.check_spawner_player(ent)
	local finfo = params[tp] or params.defaultframecheck or item.framecheck_info[tp] or {frame = 1,} if finfo.Replace then finfo = item.framecheck_info[tp] or {frame = 1,} end
	if finfo.banished then return false end
	local frame = auxi.check_if_any(finfo.frame,player,item,params,params.Update)
	local d = ent:GetData()
	local counter_key = item.own_key.."counter_"..tostring(tp)
	d[counter_key] = (d[counter_key] or frame) + 1
	if d[counter_key] >= frame then 
		d[counter_key] = 0
		return true
	end
	return false
end

function item.trigger_tear(tp,ent,pos,player,vel,rate)
	if item.trigger_enabled(tp) ~= true then return end
	callback_manager.work("POST_FIRE_TRIGGER",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,pos,player,vel,rate) end end)
end

function item.check_rate(tp,data,rate,params)
	--params = params or {}
	if rate == nil or rate <= 0 then return true else 
		local succ = auxi.random_1() < rate
		if succ then auxi.inner_tick(data,item.own_key..tp.."_rate",0,{set = true,}) return true 
		elseif auxi.inner_tick(data,item.own_key..tp.."_rate",1/rate,{Update = true,}) then return true
		else return false end
	end
end

table.insert(item.post_myToCall,#item.post_myToCall + 1,{CallBack = enums.Callbacks.POST_FIRE_TRIGGER, params = nil,
Function = function(_,tp,ent,pos,player,dir,rate)
	if item.trigger_enabled(tp) ~= true then return end
	if item.should_ignore_trigger(ent) then return end
	local succ = item.check_rate(tp,player:GetData(),rate)
	if succ and item.framecheck(tp,ent,player,{Update = true,}) then
		callback_manager.work("POST_FIRE_TRIGGER_IN_FRAME",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,pos,player,dir) end end)
	end
end,
})
	
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_FIRE_TEAR, params = nil,
Function = function(_,ent)
	if item.should_ignore_trigger(ent) then return end
	local tp = "Tear"
	local player = auxi.check_spawner_player(ent)
	if player then callback_manager.work("POST_FIRE_TRIGGER",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,nil,player,ent.Velocity) end end) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE, params = nil,
Function = function(_,ent)
	if item.should_ignore_trigger(ent) then return end
	local player = auxi.check_near_spawner_player(ent,{checklist = {"Parent",},})
	if player and item.knife_blacklist[ent.Variant] ~= true then
		local d = ent:GetData()
		if ent:IsFlying() then
			if d[item.own_key.."effect"] == nil then 
				local rate = ent.Charge
				local tp = "Knifefire"
				callback_manager.work("POST_FIRE_TRIGGER",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,nil,player,auxi.get_by_rotate(Vector(1,0),ent.Rotation),rate) end end)
				d[item.own_key.."effect"] = {}
			end
			--if ent:GetKnifeDistance() >= ent.MaxDistance then d[item.own_key.."effect"] end
		else 
			d[item.own_key.."effect"] = nil 
			local s = ent:GetSprite()
			if s:GetFrame() == 1 then 
				local tp = auxi.check_if_any(item.knife_action_list[s:GetAnimation()] or item.knife_action_list.Default,s:GetAnimation(),ent,player,item)
				if tp then
					local rate = item.knife_action_rate_list[tp]
					callback_manager.work("POST_FIRE_TRIGGER",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,nil,player,auxi.get_by_rotate(Vector(1,0),ent.Rotation),rate) end end)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_KNIFE_COLLISION, params = nil,
Function = function(_,ent,col,low)
	if item.should_ignore_trigger(ent) then return end
	local tp = "Knifecollide"
	local player = auxi.check_near_spawner_player(ent)
	if player then callback_manager.work("POST_FIRE_TRIGGER",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,col.Position,player,col.Position - ent.Position) end end) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = 240,
Function = function(_,ent)
	if item.should_ignore_trigger(ent) then return end
	local tp = "Gello"
	local player = auxi.check_near_spawner_player(ent)
	if ent.FrameCount == 5 then if player then callback_manager.work("POST_FIRE_TRIGGER",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,ent.Position,player,ent.Velocity) end end) end end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	if item.should_ignore_trigger(ent) then return end
	local tp = "Laser"
	local player = auxi.check_near_spawner_player(ent)
	if player then
		local rate = ent.CollisionDamage/player.Damage	--对手指与其他低伤害科技削弱
		if ent.MaxDistance >= 30 and ent.MaxDistance <= 100 then
			rate = rate * 0.5
		end
		if ent.SubType == 2 then
			if ent.FrameCount == 1 then
				tp = tp .. "X"
				callback_manager.work("POST_FIRE_TRIGGER",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,nil,player,ent.Velocity,rate) end end)
			end
		elseif ent.SubType == 1 then
			tp = tp .. "Ludo"
			callback_manager.work("POST_FIRE_TRIGGER",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,nil,player,ent.Velocity,rate) end end)
		elseif ent.SubType == 0 then
			if ent.Variant == 10 then return end
			if ent.Variant ~= 7 then 
				local start_dir = item.get_laser_start_direction(ent)
				local end_dir = item.get_laser_end_direction(ent,start_dir)
				if ent.Variant == 2 then
					if ent.FrameCount == 1 then
						local side = item.get_laser_trigger_side(ent,"Laser")
						if side == "Start" then
							item.trigger_tear("LaserStart",ent,ent.Position,player,start_dir,rate)
						elseif side == "End" then
							item.trigger_tear("LaserEnd",ent,ent:GetEndPoint(),player,end_dir,rate)
						end
					end
				else
					local side = item.get_laser_trigger_side(ent,"Brim")
					if side == "Start" then
						item.trigger_tear("BrimStart",ent,ent.Position,player,start_dir,rate)
					elseif side == "End" then
						item.trigger_tear("BrimEnd",ent,ent:GetEndPoint(),player,end_dir,rate)
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	if item.should_ignore_trigger(ent) then return end
	if ent.TearFlags & BitSet128(0,1<<(127-64)) == BitSet128(0,1<<(127-64)) then
		local player = auxi.check_near_spawner_player(ent)
		if player then
			local tp = "Ludo"
			callback_manager.work("POST_FIRE_TRIGGER",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,nil,player,ent.Velocity) end end)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 31,
Function = function(_,ent)
	if item.should_ignore_trigger(ent) then return end
	local player = auxi.check_near_spawner_player(ent)
	if player and ent.PositionOffset.Y >= 0 then 
		local tp = "Epic"
		callback_manager.work("POST_FIRE_TRIGGER",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,nil,player,nil) end end)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_BOMB_UPDATE, params = nil,
Function = function(_,ent)
	if item.should_ignore_trigger(ent) then return end
	local player = auxi.check_near_spawner_player(ent)
	if player and ent.IsFetus then
		if ent.FrameCount == 1 and not (Game():GetRoom():GetFrameCount() == 1 and ent.Velocity:Length() < 0.01) then 
			local tp = "Dr."
			callback_manager.work("POST_FIRE_TRIGGER",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,nil,player,ent.Velocity) end end)
		end
		local s = ent:GetSprite()
		if s:IsPlaying("Explode") and s:GetFrame() == 0 then
			local tp = "Dr. Explode"
			callback_manager.work("POST_FIRE_TRIGGER",function(funct,params) if params == nil or params == tp then funct(nil,tp,ent,nil,player,nil) end end)
		end
	end
end,
})

return item

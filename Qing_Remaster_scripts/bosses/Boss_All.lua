local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	entity = nil,
	own_key = "Boss_All_",
	Strategy = {
		{name = "Diagonally",work = function(ent,self,item)
			local d = ent:GetData()
			local info = d[item.own_key..self.name]
			local angle = ent.Velocity:GetAngleDegrees() - info.dir:GetAngleDegrees()
			if info.Force then 
				angle = 0
				if (info.counter or 0) > 0 then info.counter = (info.counter or 0) - 1 end
				if ent:CollidesWithGrid() then 
					if (info.counter or 0) <= 0 then info.dir = auxi.get_by_rotate(info.dir,(info.deltadir or 90)) info.counter = 2
					else info.dir = auxi.get_by_rotate(info.dir,(info.deltadir or -180)) end
				else info.counter = nil end
				local idangle = (math.ceil((angle-45)/90)) * 90 + 45 + info.dir:GetAngleDegrees()
				ent.Velocity = ent.Velocity * 0.5 + auxi.get_by_rotate(nil,idangle + 180,info.speed or 5) * 0.5
			else
				local idangle = (math.ceil((angle-45)/90)) * 90 + 45 + info.dir:GetAngleDegrees()
				ent.Velocity = ent.Velocity * 0.8 + auxi.get_by_rotate(nil,idangle + 180,info.speed or 5) * 0.2
			end
		end,},
		{name = "MoveEnt",work = function(ent,self,item) 
			local d = ent:GetData()
			local info = d[item.own_key..self.name]
			info.frame = (info.frame or 0) + 1
			if auxi.check_all_exists(info.tg) ~= true then d[item.own_key..self.name] = nil return true end
			local dir = (info.tg.Position - ent.Position) + (auxi.check_if_any(info.pos_offset,ent,info.frame,info) or Vector(0,0))
			local mvrate = info.mvrate or 0.9		--取为0的时候会瞬移到目标位置
			if info.frame < 3 and info.start_mvrate then mvrate = info.start_mvrate end
			ent.Velocity = ent.Velocity * mvrate + dir * (1 - mvrate)	-- * 0.5
			ent.Velocity = auxi.get_by_rotate(ent.Velocity,0,math.min(info.mxvel or 9999,ent.Velocity:Length()))
			auxi.check_if_any(info.special,ent,info.frame,info)
			if info.frame >= info.mxframe then auxi.check_if_any(info.onfinish,ent,info.frame,info) d[item.own_key..self.name] = nil end
		end,},
		{name = "Move",work = function(ent,self,item) 
			local d = ent:GetData()
			local info = d[item.own_key..self.name]
			if info.reload and (info.frame or 0) == 0 then info.npos = auxi.copyVec(ent.Position) info.reload = nil end
			local dir = auxi.Lerp(info.npos,info.pos,(info.frame)/info.mxframe) - ent.Position
			local mvrate = info.mvrate or 0.5		--取为0的时候会瞬移到目标位置
			ent.Velocity = ent.Velocity * mvrate + dir * (1 - mvrate) * (info.alpha or 1)
			info.frame = (info.frame or 0) + 1
			auxi.check_if_any(info.special,ent,info.frame,info)
			if info.frame >= info.mxframe then auxi.check_if_any(info.onfinish,ent,info.frame,info) d[item.own_key..self.name] = nil end
		end,},
		{name = "MoveInval",work = function(ent,self,item) 
			local d = ent:GetData()
			local info = d[item.own_key..self.name]
			local dir = auxi.check_lerp(info.frame,info.moveinfo).pos + (info.pos or Vector(0,0)) - ent.Position
			ent.Velocity = dir	-- * 0.5
			info.frame = (info.frame or 0) + 1
			auxi.check_if_any(info.special,ent,info.frame,info)
			if info.frame >= info.mxframe then d[item.own_key..self.name] = nil end
		end,},
		{name = "Basic",NoClear = true,work = function(ent,self,item)
			local d = ent:GetData()
			local info = d[item.own_key..self.name] 
			if info.Friction then ent.Velocity = ent.Velocity * info.Friction end
		end,},
		{name = "Nil",},
	},
	Strategy2 = {
		{name = "AttackCount",work = function(ent,self,item)
			local d = ent:GetData()
			local info = d[item.own_key..self.name] 
			info.frame = (info.frame or 0) + 1
			if info.frame >= info.mxframe then d[item.own_key..self.name] = nil 
			else return true end
		end,},
		{name = "AttackNil",},
	},
}

function item.basic(ent,params)
	local d = ent:GetData()
	d[item.own_key.."Basic"] = params or {}
end

function item.move_diagonally(ent,speed,params)
	local d = ent:GetData()
	params = params or {}
	d[item.own_key.."Diagonally"] = {speed = speed or 5,dir = params.dir or Vector(1,0),Force = params.Force,special = params.special,}
end

function item.move_in_inval(ent,moveinfo,frame,special)
	local d = ent:GetData()
	d[item.own_key.."MoveInval"] = {moveinfo = moveinfo,frame = 0,mxframe = frame,special = special,}
end

function item.move2ent(ent,tg,frame,special,params)
	local d = ent:GetData()
	d[item.own_key.."MoveEnt"] = {tg = tg,npos = auxi.copyVec(ent.Position),frame = 0,mxframe = frame,special = special,}
	for u,v in pairs(params or {}) do d[item.own_key.."MoveEnt"][u] = v end
end

function item.move2pos(ent,pos,frame,special,params)
	local d = ent:GetData()
	d[item.own_key.."Move"] = {pos = pos,npos = auxi.copyVec(ent.Position),frame = 0,mxframe = frame,special = special,}
	for u,v in pairs(params or {}) do d[item.own_key.."Move"][u] = v end
end

function item.is_clear(ent)
	local d = ent:GetData()
	for i = 1,#item.Strategy do
		local bcinfo = item.Strategy[i]
		if d[item.own_key..bcinfo.name] then return false end
	end
	return true
end

function item.ClearMovement(ent,params)
	params = params or {}
	local d = ent:GetData()
	for i = 1,#item.Strategy do
		local bcinfo = item.Strategy[i]
		if not bcinfo.NoClear and d[item.own_key..bcinfo.name] and (params.banish or {})[i] ~= true then 
			auxi.check_if_any(bcinfo.clear,ent,bcinfo,item) 
			d[item.own_key..bcinfo.name] = nil
		end
	end
end

function item.Control_Move(ent)
	local d = ent:GetData()
	for i = 1,#item.Strategy do
		local bcinfo = item.Strategy[i]
		if d[item.own_key..bcinfo.name] then local succ = auxi.check_if_any(bcinfo.work,ent,bcinfo,item) if succ ~= true then break end end		--返回true时进入下一步
	end
end

function item.AddAttackDelay(ent,frame)
	local d = ent:GetData()
	d[item.own_key.."AttackCount"] = {frame = 0,mxframe = frame,}
end

function item.GetAttackDelay(ent)
	local d = ent:GetData()
	return (d[item.own_key.."AttackCount"] or {}).frame or 0
end

function item.Control_Attack(ent)
	local d = ent:GetData()
	for i = 1,#item.Strategy2 do
		local bcinfo = item.Strategy2[i]
		if d[item.own_key..bcinfo.name] then 
			local ret = auxi.check_if_any(bcinfo.work,ent,bcinfo,item)
			if ret ~= nil then return ret end
		end
	end
end

--[[


if ainfo.name == "Normal" then
	s:Play("MiscFloat",true)
	AI.AddAttackDelay(ent,30)
	local target = auxi.get_acceptible_target(ent)
	local tbl = auxi.make_lerp({cnt = 2,mul = 10,})
	local tgpos = target.Position
	local pos = auxi.ProtectVector(ent.Position)
	local pos2 = Game():GetRoom():GetClampedPosition(tgpos + auxi.get_by_rotate(tgpos - pos,auxi.random_2() * 60,200),-40)
	tbl = auxi.set_to(tbl,auxi.cut_by(function(val) return auxi.Bezier({pos,tgpos,tgpos,pos2,},val) end,10),"pos")
	AI.move_in_inval(ent,tbl,30,function(ent,frame,info) 
	end)
elseif ainfo.name == "Attack1" then
	s:Play("MiscFloat",true)
	AI.AddAttackDelay(ent,30)
	local target = auxi.get_acceptible_target(ent)
	local tbl = auxi.make_lerp({cnt = 2,mul = 10,})
	local tgpos = target.Position
	local pos = auxi.ProtectVector(ent.Position)
	local pos2 = Game():GetRoom():GetClampedPosition(ent.Position + auxi.get_by_rotate(tgpos - ent.Position,auxi.random_2() * 60,auxi.random_1() * 100 + 50),-40)
	tbl = auxi.set_to(tbl,auxi.cut_by(function(val) return auxi.Bezier({pos,(pos + pos2) * 0.5,(pos + pos2) * 0.5,pos2,},val) end,10),"pos")
	AI.move_in_inval(ent,tbl,30,function(ent,frame,info) 
		if frame == 15 then 
			local projparams = ProjectileParams()
			local dir = target.Position - ent.Position
			local cnt = 6
			for i = 1,cnt do
				local q = Isaac.Spawn(9,0,0,ent.Position,auxi.get_by_rotate(dir,i * 360/cnt,10),ent):ToProjectile()
				q.ProjectileFlags = 1<<28
				local d = q:GetData()
				d[item.own_key.."effect"] = {}
			end
		end
	end)

--]]
return item
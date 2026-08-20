local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local AI = require("Qing_Remaster_scripts.bosses.Boss_All")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local grid_morpher = require("Qing_Remaster_scripts.grids.grid_morpher")
local Projectile_holder = require("Qing_Remaster_scripts.mimics.Projectile_holder")
local Laser_holder = require("Qing_Remaster_scripts.mimics.Laser_holder")

local item = {
	ToCall = {},
	own_key = "Boss_Zeistos2_",
	entity = enums.Entities.ZeistosHelper2,
	Speciallist = {
		info = {
			[12] = {Speed = 13,},
			[13] = {Speed = 12,},
			[14] = {Speed = 14,},
			[27] = {Speed = 13,},
			[28] = {Speed = 13,},
		},
		update = {
			[1] = function(ent,item) item.fire_proj(ent,{delay = 10,}) end,
			[2] = function(ent,item) item.fire_proj(ent,{delay = 30,directions = {{ang = 0,},{ang = -20,},{ang = 20,},},}) end,
			[3] = function(ent,item) item.fire_proj(ent,{projspecial = function(ent) ent:AddProjectileFlags(ProjectileFlags.SMART) end,}) end,
			[4] = function(ent,item) item.fire_proj(ent,{projspecial = function(ent) ent:AddScale(0.5) end,}) end,
			--[5] = function(ent,item) item.fire_proj(ent,{projspecial = function(ent) ent:AddProjectileFlags(ProjectileFlags.BOOMERANG) ent:AddFallingSpeed(-10) end,}) end,
			[6] = function(ent,item) item.fire_proj(ent,{delay = 8,projspecial = function(ent) ent:AddHeight(5) ent:GetSprite().Color = Color(1,1,0,1,0.17,0.05,0) end,}) end,
			[7] = function(ent,item) item.fire_proj(ent,{projspecial = function(ent) ent:AddScale(0.5) end,}) end,
			--[10] = function(ent,item) local d = ent:GetData() for i = 1,2 do if auxi.check_all_exists(d[item.own_key.."linker"..tostring(i)]) ~= true then local q = Isaac.Spawn(96,0,0,ent.Position,ent.Velocity,ent) q.Parent = ent d[item.own_key.."linker"..tostring(i)] = q end end end,
			[32] = function(ent,item) item.fire_proj(ent,{delay = 10,}) end,
			[36] = function(ent,item) item.fire_proj(ent,{delay = 30,directions = {{Variant = 8,},},proj_fire = function(ent,pos,vel,item) 
				local fkinfo = {s = Sprite(),tp = 14,Variant = 0,GetSprite = function(self) return self.s end,GetType = function(self) return self.tp end,GetVariant = function(self) return self.Variant end}
				fkinfo.s:Load("gfx/grid/grid_poop.anm2",true) fkinfo.s:Play("State1",true) fkinfo.s:SetLastFrame()
				return grid_morpher.morph_grid(fkinfo,{anti = true,pos = pos,vel = vel,spawner = ent,}) end,}) end,
			[37] = function(ent,item) item.fire_proj(ent,{delay = 6 * 30,proj_fire = function(ent,pos,vel,item) 
				local q = Isaac.Spawn(4,1,0,pos,vel,ent):ToBomb() return q end,}) end,
			[52] = function(ent,item) item.fire_proj(ent,{delay = 4 * 30,proj_fire = function(ent,pos,vel,item) 
				local q = Isaac.Spawn(4,1,0,pos,vel,ent):ToBomb() return q end,}) end,
			[114] = function(ent,item) item.fire_proj(ent,{projspecial = function(ent) ent:AddProjectileFlags(ProjectileFlags.ACCELERATE | ProjectileFlags.GHOST) local s = ent:GetSprite() s:Load() end,}) end,		--!!
			[115] = function(ent,item) item.fire_proj(ent,{projspecial = function(ent) ent:AddProjectileFlags(ProjectileFlags.GHOST) end,}) end,
			[118] = function(ent,item) 
				local d = ent:GetData() 
				d[item.own_key.."Laser"] = d[item.own_key.."Laser"] or {} 
				if auxi.check_all_exists(d[item.own_key.."Laser"].laser) and d[item.own_key.."Laser"].Mvangle == nil then 
					local tg = auxi.get_acceptible_target(ent)
					if tg then
						local dir = tg.Position - ent.Position
						d[item.own_key.."Laser"].laser.Angle = auxi.checkrounded(d[item.own_key.."Laser"].laser.Angle,dir:GetAngleDegrees(),0.8,0.2,360)
					end
				end
				item.fire_proj(ent,{startdelay = 2 * 30,delay = 7 * 30,proj_fire = function(ent,pos,vel,item) 
				local q = Laser_holder.fire_delay_laser(pos,vel:GetAngleDegrees(),{launcher = function(et) 
					local q = Isaac.Spawn(7,1,0,pos,Vector(0,0),ent):ToLaser() q.Angle = et.Angle q.Parent = ent q:SetTimeout(7)
					d[item.own_key.."Laser"].Mvangle = true
					et:SetTimeout(1)
					return q
				end,}) q.Parent = ent d[item.own_key.."Laser"].laser = q
				return q end,}) end,
			[168] = function(ent,item) 
				local d = ent:GetData() 
				d[item.own_key.."Missile"] = d[item.own_key.."Missile"] or {}
				item.fire_proj(ent,{delay = 5 * 30,proj_fire = function(ent,pos,vel,item,tg) 
				local q = auxi.launch_Missile(pos,vel,nil,{Dontautocheck = true,Homing = 3 * 30,targ = tg,Cooldown = 4 * 30,NoFollow = true,}) 
					d[item.own_key.."Missile"].missile = q
				return q end,}) end,
			[169] = function(ent,item) item.fire_proj(ent,{delay = 2 * 30,projspecial = function(ent) ent:AddScale(4) end,}) end,
			[182] = function(ent,item) item.fire_proj(ent,{delay = 15,projspecial = function(ent) ent:AddProjectileFlags(ProjectileFlags.SMART) ent:AddScale(2) ent:GetSprite().Color = Color(1,1,1,1,0.3,0.3,0.3) end,}) end,
			[185] = function(ent,item) item.fire_proj(ent,{delay = 15,projspecial = function(ent) ent:AddProjectileFlags(ProjectileFlags.GHOST) end,}) end,
			[316] = function(ent,item) for i = 1,5 do item.fire_proj(ent,{startdelay = i * 2 + 9,delay = 25,}) end end,		--!!
			[330] = function(ent,item) item.fire_proj(ent,{delay = 3,projspecial = function(ent) ent:AddScale(-0.9) end,projpos = function(pos,dir,ent,info,item) ent:GetData()[item.own_key.."rk"] = -(ent:GetData()[item.own_key.."rk"] or -1) return pos + auxi.get_by_rotate(dir,90,2) * ent:GetData()[item.own_key.."rk"] end,}) end,
			[331] = function(ent,item) item.fire_proj(ent,{projspecial = function(ent) ent:AddProjectileFlags(ProjectileFlags.SMART | ProjectileFlags.GODHEAD) end,}) end,
			[369] = function(ent,item) item.fire_proj(ent,{projspecial = function(ent) ent:AddProjectileFlags(ProjectileFlags.CONTINUUM) ent:AddFallingSpeed(-10) end,}) end,
			[395] = function(ent,item) item.fire_proj(ent,{delay = 6 * 30,proj_fire = function(ent,pos,vel,item) 
				local q = Isaac.Spawn(7,2,2,pos,vel,ent):ToLaser() return q end,}) end,
		},
	},
}

function item.get_table()
	if item.record_tbl == nil then
		item.record_tbl = {}
		local tbl = {}
		for u,v in pairs(item.Speciallist) do
			for uu,vv in pairs(v) do
				tbl[uu] = true
			end
		end
		for u,v in pairs(tbl) do table.insert(item.record_tbl,u) end
	end
	return item.record_tbl
end

function item.spawn_helper(subtype,pos,vel,spawner)
	local q = Isaac.Spawn(996,item.entity,subtype,pos,vel,spawner):ToNPC()
	return q
end

function item.count_helper(special)
	local n_entity = Isaac.GetRoomEntities() 
	local cnt = 0
	for u,v in pairs(n_entity) do
		if v.Type == 996 and v.Variant == item.entity then
			if special == nil or auxi.check_if_any(special,v) then cnt = cnt + 1 end
		end
	end
	return cnt
end

function item.fire_proj(ent,params)
	params = params or {}
	local d = ent:GetData()
	d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
	if d[item.own_key.."counter"] % (params.delay or 10) == (params.startdelay or 0) then
		local tg = auxi.get_acceptible_target(ent)
		if tg then
			local dir = tg.Position - ent.Position
			for u,v in pairs(params.directions or {{ang = 0,},}) do
				local pos = auxi.check_if_any(params.projpos,ent.Position,dir,ent,v,item) or ent.Position
				local proj = auxi.check_if_any(params.proj_fire,ent,pos,auxi.get_by_rotate(dir,v.ang or 0,v.shotspeed or 10),item,tg) or Isaac.Spawn(9,v.Variant or 0,0,pos,auxi.get_by_rotate(dir,v.ang or 0,v.shotspeed or 10),ent):ToProjectile()
				auxi.check_if_any(params.projspecial,proj,ent,item)
			end
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		local config = Isaac:GetItemConfig()
		ent:AddEntityFlags(EntityFlag.FLAG_PERSISTENT)
		ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
		local st = ent.SubType
		local collectible = config:GetCollectible(st)
		if ent.SubType == 0 or collectible == nil then st = auxi.get_item_from_pool(nil,false,ent:GetDropRNG()) end
		auxi.load_item(st,{sprite = ent:GetSprite()})
		ent.SubType = st
		local info = item.Speciallist.info[ent.SubType] or {}
		AI.basic(ent,{Friction = info.Friction or 0.5,})
		AI.move_diagonally(ent,info.Speed or 10,{Force = true,})
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		AI.Control_Move(ent)
		auxi.check_if_any(item.Speciallist.update[ent.SubType],ent,item)
	end
end,
})

return item
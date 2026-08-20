local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Laser_holder_",
	records = {
		["CollisionDamage"] = true,
		["Parent"] = true,
		["DisableFollowParent"] = true,
		["SpawnerEntity"] = true,
		["Mass"] = true,
		["Variant"] = true,
		["SubType"] = true,
		["Visible"] = true,
	},
}

function item.set_remove(val) item.Remove = val end
function item.is_new_laser(ent) return ent.FrameCount <= 1 and ent:GetData()[item.own_key.."Update"] == nil end

-- RGON：SetMaxDistance 后默认会过渡到新长度；instant 时立刻重算 sample，避免首帧闪一下
function item.apply_max_distance(ent, dist, instant)
	if not ent then return end
	ent:SetMaxDistance(dist)
	if instant and ent.RecalculateSamplesNextUpdate then
		ent:RecalculateSamplesNextUpdate()
	end
end

-- 制造：两端桥接激光（飞行器 ↔ 飞刀）；对齐妈刀 offset；到顶/出房/失效则移除
-- 生成后应立刻调用一次（instant），否则首帧仍是 FireTechLaser 的默认射程
function item.sync_craft_bridge(ent, instant)
	if not ent then return false end
	local d = ent:GetData()
	local ed = d.craft_bridge_end
	if not ed then return false end
	if not ed:Exists() or ed:IsDead() then
		ent:Remove()
		return true
	end
	local flight = ed:GetData().knife_flight
	if flight and (flight.locked or flight.out_of_room) then
		ent:Remove()
		return true
	end
	local room = Game():GetRoom()
	if room and not room:IsPositionInRoom(ed.Position, -24) then
		ent:Remove()
		return true
	end
	local st = d.craft_bridge_start
	local start_pos = (st and st:Exists()) and st.Position or ent.Position
	local start_off = (st and st:Exists() and st.PositionOffset) or Vector(0, 0)
	local end_off = ed.PositionOffset or Vector(0, 0)
	-- 两端 offset 不一致：差值并入瞄准向量（方向/距离），公共部分用发射源 offset
	local off_diff = end_off - start_off
	local aim = (ed.Position - start_pos) + off_diff
	local dist = aim:Length()
	ent.Position = start_pos
	ent.PositionOffset = start_off
	if dist > 0.5 then
		ent.Angle = aim:GetAngleDegrees()
		ent.EndPoint = start_pos + aim
		item.apply_max_distance(ent, dist, instant)
	else
		ent.EndPoint = ed.Position
		item.apply_max_distance(ent, 0, instant)
	end
	return true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_INIT, params = nil,
Function = function(_,ent)
	if item.Remove then ent.Visible = false ent:Remove() end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	d[item.own_key.."Update"] = true
	if d[item.own_key.."Delayed"] then
		d[item.own_key.."Delayed"].counter = (d[item.own_key.."Delayed"].counter or 0) + 1
		if d[item.own_key.."Delayed"].counter == d[item.own_key.."Delayed"].delay then
			auxi.check_if_any(d[item.own_key.."Delayed"].launcher,ent)
		end
	end
	if d.craft_bridge_end then
		-- 首两帧 instant，吃掉默认射程→桥接长度的过渡闪烁
		item.sync_craft_bridge(ent, (ent.FrameCount or 0) <= 1)
	elseif d.craft_clear_if_dead then
		local host = d.craft_clear_if_dead
		if not host or not host:Exists() or host:IsDead() then
			ent:Remove()
		end
	end

	-- §14.7.3 Brim + Spirit Sword：沿硫磺路径近敌斩击
	local brim_sw = d.craft_brim_sword
	if brim_sw then
		brim_sw.cd = (brim_sw.cd or 0) - 1
		if brim_sw.cd <= 0 then
			local a = ent.Position
			local ang = ent.Angle
			local maxd = ent.MaxDistance
			if maxd == nil or maxd <= 0 then maxd = 600 end
			local b = a + Vector.FromAngle(ang) * maxd
			local ab = b - a
			local len2 = ab.X * ab.X + ab.Y * ab.Y
			local enemies = auxi.getenemies(Isaac.FindInRadius(a, maxd + 48, EntityPartition.ENEMY))
			local hit = brim_sw.hit or {}
			brim_sw.hit = hit
			for _, enemy in ipairs(enemies or {}) do
				if enemy and enemy:Exists() and not enemy:IsDead() then
					local ptr = GetPtrHash(enemy)
					if not hit[ptr] then
						local p = enemy.Position
						local t = 0
						if len2 > 1 then
							t = ((p.X - a.X) * ab.X + (p.Y - a.Y) * ab.Y) / len2
							if t < 0 then t = 0 elseif t > 1 then t = 1 end
						end
						local proj = a + ab * t
						if (p - proj):Length() <= 36 then
							hit[ptr] = true
							brim_sw.cd = 14
							local player = brim_sw.player
							local dmg = brim_sw.dmg or 3.5
							local flags = brim_sw.flags
							local epos = enemy.Position
							auxi.fire_dosome_knife(
								epos,
								(epos - a):Normalized() / 1000,
								{TearFlags = flags or BitSet128(0, 0), TearColor = player and player.TearColor or Color(1,1,1,1), TearDamage = dmg, TearScale = 1},
								"SpinUp",
								{player = player, dmgmul = 0.45, Flip = auxi.random_bool(), list = {}, dmg = dmg},
								nil
							)
							break
						end
					end
				end
			end
		end
	end
end,
})

function item.fire_delay_laser(pos,dir,params)
	params = params or {}
	local q = Isaac.Spawn(7,7,0,pos,Vector(0,0),params.source):ToLaser()
	local d = q:GetData()
	local s = q:GetSprite()
	q.Angle = dir
	d[item.own_key.."Delayed"] = {
		delay = params.delay or 20,
		counter = 0,
		launcher = params.launcher,
	}
	return q
end

--- 独立生成跟随父体的 Tech X 环（不走 player:FireTechXLaser，避免玩家硫磺火等改写形态）
--- SubType 3 = Ring Follow Parent；Variant THIN_RED = 普通科技环
function item.fire_follow_techx_ring(params)
	params = params or {}
	local pos = params.pos or Vector(0, 0)
	local parent = params.parent
	local source = params.source or parent
	local q = Isaac.Spawn(EntityType.ENTITY_LASER, LaserVariant.THIN_RED, 3, pos, Vector(0, 0), source):ToLaser()
	q.Variant = LaserVariant.THIN_RED
	q.SubType = 3
	if parent then q.Parent = parent end
	q.Radius = params.radius or 40
	q.CollisionDamage = params.dmg or 3.5
	if params.pos_offset then
		q.PositionOffset = params.pos_offset
	elseif parent then
		q.PositionOffset = parent.PositionOffset
	end
	q:SetTimeout(params.timeout or 9999)
	if params.shrink ~= nil then q.Shrink = params.shrink end
	return q
end

function item.ProtectLaser(ent)
	ent:GetData()[item.own_key.."ProtectRecord"] = {} for u,v in pairs(item.records) do ent:GetData()[item.own_key.."ProtectRecord"][u] = ent[u] end
	ent.DisableFollowParent = true
	ent.CollisionDamage = 0
	local dummy = Isaac.Spawn(EntityType.ENTITY_SHOPKEEPER,0,0,Vector(0,0),Vector(0,0),nil)
	ent.Parent = Game():GetPlayer(0) --dummy
	dummy:Remove()
	ent.SpawnerEntity = nil
	ent.Mass = 0
	ent.Visible = false
end

function item.UnProtectLaser(ent)
	if ent:GetData()[item.own_key.."ProtectRecord"] then 
		for u,v in pairs(item.records) do ent[u] = ent:GetData()[item.own_key.."ProtectRecord"][u] end
	end
end

-- §15.4 Brim/Tech/TechX：首次命中某敌人触发血泪（攻击实例×敌人去重）
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent, amt, flag, source, cooldown)
	if not ent or not ent:IsVulnerableEnemy() then return end
	if not source or not source.Entity then return end
	local laser = source.Entity:ToLaser()
	if not laser then return end
	local ch = laser:GetData().craft_haemo
	if not ch or not ch.profile then return end
	if not CraftProfile.mark_haemo_hit(ch, ent) then return end
	local mods = ch.mods or {}
	CraftProfile.spawn_craft_haemolacria_burst(
		ch.profile,
		ent.Position,
		ch.dir or laser.Velocity,
		ch.player,
		{
			player = ch.player,
			damage_mul = 0.45 * (mods.damage_mul or 1),
			size_mul = mods.size_mul or 1,
		}
	)
end,
})

return item
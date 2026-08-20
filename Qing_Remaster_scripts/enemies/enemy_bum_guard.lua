local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	enemy = enums.Enemies.Bum_Guard,
}

item.summon_guard = function(pos,vel,spawner,mode,health)
	if vel == nil then vel = Vector(0,0) end
	local q = Isaac.Spawn(996,item.enemy,0,pos,vel,spawner)
	local d = q:GetData()
	d.battle_mode = mode or 0
	if health and health > 0 then
		q.HitPoints = health
		q.MaxHitPoints = health
	end
	return q
end

local function add_flip(npc)
	local v = npc.Velocity
    if v.X < -0.0005 then
        npc:GetSprite().FlipX = true
    elseif v.X > 0.0005 then
        npc:GetSprite().FlipX = false
    end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,	--初始化
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
		if d.State == nil then
			d.State = 0
		end
		d.invi = 0
		d.move_mode = 0
		d.battle_mode = 0
		s:Play("Idle",true)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 996,	--自己写个减伤
Function = function(_,ent,amt,flag,source,cooldown)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
		if flag & DamageFlag.DAMAGE_CLONES == 0 then
			if d.invi and d.invi > 0 then
				return false
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = 996,	--死亡
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 996,	--移除
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = 45,
Function = function(_,ent,col,low)
	if col.Variant == item.enemy and col.Type == 996 then
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,		--速度、位移调整
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
		if d.target then
			if d.move_mode == 1 then
				ent.Velocity = ent.Velocity * 0.7
			elseif d.move_mode == 2 then
				local dis = d.target.Position - ent.Position
				ent.Velocity = ent.Velocity + dis * 0.02
			elseif d.move_mode == 3 then
				local dis = d.target_pos - ent.Position
				ent.Velocity = ent.Velocity * 0.9 + dis * 0.01
			else
				local dis = d.target.Position - ent.Position
				local t_pos = ent.Position + dis:Normalized() * 20
				local room = Game():GetRoom()
				if room:GetGridCollisionAtPos(t_pos) ~= GridCollisionClass.COLLISION_NONE or room:IsPositionInRoom(t_pos,5) ~= true then
					for i = 1,4 do
						for j = 1,-1,-2 do
							local n_dis = auxi.MakeVector((dis:GetAngleDegrees() + i * j * 30)) * dis:Length()
							local t_pos = ent.Position + n_dis:Normalized() * 20
							if room:GetGridCollisionAtPos(t_pos) == GridCollisionClass.COLLISION_NONE and room:IsPositionInRoom(t_pos,5) then
								dis = n_dis
								break
							end
						end
					end
				end
				ent.Velocity = (ent.Velocity + dis:Normalized() * 3):Normalized() * (ent.Velocity:Length() * 0.9 + math.random(10)/15 * (d.move_speed or 1))
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,		--行为、战斗控制
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local player = Game():GetPlayer(0)
		local hud = Game():GetHUD()
		if d.State == nil then
			d.State = 0
		end
		if d.battle_mode == 0 then		--枪兵
			if d.spear == nil or d.spear:Exists() == false or d.spear:IsDead() then
				local q = Isaac.Spawn(996,enums.Enemies.Bum_spear,0,ent.Position,ent.Velocity,nil)
				d.spear = q
				local d2 = q:GetData()
				d2.owner = ent
			end
			if s:IsPlaying("Idle") then
				if d.target == nil then
					d.target = Game():GetPlayer(0)
					for playerNum = 1, Game():GetNumPlayers() do
						local player = Game():GetPlayer(playerNum - 1)
						if (player.Position - ent.Position):Length() < (d.target.Position - ent.Position):Length() then
							d.target = player
						end
					end
				end
				if s:IsEventTriggered("Count") then
					if d.mv_cnt == nil then d.mv_cnt = 0 end
					if d.mv_mx_cnt == nil then d.mv_mx_cnt = math.random(5) + 3 end
					d.mv_cnt = d.mv_cnt + 1
					if d.mv_cnt >= d.mv_mx_cnt then
						d.rotate_control = nil
						d.mv_cnt = 0
						d.mv_mx_cnt = math.random(5) + 3
						d.State = math.random(3)
						d.move_mode = 0
						d.velocity_offset = nil
						if d.State == 1 then
							s:Play("Jump",true)
							d.rotate_control = 180
							d.rotate_control_Offset = Vector(0,-40)
							d.move_mode = 1
							ent.GridCollisionClass = GridCollisionClass.COLLISION_SOLID
						elseif d.State == 2 then
							s:Play("Hold",true)
							d.spear_rotate_speed = (math.random(10) + 40) * (math.random(2) * 2 - 3)
							d.move_mode = 1
						end
					end
				end
				if d.State == 2 then
					if d.velocity_offset then
						d.velocity_offset = d.spear:GetSprite().Rotation + (d.spear_rotate_speed or 45)
						if s:IsEventTriggered("Count") then
							if d.target then
								d.target_pos = d.target.Position
								ent.Velocity = (d.target.Position - ent.Position) * 0.1
							end
						end
					end
				end
			end
			if s:IsPlaying("Hold") then
				if d.target then
					d.rotate_target = d.target
					d.rotate_target_offset = 180
				end
			end
			if s:IsPlaying("Jump") then
				d.position_control = ent.Position
			end
			if s:IsPlaying("Idle_above") then
				d.position_control = ent.Position
				d.rotate_control = nil
			end
			if s:IsPlaying("Fall") then
				d.position_control = ent.Position
				if s:IsEventTriggered("Hit") then
					
				end
			end
			if s:IsFinished("Jump") then
				s:Play("Idle_above",true)
				if d.target then
					d.rotate_target = d.target
				end
			end
			if s:IsFinished("Hold") then
				d.rotate_target = nil
				d.rotate_target_offset = nil
				if d.target then
					d.move_mode = 3
					d.target_pos = d.target.Position
					ent.Velocity = (d.target.Position - ent.Position) * 0.05
				end
				d.velocity_offset = ent.Velocity:GetAngleDegrees() + (d.spear_rotate_speed or 45)
				s:Play("Idle",true)
			end
			if s:IsFinished("Idle_above") then
				d.rotate_control = 180
				d.rotate_target = nil
				d.move_mode = 2
				if d.target then
					ent.Velocity = (d.target.Position - ent.Position) * 0.05
				end
				s:Play("Fall",true)
			end
			if s:IsFinished("Fall") then
				d.rotate_control = nil
				d.rotate_control_Offset = nil
				d.position_control = nil
				ent.GridCollisionClass = GridCollisionClass.COLLISION_SOLID
				s:Play("Idle",true)
				d.move_mode = 0
				d.State = 0
			end
		elseif d.battle_mode == 1 then		--弓兵
			if d.arrow == nil or d.arrow:Exists() == false or d.arrow:IsDead() then
				local q = Isaac.Spawn(996,enums.Enemies.Bum_arrow,0,ent.Position,ent.Velocity,nil)
				d.arrow = q
				local d2 = q:GetData()
				d2.owner = ent
			end
			if s:IsPlaying("Idle") then
				if d.target == nil then
					d.target = Game():GetPlayer(0)
					for playerNum = 1, Game():GetNumPlayers() do
						local player = Game():GetPlayer(playerNum - 1)
						if (player.Position - ent.Position):Length() < (d.target.Position - ent.Position):Length() then
							d.target = player
						end
					end
					d.move_speed = 0.3
				end
				if s:IsEventTriggered("Count") then
					if d.mv_cnt == nil then d.mv_cnt = 0 end
					if d.mv_mx_cnt == nil then d.mv_mx_cnt = math.random(5) + 6 end
					d.mv_cnt = d.mv_cnt + 1
					if d.mv_cnt >= d.mv_mx_cnt then
						d.rotate_control = nil
						d.mv_cnt = 0
						d.mv_mx_cnt = math.random(5) + 3
						d.State = math.random(3)
						d.move_mode = 0
						d.velocity_offset = nil
						d.should_shoot = true
					end
				end
			end
		end
		
	end
end,
})

return item
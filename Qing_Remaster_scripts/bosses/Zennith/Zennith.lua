local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local wind = require("Qing_Remaster_scripts.threads.wind.wind_runtime")
local boss_wind = require("Qing_Remaster_scripts.bosses.Zennith.boss_wind_controller")
local combat_p1 = require("Qing_Remaster_scripts.bosses.Zennith.combat_p1")

local item = {
	ToCall = {},
	enemy = enums.Enemies.Zennith,
	own_key = "Enemies_Zennith_",
	Words = {
		zh = {
		},
	},
	now_hold = nil,
	-- Legacy attack_plan_* table archived: codex_work/notes/zennith_legacy_unreachable_ai.md
	Swapper = {
		["Appearing"] = "Idle",
		["Appear"] = "Idle",
	},
}

function item.living_bosses()
	local living = {}
	local list = Isaac.FindByType(996, item.enemy, -1, false, false)
	for i = 1, #list do
		local ent = list[i]
		if auxi.check_all_exists(ent) then
			living[#living + 1] = ent
		end
	end
	return living
end

function item.start_(pos)
	local living = item.living_bosses()
	item.duplicate_error = nil
	if #living > 1 then
		local parts = {}
		for i = 1, #living do
			local ent = living[i]
			local data = ent:GetData()
			parts[#parts + 1] = string.format(
				"#%d seed=%s test=%s",
				i,
				tostring(ent.InitSeed),
				tostring(data and data.qing_wind_test_request ~= nil)
			)
		end
		item.now_hold = living[1]
		item.duplicate_error = "zennith_duplicate " .. table.concat(parts, "; ")
		Isaac.DebugString("[Zennith] " .. item.duplicate_error)
		return living[1], false
	end
	if #living == 1 then
		item.now_hold = living[1]
		return living[1], false
	end
	pos = pos or Game():GetRoom():GetCenterPos()
	local q = Isaac.Spawn(996, item.enemy, 0, pos, Vector(0, 0), nil):ToNPC()
	item.now_hold = q
	return q, true
end

--- Storm Arena intro: freeze AI / attacks until cover is gone and pose settles.
function item.set_intro_locked(ent, locked)
	ent = ent or item.now_hold
	if not auxi.check_all_exists(ent) then return false end
	local d = ent:GetData()
	if locked then
		if d[item.own_key.."coll_saved"] == nil then
			d[item.own_key.."coll_saved"] = ent.EntityCollisionClass
		end
		d[item.own_key.."intro_locked"] = true
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		ent.Velocity = Vector(0, 0)
		local s = ent:GetSprite()
		if s and not s:IsPlaying("Idle") then
			s:Play("Idle", true)
		end
		d[item.own_key.."task"] = nil
	else
		d[item.own_key.."intro_locked"] = nil
		if d[item.own_key.."coll_saved"] ~= nil then
			ent.EntityCollisionClass = d[item.own_key.."coll_saved"]
			d[item.own_key.."coll_saved"] = nil
		else
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS
		end
	end
	return true
end

function item.is_intro_locked(ent)
	ent = ent or item.now_hold
	if not auxi.check_all_exists(ent) then return false end
	return ent:GetData()[item.own_key.."intro_locked"] == true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,		--初始化
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite() local d = ent:GetData()
		s:Play("Idle",true)
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS
		ent:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
		local room = Game():GetRoom()
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if door then door:Close() end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PROJECTILE_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	-- P1 projectile height / lifecycle owner: combat_p1_projectiles via combat_p1.
	if d[combat_p1.own_key .. "hold_h"] ~= nil and combat_p1.on_projectile_update then
		combat_p1.on_projectile_update(ent)
	end
	-- Legacy fire_z_* branches (kept for compatibility if old tears still exist).
	if d[item.own_key.."effect"] then ent:GetSprite().Rotation = ent.Velocity:GetAngleDegrees() end
	if ent.FrameCount == 15 then
		if d[item.own_key.."tear2"] then local q = item.fire_z_brimstone(ent.Position,ent,d[item.own_key.."tear2"].ang) end
		if d[item.own_key.."wait_rate"] then d[wind.own_key.."rate"] = d[item.own_key.."wait_rate"] end
	end
	if ent.FrameCount == 5 then
		if d[item.own_key.."tear"] then local q = item.fire_z_brimstone(ent.Position,ent,d[item.own_key.."tear"].ang) end
	end
	if d[wind.own_key.."try_remove"] then ent:Remove() end
end,
})
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function()
	if combat_p1.render then
		combat_p1.render()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if ent.FrameCount == 5 and d[item.own_key.."laser"] then
		if d[item.own_key.."laser"].split then
			local info = d[item.own_key.."laser"].split
			local pos = ent:GetEndPoint()
			for i = 1,5 do
				local q = item.fire_z_projectile(pos,ent,auxi.MakeVector(info.ang + 180 - 30 + i * 10) * 10)
			end
		end
	end
end,
})

function item.fire_z_brimstone(pos,ent,ang)
	local q = Isaac.Spawn(7,1,0,pos,Vector(0,0),ent):ToLaser() q.Parent = ent q:SetTimeout(5) 
	q.Angle = ang q.DepthOffset = 100 q.PositionOffset = Vector(0,-20)
	q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
	return q
end

function item.fire_z_projectile(pos,ent,dir)
	local q = Isaac.Spawn(9,4,0,pos,dir,ent):ToProjectile()
	q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.NO_WALL_COLLIDE
	q.FallingAccel = -0.05
	local s = q:GetSprite() s:Load("gfx/boss/Zennith/Zennith_projectile.anm2",true) s:Play("RegularTear8",true)
	local d = q:GetData() d[item.own_key.."effect"] = {}
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,			--战斗控制
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local room = Game():GetRoom() local level = Game():GetLevel()
		local s = ent:GetSprite() local d = ent:GetData() local anim = s:GetAnimation()
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}			--有效参数：pos_offset	攻击位置
		-- Arena cinematic lock: no attack selection, no body collision / movement.
		if d[item.own_key.."intro_locked"] then
			if not s:IsPlaying("Idle") then
				s:Play("Idle", true)
			end
			ent.Velocity = Vector(0, 0)
			d[item.own_key.."task"] = nil
			combat_p1.cancel(ent)
			return
		end
		-- Combat P1 owns attack selection / cadence.
		if ent:IsDead() or ent:HasMortalDamage() then
			combat_p1.shutdown(ent)
			return
		end
		d[item.own_key.."task"] = nil
		combat_p1.tick(ent)
	end
end,
})

item.combat_p1 = combat_p1

-- Death vortex delay chain. Token gates stale tasks after cleanup / room leave.
local death_fx_token = 0
local death_fx_list_index = nil

function item.abort_death_fx(reason)
	death_fx_token = death_fx_token + 1
	death_fx_list_index = nil
	return death_fx_token
end

local function death_fx_still_valid(token, list_index)
	if token ~= death_fx_token then return false end
	if not g.is_gameplay_world_active or not g.is_gameplay_world_active() then return false end
	if list_index ~= nil then
		local level = Game():GetLevel()
		local desc = level and level:GetCurrentRoomDesc()
		if not desc or desc.ListIndex ~= list_index then return false end
	end
	return true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = 996,
Function = function(_,ent)
	if ent.Variant == item.enemy then
		ent:GetData()[item.own_key .. "defeated"] = true
		combat_p1.shutdown(ent)
		-- Verified defeat (not room unload). Encounter owns Story settlement.
		boss_wind.fade_out()
		local ok, encounter = pcall(require, "Qing_Remaster_scripts.threads.wind.storm_encounter")
		if ok and encounter and encounter.notify_boss_defeated then
			encounter.notify_boss_defeated(ent)
		end
		-- Death wind swirl: keep as death presentation only; abort on cleanup / room change.
		local pos = Vector(ent.Position.X, ent.Position.Y)
		local token = item.abort_death_fx("new_kill")
		local level = Game():GetLevel()
		local desc = level and level:GetCurrentRoomDesc()
		death_fx_list_index = desc and desc.ListIndex or nil
		local room_index = death_fx_list_index
		for i = 1, 30 do
			delay_buffer.addeffe(function()
				if not death_fx_still_valid(token, room_index) then
					return
				end
				boss_wind.set_vortex({pos = pos, delta_rotation = i * 6, power = i})
			end, {}, i * 2)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 996,
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local d = ent:GetData()
		if d[item.own_key .. "defeated"] then
			return
		end
		-- Room unload / abort / reset — not a defeat.
		item.abort_death_fx("entity_remove")
		combat_p1.shutdown(ent)
		boss_wind.clear()
		local ok, encounter = pcall(require, "Qing_Remaster_scripts.threads.wind.storm_encounter")
		if ok and encounter and encounter.notify_boss_aborted then
			encounter.notify_boss_aborted(ent)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	item.abort_death_fx("new_room")
end,
})

return item

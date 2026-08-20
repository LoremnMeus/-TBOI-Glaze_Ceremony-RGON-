local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local bum_guard = require("Qing_Remaster_scripts.enemies.enemy_bum_guard")

local item = {
	ToCall = {},
	enemy = enums.Enemies.Bum_Emperor,
	health_list = {
		[1] = 100,
		[2] = 50,
		[3] = 30,
		[4] = 15,
	},
	queue_list = {
		[1] = {
			[1] = {
				[1] = {pos = Vector(0,80),tp = 0,},
				[2] = {pos = Vector(40,80),tp = 0,},
				[3] = {pos = Vector(80,80),tp = 0,},
				[4] = {pos = Vector(-40,80),tp = 0,},
				[5] = {pos = Vector(-80,80),tp = 0,},
				[6] = {pos = Vector(0,40),tp = 1,},
				[7] = {pos = Vector(40,40),tp = 1,},
				[8] = {pos = Vector(80,40),tp = 1,},
				[9] = {pos = Vector(-40,40),tp = 1,},
				[10] = {pos = Vector(-80,40),tp = 1,},
			},
			[2] = {
				[1] = {pos = Vector(0,120),tp = 0,},
				[2] = {pos = Vector(80,80),tp = 0,},
				[3] = {pos = Vector(-80,80),tp = 0,},
				[4] = {pos = Vector(-120,0),tp = 0,},
				[5] = {pos = Vector(120,0),tp = 0,},
				[6] = {pos = Vector(0,40),tp = 1,},
				[7] = {pos = Vector(40,0),tp = 1,},
				[8] = {pos = Vector(-40,0),tp = 1,},
			},
		},
		[2] = {
			[1] = {
				[1] = {pos = Vector(0,40),tp = 0,},
				[2] = {pos = Vector(40,40),tp = 1,},
				[3] = {pos = Vector(-40,40),tp = 1,},
				[4] = {pos = Vector(-80,80),tp = 0,},
				[5] = {pos = Vector(80,80),tp = 0,},
			},
			[2] = {
				[1] = {pos = Vector(40,0),tp = 1,},
				[2] = {pos = Vector(-40,0),tp = 1,},
				[3] = {pos = Vector(-80,0),tp = 1,},
				[4] = {pos = Vector(80,0),tp = 1,},
				[5] = {pos = Vector(-120,0),tp = 1,},
				[6] = {pos = Vector(120,0),tp = 1,},
				[7] = {pos = Vector(0,120),tp = 0,},
			},
		},
		[3] = {
			[1] = {
				[1] = {pos = Vector(40,40),tp = 1,},
				[2] = {pos = Vector(-40,40),tp = 1,},
				[3] = {pos = Vector(-80,80),tp = 0,},
				[4] = {pos = Vector(80,80),tp = 0,},
			},
			[2] = {
				[1] = {pos = Vector(40,0),tp = 1,},
				[2] = {pos = Vector(-40,0),tp = 1,},
				[3] = {pos = Vector(0,40),tp = 0,},
				[4] = {pos = Vector(0,80),tp = 0,},
			},
		},
		[4] = {
			[1] = {
				[1] = {pos = Vector(0,40),tp = 1,},
				[2] = {pos = Vector(0,80),tp = 0,},
			},
			[2] = {
				[1] = {pos = Vector(40,0),tp = 1,},
				[2] = {pos = Vector(-40,0),tp = 1,},
			},
			[3] = {
				[1] = {pos = Vector(0,40),tp = 0,},
				[2] = {pos = Vector(0,80),tp = 0,},
			},
		},
	},
	levelmap = {
		[1] = {
			[LevelStage.STAGE1_1] = 4,
			[LevelStage.STAGE1_2] = 4,
			[LevelStage.STAGE2_1] = 3,
			[LevelStage.STAGE2_2] = 3,
			[LevelStage.STAGE3_1] = 2,
			[LevelStage.STAGE3_2] = 2,
			[LevelStage.STAGE4_1] = 2,
			[LevelStage.STAGE4_2] = 2,
			[LevelStage.STAGE4_3] = 1,
			[LevelStage.STAGE5] = 1,
			[LevelStage.STAGE6] = 1,
			[LevelStage.STAGE7] = 1,
			[LevelStage.STAGE8] = 1,
		},
		[2] = {
			[LevelStage.STAGE1_GREED] = 4,
			[LevelStage.STAGE2_GREED] = 3,
			[LevelStage.STAGE3_GREED] = 3,
			[LevelStage.STAGE4_GREED] = 2,
			[LevelStage.STAGE5_GREED] = 2,
			[LevelStage.STAGE6_GREED] = 1,
			[LevelStage.STAGE7_GREED] = 1,
		},
	},
}

local function check_level()
	local stage = Game():GetLevel():GetStage()
	local difficulty = Game().Difficulty
	if difficulty <= Difficulty.DIFFICULTY_HARD then
		return item.levelmap[1][stage]
	else
		return item.levelmap[2][stage]
	end
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
		s:Play("Idle",true)
		d.level_checked = check_level()
		if d.level_checked == 3 then
			ent.HitPoints = 300
			ent.MaxHitPoints = 300
		elseif d.level_checked == 2 then
			ent.HitPoints = 600
			ent.MaxHitPoints = 600
		elseif d.level_checked == 4 then
			ent.HitPoints = 100
			ent.MaxHitPoints = 100
		end
		d.stag_check = math.random(#item.queue_list[d.level_checked])
		delay_buffer.addeffe(function(params)
			if (MusicManager():GetCurrentMusicID() ~= 22) then
				local music = MusicManager()
				music:Play(41, 1)
				music:UpdateVolume()
			end
		end,{},10)
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
		local cnt = (5 - (d.level_checked or 5)) * 5
		for i = 1,cnt do
			local q = Isaac.Spawn(5,20,0,ent.Position,auxi.MakeVector(math.random(3600)/10) * (1 + math.random(1000)/1000 * 2),nil)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 996,	--移除
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
		for i = 1,#item.queue_list[d.level_checked][d.stag_check] do
			local v = item.queue_list[d.level_checked][d.stag_check][i]
			if d["guard_"..tostring(i)] ~= nil and d["guard_"..tostring(i)]:Exists() and not d["guard_"..tostring(i)]:IsDead() then
				d["guard_"..tostring(i)]:Kill()
			end
		end
		local level = Game():GetLevel()
		local room = Game():GetRoom()
		local desc = level:GetCurrentRoomDesc()
		if desc.Data.Type == 9 and desc.Data.Variant == 23503 then
			grid_door.try_spawn_grid_door(room,1,nil,{check_and_leave = "s.chest.23520",should_update = false,loadname = "gfx/grid/door_bankdoor.anm2",playname = "Opened",})
		end
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
		if d.pos == nil then
			local room = Game():GetRoom()
			local center = room:GetCenterPos()
			local posX = center.X
			local posY = center.Y
			local t_n = 1
			for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
				if room:IsDoorSlotAllowed(slot) then
					local pos = room:GetDoorSlotPosition(slot)
					if pos.Y < posY - 5 then
						t_n = 1
						posX = pos.X
						posY = pos.Y
					elseif pos.Y > posY - 5 and pos.Y < posY + 5 then
						posX = pos.X + posX
						t_n = t_n + 1
					end
				end
			end
			posX = posX / t_n
			d.pos = room:GetClampedPosition(Vector(posX,posY),10)
		end
		if (ent.Position - d.pos):Length() > 0.5 then
			ent.Position = d.pos
		end
		ent.Velocity = (d.pos - ent.Position) * 0.5
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
		if s:IsPlaying("Idle") and s:IsEventTriggered("Call") then
			s:Play("Call",true)
		end
		if s:IsPlaying("Call") and s:IsEventTriggered("Call") then
			local check_offset = math.max(0,(0.7 - ent.HitPoints / ent.MaxHitPoints) * 3)
			for i = 1,#item.queue_list[d.level_checked][d.stag_check] do
				local v = item.queue_list[d.level_checked][d.stag_check][i]
				if d["guard_"..tostring(i)] == nil then
					local q = bum_guard.summon_guard(ent.Position + v.pos,Vector(0,0),ent,v.tp,item.health_list[d.level_checked])
					d["guard_"..tostring(i)] = q
				end
				if d["guard_"..tostring(i)]:Exists() == false or d["guard_"..tostring(i)]:IsDead() then
					if math.random(1000) > 950 + (check_offset or 0) * (-50) then
						d["guard_"..tostring(i)] = nil
					else
						check_offset = check_offset + 1
					end
				end
			end
		end
		if s:IsFinished("Call") then
			s:Play("Idle",true)
		end
	end
end,
})

return item
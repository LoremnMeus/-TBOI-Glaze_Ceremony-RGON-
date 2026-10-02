local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local wind = require("Qing_Remaster_scripts.bosses.Zennith.Enemy_wind")
local Zennith = require("Qing_Remaster_scripts.bosses.Zennith.Zennith")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Dialog_holder = require("Qing_Remaster_scripts.others.Dialog_holder")
local gate = require("Qing_Remaster_scripts.story.story_runtime_gate")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "thread_wind_",
	word_list = {
		zh = {
			[1] = {
				"风暴开始席卷大地",
			},
			[2] = {
				"以撒：",
				"好猛烈的风啊，到底发生了什么？",
				"我最好回头看一看",
			},
		},
		en = {
			[1] = {
				"The Wind is blowing heavily",
			},
			[2] = {
				"Isaac:",
				"What a fierce wind! What happened?",
				"I'd better turn around and take a look.",
			},
		},
	},
	banish_room_list = {
		--[1] = true,
		[5] = true,
		[7] = true,
		[8] = true,
		[11] = true,
		[29] = true,
	},
	banish_move_room_list = {
		[7] = true,
		[8] = true,
	},
}

function item.can_spawn()
	local level = Game():GetLevel() local stageType = level:GetStageType()
	return level:GetStage() == LevelStage.STAGE3_1 and stageType >= StageType.STAGETYPE_REPENTANCE
end

function item.should_spawn()
	return item.can_spawn() and save.elses[item.own_key.."spawn"] == true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,Rng,spwnpos)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local stage = Game():GetLevel():GetStage()
	local stageType = level:GetStageType()
	if gate.is_material_event_enabled("chapter1.wind") and
	room:GetType() == RoomType.ROOM_BOSS and desc.SafeGridIndex > 0 and item.can_spawn() and save.elses[item.own_key.."spawn"] ~= true then
		local language = Options.Language
		local str = (item.word_list[language] or item.word_list["en"])[1][1]
		gui.general_speak(Vector(0,0),str,0,120,{R = 2,G = 2,B = 0,})
		delay_buffer.addeffe(function()
			Dialog_holder.add_word({data =(item.word_list[language] or item.word_list["en"])[2],header = {sprite_name = "Isaac"},step_by = true,}) 
		end,{},30 * 3)
		
		save.elses[item.own_key.."spawn"] = true
		local q = wind.start_()
		local sgid = desc.SafeGridIndex
		if save.elses["Zennith_room_conter_"..sgid] ~= 0 then wind.change_control(1,{dir = save.elses["Zennith_room_dir_"..sgid],power = save.elses["Zennith_room_conter_"..sgid],})
		else wind.change_control(2,{pos = room:GetCenterPos(),}) end
	end
end,
})

function item.plan_a_bfs()
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local stage = Game():GetLevel():GetStage()
	local stageType = level:GetStageType()
	local rng = Game():GetPlayer(0):GetCollectibleRNG(33)
	rng:SetSeed(Game():GetSeeds():GetStageSeed(Game():GetLevel():GetStage()),0)
	
	local rooms = level:GetRooms()
	local tg = {}
	for i = 0, rooms.Size do
		local targ = rooms:Get(i)
		if targ ~= nil and targ.SafeGridIndex >= 0 then
			local id = targ.SafeGridIndex
			local desc = level:GetRoomByIdx(id)
			if item.banish_room_list[desc.Data.Type] ~= true then table.insert(tg,#tg+1,targ) end
		end
	end
	if #tg == 0 then return false end
	local targ_id = rng:RandomInt(#tg) + 1
	local targ = tg[targ_id]
	local id = targ.SafeGridIndex
	local desc = level:GetRoomByIdx(id)
	local tg2 = {}		--尝试运用bfs算法。
	table.insert(tg2,{id = targ.SafeGridIndex,power = 0,})
	save.elses["Zennith_room_conter_"..targ.SafeGridIndex] = 0
	save.elses["Zennith_room_dir_"..targ.SafeGridIndex] = -1
	save.elses["Zennith_room"] = targ.SafeGridIndex
	while(#tg2 > 0) do
		local ntg = {}
		for u,v in pairs(tg2) do
			local pos_rou = auxi.move_in_rou(v.id,13,13)
			local pos_tg = {v.id,}
			for u1,v1 in pairs(pos_rou) do
				local same_desc = level:GetRoomByIdx(v1)
				if same_desc and same_desc.Data and same_desc.SafeGridIndex == v.id then		--是同一房间
					table.insert(pos_tg,#pos_tg+1,v1)
				end
			end
			for u1,v1 in pairs(pos_tg) do
				local pos_pos = auxi.move_in_sq(v1,13,13)
				for u2,v2 in pairs(pos_pos) do
					local tar = level:GetRoomByIdx(v2.id)
					local sgid = tar and tar.Data and tar.SafeGridIndex or -1
					if sgid > 0 and tar.Data.Type ~= 7 and (save.elses["Zennith_room_conter_"..sgid] == nil or save.elses["Zennith_room_conter_"..sgid] > v.power + 1) then
						save.elses["Zennith_room_conter_"..sgid] = v.power + 1
						save.elses["Zennith_room_dir_"..sgid] = v2.dir
						table.insert(ntg,#ntg+1,{id = sgid,power = v.power + 1,})
					end
				end
			end
		end
		tg2 = ntg
	end
	return true
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."spawn"] = nil
	if gate.is_chapter1_available() and Unlocker.should_any_be_done("Thread","Wind",nil,"Boss_allow") then
		for i = 0,150 do
			save.elses["Zennith_room_conter_"..i] = nil
			save.elses["Zennith_room_dir_"..i] = nil
		end
		save.elses["Zennith_room"] = nil
		if item.can_spawn() then item.plan_a_bfs() end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local stage = Game():GetLevel():GetStage()
	local stageType = level:GetStageType()
	if gate.is_chapter1_available() then
		if item.can_spawn() and desc.SafeGridIndex > 0 and save.elses[item.own_key.."spawn"] == true then
			local sgid = desc.SafeGridIndex
			if save.elses["Zennith_room_conter_"..sgid] ~= nil then
				local q = wind.start_()
				if save.elses["Zennith_room_conter_"..sgid] ~= 0 then
					wind.change_control(1,{dir = save.elses["Zennith_room_dir_"..sgid],power = save.elses["Zennith_room_conter_"..sgid],})
				else
					local size = room:GetGridSize()
					for i = 0,size - 1 do
						local gent = room:GetGridEntity(i)
						if (gent) then
							local s = gent:GetSprite()
							if gent:GetType() == GridEntityType.GRID_PRESSURE_PLATE and gent:GetVariant() == 9 then
								Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, room:GetGridPosition(i), Vector(0, 0), nil)		--记得移除压力板
								room:RemoveGridEntity(i, 0, true)
							end
						end
					end
					local Zennith = Zennith.start_()
					wind.change_control(3,{ent = Zennith,delta_pos = Vector(0,-20)})
				end
			end
		end
	end
end,
})

--l print(Game():GetLevel():GetCurrentRoomDesc().Data.Variant)
--l local room = Game():GetRoom();local size = room:GetGridSize();for i = 0,size - 1 do local gent = room:GetGridEntity(i);if (gent) then if gent:GetType() == GridEntityType.GRID_PRESSURE_PLATE and gent:GetVariant() == 9 then gent:Destroy(true); end end end

local function wind_clear_map()
	for i = 0, 150 do
		save.elses["Zennith_room_conter_" .. i] = nil
		save.elses["Zennith_room_dir_" .. i] = nil
	end
	save.elses["Zennith_room"] = nil
	save.elses[item.own_key .. "spawn"] = nil
end

item.story_test = {
	snapshot = function(_ctx)
		local snap = {
			spawn = save.elses[item.own_key .. "spawn"],
			zennith_room = save.elses["Zennith_room"],
			counters = {},
			dirs = {},
		}
		for i = 0, 150 do
			if save.elses["Zennith_room_conter_" .. i] ~= nil then
				snap.counters[i] = save.elses["Zennith_room_conter_" .. i]
			end
			if save.elses["Zennith_room_dir_" .. i] ~= nil then
				snap.dirs[i] = save.elses["Zennith_room_dir_" .. i]
			end
		end
		return snap
	end,
	restore = function(snap, _ctx)
		wind_clear_map()
		if type(snap) ~= "table" then return end
		save.elses[item.own_key .. "spawn"] = snap.spawn
		save.elses["Zennith_room"] = snap.zennith_room
		for i, v in pairs(snap.counters or {}) do
			save.elses["Zennith_room_conter_" .. i] = v
		end
		for i, v in pairs(snap.dirs or {}) do
			save.elses["Zennith_room_dir_" .. i] = v
		end
	end,
	reset = function(_ctx)
		wind_clear_map()
		return true
	end,
	prepare = function(ctx)
		ctx = ctx or {}
		local phase = ctx.phase or "pre_trigger"
		wind_clear_map()
		if phase == "pre_trigger" then
			if item.can_spawn() then
				item.plan_a_bfs()
			end
			save.elses[item.own_key .. "spawn"] = nil
		elseif phase == "storm_active" or phase == "discovered" then
			if item.can_spawn() then
				item.plan_a_bfs()
			end
			save.elses[item.own_key .. "spawn"] = true
		elseif phase == "boss" then
			if item.can_spawn() then
				item.plan_a_bfs()
			end
			save.elses[item.own_key .. "spawn"] = true
		end
		return true
	end,
	trigger = function(ctx)
		ctx = ctx or {}
		if ctx.phase == "boss" or ctx.phase == "storm_active" then
			save.elses[item.own_key .. "spawn"] = true
			if item.can_spawn() and not save.elses["Zennith_room"] then
				item.plan_a_bfs()
			end
			return true
		end
		return false, "no trigger for phase"
	end,
	inspect = function(_ctx)
		return {
			phase = save.elses[item.own_key .. "spawn"] and "active" or "idle",
			target_room = save.elses["Zennith_room"],
			spawn = save.elses[item.own_key .. "spawn"] == true,
			can_spawn = item.can_spawn(),
			gate = gate.is_material_event_enabled("chapter1.wind"),
		}
	end,
	cleanup = function(_ctx)
		wind_clear_map()
		return true
	end,
}

return item

local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local glaze_bomb = require("Qing_Remaster_scripts.pickups.pickup_glaze_bomb")
local gate = require("Qing_Remaster_scripts.story.story_runtime_gate")
local glaze_route = require("Qing_Remaster_scripts.story.glaze_route_rules")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Thread_Glaze",
}

local tracked_bombs = {} -- [GetPtrHash] = 最新 wrapper；行为追踪不得使用可能被 GC 丢弃的弱键

local function bomb_runtime_key(ent)
	local ok, ptr = pcall(GetPtrHash, ent)
	return ok and ptr or nil
end

local function checkBaseConditions()
	return glaze_route.is_valid_floor()
end

local function isValidDoor(door)
	return glaze_route.is_mirror_door(door)
end

local function isValidRoomDesc(desc)
	return glaze_route.is_mirror_room_desc(desc)
end

-- 处理Glaze碎片生成
local function handleGlazeSpawn()
    if not checkBaseConditions() then return end

    local level = Game():GetLevel()
    local room = Game():GetRoom()
    local desc = level:GetCurrentRoomDesc()

    if save.elses.mirr ~= true and 
       save.elses.mirror and 
       save.elses.mirror == true and 
       room:IsMirrorWorld() ~= save.elses.is_mirror and
       isValidRoomDesc(desc) then

        for _, gridIndex in pairs(glaze_route.MIRROR_DOOR_GRID_INDICES) do
            local door = room:GetGridEntity(gridIndex)
            if isValidDoor(door) then
                -- Legacy Glaze Shard pedestal retired: Story token only.
                room:MamaMegaExplosion(room:GetGridPosition(gridIndex))
                Game():Darken(1, 60)
                Game():ShakeScreen(30)
                save.elses.mirr = true
                local story_owned = gate.is_commission_accepted() and gate.is_chapter1_available()
                local ok, material_adapter = pcall(require, "Qing_Remaster_scripts.story.material_story_adapter")
                if ok and material_adapter and material_adapter.on_thread_complete then
                    material_adapter.on_thread_complete("glaze", {story_owned = story_owned == true})
                end
            end
        end
    end
end

-- 处理Pickup初始化（legacy shard altar sprites no longer used）
local function handlePickupInit(_ent)
end

-- 处理镜像世界延迟逻辑
local function handleMirrorWorldDelay()
    if not checkBaseConditions() then return end

    local level = Game():GetLevel()
    local room = Game():GetRoom()
    local desc = level:GetCurrentRoomDesc()

    if not isValidRoomDesc(desc) then return end

    for _, gridIndex in pairs(glaze_route.MIRROR_DOOR_GRID_INDICES) do
        local door = room:GetGridEntity(gridIndex)
        if isValidDoor(door) and door:ToDoor().Desc.Variant ~= 8 then
			local mxn = 10000
            local mrdl = mxn
            local mrd2 = mxn

			for key, ent in pairs(tracked_bombs) do
				local ok, exists = pcall(function() return ent:Exists() and not ent:IsDead() end)
				if not ok or not exists then
					tracked_bombs[key] = nil
				else
                local s = ent:GetSprite()
                local succ = consistance_holder.try_check_entity(ent, glaze_bomb.own_key)
                if s:IsPlaying("Pulse") and succ and (ent.Position - door.Position):Length() < 100 then
					if (ent.Position + ent.Velocity * 2 - door.Position):Length() < 30 then  -- 当炸弹非常接近门时
						mrd2 = math.min(mrdl, 58 - s:GetFrame())
						ent:Remove()
						SFXManager():Play(SoundEffect.SOUND_MIRROR_ENTER)  -- 播放消失音效
						local poof = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, door.Position, Vector.Zero, nil)
						poof:GetSprite().Color = Color(1, 1, 1, 0.5,0.5,0.5,0.5)  -- 设置半透明效果
					else 
						mrdl = math.min(mrdl, 58 - s:GetFrame())
					end

                end
				end
            end
			save.elses.mirror_delay = save.elses.mirror_delay or {-1,-1}
			local currentWorld = room:IsMirrorWorld() and 2 or 1  -- 1: 正常世界, 2: 镜像世界
			local oppositeWorld = 3 - currentWorld
	
			-- 初始化延迟值
			save.elses.mirror_delay[currentWorld] = (mrdl == mxn) and -1 or mrdl
			save.elses.mirror_delay[oppositeWorld] = save.elses.mirror_delay[oppositeWorld] or -1
			if mrd2 ~= mxn then 
				if save.elses.mirror_delay[oppositeWorld] > 0 then save.elses.mirror_delay[oppositeWorld] = math.min(mrd2,save.elses.mirror_delay[oppositeWorld])
				else save.elses.mirror_delay[oppositeWorld] = mrd2 end
			end
	
			if save.elses.mirror_delay[oppositeWorld] >= 0 then
				save.elses.mirror_delay[oppositeWorld] = save.elses.mirror_delay[oppositeWorld] - 1
			end
	
			-- 检查是否触发镜像切换
			if save.elses.mirror_delay[oppositeWorld] == 0 then
				save.elses.mirror = true
				save.elses.is_mirror = (currentWorld == 1)
			end
        end
    end
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_BOMB_INIT,
	params = nil,
	Function = function(_, bomb)
		local key = bomb_runtime_key(bomb)
		if key then tracked_bombs[key] = bomb end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
    CallBack = ModCallbacks.MC_POST_UPDATE,
    params = nil,
    Function = handleGlazeSpawn
})

table.insert(item.ToCall, #item.ToCall + 1, {
    CallBack = ModCallbacks.MC_POST_PICKUP_INIT,
    params = 100,
    Function = handlePickupInit
})

table.insert(item.ToCall, #item.ToCall + 1, {
    CallBack = ModCallbacks.MC_POST_UPDATE,
    params = nil,
    Function = handleMirrorWorldDelay
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = EntityType.ENTITY_FIREPLACE,
Function = function(_,ent)
	local room = Game():GetRoom()
	if glaze_route.is_white_fireplace(ent) then
		if glaze_route.is_white_fire_interact_allowed() then
			if save.elses.mirr ~= true and room:IsMirrorWorld() == true then
				local s = ent:GetSprite()
				s:Load("gfx/Glaze/glaze_fireplace.anm2")
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses.mirr = false
	save.elses.mirror = false
	save.elses.is_mirror = false
	save.elses.mirror_delay = {-1,-1,}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses.mirr = false
		save.elses.mirror = false
		save.elses.is_mirror = false
		save.elses.mirror_delay = {-1,-1,}
	end
end,
})

local function glaze_clear_mirror()
	save.elses.mirr = false
	save.elses.mirror = false
	save.elses.is_mirror = false
	save.elses.mirror_delay = {-1, -1}
end

local function stage_type_name(st)
	if st == StageType.STAGETYPE_REPENTANCE then return "REPENTANCE" end
	if st == StageType.STAGETYPE_REPENTANCE_B then return "REPENTANCE_B" end
	if st == StageType.STAGETYPE_ORIGINAL then return "ORIGINAL" end
	return tostring(st)
end

local function build_checklist(_ctx)
	local level = Game() and Game():GetLevel()
	local room = Game() and Game():GetRoom()
	local desc = level and level:GetCurrentRoomDesc()
	local fires = glaze_route.find_white_fireplaces(room)
	local mirror_room_index = glaze_route.find_mirror_room_index(level)
	local current_index = desc and (desc.SafeGridIndex or desc.GridIndex) or nil
	local in_mirror_room = glaze_route.is_mirror_room_desc(desc) == true
		or (mirror_room_index ~= nil and current_index == mirror_room_index)
	local is_mirror = room and room:IsMirrorWorld() == true
	local transfer = save.elses.mirror == true
	local returned = transfer and room and (room:IsMirrorWorld() ~= save.elses.is_mirror)
	local token_owned = false
	do
		local ok, story_state = pcall(require, "Qing_Remaster_scripts.story.story_state")
		if ok and story_state and story_state.has_token then
			token_owned = story_state.has_token("chapter1", "chapter1.material.glaze") == true
		end
	end
	local rows = {
		{id = "chapter1_available", ok = gate.is_chapter1_available() == true, label = {zh = "Chapter 1 available", en = "Chapter 1 available"}},
		{id = "commission", ok = gate.is_commission_accepted() == true, label = {zh = "Commission accepted", en = "Commission accepted"}},
		{id = "material_event", ok = glaze_route.is_material_event_enabled(), label = {zh = "Material event enabled", en = "Material event enabled"}},
		{id = "stage", ok = level and level:GetStage() == LevelStage.STAGE1_2, label = {zh = "Stage = STAGE1_2", en = "Stage = STAGE1_2"}, detail = level and tostring(level:GetStage()) or nil},
		{id = "stage_type", ok = level ~= nil and (level:GetStageType() == StageType.STAGETYPE_REPENTANCE or level:GetStageType() == StageType.STAGETYPE_REPENTANCE_B), label = {zh = "StageType = REPENTANCE*", en = "StageType = REPENTANCE*"}, detail = level and stage_type_name(level:GetStageType()) or nil},
		{id = "mirror_room", ok = in_mirror_room, label = {zh = "Mirror room matched", en = "Mirror room matched"}, detail = mirror_room_index and ("idx=" .. tostring(mirror_room_index)) or "not generated"},
		{id = "mirror_world", ok = is_mirror, label = {zh = "Mirror world = true", en = "Mirror world = true"}, detail = tostring(is_mirror)},
		{id = "white_fire", ok = #fires > 0, label = {zh = "White fireplace Variant 4 found", en = "White fireplace Variant 4 found"}, detail = tostring(#fires)},
		{id = "glaze_bomb", ok = (save.elses.glaze_bombs or 0) > 0, label = {zh = "Glaze bomb available", en = "Glaze bomb available"}, detail = tostring(save.elses.glaze_bombs or 0)},
		{id = "transfer", ok = transfer, label = {zh = "Mirror transfer registered", en = "Mirror transfer registered"}},
		{id = "returned", ok = returned == true, label = {zh = "Returned to opposite world", en = "Returned to opposite world"}},
		{id = "token", ok = token_owned or save.elses.mirr == true, label = {zh = "chapter1.material.glaze token granted", en = "chapter1.material.glaze token granted"}},
	}
	return rows
end

item.story_test = {
	snapshot = function(_ctx)
		return {
			mirr = save.elses.mirr,
			mirror = save.elses.mirror,
			is_mirror = save.elses.is_mirror,
			mirror_delay = save.elses.mirror_delay,
			glaze_bombs = save.elses.glaze_bombs,
		}
	end,
	restore = function(snap, _ctx)
		glaze_clear_mirror()
		if type(snap) ~= "table" then return end
		save.elses.mirr = snap.mirr
		save.elses.mirror = snap.mirror
		save.elses.is_mirror = snap.is_mirror
		save.elses.mirror_delay = snap.mirror_delay
		if snap.glaze_bombs ~= nil then
			save.elses.glaze_bombs = snap.glaze_bombs
		end
	end,
	reset = function(_ctx)
		glaze_clear_mirror()
		return true
	end,
	prepare = function(ctx)
		ctx = ctx or {}
		local phase = ctx.phase or "pre_trigger"
		glaze_clear_mirror()
		if phase == "bomb_interact" then
			-- Ready for natural bomb → white fire; do not forge completion.
			save.elses.glaze_bombs = 1
		elseif phase == "mirror_transfer_ready" then
			-- Bomb already crossed from mirror world; player should return to normal.
			save.elses.mirror = true
			save.elses.is_mirror = true
			save.elses.mirr = false
		elseif phase == "mirror_ready" or phase == "discovered" or phase == "pre_trigger" then
			save.elses.mirror = false
			save.elses.mirr = false
		elseif phase == "complete" then
			save.elses.mirr = true
		end
		return true
	end,
	trigger = function(_ctx)
		return false, "glaze uses natural mirror bomb flow"
	end,
	inspect = function(ctx)
		local level = Game() and Game():GetLevel()
		local room = Game() and Game():GetRoom()
		local desc = level and level:GetCurrentRoomDesc()
		local fires = glaze_route.find_white_fireplaces(room)
		local mirror_index = glaze_route.find_mirror_room_index(level)
		return {
			phase = save.elses.mirr and "complete" or (save.elses.mirror and "switching" or "idle"),
			mirr = save.elses.mirr == true,
			mirror = save.elses.mirror == true,
			is_mirror = save.elses.is_mirror,
			glaze_bombs = save.elses.glaze_bombs or 0,
			gate = glaze_route.is_material_event_enabled(),
			base = checkBaseConditions(),
			floor_ok = level and level:GetStage() == LevelStage.STAGE1_2 or false,
			stage_type = level and stage_type_name(level:GetStageType()) or nil,
			mirror_room_index = mirror_index,
			in_mirror_room = glaze_route.is_mirror_room_desc(desc) == true,
			mirror_world = room and room:IsMirrorWorld() == true or false,
			white_fire_count = #fires,
			checklist = build_checklist(ctx),
		}
	end,
	cleanup = function(_ctx)
		glaze_clear_mirror()
		return true
	end,
}

return item

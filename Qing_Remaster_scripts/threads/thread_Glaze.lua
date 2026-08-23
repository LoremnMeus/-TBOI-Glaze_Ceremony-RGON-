local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local glaze_bomb = require("Qing_Remaster_scripts.pickups.pickup_glaze_bomb")

local item = {
	ToCall = {},
	own_key = "Thread_Glaze",
}

local tracked_bombs = {} -- [GetPtrHash] = 最新 wrapper；行为追踪不得使用可能被 GC 丢弃的弱键

local function bomb_runtime_key(ent)
	local ok, ptr = pcall(GetPtrHash, ent)
	return ok and ptr or nil
end

local function checkBaseConditions()
    local level = Game():GetLevel()
    return save.UnlockData.Others.Ending1.Unlock and
           level:GetStage() == LevelStage.STAGE1_2 and
           (level:GetStageType() == StageType.STAGETYPE_REPENTANCE or 
            level:GetStageType() == StageType.STAGETYPE_REPENTANCE_B)
end

-- 辅助函数：检查门是否符合条件
local function isValidDoor(door)
    return door and 
           door:GetType() == GridEntityType.GRID_DOOR and
           door:ToDoor().TargetRoomIndex == -100
end

-- 辅助函数：检查房间描述是否符合条件
local function isValidRoomDesc(desc)
    return desc.Data.Type == RoomType.ROOM_DEFAULT and
           desc.Data.Variant >= 10000 and
           desc.Data.Variant <= 10500
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

        for _, gridIndex in pairs({60, 74}) do
            local door = room:GetGridEntity(gridIndex)
            if isValidDoor(door) then
                local pedestalIdx = (gridIndex == 60) and 61 or 73
                local spawnItem = enums.Items.A_Shard_Of_Glaze
                
                local q1 = Isaac.Spawn(5, 100, spawnItem, room:GetGridPosition(pedestalIdx), Vector.Zero, nil):ToPickup()
                q1:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
                consistance_holder.try_hold_entity(q1, item.own_key, {ignore_subtype = true})
                
                room:MamaMegaExplosion(room:GetGridPosition(gridIndex))
                
                local s1 = q1:GetSprite()
                s1:ReplaceSpritesheet(5, "gfx/items/to_item_altar.png")
                s1:LoadGraphics()
                s1:SetOverlayFrame("Alternates", 0)
                
                Game():Darken(1, 60)
                Game():ShakeScreen(30)
                save.elses.mirr = true
            end
        end
    end
end

-- 处理Pickup初始化
local function handlePickupInit(ent)
    if save.elses.mirr and ent.Type == 5 and ent.Variant == 100 then
        if consistance_holder.try_check_entity(ent, item.own_key) then
            local s = ent:GetSprite()
            s:ReplaceSpritesheet(5, "gfx/items/to_item_altar.png")
            s:LoadGraphics()
            s:SetOverlayFrame("Alternates", 0)
        end
    end
end

-- 处理镜像世界延迟逻辑
local function handleMirrorWorldDelay()
    if not checkBaseConditions() then return end

    local level = Game():GetLevel()
    local room = Game():GetRoom()
    local desc = level:GetCurrentRoomDesc()

    if not isValidRoomDesc(desc) then return end

    for _, gridIndex in pairs({60, 74}) do
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
				--save.elses.mirror_bombs = (save.elses.mirror_bombs or 0) + 1
			end
	
			-- 鏇存柊瀵归潰涓栫晫鐨勫欢杩?
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

-- 娉ㄥ唽鍥炶皟
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
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	if ent.Type == EntityType.ENTITY_FIREPLACE and ent.Variant == 4 then
		if save.UnlockData.Others.Ending1.Unlock == true then
			if save.elses.mirr ~= true and room:IsMirrorWorld() == true then
				local s = ent:GetSprite()
				s:Load("gfx/Glaze/glaze_fireplace.anm2")
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
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

return item

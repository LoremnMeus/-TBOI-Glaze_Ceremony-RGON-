-- Shared predicates for Chapter-1 Glaze (mirror / white-fire) route.
-- Formal thread + Story Test Lab must both call these; do not duplicate Variant ranges.

local gate = require("Qing_Remaster_scripts.story.story_runtime_gate")

local rules = {
	MIRROR_ROOM_VARIANT_MIN = 10000,
	MIRROR_ROOM_VARIANT_MAX = 10500,
	MIRROR_DOOR_GRID_INDICES = {60, 74},
	MIRROR_DOOR_TARGET = -100,
	WHITE_FIRE_VARIANT = 4,
	EVENT_ID = "chapter1.glaze",
}

function rules.is_valid_floor(level)
	level = level or (Game() and Game():GetLevel())
	if not level then return false end
	if not gate.is_material_event_enabled(rules.EVENT_ID) then return false end
	if level:GetStage() ~= LevelStage.STAGE1_2 then return false end
	local st = level:GetStageType()
	return st == StageType.STAGETYPE_REPENTANCE or st == StageType.STAGETYPE_REPENTANCE_B
end

function rules.is_material_event_enabled()
	return gate.is_material_event_enabled(rules.EVENT_ID) == true
end

--- White-fire / glaze-bomb interact gate (same soft enable as floor route).
function rules.is_white_fire_interact_allowed()
	return rules.is_material_event_enabled()
end

function rules.is_mirror_room_desc(desc)
	if not desc or not desc.Data then return false end
	local data = desc.Data
	return data.Type == RoomType.ROOM_DEFAULT
		and data.Variant >= rules.MIRROR_ROOM_VARIANT_MIN
		and data.Variant <= rules.MIRROR_ROOM_VARIANT_MAX
end

function rules.is_mirror_door(door)
	if not door then return false end
	if door.GetType and door:GetType() ~= GridEntityType.GRID_DOOR then
		return false
	end
	local as_door = door.ToDoor and door:ToDoor() or door
	if not as_door or as_door.TargetRoomIndex == nil then return false end
	return as_door.TargetRoomIndex == rules.MIRROR_DOOR_TARGET
end

function rules.find_mirror_door(room)
	room = room or (Game() and Game():GetRoom())
	if not room then return nil, nil end
	for _, grid_index in ipairs(rules.MIRROR_DOOR_GRID_INDICES) do
		local grid = room:GetGridEntity(grid_index)
		if rules.is_mirror_door(grid) then
			return grid, grid_index
		end
	end
	-- Fallback: scan door slots (pickup bomb path uses GetDoor).
	for i = 0, 7 do
		local door = room:GetDoor(i)
		if door and door.TargetRoomIndex == rules.MIRROR_DOOR_TARGET then
			return door, door:GetGridIndex()
		end
	end
	return nil, nil
end

function rules.find_mirror_room_desc(level)
	level = level or (Game() and Game():GetLevel())
	if not level then return nil, nil end
	local rooms = level:GetRooms()
	if not rooms then return nil, nil end
	for i = 0, rooms.Size - 1 do
		local desc = rooms:Get(i)
		if rules.is_mirror_room_desc(desc) then
			local index = desc.SafeGridIndex
			if index == nil then index = desc.GridIndex end
			return desc, index
		end
	end
	return nil, nil
end

function rules.find_mirror_room_index(level)
	local _, index = rules.find_mirror_room_desc(level)
	return index
end

function rules.is_white_fireplace(ent)
	return ent ~= nil
		and ent.Type == EntityType.ENTITY_FIREPLACE
		and ent.Variant == rules.WHITE_FIRE_VARIANT
end

function rules.find_white_fireplaces(room)
	room = room or (Game() and Game():GetRoom())
	local found = {}
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FIREPLACE, rules.WHITE_FIRE_VARIANT, -1, false, false)) do
		if rules.is_white_fireplace(ent) then
			found[#found + 1] = ent
		end
	end
	return found
end

function rules.dimension_id(name_or_id)
	if name_or_id == nil or name_or_id == "current" or name_or_id == -1 then
		return -1
	end
	if name_or_id == "normal" or name_or_id == "main" or name_or_id == 0 then
		return 0
	end
	if name_or_id == "mirror" or name_or_id == "secondary" or name_or_id == 1 then
		return 1
	end
	local n = tonumber(name_or_id)
	if n ~= nil then return n end
	return -1
end

function rules.has_mirror_dimension(level)
	level = level or (Game() and Game():GetLevel())
	if not level then return false end
	if level.HasMirrorDimension then
		local ok, has = pcall(function() return level:HasMirrorDimension() end)
		if ok then return has == true end
	end
	-- Fallback: if mirror room exists, treat secondary dim as available on alt Stage1_2.
	return rules.find_mirror_room_index(level) ~= nil
end

return rules

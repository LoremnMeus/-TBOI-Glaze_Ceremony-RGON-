local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Destiny_Anchor,
	own_key = "Item_Destiny_Anchor_",
	max_anchors = 3,
	marker_anm2 = "gfx/post/1000.2338_NILL_destiny_mark.anm2",
	runtime_configs = {},
	current_floor_seed = nil,
}

local save_key = item.own_key.."floors"
local marker_key = item.own_key.."marker"

local valid_room_types = {
	[RoomType.ROOM_DEFAULT] = true,
	[RoomType.ROOM_SHOP] = true,
	[RoomType.ROOM_TREASURE] = true,
	[RoomType.ROOM_MINIBOSS] = true,
	[RoomType.ROOM_SECRET] = true,
	[RoomType.ROOM_SUPERSECRET] = true,
	[RoomType.ROOM_ARCADE] = true,
	[RoomType.ROOM_CURSE] = true,
	[RoomType.ROOM_CHALLENGE] = true,
	[RoomType.ROOM_LIBRARY] = true,
	[RoomType.ROOM_SACRIFICE] = true,
	[RoomType.ROOM_ISAACS] = true,
	[RoomType.ROOM_BARREN] = true,
	[RoomType.ROOM_CHEST] = true,
	[RoomType.ROOM_DICE] = true,
	[RoomType.ROOM_PLANETARIUM] = true,
	[RoomType.ROOM_ULTRASECRET] = true,
}

local function floor_seed()
	return Game():GetLevel():GetDungeonPlacementSeed()
end

local function get_floor_records(seed,create)
	save.elses[save_key] = save.elses[save_key] or {}
	local key = tostring(seed or floor_seed())
	if create then save.elses[save_key][key] = save.elses[save_key][key] or {} end
	return save.elses[save_key][key],key
end

local function config_key(seed,safe_grid_index)
	return tostring(seed)..":"..tostring(safe_grid_index)
end

local function room_dimension(desc)
	if REPENTOGON and desc and desc.GetDimension then return desc:GetDimension() end
	return auxi.GetDimension(desc)
end

local function room_data(desc)
	return desc and (desc.OverrideData or desc.Data)
end

local function is_anchorable(desc)
	local data = room_data(desc)
	if not REPENTOGON or not data then return false end
	if room_dimension(desc) ~= 0 or desc.SafeGridIndex < 0 then return false end
	return valid_room_types[data.Type] == true
end

local function find_record(records,safe_grid_index,dimension)
	for _,record in ipairs(records or {}) do
		if record.safe_grid_index == safe_grid_index and record.dimension == dimension then return record end
	end
end

local function spawn_marker(position,appear)
	for _,effect in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT,enums.Entities.ID_EFFECT_MeusNIL)) do
		if effect:GetData()[marker_key] then return effect end
	end
	local effect = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		enums.Entities.ID_EFFECT_MeusNIL,
		0,
		position,
		Vector.Zero,
		nil
	):ToEffect()
	if not effect then return end
	local data = effect:GetData()
	data[marker_key] = true
	data.removecd = 999999
	local sprite = effect:GetSprite()
	sprite:Load(item.marker_anm2,true)
	sprite:Play(appear and "Appear" or "Idle",true)
	effect.DepthOffset = -20
	return effect
end

local function record_current_room(player)
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	if not is_anchorable(desc) then return false end
	local records = get_floor_records(nil,true)
	local dimension = room_dimension(desc)
	if find_record(records,desc.SafeGridIndex,dimension) or #records >= item.max_anchors then return false end

	local data = room_data(desc)
	local record = {
		safe_grid_index = desc.SafeGridIndex,
		dimension = dimension,
		stage_id = data.StageID,
		room_type = data.Type,
		variant = data.Variant,
		mode = data.Mode,
		shape = data.Shape,
		doors = data.Doors,
		position = {X = player.Position.X,Y = player.Position.Y},
	}
	table.insert(records,record)
	item.runtime_configs[config_key(floor_seed(),desc.SafeGridIndex)] = data
	spawn_marker(player.Position,true)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,1,1,false,0,2)
	return true
end

local function recover_room_config(record,source_seed)
	local runtime = item.runtime_configs[config_key(source_seed,record.safe_grid_index)]
	if runtime then return runtime end
	local holder = rawget(_G,"RoomConfig") or rawget(_G,"RoomConfigHolder")
	if not holder or not holder.GetRoomByStageTypeAndVariant then return nil end
	local success,config = pcall(
		holder.GetRoomByStageTypeAndVariant,
		record.stage_id,
		record.room_type,
		record.variant,
		record.mode
	)
	if success and config then return config end
	success,config = pcall(
		holder.GetRoomByStageTypeAndVariant,
		record.stage_id,
		record.room_type,
		record.variant,
		-1
	)
	if success then return config end
end

local function doors_are_compatible(desc,room_config)
	local required_doors = desc.AllowedDoors or 0
	return room_config.Doors & required_doors == required_doors
end

local function get_replacement_candidates(room_config,record,used)
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local current_index = level:GetCurrentRoomDesc().SafeGridIndex
	local starting_index = level:GetStartingRoomIndex()
	local candidates = {}
	for index = 0,rooms.Size - 1 do
		local desc = rooms:Get(index)
		local data = room_data(desc)
		if desc and data and desc.SafeGridIndex >= 0 and room_dimension(desc) == 0 and
			desc.SafeGridIndex ~= current_index and desc.SafeGridIndex ~= starting_index and
			desc.VisitedCount == 0 and not used[desc.SafeGridIndex] and
			data.Shape == record.shape and doors_are_compatible(desc,room_config) then
			local target_type = data.Type
			if target_type == record.room_type or target_type == RoomType.ROOM_DEFAULT then
				table.insert(candidates,{
					desc = desc,
					same_type = target_type == record.room_type,
				})
			end
		end
	end
	return candidates
end

local function choose_candidate(candidates,rng)
	for _,candidate in ipairs(candidates) do candidate.roll = rng:RandomInt(1000000) end
	table.sort(candidates,function(a,b)
		if a.same_type ~= b.same_type then return a.same_type end
		return a.roll < b.roll
	end)
	return candidates[1] and candidates[1].desc
end

local function reproduce_anchors(source_seed)
	local records = get_floor_records(source_seed,false)
	if not records or #records == 0 then return 0 end
	local level = Game():GetLevel()
	local rng = RNG()
	rng:SetSeed(level:GetDungeonPlacementSeed() + item.entity,35)
	local used = {}
	local reproduced = 0
	for _,record in ipairs(records) do
		local room_config = recover_room_config(record,source_seed)
		if room_config then
			local target = choose_candidate(get_replacement_candidates(room_config,record,used),rng)
			if target then
				Room_holder.Replace_with(target.SafeGridIndex,0,{
					data = room_config,
					others = {OverrideData = room_config},
				})
				used[target.SafeGridIndex] = true
				reproduced = reproduced + 1
			end
		end
		rng:Next()
	end
	return reproduced
end

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_USE_ITEM,params = item.entity,
Function = function(_,_,_,player,use_flags)
	if use_flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then return end
	local success = record_current_room(player)
	if not success then player:AnimateSad() end
	return {Discharge = false,ShowAnim = success}
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,params = enums.Entities.ID_EFFECT_MeusNIL,
Function = function(_,effect)
	if not effect:GetData()[marker_key] then return end
	local sprite = effect:GetSprite()
	if sprite:IsFinished("Appear") then sprite:Play("Idle",true) end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NEW_ROOM,params = nil,
Function = function(_)
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local records = get_floor_records(nil,false)
	local record = records and find_record(records,desc.SafeGridIndex,room_dimension(desc))
	if record then
		spawn_marker(Vector(record.position.X,record.position.Y),false)
	end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL,params = nil,priority = -50,
Function = function(_)
	local new_seed = floor_seed()
	local source_seed = item.current_floor_seed
	if source_seed and source_seed ~= new_seed then reproduce_anchors(source_seed) end
	item.current_floor_seed = new_seed
	get_floor_records(new_seed,true)
end,
})

table.insert(item.myToCall,{CallBack = enums.Callbacks.PRE_GAME_STARTED,params = nil,
Function = function(_,continue)
	if not continue then save.elses[save_key] = {} end
	save.elses[save_key] = save.elses[save_key] or {}
	item.runtime_configs = {}
	item.current_floor_seed = floor_seed()
	get_floor_records(item.current_floor_seed,true)
end,
})

return item

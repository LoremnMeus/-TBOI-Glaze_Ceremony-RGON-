local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local grid_wall = require("Qing_Remaster_scripts.grids.grid_wall")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Destiny_Anchor,
	own_key = "Item_Destiny_Anchor_",
	max_anchors = 3,
	marker_anm2 = "gfx/mimics/Destiny_Anchor/Anchor.anm2",
	runtime_configs = {},
	current_floor_seed = nil,
	pending_failure_notice = nil,
}

local save_key = item.own_key.."floors"
local reproduced_key = item.own_key.."reproduced"
local marker_key = item.own_key.."marker"
local marker_echo_key = item.own_key.."marker_echo"

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

local function stageapi_loaded()
	return StageAPI and StageAPI.Loaded
end

local function get_floor_records(seed,create)
	save.elses[save_key] = save.elses[save_key] or {}
	local key = tostring(seed or floor_seed())
	if create then save.elses[save_key][key] = save.elses[save_key][key] or {} end
	return save.elses[save_key][key],key
end

local function get_reproduced_records(seed,create)
	save.elses[reproduced_key] = save.elses[reproduced_key] or {}
	local key = tostring(seed or floor_seed())
	if create then save.elses[reproduced_key][key] = save.elses[reproduced_key][key] or {} end
	return save.elses[reproduced_key][key],key
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

local function copy_backdrop_table(backdrop)
	if type(backdrop) == "number" then return backdrop end
	if type(backdrop) ~= "table" then return nil end
	local copy = {}
	for key,value in pairs(backdrop) do
		local value_type = type(value)
		if value_type == "string" or value_type == "number" or value_type == "boolean" then
			copy[key] = value
		elseif value_type == "table" then
			if value[1] and type(value[1]) == "string" then
				copy[key] = {}
				for index,entry in ipairs(value) do copy[key][index] = entry end
			elseif value[1] and type(value[1]) == "table" then
				copy[key] = {}
				for index,entry in ipairs(value) do
					copy[key][index] = copy_backdrop_table(entry) or {}
				end
			end
		end
	end
	return copy
end

local function serialize_backdrops(backdrops)
	if type(backdrops) == "number" then return backdrops end
	if type(backdrops) ~= "table" then return nil end
	if backdrops.WallAnm2 or backdrops.FloorAnm2 or backdrops.WallVariants or backdrops.FloorVariants then
		return copy_backdrop_table(backdrops)
	end
	local pool = {}
	for index,entry in ipairs(backdrops) do
		pool[index] = serialize_backdrops(entry)
	end
	if #pool > 0 then return pool end
	return copy_backdrop_table(backdrops)
end

local function capture_room_gfx()
	local room = Game():GetRoom()
	local gfx = {
		backdrop_type = room:GetBackdropType(),
		decoration_seed = room:GetDecorationSeed(),
	}
	if stageapi_loaded() and StageAPI.GetCurrentRoomGfx then
		local ok,room_gfx = pcall(StageAPI.GetCurrentRoomGfx)
		if ok and room_gfx and room_gfx.Backdrops then
			gfx.stageapi_backdrops = serialize_backdrops(room_gfx.Backdrops)
		end
	end
	return gfx
end

local function apply_room_gfx(gfx_record)
	if not gfx_record then return end
	local backdrops = gfx_record.stageapi_backdrops
	if backdrops then
		if stageapi_loaded() and StageAPI.ChangeRoomGfx then
			if gfx_record.decoration_seed and StageAPI.BackdropRNG then
				StageAPI.BackdropRNG:SetSeed(gfx_record.decoration_seed,0)
			end
			pcall(StageAPI.ChangeRoomGfx,{Backdrops = backdrops,})
			return
		end
		if gfx_record.decoration_seed then
			grid_wall.BackdropRNG:SetSeed(gfx_record.decoration_seed,0)
		end
		grid_wall.ChangeRoomGfx({Backdrops = backdrops,})
		return
	end
	if gfx_record.backdrop_type ~= nil then
		grid_wall.ChangeBackdrop(gfx_record.backdrop_type)
	end
end

local function show_destiny_message(mode)
	local hud = Game():GetHUD()
	if not hud or not hud.ShowItemText then return end
	if auxi.get_EID_language() == "zh_cn" then
		if mode == "echo" then
			hud:ShowItemText("命运锚点","命运发生了偏移……")
		elseif mode == "exact" then
			hud:ShowItemText("命运锚点","命运复现")
		else
			hud:ShowItemText("命运锚点","锚点未能复现")
		end
	else
		if mode == "echo" then
			hud:ShowItemText("Destiny Anchor","Fate has shifted...")
		elseif mode == "exact" then
			hud:ShowItemText("Destiny Anchor","Fate restored")
		else
			hud:ShowItemText("Destiny Anchor","Anchor failed to return")
		end
	end
end

local function spawn_marker(position,appear,echo)
	for _,effect in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT,enums.Entities.ID_EFFECT_MeusNIL)) do
		local data = effect:GetData()
		if data[marker_key] and data[marker_echo_key] == (echo and true or false) and
			effect.Position:Distance(position) < 8 then
			return effect
		end
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
	data[marker_echo_key] = echo and true or false
	data.removecd = 999999
	local sprite = effect:GetSprite()
	sprite:Load(item.marker_anm2,true)
	sprite:Play("Idle",true)
	if echo then
		sprite.Color = Color(0.75,0.65,1,1)
	end
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
		position = {X = player.Position.X,Y = player.Position.Y,},
		room_gfx = capture_room_gfx(),
	}
	table.insert(records,record)
	item.runtime_configs[config_key(floor_seed(),desc.SafeGridIndex)] = data
	spawn_marker(player.Position,true,false)
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

local function get_replacement_candidates(room_config,record,used,require_same_shape)
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
			(not require_same_shape or data.Shape == record.shape) and
			(not require_same_shape or doors_are_compatible(desc,room_config)) then
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

local function get_echo_candidates(record,used,same_type_only)
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
			desc.VisitedCount == 0 and not used[desc.SafeGridIndex] then
			local target_type = data.Type
			local include = same_type_only and target_type == record.room_type
				or (not same_type_only and target_type == RoomType.ROOM_DEFAULT)
			if include then
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

local function get_echo_room_config(record,target_desc,rng)
	local holder = rawget(_G,"RoomConfig") or rawget(_G,"RoomConfigHolder")
	if not holder or not holder.GetRandomRoom then return nil end
	local target_data = room_data(target_desc)
	if not target_data then return nil end
	local room = Game():GetRoom()
	local stage = room and room.GetRoomConfigStage and room:GetRoomConfigStage() or record.stage_id
	local mode = Game():IsGreedMode() and 1 or 0
	local seed = rng:RandomInt(2147483646) + 1
	local success,config = pcall(
		holder.GetRandomRoom,
		seed,
		true,
		stage,
		record.room_type,
		target_data.Shape,
		0,
		-1,
		0,
		10,
		target_desc.AllowedDoors or 0,
		-1,
		mode
	)
	if success then return config end
end

local function register_reproduction(target_sgid,record,mode)
	local reproduced = get_reproduced_records(nil,true)
	reproduced[target_sgid] = {
		mode = mode,
		room_gfx = record.room_gfx,
		announced = false,
		source_safe_grid_index = record.safe_grid_index,
	}
	record.reproduction_mode = mode
end

local function apply_replacement(target_desc,room_config,record,mode,used)
	Room_holder.Replace_with(target_desc.SafeGridIndex,0,{
		data = room_config,
		others = {OverrideData = room_config,},
	})
	used[target_desc.SafeGridIndex] = true
	register_reproduction(target_desc.SafeGridIndex,record,mode)
end

local function try_echo_reproduction(record,used,rng,same_type_only)
	local candidates = get_echo_candidates(record,used,same_type_only)
	if #candidates == 0 then return false end
	for _,candidate in ipairs(candidates) do candidate.roll = rng:RandomInt(1000000) end
	table.sort(candidates,function(a,b) return a.roll < b.roll end)
	for _,candidate in ipairs(candidates) do
		local echo_config = get_echo_room_config(record,candidate.desc,rng)
		if echo_config and doors_are_compatible(candidate.desc,echo_config) then
			apply_replacement(candidate.desc,echo_config,record,"echo",used)
			return true
		end
		rng:Next()
	end
	return false
end

local function reproduce_single_anchor(record,source_seed,used,rng)
	local room_config = recover_room_config(record,source_seed)
	if room_config then
		local target = choose_candidate(get_replacement_candidates(room_config,record,used,true),rng)
		if target then
			apply_replacement(target,room_config,record,"exact",used)
			return true
		end
	end
	if try_echo_reproduction(record,used,rng,true) then return true end
	if try_echo_reproduction(record,used,rng,false) then return true end
	return false
end

local function reproduce_anchors(source_seed)
	local records = get_floor_records(source_seed,false)
	if not records or #records == 0 then return 0 end
	local level = Game():GetLevel()
	local rng = RNG()
	rng:SetSeed(level:GetDungeonPlacementSeed() + item.entity,35)
	local used = {}
	local reproduced = 0
	local failed = 0
	for _,record in ipairs(records) do
		if reproduce_single_anchor(record,source_seed,used,rng) then
			reproduced = reproduced + 1
		else
			failed = failed + 1
		end
		rng:Next()
	end
	if failed > 0 then item.pending_failure_notice = failed end
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
	local data = effect:GetData()
	if not data[marker_key] then return end
	local sprite = effect:GetSprite()
	if data[marker_echo_key] then
		local pulse = 0.72 + 0.18 * math.sin(Game():GetFrameCount() / 7)
		sprite.Color = Color(pulse,pulse * 0.82,pulse * 1.15,1)
	end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NEW_ROOM,params = nil,
Function = function(_)
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local records = get_floor_records(nil,false)
	local record = records and find_record(records,desc.SafeGridIndex,room_dimension(desc))
	if record then
		spawn_marker(Vector(record.position.X,record.position.Y),false,false)
	end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NEW_ROOM,params = nil,priority = 50,
Function = function(_)
	if item.pending_failure_notice then
		show_destiny_message("failed")
		item.pending_failure_notice = nil
	end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local reproduced = get_reproduced_records(nil,false)
	local entry = reproduced and reproduced[desc.SafeGridIndex]
	if not entry then return end
	apply_room_gfx(entry.room_gfx)
	if not entry.announced then
		show_destiny_message(entry.mode)
		entry.announced = true
	end
	local room = Game():GetRoom()
	if room and room:IsFirstVisit() then
		spawn_marker(room:GetCenterPos(),true,entry.mode == "echo")
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
	get_reproduced_records(new_seed,true)
end,
})

table.insert(item.myToCall,{CallBack = enums.Callbacks.PRE_GAME_STARTED,params = nil,
Function = function(_,continue)
	if not continue then
		save.elses[save_key] = {}
		save.elses[reproduced_key] = {}
	end
	save.elses[save_key] = save.elses[save_key] or {}
	save.elses[reproduced_key] = save.elses[reproduced_key] or {}
	item.runtime_configs = {}
	item.pending_failure_notice = nil
	item.current_floor_seed = floor_seed()
	get_floor_records(item.current_floor_seed,true)
	get_reproduced_records(item.current_floor_seed,true)
end,
})

return item

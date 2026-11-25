local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Screen_Filter = require("Qing_Remaster_scripts.others.Screen_Filter")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local teleport_holder = require("Qing_Remaster_scripts.callbacks.teleport_holder")

local item = {
	ToCall = {},
	myToCall = {},
	doors = {},
	special_reminder = nil,
	slot_dir_map = {
		[DoorSlot.LEFT0] = 0,
		[DoorSlot.UP0] = 1,
		[DoorSlot.RIGHT0] = 2,
		[DoorSlot.DOWN0] = 3,
		[DoorSlot.LEFT1] = 0,
		[DoorSlot.UP1] = 1,
		[DoorSlot.RIGHT1] = 2,
		[DoorSlot.DOWN1] = 3,
	},
	dir_map = {
		[0] = Vector(1,0),
		[1] = Vector(0,1),
		[2] = Vector(-1,0),
		[3] = Vector(0,-1),
	},
	init_work = function(s,params)
		s:Load(params.loadname or "gfx/grid/door_mausoleum.anm2", false)
		if params.spritename then for i = 0,4 do s:ReplaceSpritesheet(i,params.spritename) end end
		s.Color = params.color or Color(1,1,1,1)
		s:LoadGraphics()
		s:Play(params.playname or "Opened",true)
	end,
	movable_roomtype = {
		[3] = true,
		[5] = function(info)
			local desc = Game():GetLevel():GetCurrentRoomDesc()
			if desc.SafeGridIndex == -7 then return true end
		end,
		[24] = true,
	},
}

local lifecycle_observer = nil

function item.set_lifecycle_observer(fn)
	lifecycle_observer = (type(fn) == "function") and fn or nil
end

local function read_dimension(level)
	level = level or Game():GetLevel()
	local dim = nil
	pcall(function()
		if level and level.GetDimension then
			dim = level:GetDimension()
		end
	end)
	return tonumber(dim) or 0
end

local function room_identity(desc, level)
	level = level or Game():GetLevel()
	desc = desc or level:GetCurrentRoomDesc()
	local data = desc and desc.Data
	return {
		safe_grid_index = desc and desc.SafeGridIndex,
		safe_grid_type = data and data.Type,
		safe_grid_variant = data and data.Variant,
		dimension = read_dimension(level),
	}
end

--- Door identity: Dimension + SafeGridIndex + Type/Variant (+ optional idx / door_id / slot).
--- Missing stored dimension fails match so pre-fix entries are cleaned once.
local function entry_matches_room(v, ident, opts)
	opts = opts or {}
	if not v or not ident then
		return false
	end
	if v.dimension == nil then
		return false
	end
	if tonumber(v.dimension) ~= tonumber(ident.dimension) then
		return false
	end
	if tonumber(v.safe_grid_index) ~= tonumber(ident.safe_grid_index) then
		return false
	end
	if v.safe_grid_type ~= ident.safe_grid_type then
		return false
	end
	if v.safe_grid_variant ~= ident.safe_grid_variant then
		return false
	end
	if opts.idx ~= nil and tonumber(v.idx) ~= tonumber(opts.idx) then
		return false
	end
	if opts.door_id ~= nil and v.door_id ~= opts.door_id then
		return false
	end
	if opts.slot ~= nil then
		local slot = v.refer_slot
		if slot == nil then
			slot = v.slot
		end
		if tonumber(slot) ~= tonumber(opts.slot) then
			return false
		end
	end
	return true
end

local function emit_lifecycle(action, v, extra)
	if not lifecycle_observer then
		return
	end
	local row = {
		action = action,
		door_id = v and v.door_id or nil,
		slot = v and (v.refer_slot or v.slot) or nil,
		idx = v and v.idx or nil,
		safe_grid_index = v and v.safe_grid_index or nil,
		safe_grid_type = v and v.safe_grid_type or nil,
		safe_grid_variant = v and v.safe_grid_variant or nil,
		dimension = v and v.dimension or nil,
		virtual = v and v.virtual == true,
		game_frame = Game():GetFrameCount(),
	}
	pcall(function()
		row.room_frame = Game():GetRoom():GetFrameCount()
	end)
	if v and v.anchor then
		pcall(function()
			row.anchor_ptr = GetPtrHash(v.anchor)
			row.anchor_init_seed = v.anchor.InitSeed
			row.anchor_exists = v.anchor.Exists and v.anchor:Exists() == true
			local spr = v.anchor:GetSprite()
			if spr then
				row.animation = spr.GetAnimation and spr:GetAnimation() or nil
				row.sprite_filename = spr.GetFilename and spr:GetFilename() or nil
			end
		end)
	end
	if type(extra) == "table" then
		for k, val in pairs(extra) do
			row[k] = val
		end
	end
	pcall(function()
		lifecycle_observer(row)
	end)
end

local function dispose_door_entry(v, reason)
	if not v then
		return
	end
	if v.virtual and v.anchor then
		pcall(function()
			if v.anchor.Exists and v.anchor:Exists() and v.anchor.Remove then
				v.anchor:Remove()
			end
		end)
	end
	emit_lifecycle("cleanup", v, {reason = reason or "dispose"})
end

local function cleanup_stale_doors(tag)
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	if not desc or not desc.Data then
		for i = #item.doors, 1, -1 do
			dispose_door_entry(item.doors[i], tag or "no_room_data")
			table.remove(item.doors, i)
		end
		return
	end
	local ident = room_identity(desc, level)
	for i = #item.doors, 1, -1 do
		local v = item.doors[i]
		if v.should_kill_me or not entry_matches_room(v, ident) then
			dispose_door_entry(v, tag or "stale_room")
			table.remove(item.doors, i)
		end
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	for i = #item.doors, 1, -1 do
		dispose_door_entry(item.doors[i], "pre_new_level")
	end
	item.doors = {}
end,
})

-- priority -200: run before Golden Compass ensure (-90) so stale MeusNil is gone first.
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
priority = -200,
Function = function(_)
	-- Clear cross-room virtual door records + anchors before room init consumers run.
	cleanup_stale_doors("post_new_room")
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	if item.special_reminder then
		if (item.special_reminder.Type == nil or desc.Data.Type == item.special_reminder.Type) and (item.special_reminder.Variant == nil or desc.Data.Variant == item.special_reminder.Variant) then
			local ret = item.special_reminder.Funct()
			if ret then
				local ret2 = 0 if ret > 0 then ret2 = 1 end
				Screen_Filter.add_filter(ret,ret2)
			end
		end
	end
	item.special_reminder = nil
end,
})

local function apply_door_sprite_orient(s, dir, mov, scale)
	s.Scale = scale or Vector(1, 1)
	if dir == 0 then
		s.Rotation = 270
		s.Offset = Vector(mov, 0)
	elseif dir == 1 then
		s.Rotation = 0
		s.Offset = Vector(0, mov)
	elseif dir == 2 then
		s.Rotation = 90
		s.Offset = Vector(-mov, 0)
	elseif dir == 3 then
		s.Rotation = 180
		s.Offset = Vector(0, -mov)
	end
end

local function find_door_entry(ind_pos, desc, opts)
	opts = opts or {}
	local ident = room_identity(desc)
	for u, v in pairs(item.doors) do
		if entry_matches_room(v, ident, {
			idx = ind_pos,
			door_id = opts.door_id,
			slot = opts.slot,
		}) then
			return u
		end
	end
	return nil
end

local function tick_door_entry(v, room)
	if v.virtual then
		local anchor = v.anchor
		if not (anchor and anchor:Exists()) then
			return false
		end
		local s = anchor:GetSprite()
		if v.should_update and s then
			s:Update()
		end
		if v.on_update then
			v.on_update(v)
		end
		if v.update and s then
			local anim = s:GetAnimation()
			s:Update()
			if s:IsFinished(anim) then
				if anim == "Open" then
					s:Play("Opened", true)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_DOOR_HEAVY_OPEN, 1, 1, false, 0, 2)
				elseif anim == "Close" then
					s:Play("Closed", true)
				end
			end
		end
		item.try_enter_door(v)
		return true
	end

	local door = room:GetGridEntity(v.idx)
	if not door then
		return false
	end
	if v.should_update then
		door:GetSprite():Update()
	end
	if v.on_update then
		v.on_update(v)
	end
	if v.update then
		item.normal_update(v, door)
	end
	item.try_enter_door(v)
	return true
end

--- Shared enter path: pause / one-shot / can_enter guards before check_and_leave.
--- enter_detection = "confirmed_door": teleport_holder slot geometry + PRE_VIRTUAL_DOOR_ENTER.
--- Default: legacy auxi.check_pos_for_door (unchanged for other virtual doors).
function item.try_enter_door(v)
	if not v or not v.targ then
		return false
	end
	if v.enter_locked then
		return false
	end
	if Game():IsPaused() then
		return false
	end

	local player = nil
	local dist = nil
	local door_pos = nil
	if v.enter_detection == "confirmed_door" then
		local slot = v.refer_slot or v.slot
		local n = Game():GetNumPlayers()
		for i = 0, n - 1 do
			local p = Game():GetPlayer(i)
			local hit, d, _center, dpos = teleport_holder.player_in_slot_approach(p, slot, 25)
			if hit then
				player = p
				dist = d
				door_pos = dpos
				break
			end
		end
		if not player then
			return false
		end
	else
		player = auxi.check_pos_for_door(v.idx, item.dir_map[v.dir], v.inner)
		if not player then
			return false
		end
	end

	if v.can_enter and v.can_enter(v, player) ~= true then
		return false
	end

	if v.enter_detection == "confirmed_door" then
		local level = Game():GetLevel()
		local dim = nil
		pcall(function()
			if level.GetDimension then
				dim = level:GetDimension()
			end
		end)
		local room_index = nil
		pcall(function()
			room_index = level:GetCurrentRoomIndex()
		end)
		local blocked = callback_manager.work("PRE_VIRTUAL_DOOR_ENTER", function(funct, params)
			if params == nil or params == v.door_id then
				return funct(nil, player, {
					door_id = v.door_id,
					slot = v.refer_slot or v.slot,
					dimension = dim,
					door_position = door_pos,
					distance = dist,
					source_room_index = room_index,
					door_entry = v,
				})
			end
		end, false)
		if blocked == false then
			return false
		end
	end

	if v.special_reminder then
		item.special_reminder = {Type = v.Type, Variant = v.Variant, Funct = v.special_reminder}
	end
	if v.enter_once then
		v.enter_locked = true
	end
	Game():GetLevel().LeaveDoor = v.refer_slot or v.slot or 0
	if type(v.targ) == "string" then
		Isaac.ExecuteCommand("goto " .. v.targ)
	elseif type(v.targ) == "function" then
		v.targ(v, player)
	end
	return true
end

function item.find_door_by_id(door_id)
	if door_id == nil then
		return nil
	end
	local ident = room_identity()
	for _, v in pairs(item.doors) do
		if v.door_id == door_id and entry_matches_room(v, ident) then
			return v
		end
	end
	return nil
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local room = Game():GetRoom()
	local ident = (desc and desc.Data) and room_identity(desc, level) or nil
	for i = #item.doors,1,-1 do
		local v = item.doors[i]
		if (not ident) or v.should_kill_me or not entry_matches_room(v, ident) then
			dispose_door_entry(v, "post_update")
			table.remove(item.doors,i)
		else
			if not tick_door_entry(v, room) then
				dispose_door_entry(v, "tick_failed")
				table.remove(item.doors, i)
			end
		end
	end
end,
})

--- Virtual door carrier (MeusNil). With force_virtual, still creates an independent
--- sprite/interaction even when a native GRID_* already occupies the slot.
function item.try_spawn_virtual_door(room, slot, indx, params)
	params = params or {}
	params.allow_virtual = true
	params.on_render = true
	return item.try_spawn_grid_door(room, slot, indx, params)
end

local function spawn_virtual_anchor(room, slot, ind_pos, existing, params)
	local reuse = existing
		and existing.virtual == true
		and existing.anchor
		and existing.anchor.Exists
		and existing.anchor:Exists()
		and not (existing.anchor.IsDead and existing.anchor:IsDead())
	if reuse then
		return existing.anchor, "reuse"
	end
	if existing and existing.virtual and existing.anchor then
		pcall(function()
			if existing.anchor.Remove then
				existing.anchor:Remove()
			end
		end)
	end
	local pos = room:GetGridPosition(ind_pos)
	pcall(function()
		if slot and slot >= 0 then
			pos = room:GetDoorSlotPosition(slot)
		end
	end)
	local cooldown = params.anchor_cooldown or (30 * 60 * 30)
	local anchor = auxi.fire_nil(pos, Vector(0, 0), {cooldown = cooldown})
	if not anchor then
		return nil, "create_failed"
	end
	anchor:AddEntityFlags(EntityFlag.FLAG_RENDER_WALL | EntityFlag.FLAG_RENDER_FLOOR)
	if EntityFlag.FLAG_NO_REMOVE_ON_TEX_RENDER then
		anchor:AddEntityFlags(EntityFlag.FLAG_NO_REMOVE_ON_TEX_RENDER)
	end
	anchor:GetData().is_grid_door_sprite = true
	anchor:GetData().is_virtual_grid_door = true
	if params.door_id then
		anchor:GetData().grid_door_id = params.door_id
	end
	local action = (existing and existing.virtual) and "replace" or "create"
	return anchor, action
end

function item.try_spawn_grid_door(room,slot,indx,params)
	local level = Game():GetLevel()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	room = room or Game():GetRoom()
	params = params or {}
	local ind_pos = indx or -1
	if slot and slot >= 0 then ind_pos = room:GetGridIndex(room:GetDoorSlotPosition(slot)) end
	local tg = find_door_entry(ind_pos, desc, {
		door_id = params.door_id,
		slot = params.refer_slot or slot,
	})
	local existing = tg and item.doors[tg] or nil
	local door = room:GetGridEntity(ind_pos)
	local force_virtual = params.force_virtual == true and params.allow_virtual == true
	local virtual = false
	local anchor = nil
	local under_grid = nil
	local life_action = nil
	if door == nil or force_virtual then
		if params.allow_virtual ~= true then
			return
		end
		virtual = true
		if force_virtual and door then
			under_grid = door
			-- Keep native TargetRoomIndex / grid identity; only hide draw + seal walk-in.
			if params.hide_native_sprite ~= false then
				pcall(function()
					local ns = door:GetSprite()
					if ns and ns.Load then
						ns:Load("gfx/effects/nil_effect.anm2", true)
						ns:Play("Idle", true)
					end
				end)
			end
			if params.seal_native_collision ~= false then
				pcall(function()
					door.CollisionClass = GridCollisionClass.COLLISION_WALL
				end)
			end
		end
		anchor, life_action = spawn_virtual_anchor(room, slot, ind_pos, existing, params)
		if not anchor then
			return
		end
	end

	local s
	if virtual then
		s = anchor:GetSprite()
	else
		s = door:GetSprite()
		if params.on_render and (not auxi.check_if_any(item.movable_roomtype[desc.Data.Type],nil)) and (not (Game():GetLevel():GetStage() == 11 and Game():GetLevel():GetStageType() == 0)) then
			if existing and existing.anchor then
				pcall(function()
					if existing.anchor.Remove then
						existing.anchor:Remove()
					end
				end)
			end
			-- Legacy overlay path: short-lived carrier over an existing grid door sprite.
			anchor = auxi.fire_nil(room:GetGridPosition(ind_pos),Vector(0,0),{cooldown = 10 * 30,})
			anchor:AddEntityFlags(EntityFlag.FLAG_RENDER_WALL | EntityFlag.FLAG_RENDER_FLOOR)
			anchor:GetData().is_grid_door_sprite = true
			s:Load("gfx/effects/nil_effect.anm2",true)
			s:Play("Idle",true)
			s = anchor:GetSprite()
			life_action = "create"
		end
	end

	params.init_work = params.init_work or item.init_work
	params.init_work(s,params)
	local dir = item.slot_dir_map[slot] or params.dir or 0
	local mov = params.mov or 15
	apply_door_sprite_orient(s, dir, mov, params.scale)
	if door and not force_virtual and auxi.check_if_any(params.should_not_allow,params) ~= true then
		door.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
	end
	local cur_desc = level:GetCurrentRoomDesc()
	local tbl = {
		door = door,
		under_grid = under_grid,
		anchor = anchor,
		virtual = virtual == true,
		force_virtual = force_virtual == true,
		targ = params.check_and_leave,
		idx = ind_pos,
		dir = dir,
		slot = slot or 0,
		refer_slot = params.refer_slot or slot or 0,
		safe_grid_index = cur_desc.SafeGridIndex,
		safe_grid_variant = cur_desc.Data.Variant,
		safe_grid_type = cur_desc.Data.Type,
		dimension = read_dimension(level),
		Type = params.tp,
		Variant = params.vr,
		special_reminder = params.special_reminder,
		on_update = params.on_update,
		should_update = params.should_update,
		inner = params.inner,
		door_id = params.door_id,
		enter_detection = params.enter_detection,
		enter_once = params.enter_once == true,
		enter_locked = false,
		can_enter = params.can_enter,
	}
	if tg == nil then table.insert(item.doors,tbl)
	else item.doors[tg] = tbl end
	if life_action then
		emit_lifecycle(life_action, tbl, {
			source_tag = params.lifecycle_tag or params.source_tag,
		})
	end
	return virtual and anchor or door
end

function item.snapshot_door_entry(door_id)
	local v = item.find_door_by_id(door_id)
	if not v then
		return nil
	end
	local spr = nil
	pcall(function()
		if v.virtual and v.anchor then
			spr = v.anchor:GetSprite()
		elseif v.door then
			spr = v.door:GetSprite()
		end
	end)
	local under = v.under_grid or v.door
	local under_type, under_collision = nil, nil
	pcall(function()
		if under then
			under_type = under.GetType and under:GetType() or under.Type
			under_collision = under.CollisionClass
		end
	end)
	return {
		door_id = v.door_id,
		virtual = v.virtual == true,
		force_virtual = v.force_virtual == true,
		slot = v.slot,
		idx = v.idx,
		safe_grid_index = v.safe_grid_index,
		safe_grid_type = v.safe_grid_type,
		safe_grid_variant = v.safe_grid_variant,
		dimension = v.dimension,
		anchor_exists = v.anchor ~= nil and v.anchor.Exists and v.anchor:Exists() == true,
		sprite_filename = spr and spr.GetFilename and spr:GetFilename() or nil,
		sprite_animation = spr and spr.GetAnimation and spr:GetAnimation() or nil,
		under_grid_type = under_type,
		under_collision = under_collision,
		enter_locked = v.enter_locked == true,
	}
end

function item.force_door_anim(anim)		--先写个全部关上的
	anim = anim or "Close"
	local room = Game():GetRoom()
	for u,v in pairs(item.doors) do
		local door = room:GetGridEntity(v.idx)
		door:GetSprite():Play(anim,true)
		if v.on_update == nil then v.update = true end
		if anim == "Close" then door.CollisionClass = GridCollisionClass.COLLISION_WALL end
	end
end

function item.normal_update(v,door)
	local room = Game():GetRoom() local grid = room:GetGridEntity(v.idx)
	local s = grid:GetSprite() local anim = s:GetAnimation() s:Update()
	if s:IsFinished(anim) then
		if anim == "Open" then s:Play("Opened",true) grid.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER sound_tracker.PlayStackedSound(SoundEffect.SOUND_DOOR_HEAVY_OPEN,1,1,false,0,2) end
		if anim == "Close" then s:Play("Closed",true) end
	end
end

return item

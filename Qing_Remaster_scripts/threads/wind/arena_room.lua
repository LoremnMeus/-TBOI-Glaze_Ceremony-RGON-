-- Formal Zennith Arena RoomConfig owner.
-- No goto. Fail loud when config/placement cannot be confirmed.

local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local save = require("Qing_Remaster_scripts.core.savedata")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

local M = {
	own_key = "thread_wind_arena_",
	ARENA = {
		id = "zennith_arena",
		room_type = RoomType.ROOM_DEFAULT,
		variant = 24680,
		shape = RoomShape.ROOMSHAPE_1x1,
		width = 13,
		height = 7,
	},
}

local function key(name)
	return M.own_key .. name
end

function M.lookup_config()
	local holder = rawget(_G, "RoomConfig") or rawget(_G, "RoomConfigHolder")
	if not holder or not holder.GetRoomByStageTypeAndVariant then
		return nil, "no_api"
	end
	local mode = Game():IsGreedMode() and 1 or 0
	local ok, cfg = pcall(
		holder.GetRoomByStageTypeAndVariant,
		StbType.SPECIAL_ROOMS,
		M.ARENA.room_type,
		M.ARENA.variant,
		mode
	)
	if ok and cfg then
		return cfg, "ok"
	end
	ok, cfg = pcall(
		holder.GetRoomByStageTypeAndVariant,
		StbType.SPECIAL_ROOMS,
		M.ARENA.room_type,
		M.ARENA.variant,
		-1
	)
	if ok and cfg then
		return cfg, "ok_m1"
	end
	return nil, "room_not_loaded"
end

function M.validate_config(cfg)
	if not cfg then return false, "nil_config" end
	local typ = cfg.Type or cfg.type
	local variant = cfg.Variant or cfg.variant
	local shape = cfg.Shape or cfg.shape
	if typ ~= M.ARENA.room_type then
		return false, "type_mismatch:" .. tostring(typ)
	end
	if variant ~= M.ARENA.variant then
		return false, "variant_mismatch:" .. tostring(variant)
	end
	if shape ~= nil and shape ~= M.ARENA.shape then
		return false, "shape_mismatch:" .. tostring(shape)
	end
	return true, "ok"
end

function M.clear()
	save.elses[key("sgid")] = nil
	save.elses[key("dim")] = nil
	save.elses[key("prepared")] = nil
	save.elses[key("last_error")] = nil
end

function M.get_sgid()
	return save.elses[key("sgid")]
end

function M.get_last_error()
	return save.elses[key("last_error")]
end

local function set_error(code)
	save.elses[key("last_error")] = code
	return nil, code
end

--- Place / queue a dedicated arena slot. Returns sgid or nil, err.
function M.ensure_room()
	local cfg, reason = M.lookup_config()
	if not cfg then
		return set_error("lookup_failed:" .. tostring(reason))
	end
	local ok_cfg, cfg_err = M.validate_config(cfg)
	if not ok_cfg then
		return set_error(cfg_err)
	end

	local existing = save.elses[key("sgid")]
	local dim = auxi.GetDimension and auxi.GetDimension() or 0
	if existing ~= nil then
		local desc = Game():GetLevel():GetRoomByIdx(existing, save.elses[key("dim")] or dim)
		if desc and desc.Data then
			local v = desc.Data.Variant
			local t = desc.Data.Type
			if v == M.ARENA.variant and t == M.ARENA.room_type then
				save.elses[key("prepared")] = true
				return existing, "already"
			end
		end
	end

	local level = Game():GetLevel()
	local hub_index = nil
	if level.TryPlaceRoom then
		local seed = level:GetDungeonPlacementSeed()
		for grid_index = 0, 168 do
			local desc = level:GetRoomByIdx(grid_index, dim)
			if desc and desc.Data == nil then
				local success, placed = pcall(function()
					return level:TryPlaceRoom(
						cfg,
						grid_index,
						dim,
						seed + grid_index,
						true,
						true,
						true
					)
				end)
				if success and placed then
					hub_index = placed.SafeGridIndex or placed.GridIndex or grid_index
					break
				end
			end
		end
	end

	if hub_index == nil then
		hub_index = Room_holder.Allocate_with()
		if not hub_index or hub_index < 0 then
			return set_error("allocate_failed")
		end
		-- Inject confirmed RoomConfig only — never goto / never copy eye layout.
		Room_holder.Try_replace_with(hub_index, dim, {
			data = function()
				local live, live_reason = M.lookup_config()
				if not live then
					save.elses[key("last_error")] = "replace_lookup_failed:" .. tostring(live_reason)
					return nil
				end
				local vok, verr = M.validate_config(live)
				if not vok then
					save.elses[key("last_error")] = "replace_invalid:" .. tostring(verr)
					return nil
				end
				return live
			end,
		})
	end

	save.elses[key("sgid")] = hub_index
	save.elses[key("dim")] = dim
	save.elses[key("prepared")] = true
	save.elses[key("last_error")] = nil
	return hub_index, "prepared"
end

function M.is_current()
	local sgid = save.elses[key("sgid")]
	if sgid == nil then return false end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return false end
	if desc.SafeGridIndex ~= sgid then return false end
	local dim = tonumber(save.elses[key("dim")]) or 0
	return auxi.check_equal(auxi.GetDimension(), dim)
end

function M.validate_current()
	if not M.is_current() then
		return false, "not_current"
	end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc or not desc.Data then
		return false, "no_data"
	end
	if desc.Data.Type ~= M.ARENA.room_type then
		return false, "type_mismatch"
	end
	if desc.Data.Variant ~= M.ARENA.variant then
		return false, "variant_mismatch"
	end
	return true, "ok"
end

return M

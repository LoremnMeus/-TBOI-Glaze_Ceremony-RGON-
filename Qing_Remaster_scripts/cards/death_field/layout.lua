-- Death Field layout: stable norm identity + deterministic room mapping
-- norm = 长期相对位置（进场后不因普通换房改写）
-- _spawn_pos = 本房临时安全落点（可因障碍微调，不写回 norm）
local C = require("Qing_Remaster_scripts.cards.death_field.constants")
local Mapper = require("Qing_Remaster_scripts.others.room_space_mapper")

local M = {}

local function clamp01(x)
	x = tonumber(x) or 0
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

local function map_opts()
	return {margin = C.ROOM_MARGIN or Mapper.DEFAULT_MARGIN}
end

function M.norm_to_world(norm_x, norm_y)
	return Mapper.norm_to_world(norm_x, norm_y, map_opts())
end

function M.world_to_norm(pos)
	return Mapper.world_to_norm(pos, map_opts())
end

local function spacing_ok(pos, placed)
	local min_d = C.MIN_SPACING or 48
	for i = 1, #placed do
		if (placed[i] - pos):Length() < min_d then
			return false
		end
	end
	return true
end

--- 确定性局部搜索：固定半径环 + FindFreePickupSpawnPosition，不用 RNG
function M.find_safe_deterministic(target, placed)
	placed = placed or {}
	local room = Game():GetRoom()
	local best, best_d = nil, nil
	local radii = {0, 24, 48, 72, 96, 120}
	local angles = {0, 45, 90, 135, 180, 225, 270, 315}

	local function consider(cand)
		local free = room:FindFreePickupSpawnPosition(cand, 0, true)
		if not free then
			return
		end
		if not spacing_ok(free, placed) then
			return
		end
		local d = (free - target):Length()
		if best == nil or d < best_d then
			best = free
			best_d = d
		end
	end

	for _, r in ipairs(radii) do
		if r == 0 then
			consider(target)
		else
			for _, deg in ipairs(angles) do
				local rad = deg * (math.pi / 180)
				consider(target + Vector(math.cos(rad) * r, math.sin(rad) * r))
			end
		end
		if best then
			return best
		end
	end

	-- 兜底：引擎自由点（仍可能间距不足，但保证有落点）
	return room:FindFreePickupSpawnPosition(target, 0, true) or target
end

--- 按 uid 升序稳定布局；不改写 norm、不用 RNG
function M.place_entries(entries)
	local list = {}
	for _, e in ipairs(entries or {}) do
		list[#list + 1] = e
	end
	table.sort(list, function(a, b)
		return (tonumber(a.uid) or 0) < (tonumber(b.uid) or 0)
	end)

	local placed = {}
	for _, entry in ipairs(list) do
		local nx = entry.norm_x
		local ny = entry.norm_y
		if nx == nil or ny == nil then
			nx, ny = 0.5, 0.5
			entry.norm_x, entry.norm_y = nx, ny
		else
			nx, ny = clamp01(nx), clamp01(ny)
			entry.norm_x, entry.norm_y = nx, ny
		end
		local target = M.norm_to_world(nx, ny)
		local pos = M.find_safe_deterministic(target, placed)
		entry._spawn_pos = pos
		placed[#placed + 1] = pos
	end
	return placed
end

--- 首次进场：确定性等角环，写稳定 norm（不随机）
function M.init_around_player(player, count)
	count = math.max(0, math.floor(tonumber(count) or 0))
	local norms = {}
	if count <= 0 then
		return norms
	end
	local base = player.Position
	local base_ang = (C.INITIAL_BASE_ANGLE or 22.5) * (math.pi / 180)
	local rad = C.INITIAL_RADIUS or 84
	for i = 1, count do
		local ang = base_ang + (i - 1) * (2 * math.pi / count)
		local world = base + Vector(math.cos(ang) * rad, math.sin(ang) * rad)
		local nx, ny = M.world_to_norm(world)
		norms[i] = {norm_x = nx, norm_y = ny}
	end
	return norms
end

--- 无世界位置时：在已有 entry 角度空隙中央落点（不移动旧 entry）
function M.find_slot_for_new_entry(player, existing_entries)
	existing_entries = existing_entries or {}
	local center = player and player.Position or Game():GetRoom():GetCenterPos()
	local n = #existing_entries
	if n == 0 then
		local world = center + Vector(C.INITIAL_RADIUS or 84, 0)
		local nx, ny = M.world_to_norm(world)
		return nx, ny
	end

	local angles = {}
	for _, e in ipairs(existing_entries) do
		local w = M.norm_to_world(e.norm_x or 0.5, e.norm_y or 0.5)
		local delta = w - center
		local ang
		if math.atan2 then
			ang = math.atan2(delta.Y, delta.X)
		else
			ang = math.atan(delta.Y, delta.X)
		end
		if ang < 0 then
			ang = ang + 2 * math.pi
		end
		angles[#angles + 1] = ang
	end
	table.sort(angles)

	local best_mid = angles[1] + math.pi
	local best_gap = -1
	for i = 1, #angles do
		local a0 = angles[i]
		local a1 = angles[i % #angles + 1]
		local gap = a1 - a0
		if i == #angles then
			gap = (a1 + 2 * math.pi) - a0
		end
		if gap > best_gap then
			best_gap = gap
			best_mid = a0 + gap * 0.5
			if best_mid >= 2 * math.pi then
				best_mid = best_mid - 2 * math.pi
			end
		end
	end

	local rad = C.INITIAL_RADIUS or 84
	local world = center + Vector(math.cos(best_mid) * rad, math.sin(best_mid) * rad)
	local placed = {}
	for _, e in ipairs(existing_entries) do
		placed[#placed + 1] = M.norm_to_world(e.norm_x or 0.5, e.norm_y or 0.5)
	end
	local safe = M.find_safe_deterministic(world, placed)
	return M.world_to_norm(safe)
end

return M

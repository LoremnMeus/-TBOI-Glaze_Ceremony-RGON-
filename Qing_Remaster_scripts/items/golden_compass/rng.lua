-- Golden Compass: Root Seed + avalanche child-stream derivation.
-- Formal content RNG must come from collectible Next() root, never DungeonPlacementSeed / or-1.

local M = {}

local MASK = 0xffffffff

local function u32(x)
	x = math.floor(tonumber(x) or 0) % 4294967296
	if x < 0 then
		x = x + 4294967296
	end
	return x
end

local function avalanche32(x)
	x = u32(x)
	x = u32(x ~ (x >> 16))
	x = u32(x * 0x85ebca6b)
	x = u32(x ~ (x >> 13))
	x = u32(x * 0xc2b2ae35)
	x = u32(x ~ (x >> 16))
	return x
end

local function mix_string(acc, s)
	acc = u32(acc)
	s = tostring(s or "")
	for i = 1, #s do
		acc = avalanche32(acc ~ string.byte(s, i) ~ (i * 0x9e3779b9))
	end
	return acc
end

--- Deterministic 32-bit child seed. Not collision-proof; isolates domains well enough for floor gen.
--- @param root_seed number
--- @param domain string e.g. "room_layout", "neg_award"
--- @param sgid number|nil signed safe-grid / GridRooms index
--- @param index number|nil sub-stream index within domain
function M.derive_seed(root_seed, domain, sgid, index)
	root_seed = tonumber(root_seed)
	if not root_seed or root_seed <= 0 then
		return nil, "missing_root_seed"
	end
	local acc = avalanche32(root_seed)
	acc = mix_string(acc, domain or "default")
	acc = avalanche32(acc ~ u32((tonumber(sgid) or 0) * 0x85ebca6b + 0x9e3779b9))
	acc = avalanche32(acc ~ u32((tonumber(index) or 0) + 1) * 0xc2b2ae35)
	acc = avalanche32(acc)
	if acc == 0 then
		acc = 1
	end
	return acc, nil
end

function M.make_rng(root_seed, domain, sgid, index)
	local seed, err = M.derive_seed(root_seed, domain, sgid, index)
	if not seed then
		return nil, nil, err
	end
	local rng = RNG()
	rng:SetSeed(seed, 35)
	return rng, seed, nil
end

--- Advance collectible RNG once for a new corridor appointment.
function M.take_root_seed(player, item_id)
	if not player or not item_id or item_id <= 0 then
		return nil, "no_player_or_item"
	end
	if not player.GetCollectibleRNG then
		return nil, "no_collectible_rng"
	end
	local item_rng = player:GetCollectibleRNG(item_id)
	if not item_rng or not item_rng.Next then
		return nil, "rng_missing"
	end
	local root = item_rng:Next()
	if not root or root == 0 then
		root = item_rng:Next()
	end
	if not root or root == 0 then
		return nil, "root_seed_zero"
	end
	return root, nil
end

M.avalanche32 = avalanche32
M.u32 = u32

return M

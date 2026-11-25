-- Golden Compass corridor room plan (production).
-- Content RNG: root_seed from Golden Compass collectible Next(); child streams via golden_compass.rng.
-- Probe owns placement / rematerialize / door gate / deal suppress.
-- 78 = STB 25600 empty (default); Water II 25603 (LEFT closed); Mines II 25604 (UP closed).
-- 84 = STB 25602 fireplace-only; Water II → 25606 white fire (options deferred).
-- ROOM_DEFAULT combat (82/85/88): stage RoomSet only; filter White Fire / Button / Fool by floor.
-- Combat also filters Difficulty by stage/hard band (never Difficulty 0); local Weight decay 0.1 across 82→85→88.
-- Content preference miss → 25600 degrade (still content_complete); only missing usable cfg fails completeness.
-- ROOM_DEFAULT: stage RoomSet only + Weight (never SPECIAL_ROOMS / Shadoll mix).
-- Challenge: Subtype 0/1 only. Miniboss: exclude Greed / Super Greed / Krampus.
-- pending.force_boss_subtype: one-shot forced Boss RoomConfig.Subtype (e.g. Mom=6).
-- Shop: 1/256 rare type first, then weight; Tainted Keeper uses 100–104 / 110–111 only.
-- Deal@90 devil: Number Magnet → DEVIL_NUMBER_MAGNET(1), else DEVIL_NORMAL(0); angel unchanged.

local deal_holder = require("Qing_Remaster_scripts.callbacks.deal_chance_holder")
local deal_semantics = require("Qing_Remaster_scripts.auxiliary.deal_chance_semantics")

local M = {}

local SHAPE_1X1 = RoomShape.ROOMSHAPE_1x1
local DOOR_LEFT = (1 << DoorSlot.LEFT0)
local DOOR_RIGHT = (1 << DoorSlot.RIGHT0)
local DOOR_UP = (1 << DoorSlot.UP0)
local DOOR_DOWN = (1 << DoorSlot.DOWN0)
local DOOR_LR = DOOR_LEFT | DOOR_RIGHT
local DOOR_LRD = DOOR_LR | DOOR_DOWN
local DOOR_LRUD = DOOR_LR | DOOR_UP | DOOR_DOWN
local ROOM_VARIANT_EMPTY = 25600
-- Downpour II mirror entry: LEFT0 exists=False + corner blue fires (33.2).
local ROOM_VARIANT_WATER_II_MIRROR_ENTRY = 25603
-- Mines II mineshaft entry: UP0 exists=False (virtual planks door).
local ROOM_VARIANT_MINES_II_MINESHAFT_ENTRY = 25604
-- Mines II Dim1 reward: fixed Knife Piece 2 (627) pedestal.
local ROOM_VARIANT_MINES_II_KNIFE2_REWARD = 25605
local ROOM_VARIANT_FIXED_84 = 25602
-- Downpour II fixed 84: same layout as 25602, center fireplace → white fire (33.4).
local ROOM_VARIANT_WATER_II_84_WHITE_FIRE = 25606
-- Vanilla stage RoomSet special combat bands (not SPECIAL_ROOMS).
-- Closed upper bounds: open-ended >=N wrongly tags Fool/custom variants (e.g. 17775).
local VARIANT_BAND_WHITE_FIRE_OR_BUTTON_LO = 5000
local VARIANT_BAND_WHITE_FIRE_OR_BUTTON_HI = 5500
local VARIANT_BAND_FOOL_ROOM_LO = 10000
local VARIANT_BAND_FOOL_ROOM_HI = 10500
-- Verified spawn encodings in extracted stage XML:
local SPAWN_WHITE_FIRE_TYPE = 33
local SPAWN_WHITE_FIRE_VARIANT = 4
local SPAWN_MINES_BUTTON_TYPE = 4500
local SPAWN_MINES_BUTTON_VARIANT = 3
local SPAWN_X_SKULL_TYPE = 1008 -- STB grid id → GRID_ROCK_ALT2
local DEFAULT_COMBAT_SGIDS = {82, 85, 88}
-- Mines II custom reward teleport target (Dimension.KNIFE_PUZZLE / 1).
M.MINESHAFT_TARGET_SGID = 162
M.ROOM_VARIANT_MINES_II_KNIFE2_REWARD = ROOM_VARIANT_MINES_II_KNIFE2_REWARD
M.KNIFE_PIECE_2 = (CollectibleType and CollectibleType.COLLECTIBLE_KNIFE_PIECE_2) or 627

M.ENTRY_SGID = 78
M.FIXED_84_SGID = 84
-- Challenge/miniboss sits near Boss; reward pool is earlier on the corridor.
M.REWARD_SGID = 81
M.CHALLENGE_SGID = 87
M.BOSS_SGID = 89
M.DEAL_SGID = 90
M.ROOM_VARIANT_EMPTY = ROOM_VARIANT_EMPTY
M.ROOM_VARIANT_WATER_II_MIRROR_ENTRY = ROOM_VARIANT_WATER_II_MIRROR_ENTRY
M.ROOM_VARIANT_MINES_II_MINESHAFT_ENTRY = ROOM_VARIANT_MINES_II_MINESHAFT_ENTRY
M.ROOM_VARIANT_MINES_II_KNIFE2_REWARD = ROOM_VARIANT_MINES_II_KNIFE2_REWARD
M.ROOM_VARIANT_FIXED_84 = ROOM_VARIANT_FIXED_84
M.ROOM_VARIANT_WATER_II_84_WHITE_FIRE = ROOM_VARIANT_WATER_II_84_WHITE_FIRE
M.DEFAULT_COMBAT_SGIDS = DEFAULT_COMBAT_SGIDS

--- Water II = Downpour II only (not Dross).
function M.is_water_ii(stage, stage_type)
	stage = tonumber(stage)
	stage_type = tonumber(stage_type)
	local st_rep = StageType and StageType.STAGETYPE_REPENTANCE
	return stage == LevelStage.STAGE1_2
		and st_rep ~= nil
		and stage_type == st_rep
end

--- Mines II only (not Ashpit II).
function M.is_mines_ii(stage, stage_type)
	stage = tonumber(stage)
	stage_type = tonumber(stage_type)
	local st_rep = StageType and StageType.STAGETYPE_REPENTANCE
	return stage == LevelStage.STAGE2_2
		and st_rep ~= nil
		and stage_type == st_rep
end

local function is_repentance_alt_stage_type(stage_type)
	stage_type = tonumber(stage_type)
	local st_rep = StageType and StageType.STAGETYPE_REPENTANCE
	local st_rep_b = StageType and StageType.STAGETYPE_REPENTANCE_B
	return (st_rep ~= nil and stage_type == st_rep)
		or (st_rep_b ~= nil and stage_type == st_rep_b)
end

--- Downpour / Dross chapter (Water I or II).
function M.is_water_chapter(stage, stage_type)
	stage = tonumber(stage)
	return (stage == LevelStage.STAGE1_1 or stage == LevelStage.STAGE1_2)
		and is_repentance_alt_stage_type(stage_type)
end

--- Mines / Ashpit chapter (Mines I or II).
function M.is_mines_chapter(stage, stage_type)
	stage = tonumber(stage)
	return (stage == LevelStage.STAGE2_1 or stage == LevelStage.STAGE2_2)
		and is_repentance_alt_stage_type(stage_type)
end

function M.is_fixed_84_variant(variant)
	local v = tonumber(variant)
	return v == ROOM_VARIANT_FIXED_84 or v == ROOM_VARIANT_WATER_II_84_WHITE_FIRE
end

function M.fixed_84_variant_for_floor(stage, stage_type)
	if M.is_water_ii(stage, stage_type) then
		return ROOM_VARIANT_WATER_II_84_WHITE_FIRE
	end
	return ROOM_VARIANT_FIXED_84
end

function M.entry_78_variant_for_floor(stage, stage_type)
	if M.is_water_ii(stage, stage_type) then
		return ROOM_VARIANT_WATER_II_MIRROR_ENTRY
	end
	if M.is_mines_ii(stage, stage_type) then
		return ROOM_VARIANT_MINES_II_MINESHAFT_ENTRY
	end
	return ROOM_VARIANT_EMPTY
end

function M.is_entry_78_variant(variant)
	local v = tonumber(variant)
	return v == ROOM_VARIANT_EMPTY
		or v == ROOM_VARIANT_WATER_II_MIRROR_ENTRY
		or v == ROOM_VARIANT_MINES_II_MINESHAFT_ENTRY
end

--- Water II 25603 has LEFT exists=False — do not force-reserve AllowedDoors LEFT0.
function M.should_reserve_mirror_left0_allowed(stage, stage_type, live_variant)
	if M.is_water_ii(stage, stage_type) then
		return false
	end
	if tonumber(live_variant) == ROOM_VARIANT_WATER_II_MIRROR_ENTRY then
		return false
	end
	return true
end

--- Mines II 25604 has UP exists=False — do not force-reserve AllowedDoors UP0.
function M.should_reserve_mineshaft_up0_allowed(stage, stage_type, live_variant)
	if M.is_mines_ii(stage, stage_type) then
		return false
	end
	if tonumber(live_variant) == ROOM_VARIANT_MINES_II_MINESHAFT_ENTRY then
		return false
	end
	return true
end
M.DOOR_LR = DOOR_LR
M.DOOR_LRD = DOOR_LRD
M.DOOR_LRUD = DOOR_LRUD
M.SECRET_EXIT_IDX = (GridRooms and GridRooms.ROOM_SECRET_EXIT_IDX) or -10
M.SECRET_SHOP_IDX = (GridRooms and GridRooms.ROOM_SECRET_SHOP_IDX) or -13
M.ANGEL_SHOP_IDX = (GridRooms and GridRooms.ROOM_ANGEL_SHOP_IDX) or -18
M.BOSS_RUSH_IDX = (GridRooms and GridRooms.ROOM_BOSSRUSH_IDX) or -5
M.BLUE_WOMB_IDX = (GridRooms and GridRooms.ROOM_BLUE_WOOM_IDX) or -8
-- Mom fight test: SPECIAL_ROOMS / 6030 "Mom (mausoleum)".
-- Dad's Note prep (BACKWARDS_PATH_INIT): stage STB Boss Variant 1 Subtype 89 "Mom" — not 6030.
M.BOSS_VARIANT_MOM_MAUSOLEUM = 6030
M.BOSS_VARIANT_DADS_NOTE_PREP = 1
M.BOSS_VARIANT_MOMS_HEART_MAUSOLEUM = 6040
M.BOSS_VARIANT_MOTHER_GATE = 6000
M.BOSS_VARIANT_MOTHER_ARENA = 1
M.BOSS_SUBTYPE_MOM_MAUSOLEUM = (BossType and BossType.MOM_MAUSOLEUM) or 89
M.BOSS_SUBTYPE_MOMS_HEART_MAUSOLEUM = (BossType and BossType.MOMS_HEART_MAUSOLEUM) or 90
M.BOSS_SUBTYPE_MOTHER = (BossType and BossType.MOTHER) or 88

-- Fixed position map. required_doors = slots the RoomConfig must support (not all must link).
-- 82 DOWN→95 secret; 85 DOWN→98 curse (+ optional UP→72 when Voodoo Head).
-- 81 = random reward; 87 = challenge/miniboss (entry neighbors 86/88).
M.ASSIGNMENTS = {
	-- fixed_variant resolved per-floor in build() (Water II → 25603, Mines II → 25604).
	{sgid = 78, kind = "empty_entry", room_type = RoomType.ROOM_DEFAULT, required_doors = DOOR_RIGHT, fixed_variant = ROOM_VARIANT_EMPTY},
	{sgid = 79, kind = "treasure", room_type = RoomType.ROOM_TREASURE, required_doors = DOOR_LR},
	{sgid = 80, kind = "shop", room_type = RoomType.ROOM_SHOP, required_doors = DOOR_LR},
	{sgid = 81, kind = "reward_pool", required_doors = DOOR_LR},
	{sgid = 82, kind = "default", room_type = RoomType.ROOM_DEFAULT, required_doors = DOOR_LRD},
	{sgid = 83, kind = "treasure", room_type = RoomType.ROOM_TREASURE, required_doors = DOOR_LR},
	{sgid = 84, kind = "fixed_fire_options", room_type = RoomType.ROOM_DEFAULT, required_doors = DOOR_LR, fixed_variant = ROOM_VARIANT_FIXED_84},
	{sgid = 85, kind = "default", room_type = RoomType.ROOM_DEFAULT, required_doors = DOOR_LRUD},
	{sgid = 86, kind = "shop", room_type = RoomType.ROOM_SHOP, required_doors = DOOR_LR},
	{sgid = 87, kind = "challenge_or_miniboss", required_doors = DOOR_LR},
	{sgid = 88, kind = "default", room_type = RoomType.ROOM_DEFAULT, required_doors = DOOR_LR},
	{sgid = 89, kind = "boss", room_type = RoomType.ROOM_BOSS, required_doors = DOOR_LR},
	{sgid = 90, kind = "deal", required_doors = DOOR_LEFT},
}

local REWARD_TYPES = {
	RoomType.ROOM_LIBRARY,
	RoomType.ROOM_ARCADE,
	RoomType.ROOM_DICE,
	RoomType.ROOM_PLANETARIUM,
}

local compass_rng = require("Qing_Remaster_scripts.items.golden_compass.rng")
-- Eager pin: late require from MC_POST_NEW_ROOM / MC_PRE_NEW_ROOM cannot resolve Qing package.path.
local boss_pick = require("Qing_Remaster_scripts.items.golden_compass.boss_pick")
local boss_pool_catalog = require("Qing_Remaster_scripts.items.golden_compass.boss_pool_catalog")
-- Pin for runtime.lua (Luna/Fragmented north mirror); do not first-require from callbacks.
do
	local north_path = "Qing_Remaster_scripts.items.golden_compass.north_secret_mirror"
	require(north_path)
	local north = package.loaded[north_path]
	if type(north) ~= "table"
		or type(north.append_to_special_room_plan) ~= "function"
		or type(north.finalize_after_place) ~= "function"
	then
		error("golden_compass.corridor_plan: north_secret_mirror eager-pin missing API")
	end
end
-- Pin StageAPI fixed-room layout guard (78/84/X-skull); StageAPI may be nil at load.
do
	local guard_path = "Qing_Remaster_scripts.items.golden_compass.stageapi_layout_guard"
	require(guard_path)
	local guard = package.loaded[guard_path]
	if type(guard) ~= "table" or type(guard.activate_for_pending) ~= "function" then
		error("golden_compass.corridor_plan: stageapi_layout_guard eager-pin missing API")
	end
end

local function room_config_holder()
	return rawget(_G, "RoomConfig") or rawget(_G, "RoomConfigHolder")
end

local function make_sgid_rng(root_seed, sgid, domain)
	local rng, seed, err = compass_rng.make_rng(root_seed, domain or "room_layout", sgid, 0)
	if not rng then
		error("golden_compass.corridor_plan: " .. tostring(err or "rng_failed"))
	end
	return rng, seed
end

-- Challenge entrance layouts only (not wave config Subtype 10/11/12).
local CHALLENGE_ENTRY_SUBTYPES = {
	[(RoomSubType and RoomSubType.CHALLENGE_NORMAL) or 0] = true,
	[(RoomSubType and RoomSubType.CHALLENGE_BOSS) or 1] = true,
}
-- Exclude special minibosses that should not appear as corridor challenge/miniboss.
local MINIBOSS_EXCLUDED_SUBTYPES = {
	[(RoomSubType and RoomSubType.MINIBOSS_GREED) or 4] = true,
	[(RoomSubType and RoomSubType.MINIBOSS_SUPER_GREED) or 11] = true,
	[(RoomSubType and RoomSubType.MINIBOSS_KRAMPUS) or 15] = true,
}

local function collect_roomset_candidates(stb, room_type, required_doors)
	local out = {}
	local need = required_doors or DOOR_LR
	local holder = room_config_holder()
	if not holder or not holder.GetStage or stb == nil then
		return out
	end
	local stage_cfg = nil
	local ok = pcall(function()
		stage_cfg = holder.GetStage(stb)
	end)
	if not (ok and stage_cfg and stage_cfg.GetRoomSet) then
		return out
	end
	local set = nil
	ok = pcall(function()
		set = stage_cfg:GetRoomSet(0)
	end)
	if not (ok and set) then
		return out
	end
	local size = 0
	pcall(function()
		size = set.Size or #set or 0
	end)
	for i = 0, size - 1 do
		local room = nil
		pcall(function()
			room = set:Get(i)
		end)
		if room and room.Type == room_type and room.Shape == SHAPE_1X1 then
			local doors = room.Doors or 0
			if (doors & need) == need then
				local spawn_count = 0
				local weight = 1
				pcall(function()
					spawn_count = room.SpawnCount or 0
				end)
				pcall(function()
					weight = tonumber(room.Weight)
						or tonumber(room.weight)
						or tonumber(room.InitialWeight)
						or 1
				end)
				out[#out + 1] = {
					cfg = room,
					stb = stb,
					type = room.Type,
					variant = room.Variant,
					shape = room.Shape,
					doors = doors,
					subtype = room.Subtype,
					difficulty = room.Difficulty,
					name = room.Name,
					spawn_count = spawn_count,
					weight = weight,
				}
			end
		end
	end
	return out
end

-- Forward: void_history_mix path inside merge_candidates filters by subtype.
local filter_candidates_by_subtype

--- opts.stage_only: never merge SPECIAL_ROOMS (ROOM_DEFAULT combat).
local function merge_candidates(room_type, stage_stb, required_doors, opts)
	opts = opts or {}
	local seen = {}
	local merged = {}
	local sources = {}
	local function add_list(list, label)
		sources[#sources + 1] = {label = label, count = #list}
		for _, row in ipairs(list) do
			local key = string.format(
				"%s:%s:%s:%s",
				tostring(row.type),
				tostring(row.variant),
				tostring(row.subtype),
				tostring(row.doors)
			)
			if not seen[key] then
				seen[key] = true
				merged[#merged + 1] = row
			end
		end
	end
	if opts.void_history_mix then
		local hist = opts.void_history_stbs or M.void_history_stbs()
		local root = tonumber(opts.root_seed)
		local sgid = tonumber(opts.sgid) or 0
		if root and #hist > 0 then
			local rng = make_sgid_rng(root, sgid, "void_room_source")
			local order = {}
			for i = 1, #hist do
				order[i] = hist[i]
			end
			for i = #order, 2, -1 do
				local j = rng:RandomInt(i) + 1
				order[i], order[j] = order[j], order[i]
			end
			-- Pick first history STB that still has layouts after final eligibility filters.
			for _, stb in ipairs(order) do
				local list = collect_roomset_candidates(stb, room_type, required_doors)
				if type(opts.row_filter) == "function" then
					local filtered = {}
					for _, row in ipairs(list) do
						if opts.row_filter(row) then
							filtered[#filtered + 1] = row
						end
					end
					list = filtered
				else
					list = filter_candidates_by_subtype(list, opts)
				end
				if #list > 0 then
					add_list(list, "void_src:" .. tostring(stb))
					sources.selected_void_stb = stb
					sources.void_filtered = true
					return merged, sources
				end
			end
			sources.void_exhausted = true
		end
		-- Fall through: try stage_stb / special if mix found nothing.
	end
	if stage_stb then
		add_list(collect_roomset_candidates(stage_stb, room_type, required_doors), "stage:" .. tostring(stage_stb))
	end
	if not opts.stage_only then
		add_list(collect_roomset_candidates(StbType.SPECIAL_ROOMS, room_type, required_doors), "special_rooms")
	elseif opts.void_history_mix
		and room_type ~= RoomType.ROOM_DEFAULT
		and #merged == 0
	then
		-- Void combat stays chapter-history only (stage_only). Shop / reward / challenge /
		-- treasure / etc. still need SPECIAL_ROOMS when history RoomSets have no match —
		-- those layouts are shared vanilla pools, not per-chapter copies.
		local list = collect_roomset_candidates(StbType.SPECIAL_ROOMS, room_type, required_doors)
		if type(opts.row_filter) == "function" then
			local filtered = {}
			for _, row in ipairs(list) do
				if opts.row_filter(row) then
					filtered[#filtered + 1] = row
				end
			end
			list = filtered
		else
			list = filter_candidates_by_subtype(list, opts)
		end
		add_list(list, "special_rooms_void_miss")
		sources.void_special_fallback = true
	end
	return merged, sources
end

filter_candidates_by_subtype = function(candidates, opts)
	opts = opts or {}
	local allow = opts.allow_subtypes
	local deny = opts.deny_subtypes
	if not allow and not deny then
		return candidates
	end
	local out = {}
	for _, row in ipairs(candidates) do
		local st = tonumber(row.subtype)
		local ok = true
		if allow and (st == nil or not allow[st]) then
			ok = false
		end
		if deny and st ~= nil and deny[st] then
			ok = false
		end
		if ok then
			out[#out + 1] = row
		end
	end
	return out
end

--- SPECIAL_ROOMS challenge variants 25–32 are Mines/Ashpit-only layouts.
local function challenge_special_variant_allowed(row, stage, stage_type)
	local stb = row and (row.stb or row.source_stb)
	if stb ~= StbType.SPECIAL_ROOMS then
		return true
	end
	local v = tonumber(row and row.variant)
	if v and v >= 25 and v <= 32 then
		return M.is_mines_chapter(stage, stage_type)
	end
	return true
end

local function filter_challenge_mines_variants(candidates, stage, stage_type)
	local out = {}
	for _, row in ipairs(candidates) do
		if challenge_special_variant_allowed(row, stage, stage_type) then
			out[#out + 1] = row
		end
	end
	return out
end

-- Forward decls: pick_typed runs after load and must close over these locals (Lua scope).
local filter_candidates_by_combat_content
local filter_candidates_by_difficulty
local widen_difficulty_band

local function candidate_layout_key(row)
	return string.format(
		"%s:%s:%s:%s",
		tostring(row.stb or row.source_stb or ""),
		tostring(row.type or row.room_type or RoomType.ROOM_DEFAULT),
		tostring(row.variant),
		tostring(row.subtype)
	)
end

local function effective_candidate_weight(row, weight_scales)
	local w = tonumber(row and row.weight) or 1
	if w < 0 then
		w = 0
	end
	if weight_scales then
		local scale = tonumber(weight_scales[candidate_layout_key(row)]) or 1
		if scale < 0 then
			scale = 0
		end
		w = w * scale
	end
	return w
end

--- weight_scales: optional plan-local multipliers (do not mutate RoomConfig.Weight).
--- Effective weight <= 0 is never chosen; all-zero pool returns nil (caller degrades).
local function pick_weighted_candidate(pool, rng, weight_scales)
	if not pool or #pool == 0 then
		return nil, nil
	end
	local eligible = {}
	local total = 0
	for i, row in ipairs(pool) do
		local w = effective_candidate_weight(row, weight_scales)
		if w > 0 then
			eligible[#eligible + 1] = {row = row, weight = w, index = i}
			total = total + w
		end
	end
	if #eligible == 0 or total <= 0 then
		return nil, nil
	end
	local roll
	if rng.RandomFloat then
		roll = rng:RandomFloat() * total
	else
		roll = (rng:RandomInt(1000000) / 1000000) * total
	end
	-- Eligible weights are > 0; keep roll in (0, total].
	if roll <= 0 then
		roll = total
	end
	local acc = 0
	for _, item in ipairs(eligible) do
		acc = acc + item.weight
		if roll <= acc then
			return item.row, item.index
		end
	end
	local last = eligible[#eligible]
	return last.row, last.index
end

local COMBAT_WEIGHT_DECAY = 0.1

local function note_combat_layout_picked(weight_scales, row)
	if not weight_scales or not row then
		return
	end
	local key = candidate_layout_key(row)
	local prev = tonumber(weight_scales[key]) or 1
	weight_scales[key] = prev * COMBAT_WEIGHT_DECAY
end

local function get_fixed_variant_cfg(room_type, variant)
	local holder = room_config_holder()
	if not holder or not holder.GetRoomByStageTypeAndVariant then
		return nil
	end
	local cfg = nil
	pcall(function()
		cfg = holder.GetRoomByStageTypeAndVariant(StbType.SPECIAL_ROOMS, room_type, variant, 0)
	end)
	if not cfg then
		pcall(function()
			cfg = holder.GetRoomByStageTypeAndVariant(StbType.SPECIAL_ROOMS, room_type, variant, -1)
		end)
	end
	return cfg
end

--- Preference miss → usable 25600 so corridor activation can proceed.
local function apply_blank_content_fallback(row, asg, reason)
	row = row or {}
	local pref_err = row.error or reason or "missing_layout"
	local cfg = get_fixed_variant_cfg(RoomType.ROOM_DEFAULT, ROOM_VARIANT_EMPTY)
	row.content_preference_error = pref_err
	row.content_fallback = true
	row.cfg = cfg
	row.variant = ROOM_VARIANT_EMPTY
	row.room_type = RoomType.ROOM_DEFAULT
	row.shape = cfg and cfg.Shape or SHAPE_1X1
	row.doors = cfg and cfg.Doors
	row.subtype = cfg and cfg.Subtype or 0
	row.difficulty = cfg and cfg.Difficulty or 1
	row.name = cfg and cfg.Name or "Fixed Corridor Empty"
	row.spawn_count = cfg and cfg.SpawnCount or 0
	row.source_stb = StbType.SPECIAL_ROOMS
	row.via = "content_fallback_25600"
	row.fallback = false
	row.error = nil
	row.kind = row.kind or (asg and asg.kind) or "default"
	row.pool = row.pool or row.kind
	row.required_doors = row.required_doors or (asg and asg.required_doors) or 0
	local need = tonumber(row.required_doors) or 0
	local doors = tonumber(row.doors) or 0
	row.doors_ok = (doors & need) == need
	return row
end

--- Combat candidate list after subtype / special-content / difficulty(+widen).
local function list_default_combat_candidates(stage_stb, required_doors, opts)
	opts = opts or {}
	local candidates = select(1, merge_candidates(RoomType.ROOM_DEFAULT, stage_stb, required_doors, opts))
	candidates = filter_candidates_by_subtype(candidates, opts)
	candidates = filter_candidates_by_combat_content(candidates, opts)
	if opts.use_difficulty_filter then
		local content_pool = candidates
		candidates = filter_candidates_by_difficulty(content_pool, opts.difficulty_min, opts.difficulty_max)
		if #candidates == 0 and opts.difficulty_widen and #content_pool > 0 then
			local void_mode = opts.difficulty_void_cap == true
			local base_min = tonumber(opts.difficulty_min) or 1
			local base_max = tonumber(opts.difficulty_max) or 10
			for step = 1, 4 do
				local wmin, wmax = widen_difficulty_band(base_min, base_max, step, void_mode)
				local widened = filter_candidates_by_difficulty(content_pool, wmin, wmax)
				if #widened > 0 then
					candidates = widened
					break
				end
			end
		end
	end
	local positive = {}
	for _, row in ipairs(candidates) do
		if effective_candidate_weight(row, opts.weight_scales) > 0 then
			positive[#positive + 1] = row
		end
	end
	return positive
end

local function get_random_room(seed, stb, room_type, required_doors)
	local holder = room_config_holder()
	if not holder or not holder.GetRandomRoom then
		return nil
	end
	local cfg = nil
	pcall(function()
		cfg = holder.GetRandomRoom(
			seed,
			false,
			stb,
			room_type,
			SHAPE_1X1,
			0,
			-1,
			0,
			10,
			required_doors,
			-1,
			0
		)
	end)
	if cfg and cfg.Shape == SHAPE_1X1 and ((cfg.Doors or 0) & required_doors) == required_doors then
		return cfg
	end
	return nil
end

local function candidate_row_from_pick(chosen, idx, candidates, sources, via_label)
	return {
		cfg = chosen.cfg,
		variant = chosen.variant,
		shape = chosen.shape,
		doors = chosen.doors,
		subtype = chosen.subtype,
		difficulty = chosen.difficulty,
		name = chosen.name,
		spawn_count = chosen.spawn_count,
		weight = chosen.weight,
		source_stb = chosen.stb,
		pick_index = idx,
		candidate_count = #candidates,
		prefer_count = #candidates,
		sources = sources,
		via = via_label or "roomset_weighted",
		fallback = false,
	}
end

--- opts:
---   stage_only, allow_subtypes, deny_subtypes, no_special_fallback
---   combat_content_mode, difficulty_min/max, difficulty_widen, weight_scales, apply_weight_decay
local function pick_typed(room_type, stage_stb, required_doors, root_seed, sgid, opts)
	opts = opts or {}
	local candidates, sources = merge_candidates(room_type, stage_stb, required_doors, opts)
	candidates = filter_candidates_by_subtype(candidates, opts)
	if room_type == RoomType.ROOM_CHALLENGE then
		candidates = filter_challenge_mines_variants(
			candidates,
			opts.challenge_stage,
			opts.challenge_stage_type
		)
	end
	local before_content = #candidates
	candidates = filter_candidates_by_combat_content(candidates, opts)
	local after_content = #candidates
	local content_pool = candidates
	local diff_min = opts.difficulty_min
	local diff_max = opts.difficulty_max
	local diff_via = nil
	local before_diff = after_content
	if opts.use_difficulty_filter then
		-- Always strip Difficulty <= 0; then apply band. Never relax special-content filters.
		candidates = filter_candidates_by_difficulty(content_pool, diff_min, diff_max)
		if #candidates == 0 and opts.difficulty_widen and after_content > 0 then
			local void_mode = opts.difficulty_void_cap == true
			local base_min, base_max = tonumber(diff_min) or 1, tonumber(diff_max) or 10
			for step = 1, 4 do
				local wmin, wmax, label = widen_difficulty_band(base_min, base_max, step, void_mode)
				local widened = filter_candidates_by_difficulty(content_pool, wmin, wmax)
				if #widened > 0 then
					candidates = widened
					diff_min, diff_max = wmin, wmax
					diff_via = label
					break
				end
			end
		end
	end
	local rng, rng_seed = make_sgid_rng(root_seed, sgid)
	if #candidates > 0 then
		local chosen, idx = pick_weighted_candidate(candidates, rng, opts.weight_scales)
		if chosen then
			local row = candidate_row_from_pick(chosen, idx, candidates, sources, "roomset_weighted")
			row.room_type = room_type
			row.rng_seed = rng_seed
			row.stage_only = opts.stage_only == true
			row.combat_content_mode = opts.combat_content_mode
			row.candidates_before_content_filter = before_content
			row.candidates_after_content_filter = after_content
			row.candidates_before_difficulty_filter = before_diff
			row.candidates_after_difficulty_filter = #candidates
			row.difficulty_min = diff_min
			row.difficulty_max = diff_max
			row.difficulty_widen_via = diff_via
			row.effective_weight = effective_candidate_weight(chosen, opts.weight_scales)
			if opts.apply_weight_decay then
				note_combat_layout_picked(opts.weight_scales, chosen)
				row.weight_decay_applied = true
			end
			return row
		end
		-- Pool existed but every effective weight was <= 0.
		if opts.no_special_fallback or opts.stage_only then
			return {
				room_type = room_type,
				fallback = true,
				via = "missing_stage_pool",
				error = "no_positive_weight_candidates",
				required_doors = required_doors,
				sources = sources,
				rng_seed = rng_seed,
				stage_only = true,
				combat_content_mode = opts.combat_content_mode,
				candidates_before_content_filter = before_content,
				candidates_after_content_filter = after_content,
				candidates_before_difficulty_filter = before_diff,
				candidates_after_difficulty_filter = #candidates,
				difficulty_min = diff_min,
				difficulty_max = diff_max,
				difficulty_widen_via = diff_via,
			}
		end
	end
	if opts.no_special_fallback or opts.stage_only then
		local err = "no layout in target stage RoomSet"
		if opts.combat_content_mode and opts.combat_content_mode ~= "none" and before_content > 0 and after_content == 0 then
			err = "no layout after combat content filter (" .. tostring(opts.combat_content_mode) .. ")"
		elseif opts.use_difficulty_filter and after_content > 0 then
			err = string.format(
				"no layout after difficulty filter [%s,%s]",
				tostring(opts.difficulty_min),
				tostring(opts.difficulty_max)
			)
		end
		return {
			room_type = room_type,
			fallback = true,
			via = "missing_stage_pool",
			error = err,
			required_doors = required_doors,
			sources = sources,
			rng_seed = rng_seed,
			stage_only = true,
			combat_content_mode = opts.combat_content_mode,
			candidates_before_content_filter = before_content,
			candidates_after_content_filter = after_content,
			candidates_before_difficulty_filter = before_diff,
			candidates_after_difficulty_filter = 0,
			difficulty_min = opts.difficulty_min,
			difficulty_max = opts.difficulty_max,
			difficulty_widen_via = diff_via,
		}
	end
	local try_stbs = {}
	if stage_stb then
		try_stbs[#try_stbs + 1] = stage_stb
	end
	try_stbs[#try_stbs + 1] = StbType.SPECIAL_ROOMS
	for _, stb in ipairs(try_stbs) do
		local cfg = get_random_room(rng_seed, stb, room_type, required_doors)
		if cfg then
			local st = tonumber(cfg.Subtype)
			local ok = true
			if opts.allow_subtypes and (st == nil or not opts.allow_subtypes[st]) then
				ok = false
			end
			if opts.deny_subtypes and st ~= nil and opts.deny_subtypes[st] then
				ok = false
			end
			if ok and room_type == RoomType.ROOM_CHALLENGE then
				ok = challenge_special_variant_allowed({
					stb = stb,
					source_stb = stb,
					variant = cfg.Variant,
				}, opts.challenge_stage, opts.challenge_stage_type)
			end
			if ok then
				return {
					cfg = cfg,
					room_type = room_type,
					variant = cfg.Variant,
					shape = cfg.Shape,
					doors = cfg.Doors,
					subtype = cfg.Subtype,
					difficulty = cfg.Difficulty,
					name = cfg.Name,
					spawn_count = cfg.SpawnCount,
					source_stb = stb,
					via = "GetRandomRoom",
					rng_seed = rng_seed,
					candidate_count = 0,
					sources = sources,
					fallback = false,
				}
			end
		end
	end
	return {
		room_type = room_type,
		fallback = true,
		via = "missing",
		error = "no layout",
		required_doors = required_doors,
		sources = sources,
		rng_seed = rng_seed,
	}
end

--- Choose ROOM_DEVIL / ROOM_ANGEL from player conditions BEFORE natural-deal suppress.
function M.choose_deal_room_type(root_seed)
	local snap = nil
	pcall(function()
		snap = deal_semantics.snapshot()
	end)
	local split = snap and snap.split or {}
	local devil_share = tonumber(split.devil_share)
	local angel_share = tonumber(split.angel_share)
	local reason = "split"
	local room_type = RoomType.ROOM_DEVIL

	if deal_semantics.has_duality and deal_semantics.has_duality() then
		-- Duality: still pick one physical room for the corridor endpoint.
		reason = "duality_coin"
		local rng = make_sgid_rng(root_seed, M.DEAL_SGID, "deal_choice")
		room_type = (rng:RandomInt(2) == 0) and RoomType.ROOM_DEVIL or RoomType.ROOM_ANGEL
	elseif PlayerManager and PlayerManager.AnyoneHasCollectible
		and PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_EUCHARIST)
	then
		room_type = RoomType.ROOM_ANGEL
		reason = "eucharist"
	elseif PlayerManager and PlayerManager.AnyoneHasCollectible
		and PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_GOAT_HEAD)
	then
		room_type = RoomType.ROOM_DEVIL
		reason = "goat_head"
	elseif angel_share ~= nil and devil_share ~= nil then
		if angel_share > devil_share then
			room_type = RoomType.ROOM_ANGEL
			reason = "angel_share"
		elseif devil_share > angel_share then
			room_type = RoomType.ROOM_DEVIL
			reason = "devil_share"
		else
			local rng = make_sgid_rng(root_seed, M.DEAL_SGID + 3, "deal_choice")
			room_type = (rng:RandomInt(2) == 0) and RoomType.ROOM_DEVIL or RoomType.ROOM_ANGEL
			reason = "tie_coin"
		end
	else
		local total = nil
		pcall(function()
			total = deal_holder.refresh_total_deal()
		end)
		reason = "fallback_total"
		room_type = ((tonumber(total) or 0) > 0) and RoomType.ROOM_DEVIL or RoomType.ROOM_DEVIL
	end

	return {
		room_type = room_type,
		reason = reason,
		devil_share = devil_share,
		angel_share = angel_share,
		snapshot_total = snap and snap.internal and snap.internal.modified_total,
	}
end

local function pick_opts_for_room_type(room_type)
	if room_type == RoomType.ROOM_DEFAULT then
		return {stage_only = true, no_special_fallback = true}
	end
	if room_type == RoomType.ROOM_CHALLENGE then
		return {allow_subtypes = CHALLENGE_ENTRY_SUBTYPES}
	end
	if room_type == RoomType.ROOM_MINIBOSS then
		return {deny_subtypes = MINIBOSS_EXCLUDED_SUBTYPES}
	end
	return {}
end

local function anyone_is_tainted_keeper()
	local ok, ret = pcall(function()
		return PlayerManager and PlayerManager.AnyoneIsPlayerType
			and PlayerManager.AnyoneIsPlayerType(PlayerType.PLAYER_KEEPER_B) == true
	end)
	return ok and ret == true
end

--- STORE_UPGRADE_LV1..4 unlock shop levels 2..5 (subtype 1..4). Level 1 (0) always.
local function unlocked_shop_level_indices()
	local unlocked = {[0] = true}
	local pgd = nil
	pcall(function()
		pgd = Isaac.GetPersistentGameData()
	end)
	local function has(ach)
		if not (pgd and pgd.Unlocked and ach ~= nil) then
			return false
		end
		local ok, ret = pcall(function()
			return pgd:Unlocked(ach) == true
		end)
		return ok and ret == true
	end
	local a = Achievement
	if a then
		if has(a.STORE_UPGRADE_LV1) then unlocked[1] = true end
		if has(a.STORE_UPGRADE_LV2) then unlocked[2] = true end
		if has(a.STORE_UPGRADE_LV3) then unlocked[3] = true end
		if has(a.STORE_UPGRADE_LV4) then unlocked[4] = true end
	else
		for i = 1, 4 do
			unlocked[i] = true
		end
	end
	return unlocked
end

local function is_hard_or_harder()
	local d = nil
	pcall(function()
		d = Game().Difficulty
	end)
	if d == nil then
		return false
	end
	if Difficulty then
		if d == Difficulty.DIFFICULTY_HARD then
			return true
		end
		if Difficulty.DIFFICULTY_GREED and d >= Difficulty.DIFFICULTY_GREED then
			return true
		end
	end
	return tonumber(d) ~= nil and tonumber(d) >= 1
end

local function stage_has_labyrinth_curse()
	local on = false
	pcall(function()
		local curses = Game():GetLevel():GetCurses()
		if curses and LevelCurse and LevelCurse.CURSE_OF_LABYRINTH then
			on = (curses & LevelCurse.CURSE_OF_LABYRINTH) ~= 0
		end
	end)
	return on
end

local function is_chapter_i_stage(stage)
	return stage == LevelStage.STAGE1_1
		or stage == LevelStage.STAGE2_1
		or stage == LevelStage.STAGE3_1
		or stage == LevelStage.STAGE4_1
end

local function is_chapter_ii_stage(stage)
	return stage == LevelStage.STAGE1_2
		or stage == LevelStage.STAGE2_2
		or stage == LevelStage.STAGE3_2
		or stage == LevelStage.STAGE4_2
end

--- Vanilla-like Difficulty band for ordinary combat RoomConfig picks.
--- Difficulty 0 is never natural; caller must still exclude it explicitly.
function M.get_combat_difficulty_band(stage, stage_type, hard, opts)
	opts = opts or {}
	stage = tonumber(stage)
	hard = hard == true
	local xl = opts.xl == true or (opts.xl ~= false and stage_has_labyrinth_curse() and is_chapter_i_stage(stage))
	local band = {
		min = 1,
		max = 10,
		hard = hard,
		xl = xl == true,
		label = "default",
		allow_min_relax = false,
		relax_to = nil,
	}
	if stage == LevelStage.STAGE7 then
		band.min = hard and 5 or 1
		band.max = 20
		band.label = "void"
		return band
	end
	if stage == LevelStage.STAGE5
		or stage == LevelStage.STAGE6
		or stage == LevelStage.STAGE4_3
		or stage == LevelStage.STAGE8
		or xl
	then
		band.min = hard and 5 or 1
		band.max = hard and 15 or 10
		band.label = xl and "xl_or_late" or "late"
		return band
	end
	if is_chapter_i_stage(stage) then
		if hard then
			band.min = 5
			band.max = 10
			band.allow_min_relax = true
			band.relax_to = 1
			band.label = "chapter_i_hard"
		else
			band.min = 1
			band.max = 5
			band.label = "chapter_i_normal"
		end
		return band
	end
	if is_chapter_ii_stage(stage) then
		if hard then
			band.min = 10
			band.max = 15
			band.allow_min_relax = true
			band.relax_to = 5
			band.label = "chapter_ii_hard"
		else
			band.min = 5
			band.max = 10
			band.label = "chapter_ii_normal"
		end
		return band
	end
	band.min = hard and 5 or 1
	band.max = hard and 15 or 10
	band.label = "fallback"
	return band
end

filter_candidates_by_difficulty = function(candidates, min_d, max_d)
	min_d = tonumber(min_d)
	max_d = tonumber(max_d)
	local out = {}
	for _, row in ipairs(candidates) do
		local d = tonumber(row.difficulty)
		-- Difficulty 0 = never natural (RoomConfig_Room docs).
		if d ~= nil and d > 0 then
			local ok = true
			if min_d ~= nil and d < min_d then
				ok = false
			end
			if max_d ~= nil and d > max_d then
				ok = false
			end
			if ok then
				out[#out + 1] = row
			end
		end
	end
	return out
end

--- Widen difficulty band when range filter emptied a non-empty content pool.
--- Never reintroduces Difficulty 0; never touches special-content filters.
widen_difficulty_band = function(min_d, max_d, step, void_mode)
	min_d = tonumber(min_d) or 1
	max_d = tonumber(max_d) or 10
	local cap = void_mode and 20 or 15
	if step == 1 then
		return math.max(1, min_d - 5), max_d, "widen_min"
	elseif step == 2 then
		return min_d, math.min(cap, max_d + 5), "widen_max"
	elseif step == 3 then
		return 1, math.min(cap, max_d + 5), "widen_min1_max"
	elseif step == 4 then
		return 1, cap, "widen_full"
	end
	return min_d, max_d, nil
end

--- Vanilla shop: rare 1/256 first, then weight within that type pool.
--- Keeper B → 100–104 / 110–111; else 0–4 / 10–11. Normal = highest unlocked level only.
--- Historical STBs for Void layout content (identity remains STAGE7).
function M.void_history_stbs()
	local list = {
		StbType.BASEMENT,
		StbType.CELLAR,
		StbType.CAVES,
		StbType.CATACOMBS,
		StbType.FLOODED_CAVES,
		StbType.DEPTHS,
		StbType.NECROPOLIS,
		StbType.DANK_DEPTHS,
		StbType.WOMB,
		StbType.UTERO,
		StbType.SCARRED_WOMB,
		StbType.SHEOL,
		StbType.CATHEDRAL,
		StbType.DARK_ROOM,
		StbType.CHEST,
		StbType.DOWNPOUR,
		StbType.DROSS,
		StbType.MINES,
		StbType.ASHPIT,
		StbType.MAUSOLEUM,
		StbType.GEHENNA,
	}
	-- Prefer BURNING_BASEMENT name used by this mod's STB map; fall back to BURNT_*.
	local burn = StbType.BURNING_BASEMENT or StbType.BURNT_BASEMENT
	if burn then
		table.insert(list, 3, burn)
	end
	local out = {}
	for _, stb in ipairs(list) do
		if stb ~= nil then
			out[#out + 1] = stb
		end
	end
	return out
end

local function apply_void_mix_opts(opts, pending, root_seed, sgid)
	opts = opts or {}
	local stage = pending and tonumber(pending.restore_stage)
	if stage == LevelStage.STAGE7 then
		opts.void_history_mix = true
		opts.void_history_stbs = M.void_history_stbs()
		opts.root_seed = root_seed
		opts.sgid = sgid
		opts.stage_only = true
		opts.no_special_fallback = true
	end
	return opts
end


local function pick_shop(stage_stb, required_doors, root_seed, sgid, pending)
	local rng, rng_seed = make_sgid_rng(root_seed, sgid)
	local keeper = anyone_is_tainted_keeper()
	local rare_roll = rng:RandomInt(256)
	local is_rare = rare_roll == 0
	local unlocked = unlocked_shop_level_indices()
	local hard = is_hard_or_harder()
	local eligible = {}
	local shop_group = nil

	if is_rare then
		shop_group = keeper and "keeper_rare" or "normal_rare"
		if keeper then
			eligible = {110, 111}
		else
			eligible = {10, 11}
		end
	else
		shop_group = keeper and "keeper_level" or "normal_level"
		local levels = {}
		for lv = 0, 4 do
			if unlocked[lv] then
				levels[#levels + 1] = lv
			end
		end
		if #levels == 0 then
			levels = {0}
		end
		local chosen_levels
		if hard then
			chosen_levels = levels
		else
			local max_lv = levels[1]
			for _, lv in ipairs(levels) do
				if lv > max_lv then
					max_lv = lv
				end
			end
			chosen_levels = {max_lv}
		end
		for _, lv in ipairs(chosen_levels) do
			eligible[#eligible + 1] = keeper and (100 + lv) or lv
		end
	end

	local allow = {}
	for _, st in ipairs(eligible) do
		allow[st] = true
	end
	local shop_opts = apply_void_mix_opts({allow_subtypes = allow}, pending, root_seed, sgid)
	local candidates, sources = merge_candidates(
		RoomType.ROOM_SHOP,
		stage_stb,
		required_doors,
		shop_opts
	)
	-- Non-void / fallthrough pools still need explicit subtype filter.
	candidates = filter_candidates_by_subtype(candidates, {allow_subtypes = allow})
	local total_weight = 0
	for _, row in ipairs(candidates) do
		total_weight = total_weight + (tonumber(row.weight) or 1)
	end

	local meta = {
		shop_group = shop_group,
		rare_roll = rare_roll,
		is_rare = is_rare,
		keeper_present = keeper,
		eligible_subtypes = eligible,
		hard_mode = hard,
		unlocked_levels = unlocked,
		candidate_count = #candidates,
		total_weight = total_weight,
		rng_seed = rng_seed,
	}

	if #candidates == 0 then
		return {
			room_type = RoomType.ROOM_SHOP,
			kind = "shop",
			pool = "shop",
			fallback = true,
			via = "shop_pool_empty",
			error = "no_shop_layout_for_eligible_subtypes",
			required_doors = required_doors,
			shop_pick = meta,
		}
	end

	local chosen, idx = pick_weighted_candidate(candidates, rng)
	local row = candidate_row_from_pick(chosen, idx, candidates, sources, "shop_two_stage")
	row.room_type = RoomType.ROOM_SHOP
	row.kind = "shop"
	row.pool = "shop"
	row.rng_seed = rng_seed
	meta.selected_weight = tonumber(chosen.weight) or 1
	meta.selected_subtype = chosen.subtype
	meta.selected_variant = chosen.variant
	row.shop_pick = meta
	return row
end

local function pick_challenge_or_miniboss(stage_stb, required_doors, root_seed, sgid, pending)
	local rng, rng_seed = make_sgid_rng(root_seed, sgid)
	local use_challenge = rng:RandomInt(2) == 0
	local first = use_challenge and RoomType.ROOM_CHALLENGE or RoomType.ROOM_MINIBOSS
	local second = use_challenge and RoomType.ROOM_MINIBOSS or RoomType.ROOM_CHALLENGE
	local function with_challenge_stage(base_opts)
		local opts = apply_void_mix_opts(base_opts, pending, root_seed, sgid)
		opts.challenge_stage = pending and pending.restore_stage
		opts.challenge_stage_type = pending and pending.restore_stage_type
		return opts
	end
	local row = pick_typed(
		first,
		stage_stb,
		required_doors,
		root_seed,
		sgid,
		with_challenge_stage(pick_opts_for_room_type(first))
	)
	if row and row.cfg then
		row.pool = (first == RoomType.ROOM_CHALLENGE) and "challenge" or "miniboss"
		row.kind = "challenge_or_miniboss"
		row.rng_seed = rng_seed
		return row
	end
	row = pick_typed(
		second,
		stage_stb,
		required_doors,
		root_seed,
		sgid + 1,
		with_challenge_stage(pick_opts_for_room_type(second))
	)
	if row then
		row.pool = (second == RoomType.ROOM_CHALLENGE) and "challenge" or "miniboss"
		row.kind = "challenge_or_miniboss"
		row.rng_seed = rng_seed
	end
	return row
end

local function pick_reward(stage_stb, required_doors, root_seed, sgid, pending)
	local rng, rng_seed = make_sgid_rng(root_seed, sgid)
	local order = {}
	for i = 1, #REWARD_TYPES do
		order[i] = REWARD_TYPES[i]
	end
	for i = #order, 2, -1 do
		local j = rng:RandomInt(i) + 1
		order[i], order[j] = order[j], order[i]
	end
	for _, room_type in ipairs(order) do
		local row = pick_typed(
			room_type,
			stage_stb,
			required_doors,
			root_seed,
			sgid + room_type,
			apply_void_mix_opts(pick_opts_for_room_type(room_type), pending, root_seed, sgid + room_type)
		)
		if row and row.cfg then
			row.pool = "reward"
			row.kind = "reward_pool"
			row.rng_seed = rng_seed
			return row
		end
	end
	return {
		kind = "reward_pool",
		pool = "reward",
		fallback = true,
		via = "missing_reward",
		error = "no library/arcade/dice/planetarium",
		rng_seed = rng_seed,
	}
end

local DEVIL_SUBTYPE_NORMAL = (RoomSubType and RoomSubType.DEVIL_NORMAL) or 0
local DEVIL_SUBTYPE_NUMBER_MAGNET = (RoomSubType and RoomSubType.DEVIL_NUMBER_MAGNET) or 1
local TRINKET_NUMBER_MAGNET = (TrinketType and TrinketType.TRINKET_NUMBER_MAGNET) or 174

local function anyone_has_number_magnet()
	local ok, ret = pcall(function()
		return PlayerManager and PlayerManager.AnyoneHasTrinket
			and PlayerManager.AnyoneHasTrinket(TRINKET_NUMBER_MAGNET) == true
	end)
	return ok and ret == true
end

--- Devil@90: Number Magnet → subtype 1 only; else subtype 0 only. Angel: no magnet filter.
--- No silent cross-subtype fallback if the filtered pool is empty.
local function pick_deal(deal_choice, stage_stb, required_doors, root_seed, sgid, pending)
	local room_type = deal_choice.room_type
	local is_devil = room_type == RoomType.ROOM_DEVIL
	local is_angel = room_type == RoomType.ROOM_ANGEL
	local number_magnet = anyone_has_number_magnet()
	local required_subtype = nil
	local opts = apply_void_mix_opts(pick_opts_for_room_type(room_type), pending, root_seed, sgid)

	if is_devil then
		required_subtype = number_magnet and DEVIL_SUBTYPE_NUMBER_MAGNET or DEVIL_SUBTYPE_NORMAL
		opts.allow_subtypes = {[required_subtype] = true}
		opts.no_special_fallback = true
	end

	local row = pick_typed(room_type, stage_stb, required_doors, root_seed, sgid, opts)
	row.kind = "deal"
	row.pool = is_angel and "angel" or "devil"
	row.deal_choice = deal_choice
	row.number_magnet = number_magnet
	row.required_subtype = required_subtype
	row.selected_subtype = row.subtype
	row.selected_variant = row.variant
	row.candidates_after_filter = row.candidate_count or row.prefer_count

	if is_devil then
		local got = tonumber(row.subtype)
		if row.cfg and got ~= required_subtype then
			row.error = string.format(
				"devil_subtype_mismatch want=%s got=%s",
				tostring(required_subtype),
				tostring(got)
			)
			row.fallback = true
			row.cfg = nil
			row.via = "devil_subtype_reject"
		elseif not row.cfg then
			row.error = row.error
				or ("devil_subtype_pool_empty_" .. tostring(required_subtype))
			row.fallback = true
			row.via = row.via or "devil_subtype_missing"
		end
	end

	row.deal_magnet = {
		number_magnet = number_magnet,
		room_type = room_type,
		required_subtype = required_subtype,
		selected_subtype = row.subtype,
		selected_variant = row.variant,
		source_stb = row.source_stb,
		candidates_after_filter = row.candidates_after_filter,
		ok = row.cfg ~= nil and (not is_devil or tonumber(row.subtype) == required_subtype),
	}
	return row
end

--- Alt-path treasure Variant ranges (vanilla room lists; verify vs live RoomConfig if needed).
local TREASURE_ALT_VARIANT_BANDS = {
	-- Downpour
	[StbType.DOWNPOUR] = {
		dual = {{0, 5}, {9, 11}},
		dual_restock = {{8, 8}, {18, 23}},
		triple_one = {{12, 17}},
		extra_plus_restock = {{24, 28}},
		extra_no_restock = {{7, 7}},
		no_reward = {{6, 6}},
	},
	[StbType.DROSS] = {
		dual = {{0, 5}, {8, 9}, {11, 13}},
		dual_restock = {{10, 10}, {20, 25}},
		triple_one = {{14, 19}},
		extra_plus_restock = {{26, 30}},
		extra_no_restock = {{7, 7}},
		no_reward = {{6, 6}},
	},
	[StbType.MINES] = {
		dual = {{0, 12}},
		dual_restock = {{13, 13}, {22, 27}},
		triple_one = {{16, 21}},
		extra_plus_restock = {{28, 32}},
		extra_no_restock = {{14, 14}},
		no_reward = {{15, 15}},
	},
	[StbType.ASHPIT] = {
		dual = {{0, 12}, {16, 16}},
		dual_restock = {{13, 13}, {23, 28}},
		triple_one = {{17, 22}},
		extra_plus_restock = {{29, 33}},
		extra_no_restock = {{14, 14}},
		no_reward = {{15, 15}},
	},
	[StbType.MAUSOLEUM] = {
		dual = {{0, 7}, {11, 13}},
		dual_restock = {{8, 8}, {20, 25}},
		triple_one = {{14, 19}},
		extra_plus_restock = {{26, 30}},
		extra_no_restock = {{10, 10}},
		no_reward = {{9, 9}},
	},
	[StbType.GEHENNA] = {
		dual = {{0, 6}, {10, 12}},
		dual_restock = {{7, 7}, {19, 24}},
		triple_one = {{13, 18}},
		extra_plus_restock = {{25, 29}},
		extra_no_restock = {{9, 9}},
		no_reward = {{8, 8}},
	},
}

local TRINKET_PAY_TO_WIN = (TrinketType and TrinketType.TRINKET_PAY_TO_WIN) or 112
local SLOT_RESTOCK = (SlotVariant and (SlotVariant.SHOP_RESTOCK_MACHINE or SlotVariant.RESTOCK_MACHINE)) or 10

local function anyone_has_pay_to_win()
	local ok, ret = pcall(function()
		return PlayerManager and PlayerManager.AnyoneHasTrinket
			and PlayerManager.AnyoneHasTrinket(TRINKET_PAY_TO_WIN) == true
	end)
	return ok and ret == true
end

local function variant_in_bands(variant, bands)
	variant = tonumber(variant)
	if variant == nil or type(bands) ~= "table" then
		return false
	end
	for _, band in ipairs(bands) do
		local a, b = tonumber(band[1]), tonumber(band[2])
		if a and b and variant >= a and variant <= b then
			return true
		end
	end
	return false
end

local function classify_alt_treasure_variant(stage_stb, variant)
	local bands = TREASURE_ALT_VARIANT_BANDS[stage_stb]
	if not bands then
		return nil
	end
	if variant_in_bands(variant, bands.no_reward) then
		return "no_reward", false
	end
	if variant_in_bands(variant, bands.extra_plus_restock) then
		return "choice_pair_plus_one", true
	end
	if variant_in_bands(variant, bands.extra_no_restock) then
		return "choice_pair_plus_one", false
	end
	if variant_in_bands(variant, bands.triple_one) then
		return "triple_take_one", false
	end
	if variant_in_bands(variant, bands.dual_restock) then
		return "dual_choice", true
	end
	if variant_in_bands(variant, bands.dual) then
		return "dual_choice", false
	end
	return "unknown", nil
end

local function room_cfg_has_restock(cfg)
	if not cfg or not cfg.Spawns then
		return false
	end
	local n = tonumber(cfg.SpawnCount) or 0
	local found = false
	pcall(function()
		for i = 0, n - 1 do
			local spawn = cfg.Spawns:Get(i)
			if spawn then
				local ec = tonumber(spawn.EntryCount) or 0
				local entries = spawn.Entries
				if entries and entries.Get then
					local size = tonumber(entries.Size) or ec
					for j = 0, size - 1 do
						local e = entries:Get(j)
						if e and e.Type == EntityType.ENTITY_SLOT and tonumber(e.Variant) == SLOT_RESTOCK then
							found = true
							return
						end
					end
				elseif spawn.PickEntry and ec > 0 then
					for j = 0, ec - 1 do
						local e = spawn:PickEntry((j + 0.5) / ec)
						if e and e.Type == EntityType.ENTITY_SLOT and tonumber(e.Variant) == SLOT_RESTOCK then
							found = true
							return
						end
					end
				end
			end
		end
	end)
	return found
end

--- Walk every Spawn Entry (not only PickEntry(0)) for stage-layout content flags.
local function room_cfg_foreach_spawn_entry(cfg, fn)
	if not cfg or not cfg.Spawns or type(fn) ~= "function" then
		return
	end
	local n = tonumber(cfg.SpawnCount) or 0
	pcall(function()
		for i = 0, n - 1 do
			local spawn = cfg.Spawns:Get(i)
			if spawn then
				local ec = tonumber(spawn.EntryCount) or 0
				local entries = spawn.Entries
				local matched = false
				if entries and entries.Get then
					local size = tonumber(entries.Size) or ec
					for j = 0, size - 1 do
						local e = entries:Get(j)
						if e and fn(e, spawn, i, j) == true then
							matched = true
							break
						end
					end
				elseif spawn.PickEntry and ec > 0 then
					for j = 0, ec - 1 do
						local e = spawn:PickEntry((j + 0.5) / ec)
						if e and fn(e, spawn, i, j) == true then
							matched = true
							break
						end
					end
				end
				if matched then
					return
				end
			end
		end
	end)
end

local function room_cfg_has_spawn_tv(cfg, want_type, want_variant)
	want_type = tonumber(want_type)
	want_variant = tonumber(want_variant)
	if want_type == nil then
		return false
	end
	local found = false
	room_cfg_foreach_spawn_entry(cfg, function(e)
		if tonumber(e.Type) == want_type
			and (want_variant == nil or tonumber(e.Variant) == want_variant)
		then
			found = true
			return true
		end
	end)
	return found
end

local function candidate_has_white_fire(row)
	local v = tonumber(row and row.variant)
	if v and v >= VARIANT_BAND_WHITE_FIRE_OR_BUTTON_LO and v <= VARIANT_BAND_WHITE_FIRE_OR_BUTTON_HI then
		return true
	end
	return room_cfg_has_spawn_tv(row and row.cfg, SPAWN_WHITE_FIRE_TYPE, SPAWN_WHITE_FIRE_VARIANT)
end

local function candidate_has_mines_button(row)
	local v = tonumber(row and row.variant)
	-- Mines/Ashpit 5000–5500 band is Button Room (stage STB only).
	if v and v >= VARIANT_BAND_WHITE_FIRE_OR_BUTTON_LO and v <= VARIANT_BAND_WHITE_FIRE_OR_BUTTON_HI then
		return true
	end
	return room_cfg_has_spawn_tv(row and row.cfg, SPAWN_MINES_BUTTON_TYPE, SPAWN_MINES_BUTTON_VARIANT)
end

local function candidate_has_x_skull(row)
	local v = tonumber(row and row.variant)
	if v and v >= VARIANT_BAND_FOOL_ROOM_LO and v <= VARIANT_BAND_FOOL_ROOM_HI then
		return true
	end
	return room_cfg_has_spawn_tv(row and row.cfg, SPAWN_X_SKULL_TYPE, nil)
end

--- Combat-room content rule for the restored target floor (stage RoomSet only).
function M.get_default_combat_content_rule(stage, stage_type)
	stage = tonumber(stage)
	if M.is_water_chapter(stage, stage_type) then
		return {mode = "exclude_white_fire", stage = stage, stage_type = stage_type}
	end
	if M.is_mines_chapter(stage, stage_type) then
		return {mode = "exclude_mines_button", stage = stage, stage_type = stage_type}
	end
	if stage == LevelStage.STAGE3_1 then
		return {mode = "exclude_x_skull", stage = stage, stage_type = stage_type}
	end
	if stage == LevelStage.STAGE3_2 then
		return {mode = "quota_x_skull", stage = stage, stage_type = stage_type, quota = 1}
	end
	return {mode = "none", stage = stage, stage_type = stage_type}
end

filter_candidates_by_combat_content = function(candidates, opts)
	opts = opts or {}
	local mode = opts.combat_content_mode
	if not mode or mode == "none" then
		return candidates
	end
	local out = {}
	for _, row in ipairs(candidates) do
		local keep = true
		if mode == "exclude_white_fire" then
			keep = not candidate_has_white_fire(row)
		elseif mode == "exclude_mines_button" then
			keep = not candidate_has_mines_button(row)
		elseif mode == "exclude_x_skull" then
			keep = not candidate_has_x_skull(row)
		elseif mode == "require_x_skull" then
			keep = candidate_has_x_skull(row)
		end
		if keep then
			out[#out + 1] = row
		end
	end
	return out
end

local function is_alt_stage_stb(stage_stb)
	return stage_stb == StbType.DOWNPOUR
		or stage_stb == StbType.DROSS
		or stage_stb == StbType.MINES
		or stage_stb == StbType.ASHPIT
		or stage_stb == StbType.MAUSOLEUM
		or stage_stb == StbType.GEHENNA
end

--- Treasure@79/83:
--- - Mainline: SPECIAL_ROOMS (vanilla treasure layouts live there).
--- - Alt path: chapter RoomSet + Variant bands.
--- - Void: historical RoomSet mix; miss → SPECIAL_ROOMS (merge_candidates void miss path).
--- Pay to Win selects restock class at gen time.
local function pick_treasure(stage_stb, required_doors, root_seed, sgid, pending)
	local pay = anyone_has_pay_to_win()
	local void_mix = pending and tonumber(pending.restore_stage) == LevelStage.STAGE7
	local alt = is_alt_stage_stb(stage_stb)
	local want_restock = pay
	local pool_mode = "main_special_rooms"
	local function classify_treasure_cand(cand)
		local src_stb = cand.stb or stage_stb
		local cand_alt = void_mix and is_alt_stage_stb(src_stb) or alt
		local rule, has_restock
		if cand_alt then
			rule, has_restock = classify_alt_treasure_variant(src_stb, cand.variant)
			if has_restock == nil then
				has_restock = room_cfg_has_restock(cand.cfg)
			end
		else
			has_restock = room_cfg_has_restock(cand.cfg)
			rule = has_restock and "main_restock" or "main_single"
		end
		return rule, has_restock == true, cand_alt
	end
	local candidates, sources
	if void_mix then
		pool_mode = "void_history_mix"
		local mix_opts = apply_void_mix_opts(
			{stage_only = true, no_special_fallback = true},
			pending,
			root_seed,
			sgid
		)
		mix_opts.row_filter = function(cand)
			local rule, has_restock = classify_treasure_cand(cand)
			if rule == "no_reward" or rule == "unknown" then
				return false
			end
			if want_restock then
				return has_restock == true
			end
			return has_restock ~= true
		end
		candidates, sources = merge_candidates(
			RoomType.ROOM_TREASURE,
			stage_stb,
			required_doors,
			mix_opts
		)
		if #candidates == 0 then
			local widen = apply_void_mix_opts(
				{stage_only = true, no_special_fallback = true},
				pending,
				root_seed,
				sgid
			)
			widen.row_filter = function(cand)
				local rule = classify_treasure_cand(cand)
				return rule ~= "no_reward" and rule ~= "unknown"
			end
			candidates, sources = merge_candidates(
				RoomType.ROOM_TREASURE,
				stage_stb,
				required_doors,
				widen
			)
			if sources then
				sources.treasure_widen = true
			end
		end
	elseif alt then
		pool_mode = "alt_stage_roomset"
		candidates, sources = merge_candidates(
			RoomType.ROOM_TREASURE,
			stage_stb,
			required_doors,
			{stage_only = true, no_special_fallback = true}
		)
	else
		-- Mainline treasure layouts are in SPECIAL_ROOMS, not chapter RoomSets.
		pool_mode = "main_special_rooms"
		candidates, sources = merge_candidates(
			RoomType.ROOM_TREASURE,
			StbType.SPECIAL_ROOMS,
			required_doors,
			{stage_only = true, no_special_fallback = true}
		)
	end
	local want_rule = nil
	local filtered = {}
	local class_counts = {}
	for _, cand in ipairs(candidates) do
		local rule, has_restock, cand_alt = classify_treasure_cand(cand)
		cand._treasure_alt = cand_alt
		cand._treasure_rule = rule
		cand._has_restock = has_restock == true
		class_counts[tostring(rule)] = (class_counts[tostring(rule)] or 0) + 1
		if rule == "no_reward" or rule == "unknown" then
			-- skip bad / unclassified alt layouts
		elseif cand_alt then
			-- Prefer dual_choice (+ restock class when Pay to Win); do not mix triple/extra into dual pool.
			if want_restock then
				if rule == "dual_choice" and cand._has_restock then
					filtered[#filtered + 1] = cand
					want_rule = "dual_choice"
				end
			else
				if rule == "dual_choice" and not cand._has_restock then
					filtered[#filtered + 1] = cand
					want_rule = "dual_choice"
				end
			end
		else
			if want_restock == cand._has_restock then
				filtered[#filtered + 1] = cand
				want_rule = cand._treasure_rule
			end
		end
	end

	-- Fallbacks: if preferred class empty, widen carefully.
	if #filtered == 0 and want_restock then
		for _, cand in ipairs(candidates) do
			if cand._treasure_alt
				and cand._treasure_rule == "choice_pair_plus_one"
				and cand._has_restock
			then
				filtered[#filtered + 1] = cand
				want_rule = "choice_pair_plus_one"
			end
		end
	end
	if #filtered == 0 then
		for _, cand in ipairs(candidates) do
			if cand._treasure_rule ~= "no_reward" and cand._treasure_rule ~= "unknown" then
				if (not want_restock) or cand._has_restock then
					filtered[#filtered + 1] = cand
				end
			end
		end
		if #filtered > 0 then
			want_rule = "fallback_pool"
		end
	end

	local rng, rng_seed = make_sgid_rng(root_seed, sgid, "treasure")
	local meta = {
		stage_stb = stage_stb,
		alt_path = alt,
		void_mix = void_mix == true,
		pool_mode = pool_mode,
		pay_to_win = pay,
		want_restock = want_restock,
		want_rule = want_rule,
		candidate_total = #candidates,
		candidate_filtered = #filtered,
		class_counts = class_counts,
		sources = sources,
		rng_seed = rng_seed,
	}

	if #filtered == 0 then
		return {
			room_type = RoomType.ROOM_TREASURE,
			kind = "treasure",
			pool = "treasure",
			fallback = true,
			via = "treasure_pool_empty",
			error = "no_treasure_layout_for_class",
			required_doors = required_doors,
			treasure_pick = meta,
		}
	end

	local chosen, idx = pick_weighted_candidate(filtered, rng)
	local row = candidate_row_from_pick(chosen, idx, filtered, sources, "treasure_classified")
	row.room_type = RoomType.ROOM_TREASURE
	row.kind = "treasure"
	row.pool = "treasure"
	row.rng_seed = rng_seed
	meta.selected_variant = chosen.variant
	meta.selected_subtype = chosen.subtype
	meta.selected_weight = tonumber(chosen.weight) or 1
	meta.reward_rule = chosen._treasure_rule
	meta.has_restock_machine = chosen._has_restock == true
	meta.source_stb = chosen.stb
	row.treasure_pick = meta
	row.reward_rule = meta.reward_rule
	row.has_restock_machine = meta.has_restock_machine
	return row
end


--- Void layout fallback: replace missing target RoomConfig with a random eligible Boss layout.
--- LEGACY: formerly substituted Mom/etc Boss layouts for any Void miss; retired from M.build()
--- because ROOM_BOSS neighbors break RGON CanPlaceRoom for the corridor. Kept for diagnostics only.
--- Does not change SGID / corridor slot. Never used to override assignment 89's own boss pick path.
local function pick_void_boss_fallback(required_doors, root_seed, sgid, original)
	original = original or {}
	local hist = M.void_history_stbs()
	local rng, rng_seed = make_sgid_rng(root_seed, sgid, "void_boss_fallback")
	local candidates = {}
	local sources = {void_boss_fallback = true}
	for _, stb in ipairs(hist) do
		local list = collect_roomset_candidates(stb, RoomType.ROOM_BOSS, required_doors)
		for _, row in ipairs(list) do
			candidates[#candidates + 1] = row
		end
		sources[#sources + 1] = {label = "boss_hist:" .. tostring(stb), count = #list}
	end
	if #candidates == 0 and StbType.SPECIAL_ROOMS then
		local list = collect_roomset_candidates(StbType.SPECIAL_ROOMS, RoomType.ROOM_BOSS, required_doors)
		for _, row in ipairs(list) do
			candidates[#candidates + 1] = row
		end
		sources[#sources + 1] = {label = "boss_special", count = #list}
	end
	if #candidates == 0 then
		return {
			sgid = original.sgid,
			room_type = RoomType.ROOM_BOSS,
			kind = original.kind,
			pool = original.pool,
			fallback = true,
			via = "void_boss_fallback_empty",
			error = "no_eligible_boss_layout_for_void_fallback",
			original_room_type = original.room_type,
			original_kind = original.kind,
			required_doors = required_doors,
			sources = sources,
			rng_seed = rng_seed,
		}
	end
	local chosen, idx = pick_weighted_candidate(candidates, rng)
	local row = candidate_row_from_pick(chosen, idx, candidates, sources, "void_boss_fallback")
	row.sgid = original.sgid
	row.room_type = RoomType.ROOM_BOSS
	row.kind = original.kind or "boss_fallback"
	row.pool = original.pool or "boss_fallback"
	row.fallback = true
	row.via = "void_boss_fallback"
	row.original_room_type = original.room_type
	row.original_kind = original.kind
	row.original_error = original.error
	row.required_doors = required_doors
	row.rng_seed = rng_seed
	return row
end

--- Build corridor_plan[sgid] for 78–90. stage_stb = restored target floor STB.
function M.build(pending, stage_stb, root_seed)
	root_seed = tonumber(root_seed)
	if not root_seed or root_seed <= 0 then
		error("golden_compass.corridor_plan.build: missing root_seed")
	end
	local deal_choice = M.choose_deal_room_type(root_seed)
	local plan = {}
	local summary = {}
	local floor_rule = M.get_floor_generation_rule(
		pending and pending.restore_stage,
		pending and pending.restore_stage_type
	)
	local combat_rule = M.get_default_combat_content_rule(
		pending and pending.restore_stage,
		pending and pending.restore_stage_type
	)
	local hard = is_hard_or_harder()
	local diff_band = M.get_combat_difficulty_band(
		pending and pending.restore_stage,
		pending and pending.restore_stage_type,
		hard
	)
	-- Approximate hard-mode "small chance" min relax (not exact vanilla odds).
	if diff_band.allow_min_relax and diff_band.relax_to ~= nil then
		local relax_rng = make_sgid_rng(root_seed, 0, "diff_min_relax")
		if relax_rng:RandomInt(10) == 0 then
			diff_band = {
				min = diff_band.relax_to,
				max = diff_band.max,
				hard = diff_band.hard,
				xl = diff_band.xl,
				label = tostring(diff_band.label) .. "_min_relaxed",
				allow_min_relax = false,
				relax_to = diff_band.relax_to,
				min_relaxed = true,
			}
		end
	end
	-- Plan-local Weight scales for combat 82/85/88 (do not mutate RoomConfig.Weight).
	local combat_weight_scales = {}
	local x_skull_quota_sgid = nil
	local x_skull_quota_abandoned = false
	local x_skull_eligible = {}
	if combat_rule and combat_rule.mode == "quota_x_skull" then
		local void_cap = tonumber(pending and pending.restore_stage) == LevelStage.STAGE7
		for _, asg in ipairs(M.ASSIGNMENTS) do
			if asg.kind == "default" and asg.room_type == RoomType.ROOM_DEFAULT then
				local probe_opts = apply_void_mix_opts(
					pick_opts_for_room_type(RoomType.ROOM_DEFAULT),
					pending,
					root_seed,
					asg.sgid
				)
				probe_opts.combat_content_mode = "require_x_skull"
				probe_opts.use_difficulty_filter = true
				probe_opts.difficulty_min = diff_band.min
				probe_opts.difficulty_max = diff_band.max
				probe_opts.difficulty_widen = true
				probe_opts.difficulty_void_cap = void_cap
				local pool = list_default_combat_candidates(stage_stb, asg.required_doors, probe_opts)
				if #pool > 0 then
					x_skull_eligible[#x_skull_eligible + 1] = {
						sgid = asg.sgid,
						candidate_count = #pool,
						required_doors = asg.required_doors,
					}
				end
			end
		end
		if #x_skull_eligible > 0 then
			local q_rng = make_sgid_rng(root_seed, 0, "x_skull_quota")
			x_skull_quota_sgid = x_skull_eligible[q_rng:RandomInt(#x_skull_eligible) + 1].sgid
		else
			x_skull_quota_abandoned = true
		end
	end
	summary.floor_rule = {
		room_source = floor_rule and floor_rule.room_source,
		normal_exit = floor_rule and floor_rule.normal_exit_rule,
		secret_exit = floor_rule and floor_rule.secret_exit_rule and floor_rule.secret_exit_rule.reason,
	}
	summary.combat_content_rule = {
		mode = combat_rule and combat_rule.mode,
		x_skull_quota_sgid = x_skull_quota_sgid,
		x_skull_quota_abandoned = x_skull_quota_abandoned,
		x_skull_eligible = x_skull_eligible,
	}
	summary.combat_difficulty_band = {
		min = diff_band.min,
		max = diff_band.max,
		hard = hard,
		label = diff_band.label,
		min_relaxed = diff_band.min_relaxed == true,
		xl = diff_band.xl == true,
	}

	for _, asg in ipairs(M.ASSIGNMENTS) do
		local row
		if asg.kind == "empty_entry" or asg.kind == "fixed_fire_options" then
			local fixed_variant = asg.fixed_variant
			if asg.kind == "empty_entry" then
				fixed_variant = M.entry_78_variant_for_floor(
					pending and pending.restore_stage,
					pending and pending.restore_stage_type
				)
			elseif asg.kind == "fixed_fire_options" then
				fixed_variant = M.fixed_84_variant_for_floor(
					pending and pending.restore_stage,
					pending and pending.restore_stage_type
				)
			end
			local cfg = get_fixed_variant_cfg(RoomType.ROOM_DEFAULT, fixed_variant)
			row = {
				sgid = asg.sgid,
				kind = asg.kind,
				pool = asg.kind,
				room_type = RoomType.ROOM_DEFAULT,
				cfg = cfg,
				variant = fixed_variant,
				shape = cfg and cfg.Shape or SHAPE_1X1,
				doors = cfg and cfg.Doors,
				source_stb = StbType.SPECIAL_ROOMS,
				via = "fixed_stb_" .. tostring(fixed_variant),
				fallback = cfg == nil,
				required_doors = asg.required_doors,
				water_ii_mirror_entry = fixed_variant == ROOM_VARIANT_WATER_II_MIRROR_ENTRY,
				mines_ii_mineshaft_entry = fixed_variant == ROOM_VARIANT_MINES_II_MINESHAFT_ENTRY,
				water_ii_white_fire_84 = fixed_variant == ROOM_VARIANT_WATER_II_84_WHITE_FIRE,
			}
		elseif asg.kind == "challenge_or_miniboss" then
			row = pick_challenge_or_miniboss(stage_stb, asg.required_doors, root_seed, asg.sgid, pending)
			row.sgid = asg.sgid
			row.required_doors = asg.required_doors
		elseif asg.kind == "reward_pool" then
			row = pick_reward(stage_stb, asg.required_doors, root_seed, asg.sgid, pending)
			row.sgid = asg.sgid
			row.required_doors = asg.required_doors
		elseif asg.kind == "shop" then
			row = pick_shop(stage_stb, asg.required_doors, root_seed, asg.sgid, pending)
			row.sgid = asg.sgid
			row.required_doors = asg.required_doors
		elseif asg.kind == "deal" then
			-- Void Delirium 2x2 at 89 claims grid 90; no separate deal room.
			local boss_prev = plan[M.BOSS_SGID]
			if boss_prev and (boss_prev.suppress_deal_90 or boss_prev.boss_role == "delirium" or boss_prev.shape_2x2) then
				row = {
					sgid = asg.sgid,
					kind = "deal_footprint",
					pool = "delirium_2x2_footprint",
					room_type = RoomType.ROOM_BOSS,
					cfg = nil,
					claimed_by = M.BOSS_SGID,
					footprint_of = M.BOSS_SGID,
					suppress_deal = true,
					skipped = true,
					via = "delirium_void_2x2_footprint",
					required_doors = 0,
					doors = 0,
					doors_ok = true,
					shape = boss_prev.shape,
					fallback = false,
				}
			else
				row = pick_deal(deal_choice, stage_stb, asg.required_doors, root_seed, asg.sgid, pending)
				row.sgid = asg.sgid
				row.required_doors = asg.required_doors
			end
		elseif asg.kind == "boss" then
			-- Catalog pool pick (confident 1x1 LR); optional force_boss_subtype for probe Mom test.
			local boss_opts = apply_void_mix_opts(pick_opts_for_room_type(RoomType.ROOM_BOSS), pending, root_seed, asg.sgid)
			local force_st = pending and tonumber(pending.force_boss_subtype) or nil
			if force_st ~= nil then
				boss_opts.allow_subtypes = {[force_st] = true}
				boss_opts.force_boss_subtype = force_st
			end
			row = nil
			-- Manual Mom fight test: SPECIAL_ROOMS / 6030 (clears BACKWARDS_PATH_INIT separately).
			if force_st == M.BOSS_SUBTYPE_MOM_MAUSOLEUM then
				local cfg = get_fixed_variant_cfg(RoomType.ROOM_BOSS, M.BOSS_VARIANT_MOM_MAUSOLEUM)
				if cfg and tonumber(cfg.Subtype) == M.BOSS_SUBTYPE_MOM_MAUSOLEUM then
					local doors = tonumber(cfg.Doors) or 0
					local need = asg.required_doors or 0
					if (doors & need) == need then
						row = {
							cfg = cfg,
							room_type = RoomType.ROOM_BOSS,
							variant = cfg.Variant or M.BOSS_VARIANT_MOM_MAUSOLEUM,
							shape = cfg.Shape or SHAPE_1X1,
							doors = doors,
							subtype = cfg.Subtype,
							difficulty = cfg.Difficulty,
							name = cfg.Name,
							spawn_count = cfg.SpawnCount,
							source_stb = StbType.SPECIAL_ROOMS,
							via = "forced_mom_mausoleum_special_6030",
							fallback = false,
						}
					end
				end
			end
			-- Target-floor Boss pool (Dad's Note prep Variant 1 / Mother gate / weighted / fixed).
			local boss_pool_err = nil
			if not row and force_st == nil then
				local pick_opts = {
					force_stageapi_boss_id = pending and pending.force_stageapi_boss_id,
					force_stageapi_any = pending and pending.force_stageapi_any == true,
				}
				local picked, pick_err = boss_pick.pick_boss_room(
					pending and pending.restore_stage,
					pending and pending.restore_stage_type,
					asg.required_doors,
					root_seed,
					asg.sgid,
					pick_opts
				)
				if picked and picked.cfg then
					row = picked
					if picked.pick_pool_summary then
						summary.boss_pick_pool = picked.pick_pool_summary
					end
				else
					boss_pool_err = tostring(pick_err or "nil")
					summary.boss_pool_pick_error = boss_pool_err
					if boss_pick.get_last_pick_summary then
						summary.boss_pick_pool = boss_pick.get_last_pick_summary()
					end
				end
			end
			-- Dad's Note prep / Void Delirium are hard endpoints: never fall back to pool layouts.
			local dads_note_hard_fail = type(boss_pool_err) == "string"
				and boss_pool_err:find("dads_note_prep_failed", 1, true) ~= nil
			local delirium_hard_fail = false
			if not row and not dads_note_hard_fail then
				local def = boss_pool_catalog.find_floor_def(
					pending and pending.restore_stage,
					pending and pending.restore_stage_type
				)
				delirium_hard_fail = def and def.role_89 == "delirium"
			end
			if dads_note_hard_fail then
				row = {
					sgid = asg.sgid,
					kind = "boss",
					room_type = RoomType.ROOM_BOSS,
					pool = "dads_note_prep",
					boss_role = "dads_note_prep",
					boss_encounter_pending = false,
					cfg = nil,
					error = boss_pool_err,
					fallback = true,
					via = "dads_note_prep_failed_no_fallback",
					required_doors = asg.required_doors,
				}
			elseif delirium_hard_fail then
				row = {
					sgid = asg.sgid,
					kind = "boss",
					room_type = RoomType.ROOM_BOSS,
					pool = "delirium_void",
					boss_role = "delirium",
					boss_id = "Delirium",
					suppress_deal_90 = true,
					shape_2x2 = true,
					cfg = nil,
					error = boss_pool_err or "delirium_3414_pick_failed",
					fallback = true,
					via = "delirium_void_failed_no_fallback",
					required_doors = DOOR_LEFT,
				}
			elseif not row then
				-- Legacy RoomConfig merge fallback (never fail the corridor solely for pool miss).
				row = pick_typed(
					RoomType.ROOM_BOSS,
					stage_stb,
					asg.required_doors,
					root_seed,
					asg.sgid,
					boss_opts
				)
				if row then
					row.via = (row.via or "pick_typed") .. "+boss_pool_fallback"
				end
			end
			row.sgid = asg.sgid
			row.kind = "boss"
			row.pool = row.pool or "boss"
			-- Delirium 2x2: only LEFT→88 is a corridor neighbor (RIGHT is footprint@90).
			if row.suppress_deal_90 or row.boss_role == "delirium" or row.shape_2x2 then
				row.required_doors = DOOR_LEFT
				row.suppress_deal_90 = true
				row.shape_2x2 = true
			else
				row.required_doors = asg.required_doors
			end
			row.force_boss_subtype = force_st
			if force_st == M.BOSS_SUBTYPE_MOM_MAUSOLEUM then
				local name_l = tostring(row.name or ""):lower()
				local ok_layout = row.cfg ~= nil
					and tonumber(row.subtype) == M.BOSS_SUBTYPE_MOM_MAUSOLEUM
					and (
						tonumber(row.variant) == M.BOSS_VARIANT_MOM_MAUSOLEUM
						or name_l:find("mausoleum", 1, true) ~= nil
					)
				if not ok_layout then
					row.cfg = nil
					row.error = "forced_mom_mausoleum_layout_rejected"
					row.fallback = true
					row.via = "forced_mom_mausoleum_reject_stage_stub"
				end
			elseif force_st ~= nil and not row.cfg then
				row.error = "forced_boss_subtype_missing_" .. tostring(force_st)
				row.fallback = true
				row.via = "forced_boss_missing"
			end
		elseif asg.kind == "treasure" then
			row = pick_treasure(stage_stb, asg.required_doors, root_seed, asg.sgid, pending)
			row.sgid = asg.sgid
			row.required_doors = asg.required_doors
		else
			local pick_opts = apply_void_mix_opts(
				pick_opts_for_room_type(asg.room_type),
				pending,
				root_seed,
				asg.sgid
			)
			-- Ordinary combat rooms 82/85/88: special-content + Difficulty band + local Weight decay.
			if asg.kind == "default" and asg.room_type == RoomType.ROOM_DEFAULT then
				local mode = combat_rule and combat_rule.mode or "none"
				if mode == "quota_x_skull" then
					if x_skull_quota_abandoned or x_skull_quota_sgid == nil then
						pick_opts.combat_content_mode = "exclude_x_skull"
						pick_opts.x_skull_quota_abandoned = true
					elseif asg.sgid == x_skull_quota_sgid then
						pick_opts.combat_content_mode = "require_x_skull"
					else
						pick_opts.combat_content_mode = "exclude_x_skull"
					end
					pick_opts.x_skull_quota_sgid = x_skull_quota_sgid
				elseif mode ~= "none" then
					pick_opts.combat_content_mode = mode
				end
				pick_opts.use_difficulty_filter = true
				pick_opts.difficulty_min = diff_band.min
				pick_opts.difficulty_max = diff_band.max
				pick_opts.difficulty_widen = true
				pick_opts.difficulty_void_cap = tonumber(pending and pending.restore_stage) == LevelStage.STAGE7
				pick_opts.weight_scales = combat_weight_scales
				pick_opts.apply_weight_decay = true
			end
			row = pick_typed(
				asg.room_type,
				stage_stb,
				asg.required_doors,
				root_seed,
				asg.sgid,
				pick_opts
			)
			row.sgid = asg.sgid
			row.kind = asg.kind
			row.pool = asg.kind
			row.required_doors = asg.required_doors
			row.x_skull_quota_sgid = pick_opts.x_skull_quota_sgid
			row.has_x_skull = row.cfg and candidate_has_x_skull(row) or false
		end
		-- Hard check: selected RoomConfig must cover topology-required door slots.
		-- Footprint deal@90 (Delirium 2x2) has no own cfg / door mask.
		local need = row.required_doors or asg.required_doors or 0
		if row.footprint_of then
			need = 0
			row.required_doors = 0
			row.doors_ok = true
		else
			row.required_doors = need
			local doors = tonumber(row.doors or (row.cfg and row.cfg.Doors) or 0) or 0
			row.doors = doors
			row.doors_ok = (doors & need) == need
			if row.cfg and not row.doors_ok then
				row.error = string.format(
					"doors_mask_mismatch have=%s need=%s",
					tostring(doors),
					tostring(need)
				)
				row.fallback = true
				row.cfg = nil
				row.via = (row.via or "pick") .. "_doors_reject"
			elseif row.cfg then
				row.doors_ok = true
			end
		end
		-- Void non-boss miss: never substitute ROOM_BOSS (Mom etc.) — that breaks CanPlaceRoom
		-- adjacency. Prefer SPECIAL_ROOMS via merge_candidates; else blank 25600 below.
		-- Content degrade: preference miss → 25600 (appointment already consumed; keep corridor activatable).
		if not row.cfg and not row.footprint_of then
			apply_blank_content_fallback(row, asg, row.error or "missing_layout")
		end
		plan[asg.sgid] = row
		summary[#summary + 1] = {
			sgid = asg.sgid,
			kind = row.kind or asg.kind,
			pool = row.pool,
			room_type = row.room_type,
			original_room_type = row.original_room_type,
			original_kind = row.original_kind,
			variant = row.variant,
			shape = row.shape,
			doors = row.doors,
			required_doors = need,
			doors_ok = row.doors_ok == true,
			subtype = row.subtype,
			spawn_count = row.spawn_count,
			source_stb = row.source_stb,
			via = row.via,
			fallback = row.fallback == true,
			content_fallback = row.content_fallback == true,
			content_preference_error = row.content_preference_error,
			error = row.error,
			deal_choice = row.deal_choice,
			shop_pick = row.shop_pick,
			deal_magnet = row.deal_magnet,
			number_magnet = row.number_magnet,
			required_subtype = row.required_subtype,
			selected_subtype = row.selected_subtype,
			selected_variant = row.selected_variant,
			candidates_after_filter = row.candidates_after_filter,
			combat_content_mode = row.combat_content_mode,
			candidates_before_content_filter = row.candidates_before_content_filter,
			candidates_after_content_filter = row.candidates_after_content_filter,
			candidates_before_difficulty_filter = row.candidates_before_difficulty_filter,
			candidates_after_difficulty_filter = row.candidates_after_difficulty_filter,
			difficulty = row.difficulty,
			difficulty_min = row.difficulty_min,
			difficulty_max = row.difficulty_max,
			difficulty_widen_via = row.difficulty_widen_via,
			effective_weight = row.effective_weight,
			weight_decay_applied = row.weight_decay_applied,
			has_x_skull = row.has_x_skull,
			x_skull_quota_sgid = row.x_skull_quota_sgid,
			water_ii_white_fire_84 = row.water_ii_white_fire_84,
		}
	end

	-- content_complete = every slot has a usable RoomConfig (including 25600 degrade).
	-- Preference misses are diagnostics only; they must not fail layout_ready.
	local content_missing = {}
	local content_degraded = {}
	local content_ok = 0
	for _, asg in ipairs(M.ASSIGNMENTS) do
		local row = plan[asg.sgid]
		-- Delirium 2x2 claims deal@90: no separate RoomConfig; count as content-ok.
		if row and row.footprint_of then
			content_ok = content_ok + 1
		else
			if row and not row.cfg then
				apply_blank_content_fallback(row, asg, row.error or "missing_layout_late")
				plan[asg.sgid] = row
			end
			local has_cfg = row and row.cfg ~= nil
			local doors_ok = row and row.doors_ok == true
			if has_cfg and not doors_ok then
				-- 25600 should cover required doors; if not, still keep cfg for placement.
				doors_ok = row.content_fallback == true
				row.doors_ok = doors_ok
			end
			if has_cfg and doors_ok then
				content_ok = content_ok + 1
				if row.content_fallback then
					content_degraded[#content_degraded + 1] = {
						sgid = asg.sgid,
						kind = asg.kind,
						via = row.via,
						preference_error = row.content_preference_error,
					}
				end
			else
				content_missing[#content_missing + 1] = {
					sgid = asg.sgid,
					kind = asg.kind,
					room_type = row and row.room_type,
					via = row and row.via,
					error = row and (row.error or row.content_preference_error),
					has_cfg = has_cfg == true,
					doors_ok = doors_ok == true,
				}
			end
		end
	end

	-- STAGE3_2: diagnostic only — never mark content incomplete for quota miss.
	if combat_rule and combat_rule.mode == "quota_x_skull" then
		local x_count = 0
		local x_sgids = {}
		for _, sgid in ipairs(DEFAULT_COMBAT_SGIDS) do
			local prow = plan[sgid]
			if prow and prow.cfg and not prow.content_fallback and candidate_has_x_skull(prow) then
				x_count = x_count + 1
				x_sgids[#x_sgids + 1] = sgid
			end
		end
		summary.combat_content_rule.x_skull_count = x_count
		summary.combat_content_rule.x_skull_sgids = x_sgids
		summary.combat_content_rule.x_skull_quota_satisfied = (x_skull_quota_abandoned and x_count == 0)
			or (not x_skull_quota_abandoned and x_count == 1)
	end

	local content = {
		content_complete = #content_missing == 0,
		content_ok_count = content_ok,
		content_expected = #M.ASSIGNMENTS,
		content_missing = content_missing,
		content_degraded = content_degraded,
		content_degraded_count = #content_degraded,
		structure_expected = #M.ASSIGNMENTS,
		combat_content_rule = summary.combat_content_rule,
		combat_difficulty_band = summary.combat_difficulty_band,
	}

	if pending then
		pending.corridor_plan = plan
		pending.deal_room_choice = deal_choice
		pending.corridor_content = content
	end

	return {
		stage_stb = stage_stb,
		root_seed = root_seed,
		deal_choice = deal_choice,
		rows = summary,
		plan = plan,
		content = content,
	}
end

function M.cfg_for(pending, sgid)
	local plan = pending and pending.corridor_plan
	local row = plan and plan[sgid]
	if row and row.cfg then
		return row.cfg, row
	end
	return nil, row
end

function M.is_corridor_sgid(sgid)
	sgid = tonumber(sgid)
	return sgid ~= nil and sgid >= 78 and sgid <= 90
end

--- True when Boss@89 is Void Delirium 2x2 (deal@90 suppressed / footprint).
function M.is_delirium_void_endpoint(pending)
	local row = pending and pending.corridor_plan and pending.corridor_plan[M.BOSS_SGID]
	if not row then
		return false
	end
	return row.suppress_deal_90 == true
		or row.boss_role == "delirium"
		or row.shape_2x2 == true
		or row.pool == "delirium_void"
end

--- True when sgid 90 is claimed by Delirium 2x2 footprint (no separate deal place).
function M.is_deal_90_footprint(pending)
	local row = pending and pending.corridor_plan and pending.corridor_plan[M.DEAL_SGID]
	return row ~= nil and (row.footprint_of == M.BOSS_SGID or row.kind == "deal_footprint")
end

--- Main-path L/R slots that belong to the 78–90 chain (never secret side branches).
--- pending: optional; when Delirium 2x2, Boss@89 has no RIGHT→90 neighbor room.
function M.corridor_door_slots_for(sgid, pending)
	sgid = tonumber(sgid)
	if not M.is_corridor_sgid(sgid) then
		return {}
	end
	local slots = {}
	if sgid > 78 then
		slots[#slots + 1] = {slot = DoorSlot.LEFT0, neighbor = sgid - 1}
	end
	if sgid < 90 then
		local skip_right = sgid == M.BOSS_SGID and M.is_delirium_void_endpoint(pending)
		if not skip_right then
			slots[#slots + 1] = {slot = DoorSlot.RIGHT0, neighbor = sgid + 1}
		end
	end
	return slots
end

--- Legacy name: probe no longer uses this to gate unlock (unlock is always-on).
--- Kept for diagnostics / older callers: true only when vanilla may freely open doors.
function M.should_force_open_doors(sgid, room, desc)
	if not M.is_corridor_sgid(sgid) or not room then
		return false
	end
	if room:IsClear() ~= true then
		return false
	end
	local ambush_active = false
	pcall(function()
		ambush_active = room:IsAmbushActive() == true
	end)
	if ambush_active then
		return false
	end
	return true
end

--- Boss@89 RIGHT→90 / Deal@90 LEFT→89 use dedicated deal-door lifecycle (not main unlock).
--- Void Delirium 2x2: 90 is footprint — not a deal-door link.
function M.is_boss_deal_door_link(sgid, neighbor, pending)
	if pending and (M.is_delirium_void_endpoint(pending) or M.is_deal_90_footprint(pending)) then
		return false
	end
	sgid = tonumber(sgid)
	neighbor = tonumber(neighbor)
	if sgid == M.BOSS_SGID and neighbor == M.DEAL_SGID then
		return true
	end
	if sgid == M.DEAL_SGID and neighbor == M.BOSS_SGID then
		return true
	end
	return false
end

--- True when standing in a left/right neighbor of the challenge/miniboss slot.
function M.is_challenge_entry_neighbor(sgid, neighbor)
	sgid = tonumber(sgid)
	neighbor = tonumber(neighbor)
	local challenge = tonumber(M.CHALLENGE_SGID)
	if neighbor ~= challenge or challenge == nil then
		return false
	end
	return sgid == challenge - 1 or sgid == challenge + 1
end

function M.is_challenge_gate_sgid(sgid)
	sgid = tonumber(sgid)
	local challenge = tonumber(M.CHALLENGE_SGID)
	if sgid == nil or challenge == nil then
		return false
	end
	return sgid == challenge or sgid == challenge - 1 or sgid == challenge + 1
end

--- Stage+StageType eligibility for Boss → -10 secret-exit (route identity, not unlock).
--- Alt path floor I has no exit; floor II continues (Downpour II→Mines, Mines II→Mausoleum).
function M.get_secret_exit_rule(stage, stage_type)
	stage = tonumber(stage)
	stage_type = tonumber(stage_type)
	if stage_type == nil then
		stage_type = StageType and StageType.STAGETYPE_ORIGINAL or 0
	end
	local st_rep = StageType and StageType.STAGETYPE_REPENTANCE
	local st_rep_b = StageType and StageType.STAGETYPE_REPENTANCE_B
	local is_alt = (st_rep ~= nil and stage_type == st_rep)
		or (st_rep_b ~= nil and stage_type == st_rep_b)
	local downpour = (RoomSubType and RoomSubType.SECRET_EXIT_DOWNPOUR) or 1
	local mines = (RoomSubType and RoomSubType.SECRET_EXIT_MINES) or 2
	local mausoleum = (RoomSubType and RoomSubType.SECRET_EXIT_MAUSOLEUM) or 3

	-- Alt path chapter-1: only floor I has no exit; floor II continues to Mines.
	if stage == LevelStage.STAGE1_1 then
		if is_alt then
			return {
				eligible = false,
				reason = "downpour_i_no_exit",
				target_subtype = nil,
				kind = nil,
				stage = stage,
				stage_type = stage_type,
			}
		end
		return {
			eligible = true,
			reason = "basement_i_to_downpour",
			target_subtype = downpour,
			kind = "downpour",
			stage = stage,
			stage_type = stage_type,
		}
	end

	if stage == LevelStage.STAGE1_2 then
		if is_alt then
			return {
				eligible = true,
				reason = "downpour_ii_to_mines",
				target_subtype = mines,
				kind = "mines",
				stage = stage,
				stage_type = stage_type,
			}
		end
		return {
			eligible = true,
			reason = "basement_ii_to_downpour",
			target_subtype = downpour,
			kind = "downpour",
			stage = stage,
			stage_type = stage_type,
		}
	end

	if stage == LevelStage.STAGE2_1 then
		if is_alt then
			return {
				eligible = false,
				reason = "already_in_mines_i",
				target_subtype = nil,
				kind = nil,
				stage = stage,
				stage_type = stage_type,
			}
		end
		return {
			eligible = true,
			reason = "caves_i_to_mines",
			target_subtype = mines,
			kind = "mines",
			stage = stage,
			stage_type = stage_type,
		}
	end

	if stage == LevelStage.STAGE2_2 then
		if is_alt then
			-- Mines / Ashpit II → Mausoleum / Gehenna (vanilla exception).
			return {
				eligible = true,
				reason = "mines_ii_to_mausoleum",
				target_subtype = mausoleum,
				kind = "mausoleum",
				stage = stage,
				stage_type = stage_type,
			}
		end
		return {
			eligible = true,
			reason = "caves_ii_to_mines",
			target_subtype = mines,
			kind = "mines",
			stage = stage,
			stage_type = stage_type,
		}
	end

	if stage == LevelStage.STAGE3_1 then
		if is_alt then
			return {
				eligible = false,
				reason = "already_in_mausoleum_i",
				target_subtype = nil,
				kind = nil,
				stage = stage,
				stage_type = stage_type,
			}
		end
		return {
			eligible = true,
			reason = "depths_i_to_mausoleum",
			target_subtype = mausoleum,
			kind = "mausoleum",
			stage = stage,
			stage_type = stage_type,
		}
	end

	if stage == LevelStage.STAGE3_2 then
		if is_alt then
			-- Mausoleum/Gehenna II → Mom's Heart flesh door (not chapter SECRET_EXIT subtype).
			-- Runtime suppresses this when STATE_BACKWARDS_PATH_INIT (Dad's Note route).
			return {
				eligible = true,
				reason = "mausoleum_ii_to_moms_heart",
				target_subtype = nil,
				kind = "mausoleum_heart",
				stage = stage,
				stage_type = stage_type,
			}
		end
		-- Mainline Depths II: rewrite Home Beast Room (-10/666) with SECRET_EXIT_MAUSOLEUM.
		-- Skipping left -10 as Beast Room and kept the native 84→-10 door (pre-4d02c57b path).
		return {
			eligible = true,
			reason = "depths_ii_secret_exit_mausoleum",
			target_subtype = mausoleum,
			kind = "mausoleum",
			stage = stage,
			stage_type = stage_type,
		}
	end

	-- Corpse II only (Mortis out of scope): 89 = Mother gate, -10 = Mother 1x2 arena.
	if stage == LevelStage.STAGE4_2 then
		if st_rep ~= nil and stage_type == st_rep then
			return {
				eligible = true,
				reason = "corpse_ii_to_mother",
				target_subtype = nil,
				kind = "mother_arena",
				stage = stage,
				stage_type = stage_type,
			}
		end
		return {
			eligible = false,
			reason = "stage4_2_no_secret_exit",
			target_subtype = nil,
			kind = nil,
			stage = stage,
			stage_type = stage_type,
		}
	end

	return {
		eligible = false,
		reason = "stage_unsupported",
		target_subtype = nil,
		kind = nil,
		stage = stage,
		stage_type = stage_type,
	}
end

--- Compat: subtype only when eligible under ORIGINAL stage type assumption is unsafe.
--- Prefer get_secret_exit_rule(stage, stage_type). Without stage_type, treat as ORIGINAL.
function M.secret_exit_subtype_for_stage(stage, stage_type)
	local rule = M.get_secret_exit_rule(stage, stage_type)
	if rule and rule.eligible then
		return rule.target_subtype
	end
	return nil
end

--- Entry@78 native special-quest door (Mirror / Abandoned Mineshaft).
--- Uses Room:TrySpawnSpecialQuestDoor — no custom door entity, no TargetRoomIndex forge.
--- preferred_slot is the design intent; the API does not take a DoorSlot argument.
function M.get_special_quest_door_rule(stage, stage_type)
	stage = tonumber(stage)
	stage_type = tonumber(stage_type)
	if stage_type == nil then
		stage_type = StageType and StageType.STAGETYPE_ORIGINAL or 0
	end
	local st_rep = StageType and StageType.STAGETYPE_REPENTANCE
	local st_rep_b = StageType and StageType.STAGETYPE_REPENTANCE_B
	local is_alt = (st_rep ~= nil and stage_type == st_rep)
		or (st_rep_b ~= nil and stage_type == st_rep_b)
	local mirror_idx = (GridRooms and GridRooms.ROOM_MIRROR_IDX) or -100
	local mineshaft_idx = (GridRooms and GridRooms.ROOM_MINESHAFT_IDX) or -101
	local sq_mirror = (SpecialQuest and SpecialQuest.MIRROR) or 1
	local sq_mineshaft = (SpecialQuest and SpecialQuest.MINESHAFT) or 2
	local knife1 = (CollectibleType and CollectibleType.COLLECTIBLE_KNIFE_PIECE_1) or 626

	local function ineligible(reason)
		return {
			eligible = false,
			reason = reason,
			kind = nil,
			preferred_slot = nil,
			target_room_index = nil,
			force_quest = nil,
			requires_knife_piece_1 = false,
			knife_piece_1 = knife1,
			stage = stage,
			stage_type = stage_type,
			is_alt = is_alt,
		}
	end

	if not is_alt then
		return ineligible("not_alt_stage")
	end

	-- Downpour / Dross II → Mirror (-100), prefer LEFT0 on entry 78.
	if stage == LevelStage.STAGE1_2 then
		return {
			eligible = true,
			reason = "downpour_ii_mirror",
			kind = "mirror",
			preferred_slot = DoorSlot.LEFT0,
			target_room_index = mirror_idx,
			force_quest = sq_mirror,
			requires_knife_piece_1 = false,
			knife_piece_1 = knife1,
			stage = stage,
			stage_type = stage_type,
			is_alt = true,
		}
	end

	-- Mines / Ashpit II → Abandoned Mineshaft (-101), prefer UP0; needs Knife Piece 1.
	if stage == LevelStage.STAGE2_2 then
		return {
			eligible = true,
			reason = "mines_ii_mineshaft",
			kind = "mineshaft",
			preferred_slot = DoorSlot.UP0,
			target_room_index = mineshaft_idx,
			force_quest = sq_mineshaft,
			requires_knife_piece_1 = true,
			knife_piece_1 = knife1,
			stage = stage,
			stage_type = stage_type,
			is_alt = true,
		}
	end

	return ineligible("stage_no_special_quest_door")
end

--- Unified floor generation rule for room sources + Boss exits + secret exits.
function M.get_floor_generation_rule(stage, stage_type)
	stage = tonumber(stage)
	stage_type = tonumber(stage_type)
	if stage_type == nil then
		stage_type = StageType and StageType.STAGETYPE_ORIGINAL or 0
	end
	local st_rep = StageType and StageType.STAGETYPE_REPENTANCE
	local st_rep_b = StageType and StageType.STAGETYPE_REPENTANCE_B
	local is_alt = (st_rep ~= nil and stage_type == st_rep)
		or (st_rep_b ~= nil and stage_type == st_rep_b)
	local secret = M.get_secret_exit_rule(stage, stage_type)
	local special_quest = M.get_special_quest_door_rule(stage, stage_type)
	local normal = {spawn = true, reason = "default", keep_heaven_light = false}
	local room_source = {mode = "stage_stb"}

	if stage == LevelStage.STAGE5 then
		normal = {spawn = false, reason = "sheol_or_cathedral_vanilla_end", keep_heaven_light = false}
	elseif stage == LevelStage.STAGE6 then
		normal = {spawn = false, reason = "chest_or_dark_room", keep_heaven_light = false}
	elseif stage == LevelStage.STAGE7 then
		-- Void ends at Delirium@89 — no next-floor trapdoor after clear.
		normal = {spawn = false, reason = "void_delirium_endpoint", keep_heaven_light = false}
		room_source = {mode = "void_history_mix", sources = M.void_history_stbs()}
	elseif stage == LevelStage.STAGE4_2 then
		if is_alt then
			normal = {spawn = false, reason = "corpse_ii_vanilla_end", keep_heaven_light = false}
		else
			normal = {spawn = true, reason = "womb_ii_dual", keep_heaven_light = true}
		end
	elseif stage == LevelStage.STAGE4_3 or stage == LevelStage.STAGE8 then
		normal = {spawn = false, reason = "blue_womb_or_home", keep_heaven_light = false}
	end

	return {
		stage = stage,
		stage_type = stage_type,
		is_alt = is_alt,
		secret_exit_rule = secret,
		special_quest_door_rule = special_quest,
		normal_exit_rule = normal,
		room_source = room_source,
	}
end

local function pick_special_typed(room_type, required_subtype, root_seed, sgid_key, via_label)
	local opts = {
		allow_subtypes = {[required_subtype] = true},
		no_special_fallback = true,
	}
	-- Door mask 0: accept any 1x1 layout in the filtered subtype pool.
	local row = pick_typed(room_type, nil, 0, root_seed, sgid_key, opts)
	row.required_subtype = required_subtype
	row.selected_subtype = row.subtype
	row.selected_variant = row.variant
	row.candidates_after_filter = row.candidate_count or row.prefer_count
	if row.cfg and tonumber(row.subtype) ~= required_subtype then
		row.error = "subtype_mismatch"
		row.cfg = nil
		row.fallback = true
		row.via = via_label .. "_reject"
	elseif not row.cfg then
		row.error = row.error or (via_label .. "_missing_" .. tostring(required_subtype))
		row.fallback = true
		row.via = row.via or via_label .. "_missing"
	else
		row.via = via_label
	end
	return row
end

--- ROOM_SECRET_EXIT (-10) layout for restored chapter (Stage+StageType gated).
--- Mausoleum II alt uses Mom's Heart (mausoleum) boss layout at -10, not SECRET_EXIT subtypes.
function M.pick_secret_exit(restore_stage, root_seed, restore_stage_type)
	local rule = M.get_secret_exit_rule(restore_stage, restore_stage_type)
	if rule and rule.kind == "mausoleum_heart" and rule.eligible then
		local row = M.pick_mausoleum_heart_target(root_seed)
		row.rule = rule
		return row
	end
	if rule and rule.kind == "mother_arena" and rule.eligible then
		local row = M.pick_mother_arena_target(root_seed)
		row.rule = rule
		return row
	end
	if not rule or not rule.eligible or rule.target_subtype == nil then
		return {
			room_type = RoomType.ROOM_SECRET_EXIT,
			fallback = true,
			via = "secret_exit_ineligible",
			error = "secret_exit_ineligible_" .. tostring(rule and rule.reason or "unknown"),
			required_subtype = nil,
			skipped = true,
			skip_reason = rule and rule.reason or "unknown",
			rule = rule,
		}
	end
	local st = rule.target_subtype
	local row = pick_special_typed(
		RoomType.ROOM_SECRET_EXIT,
		st,
		root_seed,
		M.SECRET_EXIT_IDX,
		"secret_exit"
	)
	row.kind = "secret_exit"
	row.pool = "secret_exit"
	row.rule = rule
	row.exit_kind = rule.kind
	return row
end

--- Corpse II Mother fight at -10: CORPSE Boss Variant 1 (1x2), not SPECIAL_ROOMS 1x1 Mother.
function M.pick_mother_arena_target(root_seed)
	local row, err = boss_pick.pick_mother_arena()
	if not row then
		return {
			kind = "mother_arena",
			pool = "mother_arena",
			exit_kind = "mother_arena",
			room_type = RoomType.ROOM_BOSS,
			required_variant = M.BOSS_VARIANT_MOTHER_ARENA,
			required_subtype = M.BOSS_SUBTYPE_MOTHER,
			via = "mother_arena_corpse_1",
			rng_seed = root_seed,
			skipped = false,
			cfg = nil,
			fallback = true,
			error = tostring(err or "mother_arena_missing"),
		}
	end
	row.rng_seed = root_seed
	return row
end

function M.is_mother_arena_target_cfg(cfg_or_snap)
	return boss_pick.is_mother_arena_cfg(cfg_or_snap) == true
end

--- Witness / Mausoleum II flesh-route target at -10: Mom's Heart (mausoleum), not Home Beast Room.
--- Not a ROOM_SECRET_EXIT layout; TrySpawnSecretExit is not the flesh-door API.
function M.pick_mausoleum_heart_target(root_seed)
	local cfg = get_fixed_variant_cfg(RoomType.ROOM_BOSS, M.BOSS_VARIANT_MOMS_HEART_MAUSOLEUM)
	local row = {
		kind = "mausoleum_heart",
		pool = "mausoleum_heart",
		exit_kind = "mausoleum_heart",
		room_type = RoomType.ROOM_BOSS,
		required_subtype = M.BOSS_SUBTYPE_MOMS_HEART_MAUSOLEUM,
		required_variant = M.BOSS_VARIANT_MOMS_HEART_MAUSOLEUM,
		via = "mausoleum_heart_special_6040",
		rng_seed = root_seed,
		skipped = false,
	}
	if not cfg then
		row.cfg = nil
		row.fallback = true
		row.error = "moms_heart_mausoleum_cfg_missing"
		return row
	end
	row.cfg = cfg
	row.variant = cfg.Variant or M.BOSS_VARIANT_MOMS_HEART_MAUSOLEUM
	row.subtype = cfg.Subtype
	row.selected_subtype = cfg.Subtype
	row.selected_variant = row.variant
	row.shape = cfg.Shape
	row.doors = cfg.Doors
	row.name = cfg.Name
	row.spawn_count = cfg.SpawnCount
	row.source_stb = StbType.SPECIAL_ROOMS
	row.fallback = false
	if tonumber(cfg.Subtype) ~= M.BOSS_SUBTYPE_MOMS_HEART_MAUSOLEUM then
		row.cfg = nil
		row.fallback = true
		row.error = "moms_heart_mausoleum_subtype_mismatch"
	end
	return row
end

--- Reject Home Beast Room / non-heart configs left at ROOM_SECRET_EXIT_IDX.
function M.is_mausoleum_heart_target_cfg(cfg_or_snap)
	if type(cfg_or_snap) ~= "table" then
		return false
	end
	local room_type = tonumber(cfg_or_snap.Type or cfg_or_snap.type)
	local variant = tonumber(cfg_or_snap.Variant or cfg_or_snap.variant)
	local subtype = tonumber(cfg_or_snap.Subtype or cfg_or_snap.subtype)
	local name = tostring(cfg_or_snap.Name or cfg_or_snap.name or ""):lower()
	if variant == 666 or room_type == (RoomType and RoomType.ROOM_DUNGEON) then
		return false
	end
	if subtype == M.BOSS_SUBTYPE_MOMS_HEART_MAUSOLEUM
		and (variant == M.BOSS_VARIANT_MOMS_HEART_MAUSOLEUM or name:find("heart", 1, true))
	then
		return true
	end
	if room_type == RoomType.ROOM_BOSS and subtype == M.BOSS_SUBTYPE_MOMS_HEART_MAUSOLEUM then
		return true
	end
	return false
end

--- Member Card (-13): ordinary shop levels only (0–4 unlocked); never rare / Keeper B.
function M.pick_member_card_shop(root_seed)
	local unlocked = unlocked_shop_level_indices()
	local hard = is_hard_or_harder()
	local levels = {}
	for lv = 0, 4 do
		if unlocked[lv] then
			levels[#levels + 1] = lv
		end
	end
	if #levels == 0 then
		levels = {0}
	end
	local eligible = {}
	if hard then
		for _, lv in ipairs(levels) do
			eligible[#eligible + 1] = lv
		end
	else
		local max_lv = levels[1]
		for _, lv in ipairs(levels) do
			if lv > max_lv then
				max_lv = lv
			end
		end
		eligible = {max_lv}
	end
	local allow = {}
	for _, st in ipairs(eligible) do
		allow[st] = true
	end
	local opts = {allow_subtypes = allow, no_special_fallback = true}
	local row = pick_typed(RoomType.ROOM_SHOP, nil, 0, root_seed, M.SECRET_SHOP_IDX, opts)
	row.kind = "member_card_shop"
	row.pool = "member_card_shop"
	row.eligible_subtypes = eligible
	row.required_subtype = eligible[1]
	row.selected_subtype = row.subtype
	row.selected_variant = row.variant
	row.candidates_after_filter = row.candidate_count or row.prefer_count
	row.note = "ordinary shop layout for -13; never rare/keeper"
	if not row.cfg then
		row.fallback = true
		row.error = row.error or "member_card_shop_missing"
	end
	return row
end

--- Stairway (-18): ROOM_ANGEL + ANGEL_STAIRWAY.
function M.pick_angel_stairway(root_seed)
	local st = (RoomSubType and RoomSubType.ANGEL_STAIRWAY) or 1
	local row = pick_special_typed(RoomType.ROOM_ANGEL, st, root_seed, M.ANGEL_SHOP_IDX, "angel_stairway")
	row.kind = "angel_stairway"
	row.pool = "angel_stairway"
	return row
end

--- Blue Womb (-8): StbType.BLUE_WOMB / ROOM_DEFAULT / variant 1 "Entrance Room".
function M.pick_blue_womb_entrance(_root_seed)
	local holder = room_config_holder()
	local cfg = nil
	local via = nil
	if holder and holder.GetRoomByStageTypeAndVariant then
		pcall(function()
			cfg = holder.GetRoomByStageTypeAndVariant(
				StbType.BLUE_WOMB,
				RoomType.ROOM_DEFAULT,
				1,
				0
			)
			via = "GetRoomByStageTypeAndVariant_mode0"
		end)
		if not cfg then
			pcall(function()
				cfg = holder.GetRoomByStageTypeAndVariant(
					StbType.BLUE_WOMB,
					RoomType.ROOM_DEFAULT,
					1,
					-1
				)
				via = "GetRoomByStageTypeAndVariant_mode-1"
			end)
		end
	end
	local row = {
		kind = "blue_womb_entrance",
		pool = "blue_womb_entrance",
		cfg = cfg,
		variant = cfg and cfg.Variant or 1,
		subtype = cfg and cfg.Subtype or nil,
		shape = cfg and cfg.Shape or nil,
		name = cfg and cfg.Name or nil,
		selected_variant = cfg and cfg.Variant or 1,
		selected_subtype = cfg and cfg.Subtype or nil,
		via = via,
		source_stb = StbType.BLUE_WOMB,
		note = "BLUE_WOMB DEFAULT variant 1 Entrance Room for GridRooms -8",
	}
	local type_ok = cfg and tonumber(cfg.Type) == tonumber(RoomType.ROOM_DEFAULT)
	local variant_ok = cfg and tonumber(cfg.Variant) == 1
	local name = cfg and tostring(cfg.Name or "") or ""
	local name_ok = name:find("[Ee]ntrance") ~= nil
	if not cfg or not type_ok or not variant_ok then
		row.cfg = nil
		row.error = "blue_womb_entrance_pick_failed"
	elseif not name_ok then
		-- Keep cfg if Type/Variant match; log unexpected name for audit.
		row.name_warning = name
	end
	return row
end

--- Boss Rush (-5): SPECIAL_ROOMS / ROOM_BOSSRUSH (vanilla layouts are shape 2x2).
function M.pick_boss_rush(root_seed)
	local idx = M.BOSS_RUSH_IDX
	local seed = select(1, compass_rng.derive_seed(root_seed, "boss_rush", idx, 1))
		or tonumber(root_seed)
		or 1
	local shape = (RoomShape and RoomShape.ROOMSHAPE_2x2) or 8
	local holder = room_config_holder()
	local cfg = nil
	local via = nil
	if holder and holder.GetRandomRoom then
		pcall(function()
			cfg = holder.GetRandomRoom(
				seed,
				false,
				StbType.SPECIAL_ROOMS,
				RoomType.ROOM_BOSSRUSH,
				shape,
				0,
				-1,
				0,
				10,
				0,
				-1,
				0
			)
			via = "GetRandomRoom_2x2"
		end)
		if (not cfg or cfg.Type ~= RoomType.ROOM_BOSSRUSH) and RoomShape and RoomShape.NUM_ROOMSHAPES then
			pcall(function()
				cfg = holder.GetRandomRoom(
					seed,
					false,
					StbType.SPECIAL_ROOMS,
					RoomType.ROOM_BOSSRUSH,
					RoomShape.NUM_ROOMSHAPES,
					0,
					-1,
					0,
					10,
					0,
					-1,
					0
				)
				via = "GetRandomRoom_any_shape"
			end)
		end
	end
	local row = {
		kind = "boss_rush",
		pool = "boss_rush",
		cfg = cfg,
		variant = cfg and cfg.Variant or nil,
		subtype = cfg and cfg.Subtype or nil,
		shape = cfg and cfg.Shape or shape,
		selected_variant = cfg and cfg.Variant or nil,
		selected_subtype = cfg and cfg.Subtype or nil,
		via = via,
		seed = seed,
		source_stb = StbType.SPECIAL_ROOMS,
		note = "SPECIAL_ROOMS ROOM_BOSSRUSH for GridRooms -5",
	}
	if not cfg or cfg.Type ~= RoomType.ROOM_BOSSRUSH then
		row.cfg = nil
		row.error = "boss_rush_pick_failed"
	end
	return row
end

return M

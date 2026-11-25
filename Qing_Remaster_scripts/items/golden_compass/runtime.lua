-- Golden Compass corridor runtime (production).
-- Owns floor generation / doors / negative rooms / deal+challenge while phase is armed|generating|active.
-- Content RNG root: save.elses Item_Golden_Compass_corridor.root_seed (from collectible Next()).
-- Probe may enable logging + debug arm; formal play does not require the probe.

local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
local corridor_plan_mod = require("Qing_Remaster_scripts.items.golden_compass.corridor_plan")
local compass_state = require("Qing_Remaster_scripts.items.golden_compass.state")
local compass_rng = require("Qing_Remaster_scripts.items.golden_compass.rng")
local boss_encounter = require("Qing_Remaster_scripts.items.golden_compass.boss_encounter")
local deal_chance_holder = require("Qing_Remaster_scripts.callbacks.deal_chance_holder")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")

local MAP_RESOLVER_PATH = "Qing_Remaster_scripts.items.golden_compass.map_resolver"
local map_resolver = nil
local map_resolver_load_error = nil
do
	local ok, mod = pcall(require, MAP_RESOLVER_PATH)
	if ok and type(mod) == "table" then
		map_resolver = mod
	else
		map_resolver_load_error = ok and "module returned non-table" or tostring(mod)
		print("[fixed_corridor_probe] map_resolver load failed: " .. tostring(map_resolver_load_error))
	end
end

local MODULE_PATH = "Qing_Remaster_scripts.items.golden_compass.runtime"
local FILE_STEM = "golden_compass_runtime"
local SCHEMA = "golden_compass_runtime"
local SCHEMA_VERSION = 1
local BOSS_TYPE_MOM = (BossType and BossType.MOM) or 6
local DOOR_VARIANT_UNLOCKED = (DoorVariant and DoorVariant.DOOR_UNLOCKED) or 8
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
-- Forward decl: special_quest_doors may call these before the real assignment below.
local write_desc_config
local init_desc_runtime
local MAX_EVENTS = 400
local DEAL_SUPPRESS_PROVIDER_KEY = "fixed_corridor_probe_natural_deal_suppress"
local DEAL_GUARANTEE_PROVIDER_KEY = "fixed_corridor_deal_guarantee"
local ROOM_VARIANT_FIXED_84 = (corridor_plan_mod.ROOM_VARIANT_FIXED_84) or 25602
local CHALLENGE_ROOM_SGID = corridor_plan_mod.CHALLENGE_SGID or 81
local SECRET_EXIT_IDX = corridor_plan_mod.SECRET_EXIT_IDX or -10
local SECRET_SHOP_IDX = corridor_plan_mod.SECRET_SHOP_IDX or -13
local ANGEL_SHOP_IDX = corridor_plan_mod.ANGEL_SHOP_IDX or -18
local BOSS_RUSH_IDX = corridor_plan_mod.BOSS_RUSH_IDX
	or (GridRooms and GridRooms.ROOM_BOSSRUSH_IDX)
	or -5
-- BLUE_WOMB_IDX: use corridor_plan_mod.BLUE_WOMB_IDX / GridRooms inline (200-local budget).
-- Wiki Curse Room: normal 0–30; Voodoo Head exclusive enhanced 31–40.
local CURSE_VARIANT_NORMAL_MAX = 30
local CURSE_VARIANT_VOODOO_MIN = 31
local CURSE_VARIANT_VOODOO_MAX = 40
-- Priority probes for multi-cell residue (not a proven residual list).
local OCCUPANCY_PROBE_INDICES = {44, 56, 57, 58, 69, 71, 72, 95, 97, 98, 109, 108, 110, 122, 90}
-- Force PlaceRoom targets: old multi-cell aliases → own rooms from room_plan.
-- {grid, expect_owner_before} — Place only if owner_sgid ~= grid.
local FORCE_PLACE_TARGETS = {
	{grid = 108, expect_owner_before = 95},
	{grid = 110, expect_owner_before = 97},
	{grid = 122, expect_owner_before = 109},
}
-- DoorSlot 0..3 = LEFT/UP/RIGHT/DOWN for 1x1.
local DOOR_MASK_1X1_ALL = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3)
local DOOR_MASK_FOUR = DOOR_MASK_1X1_ALL
local DOOR_MASK_UP_LEFT = (1 << DoorSlot.UP0) | (1 << DoorSlot.LEFT0)
local DOOR_MASK_LEFT = (1 << DoorSlot.LEFT0)
local DOOR_MASK_DOWN = (1 << DoorSlot.DOWN0)
local DOOR_VARIANT_HIDDEN = (DoorVariant and DoorVariant.DOOR_HIDDEN) or 7
-- 109 is 1x1 ultra-secret: LEFT=108, RIGHT=110, DOWN=122, UP=none (never secret-exit -10).
local ROOM_109_SGID = 109
local ROOM_97_SGID = 97
local ROOM_98_SGID = 98
local ROOM_72_SGID = 72 -- optional second curse above 85 (Voodoo Head)
local BOSS_ROOM_SGID = corridor_plan_mod.BOSS_SGID or 89
local DEAL_ROOM_SGID = corridor_plan_mod.DEAL_SGID or 90
local ENTRY_ROOM_SGID = corridor_plan_mod.ENTRY_SGID or 78
-- Special rooms: planned RoomConfig before replace/Place (shared room_plan).
-- 98 curse is planned separately (normal 0–30 vs Voodoo 31–40).
-- 72 is appended only when Voodoo Head is held (also 31–40).
local SPECIAL_ROOM_ASSIGNMENTS = {
	{sgid = 95, room_type = RoomType.ROOM_SECRET, pool = "secret"},
	{sgid = 97, room_type = RoomType.ROOM_SECRET, pool = "secret"},
	{sgid = 108, room_type = RoomType.ROOM_SUPERSECRET, pool = "supersecret"},
	{sgid = 110, room_type = RoomType.ROOM_SUPERSECRET, pool = "supersecret"},
	{sgid = 109, room_type = RoomType.ROOM_ULTRASECRET, pool = "ultrasecret"},
	{sgid = 122, room_type = RoomType.ROOM_ULTRASECRET, pool = "ultrasecret"},
}
-- Legacy pairwise links kept for ensure_live_doors MakeDoor only (topology uses normalize).
-- north_secret_mirror: eager-pinned via corridor_plan (no new main-chunk local; 200-local limit).
-- Never first-require it from MC_PRE/POST_NEW_ROOM — Qing package.path is gone by then.
local FORCE_PLACE_DOOR_LINKS = {
	{from = 95, slot = DoorSlot.DOWN0, to = 108},
	{from = 97, slot = DoorSlot.DOWN0, to = 110},
	{from = 97, slot = DoorSlot.RIGHT0, to = 98},
	{from = 85, slot = DoorSlot.DOWN0, to = 98},
	{from = 109, slot = DoorSlot.DOWN0, to = 122},
	{from = 108, slot = DoorSlot.RIGHT0, to = 109},
	{from = 109, slot = DoorSlot.RIGHT0, to = 110},
	{from = 84, slot = DoorSlot.DOWN0, to = 97},
}
-- Extra 1x1 adjacencies beyond the horizontal corridor chain (normalize writes both ends).
-- Corridor LEFT/RIGHT are derived from present rooms; do not list 96→97 (no own room at 96).
-- 85→72 is appended only when Voodoo Head curse@72 is planned/placed.
local EXTRA_DOOR_LINKS_BASE = {
	{from = 84, slot = DoorSlot.DOWN0, to = 97},
	{from = 85, slot = DoorSlot.DOWN0, to = 98},
	{from = 82, slot = DoorSlot.DOWN0, to = 95},
	{from = 95, slot = DoorSlot.DOWN0, to = 108},
	{from = 97, slot = DoorSlot.RIGHT0, to = 98},
	{from = 97, slot = DoorSlot.DOWN0, to = 110},
	{from = 108, slot = DoorSlot.RIGHT0, to = 109},
	{from = 109, slot = DoorSlot.RIGHT0, to = 110},
	{from = 109, slot = DoorSlot.DOWN0, to = 122},
}
local DOOR_NORMALIZE_FOCUS = {
	44, 56, 57, 58, 69, 71, 72, 82, 83, 84, 85, 95, 97, 98, 108, 109, 110, 122,
}
local SECRET_EXIT_IDX = (GridRooms and GridRooms.ROOM_SECRET_EXIT_IDX) or -10
local OPPOSITE_DOOR_SLOT = {
	[DoorSlot.LEFT0] = DoorSlot.RIGHT0,
	[DoorSlot.RIGHT0] = DoorSlot.LEFT0,
	[DoorSlot.UP0] = DoorSlot.DOWN0,
	[DoorSlot.DOWN0] = DoorSlot.UP0,
}

-- Minimal STB→Grid map (StageAPI CorrectedGridTypes subset; 25600/25601 needs).
-- STB Type 1000 = rock, NOT runtime EntityType.ENTITY_EFFECT.
local STB_TO_GRID = {
	[1000] = GridEntityType.GRID_ROCK,
	[1001] = GridEntityType.GRID_ROCK_BOMB,
	[1002] = GridEntityType.GRID_ROCK_ALT,
	[1008] = GridEntityType.GRID_ROCK_ALT2,
	[1010] = GridEntityType.GRID_ROCK_SPIKED,
	[1011] = GridEntityType.GRID_ROCK_GOLD,
	[1900] = GridEntityType.GRID_ROCKB,
	[3000] = GridEntityType.GRID_PIT,
	[1930] = GridEntityType.GRID_SPIKES,
	[1940] = GridEntityType.GRID_SPIDERWEB,
	[1500] = GridEntityType.GRID_POOP,
}
local KEEP_GRID_ON_CLEAR = {
	[GridEntityType.GRID_DOOR] = true,
	[GridEntityType.GRID_WALL] = true,
	[GridEntityType.GRID_GRAVITY] = true,
}

local STAGE_TYPE_SUFFIX = {
	[StageType.STAGETYPE_ORIGINAL] = "",
	[StageType.STAGETYPE_WOTL] = "a",
	[StageType.STAGETYPE_AFTERBIRTH] = "b",
	[StageType.STAGETYPE_REPENTANCE] = "c",
	[StageType.STAGETYPE_REPENTANCE_B] = "d",
}

local HOME_STAGE = LevelStage.STAGE8
local HOME_STAGE_TYPE = StageType.STAGETYPE_ORIGINAL
local SHAPE_1X1 = RoomShape.ROOMSHAPE_1x1
-- ROOMSHAPE_2x2 = 8; avoid extra main-chunk local (200-local limit).
local LEVEL_GRID_WIDTH = 13
local CORRIDOR_ROW = 6
local CORRIDOR_LEFT = 0
local CORRIDOR_RIGHT = 12
local PLAYER_ENTRY_INDEX = 78
local ORIGINAL_START_INDEX = 84
local ROOM_VARIANT_CORRIDOR = 25600 -- empty entry STB (78)
local ROOM_VARIANT_SECRET_TERRAIN = 25601
-- ROOM_VARIANT_FIXED_84 (=25602) defined above from corridor_plan_mod

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	own_key = "fixed_corridor_probe_",
}

local cfg = {
	enabled = false,
	debug_root_seed = nil,
	arm_home_layout = false,
	-- "smoke" | "main" | "p0" | "p1" | "p2a" | "p2b" | "p2c"
	p_mode = "smoke",
	-- "smoke" = one TryPlaceRoom only, no enter 78; "full" = 78–90
	place_mode = "smoke",
	append_corridor = false,
	corridor_extra = 3,
	restore_identity = true,
	enter_player_entry = false,
	entry_change_api = "game",
	replace_corridor_config = true,
	replace_offcorridor_secret = true,
	experiment_keep_start_unvisited = false,
	fill_full_corridor = false,
	auto_disarm = true,
	-- Manual-only Witness probe (Mausoleum/Gehenna II). Never default-on in normal runs.
	witness_mausoleum_test = false,
	-- Expensive corridor event spam / bulky report fields. Default off.
	detail_logging = false,
}

--- Event kinds that are diagnostic-only (skip unless detail_logging).
local VERBOSE_EVENT_KINDS = {
	special_quest_mirror_interact = true,
	live_room_content = true,
	occupancy_alias_probe = true,
	door_audit = true,
	home_layout_snapshot = true,
	map_baseline_snapshot = true,
	room_replacements_applied = true,
	minimap_refresh = true,
	enter_97_map_check = true,
}

local runtime = {
	session_id = 0,
	events = {},
	note = "idle",
	pending = nil,
	double_transitioning = false,
	layout_snapshot = nil,
	level_snapshot = nil,
	last_select = nil,
	place_attempts = {},
	placement_conflicts = {},
	room_config_replacements = {},
	home_layout_snapshot = nil,
	connection_audit = nil,
	occupancy_probe = nil,
	first_84_live = nil,
	rematerialize_84_result = nil,
	identity_restored_seen = false,
	-- Continue active: run one current-room visit init (POST_NEW_ROOM may not re-fire).
	continue_current_room_pending = false,
	-- One continuous stay in Boss@89 (cleared when leaving 89).
	boss_89_visit_active = false,
	boss_89_visit_init_tag = nil,
	last_corridor_sgid = nil,
	deal_type_source = nil,
	force_place_batch_result = nil,
	force_place_door_links = nil,
	door_topology_normalize = nil,
	live_84_secret_door = nil,
	restore_84_explore_result = nil,
	special_room_plan = nil,
	corridor_room_plan = nil,
	boss_90_plan = nil,
	boss_90_enter = nil,
	boss_90_combat = nil,
	boss_90_clear = nil,
	boss_90_entered = false,
	boss_90_clear_logged = false,
	boss_89_trapdoor = nil,
	boss_89_deal_door = nil,
	boss_89_door_restore = nil,
	boss_89_mom_sim_door = nil,
	-- One SetRoomTypes+Close per uncleared visit to Deal@90 (POST_UPDATE must not restyle).
	deal_90_seal_init_done = false,
	deal_door_sprite_watch = nil,
	corridor_active = false,
	corridor_deal_type = nil,
	corridor_force_boss = nil,
	block_curses = false,
	force_boss_subtype_once = nil,
	-- One-shot StageAPI extension Boss@89 test: true = first pool entry, string = BossID.
	force_stageapi_boss_once = nil,
	suppress_natural_deal = false,
	deal_guarantee = false,
	negative_rooms = nil,
	secret_exit_spawn = nil,
	-- One TrySpawnSecretExit attempt per Boss-room visit (cleared on enter 89).
	secret_exit_attempted_this_visit = false,
	secret_exit_confirmed_slot = nil,
	secret_exit_spawn_attempts = 0,
	-- After restore: verify open/locked/sprite once native has ticked.
	secret_exit_restore_verify = nil,
	secret_exit_restore_consistency = nil,
	-- Block tick→save.elses until restore/verify finishes (prevents State=1 wiping mines State=4).
	secret_exit_persist_hold = false,
	secret_exit_persist_hold_reason = nil,
	witness_last_snapshot = nil,
	witness_heart_killed_seen = false,
	curse_clear = nil,
	fixed_84_content = nil,
	fixed_84_options_spawned = false,
	fixed_84_choice = nil,
	fixed_84_item_id = nil,
	fixed_84_item_init_seed = nil,
	fixed_84_angel_item_id = nil,
	fixed_84_angel_item_init_seed = nil,
	fixed_84_devil_item_id = nil,
	fixed_84_devil_item_init_seed = nil,
	fixed_84_chosen_item_init_seed = nil,
	fixed_84_chosen_item_kind = nil,
	fixed_84_bed_init_seed = nil,
	fixed_84_options_index = nil,
	fixed_84_sleep_pending_seed = nil,
	fixed_84_sleep_pending_frame = nil,
	mirror_79_knife_piece_spawned = false,
	empty_78_result = nil,
	-- Entry@78 Mirror (custom virtual) / Mineshaft (native); visit-scoped.
	special_quest_door = nil,
	special_quest_door_attempted_this_visit = false,
	special_quest_door_attempted_sgid = nil,
	special_quest_force = nil,
	special_quest_mirror_enter = nil,
	special_quest_mirror_prepare = nil,
	special_quest_mirror_corridor = nil,
	mirror_corridor_ready = false,
	special_quest_mirror_interact = nil,
	special_quest_mirror_interact_log = nil,
	special_quest_mirror_interact_emit_frame = nil,
	corridor_door_gate = nil,
	corridor_door_gate_log_key = nil,
	corridor_door_gate_fail_count = 0,
	corridor_door_gate_open_fail_logged = false,
	deal_90_preplace = nil,
	boss_89_place = nil,
	curse_72_plan = nil,
	curse_72_place = nil,
	pre_97_secret = nil,
	map_settlement = nil,
	map_settlement_done = false,
	map_resolver_load_error = map_resolver_load_error,
	force_place_108_result = nil,
	room_109_seal = nil,
	config_cache = {},
	place_plan = {},
	last_result = nil,
}

local function game_frame()
	local ok, n = pcall(function()
		return Game():GetFrameCount()
	end)
	return ok and n or nil
end

local function push_event(kind, extra)
	if VERBOSE_EVENT_KINDS[kind] and not cfg.detail_logging then
		-- Keep latest verbose sample without flooding the event queue.
		runtime.latest_verbose = runtime.latest_verbose or {}
		runtime.latest_verbose[kind] = {
			kind = kind,
			game_frame = game_frame(),
			extra = extra,
		}
		return nil
	end
	local row = {
		schema = SCHEMA,
		schema_version = SCHEMA_VERSION,
		kind = kind,
		game_frame = game_frame(),
		session_id = runtime.session_id,
		p_mode = cfg.p_mode,
	}
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			row[k] = v
		end
	end
	runtime.events[#runtime.events + 1] = row
	while #runtime.events > MAX_EVENTS do
		table.remove(runtime.events, 1)
	end
	return row
end

local function safe_call(fn, ...)
	if type(fn) ~= "function" then
		return nil, false, "not_function"
	end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then
		return nil, false, tostring(a)
	end
	return a, true, nil, b, c, d
end

local function stage_cmd(stage, stage_type)
	local suffix = STAGE_TYPE_SUFFIX[stage_type or HOME_STAGE_TYPE] or ""
	return "stage " .. tostring(stage) .. suffix
end

local function grid_index(col, row)
	return row * LEVEL_GRID_WIDTH + col
end

local function is_corridor_cell(col, row)
	return row == CORRIDOR_ROW and col >= CORRIDOR_LEFT and col <= CORRIDOR_RIGHT
end

local function sgid_is_corridor(sgid)
	if type(sgid) ~= "number" or sgid < 0 then
		return false
	end
	return is_corridor_cell(sgid % LEVEL_GRID_WIDTH, math.floor(sgid / LEVEL_GRID_WIDTH))
end

local function read_level_identity()
	local level = Game():GetLevel()
	local stage, stage_type, starting, curse, room_index
	pcall(function()
		stage = level:GetStage()
		stage_type = level:GetStageType()
		starting = level:GetStartingRoomIndex()
		curse = level:GetCurses()
		room_index = level:GetCurrentRoomIndex()
	end)
	return {
		stage = stage,
		stage_type = stage_type,
		starting_room_index = starting,
		curses = curse,
		current_room_index = room_index,
	}
end

--- Descriptor owns this index (SafeGridIndex + ListIndex). Data may still be nil.
--- Used for negative special rooms (-10/-13/-18) before first RoomConfig write.
--- Unregistered GetRoomByIdx(positive sgid) may alias -1 devil (wrong SafeGridIndex) — fails here.
local function room_desc_owns_index(desc, sgid)
	if not desc or sgid == nil then
		return false
	end
	local list = tonumber(desc.ListIndex)
	return tonumber(desc.SafeGridIndex) == tonumber(sgid)
		and list ~= nil
		and list >= 0
end

--- Normal corridor / positive SGID: owned index AND layout Data present.
local function room_desc_is_registered(desc, sgid)
	return room_desc_owns_index(desc, sgid) and desc.Data ~= nil
end

--- Safe to write RoomConfig onto this descriptor for expect_sgid.
--- Negative indices: identity only (Data may be nil). Positive: full registration.
local function room_desc_writable_for(desc, sgid)
	if desc == nil or sgid == nil then
		return false
	end
	if tonumber(sgid) < 0 then
		return room_desc_owns_index(desc, sgid)
	end
	return room_desc_is_registered(desc, sgid)
end

--- Prefer dimension 0 for normal-corridor queries (matches TryPlaceRoom dim).
local function get_registered_room_desc(sgid, dimension)
	local level = Game():GetLevel()
	local desc = nil
	local dim = dimension
	if dim == nil then
		dim = 0
	end
	pcall(function()
		desc = level:GetRoomByIdx(sgid, dim)
	end)
	if room_desc_is_registered(desc, sgid) then
		return true, desc
	end
	return false, desc
end

--- Registered room only (not Data-bearing aliases).
local function room_has_data(sgid)
	return get_registered_room_desc(sgid, 0)
end

--- Entry@78 must be a real registered DEFAULT / 25600 (or Water II 25603) before ChangeRoom(78).
local function entry_78_ready()
	local ok, desc = get_registered_room_desc(PLAYER_ENTRY_INDEX, 0)
	if not ok or not desc or not desc.Data then
		return false, desc, "entry_78_unregistered"
	end
	local data = desc.Data
	if tonumber(data.Type) ~= tonumber(RoomType.ROOM_DEFAULT) then
		return false, desc, "entry_78_wrong_type"
	end
	local variant = tonumber(data.Variant)
	if not corridor_plan_mod.is_entry_78_variant(variant) then
		return false, desc, "entry_78_wrong_variant"
	end
	return true, desc, nil
end

local function snapshot_start_room(label)
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(ORIGINAL_START_INDEX)
	local cur = level:GetCurrentRoomDesc()
	local data = desc and desc.Data
	local backwards_path = nil
	pcall(function()
		if GameStateFlag and GameStateFlag.STATE_BACKWARDS_PATH then
			backwards_path = Game():GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH)
		end
	end)
	local stairway_collectible = false
	pcall(function()
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and player:HasCollectible(CollectibleType.COLLECTIBLE_STAIRWAY) then
				stairway_collectible = true
				break
			end
		end
	end)
	return {
		label = label,
		safe_grid_index = desc and desc.SafeGridIndex,
		visited = desc and desc.VisitedCount,
		list_index = desc and desc.ListIndex,
		type = data and data.Type,
		variant = data and data.Variant,
		current_room_index = cur and cur.SafeGridIndex,
		starting_room_index = level:GetStartingRoomIndex(),
		stairway_collectible = stairway_collectible,
		backwards_path = backwards_path,
	}
end

local function get_room_config(room_type, variant)
	local key = tostring(room_type) .. ":" .. tostring(variant)
	if runtime.config_cache[key] ~= nil then
		local cached = runtime.config_cache[key]
		return cached ~= false and cached or nil
	end
	local holder = rawget(_G, "RoomConfig") or rawget(_G, "RoomConfigHolder")
	if not holder or not holder.GetRoomByStageTypeAndVariant then
		runtime.config_cache[key] = false
		return nil
	end
	local cfg_room
	local ok = pcall(function()
		cfg_room = holder.GetRoomByStageTypeAndVariant(StbType.SPECIAL_ROOMS, room_type, variant, 0)
	end)
	if not (ok and cfg_room) then
		ok = pcall(function()
			cfg_room = holder.GetRoomByStageTypeAndVariant(StbType.SPECIAL_ROOMS, room_type, variant, -1)
		end)
	end
	runtime.config_cache[key] = (ok and cfg_room) or false
	if runtime.config_cache[key] == false then
		return nil
	end
	return cfg_room
end

local function level_stage_to_stb(stage, stage_type)
	stage = tonumber(stage)
	stage_type = tonumber(stage_type) or 0
	if stage == nil then
		return nil
	end
	if stage == LevelStage.STAGE4_3 then
		return StbType.BLUE_WOMB
	end
	if stage == LevelStage.STAGE7
		or (LevelStage.STAGE7_GREED ~= nil and stage == LevelStage.STAGE7_GREED)
	then
		return StbType.VOID
	end
	if stage == LevelStage.STAGE8 then
		return StbType.HOME
	end
	local rows = {
		[LevelStage.STAGE1_1] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.BASEMENT,
			[StageType.STAGETYPE_WOTL] = StbType.CELLAR,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.BURNING_BASEMENT,
			[StageType.STAGETYPE_REPENTANCE] = StbType.DOWNPOUR,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.DROSS,
		},
		[LevelStage.STAGE1_2] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.BASEMENT,
			[StageType.STAGETYPE_WOTL] = StbType.CELLAR,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.BURNING_BASEMENT,
			[StageType.STAGETYPE_REPENTANCE] = StbType.DOWNPOUR,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.DROSS,
		},
		[LevelStage.STAGE2_1] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.CAVES,
			[StageType.STAGETYPE_WOTL] = StbType.CATACOMBS,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.FLOODED_CAVES,
			[StageType.STAGETYPE_REPENTANCE] = StbType.MINES,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.ASHPIT,
		},
		[LevelStage.STAGE2_2] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.CAVES,
			[StageType.STAGETYPE_WOTL] = StbType.CATACOMBS,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.FLOODED_CAVES,
			[StageType.STAGETYPE_REPENTANCE] = StbType.MINES,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.ASHPIT,
		},
		[LevelStage.STAGE3_1] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.DEPTHS,
			[StageType.STAGETYPE_WOTL] = StbType.NECROPOLIS,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.DANK_DEPTHS,
			[StageType.STAGETYPE_REPENTANCE] = StbType.MAUSOLEUM,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.GEHENNA,
		},
		[LevelStage.STAGE3_2] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.DEPTHS,
			[StageType.STAGETYPE_WOTL] = StbType.NECROPOLIS,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.DANK_DEPTHS,
			[StageType.STAGETYPE_REPENTANCE] = StbType.MAUSOLEUM,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.GEHENNA,
		},
		[LevelStage.STAGE4_1] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.WOMB,
			[StageType.STAGETYPE_WOTL] = StbType.UTERO,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.SCARRED_WOMB,
			[StageType.STAGETYPE_REPENTANCE] = StbType.CORPSE,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.MORTIS,
		},
		[LevelStage.STAGE4_2] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.WOMB,
			[StageType.STAGETYPE_WOTL] = StbType.UTERO,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.SCARRED_WOMB,
			[StageType.STAGETYPE_REPENTANCE] = StbType.CORPSE,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.MORTIS,
		},
		[LevelStage.STAGE5] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.SHEOL,
			[StageType.STAGETYPE_WOTL] = StbType.CATHEDRAL,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.SHEOL,
		},
		[LevelStage.STAGE6] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.DARK_ROOM,
			[StageType.STAGETYPE_WOTL] = StbType.CHEST,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.DARK_ROOM,
		},
	}
	local row = rows[stage]
	if not row then
		return nil
	end
	return row[stage_type] or row[StageType.STAGETYPE_ORIGINAL]
end

local function room_config_holder()
	return rawget(_G, "RoomConfig") or rawget(_G, "RoomConfigHolder")
end

local function collect_roomset_candidates(stb, room_type, mode, required_doors)
	local out = {}
	local need = required_doors or DOOR_MASK_FOUR
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
		set = stage_cfg:GetRoomSet(mode or 0)
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
				local weight = 1
				pcall(function()
					weight = tonumber(room.Weight)
						or tonumber(room.weight)
						or tonumber(room.InitialWeight)
						or 1
				end)
				out[#out + 1] = {
					cfg = room,
					stb = stb,
					mode = mode or 0,
					type = room.Type,
					variant = room.Variant,
					shape = room.Shape,
					doors = doors,
					weight = weight,
				}
			end
		end
	end
	return out
end

local function is_voodoo_curse_layout(cfg)
	if not cfg then
		return false
	end
	local tp = cfg.Type
	local shape = cfg.Shape
	local variant = tonumber(cfg.Variant) or -1
	return tp == RoomType.ROOM_CURSE
		and shape == SHAPE_1X1
		and variant >= CURSE_VARIANT_VOODOO_MIN
		and variant <= CURSE_VARIANT_VOODOO_MAX
end

local function is_normal_curse_layout(cfg)
	if not cfg then
		return false
	end
	local tp = cfg.Type
	local shape = cfg.Shape
	local variant = tonumber(cfg.Variant) or -1
	return tp == RoomType.ROOM_CURSE
		and shape == SHAPE_1X1
		and variant >= 0
		and variant <= CURSE_VARIANT_NORMAL_MAX
end

local function filter_variant_range(candidates, variant_min, variant_max, exclude_variant)
	if variant_min == nil and variant_max == nil and exclude_variant == nil then
		return candidates
	end
	local out = {}
	local vmin = variant_min
	local vmax = variant_max
	for _, row in ipairs(candidates) do
		local v = tonumber(row.variant)
		if v ~= nil then
			local in_range = true
			if vmin ~= nil and v < vmin then
				in_range = false
			end
			if vmax ~= nil and vmax >= 0 and v > vmax then
				in_range = false
			end
			if exclude_variant ~= nil and v == exclude_variant then
				in_range = false
			end
			if in_range then
				out[#out + 1] = row
			end
		end
	end
	return out
end

--- Weighted pick using RoomConfig.Weight (wiki / STB). Uniform fallback if weights missing.
local function pick_weighted_candidate(pool, rng)
	if not pool or #pool == 0 then
		return nil, nil
	end
	local total = 0
	for _, row in ipairs(pool) do
		local w = tonumber(row.weight) or 1
		if w < 0 then
			w = 0
		end
		total = total + w
	end
	if total <= 0 then
		local idx = rng:RandomInt(#pool) + 1
		return pool[idx], idx
	end
	local roll = 0
	if rng.RandomFloat then
		roll = rng:RandomFloat() * total
	else
		roll = (rng:RandomInt(1000000) / 1000000) * total
	end
	local acc = 0
	for i, row in ipairs(pool) do
		acc = acc + (tonumber(row.weight) or 1)
		if roll <= acc then
			return row, i
		end
	end
	return pool[#pool], #pool
end

local function merge_candidates(room_type, stage_stb, required_doors)
	local seen = {}
	local merged = {}
	local sources = {}
	local function add_list(list, label)
		sources[#sources + 1] = {label = label, count = #list}
		for _, row in ipairs(list) do
			local key = string.format("%s:%s:%s:%s", tostring(row.type), tostring(row.variant), tostring(row.shape), tostring(row.doors))
			if not seen[key] then
				seen[key] = true
				merged[#merged + 1] = row
			end
		end
	end
	if stage_stb then
		add_list(collect_roomset_candidates(stage_stb, room_type, 0, required_doors), "stage:" .. tostring(stage_stb))
	end
	add_list(collect_roomset_candidates(StbType.SPECIAL_ROOMS, room_type, 0, required_doors), "special_rooms")
	return merged, sources
end


local function production_active()
	return compass_state.should_run_callbacks() == true
end

local function session_enabled()
	return production_active() or (cfg.enabled == true)
end

local set_natural_deal_suppress
local set_deal_guarantee
local apply_mode_flags

local compass_floor = {}

function compass_floor.is_fixed_84_variant(variant)
	if corridor_plan_mod.is_fixed_84_variant then
		return corridor_plan_mod.is_fixed_84_variant(variant)
	end
	local v = tonumber(variant)
	return v == ROOM_VARIANT_FIXED_84
		or v == ((corridor_plan_mod.ROOM_VARIANT_WATER_II_84_WHITE_FIRE) or 25606)
end

--- Floors where GC must defer (keep armed appointment; do not consume root_seed).
--- STATE_BACKWARDS_PATH_INIT (photo-door Dad's Note prep) is NOT blocked — boss_pick owns that path.
--- Only formal Ascent (STATE_BACKWARDS_PATH) and greed modes are mode/path blocks here.
function compass_floor.generation_blocked_reason(level_stage, _stage_type)
	local greed = false
	pcall(function()
		greed = Game():IsGreedMode() == true
	end)
	if greed then
		return "greed_mode"
	end
	level_stage = tonumber(level_stage)
	if level_stage == LevelStage.STAGE8 then
		return "home"
	end
	if level_stage == LevelStage.STAGE4_3 then
		return "blue_womb"
	end
	local ascent = false
	pcall(function()
		local game = Game()
		if GameStateFlag and GameStateFlag.STATE_BACKWARDS_PATH
			and game:GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH)
		then
			ascent = true
		end
	end)
	if ascent then
		return "ascent"
	end
	return nil
end

--- Arm Continue-safe Boss@89 encounter from corridor plan (survives pending=nil).
runtime.arm_boss_89_encounter_commit = function(pending, tag)
	local row = pending and pending.corridor_plan and pending.corridor_plan[BOSS_ROOM_SGID]
	if type(row) ~= "table" then
		compass_state.set_boss_89_commit(nil)
		return false, "no_boss_row"
	end
	if row.pool ~= "boss_pool" or row.boss_encounter_pending ~= true then
		compass_state.set_boss_89_commit(nil)
		return false, "not_pending_pool"
	end
	local boss_id = row.boss_id
	if type(boss_id) ~= "string" or boss_id == "" then
		compass_state.set_boss_89_commit(nil)
		return false, "no_boss_id"
	end
	local ok, desc = get_registered_room_desc(BOSS_ROOM_SGID, 0)
	local list_index = desc and desc.ListIndex or nil
	local variant = tonumber(row.variant)
	local subtype = tonumber(row.subtype)
	local room_type = tonumber(row.room_type_actual or row.room_type or RoomType.ROOM_BOSS)
	if ok and desc and desc.Data then
		variant = tonumber(desc.Data.Variant) or variant
		subtype = tonumber(desc.Data.Subtype) or subtype
		room_type = tonumber(desc.Data.Type) or room_type
		list_index = desc.ListIndex
	end
	local token = string.format(
		"%s:%s:%s:%s:%s:%s",
		tostring(pending.root_seed or compass_state.get_root_seed() or ""),
		tostring(pending.restore_stage or ""),
		tostring(pending.restore_stage_type or ""),
		tostring(list_index),
		tostring(variant),
		tostring(boss_id)
	)
	local arm = {
		pending = true,
		boss_id = boss_id,
		stageapi_extension = row.stageapi_extension == true,
		stageapi_boss_id = row.stageapi_boss_id or (row.stageapi_extension and boss_id) or nil,
		token = token,
		root_seed = pending.root_seed or compass_state.get_root_seed(),
		restore_stage = pending.restore_stage,
		restore_stage_type = pending.restore_stage_type,
		list_index = list_index,
		variant = variant,
		subtype = subtype,
		room_type = room_type,
		armed_tag = tag or "layout_ready",
	}
	compass_state.set_boss_89_commit(arm)
	push_event("boss_89_encounter_armed", arm)
	return true, "armed"
end

--- Resolve armed Boss@89 encounter after StageAPI generation and/or enter 89.
--- StageAPI PersistentData.BossID → StageAPI owns. Otherwise GC commits planned boss.
runtime.resolve_boss_89_encounter_commit = function(tag, opts)
	opts = opts or {}
	local arm = compass_state.get_boss_89_commit()
	if type(arm) ~= "table" or arm.pending ~= true then
		return false, "no_armed_commit"
	end
	local guard = runtime.stageapi_layout_guard
		or package.loaded["Qing_Remaster_scripts.items.golden_compass.stageapi_layout_guard"]
	local sa_boss, sa_info = nil, nil
	if type(guard) == "table" and type(guard.get_stageapi_boss_id_at_89) == "function" then
		sa_boss, sa_info = guard.get_stageapi_boss_id_at_89()
	end
	sa_info = sa_info or {}
	-- StageAPI callback may pass boss directly.
	if (not sa_boss or sa_boss == "") and type(opts.boss) == "table" and type(opts.boss.Name) == "string" then
		-- Prefer PersistentData.BossID; Name alone is insufficient identity.
	end
	if type(sa_boss) == "string" and sa_boss ~= "" then
		-- StageAPI owns LevelRoom: still record GC encounter once (Continue-safe token).
		local commit_id = sa_boss
		if type(arm.boss_id) == "string" and arm.boss_id ~= "" then
			-- Prefer planned id when StageAPI id matches / planned was extension.
			if arm.stageapi_extension or sa_boss == arm.boss_id then
				commit_id = arm.boss_id
			end
		end
		local token = arm.token
		if type(token) ~= "string" or token == "" then
			token = string.format(
				"%s:%s:%s:%s:%s:%s",
				tostring(arm.root_seed or ""),
				tostring(arm.restore_stage or ""),
				tostring(arm.restore_stage_type or ""),
				tostring(arm.list_index),
				tostring(arm.variant),
				tostring(commit_id)
			)
		end
		local committed, reason = boss_encounter.commit_bound(commit_id, token)
		arm.pending = false
		arm.owner = "stageapi"
		arm.stageapi_boss_id = sa_boss
		arm.commit_reason = reason
		arm.token = token
		compass_state.set_boss_89_commit(arm)
		push_event("boss_89_encounter_commit", {
			tag = tag or "resolve",
			boss_id = commit_id,
			committed = committed == true,
			reason = reason,
			stageapi_boss_id = sa_boss,
			owner = "stageapi",
			token = token,
		})
		return committed, reason
	end
	-- Planned StageAPI extension must already be bound at layout_ready; do not wait forever.
	if arm.stageapi_extension == true then
		arm.pending = false
		arm.owner = "stageapi_missing"
		arm.commit_reason = "stageapi_bind_missing"
		compass_state.set_boss_89_commit(arm)
		push_event("boss_89_encounter_commit", {
			tag = tag or "resolve",
			boss_id = arm.boss_id,
			committed = false,
			reason = "stageapi_bind_missing",
			sa_info = sa_info,
			owner = "stageapi_missing",
		})
		return false, "stageapi_bind_missing"
	end
	-- StageAPI may still generate this Boss room: wait unless caller forces GC resolve
	-- after POST_STAGEAPI_NEW_ROOM_GENERATION with no BossID.
	local stageapi_loaded = StageAPI ~= nil
	local wait_for_stageapi = stageapi_loaded
		and opts.allow_wait ~= false
		and sa_info.level_room_present == false
		and opts.stageapi_generation_done ~= true
	if wait_for_stageapi then
		push_event("boss_89_encounter_wait", {
			tag = tag or "resolve",
			boss_id = arm.boss_id,
			reason = "await_stageapi_level_room",
			sa_info = sa_info,
		})
		return false, "await_stageapi"
	end
	local ok, desc = get_registered_room_desc(BOSS_ROOM_SGID, 0)
	if not ok or not desc or not desc.Data then
		return false, "desc_missing"
	end
	local data = desc.Data
	if tonumber(data.Variant) ~= tonumber(arm.variant) then
		return false, "variant_mismatch"
	end
	if tonumber(data.Subtype) ~= tonumber(arm.subtype) then
		return false, "subtype_mismatch"
	end
	if arm.room_type and tonumber(data.Type) ~= tonumber(arm.room_type) then
		return false, "type_mismatch"
	end
	local token = arm.token
	if type(token) ~= "string" or token == "" then
		token = string.format(
			"%s:%s:%s:%s:%s:%s",
			tostring(arm.root_seed or ""),
			tostring(arm.restore_stage or ""),
			tostring(arm.restore_stage_type or ""),
			tostring(desc.ListIndex),
			tostring(data.Variant),
			tostring(arm.boss_id)
		)
	end
	local committed, reason = boss_encounter.commit_bound(arm.boss_id, token)
	arm.pending = false
	arm.owner = "golden_compass"
	arm.commit_reason = reason
	arm.token = token
	compass_state.set_boss_89_commit(arm)
	push_event("boss_89_encounter_commit", {
		tag = tag or "resolve",
		boss_id = arm.boss_id,
		committed = committed == true,
		reason = reason,
		token = token,
		list_index = desc.ListIndex,
		variant = data.Variant,
		subtype = data.Subtype,
		owner = "golden_compass",
	})
	return committed, reason
end

-- Bound on runtime (not a new main-chunk local; 200-local limit).
runtime.activate_stageapi_layout_guard = function(pending, tag)
	-- Encounter arm is independent of StageAPI; must survive pending=nil after NEW_LEVEL.
	runtime.arm_boss_89_encounter_commit(pending, tag)
	local guard = runtime.stageapi_layout_guard
		or package.loaded["Qing_Remaster_scripts.items.golden_compass.stageapi_layout_guard"]
	if type(guard) ~= "table" or type(guard.activate_for_pending) ~= "function" then
		push_event("stageapi_layout_guard_skipped", {
			tag = tag,
			reason = "guard_not_pinned",
		})
		return nil
	end
	runtime.stageapi_layout_guard = guard
	if type(guard.set_boss_89_resolve_hook) == "function" then
		guard.set_boss_89_resolve_hook(function(info)
			info = info or {}
			-- Only resolve when generation targets Boss@89 list index (or unknown).
			local arm = compass_state.get_boss_89_commit()
			if type(arm) ~= "table" or arm.pending ~= true then
				return
			end
			if arm.list_index ~= nil and info.list_index ~= nil
				and tonumber(arm.list_index) ~= tonumber(info.list_index)
			then
				return
			end
			runtime.resolve_boss_89_encounter_commit(info.tag or "post_stageapi_new_room_generation", {
				stageapi_generation_done = true,
				allow_wait = false,
				boss = info.boss,
				list_index = info.list_index,
			})
		end)
	end
	local ok, result = pcall(guard.activate_for_pending, pending)
	if not ok then
		push_event("stageapi_layout_guard_error", {
			tag = tag,
			error = tostring(result),
		})
		return nil
	end
	runtime.stageapi_layout_guard_result = result
	if result and result.protected then
		compass_state.set_stageapi_protected(result.protected)
	end
	-- After protected sync: bind StageAPI extension Boss@89 or clear stale LevelRoom.
	local boss_bind = nil
	if type(guard.apply_boss_89_stageapi_ownership) == "function" then
		local bind_ok, bind_ret = pcall(guard.apply_boss_89_stageapi_ownership, pending)
		if bind_ok then
			boss_bind = bind_ret
		else
			boss_bind = {ok = false, reason = "apply_error", error = tostring(bind_ret)}
		end
		if type(result) == "table" then
			result.boss_89_stageapi = boss_bind
		end
		push_event("boss_89_stageapi_ownership", {
			tag = tag,
			boss_bind = boss_bind,
		})
		if compass_floor and compass_floor.notify_stageapi_bind_probe then
			compass_floor.notify_stageapi_bind_probe("boss_89_stageapi_ownership", {
				tag = tag,
				boss_bind = boss_bind,
			})
		end
		if boss_bind and boss_bind.ok == true and boss_bind.action == "bind_extension" then
			runtime.resolve_boss_89_encounter_commit(tag or "stageapi_bind", {
				stageapi_generation_done = true,
				allow_wait = false,
			})
		end
	end
	push_event("stageapi_layout_guard", {
		tag = tag,
		protected = result and result.protected,
		sync = result and result.sync,
		installed = result and result.installed,
		boss_89_stageapi = boss_bind,
	})
	return result
end

runtime.restore_stageapi_layout_guard = function(tag)
	local guard = runtime.stageapi_layout_guard
		or package.loaded["Qing_Remaster_scripts.items.golden_compass.stageapi_layout_guard"]
	if type(guard) ~= "table" then
		return nil
	end
	runtime.stageapi_layout_guard = guard
	if type(guard.set_boss_89_resolve_hook) == "function" then
		guard.set_boss_89_resolve_hook(function(info)
			info = info or {}
			local arm = compass_state.get_boss_89_commit()
			if type(arm) ~= "table" or arm.pending ~= true then
				return
			end
			if arm.list_index ~= nil and info.list_index ~= nil
				and tonumber(arm.list_index) ~= tonumber(info.list_index)
			then
				return
			end
			runtime.resolve_boss_89_encounter_commit(info.tag or "post_stageapi_new_room_generation", {
				stageapi_generation_done = true,
				allow_wait = false,
				boss = info.boss,
				list_index = info.list_index,
			})
		end)
	end
	local rows = compass_state.get_stageapi_protected()
	if type(guard.activate_from_persist) ~= "function" or type(rows) ~= "table" or #rows == 0 then
		if type(guard.ensure_installed) == "function" then
			pcall(guard.ensure_installed)
		end
		return nil
	end
	local ok, result = pcall(guard.activate_from_persist, rows)
	if not ok then
		push_event("stageapi_layout_guard_restore_error", {
			tag = tag,
			error = tostring(result),
		})
		return nil
	end
	runtime.stageapi_layout_guard_result = result
	-- Continue: re-bind StageAPI extension Boss@89 from armed commit (pending may be nil).
	local arm = compass_state.get_boss_89_commit()
	local boss_bind = nil
	if type(arm) == "table"
		and arm.stageapi_extension == true
		and type(guard.bind_extension_boss_at_89) == "function"
	then
		local boss_id = arm.stageapi_boss_id or arm.boss_id
		local pcall_ok, bind_success, bind_info = pcall(guard.bind_extension_boss_at_89, boss_id, {
			seed = arm.root_seed,
		})
		if pcall_ok then
			boss_bind = type(bind_info) == "table" and bind_info or {reason = tostring(bind_info)}
			boss_bind.ok = bind_success == true
			boss_bind.action = "bind_extension_restore"
			if not bind_success and type(guard.clear_boss_89_level_room) == "function" then
				pcall(guard.clear_boss_89_level_room)
				boss_bind.cleared_after_fail = true
			end
		else
			boss_bind = {ok = false, reason = "restore_bind_error", error = tostring(bind_success)}
			if type(guard.clear_boss_89_level_room) == "function" then
				pcall(guard.clear_boss_89_level_room)
			end
		end
		push_event("boss_89_stageapi_ownership", {
			tag = tag or "continue_rebuild",
			boss_bind = boss_bind,
			restore = true,
		})
	elseif type(arm) == "table" and arm.stageapi_extension ~= true and type(guard.clear_boss_89_level_room) == "function" then
		pcall(guard.clear_boss_89_level_room)
	end
	push_event("stageapi_layout_guard_restore", {
		tag = tag,
		protected = result and result.protected,
		sync = result and result.sync,
		boss_89_stageapi = boss_bind,
	})
	return result
end

function compass_floor.snapshot_stageapi_bind(phase, extra)
	local level = Game():GetLevel()
	local ok, desc = get_registered_room_desc(BOSS_ROOM_SGID, 0)
	local dim = 0
	pcall(function()
		if level and level.GetDimension then
			dim = level:GetDimension() or 0
		end
	end)
	local data = desc and desc.Data
	local override = desc and desc.OverrideData
	local level_room = nil
	local level_room_ok = false
	local stageapi_loaded = StageAPI ~= nil
	if stageapi_loaded and StageAPI.GetLevelRoom and desc and desc.ListIndex ~= nil then
		level_room_ok = pcall(function()
			level_room = StageAPI.GetLevelRoom(desc.ListIndex, dim)
		end)
	end
	local plan_row = runtime.pending
		and runtime.pending.corridor_plan
		and runtime.pending.corridor_plan[BOSS_ROOM_SGID]
	local row = {
		phase = phase or "snapshot",
		sgid = BOSS_ROOM_SGID,
		registered = ok == true,
		list_index = desc and desc.ListIndex,
		safe_grid_index = desc and desc.SafeGridIndex,
		dimension = dim,
		has_data = data ~= nil,
		has_override = override ~= nil,
		data_type = data and data.Type,
		data_variant = data and data.Variant,
		data_subtype = data and data.Subtype,
		data_shape = data and data.Shape,
		data_name = data and data.Name,
		data_doors = data and data.Doors,
		override_variant = override and override.Variant,
		override_subtype = override and override.Subtype,
		spawn_seed = desc and desc.SpawnSeed,
		visited = desc and desc.VisitedCount,
		stageapi_loaded = stageapi_loaded,
		stageapi_get_ok = level_room_ok,
		stageapi_level_room = level_room ~= nil,
		stageapi_level_room_type = level_room and type(level_room) or nil,
		plan_boss_id = plan_row and plan_row.boss_id,
		plan_stageapi_extension = plan_row and plan_row.stageapi_extension == true,
		plan_stageapi_boss_id = plan_row and plan_row.stageapi_boss_id,
		plan_selected_source = plan_row and plan_row.selected_source,
		plan_variant = plan_row and plan_row.variant,
		plan_subtype = plan_row and plan_row.subtype,
		plan_pool = plan_row and plan_row.pool,
		pick_pool_summary = plan_row and plan_row.pick_pool_summary,
		layout_ready = runtime.pending and runtime.pending.layout_ready == true,
		layout_phase = runtime.pending and runtime.pending.layout_phase,
		force_stageapi_queued = runtime.force_stageapi_boss_once,
		force_stageapi_pending_any = runtime.pending and runtime.pending.force_stageapi_any == true,
		force_stageapi_pending_id = runtime.pending and runtime.pending.force_stageapi_boss_id,
	}
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			row[k] = v
		end
	end
	return row
end

function compass_floor.notify_stageapi_bind_probe(phase, extra)
	local cb = runtime.stageapi_bind_observer
	if type(cb) ~= "function" then
		return nil
	end
	local snap = compass_floor.snapshot_stageapi_bind(phase, extra)
	pcall(cb, snap)
	return snap
end

function compass_floor.set_stageapi_bind_observer(cb)
	runtime.stageapi_bind_observer = type(cb) == "function" and cb or nil
end

--- Live Level dimension (not SGID alone). Knife puzzle / mines reward = Dim1.
function compass_floor.read_current_dimension()
	local dim = nil
	pcall(function()
		local level = Game():GetLevel()
		if level and level.GetDimension then
			dim = level:GetDimension()
		end
	end)
	if dim ~= nil then
		return tonumber(dim)
	end
	return 0
end

function compass_floor.is_at_mineshaft_reward(sgid, dimension)
	local dim = dimension
	if dim == nil then
		dim = compass_floor.read_current_dimension()
	end
	local dim_knife = (Dimension and Dimension.KNIFE_PUZZLE) or 1
	local reward_sgid = corridor_plan_mod.MINESHAFT_TARGET_SGID or 162
	return tonumber(dim) == tonumber(dim_knife)
		and tonumber(sgid) == tonumber(reward_sgid)
end

--- Entry@78 special door, or Dim1/162 return door. Prefer NEW_ROOM for first create.
function compass_floor.ensure_special_quest_room_doors(tag, sgid)
	if sgid == ENTRY_ROOM_SGID then
		compass_floor.ensure_special_quest_door(tag)
		return
	end
	if compass_floor.is_at_mineshaft_reward(sgid) then
		if compass_floor.ensure_mineshaft_return_door then
			compass_floor.ensure_mineshaft_return_door(tag)
		elseif compass_floor.tick_mirror_door then
			compass_floor.tick_mirror_door(tag)
		end
	end
end

function compass_floor.require_root_seed(tag)
	local root = compass_state.get_root_seed()
	if root and root > 0 then
		return root
	end
	local dbg = cfg.debug_root_seed or compass_state.cache.debug_force_root
	dbg = tonumber(dbg)
	if dbg and dbg > 0 then
		return dbg
	end
	push_event("root_seed_missing", {tag = tag, phase = compass_state.phase()})
	return nil
end

function compass_floor.heaven_light_grid_indices(room)
	local idxs = {}
	pcall(function()
		local ev = EffectVariant and EffectVariant.HEAVEN_LIGHT_DOOR
		if not ev then
			return
		end
		local ents = Isaac.FindByType(EntityType.ENTITY_EFFECT, ev, -1, false, false)
		for _, ent in ipairs(ents) do
			if ent and ent.Position then
				idxs[#idxs + 1] = room:GetGridIndex(ent.Position)
			end
		end
	end)
	return idxs
end

function compass_floor.find_heaven_light_effect(room)
	local found = nil
	pcall(function()
		local ev = EffectVariant and EffectVariant.HEAVEN_LIGHT_DOOR
		if not ev then
			return
		end
		local ents = Isaac.FindByType(EntityType.ENTITY_EFFECT, ev, -1, false, false)
		for _, ent in ipairs(ents) do
			if ent and ent:Exists() then
				found = ent
				break
			end
		end
	end)
	return found
end

--- Womb II: spawn vanilla HEAVEN_LIGHT_DOOR once. avoid_grid_index = trapdoor cell.
--- force_exact: keep preferred_pos (Womb II center-right symmetry; no FindFree drift).
function compass_floor.ensure_boss_89_heaven_light(tag, preferred_pos, avoid_grid_index, force_exact)
	local room = Game():GetRoom()
	local existing = compass_floor.find_heaven_light_effect(room)
	if existing then
		local row = {
			tag = tag,
			ok = true,
			spawned = true,
			already_present = true,
			grid_index = room:GetGridIndex(existing.Position),
			note = "native HEAVEN_LIGHT_DOOR already present; no duplicate",
		}
		local prev = runtime.boss_89_heaven_light
		runtime.boss_89_heaven_light = row
		if not (prev and prev.already_present and prev.grid_index == row.grid_index) then
			push_event("boss_89_heaven_light", row)
		end
		return row
	end
	local pos = preferred_pos or (room:GetCenterPos() + Vector(40, -80))
	local gi = room:GetGridIndex(pos)
	if avoid_grid_index ~= nil and gi == avoid_grid_index then
		pos = force_exact and (room:GetCenterPos() + Vector(40, 0))
			or (room:GetCenterPos() + Vector(80, -80))
		gi = room:GetGridIndex(pos)
	end
	local free_pos = pos
	if force_exact ~= true then
		pcall(function()
			free_pos = room:FindFreePickupSpawnPosition(pos, 0, true)
		end)
		if avoid_grid_index ~= nil then
			local free_gi = room:GetGridIndex(free_pos)
			if free_gi == avoid_grid_index then
				free_pos = pos
			end
		end
	end
	local spawned = nil
	local err = nil
	local ok, ret = pcall(function()
		return Isaac.Spawn(
			EntityType.ENTITY_EFFECT,
			EffectVariant.HEAVEN_LIGHT_DOOR,
			0,
			free_pos,
			Vector.Zero,
			nil
		)
	end)
	if ok then
		spawned = ret
	else
		err = tostring(ret)
	end
	local live = compass_floor.find_heaven_light_effect(room)
	local row = {
		tag = tag,
		ok = live ~= nil,
		spawned = live ~= nil,
		already_present = false,
		preferred_pos = {x = pos.X, y = pos.Y},
		spawn_pos = live and {x = live.Position.X, y = live.Position.Y} or {
			x = free_pos.X,
			y = free_pos.Y,
		},
		grid_index = live and room:GetGridIndex(live.Position) or room:GetGridIndex(free_pos),
		spawn_error = err,
		note = "spawn EffectVariant.HEAVEN_LIGHT_DOOR (vanilla cathedral beam)",
	}
	runtime.boss_89_heaven_light = row
	push_event("boss_89_heaven_light", row)
	return row
end

function compass_floor.derive_placement_seed(sgid, index, domain)
	local root = compass_floor.require_root_seed(domain or "place")
	if not root then
		return nil
	end
	local seed = select(1, compass_rng.derive_seed(root, domain or "try_place", sgid, index or 0))
	return seed
end

function compass_floor.sync_persist()
	if not compass_state.is_active() then
		return
	end
	compass_state.set_floor_persist({
		deal_type = runtime.corridor_deal_type,
		boss_90_entered = runtime.boss_90_entered == true,
		map_settlement_done = runtime.map_settlement_done == true,
		fixed_84_options_spawned = runtime.fixed_84_options_spawned == true,
		fixed_84_choice = runtime.fixed_84_choice,
		fixed_84_item_id = runtime.fixed_84_item_id,
		fixed_84_item_init_seed = runtime.fixed_84_item_init_seed,
		fixed_84_angel_item_id = runtime.fixed_84_angel_item_id,
		fixed_84_angel_item_init_seed = runtime.fixed_84_angel_item_init_seed,
		fixed_84_devil_item_id = runtime.fixed_84_devil_item_id,
		fixed_84_devil_item_init_seed = runtime.fixed_84_devil_item_init_seed,
		fixed_84_chosen_item_init_seed = runtime.fixed_84_chosen_item_init_seed,
		fixed_84_chosen_item_kind = runtime.fixed_84_chosen_item_kind,
		fixed_84_bed_init_seed = runtime.fixed_84_bed_init_seed,
		fixed_84_options_index = tonumber(runtime.fixed_84_options_index),
		mirror_79_knife_piece_spawned = runtime.mirror_79_knife_piece_spawned == true,
		mineshaft_plank_hits = tonumber(runtime.mineshaft_plank_hits) or 0,
		mineshaft_collapsed = runtime.mineshaft_collapsed == true,
		mineshaft_collapse_anim_done = runtime.mineshaft_collapse_anim_done == true,
		force_boss = runtime.corridor_force_boss,
		secret_exit_door = runtime.secret_exit_door_snap,
		deal_appear_sfx_played = runtime.deal_appear_sfx_played == true,
	})
end

function compass_floor.try_finalize(tag)
	if not compass_state.mark_generation_complete() then
		return false
	end
	runtime.corridor_active = true
	cfg.enabled = true
	set_natural_deal_suppress(false)
	set_deal_guarantee(true)
	runtime.block_curses = false
	compass_floor.sync_persist()
	push_event("corridor_active", {
		tag = tag,
		active = true,
		deal_type = runtime.corridor_deal_type,
		force_boss = runtime.corridor_force_boss,
		deal_guarantee = true,
		generation_ok = true,
	})
	if compass_floor.ensure_mineshaft_reward_room then
		local plan = corridor_plan_mod
		local id = read_level_identity and read_level_identity() or nil
		if plan and plan.is_mines_ii and id and plan.is_mines_ii(id.stage, id.stage_type) then
			compass_floor.ensure_mineshaft_reward_room((tag or "finalize") .. "_floor_finalize")
		end
	end
	if compass_floor.maybe_scan_mineshaft_dimension1 then
		compass_floor.maybe_scan_mineshaft_dimension1((tag or "finalize") .. "_floor_finalize", {
			allow_non_mines = false,
		})
	end
	return true
end

function compass_floor.clear_fixed_84_runtime()
	runtime.fixed_84_options_spawned = false
	runtime.fixed_84_choice = nil
	runtime.fixed_84_item_id = nil
	runtime.fixed_84_item_init_seed = nil
	runtime.fixed_84_angel_item_id = nil
	runtime.fixed_84_angel_item_init_seed = nil
	runtime.fixed_84_devil_item_id = nil
	runtime.fixed_84_devil_item_init_seed = nil
	runtime.fixed_84_chosen_item_init_seed = nil
	runtime.fixed_84_chosen_item_kind = nil
	runtime.fixed_84_bed_init_seed = nil
	runtime.fixed_84_options_index = nil
	runtime.fixed_84_sleep_pending_seed = nil
	runtime.fixed_84_sleep_pending_frame = nil
	runtime.fixed_84_content = nil
end

function compass_floor.clear_live(reason)
	runtime.corridor_active = false
	runtime.corridor_deal_type = nil
	runtime.corridor_force_boss = nil
	runtime.boss_90_entered = false
	runtime.map_settlement_done = false
	compass_floor.clear_fixed_84_runtime()
	runtime.mirror_79_knife_piece_spawned = false
	runtime.mineshaft_plank_hits = 0
	runtime.mineshaft_collapsed = false
	runtime.mineshaft_collapse_anim_done = false
	runtime.mineshaft_reward_visited = false
	runtime.mineshaft_boom_seen = {}
	runtime.special_quest_mineshaft_enter = nil
	runtime.special_quest_mineshaft_plank = nil
	runtime.special_quest_mineshaft_planks_visual = nil
	runtime.mineshaft_dim1_scan = nil
	runtime.mineshaft_dim1_scan_summary = nil
	runtime.mineshaft_dim1_scan_fingerprint = nil
	runtime.mineshaft_reward_place = nil
	runtime.negative_rooms = nil
	runtime.deal_door_sprite_watch = nil
	runtime.deal_90_seal_init_done = false
	runtime.secret_exit_door_snap = nil
	runtime.secret_exit_spawn = nil
	runtime.secret_exit_attempted_this_visit = false
	runtime.secret_exit_confirmed_slot = nil
	runtime.secret_exit_spawn_attempts = 0
	runtime.secret_exit_restore_verify = nil
	runtime.secret_exit_restore_consistency = nil
	runtime.secret_exit_persist_hold = false
	runtime.secret_exit_persist_hold_reason = nil
	runtime.special_quest_door = nil
	runtime.special_quest_door_attempted_this_visit = false
	runtime.special_quest_door_attempted_sgid = nil
	runtime.special_quest_force = nil
	runtime.special_quest_mirror_enter = nil
	runtime.special_quest_mirror_prepare = nil
	runtime.special_quest_mirror_corridor = nil
	runtime.mirror_corridor_ready = false
	runtime.special_quest_mirror_interact = nil
	runtime.special_quest_mirror_interact_log = nil
	runtime.special_quest_mirror_interact_emit_frame = nil
	runtime.special_quest_mirror_last_any_losted = nil
	runtime.special_quest_mirror_79_knife = nil
	runtime.continue_current_room_pending = false
	runtime.boss_89_visit_active = false
	runtime.boss_89_visit_init_tag = nil
	runtime.last_corridor_sgid = nil
	runtime.deal_type_source = nil
	runtime.boss_89_heaven_light = nil
	runtime.witness_heart_killed_seen = false
	runtime.witness_secret_enter_sgid = nil
	set_natural_deal_suppress(false)
	set_deal_guarantee(false)
	push_event("corridor_live_cleared", {reason = reason})
end

--- Copy floor business fields from already-authoritative save.elses into runtime.
--- Used by Continue rebuild and POST_REWIND. Never writes back via sync_persist.
function compass_floor.restore_runtime_floor_state(tag)
	local floor = compass_state.get_floor_persist() or {}
	runtime.corridor_deal_type = floor.deal_type
	runtime.deal_type_source = floor.deal_type and ((tag and tostring(tag):find("rewind", 1, true)) and "persist_floor_rewind" or "persist_floor") or nil
	runtime.corridor_force_boss = floor.force_boss
	runtime.boss_90_entered = floor.boss_90_entered == true
	runtime.map_settlement_done = floor.map_settlement_done == true
	runtime.fixed_84_options_spawned = floor.fixed_84_options_spawned == true
	do
		local c = floor.fixed_84_choice
		runtime.fixed_84_choice = (c == "rest" or c == "item") and c or nil
	end
	runtime.fixed_84_item_id = tonumber(floor.fixed_84_item_id)
	runtime.fixed_84_item_init_seed = tonumber(floor.fixed_84_item_init_seed)
	runtime.fixed_84_angel_item_id = tonumber(floor.fixed_84_angel_item_id)
	runtime.fixed_84_angel_item_init_seed = tonumber(floor.fixed_84_angel_item_init_seed)
	runtime.fixed_84_devil_item_id = tonumber(floor.fixed_84_devil_item_id)
	runtime.fixed_84_devil_item_init_seed = tonumber(floor.fixed_84_devil_item_init_seed)
	runtime.fixed_84_chosen_item_init_seed = tonumber(floor.fixed_84_chosen_item_init_seed)
	do
		local k = floor.fixed_84_chosen_item_kind
		runtime.fixed_84_chosen_item_kind = (k == "treasure" or k == "angel" or k == "devil" or k == "item") and k or nil
	end
	runtime.fixed_84_bed_init_seed = tonumber(floor.fixed_84_bed_init_seed)
	runtime.fixed_84_options_index = tonumber(floor.fixed_84_options_index)
	runtime.mirror_79_knife_piece_spawned = floor.mirror_79_knife_piece_spawned == true
	runtime.mom_photo_reward_done = floor.mom_photo_reward_done == true
	runtime.deal_appear_sfx_played = floor.deal_appear_sfx_played == true
	runtime.mineshaft_plank_hits = tonumber(floor.mineshaft_plank_hits) or 0
	runtime.mineshaft_collapsed = floor.mineshaft_collapsed == true
	runtime.mineshaft_collapse_anim_done = floor.mineshaft_collapse_anim_done == true
	runtime.secret_exit_door_snap = floor.secret_exit_door
	return floor
end

--- Visit / frame / one-shot derived caches that must not survive Hourglass / rewind.
function compass_floor.clear_rewind_transient_caches(tag)
	runtime.mineshaft_boom_seen = {}
	runtime.secret_exit_attempted_this_visit = false
	runtime.special_quest_door_attempted_this_visit = false
	runtime.special_quest_door_attempted_sgid = nil
	runtime.boss_89_visit_active = false
	runtime.boss_89_visit_init_tag = nil
	runtime.boss_89_trapdoor_pending_retry = nil
	runtime.boss_89_timed_door = nil
	runtime.timed_door_strange_key_seen = false
	runtime.boss_89_visit_had_combat = false
	runtime.boss_90_clear_logged = false
	runtime.boss_90_clear = nil
	runtime.boss_90_combat = nil
	runtime.boss_90_enter = nil
	runtime.deal_door_sprite_watch = nil
	runtime.deal_appear_sfx_logged = false
	runtime.mirror_corridor_ready = false
	runtime.special_quest_mirror_corridor = nil
	runtime.special_quest_mirror_prepare = nil
	runtime.special_quest_mirror_enter = nil
	runtime.special_quest_mirror_interact = nil
	runtime.special_quest_mirror_interact_log = nil
	runtime.special_quest_mirror_interact_emit_frame = nil
	runtime.special_quest_mirror_last_any_losted = nil
	runtime.fixed_84_content = nil
	runtime.fixed_84_sleep_pending_seed = nil
	runtime.fixed_84_sleep_pending_frame = nil
	runtime.continue_current_room_pending = false
	push_event("corridor_rewind_transient_cleared", {tag = tag})
end

--- After save.elses already rolled back: resync runtime mirrors, drop future caches.
--- Do not call sync_persist here (would rewrite history from stale runtime).
function compass_floor.on_post_rewind(kind, desc)
	local phase = compass_state.phase()
	local tag = "post_rewind_" .. tostring(kind or "unknown")
	if phase == "idle" or phase == "failed" then
		runtime.corridor_active = false
		cfg.enabled = false
		runtime.identity_restored_seen = false
		compass_floor.clear_rewind_transient_caches(tag)
		push_event("corridor_post_rewind", {
			tag = tag,
			phase = phase,
			active = false,
			kind = kind,
			desc = desc,
		})
		return
	end
	if phase == "armed" or phase == "generating" then
		runtime.corridor_active = false
		runtime.identity_restored_seen = false
		cfg.enabled = true
		compass_floor.clear_rewind_transient_caches(tag)
		push_event("corridor_post_rewind", {
			tag = tag,
			phase = phase,
			active = false,
			kind = kind,
			desc = desc,
		})
		return
	end
	-- phase == active: business fields already in save.elses; refresh runtime copy only.
	compass_floor.restore_runtime_floor_state(tag)
	runtime.corridor_active = true
	runtime.identity_restored_seen = true
	cfg.enabled = true
	set_natural_deal_suppress(false)
	set_deal_guarantee(true)
	runtime.block_curses = false
	compass_floor.clear_rewind_transient_caches(tag)
	pcall(function()
		local level = Game():GetLevel()
		if level.HasMirrorDimension and level:HasMirrorDimension() == true
			and compass_floor.prepare_mirror_corridor
		then
			compass_floor.prepare_mirror_corridor(tag .. "_mirror_validate")
		end
	end)
	push_event("corridor_post_rewind", {
		tag = tag,
		phase = phase,
		active = true,
		kind = kind,
		fixed_84_options_spawned = runtime.fixed_84_options_spawned,
		fixed_84_choice = runtime.fixed_84_choice,
		boss_90_entered = runtime.boss_90_entered,
		map_settlement_done = runtime.map_settlement_done,
		mirror_79_knife_piece_spawned = runtime.mirror_79_knife_piece_spawned,
		mineshaft_collapsed = runtime.mineshaft_collapsed,
		mom_photo_reward_done = runtime.mom_photo_reward_done,
		deal_appear_sfx_played = runtime.deal_appear_sfx_played,
	})
end

function compass_floor.rebuild_from_persist(tag)
	local phase = compass_state.phase()
	if phase == "idle" or phase == "failed" then
		runtime.corridor_active = false
		cfg.enabled = false
		runtime.identity_restored_seen = false
		runtime.continue_current_room_pending = false
		return
	end
	cfg.enabled = true
	if phase == "armed" or phase == "generating" then
		runtime.corridor_active = false
		runtime.identity_restored_seen = false
		runtime.continue_current_room_pending = false
		if phase == "armed" then
			-- Floor eligibility (Home/???/Ascent defer) is decided in MC_PRE_LEVEL_SELECT.
			cfg.arm_home_layout = false
			apply_mode_flags("main")
		end
		push_event("continue_rebuild", {tag = tag, phase = phase, active = false})
		return
	end
	-- active: restore floor business flags; doors/map rebuild from live rooms.
	-- identity_restored_seen = layout/identity already done → allow normal POST_NEW_ROOM enter handling.
	compass_floor.restore_runtime_floor_state(tag or "continue_rebuild")
	runtime.corridor_active = true
	runtime.identity_restored_seen = true
	runtime.mineshaft_boom_seen = {}
	-- Visit-scoped flags must NOT be treated as still in-progress across Continue.
	runtime.secret_exit_attempted_this_visit = false
	runtime.special_quest_door_attempted_this_visit = false
	runtime.special_quest_door_attempted_sgid = nil
	runtime.boss_89_visit_active = false
	runtime.boss_89_visit_init_tag = nil
	runtime.boss_89_trapdoor_pending_retry = nil
	runtime.boss_89_timed_door = nil
	runtime.timed_door_strange_key_seen = false
	runtime.continue_current_room_pending = true
	set_natural_deal_suppress(false)
	set_deal_guarantee(true)
	runtime.block_curses = false
	-- Restore StageAPI fixed-room protection indices (module memory is empty after reload).
	if runtime.restore_stageapi_layout_guard then
		runtime.restore_stageapi_layout_guard(tag or "continue_rebuild")
	end
	-- Validate / repair knife-dimension corridor registration before gameplay callbacks.
	-- Does not wipe visited rooms; only places missing or unregistered cells.
	pcall(function()
		local level = Game():GetLevel()
		if level.HasMirrorDimension and level:HasMirrorDimension() == true
			and compass_floor.prepare_mirror_corridor
		then
			compass_floor.prepare_mirror_corridor((tag or "continue") .. "_mirror_validate")
		end
	end)
	local id = read_level_identity()
	push_event("continue_rebuild", {
		tag = tag,
		phase = phase,
		active = true,
		identity_restored_seen = true,
		deal_type = runtime.corridor_deal_type,
		deal_type_source = runtime.deal_type_source,
		boss_90_entered = runtime.boss_90_entered,
		map_settlement_done = runtime.map_settlement_done,
		fixed_84_options_spawned = runtime.fixed_84_options_spawned,
		fixed_84_choice = runtime.fixed_84_choice,
		mirror_79_knife_piece_spawned = runtime.mirror_79_knife_piece_spawned,
		current_sgid = id.current_room_index,
		continue_current_room_pending = true,
		next_root = compass_state.get_next_root_seed(),
	})
	-- Room object may already be ready on Continue; otherwise first POST_UPDATE drains the pending.
	if compass_floor.maybe_init_continue_current_room then
		compass_floor.maybe_init_continue_current_room(tag)
	end
end

function compass_floor.snapshot_special_door(door)
	if not door then
		return nil
	end
	local snap = {
		open = false,
		locked = nil,
		busted = nil,
		can_blow_open = nil,
		state = nil,
		previous_state = nil,
		var_data = nil,
		previous_variant = nil,
		extra_visible = nil,
		main_animation = nil,
		main_frame = nil,
		main_filename = nil,
		main_playing = nil,
		main_finished = nil,
		extra_animation = nil,
		extra_frame = nil,
		extra_filename = nil,
		extra_playing = nil,
		extra_finished = nil,
		save_state = nil,
		save_var_data = nil,
		save_variant = nil,
		target_room_index = nil,
		target_room_type = nil,
		current_room_type = nil,
		variant = nil,
	}
	pcall(function() snap.open = door:IsOpen() == true end)
	pcall(function() snap.locked = door:IsLocked() end)
	pcall(function() snap.busted = door:IsBusted() end)
	pcall(function()
		if door.CanBlowOpen then
			snap.can_blow_open = door:CanBlowOpen()
		end
	end)
	pcall(function() snap.state = door.State end)
	pcall(function() snap.previous_state = door.PreviousState end)
	pcall(function() snap.var_data = door.VarData end)
	pcall(function() snap.previous_variant = door.PreviousVariant end)
	pcall(function() snap.extra_visible = door.ExtraVisible end)
	pcall(function() snap.target_room_index = door.TargetRoomIndex end)
	pcall(function() snap.target_room_type = door.TargetRoomType end)
	pcall(function() snap.current_room_type = door.CurrentRoomType end)
	pcall(function() snap.variant = door.Variant end)
	pcall(function()
		local main = door:GetSprite()
		if main then
			if main.GetAnimation then snap.main_animation = main:GetAnimation() end
			if main.GetFrame then snap.main_frame = main:GetFrame() end
			if main.GetFilename then snap.main_filename = main:GetFilename() end
			if main.IsPlaying then snap.main_playing = main:IsPlaying() end
			if main.IsFinished then
				if snap.main_animation then
					snap.main_finished = main:IsFinished(snap.main_animation)
				else
					snap.main_finished = main:IsFinished()
				end
			end
		end
	end)
	pcall(function()
		local extra = door.GetExtraSprite and door:GetExtraSprite() or door.ExtraSprite
		if extra then
			if extra.GetAnimation then snap.extra_animation = extra:GetAnimation() end
			if extra.GetFrame then snap.extra_frame = extra:GetFrame() end
			if extra.GetFilename then snap.extra_filename = extra:GetFilename() end
			if extra.IsPlaying then snap.extra_playing = extra:IsPlaying() end
			if extra.IsFinished then
				if snap.extra_animation then
					snap.extra_finished = extra:IsFinished(snap.extra_animation)
				else
					snap.extra_finished = extra:IsFinished()
				end
			end
		end
	end)
	pcall(function()
		local desc = door:GetSaveState()
		if desc then
			snap.save_state = desc.State
			snap.save_var_data = desc.VarData
			snap.save_variant = desc.Variant
		end
	end)
	-- Inferred payment hint only — not a verified native counter.
	snap.progress_inferred = true
	local st = tonumber(snap.state)
	local one_chain = (DoorState and DoorState.STATE_ONE_CHAIN) or 3
	local half_crack = (DoorState and DoorState.STATE_HALF_CRACKED) or 4
	local open_st = (DoorState and DoorState.STATE_OPEN) or 2
	local closed_st = (DoorState and DoorState.STATE_CLOSED) or 1
	local fn = tostring(snap.main_filename or ""):lower()
	local is_mausoleum_door = fn:find("mausoleum", 1, true) ~= nil
	if snap.open or st == open_st then
		snap.progress = 2
	elseif is_mausoleum_door then
		-- Mausoleum: unpaid State=1/VarData=1; one pay State=3/VarData=0 (VarData=1 is NOT partial).
		if st == one_chain then
			snap.progress = 1
		else
			snap.progress = 0
		end
	elseif st == half_crack or st == one_chain then
		snap.progress = 1
	elseif snap.extra_visible == false and (snap.busted or snap.var_data and tonumber(snap.var_data) > 0) then
		snap.progress = 1
	elseif snap.var_data and tonumber(snap.var_data) >= 2 then
		snap.progress = 2
	elseif snap.var_data and tonumber(snap.var_data) == 1 and st ~= closed_st then
		snap.progress = 1
	else
		snap.progress = 0
	end
	return snap
end

local special_quest_doors = require("Qing_Remaster_scripts.items.golden_compass.special_quest_doors")
special_quest_doors.install({
	runtime = runtime,
	compass_floor = compass_floor,
	corridor_plan = corridor_plan_mod,
	read_level_identity = read_level_identity,
	push_event = push_event,
	entry_sgid = ENTRY_ROOM_SGID,
	snapshot_special_door = function(door)
		return compass_floor.snapshot_special_door(door)
	end,
	grid_door = grid_door,
	Room_holder = Room_holder,
	write_desc_config = function(desc, cfg, cur, expect_sgid)
		return write_desc_config(desc, cfg, cur, expect_sgid)
	end,
	init_desc_runtime = function(desc, opts)
		return init_desc_runtime(desc, opts)
	end,
	require_root_seed = function(tag)
		return compass_floor.require_root_seed(tag)
	end,
	derive_seed = function(root, domain, sgid, index)
		return select(1, compass_rng.derive_seed(root, domain, sgid, index))
	end,
})

function compass_floor.is_mausoleum_ii_alt(stage, stage_type)
	stage = tonumber(stage)
	stage_type = tonumber(stage_type)
	if stage ~= LevelStage.STAGE3_2 then
		return false
	end
	local st_rep = StageType and StageType.STAGETYPE_REPENTANCE
	local st_rep_b = StageType and StageType.STAGETYPE_REPENTANCE_B
	return (st_rep ~= nil and stage_type == st_rep)
		or (st_rep_b ~= nil and stage_type == st_rep_b)
end

function compass_floor.is_backwards_path_init()
	local on = false
	pcall(function()
		if GameStateFlag and GameStateFlag.STATE_BACKWARDS_PATH_INIT then
			on = Game():GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT) == true
		end
	end)
	return on
end

function compass_floor.snapshot_witness_route(tag)
	local game = Game()
	local level = game:GetLevel()
	local room = game:GetRoom()
	local cur = level:GetCurrentRoomDesc()
	local secret_idx = SECRET_EXIT_IDX
	local secret_desc = nil
	pcall(function()
		secret_desc = level:GetRoomByIdx(secret_idx, 0)
	end)
	local secret = {
		idx = secret_idx,
		has_desc = secret_desc ~= nil,
		safe_grid_index = secret_desc and secret_desc.SafeGridIndex or nil,
		visited = secret_desc and secret_desc.VisitedCount or nil,
		clear = secret_desc and secret_desc.Clear or nil,
		flags = secret_desc and secret_desc.Flags or nil,
		spawn_seed = secret_desc and secret_desc.SpawnSeed or nil,
		decoration_seed = secret_desc and secret_desc.DecorationSeed or nil,
		award_seed = secret_desc and secret_desc.AwardSeed or nil,
	}
	pcall(function()
		local data = secret_desc and secret_desc.Data
		if data then
			secret.type = data.Type
			secret.variant = data.Variant
			secret.subtype = data.Subtype
			secret.shape = data.Shape
			secret.name = data.Name
			secret.doors = data.Doors
		end
	end)
	local doors = {}
	pcall(function()
		local n = (DoorSlot and DoorSlot.NUM_DOOR_SLOTS) or 8
		for slot = 0, n - 1 do
			local door = room:GetDoor(slot)
			if door then
				local row = {
					slot = slot,
					target_index = door.TargetRoomIndex,
					target_type = door.TargetRoomType,
					current_type = door.CurrentRoomType,
					variant = door.Variant,
					state = door.State,
					var_data = door.VarData,
					open = door:IsOpen(),
					locked = door:IsLocked(),
					busted = door.IsBusted and door:IsBusted() or nil,
					extra_visible = door.ExtraVisible,
				}
				pcall(function()
					local spr = door:GetSprite()
					if spr then
						row.main_animation = spr.GetAnimation and spr:GetAnimation() or nil
						row.main_frame = spr.GetFrame and spr:GetFrame() or nil
						row.main_filename = spr.GetFilename and spr:GetFilename() or nil
					end
				end)
				pcall(function()
					local extra = door.GetExtraSprite and door:GetExtraSprite() or door.ExtraSprite
					if extra then
						row.extra_animation = extra.GetAnimation and extra:GetAnimation() or nil
						row.extra_frame = extra.GetFrame and extra:GetFrame() or nil
						row.extra_filename = extra.GetFilename and extra:GetFilename() or nil
					end
				end)
				doors[#doors + 1] = row
			end
		end
	end)
	local heart_killed = nil
	local flesh_opened = nil
	local backwards_init = nil
	local backwards_path = nil
	pcall(function()
		if GameStateFlag and GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED then
			heart_killed = game:GetStateFlag(GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED)
		end
	end)
	pcall(function()
		if GameStateFlag and GameStateFlag.STATE_MOTHER_HEART_DOOR_OPENED then
			flesh_opened = game:GetStateFlag(GameStateFlag.STATE_MOTHER_HEART_DOOR_OPENED)
		end
	end)
	pcall(function()
		if GameStateFlag and GameStateFlag.STATE_BACKWARDS_PATH_INIT then
			backwards_init = game:GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT)
		end
	end)
	pcall(function()
		if GameStateFlag and GameStateFlag.STATE_BACKWARDS_PATH then
			backwards_path = game:GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH)
		end
	end)
	local boss_id = nil
	pcall(function()
		if room.GetBossID then
			boss_id = room:GetBossID()
		end
	end)
	local npc_count = 0
	local npc_sample = {}
	pcall(function()
		local ents = Isaac.GetRoomEntities()
		for _, ent in ipairs(ents) do
			if ent and ent:IsActiveEnemy(false) then
				npc_count = npc_count + 1
				if #npc_sample < 8 then
					npc_sample[#npc_sample + 1] = {
						type = ent.Type,
						variant = ent.Variant,
						subtype = ent.SubType,
					}
				end
			end
		end
	end)
	local heart_target_ok = corridor_plan_mod.is_mausoleum_heart_target_cfg
		and corridor_plan_mod.is_mausoleum_heart_target_cfg(secret)
	local snap = {
		tag = tag,
		stage = level:GetStage(),
		stage_type = level:GetStageType(),
		current_sgid = cur and cur.SafeGridIndex or nil,
		room_clear = room:IsClear() == true,
		boss_id = boss_id,
		npc_count = npc_count,
		npc_sample = npc_sample,
		heart_killed = heart_killed,
		flesh_door_opened = flesh_opened,
		backwards_path_init = backwards_init,
		backwards_path = backwards_path,
		secret_desc = secret,
		heart_target_ok = heart_target_ok == true,
		doors = doors,
		witness_test = cfg.witness_mausoleum_test == true,
		force_boss_subtype = runtime.corridor_force_boss
			or (runtime.pending and runtime.pending.force_boss_subtype)
			or nil,
		rule = compass_floor.resolve_secret_exit_rule(),
	}
	runtime.witness_last_snapshot = snap
	push_event("witness_mausoleum_snapshot", snap)
	return snap
end

--- Dad's Note path replaces Mom when STATE_BACKWARDS_PATH_INIT is set.
function compass_floor.clear_backwards_path_init(reason)
	local before = nil
	local after = nil
	local cleared = false
	pcall(function()
		if not (GameStateFlag and GameStateFlag.STATE_BACKWARDS_PATH_INIT) then
			return
		end
		local game = Game()
		before = game:GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT)
		if before then
			game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT, false)
			cleared = true
		end
		after = game:GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT)
	end)
	local row = {
		reason = reason,
		before = before,
		after = after,
		cleared = cleared,
	}
	push_event("backwards_path_init_clear", row)
	return row
end

--- Manual Soft/Force probe for Mom's Heart flesh door (same API as formal Soft→Force).
function compass_floor.try_spawn_witness_secret_exit(tag, force)
	local room = Game():GetRoom()
	local before = compass_floor.snapshot_witness_route((tag or "witness") .. ":before")
	local secret_snap = before and before.secret_desc
	local heart_ok = corridor_plan_mod.is_mausoleum_heart_target_cfg
		and corridor_plan_mod.is_mausoleum_heart_target_cfg(secret_snap)
	compass_floor.notify_secret_exit_door_observer("before_try_spawn", {
		tag = tag,
		door = compass_floor.snapshot_secret_exit_door_probe(tag),
		spawn_meta = compass_floor.secret_exit_spawn_meta(),
		note = force and "manual TrySpawnSecretExit(Force)" or "manual TrySpawnSecretExit(soft)",
	})
	local spawned, err, animate = compass_floor.call_try_spawn_secret_exit(room, force == true)
	local after = compass_floor.snapshot_witness_route((tag or "witness") .. ":after")
	local present, slot = compass_floor.room_has_secret_exit_door(room)
	local row = {
		tag = tag,
		ok = present == true or spawned == true,
		spawned = spawned,
		force = force == true,
		animate = animate,
		live_present = present == true,
		slot = slot,
		error = err,
		before = before,
		after = after,
		heart_target_ok = heart_ok == true,
		api = "TrySpawnSecretExit",
		note = "manual "
			.. (force and "Force" or "soft")
			.. "; presence="
			.. tostring(present)
			.. " heart_target_ok="
			.. tostring(heart_ok),
	}
	runtime.secret_exit_spawn = row
	push_event("witness_mausoleum_try_spawn", row)
	compass_floor.notify_secret_exit_door_observer("after_try_spawn", {
		tag = tag,
		door = compass_floor.snapshot_secret_exit_door_probe(tag),
		spawn_meta = compass_floor.secret_exit_spawn_meta(),
		note = row.note,
	})
	return row
end

function compass_floor.tick_witness_mausoleum(tag)
	if not cfg.witness_mausoleum_test then
		return
	end
	local id = read_level_identity()
	if not compass_floor.is_mausoleum_ii_alt(id.stage, id.stage_type) then
		return
	end
	local heart = false
	pcall(function()
		if GameStateFlag and GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED then
			heart = Game():GetStateFlag(GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED) == true
		end
	end)
	if heart and not runtime.witness_heart_killed_seen then
		runtime.witness_heart_killed_seen = true
		compass_floor.snapshot_witness_route((tag or "witness") .. ":heart_killed")
	end
	local cur = Game():GetLevel():GetCurrentRoomDesc()
	local sgid = cur and cur.SafeGridIndex
	if sgid == SECRET_EXIT_IDX then
		-- Entering flesh/secret room: one snapshot per enter wave.
		if runtime.witness_secret_enter_sgid ~= sgid then
			runtime.witness_secret_enter_sgid = sgid
			compass_floor.snapshot_witness_route((tag or "witness") .. ":enter_secret")
		end
	elseif runtime.witness_secret_enter_sgid ~= nil then
		runtime.witness_secret_enter_sgid = nil
	end
end

local function make_sgid_rng(root_seed, sgid, domain)
	local rng, seed, err = compass_rng.make_rng(root_seed, domain or "runtime_room", sgid, 0)
	if not rng then
		error("golden_compass.runtime: " .. tostring(err or "rng_failed"))
	end
	return rng, seed
end

local function filter_prefer_doors(candidates, prefer_doors)
	if not prefer_doors or prefer_doors == 0 or #candidates == 0 then
		return candidates
	end
	local preferred = {}
	for _, row in ipairs(candidates) do
		local doors = row.doors or 0
		if (doors & prefer_doors) == prefer_doors then
			preferred[#preferred + 1] = row
		end
	end
	if #preferred > 0 then
		return preferred
	end
	return candidates
end

local function pick_special_room_config(asg, stage_stb, base_seed)
	local required = asg.required_doors or DOOR_MASK_FOUR
	local prefer = asg.prefer_doors or required
	local variant_min = asg.variant_min
	local variant_max = asg.variant_max
	local exclude_variant = asg.exclude_variant
	local use_weight = asg.weighted == true
	local candidates, sources = merge_candidates(asg.room_type, stage_stb, required)
	local ranged = filter_variant_range(candidates, variant_min, variant_max, exclude_variant)
	-- If exclude emptied the band, retry band without exclude (same layout allowed).
	local exclude_relaxed = false
	if #ranged == 0 and exclude_variant ~= nil then
		ranged = filter_variant_range(candidates, variant_min, variant_max, nil)
		exclude_relaxed = #ranged > 0
	end
	local pool = filter_prefer_doors(ranged, prefer)
	local rng, rng_seed = make_sgid_rng(base_seed, asg.sgid)
	local row = {
		sgid = asg.sgid,
		room_type = asg.room_type,
		pool = asg.pool,
		stage_stb = stage_stb,
		required_doors = required,
		prefer_doors = prefer,
		variant_min = variant_min,
		variant_max = variant_max,
		exclude_variant = exclude_variant,
		exclude_relaxed = exclude_relaxed,
		weighted = use_weight,
		candidate_count = #candidates,
		ranged_count = #ranged,
		prefer_count = #pool,
		sources = sources,
		rng_seed = rng_seed,
		fallback = false,
	}
	if #pool > 0 then
		local chosen, idx
		if use_weight then
			chosen, idx = pick_weighted_candidate(pool, rng)
			row.via = "roomset_weighted"
		else
			idx = rng:RandomInt(#pool) + 1
			chosen = pool[idx]
			row.via = (#pool < #ranged) and "roomset_prefer" or "roomset"
		end
		row.cfg = chosen.cfg
		row.variant = chosen.variant
		row.shape = chosen.shape
		row.doors = chosen.doors
		row.weight = chosen.weight
		row.source_stb = chosen.stb
		row.pick_index = idx
		if asg.room_type == RoomType.ROOM_CURSE then
			row.curse_band = is_voodoo_curse_layout(chosen.cfg) and "voodoo_31_40"
				or (is_normal_curse_layout(chosen.cfg) and "normal_0_30" or "other")
		end
		return row
	end
	-- Secondary: GetRandomRoom with RequiredDoors + optional variant band.
	local holder = room_config_holder()
	local try_stbs = {}
	if stage_stb then
		try_stbs[#try_stbs + 1] = stage_stb
	end
	try_stbs[#try_stbs + 1] = StbType.SPECIAL_ROOMS
	local min_v = variant_min or 0
	local max_v = (variant_max == nil) and -1 or variant_max
	if holder and holder.GetRandomRoom then
		for _, stb in ipairs(try_stbs) do
			local cfg = nil
			local ok = pcall(function()
				cfg = holder.GetRandomRoom(
					rng_seed,
					false,
					stb,
					asg.room_type,
					SHAPE_1X1,
					min_v,
					max_v,
					0,
					10,
					required,
					-1,
					0
				)
			end)
			local doors_ok = ok and cfg and cfg.Shape == SHAPE_1X1
				and ((cfg.Doors or 0) & required) == required
			local band_ok = true
			if doors_ok and (variant_min ~= nil or variant_max ~= nil) then
				local v = tonumber(cfg.Variant) or -1
				if variant_min ~= nil and v < variant_min then
					band_ok = false
				end
				if variant_max ~= nil and variant_max >= 0 and v > variant_max then
					band_ok = false
				end
				if exclude_variant ~= nil and v == exclude_variant and not exclude_relaxed then
					band_ok = false
				end
			end
			if doors_ok and band_ok then
				row.cfg = cfg
				row.variant = cfg.Variant
				row.shape = cfg.Shape
				row.doors = cfg.Doors
				row.source_stb = stb
				row.via = "GetRandomRoom"
				if asg.room_type == RoomType.ROOM_CURSE then
					row.curse_band = is_voodoo_curse_layout(cfg) and "voodoo_31_40"
						or (is_normal_curse_layout(cfg) and "normal_0_30" or "other")
				end
				return row
			end
		end
	end
	-- Tertiary fallback: fixed 25601 secret terrain (probe-safe empty layout).
	-- Curse rooms: do not silently substitute secret terrain; leave missing.
	if asg.room_type == RoomType.ROOM_CURSE then
		row.fallback = true
		row.error = "no_curse_layout_in_band"
		row.via = "missing_curse_band"
		return row
	end
	local fb = get_room_config(RoomType.ROOM_SECRET, ROOM_VARIANT_SECRET_TERRAIN)
	row.cfg = fb
	row.fallback = true
	row.variant = ROOM_VARIANT_SECRET_TERRAIN
	row.shape = fb and fb.Shape or SHAPE_1X1
	row.doors = fb and fb.Doors or nil
	row.source_stb = StbType.SPECIAL_ROOMS
	row.via = "fallback_25601"
	row.room_type_actual = RoomType.ROOM_SECRET
	return row
end

--- Voodoo Head (巫毒头): EID "额外诅咒房" / additional Curse Room each floor.
local function player_has_voodoo_head()
	local has = false
	pcall(function()
		if PlayerManager and PlayerManager.AnyoneHasCollectible then
			has = PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_VOODOO_HEAD) == true
		end
	end)
	return has
end

local function build_special_room_plan(pending)
	local stage = pending and pending.restore_stage
	local stage_type = pending and pending.restore_stage_type
	local stage_stb = level_stage_to_stb(stage, stage_type)
	local base_seed = compass_floor.require_root_seed("plan")
	if not base_seed then
		return nil
	end
	local plan = {}
	local summary = {}
	local function add_asg(asg)
		local row = pick_special_room_config(asg, stage_stb, base_seed)
		plan[asg.sgid] = row
		summary[#summary + 1] = {
			sgid = row.sgid,
			room_type = row.room_type,
			pool = row.pool,
			source_stb = row.source_stb,
			variant = row.variant,
			shape = row.shape,
			doors = row.doors,
			weight = row.weight,
			required_doors = row.required_doors,
			prefer_doors = row.prefer_doors,
			variant_min = row.variant_min,
			variant_max = row.variant_max,
			curse_band = row.curse_band,
			candidate_count = row.candidate_count,
			ranged_count = row.ranged_count,
			prefer_count = row.prefer_count,
			fallback = row.fallback == true,
			via = row.via,
			error = row.error,
			stage_stb = stage_stb,
			restore_stage = stage,
			restore_stage_type = stage_type,
		}
		return row
	end
	for _, asg in ipairs(SPECIAL_ROOM_ASSIGNMENTS) do
		add_asg(asg)
	end

	-- Curse rooms: normal 0–30 vs Voodoo Head enhanced 31–40 (wiki exclusive layouts).
	local voodoo = player_has_voodoo_head()
	pending.curse_72_wanted = voodoo
	local asg98 = {
		sgid = ROOM_98_SGID,
		room_type = RoomType.ROOM_CURSE,
		pool = voodoo and "curse_voodoo" or "curse",
		required_doors = DOOR_MASK_UP_LEFT,
		prefer_doors = DOOR_MASK_FOUR,
		weighted = true,
		variant_min = voodoo and CURSE_VARIANT_VOODOO_MIN or 0,
		variant_max = voodoo and CURSE_VARIANT_VOODOO_MAX or CURSE_VARIANT_NORMAL_MAX,
	}
	local curse98_row = add_asg(asg98)
	curse98_row.voodoo_head = voodoo
	curse98_row.kind = "curse_98"

	local curse72_row = nil
	if voodoo then
		local asg72 = {
			sgid = ROOM_72_SGID,
			room_type = RoomType.ROOM_CURSE,
			pool = "curse_voodoo",
			required_doors = DOOR_MASK_DOWN,
			prefer_doors = DOOR_MASK_FOUR,
			weighted = true,
			variant_min = CURSE_VARIANT_VOODOO_MIN,
			variant_max = CURSE_VARIANT_VOODOO_MAX,
			-- Prefer a different enhanced layout than 98 when possible.
			exclude_variant = curse98_row and curse98_row.variant or nil,
		}
		curse72_row = add_asg(asg72)
		curse72_row.voodoo_head = true
		curse72_row.kind = "curse_72"
		curse72_row.paired_98_variant = curse98_row and curse98_row.variant
		curse72_row.distinct_from_98 = curse72_row.variant ~= nil
			and curse98_row
			and curse72_row.variant ~= curse98_row.variant
	end

	runtime.curse_72_plan = {
		wanted = voodoo,
		sgid = ROOM_72_SGID,
		voodoo_head = voodoo,
		curse_98 = curse98_row and {
			variant = curse98_row.variant,
			doors = curse98_row.doors,
			weight = curse98_row.weight,
			curse_band = curse98_row.curse_band,
			via = curse98_row.via,
			cfg_ok = curse98_row.cfg ~= nil,
		} or nil,
		row = curse72_row and {
			variant = curse72_row.variant,
			doors = curse72_row.doors,
			weight = curse72_row.weight,
			required_doors = curse72_row.required_doors,
			curse_band = curse72_row.curse_band,
			via = curse72_row.via,
			fallback = curse72_row.fallback == true,
			error = curse72_row.error,
			cfg_ok = curse72_row.cfg ~= nil,
			distinct_from_98 = curse72_row.distinct_from_98 == true,
			exclude_relaxed = curse72_row.exclude_relaxed == true,
			paired_98_variant = curse72_row.paired_98_variant,
		} or nil,
		note = voodoo
			and "98+72 from Voodoo enhanced 31–40; prefer distinct variants"
			or "98 from normal curse 0–30; no 72",
	}
	push_event("curse_72_plan", runtime.curse_72_plan)
	push_event("curse_98_plan", runtime.curse_72_plan.curse_98)

	local north_mod = runtime.north_secret_mirror
		or package.loaded["Qing_Remaster_scripts.items.golden_compass.north_secret_mirror"]
	if type(north_mod) ~= "table" or type(north_mod.append_to_special_room_plan) ~= "function" then
		error("golden_compass.runtime: north_secret_mirror not eager-pinned (corridor_plan load order)")
	end
	runtime.north_secret_mirror = north_mod
	-- Inventory-driven plan only (no Home surplus relocate). Links finalized after Place.
	local north_plan = north_mod.append_to_special_room_plan(pending, plan, summary, {
		add_asg = add_asg,
	})
	push_event("north_mirror_secret_plan", north_plan)

	pending.room_plan = plan
	runtime.special_room_plan = {
		stage_stb = stage_stb,
		restore_stage = stage,
		restore_stage_type = stage_type,
		base_seed = base_seed,
		rows = summary,
		curse_72_wanted = voodoo,
		voodoo_head = voodoo,
		curse_band = voodoo and "voodoo_31_40" or "normal_0_30",
		north_mirror = north_plan,
	}
	push_event("special_room_assignment", runtime.special_room_plan)
	return plan
end

local function summarize_room_config_spawns(cfg)
	if not cfg then
		return {spawn_count = 0, entries = {}}
	end
	local spawn_count = cfg.SpawnCount
	if spawn_count == nil then
		pcall(function()
			spawn_count = cfg.Spawns and (cfg.Spawns.Size or #cfg.Spawns) or 0
		end)
	end
	spawn_count = tonumber(spawn_count) or 0
	local entries = {}
	local spawns = cfg.Spawns
	local limit = math.min(spawn_count, 12)
	for i = 0, limit - 1 do
		local spawn = nil
		pcall(function()
			spawn = spawns:Get(i)
		end)
		if spawn then
			local entry = nil
			pcall(function()
				entry = spawn:PickEntry(0)
			end)
			entries[#entries + 1] = {
				index = i,
				type = entry and entry.Type,
				variant = entry and entry.Variant,
				subtype = entry and entry.Subtype,
			}
		end
	end
	return {spawn_count = spawn_count, entries = entries}
end

local function filter_boss_candidates_with_spawns(candidates)
	local with_spawns = {}
	for _, row in ipairs(candidates) do
		local sc = 0
		pcall(function()
			sc = row.cfg and (row.cfg.SpawnCount or 0) or 0
		end)
		if sc > 0 then
			local copy = {}
			for k, v in pairs(row) do
				copy[k] = v
			end
			copy.spawn_count = sc
			with_spawns[#with_spawns + 1] = copy
		end
	end
	if #with_spawns > 0 then
		return with_spawns
	end
	return candidates
end

set_natural_deal_suppress = function(on)
	runtime.suppress_natural_deal = on == true
	if on then
		deal_chance_holder.register_provider(DEAL_SUPPRESS_PROVIDER_KEY, function()
			if runtime.suppress_natural_deal then
				-- Additive override: clamp total Deal to 0 for this remade floor only.
				return {total_deal = -1e9}
			end
			return {total_deal = 0}
		end)
		pcall(function()
			deal_chance_holder.refresh_total_deal()
		end)
	else
		deal_chance_holder.unregister_provider(DEAL_SUPPRESS_PROVIDER_KEY)
		pcall(function()
			deal_chance_holder.refresh_total_deal()
		end)
	end
	push_event("natural_deal_suppress", {
		active = runtime.suppress_natural_deal == true,
		provider = DEAL_SUPPRESS_PROVIDER_KEY,
	})
end

--- While corridor_active: floor total Deal to 1.0 (HUD stays 100%; deal door already fixed).
set_deal_guarantee = function(on)
	runtime.deal_guarantee = on == true
	if on then
		deal_chance_holder.register_provider(DEAL_GUARANTEE_PROVIDER_KEY, function()
			if runtime.corridor_active and runtime.deal_guarantee then
				return {min_total_deal = 1.0}
			end
			return nil
		end)
	else
		deal_chance_holder.unregister_provider(DEAL_GUARANTEE_PROVIDER_KEY)
	end
	pcall(function()
		deal_chance_holder.refresh_total_deal()
	end)
	push_event("deal_guarantee", {
		active = runtime.deal_guarantee == true,
		provider = DEAL_GUARANTEE_PROVIDER_KEY,
	})
end

function compass_floor.seija_corridor_curse_mask()
	-- Common floor curses only: no LABYRINTH / GIANT / THE_CURSED (spike doors).
	return LevelCurse.CURSE_OF_DARKNESS
		| LevelCurse.CURSE_OF_THE_LOST
		| LevelCurse.CURSE_OF_THE_UNKNOWN
		| LevelCurse.CURSE_OF_MAZE
		| LevelCurse.CURSE_OF_BLIND
end

function compass_floor.corridor_wants_seija_curses()
	local compat = compass_state.get_compat and compass_state.get_compat() or {}
	return compat.seija_curses == true
end

local function clear_corridor_curses(tag)
	local level = Game():GetLevel()
	local before = 0
	pcall(function()
		before = level:GetCurses() or 0
	end)
	local seija = compass_floor.corridor_wants_seija_curses()
	local want = seija and compass_floor.seija_corridor_curse_mask() or LevelCurse.CURSE_NONE
	if before ~= 0 and before ~= LevelCurse.CURSE_NONE then
		pcall(function()
			level:RemoveCurses(before)
		end)
	end
	if seija and want ~= LevelCurse.CURSE_NONE then
		pcall(function()
			level:AddCurse(want, false)
		end)
	end
	local after = 0
	pcall(function()
		after = level:GetCurses() or 0
	end)
	local ok_mask
	if seija then
		ok_mask = (after & want) == want
	else
		ok_mask = after == 0 or after == LevelCurse.CURSE_NONE
	end
	local row = {
		tag = tag,
		before = before,
		after = after,
		seija = seija,
		want = want,
		ok = ok_mask == true,
	}
	runtime.curse_clear = row
	push_event("corridor_curse_clear", row)
	return row
end

-- write_desc_config forward-declared near file top (special_quest_doors + negatives).

local function snapshot_neg_desc(idx)
	local level = Game():GetLevel()
	local desc = nil
	pcall(function()
		desc = level:GetRoomByIdx(idx, 0)
	end)
	local data = desc and desc.Data
	local over = nil
	pcall(function()
		over = desc and desc.OverrideData
	end)
	local row = {
		idx = idx,
		present = desc ~= nil,
		type = data and data.Type,
		variant = data and data.Variant,
		subtype = data and data.Subtype,
		shape = data and data.Shape,
		doors = data and data.Doors,
		override_type = over and over.Type,
		override_variant = over and over.Variant,
		override_subtype = over and over.Subtype,
	}
	if desc then
		pcall(function()
			row.visited_count = desc.VisitedCount
		end)
		pcall(function()
			row.clear = desc.Clear
		end)
		pcall(function()
			row.clear_count = desc.ClearCount
		end)
		pcall(function()
			row.spawn_seed = desc.SpawnSeed
		end)
		pcall(function()
			row.decoration_seed = desc.DecorationSeed
		end)
		pcall(function()
			row.award_seed = desc.AwardSeed
		end)
		pcall(function()
			row.challenge_done = desc.ChallengeDone
		end)
		pcall(function()
			row.has_water = desc.HasWater
		end)
		pcall(function()
			row.flags = desc.Flags
		end)
	end
	return row
end

--- Shared RoomDescriptor runtime init: non-zero seeds (+ optional fresh-room wipe).
--- Data/OverrideData alone is not enough — SpawnSeed==0 asserts in room Init.
--- opts: idx, base_seed, domain_spawn/deco/award, stream, fresh_room (default true).
init_desc_runtime = function(desc, opts)
	opts = opts or {}
	local detail = {
		fields_ok = false,
		save_wipe_ok = false,
		save_wipe_attempted = false,
		fresh_room = opts.fresh_room ~= false,
		spawn_seed = nil,
		decoration_seed = nil,
		award_seed = nil,
		domain_spawn = opts.domain_spawn or "desc_spawn",
		domain_deco = opts.domain_deco or "desc_deco",
		domain_award = opts.domain_award or "desc_award",
	}
	if not desc then
		detail.error = "nil_desc"
		return detail
	end
	local root = tonumber(opts.base_seed)
	if not root or root <= 0 then
		detail.error = "missing_root_seed"
		return detail
	end
	local idx = opts.idx
	local stream = opts.stream or 1
	local spawn_seed = select(1, compass_rng.derive_seed(root, detail.domain_spawn, idx, stream))
	local deco_seed = select(1, compass_rng.derive_seed(root, detail.domain_deco, idx, stream))
	local award_seed = select(1, compass_rng.derive_seed(root, detail.domain_award, idx, stream))
	if not spawn_seed or not deco_seed or not award_seed then
		detail.error = "derive_seed_failed"
		return detail
	end
	detail.spawn_seed = spawn_seed
	detail.decoration_seed = deco_seed
	detail.award_seed = award_seed
	detail.fields_ok = pcall(function()
		if detail.fresh_room then
			-- Fresh enter: let vanilla Init spawn from Data (shops use AwardSeed).
			desc.VisitedCount = 0
			desc.Clear = false
			desc.ClearCount = 0
			desc.ChallengeDone = false
			desc.HasWater = false
			desc.Flags = 0
		end
		desc.SpawnSeed = spawn_seed
		desc.DecorationSeed = deco_seed
		desc.AwardSeed = award_seed
	end) == true

	-- RGON: wipe stale save only for never-visited / freshly configured rooms.
	if detail.fresh_room and REPENTOGON then
		detail.save_wipe_attempted = true
		detail.save_wipe_ok = pcall(function()
			if desc.GetDecoSaveState then
				desc:GetDecoSaveState():Clear()
			end
			if desc.GetEntitiesSaveState then
				desc:GetEntitiesSaveState():Clear()
			end
			if desc.GetGridEntitiesSaveState then
				local grid_save = desc:GetGridEntitiesSaveState()
				local n = #grid_save
				for i = 0, n - 1 do
					local grid_desc = grid_save:Get(i)
					if grid_desc then
						grid_desc.Initialized = false
						grid_desc.SpawnCount = 0
						grid_desc.State = 0
						grid_desc.Type = 0
						grid_desc.Variant = 0
						grid_desc.VarData = 0
					end
				end
			end
		end) == true
	end
	return detail
end

compass_floor.init_desc_runtime = init_desc_runtime

--- StageAPI ExtraRoomTransition-style descriptor prep for negative GridRooms.
local function init_negative_desc_runtime(desc, idx, base_seed)
	return init_desc_runtime(desc, {
		idx = idx,
		base_seed = base_seed,
		domain_spawn = "neg_spawn",
		domain_deco = "neg_deco",
		domain_award = "neg_award",
		stream = 1,
		fresh_room = true,
	})
end

local function write_negative_room(idx, cfg, tag_kind, base_seed)
	local before = snapshot_neg_desc(idx)
	local desc = nil
	pcall(function()
		desc = Game():GetLevel():GetRoomByIdx(idx, 0)
	end)
	if not desc then
		return {
			ok = false,
			kind = tag_kind,
			idx = idx,
			error = "missing_descriptor",
			before = before,
		}
	end
	if not cfg then
		return {
			ok = false,
			kind = tag_kind,
			idx = idx,
			error = "missing_config",
			before = before,
		}
	end
	-- Negative rooms own their index before Data exists; do not require Data for first write.
	-- Still refuse aliases (SafeGridIndex / ListIndex mismatch).
	if not room_desc_owns_index(desc, idx) then
		return {
			ok = false,
			kind = tag_kind,
			idx = idx,
			error = "descriptor_not_owned_for_idx",
			before = before,
			alias_owner = desc.SafeGridIndex,
			list_index = desc.ListIndex,
			has_data = desc.Data ~= nil,
		}
	end
	local ok, via = write_desc_config(desc, cfg, nil, idx)
	local runtime_init = init_negative_desc_runtime(desc, idx, base_seed)
	local after = snapshot_neg_desc(idx)
	return {
		ok = ok == true
			and after.type == cfg.Type
			and after.subtype == cfg.Subtype
			and runtime_init.fields_ok == true,
		kind = tag_kind,
		idx = idx,
		via = via,
		variant = cfg.Variant,
		subtype = cfg.Subtype,
		room_type = cfg.Type,
		runtime_init = runtime_init,
		before = before,
		after = after,
		note = "Data/OverrideData + Visited/Clear/Flags/seeds + RGON save wipe",
	}
end

--- Replace Home Beast -10 / ensure -13 / -18 before players use those destinations.
local function prepare_negative_special_rooms(pending, tag)
	local stage = pending and pending.restore_stage
	local stage_type = pending and pending.restore_stage_type
	local base_seed = compass_floor.require_root_seed("plan")
	if not base_seed then
		return nil
	end
	-- resolve_secret_exit_rule applies BACKWARDS_PATH_INIT suppress for mausoleum_heart.
	local exit_rule = compass_floor.resolve_secret_exit_rule()
	local secret_row
	if exit_rule and exit_rule.kind == "mausoleum_heart" and exit_rule.eligible == true
		and corridor_plan_mod.pick_mausoleum_heart_target
	then
		secret_row = corridor_plan_mod.pick_mausoleum_heart_target(base_seed)
		secret_row.rule = exit_rule
	elseif exit_rule and exit_rule.kind == "mother_arena" and exit_rule.eligible == true
		and corridor_plan_mod.pick_mother_arena_target
	then
		secret_row = corridor_plan_mod.pick_mother_arena_target(base_seed)
		secret_row.rule = exit_rule
	elseif exit_rule and exit_rule.eligible ~= true then
		secret_row = {
			skipped = true,
			skip_reason = exit_rule.reason or "ineligible",
			rule = exit_rule,
			error = "secret_exit_ineligible_" .. tostring(exit_rule.reason or "unknown"),
		}
	else
		secret_row = corridor_plan_mod.pick_secret_exit(stage, base_seed, stage_type)
	end
	local member_row = corridor_plan_mod.pick_member_card_shop(base_seed)
	local stair_row = corridor_plan_mod.pick_angel_stairway(base_seed)
	local boss_rush_row = corridor_plan_mod.pick_boss_rush
		and corridor_plan_mod.pick_boss_rush(base_seed)
		or nil
	local blue_womb_row = corridor_plan_mod.pick_blue_womb_entrance
		and corridor_plan_mod.pick_blue_womb_entrance(base_seed)
		or nil
	local out = {
		tag = tag,
		secret_exit = nil,
		member_shop = nil,
		angel_shop = nil,
		boss_rush = nil,
		blue_womb = nil,
		heart_target = (exit_rule and exit_rule.kind == "mausoleum_heart" and exit_rule.eligible == true) or false,
		mother_arena = (exit_rule and exit_rule.kind == "mother_arena" and exit_rule.eligible == true) or false,
	}
	if secret_row and secret_row.cfg then
		local write_kind = "secret_exit"
		if secret_row.kind == "mausoleum_heart" then
			write_kind = "mausoleum_heart"
		elseif secret_row.kind == "mother_arena" then
			write_kind = "mother_arena"
		end
		out.secret_exit = write_negative_room(SECRET_EXIT_IDX, secret_row.cfg, write_kind, base_seed)
		out.secret_exit.pick = {
			required_subtype = secret_row.required_subtype,
			selected_subtype = secret_row.selected_subtype,
			selected_variant = secret_row.selected_variant,
			candidates_after_filter = secret_row.candidates_after_filter,
			via = secret_row.via,
			kind = secret_row.kind,
		}
		if secret_row.kind == "mausoleum_heart" then
			local after = out.secret_exit.after or out.secret_exit
			local heart_ok = corridor_plan_mod.is_mausoleum_heart_target_cfg(after)
				or corridor_plan_mod.is_mausoleum_heart_target_cfg(secret_row.cfg)
			if not heart_ok then
				out.secret_exit.ok = false
				out.secret_exit.error = "mausoleum_heart_target_invalid"
				out.secret_exit.note = "refused Home Beast Room / non-heart -10"
			end
		elseif secret_row.kind == "mother_arena" then
			local after = out.secret_exit.after or out.secret_exit
			local mother_ok = corridor_plan_mod.is_mother_arena_target_cfg
				and (
					corridor_plan_mod.is_mother_arena_target_cfg(after)
					or corridor_plan_mod.is_mother_arena_target_cfg(secret_row.cfg)
				)
			if not mother_ok then
				out.secret_exit.ok = false
				out.secret_exit.error = "mother_arena_target_invalid"
				out.secret_exit.note = "refused Home Beast Room / non-Mother -10"
			end
		end
	else
		out.secret_exit = {
			ok = false,
			kind = secret_row and secret_row.kind or "secret_exit",
			idx = SECRET_EXIT_IDX,
			error = secret_row and secret_row.error or "pick_failed",
			pick = secret_row,
		}
	end
	if member_row and member_row.cfg then
		out.member_shop = write_negative_room(SECRET_SHOP_IDX, member_row.cfg, "member_card_shop", base_seed)
		out.member_shop.pick = {
			eligible_subtypes = member_row.eligible_subtypes,
			selected_subtype = member_row.selected_subtype,
			selected_variant = member_row.selected_variant,
			candidates_after_filter = member_row.candidates_after_filter,
			via = member_row.via,
		}
	else
		out.member_shop = {
			ok = false,
			kind = "member_card_shop",
			idx = SECRET_SHOP_IDX,
			error = member_row and member_row.error or "pick_failed",
			pick = member_row,
		}
	end
	if stair_row and stair_row.cfg then
		out.angel_shop = write_negative_room(ANGEL_SHOP_IDX, stair_row.cfg, "angel_stairway", base_seed)
		out.angel_shop.pick = {
			required_subtype = stair_row.required_subtype,
			selected_subtype = stair_row.selected_subtype,
			selected_variant = stair_row.selected_variant,
			candidates_after_filter = stair_row.candidates_after_filter,
			via = stair_row.via,
		}
	else
		out.angel_shop = {
			ok = false,
			kind = "angel_stairway",
			idx = ANGEL_SHOP_IDX,
			error = stair_row and stair_row.error or "pick_failed",
			pick = stair_row,
		}
	end
	-- Boss Rush (-5): always prepare a valid destination; timed door only decides entry.
	if boss_rush_row and boss_rush_row.cfg then
		out.boss_rush = write_negative_room(BOSS_RUSH_IDX, boss_rush_row.cfg, "boss_rush", base_seed)
		out.boss_rush.pick = {
			selected_subtype = boss_rush_row.selected_subtype,
			selected_variant = boss_rush_row.selected_variant,
			shape = boss_rush_row.shape,
			via = boss_rush_row.via,
			seed = boss_rush_row.seed,
		}
	else
		out.boss_rush = {
			ok = false,
			kind = "boss_rush",
			idx = BOSS_RUSH_IDX,
			error = boss_rush_row and boss_rush_row.error or "pick_failed",
			pick = boss_rush_row,
		}
	end
	-- Blue Womb entrance (-8): fixed BLUE_WOMB / DEFAULT / variant 1 "Entrance Room".
	do
		local blue_idx = corridor_plan_mod.BLUE_WOMB_IDX
			or (GridRooms and GridRooms.ROOM_BLUE_WOOM_IDX)
			or -8
		if blue_womb_row and blue_womb_row.cfg then
			out.blue_womb = write_negative_room(
				blue_idx,
				blue_womb_row.cfg,
				"blue_womb_entrance",
				base_seed
			)
			out.blue_womb.pick = {
				selected_subtype = blue_womb_row.selected_subtype,
				selected_variant = blue_womb_row.selected_variant,
				shape = blue_womb_row.shape,
				name = blue_womb_row.name,
				via = blue_womb_row.via,
			}
		else
			out.blue_womb = {
				ok = false,
				kind = "blue_womb_entrance",
				idx = blue_idx,
				error = blue_womb_row and blue_womb_row.error or "pick_failed",
				pick = blue_womb_row,
			}
		end
	end
	-- Ineligible chapters: skipped is success (do not require a fake -10 room).
	if out.secret_exit and (out.secret_exit.skipped or (secret_row and secret_row.skipped)) then
		out.secret_exit.ok = true
		out.secret_exit.skipped = true
		out.secret_exit.skip_reason = out.secret_exit.skip_reason
			or (secret_row and secret_row.skip_reason)
			or "ineligible"
		out.secret_exit.rule = secret_row and secret_row.rule
	end
	runtime.negative_rooms = out
	local secret_ok = out.secret_exit and out.secret_exit.ok == true
	local member_ok = out.member_shop and out.member_shop.ok == true
	local angel_ok = out.angel_shop and out.angel_shop.ok == true
	local rush_ok = out.boss_rush and out.boss_rush.ok == true
	local blue_ok = out.blue_womb and out.blue_womb.ok == true
	local neg_ok = secret_ok and member_ok and angel_ok and rush_ok and blue_ok
	compass_state.mark_negative_ready(neg_ok == true)
	if not neg_ok then
		compass_state.fail_generation("negative_rooms_incomplete")
	end
	compass_floor.try_finalize(tag or "negative_rooms")
	push_event("negative_rooms_prepare", out)
	return out
end

local secret_exit_doors = require("Qing_Remaster_scripts.items.golden_compass.secret_exit_doors")
secret_exit_doors.install({
	runtime = runtime,
	cfg = cfg,
	compass_floor = compass_floor,
	compass_state = compass_state,
	corridor_plan = corridor_plan_mod,
	read_level_identity = read_level_identity,
	push_event = push_event,
	secret_exit_idx = SECRET_EXIT_IDX,
	snapshot_neg_desc = snapshot_neg_desc,
	snapshot_special_door = function(door)
		return compass_floor.snapshot_special_door(door)
	end,
})

--- 78–90 corridor_room_plan + Boss@89 summary. Deal type chosen before suppress.
local function build_corridor_and_boss_plans(pending)
	local stage = pending and pending.restore_stage
	local stage_type = pending and pending.restore_stage_type
	local stage_stb = level_stage_to_stb(stage, stage_type)
	local base_seed = compass_floor.require_root_seed("plan")
	if not base_seed then
		return nil
	end

	-- Decide 90 Devil/Angel from live conditions, THEN suppress natural deal spawn.
	local built = corridor_plan_mod.build(pending, stage_stb, base_seed)
	runtime.corridor_room_plan = {
		stage_stb = stage_stb,
		restore_stage = stage,
		restore_stage_type = stage_type,
		base_seed = base_seed,
		deal_choice = built.deal_choice,
		rows = built.rows,
		content = built.content,
	}
	push_event("corridor_room_assignment", runtime.corridor_room_plan)
	if built and built.deal_choice and built.deal_choice.room_type then
		runtime.corridor_deal_type = built.deal_choice.room_type
	end
	if pending.force_boss_subtype ~= nil then
		runtime.corridor_force_boss = pending.force_boss_subtype
	end
	local deal90 = pending.corridor_plan and pending.corridor_plan[DEAL_ROOM_SGID]
	if deal90 and deal90.deal_magnet then
		push_event("deal_90_magnet_pick", deal90.deal_magnet)
	end
	set_natural_deal_suppress(true)

	local boss_row = pending.corridor_plan and pending.corridor_plan[BOSS_ROOM_SGID]
	pending.boss_plan = pending.boss_plan or {}
	if boss_row then
		pending.boss_plan[BOSS_ROOM_SGID] = boss_row
	end
	local spawn_info = summarize_room_config_spawns(boss_row and boss_row.cfg)
	local summary = {
		sgid = BOSS_ROOM_SGID,
		room_type = boss_row and boss_row.room_type,
		pool = "boss",
		source_stb = boss_row and boss_row.source_stb,
		stage_stb = stage_stb,
		variant = boss_row and boss_row.variant,
		shape = boss_row and boss_row.shape,
		doors = boss_row and boss_row.doors,
		subtype = boss_row and boss_row.subtype,
		difficulty = boss_row and boss_row.difficulty,
		name = boss_row and boss_row.name,
		spawn_count = (boss_row and boss_row.spawn_count) or spawn_info.spawn_count,
		spawn_entries = spawn_info.entries,
		fallback = boss_row and boss_row.fallback == true,
		via = boss_row and boss_row.via,
		error = boss_row and boss_row.error,
		force_boss_subtype = pending.force_boss_subtype,
		force_boss_ok = pending.force_boss_subtype == nil
			or (boss_row and boss_row.cfg ~= nil and boss_row.subtype == pending.force_boss_subtype),
		deal_room = pending.deal_room_choice,
		restore_stage = stage,
		restore_stage_type = stage_type,
	}
	do
		local mom_maus = (BossType and BossType.MOM_MAUSOLEUM)
			or (corridor_plan_mod.BOSS_SUBTYPE_MOM_MAUSOLEUM)
			or 89
		local want_v = corridor_plan_mod.BOSS_VARIANT_MOM_MAUSOLEUM
		if pending.force_boss_subtype == mom_maus then
			local name_l = tostring(summary.name or ""):lower()
			local layout_ok = summary.force_boss_ok == true
				and (
					tonumber(summary.variant) == want_v
					or name_l:find("mausoleum", 1, true) ~= nil
				)
			summary.force_boss_ok = layout_ok
			summary.force_boss_layout = layout_ok and "mom_mausoleum_special" or "rejected"
			if not layout_ok then
				summary.error = summary.error or "forced_mom_mausoleum_layout_rejected"
			end
		end
	end
	runtime.boss_90_plan = summary
	push_event("boss_89_assignment", summary)
	push_event("boss_90_assignment", summary) -- legacy alias during transition
	if pending.force_boss_subtype ~= nil and summary.force_boss_ok ~= true then
		push_event("force_boss_prepare_failed", {
			wanted = pending.force_boss_subtype,
			got_subtype = boss_row and boss_row.subtype,
			got_variant = boss_row and boss_row.variant,
			got_name = boss_row and boss_row.name,
			error = boss_row and boss_row.error or summary.error,
			note = "forced boss layout missing or rejected; no silent stub fallback",
		})
	end
	return built
end

local function cfg_from_room_plan(pending, sgid)
	local plan = pending and pending.room_plan
	local row = plan and plan[sgid]
	if row and row.cfg then
		return row.cfg, row
	end
	return nil, row
end

local function cfg_from_corridor_plan(pending, sgid)
	return corridor_plan_mod.cfg_for(pending, sgid)
end

local function cfg_from_boss_plan(pending, sgid)
	local cfg, row = cfg_from_corridor_plan(pending, sgid)
	if cfg then
		return cfg, row
	end
	local plan = pending and pending.boss_plan
	row = plan and plan[sgid]
	if row and row.cfg then
		return row.cfg, row
	end
	return nil, row
end


local function doors_are_compatible(required_mask, room_config)
	if not room_config or room_config.Doors == nil or required_mask == nil then
		return false
	end
	return (room_config.Doors & required_mask) == required_mask
end

local function snapshot_generator_room(slot)
	if not slot then
		return nil
	end
	local col = safe_call(slot.Column, slot)
	local row = safe_call(slot.Row, slot)
	local shape = safe_call(slot.Shape, slot)
	local door_mask = safe_call(slot.DoorMask, slot)
	local gen = safe_call(slot.GenerationIndex, slot)
	local dead = safe_call(slot.IsDeadEnd, slot)
	local neighbors = safe_call(slot.Neighbors, slot)
	return {
		generation_index = gen,
		col = col,
		row = row,
		shape = shape,
		door_mask = door_mask,
		is_dead_end = dead == true,
		neighbors = neighbors,
		sgid = (col ~= nil and row ~= nil) and grid_index(col, row) or nil,
	}
end

local function snapshot_all_generator_rooms(level_generator)
	local rooms = {}
	if not level_generator or not level_generator.GetAllRooms then
		return rooms, "no GetAllRooms"
	end
	local all, ok, err = safe_call(level_generator.GetAllRooms, level_generator)
	if not ok then
		return rooms, err or "GetAllRooms failed"
	end
	if type(all) ~= "table" then
		return rooms, "GetAllRooms not table"
	end
	for _, slot in ipairs(all) do
		rooms[#rooms + 1] = snapshot_generator_room(slot)
	end
	table.sort(rooms, function(a, b)
		return (a.generation_index or 0) < (b.generation_index or 0)
	end)
	return rooms, nil
end

local function find_slot_by_generation(level_generator, gen_index)
	local all = safe_call(level_generator.GetAllRooms, level_generator)
	if type(all) ~= "table" then
		return nil
	end
	for _, slot in ipairs(all) do
		if safe_call(slot.GenerationIndex, slot) == gen_index then
			return slot
		end
	end
	return nil
end

local function corridor_occupancy_from_level()
	local level = Game():GetLevel()
	local present = {}
	local conflicts = {}
	local COL_BOSS = BOSS_ROOM_SGID % LEVEL_GRID_WIDTH
	local COL_DEAL = DEAL_ROOM_SGID % LEVEL_GRID_WIDTH
	for col = CORRIDOR_LEFT, CORRIDOR_RIGHT do
		local sgid = grid_index(col, CORRIDOR_ROW)
		local desc = nil
		pcall(function()
			desc = level:GetRoomByIdx(sgid, 0)
		end)
		-- Alias probe: Data alone is not ownership (GetRoomByIdx may return -1 devil).
		-- Exception: Delirium 2x2 owner@89 — GetRoomByIdx(90) returns SafeGridIndex=89 (footprint).
		local owner = desc and tonumber(desc.SafeGridIndex)
		local shape = desc and desc.Data and tonumber(desc.Data.Shape)
		local delirium_footprint = desc
			and desc.Data
			and owner == BOSS_ROOM_SGID
			and shape == ((RoomShape and RoomShape.ROOMSHAPE_2x2) or 8)
			and (col == COL_BOSS or col == COL_DEAL)
		if delirium_footprint then
			present[col] = {
				sgid = BOSS_ROOM_SGID,
				shape = shape,
				variant = desc.Data.Variant,
				type = desc.Data.Type,
				visited = desc.VisitedCount,
				list_index = desc.ListIndex,
				registered = col == COL_BOSS,
				footprint_of = BOSS_ROOM_SGID,
			}
		elseif desc and desc.Data and not room_desc_is_registered(desc, sgid) then
			conflicts[#conflicts + 1] = {
				kind = "unregistered_alias",
				col = col,
				row = CORRIDOR_ROW,
				sgid = sgid,
				owner_sgid = desc.SafeGridIndex,
				list_index = desc.ListIndex,
				variant = desc.Data.Variant,
				type = desc.Data.Type,
			}
		elseif room_desc_is_registered(desc, sgid) then
			shape = desc.Data.Shape
			if shape == SHAPE_1X1 then
				present[col] = {
					sgid = sgid,
					shape = shape,
					variant = desc.Data.Variant,
					type = desc.Data.Type,
					visited = desc.VisitedCount,
					list_index = desc.ListIndex,
					registered = true,
				}
			elseif shape == ((RoomShape and RoomShape.ROOMSHAPE_2x2) or 8) and sgid == BOSS_ROOM_SGID then
				-- Owner cell of intentional Void Delirium 2x2.
				present[col] = {
					sgid = sgid,
					shape = shape,
					variant = desc.Data.Variant,
					type = desc.Data.Type,
					visited = desc.VisitedCount,
					list_index = desc.ListIndex,
					registered = true,
					delirium_2x2 = true,
				}
				present[COL_DEAL] = present[COL_DEAL] or {
					sgid = BOSS_ROOM_SGID,
					shape = shape,
					variant = desc.Data.Variant,
					type = desc.Data.Type,
					footprint_of = BOSS_ROOM_SGID,
					registered = false,
				}
			else
				conflicts[#conflicts + 1] = {
					kind = "shape_conflict",
					col = col,
					row = CORRIDOR_ROW,
					sgid = sgid,
					shape = shape,
				}
			end
		end
	end
	return present, conflicts
end

local function count_corridor_present(present)
	local n = 0
	for col = CORRIDOR_LEFT, CORRIDOR_RIGHT do
		if present[col] then
			n = n + 1
		end
	end
	return n
end

--- Place optional CURSE@72 above 85 before main-path TryPlace of 85.
--- Uses AllowNoNeighbors; failure is logged and must not abort the corridor.
local function try_place_curse_72_before_85(pending, seed)
	local level = Game():GetLevel()
	local plan_cfg, plan_row = cfg_from_room_plan(pending, ROOM_72_SGID)
	local row = {
		sgid = ROOM_72_SGID,
		wanted = true,
		voodoo_head = true,
		plan_variant = plan_row and plan_row.variant,
		plan_doors = plan_row and plan_row.doors,
		plan_via = plan_row and plan_row.via,
	}
	local own_desc = nil
	pcall(function()
		own_desc = level:GetRoomByIdx(ROOM_72_SGID, 0)
	end)
	if room_desc_is_registered(own_desc, ROOM_72_SGID) then
		if plan_cfg and (own_desc.VisitedCount or 0) == 0 then
			local ok_w = write_desc_config(own_desc, plan_cfg, nil, ROOM_72_SGID)
			row.rewritten = ok_w == true
		end
		row.ok = true
		row.reused = true
		row.note = "already own room at 72"
		return row
	end
	if not plan_cfg then
		row.ok = false
		row.error = "missing_curse_72_cfg"
		row.note = "keep 98; main path unaffected"
		return row
	end
	local can = true
	if level.CanPlaceRoom then
		local ok_can, can_val = pcall(function()
			return level:CanPlaceRoom(plan_cfg, ROOM_72_SGID, 0, true, true, true)
		end)
		can = ok_can and can_val == true
		row.can_place = can
	end
	if not can then
		row.ok = false
		row.error = "CanPlaceRoom false"
		row.note = "extra curse skipped; 85 still places with LRUD"
		return row
	end
	local placed, ok, err = safe_call(
		level.TryPlaceRoom,
		level,
		plan_cfg,
		ROOM_72_SGID,
		0,
		(seed or 1) + ROOM_72_SGID,
		true,
		true,
		true
	)
	row.ok = ok and placed ~= nil
	row.error = (not ok and err) or (placed == nil and "TryPlaceRoom nil") or nil
	row.note = row.ok and "CURSE@72 placed before 85"
		or "extra curse failed; keep 98; do not block 85"
	return row
end

--- Live-floor fill via TryPlaceRoom. MUST only run after Room::Init (POST_NEW_ROOM).
--- opts.max_new_places: smoke test uses 1; full corridor uses nil (unlimited).
local function ensure_corridor_try_place(pending, opts)
	opts = opts or {}
	local max_new = opts.max_new_places
	local attempts = {}
	local conflicts = {}
	local level = Game():GetLevel()
	local corridor_cfg = get_room_config(RoomType.ROOM_DEFAULT, ROOM_VARIANT_CORRIDOR)
	if not corridor_cfg then
		return attempts, conflicts, "missing_config_" .. tostring(ROOM_VARIANT_CORRIDOR)
	end
	if not level.TryPlaceRoom then
		return attempts, conflicts, "no_TryPlaceRoom"
	end

	local present, occ_conflicts = corridor_occupancy_from_level()
	local shape_block = false
	for _, c in ipairs(occ_conflicts) do
		conflicts[#conflicts + 1] = c
		-- Alias / unregistered rows must fall through to TryPlaceRoom; only bad shapes abort.
		if c.kind == "shape_conflict" then
			shape_block = true
		end
	end
	if shape_block then
		return attempts, conflicts, "corridor_shape_conflicts"
	end

	local seed = compass_floor.derive_placement_seed(0, 0, "try_place_batch")
	if not seed then
		return attempts, conflicts, "root_seed_missing_try_place"
	end
	local new_placed = 0

	local function place_cfg_for_sgid(sgid)
		local plan_cfg, plan_row = cfg_from_corridor_plan(pending, sgid)
		if plan_cfg then
			return plan_cfg, plan_row, "corridor_plan_" .. tostring(plan_row.kind or plan_row.pool or "typed")
		end
		if sgid == BOSS_ROOM_SGID then
			local boss_cfg, boss_row = cfg_from_boss_plan(pending, BOSS_ROOM_SGID)
			if boss_cfg then
				return boss_cfg, boss_row, "boss_plan"
			end
		end
		return corridor_cfg, nil, "corridor_fallback_25600"
	end

	-- allow_no_neighbors: required for deal@90 preplace before boss@89 exists.
	local function try_one(col, place_opts)
		place_opts = place_opts or {}
		local allow_no_neighbors = place_opts.allow_no_neighbors == true
		local sgid = grid_index(col, CORRIDOR_ROW)
		local place_cfg, place_row, place_kind = place_cfg_for_sgid(sgid)
		local attempt = {
			kind = place_opts.kind or "try_place",
			placement_phase = "post_new_room",
			col = col,
			row = CORRIDOR_ROW,
			sgid = sgid,
			place_kind = place_kind,
			place_variant = place_row and place_row.variant or ROOM_VARIANT_CORRIDOR,
			place_type = place_row and place_row.room_type or RoomType.ROOM_DEFAULT,
			allow_no_neighbors = allow_no_neighbors,
		}
		if present[col] then
			attempt.ok = true
			attempt.reused = true
			attempts[#attempts + 1] = attempt
			return true, attempt
		end
		if max_new and new_placed >= max_new then
			attempt.ok = false
			attempt.skipped = true
			attempt.error = "max_new_places_reached"
			attempts[#attempts + 1] = attempt
			return false, attempt
		end
		if not place_cfg then
			attempt.ok = false
			attempt.error = "missing_place_cfg_" .. tostring(place_kind)
			conflicts[#conflicts + 1] = attempt
			attempts[#attempts + 1] = attempt
			return false, attempt
		end
		local can = true
		if level.CanPlaceRoom then
			local ok_can, can_val = pcall(function()
				return level:CanPlaceRoom(place_cfg, sgid, 0, true, true, allow_no_neighbors)
			end)
			can = ok_can and can_val == true
			attempt.can_place = can
		end
		if not can then
			attempt.ok = false
			attempt.error = "CanPlaceRoom false"
			conflicts[#conflicts + 1] = attempt
			attempts[#attempts + 1] = attempt
			return false, attempt
		end
		-- Native AV cannot be caught by pcall; only call after Room::Init.
		local placed, ok, err = safe_call(
			level.TryPlaceRoom,
			level,
			place_cfg,
			sgid,
			0,
			seed + sgid,
			true,
			true,
			allow_no_neighbors
		)
		attempt.ok = ok and placed ~= nil
		attempt.error = (not ok and err) or (placed == nil and "TryPlaceRoom nil") or nil
		if attempt.ok then
			-- Confirm the grid now owns a real RoomDescriptor (not a lingering alias).
			local reg_ok, reg_desc = get_registered_room_desc(sgid, 0)
			if not reg_ok then
				attempt.ok = false
				attempt.error = "try_place_unregistered"
				attempt.alias_owner = reg_desc and reg_desc.SafeGridIndex
				attempt.alias_list_index = reg_desc and reg_desc.ListIndex
				conflicts[#conflicts + 1] = attempt
			else
				new_placed = new_placed + 1
				attempt.last_success_sgid = sgid
				attempt.list_index = reg_desc.ListIndex
				local placed_shape = (place_cfg and place_cfg.Shape) or SHAPE_1X1
				present[col] = {
					sgid = sgid,
					shape = placed_shape,
					variant = attempt.place_variant,
					type = attempt.place_type,
					placed = true,
					place_kind = place_kind,
					list_index = reg_desc.ListIndex,
					registered = true,
				}
				-- Delirium 2x2: mark deal col as footprint so final fill check passes.
				if sgid == BOSS_ROOM_SGID and tonumber(placed_shape) == ((RoomShape and RoomShape.ROOMSHAPE_2x2) or 8) then
					local deal_col = DEAL_ROOM_SGID % LEVEL_GRID_WIDTH
					present[deal_col] = {
						sgid = BOSS_ROOM_SGID,
						shape = placed_shape,
						footprint_of = BOSS_ROOM_SGID,
						placed = true,
						place_kind = place_kind,
					}
					attempt.footprint_90 = true
				end
			end
		else
			conflicts[#conflicts + 1] = attempt
		end
		attempts[#attempts + 1] = attempt
		return attempt.ok, attempt
	end

	-- Col indices: 78→0 … 89→11 … 90→12. Boss is 11; deal is 12.
	local COL_BOSS = BOSS_ROOM_SGID % LEVEL_GRID_WIDTH
	local COL_DEAL = DEAL_ROOM_SGID % LEVEL_GRID_WIDTH
	local COL_BEFORE_BOSS = COL_BOSS - 1
	local delirium_2x2 = corridor_plan_mod.is_delirium_void_endpoint
		and corridor_plan_mod.is_delirium_void_endpoint(pending)

	-- 1) Full mode: preplace deal@90 with AllowNoNeighbors BEFORE any boss exists.
	--    RGON rejects placing beside an existing ROOM_BOSS neighbor.
	--    Void Delirium 2x2 claims 90 as footprint — skip separate deal preplace.
	if not max_new then
		if delirium_2x2 or (corridor_plan_mod.is_deal_90_footprint and corridor_plan_mod.is_deal_90_footprint(pending)) then
			local skip90 = {
				ok = true,
				skipped = true,
				reason = "delirium_2x2_footprint",
				sgid = DEAL_ROOM_SGID,
				note = "deal@90 claimed by Boss@89 SPECIAL_ROOMS/3414",
			}
			runtime.deal_90_preplace = skip90
			push_event("deal_90_preplace", skip90)
		else
			present = corridor_occupancy_from_level()
			local ok90, row90 = try_one(COL_DEAL, {
				kind = "deal_90_preplace",
				allow_no_neighbors = true,
			})
			runtime.deal_90_preplace = row90
			push_event("deal_90_preplace", row90)
			if not ok90 and not (row90 and row90.reused) then
				return attempts, conflicts, "deal_90_preplace_failed"
			end
		end
	end

	-- 1b) Optional CURSE@72 (Voodoo Head) BEFORE 85 so CanPlaceRoom sees UP neighbor.
	-- Failure must not block main-path 85; keep 98 and log.
	if not max_new and pending and pending.curse_72_wanted then
		local curse_row = try_place_curse_72_before_85(pending, seed)
		runtime.curse_72_place = curse_row
		push_event("curse_72_place", curse_row)
	elseif not max_new then
		runtime.curse_72_place = {
			ok = false,
			skipped = true,
			reason = "no_voodoo_head",
			sgid = ROOM_72_SGID,
		}
		push_event("curse_72_place", runtime.curse_72_place)
	end

	-- 2) Fill 78–88 only (never place boss/deal in the generic growth loop).
	local east_blocked = false
	for _ = 1, 20 do
		present = corridor_occupancy_from_level()
		local missing = {}
		for col = CORRIDOR_LEFT, COL_BEFORE_BOSS do
			if not present[col] then
				missing[#missing + 1] = col
			end
		end
		if #missing == 0 then
			break
		end
		if max_new and new_placed >= max_new then
			break
		end
		local progressed = false
		for _, col in ipairs(missing) do
			if present[col - 1] or present[col + 1] then
				local ok_col = try_one(col)
				if ok_col then
					progressed = true
					present = corridor_occupancy_from_level()
					if max_new and new_placed >= max_new then
						break
					end
				elseif grid_index(col, CORRIDOR_ROW) == 85 then
					-- 85 failed: do not keep hammering eastward dependents.
					east_blocked = true
					push_event("corridor_place_abort", {
						reason = "sgid_85_failed",
						missing = missing,
					})
					break
				end
			end
		end
		if east_blocked then
			break
		end
		if max_new and new_placed >= max_new then
			break
		end
		if not progressed then
			for _, col in ipairs(missing) do
				if not present[col] then
					local ok_col = try_one(col)
					present = corridor_occupancy_from_level()
					if not ok_col and grid_index(col, CORRIDOR_ROW) == 85 then
						east_blocked = true
						break
					end
					if max_new and new_placed >= max_new then
						break
					end
				end
			end
			break
		end
	end

	-- 3) Boss@89 only when 78–88 are all present (never isolate on preplaced 90 alone).
	if not max_new then
		present = corridor_occupancy_from_level()
		local miss_before = {}
		for col = CORRIDOR_LEFT, COL_BEFORE_BOSS do
			if not present[col] then
				miss_before[#miss_before + 1] = col
			end
		end
		if #miss_before > 0 then
			local skip89 = {
				ok = false,
				skipped = true,
				reason = "corridor_78_88_incomplete",
				missing_cols = miss_before,
				neighbor_90 = present[COL_DEAL] ~= nil,
				note = "refuse boss place without full 78–88",
			}
			runtime.boss_89_place = skip89
			push_event("boss_89_place", skip89)
			-- Fall through to unfilled error below.
		else
			local ok89, row89 = try_one(COL_BOSS, {kind = "boss_89_place"})
			if row89 then
				local sgid88 = grid_index(COL_BEFORE_BOSS, CORRIDOR_ROW)
				local ok88, d88 = get_registered_room_desc(sgid88, 0)
				row89.neighbor_88 = ok88 == true
				row89.neighbor_88_type = d88 and d88.Data and d88.Data.Type
				row89.delirium_2x2 = delirium_2x2 == true
				if delirium_2x2 then
					-- 90 is same-room footprint; confirm owner@89 covers deal col via GetRoomByIdx.
					local d90 = nil
					pcall(function()
						d90 = Game():GetLevel():GetRoomByIdx(DEAL_ROOM_SGID, 0)
					end)
					local footprint_ok = d90
						and tonumber(d90.SafeGridIndex) == BOSS_ROOM_SGID
						and d90.Data ~= nil
						and tonumber(d90.Data.Shape) == ((RoomShape and RoomShape.ROOMSHAPE_2x2) or 8)
					row89.neighbor_90 = false
					row89.footprint_90 = footprint_ok == true
					row89.neighbor_90_type = d90 and d90.Data and d90.Data.Type
					if row89.ok then
						present[COL_DEAL] = {
							sgid = BOSS_ROOM_SGID,
							shape = ((RoomShape and RoomShape.ROOMSHAPE_2x2) or 8),
							footprint_of = BOSS_ROOM_SGID,
							placed = true,
						}
					end
				else
					local ok90, d90 = get_registered_room_desc(DEAL_ROOM_SGID, 0)
					row89.neighbor_90 = ok90 == true
					row89.neighbor_90_type = d90 and d90.Data and d90.Data.Type
				end
				if not row89.neighbor_88 then
					row89.ok = false
					row89.error = (row89.error or "") .. ";missing_neighbor_88"
				end
			end
			runtime.boss_89_place = row89
			push_event("boss_89_place", row89)
			if not ok89 and not (row89 and row89.reused) then
				return attempts, conflicts, "boss_89_place_failed"
			end
			if row89 and row89.ok and not row89.neighbor_88 then
				return attempts, conflicts, "boss_89_missing_neighbor_88"
			end
		end
	end

	present = corridor_occupancy_from_level()
	local miss = {}
	for col = CORRIDOR_LEFT, CORRIDOR_RIGHT do
		if not present[col] then
			miss[#miss + 1] = col
			if not max_new then
				conflicts[#conflicts + 1] = {
					kind = "unfilled",
					col = col,
					row = CORRIDOR_ROW,
					sgid = grid_index(col, CORRIDOR_ROW),
				}
			end
		end
	end
	if max_new then
		if new_placed < 1 then
			return attempts, conflicts, "smoke_place_failed"
		end
		return attempts, conflicts, nil
	end
	if #miss > 0 then
		return attempts, conflicts, "corridor_incomplete"
	end
	return attempts, conflicts, nil
end

--- Write RoomConfig onto a descriptor.
--- Prefer live PRE_NEW_ROOM descriptor so Room:Init re-reads Data.
--- POST path assigns Data/OverrideData directly — NEVER Room_holder.Replace_with
--- (VisitedCount~=0 would register Shift and interfere on re-entry).
--- expect_sgid: when set, refuse writes if descriptor does not own that grid
--- (prevents GetRoomByIdx(alias) from mutating the real -1 devil room).
--- Negative expect_sgid: allow Data=nil first-time init via room_desc_writable_for.
write_desc_config = function(desc, cfg_room, current_desc, expect_sgid)
	if not desc or not cfg_room then
		return false, "nil_desc_or_cfg"
	end
	if expect_sgid ~= nil then
		local owns_desc = room_desc_writable_for(desc, expect_sgid)
		local owns_cur = current_desc and room_desc_writable_for(current_desc, expect_sgid)
		if not owns_desc and not owns_cur then
			return false, "refuse_write_unregistered_or_alias"
		end
	else
		-- Without expect_sgid: still refuse ListIndex-invalid descriptors (stubs / aliases).
		local list = tonumber(desc.ListIndex)
		if list == nil or list < 0 then
			return false, "refuse_write_invalid_list_index"
		end
	end
	local use_current = current_desc
		and desc.SafeGridIndex ~= nil
		and current_desc.SafeGridIndex == desc.SafeGridIndex
	local target = use_current and current_desc or desc
	if expect_sgid ~= nil and current_desc and room_desc_writable_for(current_desc, expect_sgid) then
		target = current_desc
	elseif expect_sgid ~= nil and room_desc_writable_for(desc, expect_sgid) then
		target = desc
	end
	local ok = pcall(function()
		target.Data = cfg_room
		target.OverrideData = cfg_room
	end)
	if use_current then
		return ok, ok and "pre_new_room_descriptor" or "descriptor_write_failed"
	end
	return ok, ok and "direct_data_assign" or "descriptor_write_failed"
end

local function snapshot_live_room_content(phase)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	local sgid = desc and desc.SafeGridIndex
	local data = desc and desc.Data
	local ent_counts = {}
	local ent_total = 0
	pcall(function()
		for _, ent in ipairs(Isaac.GetRoomEntities()) do
			if ent and ent.Type then
				local key = tostring(ent.Type) .. "." .. tostring(ent.Variant)
				ent_counts[key] = (ent_counts[key] or 0) + 1
				ent_total = ent_total + 1
			end
		end
	end)
	local grid_rocks = 0
	local grid_poops = 0
	local grid_total = 0
	pcall(function()
		local size = room:GetGridSize()
		for i = 0, size - 1 do
			local ge = room:GetGridEntity(i)
			if ge then
				grid_total = grid_total + 1
				local gt = ge:GetType()
				if gt == GridEntityType.GRID_ROCK
					or gt == GridEntityType.GRID_ROCKB
					or gt == GridEntityType.GRID_ROCKT
					or gt == GridEntityType.GRID_ROCK_ALT
					or gt == GridEntityType.GRID_ROCK_SS
					or gt == GridEntityType.GRID_ROCK_SPIKED
					or gt == GridEntityType.GRID_ROCK_GOLD
				then
					grid_rocks = grid_rocks + 1
				elseif gt == GridEntityType.GRID_POOP then
					grid_poops = grid_poops + 1
				end
			end
		end
	end)
	local room_type = nil
	pcall(function()
		room_type = room:GetType()
	end)
	local identity = read_level_identity()
	return {
		phase = phase,
		sgid = sgid,
		visited = desc and desc.VisitedCount,
		desc_variant = data and data.Variant,
		desc_shape = data and data.Shape,
		desc_type = data and data.Type,
		desc_name = data and data.Name,
		room_type = room_type,
		entity_total = ent_total,
		entity_counts = ent_counts,
		grid_total = grid_total,
		grid_rocks = grid_rocks,
		grid_poops = grid_poops,
		stage = identity.stage,
		stage_type = identity.stage_type,
		is_home_stage = identity.stage == HOME_STAGE,
	}
end

--- Push live content; keep first native-84 init snapshot for rematerialize before/after compare.
local function emit_live_room_content(phase)
	local live = snapshot_live_room_content(phase)
	push_event("live_room_content", live)
	if live.sgid == ORIGINAL_START_INDEX and not runtime.first_84_live then
		runtime.first_84_live = live
	end
	return live
end

local function resolve_stb_grid_type(tp, vr)
	local mapped = STB_TO_GRID[tp]
	if mapped == nil then
		return nil
	end
	if type(mapped) == "table" then
		return mapped.Type, mapped.Variant or vr or 0
	end
	return mapped, vr or 0
end

--- First-POST rematerialize of the current room (84) from descriptor Data.Spawns.
--- RGON: no ReloadRoom; RespawnEnemies only restores enemies from save; PlaceRoom ≠ re-init.
local function rematerialize_current_room_from_data(tag)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	local data = desc and desc.Data
	local sgid = desc and desc.SafeGridIndex
	local before = snapshot_live_room_content((tag or "remat") .. "_before")

	if sgid ~= ORIGINAL_START_INDEX then
		local skip = {
			ok = false,
			reason = "not_current_84",
			sgid = sgid,
			before = before,
		}
		runtime.rematerialize_84_result = skip
		push_event("rematerialize_84_skip", skip)
		return false, skip.reason
	end
	-- Fixed 84 = fireplace only (25602 normal / 25606 Water II white fire). Options wait for true enter.
	local corridor_row = runtime.pending and runtime.pending.corridor_plan
		and runtime.pending.corridor_plan[ORIGINAL_START_INDEX]
	local use_fixed_84 = compass_floor.is_fixed_84_variant(data and data.Variant)
		or (corridor_row and corridor_row.kind == "fixed_fire_options")

	local clear_ent_save_ok, clear_ent_save_err = pcall(function()
		desc:GetEntitiesSaveState():Clear()
	end)
	local clear_deco_ok, clear_deco_err = pcall(function()
		if desc.GetDecoSaveState then
			desc:GetDecoSaveState():Clear()
		end
	end)

	local removed_ents = 0
	pcall(function()
		for _, ent in ipairs(Isaac.GetRoomEntities()) do
			if ent and ent.Exists and ent:Exists() then
				local tp = ent.Type
				if tp ~= EntityType.ENTITY_PLAYER
					and tp ~= EntityType.ENTITY_FAMILIAR
					and tp ~= EntityType.ENTITY_KNIFE
				then
					ent:Remove()
					removed_ents = removed_ents + 1
				end
			end
		end
	end)

	local removed_grids = 0
	pcall(function()
		local size = room:GetGridSize()
		for i = 0, size - 1 do
			local ge = room:GetGridEntity(i)
			if ge then
				local gt = ge:GetType()
				if not KEEP_GRID_ON_CLEAR[gt] then
					if room.RemoveGridEntityImmediate then
						room:RemoveGridEntityImmediate(i, 0, false)
					else
						room:RemoveGridEntity(i, 0, false)
					end
					removed_grids = removed_grids + 1
				end
			end
		end
	end)

	local spawned_ents = 0
	local spawned_grids = 0
	local skipped = 0
	local spawn_errors = {}
	local spawn_count = 0
	local fixed_84 = nil

	-- Replay Spawns (fireplace only for 25602). Do NOT spawn options here.
	pcall(function()
		local spawns = data and data.Spawns
		if not spawns or not spawns.Size then
			return
		end
		spawn_count = spawns.Size
		local width = data.Width or 13
		local seed = 1
		pcall(function()
			seed = room:GetSpawnSeed() or 1
		end)
		for i = 0, spawns.Size - 1 do
			local info = spawns:Get(i)
			local entinfo = info:PickEntry(0)
			local tp = entinfo.Type
			local vr = entinfo.Variant or 0
			local st = entinfo.Subtype or 0
			-- Skip any accidental collectible entries in STB.
			if tp == EntityType.ENTITY_PICKUP and vr == PickupVariant.PICKUP_COLLECTIBLE then
				skipped = skipped + 1
			else
				local gidx = (width + 2) * (info.Y + 1) + info.X + 1
				local grid_type, grid_vr = resolve_stb_grid_type(tp, vr)
				if grid_type then
					local ok, err = pcall(function()
						room:SpawnGridEntity(gidx, grid_type, grid_vr, seed + i, 0)
					end)
					if ok then
						spawned_grids = spawned_grids + 1
					else
						spawn_errors[#spawn_errors + 1] = {
							i = i,
							kind = "grid",
							type = tp,
							error = tostring(err),
						}
					end
				elseif tp > 0 and tp < 1000 then
					local pos = room:GetGridPosition(gidx)
					local ok, err = pcall(function()
						Isaac.Spawn(tp, vr, st, pos, Vector.Zero, nil)
					end)
					if ok then
						spawned_ents = spawned_ents + 1
					else
						spawn_errors[#spawn_errors + 1] = {
							i = i,
							kind = "ent",
							type = tp,
							error = tostring(err),
						}
					end
				else
					skipped = skipped + 1
				end
			end
		end
	end)

	if use_fixed_84 then
		local fire_present = false
		for _, ent in ipairs(Isaac.GetRoomEntities()) do
			if ent and ent.Type == EntityType.ENTITY_FIREPLACE then
				fire_present = true
				break
			end
		end
		fixed_84 = {
			stb_variant = data and data.Variant,
			fireplace_present = fire_present,
			pedestal_count = 0,
			options_deferred = true,
			note = "Home remat: fireplace only; options wait for true corridor enter",
		}
		runtime.fixed_84_content = fixed_84
	end

	local save_ok, save_err = pcall(function()
		room:SaveState()
	end)

	local after = snapshot_live_room_content((tag or "remat") .. "_after")
	local result = {
		ok = true,
		tag = tag,
		sgid = sgid,
		desc_variant = data and data.Variant,
		mode = use_fixed_84 and "fixed_84_fire_only" or "spawn_replay",
		fixed_84 = fixed_84,
		clear_ent_save_ok = clear_ent_save_ok == true,
		clear_ent_save_err = clear_ent_save_ok and nil or tostring(clear_ent_save_err),
		clear_deco_ok = clear_deco_ok == true,
		clear_deco_err = clear_deco_ok and nil or tostring(clear_deco_err),
		removed_ents = removed_ents,
		removed_grids = removed_grids,
		spawn_count = spawn_count,
		spawned_ents = spawned_ents,
		spawned_grids = spawned_grids,
		skipped = skipped,
		spawn_error_count = #spawn_errors,
		spawn_errors = spawn_errors,
		save_ok = save_ok == true,
		save_err = save_ok and nil or tostring(save_err),
		before = before,
		after = after,
		entity_total_before = before.entity_total,
		entity_total_after = after.entity_total,
		grid_rocks_before = before.grid_rocks,
		grid_rocks_after = after.grid_rocks,
	}
	runtime.rematerialize_84_result = result
	push_event("rematerialize_84", result)
	runtime.note = string.format(
		"remat84 rocks %s→%s ents %s→%s spawned_g=%d spawned_e=%d",
		tostring(before.grid_rocks),
		tostring(after.grid_rocks),
		tostring(before.entity_total),
		tostring(after.entity_total),
		spawned_grids,
		spawned_ents
	)
	return true, nil
end

local function snapshot_grid_mapping(grid_index)
	local level = Game():GetLevel()
	local desc = nil
	pcall(function()
		desc = level:GetRoomByIdx(grid_index, 0)
	end)
	local data = desc and desc.Data
	local rooms = level:GetRooms()
	return {
		query_grid = grid_index,
		owner_sgid = desc and desc.SafeGridIndex,
		list_index = desc and desc.ListIndex,
		visited = desc and desc.VisitedCount,
		shape = data and data.Shape,
		variant = data and data.Variant,
		type = data and data.Type,
		alias = desc and desc.SafeGridIndex ~= nil and desc.SafeGridIndex ~= grid_index,
		empty = not (desc and data),
		rooms_size = rooms and rooms.Size or nil,
	}
end

local function make_level_generator_entry(col, row, door_mask)
	if not Isaac.LevelGeneratorEntry then
		return nil, "no_Isaac.LevelGeneratorEntry"
	end
	local entry = nil
	local ok_new, err_new = pcall(function()
		entry = Isaac.LevelGeneratorEntry()
	end)
	if not ok_new or not entry then
		return nil, "LevelGeneratorEntry_new_failed:" .. tostring(err_new)
	end
	local function call_set(name, value)
		if entry[name] then
			local ok, err = pcall(function()
				entry[name](entry, value)
			end)
			if ok then
				return true
			end
			ok, err = pcall(function()
				entry[name](value)
			end)
			return ok, err
		end
		return false, "missing_" .. name
	end
	local ok_c, err_c = call_set("SetColIdx", col)
	if not ok_c then
		return nil, "SetColIdx:" .. tostring(err_c)
	end
	local ok_r, err_r = call_set("SetLineIdx", row)
	if not ok_r then
		return nil, "SetLineIdx:" .. tostring(err_r)
	end
	local ok_d, err_d = call_set("SetAllowedDoors", door_mask)
	if not ok_d then
		return nil, "SetAllowedDoors:" .. tostring(err_d)
	end
	return entry, nil
end

local function probe_occupancy_aliases()
	local level = Game():GetLevel()
	local rows = {}
	for _, grid_index in ipairs(OCCUPANCY_PROBE_INDICES) do
		local desc = nil
		pcall(function()
			desc = level:GetRoomByIdx(grid_index, 0)
		end)
		local data = desc and desc.Data
		rows[#rows + 1] = {
			query_grid = grid_index,
			owner_sgid = desc and desc.SafeGridIndex,
			list_index = desc and desc.ListIndex,
			visited = desc and desc.VisitedCount,
			shape = data and data.Shape,
			variant = data and data.Variant,
			type = data and data.Type,
			alias = desc and desc.SafeGridIndex ~= nil and desc.SafeGridIndex ~= grid_index,
			empty = not (desc and data),
		}
	end
	return rows
end

local function try_minimap_refresh()
	local ok, err = false, "no_Minimap"
	if Minimap and Minimap.Refresh then
		ok = pcall(function()
			Minimap.Refresh()
		end)
		if not ok then
			err = "Refresh_failed"
		else
			err = nil
		end
	end
	return ok, err
end

local function try_update_visibility()
	local level = Game():GetLevel()
	if level and level.UpdateVisibility then
		return pcall(function()
			level:UpdateVisibility()
		end)
	end
	return false, "no_UpdateVisibility"
end

-- Must be declared before link_room_pair / snapshot_home_layout (local forward-ref).
local function read_desc_doors_array(desc)
	local doors = {}
	if not desc then
		return doors
	end
	for slot = 0, 7 do
		local target = nil
		pcall(function()
			target = desc.Doors[slot]
		end)
		doors[tostring(slot)] = target
	end
	return doors
end

--- True iff GetRoomByIdx(grid) already owns that grid (registered identity).
local function grid_has_own_room(grid_index)
	return get_registered_room_desc(grid_index, 0)
end

--- Force Level:PlaceRoom at one alias grid using room_plan cfg (25601 fallback).
--- Skips Place if already own room; still writes plan Data when unvisited.
local function force_place_secret_at_grid(target, seed_base, pending)
	local grid = target.grid
	local expect_owner = target.expect_owner_before
	local before = snapshot_grid_mapping(grid)
	local before_owner = snapshot_grid_mapping(expect_owner)
	local plan_cfg, plan_row = cfg_from_room_plan(pending, grid)
	local place_cfg = plan_cfg or get_room_config(RoomType.ROOM_SECRET, ROOM_VARIANT_SECRET_TERRAIN)
	local owns, own_desc = grid_has_own_room(grid)
	if owns then
		local rewritten = false
		if plan_cfg and own_desc and (own_desc.VisitedCount or 0) == 0 then
			local ok_w = write_desc_config(own_desc, plan_cfg, nil, grid)
			rewritten = ok_w == true
		end
		local after = snapshot_grid_mapping(grid)
		return {
			grid = grid,
			expect_owner_before = expect_owner,
			skipped = true,
			reason = "already_own_room",
			plan_rewritten = rewritten,
			plan_variant = plan_row and plan_row.variant,
			plan_type = plan_row and plan_row.room_type,
			before = before,
			after = after,
			before_owner = before_owner,
			after_owner = before_owner,
			place_ok = false,
		}
	end

	local level = Game():GetLevel()
	local col = grid % LEVEL_GRID_WIDTH
	local row = math.floor(grid / LEVEL_GRID_WIDTH)
	local entry, entry_err = make_level_generator_entry(col, row, DOOR_MASK_1X1_ALL)
	local place_ok, place_err, place_ret = false, entry_err, nil
	if not place_cfg then
		place_err = "missing_place_config"
	elseif not entry then
		place_err = entry_err or "no_entry"
	elseif not level.PlaceRoom then
		place_err = "no_Level.PlaceRoom"
	else
		local seed = (seed_base or 1) + grid
		place_ret, place_ok, place_err = safe_call(level.PlaceRoom, level, entry, place_cfg, seed)
		if place_ok then
			place_ok = place_ret == true
			if place_ret ~= true then
				place_err = "PlaceRoom returned " .. tostring(place_ret)
			end
		end
	end

	local after = snapshot_grid_mapping(grid)
	local after_owner = snapshot_grid_mapping(expect_owner)
	return {
		grid = grid,
		expect_owner_before = expect_owner,
		skipped = false,
		col = col,
		row = row,
		door_mask = DOOR_MASK_1X1_ALL,
		variant = after.variant or (plan_row and plan_row.variant) or ROOM_VARIANT_SECRET_TERRAIN,
		plan_type = plan_row and plan_row.room_type,
		plan_fallback = plan_row and plan_row.fallback == true,
		before = before,
		after = after,
		before_owner = before_owner,
		after_owner = after_owner,
		place_ok = place_ok == true,
		place_error = place_err,
		owner_changed = before.owner_sgid ~= after.owner_sgid,
		now_own_room = after.owner_sgid == grid,
		owner_still_valid = after_owner.empty ~= true and after_owner.owner_sgid == expect_owner,
		rooms_size_before = before.rooms_size,
		rooms_size_after = after.rooms_size,
	}
end

local function force_place_alias_batch(tag, pending)
	local seed = compass_floor.derive_placement_seed(0, 1, "force_place_side")
	if not seed then
		return {tag = tag, placed = 0, skipped = 0, error = "root_seed_missing_force_place", rows = {}}
	end
	local rows = {}
	local placed = 0
	local skipped = 0
	for _, target in ipairs(FORCE_PLACE_TARGETS) do
		local row = force_place_secret_at_grid(target, seed, pending)
		rows[#rows + 1] = row
		if row.skipped then
			skipped = skipped + 1
		elseif row.place_ok then
			placed = placed + 1
		end
	end
	-- North mirror Luna/Fragmented extras. Topology links only after successful own rooms.
	local north_mod = runtime.north_secret_mirror
		or package.loaded["Qing_Remaster_scripts.items.golden_compass.north_secret_mirror"]
	local north_rows = {}
	local north_order = (pending and pending.north_mirror_place_order) or {}
	local north_ok = {}
	if type(north_mod) ~= "table" or type(north_mod.finalize_after_place) ~= "function" then
		push_event("north_mirror_place_skipped", {
			tag = tag,
			reason = "north_secret_mirror_not_pinned",
		})
	else
		for _, sgid in ipairs(north_order) do
			local reserved = north_mod.NORTH_RESERVED_SGIDS and north_mod.NORTH_RESERVED_SGIDS[sgid]
			if reserved then
				local brow = {
					grid = sgid,
					blocked = true,
					reason = reserved,
					north_mirror = true,
					place_ok = false,
				}
				north_rows[#north_rows + 1] = brow
				rows[#rows + 1] = brow
				push_event("north_mirror_place_blocked", brow)
			else
				-- Strict occupancy: foreign/alias descriptor blocks Place (GC own room may rewrite).
				local snap = snapshot_grid_mapping(sgid)
				local owns = grid_has_own_room(sgid)
				if snap and snap.empty ~= true and not owns then
					local brow = {
						grid = sgid,
						blocked = true,
						reason = "occupied_foreign_or_alias",
						owner_sgid = snap.owner_sgid,
						alias = snap.alias == true,
						north_mirror = true,
						place_ok = false,
					}
					north_rows[#north_rows + 1] = brow
					rows[#rows + 1] = brow
					skipped = skipped + 1
					push_event("north_mirror_place_blocked", brow)
				else
					local row = force_place_secret_at_grid({grid = sgid}, seed, pending)
					row.north_mirror = true
					north_rows[#north_rows + 1] = row
					rows[#rows + 1] = row
					-- Accept only owned SGID whose final Type/Variant match this GC north plan.
					local plan_row = pending and pending.room_plan and pending.room_plan[sgid]
					local after = row.after or snapshot_grid_mapping(sgid)
					local expect_type = plan_row and tonumber(plan_row.room_type_actual or plan_row.room_type)
					local expect_variant = plan_row and tonumber(plan_row.variant)
					local owned = after
						and after.empty ~= true
						and tonumber(after.owner_sgid) == tonumber(sgid)
					local type_ok = expect_type == nil or tonumber(after.type) == expect_type
					local variant_ok = expect_variant == nil or tonumber(after.variant) == expect_variant
					local from_gc_plan = plan_row and plan_row.north_mirror == true
					local own_ok = from_gc_plan
						and owned
						and type_ok
						and variant_ok
						and (
							row.place_ok == true
							or row.plan_rewritten == true
							or (row.skipped == true and row.reason == "already_own_room")
						)
					row.north_accepted = own_ok == true
					if own_ok then
						north_ok[#north_ok + 1] = sgid
					end
					if row.skipped then
						skipped = skipped + 1
					elseif row.place_ok then
						placed = placed + 1
					end
				end
			end
		end
		local links, ok_list, unreachable = north_mod.finalize_after_place(pending, north_ok)
		runtime.north_mirror_place = {
			tag = tag,
			rows = north_rows,
			order = north_order,
			placed_ok = ok_list,
			unreachable = unreachable,
			links = links,
		}
		push_event("north_mirror_place", runtime.north_mirror_place)
	end
	local result = {
		tag = tag,
		placed = placed,
		skipped = skipped,
		rows = rows,
		north_mirror_rows = north_rows,
	}
	runtime.force_place_batch_result = result
	push_event("force_place_alias_batch", result)
	return result
end

local room_topology = require("Qing_Remaster_scripts.items.golden_compass.room_topology")
-- Capture eager pin from corridor_plan into runtime (no new main-chunk local).
runtime.north_secret_mirror = package.loaded["Qing_Remaster_scripts.items.golden_compass.north_secret_mirror"]
if type(runtime.north_secret_mirror) ~= "table"
	or type(runtime.north_secret_mirror.append_to_special_room_plan) ~= "function"
	or type(runtime.north_secret_mirror.finalize_after_place) ~= "function"
then
	error("golden_compass.runtime: north_secret_mirror eager-pin missing API at load")
end
runtime.stageapi_layout_guard = package.loaded["Qing_Remaster_scripts.items.golden_compass.stageapi_layout_guard"]
if type(runtime.stageapi_layout_guard) ~= "table"
	or type(runtime.stageapi_layout_guard.activate_for_pending) ~= "function"
then
	error("golden_compass.runtime: stageapi_layout_guard eager-pin missing API at load")
end
do
	local guard = runtime.stageapi_layout_guard
	if type(guard.ensure_installed) == "function" then
		pcall(guard.ensure_installed)
	end
end
local _topo = room_topology.install({
	runtime = runtime,
	push_event = push_event,
	entry_sgid = ENTRY_ROOM_SGID,
	extra_door_links_base = EXTRA_DOOR_LINKS_BASE,
	room_72_sgid = ROOM_72_SGID,
	corridor_left = CORRIDOR_LEFT,
	corridor_right = CORRIDOR_RIGHT,
	corridor_row = CORRIDOR_ROW,
	opposite_door_slot = OPPOSITE_DOOR_SLOT,
	door_normalize_focus = DOOR_NORMALIZE_FOCUS,
	force_place_door_links = FORCE_PLACE_DOOR_LINKS,
	grid_index = grid_index,
	read_desc_doors_array = read_desc_doors_array,
	resolve_special_quest_door_rule = function()
		return compass_floor.resolve_special_quest_door_rule and compass_floor.resolve_special_quest_door_rule()
	end,
	should_reserve_mirror_left0_allowed = function(stage, stage_type, live_variant)
		if corridor_plan_mod.should_reserve_mirror_left0_allowed then
			return corridor_plan_mod.should_reserve_mirror_left0_allowed(stage, stage_type, live_variant)
		end
		return true
	end,
	should_reserve_mineshaft_up0_allowed = function(stage, stage_type, live_variant)
		if corridor_plan_mod.should_reserve_mineshaft_up0_allowed then
			return corridor_plan_mod.should_reserve_mineshaft_up0_allowed(stage, stage_type, live_variant)
		end
		return true
	end,
})
local set_desc_door_slot = _topo.set_desc_door_slot
local or_allowed_door = _topo.or_allowed_door
local link_room_pair = _topo.link_room_pair
local repair_force_place_door_links = _topo.repair_force_place_door_links
local normalize_door_topology = _topo.normalize_door_topology
local get_extra_door_links = _topo.get_extra_door_links
local build_canonical_door_edges = _topo.build_canonical_door_edges
local collect_own_room_descs = _topo.collect_own_room_descs
local clear_desc_all_door_slots = _topo.clear_desc_all_door_slots
local set_allowed_doors_exact = _topo.set_allowed_doors_exact


local function snapshot_live_door(door)
	local snap = {
		present = door ~= nil,
		open = nil,
		locked = nil,
		variant = nil,
		state = nil,
		var_data = nil,
		current_room_type = nil,
		target_room_type = nil,
		target_room_index = nil,
		animation = nil,
		extra_visible = nil,
		is_hidden_variant = nil,
	}
	if not door then
		return snap
	end
	pcall(function()
		snap.open = door:IsOpen()
	end)
	pcall(function()
		snap.locked = door:IsLocked()
	end)
	pcall(function()
		snap.variant = door.Variant
	end)
	pcall(function()
		snap.state = door.State
	end)
	pcall(function()
		snap.var_data = door.VarData
	end)
	pcall(function()
		snap.current_room_type = door.CurrentRoomType
	end)
	pcall(function()
		snap.target_room_type = door.TargetRoomType
	end)
	pcall(function()
		snap.target_room_index = door.TargetRoomIndex
	end)
	pcall(function()
		snap.extra_visible = door.ExtraVisible
	end)
	pcall(function()
		local spr = door:GetSprite()
		if spr and spr.GetAnimation then
			snap.animation = spr:GetAnimation()
		end
	end)
	snap.is_hidden_variant = snap.variant == DOOR_VARIANT_HIDDEN
	return snap
end

--- v17: observe-only after PRE wrote 97 SECRET before 84 Init.
--- Do not Close()/MakeDoor to "fix" a wrong native wall form.
local function fix_live_84_secret_door_to_97(tag)
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	local cur_sgid = cur and cur.SafeGridIndex
	if cur_sgid ~= ORIGINAL_START_INDEX then
		local skip = {
			ok = false,
			tag = tag,
			reason = "not_current_84",
			current_sgid = cur_sgid,
		}
		runtime.live_84_secret_door = skip
		push_event("live_84_secret_door", skip)
		return skip
	end
	local room = Game():GetRoom()
	local slot = DoorSlot.DOWN0
	local desc97 = level:GetRoomByIdx(ROOM_97_SGID, 0)
	local target_type = (desc97 and desc97.Data and desc97.Data.Type) or RoomType.ROOM_SECRET
	local current_type = (cur.Data and cur.Data.Type) or RoomType.ROOM_DEFAULT
	local door = nil
	pcall(function()
		door = room:GetDoor(slot)
	end)
	local after = snapshot_live_door(door)
	local result = {
		ok = door ~= nil,
		tag = tag,
		method = "observe_only_pre97",
		slot = slot,
		target_sgid = ROOM_97_SGID,
		current_type = current_type,
		target_type = target_type,
		door_variant_hidden = DOOR_VARIANT_HIDDEN,
		has_make_door = room ~= nil and room.MakeDoor ~= nil,
		has_remove_door = room ~= nil and room.RemoveDoor ~= nil,
		before = after,
		after = after,
		close_ok = nil,
		set_room_types_ok = nil,
		looks_like_hidden_entrance = after.is_hidden_variant == true
			and after.target_room_type == target_type
			and after.open ~= true
			and after.locked ~= true,
		note = "POST observe only; PRE must write 97 SECRET before 84 Init; no Close/MakeDoor",
		desc97_type = desc97 and desc97.Data and desc97.Data.Type,
		desc97_shape = desc97 and desc97.Data and desc97.Data.Shape,
		desc97_variant = desc97 and desc97.Data and desc97.Data.Variant,
		desc97_doors = read_desc_doors_array(desc97),
		desc84_doors = read_desc_doors_array(cur),
		pre_97_secret = runtime.pre_97_secret,
	}
	runtime.live_84_secret_door = result
	push_event("live_84_secret_door", result)
	return result
end

--- Before Room:Init of 84: write 97 as ROOM_SECRET 1x1 and link 84↔97 descriptors.
local function prepare_97_secret_before_84_init(pending, current_desc, tag)
	if not pending then
		return nil
	end
	local level = Game():GetLevel()
	local sgid84 = current_desc and current_desc.SafeGridIndex
	if sgid84 ~= ORIGINAL_START_INDEX then
		return nil
	end
	if not pending.room_plan then
		build_special_room_plan(pending)
	end
	local plan_row = pending.room_plan and pending.room_plan[ROOM_97_SGID]
	local cfg_room = plan_row and plan_row.cfg
	if not cfg_room then
		cfg_room = get_room_config(RoomType.ROOM_SECRET, ROOM_VARIANT_SECRET_TERRAIN)
	end
	local desc97 = level:GetRoomByIdx(ROOM_97_SGID, 0)
	local before = {
		type = desc97 and desc97.Data and desc97.Data.Type,
		shape = desc97 and desc97.Data and desc97.Data.Shape,
		variant = desc97 and desc97.Data and desc97.Data.Variant,
		doors = read_desc_doors_array(desc97),
		allowed = desc97 and desc97.AllowedDoors,
	}
	local ok_write, how = false, "no_desc97"
	if desc97 and cfg_room and room_desc_is_registered(desc97, ROOM_97_SGID) then
		ok_write, how = write_desc_config(desc97, cfg_room, nil, ROOM_97_SGID)
	elseif desc97 and cfg_room then
		how = "refuse_write_unregistered_or_alias"
	end
	local ok_84d, err_84d = set_desc_door_slot(current_desc, DoorSlot.DOWN0, ROOM_97_SGID)
	local ok_97u, err_97u = set_desc_door_slot(desc97, DoorSlot.UP0, ORIGINAL_START_INDEX)
	local ok_84a = or_allowed_door(current_desc, DoorSlot.DOWN0)
	local ok_97a = or_allowed_door(desc97, DoorSlot.UP0)
	local after = {
		type = desc97 and desc97.Data and desc97.Data.Type,
		shape = desc97 and desc97.Data and desc97.Data.Shape,
		variant = desc97 and desc97.Data and desc97.Data.Variant,
		doors = read_desc_doors_array(desc97),
		allowed = desc97 and desc97.AllowedDoors,
	}
	local row = {
		ok = ok_write == true
			and after.type == RoomType.ROOM_SECRET
			and after.shape == SHAPE_1X1
			and ok_84d == true
			and ok_97u == true,
		tag = tag,
		via = how,
		plan_variant = plan_row and plan_row.variant,
		plan_via = plan_row and plan_row.via,
		before = before,
		after = after,
		door_84_down_ok = ok_84d == true,
		door_84_down_err = err_84d,
		door_97_up_ok = ok_97u == true,
		door_97_up_err = err_97u,
		allowed_84_ok = ok_84a == true,
		allowed_97_ok = ok_97a == true,
		doors_84 = read_desc_doors_array(current_desc),
		note = "PRE: 97 SECRET before 84 Init for native hidden wall",
	}
	runtime.pre_97_secret = row
	pending.pre_97_secret = row
	push_event("pre_97_secret", row)
	return row
end

local function list_room_npc_snapshot()
	local room = Game():GetRoom()
	local out = {}
	local n = 0
	pcall(function()
		n = room:GetAliveEnemiesCount()
	end)
	local entities = Isaac.GetRoomEntities()
	for _, ent in ipairs(entities) do
		if ent and ent:Exists() and ent:IsActiveEnemy(false) then
			out[#out + 1] = {
				type = ent.Type,
				variant = ent.Variant,
				subtype = ent.SubType,
				boss = ent:IsBoss() == true,
				hit_points = ent.HitPoints,
				max_hit_points = ent.MaxHitPoints,
				entity_boss_id = (ent.GetBossID and ent:GetBossID()) or nil,
			}
		end
	end
	return {
		alive_enemies_count = n,
		npcs = out,
		npc_count = #out,
	}
end

local function snapshot_boss_room_doors()
	local room = Game():GetRoom()
	local doors = {}
	for slot = 0, 3 do
		local door = nil
		pcall(function()
			door = room:GetDoor(slot)
		end)
		if door then
			doors[#doors + 1] = {
				slot = slot,
				snap = snapshot_live_door(door),
			}
		end
	end
	return doors
end

local function emit_boss_90_enter(tag)
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	if not cur or cur.SafeGridIndex ~= BOSS_ROOM_SGID then
		return nil
	end
	local room = Game():GetRoom()
	local plan = runtime.boss_90_plan
	local npc = list_room_npc_snapshot()
	local right_door = nil
	pcall(function()
		right_door = room:GetDoor(DoorSlot.RIGHT0)
	end)
	local row = {
		tag = tag,
		sgid = BOSS_ROOM_SGID,
		room_type = room:GetType(),
		desc_type = cur.Data and cur.Data.Type,
		desc_variant = cur.Data and cur.Data.Variant,
		desc_subtype = cur.Data and cur.Data.Subtype,
		force_boss_subtype = runtime.pending and runtime.pending.force_boss_subtype or nil,
		right0_present = right_door ~= nil,
		right0 = snapshot_live_door(right_door),
		desc_shape = cur.Data and cur.Data.Shape,
		planned_variant = plan and plan.variant,
		planned_subtype = plan and plan.subtype,
		planned_spawn_count = plan and plan.spawn_count,
		room_boss_id = room.GetBossID and room:GetBossID() or nil,
		is_clear = room:IsClear(),
		visited = cur.VisitedCount,
		doors = snapshot_boss_room_doors(),
		npcs = npc.npcs,
		npc_count = npc.npc_count,
		alive_enemies_count = npc.alive_enemies_count,
		note = "Room:GetBossID() ≠ Entity Type; compare planned Spawns vs live NPCs separately",
	}
	runtime.boss_90_enter = row
	runtime.boss_90_entered = true
	compass_floor.sync_persist()
	push_event("boss_90_enter", row)
	-- Same frame combat baseline (lock / living boss).
	local combat = {
		tag = tag,
		sgid = BOSS_ROOM_SGID,
		is_clear = row.is_clear,
		room_boss_id = row.room_boss_id,
		alive_enemies_count = row.alive_enemies_count,
		npc_count = row.npc_count,
		boss_npc_alive = false,
		doors_locked_or_closed = {},
	}
	for _, d in ipairs(row.doors) do
		combat.doors_locked_or_closed[#combat.doors_locked_or_closed + 1] = {
			slot = d.slot,
			open = d.snap.open,
			locked = d.snap.locked,
			variant = d.snap.variant,
		}
	end
	for _, n in ipairs(row.npcs) do
		if n.boss then
			combat.boss_npc_alive = true
			break
		end
	end
	runtime.boss_90_combat = combat
	push_event("boss_90_combat", combat)
	return row
end

local boss_exits = require("Qing_Remaster_scripts.items.golden_compass.boss_exits")
local ensure_boss_89_trapdoor = boss_exits.install({
	runtime = runtime,
	push_event = push_event,
	compass_floor = compass_floor,
	compass_state = compass_state,
	read_level_identity = read_level_identity,
	corridor_plan = corridor_plan_mod,
	boss_room_sgid = BOSS_ROOM_SGID,
})


local deal_doors = require("Qing_Remaster_scripts.items.golden_compass.deal_doors")
local _deal = deal_doors.install({
	runtime = runtime,
	push_event = push_event,
	compass_state = compass_state,
	boss_room_sgid = BOSS_ROOM_SGID,
	deal_room_sgid = DEAL_ROOM_SGID,
	grid_door = grid_door,
	snapshot_live_door = snapshot_live_door,
	Room_holder = Room_holder,
	game_frame = game_frame,
	boss_type_mom = BOSS_TYPE_MOM,
})
local resolve_deal_type = _deal.resolve_deal_type
local apply_boss_deal_doors = _deal.apply_boss_deal_doors
local apply_boss_89_deal_door = _deal.apply_boss_89_deal_door
local is_mom_boss_case = _deal.is_mom_boss_case
local read_door_sprite_snap = _deal.read_door_sprite_snap
local ensure_open_sprite_pose = _deal.ensure_open_sprite_pose
local tick_deal_door_sprite_watch = _deal.tick_deal_door_sprite_watch


local function emit_boss_90_clear_if_needed(tag)
	if not runtime.boss_90_entered then
		return nil
	end
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	if not cur or cur.SafeGridIndex ~= BOSS_ROOM_SGID then
		return nil
	end
	local room = Game():GetRoom()
	-- Deal door: seal while fighting; restyle/open after clear (may retry across frames).
	-- Keep deal restyle in knife dim (design: deal entry unchanged for now).
	apply_boss_89_deal_door(tag)
	if not room:IsClear() then
		return nil
	end
	local dim = compass_floor.read_current_dimension()
	local dim_knife = (Dimension and Dimension.KNIFE_PUZZLE) or 1
	local in_mirror = tonumber(dim) == tonumber(dim_knife)
	-- Trapdoor / secret exit / timed special doors: normal dim only.
	-- Helpers also self-guard; emit skips spawn intent in knife dim and still strips residues.
	local trap = ensure_boss_89_trapdoor(tag)
	local secret_exit = secret_exit_doors.try_spawn_boss_secret_exit(tag)
	local timed_door = in_mirror and {
		skipped = true,
		reason = "mirror_dimension",
	} or boss_exits.ensure_timed_special_door(tag)
	if runtime.boss_90_clear_logged then
		return runtime.boss_90_clear
	end
	local npc = list_room_npc_snapshot()
	local row = {
		tag = tag,
		sgid = BOSS_ROOM_SGID,
		dimension = dim,
		mirror_dimension = in_mirror == true,
		is_clear = true,
		room_boss_id = room.GetBossID and room:GetBossID() or nil,
		alive_enemies_count = npc.alive_enemies_count,
		npc_count = npc.npc_count,
		doors = snapshot_boss_room_doors(),
		trapdoor = trap,
		secret_exit = secret_exit,
		timed_door = timed_door,
		deal_door = runtime.boss_89_deal_door,
		reward_pickups = (function()
			local picks = {}
			for _, ent in ipairs(Isaac.GetRoomEntities()) do
				if ent and ent.Type == EntityType.ENTITY_PICKUP then
					picks[#picks + 1] = {
						variant = ent.Variant,
						subtype = ent.SubType,
					}
				end
			end
			return picks
		end)(),
	}
	runtime.boss_90_clear = row
	runtime.boss_90_clear_logged = true
	push_event("boss_89_clear", row)
	push_event("boss_90_clear", row)
	return row
end

--- Empty 78: strip debris once; persist clear save state.
local function rematerialize_empty_entry_78(tag)
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	if not cur or cur.SafeGridIndex ~= ENTRY_ROOM_SGID then
		return nil
	end
	if runtime.empty_78_result and runtime.empty_78_result.ok then
		return runtime.empty_78_result
	end
	local room = Game():GetRoom()
	local before = snapshot_live_room_content((tag or "empty78") .. "_before")
	pcall(function()
		cur:GetEntitiesSaveState():Clear()
	end)
	local removed_ents = 0
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent and ent:Exists() then
			local tp = ent.Type
			-- Keep authored fireplaces + virtual door carriers (mirror / mineshaft planks).
			local ed = ent.GetData and ent:GetData() or nil
			local keep_door = ed and (ed.is_virtual_grid_door == true or ed.is_grid_door_sprite == true)
			if tp ~= EntityType.ENTITY_PLAYER
				and tp ~= EntityType.ENTITY_FAMILIAR
				and tp ~= EntityType.ENTITY_KNIFE
				and tp ~= EntityType.ENTITY_FIREPLACE
				and not keep_door
			then
				ent:Remove()
				removed_ents = removed_ents + 1
			end
		end
	end
	local removed_grids = 0
	local size = room:GetGridSize()
	for i = 0, size - 1 do
		local ge = room:GetGridEntity(i)
		if ge then
			local gt = ge:GetType()
			if not KEEP_GRID_ON_CLEAR[gt] then
				if room.RemoveGridEntityImmediate then
					room:RemoveGridEntityImmediate(i, 0, false)
				else
					room:RemoveGridEntity(i, 0, false)
				end
				removed_grids = removed_grids + 1
			end
		end
	end
	pcall(function()
		room:SaveState()
	end)
	local after = snapshot_live_room_content((tag or "empty78") .. "_after")
	local row = {
		ok = true,
		tag = tag,
		sgid = ENTRY_ROOM_SGID,
		removed_ents = removed_ents,
		removed_grids = removed_grids,
		before = before,
		after = after,
		note = "empty entry; no enemies/pickups/rocks",
	}
	runtime.empty_78_result = row
	push_event("empty_78_rematerialize", row)
	return row
end

-- Entry@78 Mirror / Mineshaft implemented in special_quest_doors.lua (installed after snapshot_special_door).
local function challenge81_desc_is_challenge()
	local desc = nil
	pcall(function()
		desc = Game():GetLevel():GetRoomByIdx(CHALLENGE_ROOM_SGID, 0)
	end)
	local t = desc and desc.Data and desc.Data.Type
	return t == RoomType.ROOM_CHALLENGE
end

--- Main-path L/R: SetLocked(false) only (normal). Challenge entry/exit:
--- SetRoomTypes(..., DEFAULT) + Ambush skin so Open bypasses HP gate.
--- AmbushActive → vanilla open/close. Log only on state change.
local function apply_corridor_door_gate(tag)
	local challenge_boss_st = (RoomSubType and RoomSubType.CHALLENGE_BOSS) or 1
	local ambush_anm2 = "gfx/grid/door_03_ambushroomdoor.anm2"
	local boss_ambush_anm2 = "gfx/grid/door_09_bossambushroomdoor.anm2"

	local function challenge81_subtype()
		local desc = nil
		pcall(function()
			desc = Game():GetLevel():GetRoomByIdx(CHALLENGE_ROOM_SGID, 0)
		end)
		return desc and desc.Data and tonumber(desc.Data.Subtype) or nil
	end

	local function ambush_skin_anm2()
		if challenge81_subtype() == challenge_boss_st then
			return boss_ambush_anm2
		end
		return ambush_anm2
	end

	local function force_challenge_entry_normal_open(door, current_room_type, want_open)
		local detail = {
			attempted = false,
			set_room_types_ok = false,
			skin_anm2 = nil,
			skin_ok = false,
			open_after = false,
			want_open = want_open == true,
			locked_after = nil,
			current_room_type_after = nil,
			target_room_type_after = nil,
			can_open_challenge_81 = nil,
			filename_after = nil,
		}
		if not door then
			return detail
		end
		detail.attempted = true
		local crt = current_room_type
		if crt == nil then
			pcall(function()
				crt = door.CurrentRoomType
			end)
		end
		if crt == nil then
			crt = RoomType.ROOM_DEFAULT
		end
		detail.set_room_types_ok = pcall(function()
			door:SetRoomTypes(crt, RoomType.ROOM_DEFAULT)
		end) == true
		pcall(function()
			if door:IsLocked() then
				door:SetLocked(false)
			end
		end)
		pcall(function()
			if want_open then
				if not door:IsOpen() then
					door:Open()
				end
			else
				if door:IsOpen() then
					door:Close(true)
				end
			end
		end)
		local open_after = false
		pcall(function()
			open_after = door:IsOpen() == true
		end)
		detail.open_after = open_after
		pcall(function()
			detail.locked_after = door:IsLocked()
		end)
		pcall(function()
			detail.current_room_type_after = door.CurrentRoomType
		end)
		pcall(function()
			detail.target_room_type_after = door.TargetRoomType
		end)
		pcall(function()
			detail.can_open_challenge_81 = Game():GetLevel():CanOpenChallengeRoom(CHALLENGE_ROOM_SGID)
		end)
		local skin = ambush_skin_anm2()
		detail.skin_anm2 = skin
		detail.skin_ok = pcall(function()
			local spr = door:GetSprite()
			if not spr or not spr.Load then
				return
			end
			if spr.GetFilename and spr:GetFilename() ~= skin then
				spr:Load(skin, true)
			elseif not spr.GetFilename then
				spr:Load(skin, true)
			end
			if want_open and open_after and spr.Play then
				local anim = spr.GetAnimation and spr:GetAnimation() or nil
				if anim ~= "Opened" and anim ~= "Open" then
					spr:Play("Opened", true)
				end
			elseif (not want_open) and spr.Play then
				local anim = spr.GetAnimation and spr:GetAnimation() or nil
				if anim ~= "Closed" and anim ~= "Close" then
					spr:Play("Closed", true)
				end
			end
			if spr.GetFilename then
				detail.filename_after = spr:GetFilename()
			end
		end) == true
		ensure_open_sprite_pose(door)
		pcall(function()
			detail.open_after = door:IsOpen() == true
		end)
		return detail
	end

	local function gate_state_key(row)
		if not row or type(row.actions) ~= "table" then
			return ""
		end
		local parts = {
			tostring(row.sgid),
			tostring(row.ambush_active),
			tostring(row.ambush_done),
			tostring(row.challenge_here),
		}
		for _, action in ipairs(row.actions) do
			parts[#parts + 1] = table.concat({
				tostring(action.slot),
				tostring(action.neighbor),
				tostring(action.present),
				tostring(action.challenge_phase),
				tostring(action.open_after),
				tostring(action.locked_after),
				tostring(action.target_room_type_after),
				tostring(action.filename_after),
				tostring(action.skipped),
				tostring(action.reason),
			}, ":")
		end
		return table.concat(parts, "|")
	end

	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	local sgid = cur and cur.SafeGridIndex
	if not corridor_plan_mod.is_corridor_sgid(sgid) then
		return nil
	end
	local room = Game():GetRoom()
	local ambush_active = false
	local ambush_done = false
	pcall(function()
		ambush_active = room:IsAmbushActive() == true
	end)
	pcall(function()
		ambush_done = room:IsAmbushDone() == true
	end)
	local room_type = room:GetType()
	local challenge_here = sgid == CHALLENGE_ROOM_SGID and room_type == RoomType.ROOM_CHALLENGE
	local challenge81 = challenge81_desc_is_challenge()
	local can_open_81 = nil
	pcall(function()
		can_open_81 = level:CanOpenChallengeRoom(CHALLENGE_ROOM_SGID)
	end)
	local actions = {}
	local any_forced_open_fail = false
	for _, link in ipairs(corridor_plan_mod.corridor_door_slots_for(sgid, runtime.pending)) do
		local desc_target = nil
		pcall(function()
			desc_target = cur.Doors[link.slot]
		end)
		local door = room:GetDoor(link.slot)
		local action = {
			slot = link.slot,
			neighbor = link.neighbor,
			desc_doors_target = desc_target,
			present = door ~= nil,
		}
		if corridor_plan_mod.is_boss_deal_door_link(sgid, link.neighbor, runtime.pending) then
			action.skipped = true
			action.reason = "boss_deal_door_lifecycle"
			actions[#actions + 1] = action
		else
			local is_main = desc_target == link.neighbor
			action.is_main_path = is_main == true
			if not is_main then
				action.skipped = true
				action.reason = "desc_doors_not_neighbor_" .. tostring(desc_target)
			elseif door then
				local live_target = nil
				pcall(function()
					live_target = door.TargetRoomIndex
				end)
				action.target_before = live_target
				pcall(function()
					door.TargetRoomIndex = link.neighbor
				end)
				local toward_challenge = challenge81
					and corridor_plan_mod.is_challenge_entry_neighbor(sgid, link.neighbor)
				local challenge_force_open = false
				if challenge_here then
					if ambush_active then
						-- During waves: unlock keys only; vanilla owns open/close.
						pcall(function()
							if door:IsLocked() then
								door:SetLocked(false)
							end
						end)
						action.challenge_phase = "ambush_active"
						action.unlocked = true
					else
						local detail = force_challenge_entry_normal_open(door, room_type, true)
						challenge_force_open = true
						action.challenge_phase = ambush_done and "ambush_done" or "pre_challenge"
						action.unlocked = true
						action.forced_open_attempt = detail.attempted
						action.forced_open = detail.open_after == true
						action.set_room_types_ok = detail.set_room_types_ok
						action.skin_anm2 = detail.skin_anm2
						action.skin_ok = detail.skin_ok
						action.filename_after = detail.filename_after
						action.target_room_type_after = detail.target_room_type_after
						action.current_room_type_after = detail.current_room_type_after
						action.can_open_challenge_81 = detail.can_open_challenge_81
						if detail.open_after ~= true then
							any_forced_open_fail = true
						end
					end
				elseif toward_challenge then
					-- Clear-room gate outranks challenge HP bypass: only Open when room cleared.
					local want_open = room:IsClear() == true
					local detail = force_challenge_entry_normal_open(door, room_type, want_open)
					challenge_force_open = want_open
					action.challenge_phase = want_open and "entry_side_open" or "entry_side_closed"
					action.unlocked = true
					action.room_clear = want_open
					action.forced_open_attempt = detail.attempted
					action.forced_open = detail.open_after == true
					action.set_room_types_ok = detail.set_room_types_ok
					action.skin_anm2 = detail.skin_anm2
					action.skin_ok = detail.skin_ok
					action.filename_after = detail.filename_after
					action.target_room_type_after = detail.target_room_type_after
					action.current_room_type_after = detail.current_room_type_after
					action.can_open_challenge_81 = detail.can_open_challenge_81
					if want_open and detail.open_after ~= true then
						any_forced_open_fail = true
					end
				else
					local was_locked = false
					pcall(function()
						was_locked = door:IsLocked() == true
					end)
					action.was_locked = was_locked
					if was_locked then
						pcall(function()
							door:SetLocked(false)
						end)
					end
					action.unlocked = true
					-- Normal rooms: never Open()/Close().
				end
				action.open_after = door:IsOpen()
				action.locked_after = door:IsLocked()
				action.target_after = door.TargetRoomIndex
				action.variant = door.Variant
				action.challenge_force_open = challenge_force_open
				if action.filename_after == nil then
					local snap = read_door_sprite_snap(door)
					action.filename_after = snap.filename
				end
				if action.target_room_type_after == nil then
					pcall(function()
						action.target_room_type_after = door.TargetRoomType
					end)
				end
			else
				action.skipped = true
				action.reason = "no_live_door"
			end
			actions[#actions + 1] = action
		end
	end
	if any_forced_open_fail then
		runtime.corridor_door_gate_fail_count = (runtime.corridor_door_gate_fail_count or 0) + 1
	end
	local row = {
		tag = tag,
		sgid = sgid,
		room_type = room_type,
		is_clear = room:IsClear(),
		ambush_active = ambush_active,
		ambush_done = ambush_done,
		challenge_here = challenge_here,
		challenge_subtype = challenge81_subtype(),
		can_open_challenge_81 = can_open_81,
		fail_count = runtime.corridor_door_gate_fail_count or 0,
		actions = actions,
		note = "challenge entry: SetRoomTypes→DEFAULT + Ambush skin; forced_open==IsOpen",
	}
	runtime.corridor_door_gate = row
	local key = gate_state_key(row)
	local should_log = key ~= runtime.corridor_door_gate_log_key
	if any_forced_open_fail and not runtime.corridor_door_gate_open_fail_logged then
		should_log = true
		runtime.corridor_door_gate_open_fail_logged = true
		row.first_open_fail = true
	elseif any_forced_open_fail
		and runtime.corridor_door_gate_fail_count > 0
		and runtime.corridor_door_gate_fail_count % 30 == 0
	then
		-- Persist-fail heartbeat (~1s at 30Hz) without per-frame spam.
		should_log = true
		row.persist_fail_heartbeat = true
	end
	if should_log then
		runtime.corridor_door_gate_log_key = key
		push_event("corridor_door_gate", row)
	end
	return row
end

--- Unified Boss@89 visit: enter / reenter / Continue-current.
--- Resets visit-scoped spawn flag; one TrySpawn per stay; then restore payment/visual.
function compass_floor.on_boss_89_visit(tag)
	if not runtime.corridor_active then
		return nil
	end
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	if not cur or cur.SafeGridIndex ~= BOSS_ROOM_SGID then
		return nil
	end
	-- Dedup: one init per continuous stay in 89 (Continue + POST_NEW_ROOM same stay).
	if runtime.boss_89_visit_active then
		push_event("boss_89_visit_dedup", {
			tag = tag,
			prior_tag = runtime.boss_89_visit_init_tag,
			identity_restored_seen = runtime.identity_restored_seen == true,
			note = "same stay already initialized",
		})
		return {dedup = true, tag = tag}
	end
	runtime.boss_89_visit_active = true
	runtime.boss_89_visit_init_tag = tag
	runtime.secret_exit_attempted_this_visit = false
	runtime.secret_exit_restore_skipped_tag = nil
	runtime.deal_appear_sfx_logged = false
	local room = Game():GetRoom()
	local is_clear = room:IsClear() == true
	-- Appear SFX only if this stay saw combat; re-enter cleared room stays silent.
	runtime.boss_89_visit_had_combat = not is_clear
	local first_mark = not runtime.boss_90_entered
	local live_boss_id = nil
	local backwards_init = nil
	local npc_count = 0
	pcall(function()
		if room.GetBossID then
			live_boss_id = room:GetBossID()
		end
	end)
	pcall(function()
		if GameStateFlag and GameStateFlag.STATE_BACKWARDS_PATH_INIT then
			backwards_init = Game():GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT)
		end
	end)
	pcall(function()
		for _, ent in ipairs(Isaac.GetRoomEntities()) do
			if ent and ent:IsActiveEnemy(false) then
				npc_count = npc_count + 1
			end
		end
	end)
	local want_boss = runtime.corridor_force_boss
		or (runtime.pending and runtime.pending.force_boss_subtype)
		or (runtime.boss_90_plan and runtime.boss_90_plan.force_boss_subtype)
	local mom_maus = (BossType and BossType.MOM_MAUSOLEUM)
		or (corridor_plan_mod.BOSS_SUBTYPE_MOM_MAUSOLEUM)
		or 89
	local force_live_ok = true
	local force_live_reason = "no_force"
	if want_boss ~= nil then
		force_live_ok = tonumber(live_boss_id) == tonumber(want_boss)
			and backwards_init ~= true
			and (is_clear or npc_count > 0)
		if backwards_init == true then
			force_live_reason = "backwards_path_init_dads_note"
			force_live_ok = false
		elseif tonumber(live_boss_id) ~= tonumber(want_boss) then
			force_live_reason = "boss_id_mismatch"
			force_live_ok = false
		elseif (not is_clear) and npc_count <= 0 then
			force_live_reason = "no_boss_npcs"
			force_live_ok = false
		else
			force_live_reason = "force_boss_live_ok"
		end
		if tonumber(want_boss) == mom_maus and force_live_ok ~= true then
			push_event("force_boss_live_failed", {
				tag = tag,
				wanted = want_boss,
				boss_id = live_boss_id,
				npc_count = npc_count,
				backwards_path_init = backwards_init,
				room_clear = is_clear,
				plan = runtime.boss_90_plan,
				reason = force_live_reason,
				note = "forced Mom Mausoleum not confirmed in live boss room",
			})
		end
	end
	push_event("boss_89_visit_init", {
		tag = tag,
		sgid = BOSS_ROOM_SGID,
		is_clear = is_clear,
		visit_had_combat = runtime.boss_89_visit_had_combat == true,
		first_mark = first_mark,
		identity_restored_seen = runtime.identity_restored_seen == true,
		deal_type = runtime.corridor_deal_type,
		deal_type_source = runtime.deal_type_source,
		boss_90_entered = runtime.boss_90_entered == true,
		boss_id = live_boss_id,
		npc_count = npc_count,
		backwards_path_init = backwards_init,
		force_boss_subtype = want_boss,
		force_boss_live_ok = force_live_ok,
		force_boss_live_reason = force_live_reason,
	})
	compass_floor.notify_stageapi_bind_probe("enter_89", {
		tag = tag,
		live_boss_id = live_boss_id,
		is_clear = is_clear,
		first_mark = first_mark,
	})
	-- Prefer StageAPI POST_STAGEAPI_NEW_ROOM_GENERATION; enter path resolves if ready / no StageAPI.
	runtime.resolve_boss_89_encounter_commit(tag or "enter_89", {
		allow_wait = true,
	})
	if first_mark then
		emit_boss_90_enter(tag)
	end
	-- Seal while fighting; restyle/open + secret exit when clear.
	apply_boss_deal_doors(tag .. "_deal")
	local clear_row = nil
	if is_clear then
		clear_row = emit_boss_90_clear_if_needed(tag)
	end
	compass_floor.restore_secret_exit_door(tag)
	return {
		tag = tag,
		first_mark = first_mark,
		is_clear = is_clear,
		clear = clear_row,
		secret_exit = runtime.secret_exit_spawn,
		deal_door = runtime.boss_89_deal_door,
	}
end

function compass_floor.note_corridor_sgid_transition(cur_sgid)
	local prev = runtime.last_corridor_sgid
	runtime.last_corridor_sgid = cur_sgid
	if prev == BOSS_ROOM_SGID and cur_sgid ~= BOSS_ROOM_SGID then
		runtime.boss_89_visit_active = false
		runtime.boss_89_visit_init_tag = nil
		runtime.boss_89_visit_had_combat = false
		runtime.secret_exit_attempted_this_visit = false
		runtime.timed_door_strange_key_seen = false
		runtime.deal_appear_sfx_logged = false
		compass_floor.notify_stageapi_bind_probe("leave_89", {
			from_sgid = prev,
			to_sgid = cur_sgid,
		})
	end
	if prev == DEAL_ROOM_SGID and cur_sgid ~= DEAL_ROOM_SGID then
		runtime.deal_90_seal_init_done = false
	end
	if compass_floor.special_quest_on_leave_spawn_room then
		compass_floor.special_quest_on_leave_spawn_room(prev)
	elseif prev == ENTRY_ROOM_SGID and cur_sgid ~= ENTRY_ROOM_SGID then
		runtime.special_quest_door_attempted_this_visit = false
		runtime.special_quest_door_attempted_sgid = nil
	end
end

function compass_floor.on_deal_90_visit(tag)
	if not runtime.corridor_active then
		return
	end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc or desc.SafeGridIndex ~= DEAL_ROOM_SGID then
		return
	end
	-- Fresh enter: allow one SetRoomTypes+Close if uncleared.
	runtime.deal_90_seal_init_done = false
	apply_boss_deal_doors(tag)
	push_event("deal_90_enter", {
		sgid = DEAL_ROOM_SGID,
		tag = tag,
		planned = runtime.pending and runtime.pending.deal_room_choice,
		live_type = desc.Data and desc.Data.Type,
		live_variant = desc.Data and desc.Data.Variant,
		deal_type = runtime.corridor_deal_type,
		deal_type_source = runtime.deal_type_source,
		doors = read_desc_doors_array(desc),
		deal_door = runtime.boss_89_deal_door,
	})
end

function compass_floor.maybe_init_continue_current_room(tag)
	if not runtime.continue_current_room_pending then
		return false
	end
	if not runtime.corridor_active or not runtime.identity_restored_seen then
		return false
	end
	local id = read_level_identity()
	local sgid = id.current_room_index
	local room = Game():GetRoom()
	if not room then
		return false
	end
	runtime.continue_current_room_pending = false
	runtime.last_corridor_sgid = sgid
	push_event("continue_current_room_init", {
		tag = tag,
		sgid = sgid,
		identity_restored_seen = true,
		boss_90_entered = runtime.boss_90_entered == true,
		deal_type = runtime.corridor_deal_type,
		deal_type_source = runtime.deal_type_source,
	})
	if sgid == BOSS_ROOM_SGID then
		compass_floor.on_boss_89_visit((tag or "continue") .. "_current_89")
	elseif sgid == DEAL_ROOM_SGID then
		compass_floor.on_deal_90_visit((tag or "continue") .. "_current_90")
	elseif sgid == ENTRY_ROOM_SGID then
		rematerialize_empty_entry_78((tag or "continue") .. "_current_78_empty")
		-- Gate first so mirror force_virtual overlay is not overwritten by door restyle.
		apply_corridor_door_gate((tag or "continue") .. "_current_corridor")
		compass_floor.ensure_special_quest_room_doors((tag or "continue") .. "_current_78", sgid)
	elseif compass_floor.is_at_mineshaft_reward(sgid) then
		compass_floor.ensure_special_quest_room_doors((tag or "continue") .. "_current_162", sgid)
	elseif sgid == ORIGINAL_START_INDEX then
		compass_floor.spawn_84_options_on_true_enter((tag or "continue") .. "_current_84")
		apply_corridor_door_gate((tag or "continue") .. "_current_corridor")
	elseif corridor_plan_mod.is_corridor_sgid and corridor_plan_mod.is_corridor_sgid(sgid) then
		apply_corridor_door_gate((tag or "continue") .. "_current_corridor")
	end
	if compass_floor.try_spawn_mirror_79_knife_piece then
		compass_floor.try_spawn_mirror_79_knife_piece((tag or "continue") .. "_current_79")
	end
	return true
end

function compass_floor.is_normal_dim_fixed_84()
	if not runtime.corridor_active or not runtime.identity_restored_seen then
		return false
	end
	local dim_normal = (Dimension and Dimension.NORMAL) or 0
	if tonumber(compass_floor.read_current_dimension()) ~= tonumber(dim_normal) then
		return false
	end
	local cur = Game():GetLevel():GetCurrentRoomDesc()
	if not cur or cur.SafeGridIndex ~= ORIGINAL_START_INDEX then
		return false
	end
	local variant = cur.Data and cur.Data.Variant
	return compass_floor.is_fixed_84_variant(variant) == true
end

function compass_floor.fixed_84_item_mark_kind(mark)
	if mark == "angel" or mark == "devil" or mark == "treasure" then
		return mark
	end
	if mark == "item" then
		return "treasure"
	end
	return nil
end

function compass_floor.fixed_84_is_item_mark(mark)
	return compass_floor.fixed_84_item_mark_kind(mark) ~= nil
end

function compass_floor.fixed_84_seed_matches_any_item(seed)
	seed = tonumber(seed)
	if not seed then
		return false, nil
	end
	if tonumber(runtime.fixed_84_angel_item_init_seed) == seed then
		return true, "angel"
	end
	if tonumber(runtime.fixed_84_devil_item_init_seed) == seed then
		return true, "devil"
	end
	if tonumber(runtime.fixed_84_item_init_seed) == seed then
		return true, runtime.fixed_84_chosen_item_kind or "treasure"
	end
	return false, nil
end

function compass_floor.fixed_84_remember_item_slot(kind, ped)
	if not ped then
		return
	end
	local seed = tonumber(ped.InitSeed)
	local id = tonumber(ped.SubType)
	if kind == "angel" then
		runtime.fixed_84_angel_item_id = id or runtime.fixed_84_angel_item_id
		runtime.fixed_84_angel_item_init_seed = seed or runtime.fixed_84_angel_item_init_seed
	elseif kind == "devil" then
		runtime.fixed_84_devil_item_id = id or runtime.fixed_84_devil_item_id
		runtime.fixed_84_devil_item_init_seed = seed or runtime.fixed_84_devil_item_init_seed
	else
		runtime.fixed_84_item_id = id or runtime.fixed_84_item_id
		runtime.fixed_84_item_init_seed = seed or runtime.fixed_84_item_init_seed
	end
end

function compass_floor.ensure_fixed_84_statue(kind, ped, seed_override, pos_override)
	if kind ~= "angel" and kind ~= "devil" then
		return nil
	end
	local seed = tonumber(seed_override)
	local pos = pos_override
	if ped and ped.Exists and ped:Exists() then
		seed = seed or tonumber(ped.InitSeed)
		pos = pos or (ped.Position + Vector(0, -76))
	end
	if not seed or not pos then
		return nil
	end
	local angel_var = (EffectVariant and EffectVariant.ANGEL) or 9
	local devil_var = (EffectVariant and EffectVariant.DEVIL) or 6
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent and ent:Exists()
			and ent.Type == EntityType.ENTITY_EFFECT
			and (ent.Variant == angel_var or ent.Variant == devil_var)
		then
			local data = ent:GetData()
			if data and data.__QingGC_Fixed84Statue == kind
				and tonumber(data.__QingGC_Fixed84BoundItemSeed) == seed
			then
				return ent
			end
		end
	end
	local variant = kind == "angel" and angel_var or devil_var
	local ok, spawned = pcall(function()
		return Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, 0, pos, Vector.Zero, nil)
	end)
	if not ok or not spawned then
		return nil
	end
	pcall(function()
		spawned.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		spawned.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
		spawned.DepthOffset = -20
		local data = spawned:GetData()
		data.__QingGC_Fixed84Statue = kind
		data.__QingGC_Fixed84BoundItemSeed = seed
		local spr = spawned:GetSprite()
		if spr then
			pcall(function()
				spr:Play("Idle", true)
			end)
			pcall(function()
				spr:SetFrame(0)
			end)
		end
	end)
	return spawned
end

function compass_floor.cleanup_fixed_84_statues(keep_seed)
	keep_seed = tonumber(keep_seed)
	local removed = 0
	local angel_var = (EffectVariant and EffectVariant.ANGEL) or 9
	local devil_var = (EffectVariant and EffectVariant.DEVIL) or 6
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent and ent:Exists()
			and ent.Type == EntityType.ENTITY_EFFECT
			and (ent.Variant == angel_var or ent.Variant == devil_var)
		then
			local data = ent:GetData()
			local kind = data and data.__QingGC_Fixed84Statue
			if kind == "angel" or kind == "devil" then
				local bound = tonumber(data.__QingGC_Fixed84BoundItemSeed)
				if keep_seed == nil or bound ~= keep_seed then
					ent:Remove()
					removed = removed + 1
				end
			end
		end
	end
	return removed
end

--- Strip the losing side after rest/item choice (bed kept on rest for wake anim).
function compass_floor.cleanup_fixed_84_choice_side(tag)
	local choice = runtime.fixed_84_choice
	if choice ~= "rest" and choice ~= "item" then
		return nil
	end
	if not compass_floor.is_normal_dim_fixed_84() then
		return nil
	end
	local removed = 0
	local bed_seed = tonumber(runtime.fixed_84_bed_init_seed)
	local keep_seed = tonumber(runtime.fixed_84_chosen_item_init_seed)
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent and ent:Exists() and ent.Type == EntityType.ENTITY_PICKUP then
			local data = ent:GetData()
			local mark = data and data.__QingGC_Fixed84Choice
			local seed = tonumber(ent.InitSeed)
			local kind = compass_floor.fixed_84_item_mark_kind(mark)
			local seed_hit = select(1, compass_floor.fixed_84_seed_matches_any_item(seed))
			if choice == "rest"
				and ent.Variant == PickupVariant.PICKUP_COLLECTIBLE
				and (kind ~= nil or seed_hit)
			then
				pcall(function()
					Isaac.Spawn(
						EntityType.ENTITY_EFFECT,
						EffectVariant.POOF01 or 15,
						0,
						ent.Position,
						Vector.Zero,
						nil
					)
				end)
				ent:Remove()
				removed = removed + 1
			elseif choice == "item"
				and ent.Variant == PickupVariant.PICKUP_BED
				and (mark == "bed" or (bed_seed and seed == bed_seed))
			then
				ent:Remove()
				removed = removed + 1
			elseif choice == "item"
				and ent.Variant == PickupVariant.PICKUP_COLLECTIBLE
				and (kind ~= nil or seed_hit)
				and (keep_seed == nil or seed ~= keep_seed)
			then
				pcall(function()
					Isaac.Spawn(
						EntityType.ENTITY_EFFECT,
						EffectVariant.POOF01 or 15,
						0,
						ent.Position,
						Vector.Zero,
						nil
					)
				end)
				ent:Remove()
				removed = removed + 1
			end
		end
	end
	local statues_removed = 0
	if choice == "rest" then
		statues_removed = compass_floor.cleanup_fixed_84_statues(nil)
	else
		statues_removed = compass_floor.cleanup_fixed_84_statues(keep_seed)
	end
	local row = {
		tag = tag,
		choice = choice,
		removed = removed,
		statues_removed = statues_removed,
		keep_seed = keep_seed,
		note = "enforce losing side absent after fixed_84_choice",
	}
	push_event("fixed_84_choice_cleanup", row)
	return row
end

function compass_floor.commit_fixed_84_choice(choice, tag, extra)
	if choice ~= "rest" and choice ~= "item" then
		return nil
	end
	if runtime.fixed_84_choice == "rest" or runtime.fixed_84_choice == "item" then
		return {skipped = true, prior = runtime.fixed_84_choice}
	end
	runtime.fixed_84_choice = choice
	runtime.fixed_84_options_spawned = true
	runtime.fixed_84_sleep_pending_seed = nil
	runtime.fixed_84_sleep_pending_frame = nil
	if choice == "item" and type(extra) == "table" then
		local seed = tonumber(extra.item_init_seed)
		local kind = extra.item_kind
		if seed then
			runtime.fixed_84_chosen_item_init_seed = seed
			local matched, matched_kind = compass_floor.fixed_84_seed_matches_any_item(seed)
			runtime.fixed_84_chosen_item_kind = kind
				or (matched and matched_kind)
				or runtime.fixed_84_chosen_item_kind
				or "treasure"
		end
	elseif choice == "rest" then
		runtime.fixed_84_chosen_item_init_seed = nil
		runtime.fixed_84_chosen_item_kind = nil
	end
	compass_floor.sync_persist()
	local cleanup = compass_floor.cleanup_fixed_84_choice_side(tag)
	local room = Game():GetRoom()
	-- Rest: keep bed for wake anim. Item: bed already removed in cleanup.
	if choice == "item" or (cleanup and (cleanup.removed or 0) > 0) then
		pcall(function()
			room:SaveState()
		end)
	end
	local row = {
		tag = tag,
		choice = choice,
		cleanup = cleanup,
		extra = extra,
		options_index = runtime.fixed_84_options_index,
		chosen_item_init_seed = runtime.fixed_84_chosen_item_init_seed,
		chosen_item_kind = runtime.fixed_84_chosen_item_kind,
		note = choice == "rest"
			and "bed sleep committed; remove reward pedestals"
			or "reward pickup committed; remove bed and sibling rewards",
	}
	runtime.fixed_84_content = runtime.fixed_84_content or {}
	runtime.fixed_84_content.choice = row
	push_event("fixed_84_choice", row)
	return row
end

function compass_floor.is_fixed_84_choice_bed(bed)
	if not bed or not bed.Exists or not bed:Exists() then
		return false
	end
	if bed.Type ~= EntityType.ENTITY_PICKUP or bed.Variant ~= PickupVariant.PICKUP_BED then
		return false
	end
	local mark = bed:GetData() and bed:GetData().__QingGC_Fixed84Choice
	if mark == "bed" then
		return true
	end
	local want = tonumber(runtime.fixed_84_bed_init_seed)
	return want ~= nil and tonumber(bed.InitSeed) == want
end

--- POST_PICKUP / POST_GAIN source_context or gain_context; optional live ent from pickup callback.
function compass_floor.is_fixed_84_choice_item_source(ctx, ent)
	local function match_ent(live)
		if not live or not live.Exists or not live:Exists() then
			return false, nil
		end
		if live.Type ~= EntityType.ENTITY_PICKUP then
			return false, nil
		end
		local mark = live:GetData() and live:GetData().__QingGC_Fixed84Choice
		local kind = compass_floor.fixed_84_item_mark_kind(mark)
		if kind then
			return true, kind
		end
		local hit, hit_kind = compass_floor.fixed_84_seed_matches_any_item(live.InitSeed)
		if hit then
			return true, hit_kind
		end
		return false, nil
	end
	local ok, kind = match_ent(ent)
	if ok then
		return true, ent, kind
	end
	if type(ctx) ~= "table" then
		return false, nil, nil
	end
	ok, kind = match_ent(ctx.pedestal)
	if ok then
		return true, ctx.pedestal, kind
	end
	ok, kind = match_ent(ctx.pickup)
	if ok then
		return true, ctx.pickup, kind
	end
	local collectible_holder = require("Qing_Remaster_scripts.callbacks.collectible_holder")
	local live = collectible_holder.get_live_source_pedestal
		and collectible_holder.get_live_source_pedestal(ctx)
	ok, kind = match_ent(live)
	if ok then
		return true, live, kind
	end
	local source = collectible_holder.get_acquisition_source
		and collectible_holder.get_acquisition_source(ctx)
	if source then
		local hit, hit_kind = compass_floor.fixed_84_seed_matches_any_item(source.init_seed)
		if hit then
			return true, live or ent, hit_kind
		end
	end
	return false, live, nil
end

--- Locate live bed / reward pedestals (marks preferred, then InitSeed).
--- Returns bed, by_kind{treasure,angel,devil}, beds, items.
function compass_floor.find_fixed_84_live_options()
	local bed_seed = tonumber(runtime.fixed_84_bed_init_seed)
	local beds = {}
	local items = {}
	local by_kind = {}
	local bed_marked, bed_seeded = nil, nil
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent and ent:Exists() and ent.Type == EntityType.ENTITY_PICKUP then
			local mark = ent:GetData() and ent:GetData().__QingGC_Fixed84Choice
			local seed = tonumber(ent.InitSeed)
			if ent.Variant == PickupVariant.PICKUP_BED then
				beds[#beds + 1] = ent
				if mark == "bed" then
					bed_marked = ent
				elseif bed_seed and seed == bed_seed then
					bed_seeded = ent
				end
			elseif ent.Variant == PickupVariant.PICKUP_COLLECTIBLE
				and (tonumber(ent.SubType) or 0) > 0
			then
				items[#items + 1] = ent
				local kind = compass_floor.fixed_84_item_mark_kind(mark)
				if not kind then
					local hit, hit_kind = compass_floor.fixed_84_seed_matches_any_item(seed)
					if hit then
						kind = hit_kind
					end
				end
				if kind and not by_kind[kind] then
					by_kind[kind] = ent
				end
			end
		end
	end
	local bed = bed_marked or bed_seeded or (#beds == 1 and beds[1]) or nil
	if not by_kind.treasure and not by_kind.angel and not by_kind.devil and #items == 1 then
		by_kind.treasure = items[1]
	end
	-- Back-compat: single-item callers still get a primary ped.
	local ped = by_kind.angel or by_kind.devil or by_kind.treasure or (#items == 1 and items[1]) or nil
	return bed, ped, beds, items, by_kind
end

--- Apply / allocate shared OptionsPickupIndex for bed + all reward pedestals.
function compass_floor.apply_fixed_84_options_index(bed, peds, prefer_index)
	local idx = tonumber(prefer_index) or tonumber(runtime.fixed_84_options_index)
	if not idx or idx <= 0 then
		idx = option_index_holder.find_a_new_index and option_index_holder.find_a_new_index() or 0
	end
	if not idx or idx <= 0 then
		return nil
	end
	runtime.fixed_84_options_index = idx
	pcall(function()
		if bed then
			bed.OptionsPickupIndex = idx
		end
		if type(peds) == "table" then
			for i = 1, #peds do
				local ped = peds[i]
				if ped then
					ped.OptionsPickupIndex = idx
				end
			end
		elseif peds then
			-- Legacy single-ped call site.
			peds.OptionsPickupIndex = idx
		end
	end)
	return idx
end

function compass_floor.remount_fixed_84_mark(ent, mark)
	if not ent then
		return
	end
	pcall(function()
		ent:GetData().__QingGC_Fixed84Choice = mark
		local choice = runtime.fixed_84_choice
		if choice == "rest" or choice == "item" then
			ent.OptionsPickupIndex = 0
			return
		end
		local idx = tonumber(runtime.fixed_84_options_index)
		if idx and idx > 0 then
			ent.OptionsPickupIndex = idx
		end
	end)
end

function compass_floor.spawn_fixed_84_reward_pedestal(kind, item_id, pos)
	local ok_p, ent_p = pcall(function()
		return Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_COLLECTIBLE,
			item_id or 0,
			pos,
			Vector.Zero,
			nil
		)
	end)
	if not ok_p or not ent_p then
		return nil
	end
	local ped = ent_p:ToPickup() or ent_p
	pcall(function()
		ped.Price = 0
		if ped.AutoUpdatePrice ~= nil then
			ped.AutoUpdatePrice = false
		end
	end)
	local mark = kind == "angel" and "angel" or (kind == "devil" and "devil" or "treasure")
	compass_floor.remount_fixed_84_mark(ped, mark)
	compass_floor.fixed_84_remember_item_slot(kind, ped)
	if kind == "angel" or kind == "devil" then
		compass_floor.ensure_fixed_84_statue(kind, ped)
	end
	return ped
end

--- Note a successful can_sleep collision with the 84 bed (does not settle yet).
function compass_floor.note_fixed_84_bed_sleep_collision(bed, player, tag)
	if not session_enabled() or not runtime.corridor_active then
		push_event("fixed_84_bed_sleep_reject", {
			tag = tag,
			reason = "session_inactive",
		})
		return false
	end
	if runtime.fixed_84_choice == "rest" or runtime.fixed_84_choice == "item" then
		push_event("fixed_84_bed_sleep_reject", {
			tag = tag,
			reason = "already_chosen",
			choice = runtime.fixed_84_choice,
		})
		return false
	end
	if not compass_floor.is_normal_dim_fixed_84() then
		push_event("fixed_84_bed_sleep_reject", {
			tag = tag,
			reason = "not_fixed_84_normal",
		})
		return false
	end
	if not compass_floor.is_fixed_84_choice_bed(bed) then
		push_event("fixed_84_bed_sleep_reject", {
			tag = tag,
			reason = "bed_identity_mismatch",
			bed_seed = bed and tonumber(bed.InitSeed) or nil,
			want_seed = runtime.fixed_84_bed_init_seed,
		})
		return false
	end
	local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
	if not (auxi.can_sleep and auxi.can_sleep(player)) then
		push_event("fixed_84_bed_sleep_reject", {
			tag = tag,
			reason = "cannot_sleep",
		})
		return false
	end
	if bed.Touched == true then
		push_event("fixed_84_bed_sleep_reject", {
			tag = tag,
			reason = "bed_already_touched",
		})
		return false
	end
	runtime.fixed_84_sleep_pending_seed = tonumber(bed.InitSeed)
	runtime.fixed_84_sleep_pending_frame = Game():GetFrameCount()
	push_event("fixed_84_bed_sleep_pending", {
		tag = tag,
		bed_init_seed = runtime.fixed_84_sleep_pending_seed,
		frame = runtime.fixed_84_sleep_pending_frame,
		note = "Leave_sleep path armed; wait IN_BED / SleepFillHP",
	})
	return true
end

--- Primary rest settle: Pause_Screen IN_BED after our bed Leave_sleep arm.
function compass_floor.tick_fixed_84_sleep_choice(tag)
	if not session_enabled() or not runtime.corridor_active then
		return nil
	end
	if runtime.fixed_84_choice == "rest" or runtime.fixed_84_choice == "item" then
		return nil
	end
	local pending = tonumber(runtime.fixed_84_sleep_pending_seed)
	if not pending then
		return nil
	end
	if not compass_floor.is_normal_dim_fixed_84() then
		return nil
	end
	local pause = require("Qing_Remaster_scripts.others.Pause_Screen_holder")
	local state = pause and pause.currentState
	if not state or state.name ~= "IN_BED" then
		return nil
	end
	local bed = select(1, compass_floor.find_fixed_84_live_options())
	local live_seed = bed and tonumber(bed.InitSeed) or nil
	if live_seed ~= nil and live_seed ~= pending and not compass_floor.is_fixed_84_choice_bed(bed) then
		push_event("fixed_84_bed_sleep_reject", {
			tag = tag,
			reason = "in_bed_but_seed_mismatch",
			pending = pending,
			live_seed = live_seed,
		})
		return nil
	end
	return compass_floor.commit_fixed_84_choice("rest", tag or "pause_in_bed", {
		via = "pause_screen_in_bed",
		bed_init_seed = pending,
	})
end

--- First true visit / rewind re-enter: left bed + right reward(s) with shared Options index.
--- Virtues→angel pool+statue; Belial→devil pool+statue; both→three-way with bed.
--- States: uninitialized | initialized unchosen | chosen rest/item.
function compass_floor.spawn_84_options_on_true_enter(tag)
	if not compass_floor.is_normal_dim_fixed_84() then
		return nil
	end
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	local variant = cur and cur.Data and cur.Data.Variant
	local room = Game():GetRoom()
	local center = room:GetCenterPos()
	local choice = runtime.fixed_84_choice
	local compat = compass_state.get_compat and compass_state.get_compat() or {}
	local want_angel = compat.room84_angel == true
	local want_devil = compat.room84_devil == true
	local live_bed, live_ped, _beds, _items, by_kind = compass_floor.find_fixed_84_live_options()
	by_kind = by_kind or {}

	local function collect_peds(map)
		local out = {}
		if map.treasure then out[#out + 1] = map.treasure end
		if map.angel then out[#out + 1] = map.angel end
		if map.devil then out[#out + 1] = map.devil end
		return out
	end

	local function remount_all(bed, map)
		if bed then
			compass_floor.remount_fixed_84_mark(bed, "bed")
			runtime.fixed_84_bed_init_seed = tonumber(bed.InitSeed) or runtime.fixed_84_bed_init_seed
		end
		if map.treasure then
			compass_floor.remount_fixed_84_mark(map.treasure, "treasure")
			compass_floor.fixed_84_remember_item_slot("treasure", map.treasure)
		end
		if map.angel then
			compass_floor.remount_fixed_84_mark(map.angel, "angel")
			compass_floor.fixed_84_remember_item_slot("angel", map.angel)
			compass_floor.ensure_fixed_84_statue("angel", map.angel)
		end
		if map.devil then
			compass_floor.remount_fixed_84_mark(map.devil, "devil")
			compass_floor.fixed_84_remember_item_slot("devil", map.devil)
			compass_floor.ensure_fixed_84_statue("devil", map.devil)
		end
	end

	-- Chosen: enforce losing side; do not respawn missing options.
	if choice == "rest" or choice == "item" then
		runtime.fixed_84_options_spawned = true
		remount_all(live_bed, by_kind)
		if choice == "item" then
			local kind = runtime.fixed_84_chosen_item_kind
			local seed = tonumber(runtime.fixed_84_chosen_item_init_seed)
			if kind == "angel" or kind == "devil" then
				local kept = by_kind[kind]
				if kept then
					compass_floor.ensure_fixed_84_statue(kind, kept)
				elseif seed then
					local dual = want_angel and want_devil
					local off = (kind == "angel" and dual) and Vector(88, -76)
						or (kind == "devil" and dual) and Vector(152, -76)
						or Vector(80, -76)
					compass_floor.ensure_fixed_84_statue(kind, nil, seed, center + off)
				end
			end
		end
		return compass_floor.cleanup_fixed_84_choice_side(tag or "reenter_84_chosen")
	end

	local expected_kinds = {}
	if want_angel then
		expected_kinds[#expected_kinds + 1] = "angel"
	end
	if want_devil then
		expected_kinds[#expected_kinds + 1] = "devil"
	end
	if #expected_kinds == 0 then
		expected_kinds[1] = "treasure"
	end

	local have_all = live_bed ~= nil
	for i = 1, #expected_kinds do
		if not by_kind[expected_kinds[i]] then
			have_all = false
			break
		end
	end

	-- Unchosen but live set already present (SaveState / rewind): adopt, do not duplicate.
	if have_all then
		runtime.fixed_84_options_spawned = true
		remount_all(live_bed, by_kind)
		local peds = collect_peds(by_kind)
		local opt_idx = compass_floor.apply_fixed_84_options_index(live_bed, peds, runtime.fixed_84_options_index)
		compass_floor.sync_persist()
		local row = {
			ok = true,
			tag = tag,
			choice = choice,
			adopted = true,
			want_angel = want_angel,
			want_devil = want_devil,
			collectible_id = runtime.fixed_84_item_id,
			angel_item_id = runtime.fixed_84_angel_item_id,
			devil_item_id = runtime.fixed_84_devil_item_id,
			item_init_seed = runtime.fixed_84_item_init_seed,
			bed_init_seed = runtime.fixed_84_bed_init_seed,
			options_index = opt_idx,
			spawned_bed = false,
			ped_count = #peds,
			persisted = true,
			note = "fixed_84 adopt live bed+rewards; shared Options index remounted",
			stb_variant = variant,
		}
		runtime.fixed_84_content = runtime.fixed_84_content or {}
		runtime.fixed_84_content.options = row
		push_event("fixed_84_options_spawn", row)
		return row
	end

	-- Spawn only missing side(s).
	local bed = live_bed
	local bed_seed = bed and tonumber(bed.InitSeed) or nil
	if not bed then
		local bed_pos = center + Vector(-80, 0)
		pcall(function()
			bed_pos = room:FindFreePickupSpawnPosition(center + Vector(-80, 0), 0, true)
		end)
		local ok_b, ent_b = pcall(function()
			return Isaac.Spawn(
				EntityType.ENTITY_PICKUP,
				PickupVariant.PICKUP_BED,
				0,
				bed_pos,
				Vector.Zero,
				nil
			)
		end)
		if ok_b and ent_b then
			bed = ent_b:ToPickup() or ent_b
			compass_floor.remount_fixed_84_mark(bed, "bed")
			bed_seed = tonumber(bed.InitSeed)
		end
	else
		compass_floor.remount_fixed_84_mark(bed, "bed")
	end

	local pool = Game():GetItemPool()
	local spawn_seed = 1
	pcall(function()
		spawn_seed = room:GetSpawnSeed() or 1
	end)
	local spawned_kinds = {}

	local function offset_for(kind, dual)
		if dual then
			if kind == "angel" then
				return Vector(88, 0)
			end
			return Vector(152, 0)
		end
		return Vector(80, 0)
	end

	local dual = want_angel and want_devil
	for i = 1, #expected_kinds do
		local kind = expected_kinds[i]
		if not by_kind[kind] then
			local pool_type = ItemPoolType.POOL_TREASURE
			local persist_id = runtime.fixed_84_item_id
			if kind == "angel" then
				pool_type = ItemPoolType.POOL_ANGEL
				persist_id = runtime.fixed_84_angel_item_id
			elseif kind == "devil" then
				pool_type = ItemPoolType.POOL_DEVIL
				persist_id = runtime.fixed_84_devil_item_id
			end
			local item_id = tonumber(persist_id)
			if not item_id or item_id <= 0 then
				local kind_seed = spawn_seed
				pcall(function()
					local rng = RNG()
					rng:SetSeed(spawn_seed, 35)
					for _ = 1, i do
						kind_seed = rng:Next()
					end
				end)
				item_id = pool:GetCollectible(pool_type, true, kind_seed)
			end
			local item_pos = center + offset_for(kind, dual)
			pcall(function()
				item_pos = room:FindFreePickupSpawnPosition(center + offset_for(kind, dual), 0, true)
			end)
			local ped = compass_floor.spawn_fixed_84_reward_pedestal(kind, item_id, item_pos)
			if ped then
				by_kind[kind] = ped
				spawned_kinds[#spawned_kinds + 1] = kind
			end
		else
			local mark = kind == "treasure" and "treasure" or kind
			compass_floor.remount_fixed_84_mark(by_kind[kind], mark)
			compass_floor.fixed_84_remember_item_slot(kind, by_kind[kind])
			if kind == "angel" or kind == "devil" then
				compass_floor.ensure_fixed_84_statue(kind, by_kind[kind])
			end
		end
	end

	local peds = collect_peds(by_kind)
	local ok = bed ~= nil and #peds > 0
	local opt_idx = nil
	if ok then
		runtime.fixed_84_options_spawned = true
		runtime.fixed_84_bed_init_seed = bed_seed or runtime.fixed_84_bed_init_seed
		opt_idx = compass_floor.apply_fixed_84_options_index(bed, peds, runtime.fixed_84_options_index)
		compass_floor.sync_persist()
		pcall(function()
			room:SaveState()
		end)
	end
	local row = {
		ok = ok == true,
		tag = tag,
		choice = choice,
		want_angel = want_angel,
		want_devil = want_devil,
		collectible_id = runtime.fixed_84_item_id,
		angel_item_id = runtime.fixed_84_angel_item_id,
		devil_item_id = runtime.fixed_84_devil_item_id,
		item_init_seed = runtime.fixed_84_item_init_seed,
		angel_item_init_seed = runtime.fixed_84_angel_item_init_seed,
		devil_item_init_seed = runtime.fixed_84_devil_item_init_seed,
		bed_init_seed = bed_seed,
		options_index = opt_idx,
		spawned_bed = bed ~= nil and live_bed == nil,
		spawned_kinds = spawned_kinds,
		ped_count = #peds,
		kept_bed = live_bed ~= nil,
		persisted = ok == true,
		note = ok
			and "fixed_84 rest/reward(s): shared Options index"
			or "84 rest/reward spawn incomplete; marker not persisted",
		stb_variant = variant,
	}
	runtime.fixed_84_content = runtime.fixed_84_content or {}
	runtime.fixed_84_content.options = row
	push_event("fixed_84_options_spawn", row)
	return row
end

--- Strip 109 UP / extra Shape-4 door slots so Home secret-exit (-10) cannot attach.
local function seal_109_descriptor_up(tag)
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(ROOM_109_SGID, 0)
	local before_doors = read_desc_doors_array(desc)
	local before_allowed = desc and desc.AllowedDoors
	if not desc then
		local miss = {ok = false, tag = tag, reason = "no_109_desc"}
		push_event("109_descriptor_seal", miss)
		return miss
	end
	-- Keep LEFT/RIGHT/DOWN only for 1x1 ultra-secret topology.
	local keep = {
		[DoorSlot.LEFT0] = 108,
		[DoorSlot.RIGHT0] = 110,
		[DoorSlot.DOWN0] = 122,
	}
	local writes = {}
	for slot = 0, 7 do
		local want = keep[slot]
		local target = (want ~= nil) and want or -1
		local ok, err = set_desc_door_slot(desc, slot, target)
		writes[#writes + 1] = {slot = slot, target = target, ok = ok, error = err}
	end
	local allowed_ok, allowed_err = pcall(function()
		local mask = (1 << DoorSlot.LEFT0) | (1 << DoorSlot.RIGHT0) | (1 << DoorSlot.DOWN0)
		desc.AllowedDoors = mask
	end)
	local after_doors = read_desc_doors_array(desc)
	local result = {
		ok = allowed_ok == true,
		tag = tag,
		before_doors = before_doors,
		before_allowed = before_allowed,
		after_doors = after_doors,
		after_allowed = desc.AllowedDoors,
		writes = writes,
		allowed_ok = allowed_ok == true,
		allowed_err = allowed_ok and nil or tostring(allowed_err),
		secret_exit_idx = SECRET_EXIT_IDX,
	}
	runtime.room_109_seal = runtime.room_109_seal or {}
	runtime.room_109_seal.descriptor = result
	push_event("109_descriptor_seal", result)
	return result
end

--- After Room::Init of 109: remove live UP door if present (Home secret exit).
local function seal_109_live_up_door(tag)
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	if not cur or cur.SafeGridIndex ~= ROOM_109_SGID then
		return nil
	end
	local room = Game():GetRoom()
	local door = nil
	pcall(function()
		door = room:GetDoor(DoorSlot.UP0)
	end)
	local target = nil
	if door then
		pcall(function()
			target = door.TargetRoomIndex
		end)
	end
	local removed = false
	local remove_err = nil
	if door then
		local ok, err = pcall(function()
			room:RemoveDoor(DoorSlot.UP0)
		end)
		removed = ok == true
		remove_err = ok and nil or tostring(err)
	end
	local still = nil
	pcall(function()
		still = room:GetDoor(DoorSlot.UP0) ~= nil
	end)
	local result = {
		tag = tag,
		had_up_door = door ~= nil,
		target_room_index = target,
		is_secret_exit_target = target == SECRET_EXIT_IDX,
		removed = removed,
		remove_err = remove_err,
		still_has_up = still == true,
		secret_exit_idx = SECRET_EXIT_IDX,
	}
	runtime.room_109_seal = runtime.room_109_seal or {}
	runtime.room_109_seal.live = result
	push_event("109_special_exit_door", result)
	return result
end

--- Sample DisplayFlags from unvisited ROOM_DEFAULT rooms (exclude 84).
local function sample_unvisited_default_display_flags(exclude_sgid)
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local counts = {}
	local best, best_n = 0, 0
	local samples = 0
	local size = rooms and rooms.Size or 0
	for i = 0, size - 1 do
		local desc = rooms:Get(i)
		if desc and desc.Data
			and desc.SafeGridIndex
			and desc.SafeGridIndex ~= exclude_sgid
			and (desc.VisitedCount or 0) == 0
			and desc.Data.Type == RoomType.ROOM_DEFAULT
		then
			local f = desc.DisplayFlags or 0
			counts[tostring(f)] = (counts[tostring(f)] or 0) + 1
			samples = samples + 1
			if counts[tostring(f)] > best_n then
				best = f
				best_n = counts[tostring(f)]
			end
		end
	end
	return best, samples, counts
end

--- After ChangeRoom(78): reset 84 explore so minimap matches other unvisited defaults.
--- Does NOT change StartingRoomIndex.
local function restore_84_explore_after_entry78(tag)
	local level = Game():GetLevel()
	local id = read_level_identity()
	local desc = level:GetRoomByIdx(ORIGINAL_START_INDEX, 0)
	local before = {
		visited = desc and desc.VisitedCount,
		display_flags = desc and desc.DisplayFlags,
		starting_room_index = id.starting_room_index,
		current_room_index = id.current_room_index,
	}
	if not desc then
		local miss = {
			ok = false,
			tag = tag,
			reason = "no_84_desc",
			before = before,
		}
		runtime.restore_84_explore_result = miss
		push_event("restore_84_explore", miss)
		return miss
	end

	local ref_flags, ref_samples, ref_counts = sample_unvisited_default_display_flags(ORIGINAL_START_INDEX)
	local visited_ok, visited_err = pcall(function()
		desc.VisitedCount = 0
	end)
	local flags_ok, flags_err = pcall(function()
		desc.DisplayFlags = ref_flags
	end)
	local vis_ok = try_update_visibility()
	local refresh_ok, refresh_err = try_minimap_refresh()
	local after_desc = level:GetRoomByIdx(ORIGINAL_START_INDEX, 0)
	local after_id = read_level_identity()
	local result = {
		ok = visited_ok == true and flags_ok == true,
		tag = tag,
		before = before,
		ref_display_flags = ref_flags,
		ref_samples = ref_samples,
		ref_counts = ref_counts,
		visited_ok = visited_ok == true,
		visited_err = visited_ok and nil or tostring(visited_err),
		flags_ok = flags_ok == true,
		flags_err = flags_ok and nil or tostring(flags_err),
		update_visibility_ok = vis_ok == true,
		minimap_refresh_ok = refresh_ok == true,
		minimap_refresh_err = refresh_err,
		after = {
			visited = after_desc and after_desc.VisitedCount,
			display_flags = after_desc and after_desc.DisplayFlags,
			starting_room_index = after_id.starting_room_index,
			current_room_index = after_id.current_room_index,
		},
		starting_unchanged = after_id.starting_room_index == before.starting_room_index,
		note = "explore only; StartingRoomIndex kept",
	}
	runtime.restore_84_explore_result = result
	push_event("restore_84_explore", result)
	return result
end

--- When entering a force-place / neighbor secret room, try MakeDoor for linked slots.
local function ensure_live_doors_for_current_secret(tag)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local cur = level:GetCurrentRoomDesc()
	local sgid = cur and cur.SafeGridIndex
	if not sgid or not room then
		return nil
	end
	local interesting = {
		[95] = true,
		[97] = true,
		[98] = true,
		[108] = true,
		[109] = true,
		[110] = true,
		[122] = true,
	}
	if not interesting[sgid] then
		return nil
	end
	local actions = {}
	for _, link in ipairs(FORCE_PLACE_DOOR_LINKS) do
		local slot = nil
		if link.from == sgid then
			slot = link.slot
		elseif link.to == sgid then
			slot = OPPOSITE_DOOR_SLOT[link.slot]
		end
		if slot then
			-- Never recreate 109 UP (Home secret-exit path).
			if sgid == ROOM_109_SGID and slot == DoorSlot.UP0 then
				actions[#actions + 1] = {
					slot = slot,
					skipped = true,
					reason = "seal_109_up",
				}
			else
				local has = room:GetDoor(slot) ~= nil
				local made = nil
				if not has and room.MakeDoor then
					local mok, merr = pcall(function()
						room:MakeDoor(slot)
					end)
					made = {
						ok = mok == true,
						error = mok and nil or tostring(merr),
						has_after = room:GetDoor(slot) ~= nil,
					}
				end
				actions[#actions + 1] = {
					slot = slot,
					had_door = has,
					make_door = made,
					doors_target = cur.Doors and cur.Doors[slot],
					allowed = cur.AllowedDoors and ((cur.AllowedDoors & (1 << slot)) ~= 0),
				}
			end
		end
	end
	local row = {
		tag = tag,
		sgid = sgid,
		room_type = cur.Data and cur.Data.Type,
		variant = cur.Data and cur.Data.Variant,
		actions = actions,
	}
	push_event("ensure_live_doors", row)
	return row
end

local function snapshot_home_layout(label)
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local out = {}
	local size = rooms and rooms.Size or 0
	for i = 0, size - 1 do
		local desc = rooms:Get(i)
		if desc and desc.Data and desc.SafeGridIndex and desc.SafeGridIndex >= 0 then
			local data = desc.Data
			out[#out + 1] = {
				sgid = desc.SafeGridIndex,
				list_index = desc.ListIndex,
				visited = desc.VisitedCount,
				type = data.Type,
				variant = data.Variant,
				shape = data.Shape,
				data_doors = data.Doors,
				allowed_doors = desc.AllowedDoors,
				doors = read_desc_doors_array(desc),
				is_corridor = sgid_is_corridor(desc.SafeGridIndex),
			}
		end
	end
	table.sort(out, function(a, b)
		return (a.sgid or 0) < (b.sgid or 0)
	end)
	return {
		label = label or "home_layout",
		room_count = #out,
		rooms = out,
	}
end

--- Corridor → 25600; planned specials → room_plan cfg; other off-corridor → 25601 fallback.
--- Skips PRE-successful corridor rewrites (esp. visited 84) to avoid Shift / double-write.
--- Does NOT rebuild Doors[] / AllowedDoors / roomOffset.
local function apply_level_room_replacements(pending, current_desc)
	local results = {}
	if not pending then
		return results
	end
	local wants = pending.fill_full_corridor
		or pending.place_mode == "smoke"
		or pending.place_mode == "full"
		or pending.replace_corridor_config
		or pending.replace_offcorridor_secret
	if not wants then
		return results
	end

	local corridor_cfg = get_room_config(RoomType.ROOM_DEFAULT, ROOM_VARIANT_CORRIDOR)
	local secret_cfg = get_room_config(RoomType.ROOM_SECRET, ROOM_VARIANT_SECRET_TERRAIN)
	if not corridor_cfg then
		results[#results + 1] = {
			ok = false,
			phase = "lookup",
			kind = "corridor",
			error = "missing_config_" .. tostring(ROOM_VARIANT_CORRIDOR),
		}
	end
	if not secret_cfg then
		results[#results + 1] = {
			ok = false,
			phase = "lookup",
			kind = "off_secret",
			error = "missing_config_" .. tostring(ROOM_VARIANT_SECRET_TERRAIN),
		}
	end

	local pre_ok = pending.pre_rewritten or {}
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local size = rooms and rooms.Size or 0
	for i = 0, size - 1 do
		local desc = rooms:Get(i)
		if desc and desc.Data and desc.SafeGridIndex and desc.SafeGridIndex >= 0 then
			local sgid = desc.SafeGridIndex
			local data = desc.Data
			local before = {
				shape = data.Shape,
				variant = data.Variant,
				type = data.Type,
				visited = desc.VisitedCount,
				data_doors = data.Doors,
				allowed_doors = desc.AllowedDoors,
				doors = read_desc_doors_array(desc),
			}
			local is_corridor = sgid_is_corridor(sgid)
			local plan_cfg, plan_row = cfg_from_room_plan(pending, sgid)
			local corridor_cfg_plan, corridor_row = cfg_from_corridor_plan(pending, sgid)
			local variant
			local kind
			local cfg_room
			local expected_type = nil
			if corridor_cfg_plan then
				variant = corridor_row.variant
				kind = "corridor_plan_" .. tostring(corridor_row.kind or corridor_row.pool or "typed")
				cfg_room = corridor_cfg_plan
				expected_type = corridor_row.room_type_actual or corridor_row.room_type
			elseif is_corridor then
				variant = ROOM_VARIANT_CORRIDOR
				kind = "corridor"
				cfg_room = corridor_cfg
				expected_type = RoomType.ROOM_DEFAULT
			elseif plan_cfg then
				variant = plan_row.variant
				kind = "special_plan_" .. tostring(plan_row.pool or plan_row.room_type)
				cfg_room = plan_cfg
				expected_type = plan_row.room_type_actual or plan_row.room_type
			else
				variant = ROOM_VARIANT_SECRET_TERRAIN
				kind = "off_secret_force_1x1"
				cfg_room = secret_cfg
				expected_type = RoomType.ROOM_SECRET
			end
			local pre = pre_ok[sgid]
			-- Skip PRE-success empty corridor rooms already at target (critical for visited 84).
			-- Never skip typed corridor_plan / specials.
			if pre and pre.ok and is_corridor and before.variant == variant and not plan_cfg and not corridor_cfg_plan then
				results[#results + 1] = {
					ok = true,
					phase = "skipped",
					kind = kind,
					sgid = sgid,
					before = before,
					after = before,
					expected_variant = variant,
					expected_shape = SHAPE_1X1,
					via = "skip_pre_rewritten",
					visited = before.visited,
					reason = "already_pre_rewritten_at_target",
				}
			elseif not cfg_room then
				results[#results + 1] = {
					ok = false,
					phase = "lookup",
					kind = kind,
					sgid = sgid,
					before = before,
					error = "missing_config_" .. tostring(variant),
				}
			else
				local ok_write, how = write_desc_config(desc, cfg_room, current_desc, sgid)
				local after_ok, after_desc = get_registered_room_desc(sgid, 0)
				if current_desc and room_desc_is_registered(current_desc, sgid) then
					after_desc = current_desc
					after_ok = true
				end
				if not after_ok and after_desc == nil then
					after_desc = desc
				end
				local after_data = after_desc and after_desc.Data
				local after = {
					shape = after_data and after_data.Shape,
					variant = after_data and after_data.Variant,
					type = after_data and after_data.Type,
					visited = after_desc and after_desc.VisitedCount,
					data_doors = after_data and after_data.Doors,
					allowed_doors = after_desc and after_desc.AllowedDoors,
					doors = read_desc_doors_array(after_desc),
				}
				local type_ok = expected_type == nil or after.type == expected_type
				results[#results + 1] = {
					ok = ok_write == true and after.variant == variant and type_ok,
					phase = "applied",
					kind = kind,
					sgid = sgid,
					before = before,
					after = after,
					expected_variant = variant,
					expected_type = expected_type,
					expected_shape = SHAPE_1X1,
					shape_changed = before.shape ~= after.shape,
					via = how,
					plan_fallback = plan_row and plan_row.fallback == true,
					doors_array_note = "Doors[]/AllowedDoors not force-repaired",
				}
			end
		end
	end
	return results
end

--- Observe corridor Doors[] after place; no repair.
local function audit_corridor_doors()
	local rows = {}
	for col = CORRIDOR_LEFT, CORRIDOR_RIGHT do
		local sgid = grid_index(col, CORRIDOR_ROW)
		local ok, desc = get_registered_room_desc(sgid, 0)
		if ok and desc and desc.Data then
			rows[#rows + 1] = {
				sgid = sgid,
				registered = true,
				variant = desc.Data.Variant,
				shape = desc.Data.Shape,
				data_doors = desc.Data.Doors,
				allowed_doors = desc.AllowedDoors,
				list_index = desc.ListIndex,
				doors = read_desc_doors_array(desc),
			}
		else
			rows[#rows + 1] = {
				sgid = sgid,
				missing = true,
				registered = false,
				alias_owner = desc and desc.SafeGridIndex,
				list_index = desc and desc.ListIndex,
			}
		end
	end
	return {corridor_rooms = rows}
end

local function snapshot_level_rooms()
	local level = Game():GetLevel()
	local rooms_list = level:GetRooms()
	local out = {}
	local size = rooms_list and rooms_list.Size or 0
	for i = 0, size - 1 do
		local desc = rooms_list:Get(i)
		if desc then
			local data = desc.Data
			out[#out + 1] = {
				list_index = desc.ListIndex,
				safe_grid_index = desc.SafeGridIndex,
				visited = desc.VisitedCount,
				type = data and data.Type or nil,
				shape = data and data.Shape or nil,
				variant = data and data.Variant or nil,
				name = data and data.Name or nil,
				is_corridor = sgid_is_corridor(desc.SafeGridIndex),
			}
		end
	end
	return out
end

local function build_last_result(pending)
	local present = corridor_occupancy_from_level()
	local filled = count_corridor_present(present)
	local missing = {}
	for col = CORRIDOR_LEFT, CORRIDOR_RIGHT do
		if not present[col] then
			missing[#missing + 1] = grid_index(col, CORRIDOR_ROW)
		end
	end
	local entry_ok, desc78, entry_why = entry_78_ready()
	local replace_ok, replace_fail = 0, 0
	for _, r in ipairs(runtime.room_config_replacements or {}) do
		if r.phase == "applied" then
			if r.ok then
				replace_ok = replace_ok + 1
			else
				replace_fail = replace_fail + 1
			end
		end
	end
	local identity = read_level_identity()
	local content = pending and pending.corridor_content or nil
	local result = {
		p_mode = pending and pending.p_mode or cfg.p_mode,
		layout_callback_seen = pending and pending.layout_callback_seen == true,
		placement_path = pending and pending.placement_path or nil,
		-- Structure: 13/13 *registered* corridor RoomDescriptors.
		corridor_filled = filled,
		corridor_expected = CORRIDOR_RIGHT - CORRIDOR_LEFT + 1,
		corridor_missing = missing,
		corridor_complete = #missing == 0,
		-- Content: planned RoomConfig present for each assignment.
		content_complete = content and content.content_complete == true,
		content_ok_count = content and content.content_ok_count or nil,
		content_expected = content and content.content_expected or nil,
		content_missing = content and content.content_missing or nil,
		entry_78_exists = entry_ok == true,
		entry_78_ready = entry_ok == true,
		entry_78_ready_reason = entry_why,
		entry_78_variant = desc78 and desc78.Data and desc78.Data.Variant,
		entry_78_safe_grid_index = desc78 and desc78.SafeGridIndex,
		entry_78_list_index = desc78 and desc78.ListIndex,
		player_room = identity.current_room_index,
		player_at_78 = identity.current_room_index == PLAYER_ENTRY_INDEX,
		starting_room = identity.starting_room_index,
		stage = identity.stage,
		stage_type = identity.stage_type,
		replace_applied_ok = replace_ok,
		replace_applied_fail = replace_fail,
		conflict_count = #(runtime.placement_conflicts or {}),
		place_error = pending and pending.place_error,
		entry_blocked_reason = pending and pending.entry_blocked_reason,
		layout_attempted = pending and pending.layout_attempted == true,
		layout_planned = pending and pending.layout_planned == true,
		layout_phase = pending and pending.layout_phase or nil,
		place_mode = pending and pending.place_mode or cfg.place_mode,
		last_success_sgid = pending and pending.last_success_sgid,
		layout_ready = pending and pending.layout_ready == true,
	}
	runtime.last_result = result
	return result
end

local LAYOUT_IDLE = "idle"
local LAYOUT_PLANNED = "planned"
local LAYOUT_BUILDING = "building"
local LAYOUT_READY = "ready"
local LAYOUT_FAILED = "failed"

--- Phase 1 (MC_PRE_NEW_ROOM): plan only. NEVER call TryPlaceRoom here.
--- Snapshot original shapes before any Data rewrite; only then mutate current descriptor.
local function plan_fixed_corridor_pre(source, current_desc)
	local pending = runtime.pending
	if not pending then
		return
	end
	local phase = pending.layout_phase or LAYOUT_IDLE
	if phase ~= LAYOUT_IDLE then
		push_event("pre_new_room_plan_skipped", {
			reason = "phase_" .. tostring(phase),
			sgid = current_desc and current_desc.SafeGridIndex,
		})
		return
	end

	pending.layout_phase = "planning"
	local present, shape_conflicts = corridor_occupancy_from_level()
	local missing = {}
	for col = CORRIDOR_LEFT, CORRIDOR_RIGHT do
		if not present[col] then
			missing[#missing + 1] = {
				col = col,
				row = CORRIDOR_ROW,
				sgid = grid_index(col, CORRIDOR_ROW),
			}
		end
	end

	local corridor_cfg = get_room_config(RoomType.ROOM_DEFAULT, ROOM_VARIANT_CORRIDOR)
	local secret_cfg = get_room_config(RoomType.ROOM_SECRET, ROOM_VARIANT_SECRET_TERRAIN)
	local plan = {
		placement_phase = "pre_new_room_plan",
		source = source,
		present_count = count_corridor_present(present),
		missing = missing,
		shape_conflicts = shape_conflicts,
		corridor_cfg_ok = corridor_cfg ~= nil,
		secret_cfg_ok = secret_cfg ~= nil,
		current_sgid = current_desc and current_desc.SafeGridIndex,
		current_data_rewritten = false,
		current_rewrite_kind = nil,
	}

	-- Capture ORIGINAL Shape/Variant BEFORE mutating descriptor.Data.
	-- Cross-Shape: rewrite regardless of original Shape (corridor→25600, else→25601).
	if current_desc and current_desc.Data then
		local sgid = current_desc.SafeGridIndex
		local orig_shape = current_desc.Data.Shape
		local orig_variant = current_desc.Data.Variant
		local orig_type = current_desc.Data.Type
		local orig_data_doors = current_desc.Data.Doors
		local orig_allowed = current_desc.AllowedDoors
		local orig_doors = read_desc_doors_array(current_desc)
		plan.current_original_shape = orig_shape
		plan.current_original_variant = orig_variant
		plan.current_original_type = orig_type
		plan.current_original_data_doors = orig_data_doors
		plan.current_original_allowed_doors = orig_allowed
		plan.current_original_doors = orig_doors

		local wants_place = pending.fill_full_corridor == true
			or pending.place_mode == "smoke"
			or pending.place_mode == "full"
		if wants_place then
			local is_corridor = sgid_is_corridor(sgid)
			local cfg_room = is_corridor and corridor_cfg or secret_cfg
			local variant = is_corridor and ROOM_VARIANT_CORRIDOR or ROOM_VARIANT_SECRET_TERRAIN
			local kind = is_corridor and "corridor" or "off_secret_force_1x1"
			if not cfg_room then
				plan.current_rewrite_skipped = "missing_config_" .. tostring(variant)
			else
				-- Before 84 Room:Init: neighbor 97 must already be SECRET 1x1.
				if sgid == ORIGINAL_START_INDEX then
					plan.pre_97_secret = prepare_97_secret_before_84_init(
						pending,
						current_desc,
						"pre_before_84_init"
					)
				end
				local ok_write, how = write_desc_config(current_desc, cfg_room, current_desc, sgid)
				plan.current_data_rewritten = ok_write == true
				plan.current_rewrite_kind = kind
				plan.current_rewrite_via = how
				plan.current_after_shape = current_desc.Data and current_desc.Data.Shape
				plan.current_after_variant = current_desc.Data and current_desc.Data.Variant
				pending.pre_rewritten = pending.pre_rewritten or {}
				pending.pre_rewritten[sgid] = {
					ok = ok_write == true and plan.current_after_variant == variant,
					variant = plan.current_after_variant,
					shape = plan.current_after_shape,
					kind = kind,
					visited = current_desc.VisitedCount,
				}
				runtime.room_config_replacements[#runtime.room_config_replacements + 1] = {
					ok = ok_write == true,
					phase = "pre_plan_current",
					kind = kind,
					sgid = sgid,
					before = {
						shape = orig_shape,
						variant = orig_variant,
						data_doors = orig_data_doors,
						allowed_doors = orig_allowed,
						doors = orig_doors,
					},
					after = {
						shape = plan.current_after_shape,
						variant = plan.current_after_variant,
						data_doors = current_desc.Data and current_desc.Data.Doors,
						allowed_doors = current_desc.AllowedDoors,
						doors = read_desc_doors_array(current_desc),
					},
					expected_variant = variant,
					shape_changed = orig_shape ~= plan.current_after_shape,
					via = how,
				}
			end
		end
	end

	-- Do not abort on pre-replacement shape conflicts; POST re-reads after Data rewrite.
	if not corridor_cfg and (pending.fill_full_corridor or pending.place_mode == "smoke" or pending.place_mode == "full") then
		pending.place_error = "missing_config_" .. tostring(ROOM_VARIANT_CORRIDOR)
	elseif not secret_cfg and (pending.fill_full_corridor or pending.place_mode == "smoke" or pending.place_mode == "full") then
		pending.place_error = "missing_config_" .. tostring(ROOM_VARIANT_SECRET_TERRAIN)
	end

	runtime.place_plan = plan
	pending.layout_planned = true
	pending.layout_phase = LAYOUT_PLANNED
	pending.placement_path = "pre_plan_only"
	build_last_result(pending)
	push_event("pre_new_room_plan", {
		source = source,
		placement_phase = "pre_new_room_plan",
		present_count = plan.present_count,
		missing_count = #missing,
		shape_conflict_count = #shape_conflicts,
		corridor_cfg_ok = plan.corridor_cfg_ok,
		current_sgid = plan.current_sgid,
		current_data_rewritten = plan.current_data_rewritten,
		current_rewrite_kind = plan.current_rewrite_kind,
		place_error = pending.place_error,
		place_mode = pending.place_mode,
	})
	runtime.note = string.format(
		"planned missing=%d rewrite=%s mode=%s",
		#missing,
		tostring(plan.current_data_rewritten),
		tostring(pending.place_mode)
	)
end

--- Phase 2 (first MC_POST_NEW_ROOM): replace existing → TryPlace → audit doors.
local function build_fixed_corridor_post(source)
	local pending = runtime.pending
	if not pending then
		return
	end
	local phase = pending.layout_phase or LAYOUT_IDLE
	if phase == LAYOUT_BUILDING or phase == LAYOUT_READY or phase == LAYOUT_FAILED then
		push_event("post_build_skipped", {reason = "phase_" .. tostring(phase), source = source})
		return
	end
	if phase ~= LAYOUT_PLANNED and phase ~= LAYOUT_IDLE then
		push_event("post_build_skipped", {reason = "unexpected_phase_" .. tostring(phase), source = source})
		return
	end

	pending.layout_phase = LAYOUT_BUILDING
	local place_mode = pending.place_mode or cfg.place_mode or "smoke"
	local wants_place = pending.fill_full_corridor == true
		or place_mode == "smoke"
		or place_mode == "full"

	if not wants_place then
		pending.corridor_ensured = true
		pending.layout_ready = true
		pending.layout_phase = LAYOUT_READY
		pending.placement_path = pending.layout_callback_seen and "layout_only" or "none"
		runtime.activate_stageapi_layout_guard(pending, source or "layout_only")
		compass_floor.notify_stageapi_bind_probe("layout_ready_layout_only", {source = source})
		build_last_result(pending)
		push_event("corridor_ensure_done", {
			source = source,
			placement_phase = "post_new_room",
			placement_path = pending.placement_path,
			layout_ready = true,
			place_mode = place_mode,
		})
		return
	end

	-- 1) Snapshot original Home layout BEFORE mass rewrite.
	runtime.home_layout_snapshot = snapshot_home_layout("pre_replace")
	push_event("home_layout_snapshot", {
		source = source,
		room_count = runtime.home_layout_snapshot.room_count,
		rooms = runtime.home_layout_snapshot.rooms,
	})

	-- 1b) Special side rooms + 78–90 corridor_room_plan (Boss@89 / deal@90) before rewrite/Place.
	-- Reuse PRE-built plan when 97 was already written before 84 Init.
	if not pending.room_plan then
		build_special_room_plan(pending)
	end
	build_corridor_and_boss_plans(pending)
	compass_floor.notify_stageapi_bind_probe("after_plan", {source = source})

	-- 2) Replace existing rooms (corridor 25600 / planned specials / else 25601).
	local applied = apply_level_room_replacements(pending, nil)
	compass_floor.notify_stageapi_bind_probe("after_replace", {
		source = source,
		replace_count = #applied,
	})
	for _, row in ipairs(applied) do
		runtime.room_config_replacements[#runtime.room_config_replacements + 1] = row
	end
	local after_replace = snapshot_home_layout("post_replace")
	push_event("room_replacements_applied", {
		source = source,
		placement_phase = "post_new_room_before_try_place",
		count = #applied,
		shape_changed = (function()
			local n = 0
			for _, r in ipairs(applied) do
				if r.shape_changed then
					n = n + 1
				end
			end
			return n
		end)(),
		after_rooms = after_replace.rooms,
	})

	-- 2b) Current room (84): Data is 25600 but Init already spawned Home content.
	-- Clear residue + spawn from Data.Spawns (no RGON ReloadRoom / PlaceRoom re-init).
	local cur_id = read_level_identity()
	if cur_id.current_room_index == ORIGINAL_START_INDEX then
		rematerialize_current_room_from_data("post_replace_before_try_place")
	end

	local attempts, conflicts, err
	local last_success_sgid = nil
	if pending.layout_callback_seen and pending.layout_fill_ok then
		pending.placement_path = "layout_generated"
		attempts = runtime.place_attempts
		conflicts = runtime.placement_conflicts
		err = pending.place_error
	else
		local opts = {}
		if place_mode == "smoke" then
			opts.max_new_places = 1
			pending.placement_path = "post_replace_then_smoke"
		else
			pending.placement_path = "post_replace_then_try_place"
		end
		-- 3) TryPlace AFTER Data rewrite so CanPlaceRoom sees new Shape/Doors.
		attempts, conflicts, err = ensure_corridor_try_place(pending, opts)
		pending.place_error = err
		runtime.place_attempts = attempts
		runtime.placement_conflicts = conflicts
		for i = #attempts, 1, -1 do
			local a = attempts[i]
			if a.ok and a.last_success_sgid then
				last_success_sgid = a.last_success_sgid
				break
			elseif a.ok and a.sgid and not a.reused then
				last_success_sgid = a.sgid
				break
			end
		end
		push_event("try_place_build", {
			source = source,
			placement_phase = "post_new_room",
			placement_path = pending.placement_path,
			place_mode = place_mode,
			place_ok = (function()
				local n = 0
				for _, a in ipairs(attempts) do
					if a.ok and not a.reused then
						n = n + 1
					end
				end
				return n
			end)(),
			conflict_count = #conflicts,
			error = err,
			last_success_sgid = last_success_sgid,
			failed_targets = (function()
				local out = {}
				for _, a in ipairs(attempts) do
					if not a.ok and not a.skipped and a.sgid then
						out[#out + 1] = a.sgid
					end
				end
				return out
			end)(),
			layout_callback_seen = pending.layout_callback_seen == true,
		})
	end

	-- 4) Observe corridor Doors[] after TryPlace.
	runtime.connection_audit = audit_corridor_doors()
	push_event("door_audit", {
		source = source,
		audit = runtime.connection_audit,
	})

	-- Completeness gate before any final topology writes / alias Place / map baseline.
	local present_gate = corridor_occupancy_from_level()
	local filled_gate = count_corridor_present(present_gate)
	local corridor_13 = filled_gate == (CORRIDOR_RIGHT - CORRIDOR_LEFT + 1) and err == nil

	-- 5) Force PlaceRoom 108/110/122 + normalize ONLY on full 13/13.
	-- Partial builds must not wipe Doors[] into an incomplete map.
	if (place_mode == "full" or pending.fill_full_corridor) and corridor_13 then
		force_place_alias_batch(source, pending)
		normalize_door_topology(source)
		fix_live_84_secret_door_to_97(source)
	elseif place_mode == "full" or pending.fill_full_corridor then
		push_event("topology_finalize_skipped", {
			reason = "corridor_incomplete",
			filled = filled_gate,
			need = (CORRIDOR_RIGHT - CORRIDOR_LEFT + 1),
			place_error = err,
			note = "skip force-place aliases + normalize + secret-door observe",
		})
	end

	-- 5b) Baseline map snapshot only after a complete corridor (settle still waits enter 78).
	if corridor_13 and map_resolver and map_resolver.snapshot_rooms then
		runtime.map_baseline = map_resolver.snapshot_rooms("post_layout")
		push_event("map_baseline_snapshot", runtime.map_baseline)
	elseif map_resolver_load_error then
		push_event("map_visibility_settlement_error", {
			phase = "post_layout_baseline",
			module = MAP_RESOLVER_PATH,
			error = map_resolver_load_error,
		})
	elseif not corridor_13 then
		push_event("map_baseline_skipped", {
			reason = "corridor_incomplete",
			filled = filled_gate,
		})
	end

	-- 6) Multi-cell occupancy alias probe (query grid vs owner SafeGridIndex).
	local occupancy = probe_occupancy_aliases()
	runtime.occupancy_probe = occupancy
	push_event("occupancy_alias_probe", {
		source = source,
		rows = occupancy,
		alias_count = (function()
			local n = 0
			for _, r in ipairs(occupancy) do
				if r.alias then
					n = n + 1
				end
			end
			return n
		end)(),
		force_place = runtime.force_place_batch_result,
	})

	-- 7) Minimap.Refresh — may clear visual residue; does not rebuild roomOffset.
	local refresh_ok, refresh_err = try_minimap_refresh()
	push_event("minimap_refresh", {
		source = source,
		ok = refresh_ok == true,
		error = refresh_err,
	})

	-- Live content of the room we are currently in (usually native start 84).
	emit_live_room_content("post_build_current")

	local present = corridor_occupancy_from_level()
	local filled = count_corridor_present(present)
	local entry_ok, _entry_desc, entry_why = entry_78_ready()
	pending.corridor_ensured = true
	pending.last_success_sgid = last_success_sgid
	pending.entry_78_ready_reason = entry_why

	local content = pending.corridor_content
	local content_ok = content and content.content_complete == true
	if place_mode == "smoke" then
		pending.corridor_complete = false
		pending.entry_room_ready = entry_ok == true
		pending.layout_ready = err == nil and content_ok == true
		pending.enter_player_entry = false
	else
		pending.corridor_complete = filled == (CORRIDOR_RIGHT - CORRIDOR_LEFT + 1) and err == nil
		pending.entry_room_ready = entry_ok == true
		-- Structure (13 registered SGIDs) + entry@78 DEFAULT/25600 + content plan.
		pending.layout_ready = pending.corridor_complete and entry_ok == true and content_ok == true
	end
	pending.layout_phase = pending.layout_ready and LAYOUT_READY or LAYOUT_FAILED
	if pending.layout_ready then
		compass_state.mark_layout_ready(true)
		-- Encounter commit waits for first enter 89 (StageAPI may still bind Boss LevelRoom).
		runtime.activate_stageapi_layout_guard(pending, source or "layout_ready")
	else
		compass_state.mark_layout_ready(false)
		if compass_state.phase() == "generating" then
			local fail_why = "layout_ensure_failed"
			if pending.corridor_complete and entry_ok and not content_ok then
				fail_why = "corridor_content_incomplete"
			elseif pending.corridor_complete and not entry_ok then
				fail_why = entry_why or "entry_78_not_ready"
			end
			compass_state.fail_generation(fail_why)
		end
	end
	compass_floor.notify_stageapi_bind_probe(
		pending.layout_ready and "layout_ready" or "layout_failed",
		{
			source = source,
			corridor_complete = pending.corridor_complete,
			content_ok = content_ok,
			entry_ok = entry_ok == true,
		}
	)
	build_last_result(pending)
	push_event("corridor_ensure_done", {
		source = source,
		placement_phase = "post_new_room",
		placement_path = pending.placement_path,
		place_mode = place_mode,
		corridor_filled = filled,
		corridor_complete = pending.corridor_complete,
		content_complete = content_ok,
		content_missing = content and content.content_missing or nil,
		layout_ready = pending.layout_ready,
		layout_phase = pending.layout_phase,
		entry_room_ready = pending.entry_room_ready,
		entry_78_ready_reason = entry_why,
		last_success_sgid = last_success_sgid,
		minimap_refresh_ok = refresh_ok == true,
		error = err,
	})
	runtime.note = string.format(
		"build[%s/%s] filled=%d/13 content=%s ready=%s err=%s",
		tostring(pending.placement_path),
		tostring(place_mode),
		filled,
		tostring(content_ok),
		tostring(pending.layout_ready),
		tostring(err)
	)
end

-- Legacy aliases
local function prepare_fixed_corridor(source, current_desc)
	plan_fixed_corridor_pre(source, current_desc)
end

local function ensure_corridor_for_pending(source, current_desc)
	if current_desc then
		plan_fixed_corridor_pre(source, current_desc)
	else
		build_fixed_corridor_post(source)
	end
end

-- --- generator-time path (may never run on Home) ---

local function plan_and_fill_full_corridor_generator(level_generator)
	local attempts = {}
	local conflicts = {}
	local occupancy = {}

	local function refresh()
		occupancy = {}
		local rooms = snapshot_all_generator_rooms(level_generator)
		for _, r in ipairs(rooms) do
			if r.col ~= nil and r.row ~= nil then
				occupancy[r.col .. "," .. r.row] = r
			end
		end
		return rooms
	end

	refresh()
	for col = CORRIDOR_LEFT, CORRIDOR_RIGHT do
		local hit = occupancy[col .. "," .. CORRIDOR_ROW]
		if hit and hit.shape ~= SHAPE_1X1 then
			conflicts[#conflicts + 1] = {
				kind = "shape_conflict",
				col = col,
				row = CORRIDOR_ROW,
				sgid = grid_index(col, CORRIDOR_ROW),
				shape = hit.shape,
				generation_index = hit.generation_index,
			}
		end
	end
	if #conflicts > 0 then
		return attempts, conflicts, "corridor_shape_conflicts"
	end

	local function present_cols()
		local set = {}
		for col = CORRIDOR_LEFT, CORRIDOR_RIGHT do
			local hit = occupancy[col .. "," .. CORRIDOR_ROW]
			if hit and hit.shape == SHAPE_1X1 then
				set[col] = hit
			end
		end
		return set
	end

	for _ = 1, 20 do
		refresh()
		local present = present_cols()
		local miss = {}
		for col = CORRIDOR_LEFT, CORRIDOR_RIGHT do
			if not present[col] then
				miss[#miss + 1] = col
			end
		end
		if #miss == 0 then
			return attempts, conflicts, nil
		end
		if next(present) == nil then
			local any = snapshot_all_generator_rooms(level_generator)
			if #any == 0 then
				return attempts, conflicts, "no_generator_rooms"
			end
			local origin = find_slot_by_generation(level_generator, any[1].generation_index)
			local seed_col = ORIGINAL_START_INDEX % LEVEL_GRID_WIDTH
			local new_gen, ok, err = safe_call(
				level_generator.PlaceRoom,
				level_generator,
				seed_col,
				CORRIDOR_ROW,
				SHAPE_1X1,
				origin
			)
			local attempt = {
				kind = "seed_corridor",
				col = seed_col,
				ok = ok and new_gen ~= nil,
				generation_index = new_gen,
				error = (not ok and err) or (new_gen == nil and "PlaceRoom nil") or nil,
			}
			attempts[#attempts + 1] = attempt
			if not attempt.ok then
				conflicts[#conflicts + 1] = attempt
				return attempts, conflicts, "seed_place_failed"
			end
		else
			local progressed = false
			present = present_cols()
			for col = CORRIDOR_LEFT, CORRIDOR_RIGHT do
				if not present[col] then
					local neighbor = present[col - 1] or present[col + 1]
					if neighbor then
						local origin = find_slot_by_generation(level_generator, neighbor.generation_index)
						local new_gen, ok, err = safe_call(
							level_generator.PlaceRoom,
							level_generator,
							col,
							CORRIDOR_ROW,
							SHAPE_1X1,
							origin
						)
						local attempt = {
							kind = "fill_corridor",
							col = col,
							sgid = grid_index(col, CORRIDOR_ROW),
							ok = ok and new_gen ~= nil,
							generation_index = new_gen,
							error = (not ok and err) or (new_gen == nil and "PlaceRoom nil") or nil,
						}
						attempts[#attempts + 1] = attempt
						if attempt.ok then
							progressed = true
							refresh()
							present = present_cols()
						else
							conflicts[#conflicts + 1] = attempt
						end
					end
				end
			end
			if not progressed then
				for col = CORRIDOR_LEFT, CORRIDOR_RIGHT do
					if not present_cols()[col] then
						conflicts[#conflicts + 1] = {
							kind = "unfilled",
							col = col,
							sgid = grid_index(col, CORRIDOR_ROW),
						}
					end
				end
				return attempts, conflicts, "corridor_incomplete"
			end
		end
	end
	return attempts, conflicts, "corridor_incomplete"
end

local function try_append_corridor(level_generator, extra)
	local attempts = {}
	extra = math.max(0, math.floor(tonumber(extra) or 0))
	if extra <= 0 or not level_generator or not level_generator.PlaceRoom then
		return attempts, extra <= 0 and nil or "no PlaceRoom"
	end
	local rooms = snapshot_all_generator_rooms(level_generator)
	if #rooms == 0 then
		return attempts, "empty"
	end
	local tip = rooms[1]
	for _, r in ipairs(rooms) do
		if (r.col or -1) > (tip.col or -1) then
			tip = r
		end
	end
	local origin_gen, col, row = tip.generation_index, tip.col or 0, tip.row or 0
	for i = 1, extra do
		local origin = find_slot_by_generation(level_generator, origin_gen)
		local next_col = col + 1
		local attempt = {i = i, col = next_col, row = row, from_gen = origin_gen}
		if not origin or next_col > 12 then
			attempt.ok = false
			attempt.error = not origin and "origin missing" or "col out of range"
			attempts[#attempts + 1] = attempt
			break
		end
		local new_gen, ok, err = safe_call(level_generator.PlaceRoom, level_generator, next_col, row, SHAPE_1X1, origin)
		attempt.ok = ok and new_gen ~= nil
		attempt.generation_index = new_gen
		attempt.error = (not ok and err) or (new_gen == nil and "PlaceRoom nil") or nil
		attempts[#attempts + 1] = attempt
		if not attempt.ok then
			break
		end
		origin_gen, col = new_gen, next_col
	end
	return attempts, nil
end

apply_mode_flags = function(mode)
	cfg.p_mode = mode
	cfg.arm_home_layout = true
	cfg.restore_identity = true
	cfg.append_corridor = false
	cfg.enter_player_entry = false
	cfg.replace_corridor_config = true
	cfg.replace_offcorridor_secret = true
	cfg.fill_full_corridor = false
	cfg.place_mode = "smoke"
	if mode == "smoke" then
		cfg.fill_full_corridor = true
		cfg.place_mode = "smoke"
		cfg.enter_player_entry = false
		cfg.p_mode = "smoke"
	elseif mode == "main" or mode == "p2c" then
		-- Cross-Shape experiment: replace all → TryPlace 78–90 → enter 78 if ready.
		cfg.fill_full_corridor = true
		cfg.enter_player_entry = true
		cfg.place_mode = "full"
		cfg.p_mode = mode == "p2c" and "p2c" or "main"
	elseif mode == "p2b" then
		cfg.fill_full_corridor = true
		cfg.enter_player_entry = true
		cfg.place_mode = "full"
	elseif mode == "p2a" then
		cfg.fill_full_corridor = true
		cfg.place_mode = "full"
	elseif mode == "p1" then
		cfg.append_corridor = true
		cfg.place_mode = "full"
		if (cfg.corridor_extra or 0) < 1 then
			cfg.corridor_extra = 3
		end
	end
end

local function disarm_arm_flags()
	if cfg.auto_disarm then
		cfg.arm_home_layout = false
		cfg.append_corridor = false
	end
end

local function reset_corridor_session(reason)
	set_natural_deal_suppress(false)
	set_deal_guarantee(false)
	runtime.pending = nil
	runtime.double_transitioning = false
	runtime.identity_restored_seen = false
	runtime.continue_current_room_pending = false
	runtime.boss_89_visit_active = false
	runtime.boss_89_visit_init_tag = nil
	runtime.last_corridor_sgid = nil
	runtime.deal_type_source = nil
	runtime.corridor_active = false
	runtime.corridor_deal_type = nil
	runtime.corridor_force_boss = nil
	runtime.block_curses = false
	compass_floor.clear_fixed_84_runtime()
	runtime.mirror_79_knife_piece_spawned = false
	runtime.mineshaft_plank_hits = 0
	runtime.mineshaft_collapsed = false
	runtime.mineshaft_collapse_anim_done = false
	runtime.mineshaft_reward_visited = false
	runtime.mineshaft_boom_seen = {}
	runtime.special_quest_mineshaft_enter = nil
	runtime.special_quest_mineshaft_plank = nil
	runtime.special_quest_mineshaft_planks_visual = nil
	runtime.mineshaft_dim1_scan = nil
	runtime.mineshaft_dim1_scan_summary = nil
	runtime.mineshaft_dim1_scan_fingerprint = nil
	runtime.mineshaft_reward_place = nil
	runtime.special_quest_mirror_79_knife = nil
	runtime.special_quest_mirror_corridor = nil
	runtime.mirror_corridor_ready = false
	runtime.boss_90_entered = false
	runtime.boss_90_clear_logged = false
	runtime.boss_90_enter = nil
	runtime.boss_90_combat = nil
	runtime.boss_90_clear = nil
	runtime.boss_89_trapdoor = nil
	runtime.boss_89_trapdoor_pending_retry = nil
	runtime.boss_89_timed_door = nil
	runtime.timed_door_strange_key_seen = false
	runtime.mom_photo_reward_done = false
	runtime.deal_appear_sfx_played = false
	runtime.deal_appear_sfx_logged = false
	runtime.boss_89_visit_had_combat = false
	runtime.boss_89_deal_door = nil
	runtime.boss_89_door_restore = nil
	runtime.boss_89_mom_sim_door = nil
	runtime.deal_door_sprite_watch = nil
	runtime.deal_90_seal_init_done = false
	runtime.negative_rooms = nil
	runtime.secret_exit_spawn = nil
	runtime.secret_exit_attempted_this_visit = false
	runtime.curse_clear = nil
	runtime.corridor_door_gate = nil
	runtime.corridor_door_gate_log_key = nil
	runtime.corridor_door_gate_fail_count = 0
	runtime.corridor_door_gate_open_fail_logged = false
	runtime.empty_78_result = nil
	runtime.map_settlement_done = false
	runtime.map_settlement = nil
	disarm_arm_flags()
	cfg.arm_home_layout = false
	runtime.note = "session reset: " .. tostring(reason)
	push_event("corridor_session_reset", {reason = reason})
end

local function begin_pending(from_stage, from_type, source)
	runtime.map_settlement_done = false
	runtime.map_settlement = nil
	runtime.room_109_seal = nil
	local force_boss = runtime.force_boss_subtype_once
	runtime.force_boss_subtype_once = nil
	local force_sa = runtime.force_stageapi_boss_once
	runtime.force_stageapi_boss_once = nil
	-- Do not clear STATE_BACKWARDS_PATH_INIT here — only manual witness / force-Mom test buttons.
	runtime.block_curses = true
	runtime.negative_rooms = nil
	runtime.secret_exit_spawn = nil
	runtime.curse_clear = nil
	runtime.pending = {
		source = source,
		p_mode = cfg.p_mode,
		generator_stage = HOME_STAGE,
		generator_stage_type = HOME_STAGE_TYPE,
		restore_stage = from_stage,
		restore_stage_type = from_type,
		append_corridor = cfg.append_corridor == true,
		corridor_extra = cfg.corridor_extra,
		restore_identity = cfg.restore_identity == true,
		enter_player_entry = cfg.enter_player_entry == true,
		entry_change_api = cfg.entry_change_api,
		replace_corridor_config = cfg.replace_corridor_config == true,
		replace_offcorridor_secret = cfg.replace_offcorridor_secret == true,
		fill_full_corridor = cfg.fill_full_corridor == true
			or cfg.p_mode == "smoke"
			or cfg.p_mode == "main"
			or cfg.p_mode == "p2a"
			or cfg.p_mode == "p2b"
			or cfg.p_mode == "p2c",
		place_mode = cfg.place_mode or "smoke",
		experiment_keep_start_unvisited = cfg.experiment_keep_start_unvisited == true,
		force_boss_subtype = force_boss,
		force_stageapi_any = force_sa == true,
		force_stageapi_boss_id = type(force_sa) == "string" and force_sa or nil,
		layout_callback_seen = false,
		layout_fill_ok = false,
		layout_attempted = false,
		layout_planned = false,
		layout_phase = LAYOUT_IDLE,
		layout_ready = false,
		pre_rewritten = {},
		corridor_ensured = false,
		corridor_complete = false,
		entry_room_ready = false,
		last_success_sgid = nil,
		identity_restored = false,
		created_at = game_frame(),
		target_grid = {
			row = CORRIDOR_ROW,
			left = CORRIDOR_LEFT,
			right = CORRIDOR_RIGHT,
			player_entry = PLAYER_ENTRY_INDEX,
			original_start = ORIGINAL_START_INDEX,
			corridor_variant = ROOM_VARIANT_CORRIDOR,
			secret_variant = ROOM_VARIANT_SECRET_TERRAIN,
		},
	}
	runtime.place_attempts = {}
	runtime.placement_conflicts = {}
	runtime.room_config_replacements = {}
	runtime.place_plan = {}
	runtime.layout_snapshot = nil
	runtime.level_snapshot = nil
	runtime.last_result = nil
	runtime.corridor_room_plan = nil
	runtime.stageapi_layout_guard_result = nil
	do
		local guard = runtime.stageapi_layout_guard
			or package.loaded["Qing_Remaster_scripts.items.golden_compass.stageapi_layout_guard"]
		if type(guard) == "table" and type(guard.clear) == "function" then
			pcall(guard.clear)
		end
	end
	runtime.boss_90_plan = nil
	runtime.boss_90_enter = nil
	runtime.boss_90_combat = nil
	runtime.boss_90_clear = nil
	runtime.boss_90_entered = false
	runtime.boss_90_clear_logged = false
	runtime.boss_89_trapdoor = nil
	runtime.boss_89_trapdoor_pending_retry = nil
	runtime.boss_89_timed_door = nil
	runtime.timed_door_strange_key_seen = false
	runtime.mom_photo_reward_done = false
	runtime.deal_appear_sfx_played = false
	runtime.deal_appear_sfx_logged = false
	runtime.boss_89_visit_had_combat = false
	runtime.boss_89_deal_door = nil
	runtime.boss_89_door_restore = nil
	runtime.boss_89_mom_sim_door = nil
	runtime.deal_door_sprite_watch = nil
	runtime.deal_90_seal_init_done = false
	runtime.corridor_active = false
	runtime.corridor_deal_type = nil
	runtime.corridor_force_boss = force_boss
	compass_floor.clear_fixed_84_runtime()
	runtime.mirror_79_knife_piece_spawned = false
	runtime.mineshaft_plank_hits = 0
	runtime.mineshaft_collapsed = false
	runtime.mineshaft_collapse_anim_done = false
	runtime.mineshaft_reward_visited = false
	runtime.mineshaft_boom_seen = {}
	runtime.special_quest_mineshaft_enter = nil
	runtime.special_quest_mineshaft_plank = nil
	runtime.special_quest_mineshaft_planks_visual = nil
	runtime.mineshaft_dim1_scan = nil
	runtime.mineshaft_dim1_scan_summary = nil
	runtime.mineshaft_dim1_scan_fingerprint = nil
	runtime.mineshaft_reward_place = nil
	runtime.special_quest_mirror_79_knife = nil
	runtime.special_quest_mirror_corridor = nil
	runtime.mirror_corridor_ready = false
	runtime.empty_78_result = nil
	runtime.corridor_door_gate = nil
	runtime.corridor_door_gate_log_key = nil
	runtime.corridor_door_gate_fail_count = 0
	runtime.corridor_door_gate_open_fail_logged = false
	runtime.deal_90_preplace = nil
	runtime.boss_89_place = nil
	runtime.curse_72_plan = nil
	runtime.curse_72_place = nil
	runtime.pre_97_secret = nil
	runtime.live_84_secret_door = nil
	runtime.door_topology_normalize = nil
	set_natural_deal_suppress(false)
	runtime.session_id = (runtime.session_id or 0) + 1
	runtime.note = string.format(
		"armed %s → Home then restore %s/%s%s",
		tostring(cfg.p_mode),
		tostring(from_stage),
		tostring(from_type),
		force_boss and (" force_boss=" .. tostring(force_boss)) or ""
	)
	push_event("arm_consumed", {
		source = source,
		p_mode = cfg.p_mode,
		restore_stage = from_stage,
		restore_stage_type = from_type,
		force_boss_subtype = force_boss,
		pending = runtime.pending,
	})
end

function item.get_config()
	local c = {
		enabled = cfg.enabled,
		arm_home_layout = cfg.arm_home_layout,
		p_mode = cfg.p_mode,
		place_mode = cfg.place_mode,
		append_corridor = cfg.append_corridor,
		corridor_extra = cfg.corridor_extra,
		restore_identity = cfg.restore_identity,
		enter_player_entry = cfg.enter_player_entry,
		entry_change_api = cfg.entry_change_api,
		replace_corridor_config = cfg.replace_corridor_config,
		replace_offcorridor_secret = cfg.replace_offcorridor_secret,
		experiment_keep_start_unvisited = cfg.experiment_keep_start_unvisited,
		auto_disarm = cfg.auto_disarm,
		witness_mausoleum_test = cfg.witness_mausoleum_test == true,
		detail_logging = cfg.detail_logging == true,
		pending = runtime.pending ~= nil,
		layout_phase = runtime.pending and runtime.pending.layout_phase or nil,
		note = runtime.note,
		event_count = #runtime.events,
		session_id = runtime.session_id,
		layout_room_count = runtime.layout_snapshot and #(runtime.layout_snapshot.rooms or {}) or 0,
		level_room_count = runtime.level_snapshot and #(runtime.level_snapshot.rooms or {}) or 0,
		conflict_count = #(runtime.placement_conflicts or {}),
		corridor_variant = ROOM_VARIANT_CORRIDOR,
		secret_variant = ROOM_VARIANT_SECRET_TERRAIN,
		force_boss_subtype_once = runtime.force_boss_subtype_once,
		force_boss_subtype_pending = runtime.pending and runtime.pending.force_boss_subtype or nil,
		corridor_active = runtime.corridor_active == true,
		corridor_deal_type = runtime.corridor_deal_type,
		corridor_force_boss = runtime.corridor_force_boss,
		last_result = runtime.last_result,
	}
	return c
end

function item.status_text()
	local force_q = runtime.force_boss_subtype_once
	local force_p = runtime.pending and runtime.pending.force_boss_subtype
	local force_s = ""
	if force_q then
		force_s = " forceQ=" .. tostring(force_q)
	elseif force_p then
		force_s = " forceP=" .. tostring(force_p)
	end
	local witness_s = ""
	if cfg.witness_mausoleum_test then
		witness_s = " | " .. item.witness_status_text()
	end
	local blue_s = ""
	local blue = runtime.boss_89_blue_womb_force_test
	if blue then
		blue_s = string.format(
			" | blueForce api=%s door=%s→%s flag=%s→%s",
			tostring(blue.api_result),
			tostring(blue.door_before),
			tostring(blue.door_after),
			tostring(blue.state_flagged_before),
			tostring(blue.state_flagged_after)
		)
	end
	local r = runtime.last_result
	if r then
		return string.format(
			"mode=%s place=%s phase=%s path=%s filled=%s/%s miss=%s content=%s ready=%s entry78=%s last=%s%s | %s",
			tostring(r.p_mode),
			tostring(r.place_mode),
			tostring(r.layout_phase),
			tostring(r.placement_path),
			tostring(r.corridor_filled),
			tostring(r.corridor_expected),
			tostring(r.corridor_missing and #r.corridor_missing or 0),
			tostring(r.content_complete),
			tostring(r.layout_ready),
			tostring(r.entry_78_exists),
			tostring(r.last_success_sgid),
			force_s,
			tostring(r.entry_blocked_reason or r.place_error or runtime.note)
		) .. witness_s .. blue_s
	end
	return string.format(
		"en=%s mode=%s place=%s arm=%s pending=%s%s | %s",
		tostring(cfg.enabled),
		tostring(cfg.p_mode),
		tostring(cfg.place_mode),
		tostring(cfg.arm_home_layout),
		tostring(runtime.pending ~= nil),
		force_s,
		tostring(runtime.note)
	) .. witness_s .. blue_s
end

function item.force_try_blue_womb_door(tag)
	return boss_exits.force_try_blue_womb_door(tag or "probe_force_blue_womb")
end

function item.set_enabled(on)
	cfg.enabled = on == true
	if not session_enabled() then
		cfg.arm_home_layout = false
		runtime.pending = nil
		runtime.double_transitioning = false
		runtime.note = "disabled"
	else
		runtime.note = "enabled — use 武装下一层直道测试"
	end
end

function item.set_detail_logging(on)
	cfg.detail_logging = on == true
	runtime.note = "detail_logging=" .. tostring(cfg.detail_logging)
end

function item.get_detail_logging()
	return cfg.detail_logging == true
end

function item.set_arm_home_layout(on)
	cfg.arm_home_layout = on == true
	if cfg.arm_home_layout then
		cfg.enabled = true
	end
end

function item.set_append_corridor(on)
	cfg.append_corridor = on == true
end

function item.set_corridor_extra(n)
	cfg.corridor_extra = math.max(0, math.min(8, math.floor(tonumber(n) or 0)))
end

function item.set_restore_identity(on)
	cfg.restore_identity = on == true
end

function item.set_enter_player_entry(on)
	cfg.enter_player_entry = on == true
end

function item.set_entry_change_api(api)
	if api == "level" or api == "game" then
		cfg.entry_change_api = api
	end
end

function item.set_replace_corridor_config(on)
	cfg.replace_corridor_config = on == true
end

function item.set_replace_offcorridor_secret(on)
	cfg.replace_offcorridor_secret = on == true
end

function item.set_experiment_keep_start_unvisited(on)
	cfg.experiment_keep_start_unvisited = on == true
end

function item.set_auto_disarm(on)
	cfg.auto_disarm = on == true
end

function item.set_p_mode(mode)
	if mode == "smoke"
		or mode == "main"
		or mode == "p0"
		or mode == "p1"
		or mode == "p2a"
		or mode == "p2b"
		or mode == "p2c"
	then
		apply_mode_flags(mode)
		cfg.enabled = true
		runtime.note = "mode=" .. mode
	end
end

--- Primary one-click: full corridor + planned specials + Place aliases + map settle.
function item.arm_main_test()
	cfg.enabled = true
	apply_mode_flags("main")
	runtime.note = "armed v27: neg rooms seeds/Clear/Visit/Flags + RGON wipe; deal stable; challenge Ambush skin"
	push_event("arm_main", {
		note = runtime.note,
		place_mode = "full",
		force_boss_subtype_queued = runtime.force_boss_subtype_once,
	})
end

--- Queue one-shot BossType.MOM for the next armed corridor build (missing-door restore probe).
--- Does not change normal BossPool; fails loudly if no Mom 1x1 L/R layout exists.
function item.arm_force_mom_next()
	runtime.force_boss_subtype_once = BOSS_TYPE_MOM
	runtime.note = "queued force BossType.MOM=" .. tostring(BOSS_TYPE_MOM) .. " for next 武装直道"
	push_event("arm_force_mom_queued", {
		subtype = BOSS_TYPE_MOM,
		note = runtime.note,
	})
end

function item.arm_force_mom_mausoleum_next()
	local subtype = (BossType and BossType.MOM_MAUSOLEUM) or 89
	runtime.force_boss_subtype_once = subtype
	compass_floor.clear_backwards_path_init("arm_force_mom_mausoleum")
	runtime.note = "queued force BossType.MOM_MAUSOLEUM="
		.. tostring(subtype)
		.. " for Witness Mausoleum II test"
	push_event("arm_force_mom_mausoleum_queued", {
		subtype = subtype,
		note = runtime.note,
		boss_variant = corridor_plan_mod.BOSS_VARIANT_MOM_MAUSOLEUM,
	})
end

--- One-shot: next corridor Boss@89 forces a StageAPI extension Boss (not vanilla RoomConfig).
--- boss_id nil/true → first current-floor StageAPI candidate; string → that BossID (may bypass horseman/subtype filters for test).
function item.arm_force_stageapi_extension_next(boss_id)
	if type(boss_id) == "string" and boss_id ~= "" then
		runtime.force_stageapi_boss_once = boss_id
	else
		runtime.force_stageapi_boss_once = true
	end
	-- Mutually exclusive with vanilla subtype force for this next build.
	runtime.force_boss_subtype_once = nil
	runtime.note = "queued force StageAPI extension Boss@89 once: "
		.. tostring(runtime.force_stageapi_boss_once)
	push_event("arm_force_stageapi_extension_queued", {
		force = runtime.force_stageapi_boss_once,
		note = runtime.note,
	})
	return true, runtime.force_stageapi_boss_once
end

function item.clear_force_stageapi_extension_next()
	runtime.force_stageapi_boss_once = nil
	push_event("arm_force_stageapi_extension_cleared", {})
	return true
end

function item.set_secret_exit_door_observer(cb)
	runtime.secret_exit_door_observer = type(cb) == "function" and cb or nil
end

function item.snapshot_secret_exit_door_probe(tag)
	return compass_floor.snapshot_secret_exit_door_probe(tag or "manual")
end

function item.snapshot_special_quest_door_probe(tag)
	if compass_floor.snapshot_special_quest_door_probe then
		return compass_floor.snapshot_special_quest_door_probe(tag or "manual")
	end
	return nil
end

function item.set_mirror_physics_observer(cb)
	if compass_floor.set_mirror_physics_observer then
		compass_floor.set_mirror_physics_observer(cb)
	end
end

function item.set_mineshaft_dim_observer(cb)
	if compass_floor.set_mineshaft_dim_observer then
		compass_floor.set_mineshaft_dim_observer(cb)
	end
end

function item.set_virtual_door_life_observer(cb)
	if compass_floor.set_virtual_door_life_observer then
		compass_floor.set_virtual_door_life_observer(cb)
	end
end

function item.set_stageapi_bind_observer(cb)
	compass_floor.set_stageapi_bind_observer(cb)
end

function item.snapshot_stageapi_bind_probe(tag)
	return compass_floor.snapshot_stageapi_bind(tag or "manual")
end

function item.force_mineshaft_collapse_playback(tag)
	if compass_floor.force_mineshaft_collapse_playback then
		return compass_floor.force_mineshaft_collapse_playback(tag or "force_collapse_ui")
	end
	return {ok = false, note = "no_api"}
end

function item.scan_mineshaft_dimension1(tag)
	if compass_floor.scan_mineshaft_dimension1 then
		return compass_floor.scan_mineshaft_dimension1(tag or "manual")
	end
	return nil
end

function item.maybe_scan_mineshaft_dimension1(tag, opts)
	if compass_floor.maybe_scan_mineshaft_dimension1 then
		return compass_floor.maybe_scan_mineshaft_dimension1(tag, opts)
	end
	return nil
end

function item.snapshot_left0_slot_context(phase, room, preferred)
	if compass_floor.snapshot_left0_slot_context then
		return compass_floor.snapshot_left0_slot_context(phase, room, preferred)
	end
	return nil
end

function item.set_witness_mausoleum_test(on)
	cfg.witness_mausoleum_test = on == true
	if cfg.witness_mausoleum_test then
		compass_floor.clear_backwards_path_init("witness_mausoleum_test_on")
	end
	runtime.note = "witness_mausoleum_test=" .. tostring(cfg.witness_mausoleum_test)
	push_event("witness_mausoleum_test_set", {enabled = cfg.witness_mausoleum_test})
end

function item.snapshot_witness_route(tag)
	return compass_floor.snapshot_witness_route(tag or "manual")
end

function item.try_spawn_witness_secret_exit_soft()
	return compass_floor.try_spawn_witness_secret_exit("manual_soft", false)
end

function item.try_spawn_witness_secret_exit_force()
	return compass_floor.try_spawn_witness_secret_exit("manual_force", true)
end

function item.witness_status_text()
	local snap = runtime.witness_last_snapshot
	local rule = compass_floor.resolve_secret_exit_rule()
	local heart = snap and snap.heart_killed
	local flesh = snap and snap.flesh_door_opened
	local sec = snap and snap.secret_desc
	return string.format(
		"witness=%s rule=%s/%s heart=%s fleshDoor=%s bwInit=%s boss=%s npc=%s -10ok=%s T=%s V=%s ST=%s",
		tostring(cfg.witness_mausoleum_test),
		tostring(rule and rule.kind),
		tostring(rule and rule.reason),
		tostring(heart),
		tostring(flesh),
		tostring(snap and snap.backwards_path_init),
		tostring(snap and snap.boss_id),
		tostring(snap and snap.npc_count),
		tostring(snap and snap.heart_target_ok),
		tostring(sec and sec.type),
		tostring(sec and sec.variant),
		tostring(sec and sec.subtype)
	)
end

function item.clear_force_boss_next()
	runtime.force_boss_subtype_once = nil
	runtime.force_stageapi_boss_once = nil
	runtime.note = "cleared queued force boss / StageAPI extension"
	push_event("arm_force_boss_cleared", {})
end

function item.arm_smoke_test()
	cfg.enabled = true
	apply_mode_flags("smoke")
	runtime.note = "armed SMOKE: replace-all then one TryPlace (no enter 78)"
	push_event("arm_smoke", {note = runtime.note, place_mode = "smoke"})
end

function item.arm_full_corridor()
	item.arm_main_test()
end

function item.arm_p0()
	cfg.enabled = true
	apply_mode_flags("p0")
	runtime.note = "armed P0 baseline"
	push_event("arm_p0", {note = runtime.note})
end

function item.arm_p0_p1()
	cfg.enabled = true
	apply_mode_flags("p1")
	runtime.note = "armed P1 east append"
	push_event("arm_p1", {note = runtime.note})
end

function item.arm_p2a()
	cfg.enabled = true
	apply_mode_flags("p2a")
	runtime.note = "armed P2-A fill only"
	push_event("arm_p2a", {note = runtime.note})
end

function item.arm_p2b()
	cfg.enabled = true
	apply_mode_flags("p2b")
	runtime.note = "armed P2-B fill + enter 78"
	push_event("arm_p2b", {note = runtime.note})
end

function item.arm_p2c()
	item.arm_full_corridor()
	cfg.p_mode = "p2c"
	runtime.note = "armed P2-C (= full)"
	push_event("arm_p2c", {note = runtime.note})
end

--- Manual single-grid PlaceRoom@108 with 25601 + door repair (skip if already own).
--- Main arm already batches 108/110/122; this is for isolated re-test only.
function item.experiment_force_place_108()
	cfg.enabled = true
	local seed = compass_floor.derive_placement_seed(108, 0, "debug_force_place_108") or 1
	local target = FORCE_PLACE_TARGETS[1]
	local pending = runtime.pending
	if pending and not pending.room_plan then
		build_special_room_plan(pending)
	elseif not pending then
		-- Manual place without pending: build a throwaway plan from current restore identity.
		pending = {
			restore_stage = read_level_identity().stage,
			restore_stage_type = read_level_identity().stage_type,
		}
		build_special_room_plan(pending)
	end
	local row = force_place_secret_at_grid(target, seed, pending)
	local door_row = nil
	if row.place_ok or row.now_own_room or row.skipped then
		door_row = link_room_pair(95, DoorSlot.DOWN0, 108)
		link_room_pair(108, DoorSlot.RIGHT0, 109)
	end
	local plan_row = pending.room_plan and pending.room_plan[108]
	local result = {
		grid = 108,
		variant = row.variant,
		plan_type = plan_row and plan_row.room_type,
		plan_fallback = plan_row and plan_row.fallback == true,
		row = row,
		door_link_95 = door_row,
		note = "manual Place from room_plan + door; main arm batches all three",
	}
	runtime.force_place_108_result = result
	push_event("experiment_force_place_108", result)
	runtime.note = string.format(
		"place108 v10 skipped=%s ok=%s own=%s owner95=%s",
		tostring(row.skipped),
		tostring(row.place_ok),
		tostring(row.now_own_room or (row.after and row.after.owner_sgid == 108)),
		tostring(row.owner_still_valid)
	)
	return row.place_ok == true or row.skipped == true, row.place_error or row.reason
end

function item.force_console_home_now()
	cfg.enabled = true
	local id = read_level_identity()
	cfg.arm_home_layout = true
	begin_pending(id.stage, id.stage_type, "console_force")
	disarm_arm_flags()
	local cmd = stage_cmd(HOME_STAGE, HOME_STAGE_TYPE)
	push_event("console_force", {command = cmd, p_mode = cfg.p_mode})
	runtime.note = "console: " .. cmd
	Isaac.ExecuteCommand(cmd)
end

function item.capture_current_level()
	if not session_enabled() then
		return
	end
	local rooms = snapshot_level_rooms()
	runtime.level_snapshot = {
		phase = "manual_capture",
		identity = read_level_identity(),
		rooms = rooms,
		room_count = #rooms,
		start_room = snapshot_start_room("manual"),
	}
	build_last_result(runtime.pending)
	push_event("manual_level_capture", runtime.level_snapshot)
end

function item.clear()
	reset_corridor_session("manual_clear")
	runtime.events = {}
	runtime.layout_snapshot = nil
	runtime.level_snapshot = nil
	runtime.place_attempts = {}
	runtime.placement_conflicts = {}
	runtime.room_config_replacements = {}
	runtime.home_layout_snapshot = nil
	runtime.connection_audit = nil
	runtime.occupancy_probe = nil
	runtime.first_84_live = nil
	runtime.rematerialize_84_result = nil
	runtime.force_place_batch_result = nil
	runtime.force_place_door_links = nil
	runtime.door_topology_normalize = nil
	runtime.live_84_secret_door = nil
	runtime.restore_84_explore_result = nil
	runtime.special_room_plan = nil
	runtime.corridor_room_plan = nil
	runtime.boss_90_plan = nil
	runtime.deal_90_preplace = nil
	runtime.boss_89_place = nil
	runtime.curse_72_plan = nil
	runtime.curse_72_place = nil
	runtime.pre_97_secret = nil
	runtime.map_baseline = nil
	runtime.room_109_seal = nil
	runtime.force_place_108_result = nil
	runtime.place_plan = {}
	runtime.last_select = nil
	runtime.last_result = nil
	runtime.note = "cleared"
end

local function build_summary_text()
	local r = runtime.last_result or {}
	local mirror = runtime.special_quest_door
	local corridor = runtime.special_quest_mirror_corridor
	local lines = {
		string.format("schema=%s v=%d detail=%s", SCHEMA, SCHEMA_VERSION, tostring(cfg.detail_logging)),
		item.status_text(),
		string.format(
			"layout_ready=%s corridor=%s/%s content=%s entry78=%s place_err=%s",
			tostring(r.layout_ready),
			tostring(r.corridor_filled),
			tostring(r.corridor_expected),
			tostring(r.content_complete),
			tostring(r.entry_78_exists or r.entry_78_ready),
			tostring(r.place_error or r.entry_blocked_reason or "")
		),
		string.format(
			"mirror_door=%s note=%s corridor_ok=%s/%s main=%s/%s special=%s/%s corridor_note=%s",
			tostring(mirror and mirror.ok),
			tostring(mirror and mirror.note),
			tostring(corridor and corridor.ok_count),
			tostring(corridor and corridor.total),
			tostring(corridor and corridor.main_ok_count),
			tostring(corridor and corridor.main_total),
			tostring(corridor and corridor.special_ok_count),
			tostring(corridor and corridor.special_total),
			tostring(corridor and corridor.note)
		),
		string.format(
			"neg_rooms=%s active=%s events=%s",
			tostring(runtime.negative_rooms and runtime.negative_rooms.ok),
			tostring(runtime.corridor_active),
			tostring(#runtime.events)
		),
	}
	-- Recent *non-verbose* anomalies only (last 12 kinds that look like failures).
	local anomalies = {}
	for i = #runtime.events, 1, -1 do
		local e = runtime.events[i]
		local kind = tostring(e.kind or "")
		if kind:find("fail", 1, true)
			or kind:find("incomplete", 1, true)
			or kind:find("error", 1, true)
			or e.error
			or e.place_error
			or (e.ok == false)
		then
			anomalies[#anomalies + 1] = string.format(
				"f=%s %s err=%s",
				tostring(e.game_frame),
				kind,
				tostring(e.error or e.place_error or e.note or "")
			)
			if #anomalies >= 12 then
				break
			end
		end
	end
	if #anomalies == 0 then
		lines[#lines + 1] = "anomalies: (none in event queue)"
	else
		lines[#lines + 1] = "anomalies:"
		for i = #anomalies, 1, -1 do
			lines[#lines + 1] = "  " .. anomalies[i]
		end
	end
	return table.concat(lines, "\n")
end

function item.copy_summary()
	return probe_output.copy_summary(build_summary_text())
end

local function report_header()
	local rem84 = runtime.rematerialize_84_result
	local rem84_out = nil
	if rem84 and rem84.ok == false then
		rem84_out = rem84
	elseif rem84 then
		rem84_out = {ok = true, note = "ok_omitted"}
	end
	local force_batch = runtime.force_place_batch_result
	local force_batch_out = nil
	if type(force_batch) == "table" then
		force_batch_out = {
			ok = force_batch.ok,
			placed = force_batch.placed,
			failed = force_batch.failed,
			note = force_batch.note or "summary_only",
		}
	end
	local map_set = runtime.map_settlement
	local map_out = nil
	if type(map_set) == "table" then
		map_out = {
			ok = map_set.ok,
			done = runtime.map_settlement_done == true,
			note = map_set.note,
			home_display_flags = map_set.home_display_flags or map_set.display_flags,
		}
	end
	return {
		schema = SCHEMA,
		schema_version = SCHEMA_VERSION,
		probe = FILE_STEM,
		enabled = cfg.enabled,
		count = #runtime.events,
		config = item.get_config(),
		last_result = runtime.last_result,
		layout_snapshot = runtime.layout_snapshot and {
			phase = runtime.layout_snapshot.phase,
			room_count = runtime.layout_snapshot.rooms and #runtime.layout_snapshot.rooms or nil,
		} or nil,
		level_snapshot = runtime.level_snapshot and {
			phase = runtime.level_snapshot.phase,
			room_count = runtime.level_snapshot.room_count,
			corridor_filled = runtime.level_snapshot.corridor_filled,
		} or nil,
		placement_conflicts = runtime.placement_conflicts,
		door_topology_normalize = cfg.detail_logging and runtime.door_topology_normalize or nil,
		corridor_room_plan = cfg.detail_logging and runtime.corridor_room_plan or {
			ok = runtime.corridor_room_plan and runtime.corridor_room_plan.ok,
			note = "omitted_unless_detail_logging",
		},
		negative_rooms = cfg.detail_logging and runtime.negative_rooms or {
			ok = runtime.negative_rooms and runtime.negative_rooms.ok,
			note = "omitted_unless_detail_logging",
		},
		boss_90_clear = runtime.boss_90_clear,
		boss_89_trapdoor = runtime.boss_89_trapdoor,
		boss_89_heaven_light = runtime.boss_89_heaven_light,
		secret_exit_spawn = runtime.secret_exit_spawn,
		rematerialize_84_result = rem84_out,
		force_place_batch_result = force_batch_out,
		map_settlement = map_out,
		map_settlement_done = runtime.map_settlement_done,
		map_resolver_load_error = map_resolver_load_error,
		witness_last_snapshot = cfg.witness_mausoleum_test and runtime.witness_last_snapshot or nil,
		pending_phase = runtime.pending and runtime.pending.layout_phase or nil,
		special_quest_door = runtime.special_quest_door and {
			ok = runtime.special_quest_door.ok,
			note = runtime.special_quest_door.note,
			spawned = runtime.special_quest_door.spawned,
		} or nil,
		special_quest_mirror_corridor = runtime.special_quest_mirror_corridor and {
			ok = runtime.special_quest_mirror_corridor.ok,
			ok_count = runtime.special_quest_mirror_corridor.ok_count,
			total = runtime.special_quest_mirror_corridor.total,
			main_ok_count = runtime.special_quest_mirror_corridor.main_ok_count,
			main_total = runtime.special_quest_mirror_corridor.main_total,
			special_ok_count = runtime.special_quest_mirror_corridor.special_ok_count,
			special_total = runtime.special_quest_mirror_corridor.special_total,
			special_link_ok_count = runtime.special_quest_mirror_corridor.special_link_ok_count,
			special_link_total = runtime.special_quest_mirror_corridor.special_link_total,
			expected_special_sgids = runtime.special_quest_mirror_corridor.expected_special_sgids,
			special_compare = runtime.special_quest_mirror_corridor.special_compare,
			note = runtime.special_quest_mirror_corridor.note,
		} or nil,
		detail_logging = cfg.detail_logging == true,
		note = "mirror physics → golden_compass_mirror_physics_probe; detail_logging for bulky snapshots",
	}
end

function item.copy_full_report()
	return probe_output.copy_jsonl(report_header(), runtime.events)
end

function item.export()
	local text, err = probe_output.encode_jsonl(report_header(), runtime.events)
	if not text then
		return false, err
	end
	return probe_output.export_text(FILE_STEM, "jsonl", text)
end

function item.export_jsonl()
	return item.export()
end

function item.get_output_status()
	return probe_output.format_output_status({
		"events=" .. tostring(#runtime.events),
		"mode=" .. tostring(cfg.p_mode),
	})
end

-- --- callbacks ---

-- After engine resets ForceSpecialQuest to DEFAULT, re-apply for intended restore stage
-- so Home layout gen can still prepare KNIFE_PUZZLE when eligible.
if ModCallbacks.MC_PRE_LEVEL_INIT then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_PRE_LEVEL_INIT,
		params = nil,
		priority = -70,
		Function = function(_)
			if not session_enabled() then
				return
			end
			if not runtime.pending then
				return
			end
			compass_floor.apply_force_special_quest("pre_level_init")
		end,
	})
end

if ModCallbacks.MC_PRE_LEVEL_SELECT then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_PRE_LEVEL_SELECT,
		params = nil,
		priority = -80,
		Function = function(_, level_stage, stage_type)
			-- Leaving active floor: clear live effects; promote next appointment if any.
			if compass_state.is_active() and not cfg.arm_home_layout then
				local end_result = compass_state.end_corridor("left_floor")
				compass_floor.clear_live("left_floor")
				push_event("corridor_ended", {
					reason = "left_floor",
					next_stage = level_stage,
					end_result = end_result,
					phase_after = compass_state.phase(),
				})
				if end_result ~= "promoted_next" then
					cfg.enabled = false
					return
				end
				-- Fall through to arm the promoted next floor.
			end
			if compass_state.phase() == "failed" then
				-- Stale failed session must not keep owning levelgen forever.
				compass_state.end_corridor("clear_failed_before_select")
				compass_floor.clear_live("clear_failed")
				cfg.enabled = false
			end
			-- Formal item: armed → enable main-mode Home redirect for one generation,
			-- unless target floor must defer (Home / ??? / backwards path).
			if compass_state.phase() == "armed" then
				local defer_reason = compass_floor.generation_blocked_reason(level_stage, stage_type)
				if defer_reason then
					cfg.arm_home_layout = false
					-- Keep phase=armed and root_seed; do not begin_generating / consume appointment.
					push_event("compass_arm_deferred", {
						reason = defer_reason,
						requested_stage = level_stage,
						requested_stage_type = stage_type,
						root_seed = compass_state.get_root_seed(),
						phase = compass_state.phase(),
					})
					push_event("pre_level_select", {
						requested_stage = level_stage,
						requested_stage_type = stage_type,
						armed = false,
						deferred = true,
						defer_reason = defer_reason,
						phase = compass_state.phase(),
					})
					return
				end
				apply_mode_flags("main")
				cfg.enabled = true
				cfg.arm_home_layout = true
				compass_state.begin_generating(level_stage, stage_type)
			end
			if not session_enabled() then
				return
			end
			push_event("pre_level_select", {
				requested_stage = level_stage,
				requested_stage_type = stage_type,
				armed = cfg.arm_home_layout == true,
				phase = compass_state.phase(),
			})
			if not cfg.arm_home_layout then
				return
			end
			if not runtime.pending then
				begin_pending(level_stage, stage_type, "pre_level_select")
			else
				runtime.pending.restore_stage = runtime.pending.restore_stage or level_stage
				runtime.pending.restore_stage_type = runtime.pending.restore_stage_type or stage_type
			end
			disarm_arm_flags()
			push_event("pre_level_select_redirect", {
				generator_stage = HOME_STAGE,
				restore_stage = runtime.pending.restore_stage,
				restore_stage_type = runtime.pending.restore_stage_type,
				p_mode = runtime.pending.p_mode,
				root_seed = compass_state.get_root_seed(),
			})
			return {HOME_STAGE, HOME_STAGE_TYPE}
		end,
	})
end

if ModCallbacks.MC_POST_LEVEL_LAYOUT_GENERATED then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_POST_LEVEL_LAYOUT_GENERATED,
		params = nil,
		priority = -40,
		Function = function(_, level_generator)
			if not session_enabled() then
				return
			end
			local pending = runtime.pending
			local rooms, snap_err = snapshot_all_generator_rooms(level_generator)
			local place_attempts, conflicts, place_err = {}, {}, nil
			if pending then
				pending.layout_callback_seen = true
				if pending.fill_full_corridor then
					place_attempts, conflicts, place_err = plan_and_fill_full_corridor_generator(level_generator)
					pending.layout_fill_ok = place_err == nil
					pending.place_error = place_err
					rooms = snapshot_all_generator_rooms(level_generator)
				elseif pending.append_corridor then
					place_attempts, place_err = try_append_corridor(level_generator, pending.corridor_extra)
					rooms = snapshot_all_generator_rooms(level_generator)
				end
			end
			runtime.place_attempts = place_attempts
			runtime.placement_conflicts = conflicts
			runtime.layout_snapshot = {
				phase = "layout_generated",
				room_count = #rooms,
				rooms = rooms,
				error = snap_err,
				place_error = place_err,
				place_attempts = place_attempts,
				placement_conflicts = conflicts,
			}
			push_event("layout_generated", {
				room_count = #rooms,
				error = snap_err,
				place_error = place_err,
				conflict_count = #conflicts,
				layout_callback_seen = true,
			})
			runtime.note = "LAYOUT_GENERATED rooms=" .. tostring(#rooms)
		end,
	})
end

if ModCallbacks.MC_PRE_LEVEL_PLACE_ROOM then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_PRE_LEVEL_PLACE_ROOM,
		params = nil,
		priority = -40,
		Function = function(_, slot, room_config, seed)
			local pending = runtime.pending
			if not session_enabled() or not pending then
				return
			end
			if not (pending.replace_corridor_config or pending.replace_offcorridor_secret) then
				return
			end
			if not pending.layout_callback_seen then
				return
			end
			local col = safe_call(slot.Column, slot)
			local row = safe_call(slot.Row, slot)
			local door_mask = safe_call(slot.DoorMask, slot) or (room_config and room_config.Doors)
			local shape = safe_call(slot.Shape, slot)
			if col == nil or row == nil then
				return
			end
			local cfg_room, kind, variant
			if is_corridor_cell(col, row) and pending.replace_corridor_config then
				cfg_room = get_room_config(RoomType.ROOM_DEFAULT, ROOM_VARIANT_CORRIDOR)
				kind, variant = "corridor", ROOM_VARIANT_CORRIDOR
			elseif pending.replace_offcorridor_secret and shape == SHAPE_1X1 then
				cfg_room = get_room_config(RoomType.ROOM_SECRET, ROOM_VARIANT_SECRET_TERRAIN)
				kind, variant = "off_secret", ROOM_VARIANT_SECRET_TERRAIN
			else
				return
			end
			if not cfg_room then
				runtime.room_config_replacements[#runtime.room_config_replacements + 1] = {
					ok = false,
					phase = "place_callback",
					kind = kind,
					error = "config_nil",
					col = col,
					row = row,
				}
				return
			end
			if door_mask and not doors_are_compatible(door_mask, cfg_room) then
				runtime.room_config_replacements[#runtime.room_config_replacements + 1] = {
					ok = false,
					phase = "place_callback",
					kind = kind,
					error = "door_incompatible",
					col = col,
					row = row,
				}
				return
			end
			runtime.room_config_replacements[#runtime.room_config_replacements + 1] = {
				ok = true,
				phase = "place_callback_return",
				kind = kind,
				variant = variant,
				col = col,
				row = row,
				sgid = grid_index(col, row),
				seed = seed,
			}
			return cfg_room
		end,
	})
end

local function try_restore_identity(source)
	local pending = runtime.pending
	if not pending or not pending.restore_identity or pending.identity_restored then
		return
	end
	if runtime.double_transitioning then
		return
	end

	-- If PRE plan / POST build never ran, attempt POST build once (never PRE TryPlace).
	if pending.layout_phase == LAYOUT_IDLE or pending.layout_phase == LAYOUT_PLANNED then
		if not pending.corridor_ensured then
			build_fixed_corridor_post(source .. ":emergency_build")
		end
	end

	local level = Game():GetLevel()
	local before = read_level_identity()
	local entry_before = snapshot_start_room("entry_before")
	runtime.double_transitioning = true

	local _, set_ok, set_err = safe_call(level.SetStage, level, pending.restore_stage, pending.restore_stage_type)

	local current_index = level:GetCurrentRoomIndex()
	local target_index = current_index
	if pending.enter_player_entry then
		-- Never ChangeRoom(78) into an unregistered / aliased descriptor.
		local ok78, _d78, why78 = entry_78_ready()
		if pending.layout_ready and ok78 then
			target_index = PLAYER_ENTRY_INDEX
			pending.entry_blocked_reason = nil
		else
			target_index = current_index
			if not ok78 then
				pending.entry_blocked_reason = why78 or "entry_78_missing"
			elseif not pending.layout_ready then
				pending.entry_blocked_reason = "layout_not_ready_skip_enter"
			else
				pending.entry_blocked_reason = "corridor_incomplete_skip_enter"
			end
		end
	end

	if pending.experiment_keep_start_unvisited then
		local start_desc = level:GetRoomByIdx(ORIGINAL_START_INDEX)
		if start_desc then
			pcall(function()
				start_desc.VisitedCount = 0
			end)
		end
	end
	if not pending.enter_player_entry or target_index == current_index then
		local editable = level:GetRoomByIdx(current_index)
		if editable then
			pcall(function()
				editable.VisitedCount = 0
			end)
		end
	end

	local change_api = pending.entry_change_api or "game"
	local change_ok, change_err
	if change_api == "level" then
		_, change_ok, change_err = safe_call(level.ChangeRoom, level, target_index)
	else
		_, change_ok, change_err = safe_call(Game().ChangeRoom, Game(), target_index)
	end

	local after = read_level_identity()
	local entry_after = snapshot_start_room("entry_after")
	local stage_ok = tonumber(after.stage) == tonumber(pending.restore_stage)
		and tonumber(after.stage_type) == tonumber(pending.restore_stage_type)
	local room_ok = true
	if pending.enter_player_entry and target_index == PLAYER_ENTRY_INDEX then
		room_ok = tonumber(after.current_room_index) == tonumber(PLAYER_ENTRY_INDEX)
	end
	local id_ok = set_ok == true and change_ok == true and stage_ok == true and room_ok == true
	pending.identity_restored = id_ok
	compass_state.mark_identity_restored(id_ok)
	if not id_ok then
		compass_state.fail_generation("identity_restore_failed")
	else
		compass_floor.try_finalize(source or "identity_restore")
	end
	build_last_result(pending)
	push_event("identity_restore", {
		source = source,
		set_ok = set_ok == true,
		set_error = set_err,
		change_api = change_api,
		change_ok = change_ok == true,
		change_error = change_err,
		target_index = target_index,
		enter_player_entry = pending.enter_player_entry == true,
		entry_blocked_reason = pending.entry_blocked_reason,
		before = before,
		after = after,
		entry_before = entry_before,
		entry_after = entry_after,
		start_visited_before = entry_before.visited,
		start_visited_after = entry_after.visited,
		placement_path = pending.placement_path,
		corridor_complete = pending.corridor_complete,
		identity_ok = id_ok,
		stage_ok = stage_ok,
		room_ok = room_ok,
		last_result = runtime.last_result,
	})
	runtime.note = item.status_text()
end

if ModCallbacks.MC_PRE_NEW_ROOM then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_PRE_NEW_ROOM,
		params = nil,
		priority = -100,
		Function = function(_, _room, descriptor)
			if not session_enabled() then
				return
			end
			local pending = runtime.pending
			if not pending then
				return
			end
			local sgid = descriptor and descriptor.SafeGridIndex
			-- ChangeRoom(78) re-enters PRE_NEW_ROOM; plan only once.
			if pending.layout_phase ~= LAYOUT_IDLE then
				push_event("pre_new_room_skipped", {
					reason = "phase_" .. tostring(pending.layout_phase),
					sgid = sgid,
				})
				-- Still log desc side for 84 / 78 entry diagnostics.
				if sgid == ORIGINAL_START_INDEX or sgid == PLAYER_ENTRY_INDEX then
					push_event("pre_new_room_desc", {
						sgid = sgid,
						visited = descriptor and descriptor.VisitedCount,
						variant = descriptor and descriptor.Data and descriptor.Data.Variant,
						shape = descriptor and descriptor.Data and descriptor.Data.Shape,
						name = descriptor and descriptor.Data and descriptor.Data.Name,
						phase = pending.layout_phase,
					})
				end
				return
			end
			pending.layout_attempted = true
			push_event("pre_new_room_plan_begin", {
				sgid = sgid,
				visited = descriptor and descriptor.VisitedCount,
				p_mode = pending.p_mode,
				place_mode = pending.place_mode,
			})
			plan_fixed_corridor_pre("pre_new_room", descriptor)
		end,
	})
end

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	priority = -90,
	Function = function()
		if not session_enabled() then
			return
		end
		if runtime.double_transitioning then
			runtime.double_transitioning = false
			runtime.identity_restored_seen = true
			local id = read_level_identity()
			-- After ChangeRoom(78): one-shot full-floor map settlement (no later re-runs).
			if id.current_room_index == PLAYER_ENTRY_INDEX and not runtime.map_settlement_done then
				if map_resolver and map_resolver.settle_once then
					local settle = map_resolver.settle_once({
						fake_clear_sgids = {ORIGINAL_START_INDEX},
						reason = "post_enter_78",
						focus_sgids = {72, 83, 84, 85, 78, 95, 97, 98, 108, 109, 110, 122},
					})
					runtime.map_settlement = settle
					runtime.map_settlement_done = true
					compass_floor.sync_persist()
					runtime.restore_84_explore_result = settle
					push_event("map_settlement_once", settle)
					push_event("map_visibility_settlement", settle)
				else
					local err = map_resolver_load_error or "map_resolver missing settle_once"
					push_event("map_visibility_settlement_error", {
						phase = "post_enter_78",
						module = MAP_RESOLVER_PATH,
						error = err,
						map_resolver_nil = map_resolver == nil,
						has_settle_once = map_resolver ~= nil and map_resolver.settle_once ~= nil,
					})
					-- Still attempt minimal 84 clear so testing is not fully blind; log as degraded.
					restore_84_explore_after_entry78("post_enter_78_degraded")
				end
			end
			-- First enter 78: empty debris + unlock main-path doors (incl. 78→79 treasure).
			if id.current_room_index == ENTRY_ROOM_SGID then
				rematerialize_empty_entry_78("post_restore_enter_78_empty")
			end
			apply_corridor_door_gate("post_restore_enter")
			if id.current_room_index == ENTRY_ROOM_SGID then
				compass_floor.ensure_special_quest_room_doors("post_restore_enter_78", id.current_room_index)
			elseif compass_floor.is_at_mineshaft_reward(id.current_room_index) then
				compass_floor.ensure_special_quest_room_doors("post_restore_enter_162", id.current_room_index)
			end
			build_last_result(runtime.pending)
			local live = emit_live_room_content("post_restore_enter")
			push_event("post_new_room_after_restore", {
				identity = id,
				current_equals_entry = id.current_room_index == PLAYER_ENTRY_INDEX,
				live_room = live,
				last_result = runtime.last_result,
				rematerialize_84 = runtime.rematerialize_84_result,
				force_place_batch = runtime.force_place_batch_result,
				force_place_doors = runtime.force_place_door_links,
				door_topology_normalize = runtime.door_topology_normalize,
				live_84_secret_door = runtime.live_84_secret_door,
				special_room_plan = runtime.special_room_plan,
				boss_90_plan = runtime.boss_90_plan,
				corridor_door_gate = runtime.corridor_door_gate,
				empty_78 = runtime.empty_78_result,
				special_quest_door = runtime.special_quest_door,
				special_quest_force = runtime.special_quest_force,
				pre_97_secret = runtime.pre_97_secret,
				map_settlement = runtime.map_settlement,
				map_settlement_done = runtime.map_settlement_done == true,
				map_resolver_load_error = map_resolver_load_error,
				room_109_seal = runtime.room_109_seal,
			})
			return
		end
		local pending = runtime.pending
		if pending and (pending.layout_phase == LAYOUT_PLANNED or pending.layout_phase == LAYOUT_IDLE) then
			-- Content after Room::Init of native start (usually 84), before mass rewrite.
			emit_live_room_content("post_init_before_build")
			build_fixed_corridor_post("post_new_room")
		elseif runtime.identity_restored_seen then
			local id = read_level_identity()
			local cur_sgid = id.current_room_index
			compass_floor.note_corridor_sgid_transition(cur_sgid)
			if cur_sgid == ORIGINAL_START_INDEX or cur_sgid == PLAYER_ENTRY_INDEX then
				emit_live_room_content("post_transition")
			end
			if cur_sgid == ENTRY_ROOM_SGID then
				rematerialize_empty_entry_78("post_enter_78_empty")
			end
			apply_corridor_door_gate("post_transition")
			if cur_sgid == ENTRY_ROOM_SGID then
				compass_floor.ensure_special_quest_room_doors("post_enter_78", cur_sgid)
			elseif compass_floor.is_at_mineshaft_reward(cur_sgid) then
				compass_floor.ensure_special_quest_room_doors("post_enter_162", cur_sgid)
			end
			compass_floor.spawn_84_options_on_true_enter("post_transition")
			if compass_floor.try_spawn_mirror_79_knife_piece then
				compass_floor.try_spawn_mirror_79_knife_piece("post_transition")
			end
			if cur_sgid == BOSS_ROOM_SGID then
				compass_floor.on_boss_89_visit(
					runtime.boss_90_entered and "post_reenter_89" or "post_enter_89"
				)
			elseif cur_sgid == DEAL_ROOM_SGID then
				compass_floor.on_deal_90_visit("post_enter_90_style")
			end
			-- Enter 97: snapshot 109 map flags (no settle rewrite) to test topology residue theory.
			if cur_sgid == ROOM_97_SGID then
				local level = Game():GetLevel()
				local d109 = level:GetRoomByIdx(ROOM_109_SGID, 0)
				local d97 = level:GetCurrentRoomDesc()
				push_event("enter_97_map_check", {
					room_97 = {
						doors = read_desc_doors_array(d97),
						allowed_doors = d97 and d97.AllowedDoors,
						type = d97 and d97.Data and d97.Data.Type,
						shape = d97 and d97.Data and d97.Data.Shape,
						display_flags = d97 and d97.DisplayFlags,
						visited = d97 and d97.VisitedCount,
					},
					room_109 = {
						doors = read_desc_doors_array(d109),
						allowed_doors = d109 and d109.AllowedDoors,
						type = d109 and d109.Data and d109.Data.Type,
						shape = d109 and d109.Data and d109.Data.Shape,
						display_flags = d109 and d109.DisplayFlags,
						visited = d109 and d109.VisitedCount,
					},
					note = "observe only; map settlement not re-run",
				})
			end
			-- 109: strip live UP door after native Init (Home secret-exit compatibility).
			if cur_sgid == ROOM_109_SGID then
				seal_109_live_up_door("post_enter_109")
			end
			-- Linked specials only: MakeDoor for planned links (never 109 UP).
			ensure_live_doors_for_current_secret("post_transition")
			-- Log first entry into planned specials.
			local plan = (runtime.pending and runtime.pending.room_plan) or nil
			local prow = plan and cur_sgid and plan[cur_sgid]
			if prow then
				local desc = Game():GetLevel():GetCurrentRoomDesc()
				push_event("special_room_entry", {
					sgid = cur_sgid,
					planned_type = prow.room_type,
					planned_variant = prow.variant,
					planned_fallback = prow.fallback == true,
					live_type = desc and desc.Data and desc.Data.Type,
					live_variant = desc and desc.Data and desc.Data.Variant,
					live_shape = desc and desc.Data and desc.Data.Shape,
					doors = read_desc_doors_array(desc),
					allowed_doors = desc and desc.AllowedDoors,
					visited = desc and desc.VisitedCount,
					up_door_present = (function()
						local r = Game():GetRoom()
						local d = nil
						pcall(function()
							d = r:GetDoor(DoorSlot.UP0)
						end)
						return d ~= nil
					end)(),
				})
			end
			-- Map settlement is one-shot after enter 78 — do not re-run here.
		end
		-- Restore Stage + gated enter 78 only after POST build.
		if runtime.pending and runtime.pending.restore_identity and not runtime.pending.identity_restored then
			try_restore_identity("post_new_room")
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_LEVEL,
	params = nil,
	priority = -40,
	Function = function()
		if not session_enabled() then
			return
		end
		-- Result audit only; do not use as first build entry.
		if runtime.pending and runtime.pending.restore_identity and not runtime.pending.identity_restored then
			try_restore_identity("post_new_level_fallback")
		end
		local identity = read_level_identity()
		local rooms = snapshot_level_rooms()
		local present = corridor_occupancy_from_level()
		runtime.level_snapshot = {
			phase = "post_new_level",
			identity = identity,
			rooms = rooms,
			room_count = #rooms,
			corridor_filled = count_corridor_present(present),
			start_room = snapshot_start_room("post_new_level"),
		}
		build_last_result(runtime.pending)
		push_event("post_new_level", {
			identity = identity,
			room_count = #rooms,
			corridor_filled = count_corridor_present(present),
			layout_callback_seen = runtime.pending and runtime.pending.layout_callback_seen or false,
			layout_attempted = runtime.pending and runtime.pending.layout_attempted or false,
			layout_phase = runtime.pending and runtime.pending.layout_phase or nil,
			layout_ready = runtime.pending and runtime.pending.layout_ready or false,
			place_mode = runtime.pending and runtime.pending.place_mode or cfg.place_mode,
			last_success_sgid = runtime.pending and runtime.pending.last_success_sgid,
			placement_path = runtime.pending and runtime.pending.placement_path,
			last_result = runtime.last_result,
		})
		runtime.note = item.status_text()
		-- Persist planned deal/boss onto runtime early; activation waits for full generation_ok.
		if runtime.pending and runtime.pending.layout_ready == true then
			compass_state.mark_layout_ready(true)
			runtime.activate_stageapi_layout_guard(runtime.pending, "post_new_level")
			compass_floor.notify_stageapi_bind_probe("post_new_level", {
				layout_ready = true,
			})
			if runtime.pending.deal_room_choice and runtime.pending.deal_room_choice.room_type then
				runtime.corridor_deal_type = runtime.pending.deal_room_choice.room_type
			end
			if runtime.pending.force_boss_subtype ~= nil then
				runtime.corridor_force_boss = runtime.pending.force_boss_subtype
			end
			clear_corridor_curses("post_new_level")
			if not runtime.negative_rooms then
				prepare_negative_special_rooms(runtime.pending, "post_new_level")
			end
			compass_floor.try_finalize("post_new_level")
			if not compass_state.is_active() and not compass_state.is_failed() then
				-- Still waiting for identity restore; keep effects off.
				runtime.corridor_active = false
				set_deal_guarantee(false)
			end
		elseif not runtime.pending or runtime.pending.layout_ready ~= true then
			compass_state.mark_layout_ready(false)
			if compass_state.phase() == "generating" then
				compass_state.fail_generation("layout_not_ready")
			end
			runtime.corridor_active = false
			set_natural_deal_suppress(false)
			set_deal_guarantee(false)
		end
		if runtime.pending and runtime.pending.identity_restored then
			runtime.pending = nil
		elseif runtime.pending and not runtime.pending.restore_identity then
			runtime.pending = nil
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	priority = 50,
	Function = function()
		if not session_enabled() then
			return
		end
		-- Continue may land already in 89/90 without a fresh POST_NEW_ROOM.
		compass_floor.maybe_init_continue_current_room("post_update_continue")
		tick_deal_door_sprite_watch()
		if runtime.corridor_active then
			local cur = Game():GetLevel():GetCurrentRoomDesc()
			local sgid = cur and cur.SafeGridIndex
			local dimension = compass_floor.read_current_dimension()
			if sgid == ORIGINAL_START_INDEX then
				compass_floor.tick_fixed_84_sleep_choice("post_update_84_sleep")
			end
			if corridor_plan_mod.is_challenge_gate_sgid(sgid) then
				apply_corridor_door_gate("post_update_challenge")
			end
			-- Entry@78 mirror/mineshaft, or Dim1/162 reward return door.
			local at_entry = sgid == ENTRY_ROOM_SGID
			local at_reward = compass_floor.is_at_mineshaft_reward(sgid, dimension)
			if at_entry or at_reward then
				if compass_floor.tick_mirror_door then
					compass_floor.tick_mirror_door(at_reward and "post_update_return" or "post_update_mirror")
				elseif at_entry then
					local last_sq = runtime.special_quest_door
					if last_sq and last_sq.retryable == true then
						compass_floor.ensure_special_quest_door("post_update_retry")
					end
				end
			end
			if sgid == DEAL_ROOM_SGID then
				apply_boss_deal_doors("post_update_90")
			end
			if sgid == BOSS_ROOM_SGID then
				compass_floor.tick_secret_exit_door("post_update_89")
				-- Strange Key acquired while already cleared: re-check Blue Womb door.
				local room89 = Game():GetRoom()
				if room89 and room89:IsClear() then
					local has_key = false
					local trinket = TrinketType and TrinketType.TRINKET_STRANGE_KEY
					if trinket then
						pcall(function()
							for i = 0, Game():GetNumPlayers() - 1 do
								local player = Game():GetPlayer(i)
								if player and player.GetTrinketMultiplier
									and player:GetTrinketMultiplier(trinket) > 0
								then
									has_key = true
									break
								end
							end
						end)
					end
					if has_key and runtime.timed_door_strange_key_seen ~= true then
						runtime.timed_door_strange_key_seen = true
						boss_exits.ensure_timed_special_door("post_update_strange_key")
					elseif not has_key then
						runtime.timed_door_strange_key_seen = false
					end
				end
			end
			compass_floor.tick_witness_mausoleum("post_update")
		end
		if not runtime.boss_90_entered then
			return
		end
		-- Same-visit timing only; enter init owns first spawn/restore.
		emit_boss_90_clear_if_needed("post_update")
	end,
})

if ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD,
		params = nil,
		priority = 50,
		Function = function()
			if not session_enabled() or not runtime.boss_90_entered then
				return
			end
			-- Keep vanilla award flow (do not return true). Trapdoor/exits only.
			emit_boss_90_clear_if_needed("pre_spawn_clean_award")
		end,
	})
end

-- Mama Mega explosion: try timed special door immediately with IgnoreTime (not persisted).
if EffectVariant and EffectVariant.MAMA_MEGA_EXPLOSION and ModCallbacks.MC_POST_EFFECT_INIT then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_POST_EFFECT_INIT,
		params = EffectVariant.MAMA_MEGA_EXPLOSION,
		priority = 50,
		Function = function()
			if not session_enabled() or not runtime.corridor_active then
				return
			end
			local level = Game():GetLevel()
			local cur = level:GetCurrentRoomDesc()
			if not cur or cur.SafeGridIndex ~= BOSS_ROOM_SGID then
				return
			end
			boss_exits.ensure_timed_special_door("mama_mega_explosion", {
				ignore_time = true,
				require_clear = false,
			})
		end,
	})
end

-- Mom@STAGE3_2: strip awards → Polaroid+Negative.
-- Mom's Heart@STAGE4_2 mainline: strip awards only (no photos). Corpse II skipped.
-- Do not cancel MC_PRE_SPAWN_CLEAN_AWARD. Exclude Dad's Note / BACKWARDS_PATH_INIT.
if ModCallbacks.MC_POST_ROOM_TRIGGER_CLEAR then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_POST_ROOM_TRIGGER_CLEAR,
		params = nil,
		priority = 50,
		Function = function()
			if not session_enabled() or not runtime.corridor_active or not runtime.boss_90_entered then
				return
			end
			local level = Game():GetLevel()
			local cur = level:GetCurrentRoomDesc()
			if not cur or cur.SafeGridIndex ~= BOSS_ROOM_SGID then
				return
			end
			if compass_floor.is_backwards_path_init and compass_floor.is_backwards_path_init() then
				return
			end
			local root = compass_state.get() or {}
			local stage = tonumber(root.restore_stage or root.target_stage)
			local stage_type = tonumber(root.restore_stage_type or root.target_stage_type)
			if stage == nil then
				pcall(function()
					stage = level:GetStage()
					stage_type = level:GetStageType()
				end)
			end
			local spawn_photos = stage == LevelStage.STAGE3_2
			local strip_only = false
			if stage == LevelStage.STAGE4_2 then
				local st_rep = StageType and StageType.STAGETYPE_REPENTANCE
				local st_rep_b = StageType and StageType.STAGETYPE_REPENTANCE_B
				local is_corpse = (st_rep ~= nil and stage_type == st_rep)
					or (st_rep_b ~= nil and stage_type == st_rep_b)
				if is_corpse then
					return
				end
				strip_only = true
			elseif not spawn_photos then
				return
			end
			local floor = compass_state.get_floor_persist() or {}
			if floor.mom_photo_reward_done == true or runtime.mom_photo_reward_done == true then
				return
			end
			local room = Game():GetRoom()
			local removed = 0
			for _, ent in ipairs(Isaac.GetRoomEntities()) do
				if ent and ent:Exists()
					and ent.Type == EntityType.ENTITY_PICKUP
					and ent.Variant == PickupVariant.PICKUP_COLLECTIBLE
				then
					ent:Remove()
					removed = removed + 1
				end
			end
			local spawned = {}
			local options_index = nil
			if spawn_photos then
				local center = room:GetCenterPos()
				local polaroid_pos = center + Vector(-40, 80)
				local negative_pos = center + Vector(40, 80)
				local polaroid_id = CollectibleType.COLLECTIBLE_POLAROID
				local negative_id = CollectibleType.COLLECTIBLE_NEGATIVE
				local function spawn_photo(id, pos, tag)
					local ok, ent = pcall(function()
						return Isaac.Spawn(
							EntityType.ENTITY_PICKUP,
							PickupVariant.PICKUP_COLLECTIBLE,
							id,
							pos,
							Vector(0, 0),
							nil
						)
					end)
					spawned[#spawned + 1] = {
						tag = tag,
						id = id,
						ok = ok == true and ent ~= nil,
						x = pos.X,
						y = pos.Y,
					}
					return (ok == true) and ent or nil
				end
				local polaroid = spawn_photo(polaroid_id, polaroid_pos, "polaroid")
				local negative = spawn_photo(negative_id, negative_pos, "negative")
				local ped_a = polaroid and polaroid.ToPickup and polaroid:ToPickup() or nil
				local ped_b = negative and negative.ToPickup and negative:ToPickup() or nil
				if ped_a and ped_b then
					options_index = option_index_holder.find_a_new_index()
					ped_a.OptionsPickupIndex = options_index
					ped_b.OptionsPickupIndex = options_index
				end
			end
			runtime.mom_photo_reward_done = true
			compass_state.set_floor_persist({mom_photo_reward_done = true})
			push_event("boss_89_mom_photo_reward", {
				removed_collectibles = removed,
				spawned = spawned,
				options_index = options_index,
				stage = stage,
				stage_type = stage_type,
				strip_only = strip_only == true,
				note = strip_only
					and "POST_ROOM_TRIGGER_CLEAR strip STAGE4_2 Heart awards; no photos"
					or "POST_ROOM_TRIGGER_CLEAR replace STAGE3_2 Mom awards with Polaroid+Negative (shared OptionsPickupIndex)",
			})
		end,
	})
end

if ModCallbacks.MC_POST_CURSE_EVAL then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_POST_CURSE_EVAL,
		params = nil,
		Function = function(_, curses)
			if not session_enabled() then
				return
			end
			if runtime.block_curses or (runtime.pending and runtime.pending.fill_full_corridor) then
				local seija = compass_floor.corridor_wants_seija_curses()
				local after = seija and compass_floor.seija_corridor_curse_mask() or LevelCurse.CURSE_NONE
				push_event("corridor_curse_eval_block", {
					before = curses,
					after = after,
					seija = seija,
				})
				return after
			end
		end,
	})
end

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	priority = -100,
	Function = function(_, is_continued)
		compass_state.on_game_started(is_continued == true)
		if is_continued then
			compass_floor.rebuild_from_persist("post_game_started_continue")
			return
		end
		reset_corridor_session("post_game_started_new_run")
		cfg.enabled = false
	end,
})

-- 84 rest: arm sleep pending on bed collision (does NOT settle; touch≠sleep).
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION,
	params = PickupVariant.PICKUP_BED,
	Function = function(_, bed, col, _low)
		local player = col and col:ToPlayer()
		if not player then
			return
		end
		compass_floor.note_fixed_84_bed_sleep_collision(bed, player, "pre_bed_collision")
		-- Never return true/false: do not cancel vanilla sleep / Options collision.
	end,
})

-- 84 rest fallback: SleepFillHP heal effect (RGON 1286) if Pause IN_BED missed.
if REPENTOGON and ModCallbacks.MC_POST_TRIGGER_BED_SLEEP_EFFECT then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_POST_TRIGGER_BED_SLEEP_EFFECT,
		params = nil,
		Function = function(_, player, bed)
			if not session_enabled() or not runtime.corridor_active then
				push_event("fixed_84_bed_sleep_reject", {
					tag = "post_bed_sleep_effect",
					reason = "session_inactive",
				})
				return
			end
			if runtime.fixed_84_choice == "rest" or runtime.fixed_84_choice == "item" then
				push_event("fixed_84_bed_sleep_reject", {
					tag = "post_bed_sleep_effect",
					reason = "already_chosen",
					choice = runtime.fixed_84_choice,
				})
				return
			end
			if not compass_floor.is_normal_dim_fixed_84() then
				push_event("fixed_84_bed_sleep_reject", {
					tag = "post_bed_sleep_effect",
					reason = "not_fixed_84_normal",
				})
				return
			end
			if not compass_floor.is_fixed_84_choice_bed(bed) then
				push_event("fixed_84_bed_sleep_reject", {
					tag = "post_bed_sleep_effect",
					reason = "bed_identity_mismatch",
					bed_seed = bed and tonumber(bed.InitSeed) or nil,
					want_seed = runtime.fixed_84_bed_init_seed,
				})
				return
			end
			compass_floor.commit_fixed_84_choice("rest", "post_bed_sleep_effect", {
				via = "rgon_sleep_fill_hp",
				player_index = player and player.GetData and player:GetData().__Index or nil,
				bed_init_seed = bed and tonumber(bed.InitSeed) or nil,
			})
		end,
	})
end

-- 84 rest/item: settle item when queued (POST_PICKUP), before POST_GAIN / hold anim end.
table.insert(item.myToCall, {
	CallBack = "POST_PICKUP_COLLECTIBLE",
	params = nil,
	Function = function(_, player, gained_id, _touched, ent, source_context)
		if not session_enabled() or not runtime.corridor_active then
			return
		end
		if runtime.fixed_84_choice == "rest" or runtime.fixed_84_choice == "item" then
			return
		end
		if not compass_floor.is_normal_dim_fixed_84() then
			return
		end
		local matched, live, kind = compass_floor.is_fixed_84_choice_item_source(source_context, ent)
		if not matched then
			return
		end
		local picked_seed = live and tonumber(live.InitSeed)
			or (ent and tonumber(ent.InitSeed))
			or nil
		compass_floor.commit_fixed_84_choice("item", "post_pickup_collectible", {
			player_index = player and player.GetData and player:GetData().__Index or nil,
			gained_id = tonumber(gained_id),
			item_init_seed = picked_seed,
			item_kind = kind,
			options_index = runtime.fixed_84_options_index,
		})
	end,
})

-- Hourglass / console rewind: save.elses already restored; resync runtime mirrors only.
table.insert(item.myToCall, {
	CallBack = "POST_REWIND",
	params = nil,
	Function = function(_, kind, desc)
		compass_floor.on_post_rewind(kind, desc)
	end,
})

if ModCallbacks.MC_PRE_GAME_EXIT then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
		params = nil,
		Function = function()
			-- Keep save.elses; drop live-only caches.
			runtime.deal_door_sprite_watch = nil
	end,
	})
end

-- Hide whole 89 RIGHT0 door during uncleared Boss fight.
-- Gate on floor-scoped corridor_active (pending is cleared after restore).
if REPENTOGON and ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_RENDER then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_RENDER,
		params = nil,
		Function = function(_, door, _offset)
			if not session_enabled() then
				return
			end
			if not runtime.corridor_active then
				return
			end
			local level = Game():GetLevel()
			local cur = level:GetCurrentRoomDesc()
			if not cur or cur.SafeGridIndex ~= BOSS_ROOM_SGID then
				return
			end
			local room = Game():GetRoom()
			if room:IsClear() == true then
				return
			end
			if door and door.Slot == DoorSlot.RIGHT0 then
				return false
			end
		end,
	})
end


function item.arm_with_root_seed(root_seed, meta)
	meta = meta or {}
	local greed = false
	pcall(function()
		greed = Game():IsGreedMode() == true
	end)
	if greed then
		push_event("arm_root_seed_rejected", {
			root_seed = root_seed,
			why = "greed_mode",
		})
		return false, "greed_mode"
	end
	local ok, why = compass_state.arm_next_floor(root_seed, meta)
	if ok and why ~= "already_armed" and why ~= "already_next_armed" then
		if why == "armed" then
			apply_mode_flags("main")
			cfg.enabled = true
			-- Home redirect only after PRE_LEVEL_SELECT eligibility (Home/???/Ascent defer).
			cfg.arm_home_layout = false
		end
		-- why == next_armed: keep current active floor; appointment waits for leave.
		if meta.force_boss_subtype then
			if why ~= "next_armed" then
				runtime.force_boss_subtype_once = meta.force_boss_subtype
			end
			compass_state.cache.debug_force_boss = meta.force_boss_subtype
		elseif why == "armed" and compass_state.cache.debug_force_boss then
			runtime.force_boss_subtype_once = compass_state.cache.debug_force_boss
		end
		runtime.note = "armed root=" .. tostring(root_seed) .. " via=" .. tostring(why)
		local compat = meta.compat
		if why == "next_armed" then
			compat = compass_state.get_next_compat and compass_state.get_next_compat() or compat
		elseif why == "armed" then
			compat = compass_state.get_compat and compass_state.get_compat() or compat
		end
		push_event("arm_root_seed", {
			root_seed = root_seed,
			why = why,
			phase = compass_state.phase(),
			next_root = compass_state.get_next_root_seed(),
			compat = compat,
			force_boss = runtime.force_boss_subtype_once,
		})
	end
	return ok, why
end

function item.get_persist_snapshot()
	return compass_state.snapshot_for_status()
end

function item.session_enabled()
	return session_enabled()
end

function item.production_active()
	return production_active()
end

function item.require_root_seed(tag)
	return compass_floor.require_root_seed(tag)
end

function item.prepare_mirror_corridor(tag)
	if compass_floor.prepare_mirror_corridor then
		return compass_floor.prepare_mirror_corridor(tag)
	end
	return nil
end

function item.snapshot_mirror_special_rooms_compare()
	if compass_floor.snapshot_mirror_special_rooms_compare then
		return compass_floor.snapshot_mirror_special_rooms_compare()
	end
	return nil
end

package.loaded[MODULE_PATH] = item
return item


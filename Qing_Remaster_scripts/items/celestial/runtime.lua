-- Shared Ketu / Rahu runtime: stars, companions, occupancy effects, projectiles.
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local g = require("Qing_Remaster_scripts.core.globals")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local hud_nodes = require("Qing_Remaster_scripts.items.spectralsword.hud_nodes")
local hud_targets = require("Qing_Remaster_scripts.items.celestial.hud_targets")
local orbit = require("Qing_Remaster_scripts.items.celestial.orbit")
local deal_chance_holder = require("Qing_Remaster_scripts.callbacks.deal_chance_holder")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local CraftTearParams = require("Qing_Remaster_scripts.others.craft_tear_params_data")
local CraftFamiliar = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
local item_hud_fx = require("Qing_Remaster_scripts.items.celestial.item_hud_fx")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local temp_item_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")

-- Ketu Seija time-acceleration helpers (table keeps chunk under Lua's 200-local cap).
local CTime = {}

local M = {
	ToCall = {},
	myToCall = {},
	own_key = "CelestialStars_",
	_orbit_paused = false,
	_force_seija = false,
	_time_accel = {
		active = false,
		extra_frames = 0,
		frac = 0,
		measure_game0 = nil,
		measure_time0 = nil,
		measured_rate = nil,
		tick_game_frame = -1,
	},
}

-- Occupancy-driven effects: no fixed WINDOW_FRAMES.
-- Optional visual soften when last star leaves (PEFFECT = 30Hz).
local TAIL_FRAMES = 2
-- Ketu coin HUD: temporary grant ledger (not resource_infinite fill-to-cap).
local KETU_TEMP_COINS = 7
local SPRITE_PATH = "gfx/mimics/Ketu_Rahu/celestial_stars.anm2"
local ZODIAC_SPRITE_PATH = "gfx/mimics/Ketu_Rahu/celestial_zodiac_icons.anm2"
local CONJ_FRAC = 0.03
local CONJ_COMP_FRAC = 0.06

-- Render-only soft drift (does not affect logical_s / occupancy).
-- Keep background float tiny; node linger uses one-shot hover offset instead.
local WOBBLE_MAIN_N = 0.35
local WOBBLE_MAIN_T = 0.15
local WOBBLE_COMP_N = 0.2
local WOBBLE_COMP_T = 0.08

-- Soft node hover: never hard-stop. Slow through interval + one-shot path bend.
local NODE_HOVER_ENABLED = true
local NODE_VMIN = 0.28
local NARROW_SPAN_FRAC = 0.04
local NARROW_VMIN = 0.60
local HOVER_A_N = 2.0
local HOVER_A_T = 0.9
local HOVER_PULSE = 0.035
local HOVER_ANCHOR_FADE_DIST = 80

-- Companions trail the main star by fixed arc length (screen track units).
-- Ketu σ=+1 (behind along forward); Rahu σ=-1 (behind along reverse).
local COMP_ARC_STEP = 20
-- Game():GetFrameCount() is 30Hz. 18 frames out, then 18 frames in.
local COMP_TRANSFER_FRAMES = 36
-- Design size from in-game test; atlas stays full-res (do not bake scale into PNG).
local COMP_ICON_SCALE = 0.5
-- RoomDisplayFlags: VISIBLE|SHOW_ICON (vanilla visited / map reveal).
local MAP_FLAGS_VISIBLE_ICON = 5
-- Normal fired tears: Height=-23.75 + vanilla FS range model (FA=0).
-- See codex_work/notes/tear_vanilla_fs_range_model.md (not legacy FA-from-range).
local RAHU_TEAR_HEIGHT = -23.75
-- Internal range units / world travel targets for falling_for_range_vanilla.
local RAHU_RANGE_COIN = 880
local RAHU_RANGE_KEY = 1120
local RAHU_RANGE_HEART = 800
local RAHU_RANGE_ROOM = 960
local RAHU_RANGE_GENERIC = 1040
-- Seek at least the longest tear range (not the old 320 clamp).
local RAHU_SEEK_RANGE = 1120
local RAHU_MAP_ANM2 = "gfx/mimics/Ketu_Rahu/rahu_map_rooms.anm2"
local BOMB_THROW_HEIGHT = -12
local BOMB_FALL_SPEED = -7.5
local BOMB_FALL_ACCEL = 0.75

-- Rahu continuous weapon cadence (PEFFECT 30Hz). sealed_amount ≠ fire count.
local COIN_SPREAD_PATTERN = {0, -3, 4, -6, 2, 7, -2, 5, -7, 1}
local RAHU_COIN_SPEED = 18
local RAHU_COIN_DAMAGE = 1.35
local RAHU_KEY_SPEED = 21
local RAHU_KEY_DAMAGE = {5, 7, 9, 12, 15}
local RAHU_BOMB_SPEED = 14
local RAHU_BOMB_DAMAGE = 26
local RAHU_BOMB_RADIUS = 46
local RAHU_BOMB_FUSE = 42
local RAHU_HEART_SPEED = 13
local RAHU_HEART_DAMAGE = 3.5
local RAHU_ROOM_SPEED = 11
local RAHU_ROOM_DAMAGE = 4.0
local RAHU_FIRE_INTERVAL = {
	coins = {6, 5, 4, 3, 2},
	keys = {18, 15, 12, 10, 8},
	bombs = {48, 42, 36, 30, 26},
	hearts = {10, 9, 8, 7, 6},
	minimap = {16, 14, 12, 10, 9},
}

local STAT_DELTAS_KETU = {
	speed = 0.3,
	tears = 1.0,
	damage = 2.0,
	range = 2.5,
	shotspeed = 0.3,
	luck = 3,
}
local STAT_DELTAS_RAHU = {
	speed = -0.2,
	tears = -0.7,
	damage = -1.5,
	range = -1.5,
	shotspeed = -0.2,
	luck = -2,
}

local ZODIAC = {
	CollectibleType.COLLECTIBLE_ARIES,
	CollectibleType.COLLECTIBLE_TAURUS,
	CollectibleType.COLLECTIBLE_GEMINI,
	CollectibleType.COLLECTIBLE_CANCER,
	CollectibleType.COLLECTIBLE_LEO,
	CollectibleType.COLLECTIBLE_VIRGO,
	CollectibleType.COLLECTIBLE_LIBRA,
	CollectibleType.COLLECTIBLE_SCORPIO,
	CollectibleType.COLLECTIBLE_SAGITTARIUS,
	CollectibleType.COLLECTIBLE_CAPRICORN,
	CollectibleType.COLLECTIBLE_AQUARIUS,
	CollectibleType.COLLECTIBLE_PISCES,
}

-- ANM2 suffix for pre-generated gold/purple zodiac companion icons.
local ZODIAC_ANIM = {
	[CollectibleType.COLLECTIBLE_ARIES] = "Aries",
	[CollectibleType.COLLECTIBLE_TAURUS] = "Taurus",
	[CollectibleType.COLLECTIBLE_GEMINI] = "Gemini",
	[CollectibleType.COLLECTIBLE_CANCER] = "Cancer",
	[CollectibleType.COLLECTIBLE_LEO] = "Leo",
	[CollectibleType.COLLECTIBLE_VIRGO] = "Virgo",
	[CollectibleType.COLLECTIBLE_LIBRA] = "Libra",
	[CollectibleType.COLLECTIBLE_SCORPIO] = "Scorpio",
	[CollectibleType.COLLECTIBLE_SAGITTARIUS] = "Sagittarius",
	[CollectibleType.COLLECTIBLE_CAPRICORN] = "Capricorn",
	[CollectibleType.COLLECTIBLE_AQUARIUS] = "Aquarius",
	[CollectibleType.COLLECTIBLE_PISCES] = "Pisces",
}

local _probe_sink = nil
function M.set_probe_sink(fn)
	_probe_sink = fn
end

local function probe(kind, payload)
	if _probe_sink then
		pcall(_probe_sink, kind, payload)
	end
end

-- Separate from orbit probe sink: Tear Lifecycle CONFIGURED samples only.
local _tear_lifecycle_sink = nil
function M.set_tear_lifecycle_sink(fn)
	_tear_lifecycle_sink = fn
end

local function note_tear_lifecycle(stage, tear, extra)
	if not _tear_lifecycle_sink then return end
	pcall(_tear_lifecycle_sink, stage, tear, extra)
end

local function bit_or(a, b)
	if bit and bit.bor then
		return bit.bor(a, b)
	end
	return a | b
end

local function player_key(player)
	if not player or not player.ToPlayer then return nil end
	player = player:ToPlayer()
	if not player then return nil end
	local idx = player:GetData() and player:GetData().__Index
	if idx == nil then return nil end
	return tostring(idx)
end

local function ketu_id()
	return enums.Items.Ketu
end

local function rahu_id()
	return enums.Items.Rahu
end

local function holds(player, item_id)
	return player and item_id and item_id > 0 and player:GetCollectibleNum(item_id) > 0
end

local SCHEMA = 5 -- arc-length companions; drop delay_frames history follow

-- Attack cadence and the captured room volley live beside the save.
-- Continue / rewind load a new effect table, so the next open starts empty.
function M._fx(eff)
	local all = M._fx_bags
	if not all then
		all = {}
		M._fx_bags = all
	end
	local bag = all[eff]
	if not bag then
		bag = {}
		all[eff] = bag
	end
	return bag
end

function M._lane_of(st, lane_key)
	local all = M._lanes
	if not all then
		all = {}
		M._lanes = all
	end
	local lanes = all[st]
	if not lanes then
		lanes = {}
		all[st] = lanes
	end
	local m = lanes[lane_key]
	if type(m) ~= "table" then
		m = {phase = "CRUISE", last_node = nil, local_u = nil}
		lanes[lane_key] = m
	end
	return m
end

function M._view(st)
	local all = M._views
	if not all then
		all = {}
		M._views = all
	end
	local view = all[st]
	if not view then
		view = {}
		all[st] = view
	end
	return view
end

function M._shed_runtime(root)
	if M._shed_root == root then return end
	M._shed_root = root
	M._fx_bags = {}
	M._lanes = {}
	M._views = {}
	for _, st in pairs(root.players or {}) do
		if type(st) == "table" then
			st.lane_motion = nil
			st.pending_shots = nil
			st._ketu_phase = nil
			st._ketu_local_u = nil
			st._ketu_target_node = nil
			st._rahu_phase = nil
			st._rahu_local_u = nil
			st._rahu_target_node = nil
			if type(st.effects) == "table" then
				for _, eff in pairs(st.effects) do
					if type(eff) == "table" then
						eff.map_layout = nil
						eff.fire_cd = nil
						eff.coin_shot_index = nil
						eff.heart_toggle = nil
					end
				end
			end
		end
	end
end

local function state_root()
	local root = save.elses[M.own_key .. "run"]
	if type(root) ~= "table" or root.schema ~= SCHEMA then
		root = {players = {}, schema = SCHEMA}
		save.elses[M.own_key .. "run"] = root
	end
	root.players = root.players or {}
	M._shed_runtime(root)
	return root
end

local function player_state(pkey)
	local root = state_root()
	local st = root.players[pkey]
	if type(st) ~= "table" then
		st = {
			ketu_s = 0,
			rahu_s = 0.5,
			companions = {},
			effects = {},
			conjunction_armed = true,
			rng_seed = nil,
			next_eff = 1,
		}
		root.players[pkey] = st
	end
	st.effects = st.effects or {}
	st.companions = st.companions or {}
	st.pending_shots = nil -- legacy: no deferred Rahu shot memory
	st.block_collectible = st.block_collectible or {}
	st.block_trinket = st.block_trinket or {}
	return st
end

local _geo = {}
local _sprites = {}
local _zodiac_sprites = {}

local function get_sprite(anim)
	local s = _sprites[anim]
	if not s then
		s = Sprite()
		s:Load(SPRITE_PATH, true)
		_sprites[anim] = s
	end
	if not s:IsPlaying(anim) then
		s:Play(anim, true)
	end
	return s
end

local function zodiac_anim_name(lane_name, collectible_id)
	local suffix = ZODIAC_ANIM[collectible_id]
	if not suffix then return nil end
	local prefix = (lane_name == "rahu") and "Rahu_" or "Ketu_"
	return prefix .. suffix
end

local function get_zodiac_sprite(anim)
	if not anim then return nil end
	local s = _zodiac_sprites[anim]
	if not s then
		s = Sprite()
		s:Load(ZODIAC_SPRITE_PATH, true)
		_zodiac_sprites[anim] = s
	end
	if not s:IsPlaying(anim) then
		s:Play(anim, true)
	end
	-- Scale is set by draw_companion_icon (COMP_ICON_SCALE); reset Color only here.
	s.Color = Color(1, 1, 1, 1)
	return s
end

local function ensure_rng(st, player)
	local rng = RNG()
	if st.rng_seed then
		rng:SetSeed(st.rng_seed, 35)
		return rng
	end
	local seed = 1
	if player and player.GetCollectibleRNG and ketu_id() > 0 then
		local owner = holds(player, ketu_id()) and ketu_id()
			or (holds(player, rahu_id()) and rahu_id())
			or ketu_id()
		seed = player:GetCollectibleRNG(owner):Next()
	elseif player and player.InitSeed then
		seed = player.InitSeed
	end
	if seed == 0 then seed = 1 end
	st.rng_seed = seed
	rng:SetSeed(seed, 35)
	return rng
end

local function recount_zodiac(player, st)
	local list = {}
	for i = 1, #ZODIAC do
		local id = ZODIAC[i]
		local n = player:GetCollectibleNum(id)
		for _ = 1, n do
			list[#list + 1] = id
		end
	end
	-- Preserve stable identity / follow_index / transition across rebuilds.
	-- Legacy delay_frames (schema≤4) is dropped; arc follow uses follow_index.
	local old_pool = {}
	for i = 1, #st.companions do
		local c = st.companions[i]
		if c and c.id then
			old_pool[c.id] = old_pool[c.id] or {}
			old_pool[c.id][#old_pool[c.id] + 1] = c
		end
	end
	local has_ketu = holds(player, ketu_id())
	local has_rahu = holds(player, rahu_id())
	local default_lane = has_ketu and "ketu" or (has_rahu and "rahu" or "ketu")
	local comps = {}
	st.next_comp = st.next_comp or 1
	for i = 1, #list do
		local id = list[i]
		local prev
		local bucket = old_pool[id]
		if bucket and #bucket > 0 then
			prev = table.remove(bucket, 1)
		end
		local lane = (prev and prev.lane) or default_lane
		if lane == "ketu" and not has_ketu then lane = "rahu" end
		if lane == "rahu" and not has_rahu then lane = "ketu" end
		local token = prev and prev.token
		if not token then
			token = "z" .. tostring(st.next_comp)
			st.next_comp = st.next_comp + 1
		end
		comps[#comps + 1] = {
			id = id,
			token = token,
			lane = lane,
			follow_index = prev and prev.follow_index or nil,
			transition = prev and prev.transition or nil,
		}
	end
	local function assign_follow_indices(lane_name)
		local idxs = {}
		for i = 1, #comps do
			if comps[i].lane == lane_name then
				idxs[#idxs + 1] = i
			end
		end
		local n = #idxs
		local need_reassign = false
		local seen = {}
		for k = 1, n do
			local fi = comps[idxs[k]].follow_index
			if type(fi) ~= "number" or fi < 1 or fi > n or seen[fi] then
				need_reassign = true
				break
			end
			seen[fi] = true
		end
		if not need_reassign then
			for k = 1, n do
				if not seen[k] then
					need_reassign = true
					break
				end
			end
		end
		if need_reassign then
			for k = 1, n do
				comps[idxs[k]].follow_index = k
			end
		end
	end
	assign_follow_indices("ketu")
	assign_follow_indices("rahu")
	st.companions = comps
end

local function cache_flags_for_stat(stat)
	if stat == "speed" then return CacheFlag.CACHE_SPEED end
	if stat == "tears" then return CacheFlag.CACHE_FIREDELAY end
	if stat == "damage" then return CacheFlag.CACHE_DAMAGE end
	if stat == "range" then return CacheFlag.CACHE_RANGE end
	if stat == "shotspeed" then return CacheFlag.CACHE_SHOTSPEED end
	if stat == "luck" then return CacheFlag.CACHE_LUCK end
	return nil
end

local function get_resource(player, stat)
	if stat == "coins" then return player:GetNumCoins() end
	if stat == "bombs" then return player:GetNumBombs() end
	if stat == "keys" then return player:GetNumKeys() end
	return 0
end

local function get_resource_max(player, stat)
	local def = hud_nodes.RESOURCE_DEF and hud_nodes.RESOURCE_DEF[stat]
	if def and def.get_max then
		local ok, v = pcall(def.get_max, player)
		if ok and type(v) == "number" then
			return math.max(0, math.floor(v))
		end
	end
	if stat == "coins" and player.GetMaxCoins then return player:GetMaxCoins() end
	if stat == "bombs" and player.GetMaxBombs then return player:GetMaxBombs() end
	if stat == "keys" and player.GetMaxKeys then return player:GetMaxKeys() end
	return 99
end

local function set_resource(player, stat, value)
	value = math.max(0, math.floor(tonumber(value) or 0))
	local cur = get_resource(player, stat)
	local delta = value - cur
	if delta == 0 then return end
	if stat == "coins" then player:AddCoins(delta)
	elseif stat == "bombs" then player:AddBombs(delta)
	elseif stat == "keys" then player:AddKeys(delta)
	end
end

local function add_resource(player, stat, delta)
	if delta == 0 then return end
	set_resource(player, stat, get_resource(player, stat) + delta)
end

local function floor_key()
	local level = Game():GetLevel()
	if not level then return "nil" end
	local stage = level:GetStage() or 0
	local stage_type = level:GetStageType() or 0
	local dim = 0
	if auxi.GetDimension then
		dim = auxi.GetDimension() or 0
	elseif level.GetDimension then
		local ok, d = pcall(function() return level:GetDimension() end)
		if ok and d ~= nil then dim = d end
	end
	local stage_seed = 0
	local seeds = Game():GetSeeds()
	if seeds and seeds.GetStageSeed then
		stage_seed = seeds:GetStageSeed(stage) or 0
	end
	return table.concat({stage, stage_type, dim, stage_seed}, ":")
end

local function refresh_map_visibility()
	local level = Game():GetLevel()
	if level and level.UpdateVisibility then
		level:UpdateVisibility()
	end
	if Minimap and Minimap.Refresh then
		Minimap.Refresh()
	end
end

local function capture_map_baseline()
	local level = Game():GetLevel()
	if not level then return nil, nil end
	local snap = {}
	local visited = {}
	local rooms = level:GetRooms()
	for i = 0, rooms.Size - 1 do
		local targ = rooms:Get(i)
		if targ and targ.SafeGridIndex and targ.SafeGridIndex >= 0
			and targ.ListIndex and targ.ListIndex >= 0 then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex)
			if desc and desc.ListIndex == targ.ListIndex then
				local li = targ.ListIndex
				snap[li] = desc.DisplayFlags or 0
				visited[li] = desc.VisitedCount or 0
			end
		end
	end
	return snap, visited
end

local function get_map_overlay()
	local root = state_root()
	return root.map_overlay
end

local function set_map_overlay(ov)
	state_root().map_overlay = ov
end

local function permanent_map_flags(ov, list_index)
	local base = (ov.snap and ov.snap[list_index]) or 0
	local earned = (ov.earned and ov.earned[list_index]) or 0
	return bit_or(base, earned)
end

--- Absorb real map progress while temporary reveal/shade overwrite DisplayFlags.
--- Shade: trust live DisplayFlags before we re-zero. Reveal-only: VisitedCount +
--- external mutations vs last_written (Ketu's forced 5 must not become permanent).
local function harvest_map_earned(ov)
	if not ov or not ov.snap then return end
	if ov.floor_key ~= floor_key() then return end
	local level = Game():GetLevel()
	if not level then return end
	ov.earned = ov.earned or {}
	ov.visited_snap = ov.visited_snap or {}
	ov.last_written = ov.last_written or {}
	local shade = (ov.shade_refs or 0) > 0
	local reveal = (ov.reveal_refs or 0) > 0
	local rooms = level:GetRooms()
	for i = 0, rooms.Size - 1 do
		local targ = rooms:Get(i)
		if targ and targ.SafeGridIndex and targ.SafeGridIndex >= 0
			and targ.ListIndex and targ.ListIndex >= 0 then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex)
			if desc and desc.ListIndex == targ.ListIndex then
				local li = targ.ListIndex
				local cur = desc.DisplayFlags or 0
				local visit = desc.VisitedCount or 0
				local visit0 = ov.visited_snap[li] or 0
				local earned = ov.earned[li] or 0
				if visit > visit0 then
					earned = bit_or(earned, MAP_FLAGS_VISIBLE_ICON)
				end
				if shade then
					-- Engine visits / permanent map items briefly write flags before re-shade.
					if cur ~= 0 then
						earned = bit_or(earned, cur)
					end
				elseif reveal then
					local written = ov.last_written[li]
					if written ~= nil and cur ~= written then
						earned = bit_or(earned, cur)
					end
				else
					if cur ~= 0 then
						earned = bit_or(earned, cur)
					end
				end
				if earned ~= 0 then
					ov.earned[li] = earned
				end
			end
		end
	end
end

--- Write snap|earned only. Caller must harvest while overlay mode refs are still valid.
local function restore_map_snap(ov)
	if not ov or not ov.snap then return end
	if ov.floor_key ~= floor_key() then return end
	local level = Game():GetLevel()
	if not level then return end
	local rooms = level:GetRooms()
	for i = 0, rooms.Size - 1 do
		local targ = rooms:Get(i)
		if targ and targ.ListIndex ~= nil then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex)
			if desc and desc.ListIndex == targ.ListIndex then
				local li = targ.ListIndex
				if ov.snap[li] ~= nil or (ov.earned and ov.earned[li]) then
					desc.DisplayFlags = permanent_map_flags(ov, li)
				end
			end
		end
	end
	refresh_map_visibility()
end

local function count_earned_rooms(ov)
	local n = 0
	if not ov or type(ov.earned) ~= "table" then return 0 end
	for _, flags in pairs(ov.earned) do
		if (tonumber(flags) or 0) ~= 0 then
			n = n + 1
		end
	end
	return n
end

local function apply_map_flags_from_overlay()
	local ov = get_map_overlay()
	if not ov or not ov.snap then return end
	if ov.floor_key ~= floor_key() then
		set_map_overlay(nil)
		return
	end
	harvest_map_earned(ov)
	local level = Game():GetLevel()
	if not level then return end
	local rooms = level:GetRooms()
	local shade = (ov.shade_refs or 0) > 0
	local reveal = (ov.reveal_refs or 0) > 0
	ov.last_written = ov.last_written or {}
	for i = 0, rooms.Size - 1 do
		local targ = rooms:Get(i)
		if targ and targ.SafeGridIndex and targ.SafeGridIndex >= 0
			and targ.ListIndex and targ.ListIndex >= 0 then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex)
			if desc and desc.ListIndex == targ.ListIndex then
				local li = targ.ListIndex
				local flags
				if shade then
					flags = 0
				elseif reveal then
					flags = MAP_FLAGS_VISIBLE_ICON
				else
					flags = permanent_map_flags(ov, li)
				end
				desc.DisplayFlags = flags
				ov.last_written[li] = flags
			end
		end
	end
	refresh_map_visibility()
end

local _map_shade_tick_frame = -1

--- While Rahu shade is up, permanent map items may briefly write DisplayFlags.
--- Harvest those bits into earned, then re-zero once per game frame.
local function tick_map_shade_progress()
	local ov = get_map_overlay()
	if not ov or (ov.shade_refs or 0) <= 0 then return end
	if ov.floor_key ~= floor_key() then return end
	local gf = Game():GetFrameCount()
	if _map_shade_tick_frame == gf then return end
	_map_shade_tick_frame = gf
	local level = Game():GetLevel()
	if not level then return end
	local leaked = false
	local rooms = level:GetRooms()
	for i = 0, rooms.Size - 1 do
		local targ = rooms:Get(i)
		if targ and targ.SafeGridIndex and targ.SafeGridIndex >= 0 then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex)
			if desc and desc.ListIndex == targ.ListIndex and (desc.DisplayFlags or 0) ~= 0 then
				leaked = true
				break
			end
		end
	end
	harvest_map_earned(ov)
	if leaked then
		apply_map_flags_from_overlay()
	end
end

local function invalidate_map_overlay(reason)
	local ov = get_map_overlay()
	if not ov then return end
	-- Harvest under the still-active reveal/shade mode, then restore permanently.
	if ov.floor_key == floor_key() then
		local earned_before = count_earned_rooms(ov)
		harvest_map_earned(ov)
		probe("MAP_OVERLAY_HARVEST", {
			via = "invalidate",
			reason = reason,
			reveal_refs = ov.reveal_refs,
			shade_refs = ov.shade_refs,
			earned_before = earned_before,
			earned_after = count_earned_rooms(ov),
		})
		restore_map_snap(ov)
	end
	set_map_overlay(nil)
	probe("MAP_OVERLAY_INVALIDATE", {reason = reason, floor_key = ov.floor_key})
end

local function new_map_overlay(fk, inherit)
	local snap, visited
	if inherit and inherit.floor_key == fk and inherit.snap then
		snap = inherit.snap
		visited = inherit.visited_snap or {}
	else
		snap, visited = capture_map_baseline()
		snap = snap or {}
		visited = visited or {}
	end
	return {
		floor_key = fk,
		snap = snap,
		visited_snap = visited,
		earned = (inherit and inherit.floor_key == fk and inherit.earned) or {},
		last_written = {},
		reveal_refs = 0,
		shade_refs = 0,
	}
end

local function map_overlay_acquire(mode)
	local fk = floor_key()
	local ov = get_map_overlay()
	if not ov or ov.floor_key ~= fk or not ov.snap then
		ov = new_map_overlay(fk, ov)
		set_map_overlay(ov)
	end
	ov.earned = ov.earned or {}
	ov.visited_snap = ov.visited_snap or {}
	ov.last_written = ov.last_written or {}
	if mode == "reveal" then
		ov.reveal_refs = (ov.reveal_refs or 0) + 1
	elseif mode == "shade" then
		ov.shade_refs = (ov.shade_refs or 0) + 1
	end
	apply_map_flags_from_overlay()
	probe("MAP_OVERLAY_ACQUIRE", {
		mode = mode,
		reveal_refs = ov.reveal_refs,
		shade_refs = ov.shade_refs,
		floor_key = ov.floor_key,
	})
end

local function map_overlay_release(mode)
	local ov = get_map_overlay()
	if not ov then return end
	-- Harvest while reveal/shade refs still describe the live overlay mode.
	-- Decreasing first would make Ketu's temporary DisplayFlags=5 look like earned progress.
	local refs_before = {
		reveal = ov.reveal_refs or 0,
		shade = ov.shade_refs or 0,
	}
	local earned_before = count_earned_rooms(ov)
	harvest_map_earned(ov)
	local earned_after_harvest = count_earned_rooms(ov)
	probe("MAP_OVERLAY_HARVEST", {
		via = "release",
		mode = mode,
		reveal_refs = refs_before.reveal,
		shade_refs = refs_before.shade,
		earned_before = earned_before,
		earned_after = earned_after_harvest,
	})

	if mode == "reveal" then
		ov.reveal_refs = math.max(0, (ov.reveal_refs or 0) - 1)
	elseif mode == "shade" then
		ov.shade_refs = math.max(0, (ov.shade_refs or 0) - 1)
	end
	if (ov.reveal_refs or 0) <= 0 and (ov.shade_refs or 0) <= 0 then
		if ov.floor_key == floor_key() then
			restore_map_snap(ov)
		end
		set_map_overlay(nil)
		probe("MAP_OVERLAY_RESTORE", {
			floor_key = ov.floor_key,
			via = "release",
			mode = mode,
			reveal_refs_before = refs_before.reveal,
			shade_refs_before = refs_before.shade,
			reveal_refs = 0,
			shade_refs = 0,
			earned_rooms = earned_after_harvest,
		})
	else
		apply_map_flags_from_overlay()
		probe("MAP_OVERLAY_RELEASE", {
			mode = mode,
			reveal_refs_before = refs_before.reveal,
			shade_refs_before = refs_before.shade,
			reveal_refs = ov.reveal_refs,
			shade_refs = ov.shade_refs,
			earned_rooms = earned_after_harvest,
		})
	end
end

--- Live = real occupancy OR still inside a scheduled tail (TAIL_FRAMES).
--- active_count only tracks geometry occupancy; do not invent tokens for delay.
local function effect_is_live(eff)
	if not eff or eff._torn then
		return false
	end
	if (eff.active_count or 0) > 0 then
		return true
	end
	local release_at = eff.release_at
	if type(release_at) == "number" then
		return Game():GetFrameCount() < release_at
	end
	return false
end

local function sync_map_overlay_from_effects()
	local root = state_root()
	local fk = floor_key()
	local reveal, shade = 0, 0
	for _, st in pairs(root.players or {}) do
		if type(st) == "table" and type(st.effects) == "table" then
			for _, eff in pairs(st.effects) do
				if effect_is_live(eff) then
					if eff.kind == "map_reveal" then reveal = reveal + 1 end
					if eff.kind == "map_shade" then shade = shade + 1 end
				end
			end
		end
	end
	if reveal + shade <= 0 then
		local ov = get_map_overlay()
		if ov then
			if ov.floor_key == fk then
				-- Overlay still holds the previous mode refs; harvest under that mode first.
				local earned_before = count_earned_rooms(ov)
				harvest_map_earned(ov)
				probe("MAP_OVERLAY_HARVEST", {
					via = "sync_clear",
					reveal_refs = ov.reveal_refs,
					shade_refs = ov.shade_refs,
					earned_before = earned_before,
					earned_after = count_earned_rooms(ov),
				})
				restore_map_snap(ov)
				probe("MAP_OVERLAY_RESTORE", {
					floor_key = ov.floor_key,
					via = "sync_clear",
					reveal_refs_before = ov.reveal_refs,
					shade_refs_before = ov.shade_refs,
					reveal_refs = 0,
					shade_refs = 0,
					earned_rooms = count_earned_rooms(ov),
				})
			end
			set_map_overlay(nil)
		end
		return
	end
	local ov = get_map_overlay()
	if not ov or ov.floor_key ~= fk or not ov.snap then
		ov = new_map_overlay(fk, ov)
		set_map_overlay(ov)
	end
	ov.earned = ov.earned or {}
	ov.visited_snap = ov.visited_snap or {}
	ov.last_written = ov.last_written or {}
	-- If a mode is dropping via sync (not release), harvest under the old mode first.
	local old_reveal = ov.reveal_refs or 0
	local old_shade = ov.shade_refs or 0
	if reveal < old_reveal or shade < old_shade then
		harvest_map_earned(ov)
	end
	ov.reveal_refs = reveal
	ov.shade_refs = shade
	apply_map_flags_from_overlay()
end

--- Compatibility for layout capture: current DisplayFlags snapshot (may be overlay-forced).
local function capture_map_snap()
	local snap = select(1, capture_map_baseline())
	return snap
end

local function screen_to_world(screen_pos)
	return auxi.ui_screen_to_world(screen_pos)
end

local function star_world_pos(geo, lane, s, player)
	if geo and geo.track then
		local screen = orbit.position_at(geo.track, s, lane)
		local world = screen_to_world(screen)
		if world then return world, screen end
	end
	return player.Position, nil
end

local function effect_key(kind, stat, lane)
	return tostring(kind) .. "|" .. tostring(stat) .. "|" .. tostring(lane or "")
end

local function live_ketu_infinite(st, stat)
	for _, eff in pairs(st.effects) do
		if effect_is_live(eff) and eff.kind == "resource_infinite" and eff.stat == stat
			and type(eff.snapshot) == "number" then
			return eff
		end
	end
	return nil
end

local function live_ketu_temp_coins(st)
	for _, eff in pairs(st.effects) do
		if effect_is_live(eff) and eff.kind == "ketu_temp_coins"
			and type(eff.coin_remaining) == "number" then
			return eff
		end
	end
	return nil
end

local function teardown_effect(st, player, eff)
	if not eff or eff._torn then return end
	eff._torn = true
	eff.applied = false
	eff.release_at = nil
	eff.active_count = 0
	eff.occupying = {}
	if not player then return end

	if eff.kind == "resource_infinite" and eff.stat and type(eff.snapshot) == "number" then
		set_resource(player, eff.stat, eff.snapshot)
		local pre = eff.preexisting_seal_tokens or {}
		for _, o in pairs(st.effects) do
			if o.kind == "rahu_seal" and o.stat == eff.stat and not o._torn then
				local tok = tostring(o.inst_token or "")
				-- Cancel only seals that opened during this Ketu window.
				-- sealed_amount is the sole debt authority (amount is legacy alias).
				if tok ~= "" and not pre[tok] then
					o.sealed_amount = 0
					o.amount = 0
					o.power_tier = 0
				end
			end
		end
		probe("RESOURCE_SNAPSHOT_RESTORE", {
			stat = eff.stat,
			snapshot = eff.snapshot,
		})
	end

	if eff.kind == "ketu_temp_coins" then
		local rem = math.max(0, math.floor(tonumber(eff.coin_remaining) or 0))
		local absorbed = math.max(0, math.floor(tonumber(eff.sealed_absorb) or 0))
		if absorbed > 0 then
			-- Temp coins already folded into a Rahu seal opened during this window.
			for _, o in pairs(st.effects) do
				if o.kind == "rahu_seal" and o.stat == "coins" and not o._torn then
					local sealed = math.max(0, tonumber(o.sealed_amount) or 0)
					local cut = math.min(absorbed, sealed)
					o.sealed_amount = sealed - cut
					o.amount = o.sealed_amount
					absorbed = absorbed - cut
					if absorbed <= 0 then break end
				end
			end
			probe("KETU_COIN_SEAL_ABSORB_CLEAR", {cut_left = absorbed})
		elseif rem > 0 then
			local have = get_resource(player, "coins")
			local take = math.min(rem, have)
			if take > 0 then
				set_resource(player, "coins", have - take)
			end
			probe("KETU_COIN_RECLAIM", {rem = rem, took = take, have = have})
		end
		eff.coin_remaining = 0
		eff.sealed_absorb = 0
	end

	if eff.kind == "rahu_seal" and eff.stat then
		-- Additive restore: remaining + sealed_amount (keeps mid-seal pickups/spends).
		-- Clamp to hold cap so restore cannot overflow after pickups during seal.
		local amt = tonumber(eff.sealed_amount) or 0
		if amt > 0 then
			local cap = get_resource_max(player, eff.stat)
			local cur = get_resource(player, eff.stat)
			local restored = math.min(cap, cur + amt)
			set_resource(player, eff.stat, restored)
			local ketu = live_ketu_infinite(st, eff.stat)
			if ketu and ketu.preexisting_seal_tokens
				and ketu.preexisting_seal_tokens[tostring(eff.inst_token or "")] then
				ketu.snapshot = (ketu.snapshot or 0) + amt
			end
			probe("RESOURCE_SEAL_RESTORE", {
				stat = eff.stat,
				amount = amt,
				before = cur,
				after = restored,
				cap = cap,
			})
		end
		eff.sealed_amount = 0
		eff.amount = 0
		eff.power_tier = 0
	end

	if eff.kind == "rahu_heart_soft" then
		if (eff.sealed_soul or 0) > 0 then
			player:AddSoulHearts(eff.sealed_soul)
		end
		if (eff.sealed_red or 0) > 0 then
			player:AddHearts(eff.sealed_red)
		end
		eff.sealed_soul = 0
		eff.sealed_red = 0
	end

	if eff.kind == "map_reveal" and eff.map_held then
		eff.map_held = false
		map_overlay_release("reveal")
	end
	if eff.kind == "map_shade" and eff.map_held then
		eff.map_held = false
		map_overlay_release("shade")
	end

	if eff.kind == "ketu_active_charge" and eff.slot ~= nil then
		local rem = math.max(0, tonumber(eff.charge_remaining) or 0)
		if rem > 0 then
			item_hud_fx.reduce_charge(player, eff.slot, rem)
		end
		eff.charge_remaining = 0
		probe("KETU_ACTIVE_RECLAIM", {slot = eff.slot, rem = rem})
	end

	-- Rahu extracted active charge: return whatever was not spent as shots.
	-- Green bar and battery bar are restored separately. Overcharge-only grant
	-- drops the green remainder when the player has no Battery.
	if eff.kind == "rahu_active_drain" and eff.slot ~= nil then
		local rem = math.max(0, math.floor(tonumber(eff.charge_remaining) or 0))
		local sealed = math.max(0, math.floor(tonumber(eff.sealed_charge) or 0))
		local bat0 = eff.sealed_battery
		local main0 = eff.sealed_main
		if type(bat0) ~= "number" or type(main0) ~= "number" then
			main0 = sealed
			bat0 = 0
		end
		main0 = math.max(0, math.floor(main0))
		bat0 = math.max(0, math.floor(bat0))
		local spent = math.max(0, sealed - rem)
		local bat_left = math.max(0, bat0 - spent)
		local main_left = math.max(0, main0 - math.max(0, spent - bat0))
		local got_main, got_bat = 0, 0
		if main_left > 0 or bat_left > 0 then
			got_main, got_bat = item_hud_fx.restore_drained_charge(player, eff.slot, main_left, bat_left)
		end
		probe("RAHU_ACTIVE_RESTORE", {
			slot = eff.slot,
			restored = rem,
			sealed = sealed,
			main = main_left,
			battery = bat_left,
			got_main = got_main,
			got_battery = got_bat,
		})
		eff.charge_remaining = 0
		eff.sealed_charge = 0
		eff.sealed_main = 0
		eff.sealed_battery = 0
	end

	if eff.kind == "ketu_imitate_item" then
		Imitate_item_holder.Evaluate_Imitate_Items(player)
	end
	if eff.kind == "ketu_imitate_trinket" then
		Imitate_item_holder.Evaluate_Imitate_Trinkets(player)
	end

	if eff.kind == "rahu_block_item" and eff.item_id and eff.block_owned then
		item_hud_fx.release_block_collectible(st, player, eff.item_id, eff.inst_token)
		for _, o in pairs(st.effects) do
			if effect_is_live(o) and o.kind == "ketu_imitate_item" and o.item_id == eff.item_id then
				o.imitate_suppressed = false
			end
		end
		Imitate_item_holder.Evaluate_Imitate_Items(player)
	end
	if eff.kind == "rahu_block_trinket" and eff.trinket_id and eff.block_owned then
		item_hud_fx.release_block_trinket(st, player, eff.trinket_id, eff.inst_token)
		for _, o in pairs(st.effects) do
			if effect_is_live(o) and o.kind == "ketu_imitate_trinket" and o.trinket_id == eff.trinket_id then
				o.imitate_suppressed = false
			end
		end
		Imitate_item_holder.Evaluate_Imitate_Trinkets(player)
	end
end

local function power_tier_from_amount(amount)

	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return 0 end
	if amount <= 2 then return 1 end
	if amount <= 5 then return 2 end
	if amount <= 12 then return 3 end
	if amount <= 24 then return 4 end
	return 5
end

local function fire_interval_for(kind, tier)
	local row = RAHU_FIRE_INTERVAL[kind]
	if not row then return 12 end
	tier = math.max(1, math.min(5, tonumber(tier) or 1))
	return row[tier] or row[#row] or 12
end

local function pick_enemy_near(origin, range)
	local best, best_d
	range = range or 280
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		local npc = ent:ToNPC()
		if npc and npc:IsVulnerableEnemy() and not npc:IsDead()
			and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			local d = origin:Distance(npc.Position)
			if d <= range and (not best_d or d < best_d) then
				best, best_d = npc, d
			end
		end
	end
	return best
end

--- Rahu aim geometry: HUD star → screen_to_world spawn; render only cancels PO.Y.
--- Soft wobble only here (node hover is render cosmetics; avoid forward-ref on hover helper).
local function celestial_muzzle(player, st, geo)
	local origin = player.Position
	if geo and geo.track then
		local s = st.rahu_s
		local screen = orbit.position_at(geo.track, s, orbit.LANE_OUTER)
		local tan = orbit.tangent_at(geo.track, s, orbit.LANE_OUTER)
		local nor = orbit.normal_at(geo.track, s, orbit.LANE_OUTER)
		local frame = Isaac.GetFrameCount()
		local phase = frame * 0.055 + 2.11
		local radial = math.sin(phase) * 0.85 + math.sin(phase * 0.37 + 2.1) * 0.15
		local stang = math.sin(phase * 0.9 + 1.1)
		screen = Vector(
			screen.X + nor.X * WOBBLE_MAIN_N * radial + tan.X * WOBBLE_MAIN_T * stang,
			screen.Y + nor.Y * WOBBLE_MAIN_N * radial + tan.Y * WOBBLE_MAIN_T * stang
		)
		local world = screen_to_world(screen)
		if world then origin = world end
	end
	return origin
end

--- Returns origin, dir, target. target/dir nil when no legal enemy.
local function aim_from_star(player, st, geo)
	local origin = celestial_muzzle(player, st, geo)
	local target = pick_enemy_near(origin, RAHU_SEEK_RANGE)
	if not target then
		return origin, nil, nil
	end
	local dir = target.Position - origin
	if dir:LengthSquared() < 0.01 then
		return origin, nil, nil
	end
	return origin, dir:Normalized(), target
end

-- Map formation cell spacing (world units per floor-grid step).
-- Formal default: 11/11 (in-game tested on recolor-only atlas). GoodTrip 8×7 remains
-- a screen-pitch reference only (MAP_PITCH_X/Y); not assigned as world Cell.
local MAP_CELL_W_DEFAULT = 11
local MAP_CELL_H_DEFAULT = 11
local MAP_CELL_DBG_MIN = 6
local MAP_CELL_DBG_MAX = 30
local MAP_PITCH_X = 8 -- GoodTrip screen pitch X (reference; not world default)
local MAP_PITCH_Y = 7 -- GoodTrip screen pitch Y (reference; not world default)
-- Source minimap cell (vanilla RoomUnvisited 1x1). Sprite-bound debug only.
local MAP_SRC_CELL_W = 9
local MAP_SRC_CELL_H = 8
-- All Rahu specialty tear icons use Scale 1.0 (no unjustified shrink).
local MAP_TEAR_SCALE = 1.0
-- Hard entity safety only; do not subsample an incomplete map under this cap.
local MAP_VOLLEY_HARD_CAP = 96
local MAP_VOLLEY_INTERVAL_BASE = 18
local MAP_VOLLEY_INTERVAL_PER_ROOM = 3

-- Session-only formation debug (never save.elses).
local map_formation_dbg = {
	cell_x = MAP_CELL_W_DEFAULT,
	cell_y = MAP_CELL_H_DEFAULT,
	show_anchors = false,
	show_sprite_bounds = false,
	show_logical_cells = false,
	show_sprite_pivot = false,
}
-- Birth anchors from the latest volley when any formation overlay is on.
local map_formation_anchors = {}

local function clamp_map_cell(v, fallback)
	v = tonumber(v)
	if not v then return fallback end
	if v < MAP_CELL_DBG_MIN then return MAP_CELL_DBG_MIN end
	if v > MAP_CELL_DBG_MAX then return MAP_CELL_DBG_MAX end
	return v
end

local function get_map_cell_x()
	return clamp_map_cell(map_formation_dbg.cell_x, MAP_CELL_W_DEFAULT)
end

local function get_map_cell_y()
	return clamp_map_cell(map_formation_dbg.cell_y, MAP_CELL_H_DEFAULT)
end

-- RoomShape 1..12 → AABB grid size. Icon TL must be AABB top-left (see map_aabb_top_left).
local MAP_SHAPE_GRID = {
	[1] = {w = 1, h = 1}, -- 1x1
	[2] = {w = 1, h = 1}, -- IH
	[3] = {w = 1, h = 1}, -- IV
	[4] = {w = 1, h = 2}, -- 1x2
	[5] = {w = 1, h = 2}, -- IIV
	[6] = {w = 2, h = 1}, -- 2x1
	[7] = {w = 2, h = 1}, -- IIH
	[8] = {w = 2, h = 2}, -- 2x2
	[9] = {w = 2, h = 2}, -- LTL
	[10] = {w = 2, h = 2}, -- LTR
	[11] = {w = 2, h = 2}, -- LBL
	[12] = {w = 2, h = 2}, -- LBR
}

-- Occupancy relative to AABB TL (1=solid, 0=L gap). Verified vs RoomUnvisited fill %.
local MAP_SHAPE_MASK = {
	[1] = {{1}},
	[2] = {{1}},
	[3] = {{1}},
	[4] = {{1}, {1}},
	[5] = {{1}, {1}},
	[6] = {{1, 1}},
	[7] = {{1, 1}},
	[8] = {{1, 1}, {1, 1}},
	[9] = {{0, 1}, {1, 1}}, -- LTL missing TL
	[10] = {{1, 0}, {1, 1}}, -- LTR missing TR
	[11] = {{1, 1}, {0, 1}}, -- LBL missing BL
	[12] = {{1, 1}, {1, 0}}, -- LBR missing BR
}

-- Full opaque AABB (incl. purple rim) relative to vanilla pivot (-2,-2).
-- Sparse right/bottom edge is vanilla (17/15 vs 18/16); not a scale bug.
local MAP_SHAPE_BODY_PX = {
	[1] = {w = 9, h = 8, ox = 2, oy = 2},
	[2] = {w = 9, h = 8, ox = 2, oy = 2},
	[3] = {w = 9, h = 8, ox = 2, oy = 2},
	[4] = {w = 9, h = 15, ox = 2, oy = 2},
	[5] = {w = 9, h = 15, ox = 2, oy = 2},
	[6] = {w = 17, h = 8, ox = 2, oy = 2},
	[7] = {w = 17, h = 8, ox = 2, oy = 2},
	[8] = {w = 17, h = 15, ox = 2, oy = 2},
	[9] = {w = 17, h = 15, ox = 2, oy = 2},
	[10] = {w = 17, h = 15, ox = 2, oy = 2},
	[11] = {w = 17, h = 15, ox = 2, oy = 2},
	[12] = {w = 17, h = 15, ox = 2, oy = 2},
}

-- Explicit Shape → static ANM2 animation (RoomUnvisited frame i = Shape i+1).
local function map_shape_anim_name(shape)
	shape = math.floor(tonumber(shape) or 1)
	if shape < 1 then shape = 1 end
	if shape > 12 then shape = 12 end
	return "RoomShape" .. shape, shape
end

local function map_shape_grid_size(shape)
	local row = MAP_SHAPE_GRID[math.floor(tonumber(shape) or 1)]
	if row then return row.w, row.h end
	return 1, 1
end

local function map_shape_mask(shape)
	return MAP_SHAPE_MASK[math.floor(tonumber(shape) or 1)] or {{1}}
end

--- AABB top-left floor index for map icons.
--- GridIndex is always AABB TL (for LTL = the missing gap cell).
--- SafeGridIndex is TL for all shapes EXCEPT LTL (SafeGI = top-right occupied).
local function map_aabb_top_left_index(desc, shape)
	shape = math.floor(tonumber(shape) or 1)
	if desc.GridIndex ~= nil and desc.GridIndex >= 0 then
		return desc.GridIndex
	end
	local safe = desc.SafeGridIndex
	if type(safe) ~= "number" or safe < 0 then return nil end
	-- RoomShape.ROOMSHAPE_LTL == 9
	if shape == 9 then
		return safe - 1
	end
	return safe
end

local function map_formation_overlay_wanted()
	return map_formation_dbg.show_anchors == true
		or map_formation_dbg.show_sprite_bounds == true
		or map_formation_dbg.show_logical_cells == true
		or map_formation_dbg.show_sprite_pivot == true
end

local function map_volley_interval(fired_count)
	fired_count = math.max(0, math.floor(tonumber(fired_count) or 0))
	return math.max(MAP_VOLLEY_INTERVAL_BASE, fired_count * MAP_VOLLEY_INTERVAL_PER_ROOM)
end

--- Room layout before shade: use overlay snap DisplayFlags when available.
--- Stores AABB top-left (GridIndex) + Shape mask; no pixel spacing baked in.
--- Fire time multiplies by live Cell X/Y so ImGui tweaks apply on the next volley.
local function collect_floor_room_layout(flag_snap)
	local rooms_out = {}
	local level = Game():GetLevel()
	if not level then return rooms_out end
	local rooms = level:GetRooms()
	local min_x, min_y = math.huge, math.huge
	local max_x, max_y = -math.huge, -math.huge
	for i = 0, rooms.Size - 1 do
		local targ = rooms:Get(i)
		if targ and targ.Data and targ.Data.Shape then
			local aabb_idx = map_aabb_top_left_index(targ, targ.Data.Shape)
			if aabb_idx and aabb_idx >= 0 then
				local flags
				if type(flag_snap) == "table" and targ.ListIndex ~= nil then
					flags = flag_snap[targ.ListIndex]
				else
					flags = targ.DisplayFlags
				end
				if flags and flags > 0 then
					local shape = math.floor(tonumber(targ.Data.Shape) or 1)
					local gw, gh = map_shape_grid_size(shape)
					local gx = aabb_idx % 13
					local gy = math.floor(aabb_idx / 13)
					rooms_out[#rooms_out + 1] = {
						shape = shape,
						grid_x = gx,
						grid_y = gy,
						grid_w = gw,
						grid_h = gh,
						grid_index = aabb_idx,
						safe_grid_index = targ.SafeGridIndex,
						mask = map_shape_mask(shape),
						list_index = targ.ListIndex,
					}
					if gx < min_x then min_x = gx end
					if gy < min_y then min_y = gy end
					if gx + gw > max_x then max_x = gx + gw end
					if gy + gh > max_y then max_y = gy + gh end
				end
			end
		end
	end
	if #rooms_out == 0 then
		return rooms_out
	end
	-- AABB center in floor-grid units (exclusive max).
	local cx = (min_x + max_x) * 0.5
	local cy = (min_y + max_y) * 0.5
	for i = 1, #rooms_out do
		local room = rooms_out[i]
		room.local_x = room.grid_x - cx
		room.local_y = room.grid_y - cy
		room.center_x = cx
		room.center_y = cy
	end
	return rooms_out
end

local function map_room_fire_offset(room, cell_x, cell_y)
	if type(room) ~= "table" then
		return Vector(0, 0)
	end
	if room.local_x ~= nil then
		return Vector(
			(tonumber(room.local_x) or 0) * cell_x,
			(tonumber(room.local_y) or 0) * cell_y
		)
	end
	-- Legacy in-memory snapshot that baked pixel dx/dy (pre-formation-debug).
	return Vector(tonumber(room.dx) or 0, tonumber(room.dy) or 0)
end

local function apply_rahu_map_sprite(tear, shape)
	if not tear then return end
	local anim, clamped = map_shape_anim_name(shape)
	local spr = tear:GetSprite()
	if not spr then return end
	if spr.GetFilename and spr:GetFilename() ~= RAHU_MAP_ANM2 then
		spr:Load(RAHU_MAP_ANM2, true)
	elseif not spr.GetFilename then
		spr:Load(RAHU_MAP_ANM2, true)
	end
	-- Static per-shape anim (FrameNum=1): Tear Update cannot walk RoomUnvisited frames.
	if spr.IsPlaying and spr:IsPlaying(anim) then
		spr:SetFrame(anim, 0)
	else
		spr:Play(anim, true)
		spr:SetFrame(anim, 0)
	end
	spr.Color = Color(1, 1, 1, 1)
	tear:GetData()[M.own_key .. "rahu_room"] = clamped
end

local function ensure_lane_motion(st, lane_key)
	return M._lane_of(st, lane_key)
end

local function interval_span(it, length)
	local begin_s = orbit.mod_distance(it.begin_s, length)
	local end_s = orbit.mod_distance(it.end_s, length)
	if begin_s <= end_s then
		return end_s - begin_s
	end
	return length - begin_s + end_s
end

--- Arc length traveling in lane direction from `from` to `to`.
local function directed_arc(from, to, length, forward)
	from = orbit.mod_distance(from, length)
	to = orbit.mod_distance(to, length)
	if forward then
		local d = to - from
		if d < 0 then d = d + length end
		return d
	end
	local d = from - to
	if d < 0 then d = d + length end
	return d
end

--- Normalized progress u in [0,1] through a node interval (forward: begin→end; reverse: end→begin).
local function interval_progress(it, s, length, forward)
	local span = interval_span(it, length)
	if span < 1e-3 then
		return 0.5
	end
	local traveled
	if forward then
		traveled = directed_arc(it.begin_s, s, length, true)
	else
		traveled = directed_arc(it.end_s, s, length, false)
	end
	if traveled > span then
		traveled = span
	end
	return math.max(0, math.min(1, traveled / span))
end

--- Speed mult from node progress: v(u)=1-(1-vmin)sin²(πu). Narrow intervals raise vmin.
local function node_speed_curve(u, span, length, vmin_base)
	local vmin = vmin_base or NODE_VMIN
	local span_frac = span / math.max(1, length)
	if vmin_base == nil and span_frac < NARROW_SPAN_FRAC then
		local t = span_frac / NARROW_SPAN_FRAC
		vmin = NODE_VMIN + (NARROW_VMIN - NODE_VMIN) * (1 - t)
	end
	local sn = math.sin(math.pi * u)
	return 1 - (1 - vmin) * (sn * sn)
end

--- Returns speed_mult relative to blank-aware advance (1 = normal / blank handled inside advance).
--- Never returns 0; hard DWELL removed in favor of continuous soft hover.
local function lane_speed_mult(st, lane_key, s, intervals, length, forward)
	local m = ensure_lane_motion(st, lane_key)
	local it = orbit.interval_at(intervals, s, length)
	if not it then
		m.last_node = nil
		m.local_u = nil
		m.phase = "CRUISE"
		return 1, m
	end
	local u = interval_progress(it, s, length, forward ~= false)
	m.last_node = it.id
	m.local_u = u
	local is_time = CTime and CTime.is_ketu_time and CTime.is_ketu_time(it)
	m.phase = is_time and "TIME" or "HOVER"
	local span = interval_span(it, length)
	local vmin = is_time and CTime.TIME_VMIN or nil
	return node_speed_curve(u, span, length, vmin), m
end

local function find_target_anchor(geo, node_id)
	if not geo or not node_id then
		return nil
	end
	local targets = geo.targets
	if type(targets) ~= "table" then
		return nil
	end
	for i = 1, #targets do
		local t = targets[i]
		if t and t.id == node_id and t.anchor then
			return t.anchor
		end
	end
	return nil
end

--- One-shot near-node path bend: ΔP = A_N E(u) N_toward + A_T E(u) sin(2πu) T.
local function node_hover_offset(geo, orbit_lane, s, u, node_id, tan, nor)
	if not NODE_HOVER_ENABLED or type(u) ~= "number" or not node_id then
		return Vector(0, 0)
	end
	if not geo or not geo.track then
		return Vector(0, 0)
	end
	local E = math.sin(math.pi * u)
	E = E * E
	if E < 1e-4 then
		return Vector(0, 0)
	end
	local track_pos = orbit.position_at(geo.track, s, orbit_lane)
	local n_sign = 1
	local anchor = find_target_anchor(geo, node_id)
	if anchor then
		local dx = anchor.X - track_pos.X
		local dy = anchor.Y - track_pos.Y
		local dist = math.sqrt(dx * dx + dy * dy)
		if dist > HOVER_ANCHOR_FADE_DIST then
			E = E * 0.15
		elseif dist > 0.01 then
			local dot = (dx / dist) * nor.X + (dy / dist) * nor.Y
			if dot < 0 then
				n_sign = -1
			end
		end
	end
	local sn = math.sin(2 * math.pi * u)
	return Vector(
		nor.X * n_sign * HOVER_A_N * E + tan.X * HOVER_A_T * E * sn,
		nor.Y * n_sign * HOVER_A_N * E + tan.Y * HOVER_A_T * E * sn
	)
end

--- Render-only: birth-frame PO.Y cancel that fades out (~8 Isaac render frames).
--- Does not touch Height / Falling* / Position / Velocity / PositionOffset.
local function arm_rahu_tear_visual(tear)
	if not tear then return end
	if not CraftFamiliar or not CraftFamiliar.arm_tear_cancel_po_y_fade then return end
	CraftFamiliar.arm_tear_cancel_po_y_fade(tear, 8)
end

--- Range via falling_for_range_vanilla (FA=0 + initial FS); PO.Y cancel only.
local function configure_rahu_tear(tear, vel, range)
	if not tear then return nil end
	if vel then
		tear.Velocity = vel
	end
	local h = RAHU_TEAR_HEIGHT
	local req_range = range or RAHU_RANGE_GENERIC
	local speed = vel and vel:Length() or nil
	local fa, fs, fall_meta = CraftTearParams.falling_for_range_vanilla(
		h, req_range, nil, speed
	)
	tear.Height = (fall_meta and fall_meta.height) or h
	tear.FallingAcceleration = fa
	tear.FallingSpeed = fs
	-- Spectral tears still hit entities; NONE avoids residual grid blocks on KEY variant.
	if EntityGridCollisionClass and EntityGridCollisionClass.GRIDCOLL_NONE then
		tear.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	end
	arm_rahu_tear_visual(tear)
	-- Probe-only mark + CONFIGURED sample (no-op when Tear Lifecycle sink unset).
	local d = tear:GetData()
	d[M.own_key .. "rahu_tear"] = true
	note_tear_lifecycle("CONFIGURED", tear, {
		requested_range = req_range,
		requested_speed = speed,
		range_mode = "vanilla_fs",
		raw_fa = 0,
		applied_fa = fa,
		calculated_fa = fa,
		calculated_fs = fs,
		fa_clamped = false,
		solver_status = fall_meta and fall_meta.status or nil,
		n_target = fall_meta and fall_meta.n_target or nil,
		predicted_land_frames = fall_meta and fall_meta.predicted_land_frames or nil,
		written_height = tear.Height,
		written_fs = tear.FallingSpeed,
		written_fa = tear.FallingAcceleration,
		po_y = tear.PositionOffset and tear.PositionOffset.Y or nil,
		variant = tear.Variant,
		grid_coll = tear.GridCollisionClass,
	})
	return tear
end

local function fire_rahu_coin(player, origin, direction, shot_index)
	shot_index = math.max(1, math.floor(shot_index or 1))
	local pattern_index = ((shot_index - 1) % #COIN_SPREAD_PATTERN) + 1
	local angle = COIN_SPREAD_PATTERN[pattern_index]
	local dir = direction:Rotated(angle)
	local vel = dir:Resized(RAHU_COIN_SPEED)
	local tear = attack_holder.FireTear(player, origin, vel, {
		mode = "untracked",
		damage_multiplier = RAHU_COIN_DAMAGE / math.max(0.1, player.Damage),
		can_be_eye = false,
		can_trigger_streak_end = false,
	})
	if not configure_rahu_tear(tear, vel, RAHU_RANGE_COIN) then return end
	tear.Scale = 1.0
	if tear.AddTearFlags and TearFlags.TEAR_GREED_COIN then
		tear:AddTearFlags(TearFlags.TEAR_GREED_COIN)
	end
	local spr = tear:GetSprite()
	spr:Load("gfx/002.020_coin tear.anm2", true)
	spr.Scale = Vector.One
	spr:Play("Rotate1", true)
	tear:GetData()[M.own_key .. "rahu_coin"] = true
end

local function fire_rahu_key(player, origin, direction, tier)
	tier = math.max(1, math.min(5, tier or 1))
	local vel = direction:Resized(RAHU_KEY_SPEED)
	local variant = TearVariant.KEY or 43
	local ent = Isaac.Spawn(EntityType.ENTITY_TEAR, variant, 0, origin, vel, player)
	local tear = ent and ent:ToTear()
	if not tear then return end
	attack_holder.MarkIgnore(tear)
	tear.Parent = player
	tear.SpawnerEntity = player
	tear.CollisionDamage = RAHU_KEY_DAMAGE[tier] or 5
	configure_rahu_tear(tear, vel, RAHU_RANGE_KEY)
	if tear.AddTearFlags then
		local flags = 0
		if TearFlags.TEAR_PIERCING then flags = flags | TearFlags.TEAR_PIERCING end
		if TearFlags.TEAR_SPECTRAL then flags = flags | TearFlags.TEAR_SPECTRAL end
		if flags ~= 0 then tear:AddTearFlags(flags) end
	end
	tear:GetData()[M.own_key .. "rahu_key"] = true
end

local function apply_rahu_bomb_blast(pos, player)
	for _, entity in ipairs(Isaac.FindInRadius(pos, RAHU_BOMB_RADIUS, EntityPartition.ENEMY)) do
		local npc = entity:ToNPC()
		if npc and npc:IsVulnerableEnemy() and not npc:IsDead()
			and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			npc:TakeDamage(RAHU_BOMB_DAMAGE, DamageFlag.DAMAGE_EXPLOSION, EntityRef(player), 0)
		end
	end
end

local function fire_rahu_bomb(player, origin, direction)
	local vel = direction:Resized(RAHU_BOMB_SPEED)
	local variant = BombVariant.BOMB_THROWABLE or 13
	local ent = Isaac.Spawn(EntityType.ENTITY_BOMB, variant, 0, origin, vel, player)
	local bomb = ent and ent:ToBomb()
	if not bomb then return end
	attack_holder.MarkIgnore(bomb)
	bomb.Parent = player
	bomb.SpawnerEntity = player
	bomb.ExplosionDamage = 0
	if bomb.AddEntityFlags and EntityFlag.FLAG_FRIENDLY then
		bomb:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
	end
	if bomb.TryThrow then
		pcall(function()
			bomb:TryThrow(EntityRef(player), vel, math.abs(BOMB_THROW_HEIGHT))
		end)
	end
	bomb.Velocity = vel
	if bomb.SetFallSpeed then bomb:SetFallSpeed(BOMB_FALL_SPEED) end
	if bomb.SetFallAcceleration then bomb:SetFallAcceleration(BOMB_FALL_ACCEL) end
	if bomb.Height ~= nil then bomb.Height = BOMB_THROW_HEIGHT end
	if bomb.SetExplosionCountdown then
		bomb:SetExplosionCountdown(RAHU_BOMB_FUSE)
	end
	bomb:GetData()[M.own_key .. "rahu_bomb"] = {
		owner_hash = GetPtrHash(player),
		exploded = false,
	}
end

local function fire_rahu_heart(player, origin, direction, heart_kind)
	local vel = direction:Resized(RAHU_HEART_SPEED)
	local tear = attack_holder.FireTear(player, origin, vel, {
		mode = "untracked",
		damage_multiplier = RAHU_HEART_DAMAGE / math.max(0.1, player.Damage),
		can_be_eye = false,
		can_trigger_streak_end = false,
	})
	if not configure_rahu_tear(tear, vel, RAHU_RANGE_HEART) then return end
	tear.Scale = 1.0
	if tear.AddTearFlags and TearFlags.TEAR_SPECTRAL then
		tear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
	end
	local spr = tear:GetSprite()
	if heart_kind == "soul" then
		spr:Load("gfx/005.013_heart (soul).anm2", true)
		spr:Play("Idle", true)
	else
		spr:Load("gfx/005.011_heart.anm2", true)
		spr:Play("Idle", true)
	end
	tear:GetData()[M.own_key .. "rahu_heart"] = heart_kind
end

--- One room icon in the map formation. shared_vel is identical for every room tear.
local function fire_rahu_room_shape(player, origin, offset, shared_vel, shape)
	shape = math.max(1, math.floor(tonumber(shape) or 1))
	local spawn = origin + (offset or Vector(0, 0))
	local vel = shared_vel or Vector(0, 0)
	local tear = attack_holder.FireTear(player, spawn, vel, {
		mode = "untracked",
		damage_multiplier = RAHU_ROOM_DAMAGE / math.max(0.1, player.Damage),
		can_be_eye = false,
		can_trigger_streak_end = false,
	})
	if not configure_rahu_tear(tear, vel, RAHU_RANGE_ROOM) then return nil end
	tear.Scale = MAP_TEAR_SCALE
	if tear.AddTearFlags and TearFlags.TEAR_SPECTRAL then
		tear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
	end
	apply_rahu_map_sprite(tear, shape)
	return tear
end

--- Full-map volley: every snapshot room, same Velocity, axis-aligned formation (no aim rotate).
--- Returns actual fired count (for cooldown). Hard cap only; no random room skip.
local function fire_map_constellation(player, origin, direction, layout)
	if type(layout) ~= "table" or #layout == 0 or not direction then
		return 0
	end
	local cell_x = get_map_cell_x()
	local cell_y = get_map_cell_y()
	local shared_vel = direction:Resized(RAHU_ROOM_SPEED)
	local fired = 0
	local limit = math.min(#layout, MAP_VOLLEY_HARD_CAP)
	local record_anchors = map_formation_overlay_wanted()
	if record_anchors then
		map_formation_anchors = {}
	end
	for i = 1, limit do
		local room = layout[i]
		local local_off = map_room_fire_offset(room, cell_x, cell_y)
		if fire_rahu_room_shape(player, origin, local_off, shared_vel, room.shape) then
			fired = fired + 1
			if record_anchors then
				local spawn = origin + local_off
				local body = MAP_SHAPE_BODY_PX[math.floor(tonumber(room.shape) or 1)]
					or MAP_SHAPE_BODY_PX[1]
				map_formation_anchors[#map_formation_anchors + 1] = {
					x = spawn.X,
					y = spawn.Y,
					shape = room.shape,
					grid_x = room.grid_x,
					grid_y = room.grid_y,
					grid_w = room.grid_w,
					grid_h = room.grid_h,
					local_x = room.local_x,
					local_y = room.local_y,
					mask = room.mask or map_shape_mask(room.shape),
					cell_x = cell_x,
					cell_y = cell_y,
					body_w = body.w,
					body_h = body.h,
					body_ox = body.ox,
					body_oy = body.oy,
					scale = MAP_TEAR_SCALE,
				}
			end
		end
	end
	probe("RAHU_MAP_VOLLEY", {
		rooms = #layout,
		fired = fired,
		interval = map_volley_interval(fired),
		cell_x = cell_x,
		cell_y = cell_y,
	})
	return fired
end

local function companion_token(c)
	return tostring(c.token or ("legacy:" .. tostring(c.id)))
end

--- Fixed arc-length trail behind the main star on its lane.
--- σ = +1 (Ketu forward) / −1 (Rahu reverse). Nil during cross-lane transition.
local function companion_logical_s(st, c, main_s, length)
	if c.transition and c.transition.active then
		return nil
	end
	length = tonumber(length) or 0
	if length <= 0 then
		return main_s
	end
	local k = math.max(1, math.floor(tonumber(c.follow_index) or 1))
	local sigma = (c.lane == "rahu") and -1 or 1
	return orbit.mod_distance(main_s - sigma * k * COMP_ARC_STEP, length)
end

--- Render/hover sample at companion s (interval progress on current geometry).
local function companion_hover_sample(geo, c, s)
	if not geo or s == nil then
		return nil, nil
	end
	local intervals = (c.lane == "ketu") and geo.intervals_inner or geo.intervals_outer
	local length = (c.lane == "ketu") and geo.len_inner or geo.len_outer
	local it = orbit.interval_at(intervals, s, length)
	if not it then
		return nil, nil
	end
	local forward = c.lane ~= "rahu"
	return interval_progress(it, s, length, forward), it.id
end

local function tick_rahu_weapons(player, st, geo)
	for _, eff in pairs(st.effects) do
		if effect_is_live(eff) and (eff.active_count or 0) > 0 then
			local origin, dir, target = aim_from_star(player, st, geo)
			if not target or not dir then
				-- Pause cooldown; no blind fire.
			else
				local fx = M._fx(eff)
				fx.fire_cd = (fx.fire_cd or 0) - 1
				if fx.fire_cd <= 0 then
					if eff.kind == "rahu_seal" and eff.stat then
						local sealed = tonumber(eff.sealed_amount) or 0
						local tier = tonumber(eff.power_tier) or 0
						if sealed > 0 and tier > 0 then
							if eff.stat == "coins" then
								fx.coin_shot_index = (fx.coin_shot_index or 0) + 1
								fire_rahu_coin(player, origin, dir, fx.coin_shot_index)
								fx.fire_cd = fire_interval_for("coins", tier)
							elseif eff.stat == "keys" then
								fire_rahu_key(player, origin, dir, tier)
								fx.fire_cd = fire_interval_for("keys", tier)
							elseif eff.stat == "bombs" then
								fire_rahu_bomb(player, origin, dir)
								fx.fire_cd = fire_interval_for("bombs", tier)
							end
							probe("RAHU_WEAPON_TICK", {
								stat = eff.stat,
								tier = tier,
								sealed = sealed,
							})
						end
					elseif eff.kind == "rahu_heart_soft" then
						local soul = eff.sealed_soul or 0
						local red = eff.sealed_red or 0
						local tier = tonumber(eff.power_tier) or 0
						if (soul > 0 or red > 0) and tier > 0 then
							local kind
							if soul > 0 and red > 0 then
								fx.heart_toggle = not fx.heart_toggle
								kind = fx.heart_toggle and "soul" or "red"
							elseif soul > 0 then
								kind = "soul"
							else
								kind = "red"
							end
							fire_rahu_heart(player, origin, dir, kind)
							fx.fire_cd = fire_interval_for("hearts", tier)
							probe("RAHU_HEART_TICK", {kind = kind, soul = soul, red = red})
						end
					elseif eff.kind == "map_shade" then
						local layout = fx.map_layout
						if type(layout) ~= "table" or #layout == 0 then
							-- Captured at this open. Continue does not restore it.
							layout = {}
						end
						if #layout > 0 then
							local fired = fire_map_constellation(player, origin, dir, layout)
							-- Cooldown from actual fired count; no target ⇒ tick never reaches here.
							fx.fire_cd = map_volley_interval(fired)
						else
							fx.fire_cd = MAP_VOLLEY_INTERVAL_BASE
						end
					elseif eff.kind == "rahu_active_drain" and eff.slot ~= nil then
						-- Spend from sealed ledger only (bar already emptied on open).
						local rem = math.max(0, math.floor(tonumber(eff.charge_remaining) or 0))
						local cost = item_hud_fx.RAHU_ACTIVE_COST
						if rem >= cost then
							eff.charge_remaining = rem - cost
							item_hud_fx.fire_icon_tear(player, origin, dir, {
								jacobs = true,
								collectible_id = eff.item_id,
								damage_mult = 2.4,
								scale = 1.05,
							})
							probe("RAHU_ACTIVE_SHOT", {
								slot = eff.slot,
								spent = cost,
								rem = eff.charge_remaining,
							})
						end
						fx.fire_cd = item_hud_fx.RAHU_ACTIVE_INTERVAL
					elseif eff.kind == "rahu_block_item" and eff.item_id then
						item_hud_fx.fire_icon_tear(player, origin, dir, {
							collectible_id = eff.item_id,
							damage_mult = item_hud_fx.RAHU_ITEM_DAMAGE_MULT,
						})
						fx.fire_cd = item_hud_fx.RAHU_ITEM_INTERVAL
					elseif eff.kind == "rahu_block_trinket" and eff.trinket_id then
						item_hud_fx.fire_icon_tear(player, origin, dir, {
							trinket_id = eff.trinket_id,
							damage_mult = item_hud_fx.RAHU_ITEM_DAMAGE_MULT,
						})
						fx.fire_cd = item_hud_fx.RAHU_ITEM_INTERVAL
					end
				end
			end
		end
	end
end



local function apply_rahu_heart_seal(player, eff)
	local soul = player:GetSoulHearts() or 0
	local take_soul = math.min(4, soul)
	if take_soul > 0 then
		player:AddSoulHearts(-take_soul)
		eff.sealed_soul = take_soul
	else
		eff.sealed_soul = 0
	end
	local red = player:GetHearts() or 0
	local floor = (eff.sealed_soul > 0) and 0 or 1
	local take_red = math.min(2, math.max(0, red - floor))
	if take_red > 0 then
		player:AddHearts(-take_red)
		eff.sealed_red = take_red
	else
		eff.sealed_red = 0
	end
end

--- Resolve / reuse effect instance. Cancels pending tail; does not apply side effects.
--- Reuses untorn instance (including active_count==0 during tail) so applied/snapshot stay.
local function activate_effect(st, player, geo, spec)
	local key = effect_key(spec.kind, spec.stat, spec.lane)
	local eff = st.effects[key]
	if not eff or eff._torn then
		eff = {
			kind = spec.kind,
			stat = spec.stat,
			lane = spec.lane,
			node = spec.node,
			delta = spec.delta,
			slot = spec.slot,
			item_id = spec.item_id,
			trinket_id = spec.trinket_id,
			active_count = 0,
			occupying = {},
			applied = false,
			inst_token = tostring(st.next_eff or 1),
		}
		st.next_eff = (st.next_eff or 1) + 1
		st.effects[key] = eff
	end
	-- Re-enter during tail: cancel release only; keep applied/snapshot/map refs.
	eff.release_at = nil
	eff._torn = false
	eff.slot = spec.slot or eff.slot
	eff.item_id = spec.item_id or eff.item_id
	eff.trinket_id = spec.trinket_id or eff.trinket_id
	eff.node = spec.node or eff.node
	-- History identity for gold mark (edge item closest to the star).
	if spec.history_time ~= nil then
		eff.history_time = spec.history_time
	end
	if spec.history_occurrence ~= nil then
		eff.history_occurrence = spec.history_occurrence
	end
	if spec.trinket_slot ~= nil then
		eff.trinket_slot = spec.trinket_slot
	end
	return eff, key
end

local function apply_first_open(st, player, geo, eff)
	if eff.kind == "resource_infinite" and eff.stat then
		eff.snapshot = get_resource(player, eff.stat)
		eff.preexisting_seal_tokens = {}
		for _, o in pairs(st.effects) do
			if effect_is_live(o) and o.kind == "rahu_seal" and o.stat == eff.stat and o.inst_token then
				eff.preexisting_seal_tokens[tostring(o.inst_token)] = true
			end
		end
		local cap = get_resource_max(player, eff.stat)
		set_resource(player, eff.stat, cap)
		probe("RESOURCE_SNAPSHOT_SET", {
			stat = eff.stat,
			snapshot = eff.snapshot,
			cap = cap,
			preexisting_seals = eff.preexisting_seal_tokens,
		})
	elseif eff.kind == "rahu_seal" and eff.stat then
		local cur = get_resource(player, eff.stat)
		eff.sealed_amount = cur
		eff.amount = cur -- legacy mirror only; restore reads sealed_amount
		eff.power_tier = power_tier_from_amount(cur)
		local seal_fx = M._fx(eff)
		seal_fx.fire_cd = 0
		seal_fx.coin_shot_index = 0
		if cur > 0 then
			set_resource(player, eff.stat, 0)
		end
		-- Fold live Ketu temp coins into this seal so leave-reclaim does not double-take.
		if eff.stat == "coins" then
			local ketu = live_ketu_temp_coins(st)
			if ketu then
				local rem = math.max(0, math.floor(tonumber(ketu.coin_remaining) or 0))
				if rem > 0 then
					ketu.sealed_absorb = (tonumber(ketu.sealed_absorb) or 0) + rem
					ketu.coin_remaining = 0
					probe("KETU_COIN_ABSORBED_BY_SEAL", {absorb = rem})
				end
			end
		end
		probe("RESOURCE_SEAL_SET", {
			stat = eff.stat,
			sealed_amount = eff.sealed_amount,
			power_tier = eff.power_tier,
		})
	elseif eff.kind == "ketu_temp_coins" then
		local grant = KETU_TEMP_COINS
		player:AddCoins(grant)
		eff.coin_granted = grant
		eff.coin_remaining = grant
		eff.sealed_absorb = 0
		probe("KETU_COIN_GRANT", {granted = grant})
	elseif eff.kind == "rahu_heart_soft" then
		apply_rahu_heart_seal(player, eff)
		M._fx(eff).fire_cd = 0
		eff.power_tier = power_tier_from_amount((eff.sealed_soul or 0) + (eff.sealed_red or 0))
	elseif eff.kind == "map_reveal" then
		map_overlay_acquire("reveal")
		eff.map_held = true
	elseif eff.kind == "map_shade" then
		-- Collect layout from pre-shade visibility once, then shade.
		-- The room list is an attack scratch, not a save payload.
		local snap = capture_map_snap() or {}
		local layout = collect_floor_room_layout(snap)
		local shade_fx = M._fx(eff)
		shade_fx.map_layout = layout
		shade_fx.fire_cd = 0
		eff.power_tier = (#layout > 0) and 3 or 0
		map_overlay_acquire("shade")
		eff.map_held = true
		probe("MAP_LAYOUT_CAPTURE", {
			rooms = #layout,
			interval = map_volley_interval(#layout),
		})
	elseif eff.kind == "ketu_active_charge" and eff.slot ~= nil then
		local granted = item_hud_fx.grant_temp_charge(player, eff.slot, item_hud_fx.KETU_ACTIVE_BONUS)
		eff.charge_granted = granted
		eff.charge_remaining = granted
		probe("KETU_ACTIVE_GRANT", {slot = eff.slot, granted = granted})
	elseif eff.kind == "rahu_active_drain" and eff.slot ~= nil then
		-- Seal entire bar (incl. live Ketu temp on the same slot); restore remainder on leave.
		local main, bat, total = item_hud_fx.read_charges(player, eff.slot)
		main = math.max(0, math.floor(tonumber(main) or 0))
		bat = math.max(0, math.floor(tonumber(bat) or 0))
		total = math.max(0, math.floor(tonumber(total) or 0))
		if total > 0 then
			item_hud_fx.reduce_charge(player, eff.slot, total)
		end
		for _, o in pairs(st.effects) do
			if effect_is_live(o) and o.kind == "ketu_active_charge" and o.slot == eff.slot then
				-- Bar already emptied; zero Ketu ledger so leave-reclaim does not double-take.
				o.charge_remaining = 0
			end
		end
		eff.sealed_charge = total
		eff.sealed_main = main
		eff.sealed_battery = bat
		eff.charge_remaining = total
		M._fx(eff).fire_cd = 0
		probe("RAHU_ACTIVE_SEAL", {slot = eff.slot, sealed = total})
	elseif eff.kind == "ketu_imitate_item" and eff.item_id then
		if item_hud_fx.is_collectible_blocked_by_us(st, eff.item_id) then
			eff.imitate_suppressed = true
		else
			eff.imitate_suppressed = false
			Imitate_item_holder.Evaluate_Imitate_Items(player)
		end
	elseif eff.kind == "ketu_imitate_trinket" and eff.trinket_id then
		if item_hud_fx.is_trinket_blocked_by_us(st, eff.trinket_id) then
			eff.imitate_suppressed = true
		else
			eff.imitate_suppressed = false
			Imitate_item_holder.Evaluate_Imitate_Trinkets(player)
		end
	elseif eff.kind == "rahu_block_item" and eff.item_id then
		local ok, why = item_hud_fx.claim_block_collectible(st, player, eff.item_id, eff.inst_token)
		eff.block_owned = ok == true
		M._fx(eff).fire_cd = 0
		for _, o in pairs(st.effects) do
			if effect_is_live(o) and o.kind == "ketu_imitate_item" and o.item_id == eff.item_id then
				o.imitate_suppressed = true
			end
		end
		Imitate_item_holder.Evaluate_Imitate_Items(player)
		probe("RAHU_BLOCK_ITEM", {id = eff.item_id, owned = eff.block_owned, why = why})
	elseif eff.kind == "rahu_block_trinket" and eff.trinket_id then
		local ok, why = item_hud_fx.claim_block_trinket(st, player, eff.trinket_id, eff.inst_token)
		eff.block_owned = ok == true
		M._fx(eff).fire_cd = 0
		for _, o in pairs(st.effects) do
			if effect_is_live(o) and o.kind == "ketu_imitate_trinket" and o.trinket_id == eff.trinket_id then
				o.imitate_suppressed = true
			end
		end
		Imitate_item_holder.Evaluate_Imitate_Trinkets(player)
		probe("RAHU_BLOCK_TRINKET", {id = eff.trinket_id, owned = eff.block_owned, why = why})
	end

	local flag = cache_flags_for_stat(eff.stat)

	if flag and player then
		require("Qing_Remaster_scripts.others.Unique_holder").request_evaluate_items(player, flag)
	end
end

local function fire_rahu_shot(player, st, geo, node_id, power)
	power = math.max(1, math.min(5, tonumber(power) or 1))
	local enemies = {}
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		local npc = ent:ToNPC()
		if npc and npc:IsVulnerableEnemy() and not npc:IsDead()
			and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			enemies[#enemies + 1] = npc
		end
	end
	if #enemies == 0 then
		-- No memory queue: miss this tick rather than fire later when enemies appear.
		probe("SHOT_SKIP_NO_ENEMY", {node = node_id, power = power})
		return
	end
	local origin = celestial_muzzle(player, st, geo)
	local dmg_mult = 0.6 + 0.25 * power
	for i = 1, power do
		local target = enemies[((i - 1) % #enemies) + 1]
		local vel = (target.Position - origin):Normalized() * (8 + i)
		local tear = attack_holder.FireTear(player, origin, vel, {
			mode = "untracked",
			damage_multiplier = dmg_mult,
			can_be_eye = false,
			can_trigger_streak_end = false,
		})
		if tear then
			configure_rahu_tear(tear, vel, RAHU_RANGE_GENERIC)
			tear.Scale = 0.7 + 0.1 * power
			if tear.AddTearFlags then
				tear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
				if node_id == "bombs" then
					tear:AddTearFlags(TearFlags.TEAR_EXPLOSIVE)
				elseif node_id == "keys" then
					tear:AddTearFlags(TearFlags.TEAR_PIERCING)
				end
			end
			tear:GetSprite().Color = Color(0.7, 0.3, 1.0, 1, 0.2, 0, 0.2)
			if node_id == "hearts"
				or (type(node_id) == "string" and string.sub(node_id, 1, 6) == "heart:") then
				tear:GetSprite().Color = Color(1, 0.2, 0.2, 1, 0.3, 0, 0)
			end
		end
	end
	probe("SHOT_FIRED", {node = node_id, power = power, enemies = #enemies})
end

local function rahu_shot_for_open(player, st, geo, eff)
	if not eff or eff.lane ~= "rahu" then return end
	-- Resource / heart / map use continuous tick weapons while occupying.
	if eff.kind == "stat" then
		fire_rahu_shot(player, st, geo, eff.node, 2)
	elseif eff.kind == "deal_cut" then
		fire_rahu_shot(player, st, geo, eff.node, 2)
	end
end

--- Resolve node interval → effect spec (or nil if no gameplay effect).
local function effect_spec_for_node(lane_name, node_id, group, target)
	target = target or {}
	if lane_name == "ketu" then
		if group == "stat" and STAT_DELTAS_KETU[node_id] then
			return {
				kind = "stat",
				stat = node_id,
				delta = STAT_DELTAS_KETU[node_id],
				lane = "ketu",
				node = node_id,
			}
		elseif group == "resource" then
			if node_id == "coins" then
				return {
					kind = "ketu_temp_coins",
					stat = "coins",
					lane = "ketu",
					node = node_id,
				}
			end
			return {
				kind = "resource_infinite",
				stat = node_id,
				lane = "ketu",
				node = node_id,
			}
		elseif group == "hearts" then
			return {
				kind = "invuln",
				stat = "invuln",
				lane = "ketu",
				node = node_id,
			}
		elseif group == "minimap" then
			return {
				kind = "map_reveal",
				stat = "map",
				lane = "ketu",
				node = node_id,
			}
		elseif group == "deal" then
			return {
				kind = "deal_boost",
				stat = node_id,
				delta = 0.10,
				lane = "ketu",
				node = node_id,
			}
		elseif group == "ketu_time" then
			return {
				kind = "ketu_time_acceleration",
				stat = "time",
				lane = "ketu",
				node = node_id,
			}
		elseif group == "active" then
			local slot = tonumber(target.slot)
			if slot == nil then return nil end
			return {
				kind = "ketu_active_charge",
				stat = "active_" .. tostring(slot),
				lane = "ketu",
				node = node_id,
				slot = slot,
				item_id = tonumber(target.item_id) or 0,
			}
		elseif group == "collectible" then
			local id = tonumber(target.item_id) or 0
			if id <= 0 or hud_targets.is_orbit_forbidden_collectible(id) then return nil end
			return {
				kind = "ketu_imitate_item",
				stat = "item_" .. tostring(id),
				lane = "ketu",
				node = node_id,
				item_id = id,
				history_time = target.history_time,
				history_occurrence = target.history_occurrence,
			}
		elseif group == "smelted_trinket" or group == "trinket" then
			local id = tonumber(target.trinket_id or target.item_id) or 0
			if id <= 0 then return nil end
			return {
				kind = "ketu_imitate_trinket",
				stat = "trinket_" .. tostring(id),
				lane = "ketu",
				node = node_id,
				trinket_id = id,
				item_id = id,
				history_time = target.history_time,
				history_occurrence = target.history_occurrence,
				trinket_slot = target.slot,
			}
		end
	elseif lane_name == "rahu" then
		if group == "stat" and STAT_DELTAS_RAHU[node_id] then
			return {
				kind = "stat",
				stat = node_id,
				delta = STAT_DELTAS_RAHU[node_id],
				lane = "rahu",
				node = node_id,
			}
		elseif group == "resource" then
			return {
				kind = "rahu_seal",
				stat = node_id,
				lane = "rahu",
				node = node_id,
			}
		elseif group == "hearts" then
			return {
				kind = "rahu_heart_soft",
				stat = "heart_seal",
				lane = "rahu",
				node = node_id,
			}
		elseif group == "minimap" then
			return {
				kind = "map_shade",
				stat = "map",
				lane = "rahu",
				node = node_id,
			}
		elseif group == "deal" then
			return {
				kind = "deal_cut",
				stat = node_id,
				delta = -0.10,
				lane = "rahu",
				node = node_id,
			}
		elseif group == "active" then
			local slot = tonumber(target.slot)
			if slot == nil then return nil end
			return {
				kind = "rahu_active_drain",
				stat = "active_" .. tostring(slot),
				lane = "rahu",
				node = node_id,
				slot = slot,
				item_id = tonumber(target.item_id) or 0,
			}
		elseif group == "collectible" then
			local id = tonumber(target.item_id) or 0
			if id <= 0 or hud_targets.is_orbit_forbidden_collectible(id) then return nil end
			return {
				kind = "rahu_block_item",
				stat = "item_" .. tostring(id),
				lane = "rahu",
				node = node_id,
				item_id = id,
				history_time = target.history_time,
				history_occurrence = target.history_occurrence,
			}
		elseif group == "smelted_trinket" or group == "trinket" then
			local id = tonumber(target.trinket_id or target.item_id) or 0
			if id <= 0 then return nil end
			return {
				kind = "rahu_block_trinket",
				stat = "trinket_" .. tostring(id),
				lane = "rahu",
				node = node_id,
				trinket_id = id,
				item_id = id,
				history_time = target.history_time,
				history_occurrence = target.history_occurrence,
				trinket_slot = target.slot,
			}
		end
	end
	return nil
end

local function occupy_enter(st, player, geo, spec, token)
	local eff, key = activate_effect(st, player, geo, spec)
	eff.occupying = eff.occupying or {}
	if eff.occupying[token] then
		return
	end
	eff.occupying[token] = true
	local prev = eff.active_count or 0
	eff.active_count = prev + 1
	local first_open = not eff.applied
	probe("OCCUPY_ENTER", {
		key = key,
		kind = eff.kind,
		stat = eff.stat,
		lane = eff.lane,
		node = eff.node,
		token = token,
		active_count = eff.active_count,
		first_open = first_open,
		resumed_tail = (not first_open) and prev == 0,
	})
	-- applied ≠ active_count: tail re-entry must not re-snapshot / re-acquire map refs.
	if first_open then
		apply_first_open(st, player, geo, eff)
		eff.applied = true
		rahu_shot_for_open(player, st, geo, eff)
		probe("EFFECT_OPEN", {
			key = key,
			kind = eff.kind,
			stat = eff.stat,
			lane = eff.lane,
			node = eff.node,
		})
	elseif prev == 0 then
		-- Continue drops the overlay and the engine-side holds. Re-enter must
		-- acquire again; a tail resume still has map_held and must not double it.
		if (eff.kind == "map_reveal" or eff.kind == "map_shade") and not eff.map_held then
			map_overlay_acquire(eff.kind == "map_reveal" and "reveal" or "shade")
			eff.map_held = true
		end
		probe("EFFECT_RESUME", {
			key = key,
			kind = eff.kind,
			stat = eff.stat,
			lane = eff.lane,
			node = eff.node,
		})
	end
end

local function schedule_or_teardown(st, player, key, eff)
	if (eff.active_count or 0) > 0 then
		return
	end
	-- Time acceleration must drop BrokenWatch immediately (no TAIL_FRAMES linger).
	local allow_tail = TAIL_FRAMES > 0 and eff.kind ~= "ketu_time_acceleration"
	if allow_tail then
		eff.release_at = Game():GetFrameCount() + TAIL_FRAMES
		-- Keep cache / invuln / deal live during tail via effect_is_live.
		local flag = cache_flags_for_stat(eff.stat)
		if flag and player then
			require("Qing_Remaster_scripts.others.Unique_holder").request_evaluate_items(player, flag)
		end
		probe("EFFECT_TAIL", {
			key = key,
			kind = eff.kind,
			release_at = eff.release_at,
		})
	else
		local flag = cache_flags_for_stat(eff.stat)
		teardown_effect(st, player, eff)
		st.effects[key] = nil
		if flag and player then
			require("Qing_Remaster_scripts.others.Unique_holder").request_evaluate_items(player, flag)
		end
		probe("EFFECT_CLOSE", {key = key, kind = eff.kind, stat = eff.stat})
	end
end

local function occupy_exit(st, player, key, token)
	local eff = st.effects[key]
	if not eff or eff._torn then return end
	eff.occupying = eff.occupying or {}
	if not eff.occupying[token] then return end
	eff.occupying[token] = nil
	eff.active_count = math.max(0, (eff.active_count or 0) - 1)
	probe("OCCUPY_EXIT", {
		key = key,
		kind = eff.kind,
		stat = eff.stat,
		lane = eff.lane,
		token = token,
		active_count = eff.active_count,
	})
	schedule_or_teardown(st, player, key, eff)
end

local function flush_tails(st, player)
	local now = Game():GetFrameCount()
	local flags = 0
	local to_drop = {}
	for key, eff in pairs(st.effects) do
		if eff and not eff._torn and (eff.active_count or 0) <= 0
			and type(eff.release_at) == "number" and eff.release_at <= now then
			local f = cache_flags_for_stat(eff.stat)
			if f then flags = bit_or(flags, f) end
			teardown_effect(st, player, eff)
			to_drop[#to_drop + 1] = key
			probe("EFFECT_CLOSE", {key = key, kind = eff.kind, stat = eff.stat, via = "tail"})
		end
	end
	for i = 1, #to_drop do
		st.effects[to_drop[i]] = nil
	end
	if flags ~= 0 and player then
		require("Qing_Remaster_scripts.others.Unique_holder").request_evaluate_items(player, flags)
	end
end

local function clear_all_effects(st, player)
	local flags = 0
	for key, eff in pairs(st.effects) do
		local f = cache_flags_for_stat(eff.stat)
		if f then flags = bit_or(flags, f) end
		teardown_effect(st, player, eff)
		st.effects[key] = nil
	end
	if flags ~= 0 and player then
		require("Qing_Remaster_scripts.others.Unique_holder").request_evaluate_items(player, flags)
	end
end

local function has_effect(st, kind, stat)
	for _, eff in pairs(st.effects) do
		if effect_is_live(eff) and eff.kind == kind and (stat == nil or eff.stat == stat) then
			return true, eff
		end
	end
	return false, nil
end

local function sum_stat_delta(st, stat)
	local sum = 0
	for _, eff in pairs(st.effects) do
		if effect_is_live(eff) and eff.stat == stat and type(eff.delta) == "number" then
			sum = sum + eff.delta
		end
	end
	return sum
end

local function desired_add(desired, spec, token)
	if not spec or not token then return end
	local key = effect_key(spec.kind, spec.stat, spec.lane)
	local bucket = desired[key]
	if not bucket then
		bucket = {spec = spec, tokens = {}}
		desired[key] = bucket
	end
	bucket.tokens[token] = true
end

--- Build desired occupancy from endpoint positions + in-frame sweep enters.
--- Sweep keeps full crossings visible for one sync even if endpoint is outside.
local function collect_desired_occupancy(st, geo, has_k, has_r, motion)
	local desired = {}
	motion = motion or {}

	local function add_endpoint(lane_name, s, length, intervals, token)
		local it = orbit.interval_at(intervals, s, length)
		if not it then return end
		desired_add(desired, effect_spec_for_node(lane_name, it.id, it.group, it.target), token)
	end

	local function add_sweeps(lane_name, from_s, to_s, length, intervals, reverse, token)
		if from_s == nil or to_s == nil or not intervals or not length then return end
		local hits = orbit.query_crossings(intervals, from_s, to_s, length, reverse)
		for i = 1, #hits do
			local h = hits[i]
			desired_add(desired, effect_spec_for_node(lane_name, h.id, h.group, h.interval and h.interval.target), token)
		end
	end

	if has_k and geo.intervals_inner then
		local token = "ketu:main"
		add_endpoint("ketu", st.ketu_s, geo.len_inner, geo.intervals_inner, token)
		add_sweeps(
			"ketu", motion.ketu_from, motion.ketu_to,
			geo.len_inner, geo.intervals_inner, false, token
		)
		for i = 1, #st.companions do
			local c = st.companions[i]
			if c.lane == "ketu" then
				local s = companion_logical_s(st, c, st.ketu_s, geo.len_inner)
				if s ~= nil then
					local tok = "ketu:comp:" .. companion_token(c)
					add_endpoint("ketu", s, geo.len_inner, geo.intervals_inner, tok)
				end
			end
		end
	end
	if has_r and geo.intervals_outer then
		local token = "rahu:main"
		add_endpoint("rahu", st.rahu_s, geo.len_outer, geo.intervals_outer, token)
		add_sweeps(
			"rahu", motion.rahu_from, motion.rahu_to,
			geo.len_outer, geo.intervals_outer, true, token
		)
		for i = 1, #st.companions do
			local c = st.companions[i]
			if c.lane == "rahu" then
				local s = companion_logical_s(st, c, st.rahu_s, geo.len_outer)
				if s ~= nil then
					local tok = "rahu:comp:" .. companion_token(c)
					add_endpoint("rahu", s, geo.len_outer, geo.intervals_outer, tok)
				end
			end
		end
	end
	return desired
end

local function sync_occupancy(player, st, geo, has_k, has_r, motion)
	local desired = collect_desired_occupancy(st, geo, has_k, has_r, motion)

	-- Exits first for tokens no longer present.
	for key, eff in pairs(st.effects) do
		if eff and not eff._torn then
			local want = desired[key]
			local want_tokens = want and want.tokens or {}
			local occupying = eff.occupying or {}
			local leave = {}
			for tok, _ in pairs(occupying) do
				if not want_tokens[tok] then
					leave[#leave + 1] = tok
				end
			end
			for i = 1, #leave do
				occupy_exit(st, player, key, leave[i])
			end
		end
	end

	-- Enters for new tokens / new keys.
	for key, bucket in pairs(desired) do
		for tok, _ in pairs(bucket.tokens) do
			occupy_enter(st, player, geo, bucket.spec, tok)
		end
	end
end

local function frac_dist(a, b)
	local d = math.abs(a - b)
	if d > 0.5 then d = 1 - d end
	return d
end

local function try_conjunction(player, st)
	if not (holds(player, ketu_id()) and holds(player, rahu_id())) then
		st.conjunction_armed = true
		return
	end
	local geo = _geo[player_key(player)]
	local li = (geo and geo.len_inner) or 1
	local lo = (geo and geo.len_outer) or 1
	local ki = orbit.mod_distance(st.ketu_s, li) / li
	local ro = orbit.mod_distance(st.rahu_s, lo) / lo
	local near = frac_dist(ki, ro) < CONJ_FRAC
	if near and st.conjunction_armed then
		st.conjunction_armed = false
		local rng = ensure_rng(st, player)
		local moved = 0
		local meet = ki
		local geo_now = _geo[player_key(player)]
		for i = 1, #st.companions do
			local c = st.companions[i]
			local main_s = c.lane == "ketu" and st.ketu_s or st.rahu_s
			local len = c.lane == "ketu" and li or lo
			local cs_abs = companion_logical_s(st, c, main_s, len)
			if cs_abs ~= nil then
				local cs = orbit.mod_distance(cs_abs, len) / len
				if frac_dist(cs, meet) <= CONJ_COMP_FRAC then
					local roll = rng:RandomFloat()
					st.rng_seed = rng:GetSeed()
					local new_lane = roll < 0.5 and "ketu" or "rahu"
					if c.lane ~= new_lane then
						local from_screen = nil
						if geo_now and geo_now.track then
							local lane = c.lane == "ketu" and orbit.LANE_INNER or orbit.LANE_OUTER
							from_screen = orbit.position_at(geo_now.track, cs_abs, lane)
						end
						c.transition = {
							active = true,
							start_frame = Game():GetFrameCount(),
							duration = COMP_TRANSFER_FRAMES,
							from_lane = c.lane,
							to_lane = new_lane,
							from_screen = from_screen and {X = from_screen.X, Y = from_screen.Y} or nil,
						}
						c.lane = new_lane
						c.follow_index = nil -- reassigned on recount
						moved = moved + 1
					end
				end
			end
		end
		recount_zodiac(player, st)
		probe("CONJUNCTION", {moved = moved, ketu_frac = ki, rahu_frac = ro})
	elseif not near then
		st.conjunction_armed = true
	end
end

do
	CTime.TIME_VMIN = 0.20
	CTime.TARGET_RATE = 1.4
	CTime.MEASURE_FRAMES = 15

	function CTime.is_ketu_time(it)
		if not it then
			return false
		end
		if it.group == "ketu_time" then
			return true
		end
		local t = it.target
		return t and t.group == "ketu_time"
	end

	local function set_broken_watch_safe(state)
		local room = Game() and Game():GetRoom()
		if room and room.SetBrokenWatchState then
			room:SetBrokenWatchState(state)
		end
	end

	local function count_live_time_occupiers()
		local n = 0
		local root = state_root()
		for _, st in pairs(root.players or {}) do
			if type(st) == "table" and type(st.effects) == "table" then
				for _, eff in pairs(st.effects) do
					if eff and not eff._torn
						and eff.kind == "ketu_time_acceleration"
						and (eff.active_count or 0) > 0 then
						n = n + 1
					end
				end
			end
		end
		return n
	end

	local function begin_time_accel_session()
		local ta = M._time_accel
		ta.active = true
		ta.frac = 0
		ta.measure_game0 = Game():GetFrameCount()
		ta.measure_time0 = tonumber(Game().TimeCounter) or 0
		ta.measured_rate = nil
		set_broken_watch_safe(2)
		probe("TIME_ACCEL_ON", {watch = 2})
	end

	local function end_time_accel_session()
		local ta = M._time_accel
		if not ta.active then
			set_broken_watch_safe(0)
			return
		end
		ta.active = false
		ta.frac = 0
		ta.measure_game0 = nil
		ta.measure_time0 = nil
		ta.measured_rate = nil
		set_broken_watch_safe(0)
		probe("TIME_ACCEL_OFF", {watch = 0, extra_frames = ta.extra_frames or 0})
	end

	function CTime.refresh()
		local want = count_live_time_occupiers() > 0
		local ta = M._time_accel
		if want and not ta.active then
			begin_time_accel_session()
		elseif (not want) and ta.active then
			end_time_accel_session()
		elseif want and ta.active then
			local room = Game():GetRoom()
			if room and room.GetBrokenWatchState and room:GetBrokenWatchState() ~= 2 then
				set_broken_watch_safe(2)
			end
		end
	end

	local function gameplay_time_may_advance()
		local game = Game()
		if not game then
			return false
		end
		if game.IsPaused and game:IsPaused() then
			return false
		end
		if g.is_gameplay_world_active and not g.is_gameplay_world_active() then
			return false
		end
		local room = game:GetRoom()
		if not room or (room.GetFrameCount and room:GetFrameCount() < 0) then
			return false
		end
		return true
	end

	function CTime.tick()
		local ta = M._time_accel
		if not ta.active then
			return
		end
		local gf = Game():GetFrameCount()
		if ta.tick_game_frame == gf then
			return
		end
		ta.tick_game_frame = gf
		if not gameplay_time_may_advance() then
			return
		end
		if ta.measured_rate == nil and ta.measure_game0 ~= nil then
			local dg = gf - (ta.measure_game0 or gf)
			if dg >= CTime.MEASURE_FRAMES then
				local dt = (tonumber(Game().TimeCounter) or 0) - (ta.measure_time0 or 0)
				if dg > 0 then
					ta.measured_rate = dt / dg
				else
					ta.measured_rate = 1
				end
				probe("TIME_ACCEL_MEASURED", {rate = ta.measured_rate, dg = dg, dt = dt})
			end
		end
		local native = tonumber(ta.measured_rate)
		if native == nil then
			native = 1
		end
		if native < 0.25 then
			native = 0.25
		elseif native > 3 then
			native = 3
		end
		local extra = CTime.TARGET_RATE - native
		if extra <= 1e-6 then
			return
		end
		ta.frac = (ta.frac or 0) + extra
		local whole = math.floor(ta.frac)
		if whole <= 0 then
			return
		end
		ta.frac = ta.frac - whole
		local th = CTime.Time_holder
		if not th then
			th = require("Qing_Remaster_scripts.others.Time_holder")
			CTime.Time_holder = th
		end
		if th.advance_time then
			th.advance_time(whole)
		end
		ta.extra_frames = (ta.extra_frames or 0) + whole
	end

	function CTime.force_clear()
		end_time_accel_session()
	end

	function CTime.append_intervals(track, intervals_inner, len_inner)
		if not track or not intervals_inner or not len_inner then
			return intervals_inner
		end
		local rb, re, length = orbit.top_straight_range(track, orbit.LANE_INNER)
		length = length or len_inner
		orbit.append_gap_intervals(intervals_inner, length, rb, re, function(begin_s, end_s, index)
			local id = "ketu_time:" .. tostring(index)
			local mid = begin_s + (end_s - begin_s) * 0.5
			local anchor = orbit.position_at(track, mid, orbit.LANE_INNER)
			return {
				id = id,
				group = "ketu_time",
				center_s = mid,
				begin_s = begin_s,
				end_s = end_s,
				target = {
					id = id,
					group = "ketu_time",
					visible = true,
					anchor = anchor,
				},
			}
		end)
		return intervals_inner
	end
end

local function rebuild_geometry(player, pkey)
	local ss = ui.GetScreenSize()
	local prev = _geo[pkey]
	local track
	if prev and prev.track and prev.screen
		and ss and prev.screen.X == ss.X and prev.screen.Y == ss.Y then
		track = prev.track
	else
		track = orbit.build_track()
	end
	local targets = hud_targets.snapshot(player)
	local intervals_inner, len_inner = orbit.build_intervals(
		track, orbit.LANE_INNER, targets, orbit.node_radius_frac
	)
	local intervals_outer, len_outer = orbit.build_intervals(
		track, orbit.LANE_OUTER, targets, orbit.node_radius_frac
	)
	-- Seija (or probe force): fill unused top-inner leftovers as ketu_time only.
	if M.ketu_seija_active(player) then
		intervals_inner = CTime.append_intervals(track, intervals_inner, len_inner)
	end
	_geo[pkey] = {
		track = track,
		targets = targets,
		intervals_inner = intervals_inner,
		intervals_outer = intervals_outer,
		len_inner = len_inner,
		len_outer = len_outer,
		screen = ss and Vector(ss.X, ss.Y) or nil,
		ketu_time_enabled = M.ketu_seija_active(player) == true,
	}
	return _geo[pkey]
end

local function occupancy_debug_rows(st)
	local rows = {}
	for key, eff in pairs(st.effects or {}) do
		if eff and not eff._torn then
			local tokens = {}
			for tok, _ in pairs(eff.occupying or {}) do
				tokens[#tokens + 1] = tok
			end
			table.sort(tokens)
			rows[#rows + 1] = {
				key = key,
				kind = eff.kind,
				stat = eff.stat,
				lane = eff.lane,
				active_count = eff.active_count or 0,
				applied = eff.applied == true,
				live = effect_is_live(eff),
				tokens = tokens,
				release_at = eff.release_at,
			}
		end
	end
	table.sort(rows, function(a, b) return tostring(a.key) < tostring(b.key) end)
	return rows
end

function M.set_node_hover_enabled(enabled)
	NODE_HOVER_ENABLED = enabled ~= false
end

function M.is_node_hover_enabled()
	return NODE_HOVER_ENABLED
end

-- Probe-only orbit pause / progress scrub / Seija force / time accel live on M.

function M.set_orbit_paused(enabled)
	M._orbit_paused = enabled == true
end

function M.is_orbit_paused()
	return M._orbit_paused == true
end

function M.set_force_seija(enabled)
	local on = enabled == true
	M._force_seija = on
	-- Rebuild so TIME leftovers appear/disappear immediately for scrubbing.
	if Game and Game() then
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			local pk = player_key(p)
			if pk then
				rebuild_geometry(p, pk)
			end
		end
	end
	if not on then
		-- Drop watch until next PEFFECT occupancy recount if no live time effects remain.
		CTime.refresh()
	end
end

function M.is_force_seija()
	return M._force_seija == true
end

function M.ketu_seija_active(player)
	if M._force_seija then
		return true
	end
	return player and auxi.should_do_Seija(player) == true
end

function M.get_time_accel_debug()
	local ta = M._time_accel
	local room = Game() and Game():GetRoom()
	return {
		active = ta.active == true,
		force_seija = M._force_seija == true,
		extra_frames = ta.extra_frames or 0,
		measured_rate = ta.measured_rate,
		broken_watch = room and room.GetBrokenWatchState and room:GetBrokenWatchState() or nil,
	}
end

--- Set lane arc progress as fraction of track length in [0,1]. Probe scrubbing.
--- Auto-pauses orbit so PEFFECT cannot fight reverse / bidirectional drag.
function M.set_lane_progress_frac(player, lane_name, frac)
	local pkey = player_key(player)
	if not pkey then return end
	local has_k = holds(player, ketu_id())
	local has_r = holds(player, rahu_id())
	if lane_name == "ketu" and not has_k then return end
	if lane_name == "rahu" and not has_r then return end
	local geo = _geo[pkey]
	if not geo or not geo.track then
		geo = rebuild_geometry(player, pkey)
	end
	if not geo or not geo.track then return end
	local st = player_state(pkey)
	frac = tonumber(frac) or 0
	-- Floor-wrap into [0,1). Avoid `frac % 1` alone: some Lua paths leave
	-- negative remainders ambiguous at the 0 edge; math.floor is unambiguous
	-- (e.g. -0.05 → 0.95, 1.05 → 0.05).
	frac = frac - math.floor(frac)
	M._orbit_paused = true
	local motion = {}
	if lane_name == "ketu" then
		local len = math.max(1, geo.len_inner or 1)
		local s = orbit.mod_distance(frac * len, len)
		motion.ketu_from = st.ketu_s
		st.ketu_s = s
		motion.ketu_to = s
		local _, km = lane_speed_mult(st, "ketu", s, geo.intervals_inner, len, true)
		local view = M._view(st)
		view.ketu_phase = km.phase
		view.ketu_local_u = km.local_u
		view.ketu_target_node = km.last_node
	elseif lane_name == "rahu" then
		local len = math.max(1, geo.len_outer or 1)
		local s = orbit.mod_distance(frac * len, len)
		motion.rahu_from = st.rahu_s
		st.rahu_s = s
		motion.rahu_to = s
		local _, rm = lane_speed_mult(st, "rahu", s, geo.intervals_outer, len, false)
		local view = M._view(st)
		view.rahu_phase = rm.phase
		view.rahu_local_u = rm.local_u
		view.rahu_target_node = rm.last_node
	else
		return
	end
	if has_k and motion.ketu_from == nil then
		motion.ketu_from = st.ketu_s
		motion.ketu_to = st.ketu_s
	end
	if has_r and motion.rahu_from == nil then
		motion.rahu_from = st.rahu_s
		motion.rahu_to = st.rahu_s
	end
	sync_occupancy(player, st, geo, has_k, has_r, motion)
	CTime.refresh()
	probe("PROBE_SET_PROGRESS", {lane = lane_name, frac = frac})
end

function M.get_lane_progress_frac(player, lane_name)
	local pkey = player_key(player)
	if not pkey then return 0 end
	local st = player_state(pkey)
	local geo = _geo[pkey]
	if not geo then return 0 end
	if lane_name == "ketu" then
		local len = math.max(1, geo.len_inner or 1)
		return orbit.mod_distance(st.ketu_s or 0, len) / len
	end
	if lane_name == "rahu" then
		local len = math.max(1, geo.len_outer or 1)
		return orbit.mod_distance(st.rahu_s or 0, len) / len
	end
	return 0
end

function M.nudge_lane_progress_frac(player, lane_name, delta)
	local cur = M.get_lane_progress_frac(player, lane_name)
	-- set_lane_progress_frac wraps + auto-pauses (reverse ±5% works).
	M.set_lane_progress_frac(player, lane_name, cur + (tonumber(delta) or 0))
end

--- Session-only Map Formation debug (Cell X/Y + overlays). Not saved.
function M.get_map_formation_debug()
	return {
		cell_x = get_map_cell_x(),
		cell_y = get_map_cell_y(),
		show_anchors = map_formation_dbg.show_anchors == true,
		show_sprite_bounds = map_formation_dbg.show_sprite_bounds == true,
		show_logical_cells = map_formation_dbg.show_logical_cells == true,
		show_sprite_pivot = map_formation_dbg.show_sprite_pivot == true,
		default_x = MAP_CELL_W_DEFAULT,
		default_y = MAP_CELL_H_DEFAULT,
		min = MAP_CELL_DBG_MIN,
		max = MAP_CELL_DBG_MAX,
		anchor_count = #map_formation_anchors,
		tear_scale = MAP_TEAR_SCALE,
		-- GoodTrip screen pitch; theoretical world = pitch * world_per_pixel (unmeasured).
		pitch_x = MAP_PITCH_X,
		pitch_y = MAP_PITCH_Y,
	}
end

function M.set_map_cell_x(v)
	map_formation_dbg.cell_x = clamp_map_cell(v, MAP_CELL_W_DEFAULT)
end

function M.set_map_cell_y(v)
	map_formation_dbg.cell_y = clamp_map_cell(v, MAP_CELL_H_DEFAULT)
end

function M.set_map_show_anchors(enabled)
	map_formation_dbg.show_anchors = enabled == true
	if not map_formation_overlay_wanted() then
		map_formation_anchors = {}
	end
end

function M.set_map_show_sprite_bounds(enabled)
	map_formation_dbg.show_sprite_bounds = enabled == true
	if not map_formation_overlay_wanted() then
		map_formation_anchors = {}
	end
end

function M.set_map_show_logical_cells(enabled)
	map_formation_dbg.show_logical_cells = enabled == true
	if not map_formation_overlay_wanted() then
		map_formation_anchors = {}
	end
end

function M.set_map_show_sprite_pivot(enabled)
	map_formation_dbg.show_sprite_pivot = enabled == true
	if not map_formation_overlay_wanted() then
		map_formation_anchors = {}
	end
end

function M.reset_map_formation_debug()
	map_formation_dbg.cell_x = MAP_CELL_W_DEFAULT
	map_formation_dbg.cell_y = MAP_CELL_H_DEFAULT
	-- Keep overlay toggles; Reset only restores spacing defaults (11/11).
end

--- Debug: fire one full map volley immediately (does not require live map_shade CD).
--- Prefers snapshot from an active map_shade effect; else collects current floor layout.
--- No enemy ⇒ still fires using facing / rightward dir so geometry can be audited in-room.
function M.debug_fire_map_volley(player)
	player = player or Isaac.GetPlayer(0)
	if not player then
		return {ok = false, reason = "no_player", fired = 0}
	end
	local pkey = player_key(player)
	if not pkey then
		return {ok = false, reason = "no_pkey", fired = 0}
	end
	local st = player_state(pkey)
	local geo = (_geo and _geo[pkey]) or {}
	local origin, dir, target = aim_from_star(player, st, geo)
	if not dir then
		origin = origin or player.Position
		local shoot = player.GetShootingInput and player:GetShootingInput() or nil
		if shoot and shoot:LengthSquared() > 0.01 then
			dir = shoot:Normalized()
		else
			local move = player.GetMovementVector and player:GetMovementVector() or nil
			if move and move:LengthSquared() > 0.01 then
				dir = move:Normalized()
			else
				dir = Vector(1, 0)
			end
		end
	end
	local layout = nil
	for _, eff in pairs(st.effects or {}) do
		if effect_is_live(eff) and eff.kind == "map_shade" then
			local saved = M._fx(eff).map_layout
			if type(saved) == "table" and #saved > 0 then
				layout = saved
				break
			end
		end
	end
	if type(layout) ~= "table" or #layout == 0 then
		layout = collect_floor_room_layout(nil)
	end
	local fired = fire_map_constellation(player, origin, dir, layout)
	return {
		ok = fired > 0,
		fired = fired,
		rooms = #layout,
		had_target = target ~= nil,
		cell_x = get_map_cell_x(),
		cell_y = get_map_cell_y(),
		scale = MAP_TEAR_SCALE,
	}
end

function M.get_debug_snapshot(player)
	local pkey = player_key(player)
	if not pkey then return nil end
	local st = player_state(pkey)
	local geo = _geo[pkey] or {}
	local effects = occupancy_debug_rows(st)
	local seal_rows = {}
	for _, eff in pairs(st.effects or {}) do
		if effect_is_live(eff) and (eff.kind == "rahu_seal" or eff.kind == "rahu_heart_soft") then
			seal_rows[#seal_rows + 1] = {
				kind = eff.kind,
				stat = eff.stat,
				sealed_amount = eff.sealed_amount or eff.amount,
				power_tier = eff.power_tier,
				sealed_soul = eff.sealed_soul,
				sealed_red = eff.sealed_red,
				active_count = eff.active_count,
			}
		end
	end
	local time_dbg = M.get_time_accel_debug and M.get_time_accel_debug() or {}
	local view = M._view(st)
	return {
		ketu_s = st.ketu_s,
		rahu_s = st.rahu_s,
		companions = #st.companions,
		windows = #effects, -- probe compat alias
		effects = effects,
		effect_count = #effects,
		seals = seal_rows,
		ketu_phase = view.ketu_phase,
		rahu_phase = view.rahu_phase,
		ketu_local_u = view.ketu_local_u,
		rahu_local_u = view.rahu_local_u,
		ketu_target_node = view.ketu_target_node,
		rahu_target_node = view.rahu_target_node,
		targets = #(geo.targets or {}),
		intervals_inner = #(geo.intervals_inner or {}),
		intervals_outer = #(geo.intervals_outer or {}),
		len_inner = geo.len_inner,
		len_outer = geo.len_outer,
		ketu_time_enabled = geo.ketu_time_enabled == true,
		force_seija = M._force_seija == true,
		time_accel_active = time_dbg.active == true,
		time_accel_extra_frames = time_dbg.extra_frames or 0,
		broken_watch = time_dbg.broken_watch,
		time_measured_rate = time_dbg.measured_rate,
	}
end

function M.get_frame_geometry(player)
	if player then
		local pkey = player_key(player)
		return pkey and _geo[pkey] or nil
	end
	for _, geo in pairs(_geo) do
		return geo
	end
	return nil
end

--- Force rebuild HUD orbit targets/intervals (probe drag / calibration).
function M.rebuild_geometry_now(player)
	player = player or Isaac.GetPlayer(0)
	local pkey = player_key(player)
	if not pkey then
		return nil
	end
	return rebuild_geometry(player, pkey)
end

--- Logical + render screen positions for probe overlay.
function M.get_render_debug(player)
	local pkey = player_key(player)
	if not pkey then return nil end
	local geo = _geo[pkey]
	local st = player_state(pkey)
	if not geo or not geo.track then return nil end
	local view = M._view(st)
	local frame = Isaac.GetFrameCount()
	local stars = {}
	local function push(lane_name, orbit_lane, s, seed, is_main, hover_u, node_id, phase_name)
		local logical = orbit.position_at(geo.track, s, orbit_lane)
		local tan = orbit.tangent_at(geo.track, s, orbit_lane)
		local nor = orbit.normal_at(geo.track, s, orbit_lane)
		local An = is_main and WOBBLE_MAIN_N or WOBBLE_COMP_N
		local At = is_main and WOBBLE_MAIN_T or WOBBLE_COMP_T
		local freq = (lane_name == "rahu") and 0.055 or 0.038
		local drift = (lane_name == "rahu") and 0.9 or 0.55
		local phase = frame * freq + seed
		local radial = math.sin(phase) * 0.85 + math.sin(phase * 0.37 + 2.1) * 0.15
		local stang = math.sin(phase * drift + 1.1)
		local ox = nor.X * An * radial + tan.X * At * stang
		local oy = nor.Y * An * radial + tan.Y * At * stang
		local hover = node_hover_offset(geo, orbit_lane, s, hover_u, node_id, tan, nor)
		ox = ox + hover.X
		oy = oy + hover.Y
		stars[#stars + 1] = {
			lane = lane_name,
			logical = {X = logical.X, Y = logical.Y},
			render = {X = logical.X + ox, Y = logical.Y + oy},
			main = is_main,
			phase = phase_name or ((lane_name == "ketu") and view.ketu_phase or view.rahu_phase),
			local_u = hover_u,
			node_id = node_id,
		}
	end
	if holds(player, ketu_id()) then
		push("ketu", orbit.LANE_INNER, st.ketu_s, 0.37, true, view.ketu_local_u, view.ketu_target_node, view.ketu_phase)
		for i = 1, #st.companions do
			local c = st.companions[i]
			if c.lane == "ketu" then
				local s = companion_logical_s(st, c, st.ketu_s, geo.len_inner)
				if s ~= nil then
					local local_u, node_id = companion_hover_sample(geo, c, s)
					push(
						"ketu", orbit.LANE_INNER, s,
						1.1 + i * 0.73 + (c.id or 0) * 0.01, false,
						local_u, node_id, local_u and "HOVER" or "CRUISE"
					)
				end
			end
		end
	end
	if holds(player, rahu_id()) then
		push("rahu", orbit.LANE_OUTER, st.rahu_s, 2.11, true, view.rahu_local_u, view.rahu_target_node, view.rahu_phase)
		for i = 1, #st.companions do
			local c = st.companions[i]
			if c.lane == "rahu" then
				local s = companion_logical_s(st, c, st.rahu_s, geo.len_outer)
				if s ~= nil then
					local local_u, node_id = companion_hover_sample(geo, c, s)
					push(
						"rahu", orbit.LANE_OUTER, s,
						3.3 + i * 0.91 + (c.id or 0) * 0.01, false,
						local_u, node_id, local_u and "HOVER" or "CRUISE"
					)
				end
			end
		end
	end
	return {stars = stars, effects = occupancy_debug_rows(st)}
end

deal_chance_holder.register_provider("celestial_stars_deal", function()
	local total = 0
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		local pkey = player_key(p)
		if pkey then
			local st = player_state(pkey)
			for _, eff in pairs(st.effects) do
				if effect_is_live(eff)
					and (eff.kind == "deal_boost" or eff.kind == "deal_cut")
					and (eff.stat == "devil" or eff.stat == "angel") then
					total = total + (tonumber(eff.delta) or 0)
				end
			end
		end
	end
	return total
end)

--- Drop saved occupancy so the first real sync re-enters from the star.
--- Payloads (sealed charge, applied, snapshots) stay. Returns false if a
--- player still has no persistent index and the pass must retry.
local function reapply_after_continue()
	local ready = true
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		local pkey = player_key(player)
		if not pkey then
			ready = false
		else
			local st = player_state(pkey)
			st._continue_engine = true
			for _, eff in pairs(st.effects) do
				if eff and not eff._torn then
					eff.occupying = {}
					eff.active_count = 0
					eff.release_at = nil
					eff.map_held = nil
					M._fx(eff).fire_cd = 0
				end
			end
		end
	end
	return ready
end

local function drop_map_effects_on_floor_change()
	invalidate_map_overlay("new_level")
	local root = state_root()
	for _, st in pairs(root.players or {}) do
		if type(st) == "table" and type(st.effects) == "table" then
			local drop = {}
			for key, eff in pairs(st.effects) do
				if eff and (eff.kind == "map_reveal" or eff.kind == "map_shade") then
					eff._torn = true
					drop[#drop + 1] = key
				end
			end
			for i = 1, #drop do
				st.effects[drop[i]] = nil
			end
		end
	end
end

local function render_wobble_offset(lane_name, seed, is_main, tan, nor)
	local frame = Isaac.GetFrameCount()
	local An = is_main and WOBBLE_MAIN_N or WOBBLE_COMP_N
	local At = is_main and WOBBLE_MAIN_T or WOBBLE_COMP_T
	-- Slow continuous drift; Rahu slightly sharper tangent drag.
	local freq = (lane_name == "rahu") and 0.055 or 0.038
	local drift = (lane_name == "rahu") and 0.9 or 0.55
	local phase = frame * freq + seed
	local sn = math.sin(phase)
	local sn2 = math.sin(phase * 0.37 + 2.1)
	local stang = math.sin(phase * drift + 1.1)
	local radial = sn * 0.85 + sn2 * 0.15
	return Vector(
		nor.X * An * radial + tan.X * At * stang,
		nor.Y * An * radial + tan.Y * At * stang
	)
end

-- Re-lock static RoomShapeN each tear tick so vanilla tear anim cannot replace the icon.
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_TEAR_UPDATE,
	params = nil,
	Function = function(_, tear)
		if not tear then return end
		local shape = tear:GetData()[M.own_key .. "rahu_room"]
		if shape == nil then return end
		apply_rahu_map_sprite(tear, shape)
	end,
})

-- Formation overlays from birth snapshot (debug only; no per-frame floor walk).
-- HUD layer so markers stay above HUD chrome.
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		if not map_formation_overlay_wanted() then return end
		local n = #map_formation_anchors
		if n == 0 then return end
		local show_a = map_formation_dbg.show_anchors == true
		local show_b = map_formation_dbg.show_sprite_bounds == true
		local show_c = map_formation_dbg.show_logical_cells == true
		local show_p = map_formation_dbg.show_sprite_pivot == true
		for i = 1, n do
			local a = map_formation_anchors[i]
			if a then
				local pivot = Isaac.WorldToScreen(Vector(a.x, a.y))
				local sx, sy = pivot.X, pivot.Y
				local cx = tonumber(a.cell_x) or MAP_CELL_W_DEFAULT
				local cy = tonumber(a.cell_y) or MAP_CELL_H_DEFAULT
				local scale = tonumber(a.scale) or MAP_TEAR_SCALE
				if show_a or show_p then
					Isaac.RenderText("+", sx - 3, sy - 5, 1, 0.35, 1, 0.95)
				end
				if show_a then
					Isaac.RenderText(tostring(a.shape or "?"), sx + 5, sy - 6, 1, 1, 1, 0.85)
				end
				if show_c then
					local mask = a.mask or map_shape_mask(a.shape)
					for my = 1, #mask do
						local row = mask[my]
						for mx = 1, #row do
							if row[mx] == 1 then
								local wx = a.x + (mx - 1) * cx
								local wy = a.y + (my - 1) * cy
								local tl = Isaac.WorldToScreen(Vector(wx, wy))
								local br = Isaac.WorldToScreen(Vector(wx + cx, wy + cy))
								Isaac.RenderText(".", tl.X, tl.Y, 0.25, 0.85, 1, 0.7)
								Isaac.RenderText(".", br.X - 2, br.Y - 2, 0.25, 0.85, 1, 0.45)
							end
						end
					end
				end
				if show_b then
					-- Body AABB from pivot using measured px → world via cell/source ratio + Scale.
					local ox = (tonumber(a.body_ox) or 2) * (cx / MAP_SRC_CELL_W) * scale
					local oy = (tonumber(a.body_oy) or 2) * (cy / MAP_SRC_CELL_H) * scale
					local bw = (tonumber(a.body_w) or 9) * (cx / MAP_SRC_CELL_W) * scale
					local bh = (tonumber(a.body_h) or 8) * (cy / MAP_SRC_CELL_H) * scale
					local tl = Isaac.WorldToScreen(Vector(a.x + ox, a.y + oy))
					local br = Isaac.WorldToScreen(Vector(a.x + ox + bw, a.y + oy + bh))
					Isaac.RenderText("[", tl.X - 2, tl.Y - 4, 1, 0.7, 0.2, 0.85)
					Isaac.RenderText("]", br.X - 2, br.Y - 4, 1, 0.7, 0.2, 0.85)
				end
			end
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function(_, is_continued)
		if not is_continued then
			save.elses[M.own_key .. "run"] = nil
		else
			-- Level and __Index may be unready here. Zero stale map refs so
			-- NEW_ROOM does not re-apply a dead shade/reveal; the first
			-- gameplay update re-enters effects and rebuilds the overlay.
			M._continue_rebind = true
			local ov = get_map_overlay()
			if ov then
				ov.reveal_refs = 0
				ov.shade_refs = 0
			end
		end
		_geo = {}
	end,
})

table.insert(M.myToCall, #M.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function()
		drop_map_effects_on_floor_change()
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		-- Room-local BrokenWatch must not leak across rooms.
		CTime.force_clear()
		local ov = get_map_overlay()
		if ov and ov.floor_key == floor_key()
			and ((ov.reveal_refs or 0) > 0 or (ov.shade_refs or 0) > 0) then
			apply_map_flags_from_overlay()
		elseif ov and ov.floor_key ~= floor_key() then
			set_map_overlay(nil)
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function()
		CTime.force_clear()
		M._force_seija = false
		local ta = M._time_accel
		ta.extra_frames = 0
		ta.tick_game_frame = -1
	end,
})

table.insert(M.myToCall, #M.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function()
		CTime.force_clear()
		M._force_seija = false
		local ta = M._time_accel
		ta.extra_frames = 0
		ta.tick_game_frame = -1
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_EVALUATE_CACHE,
	params = nil,
	Function = function(_, player, flag)
		local pkey = player_key(player)
		if not pkey then return end
		local st = player_state(pkey)
		if next(st.effects) == nil then return end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + sum_stat_delta(st, "damage")
		elseif flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + sum_stat_delta(st, "speed")
		elseif flag == CacheFlag.CACHE_FIREDELAY then
			local d = sum_stat_delta(st, "tears")
			if d ~= 0 then
				player.MaxFireDelay = math.max(1, player.MaxFireDelay - d * 1.5)
			end
		elseif flag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + sum_stat_delta(st, "range") * 40
		elseif flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + sum_stat_delta(st, "shotspeed")
		elseif flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + sum_stat_delta(st, "luck")
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = EntityType.ENTITY_PLAYER,
	Function = function(_, ent, _, _, _, _)
		local player = ent and ent:ToPlayer()
		local pkey = player_key(player)
		if not pkey then return end
		local st = player_state(pkey)
		if has_effect(st, "invuln") then
			return false
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PEFFECT_UPDATE,
	params = nil,
	Function = function(_, player)
		if not g.is_gameplay_world_active or not g.is_gameplay_world_active() then
			return
		end
		local pkey = player_key(player)
		if not pkey then return end
		local has_k = holds(player, ketu_id())
		local has_r = holds(player, rahu_id())
		local st = player_state(pkey)

		if M._continue_rebind then
			if reapply_after_continue() then
				M._continue_rebind = false
			end
		end

		flush_tails(st, player)

		if not (has_k or has_r) then
			if M._continue_rebind then
				return
			end
			st._continue_engine = nil
			if next(st.effects) ~= nil then
				clear_all_effects(st, player)
			end
			if #st.companions > 0 then
				st.companions = {}
			end
			CTime.refresh()
			return
		end

		recount_zodiac(player, st)
		local geo = rebuild_geometry(player, pkey)

		local dt = 1 / 30
		local motion = {}
		local paused = M._orbit_paused == true
		if has_k then
			motion.ketu_from = st.ketu_s
			if paused then
				motion.ketu_to = st.ketu_s
			else
				local k_mult = select(1, lane_speed_mult(
					st, "ketu", st.ketu_s, geo.intervals_inner, geo.len_inner, true
				))
				motion.ketu_to = select(1, orbit.advance(
					geo.track, orbit.LANE_INNER, motion.ketu_from, dt * k_mult, geo.intervals_inner, true
				))
				st.ketu_s = motion.ketu_to
			end
			-- Refresh hover sample at post-advance s so companions/render match occupancy.
			local _, k_motion = lane_speed_mult(
				st, "ketu", st.ketu_s, geo.intervals_inner, geo.len_inner, true
			)
			local view = M._view(st)
			view.ketu_phase = k_motion.phase
			view.ketu_local_u = k_motion.local_u
			view.ketu_target_node = k_motion.last_node
		end
		if has_r then
			motion.rahu_from = st.rahu_s
			if paused then
				motion.rahu_to = st.rahu_s
			else
				local r_mult = select(1, lane_speed_mult(
					st, "rahu", st.rahu_s, geo.intervals_outer, geo.len_outer, false
				))
				motion.rahu_to = select(1, orbit.advance(
					geo.track, orbit.LANE_OUTER, motion.rahu_from, dt * r_mult, geo.intervals_outer, false
				))
				st.rahu_s = motion.rahu_to
			end
			local _, r_motion = lane_speed_mult(
				st, "rahu", st.rahu_s, geo.intervals_outer, geo.len_outer, false
			)
			local view = M._view(st)
			view.rahu_phase = r_motion.phase
			view.rahu_local_u = r_motion.local_u
			view.rahu_target_node = r_motion.last_node
		end
		-- Finish companion cross-lane transitions.
		local now_f = Game():GetFrameCount()
		for i = 1, #st.companions do
			local c = st.companions[i]
			local tr = c.transition
			if tr and tr.active then
				if now_f - (tr.start_frame or 0) >= (tr.duration or COMP_TRANSFER_FRAMES) then
					c.transition = nil
				end
			end
		end

		-- Endpoint occupancy + in-frame sweep enters (logical_s only).
		sync_occupancy(player, st, geo, has_k, has_r, motion)
		flush_tails(st, player)
		if st._continue_engine then
			st._continue_engine = nil
			local need_item, need_trinket = false, false
			for _, eff in pairs(st.effects) do
				if eff and eff.applied and not eff._torn then
					if eff.kind == "resource_infinite" and eff.stat
						and type(eff.snapshot) == "number" then
						set_resource(player, eff.stat, get_resource_max(player, eff.stat))
					elseif eff.kind == "ketu_active_charge" and eff.slot ~= nil then
						local rem = math.max(0, math.floor(tonumber(eff.charge_remaining) or 0))
						if rem > 0 then
							local _, bat = item_hud_fx.read_charges(player, eff.slot)
							if rem > bat then
								item_hud_fx.grant_temp_charge(player, eff.slot, rem - bat)
							end
						end
					elseif eff.kind == "rahu_block_item" and eff.block_owned and eff.item_id
						and player.BlockCollectible
						and not (player.IsCollectibleBlocked and player:IsCollectibleBlocked(eff.item_id)) then
						player:BlockCollectible(eff.item_id)
					elseif eff.kind == "rahu_block_trinket" and eff.block_owned and eff.trinket_id
						and player.BlockTrinket
						and not (player.IsTrinketBlocked and player:IsTrinketBlocked(eff.trinket_id)) then
						player:BlockTrinket(eff.trinket_id)
					elseif eff.kind == "ketu_imitate_item" and not eff.imitate_suppressed then
						need_item = true
					elseif eff.kind == "ketu_imitate_trinket" and not eff.imitate_suppressed then
						need_trinket = true
					end
				end
			end
			if need_item then
				Imitate_item_holder.Evaluate_Imitate_Items(player)
			end
			if need_trinket then
				Imitate_item_holder.Evaluate_Imitate_Trinkets(player)
			end
			sync_map_overlay_from_effects()
			probe("CONTINUE_REBIND", {player = pkey})
		end
		CTime.refresh()
		CTime.tick()
		if has_r then
			tick_rahu_weapons(player, st, geo)
		end

		if has_k and has_r then
			try_conjunction(player, st)
		end

		tick_map_shade_progress()
	end,
})

if ModCallbacks.MC_POST_PLANETARIUM_CALCULATE then
	table.insert(M.ToCall, #M.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PLANETARIUM_CALCULATE,
		params = nil,
		Function = function(_, chance)
			local add = 0
			for i = 0, Game():GetNumPlayers() - 1 do
				local p = Game():GetPlayer(i)
				local pkey = player_key(p)
				if pkey then
					local st = player_state(pkey)
					for _, eff in pairs(st.effects) do
						if effect_is_live(eff) and eff.stat == "planetarium" then
							add = add + (tonumber(eff.delta) or 0)
						end
					end
				end
			end
			return chance + add
		end,
	})
end

-- Stars / companions are HUD-orbit visuals; draw after HUD so they are not covered.
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		if not g.is_gameplay_world_active or not g.is_gameplay_world_active() then
			return
		end
		local room = Game():GetRoom()
		if not room or room:GetFrameCount() < 0 then return end
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			local pkey = player_key(player)
			local has_k = pkey and holds(player, ketu_id())
			local has_r = pkey and holds(player, rahu_id())
			if pkey and (has_k or has_r) then
				local geo = _geo[pkey]
				if not geo or not geo.track then
					geo = rebuild_geometry(player, pkey)
				end
				local st = player_state(pkey)
				local function draw_star(lane_name, orbit_lane, s, anim, seed, is_main, hover_u, node_id)
					local logical = orbit.position_at(geo.track, s, orbit_lane)
					local tan = orbit.tangent_at(geo.track, s, orbit_lane)
					local nor = orbit.normal_at(geo.track, s, orbit_lane)
					local off = render_wobble_offset(lane_name, seed, is_main, tan, nor)
					local hover = node_hover_offset(geo, orbit_lane, s, hover_u, node_id, tan, nor)
					local pos = Vector(logical.X + off.X + hover.X, logical.Y + off.Y + hover.Y)
					local spr = get_sprite(anim)
					spr.Color = Color(1, 1, 1, 1)
					-- Soft pulse near node center (render-only).
					local pulse = 1
					if is_main and type(hover_u) == "number" then
						local E = math.sin(math.pi * hover_u)
						E = E * E
						pulse = 1 + HOVER_PULSE * E * math.sin(Isaac.GetFrameCount() * 0.18 + seed)
					end
					spr.Scale = Vector(pulse, pulse)
					spr:Render(pos, Vector.Zero, Vector.Zero)
				end
				local function draw_companion_icon(comp, lane_name, pos, alpha)
					local anim = zodiac_anim_name(lane_name, comp.id)
					local spr = get_zodiac_sprite(anim)
					if not spr then return end
					spr.Color = Color(1, 1, 1, math.max(0, math.min(1, alpha or 1)))
					spr.Scale = Vector(COMP_ICON_SCALE, COMP_ICON_SCALE)
					spr:Render(pos, Vector.Zero, Vector.Zero)
				end
				local function draw_companion(comp, index)
					local tr = comp.transition
					local lane_name = comp.lane
					local orbit_lane = lane_name == "ketu" and orbit.LANE_INNER or orbit.LANE_OUTER
					local main_s = lane_name == "ketu" and st.ketu_s or st.rahu_s
					local length = lane_name == "ketu" and geo.len_inner or geo.len_outer
					local seed = 1.1 + index * 0.73 + (comp.id or 0) * 0.01
					if tr and tr.active and tr.from_screen then
						-- Same 30Hz clock as the transition lifetime. Isaac.GetFrameCount()
						-- is ~60Hz and made this progress clamp to 1 on the first draw.
						local duration = math.max(2, tr.duration or COMP_TRANSFER_FRAMES)
						local age = Game():GetFrameCount() - (tr.start_frame or 0)
						local u = math.max(0, math.min(1, age / duration))
						local function smooth(x)
							x = math.max(0, math.min(1, x))
							return x * x * (3 - 2 * x)
						end
						if u < 0.5 then
							local from_lane = tr.from_lane or lane_name
							local pos = Vector(tr.from_screen.X, tr.from_screen.Y)
							draw_companion_icon(comp, from_lane, pos, 1 - smooth(u / 0.5))
						else
							local to_name = tr.to_lane or lane_name
							local probe_c = {
								lane = to_name,
								follow_index = comp.follow_index,
								token = comp.token,
								id = comp.id,
								transition = nil,
							}
							local to_len = (to_name == "ketu") and geo.len_inner or geo.len_outer
							local to_main = (to_name == "ketu") and st.ketu_s or st.rahu_s
							local s_now = companion_logical_s(st, probe_c, to_main, to_len) or to_main
							local to_lane = (to_name == "ketu") and orbit.LANE_INNER or orbit.LANE_OUTER
							local logical = orbit.position_at(geo.track, s_now, to_lane)
							local tan = orbit.tangent_at(geo.track, s_now, to_lane)
							local nor = orbit.normal_at(geo.track, s_now, to_lane)
							local off = render_wobble_offset(to_name, seed, false, tan, nor)
							local local_u, node_id = companion_hover_sample(geo, probe_c, s_now)
							local hover = node_hover_offset(geo, to_lane, s_now, local_u, node_id, tan, nor)
							local pos = Vector(logical.X + off.X + hover.X, logical.Y + off.Y + hover.Y)
							draw_companion_icon(comp, to_name, pos, smooth((u - 0.5) / 0.5))
						end
						return
					end
					local s = companion_logical_s(st, comp, main_s, length)
					if s == nil then return end
					local local_u, node_id = companion_hover_sample(geo, comp, s)
					local logical = orbit.position_at(geo.track, s, orbit_lane)
					local tan = orbit.tangent_at(geo.track, s, orbit_lane)
					local nor = orbit.normal_at(geo.track, s, orbit_lane)
					local off = render_wobble_offset(lane_name, seed, false, tan, nor)
					local hover = node_hover_offset(geo, orbit_lane, s, local_u, node_id, tan, nor)
					local pos = Vector(logical.X + off.X + hover.X, logical.Y + off.Y + hover.Y)
					draw_companion_icon(comp, lane_name, pos, 1)
				end
				local view = M._view(st)
				if has_k then
					draw_star(
						"ketu", orbit.LANE_INNER, st.ketu_s, "Ketu", 0.37, true,
						view.ketu_local_u, view.ketu_target_node
					)
				end
				if has_r then
					draw_star(
						"rahu", orbit.LANE_OUTER, st.rahu_s, "Rahu", 2.11, true,
						view.rahu_local_u, view.rahu_target_node
					)
				end
				for c = 1, #st.companions do
					local comp = st.companions[c]
					if (comp.lane == "ketu" and has_k) or (comp.lane == "rahu" and has_r) then
						draw_companion(comp, c)
					end
				end
			end
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_BOMB_UPDATE,
	params = BombVariant.BOMB_THROWABLE,
	Function = function(_, bomb)
		local data = bomb and bomb:GetData() and bomb:GetData()[M.own_key .. "rahu_bomb"]
		if type(data) ~= "table" or data.exploded then return end
		if not bomb:IsDead() and (bomb.FrameCount or 0) < (RAHU_BOMB_FUSE - 1) then
			return
		end
		data.exploded = true
		local player
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and GetPtrHash(p) == data.owner_hash then
				player = p
				break
			end
		end
		apply_rahu_bomb_blast(bomb.Position, player or bomb.SpawnerEntity)
	end,
})

-- Ketu invuln: gold heart HUD overlay (does not change real heart storage).
if REPENTOGON and ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS then
	local gold_heart_sprite = Sprite()
	gold_heart_sprite:Load("gfx/ui/ui_hearts.anm2", true)

	local function get_heart_row_max(hud)
		if hud and hud.GetLayout then
			local layout = hud:GetLayout()
			if layout == 2 or layout == 3 then return 3 end
		end
		return 6
	end

	local function get_heart_pos(index, scale, rowmax)
		scale = scale or 1
		rowmax = rowmax or 6
		local row = math.floor((index - 1) / rowmax)
		local column = (index - 1) - row * rowmax
		return Vector(column * 12 * scale, row * 10 * scale)
	end

	table.insert(M.ToCall, #M.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS,
		params = nil,
		Function = function(_, offset, heartsSprite, position, spriteScale, player)
			if player == nil then return end
			if not auxi.can_render_health_hud or not auxi.can_render_health_hud() then return end
			local pkey = player_key(player)
			if not pkey then return end
			local st = player_state(pkey)
			if not has_effect(st, "invuln") then return end

			local hud = player.GetPlayerHUD and player:GetPlayerHUD() or nil
			local hearts = hud and hud.GetHearts and hud:GetHearts() or nil
			local rowmax = get_heart_row_max(hud)
			local scale = 1
			if heartsSprite and heartsSprite.Scale then
				scale = heartsSprite.Scale.X
			elseif spriteScale then
				scale = spriteScale
			end

			-- Prefer the heart slot matching current red+soul fill (last visible).
			local target_index = 1
			if hearts then
				for i, heart in ipairs(hearts) do
					if heart:IsVisible() then
						target_index = i
					end
				end
			else
				target_index = math.max(1, math.ceil(((player:GetMaxHearts() or 2) + (player:GetSoulHearts() or 0)) / 2))
			end

			local pos
			if position then
				pos = position + get_heart_pos(target_index, scale, rowmax)
			elseif ui.UIHeartPos then
				local order = 1
				if auxi.GetPlayerOrder then
					order = auxi.GetPlayerOrder(player) or 1
				end
				pos = ui.UIHeartPos(target_index - 1, order, nil, {anchor = ui.HUD_ANCHOR and ui.HUD_ANCHOR.CENTER})
			else
				return
			end

			local alpha = 0.55 + 0.35 * (0.5 + 0.5 * math.sin(Isaac.GetFrameCount() * 0.15))
			gold_heart_sprite.Color = Color(1.15, 0.95, 0.45, alpha, 0.25, 0.15, 0)
			gold_heart_sprite.Scale = Vector(scale, scale)
			gold_heart_sprite:SetFrame("GoldHeartOverlay", 0)
			gold_heart_sprite:Render(pos, Vector.Zero, Vector.Zero)
		end,
	})
end

local function eid_is_zh()
	local lang = auxi.get_EID_language and auxi.get_EID_language() or ""
	return lang == "zh" or lang == "zh_cn" or lang == "zh_tw"
end

local function any_player_holds_zodiac()
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p then
			for z = 1, #ZODIAC do
				if p:GetCollectibleNum(ZODIAC[z]) > 0 then
					return true
				end
			end
		end
	end
	return false
end

local function any_player_holds_both_stars()
	local kid, rid = ketu_id(), rahu_id()
	if kid <= 0 or rid <= 0 then return false end
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if holds(p, kid) and holds(p, rid) then
			return true
		end
	end
	return false
end

local function register_celestial_eid()
	if M._eid_registered or not EID or not EID.addDescriptionModifier then
		return
	end
	M._eid_registered = true

	local function is_collectible(desc, item_id)
		return desc
			and desc.ObjType == 5
			and desc.ObjVariant == 100
			and item_id
			and item_id > 0
			and desc.ObjSubType == item_id
	end

	EID:addDescriptionModifier("qing_celestial_ketu_dyn", function(desc)
		if not is_collectible(desc, ketu_id()) then return false end
		return any_player_holds_zodiac() or any_player_holds_both_stars()
	end, function(desc)
		local zh = eid_is_zh()
		local both = any_player_holds_both_stars()
		if any_player_holds_zodiac() then
			if both then
				EID:appendToDescription(desc, zh
					and "#持有的十二星座道具会化为伴星，跟随主星运行"
					or "#Held Zodiac items appear as companion stars trailing the main stars")
			else
				EID:appendToDescription(desc, zh
					and "#持有的十二星座道具会化为伴星，跟随计都星运行"
					or "#Held Zodiac items appear as companion stars trailing Ketu")
			end
		end
		if both then
			EID:appendToDescription(desc, zh
				and "#双星交汇时，附近的伴星可能改变归属"
				or "#When both stars meet, nearby companions may switch orbits")
		end
		return desc
	end)

	EID:addDescriptionModifier("qing_celestial_rahu_dyn", function(desc)
		if not is_collectible(desc, rahu_id()) then return false end
		return any_player_holds_zodiac() or any_player_holds_both_stars()
	end, function(desc)
		local zh = eid_is_zh()
		local both = any_player_holds_both_stars()
		if any_player_holds_zodiac() then
			if both then
				EID:appendToDescription(desc, zh
					and "#持有的十二星座道具会化为伴星，跟随主星运行"
					or "#Held Zodiac items appear as companion stars trailing the main stars")
			else
				EID:appendToDescription(desc, zh
					and "#持有的十二星座道具会化为伴星，跟随星辰运行"
					or "#Held Zodiac items appear as companion stars trailing Rahu")
			end
		end
		if both then
			EID:appendToDescription(desc, zh
				and "#双星交汇时，附近的伴星可能改变归属"
				or "#When both stars meet, nearby companions may switch orbits")
		end
		return desc
	end)
end

register_celestial_eid()

-- Ketu temporary imitate (passives / trinkets). Rahu block suppresses via imitate_suppressed.
-- display=false: gold History mark replaces temp Extra HUD panel for these grants.
table.insert(M.myToCall, #M.myToCall + 1, {
	CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM,
	params = nil,
	Function = function(_, player, _colid, value)
		local pkey = player_key(player)
		if not pkey then return value end
		local st = player_state(pkey)
		for _, eff in pairs(st.effects) do
			if effect_is_live(eff) and eff.kind == "ketu_imitate_item" and eff.item_id
				and not eff.imitate_suppressed then
				Imitate_item_holder.add(value, eff.item_id, 1, {display = false, costume = true})
			end
		end
		return value
	end,
})

table.insert(M.myToCall, #M.myToCall + 1, {
	CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_TRINKET,
	params = nil,
	Function = function(_, player, _tid, value)
		local pkey = player_key(player)
		if not pkey then return value end
		local st = player_state(pkey)
		for _, eff in pairs(st.effects) do
			if effect_is_live(eff) and eff.kind == "ketu_imitate_trinket" and eff.trinket_id
				and not eff.imitate_suppressed then
				Imitate_item_holder.add(value, eff.trinket_id, 1, {display = false, costume = false})
			end
		end
		return value
	end,
})

-- No temp Extra HUD icons: amplified items are marked gold on History / trinket slot.
temp_item_hud.register_provider(function(_player)
	return nil
end, {
	source_item = ketu_id(),
	exclusive = true,
})

require("Qing_Remaster_scripts.items.celestial.hud_tint").register(M, {
	player_key = player_key,
	player_state = player_state,
	effect_is_live = effect_is_live,
})

-- Charge / coin spend: deduct Ketu temp ledgers first so leave-reclaim stays accurate.
table.insert(M.myToCall, #M.myToCall + 1, {
	CallBack = enums.Callbacks.POST_PLAYER_LOSS,
	params = nil,
	Function = function(_, player, info)
		if not info then return end
		local pkey = player_key(player)
		if not pkey then return end
		local st = player_state(pkey)
		local spent = math.max(0, tonumber(info.amount) or 0)
		if spent <= 0 then return end

		if info.kind == "charge" then
			local slot = info.active_slot
			if slot == nil then return end
			for _, eff in pairs(st.effects) do
				if effect_is_live(eff) and eff.kind == "ketu_active_charge" and eff.slot == slot then
					local take = math.min(spent, tonumber(eff.charge_remaining) or 0)
					eff.charge_remaining = (tonumber(eff.charge_remaining) or 0) - take
					spent = spent - take
					probe("KETU_ACTIVE_SPEND", {slot = slot, take = take, rem = eff.charge_remaining})
					if spent <= 0 then break end
				end
			end
			return
		end

		if info.kind == "coin" then
			for _, eff in pairs(st.effects) do
				if effect_is_live(eff) and eff.kind == "ketu_temp_coins" then
					local rem = math.max(0, tonumber(eff.coin_remaining) or 0)
					local take = math.min(spent, rem)
					eff.coin_remaining = rem - take
					spent = spent - take
					probe("KETU_COIN_SPEND", {take = take, rem = eff.coin_remaining})
					if spent <= 0 then break end
				end
			end
		end
	end,
})

return M

-- Golden Compass Boss@89 layout pick (vanilla RoomConfig + StageAPI extension pool).
-- Vanilla: confident 1x1 LR RoomConfig. StageAPI: GetBaseFloorInfo non-BaseGameBoss with
-- formal layout filter (1x1+LR doors, RequireRoomType=false). Bind via GenerateBossRoom later.
-- Horseman-only / OnlyReplaceSubtype / unsupported_shape excluded from free pick.
-- Mother Corpse II / Dad's Note prep remain hard endpoints (not StageAPI-replaced).

local catalog = require("Qing_Remaster_scripts.items.golden_compass.boss_pool_catalog")
local audit = require("Qing_Remaster_scripts.items.golden_compass.boss_pool_audit")
local encounter = require("Qing_Remaster_scripts.items.golden_compass.boss_encounter")
local compass_rng = require("Qing_Remaster_scripts.items.golden_compass.rng")

local M = {}

local SHAPE_1X1 = RoomShape.ROOMSHAPE_1x1
local CONFIDENT = {
	["subtype+spawn"] = true,
	["subtype+spawn_disambiguated"] = true,
}

local function room_config_holder()
	return rawget(_G, "RoomConfig") or rawget(_G, "RoomConfigHolder")
end

local function get_cfg(stb, room_type, variant)
	local holder = room_config_holder()
	if not holder or not holder.GetRoomByStageTypeAndVariant or stb == nil or variant == nil then
		return nil
	end
	local cfg = nil
	pcall(function()
		cfg = holder.GetRoomByStageTypeAndVariant(stb, room_type, variant, 0)
	end)
	if not cfg then
		pcall(function()
			cfg = holder.GetRoomByStageTypeAndVariant(stb, room_type, variant, -1)
		end)
	end
	return cfg
end

local function make_rng(root_seed, sgid, domain)
	local rng, seed, err = compass_rng.make_rng(root_seed, domain or "boss_pick", sgid or 89, 0)
	if not rng then
		return nil, nil, err
	end
	return rng, seed, nil
end

local function has_required_doors(doors, required)
	required = tonumber(required) or 0
	if required == 0 then
		return true
	end
	return ((tonumber(doors) or 0) & required) == required
end

local function weight_pick(rng, items, weight_key)
	weight_key = weight_key or "weight"
	local total = 0
	for i = 1, #items do
		total = total + (tonumber(items[i][weight_key]) or 0)
	end
	if total <= 0 or not rng then
		return items[#items]
	end
	local roll = 0
	if rng.RandomFloat then
		roll = rng:RandomFloat() * total
	elseif rng.Next then
		roll = (rng:Next() % 1000000) / 1000000 * total
	end
	local acc = 0
	for i = 1, #items do
		acc = acc + (tonumber(items[i][weight_key]) or 0)
		if roll <= acc then
			return items[i]
		end
	end
	return items[#items]
end

local function row_from_cfg(cfg, source_stb, via, extra)
	local row = {
		cfg = cfg,
		room_type = cfg and cfg.Type or RoomType.ROOM_BOSS,
		variant = cfg and cfg.Variant,
		shape = cfg and cfg.Shape,
		doors = cfg and cfg.Doors,
		subtype = cfg and cfg.Subtype,
		difficulty = cfg and cfg.Difficulty,
		name = cfg and cfg.Name,
		spawn_count = cfg and cfg.SpawnCount,
		source_stb = source_stb,
		via = via,
		fallback = false,
		kind = "boss",
		pool = "boss",
	}
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			row[k] = v
		end
	end
	return row
end

--- True when the engine will turn Mom@89 into Dad's Note (photo-door prep floor).
function M.is_backwards_path_init()
	local on = false
	pcall(function()
		if GameStateFlag and GameStateFlag.STATE_BACKWARDS_PATH_INIT and Game then
			on = Game():GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT) == true
		end
	end)
	return on
end

--- Mausoleum II / Gehenna II + BACKWARDS_PATH_INIT → stage STB Boss Variant 1 (Subtype 89 "Mom").
--- Not SPECIAL_ROOMS/6030 (normal Mom fight). Do not clear the backwards flag; engine owns Note spawn.
--- Does not mark boss encounters.
function M.pick_dads_note_prep(stage, stage_type, required_doors)
	stage = tonumber(stage)
	stage_type = tonumber(stage_type)
	if stage ~= LevelStage.STAGE3_2 then
		return nil, "not_stage3_2"
	end
	local st_rep = StageType and StageType.STAGETYPE_REPENTANCE
	local st_rep_b = StageType and StageType.STAGETYPE_REPENTANCE_B
	if stage_type ~= st_rep and stage_type ~= st_rep_b then
		return nil, "not_mausoleum_gehenna_ii"
	end
	if not M.is_backwards_path_init() then
		return nil, "no_backwards_path_init"
	end
	local stb = catalog.stage_to_stb(stage, stage_type)
	if stb == nil then
		return nil, "stage_stb_missing"
	end
	local variant = 1
	local expect_subtype = (BossType and BossType.MOM_MAUSOLEUM) or 89
	local cfg = get_cfg(stb, RoomType.ROOM_BOSS, variant)
	if not cfg then
		return nil, "stage_boss_variant_1_missing"
	end
	if tonumber(cfg.Subtype) ~= tonumber(expect_subtype) then
		return nil, "subtype_mismatch:" .. tostring(cfg.Subtype)
	end
	if not has_required_doors(cfg.Doors, required_doors) then
		return nil, "doors_mismatch"
	end
	return row_from_cfg(cfg, stb, "dads_note_prep_stage_variant_1", {
		boss_id = "Mom",
		boss_role = "dads_note_prep",
		pool = "dads_note_prep",
		boss_encounter_pending = false,
		required_variant = variant,
		required_subtype = expect_subtype,
	}), nil
end

--- Corpse II Mother gate at 89 (SPECIAL_ROOMS / 6000).
function M.pick_mother_gate(required_doors)
	local plan = catalog.MOTHER_CORPSE_II and catalog.MOTHER_CORPSE_II.entry_89
	if not plan then
		return nil, "mother_plan_missing"
	end
	local cfg = get_cfg(plan.source_stb, RoomType.ROOM_BOSS, plan.variant)
	if not cfg then
		return nil, "mother_gate_6000_missing"
	end
	if not has_required_doors(cfg.Doors, required_doors) then
		return nil, "mother_gate_doors_mismatch"
	end
	return row_from_cfg(cfg, plan.source_stb, "mother_gate_special_6000", {
		boss_id = "Mother",
		boss_role = "mother_gate",
		pool = "mother_gate",
	}), nil
end

--- Void Delirium at 89 (SPECIAL_ROOMS / 3414, shape 2x2).
--- Door check uses LEFT0 only: RIGHT neighbor is the 2x2 footprint (deal@90 suppressed).
function M.pick_delirium_void(required_doors)
	local plan = catalog.DELIRIUM_VOID and catalog.DELIRIUM_VOID.boss_89
	if not plan then
		return nil, "delirium_plan_missing"
	end
	local cfg = get_cfg(plan.source_stb, RoomType.ROOM_BOSS, plan.variant)
	if not cfg then
		return nil, "delirium_3414_missing"
	end
	local expect_subtype = tonumber(plan.expect_subtype) or 70
	if tonumber(cfg.Subtype) ~= expect_subtype then
		return nil, "delirium_subtype_mismatch:" .. tostring(cfg.Subtype)
	end
	-- Corridor only needs LEFT connection from 88; ignore full LR mask for 2x2 endpoint.
	local left_mask = (1 << DoorSlot.LEFT0)
	local need = left_mask
	if tonumber(required_doors) and (tonumber(required_doors) & left_mask) == left_mask then
		need = left_mask
	elseif tonumber(required_doors) and tonumber(required_doors) ~= 0 then
		need = tonumber(required_doors)
	end
	if not has_required_doors(cfg.Doors, need) then
		return nil, "delirium_doors_mismatch"
	end
	local expect_shape = tonumber(plan.shape) or ((RoomShape and RoomShape.ROOMSHAPE_2x2) or 8)
	if tonumber(cfg.Shape) ~= expect_shape then
		return nil, "delirium_shape_mismatch:" .. tostring(cfg.Shape)
	end
	return row_from_cfg(cfg, plan.source_stb, "delirium_void_special_3414", {
		boss_id = plan.boss_id or "Delirium",
		boss_role = "delirium",
		pool = "delirium_void",
		required_variant = plan.variant,
		required_subtype = expect_subtype,
		suppress_deal_90 = true,
		shape_2x2 = true,
	}), nil
end

--- Corpse II Mother arena at -10 (CORPSE / Variant 1, Shape 1x2).
function M.pick_mother_arena()
	local plan = catalog.MOTHER_CORPSE_II and catalog.MOTHER_CORPSE_II.arena_neg10
	if not plan then
		return nil, "mother_plan_missing"
	end
	local cfg = get_cfg(plan.source_stb, RoomType.ROOM_BOSS, plan.variant)
	if not cfg then
		return nil, "mother_arena_corpse_1_missing"
	end
	local expect_subtype = 88
	for st, id in pairs(catalog.BOSS_TYPE_TO_ID or {}) do
		if catalog.canonical_boss_id(id) == "Mother" then
			expect_subtype = st
			break
		end
	end
	local row = row_from_cfg(cfg, plan.source_stb, "mother_arena_corpse_1", {
		kind = "mother_arena",
		pool = "mother_arena",
		exit_kind = "mother_arena",
		boss_id = plan.boss_id or "Mother",
		required_variant = plan.variant,
		required_subtype = expect_subtype,
		selected_variant = cfg.Variant,
		selected_subtype = cfg.Subtype,
		skipped = false,
	})
	if tonumber(cfg.Subtype) ~= expect_subtype then
		row.subtype_note = "subtype_mismatch_kept"
	end
	return row, nil
end

function M.is_mother_arena_cfg(cfg_or_snap)
	if type(cfg_or_snap) ~= "table" then
		return false
	end
	local plan = catalog.MOTHER_CORPSE_II and catalog.MOTHER_CORPSE_II.arena_neg10
	local variant = tonumber(cfg_or_snap.Variant or cfg_or_snap.variant)
	local subtype = tonumber(cfg_or_snap.Subtype or cfg_or_snap.subtype)
	local room_type = tonumber(cfg_or_snap.Type or cfg_or_snap.type)
	local shape = tonumber(cfg_or_snap.Shape or cfg_or_snap.shape)
	if variant == 666 or room_type == (RoomType and RoomType.ROOM_DUNGEON) then
		return false
	end
	if plan and variant == tonumber(plan.variant) and room_type == RoomType.ROOM_BOSS then
		return true
	end
	if room_type == RoomType.ROOM_BOSS and catalog.boss_id_from_subtype(subtype) == "Mother" then
		if shape and shape ~= SHAPE_1X1 then
			return true
		end
	end
	return false
end

local function collect_confident_layouts(stage, stage_type, required_doors)
	local stb = catalog.stage_to_stb(stage, stage_type)
	local entity_index = catalog.build_entity_index()
	local stage_layouts = audit.enumerate_boss_layouts(stb, {
		source = "stage",
		entity_index = entity_index,
		require_1x1 = true,
	})
	local special_layouts = audit.enumerate_boss_layouts(StbType.SPECIAL_ROOMS, {
		source = "special_rooms",
		entity_index = entity_index,
		require_1x1 = true,
	})
	local seen = {}
	local by_boss = {}
	local function add(lay)
		if not lay or not lay.boss_id then
			return
		end
		local mk = lay.match and lay.match.match_kind
		if not CONFIDENT[mk] then
			return
		end
		if not has_required_doors(lay.doors, required_doors) then
			return
		end
		local key = string.format(
			"%s:%s:%s:%s",
			tostring(lay.stb),
			tostring(lay.variant),
			tostring(lay.subtype),
			tostring(lay.doors)
		)
		if seen[key] then
			return
		end
		seen[key] = true
		local id = catalog.canonical_boss_id(lay.boss_id)
		if not id then
			return
		end
		if not by_boss[id] then
			by_boss[id] = {}
		end
		by_boss[id][#by_boss[id] + 1] = lay
	end
	for i = 1, #stage_layouts do
		add(stage_layouts[i])
	end
	for i = 1, #special_layouts do
		add(special_layouts[i])
	end
	return by_boss
end

--- Shell RoomConfig for StageAPI extension Boss@89 (descriptor must be ROOM_BOSS 1x1 + doors).
--- Prefer StageAPI goto data; else any confident vanilla LR layout on this floor.
local function stageapi_shell_cfg(stage, stage_type, required_doors, by_boss)
	local cfg = nil
	pcall(function()
		if StageAPI and StageAPI.GetGotoDataForTypeShape then
			cfg = StageAPI.GetGotoDataForTypeShape(RoomType.ROOM_BOSS, SHAPE_1X1)
		end
	end)
	if cfg and has_required_doors(cfg.Doors, required_doors) then
		return cfg, "stageapi_goto_boss_1x1"
	end
	-- Fallback: first confident vanilla layout with required doors.
	if type(by_boss) == "table" then
		for _, lays in pairs(by_boss) do
			for i = 1, #(lays or {}) do
				local lay = lays[i]
				local c = lay.cfg or get_cfg(lay.stb, RoomType.ROOM_BOSS, lay.variant)
				if c and has_required_doors(c.Doors, required_doors) then
					return c, "vanilla_shell:" .. tostring(lay.boss_id or lay.variant)
				end
			end
		end
	end
	-- Last resort: stage STB first boss room that matches doors.
	local stb = catalog.stage_to_stb(stage, stage_type)
	if stb ~= nil then
		local holder = room_config_holder()
		if holder and holder.GetRoomByStageTypeAndVariant then
			for variant = 0, 40 do
				local c = get_cfg(stb, RoomType.ROOM_BOSS, variant)
				if c
					and tonumber(c.Shape) == tonumber(SHAPE_1X1)
					and has_required_doors(c.Doors, required_doors)
				then
					return c, "stage_stb_shell:" .. tostring(variant)
				end
			end
		end
	end
	return cfg, cfg and "stageapi_goto_doors_weak" or "shell_missing"
end

local function stageapi_condition_ok(boss, entry)
	local ok = true
	pcall(function()
		if boss and type(boss.ConditionFunc) == "function" then
			ok = boss.ConditionFunc() ~= false
		end
	end)
	if not ok then
		return false
	end
	pcall(function()
		if entry and type(entry.ConditionFunc) == "function" then
			ok = entry.ConditionFunc() ~= false
		end
	end)
	return ok
end

--- Collect StageAPI extension Boss candidates for free Boss@89 selection.
--- Returns: candidates[], skipped[{id,reason,valid_lr?,weight?}]
local function collect_stageapi_extension_candidates(stage, stage_type)
	local out = {}
	local skipped = {}
	local function skip_row(id, reason, extra)
		local row = {id = id, reason = reason}
		if type(extra) == "table" then
			for k, v in pairs(extra) do
				row[k] = v
			end
		end
		skipped[#skipped + 1] = row
	end
	if StageAPI == nil or not StageAPI.GetBaseFloorInfo or not StageAPI.GetBossData then
		return out, skipped
	end
	local info = nil
	pcall(function()
		info = StageAPI.GetBaseFloorInfo(stage, stage_type, false)
	end)
	local pool = info and info.Bosses and info.Bosses.Pool
	if type(pool) ~= "table" then
		return out, skipped
	end
	local seen = {}
	for i = 1, #pool do
		local entry = pool[i]
		local boss_id = entry and (entry.BossID or entry.bossID)
		if type(boss_id) == "string" then
			boss_id = catalog.canonical_boss_id(boss_id) or boss_id
			if not seen[boss_id] then
				seen[boss_id] = true
				local boss = nil
				pcall(function()
					boss = StageAPI.GetBossData(boss_id)
				end)
				local weight = tonumber(entry and entry.Weight) or (boss and tonumber(boss.Weight)) or 1
				local reason = nil
				local valid_lr = nil
				if not boss then
					reason = "boss_data_missing"
				elseif boss.BaseGameBoss == true then
					reason = "base_game"
				elseif not boss.Rooms then
					reason = "no_Rooms"
				elseif entry.OnlyReplaceHorsemen or boss.OnlyReplaceHorsemen then
					reason = "only_replace_horsemen"
				elseif entry.OnlyReplaceSubtype ~= nil or boss.OnlyReplaceSubtype ~= nil then
					reason = "only_replace_subtype"
				elseif not stageapi_condition_ok(boss, entry) then
					reason = "condition_func"
				else
					valid_lr = select(1, audit.count_stageapi_valid_lr(boss.Rooms))
					if (tonumber(valid_lr) or 0) <= 0 then
						reason = "no_valid_lr"
					end
				end
				if reason then
					skip_row(boss_id, reason, {weight = weight, valid_lr = valid_lr})
				else
					out[#out + 1] = {
						id = boss_id,
						weight = weight,
						forced = false,
						stageapi_extension = true,
						valid_lr = valid_lr,
						layouts = {{weight = 1, stageapi = true}},
					}
				end
			end
		end
	end
	return out, skipped
end

local function sum_weights(list)
	local n = 0
	for i = 1, #(list or {}) do
		n = n + (tonumber(list[i].weight) or 0)
	end
	return n
end

local function build_pick_pool_summary(opts)
	opts = opts or {}
	local vanilla = opts.vanilla or {}
	local stageapi = opts.stageapi or {}
	local skipped = opts.stageapi_skipped or {}
	local summary = {
		stage = opts.stage,
		stage_type = opts.stage_type,
		vanilla_candidates = #vanilla,
		stageapi_candidates = #stageapi,
		vanilla_weight_total = sum_weights(vanilla),
		stageapi_weight_total = sum_weights(stageapi),
		stageapi_skipped_count = #skipped,
		stageapi_skipped = skipped,
		vanilla_ids = {},
		stageapi_ids = {},
		force_stageapi_boss_id = opts.force_stageapi_boss_id,
		force_stageapi_any = opts.force_stageapi_any == true,
		selected_id = opts.selected_id,
		selected_source = opts.selected_source,
		selected_mode = opts.selected_mode,
		candidate_ok = opts.candidate_ok,
	}
	for i = 1, #vanilla do
		summary.vanilla_ids[#summary.vanilla_ids + 1] = {
			id = vanilla[i].id,
			weight = vanilla[i].weight,
			layouts = vanilla[i].layouts and #vanilla[i].layouts or 0,
		}
	end
	for i = 1, #stageapi do
		summary.stageapi_ids[#summary.stageapi_ids + 1] = {
			id = stageapi[i].id,
			weight = stageapi[i].weight,
			valid_lr = stageapi[i].valid_lr,
		}
	end
	return summary
end

local function remember_pick_summary(summary)
	M._last_pick_summary = summary
	return summary
end

--- Offline / probe: collect current-floor pick pool without rolling RNG.
function M.inspect_pick_pool(stage, stage_type, required_doors)
	stage = tonumber(stage)
	stage_type = tonumber(stage_type)
	required_doors = required_doors or catalog.DOOR_MASK.LR
	local def = catalog.find_floor_def(stage, stage_type)
	if not def then
		return nil, "no_floor_def"
	end
	if def.role_89 == "mother_gate" then
		return remember_pick_summary({
			stage = stage,
			stage_type = stage_type,
			selected_source = "mother_gate",
			note = "hard endpoint; StageAPI extension not used",
		}), nil
	end
	if def.role_89 == "delirium" then
		return remember_pick_summary({
			stage = stage,
			stage_type = stage_type,
			selected_source = "delirium_void",
			note = "hard endpoint SPECIAL_ROOMS/3414; StageAPI extension not used",
		}), nil
	end
	local by_boss = collect_confident_layouts(stage, stage_type, required_doors)
	local vanilla = {}
	local vanilla_ids = {}
	for _, be in ipairs(def.bosses or {}) do
		local id = catalog.canonical_boss_id(be.id)
		if id
			and not catalog.is_unsupported_shape_for_89(id)
			and not be.only_replace_horsemen
			and (tonumber(be.weight) or 0) > 0
		then
			local lays = by_boss[id]
			if lays and #lays > 0 then
				local filtered = lays
				if be.only_replace_subtype ~= nil then
					filtered = {}
					for i = 1, #lays do
						if tonumber(lays[i].subtype) == tonumber(be.only_replace_subtype) then
							filtered[#filtered + 1] = lays[i]
						end
					end
				end
				if #filtered > 0 then
					vanilla_ids[id] = true
					vanilla[#vanilla + 1] = {
						id = id,
						weight = tonumber(be.weight) or 1,
						layouts = filtered,
					}
				end
			end
		end
	end
	local sa_cands, sa_skipped = collect_stageapi_extension_candidates(stage, stage_type)
	local stageapi = {}
	for i = 1, #sa_cands do
		local c = sa_cands[i]
		if c and c.id and not vanilla_ids[c.id] then
			stageapi[#stageapi + 1] = c
		elseif c and c.id and vanilla_ids[c.id] then
			sa_skipped[#sa_skipped + 1] = {
				id = c.id,
				reason = "shadowed_by_vanilla",
				weight = c.weight,
				valid_lr = c.valid_lr,
			}
		end
	end
	return remember_pick_summary(build_pick_pool_summary({
		stage = stage,
		stage_type = stage_type,
		vanilla = vanilla,
		stageapi = stageapi,
		stageapi_skipped = sa_skipped,
		candidate_ok = (#vanilla + #stageapi) > 0,
	})), nil
end

--- Build a forced StageAPI extension candidate (test only; bypasses horseman/subtype filters).
local function make_forced_stageapi_candidate(boss_id)
	if type(boss_id) ~= "string" or boss_id == "" then
		return nil, "bad_boss_id"
	end
	if not (StageAPI and StageAPI.GetBossData) then
		return nil, "stageapi_unavailable"
	end
	local boss = nil
	pcall(function()
		boss = StageAPI.GetBossData(boss_id)
	end)
	if not boss then
		return nil, "boss_data_missing"
	end
	if boss.BaseGameBoss == true then
		return nil, "base_game"
	end
	if not boss.Rooms then
		return nil, "no_Rooms"
	end
	local n, err = audit.count_stageapi_valid_lr(boss.Rooms)
	if (tonumber(n) or 0) <= 0 then
		return nil, "no_valid_lr:" .. tostring(err)
	end
	return {
		id = boss_id,
		weight = tonumber(boss.Weight) or 1,
		forced = true,
		stageapi_extension = true,
		valid_lr = n,
		layouts = {{weight = 1, stageapi = true}},
	}, nil
end

--- Pick Boss@89 from catalog pool. Returns row or nil, err.
function M.pick_boss_room(stage, stage_type, required_doors, root_seed, sgid, opts)
	opts = opts or {}
	stage = tonumber(stage)
	stage_type = tonumber(stage_type)
	-- Dad's Note prep must win over the fixed Mom catalog entry for STAGE3_2 alt floors.
	-- Once BACKWARDS_PATH_INIT + Mausoleum/Gehenna II, never fall through to normal Mom pool.
	do
		local st_rep = StageType and StageType.STAGETYPE_REPENTANCE
		local st_rep_b = StageType and StageType.STAGETYPE_REPENTANCE_B
		local prep_floor = stage == LevelStage.STAGE3_2
			and (stage_type == st_rep or stage_type == st_rep_b)
			and M.is_backwards_path_init()
		local note_row, note_err = M.pick_dads_note_prep(stage, stage_type, required_doors)
		if note_row and note_row.cfg then
			return note_row, nil
		end
		if prep_floor then
			return nil, "dads_note_prep_failed:" .. tostring(note_err or "unknown")
		end
	end
	local def = catalog.find_floor_def(stage, stage_type)
	if not def then
		return nil, "no_floor_def"
	end
	if def.role_89 == "mother_gate" then
		return M.pick_mother_gate(required_doors)
	end
	if def.role_89 == "delirium" then
		return M.pick_delirium_void(required_doors)
	end
	if def.pool_mode == "void_mixed" or #(def.bosses or {}) == 0 then
		return nil, "empty_or_void_pool"
	end

	local by_boss = collect_confident_layouts(stage, stage_type, required_doors)
	local candidates = {}
	local vanilla_list = {}
	local vanilla_ids = {}
	for _, be in ipairs(def.bosses or {}) do
		local id = catalog.canonical_boss_id(be.id)
		if id
			and not catalog.is_unsupported_shape_for_89(id)
			and not be.only_replace_horsemen
			and (tonumber(be.weight) or 0) > 0
		then
			-- OnlyReplaceSubtype: keep as candidate; layout subtype filter below.
			local lays = by_boss[id]
			if lays and #lays > 0 then
				local filtered = lays
				if be.only_replace_subtype ~= nil then
					filtered = {}
					for i = 1, #lays do
						if tonumber(lays[i].subtype) == tonumber(be.only_replace_subtype) then
							filtered[#filtered + 1] = lays[i]
						end
					end
				end
				if #filtered > 0 then
					vanilla_ids[id] = true
					local row = {
						id = id,
						weight = tonumber(be.weight) or 1,
						forced = be.forced == true,
						layouts = filtered,
						only_replace_subtype = be.only_replace_subtype,
						stageapi_extension = false,
					}
					candidates[#candidates + 1] = row
					vanilla_list[#vanilla_list + 1] = row
				end
			end
		end
	end
	-- StageAPI extension bosses (FF etc.): same weight pool / prefer-unencountered path.
	local sa_cands, sa_skipped = collect_stageapi_extension_candidates(stage, stage_type)
	local stageapi_list = {}
	for i = 1, #sa_cands do
		local c = sa_cands[i]
		-- Prefer vanilla RoomConfig path when the same id already has confident layouts.
		if c and c.id and not vanilla_ids[c.id] then
			candidates[#candidates + 1] = c
			stageapi_list[#stageapi_list + 1] = c
		elseif c and c.id and vanilla_ids[c.id] then
			sa_skipped[#sa_skipped + 1] = {
				id = c.id,
				reason = "shadowed_by_vanilla",
				weight = c.weight,
				valid_lr = c.valid_lr,
			}
		end
	end

	local force_id = opts.force_stageapi_boss_id
	local force_any = opts.force_stageapi_any == true
	local force_note = nil
	if type(force_id) == "string" and force_id ~= "" then
		local found = nil
		for i = 1, #stageapi_list do
			if stageapi_list[i].id == force_id then
				found = stageapi_list[i]
				break
			end
		end
		if not found then
			local forced, ferr = make_forced_stageapi_candidate(force_id)
			if forced then
				found = forced
				force_note = "forced_bypass_filters"
			else
				force_note = "force_failed:" .. tostring(ferr)
			end
		else
			force_note = "forced_from_pool"
		end
		if found then
			candidates = {found}
			stageapi_list = {found}
			force_any = true
		end
	elseif force_any then
		if #stageapi_list == 0 then
			force_note = "force_any_empty_pool"
		else
			-- Prefer first pool entry (stable for tests); still one-shot.
			candidates = {stageapi_list[1]}
			force_note = "forced_any:" .. tostring(stageapi_list[1].id)
		end
	end

	local function attach_summary(row, selected_source, selected_mode, selected_id)
		local summary = remember_pick_summary(build_pick_pool_summary({
			stage = stage,
			stage_type = stage_type,
			vanilla = vanilla_list,
			stageapi = stageapi_list,
			stageapi_skipped = sa_skipped,
			force_stageapi_boss_id = force_id,
			force_stageapi_any = force_any or (type(force_id) == "string"),
			selected_id = selected_id or (row and row.boss_id),
			selected_source = selected_source,
			selected_mode = selected_mode,
			candidate_ok = #candidates > 0,
		}))
		summary.force_note = force_note
		if row then
			row.pick_pool_summary = summary
			row.selected_source = selected_source
		end
		return row, summary
	end

	if #candidates == 0 then
		local _, summary = attach_summary(nil, "none", nil, nil)
		return nil, "no_confident_candidates", summary
	end

	local rng, rng_seed = make_rng(root_seed, sgid, "boss_pool_select")
	if not rng then
		attach_summary(nil, "none", nil, nil)
		return nil, "rng_failed"
	end
	local chosen, mode
	if force_any and #candidates == 1 then
		chosen, mode = candidates[1], "forced"
	else
		chosen, mode = encounter.pick_prefer_unencountered(candidates, rng)
	end
	if not chosen then
		attach_summary(nil, "none", tostring(mode), nil)
		return nil, "encounter_pick_failed:" .. tostring(mode)
	end

	-- StageAPI extension: shell RoomConfig now; GenerateBossRoom binds LevelRoom after descriptor write.
	if chosen.stageapi_extension == true then
		local shell, shell_via = stageapi_shell_cfg(stage, stage_type, required_doors, by_boss)
		if not shell then
			attach_summary(nil, "stageapi_extension", mode, chosen.id)
			return nil, "stageapi_shell_missing:" .. tostring(shell_via)
		end
		local source = (force_any or force_id) and "forced_stageapi" or "stageapi_extension"
		local row = row_from_cfg(shell, nil, "stageapi_extension:" .. tostring(shell_via), {
			boss_id = chosen.id,
			stageapi_boss_id = chosen.id,
			stageapi_extension = true,
			boss_pick_mode = mode,
			rng_seed = rng_seed,
			pool = "boss_pool",
			boss_encounter_pending = true,
			candidate_ok = true,
			force_note = force_note,
		})
		attach_summary(row, source, mode, chosen.id)
		return row, nil
	end

	local lay_rng = select(1, make_rng(root_seed, sgid, "boss_layout_select"))
	local lay = weight_pick(lay_rng or rng, chosen.layouts, "weight")
	if not lay or not lay.cfg then
		-- enumerate stores cfg? audit enumerate does NOT keep cfg userdata — only fields.
		-- Need to re-fetch RoomConfig by stb/variant.
		local cfg = get_cfg(lay and lay.stb, RoomType.ROOM_BOSS, lay and lay.variant)
		if not cfg then
			attach_summary(nil, "vanilla", mode, chosen.id)
			return nil, "layout_cfg_missing"
		end
		lay.cfg = cfg
	end
	local cfg = lay.cfg or get_cfg(lay.stb, RoomType.ROOM_BOSS, lay.variant)
	if not cfg then
		attach_summary(nil, "vanilla", mode, chosen.id)
		return nil, "layout_cfg_missing"
	end

	-- Do NOT mark_encountered here: plan/config success ≠ RoomDescriptor@89 bind.
	-- runtime commits after layout_ready + 89 Data matches this row.

	local row = row_from_cfg(cfg, lay.stb, "boss_pool_confident", {
		boss_id = chosen.id,
		boss_pick_mode = mode,
		match_kind = lay.match and lay.match.match_kind,
		layout_source = lay.source,
		rng_seed = rng_seed,
		pool = "boss_pool",
		boss_encounter_pending = true,
		stageapi_extension = false,
		candidate_ok = true,
	})
	attach_summary(row, "vanilla", mode, chosen.id)
	return row, nil
end

function M.get_last_pick_summary()
	return M._last_pick_summary
end

function M.format_pick_pool_summary(summary)
	summary = summary or M._last_pick_summary
	if type(summary) ~= "table" then
		return "boss_pick_pool: no summary"
	end
	local lines = {
		string.format(
			"Boss pick pool stage=%s type=%s vanilla=%s(w=%s) stageapi=%s(w=%s) skipped=%s",
			tostring(summary.stage),
			tostring(summary.stage_type),
			tostring(summary.vanilla_candidates),
			tostring(summary.vanilla_weight_total),
			tostring(summary.stageapi_candidates),
			tostring(summary.stageapi_weight_total),
			tostring(summary.stageapi_skipped_count)
		),
		string.format(
			"selected=%s source=%s mode=%s force_any=%s force_id=%s note=%s",
			tostring(summary.selected_id),
			tostring(summary.selected_source),
			tostring(summary.selected_mode),
			tostring(summary.force_stageapi_any),
			tostring(summary.force_stageapi_boss_id),
			tostring(summary.force_note)
		),
	}
	if #(summary.stageapi_ids or {}) > 0 then
		local bits = {}
		for i = 1, math.min(#summary.stageapi_ids, 12) do
			local c = summary.stageapi_ids[i]
			bits[#bits + 1] = string.format("%s(w=%s,lr=%s)", tostring(c.id), tostring(c.weight), tostring(c.valid_lr))
		end
		lines[#lines + 1] = "stageapi: " .. table.concat(bits, ", ")
		if #summary.stageapi_ids > 12 then
			lines[#lines + 1] = string.format("  ... (+%s)", tostring(#summary.stageapi_ids - 12))
		end
	end
	if #(summary.stageapi_skipped or {}) > 0 then
		local by_reason = {}
		for i = 1, #summary.stageapi_skipped do
			local r = summary.stageapi_skipped[i]
			local key = tostring(r.reason or "?")
			by_reason[key] = (by_reason[key] or 0) + 1
		end
		local bits = {}
		for k, v in pairs(by_reason) do
			bits[#bits + 1] = k .. "=" .. tostring(v)
		end
		table.sort(bits)
		lines[#lines + 1] = "skipped reasons: " .. table.concat(bits, ", ")
	end
	return table.concat(lines, "\n")
end

return M

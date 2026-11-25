-- Golden Compass persistent state (save.elses) + rebuildable cache.
-- Current floor (armed/generating/active/failed) is separate from next_floor appointment.

local save = require("Qing_Remaster_scripts.core.savedata")

local OWN_KEY = "Item_Golden_Compass_corridor"

local M = {}

M.cache = {
	session_note = nil,
	debug_force_root = nil,
	debug_force_boss = nil,
	probe_logging = false,
}

local function elses()
	save.elses = save.elses or {}
	local root = save.elses[OWN_KEY]
	if type(root) ~= "table" then
		root = {phase = "idle"}
		save.elses[OWN_KEY] = root
	end
	if type(root.floor) ~= "table" then
		root.floor = {}
	end
	return root
end

local function clear_current_generation_flags(root)
	root.layout_ready = false
	root.identity_restored = false
	root.negative_ready = false
	root.generation_ok = false
	root.restore_stage = nil
	root.restore_stage_type = nil
	root.force_boss_subtype = nil
	root.fail_reason = nil
	root.floor = {}
	root.boss_89_commit = nil
	root.stageapi_protected = nil
end

function M.OWN_KEY()
	return OWN_KEY
end

function M.get()
	return elses()
end

function M.clear_persist(reason)
	local root = elses()
	for k in pairs(root) do
		root[k] = nil
	end
	root.phase = "idle"
	root.floor = {}
	root.clear_reason = tostring(reason or "clear")
	return true
end

function M.phase()
	local root = elses()
	return (root and root.phase) or "idle"
end

function M.is_armed()
	local p = M.phase()
	return p == "armed" or p == "generating"
end

function M.is_active()
	return M.phase() == "active"
end

function M.is_failed()
	return M.phase() == "failed"
end

function M.has_next_arm()
	local root = elses()
	local n = root.next
	return type(n) == "table" and tonumber(n.root_seed) and tonumber(n.root_seed) > 0
end

local function normalize_compat(meta_compat)
	local c = type(meta_compat) == "table" and meta_compat or {}
	return {
		room84_angel = c.room84_angel == true,
		room84_devil = c.room84_devil == true,
		seija_curses = c.seija_curses == true,
	}
end

--- Virtues / Belial / Seija flags locked at arm time (Continue-safe with appointment).
function M.get_compat()
	local root = elses()
	return normalize_compat(root.compat)
end

function M.get_next_compat()
	local root = elses()
	local n = root.next
	if type(n) ~= "table" then
		return normalize_compat(nil)
	end
	return normalize_compat(n.compat)
end

--- Run generation/door callbacks for current floor work, or while armed/generating.
function M.should_run_callbacks()
	local p = M.phase()
	return p == "armed" or p == "generating" or p == "active"
end

function M.get_root_seed()
	local root = elses()
	local s = root and tonumber(root.root_seed)
	if s and s > 0 then
		return s
	end
	local dbg = tonumber(M.cache.debug_force_root)
	if dbg and dbg > 0 then
		return dbg
	end
	return nil
end

function M.get_next_root_seed()
	local root = elses()
	local n = root.next
	return n and tonumber(n.root_seed) or nil
end

--- Arm / refresh next-floor appointment.
--- idle → armed (current). active → write next only (keep current floor).
--- already armed/generating without consuming: keep existing appointment (no second Next).
function M.arm_next_floor(root_seed, meta)
	meta = meta or {}
	local root = elses()
	root_seed = tonumber(root_seed)
	if not root_seed or root_seed <= 0 then
		return false, "bad_root_seed"
	end

	if root.phase == "armed" or root.phase == "generating" then
		return true, "already_armed"
	end

	if root.phase == "active" then
		if M.has_next_arm() then
			return true, "already_next_armed"
		end
		root.next = {
			root_seed = root_seed,
			target_stage = meta.target_stage,
			target_stage_type = meta.target_stage_type,
			force_boss_subtype = meta.force_boss_subtype,
			compat = normalize_compat(meta.compat),
			armed_game_frame = Game():GetFrameCount(),
		}
		return true, "next_armed"
	end

	-- idle or failed: start a fresh appointment as current armed.
	root.phase = "armed"
	root.root_seed = root_seed
	root.target_stage = meta.target_stage
	root.target_stage_type = meta.target_stage_type
	root.armed_game_frame = Game():GetFrameCount()
	clear_current_generation_flags(root)
	root.force_boss_subtype = meta.force_boss_subtype
	root.compat = normalize_compat(meta.compat)
	root.clear_reason = nil
	return true, "armed"
end

function M.begin_generating(restore_stage, restore_stage_type)
	local root = elses()
	if root.phase ~= "armed" then
		return false
	end
	root.phase = "generating"
	root.restore_stage = restore_stage
	root.restore_stage_type = restore_stage_type
	root.target_stage = root.target_stage or restore_stage
	root.target_stage_type = root.target_stage_type or restore_stage_type
	root.layout_ready = false
	root.identity_restored = false
	root.negative_ready = false
	root.generation_ok = false
	root.fail_reason = nil
	root.floor = {}
	return true
end

function M.mark_layout_ready(ok)
	local root = elses()
	root.layout_ready = ok == true
end

function M.mark_identity_restored(ok)
	local root = elses()
	root.identity_restored = ok == true
end

function M.mark_negative_ready(ok)
	local root = elses()
	root.negative_ready = ok == true
end

function M.mark_generation_complete()
	local root = elses()
	local ok = root.layout_ready == true
		and root.identity_restored == true
		and root.negative_ready == true
	root.generation_ok = ok
	if ok then
		root.phase = "active"
		root.fail_reason = nil
	end
	return ok
end

function M.fail_generation(reason)
	local root = elses()
	root.phase = "failed"
	root.generation_ok = false
	root.fail_reason = tostring(reason or "generation_failed")
	-- Keep next appointment intact.
end

--- End current floor. If next appointment exists, promote it to armed.
function M.end_corridor(reason)
	local root = elses()
	local nxt = root.next
	clear_current_generation_flags(root)
	root.root_seed = nil
	root.target_stage = nil
	root.target_stage_type = nil
	root.clear_reason = tostring(reason or "end")

	if type(nxt) == "table" and tonumber(nxt.root_seed) and tonumber(nxt.root_seed) > 0 then
		root.phase = "armed"
		root.root_seed = tonumber(nxt.root_seed)
		root.target_stage = nxt.target_stage
		root.target_stage_type = nxt.target_stage_type
		root.force_boss_subtype = nxt.force_boss_subtype
		root.compat = normalize_compat(nxt.compat)
		root.armed_game_frame = nxt.armed_game_frame or Game():GetFrameCount()
		root.next = nil
		return "promoted_next"
	end

	root.phase = "idle"
	root.compat = nil
	root.next = nil
	return "idle"
end

function M.set_floor_persist(fields)
	local root = elses()
	if root.phase ~= "active" then
		return
	end
	root.floor = root.floor or {}
	fields = fields or {}
	for k, v in pairs(fields) do
		root.floor[k] = v
	end
end

function M.get_floor_persist()
	local root = elses()
	return root.floor or {}
end

--- Boss@89 encounter arm survives pending=nil after NEW_LEVEL (Continue-safe).
function M.set_boss_89_commit(fields)
	local root = elses()
	if fields == nil then
		root.boss_89_commit = nil
		return
	end
	root.boss_89_commit = fields
end

function M.get_boss_89_commit()
	local root = elses()
	return root.boss_89_commit
end

--- Serialized StageAPI layout-guard targets for Continue restore.
function M.set_stageapi_protected(rows)
	local root = elses()
	root.stageapi_protected = rows
end

function M.get_stageapi_protected()
	local root = elses()
	return root.stageapi_protected
end

function M.on_game_started(is_continued)
	if is_continued then
		return
	end
	M.clear_persist("new_run")
	M.cache.debug_force_root = nil
	M.cache.debug_force_boss = nil
end

function M.snapshot_for_status()
	local root = elses() or {}
	local floor = root.floor or {}
	local nxt = root.next or {}
	return {
		phase = root.phase or "idle",
		root_seed = root.root_seed,
		next_root_seed = nxt.root_seed,
		layout_ready = root.layout_ready,
		identity_restored = root.identity_restored,
		negative_ready = root.negative_ready,
		generation_ok = root.generation_ok,
		fail_reason = root.fail_reason,
		restore_stage = root.restore_stage,
		restore_stage_type = root.restore_stage_type,
		target_stage = root.target_stage,
		target_stage_type = root.target_stage_type,
		force_boss_subtype = root.force_boss_subtype,
		compat_angel = root.compat and root.compat.room84_angel == true,
		compat_devil = root.compat and root.compat.room84_devil == true,
		compat_seija = root.compat and root.compat.seija_curses == true,
		floor_deal_type = floor.deal_type,
		floor_boss_90_entered = floor.boss_90_entered,
		floor_map_settled = floor.map_settlement_done,
		floor_84_options = floor.fixed_84_options_spawned,
		floor_mirror_79_knife = floor.mirror_79_knife_piece_spawned,
		floor_secret_exit_progress = floor.secret_exit_door and floor.secret_exit_door.progress,
	}
end

return M

-- Circular scan + per-target proxy suction for Alien Savior (replaces old abduct_queue).
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")
local policy = require("Qing_Remaster_scripts.items.alien_savior.suction_policy")
local proxy = require("Qing_Remaster_scripts.items.alien_savior.suction_proxy")
local rock_topology = require("Qing_Remaster_scripts.others.grid_rock_topology")
local visual = require("Qing_Remaster_scripts.items.alien_savior.visual")
local state = require("Qing_Remaster_scripts.items.alien_savior.state")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local S = {}

local HOLD_PROTECT = { protect = true }
local FREEZE_DESC = Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE)
local NO_SPRITE_DESC = Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_SPRITE_UPDATE)
local NO_QUERY_DESC = Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_QUERY)

local dbg = {
	enabled = false,
	show_rings = false,
	paused = false,
	force_scan = false,
}

local function cfg()
	return C.SUCTION or {}
end

local function clamp01(t)
	if t < 0 then
		return 0
	end
	if t > 1 then
		return 1
	end
	return t
end

local function smoothstep(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end

local function alive(ent)
	return ent and ent.Exists and ent:Exists() and not ent:IsDead()
end

local function lerp_vec(a, b, t)
	return Vector(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
end

local function dist(a, b)
	local dx = a.X - b.X
	local dy = a.Y - b.Y
	return math.sqrt(dx * dx + dy * dy)
end

function S.set_debug(patch)
	patch = patch or {}
	for k, v in pairs(patch) do
		dbg[k] = v
	end
end

function S.get_debug()
	return dbg
end

local function scan_center(txn)
	if txn.work_feet then
		return Vector(txn.work_feet.X, txn.work_feet.Y)
	end
	local bv = txn.beam_visual
	if bv and bv.foot_initialized then
		return Vector(bv.foot_x, bv.foot_y)
	end
	local mouth = visual.mouth_world_pos(txn)
	return Vector(mouth.X, mouth.Y + (C.BEAM_WORK_LENGTH or 110))
end

local function mouth_pos(txn)
	return visual.mouth_world_pos(txn)
end

local function ensure_suction(txn)
	if txn.suction then
		return txn.suction
	end
	txn.suction = {
		scan_age = 0,
		scan_radius = 0,
		scan_r_max = 0,
		scan_complete = false,
		jobs = {},
		reserved = {},
		completed = 0,
		finish_frame = nil,
		timeout = false,
		timeout_reason = nil,
		next_job_id = 1,
		candidates = {},
	}
	return txn.suction
end

local function sort_candidates(list)
	table.sort(list, function(a, b)
		if a.dist ~= b.dist then
			return a.dist < b.dist
		end
		local ak = a.sort_key or ""
		local bk = b.sort_key or ""
		if ak ~= bk then
			return ak < bk
		end
		return (a.id or 0) < (b.id or 0)
	end)
end

local function note_npc_reject(su, ent, result, reason)
	if not su then
		return
	end
	su.npc_rejects = su.npc_rejects or {}
	local h = GetPtrHash(ent)
	if su.npc_rejects[h] then
		return
	end
	su.npc_rejects[h] = {
		type = ent.Type,
		variant = ent.Variant,
		subtype = ent.SubType,
		size = ent.Size,
		is_boss = ent.IsBoss and ent:IsBoss() or false,
		is_vulnerable = ent.IsVulnerableEnemy and ent:IsVulnerableEnemy() or false,
		is_enemy = ent.IsEnemy and ent:IsEnemy() or false,
		friendly = ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == true,
		charm = ent:HasEntityFlags(EntityFlag.FLAG_CHARM) == true,
		result = result,
		reason = reason,
	}
end

local function collect_candidates(txn, center, su)
	local list = {}
	local ents = Isaac.GetRoomEntities()
	for _, ent in ipairs(ents) do
		if ent:ToNPC() then
			local result, reason = policy.evaluate_npc(ent)
			if result == "abduct" then
				local key = policy.reserve_key_entity(ent)
				local pos = Vector(ent.Position.X, ent.Position.Y)
				list[#list + 1] = {
					kind = "npc",
					key = key,
					sort_key = key,
					pos = pos,
					dist = dist(pos, center),
					ent = ent,
					hash = GetPtrHash(ent),
					size = ent.Size,
					eligibility_reason = reason,
				}
			else
				note_npc_reject(su, ent, result, reason)
			end
		else
			local kind = policy.entity_kind(ent)
			if kind then
				local key = policy.reserve_key_entity(ent)
				local pos = Vector(ent.Position.X, ent.Position.Y)
				list[#list + 1] = {
					kind = kind,
					key = key,
					sort_key = key,
					pos = pos,
					dist = dist(pos, center),
					ent = ent,
					hash = GetPtrHash(ent),
				}
			end
		end
	end
	local room = Game():GetRoom()
	local size = room:GetGridSize()
	for i = 0, size - 1 do
		if not state.is_absorbed_grid(i) then
			local grid = room:GetGridEntity(i)
			if policy.is_safe_grid(grid) then
				local pos = room:GetGridPosition(i)
				local key = policy.reserve_key_grid(i)
				list[#list + 1] = {
					kind = "grid",
					key = key,
					sort_key = string.format("g:%05d", i),
					pos = Vector(pos.X, pos.Y),
					dist = dist(pos, center),
					grid_index = i,
					grid_kind = policy.grid_kind(grid),
				}
			end
		end
	end
	sort_candidates(list)
	return list
end

--- Append newly eligible targets during scan; never duplicates reserved keys.
local function refresh_candidates(txn, su)
	local center = su.center or scan_center(txn)
	local fresh = collect_candidates(txn, center, su)
	local added = 0
	local rmax = su.scan_r_max or 40
	for _, cand in ipairs(fresh) do
		if not su.reserved[cand.key] then
			local exists = false
			for _, old in ipairs(su.candidates) do
				if old.key == cand.key then
					exists = true
					-- Refresh wrapper / live size.
					old.ent = cand.ent
					old.pos = cand.pos
					old.dist = cand.dist
					old.size = cand.size
					break
				end
			end
			if not exists then
				su.candidates[#su.candidates + 1] = cand
				added = added + 1
				if cand.dist > rmax then
					rmax = cand.dist
				end
			end
		end
	end
	su.scan_r_max = rmax + 8
	su.candidate_refresh_added = (su.candidate_refresh_added or 0) + added
	return added
end

local function seed_laser_queue(txn)
	txn.laser_queue = {}
	local seen = {}
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent:ToNPC() and policy.classify_npc(ent) == "laser" then
			local h = GetPtrHash(ent)
			if not seen[h] then
				seen[h] = true
				txn.laser_queue[#txn.laser_queue + 1] = { hash = h, ent = ent }
			end
		end
	end
end

--- Anna stop_time + Eclipse Catch: freeze AI/anim, hide native draw, clear collision.
local function hide_npc(job)
	local ent = job.ent
	if not alive(ent) then
		return false
	end
	job.saved_scale = Vector(ent.SpriteScale.X, ent.SpriteScale.Y)
	job.attr = job.attr or {}
	Attribute_holder.ensure_hold_token(ent, job.attr, "freeze", "EntityFlag_FLAG_FREEZE", true, FREEZE_DESC)
	Attribute_holder.ensure_hold_token(ent, job.attr, "no_sprite", "EntityFlag_FLAG_NO_SPRITE_UPDATE", true, NO_SPRITE_DESC)
	Attribute_holder.ensure_hold_token(ent, job.attr, "no_query", "EntityFlag_FLAG_FLAG_NO_QUERY", true, NO_QUERY_DESC)
	Attribute_holder.ensure_hold_token(ent, job.attr, "coll", "EntityCollisionClass", EntityCollisionClass.ENTCOLL_NONE, HOLD_PROTECT)
	Attribute_holder.ensure_hold_token(ent, job.attr, "grid", "GridCollisionClass", EntityGridCollisionClass.GRIDCOLL_NONE, HOLD_PROTECT)
	-- Eclipse: Visible=false; proxy renders via Renderer:GetSprite().
	Attribute_holder.ensure_hold_token(ent, job.attr, "visible", "Visible", false, HOLD_PROTECT)
	ent.Velocity = Vector.Zero
	job.owned = true
	return true
end

local function restore_npc(job)
	local ent = job.ent
	if job.attr and ent then
		Attribute_holder.rewind_hold_token(ent, job.attr, "freeze", "EntityFlag_FLAG_FREEZE", FREEZE_DESC)
		Attribute_holder.rewind_hold_token(ent, job.attr, "no_sprite", "EntityFlag_FLAG_NO_SPRITE_UPDATE", NO_SPRITE_DESC)
		Attribute_holder.rewind_hold_token(ent, job.attr, "no_query", "EntityFlag_FLAG_FLAG_NO_QUERY", NO_QUERY_DESC)
		Attribute_holder.rewind_hold_token(ent, job.attr, "coll", "EntityCollisionClass")
		Attribute_holder.rewind_hold_token(ent, job.attr, "grid", "GridCollisionClass")
		Attribute_holder.rewind_hold_token(ent, job.attr, "visible", "Visible")
		job.attr = nil
	end
	if alive(ent) then
		if job.saved_scale then
			ent.SpriteScale = job.saved_scale
		end
		ent.Velocity = Vector.Zero
	elseif ent then
		Attribute_holder.force_clear_freeze_entity(ent)
	end
	job.owned = false
	job.renderer = nil
end

local function park_npc(job)
	local ent = job.ent or job.renderer
	if not alive(ent) then
		return
	end
	local park = job.park_pos or job.source_pos or ent.Position
	ent.Position = park
	ent.Velocity = Vector.Zero
	if auxi.fix_position then
		auxi.fix_position(ent)
	end
end

local function create_proxy_for_job(job, txn)
	if job.kind == "projectile" then
		local ent = job.ent
		if not alive(ent) then
			job.replace_failure_reason = "projectile_gone"
			return false
		end
		local spr, meta = proxy.snapshot_entity_sprite(ent)
		job.sprite = spr
		job.original_color = meta and meta.original_color or nil
		job.base_scale = Vector(ent.SpriteScale.X, ent.SpriteScale.Y)
		if not job.sprite then
			job.replace_failure_reason = "sprite_snapshot_failed"
			return false
		end
		ent:Remove()
		job.ent = nil
		job.original_removed = true
		return true
	elseif job.kind == "npc" then
		local ent = job.ent
		if not alive(ent) then
			job.replace_failure_reason = "npc_gone"
			return false
		end
		-- Live Renderer (Eclipse): no Sprite() snapshot / copy_sprite / illustrate_sprite.
		local src = ent.GetSprite and ent:GetSprite()
		if not src then
			job.replace_failure_reason = "no_sprite"
			return false
		end
		job.original_color = auxi.copy_color(src.Color)
		job.base_scale = Vector(ent.SpriteScale.X, ent.SpriteScale.Y)
		job.park_pos = Vector(job.source_pos.X, job.source_pos.Y)
		job.renderer = ent
		job.sprite = nil
		if not hide_npc(job) then
			job.replace_failure_reason = "hide_failed"
			restore_npc(job)
			return false
		end
		park_npc(job)
		return true
	elseif job.kind == "grid" then
		local room = Game():GetRoom()
		local grid = room:GetGridEntity(job.grid_index)
		local gkind = policy.grid_kind(grid)
		if not gkind then
			job.replace_failure_reason = "not_safe_grid"
			return false
		end
		job.grid_kind = gkind
		job.grid_type = grid:GetType()
		job.grid_variant = grid:GetVariant()
		local spr, meta = proxy.snapshot_grid_sprite(grid)
		job.sprite = spr
		job.base_scale = Vector(1, 1)
		if meta then
			job.original_color = meta.original_color
			job.grid_texture_path = meta.texture_path
			job.grid_texture_resolution = meta.grid_texture_resolution
			job.sprite_animation = meta.animation
			job.sprite_frame = meta.frame
		end
		if not job.sprite then
			job.replace_failure_reason = "sprite_snapshot_failed"
			return false
		end
		-- Take away without smash rewards, then persistent null decoration.
		if gkind == "rock" then
			rock_topology.remove_rock(room, job.grid_index, { path_penalty = 0, keep_decoration = false })
			local remain = room:GetGridEntity(job.grid_index)
			if remain and rock_topology.is_rock(remain) and room.RemoveGridEntityImmediate then
				room:RemoveGridEntityImmediate(job.grid_index, 0, false)
				remain = room:GetGridEntity(job.grid_index)
			end
			job.grid_removed = remain == nil or not rock_topology.is_rock(remain)
		else
			-- GRID_POOP: plain remove (not rock_topology); Destroy would drop rewards.
			room:RemoveGridEntity(job.grid_index, 0, false)
			local remain = room:GetGridEntity(job.grid_index)
			if remain and remain:GetType() == GridEntityType.GRID_POOP and room.RemoveGridEntityImmediate then
				room:RemoveGridEntityImmediate(job.grid_index, 0, false)
				remain = room:GetGridEntity(job.grid_index)
			end
			job.grid_removed = remain == nil or remain:GetType() ~= GridEntityType.GRID_POOP
		end
		if not job.grid_removed then
			job.replace_failure_reason = "remove_failed"
			return false
		end
		state.register_absorbed_grid(job.grid_index, {
			tp = job.grid_type,
			variant = job.grid_variant,
			kind = gkind,
		})
		job.persistence_registered = true
		-- Match auxi.tryremovegrid(force): spawn decoration after a short delay so remove sticks.
		local gidx = job.grid_index
		local expect_kind = gkind
		delay_buffer.addeffe(function()
			local r = Game():GetRoom()
			if not r then
				return
			end
			local cur = r:GetGridEntity(gidx)
			if expect_kind == "rock" and cur and rock_topology.is_rock(cur) then
				rock_topology.remove_rock(r, gidx, { path_penalty = 0, keep_decoration = false })
				if r.RemoveGridEntityImmediate and r:GetGridEntity(gidx) then
					r:RemoveGridEntityImmediate(gidx, 0, false)
				end
			elseif expect_kind == "poop" and cur and cur:GetType() == GridEntityType.GRID_POOP then
				r:RemoveGridEntity(gidx, 0, false)
				if r.RemoveGridEntityImmediate and r:GetGridEntity(gidx) then
					r:RemoveGridEntityImmediate(gidx, 0, false)
				end
			end
			cur = r:GetGridEntity(gidx)
			if not cur or cur:GetType() ~= GridEntityType.GRID_DECORATION then
				state.spawn_null_decoration(r, gidx)
			end
		end, {}, 2)
		job.decoration_replaced = true
		job.original_removed = true
		return true
	end
	return false
end

local function consume_job(job, txn)
	if job.done then
		return
	end
	job.done = true
	job.state = "consumed"
	job.sprite = nil
	if job.kind == "npc" then
		local ent = job.ent
		if job.owned then
			restore_npc(job)
		end
		if alive(ent) then
			ent:Kill()
			txn.stats = txn.stats or {}
			txn.stats.abducted = (txn.stats.abducted or 0) + 1
		end
	elseif job.kind == "grid" and (job.grid_removed or job.decoration_replaced) then
		txn.stats = txn.stats or {}
		txn.stats.rocks = (txn.stats.rocks or 0) + 1
	elseif job.kind == "projectile" then
		txn.stats = txn.stats or {}
		txn.stats.projectiles = (txn.stats.projectiles or 0) + 1
	end
	local su = txn.suction
	if su then
		su.completed = (su.completed or 0) + 1
		su.last_completed = {
			id = job.id,
			kind = job.kind,
			frame = txn.phase_frame,
		}
	end
end

local function cancel_job(job, restore)
	if job.done then
		return
	end
	job.done = true
	job.state = restore and "restored" or "cancelled"
	job.sprite = nil
	-- Always release Attribute_holder claims if we owned the NPC (even on hard cancel).
	if job.kind == "npc" and job.owned then
		if restore then
			restore_npc(job)
		else
			restore_npc(job)
			job.state = "cancelled"
		end
	end
end

local function start_job(txn, su, cand)
	if su.reserved[cand.key] then
		return
	end
	su.reserved[cand.key] = true
	local id = su.next_job_id
	su.next_job_id = id + 1
	local sc = cfg()
	local kind_cfg = (sc.KIND and sc.KIND[cand.kind]) or {}
	local shake = kind_cfg.shake or sc.SHAKE_FRAMES or 3
	local approach = kind_cfg.approach or sc.APPROACH_DUR or 12
	local lift = kind_cfg.lift or sc.LIFT_DUR or 14
	-- Size scales NPC motion only (eligibility is independent).
	if cand.kind == "npc" then
		local m = policy.npc_motion_scale(cand.size or (cand.ent and cand.ent.Size))
		shake = math.floor(shake + (m > 1.25 and 2 or 0))
		approach = math.max(8, math.floor(approach * m + 0.5))
		lift = math.max(8, math.floor(lift * m + 0.5))
	end
	local job = {
		id = id,
		kind = cand.kind,
		state = "shaking",
		age = 0,
		source_pos = Vector(cand.pos.X, cand.pos.Y),
		staging_pos = Vector(su.center.X, su.center.Y),
		pos = Vector(cand.pos.X, cand.pos.Y),
		shake_duration = shake,
		approach_duration = approach,
		lift_duration = lift,
		ent = cand.ent,
		hash = cand.hash,
		npc_size = cand.size,
		eligibility_reason = cand.eligibility_reason,
		grid_index = cand.grid_index,
		key = cand.key,
		progress = 0,
		rotation = 0,
		scale = 1,
		proxy_created = false,
		decoration_replaced = false,
		persistence_registered = false,
		replace_failure_reason = nil,
	}
	su.jobs[#su.jobs + 1] = job
end

local function tick_job(job, txn)
	local sc = cfg()
	job.age = (job.age or 0) + 1
	local shake_f = sc.SHAKE_FRAMES or 3

	if job.state == "shaking" then
		shake_f = job.shake_duration or shake_f
		local wobble = math.sin(job.age * 1.7) * (job.kind == "grid" and 3.5 or 2.5)
		local lift = (job.kind == "grid") and (job.age * 0.6) or 0
		job.pos = job.source_pos + Vector(wobble, -lift)
		job.rotation = wobble * 3
		-- Nudge live originals so scan arrival is visible before proxy swap.
		if job.kind == "npc" or job.kind == "projectile" then
			local ent = job.ent
			if alive(ent) then
				ent.Position = job.pos
				ent.Velocity = Vector.Zero
			end
		end
		if job.age >= shake_f then
			if create_proxy_for_job(job, txn) then
				job.proxy_created = true
				job.state = "approaching"
				job.age = 0
			else
				cancel_job(job, false)
			end
		end
		return
	end

	if job.state == "approaching" or job.state == "ascending" then
		-- Keep real NPC parked (Eclipse nails Renderer.Position); motion is visual-only.
		if job.kind == "npc" then
			if not alive(job.ent) and not alive(job.renderer) then
				cancel_job(job, false)
				return
			end
			-- Refresh wrapper by hash if needed.
			if job.hash and (not alive(job.ent) or not alive(job.renderer)) then
				for _, ent in ipairs(Isaac.GetRoomEntities()) do
					if GetPtrHash(ent) == job.hash then
						job.ent = ent
						job.renderer = ent
						break
					end
				end
			end
			park_npc(job)
		end
	end

	if job.state == "approaching" then
		local dur = math.max(1, job.approach_duration or 12)
		local t = clamp01(job.age / dur)
		local ease = smoothstep(t)
		local mid = lerp_vec(job.source_pos, job.staging_pos, ease)
		local arc = math.sin(t * math.pi) * 10
		job.pos = mid + Vector(0, -arc)
		job.rotation = (job.rotation or 0) + 4
		job.scale = 1 - 0.15 * t
		job.progress = t
		if t >= 1 then
			job.state = "ascending"
			job.age = 0
			job.lift_from = Vector(job.pos.X, job.pos.Y)
		end
		return
	end

	if job.state == "ascending" then
		local dur = math.max(1, job.lift_duration or 14)
		local t = clamp01(job.age / dur)
		local ease = t * t
		local mouth = mouth_pos(txn)
		local from = job.lift_from or job.staging_pos
		job.pos = lerp_vec(from, mouth, ease)
		job.rotation = (job.rotation or 0) + 8
		local end_s = sc.LIFT_SCALE_END or 0.12
		job.scale = 1 - (1 - end_s) * ease
		job.progress = t
		if t >= 1 then
			consume_job(job, txn)
		end
	end
end

function S.begin(txn)
	local su = ensure_suction(txn)
	su.center = scan_center(txn)
	su.scan_age = 0
	su.scan_radius = 0
	su.scan_complete = false
	su.jobs = {}
	su.reserved = {}
	su.completed = 0
	su.finish_frame = nil
	su.timeout = false
	su.timeout_reason = nil
	su.next_job_id = 1
	su.npc_rejects = {}
	su.candidate_refresh_added = 0
	su.candidates = collect_candidates(txn, su.center, su)
	local rmax = 40
	for _, c in ipairs(su.candidates) do
		if c.dist > rmax then
			rmax = c.dist
		end
	end
	su.scan_r_max = rmax + 8
	seed_laser_queue(txn)
	-- Clear legacy fields so old path cannot revive.
	txn.abduct_queue = nil
	txn.rock_queue = nil
end

function S.all_jobs_finished(txn)
	local su = txn and txn.suction
	if not su then
		return true
	end
	for _, job in ipairs(su.jobs) do
		if not job.done then
			return false
		end
	end
	return true
end

function S.scan_complete(txn)
	local su = txn and txn.suction
	return su and su.scan_complete == true
end

function S.phase_ready(txn)
	local su = txn and txn.suction
	if not su then
		return true
	end
	local sc = cfg()
	local pf = txn.phase_frame or 0
	local min_done = pf >= (sc.MIN_WORK or 45)
	if not (su.scan_complete and S.all_jobs_finished(txn) and min_done) then
		return false
	end
	if not su.finish_frame then
		su.finish_frame = pf
	end
	return pf - su.finish_frame >= (sc.TAIL_GRACE or 8)
end

function S.update(txn)
	if not txn then
		return
	end
	local su = ensure_suction(txn)
	if dbg.paused and not dbg.force_scan then
		return
	end
	local sc = cfg()
	local scan_dur = sc.SCAN_DURATION or 45

	-- Expand scan ring.
	if not su.scan_complete then
		su.scan_age = (su.scan_age or 0) + 1
		local refresh_n = sc.CANDIDATE_REFRESH or 5
		if refresh_n > 0 and (su.scan_age % refresh_n) == 0 then
			refresh_candidates(txn, su)
		end
		local u = clamp01(su.scan_age / math.max(1, scan_dur))
		su.scan_radius = (su.scan_r_max or 40) * smoothstep(u)
		for _, cand in ipairs(su.candidates or {}) do
			if not su.reserved[cand.key] and cand.dist <= su.scan_radius + 0.5 then
				-- Refresh live entity wrapper by hash when possible.
				if cand.hash then
					for _, ent in ipairs(Isaac.GetRoomEntities()) do
						if GetPtrHash(ent) == cand.hash then
							cand.ent = ent
							break
						end
					end
				end
				start_job(txn, su, cand)
			end
		end
		if su.scan_age >= scan_dur or dbg.force_scan then
			-- Final refresh so late spawns in the last window still get a chance.
			refresh_candidates(txn, su)
			for _, cand in ipairs(su.candidates or {}) do
				if not su.reserved[cand.key] and cand.dist <= (su.scan_r_max or 0) + 0.5 then
					start_job(txn, su, cand)
				end
			end
			su.scan_complete = true
			su.scan_radius = su.scan_r_max or su.scan_radius
			dbg.force_scan = false
		end
	end

	-- Keep center/staging synced to live beam foot.
	su.center = scan_center(txn)
	for _, job in ipairs(su.jobs) do
		if not job.done and (job.state == "shaking" or job.state == "approaching") then
			job.staging_pos = Vector(su.center.X, su.center.Y)
		end
		if not job.done then
			tick_job(job, txn)
		end
	end

	if S.scan_complete(txn) and S.all_jobs_finished(txn) and (txn.phase_frame or 0) >= (sc.MIN_WORK or 45) then
		if not su.finish_frame then
			su.finish_frame = txn.phase_frame
		end
	end
end

--- Soft timeout: consume mid-flight proxies; restore shaking NPCs; leave unscanned alone.
function S.timeout(txn)
	local su = txn and txn.suction
	if not su then
		return
	end
	su.timeout = true
	su.timeout_reason = "max_work"
	su.scan_complete = true
	for _, job in ipairs(su.jobs) do
		if not job.done then
			if job.state == "shaking" then
				cancel_job(job, true)
			elseif job.state == "approaching" or job.state == "ascending" then
				consume_job(job, txn)
			else
				cancel_job(job, false)
			end
		end
	end
	su.finish_frame = txn.phase_frame or 0
end

function S.finalize(txn, opts)
	opts = opts or {}
	local su = txn and txn.suction
	if not su then
		return
	end
	for _, job in ipairs(su.jobs) do
		if not job.done then
			if opts.settle ~= false and (job.state == "approaching" or job.state == "ascending") then
				consume_job(job, txn)
			elseif job.state == "shaking" then
				cancel_job(job, true)
			else
				cancel_job(job, opts.settle == false)
			end
		end
	end
end

function S.abort(txn)
	S.finalize(txn, { settle = false })
	-- Restore any still-owned NPCs that finalize marked restored/cancelled incorrectly.
	local su = txn and txn.suction
	if not su then
		return
	end
	for _, job in ipairs(su.jobs) do
		if job.kind == "npc" and job.owned and alive(job.ent) then
			restore_npc(job)
		end
		job.sprite = nil
	end
end

function S.render(txn)
	local su = txn and txn.suction
	if not su then
		return
	end
	for _, job in ipairs(su.jobs) do
		if job.done then
			-- skip
		elseif job.kind == "npc" and job.renderer and (job.state == "approaching" or job.state == "ascending") then
			-- Eclipse Renderer path; native draw suppressed via Visible=false.
			proxy.render_live_npc(job.renderer, job.pos, {
				scale = job.scale or 1,
				base_scale = job.base_scale,
				rotation = job.rotation or 0,
				original_color = job.original_color,
				tint_strength = proxy.tint_strength(job),
			})
		elseif job.sprite and (job.state == "approaching" or job.state == "ascending") then
			-- Projectile / grid snapshots only.
			proxy.render(job.sprite, job.pos, {
				scale = job.scale or 1,
				base_scale = job.base_scale,
				rotation = job.rotation or 0,
				original_color = job.original_color,
				tint_strength = proxy.tint_strength(job),
			})
		end
	end
	if dbg.show_rings and su.center and Isaac.DrawLine then
		local r = su.scan_radius or 0
		local col = KColor(0.3, 1.0, 0.7, 0.35)
		local steps = 24
		local prev = nil
		for i = 0, steps do
			local a = (i / steps) * math.pi * 2
			local p = su.center + Vector(math.cos(a) * r, math.sin(a) * r * 0.65)
			local room = Game():GetRoom()
			local scr = room and room:WorldToScreenPosition(p) or Isaac.WorldToScreen(p)
			if prev then
				Isaac.DrawLine(prev, scr, col, col, 1)
			end
			prev = scr
		end
	end
end

function S.audit(txn)
	local su = txn and txn.suction
	if not su then
		return { active = false }
	end
	local active_n, pending_n, proxy_n = 0, 0, 0
	local jobs = {}
	for _, job in ipairs(su.jobs) do
		if not job.done then
			active_n = active_n + 1
			if job.state == "shaking" then
				pending_n = pending_n + 1
			end
			if job.sprite then
				proxy_n = proxy_n + 1
			end
		end
		local oc = job.original_color
		local tint_s = proxy.tint_strength(job)
		local rendered = nil
		if oc then
			rendered = proxy.compose_tint(oc, tint_s)
		end
		jobs[#jobs + 1] = {
			id = job.id,
			kind = job.kind,
			state = job.state,
			age = job.age,
			progress = job.progress,
			pos = job.pos and { x = job.pos.X, y = job.pos.Y } or nil,
			done = job.done == true,
			npc_size = job.npc_size,
			eligibility_reason = job.eligibility_reason,
			grid_index = job.grid_index,
			grid_kind = job.grid_kind,
			grid_type = job.grid_type,
			grid_variant = job.grid_variant,
			sprite_file = job.grid_texture_path,
			sprite_animation = job.sprite_animation,
			sprite_frame = job.sprite_frame,
			grid_texture_resolution = job.grid_texture_resolution,
			original_color = oc and auxi.color2table(oc) or nil,
			rendered_color = rendered and auxi.color2table(rendered) or nil,
			tint_strength = tint_s,
			proxy_created = job.proxy_created == true,
			live_renderer = job.renderer ~= nil,
			decoration_replaced = job.decoration_replaced == true,
			persistence_registered = job.persistence_registered == true,
			replace_failure_reason = job.replace_failure_reason,
		}
	end
	local rejects = {}
	for _, row in pairs(su.npc_rejects or {}) do
		rejects[#rejects + 1] = row
	end
	local sc = cfg()
	local pf = txn.phase_frame or 0
	local until_finish = nil
	if su.finish_frame then
		until_finish = math.max(0, (sc.TAIL_GRACE or 8) - (pf - su.finish_frame))
	end
	return {
		active = true,
		scan_age = su.scan_age,
		scan_radius = su.scan_radius,
		scan_r_max = su.scan_r_max,
		scan_complete = su.scan_complete == true,
		active_jobs = active_n,
		pending_jobs = pending_n,
		completed = su.completed or 0,
		proxy_count = proxy_n,
		finish_frame = su.finish_frame,
		time_until_finish = until_finish,
		phase_frame = pf,
		max_work = sc.MAX_WORK or 150,
		timeout = su.timeout == true,
		timeout_reason = su.timeout_reason,
		last_completed = su.last_completed,
		phase_ready = S.phase_ready(txn),
		completed_grid_count = state.absorbed_grid_count(),
		candidate_count = #(su.candidates or {}),
		candidate_refresh_added = su.candidate_refresh_added or 0,
		npc_rejects = rejects,
		jobs = jobs,
	}
end

return S

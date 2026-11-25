-- Golden Compass: Luna / Fragmented Card extras → north mirror of south secret cluster.
-- GC rebuilds the floor itself: plan new RoomConfig via add_asg (no scan/relocate of Home secrets).
-- Corridor row 6 is the axis. Never claim SGID 72 (Voodoo curse).
-- Topology links are built only from rooms that actually exist after Place.

local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local M = {}

-- Secret layer (row 5) pairs with super layer (row 4): 71↔58, 69↔56.
M.NORTH_SECRET_SLOTS = {71, 69}
M.SECRET_SUPER_PAIR = {
	[71] = 58,
	[69] = 56,
}
M.NORTH_ULTRASECRET_SLOTS = {57, 44}
M.NORTH_RESERVED_SGIDS = {
	[72] = "voodoo_curse_72",
}

local MASK_UP = 1 << DoorSlot.UP0
local MASK_DOWN = 1 << DoorSlot.DOWN0
local MASK_LEFT = 1 << DoorSlot.LEFT0
local MASK_RIGHT = 1 << DoorSlot.RIGHT0

--- Effective Luna / Fragmented Card counts (stacks + golden trinket multiplier).
function M.inventory_extra_counts()
	local luna_id = CollectibleType and CollectibleType.COLLECTIBLE_LUNA
	local frag_id = TrinketType and TrinketType.TRINKET_FRAGMENTED_CARD
	local luna = 0
	local frag = 0
	if luna_id then
		luna = tonumber(auxi.get_player_have_collectible_num(luna_id)) or 0
	end
	if frag_id then
		frag = tonumber(auxi.get_player_have_trinket_num(frag_id)) or 0
	end
	if luna < 0 then
		luna = 0
	end
	if frag < 0 then
		frag = 0
	end
	return {
		luna_count = luna,
		fragmented_card_count = frag,
		secret = luna + frag,
		supersecret = luna,
		ultrasecret = 0,
		note = "GC plans extras from inventory; does not scan/relocate Home secrets",
	}
end

function M.slot_block_reason(sgid, plan)
	if M.NORTH_RESERVED_SGIDS[sgid] then
		return M.NORTH_RESERVED_SGIDS[sgid]
	end
	if plan and plan[sgid] then
		return "already_planned"
	end
	return nil
end

--- Door mask from planned adjacency (not unconditional FOUR).
function M.required_doors_for_sgid(sgid, assigned)
	assigned = assigned or {}
	local mask = 0
	if sgid == 71 then
		mask = mask | MASK_DOWN -- 84
		if assigned[58] then
			mask = mask | MASK_UP
		end
	elseif sgid == 69 then
		mask = mask | MASK_DOWN -- 82
		if assigned[56] then
			mask = mask | MASK_UP
		end
	elseif sgid == 58 then
		mask = mask | MASK_DOWN -- 71
		if assigned[57] then
			mask = mask | MASK_LEFT
		end
	elseif sgid == 56 then
		mask = mask | MASK_DOWN -- 69
		if assigned[57] then
			mask = mask | MASK_RIGHT
		end
	elseif sgid == 57 then
		if assigned[56] then
			mask = mask | MASK_LEFT
		end
		if assigned[58] then
			mask = mask | MASK_RIGHT
		end
		if assigned[44] then
			mask = mask | MASK_UP
		end
	elseif sgid == 44 then
		mask = mask | MASK_DOWN -- 57
	end
	if mask == 0 then
		mask = MASK_DOWN
	end
	return mask
end

--- Only orthogonal adjacent links. No 84→58 / 82→56 skip.
--- present: set/map of sgid that actually exist (or planned set when dry-run).
function M.build_north_mirror_links(present)
	local map = {}
	if type(present) == "table" then
		if present[1] ~= nil and present[71] == nil and present[69] == nil and present[58] == nil then
			for i = 1, #present do
				local id = tonumber(present[i])
				if id then
					map[id] = true
				end
			end
		else
			for id, v in pairs(present) do
				local n = tonumber(id)
				if n and v then
					map[n] = true
				end
			end
		end
	end
	local function has(sgid)
		return map[sgid] == true
	end
	local links = {}
	if has(71) then
		links[#links + 1] = {from = 84, slot = DoorSlot.UP0, to = 71}
	end
	if has(69) then
		links[#links + 1] = {from = 82, slot = DoorSlot.UP0, to = 69}
	end
	if has(71) and has(58) then
		links[#links + 1] = {from = 71, slot = DoorSlot.UP0, to = 58}
	end
	if has(69) and has(56) then
		links[#links + 1] = {from = 69, slot = DoorSlot.UP0, to = 56}
	end
	if has(56) and has(57) then
		links[#links + 1] = {from = 56, slot = DoorSlot.RIGHT0, to = 57}
	end
	if has(57) and has(58) then
		links[#links + 1] = {from = 57, slot = DoorSlot.RIGHT0, to = 58}
	end
	if has(57) and has(44) then
		links[#links + 1] = {from = 57, slot = DoorSlot.UP0, to = 44}
	end
	return links
end

--- Plan-only: inventory → slot set → add_asg with final required_doors. No relocate.
function M.append_to_special_room_plan(pending, plan, summary, deps)
	deps = deps or {}
	local add_asg = deps.add_asg
	if type(add_asg) ~= "function" then
		error("north_secret_mirror.append_to_special_room_plan: add_asg required")
	end

	-- Continue / replay: do not re-plan from live inventory once finalized.
	if pending and pending.north_mirror_plan and pending.north_mirror_plan.finalized == true then
		return pending.north_mirror_plan
	end

	local inv = M.inventory_extra_counts()
	local want = {
		secret = inv.secret,
		supersecret = inv.supersecret,
		ultrasecret = inv.ultrasecret,
	}
	local blocked = {}
	local jobs = {} -- {sgid, room_type, pool, paired_secret?}
	local assigned_map = {}

	local function try_claim(sgid, room_type, pool_name, meta)
		local block = M.slot_block_reason(sgid, plan)
		if block then
			blocked[#blocked + 1] = {sgid = sgid, pool = pool_name, reason = block}
			return false
		end
		if assigned_map[sgid] then
			blocked[#blocked + 1] = {sgid = sgid, pool = pool_name, reason = "dup_claim"}
			return false
		end
		assigned_map[sgid] = true
		jobs[#jobs + 1] = {
			sgid = sgid,
			room_type = room_type,
			pool = pool_name,
			paired_secret = meta and meta.paired_secret,
		}
		return true
	end

	-- Pass 1: claim slots only (secrets → paired supers → ultras).
	local secret_n = 0
	for _, sgid in ipairs(M.NORTH_SECRET_SLOTS) do
		if secret_n >= want.secret then
			break
		end
		if try_claim(sgid, RoomType.ROOM_SECRET, "secret_north") then
			secret_n = secret_n + 1
		end
	end
	if secret_n < want.secret then
		blocked[#blocked + 1] = {
			pool = "secret_north",
			reason = "slots_exhausted",
			wanted = want.secret,
			placed = secret_n,
		}
	end

	local super_n = 0
	for _, secret_sgid in ipairs(M.NORTH_SECRET_SLOTS) do
		if super_n >= want.supersecret then
			break
		end
		if assigned_map[secret_sgid] then
			local super_sgid = M.SECRET_SUPER_PAIR[secret_sgid]
			if try_claim(super_sgid, RoomType.ROOM_SUPERSECRET, "supersecret_north", {
				paired_secret = secret_sgid,
			}) then
				super_n = super_n + 1
			end
		end
	end
	if super_n < want.supersecret then
		blocked[#blocked + 1] = {
			pool = "supersecret_north",
			reason = "no_paired_secret_or_slots",
			wanted = want.supersecret,
			placed = super_n,
		}
	end

	local ultra_n = 0
	if want.ultrasecret > 0 then
		if assigned_map[56] or assigned_map[58] then
			for _, sgid in ipairs(M.NORTH_ULTRASECRET_SLOTS) do
				if ultra_n >= want.ultrasecret then
					break
				end
				if sgid == 44 and not assigned_map[57] then
					blocked[#blocked + 1] = {sgid = 44, pool = "ultrasecret_north", reason = "needs_57"}
				elseif try_claim(sgid, RoomType.ROOM_ULTRASECRET, "ultrasecret_north") then
					ultra_n = ultra_n + 1
				end
			end
		else
			blocked[#blocked + 1] = {
				pool = "ultrasecret_north",
				reason = "no_super_neighbor",
				wanted = want.ultrasecret,
				placed = 0,
			}
		end
	end

	-- Pass 2: pick layouts with final required_doors from full assigned_map.
	local assigned = {}
	local place_order = {}
	for i = 1, #jobs do
		local job = jobs[i]
		local req = M.required_doors_for_sgid(job.sgid, assigned_map)
		local row = add_asg({
			sgid = job.sgid,
			room_type = job.room_type,
			pool = job.pool,
			required_doors = req,
			prefer_doors = req,
			weighted = true,
		})
		row.north_mirror = true
		row.via = (row.via or "roomset") .. "_north_mirror"
		local sum = summary[#summary]
		if sum and sum.sgid == job.sgid then
			sum.north_mirror = true
			sum.via = row.via
			sum.required_doors = req
		end
		assigned[#assigned + 1] = {
			sgid = job.sgid,
			pool = job.pool,
			via = row.via,
			variant = row.variant,
			required_doors = req,
			paired_secret = job.paired_secret,
		}
		place_order[#place_order + 1] = job.sgid
	end

	local provisional_links = M.build_north_mirror_links(assigned_map)
	pending.north_mirror_links = nil
	pending.north_mirror_place_order = place_order
	pending.north_mirror_plan = {
		inventory = inv,
		want = want,
		planned = {
			secret = secret_n,
			supersecret = super_n,
			ultrasecret = ultra_n,
		},
		placed_ok = nil,
		assigned = assigned,
		blocked = blocked,
		provisional_links = provisional_links,
		links = nil,
		place_order = place_order,
		finalized = false,
	}
	return pending.north_mirror_plan
end

--- Reachable from corridor anchors 84/82 via orthogonal north links only.
local function reachable_from_corridor(present_map, links)
	local adj = {}
	local function add_edge(a, b)
		adj[a] = adj[a] or {}
		adj[b] = adj[b] or {}
		adj[a][b] = true
		adj[b][a] = true
	end
	for i = 1, #(links or {}) do
		local link = links[i]
		if link and link.from and link.to then
			add_edge(link.from, link.to)
		end
	end
	local seen = {[84] = true, [82] = true}
	local queue = {84, 82}
	local qi = 1
	while qi <= #queue do
		local cur = queue[qi]
		qi = qi + 1
		local nbrs = adj[cur]
		if nbrs then
			for nxt in pairs(nbrs) do
				if not seen[nxt] then
					seen[nxt] = true
					queue[#queue + 1] = nxt
				end
			end
		end
	end
	local keep = {}
	local dropped = {}
	for id in pairs(present_map) do
		if seen[id] then
			keep[id] = true
		else
			dropped[#dropped + 1] = id
		end
	end
	table.sort(dropped)
	return keep, dropped
end

--- After Place: keep only successfully owned + corridor-reachable north SGIDs; build final links.
function M.finalize_after_place(pending, success_sgids)
	local map = {}
	if type(success_sgids) == "table" then
		if success_sgids[1] ~= nil then
			for i = 1, #success_sgids do
				local id = tonumber(success_sgids[i])
				if id then
					map[id] = true
				end
			end
		else
			for id, v in pairs(success_sgids) do
				if v and tonumber(id) then
					map[tonumber(id)] = true
				end
			end
		end
	end
	local provisional = M.build_north_mirror_links(map)
	local keep, dropped = reachable_from_corridor(map, provisional)
	local links = M.build_north_mirror_links(keep)
	local ok_list = {}
	for id in pairs(keep) do
		ok_list[#ok_list + 1] = id
	end
	table.sort(ok_list)
	if pending then
		pending.north_mirror_links = links
		if pending.north_mirror_plan then
			pending.north_mirror_plan.links = links
			pending.north_mirror_plan.placed_ok = ok_list
			pending.north_mirror_plan.unreachable = dropped
			pending.north_mirror_plan.finalized = true
		end
	end
	return links, ok_list, dropped
end

return M

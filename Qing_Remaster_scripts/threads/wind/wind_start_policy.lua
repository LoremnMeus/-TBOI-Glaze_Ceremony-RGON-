-- Pure decisions for storm start, test clicks, and failure cleanup.
-- No Isaac API. Game code and the standalone test both call this module.

local M = {}

local ACTIVE = {
	QUEUED = true,
	RUNNING = true,
	ARRIVED = true,
}

function M.expand(neighbor_fn, eye)
	local dist = {}
	local dir = {}
	dist[eye] = 0
	dir[eye] = -1
	local frontier = {{id = eye, power = 0}}
	while #frontier > 0 do
		local nxt = {}
		for _, node in ipairs(frontier) do
			local edges = neighbor_fn(node.id) or {}
			for _, edge in ipairs(edges) do
				local sgid = edge.id
				if sgid ~= nil and (dist[sgid] == nil or dist[sgid] > node.power + 1) then
					dist[sgid] = node.power + 1
					dir[sgid] = edge.dir
					nxt[#nxt + 1] = {id = sgid, power = node.power + 1}
				end
			end
		end
		frontier = nxt
	end
	return dist, dir
end

--- Formal play tries the random eye first, then another eye that reaches `current`.
--- Tests pass deterministic=true and keep the farthest stable eye.
function M.choose_eye(candidates, neighbor_fn, current, opts)
	opts = opts or {}
	if type(candidates) ~= "table" or #candidates == 0 then
		return nil, nil, nil, "no_bfs_candidates"
	end
	if opts.deterministic then
		local ids = {}
		for i, id in ipairs(candidates) do
			ids[i] = id
		end
		table.sort(ids)
		local best = nil
		for _, eye in ipairs(ids) do
			local dist, dir = M.expand(neighbor_fn, eye)
			local reached = (current == nil) or (dist[current] ~= nil)
			if reached then
				local score = current and dist[current] or 0
				if not best or score > best.score or (score == best.score and eye < best.eye) then
					best = {eye = eye, dist = dist, dir = dir, score = score}
				end
			end
		end
		if not best then
			return nil, nil, nil, "current_room_unreachable_from_eye"
		end
		return best.eye, best.dist, best.dir, nil
	end
	local first = tonumber(opts.first_index) or 1
	if first < 1 or first > #candidates then first = 1 end
	if current == nil then
		local eye = candidates[first]
		local dist, dir = M.expand(neighbor_fn, eye)
		return eye, dist, dir, nil
	end
	for n = 0, #candidates - 1 do
		local eye = candidates[((first - 1 + n) % #candidates) + 1]
		local dist, dir = M.expand(neighbor_fn, eye)
		if dist[current] ~= nil then
			return eye, dist, dir, nil
		end
	end
	return nil, nil, nil, "current_room_unreachable_from_eye"
end

--- nil distance is a hard stop. It is not distance 0.
function M.storm_commit_gate(state)
	state = state or {}
	if not state.floor_ok then
		return false, "need Mausoleum/Gehenna I"
	end
	if state.eye == nil then
		return false, "eye_room_missing"
	end
	if state.current_distance == nil then
		return false, "storm_bfs_distance_missing"
	end
	return true, nil
end

function M.click_action(job, requested_id)
	if type(job) == "table" and ACTIVE[job.status] then
		if job.id == requested_id then
			return "ignore_same"
		end
		return "busy"
	end
	return "start"
end

function M.room_event_matches(job, sgid)
	if type(job) ~= "table" then return false end
	if job.step ~= "room" then return false end
	if job.travel_token == nil or job.travel_token ~= job.request_id then
		return false
	end
	return sgid ~= nil and sgid == job.expect
end

--- Failure cleanup never clears BFS or the spawn flag.
--- Boss removal is limited to the request that spawned it.
function M.failure_cleanup_plan(job)
	if type(job) ~= "table" then
		return {
			remove_request = nil,
			reset_cover = false,
			shutdown_arena = false,
			reset_phase = false,
			clear_bfs = false,
			clear_spawn = false,
		}
	end
	local scene = job.may_spawn_boss == true
	local touched = job.touched_scene == true
	return {
		remove_request = scene and job.request_id or nil,
		reset_cover = scene and touched,
		shutdown_arena = scene and touched,
		reset_phase = touched,
		clear_bfs = false,
		clear_spawn = false,
	}
end

return M

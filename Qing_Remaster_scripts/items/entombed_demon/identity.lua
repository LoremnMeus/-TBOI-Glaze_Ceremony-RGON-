-- Match live Entombed Demon history rows to previously stamped instances.
-- Non-coffin rows are anchors. When a gap has fewer coffins than before, the
-- survivors keep the later instance ids, so removing an earlier same-time coffin
-- does not hand its record to the one behind it.
local M = {}

local NEG = -1000000000

local function anchor_same(left, right)
	return left.id == right.id and left.time == right.time and left.trinket == right.trinket
end

local function anchor_pairs(stamp, current)
	local sm, cm = {}, {}
	for i = 1, #stamp do
		if not stamp[i].coffin then sm[#sm + 1] = i end
	end
	for j = 1, #current do
		if not current[j].coffin then cm[#cm + 1] = j end
	end
	local n, m = #sm, #cm
	local score, choice = {}, {}
	for i = 0, n do
		score[i] = {}
		choice[i] = {}
		for j = 0, m do
			score[i][j] = NEG
		end
	end
	score[0][0] = 0
	for i = 0, n do
		for j = 0, m do
			if not (i == 0 and j == 0) then
				local best, how = NEG, nil
				if i > 0 and score[i - 1][j] > best then
					best, how = score[i - 1][j], "drop_stamp"
				end
				if j > 0 and score[i][j - 1] > best then
					best, how = score[i][j - 1], "drop_current"
				end
				if i > 0 and j > 0 and anchor_same(stamp[sm[i]], current[cm[j]]) then
					local matched = score[i - 1][j - 1] + 1
					if matched > best then
						best, how = matched, "match"
					end
				end
				score[i][j] = best
				choice[i][j] = how
			end
		end
	end
	local pairs = {}
	local i, j = n, m
	while i > 0 or j > 0 do
		local how = choice[i] and choice[i][j]
		if how == "match" then
			pairs[#pairs + 1] = {si = sm[i], cj = cm[j]}
			i = i - 1
			j = j - 1
		elseif how == "drop_stamp" then
			i = i - 1
		elseif how == "drop_current" then
			j = j - 1
		else
			break
		end
	end
	local ordered = {}
	for k = #pairs, 1, -1 do
		ordered[#ordered + 1] = pairs[k]
	end
	return ordered
end

local function assign_gap(assigned, stamp, current, s0, s1, c0, c1)
	local stamp_ids, current_indexes = {}, {}
	for i = s0 + 1, s1 - 1 do
		if stamp[i] and stamp[i].coffin then
			stamp_ids[#stamp_ids + 1] = stamp[i].instance
		end
	end
	for j = c0 + 1, c1 - 1 do
		if current[j] and current[j].coffin then
			current_indexes[#current_indexes + 1] = j
		end
	end
	local stamp_count, current_count = #stamp_ids, #current_indexes
	if current_count <= stamp_count then
		local start = stamp_count - current_count
		for k = 1, current_count do
			assigned[current_indexes[k]] = stamp_ids[start + k]
		end
	else
		for k = 1, stamp_count do
			assigned[current_indexes[k]] = stamp_ids[k]
		end
	end
end

function M.align(stamp, current)
	stamp = stamp or {}
	current = current or {}
	local assigned = {}
	local s_prev, c_prev = 0, 0
	for _, pair in ipairs(anchor_pairs(stamp, current)) do
		assign_gap(assigned, stamp, current, s_prev, pair.si, c_prev, pair.cj)
		s_prev, c_prev = pair.si, pair.cj
	end
	assign_gap(assigned, stamp, current, s_prev, #stamp + 1, c_prev, #current + 1)
	return assigned
end

function M.same_stamp(a, b)
	if a == b then return true end
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
	for i = 1, #a do
		local left, right = a[i], b[i]
		if left.id ~= right.id or left.time ~= right.time or left.trinket ~= right.trinket
			or left.coffin ~= right.coffin or left.instance ~= right.instance then
			return false
		end
	end
	return true
end

return M

-- Golden Compass Boss encounter memory (StageAPI-aligned: prefer unencountered, then allow repeat).
-- Used by boss_pick after a successful Boss@89 bind. Probe scans must NOT mark encounters.
-- Own persist under Golden Compass corridor save root; optional StageAPI read-through.

local state = require("Qing_Remaster_scripts.items.golden_compass.state")

local M = {}

local ENCOUNTER_KEY = "boss_encounters"

local function encounter_table()
	local root = state.get()
	local t = root[ENCOUNTER_KEY]
	if type(t) ~= "table" then
		t = {}
		root[ENCOUNTER_KEY] = t
	end
	return t
end

--- StageAPI SelectBoss keys EncounteredBosses by BossData.Name / NameTwo, not always by boss id.
local function stageapi_names_for(boss_id)
	local names = {}
	if type(boss_id) ~= "string" or boss_id == "" then
		return names
	end
	local ok, boss = pcall(function()
		if StageAPI and StageAPI.GetBossData then
			return StageAPI.GetBossData(boss_id)
		end
		return nil
	end)
	if ok and type(boss) == "table" then
		if type(boss.Name) == "string" and boss.Name ~= "" then
			names[#names + 1] = boss.Name
		end
		if type(boss.NameTwo) == "string" and boss.NameTwo ~= "" then
			names[#names + 1] = boss.NameTwo
		end
	end
	-- Fallback: some catalogs use Name as id.
	names[#names + 1] = boss_id
	return names
end

local function stageapi_is_encountered(boss_id)
	if not (StageAPI and StageAPI.GetBossEncountered) then
		return false
	end
	local names = stageapi_names_for(boss_id)
	for i = 1, #names do
		local ok, encountered = pcall(StageAPI.GetBossEncountered, names[i])
		if ok and encountered == true then
			return true
		end
	end
	return false
end

--- Mirror GC encounter into StageAPI Name/NameTwo keys (SelectBoss-compatible).
function M.sync_stageapi_encountered(boss_id)
	if not (StageAPI and StageAPI.SetBossEncountered) then
		return false
	end
	local names = stageapi_names_for(boss_id)
	local any = false
	for i = 1, #names do
		local ok = pcall(StageAPI.SetBossEncountered, names[i], true)
		any = any or ok
	end
	return any
end

function M.is_encountered(boss_id)
	if type(boss_id) ~= "string" or boss_id == "" then
		return false
	end
	local t = encounter_table()
	if t[boss_id] then
		return true
	end
	return stageapi_is_encountered(boss_id)
end

--- Only call after Boss identity + layout are successfully bound (not on probe / failed plan).
function M.mark_encountered(boss_id)
	if type(boss_id) ~= "string" or boss_id == "" then
		return false
	end
	local t = encounter_table()
	t[boss_id] = true
	return true
end

local COMMIT_KEY = "boss_encounter_commits"

local function commit_table()
	local root = state.get()
	local t = root[COMMIT_KEY]
	if type(t) ~= "table" then
		t = {}
		root[COMMIT_KEY] = t
	end
	return t
end

--- Commit encounter only once per generation token (Continue-safe).
--- token: stable string for this corridor instance (seed+stage+89 list/variant).
--- Returns: committed (bool), reason (string)
function M.commit_bound(boss_id, token)
	if type(boss_id) ~= "string" or boss_id == "" then
		return false, "bad_boss_id"
	end
	if type(token) ~= "string" or token == "" then
		return false, "bad_token"
	end
	local commits = commit_table()
	local prior = commits[token]
	if prior == boss_id then
		return false, "already_committed"
	end
	if prior ~= nil then
		return false, "token_used:" .. tostring(prior)
	end
	M.mark_encountered(boss_id)
	M.sync_stageapi_encountered(boss_id)
	commits[token] = boss_id
	return true, "ok"
end

function M.clear_encounters()
	local root = state.get()
	root[ENCOUNTER_KEY] = {}
	root[COMMIT_KEY] = {}
	return true
end

function M.list_encountered()
	local out = {}
	for id, v in pairs(encounter_table()) do
		if v then
			out[#out + 1] = id
		end
	end
	table.sort(out)
	return out
end

--- StageAPI-style partition: forced → unencountered → all valid.
--- candidates: array of {id=, weight=, forced=?}
--- rng: Isaac RNG with Next() returning float/int; uses RandomFloat if present.
--- Does NOT mark encounter.
function M.pick_prefer_unencountered(candidates, rng)
	if type(candidates) ~= "table" or #candidates == 0 then
		return nil, "empty_candidates"
	end
	local forced = {}
	local unencountered = {}
	local valid = {}
	for i = 1, #candidates do
		local c = candidates[i]
		if type(c) == "table" and type(c.id) == "string" then
			local w = tonumber(c.weight) or 0
			if w > 0 then
				valid[#valid + 1] = c
				if c.forced then
					forced[#forced + 1] = c
				elseif not M.is_encountered(c.id) then
					unencountered[#unencountered + 1] = c
				end
			end
		end
	end
	local pool = forced
	local mode = "forced"
	if #pool == 0 then
		pool = unencountered
		mode = "unencountered"
	end
	if #pool == 0 then
		pool = valid
		mode = "repeat_allowed"
	end
	if #pool == 0 then
		return nil, "no_positive_weight"
	end
	local total = 0
	for i = 1, #pool do
		total = total + (tonumber(pool[i].weight) or 0)
	end
	if total <= 0 then
		return nil, "zero_weight_pool"
	end
	local roll = 0
	if rng and rng.RandomFloat then
		roll = rng:RandomFloat() * total
	elseif rng and rng.Next then
		-- CollectibleRNG Next is uint; map into [0, total).
		roll = (rng:Next() % 1000000) / 1000000 * total
	else
		roll = 0
	end
	local acc = 0
	local chosen = pool[#pool]
	for i = 1, #pool do
		acc = acc + (tonumber(pool[i].weight) or 0)
		if roll <= acc then
			chosen = pool[i]
			break
		end
	end
	return chosen, mode
end

return M

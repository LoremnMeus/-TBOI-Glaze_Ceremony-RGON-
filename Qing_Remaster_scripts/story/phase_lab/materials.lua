-- Phase Lab materials: insert slots only. Never drives puzzle motion.

local defs = require("Qing_Remaster_scripts.story.phase_lab.defs")
local state = require("Qing_Remaster_scripts.story.phase_lab.state")
local story = require("Qing_Remaster_scripts.story.story_state")

local materials = {}

local function run()
	return state.get_run(true)
end

local function catalyst_available()
	local r = state.get_run(false)
	if r and r.debug_catalyst == true then return true end
	local ch = story.get_chapter("prologue", false)
	if ch and ch.status == story.STATUS.COMPLETED then return true end
	return false
end

local function has_token(def)
	if not def then return false end
	if def.catalyst then return catalyst_available() end
	if not def.token then return false end
	if story.has_token(def.token) then return true end
	if type(def.fallback_tokens) == "table" then
		for _, tok in ipairs(def.fallback_tokens) do
			if story.has_token(tok) then return true end
		end
	end
	return false
end

function materials.list()
	return defs.MATERIALS
end

function materials.is_inserted(key)
	local r = run()
	return r.materials[key] == true
end

function materials.has_inventory(key)
	local def = defs.MATERIALS[key]
	return has_token(def)
end

function materials.can_insert(key)
	if materials.is_inserted(key) then return false end
	return materials.has_inventory(key)
end

function materials.insert(key)
	if not defs.MATERIALS[key] then return false, "bad_key" end
	if materials.is_inserted(key) then return false, "already" end
	if not materials.has_inventory(key) then return false, "missing" end
	local r = run()
	r.materials[key] = true
	return true
end

function materials.clear_all()
	local r = run()
	for key, _ in pairs(defs.MATERIALS) do
		r.materials[key] = false
	end
end

function materials.set_all(on)
	local r = run()
	for key, _ in pairs(defs.MATERIALS) do
		r.materials[key] = on == true
	end
end

function materials.set_one(key, on)
	if not defs.MATERIALS[key] then return false end
	run().materials[key] = on == true
	return true
end

function materials.property_count()
	local n = 0
	for _, key in ipairs({"property_1", "property_2", "property_3", "property_4"}) do
		if materials.is_inserted(key) then n = n + 1 end
	end
	return n
end

function materials.catalyst_inserted()
	return materials.is_inserted("catalyst")
end

function materials.is_complete()
	return materials.property_count() >= 4 and materials.catalyst_inserted()
end

function materials.count_summary()
	local n = materials.property_count()
	if materials.catalyst_inserted() then n = n + 1 end
	return n, 5
end

function materials.owned_summary()
	local n = 0
	for key, _ in pairs(defs.MATERIALS) do
		if materials.has_inventory(key) or materials.is_inserted(key) then
			n = n + 1
		end
	end
	return n, 5
end

--- Debug: grant missing property tokens; catalyst uses run.debug_catalyst.
function materials.debug_grant_all()
	local r = state.get_run(true)
	r.debug_catalyst = true
	for _, def in pairs(defs.MATERIALS) do
		if def.token and not story.has_token(def.token) then
			story.grant_token(def.token)
		end
	end
end

function materials.debug_grant_count(want)
	want = tonumber(want) or 0
	local r = state.get_run(true)
	local keys = {"property_1", "property_2", "property_3", "property_4", "catalyst"}
	r.debug_catalyst = want >= 5
	for i, key in ipairs(keys) do
		local def = defs.MATERIALS[key]
		if i <= want then
			if def and def.token and not story.has_token(def.token) then
				story.grant_token(def.token)
			end
			materials.set_one(key, false)
		end
	end
end

return materials

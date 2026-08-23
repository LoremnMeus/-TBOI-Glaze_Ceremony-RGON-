local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local runtime = {
	ToCall = {},
	myToCall = {},
	SCHEMA_VERSION = 1,
	PHASE = {
		ELIGIBLE = "eligible",
		ARMED = "armed",
		ACTIVE = "active",
		BOSS = "boss",
		REWARD = "reward",
		COMPLETED = "completed",
		ABORTED = "aborted",
	},
	registry = {},
	order = {},
}

local function get_run_root(create)
	if type(save.elses) ~= "table" then
		if not create then return nil end
		save.elses = {}
	end
	local root = save.elses.ThreadRuntime
	if type(root) ~= "table" and create then
		root = {
			schema_version = runtime.SCHEMA_VERSION,
			floor_epoch = 0,
			active = {},
			completed = {},
		}
		save.elses.ThreadRuntime = root
	end
	if type(root) == "table" then
		root.schema_version = root.schema_version or runtime.SCHEMA_VERSION
		root.floor_epoch = root.floor_epoch or 0
		root.active = root.active or {}
		root.completed = root.completed or {}
	end
	return root
end

local function call_hook(definition, hook, ...)
	local fn = definition and definition[hook]
	if type(fn) ~= "function" then return true end
	local ok, result = pcall(fn, definition, ...)
	if not ok then
		print("[Qing ThreadRuntime] "..tostring(definition.id).."."..hook.." failed: "..tostring(result))
		return false, result
	end
	return true, result
end

function runtime.register(definition)
	assert(type(definition) == "table", "thread definition must be a table")
	assert(type(definition.id) == "string" and definition.id ~= "", "thread definition requires id")
	local previous = runtime.registry[definition.id]
	if previous then
		if previous.module == definition.module then return previous end
		error("duplicate thread id: "..definition.id)
	end
	definition.version = definition.version or 1
	definition.enabled = definition.enabled ~= false
	runtime.registry[definition.id] = definition
	runtime.order[#runtime.order + 1] = definition.id
	return definition
end

function runtime.get_definition(id)
	return runtime.registry[id]
end

function runtime.get_state(id, create)
	local root = get_run_root(create)
	if not root then return nil end
	local state = root.active[id]
	if type(state) ~= "table" and create then
		state = {phase = runtime.PHASE.ELIGIBLE, epoch = 0}
		root.active[id] = state
	end
	return state
end

function runtime.begin(id, phase, data)
	local definition = assert(runtime.registry[id], "unknown thread id: "..tostring(id))
	local root = get_run_root(true)
	local previous = root.active[id]
	local epoch = ((previous and previous.epoch) or 0) + 1
	local state = type(data) == "table" and data or {}
	state.phase = phase or runtime.PHASE.ARMED
	state.epoch = epoch
	state.definition_version = definition.version
	state.floor_epoch = root.floor_epoch
	root.active[id] = state
	call_hook(definition, "on_start", state)
	return state
end

function runtime.transition(id, phase, patch)
	local state = runtime.get_state(id, true)
	local previous = state.phase
	if type(patch) == "table" then
		for key, value in pairs(patch) do state[key] = value end
	end
	state.phase = phase
	local definition = runtime.registry[id]
	call_hook(definition, "on_transition", state, previous, phase)
	return state
end

function runtime.abort(id, reason)
	local root = get_run_root(false)
	local state = root and root.active[id]
	if not state then return false end
	state.abort_reason = reason or "unspecified"
	state.phase = runtime.PHASE.ABORTED
	call_hook(runtime.registry[id], "on_abort", state, state.abort_reason)
	root.active[id] = nil
	return true
end

function runtime.complete(id, payload)
	local root = get_run_root(true)
	local state = root.active[id] or {epoch = 0}
	state.phase = runtime.PHASE.COMPLETED
	state.completed_frame = Game():GetFrameCount()
	if type(payload) == "table" then
		for key, value in pairs(payload) do state[key] = value end
	end
	call_hook(runtime.registry[id], "on_complete", state)
	root.completed[id] = {
		epoch = state.epoch,
		definition_version = (runtime.registry[id] or {}).version,
		completed_frame = state.completed_frame,
	}
	root.active[id] = nil
	return true
end

function runtime.get_room_identity(desc)
	desc = desc or Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return nil end
	local dimension = -1
	if REPENTOGON then
		local ok, value = pcall(function() return desc:GetDimension() end)
		if ok and type(value) == "number" then dimension = value end
	end
	return {
		list_index = desc.ListIndex,
		safe_grid_index = desc.SafeGridIndex,
		dimension = dimension,
		room_type = desc.Data and desc.Data.Type or nil,
		variant = desc.Data and desc.Data.Variant or nil,
	}
end

function runtime.get_audit_snapshot()
	local root = get_run_root(false) or {}
	local entries = {}
	for _, id in ipairs(runtime.order) do
		local definition = runtime.registry[id]
		local state = root.active and root.active[id] or nil
		entries[#entries + 1] = {
			id = id,
			enabled = definition.enabled,
			version = definition.version,
			scope = definition.scope,
			phase = state and state.phase or nil,
			epoch = state and state.epoch or nil,
		}
	end
	return {
		schema_version = root.schema_version or runtime.SCHEMA_VERSION,
		floor_epoch = root.floor_epoch or 0,
		room = runtime.get_room_identity(),
		entries = entries,
	}
end

table.insert(runtime.myToCall, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	priority = 90,
	Function = function(_, continued)
		if not continued then save.elses.ThreadRuntime = nil end
		local root = get_run_root(true)
		for id, state in pairs(root.active) do
			local definition = runtime.registry[id]
			if not definition or not definition.enabled then
				root.active[id] = nil
			else
				call_hook(definition, "recover", state, continued)
			end
		end
	end,
})

table.insert(runtime.myToCall, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	priority = 90,
	Function = function()
		local root = get_run_root(true)
		root.floor_epoch = root.floor_epoch + 1
		for id, state in pairs(root.active) do
			local definition = runtime.registry[id]
			if definition and definition.scope == "floor" and state.floor_epoch ~= root.floor_epoch then
				runtime.abort(id, "new_level")
			end
		end
	end,
})

return runtime

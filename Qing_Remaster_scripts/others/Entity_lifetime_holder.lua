-- Entity Lifetime Helper：仅封装 RGON EntitySaveStateManager，分配/读取 token。
-- 另提供受控 namespace 读写（Unique generation 等）；不保存 Consistance payload。
-- Docs: Docs/docs_RGON/docs/EntitySaveStateManager.md

local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	own_key = "Entity_lifetime_holder_",
	debug = {
		api_errors = 0,
		last_error = nil,
		gets = 0,
		creates = 0,
		hits = 0,
		unavailable = 0,
		unsupported = 0,
		last_token = nil,
		last_is_new = nil,
	},
}

local DATA_KEY = "QingEntityLifetime"
local NEXT_KEY = "EntityLifetimeNext"

item.DATA_KEY = DATA_KEY

local function note_error(msg)
	item.debug.api_errors = (item.debug.api_errors or 0) + 1
	item.debug.last_error = tostring(msg)
end

function item.is_available()
	if not REPENTOGON then return false end
	if EntitySaveStateManager == nil then return false end
	if type(EntitySaveStateManager.GetEntityData) ~= "function" then return false end
	if g.MODREFERENCE == nil then return false end
	return true
end

local function ensure_next()
	save.elses = save.elses or {}
	local n = tonumber(save.elses[NEXT_KEY]) or 0
	n = n + 1
	save.elses[NEXT_KEY] = n
	return n
end

--- create=true → GetEntityData；create=false → 仅 TryGet（无 API 则 unsupported，禁止 fallback create）。
local function read_bucket(ent, create)
	if not item.is_available() then
		item.debug.unavailable = (item.debug.unavailable or 0) + 1
		return nil, false, "unavailable"
	end
	if ent == nil then
		note_error("nil entity")
		return nil, false, "nil_entity"
	end
	local mod = g.MODREFERENCE
	local ok, packed
	if create then
		ok, packed = pcall(function()
			local d, ex = EntitySaveStateManager.GetEntityData(mod, ent)
			return { data = d, existed = ex == true }
		end)
	else
		if type(EntitySaveStateManager.TryGetEntityData) ~= "function" then
			item.debug.unsupported = (item.debug.unsupported or 0) + 1
			return nil, false, "unsupported"
		end
		ok, packed = pcall(function()
			local d = EntitySaveStateManager.TryGetEntityData(mod, ent)
			return { data = d, existed = d ~= nil }
		end)
	end
	if not ok then
		note_error(packed)
		return nil, false, "api_error"
	end
	if type(packed) ~= "table" then
		return nil, false, "bad_pack"
	end
	return packed.data, packed.existed == true, nil
end

--- 原始 ESSM data 桶：try 永不 create。
function item.try_get_data(ent)
	local data, existed, err = read_bucket(ent, false)
	if not data then return nil, err end
	return data, existed
end

--- 原始 ESSM data 桶：必要时 GetEntityData create。
function item.get_or_create_data(ent)
	item.debug.gets = (item.debug.gets or 0) + 1
	local data, existed, err = read_bucket(ent, true)
	if not data then return nil, err end
	if existed then
		item.debug.hits = (item.debug.hits or 0) + 1
	else
		item.debug.creates = (item.debug.creates or 0) + 1
	end
	return data, existed
end

--- 从 EntitySaveState 只读整个 data 桶；无 TryGet API 则 unsupported（禁止 GetEntitySaveStateData fallback）。
function item.try_get_data_from_save_state(save_state)
	if not item.is_available() then
		item.debug.unavailable = (item.debug.unavailable or 0) + 1
		return nil, "unavailable"
	end
	if save_state == nil then return nil, "nil_save_state" end
	if type(EntitySaveStateManager.TryGetEntitySaveStateData) ~= "function" then
		item.debug.unsupported = (item.debug.unsupported or 0) + 1
		return nil, "unsupported"
	end
	local mod = g.MODREFERENCE
	local ok, data = pcall(function()
		return EntitySaveStateManager.TryGetEntitySaveStateData(mod, save_state)
	end)
	if not ok then
		note_error(data)
		return nil, "api_error"
	end
	if type(data) ~= "table" then return nil, "missing" end
	return data
end

--- 只读 namespace；不存在则 nil。永不 create。
function item.read_namespace(ent, key)
	if type(key) ~= "string" or key == "" then return nil, "bad_key" end
	local data, err = item.try_get_data(ent)
	if not data then return nil, err end
	local ns = data[key]
	if type(ns) ~= "table" then return nil, "missing" end
	return ns
end

--- 确保 namespace 表存在（会 GetEntityData）。返回 namespace table。
function item.ensure_namespace(ent, key)
	if type(key) ~= "string" or key == "" then return nil, "bad_key" end
	local data, err = item.get_or_create_data(ent)
	if not data then return nil, err or "no_data" end
	local ns = data[key]
	if type(ns) ~= "table" then
		ns = {}
		data[key] = ns
	end
	return ns
end

--- 从 save-state 只读 namespace；永不 create。
function item.read_namespace_from_save_state(save_state, key)
	if type(key) ~= "string" or key == "" then return nil, "bad_key" end
	local data, err = item.try_get_data_from_save_state(save_state)
	if not data then return nil, err end
	local ns = data[key]
	if type(ns) ~= "table" then return nil, "missing" end
	return ns
end

--- @return {token:number, is_new:boolean, state:table}|nil, err?
function item.get_or_create(ent)
	item.debug.gets = (item.debug.gets or 0) + 1
	local data, _existed, err = read_bucket(ent, true)
	if not data then
		return nil, err or "no_data"
	end
	local state = data[DATA_KEY]
	if type(state) ~= "table" or state.token == nil then
		local token = ensure_next()
		state = { seen = true, token = token }
		data[DATA_KEY] = state
		item.debug.creates = (item.debug.creates or 0) + 1
		item.debug.last_token = token
		item.debug.last_is_new = true
		return { token = token, is_new = true, state = state }
	end
	item.debug.hits = (item.debug.hits or 0) + 1
	item.debug.last_token = state.token
	item.debug.last_is_new = false
	return { token = state.token, is_new = false, state = state }
end

--- 显式创建/确保 token（会写 ESSM）。
function item.ensure_token(ent)
	local info, err = item.get_or_create(ent)
	return info and info.token or nil, err
end

--- 已有 token 才返回；不分配。
function item.try_get(ent)
	local data, _, err = read_bucket(ent, false)
	if not data then return nil, err end
	local state = data[DATA_KEY]
	if type(state) ~= "table" or state.token == nil then
		return nil, "missing"
	end
	return { token = state.token, is_new = false, state = state }
end

--- 从 EntitiesSaveState 只读 lifetime；无 TryGet API 则 unsupported（禁止 GetEntitySaveStateData fallback）。
function item.try_get_from_save_state(save_state)
	local data, err = item.try_get_data_from_save_state(save_state)
	if not data then return nil, err end
	local state = data[DATA_KEY]
	if type(state) ~= "table" or state.token == nil then
		return nil, "missing"
	end
	return { token = state.token, is_new = false, state = state, data = data }
end

--- Prepare / 探针：显式写入指定 token（会 GetEntityData，仅调试路径）。
function item.write_token(ent, token)
	token = tonumber(token)
	if not ent or token == nil then return nil, "bad_args" end
	local data, _, err = read_bucket(ent, true)
	if not data then return nil, err or "no_data" end
	local state = { seen = true, token = token }
	data[DATA_KEY] = state
	item.debug.last_token = token
	item.debug.last_is_new = false
	return { token = token, is_new = false, state = state }
end

--- 纯读：不 create。
function item.get_token(ent)
	local info = item.try_get(ent)
	return info and info.token or nil
end

function item.reset_debug()
	item.debug.api_errors = 0
	item.debug.last_error = nil
	item.debug.gets = 0
	item.debug.creates = 0
	item.debug.hits = 0
	item.debug.unavailable = 0
	item.debug.unsupported = 0
	item.debug.last_token = nil
	item.debug.last_is_new = nil
end

function item.get_debug_snapshot()
	return {
		available = item.is_available() == true,
		repentogon = REPENTOGON == true,
		api_errors = item.debug.api_errors or 0,
		last_error = item.debug.last_error,
		gets = item.debug.gets or 0,
		creates = item.debug.creates or 0,
		hits = item.debug.hits or 0,
		unavailable = item.debug.unavailable or 0,
		unsupported = item.debug.unsupported or 0,
		last_token = item.debug.last_token,
		last_is_new = item.debug.last_is_new,
		next_token = save.elses and save.elses[NEXT_KEY] or 0,
	}
end

table.insert(item.pre_myToCall, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		item.reset_debug()
	end,
})

return item

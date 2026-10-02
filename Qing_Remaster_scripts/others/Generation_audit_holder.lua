-- Generation Audit Holder：业务 epoch 内「是否见过某个 Unique generation id」。
-- Unique 只提供 generation；Empress / Live Broadcast 等用本模块做 effect-epoch-first。
-- Audit key 必须是 generation id，禁止 Ptr / SubType / ESSM token / 裸 InitSeed。

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local TRACE_CAP = 32
local STORE_KEY = "_QingGenerationAudit"

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Generation_audit_holder_",
	_trace = {},
	debug = {
		by_owner = {},
	},
}

local function store()
	save.elses = save.elses or {}
	save.elses[STORE_KEY] = save.elses[STORE_KEY] or {}
	return save.elses[STORE_KEY]
end

local function owner_bucket(owner)
	owner = tostring(owner or "")
	local root = store()
	if type(root[owner]) ~= "table" then
		root[owner] = {
			epoch = 0,
			active = false,
			seen = {},
		}
	end
	root[owner].seen = root[owner].seen or {}
	return root[owner], owner
end

local function owner_debug(owner)
	owner = tostring(owner or "")
	local d = item.debug.by_owner[owner]
	if type(d) ~= "table" then
		d = {
			epoch = 0,
			active = false,
			seen_count = 0,
			first_hits = 0,
			duplicate_blocks = 0,
			d6_new_hits = 0,
			cycle_blocks = 0,
			restore_blocks = 0,
			new_spawn_hits = 0,
		}
		item.debug.by_owner[owner] = d
	end
	return d
end

local function push_trace(row)
	local t = item._trace
	t[#t + 1] = row
	while #t > TRACE_CAP do
		table.remove(t, 1)
	end
end

local function classify_source(source)
	source = tostring(source or "")
	if source == "morph_replacement" or source == "d6" or source == "D6_REPLACEMENT" then
		return "D6_REPLACEMENT"
	end
	if source == "morph_same_seed" or source == "existing_marker" or source == "CYCLE" then
		return "CYCLE"
	end
	if source == "restore_registry" or source == "RESTORED" then
		return "RESTORE"
	end
	if source == "midroom_new" or source == "first_visit_new" or source == "NEW_SPAWN" then
		return "NEW_SPAWN"
	end
	if source == "epoch_scan" then
		return "EPOCH_SCAN"
	end
	return source ~= "" and source or "UNKNOWN"
end

function item.begin_epoch(owner)
	local bucket, key = owner_bucket(owner)
	bucket.epoch = (tonumber(bucket.epoch) or 0) + 1
	bucket.active = true
	bucket.seen = {}
	local dbg = owner_debug(key)
	dbg.epoch = bucket.epoch
	dbg.active = true
	dbg.seen_count = 0
	push_trace({
		owner = key,
		epoch = bucket.epoch,
		generation = nil,
		event = "EPOCH_BEGIN",
		source = "begin_epoch",
	})
	return bucket.epoch
end

function item.end_epoch(owner)
	local bucket, key = owner_bucket(owner)
	bucket.active = false
	local dbg = owner_debug(key)
	dbg.active = false
	push_trace({
		owner = key,
		epoch = bucket.epoch,
		generation = nil,
		event = "EPOCH_END",
		source = "end_epoch",
	})
end

function item.get_epoch(owner)
	local bucket = owner_bucket(owner)
	return bucket.epoch
end

function item.is_active(owner)
	local bucket = owner_bucket(owner)
	return bucket.active == true and (tonumber(bucket.epoch) or 0) > 0
end

function item.has_seen(owner, generation_id)
	generation_id = tonumber(generation_id)
	if generation_id == nil then return false end
	local bucket = owner_bucket(owner)
	return bucket.seen[tostring(generation_id)] == true
end

function item.mark_seen(owner, generation_id)
	generation_id = tonumber(generation_id)
	if generation_id == nil then return end
	local bucket, key = owner_bucket(owner)
	local sk = tostring(generation_id)
	if bucket.seen[sk] ~= true then
		bucket.seen[sk] = true
		local dbg = owner_debug(key)
		dbg.seen_count = (dbg.seen_count or 0) + 1
	end
end

--- @return boolean true = 本 epoch 第一次遇见该 generation
function item.check_and_mark(owner, generation_id, opts)
	opts = opts or {}
	generation_id = tonumber(generation_id)
	local bucket, key = owner_bucket(owner)
	local dbg = owner_debug(key)
	dbg.epoch = bucket.epoch
	dbg.active = bucket.active == true
	if generation_id == nil then
		return false
	end
	if bucket.active ~= true then
		return false
	end
	local sk = tostring(generation_id)
	local src = classify_source(opts.source)
	if bucket.seen[sk] == true then
		dbg.duplicate_blocks = (dbg.duplicate_blocks or 0) + 1
		if src == "CYCLE" then
			dbg.cycle_blocks = (dbg.cycle_blocks or 0) + 1
		elseif src == "RESTORE" then
			dbg.restore_blocks = (dbg.restore_blocks or 0) + 1
		end
		push_trace({
			owner = key,
			epoch = bucket.epoch,
			generation = generation_id,
			event = "DUPLICATE_BLOCK",
			source = src,
		})
		return false
	end
	bucket.seen[sk] = true
	dbg.seen_count = (dbg.seen_count or 0) + 1
	dbg.first_hits = (dbg.first_hits or 0) + 1
	if src == "D6_REPLACEMENT" then
		dbg.d6_new_hits = (dbg.d6_new_hits or 0) + 1
	elseif src == "NEW_SPAWN" then
		dbg.new_spawn_hits = (dbg.new_spawn_hits or 0) + 1
	elseif src == "RESTORE" then
		-- first see of restored in new epoch still counts as first_hit
	end
	push_trace({
		owner = key,
		epoch = bucket.epoch,
		generation = generation_id,
		event = "FIRST_SEEN",
		source = src,
	})
	return true
end

function item.reset_owner(owner)
	local root = store()
	local key = tostring(owner or "")
	root[key] = {
		epoch = 0,
		active = false,
		seen = {},
	}
	item.debug.by_owner[key] = nil
end

function item.reset_all()
	save.elses = save.elses or {}
	save.elses[STORE_KEY] = {}
	item.debug.by_owner = {}
	item._trace = {}
end

function item.get_trace()
	local out = {}
	for i = 1, #item._trace do
		out[i] = item._trace[i]
	end
	return out
end

function item.get_owner_snapshot(owner)
	local bucket, key = owner_bucket(owner)
	local dbg = owner_debug(key)
	local seen_n = 0
	for _ in pairs(bucket.seen or {}) do
		seen_n = seen_n + 1
	end
	return {
		owner = key,
		epoch = bucket.epoch,
		active = bucket.active == true,
		seen_count = seen_n,
		first_hits = dbg.first_hits or 0,
		duplicate_blocks = dbg.duplicate_blocks or 0,
		d6_new_hits = dbg.d6_new_hits or 0,
		cycle_blocks = dbg.cycle_blocks or 0,
		restore_blocks = dbg.restore_blocks or 0,
		new_spawn_hits = dbg.new_spawn_hits or 0,
	}
end

function item.get_debug_snapshot()
	local owners = {}
	for name in pairs(store()) do
		owners[#owners + 1] = item.get_owner_snapshot(name)
	end
	table.sort(owners, function(a, b)
		return tostring(a.owner) < tostring(b.owner)
	end)
	return {
		owners = owners,
		trace = item.get_trace(),
		empress = item.get_owner_snapshot("Empress"),
		live_broadcast = item.get_owner_snapshot("LiveBroadcast"),
	}
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		if not continue then
			item.reset_all()
		else
			-- continue：保留 save 中的 epoch/seen；刷新 debug 计数显示
			for name, bucket in pairs(store()) do
				local dbg = owner_debug(name)
				dbg.epoch = bucket.epoch
				dbg.active = bucket.active == true
				local n = 0
				for _ in pairs(bucket.seen or {}) do
					n = n + 1
				end
				dbg.seen_count = n
			end
		end
	end,
})

return item

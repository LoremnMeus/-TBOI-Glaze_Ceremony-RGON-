-- 里小青控制带宽：容量/单机成本/编队顺序/启动态的唯一查询入口。
-- 内部半格整数：基础容量 3 → 6 units，基础飞行器 1 → 2 units。
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	own_key = "Craft_Bandwidth_",
	UNIT_PER_SLOT = 2,
	BASE_CAPACITY_SLOTS = 3,
	BASE_CRAFT_SLOTS = 1,
	FORMATION_CRUISE = 0,
	FORMATION_GUARD = 1,
	FIRE_AUTO = 0,
	FIRE_FORCE = 1,
	-- 模块附加带宽注册表；第一版保持为空。
	MODULE_BANDWIDTH = {},
}

local function get_bp()
	return require("Qing_Remaster_scripts.items.Item_Blue_Print")
end

local function get_spwq()
	return require("Qing_Remaster_scripts.player.player_Spwq")
end

local function player_key(player)
	if not player then return "0" end
	local ok, key = pcall(function()
		local data = player:GetData()
		return data.__Index or player.InitSeed
	end)
	return (ok and key ~= nil) and tostring(key) or "0"
end

local function checkpoint(reason)
	if save.RuntimeLoaded ~= true or type(save.SaveModData) ~= "function" then return end
	pcall(save.SaveModData, "bandwidth:"..tostring(reason or "unknown"))
end

local function ensure_root()
	save.elses = save.elses or {}
	local root = save.elses.Qing_Craft_Bandwidth
	if type(root) ~= "table" then
		root = {by_player = {}}
		save.elses.Qing_Craft_Bandwidth = root
	end
	root.by_player = root.by_player or {}
	return root
end

local function get_bucket(player)
	local root = ensure_root()
	local key = player_key(player)
	local bucket = root.by_player[key]
	if type(bucket) ~= "table" then
		bucket = {
			formation_order = {},
			wanted_active = {},
			control = {
				formation_mode = item.FORMATION_CRUISE,
				fire_control_mode = item.FIRE_AUTO,
				last_aim_x = 0,
				last_aim_y = 1,
				migrated_focus = false,
			},
		}
		root.by_player[key] = bucket
	end
	bucket.formation_order = bucket.formation_order or {}
	bucket.wanted_active = bucket.wanted_active or {}
	bucket.effective_active = bucket.effective_active or {}
	bucket.control = bucket.control or {}
	return bucket
end

local function uid_key(uid)
	if uid == nil then return nil end
	return tostring(uid)
end

local function is_spwq(player)
	return player and player:GetPlayerType() == enums.Players.Spwq
end

local function list_craft_store(player)
	local bp = get_bp()
	if not bp or not bp.get_craft_store then return {} end
	return bp.get_craft_store(player) or {}
end

local function build_rec_index(player)
	local rec_by_uid = {}
	local live = {}
	for _, rec in ipairs(list_craft_store(player)) do
		if rec and rec.uid ~= nil then
			local k = uid_key(rec.uid)
			rec_by_uid[k] = rec
			live[#live + 1] = rec.uid
		end
	end
	return rec_by_uid, live
end

local function find_rec(player, uid)
	if uid == nil then return nil end
	local k = uid_key(uid)
	for _, rec in ipairs(list_craft_store(player)) do
		if rec and uid_key(rec.uid) == k then return rec end
	end
end

--- 单机内部单位。第一版忽略模块表（空注册表）。
function item.get_craft_cost_units(player, rec)
	if type(rec) ~= "table" then rec = find_rec(player, rec) end
	if type(rec) ~= "table" then return item.BASE_CRAFT_SLOTS * item.UNIT_PER_SLOT end
	local extra = 0
	local extras = rec.profile and rec.profile.extras
	if type(extras) == "table" then
		for key, on in pairs(extras) do
			if on and item.MODULE_BANDWIDTH[key] then
				extra = extra + (tonumber(item.MODULE_BANDWIDTH[key]) or 0)
			end
		end
	end
	return item.BASE_CRAFT_SLOTS * item.UNIT_PER_SLOT + extra
end

function item.get_craft_cost(player, rec)
	return item.get_craft_cost_units(player, rec)
end

local function tutorial_capacity_bonus(player)
	local bonus = 0
	local ok, tut = pcall(require, "Qing_Remaster_scripts.others.blueprint_tutorial")
	if ok and tut and tut.extra_capacity_slots then
		bonus = tonumber(tut.extra_capacity_slots(player)) or 0
	end
	if bonus < 0 then bonus = 0 end
	return bonus
end

function item.get_capacity_units(player)
	local cap = item.BASE_CAPACITY_SLOTS * item.UNIT_PER_SLOT
	local bonus = tutorial_capacity_bonus(player)
	if bonus > 0 then
		cap = cap + bonus * item.UNIT_PER_SLOT
	end
	return cap
end

function item.get_capacity(player)
	return item.get_capacity_units(player)
end

local function sync_order(player, bucket, live)
	live = live or select(2, build_rec_index(player))
	local have = {}
	for i = 1, #live do
		have[uid_key(live[i])] = true
	end
	local order = {}
	local seen = {}
	for i = 1, #(bucket.formation_order or {}) do
		local uid = bucket.formation_order[i]
		local k = uid_key(uid)
		if k and have[k] and not seen[k] then
			order[#order + 1] = uid
			seen[k] = true
		end
	end
	for i = 1, #live do
		local uid = live[i]
		local k = uid_key(uid)
		if k and not seen[k] then
			order[#order + 1] = uid
			seen[k] = true
			if bucket.wanted_active[k] == nil then
				bucket.wanted_active[k] = true
			end
		end
	end
	for k in pairs(bucket.wanted_active) do
		if not have[tostring(k)] then
			bucket.wanted_active[k] = nil
		end
	end
	bucket.formation_order = order
	return order
end

local SNAP = {}
local SNAP_VER = {}

local function copy_list(src)
	local t = {}
	for i = 1, #(src or {}) do
		t[i] = src[i]
	end
	return t
end

local function copy_bool_map(src)
	local t = {}
	for k, v in pairs(src or {}) do
		t[tostring(k)] = v == true
	end
	return t
end

local function empty_snapshot(frame)
	local cap = item.BASE_CAPACITY_SLOTS * item.UNIT_PER_SLOT
	return {
		version = 0,
		frame = frame or 0,
		order = {},
		rec_by_uid = {},
		effective_active = {},
		wanted_active = {},
		active = {},
		standby = {},
		used_units = 0,
		capacity_units = cap,
		used_slots = 0,
		capacity_slots = item.BASE_CAPACITY_SLOTS,
	}
end

function item.persist_player_key(player)
	if not player then return nil end
	local ok, idx = pcall(function()
		return player:GetData().__Index
	end)
	if ok and idx ~= nil then return tostring(idx) end
	return nil
end

function item.mark_dirty(player, _reason)
	local k = player_key(player)
	SNAP_VER[k] = (SNAP_VER[k] or 0) + 1
	local row = SNAP[k]
	if row then row.dirty = true end
end

function item.clear_snapshot_cache()
	SNAP = {}
	SNAP_VER = {}
end

local function build_snapshot(player)
	local bucket = get_bucket(player)
	local rec_by_uid, live = build_rec_index(player)
	local order = sync_order(player, bucket, live)
	local effective = {}
	local active = {}
	local standby = {}
	local cap = item.get_capacity_units(player)
	local used = 0
	local spwq = is_spwq(player)
	for i = 1, #order do
		local uid = order[i]
		local k = uid_key(uid)
		local rec = rec_by_uid[k]
		if not spwq then
			effective[k] = true
			active[#active + 1] = uid
			used = used + item.get_craft_cost_units(player, rec)
		else
			local cost = item.get_craft_cost_units(player, rec)
			local want = bucket.wanted_active[k]
			if want == nil then want = true end
			-- 超容量只影响 effective，不得改写 wanted（Render 只读）。
			if want == true and used + cost <= cap then
				effective[k] = true
				active[#active + 1] = uid
				used = used + cost
			else
				effective[k] = false
				standby[#standby + 1] = uid
			end
		end
	end
	bucket.effective_active = effective
	local frame = Game():GetFrameCount()
	return {
		version = SNAP_VER[player_key(player)] or 0,
		frame = frame,
		order = copy_list(order),
		rec_by_uid = rec_by_uid,
		effective_active = copy_bool_map(effective),
		wanted_active = copy_bool_map(bucket.wanted_active),
		active = active,
		standby = standby,
		used_units = used,
		capacity_units = cap,
		used_slots = used / item.UNIT_PER_SLOT,
		capacity_slots = cap / item.UNIT_PER_SLOT,
	}
end

function item.get_snapshot(player)
	if not player then return empty_snapshot() end
	local k = player_key(player)
	local frame = Game():GetFrameCount()
	local cap_bonus = tutorial_capacity_bonus(player)
	local ver = SNAP_VER[k] or 0
	local row = SNAP[k]
	if row and row.dirty ~= true and row.ver == ver and row.cap_bonus == cap_bonus then
		return row.snap
	end
	local snap = build_snapshot(player)
	SNAP[k] = {
		ver = ver,
		frame = frame,
		cap_bonus = cap_bonus,
		dirty = false,
		snap = snap,
	}
	return snap
end

function item.reconcile(player)
	if not player then return get_bucket(player) end
	item.get_snapshot(player)
	return get_bucket(player)
end

function item.is_active(player, craft_uid)
	if not player or craft_uid == nil then return true end
	if not is_spwq(player) then return true end
	local snap = item.get_snapshot(player)
	return snap.effective_active[uid_key(craft_uid)] == true
end

function item.set_active(player, craft_uid, enabled)
	if not player or craft_uid == nil then return false end
	local snap = item.get_snapshot(player)
	local k = uid_key(craft_uid)
	enabled = enabled == true
	if enabled then
		local rec = snap.rec_by_uid[k]
		local cost = item.get_craft_cost_units(player, rec)
		local used = snap.used_units or 0
		if snap.effective_active[k] == true then
			used = used - cost
		end
		if used + cost > (snap.capacity_units or 0) then
			return false
		end
	end
	local bucket = get_bucket(player)
	bucket.wanted_active[k] = enabled
	item.mark_dirty(player, enabled and "activate" or "standby")
	snap = item.get_snapshot(player)
	checkpoint(enabled and "activate" or "standby")
	return snap.effective_active[k] == enabled
end

function item.apply_wanted_batch(player, changes, reason)
	if not player or type(changes) ~= "table" then return false end
	local bucket = get_bucket(player)
	for key, enabled in pairs(changes) do
		if key ~= nil then
			bucket.wanted_active[uid_key(key)] = enabled == true
		end
	end
	item.mark_dirty(player, reason or "wanted_batch")
	item.get_snapshot(player)
	checkpoint(reason or "wanted_batch")
	return true
end

function item.move_order(player, craft_uid, delta)
	if not player or craft_uid == nil then return false end
	delta = tonumber(delta) or 0
	if delta == 0 then return false end
	item.get_snapshot(player)
	local bucket = get_bucket(player)
	local order = bucket.formation_order
	local idx
	local k = uid_key(craft_uid)
	for i = 1, #order do
		if uid_key(order[i]) == k then
			idx = i
			break
		end
	end
	if not idx then return false end
	local dest = idx + delta
	if dest < 1 or dest > #order then return false end
	order[idx], order[dest] = order[dest], order[idx]
	item.mark_dirty(player, "reorder")
	item.get_snapshot(player)
	checkpoint("reorder")
	return true
end

--- 将飞行器放到当前激活队列的第 active_index 位（1-based）。先尝试启动。
function item.place_as_active(player, craft_uid, active_index)
	if not player or craft_uid == nil then return false end
	if not item.set_active(player, craft_uid, true) then
		return false
	end
	local snap = item.get_snapshot(player)
	local bucket = get_bucket(player)
	local order = bucket.formation_order or {}
	local k = uid_key(craft_uid)
	local without = {}
	for i = 1, #order do
		if uid_key(order[i]) ~= k then
			without[#without + 1] = order[i]
		end
	end
	local actives = 0
	for i = 1, #without do
		if snap.effective_active[uid_key(without[i])] == true then
			actives = actives + 1
		end
	end
	active_index = math.floor(tonumber(active_index) or (actives + 1))
	active_index = math.max(1, math.min(actives + 1, active_index))
	local seen = 0
	local insert_at = #without + 1
	for i = 1, #without do
		if snap.effective_active[uid_key(without[i])] == true then
			seen = seen + 1
			if seen == active_index then
				insert_at = i
				break
			end
		end
	end
	table.insert(without, insert_at, craft_uid)
	bucket.formation_order = without
	item.mark_dirty(player, "place_active")
	snap = item.get_snapshot(player)
	checkpoint("place_active")
	return snap.effective_active[k] == true
end

function item.get_order(player)
	return copy_list(item.get_snapshot(player).order)
end

function item.get_summary(player)
	local snap = item.get_snapshot(player)
	return {
		used_units = snap.used_units,
		capacity_units = snap.capacity_units,
		used_slots = snap.used_slots,
		capacity_slots = snap.capacity_slots,
		active = #(snap.active or {}),
		standby = #(snap.standby or {}),
	}
end

local function clamp_mode(v, a, b)
	v = math.floor(tonumber(v) or a)
	if v < a then return a end
	if v > b then return b end
	return v
end

local function migrate_focus_once(player, ctrl)
	if ctrl.migrated_focus == true then return end
	local Spwq = get_spwq()
	local focus
	if player and Spwq then
		local ok, v = pcall(function()
			return player:GetData()[Spwq.own_key.."Focus"]
		end)
		if ok then focus = tonumber(v) end
	end
	if focus == 1 then
		ctrl.formation_mode = item.FORMATION_GUARD
		ctrl.fire_control_mode = item.FIRE_AUTO
	elseif focus == 2 then
		ctrl.formation_mode = item.FORMATION_CRUISE
		ctrl.fire_control_mode = item.FIRE_FORCE
	else
		ctrl.formation_mode = item.FORMATION_CRUISE
		ctrl.fire_control_mode = item.FIRE_AUTO
	end
	ctrl.migrated_focus = true
	checkpoint("migrate_focus")
end

function item.get_control(player)
	local bucket = get_bucket(player)
	local ctrl = bucket.control
	migrate_focus_once(player, ctrl)
	ctrl.formation_mode = clamp_mode(ctrl.formation_mode, item.FORMATION_CRUISE, item.FORMATION_GUARD)
	ctrl.fire_control_mode = clamp_mode(ctrl.fire_control_mode, item.FIRE_AUTO, item.FIRE_FORCE)
	local ax = tonumber(ctrl.last_aim_x) or 0
	local ay = tonumber(ctrl.last_aim_y) or 1
	if ax * ax + ay * ay < 0.0001 then
		ax, ay = 0, 1
	end
	local cache
	if player then
		local d = player:GetData()
		cache = d[item.own_key.."control"]
		if type(cache) ~= "table" then
			cache = {}
			d[item.own_key.."control"] = cache
		end
		cache.formation_mode = ctrl.formation_mode
		cache.fire_control_mode = ctrl.fire_control_mode
		if cache.last_aim and cache.last_aim.X then
			-- 运行时 Vector 优先；仅在尚未写入时从存档恢复
		else
			cache.last_aim = Vector(ax, ay)
		end
		return cache
	end
	return {
		formation_mode = ctrl.formation_mode,
		fire_control_mode = ctrl.fire_control_mode,
		last_aim = Vector(ax, ay),
	}
end

function item.save_control(player)
	if not player then return end
	local cache = player:GetData()[item.own_key.."control"]
	if type(cache) ~= "table" then return end
	local ctrl = get_bucket(player).control
	ctrl.formation_mode = clamp_mode(cache.formation_mode, item.FORMATION_CRUISE, item.FORMATION_GUARD)
	ctrl.fire_control_mode = clamp_mode(cache.fire_control_mode, item.FIRE_AUTO, item.FIRE_FORCE)
	local aim = cache.last_aim
	if aim and aim.X then
		local len2 = aim.X * aim.X + aim.Y * aim.Y
		if len2 > 0.0001 then
			local len = math.sqrt(len2)
			ctrl.last_aim_x = aim.X / len
			ctrl.last_aim_y = aim.Y / len
		end
	end
end

function item.set_formation_mode(player, mode)
	local cache = item.get_control(player)
	cache.formation_mode = clamp_mode(mode, item.FORMATION_CRUISE, item.FORMATION_GUARD)
	item.save_control(player)
	checkpoint("formation")
	return cache.formation_mode
end

function item.set_fire_control_mode(player, mode)
	local cache = item.get_control(player)
	cache.fire_control_mode = clamp_mode(mode, item.FIRE_AUTO, item.FIRE_FORCE)
	item.save_control(player)
	checkpoint("fire")
	return cache.fire_control_mode
end

function item.toggle_formation_mode(player)
	local cache = item.get_control(player)
	if cache.formation_mode == item.FORMATION_GUARD then
		return item.set_formation_mode(player, item.FORMATION_CRUISE)
	end
	return item.set_formation_mode(player, item.FORMATION_GUARD)
end

function item.toggle_fire_control_mode(player)
	local cache = item.get_control(player)
	if cache.fire_control_mode == item.FIRE_FORCE then
		return item.set_fire_control_mode(player, item.FIRE_AUTO)
	end
	return item.set_fire_control_mode(player, item.FIRE_FORCE)
end

function item.note_aim(player, vec)
	if not player or not vec then return end
	if vec:Length() < 0.05 then return end
	local cache = item.get_control(player)
	cache.last_aim = vec:Normalized()
end

function item.on_craft_added(player, uid)
	if not player or uid == nil then return end
	local bucket = get_bucket(player)
	bucket.wanted_active[uid_key(uid)] = true
	item.mark_dirty(player, "craft_add")
	item.get_snapshot(player)
	checkpoint("craft_add")
end

function item.on_craft_removed(player, uid)
	if not player then return end
	item.mark_dirty(player, "craft_del")
	item.get_snapshot(player)
	checkpoint("craft_del")
end

function item.on_craft_changed(player, _uid)
	if not player then return end
	item.mark_dirty(player, "craft_edit")
end

function item.ensure_reconcile(player)
	if not player then return end
	item.get_snapshot(player)
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		item.clear_snapshot_cache()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function()
		item.clear_snapshot_cache()
	end,
})

return item

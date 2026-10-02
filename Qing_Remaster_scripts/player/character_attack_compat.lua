-- 自定义角色攻击兼容的唯一注册入口。
-- 角色模块在自身加载完成时登记；宝宝/复制攻击系统只查询本表，禁止再维护平行角色名单。
-- Aeon 等消费者经 snapshot_attack / replay_attack 接入；禁止在 Card/aeon_replay 写角色名单。
local registry = {
	entries = {},
	advanced_supported = {},
	effects = {},
}

local PURE_DATA_MAX_DEPTH = 8

local function normalize_player_type(player_type)
	local value = tonumber(player_type)
	if value == nil then return nil end
	return value
end

local function shallow_merge(dst, src)
	for key, value in pairs(src or {}) do
		if key == "capabilities" and type(value) == "table" then
			dst.capabilities = dst.capabilities or {}
			for capability, enabled in pairs(value) do
				dst.capabilities[capability] = enabled
			end
		else
			dst[key] = value
		end
	end
	return dst
end

--- Recursive pure-data check for Aeon save / json.encode safety.
--- Allows nil/boolean/number/string/table (keys: string|number). Rejects userdata/function/thread.
function registry.validate_pure_data(value, max_depth)
	max_depth = tonumber(max_depth) or PURE_DATA_MAX_DEPTH
	local seen = {}
	local function walk(v, depth)
		if v == nil then return true end
		local t = type(v)
		if t == "boolean" or t == "number" or t == "string" then
			return true
		end
		if t == "function" or t == "thread" or t == "userdata" then
			return false, t
		end
		if t ~= "table" then
			return false, t
		end
		if depth > max_depth then
			return false, "max_depth"
		end
		if seen[v] then
			return false, "cycle"
		end
		seen[v] = true
		for key, child in pairs(v) do
			local kt = type(key)
			if kt ~= "string" and kt ~= "number" then
				return false, "bad_key:" .. kt
			end
			local ok, reason = walk(child, depth + 1)
			if not ok then
				return false, reason
			end
		end
		return true
	end
	return walk(value, 0)
end

--- def = {
---   key, module, advanced_familiars, familiar_attack,
---   snapshot_attack, replay_attack,
---   capture_replay_pose,
---   begin_replay_presentation, update_replay_presentation, end_replay_presentation,
---   capabilities = {projectile=true, volley=true, charge=true, aeon_replay=true, aeon_presentation=true, ...},
---   audit = "..."
--- }
function registry.register(player_type, def)
	player_type = normalize_player_type(player_type)
	if player_type == nil or type(def) ~= "table" then return nil end
	local entry = registry.entries[player_type] or {player_type = player_type, capabilities = {}}
	shallow_merge(entry, def)
	registry.entries[player_type] = entry
	registry.advanced_supported[player_type] = entry.advanced_familiars == true or nil
	return entry
end

--- effect = {key, category, status = {qing="implemented|inherited|needs_probe|unsupported", ...}, note}
function registry.register_effect(collectible_id, effect)
	collectible_id = tonumber(collectible_id)
	if not collectible_id or type(effect) ~= "table" then return nil end
	effect.collectible_id = collectible_id
	registry.effects[collectible_id] = effect
	return effect
end

function registry.get(player_or_type)
	local player_type = type(player_or_type) == "number" and player_or_type
		or (player_or_type and player_or_type.GetPlayerType and player_or_type:GetPlayerType())
	return registry.entries[normalize_player_type(player_type)]
end

--- 实体归属只允许显式 owner / spawner；Player 0 仅作为单人旧实体兜底。
function registry.resolve_entity_player(entity, explicit_owner)
	local function live_player(candidate)
		if not candidate then return nil end
		local ok, player = pcall(function()
			if candidate.Exists and not candidate:Exists() then return nil end
			return candidate:ToPlayer()
		end)
		return ok and player or nil
	end
	local explicit_player = live_player(explicit_owner)
	if explicit_player then return explicit_player end
	if entity then
		local ok, player = pcall(function()
			local spawner = entity.SpawnerEntity
			return live_player(spawner)
		end)
		if ok and player then return player end
	end
	if Game():GetNumPlayers() == 1 then return Isaac.GetPlayer(0) end
	return nil
end

function registry.supports_advanced_familiars(player_or_type)
	local entry = registry.get(player_or_type)
	return entry ~= nil and entry.advanced_familiars == true and type(entry.familiar_attack) == "function"
end

function registry.has_familiar_attack(player_or_type)
	local entry = registry.get(player_or_type)
	return entry ~= nil and type(entry.familiar_attack) == "function"
end

--- 所有自定义角色宝宝攻击都经过这里，统一保护错误和返回格式。
function registry.dispatch_familiar_attack(player, request)
	local entry = registry.get(player)
	if not entry or type(entry.familiar_attack) ~= "function" then return {fired = false} end
	request = request or {}
	request.suppress_player_cost = request.suppress_player_cost ~= false
	request.is_familiar_copy = true
	local ok, result = pcall(entry.familiar_attack, player, request)
	if not ok then
		print("Character_Attack_Compat_"..tostring(entry.key or entry.player_type)..":"..tostring(result))
		return {fired = false, error = tostring(result)}
	end
	if type(result) ~= "table" then return {fired = result == true} end
	result.fired = result.fired == true
	return result
end

function registry.has_snapshot_attack(player_or_type)
	local entry = registry.get(player_or_type)
	return entry ~= nil and type(entry.snapshot_attack) == "function"
end

function registry.has_replay_attack(player_or_type)
	local entry = registry.get(player_or_type)
	return entry ~= nil and type(entry.replay_attack) == "function"
end

--- Aeon recording: build a pure-data snapshot for character_action, or nil to fall through.
--- context = { attack, event, member, frame, direction, origin }
function registry.dispatch_snapshot_attack(player, context)
	local entry = registry.get(player)
	if not entry or type(entry.snapshot_attack) ~= "function" then return nil end
	context = context or {}
	local ok, result = pcall(entry.snapshot_attack, player, context)
	if not ok then
		print("Character_Attack_Compat_snapshot_"..tostring(entry.key or entry.player_type)..":"..tostring(result))
		return nil
	end
	if result == nil then return nil end
	if type(result) ~= "table" then
		print("Character_Attack_Compat_snapshot_"..tostring(entry.key or entry.player_type)..":non_table")
		return nil
	end
	local pure_ok, reason = registry.validate_pure_data(result, PURE_DATA_MAX_DEPTH)
	if not pure_ok then
		print("Character_Attack_Compat_snapshot_"..tostring(entry.key or entry.player_type)..":impure:"..tostring(reason))
		return nil
	end
	return result
end

--- Aeon / copy replay: fire from frozen snapshot without player cost / state advance.
--- request = { snapshot, origin, aim_dir, source, owner_player, fire_context, ... }
function registry.dispatch_replay_attack(player_or_type, owner_player, request)
	local entry = registry.get(player_or_type)
	if not entry or type(entry.replay_attack) ~= "function" then
		return {fired = false}
	end
	request = request or {}
	request.suppress_player_cost = request.suppress_player_cost ~= false
	request.suppress_state_advance = request.suppress_state_advance ~= false
	request.is_replay_copy = true
	request.reason = request.reason or "aeon_character_replay"
	request.fire_context = request.fire_context or {
		mode = "untracked",
		reason = request.reason,
	}
	if request.fire_context.mode == nil then
		request.fire_context.mode = "untracked"
	end
	local player = owner_player or (type(player_or_type) ~= "number" and player_or_type) or nil
	local ok, result = pcall(entry.replay_attack, player, request)
	if not ok then
		print("Character_Attack_Compat_replay_"..tostring(entry.key or entry.player_type)..":"..tostring(result))
		return {fired = false, error = tostring(result)}
	end
	if type(result) ~= "table" then return {fired = result == true} end
	result.fired = result.fired == true
	return result
end

--- Optional pure-visual replay presentation (no combat entities / Attack / damage).
--- request = { snapshot, source, origin, aim_dir, owner_player, player_type, ... }
function registry.begin_replay_presentation(player_or_type, request)
	local entry = registry.get(player_or_type)
	if not entry or type(entry.begin_replay_presentation) ~= "function" then
		return nil
	end
	request = request or {}
	request.is_replay_presentation = true
	local player = request.owner_player
		or (type(player_or_type) ~= "number" and player_or_type)
		or nil
	local ok, handle = pcall(entry.begin_replay_presentation, player, request)
	if not ok then
		print("Character_Attack_Compat_presentation_begin_"..tostring(entry.key or entry.player_type)..":"..tostring(handle))
		return nil
	end
	if type(handle) == "table" then
		handle._compat_entry = entry
		handle.player_type = handle.player_type or entry.player_type
	end
	return handle
end

--- Returns true when presentation finished (caller should drop the handle).
function registry.update_replay_presentation(handle, request)
	if type(handle) ~= "table" then return true end
	local entry = handle._compat_entry or registry.get(handle.player_type or handle.character_key)
	if not entry or type(entry.update_replay_presentation) ~= "function" then
		return true
	end
	local ok, finished = pcall(entry.update_replay_presentation, handle, request or {})
	if not ok then
		print("Character_Attack_Compat_presentation_update_"..tostring(entry.key or entry.player_type)..":"..tostring(finished))
		return true
	end
	return finished == true
end

function registry.end_replay_presentation(handle, reason)
	if type(handle) ~= "table" then return end
	local entry = handle._compat_entry or registry.get(handle.player_type or handle.character_key)
	if not entry or type(entry.end_replay_presentation) ~= "function" then
		return
	end
	pcall(entry.end_replay_presentation, handle, reason)
end

function registry.has_replay_presentation(player_or_type)
	local entry = registry.get(player_or_type)
	return entry ~= nil and type(entry.begin_replay_presentation) == "function"
end

--- Optional per-frame pure-data pose for Aeon presentation (not attack snapshot).
--- context = { canvas_center = Vector|{x,y}, frame = n, ... }
--- Returns nil, or a pure table (e.g. {target_x,target_y} or {aim_x,aim_y}).
function registry.capture_replay_pose(player, context)
	local entry = registry.get(player)
	if not entry or type(entry.capture_replay_pose) ~= "function" then
		return nil
	end
	local ok, result = pcall(entry.capture_replay_pose, player, context or {})
	if not ok then
		print("Character_Attack_Compat_pose_"..tostring(entry.key or entry.player_type)..":"..tostring(result))
		return nil
	end
	if result == nil then return nil end
	if type(result) ~= "table" then
		print("Character_Attack_Compat_pose_"..tostring(entry.key or entry.player_type)..":non_table")
		return nil
	end
	local pure_ok, reason = registry.validate_pure_data(result, PURE_DATA_MAX_DEPTH)
	if not pure_ok then
		print("Character_Attack_Compat_pose_"..tostring(entry.key or entry.player_type)..":impure:"..tostring(reason))
		return nil
	end
	return result
end

function registry.has_capture_replay_pose(player_or_type)
	local entry = registry.get(player_or_type)
	return entry ~= nil and type(entry.capture_replay_pose) == "function"
end

--- Attach a pure-data Aeon snapshot onto an Attack so Once / MEMBER_BOUND can retrieve it.
function registry.attach_attack_snapshot(attack, snapshot)
	if type(attack) ~= "table" or type(snapshot) ~= "table" then return false end
	local pure_ok, reason = registry.validate_pure_data(snapshot, PURE_DATA_MAX_DEPTH)
	if not pure_ok then
		print("Character_Attack_Compat_attach:impure:"..tostring(reason))
		return false
	end
	attack.tags = attack.tags or {}
	attack.tags.aeon_character_snapshot = snapshot
	return true
end

function registry.read_attack_snapshot(attack)
	if type(attack) ~= "table" or type(attack.tags) ~= "table" then return nil end
	local snap = attack.tags.aeon_character_snapshot
	if type(snap) ~= "table" then return nil end
	return snap
end

--- 供 ImGui/后续自动审计读取，不返回函数，避免调试导出持有闭包。
function registry.audit_snapshot()
	local out = {}
	for player_type, entry in pairs(registry.entries) do
		local capabilities = {}
		for key, enabled in pairs(entry.capabilities or {}) do capabilities[key] = enabled == true end
		out[#out + 1] = {
			player_type = player_type,
			key = entry.key,
			module = entry.module,
			advanced_familiars = entry.advanced_familiars == true,
			has_familiar_attack = type(entry.familiar_attack) == "function",
			has_snapshot_attack = type(entry.snapshot_attack) == "function",
			has_replay_attack = type(entry.replay_attack) == "function",
			has_replay_presentation = type(entry.begin_replay_presentation) == "function",
			has_capture_replay_pose = type(entry.capture_replay_pose) == "function",
			capabilities = capabilities,
			audit = entry.audit,
		}
	end
	table.sort(out, function(a, b) return a.player_type < b.player_type end)
	local effects = {}
	for collectible_id, effect in pairs(registry.effects) do
		local status = {}
		for key, value in pairs(effect.status or {}) do status[key] = value end
		effects[#effects + 1] = {
			collectible_id = collectible_id,
			key = effect.key,
			category = effect.category,
			status = status,
			note = effect.note,
		}
	end
	table.sort(effects, function(a, b) return a.collectible_id < b.collectible_id end)
	return {characters = out, effects = effects}
end

return registry

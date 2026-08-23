-- 自定义角色攻击兼容的唯一注册入口。
-- 角色模块在自身加载完成时登记；宝宝/复制攻击系统只查询本表，禁止再维护平行角色名单。
local registry = {
	entries = {},
	advanced_supported = {},
	effects = {},
}

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

--- def = {
---   key, module, advanced_familiars, familiar_attack,
---   capabilities = {projectile=true, volley=true, charge=true, ...},
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

local registry = {
	by_id = {},
	family_index = {},
	finalized = false,
	validation_warnings = {},
}

local function normalize_id(id)
	if type(id) == "userdata" and id.SubType then
		return id.SubType
	end
	return id
end

local function copy_families(families)
	local out = {}
	if type(families) == "table" then
		for k, v in pairs(families) do
			if v then out[k] = true end
		end
	end
	return out
end

local function apply_thoth_tarot(families)
	if families.thoth then
		families.tarot = true
	end
	return families
end

local function rebuild_family_index()
	registry.family_index = {}
	for id, meta in pairs(registry.by_id) do
		for family in pairs(meta.families or {}) do
			local bucket = registry.family_index[family]
			if not bucket then
				bucket = {}
				registry.family_index[family] = bucket
			end
			bucket[#bucket + 1] = id
		end
	end
	for _, bucket in pairs(registry.family_index) do
		table.sort(bucket)
	end
end

local function push_warning(code, detail)
	registry.validation_warnings[#registry.validation_warnings + 1] = {
		code = code,
		detail = detail,
	}
end

local function emit_dev_warnings(warnings)
	if type(warnings) ~= "table" or #warnings == 0 then return end
	local ok, dev_env = pcall(require, "Qing_Remaster_scripts.core.dev_environment")
	if ok and dev_env and dev_env.is_public_release and dev_env.is_public_release() then
		return
	end
	for _, warn in ipairs(warnings) do
		local msg = "[Qing card_registry] " .. tostring(warn.code)
		if warn.detail then
			msg = msg .. ": " .. tostring(warn.detail)
		end
		if Isaac and Isaac.DebugString then
			Isaac.DebugString(msg)
		end
	end
end

function registry.register(id, meta)
	id = normalize_id(id)
	meta = meta or {}
	if id == nil then
		push_warning("register_nil_id", "missing card id")
		return nil
	end
	if registry.finalized then
		push_warning("register_after_finalize", tostring(id))
	end
	if registry.by_id[id] then
		push_warning("duplicate_id", tostring(id))
	end

	local entry = {
		id = id,
		key = meta.key,
		arcana = meta.arcana,
		reversed = meta.reversed == true,
		families = apply_thoth_tarot(copy_families(meta.families)),
		source = meta.source,
		-- immediate | deferred | no_effect；缺省 immediate（绝大多数透特牌）
		use_resolution = meta.use_resolution,
	}
	registry.by_id[id] = entry
	return entry
end

function registry.register_from_item(item)
	if not item or not item.entity or not item.card_registry then
		return nil
	end
	local meta = item.card_registry
	if type(meta) == "function" then
		meta = meta(item)
	end
	if type(meta) ~= "table" then
		return nil
	end
	return registry.register(item.entity, meta)
end

function registry.get(id)
	id = normalize_id(id)
	return registry.by_id[id]
end

--- 透特牌使用结算策略；非透特 / 未登记 → immediate。
function registry.get_use_resolution(id)
	local meta = registry.get(id)
	local res = meta and meta.use_resolution or nil
	if res == "immediate" or res == "deferred" or res == "no_effect" then
		return res
	end
	return "immediate"
end

function registry.has_family(id, family)
	local meta = registry.get(id)
	if not meta or not meta.families then return false end
	return meta.families[family] == true
end

function registry.get_family(family)
	local bucket = registry.family_index[family]
	if not bucket then return {} end
	local out = {}
	for i = 1, #bucket do
		out[i] = bucket[i]
	end
	return out
end

function registry.query(opts)
	opts = opts or {}
	local out = {}
	for id, meta in pairs(registry.by_id) do
		local ok = true
		if opts.family and not meta.families[opts.family] then
			ok = false
		end
		if opts.reversed ~= nil and meta.reversed ~= opts.reversed then
			ok = false
		end
		if opts.arcana ~= nil and meta.arcana ~= opts.arcana then
			ok = false
		end
		if ok then
			out[#out + 1] = meta
		end
	end
	table.sort(out, function(a, b)
		if a.arcana == b.arcana then
			if a.reversed == b.reversed then
				return (a.id or 0) < (b.id or 0)
			end
			return not a.reversed
		end
		if a.arcana == nil then return false end
		if b.arcana == nil then return true end
		return a.arcana < b.arcana
	end)
	return out
end

function registry.is_thoth(id)
	return registry.has_family(id, "thoth")
end

function registry.get_thoth_cards()
	return registry.get_family("thoth")
end

function registry.get_tarot_cards()
	return registry.get_family("tarot")
end

function registry.finalize()
	for _, meta in pairs(registry.by_id) do
		meta.families = apply_thoth_tarot(copy_families(meta.families))
	end
	rebuild_family_index()
	registry.finalized = true
end

function registry.validate()
	local warnings = {}

	for id, meta in pairs(registry.by_id) do
		if meta.families and meta.families.thoth then
			if not meta.key then
				warnings[#warnings + 1] = {
					code = "thoth_missing_key",
					detail = tostring(id),
				}
			end
			if meta.arcana == nil then
				warnings[#warnings + 1] = {
					code = "thoth_missing_arcana",
					detail = tostring(id),
				}
			elseif meta.arcana < 0 or meta.arcana > 21 then
				warnings[#warnings + 1] = {
					code = "thoth_arcana_out_of_range",
					detail = tostring(id) .. " arcana=" .. tostring(meta.arcana),
				}
			end
		end
	end

	for _, warn in ipairs(registry.validation_warnings) do
		warnings[#warnings + 1] = warn
	end
	registry.validation_warnings = warnings
	emit_dev_warnings(warnings)
	return warnings
end

return registry

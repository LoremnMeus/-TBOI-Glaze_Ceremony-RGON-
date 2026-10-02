-- Thin wrapper over merged Stitch Edition Mixture_data (+ Extra_Mixture_data).
-- Mixture_data.lua already resolves `check` inheritance and merges functions.

local DATA = require("Qing_Remaster_scripts.auxiliary.native_mixture.data.Mixture_data")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local M = {
	schema = "runtime_stitch_mixture_merged",
	schema_version = 2,
}

local by_tvs = nil

local function ensure_tvs_index()
	if by_tvs then
		return by_tvs
	end
	by_tvs = {}
	for group, entries in pairs(DATA) do
		if type(group) == "number" and type(entries) == "table" then
			for id, entry in pairs(entries) do
				if type(id) == "number" and type(entry) == "table" and entry.type ~= nil then
					local key = tostring(entry.type)
						.. ":"
						.. tostring(entry.variant or 0)
						.. ":"
						.. tostring(entry.subtype or 0)
					if by_tvs[key] == nil then
						by_tvs[key] = { group = group, id = id }
					end
				end
			end
		end
	end
	return by_tvs
end

local function annotate(entry, group, id)
	if type(entry) ~= "table" then
		return nil
	end
	-- Stamp identity once onto the shared merged entry (Stitch Edition style).
	if entry.group == nil then
		entry.group = group
	end
	if entry.id == nil then
		entry.id = id
	end
	return entry
end

function M.raw()
	return DATA
end

function M.get(side, group, id)
	group = tonumber(group)
	id = tonumber(id)
	if group == nil or id == nil then
		return nil
	end
	local g = DATA[group]
	local entry = g and g[id]
	return annotate(entry, group, id)
end

--- Lookup by Type/Variant/SubType across merged Mixture_data.
--- `side` is accepted for call-site parity with Stitch fast_search(u, ...) but is
--- NOT used: DATA groups are boss(1)/enemy(2) catalogs, not Left/Right half tables.
--- Prefer exact TVS; also honor entry.on_search (Stitch Edition find_entity).
function M.find(_side, typ, variant, subtype)
	typ = tonumber(typ)
	variant = tonumber(variant) or 0
	subtype = tonumber(subtype) or 0
	if typ == nil then
		return nil
	end

	local key = tostring(typ) .. ":" .. tostring(variant) .. ":" .. tostring(subtype)
	local hit = ensure_tvs_index()[key]
	if hit then
		local entry = M.get(_side, hit.group, hit.id)
		if entry then
			return entry
		end
	end

	-- Slow path: scan for on_search custom match (and fill TVS miss).
	for group, entries in pairs(DATA) do
		if type(group) == "number" and type(entries) == "table" then
			for id, entry in pairs(entries) do
				if type(id) == "number" and type(entry) == "table" then
					local matched = false
					if entry.on_search then
						matched = auxi.check_if_any(entry.on_search, entry, typ, variant, subtype) == true
					end
					if not matched
						and entry.type == typ
						and (entry.variant or 0) == variant
						and (entry.subtype or 0) == subtype
					then
						matched = true
					end
					if matched then
						return annotate(entry, group, id)
					end
				end
			end
		end
	end
	return nil
end

--- Compatibility: merged data already resolved `check`; resolve == get.
function M.resolve(side, group, id)
	return M.get(side, group, id)
end

--- Overlay Qing-ported profile.mixture function hooks onto a shallow copy.
--- Only for hooks that intentionally replace Extra hooks tied to old OWN_KEY /
--- old controller. Not a second behavior database — scalars stay in Mixture_data.
--- Never mutate the shared Mixture_data table.
function M.merge_profile_hooks(entry, profile_mixture)
	if type(entry) ~= "table" then
		return entry
	end
	local out = {}
	for k, v in pairs(entry) do
		out[k] = v
	end
	if type(profile_mixture) == "table" then
		for k, v in pairs(profile_mixture) do
			if type(v) == "function" then
				out[k] = v
			end
		end
	end
	return out
end

function M.smoke_check_extra_apis()
	local missing = {}
	local function need(mod_name, path, methods)
		local ok, mod = pcall(require, path)
		if not ok or type(mod) ~= "table" then
			missing[#missing + 1] = "module:" .. mod_name
			return
		end
		for i = 1, #methods do
			local m = methods[i]
			if type(mod[m]) ~= "function" then
				missing[#missing + 1] = mod_name .. "." .. m
			end
		end
	end
	need("auxi", "Qing_Remaster_scripts.auxiliary.functions", {
		"MulColor2",
		"ProtectVector",
		"Vector2Table",
		"check_all_exists",
		"check_for_the_same",
		"check_if_any",
		"check_lerp",
		"choose",
		"copy_sprite",
		"get_last_parentnpc",
		"get_parentnpc_list",
		"getallenemies",
		"getenemies",
		"getothers",
		"random_r",
	})
	need("collector", "Qing_Remaster_scripts.others.Parent_Collect_holder", {
		"collect",
		"collect_all_parents",
		"search_for_linkage",
		"is_in_the_same_npc_group",
		"update_npc",
	})
	need("sound_tracker", "Qing_Remaster_scripts.auxiliary.sound_tracker", { "PlayStackedSound" })
	need("Attribute_holder", "Qing_Remaster_scripts.others.Attribute_holder", {
		"try_hold_attribute",
		"try_rewind_attribute",
	})
	need("delay_buffer", "Qing_Remaster_scripts.auxiliary.delay_buffer", { "addeffe" })

	local ok_extra, extra_or_err = pcall(require, "Qing_Remaster_scripts.auxiliary.native_mixture.data.Extra_Mixture_data")
	if not ok_extra then
		missing[#missing + 1] = "Extra_Mixture_data load: " .. tostring(extra_or_err)
	end
	local ok_mix, mix_or_err = pcall(require, "Qing_Remaster_scripts.auxiliary.native_mixture.data.Mixture_data")
	if not ok_mix then
		missing[#missing + 1] = "Mixture_data load: " .. tostring(mix_or_err)
	elseif type(mix_or_err) == "table" then
		local gaper = mix_or_err[2] and mix_or_err[2][1]
		if not (gaper and gaper.check_all_type == true and gaper.protect_self == true) then
			missing[#missing + 1] = "Mixture_data[2][1] missing merged Gaper flags"
		end
	end
	return #missing == 0, missing
end

return M

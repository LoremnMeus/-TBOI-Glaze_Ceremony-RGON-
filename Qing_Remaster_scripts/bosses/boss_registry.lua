local defs = require("Qing_Remaster_scripts.bosses.boss_defs")

local registry = {
	defs = defs,
	bosses = {},
	order = {},
	future = {},
	future_order = {},
	excluded = defs.excluded or {},
	unresolved = defs.unresolved or {},
}

for _, boss in ipairs(defs.bosses or {}) do
	registry.bosses[boss.id] = boss
	registry.order[#registry.order + 1] = boss.id
end

for _, entry in ipairs(defs.future or {}) do
	registry.future[entry.id] = entry
	registry.future_order[#registry.future_order + 1] = entry.id
end

function registry.get(id)
	return registry.bosses[id]
end

function registry.get_future(id)
	return registry.future[id]
end

function registry.is_current_scope(boss)
	if not boss then return false end
	local scope = boss.story_scope
	if type(scope) == "table" and scope.status then
		return scope.status == "current"
	end
	-- Formal list entries without explicit scope are treated as current.
	return true
end

function registry.list(filter)
	local out = {}
	for _, id in ipairs(registry.order) do
		local boss = registry.bosses[id]
		local ok = true
		if type(filter) == "table" then
			if filter.status and boss.status ~= filter.status then ok = false end
			if filter.kind and boss.kind ~= filter.kind then ok = false end
			if filter.wiki_visible ~= nil then
				local visible = boss.wiki and boss.wiki.visible == true
				if filter.wiki_visible ~= visible then ok = false end
			end
			if filter.implemented_or_wip and boss.status ~= "implemented" and boss.status ~= "wip" then
				ok = false
			end
			if filter.story_scope_status then
				local scope = boss.story_scope
				local st = scope and scope.status or "current"
				if st ~= filter.story_scope_status then ok = false end
			end
			if filter.current_only ~= false then
				-- default: formal list only (already current-scope entries)
			end
		end
		if ok then out[#out + 1] = boss end
	end
	return out
end

function registry.list_future()
	local out = {}
	for _, id in ipairs(registry.future_order) do
		out[#out + 1] = registry.future[id]
	end
	return out
end

--- Story Definition is canonical for "which bosses belong to a story".
function registry.get_related_stories(boss_id)
	local stories = {}
	local ok, story_registry = pcall(require, "Qing_Remaster_scripts.story.story_registry")
	if not ok or not story_registry or not story_registry.list_nodes then
		return stories
	end
	for _, node in ipairs(story_registry.list_nodes()) do
		for _, bid in ipairs(story_registry.get_related_bosses(node)) do
			if bid == boss_id then
				stories[#stories + 1] = node.id
				break
			end
		end
	end
	return stories
end

function registry.get_export_metadata(opts)
	opts = opts or {}
	local include_future = opts.include_future == true
	local bosses = {}
	for _, boss in ipairs(registry.list()) do
		if registry.is_current_scope(boss) then
			bosses[#bosses + 1] = {
				id = boss.id,
				name = boss.name,
				status = boss.status,
				kind = boss.kind,
				story_scope = boss.story_scope,
				entity = boss.entity,
				spawn = boss.spawn,
				related_character = boss.related_character,
				related_stories = registry.get_related_stories(boss.id),
				components = boss.components,
				wiki = boss.wiki,
				sources = boss.sources,
			}
		end
	end
	local payload = {
		schema_version = defs.SCHEMA_VERSION,
		current_story_scope = defs.CURRENT_STORY_SCOPE,
		status = defs.STATUS,
		kind = defs.KIND,
		bosses = bosses,
		excluded = registry.excluded,
		unresolved = registry.unresolved,
	}
	if include_future then
		payload.future = registry.list_future()
	else
		-- Public/default export: IDs only, no expansion into pages.
		local future_ids = {}
		for _, entry in ipairs(registry.list_future()) do
			future_ids[#future_ids + 1] = entry.id
		end
		payload.future_deferred_ids = future_ids
	end
	return payload
end

function registry.validate_cross_links()
	local warnings = {}
	local ok, story_registry = pcall(require, "Qing_Remaster_scripts.story.story_registry")
	if ok and story_registry and story_registry.list_nodes then
		for _, node in ipairs(story_registry.list_nodes()) do
			for _, bid in ipairs(story_registry.get_related_bosses(node)) do
				if not registry.get(bid) then
					local known_unresolved = false
					for _, u in ipairs(registry.unresolved) do
						if u.id == bid then known_unresolved = true break end
					end
					local known_future = registry.get_future(bid) ~= nil
					if known_future then
						warnings[#warnings + 1] = {
							level = "error",
							code = "story_links_future_boss",
							story = node.id,
							boss = bid,
						}
					elseif not known_unresolved then
						warnings[#warnings + 1] = {
							level = "error",
							code = "story_boss_missing",
							story = node.id,
							boss = bid,
						}
					else
						warnings[#warnings + 1] = {
							level = "info",
							code = "story_boss_unresolved",
							story = node.id,
							boss = bid,
						}
					end
				end
			end
		end
	end

	for _, boss in ipairs(registry.list({wiki_visible = true})) do
		if (boss.kind == "story_boss" or boss.kind == "side_boss") then
			local stories = registry.get_related_stories(boss.id)
			if #stories == 0 and boss.status == "implemented" then
				warnings[#warnings + 1] = {
					level = "warn",
					code = "boss_without_story",
					boss = boss.id,
				}
			end
		end
		if boss.related_character then
			local cok, char_registry = pcall(require, "Qing_Remaster_scripts.story.character_registry")
			if cok and char_registry and char_registry.get and not char_registry.get(boss.related_character) then
				warnings[#warnings + 1] = {
					level = "warn",
					code = "boss_character_missing",
					boss = boss.id,
					character = boss.related_character,
				}
			end
		end
	end
	return warnings
end

return registry

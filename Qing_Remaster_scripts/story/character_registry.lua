local defs = require("Qing_Remaster_scripts.story.character_defs")

local registry = {
	defs = defs,
	characters = {},
	order = {},
	future = {},
	future_order = {},
}

for _, character in ipairs(defs.characters or {}) do
	registry.characters[character.id] = character
	registry.order[#registry.order + 1] = character.id
end

for _, entry in ipairs(defs.future or {}) do
	registry.future[entry.id] = entry
	registry.future_order[#registry.future_order + 1] = entry.id
end

function registry.get(id)
	return registry.characters[id]
end

function registry.get_future(id)
	return registry.future[id]
end

function registry.list(filter)
	local out = {}
	for _, id in ipairs(registry.order) do
		local character = registry.characters[id]
		local ok = true
		if type(filter) == "table" then
			if filter.wiki_visible ~= nil then
				local visible = character.wiki and character.wiki.visible == true
				if filter.wiki_visible ~= visible then ok = false end
			end
			if filter.story_scope_status then
				local scope = character.story_scope
				local st = scope and scope.status or "current"
				if st ~= filter.story_scope_status then ok = false end
			end
		end
		if ok then out[#out + 1] = character end
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

function registry.get_related_stories(character_id)
	local stories = {}
	local ok, story_registry = pcall(require, "Qing_Remaster_scripts.story.story_registry")
	if not ok or not story_registry or not story_registry.list_nodes then
		return stories
	end
	for _, node in ipairs(story_registry.list_nodes()) do
		local participants = node.participants or {}
		for _, pid in ipairs(participants) do
			if pid == character_id then
				stories[#stories + 1] = node.id
				break
			end
		end
	end
	return stories
end

function registry.get_export_metadata(opts)
	opts = opts or {}
	local characters = {}
	for _, character in ipairs(registry.list()) do
		characters[#characters + 1] = {
			id = character.id,
			name = character.name,
			kind = character.kind,
			story_scope = character.story_scope,
			related_boss = character.related_boss,
			related_playable = character.related_playable,
			related_stories = registry.get_related_stories(character.id),
			wiki = character.wiki,
			notes = character.notes,
		}
	end
	local payload = {
		schema_version = defs.SCHEMA_VERSION,
		current_story_scope = defs.CURRENT_STORY_SCOPE,
		kind = defs.KIND,
		characters = characters,
	}
	if opts.include_future == true then
		payload.future = registry.list_future()
	else
		local future_ids = {}
		for _, entry in ipairs(registry.list_future()) do
			future_ids[#future_ids + 1] = entry.id
		end
		payload.future_deferred_ids = future_ids
	end
	return payload
end

return registry

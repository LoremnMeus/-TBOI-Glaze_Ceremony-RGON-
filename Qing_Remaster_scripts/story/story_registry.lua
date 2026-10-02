local defs = require("Qing_Remaster_scripts.story.story_defs")

local registry = {
	defs = defs,
	chapters = {},
	chapter_order = {},
	nodes = {},
	nodes_by_chapter = {},
	children_by_parent = {},
	parent_of = {},
	token_owner = {},
	thread_map = defs.thread_story_map or {},
}

for _, chapter in ipairs(defs.chapters or {}) do
	registry.chapters[chapter.id] = chapter
	registry.chapter_order[#registry.chapter_order + 1] = chapter.id
	registry.nodes_by_chapter[chapter.id] = {}
end

for _, node in ipairs(defs.nodes or {}) do
	registry.nodes[node.id] = node
	local list = registry.nodes_by_chapter[node.chapter]
	if list then
		list[#list + 1] = node
	end
	if type(node.parent) == "string" and node.parent ~= "" then
		registry.parent_of[node.id] = node.parent
		local kids = registry.children_by_parent[node.parent]
		if not kids then
			kids = {}
			registry.children_by_parent[node.parent] = kids
		end
		kids[#kids + 1] = node.id
	end
end

for _, list in pairs(registry.nodes_by_chapter) do
	table.sort(list, function(a, b)
		return (a.order or 0) < (b.order or 0)
	end)
end

for _, kids in pairs(registry.children_by_parent) do
	table.sort(kids, function(a, b)
		local na = registry.nodes[a]
		local nb = registry.nodes[b]
		return ((na and na.order) or 0) < ((nb and nb.order) or 0)
	end)
end

-- Token → owning chapter/node (from related.story_tokens).
for _, node in ipairs(defs.nodes or {}) do
	local related = node.related or {}
	local tokens = related.story_tokens
	if type(tokens) ~= "table" and related.token then
		tokens = {related.token}
	end
	if type(tokens) == "table" then
		for _, token in ipairs(tokens) do
			if type(token) == "string" and token ~= "" then
				registry.token_owner[token] = {
					chapter = node.chapter,
					node = node.id,
					token = token,
				}
			end
		end
	end
end

function registry.get_chapter(id)
	return registry.chapters[id]
end

function registry.get_node(id)
	return registry.nodes[id]
end

function registry.list_chapters()
	local out = {}
	for _, id in ipairs(registry.chapter_order) do
		out[#out + 1] = registry.chapters[id]
	end
	return out
end

function registry.list_nodes(chapter_id)
	if chapter_id then
		return registry.nodes_by_chapter[chapter_id] or {}
	end
	local out = {}
	for _, id in ipairs(registry.chapter_order) do
		for _, node in ipairs(registry.nodes_by_chapter[id] or {}) do
			out[#out + 1] = node
		end
	end
	return out
end

--- Top-level record nodes for a chapter (no parent), in order.
function registry.list_record_nodes(chapter_id)
	local out = {}
	for _, node in ipairs(registry.list_nodes(chapter_id)) do
		if not node.parent then
			out[#out + 1] = node
		end
	end
	return out
end

function registry.list_child_nodes(node_id)
	local ids = registry.children_by_parent[node_id] or {}
	local out = {}
	for _, id in ipairs(ids) do
		local node = registry.nodes[id]
		if node then out[#out + 1] = node end
	end
	return out
end

function registry.get_parent_node(node_or_id)
	local id = node_or_id
	if type(node_or_id) == "table" then
		id = node_or_id.id
	end
	local parent_id = registry.parent_of[id]
	if not parent_id then return nil end
	return registry.nodes[parent_id]
end

function registry.get_token_owner(token)
	if type(token) ~= "string" then return nil end
	return registry.token_owner[token]
end

function registry.get_token_title(token)
	local meta = defs.tokens and defs.tokens[token]
	if meta and type(meta.title) == "table" then
		return meta.title
	end
	return {zh = token, en = token}
end

function registry.get_node_tokens(node_or_id)
	return registry.get_story_tokens(node_or_id)
end

--- Player Progress UI: only nodes with record.player.visible == true (top-level, no parent).
function registry.list_player_records(chapter_id)
	local out = {}
	for _, node in ipairs(registry.list_nodes(chapter_id)) do
		if not node.parent then
			local player = node.record and node.record.player
			if player and player.visible == true then
				out[#out + 1] = node
			end
		end
	end
	return out
end

function registry.is_player_visible(node_or_id)
	local node = node_or_id
	if type(node_or_id) == "string" then
		node = registry.nodes[node_or_id]
	end
	local player = node and node.record and node.record.player
	return player ~= nil and player.visible == true
end

function registry.list_requirements(node_or_id)
	local node = node_or_id
	if type(node_or_id) == "string" then
		node = registry.nodes[node_or_id]
	end
	if not node or type(node.requirements) ~= "table" then return {} end
	local out = {}
	for _, req in ipairs(node.requirements) do
		out[#out + 1] = req
	end
	return out
end

--- Resolve requirement token list (explicit tokens or child_tokens).
function registry.get_requirement_tokens(node_or_id, requirement)
	local node = node_or_id
	if type(node_or_id) == "string" then
		node = registry.nodes[node_or_id]
	end
	if not node then return {} end
	local req = requirement
	if type(req) == "string" then
		for _, r in ipairs(registry.list_requirements(node)) do
			if r.id == req then
				req = r
				break
			end
		end
	end
	if type(req) ~= "table" then return {} end
	if type(req.tokens) == "table" and #req.tokens > 0 then
		local out = {}
		for _, t in ipairs(req.tokens) do out[#out + 1] = t end
		return out
	end
	if req.type == "child_tokens" or req.type == "tokens" then
		local out = {}
		local seen = {}
		for _, child in ipairs(registry.list_child_nodes(node.id)) do
			for _, token in ipairs(registry.get_story_tokens(child)) do
				if not seen[token] then
					seen[token] = true
					out[#out + 1] = token
				end
			end
		end
		return out
	end
	return {}
end

function registry.get_thread_mapping(thread_id)
	return registry.thread_map[thread_id]
end

--- Canonical: Story declares related.bosses[]; Boss→Story is derived.
function registry.get_related_bosses(node_or_id)
	local node = node_or_id
	if type(node_or_id) == "string" then
		node = registry.nodes[node_or_id]
	end
	if not node then return {} end
	local related = node.related or {}
	local bosses = related.bosses
	if type(bosses) ~= "table" and related.boss then
		bosses = {related.boss}
	end
	if type(bosses) ~= "table" then return {} end
	local out = {}
	for _, id in ipairs(bosses) do
		out[#out + 1] = id
	end
	return out
end

function registry.get_story_tokens(node_or_id)
	local node = node_or_id
	if type(node_or_id) == "string" then
		node = registry.nodes[node_or_id]
	end
	if not node then return {} end
	local related = node.related or {}
	local tokens = related.story_tokens
	if type(tokens) ~= "table" and related.token then
		tokens = {related.token}
	end
	if type(tokens) ~= "table" then return {} end
	local out = {}
	for _, id in ipairs(tokens) do
		out[#out + 1] = id
	end
	return out
end

function registry.get_gameplay_rewards(node_or_id)
	local node = node_or_id
	if type(node_or_id) == "string" then
		node = registry.nodes[node_or_id]
	end
	if not node then return {} end
	local related = node.related or {}
	local rewards = related.gameplay_rewards
	if type(rewards) ~= "table" then
		if related.collectible then
			rewards = {{id = related.collectible, status = "legacy_runtime_reward"}}
		else
			return {}
		end
	end
	local out = {}
	for _, reward in ipairs(rewards) do
		out[#out + 1] = reward
	end
	return out
end

function registry.get_stories_for_boss(boss_id)
	local out = {}
	for _, node in ipairs(registry.list_nodes()) do
		for _, bid in ipairs(registry.get_related_bosses(node)) do
			if bid == boss_id then
				out[#out + 1] = node.id
				break
			end
		end
	end
	return out
end

function registry.get_export_metadata(opts)
	opts = opts or {}
	local include_development = opts.include_development == true
	local chapters = {}
	for _, chapter in ipairs(registry.list_chapters()) do
		local scope = chapter.story_scope
		if scope and scope.status and scope.status ~= "current" and opts.include_future ~= true then
			-- skip non-current chapters from default export
		else
			local nodes = {}
			for _, node in ipairs(registry.list_nodes(chapter.id)) do
				local related = {
					bosses = registry.get_related_bosses(node),
					story_tokens = registry.get_story_tokens(node),
					gameplay_rewards = registry.get_gameplay_rewards(node),
					related_entities = (node.related and node.related.related_entities) or nil,
				}
				nodes[#nodes + 1] = {
					id = node.id,
					kind = node.kind,
					title = node.title,
					title_status = node.title_status,
					order = node.order,
					previous = node.previous,
					next = node.next,
					parent = node.parent,
					record = node.record,
					requirements = node.requirements,
					runtime_thread = node.runtime_thread,
					participants = node.participants,
					related = related,
					spoiler_level = node.spoiler_level,
					hidden = node.hidden == true,
					wiki_visible = node.wiki_visible ~= false,
					notes = node.notes,
				}
			end
			local chapter_payload = {
				id = chapter.id,
				order = chapter.order,
				title = chapter.title,
				story_scope = chapter.story_scope or {status = "current"},
				runtime_threads = chapter.runtime_threads,
				objectives = chapter.objectives,
				material_plan = chapter.material_plan,
				-- Canon requirement only when finalized; otherwise empty for Wiki.
				required_material_tokens = (chapter.material_plan and chapter.material_plan.finalized == true)
					and (chapter.required_material_tokens or chapter.material_plan.confirmed)
					or {},
				material_tokens = chapter.material_tokens,
				wiki_visible = chapter.wiki_visible ~= false,
				notes = chapter.notes,
				nodes = nodes,
			}
			if include_development then
				chapter_payload.debug_override = chapter.debug_override
			end
			if defs.alchemy then
				chapter_payload.alchemy = defs.alchemy
			end
			chapters[#chapters + 1] = chapter_payload
		end
	end
	return {
		schema_version = defs.SCHEMA_VERSION,
		current_story_scope = defs.CURRENT_STORY_SCOPE,
		kinds = defs.KINDS,
		alchemy = defs.alchemy,
		excluded_from_chapter1 = defs.excluded_from_chapter1,
		chapters = chapters,
	}
end

return registry

local defs = require("Qing_Remaster_scripts.quest.quest_defs")

local registry = {
	defs = defs,
	main_by_id = {},
	main_by_objective = {},
	main_by_node = {},
	side_by_id = {},
}

for _, q in ipairs(defs.main or {}) do
	registry.main_by_id[q.id] = q
	local match = q.match or {}
	if type(match.objective) == "string" then
		registry.main_by_objective[match.objective] = q
	end
	-- Legacy: id used as objective key when no match table.
	if not match.objective and not match.node and type(q.id) == "string" then
		registry.main_by_objective[q.id] = q
	end
	if type(match.node) == "string" then
		registry.main_by_node[match.node] = q
	end
	-- Also allow listing multiple nodes.
	if type(match.nodes) == "table" then
		for _, node_id in ipairs(match.nodes) do
			if type(node_id) == "string" then
				registry.main_by_node[node_id] = q
			end
		end
	end
end
for _, q in ipairs(defs.side or {}) do
	registry.side_by_id[q.id] = q
end

local function pick_lang(tbl, lang)
	if type(tbl) ~= "table" then return tostring(tbl or "") end
	if lang == "en" then
		return tbl.en or tbl.zh or ""
	end
	return tbl.zh or tbl.en or ""
end

--- Map declarative character keys to Isaac PlayerType (prologue uses W.Qing / enums.Players.wq).
local function character_player_type(character_key)
	if character_key == "qing" then
		local enums = require("Qing_Remaster_scripts.core.enums")
		return enums.Players.wq
	end
	return nil
end

local function primary_player_matches(character_key)
	local want = character_player_type(character_key)
	if want == nil then
		return true
	end
	local player = Isaac.GetPlayer(0)
	if not player then
		return false
	end
	return player:GetPlayerType() == want
end

--- Declarative player_variant: keep Story node, swap Quest objective when run character cannot continue.
local function resolve_objective_text(def, lang)
	local base = pick_lang(def.objective, lang)
	local variant = def.player_variant
	if type(variant) ~= "table" or type(variant.character) ~= "string" then
		return base
	end
	if primary_player_matches(variant.character) then
		return base
	end
	local alt = variant.otherwise_objective
	if type(alt) == "table" then
		local text = pick_lang(alt, lang)
		if text ~= "" then
			return text
		end
	end
	return base
end

function registry.lang()
	local language = Options and Options.Language
	if language == "en" then return "en" end
	return "zh"
end

function registry.get_main(objective_id)
	return registry.main_by_objective[objective_id] or registry.main_by_id[objective_id]
end

function registry.get_side(node_id)
	return registry.side_by_id[node_id]
end

local SCOPE = {"prologue", "chapter1"}

local function chapter1_player_visible()
	local ok, scope = pcall(require, "Qing_Remaster_scripts.core.release_scope")
	if not ok or not scope or not scope.allows_story_chapter then
		return true
	end
	return scope.allows_story_chapter("chapter1") == true
end

local function chapter_status_open(story_state, chapter_id)
	if not story_state then return false end
	if story_state.is_chapter_available and story_state.is_chapter_available(chapter_id) then
		return true
	end
	if story_state.is_chapter_active and story_state.is_chapter_active(chapter_id) then
		return true
	end
	if story_state.is_chapter_completed and story_state.is_chapter_completed(chapter_id) then
		return true
	end
	return false
end

--- Once prologue or chapter1 has been unlocked/started/completed, Quest UI stays available.
--- Challenge runs: blocked (existing Story Quests are normal-run only).
function registry.is_quest_system_revealed(story_state)
	local scope = require("Qing_Remaster_scripts.quest.quest_run_scope")
	if not scope.allows_story_quests() then
		return false
	end
	if not story_state then return false end
	for _, chapter_id in ipairs(SCOPE) do
		if chapter_status_open(story_state, chapter_id) then
			return true
		end
	end
	return false
end

function registry.resolve_current_chapter(story_state)
	if not story_state then return nil end
	for _, chapter_id in ipairs(SCOPE) do
		if chapter_id == "chapter1" and not chapter1_player_visible() then
			-- keep looking; do not surface Chapter 1 in player Quest UI
		elseif story_state.is_chapter_active and story_state.is_chapter_active(chapter_id) then
			return chapter_id
		end
	end
	-- After prologue: chapter1 available while waiting for commission still counts as chapter1.
	if chapter1_player_visible()
		and story_state.is_chapter_completed and story_state.is_chapter_completed("prologue") then
		if story_state.is_chapter_available and story_state.is_chapter_available("chapter1") then
			return "chapter1"
		end
		if story_state.is_chapter_completed("chapter1") then
			return "chapter1"
		end
	end
	if story_state.is_chapter_available and story_state.is_chapter_available("prologue") then
		return "prologue"
	end
	return nil
end

local function chapter_title(chapter_id, lang)
	if not chapter_id then return "" end
	local ok, story_reg = pcall(require, "Qing_Remaster_scripts.story.story_registry")
	if ok and story_reg and story_reg.get_chapter then
		local ch = story_reg.get_chapter(chapter_id)
		if ch and ch.title then
			return pick_lang(ch.title, lang)
		end
	end
	if chapter_id == "prologue" then
		return (lang == "en") and "Prologue" or "序章"
	end
	if chapter_id == "chapter1" then
		return (lang == "en") and "Chapter 1" or "第一章"
	end
	return chapter_id
end

local function read_current_node(story_state, chapter_id)
	if not story_state or not chapter_id then return nil end
	if story_state.get_current_node then
		return story_state.get_current_node(chapter_id)
	end
	local ch = story_state.get_chapter and story_state.get_chapter(chapter_id, false)
	return ch and ch.current_node or nil
end

local function apply_progress(view, def, story_state)
	if not def.progress or def.progress.type ~= "story_materials" then
		return
	end
	local count = story_state.count_material_tokens and story_state.count_material_tokens() or 0
	local chapter = require("Qing_Remaster_scripts.story.story_registry").get_chapter("chapter1")
	local plan = chapter and chapter.material_plan
	local total = nil
	if plan and plan.finalized == true then
		total = plan.target_count or #((plan.confirmed) or {})
		view.progress_text = tostring(count) .. " / " .. tostring(total)
	else
		view.progress_text = tostring(count) .. " / ?"
	end
	view.progress = {
		current = count,
		total = total,
		text = view.progress_text,
	}
	view.progress_key = "materials:" .. tostring(count)
end

local function build_main_view(def, story_state, resolve_source)
	if not def then return nil end
	local scope = require("Qing_Remaster_scripts.quest.quest_run_scope")
	if not scope.allows_quest(def) then
		return nil
	end
	local lang = registry.lang()
	local notes = nil
	if type(def.panel_notes) == "table" then
		notes = {}
		for _, row in ipairs(def.panel_notes) do
			notes[#notes + 1] = pick_lang(row, lang)
		end
	end
	local view = {
		id = def.id,
		chapter = def.chapter,
		category = "main",
		toast_kind = def.toast_kind or "update",
		title = pick_lang(def.title, lang),
		objective = resolve_objective_text(def, lang),
		optional = def.optional == true,
		panel_notes = notes,
		progress_text = nil,
		progress_key = nil,
		progress = nil,
		resolve_source = resolve_source or "def",
	}
	apply_progress(view, def, story_state)
	return view
end

function registry.resolve_fallback_view(story_state, chapter_id, reason)
	local lang = registry.lang()
	local fb = defs.fallbacks or {}
	local def
	if chapter_id and story_state and story_state.is_chapter_completed
		and story_state.is_chapter_completed(chapter_id)
		and not (story_state.is_chapter_active and story_state.is_chapter_active(chapter_id)) then
		def = fb.completed
	elseif chapter_id and fb[chapter_id] then
		def = fb[chapter_id]
	else
		def = fb.unstarted or fb.prologue
	end
	local view = build_main_view(def, story_state, "fallback")
	if view then
		view.fallback_reason = reason or "unmapped"
		if chapter_id then
			view.chapter = chapter_id
		end
	end
	return view
end

--- Chapter1 unlocked, commission not accepted: no active Quest (HUD quiet / panel idle).
function registry.is_chapter1_waiting_commission(story_state)
	if not story_state then return false end
	local ch = story_state.get_chapter and story_state.get_chapter("chapter1", false)
	if type(ch) ~= "table" then return false end
	if story_state.get_flag and story_state.get_flag("chapter1", "commission_accepted") then
		return false
	end
	local available = story_state.STATUS and story_state.STATUS.AVAILABLE or "available"
	return ch.status == available
end

function registry.resolve_idle_view(story_state, chapter_id, reason)
	local fb = defs.fallbacks or {}
	local def = fb.idle or fb.unstarted
	local view = build_main_view(def, story_state, "idle")
	if view then
		view.fallback_reason = reason or "idle"
		view.idle = true
		if chapter_id then
			view.chapter = chapter_id
		end
	end
	return view
end

local function resolve_by_node(story_state, chapter_id)
	local node = read_current_node(story_state, chapter_id)
	if not node then return nil, nil end
	-- Soft aliases for gaps between Story nodes.
	if chapter_id == "prologue" and node == nil then
		return nil, nil
	end
	local def = registry.main_by_node[node]
	if def then
		return build_main_view(def, story_state, "node"), node
	end
	return nil, node
end

local function resolve_by_objective(story_state, chapter_id)
	if not story_state.get_objective then return nil, nil end
	local objective_id = story_state.get_objective(chapter_id)
	if not objective_id then return nil, nil end
	local def = registry.main_by_objective[objective_id]
	if def then
		return build_main_view(def, story_state, "objective"), objective_id
	end
	return nil, objective_id
end

function registry.resolve_main_view(story_state)
	if not story_state then return nil end
	if not registry.is_quest_system_revealed(story_state) then
		return nil
	end

	local chapter_id = registry.resolve_current_chapter(story_state)

	-- Chapter fully completed and no further chapter active: completion card.
	if chapter_id == "chapter1"
		and story_state.is_chapter_completed
		and story_state.is_chapter_completed("chapter1")
		and not (story_state.is_chapter_active and story_state.is_chapter_active("chapter1")) then
		local node = read_current_node(story_state, "chapter1")
		if node == "chapter1.complete" or node == nil then
			local done = registry.main_by_node["chapter1.complete"]
			if done then
				local view = build_main_view(done, story_state, "node")
				view.title = (registry.lang() == "en") and "Chapter 1 Complete" or "第一章 完成"
				view.objective = (registry.lang() == "en") and "No new objectives yet" or "当前没有新的目标"
				view.chapter_complete = true
				return view
			end
			return registry.resolve_fallback_view(story_state, "chapter1", "chapter_complete")
		end
	end

	if not chapter_id then
		return registry.resolve_fallback_view(story_state, nil, "no_chapter")
	end

	-- Chapter1 unlocked but commission not started: no active quest (quiet waiting).
	if chapter_id == "chapter1" and registry.is_chapter1_waiting_commission(story_state) then
		local ch = story_state.get_chapter and story_state.get_chapter("chapter1", false)
		if ch
			and ch.current_node == nil
			and (ch.objective == nil or ch.objective == "") then
			return nil
		end
		-- AVAILABLE without commission: never invent a Quest even if node leftover.
		return nil
	end

	-- Prefer node (more specific player-facing stage), then objective, then fallback.
	local node = read_current_node(story_state, chapter_id)
	local view = select(1, resolve_by_node(story_state, chapter_id))
	if view then
		local def = registry.main_by_id and registry.main_by_id[view.id]
		if def and def.runtime_visible == false then
			-- Skip legacy invisible defs; keep resolving.
		else
			return view
		end
	end

	view = select(1, resolve_by_objective(story_state, chapter_id))
	if view then
		local def = registry.main_by_id and registry.main_by_id[view.id]
		if not (def and def.runtime_visible == false) then
			return view
		end
	end

	-- AVAILABLE waiting must not fall through to chapter1.fallback fake objective.
	if chapter_id == "chapter1" and registry.is_chapter1_waiting_commission(story_state) then
		return nil
	end

	return registry.resolve_fallback_view(story_state, chapter_id, "unmapped:" .. tostring(node or "?"))
end

local SIDE_ORDER = {
	"chapter1.coin",
	"chapter1.glaze",
	"chapter1.stone",
	"chapter1.wind",
	"chapter1.phase_anchor",
}

local STAGE_ALIASES = {
	discovered = "discovered",
	progressing = "progressing",
	deep = "progressing",
	climax = "climax",
	boss = "climax",
}

local STAGE_FALLBACK = {"climax", "progressing", "discovered"}

local function normalize_stage_key(reported)
	if type(reported) ~= "string" then return nil end
	return STAGE_ALIASES[reported] or reported
end

local function stage_from_keyed(stages, key)
	if type(stages) ~= "table" or not key then return nil end
	local entry = stages[key]
	if type(entry) == "table" and entry.objective then
		return entry, key
	end
	return nil
end

local function stage_from_array(stages, key)
	if type(stages) ~= "table" then return nil end
	for _, stage in ipairs(stages) do
		if type(stage) == "table" then
			local when = normalize_stage_key(stage.when)
			if when == key then
				return stage, when
			end
		end
	end
	return nil
end

local function first_available_stage(stages)
	if type(stages) ~= "table" then return nil end
	for _, key in ipairs(STAGE_FALLBACK) do
		local stage = stage_from_keyed(stages, key)
		if stage then return stage, key end
	end
	for _, key in ipairs(STAGE_FALLBACK) do
		local stage = stage_from_array(stages, key)
		if stage then return stage, key end
	end
	if stages[1] and type(stages[1]) == "table" then
		return stages[1], normalize_stage_key(stages[1].when) or "discovered"
	end
	return nil
end

local function pick_side_stage(def, node_id, story_state)
	local stages = def.stages or {}
	local reported = story_state.get_event_stage and story_state.get_event_stage("chapter1", node_id)
	local key = normalize_stage_key(reported) or "discovered"
	local stage = stage_from_keyed(stages, key)
	if stage then return stage, key end
	stage = stage_from_array(stages, key)
	if stage then return stage, key end
	local order = {discovered = 1, progressing = 2, climax = 3}
	local want = order[key] or 1
	local best, best_key, best_rank = nil, nil, -1
	local function consider(st, st_key)
		if not st then return end
		local rank = order[st_key] or 0
		if rank <= want and rank > best_rank then
			best, best_key, best_rank = st, st_key, rank
		end
	end
	for st_key, st in pairs(stages) do
		if type(st_key) == "string" and type(st) == "table" then
			consider(st, normalize_stage_key(st_key) or st_key)
		end
	end
	for _, st in ipairs(stages) do
		if type(st) == "table" then
			consider(st, normalize_stage_key(st.when) or "discovered")
		end
	end
	if best then return best, best_key end
	return first_available_stage(stages)
end

local function build_side_view(def, node_id, story_state, lang)
	local scope = require("Qing_Remaster_scripts.quest.quest_run_scope")
	if not scope.allows_quest(def) then
		return nil
	end
	local stage, stage_key = pick_side_stage(def, node_id, story_state)
	return {
		id = def.id,
		category = def.category,
		title = pick_lang(def.title, lang),
		objective = stage and pick_lang(stage.objective, lang) or "",
		stage = stage_key or "discovered",
	}
end

function registry.resolve_side_views(story_state)
	local list = {}
	if not story_state or not story_state.is_discovered then return list end
	if not registry.is_quest_system_revealed(story_state) then return list end
	local lang = registry.lang()
	for _, node_id in ipairs(SIDE_ORDER) do
		local def = registry.get_side(node_id)
		if def
			and story_state.is_discovered("chapter1", node_id)
			and not (story_state.is_node_completed and story_state.is_node_completed("chapter1", node_id)) then
			local view = build_side_view(def, node_id, story_state, lang)
			if view then
				list[#list + 1] = view
			end
		end
	end
	return list
end

local function choose_priority_side(all)
	if type(all) ~= "table" or #all == 0 then return nil end
	return all[1]
end

function registry.resolve_side_view(story_state)
	return choose_priority_side(registry.resolve_side_views(story_state))
end

function registry.resolve_material_details(story_state)
	local details = {}
	if not story_state then return details end
	local chapter = require("Qing_Remaster_scripts.story.story_registry").get_chapter("chapter1")
	local plan = chapter and chapter.material_plan
	local tokens = {}
	if plan and type(plan.confirmed) == "table" and #plan.confirmed > 0 then
		tokens = plan.confirmed
	else
		tokens = story_state.get_runtime_material_requirement and story_state.get_runtime_material_requirement() or {}
	end
	local lang = registry.lang()
	local labels = defs.material_labels or {}
	for _, token in ipairs(tokens) do
		local meta = labels[token] or {}
		local node_id = meta.node
		local owned = story_state.has_token and story_state.has_token("chapter1", token) == true
		local discovered = node_id
			and story_state.is_discovered
			and story_state.is_discovered("chapter1", node_id) == true
		local state
		local title
		if owned then
			state = "completed"
			title = pick_lang(meta.title or meta.completed, lang)
		elseif discovered then
			state = "known"
			title = pick_lang(meta.title or meta.discovered, lang)
		else
			state = "unknown"
			title = pick_lang(meta.hidden_title or meta.undiscovered, lang)
			if title == "" then
				title = (lang == "en") and "Unknown Material" or "未知素材"
			end
		end
		details[#details + 1] = {
			id = meta.id or token,
			token = token,
			title = title,
			state = state,
		}
	end
	return details
end

local function completed_chapter_rows(story_state, lang)
	local rows = {}
	if not story_state or not story_state.is_chapter_completed then return rows end
	for _, chapter_id in ipairs(SCOPE) do
		if story_state.is_chapter_completed(chapter_id) then
			rows[#rows + 1] = {
				id = chapter_id,
				title = chapter_title(chapter_id, lang),
			}
		end
	end
	return rows
end

--- Full pause-panel payload. Never nil while quest system is revealed.
function registry.resolve_panel_view(story_state)
	if not registry.is_quest_system_revealed(story_state) then
		return nil
	end
	local lang = registry.lang()
	local chapter_id = registry.resolve_current_chapter(story_state)
	local main = registry.resolve_main_view(story_state)
	if not main then
		-- Waiting for commission: show idle, never chapter1.fallback fake objective.
		if chapter_id == "chapter1" and registry.is_chapter1_waiting_commission(story_state) then
			main = registry.resolve_idle_view(story_state, chapter_id, "waiting_commission")
		else
			main = registry.resolve_idle_view(story_state, chapter_id, "empty_main")
				or registry.resolve_fallback_view(story_state, chapter_id, "empty_main")
		end
	end
	local sides = registry.resolve_side_views(story_state)
	local details = nil
	local show_materials = main
		and (main.id == "chapter1.collect_materials"
			or main.id == "chapter1.prepare_alchemy"
			or (main.progress and main.progress.current ~= nil))
	if show_materials then
		details = registry.resolve_material_details(story_state)
	end
	return {
		chapter_id = chapter_id,
		chapter_title = chapter_title(chapter_id, lang),
		main = {
			id = main.id,
			title = main.title,
			objective = main.objective,
			progress = main.progress,
			details = details,
			panel_notes = main.panel_notes,
			resolve_source = main.resolve_source,
			chapter_complete = main.chapter_complete == true,
			fallback_reason = main.fallback_reason,
			idle = main.idle == true,
		},
		sides = sides,
		completed_chapters = completed_chapter_rows(story_state, lang),
	}
end

--- Alias used by HUD/tracker consumers.
function registry.resolve_current_view(story_state)
	return registry.resolve_main_view(story_state)
end

function registry.audit_coverage()
	local report = {
		ok = true,
		chapters = {},
		missing = {},
		warnings = {},
	}
	local spine = defs.audit_spine or {}
	for chapter_id, nodes in pairs(spine) do
		local rows = {}
		for _, node_id in ipairs(nodes) do
			local mapped = registry.main_by_node[node_id] ~= nil
			-- commission / material_phase also covered via objective / match.nodes.
			if not mapped then
				for _, def in pairs(registry.main_by_id) do
					local m = def.match or {}
					if m.node == node_id then
						mapped = true
						break
					end
					if type(m.nodes) == "table" then
						for _, nid in ipairs(m.nodes) do
							if nid == node_id then
								mapped = true
								break
							end
						end
						if mapped then break end
					end
				end
			end
			rows[#rows + 1] = {node = node_id, mapped = mapped}
			if not mapped then
				report.ok = false
				report.missing[#report.missing + 1] = node_id
				report.warnings[#report.warnings + 1] =
					"Story node has no Quest definition: " .. node_id
			end
		end
		report.chapters[chapter_id] = rows
	end
	return report
end

function registry.get_export_metadata()
	return {
		schema_version = defs.SCHEMA_VERSION,
		main = defs.main,
		side = defs.side,
		fallbacks = defs.fallbacks,
		material_labels = defs.material_labels,
		audit_spine = defs.audit_spine,
	}
end

return registry

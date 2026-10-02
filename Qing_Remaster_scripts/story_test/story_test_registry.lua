local defs = require("Qing_Remaster_scripts.story_test.story_test_defs")
local story_defs = require("Qing_Remaster_scripts.story.story_defs")
local story_registry = require("Qing_Remaster_scripts.story.story_registry")

local registry = {
	defs = defs,
	steps_by_id = {},
	steps_by_chapter = {},
	audit = {info = {}, warning = {}, error = {}},
}

for _, step in ipairs(defs.steps or {}) do
	registry.steps_by_id[step.id] = step
	local ch = step.chapter or "unknown"
	registry.steps_by_chapter[ch] = registry.steps_by_chapter[ch] or {}
	registry.steps_by_chapter[ch][#registry.steps_by_chapter[ch] + 1] = step
end

local function note(severity, msg)
	local bucket = registry.audit[severity]
	if not bucket then bucket = registry.audit.warning end
	bucket[#bucket + 1] = msg
end

local VALID_TOKENS = {}
do
	local alchemy = story_defs.alchemy or {}
	for _, p in ipairs(alchemy.properties or {}) do
		if p.token then VALID_TOKENS[p.token] = true end
	end
	if alchemy.machine and alchemy.machine.token then
		VALID_TOKENS[alchemy.machine.token] = true
	end
end

function registry.get_canonical_material_route()
	local route = (story_defs.alchemy and story_defs.alchemy.canonical_material_route) or {}
	local out = {}
	for i, token in ipairs(route) do
		out[i] = token
	end
	return out
end

function registry.get_material_node_map()
	local map = {}
	local alchemy = story_defs.alchemy or {}
	for _, p in ipairs(alchemy.properties or {}) do
		if p.token and p.event then
			map[p.token] = p.event
		end
	end
	if alchemy.machine and alchemy.machine.token and alchemy.machine.event then
		map[alchemy.machine.token] = alchemy.machine.event
	end
	return map
end

function registry.material_tokens_before(count)
	local route = registry.get_canonical_material_route()
	local out = {}
	local n = math.max(0, tonumber(count) or 0)
	for i = 1, math.min(n, #route) do
		out[#out + 1] = route[i]
	end
	return out
end

function registry.material_nodes_for_tokens(tokens)
	local map = registry.get_material_node_map()
	local out = {}
	for _, token in ipairs(tokens or {}) do
		local node = map[token]
		if node then out[#out + 1] = node end
	end
	return out
end

local THREAD_PATH = {
	wind = "Qing_Remaster_scripts.threads.thread_Wind",
	stone = "Qing_Remaster_scripts.threads.thread_Stone",
	coin = "Qing_Remaster_scripts.threads.thread_Coin",
	glaze = "Qing_Remaster_scripts.threads.thread_Glaze",
	ending1 = "Qing_Remaster_scripts.threads.thread_End1",
	ending2 = "Qing_Remaster_scripts.threads.thread_End2",
}

local function has_adapter_method(thread_id, method)
	local path = THREAD_PATH[thread_id]
	if not path then return false end
	local ok, mod = pcall(require, path)
	if not ok or type(mod) ~= "table" or type(mod.story_test) ~= "table" then
		return false
	end
	return type(mod.story_test[method]) == "function"
end

function registry.validate_all()
	registry.audit = {info = {}, warning = {}, error = {}}
	local scenes_ok, scenes = pcall(require, "Qing_Remaster_scripts.story.story_scenes")
	for _, step in ipairs(defs.steps or {}) do
		if step.story_node and not story_registry.get_node(step.story_node) then
			note("error", "step " .. step.id .. " missing story_node " .. tostring(step.story_node))
		end
		local obj = step.story and step.story.objective
		if obj and step.chapter == "chapter1" then
			local ch = story_registry.get_chapter("chapter1")
			local found = false
			for _, oid in ipairs((ch and ch.objectives) or {}) do
				if oid == obj then found = true break end
			end
			if not found then
				note("error", "step " .. step.id .. " unknown objective " .. tostring(obj))
			end
		end
		local function check_tokens(list, label)
			for _, token in ipairs(list or {}) do
				if not VALID_TOKENS[token] then
					note("error", "step " .. step.id .. " invalid " .. label .. " " .. tostring(token))
				end
			end
		end
		if step.story then
			check_tokens(step.story.tokens, "token")
			check_tokens(step.story.absent_tokens, "absent_token")
		end
		check_tokens(step.force_tokens, "force_token")
		if step.expected and step.expected.side_event then
			if not story_registry.get_node(step.expected.side_event) then
				note("error", "step " .. step.id .. " bad side_event " .. tostring(step.expected.side_event))
			end
		end
		if step.level_preset and not defs.LEVEL_PRESETS[step.level_preset] then
			note("error", "step " .. step.id .. " unknown level_preset " .. tostring(step.level_preset))
		end
		local status = step.implementation_status or "implemented"
		if status == "implemented" and step.thread and step.thread.phase then
			if not has_adapter_method(step.thread.id, "prepare") then
				note("error", "step " .. step.id .. " implemented but thread adapter.prepare missing")
			end
		elseif status == "partial" and step.thread and step.thread.id then
			if not has_adapter_method(step.thread.id, "prepare") then
				note("warning", "step " .. step.id .. " partial without adapter.prepare")
			end
		end
		if status == "implemented" and step.entry and step.entry.mode == "direct_scene" then
			if not (scenes_ok and scenes and scenes.is_available(step.entry.scene)) then
				note("error", "step " .. step.id .. " implemented direct_scene but scene not wired")
			end
		elseif step.entry and step.entry.mode == "direct_scene" then
			note("warning", "step " .. step.id .. " scene not wired: " .. tostring(step.entry.scene))
		end
		if status == "planned" then
			note("info", "step " .. step.id .. " planned")
		end
	end
	return registry.audit
end

function registry.audit_summary()
	local a = registry.audit
	return {
		errors = #(a.error or {}),
		warnings = #(a.warning or {}),
		infos = #(a.info or {}),
		valid_steps = #(defs.steps or {}) - #(a.error or {}),
		total = #(defs.steps or {}),
	}
end

function registry.step_has_errors(step_id)
	for _, msg in ipairs(registry.audit.error or {}) do
		if msg:find(step_id, 1, true) then return true end
	end
	return false
end

function registry.get_step(id)
	return registry.steps_by_id[id]
end

function registry.list_chapters()
	local seen = {}
	local out = {}
	for _, step in ipairs(defs.steps or {}) do
		if step.chapter and not seen[step.chapter] then
			seen[step.chapter] = true
			out[#out + 1] = step.chapter
		end
	end
	return out
end

function registry.list_steps(chapter_id)
	if chapter_id then
		return registry.steps_by_chapter[chapter_id] or {}
	end
	return defs.steps or {}
end

function registry.get_level_preset(id)
	return defs.LEVEL_PRESETS[id]
end

function registry.pick_lang(tbl, lang)
	if type(tbl) ~= "table" then return tostring(tbl or "") end
	if lang == "en" then return tbl.en or tbl.zh or "" end
	return tbl.zh or tbl.en or ""
end

function registry.lang()
	local language = Options and Options.Language
	if language == "en" then return "en" end
	return "zh"
end

function registry.step_capabilities(step)
	if not step then return {} end
	local status = step.implementation_status or "implemented"
	local entry = step.entry or {}
	local has_prepare = true
	local has_transport = entry.mode == "natural" or entry.mode == "direct"
	local has_thread = step.thread and has_adapter_method(step.thread.id, "prepare")
	local has_scene = entry.mode == "direct_scene" and entry.scene
	local scenes_ok, scenes = pcall(require, "Qing_Remaster_scripts.story.story_scenes")
	local scene_wired = has_scene and scenes_ok and scenes.is_available(entry.scene)
	local has_transition = scenes_ok and scenes.transitions and (
		(has_scene and scenes.transitions[entry.scene])
		or (step.story_node and scenes.transitions[step.story_node])
	)
	return {
		state_prepare = has_prepare,
		transport = has_transport and status ~= "planned",
		thread_prepare = has_thread == true,
		play_scene = scene_wired == true,
		state_transition = has_transition == true,
		validation = step.expected ~= nil or step.expected_after_complete ~= nil,
		repeatable = step.repeatable ~= false,
		status = status,
	}
end

-- ── Display metadata (中文优先；ID 保持原样由 UI 另显) ──────────────

local DISPLAY = {
	result = {
		ok = {zh = "正常", en = "OK"},
		partial = {zh = "部分完成", en = "Partial"},
		blocked = {zh = "阻塞", en = "Blocked"},
		wip = {zh = "开发中", en = "WIP"},
	},
	result_mark = {
		ok = "✓",
		partial = "△",
		blocked = "✗",
		wip = "…",
	},
	status = {
		implemented = {zh = "已实装", en = "Implemented"},
		partial = {zh = "部分实装", en = "Partial"},
		planned = {zh = "计划中", en = "Planned"},
		wip = {zh = "开发中", en = "WIP"},
	},
	entry = {
		state_only = {zh = "仅设置状态", en = "State only"},
		natural = {zh = "自然流程", en = "Natural"},
		direct = {zh = "直接进入", en = "Direct"},
		direct_scene = {zh = "剧情场景", en = "Direct scene"},
		boss_glaze = {zh = "琉璃 Boss 测试", en = "Glaze boss test"},
	},
	runtime_kind = {
		state = {zh = "状态推进", en = "State"},
		natural = {zh = "自然流程", en = "Natural"},
		direct = {zh = "直接进入", en = "Direct"},
		scene = {zh = "剧情场景", en = "Scene"},
		thread = {zh = "线程入口", en = "Thread"},
		boss = {zh = "Boss 战", en = "Boss"},
	},
	resolve_source = {
		node = {zh = "剧情节点", en = "Story node"},
		objective = {zh = "Story 目标", en = "Story objective"},
		fallback = {zh = "后备文案", en = "Fallback"},
		revealed = {zh = "初始揭示状态", en = "Revealed"},
		def = {zh = "任务定义", en = "Quest def"},
	},
	validation = {
		objective = {zh = "剧情目标", en = "Story objective"},
		current_node = {zh = "当前节点", en = "Current node"},
		material_count = {zh = "素材数量", en = "Material count"},
		token = {zh = "Story Token", en = "Story Token"},
		token_absent = {zh = "Token 应不存在", en = "Token should be absent"},
		flag = {zh = "剧情标记", en = "Story flag"},
		flag_absent = {zh = "标记应不存在", en = "Flag should be absent"},
		side_discovered = {zh = "支线发现状态", en = "Side discovered"},
		node_completed = {zh = "节点完成状态", en = "Node completed"},
		chapter_status = {zh = "章节状态", en = "Chapter status"},
		quest_resolves = {zh = "Quest 解析", en = "Quest resolves"},
		transport_stage = {zh = "传送楼层", en = "Transport stage"},
		transport_stage_type = {zh = "传送 StageType", en = "Transport stage type"},
		transport_readiness = {zh = "传送就绪度", en = "Transport readiness"},
	},
	blocker = {
		story_undefined = {zh = "Story 节点未定义", en = "Story node undefined"},
		test_undefined = {zh = "测试步骤未定义", en = "Test step undefined"},
		prepare_missing = {zh = "测试状态无法准备", en = "State prepare missing"},
		runtime_entry_missing = {zh = "正式运行入口未接线", en = "Runtime entry missing"},
		scene_not_wired = {zh = "正式剧情场景尚未接线", en = "Formal story scene not wired"},
		completion_missing = {zh = "完成后的剧情推进缺失", en = "Completion transition missing"},
		quest_unmapped = {zh = "Quest 未映射", en = "Quest unmapped"},
		next_missing = {zh = "下一节点缺失", en = "Next node missing"},
	},
	side_stage = {
		discovered = {zh = "发现", en = "Discovered"},
		progressing = {zh = "推进中", en = "Progressing"},
		climax = {zh = "高潮", en = "Climax"},
		complete = {zh = "完成", en = "Complete"},
	},
	wired = {
		[true] = {zh = "已接线", en = "Wired"},
		[false] = {zh = "未接线", en = "Missing"},
	},
	pass = {
		[true] = {zh = "通过", en = "Pass"},
		[false] = {zh = "未通过", en = "Fail"},
	},
	bool = {
		[true] = {zh = "是", en = "Yes"},
		[false] = {zh = "否", en = "No"},
	},
}

registry.DISPLAY = DISPLAY

local STATUS_RANK = {
	implemented = 1,
	partial = 2,
	planned = 3,
	wip = 4,
}

local function worse_status(a, b)
	a = a or "implemented"
	b = b or "implemented"
	if (STATUS_RANK[b] or 1) > (STATUS_RANK[a] or 1) then
		return b
	end
	return a
end

function registry.display(category, key, lang)
	lang = lang or registry.lang()
	local map = DISPLAY[category]
	if not map then return tostring(key or "") end
	local entry = map[key]
	if entry == nil and (key == true or key == false) then
		entry = map[key]
	end
	if type(entry) == "table" then
		return registry.pick_lang(entry, lang)
	end
	if type(entry) == "string" then
		return entry
	end
	return tostring(key or "")
end

function registry.result_mark(result)
	return DISPLAY.result_mark[result] or "?"
end

local function load_scenes()
	local ok, scenes = pcall(require, "Qing_Remaster_scripts.story.story_scenes")
	if ok then return scenes end
	return nil
end

local function load_quest_registry()
	local ok, qr = pcall(require, "Qing_Remaster_scripts.quest.quest_registry")
	if ok then return qr end
	return nil
end

local function load_story_state()
	local ok, st = pcall(require, "Qing_Remaster_scripts.story.story_state")
	if ok then return st end
	return nil
end

function registry.steps_for_story_node(node_id)
	local out = {}
	if not node_id then return out end
	for _, step in ipairs(defs.steps or {}) do
		if step.story_node == node_id then
			out[#out + 1] = step
		end
	end
	return out
end

--- Prefer exact step id, then .complete / .discover / first.
function registry.primary_test_step(node_id)
	local steps = registry.steps_for_story_node(node_id)
	if #steps == 0 then return nil end
	for _, step in ipairs(steps) do
		if step.id == node_id then return step end
	end
	for _, step in ipairs(steps) do
		if type(step.id) == "string" and step.id:find("%.complete$") then
			return step
		end
	end
	for _, step in ipairs(steps) do
		if type(step.id) == "string" and step.id:find("%.discover$") then
			return step
		end
	end
	return steps[1]
end

local function aggregated_impl_status(node, steps)
	local status = (node and node.implementation_status) or nil
	for _, step in ipairs(steps or {}) do
		status = worse_status(status, step.implementation_status or "implemented")
	end
	return status or "implemented"
end

local function count_quest_stages(side_def)
	if not side_def or type(side_def.stages) ~= "table" then return 0 end
	local n = 0
	local seen = {}
	for key, entry in pairs(side_def.stages) do
		if type(key) == "string" and type(entry) == "table" and entry.objective and not seen[key] then
			seen[key] = true
			n = n + 1
		elseif type(key) == "number" and type(entry) == "table" and entry.objective then
			local when = entry.when or ("#" .. tostring(key))
			if not seen[when] then
				seen[when] = true
				n = n + 1
			end
		end
	end
	return n
end

local function quest_mapped_for_node(node_id, node)
	local qr = load_quest_registry()
	if not qr then return false end
	if qr.main_by_node and qr.main_by_node[node_id] then return true end
	if qr.get_side and qr.get_side(node_id) then return true end
	-- Side / hidden / puzzle events only need side mapping.
	if node and (node.kind == "side_event" or node.kind == "hidden_event"
		or node.kind == "technology_puzzle") then
		return qr.get_side and qr.get_side(node_id) ~= nil
	end
	return false
end

local function eval_runtime_entry(step, status, scenes)
	local entry = (step and step.entry) or {mode = "state_only"}
	local mode = entry.mode or "state_only"
	local kind = "state"
	local ready = false

	if mode == "direct_scene" then
		kind = "scene"
		ready = scenes ~= nil and entry.scene ~= nil and scenes.is_available(entry.scene) == true
	elseif mode == "boss_glaze" then
		kind = "boss"
		ready = status == "implemented" or status == "partial"
	elseif mode == "natural" then
		kind = "natural"
		if step and step.thread and step.thread.id then
			kind = "thread"
			ready = has_adapter_method(step.thread.id, "prepare") and status ~= "planned"
		else
			ready = status == "implemented" or status == "partial"
		end
	elseif mode == "direct" then
		kind = "direct"
		if step and step.thread and step.thread.id then
			kind = "thread"
			ready = has_adapter_method(step.thread.id, "prepare") and status ~= "planned"
		else
			ready = status ~= "planned" and status ~= "wip"
		end
	else
		-- state_only: formal path is story progression / state write.
		kind = "state"
		if status == "planned" or status == "wip" then
			ready = false
		else
			ready = true
		end
	end

	return kind, ready, mode
end

local function eval_completion(node_id, step, scenes)
	if scenes and scenes.transitions then
		if scenes.transitions[node_id] then return true end
		local scene = step and step.entry and step.entry.scene
		if scene and scenes.transitions[scene] then return true end
	end
	if step and step.expected_after_complete then return true end
	-- Side-event complete steps encode completion via expected.
	if step and type(step.id) == "string" and step.id:find("%.complete$") and step.expected then
		return true
	end
	local node = story_registry.get_node(node_id)
	if node and node.kind == "chapter_end" then return true end
	if node and node.next and story_registry.get_node(node.next) then
		-- Soft: linear spine can advance by completing current.
		local status = (step and step.implementation_status) or (node.implementation_status) or "implemented"
		if status == "implemented" or status == "partial" then
			return true
		end
	end
	return false
end

local function primary_blocker_reason(row)
	for _, key in ipairs(row.blockers or {}) do
		if key == "scene_not_wired" or key == "runtime_entry_missing" then
			return key
		end
	end
	if row.blockers and row.blockers[1] then
		return row.blockers[1]
	end
	return nil
end

--- Static / capability audit for one Story node. Does not mutate Story state.
function registry.audit_story_node(node_id)
	local node = story_registry.get_node(node_id)
	local steps = registry.steps_for_story_node(node_id)
	local step = registry.primary_test_step(node_id)
	local scenes = load_scenes()
	local status = aggregated_impl_status(node, steps)

	local story_defined = node ~= nil
	local test_defined = #steps > 0
	local quest_mapped = quest_mapped_for_node(node_id, node)

	local prepare_ready = false
	local runtime_kind, runtime_entry_ready, entry_mode
	if step then
		prepare_ready = true
		runtime_kind, runtime_entry_ready, entry_mode = eval_runtime_entry(step, status, scenes)
	elseif story_defined then
		-- Container / spine node without dedicated test step.
		prepare_ready = true
		entry_mode = "natural"
		runtime_kind = "natural"
		runtime_entry_ready = status ~= "planned" and status ~= "wip"
	else
		prepare_ready = false
		entry_mode = nil
		runtime_kind = "state"
		runtime_entry_ready = false
	end

	local completion_ready = eval_completion(node_id, step, scenes)
	local quest_ready = quest_mapped

	local next_ready = true
	if node then
		if node.next then
			next_ready = story_registry.get_node(node.next) ~= nil
		elseif node.kind == "side_event" or node.kind == "hidden_event"
			or node.kind == "technology_puzzle" or node.kind == "boss" then
			next_ready = true
		elseif node.kind == "chapter_end" then
			next_ready = true
		elseif not node.next then
			-- Main spine without next is incomplete unless chapter_end.
			next_ready = node.kind ~= "main"
		end
	else
		next_ready = false
	end

	local blockers = {}
	if not story_defined then blockers[#blockers + 1] = "story_undefined" end
	if not test_defined and story_defined then
		local kind = node and node.kind
		-- Side events should have test coverage; main containers may omit.
		if kind == "side_event" or kind == "hidden_event" or kind == "technology_puzzle"
			or kind == "boss" then
			blockers[#blockers + 1] = "test_undefined"
		end
	end
	if not prepare_ready then blockers[#blockers + 1] = "prepare_missing" end
	if not runtime_entry_ready then
		if entry_mode == "direct_scene" then
			blockers[#blockers + 1] = "scene_not_wired"
		else
			blockers[#blockers + 1] = "runtime_entry_missing"
		end
	end
	if not completion_ready then blockers[#blockers + 1] = "completion_missing" end
	if not quest_ready then blockers[#blockers + 1] = "quest_unmapped" end
	if not next_ready then blockers[#blockers + 1] = "next_missing" end

	local result
	if status == "wip" then
		result = "wip"
	elseif #blockers == 0 then
		result = "ok"
	elseif status == "partial"
		or (prepare_ready and runtime_entry_ready and (#blockers > 0)) then
		result = "partial"
	elseif not runtime_entry_ready or status == "planned" or not story_defined then
		result = "blocked"
	else
		result = "partial"
	end

	local qr = load_quest_registry()
	local side_def = qr and qr.get_side and qr.get_side(node_id) or nil
	local event_stage = nil
	local stage_keys = nil
	if side_def and count_quest_stages(side_def) > 0 then
		stage_keys = {"discovered", "progressing", "climax"}
		local st = load_story_state()
		if st and st.get_event_stage then
			event_stage = st.get_event_stage(node and node.chapter or "chapter1", node_id)
		end
	end

	local row = {
		node_id = node_id,
		chapter = node and node.chapter or (step and step.chapter) or nil,
		title = node and node.title or (step and step.label) or nil,
		kind = node and node.kind or nil,

		story_defined = story_defined,
		quest_mapped = quest_mapped,
		test_defined = test_defined,

		prepare_ready = prepare_ready,
		runtime_entry_ready = runtime_entry_ready,
		completion_ready = completion_ready,
		quest_ready = quest_ready,
		next_ready = next_ready,

		runtime_kind = runtime_kind,
		entry_mode = entry_mode,
		implementation_status = status,
		primary_test_step = step and step.id or nil,

		result = result,
		blockers = blockers,
		primary_blocker = primary_blocker_reason({blockers = blockers}),

		event_stage = event_stage,
		quest_stages = stage_keys,
	}
	return row
end

function registry.audit_story_flow(chapter_id)
	chapter_id = chapter_id or "chapter1"
	local nodes = story_registry.list_nodes(chapter_id)
	local rows = {}
	local counts = {ok = 0, partial = 0, blocked = 0, wip = 0, total = 0}
	for _, node in ipairs(nodes) do
		local row = registry.audit_story_node(node.id)
		rows[#rows + 1] = row
		counts.total = counts.total + 1
		if counts[row.result] ~= nil then
			counts[row.result] = counts[row.result] + 1
		end
	end
	return {
		chapter = chapter_id,
		nodes = rows,
		counts = counts,
	}
end

--- Flow-oriented checks for the currently selected test step (maps to its story_node).
function registry.flow_checks_for_step(step)
	if not step then return nil end
	local node_id = step.story_node or step.id
	return registry.audit_story_node(node_id)
end

-- Keep defs.MATERIAL_ROUTE as derived aliases for older callers.
defs.MATERIAL_ROUTE = registry.get_canonical_material_route()
defs.MATERIAL_NODES = registry.get_material_node_map()

registry.validate_all()

return registry

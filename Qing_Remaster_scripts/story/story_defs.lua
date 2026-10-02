-- Declarative Story / Chapter definitions.
-- Thread runtime stays gameplay-only; this file must not hold callbacks.

local defs = {
	SCHEMA_VERSION = 7,
	-- Current narrative implementation scope only.
	CURRENT_STORY_SCOPE = {"prologue", "chapter1"},
	KINDS = {
		MAIN = "main",
		SIDE_EVENT = "side_event",
		HIDDEN_EVENT = "hidden_event",
		TECHNOLOGY_PUZZLE = "technology_puzzle",
		BOSS = "boss",
		REVELATION = "revelation",
		CHAPTER_END = "chapter_end",
	},
	CHAPTER_STATUS = {
		LOCKED = "locked",
		AVAILABLE = "available",
		ACTIVE = "active",
		COMPLETED = "completed",
	},
}

-- Alchemy: 1 Catalyst + 4 Properties + 1 Machine.
-- Catalyst is prologue-owned (Glaze holds Beast Residue); not part of chapter1 5/5.
-- Material ownership lives on chapter1.material_phase (and its child event nodes).
defs.alchemy = {
	schema = "catalyst_properties_machine",
	owner = {
		chapter = "chapter1",
		node = "chapter1.material_phase",
	},
	catalyst = {
		id = "prologue.beast_residue",
		holder = "glaze",
		role = "catalyst",
		counts_toward_chapter1 = false,
		notes = {
			zh = "祸兽残余。撕开世界边界的核心驱动力。序章由琉璃取得，不计入第一章 5/5。",
			en = "Beast Residue. Cross-world catalyst. Taken by Glaze in the prologue; not part of chapter1 5/5.",
		},
	},
	properties = {
		{token = "chapter1.material.coin", property = "exchange", event = "chapter1.coin"},
		{token = "chapter1.material.glaze", property = "mapping", event = "chapter1.glaze"},
		{token = "chapter1.material.stone", property = "structure", event = "chapter1.stone"},
		{token = "chapter1.material.wind", property = "direction", event = "chapter1.wind"},
	},
	machine = {
		token = "chapter1.material.phase_anchor",
		role = "stabilization",
		event = "chapter1.phase_anchor",
		-- Token = calibration/machine-ready flag, NOT a portable inventory material.
		reward_provisional = {zh = "完成相位锚校准", en = "Complete Phase Anchor Calibration"},
	},
	-- Recommended one-run route (not a hard lock).
	canonical_material_route = {
		"chapter1.material.coin",
		"chapter1.material.glaze",
		"chapter1.material.stone",
		"chapter1.material.wind",
		"chapter1.material.phase_anchor",
	},
}

-- Player-facing token titles (UI). Ownership still comes from node.related.story_tokens.
defs.tokens = {
	["chapter1.material.coin"] = {
		title = {zh = "交换素材", en = "Exchange Material"},
	},
	["chapter1.material.glaze"] = {
		title = {zh = "映射素材", en = "Mapping Material"},
	},
	["chapter1.material.stone"] = {
		title = {zh = "结构素材", en = "Structure Material"},
	},
	["chapter1.material.wind"] = {
		title = {zh = "方向素材", en = "Direction Material"},
	},
	["chapter1.material.phase_anchor"] = {
		-- Progress flag for "machine calibrated / ready", not a carryable ingredient.
		title = {zh = "相位锚", en = "Phase Anchor"},
		subtitle = {zh = "完成相位锚校准", en = "Phase calibration complete"},
	},
}

defs.chapters = {
	{
		id = "prologue",
		order = 1,
		title = {zh = "序章", en = "Prologue"},
		opening_title = {zh = "狩猎", en = "The Hunt"},
		story_scope = {status = "current"},
		runtime_threads = {"ending1"},
		wiki_visible = true,
		notes = {
			zh = "Ending1 完结序章。Chapter1 仅变为 AVAILABLE（无 objective / 无委托）。下一局播放「第一章 · 所求之物」开幕标题；委托由后续琉璃出现时再发布。",
			en = "Ending1 completes the prologue. Chapter1 becomes AVAILABLE only (no objective / no commission). Next new run plays Chapter 1 opening title; commission waits for Glaze later.",
		},
	},
	{
		id = "chapter1",
		order = 2,
		title = {zh = "第一章", en = "Chapter 1"},
		opening_title = {zh = "所求之物", en = "What We Seek"},
		story_scope = {status = "current"},
		runtime_threads = {"ending2", "ending2_display", "coin", "stone", "wind", "glaze"},
		wiki_visible = true,
		objectives = {
			"chapter1.accept_commission",
			"chapter1.collect_materials",
			"chapter1.prepare_alchemy",
			"chapter1.enter_realms",
			"chapter1.find_qing",
			"chapter1.stop_glaze",
			"chapter1.confront_glaze",
			"chapter1.defeat_glaze",
		},
		-- LEGACY-SAVE-002: chapter-level material lists; canon is node requirements
		-- under chapter1.material_phase (+ child related.story_tokens).
		material_plan = {
			target_count = 5,
			finalized = true,
			confirmed = {
				"chapter1.material.coin",
				"chapter1.material.glaze",
				"chapter1.material.stone",
				"chapter1.material.wind",
				"chapter1.material.phase_anchor",
			},
			pending = {},
		},
		required_material_tokens = {
			"chapter1.material.coin",
			"chapter1.material.glaze",
			"chapter1.material.stone",
			"chapter1.material.wind",
			"chapter1.material.phase_anchor",
		},
		-- Debug-only incomplete gate. Must not feed Wiki / Quest / normal runtime.
		debug_override = {
			allow_incomplete_material_set = false,
			incomplete_material_tokens = {
				"chapter1.material.coin",
				"chapter1.material.glaze",
				"chapter1.material.stone",
				"chapter1.material.wind",
			},
		},
		-- Compatibility alias (same as required; no material_x).
		material_tokens = {
			"chapter1.material.coin",
			"chapter1.material.glaze",
			"chapter1.material.stone",
			"chapter1.material.wind",
			"chapter1.material.phase_anchor",
		},
		notes = {
			zh = "opening_title=所求之物；opening_seen≠委托。AVAILABLE+nil/nil = 等待琉璃发布委托。commission_accepted 才开放素材路线。炼金 = Catalyst（序章）+ 4 Properties + Phase Anchor。",
			en = "opening_title=What We Seek; opening_seen≠commission. AVAILABLE+nil/nil waits for Glaze. Materials gated by commission_accepted. Alchemy = Catalyst (prologue) + 4 Properties + Phase Anchor.",
		},
	},
}

-- Nodes are ordered within each chapter for Wiki / exporter graphs.
defs.nodes = {
	-- Prologue
	{
		id = "prologue.hunt",
		chapter = "prologue",
		kind = "main",
		order = 1,
		title = {zh = "狩猎", en = "The Hunt"},
		previous = nil,
		next = "prologue.home_encounter",
		participants = {"qing"},
		spoiler_level = 0,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
				preview_scene = "prologue.opening",
				preview_label = {zh = "播放开幕", en = "Play Opening"},
			},
		},
		notes = {
			zh = "小青经照片门进入 Mausoleum/Gehenna II（BACKWARDS_PATH_INIT）时序章开始。正常游玩该层与 Ascent，直至首次抵达 Home。",
			en = "Prologue begins when Qing enters Mausoleum/Gehenna II via the photo door (BACKWARDS_PATH_INIT). Play that floor and the Ascent until first arrival at Home.",
		},
	},
	{
		id = "prologue.home_encounter",
		chapter = "prologue",
		kind = "main",
		order = 2,
		title = {zh = "陌生的相遇", en = "A Strange Encounter"},
		previous = "prologue.hunt",
		next = "prologue.beast_battle",
		participants = {"isaac", "qing"},
		optional = true,
		spoiler_level = 0,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
			},
		},
		notes = {
			zh = "已抵达 Home，可与以撒见面（可选）。离开卧室而未完成对白视为跳过，不 complete 该节点。",
			en = "Arrived at Home; meeting Isaac is optional. Leaving the bedroom without finishing dialogue skips without completing the node.",
		},
	},
	{
		id = "prologue.beast_battle",
		chapter = "prologue",
		kind = "boss",
		order = 3,
		title = {zh = "她的目标", en = "Her Goal"},
		previous = "prologue.home_encounter",
		next = "prologue.ending",
		participants = {"qing"},
		related = {
			bosses = {},
			related_entities = {"vanilla_beast"},
			combatant = "qing",
			observer_context = {"isaac"},
			vanilla_boss = "Beast",
		},
		spoiler_level = 1,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
			},
		},
		notes = {
			zh = "离开 Home 后的追猎终盘，最终以原版 Beast 收束。青独自击败；以撒不参战。",
			en = "Post-Home pursuit finale culminating in the vanilla Beast. Qing solo; Isaac does not fight.",
		},
	},
	{
		id = "prologue.ending",
		chapter = "prologue",
		kind = "main",
		order = 4,
		title = {zh = "序章结局", en = "Prologue Ending"},
		previous = "prologue.beast_battle",
		next = "prologue.complete",
		runtime_scene = "prologue.ending",
		participants = {"qing", "glaze", "isaac"},
		related = {
			alchemy_catalyst = "prologue.beast_residue",
		},
		spoiler_level = 2,
		wiki_visible = false,
		record = {
			player = {
				visible = false,
				mode = "checkpoint",
				editable = false,
			},
		},
		notes = {
			zh = "Presentation-owned Ending1：残余 / 琉璃 / 冲突 / Home 裂隙 / 青保护以撒。内部 phase 不进永久 Story Graph。",
			en = "Presentation-owned Ending1. Internal phases are not permanent Story Graph nodes.",
		},
	},
	{
		id = "prologue.complete",
		chapter = "prologue",
		kind = "chapter_end",
		order = 5,
		title = {zh = "序章完成", en = "Prologue Complete"},
		previous = "prologue.ending",
		next = "chapter1.commission",
		participants = {"isaac", "qing", "glaze"},
		spoiler_level = 1,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
				preview_scene = "prologue.ending",
				preview_label = {zh = "播放结局", en = "Play Ending"},
			},
		},
		notes = {
			zh = "Ending1 正式完成 → chapter1 available + accept_commission。不自动 accept_chapter1_commission。",
			en = "Formal Ending1 completion → chapter1 available + accept_commission. Does not auto-accept commission.",
		},
	},

	-- Chapter 1 main spine
	{
		id = "chapter1.commission",
		chapter = "chapter1",
		kind = "main",
		order = 1,
		title = {zh = "琉璃的委托", en = "Glaze's Commission"},
		previous = "prologue.complete",
		next = "chapter1.material_phase",
		participants = {"isaac", "glaze"},
		spoiler_level = 1,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
			},
		},
		notes = {
			zh = "确认青仍存活；琉璃表现出暂稳伤势的能力；「主治医师」；说明治疗需炼成；以撒接受。结束后 commission_accepted + collect_materials。",
			en = "Confirm Qing lives; Glaze shows temporary stabilization; physician beat; alchemy needed; Isaac accepts → collect_materials.",
		},
	},
	{
		id = "chapter1.material_phase",
		chapter = "chapter1",
		kind = "main",
		order = 2,
		title = {zh = "收集炼金素材", en = "Collect Materials"},
		previous = "chapter1.commission",
		next = "chapter1.alchemy_setup",
		participants = {"isaac"},
		spoiler_level = 1,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "group",
				editable = true,
			},
		},
		-- Requirement tokens are derived from child nodes' related.story_tokens.
		-- Completing 5/5 completes this container and advances to alchemy_setup
		-- (refresh_material_phase). No separate materials_complete node.
		requirements = {
			{
				id = "alchemy_materials",
				type = "child_tokens",
				target = 5,
			},
		},
		notes = {
			zh = "容器节点：完成五个 Material Event。5/5 后直接进入 alchemy_setup。不是独立 Scene。",
			en = "Container for five material events. At 5/5 advance to alchemy_setup. Not a standalone scene.",
		},
	},

	-- Material events (container children; order = recommended route)
	{
		id = "chapter1.coin",
		chapter = "chapter1",
		parent = "chapter1.material_phase",
		kind = "side_event",
		order = 3,
		title = {zh = "贪婪银行", en = "Greed Bank"},
		title_status = "provisional",
		runtime_thread = "coin",
		level_hint = "any_pre_mausoleum",
		prerequisites = {chapter = "chapter1", flags = {"commission_accepted"}},
		participants = {"isaac"},
		related = {
			bosses = {"bum_emperor"},
			alchemy_property = "exchange",
			story_tokens = {"chapter1.material.coin"},
			gameplay_rewards = {},
			legacy_gameplay_rewards = {
				{id = "A_Shard_Of_Coin", status = "inactive", note = "Legacy physical reward; current Story uses token only."},
			},
			rules = {
				story_first_clear_requires_boss = true,
				repeat_material_acquisition_skips_mandatory_boss = true,
			},
		},
		record = {
			player = {
				visible = true,
				mode = "event",
				editable = true,
				show_run_tokens = true,
			},
		},
		spoiler_level = 1,
		wiki_visible = true,
		notes = {
			zh = "首次 Story Clear 必须进银行对抗 Bum Emperor；永久完成后本局再取素材不强制 Boss（可 Optional Rematch）。",
			en = "First story clear requires Bum Emperor; later run material acquisition is not mandatory rematch.",
		},
	},
	{
		id = "chapter1.glaze",
		chapter = "chapter1",
		parent = "chapter1.material_phase",
		kind = "hidden_event",
		order = 4,
		title = {zh = "镜中异象", en = "Mirror Vision"},
		title_status = "provisional",
		runtime_thread = "glaze",
		level_hint = "downpour_dross_2",
		prerequisites = {chapter = "chapter1", flags = {"commission_accepted"}},
		participants = {"isaac"},
		related = {
			bosses = {},
			alchemy_property = "mapping",
			story_tokens = {"chapter1.material.glaze"},
			gameplay_rewards = {},
			legacy_gameplay_rewards = {
				{id = "A_Shard_Of_Glaze", status = "inactive", note = "Legacy physical reward; current Story uses token only."},
			},
		},
		record = {
			player = {
				visible = true,
				mode = "event",
				editable = true,
				show_run_tokens = true,
			},
		},
		spoiler_level = 2,
		hidden = true,
		wiki_visible = true,
	},
	{
		id = "chapter1.stone",
		chapter = "chapter1",
		parent = "chapter1.material_phase",
		kind = "side_event",
		order = 5,
		title = {zh = "棋盘异变", en = "Chessboard Disturbance"},
		title_status = "provisional",
		runtime_thread = "stone",
		level_hint = "mines_ashpit",
		prerequisites = {chapter = "chapter1", flags = {"commission_accepted"}},
		participants = {"isaac", "floraine"},
		related = {
			bosses = {"floraine"},
			alchemy_property = "structure",
			story_tokens = {"chapter1.material.stone"},
			gameplay_rewards = {},
			legacy_gameplay_rewards = {
				{id = "A_Shard_Of_Rock", status = "inactive", note = "Legacy physical reward; current Story uses token only."},
			},
		},
		record = {
			player = {
				visible = true,
				mode = "event",
				editable = true,
				show_run_tokens = true,
			},
		},
		spoiler_level = 1,
		wiki_visible = true,
	},
	{
		id = "chapter1.wind",
		chapter = "chapter1",
		parent = "chapter1.material_phase",
		kind = "side_event",
		order = 6,
		title = {zh = "风暴异变", en = "Storm Disturbance"},
		title_status = "provisional",
		runtime_thread = "wind",
		level_hint = "mausoleum_gehenna_1",
		prerequisites = {chapter = "chapter1", flags = {"commission_accepted"}},
		participants = {"isaac"},
		related = {
			bosses = {"zennith"},
			alchemy_property = "direction",
			story_tokens = {"chapter1.material.wind"},
			gameplay_rewards = {},
			legacy_gameplay_rewards = {
				{id = "A_Shard_Of_Lava", status = "inactive", note = "Legacy physical reward; current Story uses token only."},
			},
		},
		record = {
			player = {
				visible = true,
				mode = "event",
				editable = true,
				show_run_tokens = true,
			},
		},
		spoiler_level = 1,
		wiki_visible = true,
	},
	{
		id = "chapter1.phase_anchor",
		chapter = "chapter1",
		parent = "chapter1.material_phase",
		kind = "technology_puzzle",
		order = 7,
		title = {zh = "相位锚", en = "Phase Anchor"},
		title_status = "provisional",
		level_hint = "mausoleum_gehenna_2_post_boss",
		participants = {"isaac"},
		related = {
			bosses = {},
			alchemy_role = "stabilization",
			story_tokens = {"chapter1.material.phase_anchor"},
			gameplay_rewards = {
				{id = "Phase_Anchor_Core", status = "planned"},
			},
			puzzle_skeleton = {"reference", "synchronization", "lock"},
			required_run_tokens = {
				"chapter1.material.coin",
				"chapter1.material.glaze",
				"chapter1.material.stone",
				"chapter1.material.wind",
			},
		},
		prerequisites = {
			chapter = "chapter1",
			flags = {"commission_accepted"},
			required_run_tokens = {
				"chapter1.material.coin",
				"chapter1.material.glaze",
				"chapter1.material.stone",
				"chapter1.material.wind",
			},
		},
		record = {
			player = {
				visible = true,
				mode = "event",
				editable = true,
				show_run_tokens = true,
			},
		},
		implementation_status = "partial",
		spoiler_level = 2,
		wiki_visible = true,
		notes = {
			zh = "Mausoleum/Gehenna II Boss 后。相位锚实验室：离散状态机校准谜题 + 四属性/催化剂投料 + 启动占位。他界未实装。",
			en = "Post-boss Mausoleum/Gehenna II. Phase Lab: discrete calibration puzzle + 4P/Catalyst insert + activation stub. Interstice not implemented.",
		},
	},
	{
		id = "chapter1.alchemy_setup",
		chapter = "chapter1",
		kind = "main",
		order = 8,
		title = {zh = "炼成装置", en = "Alchemy Setup"},
		previous = "chapter1.material_phase",
		next = "chapter1.enter_realms",
		participants = {"isaac", "glaze"},
		spoiler_level = 2,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
			},
		},
		notes = {
			zh = "正式 Scene：五项材料 + Beast Residue + Phase Anchor 稳定；琉璃仍以治疗解释；玩家开始起疑。",
			en = "Formal scene: five materials + Beast Residue + Phase Anchor; Glaze still frames it as healing; doubt begins.",
		},
	},
	{
		id = "chapter1.enter_realms",
		chapter = "chapter1",
		kind = "main",
		order = 9,
		title = {zh = "进入他界", en = "Enter the Realms"},
		previous = "chapter1.alchemy_setup",
		next = "chapter1.search_qing",
		runtime_thread = "ending2",
		participants = {"isaac", "glaze"},
		spoiler_level = 2,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
			},
		},
	},
	{
		id = "chapter1.search_qing",
		chapter = "chapter1",
		kind = "main",
		order = 10,
		title = {zh = "寻找青", en = "Search for Qing"},
		previous = "chapter1.enter_realms",
		next = "chapter1.qing_midboss",
		participants = {"isaac"},
		spoiler_level = 2,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
			},
		},
		notes = {
			zh = "只表示寻找。Quest 不得写「击败青」。相遇/开战属于 Qing Encounter Runtime，不另建 Story 节点。",
			en = "Search only. Quest must not say Defeat Qing. Meet/fight belongs to Qing Encounter Runtime — not a separate Story node.",
		},
	},
	{
		id = "chapter1.qing_midboss",
		chapter = "chapter1",
		kind = "boss",
		order = 11,
		title = {zh = "青（道中）", en = "Qing (Midboss)"},
		previous = "chapter1.search_qing",
		next = "chapter1.post_qing",
		runtime_thread = "ending2_display",
		participants = {"isaac", "qing"},
		related = {bosses = {"qing"}},
		spoiler_level = 2,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
			},
		},
		notes = {
			zh = "剧情要求完成 Qing encounter。Boss 本体不依赖 Story；仅 story_owned adapter 在击败后 → post_qing。禁止死亡瞬间 on_revelation()。",
			en = "Story requires completing the Qing encounter. Boss runtime is Story-agnostic; only a story_owned adapter advances to post_qing. Never on_revelation() from death.",
		},
	},
	{
		id = "chapter1.post_qing",
		chapter = "chapter1",
		kind = "main",
		order = 12,
		title = {zh = "青战后", en = "Post Qing"},
		previous = "chapter1.qing_midboss",
		next = "chapter1.revelation",
		participants = {"isaac", "qing"},
		spoiler_level = 3,
		wiki_visible = true,
		notes = {
			zh = "战后演出隔离层：Boss 死亡不得直接承担对白/revelation。完成后才进入 revelation。",
			en = "Post-fight isolation: boss death must not own dialogue/revelation. Only then revelation.",
		},
	},
	{
		id = "chapter1.revelation",
		chapter = "chapter1",
		kind = "revelation",
		order = 13,
		title = {zh = "真相揭露", en = "Revelation"},
		previous = "chapter1.post_qing",
		next = "chapter1.deep_realms",
		participants = {"isaac", "qing"},
		spoiler_level = 3,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
			},
		},
		notes = {
			zh = "理解：残余本是计划一部分；五项构造跨界；Phase Anchor 稳定；青来阻此事；以撒完成了她试图阻止的工程；救青并非全假但非全貌。→ truth_revealed + stop_glaze。",
			en = "Understand catalyst plan, five-part path, Phase Anchor, Qing's purpose, Isaac completing what she tried to stop. → truth_revealed + stop_glaze.",
		},
	},
	{
		id = "chapter1.deep_realms",
		chapter = "chapter1",
		kind = "main",
		order = 14,
		title = {zh = "深入他界", en = "Deeper Realms"},
		previous = "chapter1.revelation",
		next = "chapter1.glaze_confrontation",
		runtime_thread = "ending2",
		participants = {"isaac"},
		spoiler_level = 2,
		wiki_visible = true,
	},
	{
		id = "chapter1.glaze_confrontation",
		chapter = "chapter1",
		kind = "main",
		order = 15,
		title = {zh = "对峙琉璃", en = "Glaze Confrontation"},
		previous = "chapter1.deep_realms",
		next = "chapter1.glaze_boss",
		participants = {"isaac", "glaze"},
		spoiler_level = 3,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
			},
		},
		notes = {
			zh = "Boss 前剧情。结束后 objective = defeat_glaze。",
			en = "Pre-boss scene. Then objective = defeat_glaze.",
		},
	},
	{
		id = "chapter1.glaze_boss",
		chapter = "chapter1",
		kind = "boss",
		order = 16,
		title = {zh = "琉璃王子", en = "Prince of Glaze"},
		previous = "chapter1.glaze_confrontation",
		next = "chapter1.complete",
		runtime_thread = "ending2",
		participants = {"isaac", "glaze"},
		related = {bosses = {"glaze_prince"}},
		implementation_status = "wip",
		spoiler_level = 3,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
			},
		},
	},
	{
		id = "chapter1.complete",
		chapter = "chapter1",
		kind = "chapter_end",
		order = 17,
		title = {zh = "第一章完成", en = "Chapter 1 Complete"},
		previous = "chapter1.glaze_boss",
		next = nil,
		runtime_thread = "ending2",
		participants = {"isaac", "qing", "glaze"},
		spoiler_level = 2,
		wiki_visible = true,
		record = {
			player = {
				visible = true,
				mode = "checkpoint",
				editable = true,
			},
		},
		notes = {
			zh = "当前章节冲突阶段性解决。不要提前设计 Chapter2。",
			en = "Chapter conflict resolved for now. Do not design Chapter 2 here.",
		},
	},
}

-- Runtime thread → story node / token (for thread hooks).
defs.thread_story_map = {
	coin = {node = "chapter1.coin", token = "chapter1.material.coin", chapter = "chapter1"},
	stone = {node = "chapter1.stone", token = "chapter1.material.stone", chapter = "chapter1"},
	wind = {node = "chapter1.wind", token = "chapter1.material.wind", chapter = "chapter1"},
	glaze = {node = "chapter1.glaze", token = "chapter1.material.glaze", chapter = "chapter1"},
	ending1 = {node = "prologue.complete", chapter = "prologue"},
	ending2 = {chapter = "chapter1"},
}

defs.excluded_from_chapter1 = {
	meat = true,
	start = true,
	shaddoll = true,
	zeis = true,
	ending3 = true,
}

return defs

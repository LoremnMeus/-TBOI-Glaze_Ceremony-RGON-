-- Player-facing Quest definitions. StoryProgress remains the only narrative truth.
-- Quest only translates objectives / current nodes into HUD / Panel text.

local defs = {
	SCHEMA_VERSION = 6,
	CATEGORY = {
		MAIN = "main",
		SIDE = "side",
		HIDDEN = "hidden",
	},
}

-- Main quests: match.objective and/or match.node.
-- Resolve order in registry: current_node → objective → chapter fallback.
defs.main = {
	-- ── Prologue ──
	{
		id = "prologue.hunt",
		chapter = "prologue",
		category = "main",
		match = {node = "prologue.hunt"},
		title = {zh = "狩猎", en = "The Hunt"},
		objective = {zh = "继续前进", en = "Keep moving forward"},
		-- Permanent StoryProgress stays on hunt; Quest view adapts to who can continue.
		player_variant = {
			character = "qing",
			otherwise_objective = {
				zh = "使用小青回到家层",
				en = "Return to Home as Qing",
			},
		},
		toast_kind = "new",
	},
	{
		id = "prologue.home_encounter",
		chapter = "prologue",
		category = "main",
		match = {node = "prologue.home_encounter"},
		title = {zh = "陌生的相遇", en = "A Strange Encounter"},
		objective = {zh = "与以撒见面（可选）", en = "Meet Isaac (Optional)"},
		optional = true,
		toast_kind = "new",
	},
	{
		id = "prologue.beast_battle",
		chapter = "prologue",
		category = "main",
		match = {node = "prologue.beast_battle"},
		title = {zh = "她的目标", en = "Her Goal"},
		objective = {zh = "继续追踪", en = "Keep tracking"},
		toast_kind = "update",
	},
	{
		id = "prologue.complete",
		chapter = "prologue",
		category = "main",
		match = {node = "prologue.complete"},
		title = {zh = "序章完成", en = "Prologue Complete"},
		objective = {zh = "狩猎已经结束", en = "The hunt is over"},
		toast_kind = nil,
	},

	-- ── Chapter 1 (objective + node) ──
	-- accept_commission: legacy / debug only. Formal runtime never sets this objective.
	{
		id = "chapter1.accept_commission",
		chapter = "chapter1",
		category = "main",
		match = {
			objective = "chapter1.accept_commission",
			node = "chapter1.commission",
		},
		title = {zh = "救下青", en = "Save Qing"},
		objective = {zh = "听听琉璃怎么说", en = "Hear what Glaze has to say"},
		runtime_visible = false,
		toast_kind = "new",
	},
	{
		id = "chapter1.collect_materials",
		chapter = "chapter1",
		category = "main",
		match = {
			objective = "chapter1.collect_materials",
			node = "chapter1.material_phase",
		},
		title = {zh = "救下青", en = "Save Qing"},
		objective = {zh = "寻找炼金素材", en = "Find alchemical materials"},
		progress = {type = "story_materials", chapter = "chapter1"},
		toast_kind = "new",
	},
	{
		id = "chapter1.prepare_alchemy",
		chapter = "chapter1",
		category = "main",
		match = {
			objective = "chapter1.prepare_alchemy",
			node = "chapter1.alchemy_setup",
		},
		title = {zh = "救下青", en = "Save Qing"},
		objective = {zh = "完成炼成", en = "Complete the alchemy"},
		panel_notes = {
			{zh = "炼金素材已齐备。", en = "The alchemical materials are ready."},
			{zh = "前往炼成装置。", en = "Go to the alchemy apparatus."},
		},
		toast_kind = "update",
	},
	{
		id = "chapter1.enter_realms",
		chapter = "chapter1",
		category = "main",
		match = {
			objective = "chapter1.enter_realms",
			node = "chapter1.enter_realms",
		},
		title = {zh = "救下青", en = "Save Qing"},
		objective = {zh = "进入他界", en = "Enter the Realms"},
		panel_notes = {
			{zh = "炼成已经完成。", en = "The alchemy is complete."},
			{zh = "寻找通往另一侧的道路。", en = "Find the path to the other side."},
		},
		toast_kind = "update",
	},
	{
		id = "chapter1.search_qing",
		chapter = "chapter1",
		category = "main",
		match = {
			objective = "chapter1.find_qing",
			node = "chapter1.search_qing",
		},
		title = {zh = "找到青", en = "Find Qing"},
		objective = {zh = "深入他界", en = "Go deeper into the Realms"},
		toast_kind = "update",
	},
	{
		id = "chapter1.qing_midboss",
		chapter = "chapter1",
		category = "main",
		match = {node = "chapter1.qing_midboss"},
		title = {zh = "让青停下来", en = "Stop Qing"},
		objective = {zh = "阻止她的攻击", en = "Halt her assault"},
		toast_kind = "update",
	},
	{
		id = "chapter1.post_qing",
		chapter = "chapter1",
		category = "main",
		-- Story keeps post_qing and revelation as separate nodes; Quest view is one.
		match = {
			nodes = {
				"chapter1.post_qing",
				"chapter1.revelation",
			},
		},
		title = {zh = "青", en = "Qing"},
		objective = {zh = "听听她要说什么", en = "Hear what she has to say"},
		toast_kind = "update",
	},
	{
		id = "chapter1.stop_glaze",
		chapter = "chapter1",
		category = "main",
		match = {
			objective = "chapter1.stop_glaze",
			node = "chapter1.deep_realms",
		},
		title = {zh = "阻止琉璃", en = "Stop Glaze"},
		objective = {zh = "继续深入他界", en = "Continue deeper into the Realms"},
		toast_kind = "major",
	},
	{
		id = "chapter1.confront_glaze",
		chapter = "chapter1",
		category = "main",
		match = {
			objective = "chapter1.confront_glaze",
			node = "chapter1.glaze_confrontation",
		},
		title = {zh = "阻止琉璃", en = "Stop Glaze"},
		objective = {zh = "找到他", en = "Find him"},
		toast_kind = "update",
	},
	{
		id = "chapter1.defeat_glaze",
		chapter = "chapter1",
		category = "main",
		match = {
			objective = "chapter1.defeat_glaze",
			node = "chapter1.glaze_boss",
		},
		title = {zh = "阻止琉璃", en = "Stop Glaze"},
		objective = {zh = "击败琉璃王子", en = "Defeat the Prince of Glaze"},
		toast_kind = "update",
	},
	{
		id = "chapter1.complete",
		chapter = "chapter1",
		category = "main",
		match = {node = "chapter1.complete"},
		title = {zh = "第一章", en = "Chapter 1"},
		objective = {zh = "看看这一切最终会走向哪里", en = "See where this all leads"},
		toast_kind = "major",
	},
}

-- Chapter-level fallbacks when no objective/node mapping hits.
defs.fallbacks = {
	prologue = {
		id = "prologue.fallback",
		chapter = "prologue",
		title = {zh = "当前目标", en = "Current Objective"},
		objective = {zh = "继续探索", en = "Keep exploring"},
		panel_notes = {
			{zh = "目前没有新的线索。", en = "No new leads for now."},
		},
		toast_kind = "update",
	},
	chapter1 = {
		id = "chapter1.fallback",
		chapter = "chapter1",
		title = {zh = "当前目标", en = "Current Objective"},
		objective = {zh = "继续前进", en = "Keep going"},
		panel_notes = {
			{zh = "寻找新的线索。", en = "Look for new leads."},
		},
		toast_kind = "update",
	},
	-- Chapter1 opened / AVAILABLE, commission not accepted: no fake objective.
	idle = {
		id = "story.idle",
		chapter = nil,
		title = {zh = "暂无任务", en = "No Quest"},
		objective = {zh = "当前没有任务", en = "No active quest"},
		toast_kind = nil,
	},
	completed = {
		id = "story.chapter_complete",
		chapter = nil,
		title = {zh = "章节完成", en = "Chapter Complete"},
		objective = {zh = "当前没有新的目标", en = "No new objectives yet"},
		toast_kind = "update",
	},
	unstarted = {
		id = "story.unstarted",
		chapter = nil,
		title = {zh = "任务", en = "Quest"},
		objective = {zh = "故事尚未开始", en = "The story has not begun"},
		panel_notes = {
			{zh = "继续深入地下室。", en = "Keep going deeper into the basement."},
		},
		toast_kind = "new",
	},
}

-- Side / hidden events keyed by Story node id.
defs.side = {
	{
		id = "chapter1.coin",
		chapter = "chapter1",
		category = "side",
		title = {zh = "贪婪银行", en = "Greed Bank"},
		stages = {
			discovered = {objective = {zh = "调查异常的银行", en = "Investigate the strange bank"}},
			progressing = {objective = {zh = "深入银行", en = "Go deeper into the bank"}},
			climax = {objective = {zh = "击败乞丐皇帝", en = "Defeat the Bum Emperor"}},
		},
	},
	{
		id = "chapter1.glaze",
		chapter = "chapter1",
		category = "hidden",
		title = {zh = "镜中异象", en = "Mirror Vision"},
		title_status = "provisional",
		stages = {
			discovered = {objective = {zh = "调查镜中的异象", en = "Investigate the mirror vision"}},
			progressing = {objective = {zh = "找到异象的源头", en = "Find the source of the vision"}},
			climax = {objective = {zh = "取得琉璃碎片", en = "Obtain the Glaze Fragment"}},
		},
	},
	{
		id = "chapter1.stone",
		chapter = "chapter1",
		category = "side",
		title = {zh = "棋盘异变", en = "Chessboard Disturbance"},
		stages = {
			discovered = {objective = {zh = "调查黑白格的异常", en = "Investigate the black-and-white anomaly"}},
			progressing = {objective = {zh = "深入棋盘空间", en = "Go deeper into the chessboard"}},
			climax = {objective = {zh = "面对 Floraine", en = "Face Floraine"}},
		},
	},
	{
		id = "chapter1.wind",
		chapter = "chapter1",
		category = "side",
		title = {zh = "风之试炼", en = "Wind Trial"},
		title_status = "provisional",
		stages = {
			discovered = {objective = {zh = "追寻异常的风", en = "Follow the strange wind"}},
			progressing = {objective = {zh = "找到风暴中心", en = "Find the heart of the storm"}},
			climax = {objective = {zh = "面对 Zennith", en = "Face Zennith"}},
		},
	},
	{
		id = "chapter1.phase_anchor",
		chapter = "chapter1",
		category = "side",
		title = {zh = "相位校准", en = "Phase Calibration"},
		title_status = "provisional",
		stages = {
			discovered = {objective = {zh = "调查陌生装置", en = "Investigate the strange apparatus"}},
			progressing = {objective = {zh = "完成相位校准", en = "Finish the phase calibration"}},
			climax = {objective = {zh = "完成相位锚校准", en = "Complete the Phase Anchor calibration"}},
		},
	},
}

defs.material_labels = {
	["chapter1.material.coin"] = {
		id = "coin",
		title = {zh = "钱币碎片", en = "Coin Fragment"},
		hidden_title = {zh = "未知素材", en = "Unknown Material"},
		node = "chapter1.coin",
	},
	["chapter1.material.glaze"] = {
		id = "glaze",
		title = {zh = "琉璃碎片", en = "Glaze Fragment"},
		hidden_title = {zh = "未知素材", en = "Unknown Material"},
		node = "chapter1.glaze",
		hidden_until_discovered = true,
	},
	["chapter1.material.stone"] = {
		id = "stone",
		title = {zh = "棋子碎片", en = "Chess Fragment"},
		hidden_title = {zh = "未知素材", en = "Unknown Material"},
		node = "chapter1.stone",
	},
	["chapter1.material.wind"] = {
		id = "wind",
		title = {zh = "风暴碎片", en = "Storm Fragment"},
		hidden_title = {zh = "未知素材", en = "Unknown Material"},
		node = "chapter1.wind",
	},
	["chapter1.material.phase_anchor"] = {
		id = "phase_anchor",
		title = {zh = "相位锚", en = "Phase Anchor"},
		hidden_title = {zh = "未知目标", en = "Unknown Objective"},
		node = "chapter1.phase_anchor",
		-- Not a portable material; marks calibration complete / machine ready.
		kind = "machine_ready",
	},
}

-- Spine nodes that Quest Audit expects to map (CURRENT_STORY_SCOPE).
defs.audit_spine = {
	prologue = {
		"prologue.hunt",
		"prologue.home_encounter",
		"prologue.beast_battle",
		"prologue.complete",
	},
	chapter1 = {
		"chapter1.commission",
		"chapter1.material_phase",
		"chapter1.alchemy_setup",
		"chapter1.enter_realms",
		"chapter1.search_qing",
		"chapter1.qing_midboss",
		"chapter1.post_qing",
		"chapter1.revelation",
		"chapter1.deep_realms",
		"chapter1.glaze_confrontation",
		"chapter1.glaze_boss",
		"chapter1.complete",
	},
}

return defs

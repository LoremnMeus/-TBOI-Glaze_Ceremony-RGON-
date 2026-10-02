-- Control-layer virtual checkpoints + chapter phase labels.
-- Virtual entries are NOT Story nodes. Node checkpoints derive from record.player.visible.

local defs = {
	VIRTUAL = {
		{
			id = "prologue.before",
			chapter = "prologue",
			order = 0,
			title = {zh = "序章前", en = "Before Prologue"},
			phase = "before",
		},
		{
			id = "chapter1.before",
			chapter = "chapter1",
			order = 0,
			title = {zh = "第一章前", en = "Before Chapter 1"},
			phase = "before",
			preview_scene = "chapter1.opening",
			preview_label = {zh = "播放开幕", en = "Play Opening"},
		},
		{
			id = "chapter1.opened",
			chapter = "chapter1",
			order = 0.5,
			title = {zh = "第一章已开幕", en = "Chapter 1 Opened"},
			phase = "opened",
			preview_scene = "chapter1.opening",
			preview_label = {zh = "播放开幕", en = "Play Opening"},
		},
	},
	PHASE_LABELS = {
		prologue = {
			before = {zh = "序章前", en = "Before Prologue"},
			active = {zh = "序章进行中", en = "Prologue in Progress"},
			completed = {zh = "序章完成", en = "Prologue Complete"},
			locked = {zh = "序章前", en = "Before Prologue"},
		},
		chapter1 = {
			locked = {zh = "第一章尚未解锁", en = "Chapter 1 Locked"},
			before = {zh = "第一章前", en = "Before Chapter 1"},
			opened = {zh = "已开幕 / 尚未接到委托", en = "Opened / awaiting commission"},
			active = {zh = "第一章进行中", en = "Chapter 1 in Progress"},
			completed = {zh = "第一章完成", en = "Chapter 1 Complete"},
			available = {zh = "第一章前", en = "Before Chapter 1"},
		},
	},
	-- Objective hints when applying a node checkpoint (editor normalize).
	NODE_OBJECTIVE = {
		["chapter1.commission"] = nil, -- commission scene has no Quest objective
		["chapter1.material_phase"] = "chapter1.collect_materials",
		["chapter1.alchemy_setup"] = "chapter1.prepare_alchemy",
		["chapter1.enter_realms"] = "chapter1.enter_realms",
		["chapter1.search_qing"] = "chapter1.find_qing",
		["chapter1.qing_midboss"] = "chapter1.find_qing",
		["chapter1.revelation"] = "chapter1.stop_glaze",
		["chapter1.glaze_confrontation"] = "chapter1.confront_glaze",
		["chapter1.glaze_boss"] = "chapter1.defeat_glaze",
		["chapter1.complete"] = "chapter1.defeat_glaze",
	},
}

return defs

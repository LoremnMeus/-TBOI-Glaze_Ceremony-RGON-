-- Story-facing character identities (not playable-character XML registry).
-- Current formal scope: prologue + chapter1 only.

local defs = {
	SCHEMA_VERSION = 2,
	CURRENT_STORY_SCOPE = {"prologue", "chapter1"},
	KIND = {
		STORY = "story_character",
		FORCE = "force_character",
		NPC = "npc",
	},
}

defs.characters = {
	{
		id = "qing",
		name = {zh = "青", en = "Qing"},
		kind = "story_character",
		story_scope = {chapter = "prologue", status = "current"},
		related_boss = {"qing"},
		related_playable = {"wq", "Spwq"},
		wiki = {visible = true, spoiler_level = 0, slug = "qing"},
		notes = {
			zh = "可玩角色 / 序章人物 / 第一章 Midboss 形态可同时存在。",
			en = "Playable, prologue figure, and chapter-1 midboss form may coexist.",
		},
	},
	{
		id = "glaze",
		name = {zh = "琉璃王子", en = "Prince of Glaze"},
		kind = "story_character",
		story_scope = {chapter = "chapter1", status = "current"},
		related_boss = {"glaze_prince"},
		wiki = {visible = true, spoiler_level = 1, slug = "glaze"},
	},
	{
		id = "floraine",
		name = {zh = "Floraine", en = "Floraine"},
		kind = "story_character",
		story_scope = {chapter = "chapter1", status = "current"},
		related_boss = {"floraine"},
		wiki = {visible = true, spoiler_level = 1, slug = "floraine"},
	},
	{
		id = "isaac",
		name = {zh = "以撒", en = "Isaac"},
		kind = "story_character",
		story_scope = {chapter = "prologue", status = "current"},
		related_boss = {},
		wiki = {visible = true, spoiler_level = 0, slug = "isaac"},
	},
}

-- Future / deferred characters: planning notes only. Not formal Wiki Character Canon.
defs.future = {
	{
		id = "autio",
		name = {zh = "Autio", en = "Autio"},
		planned_chapter = "chapter2",
		wiki_visible = false,
		notes = {
			zh = "第二章方向人物。勿当正式 Character Wiki Definition。",
			en = "Chapter-2 direction. Not a formal Character Wiki definition.",
		},
	},
	{
		id = "zeistos",
		name = {zh = "Zeistos", en = "Zeistos"},
		planned_chapter = "chapter2",
		wiki_visible = false,
		notes = {
			zh = "第二章方向人物（Zeis 相关）。勿从旧 thread 推断 Canon。",
			en = "Chapter-2 Zeis-related direction. Do not infer canon from legacy threads.",
		},
	},
}

return defs

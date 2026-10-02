-- Canonical Boss encounter definitions for Wiki / Story / audit.
-- NOT an enemy loader. Folder location under bosses/ or enemies/ is irrelevant.

local defs = {
	SCHEMA_VERSION = 2,
	-- Current narrative implementation scope: prologue + chapter1 only.
	CURRENT_STORY_SCOPE = {"prologue", "chapter1"},
	STATUS = {
		IMPLEMENTED = "implemented",
		WIP = "wip",
		DISABLED = "disabled",
		LEGACY = "legacy",
	},
	KIND = {
		NORMAL = "normal_boss",
		SIDE = "side_boss",
		STORY = "story_boss",
		HIDDEN = "hidden_boss",
		SPECIAL = "special_boss",
	},
	COMPONENT_ROLE = {
		WEAPON = "weapon",
		SUMMON = "summon",
		HAZARD = "hazard",
		PHASE_ENTITY = "phase_entity",
		HELPER = "helper",
		ARENA_MECHANIC = "arena_mechanic",
	},
}

-- Formal Boss registry for CURRENT scope only (prologue / chapter1).
-- status = implementation maturity, NOT Story/Wiki maturity.
defs.bosses = {
	{
		id = "floraine",
		name = {zh = "Floraine", en = "Floraine"},
		status = "implemented",
		kind = "side_boss",
		story_scope = {chapter = "chapter1", status = "current"},
		entity = {type = 996, variant_name = "Floraine", variant = 23755},
		sources = {
			"Qing_Remaster_scripts/bosses/Floraine/Enemy_Floraine.lua",
			"content/entities2.xml#Floraine",
		},
		spawn = {
			method = "thread",
			thread = "stone",
			notes = {zh = "棋盘异变事件终局遭遇。", en = "Final encounter of the chessboard event."},
		},
		related_character = "floraine",
		components = {
			{id = "floraine_chess_board", role = "arena_mechanic", source = "Floraine/Enemy_chess_board.lua", entity_name = "Chess Board"},
			{id = "floraine_chess_pawn", role = "summon", source = "Floraine/Enemy_chess_pawn.lua", entity_name = "Chess Piece"},
			{id = "floraine_chess_staff", role = "weapon", source = "Floraine/Enemy_chess_staff.lua", entity_name = "staff strike"},
		},
		wiki = {visible = true, spoiler_level = 1, slug = "floraine"},
	},
	{
		id = "zennith",
		name = {zh = "Zennith", en = "Zennith"},
		status = "implemented",
		kind = "side_boss",
		story_scope = {chapter = "chapter1", status = "current"},
		entity = {type = 996, variant_name = "Zennith", variant = 23763},
		sources = {
			"Qing_Remaster_scripts/bosses/Zennith/Zennith.lua",
			"Qing_Remaster_scripts/bosses/Zennith/Zennith_post.lua",
			"content/entities2.xml#Zennith",
		},
		spawn = {
			method = "thread",
			thread = "wind",
			notes = {
				zh = "全层风向寻路属于 Story/Encounter；战斗内风控属于 Boss。",
				en = "Floor wind pathfinding is Story/Encounter; in-fight wind control is Boss.",
			},
		},
		related_character = nil,
		components = {
			{id = "zennith_wind", role = "arena_mechanic", source = "Zennith/Enemy_wind.lua", entity_name = "wind effect"},
		},
		wiki = {visible = true, spoiler_level = 1, slug = "zennith"},
	},
	{
		id = "bum_emperor",
		name = {zh = "乞丐皇帝", en = "Bum Emperor"},
		status = "implemented",
		kind = "side_boss",
		story_scope = {chapter = "chapter1", status = "current"},
		entity = {type = 996, variant_name = "Bum Emperor", variant = 23782},
		sources = {
			"Qing_Remaster_scripts/bosses/Bum_Emperor/enemy_bum_emperor.lua",
			"content/entities2.xml#Bum Emperor",
		},
		spawn = {
			method = "thread",
			thread = "coin",
			notes = {
				zh = "银行房谜题属于 Story；最终战属于 Boss。",
				en = "Bank-room puzzle is Story; the final fight is Boss.",
			},
		},
		related_character = nil,
		components = {
			{id = "bum_guard", role = "summon", source = "Bum_Emperor/enemy_bum_guard.lua", entity_name = "Bum Guard"},
			{id = "bum_spear", role = "weapon", source = "Bum_Emperor/enemy_bum_spear.lua", entity_name = "Bum spear"},
			{id = "bum_arrow", role = "weapon", source = "Bum_Emperor/enemy_bum_arrow.lua", entity_name = "Bum arrow"},
		},
		wiki = {visible = true, spoiler_level = 1, slug = "bum-emperor"},
	},
	{
		id = "qing",
		name = {zh = "青", en = "Qing"},
		status = "implemented",
		kind = "story_boss",
		story_scope = {chapter = "chapter1", status = "current"},
		entity = {type = 996, variant_name = "Boss Qing", variant = 24037},
		sources = {
			"Qing_Remaster_scripts/bosses/Boss_Qing.lua",
			"content/entities2.xml#Boss Qing",
		},
		spawn = {
			method = "thread",
			thread = "ending2_display",
			notes = {zh = "第一章道中 Midboss。implemented = Boss AI 存在，不表示剧情写完。", en = "Chapter 1 midboss. implemented = combat exists, not full narrative."},
		},
		related_character = "qing",
		components = {
			{id = "qing_knife", role = "weapon", source = "Boss_Qing_knife.lua", entity_name = "QingKnife"},
			{id = "qing_helper", role = "helper", entity_name = "QingHelper"},
			{id = "qing_helper2", role = "phase_entity", entity_name = "QingHelper2"},
		},
		wiki = {visible = true, spoiler_level = 2, slug = "qing"},
	},
	{
		id = "glaze_prince",
		name = {zh = "琉璃王子", en = "Prince of Glaze"},
		status = "wip",
		kind = "story_boss",
		story_scope = {chapter = "chapter1", status = "current"},
		entity = {type = 996, variant_name = "Prince Glaze", variant = 23510},
		sources = {
			"Qing_Remaster_scripts/bosses/Boss_Glaze.lua",
			"content/entities2.xml#Prince Glaze",
		},
		spawn = {
			method = "thread",
			thread = "ending2",
			notes = {
				zh = "第一章终盘 Boss。攻击完整度仍需对照 HEAD；勿因 Story 节点存在而标 implemented。",
				en = "Chapter 1 final boss. Keep wip until combat audit; Story node alone is not enough.",
			},
		},
		related_character = "glaze",
		components = {},
		wiki = {visible = true, spoiler_level = 3, slug = "glaze-prince"},
	},
}

-- Future / deferred: known planning only. NOT current canon Story Graph / Wiki / encounter metadata.
-- Legacy threads (start/zeis) are historical implementation evidence, not chapter2 design.
defs.future = {
	{
		id = "absurd",
		name = {zh = "Absurd", en = "Absurd"},
		planned_chapter = "chapter2",
		planned_role = "final_boss",
		wiki_visible = false,
		legacy_sources = {
			"Qing_Remaster_scripts/bosses/Boss_Absurd.lua",
			"content/entities2.xml#Absurd",
		},
		notes = {
			zh = "第二章最终 Boss 方向。禁止提前建 Story Graph / 公开 Wiki / 正式遭遇路径审计。",
			en = "Planned chapter-2 final boss. Do not expand into Story/Wiki/encounter canon yet.",
		},
	},
	{
		id = "autio",
		name = {zh = "Autio", en = "Autio"},
		planned_chapter = "chapter2",
		planned_role = "side_boss",
		wiki_visible = false,
		legacy_implementation = {
			status = "disabled",
			thread = "start",
			entity = {type = 996, variant = 24010},
			sources = {
				"Qing_Remaster_scripts/bosses/Boss_Autio.lua",
				"content/entities2.xml#Autio",
			},
		},
		notes = {
			zh = "第二章支线 Boss 方向。旧 start thread 仅为历史实现，不是新 Canon。",
			en = "Planned chapter-2 side boss. Legacy start thread is historical evidence only.",
		},
	},
	{
		id = "zeistos",
		name = {zh = "Zeistos", en = "Zeistos"},
		planned_chapter = "chapter2",
		planned_role = "side_boss",
		wiki_visible = false,
		legacy_implementation = {
			status = "disabled",
			thread = "zeis",
			entity = {type = 996, variant = 24016},
			sources = {
				"Qing_Remaster_scripts/bosses/Boss_Zeistos.lua",
				"content/entities2.xml#Zeistos",
			},
		},
		notes = {
			zh = "第二章支线 Boss 方向（Zeis 相关）。旧 zeis thread 不是第二章 Story 设计。",
			en = "Planned chapter-2 Zeis-related side boss. Legacy zeis thread is not chapter-2 Story design.",
		},
	},
	{
		id = "winda",
		name = {zh = "Winda", en = "Winda"},
		planned_chapter = "future",
		planned_role = "boss",
		wiki_visible = false,
		legacy_implementation = {
			xml_boss_flag = true,
			entity = {type = 996, variant = 23796},
			lua_module = nil,
		},
		notes = {
			zh = "更后续章节 Boss 方向。XML boss=1 无正式 Lua；禁止当当前清册审计对象。",
			en = "Later-chapter boss direction. XML boss flag without Lua; not in current formal registry.",
		},
	},
}

-- Explicit non-boss / unresolved objects (audit surface).
defs.excluded = {
	{
		id = "qing_knife",
		reason = "Boss Qing weapon component; not a standalone boss page.",
		source = "Boss_Qing_knife.lua / QingKnife entity",
	},
	{
		id = "boss_all",
		reason = "Shared AI helper library used by multiple bosses; not an encounter.",
		source = "Boss_All.lua",
	},
	{
		id = "boss_a_stub",
		reason = "Empty stub (entity=nil); legacy/disabled scaffold.",
		source = "Boss_A_.lua",
	},
	{
		id = "path_finding",
		reason = "Shared pathfinding utility for boss AI.",
		source = "Path_Finding.lua",
	},
	{
		id = "sprite_regions",
		reason = "Shared sprite-region helper for Absurd-style bosses.",
		source = "sprite_regions.lua",
	},
	{
		id = "floraine_chess_board",
		reason = "Floraine arena component.",
		source = "Floraine/Enemy_chess_board.lua",
	},
	{
		id = "floraine_chess_pawn",
		reason = "Floraine summon component.",
		source = "Floraine/Enemy_chess_pawn.lua",
	},
	{
		id = "floraine_chess_staff",
		reason = "Floraine weapon/hazard component.",
		source = "Floraine/Enemy_chess_staff.lua",
	},
	{
		id = "bum_guard",
		reason = "Bum Emperor summon.",
		source = "Bum_Emperor/enemy_bum_guard.lua",
	},
	{
		id = "bum_spear",
		reason = "Bum Emperor projectile/weapon.",
		source = "Bum_Emperor/enemy_bum_spear.lua",
	},
	{
		id = "bum_arrow",
		reason = "Bum Emperor projectile/weapon.",
		source = "Bum_Emperor/enemy_bum_arrow.lua",
	},
	{
		id = "zennith_wind",
		reason = "Wind arena/control effect for Wind thread + Zennith fight.",
		source = "Zennith/Enemy_wind.lua",
	},
	{
		id = "shadollee",
		reason = "Effect/helper tied to shaddoll content; not a boss encounter page.",
		source = "enemy_shadollee.lua",
	},
}

defs.unresolved = {
	{
		id = "vanilla_beast",
		story_scope = {chapter = "prologue", status = "current"},
		notes = {
			zh = "序章 Beast：原版 Boss。青独自击败；以撒仅在场外语境。Story 用 related_entities / vanilla_boss，不进模组 Boss Registry。",
			en = "Prologue Beast: vanilla boss. Qing solo; Isaac is observer context only. Story uses related_entities/vanilla_boss — not mod Boss Registry.",
		},
	},
}

return defs

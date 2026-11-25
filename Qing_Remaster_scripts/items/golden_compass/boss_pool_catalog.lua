-- Golden Compass local Boss pool catalog (StageAPI floorInfo / bosses derived).
-- Read-only data for audit + future Boss@89 selection. Mortis excluded from scan targets.
-- Do NOT enable corridor selection from this module yet.

local M = {}

M.SOURCE = "StageAPI reimpl/floorInfo.lua + bosses.lua"
M.SCHEMA_VERSION = 1

M.BOSS_ENTITY = {
	["Baby Plum"] = {type = 908, variant = 0, subtype = 0},
	["Big Horn"] = {type = 411, variant = 0, subtype = 0},
	["Blastocyst"] = {type = 74, variant = 0, subtype = 0},
	["Blighted Ovum"] = {type = 79, variant = 2, subtype = 0},
	["Blue Baby"] = {type = 102, variant = 1, subtype = 0},
	["Brownie"] = {type = 402, variant = 0, subtype = 0},
	["Bumbino"] = {type = 916, variant = 0, subtype = 0},
	["Carrion Queen"] = {type = 28, variant = 2, subtype = 0},
	["Chad"] = {type = 28, variant = 1, subtype = 0},
	["Chimera"] = {type = 910, variant = 0, subtype = 0},
	["Chub"] = {type = 28, variant = 0, subtype = 0},
	["Clog"] = {type = 914, variant = 0, subtype = 0},
	["Clutch"] = {type = 921, variant = 0, subtype = 0},
	["Colostomia"] = {type = 917, variant = 0, subtype = 0},
	["Conquest"] = {type = 65, variant = 1, subtype = 0},
	["Daddy Long Legs"] = {type = 101, variant = 0, subtype = 0},
	["Dangle"] = {type = 261, variant = 1, subtype = 0},
	["Dark One"] = {type = 267, variant = 0, subtype = 0},
	["Death"] = {type = 66, variant = 0, subtype = 0},
	["Delirium"] = {type = 412, variant = 0, subtype = 0},
	["Dingle"] = {type = 261, variant = 0, subtype = 0},
	["Dogma"] = {type = 950, variant = 0, subtype = 0},
	["Duke of Flies"] = {type = 67, variant = 0, subtype = 0},
	["Famine"] = {type = 63, variant = 0, subtype = 0},
	["Fistula"] = {type = 71, variant = 0, subtype = 0},
	["Gemini"] = {type = 79, variant = 0, subtype = 0},
	["Gish"] = {type = 43, variant = 1, subtype = 0},
	["Great Gideon"] = {type = 907, variant = 0, subtype = 0},
	["Gurdy"] = {type = 36, variant = 0, subtype = 0},
	["Gurdy Jr"] = {type = 99, variant = 0, subtype = 0},
	["Gurglings"] = {type = 237, variant = 1, subtype = 0},
	["Headless Horseman"] = {type = 82, variant = 0, subtype = 0},
	["Hornfel"] = {type = 906, variant = 0, subtype = 0},
	["Horny Boys"] = {type = 920, variant = 0, subtype = 0},
	["Hush"] = {type = 407, variant = 0, subtype = 0},
	["Isaac"] = {type = 102, variant = 0, subtype = 0},
	["It Lives"] = {type = 78, variant = 1, subtype = 0},
	["Krampus"] = {type = 81, variant = 1, subtype = 0},
	["Larry Jr"] = {type = 19, variant = 0, subtype = 0},
	["Lil Blub"] = {type = 901, variant = 0, subtype = 0},
	["Little Horn"] = {type = 404, variant = 0, subtype = 0},
	["Loki"] = {type = 69, variant = 0, subtype = 0},
	["Lokii"] = {type = 69, variant = 1, subtype = 0},
	["Mama Gurdy"] = {type = 266, variant = 0, subtype = 0},
	["Mask of Infamy"] = {type = 97, variant = 0, subtype = 0},
	["Mega Fatty"] = {type = 264, variant = 0, subtype = 0},
	["Mega Maw"] = {type = 262, variant = 0, subtype = 0},
	["Mega Satan"] = {type = 274, variant = 0, subtype = 0},
	["Min-Min"] = {type = 913, variant = 0, subtype = 0},
	["Mom"] = {type = 45, variant = 0, subtype = 0},
	["Mom's Heart"] = {type = 78, variant = 0, subtype = 0},
	["Monstro"] = {type = 20, variant = 0, subtype = 0},
	["Monstro 2"] = {type = 43, variant = 0, subtype = 0},
	["Mother"] = {type = 912, variant = 0, subtype = 0},
	["Mr. Fred"] = {type = 270, variant = 0, subtype = 0},
	["Peep"] = {type = 68, variant = 0, subtype = 0},
	["Pestilence"] = {type = 64, variant = 0, subtype = 0},
	["Pin"] = {type = 62, variant = 0, subtype = 0},
	["Polycephalus"] = {type = 269, variant = 0, subtype = 0},
	["Rag Man"] = {type = 405, variant = 0, subtype = 0},
	["Rag Mega"] = {type = 409, variant = 0, subtype = 0},
	["Raglich"] = {type = 919, variant = 0, subtype = 0},
	["Reap Creep"] = {type = 900, variant = 0, subtype = 0},
	["Rotgut"] = {type = 911, variant = 0, subtype = 0},
	["Satan"] = {type = 84, variant = 0, subtype = 0},
	["Scolex"] = {type = 62, variant = 1, subtype = 0},
	["Singe"] = {type = 915, variant = 0, subtype = 0},
	["Sisters Vis"] = {type = 410, variant = 0, subtype = 0},
	["Steven"] = {type = 79, variant = 1, subtype = 0},
	["Teratoma"] = {type = 71, variant = 1, subtype = 0},
	["The Adversary"] = {type = 268, variant = 0, subtype = 0},
	["The Bloat"] = {type = 68, variant = 1, subtype = 0},
	["The Cage"] = {type = 265, variant = 0, subtype = 0},
	["The Fallen"] = {type = 81, variant = 0, subtype = 0},
	["The Forsaken"] = {type = 403, variant = 0, subtype = 0},
	["The Frail"] = {type = 62, variant = 2, subtype = 0},
	["The Gate"] = {type = 263, variant = 0, subtype = 0},
	["The Haunt"] = {type = 260, variant = 0, subtype = 0},
	["The Heretic"] = {type = 905, variant = 0, subtype = 0},
	["The Hollow"] = {type = 19, variant = 1, subtype = 0},
	["The Husk"] = {type = 67, variant = 1, subtype = 0},
	["The Lamb"] = {type = 273, variant = 0, subtype = 0},
	["The Matriarch"] = {type = 413, variant = 0, subtype = 0},
	["The Pile"] = {type = 269, variant = 1, subtype = 0},
	["The Rainmaker"] = {type = 902, variant = 0, subtype = 0},
	["The Scourge"] = {type = 909, variant = 0, subtype = 0},
	["The Shell"] = {type = 19, variant = 1, subtype = 0},
	["The Siren"] = {type = 904, variant = 0, subtype = 0},
	["The Stain"] = {type = 401, variant = 0, subtype = 0},
	["The Visage"] = {type = 903, variant = 0, subtype = 0},
	["The Wretched"] = {type = 100, variant = 1, subtype = 0},
	["Triachnid"] = {type = 101, variant = 1, subtype = 0},
	["Tuff Twins"] = {type = 19, variant = 0, subtype = 0},
	["Turdlet"] = {type = 918, variant = 0, subtype = 0},
	["Turdlings"] = {type = 237, variant = 2, subtype = 0},
	["Ultra Greed"] = {type = 406, variant = 0, subtype = 0},
	["War"] = {type = 65, variant = 0, subtype = 0},
	["Widow"] = {type = 100, variant = 0, subtype = 0},
	["Wormwood"] = {type = 62, variant = 3, subtype = 0},
}

M.BOSS_TYPE_TO_ID = {
	[1] = "Monstro",
	[2] = "Larry Jr",
	[3] = "Chub",
	[4] = "Gurdy",
	[5] = "Monstro 2",
	[6] = "Mom",
	[7] = "Scolex",
	[8] = "Mom's Heart",
	[9] = "Famine",
	[10] = "Pestilence",
	[11] = "War",
	[12] = "Death",
	[13] = "Duke of Flies",
	[14] = "Peep",
	[15] = "Loki",
	[16] = "Blastocyst",
	[17] = "Gemini",
	[18] = "Fistula",
	[19] = "Gish",
	[20] = "Steven",
	[21] = "Chad",
	[22] = "Headless Horseman",
	[23] = "The Fallen",
	[24] = "Satan",
	[25] = "It Lives",
	[26] = "The Hollow",
	[27] = "Carrion Queen",
	[28] = "Gurdy Jr",
	[29] = "The Husk",
	[30] = "The Bloat",
	[31] = "Lokii",
	[32] = "Blighted Ovum",
	[33] = "Teratoma",
	[34] = "Widow",
	[35] = "Mask of Infamy",
	[36] = "The Wretched",
	[37] = "Pin",
	[38] = "Conquest",
	[39] = "Isaac",
	[40] = "Blue Baby",
	[41] = "Daddy Long Legs",
	[42] = "Triachnid",
	[43] = "The Haunt",
	[44] = "Dingle",
	[45] = "Mega Maw",
	[46] = "The Gate",
	[47] = "Mega Fatty",
	[48] = "The Cage",
	[49] = "Mama Gurdy",
	[50] = "Dark One",
	[51] = "The Adversary",
	[52] = "Polycephalus",
	[53] = "Mr. Fred",
	[54] = "The Lamb",
	[55] = "Mega Satan",
	[56] = "Gurglings",
	[57] = "The Stain",
	[58] = "Brownie",
	[59] = "The Forsaken",
	[60] = "Little Horn",
	[61] = "Rag Man",
	[62] = "Ultra Greed",
	[63] = "Hush",
	[64] = "Dangle",
	[65] = "Turdlings",
	[66] = "The Frail",
	[67] = "Rag Mega",
	[68] = "Sisters Vis",
	[69] = "Big Horn",
	[70] = "Delirium",
	[72] = "The Matriarch",
	[73] = "The Pile",
	[74] = "Reap Creep",
	[75] = "Lil Blub",
	[76] = "Wormwood",
	[77] = "The Rainmaker",
	[78] = "The Visage",
	[79] = "The Siren",
	[80] = "Tuff Twins",
	[81] = "The Heretic",
	[82] = "Hornfel",
	[83] = "Great Gideon",
	[84] = "Baby Plum",
	[85] = "The Scourge",
	[86] = "Chimera",
	[87] = "Rotgut",
	[88] = "Mother",
	[89] = "Mom",
	[90] = "Mom's Heart",
	[91] = "Min-Min",
	[92] = "Clog",
	[93] = "Singe",
	[94] = "Bumbino",
	[95] = "Colostomia",
	[96] = "The Shell",
	[97] = "Turdlet",
	[98] = "Raglich",
	[99] = "Dogma",
	[100] = "The Beast",
	[101] = "Horny Boys",
	[102] = "Clutch",
}

M.DOOR_MASK = {
	LEFT = 1 << DoorSlot.LEFT0,
	RIGHT = 1 << DoorSlot.RIGHT0,
	UP = 1 << DoorSlot.UP0,
	DOWN = 1 << DoorSlot.DOWN0,
}
M.DOOR_MASK.LR = M.DOOR_MASK.LEFT | M.DOOR_MASK.RIGHT
M.DOOR_MASK.UD = M.DOOR_MASK.UP | M.DOOR_MASK.DOWN
M.DOOR_MASK.LRUD = M.DOOR_MASK.LR | M.DOOR_MASK.UD

function M.stage_to_stb(stage, stage_type)
	stage = tonumber(stage)
	stage_type = tonumber(stage_type) or 0
	if stage == nil then return nil end
	if stage == LevelStage.STAGE4_3 then return StbType.BLUE_WOMB end
	if stage == LevelStage.STAGE7 then return StbType.VOID end
	local rows = {
		[LevelStage.STAGE1_1] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.BASEMENT,
			[StageType.STAGETYPE_WOTL] = StbType.CELLAR,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.BURNING_BASEMENT,
			[StageType.STAGETYPE_REPENTANCE] = StbType.DOWNPOUR,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.DROSS,
		},
		[LevelStage.STAGE1_2] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.BASEMENT,
			[StageType.STAGETYPE_WOTL] = StbType.CELLAR,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.BURNING_BASEMENT,
			[StageType.STAGETYPE_REPENTANCE] = StbType.DOWNPOUR,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.DROSS,
		},
		[LevelStage.STAGE2_1] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.CAVES,
			[StageType.STAGETYPE_WOTL] = StbType.CATACOMBS,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.FLOODED_CAVES,
			[StageType.STAGETYPE_REPENTANCE] = StbType.MINES,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.ASHPIT,
		},
		[LevelStage.STAGE2_2] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.CAVES,
			[StageType.STAGETYPE_WOTL] = StbType.CATACOMBS,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.FLOODED_CAVES,
			[StageType.STAGETYPE_REPENTANCE] = StbType.MINES,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.ASHPIT,
		},
		[LevelStage.STAGE3_1] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.DEPTHS,
			[StageType.STAGETYPE_WOTL] = StbType.NECROPOLIS,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.DANK_DEPTHS,
			[StageType.STAGETYPE_REPENTANCE] = StbType.MAUSOLEUM,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.GEHENNA,
		},
		[LevelStage.STAGE3_2] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.DEPTHS,
			[StageType.STAGETYPE_WOTL] = StbType.NECROPOLIS,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.DANK_DEPTHS,
			[StageType.STAGETYPE_REPENTANCE] = StbType.MAUSOLEUM,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.GEHENNA,
		},
		[LevelStage.STAGE4_1] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.WOMB,
			[StageType.STAGETYPE_WOTL] = StbType.UTERO,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.SCARRED_WOMB,
			[StageType.STAGETYPE_REPENTANCE] = StbType.CORPSE,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.MORTIS,
		},
		[LevelStage.STAGE4_2] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.WOMB,
			[StageType.STAGETYPE_WOTL] = StbType.UTERO,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.SCARRED_WOMB,
			[StageType.STAGETYPE_REPENTANCE] = StbType.CORPSE,
			[StageType.STAGETYPE_REPENTANCE_B] = StbType.MORTIS,
		},
		[LevelStage.STAGE5] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.SHEOL,
			[StageType.STAGETYPE_WOTL] = StbType.CATHEDRAL,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.SHEOL,
		},
		[LevelStage.STAGE6] = {
			[StageType.STAGETYPE_ORIGINAL] = StbType.DARK_ROOM,
			[StageType.STAGETYPE_WOTL] = StbType.CHEST,
			[StageType.STAGETYPE_AFTERBIRTH] = StbType.DARK_ROOM,
		},
	}
	local row = rows[stage]
	if not row then return nil end
	return row[stage_type] or row[StageType.STAGETYPE_ORIGINAL]
end

M.FLOOR_DEFS = {
	{
		stage = LevelStage.STAGE1_1,
		stage_type = StageType.STAGETYPE_ORIGINAL,
		prefix = "01_basement",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "Monstro", weight = 1.0},
			{id = "Gemini", weight = 1.0},
			{id = "Larry Jr", weight = 1.0},
			{id = "Dingle", weight = 1.0},
			{id = "Dangle", weight = 0.25},
			{id = "Gurglings", weight = 1.0},
			{id = "Turdlings", weight = 0.25},
			{id = "Steven", weight = 0.25},
			{id = "Duke of Flies", weight = 1.0},
			{id = "Little Horn", weight = 1.0},
			{id = "Baby Plum", weight = 1.0},
			{id = "Famine", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE1_2,
		stage_type = StageType.STAGETYPE_ORIGINAL,
		prefix = "01_basement",
		inherits_from = {stage = LevelStage.STAGE1_1, stage_type = StageType.STAGETYPE_ORIGINAL},
		pool_mode = "inherit",
		role_89 = "fight",
		bosses = {
			{id = "Monstro", weight = 1.0},
			{id = "Gemini", weight = 1.0},
			{id = "Larry Jr", weight = 1.0},
			{id = "Dingle", weight = 1.0},
			{id = "Dangle", weight = 0.25},
			{id = "Gurglings", weight = 1.0},
			{id = "Turdlings", weight = 0.25},
			{id = "Steven", weight = 0.25},
			{id = "Duke of Flies", weight = 1.0},
			{id = "Little Horn", weight = 1.0},
			{id = "Baby Plum", weight = 1.0},
			{id = "Famine", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE1_1,
		stage_type = StageType.STAGETYPE_WOTL,
		prefix = "02_cellar",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "Pin", weight = 1.0},
			{id = "Widow", weight = 1.0},
			{id = "Blighted Ovum", weight = 1.0},
			{id = "The Haunt", weight = 1.0},
			{id = "Duke of Flies", weight = 1.0},
			{id = "Little Horn", weight = 1.0},
			{id = "Rag Man", weight = 1.0},
			{id = "Baby Plum", weight = 1.0},
			{id = "Famine", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE1_2,
		stage_type = StageType.STAGETYPE_WOTL,
		prefix = "02_cellar",
		inherits_from = {stage = LevelStage.STAGE1_1, stage_type = StageType.STAGETYPE_WOTL},
		pool_mode = "inherit",
		role_89 = "fight",
		bosses = {
			{id = "Pin", weight = 1.0},
			{id = "Widow", weight = 1.0},
			{id = "Blighted Ovum", weight = 1.0},
			{id = "The Haunt", weight = 1.0},
			{id = "Duke of Flies", weight = 1.0},
			{id = "Little Horn", weight = 1.0},
			{id = "Rag Man", weight = 1.0},
			{id = "Baby Plum", weight = 1.0},
			{id = "Famine", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE1_1,
		stage_type = StageType.STAGETYPE_AFTERBIRTH,
		prefix = "13_burning_basement",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "Monstro", weight = 1.0},
			{id = "Gemini", weight = 1.0},
			{id = "Larry Jr", weight = 1.0},
			{id = "Dingle", weight = 1.0},
			{id = "Dangle", weight = 0.25},
			{id = "Gurglings", weight = 1.0},
			{id = "Turdlings", weight = 0.25},
			{id = "Steven", weight = 0.25},
			{id = "Duke of Flies", weight = 1.0},
			{id = "Little Horn", weight = 1.0},
			{id = "Baby Plum", weight = 1.0},
			{id = "Famine", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE1_2,
		stage_type = StageType.STAGETYPE_AFTERBIRTH,
		prefix = "13_burning_basement",
		inherits_from = {stage = LevelStage.STAGE1_1, stage_type = StageType.STAGETYPE_AFTERBIRTH},
		pool_mode = "inherit",
		role_89 = "fight",
		bosses = {
			{id = "Monstro", weight = 1.0},
			{id = "Gemini", weight = 1.0},
			{id = "Larry Jr", weight = 1.0},
			{id = "Dingle", weight = 1.0},
			{id = "Dangle", weight = 0.25},
			{id = "Gurglings", weight = 1.0},
			{id = "Turdlings", weight = 0.25},
			{id = "Steven", weight = 0.25},
			{id = "Duke of Flies", weight = 1.0},
			{id = "Little Horn", weight = 1.0},
			{id = "Baby Plum", weight = 1.0},
			{id = "Famine", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE1_1,
		stage_type = StageType.STAGETYPE_REPENTANCE,
		prefix = "01x_downpour",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "Lil Blub", weight = 1.0},
			{id = "Wormwood", weight = 1.0},
			{id = "The Rainmaker", weight = 1.0},
			{id = "Min-Min", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE1_2,
		stage_type = StageType.STAGETYPE_REPENTANCE,
		prefix = "01x_downpour",
		inherits_from = {stage = LevelStage.STAGE1_1, stage_type = StageType.STAGETYPE_REPENTANCE},
		pool_mode = "inherit",
		role_89 = "fight",
		bosses = {
			{id = "Lil Blub", weight = 1.0},
			{id = "Wormwood", weight = 1.0},
			{id = "The Rainmaker", weight = 1.0},
			{id = "Min-Min", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE1_1,
		stage_type = StageType.STAGETYPE_REPENTANCE_B,
		prefix = "02x_dross",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "Lil Blub", weight = 1.0},
			{id = "Wormwood", weight = 1.0},
			{id = "Clog", weight = 1.0},
			{id = "Colostomia", weight = 1.0},
			{id = "Turdlet", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE1_2,
		stage_type = StageType.STAGETYPE_REPENTANCE_B,
		prefix = "02x_dross",
		inherits_from = {stage = LevelStage.STAGE1_1, stage_type = StageType.STAGETYPE_REPENTANCE_B},
		pool_mode = "inherit",
		role_89 = "fight",
		bosses = {
			{id = "Lil Blub", weight = 1.0},
			{id = "Wormwood", weight = 1.0},
			{id = "Clog", weight = 1.0},
			{id = "Colostomia", weight = 1.0},
			{id = "Turdlet", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE2_1,
		stage_type = StageType.STAGETYPE_ORIGINAL,
		prefix = "03_caves",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "Chub", weight = 1.0},
			{id = "Gurdy", weight = 1.0},
			{id = "Fistula", weight = 1.0},
			{id = "Mega Maw", weight = 1.0},
			{id = "Mega Fatty", weight = 1.0},
			{id = "Chad", weight = 0.25},
			{id = "Peep", weight = 1.0},
			{id = "Gurdy Jr", weight = 1.0},
			{id = "The Stain", weight = 1.0},
			{id = "Rag Mega", weight = 1.0},
			{id = "Big Horn", weight = 1.0},
			{id = "Bumbino", weight = 1.0},
			{id = "Pestilence", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE2_2,
		stage_type = StageType.STAGETYPE_ORIGINAL,
		prefix = "03_caves",
		inherits_from = {stage = LevelStage.STAGE2_1, stage_type = StageType.STAGETYPE_ORIGINAL},
		pool_mode = "inherit",
		role_89 = "fight",
		bosses = {
			{id = "Chub", weight = 1.0},
			{id = "Gurdy", weight = 1.0},
			{id = "Fistula", weight = 1.0},
			{id = "Mega Maw", weight = 1.0},
			{id = "Mega Fatty", weight = 1.0},
			{id = "Chad", weight = 0.25},
			{id = "Peep", weight = 1.0},
			{id = "Gurdy Jr", weight = 1.0},
			{id = "The Stain", weight = 1.0},
			{id = "Rag Mega", weight = 1.0},
			{id = "Big Horn", weight = 1.0},
			{id = "Bumbino", weight = 1.0},
			{id = "Pestilence", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE2_1,
		stage_type = StageType.STAGETYPE_WOTL,
		prefix = "04_catacombs",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "The Hollow", weight = 1.0},
			{id = "The Husk", weight = 1.0},
			{id = "Dark One", weight = 1.0},
			{id = "Polycephalus", weight = 1.0},
			{id = "Carrion Queen", weight = 1.0},
			{id = "The Wretched", weight = 1.0},
			{id = "Peep", weight = 1.0},
			{id = "Gurdy Jr", weight = 1.0},
			{id = "The Forsaken", weight = 1.0},
			{id = "The Frail", weight = 1.0},
			{id = "Rag Mega", weight = 1.0},
			{id = "Big Horn", weight = 1.0},
			{id = "Bumbino", weight = 1.0},
			{id = "Pestilence", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE2_2,
		stage_type = StageType.STAGETYPE_WOTL,
		prefix = "04_catacombs",
		inherits_from = {stage = LevelStage.STAGE2_1, stage_type = StageType.STAGETYPE_WOTL},
		pool_mode = "inherit",
		role_89 = "fight",
		bosses = {
			{id = "The Hollow", weight = 1.0},
			{id = "The Husk", weight = 1.0},
			{id = "Dark One", weight = 1.0},
			{id = "Polycephalus", weight = 1.0},
			{id = "Carrion Queen", weight = 1.0},
			{id = "The Wretched", weight = 1.0},
			{id = "Peep", weight = 1.0},
			{id = "Gurdy Jr", weight = 1.0},
			{id = "The Forsaken", weight = 1.0},
			{id = "The Frail", weight = 1.0},
			{id = "Rag Mega", weight = 1.0},
			{id = "Big Horn", weight = 1.0},
			{id = "Bumbino", weight = 1.0},
			{id = "Pestilence", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE2_1,
		stage_type = StageType.STAGETYPE_AFTERBIRTH,
		prefix = "14_drowned_caves",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "Chub", weight = 1.0},
			{id = "Gurdy", weight = 1.0},
			{id = "Fistula", weight = 1.0},
			{id = "Mega Maw", weight = 1.0},
			{id = "Mega Fatty", weight = 1.0},
			{id = "Chad", weight = 0.25},
			{id = "Peep", weight = 1.0},
			{id = "Gurdy Jr", weight = 1.0},
			{id = "The Stain", weight = 1.0},
			{id = "The Forsaken", weight = 1.0},
			{id = "The Frail", weight = 1.0},
			{id = "Rag Mega", weight = 1.0},
			{id = "Big Horn", weight = 1.0},
			{id = "Bumbino", weight = 1.0},
			{id = "Pestilence", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE2_2,
		stage_type = StageType.STAGETYPE_AFTERBIRTH,
		prefix = "14_drowned_caves",
		inherits_from = {stage = LevelStage.STAGE2_1, stage_type = StageType.STAGETYPE_AFTERBIRTH},
		pool_mode = "inherit",
		role_89 = "fight",
		bosses = {
			{id = "Chub", weight = 1.0},
			{id = "Gurdy", weight = 1.0},
			{id = "Fistula", weight = 1.0},
			{id = "Mega Maw", weight = 1.0},
			{id = "Mega Fatty", weight = 1.0},
			{id = "Chad", weight = 0.25},
			{id = "Peep", weight = 1.0},
			{id = "Gurdy Jr", weight = 1.0},
			{id = "The Stain", weight = 1.0},
			{id = "The Forsaken", weight = 1.0},
			{id = "The Frail", weight = 1.0},
			{id = "Rag Mega", weight = 1.0},
			{id = "Big Horn", weight = 1.0},
			{id = "Bumbino", weight = 1.0},
			{id = "Pestilence", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE2_1,
		stage_type = StageType.STAGETYPE_REPENTANCE,
		prefix = "03x_mines",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "Reap Creep", weight = 1.0},
			{id = "Tuff Twins", weight = 1.0},
			{id = "Hornfel", weight = 1.0},
			{id = "Great Gideon", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE2_2,
		stage_type = StageType.STAGETYPE_REPENTANCE,
		prefix = "03x_mines",
		inherits_from = {stage = LevelStage.STAGE2_1, stage_type = StageType.STAGETYPE_REPENTANCE},
		pool_mode = "inherit",
		role_89 = "fight",
		bosses = {
			{id = "Reap Creep", weight = 1.0},
			{id = "Tuff Twins", weight = 1.0},
			{id = "Hornfel", weight = 1.0},
			{id = "Great Gideon", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE2_1,
		stage_type = StageType.STAGETYPE_REPENTANCE_B,
		prefix = "04x_ashpit",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "The Pile", weight = 1.0},
			{id = "The Shell", weight = 1.0},
			{id = "Singe", weight = 1.0},
			{id = "Great Gideon", weight = 1.0},
			{id = "Clutch", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE2_2,
		stage_type = StageType.STAGETYPE_REPENTANCE_B,
		prefix = "04x_ashpit",
		inherits_from = {stage = LevelStage.STAGE2_1, stage_type = StageType.STAGETYPE_REPENTANCE_B},
		pool_mode = "inherit",
		role_89 = "fight",
		bosses = {
			{id = "The Pile", weight = 1.0},
			{id = "The Shell", weight = 1.0},
			{id = "Singe", weight = 1.0},
			{id = "Great Gideon", weight = 1.0},
			{id = "Clutch", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE3_1,
		stage_type = StageType.STAGETYPE_ORIGINAL,
		prefix = "05_depths",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "The Cage", weight = 1.0},
			{id = "Monstro 2", weight = 1.0},
			{id = "The Gate", weight = 1.0},
			{id = "Gish", weight = 0.25},
			{id = "Loki", weight = 1.0},
			{id = "Brownie", weight = 1.0},
			{id = "Sisters Vis", weight = 1.0},
			{id = "Reap Creep", weight = 1.0},
			{id = "War", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE3_1,
		stage_type = StageType.STAGETYPE_WOTL,
		prefix = "06_necropolis",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "The Adversary", weight = 1.0},
			{id = "The Bloat", weight = 1.0},
			{id = "Mask of Infamy", weight = 1.0},
			{id = "Loki", weight = 1.0},
			{id = "Brownie", weight = 1.0},
			{id = "Sisters Vis", weight = 1.0},
			{id = "The Pile", weight = 1.0},
			{id = "War", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE3_1,
		stage_type = StageType.STAGETYPE_AFTERBIRTH,
		prefix = "15_dank_depths",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "The Cage", weight = 1.0},
			{id = "Monstro 2", weight = 1.0},
			{id = "The Gate", weight = 1.0},
			{id = "Gish", weight = 1.0},
			{id = "Loki", weight = 1.0},
			{id = "Brownie", weight = 1.0},
			{id = "Sisters Vis", weight = 1.0},
			{id = "Reap Creep", weight = 1.0},
			{id = "War", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE3_1,
		stage_type = StageType.STAGETYPE_REPENTANCE,
		prefix = "05x_mausoleum",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "The Siren", weight = 1.0},
			{id = "The Heretic", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE3_1,
		stage_type = StageType.STAGETYPE_REPENTANCE_B,
		prefix = "06x_gehenna",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "The Visage", weight = 1.0},
			{id = "Horny Boys", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE4_1,
		stage_type = StageType.STAGETYPE_ORIGINAL,
		prefix = "07_womb",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "Scolex", weight = 1.0},
			{id = "Mama Gurdy", weight = 1.0},
			{id = "Lokii", weight = 1.0},
			{id = "Mr. Fred", weight = 1.0},
			{id = "Blastocyst", weight = 1.0},
			{id = "The Matriarch", weight = 0.25},
			{id = "Death", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Conquest", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE4_1,
		stage_type = StageType.STAGETYPE_WOTL,
		prefix = "08_utero",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "Teratoma", weight = 1.0},
			{id = "Lokii", weight = 1.0},
			{id = "Daddy Long Legs", weight = 1.0},
			{id = "Triachnid", weight = 1.0},
			{id = "The Bloat", weight = 1.0},
			{id = "Death", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Conquest", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE4_1,
		stage_type = StageType.STAGETYPE_AFTERBIRTH,
		prefix = "16_scarred_womb",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "Scolex", weight = 1.0},
			{id = "Mama Gurdy", weight = 1.0},
			{id = "Lokii", weight = 1.0},
			{id = "Mr. Fred", weight = 1.0},
			{id = "Blastocyst", weight = 1.0},
			{id = "Triachnid", weight = 1.0},
			{id = "The Matriarch", weight = 2.0},
			{id = "Death", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Conquest", weight = 1.0, horseman = true, only_replace_horsemen = true},
			{id = "Headless Horseman", weight = 1.0, horseman = true, only_replace_horsemen = true},
		},
	},
	{
		stage = LevelStage.STAGE4_1,
		stage_type = StageType.STAGETYPE_REPENTANCE,
		prefix = "07x_corpse",
		no_copy_ii = false,
		fixed = false,
		pool_mode = "weighted",
		role_89 = "fight",
		bosses = {
			{id = "The Scourge", weight = 1.0},
			{id = "Chimera", weight = 1.0},
			{id = "Rotgut", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE4_1,
		stage_type = StageType.STAGETYPE_REPENTANCE_B,
		prefix = "07x_corpse",
		skip_scan = true,
		note = "Mortis: StageAPI floorInfo has no Bosses; excluded",
		bosses = {},
	},
	{
		stage = LevelStage.STAGE5,
		stage_type = StageType.STAGETYPE_ORIGINAL,
		prefix = "09_sheol",
		no_copy_ii = true,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		bosses = {
			{id = "Satan", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE5,
		stage_type = StageType.STAGETYPE_WOTL,
		prefix = "10_cathedral",
		no_copy_ii = true,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		bosses = {
			{id = "Isaac", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE6,
		stage_type = StageType.STAGETYPE_ORIGINAL,
		prefix = "11_darkroom",
		no_copy_ii = true,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		bosses = {
			{id = "The Lamb", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE6,
		stage_type = StageType.STAGETYPE_WOTL,
		prefix = "12_chest",
		no_copy_ii = true,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		bosses = {
			{id = "Blue Baby", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE4_3,
		all_types = true,
		prefix = "17_blue_womb",
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		bosses = {
			{id = "Hush", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE7,
		all_types = true,
		prefix = "19_void",
		fixed = true,
		pool_mode = "fixed",
		role_89 = "delirium",
		bosses = {
			{id = "Delirium", weight = 1.0},
		},
		note = "Void: designated SPECIAL_ROOMS/3414 Delirium (2x2) at Boss@89",
	},
	{
		stage = LevelStage.STAGE3_2,
		stage_type = StageType.STAGETYPE_ORIGINAL,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		note = "Mom all stage types",
		bosses = {
			{id = "Mom", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE3_2,
		stage_type = StageType.STAGETYPE_WOTL,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		note = "Mom all stage types",
		bosses = {
			{id = "Mom", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE3_2,
		stage_type = StageType.STAGETYPE_AFTERBIRTH,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		note = "Mom all stage types",
		bosses = {
			{id = "Mom", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE3_2,
		stage_type = StageType.STAGETYPE_REPENTANCE,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		note = "Normal Mom fight pool; BACKWARDS_PATH_INIT uses stage STB Variant 1 via boss_pick.pick_dads_note_prep",
		bosses = {
			{id = "Mom", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE3_2,
		stage_type = StageType.STAGETYPE_REPENTANCE_B,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		note = "Normal Mom fight pool; BACKWARDS_PATH_INIT uses stage STB Variant 1 via boss_pick.pick_dads_note_prep",
		bosses = {
			{id = "Mom", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE4_2,
		stage_type = StageType.STAGETYPE_ORIGINAL,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		note = "Mom's Heart / It Lives",
		bosses = {
			{id = "Mom's Heart", weight = 1.0, only_replace_subtype = 8},
			{id = "It Lives", weight = 1.0, only_replace_subtype = 25},
		},
	},
	{
		stage = LevelStage.STAGE4_2,
		stage_type = StageType.STAGETYPE_WOTL,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		note = "Mom's Heart / It Lives",
		bosses = {
			{id = "Mom's Heart", weight = 1.0, only_replace_subtype = 8},
			{id = "It Lives", weight = 1.0, only_replace_subtype = 25},
		},
	},
	{
		stage = LevelStage.STAGE4_2,
		stage_type = StageType.STAGETYPE_AFTERBIRTH,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "fight",
		note = "Mom's Heart / It Lives",
		bosses = {
			{id = "Mom's Heart", weight = 1.0, only_replace_subtype = 8},
			{id = "It Lives", weight = 1.0, only_replace_subtype = 25},
		},
	},
	{
		stage = LevelStage.STAGE4_2,
		stage_type = StageType.STAGETYPE_REPENTANCE,
		fixed = true,
		pool_mode = "fixed",
		role_89 = "mother_gate",
		role_neg10 = "mother_fight",
		note = "Mother",
		bosses = {
			{id = "Mother", weight = 1.0},
		},
	},
	{
		stage = LevelStage.STAGE4_2,
		stage_type = StageType.STAGETYPE_REPENTANCE_B,
		skip_scan = true,
		note = "Mortis II Mother exists in StageAPI but Mortis out of scope",
		bosses = {},
	},
}

-- Display / legacy names -> StageAPI canonical BossID
M.BOSS_ALIASES = {
	["Monstro II"] = "Monstro 2",
	["Mega Gurdy"] = "Mama Gurdy",
}

-- Extra spawn identities (empty: do not use StageAPI's wrong 276 Roundy aliases).
M.BOSS_ENTITY_ALT = {
}

-- Known non-1x1-only bosses for ordinary Boss@89 (not missing rooms).
M.UNSUPPORTED_SHAPE_FOR_89 = {
	["Great Gideon"] = true,
	["Tuff Twins"] = true,
	["The Shell"] = true,
	["Mr. Fred"] = true,
}

-- Corpse II Mother split (audit-verified RoomConfig; wired by corridor_plan / boss_pick).
M.MOTHER_CORPSE_II = {
	entry_89 = {
		source_stb = StbType.SPECIAL_ROOMS,
		variant = 6000,
		role = "mother_gate",
	},
	arena_neg10 = {
		source_stb = StbType.CORPSE,
		variant = 1,
		boss_id = "Mother",
		prefer_shapes = {
			RoomShape.ROOMSHAPE_1x2,
			RoomShape.ROOMSHAPE_2x1,
			RoomShape.ROOMSHAPE_2x2,
		},
		role = "mother_fight",
	},
}

-- Void Delirium endpoint: SPECIAL_ROOMS variant 3414 (shape 2x2, subtype 70).
-- Footprint claims 89 + right/down neighbors; deal@90 is suppressed on Void.
M.DELIRIUM_VOID = {
	boss_89 = {
		source_stb = StbType.SPECIAL_ROOMS,
		variant = 3414,
		boss_id = "Delirium",
		expect_subtype = 70,
		role = "delirium",
		shape = (RoomShape and RoomShape.ROOMSHAPE_2x2) or 8,
	},
}

function M.list_scan_targets()
	local out = {}
	for _, def in ipairs(M.FLOOR_DEFS) do
		if not def.skip_scan then out[#out + 1] = def end
	end
	return out
end

function M.find_floor_def(stage, stage_type)
	stage = tonumber(stage); stage_type = tonumber(stage_type)
	local fallback = nil
	for _, def in ipairs(M.FLOOR_DEFS) do
		if def.stage == stage and (def.all_types or def.stage_type == stage_type) then
			if def.fixed then return def end
			if fallback == nil then fallback = def end
		end
	end
	return fallback
end

function M.canonical_boss_id(name)
	if type(name) ~= "string" or name == "" then return nil end
	return M.BOSS_ALIASES[name] or name
end

function M.entity_key(typ, var, sub)
	return (tonumber(typ) or 0) .. ":" .. (tonumber(var) or 0) .. ":" .. (tonumber(sub) or 0)
end

local function index_add(idx, key, id)
	id = M.canonical_boss_id(id)
	if not id or key == nil then return end
	local cur = idx[key]
	if cur == nil then
		idx[key] = {id}
		return
	end
	for i = 1, #cur do
		if cur[i] == id then return end
	end
	cur[#cur + 1] = id
end

-- Multi-id entity index: shared Type/Variant (Larry Jr / Tuff Twins) keep both candidates.
function M.build_entity_index()
	local idx = {}
	for id, ent in pairs(M.BOSS_ENTITY) do
		local cid = M.canonical_boss_id(id)
		index_add(idx, M.entity_key(ent.type, ent.variant, ent.subtype), cid)
		index_add(idx, tostring(ent.type) .. ":" .. tostring(ent.variant), cid)
	end
	for _, ent in ipairs(M.BOSS_ENTITY_ALT or {}) do
		local cid = M.canonical_boss_id(ent.id)
		index_add(idx, M.entity_key(ent.type, ent.variant, ent.subtype), cid)
		index_add(idx, tostring(ent.type) .. ":" .. tostring(ent.variant), cid)
	end
	return idx
end

function M.lookup_entity_ids(entity_index, typ, var, sub)
	if not entity_index then return {} end
	local ids = entity_index[M.entity_key(typ, var, sub)]
		or entity_index[tostring(tonumber(typ) or 0) .. ":" .. tostring(tonumber(var) or 0)]
	if type(ids) ~= "table" then return {} end
	return ids
end

function M.boss_id_from_subtype(subtype)
	return M.canonical_boss_id(M.BOSS_TYPE_TO_ID[tonumber(subtype)])
end

function M.is_unsupported_shape_for_89(boss_id)
	boss_id = M.canonical_boss_id(boss_id)
	return boss_id and M.UNSUPPORTED_SHAPE_FOR_89[boss_id] == true
end

return M

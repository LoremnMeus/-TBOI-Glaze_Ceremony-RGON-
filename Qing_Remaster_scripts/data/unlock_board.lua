-- 由 html/qing_unlock_board_save.json 自动生成。
-- 本文件由成就展示与可选道具池解锁逻辑直接读取。
-- 修改解锁板后请重新生成，不要直接维护本文件。

return {
	boss_columns = {
		{
			key = "GlazeNormal",
			label = "琉璃（普通）",
		},
		{
			key = "GlazeHard",
			label = "琉璃（困难）",
		},
		{
			key = "ZeisNormal",
			label = "泽伊斯（普通）",
		},
		{
			key = "ZeisHard",
			label = "泽伊斯（困难）",
		},
		{
			key = "custom_col_1785574945065",
			label = "阿莱斯特",
		},
		{
			key = "custom_col_1785394801039",
			label = "结局3",
		},
	},
	boss_rows = {
		{
			code = "Isaac",
			name = "以撒",
		},
		{
			code = "Magdalene",
			name = "抹大拉",
		},
		{
			code = "Cain",
			name = "该隐",
		},
		{
			code = "Judas",
			name = "犹大",
		},
		{
			code = "BlueBaby",
			name = "???",
		},
		{
			code = "Eve",
			name = "夏娃",
		},
		{
			code = "Samson",
			name = "参孙",
		},
		{
			code = "Azazel",
			name = "阿撒泻勒",
		},
		{
			code = "Lazarus",
			name = "拉撒路",
		},
		{
			code = "Eden",
			name = "伊甸",
		},
		{
			code = "Lost",
			name = "游魂",
		},
		{
			code = "Lilith",
			name = "莉莉丝",
		},
		{
			code = "Keeper",
			name = "店主",
		},
		{
			code = "Apollyon",
			name = "亚玻伦",
		},
		{
			code = "Forgotten",
			name = "遗骸",
		},
		{
			code = "Bethany",
			name = "伯大尼",
		},
		{
			code = "JacobEsau",
			name = "雅各和以扫",
		},
		{
			code = "Isaac_B",
			name = "堕化以撒",
		},
		{
			code = "Magdalene_B",
			name = "堕化抹大拉",
		},
		{
			code = "Cain_B",
			name = "堕化该隐",
		},
		{
			code = "Judas_B",
			name = "堕化犹大",
		},
		{
			code = "BlueBaby_B",
			name = "堕化???",
		},
		{
			code = "Eve_B",
			name = "堕化夏娃",
		},
		{
			code = "Samson_B",
			name = "堕化参孙",
		},
		{
			code = "Azazel_B",
			name = "堕化阿撒泻勒",
		},
		{
			code = "Lazarus_B",
			name = "堕化拉撒路",
		},
		{
			code = "Eden_B",
			name = "堕化伊甸",
		},
		{
			code = "Lost_B",
			name = "堕化游魂",
		},
		{
			code = "Lilith_B",
			name = "堕化莉莉丝",
		},
		{
			code = "Keeper_B",
			name = "堕化店主",
		},
		{
			code = "Apollyon_B",
			name = "堕化亚玻伦",
		},
		{
			code = "Forgotten_B",
			name = "堕化遗骸",
		},
		{
			code = "Bethany_B",
			name = "堕化伯大尼",
		},
		{
			code = "Jacob_B",
			name = "堕化雅各",
		},
	},
	character_unlocks = {
		-- 模组角色：W.Qing
		["wq"] = {
			-- 解锁条件：超级撒旦
			["MegaSatan"] = {
				{
					uid = "Chiastolite",
					id = "82",
					enum_key = "Chiastolite",
					name = "Chiastolite",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：羔羊
			["Lamb"] = {
				{
					uid = "Touchstone",
					id = "2",
					enum_key = "Touchstone",
					name = "Touchstone",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：???
			["BlueBaby"] = {
				{
					uid = "Multiknife",
					id = "142",
					enum_key = "Multiknife",
					name = "Multiknife",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：死寂
			["Hush"] = {
				{
					uid = "Alchemy_Pot",
					id = "25",
					enum_key = "Alchemy_Pot",
					name = "Alchemy Pot",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：Boss Rush
			["BossRush"] = {
				{
					uid = "Assassin_s_Eye",
					id = "5",
					enum_key = "Assassin_s_Eye",
					name = "Assassin's Eye",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：精神错乱
			["Delirium"] = {
				{
					uid = "Mental_Hypnosis",
					id = "6",
					enum_key = "Mental_Hypnosis",
					name = "Mental Hypnosis",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：以撒
			["Isaac"] = {
				{
					uid = "Pageant_Cross_dresser",
					id = "28",
					enum_key = "Pageant_Cross_dresser",
					name = "Pageant Cross-dresser",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：撒旦
			["Satan"] = {
				{
					uid = "Super_Bombs",
					id = "13",
					enum_key = "Super_Bombs",
					name = "Super Bombs",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：祸兽
			["Beast"] = {
				{
					uid = "Delicate_Flower",
					id = "91",
					enum_key = "Delicate_Flower",
					name = "Delicate Flower",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：母亲
			["Mother"] = {
				{
					uid = "Black_Map",
					id = "21",
					enum_key = "Black_Map",
					name = "Black Map",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：贪婪模式
			["GreedMode"] = {
				{
					uid = "Gold_Rush",
					id = "7",
					enum_key = "Gold_Rush",
					name = "Gold Rush",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：琉璃王子（结局2）
			["custom_col_1784813595360"] = {
				{
					uid = "Glaze_Mushroom",
					id = "27",
					enum_key = "Glaze_Mushroom",
					name = "Glaze Mushroom",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：里角色/特殊
			["Tainted"] = {
				{
					uid = "My_Hat",
					id = "3",
					enum_key = "My_Hat",
					name = "My Hat",
					kind = "passive",
					content_type = "Item",
				},
				{
					uid = "My_Emblem",
					id = "46",
					enum_key = "My_Emblem",
					name = "My Emblem",
					kind = "passive",
					content_type = "Item",
				},
				{
					uid = "player:SP_W_Qing",
					id = "SP.W.Qing",
					enum_key = "SP_W_Qing",
					name = "SP.W.Qing",
					kind = "player",
					content_type = "Player",
				},
			},
			-- 解锁条件：究极贪婪
			["Greedier"] = {
				{
					uid = "Giant_Punch",
					id = "10",
					enum_key = "Giant_Punch",
					name = "Giant Punch",
					kind = "passive",
					content_type = "Item",
				},
			},
		},
		-- 模组角色：SP.W.Qing
		["Spwq"] = {
			-- 解锁条件：羔羊
			["Lamb"] = {
				{
					uid = "Theseus_s_Sign",
					id = "69",
					enum_key = "Theseus_s_Sign",
					name = "Theseus's Sign",
					kind = "passive",
					content_type = "Item",
				},
				{
					uid = "Charon_s_Sign",
					id = "134",
					enum_key = "Charon_s_Sign",
					name = "Charon's Sign",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：???
			["BlueBaby"] = {
				{
					uid = "The_Watcher",
					id = "9",
					enum_key = "The_Watcher",
					name = "The Watcher",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：Boss Rush
			["BossRush"] = {
				{
					uid = "Seeker_s_Eye",
					id = "93",
					enum_key = "Seeker_s_Eye",
					name = "Seeker's Eye",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：精神错乱
			["Delirium"] = {
				{
					uid = "Memory",
					id = "11",
					enum_key = "Memory",
					name = "Memory",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：以撒
			["Isaac"] = {
				{
					uid = "Remaster",
					id = "162",
					enum_key = "Remaster",
					name = "Remaster!",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：祸兽
			["Beast"] = {
				{
					uid = "My_Best_Friend",
					id = "12",
					enum_key = "My_Best_Friend",
					name = "My Best Friend",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：母亲
			["Mother"] = {
				{
					uid = "Live_Broadcast",
					id = "74",
					enum_key = "Live_Broadcast",
					name = "Live Broadcast",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：贪婪模式
			["GreedMode"] = {
				{
					uid = "Fate_s_Draw",
					id = "45",
					enum_key = "Fate_s_Draw",
					name = "Fate's Draw",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：撒旦
			["Satan"] = {
				{
					uid = "Tech_9",
					id = "4",
					enum_key = "Tech_9",
					name = "Tech 9",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：超级撒旦
			["MegaSatan"] = {
				{
					uid = "Brimstream",
					id = "14",
					enum_key = "Brimstream",
					name = "Brimstream",
					kind = "passive",
					content_type = "Item",
				},
				{
					uid = "Blaststone",
					id = "22",
					enum_key = "Blaststone",
					name = "Blaststone",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：死寂
			["Hush"] = {
				{
					uid = "Philosopher_s_stone",
					id = "97",
					enum_key = "Philosopher_s_stone",
					name = "Philosopher's stone",
					kind = "active",
					content_type = "Item",
				},
				{
					uid = "card:Qing_s_Soul",
					id = "2360",
					enum_key = "Qing_s_Soul",
					name = "Qing's Soul",
					kind = "card",
					content_type = "Card",
				},
			},
			-- 解锁条件：琉璃王子（结局2）
			["custom_col_1784813595360"] = {
				{
					uid = "More_Options",
					id = "44",
					enum_key = "More_Options___",
					name = "More Options??!",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：究极贪婪
			["Greedier"] = {
				{
					uid = "Apocalypse",
					id = "30",
					enum_key = "Tianyi",
					name = "Apocalypse",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：全标记
			["FullCompletion"] = {
				{
					uid = "Air_Flight",
					id = "8",
					enum_key = "Air_Flight",
					name = "Air Flight",
					kind = "passive",
					content_type = "Item",
				},
				{
					uid = "Air_Terror",
					id = "26",
					enum_key = "Air_Terror",
					name = "Air Terror",
					kind = "passive",
					content_type = "Item",
				},
				{
					uid = "Blue_Print",
					id = "88",
					enum_key = "Blue_Print",
					name = "Blue Print",
					kind = "active",
					content_type = "Item",
				},
			},
		},
		-- 模组角色：Special
		["Special"] = {
		},
		-- 模组角色：Tecrorun
		["Tecrorun"] = {
			-- 解锁条件：以撒
			["Isaac"] = {
				{
					uid = "Tech_14",
					id = "92",
					enum_key = "Tech_14",
					name = "Tech 14",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：羔羊
			["Lamb"] = {
				{
					uid = "Field",
					id = "32",
					enum_key = "Field",
					name = "Field",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：琉璃王子（结局2）
			["custom_col_1784813595360"] = {
				{
					uid = "Glaze_Mirror",
					id = "116",
					enum_key = "Glaze_Mirror",
					name = "Glaze Mirror",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：死寂
			["Hush"] = {
				{
					uid = "Illumination",
					id = "108",
					enum_key = "Illumination",
					name = "Illumination",
					kind = "active",
					content_type = "Item",
				},
				{
					uid = "card:Tecro_s_Soul",
					id = "2428",
					enum_key = "Tecro_s_Soul",
					name = "Tecro's Soul",
					kind = "card",
					content_type = "Card",
				},
			},
			-- 解锁条件：Boss Rush
			["BossRush"] = {
				{
					uid = "Subera_Light",
					id = "124",
					enum_key = "Subera_Light",
					name = "Subera Light",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：超级撒旦
			["MegaSatan"] = {
				{
					uid = "Kaitian",
					id = "141",
					enum_key = "Kaitian",
					name = "Kaitian",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：妈妈的心
			["MomsHeart"] = {
				{
					uid = "Baby_Tecro",
					id = "135",
					enum_key = "Baby_Tecro",
					name = "Baby Tecro",
					kind = "familiar",
					content_type = "Item",
				},
			},
			-- 解锁条件：贪婪模式
			["GreedMode"] = {
				{
					uid = "Brilliant",
					id = "98",
					enum_key = "Brilliant",
					name = "Brilliant",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：撒旦
			["Satan"] = {
				{
					uid = "Ingestion_to_Night",
					id = "47",
					enum_key = "Ingestion_to_Night",
					name = "Ingestion to Night",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：???
			["BlueBaby"] = {
				{
					uid = "Lofty",
					id = "68",
					enum_key = "Lofty",
					name = "Lofty",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：母亲
			["Mother"] = {
				{
					uid = "Moment",
					id = "67",
					enum_key = "Moment",
					name = "Moment",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：究极贪婪
			["Greedier"] = {
				{
					uid = "card:Sting_r",
					id = "2434",
					enum_key = "Sting_r",
					name = "V - The Sting?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 模组角色：annA
		["annA"] = {
			-- 解锁条件：死寂
			["Hush"] = {
				{
					uid = "Calamity",
					id = "85",
					enum_key = "Calamity",
					name = "Calamity",
					kind = "active",
					content_type = "Item",
				},
				{
					uid = "card:Anna_s_Soul",
					id = "2429",
					enum_key = "Anna_s_Soul",
					name = "Anna's Soul",
					kind = "card",
					content_type = "Card",
				},
			},
			-- 解锁条件：???
			["BlueBaby"] = {
				{
					uid = "Shangrila",
					id = "126",
					enum_key = "Shangrila",
					name = "Shangrila",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：超级撒旦
			["MegaSatan"] = {
				{
					uid = "Dimension_Contact",
					id = "102",
					enum_key = "Dimension_Contact",
					name = "Dimension Contact",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：妈妈的心
			["MomsHeart"] = {
				{
					uid = "Baby_Anna",
					id = "136",
					enum_key = "Baby_Anna",
					name = "Baby Anna",
					kind = "familiar",
					content_type = "Item",
				},
			},
			-- 解锁条件：Boss Rush
			["BossRush"] = {
				{
					uid = "Spectralsword",
					id = "65",
					enum_key = "Spectralsword",
					name = "Spectralsword",
					kind = "active",
					content_type = "Item",
				},
				{
					uid = "Squiresaga",
					id = "66",
					enum_key = "Squiresaga",
					name = "Squiresaga",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：究极贪婪
			["Greedier"] = {
				{
					uid = "card:Eclipse_r",
					id = "2427",
					enum_key = "Eclipse_r",
					name = "XIX - The Eclipse?",
					kind = "card",
					content_type = "Card",
				},
			},
			-- 解锁条件：羔羊
			["Lamb"] = {
				{
					uid = "Drama_of_sorrow_and_joy",
					id = "75",
					enum_key = "Drama_of_sorrow_and_joy",
					name = "Drama of sorrow and joy",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：祸兽
			["Beast"] = {
				{
					uid = "Little_Duck",
					id = "23",
					enum_key = "Little_Duck",
					name = "Little Duck",
					kind = "passive",
					content_type = "Item",
				},
			},
		},
		-- 模组角色：Tecro
		["Tecro"] = {
			-- 解锁条件：羔羊
			["Lamb"] = {
				{
					uid = "Ritual_Sting",
					id = "120",
					enum_key = "Ritual_Sting",
					name = "Ritual Sting",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：超级撒旦
			["MegaSatan"] = {
				{
					uid = "Darkness",
					id = "1",
					enum_key = "Darkness",
					name = "Darkness",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：以撒
			["Isaac"] = {
				{
					uid = "Book_of_Rune",
					id = "105",
					enum_key = "Book_of_Rune",
					name = "Book of Rune",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：???
			["BlueBaby"] = {
				{
					uid = "Risemara",
					id = "81",
					enum_key = "Risemara",
					name = "Risemara",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：母亲
			["Mother"] = {
				{
					uid = "Tiramisu",
					id = "73",
					enum_key = "Tiramisu",
					name = "Tiramisu",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：究极贪婪
			["Greedier"] = {
				{
					uid = "card:Sting",
					id = "2433",
					enum_key = "Sting",
					name = "V - The Sting",
					kind = "card",
					content_type = "Card",
				},
			},
			-- 解锁条件：Boss Rush
			["BossRush"] = {
				{
					uid = "D773",
					id = "48",
					enum_key = "D773",
					name = "D773",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：贪婪模式
			["GreedMode"] = {
				{
					uid = "Qing_s_Faceted_Market_Diamond",
					id = "167",
					enum_key = "Qing_Faceted_Market_Diamond",
					name = "Qing's Faceted Market Diamond",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：祸兽
			["Beast"] = {
				{
					uid = "Final_Prism",
					id = "104",
					enum_key = "Final_Prism",
					name = "Final Prism",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：精神错乱
			["Delirium"] = {
				{
					uid = "Acrotomophilia",
					id = "128",
					enum_key = "Acrotomophilia",
					name = "Acrotomophilia",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：六使徒（结局3）
			["custom_col_1784816386034"] = {
				{
					uid = "trinket:Puncture_Symbol",
					id = "6",
					enum_key = "Puncture_Symbol",
					name = "Puncture Symbol",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
			-- 解锁条件：里角色/特殊
			["Tainted"] = {
				{
					uid = "player:Tecrorun",
					id = "Tecrorun",
					enum_key = "Tecrorun",
					name = "Tecrorun",
					kind = "player",
					content_type = "Player",
				},
			},
		},
		-- 模组角色：Zeistos
		["Zeis"] = {
			-- 解锁条件：羔羊
			["Lamb"] = {
				{
					uid = "Nihilistic_Artificial_Eye",
					id = "121",
					enum_key = "Nihilistic_Artificial_Eye",
					name = "Nihilistic Artificial Eye",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：超级撒旦
			["MegaSatan"] = {
				{
					uid = "Nazca",
					id = "60",
					enum_key = "Nazca",
					name = "Nazca",
					kind = "passive",
					content_type = "Item",
				},
				{
					uid = "Tzolkin",
					id = "76",
					enum_key = "Tzolkin",
					name = "Tzolkin",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：以撒
			["Isaac"] = {
				{
					uid = "Book_of_Vision",
					id = "57",
					enum_key = "Book_of_Vision",
					name = "Book of Vision",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：死寂
			["Hush"] = {
				{
					uid = "Cloundy",
					id = "61",
					enum_key = "Cloundy",
					name = "Cloundy",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：母亲
			["Mother"] = {
				{
					uid = "Cheater_s_Blessing",
					id = "101",
					enum_key = "Cheater_s_Blessing",
					name = "Cheater's Blessing",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：Boss Rush
			["BossRush"] = {
				{
					uid = "Ending_Count",
					id = "100",
					enum_key = "Ending_Count",
					name = "Ending Count",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：???
			["BlueBaby"] = {
				{
					uid = "The_True_Name",
					id = "87",
					enum_key = "The_True_Name",
					name = "The True Name",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：究极贪婪
			["Greedier"] = {
				{
					uid = "card:Profound",
					id = "2431",
					enum_key = "Profound",
					name = "XXI - The Profound",
					kind = "card",
					content_type = "Card",
				},
			},
			-- 解锁条件：精神错乱
			["Delirium"] = {
				{
					uid = "Hypermnesia",
					id = "90",
					enum_key = "Hypermnesia",
					name = "Hypermnesia",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：撒旦
			["Satan"] = {
				{
					uid = "Death_Sentence",
					id = "161",
					enum_key = "Death_Sentence",
					name = "Death Sentence",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：贪婪模式
			["GreedMode"] = {
				{
					uid = "trinket:Pacification_Mark",
					id = "1",
					enum_key = "Pacification_Mark",
					name = "Pacification Mark",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
			-- 解锁条件：祸兽
			["Beast"] = {
				{
					uid = "Fantastic_Inspiration",
					id = "131",
					enum_key = "Inspiration",
					name = "Fantastic Inspiration",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：六使徒（结局3）
			["custom_col_1784816386034"] = {
				{
					uid = "trinket:Transition_Symbol",
					id = "8",
					enum_key = "Transition_Symbol",
					name = "Transition Symbol",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
			-- 解锁条件：里角色/特殊
			["Tainted"] = {
				{
					uid = "player:Zeiz",
					id = "Zeiz",
					enum_key = "Zeiz",
					name = "Zeiz",
					kind = "player",
					content_type = "Player",
				},
			},
		},
		-- 模组角色：Marriano
		["Marriano"] = {
			-- 解锁条件：???
			["BlueBaby"] = {
				{
					uid = "Pathetique",
					id = "112",
					enum_key = "Pathetique",
					name = "Pathetique",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：撒旦
			["Satan"] = {
				{
					uid = "Suture_Needle",
					id = "33",
					enum_key = "Suture_Needle",
					name = "Suture Needle",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：死寂
			["Hush"] = {
				{
					uid = "Disequilibrium",
					id = "95",
					enum_key = "Disequilibrium",
					name = "Disequilibrium",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：妈妈的心
			["MomsHeart"] = {
				{
					uid = "Baby_Marri",
					id = "138",
					enum_key = "Baby_Marri",
					name = "Baby Marri",
					kind = "familiar",
					content_type = "Item",
				},
			},
			-- 解锁条件：羔羊
			["Lamb"] = {
				{
					uid = "Fresh_Death",
					id = "114",
					enum_key = "Fresh_Death",
					name = "Fresh Death",
					kind = "passive",
					content_type = "Item",
				},
				{
					uid = "The_Suture_Needle",
					id = "115",
					enum_key = "The_Suture_Needle",
					name = "The Suture Needle",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：Boss Rush
			["BossRush"] = {
				{
					uid = "Colorblindness",
					id = "31",
					enum_key = "Colorblindness",
					name = "Colorblindness",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：贪婪模式
			["GreedMode"] = {
				{
					uid = "trinket:Consistent_Expectations",
					id = "14",
					enum_key = "Consistent_Expectations",
					name = "Consistent Expectations",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
			-- 解锁条件：母亲
			["Mother"] = {
				{
					uid = "Sacred_Mind_Shield",
					id = "166",
					enum_key = "Sacred_Mind_Shield",
					name = "Sacred Mind Shield",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：精神错乱
			["Delirium"] = {
				{
					uid = "Day_Dreamer",
					id = "94",
					enum_key = "Day_Dreamer",
					name = "Day Dreamer",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：以撒
			["Isaac"] = {
				{
					uid = "D_Plus",
					id = "125",
					enum_key = "D_Plus",
					name = "D Plus",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：祸兽
			["Beast"] = {
				{
					uid = "Dyson_Star",
					id = "89",
					enum_key = "Dyson_Star",
					name = "Dyson Star",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：六使徒（结局3）
			["custom_col_1784816386034"] = {
				{
					uid = "trinket:Adhesive_Symbol",
					id = "9",
					enum_key = "Adhesive_Symbol",
					name = "Adhesive Symbol",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
		},
		-- 模组角色：Anna
		["Anna"] = {
			-- 解锁条件：琉璃王子（结局2）
			["custom_col_1784813595360"] = {
				{
					uid = "Pendulum_Star",
					id = "54",
					enum_key = "Pendulum_Star",
					name = "Pendulum Star",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：超级撒旦
			["MegaSatan"] = {
				{
					uid = "Evil_Intervention",
					id = "106",
					enum_key = "Evil_Intervention",
					name = "Evil Intervention",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：羔羊
			["Lamb"] = {
				{
					uid = "Core_Brooch",
					id = "130",
					enum_key = "Core_Brooch",
					name = "Core Brooch",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：贪婪模式
			["GreedMode"] = {
				{
					uid = "Reserved_Judgment",
					id = "160",
					enum_key = "Reserved_Judgment",
					name = "Reserved Judgment",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：Boss Rush
			["BossRush"] = {
				{
					uid = "Book_of_Future",
					id = "51",
					enum_key = "Book_of_Future",
					name = "Book of Future",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：究极贪婪
			["Greedier"] = {
				{
					uid = "card:Eclipse",
					id = "2426",
					enum_key = "Eclipse",
					name = "XIX - The Eclipse",
					kind = "card",
					content_type = "Card",
				},
			},
			-- 解锁条件：以撒
			["Isaac"] = {
				{
					uid = "Book_of_The_Law",
					id = "56",
					enum_key = "Book_of_The_Law",
					name = "Book of The Law",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：???
			["BlueBaby"] = {
				{
					uid = "Devil_s_Heart",
					id = "49",
					enum_key = "Devil_s_Heart",
					name = "Devil's Heart",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：母亲
			["Mother"] = {
				{
					uid = "Cable_Jar",
					id = "71",
					enum_key = "Cable_Jar",
					name = "Cable Jar",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：六使徒（结局3）
			["custom_col_1784816386034"] = {
				{
					uid = "trinket:Hoarding_Symbol",
					id = "7",
					enum_key = "Hoarding_Symbol",
					name = "Hoarding Symbol",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
			-- 解锁条件：里角色/特殊
			["Tainted"] = {
				{
					uid = "player:annA",
					id = "annA",
					enum_key = "annA",
					name = "annA",
					kind = "player",
					content_type = "Player",
				},
			},
		},
		-- 模组角色：Autio
		["Autio"] = {
			-- 解锁条件：以撒
			["Isaac"] = {
				{
					uid = "Abiogenesis",
					id = "169",
					enum_key = "Abiogenesis",
					name = "Abiogenesis",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：???
			["BlueBaby"] = {
				{
					uid = "Dark_Mysticism",
					id = "113",
					enum_key = "Dark_Mysticism",
					name = "Dark Mysticism",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：死寂
			["Hush"] = {
				{
					uid = "Chasm",
					id = "110",
					enum_key = "Chasm",
					name = "Chasm",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：妈妈的心
			["MomsHeart"] = {
				{
					uid = "Baby_Autio",
					id = "139",
					enum_key = "Baby_Autio",
					name = "Baby Autio",
					kind = "familiar",
					content_type = "Item",
				},
			},
			-- 解锁条件：撒旦
			["Satan"] = {
				{
					uid = "Dragon_Tooth",
					id = "143",
					enum_key = "Dragon_Tooth",
					name = "Dragon Tooth",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：贪婪模式
			["GreedMode"] = {
				{
					uid = "trinket:Equality_Agreement",
					id = "13",
					enum_key = "Equality_Agreement",
					name = "Equality Agreement",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
			-- 解锁条件：羔羊
			["Lamb"] = {
				{
					uid = "Shadow_Bottle",
					id = "86",
					enum_key = "Shadow_Bottle",
					name = "Shadow Bottle",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：精神错乱
			["Delirium"] = {
				{
					uid = "Procrastination",
					id = "165",
					enum_key = "Procrastination",
					name = "Procrastination",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：Boss Rush
			["BossRush"] = {
				{
					uid = "Phantom_Crown",
					id = "122",
					enum_key = "Phantom_Crown",
					name = "Phantom Crown",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：母亲
			["Mother"] = {
				{
					uid = "Wavering_Eyes",
					id = "53",
					enum_key = "Wavering_Eyes",
					name = "Wavering Eyes",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：祸兽
			["Beast"] = {
				{
					uid = "Regenesis",
					id = "171",
					enum_key = "Regenesis",
					name = "Regenesis",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：六使徒（结局3）
			["custom_col_1784816386034"] = {
				{
					uid = "trinket:Straining_Symbol",
					id = "10",
					enum_key = "Straining_Symbol",
					name = "Straining Symbol",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
		},
		-- 模组角色：Lu
		["Lu"] = {
			-- 解锁条件：以撒
			["Isaac"] = {
				{
					uid = "Book_of_6_sin",
					id = "111",
					enum_key = "Book_of_6_sin",
					name = "Book of 6 sin",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：死寂
			["Hush"] = {
				{
					uid = "Deconstruction",
					id = "96",
					enum_key = "Destruction",
					name = "Deconstruction",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：精神错乱
			["Delirium"] = {
				{
					uid = "Annihilation",
					id = "83",
					enum_key = "Annihilation",
					name = "Annihilation",
					kind = "passive",
					content_type = "Item",
				},
				{
					uid = "Annihilation_2",
					id = "84",
					enum_key = "Annihilation_",
					name = "Annihilation ",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：妈妈的心
			["MomsHeart"] = {
				{
					uid = "Baby_Lu",
					id = "140",
					enum_key = "Baby_Lu",
					name = "Baby Lu",
					kind = "familiar",
					content_type = "Item",
				},
			},
			-- 解锁条件：贪婪模式
			["GreedMode"] = {
				{
					uid = "trinket:Bundled_Sale",
					id = "15",
					enum_key = "Bundled_Sale",
					name = "Bundled Sale",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
			-- 解锁条件：羔羊
			["Lamb"] = {
				{
					uid = "World_Arc",
					id = "103",
					enum_key = "World_Arc",
					name = "World Arc",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：撒旦
			["Satan"] = {
				{
					uid = "Tears_of_Pearl",
					id = "79",
					enum_key = "Tears_of_Pearl",
					name = "Tears of Pearl",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：母亲
			["Mother"] = {
				{
					uid = "Hunger_Burger",
					id = "132",
					enum_key = "Hunger_Burger",
					name = "Hunger Burger",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：???
			["BlueBaby"] = {
				{
					uid = "Cursed_Mask",
					id = "119",
					enum_key = "Cursed_Mask",
					name = "Cursed Mask",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：祸兽
			["Beast"] = {
				{
					uid = "Cup_Cat",
					id = "168",
					enum_key = "Cup_Cat",
					name = "Cup Cat",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：六使徒（结局3）
			["custom_col_1784816386034"] = {
				{
					uid = "trinket:Allocation_Symbol",
					id = "11",
					enum_key = "Allocation_Symbol",
					name = "Allocation Symbol",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
		},
		-- 模组角色：Zeiz
		["Zeiz"] = {
			-- 解锁条件：死寂
			["Hush"] = {
				{
					uid = "Contemplation",
					id = "109",
					enum_key = "Contemplation",
					name = "Contemplation",
					kind = "passive",
					content_type = "Item",
				},
				{
					uid = "card:Zeis_s_Soul",
					id = "2430",
					enum_key = "Zeis_s_Soul",
					name = "Zeis's Soul",
					kind = "card",
					content_type = "Card",
				},
			},
			-- 解锁条件：羔羊
			["Lamb"] = {
				{
					uid = "DVF",
					id = "50",
					enum_key = "DVF",
					name = "D-V-F",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：妈妈的心
			["MomsHeart"] = {
				{
					uid = "Baby_Zeis",
					id = "137",
					enum_key = "Baby_Zeis",
					name = "Baby Zeis",
					kind = "familiar",
					content_type = "Item",
				},
			},
			-- 解锁条件：琉璃王子（结局2）
			["custom_col_1784813595360"] = {
				{
					uid = "It_s_a_trick",
					id = "29",
					enum_key = "It_s_a_trick",
					name = "It's a trick!!",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：以撒
			["Isaac"] = {
				{
					uid = "Book_of_Voice",
					id = "58",
					enum_key = "Book_of_Voice",
					name = "Book of Voice",
					kind = "active",
					content_type = "Item",
				},
				{
					uid = "The_Voice",
					id = "170",
					enum_key = "The_Voice",
					name = "The Voice",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：贪婪模式
			["GreedMode"] = {
				{
					uid = "Skiel",
					id = "62",
					enum_key = "Skiel",
					name = "Skiel",
					kind = "passive",
					content_type = "Item",
				},
				{
					uid = "Wisel",
					id = "63",
					enum_key = "Wisel",
					name = "Wisel",
					kind = "passive",
					content_type = "Item",
				},
				{
					uid = "Granel",
					id = "64",
					enum_key = "Granel",
					name = "Granel",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：撒旦
			["Satan"] = {
				{
					uid = "Heart_Change",
					id = "70",
					enum_key = "Heart_Change",
					name = "Heart Change",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：Boss Rush
			["BossRush"] = {
				{
					uid = "Muscae_Volitantes",
					id = "133",
					enum_key = "Muscae_Volitantes",
					name = "Muscae Volitantes",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 解锁条件：究极贪婪
			["Greedier"] = {
				{
					uid = "card:Profound_r",
					id = "2432",
					enum_key = "Profound_r",
					name = "XXI - The Profound?",
					kind = "card",
					content_type = "Card",
				},
			},
			-- 解锁条件：母亲
			["Mother"] = {
				{
					uid = "Loneliness",
					id = "129",
					enum_key = "Loneliness",
					name = "Loneliness",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：祸兽
			["Beast"] = {
				{
					uid = "Pareidolia",
					id = "77",
					enum_key = "Pareidolia",
					name = "Pareidolia",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：???
			["BlueBaby"] = {
				{
					uid = "Gospel",
					id = "72",
					enum_key = "Gospel",
					name = "Gospel",
					kind = "passive",
					content_type = "Item",
				},
			},
		},
		-- 模组角色：Others
		["Others"] = {
		},
		-- 模组角色：Noia
		["custom_row_1785848579295"] = {
			-- 解锁条件：???
			["BlueBaby"] = {
				{
					uid = "Bloody_Map",
					id = "163",
					enum_key = "Bloody_Map",
					name = "Bloody Map",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：超级撒旦
			["MegaSatan"] = {
				{
					uid = "Blood_Wing",
					id = "123",
					enum_key = "Blood_Wing",
					name = "Blood Wing",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 解锁条件：贪婪模式
			["GreedMode"] = {
				{
					uid = "Golden_Slot",
					id = "164",
					enum_key = "Golden_Slot",
					name = "Golden Slot",
					kind = "active",
					content_type = "Item",
				},
			},
		},
	},

	boss_unlocks = {
		-- 原版角色：以撒
		["Isaac"] = {
			-- 模组 Boss 击破标记：琉璃（普通）
			["GlazeNormal"] = {
				{
					uid = "card:Glaze_dice_shard",
					id = "2359",
					enum_key = "Glaze_dice_shard",
					name = "Glazed Dice Shard",
					kind = "card",
					content_type = "Card",
				},
			},
			-- 模组 Boss 击破标记：琉璃（困难）
			["GlazeHard"] = {
				{
					uid = "Paranoia",
					id = "118",
					enum_key = "Paranoia",
					name = "Paranoia",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_IIII",
					id = "144",
					enum_key = "DI_III",
					name = "D_IIII",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Fool",
					id = "2378",
					enum_key = "Fool",
					name = "0 - The Fool",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：抹大拉
		["Magdalene"] = {
			-- 模组 Boss 击破标记：琉璃（普通）
			["GlazeNormal"] = {
				{
					uid = "pickup:Glaze_Heart",
					id = "Glaze_Heart",
					enum_key = "Glaze_Heart",
					name = "Glaze heart",
					kind = "pickup",
					content_type = "Pickup",
				},
			},
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Heart",
					id = "145",
					enum_key = "D_Heart",
					name = "D Heart",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Lover",
					id = "2386",
					enum_key = "Lover",
					name = "VI - Lover",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：该隐
		["Cain"] = {
			-- 模组 Boss 击破标记：琉璃（普通）
			["GlazeNormal"] = {
				{
					uid = "pickup:Glaze_Key",
					id = "Glaze_Key",
					enum_key = "Glaze_Key",
					name = "Glaze key",
					kind = "pickup",
					content_type = "Pickup",
				},
			},
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Key",
					id = "146",
					enum_key = "D_Key",
					name = "D Key",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Hierophant",
					id = "2385",
					enum_key = "Hierophant",
					name = "V - The Hierophant",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Adjustment",
					id = "2388",
					enum_key = "Adjustment",
					name = "VIII - Adjustment",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：犹大
		["Judas"] = {
			-- 模组 Boss 击破标记：琉璃（普通）
			["GlazeNormal"] = {
				{
					uid = "pickup:Glaze_Enemy",
					id = "Glaze_Enemy",
					enum_key = "Glaze_Enemy",
					name = "Glazed Enemy",
					kind = "pickup",
					content_type = "Pickup",
				},
			},
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Bomb",
					id = "147",
					enum_key = "D_Bomb",
					name = "D Bomb",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Emperor",
					id = "2384",
					enum_key = "Emperor",
					name = "IV - The Emperor",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Art_r",
					id = "2418",
					enum_key = "Art_r",
					name = "XIV - Art?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：???
		["BlueBaby"] = {
			-- 模组 Boss 击破标记：琉璃（普通）
			["GlazeNormal"] = {
				{
					uid = "pickup:Glaze_Poop",
					id = "Glaze_Poop",
					enum_key = "Glaze_Poop",
					name = "Glaze big poop",
					kind = "pickup",
					content_type = "Pickup",
				},
			},
			-- 模组 Boss 击破标记：琉璃（困难）
			["GlazeHard"] = {
				{
					uid = "Destiny_Anchor",
					id = "127",
					enum_key = "Destiny_Anchor",
					name = "Destiny Anchor",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Cross",
					id = "149",
					enum_key = "D_Cross",
					name = "D Cross",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Faint",
					id = "2393",
					enum_key = "Faint",
					name = "XIII - Faint",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：夏娃
		["Eve"] = {
			-- 模组 Boss 击破标记：琉璃（普通）
			["GlazeNormal"] = {
				{
					uid = "pickup:Glaze_Bomb",
					id = "Glaze_Bomb",
					enum_key = "Glaze_Bomb",
					name = "Glaze bomb",
					kind = "pickup",
					content_type = "Pickup",
				},
			},
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_RazorBlade",
					id = "148",
					enum_key = "D_RazorBlade",
					name = "D RazorBlade",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Witch",
					id = "2379",
					enum_key = "Witch",
					name = "I - The Witch",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Invoker",
					id = "2380",
					enum_key = "Invoker",
					name = "I - The Invoker",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Wizard",
					id = "2381",
					enum_key = "Wizard",
					name = "I - The Wizard",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：参孙
		["Samson"] = {
			-- 模组 Boss 击破标记：琉璃（普通）
			["GlazeNormal"] = {
				{
					uid = "pickup:Glaze_Chest",
					id = "Glaze_Chest",
					enum_key = "Glaze_Chest",
					name = "Glaze chest",
					kind = "pickup",
					content_type = "Pickup",
				},
			},
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Lusty",
					id = "150",
					enum_key = "D_Lusty",
					name = "D Lusty",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Chariot",
					id = "2387",
					enum_key = "Chariot",
					name = "VII - Chariot",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Lure",
					id = "2391",
					enum_key = "Lure",
					name = "XI - Lure",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：阿撒泻勒
		["Azazel"] = {
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Flame",
					id = "151",
					enum_key = "D_Flame",
					name = "D Flame",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Devil",
					id = "2395",
					enum_key = "Devil",
					name = "XV - The Devil",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：拉撒路
		["Lazarus"] = {
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Rag",
					id = "152",
					enum_key = "D_Rag",
					name = "D Rag",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Tower",
					id = "2396",
					enum_key = "Tower",
					name = "XVI - The Tower",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：伊甸
		["Eden"] = {
			-- 模组 Boss 击破标记：琉璃（普通）
			["GlazeNormal"] = {
				{
					uid = "pickup:Glaze_Grabbag",
					id = "Glaze_Grabbag",
					enum_key = "Glaze_Grabbag",
					name = "Glaze grabbag",
					kind = "pickup",
					content_type = "Pickup",
				},
			},
			-- 模组 Boss 击破标记：琉璃（困难）
			["GlazeHard"] = {
				{
					uid = "Mental_Disorder",
					id = "117",
					enum_key = "Mental_Disorder",
					name = "Mental Disorder",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Soul",
					id = "154",
					enum_key = "D_Soul",
					name = "D Soul",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Aeon",
					id = "2400",
					enum_key = "Aeon",
					name = "XX - The Aeon",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：游魂
		["Lost"] = {
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Trinity",
					id = "153",
					enum_key = "D_Trinity",
					name = "D Trinity",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Hanged_Man",
					id = "2392",
					enum_key = "Hanged_Man",
					name = "XII - The Hanged Man",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：莉莉丝
		["Lilith"] = {
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Sacrificalaltar",
					id = "155",
					enum_key = "D_Sacrificalaltar",
					name = "D Sacrificalaltar",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Empress",
					id = "2383",
					enum_key = "Empress",
					name = "III - The Empress",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：店主
		["Keeper"] = {
			-- 模组 Boss 击破标记：琉璃（普通）
			["GlazeNormal"] = {
				{
					uid = "pickup:Glaze_Coin",
					id = "Glaze_Coin",
					enum_key = "Glaze_Coin",
					name = "Glaze coin",
					kind = "pickup",
					content_type = "Pickup",
				},
			},
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Coin",
					id = "156",
					enum_key = "D_Coin",
					name = "D Coin",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Hermit",
					id = "2389",
					enum_key = "Hermit",
					name = "IX - The Hermit",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：亚玻伦
		["Apollyon"] = {
			-- 模组 Boss 击破标记：琉璃（普通）
			["GlazeNormal"] = {
				{
					uid = "pickup:Glaze_Spider",
					id = "Glaze_Spider",
					enum_key = "Glaze_Spider",
					name = "Glazed Spider",
					kind = "pickup",
					content_type = "Pickup",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Universe",
					id = "2401",
					enum_key = "Universe",
					name = "XXI - The Universe",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：遗骸
		["Forgotten"] = {
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Pointyrib",
					id = "157",
					enum_key = "D_Pointyrib",
					name = "D Pointyrib",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Star",
					id = "2397",
					enum_key = "Star",
					name = "XVII - The Star",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Moon",
					id = "2398",
					enum_key = "Moon",
					name = "XVIII - The Moon",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Sun",
					id = "2399",
					enum_key = "Sun",
					name = "XIX - The Sun",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：伯大尼
		["Bethany"] = {
			-- 模组 Boss 击破标记：琉璃（普通）
			["GlazeNormal"] = {
				{
					uid = "pickup:Glaze_Battery",
					id = "Glaze_Battery",
					enum_key = "Glaze_Battery",
					name = "Glaze battery",
					kind = "pickup",
					content_type = "Pickup",
				},
			},
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "Book_of_Dull",
					id = "158",
					enum_key = "Book_of_Dull",
					name = "Book of Dull",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Priestess",
					id = "2382",
					enum_key = "Priestess",
					name = "II - The High Priestess",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：雅各和以扫
		["JacobEsau"] = {
			-- 模组 Boss 击破标记：泽伊斯（普通）
			["ZeisNormal"] = {
				{
					uid = "D_Pack",
					id = "159",
					enum_key = "D_Pack",
					name = "D Pack",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Wheel_of_Destiny",
					id = "2390",
					enum_key = "Wheel_of_Destiny",
					name = "X - The Wheel of Destiny",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化以撒
		["Isaac_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Fool_r",
					id = "2402",
					enum_key = "Fool_r",
					name = "0 - The Fool?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化抹大拉
		["Magdalene_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Lover_r",
					id = "2408",
					enum_key = "Lover_r",
					name = "VI - The Lover?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化该隐
		["Cain_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Hierophant_r",
					id = "2407",
					enum_key = "Hierophant_r",
					name = "V - The Hierophant?",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Adjustment_r",
					id = "2410",
					enum_key = "Adjustment_r",
					name = "VIII - Adjustment?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化犹大
		["Judas_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Art",
					id = "2394",
					enum_key = "Art",
					name = "XIV - Art",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Emperor_r",
					id = "2406",
					enum_key = "Emperor_r",
					name = "IV - The Emperor?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化???
		["BlueBaby_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Faint_r",
					id = "2415",
					enum_key = "Faint_r",
					name = "XIII - Faint?",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Death_r",
					id = "2416",
					enum_key = "Death_r",
					name = "XIII - Death?",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Corpse_r",
					id = "2417",
					enum_key = "Corpse_r",
					name = "XIII - The Corpse?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化夏娃
		["Eve_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Sage_r",
					id = "2403",
					enum_key = "Sage_r",
					name = "I - The Sage?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化参孙
		["Samson_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Chariot_r",
					id = "2409",
					enum_key = "Chariot_r",
					name = "VII - The Chariot?",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Lure_r",
					id = "2413",
					enum_key = "Lure_r",
					name = "XI - Lure?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化阿撒泻勒
		["Azazel_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Devil_r",
					id = "2419",
					enum_key = "Devil_r",
					name = "XV - The Devil?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化拉撒路
		["Lazarus_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Tower_r",
					id = "2420",
					enum_key = "Tower_r",
					name = "XVI - The Tower?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化伊甸
		["Eden_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Aeon_r",
					id = "2424",
					enum_key = "Aeon_r",
					name = "XX - The Aeon?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化游魂
		["Lost_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Hanged_Man_r",
					id = "2414",
					enum_key = "Hanged_Man_r",
					name = "XII - The Hanged Man?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化莉莉丝
		["Lilith_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Empress_r",
					id = "2405",
					enum_key = "Empress_r",
					name = "III - The Empress?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化店主
		["Keeper_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Hermit_r",
					id = "2411",
					enum_key = "Hermit_r",
					name = "IX - The Hermit?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化亚玻伦
		["Apollyon_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Universe_r",
					id = "2425",
					enum_key = "Universe_r",
					name = "XXI - The Universe?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化遗骸
		["Forgotten_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Star_r",
					id = "2421",
					enum_key = "Star_r",
					name = "XVII - The Stars?",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Moon_r",
					id = "2422",
					enum_key = "Moon_r",
					name = "XVIII - The Moon?",
					kind = "card",
					content_type = "Card",
				},
				{
					uid = "card:Sun_r",
					id = "2423",
					enum_key = "Sun_r",
					name = "XIX - The Sun?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化伯大尼
		["Bethany_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Priestess_r",
					id = "2404",
					enum_key = "Priestess_r",
					name = "II - The High Priestess?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
		-- 原版角色：堕化雅各
		["Jacob_B"] = {
			-- 模组 Boss 击破标记：阿莱斯特
			["custom_col_1785574945065"] = {
				{
					uid = "card:Wheel_of_Destiny_r",
					id = "2412",
					enum_key = "Wheel_of_Destiny_r",
					name = "X - The Wheel of Destiny?",
					kind = "card",
					content_type = "Card",
				},
			},
		},
	},

	special_events = {
		{
			key = "Crushed",
			label = "被碾碎",
			category = "Others",
		},
		{
			key = "DefeatGlaze",
			label = "击败Glaze",
			category = "Others",
		},
		{
			key = "DefeatZennith",
			label = "击败zennith",
			category = "Others",
		},
		{
			key = "custom_event_1785574291152",
			label = "击败乞丐国王",
			category = "Others",
		},
		{
			key = "custom_event_1786539528390",
			label = "用尽恶魔胸针",
			category = "Others",
		},
		{
			key = "custom_event_1786539547154",
			label = "进入恶魔房后，在3秒内退出",
			category = "Others",
		},
		{
			key = "Cookie_Clicker",
			label = "挑战：曲奇点击者",
			category = "Others",
		},
		{
			key = "Dragon_Flight",
			label = "挑战：飞龙在天",
			category = "Others",
		},
		{
			key = "Fans_Service",
			label = "挑战：粉丝服务",
			category = "Others",
		},
		{
			key = "Feels_Like_Dead_Ashes",
			label = "挑战：心如死灰",
			category = "Others",
		},
		{
			key = "Fusion_Destiny",
			label = "挑战：命运融合",
			category = "Others",
		},
		{
			key = "Heterothermal_Concentric",
			label = "挑战：异热同心",
			category = "Others",
		},
		{
			key = "Invisible",
			label = "挑战：不为人知",
			category = "Others",
		},
		{
			key = "Louvre_puzzle",
			label = "挑战：卢浮宫难题",
			category = "Others",
		},
		{
			key = "Pointing",
			label = "挑战：指指点点",
			category = "Others",
		},
		{
			key = "Safe_Driving",
			label = "挑战：安全驾驶",
			category = "Others",
		},
		{
			key = "Swallow_The_Sun",
			label = "挑战：食日",
			category = "Others",
		},
		{
			key = "Unstable_State",
			label = "挑战：不稳定体",
			category = "Others",
		},
		{
			key = "custom_event_1787476895318",
			label = "击败阿莱斯特",
			category = "Others",
		},
	},

	special_unlocks = {
		-- 特殊解锁分类：Others
		["Others"] = {
			-- 特殊解锁条件：被碾碎
			["Crushed"] = {
				{
					uid = "card:Round_trip_Rail_Ticket",
					id = "2375",
					enum_key = "Round_trip_Rail_Ticket",
					name = "Round trip Rail Ticket",
					kind = "card",
					content_type = "Card",
					note = "被列车碾碎",
				},
				{
					uid = "card:One_way_Rail_Ticket",
					id = "2376",
					enum_key = "One_way_Rail_Ticket",
					name = "One way Rail Ticket",
					kind = "card",
					content_type = "Card",
				},
			},
			-- 特殊解锁条件：击败Glaze
			["DefeatGlaze"] = {
				{
					uid = "Crown_of_the_Glaze",
					id = "15",
					enum_key = "Crown_of_the_glaze",
					name = "Crown of the Glaze",
					kind = "passive",
					content_type = "Item",
					note = "任意角色击败琉璃王子后解锁",
				},
			},
			-- 特殊解锁条件：击败zennith
			["DefeatZennith"] = {
				{
					uid = "Aphasia",
					id = "59",
					enum_key = "Aphasia",
					name = "Aphasia",
					kind = "passive",
					content_type = "Item",
					note = "击败Zenith女士后解锁",
				},
			},
			-- 特殊解锁条件：击败乞丐国王
			["custom_event_1785574291152"] = {
				{
					uid = "A_Shard_of_Coin",
					id = "16",
					enum_key = "A_Shard_Of_Coin",
					name = "A Shard of Coin",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 特殊解锁条件：用尽恶魔胸针
			["custom_event_1786539528390"] = {
				{
					uid = "trinket:Broken_Brooch",
					id = "16",
					enum_key = "Broken_Brooch",
					name = "Broken Brooch",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
			-- 特殊解锁条件：进入恶魔房后，在3秒内退出
			["custom_event_1786539547154"] = {
				{
					uid = "trinket:Devil_s_Joke",
					id = "4",
					enum_key = "Devil_s_Joke",
					name = "Devil's Joke",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
			-- 特殊解锁条件：custom_event_1786539572973
			["custom_event_1786539572973"] = {
			},
			-- 特殊解锁条件：挑战：曲奇点击者
			["Cookie_Clicker"] = {
				{
					uid = "trinket:Pause_",
					id = "12",
					enum_key = "Pause_",
					name = "Pause?",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
			-- 特殊解锁条件：挑战：飞龙在天
			["Dragon_Flight"] = {
				{
					uid = "How_to_Fly",
					id = "107",
					enum_key = "Book_of_How_to_Fly",
					name = "How to Fly",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 特殊解锁条件：挑战：粉丝服务
			["Fans_Service"] = {
				{
					uid = "Fraternity",
					id = "99",
					enum_key = "Fraternity",
					name = "Fraternity",
					kind = "passive",
					content_type = "Item",
				},
			},
			-- 特殊解锁条件：挑战：心如死灰
			["Feels_Like_Dead_Ashes"] = {
				{
					uid = "Ember",
					id = "172",
					enum_key = "Ember",
					name = "Ember",
					kind = "passive",
					content_type = "Item",
					note = "完成挑战：心如死灰",
				},
			},
			-- 特殊解锁条件：挑战：命运融合
			["Fusion_Destiny"] = {
			},
			-- 特殊解锁条件：挑战：异热同心
			["Heterothermal_Concentric"] = {
			},
			-- 特殊解锁条件：挑战：不为人知
			["Invisible"] = {
			},
			-- 特殊解锁条件：挑战：卢浮宫难题
			["Louvre_puzzle"] = {
				{
					uid = "trinket:Torn_Moon_",
					id = "5",
					enum_key = "Torn_Moon_",
					name = "Torn Moon?",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
			-- 特殊解锁条件：挑战：指指点点
			["Pointing"] = {
			},
			-- 特殊解锁条件：挑战：安全驾驶
			["Safe_Driving"] = {
				{
					uid = "Hyper_Velocity",
					id = "52",
					enum_key = "Hyper_Velocity",
					name = "Hyper Velocity",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 特殊解锁条件：挑战：食日
			["Swallow_The_Sun"] = {
				{
					uid = "trinket:Dark_Particle",
					id = "2",
					enum_key = "Dark_Particle",
					name = "Dark Particle",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
			-- 特殊解锁条件：挑战：不稳定体
			["Unstable_State"] = {
				{
					uid = "D_NAN",
					id = "80",
					enum_key = "D_NAN",
					name = "D NAN",
					kind = "active",
					content_type = "Item",
				},
			},
			-- 特殊解锁条件：击败阿莱斯特
			["custom_event_1787476895318"] = {
				{
					uid = "Book_of_Thoth",
					id = "55",
					enum_key = "Book_of_Thoth",
					name = "Book of Thoth",
					kind = "active",
					content_type = "Item",
				},
				{
					uid = "trinket:Torn_Emperor",
					id = "3",
					enum_key = "Torn_Emperor",
					name = "Torn Emperor",
					kind = "trinket",
					content_type = "Trinket",
				},
			},
		},
	},
}

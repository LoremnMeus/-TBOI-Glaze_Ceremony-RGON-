local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local displaying_data = require("Qing_Remaster_scripts.translations.data")
local static_translations = require("Qing_Remaster_scripts.translations.translate")
local Items = enums.Items
local Cards = enums.Cards
local Trinkets = enums.Trinkets

local item = {
	zh = {},
	en = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
}

item.zh.Players = {}
item.zh.Trinkets = {}
item.zh.Cards = {}
item.zh.Collectibles = {
	[Items.It_s_a_trick] = {Name = function(info,player,ignore_changes)
		if not player then return info.RealName end
		if save.elses.glazed_trick == nil then save.elses.glazed_trick = 32 end
		local name = ""
		if item.zh.Collectibles[save.elses.glazed_trick] then 
			if save.elses.glazed_trick ~= Items.It_s_a_trick then
				name = item.zh.Collectibles[save.elses.glazed_trick].Name
				if type(name) == "function" then name = name(info,player,ignore_changes) end
			else name = "琉璃之核" end
		else
			local configitem = Isaac:GetItemConfig():GetCollectible(save.elses.glazed_trick)
			name = auxi.check_name_data(configitem.Name)
			local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder") 
			name = item_displaying_holder.check_description("UnItem",save.elses.glazed_trick,name,"",player).Name	--追加一次公示
		end
		return name.."?"
	end,RealName = "琉璃之核",Description = function(info,player)
		return "这不是我要的！！"
	end,},
	[Items.Tianyi] = {
		Name = "世末天依",Description = function(info,player,ignore_changes) 
			if ignore_changes == nil then 
				if save.elses.Tianyi == nil then save.elses.Tianyi = 1 end 
				save.elses.Tianyi = (save.elses.Tianyi - 1) % #(info.des) + 1 
			end 
			return info.des[save.elses.Tianyi or 1] 
		end,
	des = {"蝉时雨 化成淡墨渲染暮色","渗透着 勾勒出足迹与车辙","欢笑声 与漂浮的水汽饱和","隔着窗 同城市一并模糊了","拨弄着 旧吉他 哼着四拍子的歌","回音中 一个人 仿佛颇悠然自得","等凉雨 的温度 将不安燥热中和","寻觅着 风的波折","我仍然在 无人问津的阴雨霉湿之地","和着雨音 唱着没有听众的歌曲",
	"人潮仍是漫无目的地向目的地散去","忙碌着 无为着 继续","等待着谁能够将我的心房轻轻叩击","即使是你 也仅仅驻足了片刻便离去","想着或许 下个路口会有谁与我相遇","哪怕只 一瞬的 奇迹","夏夜空 出现在遥远的记忆","","绽放的 璀璨花火拥着繁星","消失前 做出最温柔的给予",
	"一如那些模糊身影的别离","困惑地 拘束着 如城市池中之鱼","或哽咽 或低泣 都融进了泡沫里","拖曳疲惫身躯 沉入冰冷的池底","注视着 色彩褪去","我仍然在无人问津的阴雨霉湿之地","和着雨音 唱着没有听众的歌曲","人潮仍是漫无目的地向目的地散去","忙碌着 无为着 继续",
	"祈求着谁 能够将我的 心房轻轻叩击","今天的你 是否会留意并尝试去靠近","因为或许 下个路口仍是同样的结局","不存在刹那的奇迹","极夜与永昼","别离与欢聚","脉搏与呼吸","找寻着意义","我仍然在无人问津的阴雨霉湿之地","和着雨音 唱着卖不出去的歌曲","浮游之人也挣扎不已执着存在下去",
	"追逐着 梦想着 继续","请别让我独自匍匐于滂沱世末之雨","和着雨音 唱着见证终结的歌曲","人们终于 结束了寻觅呆滞伫立原地","哭泣着 乞求着 奇迹","用这双手 拨出残缺染了锈迹的弦音","都隐没于淋漓的雨幕无声无息","曲终之时 你是否便会回应我的心音","将颤抖的双手牵起","迎来每个人的结局",},
	},
	[Items.D773] = {Name = function(info,player,ignore_changes) 
			save.elses.D773 = save.elses.D773 or 0
		return "D"..tostring(773 + save.elses.D773) end,
		Description = function(info) 
			return info.des[math.random(#(info.des))] 
		end,
	des = {"生活就像奥利奥","这就是究极的谜题","人生就是犯罪",},},
	[Items.Devil_s_Heart] = {Name = "恶魔的心智",Description = "他们自愿为我而死",Rnd_Special = {Name = "喜悦之种",Description = "永生？呵呵..",},},
	[Items.DVF] = {Name = "D-V-F",Description = "不惜一切代价",Rnd_Special = {Name = "- - -",Description = "- - -",weigh = 10,},},
	[Items.Book_of_Voice] = {Name = "假象之书",Description = "快，毁灭我",Rnd_Special = {Name = "零之书",Description = "一个声音在我耳边低语",weigh = 4,},},
	[Items.The_Voice] = {Name = "声音",Description = "现在，只剩我们两个了",},
	[Items.Regenesis] = {Name = "再世纪",Description = "连错误也会被继承",},
	[Items.Seeker_s_Eye] = {Name = "求索者之眼",Description = "这条路不是答案",},
	[Items.Nazca] = {Name = "纳兹卡线条",Description = "神明立于尘埃之上",Rnd_Special = {Name = "地缚地上绘",Description = "极星重临大地",weigh = 6,},},
	[Items.Spectralsword] = {Name = "妖刀 · 逢魔",Description = "物皆有灵",Rnd_Special = {Name = "青",Description = "斩生身兮凭风，合光来兮以扬声",weigh = 10,},},
	[Items.Squiresaga] = {Name = "妖刻 · 白隙",Description = "物皆有间",Rnd_Special = {Name = "赤",Description = "觅长生兮不获，流天火兮葬心魂",weigh = 10,},},
	[Items.Moment] = {Name = "妖星 · 一瞬",Description = "物皆有能",Rnd_Special = {Name = "苍",Description = "解万事兮尚忧，心惶惶兮难驻足",weigh = 10,},},
	[Items.Pareidolia] = {Name = "妖心 · 盈月",Description = "物皆有情",Rnd_Special = {Name = "黄",Description = "操太阴兮蚀痕，问执象兮曾不识",weigh = 10,},},
	[Items.Annihilation] = {Name = function(info,player,ignore_changes)
		if not player then return info.RealName end
		local pt = player:GetPlayerType()
		if info.Nameinfo[pt] then return info.Nameinfo[pt]
		else return info.RealName end
	end,RealName = "无知者书",
	Nameinfo = {
		[PlayerType.PLAYER_ISAAC] = "游戏规则书",
		[PlayerType.PLAYER_MAGDALENE] = "为爱献身",
		[PlayerType.PLAYER_CAIN] = "出千的奥秘",
		[PlayerType.PLAYER_JUDAS] = "彼列伪书",
		[PlayerType.PLAYER_BLUEBABY] = "膳食营养与搭配",
		[PlayerType.PLAYER_EVE] = "美妆初步教程",
		[PlayerType.PLAYER_SAMSON] = "心如止水",
		[PlayerType.PLAYER_AZAZEL] = "神曲",
		[PlayerType.PLAYER_LAZARUS] = "安息日",
		[PlayerType.PLAYER_EDEN] = "无知之风",
		[PlayerType.PLAYER_THELOST] = "默示录",
		[PlayerType.PLAYER_LAZARUS2] = "复活日",
		[PlayerType.PLAYER_BLACKJUDAS] = "彼列邪典",
		[PlayerType.PLAYER_LILITH] = "产后护理",
		[PlayerType.PLAYER_KEEPER] = "市场经济学",
		[PlayerType.PLAYER_APOLLYON] = "论放弃",
		[PlayerType.PLAYER_THEFORGOTTEN] = "尸检报告",
		[PlayerType.PLAYER_THESOUL] = "尸检报告",
		[PlayerType.PLAYER_BETHANY] = "灵魂招徕",
		[PlayerType.PLAYER_JACOB] = "被撕毁的契约I",
		[PlayerType.PLAYER_ESAU] = "被撕毁的契约II",
		
		[PlayerType.PLAYER_ISAAC_B] = "潜规则书",
		[PlayerType.PLAYER_MAGDALENE_B] = "取媚的艺术",
		[PlayerType.PLAYER_CAIN_B] = "成功学",
		[PlayerType.PLAYER_JUDAS_B] = "彼列魔咒",
		[PlayerType.PLAYER_BLUEBABY_B] = "食品安全与加工",
		[PlayerType.PLAYER_EVE_B] = "魔物养殖教程",
		[PlayerType.PLAYER_SAMSON_B] = "心理健康",
		[PlayerType.PLAYER_AZAZEL_B] = "祭奠学",
		[PlayerType.PLAYER_LAZARUS_B] = "现世与冥界的逆转",
		[PlayerType.PLAYER_EDEN_B] = "量子力学初步",
		[PlayerType.PLAYER_THELOST_B] = "神启十诫",
		[PlayerType.PLAYER_LILITH_B] = "手术报告",
		[PlayerType.PLAYER_KEEPER_B] = "资本论",
		[PlayerType.PLAYER_APOLLYON_B] = "深渊奥秘",
		[PlayerType.PLAYER_THEFORGOTTEN_B] = "肉身生灵术",
		[PlayerType.PLAYER_BETHANY_B] = "幻术学导论",
		[PlayerType.PLAYER_JACOB_B] = "契约残片",
		[PlayerType.PLAYER_LAZARUS2_B] = "绝望与希望的逆转",
		[PlayerType.PLAYER_JACOB2_B] = "契约灰烬",
		[PlayerType.PLAYER_THESOUL_B] = "肉身生灵术",
		[enums.Players.wq] = "世界穿梭指南",
		[enums.Players.Spwq] = "机器学习初步",
		[enums.Players.Tecro] = "杀生实录",
		[enums.Players.Tecrorun] = "调色咒文",
		[enums.Players.Anna] = "绞杀记录",
		[enums.Players.Zeistos] = "目录",
		[enums.Players.Marriano] = "真名录",
		[enums.Players.Autio] = "俘获榜单",
		[enums.Players.Lu] = "计划书",
	},
	Description = function(info,player,ignore_changes)
		if not player then return info.RealDesc end
		local pt = player:GetPlayerType()
		if info.Descinfo[pt] then return info.Descinfo[pt]
		else return info.RealDesc end
	end,RealDesc = "可惜无法辨识",
	Descinfo = {
		[PlayerType.PLAYER_ISAAC] = "要尽可能寻找道具",
		[PlayerType.PLAYER_MAGDALENE] = "去吸尽生命吧",
		[PlayerType.PLAYER_CAIN] = "作弊是你的美德",
		[PlayerType.PLAYER_JUDAS] = "恶魔？呵呵..",
		[PlayerType.PLAYER_BLUEBABY] = "就由你来制造粪便",
		[PlayerType.PLAYER_EVE] = "脆弱和美丽才是你的武器",
		[PlayerType.PLAYER_SAMSON] = "平息你的力量",
		[PlayerType.PLAYER_AZAZEL] = "地狱的大门为我敞开",
		[PlayerType.PLAYER_LAZARUS] = "别让它们复活",
		[PlayerType.PLAYER_EDEN] = "查缺补漏",
		[PlayerType.PLAYER_THELOST] = "去显露神迹",
		[PlayerType.PLAYER_LAZARUS2] = "别让它们死去",
		[PlayerType.PLAYER_BLACKJUDAS] = "恶魔？对..",
		[PlayerType.PLAYER_LILITH] = "母体平安",
		[PlayerType.PLAYER_KEEPER] = "操纵世界的经济",
		[PlayerType.PLAYER_APOLLYON] = "扔掉无用的玩意吧",
		[PlayerType.PLAYER_THEFORGOTTEN] = "骨质严密",
		[PlayerType.PLAYER_THESOUL] = "灵体完整",
		[PlayerType.PLAYER_BETHANY] = "导引驱魔",
		[PlayerType.PLAYER_JACOB] = "杀死你的另一半",
		[PlayerType.PLAYER_ESAU] = "杀死你的另一半",
		
		[PlayerType.PLAYER_ISAAC_B] = "不必留下低级道具",
		[PlayerType.PLAYER_MAGDALENE_B] = "取悦怪物是你的职责",
		[PlayerType.PLAYER_CAIN_B] = "拆解是个好能力",
		[PlayerType.PLAYER_JUDAS_B] = "恶魔？有趣的想法..",
		[PlayerType.PLAYER_BLUEBABY_B] = "就由你来清理粪便",
		[PlayerType.PLAYER_EVE_B] = "这种史莱姆还要更多",
		[PlayerType.PLAYER_SAMSON_B] = "记住杀戮",
		[PlayerType.PLAYER_AZAZEL_B] = "取回你曾经的力量",
		[PlayerType.PLAYER_LAZARUS_B] = "去沟通死者",
		[PlayerType.PLAYER_EDEN_B] = "你安静呆着就好",
		[PlayerType.PLAYER_THELOST_B] = "要愚弄信徒",
		[PlayerType.PLAYER_LILITH_B] = "剖腹产失败，胎儿已变异",
		[PlayerType.PLAYER_KEEPER_B] = "让万物为你赚钱",
		[PlayerType.PLAYER_APOLLYON_B] = "我要更多飞蝗",
		[PlayerType.PLAYER_THEFORGOTTEN_B] = "死亡，并不是结束",
		[PlayerType.PLAYER_BETHANY_B] = "制造幻象",
		[PlayerType.PLAYER_JACOB_B] = "憎恨不公？这就对了",
		[PlayerType.PLAYER_LAZARUS2_B] = "去沟通生者",
		[PlayerType.PLAYER_JACOB2_B] = "..不.？..对.",
		[PlayerType.PLAYER_THESOUL_B] = "死亡，并不是结束",
		[enums.Players.wq] = "为我引导来路",
		[enums.Players.Spwq] = "醒来！",
		[enums.Players.Tecro] = "目标名单已送达",
		[enums.Players.Tecrorun] = "传达我的意志",
		[enums.Players.Anna] = "毁灭！",
		[enums.Players.Zeistos] = "无须如此",
		[enums.Players.Marriano] = "你究竟是谁",
		[enums.Players.Autio] = "阴影落下",
		[enums.Players.Lu] = "计略已定",
	},},
	[Items.Calamity] = {Name = "天象灾变",Description = "II",Rnd_Special = {Name = "妖痕 · 灾天",Description = "天灾过后，遍地残垣",weigh = 5,},},
	[Items.Disequilibrium] = {Name = "天象失权",Description = "IV",Rnd_Special = {Name = "妖痕 · 权天",Description = "失衡 · 不削 · 必亡",weigh = 5,},},
	[Items.Destruction] = {Name = "天象解构",Description = "VI",Rnd_Special = {Name = "妖痕 · 解天",Description = "世界就在我们脚下",weigh = 5,},},
	[Items.Cheater_s_Blessing] = {Name = "作弊者的祝福",Description = "你打得也太好了！",Rnd_Special = {Name = "妖邪 · 回梦",Description = "物皆有悟",weigh = 10,},},
	[Items.World_Arc] = {Name = "世界弧",Description = "天下如一",Rnd_Special = {Name = "天下弧",Description = "世界如此之小",weigh = 3,},},
	[Items.Illumination] = {Name = "天象破幻",Description = "I",Rnd_Special = {Name = "妖痕 · 幻天",Description = "生身再诞",weigh = 5,},},
	[Items.Contemplation] = {Name = "天象窥井",Description = "III",Rnd_Special = {Name = "妖痕 · 窥天",Description = "一寸即天地",weigh = 5,},},
	[Items.Chasm] = {Name = "天象入渊",Description = "V",Rnd_Special = {Name = "妖痕 · 渊天",Description = "沉沦于此",weigh = 5,},},
	[Items.Pathetique] = {Name = "悲怆",Description = "它们被迫为我而死",Rnd_Special = {Name = "惨淡之种",Description = "不老不死..",},},
	[CollectibleType.COLLECTIBLE_BIRTHRIGHT] = {Name = "长子名分",Description = function(info,player)
		local pt = player:GetPlayerType()
		if info.Nameinfo[pt] then return info.Nameinfo[pt]
		else
			local name = auxi.get_birth_right_name(player) 
			if name then 
				local ret = auxi.check_name_data("#"..name.."_BIRTHRIGHT","")
				if ret ~= "" then return ret end
			end 
			return auxi.random_in_table(info.Rndinfo)
		end
	end,
	Expeled = true,
	Rndinfo = {
		"恐惧我！",
		"正视我！",
		"热爱我！",
		"深爱我！",
		"追随我！",
		"追求我！",
		"模仿我！",
		"惩戒我！",
		"责罚我！",
		"我就是我！",
	},
	Nameinfo = {
		[enums.Players.wq] = "血债应由血偿!",
		[enums.Players.Spwq] = "额外组件已就位",
		[enums.Players.Tecro] = "刺痛塑我身",
		[enums.Players.Tecrorun] = "轻如光明",
		[enums.Players.Anna] = "血光之灾",
		[enums.Players.annA] = "神明攻势",
		[enums.Players.Zeistos] = "所见即所得",
		[enums.Players.Marriano] = "人格重组",
		[enums.Players.Autio] = "究天之使",
		[enums.Players.Lu] = "见令如见我",
	},},
}

item.en.Players = {}
item.en.Trinkets = {}
item.en.Cards = {}
item.en.Collectibles = {
	[Items.It_s_a_trick] = {Name = function(info,player,ignore_changes)
		if save.elses.glazed_trick == nil then save.elses.glazed_trick = 32 end
		local name = ""
		if item.zh.Collectibles[save.elses.glazed_trick] then 
			if save.elses.glazed_trick ~= Items.It_s_a_trick then
				name = item.en.Collectibles[save.elses.glazed_trick].Name
				if type(name) == "function" then name = name(info,player,ignore_changes) end
			else name = "Glazed Core" end		--这是几乎不可能做到的！
		else
			local configitem = Isaac:GetItemConfig():GetCollectible(save.elses.glazed_trick)
			name = auxi.check_name_data(configitem.Name)
		end
		return name.."?"
	end,Description = function(info,player)
		return "You Are Fooled Again!!"
	end,},
	[Items.D773] = {Name = function(v) if save.elses.D773 == nil then save.elses.D773 = 0 end;return "D"..tostring(773 + save.elses.D773) end,Description = function(v) return v.des[math.random(#(v.des))] end,
	des = {"It's like an oreo.","Higher altitude,Higher level brain.","It's the ultimate mystery.","Life's a crime.","A clown nose is the height of fashion.","Never take anything seriously,unless it's a joke.","I'm a clown GUY!","A fish walks into a bar.","A monkey grabs the banana and runs away.","Help me out of this cage!","I'm a twisted individual.","Fishtastic!","The Dentist Killer of wobbly Road","Cake is dry,not moist.And deceitful.","The end result of an evoluved family line of clowns.",}},
	[CollectibleType.COLLECTIBLE_BIRTHRIGHT] = {Name = "Birthright",Description = function(info,player)
		local pt = player:GetPlayerType()
		if info.Nameinfo[pt] then return info.Nameinfo[pt]
		else
			local name = auxi.get_birth_right_name(player) 
			if name then 
				local ret = auxi.check_name_data("#"..name.."_BIRTHRIGHT")
				if ret then return ret end
			end 
			return "?" 
		end
	end,
	Nameinfo = {
		[enums.Players.wq] = "Pain has to Pay!",
		[enums.Players.Spwq] = "Memories...",
		[enums.Players.Tecro] = "I Sting!",
		[enums.Players.Tecrorun] = "She is back now",
		[enums.Players.Anna] = "Bloody disaster",
	},},
}

local function attach_static_fallbacks()
	local static_zh = static_translations.zh_cn or static_translations.zh or {}
	local static_en = static_translations.en_us or static_translations.en or {}
	setmetatable(item.zh.Collectibles, {__index = static_zh.Collectibles or {}})
	setmetatable(item.zh.Trinkets, {__index = static_zh.Trinkets or {}})
	setmetatable(item.zh.Cards, {__index = static_zh.Cards or {}})
	setmetatable(item.zh.Players, {__index = static_zh.Players or {}})
	item.zh.Room = static_zh.Room or {}
	item.zh.Level = static_zh.Level or {}
	setmetatable(item.en.Collectibles, {__index = static_en.Collectibles or {}})
	setmetatable(item.en.Trinkets, {__index = static_en.Trinkets or {}})
	setmetatable(item.en.Cards, {__index = static_en.Cards or {}})
	setmetatable(item.en.Players, {__index = static_en.Players or {}})
	item.en.Room = static_en.Room or {}
	item.en.Level = static_en.Level or {}
end

attach_static_fallbacks()

function item.set_basic_data()
	if REPENTOGON and Options.Language == "zh" then
		local static_zh = static_translations.zh_cn or static_translations.zh or {}
		local config = Isaac.GetItemConfig()
		for u,v in pairs(static_zh.Collectibles or {}) do
			local conf = config:GetCollectible(u)
			if conf and not v.Expeled then
				if v.Name then conf.Name = auxi.check_if_any(v.Name,v,nil,true) end
				if v.Desc then conf.Description = auxi.check_if_any(v.Desc,v,nil,true) end
			end
		end
		for u,v in pairs(static_zh.Trinkets or {}) do
			local conf = config:GetTrinket(u)
			if conf then
				if v.Name then conf.Name = auxi.check_if_any(v.Name,v,nil,true) end
				if v.Desc then conf.Description = auxi.check_if_any(v.Desc,v,nil,true) end
			end
		end
		for u,v in pairs(static_zh.Cards or {}) do
			local conf = config:GetCard(u)
			if conf then
				if v.Name then conf.Name = auxi.check_if_any(v.Name,v,nil,true) end
				if v.Desc then conf.Description = auxi.check_if_any(v.Desc,v,nil,true) end
			end
		end
	end
end

item.set_basic_data()

table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	local target = nil
	local ignore_changes = nil
	local language = Options.Language
	local base = item[language]
	if base == nil then return nil end
	if tp == "Trinket" then
		target = base.Trinkets
	elseif tp == "Item" then
		target = base.Collectibles
	elseif tp == "Card" then
		target = base.Cards
	elseif tp == "UnItem" then
		target = base.Collectibles
		ignore_changes = true
	elseif tp == "Room" then
		target = base.Room
	elseif tp == "Level" then
		target = base.Level
	elseif tp == "Player" then
		target = base.Players
	end
	if target == nil then return nil end
	local static_base = static_translations[language] or static_translations.zh_cn
	local static_target = nil
	if tp == "Trinket" then
		static_target = static_base and static_base.Trinkets
	elseif tp == "Item" or tp == "UnItem" then
		static_target = static_base and static_base.Collectibles
	elseif tp == "Card" then
		static_target = static_base and static_base.Cards
	elseif tp == "Player" then
		static_target = static_base and static_base.Players
	elseif tp == "Room" then
		static_target = static_base and static_base.Room
	elseif tp == "Level" then
		static_target = static_base and static_base.Level
	end
	local dynamic_info = rawget(target, id)
	local info = static_target and static_target[id] or target[id]
	if dynamic_info then
		if type(dynamic_info.Name) == "function" or type(dynamic_info.Description) == "function" then
			info = dynamic_info
		end
	end
	local rnd_special = nil
	if not (dynamic_info and (type(dynamic_info.Name) == "function" or type(dynamic_info.Description) == "function")) then
		rnd_special = (dynamic_info and dynamic_info.Rnd_Special) or (info and info.Rnd_Special)
	end
	if rnd_special then
		local rnd_mx = rnd_special.weigh or 5
		if math.random(rnd_mx) == 1 then info = rnd_special end
	end
	if info then
		local name = info.Name
		local des = info.Desc or info.Description
		if type(name) == "function" then name = name(info,player,ignore_changes) end
		if type(des) == "function" then des = des(info,player,ignore_changes) end
		return {Name = name,Description = des,}
	end
	if tp == "Room" then
		for u,v in pairs(target) do value.Name = string.gsub(value.Name,u,v) end
		for u,v in pairs(target) do value.Description = string.gsub(value.Description,u,v) end
		return value
	end
	return nil
end,
})

function item.get_chinese_console_names()
	local tbl = {}
	local static_zh = static_translations.zh_cn or static_translations.zh or {}
	for uu,vv in pairs({["Collectibles"] = "c",["Cards"] = "k",["Trinkets"] = "t",}) do
		for u,v in pairs(static_zh[uu] or {}) do
			local name = v.Name
			if type(name) == "string" then table.insert(tbl,{vv..u,name}) end
		end
		for u,v in pairs(item.zh[uu] or {}) do
			local name = v.Name if type(name) == "function" then name = v.RealName end
			if type(name) == "string" then table.insert(tbl,{vv..u,name}) end
		end
	end
	return tbl
end

function item.register_chinese_console(force)
	if item.chinese_console_registered and not force then return true end
	if _SZX_CHINESE_CONSOLE_ == nil or type(_SZX_CHINESE_CONSOLE_.setModItemChineseName) ~= "function" then return false end
	local succ,err = pcall(_SZX_CHINESE_CONSOLE_.setModItemChineseName,item.get_chinese_console_names())
	if succ then
		item.chinese_console_registered = true
		return true
	end
	print("[Qing] failed to register Chinese console names: "..tostring(err))
	return false
end

item.register_chinese_console()

return item

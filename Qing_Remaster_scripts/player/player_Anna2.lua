local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Wavering_Eyes = require("Qing_Remaster_scripts.items.Item_Wavering_Eyes")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local Damage_holder = require("Qing_Remaster_scripts.mimics.Damage_holder")
local grid_entity = require("Qing_Remaster_scripts.grids.grid_entity")
local Epic_holder = require("Qing_Remaster_scripts.mimics.Epic_holder")
local Tech_5_holder = require("Qing_Remaster_scripts.mimics.Tech_5_holder")
local Shader_holder = require("Qing_Remaster_scripts.others.Shader_holder")
local Seeker_s_Eye = require("Qing_Remaster_scripts.items.Item_Seeker_s_Eye")
local Item_Assassin_s_Eye = require("Qing_Remaster_scripts.items.Item_Assassin_s_Eye")
local Flat_Stone_holder = require("Qing_Remaster_scripts.mimics.Flat_Stone_holder")
local Isaacs_Tear_holder = require("Qing_Remaster_scripts.mimics.Isaacs_Tear_holder")
local Jacob_ladder_holder = require("Qing_Remaster_scripts.mimics.Jacob_ladder_holder")
local tear_trigger_holder = require("Qing_Remaster_scripts.callbacks.tear_trigger_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Players.annA,
	own_key = "Player_annA_",
	Special_Des = {
		["zh"] = {
			["Item"] = {
				[CollectibleType.COLLECTIBLE_EPIC_FETUS] = {Name = "天风",Description = "我从天空落下",},
				[CollectibleType.COLLECTIBLE_DR_FETUS] = {Name = "天雷",Description = "轰炸机来袭",},
				[CollectibleType.COLLECTIBLE_BRIMSTONE] = {Name = "天火",Description = "坠落的火种",},
				[CollectibleType.COLLECTIBLE_MOMS_KNIFE] = {Name = "天伤",Description = "扎扎扎！",},
				[CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = {Name = "天剑",Description = "第九分形",},
				[CollectibleType.COLLECTIBLE_DEATHS_TOUCH] = {Name = "天镰",Description = "斩尽汝敌",},
				[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {Name = nil,Description = "激光已配置",},
				[CollectibleType.COLLECTIBLE_TECH_X] = {Name = nil,Description = "激光环已配置",},
				[CollectibleType.COLLECTIBLE_C_SECTION] = {Name = "天蝶",Description = "飞蛾幼体已配置",},
				[CollectibleType.COLLECTIBLE_HAEMOLACRIA] = {Name = nil,Description = "鲜血已配置",},
				[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {Name = "远程灾难传送器",Description = "灾祸追随着我",},
				[enums.Items.Book_of_6_sin] = {Name = "论贪婪",Description = "所欲无所不在",},
				[enums.Items.Calamity] = {Name = "灾天 · 天灾",Description = "灾难降诞",},
				[enums.Items.Shangrila] = {Name = "灾诞之日",Description = "神兵天降",},
				[enums.Items.Core_Brooch] = {Name = "我的胸针",Description = "神择灾诞",},
				
				[CollectibleType.COLLECTIBLE_BLOOD_OATH] = {Name = "天之誓言",Description = "为我落下",},
				[CollectibleType.COLLECTIBLE_SOY_MILK] = {Name = "灾害增生",Description = "祸不单行",},
				[CollectibleType.COLLECTIBLE_ALMOND_MILK] = {Name = "灾害腐生",Description = "福无双至",},
			},
		},
		["en"] = {
			["Item"] = {
			},
		},
	},
	attack_info = {
		[0] = {
			{frame = 0,offset = Vector(0,0),scale = Vector(1,1),A = 1,},
			{frame = 2,offset = Vector(0,5),scale = Vector(1.2,0.8),A = 1,},
			{frame = 10,offset = Vector(0,-35),scale = Vector(0.9,1.1),A = 1,},
			{frame = 15,offset = Vector(0,-42),scale = Vector(1,1),A = 1,},
			{frame = 20,offset = Vector(0,-45),scale = Vector(1.1,1.1),A = 1,},
			{frame = 25,offset = Vector(0,-47),scale = Vector(1.2,1.2),A = 1,},
			{frame = 30,offset = Vector(0,-50),scale = Vector(0,0),A = 0,},
			total = 30,
			port = 10,
			rport = 20,
			scythe = 18,
			init = true,
		},
		[0.1] = {				--反重力专用模板
			{frame = 0,offset = Vector(0,0),scale = Vector(1,1),A = 1,},
			{frame = 2,offset = Vector(0,10),scale = Vector(1.2,0.8),A = 1,},
			{frame = 10,offset = Vector(0,-55),scale = Vector(0.9,1.1),A = 1,},
			{frame = 15,offset = Vector(0,-72),scale = Vector(1,1),A = 1,},
			{frame = 20,offset = Vector(0,-75),scale = Vector(1.1,1.1),A = 1,},
			{frame = 24,offset = Vector(0,-77),scale = Vector(1.2,1.2),A = 1,},
			{frame = 28,offset = Vector(0,-60),scale = Vector(1.2,0),A = 0,},
			total = 28,
			waitable = 24,
			init = true,
		},
		[1] = {
			{frame = 0,offset = Vector(0,-60),scale = Vector(0,0),A = 0,RO = -1,GO = -1,BO = -1,},
			{frame = 2,offset = Vector(0,-30),scale = Vector(0.2,-2.4),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 4,offset = Vector(0,-10),scale = Vector(0.8,-1.2),A = 1,RO = -1,GO = -1,BO = -1,},
			{frame = 6,offset = Vector(2,0),scale = Vector(1.2,-0.8),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 8,offset = Vector(-2,5),scale = Vector(1.4,-1),A = 1,RO = -1,GO = -1,BO = -1,},
			{frame = 10,offset = Vector(2,0),scale = Vector(1.2,-0.6),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 12,offset = Vector(-2,-5),scale = Vector(1.2,0.6),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 14,offset = Vector(0,-10),scale = Vector(0.8,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 16,offset = Vector(0,0),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			total = 16,
			launch = 6,
			specialcast = 2,
		},
		[2] = {
			{frame = 0,offset = Vector(0,-40),scale = Vector(0.6,-1.4),A = 0,RO = -1,GO = -1,BO = -1,},
			{frame = 2,offset = Vector(0,-10),scale = Vector(0.8,-1.2),A = 0.5,RO = -1,GO = -1,BO = -1,},
			{frame = 4,offset = Vector(0,0),scale = Vector(1.2,-0.8),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 6,offset = Vector(0,10),scale = Vector(0.8,-1.2),A = 0.5,RO = -1,GO = -1,BO = -1,},
			{frame = 8,offset = Vector(0,30),scale = Vector(0.6,-1.4),A = 0,RO = -1,GO = -1,BO = -1,},
			total = 8,
			launch = 4,
			cast = 4,
		},
		[3] = {
			{frame = 0,offset = Vector(0,-300),scale = Vector(0,0),A = 0,RO = 1,GO = 1,BO = 1,},
			{frame = 30,offset = Vector(0,-300),scale = Vector(1,-1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 40,offset = Vector(0,0),scale = Vector(1,-1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 42,offset = Vector(0,-10),scale = Vector(1.2,-0.8),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 44,offset = Vector(0,10),scale = Vector(0.8,-1.2),A = 0,RO = -1,GO = -1,BO = -1,},
			{frame = 46,offset = Vector(-2,5),scale = Vector(1.4,-1),A = 1,RO = -1,GO = -1,BO = -1,},
			{frame = 48,offset = Vector(2,0),scale = Vector(1.2,-0.6),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 50,offset = Vector(-2,-5),scale = Vector(1.2,0.6),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 52,offset = Vector(0,-10),scale = Vector(0.8,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 54,offset = Vector(0,0),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			shake = {[40] = true,},
			shake2 = {[32] = true,[34] = true,[36] = true,[38] = true,},
			specialcast = 30,
			total = 54,
			fall = 32,
			launch = 40,
		},
		[4] = {
			{frame = 0,offset = Vector(-5,-80),scale = Vector(0,0.6),A = 0,RO = 0,GO = 0,BO = 0,},
			{frame = 2,offset = Vector(0,-80),scale = Vector(0.8,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 4,offset = Vector(5,-80),scale = Vector(0,0.6),A = 1,RO = 0,GO = 0,BO = 0,},
			total = 4,
			cast = 2,
		},
		[5] = {
			{frame = 0,offset = Vector(0,-80),scale = Vector(0,0),A = 0,RO = 0,GO = 0,BO = 0,},
			{frame = 2,offset = Vector(0,-86),scale = Vector(0.8,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 4,offset = Vector(0,-88),scale = Vector(1.2,0.8),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 6,offset = Vector(0,-90),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 8,offset = Vector(0,-95),scale = Vector(1,-1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 16,offset = Vector(0,0),scale = Vector(0.8,-1.4),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 18,offset = Vector(0,-10),scale = Vector(1.2,-0.8),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 20,offset = Vector(0,10),scale = Vector(0.8,-1.2),A = 0,RO = -1,GO = -1,BO = -1,},
			{frame = 22,offset = Vector(-2,5),scale = Vector(1.4,-1),A = 1,RO = -1,GO = -1,BO = -1,},
			{frame = 24,offset = Vector(2,0),scale = Vector(1.2,-0.6),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 26,offset = Vector(-2,-5),scale = Vector(1.2,0.6),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 28,offset = Vector(0,-10),scale = Vector(0.8,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 30,offset = Vector(0,0),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			total = 30,
			specialcast = 6,
			fall = 8,
			launch = 18,
		},
		[6] = {
			{frame = 0,offset = Vector(0,-80),scale = Vector(0,0),A = 0,RO = 0,GO = 0,BO = 0,},
			{frame = 2,offset = Vector(0,-86),scale = Vector(0.8,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 4,offset = Vector(0,-88),scale = Vector(1.2,0.8),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 6,offset = Vector(0,-90),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 8,offset = Vector(0,-120),scale = Vector(0,2.4),A = 1,RO = 0,GO = 0,BO = 0,},
			total = 8,
			cast = 6,
		},
		[7] = {
			{frame = 0,offset = Vector(0,-120),scale = Vector(0,0),A = 0,RO = 0,GO = 0,BO = 0,},
			{frame = 2,offset = Vector(0,-110),scale = Vector(1,-1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 4,offset = Vector(0,-90),scale = Vector(1,-1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 12,offset = Vector(0,0),scale = Vector(1,-1.8),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 14,offset = Vector(0,-10),scale = Vector(1.2,-0.8),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 16,offset = Vector(0,10),scale = Vector(0.8,-1.2),A = 0,RO = -1,GO = -1,BO = -1,},
			{frame = 18,offset = Vector(-2,5),scale = Vector(1.4,-1),A = 1,RO = -1,GO = -1,BO = -1,},
			{frame = 20,offset = Vector(2,0),scale = Vector(1.2,-0.6),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 22,offset = Vector(-2,-5),scale = Vector(1.2,0.6),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 24,offset = Vector(0,-10),scale = Vector(0.8,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 26,offset = Vector(0,-15),scale = Vector(1,1.4),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 32,offset = Vector(0,-20),scale = Vector(1.2,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 40,offset = Vector(0,0),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			shake = {[14] = true,},
			specialcast = 2,
			total = 40,
			launch = 14,
		},
		[8] = {
			{frame = 0,offset = Vector(0,-80),scale = Vector(0,0),A = 0,RO = 0,GO = 0,BO = 0,},
			{frame = 2,offset = Vector(0,-86),scale = Vector(0.8,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 4,offset = Vector(0,-88),scale = Vector(1.2,0.8),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 6,offset = Vector(0,-90),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 8,offset = Vector(0,-110),scale = Vector(0.6,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 10,offset = Vector(0,-150),scale = Vector(0,2.4),A = 1,RO = 0,GO = 0,BO = 0,},
			total = 10,
			cast = 6,
			steps = 1,
		},
		[8.1] = {
			{frame = 0,offset = Vector(0,-90),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 2,offset = Vector(0,-90),scale = Vector(1,-1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 4,offset = Vector(0,-80),scale = Vector(1,-1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 14,offset = Vector(0,0),scale = Vector(0.8,-1.8),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 16,offset = Vector(0,-10),scale = Vector(1.2,-0.8),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 18,offset = Vector(0,10),scale = Vector(0.8,-1.2),A = 0,RO = -1,GO = -1,BO = -1,},
			{frame = 20,offset = Vector(-2,5),scale = Vector(1.4,-1),A = 1,RO = -1,GO = -1,BO = -1,},
			{frame = 22,offset = Vector(2,0),scale = Vector(1.2,-0.6),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 24,offset = Vector(-2,-5),scale = Vector(1.2,0.6),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 26,offset = Vector(0,-10),scale = Vector(0.8,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 28,offset = Vector(0,0),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			cast = 2,
			no2separate = true,
			launch = 16,
			total = 28,
		},
		[9] = {
			{frame = 0,offset = Vector(0,-70),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 2,offset = Vector(0,-65),scale = Vector(1.4,0.6),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 8,offset = Vector(0,-120),scale = Vector(0.8,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 10,offset = Vector(0,-120),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 12,offset = Vector(0,-110),scale = Vector(1,-1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 14,offset = Vector(0,-90),scale = Vector(1,-1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 22,offset = Vector(0,0),scale = Vector(1,-1.8),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 24,offset = Vector(0,-10),scale = Vector(1.2,-0.8),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 26,offset = Vector(0,10),scale = Vector(0.8,-1.2),A = 0,RO = -1,GO = -1,BO = -1,},
			{frame = 28,offset = Vector(-2,5),scale = Vector(1.4,-1),A = 1,RO = -1,GO = -1,BO = -1,},
			{frame = 30,offset = Vector(2,0),scale = Vector(1.2,-0.6),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 32,offset = Vector(-2,-5),scale = Vector(1.2,0.6),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 34,offset = Vector(0,-10),scale = Vector(0.8,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 36,offset = Vector(0,-15),scale = Vector(1,1.4),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 42,offset = Vector(0,-20),scale = Vector(1.2,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 50,offset = Vector(0,0),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			shake = {[24] = true,},
			specialcast = 12,
			total = 50,
			launch = 24,
		},
		[9.1] = {
			{frame = 0,offset = Vector(0,-60),scale = Vector(0,0),A = 0,RO = 0,GO = 0,BO = 0,},
			{frame = 5,offset = Vector(0,-65),scale = Vector(1.2,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 8,offset = Vector(0,-70),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 12,offset = Vector(0,-70),scale = Vector(0.8,1.4),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 14,offset = Vector(0,-68),scale = Vector(1.2,0.8),A = 1,RO = 1,GO = 1,BO = 1,},
			{frame = 16,offset = Vector(0,-65),scale = Vector(1.1,1.1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 18,offset = Vector(0,-70),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			set = 14,
			total = 18,
		},
		[9.2] = {
			{frame = 0,offset = Vector(0,-70),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 2,offset = Vector(0,-70),scale = Vector(1.2,1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 4,offset = Vector(0,-70),scale = Vector(1,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 6,offset = Vector(0,-70),scale = Vector(1.2,1),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 8,offset = Vector(0,-70),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			cast = 6,
			total = 8,
		},
		[10] = {
			{frame = 0,offset = Vector(0,-90),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			total = 0,
			Step_forward = true,
		},
		[10.1] = {
			{frame = 0,offset = Vector(0,-60),scale = Vector(1,1),A = 0,RO = 0,GO = 0,BO = 0,},
			{frame = 2,offset = Vector(0,-60),scale = Vector(1.2,1.2),A = 1,RO = 0,GO = 0,BO = 0,},
			{frame = 4,offset = Vector(0,-60),scale = Vector(1,1),A = 0,RO = 0,GO = 0,BO = 0,},
			separate = 2,
			total = 4,
			separate_finfo = function(player,ent)
				local mul = 3
				local ret = {finfo = {},einfo = {[1] = {mul = mul,},},steps = mul + 2,step = 1,}
				table.insert(ret.finfo,{id = 9.1,iid = 1,})
				for i = 1,mul do table.insert(ret.finfo,{id = 9.2,iid = 1,wait = 3,}) end
				table.insert(ret.finfo,{id = 9,iid = 1,})
				return ret
			end,
		},
		[10.2] = {
			{frame = 0,offset = Vector(0,-90),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
			total = 0,
			Step_forward = true,
		},
		[11] = {
			{frame = 0,offset = Vector(0,-90),scale = Vector(1,1),A = 0,RO = 0,GO = 0,BO = 0,},
			{frame = 60,offset = Vector(0,-90),scale = Vector(1,1),A = 0,RO = 0,GO = 0,BO = 0,},
			total = 60,
			cast = 2,
		},
		[12] = {
			{frame = 0,offset = Vector(0,-90),scale = Vector(1,1),A = 0,RO = 0,GO = 0,BO = 0,},
			{frame = 20,offset = Vector(0,-90),scale = Vector(1,1),A = 0,RO = 0,GO = 0,BO = 0,},
			total = 20,
			cast = 2,
		},
	},
	bomb_transfer_info = {
		[1] = {
			{frame = 0,vel = 0,},
			{frame = 8,vel = 1,},
			{frame = 16,vel = 1.5,},
			{frame = 32,vel = 2,},
		},
		[2] = {
			{frame = 0,vel = 2,},
			{frame = 2,vel = 10,},
			{frame = 8,vel = 20,},
			{frame = 16,vel = 30,},
		},
	},
	bomb_appear_info = {
		{frame = 0,val = -100,scale = Vector(1,1),A = 0,},
		{frame = 2,val = -100,scale = Vector(1,1),A = 0,},
		{frame = 6,val = 0,scale = Vector(1.2,0.8),A = 1,},
		{frame = 7,val = 0,scale = Vector(0.9,1.1),A = 1,},
		{frame = 8,val = 0,scale = Vector(1,1),A = 1,},
		total = 8,
	},
	planet_info = {
		{frame = 0,val = 0,},
		{frame = 0.5,val = 0.2,},
		{frame = 0.6,val = 0.8,},
		{frame = 1,val = 1,},
	},
	mirror_info = {
		{frame = 0,val = 1,},
		{frame = 10,val = 1,},
		{frame = 60,val = -1,},
	},
	shift_id = {
		[2] = 1,
		[4] = 3,
		[6] = 5,
		[8] = 7,
		[10] = 9,
		[10.1] = 9.1,
		[10.2] = 9.2,
		[12] = 11,
	},
	separate_finfo = {
		[1] = {
			[0] = {id = 8.1,},
		},
	},
	Scythe_info = {
		{frame = 0,val = -90,},
		{frame = 1,val = 0,},
		{frame = 1.2,val = 20,},
	},
	knife_speed_rate = {
		{frame = 0,val = 1,},
		{frame = 5,val = 1.5,},
		{frame = 10,val = 2,},
		{frame = 20,val = 2.5,},
	},
	fade_info = {
		{frame = 0,offset = Vector(0,0),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4,offset = Vector(0,-50),scale = Vector(0,5),A = 0,RO = -1,GO = -1,BO = -1,},
		total = 4,
	},
	ignore_type = {
		[1] = true,
		[3] = true,
	},
	birth_info = {
		total = 30,
	},
	coal_info = {
		{frame = 0,val = 0,scale = Vector(1,1),},
		{frame = 80,val = 0.2,scale = Vector(1.1,1.1),},
		{frame = 160,val = 0.4,scale = Vector(1.2,1.2),},
		{frame = 250,val = 0.6,scale = Vector(1.3,1.3),},
		{frame = 500,val = 1,scale = Vector(1.4,1.4),},
		{frame = 1000,val = 2,scale = Vector(1.7,1.7),},
	},
	prop_info = {
		{frame = 0,val = 2,scale = Vector(1.7,1.7),},
		{frame = 80,val = 1,scale = Vector(1.4,1.4),},
		{frame = 160,val = 0.5,scale = Vector(1.2,1.2),},
		{frame = 200,val = 0,scale = Vector(1,1),},
		{frame = 300,val = -0.5,scale = Vector(0.7,0.7),},
		{frame = 500,val = -0.8,scale = Vector(0.1,0.1),},
	},
	choco_info = {
		{frame = 0,scale = Vector(1,1),},
		{frame = 1,scale = Vector(1,1),},
		{frame = 2,scale = Vector(1.4,1.4),},
	},
	cascade_info = {
		{frame = 0,val = 0,},
		{frame = 2,val = 50,},
		{frame = 5,val = 200,},
		{frame = 10,val = 400,},
		{frame = 15,val = 1000,},
		{frame = 20,val = 2000,},
		{frame = 30,val = 3000,},
		coll = 2,
	},
	Rlaser_info = {
		{frame = 0,val = 0,A = 0,},
		{frame = 10,val = 1,A = 0.5,},
		{frame = 20,val = 1.5,A = 1,},
		{frame = 30,val = 1,A = 0,},
		tot = 35,
	},
	Sword_info = {
		{frame = 0,A = 0,val = 0,},
		{frame = 2,A = 1,val = 0.3,},
		{frame = 4,A = 1,val = 1,},
		{frame = 8,A = 0,val = 1.2,},
		cut = 2, -- 命中判定
		torsion = 5, -- 落地后再打横扫 Torsion（frame 4 已到 edpos）
		total = 8,
	},
	mxdelay2cnt = 20,
	wait_mul = 2,
}

function item.wait_time(player)
	return 3 * 10 * (player.MaxFireDelay + 1)
end

function item.get_anna()
	for playerNum = 1,Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player:GetPlayerType() == item.entity then return player end
	end
end

--l local player_Anna2 = require("Qing_Remaster_scripts.player.player_Anna2") local q = player_Anna2.fire_anna_phantom(Game():GetPlayer(0),Vector(200,200),Vector(0,0),{}) q.Rotation = 60

function item.fire_anna_phantom(player,pos,vel,params)
	params = params or {}
	local q = Isaac.Spawn(1000,enums.Entities.Phantom,0,pos,vel,player):ToEffect()
	local s = q:GetSprite()
	local d = q:GetData()
	auxi.copy_sprite(player:GetSprite(),s)
	d[item.own_key.."Base"] = {color = params.color,}
	d[item.own_key.."Anna"] = {}
	s.Color = params.color or Color(1,1,1,0.5,-1,-1,-1)
	--q:AddEntityFlags(EntityFlag.FLAG_INTERPOLATION_UPDATE)
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local s = ent:GetSprite()
		if d[item.own_key.."effect"].Replay then d[item.own_key.."effect"].Replay = nil s:Play(d[item.own_key.."effect"].name or s:GetAnimation(),true) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		ent.Velocity = Vector(0,0)
		local player = d[item.own_key.."effect"].player
		if (d[item.own_key.."effect"].wait or 0) > 0 then d[item.own_key.."effect"].wait = d[item.own_key.."effect"].wait - 1 end	
		if d[item.own_key.."effect"].cascade then
			d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
			local cascade_leg = auxi.check_lerp(d[item.own_key.."effect"].counter,item.cascade_info).val
			ent.MaxDistance = cascade_leg
			--local dir = d[item.own_key.."effect"].cascade.dir
			--ent.Angle = auxi.checkrounded(dir,-90,cascade_dir / 90,1 - cascade_dir / 90,360) + 90
			--math.asin(math.sin(cascade_dir) * (math.cos(dir) + math.sin(dir))/math.sqrt(2)) * 180/3.1415 - 90
			--math.atan(math.tan(cascade_dir) * math.cos(dir)) * 180/3.1415 - 90 + auxi.checkrounded((math.atan(math.tan(dir) * math.cos(45)) * 180/3.1415 + 90)* (cascade_dir/3.1415 * 2),0,1,0,360)
			if d[item.own_key.."effect"].counter == item.cascade_info.coll then 
				ent.Visible = true
				ent.Mass = 1
			end
		end
	end
	if d[item.own_key.."MawLaser"] then
		local r = d[item.own_key.."MawLaser"].Radius or 80
		ent.Radius = (ent.Radius * 0.9) + r * 0.1
	end
	if d[item.own_key.."Reffect"] then
		d[item.own_key.."Reffect"].counter = (d[item.own_key.."Reffect"].counter or 0) + 1
		local info = auxi.check_lerp(d[item.own_key.."Reffect"].counter,item.Rlaser_info)
		--ent.Radius = d[item.own_key.."Reffect"].radius * info.val
		ent:GetSprite().Color = auxi.MulColor(auxi.table2color(info),d[item.own_key.."Reffect"].color)
		if d[item.own_key.."Reffect"].counter > item.Rlaser_info.tot then ent:Remove() end
	end
	if d[item.own_key.."LinkBrimstone"] and d[item.own_key.."LinkBrimstone"].pos then
		if auxi.check_all_exists(d[item.own_key.."LinkBrimstone"].linker) then
			ent.Position = d[item.own_key.."LinkBrimstone"].linker.Position
		else d[item.own_key.."LinkBrimstone"] = nil ent:SetTimeout(1) return end
		if d[item.own_key.."LinkBrimstone"].wait then
			if d[item.own_key.."LinkBrimstone"].wait > 0 then d[item.own_key.."LinkBrimstone"].wait = d[item.own_key.."LinkBrimstone"].wait - 1 else ent.Visible = true d[item.own_key.."LinkBrimstone"].wait = nil end
		end
		local dir = ent.Position - d[item.own_key.."LinkBrimstone"].pos
		ent.Angle = 180 + dir:GetAngleDegrees()
		ent.MaxDistance = dir:Length()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_BOMB_RENDER, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if d[item.own_key.."effect"].NoFall ~= true then
			if d[item.own_key.."effect"].Rocket and d[item.own_key.."effect"].delta == nil then
				d[item.own_key.."effect"].Rocket.posoffset = d[item.own_key.."effect"].Rocket.posoffset or auxi.ProtectVector(ent.PositionOffset)
				ent.PositionOffset = d[item.own_key.."effect"].Rocket.posoffset
			end
		end
		if d[item.own_key.."effect"].Appear then
			local info = auxi.check_lerp(d[item.own_key.."effect"].Appear.counter or 0,item.bomb_appear_info)
			ent.PositionOffset = ent.PositionOffset + Vector(0,info.val)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_BOMB_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if d[item.own_key.."effect"].Reload then 
			local info = d[item.own_key.."effect"].Reload
			local s = ent:GetSprite() 
			s:Load(info.name or "gfx/player/anna/_anna_rocket.anm2",true) 
			if info.Rname then s:ReplaceSpritesheet(0,info.Rname) s:LoadGraphics() end
			s:Play("Idle",true) 
			d[item.own_key.."effect"].Reload = nil 
			ent.Visible = true
		end
		ent.Velocity = Vector(0,0)
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		if d[item.own_key.."effect"].NoFall ~= true then
			if d[item.own_key.."effect"].Rocket then
				if d[item.own_key.."effect"].Rocket and d[item.own_key.."effect"].delta == nil then
					d[item.own_key.."effect"].Rocket.posoffset = d[item.own_key.."effect"].Rocket.posoffset or auxi.ProtectVector(ent.PositionOffset)
					ent.PositionOffset = d[item.own_key.."effect"].Rocket.posoffset
				end
			else
				local vel = 2 * d[item.own_key.."effect"].counter - 1
				ent.PositionOffset = ent.PositionOffset + Vector(0,vel)
			end
			if d[item.own_key.."effect"].delta then 
				d[item.own_key.."effect"].delta_counter = (d[item.own_key.."effect"].delta_counter or 0) + 1
				local info2 = auxi.check_lerp(d[item.own_key.."effect"].delta_counter,item.bomb_transfer_info[2])
				ent.PositionOffset = ent.PositionOffset + Vector(0,info2.vel)
			end
		end
		if d[item.own_key.."effect"].Appear then
			local s = ent:GetSprite()
			d[item.own_key.."effect"].Appear.color = d[item.own_key.."effect"].Appear.color or auxi.table2color(s.Color)
			d[item.own_key.."effect"].Appear.scale = d[item.own_key.."effect"].Appear.scale or auxi.Vector2Table(s.Scale)
			d[item.own_key.."effect"].Appear.counter = (d[item.own_key.."effect"].Appear.counter or 0) + 1
			local info = auxi.check_lerp(d[item.own_key.."effect"].Appear.counter,item.bomb_appear_info)
			s.Color = auxi.MulColor(d[item.own_key.."effect"].Appear.color,Color(1,1,1,info.A,1,1,1))
			s.Scale = auxi.mul_t(auxi.ProtectVector(d[item.own_key.."effect"].Appear.scale),info.scale)
			ent.PositionOffset = ent.PositionOffset + Vector(0,info.val)
			if d[item.own_key.."effect"].Appear.counter > item.bomb_appear_info.total then d[item.own_key.."effect"].Appear = nil end
		end
		ent.PositionOffset = Vector(ent.PositionOffset.X,math.min(1,ent.PositionOffset.Y))
		ent.DepthOffset = 1
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		if ent.PositionOffset.Y > -5 then
			if d[item.own_key.."effect"].Rocket then 
				local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
				Epic_holder.trigger_epic_effect(ent.Position,ent.ExplosionDamage,ent.TearFlags,ent.Color,player,ent,auxi.get_epic_list(player),{dmgself = not d[item.own_key.."safe"],})
				ent:SetExplosionCountdown(0) d[item.own_key.."effect"] = nil
			else
				ent.PositionOffset = Vector(0,0)
				d[item.own_key.."effect"].NoFall = true
				ent:SetExplosionCountdown(999 - ent.FrameCount%8)
				if d[item.own_key.."effect"].Trigger then ent:SetExplosionCountdown(0) d[item.own_key.."effect"] = nil end
			end
		else ent:SetExplosionCountdown(999 - ent.FrameCount%8) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Phantom,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
	local ctrlvel = false
	if d[item.own_key.."Anna"] then ctrlvel = true end
	d[item.own_key.."Base"] = d[item.own_key.."Base"] or {}
	--if d[item.own_key.."Base"].color then auxi.PrintTable(auxi.color2table(d[item.own_key.."Base"].color)) end
	for i = 1,1 do if d[item.own_key.."Fade"] then
		d[item.own_key.."Fade"].counter = (d[item.own_key.."Fade"].counter or 0) + 1
		local info = auxi.check_lerp(d[item.own_key.."Fade"].counter or 0,item.fade_info)
		ent.SpriteScale = info.scale
		ent.PositionOffset = info.offset
		s.Color = auxi.MulColor(Color(1,1,1,info.A,1,1,1),d[item.own_key.."Base"].color or Color(1,1,1,0.5,-1,-1,-1))
		if d[item.own_key.."Fade"].counter > item.fade_info.total then d[item.own_key.."Fade"] = nil ent:Remove() return end
	elseif d[item.own_key.."Attack"] then
		local fminfo = d[item.own_key.."Attack"].forms[d[item.own_key.."Attack"].step or 0] or {}
		local finfo = item.attack_info[fminfo.id or 0]
		local einfo = d[item.own_key.."Attack"].extra_info[fminfo.iid or 1] or {}
		if fminfo.Slowdown then ctrlvel = false ent.Velocity = ent.Velocity * 0.5 end
		if finfo.waitable and finfo.waitable == d[item.own_key.."Attack"].counter and d[item.own_key.."Attack"].wait then
			local gdir = auxi.ggdir(player,true,true,nil,nil,{ignore_canwork = true,real = true,})
			d[item.own_key.."Attack"].waitcounter = (d[item.own_key.."Attack"].waitcounter or 0) + 1
			if d[item.own_key.."Attack"].waitcounter > item.wait_time(player) or player:GetData()[item.own_key.."Attack"] then
			elseif Game():IsPaused() or (not auxi.g_dir_can_work(player)) or gdir:Length() > 0.05 then break end
		end
		if d[item.own_key.."Attack"].Hide then 
			d[item.own_key.."Attack"].Hide = d[item.own_key.."Attack"].Hide - 1 
			if d[item.own_key.."Attack"].Hide < 0 then d[item.own_key.."Attack"].Hide = nil ent.Visible = true
			else ent.Visible = false break end
		end
		if fminfo.wait then fminfo.wait = fminfo.wait - 1 if fminfo.wait <= 0 then fminfo.wait = nil end break end
		d[item.own_key.."Attack"].counter = (d[item.own_key.."Attack"].counter or 0) + 2
		local info = auxi.check_lerp(d[item.own_key.."Attack"].counter or 0,finfo)
		d[item.own_key.."Record"] = d[item.own_key.."Record"] or {}
		d[item.own_key.."Record"].BaseScale = Vector(1,1)
		ent.SpriteScale = auxi.mul_t(info.scale,einfo.scale or Vector(1,1))
		ent.PositionOffset = info.offset
		--s.Scale = info.scale
		s.Color = auxi.MulColor(Color(1,1,1,info.A,1,1,1),d[item.own_key.."Base"].color or Color(1,1,1,0.5,-1,-1,-1))
		item.trigger_finfo(player,ent,finfo,einfo,{counter = d[item.own_key.."Attack"].counter,pos = ent.Position + ent.PositionOffset,})
		if d[item.own_key.."Attack"].counter > finfo.total then
			local nxfminfo = d[item.own_key.."Attack"].forms[(d[item.own_key.."Attack"].step or 0) + 1]
			while(nxfminfo and item.attack_info[nxfminfo.id or 0].Step_forward) do
				d[item.own_key.."Attack"].step = (d[item.own_key.."Attack"].step or 0) + 1
				nxfminfo = d[item.own_key.."Attack"].forms[(d[item.own_key.."Attack"].step or 0) + 1]
			end
			if nxfminfo then
				local nxeinfo = d[item.own_key.."Attack"].extra_info[nxfminfo.iid or -1]
				if nxeinfo and nxeinfo.pos and d[item.own_key.."Attack"].NoPos == nil then
					Game():MakeShockwave(ent.Position + ent.PositionOffset,0.035,0.025,10) 
					ent.Position = nxeinfo.pos
				end
				if d[item.own_key.."Attack"].ForceWise then 
					local pos = (auxi.get_nearest_enemy(nil,ent.Position) or ent).Position
					ent.Position = pos
				end
			end
			d[item.own_key.."Attack"].counter = 0
			d[item.own_key.."Attack"].step = (d[item.own_key.."Attack"].step or 0) + 1
			if auxi.check_all_exists(d[item.own_key.."Attack"].port) then
				d[item.own_key.."Attack"].port:GetData()[item.own_key.."AnnaPort"].Fade = true
				d[item.own_key.."Attack"].port = nil
			end
			local should_end = false
			if d[item.own_key.."Attack"].OneStep then
				if d[item.own_key.."Attack"].OneStep > 0 then d[item.own_key.."Attack"].OneStep = d[item.own_key.."Attack"].OneStep - 1 end
				if d[item.own_key.."Attack"].OneStep <= 0 then should_end = true end
			end
			if should_end or (d[item.own_key.."Attack"].total and d[item.own_key.."Attack"].step >= d[item.own_key.."Attack"].total) then d[item.own_key.."Attack"] = nil d[item.own_key.."Fade"] = {} end
		end
	end end
	if ctrlvel then ent.Velocity = Vector(0,0) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local d = player:GetData()
	if player:GetPlayerType() == item.entity then
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			local cnt = (d[item.own_key.."charge"] or 0)
			local shotinfo = auxi.getshotinfo(player,{Extra = true,})
			cnt = cnt / (shotinfo.mx or 1) * item.mxdelay2cnt / player.MaxFireDelay
			local mx_cnt = player.MaxFireDelay / item.mxdelay2cnt
			local ret = Charging_Bar_holder.render_me(player,{name1 = item.own_key,name2 = item.own_key,name3 = item.own_key,loadname = "gfx/effects/chargebar/chargebar_Anna.anm2",
				check1 = function(val,ent)
					return cnt > 5
				end,
				check2 = function(val,ent) 
					return cnt > 100
				end,
				check3 = function(val,ent)
					return math.ceil(cnt)
				end,
				signal1 = function(ent)
				end,
			})
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ANTI_GRAVITY) then
				Charging_Bar_holder.render_me(player,{name1 = item.own_key.."anti_counter",name2 = item.own_key.."anti_counter",name3 = item.own_key.."anti_counter",loadname = "gfx/effects/chargebar/chargebar_Anna_Anti.anm2",
					check1 = function(val,ent)
						return val > 5
					end,
					check2 = function(val,ent)
						return val >= item.wait_mul * mx_cnt * 100
					end,
					check3 = function(val,ent)
						return math.ceil(val/mx_cnt/item.wait_mul)
					end,
					signal1 = function(ent)
					end,
				})
			end
			if d[item.own_key.."Attack"] and d[item.own_key.."Attack"].birth then
				local cnt = d[item.own_key.."Attack"].birth.counter or 0
				Charging_Bar_holder.render_me(player,{name1 = item.own_key.."birth_counter",name2 = item.own_key.."birth_counter",name3 = item.own_key.."birth_counter",loadname = "gfx/effects/chargebar/chargebar_Anna_Birth.anm2",
					check1 = function(val,ent)
						return cnt > 5
					end,
					check2 = function(val,ent)
						return cnt >= item.birth_info.total
					end,
					check3 = function(val,ent)
						return math.ceil(cnt/item.birth_info.total * 100)
					end,
					signal1 = function(ent)
					end,
				})
			else Charging_Bar_holder.remove_charge_bar(player,item.own_key.."birth_counter") end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	if collid == CollectibleType.COLLECTIBLE_ANTI_GRAVITY and count < 0 then
		Charging_Bar_holder.remove_charge_bar(player,item.own_key.."anti_counter")
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHECK_PLAYER_POSITIONOFFSET, params = nil,
Function = function(_,player,value)
	local d = player:GetData()
	if d[item.own_key.."Attack"] then
		local finfo = item.attack_info[(d[item.own_key.."Attack"].forms[d[item.own_key.."Attack"].step or 0] or {}).id or 0]
		value.Offset = value.Offset + auxi.check_lerp(d[item.own_key.."Attack"].counter or 0,finfo).offset
		value.Remove = false
	end
end,
})

function item.cast_bomb(player,pos,vel,params)
	params = params or {}
	local q = player:FireBomb(pos,vel)
	local d = q:GetData()
	d[item.own_key.."effect"] = {counter = 0,}
	if params.Appear and params.Rocket then d[item.own_key.."effect"].Appear = {counter = 0,} end
	if q.Variant == 19 or params.Rocket == true then 
		local s1 = (q.Variant == 19)
		local s = q:GetSprite()
		d[item.own_key.."effect"].Rocket = {}
		q.Variant = 0 
		if s1 then s.Rotation = 90
		else 
			d[item.own_key.."effect"].Reload = {} 
			q.Visible = false
			if params.main then else d[item.own_key.."effect"].Reload.Rname = "gfx/effects/rockets/Small_missile.png" end
		end
	end
	if q.Variant == 20 and q.SubType == 1 then q.Variant = 17 d[item.own_key.."effect"].Rocket = {} end
	return q
end

function item.check_brim_mode(weap,player,tearflags)
	local ret = 0
	if weap == 2 or auxi.has_have_coll(player,118) then
		if weap == 2 and auxi.has_have_coll(player,118) then ret = 2 else ret = 1 end
	end
	if (tearflags & BitSet128(1<<60,0) == BitSet128(1<<60,0)) then 
		ret = ret | 4
	end
	return ret
end

function item.cast_brim(player,pos,vel,params)
	params = params or {}
	if (params.mode and params.mode == 1) or (not params.tri and not params.both) then params.charge = (params.charge or 1) * 0.5 end
	local tearflags = params.tearflags
	params.tri = params.tri or (tearflags and (tearflags & BitSet128(1<<60,0) == BitSet128(1<<60,0)))
	local q = player:FireBrimstone(vel,nil,params.charge or 1)
	q.CollisionDamage = 0
	q:SetTimeout(99)
	q.Mass = 0
	q.DisableFollowParent = true
	q.Variant = 5
	q.Position = pos
	q.TearFlags = (tearflags or q.TearFlags) & ~(BitSet128(1<<19,0) | BitSet128(1<<38,0))
	if (params.mode and (params.mode & 4 == 4)) or params.tri then 
		q.Variant = 3 q:GetSprite().Color = player.TearColor if (params.mode and params.mode == 1) or (not params.both) then q:SetMaxDistance(90) end
		local s = q:GetSprite() s:Load("gfx/007.003_Shoop Laser.anm2",true) s:Play("LargeRedLaser",true)
	end
	q:GetData()[item.own_key.."effect"] = {player = player,}
	if params.skip then
	else q:Update() q:Update() end
	SFXManager():Stop(SoundEffect.SOUND_REDLIGHTNING_ZAP_WEAK)
	SFXManager():Stop(SoundEffect.SOUND_REDLIGHTNING_ZAP)
	SFXManager():Stop(SoundEffect.SOUND_REDLIGHTNING_ZAP_STRONG)
	SFXManager():Stop(SoundEffect.SOUND_REDLIGHTNING_ZAP_BURST)
	SFXManager():Stop(SoundEffect.SOUND_ANGEL_BEAM)
	return q
end

function item.release_launch(player,ent,params)
	params = params or {}
	local tearflags = params.tearflags or BitSet128(0,0)
	local d = player:GetData()
	if d[item.own_key.."Bomb"] then
		for u,v in pairs(d[item.own_key.."Bomb"]) do
			if auxi.check_all_exists(v) then
				v:GetData()[item.own_key.."effect"] = v:GetData()[item.own_key.."effect"] or {}
				v:GetData()[item.own_key.."effect"].Trigger = true
				v:GetData()[item.own_key.."effect"].delta = true
			end
		end
		d[item.own_key.."Bomb"] = nil
	end
	if d[item.own_key.."Brim"] then
		for u,v in pairs(d[item.own_key.."Brim"]) do
			if auxi.check_exists(v) then
				if v:GetData()[item.own_key.."effect"] == nil or (v:GetData()[item.own_key.."effect"].main == nil) then
					local cnt = auxi.choose(1,2,3,4)
					for i = 1,cnt do
						local dir = (ent.Position - v.Position):GetAngleDegrees() + 90 + 90 * (i - 0.5) / cnt - 45
						v:SetTimeout(40)
						local q = item.cast_brim(player,v.Position,auxi.get_by_rotate(nil,dir,1),{charge = 0.2,tearflags = tearflags,})
						q.Visible = false
						q:SetMaxDistance(0)
						q:GetData()[item.own_key.."effect"].wait = 10
						q:GetData()[item.own_key.."effect"].cascade = {dir = dir,}
						q:SetTimeout(30)
					end
				else
					v:SetTimeout(40)
					local rnd = auxi.random_1() * 360
					local cnt = auxi.choose(5,6,7,8)
					for i = 1,cnt do
						local q = item.cast_brim(player,ent.Position,auxi.get_by_rotate(nil,rnd + i * 360/cnt,1),{charge = 0.2,tearflags = tearflags,})
						q.Visible = false
						q:SetMaxDistance(0)
						q:GetData()[item.own_key.."effect"].wait = 10
						q:GetData()[item.own_key.."effect"].cascade = {dir = rnd + i * 360/cnt,}
						q:SetTimeout(30)
					end
				end
			end
		end
		d[item.own_key.."Brim"] = nil
	end
end

function item.control_linkers(player,ent,params)
	params = params or {}
	if auxi.check_all_exists(ent:GetData()[item.own_key.."linked_bomb"]) then
		local q = ent:GetData()[item.own_key.."linked_bomb"]
		q.PositionOffset = params.pos - ent.Position + Vector(0,15) * math.abs(ent.SpriteScale.Y)		--!!
		q.Position = ent.Position
	end
	if auxi.check_exists(ent:GetData()[item.own_key.."linked_brim"]) then
		local q = ent:GetData()[item.own_key.."linked_brim"]
		q.PositionOffset = params.pos - ent.Position + Vector(0,15) * math.abs(ent.SpriteScale.Y)
		q.PositionOffset = Vector(q.PositionOffset.X,math.min(0,q.PositionOffset.Y))
		q.Position = ent.Position
	end
	if ent:GetData()[item.own_key.."linked_knife"] then
		local d2 = ent:GetData()
		d2[item.own_key.."knife"] = d2[item.own_key.."knife"] or {rnd = auxi.random_1() * 360,}
		d2[item.own_key.."knife"].counter = (d2[item.own_key.."knife"].counter or 0) + 1
		local cnt = d2[item.own_key.."knife"].counter
		for u,v in pairs(d2[item.own_key.."linked_knife"]) do
			v.PositionOffset = params.pos - ent.Position + Vector(0,math.sin(math.rad(cnt * 15 + u * 360/#d2[item.own_key.."linked_knife"])) * 10)
			local tgpos = ent.Position + auxi.get_by_rotate(nil,d2[item.own_key.."knife"].rnd + cnt * 15 + u * 360/#d2[item.own_key.."linked_knife"],40 * ent.SpriteScale.X)
			v.Velocity = (tgpos - v.Position) * 0.2
		end
	end
end

function item.trigger_finfo(player,ent,finfo,einfo,params)
	params = params or {}
	local d = player:GetData()
	local tearHitParams = einfo.tearHitParams or player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
	local tearflags = (einfo.tearflags or BitSet128(0,0)) | tearHitParams.TearFlags
	local dmg = tearHitParams.TearDamage * 5 * (einfo.dmgmul or 1) * (params.dmgrate or 1)
	if finfo.launch and finfo.launch == params.counter then 
		item.anna_attack(player,ent,ent.Position,einfo,params) 
		if params.main then
			item.release_launch(player,ent,tearflags)
		end
		if auxi.check_all_exists(ent:GetData()[item.own_key.."linked_bomb"]) then
			local q = ent:GetData()[item.own_key.."linked_bomb"]
			q.PositionOffset = Vector(0,0)
			ent:GetData()[item.own_key.."linked_bomb"] = nil
		end
		if auxi.check_exists(ent:GetData()[item.own_key.."linked_brim"]) then
			local q = ent:GetData()[item.own_key.."linked_brim"]
			q.PositionOffset = Vector(0,10)
			ent:GetData()[item.own_key.."linked_brim"] = nil
		end
	end
	local weap = einfo.weap or auxi.get_weapon(player)
	if (finfo.fall or finfo.specialcast or -1) == params.counter then 
		if d[item.own_key.."Bomb"] then
			for u,v in pairs(d[item.own_key.."Bomb"]) do
				if auxi.check_all_exists(v) then
					v:GetData()[item.own_key.."effect"] = v:GetData()[item.own_key.."effect"] or {}
					v:GetData()[item.own_key.."effect"].delta = true
				end
			end
		end
	end
	if finfo.specialcast and finfo.specialcast == params.counter then 
		if (weap == 5 or weap == 6) or (auxi.has_have_coll(player,168) or auxi.has_have_coll(player,52)) then
			local both = (auxi.has_have_coll(player,168) and weap == 6) or (auxi.has_have_coll(player,52) and weap == 5)
			local rocket = auxi.has_have_coll(player,168) or weap == 6
			local q = item.cast_bomb(player,ent.Position,Vector(0,0),{Rocket = rocket,main = true,})
			if (ent:GetData()[item.own_key.."Attack"] or {}).ForceWise then q:GetData()[item.own_key.."safe"] = true end
			q:GetData()[item.own_key.."effect"].NoFall = true
			ent:GetData()[item.own_key.."linked_bomb"] = q
			d[item.own_key.."Bomb"] = d[item.own_key.."Bomb"] or {}
			table.insert(d[item.own_key.."Bomb"],q)
		end
		if weap == 2 or auxi.has_have_coll(player,118) then
			local both = weap == 2 and auxi.has_have_coll(player,118)
			local q = item.cast_brim(player,ent.Position,Vector(0,-1),{both = both,tearflags = tearflags,})
			q:GetData()[item.own_key.."effect"].main = true
			d[item.own_key.."Brim"] = d[item.own_key.."Brim"] or {}
			ent:GetData()[item.own_key.."linked_brim"] = q
			table.insert(d[item.own_key.."Brim"],q)
		elseif (tearflags & BitSet128(1<<60,0) == BitSet128(1<<60,0)) then
			local cnt = auxi.choose(3,4,5) local rnd = auxi.random_1() * 360
			for i = 1,cnt do
				local q = item.cast_brim(player,ent.Position,Vector(0,-1),{tearflags = tearflags,charge = 0.33,})
				q.Angle = rnd + i * 360/cnt
				q:SetTimeout(5)
				--q.Velocity = auxi.get_by_rotate(nil,q.Angle + 180,10 * player.ShotSpeed)
			end
		end
		if weap == 13 or auxi.has_have_coll(player,579) then
			local both = (weap == 13 and auxi.has_have_coll(player,579))
			local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,ent.Position,Vector(0,0),player)
			local d2 = q:GetData()
			local mul = 1
			d2[item.own_key.."Sword"] = {mul = mul,rdpos = ent.Position,}
			auxi.copy_sprite(player:GetSprite(),q:GetSprite())
			einfo.Sword = {}
			q.Visible = false
		end
		if ent:GetData()[item.own_key.."linked_knife"] then
			local d2 = ent:GetData()
			for i = 1,(#d2[item.own_key.."linked_knife"]) do
				local tg = d2[item.own_key.."linked_knife"][#d2[item.own_key.."linked_knife"] ]
				tg:GetData()[item.own_key.."Cast"] = {counter = 0,dir = tg.Position - ent.Position,}
				table.remove(d2[item.own_key.."linked_knife"],#d2[item.own_key.."linked_knife"])
				if #d2[item.own_key.."linked_knife"] == 0 then d2[item.own_key.."linked_knife"] = nil break end
			end
		end
	end
	if finfo.cast and finfo.cast == params.counter then 
		local fired = false
		local brimmode = item.check_brim_mode(weap,player,tearflags)
		if (weap == 5 or weap == 6) or (auxi.has_have_coll(player,168) or auxi.has_have_coll(player,52)) then
			local both = (auxi.has_have_coll(player,168) and weap == 6) or (auxi.has_have_coll(player,52) and weap == 5)
			local rocket = auxi.has_have_coll(player,168) or weap == 6
			local q = item.cast_bomb(player,ent.Position,Vector(0,0),{Rocket = rocket,Appear = not both,})
			if (ent:GetData()[item.own_key.."Attack"] or {}).ForceWise then q:GetData()[item.own_key.."safe"] = true end
			q.PositionOffset = params.pos - ent.Position
			d[item.own_key.."Bomb"] = d[item.own_key.."Bomb"] or {}
			table.insert(d[item.own_key.."Bomb"],q)
		end
		if weap == 13 or auxi.has_have_coll(player,579) then
			local both = (weap == 13 and auxi.has_have_coll(player,579))
			local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,ent.Position,Vector(0,0),player)
			local d2 = q:GetData()
			local mul = 1
			if both then mul = 3 end
			d2[item.own_key.."Sword"] = {mul = mul,brimmode = brimmode,}
			auxi.copy_sprite(player:GetSprite(),q:GetSprite())
			einfo.Sword = {}
			q.Visible = false
			fired = true
		end
		if ent:GetData()[item.own_key.."linked_knife"] then
			local d2 = ent:GetData()
			local tg = d2[item.own_key.."linked_knife"][#d2[item.own_key.."linked_knife"] ]
			tg:GetData()[item.own_key.."Cast"] = {counter = 0,dir = tg.Position - ent.Position,brimmode = brimmode,}
			table.remove(d2[item.own_key.."linked_knife"],#d2[item.own_key.."linked_knife"])
			if #d2[item.own_key.."linked_knife"] == 0 then d2[item.own_key.."linked_knife"] = nil end
			fired = true
		end
		if (weap == 2 or auxi.has_have_coll(player,118) or (tearflags & BitSet128(1<<60,0) == BitSet128(1<<60,0))) and fired ~= true then
			if finfo.no2separate then
				local both = (weap == 2 and auxi.has_have_coll(player,118))
				local q = item.cast_brim(player,ent.Position,Vector(0,-1),{both = both,tearflags = tearflags,})
				d[item.own_key.."Brim"] = d[item.own_key.."Brim"] or {}
				ent:GetData()[item.own_key.."linked_brim"] = q
				table.insert(d[item.own_key.."Brim"],q)
			else
				local q = item.fire_anna_phantom(player,ent.Position,Vector(0,0),{})
				local d2 = q:GetData()
				local info = auxi.check_if_any(item.separate_finfo[1],player,ent)
				d2[item.own_key.."Attack"] = {target = q,counter = 0,step = 0,forms = info.finfo or info,extra_info = info.einfo or {[1] = auxi.deepCopy(einfo),},OneStep = info.steps or finfo.steps or 1,}
			end
		end
	end
	item.control_linkers(player,ent,params)
	if finfo.separate and finfo.separate == params.counter then 
		local q = item.fire_anna_phantom(player,ent.Position,Vector(0,0),{})		--!!
		local d2 = q:GetData()
		local info = auxi.check_if_any(finfo.separate_finfo,player,ent)
		d2[item.own_key.."Attack"] = {target = q,counter = 0,step = info.step or 0,forms = info.finfo or info,extra_info = info.einfo or {},OneStep = info.steps or finfo.steps,}
		if ent:GetData()[item.own_key.."Base"] then q:GetData()[item.own_key.."Base"].color = ent:GetData()[item.own_key.."Base"].color end
	end
	if finfo.set and finfo.set == params.counter then 
		ent:GetData()[item.own_key.."linked_knife"] = ent:GetData()[item.own_key.."linked_knife"] or {}
		einfo.Knife = {}
		local mul = einfo.mul or 3
		for i = 1,mul do 
			local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,ent.Position,Vector(0,0),player)
			local s2 = q:GetSprite()
			s2:Load("gfx/player/anna/_anna_knife.anm2")
			s2:Play("Appear",true)
			q:GetData()[item.own_key.."AnnaKnife"] = {counter = 0,linker = ent,}
			table.insert(ent:GetData()[item.own_key.."linked_knife"],q)
		end
	end
	if finfo.scythe and finfo.scythe == params.counter and auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DEATHS_TOUCH) then
		--local pos = auxi.find_target_on_dir(((ent:GetData()[item.own_key.."Attack"] or {}).target or ent).Position,auxi.random_r(),nil,{leg = player.TearRange * 0.5,leg2 = 0.1 * player.TearRange,}).pos
		local tg = (ent:GetData()[item.own_key.."Attack"] or {}).target or ent local tent = auxi.get_nearest_enemy(nil,tg.Position) or tg
		local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,tent.Position,Vector(0,0),player)
		local d2 = q:GetData()
		local mul = 1
		local dir = q.Position - params.pos
		if auxi.check_for_the_same(tent,ent) then dir = q.Position - player.Position end
		d2[item.own_key.."Sword"] = {mul = mul,Scythe = true,recorddir = {[1] = dir:Normalized(),},}
		q.Visible = false
		auxi.copy_sprite(player:GetSprite(),q:GetSprite())
	end
	if tearflags & BitSet128(1<<57,0) == BitSet128(1<<57,0) and finfo.total == params.counter and finfo.port then
		local tg = (ent:GetData()[item.own_key.."Attack"] or {}).target or ent
		local dir = tg.Position - params.pos
		local q = Isaac.Spawn(7,10,0,params.pos,Vector(0,0),player):ToLaser()
		q.Angle = dir:GetAngleDegrees()
		q.MaxDistance = dir:Length()
		q:SetTimeout(2)
		q.OneHit = true
		q.CollisionDamage = dmg * 0.3
		q.PositionOffset = Vector(0,0)
	end
	--if finfo.shake2 and auxi.check_if_any(finfo.shake2[params.counter],player,ent) then Game():MakeShockwave(params.pos,0.5,0.25,2) end
	if params.main and finfo.shake and auxi.check_if_any(finfo.shake[params.counter],player,ent) then
		Game():MakeShockwave(params.pos,1,0.05,20) 
		Game():ShakeScreen(60)
	end
	if tearflags & BitSet128(1<<2,0) == BitSet128(1<<2,0) and finfo.launch then
		if params.counter < finfo.launch then 
			local tg = auxi.get_nearest_enemy(nil,ent.Position)
			if auxi.check_all_exists(tg) then ent.Velocity = (tg.Position - ent.Position) * 0.4 * math.min(2,player.ShotSpeed)
			else ent.Velocity = Vector(0,0) end
		elseif params.counter == finfo.launch then ent.Velocity = Vector(0,0) end
	end
	if tearflags & BitSet128(1<<31,0) == BitSet128(1<<31,0) then
		if auxi.check_all_exists(ent:GetData()[item.own_key.."Godhead"]) then else
			local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,ent.Position,Vector(0,0),player)
			ent:GetData()[item.own_key.."Godhead"] = q
			q:GetData()[item.own_key.."Godhead"] = {linker = ent,Update = 2,}
			local s2 = q:GetSprite() s2:Load("gfx/effects/anna/Halo_godhead_ring.anm2",true) s2:Play("Idle",true)
		end
		local q = ent:GetData()[item.own_key.."Godhead"]
		if auxi.check_all_exists(q) then
			q.Position = ent.Position
			q.PositionOffset = params.pos - ent.Position + auxi.mul_t(Vector(0,-10),auxi.ProtectVector(ent.SpriteScale))
			q.DepthOffset = ent.DepthOffset - 5
			--q:GetSprite().Scale = Vector(1,1) * ent.SpriteScale:Length()/math.sqrt(2)	
			q:GetSprite().Scale = auxi.ProtectVector(ent.SpriteScale)
			q:GetData()[item.own_key.."Godhead"].Update = 2
			q:GetData()[item.own_key.."Godhead"].counter = (q:GetData()[item.own_key.."Godhead"].counter or 0) + 1
			local range = 100 * auxi.ProtectVector(ent.SpriteScale):Length() / math.sqrt(2)
			local n_entity = Isaac.GetRoomEntities()
			if q:GetData()[item.own_key.."Godhead"].counter % 3 == 2 then for u,v in pairs(n_entity) do if (v.Position - params.pos):Length() < range then 
				if auxi.isenemies(v) or ((not v:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and auxi.check_if_any(item.ignore_type[v.Type],v) ~= true) then
					v:TakeDamage(dmg * 0.1,0,EntityRef(player),0) 
				end
			end end end
		end
	end	
end

function item.anna_attack(player,ent,pos,einfo,params)
	einfo = einfo or {}
	params = params or {}
	-- 主攻击与宝宝副本共用同一份 TearParams 采样，避免概率 flag/颜色在同次攻击内各自重投。
	einfo.tearHitParams = einfo.tearHitParams
		or player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
	-- 只在里 Anna 的统一落点攻击入口复制；表 Anna 位于 player_Anna.lua，不经过此路径，
	-- 因此不会被引入里 Anna 的 Maw/black-hole 等新效果。
	if not params.advanced_familiar_copy then
		local CharacterFamiliars = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")
		CharacterFamiliars.for_each_attack_copy(player, function(fam, mul, origin, _, aim_dir)
			local copied_info = {}
			for k, v in pairs(einfo) do copied_info[k] = v end
			copied_info.dmgmul = (tonumber(einfo.dmgmul) or 1) * mul
			copied_info.tearflags = CharacterFamiliars.apply_familiar_tear_flags(player, copied_info.tearflags)
			if aim_dir and aim_dir:Length() >= 0.01 then
				copied_info.dir = aim_dir
			end
			local copied_params = {}
			for k, v in pairs(params) do copied_params[k] = v end
			copied_params.advanced_familiar_copy = true
			if aim_dir and aim_dir:Length() >= 0.01 then
				copied_params.dir = aim_dir
			end
			item.anna_attack(player, fam, origin, copied_info, copied_params)
		end)
		do
			local ok, EvilEye = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Evil_Eye_holder")
			if ok and EvilEye and EvilEye.notify_player_attack then
				EvilEye.notify_player_attack(player, params.dir or einfo.dir)
			end
		end
	end
	if params.noshock ~= true then 
		if player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MEGA_MUSH) then
			local q = Isaac.Spawn(1000,61,0,pos,Vector(0,0),player):ToEffect()
			q.Parent = player
		end
		Game():MakeShockwave(pos,0.035,0.025,10) 
	end
	local n_entity = Isaac.GetRoomEntities()
	local tearHitParams = einfo.tearHitParams or player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
	local tearflags = (einfo.tearflags or BitSet128(0,0)) | tearHitParams.TearFlags
	local tearcolor = params.color or einfo.tearcolor or tearHitParams.TearColor
	local dmg = tearHitParams.TearDamage * 5 * (einfo.dmgmul or 1) * (params.dmgrate or 1)
	local range_mul = (ent.SpriteScale:Length()/math.sqrt(2)) * (params.rangerate or 1)
	local range = (math.sqrt(player.TearRange/10) * 12 + 20) * range_mul
	local weap = einfo.weap or auxi.get_weapon(player)
	local clear_tear = (tearflags & BitSet128(1<<34,0) == BitSet128(1<<34,0)) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_LOST_CONTACT)
	local magnet_tear = (tearflags & BitSet128(0,1<<(66-64)) == BitSet128(0,1<<(66-64))) or player:HasTrinket(TrinketType.TRINKET_SUPER_MAGNET)
	local knock = (tearflags & BitSet128(1<<24,0) == BitSet128(1<<24,0))
	if tearflags & BitSet128(1<<6,0) == BitSet128(1<<6,0) then range = range + 15 end
	if tearflags & BitSet128(1<<18,0) == BitSet128(1<<18,0) then range = range + 15 end
	local cnt = 0
	for u,v in pairs(n_entity) do 
		if (v.Position - pos):Length() < range then
			if v.Type == 9 then
				local mul = -1
				if clear_tear then mul = -8 end
				v:AddVelocity((pos - v.Position):Normalized() * (mul))
			elseif auxi.isenemies(v) then 
				v:TakeDamage(dmg,0,EntityRef(player),0)
				Damage_holder.damage_with(player,v,{Luck = player.luck,dmg = dmg,tearflags = tearflags,tearcolor = tearcolor,player = player,Anna = true,}) 
				cnt = cnt + 1
			elseif (not v:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and auxi.check_if_any(item.ignore_type[v.Type],v) ~= true and v.HitPoints < 10 then
				for i = 1,4 do v:TakeDamage(2.5,0,EntityRef(player),0) end
				if v.MaxHitPoints > 0 and v.HitPoints > 0 then cnt = cnt + 1 end
			end
		end
	end
	tear_trigger_holder.trigger_tear("Anna2",ent,pos,player,nil)
	Isaacs_Tear_holder.add_tear(player)
	if tearflags & BitSet128(1<<12,0) == BitSet128(1<<12,0) then Game():BombExplosionEffects(pos,dmg * 0.5,tearflags,tearcolor,player,range_mul,false,false) end
	if tearflags & BitSet128(1<<61,0) == BitSet128(1<<61,0) then Flat_Stone_holder.attack_wave(pos,{scale = Vector(1,1) * range_mul,dmg = dmg * 0.1,}) end		--!!
	if tearflags & BitSet128(1<<55,0) == BitSet128(1<<55,0) then Jacob_ladder_holder.fire_laser(pos,{player = player,dmg = dmg * 0.1,range = range * 2,}) end
	if tearflags & BitSet128(1<<39,0) == BitSet128(1<<39,0) then
		local q = Isaac.Spawn(1000,EffectVariant.CRACK_THE_SKY,0,pos,Vector(0,0),player):ToEffect()
		q.CollisionDamage = dmg * 0.75
	end
	if auxi.has_have_coll(player,enums.Items.Assassin_s_Eye) then local q = Item_Assassin_s_Eye.fire_Assassin_tear(player,pos,Vector(0,0),{counter = 3,}) q.Visible = false end
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DEAD_EYE) then
		if cnt > 0 then	player:AddDeadEyeCharge()
		else for i = 1,3 do player:ClearDeadEyeCharge() end end
	end
	if auxi.has_have_coll(player,enums.Items.Wavering_Eyes) then 
		if cnt > 0 then	Wavering_Eyes.add_waver_eye_charge(player) 
		else Wavering_Eyes.clear_waver_eye_charge(player) end
	end
	if cnt > 0 and tearflags & BitSet128(1<<52,0) == BitSet128(1<<52,0) and params.main then
		local q = item.fire_anna_phantom(player,ent.Position,Vector(0,0),{})
		local d2 = q:GetData()
		d2[item.own_key.."Attack"] = {target = q,counter = 0,step = 0,forms = {[0] = {id = 0.1,},},extra_info = {},}
		local ret = item.anna_plan(player,nil,d2[item.own_key.."Attack"],1,{pos = (auxi.get_nearest_enemy(nil,ent.Position) or ent).Position,})
		local tcnt = 0
		for u,v in pairs(ret.forms) do
			tcnt = tcnt + 1
			table.insert(d2[item.own_key.."Attack"].forms,auxi.deepCopy(v))
		end
		d2[item.own_key.."Attack"].total = tcnt + 1
		d2[item.own_key.."Attack"].extra_info[1] = d2[item.own_key.."Attack"].extra_info[1] or {}
		d2[item.own_key.."Attack"].extra_info[1].Belial = true
		d2[item.own_key.."Attack"].extra_info[1].tearflags = BitSet128(1<<2,0)
		d2[item.own_key.."Base"] = {color = Color(1,0,0,0.5,0.5,0,0),}
	end
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MAW_OF_THE_VOID) or (auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ATHAME) and auxi.check_rand(player.Luck,30,10,8)) then
		local q = player:SpawnMawOfVoid(35)
		local both = (auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MAW_OF_THE_VOID) and auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ATHAME))
		q:GetData()[item.own_key.."MawLaser"] = {}
		if both then q.CollisionDamage = dmg * 0.4 q:GetData()[item.own_key.."MawLaser"].Radius = 150 * range_mul
		else q.CollisionDamage = dmg * 0.2 q:GetData()[item.own_key.."MawLaser"].Radius = 80 * range_mul end
		q.Radius = 0
		local t = auxi.fire_nil(pos,Vector(0,0),{cooldown = 35,})
		q.Parent = t
		q.Variant = 1 --t:SetTimeout(-1)
	end
	if weap == 9 or auxi.has_have_coll(player,395) then
		local both = (weap == 9 and auxi.has_have_coll(player,395))
		local t
		if both then t = player:FireTechXLaser(pos,Vector(0,0),40 * range_mul + 10,nil,1)
		else t = player:FireTechXLaser(pos,Vector(0,0),20 * range_mul + 20,nil,0.5) end
		t.SubType = 2 t.Parent = ent
		t:GetData()[item.own_key.."Reffect"] = {radius = t.Radius,counter = 0,color = auxi.color2table(t:GetSprite().Color),}
		--t.Radius = 0
		t:GetSprite().Color = Color(1,1,1,0)
		t:SetTimeout(45)
	end
	if weap == 3 or auxi.has_have_coll(player,68) then
		local both = (weap == 3 and auxi.has_have_coll(player,68))
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MONSTROS_LUNG) then 
			auxi.fire_lung_Laser(player,pos,function() return auxi.random_r() end,{angle = 360,dmg = dmg * 0.4,})
		else
			local q2 = auxi.fire_nil(pos,Vector(0,0),{cooldown = 10,})
			local cnt = math.random(2) + 3
			local rnd = math.random(36000)/100
			for i = 1,cnt do
				local q1 = player:FireTechLaser(pos,1,auxi.MakeVector(360/cnt * i + rnd),false,true) q1.Parent = q2 q1.PositionOffset = Vector(0,0)
			end
		end
	end
	if weap == 14 or auxi.has_have_coll(player,678) then
		local both = (weap == 14 and auxi.has_have_coll(player,678))
		local q = auxi.fire_fetus(nil,player,pos,Vector(0,0),true,true,{dmg = dmg * 0.3,tearflags = tearflags,})
		local s = q:GetSprite()
		local d = q:GetData()
		s:Load("gfx/mimics/Evil_Intervention/Evil_I_Tear.anm2",true) s:Play("Idle",true)
		--s:Load("gfx/player/anna/_anna_tear.anm2",true) local anim = "Rotate" if dmg < 10 then anim = anim .. "1" elseif dmg < 35 then anim = anim .. "2" else anim = anim .. "3" end s:Play(anim,true)
		q.TearFlags = q.TearFlags | BitSet128(1<<0,0) | BitSet128(1<<1,0)
		d[item.own_key.."effect"] = {Replay = true,name = anim,}
	end
	if weap == 4 or auxi.has_have_coll(player,114) then 
		local both = (weap == 4 and auxi.has_have_coll(player,114))
		if false then --params.Sword then		--einfo.Knife or 
		else
			local Brimmode = item.check_brim_mode(weap,player,tearflags)
			local knifeparams = {
				cooldown = 30,
				Accerate = 1.3,
				player = player,
				Color = tearcolor,
				Explosive = player:GetCollectibleNum(149) + player:GetCollectibleNum(52),
			}
			local cnt = math.random(2) + 2
			if both and params.Knife ~= true then cnt = cnt + math.random(2) + 2
			else knifeparams.remove_color = true knifeparams.cooldown = 15 end
			local rnd = math.random(36000)/100
			for i = 1,cnt do 
				local dir = auxi.MakeVector(360/cnt * i + rnd) * 10
				local q = auxi.fire_knife(pos,dir,dmg * 0.3,nil,knifeparams) 
				if Brimmode > 0 then
					local q3 = item.cast_brim(player,q.Position,-dir,{mode = Brimmode,charge = (einfo.dmgmul or 1),})
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLOOD_LASER_LARGE,1,1,false,0,2)
					q3:SetTimeout(knifeparams.cooldown)
					q3.PositionOffset = Vector(0,0)
					--q3.Parent = q
					--q3.DisableFollowParent = false
					q3.Position = q.Position
					q3.TearFlags = q3.TearFlags & (~TearFlags.TEAR_WAIT)
					q3.MaxDistance = 30
					q3.Angle = -dir:GetAngleDegrees()
					q3:GetData()[item.own_key.."LinkBrimstone"] = {pos = pos - dir * 0.2,linker = q,wait = 2,}
					q3.Visible = false
					--q:GetData()["Knife_link_brimstone"] = q3
				end
			end
		end
	end
	if weap == 13 or auxi.has_have_coll(player,579) then 
		local both = (weap == 13 and auxi.has_have_coll(player,579))
		if einfo.Sword or params.Sword then
		else
			local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,ent.Position,Vector(0,0),player)
			local d2 = q:GetData()
			local mul = 1
			if both then mul = 3 end
			d2[item.own_key.."Sword"] = {mul = mul,}
			auxi.copy_sprite(player:GetSprite(),q:GetSprite())
			q.Visible = false
		end
	end
	if (tearflags & BitSet128(1<<62,0) == BitSet128(1<<62,0)) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_HAEMOLACRIA) then
		local maxcnt = math.random(math.ceil((player:GetCollectibleNum(CollectibleType.COLLECTIBLE_HAEMOLACRIA) + 1) * math.max(1,(einfo.dmgmul or 1))))
		for i = 1, maxcnt do 
			local q = player:FireTear(pos,Vector(0,0),true,true,true)
			q.Visible = false
			q.TearFlags = q.TearFlags | BitSet128(1<<62,0)
			q.TearFlags = q.TearFlags & (~(BitSet128(1<<60,0)))
			q.FallingSpeed = 10
			q.FallingAcceleration = 2.6
			q.PositionOffset = Vector(0,0)
			q.Scale = q.Scale * (auxi.random_1() * 1.5 + 0.8)
		end
	end
	if auxi.has_have_coll(player,495) or auxi.has_have_coll(player,616) then
		local both = auxi.has_have_coll(player,495) and auxi.has_have_coll(player,616)
		if auxi.has_have_coll(player,495) and auxi.check_rand(player.Luck,50,10,10) then
			local q = Isaac.Spawn(1000,EffectVariant.BLUE_FLAME,0,pos,Vector(0,0),player):ToEffect()
			q:SetTimeout(60)
			q.LifeSpan = 60
			q.CollisionDamage = dmg * 4 * 0.2
		elseif auxi.has_have_coll(player,616) and ((both and auxi.check_rand(player.Luck,100,10,10)) or auxi.check_rand(player.Luck,50,10,10)) then
			local q = Isaac.Spawn(1000,EffectVariant.RED_CANDLE_FLAME,0,pos,Vector(0,0),player):ToEffect()
			q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
			q.CollisionDamage = dmg * 3 * 0.2
		end
	end
	local grids = auxi.get_near_grid_info(pos,range)
	for u,v in pairs(grids) do
		local grid = grid_entity.get_grid_entity(v.grid,v.idx):get_grid()
		if params.no_grid ~= true then grid:Hurt(1) end
		if tearflags & BitSet128(1<<50,0) == BitSet128(1<<50,0) then
			if auxi.check_rand(player.Luck,50,20,6) then auxi.try_destroy_grid(grid,1) end
		end
		if tearflags & BitSet128(0,1<<(70 - 64)) == BitSet128(0,1<<(70 - 64)) and auxi.check_rand(player.Luck,80,40,4) then
			local succ = auxi.try_destroy_grid(grid,2)
			if succ then delay_buffer.addeffe(function(params) sound_tracker.PlayStackedSound(SoundEffect.SOUND_STONE_IMPACT,math.random(1000)/1000 * 0.2 + 0.9,math.random(1000)/1000 * 0.1 + 0.95,false,0,2) end,{},1) end
		end
	end
	local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,pos,Vector(0,0),player)
	local s2 = q:GetSprite()
	s2:Load("gfx/player/anna/_anna_effect.anm2",true)
	s2:Play("Fade",true)
	s2.Scale = auxi.mul_t(auxi.ProtectVector((ent:GetData()[item.own_key.."Record"] or {}).BaseScale or ent:GetSprite().Scale),Vector(1.2,0.8)) * range_mul
	s2.Rotation = params.Rotation or 0
	if tearflags & BitSet128(1<<6,0) == BitSet128(1<<6,0) or tearflags & BitSet128(1<<18,0) == BitSet128(1<<18,0) then
		local dir = auxi.random_r()
		local tab = {dir,-dir,}
		if tearflags & BitSet128(1<<18,0) == BitSet128(1<<18,0) then tab = {dir,-dir,auxi.get_by_rotate(dir,90),auxi.get_by_rotate(dir,-90)} end
		for u,v in pairs(tab) do
			local pos_ = v * range * 0.3 + pos
			local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,pos_,Vector(0,0),player)
			local s2 = q:GetSprite()
			s2:Load("gfx/player/anna/_anna_effect.anm2",true)
			s2:Play("Fade",true)
			s2.Scale = auxi.mul_t(auxi.ProtectVector((ent:GetData()[item.own_key.."Record"] or {}).BaseScale or ent:GetSprite().Scale),Vector(1.2,0.8)) * range_mul * 0.5
			s2.Color = tearcolor
		end
	end
	if params.nosound ~= true then sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEMON_HIT,1,1,false,0,2) end
end

function item.anna_plan(player,dinfo,tab,i,params)
	dinfo = dinfo or {}
	local ret = {forms = {},}
	params = params or {}
	local weap = params.weap or auxi.get_weapon(player)
	
	local dir = params.dir
	local stpos = params.stpos or player.Position
	local pos = params.pos or (stpos + auxi.get_by_rotate(dir,dinfo.dir) * (dinfo.legmul or 1) + (dinfo.leg or Vector(0,0)))
	tab.extra_info[i] = {
		weap = weap,
		tearparams = params.tearparams or player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1)),
		pos = pos,
	}
	tab.extra_info[i].tearflags = tab.extra_info[i].tearparams.TearFlags | (dinfo.tearflags or BitSet128(0,0)) | (params.tearflags or BitSet128(0,0))
	if tab.extra_info[i].tearflags & BitSet128(1<<7,0) == BitSet128(1<<7,0) then	
		local delta = (pos - stpos):Length()
		local cinfo = auxi.check_lerp(delta,item.coal_info)
		tab.extra_info[i].dmgmul = (tab.extra_info[i].dmgmul or 1) * (1 + cinfo.val)
		tab.extra_info[i].scale = auxi.mul_t(tab.extra_info[i].scale or Vector(1,1),cinfo.scale)
	end
	if tab.extra_info[i].tearflags & BitSet128(1<<21,0) == BitSet128(1<<21,0) then	
		local delta = (pos - stpos):Length()
		local pinfo = auxi.check_lerp(delta,item.prop_info)
		tab.extra_info[i].dmgmul = (tab.extra_info[i].dmgmul or 1) * (1 + pinfo.val)
		tab.extra_info[i].scale = auxi.mul_t(tab.extra_info[i].scale or Vector(1,1),pinfo.scale)
	end
	if params.charge and auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CHOCOLATE_MILK) then
		local cmul = math.min(2,math.max(params.charge,1))
		tab.extra_info[i].dmgmul = (tab.extra_info[i].dmgmul or 1) * cmul
		tab.extra_info[i].scale = auxi.mul_t(tab.extra_info[i].scale or Vector(1,1),auxi.check_lerp(cmul,item.choco_info).scale)
	end
	if weap == 6 then table.insert(ret.forms,{id = 4,iid = i,})
	elseif weap == 5 then table.insert(ret.forms,{id = 6,iid = i,})
	elseif weap == 2 then table.insert(ret.forms,{id = 8,iid = i,})
	elseif weap == 14 then table.insert(ret.forms,{id = 8.1,iid = i,})
	elseif weap == 4 then 
		local mul = 3
		tab.extra_info[i].mul = 3
		table.insert(ret.forms,{id = 10.1,iid = i,})
		for j = 1,mul do table.insert(ret.forms,{id = 10.2,iid = i,wait = 10,}) end
		table.insert(ret.forms,{id = 10,iid = i,wait = 20,})
	elseif weap == 13 then table.insert(ret.forms,{id = 12,iid = i,}) table.insert(ret.forms,{id = 1,iid = i,})
	else table.insert(ret.forms,{id = 2,iid = i,}) end
	return ret
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	-- 死亡 / 换角残留：先安全退出攻击，再走正常逻辑
	if item.should_abort_attack(player) then
		item.force_break(player)
	end
	if player:GetPlayerType() == item.entity then
		local d = player:GetData()
		local s = player:GetSprite()
		local gdir = auxi.ggdir(player,true,true,nil,nil,{ignore_canwork = true,real = true,})
		if Game():IsPaused() or not auxi.g_dir_can_work(player) then
		elseif player:IsDead() or (player.IsCoopGhost and player:IsCoopGhost()) then
			-- 死亡中不再开新攻击 / 充能
		elseif gdir:Length() > 0.05 then
			if auxi.check_all_exists(d[item.own_key.."Focus_target"]) ~= true then
				local q = Isaac.Spawn(1000,enums.Entities.AnnaMarks,0,player.Position,Vector(0,0),player)
				q.GridCollisionClass = 3
				local s2 = q:GetSprite()
				s2.Color = Color(1,1,1,0)
				d[item.own_key.."Focus_target"] = q
			end
			d[item.own_key.."charge"] = (d[item.own_key.."charge"] or 0) + 1
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CHOCOLATE_MILK) then
				player:AddCacheFlags(CacheFlag.CACHE_SIZE)
				player:EvaluateItems()
			end
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ANTI_GRAVITY) then
				d[item.own_key.."anti_counter_Charge_Bar_buff"] = (d[item.own_key.."anti_counter_Charge_Bar_buff"] or 0) + 1
				if d[item.own_key.."anti_counter_Charge_Bar_buff"] >= 100 * player.MaxFireDelay / item.mxdelay2cnt * item.wait_mul then
					if d[item.own_key.."Focus_target"] then
						local fpos = d[item.own_key.."Focus_target"].Position
						local q = item.fire_anna_phantom(player,fpos,Vector(0,0),{color = Color(0,0.85,0.85,0.5,0,0.85,0.85),})
						local d2 = q:GetData() 
						d2[item.own_key.."Attack"] = {target = d[item.own_key.."Focus_target"],counter = 0,step = 0,forms = {[0] = {id = 0.1,},},extra_info = {},wait = true,}
						local ret = item.anna_plan(player,nil,d2[item.own_key.."Attack"],1,{pos = fpos,})
						for u,v in pairs(ret.forms) do
							table.insert(d2[item.own_key.."Attack"].forms,auxi.deepCopy(v))
						end
						d2[item.own_key.."Attack"].total = #d2[item.own_key.."Attack"].forms + 1
					end
					d[item.own_key.."anti_counter_Charge_Bar_buff"] = 0
				end
			elseif d[item.own_key.."anti_counter_Charge_Bar_buff"] then d[item.own_key.."anti_counter_Charge_Bar_buff"] = nil end
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_TECH_5) and d[item.own_key.."charge"] % 10 == 5 then Tech_5_holder.work_on_tech_5(player) end
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_TECHNOLOGY_2) then
				local dir = d[item.own_key.."Focus_target"].Position - player.Position
				if dir:Length() > 10 then
					if auxi.check_all_exists(d[item.own_key.."Tech2"]) then
						local q = d[item.own_key.."Tech2"]
						--dir = d[item.own_key.."Focus_target"].Position - q.Position - q.PositionOffset
						q.Position = player.Position q.Velocity = player.Velocity
						q.Angle = dir:GetAngleDegrees()
						--q.PositionOffset = player_offset_holder.GetPlayerOffset(player)
						q.Visible = true
					else
						local q = player:FireTechLaser(player.Position,0,dir,true,false,nil,0.2)
						q.TearFlags = q.TearFlags & (~TearFlags.TEAR_WAIT)
						q.Parent = ent q:SetTimeout(-1)
						--q.PositionOffset = Vector(0,0)
						d[item.own_key.."Tech2"] = q
						q.Visible = false
					end
				elseif auxi.check_all_exists(d[item.own_key.."Tech2"]) then d[item.own_key.."Tech2"]:Remove() d[item.own_key.."Tech2"] = nil end
			end
		elseif auxi.check_all_exists(d[item.own_key.."Focus_target"]) then	--if auxi.g_dir_can_work(player) then
			local cnt = (d[item.own_key.."charge"] or 0) * item.mxdelay2cnt / player.MaxFireDelay
			local shotinfo = auxi.getshotinfo(player,{Extra = true,})
			local charge = math.min(cnt/100,shotinfo.mx)
			local ctrlid = player.ControllerIndex
			if charge >= shotinfo.lw and not (Input.IsActionTriggered(11,ctrlid) or Input.IsActionPressed(11,ctrlid)) then
				local weapon = auxi.get_weapon(player)
				local multishot_of_player = auxi.get_Anna2_multishots(player,nil,{charge = charge,weapon = weapon,})
				local tcnt = 0
				d[item.own_key.."Attack"] = {
					target = d[item.own_key.."Focus_target"],
					counter = 0,
					step = 0,
					forms = {
						[0] = {id = 0,},
					},
					extra_info = {},
					startpos = player.Position,
					basedata = multishot_of_player,
					total = 1 + #(multishot_of_player.main),
				}
				local fpos = d[item.own_key.."Focus_target"].Position
				local stpos = d[item.own_key.."Attack"].startpos
				for i = 1,#multishot_of_player.main do
					local weap = weapon
					if player:HasCollectible(258) or (player:HasCollectible(191) and auxi.random_1() > 0.75) then weap = auxi.choose(1,2,3,4,5,6,7,9,13,14,15) end
					local dinfo = multishot_of_player.main[i]
					local ret = item.anna_plan(player,dinfo,d[item.own_key.."Attack"],i,{dir = fpos - stpos,weap = weap,charge = charge,})
					for u,v in pairs(ret.forms) do
						tcnt = tcnt + 1
						d[item.own_key.."Attack"].forms[tcnt] = auxi.deepCopy(v)
					end
				end
				if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SOY_MILK) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ALMOND_MILK) then d[item.own_key.."Attack"].counter = 999 end		--跳过前摇
				--d[item.own_key.."Attack"].forms[tcnt].id = auxi.check_if_any(item.shift_id[d[item.own_key.."Attack"].forms[tcnt].id],player) or d[item.own_key.."Attack"].forms[tcnt].id		--最后一击变形
				for u,v in pairs(d[item.own_key.."Attack"].forms) do if v.iid == d[item.own_key.."Attack"].forms[tcnt].iid then v.id = (auxi.check_if_any(item.shift_id[v.id],player) or v.id) end end
				d[item.own_key.."Attack"].total = tcnt + 1
				player_offset_holder.LoadPlayer(player,true)
				d[item.own_key.."gridcollision_succ"] = Attribute_holder.try_hold_attribute(player,"GridCollisionClass",EntityGridCollisionClass.GRIDCOLL_NONE)
				d[item.own_key.."entitycollision_succ"] = Attribute_holder.try_hold_attribute(player,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
				if weapon == 8 then
					local q = item.fire_anna_phantom(player,fpos,Vector(0,0))
					local d2 = q:GetData()
					d2[item.own_key.."Attack"] = auxi.deepCopy(d[item.own_key.."Attack"])
					d[item.own_key.."Attack"] = nil
				end
				for i = 1,#multishot_of_player.phantom do
					local weap = weapon
					local tcnt = 0
					if player:HasCollectible(258) or (player:HasCollectible(191) and auxi.random_1() > 0.75) then weap = auxi.choose(1,2,3,4,5,6,7,9,13,14) end
					local dinfo = multishot_of_player.phantom[i]
					local q = item.fire_anna_phantom(player,player.Position,auxi.get_by_rotate(fpos - stpos,dinfo.dir,((dinfo.legmul or 1) * 30 + 10) * player.ShotSpeed),{})
					local d2 = q:GetData()
					d2[item.own_key.."Attack"] = {target = q,counter = 0,step = 0,forms = {[0] = {id = 0,Slowdown = true,},},extra_info = {},}
					d2[item.own_key.."Base"] = {color = dinfo.color,}
					auxi.check_if_any(dinfo,player)
					local ret = item.anna_plan(player,dinfo,d2[item.own_key.."Attack"],i,{dir = fpos - stpos,weap = weap,charge = charge,})
					for u,v in pairs(ret.forms) do
						tcnt = tcnt + 1
						d2[item.own_key.."Attack"].forms[tcnt] = auxi.deepCopy(v)
					end
					d2[item.own_key.."Attack"].total = tcnt + 1
				end
				if auxi.has_have_coll(player,619) then
					for i = 1,3 do if auxi.check_rand(player.Luck,50,25,4) then
						local tcnt = 0
						local weap = auxi.choose(1,2,3,4,5,6,9,13,14)
						local dinfo = {dir = auxi.random_1() * 360,legmul = auxi.random_1(),tearflags = BitSet128(1<<2,0),}
						local q = item.fire_anna_phantom(player,player.Position,auxi.get_by_rotate(fpos - stpos,dinfo.dir,((dinfo.legmul or 1) * 30 + 10) * player.ShotSpeed),{})
						local d2 = q:GetData()
						d2[item.own_key.."Attack"] = {target = q,counter = 0,step = 0,forms = {[0] = {id = 0,},},extra_info = {},ForceWise = true,}
						d2[item.own_key.."Base"] = {color = dinfo.color,}
						auxi.check_if_any(dinfo,player)
						local ret = item.anna_plan(player,dinfo,d2[item.own_key.."Attack"],i,{dir = fpos - stpos,weap = weap,charge = charge,})
						for u,v in pairs(ret.forms) do
							tcnt = tcnt + 1
							d2[item.own_key.."Attack"].forms[tcnt] = auxi.deepCopy(v)
						end
						d2[item.own_key.."Attack"].total = tcnt + 1
					end end
				end
			end
			if auxi.check_all_exists(d[item.own_key.."Focus_target"]) then
				if d[item.own_key.."Focus_target"].Variant == enums.Entities.AnnaMarks then
					if not auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE) then
						d[item.own_key.."Focus_target"]:GetSprite():Play("Fade",true)
						d[item.own_key.."Focus_target"] = nil
					end
				end
			end
			d[item.own_key.."charge"] = 0
			if d[item.own_key.."anti_counter_Charge_Bar_buff"] then d[item.own_key.."anti_counter_Charge_Bar_buff"] = nil end
			if auxi.check_all_exists(d[item.own_key.."Tech2"]) then d[item.own_key.."Tech2"]:Remove() d[item.own_key.."Tech2"] = nil end
		end
		for _ = 1,1 do if d[item.own_key.."Attack"] then
			local fminfo = d[item.own_key.."Attack"].forms[d[item.own_key.."Attack"].step or 0] or {}
			local einfo = d[item.own_key.."Attack"].extra_info[fminfo.iid or 1] or {}
			local finfo = item.attack_info[fminfo.id or 0]
			local info = auxi.check_lerp(d[item.own_key.."Attack"].counter or 0,finfo)
			d[item.own_key.."Attack"].info = info
			d[item.own_key.."Attack"].einfo = einfo
			local birth_succ = false
			if auxi.has_have_coll(player,572) then 
				local val = finfo.specialcast or finfo.cast
				local mov = auxi.getmov(player)
				if val and (d[item.own_key.."Attack"].counter or 0) <= 0 and mov:Length() > 0.05 then
					d[item.own_key.."Attack"].birth = d[item.own_key.."Attack"].birth or {}
					if (fminfo.wait or 0) <= 0 then 
						d[item.own_key.."Attack"].birth.counter = (d[item.own_key.."Attack"].birth.counter or 0) + 1
						if d[item.own_key.."Attack"].birth.counter <= item.birth_info.total then fminfo.wait = (fminfo.wait or 0) + 1 end
					end
					birth_succ = true
				end
			end
			if not birth_succ then d[item.own_key.."Attack"].birth = nil player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown)) end
			--player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
			player:SetMinDamageCooldown(math.max(0,3 - player:GetDamageCooldown()))
			player:AddCacheFlags(CacheFlag.CACHE_SIZE)
			player:EvaluateItems()
			if d[item.own_key.."Attack"].birth then s.Color = Color(1,1,1,1)
			else s.Color = auxi.MulColor(auxi.table2color(info),d[item.own_key.."Attack"].extra_color or Color(1,1,1,1,1,1,1)) end
			local tgpos = player.Position + player_offset_holder.GetPlayerOffset(player)
			if fminfo.wait then fminfo.wait = fminfo.wait - 1 if fminfo.wait <= 0 then fminfo.wait = nil end item.control_linkers(player,player,{pos = tgpos,}) break end
			d[item.own_key.."Attack"].counter = (d[item.own_key.."Attack"].counter or 0) + 1
			if finfo.rport and finfo.rport == d[item.own_key.."Attack"].counter and auxi.check_all_exists(d[item.own_key.."Attack"].port) then
				d[item.own_key.."Attack"].port:GetData()[item.own_key.."AnnaPort"].Fade = true
				d[item.own_key.."Attack"].port = nil
			end
			if finfo.port and finfo.port == d[item.own_key.."Attack"].counter then
				local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,player.Position,Vector(0,0),player)
				local s2 = q:GetSprite()
				s2:Load("gfx/player/anna/_anna_port2.anm2")
				s2:Play("Appear",true)
				q:GetData()[item.own_key.."AnnaPort"] = {
					counter = 0,
					linker = player,
				}
				q.DepthOffset = -20
				s2.Color = Color(1,0,0,1,0.3,0,0)
				d[item.own_key.."Attack"].port = q
			end
			--print(fminfo.id.." "..d[item.own_key.."Attack"].counter)
			item.trigger_finfo(player,player,finfo,einfo,{counter = d[item.own_key.."Attack"].counter,pos = tgpos,main = true,})
			if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] == nil then d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = Attribute_holder.try_hold_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) end
			if d[item.own_key.."Attack"].counter > finfo.total then
				d[item.own_key.."Attack"].extra_color = nil
				if einfo.tearflags & BitSet128(1<<38,0) == BitSet128(1<<38,0) and finfo.init ~= true then
					d[item.own_key.."Attack"].continue_counter = (d[item.own_key.."Attack"].continue_counter or math.max(1,player:GetCollectibleNum(CollectibleType.COLLECTIBLE_CONTINUUM)))
					if d[item.own_key.."Attack"].continue_counter > 0 then
						local gdir = auxi.ggdir(player,true,true,nil,nil,{ignore_canwork = true,ignore_firedirection = true,})
						if gdir:Length() > 0.05 then 
							d[item.own_key.."Attack"].step = (d[item.own_key.."Attack"].step or 0) - 1
							d[item.own_key.."Attack"].continue_counter = d[item.own_key.."Attack"].continue_counter - 1
							d[item.own_key.."Attack"].extra_color = Color(0.5,0.35,0.4,1,0.5,0.35,0.4)
							local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,player.Position,Vector(0,0),player)
							local s2 = q:GetSprite()
							s2:Load("gfx/effects/anna/anna_continum.anm2",true)
							s2:Play("Fade",true)
							s2.Scale = Vector(0.5,1)
							local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,player.Position,Vector(0,0),player)
							local s2 = q:GetSprite()
							s2:Load("gfx/effects/anna/anna_continum.anm2",true)
							s2:Play("Fade",true)
							s2.Scale = Vector(0.5,-1)
							s2.Color = Color(1,1,1,0.3)
							fminfo.wait = 30		--!!
						end
					end
				end
				local nxfminfo = d[item.own_key.."Attack"].forms[(d[item.own_key.."Attack"].step or 0) + 1]
				while(nxfminfo and item.attack_info[nxfminfo.id or 0].Step_forward) do
					d[item.own_key.."Attack"].step = (d[item.own_key.."Attack"].step or 0) + 1
					nxfminfo = d[item.own_key.."Attack"].forms[(d[item.own_key.."Attack"].step or 0) + 1]
				end
				if nxfminfo then
					if nxfminfo.iid ~= fminfo.iid then
						local nxeinfo = d[item.own_key.."Attack"].extra_info[nxfminfo.iid or -1]
						if nxeinfo and nxeinfo.pos then
							Game():MakeShockwave(player.Position + player_offset_holder.GetPlayerOffset(player),0.035,0.025,10) 
							local delta = nxeinfo.pos - player.Position
							player.Position = nxeinfo.pos
							--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 3 then print(v.Variant.." "..v:ToFamiliar().OrbitLayer) end end
							local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 3 and v:ToFamiliar().OrbitLayer >= 0 then v.Position = v.Position + delta end end
						end
					end
				end
				player.Velocity = Vector(0,0)
				d[item.own_key.."Attack"].counter = 0
				d[item.own_key.."Attack"].step = (d[item.own_key.."Attack"].step or 0) + 1
				if auxi.check_all_exists(d[item.own_key.."Attack"].port) then
					d[item.own_key.."Attack"].port:GetData()[item.own_key.."AnnaPort"].Fade = true
					d[item.own_key.."Attack"].port = nil
				end
				if d[item.own_key.."Attack"].basedata.phantom.mult and d[item.own_key.."Attack"].Phantom_mult == nil then
					d[item.own_key.."Attack"].Phantom_mult = {}
					local mcnt = d[item.own_key.."Attack"].basedata.phantom.mult
					for i = 1,mcnt do
						local tgpos = (mcnt - i + 0.5)/mcnt * (player.Position - d[item.own_key.."Attack"].startpos) + d[item.own_key.."Attack"].startpos
						local q = item.fire_anna_phantom(player,tgpos,Vector(0,0),{})		--!!
						local d2 = q:GetData()
						d2[item.own_key.."Attack"] = auxi.deepCopy(d[item.own_key.."Attack"])
						--d2[item.own_key.."Attack"].OneStep = 1
						d2[item.own_key.."Attack"].Hide = i * 2
						d2[item.own_key.."Attack"].NoPos = true
						q.Visible = false
					end
				end
				if (d[item.own_key.."Attack"].step >= d[item.own_key.."Attack"].total) then 
					d[item.own_key.."Attack"] = nil 
					local desc = Game():GetLevel():GetCurrentRoomDesc() if desc.Data.Type == 16 then player.Position = Game():GetRoom():FindFreeTilePosition(player.Position,20) end
					player:AddCacheFlags(CacheFlag.CACHE_SIZE)
					player:EvaluateItems()
					player:SetMinDamageCooldown(math.max(0,15 - player:GetDamageCooldown()))
					if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] then Attribute_holder.try_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = nil end
				end
			end
		else
			if d[item.own_key.."gridcollision_succ"] then Attribute_holder.try_rewind_attribute(player,"GridCollisionClass",d[item.own_key.."gridcollision_succ"]) d[item.own_key.."gridcollision_succ"] = nil end
			if d[item.own_key.."entitycollision_succ"] then Attribute_holder.try_rewind_attribute(player,"EntityCollisionClass",d[item.own_key.."entitycollision_succ"]) d[item.own_key.."entitycollision_succ"] = nil end
			if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] then Attribute_holder.try_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = nil end
			player_offset_holder.LoadPlayer(player, nil)
			s.Color = Color(1,1,1,1)
			item.release_launch(player,player)
		end end
	end
end,
})

function item.force_break(player)
	if not player then return end
	local d = player:GetData()
	local s = player:GetSprite()
	local attack = d[item.own_key.."Attack"]
	if attack and auxi.check_all_exists(attack.port) then
		local port_data = attack.port:GetData()
		port_data[item.own_key.."AnnaPort"] = port_data[item.own_key.."AnnaPort"] or {}
		port_data[item.own_key.."AnnaPort"].Fade = true
	end
	d[item.own_key.."Attack"] = nil
	if d[item.own_key.."gridcollision_succ"] then
		Attribute_holder.try_rewind_attribute(player, "GridCollisionClass", d[item.own_key.."gridcollision_succ"])
		d[item.own_key.."gridcollision_succ"] = nil
	end
	if d[item.own_key.."entitycollision_succ"] then
		Attribute_holder.try_rewind_attribute(player, "EntityCollisionClass", d[item.own_key.."entitycollision_succ"])
		d[item.own_key.."entitycollision_succ"] = nil
	end
	if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] then
		Attribute_holder.try_rewind_attribute(player, "ENTITY_FLAG_NO_DAMAGE_BLINK", d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"], {
			toget = function(ent) return ent:HasEntityFlags(EntityFlag.FLAG_NO_DAMAGE_BLINK) end,
			tochange = function(ent, value)
				if value ~= true then ent:ClearEntityFlags(EntityFlag.FLAG_NO_DAMAGE_BLINK)
				else ent:AddEntityFlags(EntityFlag.FLAG_NO_DAMAGE_BLINK) end
			end,
		})
		d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = nil
	end
	-- 关掉攻击用的贴图代理，恢复可见皮肤
	player_offset_holder.LoadPlayer(player, nil)
	if auxi.check_all_exists(d[item.own_key.."Tech2"]) then
		d[item.own_key.."Tech2"]:Remove()
		d[item.own_key.."Tech2"] = nil
	end
	s.Color = Color(1, 1, 1, 1)
	player.SpriteScale = Vector(1, 1)
	player:AddCacheFlags(CacheFlag.CACHE_SIZE)
	player:EvaluateItems()
	item.release_launch(player, player)
end

function item.has_attack_state(player)
	local d = player:GetData()
	return d[item.own_key.."Attack"]
		or d[item.own_key.."gridcollision_succ"]
		or d[item.own_key.."entitycollision_succ"]
		or d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"]
end

function item.should_abort_attack(player)
	if not item.has_attack_state(player) then return false end
	if player:GetPlayerType() ~= item.entity then return true end
	if player:IsDead() then return true end
	if player.IsCoopGhost and player:IsCoopGhost() then return true end
	return false
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_PLAYER_SHIFT, params = nil,
Function = function(_, player, old_tp)
	-- 从里 Anna 切走，或残留攻击态时强制收束（皮肤/碰撞）
	if old_tp == item.entity or item.has_attack_state(player) then
		item.force_break(player)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if item.has_attack_state(player) then item.force_break(player) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = nil,
Function = function(_,ent)
	if ent.Variant == 30 or ent.Variant == 153 then
		local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
		if player:GetPlayerType() == item.entity and auxi.check_for_the_same(ent.SpawnerEntity,player) then
			local d2 = player:GetData()
			d2[item.own_key.."Focus_target"] = ent
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.AnnaHelper,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	if s:IsPlaying("Fade") or s:IsFinished("Fade") then 
		ent.Velocity = ent.Velocity * 0.5
		if s:IsFinished("Fade") then ent:Remove() return end
	else
		local player = auxi.check_spawner_player(ent)
		if d[item.own_key.."AnnaPort"] then
			local tg = d[item.own_key.."AnnaPort"].linker
			if player then s.Offset = player_offset_holder.GetPlayerOffset(player) + Vector(0,5) * player.SpriteScale.Y end
			s.Scale = auxi.mul_t(player.SpriteScale,Vector(1.2,1.2))
			ent.Position = player.Position
			ent.Velocity = player.Velocity
			ent.DepthOffset = -20
			if ent.FrameCount > 30 or auxi.check_all_exists(tg) ~= true or d[item.own_key.."AnnaPort"].Fade then s:Play("Fade",true) end
		end
		for _ = 1,1 do if d[item.own_key.."AnnaKnife"] then
			local tg = d[item.own_key.."AnnaKnife"].linker
			ent.DepthOffset = 5
			if d[item.own_key.."Cast"] then
				local dposoffset = (ent.PositionOffset - Vector(0,-16)) * 0.2 * math.min(1.5,player.ShotSpeed)
				local rvel = ent.Velocity - dposoffset
				d[item.own_key.."Cast"].posoffset = d[item.own_key.."Cast"].posoffset or ent.PositionOffset.Y
				if math.abs(d[item.own_key.."Cast"].posoffset) < 0.0001 then d[item.own_key.."Cast"].posoffset = 0.001 end
				local prate = auxi.sigmod(ent.PositionOffset.Y/d[item.own_key.."Cast"].posoffset)
				ent.PositionOffset = ent.PositionOffset - dposoffset
				d[item.own_key.."Cast"].tgpos = d[item.own_key.."Cast"].tgpos or auxi.find_target_on_dir(ent.Position,d[item.own_key.."Cast"].dir,nil,{leg = player.TearRange * 0.5,leg2 = 0.1 * player.TearRange,}).pos
				d[item.own_key.."Cast"].counter = (d[item.own_key.."Cast"].counter or 0) + 1
				local dir = d[item.own_key.."Cast"].tgpos - ent.Position
				local checkrange = 100
				if dir:Length() < checkrange then 
					local tg = auxi.get_nearest_enemy(nil,d[item.own_key.."Cast"].tgpos) 
					if auxi.check_all_exists(tg) and (tg.Position - ent.Position):Length() < checkrange then 
						local tgpos = tg.Position + tg.Velocity * 2
						if (d[item.own_key.."Cast"].tgpos - tgpos):Length() < checkrange then d[item.own_key.."Cast"].tgpos = tgpos end
					end
					dir = d[item.own_key.."Cast"].tgpos - ent.Position
				end
				ent.Velocity = dir * 0.2 * math.min(1.5,player.ShotSpeed) * auxi.check_lerp(ent.FrameCount,item.knife_speed_rate).val
				if dir:Length() < 20 and math.abs(ent.PositionOffset.Y + 16) < 5 then 
					ent.PositionOffset = Vector(0,-16)
					ent.Velocity = Vector(0,0)
					ent.Position = d[item.own_key.."Cast"].tgpos
					d[item.own_key.."Cast"] = nil 
					d[item.own_key.."Trigger"] = {} 
					s:Play("Cut",true)
					--local q = auxi.fire_knife(ent.Position - ent.Velocity:Normalized() * 10 * player.ShotSpeed,Vector(0,0),player.Damage * 0.5,nil,{player = player,}) 
					--local s = q:GetSprite() s:Load("gfx/effects/nil_effect.anm2",true) s:Play("Idle",true) 
					break 
				end
				if d[item.own_key.."Cast"].counter > 60 then d[item.own_key.."AnnaKnife"].Fade = true end
				s.Rotation = rvel:GetAngleDegrees() - 90
				s.Rotation = auxi.checkrounded(rvel:GetAngleDegrees() - 90,0,prate,1 - prate,360)
			end
			if auxi.check_all_exists(tg) ~= true or d[item.own_key.."AnnaKnife"].Fade then s:Play("Fade",true) end
		end end
		if d[item.own_key.."Trigger"] then
			ent.Velocity = Vector(0,0)
			d[item.own_key.."Trigger"].counter = (d[item.own_key.."Trigger"].counter or 0) + 1
			s.Rotation = 0
			if s:IsFinished("Cut") then 
				s:Play("Fade",true) 
				item.anna_attack(player,ent,ent.Position,nil,{noshock = true,dmgrate = 0.5,rangerate = 0.5,Knife = true,})
			end
			if d[item.own_key.."Trigger"].counter > 20 then s:Play("Fade",true) end
		end
		for i = 1,1 do if d[item.own_key.."Sword"] then
			d[item.own_key.."Sword"].counter = (d[item.own_key.."Sword"].counter or 0) + 1
			if d[item.own_key.."Sword"].counter == 1 then 
				ent.Visible = true
				d[item.own_key.."Sword"].mul = (d[item.own_key.."Sword"].mul or 3)
				if d[item.own_key.."Sword"].mul <= 0 then ent:Remove() return end
				if auxi.check_all_exists(d[item.own_key.."Sword"].tg) then 
				else d[item.own_key.."Sword"].tg = auxi.get_nearest_enemy(nil,ent.Position + ent.PositionOffset) end
				local tgpos = ent.Position
				local sz = 20
				if auxi.check_all_exists(d[item.own_key.."Sword"].tg) then 
					tgpos = d[item.own_key.."Sword"].tg.Position
					sz = d[item.own_key.."Sword"].tg.Size
				end
				tgpos = d[item.own_key.."Sword"].rdpos or tgpos
				local Vrnd = auxi.random_r() * auxi.random_1() * sz
				local dir = auxi.random_r()
				if d[item.own_key.."Sword"].recorddir then dir = d[item.own_key.."Sword"].recorddir[d[item.own_key.."Sword"].mul] or dir end
				d[item.own_key.."Sword"].stpos = tgpos + Vrnd - dir * sz * player.ShotSpeed * 10
				d[item.own_key.."Sword"].tgpos = tgpos
				d[item.own_key.."Sword"].leg = sz * player.ShotSpeed * 10
				d[item.own_key.."Sword"].edpos = d[item.own_key.."Sword"].stpos + dir * sz * player.ShotSpeed * 10
				d[item.own_key.."Sword"].dir = dir
			end
			local info = auxi.check_lerp(d[item.own_key.."Sword"].counter,item.Sword_info)
			s.Color = auxi.MulColor(auxi.table2color(info),d[item.own_key.."Sword"].basecolor or Color(1,1,1,0.5,-1,-1,-1))
			local realpos = d[item.own_key.."Sword"].stpos * (1 - info.val) + d[item.own_key.."Sword"].edpos * info.val
			if d[item.own_key.."Sword"].Scythe then realpos = (d[item.own_key.."Sword"].stpos * (1 - info.val) + d[item.own_key.."Sword"].edpos * info.val) * 0.5 + (d[item.own_key.."Sword"].tgpos - d[item.own_key.."Sword"].dir * d[item.own_key.."Sword"].leg * 0.2) * 0.5 end
			ent.PositionOffset = realpos - ent.Position
			s.Rotation = d[item.own_key.."Sword"].dir:GetAngleDegrees() + 90
			if d[item.own_key.."Sword"].Scythe then 
				if auxi.check_all_exists(d[item.own_key.."Sword"].Scythe_linker) then else 
					local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,Vector(200,200),Vector(0,0),nil) local s = q:GetSprite() s:Load("gfx/effects/anna/anna_scythe.anm2",true) s:Play("Rotate6",true)
					q:GetData()[item.own_key.."Scythe"] = {linker = ent,}
					d[item.own_key.."Sword"].Scythe_linker = q
				end
				local q = d[item.own_key.."Sword"].Scythe_linker local s2 = q:GetSprite()
				local sinfo = auxi.check_lerp(info.val,item.Scythe_info)
				s2.Rotation = s.Rotation + sinfo.val
				s2.Color = auxi.MulColor(s.Color,Color(1,1,1,0.75,1,1,1)) s2.Scale = s.Scale q.Position = ent.Position q.DepthOffset = ent.DepthOffset - 5
				q.PositionOffset = ent.PositionOffset + auxi.get_by_rotate(d[item.own_key.."Sword"].dir,sinfo.val,60 * s2.Scale.X)
			end
			if (d[item.own_key.."Sword"].brimmode or 0) > 0 then
				if d[item.own_key.."Sword"].counter == 1 and auxi.check_all_exists(d[item.own_key.."Sword"].link_brim) then 
					d[item.own_key.."Sword"].link_brim:SetTimeout(1)
					d[item.own_key.."Sword"].link_brim = nil 
				end
				if auxi.check_all_exists(d[item.own_key.."Sword"].link_brim) ~= true then
					local q = item.cast_brim(player,ent.Position + ent.PositionOffset,-d[item.own_key.."Sword"].dir,{mode = d[item.own_key.."Sword"].brimmode,charge = 1,})
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLOOD_LASER_LARGE,1,1,false,0,2)
					d[item.own_key.."Sword"].link_brim = q
					q:SetTimeout(10)
				end
				local q = d[item.own_key.."Sword"].link_brim
				q.PositionOffset = Vector(0,0)
				q.Position = ent.Position + ent.PositionOffset
			end
			if d[item.own_key.."Sword"].counter == item.Sword_info.cut then
				if auxi.check_all_exists(d[item.own_key.."Sword"].tg) then 
					local tg = d[item.own_key.."Sword"].tg
					item.anna_attack(player,ent,tg.Position,nil,{noshock = true,dmgrate = 0.3,rangerate = 0.5,nosound = true,Rotation = d[item.own_key.."Sword"].dir:GetAngleDegrees() + 90,Sword = true,})
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_TOOTH_AND_NAIL,1,1,false,0,2)
				end
			end
			do
				local dbg = save.ModConfigSettings and save.ModConfigSettings.QingRemasterOptions and save.ModConfigSettings.QingRemasterOptions.Debug
				local trigger = (dbg and tonumber(dbg.AnnaTorsionFrame)) or item.Sword_info.torsion or item.Sword_info.total
				if d[item.own_key.."Sword"].counter == trigger then
				local peak = (dbg and tonumber(dbg.AnnaTorsionPeak)) or 0.1
				local stretch_ratio = (dbg and tonumber(dbg.AnnaTorsionStretchRatio)) or 0.7
				local slide_ang = (dbg and tonumber(dbg.AnnaTorsionSlideAng)) or 28
				local gap = (dbg and tonumber(dbg.AnnaTorsionGap)) or 0.0002
				local soft = (dbg and tonumber(dbg.AnnaTorsionSoft)) or 0.045
				local band_px = (dbg and tonumber(dbg.AnnaTorsionBandPx)) or 52
				local total = (dbg and tonumber(dbg.AnnaTorsionTotal)) or 14
				local hold = (dbg and tonumber(dbg.AnnaTorsionHold)) or 2
				if d[item.own_key.."Sword"].Scythe then
					-- 镰刀暂用经典横扫线段；参数与普通斩共用 Debug
					local pos = d[item.own_key.."Sword"].tgpos
					local dir = auxi.get_by_rotate(d[item.own_key.."Sword"].dir,90)
					local leg = d[item.own_key.."Sword"].leg
					local from = pos - dir * leg
					local to = pos + dir * leg
					Shader_holder.Add_torsion({
						from = from,
						to = to,
						world_space = true,
						peak = peak,
						stretch_ratio = stretch_ratio,
						gap = gap,
						soft = soft,
						band_px = band_px,
						slide_ang_deg = slide_ang,
						total = total,
						hold = hold,
						P3A = -1,
						force = true,
					})
					local c1 = Color(1,1,1,1)
					Seeker_s_Eye.Seeker_link(player,from,to,nil,nil,{NoS2 = true,c1 = c1,})
				else
					Shader_holder.Add_torsion({
						from = d[item.own_key.."Sword"].stpos,
						to = d[item.own_key.."Sword"].edpos,
						world_space = true,
						peak = peak,
						stretch_ratio = stretch_ratio,
						gap = gap,
						soft = soft,
						band_px = band_px,
						slide_ang_deg = slide_ang,
						total = total,
						hold = hold,
						P3A = -1,
						force = true,
					})
					local c1 = Color(1,1,1,1,1,1,1)
					Seeker_s_Eye.Seeker_link(player,d[item.own_key.."Sword"].stpos,d[item.own_key.."Sword"].edpos,nil,nil,{NoS2 = true,c1 = c1,})
				end
				end
			end
			if d[item.own_key.."Sword"].counter >= item.Sword_info.total then 
				d[item.own_key.."Sword"].counter = 0 d[item.own_key.."Sword"].mul = (d[item.own_key.."Sword"].mul or 0) - 1 
			end
		end end
		if d[item.own_key.."Scythe"] then if auxi.check_all_exists(d[item.own_key.."Scythe"].linker) then else ent:Remove() return end end
		if d[item.own_key.."Godhead"] then
			d[item.own_key.."Godhead"].Update = (d[item.own_key.."Godhead"].Update or 0) - 1
			if d[item.own_key.."Godhead"].Update < 0 then s:Play("Fade",true) end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.AnnaMarks,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
	if s:IsPlaying("Fade") or s:IsFinished("Fade") then 
		ent.Velocity = ent.Velocity * 0.5
		if s:IsFinished("Fade") then ent:Remove() return end
	else
		s.Color = auxi.AddColor(s.Color,Color(1,1,1,1),0.8,0.2)
		local tgscale = Vector(1,1)
		local tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
		if tearHitParams.TearFlags & BitSet128(1<<7,0) == BitSet128(1<<7,0) then
			local delta = (player.Position - ent.Position):Length()
			local cinfo = auxi.check_lerp(delta,item.coal_info)
			tgscale = auxi.mul_t(tgscale,cinfo.scale)
		end
		if tearHitParams.TearFlags & BitSet128(1<<21,0) == BitSet128(1<<21,0) then 
			local delta = (player.Position - ent.Position):Length()
			local pinfo = auxi.check_lerp(delta,item.prop_info)
			tgscale = auxi.mul_t(tgscale,pinfo.scale)
		end
		ent.SpriteScale = ent.SpriteScale * 0.8 + tgscale * 0.2
		if player:GetPlayerType() == item.entity then
			local d2 = player:GetData()
			if auxi.check_for_the_same(d2[item.own_key.."Focus_target"],ent) ~= true then s:Play("Fade") return end
			local gdir = auxi.ggdir(player,true,ModConfig.ModConfigSettings.mouseSupport1,ModConfig.ModConfigSettings.mouseSupport2,ent.Position) * player.ShotSpeed * 15
			local ondir = gdir
			local otherdir = Vector(0,0)
			local ctrlidx = player.ControllerIndex
			if auxi.check_bottom_down(341,ctrlidx) then
				d2[item.own_key.."Focus_target"] = nil
				s:Play("Fade")
				return
			end
			if tearHitParams.TearFlags & BitSet128(1<<16,0) == BitSet128(1<<16,0) then 
				local dir = ent.Position - player.Position
				local range = math.sqrt(player.TearRange) * 5 + 40
				local rate = dir:Length()/range
				local info = auxi.check_lerp(rate,item.planet_info)
				ondir = ondir * (1 - info.val)
				otherdir = otherdir + auxi.get_by_rotate(dir,90,gdir:Length()) * info.val
				if rate > 1 then otherdir = otherdir + dir * (1 - rate) * 0.2 end
			end
			if tearHitParams.TearFlags & BitSet128(1<<8,0) == BitSet128(1<<8,0) then 
				local dir = ent.Position - player.Position
				local range = math.sqrt(player.TearRange) * 5 + 40
				local rate = dir:Length()/range
				local info = auxi.check_lerp(ent.FrameCount,item.mirror_info)
				ondir = ondir * info.val
			end
			ent.Velocity = ondir + otherdir
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if player:GetPlayerType() == item.entity or player:GetSprite():GetFilename() == "gfx/characters/reloader/Anna2.anm2" then
		if cacheFlag == CacheFlag.CACHE_FLYING then player.CanFly = true end
	end
	if player:GetPlayerType() == item.entity then
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.05
		end
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 0.35 * auxi.get_damage_multiplier(player)
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + 2 * 40
		end
		local d = player:GetData()
		if cacheFlag == CacheFlag.CACHE_SIZE then
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CHOCOLATE_MILK) then
				local cnt = (d[item.own_key.."charge"] or 0) * item.mxdelay2cnt / player.MaxFireDelay
				local shotinfo = auxi.getshotinfo(player,{Extra = true,})
				local charge = math.min(cnt/100,shotinfo.mx)
				player.SpriteScale = auxi.mul_t(player.SpriteScale,auxi.check_lerp(charge,item.choco_info).scale)
			end
			d[item.own_key.."Record"] = d[item.own_key.."Record"] or {}
			d[item.own_key.."Record"].BaseScale = auxi.ProtectVector(player.SpriteScale)
			if d[item.own_key.."Attack"] and d[item.own_key.."Attack"].info then
				local s = player:GetSprite()
				local info = d[item.own_key.."Attack"].info
				local einfo = d[item.own_key.."Attack"].einfo or {}
				local iscale = info.scale
				if d[item.own_key.."Attack"].birth then iscale = Vector(1,1) end
				player.SpriteScale = auxi.mul_t(auxi.mul_t(player.SpriteScale,iscale),einfo.scale or Vector(1,1))
			end
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_,ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if player and player:GetPlayerType() == item.entity then
		if source and source.Entity then
			local d = source.Entity:GetData()
			if d[item.own_key.."safe"] then return false end
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_,ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if player and player:GetPlayerType() == item.entity then
		local d = player:GetData()
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CURSED_EYE) and not auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BLACK_CANDLE) then
			local cnt = (d[item.own_key.."charge"] or 0)
			local shotinfo = auxi.getshotinfo(player,{Extra = true,})
			local charge = math.min(cnt/100,shotinfo.mx)
			if cnt > 2 and charge >= shotinfo.lw then
				player:AnimateTeleport(true)
				player:UseActiveItem(CollectibleType.COLLECTIBLE_TELEPORT,false,true,false,false)
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	if player:GetPlayerType() == item.entity then
		local ret = nil
		local language = Options.Language
		local infos = (item.Special_Des[language] or {})[tp]
		if infos == nil then return end
		local info = infos[id]
		if info == nil then return end
		ret = {Name = info.Name or value.Name,Description = info.Description or value.Description,}
		return ret
	end
end,
})

--- Gello 等宝宝：从 familiar 原点执行 anna_attack；advanced_familiar_copy 跳过 Incubus 二次复制。
function item.fire_familiar_attack(player, request)
	request = request or {}
	if not player then return {fired = false} end
	local CharacterFamiliars = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")
	local source = request.source
	local origin = request.origin or (source and source.Position) or player.Position
	local aim = request.aim_dir or Vector(0, 1)
	local mul = tonumber(request.damage_mul) or 0.75
	local einfo = {
		dmgmul = mul,
		dir = aim,
		tearflags = CharacterFamiliars.apply_familiar_tear_flags(player, BitSet128(0, 0)),
	}
	local params = {
		advanced_familiar_copy = true,
		dir = aim,
		suppress_player_cost = request.suppress_player_cost,
	}
	item.anna_attack(player, source or player, origin, einfo, params)
	return {fired = true, delay = player.MaxFireDelay}
end

return item

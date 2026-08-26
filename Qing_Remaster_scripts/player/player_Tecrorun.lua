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
local Seeker_s_Eye = require("Qing_Remaster_scripts.items.Item_Seeker_s_Eye")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local Shader_holder = require("Qing_Remaster_scripts.others.Shader_holder")
local Damage_holder = require("Qing_Remaster_scripts.mimics.Damage_holder")
local Epic_holder = require("Qing_Remaster_scripts.mimics.Epic_holder")
local Tech_5_holder = require("Qing_Remaster_scripts.mimics.Tech_5_holder")
local CharacterAttackCompat = require("Qing_Remaster_scripts.player.character_attack_compat")
local Shader_holder = require("Qing_Remaster_scripts.others.Shader_holder")
local Seeker_s_Eye = require("Qing_Remaster_scripts.items.Item_Seeker_s_Eye")
local Item_Assassin_s_Eye = require("Qing_Remaster_scripts.items.Item_Assassin_s_Eye")
local Flat_Stone_holder = require("Qing_Remaster_scripts.mimics.Flat_Stone_holder")
local Isaacs_Tear_holder = require("Qing_Remaster_scripts.mimics.Isaacs_Tear_holder")
local Jacob_ladder_holder = require("Qing_Remaster_scripts.mimics.Jacob_ladder_holder")
local tear_trigger_holder = require("Qing_Remaster_scripts.callbacks.tear_trigger_holder")
local teleport_holder = require("Qing_Remaster_scripts.callbacks.teleport_holder")
local Time_Freeze_holder = require("Qing_Remaster_scripts.mimics.Time_Freeze_holder")
local grid_entity = require("Qing_Remaster_scripts.grids.grid_entity")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Players.Tecrorun,
	own_key = "Player_Tecrorun_",
	dirs = {
		[4] = Vector(-1,0),
		[5] = Vector(1,0),
		[6] = Vector(0,-1),
		[7] = Vector(0,1),
	},
	Special_Des = {
		["zh"] = {
			["Item"] = {
				[CollectibleType.COLLECTIBLE_DR_FETUS] = {Name = "光明炸弹",Description = "耀眼到爆炸！",},
				[CollectibleType.COLLECTIBLE_MOMS_KNIFE] = {Name = "光明穿刺",Description = "耀眼而完美！",},
				[CollectibleType.COLLECTIBLE_BRIMSTONE] = {Name = "光明利焰",Description = "耀眼而华丽！",},
				[CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = {Name = "光明宽刃",Description = "耀眼而优雅！",},
				[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {Name = "光明镭射",Description = "耀眼而喧嚣！",},
				[CollectibleType.COLLECTIBLE_TECH_X] = {Name = "光明环刃",Description = "耀眼而圆满！",},
				[CollectibleType.COLLECTIBLE_EPIC_FETUS] = {Name = "落日-IX",Description = "耀眼而恐怖！",},
				[CollectibleType.COLLECTIBLE_MAW_OF_VOID] = {Name = "光明之咬",Description = "耀眼而贪食！",},
				[CollectibleType.COLLECTIBLE_C_SECTION] = {Name = "光明蜂军",Description = "耀眼而敏锐！",},
				[CollectibleType.COLLECTIBLE_SACRIFICIAL_DAGGER] = {Name = nil,Description = "耀眼而喋血！",},
				[CollectibleType.COLLECTIBLE_ATHAME] = {Name = "祭光之刃",Description = "耀眼而嗜血！",},
				[CollectibleType.COLLECTIBLE_BLOOD_OATH] = {Name = "光之誓言",Description = "耀眼而可怖！",},
				[enums.Items.Book_of_6_sin] = {Name = "论嫉妒",Description = "刺眼而夺目",},
				
			},
		},
		["en"] = {
			["Item"] = {
			},
		},
	},
	Colorinfo = {
		{frame = 0 * 6,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 6,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 6,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 6,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 6,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 6,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 6 * 6,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 6,
	},
	Colorids = {
		[0] = "",
		[1] = "_red",
		[2] = "_orange",
		[3] = "_yellow",
		[4] = "_green",
		[5] = "_blue",
		[6] = "_purple",
	},
	colormap = {
		["R"] = "Red",
		["G"] = "Green",
		["B"] = "Blue",
	},
	colors = {
		[1] = {R = 1,G = 0,B = 0,AO = 1,},
		[2] = {R = 1,G = 0.5,B = 0,AO = 1,},
		[3] = {R = 1,G = 1,B = 0,AO = 1,},
		[4] = {R = 0,G = 1,B = 0,AO = 1,},
		[5] = {R = 0,G = 0,B = 1,AO = 1,},
		[6] = {R = 0.5,G = 0,B = 0.5,AO = 1,},
	},
	sprite_loader = {
		{name = "gfx/player/spears/Missile_Spear.png",offset = 28,color = Color(0.5,0.5,0.5,1),firename = "Head2",triggername = "Shoot",check = function(player,info)
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_EPIC_FETUS) or (auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DR_FETUS) and auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ROCKET_IN_A_JAR)) then return true end 
		end,check_trigger = function(player,ent,info)
			local d = ent:GetData()
			if d.head and d.head:IsPlaying(info.firename or "") and d.head:IsEventTriggered(info.triggername or "") then return true end
		end,special_reloader = {[2] = function(player,ent,info)
			local weap = auxi.get_weapon(player)
			local list = player:GetData().Tecro_list or auxi.get_Tecro_list(player)
			if weap == 6 and (list.epic or 0) > 0 then return "gfx/player/spears/Missile_Spear2.png" end
			if weap == 6 or (list.epic or 0) > 0 then return "gfx/player/spears/Missile_Spear.png" end
			return "gfx/player/spears/Missile_Spear3.png"
		end,},},						--史诗、博士+罐装火箭
		{name = "gfx/player/spears/Brim_Spear.png",offset = 20,color = Color(1,0,0,1),idlename = "IdleHead2",firename = "Head3",onfirename = "IdleHead3",triggername = "Shoot",check = function(player,info) 			--硫磺火：射击时口中发射硫磺火。黑圈：射击时口中发射黑圈
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BRIMSTONE) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MAW_OF_THE_VOID) then return true end 
		end,check_on_fire = function(player,ent,info)
			local d = ent:GetData()
			if auxi.check_delay_exists(d.Tecro_linked_brimstone) or auxi.check_delay_exists(d.Tecro_linked_maw_of_void) then return true end
		end,check_trigger = function(player,ent,info)
			local d = ent:GetData()
			if d.head and d.head:IsPlaying(info.firename or "") and d.head:IsEventTriggered(info.triggername or "") then return true end
		end,},							--硫磺火、黑圈
		{name = "gfx/player/spears/Needle_Spear.png",offset = 15,color = Color(1,1,1,0.3),check = function(player,info) 		--剖腹产：飞针取敌
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_C_SECTION) then return true end 
		end,},							--剖腹产
		{name = "gfx/player/spears/Gun_Spear.png",offset = 20,color = Color(1,1,1,1),idlename = "IdleHead2",firename = "Head4",triggername = "Shoot",check = function(player,info) 			--博士：从炮口发射炸弹
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DR_FETUS) then return true end 		--or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_GLASS_CANNON) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BROKEN_GLASS_CANNON)
		end,check_trigger = function(player,ent,info)
			local d = ent:GetData()
			if d.head and d.head:IsPlaying(info.firename or "") and d.head:IsEventTriggered(info.triggername or "") then return true end
		end,},							--博士
		----5----
		{name = "gfx/player/spears/Sword_Spear.png",offset = 28,color = Color(1,1,1,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SPIRIT_SWORD) then return true end 
		end,},							--英灵剑
		{name = "gfx/player/spears/Tech_X_Spear.png",offset = 18,color = Color(1,0,0,1),check = function(player,info) 		--科X：口中射击激光圈
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_TECH_X) then return true end 
		end,},							--科技X
		{name = "gfx/player/spears/Ipec_Spear.png",offset = 15,color = Color(1,1,1,0.3),firename = "Head1",triggername = "Shoot",check = function(player,info) 		--鍚愭牴
			local idx = player:GetData().__Index
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_IPECAC) then return true end 
		end,check_trigger = function(player,ent,info)
			local d = ent:GetData()
			if d.head and d.head:IsPlaying(info.firename or "") and d.head:IsEventTriggered(info.triggername or "") then return true end
		end,},
		{name = "gfx/player/spears/Knife_Spear.png",offset = 25,color = Color(1,1,1,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MOMS_KNIFE) or (auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_KNIFE_PIECE_1) and auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_KNIFE_PIECE_2)) then return true end 
		end,},							--妈刀、妈刀碎片
		
		----10----
		{name = "gfx/player/spears/Tech_Spear.png",offset = 20,color = Color(1,0,0,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_TECHNOLOGY) then return true end 
		end,},							--科技
		{name = "gfx/player/spears/Damo_Spear.png",offset = 24,color = Color(0.8,0.6,0.45,1),damo = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DAMOCLES) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DAMOCLES_PASSIVE) then return true end 
		end,},							--达摩
		{name = "gfx/player/spears/Salva_Spear.png",offset = 12,color = Color(0.6,0.8,1,0.8),salva = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SALVATION) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_HOLY_LIGHT) then return true end 
		end,},							--救济、圣光
		{name = "gfx/player/spears/Sacrifice_Spear.png",offset = 34,color = Color(1,0,0,1),sacri = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SACRIFICIAL_DAGGER) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SACRIFICIAL_ALTAR) then return true end 
		end,},							--献祭刀、煲仔饭
		
		{name = "gfx/player/spears/Razor_Spear.png",offset = 13,color = Color(1,0.4,0.6,1),bleed_out = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MOMS_RAZOR) then return true end 
		end,},							--妈妈的剃刀
		{name = "gfx/player/spears/Star_Spear.png",offset = 17,color = Color(0.2,0.2,0.7,1),star = true,idlename = "IdleHead2",check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_STAR_OF_BETHLEHEM) then return true end 
		end,},							--伯利恒
		{name = "gfx/player/spears/Lipstick_Spear.png",offset = 18,color = Color(1,0,0,1),reder = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MOMS_LIPSTICK) then return true end 
		end,},							--口红
		{name = "gfx/player/spears/Urn_Spear.png",offset = 22,color = Color(0,0.7,1,1),firename = "Head3",onfirename = "IdleHead3",triggername = "Shoot",bluefire = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_URN_OF_SOULS) then return true end 
		end,check_trigger = function(player,ent,info)
			local d = ent:GetData()
			if d.head and d.head:IsPlaying(info.firename or "") and d.head:IsEventTriggered(info.triggername or "") then return true end
		end,},							--魂瓶
		
		----20----
		{name = "gfx/player/spears/Athame_Spear.png",offset = 14,color = Color(1,1,1,1),reversed_tail = true,maw_of_void = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ATHAME) then return true end 
		end,},							--被黑
		{name = "gfx/player/spears/Sanguine_Spear.png",offset = 14,color = Color(1,0,0,1),bond = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SANGUINE_BOND) then return true end 
		end},							--血色羁绊
		{name = "gfx/player/spears/Bloodoath_Spear.png",offset = 20,color = Color(0.5,0,0,1),blood_oath = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BLOOD_OATH) then return true end 
		end},							--血誓
		
		{name = "gfx/player/spears/Reap_Spear.png",offset = 4,rot_offset = -45,color = Color(0.65,0.45,0.45,1),blade_mul = 0.6,blade = true,blade_offset = 20,blade_rot_offset = 10,blade_rot = -10,blade_scale = Vector(1,3.5),reversed_tail = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DEATHS_TOUCH) then return true end 
		end,},							--镰刀
		{name = "gfx/player/spears/Highheel_Spear.png",offset = 10,rot_offset = -20,color = Color(1,0,0,1),blade_mul = 0.3,blade = true,blade_offset = 10,blade_rot_offset = 20,blade_scale = Vector(1,2),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MOMS_HEELS) then return true end 
		end},							--高跟鞋
		{name = "gfx/player/spears/Kamikaze_Spear.png",offset = 10,color = Color(1,0,0,1),kamikaze = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_KAMIKAZE) then return true end 
		end,},							--神风
		{name = "gfx/player/spears/Gear_Spear.png",offset = 10,color = Color(1,1,1,1),idlename = "IdleHead6",gear = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SMB_SUPER_FAN) then return true end 
		end,},							--食肉男孩
		{name = "gfx/player/spears/Censer_Spear.png",offset = 34,color = Color(0.9,0.7,0,1),censer = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CENSER) then return true end 
		end,},							--香炉
		
		{name = "gfx/player/spears/Prism_Spear.png",offset = 12,color = Color(1,1,1,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_GODHEAD) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ANGELIC_PRISM) or auxi.has_have_coll(player,enums.Items.Gospel) then return true end 
		end,},		--彩色？			--神性、棱镜、福音
		{name = "gfx/player/spears/Rock_Spear.png",offset = 20,color = Color(0,0.75,0.35,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_TERRA) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_TINY_PLANET) then return true end 
		end,},							--地球、小星球
		{name = "gfx/player/spears/Guillotine_Spear.png",offset = 10,color = Color(1,1,1,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_GUILLOTINE) then return true end 
		end,},							--断头台
		{name = "gfx/player/spears/Vampire_Spear.png",offset = 20,color = Color(1,1,1,1),reversed_tail = true,idlename = "IdleHead5",check = function(player,info) 		--idlename = "IdleHead2",
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CHARM_VAMPIRE) then return true end 
		end,},							--吸血鬼
		{name = "gfx/player/spears/Spear_Spear.png",offset = 24,color = Color(1,1,1,1),reversed_tail = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SPEAR_OF_DESTINY) then return true end 
		end,},							--长枪
		{name = "gfx/player/spears/Finger_Spear.png",offset = 20,color = Color(0.84,0.78,0.69,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_FINGER) then return true end 
		end,},							--手指头
		{name = "gfx/player/spears/Magnet_Spear.png",offset = 12,color = Color(1,1,1,1),reversed_tail = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MAGNETO) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_STRANGE_ATTRACTOR) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_LODESTONE) then return true end 
		end,},							--磁铁
		----30----
		{name = "gfx/player/spears/Pencil_Spear.png",offset = 15,color = Color(1,1,0.5,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_LEAD_PENCIL) then return true end 
		end,},							--铅笔
		
		
		{name = "gfx/player/spears/Peeler_Spear.png",offset = 18,color = Color(0.5,0.5,0.5,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_POTATO_PEELER) then return true end 
		end,},							--土豆削皮器
		{name = "gfx/player/spears/Scissor_Spear.png",offset = 10,color = Color(1,1,1,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SCISSORS) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_PINKING_SHEARS) then return true end 
		end,},							--六、二充剪
		{name = "gfx/player/spears/Darkart_Spear.png",offset = 22,color = Color(1,0,0,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DARK_ARTS) then return true end 
		end,},							--黑暗艺术
		{name = "gfx/player/spears/Ice_Spear.png",offset = 25,color = Color(0.45,0.6,0.93,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_URANUS) then return true end 
		end,},							--天王星
		{name = "gfx/player/spears/Sea_Spear.png",offset = 25,color = Color(0,1,1,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_NEPTUNUS) then return true end 
		end,},							--海王星
		{name = "gfx/player/spears/Key_Spear.png",offset = 20,color = Color(1,0,0,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SHARP_KEY) then return true end 
		end},							--尖钥匙
		{name = "gfx/player/spears/Big_chub_Spear.png",offset = 18,color = Color(0.8,0.8,0.7,1),idlename = "IdleHead2",check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BIG_CHUBBY) then return true end 
		end,},							--大妈刀宝
		{name = "gfx/player/spears/Small_chub_Spear.png",offset = 10,color = Color(0.8,0.8,0.7,1),idlename = "IdleHead2",check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_LITTLE_CHUBBY) then return true end 
		end,},							--小妈刀宝
		
		----40----
		
		{name = "gfx/player/spears/Ventriclerazor_Spear.png",offset = 20,color = Color(1,1,1,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_VENTRICLE_RAZOR) then return true end 
		end,},							--手术刀
		{name = "gfx/player/spears/Sumptorium_Spear.png",offset = 26,color = Color(1,0,0,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SUMPTORIUM) then return true end 
		end,},							--圣血吸管
		{name = "gfx/player/spears/Unicorn_Spear.png",offset = 24,color = Color(1,1,1,0.8),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MY_LITTLE_UNICORN) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_UNICORN_STUMP) then return true end 
		end,},							--独角兽
		{name = "gfx/player/spears/Goathead_Spear.png",offset = 20,color = Color(0.5,0.4,0.3,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_GOAT_HEAD) then return true end 
		end,},							--羊头
		{name = "gfx/player/spears/Stigmata_Spear.png",offset = 20,color = Color(0.5,0.4,0.3,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_STIGMATA) then return true end 
		end,},							--圣痕
		{name = "gfx/player/spears/Restock_Spear.png",offset = 16,color = Color(0.4,0.8,0.8,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_RESTOCK) then return true end 
		end,},							--补货
		{name = "gfx/player/spears/Plug_Spear.png",offset = 10,color = Color(1,1,1,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SHARP_PLUG) then return true end 
		end,},							--插头
		{name = "gfx/player/spears/Wirecoathanger_Spear.png",offset = 16,color = Color(1,1,1,1),reversed_tail = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_WIRE_COAT_HANGER) then return true end 
		end,},							--鸭架
		{name = "gfx/player/spears/Betrayal_Spear.png",offset = 16,color = Color(1,0,0,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BETRAYAL) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BACKSTABBER) then return true end 
		end,},							--背叛、背刺
		{name = "gfx/player/spears/Cupid_Spear.png",offset = 16,color = Color(1,1,1,1),reversed_tail = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CUPIDS_ARROW) then return true end 
		end,},							--丘比特
		{name = "gfx/player/spears/Ithurts_Spear.png",offset = 2,color = Color(1,1,1,1),reversed_tail = true,check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_IT_HURTS) then return true end 
		end},							--缝衣针
		{name = "gfx/player/spears/Nail_Spear.png",offset = 18,color = Color(0.7,0.7,0.7,1),check = function(player,info) 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_THE_NAIL) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_8_INCH_NAILS) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_TOOTH_AND_NAIL) then return true end 
		end,},							--钉子、八寸钉
		
		{name = "gfx/player/spears/Angel_Spear.png",offset = 18,color = Color(1,1,1,1),check = function(player,info) 
			if player:HasPlayerForm(PlayerForm.PLAYERFORM_ANGEL) then return true end 
		end,},							--天使套
		{name = "gfx/player/spears/Devil_Spear.png",offset = 20,color = Color(1,0,0,1),check = function(player,info) 
			if player:HasPlayerForm(PlayerForm.PLAYERFORM_EVIL_ANGEL) then return true end 
		end,},							--恶魔套
		{name = "gfx/player/spears/Succubus_Spear.png",offset = 17,color = Color(1,1,1,1),reversed_tail = true,check = function(player,info) 
			if player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY) then return true end 
		end,},							--宝宝套
		{name = "gfx/player/spears/Bone_Spear.png",offset = 30,color = Color(0.6,0,0,1),check = function(player,info) 
			if player:GetCollectibleNum(453) + player:GetCollectibleNum(544) + player:GetCollectibleNum(549) + player:GetCollectibleNum(541) + player:GetCollectibleNum(542) + player:GetCollectibleNum(548) + player:GetCollectibleNum(683) >= 2 then return true end 
		end,},							--骨类
		{name = "gfx/player/spears/Eye_Spear.png",offset = 10,color = Color(1,0,0,1),check = function(player,info) 
			if player:GetCollectibleNum(558) + player:GetCollectibleNum(529) * 2 + player:GetCollectibleNum(261) + player:GetCollectibleNum(410) + player:GetCollectibleNum(462) >= 2 then return true end 
		end,},							--眼睛
		
		{name = "gfx/player/spears/Mega_satan_Spear.png",offset = 15,color = Color(0.7,0.7,0.65,1),check = function(player,info) 
			if save.elses.Tecro_Satan_killed then return true end 
		end,},							--击杀大撒旦
		{name = "gfx/player/spears/Lamb_Spear.png",offset = 20,color = Color(0.7,0.7,0.65,1),lamb = true,check = function(player,info) 
			if save.elses.Tecro_Lamb_killed then return true end 
		end,check_id = function(player,info,ent,id)
			if player:HasTrinket(TrinketType.TRINKET_CURVED_HORN) then return id - 1000 end
		end,},							--击杀羊总
		{name = "gfx/player/spears/Siren_Spear.png",offset = 20,color = Color(0.7,0.7,0.7,1),charm = true,check = function(player,info) 
			if save.elses.Tecro_Siren_killed then return true end 
		end,check_id = function(player,info,ent,id)
			if player:HasCollectible(CollectibleType.COLLECTIBLE_VENUS) then return id - 1000 end
		end,},							--击杀塞壬
		{name = "gfx/player/spears/Darkone_Spear.png",offset = 20,color = Color(1,1,1,1),reversed_tail = true,check = function(player,info) 
			if save.elses.Tecro_Darkone_killed then return true end 
		end,},							--击杀小恶魔
		{name = "gfx/player/spears/Whip_Spear.png",offset = 30,color = Color(0.3,0.3,0.2,1),check = function(player,info) 
			if save.elses.Tecro_Whip_killed then return true end 
		end,},							--击杀天灾
		{name = "gfx/player/spears/Horn_Spear.png",offset = 20,color = Color(1,0,0,1),check = function(player,info) 
			if save.elses.Tecro_Horn_killed then return true end 
		end,},							--击杀角恶魔
		{name = "gfx/player/spears/Krampus_Spear.png",offset = 10,color = Color(1,1,1,1),reversed_tail = true,idlename = "IdleHead7",krampus = true,check = function(player,info) 
			if save.elses.Tecro_Krampus_killed then return true end 
		end,check_id = function(player,info,ent,id)
			if player:HasCollectible(CollectibleType.COLLECTIBLE_HEAD_OF_KRAMPUS) then return id - 1000 end
		end,},							--击杀坎普斯
		{name = "gfx/player/spears/Shell_Spear.png",offset = 20,color = Color(0.7,0.7,0.7,1),idlename = "IdleHead2",check = function(player,info) 
			if save.elses.Tecro_Shell_killed then return true end 
		end,},							--击杀灰虫
		{name = "gfx/player/spears/Tufftwin_Spear.png",offset = 20,color = Color(1,0,0,1),check = function(player,info) 	--idlename = "IdleHead2",
			if save.elses.Tecro_Tufftwin_killed then return true end 
		end,},							--击杀石虫
		{name = "gfx/player/spears/Hollow_Spear.png",offset = 20,color = Color(0.7,0.7,0.7,1),idlename = "IdleHead2",check = function(player,info) 
			if save.elses.Tecro_Hollow_killed then return true end 
		end,},							--击杀空心虫
		----50----
		{name = "gfx/player/spears/Larry_Spear.png",offset = 20,color = Color(0.9,0.8,0.8,1),idlename = "IdleHead2",check = function(player,info) 
			if save.elses.Tecro_Larry_killed then return true end 
		end,},							--击杀贪吃蛇
		
		{name = "gfx/player/spears/Arrow_Spear.png",offset = 27,color = Color(1,1,1,1),reversed_tail = true,check = function(player,info) 
			if player.TearFlags & (TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL) == (TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL) then return true end 
		end,},							--双穿透
		{name = "gfx/player/spears/Long_Spear.png",offset = 45,color = Color(1,1,1,1),check = function(player,info) 
			if get_impale_rate(player) >= 3 then return true end
		end,},							--锋利度>=3
		
		{name = "gfx/player/spears/Normal_Spear.png",offset = 18,color = Color(1,1,1,1),
		},								--正常
		{name = "gfx/player/spears/Sharp_Spear.png",offset = 0,color = Color(0.5,0.5,0.5,1),idlename = "IdleHead4",reversed_tail = true,check = function(player,info,ent)
			if ent.Variant == enums.Entities.Tecro_Needle then return true end
		end,},								--剖腹产附带
		
		--53--
	},
	eventlist = {"Explosion","Shoot","Jump","Land","BloodStart","BloodStop","Lift","Stop","Slide","Spawn","Shoot2","DeathSound","DropSound","Disappear","Prize",},--"Shuffle",--"CoinInsert",--"Heartbeat",
	judged_color_map = {},
	judged_color_dmap = {},
	res_length = 60,
	ignore_type = {
		[1] = true,
		[3] = true,
		[17] = true,
		[86] = true,
	},
	cnt_check = {
		[33] = function(v) return v.HitPoints > 1 end,
	},
	fade_info = {
		{frame = 0,offset = Vector(0,0),scale = Vector(1,1),A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4,offset = Vector(0,-50),scale = Vector(5,0),A = 0,RO = -1,GO = -1,BO = -1,},
		total = 4,
	},
	Addition_catcher = {
		[19] = true,
		[28] = true,
		[62] = true,
		[239] = true,
	},
	knife_move_info = {
		{frame = 0,val = 1,},
		{frame = 20,val = 0.2,},
		{frame = 25,val = 0,},
		{frame = 30,val = 0,},
		total = 30,
	},
	ContInfo = {
		{frame = 0,R = 1,G = 0.2,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2,R = 1.5,G = 0.5,B = 1.5,A = 1,RO = 0.2,GO = 0,BO = 0.2,},
		{frame = 4,R = 0.5,G = 0.1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 6,R = 1,G = 0.2,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6,
	},
	BelialInfo = {
		{frame = 0,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4,R = 1.5,G = 0.25,B = 0,A = 1,RO = 0.5,GO = 0,BO = 0,},
		{frame = 8,R = 1,G = 0,B = 0,A = 1,RO = 1,GO = 0,BO = 0,},
		{frame = 16,R = 1,G = 0,B = 0,A = 1,RO = -1,GO = -1,BO = -1,},
		{frame = 20,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 20,
	},
	GoldInfo = {
		{frame = 0,R = 0.8,G = 0.4,B = 0.1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5,R = 1,G = 0.85,B = 0.2,A = 1,RO = 0.3,GO = 0.25,BO = 0,},
		{frame = 10,R = 1,G = 0.85,B = 0.4,A = 1,RO = 0.8,GO = 0.7,BO = 0.05,},
		{frame = 15,R = 1,G = 1,B = 1,A = 1,RO = 1,GO = 1,BO = 1,},
		{frame = 17,R = 1,G = 0.85,B = 0.2,A = 1,RO = 0.3,GO = 0.25,BO = 0,},
		{frame = 20,R = 0.8,G = 0.4,B = 0.1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 20,
	},
	coal_info = {
		{frame = 0,val = 0,},
		{frame = 3,val = 1,},
		{frame = 10,val = 2,},
		{frame = 30,val = 3,},
	},
	prop_info = {
		{frame = 0,val = 2,},
		{frame = 5,val = 1,},
		{frame = 10,val = 0.5,},
		{frame = 30,val = 0.1,},
	},
	anti_mul = 2,
}

function item.stop_time(ent,source,player)
	Time_Freeze_holder.stop_time(ent,item.own_key)
	ent:GetData()[item.own_key.."Capture"] = {linker = source,}
	if ent:IsBoss() then 
		local d = ent:GetData()
		local extra_time = auxi.get_sharp_time(player)
		d["Tecro_spear_hold_time_Charge_Bar_buff_mx"] = (45 + player.TearRange/15) * player.ShotSpeed + extra_time * 30
		d["Tecro_spear_hold_time_Charge_Bar_buff"] = 0
	end
end

function item.time_free(ent)
	Time_Freeze_holder.time_free(ent,item.own_key)
	local d = ent:GetData()
	d[item.own_key.."Capture"] = nil
	if d["Tecro_spear_hold_time_Charge_Bar_buff"] and d["Tecro_spear_hold_time_Charge_Bar_buff_mx"] then d["Tecro_spear_hold_time_Charge_Bar_buff"] = math.min(d["Tecro_spear_hold_time_Charge_Bar_buff_mx"],d["Tecro_spear_hold_time_Charge_Bar_buff"]) end
end

function item.wait_time(player)
	return 3 * 5 * (player.MaxFireDelay + 1)
end

function item.get_layer_multi(player)
	local ret = 3
	if auxi.has_have_coll(player,619) then ret = ret + 3 end
	return ret
end

function item.get_max_delay(player)
	local ret = math.max(player.MaxFireDelay * math.sqrt(auxi.get_mxdelay_multiplier(player)) * 3,5) * 3
	return ret
end

function item.get_mx_delay(player)
	local ret = 1
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CHOCOLATE_MILK) then ret = ret + 1 end
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CURSED_EYE) then ret = ret + 5 end
	return ret
end

local function get_rot_dis(dir,tp)
	local rt = dir.X
	if tp == "dis" then rt = dir.Y end
	if math.abs(rt) > 0.7 then
		if rt > 0 then return 1
		else return -1
		end
	end
	return 0
end

--l local player_Tecrorun = require("Qing_Remaster_scripts.player.player_Tecrorun") player_Tecrorun.load_color(nil,0)
local function get_spear_range(player,state)
	local d = player:GetData()
	state = state or d.Tecro_spear_state
	local ret = math.max(15,player.TearRange/10)
	if ret >= 26 then ret = 26 + (ret - 26) * 0.8 end
	if ret >= 40 then ret = 40 + math.sqrt(ret - 40) end
	if state == 0 then
	elseif state == -1 then
		ret = ret * 0.1 - 5
	elseif state > 0 then
		ret = ret * 4
	end
	for i = 1,10 do
		local thea = (80 + i * 20)
		if ret >= thea then ret = thea + (ret - thea) * 0.7
		else break end
	end
	return ret
end

local MOUSE_ENABLED_KEY = item.own_key.."mouse_enabled"
local MOUSE_DEBOUNCE_KEY = item.own_key.."mouse_debounce"

local function mouse_enabled(player)
	return player and player:GetData()[MOUSE_ENABLED_KEY] == true
end

local function check_mouse_work(player,ndir,qdir,center)
	qdir = qdir or player:GetData().now_dir
	center = center or player.Position
	local d = player:GetData()
	if player.ControllerIndex == 0 and (d[MOUSE_DEBOUNCE_KEY] or 0) <= 0 and Input.IsMouseBtnPressed(2) then
		d[MOUSE_DEBOUNCE_KEY] = 20
		d[MOUSE_ENABLED_KEY] = not d[MOUSE_ENABLED_KEY]
	end
	if ndir:Length() < 0.05 and mouse_enabled(player) then
		local ret = Vector(0,0)
		local mspos = Input.GetMousePosition(true)
		if Game():GetRoom():IsMirrorWorld() then
			mspos = auxi.mul_t(ui.myScreenToWorld(Isaac.WorldToRenderPosition(Input.GetMousePosition(true))),Vector(-1,1)) +
				auxi.mul_t(Isaac.ScreenToWorld(auxi.GetScreenSize()),Vector(2,0))
		end
		local dir = mspos - (center or Vector(0,0))
		ret = ret + Vector(auxi.get_correct_angle_id(dir:GetAngleDegrees() - qdir:GetAngleDegrees(),2),0)
		if Input.IsMouseBtnPressed(0) then 
			ret = ret + Vector(0,-1)
		elseif Input.IsMouseBtnPressed(1) then
			ret = ret + Vector(0,1)
		end
		return ret:Normalized()
	end
end

function item.get_tecro()
	for playerNum = 1,Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player:GetPlayerType() == item.entity then return player end
	end
end

function item.load_color(player,id)
	player = player or item.get_tecro()
	if not player then return end
	if not item.Colorids[id] then id = 0 end
	local s = player:GetSprite()
	for i = 0,14 do 
		if i ~= 13 then s:ReplaceSpritesheet(i,"gfx/characters/costumes/character_Tecrorun"..item.Colorids[id]..".png") end 
	end
	s:LoadGraphics()
end

function item.get_judged_color(id)
	if item.judged_color_map[id] then return item.judged_color_map[id] end
	local s = Sprite()
	s:Load("gfx/effects/nil_effect.anm2",false)
	local itemConfig = Isaac.GetItemConfig()
	local collectible = itemConfig:GetCollectible(id)
	if collectible then
		local name = collectible.GfxFileName
		s:ReplaceSpritesheet(0,name)
		s:LoadGraphics()
		s:SetFrame("Idle",0)
		local colorvec = {}
		for i = -16,16 do
			for j = -16,16 do
				local Kcol = s:GetTexel(Vector(i,j),Vector(0,0))
				for u,v in pairs(item.colormap) do
					colorvec[u] = (colorvec[u] or 0) + Kcol[v] * Kcol.Alpha
				end
				colorvec["A"] = (colorvec["A"] or 0) + Kcol.Alpha
			end
		end
		item.judged_color_map[id] = colorvec
		return colorvec
	end
end

function item.judge_color(id)
	if item.judged_color_dmap[id] then return item.judged_color_dmap[id] end
	local colorvec = item.get_judged_color(id)
	if colorvec then
		local cmax = colorvec.R + colorvec.G + colorvec.B
		local rate = cmax/math.max(colorvec.A - cmax,cmax)
		local ret = {}
		for u,v in pairs(item.colors) do
			ret[u] = auxi.SimilarColor(colorvec,v) * rate
		end
		item.judged_color_dmap[id] = ret
		return ret
	end
	return {0,0,0,0,0,0,}
end
--[[
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	if player:GetPlayerType() == item.entity then
		if Game():GetFrameCount() == 0 then player:AddEternalHearts(1) end
	end
end,
})
--]]
--l local player_Tecrorun = require("Qing_Remaster_scripts.player.player_Tecrorun") player_Tecrorun.judge_color(118)
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	if player:GetPlayerType() ~= item.entity then return end
	local d = player:GetData()
	if (d[MOUSE_DEBOUNCE_KEY] or 0) > 0 then d[MOUSE_DEBOUNCE_KEY] = d[MOUSE_DEBOUNCE_KEY] - 1 end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local d = player:GetData()
	if player:GetPlayerType() == item.entity then
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			local list = d.Tecro_list or auxi.get_Tecro_list(player)
			local mx_cnt = item.get_max_delay(player) * item.get_mx_delay(player)
			Charging_Bar_holder.render_me(player,{name1 = item.own_key,name2 = item.own_key,name3 = item.own_key,loadname = "gfx/effects/chargebar/chargebar_Tecro.anm2",
				check1 = nil,
				check2 = function(val,ent)
					return val >= mx_cnt
				end,
				check3 = function(val,ent)
					return math.ceil(val/mx_cnt * 100)
				end,
				signal1 = function(ent)
				end,
			})
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ANTI_GRAVITY) then
				Charging_Bar_holder.render_me(player,{name1 = item.own_key.."anti_counter",name2 = item.own_key.."anti_counter",name3 = item.own_key.."anti_counter",loadname = "gfx/effects/chargebar/chargebar_Tecro_Anti.anm2",
					check1 = function(val,ent)
						return val > 5
					end,
					check2 = function(val,ent)
						return val >= mx_cnt * item.anti_mul
					end,
					check3 = function(val,ent)
						return math.ceil(val/mx_cnt/item.anti_mul * 100)
					end,
					signal1 = function(ent)
					end,
				})
			end
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

function item.get_cutting_info(ret,laser)
	ret = ret or {res = 0,}
	ret.res = ret.res or 0
	ret.res_length = ret.res_length or item.res_length
	local samples = laser:GetSamples()
	--local samples = laser:GetNonOptimizedSamples()
	if ret.res_out then ret.res_out = ret.res_out - ret.res end
	local st_pos = laser.Position if ret.break_end and #samples > 0 then st_pos = samples:Get(0) end
	local lspos = st_pos
	local ep = laser:GetEndPoint()
	for i = 0, #samples do
		local pos if i == #samples then pos = ep if ret.break_end then break end else pos = samples:Get(i) end
		local dis = (st_pos - pos):Length()
		local st = ret.res
		local sdir = 0
		while(sdir + ret.res_length < dis - st) do
			lspos = auxi.check_lerp(sdir,{{frame = 0,pos = st_pos,},{frame = dis,pos = pos,},}).pos
			table.insert(ret,{pos = lspos,dir = pos - st_pos,})
			sdir = sdir + ret.res_length
			if ret.res_out then ret.res_out = ret.res_out - ret.res_length if ret.res_out < 0 then return ret end end
		end
		ret.res = st + sdir - dis
		st_pos = pos
	end
	table.insert(ret,{pos = ep,skip = true,})
	--print(#ret)
	return ret
end

function item.get_laser_pair(ent)
	if ent:ToPlayer() then 
		local d = ent:GetData()
		local spear = d.linked_spear
		if auxi.check_all_exists(spear) then 
			local espear = spear.Parent
			if auxi.check_all_exists(espear) then 
				local laser = espear:GetData()[item.own_key.."Linked_Laser"] 
				return laser,espear
			end
		end
	else
		local laser = ent:GetData()[item.own_key.."Linked_Laser"] 
		if laser then return laser,ent end
	end
end

function item.get_segment_multipliers(segment_level)
	segment_level = math.max(0,math.floor(tonumber(segment_level) or 0))
	return 1 + segment_level * 0.30,1 + segment_level * 0.15
end

function item.get_segment_preview_alpha(segment_level,reflection_count)
	segment_level = math.max(0,math.floor(tonumber(segment_level) or 0))
	reflection_count = math.max(0,math.floor(tonumber(reflection_count) or 0))
	if reflection_count == 0 or segment_level >= reflection_count then return 1 end
	return 0.35 + 0.65 * segment_level/reflection_count
end

function item.load_impale(ent)
	local d = ent:GetData()
	local laser = d[item.own_key.."Linked_Laser"]
	if auxi.check_exists(laser) then
		local d2 = laser:GetData()
		d2[item.own_key.."laser"] = d2[item.own_key.."laser"] or {}
		d2[item.own_key.."laser"].wait = {
			pos = laser.Position,
			ang = laser.Angle,
			po = laser.PositionOffset,
		}
		local tbl = {}
		if laser then tbl = item.get_cutting_info(tbl,laser) end
		local laserdata = d2[item.own_key.."laser"] or {}
		d[item.own_key.."Impale"] = {tbl = tbl,id = 0,reflection_count = laserdata.reflection_count or laserdata.mxlayer or laserdata.layer or 0,last_pivot = laser.Position,}
	end
end

function item.start_impale(player)
	local d = player:GetData()
	local spear = d.linked_spear
	if auxi.check_all_exists(spear) then 
		local espear = spear.Parent
		if auxi.check_all_exists(espear) then
			local laser = espear:GetData()[item.own_key.."Linked_Laser"]
			if auxi.check_exists(laser) then
				local d2 = laser:GetData()
				d2[item.own_key.."laser"] = d2[item.own_key.."laser"] or {}
				d2[item.own_key.."laser"].wait = {
					pos = laser.Position,
					ang = laser.Angle,
					po = laser.PositionOffset,
				}
				local tbl = {}
				if laser then --while(laser) do
					tbl = item.get_cutting_info(tbl,laser)
					--laser = laser:GetData()[item.own_key.."Linked_Laser"]
				end
				local laserdata = d2[item.own_key.."laser"] or {}
				d[item.own_key.."Impale"] = {tbl = tbl,id = 0,reflection_count = laserdata.reflection_count or laserdata.mxlayer or laserdata.layer or 0,last_pivot = laser.Position,}
			end
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Phantom,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local player = CharacterAttackCompat.resolve_entity_player(ent, auxi.check_spawner_player(ent))
	if not player then return end
	local ctrlvel = false
	if d[item.own_key.."Tecro_Phantom"] then ctrlvel = true end
	d[item.own_key.."Base"] = d[item.own_key.."Base"] or {}
	--if d[item.own_key.."Base"].color then auxi.PrintTable(auxi.color2table(d[item.own_key.."Base"].color)) end
	for i = 1,1 do if d[item.own_key.."Fade"] then
		d[item.own_key.."Fade"].counter = (d[item.own_key.."Fade"].counter or 0) + 1
		local info = auxi.check_lerp(d[item.own_key.."Fade"].counter or 0,item.fade_info)
		ent.SpriteScale = info.scale
		--ent.PositionOffset = info.offset
		s.Color = auxi.MulColor(Color(1,1,1,info.A,1,1,1),d[item.own_key.."Base"].color or Color(1,1,1,0.5,-1,-1,-1))
		if d[item.own_key.."Fade"].counter > item.fade_info.total then d[item.own_key.."Fade"] = nil ent:Remove() return end
	elseif d[item.own_key.."Attack"] then
		local dir = d[item.own_key.."Attack"].dir
		local difcnt = 3
		d[item.own_key.."Attack"].counter = (d[item.own_key.."Attack"].counter or 0) + 1
		for i = 1,1 do if d[item.own_key.."Attack"].wait then
			d[item.own_key.."Attack"].wait = d[item.own_key.."Attack"].wait - 1
			local gdir = auxi.ggdir(player,true,true,nil,nil,{ignore_canwork = true,real = true,})
			if Game():IsPaused() or (not auxi.g_dir_can_work(player)) or gdir:Length() > 0.05 then
			else d[item.own_key.."Attack"].wait = nil break end
			if d[item.own_key.."Attack"].wait < 0 then d[item.own_key.."Attack"].wait = nil break end
			if d[item.own_key.."Attack"].counter >= difcnt then d[item.own_key.."Attack"].counter = d[item.own_key.."Attack"].counter - 1 end
		end end
		if d[item.own_key.."Attack"].counter < difcnt then 
			s.Color = auxi.MulColor(d[item.own_key.."Base"].color,Color(1,1,1,(d[item.own_key.."Attack"].counter + 0.5)/difcnt,1,1,1))
			local tq = d[item.own_key.."Linked_Laser"]
			if auxi.check_exists(tq) ~= true and Game():GetRoom():IsPositionInRoom(ent.Position,d[item.own_key.."Attack"].margin or 0) then
				d[item.own_key.."Linked_Laser"] = item.fire_tecro_laser(ent.Position,player,dir,{tearflags = d[item.own_key.."Attack"].tearflags,Addtearflags = d[item.own_key.."Attack"].Addtearflags,})
				tq = d[item.own_key.."Linked_Laser"]
				local d3 = tq:GetData()
				d3[item.own_key.."laser"].layer = d[item.own_key.."Attack"].layer d3[item.own_key.."laser"].mxlayer = d[item.own_key.."Attack"].layer d3[item.own_key.."laser"].reflection_count = d[item.own_key.."Attack"].layer d3[item.own_key.."laser"].segment_level = 0 d3[item.own_key.."laser"].linker = ent
			end
		elseif d[item.own_key.."Attack"].counter == difcnt then 
			item.load_impale(ent)
			if d[item.own_key.."Impale"] == nil then d[item.own_key.."Fade"] = {} break end
			d[item.own_key.."Impale"].rnd = auxi.random_1() * 60
		end
		if d[item.own_key.."Attack"].counter >= difcnt then 
			for i = 1,2 do
				local ret = item.control_impale(player,ent,{main = nil,tearflags = (d[item.own_key.."Attack"].tearflags or BitSet128(0,0)) | (d[item.own_key.."Attack"].Addtearflags or BitSet128(0,0)),charge = d[item.own_key.."Attack"].charge,}) or {}
				if ret.End then d[item.own_key.."Fade"] = {} break end
				s.Rotation = ret.dir:GetAngleDegrees() + 90
			end
		end
	elseif d[item.own_key.."Knife"] then
		d[item.own_key.."Knife"].counter = (d[item.own_key.."Knife"].counter or 0) + 1
		local info = auxi.check_lerp(d[item.own_key.."Knife"].counter,item.knife_move_info)
		s.Rotation = d[item.own_key.."Knife"].dir:GetAngleDegrees() - 90
		ent.DepthOffset = 20
		ent.Position = ent.Position + info.val * d[item.own_key.."Knife"].dpos
		if d[item.own_key.."Knife"].counter == 24 then s:Play("Fade2",true) end
		ctrlvel = true
		local cnt = #(d[item.own_key.."Knife"].linkers)
		for i = #(d[item.own_key.."Knife"].linkers),1,-1 do
			local v = d[item.own_key.."Knife"].linkers[i]
			if not auxi.check_all_exists(v) or v:IsDead() then item.time_free(v) table.remove(d[item.own_key.."Knife"].linkers,i) 
			else v.Position = ent.Position + d[item.own_key.."Knife"].dir * (10 * (i - 0.5)/cnt) v.Velocity = Vector(0,0) v:TakeDamage(player.Damage * 0.2,0,EntityRef(player),0) end
		end
		if d[item.own_key.."Knife"].counter >= item.knife_move_info.total then
			for u,v in pairs(d[item.own_key.."Knife"].linkers) do item.time_free(v) end
			ent:Remove() return
		end
	end end
	if ctrlvel then ent.Velocity = Vector(0,0) end
end,
})

function item.fire_tecro_phantom(player,pos,vel,params)
	params = params or {}
	local q = Isaac.Spawn(1000,enums.Entities.Phantom,0,pos,vel,player):ToEffect()
	local s = q:GetSprite()
	local d = q:GetData()
	auxi.copy_sprite(player:GetSprite(),s)
	local col = params.color or Color(1,1,1,0.5,-1,-1,-1)
	d[item.own_key.."Base"] = {color = col,}
	d[item.own_key.."Tecro_Phantom"] = {}
	q:GetData()[item.own_key.."Attack"] = {dir = params.dir,tearflags = params.tearflags,Addtearflags = params.Addtearflags,layer = params.layer or 0,wait = params.wait,margin = params.margin,cross = params.cross,charge = params.charge,}
	s.Rotation = params.dir:GetAngleDegrees() + 90
	s.Color = auxi.MulColor(col,Color(1,1,1,0,1,1,1))
	return q
end

function item.attack_impale(player,ent,pos,einfo,params) 
	einfo = einfo or {}
	params = params or {}
	if params.main and not params.advanced_familiar_copy then
		local pd = player:GetData()
		local frame = Game():GetFrameCount()
		if pd[item.own_key.."evil_eye_frame"] ~= frame then
			pd[item.own_key.."evil_eye_frame"] = frame
			local ok, EvilEye = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Evil_Eye_holder")
			if ok and EvilEye and EvilEye.notify_player_attack then
				EvilEye.notify_player_attack(player, params.dir or params.best_dir)
			end
		end
	end
	local n_entity = Isaac.GetRoomEntities()
	local d = ent:GetData()
	d[item.own_key.."Attack_Impale"] = d[item.own_key.."Attack_Impale"] or {} 
	local tearHitParams = einfo.tearHitParams or player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
	local tearflags = (einfo.tearflags or BitSet128(0,0)) | tearHitParams.TearFlags
	local tearcolor = params.color or einfo.tearcolor or tearHitParams.TearColor
	local charge = params.charge or 1
	local sid = d[item.own_key.."Impale"].step_id
	local dmgmul = (einfo.dmgmul or 1)
	local range_mul = (0.5 + 0.5 * math.sqrt(ent.SpriteScale:Length()/math.sqrt(2))) * (params.rangerate or 1)
	local segment_dmg_mul,segment_width_mul = item.get_segment_multipliers(params.segment_level or 0)
	dmgmul = dmgmul * segment_dmg_mul
	range_mul = range_mul * segment_width_mul
	if tearflags & BitSet128(1<<7,0) == BitSet128(1<<7,0) then local cinfo = auxi.check_lerp(sid,item.coal_info) dmgmul = dmgmul * cinfo.val range_mul = range_mul * math.sqrt(cinfo.val) end
	if tearflags & BitSet128(1<<21,0) == BitSet128(1<<21,0) then local pinfo = auxi.check_lerp(sid,item.prop_info) dmgmul = dmgmul * pinfo.val range_mul = range_mul * math.sqrt(pinfo.val) end
	local dmg = tearHitParams.TearDamage * 0.5 * dmgmul * (params.dmgrate or 1) * math.sqrt(charge)
	local range = (math.sqrt(player.TearRange/10) * 12 + 5) * range_mul
	local weap = einfo.weap or auxi.get_weapon(player)
	local clear_tear = (tearflags & BitSet128(1<<34,0) == BitSet128(1<<34,0)) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_LOST_CONTACT)
	local magnet_tear = (tearflags & BitSet128(0,1<<(66-64)) == BitSet128(0,1<<(66-64))) or player:HasTrinket(TrinketType.TRINKET_SUPER_MAGNET)
	local knock = (tearflags & BitSet128(1<<24,0) == BitSet128(1<<24,0))
	local pass = params.pass or (params.cnt == 1) or params.wallpos
	local best_dir = params.best_dir or params.dir
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
				if v:GetData()[item.own_key.."Capture"] then v:TakeDamage(dmg * 0.2,0,EntityRef(player),0)
				else
					v:TakeDamage(dmg,0,EntityRef(player),0)
					Damage_holder.damage_with(player,v,{Luck = player.luck,dmg = dmg,tearflags = tearflags,tearcolor = tearcolor,player = player,Tecro = true,}) 
					cnt = cnt + 1
				end
			elseif (not v:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and auxi.check_if_any(item.ignore_type[v.Type],v) ~= true and v.HitPoints < 10 then
				for i = 1,4 do v:TakeDamage(2.5,0,EntityRef(player),0) end
				if v.MaxHitPoints > 0 and v.HitPoints > 0 and auxi.check_if_any(item.cnt_check[v.Type],v) then cnt = cnt + 1 end
			end
		end
	end
	if ent.FrameCount % 3 == 1 then
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
	end
	if cnt > 0 or params.wallpos then
		tear_trigger_holder.trigger_tear("Tecrorun",ent,pos,player,nil)
		Isaacs_Tear_holder.add_tear(player)
		if tearflags & BitSet128(1<<12,0) == BitSet128(1<<12,0) then Game():BombExplosionEffects(pos,dmg * 0.5,tearflags,tearcolor,player,range_mul,false,false) end
		if tearflags & BitSet128(1<<61,0) == BitSet128(1<<61,0) then Flat_Stone_holder.attack_wave(pos,{scale = Vector(1,1) * range_mul,dmg = dmg * 0.1,}) end		--!!
		if tearflags & BitSet128(1<<55,0) == BitSet128(1<<55,0) then Jacob_ladder_holder.fire_laser(pos,{player = player,dmg = dmg * 0.1,range = range * 2,}) end
		if tearflags & BitSet128(1<<39,0) == BitSet128(1<<39,0) then local q = Isaac.Spawn(1000,EffectVariant.CRACK_THE_SKY,0,pos,Vector(0,0),player):ToEffect() q.CollisionDamage = dmg * 0.75 end
		
		if params.nosound ~= true then
			if cnt > 0 then sound_tracker.PlayStackedSound(auxi.choose(SoundEffect.SOUND_MEATY_DEATHS,SoundEffect.SOUND_TOOTH_AND_NAIL),1,1,false,0,2) end
			if params.wallpos then 
				local soundid = SoundEffect.SOUND_FORESTBOSS_STOMPS
				if auxi.has_have_coll(player,690) then soundid = SoundEffect.SOUND_JELLY_BOUNCE	else end
				sound_tracker.PlayStackedSound(soundid,1,0.75 + 0.5 * math.sqrt(params.lid),false,0,2) 
			end
		end
	end
	if cnt > 0 and params.main and tearflags & BitSet128(1<<52,0) == BitSet128(1<<52,0) and d[item.own_key.."Impale"].Belial == nil then 
		d[item.own_key.."Impale"].Belial = true
		local q = item.fire_tecro_phantom(player,ent.Position,Vector(0,0),{dir = params.dir,layer = 1,margin = -50,Addtearflags = BitSet128(1<<2,0),cross = "BelialInfo",charge = charge * 2,})	--((d2[item.own_key.."laser"] or {}).mxlayer or 1)	--!!
	end
	if pass or cnt > 0 then d[item.own_key.."Attack_Impale"].lcnt = 1 end
	local cinfo = item.Colorinfo 
	local cross = (d[item.own_key.."Attack"] and d[item.own_key.."Attack"].cross)
	if cross then cinfo = item[cross] end
	local effect_scale = math.max(0.05,tonumber(params.effect_scale) or 1)
	if pass then
		local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,pos,Vector(0,0),player)
		local s2 = q:GetSprite()
		s2:Load("gfx/player/anna/_anna_effect.anm2",true)
		s2:Play("Fade",true)
		local base_sc = auxi.mul_t(auxi.ProtectVector((ent:GetData()[item.own_key.."Record"] or {}).BaseScale or ent:GetSprite().Scale),Vector(1,1)) * range_mul
		if effect_scale ~= 1 then
			s2.Scale = Vector(base_sc.X * effect_scale, base_sc.Y * effect_scale)
		else
			s2.Scale = base_sc
		end
		s2.Rotation = params.Rotation or 0
		local color = auxi.check_lerp((ent.FrameCount + (params.segment_level or 0) * 6) % cinfo.total,cinfo) color = auxi.UpColor(color,1) s2.Color = color
	else
		d[item.own_key.."Attack_Impale"].lcnt = (d[item.own_key.."Attack_Impale"].lcnt or 1) * 0.75 + 0.25 * 0.2
		local lcnt = d[item.own_key.."Attack_Impale"].lcnt
		local mx_effect_cnt = 3
		local dis = params.dir:Length()
		for i = 1,mx_effect_cnt do
			local di = (i - 0.5)/mx_effect_cnt - 0.5
			local q = Isaac.Spawn(1000,enums.Entities.AnnaHelper,0,pos + auxi.MakeVector(params.Rotation) * (i - mx_effect_cnt/2 - 0.5) * dis * 0.33,Vector(0,0),player)
			local s2 = q:GetSprite()
			s2:Load("gfx/player/anna/_anna_effect.anm2",true)
			s2:Play("Fade",true)
			local base_sc = auxi.mul_t(auxi.ProtectVector((d[item.own_key.."Record"] or {}).BaseScale or ent:GetSprite().Scale),Vector(0.2 + lcnt * lcnt * 0.2,1)) * range_mul
			-- Scale.X = 沿前进方向；Scale.Y = 垂直于前进的宽度（与 Tecrorun 一致）
			if effect_scale ~= 1 then
				s2.Scale = Vector(base_sc.X * effect_scale, base_sc.Y)
			else
				s2.Scale = base_sc
			end
			s2.Rotation = params.Rotation or 0
			local color = auxi.check_lerp((ent.FrameCount + (params.segment_level or 0) * 6 + di + (d[item.own_key.."Impale"].rnd or 0)) % cinfo.total,cinfo) color = auxi.UpColor(color,1) s2.Color = auxi.MulColor(color,Color(1,1,1,lcnt,1,1,1))
		end
	end
	if not params.End and (pass or (cnt > 0)) then		--博士+史诗
		if weap == 5 or auxi.has_have_coll(player,52) then
			if pass or auxi.inner_tick(player:GetData(),item.own_key.."dr_counter",3,{Update = true,}) then 
				local q = player:FireBomb(pos,Vector(0,0)) 
			end
		end
		if weap == 13 or auxi.has_have_coll(player,579) then
			if pass or auxi.inner_tick(player:GetData(),item.own_key.."sword_counter",5,{Update = true,}) then 
				local both = (weap == 13 and auxi.has_have_coll(player,579))
				local Swordparams = {
					cooldown = 8,
					player = player,
					tearflags = tearflags,
					Color = tearcolor,
					Tech = player:HasCollectible(68) or player:HasCollectible(395),
					RotationOffset = params.best_dir:GetAngleDegrees(),
					follower = ent,
					Attack = true,
				}
				if both then Swordparams.cooldown = 16 Swordparams.Attack = false end
				local q = auxi.fire_Sword(pos,Vector(0,0),dmg,nil,Swordparams)
				delay_buffer.addeffe(function(params)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME,1,1,false,0,2)
				end,{},4)
			end
		end
		if weap == 6 or auxi.has_have_coll(player,168) then
			if pass or auxi.inner_tick(player:GetData(),item.own_key.."epic_counter",3,{Update = true,}) then
				local q = auxi.launch_Missile(pos,Vector(0,0),nil,{player = player,}) 
			end
		end
	else 
		if weap == 5 or auxi.has_have_coll(player,52) then auxi.inner_tick(player:GetData(),item.own_key.."dr_counter",5,{set = true,set_val = function(d,key) d[key] = math.max(0,d[key] - 2) end,}) end
		if weap == 6 or auxi.has_have_coll(player,168) then auxi.inner_tick(player:GetData(),item.own_key.."epic_counter",5,{set = true,set_val = function(d,key) d[key] = math.max(0,d[key] - 2) end,}) end
		if weap == 13 or auxi.has_have_coll(player,579) then auxi.inner_tick(player:GetData(),item.own_key.."sword_counter",5,{set = true,set_val = function(d,key) d[key] = math.max(0,d[key] - 2) end,}) end
	end
	if params.wallpos and auxi.check_all_exists(d[item.own_key.."Laser"]) then
		local q = d[item.own_key.."Laser"] q:SetTimeout(12) q.Position = params.wallpos
		d[item.own_key.."Laser"] = nil
	end
	local add_brim = false
	if (weap == 4 or auxi.has_have_coll(player,114)) then
		if auxi.has_have_coll(player,118) and params.wallpos then 
			local dir = -params.best_dir:Normalized()
			local Knifeparams = {
				cooldown = 30,Accerate = 1.5,player = player,tearflags = tearflags,Color = player.TearColor,remove_color = true,
			}
			local cnt = math.random(3) + 1 + 2 * (player:GetCollectibleNum(118) - 1)
			for i = 1,cnt do
				local cnt2 = math.random(2) + (player:GetCollectibleNum(118) - 1)
				for j = 1,cnt2 do
					delay_buffer.addeffe(function(pm)
						local rand = math.random(31) - 16
						local q2 = auxi.fire_knife(params.wallpos,auxi.get_by_rotate(dir,rand),dmg,nil,Knifeparams)
						q2.PositionOffset = ent.PositionOffset 
						if rand < 0 then q2:GetSprite().FlipX = true q2.RotationOffset = 180 - q2.RotationOffset end
						delay_buffer.addeffe(function(params)
							local mnil = q2.Parent
							if auxi.check_all_exists(mnil) then	mnil.Velocity = mnil.Velocity:Length() * auxi.MakeVector(dir:GetAngleDegrees()) end
						end,{},5,{remove_now = true,})
						for i = 1,2 do
							delay_buffer.addeffe(function(params)
								if q2:GetSprite().FlipX then q2.RotationOffset = 180 - dir:GetAngleDegrees()
								else q2.RotationOffset = dir:GetAngleDegrees() end
							end,{},5 + i,{remove_now = true,})
						end
					end,{},i * 3,{remove_now = true,})
				end
			end
			add_brim = true
		else
			for u,v in pairs(n_entity) do 	--淇樿幏璁＄畻
				if v:GetData()[item.own_key.."Capture"] == nil and auxi.isenemies(v) and (v.Position - pos):Length() < range and not (v:IsBoss() and (v:GetData()["Tecro_spear_hold_time_Charge_Bar_buff"] or 0) > 0) then	
					item.stop_time(v,ent,player)
					d[item.own_key.."Captured"] = d[item.own_key.."Captured"] or {}
					table.insert(d[item.own_key.."Captured"],v)
					if auxi.check_if_any(item.Addition_catcher[v.Type],v) then 
						local n_entities = auxi.get_linked(v) 
						for uu,vv in pairs(n_entities) do	
							local d4 = vv:GetData()
							if d4[item.own_key.."Capture"] == nil then 
								item.stop_time(vv,ent,player)
								table.insert(d[item.own_key.."Captured"],vv)
							end 
						end
					end
				end
			end
		end
	end
	if pass then
		local ldir = params.best_dir if params.cnt ~= 1 then ldir = - ldir end
		local q = nil
		if tearflags & BitSet128(1<<58,0) == BitSet128(1<<58,0) then
			q = q or player:FireTear(ent.Position,ldir:Normalized() * 10 * player.ShotSpeed,true,true,true) q.TearFlags = q.TearFlags | BitSet128(1<<58,0) q.CollisionDamage = dmg * 0.5
		end
		if tearflags & BitSet128(1<<59,0) == BitSet128(1<<59,0) then
			q = q or player:FireTear(ent.Position,ldir:Normalized() * 10 * player.ShotSpeed,true,true,true) q.TearFlags = q.TearFlags | BitSet128(1<<59,0) q.CollisionDamage = dmg * 0.5
		end
	end
	if tearflags & BitSet128(1<<60,0) == BitSet128(1<<60,0) then
		for u,v in pairs(n_entity) do  	--淇樿幏璁＄畻
			if v:GetData()[item.own_key.."Capture"] == nil and auxi.isenemies(v) and (v.Position - pos):Length() < range and not (v:IsBoss() and (v:GetData()["Tecro_spear_hold_time_Charge_Bar_buff"] or 0) > 0) then	
				item.stop_time(v,ent,player)
				d[item.own_key.."Captured"] = d[item.own_key.."Captured"] or {}
				table.insert(d[item.own_key.."Captured"],v)
				if auxi.check_if_any(item.Addition_catcher[v.Type],v) then 
					local n_entities = auxi.get_linked(v) 
					for uu,vv in pairs(n_entities) do	
						local d4 = vv:GetData()
						if d4[item.own_key.."Capture"] == nil then 
							item.stop_time(vv,ent,player)
							table.insert(d[item.own_key.."Captured"],vv)
						end 
					end
				end
			end
		end
	end
	for i = 1,1 do if d[item.own_key.."Captured"] then
		local tri = (tearflags & BitSet128(1<<60,0) == BitSet128(1<<60,0)) if (weap == 4 or auxi.has_have_coll(player,114)) then tri = false end
		local tdmg = dmg * 0.75 if tri then tdmg = dmg * 0.15 end
		local cnt = #d[item.own_key.."Captured"]
		for i = #d[item.own_key.."Captured"],1,-1 do
			local v = d[item.own_key.."Captured"][i]
			if not auxi.check_all_exists(v) or v:IsDead() then item.time_free(v) table.remove(d[item.own_key.."Captured"],i) 
			else 
				if tri then v.Position = pos - params.dir:Normalized() * (30 + 30 * (i - 0.5)/cnt)
				else v.Position = pos + params.dir:Normalized() * (10 * (i - 0.5)/cnt) end
				 v.Velocity = Vector(0,0) v:TakeDamage(tdmg,0,EntityRef(player),0)
				if v:IsBoss() then v:GetData()["Tecro_spear_hold_time_Charge_Bar_buff"] = v:GetData()["Tecro_spear_hold_time_Charge_Bar_buff"] + 1 end
			end
		end
		if tri and params.wallpos then for u,v in pairs(d[item.own_key.."Captured"]) do item.time_free(v) end d[item.own_key.."Captured"] = nil break end
		if params.End then 
			local q = Isaac.Spawn(1000,enums.Entities.Phantom,0,pos,Vector(0,0),player):ToEffect() local d2 = q:GetData() local s2 = q:GetSprite() --s2.Scale = Vector(2,2)
			d2[item.own_key.."Knife"] = {linkers = {},dir = params.best_dir:Normalized(),dpos = params.best_dir:Normalized() * 5,} s2:Load("gfx/player/anna/_anna_knife.anm2") s2:Play("Idle",true)
			s2.Rotation = d2[item.own_key.."Knife"].dir:GetAngleDegrees() - 90
			for u,v in pairs(d[item.own_key.."Captured"]) do
				table.insert(d2[item.own_key.."Knife"].linkers,v)
			end
		end
		if #d[item.own_key.."Captured"] == 0 or params.End then d[item.own_key.."Captured"] = nil end
	end end
	if (weap == 2 or auxi.has_have_coll(player,118) or tearflags & BitSet128(1<<60,0) == BitSet128(1<<60,0)) and not (params.wallpos or params.End or add_brim) then
		if auxi.check_all_exists(d[item.own_key.."Laser"]) then	else 
			local tcharge = charge local not_once = not (weap == 2 or auxi.has_have_coll(player,118)) if not_once then tcharge = tcharge * 0.5 end
			local q = player:FireBrimstone(-params.dir,nil,tcharge) if tearflags & BitSet128(1<<60,0) == BitSet128(1<<60,0) then q.Variant = 3 local s = q:GetSprite() s:Load("gfx/007.003_Shoop Laser.anm2",true) s:Play("LargeRedLaser",true) end if not_once then q:SetMaxDistance(90) end
			d[item.own_key.."Laser"] = q
			q:SetTimeout(99) q.Mass = 0 q.DisableFollowParent = true q.Position = pos q.PositionOffset = Vector(0,0) q.DepthOffset = -300
			q.TearFlags = (tearflags or q.TearFlags) & ~(BitSet128(1<<19,0) | BitSet128(1<<38,0))
		end
	end
	if not (params.wallpos or params.End) then if auxi.check_all_exists(d[item.own_key.."Laser"]) then local q = d[item.own_key.."Laser"] q.Position = pos q.Angle = params.dir:GetAngleDegrees() + 180 end end
	if (weap == 3 or auxi.has_have_coll(player,68)) then
		if params.wallpos then 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MONSTROS_LUNG) then 
				auxi.fire_lung_Laser(player,params.wallpos,function() return -params.best_dir:Normalized() end,{angle = (params.dang or 45) * 2,dmg = dmg * 0.4,cnt = function() if params.main then return auxi.choose(4,5,6,7) else return auxi.choose(0,1,2) end end,})
			else
				local techcnt = 5 if not params.main then techcnt = 3 end
				for i = 1,techcnt do
					local dir = auxi.get_by_rotate(params.best_dir,180 + ((i - 0.5)/techcnt - 0.5) * (params.dang or 30) * 2)
					local q = player:FireTechLaser(params.wallpos,0,dir,false,true,nil,charge) q.TearFlags = q.TearFlags | BitSet128(1,0)
				end
			end
		end
	end
	if (weap == 9 or auxi.has_have_coll(player,395)) then
		if auxi.inner_tick(player:GetData(),item.own_key.."TechX_counter",5,{Update = true,}) then
			local q = player:FireTechXLaser(pos,Vector(0,0),40 * range_mul + 20,nil,charge) q.PositionOffset = Vector(0,0) q:SetTimeout(15) 
		end
	end
end

function item.spawn_terminal_light_burst(player,pos,reflection_count,tearHitParams,params)
	params = params or {}
	reflection_count = math.max(0,math.floor(tonumber(reflection_count) or 0))
	tearHitParams = tearHitParams or player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
	local scale_mul = math.max(0.05,tonumber(params.scale) or 1)
	local dmg_mul = math.max(0,tonumber(params.dmg_mul) or 1)
	local damage = tearHitParams.TearDamage * (0.75 + 0.35 * reflection_count) * dmg_mul
	local radius = (60 + 12 * reflection_count) * scale_mul
	for _,v in ipairs(Isaac.GetRoomEntities()) do
		if auxi.isenemies(v) and (v.Position - pos):Length() <= radius + (v.Size or 0) then
			v:TakeDamage(damage,0,EntityRef(player),0)
		end
	end
	local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,16,3,pos,Vector(0,0),player):ToEffect()
	if q then
		-- 1000.016_Poof02_B_Blood.anm2 的有效帧相对 Pivot 最大不透明半径约为 133.96 px。
		local scale = radius/133.96
		q.CollisionDamage = 0
		local s = q:GetSprite()
		s.Scale = Vector(scale,scale)
		local color = auxi.check_lerp((reflection_count * 6) % item.Colorinfo.total,item.Colorinfo)
		s.Color = auxi.UpColor(color,1)
		q.DepthOffset = -5
	end
	if params.nosound ~= true then
		SFXManager():Play(SoundEffect.SOUND_LIGHTBOLT_CHARGE,math.min(1,0.55 + 0.45 * scale_mul),0,false,1)
	end
end

function item.control_impale(player,ent,params)
	local d = ent:GetData()
	local cnt = d[item.own_key.."Impale"].id or 0
	local tbl = d[item.own_key.."Impale"].tbl
	local ret = {}
	local nowpos = auxi.ProtectVector(ent.Position)
	local ang = nil
	local laser,espear = item.get_laser_pair(ent)
	if not (laser and espear) then return {End = true,} end
	local dir1 = laser.Angle local dir2 = nil
	local d2 = laser:GetData()
	local laserdata = d2[item.own_key.."laser"] or {}
	local lid = (laserdata.layer or 0)/math.max(1,laserdata.mxlayer or 0)
	local segment_level = laserdata.segment_level or math.max(0,(laserdata.reflection_count or laserdata.mxlayer or 0) - (laserdata.layer or 0))
	local info = tbl[cnt + 1]
	local wallpos = nil
	while(info) do
		cnt = cnt + 1
		if info.skip == nil then ent.Position = info.pos break 
		else
			local tlaser = d2[item.own_key.."Linked_Laser"]
			espear:GetData()[item.own_key.."Linked_Laser"] = d2[item.own_key.."Linked_Laser"]
			if auxi.check_exists(tlaser) then 
				if tlaser:GetData()[item.own_key.."laser"] then	tlaser:GetData()[item.own_key.."laser"].linker = espear end
				dir2 = tlaser.Angle
				d[item.own_key.."Impale"].tbl = item.get_cutting_info(tbl,tlaser)
			end
			tbl.res_length = (tbl.res_length or item.res_length) + player.ShotSpeed * 3		--根据弹速逐渐加速
			if d2[item.own_key.."laser"] then d2[item.own_key.."laser"].RemoveNow = true end
			wallpos = auxi.ProtectVector(info.pos or ent.Position)
			d[item.own_key.."Impale"].step_id = 0
		end
		info = tbl[cnt + 1]
	end
	
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if desc.Data.Type == 16 then ent.Position = Game():GetRoom():GetClampedPosition(ent.Position,10) end
	
	d[item.own_key.."Impale"].step_id = (d[item.own_key.."Impale"].step_id or 0) + 1
	local move_dir = ent.Position - nowpos
	local seg = tbl[cnt]
	local face_dir
	if seg and seg.dir and seg.dir:Length() > 0.001 then
		face_dir = seg.dir:Normalized()
	elseif move_dir:Length() > 0.001 then
		face_dir = move_dir:Normalized()
	else
		face_dir = d[item.own_key.."record_dir"] or Vector(0, 1)
		if face_dir:Length() > 0.001 then face_dir = face_dir:Normalized() else face_dir = Vector(0, 1) end
	end
	d[item.own_key.."record_dir"] = auxi.ProtectVector(face_dir)
	local imp = d[item.own_key.."Impale"]
	local pivot_pos = ent.Position
	local step_len
	if imp and imp.last_pivot then
		step_len = (pivot_pos - imp.last_pivot):Length()
	end
	if not step_len or step_len <= 0.001 then
		step_len = math.abs(move_dir:Dot(face_dir))
	end
	if step_len <= 0.001 then
		step_len = tonumber((imp and imp.tbl or {}).res_length) or item.res_length or 60
	end
	if imp then imp.last_pivot = pivot_pos end
	-- 朝向用段 dir；间距用光路 pivot 点距（宝宝脚底回退时不污染 dis）
	local dir = face_dir * step_len
	local best_dir = face_dir
	local dang = nil
	if wallpos and dir1 and dir2 then 
		local ddir1 = dir1 + 180
		dang = math.max(25,math.abs(auxi.checkrounded(ddir1,dir2,-1,1,360) * 0.5))
		local dangle = ddir1 + auxi.checkrounded(ddir1,dir2,-1,1,360) * 0.5
		best_dir = auxi.MakeVector(dangle + 180)
	end
	local tearHitParams = params.tearHitParams or player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
	local tearflags = (params.tearflags or BitSet128(0,0)) | tearHitParams.TearFlags
	local tearcolor = params.color or params.tearcolor or tearHitParams.TearColor
	local charge = params.charge or d[item.own_key.."Impale"].charge or 1
	local dmg = tearHitParams.TearDamage * 0.5 * (params.dmgmul or 1) * (params.dmgrate or 1) * math.sqrt(charge)
	
	if wallpos then
		if params.main then 
			local room = Game():GetRoom()
			local gent = room:GetGridEntityFromPos(wallpos) 
			if gent and gent:ToDoor() and gent:ToDoor():IsOpen() then 
				teleport_holder.try_leave_room(gent:ToDoor(),player)
			end
			
			if dir1 and dir2 and (tearflags & BitSet128(1<<19,0) == BitSet128(1<<19,0)) then
				local ddir1 = dir1 + 180
				local dangle = ddir1 + auxi.checkrounded(ddir1,dir2,-1,1,360) * 0.5
				local q = item.fire_tecro_phantom(player,wallpos + auxi.MakeVector(dangle) * 20,Vector(0,0),{dir = auxi.MakeVector(dangle),layer = 0,charge = charge,})
			end
			if dir1 and (tearflags & BitSet128(1<<38,0) == BitSet128(1<<38,0)) then
				local alpha = auxi.dichotomy_search(function(val) return not Game():GetRoom():IsPositionInRoom(wallpos - auxi.MakeVector(dir1) * val,-200) end,200,1000)
				local q = item.fire_tecro_phantom(player,wallpos - auxi.MakeVector(dir1) * alpha,Vector(0,0),{dir = auxi.MakeVector(dir1),layer = 0,margin = -300,cross = "ContInfo",charge = charge * 0.5,})	--((d2[item.own_key.."laser"] or {}).mxlayer or 1)	--!!
			end
		end
		if dir1 and dir2 then
			local ddir1 = dir1 + 180
			local dangle = ddir1 + auxi.checkrounded(ddir1,dir2,-1,1,360) * 0.5
			if auxi.has_have_coll(player,495) or auxi.has_have_coll(player,616) then
				local both = auxi.has_have_coll(player,495) and auxi.has_have_coll(player,616)
				if auxi.has_have_coll(player,495) and auxi.check_rand(player.Luck,50,10,10) then
					local q = Isaac.Spawn(1000,EffectVariant.BLUE_FLAME,0,wallpos,auxi.MakeVector(dangle) * player.ShotSpeed * 10,player):ToEffect()
					q:SetTimeout(60)
					q.LifeSpan = 60
					q.CollisionDamage = dmg * 4 * 0.5
				elseif auxi.has_have_coll(player,616) and ((both and auxi.check_rand(player.Luck,100,10,10)) or auxi.check_rand(player.Luck,50,10,10)) then
					local q = Isaac.Spawn(1000,EffectVariant.RED_CANDLE_FLAME,0,wallpos,auxi.MakeVector(dangle) * player.ShotSpeed * 10,player):ToEffect()
					q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
					q.CollisionDamage = dmg * 3 * 0.5
				end
			end
		end
	end
	
	d[item.own_key.."Impale"].id = cnt
	local ctinfo = tbl[math.min(#tbl,cnt + 1)]
	d[item.own_key.."Impale"].tgpos = ctinfo.pos
	if cnt >= #(d[item.own_key.."Impale"].tbl) then ret.End = true end
	
	if wallpos then --ret.End then
		local q = Isaac.Spawn(1000,16,3,ent.Position,Vector(0,0),player):ToEffect()
		q.DepthOffset = -5
		local effect_scale = math.max(0.05,tonumber(params.effect_scale) or 1)
		if effect_scale ~= 1 then
			-- 与 _anna_effect 一致：压 Scale.X（沿前进），保留 Scale.Y（横向宽度）
			local s = q:GetSprite()
			s.Scale = Vector(s.Scale.X * effect_scale, s.Scale.Y)
		end
		--local q = Isaac.Spawn(1000,16,0,ent.Position,Vector(0,0),player):ToEffect() q.DepthOffset = -5
	end
	
	if params.main and ret.End and (tearflags & BitSet128(1<<62,0) == BitSet128(1<<62,0)) then
		local rnd = auxi.choose(1,2)
		for i = 1,rnd do local q = item.fire_tecro_phantom(player,Game():GetRoom():GetClampedPosition(ent.Position,5),Vector(0,0),{dir = auxi.random_r(),layer = 1,margin = -50,charge = charge * 0.5,}) end
	end
	
	item.attack_impale(player,ent,ent.Position,nil,{
		Rotation = dir:GetAngleDegrees(),
		dir = dir,
		dang = dang,
		best_dir = best_dir,
		wallpos = wallpos,
		lid = lid,
		cnt = cnt,
		End = ret.End,
		charge = params.charge or d[item.own_key.."Impale"].charge or 1,
		main = params.main,
		segment_level = segment_level,
		dmgmul = params.dmgmul,
		rangerate = params.rangerate,
		nosound = params.nosound,
		effect_scale = params.effect_scale,
	})
	if params.main and ret.End and not d[item.own_key.."Impale"].terminal_burst_done then
		d[item.own_key.."Impale"].terminal_burst_done = true
		item.spawn_terminal_light_burst(player,ent.Position,d[item.own_key.."Impale"].reflection_count or laserdata.reflection_count or laserdata.mxlayer or 0,tearHitParams)
	end
	if params.terminal_burst and ret.End and not d[item.own_key.."Impale"].terminal_burst_done then
		d[item.own_key.."Impale"].terminal_burst_done = true
		item.spawn_terminal_light_burst(
			player,
			ent.Position,
			d[item.own_key.."Impale"].reflection_count or laserdata.reflection_count or laserdata.mxlayer or 0,
			tearHitParams,
			{scale = params.effect_scale or 0.45,dmg_mul = params.dmgmul or 0.35}
		)
	end
	
	ret.dir = face_dir ret.pos = ent.Position
	if desc.Data.Type == 16 and ret.End then ent.Position = Game():GetRoom():FindFreeTilePosition(ent.Position,20) end
	
	return ret
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if player:GetPlayerType() == item.entity then
		local d = player:GetData()
		if d[item.own_key.."room_epoch"] ~= (item._room_epoch or 0) then
			d[item.own_key.."room_epoch"] = item._room_epoch or 0
			if d[item.own_key.."Impale"] then item.end_impale(player) end
			if d[item.own_key.."Ludopos"] then d[item.own_key.."Ludopos"] = player.Position end
		end
		local s = player:GetSprite()
		local ctrlid = player.ControllerIndex
		local gdir = auxi.ggdir(player,true,false,false,nil,{real = true})
		d.now_dir = d.now_dir or Vector(0,1)
		gdir = check_mouse_work(player,gdir) or gdir
		d.check_dir = gdir
		if auxi.check_all_exists(d.linked_spear) ~= true then
			d.linked_spear = auxi.fire_laser_spear(nil,nil,{player = player,dir = d.now_dir:GetAngleDegrees(),})
			d.linked_spear:GetData()[item.own_key.."spear"] = {}
			d.Tecro_list = auxi.get_Tecro_list(player)
		end
		d.Tecro_list = d.Tecro_list or auxi.get_Tecro_list(player)
		
		d.now_rot_vel = d.now_rot_vel or 0
		d.Tecro_spear_state = d.Tecro_spear_state or 0
		local angle = d.now_dir:GetAngleDegrees()
		local dir = d.linked_spear:GetData().on_record_spear_dir or d.now_dir or Vector(0,1)
		
		local rot = get_rot_dis(gdir,"rot")
		local dis = get_rot_dis(gdir,"dis")
		local alpha = player.ShotSpeed * 3 + 4						--alpha 就是旋转速度上限
		if d.Tecro_spear_state == -1 then alpha = alpha * 1.3 end
		if d.Tecro_spear_state == 1 then alpha = alpha * 0.6 end
		
		if math.abs(d.now_rot_vel * rot) > 0.5 then
			if rot * d.now_rot_vel > 0 then d.now_rot_vel = d.now_rot_vel * 0.9 + rot * alpha * 0.1
			else d.now_rot_vel = d.now_rot_vel * 0.4 + rot * alpha * 0.1 end
		else
			if rot == 0 then d.now_rot_vel = d.now_rot_vel * 0.8
			else d.now_rot_vel = rot * alpha * 0.1 end
		end
		d.now_rot_set = rot
		d.now_vel_alpha = math.max(0.001,alpha)
		
		d[item.own_key.."_Charge_Bar_buff"] = (d[item.own_key.."_Charge_Bar_buff"] or 0)
		d[item.own_key.."_Charge_Bar_buff_mx"] = item.get_max_delay(player)
		
		local mxn = item.get_mx_delay(player)
		d.now_flip = d.now_flip or 1
		if dis > 0 then							--钃勫姏
			d.now_flip = -1
			if auxi.g_dir_can_work(player) then
				if d.Tecro_spear_state <= 0 then
					d[item.own_key.."_Charge_Bar_buff"] = math.min(d[item.own_key.."_Charge_Bar_buff_mx"] * mxn,d[item.own_key.."_Charge_Bar_buff"] + 1)
					if (d.Tecro_list.nepton or 0) > 0 then d[item.own_key.."_Charge_Bar_buff"] = math.max(d[item.own_key.."_Charge_Bar_buff"],d.Tecro_spear_nep_Charge_Bar_buff or 0) d.Tecro_spear_nep_Charge_Bar_buff = 0 end
					if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ANTI_GRAVITY) then
						d[item.own_key.."anti_counter_Charge_Bar_buff"] = (d[item.own_key.."anti_counter_Charge_Bar_buff"] or 0) + 1
						if d[item.own_key.."anti_counter_Charge_Bar_buff"] >= item.anti_mul * mxn * d[item.own_key.."_Charge_Bar_buff_mx"] then
							local q = item.fire_tecro_phantom(player,player.Position,Vector(0,0),{dir = d.now_dir,layer = item.get_layer_multi(player),wait = item.wait_time(player),})
							d[item.own_key.."anti_counter_Charge_Bar_buff"] = 0
						end
					elseif d[item.own_key.."anti_counter_Charge_Bar_buff"] then d[item.own_key.."anti_counter_Charge_Bar_buff"] = nil end
				else d[item.own_key.."_Charge_Bar_buff"] = 0 end
				d.Tecro_spear_state = -1
			end
			local rate = (d[item.own_key.."_Charge_Bar_buff"]/d[item.own_key.."_Charge_Bar_buff_mx"])
			d[item.own_key.."record_rate"] = rate
		else
			d.now_flip = 1
			if auxi.g_dir_can_work(player) then
				local layercnt = item.get_layer_multi(player)
				local rate = d[item.own_key.."record_rate"] or 1
				local now_layer = math.floor(rate * layercnt)
				if (d.Tecro_spear_state == 0 or d.Tecro_spear_state == -1) then
					if rate * layercnt > 0.5 then
						item.start_impale(player)
						if d[item.own_key.."Impale"] then
							d.Tecro_spear_state = 1
							d[item.own_key.."Impale"].charge = rate
							local CharacterFamiliars = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")
							CharacterFamiliars.dispatch_registered_copies(player, {
								aim_dir = d.now_dir,
								damage_mul = rate,
							})
							--d[item.own_key.."Phantom_spear"] = d[item.own_key.."Phantom_spear"] or {}
							local multishot_of_player = auxi.get_Tecrorun_multishots(player,nil,{allowrand = true,cnt1 = 0,})		--d.Tecro_list
							for u,v in pairs(multishot_of_player) do
								local pos = d[item.own_key.."Ludopos"] or player.Position
								local q = item.fire_tecro_phantom(player,pos,Vector(0,0),{dir = auxi.get_by_rotate(d.now_dir,v.dir or 0),Addtearflags = v.tearflags,layer = now_layer,margin = -30,cross = v.cross,})
								--table.insert(d[item.own_key.."Phantom_spear"],q)
							end
							d[item.own_key.."Csection"] = {counter = rate * 300,}
						end
					end
					d[item.own_key.."_Charge_Bar_buff"] = 0
					d[item.own_key.."record_rate"] = 0
				end
			end
			if d[item.own_key.."anti_counter_Charge_Bar_buff"] then d[item.own_key.."anti_counter_Charge_Bar_buff"] = nil end
		end
		if dis < 0 then d.now_dir_set_on = true
		else d.now_dir_set_on = nil end
		
		for i = 1,1 do if auxi.has_have_coll(player,329) then
			local ctrlidx = player.ControllerIndex
			local room = Game():GetRoom()
			if dis < 0 then d[item.own_key.."Ludopos"] = room:GetClampedPosition((d[item.own_key.."Ludopos"] or player.Position) + dir:Normalized() * 5 * player.ShotSpeed,0)
			elseif Input.IsActionTriggered(ButtonAction.ACTION_DROP,ctrlidx) or Input.IsActionPressed(ButtonAction.ACTION_DROP,ctrlidx) then if d[item.own_key.."Ludopos"] == nil then break end
				d[item.own_key.."Ludopos"] = d[item.own_key.."Ludopos"] * 0.5 + player.Position * 0.5
				if (d[item.own_key.."Ludopos"] - player.Position):Length() < 30 then d[item.own_key.."Ludopos"] = nil end
			end
		elseif d[item.own_key.."Ludopos"] then d[item.own_key.."Ludopos"] = nil end end
		
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_TECH_5) and d[item.own_key.."_Charge_Bar_buff"] > 0 and auxi.inner_tick(player:GetData(),item.own_key.."Tech_5_counter",10,{Update = true,}) then Tech_5_holder.work_on_tech_5(player,{dir = d.now_dir,}) end
		if d[item.own_key.."Impale"] then
			if d[item.own_key.."Ludopos"] then
				local sent = d.linked_spear.Parent
				if auxi.check_all_exists(sent) then
					d[item.own_key.."LudoCtrl"] = {linker = sent,}
					sent:GetData()[item.own_key.."Impale"] = d[item.own_key.."Impale"] d[item.own_key.."Impale"] = nil
				end
			else
				player:SetMinDamageCooldown(math.max(0,3 - player:GetDamageCooldown()))
				player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
				if d[item.own_key.."gridcollision_succ"] == nil then d[item.own_key.."gridcollision_succ"] = Attribute_holder.try_hold_attribute(player,"GridCollisionClass",EntityGridCollisionClass.GRIDCOLL_NONE) end
				if d[item.own_key.."entitycollision_succ"] == nil then d[item.own_key.."entitycollision_succ"] = Attribute_holder.try_hold_attribute(player,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE) end
				local ret = item.control_impale(player,player,{main = true,}) or {}
				if ret.End then 
					item.end_impale(player)
					player.Position = Game():GetRoom():GetClampedPosition(player.Position,0)
				end
			end
		end
		
		if d[item.own_key.."LudoCtrl"] then
			if auxi.check_all_exists(d[item.own_key.."LudoCtrl"].linker) and d[item.own_key.."LudoCtrl"].linker:GetData()[item.own_key.."Impale"] then
				local ret = item.control_impale(player,d[item.own_key.."LudoCtrl"].linker,{main = true,}) or {}
				d[item.own_key.."Ludopos"] = ret.pos
				if ret.End then item.end_impale(player,{NoDmg = true,}) d[item.own_key.."LudoCtrl"].linker:GetData()[item.own_key.."Impale"] = nil d[item.own_key.."LudoCtrl"] = nil end
			else item.end_impale(player,{NoDmg = true,}) d[item.own_key.."LudoCtrl"] = nil end
		end
		if d[item.own_key.."Csection"] then
			d[item.own_key.."Csection"].counter = (d[item.own_key.."Csection"].counter or 300) - 1
			if d[item.own_key.."Csection"].counter < 0 then d[item.own_key.."Csection"] = nil end
		end
		
		d.now_dir = auxi.MakeVector(angle + d.now_rot_vel)
	end
end,
})

function item.end_impale(player,params)
	params = params or {}
	local d = player:GetData()
	if params.NoDmg ~= true then
		Attribute_holder.try_hold_and_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,30 - player:GetDamageCooldown(),Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK))
		player:SetMinDamageCooldown(math.max(0,30 - player:GetDamageCooldown()))
	end
	d[item.own_key.."Impale"] = nil d.Tecro_spear_state = 0 
	if d[item.own_key.."gridcollision_succ"] then Attribute_holder.try_rewind_attribute(player,"GridCollisionClass",d[item.own_key.."gridcollision_succ"]) d[item.own_key.."gridcollision_succ"] = nil end
	if d[item.own_key.."entitycollision_succ"] then Attribute_holder.try_rewind_attribute(player,"EntityCollisionClass",d[item.own_key.."entitycollision_succ"]) d[item.own_key.."entitycollision_succ"] = nil end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item._room_epoch = (item._room_epoch or 0) + 1
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_RENDER, params = nil,
Function = function(_,ent,offset)
	if ent.Variant == enums.Entities.Tecro_Laser_Spear then
		local d = ent:GetData()
		local s = ent:GetSprite()
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			local player = CharacterAttackCompat.resolve_entity_player(ent, d.player)
			if not player then return end
			local d2 = player:GetData()
			local list = d2.Tecro_list or {}
			
			if d.Tecro_linked_godhead then d.Tecro_linked_godhead:Render(Isaac.WorldToScreen(ent.Position),Vector(0,0),Vector(0,0)) end
			if d.Tecro_linked_salva then d.Tecro_linked_salva:Render(Isaac.WorldToScreen(ent.Position),Vector(0,0),Vector(0,0)) end
			if d.Tecro_linked_censer then d.Tecro_linked_censer:Render(Isaac.WorldToScreen(ent.Position),Vector(0,0),Vector(0,0)) end
			if d.Tecro_linked_charming then d.Tecro_linked_charming:Render(Isaac.WorldToScreen(ent.Position),Vector(0,0),Vector(0,0)) end
			if d.Tecro_linked_charming_2 then d.Tecro_linked_charming_2:Render(Isaac.WorldToScreen(ent.Position),Vector(0,0),Vector(0,0)) end
			
			if d.head == nil then 
				d.head = Sprite() 
				d.head:Load("gfx/player/tecro/_Tecro_Spear.anm2",true)
				d.head:Play("IdleHead",true)
			end
			local cnt = (d.tecro_remove_cnt or 1)
			if (list.anti or 0) > 0 and d.Tecro_anti_counter == nil then cnt = 1 end
			local t_color = d.Tecro_this_color or player.TearColor
			d.head.Color = auxi.AddColor(t_color,Color(0,0,0,0),cnt,1 - cnt)
			d.head.Rotation = s.Rotation --+ ent.RotationOffset
			d.head:Render(Isaac.WorldToScreen(ent.Position),Vector(0,0),Vector(0,0))
			
			if (list.deadeye or 0) > 0 then
				local alpha = math.min(1,(d2.Tecro_dead_eye_total_counter or 0)/6) * 0.5
				local s2 = d.tecro_dead_eye_sprite or Sprite()
				s2:Load("gfx/mimics/Dead_Eye/dead_eye_effect.anm2",true)
				s2:Play("Idle",true)
				s2.Color = Color(1,1,1,alpha)
				s2:Render(Isaac.WorldToScreen(ent.Position),Vector(0,0),Vector(0,0))
				d.tecro_dead_eye_sprite = s2
			end
		end
	end
end,
})

function item.find_dir(pos,dir)
	local room = Game():GetRoom()
	local center = auxi.get_near_grid_position(pos)--room:GetGridPosition(room:GetGridIndex(pos))
	local ddir = pos - center
	local ret = dir
	local epsl = 0.0001
	if math.abs(ddir.X) > epsl and math.abs(ddir.Y) < epsl then ret = Vector(ret.X,-ret.Y)
	elseif math.abs(ddir.Y) > epsl and math.abs(ddir.X) < epsl then ret = Vector(-ret.X,ret.Y)
	else
		local succ = 0
		for u,v in pairs({Vector(-ret.X,-ret.Y),Vector(ret.X,-ret.Y),Vector(-ret.X,ret.Y),}) do
			for uu,vv in pairs({40,1}) do if room:IsPositionInRoom(pos + v * vv,-20) then succ = succ + 1 ret = v break end end
		end
		if succ == 3 then ret = Vector(-ret.X,-ret.Y) end
	end
	return ret
end

function item.fire_tecro_laser(pos,player,dir,params)
	player = CharacterAttackCompat.resolve_entity_player(nil, player)
	if not player then return nil end
	params = params or {}
	local tearhitparams = params.tearhitparams or player:GetTearHitParams(WeaponType.WEAPON_LASER,1,auxi.choose(0,-1))
	local tearflags = params.tearflags or tearhitparams.TearFlags
	if params.Addtearflags then tearflags = tearflags | params.Addtearflags end
	local basecolor = auxi.color2table(params.color or tearhitparams.TearColor)
	SFXManager():Play(SoundEffect.SOUND_REDLIGHTNING_ZAP_WEAK,0,2,false,1)
	SFXManager():SetAmbientSound(SoundEffect.SOUND_REDLIGHTNING_ZAP_WEAK,0,1)
	local q = player:FireTechLaser(pos,0,dir,false,false,player,0)
	SFXManager():SetAmbientSound(SoundEffect.SOUND_REDLIGHTNING_ZAP_WEAK,0,1)
	q.CollisionDamage = 0
	local dummy = Isaac.Spawn(EntityType.ENTITY_SHOPKEEPER,0,0,Vector(0,0),Vector(0,0),nil)
	dummy.Visible = false q.Parent = dummy dummy:Remove() 
	q.SpawnerEntity = nil q.Mass = 0 q.DisableFollowParent = true q:SetTimeout(-1)
	q:GetData().check_spawner_player_record = player
	q.TearFlags = tearflags | TearFlags.TEAR_SPECTRAL
	q.TearFlags = q.TearFlags & ~(BitSet128(1<<6,0) | BitSet128(1<<19,0) | BitSet128(1<<38,0) | BitSet128(1<<55,0) | BitSet128(1<<58,0)| BitSet128(1<<59,0) | (params.banishedtearflag or BitSet128(0,0)))
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	q.PositionOffset = params.PositionOffset or Vector(0,0)
	local s = q:GetSprite()
	s.Color = auxi.table2color(basecolor)
	s:Load("gfx/player/tecro/tecro_laser.anm2",true)
	for i = 0,1 do s:ReplaceSpritesheet(i,"gfx/effects/lasers/tecro_laser_brimstone.png") end s:LoadGraphics() 
	s:Play("Laser0",true)
	for i = 1,2 do q:Update() SFXManager():SetAmbientSound(SoundEffect.SOUND_REDLIGHTNING_ZAP_WEAK,0,1) end
	SFXManager():Stop(SoundEffect.SOUND_REDLIGHTNING_ZAP_WEAK)
	SFXManager():Stop(SoundEffect.SOUND_REDLIGHTNING_ZAP)
	local d = q:GetData()
	d[item.own_key.."laser"] = {basecolor = basecolor,base_scale = auxi.ProtectVector(s.Scale),Addtearflags = params.Addtearflags,segment_level = 0,reflection_count = 0,}
	return q
end

function item.dichotomy_search_in_room(pos,dir,params)
	params = params or {}
	params.margin = params.margin or -20
	params.st = params.st or 0.5
	params.ed = params.ed or 200
	local room = Game():GetRoom()
	if not room:IsPositionInRoom(pos + params.st * dir,params.margin) then return pos end
	while(room:IsPositionInRoom(pos + params.ed * dir,params.margin)) do
		params.st = params.ed
		params.ed = params.ed + 200
	end
	while(params.ed - params.st > (params.epsl or 0.1)) do
		local mid = (params.ed + params.st) * 0.5
		if room:IsPositionInRoom(pos + mid * dir,params.margin) then params.st = mid 
		else params.ed = mid end
	end
	return params.st * dir + pos
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = 50,
--table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 50,
Function = function(_,ent)
	local d = ent:GetData()
	--if d[item.own_key.."laserend"] then
	if ent.Parent and ent.Parent:GetData()[item.own_key.."laser"] then
		local s = ent:GetSprite()
		if d[item.own_key.."effect"] == nil then
			s.Color = Color(1,1,1,0)
			s:Load("gfx/player/tecro/tecro_laser_cross.anm2",true)
			s:Play("Idle",true)
			d[item.own_key.."effect"] = {}
		end
		local laserdata = ent.Parent:GetData()[item.own_key.."laser"]
		local alpha = item.get_segment_preview_alpha(laserdata.segment_level or 0,laserdata.reflection_count or laserdata.mxlayer or 0)
		local color = auxi.check_lerp(((laserdata.segment_level or 0) * 6) % item.Colorinfo.total,item.Colorinfo)
		s.Color = auxi.MulColor(auxi.UpColor(color,1),Color(1,1,1,alpha,1,1,1))
		if auxi.check_exists(ent.Parent) ~= true then ent:Remove() return end
		--if auxi.check_all_exists(ent.Parent) ~= true then ent:Remove() return end
		--if auxi.check_all_exists(d[item.own_key.."laserend"].linker) ~= true then ent:Remove() return end
	end
end,
})
--l local desc = Game():GetLevel():GetCurrentRoomDesc() print(desc.Flags)
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_INIT, params = 2,
Function = function(_,ent)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = 2,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."laser"] then
		ent.CollisionDamage = 0
		local laserdata = d[item.own_key.."laser"]
		local lcnt = laserdata.layer or 0
		local segment_level = laserdata.segment_level or math.max(0,(laserdata.reflection_count or laserdata.mxlayer or 0) - lcnt)
		local reflection_count = laserdata.reflection_count or laserdata.mxlayer or 0
		local player = auxi.check_spawner_player(ent)
		local s = ent:GetSprite()
		s:Play("Laser0")
		local _,width_multiplier = item.get_segment_multipliers(segment_level)
		local base_scale = laserdata.base_scale or Vector(1,1)
		s.Scale = Vector(base_scale.X,base_scale.Y * width_multiplier)
		if d[item.own_key.."laser"].wait then
			local waitinfo = d[item.own_key.."laser"].wait
			ent.Position = waitinfo.pos
			ent.Angle = waitinfo.ang
			if waitinfo.po then ent.PositionOffset = waitinfo.po end
		end
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		if desc.Flags & (1<<15) == 1<< 15 then		--!!简单处理了一下，但效果不好，教条房间还需要继续处理。
			local st = 0.5 if Game():GetRoom():IsPositionInRoom(ent.Position,0) ~= true then st = 40 end
			local tpos = item.dichotomy_search_in_room(ent.Position,auxi.MakeVector(ent.Angle),{st = st,})
			ent:SetMaxDistance((tpos - ent.Position):Length())
		end
		local tpos = ent:GetEndPoint()
		local reflect = ent.TearFlags & BitSet128(1<<8,0) == BitSet128(1<<8,0)
		local not_invisible = reflect
		local dis_multiplier = 1
		local ang = d[item.own_key.."laser"].Angle or ent.Angle if reflect then ang = ang + 180 end
		--print(tostring(lcnt).." Find:")
		local tdir = item.find_dir(tpos,auxi.MakeVector(ang))
		local dir = auxi.MakeVector(ent.Angle)
		if auxi.check_exists(d[item.own_key.."laser"].linker) ~= true then ent:Remove() return end
		laserdata.basecolor = (laserdata.basecolor or auxi.color2table(s.Color))
		if (tpos - dir * 20 - ent.Position):Length() < 16 and not_invisible ~= true then s.Color = Color(1,1,1,0)
		elseif laserdata.Remove then
			laserdata.Removecounter = (laserdata.Removecounter or 1) * 0.8
			local rcnt = laserdata.Removecounter
			s.Color = auxi.MulColor(auxi.table2color(laserdata.basecolor),Color(1,1,1,rcnt,1,1,1))
		else
			local alpha = item.get_segment_preview_alpha(segment_level,reflection_count)
			s.Color = auxi.MulColor(auxi.table2color(laserdata.basecolor),Color(1,1,1,alpha,1,1,1))
		end
		if ent.TearFlags & BitSet128(0,1<<(121 - 64)) == BitSet128(0,1<<(121 - 64)) then
			d[item.own_key.."laser"].color_counter = ((d[item.own_key.."laser"].color_counter or math.random(item.Colorinfo.total)) + 1) % item.Colorinfo.total
			local rcolor = auxi.check_lerp(d[item.own_key.."laser"].color_counter,item.Colorinfo) rcolor = auxi.UpColor(rcolor) rcolor = auxi.MulColor(rcolor,Color(1,1,1,s.Color.A,1,1,1))
			s.Color = auxi.AddColor(s.Color,rcolor,0.5,0.5)
		end
		local tq = d[item.own_key.."Linked_Laser"]
		if lcnt > 0 then
			if auxi.check_exists(tq) ~= true then
				d[item.own_key.."Linked_Laser"] = item.fire_tecro_laser(tpos,player,tdir,{banishedtearflag = BitSet128(1<<8,0),})		--!!第二层之后镜子弹射在墙角的一个特定区域会发生反向，且找不到修复的方法，因此强制要求第二层以后镜子不生效。
				tq = d[item.own_key.."Linked_Laser"]
				local d3 = tq:GetData() 
				d3[item.own_key.."laser"].layer = (laserdata.layer or 0) - 1 d3[item.own_key.."laser"].mxlayer = reflection_count d3[item.own_key.."laser"].reflection_count = reflection_count d3[item.own_key.."laser"].segment_level = segment_level + 1 d3[item.own_key.."laser"].linker = ent
				if desc.Flags & (1<<15) == 1<< 15 then tq:SetMaxDistance(10) end
			end
			if auxi.check_exists(tq) then
				local d3 = tq:GetData()
				if d[item.own_key.."laser"].Remove then d3[item.own_key.."laser"].Remove = true end
				if d3[item.own_key.."laser"] then
					d3[item.own_key.."laser"].Angle = tdir:GetAngleDegrees() 
					d3[item.own_key.."laser"].layer = (laserdata.layer or 0) - 1
					d3[item.own_key.."laser"].mxlayer = reflection_count
					d3[item.own_key.."laser"].reflection_count = reflection_count
					d3[item.own_key.."laser"].segment_level = segment_level + 1
				end
				tq.Angle = tdir:GetAngleDegrees() --+ angle_addon
				tq.Position = tpos - tdir * 20 * dis_multiplier
				tq.DepthOffset = ent.DepthOffset
			end
		else
			if auxi.check_exists(tq) then tq:GetData()[item.own_key.."laser"].layer = 0 tq:GetData()[item.own_key.."laser"].RemoveNow = true end d[item.own_key.."Linked_Laser"] = nil
		end
		if d[item.own_key.."laser"].RemoveNow then ent:Remove() return end
		if d[item.own_key.."laser"].Remove and (d[item.own_key.."laser"].Removecounter or 0) < 0.01 then ent:Remove() return end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.TecroLaserNil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local room = Game():GetRoom()
	
	d.Tecro_inner_frame = (d.Tecro_inner_frame or 0) + 1
	if d.player and d.player:Exists() then
		local player = d.player
		local spear = d.spear
		if spear == nil then return end
		local d3 = spear:GetData()
		local d2 = player:GetData()
		d2.Tecro_spear_state = d2.Tecro_spear_state or 0
		d2.Tecro_spear_target = d2.Tecro_spear_target or {}
		local list = d2.Tecro_list or {}
		local tail = spear:GetData().tail
		local info = item.sprite_loader[(d3.spear_type or 1)] or item.sprite_loader[1]
		local init_pos = d3.birth_init_pos or d2[item.own_key.."Ludopos"] or player.Position
		local range = get_spear_range(player) 
		local dir = d2.now_dir or Vector(0,1)
		local postdir = dir
		for i = 1,1 do if spear.TearFlags & BitSet128(1<<16,0) == BitSet128(1<<16,0) or spear.TearFlags & BitSet128(0,1<<(69-64)) == BitSet128(0,1<<(69-64)) then
			if (d2.Tecro_spear_state == 1) then break end
			local charge = d3.record_spear_charge or d2.Tecro_spear_charge or 0.2
			d3.record_that_spear_charge = (d3.record_that_spear_charge or 0) * 0.9 + charge * 0.1
			d3.planet_flying_charge = (d3.planet_flying_charge or 0) + 10 * (d3.record_that_spear_charge + 1) * (d2.tecro_rev_counter or 1)
		end end
		dir = dir:Length() * auxi.MakeVector(dir:GetAngleDegrees() + (d3.planet_flying_charge or 0))
		for i = 1,1 do if d2.Tecro_spear_state == -1 and math.abs(d3.planet_flying_charge or 0) > 0.01 then 
			if d3.tecro_remove_then then break end
			local dir_angle = auxi.get_correct_angle(dir:GetAngleDegrees() - postdir:GetAngleDegrees())
			local mxag = dir_angle * 0.85
			if dir_angle > 0.01 then dir_angle = math.max(0,math.min(mxag,dir_angle - 5)) end
			if dir_angle < 0.01 then dir_angle = math.min(0,math.max(mxag,dir_angle + 5)) end
			d3.planet_flying_charge = dir_angle
		end end
		postdir = dir
		dir = dir:Length() * auxi.MakeVector(dir:GetAngleDegrees() + (d3.homing_flying_charge or 0))
		for i = 1,1 do if d2.Tecro_spear_state == -1 and math.abs(d3.homing_flying_charge or 0) > 0.01 then 
			if d3.tecro_remove_then then break end
			local dir_angle = auxi.get_correct_angle(dir:GetAngleDegrees() - postdir:GetAngleDegrees())
			local mxag = dir_angle * 0.85
			if dir_angle > 0.01 then dir_angle = math.max(0,math.min(mxag,dir_angle - 5)) end
			if dir_angle < 0.01 then dir_angle = math.min(0,math.max(mxag,dir_angle + 5)) end
			d3.homing_flying_charge = dir_angle
		end end
		
		local tg_pos = room:GetClampedPosition(init_pos + dir * range, - range * 1.3)
		local dis = (tg_pos - ent.Position)
		local ttg_pos = room:GetClampedPosition(init_pos + dir * range * (d2.Tecro_spear_charge or 0.2), - range * 1.3)
		if mouse_enabled(player) then
			ttg_pos = room:GetClampedPosition(init_pos + dir * math.min((math.max(0.1,(Input.GetMousePosition(true) - init_pos):Length()) - 30),range * 1.2) * (d2.Tecro_spear_charge or 0.2), - range * 1.3)
		end
		local ddis = (ttg_pos - ent.Position)
		local dir_vel = (d2.now_rot_vel or 0)
		local delta = math.abs(dir_vel)/(d2.now_vel_alpha or 1)
		local wait_me = false
		
		d3.tecro_dir_offset = d3.tecro_dir_offset or 0
		local ddir = dir:Length() * auxi.MakeVector(dir:GetAngleDegrees() + d3.tecro_dir_offset)
		d3.record_spear_dir = dir
		d3.record_spear_ddir = ddir
		for i = 1,1 do if d3.tecro_remove_then then	else
			if d2.Tecro_spear_state == 0 then			--正常
				if dis:Length() > get_spear_range(player,1) * 7 then 
					ent.Position = tg_pos
					ent.Velocity = ent.Velocity:Normalized() * player.ShotSpeed * 3
				else
					ent.Velocity = ent.Velocity * 0.5 + player.Velocity * 0.3 + dis:Normalized() * dis:Length() * 0.1 * math.sqrt(math.max(1,ent.Velocity:Length() * 0.4))
				end
			elseif d2.Tecro_spear_state == -1 then		--鍚戝悗
				if dis:Length() > get_spear_range(player,1) * 7 then 	
					ent.Position = init_pos
					ent.Velocity = ent.Velocity:Normalized() * player.ShotSpeed * 3
				else
					ent.Velocity = ent.Velocity * 0.3 + player.Velocity * 0.5 + dis:Normalized() * dis:Length() * 0.2 * math.sqrt(math.max(1,ent.Velocity:Length() * 0.4))
				end
				local layercnt = item.get_layer_multi(player)
				local rate = d2[item.own_key.."record_rate"] or 1
				local now_layer = math.floor(rate * layercnt)
				local tq = d[item.own_key.."Linked_Laser"]
				if auxi.check_exists(tq) ~= true and room:IsPositionInRoom(spear.Position,0) and rate * layercnt >= 0.5 then
					d[item.own_key.."Linked_Laser"] = item.fire_tecro_laser(ent.Position,player,dir)
					tq = d[item.own_key.."Linked_Laser"]
					local d3 = tq:GetData()
					d3[item.own_key.."laser"].layer = now_layer d3[item.own_key.."laser"].mxlayer = now_layer d3[item.own_key.."laser"].reflection_count = now_layer d3[item.own_key.."laser"].segment_level = 0 d3[item.own_key.."laser"].linker = ent
				end
				if tq then
					local laserdata = tq:GetData()[item.own_key.."laser"]
					laserdata.layer = now_layer laserdata.mxlayer = now_layer laserdata.reflection_count = now_layer laserdata.segment_level = 0
				end
			elseif d2.Tecro_spear_state == 1 then 		--瞬移
				local ddis = dis
				if d2[item.own_key.."Impale"] and d2[item.own_key.."Impale"].tgpos then ddis = (d2[item.own_key.."Impale"].tgpos - ent.Position) end
				if d[item.own_key.."Impale"] and d[item.own_key.."Impale"].tgpos then ddis = (d[item.own_key.."Impale"].tgpos - ent.Position) end
				ent.Position = init_pos
				ent.Velocity = player.Velocity
				spear:GetData().record_spear_dir = ddis + ent.Position - init_pos 
			end
			local tq = d[item.own_key.."Linked_Laser"]
			if auxi.check_exists(tq) then
				if d2.Tecro_spear_state == 0 or d2.Tecro_spear_state == -1 then
					tq.Angle = ddir:GetAngleDegrees()
					tq.Position = spear.Position
					tq.DepthOffset = 5
					if room:IsPositionInRoom(spear.Position,0) ~= true then 
						tq:GetData()[item.own_key.."laser"].Remove = true
						d[item.own_key.."Linked_Laser"] = nil
					end
				end
			end
		end	end
		
		if auxi.has_have_coll(player,152) then
			if d2.Tecro_spear_state == -1 then
				if auxi.check_all_exists(d[item.own_key.."Tech2Laser"]) then else 
					local q = player:FireTechLaser(spear.Position,0,dir,true,false,nil,0.13)
					q.TearFlags = q.TearFlags & (~TearFlags.TEAR_WAIT) q.PositionOffset = Vector(0,0) q.Parent = ent q:SetTimeout(-1)
					d[item.own_key.."Tech2Laser"] = q
				end
				if auxi.check_all_exists(d[item.own_key.."Tech2Laser"]) then local q = d[item.own_key.."Tech2Laser"]
					q.Position = spear.Position q.Angle = dir:GetAngleDegrees()
				end
			else
				if auxi.check_all_exists(d[item.own_key.."Tech2Laser"]) then local q = d[item.own_key.."Tech2Laser"]
					q:SetTimeout(1) d[item.own_key.."Tech2Laser"] = nil
				end
			end
		end
		
		if d2[item.own_key.."Record_spear_shot"] then d2[item.own_key.."Record_spear_shot"] = (d2[item.own_key.."Record_spear_shot"] or 0) - 1 if d2[item.own_key.."Record_spear_shot"] <= 0 then d2[item.own_key.."Record_spear_shot"] = nil end end
		dir = ddir
	else ent:Remove() end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if player:GetPlayerType() == item.entity or player:GetSprite():GetFilename() == "gfx/characters/reloader/Tecrorun.anm2" then
		if cacheFlag == CacheFlag.CACHE_FLYING then player.CanFly = true end
	end
	if player:GetPlayerType() == item.entity then
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_,ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if player and player:GetPlayerType() == item.entity then
		local d = player:GetData()
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CURSED_EYE) and not auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BLACK_CANDLE) then
			local rate = (d[item.own_key.."_Charge_Bar_buff"] or 0) / (item.get_max_delay(player) * item.get_mx_delay(player))
			if (d[item.own_key.."_Charge_Bar_buff"] or 0) > 0 and rate > 0 and rate < 1 then
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

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if ent ~= nil then
		local player = ent:ToPlayer()
		if player and player:GetPlayerType() == item.entity then
			local d = player:GetData()
			local dir = (d.now_dir or Vector(0,1))
			if Game():GetRoom():IsMirrorWorld() == true then dir = Vector(-dir.X,dir.Y) end
			local gdir = d.check_dir or Vector(0,0)
			if gdir:Length() > 0.05 then
				if item.dirs[button] then
					local info = item.dirs[button] or Vector(0,0)
					local val = info.X * dir.X + info.Y * dir.Y
					if (hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED) then
					elseif hook == InputHook.GET_ACTION_VALUE then
						if math.abs(gdir.Y) > 0.7 then
							return val
						else 
							return val * 0.01
						end
--						return val * (gdir.Y * gdir.Y + 0.01)			--有趣的参数
					end
				end
			else
				
			end
		end
	end
end,
})

--- Gello 等宝宝：从 origin 发射完整蓄力层数的 Phantom 穿刺；不推进玩家蓄力/Impale。
function item.fire_familiar_attack(player, request)
	request = request or {}
	if not player then return {fired = false} end
	local CharacterFamiliars = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")
	local origin = request.origin or (request.source and request.source.Position) or player.Position
	local aim = request.aim_dir or Vector(0, 1)
	if aim:Length() < 0.01 then aim = Vector(0, 1) else aim = aim:Normalized() end
	local mul = tonumber(request.damage_mul) or 0.75
	local layer = item.get_layer_multi(player)
	local flags = CharacterFamiliars.apply_familiar_tear_flags(player, BitSet128(0, 0))
	-- cnt1=1：与 Tecro 相同，默认 base=0 时无多发道具会得到空表，邪眼/Gello 等于空放。
	local multishot = auxi.get_Tecrorun_multishots(player, nil, {allowrand = true, cnt1 = 1})
	if not multishot or next(multishot) == nil then
		multishot = {{dir = 0}}
	end
	local spawned = {}
	for _, v in pairs(multishot) do
		local dir = auxi.get_by_rotate(aim, v.dir or 0)
		if not dir or dir:Length() < 0.01 then dir = aim end
		local q = item.fire_tecro_phantom(player, origin, Vector(0, 0), {
			dir = dir,
			Addtearflags = (v.tearflags or BitSet128(0, 0)) | flags,
			layer = layer,
			margin = -30,
			cross = v.cross,
			charge = mul,
		})
		if q and request.source then
			q.SpawnerEntity = request.source
			q.Parent = request.source
		end
		spawned[#spawned + 1] = q
	end
	return {
		fired = #spawned > 0,
		delay = player.MaxFireDelay,
		spawned = spawned,
	}
end

CharacterAttackCompat.register(item.entity, {
	key = "tainted_tecro",
	module = "Qing_Remaster_scripts.player.player_Tecrorun",
	advanced_familiars = true,
	familiar_attack = item.fire_familiar_attack,
	capabilities = {projectile = true, volley = true, charge = true, weapon_morph = true},
})

return item

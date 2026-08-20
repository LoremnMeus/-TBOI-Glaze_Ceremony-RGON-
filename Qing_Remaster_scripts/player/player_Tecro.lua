local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Fusion_Destiny = require("Qing_Remaster_scripts.challanges.Fusion_Destiny")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local qing_s_knife_holder = require("Qing_Remaster_scripts.callbacks.qing_s_knife_holder")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Wavering_Eyes = require("Qing_Remaster_scripts.items.Item_Wavering_Eyes")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local Damo_holder = require("Qing_Remaster_scripts.mimics.Damo_holder")
local Isaacs_Tear_holder = require("Qing_Remaster_scripts.mimics.Isaacs_Tear_holder")
local Flat_Stone_holder = require("Qing_Remaster_scripts.mimics.Flat_Stone_holder")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local player_Tecrorun = require("Qing_Remaster_scripts.player.player_Tecrorun")

local function get_impale_rate(player)
	local ret = auxi.get_sharp_rate(player) + (player:GetData().temp_sharp_rate or 0)
	return ret
end

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Players.Tecro,
	own_key = "Players_Tecro_",
	dirs = {
		[4] = Vector(-1,0),
		[5] = Vector(1,0),
		[6] = Vector(0,-1),
		[7] = Vector(0,1),
	},
	anims = {
		[4] = "HeadLeft",
		[5] = "HeadRight",
		[6] = "HeadUp",
		[7] = "HeadDown",
	},
	repelables = {
		[302] = true,
	},
	sharp_items = {
		[CollectibleType.COLLECTIBLE_THE_NAIL] = 1,
		[CollectibleType.COLLECTIBLE_PINKING_SHEARS] = 1,
		[CollectibleType.COLLECTIBLE_RAZOR_BLADE] = 1,
		[CollectibleType.COLLECTIBLE_BLOOD_RIGHTS] = 1,
		[CollectibleType.COLLECTIBLE_SCISSORS] = 1,
		[CollectibleType.COLLECTIBLE_GOLDEN_RAZOR] = 1,
		[CollectibleType.COLLECTIBLE_MEAT_CLEAVER] = 1,
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
		
		{name = "gfx/player/spears/Normal_Spear2.png",offset = 18,color = Color(1,1,1,1),check = function(player,info,ent) if ent:GetData()[player_Tecrorun.own_key.."spear"] then return true end end,
		},
		{name = "gfx/player/spears/Normal_Spear.png",offset = 18,color = Color(1,1,1,1),
		},								--正常
		{name = "gfx/player/spears/Sharp_Spear.png",offset = 0,color = Color(0.5,0.5,0.5,1),idlename = "IdleHead4",reversed_tail = true,check = function(player,info,ent)
			if ent.Variant == enums.Entities.Tecro_Needle then return true end
		end,},								--剖腹产附带
		
		--53--
	},
	Special_Des = {
		["zh"] = {
			["Item"] = {
				[CollectibleType.COLLECTIBLE_DR_FETUS] = {Name = "尖体炸弹",Description = "锋利到爆炸！",},
				[CollectibleType.COLLECTIBLE_MOMS_KNIFE] = {Name = "锐利的菜刀",Description = "锋利而完美！",},
				[CollectibleType.COLLECTIBLE_BRIMSTONE] = {Name = "硫磺利焰",Description = "锋利而华丽！",},
				[CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = {Name = "英灵神锋",Description = "锋利而优雅！",},
				[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {Name = "镭射利焰",Description = "锋利而喧嚣！",},
				[CollectibleType.COLLECTIBLE_TECH_X] = {Name = "镭射环刃",Description = "锋利而圆满！",},
				[CollectibleType.COLLECTIBLE_EPIC_FETUS] = {Name = "东风-XXXI",Description = "锋利而强盛！",},
				[CollectibleType.COLLECTIBLE_MAW_OF_VOID] = {Name = "虚空利刃",Description = "锋利而贪食！",},
				[CollectibleType.COLLECTIBLE_C_SECTION] = {Name = "限界飞针",Description = "锋利而敏锐！",},
				[CollectibleType.COLLECTIBLE_SACRIFICIAL_DAGGER] = {Name = "祭奠之利齿",Description = "锋利而喋血！",},
				[CollectibleType.COLLECTIBLE_ATHAME] = {Name = "祭奠之利刃",Description = "锋利而嗜血！",},
				[CollectibleType.COLLECTIBLE_BLOOD_OATH] = {Name = "刃之誓言",Description = "锋利而可怖！",},
				
				[CollectibleType.COLLECTIBLE_ANTI_GRAVITY] = {Name = nil,Description = "枪尖在空中漂浮",},
				[CollectibleType.COLLECTIBLE_CHOCOLATE_MILK] = {Name = nil,Description = "枪尖变得自由",},
				[CollectibleType.COLLECTIBLE_CURSED_EYE] = {Name = nil,Description = "枪尖的诅咒",},
				[CollectibleType.COLLECTIBLE_TRISAGION] = {Name = nil,Description = "枪尖引导神圣",},
				[CollectibleType.COLLECTIBLE_SALVATION] = {Name = nil,Description = "枪尖带来救济",},
				[CollectibleType.COLLECTIBLE_GODHEAD] = {Name = nil,Description = "枪尖象征上神",},
				[CollectibleType.COLLECTIBLE_IPECAC] = {Name = nil,Description = "枪尖带来爆破",},
				[CollectibleType.COLLECTIBLE_EYE_OF_BELIAL] = {Name = nil,Description = "枪尖如有恶魔",},
				[CollectibleType.COLLECTIBLE_THE_WIZ] = {Name = nil,Description = "出枪决不能偏！",},
				
				[CollectibleType.COLLECTIBLE_TECHNOLOGY_ZERO] = {Name = nil,Description = "这枪导电！",},
				[CollectibleType.COLLECTIBLE_JACOBS_LADDER] = {Name = nil,Description = "这枪导电？",},
				[CollectibleType.COLLECTIBLE_TECHNOLOGY_2] = {Name = nil,Description = "似乎可以用来改造枪尖？",},
				[CollectibleType.COLLECTIBLE_PONY] = {Name = nil,Description = "匹马单枪出重围",},
				[CollectibleType.COLLECTIBLE_WHITE_PONY] = {Name = nil,Description = "英风锐气敌胆寒",},
				[CollectibleType.COLLECTIBLE_MOMS_RAZOR] = {Name = "锐利的剃刀",Description = "刺破它们的血管",},
				[CollectibleType.COLLECTIBLE_KAMIKAZE] = {Name = nil,Description = "有趣...",},
				
				[CollectibleType.COLLECTIBLE_BIG_CHUBBY] = {Name = nil,Description = "你也喜欢尖锐么？",},
				[CollectibleType.COLLECTIBLE_LITTLE_CHUBBY] = {Name = nil,Description = "你也喜欢尖锐吧！",},
				
				[CollectibleType.COLLECTIBLE_CUPIDS_ARROW] = {Name = nil,Description = "箭矢犹锋",},
				[CollectibleType.COLLECTIBLE_SANGUINE_BOND] = {Name = nil,Description = "定要撕开一道裂口",},
				[CollectibleType.COLLECTIBLE_DARK_ARTS] = {Name = "暗锋寻踪",Description = "黑夜与枪共舞",},
				[CollectibleType.COLLECTIBLE_THE_NAIL] = {Name = nil,Description = "钉头还算锋利",},
				[CollectibleType.COLLECTIBLE_8_INCH_NAILS] = {Name = nil,Description = "钉头有些锋利",},
				[CollectibleType.COLLECTIBLE_SHARP_KEY] = {Name = "钥枪",Description = "锋利的...钥匙？",},
				[CollectibleType.COLLECTIBLE_SAGITTARIUS] = {Name = nil,Description = "象征锋利",},
				[CollectibleType.COLLECTIBLE_SPEAR_OF_DESTINY] = {Name = nil,Description = "閽濋攱",},
				[CollectibleType.COLLECTIBLE_DEAD_ONION] = {Name = nil,Description = "它在刺我舌头",},
				[CollectibleType.COLLECTIBLE_SMB_SUPER_FAN] = {Name = nil,Description = "旋转利刃",},
				[CollectibleType.COLLECTIBLE_SCREW] = {Name = "尖头螺丝",Description = "确实是尖头啦",},
				[CollectibleType.COLLECTIBLE_GUILLOTINE] = {Name = "国王快乐台",Description = "也对资本家特攻",},
				[CollectibleType.COLLECTIBLE_SCISSORS] = {Name = nil,Description = "该怎么在另一端操控呢？",},
				[CollectibleType.COLLECTIBLE_PINKING_SHEARS] = {Name = nil,Description = "剪刀可以是枪吗？",},
				[CollectibleType.COLLECTIBLE_MOMS_HEELS] = {Name = "足刃",Description = "讲真，我喜欢这个",},
				
				[CollectibleType.COLLECTIBLE_LEAD_PENCIL] = {Name = nil,Description = "尖而不利",},
				[CollectibleType.COLLECTIBLE_VENTRICLE_RAZOR] = {Name = nil,Description = "只能用来划开肉壁",},
				[CollectibleType.COLLECTIBLE_TOOTH_AND_NAIL] = {Name = nil,Description = "理论上，这也是刺",},
				[CollectibleType.COLLECTIBLE_STAPLER] = {Name = nil,Description = "它甚至不能扎破手指！",},
				[CollectibleType.COLLECTIBLE_SHARP_PLUG] = {Name = nil,Description = "锋利，可惜有点小",},
				[CollectibleType.COLLECTIBLE_SAFETY_PIN] = {Name = nil,Description = "锋利，可惜实在太小",},
				[CollectibleType.COLLECTIBLE_SHARD_OF_GLASS] = {Name = nil,Description = "徒有锋利，一无是处",},
				[CollectibleType.COLLECTIBLE_RAZOR_BLADE] = {Name = nil,Description = "锋利，但在枪尖用不上",},
				[CollectibleType.COLLECTIBLE_IV_BAG] = {Name = nil,Description = "锋利，但在难以镶上枪尖",},
				[CollectibleType.COLLECTIBLE_BLOOD_RIGHTS] = {Name = nil,Description = "锋利，但刃口只能对着自己",},
				[CollectibleType.COLLECTIBLE_GOLDEN_RAZOR] = {Name = nil,Description = "黄金枪？开什么玩笑！",},
				
				[CollectibleType.COLLECTIBLE_TERRA] = {Name = "石开利刃",Description = "唯锐可以破坚",},
				[CollectibleType.COLLECTIBLE_URANUS] = {Name = "冰行利刃",Description = "寒意刺骨",},
				[CollectibleType.COLLECTIBLE_MARS] = {Name = nil,Description = "冲锋枪？",},
				[CollectibleType.COLLECTIBLE_NEPTUNUS] = {Name = nil,Description = "半自动枪？",},
				[CollectibleType.COLLECTIBLE_VENUS] = {Name = nil,Description = "热流枪？",},
				[CollectibleType.COLLECTIBLE_MY_REFLECTION] = {Name = nil,Description = "回马枪？",},
				
				[CollectibleType.COLLECTIBLE_LOKIS_HORNS] = {Name = nil,Description = "以防腹背受敌",},
				[CollectibleType.COLLECTIBLE_INNER_EYE] = {Name = nil,Description = "落枪如雷",},
				[CollectibleType.COLLECTIBLE_MUTANT_SPIDER] = {Name = nil,Description = "飞枪如瀑",},
				[CollectibleType.COLLECTIBLE_20_20] = {Name = nil,Description = "枪底藏锋",},
				[CollectibleType.COLLECTIBLE_SPOON_BENDER] = {Name = nil,Description = "宁折不弯",},
				
				[CollectibleType.COLLECTIBLE_WIRE_COAT_HANGER] = {Name = "弯刃鸭架",Description = "掰直顶部的话还能勉强用用",},
				[CollectibleType.COLLECTIBLE_ANGELIC_PRISM] = {Name = nil,Description = "易碎的尖角",},
				[CollectibleType.COLLECTIBLE_GOAT_HEAD] = {Name = nil,Description = "这玩意也能穿在枪头诶！",},
				[CollectibleType.COLLECTIBLE_IT_HURTS] = {Name = nil,Description = "又细又软，不怎么行",},
				[CollectibleType.COLLECTIBLE_MOMS_LIPSTICK] = {Name = nil,Description = "并不尖锐，只能凑合着用",},
				[CollectibleType.COLLECTIBLE_RESTOCK] = {Name = nil,Description = "把尖锐符号化？",},
				[CollectibleType.COLLECTIBLE_STIGMATA] = {Name = nil,Description = "这木头满是刺渣",},
				[CollectibleType.COLLECTIBLE_CHARM_VAMPIRE] = {Name = nil,Description = "快！用尖牙咬他！",},
				[CollectibleType.COLLECTIBLE_MY_LITTLE_UNICORN] = {Name = nil,Description = "奇怪的手感",},
				[CollectibleType.COLLECTIBLE_UNICORN_STUMP] = {Name = nil,Description = "更奇怪的手感",},
				[CollectibleType.COLLECTIBLE_CENSER] = {Name = nil,Description = "可它一点也不尖...",},
				[CollectibleType.COLLECTIBLE_POINTY_RIB] = {Name = nil,Description = "骨刺可不是个好兆头",},
				[CollectibleType.COLLECTIBLE_MEAT_CLEAVER] = {Name = nil,Description = "我可不是厨子",},
				[CollectibleType.COLLECTIBLE_DAMOCLES] = {Name = nil,Description = "我讨厌被刺穿",},
				[CollectibleType.COLLECTIBLE_DAMOCLES_PASSIVE] = {Name = nil,Description = "我非常讨厌被刺穿",},
				[CollectibleType.COLLECTIBLE_POLYPHEMUS] = {Name = nil,Description = "可惜怪力与穿刺是两回事",},
				[CollectibleType.COLLECTIBLE_DEATHS_TOUCH] = {Name = nil,Description = "我也不会用这玩意",},
				[CollectibleType.COLLECTIBLE_CONTINUUM] = {Name = nil,Description = "数学再好也不能把枪变成两把",},
				[CollectibleType.COLLECTIBLE_PUPULA_DUPLEX] = {Name = nil,Description = "不该把美瞳留给我的",},
				[CollectibleType.COLLECTIBLE_BACKSTABBER] = {Name = nil,Description = "暗杀这种事还是交给别人吧",},
				[CollectibleType.COLLECTIBLE_FINGER] = {Name = "手指枪",Description = "指枪 · 六王枪！",},
				[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {Name = "御枪飞行",Description = "飞枪术其实并不怎么好用",},
				
				[CollectibleType.COLLECTIBLE_MONSTROS_LUNG] = {Name = nil,Description = "隐枪于万向",},
				[CollectibleType.COLLECTIBLE_TINY_PLANET] = {Name = "星落",Description = "枪如陀螺",},
				[CollectibleType.COLLECTIBLE_SOY_MILK] = {Name = nil,Description = "枪疾似电",},
				[CollectibleType.COLLECTIBLE_ALMOND_MILK] = {Name = nil,Description = "枪快如风",},
				[enums.Items.Assassin_s_Eye] = {Name = nil,Description = "明枪暗刃",},
				[enums.Items.Touchstone] = {Name = "似有所名之刃",Description = "这是...",},
				[enums.Items.Suture_Needle] = {Name = "缝合魔鬼",Description = "此物不祥，于我无用",},
				[enums.Items.Devil_s_Heart] = {Name = "尖锐之种",Description = "不错的噩梦..",},
				[enums.Items.Pendulum_Star] = {Name = nil,Description = "摆得太高了",},
				[enums.Items.Squiresaga] = {Name = "是那把剑！",Description = "...",},
				[enums.Items.Illumination] = {Name = "幻灭",Description = "不...",},
				[enums.Items.Book_of_6_sin] = {Name = "论嫉妒",Description = "痛在我心",},
				[enums.Items.The_Suture_Needle] = {Name = "缝合恶魔",Description = "她比我还痛吗？",},
				
				[CollectibleType.COLLECTIBLE_KNIFE_PIECE_1] = {Name = nil,Description = "锋？",},
				[CollectibleType.COLLECTIBLE_KNIFE_PIECE_2] = {Name = nil,Description = "利！",},
			},
			["PlayerDesc"] = {
				["Killlist"] = {
					["19.0"] = {Name = "不错的战利品",Description = "这头倒也还算保存完整",},
					["19.1"] = {Name = "破口的战利品",Description = "这脑袋也算是一个玩具啦",},
					["19.2"] = {Name = "创伤的战利品",Description = "这个脑袋不会动呢",},
					["19.3"] = {Name = "灰色的战利品",Description = "咬咬咬！",},
					["81.1"] = {Name = "三角的战利品",Description = "似乎还有喷硫磺火的机关，在哪来着？",},
					["920.0"] = {Name = "一角的战利品",Description = "可爱吧！分裂两个脑袋可真费功夫！",},
					["906.0"] = {Name = "一角的战利品",Description = "可爱捏！",},
					["909.0"] = {Name = "帅气的战利品",Description = "事实证明，鞭子不如长枪",},
					["273.0"] = {Name = "羊角的战利品",Description = "这羔羊浑身无肉，如何能吃？",},
					["275.0"] = {Name = "终焉的战利品",Description = "在我的枪尖下其实也就那样",},
					["904.0"] = {Name = "小姐姐的战利品",Description = "要永远地纪念你哦！",},
					["267.0"] = {Name = "两角的战利品",Description = "我的收藏夹又添一页",},
					["268.0"] = {Name = "一个半角的战利品",Description = "修好那个半角可花了不少时间",},
				},
			},
		},
		["en"] = {
			["Item"] = {
				[CollectibleType.COLLECTIBLE_DR_FETUS] = {Name = "Pointed Fetus",Description = "Sharp to Bomb!",},
				[CollectibleType.COLLECTIBLE_MOMS_KNIFE] = {Name = "Keen Knife",Description = "Sharp and Perfect!",},
				[CollectibleType.COLLECTIBLE_BRIMSTONE] = {Name = nil,Description = "Sharp and Gorgeous!",},
				[CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = {Name = nil,Description = "Sharp and Elegant!",},
				[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {Name = nil,Description = "Sharp and Noisy!",},
				[CollectibleType.COLLECTIBLE_TECH_X] = {Name = "Tech Edge",Description = "Sharp and Rounded!",},
				[CollectibleType.COLLECTIBLE_EPIC_FETUS] = {Name = "East Wind-XXXI",Description = "Sharp and Powerful!",},
				[CollectibleType.COLLECTIBLE_MAW_OF_VOID] = {Name = nil,Description = "Sharp and Gluttonous!",},
				[CollectibleType.COLLECTIBLE_C_SECTION] = {Name = "Limit over section",Description = "Sharp and Incisive!",},
				[CollectibleType.COLLECTIBLE_SACRIFICIAL_DAGGER] = {Name = nil,Description = "Sharp and bleeding!",},
				[CollectibleType.COLLECTIBLE_ATHAME] = {Name = nil,Description = "Sharp and Bloodthirsty!",},
				[CollectibleType.COLLECTIBLE_BLOOD_OATH] = {Name = "Blade oath",Description = "Sharp and Terrifying!",},
				
				[CollectibleType.COLLECTIBLE_ANTI_GRAVITY] = {Name = nil,Description = "Floating in the air?",},
				[CollectibleType.COLLECTIBLE_CHOCOLATE_MILK] = {Name = nil,Description = "I'm in freedom",},
				[CollectibleType.COLLECTIBLE_CURSED_EYE] = {Name = nil,Description = "I'm cursed",},
				[CollectibleType.COLLECTIBLE_TRISAGION] = {Name = nil,Description = "I lead holy",},
				[CollectibleType.COLLECTIBLE_SALVATION] = {Name = nil,Description = "I bring salvation",},
				[CollectibleType.COLLECTIBLE_GODHEAD] = {Name = nil,Description = "I symbolize god",},
				[CollectibleType.COLLECTIBLE_IPECAC] = {Name = nil,Description = "I bring blast",},
				[CollectibleType.COLLECTIBLE_EYE_OF_BELIAL] = {Name = nil,Description = "I board belial",},
				[CollectibleType.COLLECTIBLE_THE_WIZ] = {Name = nil,Description = "No place for deviation",},
				
				[CollectibleType.COLLECTIBLE_TECHNOLOGY_ZERO] = {Name = nil,Description = "I conduct electricity!",},
				[CollectibleType.COLLECTIBLE_JACOBS_LADDER] = {Name = nil,Description = "I conduct electricity?",},
				[CollectibleType.COLLECTIBLE_TECHNOLOGY_2] = {Name = nil,Description = "Seems to be useful",},
				--[CollectibleType.COLLECTIBLE_PONY] = {Name = nil,Description = "匹马单枪出重围",},
				--[CollectibleType.COLLECTIBLE_WHITE_PONY] = {Name = nil,Description = "横枪跃马，威风凛凛",},
				[CollectibleType.COLLECTIBLE_MOMS_RAZOR] = {Name = "Sharp razor",Description = "Pierce their vessels",},
				[CollectibleType.COLLECTIBLE_KAMIKAZE] = {Name = nil,Description = "Funny...",},
				
				[CollectibleType.COLLECTIBLE_BIG_CHUBBY] = {Name = nil,Description = "You want to be pierced？",},
				[CollectibleType.COLLECTIBLE_LITTLE_CHUBBY] = {Name = nil,Description = "You want to be pierced！",},
				
				[CollectibleType.COLLECTIBLE_CUPIDS_ARROW] = {Name = nil,Description = "As sharp as an arrow",},
				[CollectibleType.COLLECTIBLE_SANGUINE_BOND] = {Name = nil,Description = "to Tear a Crack",},
				--[CollectibleType.COLLECTIBLE_DARK_ARTS] = {Name = nil,Description = "黑夜与枪共舞",},
				[CollectibleType.COLLECTIBLE_THE_NAIL] = {Name = nil,Description = "Sharp?Kind of..",},
				[CollectibleType.COLLECTIBLE_8_INCH_NAILS] = {Name = nil,Description = "Sharp?Kind of...",},
				[CollectibleType.COLLECTIBLE_SHARP_KEY] = {Name = nil,Description = "A keen key?",},
				[CollectibleType.COLLECTIBLE_SAGITTARIUS] = {Name = nil,Description = "Symbolizes the sharp",},
				[CollectibleType.COLLECTIBLE_SPEAR_OF_DESTINY] = {Name = nil,Description = "Blunt but sharp",},
				[CollectibleType.COLLECTIBLE_DEAD_ONION] = {Name = nil,Description = "It stings on my tongue",},
				[CollectibleType.COLLECTIBLE_SMB_SUPER_FAN] = {Name = nil,Description = "Rotating blade",},
				[CollectibleType.COLLECTIBLE_SCREW] = {Name = nil,Description = "It's really pointed",},
				[CollectibleType.COLLECTIBLE_GUILLOTINE] = {Name = "Happy King's platform",Description = "Specialized on capitalists as well",},
				--[CollectibleType.COLLECTIBLE_SCISSORS] = {Name = nil,Description = "该怎么在另一端操控呢？",},
				--[CollectibleType.COLLECTIBLE_PINKING_SHEARS] = {Name = nil,Description = "剪刀可以是枪吗？",},
				[CollectibleType.COLLECTIBLE_MOMS_HEELS] = {Name = "Foot blade",Description = "I love it",},
				
				--[CollectibleType.COLLECTIBLE_LEAD_PENCIL] = {Name = nil,Description = "尖而不利",},
				[CollectibleType.COLLECTIBLE_VENTRICLE_RAZOR] = {Name = nil,Description = "Only be used to cut the meat",},
				[CollectibleType.COLLECTIBLE_TOOTH_AND_NAIL] = {Name = nil,Description = "That's sharp,theoretically",},
				[CollectibleType.COLLECTIBLE_STAPLER] = {Name = nil,Description = "can't even prick a finger",},
				[CollectibleType.COLLECTIBLE_SHARP_PLUG] = {Name = nil,Description = "Too small to install",},
				[CollectibleType.COLLECTIBLE_SAFETY_PIN] = {Name = nil,Description = "Too too small to Install",},
				[CollectibleType.COLLECTIBLE_SHARD_OF_GLASS] = {Name = nil,Description = "Nothing but sharpness",},
				[CollectibleType.COLLECTIBLE_RAZOR_BLADE] = {Name = nil,Description = "Difficult to install",},
				[CollectibleType.COLLECTIBLE_IV_BAG] = {Name = nil,Description = "Sharp but not ideal",},
				[CollectibleType.COLLECTIBLE_BLOOD_RIGHTS] = {Name = nil,Description = "It hurts me",},
				[CollectibleType.COLLECTIBLE_GOLDEN_RAZOR] = {Name = nil,Description = "Golden?WTF!",},
				
				--[CollectibleType.COLLECTIBLE_TERRA] = {Name = nil,Description = "唯锐可以破坚",},		--怎么翻译呢？
				--[CollectibleType.COLLECTIBLE_URANUS] = {Name = nil,Description = "寒意刺骨",},
				--[CollectibleType.COLLECTIBLE_MARS] = {Name = nil,Description = "冲锋枪？",},
				--[CollectibleType.COLLECTIBLE_NEPTUNUS] = {Name = nil,Description = "半自动枪？",},
				--[CollectibleType.COLLECTIBLE_VENUS] = {Name = nil,Description = "热流枪？",},
				--[CollectibleType.COLLECTIBLE_MY_REFLECTION] = {Name = nil,Description = "回马枪？",},
				
				--[CollectibleType.COLLECTIBLE_LOKIS_HORNS] = {Name = nil,Description = "以防腹背受敌",},
				--[CollectibleType.COLLECTIBLE_INNER_EYE] = {Name = nil,Description = "落枪如雷",},
				--[CollectibleType.COLLECTIBLE_MUTANT_SPIDER] = {Name = nil,Description = "飞枪如瀑",},
				--[CollectibleType.COLLECTIBLE_20_20] = {Name = nil,Description = "枪底藏锋",},
				[CollectibleType.COLLECTIBLE_SPOON_BENDER] = {Name = nil,Description = "I would rather break than bend",},
				
				[CollectibleType.COLLECTIBLE_WIRE_COAT_HANGER] = {Name = nil,Description = "I have to straighten the top",},
				[CollectibleType.COLLECTIBLE_ANGELIC_PRISM] = {Name = nil,Description = "Fragile sharp corner",},
				[CollectibleType.COLLECTIBLE_GOAT_HEAD] = {Name = nil,Description = "It can also be pierced on!",},
				[CollectibleType.COLLECTIBLE_IT_HURTS] = {Name = nil,Description = "Thin and soft",},
				[CollectibleType.COLLECTIBLE_MOMS_LIPSTICK] = {Name = nil,Description = "Barely to use",},
				[CollectibleType.COLLECTIBLE_RESTOCK] = {Name = nil,Description = "Symbolize sharpness？",},
				[CollectibleType.COLLECTIBLE_STIGMATA] = {Name = nil,Description = "Stingers",},
				[CollectibleType.COLLECTIBLE_CHARM_VAMPIRE] = {Name = nil,Description = "Bite it!",},
				[CollectibleType.COLLECTIBLE_MY_LITTLE_UNICORN] = {Name = nil,Description = "Strange to handle",},
				[CollectibleType.COLLECTIBLE_UNICORN_STUMP] = {Name = nil,Description = "More strange to handle",},
				[CollectibleType.COLLECTIBLE_CENSER] = {Name = nil,Description = "It's not sharp at all...",},
				[CollectibleType.COLLECTIBLE_POINTY_RIB] = {Name = nil,Description = "That's not a good idea",},
				[CollectibleType.COLLECTIBLE_MEAT_CLEAVER] = {Name = nil,Description = "I'm not a chef!",},
				[CollectibleType.COLLECTIBLE_DAMOCLES] = {Name = nil,Description = "I hate being impaled",},
				[CollectibleType.COLLECTIBLE_DAMOCLES_PASSIVE] = {Name = nil,Description = "I really hate being impaled",},
				--[CollectibleType.COLLECTIBLE_POLYPHEMUS] = {Name = nil,Description = "可惜怪力与穿刺是两回事",},
				[CollectibleType.COLLECTIBLE_DEATHS_TOUCH] = {Name = nil,Description = "I don't know how to use it",},
				--[CollectibleType.COLLECTIBLE_CONTINUUM] = {Name = nil,Description = "数学再好也不能把枪变成两把",},
				--[CollectibleType.COLLECTIBLE_PUPULA_DUPLEX] = {Name = nil,Description = "不该把美瞳留给我的",},
				--[CollectibleType.COLLECTIBLE_BACKSTABBER] = {Name = nil,Description = "暗杀这种事还是交给别人吧",},
				[CollectibleType.COLLECTIBLE_FINGER] = {Name = "Finger gun",Description = nil,},
				--[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {Name = "御枪飞行",Description = "飞枪术其实并不怎么好用",},
				
				[CollectibleType.COLLECTIBLE_MONSTROS_LUNG] = {Name = nil,Description = "Multidirections",},
				[CollectibleType.COLLECTIBLE_TINY_PLANET] = {Name = "Falling Planet",Description = "Like a whipping top",},
				[CollectibleType.COLLECTIBLE_SOY_MILK] = {Name = nil,Description = "As quick as the lightning",},
				[CollectibleType.COLLECTIBLE_ALMOND_MILK] = {Name = nil,Description = "As quick as the wing",},
				--[enums.Items.Assassin_s_Eye] = {Name = nil,Description = "明枪暗刃",},
				[enums.Items.Touchstone] = {Name = "Someone's dagger",Description = "...",},
				[enums.Items.Suture_Needle] = {Name = nil,Description = "Ominous and useless",},
				[enums.Items.Devil_s_Heart] = {Name = "Keen's Heart",Description = "That's a nice nightmare..",},
				[enums.Items.Pendulum_Star] = {Name = nil,Description = "It swings too high",},
				[enums.Items.Squiresaga] = {Name = "THE SWORD!",Description = "...",},
				
				[CollectibleType.COLLECTIBLE_KNIFE_PIECE_1] = {Name = nil,Description = "SHA?",},
				[CollectibleType.COLLECTIBLE_KNIFE_PIECE_2] = {Name = nil,Description = "SHARP!",},
			},
			["PlayerDesc"] = {
				["Killlist"] = {
					["19.0"] = {Name = "Nice trophy",Description = "Well preserved",},
					["19.1"] = {Name = "Broken trophy",Description = "That can be a trophy",},
					["19.2"] = {Name = "Wounded trophy",Description = "The trophy can't move now!",},
					["19.3"] = {Name = "Grey trophy",Description = "EAT!",},
					["81.1"] = {Name = "Trophy with 3 horns",Description = "With mechanism to shoot brimstone",},
					["920.0"] = {Name = "Trophy with 1 horn",Description = "That's cute!",},
					["906.0"] = {Name = "Trophy with 1 horn",Description = "That's cute!",},
					["909.0"] = {Name = "Handsome Trophy",Description = "It turns out that whip is worse than spear",},
					["273.0"] = {Name = "Trophy with goat horn",Description = "How can I eat the meatless goat?",},
					["275.0"] = {Name = "The final trophy",Description = "That's easy to done,actually",},
					["904.0"] = {Name = "Trophy from a cute girl",Description = "I will remember you forever!",},
					["267.0"] = {Name = "Trophy with 2 horns",Description = "Add another page to my favorites",},
					["268.0"] = {Name = "Trophy with one and a half horns",Description = "It takes time to restore the broken horn",},
				},
			},
		},
	},
	kill_lists = {
		["19.0"] = {name = "Tecro_Larry_killed",tp = 19,vr = 0,},
		["19.1"] = {name = "Tecro_Hollow_killed",tp = 19,vr = 1,},
		["19.2"] = {name = "Tecro_Tufftwin_killed",tp = 19,vr = 2,},
		["19.3"] = {name = "Tecro_Shell_killed",tp = 19,vr = 3,},
		["81.1"] = {name = "Tecro_Krampus_killed",tp = 81,vr = 1,},
		["920.0"] = {name = "Tecro_Horn_killed",tp = 920,vr = 0,},
		["906.0"] = {name = "Tecro_Horn_killed",tp = 906,vr = 0,},
		["909.0"] = {name = "Tecro_Whip_killed",tp = 909,vr = 0,},
		["273.0"] = {name = "Tecro_Lamb_killed",tp = 273,vr = 0,},
		["275.0"] = {name = "Tecro_Satan_killed",tp = 275,vr = 0,},
		["904.0"] = {name = "Tecro_Siren_killed",tp = 904,vr = 0,},
		["267.0"] = {name = "Tecro_Darkone_killed",tp = 267,vr = 0,},
		["268.0"] = {name = "Tecro_Darkone_killed",tp = 268,vr = 0,},
	},
	brim_list = {
		[1] = true,
		[9] = true,
		[10] = true,
		[11] = true,
		[15] = true,
		[14] = true,
	},
	buff_list = {
		BitSet128(1<<2,0),
		BitSet128(1<<16,0),
		BitSet128(1<<30,0),
		BitSet128(1<<19,0),
		BitSet128(1<<33,0),
		BitSet128(0,1<<5),
	},
	check_kill = {
		[92] = {[93] = true,},
		[98] = {[97] = true,},
		[903] = function(ent) if ent.Variant == 0 then return {[903] = function(ent) if ent.Variant == 1 then return true end end,} end end,
	},
	check_rel = {
		[62] = true,
	},
	Tecro_middle_holder = false,
	Tecro_middle_time_holder = 0,
	bond_special_spikes = {
		[LevelStage.STAGE4_1] = true,
		[LevelStage.STAGE4_2] = true,
		[LevelStage.STAGE4_3] = true,
	},
	Addition_catcher = {
		[19] = true,
		[28] = true,
		[62] = true,
		[239] = true,
	},
	eventlist = {"Explosion","Shoot","Jump","Land","BloodStart","BloodStop","Lift","Stop","Slide","Spawn","Shoot2","DeathSound","DropSound","Disappear","Prize",},--"Shuffle",--"CoinInsert",--"Heartbeat",
}

local function get_max_delay(player)
	local ret = math.max(player.MaxFireDelay * 3,10)
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CURSED_EYE) then		--诅咒之眼
		ret = ret * 5
	end
	return ret
end

local function can_be_repeled(ent,player)
	return (auxi.isenemies(ent) or item.repelables[ent.Type] ~= nil)
end

local function can_be_impaled(ent,player)
	return (auxi.isenemies(ent))
end

local function find_a_impaled_place(ent,player)
	local mx = get_impale_rate(player)
	local d = player:GetData()
	d.Tecro_spear_target = d.Tecro_spear_target or {}
	if #d.Tecro_spear_target < mx then return true end
	local linked_ent = auxi.get_linked(ent)
	local ret = false
	for u,v in pairs(linked_ent) do v:GetData().impaled_marked_here = true end
	for u,v in pairs(d.Tecro_spear_target) do
		local eent = v.ent
		if eent:GetData().impaled_marked_here then ret = true break end
	end
	for u,v in pairs(linked_ent) do v:GetData().impaled_marked_here = nil end
	return ret
end

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

local function get_spear_damage(player,state)
	local d = player:GetData()
	state = state or d.Tecro_spear_state
	local ret = player.Damage
	if state == 0 or state == -1 then
		ret = ret * 0.8
	else
		ret = ret * 3
	end
	return ret
end

local function get_spear_size(player,state)
	local d = player:GetData()
	state = state or d.Tecro_spear_state
	local ret = {size1 = 5,size2 = Vector(1,4),size3 = 5,}
	if state == 0 or state == -1 then
	else
		ret.size2 = Vector(ret.size2.X * 3,ret.size2.Y * 1.3)
	end
	return ret
end

local function stop_time(ent,player)
	if ent == nil then return end
	local s = ent:GetSprite()
	for u,v in pairs(item.eventlist) do
		if s:IsEventTriggered(v) ~= false then 
			s:Update()
		end
	end
	local d = ent:GetData()
	if d.Tecro_flag_freeze_succ == nil then
		d.Tecro_flag_freeze_succ = Attribute_holder.try_hold_attribute(ent,"EntityFlag_FLAG_FREEZE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
	end
	if d.Tecro_flag_no_sprite_update_succ == nil then
		d.Tecro_flag_no_sprite_update_succ = Attribute_holder.try_hold_attribute(ent,"EntityFlag_FLAG_NO_SPRITE_UPDATE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_SPRITE_UPDATE))
	end
	if d.Tecro_flag_velocity_succ == nil then
		d.Tecro_flag_velocity_succ = Attribute_holder.try_hold_attribute(ent,"Velocity",Vector(0,0),{tocompare = function(v1,v2) return (v1 - v2):Length() < 0.001 end,})
	end
	if d.Tecro_flag_positionoffset_succ == nil then
		d.Tecro_flag_positionoffset_succ = Attribute_holder.try_hold_attribute(ent,"PositionOffset",Vector(0,0),{tocompare = function(v1,v2) return (v1 - v2):Length() < 0.001 end,})
	end
	if d.Tecro_flag_gridcollision_succ == nil then
		d.Tecro_flag_gridcollision_succ = Attribute_holder.try_hold_attribute(ent,"GridCollisionClass",GridCollisionClass.COLLISION_NONE)
	end
	d.time_stopped = true
	d.Tecro_spear_hold_time_Charge_Bar_buff = 0
	local extra_time = auxi.get_sharp_time(player)
	if ent:IsBoss() then
		d.Tecro_spear_hold_time_Charge_Bar_buff_mx = (45 + player.TearRange/15) * player.ShotSpeed + extra_time * 30
	else
		d.Tecro_spear_hold_time_Charge_Bar_buff_mx = (90 + player.TearRange/5) * player.ShotSpeed + extra_time * 30
	end
	d.Tecro_spear_targeted_player = player
end

local function time_free(ent)
	if ent == nil then return end
	local d = ent:GetData()
	if d.Tecro_flag_freeze_succ then
		local succ = Attribute_holder.try_rewind_attribute(ent,"EntityFlag_FLAG_FREEZE",d.Tecro_flag_freeze_succ,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
		d.Tecro_flag_freeze_succ = nil
	end
	if d.Tecro_flag_no_sprite_update_succ then
		Attribute_holder.try_rewind_attribute(ent,"EntityFlag_FLAG_NO_SPRITE_UPDATE",d.Tecro_flag_no_sprite_update_succ,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_SPRITE_UPDATE))
		d.Tecro_flag_no_sprite_update_succ = nil
	end
	if d.Tecro_flag_velocity_succ then
		Attribute_holder.try_rewind_attribute(ent,"Velocity",d.Tecro_flag_velocity_succ,{tocompare = function(v1,v2) return (v1 - v2):Length() < 0.001 end,})
		d.Tecro_flag_velocity_succ = nil
	end
	if d.Tecro_flag_positionoffset_succ then
		Attribute_holder.try_rewind_attribute(ent,"PositionOffset",d.Tecro_flag_positionoffset_succ,{tocompare = function(v1,v2) return (v1 - v2):Length() < 0.001 end,})
		d.Tecro_flag_positionoffset_succ = nil
	end
	if d.Tecro_flag_gridcollision_succ then
		Attribute_holder.try_rewind_attribute(ent,"GridCollisionClass",d.Tecro_flag_gridcollision_succ)
		d.Tecro_flag_gridcollision_succ = nil
	end
	Attribute_holder.try_hold_and_rewind_attribute(ent,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE,3)
	d.time_stopped = nil
	d.Tecro_spear_targeted_player = nil
	d.Tecro_linked_ent = nil
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

local function get_spear_sprite_path(name)
	if type(name) ~= "string" then return nil end
	if string.find(name,"/") or string.find(name,"\\") then return name end
	return "gfx/player/spears/"..name
end

local function reload_needle(ent,player,tp)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local info = item.sprite_loader[tp or #item.sprite_loader]
	for i = 1,2 do
		local name = info.name
		local t_name = name
		if info.special_reloader then if type(info.special_reloader) == "table" and info.special_reloader[i] then t_name = info.special_reloader[i] end else t_name = info.special_reloader end
		if type(t_name) == "function" then t_name = t_name(player,ent,info) end
		if type(t_name) == "string" then name = t_name end
		s:ReplaceSpritesheet(i,get_spear_sprite_path(name))
	end
	s:LoadGraphics()
	local idlename = info.idlename or "IdleHead"
	s:Play(idlename)
	if d.tail then
		local s2 = d.tail:GetSprite() 
		if info.reversed_tail then
			s2:Load("gfx/recolored_trail.anm2",true)
			s2:Play("Idle",true)
		else
			s2:Load("gfx/effects/trail.anm2",true)
			s2:Play("Idle",true)
		end
	end
end

local function get_all_spear(ent,player)
	local ret = {}
	for u,v in pairs(item.sprite_loader) do
		if v.check == nil or v.check(player,v,ent) then
			table.insert(ret,#ret + 1,{id = u,info = v,})
		end
	end
	return ret
end

function item.get_first_spear(ent,player,params)
	local ret = 0
	local wei = 1000
	for u,v in pairs(item.sprite_loader) do
		if v.check == nil or v.check(player,v,ent) then
			local ww = u
			if v.check_id then ww = v.check_id(player,v,ent,u) or ww end
			if wei > ww then
				wei = ww
				ret = u
			end
		end
	end
	return ret
end

local function reload_spear(ent,player,params)
	params = params or {}
	local d = ent:GetData()
	local s = ent:GetSprite()
	id = params.spear_type or item.now_id or item.get_first_spear(ent,player) or 1
	d.spear_type = id
	if d.record_spear_type ~= d.spear_type then
		d.record_spear_type = d.spear_type
		local info = item.sprite_loader[(d.spear_type or 1)] or item.sprite_loader[1]
		if d.head == nil then 
			d.head = Sprite() 
			d.head:Load("gfx/player/tecro/_Tecro_Spear.anm2",true)
		end
		local head = d.head
		for i = 1,2 do 
			local name = info.name
			local t_name = name
			if info.special_reloader then if type(info.special_reloader) == "table" and info.special_reloader[i] then t_name = info.special_reloader[i] end else t_name = info.special_reloader end
			if type(t_name) == "function" then t_name = t_name(player,ent,info) end
			if type(t_name) == "string" then name = t_name end
			local sprite_path = get_spear_sprite_path(name)
			s:ReplaceSpritesheet(i,sprite_path)
			head:ReplaceSpritesheet(i,sprite_path)
		end	
		s:LoadGraphics()
		head:LoadGraphics()
		
		local idlename = info.idlename or "IdleHead"
		head:Play(idlename,true)
		
		if d.tail then
			local s2 = d.tail:GetSprite() 
			if info.reversed_tail then
				s2:Load("gfx/recolored_trail.anm2",true)
				s2:Play("Idle",true)
			else
				s2:Load("gfx/effects/trail.anm2",true)
				s2:Play("Idle",true)
			end
		end
	end
end

local function check_mouse_work(player,ndir,qdir,center)
	qdir = qdir or player:GetData().now_dir
	center = center or player.Position
	if item.Tecro_middle_time_holder <= 0 and Input.IsMouseBtnPressed(2) then 
		item.Tecro_middle_time_holder = 20 
		item.Tecro_middle_holder = (not item.Tecro_middle_holder) 
	end
	if ndir:Length() < 0.05 and item.Tecro_middle_holder then
		local ret = Vector(0,0)
		local mspos = Input.GetMousePosition(true)
		if Game():GetRoom():IsMirrorWorld() then
			mspos = auxi.mul_t(ui.myScreenToWorld(Isaac.WorldToRenderPosition(Input.GetMousePosition(true))),Vector(-1,1)) +
				auxi.mul_t(Isaac.ScreenToWorld(auxi.GetScreenSize()),Vector(2,0))
		end
		local dir = mspos - (center or Vector(0,0))
		ret = ret + Vector(auxi.get_correct_angle_id(dir:GetAngleDegrees() - qdir:GetAngleDegrees()),0)
		if Input.IsMouseBtnPressed(0) then 
			ret = ret + Vector(0,-1)
		elseif Input.IsMouseBtnPressed(1) then
			ret = ret + Vector(0,1)
		end
		return ret:Normalized()
	end
end

--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local tearHitParams = Game():GetPlayer(0):GetTearHitParams(WeaponType.WEAPON_BRIMSTONE,1,0) print(tearHitParams.TearFlags) auxi.PrintColor(tearHitParams.TearColor) print(tearHitParams.TearDamage.." "..tearHitParams.TearScale)
local function add_addition_to_spear(ent,player,params)
	params = params or {}
	local birth = params.birth
	local tearHitParams = params.tearHitParams or player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
	local tearflag = tearHitParams.TearFlags | (params.TearFlags or BitSet128(0,0))
	local tearcolor = auxi.AddColor(tearHitParams.TearColor,(params.TearColor or tearHitParams.TearColor),0.7,0.3)
	local d = ent:GetData()
	local d2 = player:GetData()
	local idx = d2.__Index
	local list = d2.Tecro_list or params.list or {}
	if params.should_not_reload == nil then reload_spear(ent,player) end
	local info = item.sprite_loader[(d.spear_type or 1)] or item.sprite_loader[1]
	local dir = params.dir or d2.now_dir or Vector(0,1)
	local charge = params.charge or (d2.Tecro_spear_Charge_Bar_buff or 0)/(d2.Tecro_spear_Charge_Bar_buff_mx or 1)
	local weap = auxi.get_weapon(player)
	if weap == 2 or (list.brimstone or 0) > 0 then			--硫磺火
		local both = (weap == 2 and (list.brimstone or 0) > 0)
		if (list.soy or 0) > 0 or (list.soy2 or 0) > 0 then
			local q 
			if both then
				q = player:FireBrimstone(dir,nil,1 * charge)
			else
				q = player:FireBrimstone(dir,nil,0.5 * charge)
			end
			q.PositionOffset = Vector(0,0)
			q.Parent = ent
			q.Position = ent.Position
			q.TearFlags = q.TearFlags & (~TearFlags.TEAR_WAIT)
			if auxi.check_exists(d.Tecro_linked_brimstone) then d.Tecro_linked_brimstone:SetTimeout(1) end
			d.Tecro_linked_brimstone = q
			if both then
			else
				q.MaxDistance = math.sqrt(player.TearRange) * 5
			end
			q:SetTimeout(-1)
		else
			d.Tecro_linked_brimstone = function(ent,spear,player)
				local q 
				if both then
					q = player:FireBrimstone(dir,nil,1 * charge)
				else
					q = player:FireBrimstone(dir,nil,0.5 * charge)
				end
				q.PositionOffset = Vector(0,0)
				q.Parent = spear
				q.Position = spear.Position
				q.TearFlags = q.TearFlags & (~TearFlags.TEAR_WAIT)
				if auxi.check_exists(d.Tecro_linked_brimstone) then d.Tecro_linked_brimstone:SetTimeout(1) end
				d.Tecro_linked_brimstone = q
				if both then
				else
					q.MaxDistance = math.sqrt(player.TearRange) * 5
				end
				q:SetTimeout(q.Timeout * 3)
				return q
			end
		end
	end
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MAW_OF_THE_VOID) or (info.maw_of_void and auxi.check_rand(player.Luck,50,15,6)) then
		if (list.soy or 0) > 0 or (list.soy2 or 0) > 0 then
			local q = player:SpawnMawOfVoid(35)
			q.CollisionDamage = player.Damage * 0.3 * charge
			if auxi.check_exists(d.Tecro_linked_maw_of_void) then d.Tecro_linked_maw_of_void:SetTimeout(1) end
			d.Tecro_linked_maw_of_void = q
			q.Parent = ent
			q.PositionOffset = Vector(0,0)
			q.Variant = 3
			q:SetTimeout(-1)
		else
			d.Tecro_linked_maw_of_void = function(ent,spear,player)
				local q = player:SpawnMawOfVoid(35)
				q.CollisionDamage = player.Damage * 0.3 * charge
				if auxi.check_exists(d.Tecro_linked_maw_of_void) then d.Tecro_linked_maw_of_void:SetTimeout(1) end
				d.Tecro_linked_maw_of_void = q
				q.Parent = spear
				q.PositionOffset = Vector(0,0)
				q.Variant = 3
				q:SetTimeout(35)
				return q
			end
		end
	end
	if ((weap == 3 or (list.tech or 0) > 0) and ((list.soy or 0) > 0 or (list.soy2 or 0) > 0)) or (list.tech2 or 0) > 0 then		--科技2、科技
		local q = player:FireTechLaser(player.Position,0,dir,true,false,nil,0.13 * charge)
		q.TearFlags = q.TearFlags & (~TearFlags.TEAR_WAIT)
		q.PositionOffset = Vector(0,0)
		q.Parent = ent
		q:SetTimeout(-1)
		if auxi.check_exists(d.Tecro_linked_tech2) then d.Tecro_linked_tech2:SetTimeout(1) end
		d.Tecro_linked_tech2 = q
		q:GetData().check_linker = ent
	else
		if weap == 3 or (list.tech or 0) > 0 then
			local both = (weap == 3 and (list.tech or 0) > 0)
			d.Tecro_linked_tech = function(ent,spear,player,dir)
				local q
				if both then
					q = player:FireTechLaser(spear.Position,0,dir,true,false,nil,1 * charge)
				else
					q = player:FireTechLaser(spear.Position,0,dir,true,false,nil,0.6 * charge)
				end
				q.TearFlags = q.TearFlags & (~TearFlags.TEAR_WAIT)
				q.PositionOffset = Vector(0,0)
				q.Parent = spear
				return q
			end
		end
	end
	if (list.tech_5 or 0) > 0 then							--科技.5 
		if auxi.check_rand(player.Luck,30,10,5) then
			local q = player:FireTechLaser(ent.Position,0,dir,true,false,nil,1 * charge)
			q.PositionOffset = Vector(0,0)
			q.Parent = ent
			for u,v in pairs(item.buff_list) do 
				if math.random(1000) > 700 then
					q.TearFlags = q.TearFlags | v
				end
			end
		end
	end
	if ((list.bluefire or 0) > 0) or info.bluefire then
		if auxi.check_rand(player.Luck,50,10,10) then
			d.Tecro_linked_bluefire = function(ent,spear,player,dir,info)
				local dmg = player.Damage * 4 * charge
				if (list.bluefire or 0) > 0 then else dmg = dmg * 0.1 end
				local cnt = math.random(5) + 3
				if (list.soy or 0) > 0 or (list.soy2 or 0) > 0 or (list.urn or 0) > 0 then 
					cnt = cnt + math.random(10 * ((list.soy or 0) + (list.soy2 or 0) + (list.urn or 0)))
				end
				for i = 1,cnt do
					delay_buffer.addeffe(function(params)
						if spear:Exists() == false then return end
						local q = Isaac.Spawn(1000,EffectVariant.BLUE_FLAME,0,spear.Position,dir:Normalized() * 15 * player.ShotSpeed,player):ToEffect()
						q:SetTimeout(60)
						q.LifeSpan = 60
						q.CollisionDamage = dmg
						q.Parent = spear
					end,{},i)
				end
			end
		end
	end
	if (list.redfire or 0) > 0 then
		if auxi.check_rand(player.Luck,50,10,10) then
			d.Tecro_linked_redfire = function(ent,spear,player,dir)
				local q = Isaac.Spawn(1000,EffectVariant.RED_CANDLE_FLAME,0,spear.Position,Vector(0,0),player):ToEffect()
				q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
				q.CollisionDamage = player.Damage * 3 * charge
				return q
			end
		end
	end
	if (list.tri or 0) > 0 or tearflag & TearFlags.TEAR_LASERSHOT == TearFlags.TEAR_LASERSHOT then								--三圣颂(吐根三圣颂需要被处理)
		local q = Isaac.Spawn(7,3,0,player.Position,Vector(0,0),player):ToLaser()
		q.TearFlags = tearflag
		q:GetSprite().Color = tearcolor
		q.PositionOffset = Vector(0,0)
		q.Parent = ent
		for i = 0,2 do
			delay_buffer.addeffe(function(params)
				SFXManager():Stop(SoundEffect.SOUND_BLOOD_LASER_LARGE)
			end,{},i)
		end
		q.CollisionDamage = q.CollisionDamage * 0.33 * charge
		if auxi.check_exists(d.Tecro_linked_trisagon) then d.Tecro_linked_trisagon:SetTimeout(1) end
		d.Tecro_linked_trisagon = q
		q.MaxDistance = math.sqrt(player.TearRange) * 3
		q:SetTimeout(-1)
		q:GetData().check_linker = ent
	end
	if weap == 5 or (list.dr or 0) > 0 then					--博士
		d.Tecro_linked_bomb = function(ent,spear,player,dir)
			local both = (weap == 5 and (list.dr or 0) > 0)
			local q = player:FireBomb(spear.Position + dir:Normalized() * 10,dir:Normalized() * 10 * player.ShotSpeed)
			local s2 = q:GetSprite()
			local d3 = q:GetData()
			Attribute_holder.try_hold_and_rewind_attribute(q,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE,5)
			if both then
				q.ExplosionDamage = q.ExplosionDamage * charge
			else
				q.Variant = 14
				local name = s2:GetAnimation()
				s2:Load("gfx/004.014_Small Bomb.anm2",true)
				s2:Play("Pulse",true)
				q.ExplosionDamage = q.ExplosionDamage * 0.5 * charge
			end
			if ((list.soy or 0) > 0 or (list.soy2 or 0) > 0) then
				local cnt = math.random(5)
				for i = 1,cnt do 
					delay_buffer.addeffe(function(params)
						local q = player:FireBomb(spear.Position + dir:Normalized() * 10,auxi.MakeVector(dir:GetAngleDegrees() + math.random(20) - 10) * (math.random(60)/10 + 7) * player.ShotSpeed)
						if both then
							q.ExplosionDamage = q.ExplosionDamage * charge
						else
							q.ExplosionDamage = q.ExplosionDamage * 0.5 * charge
						end
					end,{},math.random(3))
				end
			end
			return q
		end
	end
	if weap == 9 or (list.techX or 0) > 0 then				--科技X
		local both = (weap == 9 and (list.techX or 0) > 0)
		local range = 30 * charge * player.ShotSpeed 
		local dmgmul = 0.2 * charge
		if both then 
			range = 50 * charge * player.ShotSpeed 
			dmgmul = 0.75 * charge
		end
		local q = player:FireTechXLaser(ent.Position,Vector(0,0),range,nil,dmgmul)
		local s2 = q:GetSprite()
		q.PositionOffset = Vector(0,0)
		q.Parent = ent
		q.SubType = 3
		if item.brim_list[q.Variant] then 
			q.Variant = 3
		end
		if d.Tecro_linked_tech_x_laser and d.Tecro_linked_tech_x_laser:Exists() then 
			d.Tecro_linked_tech_x_laser.SubType = 2
			d.Tecro_linked_tech_x_laser.Velocity = dir:Normalized() * 10 * player.ShotSpeed
			d.Tecro_linked_tech_x_laser = nil
		end
		d.Tecro_linked_tech_x_laser = q
	end
	for i = 1,1 do if weap == 4 or (list.knife or 0) > 0 then				--濡堝垁
		if (save.elses.Tecro_knife_buff or {})[idx] then break end
		local both = (weap == 4 and (list.knife or 0) > 0)
		d.Tecro_linked_knife = function(ent,spear,player,dir)
			local params = {
				cooldown = 30,
				Accerate = 1.5,
				player = player,
				Color = player.TearColor,
				Explosive = player:GetCollectibleNum(149) + player:GetCollectibleNum(52),
			}
			local cnt1 = math.random(3) + 2
			local cnt2 = math.random(3) + 1
			if both and not birth then
			else
				params.remove_color = true
				params.cooldown = 15
				cnt1 = cnt1 - 2
				cnt2 = cnt2 - 1
			end
			if ((list.soy or 0) > 0 or (list.soy2 or 0) > 0) then
				cnt1 = cnt1 + math.random(3) + 1
				cnt2 = cnt2 + math.random(2) + 1
			end
			for i = 1,cnt1 do
				for j = 1,cnt2 do
					delay_buffer.addeffe(function(params)
						if params.ent == nil or params.player == nil or params.dir == nil then return end
						local ent = params.ent
						local dir = ent:GetData().record_spear_ddir or params.dir
						local player = params.player
						local pm = auxi.deepCopy(params.pm)
						if j == 1 and (list.brimstone or 0) > 0 then pm.Brim = true end
						local rand = math.random(31) - 16
						local q2 = auxi.fire_knife(ent.Position + Vector(0,-10),12 * player.ShotSpeed * auxi.MakeVector(dir:GetAngleDegrees() + rand),player.Damage * charge,nil,pm)
						if rand < 0 then 
							q2:GetSprite().FlipX = true 
							q2.RotationOffset = 180 - q2.RotationOffset
						end
						delay_buffer.addeffe(function(params)
							local dir = params.dir
							local mnil = q2.Parent
							if mnil then
								mnil.Velocity = mnil.Velocity:Length() * auxi.MakeVector(dir:GetAngleDegrees())
							end
						end,{dir = dir,},5)
						for k = 1,4 do
							delay_buffer.addeffe(function(params)
								local dir = params.dir
								if q2:GetSprite().FlipX then
									q2.RotationOffset = 180 - dir:GetAngleDegrees()
								else
									q2.RotationOffset = dir:GetAngleDegrees()
								end
							end,{dir = dir,},5 + k)
						end
					end,auxi.copy({ent = spear,player = player,dir = dir:Normalized(),pm = params,}),i * 3 - 1)
				end
			end
		end
	end end
	if (list.ipec or 0) > 0 then
		d.Tecro_linked_ipec = function(ent,spear,player,dir)
			Game():BombExplosionEffects(spear.Position,player.Damage * 2,tearflag,spear:GetSprite().Color,player,1,false,false) 
		end
	end
	if weap == 6 or (list.epic or 0) > 0 then				--史诗
		local both = (weap == 6 and (list.epic or 0) > 0)
		d.Tecro_linked_epic_missile = function(ent,spear,player,dir)
			local q
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ROCKET_IN_A_JAR) == false then
				Imitate_item_holder.assign_fake_item(player,CollectibleType.COLLECTIBLE_ROCKET_IN_A_JAR,true)
				q = player:FireBomb(spear.Position + dir:Normalized() * 10,dir:Normalized() * 10 * player.ShotSpeed)
				if ((list.soy or 0) > 0 or (list.soy2 or 0) > 0) then
					local cnt = math.random(6) + 2
					for i = 1,cnt do 
						q = player:FireBomb(spear.Position + dir:Normalized() * 10 + auxi.MakeVector(360/cnt*i) * 40,auxi.MakeVector(dir:GetAngleDegrees() + math.random(20) - 10) * (math.random(60)/10 + 7) * player.ShotSpeed)
					end
				end
				Imitate_item_holder.re_assign_fake_item()
			else
				q = player:FireBomb(spear.Position + dir:Normalized() * 10,dir:Normalized() * 10 * player.ShotSpeed)
				if ((list.soy or 0) > 0 or (list.soy2 or 0) > 0) then
					local cnt = math.random(6) + 2
					for i = 1,cnt do 
						q = player:FireBomb(spear.Position + dir:Normalized() * 10 + auxi.MakeVector(360/cnt*i) * 40,auxi.MakeVector(dir:GetAngleDegrees() + math.random(20) - 10) * (math.random(60)/10 + 7) * player.ShotSpeed)
					end
				end
			end
			local s = q:GetSprite()
			q.PositionOffset = Vector(0,0)
			if both then
				q.CollisionDamage = q.CollisionDamage * 2 * charge
				q.RadiusMultiplier = q.RadiusMultiplier * 1.5
				s:Load("gfx/mimics/Epic_Fetus/Missile_huge.anm2",true)
				s:Play("Pulse",true)
			else
				q.CollisionDamage = q.CollisionDamage * charge
				s:Load("gfx/mimics/Epic_Fetus/Missile_small.anm2",true)
				s:Play("Pulse",true)
			end
		end
	end
	if weap == 13 or (list.sword or 0) > 0 then				--英灵剑
		local both = (weap == 13 and (list.sword or 0) > 0)
		if both then
			d.Tecro_linked_sword = function(ent,spear,player,dir)
				local params = {
					cooldown = 16,
					player = player,
					tearflags = player.TearFlags,
					Color = player.TearColor,
					Tech = player:HasCollectible(68) or player:HasCollectible(395),
					RotationOffset = dir:GetAngleDegrees(),
					follower = spear,
				}
				local q2 = auxi.fire_Sword(spear.Position,Vector(0,0),player.Damage * 0.4 * charge,nil,params)
				delay_buffer.addeffe(function(params)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME,1,1,false,0,2)
				end,{},4)
				return q2
			end
		else
			d.Tecro_linked_sword = function(ent,spear,player,dir)
				local params = {
					cooldown = 8,
					player = player,
					tearflags = player.TearFlags,
					Color = player.TearColor,
					Tech = player:HasCollectible(68) or player:HasCollectible(395),
					Attack = true,
					RotationOffset = dir:GetAngleDegrees(),
					follower = spear,
				}
				local q2 = auxi.fire_Sword(spear.Position,Vector(0,0),player.Damage * 0.2 * charge,nil,params)
				delay_buffer.addeffe(function(params)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME,1,1,false,0,2)
				end,{},4)
				return q2
			end
		end
	end
	if d.tecro_remove_then == nil and (list.birthright or 0) > 0 then		--长子权
		d.Tecro_birthright_counter = 1
	end
	if (list.assassin or 0) > 0 then
		d.Tecro_linked_assassin_eye = function(ent,spear,player,dir)
			local q2 = Isaac.Spawn(2,0,0,spear.Position,dir:Normalized() * 10 * player.ShotSpeed,player):ToTear()
			q2.Visible = false
			q2.CollisionDamage = player.Damage * 0.75
			q2.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			q2.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
			Attribute_holder.try_hold_and_rewind_attribute(q2,"Height",q2.Height,29)
			Attribute_holder.try_hold_and_rewind_attribute(q2,"FallingSpeed",q2.FallingSpeed,29)
			local d2 = q2:GetData()
			d2.Ignore_me_flag = true
			d2.is_assassin = true
			delay_buffer.addeffe(function(params)
				if q2:Exists() and not q2:IsDead() then
					q2:Remove()
				end
			end,{},30)
			return q2
		end
	end
	if tearflag & BitSet128(1<<52,0) == BitSet128(1<<52,0) then
		d.Tecro_belial_counter = 1
	end
	if info.blood_oath then
		d.Tecro_blood_oath_counter = 1
	end
	if info.krampus and (list.krampus or 0) > 0 then
		if auxi.check_rand(player.Luck,50,10,9) then
			d.Tecro_linked_krampus = function(ent,spear,player,dir)
				local should_rotate = math.random(1000) > 700
				if should_rotate then should_rotate = math.random(2) * 2 - 3 end
				local ret = {}
				local cnt = 4
				for i = 1,cnt do
					local q = Isaac.Spawn(7,1,0,spear.Position,Vector(0,0),player):ToLaser()
					q.CollisionDamage = player.Damage * 1.5
					q.Angle = dir:GetAngleDegrees() + i * 360 / cnt
					q.Timeout = 15
					if should_rotate ~= nil then q.Timeout = 30 end
					q.Parent = spear
					q:GetData().Tecro_should_rotate = should_rotate
					q:GetData().Tecro_delta_angle = i * 360 / cnt
					table.insert(ret,#ret + 1,q)
				end
				return ret
			end
		end
	end
	if info.sacri then
		d.Tecro_linked_sacri = function(ent,spear,player,dir)
			local pm = {
				cooldown = 30,
				Accerate = 2.5,
				player = player,
				Color = player.TearColor,
			}
			local rand = math.random(15) - 8
			local q2 = auxi.fire_knife(spear.Position,18 * player.ShotSpeed * auxi.MakeVector(dir:GetAngleDegrees() + rand),player.Damage * charge,nil,auxi.deepCopy(pm))
			local s2 = q2:GetSprite()
			s2:Load("gfx/Knife_loader.anm2",true)
			s2:Play("Idle",true)
			if rand < 0 then 
				q2:GetSprite().FlipX = true 
				q2.RotationOffset = 180 - q2.RotationOffset
			end
			delay_buffer.addeffe(function(params)
				local dir = params.dir
				local mnil = q2.Parent
				if mnil then
					mnil.Velocity = mnil.Velocity:Length() * auxi.MakeVector(dir:GetAngleDegrees())
				end
			end,{dir = dir,},5)
			for k = 1,4 do
				delay_buffer.addeffe(function(params)
					local dir = params.dir
					if q2:GetSprite().FlipX then
						q2.RotationOffset = 180 - dir:GetAngleDegrees()
					else
						q2.RotationOffset = dir:GetAngleDegrees()
					end
				end,{dir = dir,},5 + k)
			end
			local q3 = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL, 0, ent.Position, Vector(0,0), ent):ToEffect()
			q2:GetData().tail = q3
			q3.PositionOffset = Vector(0,0)
			q3:GetSprite().Color = Color(1,0,0,1)
			q3.MinRadius = 0.07
			q3.MaxRadius = 0.07
			q3.SpriteScale = Vector(1,1)
			q3.Parent = q2
			for k = 1,6 do
				delay_buffer.addeffe(function(params)
					local q = params.q
					if q and q:Exists() then
						local source = q.Parent
						if source == nil then return end
						local targ = auxi.get_by_nearest_enemy(q.Position)
						if targ then
							local dir = targ.Position - q.Position
							source.Velocity = source.Velocity * 0.3 + (dir) * 0.4 * 0.2
						end
						if q:GetSprite().FlipX then
							q.RotationOffset = 180 - source.Velocity:GetAngleDegrees()
						else
							q.RotationOffset = source.Velocity:GetAngleDegrees()
						end
					end
				end,{q = q2,},7 + k)
			end
			return q2
		end
	end
	if info.star then
		d.Tecro_linked_star = function(ent,spear,player,dir)
			local q = player:FireTear(spear.Position,dir * player.ShotSpeed * 10,true,true,true)
			local s2 = q:GetSprite()
			s2:Load("gfx/player/tecro/Star_tear.anm2",true)
			s2:Play("Idle",true)
			q.CollisionDamage = player.Damage * 0.5
			q.TearFlags = q.TearFlags & (~(BitSet128(1<<60,0)))
			q.PositionOffset = Vector(0,-5)
		end
	end
	if info.firename then d.head:Play(info.firename,true) end
end

function item.fire_birth_right_spear(player,pos,dir,params)
	params = params or {}
	local addertearflag = BitSet128(0,0) | (params.TearFlags or BitSet128(0,0))		--自带跟踪防止跑偏
	local ignoretearflag = (TearFlags.TEAR_LASERSHOT | BitSet128(1<<17,0)) | (params.IgnoreTearFlags or BitSet128(0,0))
	local q = auxi.fire_spear(nil,nil,{player = player,dir = dir:GetAngleDegrees(),})
	local d = q:GetData()
	d.tecro_dir_offset = dir:GetAngleDegrees() - (player:GetData().now_dir or Vector(0,1)):GetAngleDegrees()
	d.tecro_remove_then = true
	d.record_spear_charge = 1.5
	d.birth_init_pos = pos
	d.Tecro_this_color = params.color
	d.should_not_reload = true
	reload_spear(q,player,{spear_type = params.spear_type,})
	local source = q.Parent
	source.Position = pos
	local tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,0)
	q.TearFlags = (tearHitParams.TearFlags | addertearflag) & (~ignoretearflag)
	add_addition_to_spear(q,player,{dir = dir,TearFlags = addertearflag,charge = 1,should_not_reload = true,list = params.list,birth = true,})
	return q
end

local function work_on_Tecro_multi_attack_params(player,params)
	params = params or {}
	local d = player:GetData()
	d.Tecro_list = d.Tecro_list or auxi.get_Tecro_list(player)
	local dir = params.dir or d.now_dir or Vector(0,1)
	local multishot_of_player = params.multishot
		or auxi.get_Tecro_multishots(player,d.Tecro_list,{allowrand = true,cnt1 = params.cnt1,})
	for u,v in pairs(multishot_of_player) do
		local adderdir = v.dir or 0
		local addertearflag = (v.tearflag or BitSet128(0,0)) | (params.TearFlags or BitSet128(0,0))
		local shot_dir = auxi.MakeVector(dir:GetAngleDegrees() + adderdir)
		local q = auxi.fire_spear(params.origin,nil,{
			player = player,
			dir = dir:GetAngleDegrees() + adderdir,
			source = params.source,
		})
		local d2 = q:GetData()
		d2.tecro_dir_offset = adderdir
		d2.tecro_remove_then = true
		if params.charge then d2.record_spear_charge = params.charge end
		-- 宝宝/邪眼等脱主枪齐射：无玩家蓄力态时 TecroNil 会在 remove_cnt<0.1 时立刻删枪。
		-- 预置满伸展 + birth 锚点，走收回动画而非空放。
		if params.origin or params.advanced_familiar_copy then
			local origin = params.origin
			if origin then
				d2.birth_init_pos = Vector(origin.X, origin.Y)
			end
			d2.record_spear_charge = math.max(0.5, tonumber(d2.record_spear_charge) or tonumber(params.charge) or 1)
			d2.tecro_remove_cnt = 1
			d2.on_record_spear_dir = shot_dir
		end
		local tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
		q.TearFlags = tearHitParams.TearFlags & (~TearFlags.TEAR_LASERSHOT) | addertearflag
		add_addition_to_spear(q,player,{dir = shot_dir,TearFlags = addertearflag,charge = params.charge,})
	end
	if not params.advanced_familiar_copy then
		local CharacterFamiliars = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")
		CharacterFamiliars.for_each_attack_copy(player, function(_, mul, origin, _, aim_dir)
			work_on_Tecro_multi_attack_params(player, {
				dir = (aim_dir and aim_dir:Length() >= 0.01) and aim_dir or dir,
				cnt1 = params.cnt1,
				TearFlags = CharacterFamiliars.apply_familiar_tear_flags(player, params.TearFlags),
				multishot = multishot_of_player,
				charge = (tonumber(params.charge) or 1) * mul,
				origin = origin,
				advanced_familiar_copy = true,
			})
		end)
		do
			local ok, EvilEye = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Evil_Eye_holder")
			if ok and EvilEye and EvilEye.notify_player_attack then
				EvilEye.notify_player_attack(player, dir)
			end
		end
	end
	if not params.advanced_familiar_copy then Isaacs_Tear_holder.add_tear(player) end		--眼泪盆
	if not params.advanced_familiar_copy and d.Tecro_list.greed_head and d.Tecro_list.greed_head > 0 then			--理财眼
		d.greed_head_delay = (d.greed_head_delay or 0) + 1
		if d.greed_head_delay >= 10 then
			d.greed_head_delay = 0
			item.fire_birth_right_spear(player,player.Position,dir,{color = Color(1,0.69,0,1,1,0.69,0),TearFlags = BitSet128(1<<53,0),})
			player:AddCoins(-1)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_CASH_REGISTER,1,1,false,0,2)
		end
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
		save.elses.Tecro_ludo_buff = save.elses.Tecro_ludo_buff or {}
		save.elses.Tecro_knife_buff = save.elses.Tecro_knife_buff or {}
	else
		for u,v in pairs(item.kill_lists) do save.elses[v.name] = nil end
		save.elses.Tecro_ludo_buff = {}
		save.elses.Tecro_knife_buff = {}
		item.Tecro_middle_time_holder = 0 
		item.Tecro_middle_holder = false
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
	if ent:ToNPC() and amt >= ent.HitPoints and not ent:HasMortalDamage() and source and source.Type == 8 and source.Variant == enums.Entities.Tecro_Spear then
		ent = ent:ToNPC()
		if ent.ParentNPC == nil then
			local check_name = tostring(ent.Type).."."..tostring(ent.Variant)
			local info = item.kill_lists[check_name]
			if info then
				if save.elses[info.name] ~= true then
					local language = Options.Language
					local info2 = (((item.Special_Des[language] or {})["PlayerDesc"] or {})["Killlist"] or {})[check_name]
					if info2 then
						item_displaying_holder.check_and_description("PlayerDesc",check_name,info2.Name,info2.Description,player)
					end
				end
				save.elses[info.name] = true
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if item.Tecro_middle_time_holder >= 0 then item.Tecro_middle_time_holder = (item.Tecro_middle_time_holder or 0) - 1 end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = nil,
Function = function(_,collid, itemRng, player, useFlags, activeSlot, customVarData)
	if player:GetName() == "Tecro" then
		local d = player:GetData()
		if item.sharp_items[collid] ~= nil then
			d.temp_sharp_rate = (d.temp_sharp_rate or 0) + item.sharp_items[collid]
		end
		if collid == CollectibleType.COLLECTIBLE_KAMIKAZE then
			local spears = auxi.getothers(Isaac.GetRoomEntities(),8,enums.Entities.Tecro_Spear,nil)
			local tearflag = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1)).TearFlags
			for u,v in pairs(spears) do
				local d = v:GetData()
				local info = item.sprite_loader[(d.spear_type or 1)] or item.sprite_loader[1]
				if info.kamikaze then Game():BombExplosionEffects(v.Position,player.Damage * 2 + 60,tearflag,v:GetSprite().Color,player,1,false,false) end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		d.temp_sharp_rate = 0
		d.damaged_sharp_rate = nil
		d.ludo_init_pos = nil
		d.Tecro_Tech0_lst_pos = nil
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_NPC_COLLISION, params = nil,
Function = function(_,ent, col,low)
	local player = col:ToPlayer()
	if player and player:GetName() == "Tecro" then
		local d = player:GetData()
		local tg = ent:GetData().Tecro_spear_targeted_player
		if tg and auxi.check_for_the_same(tg,player) then
			return false
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_,ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if player and player:GetName() == "Tecro" then
		local d = player:GetData()
		local list = d.Tecro_list or auxi.get_Tecro_list(player)
		d.damaged_sharp_rate = true
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CURSED_EYE) and not auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BLACK_CANDLE) then
			if (d.Tecro_spear_Charge_Bar_buff or 0) > 0 and (d.Tecro_spear_Charge_Bar_buff or 0) < (d.Tecro_spear_Charge_Bar_buff_mx or 0) then
				player:AnimateTeleport(true)
				player:UseActiveItem(CollectibleType.COLLECTIBLE_TELEPORT,false,true,false,false)
				d.Tecro_spear_Charge_Bar_buff = 0
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.TWISTED_BABY,
Function = function(_,ent)
	local player = ent.Player
	if player == nil then return end
	if player:GetName() == "Tecro" then
		local d2 = player:GetData()
		if d2.linked_spear and d2.linked_spear.Position.X < 1500 then		--除却初始化
			local spear = d2.linked_spear
			if ent.Parent == nil or ent.Parent:Exists() == false or ent.Parent:IsDead() or (ent.Parent.Type == 1 and ent.Parent.Variant == 0) then
				ent.Parent = spear
			end
			if ent.SubType == 0 then 
				local eent = ent.Child
				if eent and eent:Exists() then
					--print(eent.Type.." "..eent.Variant)
					local tdir = auxi.MakeVector(spear.RotationOffset)
					local tg_pos = spear.Position + auxi.get_delta_length(spear.Position,eent.Position,tdir) * auxi.Get_rotate(tdir):Normalized() + auxi.get_alpha_length(spear.Position,eent.Position,tdir) * d2.now_dir:Normalized()
					local dg_pos = tg_pos * 0.5 + ent.Position * 0.5
					--print(auxi.get_delta_length(spear.Position,eent.Position,d2.now_dir))
					--print(auxi.Get_rotate(d2.now_dir):Normalized())
					ent.Position = dg_pos
					ent:FollowPosition(dg_pos)
				end
			end
		else
			if ent.Parent == nil or ent.Parent:Exists() == false then ent.Parent = player ent.Position = player.Position if ent.Child then ent.Child.Position = player.Position end end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local d = player:GetData()
	if player:GetName() == "Tecro" then
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			local list = d.Tecro_list or auxi.get_Tecro_list(player)
			local mx_cnt = d.Tecro_spear_Charge_Bar_buff_mx or 30
			Charging_Bar_holder.render_me(player,{name1 = "Tecro_spear",name2 = "Tecro_spear",name3 = "Tecro_spear",loadname = "gfx/effects/chargebar/chargebar_Tecro.anm2",
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
			if (list.anti or 0) > 0 then
				Charging_Bar_holder.render_me(player,{name1 = "Tecro_spear_anti",name2 = "Tecro_spear_anti",name3 = "Tecro_spear_anti",loadname = "gfx/effects/chargebar/chargebar_Tecro_Anti.anm2",
					check1 = nil,
					check2 = function(val,ent)
						return val >= 5 * mx_cnt
					end,
					check3 = function(val,ent)
						return math.ceil(val/mx_cnt * 100 /5)
					end,
					signal1 = function(ent)
					end,
				})
			end
			if (list.nepton or 0) > 0 then
				Charging_Bar_holder.render_me(player,{name1 = "Tecro_spear_nep",name2 = "Tecro_spear_nep",name3 = "Tecro_spear_nep",loadname = "gfx/effects/chargebar/chargebar_Tecro_Nep.anm2",
					check1 = nil,
					check2 = function(val,ent)
						return val >= 0.5 * mx_cnt
					end,
					check3 = function(val,ent)
						return math.ceil(val/(mx_cnt * 0.5) * 100)
					end,
					signal1 = function(ent)
					end,
				})
			end
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CHOCOLATE_MILK) then
				Charging_Bar_holder.render_me(player,{name1 = "Tecro_spear_cho",name2 = "Tecro_spear_cho",name3 = "Tecro_spear_cho",loadname = "gfx/effects/chargebar/chargebar_Tecro_Cho.anm2",
					check1 = function(val,ent)
						return (d["Tecro_spear_Charge_Bar_buff"] or 0) >= mx_cnt
					end,
					check2 = function(val,ent)
						return (d["Tecro_spear_Charge_Bar_buff"] or 0) >= 2 * mx_cnt
					end,
					check3 = function(val,ent)
						return math.ceil(((d["Tecro_spear_Charge_Bar_buff"] or 0) - mx_cnt)/mx_cnt * 100)
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
		Charging_Bar_holder.remove_charge_bar(player,"Tecro_spear_anti")
	end
	if collid == CollectibleType.COLLECTIBLE_CHOCOLATE_MILK and count < 0 then
		Charging_Bar_holder.remove_charge_bar(player,"Tecro_spear_cho")
	end
	if collid == CollectibleType.COLLECTIBLE_NEPTUNUS and count < 0 then
		Charging_Bar_holder.remove_charge_bar(player,"Tecro_spear_nep")
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_,ent,offset)
	local d = ent:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		local mx_cnt = d.Tecro_spear_hold_time_Charge_Bar_buff_mx or 30
		Charging_Bar_holder.render_me(ent,{name1 = "Tecro_spear_hold_time",name2 = "Tecro_spear_hold_time",name3 = "Tecro_spear_hold_time",loadname = "gfx/effects/chargebar/chargebar_Tecro2.anm2",
			check1 = nil,
			check2 = function(val,ent)
				return val > mx_cnt
			end,
			check3 = function(val,ent)
				return math.ceil(val/mx_cnt * 100)
			end,
			signal1 = function(ent)
			end,
		})
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d.Tecro_spear_hold_time_Charge_Bar_buff and d.Tecro_spear_hold_time_Charge_Bar_buff_mx then
		if ent:IsBoss() then
			d.Tecro_spear_hold_time_Charge_Bar_buff = math.max(0,(d.Tecro_spear_hold_time_Charge_Bar_buff or 0) - d.Tecro_spear_hold_time_Charge_Bar_buff_mx / (30 * 10))
		else
			d.Tecro_spear_hold_time_Charge_Bar_buff = math.max(0,(d.Tecro_spear_hold_time_Charge_Bar_buff or 0) - d.Tecro_spear_hold_time_Charge_Bar_buff_mx / 90)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if player:GetName() == "Tecro" then
		local d = player:GetData()
		local s = player:GetSprite()
		local ctrlid = player.ControllerIndex
		local gdir = auxi.ggdir(player,true,false,false,nil,{real = true})
		d.now_dir = d.now_dir or Vector(0,1)
		gdir = check_mouse_work(player,gdir) or gdir
		d.check_dir = gdir
		if d.linked_spear == nil or d.linked_spear:Exists() == false or d.linked_spear:IsDead() then
			d.linked_spear = auxi.fire_spear(nil,nil,{player = player,dir = d.now_dir:GetAngleDegrees(),})
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
		if player.TearFlags & BitSet128(1<<8,0) == BitSet128(1<<8,0) then			--镜子
			local rec = d.Tecro_reflection_record or 0
			d.Tecro_reflection_record = rot
			if rec * rot > 0 then
				rot = rot * math.cos((d.Tecro_reflection_counter or 0) * 5 * 3.14/180)
				d.Tecro_reflection_counter = (d.Tecro_reflection_counter or 0) + 1
			else
				d.Tecro_reflection_counter = 0
			end
		end
		if player.TearFlags & BitSet128(1<<10,0) == BitSet128(1<<10,0) then			--弯虫
			if math.abs(rot) > 0 then
				rot = rot * (math.cos((d.Tecro_wiggle_counter or 0) * 3 * 3.14/180) + 0.1)
				d.Tecro_wiggle_counter = (d.Tecro_wiggle_counter or 0) + 1
				d.Tecro_wiggle_counter = (d.Tecro_wiggle_counter or 0) + 1
			else
				d.Tecro_wiggle_counter = 0
			end
		end
		if player.TearFlags & BitSet128(1<<30,0) == BitSet128(1<<30,0) then			--鏂规尝铏?
			if math.abs(rot) > 0 then
				rot = rot * (math.cos((d.Tecro_hook_counter or 0) * 8 * 3.14/180) + 0.2)
				d.Tecro_hook_counter = (d.Tecro_hook_counter or 0) + 1
				d.Tecro_hook_counter = (d.Tecro_hook_counter or 0) + 1
			else
				d.Tecro_hook_counter = 0
			end
		end
		if player.TearFlags & BitSet128(1<<26,0) == BitSet128(1<<26,0) then			--环虫
			if math.abs(rot) > 0 then
				rot = rot * (math.sin((d.Tecro_ring_counter or 0) * 5 * 3.14/180) + 1)
				d.Tecro_ring_counter = (d.Tecro_ring_counter or 0) + 1
			else
				d.Tecro_ring_counter = 0
			end
		end
		if player.TearFlags & BitSet128(1<<46,0) == BitSet128(1<<46,0) then			--榛戣櫕
			d.Tecro_Ouroboros_counter = (d.Tecro_Ouroboros_counter or 0) * 0.97 + rot * 0.03
			rot = d.Tecro_Ouroboros_counter
		end
		if math.abs(d.now_rot_vel * rot) > 0.5 then
			if rot * d.now_rot_vel > 0 then
				d.now_rot_vel = d.now_rot_vel * 0.9 + rot * alpha * 0.1
			else
				d.now_rot_vel = d.now_rot_vel * 0.4 + rot * alpha * 0.1
			end
		else
			if rot == 0 then
				d.now_rot_vel = d.now_rot_vel * 0.8
			else
				d.now_rot_vel = rot * alpha * 0.1
			end
		end
		d.now_rot_set = rot
		d.now_vel_alpha = math.max(0.001,alpha)
		
		d.Tecro_spear_Charge_Bar_buff = (d.Tecro_spear_Charge_Bar_buff or 0)
		d.Tecro_spear_Charge_Bar_buff_mx = get_max_delay(player)			--寤惰繜涓婇檺
		local mxn = 1
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CHOCOLATE_MILK) then mxn = 2 end
		d.now_flip = d.now_flip or 1
		if dis > 0 then							--蓄力、打断
			d.now_flip = -1
			if auxi.g_dir_can_work(player) then
				if d.Tecro_spear_state <= 0 then
					d.Tecro_spear_Charge_Bar_buff = math.min(d.Tecro_spear_Charge_Bar_buff_mx * mxn,d.Tecro_spear_Charge_Bar_buff + 1)
					if (d.Tecro_list.nepton or 0) > 0 then 
						d.Tecro_spear_Charge_Bar_buff = math.max(d.Tecro_spear_Charge_Bar_buff,d.Tecro_spear_nep_Charge_Bar_buff or 0)
						d.Tecro_spear_nep_Charge_Bar_buff = 0
					end
					if (d.Tecro_list.anti or 0) > 0 then			--反重力
						d.Tecro_spear_anti_Charge_Bar_buff = math.min(d.Tecro_spear_Charge_Bar_buff_mx * 5,(d.Tecro_spear_anti_Charge_Bar_buff or 0) + 1)
						if d.Tecro_spear_anti_Charge_Bar_buff == d.Tecro_spear_Charge_Bar_buff_mx * 5 then
							work_on_Tecro_multi_attack_params(player,{dir = dir,charge = 1,cnt1 = 1,})
							d.Tecro_spear_anti_Charge_Bar_buff = 0
						end
					else
						d.Tecro_spear_anti_Charge_Bar_buff = nil
					end
				else
					d.Tecro_spear_Charge_Bar_buff = 0
				end
				d.Tecro_spear_state = -1
			end
		else
			d.now_flip = 1
			if auxi.g_dir_can_work(player) then
				if d.Tecro_spear_Charge_Bar_buff >= d.Tecro_spear_Charge_Bar_buff_mx * 0.15 and (d.Tecro_spear_state == 0 or d.Tecro_spear_state == -1) then		--蓄力后发射，发射时记录各状态
					d.Tecro_spear_state = 1
					d.tecro_rev_counter = - (d.tecro_rev_counter or 1)
					
					d.Tecro_spear_charge = math.min(mxn,math.max(0.1,d.Tecro_spear_Charge_Bar_buff / d.Tecro_spear_Charge_Bar_buff_mx))
					d.Tecro_list = auxi.get_Tecro_list(player)
					if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CURSED_EYE) then 			--连续5发
						local cnt = math.min(5,math.floor(d.Tecro_spear_charge * 5))
						local now_charge = math.max(1,d.Tecro_spear_charge)
						work_on_Tecro_multi_attack_params(player,{dir = dir,charge = now_charge,})
						for i = 1,cnt - 1 do
							delay_buffer.addeffe(function(params)
								work_on_Tecro_multi_attack_params(player,{dir = dir,charge = now_charge * (i * 0.2 + 1),cnt1 = 1,})
							end,{},i * 5)
						end
						add_addition_to_spear(d.linked_spear,player,{})
					else
						if d.Tecro_spear_charge >= 1 then
							work_on_Tecro_multi_attack_params(player)
							add_addition_to_spear(d.linked_spear,player,{})
						elseif auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CHOCOLATE_MILK) and d.Tecro_spear_charge > 0.3 then
							work_on_Tecro_multi_attack_params(player,{charge = d.Tecro_spear_charge,})
							add_addition_to_spear(d.linked_spear,player,{charge = d.Tecro_spear_charge,})
						end
					end
				end
				if dis < 0 and (d.Tecro_spear_state == 0 or d.Tecro_spear_state == -1) then				--直接发射
					d.Tecro_spear_state = 3
					d.Tecro_spear_charge = math.min(1,math.max(0.1,d.Tecro_spear_Charge_Bar_buff / d.Tecro_spear_Charge_Bar_buff_mx))
					d.Tecro_list = auxi.get_Tecro_list(player)
				end
				d.Tecro_spear_Charge_Bar_buff = 0
				if d.Tecro_spear_state == -1 then d.Tecro_spear_state = 0 end
				if (d.Tecro_list.nepton or 0) > 0 then
					d.Tecro_spear_nep_Charge_Bar_buff = math.min(d.Tecro_spear_Charge_Bar_buff_mx * 0.5,(d.Tecro_spear_nep_Charge_Bar_buff or 0) + 0.3)
				end
				if (d.Tecro_list.anti or 0) > 0 then
					d.Tecro_spear_anti_Charge_Bar_buff = nil
				end
			end
		end
		if dis < 0 then
			d.now_dir_set_on = true
		else
			d.now_dir_set_on = nil
		end
		for i = 1,1 do if (d.Tecro_list.ludo or 0) > 0 then
			local room = Game():GetRoom()
			if dis < 0 then 
				d.ludo_init_pos = room:GetClampedPosition((d.ludo_init_pos or player.Position) + dir:Normalized() * 5 * player.ShotSpeed,0)
			elseif dis > 0 then
				if d.ludo_init_pos == nil then break end
				d.ludo_init_pos = d.ludo_init_pos * 0.5 + player.Position * 0.5
				if (d.ludo_init_pos - player.Position):Length() < 30 then d.ludo_init_pos = nil end
			end
		end end
		
		d.now_dir = auxi.MakeVector(angle + d.now_rot_vel)
		if player.Velocity:Length() > 12 then		--冲刺状态
			if d.ludo_init_pos then d.ludo_init_pos = d.ludo_init_pos * 0.5 + player.Position * 0.5 + player.Velocity * 2 end
			d.now_dir = (d.now_dir * 0.9 + player.Velocity:Normalized()):Normalized()
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if player:GetName() == "Tecro" then
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
		if cacheFlag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 0.88
		end
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			if player:GetData().linked_spear and item.sprite_loader[player:GetData().linked_spear:GetData().spear_type or 1].lamb and player:HasTrinket(TrinketType.TRINKET_CURVED_HORN) then 
				player.Damage = player.Damage * 1.5
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_INIT, params = nil,
Function = function(_,ent)
	if ent.Variant == enums.Entities.Tecro_Spear then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local player = d.player or Game():GetPlayer(0)
		reload_spear(ent,player)
		s:SetFrame("IdleUp",0)
	end
	if ent.Variant == enums.Entities.Tecro_Needle then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local player = d.player or Game():GetPlayer(0)
		reload_needle(ent,player)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.TecroNeedleNil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local room = Game():GetRoom()
	local player = d.player
	if player == nil then return end
	local needle = d.needle
	if needle == nil then return end
	local d3 = needle:GetData()
	local d2 = player:GetData()
	local spear = d2.linked_spear
	if spear == nil then return end
	local linker = d3.link_parent
	if linker == nil then return end
	local dir_vel = (d2.now_rot_vel or 0)
	local delta = math.abs(dir_vel)/(d2.now_vel_alpha or 1)
	
	local init_pos = d3.init_pos or ent.Position
	local focus_pos = ent.Position
	local mx_vel = nil
	local cross_out = nil
	if d2.Tecro_spear_state == -1 or d2.Tecro_spear_state == 0 and not d2[player_Tecrorun.own_key.."Csection"] then
		if d.linked_enemy_target then
			local tg = d.linked_enemy_target
			time_free(tg) 
			d.linked_enemy_target = nil
		end
		d.nolinked_enemy_target = nil
	else
		local n_enemy = auxi.getenemies(Isaac.GetRoomEntities())
		local tg = nil
		for u,v in pairs(n_enemy) do
			if (tg == nil or (v.Position - ent.Position):Length() < (tg.Position - ent.Position):Length()) then tg = v end
		end
		if tg then
			d.nolinked_enemy_target = tg
		end
		if (auxi.check_all_exists(d.linked_enemy_target) ~= true) or (auxi.check_for_the_same(ent,d.linked_enemy_target:GetData().Tecro_linked_ent) == false) then
			if d.linked_enemy_target ~= nil then time_free(d.linked_enemy_target,player) d.linked_enemy_target = nil end
			local tg = nil
			for u,v in pairs(n_enemy) do
				if (v:GetData().Tecro_linked_ent == nil and can_be_impaled(v,player) and (v:GetData().Tecro_spear_hold_time_Charge_Bar_buff or 0) < 5)
					and (tg == nil or (v.Position - ent.Position):Length() < (tg.Position - ent.Position):Length() and (v.Position - ent.Position):Length() < (v.Position - linker.Position):Length()) then
					tg = v
				end
			end
			if tg then
				tg:GetData().Tecro_linked_ent = ent
				d.linked_enemy_target = tg
			end
		else
			local tg = d.linked_enemy_target
			local dd = tg:GetData()
			if dd.time_stopped == nil and (tg.Position - focus_pos):Length() > 30 then
				init_pos = tg.Position
			else
				if dd.time_stopped == nil then 
					stop_time(tg,player) 
				end
				dd.Tecro_spear_hold_time_Charge_Bar_buff = (dd.Tecro_spear_hold_time_Charge_Bar_buff or 0) + 1
				if (dd.Tecro_spear_hold_time_Charge_Bar_buff or 60) > (dd.Tecro_spear_hold_time_Charge_Bar_buff_mx or 30) then
					time_free(tg)
					d.linked_enemy_target = nil
				end
				tg.Position = needle.Position
				init_pos = spear.Position
				mx_vel = 10
			end
		end
		if (auxi.check_all_exists(d.linked_enemy_target) ~= true) and (auxi.check_all_exists(d.nolinked_enemy_target) == true) then
			init_pos = d.nolinked_enemy_target.Position
			mx_vel = 20
			cross_out = true
		end
	end
	
	local dis = init_pos - focus_pos
	if cross_out then
		d3.linked_target = d.nolinked_enemy_target
		--ent.Velocity = ent.Velocity * 0.8 + auxi.MakeVector(needle.RotationOffset) * math.sqrt(dis:Length()) * 0.2
		--ent.Velocity = ent.Velocity * (0.9 - delta * 0.4) + player.Velocity * 0.05 + dis:Normalized() * (0.05 + delta * 0.3) * math.sqrt((dis:Length() + math.min(dis:Length(),40)) * math.max(1,ent.Velocity:Length() * 0.3))
	else
		d3.linked_target = nil
		--ent.Velocity = ent.Velocity * (0.8 - delta * 0.3) + player.Velocity * 0.1 + dis:Normalized() * (0.15 + delta * 0.3) * math.sqrt((dis:Length() + math.min(dis:Length(),40)) * math.max(1,ent.Velocity:Length() * 0.1))
	end
	ent.Velocity = dis:Normalized() * math.min(35,dis:Length() * 0.3)
	if mx_vel then ent.Velocity = ent.Velocity:Normalized() * math.min(mx_vel,ent.Velocity:Length()) end
	--spear.RotationOffset = spear.RotationOffset * 0.9 + ent.Velocity:GetAngleDegrees() * 0.1
	
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_RENDER, params = nil,
Function = function(_,ent,offset)
	if ent.Variant == enums.Entities.Tecro_Spear then
		local d = ent:GetData()
		local s = ent:GetSprite()
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			local player = d.player or Game():GetPlayer(0)
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

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.TecroNil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local room = Game():GetRoom()
	
	d.Tecro_inner_frame = (d.Tecro_inner_frame or 0) + 1
	local player = d.player or Game():GetPlayer(0)
	if auxi.check_all_exists(player) then
		local spear = d.spear
		if spear == nil then return end
		local d3 = spear:GetData()
		local d2 = player:GetData()
		d2.Tecro_spear_state = d2.Tecro_spear_state or 0
		d2.Tecro_spear_target = d2.Tecro_spear_target or {}
		local list = d2.Tecro_list or {}
		local tail = spear:GetData().tail
		local info = item.sprite_loader[(d3.spear_type or 1)] or item.sprite_loader[1]
		local init_pos = d3.birth_init_pos or d2.ludo_init_pos or player.Position
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
		
		for i = 1,1 do if spear.TearFlags & BitSet128(1<<2,0) == BitSet128(1<<2,0) then
			if d2.Tecro_spear_state == 4 then break end
			local nearest = auxi.get_by_nearest_enemy(spear.Position)
			if nearest == nil then break end
			local dis = nearest.Position - init_pos
			local dir_leg = math.min(8,dis:Length()/20 + 1)
			local dir_aid = auxi.get_correct_angle(dis:GetAngleDegrees() - (dir:GetAngleDegrees() + (d3.homing_flying_charge or 0) + (d3.tecro_dir_offset or 0)))
			local adder = auxi.get_id(dir_aid) * math.min(dir_leg,math.abs(dir_aid))
			if d2.now_rot_set ~= 0 and d2.now_rot_set * adder < 0 then adder = 0 end 
			d3.homing_flying_charge = (d3.homing_flying_charge or 0) + adder
		end end
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
		if item.Tecro_middle_holder then 
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
		for i = 1,1 do if d3.tecro_remove_then then
			if spear.TearFlags & BitSet128(1<<17,0) == BitSet128(1<<17,0) then
				if d3.Tecro_anti_counter == nil and d2.Tecro_spear_state == -1 then
					d3.Tecro_anti_record_pos = d3.Tecro_anti_record_pos or ent.Position
					wait_me = true
					break 
				else
					if d3.Tecro_anti_counter == nil then if info.firename and d3.head then d3.head:Play(info.firename,true) end end
					d3.Tecro_anti_counter = true
				end
				init_pos = d3.birth_init_pos or d3.Tecro_anti_record_pos or init_pos
			end
			if d3.tecro_remove_new == nil then
				d3.tecro_remove_new = true
				d3.record_spear_charge = d3.record_spear_charge or d2.Tecro_spear_charge or 0.2
				d3.tecro_dir_delta = 0
				d3.record_spear_dir = dir
			end
			if (d2.Tecro_spear_state == 1 and d3.tecro_remove_now == nil) then
				d3.record_spear_charge = math.max(0,d3.record_spear_charge + 0.1)
				local rrange = get_spear_range(player,1) 
				local tttg_pos = room:GetClampedPosition(init_pos + ddir * rrange * d3.record_spear_charge * 1.2, - rrange * 1.3)
				local dddis = (tttg_pos - ent.Position)
				if dddis:Length() > rrange * 7 then 
					ent.Position = tttg_pos
					ent.Velocity = ent.Velocity:Normalized() * player.ShotSpeed * 3
				else
					ent.Velocity = ent.Velocity * 0.4 + player.Velocity * 0.15 + dddis:Normalized() * dddis:Length() * 0.15 * math.sqrt(math.max(1,ent.Velocity:Length() * 0.6))
				end
			else
				d3.tecro_remove_now = true
				if (d3.tecro_remove_cnt or 0) < 0.1 then
					spear:Remove()
					ent:Remove()
					return
				else
					d3.record_spear_charge = math.max(0,(d3.record_spear_charge) - (1.1 - (d3.tecro_remove_cnt or 0)) * 0.2)
					local rrange = get_spear_range(player,1) 
					--ddir = d3.record_spear_dir:Length() * auxi.MakeVector(d3.record_spear_dir:GetAngleDegrees() + d3.tecro_dir_offset + (d3.planet_flying_charge or 0))	
					local tttg_pos = room:GetClampedPosition(init_pos + ddir * rrange * d3.record_spear_charge * 1.2, - rrange * 1.3)
					local dddis = (tttg_pos - ent.Position)
					if dddis:Length() > rrange * 7 then 
						ent.Position = tttg_pos
						ent.Velocity = ent.Velocity:Normalized() * player.ShotSpeed * 3
					else
						ent.Velocity = ent.Velocity * 0.4 + player.Velocity * 0.15 + dddis:Normalized() * dddis:Length() * 0.15 * math.sqrt(math.max(1,ent.Velocity:Length() * 0.6))
					end
				end
			end
		else
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
			elseif d2.Tecro_spear_state == 1 then		--蓄力出枪
				d2[item.own_key.."Record_spear_shot"] = 5
				if d2.now_dir_set_on ~= nil then
					d2.Tecro_spear_charge = math.min((d2.Tecro_spear_charge or 0.06) + 0.12,math.max(d2.Tecro_spear_charge,1.5))
				end
				if ddis:Length() > range * 7 then 
					ent.Position = ttg_pos
					ent.Velocity = ent.Velocity:Normalized() * player.ShotSpeed * 3
				else
					ent.Velocity = ent.Velocity * 0.4 + player.Velocity * 0.15 + ddis:Normalized() * (ddis:Length() + 5) * 0.15 * math.sqrt(math.max(1,ent.Velocity:Length() * 0.6))
				end
				
				local ddisn = ddis:Normalized()
				if ddisn.X * dir.X + ddisn.Y * dir.Y < -0.3 then
					if d2.now_dir_set_on == nil then
						d2.Tecro_spear_state = 2
					else
						d2.Tecro_spear_state = 3
					end
				end
			elseif d2.Tecro_spear_state == 2 then		--鏀跺洖
				if d2.now_dir_set_on == nil then
					d2.Tecro_spear_charge = d2.Tecro_spear_charge * 0.8
				else
					d2.Tecro_spear_state = 3
				end
				if ddis:Length() > range * 7 then 
					ent.Position = ttg_pos
					ent.Velocity = ent.Velocity:Normalized() * player.ShotSpeed * 3
				else
					ent.Velocity = ent.Velocity * 0.5 + player.Velocity * 0.1 + ddis:Normalized() * ddis:Length() * 0.1 * math.sqrt(math.max(1,ent.Velocity:Length() * 0.3))
				end
				if d2.Tecro_spear_charge < 0.15 then
					d2.Tecro_spear_state = 0
				end
			elseif d2.Tecro_spear_state == 3 then		--正常出枪
				if d2.now_dir_set_on == nil then 
					d2.Tecro_spear_state = 2
				else
					d2.Tecro_spear_charge = math.min((d2.Tecro_spear_charge or 0.06) + 0.15,math.max(d2.Tecro_spear_charge,1))
				end
				if ddis:Length() > range * 7 then 
					ent.Position = ttg_pos
					ent.Velocity = ent.Velocity:Normalized() * player.ShotSpeed * 3
				else
					ent.Velocity = ent.Velocity * 0.3 + player.Velocity * 0.3 + ddis:Normalized() * ddis:Length() * 0.2 * math.sqrt(math.max(1,ent.Velocity:Length() * 0.4))
				end
			elseif d2.Tecro_spear_state == 4 then		--刺入敌人
				if d2.now_dir_set_on then 
					d2.Tecro_spear_charge = math.min((d2.Tecro_spear_charge or 0.06) + 0.1,math.max(d2.Tecro_spear_charge,1))
				else
					d2.Tecro_spear_charge = math.min((d2.Tecro_spear_charge or 0.06) + 0.14,math.max(d2.Tecro_spear_charge,0.5))
				end
				if ddis:Length() > range * 7 then 
					ent.Position = ttg_pos
					ent.Velocity = ent.Velocity:Normalized() * player.ShotSpeed * 3
				else
					ent.Velocity = ent.Velocity * 0.3 + player.Velocity * 0.3 + ddis:Normalized() * ddis:Length() * 0.2 * math.sqrt(math.max(1,ent.Velocity:Length() * 0.4))
				end
				for u,v in pairs(d2.Tecro_spear_target) do
					local eent = v.ent
					if (eent:Exists() == false or eent:IsDead()) then 
						time_free(eent)
						table.remove(d2.Tecro_spear_target,u)
					end
				end
				for u,v in pairs(d2.Tecro_spear_target) do
					local eent = v.ent
					if eent and eent:Exists() and not eent:IsDead() then
						local dd = eent:GetData()
						dd.Tecro_spear_hold_time_Charge_Bar_buff = (dd.Tecro_spear_hold_time_Charge_Bar_buff or 0) + 1
						eent.Position = ent.Position + dir:Normalized() * 80 / (#d2.Tecro_spear_target) * ((tonumber(u) or 3) - 0.5)
						local dmg = spear.CollisionDamage * 0.4
						if dmg > 0.1 or math.random(1000) < dmg * 10000 then
							eent:TakeDamage(dmg,0,EntityRef(spear),0)
							if math.random(1000) > 400 then
								local rnd = math.random(math.max(math.ceil(6 * delta),1))
								for i = 1,rnd do
									local q = Isaac.Spawn(1000,5,0,eent.Position,auxi.MakeVector(math.random(360)) * math.random(1000)/50,nil):ToEffect()
									q.SpriteRotation = math.random(360)
									q.SpriteScale = Vector(0.5 + math.random(1000)/1000,0.5 + math.random(1000)/1000)
								end
							end
							if math.random(1000) > 700 then
								local q = Isaac.Spawn(1000,7,0,eent.Position,Vector(0,0),nil):ToEffect()
								q.SpriteRotation = math.random(360)
								q.SpriteScale = Vector(0.9 + math.random(1000)/1000 * 0.2,0.9 + math.random(1000)/1000 * 0.2)
								sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS,0.7 + math.random(1000)/1000 * 0.7,0.8 + math.random(1000)/1000 * 0.4,false,0,2) 
							end
						end
						if (dd.Tecro_spear_hold_time_Charge_Bar_buff or 60) > (dd.Tecro_spear_hold_time_Charge_Bar_buff_mx or 30) then
							time_free(eent)
							table.remove(d2.Tecro_spear_target,u)
						end
					end
				end
				if #d2.Tecro_spear_target == 0 then
					d2.Tecro_spear_state = 3
				end
			end
			if (list.deadeye or 0) > 0 then 				--死眼
				if (d2.Tecro_spear_state or 0) <= 0 then
					if d3.Tecro_dead_eye_counter ~= nil then
						if d3.Tecro_dead_eye_counter > 0 then
							for i = 1,5 do
								player:ClearDeadEyeCharge()
							end
							d2.Tecro_dead_eye_total_counter = 0
						end
						d3.Tecro_dead_eye_counter = nil
					end
				else
					if d3.Tecro_dead_eye_counter == nil then
						d3.Tecro_dead_eye_counter = 1
					end
				end
			end
			if (list.wavereye or 0) > 0 then				--摇晃之眼
				if (d2.Tecro_spear_state or 0) <= 0 then
					if d3.Tecro_wavereye_counter ~= nil then
						if d3.Tecro_wavereye_counter > 0 then
							if math.random(1000) > 750 then	
								Wavering_Eyes.clear_waver_eye_charge(player)
							end
						end
						d3.Tecro_wavereye_counter = nil
					end
				else
					if d3.Tecro_wavereye_counter == nil then
						d3.Tecro_wavereye_counter = 1
					end
				end
			end
			if d2.Tecro_spear_state ~= 4 and #d2.Tecro_spear_target > 0 then
				for u,v in pairs(d2.Tecro_spear_target) do
					local eent = v.ent
					if eent and eent:Exists() then		--and not eent:IsDead()
						time_free(eent)
					end
					table.remove(d2.Tecro_spear_target,u)
				end
			end
		end	end
		
		if d2[item.own_key.."Record_spear_shot"] then d2[item.own_key.."Record_spear_shot"] = (d2[item.own_key.."Record_spear_shot"] or 0) - 1 if d2[item.own_key.."Record_spear_shot"] <= 0 then d2[item.own_key.."Record_spear_shot"] = nil end end
		
		for i = 1,1 do if (list.tech_0 or 0) > 0 then
			if d.Tecro_inner_frame % 5 == 3 then
				if tail then
					if d2.Tecro_Tech0_lst_pos then
						local mx_dis = (d2.Tecro_Tech0_lst_pos - tail.Position):Length()
						if mx_dis > 10 then
							local q = Isaac.Spawn(7,10,4,tail.Position,Vector(0,0),player):ToLaser()
							q.AngleDegrees = (d2.Tecro_Tech0_lst_pos - tail.Position):GetAngleDegrees()
							q.TearFlags = BitSet128(0,0)
							q.PositionOffset = Vector(0,0)
							q:SetTimeout(7)
							q.CollisionDamage = player.Damage * 0.1
							q.MaxDistance = mx_dis
							delay_buffer.addeffe(function(params)
								SFXManager():Stop(SoundEffect.SOUND_REDLIGHTNING_ZAP_WEAK)
							end,{},2)
						end
					end
					d2.Tecro_Tech0_lst_pos = tail.Position
				end
			end
		end end
		
		dir = ddir
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_bomb) then						--博士
			if wait_me then break end 
			if type(d3.Tecro_linked_bomb) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_bomb = d3.Tecro_linked_bomb(ent,spear,player,dir) 
				else
					break
				end
			end
			if d2.Tecro_spear_state == 1 then
				d3.Tecro_linked_bomb.Position = spear.Position + dir:Normalized() * 40
				d3.Tecro_linked_bomb.Velocity = Vector(0,0)
			else
				d3.Tecro_linked_bomb.Velocity = dir:Normalized() * 10 * player.ShotSpeed
				d3.Tecro_linked_bomb = nil
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_bluefire) then					--钃濈伀
			if wait_me then break end 
			if type(d3.Tecro_linked_bluefire) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_bluefire = d3.Tecro_linked_bluefire(ent,spear,player,dir,d3.Tecro_linked_bluefire) 
				else
					break
				end
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_redfire) then						--红火
			if wait_me then break end 
			if type(d3.Tecro_linked_redfire) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_redfire = d3.Tecro_linked_redfire(ent,spear,player,dir)
				else
					break
				end
			end
			if d2.Tecro_spear_state < 0 then
				d3.Tecro_linked_redfire.Velocity = dir:Normalized() * 15 * player.ShotSpeed
				d3.Tecro_linked_redfire.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NOPITS
				d3.Tecro_linked_redfire = nil
			else
				d3.Tecro_linked_redfire.Position = spear.Position + Vector(0,0.1)
				d3.Tecro_linked_redfire.Velocity = ent.Velocity
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_brimstone) then					--硫磺火
			if type(d3.Tecro_linked_brimstone) == "function" then 
				if wait_me then break end 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_brimstone = d3.Tecro_linked_brimstone(ent,spear,player)
				else
					break
				end
			end
			d3.Tecro_linked_brimstone.Angle = spear.RotationOffset
			if wait_me then break end
			if d2.Tecro_spear_state == -1 then
				d3.Tecro_linked_brimstone:SetTimeout(1)
				d3.Tecro_linked_brimstone = nil
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_maw_of_void) then					--榛戝湀
			if wait_me then break end 
			if type(d3.Tecro_linked_maw_of_void) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_maw_of_void = d3.Tecro_linked_maw_of_void(ent,spear,player) 
				else
					break
				end
			end
			if d2.Tecro_spear_state == -1 then
				d3.Tecro_linked_maw_of_void:SetTimeout(1)
				d3.Tecro_linked_maw_of_void = nil
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_epic_missile) then				--史诗
			if wait_me then break end 
			if type(d3.Tecro_linked_epic_missile) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_epic_missile = d3.Tecro_linked_epic_missile(ent,spear,player,dir) 
				else
					break
				end
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_knife) then						--濡堝垁
			if wait_me then break end 
			if type(d3.Tecro_linked_knife) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_knife = d3.Tecro_linked_knife(ent,spear,player,dir) 
				else
					break
				end
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_sacri) then						--献祭刀
			if wait_me then break end 
			if type(d3.Tecro_linked_sacri) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_sacri = d3.Tecro_linked_sacri(ent,spear,player,dir) 
				else
					break
				end
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_star) then						--启明星
			if wait_me then break end 
			if type(d3.Tecro_linked_star) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_star = d3.Tecro_linked_star(ent,spear,player,dir) 
				else
					break
				end
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_krampus) then						--坎普头
			if wait_me then break end 
			if type(d3.Tecro_linked_krampus) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_krampus = d3.Tecro_linked_krampus(ent,spear,player,dir) 
				else
					break
				end
			end
			if type(d3.Tecro_linked_krampus) == "table" then
				for u,v in pairs(d3.Tecro_linked_krampus) do
					if auxi.check_all_exists(v) ~= true then 
						table.remove(d3.Tecro_linked_krampus,u) 
					else
						local dd = v:GetData()
						v.Angle = dir:GetAngleDegrees() + (dd.Tecro_delta_angle or 0) + (dd.Tecro_delta_dangle or 0)
						if dd.Tecro_should_rotate and v.FrameCount > 3 then dd.Tecro_delta_dangle = (dd.Tecro_delta_dangle or 0) * 0.9 + 90 * dd.Tecro_should_rotate * 0.1 end
					end
				end
				if #d3.Tecro_linked_krampus == 0 then d3.Tecro_linked_krampus = nil end
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_assassin_eye) then				--鏆楁潃
			if wait_me then break end 
			if type(d3.Tecro_linked_assassin_eye) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_assassin_eye = d3.Tecro_linked_assassin_eye(ent,spear,player,dir) 
				else
					break
				end
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_ipec) then						--鍚愭牴
			if wait_me then break end 
			if type(d3.Tecro_linked_ipec) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_ipec = d3.Tecro_linked_ipec(ent,spear,player,dir) 
				else
					break
				end
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_sword) then						--英灵剑
			if wait_me then break end 
			if type(d3.Tecro_linked_sword) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_sword = d3.Tecro_linked_sword(ent,spear,player,dir) 
				else
					break
				end
			end
			d3.Tecro_linked_sword.RotationOffset = dir:GetAngleDegrees()
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_tech) then						--科技1
			if wait_me then break end 
			if type(d3.Tecro_linked_tech) == "function" then 
				if info.check_trigger == nil or info.check_trigger(player,spear,info) then 
					d3.Tecro_linked_tech = d3.Tecro_linked_tech(ent,spear,player,dir) 
				else
					break
				end
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_tech2) then						--科技2
			d3.Tecro_linked_tech2.Angle = spear.RotationOffset
			d3.Tecro_linked_tech2.Position = spear.Position
			if wait_me then break end 
			if d2.Tecro_spear_state == -1 then
				d3.Tecro_linked_tech2:SetTimeout(1)
				d3.Tecro_linked_tech2 = nil
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_trisagon) then					--硫磺水
			d3.Tecro_linked_trisagon.Angle = 180 + spear.RotationOffset
			if wait_me then break end 
			if d2.Tecro_spear_state <= 0 then
				local eent = d3.Tecro_linked_trisagon
				eent.Parent = nil
				eent.Velocity = ent.Velocity
				eent:GetData().tecro_velocity_adder = dir:Normalized() * 12 * player.ShotSpeed
				eent:GetData().tecro_velocity_adder_counter = 10
				eent:GetData().tecro_velocity_decrease = true
				eent:SetTimeout(20)
				d3.Tecro_linked_trisagon = nil
			end
		end end
		for i = 1,1 do if auxi.check_delay_exists(d3.Tecro_linked_tech_x_laser) then				--科技X
			if wait_me then break end 
			if d2.Tecro_spear_state <= 0 and d3.Tecro_linked_tech_x_laser.FrameCount > 3 then
				d3.Tecro_linked_tech_x_laser.SubType = 2
				d3.Tecro_linked_tech_x_laser.Velocity = dir:Normalized() * 10 * player.ShotSpeed
				d3.Tecro_linked_tech_x_laser = nil
			end
		end end
	else ent:Remove() return end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE, params = nil,
Function = function(_,ent)
	if ent.Variant == enums.Entities.Tecro_Spear then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local player = d.player or Game():GetPlayer(0)
		if auxi.check_all_exists(player) ~= true then ent:Remove() return end
		local d2 = player:GetData()
		local list = d2.Tecro_list or {}
		local weap = auxi.get_weapon(player)
		local dir = d.on_record_spear_dir or d.record_spear_dir or d2.now_dir or Vector(0,1)
		local ddir = d.record_spear_ddir or d2.now_dir or Vector(0,1)
		local dir_vel = (d2.now_rot_vel or 0)
		local delta = math.abs(dir_vel)/(d2.now_vel_alpha or 1)
		local tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
		local init_pos = d.birth_init_pos or d.Tecro_anti_record_pos or d2.ludo_init_pos or d2[player_Tecrorun.own_key.."Ludopos"] or player.Position
		local dis = (init_pos - ent.Position):Length()
		local charge = d.record_spear_charge or d2.Tecro_spear_charge or 0.2
		if d.should_not_reload == nil then
			reload_spear(ent,player)
		end
		local info = item.sprite_loader[(d.spear_type or 1)] or item.sprite_loader[1]
		local lev = math.min(100,math.floor(math.max(0,(dis - 50) * 0.3)))
		local source = ent.Parent or player
		d2.Tecro_spear_state = d2.Tecro_spear_state or 0
		
		if d.head then
			if d["spear_render_Clock"] ~= Game():GetFrameCount() then d.head:Update() end
			if not d.Tecro_Ignore_fire then
				local idlename = info.idlename or "IdleHead"
				local now_ani = d.head:GetAnimation()
				if now_ani ~= idlename and (d.head:IsFinished(d.head:GetAnimation()) or d2.Tecro_spear_state <= 0) then
					if info.onfirename and (now_ani == info.firename or now_ani == info.onfirename) and d2.Tecro_spear_state >= 0 then
						if info.check_on_fire == nil or info.check_on_fire(player,ent) then
							idlename = info.onfirename
						end
					end
					d.head:Play(idlename,true)
				end
			end
		end
		
		if (d.Tecro_inner_frame or 0) ~= (source:GetData().Tecro_inner_frame or 0) then	s:SetFrame("IdleUp",lev) end
		d.Tecro_inner_frame = (source:GetData().Tecro_inner_frame or 0)
		d.inner_frame = (d.inner_frame or 0) + 1
		local t_color = d.Tecro_this_color or auxi.AddColor((info.color or Color(1,1,1,1)),player.TearColor,0.5,0.5)
		if d.tecro_remove_then then
			--ent.TearFlags = tearHitParams.TearFlags & (~TearFlags.TEAR_LASERSHOT)		--隐枪不重置特效状态
			local should_remove = true
			if (ent.TearFlags & BitSet128(1<<17,0) == BitSet128(1<<17,0)) and d.Tecro_anti_counter == nil then should_remove = false end
			if should_remove then
				if d.tecro_remove_now == nil then
					d.tecro_remove_cnt = (d.tecro_remove_cnt or 0) * 0.5 + 1 * 0.5
					if math.abs(d.tecro_remove_cnt - 1) < 0.0001 then d.tecro_remove_now = true end
				else
					d.tecro_remove_cnt = (d.tecro_remove_cnt or 0) * 0.95
				end
				s.Color = auxi.AddColor(s.Color,auxi.AddColor(t_color,Color(0,0,0,0),d.tecro_remove_cnt,1 - d.tecro_remove_cnt),0.5,0.5)
			else
				d.tecro_remove_cnt = d.tecro_remove_cnt or 0
				s.Color = t_color
			end
		else
			s.Color = t_color
			if d2.Tecro_spear_state == -1 then ent.TearFlags = BitSet128(0,0)
			else ent.TearFlags = tearHitParams.TearFlags & (~TearFlags.TEAR_LASERSHOT) end
		end
		ent.RotationOffset = dir:GetAngleDegrees() + (d.tecro_dir_offset or 0)
		
		d.Tecro_spear_damage = get_spear_damage(player)
		local vel = source.Velocity
		if vel:Length() < 0.0005 then vel = Vector(0.0005,0) end
		local dmgoffset = 0
		local val = (d.Tecro_spear_damage * 0.5 * (dmgoffset + 0.2 * math.sqrt((vel + auxi.Get_rotate(ent.Position - init_pos) * dir_vel / 180 * 3.14):Length()/20 * player.ShotSpeed)))
		if d2.Tecro_spear_state == 1 or d2.Tecro_spear_state == 3 then
			val = (d.Tecro_spear_damage * 0.5 * (dmgoffset + 0.2 * math.sqrt((vel + 0.5 * auxi.Get_rotate(ent.Position - init_pos) * dir_vel / 180 * 3.14):Length()/20 * player.ShotSpeed)))
		elseif d2.Tecro_spear_state == 4 then
			val = val * 0.3
		end
	--	print(val/(d.Tecro_spear_damage * 0.5))
		if (list.ipec or 0) > 0 then d.Tecro_ipec_counter = math.max(0,(d.Tecro_ipec_counter or 0) - 1) end
		if ent.TearFlags & TearFlags.TEAR_GROW == TearFlags.TEAR_GROW then						--鐓ゅ潡
			val = val * (charge * 1.5 + 0.3)
		end
		if ent.TearFlags & TearFlags.TEAR_SHRINK == TearFlags.TEAR_SHRINK then					--绐佺溂
			val = val * math.max(0,2 - charge * 1.5)
			if d2.Tecro_spear_state == 0 then val = val * 4 end
		end
		if ent.TearFlags and ent.TearFlags & BitSet128(1<<34,0) == BitSet128(1<<34,0) then		--泪盾
			local n_entity = Isaac.GetRoomEntities()
			local n_projs = auxi.getothers(n_entity,9,nil,nil)
			for i = 1,#n_projs do
				if (ent.Position - n_projs[i].Position):Length() < 30 then
					n_projs[i]:AddVelocity((player.Position - n_projs[i].Position):Normalized() * (-2))
				end
			end
		end
		if d2.now_dir_set_on then d.record_collisiondamage = math.max(val,(d.record_collisiondamage or val)) * 0.95 + val * 0.05
		else d.record_collisiondamage = math.max(val * 0.9,(d.record_collisiondamage or val)) * 0.6 + val * 0.4	end
		d.Tecro_damage_rate = d.Tecro_damage_rate or 1
		d.record_collisiondamage = d.record_collisiondamage * d.Tecro_damage_rate
		if info.gear then ent.CollisionDamage = d.record_collisiondamage * 0.9 + 0.1 * player.Damage * 0.5
		else ent.CollisionDamage = d.record_collisiondamage end
		
		local tosetsize = get_spear_size(player)
		ent:SetSize(tosetsize.size1,tosetsize.size2,tosetsize.size3)
		local tail_pos = ent.Position + ddir:Normalized() * (info.offset or 20) + auxi.Get_rotate(ddir) * (info.rot_offset or 0)
		if ent.TearFlags & BitSet128(1<<61,0) == BitSet128(1<<61,0) and d.inner_frame % 7 == 3 and ent.Parent.Velocity:Length() > 3 then Flat_Stone_holder.attack_wave(tail_pos,{scale = s.Scale * 1.5,dmg = ent.CollisionDamage * 0.5,}) end
		
		if d.tail and d.tail:Exists() and d.tail:IsDead() ~= true then
			d.tail.Position = tail_pos
			local s2 = d.tail:GetSprite()
			if d.tecro_remove_then then
				local col = (info.color or Color(1,1,1,1))
				s2.Color = Color(col.R,col.G,col.B,s.Color.A,col.RO,col.GO,col.BO)
			else
				s2.Color = auxi.AddColor((info.color or Color(1,1,1,1)),s.Color,0.5,0.5)
			end
		else
			local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL, 0, tail_pos, Vector(0,0), ent):ToEffect()
			q.PositionOffset = Vector(0,0)
			local s2 = q:GetSprite()
			local info = item.sprite_loader[(d.spear_type or 1)] or item.sprite_loader[1]
			if info.reversed_tail then
				s2:Load("gfx/recolored_trail.anm2",true)
				s2:Play("Idle",true)
			end
			s2.Color = auxi.AddColor(Color(1,1,1,1),s.Color,0.1,0.8)
			d.tail = q
			q.MinRadius = 0.07
			q.MaxRadius = 0.07
			q.SpriteScale = Vector(1,1)
			q.Parent = ent
			q:SetColor(auxi.AddColor(s.Color,Color(1, 1, 1, 0.3, 0, 0, 0),0,1), -1, 0)
			ent.Child = q
		end
		if d.tecro_remove_then == nil then
			if (list.sec or 0) > 0 or weap == 14 then
				local both = (list.sec or 0) > 0 and weap == 14
				local mx_cnt = 6
				if not both then mx_cnt = 2 end
				d.sec_spear = d.sec_spear or {}
				if #d.sec_spear > mx_cnt then
					for i = #d.sec_spear,mx_cnt + 1,-1 do
						local q = d.sec_spear[i].needle
						q:GetData().link_parent = nil
						table.remove(d.sec_spear,i) 
					end
				end
				for u,v in pairs(d.sec_spear) do
					if v.needle == nil or v.needle:Exists() == false or v.needle:IsDead() then
						table.remove(d.sec_spear,u)
					end
				end
				for i = (#d.sec_spear + 1),mx_cnt do
					local q = auxi.fire_needle(nil,nil,{player = player,})
					local d3 = q:GetData()
					d3.link_parent = ent
					table.insert(d.sec_spear,#d.sec_spear + 1,{needle = q,})
				end
				
				local sec_delta = (ent.Position - player.Position):Length() * 0.5
				if d2.Tecro_spear_state == -1 or d2.Tecro_spear_state == 4 then sec_delta = 30 end
				for u,v in pairs(d.sec_spear) do
					local q = v.needle
					local d4 = q:GetData()
					local s4 = q:GetSprite()
					d4.init_pos = ent.Position + auxi.MakeVector(dir:GetAngleDegrees() + 240/mx_cnt * (tonumber(u) - 0.5) - 120) * sec_delta
				end
			else
				if d.sec_spear then
					for i = #d.sec_spear,1,-1 do
						local v = d.sec_spear[i]
						local q = v.needle
						q:GetData().link_parent = nil
						table.remove(d.sec_spear,i)
					end
					d.sec_spear = nil
				end
			end
			if (list.occu or 0) > 0 then
				d.linked_occu_tears = d.linked_occu_tears or {}
				local cnt = 3
				for i = 1,cnt do
					if auxi.check_all_exists(d.linked_occu_tears[i]) == false and Game():GetFrameCount() % 10 == 5 then
						local q = Isaac.Spawn(2,32,0,ent.Position,Vector(0,0),player):ToTear()
						q.TearFlags = BitSet128(1,0)
						q.CollisionDamage = player.Damage * 0.33
						q:GetSprite().Color = player.TearColor
						q:GetData().Ignore_me_flag = true
						q:GetData().Tecro_occu_linked_tear = true
						d.linked_occu_tears[i] = q
						q:GetData().Tecro_occu_linked_parent = ent
					end
					if auxi.check_all_exists(d.linked_occu_tears[i]) then
						local alpha = ((Game():GetFrameCount() + i * 20)% 60) / 60
						d.linked_occu_tears[i]:GetData().target_pos = tail_pos + auxi.MakeVector(Game():GetFrameCount() * 5 + i * 360/cnt) * (20 + math.sin(Game():GetFrameCount()/180 * 3.14 * 5) * 15)
						d.linked_occu_tears[i]:GetSprite().Color = auxi.AddColor(player.TearColor,info.color or Color(1,1,1,1),alpha,1 - alpha)
					end
				end
			elseif d.linked_occu_tears then
				for u,v in pairs(d.linked_occu_tears) do
					if v:Exists() then v:GetData().is_Tecro_linked_occu_tear = nil end
					d.linked_occu_tears[u] = nil
				end
				d.linked_occu_tears = nil
			end
			if info.blade then
				if auxi.check_all_exists(d.linked_blader) == false then
					local q = auxi.fire_knife(ent.Position,Vector(0,0),player.Damage * 0.1,nil,{cooldown = 180,})
					local sq = q:GetSprite()
					sq:Load("gfx/effects/nil_effect.anm2",true)
					sq:Play("Idle",true)
					d.linked_blader = q
					q:GetData().Tecro_blade_linked_knife = ent
				end
				if auxi.check_all_exists(d.linked_blader) then
					local q = d.linked_blader
					q.RotationOffset = ent.RotationOffset - 90 + (info.blade_rot or 0)
					q:SetSize(q.Size,info.blade_scale,5)
					q.CollisionDamage = ent.CollisionDamage * (info.blade_mul or 0.2)
					q.TearFlags = ent.TearFlags
					if q.Parent then q.Parent.Position = ent.Position + ddir:Normalized() * (info.blade_offset or 0) + auxi.Get_rotate(ddir) * (info.blade_rot_offset or 0) end
				end
			elseif d.linked_blader then
				if auxi.check_all_exists(d.linked_blader) then d.linked_blader:Remove() end
				d.linked_blader = nil
			end
		end
		if (list.godhead or 0) > 0 then
			if d.Tecro_linked_godhead == nil then
				local s3 = Sprite()
				s3:Load("gfx/effects/Halo/Halo_godhead_ring.anm2",true)
				s3:Play("Idle",true)
				s3.Scale = Vector(0.5,0.5)
				d.Tecro_linked_godhead = s3
			end
			if d["spear_render_Clock"] ~= Game():GetFrameCount() then d.Tecro_linked_godhead:Update() end
			
			if ent.FrameCount % 5 == 1 then
				local tgs = Isaac.FindInRadius(ent.Position,40,EntityPartition.ENEMY)
				for u,v in pairs(tgs) do
					v:TakeDamage(player.Damage * 0.1,0,EntityRef(spear),0)
				end
			end
		else
			if d.Tecro_linked_godhead then d.Tecro_linked_godhead = nil	end
		end
		if info.charm then
			if d.Tecro_linked_charming == nil then
				local s3 = Sprite()
				s3:Load("gfx/effects/Halo/Halo_charming_ring.anm2",true)
				s3:Play("Idle",true)
				d.Tecro_linked_charming = s3
				d.Tecro_linked_charming.Scale = Vector(0.5,0.5)
			end
			if d.Tecro_linked_charming_2 == nil then
				local s3 = Sprite()
				s3:Load("gfx/effects/Halo/Halo_charming_ring.anm2",true)
				s3:Play("Idle",true)
				d.Tecro_linked_charming_2 = s3
				d.Tecro_linked_charming_2.Scale = Vector(0.25,0.25)
			end
			local scaler = 1
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_VENUS) then scaler = 2 end
			d.Tecro_linked_charming_2.Scale = d.Tecro_linked_charming_2.Scale * 0.9 + Vector(0.25 * scaler,0.25 * scaler) * 0.1
			d.Tecro_linked_charming.Scale = d.Tecro_linked_charming.Scale * 0.9 + Vector(0.5 * scaler,0.5 * scaler) * 0.1
			if d["spear_render_Clock"] ~= Game():GetFrameCount() then 
				d.Tecro_linked_charming:Update() 
				d.Tecro_linked_charming.Rotation = d.Tecro_linked_charming.Rotation + 5
				d.Tecro_linked_charming_2:Update() 
				d.Tecro_linked_charming_2.Rotation = d.Tecro_linked_charming_2.Rotation - 5
			end
			
			if ent.FrameCount % 5 == 1 then
				local tgs = Isaac.FindInRadius(ent.Position,50 * d.Tecro_linked_charming.Scale.X,EntityPartition.ENEMY)
				for u,v in pairs(tgs) do
					local succ = auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_VENUS) or auxi.check_rand(player.Luck,100,50,7)
					if succ then
						v:AddCharmed(EntityRef(player),30 * 3)
					end
				end
			end
		else
			if d.Tecro_linked_charming then d.Tecro_linked_charming = nil end
		end
		if info.salva then
			if d.Tecro_linked_salva == nil then
				local s3 = Sprite()
				s3:Load("gfx/effects/Halo/Halo_salva_ring.anm2",true)
				s3:Play("Idle",true)
				s3.Scale = Vector(0.5,0.5)
				d.Tecro_linked_salva = s3
			end
			if d["spear_render_Clock"] ~= Game():GetFrameCount() then 
				d.Tecro_linked_salva:Update() 
				d.Tecro_linked_salva.Rotation = d.Tecro_linked_salva.Rotation + 5
			end
			
			if ent.FrameCount % 15 == 1 then
				local tgs = Isaac.FindInRadius(ent.Position,40,EntityPartition.ENEMY)
				for u,v in pairs(tgs) do
					if auxi.check_rand(player.Luck,20,5,10) then
						local q = Isaac.Spawn(1000,19,0,v.Position,Vector(0,0),player):ToEffect()
						q.Parent = player
						q.CollisionDamage = player.Damage * 0.5
						q.SpriteScale = Vector(0.3 + math.random(1000)/1000 * 0.2,1)
					end
				end
			end
		else
			if d.Tecro_linked_salva then d.Tecro_linked_salva = nil	end
		end
		if info.censer then
			if d.Tecro_linked_censer == nil then
				local s3 = Sprite()
				s3:Load("gfx/effects/Halo/Halo_censer_ring.anm2",true)
				s3:Play("Idle",true)
				s3.Scale = Vector(0.75,0.75)
				s3.Color = Color(1,1,1,0.4)
				d.Tecro_linked_censer = s3
			end
			if d["spear_render_Clock"] ~= Game():GetFrameCount() then 
				d.Tecro_linked_censer:Update() 
			end
			
			if ent.FrameCount % 5 == 1 then
				local tgs = Isaac.FindInRadius(ent.Position,60,EntityPartition.ENEMY | EntityPartition.BULLET)
				for u,v in pairs(tgs) do
					if v:Exists() and not v:IsDead() then
						v:AddSlowing(EntityRef(player),1,0.5,Color(0.85,0.85,0.85,1,0.15,0.15,0.2))
					end
				end
			end
		else
			if d.Tecro_linked_censer then d.Tecro_linked_censer = nil end
		end
		
		if d.bond_delay and d.bond_delay > 0 then d.bond_delay = d.bond_delay - 1 end
		
		d["spear_render_Clock"] = Game():GetFrameCount() 
	end
	
	if ent.Variant == enums.Entities.Tecro_Needle then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local player = d.player or Game():GetPlayer(0)
		local d2 = player:GetData()
		local source = ent.Parent
		if source == nil then ent:Remove() return end
		local dir_vel = (d2.now_rot_vel or 0)
		local delta = math.abs(dir_vel)/(d2.now_vel_alpha or 1)
		if d.should_not_reload == nil then
			reload_needle(ent,player)
		end
		local info = item.sprite_loader[#(item.sprite_loader)]
		
		if d.link_parent and d.link_parent:Exists() and d.link_parent:IsDead() ~= true then 
			local d3 = d.link_parent:GetData()
			local dir = d3.on_record_spear_dir or d3.record_spear_dir or d2.now_dir or Vector(0,1)
			local ndir = source.Position - (d.link_parent.Position)
			if d2.Tecro_spear_state == -1 or d2.Tecro_spear_state == 1 then 
				ndir = d.link_parent.Position + dir * get_spear_range(player,1) - source.Position
			end
			ndir = ndir + source.Velocity * 5
			if auxi.check_all_exists(d.linked_target) then ndir = d.linked_target.Position - source.Position end
			ent.RotationOffset = ent.RotationOffset + auxi.get_correct_angle_id(ndir:GetAngleDegrees() - ent.RotationOffset) * math.min(10,0.3 * math.abs(ent.RotationOffset - ndir:GetAngleDegrees()))

			ent.CollisionDamage = 0.5 * player.Damage * 0.07
			
			if d.tail and d.tail:Exists() and d.tail:IsDead() ~= true then
				d.tail.Position = ent.Position + dir:Normalized() * (info.offset or 20) + auxi.Get_rotate(dir) * (info.rot_offset or 0)
				local s2 = d.tail:GetSprite()
				if d.tecro_remove_then then
					local col = (info.color or Color(1,1,1,1))
					s2.Color = Color(col.R,col.G,col.B,s.Color.A,col.RO,col.GO,col.BO)
				else
					s2.Color = auxi.AddColor((info.color or Color(1,1,1,1)),s.Color,0.5,0.5)
				end
			else
				local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL, 0, ent.Position, Vector(0,0), ent):ToEffect()
				local s2 = q:GetSprite()
				local info = item.sprite_loader[(d.spear_type or 1)] or item.sprite_loader[1]
				if info.reversed_tail then
					s2:Load("gfx/recolored_trail.anm2",true)
					s2:Play("Idle",true)
				end
				s2.Color = auxi.AddColor(Color(1,1,1,1),s.Color,0.1,0.8)
				d.tail = q
				q.MinRadius = 0.07
				q.MaxRadius = 0.07
				q.SpriteScale = Vector(1,1)
				q.Parent = ent
				q:SetColor(auxi.AddColor(s.Color,Color(1, 1, 1, 0.3, 0, 0, 0),0,1), -1, 0)
				ent.Child = q
			end
		else
			source:Remove()
			ent:Remove()
			return
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_KNIFE_COLLISION, params = nil,
Function = function(_,ent,col,low)
	if ent.Variant == enums.Entities.Tecro_Spear then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local player = d.player or Game():GetPlayer(0)
		local d2 = player:GetData()
		local list = d2.Tecro_list or {}
		local d3 = col:GetData()
		local dir = d.record_spear_dir or d2.now_dir or Vector(0,1)
		local ddir = d.record_spear_ddir or d2.now_dir or Vector(0,1)
		local dir_vel = (d2.now_rot_vel or 0)
		local delta = math.abs(dir_vel)/(d2.now_vel_alpha or 1)
		local info = item.sprite_loader[(d.spear_type or 1)] or item.sprite_loader[1]
		local should_repel = true
		
		if d.tecro_remove_then == nil then
			if ((d2[item.own_key.."Record_spear_shot"] or 0) > 0 and d2.Tecro_spear_state == 1 or (d2.Tecro_spear_state == 4 and find_a_impaled_place(col,player)) or player.Velocity:Length() > 12) and can_be_impaled(col,player) and (d3.Tecro_spear_hold_time_Charge_Bar_buff or 0) < 5 and d3.time_stopped == nil then		--or (d2.Tecro_spear_state == 3 and (d2.Tecro_spear_charge or 0) < 0.9) 
				d2.Tecro_spear_state = 4
				d2.Tecro_spear_target = d2.Tecro_spear_target or {} 
				table.insert(d2.Tecro_spear_target,#d2.Tecro_spear_target + 1,{ent = col,})
				d3.Tecro_linked_ent = ent
				stop_time(col,player)
				if auxi.check_if_any(item.Addition_catcher[col.Type],col) then 
					local n_entities = auxi.get_linked(col) 
					for u,v in pairs(n_entities) do	
						local d4 = v:GetData()
						if (d4.Tecro_spear_hold_time_Charge_Bar_buff or 0) < 5 and d4.time_stopped == nil then 
							table.insert(d2.Tecro_spear_target,#d2.Tecro_spear_target + 1,{ent = v,})
							stop_time(v,player)
							d4.Tecro_linked_ent = ent
						end 
					end
				end
				local rnd = math.random(math.max(math.ceil(6 * delta),1)) + 2
				for i = 1,rnd do
					local q = Isaac.Spawn(1000,5,0,ent.Position,auxi.MakeVector(math.random(360)) * math.random(1000)/1000 * 4 + ((col.Position - player.Position):Normalized() * 10 * player.ShotSpeed + auxi.Get_rotate(ddir) * dir_vel),nil):ToEffect()
					q.SpriteRotation = math.random(360)
					q.SpriteScale = Vector(0.5 + math.random(1000)/1000,0.5 + math.random(1000)/1000)
				end
			end
		end
		if d.Tecro_dead_eye_counter or 0 > 0 then
			player:AddDeadEyeCharge()
			d.Tecro_dead_eye_counter = (d.Tecro_dead_eye_counter or 0) - 1
			d2.Tecro_dead_eye_total_counter = (d2.Tecro_dead_eye_total_counter or 0) + 1
		end
		if d.Tecro_wavereye_counter or 0 > 0 then
			Wavering_Eyes.add_waver_eye_charge(player)
			d.Tecro_wavereye_counter = 0
		end
		if auxi.isenemies(col) then
			if delta > 0.4 then
				local q = Isaac.Spawn(1000,2,0,col.Position,Vector(0,0),nil):ToEffect()
				q.SpriteRotation = math.random(360)
				q.SpriteScale = Vector(0.9 + math.random(1000)/1000 * 0.2,0.9 + math.random(1000)/1000 * 0.2)
			end
			if info.bleed_out and col:HasEntityFlags(EntityFlag.FLAG_BLEED_OUT) == false then 
				if auxi.check_rand(player.Luck,30,10,5) then
					Attribute_holder.try_hold_and_rewind_attribute(col,"EntityFlag_FLAG_BLEED_OUT",true,1 * 30,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_BLEED_OUT))
				end
			end
			if info.blood_oath then
				if (d.Tecro_blood_oath_counter or 0) > 0 then
					d.Tecro_blood_oath_counter = d.Tecro_blood_oath_counter - 1
					local dmg = math.min(player.Damage * 5,col.HitPoints * 0.1)
					col:TakeDamage(dmg,0,EntityRef(spear),0)
					for i = 1,7 do
						local q = Isaac.Spawn(1000,5,0,col.Position,auxi.MakeVector(math.random(360)) * math.random(1000)/1000 * 10 + ddir:Normalized() * 20,nil):ToEffect()
						q.SpriteRotation = math.random(360)
						q.SpriteScale = Vector(0.5 + math.random(1000)/1000,0.5 + math.random(1000)/1000)
						q.PositionOffset = Vector(0,- math.random(1000)/1000 * 30 - 10)
					end
					if auxi.check_rand(dmg/player.Damage,100,10,4) then
						local q = Isaac.Spawn(5,10,2,col.Position,ddir:Normalized() * 20,nil):ToPickup()
						q:Morph(5,10,2,true,true,true)
						local ss = q:GetSprite()
						ss:SetLastFrame()
						q.Timeout = 15 + math.random(45)
						local q2 = Isaac.Spawn(1000,enums.Entities.TecroThisNil,0,col.Position,col.Velocity,nil):ToEffect()
						q2.Parent = q
						local d4 = q2:GetData()
						d4.tail_pos_offset = Vector(0,-10)
						d4.follow_position_offset = true
						local q3 = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL, 0, col.Position, Vector(0,0), ent):ToEffect()
						d4.tail = q3 
						q3.PositionOffset = Vector(0,0)
						q3:GetSprite().Color = Color(1,0,0,0.3)
						q3.MinRadius = 0.07
						q3.MaxRadius = 0.07
						q3.SpriteScale = Vector(2,2)
						q3.Parent = q2
					end
				end
			end
			if info.damo then Damo_holder.try_add_damo(col) end
			if info.reder then
				if col:GetSprite().Color.RO > 0.01 then col:TakeDamage(ent.CollisionDamage * col:GetSprite().Color.RO * 0.4,0,EntityRef(ent),0) end
				if auxi.check_rand(player.Luck,20,1,15) then
					local color = auxi.AddColor(col:GetSprite().Color,Color(1,0.1,0.1,1,0.5,0,0),0.7,0.3)
					Attribute_holder.try_hold_and_rewind_attribute(col,"Color",color,30 * 15,Attribute_holder.descriptors.color())		--重载不等号
				end
			end
			if info.bond and (d.bond_delay or 0) <= 0 then
				local q = auxi.fire_nil(col.Position,Vector(0,0),{cooldown = 25,})
				q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_GROUND
				local s = q:GetSprite()
				s:Load("gfx/player/tecro/tecro_spike.anm2",true)
				q:GetData().is_spike = true
				q:GetData().recorded_damage = player.Damage * 0.3
				if item.bond_special_spikes[Game():GetLevel():GetStage()] then 
					s:Play("SummonWomb",true)
				else
					s:Play("Summon",true)
				end
				d.bond_delay = 2 + math.random(5)
			end
			if (list.birthright or 0) > 0 then		--长子权
				if d2.Tecro_spear_state > 0 and (d.Tecro_birthright_counter or 0) > 0 then
					d.Tecro_birthright_counter = (d.Tecro_birthright_counter or 0) - 1
					local infos = get_all_spear(ent,player)
					local st_rnd = math.random(3600)/10
					if (#infos) > 0 then
						for i = 1,#infos do
							local v = infos[i]
							local ndir = auxi.MakeVector(360 * i/(#infos) + st_rnd)
							local npos = col.Position - ndir * (120 + math.random(1000)/1000 * 60)
							item.fire_birth_right_spear(player,npos,ndir,{spear_type = v.id,TearFlags = BitSet128(1<<2,0),})
						end
					end
				end
			end
			if ent.TearFlags & BitSet128(1<<49,0) == BitSet128(1<<49,0) then 		--中猫套
				if auxi.check_rand(player.Luck,50,10,15) then		--随着幸运上升，在15达到50%。基础值为 10%
					if math.random(1000) > 500 then
						player:ThrowBlueSpider(ent.Position,player.Position)
					else
						player:AddBlueFlies(math.random(2),ent.Position,player)
					end
					Isaac.Spawn(1000,44,0,ent.Position,Vector(0,0),player)
				elseif math.random(1000) > 950 then
					Isaac.Spawn(1000,44,0,ent.Position,Vector(0,0),player)
				end
			end
			if ent.TearFlags & BitSet128(1<<52,0) == BitSet128(1<<52,0) then		--比列眼
				if d.tecro_remove_then == nil and d2.Tecro_spear_state > 0 then
					if (d.Tecro_belial_counter or 0) > 0 then
						local q = item.fire_birth_right_spear(player,col.Position,ddir,{color = Color(0,0,0,1,1,0,0),TearFlags = BitSet128(1<<2,0),})
						d.Tecro_belial_counter = d.Tecro_belial_counter - 1
					end
				end
			end
		end
		if ent.TearFlags & BitSet128(1<<33,0) == BitSet128(1<<33,0) then		--神秘液体
			if auxi.check_rand(player.Luck,100,30,10) == true then
				Isaac.Spawn(1000,53,0,col.Position,Vector(0,0),player)
			end
		end
		if (list.ipec or 0) > 0 then 
			if (d.Tecro_ipec_counter or 0) <= 0 then
				local head = ent:GetData().head or Sprite()
				local dmgself = false
				Game():BombExplosionEffects(col.Position,player.Damage,ent.TearFlags,s.Color,player,head.Scale:Length()/math.sqrt(2),false,dmgself) 
				d.Tecro_ipec_counter = player.MaxFireDelay * 5
			end
		end
		if should_repel and can_be_repeled(col,player) then
			local vel_decayer = math.max(0.1,math.min(1,1.4 - col.Velocity:Length() * 0.1))
			if d2.Tecro_spear_state == 0 or d2.Tecro_spear_state == -1 or (d2.Tecro_spear_state == 3 and d2.Tecro_spear_charge >= 1) then		--离心作为主体
				col:AddVelocity(((col.Position - player.Position):Normalized() * 12 * player.ShotSpeed * delta + auxi.Get_rotate(ddir) * dir_vel) * vel_decayer)
				if delta > 0.3 and math.random(1000) > 500 then sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS,0.8 + math.random(1000)/1000 * 0.2,1,false,0,2) end
			else		--击退作为主体
				col:AddVelocity(((col.Position - player.Position):Normalized() * 24 * player.ShotSpeed) * vel_decayer)
			end
		end
	end
	if ent.Variant == enums.Entities.TecroNeedleNil then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local player = d.player or Game():GetPlayer(0)
		local d2 = player:GetData()
		local list = d2.Tecro_list or {}
		local d3 = col:GetData()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.TecroThisNil,
Function = function(_,ent)
	local d = ent:GetData()
	local targ = d.targ or ent.Parent
	if targ == nil then ent:Remove() return end
	local pos = targ.Position + (d.position_offset or Vector(0,0))
	if d.follow_position_offset then pos = pos + targ.PositionOffset end
	ent.Position = pos
	if d.tail then
		d.tail.Position = ent.Position + (d.tail_pos_offset or Vector(0,0))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d.check_linker and (d.check_linker:Exists() == false or d.check_linker:IsDead()) and (ent.Timeout > 2) then ent:SetTimeout(1) end
	if (d.tecro_velocity_adder_counter or 0) > 0 then
		d.tecro_velocity_adder_counter = d.tecro_velocity_adder_counter - 1
		ent.Velocity = ent.Velocity * 0.7 + (d.tecro_velocity_adder or Vector(0,0)) * 0.3
	else
		if d.tecro_velocity_decrease then
			ent.Velocity = ent.Velocity * 0.95
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d.Tecro_occu_linked_tear then
		ent.Height = math.max(-10,math.min(ent.Height * 1.1,ent.Height - 1))
		ent.FallingAcceleration = 0
		ent.FallingSpeed = 0
		local tg_pos = ent:GetData().target_pos or ent.Position
		ent.Velocity = ent.Velocity * 0.3 + (tg_pos - ent.Position) * 0.3 * 0.7
		if auxi.check_all_exists(ent:GetData().Tecro_occu_linked_parent) == false then ent:Remove() return end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	if player:GetName() == "Tecro" then
		local d = player:GetData()
		local idx = d.__Index
		local weap = auxi.get_weapon(player)
		save.elses.Tecro_ludo_buff = save.elses.Tecro_ludo_buff or {}
		save.elses.Tecro_knife_buff = save.elses.Tecro_knife_buff or {}
		if (auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DR_FETUS) and weap == 7) or (save.elses.Tecro_knife_buff[idx] and weap == 4) then
			save.elses.Tecro_knife_buff[idx] = true
			value[114] = (value[114] or 0) + 1
			save.elses.Tecro_ludo_buff[idx] = nil
		else
			if (auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_IPECAC) and weap == 1) or weap == 7 or (save.elses.Tecro_ludo_buff[idx] and weap == 8) then
				save.elses.Tecro_ludo_buff[idx] = true
				value[329] = (value[329] or 0) + 1
			else
				save.elses.Tecro_ludo_buff[idx] = nil
			end
			save.elses.Tecro_knife_buff[idx] = nil
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_REASSIGN_IMITATE_ITEM, params = nil,
Function = function(_,player)
	if player:GetName() == "Tecro" then
		local d = player:GetData()
		d.Tecro_list = auxi.get_Tecro_list(player)
		if d.linked_spear then reload_spear(d.linked_spear,player) end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = 329,
Function = function(_,player,collid,cnt,touched)
	if player:GetName() == "Tecro" then
		local d = player:GetData()
		local idx = d.__Index
		save.elses.Tecro_ludo_buff = save.elses.Tecro_ludo_buff or {}
		save.elses.Tecro_ludo_buff[idx] = nil
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = 329,
Function = function(_,player,collid,count)
	if player:GetName() == "Tecro" then
		if count < 0 then
			local d = player:GetData()
			d.ludo_init_pos = nil
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = 114,
Function = function(_,player,collid,cnt,touched)
	if player:GetName() == "Tecro" then
		local d = player:GetData()
		local idx = d.__Index
		save.elses.Tecro_knife_buff = save.elses.Tecro_knife_buff or {}
		save.elses.Tecro_knife_buff[idx] = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_,ent)
	local ret1 = auxi.check_if_any(item.check_kill[ent.Type],ent)
	if ret1 and ent:HasEntityFlags(EntityFlag.FLAG_FREEZE) then
		local n_entity = Isaac.GetRoomEntities()
		for u,v in pairs(n_entity) do
			if auxi.check_if_any(ret1[v.Type],v) then
				if auxi.check_for_the_same(v.Parent,ent) or auxi.check_for_the_same(ent.Parent,v) then
					v:Kill()
					break
				end
			end
		end
	end
	if item.check_rel[ent.Type] and ent:HasEntityFlags(EntityFlag.FLAG_FREEZE) then
		local n_entity = Isaac.GetRoomEntities()
		for u,v in pairs(n_entity) do
			if ent.Type == v.Type then
				if v:HasCommonParentWithEntity(ent) then
					if v:HasEntityFlags(EntityFlag.FLAG_FREEZE) then time_free(v) end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if ent ~= nil then
		local player = ent:ToPlayer()
		if player and player:GetName() == "Tecro" then
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

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_,str,params)
	if string.lower(str) == "meus" and params ~= nil then
		local args={}
		for str in string.gmatch(params, "([^ ]+)") do
			table.insert(args, str)
		end
		if args[1] then
			if string.lower(args[1]) == "please" then
				if args[2] and args[3] and args[4] then
					if args[2] == "record" and args[3] == "tecro" then
						item.now_id = (tonumber(args[4]) or 1)
						print("OK.Now it is "..tostring(item.now_id))
					end
				end
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	if player:GetName() == "Tecro" then
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

--- Gello 等宝宝：从 origin 发射长枪多发；charge 承载伤害倍率；不扣币/不推进眼泪盆。
function item.fire_familiar_attack(player, request)
	request = request or {}
	if not player then return {fired = false} end
	local CharacterFamiliars = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")
	local aim = request.aim_dir or Vector(0, 1)
	if aim:Length() < 0.01 then aim = Vector(0, 1) end
	local mul = tonumber(request.damage_mul) or 0.75
	-- fire_spear 会把 source 当作 TecroNil Parent；仅允许熟悉体/TecroNil，禁止邪眼等 Effect
	local src = request.source
	if src and src.Type == EntityType.ENTITY_EFFECT then
		if src.Variant ~= enums.Entities.TecroNil and src.Variant ~= enums.Entities.TecroLaserNil then
			src = nil
		end
	end
	-- cnt1=1：get_Tecro_multishots 默认 base=0，无多发道具时表为空（玩家主枪不走这条）。
	work_on_Tecro_multi_attack_params(player, {
		dir = aim,
		charge = mul,
		cnt1 = 1,
		origin = request.origin or (request.source and request.source.Position),
		source = src,
		TearFlags = CharacterFamiliars.apply_familiar_tear_flags(player, BitSet128(0, 0)),
		advanced_familiar_copy = true,
	})
	return {fired = true, delay = player.MaxFireDelay}
end

return item

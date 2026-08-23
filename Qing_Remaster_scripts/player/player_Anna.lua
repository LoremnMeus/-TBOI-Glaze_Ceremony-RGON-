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
local anna_portal_holder = require("Qing_Remaster_scripts.callbacks.anna_portal_holder")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local grid_entity = require("Qing_Remaster_scripts.grids.grid_entity")
local grid_morpher = require("Qing_Remaster_scripts.grids.grid_morpher")
local record_holder = require("Qing_Remaster_scripts.others.Record_holder")
local every_entity_holder = require("Qing_Remaster_scripts.callbacks.every_entity_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local Isaacs_Tear_holder = require("Qing_Remaster_scripts.mimics.Isaacs_Tear_holder")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local card_06r_lover = require("Qing_Remaster_scripts.cards.Card_06r_lover")
local Crane_Game_holder = require("Qing_Remaster_scripts.mimics.Crane_Game_holder")
local CharacterAttackCompat = require("Qing_Remaster_scripts.player.character_attack_compat")
local Entity_holder = require("Qing_Remaster_scripts.others.Entity_holder")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	pre_myToCall = {},
	myToCall = {},
	post_myToCall = {},
	entity = enums.Players.Anna,
	own_key = "Player_Anna_",
	own_key2 = "Player_Anna2_",
	save_holder = {},
	suck_info = function(ent,fr,id,info,item) 
		if info["Frame"] ~= fr then info["id"] = (info["id"] or -1) + 1 end
		info["Frame"] = fr
		local rm = (info["id"] > 16) --((auxi.check_all_exists(info.ent) ~= true) or 
		return {Rotation = info.ang,fr = info["id"],rm = rm,}
	end,
	rift_info = function(ent,fr,id,info,item) 
		local d = ent:GetData()
		d[item.own_key.."RiftCounter"..tostring(id)] = (d[item.own_key.."RiftCounter"..tostring(id)] or math.random(6)) - 1
		if d[item.own_key.."RiftFrame"..tostring(id)] ~= fr and d[item.own_key.."RiftCounter"..tostring(id)] < 0 then d[item.own_key.."RiftFrameid"..tostring(id)] = (d[item.own_key.."RiftFrameid"..tostring(id)] or -1) + 1 end
		d[item.own_key.."RiftFrame"..tostring(id)] = fr
		if d[item.own_key.."RiftCounter"..tostring(id)] == 0 then d[item.own_key.."RiftRotation"..tostring(id)] = info.angle or math.random(360) end
		if (d[item.own_key.."RiftFrameid"..tostring(id)] or 0) > 8 then 
			d[item.own_key.."RiftCounter"..tostring(id)] = math.random(12) 
			d[item.own_key.."RiftFrameid"..tostring(id)] = nil 
		end
		if d[item.own_key.."RiftFrameid"..tostring(id)] then return {Rotation = d[item.own_key.."RiftRotation"..tostring(id)],fr = d[item.own_key.."RiftFrameid"..tostring(id)],} end
	end,
	Port_info = {
		[1] = {
			{frame = 0,C = 255,},
			{frame = 2,C = 281,},
			{frame = 4,C = 306,},
			{frame = 6,C = 319,},
			{frame = 8,C = 306,},
			{frame = 10,C = 281,},
			{frame = 12,C = 255,},
			{frame = 14,C = 230,},
			{frame = 16,C = 204,},
			{frame = 18,C = 191,},
			{frame = 20,C = 204,},
			{frame = 22,C = 230,},
			{frame = 24,C = 255,},
		},
		[2] = {
			{frame = 0,C = 148,},
			{frame = 2,C = 167,},
			{frame = 4,C = 185,},
			{frame = 6,C = 204,},
			{frame = 8,C = 222,},
			{frame = 10,C = 231,},
			{frame = 12,C = 222,},
			{frame = 14,C = 204,},
			{frame = 16,C = 185,},
			{frame = 18,C = 167,},
			{frame = 20,C = 148,},
			{frame = 22,C = 139,},
			{frame = 24,C = 148,},
		},
		[3] = {
			{frame = 0,C = 92,},
			{frame = 2,C = 86,},
			{frame = 4,C = 92,},
			{frame = 6,C = 104,},
			{frame = 8,C = 115,},
			{frame = 10,C = 127,},
			{frame = 12,C = 138,},
			{frame = 14,C = 144,},
			{frame = 16,C = 138,},
			{frame = 18,C = 127,},
			{frame = 20,C = 115,},
			{frame = 22,C = 104,},
			{frame = 24,C = 92,},
		},
		[4] = {
			{frame = 0,C = 45,},
			{frame = 2,C = 41,},
			{frame = 4,C = 36,},
			{frame = 6,C = 34,},
			{frame = 8,C = 36,},
			{frame = 10,C = 41,},
			{frame = 12,C = 45,},
			{frame = 14,C = 50,},
			{frame = 16,C = 54,},
			{frame = 18,C = 56,},
			{frame = 20,C = 54,},
			{frame = 22,C = 50,},
			{frame = 24,C = 45,},
		},
	},
	Special_Des = {
		["zh"] = {
			["Item"] = {
				[CollectibleType.COLLECTIBLE_DR_FETUS] = {Name = "爆灾",Description = "吞噬炸弹！",},
				[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {Name = "痕灾",Description = "操纵激光！",},
				[CollectibleType.COLLECTIBLE_MOMS_KNIFE] = {Name = "伤灾",Description = "此刀为我所用！",},
				[CollectibleType.COLLECTIBLE_BRIMSTONE] = {Name = "磺灾",Description = "恶魔的权柄！",},
				[CollectibleType.COLLECTIBLE_EPIC_FETUS] = {Name = "引灾",Description = "歼灭！",},
				[CollectibleType.COLLECTIBLE_TECH_X] = {Name = "割灾",Description = "无路可逃！",},
				[CollectibleType.COLLECTIBLE_IPECAC] = {Name = "毁灾",Description = "定向爆破！",},
				[CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = {Name = "斩灾",Description = "剑气激荡！",},
				[CollectibleType.COLLECTIBLE_C_SECTION] = {Name = "寂灾",Description = "吞噬！",},
				[CollectibleType.COLLECTIBLE_MONSTROS_LUNG] = {Name = "食灾",Description = "有点过饱",},
				
				[CollectibleType.COLLECTIBLE_HAEMOLACRIA] = {Name = "解灾",Description = "释放鲜血",},
				[CollectibleType.COLLECTIBLE_LIBRA] = {Name = "衡灾",Description = nil,},
				[CollectibleType.COLLECTIBLE_VOID] = {Name = "噬灾",Description = "吃干抹净",},
				[CollectibleType.COLLECTIBLE_ABYSS] = {Name = "蝗灾",Description = "它们饥饿",},
				
				[CollectibleType.COLLECTIBLE_TERRA] = {Name = "石灾",Description = "吞噬地面！",},
				[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {Name = "远程灾难发生器",Description = "我带来了灾祸",},
				[CollectibleType.COLLECTIBLE_MAW_OF_VOID] = {Name = "最终天灾",Description = "我欲问天",},
				[CollectibleType.COLLECTIBLE_LIL_PORTAL] = {Name = "灾难幼体",Description = "你有潜力！",},
				[enums.Items.Calamity] = {Name = "天灾 · 灾天",Description = "我欲焚天",},
				[enums.Items.Book_of_6_sin] = {Name = "论贪婪",Description = "囤积祸端",},
				[enums.Items.Core_Brooch] = {Name = "我的胸针",Description = "我择祭品",},
				
				[CollectibleType.COLLECTIBLE_BLOOD_OATH] = {Name = "灾之誓言",Description = "它追随着我们",},
				[CollectibleType.COLLECTIBLE_SOY_MILK] = {Name = "灾害增生",Description = "祸不单行",},
				[CollectibleType.COLLECTIBLE_ALMOND_MILK] = {Name = "灾害腐生",Description = "福无双至",},
			},
		},
		["en"] = {
			["Item"] = {
			},
		},
	},
	Port_order = {
		[1] = {
			{id = 5,},
			{id = 4,Offset = Vector(-4,0),},
			{id = 3,Offset = Vector(-3,0),},
			{id = 2,Offset = Vector(-2,0),},
			{id = 1,Offset = Vector(-1,0),},
		},
		[2] = {
			{id = 5,},
			{id = 4,A = 0.5,},
			{id = 3,A = 0.5,},
			{id = 2,A = 0.5,},
			{id = 1,A = 0.5,},
		},
	},
	ignore_ports = {
		[1] = true,
		[2] = true,
		--[3] = true,
		[3] = function(ent,item) if auxi.check_if_any(item.ignore_familiars[ent.Variant],ent) then return true end end,
		--[4] = true,
		[5] = function(ent,item) if ent.Variant == 340 or ent.Variant == 370 then return true end 
			if ent.Variant == 100 then	
				if Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex == -12 then return true end
				if auxi.GetDimension() == 2 and ent:ToPickup().OptionsPickupIndex ~= 0 then return true end
			end
		end,
		[6] = function(ent,item) if auxi.check_if_any(item.ignore_slots[ent.Variant],ent) then return true end end,
		[7] = true,
		[8] = true,
		[266] = function(ent) if ent.Variant ~= 0 then return true end end,
		[912] = function(ent) if ent.Variant == 0 and ent.SubType ~= 0 then return true end end,
		[1000] = function(ent,item) if auxi.check_if_any(item.no_ignore_effects[ent.Variant],ent) then else return true end end,
	},
	Addition_catcher = {
		[19] = true,
		[28] = true,
		[62] = true,
		[239] = true,
	},
	collision_ignorers = {
		[96] = true,
		[266] = function(ent) if ent.Variant ~= 0 then return true end end,
		[409] = function(ent) if ent.Variant == 1 then return true end end,
		[912] = function(ent) if ent.Variant == 0 and ent.SubType ~= 0 then return true end end,
	},
	no_ignore_effects = {
		[EffectVariant.DEVIL] = true,
		[EffectVariant.ANGEL] = true,
		[EffectVariant.TRINITY_SHIELD] = true,
		[EffectVariant.BLUE_FLAME] = true,
		[EffectVariant.RED_CANDLE_FLAME] = true,
	},
	ignore_killers = {
		[1000] = function(ent,item) if auxi.check_if_any(item.ignore_killer_effects[ent.Variant],ent) then return true end end,
	},
	ignore_killer_effects = {
		[EffectVariant.TINY_BUG] = true,
		[EffectVariant.TINY_FLY] = true,
		[EffectVariant.WORM] = true,
		[EffectVariant.WALL_BUG] = true,
		[EffectVariant.BUTTERFLY] = true,
		[EffectVariant.EVIL_EYE] = true,
	},
	ignore_familiars = {
		[FamiliarVariant.FLY_ORBITAL] = true,
		[FamiliarVariant.SWARM_FLY_ORBITAL] = true,
		[FamiliarVariant.BLUE_FLY] = true,
		[FamiliarVariant.BLUE_SPIDER] = true,
		[FamiliarVariant.GUILLOTINE] = true,
		[FamiliarVariant.SAMSONS_CHAINS] = true,
		[FamiliarVariant.ABYSS_LOCUST] = true,
		[FamiliarVariant.MINISAAC] = true,
		[FamiliarVariant.ISAACS_HEART] = true,
		--[FamiliarVariant.SUCCUBUS] = true,
		[FamiliarVariant.DIP] = true,
		[FamiliarVariant.WISP] = true,
		[FamiliarVariant.ITEM_WISP] = true,
		[FamiliarVariant.LOST_SOUL] = true,
		[FamiliarVariant.BABY_PLUM] = true,
		--[FamiliarVariant.LOST_FLY] = true,
		--[FamiliarVariant.LIL_GURDY] = true,
		--[FamiliarVariant.SPRINKLER] = true,
		[FamiliarVariant.DAMOCLES] = true,
		[FamiliarVariant.FORGOTTEN_BODY] = true,
		[enums.Familiars.QingsAirs] = true,
		[enums.Familiars.Star_Pendulum] = true,
		[enums.Familiars.Air_Terror] = true,
		[enums.Familiars.Nazca] = true,
	},
	ignore_slots = {
		[enums.Slots.Rift_beggar.Variant] = true,
		[enums.Slots.Bard_beggar.Variant] = true,
	},
	Special_check = {
		--[9] = function(ent,range) if ent.PositionOffset.Y < -range then return true end end,
	},
	Special_info = {
		[2] = {Replace = true,Weigh = 10,Load = {
			["Type"] = true,
			["Variant"] = true,
			["SubType"] = true,
			["TearFlags"] = true,
		},},
		[3] = {Assign = true,Weigh = 20,},
		[4] = {Replace = true,Weigh = 100,Load = {
			["Type"] = true,
			["Variant"] = true,
			["SubType"] = true,
			["InitSeed"] = true,
			["Size"] = true,
			["SizeMulti"] = function(v) return {X = v.X,Y = v.Y,} end,
			
			["E"] = function(v,ent) return ent:ToBomb().ExplosionDamage end,
			["R"] = function(v,ent) return ent:ToBomb().RadiusMultiplier end,
			["IF"] = function(v,ent) return ent:ToBomb().IsFetus end,
			["F"] = function(v,ent) return auxi.bit2table(ent:ToBomb().Flags) end,
		},Loader = {
			["ExplosionDamage"] = function(v,params) return params.E end,
			["RadiusMultiplier"] = function(v,params) return params.R end,
			["IsFetus"] = function(v,params) return params.IF end,
			["Flags"] = function(v,params) return auxi.table2bit(params.F) end,
		},Release = function(params,ent,player,info,item) 
			local vr = params.Variant
			local q = Game():Spawn(params.Type,vr,Game():GetRoom():FindFreeTilePosition(ent.Position,10),ent.Velocity,player,params.SubType,params.InitSeed):ToBomb()
			q:GetSprite():SetLastFrame()
			for u,v in pairs(info.Loader) do 
				if type(v) == "function" then q[u] = auxi.check_if_any(v,params[u],params) 
				else q[u] = params[u] end
			end
			q:SetExplosionCountdown(math.random(7) + 3)
			if vr == 19 or vr == 20 then q:SetExplosionCountdown(1) end
			return {ent = q,}
		end,},
		[5] = {Replace = true,Weigh = 15,Special = function(ent,col,info,player,item)
			if auxi.can_start_ambush(col) then auxi.try_start_ambush() end
			if col.Variant == 100 and col:ToPickup().Price < 0 and col:ToPickup().Price > -10 then Game():AddDevilRoomDeal() end
			if col.Variant == 100 then card_06r_lover.try_take_on_lover(player,col) end
			auxi.remove_others_option_pickup(col)
		end,Load = {
			["Type"] = true,
			["Variant"] = true,
			["SubType"] = true,
			["InitSeed"] = true,
			["Size"] = true,
			["SizeMulti"] = function(v) return {X = v.X,Y = v.Y,} end,
			
			["Price"] = function(v,ent) if ent:ToPickup().Price ~= 0 then return ent:ToPickup().Price end end,
			["C"] = function(v,ent) return ent:ToPickup().Charge end,
			["T"] = function(v,ent) return ent:ToPickup().Touched end,
			["To"] = function(v,ent) return ent:ToPickup().Timeout end,
			["Si"] = function(v,ent) return ent:ToPickup().ShopItemId end,
			["B"] = function(v,ent) return auxi.isBlindPickup(ent) end,
			--["OptionsPickupIndex"] = true,
			--["AutoUpdatePrice"] = true,
			["RS"] = function(v,ent,info) return ent:GetDropRNG():GetSeed()	end,
		},Loader = {
			["Timeout"] = function(v,params) return params.To end,
			["ShopItemId"] = function(v,params) return params.Si end,
			["Touched"] = function(v,params) return params.T end,
			["Charge"] = function(v,params) return params.C end,
		},check_pos = {
			[20] = function(ent) if ent.SubType == 6 then return true end end,
			[57] = true,
			[100] = true,
			[340] = true,
			[370] = true,
			[380] = true,
			[390] = true,
		},Remover = {
			[50] = true,
			[51] = true,
			[52] = true,
			[53] = true,
			[54] = true,
			[55] = true,
			[56] = true,
			[57] = true,
			[58] = true,
			[60] = true,
			[100] = true,
			[360] = true,
			[380] = function(params) if params.T then return true end end
		},Release = function(params,ent,player,info,item) 
			local pos = ent.Position
			if auxi.check_if_any(info.Remover[params.Variant],params) and params.SubType == 0 then return {Kick = true,} end
			if (params.Variant == 110 or (params.Variant == 100 and params.SubType == 550)) and (Game():GetLevel():GetStage() ~= 1 or Game():GetLevel():GetStage() > 2) then return {Kick = true,} end
			if false then pos = Game():GetRoom():FindFreeTilePosition(ent.Position,10) end
			if params.Price or auxi.check_if_any(info.check_pos[params.Variant],params) then pos = Game():GetRoom():FindFreePickupSpawnPosition(ent.Position,5,true) end
			--l local q = Game():Spawn(5,100,Vector(200,200),Vector(0,0),nil,1,1):ToPickup()
			unique_holder.Hold_for_missing(true)
			local q = Game():Spawn(params.Type,params.Variant,pos,ent.Velocity,player,params.SubType,params.InitSeed):ToPickup()
			q:PlayDropSound()
			auxi.self_morph(q,{params.Type,params.Variant,params.SubType})
			if params.RS and params.RS > 0 then q:GetDropRNG():SetSeed(params.RS,0) end
			local s = q:GetSprite()
			unique_holder.Hold_for_missing()
			for u,v in pairs(info.Loader) do 
				if type(v) == "function" then q[u] = auxi.check_if_any(v,params[u],params) 
				else q[u] = params[u] end
			end
			if params.Price then 
				price_holder.try_catch_price(q) 
				q.Price = params.Price
				consistance_holder.try_hold_over_entity(q,item.own_key)
				q:GetData()._Data[item.own_key][item.own_key.."record"] = params.Price
				consistance_holder.try_hold_entity(q,item.own_key)
			end		--!
			if params.B then
				s:ReplaceSpritesheet(1,"gfx/items/collectibles/questionmark.png")
				s:LoadGraphics()
			end
			q:GetSprite():SetLastFrame()
			return {ent = q,Sounded = true,}
		end,},
		[6] = {Replace = true,Weigh = 30,Load = {
			["Type"] = true,
			["Variant"] = true,
			["SubType"] = true,
			["InitSeed"] = true,
			["Size"] = true,
			["SizeMulti"] = function(v) return {X = v.X,Y = v.Y,} end,
			["Broken"] = function(v,ent,info) 
				if ent:GetSprite():GetAnimation() == "Broken" or ent:GetSprite():GetAnimation() == "Death" then return true end
				return false
			end,
			["Rd"] = function(v,ent,info) 
				if ent.Variant == 16 then return Crane_Game_holder.try_ask_ent(ent) end
			end,
			["RS"] = function(v,ent,info) return ent:GetDropRNG():GetSeed()	end,
		},NoLastFrame = {
			[8] = true,
		},Machines = {
			[1] = true,
			[2] = true,
			[3] = true,
			[8] = true,
			[10] = true,
			[11] = true,
			[12] = true,
			[16] = true,
			[17] = true,
		},Release = function(params,ent,player,info,item) 
			if params.Broken then return {Kick = true,} end
			local pos = Game():GetRoom():GetClampedPosition(ent.Position,30)
			if params.Rd then 
				Crane_Game_holder.Hold_for_missing(true,params.Rd,params.RS or params.InitSeed)
				delay_buffer.addeffe(function(params)
					Crane_Game_holder.Hold_for_missing(nil,nil,params.RS or params.InitSeed)
				end,{},3)
			end
			local q = Game():Spawn(params.Type,params.Variant,pos,ent.Velocity,player,params.SubType,params.InitSeed)
			if info.NoLastFrame[params.Variant] ~= true then q:GetSprite():SetLastFrame() end
			if params.RS and params.RS > 0 then q:GetDropRNG():SetSeed(params.RS,0) end
			if info.Machines[params.Variant] then 
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_SUMMONSOUND,1.2,1,false,0,2) 
				return {ent = q,Sounded = true,} 
			end
			return {ent = q,}
		end,},
		[9] = {Replace = true,Weigh = 5,Load = {
			["Type"] = true,
			["Variant"] = true,
			["SubType"] = true,
			["ProjectileFlags"] = true,
			["Size"] = true,
			["SizeMulti"] = function(v) return {X = v.X,Y = v.Y,} end,
		},AddPosOffset = true,},
		[17] = {Replace = true,Weigh = 35,Load = {
			["Type"] = true,
			["Variant"] = true,
			["SubType"] = true,
			["InitSeed"] = true,
			["Size"] = true,
			["SizeMulti"] = function(v) return {X = v.X,Y = v.Y,} end,
		},Release = function(params,ent,player,info,item) 
			local pos = ent.Position
			local q = Game():Spawn(params.Type,params.Variant,pos,ent.Velocity,player,params.SubType,params.InitSeed)
			q:GetSprite():SetLastFrame()
			return {ent = q,CopySprite = true,}
		end,},
		[33] = {Replace = true,Weigh = 50,Load = {
			["Type"] = true,
			["Variant"] = true,
			["SubType"] = true,
			["InitSeed"] = true,
			["Size"] = true,
			["SizeMulti"] = function(v) return {X = v.X,Y = v.Y,} end,
			
			["H"] = function(v,ent) return ent.HitPoints end,
			["L"] = function(v,ent) return auxi.get_acceptible_level() end,
		},Kicker = {
			[2] = true,
			[3] = true,
			[4] = true,
		},Release = function(params,ent,player,info,item) 
			if params.H <= 1 or (info.Kicker[params.Variant] and auxi.get_acceptible_level() ~= params.L) then return {Kick = true,} end
			local pos = Game():GetRoom():GetClampedPosition(ent.Position,20)
			local q = Game():Spawn(params.Type,params.Variant,pos,ent.Velocity,player,params.SubType,params.InitSeed)
			q:GetSprite():SetLastFrame()
			return {ent = q,CopySprite = true,}
		end,},
		[245] = {Replace = true,Weigh = 50,Load = {
			["Type"] = true,
			["Variant"] = true,
			["SubType"] = true,
			["InitSeed"] = true,
			["Size"] = true,
			["SizeMulti"] = function(v) return {X = v.X,Y = v.Y,} end,
			
			["H"] = function(v,ent) return ent.HitPoints end,
		},Release = function(params,ent,player,info,item) 
			return {Kick = true,}
		end,},
		[292] = {Replace = true,Weigh = 50,Load = {
			["Type"] = true,
			["Variant"] = true,
			["SubType"] = true,
			["InitSeed"] = true,
			["Size"] = true,
			["SizeMulti"] = function(v) return {X = v.X,Y = v.Y,} end,
			
			["H"] = function(v,ent) return ent.HitPoints end,
		},Release = function(params,ent,player,info,item) 
			if params.H <= 1 then return {Kick = true,} end
			local pos = ent.Position
			local q = Game():Spawn(params.Type,params.Variant,pos,ent.Velocity,player,params.SubType,params.InitSeed)
			q:GetSprite():SetLastFrame()
			q:TakeDamage(100,0,EntityRef(q),0)
			return {ent = q,CopySprite = true,}
		end,},
		[1001] = {
			Release = function(params,ent,player,info,item) 
				local q = grid_morpher.morph_info(params,{pos = ent.Position,}):ToTear()
				q.Height = -3
			end,
		},
		--[[
		[951] = function(ent)
			if ent.Variant == 31 then return {
				Replace = true,Weigh = 50,Load = {
					["Type"] = true,
					["Variant"] = true,
					["SubType"] = true,
					["InitSeed"] = true,
					["Size"] = true,
					["SizeMulti"] = function(v) return {X = v.X,Y = v.Y,} end,
					},Release = function()
					local q = Isaac.Spawn(4,17,0,ent.Position,Vector(0,0),nil):ToBomb() q.Visible = false q:GetSprite():SetLastFrame() q:SetExplosionCountdown(0)
					q:SetExplosionCountdown(1)
					return {ent = q,}
				end,} 
			end
		end,
		[960] = function(ent)
			if ent.Variant ~= 0 then return {
				Replace = true,Weigh = 35,Load = {
					["Type"] = true,
					["Variant"] = true,
					["SubType"] = true,
					["InitSeed"] = true,
					["Size"] = true,
					["SizeMulti"] = function(v) return {X = v.X,Y = v.Y,} end,
				},Release = function(params,ent,player,info,item) 
					local pos = ent.Position
					local q = Game():Spawn(params.Type,params.Variant,pos,ent.Velocity,player,params.SubType,params.InitSeed)
					return {ent = q,CopySprite = true,}
				end,}
			end
		end,
		--]]
	},
	GridType = {
		[2] = true,
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		--[7] = true,
		[8] = true,
		[9] = true,
		[10] = true,
		[11] = true,
		[12] = true,
		[13] = true,
		[14] = true,
		[18] = true,
		[21] = true,
		[22] = true,
		[24] = true,
		[25] = true,
		[26] = true,
		[27] = true,
	},
	Flag_Expack = {
		[0] = {TearFlag = BitSet128(1<<2,0),},
		[1] = {TearFlag = BitSet128(1<<12,0),},
		[2] = {TearFlag = BitSet128(1<<33,0),},
		[3] = {TearFlag = BitSet128(1<<32,0),},
		[4] = {TearFlag = BitSet128(1<<0,0),},
		[5] = {TearFlag = BitSet128(1<<10,0),},
		[6] = {TearFlag = BitSet128(1<<8,0),},
		[8] = {TearFlag = BitSet128(0,1<<(67-64)),},
		[9] = {TearFlag = BitSet128(1<<44,0),},
		[10] = {TearFlag = BitSet128(0,1<<(67-64)),},
		[11] = {TearFlag = BitSet128(1<<16,0),},
		[12] = {TearFlag = BitSet128(0,1<<(69-64)),},
		[16] = {TearFlag = BitSet128(1<<18,0),},
		[18] = {TearFlag = BitSet128(1<<26,0),},
		[19] = {TearFlag = BitSet128(1<<26,0),},
		[20] = {TearFlag = BitSet128(0,1<<(71-64)),},
		--21
		[22] = {TearFlag = BitSet128(1<<10,0),},
		[23] = {TearFlag = BitSet128(1<<10,0),},
		[25] = {TearFlag = BitSet128(1<<30,0),},
		[29] = {TearFlag = BitSet128(1<<6,0),},
		[30] = {TearFlag = BitSet128(1<<38,0),},
		[34] = {TearFlag = BitSet128(1<<17,0),},
		--35
		--36
		--39
		[42] = {TearFlag = BitSet128(1<<19,0),},
		[44] = {TearFlag = BitSet128(1<<34,0),},
		--45
		--46
		[47] = {TearFlag = BitSet128(1<<31,0),},
		[48] = {TearFlag = BitSet128(0,1<<(114-64)),},
		[49] = {TearFlag = BitSet128(1<<62,0),},
		--54
		--55
		--56
		--57
	},
	Something_info = {
		[5] = {
			[10] = {
				[1] = {rate = 1,},
				[2] = {rate = 0.5,},
				[3] = {Dmg = 5,rate = 1,},
				[4] = {Shift = function(ent,player) if auxi.check_rand(player.Luck,20,10,10) then ent.TearFlags = ent.TearFlags | BitSet128(1<<39,0) end end,rate = 2,},
				[5] = {rate = 2,},
				[6] = {Hit = function(ent,col) end,rate = 2,},
				[7] = {Shift = function(ent,player) if auxi.check_rand(player.Luck,20,10,10) then ent.TearFlags = ent.TearFlags | BitSet128(1<<53,0) end end,rate = 3,},
				[8] = {Dmg = 2.5,rate = 0.5,},
				[9] = {Shift = function(ent,player) if auxi.check_rand(player.Luck,50,25,5) then ent.TearFlags = ent.TearFlags | BitSet128(1<<13,0) end end,rate = 0.75,},
				[10] = {Dmg = 2.5,rate = 1,},
				[11] = {Shift = function(ent,player) if auxi.check_rand(player.Luck,50,25,3) then ent.TearFlags = ent.TearFlags | BitSet128(1<<51,0) end end,rate = 2,},
				[12] = {Shift = function(ent,player) if auxi.check_rand(player.Luck,30,15,5) then ent.TearFlags = ent.TearFlags | BitSet128(1<<11,0) end end,rate = 0.5,},
				Default = {rate = 1,},
			},
			[20] = {
				[1] = {rate = 0.1,},
				[2] = {rate = 0.5,},
				[3] = {rate = 1,},
				[4] = {rate = 0.2,},
				[5] = {rate = 1,},
				[6] = {Shift = function(ent,player) if auxi.check_rand(player.Luck,20,10,10) then ent.TearFlags = ent.TearFlags | BitSet128(1<<3,0) end end,rate = 0.1,},
				[7] = {Shift = function(ent,player) if auxi.check_rand(player.Luck,20,10,10) then ent.TearFlags = ent.TearFlags | BitSet128(1<<53,0) end end,rate = 2,},
				Default = {rate = 0.1,},
				--Adder = {Shift = function(ent,player) if auxi.check_rand(player.Luck,3,1,10) then ent.TearFlags = ent.TearFlags | BitSet128(1<<44,0) end end,}
			},
			[30] = {
				[1] = {rate = 0.3,},
				[2] = {rate = 1,},
				[3] = {rate = 0.6,},
				[4] = {Hit = function(ent,col,player) if auxi.check_rand(player.Luck,20,10,10) then auxi.add_charge(player,1) end end,rate = 0.8,},
				Default = {rate = 0.3,},
			},
			[40] = {
				[1] = {Hit = function(ent,col,player) if auxi.check_rand(player.Luck,5,2,10) then Game():BombExplosionEffects(ent.Position,player.Damage * 2,0,ent.Color,player,0.5,true,false) end end,rate = 0.25,},
				[2] = {Hit = function(ent,col,player) if auxi.check_rand(player.Luck,10,5,10) then Game():BombExplosionEffects(ent.Position,player.Damage * 2,0,ent.Color,player,0.5,true,false) end end,rate = 0.5,},
				[4] = {Hit = function(ent,col,player) Game():BombExplosionEffects(ent.Position,player.Damage * 2,0,ent.Color,player,0.5,true,false)end,rate = 1,},
				[7] = {Hit = function(ent,col,player) if auxi.check_rand(player.Luck,50,20,10) then local q = Isaac.Spawn(4,17,0,ent.Position,Vector(0,0),nil):ToBomb() q.Visible = false q:GetSprite():SetLastFrame() q:SetExplosionCountdown(0) end end,rate = 10,},
				Default = {Hit = function(ent,col,player) if auxi.check_rand(player.Luck,5,2,10) then Game():BombExplosionEffects(ent.Position,player.Damage * 2,0,ent.Color,player,0.5,true,false) end end,rate = 0.25,},
			},
			[41] = {
				Default = {Hit = function(ent,col,player) if auxi.check_rand(player.Luck,5,2,10) then Game():BombExplosionEffects(ent.Position,player.Damage * 2,0,ent.Color,player,0.5,true,false) end end,rate = 0,},
			},
			[42] = {
				[1] = {rate = 0.2,},
				[2] = {rate = 0.6,},
				Default = {rate = 0.2,},
				Adder = {Shift = function(ent,player) if auxi.check_rand(player.Luck,30,15,10) then ent.TearFlags = ent.TearFlags | BitSet128(0,1<<(73-64)) end end,}
			},
			[51] = {
				Default = {rate = 2,},
			},
			[53] = {
				Default = {rate = 2,},
			},
			[57] = {
				Default = {rate = 5,},
			},
			[60] = {
				Default = {rate = 2,},
			},
			[70] = {
				Default = function(st)
					if st == 14 then return {Shift = function(ent,player) if auxi.check_rand(player.Luck,75,45,3) then ent.TearFlags = ent.TearFlags | BitSet128(1<<(auxi.choose(3,4,5,11,13,20,22,32,49,50)),0) end end,rate = 0.5,}
					elseif st == 14 + 2048 then return {Shift = function(ent,player) for i = 1,4 do ent.TearFlags = ent.TearFlags | BitSet128(1<<(auxi.choose(3,4,5,11,13,20,22,32,49,50)),0) end end,rate = 1,}
					elseif st > 2048 then return {Shift = function(ent,player) for i = 1,4 do if auxi.check_rand(player.Luck,30,15,5) then ent.TearFlags = ent.TearFlags | BitSet128(1<<(auxi.choose(3,4,5,11,13,20,22,32,49,50)),0) end end end,rate = 0.66,}
					else return {Shift = function(ent,player) if auxi.check_rand(player.Luck,30,15,5) then ent.TearFlags = ent.TearFlags | BitSet128(1<<(auxi.choose(3,4,5,11,13,20,22,32,49,50)),0) end end,rate = 0.33,} end
				end,
			},
			[90] = {
				[1] = {Shift = function(ent,player) if auxi.check_rand(player.Luck,30,15,10) then ent.TearFlags = ent.TearFlags | BitSet128(1<<55,0) end end,rate = 0.5},
				[2] = {Shift = function(ent,player) if auxi.check_rand(player.Luck,10,5,10) then ent.TearFlags = ent.TearFlags | BitSet128(1<<55,0) end end,rate = 0.2},
				[3] = {Shift = function(ent,player) ent.TearFlags = ent.TearFlags | BitSet128(1<<55,0) end,rate = 2,},
				[4] = {Shift = function(ent,player) ent.TearFlags = ent.TearFlags | BitSet128(1<<55,0) end,rate = 3,},
				Default = {rate = 0.5,},
				Adder = {Hit = function(ent,col,player) if auxi.check_rand(player.Luck,10,5,10) then auxi.add_charge(player,1) end end,}
			},
			[100] = {
				Default = {rate = 5,},
			},
			[110] = {
				Default = {Hit = function(ent,col,player) local q = Isaac.Spawn(1000,29,0,ent.Position,Vector(0,0),nil):ToEffect() q.Parent = player q.CollisionDamage = player.Damage * 10 end,rate = 2.5,},
			},
			[380] = {
				Default = {rate = 5,},
			},
			Default = {Default = {rate = 1,},},
			Price = {rate = 0,},
		},
		Default = {Default = {Default = {rate = 1,},},},
	},
	Pickup_info = {
		["zh"] = {
			[10] = {
				[1] = {Description = "",rate = 1,},
				[2] = {Description = "",rate = 0.5,},
				[3] = {Description = "抛掷物伤害+5",rate = 1,},
				[4] = {Description = "命中后概率生成圣光光柱",rate = 0.5,},
				[5] = {Description = "",rate = 2,},
				[6] = {Description = "命中后造成范围伤害",rate = 1,},
				[7] = {Description = "命中后概率使敌人变为金",rate = 1,},
				[8] = {Description = "抛掷物伤害+2.5",rate = 0.5,},
				[9] = {Description = "命中后低概率造成魅惑",rate = 1,},
				[10] = {Description = "抛掷物伤害+2.5",rate = 1,},
				[11] = {Description = "命中后概率分裂出骨头碎片",rate = 1,},
				[12] = {Description = "命中后概率生成一只苍蝇",rate = 1,},
				Default = {Description = "",rate = 1,},
			},
			[20] = {
				[1] = {Description = "",rate = 0.1,},
				[2] = {Description = "",rate = 0.5,},
				[3] = {Description = "",rate = 1,},
				[4] = {Description = "",rate = 0.1,},
				[5] = {Description = "",rate = 0.1,},
				[6] = {Description = "{{Slow}}命中概率减速敌人",rate = 0.1,},
				[7] = {Description = "命中后概率使敌人变为金",rate = 0.1,},
				Default = {Description = "",rate = 0.1,},
				Adder = {Description = "命中后极低概率额外掉落硬币",}
			},
			[30] = {
				[1] = {Description = "",rate = 0.5,},
				[2] = {Description = "",rate = 0.5,},
				[3] = {Description = "",rate = 1,},
				[4] = {Description = "命中后低概率获得一点充能",rate = 0.5,},
				Default = {Description = "",rate = 0.5,},
			},
			[40] = {
				[1] = {Description = "命中后低概率爆炸",rate = 0.25,},
				[2] = {Description = "命中后低概率爆炸",rate = 0.5,},
				[4] = {Description = "命中后发生爆炸",rate = 0.25,},
				[7] = {Description = "命中后概率发生巨大爆炸",rate = 10,},
				Default = {Description = "命中后低概率爆炸",rate = 0.25,},
			},
			[41] = {
				Default = {Description = "命中后低概率爆炸",rate = 0,},
			},
			[42] = {
				[1] = {Description = "",rate = 0.5,},
				[2] = {Description = "",rate = 1.5,},
				Default = {Description = "",rate = 0.5,},
				Adder = {Description = "命中后低概率使敌人变为便便",}
			},
			[70] = {
				Default = function(st)
					if st == 14 then return {Description = "命中后高概率造成随机特殊效果",rate = 0.5,}
					elseif st == 14 + 2048 then return {Description = "命中后高概率造成多种随机特殊效果",rate = 1,}
					elseif st > 2048 then return {Description = "命中后概率造成多种随机特殊效果",rate = 0.66,}
					else return {Description = "命中后概率造成随机特殊效果",rate = 0.3,} end
				end,
			},
			[90] = {
				[1] = {Description = "命中时概率生成随机方向的电弧",rate = 0.5},
				[2] = {Description = "命中时低概率生成随机方向的电弧",rate = 0.2},
				[3] = {Description = "命中时生成随机方向的电弧",rate = 2,},
				Default = {Description = "",rate = 0.5,},
				Adder = {Description = "命中后低概率获得一点充能",}
			},
			[100] = {		--表角色没有特殊效果
				--[[
				[CollectibleType.COLLECTIBLE_DR_FETUS] = {Description = "落地时额外生成一枚炸弹",},
				[CollectibleType.COLLECTIBLE_MOMS_KNIFE] = {Description = "落地时飞出数把妈刀",},
				[CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = {Description = "落地时产生一道斩击",},
				[CollectibleType.COLLECTIBLE_BRIMSTONE] = {Description = "落地时释放数道硫磺火",},
				[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {Description = "落地时释放数道激光",},
				[CollectibleType.COLLECTIBLE_EPIC_FETUS] = {Description = "落地时落下导弹标记",},
				[CollectibleType.COLLECTIBLE_TECH_X] = {Description = "落地时释放数道激光圈",},
				--[CollectibleType.COLLECTIBLE_C_SECTION] = {Description = "落地时吸引敌人",},
				[CollectibleType.COLLECTIBLE_MONSTROS_LUNG] = {Description = "落地时喷射血泪",},
				[CollectibleType.COLLECTIBLE_TECHNOLOGY_2] = {Description = "与角色间由激光相连",},
				[CollectibleType.COLLECTIBLE_MAW_OF_VOID] = {Description = "落地时生成一道黑色激光圈",},
				[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {Description = "可自由控制飞行直到碰撞落地",},
				[CollectibleType.COLLECTIBLE_IPECAC] = {Description = "落地时爆炸",},
				--]]
				Default = {Description = "",rate = 5,},
			},
			[110] = {
				Default = {Description = "命中后概率生成一道妈腿",rate = 2.5,},
			},
			[380] = {
				Default = {Description = "",rate = 5,},
			},
			Default = {Default = {Description = "",rate = 2,},},
			Price = {Description = "#作为商品被投掷：不能造成伤害",rate = 0,},
			DamageRate = "投掷伤害倍率"
		},
	},
	eventlist = {
		"Explosion",
		"Shoot",
		"Jump",
		"Land",
		"BloodStart",
		"BloodStop",
		--"Heartbeat",
		"Lift",
		"Stop",
		"Slide",
		"Spawn",
		"Shoot2",
		"DeathSound",
		"DropSound",
		"Disappear",
		"Prize",
		--"Shuffle",
		--"CoinInsert",
	},
	Pos_offset = {
		[404] = function(ent) if ent.Variant == 1 then return Vector(0,32) end end,
	},
	catch2charge = {
		[2] = 5,
		[3] = 3,
		[4] = function(ent,params,info) 
			local vr = params.Variant
			return info.Bomb[vr] or 20
		end,
		["Bomb"] = {
			[1] = 30,
			[4] = 30,
			[6] = 30,
			[14] = 10,
			[17] = 50,
			[18] = 50,
			[20] = 50,
		},
		[5] = function(ent,params,info)
			local vr = params.Variant
			return info.Pickup[vr] or 10
		end,
		["Pickup"] = {
			[10] = 5,
			[20] = 5,
			[30] = 5,
			[40] = 5,
			[41] = 5,
			[42] = 5,
			[57] = 30,
			[69] = 5,
			[100] = 15,
		},
		[6] = 20,
		[7] = 1,
		[8] = 1,
		[9] = 4,
	},
	push_scaler = {
		{frame = 0,scale = Vector(1,1),offsetscale = 1,},
		{frame = 2,scale = Vector(1.2,0.8),offsetscale = 1.4,},
		{frame = 4,scale = Vector(1.4,1.4),offsetscale = 1.6,},
		{frame = 7,scale = Vector(1.35,1.45),offsetscale = 1.5,},
		{frame = 9,scale = Vector(1,1),offsetscale = 1,},
		Limit = 9,
	},
	size_launcher = {
		{frame = 0,rate = 0,offsetscale = 1,scalerate = 1,},
		{frame = 8,rate = 0.8,offsetscale = 1.4,scalerate = 1,},
		{frame = 15,rate = 1,offsetscale = 1.6,scalerate = 0.9,},
		{frame = 35,rate = 1,offsetscale = 1.4,scalerate = 0.8,},
		{frame = 50,rate = 0,offsetscale = 1,scalerate = 0,},
		Limit = 50,
	},
	size_scaler = {
		{frame = 0,scale = 1,},
		{frame = 10,scale = 1,},
		{frame = 20,scale = 1.2,},
		{frame = 50,scale = 2,},
		{frame = 100,scale = 3,},
		{frame = 200,scale = 4,},
	},
	other_info = {
		[17] = {NoRotate = true,},
	},
	damage_rate = {
		normal = {
			{frame = 3,rate = 0.75,},
			{frame = 5,rate = 1,},
			{frame = 10,rate = 1.5,},
			{frame = 30,rate = 2,},
			{frame = 100,rate = 4,},
		},
		boss = {
			{frame = 8,rate = 0.75,},
			{frame = 10,rate = 1,},
			{frame = 30,rate = 1.5,},
			{frame = 100,rate = 2,},
			{frame = 500,rate = 4,},
		},
	},
	localizer = {},
	item2tear = {
		[678] = {},
	},
	delayoffset = 3,
	Range_charger = {
		{frame = 40,ret = 5,},
		{frame = 260,ret = 15,},
		{frame = 400,ret = 30,},
		{frame = 800,ret = 45,},
		{frame = 1600,ret = 60,},
		{frame = 4000,ret = 80,},
	},
	snd_remover = {
		[11] = {Snd = {SoundEffect.SOUND_SPLATTER,SoundEffect.SOUND_TEARIMPACTS,SoundEffect.SOUND_SCYTHE_BREAK,SoundEffect.SOUND_REDLIGHTNING_ZAP_WEAK,},},
		[12] = {Snd = {SoundEffect.SOUND_SPLATTER,SoundEffect.SOUND_TEARIMPACTS,SoundEffect.SOUND_SCYTHE_BREAK,SoundEffect.SOUND_REDLIGHTNING_ZAP_WEAK,},},
		[13] = {Snd = {SoundEffect.SOUND_SPLATTER,SoundEffect.SOUND_TEARIMPACTS,},},
		[79] = {Snd = {SoundEffect.SOUND_SPLATTER,SoundEffect.SOUND_TEARIMPACTS,},},
		[80] = {Snd = {SoundEffect.SOUND_SPLATTER,SoundEffect.SOUND_TEARIMPACTS,},},
		[20] = {Snd = {SoundEffect.SOUND_SCYTHE_BREAK,},},
		[35] = {Snd = {SoundEffect.SOUND_BOIL_HATCH,SoundEffect.SOUND_POT_BREAK,SoundEffect.SOUND_STONE_IMPACT,},},
		[85] = {Snd = {SoundEffect.SOUND_POT_BREAK,},},
		[98] = {Snd = {SoundEffect.SOUND_POT_BREAK,},},
		[86] = {Snd = {SoundEffect.SOUND_POT_BREAK,},},
	},
	Kick_info = {
		{frame = 0,A = 1,Scale = Vector(1,1),},
		{frame = 30,A = 0.3,Scale = Vector(1.2,1.2),},
		{frame = 60,A = 0,Scale = Vector(1.8,1.8),},
		Limit = 60,
	},
	spilt_info = {
		{frame = 0,cnt = 0,},
		{frame = 3,cnt = 1,},
		{frame = 7,cnt = 2,},
		{frame = 12,cnt = 3,},
		{frame = 20,cnt = 5,},
		{frame = 50,cnt = 10,},
	},
	Sec_buffs = {
		[579] = {TearFlags = BitSet128(0,1<<(107-64)),},
		--[704] = {check = function(player) if player:GetEffects():HasCollectibleEffect(704) then return true end end,TearFlags = BitSet128(0,1<<(108-64)),},
		[114] = {TearFlags = BitSet128(0,1<<(109-64)),},
		[395] = {TearFlags = BitSet128(0,1<<(110-64)),},
		[68] = {TearFlags = BitSet128(0,1<<(111-64)),},
		[118] = {TearFlags = BitSet128(0,1<<(112-64)),},
		[52] = {TearFlags = BitSet128(0,1<<(113-64)),},
	},
	spilt_record = {},
	brim_list = {
		[1] = true,
		[9] = true,
		[10] = true,
		[11] = true,
		[15] = true,
		[14] = true,
	},
	portal_offset = Vector(0,-8),
	buff_list = {
		BitSet128(1<<2,0),
		BitSet128(1<<16,0),
		BitSet128(1<<30,0),
		BitSet128(1<<19,0),
		BitSet128(1<<33,0),
		BitSet128(0,1<<5),
	},
	--下面是从小鬼那里拷贝来的
	target = {		--只控制强制转移的敌人
		[6] = true,
		[17] = true,
		[30] = true,
		[33] = true,
		[36] = true,
		[40] = true,		--很特殊哦
		[42] = true,
		[45] = true,
		[56] = true,
		[59] = true,
		[60] = true,
		--[61] = true,		--目标坐标
		--[63] = true,
		--[65] = true,
		[84] = true,
		[78] = true,
		[96] = true,
		[101] = true,
		[102] = true,
		[201] = true,
		[202] = true,
		[203] = true,
		[209] = true,
		[218] = true,
		[221] = true,
		[228] = true,
		[231] = true,
		[235] = true,
		[236] = true,
		[240] = true,
		[241] = true,
		[242] = true,
		[244] = true,
		[245] = true,
		[251] = true,
		[255] = true,
		[262] = true,
		[263] = true,
		[266] = true,
		[270] = true,
		[273] = function(ent) if ent.Variant == 10 then return true end end,
		[274] = true,
		[275] = true,
		[276] = true,
		[289] = true,
		[292] = true,
		[294] = true,
		[298] = true,
		[300] = true,
		[304] = true,
		[306] = true,
		[307] = true,
		[309] = true,
		[406] = function(ent) if ent.State == 9000 or ent.State == 9001 then return true end end,
		[804] = true,
		[805] = true,
		[809] = true,
		[825] = true,
		[829] = true,
		[832] = function(ent) if ent.Variant == 1 and ent.SubType > 0 and (ent.State == 16 or ent.State == 5) then return true end end,
		[837] = true,
		[852] = true,
		[856] = true,
		[861] = true,
		[862] = true,
		[877] = true,
		[880] = true,
		[881] = true,
		[889] = true,
		[900] = true,
		[904] = function(ent) if ent.Variant == 1 then return true end end,
		[905] = function(ent) if ent.State == 6 then return true end end,
		[906] = true,
		[907] = true,
		[911] = true,
		[912] = function(ent) if ent.Variant < 100 then return true end end,
		[914] = true,
		[917] = true,
		--919
		[921] = true,
		[950] = function(ent) if ent.Variant == 1 or ent.Variant == 2 then return true end end,
		[951] = function(ent) if ent.Variant == 0 or ent.Variant == 1 then return true end end,
		[960] = true,
		[964] = true,
		[965] = true,
		[967] = true,
	},
	middle_target = {
		[29] = true,		--
		[54] = true,		--
		[86] = true,		--
		[215] = true,		--
		[246] = true,		--
		[250] = true,		--
		[305] = true,		--
		[840] = true,		--
		[851] = true,		--
		--[869] = true,		--
		--[20] = true,		--
		--[100] = true,		--
		--[68] = true,		--
		--[264] = true,		--
		--[43] = true,		--
		[410] = true,		--
	},
}

function item.get_anna(player_key)
	local only, count = nil, 0
	for playerNum = 1,Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player:GetPlayerType() == item.entity then
			if player_key ~= nil and player:GetData().__Index == player_key then return player end
			only, count = player, count + 1
		end
	end
	-- 旧记录没有 PlayerKey 时只允许单安娜局兜底，禁止多人串池。
	if player_key == nil and count == 1 then return only end
end

function item.ent2info(ent)
	if ent == nil then return end
	local desc = ent:GetData()[item.own_key.."Record"]
	if desc and desc.Record then return item.something2info(desc.Record.Type,desc.Record.Variant,desc.Record.SubType,{Price = desc.Record.Price,}) end
end

function item.something2info(tp,vr,st,params)
	params = params or {}
	local infomap = item.Something_info[tp] or item.Something_info.Default
	if params.Price then return infomap.Price end
	local infodesc = auxi.check_if_any(infomap[vr],st) or auxi.check_if_any(infomap.Default,vr,st)
	local info = auxi.check_if_any(infodesc[st]) or auxi.check_if_any(infodesc.Default,st) or auxi.check_if_any(infomap.Default.Default,vr,st)
	return info,infodesc
end

function item.pickup2EID(tp,vr,st,params)
	params = params or {}
	local language = Options.Language 
	if item.Pickup_info[language] == nil then language = "zh" end
	local infomap = item.Pickup_info[language]
	if (params.Price or 0) ~= 0 then return infomap.Price.Description end
	local infodesc = auxi.check_if_any(infomap[vr],st) or infomap.Default
	local info = auxi.check_if_any(infodesc[st]) or auxi.check_if_any(infodesc.Default,st) or auxi.check_if_any(infomap.Default.Default,vr,st)
	local desc = ""
	--if true then desc = desc .. "#" ..infomap.DamageRate..":"..tostring(math.floor(info.rate * 20)).."%" end
	--if infodesc.Adder then desc = desc .. "#" .. auxi.check_if_any(infodesc.Adder.Description) end
	--if info.Description ~= "" then desc = desc .. "#" .. info.Description end
	return desc
end

local function stop_time(ent,player)
	if ent == nil then return end
	local d = ent:GetData()
	local s = ent:GetSprite()
	for u,v in pairs(item.eventlist) do if s:IsEventTriggered(v) ~= false then s:Update() end end
	if ent:ToPickup() and ent:ToPickup().Price ~= 0 then 
		d[item.own_key.."Priceeffect"] = true
		price_holder.catch_price_over(ent)
	end
	if d.Anna_flag_freeze_succ == nil then
		d.Anna_flag_freeze_succ = Attribute_holder.try_hold_attribute(ent,"EntityFlag_FLAG_FREEZE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
	end
	if d.Anna_flag_no_sprite_update_succ == nil then
		d.Anna_flag_no_sprite_update_succ = Attribute_holder.try_hold_attribute(ent,"EntityFlag_FLAG_NO_SPRITE_UPDATE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_SPRITE_UPDATE))
	end
	if d.Anna_flag_no_query_succ == nil and ent.Type ~= 3 then
		d.Anna_flag_no_query_succ = Attribute_holder.try_hold_attribute(ent,"EntityFlag_FLAG_FLAG_NO_QUERY",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_QUERY))
	end
	if d.Anna_flag_gridcollision_succ == nil then
		d.Anna_flag_gridcollision_succ = Attribute_holder.try_hold_attribute(ent,"GridCollisionClass",EntityGridCollisionClass.GRIDCOLL_NONE)
	end
	if d.Anna_flag_entitycollision_succ == nil then
		d.Anna_flag_entitycollision_succ = Attribute_holder.try_hold_attribute(ent,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
	end
	if d.Anna_flag_depth_succ == nil then
		d.Anna_flag_depth_succ = Attribute_holder.try_hold_attribute(ent,"DepthOffset",function(ent) 
			local val = (ent:GetData()[item.own_key.."Catch"] or {})["Back"] 
			if val == true then return -100 
			elseif val == false then return 100 
			else return 0 end 
		end,{protect = true,})
	end
	if d.Anna_flag_scale_succ == nil then
		d.Anna_flag_scale_succ = Attribute_holder.try_hold_attribute(ent,"SpriteScale",function(ent) return (ent:GetData()[item.own_key.."Catch"] or {})["mScale"] or ent.SpriteScale end,{protect = true,})
	end
	if d.Anna_flag_Rotate_succ == nil then
		d.Anna_flag_Rotate_succ = Attribute_holder.try_hold_attribute(ent,"SpriteRotation",function(ent) return (ent:GetData()[item.own_key.."Catch"] or {})["Rotate"] or ent.SpriteRotation end,{protect = true,})
	end
	if d.Anna_flag_Posoffset_succ == nil then
		d.Anna_flag_Posoffset_succ = Attribute_holder.try_hold_attribute(ent,"PositionOffset",function(ent) return (ent:GetData()[item.own_key.."Catch"] or {})["Posoffset"] or ent.PositionOffset end,{protect = true,})
	end
	if ent:ToFamiliar() and d.Anna_flag_Cooldown_succ == nil then
		ent = ent:ToFamiliar()
		d.Anna_flag_Cooldown_succ = Attribute_holder.try_hold_attribute(ent,"FireCooldown",math.max(3,ent.FireCooldown))
	end
end

local function time_free(ent)
	if ent == nil then return end
	local d = ent:GetData()
	if d.Anna_flag_freeze_succ then
		local succ = Attribute_holder.try_rewind_attribute(ent,"EntityFlag_FLAG_FREEZE",d.Anna_flag_freeze_succ,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
		d.Anna_flag_freeze_succ = nil
	end
	if d.Anna_flag_no_sprite_update_succ then
		Attribute_holder.try_rewind_attribute(ent,"EntityFlag_FLAG_NO_SPRITE_UPDATE",d.Anna_flag_no_sprite_update_succ,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_SPRITE_UPDATE))
		d.Anna_flag_no_sprite_update_succ = nil
	end
	if d.Anna_flag_no_query_succ then
		Attribute_holder.try_rewind_attribute(ent,"EntityFlag_FLAG_FLAG_NO_QUERY",d.Anna_flag_no_query_succ,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_QUERY))
		d.Anna_flag_no_query_succ = nil
	end
	if d.Anna_flag_gridcollision_succ then
		Attribute_holder.try_rewind_attribute(ent,"GridCollisionClass",d.Anna_flag_gridcollision_succ)
		d.Anna_flag_gridcollision_succ = nil
	end
	if d.Anna_flag_entitycollision_succ then
		Attribute_holder.try_rewind_attribute(ent,"EntityCollisionClass",d.Anna_flag_entitycollision_succ)
		d.Anna_flag_entitycollision_succ = nil
	end
	if d.Anna_flag_depth_succ then
		Attribute_holder.try_rewind_attribute(ent,"DepthOffset",d.Anna_flag_depth_succ)
		d.Anna_flag_depth_succ = nil
	end
	if d.Anna_flag_scale_succ then
		Attribute_holder.try_rewind_attribute(ent,"SpriteScale",d.Anna_flag_scale_succ)
		d.Anna_flag_scale_succ = nil
	end
	if d.Anna_flag_Rotate_succ then
		Attribute_holder.try_rewind_attribute(ent,"SpriteRotation",d.Anna_flag_Rotate_succ)
		d.Anna_flag_Rotate_succ = nil
	end
	if d.Anna_flag_Posoffset_succ then
		Attribute_holder.try_rewind_attribute(ent,"PositionOffset",d.Anna_flag_Posoffset_succ)
		d.Anna_flag_Posoffset_succ = nil
	end
	if ent:ToFamiliar() and d.Anna_flag_Cooldown_succ then
		ent = ent:ToFamiliar()
		Attribute_holder.try_rewind_attribute(ent,"FireCooldown",d.Anna_flag_Cooldown_succ)
		d.Anna_flag_Cooldown_succ = nil
	end
	--Attribute_holder.try_hold_and_rewind_attribute(ent,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE,3)
	if d[item.own_key.."Priceeffect"] then 
		d[item.own_key.."Priceeffect"] = nil
	end
	if auxi.check_if_any(item.target[ent.Type],ent) then ent.TargetPosition = Game():GetRoom():FindFreeTilePosition(ent.Position,ent.Size) end
	if auxi.check_if_any(item.middle_target[ent.Type],ent) then
		local owner = CharacterAttackCompat.resolve_entity_player(ent, auxi.check_spawner_player(ent))
		if owner then ent.TargetPosition = Game():GetRoom():FindFreeTilePosition(ent.Position * 0.9 + owner.Position * 0.1,10) end
	end
end
--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 3 and v.Variant == 202 then print(v:ToFamiliar():GetDropRNG()) end end
--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 7 then print(v:ToLaser().SubType) end end
function item.get_anna_size(player)
	player = CharacterAttackCompat.resolve_entity_player(nil, player)
	if not player then return Vector(1, 1) end
	return player.SpriteScale * 0.5 + Vector(1,1) * 0.5
end

function item.get_anna_color(player,id)
	player = CharacterAttackCompat.resolve_entity_player(nil, player)
	if not player then return Color(1, 1, 1, 1) end
	local d = player:GetData()
	local c1 = d[item.own_key.."effect_color"] or player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1)).TearColor
	--local c1 = player.TearColor
	local c3 = Color(c1.R,auxi.sigmod(1 - c1.R,{range = 0.2,mid = 0.1,}) * c1.G,auxi.sigmod(1 - c1.R,{range = 0.2,mid = 0.1,}) * c1.B,c1.A,c1.RO * 0.7,c1.GO * 0.5,c1.BO * 0.5)
	return c3
end
--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") auxi.PrintColor(Game():GetPlayer(0).TearColor)
function item.check_charge(ent,params)
	local d = ent:GetData()
	if ent.IsGrid then return 10 end
	local tp = ((d[item.own_key.."Record"] or {}).Record or {}).Type or ent.Type 
	local ret = auxi.check_if_any(item.catch2charge[tp],ent,(d[item.own_key.."Record"] or {}).Record,item.catch2charge) or 10
	if ent:IsBoss() then ret = ret * 3 end
	return ret
end

function item.Range2charge(val)
	return math.ceil(auxi.check_lerp(val,item.Range_charger).ret)
end

function item.recatch(player,ent,col,params)
	params = params or {ent = col,}
	local d2 = ent:GetData()
	local d3 = col:GetData()
	if d3[item.own_key.."Record"] then
		d3[item.own_key.."Record"].PlayerKey = player:GetData().__Index
	end
	stop_time(col)
	d3[item.own_key.."Catcher"] = ent
	d3[item.own_key.."Catcherer"] = player
	d2[item.own_key.."Catch_pool"] = d2[item.own_key.."Catch_pool"] or {}
	if params.Position then col.Position = params.Position end
	table.insert(d2[item.own_key.."Catch_pool"],#d2[item.own_key.."Catch_pool"] + 1,params)
	--for i = 1,10 do delay_buffer.addeffe(function(params) print(#d2[item.own_key.."Catch_pool"]) end,{},i) end
	d3[item.own_key.."Catched"] = true
end

function item.replace_with(ent,params)
	params = params or {}
	local pos = params.Position or ent.Position
	if params.AddPosOffset then pos = pos + ent.PositionOffset end
	local q = Isaac.Spawn(1000,enums.Entities.Anna_Partical,0,pos,Vector(0,0),params.Player):ToEffect()	--Entity_holder.generate()
	if params.Sprite then
		auxi.copy_sprite(ent:GetSprite(),q:GetSprite())
		auxi.illustrate_sprite(ent,q:GetSprite())
		q:GetSprite():SetLastFrame()
	end
	if params.Size ~= true and ent.Size and ent.SizeMulti then q:SetSize(ent.Size,auxi.ProtectVector(ent.SizeMulti),math.ceil(ent.Size)) end
	return q
end

function item.try_catch(player,ent,col,params)
	local succ = anna_portal_holder.collide_over_it(ent,col,player) 
	if succ then
		params = params or {}
		--print(col.Mass)
		--print(col.Type)
		col = auxi.illustrate_ent(col)
		local Replace = nil
		if col.IsGrid then
			Replace = true
			local idx = player:GetData().__Index
			local q = grid_morpher.morph_grid(col:get_grid(),{spawner = player,ent = Isaac.Spawn(1000,enums.Entities.Anna_Partical,0,col:Position(),Vector(0,0),player):ToEffect(),})
			local d3 = q:GetData()
			save.elses[item.own_key.."Record"] = save.elses[item.own_key.."Record"] or {}
			save.elses[item.own_key.."Record"][idx] = save.elses[item.own_key.."Record"][idx] or {}
			d3[item.own_key.."Record"] = {Record = grid_morpher.gent2info(col:get_grid()),Sprite = auxi.sprite2table(col:GetSprite()),PlayerKey = idx,}
			table.insert(save.elses[item.own_key.."Record"][idx],#save.elses[item.own_key.."Record"][idx] + 1,d3[item.own_key.."Record"])
			auxi.tryremovegrid(col.grididx,true)
			col = q
		end
		local info = auxi.check_if_any(item.Special_info[col.Type] or {},col)
		auxi.check_if_any(info.Special,ent,col,info,player,item)
		if info.Replace then
			Replace = true
			local idx = player:GetData().__Index
			local q = item.replace_with(col,{Sprite = true,AddPosOffset = info.AddPosOffset,Player = player,})
			local d3 = q:GetData()
			local tbl = {}
			for u,v in pairs(info.Load or {}) do 
				if type(v) == "function" then tbl[u] = v(col[u],col,info)
				else tbl[u] = col[u] end
			end
			--l local save = require("Qing_Remaster_scripts.core.savedata") local auxi = require("Qing_Remaster_scripts.auxiliary.functions") auxi.PrintTable(save.elses["Player_Anna_Record"])
			save.elses[item.own_key.."Record"] = save.elses[item.own_key.."Record"] or {}
			save.elses[item.own_key.."Record"][idx] = save.elses[item.own_key.."Record"][idx] or {}
			d3[item.own_key.."Record"] = {Record = tbl,Sprite = auxi.sprite2table(col:GetSprite()),PlayerKey = idx,}
			table.insert(save.elses[item.own_key.."Record"][idx],#save.elses[item.own_key.."Record"][idx] + 1,d3[item.own_key.."Record"])
			auxi.safely_remove(col)
			col = q
		end
		local d2 = ent:GetData()
		local d3 = col:GetData()
		d3[item.own_key.."taken"] = nil
		local szinfo = auxi.check_lerp(col.Size,item.size_scaler)
		if szinfo.scale > 1 then
			local postinfo = auxi.check_lerp((d2[item.own_key.."Size_Scaler"] or {}).counter or 10,item.size_launcher)
			local rscale = ((d2[item.own_key.."Size_Scaler"] or {}).scale or 1)
			if postinfo.scalerate * rscale < szinfo.scale then d2[item.own_key.."Size_Scaler"] = {counter = 0,scale = szinfo.scale,delta = rscale * postinfo.rate + 1 * (1 - postinfo.rate),} end
		end
		stop_time(col)
		if params.Position then col.Position = params.Position end
		d3[item.own_key.."Catcher"] = ent
		d3[item.own_key.."Catcherer"] = player
		d2[item.own_key.."Catch_pool"] = d2[item.own_key.."Catch_pool"] or {}
		table.insert(d2[item.own_key.."Catch_pool"],#d2[item.own_key.."Catch_pool"] + 1,{ent = col,Replace = Replace,})
		d3[item.own_key.."Catched"] = true
		d3[item.own_key.."Catch"] = nil
		if auxi.check_if_any(item.Addition_catcher[col.Type],col) then 
			local n_entities = auxi.get_linked(col) 
			for u,v in pairs(n_entities) do	if not v:GetData()[item.own_key.."Catched"] then item.try_catch(player,ent,v) end end
		end
		--sound_tracker.PlayStackedSound(enums.SoundEffect.Rift,1,1 + auxi.random_1() * 0.5,false,0,2)
	end
end

function item.spilt_cnt(cnt)
	if item.spilt_record[cnt] then return item.spilt_record[cnt] end
	local ret = {}
	local c1 = math.ceil(cnt / 2)
	local c2 = cnt - c1
	if c2 > 0 then
		local spilt = math.ceil(auxi.check_lerp(c2,item.spilt_info).cnt)
		local c3 = math.floor(c2 / spilt)
		local cc = c2 - c3 * spilt
		ret = {c1 = c1 + c2 - spilt,c2 = 1,spilt = spilt,}
	else ret = {spilt = 0,} end
	item.spilt_record[cnt] = ret
	return ret
end

function item.fire_anna_tear(player,pos,vel,params)
	params = params or {}
	player:GetData()[item.own_key.."Protect"] = true
	local q = player:FireTear(pos,vel,true,true,true)
	player:GetData()[item.own_key.."Protect"] = nil
	if params.Sprite ~= true then 
		local s = q:GetSprite()
		s:Load("gfx/effects/nil_effect.anm2",true)
		s:Play("Idle",true)
	end
	local d = q:GetData()
	d[item.own_key.."Catched"] = true
	if not params.SuppressAttackNotify then
		-- 每帧最多一次邪眼判定（同 volley 多发不叠）
		local pd = player:GetData()
		local frame = Game():GetFrameCount()
		if pd[item.own_key.."evil_eye_frame"] ~= frame then
			pd[item.own_key.."evil_eye_frame"] = frame
			local ok, EvilEye = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Evil_Eye_holder")
			if ok and EvilEye and EvilEye.notify_player_attack then
				local aim = vel and vel:Length() > 0.01 and vel:Normalized() or nil
				EvilEye.notify_player_attack(player, aim)
			end
		end
	end
	return q
end

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_FIRE_TEAR, params = nil,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent)
	if player and player:GetData()[item.own_key.."Protect"] then
		local d = ent:GetData()
		d.Dont_Remove = true
	end
end,
})

table.insert(item.post_myToCall,#item.post_myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local d = ent:GetData()
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ then return d._Data[item.own_key][item.own_key.."record"] or val end
	if d[item.own_key.."Priceeffect"] then return -118 end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	if ent.FrameCount == 1 and ent.Price ~= 0 then 
		local d = ent:GetData()
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ then 
			local st = ent.SubType local vr = ent.Variant
			record_holder.try_hold(ent,{check = function(et) 
				if et.Price == 0 then return true,"Buy" end
				if et.SubType ~= st or et.Variant ~= vr then return true,"Turn" end
			end,Function = function(tp,et)
				if tp == "Turn" then local q = Isaac.Spawn(1000,15,0,et.Position,Vector(0,0),nil) sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2) et:Remove() end
			end,})
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local d = ent:GetData()
	if d[item.own_key.."Catched"] then return false end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_ANNAS_PORTAL_COLLISION, params = nil,
Function = function(_,ent,col,player,val)
	--if col:GetData()[item.own_key.."ignore"] then return false end
	local d2 = col:GetData()
	if d2[item.own_key.."Catched"] or d2[item.own_key.."Catch"] then return false end
	if col.IsGrid then
		if col:get_grid().CollisionClass ~= GridCollisionClass.COLLISION_NONE then
			if auxi.check_if_any(item.GridType[col:get_grid():GetType()],col) and 
				(auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_TERRA) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MEGA_MUSH)) then return true end
			if col:get_grid():GetType() == 14 and auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DIRTY_MIND) then return true end
		end
	else
		if col:IsBoss() then
			if (col:GetData()[item.own_key.."taken"] or 0)/math.max(col.HitPoints,33) > 1 then return true end
		elseif col.Type <= 1000 then return true end
	end
end,
})

function item.try_suck(player,ent,col)
	local d2 = ent:GetData()
	d2[item.own_key.."Rift_Sucker"] = d2[item.own_key.."Rift_Sucker"] or {}
	table.insert(d2[item.own_key.."Rift_Sucker"],{ent = col,ang = (col.Position - ent.Position):GetAngleDegrees() + math.random(60) - 30,info = item.suck_info,})
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if player:GetPlayerType() == item.entity or player:GetSprite():GetFilename() == "gfx/characters/reloader/Anna.anm2" then
		if cacheFlag == CacheFlag.CACHE_FLYING then player.CanFly = true end
	end
	if player:GetPlayerType() == item.entity then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then 
			local rate = 1
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MUTANT_SPIDER) then rate = 1.25
			elseif auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_INNER_EYE) then rate = 1.5
			elseif auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_20_20) then rate = 1.5 end
			player.Damage = player.Damage * rate
		end
	end
	if idx ~= nil and player:GetPlayerType() == item.entity and d[item.own_key.."Port"] then
		if cacheFlag == CacheFlag.CACHE_SPEED then
			local shotinfo = auxi.getshotinfo(player)
			local cnt = ((d[item.own_key.."Port"]:GetData()[item.own_key.."Catch_Charge2"] or 0)/100 - shotinfo.mx) * item.Range2charge(player.TearRange)
			local rate = 0.02
			if auxi.has_have_coll(player,619) then rate = 0 end
			player.MoveSpeed = player.MoveSpeed - rate * math.max(0,cnt)
		end
	end
end,
})
--[[
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	if player:GetPlayerType() == item.entity then
		local d = player:GetData()
		local idx = d.__Index
		local weap = auxi.get_weapon(player)
		save.elses.Anna_ludo_buff = save.elses.Anna_ludo_buff or {}
		save.elses.Anna_knife_buff = save.elses.Anna_knife_buff or {}
		if (auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DR_FETUS) and weap == 7) or (save.elses.Anna_knife_buff[idx] and weap == 4) then
			save.elses.Anna_knife_buff[idx] = true
			value[114] = (value[114] or 0) + 1
			save.elses.Anna_ludo_buff[idx] = nil
		else
			if weap == 7 or (save.elses.Anna_ludo_buff[idx] and weap == 8) then		--(auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_IPECAC) and weap == 1) or
				save.elses.Anna_ludo_buff[idx] = true
				value[329] = (value[329] or 0) + 1
			else
				save.elses.Anna_ludo_buff[idx] = nil
			end
			save.elses.Anna_knife_buff[idx] = nil
		end
	end
end,
})
--]]
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if (d[item.own_key.."taken"] or 0) > 0 then
		if (d[item.own_key.."take"] or 0) > 0 then d[item.own_key.."take"] = d[item.own_key.."take"] - 1
		else d[item.own_key.."taken"] = math.max(0,math.min(d[item.own_key.."taken"] - 2,d[item.own_key.."taken"] * 0.8)) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_,ent,offset)
	local d = ent:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) and ent:IsBoss() then
		local cnt = (d[item.own_key.."taken"] or 0)/math.max(ent.HitPoints,33)
		local ret = Charging_Bar_holder.render_me(ent,{name1 = item.own_key,name2 = item.own_key,name3 = item.own_key,loadname = "gfx/effects/chargebar/chargebar_Anna3.anm2",
			check1 = function(val,ent)
				return cnt > 0.05
			end,
			check2 = function(val,ent) 
				return cnt > 1
			end,
			check3 = function(val,ent)
				return math.ceil(cnt * 100)
			end,
			signal1 = function(ent)
			end,
		})
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local d = player:GetData()
	if player:GetPlayerType() == item.entity then
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			local cnt = (d[item.own_key.."charge"] or 0)
			local cnt2 = 0
			local cnt3 = d[item.own_key.."Catch_BossCharge"] or 0
			cnt = math.max(cnt,cnt3)
			if d[item.own_key.."Port"] then cnt2 = (d[item.own_key.."Port"]:GetData()[item.own_key.."Catch_Charge2"] or 0) end
			if cnt > 2 and auxi.check_all_exists(d[item.own_key.."Port"]) then cnt = cnt + cnt2
			else cnt2 = 0 end
			local shotinfo = auxi.getshotinfo(player)
			cnt = cnt / (shotinfo.mx or 1)
			cnt2 = cnt2 / (shotinfo.mx or 1)
			local ret = Charging_Bar_holder.render_me(player,{name1 = item.own_key,name2 = item.own_key,name3 = item.own_key,loadname = "gfx/effects/chargebar/chargebar_Anna.anm2",
				check1 = function(val,ent)
					return cnt > 5
				end,
				check2 = function(val,ent) 
					return cnt > 100--item["time_counter"]
				end,
				check3 = function(val,ent)
					return math.ceil(cnt)
				end,
				signal1 = function(ent)
				end,
			})
			Charging_Bar_holder.render_me(player,{name1 = item.own_key.."_",name2 = item.own_key.."_",name3 = item.own_key.."_",loadname = "gfx/effects/chargebar/chargebar_Anna2.anm2",offset = ret.pos,
				check1 = function(val,ent)
					return cnt2 > 5
				end,
				check2 = function(val,ent) 
					return cnt2 >= 100--item["time_counter"]
				end,
				check3 = function(val,ent)
					return math.ceil(cnt2)
				end,
				signal1 = function(ent)
				end,
			})
			Charging_Bar_holder.render_me(player,{name1 = item.own_key.."__",name2 = item.own_key.."__",name3 = item.own_key.."__",loadname = "gfx/effects/chargebar/chargebar_Anna1.anm2",offset = ret.pos,
				check1 = function(val,ent)
					return cnt3 > 5
				end,
				check2 = function(val,ent) 
					return cnt3 >= 100--item["time_counter"]
				end,
				check3 = function(val,ent)
					return math.ceil(cnt3)
				end,
				signal1 = function(ent)
				end,
			})
		end
	end
end,
})

function item.check_tear_offset(id,mxn)
	local mmxn = mxn
	local iid = id
	item.localizer[mxn] = item.localizer[mxn] or {}
	if item.localizer[mxn] and item.localizer[mxn][id] then return item.localizer[mxn][id] end
	local ret = {row = 1,col = 1,}
	local mcnt = 1
	while(iid > mcnt) do
		ret.col = ret.col + 1
		iid = iid - mcnt
		mmxn = mmxn - mcnt
		mcnt = mcnt + 5
	end
	mcnt = math.min(mcnt,mmxn)
	ret.row = 360 / mcnt * iid
	item.localizer[mxn][id] = ret
	return ret
end

function item.generate_port(player)
	local ent = Isaac.Spawn(1000,enums.Entities.Anna_Portal,0,player.Position,Vector(0,0),player)
	local d = ent:GetData()
	local idx = player:GetData().__Index
	d[item.own_key.."Catch_pool"] = d[item.own_key.."Catch_pool"] or {}
	--print("Reloaded:"..#((save.elses[item.own_key.."Record"] or {})[idx] or {}))
	for u,v in pairs((save.elses[item.own_key.."Record"] or {})[idx] or {}) do 
		local q = item.replace_with(v.Record,{Position = player.Position,Player = player,})
		local d2 = q:GetData()
		d2[item.own_key.."Record"] = auxi.deepCopy(v)
		d2[item.own_key.."Record"].PlayerKey = idx
		item.recatch(player,ent,q,{ent = q,Virtual = true,})
	end
	return ent
end

function item.check_mass(ent,info)
	if info.Virtual or info.Replace then
		local info,Adder = item.ent2info(ent)
		return info.rate or 1
	else
		if ent:IsBoss() then 
			return auxi.check_lerp(ent.Mass,item.damage_rate.boss).rate
		elseif auxi.isenemies(ent) then
			return auxi.check_lerp(ent.Mass,item.damage_rate.normal).rate
		end
	end
	return 1
end

function item.sort_by(tbl,params)
	params = params or {}
	table.sort(tbl,function(a,b)
		local vala,valb = (a.ent.HitPoints + a.ent.MaxHitPoints * 0.3) + 60,(b.ent.HitPoints + b.ent.MaxHitPoints * 0.3) + 60
		if a.ent:IsBoss() then vala = vala + 1000 end
		if b.ent:IsBoss() then valb = valb + 1000 end
		local tpa = (a.ent:GetData()[item.own_key.."record"] or {})["Type"] or a.ent.Type
		local tpb = (b.ent:GetData()[item.own_key.."record"] or {})["Type"] or b.ent.Type
		if item.Special_info[tpa] then vala = auxi.check_if_any(item.Special_info[tpa].Weigh,a) or vala end
		if item.Special_info[tpb] then valb = auxi.check_if_any(item.Special_info[tpb].Weigh,b) or valb end
		return vala > valb
	end)
	local cut = (params.cnt or 1)
	if cut == 1 then return {tbl}
	else
		local ret = {}
		local ncut = math.ceil(#tbl / cut) * cut
		for i = 1,cut do ret[i] = {} end
		for i = 1,#tbl do table.insert(ret[i % cut + 1],#ret[i % cut + 1] + 1,tbl[i]) end
		--for i = #tbl + 1,ncut do table.insert(ret[i % cut + 1],#ret[i % cut + 1] + 1,{})
		return ret
	end
end

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_NPC_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	if player and player:GetPlayerType() == item.entity then
		if auxi.check_if_any(item.collision_ignorers[ent.Type],ent) then
			local succ = auxi.find_in_parents(ent,function(v) 
				if v:GetData()[item.own_key.."Catched"] then return true end
			end)
			if succ then return true end
		end
		if ent:GetData()[item.own_key.."Catched"] then return true end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	if player:GetPlayerType() == item.entity then
		if Game():GetFrameCount() == 0 then player:AddGoldenBomb() end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if player:GetPlayerType() == item.entity then
		local d = player:GetData()
		if item._room_reget_done_epoch ~= (item._room_epoch or 0) then
			item._room_reget_done_epoch = item._room_epoch or 0
			for _, ent in pairs(Isaac.GetRoomEntities()) do item.reget_ent(ent) end
		end
		local s = player:GetSprite()
		local dir2 = auxi.ggdir(player,false,true,nil,nil,{ignore_canwork = true,real = true,})
		local dir = auxi.ggdir(player,true,true,nil,nil,{real = true,})
		d[item.own_key.."Dir"] = dir
		d[item.own_key.."Dir2"] = dir2
		if auxi.check_all_exists(d[item.own_key.."Port"]) ~= true then
			d[item.own_key.."Port"] = item.generate_port(player)
			d[item.own_key.."List"] = auxi.get_Anna_list(player)
		end
		d[item.own_key.."List"] = d[item.own_key.."List"] or auxi.get_Anna_list(player)
		local list = d[item.own_key.."List"]
		if (d[item.own_key.."effect_counter"] or 0) <= 0 then 
			d[item.own_key.."effect_color"] = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1)).TearColor 
			d[item.own_key.."effect_counter"] = 15
		end
		d[item.own_key.."effect_counter"] = (d[item.own_key.."effect_counter"] or 0) - 1
		local ent = d[item.own_key.."Port"]
		local d2 = ent:GetData()
		if Game():IsPaused() then
		else
			local del = 30 / (player.MaxFireDelay + 1)
			local ctrlid = player.ControllerIndex
			if dir:Length() > 0.5 then 
				d[item.own_key.."charge"] = (d[item.own_key.."charge"] or 0) + 0.2 * del
				d[item.own_key.."DirRecord"] = dir2
			end
			local cnt = (d[item.own_key.."charge"] or 0)
			local cnt3 = d[item.own_key.."Catch_BossCharge"] or 0
			cnt = math.max(cnt,cnt3)
			if cnt > 2 then cnt = cnt + (d[item.own_key.."Port"]:GetData()[item.own_key.."Catch_Charge2"] or 0) end
			local shotinfo = auxi.getshotinfo(player)
			local charge = math.min(cnt/100,shotinfo.mx)
			if (dir:Length() < 0.5 or cnt3 >= 100) and auxi.g_dir_can_work(player) then		-- or auxi.has_mark(player)
				if charge >= shotinfo.lw and not (Input.IsActionTriggered(11,ctrlid) or Input.IsActionPressed(11,ctrlid)) then		--发射
					local idx = player:GetData().__Index
					save.elses[item.own_key.."Record"] = save.elses[item.own_key.."Record"] or {}
					--for u,v in pairs(save.elses[item.own_key.."Record"][idx] or {}) do table.insert(item.save_holder,#item.save_holder + 1,v) end
					--print(#(save.elses[item.own_key.."Record"][idx] or {}))
					save.elses[item.own_key.."Record"][idx] = {}
					d2[item.own_key.."Push"] = {counter = 0,}
					d2[item.own_key.."Catch_pool2"] = d2[item.own_key.."Catch_pool2"] or {}
					local ctn = 0
					for u,v in pairs(d2[item.own_key.."Catch_pool"]) do 
						if v.Virtual or ((v.ent:GetData()[item.own_key.."Catch"] or {})["counter"] or 0) > item.delayoffset then ctn = ctn + 1 end
					end
					local ct = math.max(1,ctn)
					local tbl = {}
					local tbl2 = {}
					for i = #d2[item.own_key.."Catch_pool"],1,-1 do 
						local v = d2[item.own_key.."Catch_pool"][i]
						local ve = v.ent
						local d3 = ve:GetData()
						if v.Virtual or ((d3[item.own_key.."Catch"] or {})["counter"] or 0) > item.delayoffset then
							if v.Virtual and d3[item.own_key.."Record"] then 
								auxi.table2sprite(d3[item.own_key.."Record"].Sprite,ve:GetSprite())
								auxi.illustrate_sprite_(d3[item.own_key.."Record"].Record,ve:GetSprite(),ve)
							end
							(d3[item.own_key.."Catch"] or {})["Back"] = nil
							if (v.Replace or v.Virtual) and ((d3[item.own_key.."Record"] or {}).Record or {}).Type == 9 then table.insert(tbl2,#tbl2 + 1,v) 
							else table.insert(tbl,#tbl + 1,v) end
							if d3[item.own_key.."Record"] then d3[item.own_key.."Record"].Fired = true end
							table.remove(d2[item.own_key.."Catch_pool"],i)
						elseif d3[item.own_key.."Record"] then 
							table.insert(save.elses[item.own_key.."Record"][idx],#save.elses[item.own_key.."Record"][idx] + 1,d3[item.own_key.."Record"])
						end
					end
					if #tbl > 0 or #tbl2 > 0 then
						--sound_tracker.PlayStackedSound(SoundEffect.SOUND_MOTHER_SHOOT,1,1,false,0,2)
						local multishot_of_player = auxi.get_Anna_multishots(player,list,{charge = charge,})
						local cnt,cnt2 = (#multishot_of_player),0
						for u,v in pairs(multishot_of_player) do if v.Ignore then cnt2 = cnt2 + 1 cnt = cnt - 1 end end
						tbl = item.sort_by(tbl,{cnt = cnt,})
						tbl2 = item.sort_by(tbl2,{cnt = cnt,})
						for i = 1,cnt + cnt2 do
							local w = tbl[i] or {}
							local rt = auxi.random_0()
							local ct = #w
							local basicinfo = multishot_of_player[i]
							local shotspeed = player.ShotSpeed
							local dmg = 0
							for u,v in pairs(w) do 
								local info,infodesc = item.ent2info(v.ent)
								for o,p in pairs({info,(infodesc or {}).Adder,}) do 
									--shotspeed = shotspeed + (p.ShotSpeed or 0) * 0.1
									dmg = dmg + (p.Dmg or 0)
								end
							end
							local nvel = auxi.get_by_rotate(d[item.own_key.."DirRecord"] or Vector(1,0),basicinfo.dir)
							local AddVelocity = shotspeed * nvel * (10 + (basicinfo.shotspeed or 0))
							local q = item.fire_anna_tear(player,ent.Position + (auxi.check_if_any(basicinfo.Posoffset,nvel) or Vector(0,0)),AddVelocity + ent.Velocity * 0.4,{Sprite = (ct == 0),})
							auxi.check_if_any(basicinfo,player,q)
							local d4 = q:GetData()
							--l local player = Game():GetPlayer(0) local q = player:FireTear(player.Position,Vector(0,0),true,true,true) print(q.TearFlags) print(q:GetEntityFlags())
							local weapon = auxi.get_weapon(player)
							local tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
							if weapon == 14 or auxi.has_have_coll(player,678) then
								q.TearFlags = q.TearFlags | BitSet128(0,1<<(114-64)) | BitSet128(1<<0,0) & (~BitSet128(0,1<<(68-64)))
								for u,v in pairs(item.Sec_buffs) do if (v.check == nil and auxi.has_have_coll(player,u)) or auxi.check_if_any(v.check,player) then q.TearFlags = q.TearFlags | (v.TearFlags or BitSet128(0,0)) end end
							end
							d4[item.own_key.."effect"] = {linkers = {},tearHitParams = tearHitParams,}
							q.TearFlags = (q.TearFlags | tearHitParams.TearFlags | (basicinfo.tearflag or BitSet128(0,0))) & (~TearFlags.TEAR_WAIT)--| BitSet128(0,1<<(83-64)) --& ~(BitSet128(1<<58,0) | BitSet128(1<<59,0) | BitSet128(1<<60,0) | BitSet128(1<<0,0))
							Attribute_holder.try_hold_and_rewind_attribute(q,"GridCollisionClass",EntityGridCollisionClass.GRIDCOLL_WALLS,3)
							local s1 = q.Size
							d4[item.own_key.."RSize"] = s1
							d4[item.own_key.."RScale"] = q.Scale
							q.Scale = q.Scale + math.max(0,(item.check_tear_offset(ct,ct).col - 1) * 10/q.Size - 1) * math.min(1,q.Scale)
							q:SetSize(q.Size,q.SizeMulti,math.ceil(s1))
							local mass = 0
							for j = 1,ct do
								local v = w[j]
								local ve = v.ent
								local d3 = ve:GetData()
								local posinfo = item.check_tear_offset(j,ct)
								v.AddVelocity = AddVelocity
								v.Position = d[item.own_key.."Port"].Position
								v.TgPos = auxi.MakeVector(posinfo.row) * (posinfo.col - 1) * 10
								v["RotateRnd"] = rt * (auxi.random_1() * 20 + 35)
								mass = mass + (item.check_mass(ve,v) or 1)
								local info,infodesc = item.ent2info(ve)
								--for o,p in pairs({info,(infodesc or {}).Adder,}) do auxi.check_if_any(p.Shift,q,player) end
								v.tear = q
								table.insert(d2[item.own_key.."Catch_pool2"],#d2[item.own_key.."Catch_pool2"] + 1,v)
								table.insert(d4[item.own_key.."effect"].linkers,#d4[item.own_key.."effect"].linkers + 1,v)
							end
							q.CollisionDamage = d4[item.own_key.."effect"].tearHitParams.TearDamage * (mass * 0.4 + 0.5) * charge + dmg
							
							local ct2 = #(tbl2[i] or {})
							for j = 1,ct2 do 
								local v = tbl2[i][j]
								local posinfo = item.check_tear_offset(j + ct,ct2 + ct)
								local tgpos = auxi.MakeVector(posinfo.row) * ((posinfo.col - 1) * 10) --auxi.MakeVector(j/ct2 * 360) * q.Size
								local q2 = item.fire_anna_tear(player,q.Position + tgpos,AddVelocity + player.Velocity * 0.4)
								local d5 = q2:GetData()
								d5[item.own_key.."effect2"] = {tg = q,row = posinfo.row,col = (posinfo.col - 1) * 10 + q.Size * 0.9,RotateRnd = rt * (auxi.random_1() * 5 + 3),}
								v.tear = q2
								v.AddVelocity = AddVelocity
								v.Position = d[item.own_key.."Port"].Position
								v.TgPos = Vector(0,0)	--tgpos
								table.insert(d2[item.own_key.."Catch_pool2"],#d2[item.own_key.."Catch_pool2"] + 1,v)
								q.CollisionDamage = q.CollisionDamage + q2.CollisionDamage * 0.3
								local pf = v.ent:GetData()[item.own_key.."Record"].Record.ProjectileFlags
								for u,v in pairs(item.Flag_Expack) do if (pf & (1<<u) == (1<<u)) then q2.TearFlags = q2.TearFlags | v.TearFlag end end
							end
							
							Isaacs_Tear_holder.add_tear(player)
							if weapon == 14 or auxi.has_have_coll(player,678) then
								q.TearFlags = q.TearFlags & (~BitSet128(0,1<<(68-64)))
							end
							if weapon == 2 or auxi.has_have_coll(player,118) then 
								if i == 1 then 
									for u,v in pairs(d2[item.own_key.."Brimstone"] or {}) do if auxi.check_all_exists(v) then v:SetTimeout(1) end end 
									d2[item.own_key.."Brimstone"] = {}
								end
								local both = (weapon == 2 and auxi.has_have_coll(player,118))
								local t
								if both then t = player:FireBrimstone(nvel,nil,1 * charge)
								else t = player:FireBrimstone(nvel,nil,0.5 * charge) if not auxi.has_have_coll(player,118) then t.MaxDistance = player.TearRange * 0.3 end end
								t.PositionOffset = ent.PositionOffset
								t.Parent = ent
								t.Position = ent.Position
								t.TearFlags = (t.TearFlags | (basicinfo.tearflag or BitSet128(0,0))) & (~TearFlags.TEAR_WAIT)
								table.insert(d2[item.own_key.."Brimstone"],#d2[item.own_key.."Brimstone"] + 1,t)
								local d5 = t:GetData()
								d5[item.own_key.."Dir"] = basicinfo.dir
								if (list.soy or 0) > 0 or (list.soy2 or 0) > 0 then t:SetTimeout(-1)
								else t:SetTimeout(t.Timeout * 3) end
							end
							if weapon == 3 or auxi.has_have_coll(player,68) then 
								local both = (weapon == 3 and auxi.has_have_coll(player,68))
								local t
								if both then t = player:FireTechLaser(q.Position,0,nvel,true,false,nil,1 * charge)
								else t = player:FireTechLaser(q.Position,0,nvel,true,false,nil,0.5 * charge) t.MaxDistance = player.TearRange * 0.5 end
								t.TearFlags = t.TearFlags & (~TearFlags.TEAR_WAIT)
								t.PositionOffset = q.PositionOffset
								t.Parent = q
								t:SetTimeout(-1)
								d4[item.own_key.."Link_Tech"] = d4[item.own_key.."Link_Tech"] or {}
								table.insert(d4[item.own_key.."Link_Tech"],#d4[item.own_key.."Link_Tech"] + 1,t)
								local d5 = t:GetData()
								d5[item.own_key.."Linker"] = ent
							end
							if auxi.has_have_coll(player,524) or q.TearFlags & BitSet128(1<<57,0) == BitSet128(1<<57,0) then
								local t = Isaac.Spawn(7,10,4,q.Position,Vector(0,0),player):ToLaser() --player:FireTechLaser(q.Position,0, - nvel,true,false,nil,0.5 * charge) 
								t.Variant = 10
								t.TearFlags = t.TearFlags & (~TearFlags.TEAR_WAIT)
								t.PositionOffset = q.PositionOffset
								t.Parent = q
								t:SetTimeout(-1)
								q.CollisionDamage = player.Damage * 0.5 * charge
								d4[item.own_key.."Link_Tech"] = d4[item.own_key.."Link_Tech"] or {}
								table.insert(d4[item.own_key.."Link_Tech"],#d4[item.own_key.."Link_Tech"] + 1,t)
								t:GetData()[item.own_key.."Linker"] = ent
								local d5 = t:GetData()
								d5[item.own_key.."Dir"] = 180
								d5[item.own_key.."Dis"] = function(ent,dis) return dis:Length() end
							end
							if auxi.has_have_coll(player,229) or weapon == 7 then
								local ts = auxi.fire_lung(ent.Position,nil,player,{dir = nvel:Normalized(),dmgrate = charge,})
							end
							if weapon == 6 or auxi.has_have_coll(player,168) then
								local both = (weapon == 6 and auxi.has_have_coll(player,168))
								d4[item.own_key.."Epic"] = math.max(1,player:GetCollectibleNum(168))
							end
							if weapon == 9 or auxi.has_have_coll(player,395) then
								local both = (weapon == 9 and auxi.has_have_coll(player,395))
								local t
								if both then t = player:FireTechXLaser(q.Position,AddVelocity,40 * charge + q.Size,nil,1 * charge)
								else t = player:FireTechXLaser(q.Position,AddVelocity,20 * charge + q.Size,nil,0.5 * charge) end
								t.PositionOffset = q.PositionOffset
								t.Parent = q
								--t.SubType = 3
								--if item.brim_list[t.Variant] then t.Variant = 3 end
								d4[item.own_key.."Link_TechX"] = d4[item.own_key.."Link_TechX"] or {}
								table.insert(d4[item.own_key.."Link_TechX"],#d4[item.own_key.."Link_TechX"] + 1,t)
								local d5 = t:GetData()
								d5[item.own_key.."TechXLinker"] = q
								d5[item.own_key.."TechXDir"] = AddVelocity
							end
							if auxi.has_have_coll(player,399) or auxi.has_have_coll(player,408) then
								local t = player:SpawnMawOfVoid(35)
								local both = (auxi.has_have_coll(player,408) and auxi.has_have_coll(player,395))
								if both then
									t.CollisionDamage = player.Damage * charge
									t.Radius = 60
								else
									t.CollisionDamage = player.Damage * 0.5 * charge
									t.Radius = 30
								end
								t.Variant = 3
								t.SubType = 2
								t.Parent = q
								t:SetTimeout(-1)
								d4[item.own_key.."Link_TechX"] = d4[item.own_key.."Link_TechX"] or {}
								table.insert(d4[item.own_key.."Link_TechX"],#d4[item.own_key.."Link_TechX"] + 1,t)
								local d5 = t:GetData()
								d5[item.own_key.."TechXLinker"] = q
								d5[item.own_key.."TechXDir"] = AddVelocity
								d5[item.own_key.."TechXBreak"] = true
							end
							if weapon == 5 or auxi.has_have_coll(player,52) then
								local both = (weapon == 5 and auxi.has_have_coll(player,52))
								d4[item.own_key.."Dr."] = math.max(1,player:GetCollectibleNum(52))
							end
							if weapon == 4 or auxi.has_have_coll(player,114) then
								local both = (weapon == 4 and auxi.has_have_coll(player,114))
								local cnt = 1 + player:GetCollectibleNum(114)
								if both then cnt = cnt + 2 end
								d4[item.own_key.."Knife"] = {}
								d4[item.own_key.."KnifeInfo"] = {}
								for i = 1,cnt do 
									local t = Isaac.Spawn(EntityType.ENTITY_KNIFE,0,0,Vector(2000,0),Vector(0,0), nil):ToKnife()
									t.CollisionDamage = player.Damage * charge
									t.TearFlags = q.TearFlags
									t:GetSprite().Color = tearHitParams.TearColor
									t.Parent = q
									table.insert(d4[item.own_key.."Knife"],#d4[item.own_key.."Knife"] + 1,t)
								end
							end
							if weapon == 13 or auxi.has_have_coll(player,579) then
								local both = (weapon == 13 and auxi.has_have_coll(player,579))
								local cnt = math.max(1,player:GetCollectibleNum(579))
								if both then
									local params = {
										cooldown = 16,
										player = player,
										tearflags = q.TearFlags,
										Color = tearHitParams.TearColor,
										Tech = player:HasCollectible(68) or player:HasCollectible(395),
										RotationOffset = nvel:GetAngleDegrees(),
										follower = q,
									}
									local t = auxi.fire_Sword(ent.Position,nvel,player.Damage * charge,nil,params)
									delay_buffer.addeffe(function(params)
										sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME,1,1,false,0,2)
									end,{},4)
								else
									local params = {
										cooldown = 8,
										player = player,
										tearflags = q.TearFlags,
										Color = tearHitParams.TearColor,
										Tech = player:HasCollectible(68) or player:HasCollectible(395),
										Attack = true,
										RotationOffset = nvel:GetAngleDegrees(),
										follower = q,
									}
									local q2 = auxi.fire_Sword(ent.Position,nvel,player.Damage * 0.4 * charge,nil,params)
									delay_buffer.addeffe(function(params)
										sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME,1,1,false,0,2)
									end,{},4)
								end
							end
							if auxi.has_have_coll(player,495) or auxi.has_have_coll(player,616) then
								local both = auxi.has_have_coll(player,495) and auxi.has_have_coll(player,616)
								if auxi.has_have_coll(player,495) and auxi.check_rand(player.Luck,50,10,10) then
									local q = Isaac.Spawn(1000,EffectVariant.BLUE_FLAME,0,ent.Position,nvel:Normalized() * 15 * player.ShotSpeed,player):ToEffect()
									q:SetTimeout(60)
									q.LifeSpan = 60
									q.CollisionDamage = player.Damage * 4 * charge
								elseif auxi.has_have_coll(player,616) and ((both and auxi.check_rand(player.Luck,100,10,10)) or auxi.check_rand(player.Luck,50,10,10)) then
									local q = Isaac.Spawn(1000,EffectVariant.RED_CANDLE_FLAME,0,ent.Position,nvel:Normalized() * 15 * player.ShotSpeed,player):ToEffect()
									q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
									q.CollisionDamage = player.Damage * 3 * charge
								end
							end
						end
						-- 主齐射已经成功生成，且 Catch_pool2 已保存本次捕获物快照后再复制。
						local CharacterFamiliars = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")
						CharacterFamiliars.dispatch_registered_copies(player, {
							aim_dir = d[item.own_key.."DirRecord"] or dir2,
							damage_mul = charge,
						})
						SFXManager():Stop(SoundEffect.SOUND_TEARS_FIRE)
						for j = 1,2 do delay_buffer.addeffe(function(params) SFXManager():Stop(SoundEffect.SOUND_TEARS_FIRE) end,{},j) end
					end

					if ctn > 0 then d[item.own_key.."charge"] = 0 end
				end
				if not (auxi.has_mark(player) and dir:Length() > 0.5) then d[item.own_key.."charge"] = 0 end
			end
			if Input.IsActionTriggered(11,ctrlid) or Input.IsActionPressed(11,ctrlid) then
				if (d[item.own_key.."Call"] or 0) > 0 and d[item.own_key.."Call"] ~= 15 then
					if auxi.is_all_clear() and (d[item.own_key.."Port"]:GetSprite().Scale:Length() > 0.8) then
						local n_entity = Isaac.GetRoomEntities() 
						for u,v in pairs(n_entity) do 
							if not v:GetData()[item.own_key.."Catched"] and v:GetData()[item.own_key.."HaveCatched"] then 		--and ((v.ToPickup() or {}).Price or 0) == 0
								local q = auxi.fire_nil(v.Position,auxi.RoundVector(nil,20),{cooldown = 120,})
								local d3 = q:GetData()
								d3.nil_mode = "anna_nileffect"
								d3[item.own_key.."Nileffect"] = {tg = d2[item.own_key.."Port"],Renderer = v,Speed = 0.3,}
								item.try_catch(player,d[item.own_key.."Port"],v,{Position = d[item.own_key.."Port"].Position,}) 
							end 
						end
					end
				end
				d[item.own_key.."Call"] = 15
			else
				if (d[item.own_key.."Call"] or 0) > 0 then d[item.own_key.."Call"] = d[item.own_key.."Call"] - 1 end
			end
		end
	end
end,
})
--[[
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_EVERY_ENTITY_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if (d[item.own_key.."Lasercounter"] or 0) > 0 then d[item.own_key.."Lasercounter"] = d[item.own_key.."Lasercounter"] - 1 end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_,ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if player and player:GetPlayerType() == item.entity and flag & DamageFlag.DAMAGE_LASER == DamageFlag.DAMAGE_LASER and source and source.Entity then
		local col = source.Entity
		local d2 = col:GetData()
		if (d2[item.own_key.."Lasercounter"] or 0) <= 0 then 
			d2[item.own_key.."Lasercounter"] = 3
			return false 
		end
	end
end,
})

--]]
function item.check_for_laser(ent)
	if ent.SubType == 0 and auxi.check_spawner_player(ent) == nil then
		local tg, best_distance = nil, nil
		for i = 0, Game():GetNumPlayers() - 1 do
			local candidate_player = Isaac.GetPlayer(i)
			if candidate_player:GetPlayerType() == item.entity then
				local candidate = candidate_player:GetData()[item.own_key.."Port"]
				if auxi.check_all_exists(candidate) then
					local distance = (candidate.Position - ent.Position):LengthSquared()
					if best_distance == nil or distance < best_distance then tg, best_distance = candidate, distance end
				end
			end
		end
		if not tg then return end
		if (tg:GetData()[item.own_key.."Scaler"] or 0) < 0.8 then return end
		local ang = ent.Angle
		local dir = tg.Position - ent.Position
		local dang = math.rad(dir:GetAngleDegrees() - ang)
		local samplePoints = ent:GetSamples()
		local st_pos = ent.Position
		local ep = ent:GetEndPoint()
		local mx_dst = 0
		for i = 0, #samplePoints - 1 do
			local pos = samplePoints:Get(i)
			local idir = pos - st_pos
			local tdir = tg.Position - st_pos
			local ang = idir:GetAngleDegrees()
			local dang = math.rad(tdir:GetAngleDegrees() - ang)
			if tdir:Length() * math.cos(dang) <= idir:Length() and (tdir:Length() * math.cos(dang) >= 0) and (math.abs(tdir:Length() * math.sin(dang)) < ent.Size + tg.Size) then
				ent.TearFlags = BitSet128(0,0)
				ent.Angle = dir:GetAngleDegrees()
				ent.MaxDistance = math.max(0,dir:Length() - ent.Size)
				st_pos = ep
				break
			end
			st_pos = pos
			mx_dst = mx_dst + idir:Length()
		end
		if st_pos ~= ep and (dir:Length() * math.cos(dang) <= (st_pos - ep):Length()) and (dir:Length() * math.cos(dang) >= 0) and (math.abs(dir:Length() * math.sin(dang)) < ent.Size + tg.Size) then ent.MaxDistance = dir:Length() * math.cos(dang) - ent.Size end 
		if ent.MaxDistance ~= 0 and ent.MaxDistance < 0.5 then ent:Remove() end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	--item.check_for_laser(ent)
	--之后再追加吸收殆尽的效果
	if ent.Parent and ent.Parent:ToTear() then
		local pe = ent.Parent:ToTear()
		if ent.MaxDistance == 30 and pe.TearFlags & BitSet128(1<<60,0) == BitSet128(1<<60,0) and pe:GetData()[item.own_key.."effect"] then
			ent.CollisionDamage = ent.Parent:ToTear().CollisionDamage * 0.33
		end
	end
	local d = ent:GetData()
	if d[item.own_key.."TechXLinker"] and auxi.check_exists(d[item.own_key.."TechXLinker"]) ~= true then
		d[item.own_key.."TechXLinker"] = nil
	end
	if d[item.own_key.."TechXBreak"] and d[item.own_key.."TechXLinker"] == nil then
		ent.Color = auxi.AddColor(ent.Color,Color(0,0,0,1),1,-0.01)
		if ent.Color.A < 0.01 then ent:Remove() end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = enums.Entities.Anna_Portal,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	ent.PositionOffset = item.portal_offset
	s.Scale = Vector(0,0)
	ent.DepthOffset = 1
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = enums.Entities.Anna_Portal,
Function = function(_,ent)
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local rpos = Isaac.WorldToScreen(ent.Position + ent.PositionOffset)
		local fr = s:GetFrame()
		local dir = d[item.own_key.."Dir"] or Vector(0,1)
		if d[item.own_key.."Push"] then dir = d[item.own_key.."dir"] or dir end
		local id = 1
		if dir.Y < -0.2 then id = 2 end
		Order = item.Port_order[id]
		local c1 = d[item.own_key.."Record_Color"] or item.get_anna_color(player)
		local sz = item.get_anna_size(player)
		for u,v in pairs(Order) do
			local offsetscale = 1
			local i = v.id
			local anim = "R"..tostring(i)
			d[item.own_key..anim] = auxi.copy_sprite(s,d[item.own_key..anim])
			local st = d[item.own_key..anim]
			if dir.Y > 0.999 and item.Port_info[i] then st.Rotation = fr/24*360 st:SetFrame(anim,0)
			else st.Rotation = 0 st:SetFrame(anim,fr) end
			if item.Port_info[i] then 
				local c = auxi.check_lerp(fr,item.Port_info[i]).C/255
				local col = Color(c,c,c,v.A or 1,1,1,1)
				st.Color = auxi.MulColor(c1,col)
				local dir_mul = auxi.mul_t(sz,Vector(math.abs(dir.Y) * 0.8 + 0.2,1 + math.abs(dir.X) * 0.2))
				st.Scale = (d[item.own_key.."Scaler"] or 0) * dir_mul
			else
				st.Color = c1
				st.Scale = (d[item.own_key.."Scaler"] or 0) * auxi.mul_t(sz,Vector(math.abs(dir.Y) * 0.7 + 0.3,1 + math.abs(dir.X) * 0.2))
			end
			if d[item.own_key.."Push"] then 
				local cnt = d[item.own_key.."Push"].counter or 0
				local info = auxi.check_lerp(cnt,item.push_scaler)
				st.Scale = auxi.mul_t(st.Scale,info.scale)
				offsetscale = offsetscale * info.offsetscale
			end
			if d[item.own_key.."Size_Scaler"] then
				local cnt = d[item.own_key.."Size_Scaler"].counter or 0
				local info = auxi.check_lerp(cnt,item.size_launcher)
				st.Scale = st.Scale * (d[item.own_key.."Size_Scaler"].rscaler or (1 * (1 - info.rate) + (d[item.own_key.."Size_Scaler"].scale or 1) * info.rate) * (1 - (d[item.own_key.."Size_Scaler"].rrate or 1)) + (d[item.own_key.."Size_Scaler"].rrate or 1) * d[item.own_key.."Size_Scaler"].delta)
			end
			st:Render(rpos + offsetscale * (v.Offset or Vector(0,0)) * dir.X,Vector(0,0),Vector(0,0))
		end
		for i = #(d[item.own_key.."Rift_Sucker"] or {}),1,-1 do
			local v = d[item.own_key.."Rift_Sucker"][i]
			local st = auxi.copy_sprite(s)
			local info = auxi.check_if_any(v.info or item.suck_info,ent,fr,u,v,item)
			if info then
				st.Color = c1
				st.Scale = (d[item.own_key.."Scaler"] or 0) * auxi.mul_t(sz,Vector(math.abs(dir.Y) * 0.4 + 0.6,1 + math.abs(dir.X) * 0.2))
				st.Rotation = info.Rotation
				st:SetFrame("R6",info.fr)
				st:Render(rpos + (v.Offset or Vector(0,0)) * dir.X,Vector(0,0),Vector(0,0))
				if info.rm then table.remove(d[item.own_key.."Rift_Sucker"],i) end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = nil,
Function = function(_,ent)
	if item.snd_remover[ent.Variant] then
		local info = item.snd_remover[ent.Variant]
		local n_entity = Isaac.FindInRadius(ent.Position,50,EntityPartition.TEAR)
		for u,v in pairs(n_entity) do 
			if v:GetData()[item.own_key.."effect"] then ent:Remove() for u,v in pairs(info.Snd or {}) do SFXManager():Stop(v) end return end 
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 1000,
Function = function(_,ent)
	local d = ent:GetData()
	if ent.Variant == enums.Entities.Anna_Partical and Game():GetRoom():GetFrameCount() == 0 and d[item.own_key.."Record"] and d[item.own_key.."Record"].Fired then
		local record = d[item.own_key.."Record"]
		local player = CharacterAttackCompat.resolve_entity_player(ent, record.Player)
			or item.get_anna(record.PlayerKey)
		if player then
			local idx = player:GetData().__Index
			d[item.own_key.."Record"].Fired = nil
			save.elses[item.own_key.."Record"] = save.elses[item.own_key.."Record"] or {}
			save.elses[item.own_key.."Record"][idx] = save.elses[item.own_key.."Record"][idx] or {}
			table.insert(save.elses[item.own_key.."Record"][idx],#save.elses[item.own_key.."Record"][idx] + 1,d[item.own_key.."Record"])
		end
	end
end,
})

function item.break_anna_tear(ent,col,tp)
	local ret = {}
	local d = ent:GetData()
	if not d[item.own_key.."effect"] then return end
	if d[item.own_key.."effect"].Break then return end
	if (d[item.own_key.."effect"].Delay or 0) > 0 then return end
	d[item.own_key.."effect"].Delay = 5
	--print((d[item.own_key.."effect"].Dis or 0))
	local player = CharacterAttackCompat.resolve_entity_player(ent, auxi.check_spawner_player(ent))
	if not player then return end
	if tp ~= "Trail" then sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_BURST_SMALL,1 + auxi.random_1() * 0.5,1,false,0,2) end
	if (d[item.own_key.."effect"].counter or 0) > 0 then return end
	for u,v in pairs(d[item.own_key.."effect"].linkers) do 
		v.Dmg = (v.Dmg or 0) * 0.8 + ent.CollisionDamage
		--if col then 
			--local info,infodesc = item.ent2info(v.ent)
			--for o,p in pairs({info,(infodesc or {}).Adder,}) do auxi.check_if_any(p.Hit,ent,col,player) end
		--end
	end
	local cnt = #d[item.own_key.."effect"].linkers
	local spilt_info = item.spilt_cnt(cnt)
	local enemy = false
	if spilt_info.spilt > 0 then
		local tbl = {}
		for i = #d[item.own_key.."effect"].linkers,spilt_info.c1 + 1,-1 do
			table.insert(tbl,#tbl + 1,d[item.own_key.."effect"].linkers[i])
			table.remove(d[item.own_key.."effect"].linkers,i)
		end
		tbl = item.sort_by(tbl,{cnt = spilt_info.spilt,})
		local rndvec = math.random(360)
		for i = 1,spilt_info.spilt do
			for u,v in pairs(tbl[i]) do
				v.marked = v.tear
				v.tear = nil
				v.ent.Velocity = ent.Velocity + auxi.MakeVector(rndvec + (i + auxi.random_1()) * 360/spilt_info.spilt) * 5
				if auxi.isenemies(v.ent) then enemy = true end
			end
		end
		if tp == "Trail" then sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_BURST_SMALL,1 + auxi.random_1() * 0.5,1,false,0,2) end
	else
		ret.NoSplit = true
	end
	if d[item.own_key.."Epic"] then
		if d[item.own_key.."Epic"] > 0 then
			auxi.launch_Missile(ent.Position,Vector(0,0),nil,{player = player,})
			d[item.own_key.."Epic"] = d[item.own_key.."Epic"] - 1
		else
			if auxi.check_rand(player.Luck,30,10,10) then auxi.launch_Missile(ent.Position,Vector(0,0),nil,{player = player,}) end
		end
	end
	if d[item.own_key.."Dr."] then
		if d[item.own_key.."Dr."] > 0 then
			local q = player:FireBomb(ent.Position,ent.Velocity)
			if q.Variant == 19 or q.Variant == 20 then 
			else q:SetExplosionCountdown(math.random(7) + 3) end
			d[item.own_key.."Dr."] = d[item.own_key.."Dr."] - 1
		else
			if auxi.check_rand(player.Luck,30,10,10) then player:FireBomb(ent.Position,ent.Velocity) end
		end
	end
	if d[item.own_key.."KnifeInfo"] then
		for i = #d[item.own_key.."Knife"],1,-1 do 
			local v = d[item.own_key.."Knife"][i]
			if auxi.check_all_exists(v) then
				local dir = (v.Position - ent.Position):Normalized()
				v.Velocity = Vector(0,0)
				v.Rotation = dir:GetAngleDegrees()
				local q = auxi.fire_knife(v.Position - dir * 15,Vector(0,0),v.CollisionDamage,nil,{knife = v,player = player,cooldown = 60,Accerate = 1.5,})
				q.Parent.Velocity = dir * player.ShotSpeed * 20
				table.remove(d[item.own_key.."Knife"],i)
			end
		end
	end
	
	if d[item.own_key.."RScale"] and d[item.own_key.."RSize"] then 
		ent.Scale = d[item.own_key.."RScale"] + math.max(0,(item.check_tear_offset(cnt,cnt).col - 1) * 10/d[item.own_key.."RSize"] - 1) * math.min(1,d[item.own_key.."RScale"])
		ent:SetSize(ent.Size,ent.SizeMulti,math.ceil(d[item.own_key.."RSize"]))
	end
	if enemy then
		local q = Isaac.Spawn(1000,2,0,ent.Position,Vector(0,0),nil):ToEffect()
		for i = 1,5 do
			if auxi.random_1() > 0.3 then local q = Isaac.Spawn(1000,5,0,ent.Position,auxi.random_r() * auxi.random_1() * 10 + ent.Velocity,nil):ToEffect() end
		end
	end
	local q = Isaac.Spawn(1000,17,1,ent.Position,Vector(0,0),nil):ToEffect()
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEAT_JUMPS,1,1,false,0,2)
	return ret
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	if ent.FrameCount == 1 then
		--print(ent.Velocity:GetAngleDegrees().." "..ent.Velocity:Length())
		--print(ent.Scale.." "..ent.Height)
		--print(ent.FallingSpeed.." "..ent.FallingAcceleration)
	end
	--if ent.FrameCount > 3 then if ent.GridCollisionClass == EntityGridCollisionClass.GRIDCOLL_NONE and not (ent.TearFlags & BitSet128(1<<38,0) == BitSet128(1<<38,0)) then ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS end end
	local d = ent:GetData()
	local player = CharacterAttackCompat.resolve_entity_player(ent, auxi.check_spawner_player(ent))
	if not player then return end
	if d[item.own_key.."effect"] then
		if d[item.own_key.."effect"].Delay then d[item.own_key.."effect"].Delay = d[item.own_key.."effect"].Delay - 1 end
		d[item.own_key.."effect"].Dis = (d[item.own_key.."effect"].Dis or 0) + ent.Velocity:Length()
		if (auxi.is_all_clear() and ent.Velocity:Length() < 2) or ent:IsDead() then 
			local succ = item.break_anna_tear(ent,nil,"Trail") or {}
			if succ.NoSplit then ent:Kill()	end
		end
		if ent:CollidesWithGrid() then item.break_anna_tear(ent) end
		d[item.own_key.."effect"].Counter = (d[item.own_key.."effect"].Counter or 0) + 1
	end	
	if d[item.own_key.."effect2"] then
		local tg = d[item.own_key.."effect2"].tg
		if auxi.check_all_exists(tg) then
			--local cnt = (tg:GetData()[item.own_key.."effect"] or {}).Counter or 0
			--local dir = tg.Position + auxi.MakeVector(cnt * d[item.own_key.."effect2"].RotateRnd + d[item.own_key.."effect2"].row) * d[item.own_key.."effect2"].col - ent.Position
			--ent.Velocity = ent.Velocity * 0 + dir:Normalized() * math.min(40,dir:Length() * 0.8) * 1
		end
	end
	for u,v in pairs(d[item.own_key.."Link_Tech"] or {}) do 
		if auxi.check_all_exists(v) then
			v.Position = ent.Position
			v.PositionOffset = ent.PositionOffset
			local d2 = v:GetData()
			if auxi.check_all_exists(d2[item.own_key.."Linker"]) then
				local dir = v.Position - d2[item.own_key.."Linker"].Position
				v.Angle = dir:GetAngleDegrees() + (d2[item.own_key.."Dir"] or 0)
				v.MaxDistance = auxi.check_if_any(d2[item.own_key.."Dis"],ent,dir) or v.MaxDistance
			end
		end
	end
	for u,v in pairs(d[item.own_key.."Link_TechX"] or {}) do 
		if auxi.check_all_exists(v) then
			v.Position = ent.Position
			v.Velocity = ent.Velocity
			v.PositionOffset = ent.PositionOffset
		end
	end
	if d[item.own_key.."KnifeInfo"] then
		local ct = #(d[item.own_key.."Knife"] or {})
		d[item.own_key.."KnifeInfo"].Radius = (d[item.own_key.."KnifeInfo"].Radius or 0) + player.ShotSpeed * 10
		for i = #d[item.own_key.."Knife"],1,-1 do 
			local v = d[item.own_key.."Knife"][i]
			if auxi.check_all_exists(v) then
				v.PositionOffset = ent.PositionOffset
				v.Rotation = d[item.own_key.."KnifeInfo"].Radius + i/ct * 360
			else
				table.remove(d[item.own_key.."Knife"],i)
			end
		end
	end
	
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then 
		if col:GetData()[item.own_key.."marked"] and auxi.check_for_the_same(ent,col:GetData()[item.own_key.."marked"]) then return true end
		item.break_anna_tear(ent,col) 
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Anna_Portal,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local room = Game():GetRoom()
	local player = d[item.own_key.."Player"] or auxi.check_spawner_player(ent)
	if auxi.check_all_exists(player) ~= true then ent:Remove() return end
	d[item.own_key.."Player"] = d[item.own_key.."Player"] or player
	local d2 = player:GetData()
	local gdir = d2[item.own_key.."Dir"]
	local dirscale = 1
	d[item.own_key.."Dir"] = gdir
	if gdir:Length() > 0.05 then d[item.own_key.."dir"] = gdir end
	d[item.own_key.."Scaler"] = d[item.own_key.."Scaler"] or 0.0001
	local scaler = 1
	if d[item.own_key.."Size_Scaler"] then
		local cnt = d[item.own_key.."Size_Scaler"].counter or 0
		d[item.own_key.."Size_Scaler"].rrate = (d[item.own_key.."Size_Scaler"].rrate or 1) * 0.4
		local info = auxi.check_lerp(cnt,item.size_launcher)
		dirscale = dirscale + info.offsetscale * ((d[item.own_key.."Size_Scaler"].scale or 1) - 1) * 0.3
		d[item.own_key.."Size_Scaler"].rscaler = (1 * (1 - info.rate) + (d[item.own_key.."Size_Scaler"].scale or 1) * info.rate) * (1 - d[item.own_key.."Size_Scaler"].rrate) + d[item.own_key.."Size_Scaler"].rrate * d[item.own_key.."Size_Scaler"].delta
		scaler = scaler * d[item.own_key.."Size_Scaler"].rscaler
		if cnt > item.size_launcher.Limit then d[item.own_key.."Size_Scaler"] = nil 
		else d[item.own_key.."Size_Scaler"].counter = cnt + 1 end
	end
	if d[item.own_key.."Push"] then 
		if gdir:Length() < 0.05 then gdir = d[item.own_key.."dir"] or gdir end
		local cnt = d[item.own_key.."Push"].counter or 0
		local info = auxi.check_lerp(cnt,item.push_scaler)
		dirscale = dirscale * info.offsetscale
		d[item.own_key.."Scaler"] = d[item.own_key.."Scaler"] * 0.5 + 1 * 0.5
		if cnt > item.push_scaler.Limit then d[item.own_key.."Push"] = nil 
		else d[item.own_key.."Push"].counter = cnt + 1 end
	elseif gdir:Length() < 0.05 then 
		d[item.own_key.."Scaler"] = d[item.own_key.."Scaler"] * 0.5
	else d[item.own_key.."Scaler"] = d[item.own_key.."Scaler"] * 0.5 + 1 * 0.5 end
	s.Scale = scaler * d[item.own_key.."Scaler"] * auxi.mul_t(item.get_anna_size(player),Vector(math.abs(gdir.Y) * 0.6 + 0.4,1 + math.abs(gdir.X) * 0.4))
	local col = item.get_anna_color(player,0)
	d[item.own_key.."Record_Color"] = auxi.AddColor(d[item.own_key.."Record_Color"] or Color(1,0,0,1),auxi.AddColor(col,Color(1,1,1,0),1,0.2),0.8,0.2)
	s.Color = d[item.own_key.."Record_Color"]
	
	local ctrlid = player.ControllerIndex
	if auxi.has_have_coll(player,329) and not (Input.IsActionTriggered(11,ctrlid) or Input.IsActionPressed(11,ctrlid)) then 
		if d[item.own_key.."Scaler"] < 0.05 then
			d[item.own_key.."Position"] = nil
		else
			d[item.own_key.."Position"] = (d[item.own_key.."Position"] or player.Position) + gdir * player.ShotSpeed * 7.5
		end
	else
		if d[item.own_key.."Position"] then 
			d[item.own_key.."Position"] = d[item.own_key.."Position"] * 0.5 + player.Position * 0.5
			if (d[item.own_key.."Position"] - player.Position):Length() < 20 then d[item.own_key.."Position"] = nil end
		end
	end
	local tg_pos = (d[item.own_key.."Position"] or player.Position) + gdir * (player.ShotSpeed * 4 + 25 * dirscale) + (d2[item.own_key.."Velocity"] or player.Velocity) * 5 + Vector(gdir.X,0) * player.SpriteScale:Length()
	local dir = tg_pos - ent.Position
	ent.Velocity = dir:Normalized() * math.min(20,dir:Length() * 0.4)
	
	local range = 10 --* d[item.own_key.."Scaler"]
	local centpos = ent.Position + ent.PositionOffset
	
	d[item.own_key.."Catch_pool"] = d[item.own_key.."Catch_pool"] or {}
	for u,v in pairs(d[item.own_key.."Catch_pool"]) do
		if auxi.check_exists(v.ent) then
			local ve = v.ent
			local s3 = ve:GetSprite()
			local d3 = ve:GetData()
			if d3[item.own_key.."Catch"] == nil then
				d3[item.own_key.."Catch"] = {}
				local tdir = auxi.mul_t(ve.Position - centpos,auxi.rev_s(s.Scale * 0.9 + Vector(1,1) * 0.1))
				d3[item.own_key.."Catch"]["InitAngle"] = tdir:GetAngleDegrees()
				d3[item.own_key.."Catch"]["InitLeg"] = tdir:Length()
				d3[item.own_key.."Catch"]["RecordScale"] = auxi.copyVec(s3.Scale)
				d3[item.own_key.."Catch"]["RecordPosoffset"] = auxi.copyVec(ve.PositionOffset)
				d3[item.own_key.."Catch"]["RecordRotate"] = ve.SpriteRotation
				if v.Virtual then		--!!
					
				end
			end
			d3[item.own_key.."Catch"]["counter"] = (d3[item.own_key.."Catch"]["counter"] or 0) + 1
			d3[item.own_key.."Catch"]["RotateCounter"] = (d3[item.own_key.."Catch"]["RotateCounter"] or 0) + math.min(1,d3[item.own_key.."Catch"]["counter"]/20)
			d3[item.own_key.."Catch"]["Scaler"] = (d3[item.own_key.."Catch"]["Scaler"] or 1) * 0.97
			d3[item.own_key.."Catch"]["rScale"] = (d3[item.own_key.."Catch"]["rScale"] or s3.Scale) * 0.95
			d3[item.own_key.."Catch"]["mScale"] = (d3[item.own_key.."Catch"]["mScale"] or d3[item.own_key.."Catch"]["rScale"]) * 0.5 + d[item.own_key.."Scaler"] * auxi.mul_t(d3[item.own_key.."Catch"]["rScale"],s.Scale:Normalized()) * 0.5
			ve.Velocity = ent.Velocity
			
			if gdir.Y < -0.1 then d3[item.own_key.."Catch"]["Back"] = true else d3[item.own_key.."Catch"]["Back"] = false end
			
			d3[item.own_key.."Catch"]["Posoffset"] = (d3[item.own_key.."Catch"]["Posoffset"] or ve.PositionOffset) * 0.5 + (auxi.check_if_any(item.Pos_offset[ve.Type],ve) or Vector(0,0)) * 0.5
			if d3[item.own_key.."Catch"]["InitLeg"] > 50 then d3[item.own_key.."Catch"]["InitLeg"] = d3[item.own_key.."Catch"]["InitLeg"] * 0.8 + 40 * 0.2 end
			local tgpos = centpos + auxi.mul_t(auxi.get_by_rotate(Vector(1,0),(d3[item.own_key.."Catch"]["InitAngle"] or 0) + d3[item.own_key.."Catch"]["RotateCounter"] * 15,(d3[item.own_key.."Catch"]["InitLeg"] or 1) * d3[item.own_key.."Catch"]["Scaler"]),s.Scale)
			ve.Position = ve.Position * 0.2 + tgpos * 0.8
			auxi.fix_position(ve)
			anna_portal_holder.update_over_it(ent,ve,nil)
			--if d3[item.own_key.."Catch"]["rScale"]:Length() < 0.03 then ve:Remove() end
		elseif v.ent and (v.ent:IsDead() or v.ent:Exists() == false) then time_free(v.ent) end
	end
	local charge = 0
	local boss = false
	for i = #d[item.own_key.."Catch_pool"],1,-1 do 
		local v = d[item.own_key.."Catch_pool"][i]
		if auxi.check_exists(v.ent) ~= true then table.remove(d[item.own_key.."Catch_pool"],i)
		else 
			-- 捕获后的类型/虚拟记录/首领倍率均不再变化，缓存静态 charge；
			-- 入场过渡比例仍逐帧计算。
			v[item.own_key.."cached_charge"] = v[item.own_key.."cached_charge"] or item.check_charge(v.ent,v)
			local val = v[item.own_key.."cached_charge"]
			if not v.Virtual then val = val * math.min(1,math.max(0,v.ent:GetData()[item.own_key.."Catch"]["counter"] - item.delayoffset)/30) end
			--print(v.ent.Type.." "..v.ent.Variant)
			charge = charge + val 
			if v.ent:IsBoss() then boss = true end
		end
	end
	--print("End")
	if boss then d2[item.own_key.."Catch_BossCharge"] = (d2[item.own_key.."Catch_BossCharge"] or 0) + 0.5
	else d2[item.own_key.."Catch_BossCharge"] = 0 end
	d[item.own_key.."Catch_Charge2"] = charge * 10 / item.Range2charge(player.TearRange)
	-- CACHE_SPEED 只在实际移速惩罚跨过 0.01 档时 dirty；Birthright 下惩罚恒为 0。
	local shotinfo = auxi.getshotinfo(player)
	local excess = math.max(0,
		(d[item.own_key.."Catch_Charge2"] / 100 - shotinfo.mx) * item.Range2charge(player.TearRange)
	)
	local speed_rate = auxi.has_have_coll(player, 619) and 0 or 0.02
	local speed_signature = math.floor(excess * speed_rate * 100 + 0.5)
	local pd = player:GetData()
	if pd[item.own_key.."portal_speed_signature"] ~= speed_signature then
		pd[item.own_key.."portal_speed_signature"] = speed_signature
		player:AddCacheFlags(CacheFlag.CACHE_SPEED)
		pd.should_evaluate_on_update_once = true
	end
	d[item.own_key.."Catch_pool2"] = d[item.own_key.."Catch_pool2"] or {}
	for u,v in pairs(d[item.own_key.."Catch_pool2"]) do
		if auxi.check_exists(v.ent) then
			local ve = v.ent
			local s3 = ve:GetSprite()
			local d3 = ve:GetData()
			v.counter = (v.counter or 0) + 1
			if d3[item.own_key.."Catch"] == nil then
				d3[item.own_key.."Catch"] = {}
				d3[item.own_key.."Catch"]["RecordScale"] = auxi.copyVec(s3.Scale)
				d3[item.own_key.."Catch"]["RecordPosoffset"] = auxi.copyVec(ve.PositionOffset)
				d3[item.own_key.."Catch"]["RecordRotate"] = ve.SpriteRotation
			end
			d3[item.own_key.."Catch"]["Rotate"] = ((d3[item.own_key.."Catch"]["Rotate"] or d3[item.own_key.."Catch"]["RecordRotate"] or ve.SpriteRotation) + (v["RotateRnd"] or 0)) % 360
			d3[item.own_key.."Catch"]["mScale"] = (d3[item.own_key.."Catch"]["mScale"] or d3[item.own_key.."Catch"]["RecordScale"] or Vector(1,1)) * 0.5 + (d3[item.own_key.."Catch"]["RecordScale"] or Vector(1,1)) * 0.5
			if auxi.check_exists(v.tear) then
				--d3[item.own_key.."Catch"]["Rotate"] = auxi.AddAngle(d3[item.own_key.."Catch"]["Rotate"] or d3[item.own_key.."Catch"]["RecordRotate"] or ve.SpriteRotation,v.tear.Velocity:GetAngleDegrees() + 90,0,1)
				d3[item.own_key.."Catch"]["Posoffset"] = v.tear.PositionOffset
			else
				--d3[item.own_key.."Catch"]["Rotate"] = auxi.AddAngle(d3[item.own_key.."Catch"]["Rotate"] or d3[item.own_key.."Catch"]["RecordRotate"] or ve.SpriteRotation,d3[item.own_key.."Catch"]["RecordRotate"] or ve.SpriteRotation,0,1)
				d3[item.own_key.."Catch"]["Posoffset"] = (d3[item.own_key.."Catch"]["Posoffset"] or d3[item.own_key.."Catch"]["RecordPosoffset"] or Vector(0,0)) * 0.5 + (d3[item.own_key.."Catch"]["RecordPosoffset"] or Vector(0,0)) * 0.5
			end
			if auxi.check_exists(v.tear) ~= true then
				d3[item.own_key.."marked"] = v.marked or v.tear
				time_free(ve)
				if d3[item.own_key.."Record"] then
					local record = d3[item.own_key.."Record"].Record
					local info = item.Special_info[record.Type or 0] or {}
					local ret = auxi.check_if_any(info.Release,record,ve,player,info,item) or {}
					if auxi.check_exists(ret.ent) then 
						local q = ret.ent
						q:GetData()[item.own_key.."HaveCatched"] = true
						if ret.CopySprite then auxi.copy_sprite(ve:GetSprite(),q:GetSprite()) end
						--auxi.table2sprite(d3[item.own_key.."Record"].Sprite,q:GetSprite())
						q:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
						auxi.illustrate_sprite(q,q:GetSprite())
						ent:SetSize(record.Size,auxi.ProtectVector(record.SizeMulti),record.Size)
					end
					d3[item.own_key.."Record"] = nil
					if ret.Kick then d3[item.own_key.."Kick"] = {counter = 0,Scale = auxi.copyVec(ve:GetSprite().Scale),Rotate = v.RotateRnd,startframe = auxi.random_1() * (6) + 2,dir = auxi.RoundVector(nil,1).X * 10,Color = auxi.AddColor(ve:GetSprite().Color,Color(0,0,0,0),1,0),}
					else ve:Remove() end
				else
					if v.Dmg then
						ve:TakeDamage(v.Dmg,0,EntityRef(player),0)
						v.Dmg = nil
					end
				end
				d3[item.own_key.."Catched"] = nil
				d3[item.own_key.."Catch"] = nil
				v.ent = nil
			else
				if auxi.check_exists(v.tear) then
					v.Velocity = v.tear.Velocity
					v.Posoffset = (v.Posoffset or Vector(0,0)) * 0.5 + (v.TgPos or Vector(0,0)) * 0.5
					v.Position = v.tear.Position
				else
					v.Velocity = (v.Velocity or Vector(0,0)) * 0.5 + (v.AddVelocity or Vector(0,0)) * 0.5
					v.Posoffset = (v.Posoffset or Vector(0,0)) * 0.5 + (v.TgPos or Vector(0,0)) * 0.5
					v.Position = v.Position + v.Velocity
				end
				ve.Velocity = v.Velocity
				ve.Position = (v.Position + v.Posoffset)
			end
		elseif v.ent and (v.ent:IsDead() or v.ent:Exists() == false) then time_free(v.ent) end
	end
	for i = #d[item.own_key.."Catch_pool2"],1,-1 do 
		local v = d[item.own_key.."Catch_pool2"][i]
		if auxi.check_exists(v.ent) ~= true then table.remove(d[item.own_key.."Catch_pool2"],i) end
	end
	
	if #(d[item.own_key.."Brimstone"] or {}) > 0 then
		for u,v in pairs(d[item.own_key.."Brimstone"]) do 
			if auxi.check_all_exists(v) then
				if d[item.own_key.."Scaler"] > 0.8 then
					local d4 = v:GetData()
					v.Angle = (d[item.own_key.."dir"] or Vector(1,0)):GetAngleDegrees() + (d4[item.own_key.."Dir"] or 0)
					v.PositionOffset = ent.PositionOffset
				else v:SetTimeout(1) d[item.own_key.."Brimstone"][u] = nil end
			end
		end
	end
	if auxi.has_have_coll(player,152) and d[item.own_key.."Scaler"] > 0.8 then
		if auxi.check_all_exists(d[item.own_key.."Tech2"]) then
			local q = d[item.own_key.."Tech2"]
			q.Position = ent.Position
			q.Velocity = ent.Velocity
			q.Angle = (d[item.own_key.."dir"] or Vector(1,0)):GetAngleDegrees()
			q.PositionOffset = ent.PositionOffset
		else
			local q = player:FireTechLaser(ent.Position,0,d[item.own_key.."dir"],true,false,nil,0.13)
			q.TearFlags = q.TearFlags & (~TearFlags.TEAR_WAIT)
			q.PositionOffset = ent.PositionOffset
			q.Parent = ent
			q:SetTimeout(-1)
			d[item.own_key.."Tech2"] = q
		end
	else
		if auxi.check_all_exists(d[item.own_key.."Tech2"]) then d[item.own_key.."Tech2"]:SetTimeout(1) d[item.own_key.."Tech2"] = nil end
	end
	if auxi.has_have_coll(player,244) and d[item.own_key.."Scaler"] > 0.8 then
		if ent.FrameCount % 5 == 3 and auxi.check_rand(player.Luck,30,10,5) then
			local q = player:FireTechLaser(ent.Position,0,d[item.own_key.."dir"] or Vector(1,0),true,false,nil,1)
			q.Position = ent.Position
			q.PositionOffset = ent.PositionOffset
			q.Parent = ent
			for u,v in pairs(item.buff_list) do 
				if math.random(1000) > 700 then
					q.TearFlags = q.TearFlags | v
				end
			end
		end
	end
	if d[item.own_key.."Scaler"] > 0.8 then
		local n_entity = Isaac.GetRoomEntities()
		for u,v in pairs(n_entity) do
			if auxi.check_if_any(item.ignore_ports[v.Type],v,item) ~= true then
				local d3 = v:GetData()
				local dis = ent.Position - v.Position
				local leg = dis:Length()
				local r1 = math.abs(auxi.do_t(s.Scale,auxi.ab_s(dis:Normalized())) * range)
				local r2 = math.abs(auxi.do_t(v.SizeMulti,auxi.ab_s(dis:Normalized())) * v.Size)
				if d3[item.own_key.."Catched"] ~= true and (v.EntityCollisionClass ~= EntityCollisionClass.ENTCOLL_NONE or v:HasEntityFlags(EntityFlag.FLAG_HELD)) and auxi.check_if_any(item.Special_check[ent.Type],ent,r1 + r2) ~= true then
					if leg < r1 + r2 then
						if v:IsBoss() then 
							d3[item.own_key.."taken"] = (d3[item.own_key.."taken"] or 0) + player.Damage
							d3[item.own_key.."take"] = 10
						end
						item.try_catch(player,ent,v)
					elseif #(d[item.own_key.."Rift_Sucker"] or {}) < 4 and leg < r1 + r2 + 70 then
						item.try_suck(player,ent,v)
					end
				end
			end
		end
		local gent = grid_entity.get_grid_entity(room:GetGridEntityFromPos(ent.Position))
		if gent then item.try_catch(player,ent,gent) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = enums.Entities.Anna_Partical,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."Kick"] then
		local s = ent:GetSprite()
		local cnt = (d[item.own_key.."Kick"].counter or 0)
		local frame = (d[item.own_key.."Kick"].startframe or 0)
		s.Rotation = s.Rotation + d[item.own_key.."Kick"].Rotate
		s.Offset = Vector((d[item.own_key.."Kick"].dir or 1) * cnt,0.2 * (cnt * cnt - 2 * frame * cnt))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = EffectVariant.BLACK_HOLE,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent)
	if player and player:GetPlayerType() == item.entity then
		local s = ent:GetSprite()
		local anim = s:GetAnimation()
		if anim == "Idle" then
			local range = 5
			local d2 = player:GetData()
			if auxi.check_all_exists(d2[item.own_key.."Port"]) ~= true then d2[item.own_key.."Port"] = item.generate_port(player) end
			local n_entity = Isaac.GetRoomEntities()
			for u,v in pairs(n_entity) do
				if auxi.check_if_any(item.ignore_ports[v.Type],v,item) ~= true then
					local d3 = v:GetData()
					local dis = ent.Position - v.Position
					local leg = dis:Length()
					local r1 = math.abs(auxi.do_t(s.Scale,auxi.ab_s(dis:Normalized())) * range)
					local r2 = math.abs(auxi.do_t(v.SizeMulti,auxi.ab_s(dis:Normalized())) * v.Size)
					if d3[item.own_key.."Catched"] ~= true and (v.EntityCollisionClass ~= EntityCollisionClass.ENTCOLL_NONE or v:HasEntityFlags(EntityFlag.FLAG_HELD)) and auxi.check_if_any(item.Special_check[ent.Type],ent,r1 + r2) ~= true then
						if leg < r1 + r2 then
							if v:IsBoss() then 
								d3[item.own_key.."taken"] = (d3[item.own_key.."taken"] or 0) + player.Damage * 0.2
								d3[item.own_key.."take"] = 10
							end
							local q = auxi.fire_nil(v.Position,auxi.RoundVector(nil,20),{cooldown = 120,})
							local d3 = q:GetData()
							d3.nil_mode = "anna_nileffect"
							d3[item.own_key.."Nileffect"] = {tg = d2[item.own_key.."Port"],}
							item.try_catch(player,d2[item.own_key.."Port"],v,{Position = d2[item.own_key.."Port"].Position,})
						end
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Anna_Partical,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."Kick"] then
		ent.Velocity = ent.Velocity * 0.5
		local s = ent:GetSprite()
		local cnt = (d[item.own_key.."Kick"].counter or 0)
		local info = auxi.check_lerp(cnt,item.Kick_info)
		s.Scale = auxi.mul_t(info.Scale,d[item.own_key.."Kick"].Scale)
		s.Color = auxi.MulColor(Color(1,1,1,info.Color,1,1,1),d[item.own_key.."Kick"].Color)
		if cnt > item.Kick_info.Limit then d[item.own_key.."Kick"] = nil ent:Remove() return
		else d[item.own_key.."Kick"].counter = cnt + 1 end
	end
end,
})
--[[
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, params = nil,
Function = function(_,tp,vr,st,gidx,seed)
	local room = Game():GetRoom()
	if auxi.have_player(item.entity) and tp == 6 and vr == 10 then 	--and auxi.get_acceptible_level() % 2 == 0 then		--and room:IsFirstVisit()		--room:GetType() == 14
		return {6,enums.Slots.Rift_beggar.Variant,0,}
	end
end,
})
--]]
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	if auxi.have_player(item.entity) and room:IsFirstVisit() then
		local succ = auxi.get_acceptible_level() % 2 == 0
		if not succ then for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			if player:GetPlayerType() == item.entity and auxi.has_have_coll(player,619) then succ = true break end
		end end
		if succ then 
			local q = Isaac.Spawn(6,enums.Slots.Rift_beggar.Variant,0,Game():GetRoom():FindFreePickupSpawnPosition(Game():GetRoom():GetGridPosition(32),10),Vector(0,0),nil)
			every_entity_holder.init_slot(q)
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_,ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if player and player:GetPlayerType() == item.entity then
		local d = player:GetData()
		d.damaged_sharp_rate = true
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CURSED_EYE) and not auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BLACK_CANDLE) then
			local cnt1 = (d[item.own_key.."charge"] or 0)
			local cnt2 = 0
			if d[item.own_key.."Port"] then cnt2 = (d[item.own_key.."Port"]:GetData()[item.own_key.."Catch_Charge2"] or 0) end
			if cnt1 > 2 and cnt1 + cnt2 < 100 * (auxi.getshotinfo(player).mx or 1) then
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

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	if player:GetPlayerType() == item.entity then
		local d = player:GetData()
		d[item.own_key.."List"] = auxi.get_Anna_list(player)
	end
end,
})

function item.reget_ent(ent)
	local d = ent:GetData()
	if d[item.own_key.."Catch"] and auxi.check_all_exists(d[item.own_key.."Catcher"]) ~= true and auxi.check_all_exists(d[item.own_key.."Catcherer"]) then
		local player = d[item.own_key.."Catcherer"]
		local d2 = player:GetData()
		if auxi.check_all_exists(d2[item.own_key.."Port"]) ~= true then d2[item.own_key.."Port"] = item.generate_port(player) end
		item.recatch(player,d2[item.own_key.."Port"],ent,{Position = d2[item.own_key.."Port"].Position,ent = ent,})
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item._room_epoch = (item._room_epoch or 0) + 1
end,
})

if EID then
	EID:addDescriptionModifier("qing_player_desc_sync_Anna", function(desc) local ret = auxi.have_player(item.entity) return ret end, function(desc)
        local id = desc.ObjType
        local vr = desc.ObjVariant
        local st = desc.ObjSubType
		if auxi.check_all_exists(desc.Entity) and desc.Entity.Type == 5 then
            local info = item.pickup2EID(desc.Entity.Type,desc.Entity.Variant,desc.Entity.SubType,{Price = desc.Entity:ToPickup().Price,})
            if info and info ~= "" then
				if string.sub(info,0,1) ~= "#" then info = "#"..info end
                local repl = "#{{Player"..item.entity.."}} "
                info = string.gsub(info, "#", repl)
                EID:appendToDescription(desc, info)
            end
        end
        return desc
	end)
end

Nil_holder.register("anna_nileffect", {
	detect = function(d) return d[item.own_key.."Nileffect"] end,
	update = function(ent, d, s, player)
		local tg = d[item.own_key.."Nileffect"].tg
		if auxi.check_all_exists(tg) ~= true then tg = CharacterAttackCompat.resolve_entity_player(ent, player) end
		if not tg then ent:Remove() return end
		local dir = tg.Position - ent.Position
		ent.Velocity = ent.Velocity * 0.5 + dir * (d[item.own_key.."Nileffect"].Speed or 0.2) * 0.5
		if dir:Length() < 10 then ent:Remove() end
		if auxi.check_all_exists(d[item.own_key.."tail"]) then
			d[item.own_key.."tail"].Position = ent.Position
			d[item.own_key.."tail"]:GetSprite().Color = auxi.AddColor(d[item.own_key.."tail"]:GetSprite().Color,Color(1,1,1,1,0,0,0),0.5,0.5)
		else
			local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL, 0, ent.Position, Vector(0,0), ent):ToEffect()
			local s2 = q:GetSprite()
			s2:Load("gfx/recolored_trail.anm2",true)
			s2:Play("Idle",true)
			s2.Color = Color(1,1,1,0,0,0,0)
			d[item.own_key.."tail"] = q
			q.MinRadius = 0.1
			q.MaxRadius = 0.1
			q.SpriteScale = Vector(1,1)
			q.Parent = ent
		end
	end,
	render = function(ent, d, s, player)
		if auxi.check_all_exists(d[item.own_key.."Nileffect"].Renderer) then
			d[item.own_key.."Nileffect"].Renderer:GetSprite():Render(Isaac.WorldToScreen(ent.Position + ent.PositionOffset),Vector(0,0),Vector(0,0))
		end
	end,
})

--- 宝宝复制只读当前捕获池；绝不移动、释放、删除实体，也不改存档 Record/Fired。
function item.get_familiar_ammo_snapshot(player)
	local out = {count = 0, average_mass = 1, average_damage = 0}
	if not player then return out end
	local port = player:GetData()[item.own_key.."Port"]
	if not auxi.check_all_exists(port) then return out end
	local pool = port:GetData()[item.own_key.."Catch_pool"] or {}
	local total_mass, total_damage = 0, 0
	for _, entry in pairs(pool) do
		local ent = entry and entry.ent
		if auxi.check_all_exists(ent) then
			local record_holder_data = ent:GetData()[item.own_key.."Record"]
			local record = record_holder_data and record_holder_data.Record
			local info, info_desc
			if record then
				info, info_desc = item.something2info(record.Type, record.Variant, record.SubType, {Price = record.Price})
			else
				info, info_desc = item.ent2info(ent)
			end
			info = type(info) == "table" and info or {}
			info_desc = type(info_desc) == "table" and info_desc or {}
			local adder = type(info_desc.Adder) == "table" and info_desc.Adder or {}
			local mass = tonumber(info.rate) or tonumber(adder.rate) or 1
			local damage = (tonumber(info.Dmg) or 0) + (tonumber(adder.Dmg) or 0)
			out.count = out.count + 1
			total_mass = total_mass + math.max(0.1, mass)
			total_damage = total_damage + damage
		end
	end
	if out.count > 0 then
		out.average_mass = total_mass / out.count
		out.average_damage = total_damage / out.count
	end
	return out
end

--- Gello / Incubus 等使用捕获池快照生成独立副本；不消耗真实弹药、不推进蓄力和存档。
function item.fire_familiar_attack(player, request)
	request = request or {}
	if not player then return {fired = false} end
	local origin = request.origin or (request.source and request.source.Position) or player.Position
	local aim = request.aim_dir or Vector(0, 1)
	if aim:Length() < 0.01 then aim = Vector(0, 1) else aim = aim:Normalized() end
	local damage_mul = tonumber(request.damage_mul) or 0.75
	local list = player:GetData()[item.own_key.."List"] or auxi.get_Anna_list(player)
	local volley = auxi.get_Anna_multishots(player, list, {charge = 1}) or {}
	if next(volley) == nil then volley = {{dir = 0}} end
	local snapshot = item.get_familiar_ammo_snapshot(player)
	local tear_params = player:GetTearHitParams(WeaponType.WEAPON_TEARS, 1, 0)
	local CharacterFamiliars = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")
	local spawned = {}
	for _, shot in pairs(volley) do
		if not shot.Ignore then
			local direction = auxi.get_by_rotate(aim, shot.dir or 0)
			local speed = player.ShotSpeed * (10 + (shot.shotspeed or 0))
			local tear = item.fire_anna_tear(player, origin, direction * speed, {
				Sprite = true,
				SuppressAttackNotify = true,
			})
			tear.TearFlags = CharacterFamiliars.apply_familiar_tear_flags(
				player, (tear_params.TearFlags | (shot.tearflag or BitSet128(0, 0))) & (~TearFlags.TEAR_WAIT)
			)
			tear.CollisionDamage = math.max(0.1,
				(tear_params.TearDamage * (snapshot.average_mass * 0.4 + 0.5) + snapshot.average_damage) * damage_mul
			)
			if request.source then
				tear.Parent = request.source
				tear.SpawnerEntity = request.source
			end
			spawned[#spawned + 1] = tear
		end
	end
	return {fired = #spawned > 0, delay = player.MaxFireDelay, spawned = spawned}
end

CharacterAttackCompat.register(item.entity, {
	key = "anna",
	module = "Qing_Remaster_scripts.player.player_Anna",
	advanced_familiars = true,
	familiar_attack = item.fire_familiar_attack,
	capabilities = {projectile = true, volley = true, captured_ammo = true},
	audit = "familiar copies use a read-only averaged captured-ammo snapshot",
})

return item

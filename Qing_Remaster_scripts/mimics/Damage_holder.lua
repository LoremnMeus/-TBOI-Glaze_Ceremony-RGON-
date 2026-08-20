local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local Ice_holder = require("Qing_Remaster_scripts.mimics.Ice_holder")
local Horn_hand_holder = require("Qing_Remaster_scripts.mimics.Horn_hand_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Punch_holder = require("Qing_Remaster_scripts.mimics.Punch_holder")
local tear_trigger_holder = require("Qing_Remaster_scripts.callbacks.tear_trigger_holder")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Damage_holder_",
	info = {
		["Anna"] = {
			["Burst"] = true,
			["compound_fracture"] = true,
		},
	},
}

function item.damage_with(ent,col,params)
	params = params or {}
	local player = params.player or Game():GetPlayer(0)
	local tearflags = params.tearflags or BitSet128(0,0)
	local tearcolor = params.tearcolor or Color(1,1,1,1)
	local dmg = params.dmg or 3.5
	local luck = params.luck or 0
	if player:HasTrinket(139) then luck = luck + 3 end
	for u,v in pairs(item.info) do if params[u] then for uu,vv in pairs(v) do params[uu] = vv end end end
	--0：穿透，1：穿怪，2：跟踪
	if tearflags & BitSet128(1<<3,0) == BitSet128(1<<3,0) then		--蜘蛛之咬
		col:AddSlowing(EntityRef(ent),30 * 7,0.9,Color(0.85,0.85,0.85,1))
	end
	if tearflags & BitSet128(1<<4,0) == BitSet128(1<<4,0) then		--毒
		col:AddPoison(EntityRef(ent),30 * 10,dmg * 0.1)
	end
	if tearflags & BitSet128(1<<5,0) == BitSet128(1<<5,0) then		--石化
		col:AddFreeze(EntityRef(ent),30 * 5)
	end
	--6：分裂，7：煤块，8：回旋，9：大眼，10：虫
	if tearflags & BitSet128(1<<11,0) == BitSet128(1<<11,0) then		--小猫套
		if math.random(1000) > 700 then	ent:AddBlueFlies(math.random(2),ent.Position,ent) end
	end
	if player:HasPlayerForm(PlayerForm.PLAYERFORM_GUPPY) then 				--猫套
		ent:AddBlueFlies(1,ent.Position,ent)
	end
	--12：吐根
	if tearflags & BitSet128(1<<13,0) == BitSet128(1<<13,0) then		--魅惑
		col:AddCharmed(EntityRef(ent),30 * 5)
	end
	if tearflags & BitSet128(1<<14,0) == BitSet128(1<<14,0) then		--眩晕
		col:AddConfusion(EntityRef(ent),30 * 5,false)
	end
	--15：杀死掉红心，16：小星球，17：反重力，18：四分裂，19：弹弹弹
	if tearflags & BitSet128(1<<20,0) == BitSet128(1<<20,0) then		--恐惧
		col:AddFear(EntityRef(ent),30 * 5)
	end
	--21：突眼
	if tearflags & BitSet128(1<<22,0) == BitSet128(1<<22,0) then		--火之意志
		if auxi.check_rand(luck,50,25,5) then
			col:AddBurn(EntityRef(ent),30 * 5,dmg * 0.1)
			if params.Burst then
				Game():BombExplosionEffects(col.Position,dmg * 0.2,tearflags,Color(1,0.7,0.2,1,0.5,0.35,0.1),player,1,false,false)
				local q = Isaac.Spawn(1000,EffectVariant.RED_CANDLE_FLAME,0,col.Position,Vector(0,0),player):ToEffect()
				q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
				q.CollisionDamage = dmg * 0.2
			end
		end
	end
	--23：吸引敌人	--!!
	--24：稍微击退	--??
	--25,26,27:各种虫，28,29：炸弹，30：虫，31：神性
	if tearflags & BitSet128(1<<32,0) == BitSet128(1<<32,0) then		--沥青
		if auxi.check_rand(luck,100,30,5) == true then
			col:AddSlowing(EntityRef(ent),30 * 9,0.9,Color(0.15,0.15,0.15,1))
		end
	end
	if tearflags & BitSet128(1<<33,0) == BitSet128(1<<33,0) then		--神秘液体
		if auxi.check_rand(luck,100,30,10) == true then
			Isaac.Spawn(1000,53,0,col.Position,Vector(0,0),ent)
		end
	end
	--34：泪盾，35,36：炸弹
	--37：粘弹	--!!
	--38：连续统
	if tearflags & BitSet128(1<<39,0) == BitSet128(1<<39,0) then		--圣光 
		local q2 = Isaac.Spawn(1000,EffectVariant.CRACK_THE_SKY,0,col.Position,Vector(0,0),ent):ToEffect()
		q2.CollisionDamage = dmg * 1.5
	end
	--40：掉金币（笨笨），41：杀死掉黑心，42：口球
	if tearflags & BitSet128(1<<43,0) == BitSet128(1<<43,0) then		--缩小
		col:AddShrink(EntityRef(ent),30 * 10)
	end
	if tearflags & BitSet128(1<<44,0) == BitSet128(1<<44,0) then		--贪婪头
		if auxi.check_rand(luck,3,1,13) == true then
			local room = Game():GetRoom()
			Isaac.Spawn(5,20,0,room:FindFreePickupSpawnPosition(col.Position,10,true),Vector(0,0),nil)
		end
	end
	--45：炸弹，46：虫
	if tearflags & BitSet128(1<<47,0) == BitSet128(1<<47,0) then		--青光眼
		if not col:IsBoss() then col:AddEntityFlags(1<<9) end
	end
	--48：鼻涕		--!!
	if tearflags & BitSet128(1<<49,0) == BitSet128(1<<49,0) then 		--中猫套
		if math.random(1000) > 500 then
			ent:ThrowBlueSpider(ent.Position,ent.Position)
		else
			ent:AddBlueFlies(math.random(2),ent.Position,ent)
		end
		Isaac.Spawn(1000,44,0,ent.Position,Vector(0,0),ent)
	end
	--50：硫酸
	if tearflags & BitSet128(1<<51,0) == BitSet128(1<<51,0) and params.compound_fracture then		--骨裂
		local cnt = auxi.choose(1,2,3)
		for i = 1,cnt do
			local dir = auxi.random_r()
			local q = player:FireTear(col.Position,dir * 10 * player.ShotSpeed,true,true,true)
			q.TearFlags = BitSet128(0,0)
			q.CollisionDamage = dmg * 0.2
			q.Scale = q.Scale * 0.5
			q:ResetSpriteScale()
		end
	end
	--52：彼列眼
	if tearflags & BitSet128(1<<53,0) == BitSet128(1<<53,0) then		--点金
		col:AddMidasFreeze(EntityRef(ent),30 * 2)
	end
	--54：针？55：天梯
	if tearflags & BitSet128(1<<56,0) == BitSet128(1<<56,0) then 		--霍恩角
		Horn_hand_holder.fire_horn_hand(ent,col,{player = player,dmg = dmg * 0.5,})
	end
	--57：科技0，58：眼球，59：噬泪症，60：三圣颂，61：跳石，62：血泪，63：炸弹
	if tearflags & BitSet128(0,1<<(64-64)) == BitSet128(0,1<<(64-64)) then		--拳头
		Punch_holder.Add_Punch(ent,col,{vel = (col.Position - ent.Position):Normalized() * 20,})
	end
	if tearflags & BitSet128(0,1<<(65-64)) == BitSet128(0,1<<(65-64)) then		--冰
		if auxi.check_rand(luck,30,10,5) == true then
			col:AddSlowing(EntityRef(ent),30 * 8,0.95,Color(0.8,0.8,1,1,0.15,0.15,0.3))
		end
		Ice_holder.try_ice(col)
	end
	if tearflags & BitSet128(0,1<<(66-64)) == BitSet128(0,1<<(66-64)) then		--磁化
		if not col:HasEntityFlags(EntityFlag.FLAG_MAGNETIZED) then
			Attribute_holder.try_hold_and_rewind_attribute(col,"ENTITY_FLAG_FLAG_MAGNETIZED",true,30 * 15,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_MAGNETIZED))
			Attribute_holder.try_hold_and_rewind_attribute(col,"Color",Color(0.5,0.5,0.5,1),30 * 15,Attribute_holder.descriptors.color())		--重载不等号
		end
	end
	if tearflags & BitSet128(0,1<<(67-64)) == BitSet128(0,1<<(67-64)) then		--烂番茄
		if not col:HasEntityFlags(EntityFlag.FLAG_BAITED) then
			Attribute_holder.try_hold_and_rewind_attribute(col,"ENTITY_FLAG_FLAG_BAITED",true,30 * 30,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_BAITED))
			Attribute_holder.try_hold_and_rewind_attribute(col,"Color",Color(1,0.4,0.4,1,0.3,0,0),30 * 15,Attribute_holder.descriptors.color())		--重载不等号
		end
	end
	--68：魔眼，69：小星球+，70：地球，71：脑虫，72：血炸弹，73：点粪，
	--74：杀死掉钱		--!!
	--75：硫磺火炸弹
	if tearflags & BitSet128(0,1<<(76-64)) == BitSet128(0,1<<(76-64)) then		--黑洞眼
		local q = Isaac.Spawn(1000,EffectVariant.RIFT,0,col.Position,Vector(0,0),ent):ToEffect()
		q:SetTimeout(120)
	end
	--77：毛霉菌		--!!
	--78：鬼炸弹，79：杀死掉塔罗牌，80：杀死掉符文，81：随机传送敌人，82：减速，83：加速
	--104：墙间弹射，105：防止地形伤害，106：背刺，107-114：剖腹产	...
	if params.tear_trigger then tear_trigger_holder.trigger_tear(params.tear_trigger_tp or "_",ent,nil,player,nil) end
end

return item
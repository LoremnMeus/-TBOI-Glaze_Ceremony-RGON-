local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local slot_manager = require("Qing_Remaster_scripts.core.slot_manager")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local every_entity_holder = require("Qing_Remaster_scripts.callbacks.every_entity_holder")

local item = {
	myToCall = {},
	ToCall = {},
	entity = enums.Slots.Bard_beggar,
	own_key = "Slot_Bard_Beggar_",
	Talking_Pos_Offset = Vector(30,-50),
	Prizes = {
		{
			check = function(player,info) return player:HasGoldenBomb() end,
			replacer = "gfx/items/slots/item_to_pay_goldenbomb.png",
			weigh = 999,bonus = 4,
			work = function(player,info) player:RemoveGoldenBomb() end,
		},
		{
			check = function(player,info) return player:HasGoldenKey() end,
			replacer = "gfx/items/slots/item_to_pay_goldenkey.png",
			weigh = 999,bonus = 4,
			work = function(player,info) player:RemoveGoldenKey() end,
		},
		{
			check = function(player,info) if player:GetNumBombs() >= 10 then return true end end,
			replacer = "gfx/items/slots/item_to_pay_10bombs.png",
			weigh = function(player,info) return 10 * math.ceil(player:GetNumBombs()/20) end,
			bonus = function(player,info,rng) return rng:RandomInt(4) end,
			work = function(player,info) player:AddBombs(-10) end,
		},
		{
			check = function(player,info) if player:GetNumBombs() >= 1 then return true end end,
			replacer = "gfx/items/slots/item_to_pay_bomb.png",
			weigh = function(player,info) return 3 * math.ceil(player:GetNumBombs()/20) end,
			bonus = function(player,info,rng) return math.floor(rng:RandomInt(4)/3) end,
			work = function(player,info) player:AddBombs(-1) end,
		},
		{
			check = function(player,info) if player:GetNumKeys() >= 1 then return true end end,
			replacer = "gfx/items/slots/item_to_pay_key.png",
			weigh = function(player,info) return 2 * math.ceil(player:GetNumKeys()/20) end,
			bonus = function(player,info,rng) return math.floor(rng:RandomInt(4)/3) end,
			work = function(player,info) player:AddKeys(-1) end,
		},
		{
			check = function(player,info) if player:GetNumCoins() >= 1 then return true end end,
			replacer = "gfx/items/slots/item_to_pay_coin.png",
			weigh = function(player,info) return 1 * math.ceil(player:GetNumCoins()/20) end,
			bonus = function(player,info) return 0.1 end,
			work = function(player,info) player:AddCoins(-1) end,
		},
		{
			check = function(player,info) if player:GetNumCoins() >= 25 then return true end end,
			replacer = "gfx/items/slots/item_to_pay_25coin.png",
			weigh = function(player,info) return 10 * math.ceil(player:GetNumCoins()/20) end,
			bonus = function(player,info) return rng:RandomInt(4) end,
			work = function(player,info) player:AddCoins(-1) end,
		},
		{
			check = function(player,info) if player:GetHearts() + player:GetSoulHearts() + player:GetBoneHearts() >= 3 and player:GetHearts() >= 2 then return true end end,
			replacer = "gfx/items/slots/item_to_pay_heart.png",
			weigh = function(player,info) return 2 * math.ceil(player:GetHearts()/2) end,
			bonus = function(player,info) return 0.33 end,
			work = function(player,info) player:AddHearts(-2) player:TakeDamage(0,DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_FAKE,EntityRef(player),60) end,
		},
		{
			check = function(player,info) if player:GetHearts() + player:GetSoulHearts() + player:GetBoneHearts() >= 3 and player:GetSoulHearts() >= 2 and player:GetBlackHearts() == 0 then return true end end,
			replacer = "gfx/items/slots/item_to_pay_soulheart.png",
			weigh = function(player,info) return 5 * math.ceil(player:GetSoulHearts()/2) end,
			bonus = function(player,info) return 0.6 end,
			work = function(player,info) player:AddSoulHearts(-2) player:TakeDamage(0,DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_FAKE,EntityRef(player),60) end,
		},
		{
			check = function(player,info) if player:GetHearts() + player:GetSoulHearts() + player:GetBoneHearts() >= 3 and player:GetSoulHearts() >= 2 and player:GetBlackHearts() > 0 then return true end end,
			replacer = "gfx/items/slots/item_to_pay_blackheart.png",
			weigh = function(player,info) return 7 * math.ceil(player:GetSoulHearts()/2) end,
			bonus = function(player,info) return 1 end,
			work = function(player,info) local black_infos = auxi.split_bits(player:GetBlackHearts()) player:RemoveBlackHeart((black_infos[1] or 0) * 2) player:AddSoulHearts(-2) player:TakeDamage(0,DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_FAKE,EntityRef(player),60) end,
		},
		{
			check = function(player,info) if player:GetHearts() + player:GetSoulHearts() + player:GetBoneHearts() >= 3 and player:GetBoneHearts() >= 1 then return true end end,
			replacer = "gfx/items/slots/item_to_pay_boneheart.png",
			weigh = function(player,info) return 6 * math.ceil(player:GetBoneHearts()) end,
			bonus = function(player,info) return 1 end,
			work = function(player,info) player:AddBoneHearts(-1) player:TakeDamage(0,DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_FAKE,EntityRef(player),30) end,
		},
		{
			check = function(player,info) if player:GetEternalHearts() >= 1 then return true end end,
			replacer = "gfx/items/slots/item_to_pay_eternalheart.png",
			weigh = function(player,info) return 10 * math.ceil(player:GetBoneHearts()) end,
			bonus = function(player,info) return 1.5 end,
			work = function(player,info) player:AddEternalHearts(-1) player:TakeDamage(0,DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_FAKE,EntityRef(player),30) end,
		},
	},
	Tosay = {
		zh = {
			{
				"英雄来到了遍布恶龙的王国！",
				"拔下石中宝剑，战胜三百恶魔！",
				"成为天命的主人！",
				"那么今天的故事就讲到这里~",
			},
			{
				"于是 达拉崩吧斑得贝迪卜多比鲁翁~",
				"砍向 昆图库塔卡提考特苏瓦西拉松~",
				"然后 昆图库塔卡提考特苏瓦西拉松~",
				"咬了 达拉崩吧斑得贝迪卜多比鲁翁~",
			},
			{
				"最后 达拉崩吧斑得贝迪卜多比鲁翁~",
				"他战胜了 昆图库塔卡提考特苏瓦西拉松~",
				"救出了 公主米娅莫拉苏娜丹妮谢莉红~",
				"回到了 蒙达鲁克硫斯伯古比奇巴勒城~",
			},
			{
				"发动~暴走魔法阵~~",
				"通常召唤阿莱斯特~",
				"效果检索召唤魔术~",
			},
			{
				"不要为了破碎的镜子悲伤！",
				"它们注定活在另一个世界~",
			},
			{
				"镜子的那一边有什么？",
				"是那五色的琉璃，虚幻的象征！",
				"美丽，而又不切实际~",
				"破裂的风暴中，只有覆盖在上面的油膜才是真实的存在~",
			},
			{
				"如果镜子的命运就是破碎",
				"那么我希望它爆裂得五彩斑斓~",
				"经过彩色火焰的烘焙",
				"琉璃将变得无坚不摧~",
			},
			{
				"硬币也不是坚不可摧",
				"贪婪的意志足以将其磨灭~",
				"但其中蕴含的价值依然存在",
				"哼！没有人能战胜它们！其名为资本主义！",
			},
			{
				"名为资本的恶魔正在摧毁大地",
				"藏匿于表面是银行的恐怖骗局~",
				"任何人倘若敢于狠心销毁账号",
				"他能收获到的只有破碎的人格~",
			},
			{
				"听说那遥远的危险矿洞",
				"有位少女在那里守护~",
				"如果想要拿到胜利的钥匙",
				"就千万不要踩上棋盘的边缘~",
			},
			{
				"王后手持宝剑威临四方",
				"主教事事妙算先机独占~",
				"战车不惧危难拼死冲锋",
				"骑士步伐坚定实力高卓~",
				"就算是临时招募的小卒",
				"也足以困得你焦头烂额~",
			},
			{
				"没有人能够永恒，除非他由石头做成",
				"但伟大的魔像也有它的惧怕之物~",
				"用黎明的智慧照耀那道阴暗",
				"正是精诚所至金石为开~",
			},
			{
				"血肉的天国向上苍张开双翼",
				"铺满白骨的地面，密布触手的天穹~",
				"没人能逃过血肉的魔爪",
				"没错，他的名字是德西·莱诺阿~",
			},
			{
				"当流星正面朝你飞来",
				"莫要逃避，转身正面迎击。",
				"小行星带总是有所预示",
				"譬如这次，仿佛天国即将降临~",
			},
			{
				"炼金术的最终奥义",
				"名为不可触摸之结界",
				"在那视线之外的帝国",
				"连声音也无法传达",
			},
			{
				"味觉理所当然彻底失灵",
				"嗅觉宛如夜空中的阵风",
				"听觉消失无影无踪",
				"心灵仿佛沉寂在无空的世界",
			},
			{
				"苍白的视界无限地延展",
				"苍白的呼啸剧烈地颤抖~",
				"不可闻，所知者天下万物",
				"不可视，所在者诸世众生~",
			},
			{
				"不可视之界限悬浮在第十三层以外",
				"欲到达此地，唯有得到主人首肯~",
				"或是找寻名为噩梦的呢祝师",
				"从噩梦里寻觅踪影~",
			},
			{
				"白色的风暴向外延展",
				"突破世界的藩篱~",
				"激发愤怒的火焰",
				"点燃生命的怒吼~",
				"这样的狂风该如何来阻止？",
			},
			{
				"啊啊啊，那就是嗝屁猫警长！",
				"森林公民向您致敬！",
				"向您致敬！！",
				"致敬！！！！",
			},
			{
				"地下室里的道具总是在增加？",
				"那再正常不过了~",
			},
			{
				"嗨，Judas！",
				"莫要哭泣~",
				"找一首哀伤的歌!",
				"然后把它唱得更快乐~",
			},
			{
				"爱你孤身走暗巷",
				"爱你不跪的模样~",
				"爱你对峙过绝望",
				"不肯哭一场~",
			},
			{
				"是谁带来~远古的呼唤~",
				"是谁留下~千年的期盼~",
				"难道说还有无言的歌~",
				"还是那久久不能忘怀的眷恋~",
			},
			{
				"我用尽一生一世来将你供养",
				"只期盼你停住流转的目光~",
				"请赐予我无限爱与被爱的力量",
				"让我能安心在菩提下静静的观想~",
			},
			Special_words = {
				[1] = {
					"孩子，初次见面",
					"在下是一名吟游诗人，正在这无人打扰之地寻找灵感~",
					"什么？你说你见过我？",
					"也许你说的是我的远房亲戚",
					"他们的连锁服务已经开到全球各地了~",
					"如果愿意付一点小费的话，我就来为你献唱一曲。",
					"当然，不愿意的话，我也不会强求的。",
				},
				[2] = {
					"又见面了，孩子。",
					"想要我为你献上一曲么？",
				},
			},
			Special_items = {
				[4] = {
					"哦，如此可爱的小猫咪！",
					"我会好好善待它的。",
				},
				[38] = {
					"哦，如此可爱的小猫咪！",
					"我会好好善待它的。",
				},
				[62] = {
					"吸血鬼并不惧怕阳光",
					"石质面具之后是对鲜血的渴望~",
					"但在慵懒的冬日早晨",
					"红色的番茄汁也能果腹!",
				},
				[81] = {
					"哦，如此可爱的小猫咪！",
					"我会好好善待它的。",
				},
				[118] = {
					"硫磺是如此的不幸",
					"染上了恶魔的颜色~",
					"净化的力量也不能触及",
					"从血脉中染红的死亡因子",
				},
				[144] = {
					"啊，这是我的一个远房亲戚！",
					"看起来他并不是很喜欢你富有的样子。",
				},
				[145] = {
					"哦，如此可爱的小猫咪！",
					"我会好好善待它的。",
				},
				[229] = {
					"咆哮在肺脏中爆炸",
					"血管如同脆化的橡胶",
					"绵软的手臂，苍白的面颊~",
					"无力地看着血液迸发",
					"————你我共同的命运",
				},
				[242] = {
					"鬼面象征着内心的耻辱",
					"但很少有人愿意戴上",
					"悲哀，痛苦亦或是绝望",
					"噩梦，你的名字是无名~",
				},
				[278] = {
					"啊，这是我另一个远房亲戚！",
					"我还以为我们早已阴阳两隔了呢！",
				},
				[281] = {
					"嘿！",
					"不要一直把宝宝塞给我！",
					"照顾他们很费时间！",
				},
				[293] = {
					"哦，如此可爱的小猫咪！",
					"我会好好善待它的。",
					"恶魔？差不了多少的。",
				},
				[304] = {
					"我想你很乐意我拿走它，对吧？",
				},
				[385] = {
					"哇塞，我远房亲戚的老大居然成了你的下属！",
					"你可真是有魄力的孩子！",
				},
				[388] = {
					"哦，你找到了我的远房亲戚！",
					"他在我们的商业圈中总是处于关键地位。",
				},
				[395] = {
					"谢谢你。",
					"我可以买一份新的平板了。",
				},
				[441] = {
					"哦，如此可爱的小猫咪！",
					"我会好好善待它的。",
					"恶魔？差不了多少的。",
				},
				[452] = {
					"咆哮在肺脏中爆炸",
					"血管如同脆化的橡胶",
					"绵软的手臂，苍白的面颊~",
					"无力地看着血液迸发",
					"————你我共同的命运",
				},
				[614] = {
					"咆哮在肺脏中爆炸",
					"血管如同脆化的橡胶",
					"绵软的手臂，苍白的面颊~",
					"无力地看着血液迸发",
					"————你我共同的命运",
				},
				[618] = {
					"吸血鬼并不惧怕阳光",
					"石质面具之后是对鲜血的渴望~",
					"但在慵懒的冬日早晨",
					"红色的番茄汁也能果腹!",
				},
				[628] = {
					"......",
					"(优美而无奈的琴声)",
				},
				[633] = {
					"这件物品不属于你我~",
					"或许存在即为合理。",
				},
				[641] = {
					"咆哮在肺脏中爆炸",
					"血管如同脆化的橡胶",
					"绵软的手臂，苍白的面颊~",
					"无力地看着血液迸发",
					"————你我共同的命运",
				},
				[657] = {
					"咆哮在肺脏中爆炸",
					"血管如同脆化的橡胶",
					"绵软的手臂，苍白的面颊~",
					"无力地看着血液迸发",
					"————你我共同的命运",
				},
				[724] = {
					"咆哮在肺脏中爆炸",
					"血管如同脆化的橡胶",
					"绵软的手臂，苍白的面颊~",
					"无力地看着血液迸发",
					"————你我共同的命运",
				},
			},
		},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_INIT, params = item.entity.Variant,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ then
	else
		consistance_holder.try_hold_over_entity(ent,item.own_key)
		consistance_holder.try_hold_entity(ent,item.own_key)
	end
	if d._Data[item.own_key]["State"] then
		s:Play("Idle",true)
	else
		s:Play("Idle0",true)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_UPDATE, params = item.entity.Variant,
Function = function(_,ent)
	local room = Game():GetRoom()
	local s = ent:GetSprite()
	local d = ent:GetData()
	local rng = ent:GetDropRNG()
	if d.tosay == nil or #d.tosay == 0 then	d.should_prize = false end
	if s:IsPlaying("Idle") then
		if d.should_prize then s:Play("Prize",true) end
	end
	if s:IsPlaying("Prize") then
		if s:IsEventTriggered("Sing") then
			if d.tosay and d.tosay[1] then
				gui.draw_ch_with_time_to_dispair(ent.Position + item.Talking_Pos_Offset + Vector(-(#d.tosay[1])/2,0),Vector(0,-50),d.tosay[1],60)
				table.remove(d.tosay,1)
				if #d.tosay == 0 then	
					consistance_holder.try_hold_over_entity(ent,item.own_key)
					if (d._Data[item.own_key]["Counter"] or 0) >= 7 then 
						d._Data[item.own_key]["Counter"] = -1000
						local q = Isaac.Spawn(5,100,CollectibleType.COLLECTIBLE_MYSTERY_GIFT,room:FindFreePickupSpawnPosition(ent.Position,10,true),Vector(0,0),nil):ToPickup() 
						Game():GetPlayer(0):AnimateHappy()
					end
					consistance_holder.try_hold_entity(ent,item.own_key)
				end
			end
		end
	end
	
	if s:IsFinished("Teleport") then ent:Remove() return end
	if s:IsFinished("Prize") then s:Play("Idle",true) end
	if s:IsFinished("PayPrize") then s:Play("Prize",true) end
	if s:IsFinished("Appearing") then
		local language = Options.Language
		if item.Tosay[language] == nil then language = "zh"	end
		local to_say = item.Tosay[language].Special_words[1]
		if (save.elses.times_meet_beggar or 0) ~= 0 then to_say = item.Tosay[language].Special_words[2] end
		d.tosay = d.tosay or {}
		for j = 1,#to_say do table.insert(d.tosay,to_say[j]) end
		d.should_prize = true
		s:Play("Prize",true)
		save.elses.times_meet_beggar = (save.elses.times_meet_beggar or 0) + 1
		
		consistance_holder.try_hold_over_entity(ent,item.own_key)
		d._Data[item.own_key]["State"] = true
		consistance_holder.try_hold_entity(ent,item.own_key)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_KILL, params = item.entity.Variant,
Function = function(_,ent,killer)
	local s = ent:GetSprite()
	local level = Game():GetLevel()
	s:Play("Teleport",true)
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	level:SetStateFlag(LevelStateFlag.STATE_BUM_KILLED,true)
end,
})

local function addtosay(ent,num,rng)
	rng = auxi.rng_for_sake(rng)
	num = num or 1
	local d = ent:GetData()
	d.tosay = d.tosay or {}
	local language = Options.Language
	if item.Tosay[language] == nil then	language = "zh" end
	for i = 1,num do
		local rnd = rng:RandomInt(#item.Tosay[language]) + 1
		for j = 1,#item.Tosay[language][rnd] do
			table.insert(d.tosay,item.Tosay[language][rnd][j])
		end
	end
end

local function try_prize(player,rng,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local tbl = {}
	for u,v in pairs(item.Prizes) do
		local succ = v.check(player,v)
		if succ then table.insert(tbl,#tbl+1,{weigh = auxi.check_if_any(v.weigh,player,v) or 0,info = v,}) end
	end
	local rnd = auxi.random_in_weighed_table(tbl,rng)
	if rnd then
		local v = rnd.info
		s:ReplaceSpritesheet(2,v.replacer) s:LoadGraphics()
		local cnt = auxi.check_to_number(auxi.check_if_any(v.bonus,player,v,rng))
		for i = 1,cnt do addtosay(ent,1,rng) end
		v.work(player,v)
		consistance_holder.try_hold_over_entity(ent,item.own_key)
		d._Data[item.own_key]["Counter"] = (d._Data[item.own_key]["Counter"] or 0) + cnt
		consistance_holder.try_hold_entity(ent,item.own_key)
		return true
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_COLLISION, params = item.entity.Variant,
Function = function(_,ent,player,low)
	local s = ent:GetSprite()
	local d = ent:GetData()
	if s:IsPlaying("Idle") and d.should_prize ~= true then
		local succ = try_prize(player,ent:GetDropRNG(),ent)
		if succ then
			s:Play("PayPrize",true)
			d.should_prize = true
		end
	end
	if s:IsPlaying("Idle0") then s:Play("Appearing",true) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	local stage = Game():GetLevel():GetStage()
	local seed = Game():GetSeeds():GetStageSeed(stage)
	if room:GetType() == RoomType.ROOM_SECRET_EXIT and room:IsFirstVisit() then
		local rng = RNG()
		rng:SetSeed(seed,0)
		local rnd = rng:RandomInt(100)
		if rnd > 50 then
			local q = Isaac.Spawn(item.entity.Type,item.entity.Variant,0,room:FindFreeTilePosition(room:GetRandomPosition(10),10),Vector(0,0),nil)
			every_entity_holder.init_slot(q)
		end
	end
end,
})

return item
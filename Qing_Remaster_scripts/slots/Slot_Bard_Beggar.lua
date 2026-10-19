local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local slot_manager = require("Qing_Remaster_scripts.core.slot_manager")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local every_entity_holder = require("Qing_Remaster_scripts.callbacks.every_entity_holder")
local slot_offer_lift = require("Qing_Remaster_scripts.slots.slot_offer_lift")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")

local item = {
	myToCall = {},
	post_myToCall = {},
	ToCall = {},
	entity = enums.Slots.Bard_beggar,
	own_key = "Slot_Bard_Beggar_",
	Talking_Pos_Offset = Vector(30,-50),
	Dialogue = {
		zh = {
			intro = {
				"啊，一位新的听众。",
				"我不收门票，只收一点能写进歌里的东西。",
				"硬币、钥匙、炸弹，或者一点生命——都能谱成曲子。",
				"今天付给我的，明天会唱回来。",
			},
			repeat_meet = {
				"又见面了。",
				"这一层，想把什么写进下一首歌？",
			},
			offers = {
				coin = {
					first = {
						"五枚金币，正好够写一个副歌。",
						"下一层，店里的硬币价会跟着旋律低两拍。",
					},
					repeat_say = {
						"副歌已经写好了，下一层的正价商品都会便宜些。",
					},
				},
				key = {
					first = {
						"一把钥匙，却不是用来开眼前的门。",
						"下一层的路，我替你先看一眼。",
					},
					repeat_say = {
						"前路仍在歌里，下一层记得听。",
					},
				},
				bomb = {
					first = {
						"一枚炸弹，换一层战歌。",
						"下一层，每个房间的第一声挽歌都会炸响。",
					},
					repeat_say = {
						"战歌还在，每间房的首个敌人会为它落下重音。",
					},
				},
				heart = {
					first = {
						"生命最适合写成安静的曲子。",
						"这一颗心我先替你收下。",
						"下一层，新生的红心偶尔会唱成魂心。",
					},
					repeat_say = {
						"安魂曲还在，留意那些刚生成的红心。",
					},
				},
			},
			bless_hud = {
				coin = {"富饶之歌", "金币虽轻，却能换来更多。"},
				key = {"旅途之歌", "通往宝藏的路，已为你敞开。"},
				bomb = {"战歌", "第一位倒下的敌人，将为战歌奏响重音。"},
				heart = {"安魂曲", "鲜红的心，也会偶尔泛起灵魂的蓝。"},
			},
			idle = {
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
			}
			},
			special_items = {
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
		en = {
			intro = {
				"Ah, a new listener.",
				"No cover charge—just something I can write into a song.",
				"Coins, keys, bombs, or a little life—all make fine ink.",
				"Pay me today, and I'll sing it back tomorrow.",
			},
			repeat_meet = {
				"We meet again.",
				"What shall we leave for the next floor's song?",
			},
			offers = {
				coin = {
					first = {
						"Five coins—just enough for a chorus.",
						"Next floor, every positive coin price drops by two beats.",
					},
					repeat_say = {
						"The chorus is written—positive shop prices will be lower next floor.",
					},
				},
				key = {
					first = {
						"A key—not for the door in front of you.",
						"I'll read the next floor's road ahead for you.",
					},
					repeat_say = {
						"The road is still in the song—listen on the next floor.",
					},
				},
				bomb = {
					first = {
						"One bomb for a floor-long war song.",
						"Next floor, the first death in every room will strike an explosive note.",
					},
					repeat_say = {
						"The war song remains—the first enemy in each room carries its refrain.",
					},
				},
				heart = {
					first = {
						"Life writes the quietest melodies.",
						"I'll hold this heart for you.",
						"Next floor, newborn red hearts may sing themselves into soul hearts.",
					},
					repeat_say = {
						"The requiem still waits—watch the red hearts that appear.",
					},
				},
			},
			bless_hud = {
				coin = {"Song of Plenty", "Light coins, yet they buy you more."},
				key = {"Song of the Road", "The road to treasure stands open."},
				bomb = {"War Song", "The first to fall strikes the war song's beat."},
				heart = {"Requiem", "A red heart may take on a soul's blue."},
			},
			idle = {
				{"Hero, dragon, kingdom—the usual tale ends here~"},
				{"Don't mourn a broken mirror—they live in another world~"},
				{"Hey, Judas! Don't cry—find a sad song and sing it happier~"},
			},
			special_items = {
				[4] = {"Oh, what a lovely little cat!", "I'll take good care of it."},
				[144] = {"Ah, a distant cousin of mine!", "He doesn't seem to like how rich you look."},
				[278] = {"Ah, another cousin!", "I thought we'd parted ways long ago!"},
				[628] = {"......", "(elegant, helpless piano)"},
			},
		},
	},
}
local try_greet, utter_next

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
	d._Data = d._Data or {}
	d._Data[item.own_key] = d._Data[item.own_key] or {}
	-- Accepted 只表示交易已经完成。回房后直接接现有离场，不重播支付和献唱。
	if d._Data[item.own_key].Accepted == true then
		s:Play("Teleport", true)
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	else
		s:Play("Idle", true)
	end
	d._Data[item.own_key]["State"] = true
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_UPDATE, params = item.entity.Variant,
Function = function(_,ent)
	local room = Game():GetRoom()
	local s = ent:GetSprite()
	local d = ent:GetData()
	local rng = ent:GetDropRNG()
	local anim = s:GetAnimation()
	if anim == "Idle0" or anim == "Appearing" then
		s:Play("Idle",true)
	end
	if d._say_cd and d._say_cd > 0 then
		d._say_cd = d._say_cd - 1
	end
	-- 进房后自顾自开场，不依赖交易或举物会话。
	try_greet(ent)
	if d.tosay == nil or #d.tosay == 0 then d.should_prize = false end
	if s:IsPlaying("Idle") then
		utter_next(ent)
		if d.should_prize then s:Play("Prize",true) end
	end
	if s:IsPlaying("Prize") then
		if s:IsEventTriggered("Sing") then
			d._say_cd = 0
		end
		utter_next(ent)
	end

	if s:IsFinished("Teleport") then ent:Remove() return end
	if s:IsFinished("Prize") then
		if d._Data and d._Data[item.own_key] and d._Data[item.own_key].Accepted then
			-- 献唱台词说完再离开；多句时循环 Prize。
			if (d.tosay and #d.tosay > 0) or (d._say_cd or 0) > 0 then
				s:Play("Prize",true)
				return
			end
			s:Play("Teleport",true)
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			return
		end
		s:Play("Idle",true)
	end
	if s:IsFinished("PayPrize") then s:Play("Prize",true) end
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

local function dialogue_lang()
	local language = Options.Language
	if item.Dialogue[language] == nil then language = "zh" end
	return language
end

local function queue_dialogue(ent, lines)
	if not lines or #lines == 0 then return end
	local d = ent:GetData()
	d.tosay = d.tosay or {}
	for i = 1, #lines do
		table.insert(d.tosay, lines[i])
	end
end

local function pick_idle_dialogue(rng)
	rng = auxi.rng_for_sake(rng)
	local pack = item.Dialogue[dialogue_lang()]
	local idle = pack and pack.idle
	if not idle or #idle == 0 then return nil end
	return idle[rng:RandomInt(#idle) + 1]
end

local function pick_special_item_dialogue(player, ent, rng)
	rng = auxi.rng_for_sake(rng)
	local d = ent:GetData()
	if d._special_dialogue_done then return nil end
	local pack = item.Dialogue[dialogue_lang()]
	local special = pack and pack.special_items
	if not special then return nil end
	local matches = {}
	for id, lines in pairs(special) do
		if player:HasCollectible(id) then matches[#matches + 1] = lines end
	end
	if #matches == 0 then return nil end
	d._special_dialogue_done = true
	return matches[rng:RandomInt(#matches) + 1]
end

local function queue_open_dialogue(player, ent)
	local special = pick_special_item_dialogue(player, ent, ent:GetDropRNG())
	if special then
		queue_dialogue(ent, special)
		return
	end
	local pack = item.Dialogue[dialogue_lang()]
	if not save.elses[item.own_key.."met"] then
		save.elses[item.own_key.."met"] = true
		queue_dialogue(ent, pack.intro)
	else
		queue_dialogue(ent, pack.repeat_meet)
	end
end

-- 台词气泡约 60 帧；间隙略短，便于连说又不叠成一团。
local SAY_GAP = 50

utter_next = function(ent)
	local d = ent:GetData()
	if (d._say_cd or 0) > 0 then return false end
	if not d.tosay or not d.tosay[1] then return false end
	local line = d.tosay[1]
	table.remove(d.tosay, 1)
	gui.draw_ch_with_time_to_dispair(
		ent.Position + item.Talking_Pos_Offset + Vector(-(#line) / 2, 0),
		Vector(0, -50),
		line,
		60
	)
	d._say_cd = SAY_GAP
	if #d.tosay == 0 then
		consistance_holder.try_hold_over_entity(ent, item.own_key)
		consistance_holder.try_hold_entity(ent, item.own_key)
	end
	return true
end

try_greet = function(ent)
	local d = ent:GetData()
	if d._greeted then return end
	if d._Data and d._Data[item.own_key] and d._Data[item.own_key].Accepted then
		d._greeted = true
		return
	end
	local player = Game():GetNearestPlayer(ent.Position)
	if not player then return end
	d._greeted = true
	queue_open_dialogue(player, ent)
end

local function queue_offer_dialogue(ent, opt, rng)
	rng = auxi.rng_for_sake(rng)
	local pack = item.Dialogue[dialogue_lang()].offers[opt.id]
	if not pack then return end
	local said = save.elses[item.own_key.."offer_said"] or {}
	local lines = said[opt.id] and pack.repeat_say or pack.first
	if not said[opt.id] then
		said[opt.id] = true
		save.elses[item.own_key.."offer_said"] = said
	end
	queue_dialogue(ent, lines)
	if rng:RandomInt(100) < 20 then
		local idle = pick_idle_dialogue(rng)
		if idle then queue_dialogue(ent, idle) end
	end
end

local function bless_hud_text(kind)
	local pack = item.Dialogue[dialogue_lang()].bless_hud
	local hud = pack and pack[kind]
	if hud then return hud[1], hud[2] end
	if dialogue_lang() == "zh" then return "吟游祝福", "本层生效" end
	return "Bard Blessing", "Active this floor"
end

local function blessing_bag()
	return save.elses[item.own_key.."bless"]
end

local function set_blessing(kind, rng)
	save.elses[item.own_key.."bless"] = {
		kind = kind,
		pending = true,
		room_uses = {},
		heart_rolls = {},
	}
end

local function clear_blessing()
	save.elses[item.own_key.."bless"] = nil
end

local function can_pay_heart(player)
	return player:GetHearts() >= 2 or player:GetSoulHearts() >= 2
end

local function pay_heart(player)
	if player:GetHearts() >= 2 then
		player:AddHearts(-2)
	else
		player:AddSoulHearts(-2)
	end
end

local OFFERS = {
	{
		id = "coin",
		anm2 = "gfx/005.021_penny.anm2",
		replacer = "gfx/items/slots/item_to_pay_coin.png",
		hud_num = "5",
		title_zh = "富饶之歌",
		title_en = "Song of Plenty",
		eid_zh = "{{Coin}} 富饶之歌#支付5枚硬币#下一层商店商品的硬币价格降低2",
		eid_en = "{{Coin}} Song of Plenty#Pay 5 coins#Shop coin prices are 2 lower next floor",
		can = function(player) return player:GetNumCoins() >= 5 end,
		take = function(player) player:AddCoins(-5) end,
	},
	{
		id = "key",
		anm2 = "gfx/005.031_key.anm2",
		replacer = "gfx/items/slots/item_to_pay_key.png",
		hud_num = "1",
		title_zh = "旅途之歌",
		title_en = "Song of the Road",
		eid_zh = "{{Key}} 旅途之歌#支付1把钥匙#下一层揭示通往宝箱房的最短路线，并持续开启沿途的门",
		eid_en = "{{Key}} Song of the Road#Pay 1 key#Next floor reveals the shortest route to the {{TreasureRoom}} and keeps the doors along it open",
		can = function(player) return player:GetNumKeys() >= 1 end,
		take = function(player) player:AddKeys(-1) end,
	},
	{
		id = "bomb",
		anm2 = "gfx/005.041_bomb.anm2",
		replacer = "gfx/items/slots/item_to_pay_bomb.png",
		hud_num = "1",
		title_zh = "战歌",
		title_en = "War Song",
		eid_zh = "{{Bomb}} 战歌#支付1个炸弹#下一层每个房间首个敌人死亡时引发爆炸",
		eid_en = "{{Bomb}} War Song#Pay 1 bomb#Next floor, the first enemy death in each room causes an explosion",
		can = function(player) return player:GetNumBombs() >= 1 end,
		take = function(player) player:AddBombs(-1) end,
	},
	{
		id = "heart",
		anm2 = "gfx/005.011_heart.anm2",
		anm2_fn = function(player)
			if player:GetHearts() >= 2 then
				return "gfx/005.011_heart.anm2"
			end
			return "gfx/005.013_heart (soul).anm2"
		end,
		replacer = "gfx/items/slots/item_to_pay_heart.png",
		replacer_fn = function(player)
			if player:GetHearts() >= 2 then
				return "gfx/items/slots/item_to_pay_heart.png"
			end
			return "gfx/items/slots/item_to_pay_soulheart.png"
		end,
		hud_num = "1",
		title_zh = "安魂曲",
		title_en = "Requiem",
		eid_zh = "{{Heart}} 安魂曲#支付1颗心#下一层生成的红心有25%概率变成魂心",
		eid_en = "{{Heart}} Requiem#Pay 1 heart#Red hearts generated next floor have a 25% chance to become soul hearts",
		can = can_pay_heart,
		take = pay_heart,
	},
}

spec = {
	key = item.own_key,
	variant = item.entity.Variant,
	range = 48,
	render_hud = false,
	on_open = function(player, ent)
		-- 开场台词由 UPDATE 的 try_greet 自顾自触发；此处仅兜底。
		try_greet(ent)
	end,
	can_open = function(ent)
		if not ent or not ent:Exists() then return false end
		local s = ent:GetSprite()
		if not s:IsPlaying("Idle") then return false end
		local d = ent:GetData()
		if d.should_prize then return false end
		if d._Data and d._Data[item.own_key] and d._Data[item.own_key].Accepted then return false end
		return true
	end,
	get_options = function(player,ent)
		local list = {}
		for _,info in ipairs(OFFERS) do
			if info.can(player) then list[#list + 1] = info end
		end
		return list
	end,
	on_confirm = function(player,ent,opt)
		if not opt or not opt.take then return end
		if opt.can and not opt.can(player) then return end
		local s = ent:GetSprite()
		local replacer = opt.replacer
		if opt.replacer_fn then replacer = opt.replacer_fn(player) end
		if replacer then
			s:ReplaceSpritesheet(2, replacer)
			s:LoadGraphics()
		end
		opt.take(player)
		set_blessing(opt.id,ent:GetDropRNG())
		local d = ent:GetData()
		queue_offer_dialogue(ent, opt, ent:GetDropRNG())
		s:Play("PayPrize",true)
		d.should_prize = true
		consistance_holder.try_hold_over_entity(ent,item.own_key)
		d._Data[item.own_key] = d._Data[item.own_key] or {}
		d._Data[item.own_key].Accepted = true
		consistance_holder.try_hold_entity(ent,item.own_key)
		local hud = Game():GetHUD()
		if hud and hud.ShowItemText then
			if slot_offer_lift.lang_zh() then
				hud:ShowItemText(opt.title_zh or "吟游乞丐", "")
			else
				hud:ShowItemText(opt.title_en or "Bard Beggar", "")
			end
		end
	end,
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_COLLISION, params = item.entity.Variant,
Function = function(_,ent,col,low)
	local player = col and col:ToPlayer()
	if not player then return end
	local s = ent:GetSprite()
	local d = ent:GetData()
	if s:IsPlaying("Idle") and d.should_prize ~= true then
		spec.variant = item.entity.Variant
		slot_offer_lift.try_confirm(player,ent,spec)
	end
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

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	spec.variant = item.entity.Variant
	slot_offer_lift.tick(player,spec)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if ent == nil then return end
	local player = ent:ToPlayer()
	if not player then return end
	return slot_offer_lift.block_input(player,item.own_key,hook,button)
end,
})

local debug_state = {
	overrides = {coin = nil, key = nil, bomb = nil, heart = nil},
	room_uses = {}, heart_rolls = {}, route = nil,
	stats = {discounts = 0, explosions = 0, heart_rolls = 0, heart_converts = 0},
	lifecycle = {}, price_quotes = {},
}

local DEBUG_KINDS = {coin = true, key = true, bomb = true, heart = true}

local function floor_key()
	local level = Game():GetLevel()
	local stage = level:GetStage()
	local stage_seed = Game():GetSeeds():GetStageSeed(stage)
	return table.concat({stage, level:GetStageType(), auxi.GetDimension() or 0, stage_seed}, ":")
end

local function formal_active(kind)
	local bless = blessing_bag()
	return bless and bless.active and bless.kind == kind
end

local function debug_active(kind)
	return debug_state.overrides[kind] == floor_key()
end

local function effect_active(kind)
	return formal_active(kind) or debug_active(kind)
end

local function room_key()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	return floor_key() .. ":" .. tostring(desc and desc.SafeGridIndex or -1)
end

local function allowed_connection(desc, slot)
	return desc and desc.AllowedDoors and (desc.AllowedDoors & (1 << slot)) ~= 0
end

local function actual_neighbors(desc)
	local ret = {}
	if not desc or not desc.GetNeighboringRooms then return ret end
	for slot, neighbor in pairs(desc:GetNeighboringRooms()) do
		if neighbor and allowed_connection(desc, slot) then
			local reverse_slot = nil
			for other_slot, back in pairs(neighbor:GetNeighboringRooms()) do
				if back and back.SafeGridIndex == desc.SafeGridIndex and allowed_connection(neighbor, other_slot) then
					reverse_slot = other_slot
					break
				end
			end
			if reverse_slot ~= nil then
				ret[#ret + 1] = {desc = neighbor, from_slot = slot, to_slot = reverse_slot}
			end
		end
	end
	return ret
end

local function build_treasure_route()
	local level = Game():GetLevel()
	local dimension = auxi.GetDimension() or 0
	local start = level:GetRoomByIdx(level:GetStartingRoomIndex(), dimension)
	if not start then return nil end
	local queue, head = {start}, 1
	local seen = {[start.SafeGridIndex] = true}
	local parent = {}
	local target = nil
	while queue[head] do
		local desc = queue[head]
		head = head + 1
		if desc.Data and desc.Data.Type == RoomType.ROOM_TREASURE then
			target = desc
			break
		end
		for _, edge in ipairs(actual_neighbors(desc)) do
			local idx = edge.desc.SafeGridIndex
			if not seen[idx] then
				seen[idx] = true
				parent[idx] = {from = desc.SafeGridIndex, from_slot = edge.from_slot, to_slot = edge.to_slot}
				queue[#queue + 1] = edge.desc
			end
		end
	end
	if not target then return nil end
	local edges, cursor = {}, target.SafeGridIndex
	while cursor ~= start.SafeGridIndex do
		local p = parent[cursor]
		if not p then return nil end
		table.insert(edges, 1, {from = p.from, to = cursor, from_slot = p.from_slot, to_slot = p.to_slot})
		cursor = p.from
	end
	return {floor = floor_key(), start = start.SafeGridIndex, target = target.SafeGridIndex, edges = edges}
end

local function reveal_route(route)
	if not route then return end
	local level = Game():GetLevel()
	local dimension = auxi.GetDimension() or 0
	local indices = {[route.start] = true, [route.target] = true}
	for _, edge in ipairs(route.edges or {}) do indices[edge.from] = true indices[edge.to] = true end
	for idx in pairs(indices) do
		local desc = level:GetRoomByIdx(idx, dimension)
		if desc then desc.DisplayFlags = desc.DisplayFlags | 5 end
	end
	level:UpdateVisibility()
end

local function active_route()
	local bless = blessing_bag()
	if formal_active("key") then return bless.route end
	if debug_active("key") then return debug_state.route end
end

local function rebuild_route()
	local route = build_treasure_route()
	if formal_active("key") then blessing_bag().route = route end
	if debug_active("key") then debug_state.route = route end
	reveal_route(route)
	return route
end

local function open_route_doors()
	local route = active_route()
	if not route or route.floor ~= floor_key() then return end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local room = Game():GetRoom()
	for _, edge in ipairs(route.edges or {}) do
		local slot = nil
		if desc.SafeGridIndex == edge.from then slot = edge.from_slot end
		if desc.SafeGridIndex == edge.to then slot = edge.to_slot end
		if slot ~= nil then
			local door = room:GetDoor(slot)
			if door then door:Open() end
		end
	end
end

local function reset_prices()
	price_holder.reset_price()
end

local COIN_QUOTE_KEY = item.own_key .. "coin_quote"

local function clear_coin_quote_states()
	for _, entity in ipairs(auxi.getothers(nil, EntityType.ENTITY_PICKUP)) do
		local pickup = entity:ToPickup()
		if pickup then pickup:GetData()[COIN_QUOTE_KEY] = nil end
	end
end

table.insert(item.post_myToCall, {CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_, ent, val)
	if effect_active("coin") and ent and ent:IsShopItem() and type(val) == "number" and val > 0 then
		local data = ent:GetData()
		local previous = data[COIN_QUOTE_KEY]
		local reused = previous ~= nil and previous.floor == floor_key() and val == previous.final
		local base = reused and previous.base or val
		local final = math.max(1, base - 2)
		local source = formal_active("coin") and "formal" or "debug"
		data[COIN_QUOTE_KEY] = {floor = floor_key(), base = base, final = final, source = source}
		debug_state.stats.discounts = debug_state.stats.discounts + 1
		debug_state.price_quotes[tostring(GetPtrHash(ent))] = {
			floor = floor_key(), room = room_key(), input = val, base = base, final = final,
			reused_base = reused, source = source, frame = Game():GetFrameCount(),
		}
		return final
	end
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_, ent)
	if effect_active("coin") and ent:IsShopItem() then price_holder.try_catch_price(ent) end
end})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	local bless = blessing_bag()
	if bless and bless.active and not bless.floor then
		bless.floor = floor_key()
		bless.room_uses = {}
		bless.heart_rolls = {}
		if bless.kind == "key" then rebuild_route() end
		local hud = Game():GetHUD()
		if hud and hud.ShowItemText then
			local title, subtitle = bless_hud_text(bless.kind)
			if title then hud:ShowItemText(title, subtitle or "") end
		end
	end
	if debug_active("key") then rebuild_route() end
	reset_prices()
end,
})

table.insert(item.myToCall, {CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function()
	local old_floor = floor_key()
	debug_state.overrides = {coin = nil, key = nil, bomb = nil, heart = nil}
	debug_state.room_uses = {}
	debug_state.heart_rolls = {}
	debug_state.route = nil
	debug_state.price_quotes = {}
	debug_state.lifecycle[#debug_state.lifecycle + 1] = {event = "pre_new_level", floor = old_floor}
	clear_coin_quote_states()
	local bless = blessing_bag()
	if bless then
		if bless.pending then
			bless.pending = false
			bless.active = true
			bless.floor = nil
		else
			clear_blessing()
		end
	end
end})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	reveal_route(active_route())
	open_route_doors()
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = nil,
Function = function(_, npc)
	if not effect_active("bomb") or not npc:IsEnemy() or npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return end
	local key = room_key()
	local bless = blessing_bag()
	if formal_active("bomb") then
		bless.room_uses = bless.room_uses or {}
		if bless.room_uses[key] then return end
		bless.room_uses[key] = true
	elseif debug_state.room_uses[key] then
		return
	else
		debug_state.room_uses[key] = true
	end
	debug_state.stats.explosions = debug_state.stats.explosions + 1
	debug_state.last_enemy = {type = npc.Type, variant = npc.Variant, subtype = npc.SubType, room = key}
	Game():BombExplosionEffects(npc.Position, 100, BitSet128(0, 0), Color.Default, Game():GetPlayer(0), 1, false, false)
end})

local function heart_roll_store(key)
	local bless = blessing_bag()
	if formal_active("heart") then
		bless.heart_rolls = bless.heart_rolls or {}
		return bless.heart_rolls
	end
	return debug_state.heart_rolls
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_HEART,
Function = function(_, pickup)
	if not effect_active("heart") then return end
	local subtype = pickup.SubType
	if subtype ~= HeartSubType.HEART_FULL and subtype ~= HeartSubType.HEART_HALF then return end
	local key = table.concat({room_key(), pickup.InitSeed, subtype}, ":")
	local rolls = heart_roll_store(key)
	if rolls[key] ~= nil then return end
	local roll = pickup:GetDropRNG():RandomFloat()
	local convert = roll < 0.25
	rolls[key] = convert
	debug_state.stats.heart_rolls = debug_state.stats.heart_rolls + 1
	debug_state.last_heart = {
		key = key, roll = roll, convert = convert, source = formal_active("heart") and "formal" or "debug",
		floor = floor_key(), room = room_key(), subtype = subtype,
	}
	if convert then
		debug_state.stats.heart_converts = debug_state.stats.heart_converts + 1
		local target = subtype == HeartSubType.HEART_FULL and HeartSubType.HEART_SOUL or HeartSubType.HEART_HALF_SOUL
		pickup:Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, target, true, true, true)
	end
end})

table.insert(item.myToCall, {CallBack = enums.Callbacks.POST_REWIND, params = nil,
Function = function()
	debug_state.room_uses = {}
	debug_state.heart_rolls = {}
	debug_state.price_quotes = {}
	debug_state.lifecycle[#debug_state.lifecycle + 1] = {event = "post_rewind", floor = floor_key(), room = room_key()}
	clear_coin_quote_states()
	reset_prices()
	if debug_active("key") then rebuild_route() end
end})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	debug_state = {
		overrides = {coin = nil, key = nil, bomb = nil, heart = nil},
		room_uses = {}, heart_rolls = {}, route = nil,
		stats = {discounts = 0, explosions = 0, heart_rolls = 0, heart_converts = 0},
		lifecycle = {{event = continue and "continue" or "new_run", floor = floor_key()}}, price_quotes = {},
	}
	if continue then
	else
		clear_blessing()
	end
end,
})

function item.debug_get_state() return debug_state end
function item.debug_is_override(kind) return debug_active(kind) end
function item.debug_set_override(kind, enabled)
	if not DEBUG_KINDS[kind] then return false end
	debug_state.overrides[kind] = enabled == true and floor_key() or nil
	debug_state.lifecycle[#debug_state.lifecycle + 1] = {
		event = enabled == true and "debug_enable" or "debug_disable", kind = kind, floor = floor_key(), room = room_key(),
	}
	if kind == "coin" then
		clear_coin_quote_states()
		reset_prices()
	end
	if kind == "key" and enabled then rebuild_route() end
	return true
end
function item.debug_schedule(kind)
	set_blessing(kind)
	return true
end
function item.debug_rebuild_route() return rebuild_route() end
function item.debug_reset_prices() reset_prices() end
function item.debug_spawn_bard()
	local player = Game():GetPlayer(0)
	local ent = Isaac.Spawn(item.entity.Type, item.entity.Variant, 0, player.Position + Vector(80, 0), Vector.Zero, player)
	every_entity_holder.init_slot(ent)
	return ent
end
function item.debug_spawn_hearts(count)
	local player = Game():GetPlayer(0)
	for i = 1, (count or 40) do
		local subtype = i % 2 == 0 and HeartSubType.HEART_FULL or HeartSubType.HEART_HALF
		local pos = Game():GetRoom():FindFreePickupSpawnPosition(player.Position + Vector((i % 8 - 4) * 30, math.floor(i / 8) * 24), 0, true)
		Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, subtype, pos, Vector.Zero, player)
	end
end
function item.debug_copy_summary()
	local output = require("Qing_Remaster_scripts.debug.probe_output")
	return output.copy_summary({
		floor = floor_key(), room = room_key(),
		overrides = {
			coin = debug_active("coin"), key = debug_active("key"),
			bomb = debug_active("bomb"), heart = debug_active("heart"),
		},
		stats = debug_state.stats,
		last_heart = debug_state.last_heart,
		route = debug_state.route and {target = debug_state.route.target, edges = #debug_state.route.edges} or nil,
	})
end
function item.debug_copy_full_report()
	local output = require("Qing_Remaster_scripts.debug.probe_output")
	return output.copy_json({debug = debug_state, formal = blessing_bag(), floor = floor_key(), room = room_key()})
end

local function static_eid()
	if slot_offer_lift.lang_zh() then
		return "交付一份资源，获得下一层的祝福"..
			"#靠近后左右切换馈赠，走进确认"..
			"#按{{ButtonRT}}取消"
	end
	return "Offer a resource for a blessing on the next floor"..
		"#Switch gifts with left/right, walk in to confirm"..
		"#Press {{ButtonRT}} to cancel"
end

local function option_eid(player, opt)
	if slot_offer_lift.lang_zh() then
		return opt.eid_zh or static_eid()
	end
	return opt.eid_en or static_eid()
end

slot_offer_lift.install_eid("qing_bard_beggar_eid", item.entity.Variant, item.own_key, static_eid, option_eid)

return item

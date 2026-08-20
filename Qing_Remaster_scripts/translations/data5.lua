--0,1,2,3分别表示：无事发生，感谢，憎恨，离开。
local data = {
	["English"]={
		
	},
	["Chinese"]={
		{
			Name = "迷路的羔羊",
			Description = {"忽然间，一只迷路的怪物出现在你面前。#我们放了他吧。#C1说。#不行！要杀了它！#C2说。#怎么抉择呢？",},
			Selection = {
				{Description = "放它生路",LaterOn = {{Description = "怪物和#C1很感激你，但#C2并不。",weight = 10,Bonus = 1 + 2 * 4,},{Description = "好吧，我其实还是比较仁爱的。#C2笑着说。",weight = 5,Bonus = 5,},},},
				{Description = "取它小命",LaterOn = {{Description = "精疲力尽的怪物被你轻松斩杀。",weight = 10,Bonus = 4,},{Description = "精疲力尽的怪物被#C2轻松斩杀，但#C1似乎不开心。",weight = 10,Bonus = 6,},{Description = "糟糕！怪物愤怒地向你冲来！",weight = 10,Bonus = 0,},},},	--!!
			},
		},
		{
			Name = "河流",
			Description = {"#C1和#C2同时掉进了水里。#救我！快救我！#C1大喊。#不！我才必须活着！#C2也喊着。",},
			Selection = {
				{Description = "救#C1",LaterOn = {{Description = "#C1很感激你，但#C2永远离开了你。",weight = 10,Bonus = 1 + 3 * 4,},},},
				{Description = "救#C2",LaterOn = {{Description = "#C2很感激你，但#C1永远离开了你。",weight = 10,Bonus = 3 + 1 * 4,},},},
				{Description = "冷眼旁观",LaterOn = {{Description = "虽然#C1与#C2还是挣扎着上了岸，但它们看起来并不开心。",weight = 10,Bonus = 2 + 2 * 4,},{Description = "水流将#C1与#C2带向远方",weight = 10,Bonus = 3 + 3 * 4,},},},
				{Description = "我全都要救！",LaterOn = {{Description = "#C1与#C2挣扎着成功上了岸。",weight = 10,Bonus = 1 + 1 * 4,},{Description = "虽然受了点伤，但是在你的努力下#C1与#C2总算平安无事",weight = 10,Bonus = 1 + 1 * 4,Special = function(player,c1,c2,info,item) player:TakeDamage(1,0,EntityRef(player),0) end,},},},
			},
		},
		{
			Name = "魔法蘑菇",
			Description = {"主人！我们去摘魔法蘑菇了！#C1与#C2将两篮蘑菇递给你。#挑一个吃吧！它们说。",},
			Selection = {
				{Description = "吃下#C1的可疑蘑菇",LaterOn = {{Description = "嘟嘟嘟！你变厉害了！",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) player:UseActiveItem(CollectibleType.COLLECTIBLE_MEGA_MUSH,UseFlag.USE_NOANIM) end,},},},
				{Description = "吃下#C2的可疑蘑菇",LaterOn = {{Description = "有..有点反胃？",weight = 10,Bonus = 1 * 4,Special = function(player,c1,c2,info,item) for i = 1,math.random(3) do player:UseActiveItem(CollectibleType.COLLECTIBLE_WAVY_CAP,UseFlag.USE_NOANIM) end end,},},},		--sound
			},
		},
		{
			Name = "圣光闪烁",
			Description = {"你发现一道圣光照耀在房间中央。#这是一个洗礼台，只有一个人能受洗。#让谁去呢？",},
			Selection = {
				{Description = "洗礼自身",LaterOn = {
					{Description = "哦不！这是一个圣光通道！",weight = 5,Bonus = 0,Special = function(player,c1,c2,info,item) local q = Isaac.Spawn(1000,39,0,player.Position + Vector(0,-40),Vector(0,0),nil) for i = 1,60 do q:Update() end q:GetSprite():SetLastFrame() q.Position = player.Position end,},
					{Description = "你被祝福了！",weight = 10,Bonus = 0,Special = function(player,c1,c2,info,item) end},		--!!
				},},
				{Description = "洗礼#C1",LaterOn = {
					{Description = "不！这是一个圣光通道！你眼看着#C1离你而去。",weight = 5,Bonus = 3,},
					{Description = "#C1变得光洁无比。它很开心。",weight = 10,Bonus = 1,},
				},},
				{Description = "洗礼#C2",LaterOn = {
					{Description = "不！这是一个圣光通道！你眼看着#C2离你而去。",weight = 5,Bonus = 3 * 4,},
					{Description = "#C2变得光洁无比。它很开心。",weight = 10,Bonus = 1 * 4,},
				},},
			},
		},
		{
			Name = "小礼物",
			Description = {"你为#C1准备了一份礼物，但#C2似乎眼巴巴地望着你",},
			Selection = {
				{Description = "按照计划，赠送给#C1",LaterOn = {
					{Description = "谢谢你！#C1笑着收下了它。",weight = 10,Bonus = 1,},
				},},
				{Description = "不如送给#C2吧",LaterOn = {
					{Description = "真的可以吗？#C2十分感动。",weight = 10,Bonus = 1 * 4,},
					{Description = "你的心意我非常感谢！但我想还是#C1更适合这份礼物！",weight = 10,Bonus = 1 + 1 * 4,},
				},},
			},
		},
		{
			Name = "爱人的名字",
			Description = {"主人在手心写一个名字，让我猜猜是谁如何？#C1当着#C2的面对你这样说。#该怎么做呢？",},
			Selection = {
				{Description = "写上自己的名字",LaterOn = {
					{Description = "我猜..是你的名字？#我就知道！嘿嘿..",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
					{Description = "我猜..是我的名字？#啊？不是啊..",weight = 10,Bonus = 0,Special = function(player,c1,c2,info,item) end,},
					{Description = "我猜..是#C2的名字？#不是？太好了..",weight = 10,Bonus = 0,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "写上#C1的名字",LaterOn = {
					{Description = "我猜..是我的名字？#啊！果然呢！谢谢主人..",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
					{Description = "是我的名字对吧！#果然主人才不会要#C2这种废物..",weight = 10,Bonus = 1 + 2 * 4,Special = function(player,c1,c2,info,item) end,},
					{Description = "我猜..是#C2的名字？#居然不是？看来你心里还有我..",weight = 10,Bonus = 0,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "写上#C2的名字",LaterOn = {
					{Description = "我猜..是我的名字？#什么？为什么是#C2啊！..",weight = 10,Bonus = 2 + 1 * 4,Special = function(player,c1,c2,info,item) end,},
					{Description = "我猜..是#C2的名字？#呵呵，去和#C2过吧！..",weight = 10,Bonus = 3 + 1 * 4,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "什么也不写",LaterOn = {
					{Description = "我猜..是你的名字？诶？..",weight = 10,Bonus = 0,Special = function(player,c1,c2,info,item) end,},
					{Description = "我猜..是我的名字？诶？..",weight = 10,Bonus = 0,Special = function(player,c1,c2,info,item) end,},
					{Description = "我猜..是#C2的名字？诶？..",weight = 10,Bonus = 0,Special = function(player,c1,c2,info,item) end,},
				},},
			},
		},
		{
			Name = "品质比拼",
			Description = {"主人认为品质是几的道具更好呢？##C1和#C2这样问你。",},
			Selection = {
				{Description = "零级",LaterOn = {
					{Description = "",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "一级",LaterOn = {
					{Description = "",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "二级",LaterOn = {
					{Description = "",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "三级",LaterOn = {
					{Description = "",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "四级",LaterOn = {
					{Description = "",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "品质不重要，有趣才重要",LaterOn = {
					{Description = "",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
				},},
			},
		},
		{
			Name = "死亡瞬间",
			Description = {"在你濒死前的瞬间，你的眼前出现了两个你所爱的道具。#你的选择是？",},
			Selection = {
				{Description = "向#C1伸出手",LaterOn = {
					{Description = "复活吧！我的爱人！#我将献出我的生命！##C1向你高声喊道。#你感到身体重获力量。",weight = 15,Bonus = 3,Special = function(player,c1,c2,info,item) end,},
					{Description = "对不起，爱人，但是我也无能为力了..",weight = 5,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
					{Description = "为何要如此求索？#C1叹了口气。#你的死亡也不过是贪婪的伎俩。",weight = 5,Bonus = 3,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "向#C1祈祷",LaterOn = {
					{Description = "复活吧！我的爱人！#我将献出我的生命！##C1向你高声喊道。#你感到身体重获力量。",weight = 10,Bonus = 3,Special = function(player,c1,c2,info,item) end,},
					{Description = "对不起，爱人，但是我也无能为力了..",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "向#C2伸出手",LaterOn = {
					{Description = "复活吧！我的爱人！#我将献出我的生命！##C2向你高声喊道。#你感到身体重获力量。",weight = 15,Bonus = 3 * 4,Special = function(player,c1,c2,info,item) end,},
					{Description = "对不起，爱人，但是我也无能为力了..",weight = 5,Bonus = 1 * 4,Special = function(player,c1,c2,info,item) end,},
					{Description = "为何要如此求索？#C2叹了口气。#你的死亡也不过是贪婪的伎俩。",weight = 5,Bonus = 3 * 4,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "向#C2祈祷",LaterOn = {
					{Description = "复活吧！我的爱人！#我将献出我的生命！##C2向你高声喊道。#你感到身体重获力量。",weight = 10,Bonus = 3 * 4,Special = function(player,c1,c2,info,item) end,},
					{Description = "对不起，爱人，但是我也无能为力了..",weight = 10,Bonus = 1 * 4,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "什么也不做",LaterOn = {
					{Description = "你露出安详的神色，你的爱人纷纷为你祈祷。",weight = 10,Bonus = 1 + 1 * 4,Special = function(player,c1,c2,info,item) end,},
				},},
			},
		},
		{
			Name = "死亡证明",
			Description = {"费尽千辛万苦的你终于进入了死亡证明层，但#C1与#C2却拦住了你。#它们分别要求你再拾取一份自己来加强自身。",},
			Selection = {
				{Description = "答应#C1",LaterOn = {
					{Description = "谢谢主人！#C2嫉妒地看着你们。",weight = 10,Bonus = 1 + 2 * 4,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "答应#C2",LaterOn = {
					{Description = "谢谢主人！#C1嫉妒地看着你们。",weight = 10,Bonus = 2 + 1 * 4,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "谁也不答应",LaterOn = {
					{Description = "怎么会这样呢..它们纷纷沮丧地低下了头。",weight = 10,Bonus = 2 + 2 *4,Special = function(player,c1,c2,info,item) end,},
					{Description = "没事的，我知道主人的难处！#它们重振精神，继续跟随着你。",weight = 2,Bonus = 1 + 1 * 4,Special = function(player,c1,c2,info,item) end,},
				},},
				{Description = "以和为贵，此层不如不进",LaterOn = {
					{Description = "#C1与#C2感动地望着你。",weight = 10,Bonus = 1 + 1 * 4,Special = function(player,c1,c2,info,item) end,},
				},},
			},
		},
		{
			Name = "",
			Description = {"",},
			Selection = {
				{Description = "",LaterOn = {
					{Description = "",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
				},},
			},
		},
		{
			Name = "",
			Description = {"",},
			Selection = {
				{Description = "",LaterOn = {
					{Description = "",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
				},},
			},
		},
		{
			Name = "",
			Description = {"",},
			Selection = {
				{Description = "",LaterOn = {
					{Description = "",weight = 10,Bonus = 1,Special = function(player,c1,c2,info,item) end,},
				},},
			},
		},
	},
}

return data
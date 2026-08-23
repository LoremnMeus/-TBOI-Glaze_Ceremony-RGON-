local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local Dialog_holder = require("Qing_Remaster_scripts.others.Dialog_holder") 

local useful_cnt = {}
local to_render = Sprite()

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	target_Beast = nil,
	should_end = false,
	end1_has_end = false,
	lst_frame = 114,
	should_fin = false,
	end1_render_counter = 0,
	Talking_Pos_Offset = Vector(20,-30),
	now_counter = 0,
	end1_dialog_cnt = 0,
	dialog_cnt = 1,
	own_key = "Thread_End_1",
	Words = {
		zh = {
			{word = "现在你无路可退了，大家伙！",},
			{word =	"青御空飞行，将短剑狠狠地刺向祸兽。",},
			{word = "额啊！！..在飞刃刺中怪兽前的瞬间，光芒忽然四射。",cut = true,},
			{word = "祸兽痛苦的惨叫声同时响起。",},
			{word = "什么？是琉璃王子！他蓄谋已久，在最后的一瞬间拿下了人头！",cut = true,},
			{word = "在七彩的光线中，琉璃转过头，笑着看向青。",},
			{word = "这等妖兽，就由我琉璃来收下了！",},
			{word = "而且，没想到，还有这种意外收获...",cut = true,},
			{word = "可恶..青紧紧地盯着琉璃。",},
			{word = "那是我的宿敌，琉璃王子。",},
			{word = "必须先下手为强！",},
			{word = "说时迟，那时快，青的飞刃已经高悬在琉璃的头顶！",},
			{word = "还是如此莽撞，还好我早有准备。",cut = true,},
			{word = "剑尖悬停在距离以撒咽喉半米之处，无法再前进半步。",},
			{word = "以撒！！青瞳孔放大。你————",cut = true,},
			{word = "有趣的筹码，对你来说。琉璃呵呵地笑着。",},
			{word = "那么，小刺客。你是选择让你的朋友与我陪葬，还是立刻束手就擒呢？",},
			{word = "唔...这...我...",cut = true,},
			{word = "这个瞬间。'",cut = true,},
			{word = "熔销光暗结",},
			{word = "啊啊啊啊啊！！！！....",cut = true,},
			{word = "...",cut = true,},						--视角切换
			{word = "哦！孩子，你醒了。",cut = true,},
			{word = "你是...谁？...我在哪里？",cut = true,},
			{word = "鄙人琉璃。现在是青的主治医师。",},
			{word = "！！小青！他在哪里？我刚刚还拜托他...！",cut = true,},
			{word = "青为了你，受到了祸兽的搏命一击。",cut = true,},
			{word = "现在正处于病危治疗中。",},
			{word = "什么！！怎么会...",cut = true,},
			{word = "看，这些就是用于治疗的器材。",},
			{word = "呜呜...都是我的错...",},
			{word = "请节哀。",cut = true,},
			{word = "这些是小青的衣服，你先带回去吧。",unlock = true,},	
			{word = "但他醒来之后该...",},
			{word = "不必担心。",cut = true,},
			{word = "另外，治疗的素材有点不够了。",},
			{word = "我需要使用炼金术稍微制作一点素材。",},
			{word = "要我...",},
			{word = "你可以帮助小青，对吧？",},
			{word = "呜...",},
			{word = "那么来吧。",cut = true,},
			{word = "片刻后",},
			{word = "好，我在你的身上刻了一个隐藏的炼成阵。",},
			{word = "制造的材料散落在地下室各个角落。",},
			{word = "我的分队已经前去收集它们了。",},
			{word = "分别找到富含金、木、水、火、土的材料",},
			{word = "吞服，吸收它们的能量",cut = true,},
			{word = "呜呜...包在我身上...",},
			{word = "对了，我能告诉你一个秘密，水的素材存在于'虚像与实像之间'。",},
			{word = "炼成素材，记得多收集一点哦！",fin = true,},
		},
		en = {
            {word = "Now you have nowhere to retreat, big guy!",},
            {word = "Qing flew through the air, thrusting his dagger fiercely at the calamity beast.",},
            {word = "Argh!!.. Just as the flying blade was about to hit the monster, a sudden burst of light erupted.", cut = true,},
            {word = "The agonized scream of the calamity beast echoed simultaneously.",},
            {word = "What? It's Prince Glaze! He had been plotting all along, taking the final blow at the last moment!", cut = true,},
            {word = "Amidst the colorful rays of light, Glaze turned his head and smiled at Qing.",},
            {word = "This demon beast shall be mine to claim!",},
            {word = "And to think, there's also this unexpected bonus...", cut = true,},
            {word = "Damn it.. Qing stared intently at Glaze.",},
            {word = "That's my arch-nemesis, Prince Glaze.",},
            {word = "I must strike first!",},
            {word = "In the blink of an eye, Qing's flying blade was already suspended above Glaze's head!",},
            {word = "Still so reckless, good thing I came prepared.", cut = true,},
            {word = "The sword tip hovered half a meter from Isaac's throat, unable to advance any further.",},
            {word = "Isaac!! Qing's pupils dilated. You————", cut = true,},
            {word = "An interesting bargaining chip, for you. Glaze chuckled.",},
            {word = "So, little assassin. Will you choose to have your friend die with me, or surrender immediately?",},
            {word = "Ugh... this... I...", cut = true,},
            {word = "At this moment.", cut = true,},
            {word = "Melting light and darkness together",},
            {word = "AHHHHHHH!!!!....", cut = true,},
            {word = "...", cut = true,},                        -- Scene transition
            {word = "Oh! Child, you're awake.", cut = true,},
            {word = "Who... are you?... Where am I?", cut = true,},
            {word = "I am Glaze. Currently Qing's attending physician.",},
            {word = "!! Qing! Where is he? I just asked him to...!", cut = true,},
            {word = "Qing took a fatal blow from the calamity beast for you.", cut = true,},
            {word = "He's now in critical condition and undergoing treatment.",},
            {word = "What!! How could this...", cut = true,},
            {word = "Look, these are the medical equipment for his treatment.",},
            {word = "Wuwu... it's all my fault...",},
            {word = "Please accept my condolences.", cut = true,},
            {word = "These are Qing's clothes, please take them back.", unlock = true,},    
            {word = "But what should we do when he wakes up...",},
            {word = "Don't worry.", cut = true,},
            {word = "Also, we're running low on treatment materials.",},
            {word = "I need to use alchemy to create some more materials.",},
            {word = "Do you need me to...",},
            {word = "You want to help Qing, right?",},
            {word = "Wuwu...",},
            {word = "Then come with me.", cut = true,},
            {word = "A moment later",},
            {word = "Good, I've engraved a hidden alchemy array on your body.",},
            {word = "The materials needed are scattered throughout the basement.",},
            {word = "My team has already gone to collect them.",},
            {word = "Find materials rich in metal, wood, water, fire, and earth",},
            {word = "Consume them and absorb their energy", cut = true,},
            {word = "Wuwu... leave it to me...",},
            {word = "By the way, I can tell you a secret - the water material exists 'between illusion and reality'.",},
            {word = "Remember to collect plenty of alchemy materials!", fin = true,},
        },
	},
	Words2 = {
		zh = {
			[1] = {
				{word = "啊！你是..",},
				{},
				{word = "小青！真高兴还能见到你！",},
				{pword = "..",},
				{word = "小青，我有一件事想拜托你",},
				{},
				{word = "我的家里似乎闯进来一只大怪兽，它好可怕，我打不过它！",},
				{},
				{word = "妈妈也不在家，我不想再让妈妈为我担心了。",},
				{},
				{word = "你能战胜它吗？你一定可以捉住它，对吧！",},
				{},
				{pword = "好",special = function() save.elses.has_speak_1 = true end,},
				{},
				{word = "好耶！谢谢您！",special = function(ent) ent:GetSprite():Play("Happy",true) end,},
				{},
			},
			[2] = {
				{
					{word = "还是有点困...",},
					{},
					{},
					{word = "等小青走了再去睡会儿吧...",},
					{},
					{},
				},
				{
					{word = "如果能抓住大怪兽的话，大家都会羡慕我吧！",},
					{},
					{},
				},
				{
					{word = "好想出去玩，但这周都得在家里隔离",},
					{},
					{},
					{word = "决定了！一会去地下室！",},
					{},
					{},
				},
				{
					{word = "忽然有点想当刺客了",},
					{},
					{},
					{word = "努力训练的话，未来我也会变得很帅吗？",},
					{},
					{},
				},
				{
					{word = "小青为什么要戴大帽子呢？",},
					{},
					{},
					{word = "难道这是一种修炼吗？",},
					{},
					{},
				},
				{
					{word = "好像有点饿了",},
					{},
					{},
					{word = "可是家里只剩狗粮能吃了",},
					{},
					{},
					{word = "唔唔..等会儿还是再躺一会吧",},
					{},
					{},
				},
				{
					{word = "妈妈那天好生气啊，她出门的时候把门都摔坏了。",},
					{},
					{word = "她还要多久才会回来呢？",},
					{},
					{},
				},
				{
					{word = "对不起，妈妈..",},
					{},
					{word = "我不是故意那样画的...",},
					{},
					{},
				},
			},
			[3] = {
				{word = "唔唔..",},
				{},
				{word = "好快就天黑了啊..",},
				{},
				{},
				{pword = "做个好梦，以撒！",},
				{},
			},
			[4] = {
				{word = "等下...",},
				{},
				{word = "那是我的床...",},
				{},
			},
			[5] = {
				{word = "小青你去忙吧...",},
				{},
				{word = "我再躺一会儿",},
				{},
				{word = "别管我..",},
				{},
			},
		},
		en = {
            [1] = {
                {word = "Ah! You are..",},
                {},
                {word = "Qing! I'm so glad to see you again!",},
                {pword = "..",},
                {word = "Qing, I need to ask you for a favor",},
                {},
                {word = "There seems to be a big monster in my house, it's so scary, I can't defeat it!",},
                {},
                {word = "Mom isn't home either, I don't want to worry her anymore.",},
                {},
                {word = "Can you defeat it? You can catch it, right!",},
                {},
                {pword = "Okay", special = function() save.elses.has_speak_1 = true end,},
                {},
                {word = "Yay! Thank you!", special = function(ent) ent:GetSprite():Play("Happy",true) end,},
                {},
            },
            [2] = {
                {
                    {word = "Still a bit sleepy...",},
                    {},
                    {},
                    {word = "I'll sleep a bit more after Qing leaves...",},
                    {},
                    {},
                },
                {
                    {word = "If I can catch the big monster, everyone will be so jealous of me!",},
                    {},
                    {},
                },
                {
                    {word = "I really want to go out and play, but I have to stay home in quarantine this week",},
                    {},
                    {},
                    {word = "I've decided! I'll go to the basement later!",},
                    {},
                    {},
                },
                {
                    {word = "Suddenly I feel like becoming an assassin",},
                    {},
                    {},
                    {word = "If I train hard, will I become really cool in the future?",},
                    {},
                    {},
                },
                {
                    {word = "Why does Qing wear such a big hat?",},
                    {},
                    {},
                    {word = "Is it some kind of training?",},
                    {},
                    {},
                },
                {
                    {word = "I think I'm a bit hungry",},
                    {},
                    {},
                    {word = "But there's only dog food left to eat at home",},
                    {},
                    {},
                    {word = "Hmm.. I think I'll just lie down a bit more",},
                    {},
                    {},
                },
                {
                    {word = "Mom was so angry that day, she slammed the door so hard when she left.",},
                    {},
                    {word = "How much longer until she comes back?",},
                    {},
                    {},
                },
                {
                    {word = "I'm sorry, Mom..",},
                    {},
                    {word = "I didn't mean to draw that...",},
                    {},
                    {},
                },
            },
            [3] = {
                {word = "Hmm..",},
                {},
                {word = "It got dark so quickly..",},
                {},
                {},
                {pword = "Sweet dreams, Isaac!",},
                {},
            },
            [4] = {
                {word = "Wait...",},
                {},
                {word = "That's my bed...",},
                {},
            },
            [5] = {
                {word = "Qing, you go ahead...",},
                {},
                {word = "I'll just lie here a bit more",},
                {},
                {word = "Don't mind me..",},
                {},
            },
        },
	},	
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.should_end = false
	item.end1_has_start = false
	item.should_fin = false
	item.end1_has_end = false
	item.lst_frame = 108
	for i = 1,20 do
		save.elses[item.own_key.."has_speak_"..tostring(i)] = false
	end
end,
})

function start_end1()
	MusicManager():Play(69,1)
	Isaac.GetPlayer(0):UseActiveItem(CollectibleType.COLLECTIBLE_PAUSE, UseFlag.USE_NOANIM)		--停止世界
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		local succ = Attribute_holder.try_hold_attribute(player,"ControlsEnabled",false)
		d[item.own_key.."End_1_control_enables_succ"] = succ
		player.Velocity = Vector.Zero
	end
	to_render:Load("gfx/my_cutscenes/my_fin1.anm2",true)
	to_render:Play("Scene",true)
	item.end1_has_start = true
	
	item.end1_render_counter = 0
	item.end1_dialog_cnt = 0
	item.now_counter = 0
	item.dialog_cnt = 1
	item.lst_frame = 108
	item.should_fin = false
	item.end1_has_end = false
	item.end1_has_end_counter = 0
end

function item.finish_end1()
	item.end1_has_start = false
	local tbl = {}
	for u,v in pairs(enums.AchievementGraphics.others.Ending1) do
		table.insert(tbl,#tbl + 1,"gfx/ui/Some achievements/"..v..".png")
	end
	Unlocker.unlock_achievement(save.UnlockData.Others.Ending1,"Unlock",{Achievement_page = tbl,})
	
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		local succ = Attribute_holder.try_rewind_attribute(player,"ControlsEnabled",d[item.own_key.."End_1_control_enables_succ"])
	end
	if item.end1_has_end_counter ~= 0 then item.end1_has_end_counter = 0 end
	item.end1_has_end = true
	if Achievement_Display_holder.Is_Finished_playing() then
		item.end1_has_end = false
		Game():End(3)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	if item.end1_has_start or item.end1_has_end then
		if Game():IsPaused() or item.end1_has_end then
			local scz = gui.GetScreenSize()
			to_render.Scale = Vector(scz.X/432,scz.Y/240)
			to_render:Render(Vector(scz.X/2,scz.Y/2) - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
		end
		if Achievement_Display_holder.Is_Finished_playing() and item.end1_has_end then
			if item.end1_has_end_counter == nil then item.end1_has_end_counter = 0 end
			if item.end1_has_end_counter > 1 then
				item.end1_has_end = false
				Game():End(3)
			else
				item.end1_has_end_counter = item.end1_has_end_counter + 1
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_,name)
	if name == "Qing_HelpfulShader" then
		if item.end1_has_start then
			if Game():IsPaused() then
			else
				local scz = gui.GetScreenSize()
				to_render.Scale = Vector(scz.X/432,scz.Y/240)
				to_render:Render(Vector(scz.X/2,scz.Y/2) - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
				if SFXManager():IsPlaying(SoundEffect.SOUND_MEAT_JUMPS) then
					SFXManager():Stop(SoundEffect.SOUND_MEAT_JUMPS)
				end
				if item.should_fin ~= true then
					local frct = item.end1_dialog_cnt * 6 + math.floor(item.end1_render_counter/2)
					local should_change = false
					local should_finish = false
					local language = Options.Language
					if item.Words[language] == nil then language = "zh" end
					local now_word = item.Words[language][item.dialog_cnt] 
					local word = now_word.word
					if word then
						gui.draw_ch(Vector(scz.X * 0.5 - (#word) * 2.5,scz.Y * 0.8),word,1.5,1.5,nil,true)
					end
					to_render:SetFrame("Scene",frct)
					item.end1_render_counter = (item.end1_render_counter + 1)% 12
					item.now_counter = item.now_counter + 1
					if item.now_counter == 80 or (item.now_counter > 6 and Input.IsActionPressed(ButtonAction.ACTION_MENUCONFIRM,0)) then 
						item.now_counter = 0
						item.dialog_cnt = item.dialog_cnt + 1
						if now_word.cut then should_change = true end
						if now_word.fin then should_finish = true end
					end
					if should_change then
						item.end1_dialog_cnt = item.end1_dialog_cnt + 1 
					end
					if should_finish then 
						item.should_fin = true
					end
				else
					item.lst_frame = item.lst_frame + 0.5
					to_render:SetFrame("Scene",math.floor(item.lst_frame))
					if item.lst_frame >= 140 then
						item.finish_end1()
					end
				end
			end
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent, amt, flag, source, cooldown)
	if item.end1_has_end or item.end1_has_start then	
		return false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_BED,
Function = function(_,ent)
	if ent.Type == 5 and ent.Variant == PickupVariant.PICKUP_BED then
		local level = Game():GetLevel()
		local levelStage = level:GetStage()
		if levelStage == LevelStage.STAGE8 then
			if Game():GetPlayer(0):GetPlayerType() == enums.Players.wq and level:GetCurrentRoomDesc().SafeGridIndex == 84 then
				local d = ent:GetData()
				local s = ent:GetSprite()
				if consistance_holder.try_check_entity(ent,item.own_key) and d._Data[item.own_key].is_isaac_sleeping then
					s:Load("gfx/thread/Sleep_on_bed.anm2",true)
					s:Play("Idle",true)
				else
					d._Data = d._Data or {}
					d._Data[item.own_key] = d._Data[item.own_key] or {}
					d._Data[item.own_key].is_isaac_sleeping = true
					consistance_holder.try_hold_entity(ent,item.own_key)
					s:Load("gfx/thread/Sleep_on_bed.anm2",true)
					s:Play("Idle",true)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = enums.Entities.Sleep_on_Bed,
Function = function(_,ent)
	if ent.Type == 5 and ent.Variant == enums.Entities.Sleep_on_Bed then
		local s = ent:GetSprite()
		s:Play("Idle",true)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = enums.Entities.Sleep_on_Bed,
Function = function(_,ent)
	if ent.Type == 5 and ent.Variant == enums.Entities.Sleep_on_Bed then
		local d = ent:GetData()
		local s = ent:GetSprite()
		if d[item.own_key.."pos"] then
			if s:IsPlaying("Jump") then
				local dis = (d[item.own_key.."pos"] - ent.Position) * 0.5
				ent.Velocity = auxi.apply_friction(dis,1)
			else
				ent.Position = ent.Position * 0.7 + d[item.own_key.."pos"] * 0.3
				ent.Velocity = Vector(0,0)
			end
		else
			ent:Remove()
		end
		d[item.own_key.."words"] = d[item.own_key.."words"] or {}
		if s:IsFinished("Jump") then
			if save.elses.has_speak_1 ~= true then
				local language = Options.Language
				if item.Words2[language] == nil then language = "zh" end
				local words = item.Words2[language][1]
				for i = 1,#words do
					local tab = {word = words[i].word,pword = words[i].pword,special = words[i].special,}
					table.insert(d[item.own_key.."words"],#d[item.own_key.."words"] + 1,tab)
				end
			end
			s:Play("Idle",true)
		end
		if s:IsPlaying("Idle") then
			if #d[item.own_key.."words"] > 0 and d[item.own_key.."lock"] ~= true then s:Play("Speak",true) 
			else
				d[item.own_key.."not_speaking_counter"] = (d[item.own_key.."not_speaking_counter"] or 0) + 1
				if d[item.own_key.."not_speaking_counter"] >= 180 then
					d[item.own_key.."not_speaking_counter"] = 0
					local language = Options.Language
					if item.Words2[language] == nil then language = "zh" end
					local words = item.Words2[language][2]
					local tbls = {}
					for i = 1,#words do
						if save.elses[item.own_key.."has_speak_"..tostring(i + 5)] ~= true then
							local tab = {tab = words[i],id = i,}
							table.insert(tbls,tab)
						end
					end
					if #tbls > 0 then
						local rnd = math.random(#tbls)
						local tbl = tbls[rnd]
						for i = 1,#(tbl.tab) do
							local tab = {word = tbl.tab[i].word,pword = tbl.tab[i].pword,special = tbl.tab[i].special,is_thinking = true,id = tbl.id,}
							if i == #(tbl.tab) then
								tab.special = function(ent,this) if this.id then save.elses[item.own_key.."has_speak_"..tostring(this.id + 5)] = true end end
							end
							table.insert(d[item.own_key.."words"],#d[item.own_key.."words"] + 1,tab)
						end
					else
					end
				end
			end
		end
		if s:IsPlaying("Speak") then
			if s:IsEventTriggered("Speak") then
				if #(d[item.own_key.."words"]) > 0 then
					local word = d[item.own_key.."words"][1].word
					local pword = d[item.own_key.."words"][1].pword
					local is_thinking = d[item.own_key.."words"][1].is_thinking
					if word and word ~= "" then
						if is_thinking then
							--gui.draw_ch_with_time_to_dispair(ent.Position + item.Talking_Pos_Offset + Vector(-(#word)/2,0),Vector(0,-40),word,60,{R = 0.3,G = 0.3,B = 0.3,})
							d[item.own_key.."lock"] = true Dialog_holder.add_word({data = {"以撒：",word},header = {sprite_name = "Isaac"},step_by = true,color = {[1] = Color(1,1,1,1),},all_alpha_multi = 0.5,Defaultcolor = Color(0.3,0.3,0.3,1),on_erase = function() if auxi.check_all_exists(ent) then d[item.own_key.."lock"] = nil end end,})
						else
							--gui.draw_ch_with_time_to_dispair(ent.Position + item.Talking_Pos_Offset + Vector(-(#word)/2,0),Vector(0,-40),word,60)
							d[item.own_key.."lock"] = true Dialog_holder.add_word({data = {"以撒：",word},header = {sprite_name = "Isaac"},step_by = true,on_erase = function() if auxi.check_all_exists(ent) then d[item.own_key.."lock"] = nil end end,})
						end
					end
					if pword and pword ~= "" then
						local player = Game():GetPlayer(0)
						--gui.draw_ch_with_time_to_dispair(player.Position + item.Talking_Pos_Offset + Vector(-(#pword)/2,0),Vector(0,-40),pword,60,{R = 0.82,G = 0.82,B = 0.94,})
						d[item.own_key.."lock"] = true Dialog_holder.add_word({data = {"小青：",pword},header = {sprite_name = "Qing"},step_by = true,on_erase = function() if auxi.check_all_exists(ent) then d[item.own_key.."lock"] = nil end end,})
					end
					if d[item.own_key.."words"][1].special then
						d[item.own_key.."words"][1].special(ent,d[item.own_key.."words"][1])
					end
					table.remove(d[item.own_key.."words"],1)
				end
			end
		end
		if s:IsFinished("Speak") or s:IsFinished("Happy") then
			if #(d[item.own_key.."words"]) > 0 and d[item.own_key.."lock"] ~= true then s:Play("Speak",true)
			else s:Play("Idle",true) end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = PickupVariant.PICKUP_BED,
Function = function(_,ent,offset)
	if ent.Type == 5 and ent.Variant == PickupVariant.PICKUP_BED then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local room = Game():GetRoom()
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ and d._Data[item.own_key].is_isaac_sleeping then
			if s:IsPlaying("Idle") then
				if d[item.own_key.."zzz"] == nil then
					d[item.own_key.."zzz"] = Sprite()
					d[item.own_key.."zzz"]:Load("gfx/thread/Sleep_on_bed.anm2",true)
					d[item.own_key.."zzz"]:Play("zzz",true)
					d[item.own_key.."zzz_dpos"] = Vector(math.random(20) - 10,math.random(20) - 10)
				end
				d[item.own_key.."zzz"]:Render(Isaac.WorldToScreen(ent.Position + d[item.own_key.."zzz_dpos"]),Vector(0,0),Vector(0,0))
				if Game():IsPaused() == true then
				else
					if Game():GetFrameCount() % 2 == 1 then
						d[item.own_key.."zzz"]:Update()
						if d[item.own_key.."zzz"]:IsEventTriggered("Recharge") then
							d[item.own_key.."zzz_dpos"] = Vector(math.random(20) - 10,math.random(20) - 10)
						end
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = PickupVariant.PICKUP_BED,
Function = function(_,ent)
	if ent.Type == 5 and ent.Variant == PickupVariant.PICKUP_BED then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local room = Game():GetRoom()
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ and d._Data[item.own_key].is_isaac_sleeping then
			if s:IsFinished("Wakeup") then
				s:Play("Idle2",true)
				delay_buffer.addeffe(function(params)
					local ent = params.ent
					if ent and ent:Exists() and ent:IsDead() == false then
						if ent:GetData()._Data and ent:GetData()._Data[item.own_key]  then
							ent:GetData()._Data[item.own_key].is_isaac_sleeping = nil
							ent:GetData()._Data[item.own_key].is_isaacs_bed = true
						end
					end
				end,{ent = ent,},30)
				local q = Isaac.Spawn(5,enums.Entities.Sleep_on_Bed,0,ent.Position,Vector(0,0),nil)
				d[item.own_key.."mimic_isaac"] = q
				local d = q:GetData()
				local pos = room:FindFreePickupSpawnPosition(Game():GetPlayer(0).Position,10,true)
				if (pos - ent.Position):Length() < 50 then pos = Vector(160,160) end
				d[item.own_key.."pos"] = pos
				local s = q:GetSprite()
				s:Play("Jump",true)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil,
Function = function(_,ent,col,low)
	if ent.Type == 5 and ent.Variant == PickupVariant.PICKUP_BED then
		if col.Type == 1 then
			local d = ent:GetData()
			local s = ent:GetSprite()
			local succ = consistance_holder.try_check_entity(ent,item.own_key)
			if succ then
				if d._Data[item.own_key].is_isaac_sleeping then
					if s:IsPlaying("Idle") then
						s:Play("Wakeup")
					end
					return false
				elseif d._Data[item.own_key].is_isaacs_bed then
					if d[item.own_key.."mimic_isaac"] and d[item.own_key.."mimic_isaac"]:Exists() and d[item.own_key.."mimic_isaac"]:IsDead() == false then
						if save.elses[item.own_key.."has_speak_"..tostring(2)] ~= true then
							save.elses[item.own_key.."has_speak_"..tostring(2)] = true
							local d2 = d[item.own_key.."mimic_isaac"]:GetData()
							if d2[item.own_key.."words"] == nil then d2[item.own_key.."words"] = {} end
							local language = Options.Language
							if item.Words[language] == nil then language = "zh" end
							local words = item.Words2[language][4] 
							for i = #words,1,-1 do
								local tab = {word = words[i].word,pword = words[i].pword,special = words[i].special,is_thinking = true,}
								table.insert(d2[item.own_key.."words"],1,tab)
							end
						end
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	local level = g.game:GetLevel()
	local room = g.game:GetRoom()
	local desc = level:GetCurrentRoomDesc()
	local levelStage = level:GetStage()
	local roomType = room:GetType()
	local difficulty = g.game.Difficulty
	
	if Isaac.GetChallenge() > 0 or g.game:GetVictoryLap() > 0 or (item.should_end and item.should_end == true) then
		return
	end
	
	local player = Game():GetPlayer(0)
	if player:GetPlayerType() ~= enums.Players.wq then return end
	
	if item.end1_has_start then
		
	else
		if difficulty <= Difficulty.DIFFICULTY_HARD then
			local stageType = level:GetStageType()
			
			if levelStage == LevelStage.STAGE4_1 and level:GetCurses() & LevelCurse.CURSE_OF_LABYRINTH > 0 then
				levelStage = levelStage + 1
			end
			
			if levelStage == LevelStage.STAGE8 and roomType == RoomType.ROOM_DUNGEON then
				if item.target_Beast == nil or item.target_Beast:Exists() == false then
					for _, beast in ipairs(Isaac.FindByType(EntityType.ENTITY_BEAST, 0)) do
						item.target_Beast = beast
						break
					end
				end
				if item.target_Beast == nil or item.target_Beast:Exists() == false then return end
				
				local sprite = item.target_Beast:GetSprite()
				
				if sprite:IsPlaying("Death") and sprite:GetFrame() == 60 then
					item.should_end = true
					item.target_Beast:AddEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE)
					start_end1()
				end
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
		if args[1] and args[1] == "end" then
			if args[2] and args[2] == "1" then
				start_end1()
			end
		end
	end
end,
})

return item
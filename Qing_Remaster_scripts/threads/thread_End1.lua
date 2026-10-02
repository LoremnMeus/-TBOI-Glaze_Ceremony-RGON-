local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Dialog_holder = require("Qing_Remaster_scripts.others.Dialog_holder")

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
	-- Ending1 captions live in story/prologue/ending_defs.lua (authoritative).
	-- Words2 = Home / bedroom Isaac dialogue only.
	Words2 = {
		zh = {
			[1] = {
				{word = "唔……",},
				{pword = "醒醒。",},
				{word = "……谁？",},
				{word = "你为什么会在我家？",},
				{pword = "……",},
				{pword = "看来没有找错。",},
				{word = "什么没有找错？",},
				{pword = "没什么。",},
				{pword = "你待在这里。",},
				{word = "等等，你要去哪？",},
				{pword = "处理一点麻烦。",},
				{word = "外面很危险……",},
				{pword = "我知道。",},
				{pword = "所以你别出来。", special = function()
					local ok, home = pcall(require, "Qing_Remaster_scripts.story.prologue.home_encounter")
					if ok and home and home.on_dialog_completed then
						home.on_dialog_completed()
					else
						save.elses.has_speak_1 = true
					end
				end,},
			},
			[2] = {
				{
					{word = "还是有点困……",},
				},
				{
					{word = "妈妈那天好生气啊，她出门的时候把门都摔坏了。",},
					{word = "她还要多久才会回来呢？",},
				},
				{
					{word = "对不起，妈妈……",},
					{word = "我不是故意那样画的……",},
				},
				{
					{word = "刚才那个人到底是谁啊……",},
				},
				{
					{word = "她看起来一点都不害怕。",},
				},
				{
					{word = "外面又有奇怪的声音了……",},
				},
				{
					{word = "好像有点饿了",},
					{word = "可是家里只剩狗粮能吃了",},
					{word = "唔唔……等会儿还是再躺一会吧",},
				},
			},
			[4] = {
				{word = "等下……",},
				{word = "那是我的床……",},
			},
		},
		en = {
			[1] = {
				{word = "Nn...",},
				{pword = "Wake up.",},
				{word = "...Who?",},
				{word = "Why are you in my house?",},
				{pword = "...",},
				{pword = "Looks like I wasn't wrong.",},
				{word = "Wrong about what?",},
				{pword = "Nothing.",},
				{pword = "Stay here.",},
				{word = "Wait—where are you going?",},
				{pword = "To deal with a problem.",},
				{word = "It's dangerous out there...",},
				{pword = "I know.",},
				{pword = "So don't come out.", special = function()
					local ok, home = pcall(require, "Qing_Remaster_scripts.story.prologue.home_encounter")
					if ok and home and home.on_dialog_completed then
						home.on_dialog_completed()
					else
						save.elses.has_speak_1 = true
					end
				end,},
			},
			[2] = {
				{
					{word = "Still a bit sleepy...",},
				},
				{
					{word = "Mom was so angry that day. She slammed the door hard when she left.",},
					{word = "How much longer until she comes back?",},
				},
				{
					{word = "I'm sorry, Mom...",},
					{word = "I didn't mean to draw that...",},
				},
				{
					{word = "Who even was that person just now...",},
				},
				{
					{word = "She didn't look scared at all.",},
				},
				{
					{word = "There are strange sounds outside again...",},
				},
				{
					{word = "I think I'm a bit hungry",},
					{word = "But there's only dog food left to eat at home",},
					{word = "Hmm... maybe I'll just lie down a bit more",},
				},
			},
			[4] = {
				{word = "Wait...",},
				{word = "That's my bed...",},
			},
		},
	},
}

local function enqueue_dialog_entry(dst, src, extra)
	if type(dst) ~= "table" or type(src) ~= "table" then return end
	if src.word == nil and src.pword == nil and src.special == nil and src.pause_frames == nil then
		return
	end
	local tab = {
		word = src.word,
		pword = src.pword,
		special = src.special,
		pause_frames = src.pause_frames,
	}
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			tab[k] = v
		end
	end
	table.insert(dst, #dst + 1, tab)
end

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

function start_end1(opts)
	opts = opts or {}
	local ok, ending_scene = pcall(require, "Qing_Remaster_scripts.story.prologue.ending_scene")
	if ok and ending_scene and ending_scene.start then
		return ending_scene.start(opts)
	end
	return false, "ending_scene_missing"
end

function item.finish_end1()
	local ok, ending_scene = pcall(require, "Qing_Remaster_scripts.story.prologue.ending_scene")
	if ok and ending_scene and ending_scene.finish then
		return ending_scene.finish()
	end
	return false
end

-- Legacy cutscene path retired: Update/render live in prologue/ending_scene.lua.
-- Keep empty shells so old callback registrations remain harmless.
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_,name)
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent, amt, flag, source, cooldown)
	local ok, ending_scene = pcall(require, "Qing_Remaster_scripts.story.prologue.ending_scene")
	if ok and ending_scene and ending_scene.is_active and ending_scene.is_active() then
		return false
	end
end,
})

--- Idempotent: convert a vanilla bed into Sleep_on_bed presentation when Story allows.
--- Gate is home.should_replace_bed(); callers must not widen the gate here.
function item.apply_sleeping_isaac_to_bed(ent)
	if not ent or not ent.Exists or not ent:Exists() then return false end
	if ent.Type ~= EntityType.ENTITY_PICKUP or ent.Variant ~= PickupVariant.PICKUP_BED then
		return false
	end
	local ok, home = pcall(require, "Qing_Remaster_scripts.story.prologue.home_encounter")
	if not (ok and home and home.should_replace_bed and home.should_replace_bed()) then
		return false
	end
	local d = ent:GetData()
	local s = ent:GetSprite()
	d._Data = d._Data or {}
	d._Data[item.own_key] = d._Data[item.own_key] or {}
	if consistance_holder.try_check_entity(ent, item.own_key)
		and d._Data[item.own_key].is_isaac_sleeping then
		-- Already marked; refresh sprite only.
		s:Load("gfx/thread/Sleep_on_bed.anm2", true)
		s:Play("Idle", true)
		return true
	end
	d._Data[item.own_key].is_isaac_sleeping = true
	consistance_holder.try_hold_entity(ent, item.own_key)
	s:Load("gfx/thread/Sleep_on_bed.anm2", true)
	s:Play("Idle", true)
	return true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_BED,
Function = function(_,ent)
	item.apply_sleeping_isaac_to_bed(ent)
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
					enqueue_dialog_entry(d[item.own_key.."words"], words[i])
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
							enqueue_dialog_entry(d[item.own_key.."words"], tbl.tab[i], {
								is_thinking = true,
								id = tbl.id,
							})
							local last = d[item.own_key.."words"][#d[item.own_key.."words"]]
							if last and i == #(tbl.tab) then
								last.special = function(ent, this)
									if this.id then
										save.elses[item.own_key.."has_speak_"..tostring(this.id + 5)] = true
									end
								end
							end
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
							if item.Words2[language] == nil then language = "zh" end
							local words = item.Words2[language][4]
							for i = #words, 1, -1 do
								local src = words[i]
								if type(src) == "table"
									and (src.word ~= nil or src.pword ~= nil or src.special ~= nil or src.pause_frames ~= nil) then
									table.insert(d2[item.own_key.."words"], 1, {
										word = src.word,
										pword = src.pword,
										special = src.special,
										pause_frames = src.pause_frames,
										is_thinking = true,
									})
								end
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
	local levelStage = level:GetStage()
	local roomType = room:GetType()
	local difficulty = g.game.Difficulty

	if Isaac.GetChallenge() > 0 or g.game:GetVictoryLap() > 0 or item.should_end == true then
		return
	end

	local player = Game():GetPlayer(0)
	if player:GetPlayerType() ~= enums.Players.wq then return end

	local ok_end, ending_scene = pcall(require, "Qing_Remaster_scripts.story.prologue.ending_scene")
	if ok_end and ending_scene and ending_scene.is_active and ending_scene.is_active() then
		return
	end

	if difficulty > Difficulty.DIFFICULTY_HARD then return end

	if levelStage == LevelStage.STAGE4_1 and level:GetCurses() & LevelCurse.CURSE_OF_LABYRINTH > 0 then
		levelStage = levelStage + 1
	end

	if levelStage ~= LevelStage.STAGE8 or roomType ~= RoomType.ROOM_DUNGEON then
		return
	end

	local ok_story, story = pcall(require, "Qing_Remaster_scripts.story.story_state")
	if not ok_story or not story then return end

	local ok_home, home = pcall(require, "Qing_Remaster_scripts.story.prologue.home_encounter")
	if ok_home and home and home.ensure_past_optional then
		home.ensure_past_optional()
	end

	if story.get_current_node("prologue") ~= "prologue.beast_battle" then
		return
	end

	if item.target_Beast == nil or item.target_Beast:Exists() == false then
		for _, beast in ipairs(Isaac.FindByType(EntityType.ENTITY_BEAST, 0)) do
			item.target_Beast = beast
			break
		end
	end
	if item.target_Beast == nil or item.target_Beast:Exists() == false then return end

	local sprite = item.target_Beast:GetSprite()
	local handoff = 60
	local ok_defs, edefs = pcall(require, "Qing_Remaster_scripts.story.prologue.ending_defs")
	if ok_defs and edefs and edefs.BEAST_HANDOFF_FRAME then
		handoff = edefs.BEAST_HANDOFF_FRAME
	end

	if sprite:IsPlaying("Death") and sprite:GetFrame() == handoff then
		item.should_end = true
		item.target_Beast:AddEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE)
		-- Story truth first; presentation second.
		if story.on_prologue_beast_defeated then
			story.on_prologue_beast_defeated()
		end
		start_end1({preview = false})
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
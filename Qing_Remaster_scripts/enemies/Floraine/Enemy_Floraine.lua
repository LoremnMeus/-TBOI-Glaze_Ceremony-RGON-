local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local Dialog_holder = require("Qing_Remaster_scripts.others.Dialog_holder")
local Damage_holder = require("Qing_Remaster_scripts.others.Damage_holder")
local board = require("Qing_Remaster_scripts.enemies.Floraine.Enemy_chess_board")
local pawn = require("Qing_Remaster_scripts.enemies.Floraine.Enemy_chess_pawn")
local staff = require("Qing_Remaster_scripts.enemies.Floraine.Enemy_chess_staff")

local item = {
	ToCall = {},
	post_ToCall = {},
	enemy = enums.Enemies.Floraine,
	own_key = "Enemies_Floraine_",
	word_list = {
		zh = {
			[0] = {
				"芙拉：",
			},
			[1] = {
				{
					"奇怪....",
					"我好像不应该出现在这里....",
				},
			},
			[2] = {
				{
					"小青？",
					"是你吗？",
					"琉璃之前告诉我说他正在找你呢！",
				},
				{
					"不对！你不是小青！",
					"你只是拿了他的帽子和小刀的其他人。",
					"奇怪...",
				},
			},
			[3] = {
				{
					"小青？你！你怎么....",
					"不对。小青已经...",
					"哎...",
				},
			},
			[4] = {
				{
					"欢迎来到我的棋盘。",
					"这里非常安静，没有人能打扰我们对弈。",
				},
				{
					"我有一张混沌卡",
					"只要你战胜我，你就能拿到它",
					"当然，前提是你得先在我的棋盘中活下来！",
					"事先说好，我不打算控制那些棋兵。它们将会按规则在棋盘里自由移动。",
					"在被它们吞没前战胜我你就过关了。",
				},
			},
			[5] = {
				{
					"橡皮擦？",
					"别以为这种诡计可以生效啊喂！",
				},
			},
			[6] = {
				{
					"你确实有两把刷子..",
					"至少DPS已经足够战胜这些小兵了",
				},
				{
					"我将兑现我的诺言。",
					"作为胜者，你可以从以下五种物品中挑一样带走。",
				},
				{
					"如果你想找到琉璃，就带走混沌卡吧",
					"我会替你确保，本局游戏中一定存在一只基甸石人",
					"另外，祝你今天好运。",
				},
			},
			[7] = {			--受到极高伤害
				{
					"不是！你这伤害有问题！",
					"怎么可能这么痛啊！",
				},
			},
			[8] = {			--二次战斗战败
				{
					"你又战胜了我！",
					"这意味着即使我动用全力，也不是你的对手了！",
					"我不清楚你用了什么把戏",
					"还是说你真的有这样强大。",
				},
				{
					"事到如今，还望你能仔细听听我的忠告。",
					"琉璃的行事混乱而毫无计划",
					"而他的主人更是荒谬异常",
				},
				{
					"你即使再强大，也很难正面战胜他们",
					"所以劝你尽早做好准备",
					"比如，筹划一次偷袭",
				},
			},
			[9] = {
				{
					"加油！",
					"你已经打掉我一半血了！",
					"幸好这里是第四层，我没有二阶段",
				},
			},
		},
		en = {
			[0] = {
				"Floraine:",
			},
			[1] = {
				{
					"Strange...",
					"I don't think I should be here...",
				},
			},
			[2] = {
				{
					"Qing?",
					"Is that you?",
					"Glaze told me before that he was looking for you!",
				},
				{
					"No! You are a wrong person!",
					"You're just the other person taking his hat and knife.",
					"So weird...",
				},
			},
			[3] = {
				{
					"Qing? How can it be?",
					"...",
				},
			},
			[4] = {
				{
					"Welcome to my chessboard",
					"It's very quiet here, no one can disturb us playing games.",
				},
				{
					"I have a Chaos Card",
					"As long as you defeat me, you can get it",
					"Of course, the prerequisite is that you have to survive in my chessboard first!",
					"As agreed beforehand, I have no intention of controlling those chess players.",
					"They will move freely on the chessboard according to the rules.",
					"If you defeat me before they engulf you, you will pass my game.",
				},
			},
			[5] = {
				{
					"Eraser?",
					"Don't think this kind of trick can work!",
				},
			},
			[6] = {
				{
					"You do have something..",
					"At least your DPS is enough to defeat these pawns",
				},
				{
					"I will fulfill my promise.",
					"As a winner, you can choose one of the following five items to take away.",
				},
				{
					"If you want to find Glaze, take the Chaos Card with you",
					"I will ensure for you that there must be a Gideon Stone Man in this game",
					"Also, good luck to you today.",
				},
			},
			[7] = {			--受到极高伤害
				{
					"It's so pain!",
					"I'll leave here now.",
				},
			},
			[8] = {			--二次战斗战败
				{
					"You have defeated me again!",
					"This means that even if I use all my strength, I won't be your match anymore!",
					"I'm not sure what trick you used",
					"Or you really have such strength",
				},
				{
					"At this point, I hope you can listen carefully to my advice.",
					"Glaze's actions were chaotic and unplanned",
					"And his master is even more absurd and abnormal",
				},
				{
					"Even if you are strong, it is difficult for you to defeat them head-on",
					"So I advise you to prepare as soon as possible",
					"For example, planning a surprise attack",
				},
			},
			[9] = {
				{
					"Come on!",
					"You've already knocked out half of my lifepoint!",
					"Fortunately, this is the fourth level, I don't have a second stage.",
				},
			},
		},
	},
	summon_list = {		--生成位置列表
		[0] = {
			{Vector(80,40),Vector(80,-40),Vector(40,80),Vector(-40,80),Vector(-80,40),Vector(-80,-40),Vector(40,-80),Vector(-40,-80),},
		},
		[1] = {
			{Vector(40,40),Vector(40,80),Vector(40,0),Vector(40,-40),Vector(40,-80),},
			{Vector(-40,40),Vector(-40,80),Vector(-40,0),Vector(-40,-40),Vector(-40,-80),},
			{Vector(40,40),Vector(80,40),Vector(0,40),Vector(-40,40),Vector(-80,40),},
			{Vector(40,-40),Vector(80,-40),Vector(0,-40),Vector(-40,-40),Vector(-80,-40),},
		},
		[2] = {
			{Vector(40,40),Vector(40,-40),Vector(-40,-40),Vector(-40,40),},
			{Vector(80,80),Vector(80,-80),Vector(-80,-80),Vector(-80,80),},
			{Vector(80,0),Vector(0,80),Vector(-80,0),Vector(0,-80),},
			{Vector(40,0),Vector(0,40),Vector(-40,0),Vector(0,-40),},
		},
		[3] = {
			{Vector(40,40),Vector(40,-40),Vector(-40,-40),Vector(-40,40),},
			{Vector(80,0),Vector(0,80),Vector(-80,0),Vector(0,-80),},
		},
		[4] = {
			{Vector(40,40),Vector(40,80),Vector(40,0),Vector(40,-40),Vector(40,-80),Vector(40,-120),Vector(40,120),},
			{Vector(-40,40),Vector(-40,80),Vector(-40,0),Vector(-40,-40),Vector(-40,-80),Vector(-40,-120),Vector(-40,120),},
			{Vector(40,40),Vector(80,40),Vector(0,40),Vector(-40,40),Vector(-80,40),Vector(-120,40),Vector(120,40),},
			{Vector(40,-40),Vector(80,-40),Vector(0,-40),Vector(-40,-40),Vector(-80,-40),Vector(-120,-40),Vector(120,-40),},
			{Vector(40,40),Vector(40,-40),Vector(-40,-40),Vector(-40,40),Vector(-80,80),Vector(-80,-80),Vector(80,-80),Vector(80,80),},
			{Vector(80,80),Vector(80,-80),Vector(-80,-80),Vector(-80,80),Vector(-80,0),Vector(80,0),Vector(0,-80),Vector(0,80),},
			{Vector(80,0),Vector(0,80),Vector(-80,0),Vector(0,-80),Vector(-40,0),Vector(0,-40),},
			{Vector(40,0),Vector(0,40),Vector(-40,0),Vector(0,-40),Vector(-80,0),Vector(0,-80),},
		},
	},
	strategies = {		--攻击策略列表
		[1] = {anim = "Attack",},
		[2] = {anim = "Attack2",},
		[3] = {anim = "Attack3",},
		[4] = {anim = "Attack4",},
	},
	Swapper = {
		["Appear"] = "Idle",
		["Attack"] = "Idle",
		["Attack2"] = "Idle",
		["Attack3"] = "Idle",
		["Attack4"] = "Idle",
	},
}
--这个敌人的代码写得太糟糕了，现在需要完全重构一次。
function item.add_word(ent,id)
	local d = ent:GetData()
	for u,v in pairs(item.get_word(id)) do table.insert(d[item.own_key.."effect"].words,v) end
end

function item.get_word(id,force)
	local language = Options.Language
	if item.word_list[language] == nil then language = "zh" end
	if force then return auxi.copy(item.word_list[language][id]) end
	return item.word_list[language][id]
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite() local d = ent:GetData()
		ent.State = 0
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS
		d[item.own_key.."effect"] = {pos = ent.Position,}
		d[item.own_key.."effect"].words = {}
		ent:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
		if auxi.have_player(enums.Players.wq) then item.add_word(ent,2)
		elseif auxi.have_player(enums.Players.Spwq) then item.add_word(ent,3) end
		if item.should_spawn() then item.add_word(ent,4)
		else item.add_word(ent,1) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,	
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite() local d = ent:GetData()
		local anim = s:GetAnimation()
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		if s:IsFinished("Leave") then ent:Remove() return end
for i = 1,1 do 
		if anim == "Idle" then
			if #(d[item.own_key.."effect"].words or {}) > 0 then
				for u,v in pairs(d[item.own_key.."effect"].words) do 
					local data = item.get_word(0,true) for uu,vv in pairs(v) do table.insert(data,vv) end
					Dialog_holder.add_word({data = data,header = {sprite_name = "Floraine"},step_by = true,}) 
				end
				d[item.own_key.."effect"].words = {}
				s:Play("Speak",true) break
			end
			if ent.HitPoints < ent.MaxHitPoints * 0.5 and d[item.own_key.."effect"].c1 ~= true then 
				d[item.own_key.."effect"].c1 = true
				if item.should_spawn() then 
					for u,v in pairs(item.get_word(9)) do 
						local data = item.get_word(0,true) for uu,vv in pairs(v) do table.insert(data,vv) end 
						local datadialog = {data = data,header = {sprite_name = "Floraine"},step_by = true,}
						Dialog_holder.add_word(datadialog) 
					end 
				end
			end
			if d[item.own_key.."effect"].should_leave then
				if (Dialog_holder.word_list[1] or {})[item.own_key.."id"] == 3 then item.spawn_reward(ent.Position) Dialog_holder.word_list[1][item.own_key.."id"] = nil save.elses.Floraine_end = true end
				if Dialog_holder.is_clear() then s:Play("Leave",true) end
				break
			end
			if d[item.own_key.."effect"].delay then d[item.own_key.."effect"].delay = d[item.own_key.."effect"].delay - 1 if d[item.own_key.."effect"].delay <= 0 then d[item.own_key.."effect"].delay = nil end end
			if d[item.own_key.."effect"].delay == nil then
				local n_piece = auxi.getothers(n_ent,996,enums.Enemies.chess_piece)
				local tbl = {{id = 2,weigh = 10,},}
				if #n_piece == 0 then table.insert(tbl,{id = 1,weigh = 100,}) 
				else table.insert(tbl,{id = 1,weigh = math.max(0,50 - 5 * (#n_piece)),}) end 
				if #n_piece > 3 then table.insert(tbl,{id = 4,weigh = 20,}) end
				if #n_piece > 5 then table.insert(tbl,{id = 3,weigh = 5,}) end
				local rnd = auxi.random_in_weighed_table(tbl)
				local sinfo = item.strategies[rnd.id]
				s:Play(sinfo.anim,true) auxi.check_if_any(sinfo.extra,ent,item)
				d[item.own_key.."effect"].delay = 20 + math.random(20)
			end
		end
		if anim == "Speak" then
			if Dialog_holder.is_clear() then 
				if (MusicManager():GetCurrentMusicID() ~= 24) then
					local music = MusicManager()
					music:Play(24, 1)
					music:UpdateVolume()
				end
				s:Play("Idle",true) break 
			end
		end
		if anim == "Attack" then
			if s:IsEventTriggered("Call") then 		--基础的召唤模式
				local rnd2 = auxi.choose(0,1,2,3,4)
				local rnd3 = math.random(#item.summon_list[rnd2])
				for u,v in pairs(item.summon_list[rnd2][rnd3]) do
					local rnd = auxi.choose(1,2,3,4,5)
					local q = pawn.generate_pawn(rnd,ent.Position + v,Vector(0,0),{spawner = ent,})
				end
			end
			if s:IsEventTriggered("Ask") then 		--开启棋盘
				if d[item.own_key.."effect"].ask1 == nil then d[item.own_key.."effect"].ask1 = true 
					board.start_(ent.Position)
					local room = Game():GetRoom()
					for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
						local door = room:GetDoor(slot)
						if door then door:Close() end
					end
				end
			end
		end
		if anim == "Attack2" then			--杖击
			if s:IsEventTriggered("Call") then 
				local rnd = math.random(5)
				for i = 1,rnd do
					delay_buffer.addeffe(function(params) 
						local target = auxi.get_acceptible_target(ent)
						staff.generate_staff(target.Position,target.Velocity,{spawner = ent,target = target,}) 
					end,{},(i - 1) * 20)
				end
				d[item.own_key.."effect"].attack2delay = rnd * 20 + 15
			end
			if s:GetFrame() == 32 then
				if (d[item.own_key.."effect"].attack2delay or 0) > 0 then
					d[item.own_key.."effect"].attack2delay = d[item.own_key.."effect"].attack2delay - 1 s:SetFrame(31)
				end
			end
		end
		if anim == "Attack3" then			--回血
			if s:IsEventTriggered("Call") then 
				local n_piece = auxi.getothers(n_ent,996,enums.Enemies.chess_piece)
				for u,v in pairs(n_piece) do
					v.HitPoints = v.MaxHitPoints
					v:SetColor(Color(1,1,1,1,0.5,0,0),60,10,true,false)
				end
			end
		end
		if anim == "Attack4" then			--快速施法
			if s:IsEventTriggered("Call") then 
				local target = auxi.get_acceptible_target(ent)
				local rnd = auxi.choose(1,2,3,4,5)
				local q = pawn.generate_pawn(rnd,target.Position,Vector(0,0),{spawner = ent,})
			end
		end
		if s:IsFinished(anim) then
			local tg = auxi.check_if_any(item.Swapper[anim],ent) or "Idle"
			s:Play(tg,true)
		end
end
		ent.Velocity = ((d[item.own_key.."effect"].pos or ent.Position) - ent.Position) * 0.2
		ent.Velocity = auxi.apply_friction(ent.Velocity,1)
	end
end,
})

function item.should_spawn()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local stageType = level:GetStageType()
	local stage = Game():GetLevel():GetStage()
	if desc.Data.Type == RoomType.ROOM_DEFAULT and desc.Data.Variant >= 23752 and desc.Data.Variant <= 23762 and (stage == LevelStage.STAGE2_1 or stage == LevelStage.STAGE2_2) and stageType >= StageType.STAGETYPE_REPENTANCE then return true 
	else return false end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	if item.should_spawn() and room:IsFirstVisit() and save.elses[item.own_key.."has_seen"] ~= true then
		save.elses[item.own_key.."has_seen"] = true
		local q = Isaac.Spawn(996,item.enemy,0,Vector(320,250),Vector(0,0),nil)
		room:SetWallColor(Color(0.5, 0.5, 0.5, 1, -0.1, -0.1, -0.1))
		if (MusicManager():GetCurrentMusicID() ~= 116) then
			local music = MusicManager()
			music:Play(116, 1)
			music:UpdateVolume()
		end
		local d = q:GetData()
		q.MaxHitPoints = 500
		q.HitPoints = 500
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 996,
Function = function(_,ent,amt,flag,source,cooldown)
	if ent.Variant == item.enemy then
		local d = ent:GetData()
		if not Dialog_holder.is_clear() then return false end
		if d[item.own_key.."effect"].should_leave then return false end
		if amt > 50000 then ent.HitPoints = 1 return false end
		--if ent:HasMortalDamage() then d[item.own_key.."effect"].should_leave = true ent.HitPoints = 1 return false end
		local total_damage = Damage_holder.on_damage(ent,amt,flag,source,cooldown)
		if total_damage > ent.HitPoints then 
			d[item.own_key.."effect"].should_leave = true 
			for u,v in pairs(item.get_word(6)) do 
				local data = item.get_word(0,true) for uu,vv in pairs(v) do table.insert(data,vv) end 
				local datadialog = {data = data,header = {sprite_name = "Floraine"},step_by = true,} datadialog[item.own_key.."id"] = u 
				Dialog_holder.add_word(datadialog) 
			end 
			local n_piece = auxi.getothers(n_ent,996,enums.Enemies.chess_piece) for u,v in pairs(n_piece) do v:Kill() end
			ent.HitPoints = 1 return false 
		end
	end
end,
})

function item.spawn_reward(pos)
	pos = pos or Vector(200,200)
	local to_award = {}
	table.insert(to_award,{Variant = 100,SubType = 0,Type = 5,weigh = 10,})
	table.insert(to_award,{Variant = 100,SubType = 0,Type = 5,weigh = 10,})
	table.insert(to_award,{Variant = 100,SubType = 0,Type = 5,weigh = 10,})
	table.insert(to_award,{Variant = 100,SubType = 0,Type = 5,weigh = 10,})
	table.insert(to_award,{Variant = 100,SubType = 0,Type = 5,weigh = 10,})
	table.insert(to_award,{Variant = 100,SubType = 0,Type = 5,weigh = 10,})
	table.insert(to_award,{Variant = 100,SubType = 619,Type = 5,weigh = 1,})
	table.insert(to_award,{Variant = 100,SubType = 173,Type = 5,weigh = 1,})
	table.insert(to_award,{Variant = 100,SubType = 156,Type = 5,weigh = 1,})
	table.insert(to_award,{Variant = 100,SubType = 206,Type = 5,weigh = 1,})
	table.insert(to_award,{Variant = 100,SubType = 233,Type = 5,weigh = 1,})
	table.insert(to_award,{Variant = 300,SubType = 23,Type = 5,weigh = 3,})
	table.insert(to_award,{Variant = 300,SubType = 24,Type = 5,weigh = 3,})
	table.insert(to_award,{Variant = 300,SubType = 25,Type = 5,weigh = 3,})
	table.insert(to_award,{Variant = 300,SubType = 26,Type = 5,weigh = 3,})
	table.insert(to_award,{Variant = 300,SubType = 31,Type = 5,weigh = 3,})
	table.insert(to_award,{Variant = 300,SubType = 43,Type = 5,weigh = 3,})
	table.insert(to_award,{Variant = 300,SubType = 78,Type = 5,weigh = 3,})
	table.insert(to_award,{Variant = 300,SubType = 80,Type = 5,weigh = 3,})
	table.insert(to_award,{Variant = 300,SubType = enums.Cards.Glaze_dice_shard,Type = 5,weigh = 3,})
	table.insert(to_award,{Variant = 40,SubType = 7,Type = 5,weigh = 5,})
	table.insert(to_award,{Variant = 57,SubType = 0,Type = 5,weigh = 5,})
	table.insert(to_award,{Variant = 90,SubType = 4,Type = 5,weigh = 1,})
	table.insert(to_award,{Variant = 70,SubType = 14,Type = 5,weigh = 2,})
	table.insert(to_award,{Variant = 70,SubType = 2062,Type = 5,weigh = 3,})
	local chaos_id = math.random(5)
	local ndx = option_index_holder.find_a_new_index()
	local room = Game():GetRoom()
	for i = 1,5 do
		local ent = {Variant = 100,SubType = 0,Type = 5,}
		if chaos_id == i then ent = {Variant = 300,SubType = 42,Type = 5,}
		else
			local ent,u = auxi.random_in_weighed_table(to_award)
			table.remove(to_award,u)
		end
		local q = Isaac.Spawn(ent.Type,ent.Variant,ent.SubType,room:FindFreePickupSpawnPosition(pos + Vector(-240 + i * 80,100),10,true),Vector(0,0),nil):ToPickup()
		q.OptionsPickupIndex = ndx
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else save.elses[item.own_key.."has_seen"] = false end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."has_seen"] = false
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,	--防止某些奇怪情况
Function = function(_,ent,col,low)
	if (ent.Variant == 45 or ent.Variant == 9) and col.Variant == item.enemy and col.Type == 996 then
		return false
	end
end,
})

--l local q = Isaac.Spawn(996,23751,0,Vector(400,300),Vector(0,0),nil);local s = q:GetSprite();s:ReplaceSpritesheet(0, "gfx/boss/Floraine/pawn_pieces.png");s:LoadGraphics();print(q.Mass);

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local console_holder = require("Qing_Remaster_scripts.others.Console_holder")
local Dialog_holder = require("Qing_Remaster_scripts.others.Dialog_holder")
local Boss_Qing = require("Qing_Remaster_scripts.bosses.Boss_Qing")
local AI = require("Qing_Remaster_scripts.bosses.Boss_All")
local grid_doors = require("Qing_Remaster_scripts.grids.grid_doors")
local grid_trapdoor = require("Qing_Remaster_scripts.grids.grid_trapdoor")
local Nil = require("Qing_Remaster_scripts.others.Nil_holder")
local Screen_Filter = require("Qing_Remaster_scripts.others.Screen_Filter")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	own_key = "Thread_End2_2_",
	glaze_info = {
		["Idle"] = {
			{frame = 0,offset = 0,},
			{frame = 2,offset = 5,},
			{frame = 4,offset = 5,},
			{frame = 9,offset = 2,},
			{frame = 10,offset = -3,},
			{frame = 11,offset = -8,},
			{frame = 13,offset = -12,},
			{frame = 21,offset = -12,},
			{frame = 29,offset = 0,},
			total = 29,
		},
	},
}
item.word_list = {
	zh = {
		[1] = {
			{
				data = {
					"以撒：",
					{word = "啊！是琉璃医生！",line_inside_delay = 20,},
					"医生，小青怎么样了？",
				},
				header = {sprite_name = "Isaac",},
			},
			{
				data = {
					"琉璃：",
					{word = "我很高兴你能来。事实上，你做得非常好！",colorful = 0,},
					{word = "这里是\"他界\"，易碎的世界边际。",colorful = 10,},
					{word = "唯有像你这样的好孩子",colorful = 20,},
					{word = "才能借助那些碎片的力量到达这里。",colorful = 30,},
				},
				header = {sprite_name = "Glaze_Doctor",},
			},
			{
				data = {
					"以撒：",
					"等等！琉璃医生",
					{word = "你不是说，要用这些碎片来拯救小青吗？",on_finish = function() 
						local ent = item.get_glaze()
						local d = ent:GetData()
						d[item.own_key.."control"] = {}
						AI.move2pos(ent,Game():GetRoom():GetGridPosition(97),150)
					end,},
				},
				header = {sprite_name = "Isaac",},
			},
			{
				data = {
					"琉璃：",
					{word = "小青？呵呵..",colorful = 0,},
					{word = "他恢复得很快，甚至完全等不及这些碎片了",colorful = 10,line_inside_delay = 20,},
					{word = "其实你马上就能见到他了",colorful = 20,},
					{word = "相比刺客，有一个新身份更适合他。",colorful = 30,},
				},
				header = {sprite_name = "Glaze_Doctor",},
			},
			{
				data = {
					"以撒：",
					"适合？",
				},
				header = {sprite_name = "Isaac",},
			},
			{
				data = {
					"琉璃：",
					{word = "不必在意。我还有很重要的手术要在前面进行",colorful = 0,},
					{word = "先导，别让任何人闯进来",colorful = 10,},
					"        ",
					{word = "顺便，扫除这个入侵者",scaler = Vector(0.75,0.75),color = Color(1,1,1,0.3),on_finish = function() 
						local ent = item.get_glaze()
						local d = ent:GetData()
						AI.move2pos(ent,Game():GetRoom():GetGridPosition(97) + Vector(0,-300),150)
						d[item.own_key.."leave"] = true
						local player = Game():GetPlayer(0)
						for i = 1,8 do 
							local q = auxi.launch_Missile(player.Position + auxi.MakeVector(i/8 * 360) * 120,Vector(0,0),{TearFlags = BitSet128(0,0),TearVariant = 0,TearColor = Color(1,1,1,1),TearDamage = 5,},nil,{ReloadRocket = function(et)
								local ets = et:GetSprite() ets:Load("gfx/boss/Qing/rocket.anm2",true) ets:Play("Idle",true) ets.Rotation = 90
							end,fallspeed = 20,baseoffset = Vector(0,-800),})
							local qs = q:GetSprite() qs:Load("gfx/boss/Qing/Target.anm2",true) qs:Play("Appear")
						end
						for k = 1,3 do 
							delay_buffer.addeffe(function()
								local cnt = k * 8 + 8
								for i = 1,cnt do 
									local q = auxi.launch_Missile(player.Position + auxi.MakeVector(i/cnt * 360) * (120 + 80 * k),Vector(0,0),{TearFlags = BitSet128(0,0),TearVariant = 0,TearColor = Color(1,1,1,1),TearDamage = 5,},nil,{ReloadRocket = function(et)
										local ets = et:GetSprite() ets:Load("gfx/boss/Qing/rocket.anm2",true) ets:Play("Idle",true) ets.Rotation = 90
									end,fallspeed = 20,baseoffset = Vector(0,-800),})
									local qs = q:GetSprite() qs:Load("gfx/boss/Qing/Target.anm2",true) qs:Play("Appear")
								end
							end,{},k * 20,{remove_now = true,})
						end 
					end,},
				},
				header = {sprite_name = "Glaze_Doctor",},
			},
			{
				data = {
					"以撒：",
					"什么？",
				},
				header = {sprite_name = "Isaac",},
			},
			{
				data = {
					"? ? ?：",
					{word = "扫除...入侵者...",color = Color(1,0,0,1),scaler = Vector(2,2),inner_step_multi = 10,},
				},
				header = {sprite_name = "WQing?",},
			},
			{
				data = {
					"以撒：",
					"不！",
					"医生，你做了什么？",
				},
				header = {sprite_name = "Isaac",},
			},
		},
		[2] = {
			{
				data = {
					"以撒：",
					"琉璃！小青都告诉我了。",
					"你的邪恶计划破产了！",
					"乖乖停手吧！",
				},
				header = {sprite_name = "Isaac",},
			},
			{
				data = {
					"琉璃：",
					{word = "哦？是吗？",colorful = 0,doublerender = Vector(1,-1),},
					{word = "这么说来，小青做得很好。",colorful = 10,doublerender = Vector(1,-1),},
					{word = "他拖延了充分的时间。现在..已经来不及了！",colorful = 20,doublerender = Vector(1,-1),},
				},
				header = {sprite_name = "Glaze",},
			},
			{
				data = {
					"琉璃：",
					{word = "你的世界已经被我扎了个口子！",colorful = 0,doublerender = Vector(1,-1),},
					{word = "这让灾诞锁定了这里",colorful = 10,doublerender = Vector(1,-1),},
					{word = "看呀... 这些梦境能量像牛奶一样汩汩流出..",colorful = 20,doublerender = Vector(1,-1),},
					{word = "你绝对想象不到，它能把我强化到什么程度！",colorful = 30,doublerender = Vector(1,-1),},
				},
				header = {sprite_name = "Glaze",},
			},
			{
				data = {
					"以撒：",
					"休想！即使你窃取了这些力量",
					"你的目的也绝不可能达成！",
				},
				header = {sprite_name = "Isaac",},
			},
		},
		[3] = {
			{
				data = {
					"琉璃：",
					{word = "真是难以置信",colorful = 0,doublerender = Vector(1,-1),},
					{word = "即使我处于最佳状态，居然也不是你的对手！",colorful = 10,doublerender = Vector(1,-1),},
					{word = "但你依然改变不了这一切！",colorful = 20,doublerender = Vector(1,-1),},
					{word = "灾诞已经开始注视这个世界",colorful = 30,doublerender = Vector(1,-1),},
				},
				header = {sprite_name = "Glaze",},
			},
			{
				data = {
					"琉璃：",
					{word = "用不了多久，我的主人就会降临！",colorful = 0,doublerender = Vector(1,-1),},
					{word = "希望你，还能笑到那个时候。",colorful = 10,doublerender = Vector(1,-1),},
					{word = "..",colorful = 20,doublerender = Vector(1,-1),},
					{word = "我的任务已经完成了，再见！",colorful = 30,doublerender = Vector(1,-1),},
				},
				header = {sprite_name = "Glaze",},
			},
			{
				data = {
					"以撒：",
					"灾诞？",
					"这个名字..究竟是什么？",
				},
				header = {sprite_name = "Isaac",},
			},
			{
				data = {
					"小青：",
					"灾诞是一个跨域侵略组织，我也曾是他们中的一员",
					"他们存在的意义就是侵略和占领世界",
					"被他们盯上的话，可就糟糕了",
				},
				header = {sprite_name = "WQing?",},
			},
			{
				data = {
					"???：",
					"我...已...到...达",
				},
				header = {sprite_name = "Tecro",},
			},
		},
	},
	en = {
        [1] = {
            {
                data = {
                    "Isaac:",
                    {word = "Ah! It's Dr. Glaze!", line_inside_delay = 20},
                    "Doctor, how is Qing doing?",
                },
                header = {sprite_name = "Isaac"},
            },
            {
                data = {
                    "Glaze:",
                    {word = "I'm glad you could make it. In fact, you've done exceptionally well!", colorful = 0},
                    {word = "This is the 'Other Realm', the fragile edge of the world.", colorful = 10},
                    {word = "Only a good child like you", colorful = 20},
                    {word = "can reach here with the power of those fragments.", colorful = 30},
                },
                header = {sprite_name = "Glaze_Doctor"},
            },
            {
                data = {
                    "Isaac:",
                    "Wait! Dr. Glaze",
                    {word = "Didn't you say we need these fragments to save Qing?", on_finish = function() 
                        local ent = item.get_glaze()
                        local d = ent:GetData()
                        d[item.own_key.."control"] = {}
                        AI.move2pos(ent,Game():GetRoom():GetGridPosition(97),150)
                    end},
                },
                header = {sprite_name = "Isaac"},
            },
            {
                data = {
                    "Glaze:",
                    {word = "Qing? Hehe..", colorful = 0},
                    {word = "He's recovering quickly, too fast to wait for these fragments", colorful = 10, line_inside_delay = 20},
                    {word = "In fact, you'll see him soon", colorful = 20},
                    {word = "Compared to an assassin, there's a new identity that suits him better.", colorful = 30},
                },
                header = {sprite_name = "Glaze_Doctor"},
            },
            {
                data = {
                    "Isaac:",
                    "Suits him?",
                },
                header = {sprite_name = "Isaac"},
            },
            {
                data = {
                    "Glaze:",
                    {word = "Don't worry about it. I have an important surgery to perform ahead", colorful = 0},
                    {word = "Vanguard, don't let anyone in", colorful = 10},
                    "        ",
                    {word = "And by the way, eliminate this intruder", scaler = Vector(0.75,0.75), color = Color(1,1,1,0.3), on_finish = function() 
                        local ent = item.get_glaze()
                        local d = ent:GetData()
                        AI.move2pos(ent,Game():GetRoom():GetGridPosition(97) + Vector(0,-300),150)
                        d[item.own_key.."leave"] = true
                        local player = Game():GetPlayer(0)
                        for i = 1,8 do 
                            local q = auxi.launch_Missile(player.Position + auxi.MakeVector(i/8 * 360) * 120,Vector(0,0),{TearFlags = BitSet128(0,0),TearVariant = 0,TearColor = Color(1,1,1,1),TearDamage = 5,},nil,{ReloadRocket = function(et)
                                local ets = et:GetSprite() ets:Load("gfx/boss/Qing/rocket.anm2",true) ets:Play("Idle",true) ets.Rotation = 90
                            end,fallspeed = 20,baseoffset = Vector(0,-800),})
                            local qs = q:GetSprite() qs:Load("gfx/boss/Qing/Target.anm2",true) qs:Play("Appear")
                        end
                        for k = 1,3 do 
                            delay_buffer.addeffe(function()
                                local cnt = k * 8 + 8
                                for i = 1,cnt do 
                                    local q = auxi.launch_Missile(player.Position + auxi.MakeVector(i/cnt * 360) * (120 + 80 * k),Vector(0,0),{TearFlags = BitSet128(0,0),TearVariant = 0,TearColor = Color(1,1,1,1),TearDamage = 5,},nil,{ReloadRocket = function(et)
                                        local ets = et:GetSprite() ets:Load("gfx/boss/Qing/rocket.anm2",true) ets:Play("Idle",true) ets.Rotation = 90
                                    end,fallspeed = 20,baseoffset = Vector(0,-800),})
                                    local qs = q:GetSprite() qs:Load("gfx/boss/Qing/Target.anm2",true) qs:Play("Appear")
                                end
                            end,{},k * 20,{remove_now = true,})
                        end 
                    end},
                },
                header = {sprite_name = "Glaze_Doctor"},
            },
            {
                data = {
                    "Isaac:",
                    "What?",
                },
                header = {sprite_name = "Isaac"},
            },
            {
                data = {
                    "? ? ?:",
                    {word = "Eliminate... intruder...", color = Color(1,0,0,1), scaler = Vector(2,2), inner_step_multi = 10},
                },
                header = {sprite_name = "WQing?"},
            },
            {
                data = {
                    "Isaac:",
                    "No!",
                    "Doctor, what have you done?",
                },
                header = {sprite_name = "Isaac"},
            },
        },
        [2] = {
            {
                data = {
                    "Qing?:",
                    {word = "That's all for now, the update ends here.", color = Color(1,1,1,1)},
                },
                header = {sprite_name = "WQing"},
            },
        },
    },
}
--好像写不下了，所以把剧情表演分开来
function item.get_word(id,force)
	local language = Options.Language
	if item.word_list[language] == nil then language = "zh" end
	if force then return auxi.copy(item.word_list[language][id]) end
	return item.word_list[language][id]
end

function item.try_start(act)			--或许需要考虑传送打断剧情进展。
	act = act or 1
	if act == 1 then
		if save.elses[Boss_Qing.own_key.."finished"] then
		elseif save.elses[item.own_key.."act1_end"] then 
			Boss_Qing.start()
		else
			save.elses[item.own_key.."act1_control"] = {}
		end
	end
	if act == 2 then
		if save.elses[item.own_key.."act2_end"] then 
			item.act2_end()
		else
			save.elses[item.own_key.."act2_control"] = {}
		end
	end
end

function item.is_act_finish(act)
	if act == 1 then
		if save.elses[Boss_Qing.own_key.."finished"] then return true else return false end
	end
end

function item.try_generate_glaze()
	local room = Game():GetRoom()
	local q = Isaac.Spawn(1000,enums.Entities.Glaze_Helper,0,room:GetGridPosition(293),Vector(0,0),nil):ToEffect()
	local sq = q:GetSprite() sq:Load("gfx/boss/Glaze/Prince_glaze.anm2",true) sq:Play("Idle_Doctor",true)
	return q
end

function item.get_glaze(force)
	local tgs = auxi.getothers(1000,enums.Entities.Glaze_Helper,0)
	if #tgs == 0 then return item.try_generate_glaze()
	else return tgs[1] end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Glaze_Helper,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."control"] then AI.Control_Move(ent)
	else 
		local player = Game():GetPlayer(0)
		ent.Velocity = (player.Position + Vector(0,-120) - ent.Position) * 0.3
		ent.Velocity = auxi.apply_friction(ent.Velocity,1)
	end
	auxi.check_if_any(d[item.own_key.."update"])
	if d[item.own_key.."leave"] then 
		local s = ent:GetSprite()
		s.Color = auxi.AddColor(s.Color,Color(0,0,0,-0.01),1,1)
		if s.Color.A < 0.04 then ent:Remove() return end
	end
	local info = item.glaze_info.Idle
	local frame = ent.FrameCount % info.total
	ent.PositionOffset = Vector(0,auxi.check_lerp(frame,info).offset) + Vector(0,-20)
end,
})

function item.act2_end()
	local q = grid_trapdoor.spawn_trapdoor(Game():GetRoom():GetCenterPos(),{Function = function(player)
		Game():GetLevel():SetStage(8,0)
		Isaac.ExecuteCommand("reseed")
		Screen_Filter.add_filter(30,3)
	end,})
	local s = q:GetSprite() s:Load("gfx/boss/Glaze/door_11_wombhole.anm2",true) s:Play("Open Animation",true)
	local d = q:GetData() d[Nil.own_key.."work_addon"] = function(self) local ss = self:GetSprite() if ss:IsFinished("Open Animation") then ss:Play("Opened",true) end end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if save.elses[item.own_key.."act1_control"] then
		if save.elses[item.own_key.."act1_control"].dialog == nil then
			if Dialog_holder.is_clear() then
				grid_doors.force_door_anim()
				save.elses[item.own_key.."act1_control"].dialog = true
				local data = item.get_word(1,true)
				for u,v in pairs(data) do Dialog_holder.add_word({data = v.data,header = v.header,step_by = true,line_inside_delay = 20,cid = u,ignore_nil = true,}) end
				item.try_generate_glaze()
			end
		else
			if (Dialog_holder.word_list[1] or {}).cid then save.elses[item.own_key.."act1_control"].cnt = Dialog_holder.word_list[1].cid end
			if Dialog_holder.is_clear() and (save.elses[item.own_key.."act1_control"].cnt or 0) == #(item.get_word(1)) then
				save.elses[item.own_key.."act1_end"] = true
				save.elses[item.own_key.."act1_control"] = nil
				Boss_Qing.start()
			end
		end
	end
	if save.elses[item.own_key.."act2_control"] then
		if save.elses[item.own_key.."act2_control"].dialog == nil then
			if Dialog_holder.is_clear() then
				--grid_doors.force_door_anim()
				save.elses[item.own_key.."act2_control"].dialog = true
				local data = item.get_word(2,true)
				for u,v in pairs(data) do Dialog_holder.add_word({data = v.data,header = v.header,step_by = true,line_inside_delay = 20,cid = u,ignore_nil = true,}) end
				--item.try_generate_glaze()
			end
		else
			if (Dialog_holder.word_list[1] or {}).cid then save.elses[item.own_key.."act2_control"].cnt = Dialog_holder.word_list[1].cid end
			if Dialog_holder.is_clear() and (save.elses[item.own_key.."act2_control"].cnt or 0) == #(item.get_word(2)) then
				save.elses[item.own_key.."act2_end"] = true
				save.elses[item.own_key.."act2_control"] = nil
				item.act2_end()
			end
		end
	end
end,
})

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	own_key = "Player_All_holder_",
	re_costume_items = {
		[CollectibleType.COLLECTIBLE_D100] = true,
		[CollectibleType.COLLECTIBLE_D4] = true,
		[CollectibleType.COLLECTIBLE_ESAU_JR] = true,
	},
	player_info = {
		[enums.Players.wq] = {
			costumes = {
				{id = enums.Costumes.Qingrobes,},
			},
			Description = {
				loader = {
					[1] = "gfx/effects/signs/notice_sign_Qing.png",
				},
				Desc = {
					["zh"] = {
						Name = "操作指南：万青",
						Description = "插在物体上的小刀可以作为瞬移标记点#按下Alt键进行瞬移#必要情况下小刀会自动扎在墙上让玩家瞬移出来",
					},
					["en"] = {
						Name = "Operation Guide:W.Q.",
						Description = "A small knife inserted into an object can serve as a teleportation marker #Press the Alt key to teleport",
					},
				},
			},
		},
		[enums.Players.Spwq] = {
			costumes = {
				{id = enums.Costumes.SPWQinghair,},
			},
			Description = {
				loader = {
					[1] = "gfx/effects/signs/notice_sign_Qing.png",
				},
				Desc = {
					["zh"] = {
						Name = "操作指南：万青",
						Description = "攻击键或按住鼠标左键移动指挥准星#Ctrl 或鼠标中键切换巡航/护卫#鼠标右键或短按蓝图切换自动/压制开火#长按蓝图打开面板",
					},
					["en"] = {
						Name = "Operation Guide:W.Qing",
						Description = "Attack or hold LMB to move the command mark#Ctrl or MMB toggles Cruise/Guard#RMB or tap Blueprint toggles Auto/Force fire#Hold Blueprint to open the panel",
					},
				},
			},
		},
		[enums.Players.Autio] = {
			costumes = {
				{id = enums.Costumes.Autio_Hair,},
			},
		},
		[enums.Players.Tecro] = {
			costumes = {
				{id = enums.Costumes.Tecrohair,},
				{id = enums.Costumes.Tecroface,},
			},
			Description = {
				loader = {
					[1] = "gfx/effects/signs/notice_sign_Tecro.png",
				},
				Desc = {
					["zh"] = {
						Name = "操作指南：泰克罗",
						Description = "按下鼠标中键开关鼠标控制",
					},
					["en"] = {
						Name = "Operation Guide:Tecro",
						Description = "Press the middle mouse button to switch mouse control",
					},
				},
			},
		},
		[enums.Players.Tecrorun] = {
			costumes = {
				{id = enums.Costumes.Tecrorun_head,},
				{id = enums.Costumes.Tecrorun_body,},
			},
			reloader_sprite = "gfx/characters/reloader/Tecrorun.anm2",
			Description = {
				loader = {
					[1] = "gfx/effects/signs/notice_sign_Tecro.png",
				},
				Desc = {
					["zh"] = {
						Name = "操作指南：泰克罗· 罗恩",
						Description = "按下鼠标中键开关鼠标控制#瞄准门口瞬移可以出门#满蓄力造成更高伤害",
					},
					["en"] = {
						Name = "Operation Guide:Tecro",
						Description = "Press the middle mouse button to switch mouse control",
					},
				},
			},
		},
		[enums.Players.Anna] = {
			costumes = {
				{id = enums.Costumes.Anna_body,},
				{id = enums.Costumes.Anna_Horn,},
			},
			reloader_sprite = "gfx/characters/reloader/Anna.anm2",
			Description = {
				loader = {
					[1] = "gfx/effects/signs/notice_sign_Anna.png",
				},
				Desc = {
					["zh"] = {
						Name = "操作指南：安娜",
						Description = "按住 {{ButtonRT}} 时松开攻击键就不会发射#清理房间后按住攻击键并双击 {{ButtonRT}} 可快速收回捕获物#稀有的掉落物造成更高伤害",
					},
					["en"] = {
						Name = "Operation Guide:Anna",
						Description = "Releasing the attack key while holding down {{ButtonRT}} will not emit #After cleaning the room, holding down the attack key and double clicking {ButtonRT}} can quickly retrieve the captured item # Rare dropped items cause higher damage",
					},
				},
			},
		},
		[enums.Players.annA] = {
			costumes = {
				{id = enums.Costumes.Anna2_body,},
				{id = enums.Costumes.Anna_Horn,},
			},
			reloader_sprite = "gfx/characters/reloader/Anna2.anm2",
			Description = {
				loader = {
					[1] = "gfx/effects/signs/notice_sign_Anna.png",
				},
				Desc = {
					["zh"] = {
						Name = "操作指南：安奈",
						Description = "蓄力轰炸目标#攻击后有0.25秒无敌时间",
					},
					["en"] = {
						Name = "Operation Guide:Anna",
						Description = "Accumulated and bomb target # Gain 0.25 seconds of invincibility after attack",
					},
				},
			},
		},
		[enums.Players.Zeistos] = {
			costumes = {
				{id = enums.Costumes.Zeistos_Head,},
			},
			Description = {
				loader = {
					[1] = "gfx/effects/signs/notice_sign_Zeistos.png",
				},
				Desc = {
					["zh"] = {
						Name = "操作指南：泽·伊斯托斯",
						Description = "第一层自由选择一个被动道具#此后可以选择与获得的道具一定距离内的被动道具#未正式获得的被动道具最多只能选一次",
					},
					["en"] = {
						Name = "Operation Guide:Zeis",
						Description = "The first layer freely selects a passive item #Afterwards, you can choose passive items within a certain distance from the obtained item #Passive items that have not been officially obtained can only be selected once at most",
					},
				},
			},
		},
		[enums.Players.Zeiz] = {
			costumes = {
				{id = enums.Costumes.Zeistos_Head,},
			},
			Description = {
				loader = {
					[1] = "gfx/effects/signs/notice_sign_Zeistos.png",
				},
				Desc = {
					["zh"] = {
						Name = "操作指南：泽伊兹",
						Description = "每层进入控制中枢#接触候选虚影以任命管理员#其愚见会错误地管理世界",
					},
					["en"] = {
						Name = "Operation Guide:Zeiz",
						Description = "Enter the Control Hub each floor#Touch a candidate phantom to appoint them#Their Folly mismanages the world",
					},
				},
			},
		},
		[enums.Players.Marriano] = {
			costumes = {
			},
			Description = {
				loader = {
					[1] = "gfx/effects/signs/notice_sign_Marriano.png",
				},
				Desc = {
					["zh"] = {
						Name = "操作指南：玛利亚诺",
						Description = "将道具重置为面具#面具全部破碎后堕入恶魔",
					},
				},
			},
		},
	},
	StageAPI_PlayerGraphicsInfo = {
		[enums.Players.wq] = {
			Name = "gfx/ui/stage/playername_WQing.png",
			Portrait = "gfx/ui/stage/WQingPortrait.png",
			NoShake = false,
		},
		[enums.Players.Spwq] = {
			Name = "gfx/ui/stage/playername_WQing.png",
			Portrait = "gfx/ui/stage/SPWQingPortrait.png",
			NoShake = false,
		},
		[enums.Players.Tecro] = {
			Name = "gfx/ui/stage/playername_Tecro.png",
			Portrait = "gfx/ui/stage/TecroPortrait.png",
			NoShake = false,
		},
		[enums.Players.Anna] = {
			Name = "gfx/ui/stage/playername_Anna.png",
			Portrait = "gfx/ui/stage/AnnaPortrait.png",
			NoShake = false,
		},
		[enums.Players.annA] = {
			Name = "gfx/ui/stage/playername_Anna.png",
			Portrait = "gfx/ui/stage/AnnaPortrait3.png",
			NoShake = false,
		},
		[enums.Players.Zeistos] = {
			Name = "gfx/ui/stage/playername_Zeistos.png",
			Portrait = "gfx/ui/stage/ZeistosPortrait.png",
			NoShake = false,
		},
		[enums.Players.Zeiz] = {
			Name = "gfx/ui/stage/playername_Zeistos.png",
			Portrait = "gfx/ui/stage/ZeisPortrait2.png",
			NoShake = false,
		},
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = nil,
Function = function(_,collid, itemRng, player, useFlags, activeSlot, customVarData)
	local info = item.player_info[player:GetPlayerType()]
	if item.re_costume_items[collid] and info and info.costumes then
		for u,v in pairs(info.costumes) do player:AddNullCostume(v.id) end	--print(v.id) 
	end
end,
})

function item.do_init(player)
	local info = item.player_info[player:GetPlayerType()]
	local idx = player:GetData().__Index
	local s = player:GetSprite()
	save.elses[item.own_key.."Reload"] = save.elses[item.own_key.."Reload"] or {}
	if info then
		if info.reloader_sprite then 
			s:Load(info.reloader_sprite,true) 
			save.elses[item.own_key.."Reload"][idx] = info.reloader_sprite
		end
		for u,v in pairs(info.costumes or {}) do player:AddNullCostume(v.id) end
	end
	if save.elses[item.own_key.."Reload"][idx] and save.elses[item.own_key.."Reload"][idx] ~= s:GetFilename() then s:Load(save.elses[item.own_key.."Reload"][idx],true) end
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	item.do_init(player)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_PLAYER_SHIFT, params = nil,
Function = function(_,player,tp)
	local info = item.player_info[tp]
	if info then
		local idx = player:GetData().__Index
		local s = player:GetSprite()
		save.elses[item.own_key.."Reload"] = save.elses[item.own_key.."Reload"] or {}
		if save.elses[item.own_key.."Reload"][idx] == nil or save.elses[item.own_key.."Reload"][idx] ~= s:GetFilename() then
			save.elses[item.own_key.."Reload"][idx] = nil
			for u,v in pairs(info.costumes or {}) do player:TryRemoveNullCostume(v.id) end
		end
	end
	item.do_init(player)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local info = item.player_info[player:GetPlayerType()]
	if info then
		local d = player:GetData()
		local s = player:GetSprite()
		if player:IsCoopGhost() then d[item.own_key.."Ghost"] = true
		elseif d[item.own_key.."Ghost"] then d[item.own_key.."Ghost"] = nil
			for u,v in pairs(info.costumes or {}) do player:AddNullCostume(v.id) end
		end
		if info.reloader_sprite and s:GetFilename() ~= info.reloader_sprite then s:Load(info.reloader_sprite,true) end
	end
end,
})

function item.spawn_desc_info(tp,params)
	params = params or {}
	local info = item.player_info[tp]
	if info and info.Description then
		local q = Isaac.Spawn(1000,enums.Entities.EID_Descriptier,0,params.pos or Game():GetRoom():GetGridPosition(auxi.choose(1,2,3,4,5,9,10,12,13)),Vector(0,0),nil)
		q.SortingLayer = 1
		local s = q:GetSprite()
		s:Load("gfx/thread/Notice_board.anm2",true)
		for u,v in pairs(info.Description.loader) do s:ReplaceSpritesheet(u,v) end s:LoadGraphics()
		s:SetFrame("Idle1_",1)
		local d = q:GetData()
		local language = Options.Language 
		local desc = info.Description.Desc
		if desc[language] == nil then language = "zh" end
		desc = desc[language]
		d.EID_Description = {Name = desc.Name,Description = desc.Description,}
		return q
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		if auxi.is_normal_game() then
			local info = {}
			for playerNum = 1,Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				local info = item.player_info[player:GetPlayerType()]
				if info and info.Description then
					item.spawn_desc_info(player:GetPlayerType())
					break
				end
			end
		end
	end
	if SpecialistModAPI then
		for u,v in pairs(item.player_info) do
			local costume = v.dance and Isaac.GetCostumeIdByPath(v.dance)
			if costume and costume > 0 then
				SpecialistModAPI:AddDanceCostume(u, costume, true)
			end
		end
	end
end,
})

if StageAPI and StageAPI.Loaded then
	for u,v in pairs(item.StageAPI_PlayerGraphicsInfo) do StageAPI.AddPlayerGraphicsInfo(u,v) end
end

return item

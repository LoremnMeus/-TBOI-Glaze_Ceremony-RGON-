local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local translations = include("Qing_Remaster_scripts.translations.translate")
local menu_lang = require("Qing_Remaster_scripts.callbacks.rgon_menu_language_holder")

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
				dogma_shader = true,
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
				dogma_shader = true,
			},
		},
		[enums.Players.Marriano] = {
			costumes = {
			},
			Description = {
				loader = {
					[1] = "gfx/effects/signs/notice_sign_Marriano.png",
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
		[enums.Players.Tecrorun] = {
			Name = "gfx/ui/stage/playername_Tecrorun.png",
			Portrait = "gfx/ui/stage/TecroPortrait3.png",
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

local function apply_notice_dogma(sprite)
	if not REPENTOGON or not sprite then return end
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	temp_hud.apply_sprite_shader(sprite, temp_hud.DOGMA_CHROMATIC_SHADER)
	local col = sprite.Color
	local t = temp_hud.dogma_shader_time()
	if col.SetColorize then
		local next_col = Color(col.R, col.G, col.B, col.A, col.RO, col.GO, col.BO)
		next_col:SetColorize(0, 0, 0, t)
		sprite.Color = next_col
	else
		sprite.Color = Color(col.R, col.G, col.B, col.A, col.RO, col.GO, col.BO, 0, 0, 0, t)
	end
end

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
	local guide = translations.get_player_start_guide(tp, menu_lang.get_language("ControlsLanguage"))
	if not info or not info.Description or not guide then return nil end
	local q = Isaac.Spawn(1000,enums.Entities.EID_Descriptier,0,params.pos or Game():GetRoom():GetGridPosition(auxi.choose(1,2,3,4,5,9,10,12,13)),Vector(0,0),nil)
	q.SortingLayer = 1
	local s = q:GetSprite()
	s:Load("gfx/thread/Notice_board.anm2",true)
	for u,v in pairs(info.Description.loader) do s:ReplaceSpritesheet(u,v) end s:LoadGraphics()
	s:SetFrame("Idle1_",1)
	local d = q:GetData()
	d.EID_Description = {Name = guide.Name, Description = guide.Description,}
	if info.Description.dogma_shader then
		item.apply_notice_board_dogma(q)
	end
	return q
end

function item.apply_notice_board_dogma(ent)
	if not ent then return end
	ent:GetData()[item.own_key.."dogma_sign"] = true
	apply_notice_dogma(ent:GetSprite())
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.EID_Descriptier,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."dogma_sign"] then
		apply_notice_dogma(ent:GetSprite())
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		if auxi.is_normal_game() then
			local info = {}
			for playerNum = 1,Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				local info = item.player_info[player:GetPlayerType()]
				if info and info.Description and translations.get_player_start_guide(player:GetPlayerType(), menu_lang.get_language("ControlsLanguage")) then
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

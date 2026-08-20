local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Screen_Filter = require("Qing_Remaster_scripts.others.Screen_Filter")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	Post_ToCall = {},
	own_key = "Thread_start_",
	paper_loader = {
		
	},
	paper_sprite = {
		"collectibles_018_adollar",
		"collectibles_054_treasuremap",
		"collectibles_064_steamsale",
		"collectibles_075_phd",
		"collectibles_080_thepact",
		"collectibles_115_ouijaboard",
		"collectibles_141_pageantboy",
		"collectibles_191_3dollarbill",
		"collectibles_203_humblingbundle",
		"collectibles_241_contractfrombelow",
		"collectibles_246_bluemap",
		"collectibles_250_bogobombs",
		"collectibles_262_missingpage2",
		"collectibles_327_thepolaroid",
		"collectibles_328_thenegative",
		"collectibles_341_tornphoto",
		"collectibles_526_7seals",
		"collectibles_530_deathslist",
		"collectibles_547_divorcepapers",
		"collectibles_601_actofcontrition",
		"collectibles_619_birthright",
		"collectibles_628_deathcertificate",
		"collectibles_654_falsephd",
		"collectibles_660_cardreading",
		"collectibles_668_dadsnote",
		"trinket_008_cartridge",
		"trinket_013_storecredit",
		"trinket_021_mysteriouspaper",
		"trinket_023_missingposter",
		"trinket_069_fadedpolaroid",
		"trinket_141_songofthesiren",
		"trinket_145_perfection",
		"trinket_169_kidsdrawing",
		"trinket_184_adoptionpapers",
	},
	words = {
	},
}

function item.cast_a_paper(pos,params)
	params = params or {}
	local q = Isaac.Spawn(1000,enums.Entities.Lu_s_paper,0,pos,Vector(0,0),nil):ToEffect()
	local d = q:GetData()
	local s = q:GetSprite()
	s:ReplaceSpritesheet(0,"gfx/effects/papers/"..auxi.random_in_table(item.paper_sprite)..".png") s:LoadGraphics()
	if params.cnt then 
		s:Play(auxi.choose("Float1","Float2"),true)
		s:SetLastFrame()
		s.Offset = Vector(0,- (params.cnt - 1) * 50)
		d[item.own_key.."counter"] = params.cnt - 1
		s.PlaybackSpeed = params.PlaybackSpeed or (math.random(1000)/1000 + 0.5)
	end
	return q
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."Start"] = nil
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."Start"] = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,rng,pos)
	local level = Game():GetLevel()
	if Unlocker.should_any_be_done("Thread","Start1",nil,"Boss_allow") and 
	level:GetStage() == LevelStage.STAGE1_1 and level:GetStageType() <= StageType.STAGETYPE_AFTERBIRTH and Game():GetRoom():IsCurrentRoomLastBoss() and (save.elses[item.own_key.."Start"] or 0) == 0 then
		local rooms = level:GetRooms()
		for i = 1,rooms.Size do
			local targ = rooms:Get(i - 1)
			if targ and targ.Data and targ.Data.Type == RoomType.ROOM_SUPERSECRET and targ.VisitedCount == 0 then
				Room_holder.Try_replace_with(targ.SafeGridIndex,nil,{data = function() Isaac.ExecuteCommand("goto s.supersecret.24700") return Game():GetLevel():GetRoomByIdx(-3).Data end,})
				save.elses[item.own_key.."Start"] = 1
				break
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local room = Game():GetRoom()
	if desc.Data.Type == RoomType.ROOM_SUPERSECRET and desc.Data.Variant == 24700 then
		for i = 1,15 do 
			item.cast_a_paper((Vector(440,280) + auxi.RoundVector(nil,40)),{cnt = auxi.choose(2,3,4,5,6,7,8,9),})
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Lu_s_paper,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if (d[item.own_key.."counter"] or 0) > 0 then
		if s:IsFinished("Float1") or s:IsFinished("Float2") then 
			d[item.own_key.."counter"] = d[item.own_key.."counter"] - 1
			s.Offset = s.Offset + Vector(0,50)
			if d[item.own_key.."counter"] == 0 then
				if s:IsFinished("Float1") then s:Play("Float2Down",true) 
				else s:Play("Float1Down",true) end
			else
				if s:IsFinished("Float1") then s:Play("Float2",true) 
				else s:Play("Float1",true) end
			end
		end
	end
	if s:IsFinished("Float1Down") or s:IsFinished("Float2Down") then s:Play("Lay",true) end
end,
})

return item
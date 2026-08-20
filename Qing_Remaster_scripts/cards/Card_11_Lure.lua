local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")

local Lure_effect = Sprite()
Lure_effect:Load("gfx/cards/Tarot_Lure_effect.anm2",true)
Lure_effect:Play("Idle",true)

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Lure,
	own_key = "Thoth_cd11_Lur_",
	render_counter = 0,
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	save.elses[item.own_key.."effect"] = 0
	Lure_effect.Color = Color(1,1,1,0)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = 0
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	local scz = auxi.GetScreenSize()
	if save.elses[item.own_key.."effect"] ~= nil and save.elses[item.own_key.."effect"] > 0 then
		Lure_effect.Color = auxi.AddColor(Lure_effect.Color,Color(1.5,1.5,1.5,1,0.3,0.3,0.3),0.9,0.1)
	else
		Lure_effect.Color = auxi.AddColor(Lure_effect.Color,Color(1,1,1,0,0,0,0),0.9,0.1)
	end
	if Lure_effect.Color.A > 0.05 then
		Lure_effect:Render(auxi.GetScreenCenter()/2 - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
		Lure_effect:Update()
		Lure_effect.Rotation = Lure_effect.Rotation + 0.3
		Lure_effect.Scale = Vector(scz.X/205 * (1 + 0.3 * math.sin(1.2 * math.rad(item.render_counter - 82))),scz.Y/205 * (1 + 0.3 * math.cos(math.rad(item.render_counter + 38))))
	end
	item.render_counter = item.render_counter + 0.1
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d[item.own_key.."effect"] then s.PlaybackSpeed = 1.2 end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if flag & DamageFlag.DAMAGE_CLONES == 0 and amt ~= 0 then
			local dmg = 5
			if d[item.own_key.."effect"] == 2 then dmg = 10 end
			ent:TakeDamage(dmg,flag | DamageFlag.DAMAGE_CLONES,source,cooldown)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local n_entity = Isaac.GetRoomEntities()
	local n_enemy = auxi.getenemies(n_entity)
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			for u,v in pairs(n_enemy) do
				v:GetData()[item.own_key.."effect"] = 2
			end
		else
			for u,v in pairs(n_enemy) do
				v:GetData()[item.own_key.."effect"] = 1
			end
		end
		save.elses[item.own_key.."effect"] = 1
	end
end,
})

return item
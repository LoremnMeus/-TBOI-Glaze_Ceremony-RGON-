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

local Art_effect = Sprite()
Art_effect:Load("gfx/cards/Tarot_Art_effect.anm2",true)
Art_effect:Play("Idle",true)

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Art,
	own_key = "Thoth_cd14_Art_",
	render_counter = 0,
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = 0
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or 0
	Art_effect.Color = Color(1,1,1,0)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	local scz = auxi.GetScreenSize()
	if save.elses[item.own_key.."effect"] ~= nil and save.elses[item.own_key.."effect"] > 0 then
		Art_effect.Color = auxi.AddColor(Art_effect.Color,Color(1,1,1,1,0.3,0.3,0.3),0.9,0.1)
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] - 1
	else
		Art_effect.Color = auxi.AddColor(Art_effect.Color,Color(1,1,1,0,0,0,0),0.9,0.1)
	end
	if Art_effect.Color.A > 0.05 then
		Art_effect:Render(auxi.GetScreenCenter()/2 - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
		Art_effect:Update()
		Art_effect.Rotation = Art_effect.Rotation - 0.3
		Art_effect.Scale = Vector(scz.X/205 * (1 + 0.3 * math.sin(math.rad(item.render_counter + 81))),scz.Y/205 * (1 + 0.3 * math.cos(0.8 * math.rad(item.render_counter + 145))))
	end
	item.render_counter = item.render_counter + 0.1
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
	local d = ent:GetData()
	if not ent:IsBoss() then
		if save.elses[item.own_key.."effect"] and save.elses[item.own_key.."effect"] > 0 then
			if d[item.own_key.."effect"] == nil then
				if ent.HitPoints/ent.MaxHitPoints < 0.1 then
					d[item.own_key.."effect"] = true
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local room = Game():GetRoom()
	if not ent:IsBoss() then
		if d[item.own_key.."effect"] ~= nil then
			Isaac.Spawn(5,0,1,room:FindFreePickupSpawnPosition(ent.Position,10,true),Vector(0,0),ent):ToPickup()
			d[item.own_key.."effect"] = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		if save.elses[item.own_key.."effect"] == nil then save.elses[item.own_key.."effect"] = 0 end
		save.elses[item.own_key.."effect"] = math.max(save.elses[item.own_key.."effect"],45 * 60)
	else
		if save.elses[item.own_key.."effect"] == nil then save.elses[item.own_key.."effect"] = 0 end
		save.elses[item.own_key.."effect"] = math.max(save.elses[item.own_key.."effect"],30 * 60)
	end
end,
})

return item
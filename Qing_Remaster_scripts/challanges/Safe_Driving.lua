local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local Hyper_Velocity = require("Qing_Remaster_scripts.items.Item_Hyper_Velocity")

local modReference
local item = {
	ToCall = {},
	challange = enums.Challenges.Safe_Driving,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	if Game().Challenge == item.challange then
		local room = Game():GetRoom()
		local s = player:GetSprite()
		local d = player:GetData()
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			Charging_Bar_holder.render_me(player,{name1 = "fire_delay_counter",name2 = "Safe_Driving_sprite",name3 = "Safe_Driving",loadname = "gfx/challenges/Safe_Driving/chargebar_Safe_Driving.anm2",
				check1 = nil,
				check2 = function(val,ent) 
					return val > 100
				end,
				check3 = function(val,ent)
					return math.ceil(val)
				end,
				signal1 = function(ent)
				end,
			})
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if Game().Challenge == item.challange then
		local d = player:GetData()
		if auxi.g_dir_can_work(player) then
			d.fire_delay_counter_Charge_Bar_buff = (d.fire_delay_counter_Charge_Bar_buff or 0) + 1
			if d.fire_delay_counter_Charge_Bar_buff >= 100 then
				local gdir = auxi.ggdir(player,true,true)
				if gdir:Length() < 0.05 then
				else
					local room = Game():GetRoom()
					Hyper_Velocity.Fire_Harmony(player,player.Position,gdir)
					d.fire_delay_counter_Charge_Bar_buff = 0
				end
			end
		end
	end
end,
})

return item

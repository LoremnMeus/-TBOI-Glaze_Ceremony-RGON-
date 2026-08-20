local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")

local item = {
	entity = enums.Cards.Qing_s_Soul,
	own_key = "sins_rune_Qing_s_Soul_",
	ToCall = {},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,card,player,useflags)		--暂时先这样？？
	local list = auxi.get_qing_list(player)
	local rnd = math.random(25) + 13
	local cnt = 0
	for i = 1,rnd do
		delay_buffer.addeffe(function(params)
			local gdir = auxi.ggdir(player,false,ModConfig.ModConfigSettings.allow_mouse_control)
			local dir = player.Velocity + gdir * 10
			local rnd2 = math.random(2) + 1
			for i = 1,rnd2 do auxi.fire_dosome_knife(player.Position + player.Velocity,auxi.get_by_rotate(dir,math.random(30) - 15,20 * player.ShotSpeed),nil,"IdleUp",{cooldown = 10,player = player,dmgmul = 1,Accerate = 0.75 + auxi.random_1(),Way_Accerate = dir:Normalized() * 20 * player.ShotSpeed,},nil) end
		end,{},cnt)
		cnt = cnt + 1 + math.random(4)
	end
end,
})

return item
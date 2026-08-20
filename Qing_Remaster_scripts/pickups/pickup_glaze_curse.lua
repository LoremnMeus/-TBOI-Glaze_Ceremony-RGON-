local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	curse_mul = 0,
	glaze_buffer = {},
	glaze_map = {
		0,
		0.1,
		0.2,
		0.3,
		0.4,
		0.5,
		0.6,
		0.75,
		0.7,
		0.6,
		0.5,
		0.4,
		0.2,
		0.15,
		0.1,
		0.05,
		0.05,
	},
	lst = 0,
}

function item.cast_a_glaze(player,ent,wei,delta_time)
	
end

return item
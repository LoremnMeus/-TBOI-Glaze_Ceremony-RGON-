local enums = require("Qing_Remaster_scripts.core.enums")
local console_holder = require("Qing_Remaster_scripts.others.Console_holder")
local Ember = require("Qing_Remaster_scripts.items.Item_Ember")

local item = {
	ToCall = {},
	challange = enums.Challenges.Feels_Like_Dead_Ashes,
}

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_, continue)
	if Game().Challenge ~= item.challange then return end
	console_holder.try_close_console()
	Ember.on_challenge_start(continue == true)
end,
})

return item

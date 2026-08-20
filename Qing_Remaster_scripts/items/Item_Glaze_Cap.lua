local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	myToCall = {},
	ToCall = {},
	entity = enums.Items.Glaze_Mushroom,
	own_key = "Item_Glaze_Mushroom_"
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil,
Function = function(_,pool,decrease,seed)
	if auxi.have_player_has_collectible(item.entity) and (not auxi.have_player_has_collectible(12)) and pool == ItemPoolType.POOL_BOSS and (save.elses[item.own_key.."effect"] ~= true) and Game():GetFrameCount() > 5 then
		local rng = RNG()
		rng:SetSeed(seed,0)
		rng = auxi.rng_for_sake(rng)
		local rnd = rng:RandomInt(5)
		if rnd == 1 then
			if decrease == true then save.elses[item.own_key.."effect"] = true end
			return 12
		end
	end
end,
})

return item
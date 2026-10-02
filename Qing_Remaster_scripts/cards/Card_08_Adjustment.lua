local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Adjustment,
	own_key = "Thoth_cd8_Adj_",
	infos = {
		[1] = {vr = 20,st = 1,},
		[2] = {vr = 30,st = 1,},
		[3] = {vr = 40,st = 1,},
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()

	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local total = player:GetNumBombs() + player:GetNumKeys() + player:GetNumCoins()
		local delta = math.floor(total/3)
		player:AddBombs(delta - player:GetNumBombs())
		player:AddKeys(delta - player:GetNumKeys())
		player:AddCoins(delta - player:GetNumCoins())
		local cnt = total - delta * 3
		local rng = auxi.rng_for_sake(player:GetCardRNG(item.entity))
		for i = 1,cnt do
			local free_pos = room:FindFreePickupSpawnPosition(player.Position,10,true)
			local ndx = option_index_holder.find_a_new_index()
			local nidx = rng:RandomInt(360)
			for j = 1,3 do
				local info = item.infos[j]
				local q = Isaac.Spawn(5,info.vr,info.st,free_pos + auxi.MakeVector(j * 360/3 + nidx) * 5,Vector(0,0),player):ToPickup()
				q:Morph(5,info.vr,info.st,true,true,true)
				q.OptionsPickupIndex = ndx
			end
		end
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			player:AddCoins(1)
			player:AddKeys(1)
			player:AddBombs(1)
		end
	end
end,
})


return item

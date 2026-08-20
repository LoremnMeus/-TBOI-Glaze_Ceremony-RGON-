local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local modReference
local item = {
	ToCall = {},
	entity = enums.Challenges.Unstable_State,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent, amt, flag, source, cooldown)
	if Game().Challenge == item.entity then
		local player = ent:ToPlayer()
		local room = Game():GetRoom()
		if player then
			local rng = player:GetDropRNG()
			if amt > 0 then
				if auxi.is_damage_from_enemy(ent, amt, flag, source, cooldown) then
					delay_buffer.addeffe(function(params)
						if player and not player:IsDead() and player:Exists() then
							player:UseCard(Card.CARD_REVERSE_FOOL,1 | (1<<8))
						end
					end,{},1)
					local itemConfig = Isaac.GetItemConfig()
					local tbl = {}
					local wei = 0
					local sz = itemConfig:GetCollectibles().Size
					for i = 1,sz do
						local collectible = itemConfig:GetCollectible(i)
						if (collectible and not collectible.Hidden and not collectible:HasTags(1<<15)) then
							if player:HasCollectible(i) then
								table.insert(tbl,{id = i,nums = player:GetCollectibleNum(i,true)})
								wei = wei + player:GetCollectibleNum(i,true)
							end
						end
					end
					for u,v in pairs(tbl) do
						for i = 1,v.nums do
							player:RemoveCollectible(v.id)
						end
					end
					for u,v in pairs(tbl) do
						for i = 1,v.nums do
							local q = Isaac.Spawn(5,100,v.id,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
							q.Touched = true
						end
					end
				end
			end
		end
	end
end,
})

return item

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

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Aeon,
	own_key = "Thoth_cd20_Aeon_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	local room = Game():GetRoom()
	if player then
		if auxi.has_card(player,item.entity) then
			local rng = player:GetCardRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			local rnd = rng:RandomInt(1000)
			if rnd > 950 then
				local pos = room:FindFreePickupSpawnPosition(room:FindFreeTilePosition(player.Position,10),10,true)
				local q = Isaac.Spawn(5,10,4,pos,Vector(0,0),player):ToPickup()
				q:GetSprite():SetLastFrame()
				q:GetSprite().Scale = Vector(0,0)
				local cnt = 10
				for i = 1,cnt do
					delay_buffer.addeffe(function(params)
						if q and q:Exists() then q:GetSprite().Scale = Vector(i / cnt,i / cnt) end
					end,{},i)
				end
				local e = Isaac.Spawn(1000,EffectVariant.CRACK_THE_SKY,0,pos,Vector(0,0),player):ToEffect()
				e.Parent = player
				e.CollisionDamage = 0
				e:GetSprite().Scale = Vector(0,0)
				for i = 1,cnt do
					delay_buffer.addeffe(function(params)
						if e and e:Exists() then e:GetSprite().Scale = Vector(i / cnt,i / cnt) end
					end,{},i)
				end
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_SUPERHOLY,1.2,1,false,0,2)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local rng = player:GetCardRNG(cardtype)
	local room = Game():GetRoom()
	rng = auxi.rng_for_sake(rng)
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		local q = Isaac.Spawn(6,17,0,room:FindFreePickupSpawnPosition(room:FindFreeTilePosition(player.Position,10),10,true),Vector(0,0),player)
		local e = Isaac.Spawn(1000,15,0,q.Position,Vector(0,0),q)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SUMMONSOUND,1.2,1,false,0,2)
	else
		local q = Isaac.Spawn(6,17,0,room:FindFreePickupSpawnPosition(room:FindFreeTilePosition(player.Position,10),10,true),Vector(0,0),player)
		local e = Isaac.Spawn(1000,15,0,q.Position,Vector(0,0),q)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SUMMONSOUND,1.2,1,false,0,2)
	end
end,
})

return item
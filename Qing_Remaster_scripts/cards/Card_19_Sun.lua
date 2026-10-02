local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Sun,
	own_key = "Thoth_cd19_Sun_",
}

local function get_state()
	local effect_key = item.own_key .. "effect"
	local effect2_key = item.own_key .. "effect2"
	local effects = save.elses[effect_key]
	if type(effects) ~= "table" then
		effects = {}
		save.elses[effect_key] = effects
	end
	local cloth = save.elses[effect2_key]
	if type(cloth) ~= "table" then
		cloth = {}
		save.elses[effect2_key] = cloth
	end
	return effects, cloth
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if not continue then
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."effect2"] = {}
	end
	get_state()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = {}
	save.elses[item.own_key.."effect2"] = {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		d[item.own_key.."effect"] = {}
		d[item.own_key.."counter"] = 0
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local _, cloth = get_state()
	if #(d[item.own_key.."effect"] or {}) > 0 then
		if player:IsExtraAnimationFinished() then
			player:UseCard(d[item.own_key.."effect"][1].id,0)
			table.remove(d[item.own_key.."effect"],1)
			d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
			if d[item.own_key.."counter"] == 3 then
				local q = Isaac.Spawn(5,300,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
			end
			if cloth[idx] and d[item.own_key.."counter"] == 10 then
				local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				--q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
			end
		end
	else
		if d[item.own_key.."counter"] then d[item.own_key.."counter"] = nil end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = nil,
Function = function(_,cardtype,player,useFlags)
	if cardtype == item.entity then return end
	local d = player:GetData()
	local idx = d.__Index
	local effects = get_state()

	-- Only pocket-slot uses count. Sun replays via UseCard(..., 0) and other
	-- synthetic fires must not refill room history.
	if useFlags & UseFlag.USE_OWNED == UseFlag.USE_OWNED
		and (useFlags & UseFlag.USE_CARBATTERY ~= UseFlag.USE_CARBATTERY) then
		effects[idx] = effects[idx] or {}
		table.insert(effects[idx],#effects[idx] + 1,{id = cardtype,})
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local effects, cloth = get_state()
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then cloth[idx] = true end
		effects[idx] = effects[idx] or {}
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		for i = 1,#effects[idx] do
			local v = effects[idx][i]
			if v.id ~= cardtype then
				table.insert(d[item.own_key.."effect"],#d[item.own_key.."effect"] + 1,{id = v.id})
			end
		end
		effects[idx] = {}
	end
end,
})

return item

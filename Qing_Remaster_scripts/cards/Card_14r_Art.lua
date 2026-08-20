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
	entity = enums.Cards.Art_r,
	own_key = "Thoth_cd14r_Art_",
	colors = {
		[1] = Color(1,0,0,0.7,0.5,0,0),
		[2] = Color(1,0.1,0.5,0.7,0.5,0,0.2),
		[3] = Color(1,0,1,0.7,0.2,0,0.2),
		[4] = Color(0.4,0,1,0.7,0,0,0.3),
		[5] = Color(0,0.5,1,0.7,0,0.2,0.5),
		[6] = Color(0.5,0.5,0,0.7,0.2,0.2,0),
		[7] = Color(0.4,0.6,0,0.8,0.1,0.3,0),
		[8] = Color(1,1,0,0.7,0.5,0.4,0),
		[9] = Color(1,0.7,0,0.7,0.5,0.2,0),
		[10] = Color(1,1,1,0.7,0,0,0),
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = 0
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or 0
	save.elses[item.own_key.."counter"] = 0.7
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = 0
	save.elses[item.own_key.."counter"] = 0.7
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 300,
Function = function(_,ent)
	if ent.SubType == item.entity then
		local d = ent:GetData()
		d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
		if d[item.own_key.."counter"] == 30 * 4.5 then 
			d[item.own_key.."color"] = auxi.random_in_table(item.colors)
			ent:SetColor(d[item.own_key.."color"],30,50,true,false)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_WAR_BOMB_TICK,1,1,false,0,2)
		end
		if d[item.own_key.."counter"] > 30 * 6 then
			d[item.own_key.."counter"] = nil
			Game():BombExplosionEffects(ent.Position,10,BitSet128(0,0),d[item.own_key.."color"] or auxi.random_in_table(item.colors),ent)
			ent:Morph(5,300,item.entity,true,true,true)
			ent.Velocity = auxi.RoundVector(ent:GetDropRNG(),5)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = nil,
Function = function(_,ent)
	if ent.Type ~= 1000 and Game():GetRoom():GetFrameCount() ~= 0 then
		if save.elses[item.own_key.."effect"] and save.elses[item.own_key.."effect"] ~= 0 then
			local should_do = true
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				if (player.Position - ent.Position):Length() < 50 then
					should_do = false
					break
				end
			end
			if should_do then
				local dmgself = true
				if save.elses[item.own_key.."effect"] == 2 then dmgself = false end
				local player = save.elses[item.own_key.."player"] or Game():GetPlayer(0)
				if player:Exists() == false or player:IsDead() then player = Game():GetPlayer(0) end
				if player == nil or player:Exists() == false or player:IsDead() then player = Game():GetPlayer(0) end
				save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or 0.7
				Game():BombExplosionEffects(ent.Position,player.Damage * 2,player.TearFlags,player.TearColor,player,save.elses[item.own_key.."counter"],false,dmgself)	
				save.elses[item.own_key.."counter"] = math.min(2,save.elses[item.own_key.."counter"] + 0.1)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local rng = player:GetCardRNG(cardtype)
	rng = auxi.rng_for_sake(rng)
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		save.elses[item.own_key.."effect"] = 1
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			save.elses[item.own_key.."effect"] = 2
		end
		save.elses[item.own_key.."player"] = player
	end
end,
})

return item
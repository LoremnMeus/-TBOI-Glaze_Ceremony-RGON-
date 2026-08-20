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
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Moon_r,
	own_key = "Thoth_cd18r_Moo_",
	init_sound = 1,
	color = Color(0.5,0.1,0.5,1),
	coloring_effect = {
		[5] = true,
		[7] = true,
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item[item.own_key.."effect"] = nil
	item[item.own_key.."sound"] = math.min(item.init_sound,Options.MusicVolume)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = nil,
Function = function(_,ent)
	if item.coloring_effect[ent.Variant] then
		local color = item.color
		ent:SetColor(color,10,99,false,false)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = nil,
Function = function(_,ent)
	if Game():GetRoom():GetFrameCount() > 1 and item[item.own_key.."effect"] then
		local ti = 1
		if item[item.own_key.."effect"] == 1 then ti = 2 * 60 * 30
		elseif item[item.own_key.."effect"] == 2 then ti = 9999 * 60 * 30 end
		Attribute_holder.try_hold_and_rewind_attribute(ent,"ENTITY_FLAG_FLAG_FEAR",true,ti,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FEAR))
		local color = item.color
		Attribute_holder.try_hold_and_rewind_attribute(ent,"Color",color,ti,Attribute_holder.descriptors.color())		--重载不等号
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_,ent)
	if Game():GetRoom():GetFrameCount() > 1 and item[item.own_key.."effect"] then
		if ent:HasEntityFlags(EntityFlag.FLAG_FEAR) then
			local rng = ent:GetDropRNG()
			rng = auxi.rng_for_sake(rng)
			if rng:RandomInt(100) > 95 then
				local q = Isaac.Spawn(5,300,item.entity,ent.Position,Vector(0,0),nil):ToPickup()
				q:Morph(5,300,item.entity,true,true,true)
			end
			item[item.own_key.."sound"] = math.min(3,(item[item.own_key.."sound"] or item.init_sound) + 0.2)
			if MusicManager():GetCurrentMusicID() == enums.Music.Weapon_A then
			else
				MusicManager():Play(enums.Music.Weapon_A, item[item.own_key.."sound"])
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
	if item[item.own_key.."effect"] then
		if ent:HasEntityFlags(EntityFlag.FLAG_FEAR) then
			if flag & DamageFlag.DAMAGE_CLONES == 0 and amt ~= 0 then
				ent:TakeDamage(amt * 2,flag | DamageFlag.DAMAGE_CLONES,source,cooldown)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS,0.7 + math.random(1000)/1000 * 0.7,0.8 + math.random(1000)/1000 * 0.4,false,0,2)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local n_entity = Isaac.GetRoomEntities()
	local n_enemy = auxi.getenemies(n_entity)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		item[item.own_key.."sound"] = item[item.own_key.."sound"] or item.init_sound
		MusicManager():Play(enums.Music.Weapon_A, item[item.own_key.."sound"])
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			for u,v in pairs(n_enemy) do	
				local ti = 9999 * 60 * 30
				Attribute_holder.try_hold_and_rewind_attribute(v,"ENTITY_FLAG_FLAG_FEAR",true,ti,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FEAR))
				local color = item.color
				Attribute_holder.try_hold_and_rewind_attribute(v,"Color",color,ti,Attribute_holder.descriptors.color())		--重载不等号
			end
			for playerNum = 1, Game():GetNumPlayers() do
				local t_player = Game():GetPlayer(playerNum - 1)
				t_player:AddFear(EntityRef(player),20 * 30)
			end
			item[item.own_key.."effect"] = 2
		else
			for u,v in pairs(n_enemy) do
				local ti = 2 * 60 * 30
				Attribute_holder.try_hold_and_rewind_attribute(v,"ENTITY_FLAG_FLAG_FEAR",true,ti,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FEAR))
				local color = item.color
				Attribute_holder.try_hold_and_rewind_attribute(v,"Color",color,ti,Attribute_holder.descriptors.color())		--重载不等号
			end
			for playerNum = 1, Game():GetNumPlayers() do
				local t_player = Game():GetPlayer(playerNum - 1)
				t_player:AddFear(EntityRef(player),10 * 60)
			end
			item[item.own_key.."effect"] = 1
		end
	end
end,
})


return item
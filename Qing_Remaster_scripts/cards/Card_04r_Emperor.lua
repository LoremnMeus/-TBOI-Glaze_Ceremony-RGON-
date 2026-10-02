local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local danger_data = require("Qing_Remaster_scripts.others.Danger_Data")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Emperor_r,
	own_key = "Thoth_cd4r_Emp_",
	sounds = {
		[1] = {id = 11,vol = 2,pit = 0.75,},
		[2] = {id = 12,vol = 2,pit = 0.75,},
	},
	musics = {
		[1] = {id = Music.MUSIC_BOSS,},
		[2] = {id = Music.MUSIC_BOSS2,},
		[3] = {id = Music.MUSIC_BOSS3,},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then 
		danger_data.spawn_by_info(ent,danger_data.check_data(ent),true,function(ent) 
			ent:AddEntityFlags(EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_PERSISTENT | EntityFlag.FLAG_CHARM)
		end)
		d[item.own_key.."effect"] = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local min_level = 1
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			min_level = 2
		end
		local q = Isaac.Spawn(74,0,0,room:GetCenterPos(),Vector(0,0),nil):ToNPC()
		local infos = danger_data.check_and_morph_ent(q, true, {
			health_alpha = 1,
			ignore_hard = true,
			min_level = min_level,
			max_level = 4.5,
		})
		q:Remove()
		local q = infos.signon
		q:GetData()[item.own_key.."effect"] = true
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if (door) then
				door:Close()
			end
		end
		local music_info = auxi.random_in_weighed_table(auxi.deepCopy(item.musics),rng)
		MusicManager():Play(music_info.id,Options.MusicVolume)
	end
end,
})


return item
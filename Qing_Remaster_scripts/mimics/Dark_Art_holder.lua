local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local tear_trigger_holder = require("Qing_Remaster_scripts.callbacks.tear_trigger_holder")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Dark_Art_holder_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent, amt, flag, source, cooldown)
	if flag & DamageFlag.DAMAGE_CLONES ~= 0 and ent:ToNPC() then
		if source.Type == EntityType.ENTITY_EFFECT and source.Variant == EffectVariant.DARK_SNARE then
			if source.Entity and source.Entity.SpawnerEntity and source.Entity.SpawnerEntity.Type == EntityType.ENTITY_PLAYER then
				local player = source.Entity.SpawnerEntity:ToPlayer()
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = EffectVariant.DARK_SNARE,
Function = function(_,ent)
	if ent.FrameCount == 1 and ent.SpawnerEntity and ent.SpawnerEntity.Type == EntityType.ENTITY_PLAYER then
		local player = ent.SpawnerEntity:ToPlayer()
		tear_trigger_holder.trigger_tear("Darkart",ent,nil,player,player.Velocity)
	end
end,
})

return item
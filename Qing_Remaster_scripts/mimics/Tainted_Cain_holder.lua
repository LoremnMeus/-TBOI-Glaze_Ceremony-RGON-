local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local item = {
	post_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Tainted_Cain_holder_",
}

function item.add_touchable(ent)
	consistance_holder.try_hold_entity(ent,item.own_key,{ignore_subtype = true,})
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 100,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	if player and player:GetPlayerType() == PlayerType.PLAYER_CAIN_B then
		local colinfo = Isaac.GetItemConfig():GetCollectible(ent.SubType)
		if colinfo and consistance_holder.try_check_entity(ent,item.own_key) then 
			if player:IsExtraAnimationFinished() and player:IsItemQueueEmpty() then
				if auxi.REPENTENCE_PLUS() then
					player:AddCollectible(colinfo.ID, ent.Charge,not ent.Touched)  -- 新版本使用AddCollectible
				else
					player:QueueItem(colinfo, ent.Charge, ent.Touched)  -- 旧版本保持QueueItem
				end
				player:AnimateCollectible(ent.SubType,"Pickup","PlayerPickupSparkle")
				auxi.remove_others_option_pickup(ent)
				auxi.try_start_ambush()
				ent.SubType = 0
				local s = ent:GetSprite()
				s:ReplaceSpritesheet(1,"gfx/effects/nill.png")
				s:LoadGraphics()
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2)
			else
				return false
			end
		end
	end
end,
})

return item

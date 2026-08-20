local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local glaze_curse = require("Qing_Remaster_scripts.pickups.pickup_glaze_curse")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")
local glaze_crown = require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze")

local item = {
	pickup = enums.Pickups.Glaze_big_poop,
	ToCall = {},
}

local poop_ui = Sprite()
poop_ui:Load("gfx/Glaze/glazed_poop.anm2", true)
poop_ui:Play("Idle",true)
poop_ui.Scale = Vector(0.5,0.5)
local frame = 0

function item.try_collect(player,ent)
	if ent:IsShopItem() and auxi.check_shop_pickup(ent,player) then return nil end
	if glaze_crown.should_empower(player) then
		save.elses.poop_counter = math.min(2,save.elses.poop_counter + 1)
	else
		save.elses.poop_counter = 1		
	end
	if auxi.has_poop_player() then player:AddPoopMana(2) end
	glaze_crown.notify_pickup(player)
	return true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	if amt > 0 and auxi.is_damage_from_enemy(ent, amt, flag, source, cooldown) then
		local player = ent:ToPlayer()
		local rng = player:GetDropRNG()
		rng = auxi.rng_for_sake(rng)
		if player then
			if save.elses.poop_counter and save.elses.poop_counter > 0 then
				player:UsePoopSpell(rng:RandomInt(11) + 1)
				save.elses.poop_counter = 0
			end
		end
	end
end,
})


table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_,shadername)
	if shadername == "Qing_HelpfulShader" then
		if save.elses.poop_counter and save.elses.poop_counter > 0 and Game():GetHUD():IsVisible() then
			if Game():IsPaused() == false then
				frame = frame + 1
			else
				frame = frame - 1
			end
			if frame > 47 then frame = 0 end
			if frame < 0 then frame = 47 end
			poop_ui:SetFrame(frame)
			local pos = ui.UIPoopPos(auxi.is_double_player())
			poop_ui.Color = Color(1,1,1,slot_render_holder.get_alpha())
			poop_ui:Render(pos,Vector(0,0),Vector(0,0))
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
    if continue then
	else
		save.elses.poop_counter = 0
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = item.pickup.Variant,
Function = function(_,ent, col, low)
    local player = col:ToPlayer()
	if ent.SubType == item.pickup.SubType then
		if player then
			local should_collect = item.try_collect(player,ent)
			if should_collect == true then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_PING_PONG,1,1,false,0,2)
				glaze_curse.cast_a_glaze(player,ent)
				ent.Velocity = Vector(0,0)
				ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BATTERYDISCHARGE,1,1,false,0,2)
				auxi.remove_others_option_pickup(ent)
				if ent:IsShopItem() then auxi.buy_a_pickup(ent,player)
				else ent:GetSprite():Play("Collect", true) end
				return true
			elseif ent:IsShopItem() then return nil 
			else return false end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = item.pickup.Variant,
Function = function(_,ent)
	if ent.SubType == item.pickup.SubType then
		if ent:GetSprite():IsEventTriggered("DropSound") then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_SPLATTER,1,1,false,0,2)
		end
		if ent:GetSprite():IsFinished("Collect") or ent:GetSprite():IsEventTriggered("Remove") then
			ent:Remove()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 42,
Function = function(_,ent)
	if Unlocker.should_any_be_done("Pickup","Glaze_Poop",nil,"Pickup_allow") then
		if ent.SubType == 1 then
			local rng = ent:GetDropRNG()
			rng = auxi.rng_for_sake(rng)
			if glaze_crown.roll_convert(rng, 60) then		-- 原 1/60
				ent:Morph(5,item.pickup.Variant,item.pickup.SubType,true)
			end
		end
	end
end,
})

return item
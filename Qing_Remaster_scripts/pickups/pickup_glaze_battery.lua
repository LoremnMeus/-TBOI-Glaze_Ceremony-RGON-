local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local glaze_curse = require("Qing_Remaster_scripts.pickups.pickup_glaze_curse")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")
local glaze_crown = require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze")

local item = {
	pickup = enums.Pickups.Glaze_battery,
	ToCall = {},
	myToCall = {},
	own_key = "Pickup_Glaze_battery_",
	available_slot = {
		[0] = true,
		[2] = true,
	},
	ignore_cid = {
		[489] = true,
	},
}

local frame = 0
local charge_ui2 = Sprite()
charge_ui2:Load("gfx/Glaze/glazed_charge_bar.anm2", true)
charge_ui2:Play("Idle",true)
charge_ui2.Scale = Vector(1,1)

function item.try_collect(ent,player)
	if ent:IsShopItem() and auxi.check_shop_pickup(ent,player) then return nil end
	local charge = 0
	local has_active = nil
	for i = 0,3 do
		if player:GetActiveItem(i) > 0 then has_active = true end
		if player:GetActiveCharge(i) > 0 and player:GetActiveCharge(i) <= 12 then
			charge = charge + player:GetActiveCharge(i) + player:GetBatteryCharge(i)
			player:SetActiveCharge(0,i)
		elseif player:GetActiveCharge(i) > 0 then
			charge = charge + 1
			if player:GetBatteryCharge(i) > 0 then charge = charge + 1 end
			player:SetActiveCharge(0,i)
		end
	end
	if has_active then
		if charge == 0 then charge = 1 end
		save.elses.glaze_battery = math.min(64,(save.elses.glaze_battery or 0) + charge)
		glaze_crown.notify_pickup(player)
		return true
	end
	return nil
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = item.pickup.Variant,
Function = function(_,ent, col, low)
	if ent.SubType == item.pickup.SubType then
		local player = col:ToPlayer()
		if player then
			local should_collect = item.try_collect(ent,player)
			if should_collect then
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

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
    if continue then
	else
		save.elses.glaze_battery = 0
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = item.pickup.Variant,
Function = function(_,ent)
	if ent.SubType == item.pickup.SubType then
		if ent:GetSprite():IsEventTriggered("DropSound") then end
		if ent:GetSprite():IsFinished("Collect") or ent:GetSprite():IsEventTriggered("Remove") then	ent:Remove() return end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,ent)
	if save.elses.glaze_battery and save.elses.glaze_battery > 0 then
		local succ = false
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local should_spawn = false
			for i = 0,3 do
				if player:NeedsCharge(i) then
					if glaze_crown.should_empower(player) then player:SetActiveCharge(player:GetActiveCharge(i) + player:GetBatteryCharge(i) + 3,i)
					else player:SetActiveCharge(player:GetActiveCharge(i) + player:GetBatteryCharge(i) + 2,i) end
					should_spawn = true
					succ = true
				end
			end
			if should_spawn then
				local q = Isaac.Spawn(1000,EffectVariant.BATTERY,0,player.Position + Vector(0,-30) * player.SpriteScale.Y + player.Velocity,Vector(0,0),nil)
				local s = q:GetSprite()
				q.DepthOffset = 1000
				s:ReplaceSpritesheet(0,"gfx/effects/effect_glazed_batteryeffect.png")
				s:LoadGraphics()
			end
		end
		if succ then sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE,1.5,1,false,0,2) end
		if glaze_crown.any_complete() or succ then
			save.elses.glaze_battery = save.elses.glaze_battery - 1
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 90,
Function = function(_,ent)
	if Unlocker.should_any_be_done("Pickup","Glaze_Battery",nil,"Pickup_allow") then
		if ent.SubType == 1 or ent.SubType == 2 then
			local rng = ent:GetDropRNG()
			rng = auxi.rng_for_sake(rng)
			if glaze_crown.roll_convert(rng, 20) then		-- 原 1/20
				ent:Morph(5,item.pickup.Variant,item.pickup.SubType,true)
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_,player,tp,cid,slot)
	if save.elses.glaze_battery and save.elses.glaze_battery > 0 and item.available_slot[slot] and not item.ignore_cid[cid] then
		local pos = ui.PlayerActiveUIPos(player,slot,auxi.GetPlayerOrder(player),cid)
		local s = auxi.load_item(cid,{Anm = "gfx/Glaze/glazed_item2.anm2",})
		s:SetFrame(frame or 0)
		s.Color = Color(1,1,1,slot_render_holder.get_alpha())
		s:Render(pos,Vector(0,0),Vector(0,0))
		--[[
		local colinfo = Isaac.GetItemConfig():GetCollectible(cid)
		if collectible and collectible.MaxCharges ~= 0 then
			local posinfo = pos + Vector(18,1)
			charge_ui2:SetFrame(frame)
			charge_ui2.Color = Color(1,1,1,slot_render_holder.get_alpha())
			charge_ui2:Render(posinfo,Vector(0,0),Vector(0,0))
		end
		--]]
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_SLOT_RENDER, params = "Active",
Function = function(_,player,tp,cid,slot)
	if save.elses.glaze_battery and save.elses.glaze_battery > 0 and item.available_slot[slot] and not item.ignore_cid[cid] then
		local pos = ui.PlayerActiveUIPos(player,slot,auxi.GetPlayerOrder(player),cid)
		local s = auxi.load_item(cid,{Anm = "gfx/mimics/Glaze_Item/glazed_item.anm2",})
		
		local alpha = slot_render_holder.get_alpha()
		for i = 1,save.elses.glaze_battery do
			local tg_fr = frame + math.ceil(i * 48 / save.elses.glaze_battery)
			while tg_fr > 47 do tg_fr = tg_fr - 48 end
			s:SetFrame(tg_fr or 0)
			local id = 35 - i 
			if id < 0 then id = id + 48 end
			s.Color = Color(1,1,1,alpha * (0.5 + 0.5/save.elses.glaze_battery * id))
			s.Scale = Vector(0.65,0.65)
			s:Render(pos - 15 * auxi.MakeVector(360/save.elses.glaze_battery * i + 90),Vector(0,0),Vector(0,0))
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	if save.elses.glaze_battery and save.elses.glaze_battery > 0 and Game():GetHUD():IsVisible() then
		if Game():IsPaused() == false then frame = frame + 1
		else frame = frame - 1 end
		if frame > 47 then frame = 0 end
		if frame < 0 then frame = 48 end
	end
end,
})

--[[
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_,name)
	if name == "Qing_HelpfulShader" then
		if save.elses.glaze_battery and save.elses.glaze_battery > 0 and Game():GetHUD():IsVisible() then
			local player = Game():GetPlayer(0)
			local item = player:GetActiveItem(0)
			local item2 = player:GetActiveItem(2)
			local collectible = Isaac.GetItemConfig():GetCollectible(item)
			local collectible2 = Isaac.GetItemConfig():GetCollectible(item2)
			if collectible and collectible.MaxCharges ~= 0 then			--娓叉煋鍏呰兘妲?
				local pos = ui.UIChargeBarPos(0)
				if (player:HasCollectible(584) and item ~= 584) or (player:HasCollectible(59) and item ~= 59)then
					pos = pos + Vector(0,3)
				end
				charge_ui2:SetFrame(frame)
				charge_ui2.Color = Color(1,1,1,slot_render_holder.get_alpha())
				charge_ui2:Render(pos,Vector(0,0),Vector(0,0))
			end
			if player:GetCard(0) == 0 and player:GetPill(0) == 0 and collectible2 and collectible2.MaxCharges ~= 0 then
				local pos = ui.UIChargeBarPos(2)
				charge_ui2:SetFrame(frame)
				charge_ui2.Color = Color(1,1,1,slot_render_holder.get_alpha())
				charge_ui2:Render(pos,Vector(0,0),Vector(0,0))
			elseif Game():GetNumPlayers() > 1 then
				local player = Game():GetPlayer(1)
				if player and player.ControllerIndex == 0 then		--拥有主动的非主角色人物
					local item3 = player:GetActiveItem(0)
					local collectible3 = Isaac.GetItemConfig():GetCollectible(item3)
					if item3 and item3 ~= 0 and collectible3 and collectible3.MaxCharges ~= 0 then
						local pos = ui.UIChargeBarPos(1)
						charge_ui2:SetFrame(frame)
						charge_ui2.Color = Color(1,1,1,slot_render_holder.get_alpha())
						charge_ui2:Render(pos,Vector(0,0),Vector(0,0))
					end
				end
			end
		end
	end
end,
})
--]]

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = CollectibleType.COLLECTIBLE_GENESIS,
Function = function(_,collect,rng,player,useFlags,activeSlot,varData)
	save.elses.glaze_battery = 0
end,
})

return item
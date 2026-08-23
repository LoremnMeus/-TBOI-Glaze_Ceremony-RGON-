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

local function first_poop_player(prefer)
	if prefer and auxi.is_poop_player(prefer) then return prefer end
	for i = 1,Game():GetNumPlayers() do
		local p = Game():GetPlayer(i - 1)
		if auxi.is_poop_player(p) then return p end
	end
	return prefer
end

function item.try_collect(player,ent)
	if ent:IsShopItem() and auxi.check_shop_pickup(ent,player) then return nil end
	local target = first_poop_player(player)
	if target and auxi.is_poop_player(target) and target.GetPoopSpell and target.SetPoopSpell then
		local none = (PoopSpellType and PoopSpellType.SPELL_NONE) or 0
		local basic = (PoopSpellType and PoopSpellType.SPELL_POOP) or 1
		local copy = target:GetPoopSpell(0)
		if not copy or copy == none then
			target:SetPoopSpell(0,basic)
			if target.AddPoopMana then target:AddPoopMana(1) end
		else
			local slot = nil
			for i = 1,5 do
				local sp = target:GetPoopSpell(i)
				if not sp or sp == none then slot = i break end
			end
			if target.AddPoopMana then target:AddPoopMana(1) end
			target:SetPoopSpell(slot or 5,copy)
		end
	end
	glaze_crown.notify_pickup(player)
	return true
end

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
		if not auxi.has_poop_player() then return end
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
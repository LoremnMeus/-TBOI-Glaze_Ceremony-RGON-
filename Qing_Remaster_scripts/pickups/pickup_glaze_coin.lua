local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local glaze_curse = require("Qing_Remaster_scripts.pickups.pickup_glaze_curse")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local glaze_crown = require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze")

local translations = include("Qing_Remaster_scripts.translations.translate")

local item = {
	pickup = enums.Pickups.Glaze_coin,
	ToCall = {},
	own_key = "Pickup_glaze_coin_",
}

function item.load_EID(ent)
	if not ent or not EID then return end
	local texts = translations.get_pickup_by_key("Glaze_Coin", auxi.get_EID_language())
	if not texts then return end
	ent:GetData().EID_Description = {
		Name = texts.Name,
		Description = texts.Description,
	}
end

item.pickup.load_EID = item.load_EID

function item.try_collect(player,ent)
	if ent:IsShopItem() and auxi.check_shop_pickup(ent,player) then return nil end
	if glaze_crown.should_empower(player) then
		if math.random(1000) > 100 then
			player:AddCoins(1)
			ent:GetData()[item.own_key.."sound"] = 1
		else
			player:AddCoins(15)
			ent:GetData()[item.own_key.."sound"] = 2
		end
	else
		if math.random(1000) > 100 then
			player:AddCoins(1)
			ent:GetData()[item.own_key.."sound"] = 1
		else
			player:AddCoins(5)
			ent:GetData()[item.own_key.."sound"] = 2
		end
	end
	glaze_crown.notify_pickup(player)
	return true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = item.pickup.Variant,
Function = function(_,ent, col, low)
    local player = col:ToPlayer()
	if ent.SubType == item.pickup.SubType then
		consistance_holder.try_check_entity(ent,"Glaze_Coin")
		if item.pickup.special_to_check(ent) then
			if player then
				local should_collect = item.try_collect(player,ent)
				if should_collect == true then
					glaze_curse.cast_a_glaze(player,ent)
					ent.Velocity = Vector(0,0)
					ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
					if ent:GetData()[item.own_key.."sound"] ~= 2 then sound_tracker.PlayStackedSound(SoundEffect.SOUND_PENNYPICKUP,1,1,false,0,2)
					else sound_tracker.PlayStackedSound(SoundEffect.SOUND_DIMEPICKUP,1,1,false,0,2)	end
					auxi.remove_others_option_pickup(ent)
					if ent:IsShopItem() then auxi.buy_a_pickup(ent,player)
					else ent:GetSprite():Play("Collect", true) end
					return true
				elseif ent:IsShopItem() then return nil 
				else return false end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = item.pickup.Variant,
Function = function(_,ent)
	if ent.SubType == item.pickup.SubType then
		local d = ent:GetData()
		local s = ent:GetSprite()
		consistance_holder.try_check_entity(ent,"Glaze_Coin")
		if item.pickup.special_to_check(ent) then
			if d.Loaded_EID == nil then
				item.load_EID(ent)
				d.Loaded_EID = true
			end
			if s:GetFilename() ~= "gfx/Glaze/glaze_coin.anm2" then
				local name1 = s:GetAnimation()
				local name2 = s:GetOverlayAnimation()
				s:Load("gfx/Glaze/glaze_coin.anm2",true)
				s:Play(name1,true)
				s:PlayOverlay(name2,true)
			end
			if s:IsEventTriggered("DropSound") then
				if math.random(3) == 1 then
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_PENNYDROP,1,1,false,0,2)
				elseif math.random(2) == 1 then
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_NICKELDROP,1,1,false,0,2)
				else
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_DIMEDROP,1,1,false,0,2)
				end
			end
			if s:IsFinished("Collect") or s:IsEventTriggered("Remove") then
				ent:Remove()
			end
			if s:IsEventTriggered("Attract") then
				local n_entity = Isaac.GetRoomEntities()
				local pick_up = auxi.getothers(n_entity,5)
				for i = 1,#pick_up do
					if pick_up[i]:ToPickup():IsShopItem() == false then
						local dir = (ent.Position - pick_up[i].Position)
						if dir:Length() > 10 then
							dir = dir:Normalized()
						else
							dir = dir/10
						end
						pick_up[i]:AddVelocity(dir)
						ent:AddVelocity(-dir/4)
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 20,
Function = function(_,ent)
	if Unlocker.should_any_be_done("Pickup","Glaze_Coin",nil,"Pickup_allow") then
		if ent.SubType == 1 or ent.SubType == 3 then
			local rng = ent:GetDropRNG()
			rng = auxi.rng_for_sake(rng)
			if glaze_crown.roll_convert(rng, 40) then		-- 原 1/40，持有冠冕后按生成倍率提高
				auxi.special_morph(ent,item.pickup,true,false,false)
			end
		end
	end
end,
})

glaze_crown.install_glaze_crown_pickup_eid(item.pickup, {
	zh = "辉片满层时：90%获得1枚，10%获得15枚",
	en = "At 5 shards: 90% for 1 coin, 10% for 15",
}, function(desc)
	return desc.Entity and item.pickup.special_to_check(desc.Entity)
end)

return item
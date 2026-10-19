local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local glaze_curse = require("Qing_Remaster_scripts.pickups.pickup_glaze_curse")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local glaze_crown = require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")

local item = {
	pickup = enums.Pickups.Glaze_grabbag,
	ToCall = {},
	own_key = "Pickup_Glaze_Grabbag_",
	check_info = {
		Glaze_key = {weigh = 1,check = function(player) return (player:GetNumKeys() > 0) end,
			get = function(player) player:AddKeys(-1) end,},
		Glaze_bomb = {weigh = 1,check = function(player) return (player:GetNumBombs() > 0) end,
			get = function(player) player:AddBombs(-1) end,},
		Glaze_coin = {weigh = 0.5,check = function(player) return (player:GetNumCoins() > 0) end,
			get = function(player) player:AddCoins(-1) end,},
	},
}

function item.try_collect(player,ent)
	if ent:IsShopItem() and auxi.check_shop_pickup(ent,player) then return nil end
	local rng = ent:GetDropRNG()
	rng = auxi.rng_for_sake(rng)
	local cnt = rng:RandomInt(2) + 2
	if glaze_crown.should_empower(player) then cnt = 3 end
	local allow = {Glaze_key = true, Glaze_bomb = true, Glaze_coin = true}
	for i = 1,cnt do
		local tbl = {}
		for u,v in pairs(enums.Pickups) do
			if allow[u] then
				local info = item.check_info[u] or {}
				if auxi.check_if_any(info.check,player,item) then
					table.insert(tbl,#tbl+1,{weigh = (v.weigh or 1),name = u,})
				end
			end
		end
		if #tbl == 0 then
			if i == 1 then
				local tg = enums.Pickups.Glaze_big_poop
				local q = Isaac.Spawn(5,tg.Variant,tg.SubType,ent.Position,auxi.RoundVector(rng,3),player):ToPickup()
				auxi.special_morph(q,tg)
			end
			break
		else
			local tg = auxi.random_in_weighed_table(tbl,rng)
			-- 有便便角色时：炸弹转化结果改为琉璃便便，但仍按炸弹扣除库存。
			local cost_name = tg.name
			local spawn_name = tg.name
			if tg.name == "Glaze_bomb" and auxi.has_poop_player() then
				spawn_name = "Glaze_big_poop"
			end
			local info = item.check_info[cost_name] or {}
			auxi.check_if_any(info.get,player,item)
			local ttg = enums.Pickups[spawn_name]
			local q = Isaac.Spawn(5,ttg.Variant,ttg.SubType,ent.Position,auxi.RoundVector(rng,3),player):ToPickup()		--此法生成的不会被替换
			auxi.special_morph(q,ttg)
		end
	end
	auxi.try_start_ambush()
	glaze_crown.notify_pickup(player, ent and ent.Position)
	return true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = item.pickup.Variant,
Function = function(_,ent, col, low)
    local player = col:ToPlayer()
	if ent.SubType == item.pickup.SubType then
		if player then
			local should_collect = item.try_collect(player,ent)
			if should_collect == true then
				glaze_curse.cast_a_glaze(player,ent)
				ent.Velocity = Vector(0,0)
				ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME,1,1,false,0,2)
				option_index_holder.commit_selection(ent, player, {
					skip_will_collect = true,
					remove_siblings = true,
				})
				if ent:IsShopItem() then auxi.buy_a_pickup(ent,player)
				else ent:GetSprite():Play("Collect",true) end
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
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_FETUS_JUMP,1,1,false,0,2)
		end
		if ent:GetSprite():IsFinished("Collect") or ent:GetSprite():IsEventTriggered("Remove") then
			ent:Remove()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 69,
Function = function(_,ent)
	if Unlocker.should_any_be_done("Pickup","Glaze_Grabbag",nil,"Pickup_allow") then
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

glaze_crown.install_glaze_crown_pickup_eid(item.pickup, {
	zh = "辉片满层时固定生成3份（否则为2-3份）",
	en = "At 5 shards: always 3 conversions (otherwise 2-3)",
})

return item

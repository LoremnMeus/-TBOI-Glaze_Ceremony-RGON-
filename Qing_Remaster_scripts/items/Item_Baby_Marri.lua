local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local AI = require("Qing_Remaster_scripts.bosses.Boss_All")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local Baby_Anim = require("Qing_Remaster_scripts.others.Baby_Anim_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Baby_Marri,
	familiar = enums.Familiars.Baby_Marri,
	own_key = "Item_Baby_Marri_",
	cnt2mxn = {
		{frame = 0,val = 10,},
		{frame = 2,val = 7,},
		{frame = 10,val = 5,},
		{frame = 40,val = 3,},
		{frame = 80,val = 2,},
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_, ent)
	local player = auxi.check_spawner_player(ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if not d[item.own_key.."IsFollow"] then
		ent:AddToFollowers()
		d[item.own_key.."IsFollow"] = true
	end
	d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
	local cnt = d[item.own_key.."effect"].cnt or 0
	local mxn = auxi.check_lerp(cnt,item.cnt2mxn).val
	if player:HasTrinket(TrinketType.TRINKET_FORGOTTEN_LULLABY) then mxn = mxn * 0.75 end
	
	local dirinfo = auxi.get_by_familiar_dir(ent)
	d[item.own_key.."effect"].counter = d[item.own_key.."effect"].counter or 0
	if d[item.own_key.."effect"].counter < mxn then 
		d[item.own_key.."effect"].counter = d[item.own_key.."effect"].counter + 1
	end
	if d[item.own_key.."effect"].counter >= mxn then 
		if dirinfo.dir:Length() > 0.05 then
			item.fire_attack(ent,dirinfo.dir)
		end
		d[item.own_key.."effect"].counter = 0
	end

	Baby_Anim.tick_float_idle(ent, item.own_key.."float")
	ent:FollowParent()
end
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_,ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if player then
		local tgs = auxi.getothers(nil,3,item.familiar)
		for u,v in pairs(tgs) do
			local tgplayer = v.Player
			if auxi.check_for_the_same(tgplayer,player) then
				local d = v:GetData()
				d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
				d[item.own_key.."effect"].cnt = (d[item.own_key.."effect"].cnt or 0) + 1
			end
		end
	end
end
})

function item.fire_attack(ent,dir)
	local player = ent.Player or Isaac.GetPlayer(0)
	local q = Isaac.Spawn(2,0,0,ent.Position,dir:Normalized() * 7,ent):ToTear()
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BFFS) then 
		q.CollisionDamage = q.CollisionDamage * 2 
	end
	if player:HasTrinket(TrinketType.TRINKET_BABY_BENDER) then 
		q.TearFlags = q.TearFlags | BitSet128(1<<2,0)
	end
end

return item
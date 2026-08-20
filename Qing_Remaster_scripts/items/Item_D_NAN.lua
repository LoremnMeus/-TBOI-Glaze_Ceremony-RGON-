local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")

local item = {
	ToCall = {},
	post_ToCall = {},
	entity = enums.Items.D_NAN,
	own_key = "Item_D_NAN_",
	Colorinfo = {
		{frame = 0 * 18,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 18,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 18,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 18,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 18,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 18,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		
		{frame = 6 * 18,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 18,
	},
}

function item.reroll_items(player)
	local n_item = auxi.getothers(Isaac.GetRoomEntities(),5,100)
	local tbl = {}
	for u,v in pairs(n_item) do
		local ent = v:ToPickup()
		local id = ent.SubType
		if id > 2^31 and id < 2^32 then 
			local colid = 0
			if auxi.should_do_belial(player) then colid = auxi.get_item_from_pool(3,true,player:GetCollectibleRNG(item.entity)) end
			ent:Morph(5,100,colid,true,false,false)
			auxi.initialize_item(ent)
		elseif id > 0 then
			table.insert(tbl,#tbl + 1,ent)
		end
	end
	local adder = false
	if auxi.have_player_has_collectible(CollectibleType.COLLECTIBLE_TMTRAINER) then
	else
		adder = true 
		Imitate_item_holder.assign_fake_item(player,CollectibleType.COLLECTIBLE_TMTRAINER,true)
	end
	for u,ent in pairs(tbl) do
		ent:Morph(5,100,0,true,false,false)
		auxi.initialize_item(ent)
	end
	if adder then Imitate_item_holder.re_assign_fake_item() end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		delay_buffer.addeffe(function(params)
			item.reroll_items(player)
		end,{},2)
	else
		item.reroll_items(player)
	end
	return ret
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.WISP,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.WISP and ent.SubType == item.entity then
		local d = ent:GetData()
		local s = ent:GetSprite()
		s.Color = auxi.table2color(auxi.check_lerp(ent.FrameCount % item.Colorinfo.total,item.Colorinfo))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_INIT, params = nil,
Function = function(_,ent)
	if ent.SpawnerEntity and ent.SpawnerEntity.Type == 3 and ent.SpawnerEntity.Variant == FamiliarVariant.WISP and ent.SpawnerEntity.SubType == item.entity then
		local color = auxi.table2color(auxi.check_lerp(ent.SpawnerEntity.FrameCount % item.Colorinfo.total,item.Colorinfo))
		delay_buffer.addeffe(function(params) 
			if auxi.check_all_exists(ent) then 
				ent:GetSprite().Color = color 
				ent.TearFlags = ent.TearFlags | auxi.MakeBitSet(math.random(84) - 1)
			end 
		end,{},1)
	end
end,
})

return item
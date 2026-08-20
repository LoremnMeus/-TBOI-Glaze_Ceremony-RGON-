local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local costume_holder = require("Qing_Remaster_scripts.others.Costume_holder")

local item = {
	ToCall = {},
	post_ToCall = {},
	entity = enums.Items.D773,
	zh = {Description = "#重置你的皮肤 #重置房间内所有主动道具",},
	en = {Description = "#Reroll your costume #Reroll all active items.",},
	evils = {
		34,51,79,80,82,83,118,122,159,216,462,
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	if coltyp == item.entity then
		if save.elses.D773 == nil then save.elses.D773 = 0 end
		save.elses.D773 = save.elses.D773 + 1
		if(MaxEID) or Options.Language == "zh" or EID.Config["Language"] == "zh_cn" then
			EID:addCollectible(item.entity, item.zh.Description,"D"..tostring(773 + save.elses.D773))
		else
			EID:addCollectible(item.entity, item.en.Description,"D"..tostring(773 + save.elses.D773))
		end
		local itemConfig = Isaac.GetItemConfig()
		local sz = itemConfig:GetCollectibles().Size
		local cnt = 0
		local tab = {}
		for u,v in pairs(costume_holder.CanAdd) do
			local collectible = itemConfig:GetCollectible(v)
			if (collectible and player:HasCollectible(v)) then
				cnt = cnt + 1
			end
			player:RemoveCostume(collectible)
			table.insert(tab,#tab + 1,v)
		end
		for i = 1,cnt do
			if #tab > 0 then
				rng = auxi.rng_for_sake(rng)
				local rnd = rng:RandomInt(#tab) + 1
				player:AddCostume(itemConfig:GetCollectible(tab[rnd]),false)
				table.remove(tab,rnd)
			else
				break
			end
		end
		local n_entity = Isaac.GetRoomEntities()
		local n_item = auxi.getothers(n_entity,5,100)
		for u,v in pairs(n_item) do
			local id = v.SubType
			if id ~= 0 then
				v:ToPickup():Morph(5,100,id,true,false,false)
				auxi.initialize_item(v)
			end
		end
		if auxi.should_do_belial(player) then 
			for i = 1,3 do player:AddCostume(itemConfig:GetCollectible(auxi.choose2(item.evils)),false) end
		end
		return true
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_,str,params)
	if string.lower(str) == "meus" and params ~= nil then
		local args={}
		for str in string.gmatch(params, "([^ ]+)") do
			table.insert(args, str)
		end
		if args[1] then
			if string.lower(args[1]) == "please" then
				if args[2] and args[3] then
					if args[2] == "clear" and args[3] == "773" then
						print("Ok.")
						save.elses.D773 = 0
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = nil,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.WISP and ent.SubType == item.entity then
		local rng = ent:GetDropRNG()
		local n_pickups = auxi.getpickups(Isaac.GetRoomEntities(),false)
		if #n_pickups > 0 then
			local rnd = rng:RandomInt(#n_pickups) + 1
			local v = n_pickups[rnd]:ToPickup()
			v:Morph(5,v.Variant,v.SubType,true,false,true)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if save.elses.D773 == nil then save.elses.D773 = 0 end
	if EID then
		if(MaxEID) or Options.Language == "zh" or EID.Config["Language"] == "zh_cn" then
			EID:addCollectible(item.entity, item.zh.Description,"D"..tostring(773 + save.elses.D773))
		else
			EID:addCollectible(item.entity, item.en.Description,"D"..tostring(773 + save.elses.D773))
		end
	end
end,
})

return item
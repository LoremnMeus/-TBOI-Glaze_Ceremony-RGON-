local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Empress_r,
	own_key = "Thoth_cd3r_Emp_",
	own_key2 = "Thoth_cd3r_Emp2_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = nil
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = nil
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = 100,
Function = function(_,ent,val)
	local d = ent:GetData()
	if save.elses[item.own_key.."effect"] and d[item.own_key.."effect"] then
		local config = Isaac:GetItemConfig()
		local collectibleinfo = config:GetCollectible(ent.SubType)
		if collectibleinfo then
			if val == -1000 then val = 0 end
			if val >= 0 then
				local ret = math.ceil(collectibleinfo.Quality * (save.elses[item.own_key.."effect"] or 7) * val / 15)
				if ret == 0 then ret = -1000 end
				return ret
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 100,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local succ2 = consistance_holder.try_check_entity(ent,item.own_key2)
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ2 then
			if succ ~= true then
				consistance_holder.try_remove_entity(ent,item.own_key,{record_subtype = d._Data[item.own_key2][item.own_key.."record"],})
				consistance_holder.try_remove_entity(ent,item.own_key2)
			end
		else
			if ent.SubType == 0 then
				s:ReplaceSpritesheet(1,"gfx/effects/nill.png")
				s:LoadGraphics()
			end
			d[item.own_key.."effect"] = nil	
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 100,
Function = function(_,ent)
	if save.elses[item.own_key.."effect"] then
		local config = Isaac:GetItemConfig()
		local collectibleinfo = config:GetCollectible(ent.SubType)
		if collectibleinfo and collectibleinfo.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST then
			local succ = consistance_holder.try_check_entity(ent,item.own_key)
			local succ2 = consistance_holder.try_check_entity(ent,item.own_key2)
			local d = ent:GetData()
			local s = ent:GetSprite()
			if d.first_appear2 and not succ2 then
				unique_holder.try_spawn_shop_item()
				delay_buffer.addeffe(function(params)
					if auxi.check_all_exists(ent) then
						if not price_holder.have_catched_price(ent) then
							if ent.Price == 0 then ent.Price = 15 end
							price_holder.catch_price_over(ent)
						end
					end
				end,{},1)
				consistance_holder.try_hold_entity(ent,item.own_key)
				consistance_holder.try_hold_over_entity(ent,item.own_key2)
				d._Data[item.own_key2][item.own_key.."record"] = ent.SubType
				consistance_holder.try_hold_entity(ent,item.own_key2,{ignore_subtype = true})
			end
			if succ or d.first_appear2 then
				s:ReplaceSpritesheet(1,"gfx/items/collectibles/to_be_question_mark.png")
				s:LoadGraphics()
				d[item.own_key.."effect"] = true
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		Game():RerollLevelCollectibles()
		player:UseActiveItem(105,false,true,true,false)
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			save.elses[item.own_key.."effect"] = 1
		else
			save.elses[item.own_key.."effect"] = 5
		end
		local n_entity = Isaac.GetRoomEntities()
		local config = Isaac:GetItemConfig()
		for u,v in pairs(n_entity) do
			if v.Type == 5 and v.Variant == 100 and config:GetCollectible(v.SubType) and config:GetCollectible(v.SubType).Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST then
				v = v:ToPickup()
				if v.Price == 0 then v.Price = 15 end
				local d2 = v:GetData()
				price_holder.catch_price_over(v)
				consistance_holder.try_hold_entity(v,item.own_key)
				consistance_holder.try_hold_over_entity(v,item.own_key2)
				d2._Data[item.own_key2][item.own_key.."record"] = v.SubType
				consistance_holder.try_hold_entity(v,item.own_key2,{ignore_subtype = true})
				local s = v:GetSprite()
				s:ReplaceSpritesheet(1,"gfx/items/collectibles/to_be_question_mark.png")
				s:LoadGraphics()
				v:GetData()[item.own_key.."effect"] = true
			end
		end
		unique_holder.try_spawn_shop_item()
		unique_holder.clear_Appear2()
	end
end,
})

if EID then
	EID:addDescriptionModifier("qing_item_sync_cd"..tostring(item.entity), function(desc) return save.elses[item.own_key.."effect"] end, function(desc)
		if (desc.ObjType == 5 and desc.ObjVariant == 100 and desc.Entity) then
			if desc.Entity:GetData()[item.own_key.."effect"] then
				return {Description = "QuestionMark",}
			end
		end
		return desc
	end)
end

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Assemble_holder = require("Qing_Remaster_scripts.others.Assemble_holder")

local item = {
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	post_myToCall = {},
	check_for_fortune_teller = 0,
	own_key = "Callback_Item_Display_holder_",
	minibossname = {
		[46] = function(entinfo) 
			if entinfo.Variant == 0 then return "SLOTH" end 
			if entinfo.Variant == 1 then return "SUPER_SLOTH" end 
			if entinfo.Variant == 2 then return "ULTRA_PRIDE" end 
		end,
		[47] = function(entinfo) 
			if entinfo.Variant == 0 then return "LUST" end 
			if entinfo.Variant == 1 then return "SUPER_LUST" end 
		end,
		[48] = function(entinfo) 
			if entinfo.Variant == 0 then return "WRATH" end 
			if entinfo.Variant == 1 then return "SUPER_WRATH" end 
		end,
		[49] = function(entinfo) 
			if entinfo.Variant == 0 then return "GLUTTONY" end 
			if entinfo.Variant == 1 then return "SUPER_GLUTTONY" end 
		end,
		[50] = function(entinfo) 
			if entinfo.Variant == 0 then return "GREED" end 
			if entinfo.Variant == 1 then return "SUPER_GREED" end 
		end,
		[51] = function(entinfo) 
			if entinfo.Variant == 0 then return "ENVY" end 
			if entinfo.Variant == 1 then return "SUPER_ENVY" end 
		end,
		[52] = function(entinfo) 
			if entinfo.Variant == 0 then return "PRIDE" end 
			if entinfo.Variant == 1 then return "SUPER_PRIDE" end 
		end,
		[81] = function(entinfo) 
			if entinfo.Variant == 1 then return "KRAMPUS" end 
		end,
		[303] = function(entinfo)
			if entinfo.Variant == enums.Enemies.ShadowToken then return "MULTIPLE SINS" end 
		end
	},
	room_check = {
		[2] = function() return Game():GetLevel():GetCurrentRoomDesc().SurpriseMiniboss end,
		[6] = true,
		[7] = function() return Game():GetLevel():GetCurrentRoomDesc().SurpriseMiniboss end,
		[14] = function() return Game():GetLevel():GetCurrentRoomDesc().SurpriseMiniboss end,
	},
}
Assemble_holder.register_on(item.own_key,item,{force = true,})

function item.display_item(player,id)
	player = player or Game():GetPlayer(0)
	local configitem = Isaac:GetItemConfig():GetCollectible(id)
	if configitem then
		local typ = "Item"
		local ret = callback_manager.work_with_result("PRE_DESCRIPT_ITEM",function(funct,params,value) if params == nil or params == typ then return funct(nil,player,typ,id,value) end end,{Name = auxi.check_name_data(configitem.Name),Description = auxi.check_name_data(configitem.Description),})
		if ret then
			callback_manager.work("POST_DESCRIPT_ITEM",function(funct,params) if params == nil or params == typ then funct(nil,player,typ,ret) end end)
			Game():GetHUD():ShowItemText(ret.Name or "", ret.Description or "")
		end
	end
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local s = player:GetSprite()
	if player:IsItemQueueEmpty() then
		if player:GetData()[item.own_key.."showing_buff"] == true then
			player:GetData()[item.own_key.."showing_buff"] = nil
		end
	end
	d.for_dead_sea_scrolls_minder = nil
	d.check_for_lemegeton = nil
	if d[item.own_key.."Craft"] then
		local anim = s:GetAnimation()
		if string.match(anim,"Walk") and ((d[item.own_key.."Craft"] <= 3 and not string.match(anim,"Pickup")) or (d[item.own_key.."Craft"] >= 3 and string.match(anim,"Pickup"))) then
			if Input.IsActionPressed(ButtonAction.ACTION_PILLCARD, player.ControllerIndex) and not d[item.own_key.."Craft_Counter"] then d[item.own_key.."Craft"] = (d[item.own_key.."Craft"] or 0) + 1
			else 
				d[item.own_key.."Craft_Counter"] = (d[item.own_key.."Craft_Counter"] or 0) + 1
			end
		else
			d[item.own_key.."Craft_Counter"] = (d[item.own_key.."Craft_Counter"] or 0) + 1
		end
		if (d[item.own_key.."Craft_Counter"] or 0) >= 2 then
			d[item.own_key.."Craft"] = nil
			d[item.own_key.."Craft_Counter"] = nil
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_PICKUP_COLLECTIBLE, params = nil,
Function = function(_,player,id,touched,ent)
	if player:GetData()[item.own_key.."showing_buff"] == nil then
		local config = Isaac:GetItemConfig()
		local configitem = config:GetCollectible(id)
		if configitem then
			local typ = "Item"
			local ret = callback_manager.work_with_result("PRE_DESCRIPT_ITEM",function(funct,params,value) if params == nil or params == typ then return funct(nil,player,typ,id,value) end end,{Name = auxi.check_name_data(configitem.Name),Description = auxi.check_name_data(configitem.Description),})
			if ret then
				callback_manager.work("POST_DESCRIPT_ITEM",function(funct,params) if params == nil or params == typ then funct(nil,player,typ,ret) end end)
				Game():GetHUD():ShowItemText(ret.Name or "", ret.Description or "")
				player:GetData()[item.own_key.."showing_buff"] = true
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_PICKUP_TRINKET, params = nil,
Function = function(_,player,id,golden,touched)
	if player:GetData()[item.own_key.."showing_buff"] == nil then
		local config = Isaac:GetItemConfig()
		local configitem = config:GetTrinket(id)
		if configitem then
			local typ = "Trinket"
			local ret = callback_manager.work_with_result("PRE_DESCRIPT_ITEM",function(funct,params,value) if params == nil or params == typ then return funct(nil,player,typ,id,value) end end,{Name = auxi.check_name_data(configitem.Name),Description = auxi.check_name_data(configitem.Description),})
			if ret then
				callback_manager.work("POST_DESCRIPT_ITEM",function(funct,params) if params == nil or params == typ then funct(nil,player,typ,ret) end end)
				Game():GetHUD():ShowItemText(ret.Name or "", ret.Description or "")
				player:GetData()[item.own_key.."showing_buff"] = true
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_PICKUP_POCKET_ITEM, params = nil,
Function = function(_,player,var,st)
	if var == 300 then
		local card = st
		local configitem = Isaac:GetItemConfig():GetCard(card)
		if configitem then
			local typ = "Card"
			local ret = callback_manager.work_with_result("PRE_DESCRIPT_ITEM",function(funct,params,value) if params == nil or params == typ then return funct(nil,player,typ,card,value) end end,{Name = auxi.check_name_data(configitem.Name),Description = auxi.check_name_data(configitem.Description),})
			if ret then
				callback_manager.work("POST_DESCRIPT_ITEM",function(funct,params) if params == nil or params == typ then funct(nil,player,typ,ret) end end)
				Game():GetHUD():ShowItemText(ret.Name or "", ret.Description or "")
				player:GetData()[item.own_key.."showing_buff"] = true
			end
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 20,
Function = function(_,ent,col,low)
	if ent.Variant == 20 and ent.SubType == 5 then
		if col.Type == 1 then
			local player = col:ToPlayer()
			if player then
				local typ = "Coin"
				local ret = callback_manager.work_with_result("PRE_DESCRIPT_ITEM",function(funct,params,value) if params == nil or params == typ then return funct(nil,player,typ,5,value) end end,{Name = auxi.check_name_data("#LUCKY_PENNY_NAME"),Description = auxi.check_name_data("#LUCKY_PENNY_DESCRIPTION"),})
				if ret then
					delay_buffer.addeffe(function(params)
						callback_manager.work("POST_DESCRIPT_ITEM",function(funct,params) if params == nil or params == typ then funct(nil,player,typ,ret) end end)
						Game():GetHUD():ShowItemText(ret.Name or "", ret.Description or "")
						player:GetData()[item.own_key.."showing_buff"] = true
					end,{},1)
				end
			end
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_USE_PILL, params = nil,
Function = function(_,pill,player,flag)	
	if flag & UseFlag.USE_NOHUD ~= UseFlag.USE_NOHUD then
		local config = Isaac:GetItemConfig()
		local configitem = config:GetPillEffect(pill)
		if configitem then
			local typ = "Pill"
			local ret = callback_manager.work_with_result("PRE_DESCRIPT_ITEM",function(funct,params,value) if params == nil or params == typ then return funct(nil,player,typ,pill,value) end end,{Name = auxi.check_name_data(configitem.Name),Description = "",})
			if ret then
				callback_manager.work("POST_DESCRIPT_ITEM",function(funct,params) if params == nil or params == typ then funct(nil,player,typ,ret) end end)
				Game():GetHUD():ShowItemText(ret.Name or "", ret.Description or "")
				player:GetData()[item.own_key.."showing_buff"] = true
			end
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = nil,
Function = function(_,card,player,flag)
	if card == Card.CARD_RULES then
		local typ = "Tips"
		local ret = callback_manager.work_with_result("PRE_TELL_FORTUNE",function(funct,params,value) return funct(nil,typ,value) end,{Description = nil,})		--也许以后可以把player也传进来？
		if ret and ret.Description ~= nil then
			callback_manager.work("POST_DESCRIPT_ITEM",function(funct,params) if params == nil or params == typ then funct(nil,player,typ,ret) end end)
			if type(ret.Description) == "table" then
				Game():GetHUD():ShowFortuneText(ret.Description[1] or "",ret.Description[2],ret.Description[3],ret.Description[4],ret.Description[5])
			else
				Game():GetHUD():ShowFortuneText(ret.Description or "")
			end
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = nil,			--死海和缺德书
Function = function(_, colid, rng, player, flags, slot, data)
	local d = player:GetData()
	if colid == CollectibleType.COLLECTIBLE_DEAD_SEA_SCROLLS then
		if d.for_dead_sea_scrolls_minder then
			local config = Isaac:GetItemConfig()
			local id = d.for_dead_sea_scrolls_minder
			local configitem = config:GetCollectible(id)
			if configitem then
				local typ = "Item"
				local ret = callback_manager.work_with_result("PRE_DESCRIPT_ITEM",function(funct,params,value) if params == nil or params == typ then return funct(nil,player,typ,id,value) end end,{Name = auxi.check_name_data(configitem.Name),Description = "",})
				if ret then
					callback_manager.work("POST_DESCRIPT_ITEM",function(funct,params) if params == nil or params == typ then funct(nil,player,typ,ret) end end)
					Game():GetHUD():ShowItemText(ret.Name or "", ret.Description or "")
					player:GetData()[item.own_key.."showing_buff"] = true
				end
			end
		end
	elseif colid == CollectibleType.COLLECTIBLE_LEMEGETON then
		if d.check_for_lemegeton then
			local config = Isaac:GetItemConfig()
			local id = d.check_for_lemegeton
			local configitem = config:GetCollectible(id)
			if configitem then
				local typ = "Item"
				local ret = callback_manager.work_with_result("PRE_DESCRIPT_ITEM",function(funct,params,value) if params == nil or params == typ then return funct(nil,player,typ,id,value) end end,{Name = auxi.check_name_data(configitem.Name),Description = auxi.check_name_data(configitem.Description),})
				if ret then
					callback_manager.work("POST_DESCRIPT_ITEM",function(funct,params) if params == nil or params == typ then funct(nil,player,typ,ret) end end)
					Game():GetHUD():ShowItemText(ret.Name or "", ret.Description or "")
					player:GetData()[item.own_key.."showing_buff"] = true
				end
			end
			d.check_for_lemegeton = nil
		end
	elseif colid == CollectibleType.COLLECTIBLE_FORTUNE_COOKIE then
		item.check_for_fortune_teller = 3
	end
	if colid == CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING and Input.IsActionPressed(ButtonAction.ACTION_PILLCARD, player.ControllerIndex) then d[item.own_key.."Craft"] = 0 d[item.own_key.."Craft_Counter"] = nil
	else d[item.own_key.."Craft"] = nil end
	d.for_dead_sea_scrolls_minder = colid
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = nil,
Function = function(_,player,collid,cnt,touched)
	local d = player:GetData()
	local anim = player:GetSprite():GetAnimation()
	if (d[item.own_key.."Craft"] or 0) == 59 or (d[item.own_key.."Craft"] or 0) == 60 then 
		local info = Isaac:GetItemConfig():GetCollectible(collid)
		delay_buffer.addeffe(function(params) item.check_and_description("Item",collid,auxi.check_name_data(info.Name),auxi.check_name_data(info.Description),player,nil) end,{},1)
		d[item.own_key.."Craft"] = nil
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = FamiliarVariant.ITEM_WISP,
Function = function(_,ent)
	local player = ent.Player
	if player == nil then player = Game():GetPlayer(0) end
	local d = player:GetData()
	d.check_for_lemegeton = ent.SubType
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local n_entity = Isaac.GetRoomEntities()
	local n_fortune_teller = auxi.getothers(n_entity,6,3)
	for u,v in pairs(n_fortune_teller) do
		local s = v:GetSprite()
		if s:IsEventTriggered("Prize") then
			item.check_for_fortune_teller = 4
			break
		end
	end
	if item.check_for_fortune_teller and item.check_for_fortune_teller > 0 then
		if SFXManager():IsPlaying(SoundEffect.SOUND_SHELLGAME) then
			if SFXManager():GetAmbientSoundVolume(SoundEffect.SOUND_SHELLGAME) == 0.5 then
				local typ = "Fortune"
				local ret = callback_manager.work_with_result("PRE_TELL_FORTUNE",function(funct,params,value) return funct(nil,typ,value) end,{Description = nil,})		--也许以后可以把player也传进来？
				if ret and ret.Description ~= nil then
					callback_manager.work("POST_DESCRIPT_ITEM",function(funct,params) if params == nil or params == typ then funct(nil,nil,typ,ret) end end)
					if type(ret.Description) == "table" then
						Game():GetHUD():ShowFortuneText(ret.Description[1] or "",ret.Description[2],ret.Description[3],ret.Description[4],ret.Description[5])
					else
						Game():GetHUD():ShowFortuneText(ret.Description or "")
					end
				end
				SFXManager():Stop(SoundEffect.SOUND_SHELLGAME)
				item.check_for_fortune_teller = 0
			end
		end
		item.check_for_fortune_teller = item.check_for_fortune_teller - 1
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	if auxi.check_if_any(item.room_check[room:GetType()]) and room:IsClear() == false then
		local typ = "Room"
		local name = auxi.get_players_display_name()
		name = name .." VS "
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		if desc.SurpriseMiniboss then
			local n_entity = Isaac.GetRoomEntities()
			for u,v in pairs(n_entity) do
				local succ = auxi.check_if_any(item.minibossname[v.Type],v)
				if succ then
					name = name .. auxi.check_name_data("#"..succ.."_NAME",succ)
					item.check_and_description(typ,nil,name,"",nil)
					break
				end
			end
		else
			local spawns = desc.Data.Spawns
			local sz = spawns.Size
			for i = 1,sz do
				local entinfo = spawns:Get(i - 1):PickEntry(math.random(1000)/1000)
				local succ = auxi.check_if_any(item.minibossname[entinfo.Type],entinfo)
				if succ then
					name = name .. auxi.check_name_data("#"..succ.."_NAME",succ)
					item.check_and_description(typ,nil,name,"",nil)
					break
				end
			end
		end
	end
end,
})

--l local desc = Game():GetLevel():GetCurrentRoomDesc() local spawns = desc.Data.Spawns local sz = spawns.Size for i = 1,sz do local entinfo = spawns:Get(i - 1):PickEntry(math.random(1000)/1000) print(entinfo.Type.." "..entinfo.Variant) end
function item.check_and_description(tp,id,Name,Description,player,ispaper)			--必须要传入的参数
	if ispaper == nil then ispaper = false end
	local typ = tp
	if player == nil then player = Game():GetPlayer(0) end
	local ret = callback_manager.work_with_result("PRE_DESCRIPT_ITEM",function(funct,params,value) if params == nil or params == typ then return funct(nil,player,typ,id,value) end end,{Name = Name,Description = Description,})
	if ret then
		callback_manager.work("POST_DESCRIPT_ITEM",function(funct,params) if params == nil or params == typ then funct(nil,player,typ,ret) end end)
		Game():GetHUD():ShowItemText(ret.Name or "", ret.Description or "",ispaper)
	end
	return ret
end
--l Game():GetHUD():ShowItemText("?","",false)

--l local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder") item_displaying_holder.check_and_description("Room",0,"11","",nil,false)

function item.check_description(tp,id,Name,Description,player)			--必须要传入的参数
	local typ = tp
	if player == nil then player = Game():GetPlayer(0) end
	local ret = callback_manager.work_with_result("PRE_DESCRIPT_ITEM",function(funct,params,value) if params == nil or params == typ then return funct(nil,player,typ,id,value) end end,{Name = Name,Description = Description,})
	return ret
end

table.insert(item.post_myToCall,#item.post_myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	value.Name = auxi.protect_text(value.Name or "")
	return value
end,
})

return item
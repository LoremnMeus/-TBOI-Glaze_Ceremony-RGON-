local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")

local item = {
	ToCall = {},
	pre_myToCall = {},
	myToCall = {},
	entity = enums.Items.It_s_a_trick,
	delay_time = nil,
	own_key = "Item_glaze_item_",
	room_temp_key = "Item_glaze_item_room_temp",
}

local function get_mimicked_collectible()
	local collectible = tonumber(save.elses.glazed_trick) or 32
	if collectible == item.entity or Isaac.GetItemConfig():GetCollectible(collectible) == nil then
		collectible = 32
	end
	return collectible
end

local function any_player_has_trick()
	for i = 0, Game():GetNumPlayers() - 1 do
		if Game():GetPlayer(i):HasCollectible(item.entity) then
			return true
		end
	end
	return false
end

local gl_s = Sprite()
local frame = 0
gl_s:Load("gfx/mimics/Glaze_Item/glazed_item.anm2", true)
gl_s:Play("Idle",true)
local gl_s_2 = Sprite()
local frame = 0
gl_s_2:Load("gfx/mimics/Glaze_Item/glazed_item.anm2", true)
gl_s_2:Play("Idle",true)
gl_s_2.Scale = Vector(0.5,0.5)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GET_COLLECTIBLE, params = nil,
Function = function(_,coltyp,pooltyp,decrease,seed)
	if coltyp == item.entity then
		if Game():GetFrameCount() > 3 and (item.delay_time ~= nil and Game():GetFrameCount() > item.delay_time + 3) then
			--print(item.delay_time)
			local rng = RNG()
			rng:SetSeed(seed,0)
			rng = auxi.rng_for_sake(rng)
			local trk = Game():GetItemPool():GetCollectible(pooltyp, true, seed)
			local player = Game():GetPlayer(0)
			if pooltyp ~= 6 then
				for i = 1,10 do
					if Isaac.GetItemConfig():GetCollectible(trk).Type == ItemType.ITEM_ACTIVE then
						trk = Game():GetItemPool():GetCollectible(pooltyp, true,rng:Next())
					else
						break
					end
				end
			else
				trk = 584
			end
			if Isaac.GetItemConfig():GetCollectible(trk).Type == ItemType.ITEM_ACTIVE then
				save.elses.glazed_trick = 32
			else
				save.elses.glazed_trick = trk
			end
			--print(save.elses.glazed_trick)
		else
			
		end
	end
end,
})

table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = 100,
Function = function(_,ent,val)
	if ent.Variant == 100 and ent.SubType == item.entity then
		local rng = RNG()
		rng:SetSeed(ent:GetDropRNG():GetSeed(),0)
		rng = auxi.rng_for_sake(rng)
		if val < 0 then
			local price = val
			local price2 = - Isaac.GetItemConfig():GetCollectible(save.elses.glazed_trick).DevilPrice
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				if player:HasTrinket(TrinketType.TRINKET_YOUR_SOUL) then
					price = -6
				end
			end
			if price ~= -6 then
				if price2 < -1 then
					for playerNum = 1, Game():GetNumPlayers() do
						local player = Game():GetPlayer(playerNum - 1)
						if player:HasTrinket(TrinketType.TRINKET_JUDAS_TONGUE) then
							price = -1
						end
					end
					local player = Game():GetPlayer(0)
					if(price == -1 or price == -2) and (player:GetMaxHearts() + player:GetBoneHearts() == 0 or auxi.is_soul_player(player) == true) then
						price = -3
					end
					if price == -2 and player:GetMaxHearts() + player:GetBoneHearts() == 2 then
						price = -4
					end
				end
			end
			return price
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = 100,
Function = function(_,ent)
	if ent.Variant == 100 and ent.SubType == item.entity then
		if auxi.isBlindPickup(ent) == false then
			if ent:GetData()[item.own_key.."sprite"] ~= true then
				local s = ent:GetSprite()
				s:ReplaceSpritesheet(1, Isaac.GetItemConfig():GetCollectible(save.elses.glazed_trick).GfxFileName)
				s:LoadGraphics()
				ent:GetData()[item.own_key.."sprite"] = true
				price_holder.try_catch_price(ent)
			end
		end
	else
		if ent:GetData()[item.own_key.."sprite"] then ent:GetData()[item.own_key.."sprite"] = nil end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	if Game():IsPaused() == false then
		frame = frame + 1
	else
		frame = frame - 1
	end
	if frame > 47 then frame = 0 end
	if frame < 0 then frame = 48 end
	local player = Game():GetPlayer(0)
	local act = player:GetActiveItem(1)
	if act and act == item.entity then
		--print(Isaac.GetItemConfig():GetCollectible(save.elses.glazed_trick).GfxFileName)
		gl_s_2:ReplaceSpritesheet(0, Isaac.GetItemConfig():GetCollectible(save.elses.glazed_trick).GfxFileName)
		gl_s_2:LoadGraphics()
		local pos = ui.PlayerActiveUIPos(player,ActiveSlot.SLOT_SECONDARY,auxi.GetPlayerOrder(player),act)
		gl_s_2:SetFrame(frame)
		gl_s_2:Render(pos,Vector(0,0),Vector(0,0))
	end
	if Game():GetNumPlayers() > 1 then
		local player = Game():GetPlayer(1)
		if player and player.ControllerIndex == 0 then		--拥有主动的非主角色人物
			local act = player:GetActiveItem(1)
			if act and act == item.entity then
				--print(Isaac.GetItemConfig():GetCollectible(save.elses.glazed_trick).GfxFileName)
				gl_s_2:ReplaceSpritesheet(0, Isaac.GetItemConfig():GetCollectible(save.elses.glazed_trick).GfxFileName)
				gl_s_2:LoadGraphics()
				local pos = ui.PlayerActiveUIPos(player,ActiveSlot.SLOT_SECONDARY,auxi.GetPlayerOrder(player),act)
				gl_s_2:SetFrame(frame)
				gl_s_2:Render(pos,Vector(0,0),Vector(0,0))
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
		item.delay_time = Game():GetFrameCount()
	else
		item.delay_time = 0
		save.elses.glazed_trick = 32
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.delay_time = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_,name)
	if name == "Qing_HelpfulShader" and Game():GetHUD():IsVisible() then
		local player = Game():GetPlayer(0)
		local act = player:GetActiveItem(0)
		if act and act == item.entity then
			gl_s:ReplaceSpritesheet(0, Isaac.GetItemConfig():GetCollectible(save.elses.glazed_trick).GfxFileName)
			gl_s:LoadGraphics()
			local pos = ui.PlayerActiveUIPos(player,ActiveSlot.SLOT_PRIMARY,auxi.GetPlayerOrder(player),act)
			gl_s:SetFrame(frame)
			gl_s:Render(pos,Vector(0,0),Vector(0,0))
		end
		if Game():GetNumPlayers() > 1 then
			local player = Game():GetPlayer(1)
			if player and player.ControllerIndex == 0 then		--拥有主动的非主角色人物
				local act = player:GetActiveItem(0)
				if act and act == item.entity then
					gl_s:ReplaceSpritesheet(0, Isaac.GetItemConfig():GetCollectible(save.elses.glazed_trick).GfxFileName)
					gl_s:LoadGraphics()
					local pos = ui.PlayerActiveUIPos(player,ActiveSlot.SLOT_PRIMARY,auxi.GetPlayerOrder(player),act)
					gl_s:SetFrame(frame)
					gl_s:Render(pos,Vector(0,0),Vector(0,0))
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	if coltyp == item.entity then
		rng = auxi.rng_for_sake(rng)
		local mimicked = get_mimicked_collectible()
		if rng:RandomFloat() < 0.05 then
			player:AddCollectible(mimicked)
			player:RemoveCollectible(item.entity)
			player:GetData()[item.room_temp_key] = nil
		else
			player:GetEffects():AddCollectibleEffect(mimicked, false, 1)
			-- 房间临时效果：纳入通用琉璃化临时道具显示
			player:GetData()[item.room_temp_key] = mimicked
		end
		if auxi.should_spawn_wisp(player,useFlags) then
			local rnd = rng:RandomInt(10)
			if rnd == 1 then
				player:AddItemWisp(mimicked,player.Position,true)
			end
		end
		player:AnimateCollectible(mimicked,"UseItem", "PlayerPickupSparkle")
		return false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for i = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player then player:GetData()[item.room_temp_key] = nil end
	end
end,
})

do
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	temp_hud.register_provider(function(player)
		local id = player:GetData()[item.room_temp_key]
		id = tonumber(id)
		if not id or id <= 0 then return end
		local effects = player:GetEffects()
		if not effects or not effects:HasCollectibleEffect(id) then
			player:GetData()[item.room_temp_key] = nil
			return
		end
		return {[id] = 1}
	end,{
		-- 本模组通用琉璃化：闪烁 Tint + 跳动 Scale（同 glaze_enemy）
		glaze = true,
		exclusive = true,
		source_item = item.entity,
	})
end

if EID then
	EID:addDescriptionModifier(item.own_key .. "mimicked_eid", function(desc)
		return desc.ObjType == 5 and desc.ObjVariant == 100 and desc.ObjSubType == item.entity
	end, function(desc)
		local mimicked = get_mimicked_collectible()
		local mimicked_desc = EID:getDescriptionObj(5, 100, mimicked, nil, true)
		if mimicked_desc == nil then
			return desc
		end

		-- Copy every visible collectible field, while retaining the real subtype so this
		-- modifier remains attached to It's a trick rather than the imitated collectible.
		desc.Icon = mimicked_desc.Icon
		desc.Quality = mimicked_desc.Quality
		desc.Transformation = mimicked_desc.Transformation
		desc.ModName = mimicked_desc.ModName
		desc.ItemPoolType = mimicked_desc.ItemPoolType
		desc.ItemType = mimicked_desc.ItemType
		desc.ChargeType = mimicked_desc.ChargeType
		desc.Charges = mimicked_desc.Charges

		if not any_player_has_trick() then
			desc.Name = mimicked_desc.Name
			desc.Description = mimicked_desc.Description
			return desc
		end

		local language = EID:getLanguage()
		if language == "zh_cn" then
			desc.Name = "伪饰的" .. mimicked_desc.Name
			desc.Description = "{{Room}} 本房间获得{{Collectible" .. mimicked .. "}} " .. mimicked_desc.Name .. "的效果"
				.. "#" .. mimicked_desc.Description
				.. "#每次使用有5%概率变回真实的对应道具"
		else
			desc.Name = "Disguised " .. mimicked_desc.Name
			desc.Description = "{{Room}} Gain the effect of {{Collectible" .. mimicked .. "}} " .. mimicked_desc.Name .. " for the room"
				.. "#" .. mimicked_desc.Description
				.. "#Each use has a 5% chance to become the real corresponding collectible"
		end
		return desc
	end)
end

return item

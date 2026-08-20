local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.The_True_Name,
	own_key = "Item_TT_Name_",
	start_pos = Vector(0,-50),
	mov_pos = Vector(15,0),
	mov_pos2 = Vector(0,15),
	limit = 100,
	dir_time_limit = 20,
	dirinfo = {
		[1] = {x = -1,spritename = "gfx/ui/math/pre_mark.png",},
		[2] = {x = 10,spritename = "gfx/ui/math/next_mark.png",},
	},
}

if true then
	item.Item_list = {}
	local config = Isaac:GetItemConfig()
	local sz = config:GetCollectibles().Size
	for i = 1,sz do
		local col = config:GetCollectible(i)
		if col and (col.Hidden ~= true) and (col.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST) then
			table.insert(item.Item_list,#item.Item_list + 1,i)
		end
	end
end

local function get_column(player,number) return 10 end

local function get_render_sprite(player,id)
	id = id + 1
	local d = player:GetData()
	local ret = Sprite()
	ret:Load("gfx/mimics/The_True_Name/the_true_name_item.anm2",true)
	ret:Play("Idle",true)
	ret.Scale = Vector(0.5,0.5)
	local config = Isaac:GetItemConfig()
	if item.Item_list[id] and config:GetCollectible(item.Item_list[id]) then 
		local col = config:GetCollectible(item.Item_list[id])
		if item.Item_list[id] == enums.Items.It_s_a_trick then col = config:GetCollectible(save.elses.glazed_trick or 32) or config:GetCollectible(32) end
		ret:ReplaceSpritesheet(0,col.GfxFileName)
		ret:LoadGraphics()
	end
	return {sprite = ret,}
end

local function render_selector(player)
	local d = player:GetData()
	local column = get_column(player)
	local row = 10
	local cnt = row * column
	local startid = (d[item.own_key.."counter"] or 0) - (d[item.own_key.."counter"] or 0) % cnt
	local stpos = Isaac.WorldToScreen(player.Position) + item.start_pos - item.mov_pos * ((column - 1)/2) - item.mov_pos2 * row
	for i = 0,cnt - 1 do
		local x = i % row
		local y = (i - x)/row
		local info = get_render_sprite(player,startid + i)
		local s = info.sprite
		local tpos = stpos + x * item.mov_pos + y * item.mov_pos2
		s:Render(tpos,Vector(0,0),Vector(0,0))
		if (d[item.own_key.."counter"] or 0) == startid + i and (d[item.own_key.."tp"] or 0) == 0 then
			local s2 = Sprite()
			s2:Load("gfx/mimics/The_True_Name/the_true_name_item.anm2",true)
			s2:Play("Idle",true)
			s2:ReplaceSpritesheet(0,"gfx/ui/math/catch_mark.png")
			s2:LoadGraphics()
			s2.Scale = Vector(0.5,0.5)
			s2:Render(tpos,Vector(0,0),Vector(0,0))
		end
	end
	for i = 1,2 do
		local info = item.dirinfo[i]
		local tpos = stpos + item.mov_pos * info.x + row * 0.45 * item.mov_pos2
		local s = Sprite()
		s:Load("gfx/mimics/The_True_Name/the_true_name_item.anm2",true)
		s:Play("Idle",true)
		s:ReplaceSpritesheet(0,info.spritename)
		s:LoadGraphics()
		s.Scale = Vector(0.5,0.5)
		s:Render(tpos,Vector(0,0),Vector(0,0))
		if (d[item.own_key.."tp"] or 0) == i then
			local s2 = Sprite()
			s2:Load("gfx/mimics/The_True_Name/the_true_name_item.anm2",true)
			s2:Play("Idle",true)
			s2:ReplaceSpritesheet(0,"gfx/ui/math/catch_mark.png")
			s2:LoadGraphics()
			s2.Scale = Vector(0.5,0.5)
			s2:Render(tpos,Vector(0,0),Vector(0,0))
		end
	end
end

local function move(player,dir)
	local column = get_column(player)
	local row = 10
	local cnt = row * column
	local tot = math.ceil(#item.Item_list/100) * 100
	local d = player:GetData()
	local start = (d[item.own_key.."counter"] or 0) % cnt
	local startid = (d[item.own_key.."counter"] or 0) - start
	local x = start % row
	local y = (start - x)/row
	if (d[item.own_key.."tp"] or 0) == 0 then
		if dir == 4 then if x == 0 then d[item.own_key.."tp"] = 1 else x = x - 1 end
		elseif dir == 5 then if x == row - 1 then d[item.own_key.."tp"] = 2 else x = x + 1 end
		elseif dir == 6 then y = (y - 1 + column) % column
		elseif dir == 7 then y = (y + 1) % column
		elseif dir == 9 then 
			local slot = auxi.check_slot_with_item(player,item.entity)
			local adder = false
			if auxi.have_player_has_collectible(CollectibleType.COLLECTIBLE_CHAOS) then
			elseif not auxi.should_do_belial(player) then
				adder = true 
				Imitate_item_holder.assign_fake_item(player,CollectibleType.COLLECTIBLE_CHAOS,true)
			end
			local rng = player:GetCollectibleRNG(item.entity)
			local pid = 0
			if auxi.should_do_belial(player) then pid = 3 end
			local colid = auxi.get_item_from_pool(pid,true,rng)
			rng:Next()
			local room = Game():GetRoom()
			if colid == item.Item_list[(d[item.own_key.."counter"] or 0) + 1] then
				player:AnimateHappy()
				unique_holder.Hold_for_missing(true) 
				local q = Isaac.Spawn(5,100,colid,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				auxi.self_morph(q,{5,100,colid,})
				local q2 = Isaac.Spawn(5,100,CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				auxi.self_morph(q2,{5,100,CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE,})
				unique_holder.Hold_for_missing() 
				if d[item.own_key.."wisp"] then
					d[item.own_key.."wisp"] = nil
					player:AddItemWisp(colid,player.Position,true)
				end
			else
				player:AnimateSad()
				local q = auxi.spawn_item_dust(player,player.Position,colid,nil,Color(0.5,0.5,0.5,1,0.1,0.1,0.1))
				if auxi.should_do_belial(player) then q:GetSprite().Color = Color(0,0,0,1) end
			end
			if adder then Imitate_item_holder.re_assign_fake_item() end
			player:UseActiveItem(item.entity,UseFlag.USE_OWNED,slot)
			player:SetActiveCharge(player:GetBatteryCharge(slot), slot)
		end
	elseif (d[item.own_key.."tp"] or 0) == 1 then
		if dir == 9 then startid = (startid + tot - 100) % tot
		elseif dir == 4 then d[item.own_key.."tp"] = 2 x = row - 1
		elseif dir == 6 then d[item.own_key.."tp"] = 0 y = 0
		elseif dir == 7 then d[item.own_key.."tp"] = 0 y = column - 1
		elseif dir == 5 then d[item.own_key.."tp"] = 0 end
	elseif (d[item.own_key.."tp"] or 0) == 2 then
		if dir == 9 then startid = (startid + 100) % tot
		elseif dir == 5 then d[item.own_key.."tp"] = 1 x = 0
		elseif dir == 6 then d[item.own_key.."tp"] = 0 y = 0
		elseif dir == 7 then d[item.own_key.."tp"] = 0 y = column - 1
		elseif dir == 4 then d[item.own_key.."tp"] = 0 end
	end
	d[item.own_key.."counter"] = startid + x + y * row
	return 0
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local d = player:GetData()
		if d[item.own_key.."effect"] ~= true then
			d[item.own_key.."effect"] = true
			d[item.own_key.."lift"] = true
			item.last_open_dir = 9
			d[item.own_key.."wisp"] = auxi.should_spawn_wisp(player,useFlags)
			return {Discharge = false}
		else
			player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
			selection_holder.remove_select(player,item.own_key)
			d[item.own_key.."effect"] = false
			d[item.own_key.."wisp"] = nil
			return {Discharge = false}
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if ent ~= nil then
		local player = ent:ToPlayer()
		if player then
			if player:GetData()[item.own_key.."effect"] and selection_holder.check_select(player,item.own_key) then
				for u,i in pairs({4,5,6,7,9,11}) do
					if button == i and (hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED) then
						return false
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local ctrlid = player.ControllerIndex
	local d = player:GetData()
	local room = Game():GetRoom()
	if d[item.own_key.."lift"] and player:IsExtraAnimationFinished() then
		player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
		selection_holder.check_and_try_select(player,item.own_key)
		d[item.own_key.."lift"] = nil
	end
	if d[item.own_key.."effect"] and not d[item.own_key.."lift"] then
		if player:IsHoldingItem() == false then
			d[item.own_key.."effect"] = false
			selection_holder.remove_select(player,item.own_key)
		else
			if selection_holder.check_select(player,item.own_key) and Game():IsPaused() == false then
				local dir = nil
				for u,i in pairs({4,5,6,7,9,11}) do
					if (Input.IsActionTriggered(i,ctrlid) or Input.IsActionPressed(i,ctrlid)) then dir = i end
				end
				local should_count = false
				if dir then
					if dir == 11 then
						local slot = auxi.check_slot_with_item(player,item.entity)
						player:UseActiveItem(item.entity,UseFlag.USE_OWNED,slot)
					end
					if dir == item.last_open_dir then
						item.last_open_dir_counter = (item.last_open_dir_counter or 0) + 1
						if item.last_open_dir_counter > item.dir_time_limit and item.last_open_dir_counter % 8 == 1 then should_count = true end
					else
						item.last_open_dir_counter = 0
						should_count = true
					end
				end
				item.last_open_dir = dir
				if should_count then
					local succ = move(player,dir)
					if succ == -1 then
						sound_tracker.PlayStackedSound(187,1,1,false,0,2)
					else
						if dir == 5 or dir == 6 then
							sound_tracker.PlayStackedSound(195,1,1,false,0,2)
						elseif dir == 4 or dir == 7 then
							sound_tracker.PlayStackedSound(194,1,1,false,0,2)
						elseif dir == 9 then
							sound_tracker.PlayStackedSound(285,1,1,false,0,2)
						end
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local room = Game():GetRoom()
	local s = player:GetSprite()
	local d = player:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		if d[item.own_key.."effect"] == true and player:IsHoldingItem() then
			if selection_holder.check_select(player,item.own_key) then
				render_selector(player)
			end
		end
	end
end,
})

return item
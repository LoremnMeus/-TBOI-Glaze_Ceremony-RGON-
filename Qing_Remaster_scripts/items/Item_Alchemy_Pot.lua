local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local Tainted_Cain_holder = require("Qing_Remaster_scripts.mimics.Tainted_Cain_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Alchemy_Pot,
	own_key = "Item_Alchemy_Pot_",
	start_pos = Vector(-70,-50),
	mov_pos = Vector(30,0),
	mov_pos2 = Vector(0,30),
	limit = 3,
	dir_time_limit = 20,
}
auxi.add_to_seija(item.entity)

local function get_column(player,number)
	local ret = math.max(3,math.ceil(math.sqrt(number)))
	local delpos = Isaac.WorldToScreen(player.Position) + item.start_pos - item.mov_pos2 * 0.5 	--ui.GetScreenSize()
	local mxn = math.max(1,math.ceil(delpos.Y / 32))
	ret = math.max(math.ceil(number / mxn),ret)
	return ret
end

local function get_value_map(num,id,dontmul)
	local ret = math.floor(num /(10^(3 - id)))% 10
	if dontmul == nil then ret = ret * (10^(3 - id)) end
	return ret
end

local function makeitemlist(player,id)
	local d = player:GetData()
	d[item.own_key.."list"] = {}
	local config = Isaac:GetItemConfig()
	local sz = config:GetCollectibles().Size
	if auxi.should_do_belial(player) then
		local num = 1
		for k = 1,item.limit do
			if (d["Alchemy_Pot_select_st"..tostring(k)] or 0) == 666 then 
				if k == id then d["Alchemy_Pot_select_sl"] = #d[item.own_key.."list"] end
				num = num - 1 
			end
		end
		if num > 0 then table.insert(d[item.own_key.."list"],#d[item.own_key.."list"] + 1,{id = 666,spritename = "gfx/mimics/Alchemy_Pot/666.png",}) end
	end
	for i = 1,sz do
		local col = config:GetCollectible(i)
		if col and (col.Hidden ~= true) and (col.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST) and (i ~= item.entity) then
			local num = player:GetCollectibleNum(i,true)
			if num > 0 then
				for k = 1,item.limit do
					if (d["Alchemy_Pot_select_st"..tostring(k)] or 0) == i then 
						if k == id then d["Alchemy_Pot_select_sl"] = #d[item.own_key.."list"] end
						num = num - 1 
					end
				end
				if i == enums.Items.It_s_a_trick then col = config:GetCollectible(save.elses.glazed_trick or 32) or config:GetCollectible(32) end
				if num > 0 then table.insert(d[item.own_key.."list"],#d[item.own_key.."list"] + 1,{id = i,spritename = col.GfxFileName,}) end
			end
		end
	end
	--local column = get_column(player,#d[item.own_key.."list"] + 1)
end

local function reflush_selector(player)
	local d = player:GetData()
	d.Alchemy_Pot_select_tp = 1
	d.Alchemy_Pot_select_vr = 1
	d["Alchemy_Pot_select_sl"] = 1
	for i = 1,item.limit do
		d["Alchemy_Pot_select_st"..tostring(i)] = 0
	end
end

local function get_render_sprite(player,id)
	local d = player:GetData()
	local ret = Sprite()
	ret:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true)
	ret:Play("Idle",true)
	local config = Isaac:GetItemConfig()
	local succ = false
	local succid = -1
	if id > 0 and id <= 3 then
		local colid = d["Alchemy_Pot_select_st"..tostring(id)] or 0
		local col = config:GetCollectible(colid)
		if colid == enums.Items.It_s_a_trick then col = config:GetCollectible(save.elses.glazed_trick or 32) or config:GetCollectible(32) end
		if col then
			ret:ReplaceSpritesheet(0,col.GfxFileName)
			succ = true
			succid = get_value_map(d["Alchemy_Pot_select_st"..tostring(i)] or 0,id)
		else
			if colid == 666 then
				ret:ReplaceSpritesheet(0,"gfx/mimics/Alchemy_Pot/666.png")
				succ = true
				succid = get_value_map(d["Alchemy_Pot_select_st"..tostring(i)] or 0,id)
			end
		end
	elseif id == 4 then
		ret:ReplaceSpritesheet(0,"gfx/ui/math/equal_mark.png")
	elseif id == 5 then
		local colid = 0
		for i = 1,3 do
			if (d["Alchemy_Pot_select_st"..tostring(i)] or 0) ~= 0 then	colid = colid + get_value_map(d["Alchemy_Pot_select_st"..tostring(i)] or 0,i)
			else colid = 0 break end
		end
		local col = config:GetCollectible(colid)
		if colid == enums.Items.It_s_a_trick then col = config:GetCollectible(save.elses.glazed_trick or 32) or config:GetCollectible(32) end
		if col then
			ret:ReplaceSpritesheet(0,col.GfxFileName)
			succ = true
			succid = colid
		else
			succid = 0
		end
	end
	ret:LoadGraphics()
	return {succ = succ,id = succid,sprite = ret}
end

local function render_item_list(player,id,pos)
	local d = player:GetData()
	if d[item.own_key.."list"] == nil then makeitemlist(player,id) end
	local sl = d["Alchemy_Pot_select_sl"] or 0
	local column = get_column(player,#d[item.own_key.."list"] + 1)
	local mxn = math.ceil((#d[item.own_key.."list"] + 1)/column) * column
	local spos = pos - item.mov_pos * ((column - 1)/2) - item.mov_pos2 * (mxn/column)
	for ii = 1,mxn do
		local info = d[item.own_key.."list"][ii] or {id = 0,spritename = "gfx/ui/math/exclude_mark.png",noword = true,}
		if info.spritename then
			local s = Sprite()
			s:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true)
			s:Play("Idle",true)
			s:ReplaceSpritesheet(0,info.spritename)
			s:LoadGraphics()
			local iii = ii - 1
			local i = iii % column
			local j = math.floor(iii/column)
			local tpos = spos + item.mov_pos * i + item.mov_pos2 * j
			s:Render(tpos,Vector(0,0),Vector(0,0))
			if iii == sl then
				local s2 = Sprite()
				s2:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true)
				s2:Play("Idle",true)
				s2:ReplaceSpritesheet(0,"gfx/ui/math/catch_mark.png")
				s2:LoadGraphics()
				s2:Render(tpos,Vector(0,0),Vector(0,0))
			end
			if info.noword ~= true then
				gui.draw_ch(tpos + Vector(-8,-16),tostring(info.id),1,1,auxi.AddColor(Color(1,1,1,1),Color(1,1,1,1),1,0,true),true)
			end
		end
	end
end

local function render_selector(player)
	local d = player:GetData()
	local stpos = Isaac.WorldToScreen(player.Position) + item.start_pos
	for i = 1,item.limit + 2 do
		local info = get_render_sprite(player,i)
		local s = info.sprite
		s:Render(stpos,Vector(0,0),Vector(0,0))
		if i == d.Alchemy_Pot_select_tp then
			local s2 = Sprite()
			s2:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true)
			s2:Play("Idle",true)
			s2:ReplaceSpritesheet(0,"gfx/ui/math/catch_mark.png")
			s2:LoadGraphics()
			s2:Render(stpos,Vector(0,0),Vector(0,0))
			if (d.Alchemy_Pot_select_vr or 1) == 1 then
			else
				render_item_list(player,i,stpos)
			end
		end
		if (d["Alchemy_Pot_select_st"..tostring(i)] or 0) ~= 0 then		--Isaac:GetItemConfig():GetCollectible(d["Alchemy_Pot_select_st"..tostring(i)] or 0) 
			local info = get_value_map(d["Alchemy_Pot_select_st"..tostring(i)],i,true)
			gui.draw_ch(stpos + Vector(-8,-16),tostring(info),1,1,auxi.AddColor(Color(1,1,1,1),Color(1,1,1,1),1,0,true),true)
		end
		stpos = stpos + item.mov_pos
	end
end

local function move(player,dir)
	local d = player:GetData()
	local tp = d.Alchemy_Pot_select_tp or 1
	if d[item.own_key.."list"] == nil then makeitemlist(player,tp) end
	local vr = d.Alchemy_Pot_select_vr or 1
	local sl = d["Alchemy_Pot_select_sl"] or 0
	local column = get_column(player,#d[item.own_key.."list"] + 1)
	local raw = math.ceil((#d[item.own_key.."list"] + 1) / column)
	local i = sl % column
	local j = math.floor(sl/column)
	if tp == 4 then
		if dir == 9 then
			local slot = auxi.check_slot_with_item(player,item.entity)
			local info = get_render_sprite(player,5)
			if info.succ then
				local col = info.id
				local room = Game():GetRoom()
				local succ = true
				for i = 1,item.limit do
					if d["Alchemy_Pot_select_st"..tostring(i)] ~= 666 and player:GetCollectibleNum(d["Alchemy_Pot_select_st"..tostring(i)],true) <= 0 then
						d["Alchemy_Pot_select_st"..tostring(i)] = 0
						succ = false
					end
				end
				if succ == true then
					for i = 1,item.limit do
						if auxi.has_have_coll(player,d["Alchemy_Pot_select_st"..tostring(i)]) then player:RemoveCollectible(d["Alchemy_Pot_select_st"..tostring(i)]) end
					end
					local succ = true
					if auxi.should_do_Seija(player) then local rng = player:GetCollectibleRNG(item.entity) if rng:RandomFloat() > 0.5 then succ = false end end
					if succ then
						unique_holder.Hold_for_missing(true)
						local q = Isaac.Spawn(5,100,col,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						auxi.self_morph(q,{5,100,col,})
						unique_holder.Hold_for_missing() 
						sound_tracker.PlayStackedSound(268,1,1,false,0,2)
					else
						local adder = false
						if auxi.have_player_has_collectible(CollectibleType.COLLECTIBLE_TMTRAINER) then
						else
							adder = true 
							Imitate_item_holder.assign_fake_item(player,CollectibleType.COLLECTIBLE_TMTRAINER,true)
						end
						local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						if adder then Imitate_item_holder.re_assign_fake_item() end
						sound_tracker.PlayStackedSound(267,1,1,false,0,2)
					end
					player:UseActiveItem(item.entity,UseFlag.USE_OWNED,slot)
					player:SetActiveCharge(player:GetBatteryCharge(slot), slot)
					if auxi.should_spawn_wisp(player) then 
						for i = 1,item.limit do
							player:AddItemWisp(d["Alchemy_Pot_select_st"..tostring(i)],player.Position,true)
						end
					end
					return 0
				end
			end
			return -1
		elseif dir == 5 then 
			tp = tp % 4 + 1
		elseif dir == 4 then
			tp = (tp + 2)% 4 + 1
		else 
			return -1
		end
	else
		if vr == 1 then
			if dir == 5 then 
				tp = tp % 4 + 1
			elseif dir == 4 then
				tp = (tp + 2)% 4 + 1
			elseif dir == 6 then
				vr = 2
			elseif dir == 7 then
				return -1
			end
		elseif vr == 2 then
			if dir == 5 then
				i = (i + 1) % column
			elseif dir == 4 then
				i = (i + column - 1)% column
			elseif dir == 7 then
				j = (j + 1) % raw
			elseif dir == 6 then
				j = (j + raw - 1) % raw
			end
		end
	end
	if dir == 9 then
		if vr == 2 then
			d["Alchemy_Pot_select_st"..tostring(tp)] = (d[item.own_key.."list"][sl + 1] or {}).id or 0
		end
		vr = 3 - vr 
	end
	--print(dir.." "..tp.." "..vr)
	makeitemlist(player,tp)
	d.Alchemy_Pot_select_tp = tp
	d.Alchemy_Pot_select_vr = vr
	d["Alchemy_Pot_select_sl"] = i + j * column
	return 0
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	if player:HasCollectible(item.entity) then
		for i = 1,item.limit do
			makeitemlist(player,i)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local d = player:GetData()
		if d[item.own_key.."effect"] ~= true then
			d[item.own_key.."effect"] = true
			d[item.own_key.."lift"] = true
			item.last_open_dir = 9
			return {Discharge = false}
		else
			player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
			selection_holder.remove_select(player,item.own_key)
			d[item.own_key.."effect"] = false
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
		reflush_selector(player)
	end
	if d[item.own_key.."effect"] and not d[item.own_key.."lift"] then
		if player:IsHoldingItem() == false then
			d[item.own_key.."effect"] = false
			selection_holder.remove_select(player,item.own_key)
		else
			if selection_holder.check_select(player,item.own_key) and Game():IsPaused() == false then
				local dir = nil
				for u,i in pairs({4,5,6,7,9,11}) do
					if (Input.IsActionTriggered(i,ctrlid) or Input.IsActionPressed(i,ctrlid)) then
						dir = i
					end
				end
				local should_count = false
				if dir then
					if dir == 11 then
						local slot = auxi.check_slot_with_item(player,item.entity)
						player:UseActiveItem(item.entity,UseFlag.USE_OWNED,slot)
					end
					if dir == item.last_open_dir then
						item.last_open_dir_counter = (item.last_open_dir_counter or 0) + 1
						if item.last_open_dir_counter > item.dir_time_limit and item.last_open_dir_counter % 8 == 1 then
							should_count = true
						end
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
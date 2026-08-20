local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Wheel_of_Destiny,
	own_key = "Thoth_cd10_Whe_",
	button_list = {
		4,5,6,7,9,11,
	},
	dir_time_limit = 20,
	start_pos = Vector(0,-30),
	mov_pos = Vector(30,0),
	mov_pos2 = Vector(0,30),
}

local function get_column(player,number)
	local ret = math.max(3,math.ceil(math.sqrt(number)))
	local delpos = Isaac.WorldToScreen(player.Position) + item.start_pos - item.mov_pos2 * 0.5 	--ui.GetScreenSize()
	local mxn = math.max(1,math.ceil(delpos.Y / 32))
	ret = math.max(math.ceil(number / mxn),ret)
	return ret
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."last_open_dir"] = {}
	save.elses[item.own_key.."last_open_dir_counter"] = {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	delay_buffer.addeffe(function(params)
		local n_entity = Isaac.GetRoomEntities()
		local room = Game():GetRoom()
		for u,v in pairs(n_entity) do
			if v.Type == 3 and v.Variant == 237 then
				local succ = consistance_holder.try_check_entity(v,item.own_key)
				if succ then
					local d = v:GetData()
					consistance_holder.try_hold_over_entity(v,item.own_key)
					d._Data[item.own_key]["effect"] = (d._Data[item.own_key]["effect"] or 0) - 1
					if d._Data[item.own_key]["effect"] <= 0 then
						unique_holder.Hold_for_missing(true)
						local q = Isaac.Spawn(5,100,v.SubType,room:FindFreePickupSpawnPosition(v.Position,10,true),Vector(0,0),nil):ToPickup()
						auxi.self_morph(q,{5,100,v.SubType,})
						unique_holder.Hold_for_missing()
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
						local e1 = Isaac.Spawn(1000,16,2,q.Position,Vector(0,0),nil)
						local e2 = Isaac.Spawn(1000,16,1,q.Position,Vector(0,0),nil)
						consistance_holder.try_remove_entity(v,item.own_key)
						v:Kill()
					else
						consistance_holder.try_hold_entity(v,item.own_key,{keep_level = true,})
					end
				end
			end
		end
	end,{},1)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if ent ~= nil then
		local player = ent:ToPlayer()
		if player then
			local d = player:GetData()
			if d[item.own_key.."effect"] and selection_holder.check_select(player,item.own_key) then
				for u,i in pairs(item.button_list) do
					if button == i and (hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED) then
						return false
					end
				end
			end
		end
	end
end,
})

local function makeitemlist(player)
	local d = player:GetData()
	d[item.own_key.."list"] = {}
	local config = Isaac:GetItemConfig()
	local sz = config:GetCollectibles().Size
	for i = 1,sz do
		local col = config:GetCollectible(i)
		if col and (col.Hidden ~= true) and (col.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST) then
			local num = player:GetCollectibleNum(i,true)
			if num > 0 then
				if i == enums.Items.It_s_a_trick then col = config:GetCollectible(save.elses.glazed_trick or 32) or config:GetCollectible(32) end
				if num > 0 then table.insert(d[item.own_key.."list"],#d[item.own_key.."list"] + 1,{id = i,spritename = col.GfxFileName,}) end
			end
		end
	end
end

local function render_selector(player)
	local d = player:GetData()
	local stpos = Isaac.WorldToScreen(player.Position) + item.start_pos
	if d[item.own_key.."list"] == nil then makeitemlist(player) end
	local sl = d[item.own_key.."select"] or 0
	local column = get_column(player,#d[item.own_key.."list"] + 1)
	local mxn = math.ceil((#d[item.own_key.."list"] + 1)/column) * column
	local spos = Isaac.WorldToScreen(player.Position) + item.start_pos - item.mov_pos * ((column - 1)/2) - item.mov_pos2 * (mxn/column)
	for ii = 1,mxn do
		local info = d[item.own_key.."list"][ii] or {id = 0,spritename = "gfx/ui/math/exclude_mark.png",}
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
		end
	end
end

local function move(player,dir)
	local d = player:GetData()
	local column = get_column(player,#d[item.own_key.."list"] + 1)
	local raw = math.ceil((#d[item.own_key.."list"] + 1) / column)
	local sl = d[item.own_key.."select"] or 0
	local i = sl % column
	local j = math.floor(sl/column)
	if dir == 5 then
		i = (i + 1) % column
	elseif dir == 4 then
		i = (i + column - 1)% column
	elseif dir == 7 then
		j = (j + 1) % raw
	elseif dir == 6 then
		j = (j + raw - 1) % raw
	end
	d[item.own_key.."select"] = i + j * column
	makeitemlist(player)
	return 0
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	if player:GetData()[item.own_key.."effect"] then
		makeitemlist(player)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local ctrlid = player.ControllerIndex
	local d = player:GetData()
	local room = Game():GetRoom()
	for ii = 1,1 do if d[item.own_key.."effect"] then
		if player:IsHoldingItem() == false then
			if selection_holder.check_select(player,item.own_key) and Game():IsPaused() == false then
				player:AnimateCard(item.entity,"LiftItem")
			end
		else
			if selection_holder.check_select(player,item.own_key) and Game():IsPaused() == false then
				local dir = nil
				for u,i in pairs(item.button_list) do
					if (Input.IsActionTriggered(i,ctrlid) or Input.IsActionPressed(i,ctrlid)) then
						dir = i
					end
				end
				local should_count = false
				if dir then
					if dir == 11 then
						player:AnimateCard(item.entity,"HideItem")
						d[item.own_key.."effect"] = nil
						selection_holder.remove_select(player,item.own_key)
						local q = Isaac.Spawn(5,300,item.entity,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						q:Morph(5,300,item.entity,true,true,true)
						local s2 = q:GetSprite()
						s2:SetLastFrame()
						break
					end
					save.elses[item.own_key.."last_open_dir"] = save.elses[item.own_key.."last_open_dir"] or {}
					save.elses[item.own_key.."last_open_dir_counter"] = save.elses[item.own_key.."last_open_dir_counter"] or {}
					if dir == save.elses[item.own_key.."last_open_dir"][ctrlid] then
						save.elses[item.own_key.."last_open_dir_counter"][ctrlid] = (save.elses[item.own_key.."last_open_dir_counter"][ctrlid] or 0) + 1
						if save.elses[item.own_key.."last_open_dir_counter"][ctrlid] > item.dir_time_limit and save.elses[item.own_key.."last_open_dir_counter"][ctrlid] % 8 == 1 then
							should_count = true
						end
					else
						save.elses[item.own_key.."last_open_dir_counter"][ctrlid] = 0
						should_count = true
					end
				end
				save.elses[item.own_key.."last_open_dir"][ctrlid] = dir
				if should_count then
					local succ = move(player,dir)
					if succ == -1 then
						sound_tracker.PlayStackedSound(187,1,1,false,0,2)
					else
						if dir == 5 or dir == 6 then
							sound_tracker.PlayStackedSound(195,1,1,false,0,2)
						elseif dir == 4 or dir == 7 then
							sound_tracker.PlayStackedSound(194,1,1,false,0,2)
						end
					end
					
					if dir == 9 then
						d[item.own_key.."effect"] = nil
						selection_holder.remove_select(player,item.own_key)
						if d[item.own_key.."list"] == nil then makeitemlist(player) end
						local colinfo = d[item.own_key.."list"][(d[item.own_key.."select"] or 0) + 1] or {id = 0,spritename = "gfx/ui/math/exclude_mark.png",}
						if colinfo and colinfo.id ~= 0 then
							local colid = colinfo.id
							sound_tracker.PlayStackedSound(285,1,1,false,0,2)
							player:AnimateCollectible(colid,"LiftItem","PlayerPickup")
							delay_buffer.addeffe(function(params)
								if auxi.check_all_exists(player) and player:IsHoldingItem() then
									player:AnimateCollectible(colid,"HideItem","PlayerPickup")
									player:RemoveCollectible(colid)
									sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
									local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player)
									local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),player)
									local cnt = 2
									local mxhp = 1
									if d[item.own_key.."effect2"] then 
										cnt = 3
										mxhp = 2
									end
									for i = 1,cnt do
										local q = player:AddItemWisp(colid,player.Position,true)
										local d2 = q:GetData()
										q.HitPoints = mxhp
										d2._Data = d2._Data or {}
										d2._Data[item.own_key] = d2._Data[item.own_key] or {}
										d2._Data[item.own_key]["effect"] = 2
										consistance_holder.try_hold_entity(q,item.own_key,{keep_level = true,})
									end
								end
							end,{},15)
						else
							player:AnimateCard(item.entity,"HideItem")
							local q = Isaac.Spawn(5,300,item.entity,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
							q:Morph(5,300,item.entity,true,true,true)
							local s2 = q:GetSprite()
							s2:SetLastFrame()
						end
					end
				end
			end
		end
	end end
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

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d[item.own_key.."effect"] ~= true then
			player:AnimateCard(item.entity,"LiftItem")
			selection_holder.check_and_try_select(player,item.own_key)
			d[item.own_key.."effect"] = true
			makeitemlist(player)
			local ctrlid = player.ControllerIndex
			local dir = nil
			for u,i in pairs(item.button_list) do
				if (Input.IsActionTriggered(i,ctrlid) or Input.IsActionPressed(i,ctrlid)) then
					dir = i
				end
			end
			save.elses[item.own_key.."last_open_dir"] = save.elses[item.own_key.."last_open_dir"] or {}
			save.elses[item.own_key.."last_open_dir"][ctrlid] = dir		--白卡
			save.elses[item.own_key.."last_open_dir_counter"][ctrlid] = 0
		end			
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			d[item.own_key.."effect2"] = true
		else
			d[item.own_key.."effect2"] = nil
		end
	end
end,
})

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Core_Brooch,
	own_key = "Item_Core_Brooch_",
	start_pos = Vector(0,-50),
	mov_pos = Vector(30,0),
	dir_time_limit = 20,
	maxlimit = 3,
	buffinfo = {
		[1] = {name = "speed",cache = CacheFlag.CACHE_SPEED,
			toget = function(player) return player.MoveSpeed end,mul = 0.6,},
		[2] = {name = "tear",cache = CacheFlag.CACHE_FIREDELAY,
			toget = function(player) return 30 / (player.MaxFireDelay + 1) end,mul = 1.5,},
		[3] = {name = "damage",cache = CacheFlag.CACHE_DAMAGE,
			toget = function(player) return player.Damage end,mul = 3,},
		[4] = {name = "range",cache = CacheFlag.CACHE_RANGE,
			toget = function(player) return player.TearRange end,mul = 4.5 * 40,},
		[5] = {name = "shotspeed",cache = CacheFlag.CACHE_SHOTSPEED,
			toget = function(player) return player.ShotSpeed end,mul = 0.6,},
		[6] = {name = "luck",cache = CacheFlag.CACHE_LUCK,
			toget = function(player) return player.Luck end,mul = 6,},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then else save.elses[item.own_key.."effect"] = {} end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	local d = player:GetData()
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local idx = player:GetData().__Index
		if d[item.own_key.."effect"] then 
			d[item.own_key.."effect"] = nil
			player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
			selection_holder.remove_select(player,item.own_key)
		else d[item.own_key.."lift"] = {} d[item.own_key.."effect"] = {} item.last_open_dir = 9 end
		save.elses[item.own_key.."ToSelect"] = save.elses[item.own_key.."ToSelect"] or {}
		save.elses[item.own_key.."ToSelect"][idx] = save.elses[item.own_key.."ToSelect"][idx] or item.makechoice(player)
		return {Discharge = false}
	end
	return ret
end,
})

function item.makechoice(player)
	local rng = player:GetCollectibleRNG(item.entity)
	local tbl = auxi.randomTable({1,2,3,4,5,6,},rng)
	return tbl
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local room = Game():GetRoom()
	local s = player:GetSprite()
	local d = player:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		if d[item.own_key.."effect"] and player:IsHoldingItem() then
			if selection_holder.check_select(player,item.own_key) then
				--render_selector(player)
				local idx = player:GetData().__Index
				save.elses[item.own_key.."ToSelect"] = save.elses[item.own_key.."ToSelect"] or {}
				save.elses[item.own_key.."ToSelect"][idx] = save.elses[item.own_key.."ToSelect"][idx] or item.makechoice(player)
				local stpos = Isaac.WorldToScreen(player.Position) + item.start_pos - ((item.maxlimit - 1)/2) * item.mov_pos
				for i = 1,item.maxlimit do
					local info = item.buffinfo[save.elses[item.own_key.."ToSelect"][idx][i] or 1]
					local s = Sprite() s:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true) s:ReplaceSpritesheet(0,"gfx/ui/status/"..(info.name)..".png") s:LoadGraphics() s:Play("Idle",true) 
					local selected = (i - 1) == (d[item.own_key.."effect"].selected or 0)
					if not selected then s.Color = Color(1,1,1,1,-0.2,-0.2,-0.2) end
					s:Render(stpos,Vector(0,0),Vector(0,0))
					if selected then 
						local s2 = Sprite() s2:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true) s2:ReplaceSpritesheet(0,"gfx/ui/math/catch_mark.png") s2:LoadGraphics() s2:Play("Idle",true) 
						s2:Render(stpos,Vector(0,0),Vector(0,0))
					end
					stpos = stpos + item.mov_pos
				end
			end
		end
	end
end,
})

local function move(player,dir)
	local d = player:GetData()
	local idx = player:GetData().__Index
	if dir == 4 or dir == 6 then d[item.own_key.."effect"].selected = ((d[item.own_key.."effect"].selected or 0) - 1) % item.maxlimit end
	if dir == 5 or dir == 7 then d[item.own_key.."effect"].selected = ((d[item.own_key.."effect"].selected or 0) + 1) % item.maxlimit end
	if dir == 9 then
		save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0) + 1
		save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
		save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
		for i = 1,item.maxlimit do
			local info = item.buffinfo[save.elses[item.own_key.."ToSelect"][idx][i] or 1]
			local selected = (i - 1) == (d[item.own_key.."effect"].selected or 0)
			if selected then save.elses[item.own_key.."buff"][idx][info.name] = (save.elses[item.own_key.."buff"][idx][info.name] or 0) + item.maxlimit * 0.1
			else save.elses[item.own_key.."buff"][idx][info.name] = (save.elses[item.own_key.."buff"][idx][info.name] or 0) - 0.1 end
			player:AddCacheFlags(info.cache)
		end
		player:GetData().should_evaluate_on_update_once = true
		save.elses[item.own_key.."ToSelect"][idx] = nil
		local slot = auxi.check_slot_with_item(player,item.entity)
		player:UseActiveItem(item.entity,UseFlag.USE_OWNED,slot)
		if save.elses[item.own_key.."effect"][idx] >= 10 then 
			save.elses[item.own_key.."effect"][idx] = 0
			player:RemoveCollectible(item.entity)
			player:AnimateSad()
			Game():BombExplosionEffects(player.Position,player.Damage * 5,BitSet128(0,0),Color(1,1,1,1,0.3,0,0),player,1,false,false)
			local q = Isaac.Spawn(5,350,enums.Trinkets.Broken_Brooch,player.Position,Vector(0,0),player):ToPickup()		--Game():GetRoom():FindFreePickupSpawnPosition(player.Position,10,true)
			q:Morph(5,350,enums.Trinkets.Broken_Brooch,true,true,true)
			q.Velocity = auxi.RoundVector(q:GetDropRNG(),1,{leg2 = 5,})
			sound_tracker.PlayStackedSound(267,1,1,false,0,2)
		else sound_tracker.PlayStackedSound(268,1,1,false,0,2) end
	end
	return 0
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if save.elses[item.own_key.."buff"] then
		local idx = player:GetData().__Index
		if idx ~= nil and save.elses[item.own_key.."buff"][idx] then
			if cacheFlag == CacheFlag.CACHE_DAMAGE then
				player.Damage = player.Damage + (save.elses[item.own_key.."buff"][idx].damage or 0)
			end
			if cacheFlag == CacheFlag.CACHE_FIREDELAY then
				player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,(save.elses[item.own_key.."buff"][idx].tear or 0))
			end
			if cacheFlag == CacheFlag.CACHE_RANGE then
				player.TearRange = player.TearRange + (save.elses[item.own_key.."buff"][idx].range or 0) * 40 * 2.5
			end
			if cacheFlag == CacheFlag.CACHE_SPEED then
				player.MoveSpeed = player.MoveSpeed + (save.elses[item.own_key.."buff"][idx].speed or 0) * 0.5
			end
			if cacheFlag == CacheFlag.CACHE_LUCK then
				player.Luck = player.Luck + (save.elses[item.own_key.."buff"][idx].luck or 0) * 5
			end
			if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
				player.ShotSpeed = player.ShotSpeed + (save.elses[item.own_key.."buff"][idx].shotspeed or 0)
			end
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
	local d = player:GetData()
	if d[item.own_key.."lift"] and player:IsExtraAnimationFinished() then
		player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
		selection_holder.check_and_try_select(player,item.own_key)
		d[item.own_key.."lift"] = nil
		--reflush_selector(player)
	end
	if d[item.own_key.."effect"] and not d[item.own_key.."lift"] then
		if player:IsHoldingItem() == false then	d[item.own_key.."effect"] = nil selection_holder.remove_select(player,item.own_key)	else
			if selection_holder.check_select(player,item.own_key) and Game():IsPaused() == false then
				local dir = nil
				local ctrlid = player.ControllerIndex
				for u,i in pairs({4,5,6,7,9,11}) do if (Input.IsActionTriggered(i,ctrlid) or Input.IsActionPressed(i,ctrlid)) then dir = i end end
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
					if succ == -1 then sound_tracker.PlayStackedSound(187,1,1,false,0,2) else
						if dir == 5 or dir == 6 then sound_tracker.PlayStackedSound(195,1,1,false,0,2)
						elseif dir == 4 or dir == 7 then sound_tracker.PlayStackedSound(194,1,1,false,0,2)
						elseif dir == 9 then sound_tracker.PlayStackedSound(285,1,1,false,0,2) end
					end
				end
			end
		end
	end
end,
})

local ffont = Font()
ffont:Load("font/luaminioutlined.fnt")

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_,player,tp,cid,slot)
	if cid == item.entity then
		local pos = ui.PlayerActiveUIPos(player,slot,auxi.GetPlayerOrder(player),cid)
		local c = slot_render_holder.get_alpha()
		local col = Color(0.5 * c,c,c,1)
		local idx = player:GetData().__Index
		local counter = 10 - (save.elses[item.own_key.."effect"][idx] or 0)
		local str = "*"..tostring(counter)
		gui.draw_ch(pos + Vector(-16,-16),str,1,1,auxi.Color_2_KColor(col),true,ffont)
	end
end,
})

return item
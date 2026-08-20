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
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Priestess,
	own_key = "Thoth_cd2_Pri_",
	costumes = {
		30,55,110,139,195,200,217,		--228,355,732,
	},
	sounds = {
		SoundEffect.SOUND_MOM_VOX_ISAAC,
		SoundEffect.SOUND_MOM_VOX_GRUNT,
		--SoundEffect.SOUND_MOM_VOX_FILTERED_ISAAC,
		--SoundEffect.SOUND_MOM_VOX_EVILLAUGH,
		--SoundEffect.SOUND_MOM_VOX_FILTERED_EVILLAUGH,
	},
}
--l local itemConfig = Isaac.GetItemConfig() local player = Game():GetPlayer(0) player:AddCostume(itemConfig:GetCollectible(29),false)

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."multi"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."multi"] = save.elses[item.own_key.."multi"] or {}
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		if cacheFlag == CacheFlag.CACHE_SIZE then
			save.elses[item.own_key.."multi"] = save.elses[item.own_key.."multi"] or {}
			local mul = save.elses[item.own_key.."multi"][idx]
			if mul then
				player.SpriteScale = player.SpriteScale:Normalized() * math.max(mul * 1.414,player.SpriteScale:Length() * mul * 1.5)
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_REASSIGN_IMITATE_ITEM, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	if save.elses[item.own_key.."effect"][idx] then
		local itemConfig = Isaac.GetItemConfig()
		player:RemoveCostume(itemConfig:GetCollectible(678))
		player:RemoveCostume(itemConfig:GetCollectible(394))
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_REWIND_SAVEDATA, params = nil,
Function = function(_,data)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		local idx = d.__Index
		if save.elses[item.own_key.."effect"][idx] and not data[item.own_key.."effect"][idx] then
			auxi.setCanShoot(player,true)
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	if save.elses[item.own_key.."effect"][idx] then
		value[678] = math.max(value[678] or 0,1)
		value[394] = math.max(value[394] or 0,1)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 29,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."position"] then
		local dir = (d[item.own_key.."position"] - ent.Position)
		if dir:Length() > 0.1 then
			ent.Velocity = dir:Normalized() * math.min(15 + math.min(20,ent.FrameCount),dir:Length() * 0.4)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = nil,
Function = function(_,ent)
	if ent.Variant == 30 or ent.Variant == 153 then
		local player = auxi.check_spawner_player(ent)
		if player then 
			local d = player:GetData()
			local d2 = ent:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
			if save.elses[item.own_key.."effect"][idx] then
				d.fire_delay_counter_Charge_Bar_buff = (d.fire_delay_counter_Charge_Bar_buff or 0) + 1
				if (d.fire_delay_counter_Charge_Bar_buff >= math.max(1,player.MaxFireDelay * 10 - 25) and (not d2[item.own_key.."linker"] or d2[item.own_key.."flush"] == nil)) then
					local rng = player:GetCardRNG(item.entity)
					local rnd = item.sounds[rng:RandomInt(#item.sounds) + 1]
					sound_tracker.PlayStackedSound(rnd,1.5,1,false,0,2)
					local q = Isaac.Spawn(1000,29,0,ent.Position,Vector(0,0),nil):ToEffect()
					q.Parent = player
					q.CollisionDamage = player.Damage * 40
					d2[item.own_key.."linker"] = q
					d2[item.own_key.."flush"] = true
				end
				if d.fire_delay_counter_Charge_Bar_buff >= math.max(1,player.MaxFireDelay * 10) then d2[item.own_key.."flush"] = nil d.fire_delay_counter_Charge_Bar_buff = 0 end
				if d2[item.own_key.."linker"] then
					if auxi.check_all_exists(d2[item.own_key.."linker"]) then
						local d3 = d2[item.own_key.."linker"]:GetData()
						d3[item.own_key.."position"] = ent.Position
					else
						d2[item.own_key.."linker"] = nil
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = nil,
Function = function(_,ent)
	if ent.Variant == 30 or ent.Variant == 153 then
		local player = auxi.check_spawner_player(ent)
		if player then 
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
			if save.elses[item.own_key.."effect"][idx] then
				if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
					Charging_Bar_holder.render_me(player,{name1 = "fire_delay_counter",name2 = "cd2_Priestess_sprite",name3 = "cd2_Priestess_sprite",loadname = "gfx/effects/chargebar/chargebar_cd2_Priestess.anm2",position = ent.Position,offset = Vector(0,0),
						check1 = nil,
						check2 = function(val,ent) 
							return val > math.max(1,player.MaxFireDelay * 10)
						end,
						check3 = function(val,ent)
							return math.ceil(val/math.max(1,player.MaxFireDelay * 10) * 100)
						end,
						signal1 = function(ent)
						end,
					})
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	if save.elses[item.own_key.."effect"][idx] then
		if (save.elses[item.own_key.."effect"][idx] or 0) > 0 then
			auxi.setCanShoot(player,false)
			save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0) - 1
			save.elses[item.own_key.."multi"][idx] = (save.elses[item.own_key.."multi"][idx] or 1) * 0.9 + 2 * 0.1
			if math.abs(save.elses[item.own_key.."multi"][idx] - 2) > 0.05 then 
				player:AddCacheFlags(CacheFlag.CACHE_SIZE)
				d.should_evaluate_on_update_once = true
			else
				if save.elses[item.own_key.."multi"][idx] ~= 2 then 
					save.elses[item.own_key.."multi"][idx] = 2 
					player:AddCacheFlags(CacheFlag.CACHE_SIZE)
					d.should_evaluate_on_update_once = true
				end
			end
		elseif save.elses[item.own_key.."effect"][idx] <= 0 then
			player:AddCacheFlags(CacheFlag.CACHE_SIZE)
			player:GetData().should_evaluate_on_update_once = true
			auxi.setCanShoot(player,true)
			save.elses[item.own_key.."effect"][idx] = nil
			local itemConfig = Isaac.GetItemConfig()
			for u,v in pairs(item.costumes) do
				player:RemoveCostume(itemConfig:GetCollectible(v))
			end
			Imitate_item_holder.Evaluate_Imitate_Items(player)
		end
	elseif save.elses[item.own_key.."multi"][idx] then
		save.elses[item.own_key.."multi"][idx] = (save.elses[item.own_key.."multi"][idx] or 1) * 0.9 + 1 * 0.1
		if math.abs(save.elses[item.own_key.."multi"][idx] - 1) > 0.05 then 
			player:AddCacheFlags(CacheFlag.CACHE_SIZE)
			d.should_evaluate_on_update_once = true
		else
			save.elses[item.own_key.."multi"][idx] = nil
			player:AddCacheFlags(CacheFlag.CACHE_SIZE)
			d.should_evaluate_on_update_once = true
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
		if idx then
			player:AddCacheFlags(CacheFlag.CACHE_SIZE)
			player:GetData().should_evaluate_on_update_once = true
			save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
			local tm = 30 * 60
			if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then tm = tm * 2 end
			save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0) + tm
			local itemConfig = Isaac.GetItemConfig()
			for u,v in pairs(item.costumes) do
				player:AddCostume(itemConfig:GetCollectible(v),false)
			end
			Imitate_item_holder.Evaluate_Imitate_Items(player)
		end
	end
end,
})

return item
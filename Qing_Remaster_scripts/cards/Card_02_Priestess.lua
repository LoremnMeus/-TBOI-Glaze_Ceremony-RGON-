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
local custom_attack_manager = require("Qing_Remaster_scripts.player.custom_attack_manager")

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
item.shoot_block_source = item.own_key.."shoot_block"

local function sync_shoot_block(player, active)
	if active then
		custom_attack_manager.RequestShootBlock(player, item.shoot_block_source)
	else
		custom_attack_manager.ReleaseShootBlock(player, item.shoot_block_source)
	end
end
--l local itemConfig = Isaac.GetItemConfig() local player = Game():GetPlayer(0) player:AddCostume(itemConfig:GetCollectible(29),false)


local function get_roots()
	local effect_key = item.own_key .. "effect"
	local multi_key = item.own_key .. "multi"
	local effect = save.elses[effect_key]
	if type(effect) ~= "table" then
		effect = {}
		save.elses[effect_key] = effect
	end
	local multi = save.elses[multi_key]
	if type(multi) ~= "table" then
		multi = {}
		save.elses[multi_key] = multi
	end
	return effect, multi
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
		get_roots()
	else
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."multi"] = {}
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local effect, multi = get_roots()
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		if cacheFlag == CacheFlag.CACHE_SIZE then
			local mul = multi[idx]
			if mul then
				player.SpriteScale = player.SpriteScale:Normalized() * math.max(mul * 1.414,player.SpriteScale:Length() * mul * 1.5)
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_REASSIGN_IMITATE_ITEM, params = nil,
Function = function(_,player)
	local effect, multi = get_roots()
	local d = player:GetData()
	local idx = d.__Index
	if effect[idx] then
		local itemConfig = Isaac.GetItemConfig()
		player:RemoveCostume(itemConfig:GetCollectible(678))
		player:RemoveCostume(itemConfig:GetCollectible(394))
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_REWIND_SAVEDATA, params = nil,
Function = function(_,data)
	local effect, multi = get_roots()
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		local idx = d.__Index
		if effect[idx] and not data[item.own_key.."effect"][idx] then
			sync_shoot_block(player, false)
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	local effect, multi = get_roots()
	local d = player:GetData()
	local idx = d.__Index
	if effect[idx] then
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

local function update_priestess_effect(_,ent)
	local effect, multi = get_roots()
	local player = auxi.check_spawner_player(ent)
	if player then
			local d = player:GetData()
			local d2 = ent:GetData()
			local idx = d.__Index
			if effect[idx] then
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

local function render_priestess_effect(_,ent)
	local effect, multi = get_roots()
	local player = auxi.check_spawner_player(ent)
	if player then
			local d = player:GetData()
			local idx = d.__Index
			if effect[idx] then
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

for _,variant in ipairs({30,153}) do
	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = variant,
	Function = update_priestess_effect,
	})
	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = variant,
	Function = render_priestess_effect,
	})
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local effect, multi = get_roots()
	local d = player:GetData()
	local idx = d.__Index
	if effect[idx] then
		if (effect[idx] or 0) > 0 then
			sync_shoot_block(player, true)
			effect[idx] = (effect[idx] or 0) - 1
			multi[idx] = (multi[idx] or 1) * 0.9 + 2 * 0.1
			if math.abs(multi[idx] - 2) > 0.05 then
				player:AddCacheFlags(CacheFlag.CACHE_SIZE)
				d.should_evaluate_on_update_once = true
			else
				if multi[idx] ~= 2 then
					multi[idx] = 2
					player:AddCacheFlags(CacheFlag.CACHE_SIZE)
					d.should_evaluate_on_update_once = true
				end
			end
		elseif effect[idx] <= 0 then
			player:AddCacheFlags(CacheFlag.CACHE_SIZE)
			player:GetData().should_evaluate_on_update_once = true
			sync_shoot_block(player, false)
			effect[idx] = nil
			local itemConfig = Isaac.GetItemConfig()
			for u,v in pairs(item.costumes) do
				player:RemoveCostume(itemConfig:GetCollectible(v))
			end
			Imitate_item_holder.Evaluate_Imitate_Items(player)
		end
	elseif multi[idx] then
		multi[idx] = (multi[idx] or 1) * 0.9 + 1 * 0.1
		if math.abs(multi[idx] - 1) > 0.05 then
			player:AddCacheFlags(CacheFlag.CACHE_SIZE)
			d.should_evaluate_on_update_once = true
		else
			multi[idx] = nil
			player:AddCacheFlags(CacheFlag.CACHE_SIZE)
			d.should_evaluate_on_update_once = true
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local effect, multi = get_roots()
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
			local tm = 30 * 60
			if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then tm = tm * 2 end
			effect[idx] = (effect[idx] or 0) + tm
			sync_shoot_block(player, true)
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

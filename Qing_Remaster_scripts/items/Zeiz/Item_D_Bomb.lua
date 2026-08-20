local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Dull = require("Qing_Remaster_scripts.items.Zeiz.Item_Dull_items")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.D_Bomb,
	own_key = "Item_D_Bomb_",
	costume_name = "gfx/items/bombs/bomb_dull",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
	if source and source.Entity then
		local se = source.Entity
		if item.should_work(se) then
			if ent:ToPlayer() then
				Dull.add_point(ent:ToPlayer(),1)
			else
				local player = auxi.check_spawner_player(se) or auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
				local d = player:GetData()
				local idx = d.__Index
				save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
				save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0) + 1
				player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
				d.should_evaluate_on_update_once = true
			end
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if Game():GetFrameCount() % 10 == 5 then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local d = player:GetData()
			local idx = d.__Index
			if save.elses[item.own_key.."effect"][idx] and save.elses[item.own_key.."effect"][idx] > 0 then
				save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] - 0.05
				player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
				d.should_evaluate_on_update_once = true
			end
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
			local mul = save.elses[item.own_key.."effect"][idx]
			if mul then
				player.Damage = player.Damage + auxi.get_damage_multiplier(player) * mul 
			end
		end
	end
end,
})

function item.trigger_effect(ent,pos,params)
end

function item.replace_costume(ent)
	if item.should_work(ent) then
		local s = ent:GetSprite() local fname = s:GetFilename() local id = 2
		for i = 0, 3 do if (string.sub(fname, -6) == i..".anm2") then id = i break end end
		local suffix = ""
		s:Load(item.costume_name..suffix..id..".anm2", true)
		s:Play("Pulse", true)
	end
end

function item.add_work(ent)
	consistance_holder.try_hold_entity(ent,item.own_key)
	item.replace_costume(ent)
end

function item.should_work(ent)
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ then return true end return false
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_TRIGGER_BOMB_EFFECT, params = nil,
Function = function(_,player,tp,spawner,ent,scale)
	if auxi.has_have_coll(player,item.entity) then
		local succ = true if tp == "epic" then if auxi.check_rand(player.Luck,50,11,13) then else succ = false end end
		if succ then item.trigger_effect(player,ent.Position,{scale = scale,}) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_BOMB_UPDATE, params = nil,
Function = function(_,ent)	
	if ent.FrameCount < 2 then
		if not REPENTOGON then
			local player = auxi.check_spawner_player(ent)
            if player and auxi.has_have_coll(player,item.entity) then
				if ent.IsFetus then if auxi.check_rand(player.Luck,50,11,13) then item.add_work(ent) end
				else item.add_work(ent) end
			end
		end
		if item.should_work(ent) then item.replace_costume(ent) end
	end
	if ent:IsDead() then
		if item.should_work(ent) then
			item.trigger_effect(ent,ent.Position,{ent = ent,})
		end
	end
end,
})

if REPENTOGON then

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_FIRE_BOMB, params = nil,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent)
	if player and auxi.has_have_coll(player,item.entity) then
		if auxi.check_rand(player.Luck,50,11,13) then item.add_work(ent) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_USE_BOMB, params = nil,
Function = function(_,player,ent)
	if player and auxi.has_have_coll(player,item.entity) then item.add_work(ent) end
end,
})
	
end

return item
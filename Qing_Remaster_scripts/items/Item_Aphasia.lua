local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local displaying_data = require("Qing_Remaster_scripts.translations.data")
local displaying_data2 = require("Qing_Remaster_scripts.translations.data2")
local displaying_data3 = require("Qing_Remaster_scripts.translations.data3")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Aphasia,
}

function item.insert_word(player,wd)
	local d = player:GetData()
	local idx = player:GetData().__Index
	d.Aphasia_buffer = d.Aphasia_buffer or {}
	table.insert(d.Aphasia_buffer,wd)
	save.elses.Aphasia_damage = save.elses.Aphasia_damage or {}
	save.elses.Aphasia_damage[idx] = (save.elses.Aphasia_damage[idx] or 0) + 1
	player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
	player:GetData().should_evaluate_on_update_once = true
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses.Aphasia_damage = {}
	end
	save.elses.Aphasia_damage = save.elses.Aphasia_damage or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			local d = player:GetData()
			local idx = player:GetData().__Index
			player.Damage = player.Damage + (math.sqrt((save.elses.Aphasia_damage[idx] or 0) + 4) - 2) * 0.4 * auxi.get_damage_multiplier(player)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		if Game():GetFrameCount() % 10 == 5 then
			local d = player:GetData()
			local idx = player:GetData().__Index
			save.elses.Aphasia_damage[idx] = (save.elses.Aphasia_damage[idx] or 0) * 0.97
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_FIRE_TEAR, params = nil,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent)
	if player and auxi.has_have_coll(player,item.entity) then
		local d = player:GetData()
		if d.Aphasia_buffer ~= nil and #d.Aphasia_buffer > 0 then
			local rng = player:GetCollectibleRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			local rnd = rng:RandomInt(#d.Aphasia_buffer) + 1
			ent:GetData().Aphasia_render_word = d.Aphasia_buffer[rnd]
			table.remove(d.Aphasia_buffer,rnd)
			ent.CollisionDamage = ent.CollisionDamage * auxi.get_word_damage(ent:GetData().Aphasia_render_word)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_RENDER, params = nil,
Function = function(_,ent,offset)
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		local d = ent:GetData()
		if d.Aphasia_render_word then
			local s = ent:GetSprite()
			local offset = auxi.get_word_render_offset(d.Aphasia_render_word)
			local sx = s.Scale.X
			local sy = s.Scale.Y
			gui.draw_ch(Isaac.WorldToScreen(ent.Position + ent.PositionOffset) + Vector(sx * offset.X,sy * offset.Y),d.Aphasia_render_word,sx,sy,auxi.Color_2_KColor(ent:GetColor()),true)
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	if player == nil or player:Exists() == false or player:IsDead() then player = Game():GetPlayer(0) end
	if auxi.has_have_coll(player,item.entity) then
		local name = value.Name
		local des = value.Description
		local target = name..des
		local ret = auxi.random_shuffle_string(target,player:GetCollectibleRNG(item.entity))
		if #des > 0 then
			local cut_n = math.min(#ret,math.max(0,auxi.get_string_real_length(name) + math.random(3) - 1))
			local result_name = auxi.collect_table_to_string(ret,1,cut_n)
			local result_des = auxi.collect_table_to_string(ret,cut_n + 1,#ret)
			return {Name = result_name,Description = result_des,}
		else
			local result = auxi.collect_table_to_string(ret)
			return {Name = result,Description = "",}
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,value)
	if player == nil or player:Exists() == false or player:IsDead() then player = Game():GetPlayer(0) end
	if auxi.has_have_coll(player,item.entity) then
		local name = value.Name or ""
		local des = value.Description or ""
		if type(des) == "table" then des = auxi.collect_table_to_string(des) end
		local target = auxi.spilt_string(name..des)
		local rng = player:GetCollectibleRNG(item.entity)
		rng = auxi.rng_for_sake(rng)
		local rnd = rng:RandomInt(math.floor(#target)) + 1
		target = auxi.randomTable(target,rng)
		for i = 1,rnd do
			local word = target[i]
			local q = auxi.fire_nil(player.Position,auxi.MakeVector(math.random(3600)/10) * (math.random(5) + 5),{cooldown = 30 * 5,})
			q.GridCollisionClass = GridCollisionClass.COLLISION_OBJECT
			local d2 = q:GetData()
			d2.nil_mode = "aphasia_word"
			d2.is_Aphasia_word = true
			if d2.Params == nil then d2.Params = {} end
			d2.Params.Accerate = - 0.25
			d2.RenderHeight = math.random(1000)/1000 * 5 + 15
			d2.RenderHeight_Velocity = math.random(1000)/1000 * 3 + 2
			d2.floor = 0
			d2.Aphasia_word = word
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_TELL_FORTUNE, params = nil,
Function = function(_,tp,value)
	local result = nil
	local player = nil
	for playerNum = 1, Game():GetNumPlayers() do
		local t_player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(t_player,item.entity) then
			player = t_player
			break
		end
	end
	if player then
		local rng = player:GetCollectibleRNG(item.entity)
		rng = auxi.rng_for_sake(rng)
		local language = auxi.get_language_map(Options.Language)
		if language then
			if tp == "Fortune" then
				if rng:RandomInt(1000) > 300 then
					local rnd = rng:RandomInt(64) + 1
					if displaying_data[language] then
						local data = displaying_data[language]["#Entry_"..tostring(rnd)]
						if data then
							result = auxi.random_work_on_the_raw_string(data,rng)
						end
					end
				else
					local rnd = rng:RandomInt(69) + 1
					if displaying_data3[language] then
						local data = displaying_data3[language]["#Entry_"..tostring(rnd)]
						if data then
							result = auxi.random_work_on_the_raw_string(data,rng)
						end
					end
				end
			elseif tp == "Tips" then
				local rnd = rng:RandomInt(8) + 1
				if displaying_data2[language] then
					local data = displaying_data2[language]["#Entry_"..tostring(rnd)]
					if data then
						result = auxi.random_work_on_the_raw_string(data,rng)
					end
				end
			end
		end
		result = {Description = result,}
	end
	return result
end,
})

Nil_holder.register("aphasia_word", {
	detect = function(d) return d.is_Aphasia_word and d.Aphasia_word end,
	update = function(ent, d, s, player)
		if not (d.is_Aphasia_word and d.Aphasia_word) then return end
		if d.RenderHeight and d.RenderHeight < 0.0001 then
			if (player.Position - ent.Position):Length() < 30 and d.should_not_collect == nil then
				item.insert_word(player,d.Aphasia_word)
				player:AnimateHappy()
				d.is_Aphasia_word = nil
				d.removecd = 1
			end
		end
	end,
	render = function(ent, d, s, player)
		if not (d.is_Aphasia_word and d.Aphasia_word) then return end
		if d.word_size == nil then d.word_size = 1 end
		if d.floor == nil then d.floor = 0 end
		local sx = d.word_size
		local sy = d.word_size
		gui.draw_ch(Isaac.WorldToScreen(ent.Position + Vector(0,-2) * d.RenderHeight) + Vector(-sx * 5,-sy * 5),d.Aphasia_word,sx,sy,auxi.Color_2_KColor(player.TearColor),true)
		d.RenderHeight = math.max(0,d.RenderHeight + d.RenderHeight_Velocity)
		if d.RenderHeight > 0.0001 then
			d.word_size = d.word_size * 1.01
		elseif d.floor < 10 then
			d.floor = d.floor + 1
			d.word_size = d.word_size + 0.05
		else
			d.word_size = d.word_size * 0.97
		end
		if d.small_quickly then d.word_size = d.word_size * 0.75 end
		if d.word_size <= 0.3 then
			d.should_not_collect = true
			d.small_quickly = true
			d.removecd = 7
		end
		d.RenderHeight_Velocity = d.RenderHeight_Velocity - 0.3
	end,
})

return item
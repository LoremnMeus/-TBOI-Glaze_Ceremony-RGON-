local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Wavering_Eyes,
	own_key = "Item_Wav_Eye_",
	buff_offsets = {
		[5] = {flag = BitSet128(0,1<<(68-64)),},
		[8] = {flag = BitSet128(1<<2,0),},
		[13] = {flag = BitSet128(1<<30,0),},
		[21] = {flag = BitSet128(1<<19,0),},
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local idx = player:GetData().__Index
		if idx then
			save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
			if cacheFlag == CacheFlag.CACHE_FIREDELAY then
				player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * 0.5 * math.sqrt(math.floor((save.elses[item.own_key.."effect"][idx] or 0)/3)))
			end
			if cacheFlag == CacheFlag.CACHE_TEARFLAG then
				for u,v in pairs(item.buff_offsets) do
					if (save.elses[item.own_key.."effect"][idx] or 0) >= u then
						player.TearFlags = player.TearFlags | v.flag
					end
				end
			end
			if cacheFlag == CacheFlag.CACHE_TEARCOLOR then
				local mul = math.max(0,math.min(1,math.sqrt(save.elses[item.own_key.."effect"][idx] or 0)/10))
				player.TearColor = auxi.AddColor(player.TearColor,Color(0.8,0.3,0.7,1,0.7,0,0.7),-0.5 + 1.5 * (1 - mul),1.5 * mul)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_FIRE_TEAR, params = nil,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent)
	if player and auxi.has_have_coll(player,item.entity) then
		local idx = player:GetData().__Index
		if idx then
			local d = ent:GetData()
			local rng = player:GetCollectibleRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			d.count_waver_eye = true
			save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
			local rnd_flg = math.floor((save.elses[item.own_key.."effect"][idx] or 0)/2) * 5
			local dir_rnd = rng:RandomInt(rnd_flg * 2 + 1) - rnd_flg
			ent.Velocity = auxi.MakeVector(ent.Velocity:GetAngleDegrees() + dir_rnd) * ent.Velocity:Length()
		end
	end
end,
})

function item.add_waver_eye_charge(player)
	local idx = player:GetData().__Index
	if idx then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		save.elses[item.own_key.."effect2"] = save.elses[item.own_key.."effect2"] or {}
		save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0) + 1
		if (save.elses[item.own_key.."effect2"][idx] or 0) > 0 then save.elses[item.own_key.."effect2"][idx] = save.elses[item.own_key.."effect2"][idx] - 0.3 end
		if save.elses[item.own_key.."effect"][idx] % 3 == 0 then player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY) end
		if item.buff_offsets[save.elses[item.own_key.."effect"][idx]] then player:AddCacheFlags(CacheFlag.CACHE_TEARFLAG) end
		player:AddCacheFlags(CacheFlag.CACHE_TEARCOLOR)
		player:GetData().should_evaluate_on_update_once = true
	end
end

function item.clear_waver_eye_charge(player)
	local idx = player:GetData().__Index
	if idx then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		save.elses[item.own_key.."effect2"] = save.elses[item.own_key.."effect2"] or {}
		save.elses[item.own_key.."effect2"][idx] = (save.elses[item.own_key.."effect2"][idx] or 0) + 1
		if save.elses[item.own_key.."effect2"][idx] >= 4 then
			save.elses[item.own_key.."effect"][idx] = 0
			save.elses[item.own_key.."effect2"][idx] = 0
			player:AddCacheFlags(CacheFlag.CACHE_TEARCOLOR | CacheFlag.CACHE_TEARFLAG | CacheFlag.CACHE_FIREDELAY)
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_,ent,col,low)
	if ent.SpawnerType == 1 and ent.Parent then
		local player = ent.Parent:ToPlayer()
		if player and col:IsVulnerableEnemy() and col:IsActiveEnemy() then
			if auxi.has_have_coll(player,item.entity) then
				local d = ent:GetData()
				if d.count_waver_eye or d.should_count_waver_eye then
					d.count_waver_eye = nil
					d.should_count_waver_eye = nil
					item.add_waver_eye_charge(player)
				end
			end
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = nil,
Function = function(_,ent)
	if ent.Type == 2 then
		local d = ent:GetData()
		if d.count_waver_eye and ent.Parent then
			local player = ent.Parent:ToPlayer()
			if player and auxi.has_have_coll(player,item.entity) then
				item.clear_waver_eye_charge(player)
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."effect2"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."effect2"] = save.elses[item.own_key.."effect2"] or {}
end,
})

return item
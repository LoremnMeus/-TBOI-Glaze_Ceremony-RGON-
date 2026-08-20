local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Dull = require("Qing_Remaster_scripts.items.Zeiz.Item_Dull_items")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.D_Pointyrib,
	own_key = "Item_D_Pointyrib_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		item.spawn_bone(player)
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."bone"] = save.elses[item.own_key.."bone"] or {}
			save.elses[item.own_key.."damage_count"] = save.elses[item.own_key.."damage_count"] or {}
			save.elses[item.own_key.."respawn_timer"] = save.elses[item.own_key.."respawn_timer"] or {}
			
			-- 检查骨刺是否存在
			if save.elses[item.own_key.."bone"][idx] then
				local bone = save.elses[item.own_key.."bone"][idx]
				if not bone:Exists() or bone:IsDead() then
					-- 骨刺被破坏，开始重生计时
					save.elses[item.own_key.."bone"][idx] = nil
					save.elses[item.own_key.."respawn_timer"][idx] = 600 -- 10秒后重生
				else
					-- 检查伤害计数
					local damageCount = save.elses[item.own_key.."damage_count"][idx] or 0
					if damageCount >= 10 then
						-- 造成10次伤害后骨刺破碎
						bone:Die()
						save.elses[item.own_key.."bone"][idx] = nil
						save.elses[item.own_key.."damage_count"][idx] = 0
						save.elses[item.own_key.."respawn_timer"][idx] = 600
					end
				end
			end
			
			-- 重生计时器
			if save.elses[item.own_key.."respawn_timer"][idx] and save.elses[item.own_key.."respawn_timer"][idx] > 0 then
				save.elses[item.own_key.."respawn_timer"][idx] = save.elses[item.own_key.."respawn_timer"][idx] - 1
				if save.elses[item.own_key.."respawn_timer"][idx] <= 0 then
					-- 消耗1点幸运重新生成
					if player.Luck >= 1 then
						player.Luck = player.Luck - 1
						player:AddCacheFlags(CacheFlag.CACHE_LUCK)
						d.should_evaluate_on_update_once = true
						item.spawn_bone(player)
					end
				end
			end
		end
	end
end,
})

function item.spawn_bone(player)
	local room = Game():GetRoom()
	local pos = room:FindFreePickupSpawnPosition(player.Position, 30, true)
	local bone = Isaac.Spawn(6, 0, 0, pos, Vector(0,0), player) -- 骨刺
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."bone"] = save.elses[item.own_key.."bone"] or {}
	save.elses[item.own_key.."damage_count"] = save.elses[item.own_key.."damage_count"] or {}
	save.elses[item.own_key.."bone"][idx] = bone
	save.elses[item.own_key.."damage_count"][idx] = 0
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
	if ent:IsEnemy() and source and source.Entity then
		local player = source.Entity:ToPlayer()
		if player and auxi.has_have_coll(player,item.entity) then
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."damage_count"] = save.elses[item.own_key.."damage_count"] or {}
			save.elses[item.own_key.."damage_count"][idx] = (save.elses[item.own_key.."damage_count"][idx] or 0) + 1
		end
	end
end,
})

return item


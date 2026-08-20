local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Cup_Cat,
	own_key = "Item_Cup_Cat_",
}

local GUPPY_TAG = ItemConfig.TAG_GUPPY or (1 << 5)

local function is_other_guppy_item(collid)
	if not collid or collid == item.entity then return false end
	local cfg = Isaac.GetItemConfig():GetCollectible(collid)
	if not cfg then return false end
	return (cfg.Tags & GUPPY_TAG) == GUPPY_TAG
end

local function has_other_guppy(player)
	local config = Isaac.GetItemConfig()
	local size = config:GetCollectibles().Size
	for id = 1,size - 1 do
		if is_other_guppy_item(id) and player:GetCollectibleNum(id,true) > 0 then
			return true
		end
	end
	return false
end

local function reward_state(player)
	local idx = player:GetData().__Index
	if idx == nil then return nil end
	save.elses[item.own_key.."rewarded"] = save.elses[item.own_key.."rewarded"] or {}
	save.elses[item.own_key.."rewarded"][idx] = save.elses[item.own_key.."rewarded"][idx] or {n = 0}
	return save.elses[item.own_key.."rewarded"][idx]
end

local function grant_bonus(player)
	player:AddSoulHearts(2)
	local room = Game():GetRoom()
	local rng = player:GetCollectibleRNG(item.entity)
	local card = Game():GetItemPool():GetCard(rng:Next(),true,true,false)
	local pos = room:FindFreePickupSpawnPosition(player.Position,10,true)
	Isaac.Spawn(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_TAROTCARD,card,pos,Vector(0,0),player)
end

-- 每个杯糕猫只奖励一次；条件为身上另有猫套道具
local function sync_rewards(player)
	if not player or not player:Exists() then return end
	local state = reward_state(player)
	if not state then return end
	local cup_n = player:GetCollectibleNum(item.entity,true) or 0
	state.n = math.min(tonumber(state.n) or 0,cup_n)
	if cup_n <= 0 then return end
	if not has_other_guppy(player) then return end
	while state.n < cup_n do
		grant_bonus(player)
		state.n = state.n + 1
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,diff,curNum)
	if not player or not player:Exists() then return end
	if (diff or 0) <= 0 then
		-- 失去杯糕猫时把已发次数钳回当前持有数，再拿可再发
		if collid == item.entity then
			local state = reward_state(player)
			if state then
				local cup_n = player:GetCollectibleNum(item.entity,true) or 0
				state.n = math.min(tonumber(state.n) or 0,cup_n)
			end
		end
		return
	end
	if collid == item.entity or is_other_guppy_item(collid) then
		sync_rewards(player)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if not continue then
		save.elses[item.own_key.."rewarded"] = {}
	else
		save.elses[item.own_key.."rewarded"] = save.elses[item.own_key.."rewarded"] or {}
	end
end,
})

return item

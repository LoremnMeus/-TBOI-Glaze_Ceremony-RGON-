local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local adjustment_vfx = require("Qing_Remaster_scripts.cards.adjustment_vfx")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Adjustment_r,
	own_key = "Thoth_cd8r_Adj_",
}

local function half_amount(n, rng)
	n = math.max(0, math.floor(n or 0))
	local base = math.floor(n / 2)
	if n % 2 == 1 and rng and rng.RandomInt and rng:RandomInt(2) == 1 then
		base = base + 1
	end
	return base
end

table.insert(item.post_ToCall, #item.post_ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		save.elses[item.own_key.."effect"][idx] = math.max(0, save.elses[item.own_key.."effect"][idx] or 0)
		local mul = ((math.sqrt(save.elses[item.own_key.."effect"][idx] + 5) - math.sqrt(5)) * 0.2)
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * mul * 1.7
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay, auxi.get_mxdelay_multiplier(player) * mul * 0.85)
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + mul * 40 * 1.5
		end
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + mul * 0.26
		end
		if cacheFlag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + mul * 1.74
		end
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	adjustment_vfx.clear_all()
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function()
	adjustment_vfx.clear_all()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	if player.Index == 0 then
		adjustment_vfx.tick()
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_, player, offset)
	adjustment_vfx.capture_player_render(player, offset)
end,
})

local hud_render_cb = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = hud_render_cb, params = nil,
Function = function()
	if not Game():GetHUD():IsVisible() then
		return
	end
	adjustment_vfx.render()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_, cardtype, player, useFlags)
	local rng = player:GetCardRNG(cardtype)
	rng = auxi.rng_for_sake(rng)
	local d = player:GetData()
	local idx = d.__Index

	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return
	end

	local coins = player:GetNumCoins()
	local keys = player:GetNumKeys()
	local bombs = player:GetNumBombs()
	local total = bombs + keys * 0.8 + coins * 0.4

	player:AddBombs(-bombs)
	player:AddKeys(-keys)
	player:AddCoins(-coins)

	if idx then
		save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0) + total
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	end

	local refund = nil
	if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
		refund = {
			coin = half_amount(coins, rng),
			key = half_amount(keys, rng),
			bomb = half_amount(bombs, rng),
		}
	end

	-- LiftItem 唯一入口；VFX 只负责 HideItem
	player:AnimateCard(item.entity, "LiftItem")
	adjustment_vfx.play({
		player = player,
		card_id = item.entity,
		coins = coins,
		keys = keys,
		bombs = bombs,
		total = total,
		refund = refund,
	})
end,
})

return item

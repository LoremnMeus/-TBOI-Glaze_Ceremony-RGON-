local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Abiogenesis,
	familiar = enums.Familiars.Abiogenesis,
	own_key = "Item_Abiogenesis_",
}

auxi.add_to_seija(item.entity)

local RESOURCE_ORDER = {"charge", "coin", "key", "bomb"}
local RESOURCE_DROPS = {
	charge = {Variant = PickupVariant.PICKUP_LIL_BATTERY, SubType = 0},
	coin = {Variant = PickupVariant.PICKUP_COIN, SubType = 0},
	key = {Variant = PickupVariant.PICKUP_KEY, SubType = 0},
	bomb = {Variant = PickupVariant.PICKUP_BOMB, SubType = 0},
}
local RESOURCE_WISPS = {
	charge = item.entity,
	coin = CollectibleType.COLLECTIBLE_WOODEN_NICKEL,
	key = CollectibleType.COLLECTIBLE_DADS_KEY,
	bomb = CollectibleType.COLLECTIBLE_MR_BOOM,
}
local EXCLUDE_TEXT = {
	zh = {
		title = "实验记录",
		charge = "根据实验数据，电能本底过高，充能不纳入统计",
		coin = "根据实验数据，货币属混杂因素，硬币不纳入统计",
		key = "根据实验数据，开锁变量不可复现，钥匙不纳入统计",
		bomb = "根据实验数据，爆破冲击污染对照，炸弹不纳入统计",
	},
	en = {
		title = "Lab Notes",
		charge = "Charge treated as background noise and excluded",
		coin = "Coins treated as a confounder and excluded",
		key = "Keys failed replication and were excluded",
		bomb = "Bombs contaminated the control and were excluded",
	},
}

local function proved_bag()
	save.elses[item.own_key.."proved"] = save.elses[item.own_key.."proved"] or {}
	return save.elses[item.own_key.."proved"]
end

function item.get_proved_count(player)
	local idx = player and player:GetData() and player:GetData().__Index
	if idx == nil then return 0 end
	return proved_bag()[idx] or 0
end

function item.add_proved(player)
	local idx = player and player:GetData() and player:GetData().__Index
	if idx == nil then return 0 end
	local bag = proved_bag()
	bag[idx] = (bag[idx] or 0) + 1
	return bag[idx]
end

local function player_idx(player)
	return player and player:GetData() and player:GetData().__Index
end

local function exclude_bag(player)
	local idx = player_idx(player)
	if idx == nil then return nil end
	save.elses[item.own_key.."exclude"] = save.elses[item.own_key.."exclude"] or {}
	save.elses[item.own_key.."exclude"][idx] = save.elses[item.own_key.."exclude"][idx] or {}
	return save.elses[item.own_key.."exclude"][idx]
end

local function is_excluded(player, kind)
	local idx = player_idx(player)
	if idx == nil then return false end
	local root = save.elses[item.own_key.."exclude"]
	local bag = root and root[idx]
	return bag and bag[kind] == true
end

local function clear_exclude(player)
	local idx = player_idx(player)
	if idx == nil then return end
	save.elses[item.own_key.."exclude"] = save.elses[item.own_key.."exclude"] or {}
	save.elses[item.own_key.."exclude"][idx] = {}
end

local function is_zh()
	local lang = Options.Language
	return lang == "zh" or lang == "zh_cn"
end

local function resolve_slot(player, active_slot)
	if active_slot and active_slot >= 0 and player:GetActiveItem(active_slot) == item.entity then
		return active_slot
	end
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		if player:GetActiveItem(slot) == item.entity then
			return slot
		end
	end
	return -1
end

local function slot_charge(player, slot)
	if not slot or slot < 0 then return 0 end
	return (player:GetActiveCharge(slot) or 0) + (player:GetBatteryCharge(slot) or 0)
end

local function raw_resource_amounts(player, slot)
	local keys = player:GetNumKeys() or 0
	local bombs = player:GetNumBombs() or 0
	if player:HasGoldenKey() and keys <= 0 then keys = 1 end
	if player:HasGoldenBomb() and bombs <= 0 then bombs = 1 end
	return {
		charge = slot_charge(player, slot),
		coin = player:GetNumCoins() or 0,
		key = keys,
		bomb = bombs,
	}
end

local function observed_amounts(player, slot)
	local amounts = raw_resource_amounts(player, slot)
	for _, kind in ipairs(RESOURCE_ORDER) do
		if is_excluded(player, kind) then amounts[kind] = 0 end
	end
	return amounts
end

local function extra_costs_ok(player)
	if not player then return false end
	if not is_excluded(player, "coin") and (player:GetNumCoins() or 0) < 1 then return false end
	if not is_excluded(player, "key") and (player:GetNumKeys() or 0) < 1 and not player:HasGoldenKey() then return false end
	if not is_excluded(player, "bomb") and (player:GetNumBombs() or 0) < 1 and not player:HasGoldenBomb() then return false end
	return true
end

local function can_pay(player, slot)
	if not player or not slot or slot < 0 then return false end
	if not is_excluded(player, "charge") and slot_charge(player, slot) < 1 then return false end
	return extra_costs_ok(player)
end

local function consume_cost(player, slot)
	if not is_excluded(player, "coin") then player:AddCoins(-1) end
	if not is_excluded(player, "key") then player:AddKeys(-1) end
	if not is_excluded(player, "bomb") then player:AddBombs(-1) end
	if not is_excluded(player, "charge") then
		player:SetActiveCharge(math.max(0, slot_charge(player, slot) - 1), slot)
	end
end

local function pick_max_resource(amounts, rng)
	local max_v = 0
	local cands = {}
	for _, kind in ipairs(RESOURCE_ORDER) do
		local v = amounts[kind] or 0
		if v > max_v then
			max_v = v
			cands = {kind}
		elseif v == max_v and v > 0 then
			cands[#cands + 1] = kind
		end
	end
	if max_v <= 0 or #cands == 0 then return nil end
	if #cands == 1 then return cands[1] end
	rng = auxi.rng_for_sake(rng)
	if not rng then return cands[1] end
	return cands[rng:RandomInt(#cands) + 1]
end

local function play_fail_feedback(player)
	Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, player.Position, Vector(0, 0), player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBS_DOWN, 1, 1, false, 0, 2)
end

local function spawn_fail_drop(player, kind)
	local drop = RESOURCE_DROPS[kind]
	if not drop then
		play_fail_feedback(player)
		return
	end
	local room = Game():GetRoom()
	local pos = room:FindFreePickupSpawnPosition(player.Position, 10, true)
	Isaac.Spawn(EntityType.ENTITY_PICKUP, drop.Variant, drop.SubType, pos, Vector(0, 0), player)
	Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, pos, Vector(0, 0), player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBS_DOWN, 1, 1, false, 0, 2)
end

local function spawn_resource_wisp(player, kind, useFlags)
	if not kind or not auxi.should_spawn_wisp(player, useFlags) then return end
	local wisp_id = RESOURCE_WISPS[kind]
	if not wisp_id then return end
	player:AddWisp(wisp_id, player.Position, true)
end

local function show_exclude_text(kind)
	local pack = is_zh() and EXCLUDE_TEXT.zh or EXCLUDE_TEXT.en
	local hud = Game():GetHUD()
	if hud and hud.ShowItemText then
		hud:ShowItemText(pack.title, pack[kind] or "")
	end
end

local function belial_exclude_one(player, raw, rng)
	if not auxi.should_do_belial(player) then return end
	local bag = exclude_bag(player)
	if not bag then return end
	local cands = {}
	for _, kind in ipairs(RESOURCE_ORDER) do
		if not bag[kind] and (raw[kind] or 0) > 0 then
			cands[#cands + 1] = kind
		end
	end
	if #cands == 0 then return end
	rng = auxi.rng_for_sake(rng)
	local kind = cands[1]
	if rng and #cands > 1 then
		kind = cands[rng:RandomInt(#cands) + 1]
	end
	bag[kind] = true
	show_exclude_text(kind)
end

local function prove(player)
	item.add_proved(player)
	clear_exclude(player)
	player:RemoveCollectible(item.entity)
	player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
	player:EvaluateItems()
	Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 0, player.Position, Vector(0, 0), player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_HOLY, 1, 1, false, 0, 2)
	player:AnimateHappy()
end

if REPENTOGON and ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE, params = item.entity,
	Function = function(_, _, player, _)
		if not extra_costs_ok(player) then return 13 end
		if is_excluded(player, "charge") then return 0 end
		return 1
	end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, _, rng, player, useFlags, activeSlot)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return {Discharge = false, ShowAnim = false}
	end
	if useFlags & UseFlag.USE_VOID == UseFlag.USE_VOID then
		return {Discharge = false, ShowAnim = false}
	end
	local slot = resolve_slot(player, activeSlot)
	if not can_pay(player, slot) then
		play_fail_feedback(player)
		return {Discharge = false, ShowAnim = false}
	end
	consume_cost(player, slot)
	local raw = raw_resource_amounts(player, slot)
	local amounts = observed_amounts(player, slot)
	local all_zero = true
	for _, kind in ipairs(RESOURCE_ORDER) do
		if (amounts[kind] or 0) > 0 then
			all_zero = false
			break
		end
	end
	if all_zero then
		prove(player)
		return {Discharge = false, Remove = false, ShowAnim = false}
	end
	local kind = pick_max_resource(amounts, rng)
	spawn_fail_drop(player, kind)
	spawn_resource_wisp(player, kind, useFlags)
	belial_exclude_one(player, raw, rng)
	return {Discharge = false, Remove = false, ShowAnim = true}
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_, ent)
	if ent.Type ~= 3 or ent.Variant ~= FamiliarVariant.WISP or ent.SubType ~= item.entity then return end
	local drop = RESOURCE_DROPS.charge
	local pos = Game():GetRoom():FindFreePickupSpawnPosition(ent.Position, 10, true)
	Isaac.Spawn(EntityType.ENTITY_PICKUP, drop.Variant, drop.SubType, pos, Vector(0, 0), nil)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	if cacheFlag ~= CacheFlag.CACHE_FAMILIARS then return end
	local cnt = item.get_proved_count(player)
	local cfg = Isaac.GetItemConfig():GetCollectible(item.entity)
	player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), cfg)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_, ent)
	local s = ent:GetSprite()
	s:Play("Idle", true)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_, ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if not d[item.own_key.."IsFollow"] then
		ent:AddToFollowers()
		d[item.own_key.."IsFollow"] = true
	end
	if not s:IsPlaying("Idle") then
		s:Play("Idle", true)
	end
	ent:FollowParent()
end,
})

local function refresh_proved_familiars()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if item.get_proved_count(player) > 0 then
			player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
			player:EvaluateItems()
		end
	end
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."proved"] = {}
		save.elses[item.own_key.."exclude"] = {}
	else
		save.elses[item.own_key.."proved"] = save.elses[item.own_key.."proved"] or {}
		save.elses[item.own_key.."exclude"] = save.elses[item.own_key.."exclude"] or {}
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_PRE_GAME_STARTED, params = nil,
Function = function(_)
	refresh_proved_familiars()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	refresh_proved_familiars()
end,
})

return item

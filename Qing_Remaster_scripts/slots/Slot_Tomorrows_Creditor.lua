local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local every_entity_holder = require("Qing_Remaster_scripts.callbacks.every_entity_holder")
local slot_offer_lift = require("Qing_Remaster_scripts.slots.slot_offer_lift")
local contract_vfx = require("Qing_Remaster_scripts.slots.creditor_contract_vfx")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Slots.Tomorrows_creditor,
	own_key = "Slot_Tomorrows_Creditor_",
	spawn_pct = {12, 10, 6, 0},
}

local PENNY = "gfx/005.021_penny.anm2"
local KEY_ANM = "gfx/005.031_key.anm2"
local BOMB_ANM = "gfx/005.041_bomb.anm2"
local HEART_ANM = "gfx/005.011_heart.anm2"
local SOUL_ANM = "gfx/005.013_heart (soul).anm2"

local function hud_swap(gain, take, anm2, take_anm2)
	return {
		{t = "num", v = "+"..tostring(gain), c = "gain", w = 20},
		{t = "spr", anm2 = anm2, a = 0.9, w = 18},
		{t = "txt", v = "->", c = "arrow", w = 16, scale = 1},
		{t = "num", v = "-"..tostring(take), c = "debt", w = 20},
		{t = "spr", anm2 = take_anm2 or anm2, a = 0.4, w = 18},
	}
end

local CONTRACTS = {
	coin = {
		id = "coin",
		anm2 = PENNY,
		hud_tokens = hud_swap(10, 12, PENNY),
		title_zh = "来日的钱",
		title_en = "Tomorrow's Coins",
		give = function(player) player:AddCoins(10) end,
		debt_key = "coin",
		debt = 12,
		eid_zh = "{{Coin}} 来日的钱#立即获得10¢#之后生成的12¢会被收走",
		eid_en = "{{Coin}} Tomorrow's Coins#Gain 10¢ now#The next 12¢ that spawn are taken",
	},
	key = {
		id = "key",
		anm2 = KEY_ANM,
		hud_tokens = hud_swap(3, 4, KEY_ANM),
		title_zh = "来日的钥匙",
		title_en = "Tomorrow's Keys",
		give = function(player) player:AddKeys(3) end,
		debt_key = "key",
		debt = 4,
		eid_zh = "{{Key}} 来日的钥匙#立即获得3把钥匙#之后生成的4把钥匙会被收走",
		eid_en = "{{Key}} Tomorrow's Keys#Gain 3 keys now#The next 4 keys that spawn are taken",
	},
	bomb = {
		id = "bomb",
		anm2 = BOMB_ANM,
		hud_tokens = hud_swap(3, 4, BOMB_ANM),
		title_zh = "来日的炸弹",
		title_en = "Tomorrow's Bombs",
		give = function(player) player:AddBombs(3) end,
		debt_key = "bomb",
		debt = 4,
		eid_zh = "{{Bomb}} 来日的炸弹#立即获得3个炸弹#之后生成的4个炸弹会被收走",
		eid_en = "{{Bomb}} Tomorrow's Bombs#Gain 3 bombs now#The next 4 bombs that spawn are taken",
	},
	heart = {
		id = "heart",
		anm2 = SOUL_ANM,
		hud_tokens = hud_swap(2, 3, SOUL_ANM, HEART_ANM),
		title_zh = "来日的生命",
		title_en = "Tomorrow's Life",
		give = function(player) player:AddSoulHearts(4) end,
		debt_key = "heart",
		debt = 3,
		eid_zh = "{{SoulHeart}} 来日的生命#立即获得2颗魂心#之后生成的3颗普通心掉落会被收走",
		eid_en = "{{SoulHeart}} Tomorrow's Life#Gain 2 soul hearts now#The next 3 red heart pickups that spawn are taken",
	},
}

local function migrate_debt()
	local old = save.elses["Slot_Time_Beggar_debt"]
	if old and save.elses[item.own_key.."debt"] == nil then
		save.elses[item.own_key.."debt"] = old
		save.elses["Slot_Time_Beggar_debt"] = nil
	end
end

local function debt_bag()
	migrate_debt()
	save.elses[item.own_key.."debt"] = save.elses[item.own_key.."debt"] or {coin = 0, key = 0, bomb = 0, heart = 0}
	return save.elses[item.own_key.."debt"]
end

local function clear_debt()
	save.elses[item.own_key.."debt"] = {coin = 0, key = 0, bomb = 0, heart = 0}
end

local function gain_unit_fn(opt)
	if opt.id == "coin" then return function(p) p:AddCoins(1) end end
	if opt.id == "key" then return function(p) p:AddKeys(1) end end
	if opt.id == "bomb" then return function(p) p:AddBombs(1) end end
	if opt.id == "heart" then return function(p) p:AddSoulHearts(2) end end
end

contract_vfx.setup(debt_bag)

local function slot_busy(ent)
	if not ent or not ent:Exists() then return true end
	local s = ent:GetSprite()
	if s:IsPlaying("Idle") then return false end
	return s:GetAnimation() ~= "Idle"
end

local function roll_contracts(ent)
	local d = ent:GetData()
	if d[item.own_key.."offers"] then return d[item.own_key.."offers"] end
	local rng = auxi.rng_for_sake(ent:GetDropRNG())
	local pool = {"coin", "key", "bomb", "heart"}
	for i = #pool, 2, -1 do
		local j = rng:RandomInt(i) + 1
		pool[i], pool[j] = pool[j], pool[i]
	end
	local offers = {}
	for i = 1, 3 do
		offers[#offers + 1] = CONTRACTS[pool[i]]
	end
	d[item.own_key.."offers"] = offers
	return offers
end

local spec = {
	key = item.own_key,
	variant = item.entity.Variant,
	range = 48,
	can_open = function(ent)
		if slot_busy(ent) then return false end
		return ent:GetData()[item.own_key.."done"] ~= true
	end,
	get_options = function(player, ent)
		return roll_contracts(ent)
	end,
	on_confirm = function(player, ent, opt)
		if not opt then return end
		ent:GetData()[item.own_key.."done"] = true
		ent:GetSprite():Play("PayPrize", true)
		local gain_unit = gain_unit_fn(opt)
		contract_vfx.queue_contract(player, ent, opt,
			function()
				if gain_unit then gain_unit(player) end
			end,
			function()
				local bag = debt_bag()
				bag[opt.debt_key] = (bag[opt.debt_key] or 0) + 1
			end)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SLOTSPAWN, 0.9, 1, false, 0, 1)
		local hud = Game():GetHUD()
		if hud and hud.ShowItemText then
			if slot_offer_lift.lang_zh() then
				hud:ShowItemText(opt.title_zh or "来日债主", "")
			else
				hud:ShowItemText(opt.title_en or "Tomorrow's Creditor", "")
			end
		end
	end,
}

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_SLOT_INIT, params = item.entity.Variant,
Function = function(_, ent)
	local s = ent:GetSprite()
	s.Offset = Vector(0, 5)
	s:Play("Idle", true)
	spec.variant = item.entity.Variant
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_SLOT_COLLISION, params = item.entity.Variant,
Function = function(_, ent, col, low)
	local player = col and col:ToPlayer()
	if not player then return end
	spec.variant = item.entity.Variant
	slot_offer_lift.try_confirm(player, ent, spec)
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_SLOT_UPDATE, params = item.entity.Variant,
Function = function(_, ent)
	local s = ent:GetSprite()
	if s:IsFinished("Teleport") then ent:Remove() return end
	if s:IsFinished("Prize") then
		s:Play("Teleport", true)
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		return
	end
	if s:IsFinished("PayNothing") then s:Play("Idle", true) end
	if s:IsFinished("PayPrize") then s:Play("Prize", true) end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_SLOT_KILL, params = item.entity.Variant,
Function = function(_, ent, killer)
	ent:GetSprite():Play("Teleport", true)
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	Game():GetLevel():SetStateFlag(LevelStateFlag.STATE_BUM_KILLED, true)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	spec.variant = item.entity.Variant
	slot_offer_lift.tick(player, spec)
	if player.Index == 0 then contract_vfx.tick() end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_, ent, hook, button)
	if ent == nil then return end
	local player = ent:ToPlayer()
	if not player then return end
	return slot_offer_lift.block_input(player, item.own_key, hook, button)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_, player, offset)
	spec.variant = item.entity.Variant
	slot_offer_lift.render(player, spec)
	if player and player.Index == 0 then
		contract_vfx.render()
	end
end,
})

local function coin_value(subtype)
	if subtype == CoinSubType.COIN_NICKEL then return 5 end
	if subtype == CoinSubType.COIN_DIME then return 10 end
	if subtype == CoinSubType.COIN_DOUBLEPACK then return 2 end
	if subtype == CoinSubType.COIN_PENNY or subtype == CoinSubType.COIN_LUCKYPENNY then return 1 end
	return nil
end

local function key_value(subtype)
	if subtype == KeySubType.KEY_GOLDEN or subtype == KeySubType.KEY_CHARGED then return nil end
	if subtype == KeySubType.KEY_DOUBLEPACK then return 2 end
	if subtype == KeySubType.KEY_NORMAL then return 1 end
	return nil
end

local function bomb_value(subtype)
	if subtype == BombSubType.BOMB_GOLDEN or subtype == BombSubType.BOMB_GIGA
		or subtype == BombSubType.BOMB_TROLL or subtype == BombSubType.BOMB_SUPERTROLL then
		return nil
	end
	if subtype == BombSubType.BOMB_DOUBLEPACK then return 2 end
	if subtype == BombSubType.BOMB_NORMAL then return 1 end
	return nil
end

local function heart_value(subtype)
	if subtype == HeartSubType.HEART_FULL or subtype == HeartSubType.HEART_SCARED then return 1 end
	if subtype == HeartSubType.HEART_HALF then return 0.5 end
	if subtype == HeartSubType.HEART_DOUBLEPACK then return 2 end
	if subtype == HeartSubType.HEART_BLENDED then return 1 end
	return nil
end

local function should_skip_pickup(ent)
	if not ent then return true end
	if ent:IsShopItem() then return true end
	if (ent.Price or 0) ~= 0 then return true end
	if ent.SpawnerType == EntityType.ENTITY_PLAYER then return true end
	local spawner = ent.SpawnerEntity
	if spawner and spawner:ToPlayer() then return true end
	return false
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = nil,
Function = function(_, ent)
	if should_skip_pickup(ent) then return end
	local bag = debt_bag()
	local vr = ent.Variant
	if vr == PickupVariant.PICKUP_COIN then
		local val = coin_value(ent.SubType)
		if val and (bag.coin or 0) > 0 then
			bag.coin = math.max(0, (bag.coin or 0) - val)
			ent:Remove()
		end
	elseif vr == PickupVariant.PICKUP_KEY then
		local val = key_value(ent.SubType)
		if val and (bag.key or 0) > 0 then
			bag.key = math.max(0, (bag.key or 0) - val)
			ent:Remove()
		end
	elseif vr == PickupVariant.PICKUP_BOMB then
		local val = bomb_value(ent.SubType)
		if val and (bag.bomb or 0) > 0 then
			bag.bomb = math.max(0, (bag.bomb or 0) - val)
			ent:Remove()
		end
	elseif vr == PickupVariant.PICKUP_HEART then
		local val = heart_value(ent.SubType)
		if val and (bag.heart or 0) > 0 then
			bag.heart = math.max(0, (bag.heart or 0) - val)
			ent:Remove()
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		clear_debt()
	else
		migrate_debt()
	end
end,
})

local function chapter_index()
	local stage = Game():GetLevel():GetStage()
	if Game():IsGreedMode() then
		if stage <= 1 then return 1 end
		if stage <= 2 then return 2 end
		if stage <= 3 then return 3 end
		return 4
	end
	if stage <= 2 then return 1 end
	if stage <= 4 then return 2 end
	if stage <= 6 then return 3 end
	return 4
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_SLOT_INIT, params = 4,
Function = function(_, ent)
	local room = Game():GetRoom()
	if ent.FrameCount == 0 and (room:IsFirstVisit() or room:GetFrameCount() ~= 0) then
		local chance = item.spawn_pct[chapter_index()] or 0
		if chance > 0 and ent:GetDropRNG():RandomInt(100) < chance then
			local q = Isaac.Spawn(item.entity.Type, item.entity.Variant, 0, ent.Position, Vector(0, 0), nil)
			every_entity_holder.init_slot(q)
			ent:Remove()
		end
	end
end,
})

local function static_eid()
	if slot_offer_lift.lang_zh() then
		return "从来日预支资源，再用未来偿还"..
			"#靠近后左右切换契约，走进确认"..
			"#按{{ButtonRT}}取消"
	end
	return "Borrow resources from tomorrow and repay them later"..
		"#Switch contracts with left/right, walk in to confirm"..
		"#Press {{ButtonRT}} to cancel"
end

local function option_eid(player, opt)
	if slot_offer_lift.lang_zh() then
		return opt.eid_zh or static_eid()
	end
	return opt.eid_en or static_eid()
end

slot_offer_lift.install_eid("qing_tomorrows_creditor_eid", item.entity.Variant, item.own_key, static_eid, option_eid)

return item

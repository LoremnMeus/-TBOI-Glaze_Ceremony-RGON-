local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Golden_Slot,
	own_key = "Item_Golden_Slot_",
	base_cost = 1,
	belial_cost = 2,
	base_win_chance = 0.10,
	win_chance_per_loss = 0.04,
	max_win_chance = 0.40,
	virtues_wisp_max = 3,
	wisp_midas_chance = 0.12,
	wisp_midas_frames = 90,
	default_reward_weights = {
		midas_fly = 24,
		gold_troll = 15,
		gold_coin = 18,
		gold_heart = 11,
		gold_pill = 8,
		gold_battery = 6,
		gold_bomb = 5,
		gold_key = 5,
		gold_mega_pill = 3,
		gold_trinket = 4,
		ending = 1,
	},
	default_ending_weights = {
		mega_chest = 95,
		trophy = 5,
	},
	reward_tier = {
		midas_fly = 10,
		gold_coin = 20,
		gold_heart = 30,
		gold_pill = 40,
		gold_battery = 50,
		gold_bomb = 60,
		gold_key = 60,
		gold_troll = 70,
		gold_mega_pill = 80,
		gold_trinket = 90,
		ending = 100,
	},
}

local halo_spr = Sprite()
halo_spr:Load("gfx/effects/Halo/Halo_Golden.anm2", true)
halo_spr:Play("Idle", true)
local halo_update_frame = -1

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

local function debug_number(key, default, min_value, max_value)
	local debug = debug_root()
	local value = tonumber(debug and debug[key])
	if value == nil then value = default end
	if min_value then value = math.max(min_value, value) end
	if max_value then value = math.min(max_value, value) end
	return value
end

local function run_bucket()
	save.elses = save.elses or {}
	save.elses[item.own_key.."run"] = save.elses[item.own_key.."run"] or {}
	return save.elses[item.own_key.."run"]
end

function item.get_cost(player)
	if player and auxi.should_do_belial(player) then
		return item.belial_cost
	end
	return item.base_cost
end

function item.get_loss_streak()
	return math.max(0, math.floor(tonumber(run_bucket().loss_streak) or 0))
end

function item.set_loss_streak(value)
	run_bucket().loss_streak = math.max(0, math.floor(tonumber(value) or 0))
end

function item.increase_loss_streak()
	item.set_loss_streak(item.get_loss_streak() + 1)
end

function item.get_win_chance()
	local streak = item.get_loss_streak()
	local base = debug_number("GoldenSlotBaseWinChance", item.base_win_chance * 100, 0, 100) / 100
	local per = debug_number("GoldenSlotWinChancePerLoss", item.win_chance_per_loss * 100, 0, 100) / 100
	local max_chance = debug_number("GoldenSlotMaxWinChance", item.max_win_chance * 100, 0, 100) / 100
	return math.min(base + streak * per, max_chance)
end

local reward_weight_keys = {
	midas_fly = "GoldenSlotRewardWeightMidasFly",
	gold_troll = "GoldenSlotRewardWeightGoldTroll",
	gold_coin = "GoldenSlotRewardWeightGoldCoin",
	gold_heart = "GoldenSlotRewardWeightGoldHeart",
	gold_pill = "GoldenSlotRewardWeightGoldPill",
	gold_battery = "GoldenSlotRewardWeightGoldBattery",
	gold_bomb = "GoldenSlotRewardWeightGoldBomb",
	gold_key = "GoldenSlotRewardWeightGoldKey",
	gold_mega_pill = "GoldenSlotRewardWeightGoldMegaPill",
	gold_trinket = "GoldenSlotRewardWeightGoldTrinket",
	ending = "GoldenSlotRewardWeightEnding",
}

function item.get_reward_weight(key)
	return debug_number(reward_weight_keys[key], item.default_reward_weights[key], 0, 1000)
end

local function has_virtues_book(player)
	return player and player:HasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES)
end

local function is_golden_wisp(ent)
	return ent and ent:GetData() and ent:GetData()[item.own_key.."golden"] == true
end

local function spawn_pos(player)
	return Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 40, true)
end

local function spawn_midas_fly(player)
	local q = Isaac.Spawn(EntityType.ENTITY_ATTACKFLY, 0, 0, spawn_pos(player), Vector(0, 0), player)
	q:AddMidasFreeze(EntityRef(player), 30 * 60 * 10)
end

local function spawn_pickup(variant, subtype, player)
	Isaac.Spawn(EntityType.ENTITY_PICKUP, variant, subtype, spawn_pos(player), Vector(0, 0), player)
end

local function spawn_gold_trinket(player)
	local pool = Game():GetItemPool()
	local id = pool:GetTrinket()
	if not id or id == 0 then id = TrinketType.TRINKET_SWALLOWED_PENNY end
	local golden = id
	if TrinketType.TRINKET_GOLDEN_FLAG then
		golden = id | TrinketType.TRINKET_GOLDEN_FLAG
	end
	spawn_pickup(PickupVariant.PICKUP_TRINKET, golden, player)
end

local function reward_table()
	return {
		{
			key = "midas_fly",
			weigh = function() return item.get_reward_weight("midas_fly") end,
			work = function(player) spawn_midas_fly(player) end,
		},
		{
			key = "gold_troll",
			weigh = function() return item.get_reward_weight("gold_troll") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_BOMB, BombSubType.BOMB_GOLDENTROLL, player)
			end,
		},
		{
			key = "gold_coin",
			weigh = function() return item.get_reward_weight("gold_coin") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_COIN, CoinSubType.COIN_GOLDEN, player)
			end,
		},
		{
			key = "gold_heart",
			weigh = function() return item.get_reward_weight("gold_heart") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_HEART, HeartSubType.HEART_GOLDEN, player)
			end,
		},
		{
			key = "gold_pill",
			weigh = function() return item.get_reward_weight("gold_pill") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_PILL, PillColor.PILL_GOLD, player)
			end,
		},
		{
			key = "gold_battery",
			weigh = function() return item.get_reward_weight("gold_battery") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_GOLDEN, player)
			end,
		},
		{
			key = "gold_bomb",
			weigh = function() return item.get_reward_weight("gold_bomb") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_BOMB, BombSubType.BOMB_GOLDEN, player)
			end,
		},
		{
			key = "gold_key",
			weigh = function() return item.get_reward_weight("gold_key") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_KEY, KeySubType.KEY_GOLDEN, player)
			end,
		},
		{
			key = "gold_mega_pill",
			weigh = function() return item.get_reward_weight("gold_mega_pill") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_PILL, PillColor.PILL_GOLD | PillColor.PILL_GIANT_FLAG, player)
			end,
		},
		{
			key = "gold_trinket",
			weigh = function() return item.get_reward_weight("gold_trinket") end,
			work = function(player)
				spawn_gold_trinket(player)
			end,
		},
		{
			key = "ending",
			weigh = function() return item.get_reward_weight("ending") end,
			work = function(player, rng)
				local mega = debug_number("GoldenSlotEndingMegaWeight", item.default_ending_weights.mega_chest, 0, 1000)
				local trophy = debug_number("GoldenSlotEndingTrophyWeight", item.default_ending_weights.trophy, 0, 1000)
				local pick = auxi.random_in_weighed_table({
					{weigh = mega, info = "mega"},
					{weigh = trophy, info = "trophy"},
				}, rng)
				if pick and pick.info == "trophy" then
					spawn_pickup(PickupVariant.PICKUP_TROPHY, 0, player)
				else
					spawn_pickup(PickupVariant.PICKUP_MEGACHEST, 0, player)
				end
			end,
		},
	}
end

local function pick_reward(rng)
	local candidates = {}
	for _, v in ipairs(reward_table()) do
		local w = v.weigh()
		if w and w > 0 then
			table.insert(candidates, #candidates + 1, {weigh = w, info = v})
		end
	end
	local pick = auxi.random_in_weighed_table(candidates, rng)
	return pick and pick.info or nil
end

local function reward_tier_value(key)
	return item.reward_tier[key or ""] or 0
end

local function apply_reward(info, player, rng)
	if not info or not info.work then return end
	auxi.check_if_any(info.work, player, rng, info, item)
end

local function grant_win_reward(player, rng)
	if auxi.should_do_belial(player) then
		local a = pick_reward(rng)
		local b = pick_reward(rng)
		local chosen = a
		if b and reward_tier_value(b.key) > reward_tier_value(a and a.key) then
			chosen = b
		end
		apply_reward(chosen, player, rng)
		return
	end
	apply_reward(pick_reward(rng), player, rng)
end

local function clear_golden_wisps(player)
	local wisps = auxi.get_wisps(player, item.entity) or {}
	for i = 1, #wisps do
		if wisps[i] and is_golden_wisp(wisps[i]) then
			wisps[i]:Remove()
		end
	end
end

local function sync_golden_wisp_visual(wisp, heat)
	if not wisp or not wisp:Exists() then return end
	heat = math.max(1, math.floor(tonumber(heat) or 1))
	local scale = 0.82 + math.min(heat, 8) * 0.075
	wisp.SpriteScale = Vector(scale, scale)
	local bright = 0.72 + math.min(heat, 8) * 0.05
	wisp:SetColor(Color(1, bright, bright * 0.42, 1, 0, 0, 0), -1, 0, false, false)
end

function item.sync_golden_wisps(player)
	local heat = item.get_loss_streak()
	local wisps = auxi.get_wisps(player, item.entity) or {}
	for i = 1, #wisps do
		if wisps[i] and is_golden_wisp(wisps[i]) then
			sync_golden_wisp_visual(wisps[i], heat)
		end
	end
end

local function spawn_virtues_wisp(player)
	if not has_virtues_book(player) then return end
	local wisps = auxi.get_wisps(player, item.entity) or {}
	local golden = {}
	for i = 1, #wisps do
		if wisps[i] and is_golden_wisp(wisps[i]) then
			golden[#golden + 1] = wisps[i]
		end
	end
	while #golden >= item.virtues_wisp_max do
		if golden[1] then golden[1]:Remove() end
		table.remove(golden, 1)
	end
	local wisp = player:AddWisp(item.entity, player.Position, true, false)
	if not wisp then return end
	wisp:GetData()[item.own_key.."golden"] = true
	sync_golden_wisp_visual(wisp, item.get_loss_streak())
	item.sync_golden_wisps(player)
end

local function try_midas_from_golden_wisp(source, target, rng)
	if not source or not target or not auxi.isenemies(target) then return end
	if not is_golden_wisp(source) then return end
	if rng:RandomFloat() >= item.wisp_midas_chance then return end
	local owner = source.Player or auxi.check_spawner_player(source)
	target:AddMidasFreeze(EntityRef(owner or source), item.wisp_midas_frames)
end

local function ensure_halo_updated()
	local frame = Game():GetFrameCount()
	if halo_update_frame == frame then return end
	halo_update_frame = frame
	halo_spr:Update()
end

local function halo_heat_alpha(loss_streak)
	if loss_streak < 1 then return 0 end
	return math.min(1, loss_streak / 8)
end

local function render_halo_behind(center, scale, hud_alpha, loss_streak)
	local heat = halo_heat_alpha(loss_streak)
	if heat < 0.02 then return end
	ensure_halo_updated()
	local frame = Game():GetFrameCount()
	local pulse = 0.5 + 0.5 * math.sin(frame * 0.28)
	local col = Color(1, 1, 1, hud_alpha * heat * (0.35 + 0.45 * pulse), 0, 0, 0)
	if col.SetColorize then
		col:SetColorize(1.12 + 0.18 * pulse, 0.86 + 0.1 * pulse, 0.05, 1)
	end
	halo_spr.Color = col
	halo_spr.Scale = Vector(scale * (0.9 + 0.18 * heat), scale * (0.9 + 0.18 * heat))
	halo_spr:Render(center, Vector.Zero, Vector.Zero)
	halo_spr.Scale = Vector(1, 1)
	halo_spr.Color = Color(1, 1, 1, 1)
end

local function hud_icon_offset(loss_streak)
	if loss_streak < 4 then return Vector.Zero end
	local tier = (loss_streak >= 8) and 4 or (loss_streak >= 6) and 3 or 2
	local frame = Game():GetFrameCount()
	local amp = (tier == 2) and 0.35 or (tier == 3) and 0.75 or 1.15
	return Vector(math.sin(frame * 0.95) * amp, math.cos(frame * 1.07) * amp)
end

local function render_active_icon(player, slot, cid)
	local info = ui.GetActiveSlotRenderInfo(player, slot)
	local scale = (info and tonumber(info.scale)) or 1
	local hud_alpha = (info and tonumber(info.alpha)) or 1
	local streak = item.get_loss_streak()
	local offset = hud_icon_offset(streak)
	local halo_center = ui.PlayerActiveUIPos(player, slot, auxi.GetPlayerOrder(player), cid) + offset
	render_halo_behind(halo_center, scale, hud_alpha, streak)
	local sprite = auxi.load_item(cid)
	sprite.Scale = Vector(scale, scale)
	sprite.Color = Color(1, 1, 1, hud_alpha)
	local pos = ui.ActiveSlotSpriteRenderPos(player, slot, sprite, 0) + offset
	sprite:Render(pos, Vector.Zero, Vector.Zero)
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, collItem, rng, player, useFlags)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return {Discharge = false, ShowAnim = false}
	end
	local cost = item.get_cost(player)
	if player:GetNumCoins() < cost then
		player:AnimateSad()
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 1, 1, false, 0, 2)
		return {Discharge = false, ShowAnim = false}
	end

	player:AddCoins(-cost)

	if rng:RandomFloat() < item.get_win_chance() then
		item.set_loss_streak(0)
		clear_golden_wisps(player)
		grant_win_reward(player, rng)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SLOTSPAWN, 1, 1, false, 0, 2)
		return {Discharge = false, ShowAnim = true}
	end

	item.increase_loss_streak()
	spawn_virtues_wisp(player)
	player:AnimateSad()
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_COIN_INSERT, 0.6, 1, false, 0, 2)
	return {Discharge = false, ShowAnim = true}
end,
})

if ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM, params = item.entity,
	Function = function(_, player, slot)
		if player:GetActiveItem(slot) ~= item.entity then return end
		return {HideItem = true}
	end,
	})
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_, player, tp, cid, slot)
	if cid ~= item.entity then return end
	render_active_icon(player, slot, cid)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = FamiliarVariant.WISP,
Function = function(_, ent, col, low)
	if ent.SubType ~= item.entity or not is_golden_wisp(ent) then return end
	try_midas_from_golden_wisp(ent, col, ent:GetDropRNG())
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_, tear, col, low)
	local spawner = tear.SpawnerEntity
	if not spawner or spawner.Type ~= EntityType.ENTITY_FAMILIAR or spawner.Variant ~= FamiliarVariant.WISP then return end
	if spawner.SubType ~= item.entity or not is_golden_wisp(spawner) then return end
	try_midas_from_golden_wisp(spawner, col, spawner:GetDropRNG())
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if continue then return end
	item.set_loss_streak(0)
end,
})

return item

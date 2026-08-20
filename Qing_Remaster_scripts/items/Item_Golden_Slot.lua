local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Golden_Slot,
	own_key = "Item_Golden_Slot_",
	base_cost = 1,
	-- Active UI 硬币 icon（相对数字右缘的 X；相对 Active 槽位的 Y；Scale）
	coin_offset_x = 4.5,
	coin_offset_y = -6.25,
	coin_scale = 0.5,
	default_weights = {
		midas_fly = 20,
		gold_troll = 10,
		gold_coin = 32,
		gold_bomb = 36,
		gold_heart = 26,
		gold_key = 28,
		gold_battery = 18,
		gold_pill = 18,
		gold_mega_pill = 10,
		gold_trinket = 14,
		ending = 1,
	},
}

local cost_font = Font()
cost_font:Load("font/luaminioutlined.fnt")

-- luamini 无 ¢ 字形；改用硬币 icon + 数字
local coin_sprite = Sprite()
local coin_sprite_ready = false
local function ensure_coin_sprite()
	if coin_sprite_ready then return true end
	coin_sprite:Load("gfx/005.021_penny.anm2", true)
	coin_sprite:Play("Idle", true)
	coin_sprite:SetFrame(0)
	coin_sprite_ready = true
	return true
end

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

function item.get_cost()
	local bucket = run_bucket()
	return math.max(1, math.floor(tonumber(bucket.cost) or item.base_cost))
end

function item.set_cost(value)
	local cost = math.max(1, math.floor(tonumber(value) or item.base_cost))
	run_bucket().cost = cost
	local debug = debug_root()
	if debug then debug.GoldenSlotCost = cost end
end

function item.increase_cost()
	item.set_cost(item.get_cost() + 1)
end

function item.get_weight(key)
	local map = {
		midas_fly = "GoldenSlotWeightMidasFly",
		gold_troll = "GoldenSlotWeightGoldTroll",
		gold_coin = "GoldenSlotWeightGoldCoin",
		gold_bomb = "GoldenSlotWeightGoldBomb",
		gold_heart = "GoldenSlotWeightGoldHeart",
		gold_key = "GoldenSlotWeightGoldKey",
		gold_battery = "GoldenSlotWeightGoldBattery",
		gold_pill = "GoldenSlotWeightGoldPill",
		gold_mega_pill = "GoldenSlotWeightGoldMegaPill",
		gold_trinket = "GoldenSlotWeightGoldTrinket",
		ending = "GoldenSlotWeightEnding",
	}
	return debug_number(map[key], item.default_weights[key], 0, 1000)
end

local function spawn_pos(player)
	return Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 40, true)
end

local function spawn_midas_fly(player)
	local q = Isaac.Spawn(EntityType.ENTITY_ATTACKFLY, 0, 0, spawn_pos(player), Vector(0, 0), player)
	q:AddMidasFreeze(EntityRef(player), 30 * 60 * 10)
	return true
end

local function spawn_pickup(variant, subtype, player)
	Isaac.Spawn(EntityType.ENTITY_PICKUP, variant, subtype, spawn_pos(player), Vector(0, 0), player)
end

local function spawn_gold_trinket(player, rng)
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
			weigh = function() return item.get_weight("midas_fly") end,
			sad = true,
			work = function(player) spawn_midas_fly(player) end,
		},
		{
			key = "gold_troll",
			weigh = function() return item.get_weight("gold_troll") end,
			sad = true,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_BOMB, BombSubType.BOMB_GOLDENTROLL, player)
			end,
		},
		{
			key = "gold_coin",
			weigh = function() return item.get_weight("gold_coin") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_COIN, CoinSubType.COIN_GOLDEN, player)
			end,
		},
		{
			key = "gold_bomb",
			weigh = function() return item.get_weight("gold_bomb") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_BOMB, BombSubType.BOMB_GOLDEN, player)
			end,
		},
		{
			key = "gold_heart",
			weigh = function() return item.get_weight("gold_heart") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_HEART, HeartSubType.HEART_GOLDEN, player)
			end,
		},
		{
			key = "gold_key",
			weigh = function() return item.get_weight("gold_key") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_KEY, KeySubType.KEY_GOLDEN, player)
			end,
		},
		{
			key = "gold_battery",
			weigh = function() return item.get_weight("gold_battery") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_GOLDEN, player)
			end,
		},
		{
			key = "gold_pill",
			weigh = function() return item.get_weight("gold_pill") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_PILL, PillColor.PILL_GOLD, player)
			end,
		},
		{
			key = "gold_mega_pill",
			weigh = function() return item.get_weight("gold_mega_pill") end,
			work = function(player)
				spawn_pickup(PickupVariant.PICKUP_PILL, PillColor.PILL_GOLD | PillColor.PILL_GIANT_FLAG, player)
			end,
		},
		{
			key = "gold_trinket",
			weigh = function() return item.get_weight("gold_trinket") end,
			work = function(player, rng)
				spawn_gold_trinket(player, rng)
			end,
		},
		{
			key = "ending",
			weigh = function() return item.get_weight("ending") end,
			work = function(player, rng)
				if rng:RandomFloat() < 0.5 then
					spawn_pickup(PickupVariant.PICKUP_TROPHY, 0, player)
				else
					spawn_pickup(PickupVariant.PICKUP_MEGACHEST, 0, player)
				end
			end,
		},
	}
end

local function roll_reward(player, rng)
	local candidates = {}
	for _, v in ipairs(reward_table()) do
		local w = v.weigh()
		if w and w > 0 then
			table.insert(candidates, #candidates + 1, {weigh = w, info = v})
		end
	end
	local pick = auxi.random_in_weighed_table(candidates, rng)
	if not pick then return nil end
	auxi.check_if_any(pick.info.work, player, rng, pick.info, item)
	return pick.info
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,collItem,rng,player,useFlags)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return {Discharge = false, ShowAnim = false}
	end
	local cost = item.get_cost()
	if player:GetNumCoins() < cost then
		player:AnimateSad()
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 1, 1, false, 0, 2)
		return {Discharge = false, ShowAnim = false}
	end

	player:AddCoins(-cost)
	item.increase_cost()

	local reward = roll_reward(player, rng)
	if reward and reward.sad then
		player:AnimateSad()
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBS_DOWN, 1, 1, false, 0, 2)
		return {Discharge = false, ShowAnim = false}
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SLOTSPAWN, 1, 1, false, 0, 2)
	return {Discharge = false, ShowAnim = true}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_,player,tp,cid,slot)
	if cid ~= item.entity then return end
	local pos = ui.PlayerActiveUIPos(player, slot, auxi.GetPlayerOrder(player), cid)
	local alpha = slot_render_holder.get_alpha()
	local col = Color(1, 0.85, 0.2, alpha)
	local str = "-"..tostring(item.get_cost())
	local text_pos = Vector(-18, -16)
	gui.draw_ch(pos + text_pos, str, 1, 1, auxi.Color_2_KColor(col), true, cost_font)
	if ensure_coin_sprite() then
		local coin_ox = debug_number("GoldenSlotCoinOffsetX", item.coin_offset_x, -64, 64)
		local coin_oy = debug_number("GoldenSlotCoinOffsetY", item.coin_offset_y, -64, 64)
		local coin_sc = debug_number("GoldenSlotCoinScale", item.coin_scale, 0.05, 2)
		coin_sprite.Color = Color(1, 0.9, 0.35, alpha, 0, 0, 0)
		coin_sprite.Scale = Vector(coin_sc, coin_sc)
		coin_sprite:SetFrame(0)
		-- 数字右侧画一枚硬币；X = 数字右缘 + OffsetX，Y = Active 槽位 + OffsetY
		local text_w = cost_font:GetStringWidthUTF8(str) * 1
		coin_sprite:Render(pos + Vector(text_pos.X + text_w + coin_ox, coin_oy), Vector.Zero, Vector.Zero)
	end
end,
})

local function eid_lang_is_zh()
	local lang = Options.Language
	if EID and EID.UserConfig and EID.UserConfig.Language and EID.UserConfig.Language ~= "auto" then
		lang = EID.UserConfig.Language
	end
	return lang == "zh" or lang == "zh_cn"
end

if EID then
	EID:addDescriptionModifier("qing_golden_slot_eid", function(desc)
		return desc.ObjType == 5 and desc.ObjVariant == 100 and desc.ObjSubType == item.entity
	end, function(desc)
		local text
		if eid_lang_is_zh() then
			text = "{{Coin}} 消耗金币抽奖"..
				"#生成金色奖励"..
				"#极小概率生成金奖杯或超大金箱"
		else
			text = "{{Coin}} Spend coins to gamble"..
				"#Spawn golden rewards"..
				"#Tiny chance for a golden trophy or mega chest"
		end
		desc.Description = text
		return desc
	end)
end

return item

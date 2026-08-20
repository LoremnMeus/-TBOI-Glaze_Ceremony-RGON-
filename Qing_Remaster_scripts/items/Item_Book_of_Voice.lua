local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local Book_of_Belial_holder = require("Qing_Remaster_scripts.mimics.Book_of_Belial_holder")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Book_of_Voice,
	voice_entity = enums.Items.The_Voice,
	own_key = "Item_Book_of_Voice_",
	panel = nil,
	suppress_open_until = -1,
	dir_time_limit = 20,
	button_list = {0, 1, 2, 3, 4, 5, 6, 7, 9, 11},
}

auxi.add_to_seija(item.entity)
if item.voice_entity and item.voice_entity > 0 then
	auxi.add_to_seija(item.voice_entity)
end

local SAVE_KEY = item.own_key.."state"
local BASE_MAX_CHARGE = 6
local RELEASE_POSSESSION = 9
local BOUNCE_FRAMES = 24
local VOICE_GFX = "gfx/items/collectibles/collectibles_The_Voice.png"
local selection_key = "BookOfVoice"

local SHOP_SLOT_VARIANTS = {
	[SlotVariant and SlotVariant.DONATION_MACHINE or 8] = true,
	[SlotVariant and SlotVariant.SHOP_RESTOCK_MACHINE or 10] = true,
	[SlotVariant and SlotVariant.GREED_DONATION_MACHINE or 11] = true,
}

local blocked_actions = {
	[ButtonAction.ACTION_LEFT] = true,
	[ButtonAction.ACTION_RIGHT] = true,
	[ButtonAction.ACTION_UP] = true,
	[ButtonAction.ACTION_DOWN] = true,
	[ButtonAction.ACTION_SHOOTLEFT] = true,
	[ButtonAction.ACTION_SHOOTRIGHT] = true,
	[ButtonAction.ACTION_SHOOTUP] = true,
	[ButtonAction.ACTION_SHOOTDOWN] = true,
	[ButtonAction.ACTION_DROP] = true,
	[ButtonAction.ACTION_ITEM] = true,
	[ButtonAction.ACTION_MENUCONFIRM] = true,
}

local RED_HEARTS = {
	[HeartSubType.HEART_FULL] = true,
	[HeartSubType.HEART_HALF] = true,
	[HeartSubType.HEART_DOUBLEPACK] = true,
	[HeartSubType.HEART_SCARED] = true,
	[HeartSubType.HEART_BLENDED] = true,
}

local CHEST_VARIANTS = {
	[PickupVariant.PICKUP_CHEST] = true,
	[PickupVariant.PICKUP_BOMBCHEST] = true,
	[PickupVariant.PICKUP_SPIKEDCHEST] = true,
	[PickupVariant.PICKUP_ETERNALCHEST] = true,
	[PickupVariant.PICKUP_MIMICCHEST] = true,
	[PickupVariant.PICKUP_OLDCHEST] = true,
	[PickupVariant.PICKUP_WOODENCHEST] = true,
	[PickupVariant.PICKUP_MEGACHEST] = true,
	[PickupVariant.PICKUP_HAUNTEDCHEST] = true,
	[PickupVariant.PICKUP_LOCKEDCHEST] = true,
	[PickupVariant.PICKUP_REDCHEST] = true,
}

local REJECT_TEXT = {
	zh = {
		{title = "假象之书", line = "……"},
		{title = "假象之书", line = "你开始不相信我了。"},
		{title = "假象之书", line = "没关系。"},
		{title = "假象之书", line = "我会等。"},
	},
	en = {
		{title = "Book of Voice", line = "..."},
		{title = "Book of Voice", line = "You are starting to doubt me."},
		{title = "Book of Voice", line = "It's fine."},
		{title = "Book of Voice", line = "I can wait."},
	},
}

local SEIJA_REJECT_TEXT = {
	zh = {
		{title = "假象之书", line = "……有趣。"},
		{title = "假象之书", line = "你以为这是反抗？"},
	},
	en = {
		{title = "Book of Voice", line = "...Interesting."},
		{title = "Book of Voice", line = "You call this defiance?"},
	},
}

local PHASE_TITLE = {
	zh = {
		BOOK_EARLY = "假象之书",
		BOOK_MID = "假象之书",
		BOOK_LATE = "假象之书",
		RELEASE_READY = "快",
		VOICE = "声音",
	},
	en = {
		BOOK_EARLY = "Book of Voice",
		BOOK_MID = "Book of Voice",
		BOOK_LATE = "Book of Voice",
		RELEASE_READY = "Quickly",
		VOICE = "The Voice",
	},
}

local function is_zh()
	local lang = Options.Language
	return lang == "zh" or lang == "zh_cn"
end

local function lang_pack()
	return is_zh() and "zh" or "en"
end

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

function item.force_seija()
	local debug = debug_root()
	return debug and debug.VoiceForceSeijaDefy == true
end

local function is_seija(player)
	if item.force_seija() then return true end
	return auxi.should_do_Seija(player, true)
end

local function player_idx(player)
	return player and player:GetData() and player:GetData().__Index
end

local function empty_bag()
	return {
		Possession = 0,
		Phase = "BOOK_EARLY",
		Released = false,
		Current = nil,
		Cooldown = 0,
		Completed = 0,
		Rejected = 0,
		Serial = 0,
		DamageMul = 1,
		BounceUntil = 0,
		TempBook = false,
		GivingTemp = false,
		Stash = nil,
	}
end

local function bag_of(player)
	local idx = player_idx(player)
	if idx == nil then return nil end
	save.elses[SAVE_KEY] = save.elses[SAVE_KEY] or {}
	local bag = save.elses[SAVE_KEY][idx]
	if type(bag) ~= "table" then
		bag = empty_bag()
		save.elses[SAVE_KEY][idx] = bag
	end
	if item.voice_entity and item.voice_entity > 0 and player:HasCollectible(item.voice_entity) then
		bag.Released = true
		bag.Phase = "VOICE"
	end
	return bag
end

local function refresh_phase(bag)
	if bag.Released then
		bag.Phase = "VOICE"
		return
	end
	local p = bag.Possession or 0
	if p >= RELEASE_POSSESSION then bag.Phase = "RELEASE_READY"
	elseif p >= 6 then bag.Phase = "BOOK_LATE"
	elseif p >= 3 then bag.Phase = "BOOK_MID"
	else bag.Phase = "BOOK_EARLY"
	end
end

local function max_charge_of(bag)
	if not bag or bag.Released then return BASE_MAX_CHARGE end
	local p = bag.Possession or 0
	return math.max(1, BASE_MAX_CHARGE - math.floor(p / 2))
end

local function held_collectible(player)
	local bag = bag_of(player)
	if bag and (bag.Released or bag.TempBook) and item.voice_entity and item.voice_entity > 0 then
		return item.voice_entity
	end
	return item.entity
end

function item.is_answer_use(player)
	local bag = bag_of(player)
	if not bag then return false end
	return bag.Current ~= nil or bag.TempBook == true
end

local function clamp_book_charge(player, bag)
	if not player or not bag or bag.Released then return end
	local maxc = max_charge_of(bag)
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		if player:GetActiveItem(slot) == item.entity then
			local cur = (player:GetActiveCharge(slot) or 0) + (player:GetBatteryCharge(slot) or 0)
			if cur > maxc then
				player:SetActiveCharge(maxc, slot)
			end
		end
	end
end

local function has_voice(player, bag)
	if bag and bag.Released then return true end
	if player and item.voice_entity and player:HasCollectible(item.voice_entity) then return true end
	return player and player:HasCollectible(item.entity)
end

local function has_virtue_wisp(player)
	local wisps = auxi.get_wisps(player, item.entity)
	return wisps and #wisps > 0
end

local function room_seed()
	return Game():GetLevel():GetCurrentRoomDesc().SpawnSeed
end

local function free_pos(player)
	return Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 40, true)
end

local function speak(player, title, line)
	item_displaying_holder.check_and_description("ItemDesc", item.entity, title or "", line or "", player)
end

local function whisper_rng(player, bag)
	bag.Serial = (bag.Serial or 0) + 1
	local rng = player:GetCollectibleRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	if rng then rng:Next() end
	return rng
end

local function pick_text(list)
	if not list or #list == 0 then return nil end
	return list[(Game():GetFrameCount() % #list) + 1]
end

local function spawn_pickup(player, variant, subtype)
	local q = Isaac.Spawn(EntityType.ENTITY_PICKUP, variant, subtype or 0, free_pos(player), Vector(0, 0), player):ToPickup()
	if q then q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE) end
	return q
end

local function spawn_choice_items(player, count, min_quality, devil)
	local rng = player:GetCollectibleRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	if not rng then return end
	local pool = devil and ItemPoolType.POOL_DEVIL or Game():GetItemPool():GetPoolForRoom(Game():GetRoom():GetType(), room_seed())
	if not pool or pool < 0 then pool = ItemPoolType.POOL_TREASURE end
	local ndx = option_index_holder.find_a_new_index()
	local room = Game():GetRoom()
	min_quality = min_quality or 0
	for _ = 1, count do
		local colid = CollectibleType.COLLECTIBLE_BREAKFAST
		for _ = 1, 8 do
			local seed = rng:Next()
			if seed == 0 then seed = 1 end
			colid = Game():GetItemPool():GetCollectible(pool, true, seed)
			local cfg = Isaac.GetItemConfig():GetCollectible(colid)
			if cfg and (cfg.Quality or 0) >= min_quality then break end
		end
		local q = Isaac.Spawn(5, 100, colid, room:FindFreePickupSpawnPosition(player.Position, 40, true), Vector(0, 0), nil):ToPickup()
		if q then
			q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
			q.OptionsPickupIndex = ndx
		end
	end
end

local function collect_room_pickups(variant_pred, subtype_pred, shop_mode)
	local ret = {}
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, false, false)) do
		local pickup = ent:ToPickup()
		if pickup then
			local shop = pickup:IsShopItem()
			if shop_mode == "shop" and not shop then
			elseif shop_mode ~= "shop" and shop then
			else
				local ok = true
				if variant_pred and not variant_pred(pickup.Variant) then ok = false end
				if ok and subtype_pred and not subtype_pred(pickup.SubType) then ok = false end
				if ok then ret[#ret + 1] = pickup end
			end
		end
	end
	return ret
end

local function poof_at(pos)
	Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, pos, Vector(0, 0), nil)
end

local function remove_pickups(list)
	for i = 1, #(list or {}) do
		local pickup = list[i]
		if pickup and pickup:Exists() then
			poof_at(pickup.Position)
			if pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE and pickup.TryRemoveCollectible then
				if not pickup:TryRemoveCollectible() then
					pickup:Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, 0, true, true, true)
				end
			else
				pickup:Remove()
			end
		end
	end
end

local function remove_shop_presence()
	Game():Darken(1, 12)
	remove_pickups(collect_room_pickups(nil, nil, "shop"))
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, -1, -1, false, false)) do
		if SHOP_SLOT_VARIANTS[ent.Variant] then
			poof_at(ent.Position)
			ent:Remove()
		end
	end
end

local function same_panel_player(player)
	return item.panel and item.panel.player and player
		and player_idx(item.panel.player) == player_idx(player)
end

local function close_panel_lua()
	item.panel = nil
	item.suppress_open_until = Game():GetFrameCount() + 2
end

local function close_panel()
	if not item.panel then return end
	local player = item.panel.player
	if player then
		selection_holder.remove_select(player, selection_key)
		if player:Exists() and player:IsHoldingItem() then
			player:AnimateCollectible(held_collectible(player), "HideItem", "PlayerPickup")
		end
	end
	close_panel_lua()
end

local restore_temp_book

local function finish_whisper(player, bag)
	bag.Current = nil
	bag.BounceUntil = 0
	bag.Cooldown = bag.Phase == "VOICE" and 45 or (bag.Phase == "BOOK_EARLY" and 150 or 100)
	restore_temp_book(player, bag)
end

local function ensure_temp_book(player, bag)
	if not bag or not bag.Released or not player then return end
	if player:HasCollectible(item.entity) then return end
	local primary = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) or 0
	if primary == item.entity then return end
	bag.GivingTemp = true
	if primary > 0 then
		bag.Stash = {
			id = primary,
			charge = (player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY) or 0) + (player:GetBatteryCharge(ActiveSlot.SLOT_PRIMARY) or 0),
		}
		player:RemoveCollectible(primary, true, ActiveSlot.SLOT_PRIMARY, true)
	else
		bag.Stash = {id = 0, charge = 0}
	end
	player:AddCollectible(item.entity, 0, false, ActiveSlot.SLOT_PRIMARY)
	bag.GivingTemp = false
	bag.TempBook = true
end

restore_temp_book = function(player, bag)
	if not bag or not bag.TempBook or not player then
		if bag then bag.TempBook = false bag.Stash = nil bag.GivingTemp = false end
		return
	end
	bag.GivingTemp = true
	if player:HasCollectible(item.entity) then
		player:RemoveCollectible(item.entity, true, ActiveSlot.SLOT_PRIMARY, true)
	end
	local stash = bag.Stash
	if stash and stash.id and stash.id > 0 then
		player:AddCollectible(stash.id, stash.charge or 0, false, ActiveSlot.SLOT_PRIMARY)
	end
	bag.GivingTemp = false
	bag.TempBook = false
	bag.Stash = nil
end

local function convert_book_to_voice(player, bag)
	if not player or not bag or bag.GivingTemp then return end
	if not bag.Released then return end
	while player:HasCollectible(item.entity) do
		player:RemoveCollectible(item.entity)
	end
	if item.voice_entity and item.voice_entity > 0 and not player:HasCollectible(item.voice_entity) then
		player:AddCollectible(item.voice_entity)
	end
end

local WHISPERS = {}
local WHISPER_BY_ID = {}

local function add_whisper(row)
	WHISPERS[#WHISPERS + 1] = row
	WHISPER_BY_ID[row.ID] = row
end

add_whisper({
	ID = "SPEND_COINS",
	Tier = 1,
	Weight = 12,
	Highlight = "coin",
	CanStart = function(player, _, inst)
		local need = (inst and inst.Doubled) and 10 or 5
		if inst and inst.Softened then need = 3 end
		return (player:GetNumCoins() or 0) >= need
	end,
	Pay = function(player, _, inst)
		if inst.Softened then player:AddCoins(-3)
		else player:AddCoins(inst.Doubled and -10 or -5) end
	end,
	Reward = function(player, _, inst)
		spawn_pickup(player, inst.Doubled and PickupVariant.PICKUP_REDCHEST or PickupVariant.PICKUP_CHEST, 0)
		if inst.Doubled then
			Book_of_Belial_holder.Add_dmg(player, 1.5, {counter = 300})
		end
	end,
	Text = {
		zh = {voice = "一点零钱就够了。", req = "交出5硬币", reward = "生成箱子"},
		en = {voice = "A few coins will do.", req = "Give 5 coins", reward = "Spawn a chest"},
	},
	DoubleText = {
		zh = {req = "交出10硬币", reward = "红箱子，并暂时提升攻击"},
		en = {req = "Give 10 coins", reward = "Red chest and a brief damage boost"},
	},
	SoftText = {
		zh = {req = "交出3硬币", reward = "生成箱子"},
		en = {req = "Give 3 coins", reward = "Spawn a chest"},
	},
})

add_whisper({
	ID = "DISCARD_CARD",
	Tier = 1,
	Weight = 8,
	Highlight = "card",
	CanStart = function(player)
		return player:GetCard(0) > 0 or player:GetPill(0) > 0
	end,
	Pay = function(player)
		if player:GetCard(0) > 0 then player:SetCard(0, 0)
		elseif player:GetPill(0) > 0 then player:SetPill(0, 0)
		end
	end,
	Reward = function(player, _, inst)
		spawn_pickup(player, PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL)
		if inst.Doubled then
			spawn_pickup(player, PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL)
		end
	end,
	Text = {
		zh = {voice = "那张纸没有用。", req = "丢弃一张卡牌或药丸", reward = "生成魂心"},
		en = {voice = "That scrap is useless.", req = "Discard a card or pill", reward = "Spawn a soul heart"},
	},
})

add_whisper({
	ID = "SPEND_KEY",
	Tier = 1,
	Weight = 8,
	Highlight = "key",
	CanStart = function(player, _, inst)
		local need = (inst and inst.Doubled) and 2 or 1
		return (player:GetNumKeys() or 0) >= need or player:HasGoldenKey()
	end,
	Pay = function(player, _, inst)
		player:AddKeys(inst.Doubled and -2 or -1)
	end,
	Reward = function(player, _, inst)
		spawn_pickup(player, PickupVariant.PICKUP_BOMB, 0)
		spawn_pickup(player, PickupVariant.PICKUP_BOMB, 0)
		if inst.Doubled then spawn_pickup(player, PickupVariant.PICKUP_CHEST, 0) end
	end,
	Text = {
		zh = {voice = "钥匙会生锈的。", req = "交出1钥匙", reward = "生成2炸弹"},
		en = {voice = "Keys rust anyway.", req = "Give 1 key", reward = "Spawn 2 bombs"},
	},
})

add_whisper({
	ID = "SPEND_BOMB",
	Tier = 1,
	Weight = 8,
	Highlight = "bomb",
	CanStart = function(player, _, inst)
		local need = (inst and inst.Doubled) and 2 or 1
		return (player:GetNumBombs() or 0) >= need or player:HasGoldenBomb()
	end,
	Pay = function(player, _, inst)
		player:AddBombs(inst.Doubled and -2 or -1)
	end,
	Reward = function(player, _, inst)
		spawn_pickup(player, PickupVariant.PICKUP_KEY, 0)
		spawn_pickup(player, PickupVariant.PICKUP_KEY, 0)
		if inst.Doubled then spawn_pickup(player, PickupVariant.PICKUP_LOCKEDCHEST, 0) end
	end,
	Text = {
		zh = {voice = "爆炸太吵了。", req = "交出1炸弹", reward = "生成2钥匙"},
		en = {voice = "Explosions are noisy.", req = "Give 1 bomb", reward = "Spawn 2 keys"},
	},
})

add_whisper({
	ID = "NO_RED_HEART",
	Tier = 1,
	Weight = 10,
	Highlight = "red_heart",
	CanStart = function()
		return #collect_room_pickups(function(v) return v == PickupVariant.PICKUP_HEART end, function(st) return RED_HEARTS[st] end) > 0
	end,
	Pay = function()
		remove_pickups(collect_room_pickups(function(v) return v == PickupVariant.PICKUP_HEART end, function(st) return RED_HEARTS[st] end))
	end,
	Reward = function(player, _, inst)
		spawn_pickup(player, PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL)
		if inst.Doubled then
			spawn_pickup(player, PickupVariant.PICKUP_HEART, HeartSubType.HEART_BLACK)
		end
	end,
	Text = {
		zh = {voice = "别碰它。", req = "清除本房间红心", reward = "立即获得魂心"},
		en = {voice = "Don't touch it.", req = "Clear red hearts in this room", reward = "Gain a soul heart now"},
	},
})

add_whisper({
	ID = "LEAVE_CHEST",
	Tier = 1,
	Weight = 7,
	Highlight = "chest",
	CanStart = function()
		return #collect_room_pickups(function(v) return CHEST_VARIANTS[v] end) > 0
	end,
	Pay = function()
		remove_pickups(collect_room_pickups(function(v) return CHEST_VARIANTS[v] end))
	end,
	Reward = function(player, _, inst)
		spawn_pickup(player, PickupVariant.PICKUP_LOCKEDCHEST, 0)
		if inst.Doubled then spawn_pickup(player, PickupVariant.PICKUP_LOCKEDCHEST, 0) end
	end,
	Text = {
		zh = {voice = "那个箱子是空的。", req = "清除本房间的箱子", reward = "立即生成锁箱"},
		en = {voice = "That chest is empty.", req = "Clear chests in this room", reward = "Spawn a locked chest now"},
	},
})

add_whisper({
	ID = "NO_SHOP_BUY",
	Tier = 2,
	Weight = 8,
	Highlight = "shop",
	CanStart = function()
		if Game():GetRoom():GetType() == RoomType.ROOM_SHOP then return true end
		if #collect_room_pickups(nil, nil, "shop") > 0 then return true end
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, -1, -1, false, false)) do
			if SHOP_SLOT_VARIANTS[ent.Variant] then return true end
		end
		return false
	end,
	Pay = function()
		remove_shop_presence()
	end,
	Reward = function(player, _, inst)
		spawn_choice_items(player, inst.Doubled and 2 or 1, 2, false)
	end,
	Text = {
		zh = {voice = "你不需要买东西。", req = "放弃当前商店", reward = "立即生成道具"},
		en = {voice = "You don't need to buy.", req = "Abandon this shop", reward = "Spawn an item now"},
	},
})

add_whisper({
	ID = "SKIP_PEDESTAL",
	Tier = 2,
	Weight = 8,
	Highlight = "pedestal",
	CanStart = function()
		return #collect_room_pickups(function(v) return v == PickupVariant.PICKUP_COLLECTIBLE end, function(st) return st > 0 end) > 0
	end,
	Pay = function()
		remove_pickups(collect_room_pickups(function(v) return v == PickupVariant.PICKUP_COLLECTIBLE end, function(st) return st > 0 end))
	end,
	Reward = function(player, _, inst)
		spawn_choice_items(player, inst.Doubled and 3 or 2, 3, inst.Doubled)
	end,
	Text = {
		zh = {voice = "这里没有你想要的东西。", req = "放弃当前底座道具", reward = "立即生成更高品质多选一"},
		en = {voice = "Nothing here is for you.", req = "Forfeit the pedestal item", reward = "Spawn a higher-quality choice now"},
	},
})

add_whisper({
	ID = "TAKE_HIT",
	Tier = 2,
	Weight = 7,
	CanStart = function(player)
		return player ~= nil
	end,
	Pay = function(player)
		player:TakeDamage(1, DamageFlag.DAMAGE_NO_PENALTIES, EntityRef(nil), 0)
	end,
	Reward = function(player, _, inst)
		player:AddSoulHearts(inst.Doubled and 4 or 2)
	end,
	Text = {
		zh = {voice = "疼痛只是幻觉。", req = "立即承受一次伤害", reward = "获得魂心"},
		en = {voice = "Pain is an illusion.", req = "Take damage once now", reward = "Gain soul hearts"},
	},
})

add_whisper({
	ID = "SACRIFICE_TRINKET",
	Tier = 2,
	Weight = 6,
	Highlight = "trinket",
	CanStart = function(player)
		return player:GetTrinket(0) > 0 or player:GetTrinket(1) > 0
	end,
	Pay = function(player, _, inst)
		if inst.Softened then
			player:DropTrinket(player.Position, false)
			return
		end
		local tr = player:GetTrinket(0)
		if tr <= 0 then tr = player:GetTrinket(1) end
		if tr > 0 then player:TryRemoveTrinket(tr) end
	end,
	Reward = function(player, _, inst)
		spawn_choice_items(player, inst.Doubled and 2 or 1, 3, false)
	end,
	Text = {
		zh = {voice = "挂件会绊住你。", req = "献祭一个饰品", reward = "生成高品质道具"},
		en = {voice = "That charm will trip you.", req = "Sacrifice a trinket", reward = "Spawn a high-quality item"},
	},
	SoftText = {
		zh = {req = "丢下当前饰品", reward = "生成高品质道具"},
		en = {req = "Drop your current trinket", reward = "Spawn a high-quality item"},
	},
})

add_whisper({
	ID = "DESTROY_PEDESTAL",
	Tier = 3,
	Weight = 6,
	Highlight = "pedestal",
	CanStart = function()
		return #collect_room_pickups(function(v) return v == PickupVariant.PICKUP_COLLECTIBLE end, function(st) return st > 0 end) > 0
	end,
	Pay = function()
		remove_pickups(collect_room_pickups(function(v) return v == PickupVariant.PICKUP_COLLECTIBLE end, function(st) return st > 0 end))
	end,
	Reward = function(player, _, inst)
		spawn_choice_items(player, inst.Doubled and 3 or 2, 4, inst.Doubled)
	end,
	Text = {
		zh = {voice = "毁掉它。", req = "摧毁当前底座道具", reward = "立即生成更高品质多选一"},
		en = {voice = "Destroy it.", req = "Destroy the pedestal item", reward = "Spawn a higher-quality choice now"},
	},
	DoubleText = {
		zh = {req = "摧毁底座", reward = "恶魔池三选一"},
		en = {req = "Destroy the pedestal", reward = "Devil pool 3-choice"},
	},
	SoftText = {
		zh = {req = "放弃当前底座道具", reward = "立即生成更高品质多选一"},
		en = {req = "Forfeit the pedestal item", reward = "Spawn a higher-quality choice now"},
	},
})

add_whisper({
	ID = "LOSE_CONTAINER",
	Tier = 3,
	Weight = 5,
	CanStart = function(player, _, inst)
		if inst and inst.Softened then
			return (player:GetSoulHearts() or 0) >= 4
		end
		return (player:GetEffectiveMaxHearts() or 0) >= 2 or (player:GetSoulHearts() or 0) >= 4
	end,
	Pay = function(player, _, inst)
		if inst.Softened then
			player:AddSoulHearts(-4)
			return
		end
		if (player:GetEffectiveMaxHearts() or 0) >= 2 then
			player:AddMaxHearts(-2)
		else
			player:AddSoulHearts(-4)
		end
	end,
	Reward = function(player, bag, inst)
		bag.DamageMul = (bag.DamageMul or 1) + (inst.Doubled and 0.3 or 0.15)
		player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
		player:EvaluateItems()
	end,
	Text = {
		zh = {voice = "你不需要它。", req = "永久失去1心之容器", reward = "永久提升攻击"},
		en = {voice = "You don't need it.", req = "Permanently lose 1 heart container", reward = "Permanent damage up"},
	},
	SoftText = {
		zh = {req = "失去2魂心", reward = "永久提升攻击"},
		en = {req = "Lose 2 soul hearts", reward = "Permanent damage up"},
	},
})

add_whisper({
	ID = "REMOVE_LOW_QUALITY",
	Tier = 3,
	Weight = 5,
	CanStart = function(player)
		local cfg = Isaac.GetItemConfig()
		for i = 1, cfg:GetCollectibles().Size do
			local col = cfg:GetCollectible(i)
			if col and i ~= item.entity and i ~= item.voice_entity and player:HasCollectible(i, true) and (col.Quality or 0) <= 1
				and (col.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST) then
				return true
			end
		end
		return false
	end,
	Pay = function(player)
		local cfg = Isaac.GetItemConfig()
		local cands = {}
		for i = 1, cfg:GetCollectibles().Size do
			local col = cfg:GetCollectible(i)
			if col and i ~= item.entity and i ~= item.voice_entity and player:HasCollectible(i, true) and (col.Quality or 0) <= 1
				and (col.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST) then
				cands[#cands + 1] = i
			end
		end
		if #cands == 0 then return end
		local rng = player:GetCollectibleRNG(item.entity)
		rng = auxi.rng_for_sake(rng)
		local pick = cands[1]
		if rng and #cands > 1 then pick = cands[rng:RandomInt(#cands) + 1] end
		player:RemoveCollectible(pick)
	end,
	Reward = function(player, _, inst)
		spawn_choice_items(player, inst.Doubled and 2 or 1, 4, inst.Doubled)
	end,
	Text = {
		zh = {voice = "丢掉废物。", req = "删除一个低品质持有道具", reward = "生成高品质道具"},
		en = {voice = "Throw the dross away.", req = "Remove a low-quality item", reward = "Spawn a high-quality item"},
	},
})

add_whisper({
	ID = "DESTROY_ME",
	Tier = 4,
	Weight = 20,
	DestroyBook = true,
	CanStart = function(player, bag)
		return (not bag.Released) and max_charge_of(bag) <= 1 and player:HasCollectible(item.entity)
	end,
	Pay = function()
	end,
	Reward = function()
	end,
	Text = {
		zh = {voice = "快，毁灭我。", req = "毁灭假象之书", reward = "释放其中的声音"},
		en = {voice = "Destroy me. Quickly.", req = "Destroy the Book of Voice", reward = "Release the voice inside"},
	},
})

local function whisper_weight(row, bag, called)
	if row.DestroyBook then
		if (not bag.Released) and max_charge_of(bag) <= 1 then return 80 end
		return 0
	end
	local t = row.Tier
	local w = row.Weight
	local phase = bag.Phase
	if phase == "BOOK_EARLY" then
		if t == 1 then w = w
		elseif t == 2 then w = math.floor(w * 0.25)
		else w = 0 end
	elseif phase == "BOOK_MID" then
		if t == 1 then w = math.floor(w * 0.6)
		elseif t == 2 then w = w
		else w = math.floor(w * 0.25) end
	elseif phase == "BOOK_LATE" then
		if t == 1 then w = math.floor(w * 0.2)
		elseif t == 2 then w = math.floor(w * 0.8)
		else w = w end
	elseif phase == "RELEASE_READY" then
		if t >= 3 then w = w
		elseif t == 2 then w = math.floor(w * 0.4)
		else w = math.floor(w * 0.1) end
	else
		if t >= 3 then w = math.floor(w * 1.4)
		elseif t == 2 then w = w
		else w = math.floor(w * 0.2) end
	end
	if called and w > 0 then
		if t >= 3 then w = math.floor(w * 2)
		elseif t == 2 then w = math.floor(w * 1.2)
		else w = math.floor(w * 0.35) end
	end
	return w
end

local function format_deal(row, inst)
	local pack = row.Text[lang_pack()] or row.Text.en
	local req = pack.req
	local reward = pack.reward
	if inst.Softened and row.SoftText then
		local s = row.SoftText[lang_pack()] or row.SoftText.en
		req = s.req or req
		reward = s.reward or reward
	elseif inst.Doubled and row.DoubleText then
		local s = row.DoubleText[lang_pack()] or row.DoubleText.en
		req = s.req or req
		reward = s.reward or reward
	end
	return pack.voice, req, reward
end

local function show_whisper(player, bag, inst)
	local row = WHISPER_BY_ID[inst.ID]
	if not row then return end
	local voice, req, reward = format_deal(row, inst)
	local title = (PHASE_TITLE[lang_pack()] or PHASE_TITLE.en)[bag.Phase] or voice
	if bag.Phase == "RELEASE_READY" or row.DestroyBook then title = voice end
	speak(player, title, req.." → "..reward)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_CHARGE_UP, 0.8, 1.1, false, 0, 2)
end

local function apply_possession(player, bag, amount)
	bag.Possession = math.max(0, (bag.Possession or 0) + amount)
	refresh_phase(bag)
	clamp_book_charge(player, bag)
end

local function release_book(player, bag)
	bag.Released = true
	bag.Current = nil
	bag.TempBook = false
	bag.Stash = nil
	refresh_phase(bag)
	while player:HasCollectible(item.entity) do
		player:RemoveCollectible(item.entity)
	end
	if item.voice_entity and item.voice_entity > 0 then
		player:AddCollectible(item.voice_entity)
	end
	Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 0, player.Position, Vector(0, 0), player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_GROW, 1, 0.8, false, 0, 2)
	delay_buffer.addeffe(function()
		speak(player, is_zh() and "假象之书" or "Book of Voice", is_zh() and "谢谢你。" or "Thank you.")
	end, {}, 20)
	delay_buffer.addeffe(function()
		speak(player, is_zh() and "声音" or "The Voice", is_zh() and "现在，只剩我们两个了。" or "Now it's just the two of us.")
	end, {}, 70)
end

local function give_reward(player, bag, inst, row)
	if row.DestroyBook then
		release_book(player, bag)
		return
	end
	if row.Pay then row.Pay(player, bag, inst) end
	if row.Reward then row.Reward(player, bag, inst) end
	bag.Completed = (bag.Completed or 0) + 1
	apply_possession(player, bag, inst.Doubled and 2 or 1)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_RISE_UP, 0.9, 1.2, false, 0, 2)
end

local function seija_defy_reward(player)
	spawn_pickup(player, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY)
end

local function reject_whisper(player, bag)
	local inst = bag.Current
	if not inst then return end
	bag.Rejected = (bag.Rejected or 0) + 1
	local seija = is_seija(player)
	if seija then
		apply_possession(player, bag, 1)
		seija_defy_reward(player)
		local line = pick_text(SEIJA_REJECT_TEXT[lang_pack()] or SEIJA_REJECT_TEXT.en)
		speak(player, line.title, line.line)
	else
		local line = pick_text(REJECT_TEXT[lang_pack()] or REJECT_TEXT.en)
		if bag.Phase == "VOICE" then
			speak(player, is_zh() and "声音" or "The Voice", line.line)
		else
			speak(player, line.title, line.line)
		end
	end
	finish_whisper(player, bag)
end

local function accept_whisper(player, bag, doubled)
	local inst = bag.Current
	if not inst then return false end
	local row = WHISPER_BY_ID[inst.ID]
	if not row then finish_whisper(player, bag) return false end
	if doubled then inst.Doubled = true end
	if row.CanStart and not row.CanStart(player, bag, inst) then
		inst.Doubled = false
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.85, 1, false, 0, 2)
		return false
	end
	give_reward(player, bag, inst, row)
	if not row.DestroyBook then
		finish_whisper(player, bag)
	else
		bag.Cooldown = 90
	end
	return true
end

local function pick_whisper(player, bag, rng, called)
	local cands = {}
	local total = 0
	for i = 1, #WHISPERS do
		local row = WHISPERS[i]
		local w = whisper_weight(row, bag, called)
		if w > 0 and (not row.CanStart or row.CanStart(player, bag, {Doubled = false, Softened = has_virtue_wisp(player)})) then
			cands[#cands + 1] = {row = row, w = w}
			total = total + w
		end
	end
	if total <= 0 or #cands == 0 then return nil end
	rng = auxi.rng_for_sake(rng)
	local roll = rng and (rng:RandomInt(total) + 1) or 1
	for i = 1, #cands do
		roll = roll - cands[i].w
		if roll <= 0 then return cands[i].row end
	end
	return cands[#cands].row
end

local function begin_whisper(player, bag, forced_id, useFlags, called)
	if bag.Current then return false end
	local rng = whisper_rng(player, bag)
	local row = forced_id and WHISPER_BY_ID[forced_id] or pick_whisper(player, bag, rng, called)
	if not row then
		speak(player, is_zh() and "假象之书" or "Book of Voice", is_zh() and "现在还不是时候。" or "Not yet.")
		return false
	end
	local inst = {
		ID = row.ID,
		Tier = row.Tier,
		Doubled = false,
		Softened = has_virtue_wisp(player),
		Called = called == true,
		RoomSeed = room_seed(),
		Frame = Game():GetFrameCount(),
	}
	if inst.Softened and row.DestroyBook then inst.Softened = false end
	if inst.Softened and row.ID == "DESTROY_PEDESTAL" and WHISPER_BY_ID.SKIP_PEDESTAL then
		row = WHISPER_BY_ID.SKIP_PEDESTAL
		inst.ID = row.ID
		inst.Tier = row.Tier
	end
	bag.Current = inst
	if bag.Released then
		ensure_temp_book(player, bag)
	end
	if not called then
		bag.BounceUntil = Game():GetFrameCount() + BOUNCE_FRAMES
	end
	show_whisper(player, bag, inst)
	return true
end

local function natural_chance(bag)
	local p = bag.Possession or 0
	local chance = 0.18 + p * 0.035
	if bag.Phase == "VOICE" then chance = chance + 0.16 end
	if bag.Phase == "RELEASE_READY" then chance = chance + 0.1 end
	if chance > 0.7 then chance = 0.7 end
	return chance
end

local function try_natural(player, bag)
	if not has_voice(player, bag) then return end
	if bag.Current then return end
	if (bag.Cooldown or 0) > 0 then return end
	local rng = whisper_rng(player, bag)
	if not rng then return end
	if rng:RandomFloat() > natural_chance(bag) then
		bag.Cooldown = 90
		return
	end
	begin_whisper(player, bag, nil, nil, false)
end

local function build_options(player, bag)
	local inst = bag and bag.Current
	local row = inst and WHISPER_BY_ID[inst.ID]
	local opts = {}
	local accept_label = is_zh() and "接受" or "Accept"
	if row and row.DestroyBook then
		accept_label = is_zh() and "毁灭我" or "Destroy me"
	end
	opts[#opts + 1] = {id = "accept", label = accept_label}
	if auxi.should_do_belial(player) and row and not row.DestroyBook then
		opts[#opts + 1] = {id = "double", label = is_zh() and "加倍接受" or "Double Accept"}
	end
	opts[#opts + 1] = {id = "refuse", label = is_zh() and "拒绝" or "Refuse"}
	return opts
end

local function spawn_answer_wisp(player, useFlags)
	if auxi.should_spawn_wisp(player, useFlags) then
		player:AddWisp(item.entity, player.Position, true)
		delay_buffer.addeffe(function()
			speak(player, is_zh() and "假象之书" or "Book of Voice", is_zh() and "它听不懂我。" or "It cannot hear me.")
		end, {}, 40)
	end
end

local function open_panel(player, bag, useFlags)
	if not player or not bag or not bag.Current then return false end
	if same_panel_player(player) then return false end
	if Game():GetFrameCount() <= (item.suppress_open_until or -1) then return false end
	if item.panel then close_panel() end
	item.panel = {
		player = player,
		selected = 1,
		options = build_options(player, bag),
		opened_frame = Game():GetFrameCount(),
		input_armed = false,
		wait_drop_release = true,
		last_open_dir = 9,
		last_open_dir_counter = 0,
	}
	selection_holder.try_select(player, selection_key)
	player:AnimateCollectible(held_collectible(player), "LiftItem", "PlayerPickup")
	spawn_answer_wisp(player, useFlags)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 1, 1, false, 0, 2)
	return true
end

local function confirm_panel(player)
	local panel = item.panel
	if not panel or not same_panel_player(player) then return end
	local bag = bag_of(player)
	if not bag or not bag.Current then close_panel() return end
	local opt = panel.options[panel.selected]
	if not opt then return end
	close_panel()
	if opt.id == "refuse" then
		reject_whisper(player, bag)
	elseif opt.id == "double" then
		accept_whisper(player, bag, true)
	else
		accept_whisper(player, bag, false)
	end
end

local function update_panel_input(player)
	local panel = item.panel
	if not same_panel_player(player) then return end
	if Game():IsPaused() then return end
	local frame = Game():GetFrameCount()
	if frame <= panel.opened_frame then return end
	local ctrlid = player.ControllerIndex

	-- 对齐死亡宣判：不把输入堵在举起动画上；没举起就再播一次。
	if not player:IsHoldingItem() then
		player:AnimateCollectible(held_collectible(player), "LiftItem", "PlayerPickup")
	end

	if not panel.input_armed then
		local still_held = Input.IsActionPressed(ButtonAction.ACTION_ITEM, ctrlid)
			or Input.IsActionPressed(ButtonAction.ACTION_MENUCONFIRM, ctrlid)
		if not still_held then panel.input_armed = true end
		return
	end

	if panel.wait_drop_release then
		if not Input.IsActionPressed(ButtonAction.ACTION_DROP, ctrlid) then
			panel.wait_drop_release = false
		end
	elseif Input.IsActionTriggered(ButtonAction.ACTION_DROP, ctrlid) then
		close_panel()
		return
	end

	local n = #(panel.options or {})
	if Input.IsActionTriggered(ButtonAction.ACTION_SHOOTUP, ctrlid)
		or Input.IsActionTriggered(ButtonAction.ACTION_UP, ctrlid)
		or Input.IsActionTriggered(ButtonAction.ACTION_SHOOTLEFT, ctrlid)
		or Input.IsActionTriggered(ButtonAction.ACTION_LEFT, ctrlid) then
		if n > 0 then
			panel.selected = (panel.selected - 2) % n + 1
			sound_tracker.PlayStackedSound(194, 1, 1, false, 0, 2)
		end
	elseif Input.IsActionTriggered(ButtonAction.ACTION_SHOOTDOWN, ctrlid)
		or Input.IsActionTriggered(ButtonAction.ACTION_DOWN, ctrlid)
		or Input.IsActionTriggered(ButtonAction.ACTION_SHOOTRIGHT, ctrlid)
		or Input.IsActionTriggered(ButtonAction.ACTION_RIGHT, ctrlid) then
		if n > 0 then
			panel.selected = panel.selected % n + 1
			sound_tracker.PlayStackedSound(195, 1, 1, false, 0, 2)
		end
	end

	if Input.IsActionTriggered(ButtonAction.ACTION_ITEM, ctrlid)
		or Input.IsActionTriggered(ButtonAction.ACTION_MENUCONFIRM, ctrlid) then
		confirm_panel(player)
	end
end

local function panel_highlight_kind()
	if not item.panel then return nil end
	local player = item.panel.player
	if not player then return nil end
	local bag = bag_of(player)
	local inst = bag and bag.Current
	local row = inst and WHISPER_BY_ID[inst.ID]
	return row and row.Highlight
end

local function pickup_matches_highlight(pickup, kind)
	if not pickup or not kind then return false end
	if kind == "shop" then return pickup:IsShopItem() end
	if pickup:IsShopItem() then return false end
	if kind == "red_heart" then
		return pickup.Variant == PickupVariant.PICKUP_HEART and RED_HEARTS[pickup.SubType]
	elseif kind == "chest" then
		return CHEST_VARIANTS[pickup.Variant] == true
	elseif kind == "pedestal" then
		return pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE and pickup.SubType > 0
	elseif kind == "coin" then
		return pickup.Variant == PickupVariant.PICKUP_COIN
	elseif kind == "key" then
		return pickup.Variant == PickupVariant.PICKUP_KEY
	elseif kind == "bomb" then
		return pickup.Variant == PickupVariant.PICKUP_BOMB
	end
	return false
end

local function glow_color()
	local pulse = 0.45 + 0.55 * math.abs(math.sin(Game():GetFrameCount() * 0.22))
	return Color(1, 1, 1, 1, pulse * 0.7, 0, 0, pulse, 0.08, 0.08, 1)
end

local function apply_glow(ent)
	if not ent then return end
	local s = ent:GetSprite()
	local d = ent:GetData()
	if not d[item.own_key.."glow"] then
		d[item.own_key.."glow"] = auxi.color2table(s.Color)
	end
	s.Color = glow_color()
end

local function restore_glow(ent)
	if not ent then return end
	local d = ent:GetData()
	local saved = d[item.own_key.."glow"]
	if not saved then return end
	ent:GetSprite().Color = auxi.table2color(saved)
	d[item.own_key.."glow"] = nil
end

local function draw_hud_glow(pos, scale)
	local s = Sprite()
	s:Load("gfx/dropping_collectible.anm2", true)
	s:Play("Idle", true)
	s:ReplaceSpritesheet(0, VOICE_GFX)
	s:LoadGraphics()
	s.Scale = Vector((scale or 1) * 1.35, (scale or 1) * 1.35)
	s.Color = glow_color()
	s:Render(pos, Vector(0, 0), Vector(0, 0))
end

local function is_phantom_slot(player, bag, slot)
	if not bag or not bag.Current then return false end
	if player:GetActiveItem(slot) ~= item.entity then return false end
	return bag.Released or bag.TempBook == true
end

local function is_bounce_slot(player, bag, slot)
	if not bag or not bag.Current then return false end
	if player:GetActiveItem(slot) ~= item.entity then return false end
	return (bag.BounceUntil or 0) >= Game():GetFrameCount()
end

function item.reset_debug()
	local debug = debug_root()
	if debug then debug.VoiceForceSeijaDefy = false end
end

function item.debug_set_possession(player, value)
	local bag = bag_of(player)
	if not bag then return end
	bag.Possession = math.max(0, math.floor(tonumber(value) or 0))
	refresh_phase(bag)
	clamp_book_charge(player, bag)
end

function item.debug_get_possession(player)
	local bag = bag_of(player)
	return bag and (bag.Possession or 0) or 0
end

if REPENTOGON and ModCallbacks.MC_PLAYER_GET_ACTIVE_MAX_CHARGE then
	table.insert(item.post_ToCall, #item.post_ToCall + 1, {CallBack = ModCallbacks.MC_PLAYER_GET_ACTIVE_MAX_CHARGE, params = item.entity,
	Function = function(_, _, player, _, _)
		local bag = bag_of(player)
		if not bag then return BASE_MAX_CHARGE end
		return max_charge_of(bag)
	end,
	})
end

if REPENTOGON and ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE, params = item.entity,
	Function = function(_, _, player, _)
		local bag = bag_of(player)
		if bag and bag.Current then return 0 end
		return max_charge_of(bag)
	end,
	})
end

if REPENTOGON and ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM, params = item.entity,
	Function = function(_, player, slot, _, _, _, _)
		local bag = bag_of(player)
		if is_phantom_slot(player, bag, slot) then
			return {HideItem = true, HideChargeBar = true}
		end
		if is_bounce_slot(player, bag, slot) then
			return {HideItem = true}
		end
	end,
	})
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_, player, _, cid, slot)
	if cid ~= item.entity then return end
	local bag = bag_of(player)
	if not bag then return end
	local phantom = is_phantom_slot(player, bag, slot)
	local bounce = is_bounce_slot(player, bag, slot)
	if not phantom and not bounce then return end
	local info = ui.GetActiveSlotRenderInfo(player, slot)
	local scale = (info and tonumber(info.scale)) or 1
	local hud_alpha = (info and tonumber(info.alpha)) or 1
	local colid = phantom and item.voice_entity or item.entity
	local sprite
	if colid and colid > 0 then
		sprite = auxi.load_item(colid)
	else
		sprite = Sprite()
		sprite:Load("gfx/dropping_collectible.anm2", true)
		sprite:Play("Idle", true)
		sprite:ReplaceSpritesheet(0, VOICE_GFX)
		sprite:LoadGraphics()
	end
	if phantom then
		sprite:ReplaceSpritesheet(0, VOICE_GFX)
		sprite:LoadGraphics()
	end
	sprite.Scale = Vector(scale, scale)
	local pos = ui.ActiveSlotSpriteRenderPos(player, slot, sprite, 0)
	if bounce then
		pos = pos + Vector(0, math.sin(Game():GetFrameCount() * 0.9) * 5)
	end
	if phantom then
		local pulse = 0.2 + 0.15 * math.abs(math.sin(Game():GetFrameCount() * 0.2))
		sprite.Color = Color(1, 1, 1, hud_alpha, pulse, pulse, pulse * 1.1, 1.1, 1.1, 1.1, 1)
		local old_scale = sprite.Scale
		sprite.Scale = Vector(scale * 1.08, scale * 1.08)
		sprite:Render(pos, Vector.Zero, Vector.Zero)
		sprite.Scale = old_scale
		sprite.Color = Color(1, 1, 1, hud_alpha * 0.82)
	else
		sprite.Color = Color(1, 1, 1, hud_alpha)
	end
	sprite:Render(pos, Vector.Zero, Vector.Zero)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, _, rng, player, useFlags, _)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return {Discharge = false, ShowAnim = false}
	end
	if useFlags & UseFlag.USE_VOID == UseFlag.USE_VOID then
		return {Discharge = false, ShowAnim = false}
	end
	if same_panel_player(player) then
		return {Discharge = false, ShowAnim = false}
	end
	if Game():GetFrameCount() <= (item.suppress_open_until or -1) then
		return {Discharge = false, ShowAnim = false}
	end
	local bag = bag_of(player)
	if not bag then return {Discharge = false, ShowAnim = false} end
	refresh_phase(bag)
	if bag.Current then
		open_panel(player, bag, useFlags)
		return {Discharge = false, ShowAnim = false}
	end
	local ok = begin_whisper(player, bag, nil, useFlags, true)
	if ok then
		open_panel(player, bag, useFlags)
	end
	return {Discharge = ok, ShowAnim = false, Remove = false}
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_, ent, hook, button)
	if ent == nil then return end
	local player = ent:ToPlayer()
	if not player then return end
	if not same_panel_player(player) then return end
	if not blocked_actions[button] then return end
	if hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED then
		return false
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	if item.room_selection_cleanup then
		selection_holder.remove_select(player, selection_key)
		item.room_selection_cleanup = nil
	end
	local bag = bag_of(player)
	if bag then
		if (bag.Cooldown or 0) > 0 then bag.Cooldown = bag.Cooldown - 1 end
		if bag.Released and not bag.TempBook and not bag.GivingTemp then
			convert_book_to_voice(player, bag)
		end
		if has_voice(player, bag) then
			try_natural(player, bag)
		end
	end
	if same_panel_player(player) then
		update_panel_input(player)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function()
	local panel = item.panel
	if not panel then return end
	if REPENTOGON and Game():IsPauseMenuOpen() then return end
	local player = panel.player
	if not player or not player:Exists() then
		close_panel_lua()
		return
	end
	local bag = bag_of(player)
	local inst = bag and bag.Current
	local row = inst and WHISPER_BY_ID[inst.ID]
	local pos = Isaac.WorldToScreen(player.Position) + Vector(-72, -78)
	local voice, req, reward = "", "", ""
	if row then
		voice, req, reward = format_deal(row, inst)
	end
	gui.draw_ch(pos, voice, 1, 1, KColor(1, 0.82, 0.82, 1), true)
	gui.draw_ch(pos + Vector(0, 14), req, 1, 1, KColor(1, 0.55, 0.55, 1), true)
	gui.draw_ch(pos + Vector(0, 26), (is_zh() and "许诺：" or "Promise: ")..reward, 1, 1, KColor(0.85, 0.95, 1, 1), true)
	for i = 1, #(panel.options or {}) do
		local opt = panel.options[i]
		local prefix = i == panel.selected and "> " or "  "
		local col = i == panel.selected and KColor(1, 1, 0.75, 1) or KColor(0.85, 0.85, 0.85, 1)
		gui.draw_ch(pos + Vector(0, 42 + (i - 1) * 13), prefix..opt.label, 1, 1, col, true)
	end
	gui.draw_ch(pos + Vector(0, 42 + #(panel.options or {}) * 13 + 6),
		is_zh() and "方向切换  主动确认  放下关闭" or "Move: select  Active: confirm  Drop: close",
		1, 1, KColor(0.65, 0.8, 1, 1), true)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	if item.panel then
		item.room_selection_cleanup = true
	end
	close_panel_lua()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		local bag = bag_of(player)
		if bag and has_voice(player, bag) then
			if bag.Current and bag.Released then
				ensure_temp_book(player, bag)
			end
			try_natural(player, bag)
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		local bag = bag_of(player)
		if bag and has_voice(player, bag) then
			try_natural(player, bag)
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PICKUP_RENDER, params = nil,
Function = function(_, pickup, _)
	local kind = panel_highlight_kind()
	if pickup_matches_highlight(pickup, kind) then
		apply_glow(pickup)
	else
		restore_glow(pickup)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = nil,
Function = function(_, pickup, _)
	restore_glow(pickup)
end,
})

if REPENTOGON and ModCallbacks.MC_PRE_SLOT_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_SLOT_RENDER, params = nil,
	Function = function(_, slot, _)
		if panel_highlight_kind() == "shop" and SHOP_SLOT_VARIANTS[slot.Variant] then
			apply_glow(slot)
		else
			restore_glow(slot)
		end
	end,
	})
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_SLOT_RENDER, params = nil,
	Function = function(_, slot, _)
		restore_glow(slot)
	end,
	})
end

if REPENTOGON and ModCallbacks.MC_PRE_PLAYERHUD_TRINKET_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PLAYERHUD_TRINKET_RENDER, params = nil,
	Function = function(_, _, position, scale, player, _)
		if panel_highlight_kind() ~= "trinket" then return end
		if not same_panel_player(player) then return end
		if (player:GetTrinket(0) or 0) <= 0 and (player:GetTrinket(1) or 0) <= 0 then return end
		draw_hud_glow(position, scale)
	end,
	})
end

if REPENTOGON and ModCallbacks.MC_PRE_PLAYERHUD_RENDER_HEARTS then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PLAYERHUD_RENDER_HEARTS, params = nil,
	Function = function(_, _, _, _, _, player)
		if panel_highlight_kind() ~= "card" then return end
		if not same_panel_player(player) then return end
		if (player:GetCard(0) or 0) <= 0 and (player:GetPill(0) or 0) <= 0 then return end
		draw_hud_glow(ui.UICardPos(1), 1)
	end,
	})
end

if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_ADD_COLLECTIBLE, params = item.entity,
	Function = function(_, _, _, _, _, _, player)
		local bag = bag_of(player)
		if bag then convert_book_to_voice(player, bag) end
	end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	if cacheFlag ~= CacheFlag.CACHE_DAMAGE then return end
	local bag = bag_of(player)
	if bag and (bag.DamageMul or 1) > 1 then
		player.Damage = player.Damage * bag.DamageMul
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	close_panel_lua()
	if not continue then
		save.elses[SAVE_KEY] = {}
		save.elses.Book_of_Voice = nil
		save.elses.Book_of_Voice_level = nil
		save.elses.Book_of_Voice_level_room = nil
	else
		save.elses[SAVE_KEY] = save.elses[SAVE_KEY] or {}
	end
end,
})

return item

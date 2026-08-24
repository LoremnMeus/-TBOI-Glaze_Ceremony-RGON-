-- 蓝图「道具原型」掉落物：拾取写入蓝图库存，不 AddCollectible
-- 贴图：gfx/items/prototype.anm2，Layer 4 Item 运行时替换为对应收藏品 GfxFileName
-- 清房：RGON MC_PRE/POST_ROOM_TRIGGER_CLEAR；商店价不吃消耗品原价；购买后可 Restock
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local PRICE_SPIKES = PickupPrice and PickupPrice.PRICE_SPIKES or -5

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Pickup_Blueprint_Prototype_",
	pickup = enums.Pickups.Blueprint_Prototype,
	anm2 = "gfx/items/prototype.anm2",
	item_layer = 4, -- Layer Name="Item"；ReplaceSpritesheet 参数是 LayerId，禁止改成 3
	force_next_clean = false,
	_pre_clear_seeds = nil,
}

local REPLACEABLE_CLEAN = {
	[PickupVariant.PICKUP_HEART] = true,
	[PickupVariant.PICKUP_COIN] = true,
	[PickupVariant.PICKUP_BOMB] = true,
	[PickupVariant.PICKUP_KEY] = true,
	[PickupVariant.PICKUP_LIL_BATTERY] = true,
	[PickupVariant.PICKUP_PILL] = true,
	[PickupVariant.PICKUP_TAROTCARD] = true,
}

local SHOP_CONSUMABLE = {
	[PickupVariant.PICKUP_HEART] = true,
	[PickupVariant.PICKUP_COIN] = true,
	[PickupVariant.PICKUP_BOMB] = true,
	[PickupVariant.PICKUP_KEY] = true,
	[PickupVariant.PICKUP_LIL_BATTERY] = true,
	[PickupVariant.PICKUP_PILL] = true,
	[PickupVariant.PICKUP_TAROTCARD] = true,
}

local function lang_is_zh()
	if EID and EID.UserConfig and EID.UserConfig.Language and EID.UserConfig.Language ~= "auto" then
		local lang = EID.UserConfig.Language
		return lang == "zh" or lang == "zh_cn"
	end
	return Options.Language == "zh" or Options.Language == "zh_cn"
end

--- 名称 / Desc（风味，沿用原道具）/ EID Description
function item.get_texts(collectible_id)
	collectible_id = tonumber(collectible_id) or 0
	local col = Isaac.GetItemConfig():GetCollectible(collectible_id)
	local base_name = auxi.check_name_data(col and col.Name or ("#" .. tostring(collectible_id)))
	local base_desc = auxi.check_name_data(col and col.Description or "")
	local zh = lang_is_zh()
	local name = zh and (base_name .. "原型") or (base_name .. " Prototype")
	local icon = "{{Collectible" .. tostring(collectible_id) .. "}}"
	local description
	if zh then
		description = "#{{Collectible}} 拾取后，将" .. icon .. "记录为1份原型模块"
			.. "#原型模块存入蓝图仓库，可额外装配1次对应道具效果"
			.. "#只能作为模块使用，不能作为飞行器成本"
	else
		description = "#{{Collectible}} On pickup, records " .. icon .. " as 1 prototype module"
			.. "#Stored in Blueprint inventory, granting 1 extra installation of that item's effect"
			.. "#Modules only; cannot be used as a Flight cost"
	end
	return {
		Name = name,
		Desc = base_desc,
		Description = description,
		base_name = base_name,
	}
end

function item.load_EID(ent)
	if not ent or not EID then return end
	local texts = item.get_texts(ent.SubType)
	ent:GetData().EID_Description = {
		Name = texts.Name,
		Description = texts.Description,
	}
end

local MAX_REJECT = 40
local CLEAN_PITY_START = 15
local CLEAN_PITY_GUARANTEE = 25
local SHOP_FIRST_CHANCE = 0.125
local SHOP_RESTOCK_PROTO_CHANCE = 0.0625
local BREAKFAST = CollectibleType.COLLECTIBLE_BREAKFAST or 25

local function get_bp()
	return require("Qing_Remaster_scripts.items.Item_Blue_Print")
end

--- 商店/清房/天使恶魔等自然生成：仅当场上有人持有蓝图时才可能出现。
--- ImGui debug spawn 不经此检查。
local function any_player_owns_blueprint()
	local id = enums.Items.Blue_Print
	if not id or id <= 0 then return false end
	local n = Game():GetNumPlayers()
	for i = 0, n - 1 do
		local p = Game():GetPlayer(i)
		if p and p:HasCollectible(id) then return true end
	end
	return false
end

local function floor_key()
	local level = Game():GetLevel()
	if not level then return 0 end
	return (level:GetStage() or 0) * 100 + (level:GetStageType() or 0)
end

local function room_unique_key()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return "0"
	end
	return tostring(desc.ListIndex or desc.SafeGridIndex or 0)
end

local function root_meta()
	local bp = get_bp()
	local root = bp.ensure_prototype_root and bp.ensure_prototype_root() or nil
	if root then
		root.room_flags = root.room_flags or {}
		root.shop_restock_tax = root.shop_restock_tax or {}
		root.shop_proto_rooms = root.shop_proto_rooms or {}
	end
	return root
end

local function room_flag(key)
	local meta = root_meta()
	if not meta then return nil end
	meta.room_flags[key] = meta.room_flags[key] or {}
	return meta.room_flags[key]
end

local function quality_of(id)
	local col = Isaac.GetItemConfig():GetCollectible(id)
	return col and (col.Quality or 0) or 0
end

local function shop_price_base(quality)
	quality = quality or 0
	if quality <= 1 then return 7 end
	if quality == 2 then return 10 end
	if quality == 3 then return 15 end
	return 25
end

--- 品质基础价 + Restock 涨价，再套 Steam Sale；不从被替换消耗品价格反推
function item.compute_listed_price(quality, restock_tax)
	local base = shop_price_base(quality)
	local tax = math.max(0, math.floor(tonumber(restock_tax) or 0))
	if tax > 0 then
		base = base + math.floor(tax * (tax + 1) / 2)
	end
	base = math.min(99, base)
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p.GetCollectibleNum then
			local n = p:GetCollectibleNum(CollectibleType.COLLECTIBLE_STEAM_SALE) or 0
			for _ = 1, n do
				base = math.max(1, math.floor(base / 2))
			end
		end
	end
	return base
end

--- 恶魔房原型使用独立尖刺售价：拾取时受到一次半心尖刺伤害，与品质无关。
local function pay_devil_spike(player, ent)
	if not player then return false end
	-- 这是独立售价而非普通受伤：固定半心、穿过无敌帧，不触发房间/道具的受伤惩罚或修正。
	local flags = DamageFlag.DAMAGE_SPIKES | DamageFlag.DAMAGE_INVINCIBLE
		| DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_NO_MODIFIERS
	return player:TakeDamage(1, flags, EntityRef(ent or player), 30) ~= false
end

local function eligible_fallback_list()
	local list = {}
	local config = Isaac.GetItemConfig()
	local size = config:GetCollectibles().Size
	for id = 1, size do
		if CraftProfile.is_prototype_eligible(id) then
			list[#list + 1] = id
		end
	end
	return list
end

--- 仅本池内、且通过 is_prototype_eligible 的收藏品（保留恶魔/天使/商店主题）
local function eligible_list_for_pool(pool_type)
	local list = {}
	local seen = {}
	local pool = Game():GetItemPool()
	if not pool or not pool.GetCollectiblesFromPool then
		return list
	end
	local rows = pool:GetCollectiblesFromPool(pool_type)
	if type(rows) ~= "table" then return list end
	for _, row in pairs(rows) do
		local id = nil
		if type(row) == "table" then
			id = tonumber(row.itemID or row.ItemID or row.id)
		else
			id = tonumber(row)
		end
		if id and id > 0 and not seen[id] and CraftProfile.is_prototype_eligible(id) then
			seen[id] = true
			list[#list + 1] = id
		end
	end
	return list
end

local function is_deal_pool(pool_type)
	return pool_type == ItemPoolType.POOL_DEVIL or pool_type == ItemPoolType.POOL_ANGEL
end

--- pool 抽失败时：先本池合格表；清房/商店可再退 Treasure；恶魔/天使禁止跨池，避免不兼容主题
function item.roll_collectible(pool_type, rng, allow_treasure_fallback)
	rng = rng or RNG()
	local pool = Game():GetItemPool()
	pool_type = pool_type or ItemPoolType.POOL_TREASURE
	if pool_type < 0 then pool_type = ItemPoolType.POOL_TREASURE end
	local null_item = CollectibleType.COLLECTIBLE_NULL or 0
	local function pool_roll(ptype)
		-- RGON：第 4 参 DefaultItem=NULL，避免耗尽退 Breakfast；无则退回三参
		local ok, id = pcall(function()
			return pool:GetCollectible(ptype, false, rng:Next(), null_item)
		end)
		if not ok then
			id = pool:GetCollectible(ptype, false, rng:Next())
		end
		return tonumber(id) or 0
	end
	for _ = 1, MAX_REJECT do
		local id = pool_roll(pool_type)
		if id > 0 and id ~= BREAKFAST and CraftProfile.is_prototype_eligible(id) then
			return id, pool_type
		end
	end
	local scoped = eligible_list_for_pool(pool_type)
	if #scoped > 0 then
		return scoped[rng:RandomInt(#scoped) + 1], pool_type
	end
	-- 交易房：绝不能用宝箱/全表顶替，否则恶魔房会出现天使/宝箱主题材料
	if is_deal_pool(pool_type) then
		return nil, pool_type
	end
	if allow_treasure_fallback ~= false and pool_type ~= ItemPoolType.POOL_TREASURE then
		for _ = 1, MAX_REJECT do
			local id = pool_roll(ItemPoolType.POOL_TREASURE)
			if id > 0 and id ~= BREAKFAST and CraftProfile.is_prototype_eligible(id) then
				return id, ItemPoolType.POOL_TREASURE
			end
		end
		local treasure_scoped = eligible_list_for_pool(ItemPoolType.POOL_TREASURE)
		if #treasure_scoped > 0 then
			return treasure_scoped[rng:RandomInt(#treasure_scoped) + 1], ItemPoolType.POOL_TREASURE
		end
	end
	local all = eligible_fallback_list()
	if #all > 0 then
		return all[rng:RandomInt(#all) + 1], pool_type
	end
	return nil, pool_type
end

--- 生成前/INIT：加载 prototype.anm2，并替换 Layer 4 Item 为收藏品贴图
function item.apply_item_sprite(ent, collectible_id, play_anim)
	if not ent then return end
	collectible_id = tonumber(collectible_id) or ent.SubType
	local col = Isaac.GetItemConfig():GetCollectible(collectible_id)
	local gfx = (col and col.GfxFileName) or "gfx/items/collectibles/questionmark.png"
	local s = ent:GetSprite()
	s:Load(item.anm2, true)
	s:ReplaceSpritesheet(item.item_layer, gfx)
	s:LoadGraphics()
	if play_anim == false then return end
	if Game():GetRoom():GetFrameCount() <= 0 then
		s:Play("Idle", true)
	else
		s:Play("Appear", true)
	end
end

function item.spawn_prototype(pos, collectible_id, opts)
	opts = opts or {}
	collectible_id = tonumber(collectible_id)
	if not collectible_id or not CraftProfile.is_prototype_eligible(collectible_id) then
		return nil
	end
	local room = Game():GetRoom()
	pos = pos or room:GetCenterPos()
	if opts.exact_pos ~= true then
		pos = room:FindFreePickupSpawnPosition(pos, 10, true)
	end
	local variant = item.pickup.Variant
	local ent = Isaac.Spawn(EntityType.ENTITY_PICKUP, variant, collectible_id, pos, Vector(0, 0), opts.spawner)
	ent = ent and ent:ToPickup()
	if not ent then return nil end
	item.apply_item_sprite(ent, collectible_id, true)
	item.load_EID(ent)
	local d = ent:GetData()
	d[item.own_key.."pool"] = opts.pool_type
	d[item.own_key.."source"] = opts.source or "debug"
	d[item.own_key.."quality"] = quality_of(collectible_id)
	if opts.shop then
		ent.ShopItemId = opts.shop_item_id or -1
		ent.AutoUpdatePrice = false
		local tax = tonumber(opts.restock_tax) or 0
		ent.Price = opts.price or item.compute_listed_price(d[item.own_key.."quality"], tax)
		d[item.own_key.."restock_tax"] = tax
	elseif opts.devil then
		d[item.own_key.."devil_spike"] = opts.devil_spike ~= false
		-- 复用原版尖刺价格及其 HUD 图标；实际支付仍由本模块拦截为半颗心。
		ent.ShopItemId = opts.shop_item_id or -1
		ent.AutoUpdatePrice = false
		ent.Price = PRICE_SPIKES
	end
	return ent
end

--- SubType=0（控制台/模组 spawn 未指定 ID）：就地变成随机有效原型，禁止卡死
function item.resolve_untyped_prototype(ent)
	if not ent or ent.Variant ~= item.pickup.Variant then return nil end
	local d = ent:GetData()
	if d[item.own_key.."resolving"] then return tonumber(ent.SubType) end
	local cur = tonumber(ent.SubType) or 0
	if cur > 0 and CraftProfile.is_prototype_eligible(cur) then
		return cur
	end
	d[item.own_key.."resolving"] = true
	local rng = RNG()
	local seed = ent.InitSeed or Random()
	if seed == 0 then seed = 1 end
	rng:SetSeed(math.floor(seed % 4294967296), 35)
	local room = Game():GetRoom()
	local pool_type = ItemPoolType.POOL_TREASURE
	if room then
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		local spawn_seed = desc and desc.SpawnSeed or seed
		pool_type = Game():GetItemPool():GetPoolForRoom(room:GetType(), spawn_seed)
		if not pool_type or pool_type < 0 then pool_type = ItemPoolType.POOL_TREASURE end
	end
	local rolled = select(1, item.roll_collectible(pool_type, rng, true))
	if not rolled then
		-- roll_collectible 可能因交易房禁跨池返回 nil；强制全表合格项
		local all = {}
		local config = Isaac.GetItemConfig()
		local size = config:GetCollectibles().Size
		for id = 1, size do
			if CraftProfile.is_prototype_eligible(id) then
				all[#all + 1] = id
			end
		end
		if #all > 0 then
			rolled = all[rng:RandomInt(#all) + 1]
		end
	end
	if not rolled then
		d[item.own_key.."resolving"] = nil
		return nil
	end
	if ent.Morph then
		ent:Morph(EntityType.ENTITY_PICKUP, item.pickup.Variant, rolled, true, true, false)
	else
		ent.SubType = rolled
	end
	d[item.own_key.."source"] = d[item.own_key.."source"] or "untyped"
	d[item.own_key.."pool"] = d[item.own_key.."pool"] or pool_type
	d[item.own_key.."quality"] = quality_of(rolled)
	d[item.own_key.."resolving"] = nil
	item.apply_item_sprite(ent, rolled, true)
	item.load_EID(ent)
	return rolled
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_INIT,
	params = nil,
	Function = function(_, ent)
		if not ent or ent.Variant ~= item.pickup.Variant then return end
		local id = tonumber(ent.SubType) or 0
		if id <= 0 or not CraftProfile.is_prototype_eligible(id) then
			id = item.resolve_untyped_prototype(ent) or 0
		end
		if id > 0 then
			item.apply_item_sprite(ent, id, true)
			item.load_EID(ent)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE,
	params = nil,
	Function = function(_, ent)
		if not ent or ent.Variant ~= item.pickup.Variant then return end
		-- INIT 未跑到或 Morph 失败时兜底，避免 SubType=0 一直卡住
		local id = tonumber(ent.SubType) or 0
		if id <= 0 then
			item.resolve_untyped_prototype(ent)
			return
		end
		local s = ent:GetSprite()
		if s:IsFinished("Appear") then s:Play("Idle", true) end
		if s:IsFinished("Collect") or s:IsEventTriggered("Remove") then
			ent:Remove()
		end
	end,
})

-- 引擎算完价后覆盖为品质基础价（含 Steam Sale）；避免重复折扣时只返回 compute_listed_price
if ModCallbacks.MC_GET_SHOP_ITEM_PRICE then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_GET_SHOP_ITEM_PRICE,
		params = item.pickup.Variant,
		Function = function(_, variant, subtype, shop_item_id, price)
			if variant ~= item.pickup.Variant then return end
			local tax = 0
			-- 尝试从场上实体读 tax；缺省按品质基础+Steam Sale
			for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, item.pickup.Variant, subtype or -1, false, false)) do
				local pk = e:ToPickup()
				if pk and pk.ShopItemId == shop_item_id then
					if pk:GetData()[item.own_key.."devil_spike"] then
						return PRICE_SPIKES
					end
					tax = tonumber(pk:GetData()[item.own_key.."restock_tax"]) or 0
					break
				end
			end
			return item.compute_listed_price(quality_of(subtype), tax)
		end,
	})
end

local function charge_shop_price(player, ent)
	local price = ent.Price or 0
	if price > 0 then
		player:AddCoins(-price)
		if auxi.has_have_coll(player, CollectibleType.COLLECTIBLE_KEEPERS_SACK) then
			player:GetData().Keeper_Sack_adder = (player:GetData().Keeper_Sack_adder or 0) + price
		end
		local Dyn = require("Qing_Remaster_scripts.others.craft_dynamic_stats")
		if Dyn and Dyn.on_player_spent_coins then
			Dyn.on_player_spent_coins(player, price)
		end
	elseif price == (PickupPrice and PickupPrice.PRICE_FREE or -1000) then
		local credit = auxi.have_player_has_trinket and auxi.have_player_has_trinket(TrinketType.TRINKET_STORE_CREDIT)
		if credit then credit:TryRemoveTrinket(TrinketType.TRINKET_STORE_CREDIT) end
	end
end

local function random_shop_consumable_subtype(variant, rng)
	if variant == PickupVariant.PICKUP_HEART then
		return HeartSubType.HEART_FULL
	elseif variant == PickupVariant.PICKUP_COIN then
		return CoinSubType.COIN_PENNY
	elseif variant == PickupVariant.PICKUP_BOMB then
		return (BombSubType and BombSubType.BOMB_NORMAL) or 1
	elseif variant == PickupVariant.PICKUP_KEY then
		return (KeySubType and KeySubType.KEY_NORMAL) or 1
	elseif variant == PickupVariant.PICKUP_LIL_BATTERY then
		return (BatterySubType and BatterySubType.BATTERY_NORMAL) or 1
	elseif variant == PickupVariant.PICKUP_PILL then
		return rng:RandomInt(13) + 1
	elseif variant == PickupVariant.PICKUP_TAROTCARD then
		return Game():GetItemPool():GetCard(rng:Next(), false, false, false)
	end
	return 1
end

--- 购买原型后的补货：默认普通消耗品；6.25% 再出原型；叠加 Restock Tax
function item.schedule_shop_restock(ent)
	if not ent then return end
	local pos = Vector(ent.Position.X, ent.Position.Y)
	local shop_id = ent.ShopItemId
	local meta = root_meta()
	if not meta then return end
	local rkey = room_unique_key()
	local tax_key = rkey .. "_" .. tostring(shop_id)
	local tax = tonumber(meta.shop_restock_tax[tax_key]) or 0
	local next_tax = tax + 1
	meta.shop_restock_tax[tax_key] = next_tax
	local seed = (ent.InitSeed or 1) + Game():GetFrameCount() * 17 + next_tax * 31

	local delay = Game():IsGreedMode() and 10 or 1
	delay_buffer.addeffe(function()
		local room = Game():GetRoom()
		if not room or room:GetType() ~= RoomType.ROOM_SHOP then return end
		local rng = RNG()
		rng:SetSeed(math.floor(seed % 4294967296) + 1, 35)
		local spawn_pos = room:FindFreePickupSpawnPosition(pos, 0, true)
		local new_ent
		if rng:RandomFloat() < SHOP_RESTOCK_PROTO_CHANCE and any_player_owns_blueprint() then
			local id = select(1, item.roll_collectible(ItemPoolType.POOL_SHOP, rng, true))
			if id then
				new_ent = item.spawn_prototype(spawn_pos, id, {
					pool_type = ItemPoolType.POOL_SHOP,
					source = "shop_restock",
					shop = true,
					shop_item_id = shop_id,
					restock_tax = next_tax,
					exact_pos = true,
				})
			end
		end
		if not new_ent then
			local variants = {
				PickupVariant.PICKUP_HEART,
				PickupVariant.PICKUP_COIN,
				PickupVariant.PICKUP_BOMB,
				PickupVariant.PICKUP_KEY,
				PickupVariant.PICKUP_LIL_BATTERY,
				PickupVariant.PICKUP_PILL,
				PickupVariant.PICKUP_TAROTCARD,
			}
			local vr = variants[rng:RandomInt(#variants) + 1]
			local st = random_shop_consumable_subtype(vr, rng)
			new_ent = Isaac.Spawn(EntityType.ENTITY_PICKUP, vr, st, spawn_pos, Vector(0, 0), nil)
			new_ent = new_ent and new_ent:ToPickup()
			if new_ent then
				new_ent.ShopItemId = shop_id
				-- Lua 新生成的商店掉落不会可靠触发自动定价；直接询问房间价格后锁定。
				local listed = room.GetShopItemPrice and room:GetShopItemPrice(vr, st, shop_id)
				if not listed or listed <= 0 then listed = 5 end
				new_ent.AutoUpdatePrice = false
				new_ent.Price = listed
				if next_tax > 0 then
					new_ent.Price = math.min(99, new_ent.Price + math.floor(next_tax * (next_tax + 1) / 2))
				end
			end
		end
		if new_ent then
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, spawn_pos, Vector(0, 0), new_ent)
			if new_ent.Wait ~= nil then new_ent.Wait = 60 end
		end
	end, {}, delay)
end

local function try_collect(ent, player)
	if not ent or not player then return false end
	local d = ent:GetData()
	local id = ent.SubType
	if not id or id <= 0 then return false end

	local devil_spike = d[item.own_key.."devil_spike"] == true
	local is_shop = ent:IsShopItem() and not devil_spike

	-- 1) 先检查支付能力，失败不改库存/不移除
	if is_shop then
		if auxi.check_shop_pickup(ent, player) then return false end
	end

	-- 2) 写入库存
	local bp = get_bp()
	local uid = bp.add_prototype(player, id, {
		pool = d[item.own_key.."pool"],
		quality = d[item.own_key.."quality"] or quality_of(id),
		source = d[item.own_key.."source"] or "pickup",
	})
	if not uid then return false end

	-- 3) 扣款 / 刺价；商店可 Restock
	if is_shop then
		charge_shop_price(player, ent)
		if auxi.can_restock() then
			item.schedule_shop_restock(ent)
		end
	elseif devil_spike then
		pay_devil_spike(player, ent)
	end

	local texts = item.get_texts(id)
	local hud = Game():GetHUD()
	if hud and hud.ShowItemText then
		hud:ShowItemText(texts.Name, texts.Desc or "")
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1, 0.9, 1.1, false, 0, 2)
	player:AnimateHappy()
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	local s = ent:GetSprite()
	-- Sprite 没有 HasAnimation API；Collect 由本模组 prototype.anm2 明确定义。
	s:Play("Collect", true)
	return true
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION,
	params = nil,
	Function = function(_, ent, col, low)
		if not ent or ent.Variant ~= item.pickup.Variant then return end
		local player = col and col:ToPlayer()
		if not player then return end
		if try_collect(ent, player) then
			return true
		elseif ent:IsShopItem() or ent:GetData()[item.own_key.."devil_spike"] then
			return false
		end
		return false
	end,
})

-- ---------- 清房：进房记敌人 + PRE 快照 + POST 判定 ----------
local function has_valid_clearable_enemies()
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		local npc = ent and ent:ToNPC()
		if npc and npc:IsActiveEnemy(false)
			and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
		then
			return true
		end
	end
	return false
end

local function snapshot_pickup_seeds()
	local set = {}
	for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, false, false)) do
		if e and e.InitSeed then
			set[e.InitSeed] = true
		end
	end
	return set
end

local function is_valid_prototype_clear_room(room)
	if not room then return false end
	if Game():IsGreedMode() then return false end
	if room:GetType() ~= RoomType.ROOM_DEFAULT then return false end
	return true
end

local function process_clean_prototype(opts)
	opts = opts or {}
	local force_extra = opts.force_extra == true
	local room = Game():GetRoom()
	if not is_valid_prototype_clear_room(room) then
		item._pre_clear_seeds = nil
		return
	end
	local key = room_unique_key()
	local rf = room_flag(key)
	if not rf then
		item._pre_clear_seeds = nil
		return
	end
	if rf.prototype_clear_checked then
		item._pre_clear_seeds = nil
		return
	end
	-- 无人持有蓝图：不掉落，也不消耗本房判定/保底进度
	if not any_player_owns_blueprint() then
		item._pre_clear_seeds = nil
		return
	end
	rf.prototype_clear_checked = true

	local meta = root_meta()
	if not meta then
		item._pre_clear_seeds = nil
		return
	end

	-- 空房 / 无有效敌人：不记保底、不掉落
	if not rf.had_valid_enemies then
		item._pre_clear_seeds = nil
		return
	end

	meta.clean_streak = tonumber(meta.clean_streak) or 0
	local force = item.force_next_clean or meta.force_next_clean
	local luck = 0
	local p0 = Game():GetPlayer(0)
	if p0 then luck = p0.Luck or 0 end

	local rng = RNG()
	local seed = room:GetSpawnSeed()
	if seed == 0 then seed = 1 end
	rng:SetSeed(seed, 35)

	local base = math.max(0.005, math.min(0.06, 0.02 + 0.003 * luck))
	local streak = meta.clean_streak
	if streak >= CLEAN_PITY_START then
		base = base + 0.005 * (streak - CLEAN_PITY_START + 1)
	end
	local hit = force or streak + 1 >= CLEAN_PITY_GUARANTEE or rng:RandomFloat() < base
	if not hit then
		meta.clean_streak = streak + 1
		item._pre_clear_seeds = nil
		return
	end
	item.force_next_clean = false
	meta.force_next_clean = nil
	meta.clean_streak = 0

	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local pool_type = Game():GetItemPool():GetPoolForRoom(room:GetType(), desc and desc.SpawnSeed or seed)
	local id = select(1, item.roll_collectible(pool_type, rng, true))
	if not id then
		item._pre_clear_seeds = nil
		return
	end

	local extra_rate = math.max(0.3, math.min(1, 0.3 + 0.1 * luck))
	local do_extra = force_extra or rng:RandomFloat() < extra_rate
	local spawn_pos = room:GetCenterPos()
	local pre = item._pre_clear_seeds
	item._pre_clear_seeds = nil
	-- 没有 PRE 快照就无法证明某掉落属于本次清房奖励，绝不替换旧掉落。
	if not pre then do_extra = true end

	if not do_extra then
		local candidates = {}
		for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, false, false)) do
			local pk = e:ToPickup()
			if pk and REPLACEABLE_CLEAN[pk.Variant] and not pk:IsShopItem()
				and pk.Variant ~= item.pickup.Variant
				and not pre[pk.InitSeed]
			then
				candidates[#candidates + 1] = pk
			end
		end
		if #candidates > 0 then
			local victim = candidates[rng:RandomInt(#candidates) + 1]
			spawn_pos = victim.Position
			victim:Remove()
		else
			do_extra = true
		end
	end
	if do_extra then
		spawn_pos = room:FindFreePickupSpawnPosition(room:GetCenterPos(), 10, true)
	end
	item.spawn_prototype(spawn_pos, id, {
		pool_type = pool_type,
		source = "clean",
		spawner = p0,
		exact_pos = not do_extra,
	})
end

-- 进房记录是否存在可清理敌人（禁止恒 true）
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		local room = Game():GetRoom()
		if not room then return end
		local key = room_unique_key()
		local rf = room_flag(key)
		if not rf then return end
		if not room:IsClear() and has_valid_clearable_enemies() then
			rf.had_valid_enemies = true
		end
	end,
})

-- 延迟生成的敌人也应把房间标为真实战斗房；仅在尚未记录时工作。
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_NPC_UPDATE,
	params = nil,
	Function = function(_, npc)
		if not npc or not npc:IsActiveEnemy(false)
			or npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
		then
			return
		end
		local room = Game():GetRoom()
		if not is_valid_prototype_clear_room(room) then return end
		local rf = room_flag(room_unique_key())
		if rf then rf.had_valid_enemies = true end
	end,
})

if ModCallbacks.MC_PRE_ROOM_TRIGGER_CLEAR then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_ROOM_TRIGGER_CLEAR,
		params = nil,
		Function = function(_, silent)
			local room = Game():GetRoom()
			if not is_valid_prototype_clear_room(room) then
				item._pre_clear_seeds = nil
				return
			end
			item._pre_clear_seeds = snapshot_pickup_seeds()
		end,
	})
end

if ModCallbacks.MC_POST_ROOM_TRIGGER_CLEAR then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_ROOM_TRIGGER_CLEAR,
		params = nil,
		Function = function(_, silent)
			process_clean_prototype({})
		end,
	})
else
	-- 无 RGON 时降级：无法安全做差集替换，只额外生成
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD,
		params = nil,
		Function = function(_, rng, pos)
			process_clean_prototype({force_extra = true})
		end,
	})
end

-- ---------- 天使 / 恶魔 / 商店首次进房 ----------
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		local room = Game():GetRoom()
		local level = Game():GetLevel()
		if not room or not level then return end
		if not room:IsFirstVisit() then return end
		if not any_player_owns_blueprint() then return end
		local rt = room:GetType()
		local meta = root_meta()
		if not meta then return end
		local fk = floor_key()
		if rt == RoomType.ROOM_ANGEL or rt == RoomType.ROOM_DEVIL then
			if meta.deal_prototype_floor == fk then return end
			local rng = RNG()
			rng:SetSeed(room:GetSpawnSeed(), 35)
			if rt == RoomType.ROOM_ANGEL then
				-- 天使/恶魔：禁止 Treasure/全表回退，只抽本池合格材料
				local id = select(1, item.roll_collectible(ItemPoolType.POOL_ANGEL, rng, false))
				if id then
					item.spawn_prototype(room:GetCenterPos() + Vector(80, 0), id, {
						pool_type = ItemPoolType.POOL_ANGEL,
						source = "angel",
					})
					meta.deal_prototype_floor = fk
				end
			else
				local id = select(1, item.roll_collectible(ItemPoolType.POOL_DEVIL, rng, false))
				if id then
					item.spawn_prototype(room:GetCenterPos() + Vector(80, 0), id, {
						pool_type = ItemPoolType.POOL_DEVIL,
						source = "devil",
						devil = true,
						devil_spike = true,
					})
					meta.deal_prototype_floor = fk
				end
			end
		elseif rt == RoomType.ROOM_SHOP then
			-- 首次生成商店 12.5%；Restock 再出原型在 schedule_shop_restock 里用 6.25%
			local desc = level:GetCurrentRoomDesc()
			local list_idx = desc and desc.ListIndex or -1
			local seen_key = tostring(list_idx)
			if meta.shop_proto_rooms[seen_key] then return end
			local rng = RNG()
			rng:SetSeed(room:GetSpawnSeed(), 41)
			meta.shop_proto_rooms[seen_key] = true -- 标记已判定，避免重进房再 roll
			if rng:RandomFloat() >= SHOP_FIRST_CHANCE then return end
			local slots = {}
			for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, false, false)) do
				local pk = e:ToPickup()
				if pk and pk:IsShopItem() and SHOP_CONSUMABLE[pk.Variant]
					and pk.Variant ~= PickupVariant.PICKUP_COLLECTIBLE
					and pk.Variant ~= item.pickup.Variant
				then
					slots[#slots + 1] = pk
				end
			end
			if #slots == 0 then return end
			local victim = slots[rng:RandomInt(#slots) + 1]
			local id = select(1, item.roll_collectible(ItemPoolType.POOL_SHOP, rng, true))
			if not id then return end
			local pos = victim.Position
			local shop_id = victim.ShopItemId
			victim:Remove()
			item.spawn_prototype(pos, id, {
				pool_type = ItemPoolType.POOL_SHOP,
				source = "shop",
				shop = true,
				shop_item_id = shop_id,
				exact_pos = true,
			})
		end
	end,
})

return item

-- Death Field use / materialize / absorb / activate
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local C = require("Qing_Remaster_scripts.cards.death_field.constants")
local state = require("Qing_Remaster_scripts.cards.death_field.state")
local layout = require("Qing_Remaster_scripts.cards.death_field.layout")
local proxy = require("Qing_Remaster_scripts.cards.death_field.proxy")
local visual = require("Qing_Remaster_scripts.cards.death_field.visual")
local charge = require("Qing_Remaster_scripts.cards.death_field.charge")
local trinkets = require("Qing_Remaster_scripts.cards.death_field.trinket_effects")
local pedestal_restore = require("Qing_Remaster_scripts.auxiliary.pedestal_restore")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local collectible_holder = require("Qing_Remaster_scripts.callbacks.collectible_holder")

local M = {}

local function poof(pos)
	local e1 = Isaac.Spawn(1000, 16, 2, pos, Vector.Zero, nil):ToEffect()
	if e1 then
		e1:GetSprite().Color = Color(0, 0, 0, 1)
	end
	local e2 = Isaac.Spawn(1000, 16, 1, pos, Vector.Zero, nil):ToEffect()
	if e2 then
		e2:GetSprite().Color = Color(0, 0, 0, 1)
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF, 1, 1, false, 0, 2)
end

local function fail_full(player, pos)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 1, 1, false, 0, 2)
	local fx = Isaac.Spawn(1000, EffectVariant.POOF01, 0, pos or player.Position, Vector.Zero, player):ToEffect()
	if fx then
		fx:GetSprite().Color = Color(1, 0.2, 0.2, 0.8)
	end
end

--- Restored owned simple pickup（饰品/卡/药）：直接 Idle，不播 Appear（非 NEW OFFER）
local function spawn_restored_simple_pickup(variant, subtype, pos)
	local q = Isaac.Spawn(
		EntityType.ENTITY_PICKUP,
		variant,
		subtype,
		pos,
		Vector.Zero,
		nil
	):ToPickup()
	if not q then
		return nil
	end
	local spr = q:GetSprite()
	if spr then
		spr:Play("Idle", true)
	end
	return q
end

function M.spawn_real_pickup(entry, pos)
	local room = Game():GetRoom()
	pos = room:FindFreePickupSpawnPosition(pos or room:GetCenterPos(), 0, true)
	if entry.kind == "active" then
		local main = entry.charge or 0
		local battery = entry.battery_charge or 0
		return pedestal_restore.spawn_owned_collectible(
			C.OWN_KEY,
			{
				collectible_id = entry.collectible_id,
				touched = entry.pickup_touched == true,
				charge = main + battery,
			},
			pos,
			nil,
			function(q)
				local d2 = q:GetData()
				d2._Data = d2._Data or {}
				d2._Data[C.OWN_KEY] = {
					slot = entry.original_slot or ActiveSlot.SLOT_PRIMARY,
					colid = entry.collectible_id,
					charge = main,
					battery_charge = battery,
					max_charge = entry.max_charge,
					touched = entry.pickup_touched == true,
				}
				consistance_holder.try_hold_entity(q, C.OWN_KEY, {ignore_subtype = true})
			end
		)
	end
	if entry.kind == "trinket" then
		local tid = trinkets.compose_trinket_id(entry.trinket_id, entry.golden)
		return spawn_restored_simple_pickup(PickupVariant.PICKUP_TRINKET, tid, pos)
	end
	if entry.kind == "card" then
		return spawn_restored_simple_pickup(PickupVariant.PICKUP_TAROTCARD, entry.card_id, pos)
	end
	if entry.kind == "pill" then
		return spawn_restored_simple_pickup(PickupVariant.PICKUP_PILL, entry.pill_color, pos)
	end
	return nil
end

function M.materialize_entry(player, uid, pos)
	local entry = state.find_entry(player, uid)
	if not entry then
		return false
	end
	local ent = proxy.get_proxy(player, uid)
	pos = pos or (ent and ent.Position) or player.Position
	-- 先改业务真相，再 evaluate（desired 中不再含该饰品）
	state.remove_entry(player, uid)
	proxy.remove_proxy(player, uid)
	if entry.kind == "trinket" then
		trinkets.refresh(player)
	end
	M.spawn_real_pickup(entry, pos)
	poof(pos)
	return true
end

function M.materialize_all(player)
	local f = state.get_field(player)
	if not f then
		return
	end
	local snapshot = {}
	for _, e in ipairs(f.entries) do
		local ent = proxy.get_proxy(player, e.uid)
		table.insert(snapshot, {
			entry = e,
			pos = (ent and ent.Position) or player.Position,
		})
	end
	-- state clear 必须在 evaluate 前，使 desired = {}
	state.clear_field(player)
	trinkets.refresh(player)
	proxy.remove_all_proxies(player)
	for _, row in ipairs(snapshot) do
		M.spawn_real_pickup(row.entry, row.pos)
	end
end

function M.end_field(player)
	if not state.is_active(player) then
		return
	end
	M.materialize_all(player)
	poof(player.Position)
	-- 兜底：清掉残留吸收高亮（主路径：identity 变化时 tick/render 当帧 restore）
	local interaction = require("Qing_Remaster_scripts.cards.death_field.interaction")
	if interaction.clear_all_absorb_visuals then
		interaction.clear_all_absorb_visuals()
	end
end

function M.charge_field_actives(player, amount)
	amount = amount or 1
	if amount <= 0 or not state.is_active(player) then
		return
	end
	local changed = false
	for e in state.iter_entries(player) do
		if e.kind == "active" then
			local maxc = charge.entry_max_charge(e)
			local _, ctype = charge.get_active_charge_info(e.collectible_id)
			-- 仅普通格充能；TIMED 由 tick_timed_charges 每逻辑帧 +1
			-- The Battery（COLLECTIBLE_BATTERY）才充黄色过充；非 Car Battery
			if maxc > 0 and ctype ~= ItemConfig.CHARGE_SPECIAL and ctype ~= ItemConfig.CHARGE_TIMED then
				local left = amount
				e.charge = e.charge or 0
				e.battery_charge = e.battery_charge or 0
				while left > 0 and e.charge < maxc do
					e.charge = e.charge + 1
					left = left - 1
					changed = true
					visual.note_charge_pulse(e)
				end
				if left > 0 and auxi.has_have_coll(player, CollectibleType.COLLECTIBLE_BATTERY) then
					while left > 0 and e.battery_charge < maxc do
						e.battery_charge = e.battery_charge + 1
						left = left - 1
						changed = true
						visual.note_charge_pulse(e)
					end
				end
			end
		end
	end
	if changed then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE, 1.2, 1, false, 0, 2)
	end
end

--- 离槽 timed 主动：本地计数（邻模组共识；不塞玩家槽骗引擎）
--- clock：MC_POST_UPDATE = 30 Hz → 每调用 +1，MaxCharges 即「满充所需逻辑帧」
function M.tick_timed_charges(player)
	if not state.is_active(player) then
		return
	end
	for e in state.iter_entries(player) do
		if e.kind == "active" then
			local maxc = charge.entry_max_charge(e)
			local _, ctype = charge.get_active_charge_info(e.collectible_id)
			if maxc > 0 and ctype == ItemConfig.CHARGE_TIMED then
				e.charge = math.min(maxc, (e.charge or 0) + 1)
			end
		end
	end
end

local function snapshot_returned_active_meta(pickup, meta)
	local id = tonumber(meta.colid) or (pickup and pickup.SubType)
	if not id or id <= 0 then
		return nil
	end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg or cfg.Type ~= ItemType.ITEM_ACTIVE then
		return nil
	end
	local slot = tonumber(meta.slot) or ActiveSlot.SLOT_PRIMARY
	local touched = meta.touched == true
	local maxc = tonumber(meta.max_charge)
	if not maxc or maxc <= 0 then
		maxc = select(1, charge.get_active_charge_info(id))
	end
	local main, battery
	if meta.battery_charge ~= nil then
		main = math.max(0, tonumber(meta.charge) or 0)
		battery = math.max(0, tonumber(meta.battery_charge) or 0)
	else
		main, battery = charge.split_total_charge(meta.charge or (pickup and pickup.Charge) or 0, maxc)
	end
	if maxc and maxc > 0 then
		main = math.min(main, maxc)
		battery = math.min(battery, maxc)
	end
	return {
		id = id,
		slot = slot,
		touched = touched,
		main = main,
		battery = battery,
	}
end

local function arm_primary_charge_restore(player, snap)
	player:GetData()[C.PENDING_PRIMARY_CHARGE_KEY] = {
		id = snap.id,
		main = snap.main,
		battery = snap.battery,
		frame = Game():GetFrameCount(),
	}
end

--- POST_GAIN_COLLECTIBLE：PRIMARY returned active 经 vanilla 入槽后，只修正充能。
function M.on_post_gain_returned_active(player, collectible_id)
	if not player then
		return
	end
	local d = player:GetData()
	local pend = d[C.PENDING_PRIMARY_CHARGE_KEY]
	if not pend or pend.id ~= collectible_id then
		return
	end
	d[C.PENDING_PRIMARY_CHARGE_KEY] = nil
	charge.restore_active_charge(player, ActiveSlot.SLOT_PRIMARY, pend.main, pend.battery)
end

function M.clear_pending_primary_charge(player)
	if player then
		player:GetData()[C.PENDING_PRIMARY_CHARGE_KEY] = nil
	end
end

--- PRE collision：
--- PRIMARY → 不消费，交给 vanilla；仅 arm 充能修正。
--- 非 PRIMARY → exact-slot adapter（vanilla 无法保证回副槽/口袋）。
--- 返回 true = 已消费碰撞，调用方应 return true 阻止 vanilla。
function M.try_collect_returned_active(player, pickup)
	if not player or not pickup then
		return false
	end
	if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		return false
	end
	if not auxi.will_collect_pickup(player, pickup) then
		return false
	end
	if not consistance_holder.try_check_entity(pickup, C.OWN_KEY) then
		return false
	end

	local d = pickup:GetData()
	local meta = d._Data and d._Data[C.OWN_KEY]
	if not meta or meta.slot == nil then
		return false
	end

	local snap = snapshot_returned_active_meta(pickup, meta)
	if not snap then
		return false
	end

	-- PRIMARY：原版拾取通路；Death Field 只保留充能修正
	if snap.slot == ActiveSlot.SLOT_PRIMARY then
		arm_primary_charge_restore(player, snap)
		return false
	end

	-- 非 PRIMARY：exact-slot simulated acquisition（Pickup，非 LiftItem）
	-- 先 grant，成功后才消费 pedestal（避免 Remove 后 Add 失败）
	local ok = collectible_holder.simulate_active_pickup(player, snap.id, {
		touched = snap.touched,
		slot = snap.slot,
		main_charge = snap.main,
		battery_charge = snap.battery,
	})
	if not ok then
		return false
	end

	d._Data[C.OWN_KEY] = nil
	consistance_holder.try_remove_entity(pickup, C.OWN_KEY)
	pickup:Remove()
	return true
end

function M.can_use_active(entry)
	if not entry or entry.kind ~= "active" then
		return false
	end
	local maxc = charge.entry_max_charge(entry)
	if maxc <= 0 then
		return true
	end
	-- Debug 8：仅运行时可用，不改 entry
	if charge.debug_infinite_charge() then
		return true
	end
	-- 主条满即可用；battery_charge 是 The Battery 额外层
	return (entry.charge or 0) >= maxc
end

--- Active / Card / Pill 当前能否用对应键激活（饰品不可「使用」，仅解除）
function M.can_activate(entry)
	if not entry then
		return false
	end
	if entry.kind == "active" then
		return M.can_use_active(entry)
	end
	if entry.kind == "card" or entry.kind == "pill" then
		return true
	end
	return false
end

function M.use_active(player, uid)
	local entry = state.find_entry(player, uid)
	if not entry or entry.kind ~= "active" then
		return false
	end
	if not M.can_use_active(entry) then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.8, 1, false, 0, 2)
		return false
	end
	local colid = entry.collectible_id
	local flags = 0
	local result = nil
	if player.UseActiveItem then
		-- 交给引擎处理 Car Battery 二次效果；Death Field 只扣一次充能
		result = player:UseActiveItem(colid, flags, -1, 0)
	end
	-- Debug 8：不改写真实 entry.charge / battery_charge
	if not charge.debug_infinite_charge() then
		charge.apply_active_use_charge(entry)
	end
	-- 一次性消耗类：尽量根据 REMOVE 旗标删掉 record
	local remove = false
	if type(result) == "number" and UseActiveItemResultFlag and UseActiveItemResultFlag.REMOVE then
		remove = (result & UseActiveItemResultFlag.REMOVE) ~= 0
	end
	local cfg = Isaac.GetItemConfig():GetCollectible(colid)
	if cfg and (cfg.MaxCharges or 0) <= 0 and cfg.Type == ItemType.ITEM_ACTIVE then
		-- 许多主动仍有 MaxCharges；保留 record 除非明确 REMOVE
	end
	if remove then
		state.remove_entry(player, uid)
		proxy.remove_proxy(player, uid)
	end
	return true
end

function M.use_card(player, uid)
	local entry = state.find_entry(player, uid)
	if not entry or entry.kind ~= "card" then
		return false
	end
	local card_id = entry.card_id
	state.remove_entry(player, uid)
	proxy.remove_proxy(player, uid)
	player:UseCard(card_id, 0)
	return true
end

-- Golden Pill = 14；Golden Horse Pill = 14 | PILL_GIANT_FLAG(2048)
-- entry 持久身份是 pill_color；普通药可缓存 pill_effect；金药丸 effect 仅 use-time 抽取
local GOLDEN_PILL_COLOR = (PillColor and PillColor.PILL_GOLD) or 14
local PILL_COLOR_MASK = (PillColor and PillColor.PILL_COLOR_MASK)
	or (((PillColor and PillColor.PILL_GIANT_FLAG) or (1 << 11)) - 1)
local GOLDEN_PILL_REMOVE_CHANCE = 0.10
local GOLDEN_CONSUME_SHIFT = 35

local function is_golden_pill_color(color)
	color = tonumber(color) or 0
	local base = color & PILL_COLOR_MASK
	return base == GOLDEN_PILL_COLOR
end

local function mix_u32(seed, salt)
	seed = ((tonumber(seed) or 1) + (tonumber(salt) or 0)) % 4294967296
	seed = seed ~ math.floor(seed / 65536)
	seed = (seed * 2127912214) % 4294967296
	seed = seed ~ math.floor(seed / 32768)
	if seed == 0 then
		seed = 1
	end
	return seed
end

--- 金药丸消耗流：状态写在 entry.golden_use_seed，每次推进（与药效抽取分离）
local function ensure_golden_consume_seed(entry, player)
	local cur = tonumber(entry.golden_use_seed)
	if cur and cur ~= 0 then
		return cur
	end
	local base = (player and player.InitSeed) or Random()
	local salt = ((entry.uid or 0) * 97) + ((tonumber(entry.pill_color) or GOLDEN_PILL_COLOR) * 131)
	entry.golden_use_seed = mix_u32(base, salt)
	return entry.golden_use_seed
end

local function roll_golden_pill_consume(entry, player)
	local seed = ensure_golden_consume_seed(entry, player)
	local rng = RNG()
	rng:SetSeed(seed, GOLDEN_CONSUME_SHIFT)
	local roll = rng:RandomFloat()
	-- RandomFloat 已 Next；写回当前 seed 供下次使用
	entry.golden_use_seed = rng:GetSeed()
	if entry.golden_use_seed == 0 then
		entry.golden_use_seed = 1
	end
	return roll < GOLDEN_PILL_REMOVE_CHANCE
end

local function capture_pill_fields(player, color)
	color = tonumber(color) or 0
	if is_golden_pill_color(color) then
		return {
			pill_color = color,
			pill_effect = nil,
			golden_use_seed = mix_u32(
				(player and player.InitSeed) or Random(),
				color * 131 + Game():GetFrameCount()
			),
		}
	end
	return {
		pill_color = color,
		pill_effect = Game():GetItemPool():GetPillEffect(color, player),
	}
end

--- 使用一份 pill 业务数据；不碰 Death Field state。返回是否消耗。
local function execute_pill_entry(player, entry)
	if not player or not entry or entry.kind ~= "pill" then
		return false
	end
	local color = entry.pill_color
	local golden = is_golden_pill_color(color)

	local effect
	if golden then
		-- 每次重抽；禁止复用缓存的 pill_effect
		effect = Game():GetItemPool():GetPillEffect(color, player)
		entry.pill_effect = nil
	else
		effect = entry.pill_effect
		if effect == nil then
			effect = Game():GetItemPool():GetPillEffect(color, player)
			entry.pill_effect = effect
		end
	end

	if player.UsePill then
		player:UsePill(effect, color, 0)
	end

	local consumed = true
	if golden then
		consumed = roll_golden_pill_consume(entry, player)
	end
	return consumed
end

function M.use_pill(player, uid)
	local entry = state.find_entry(player, uid)
	if not entry or entry.kind ~= "pill" then
		return false
	end
	local consumed = execute_pill_entry(player, entry)
	if consumed then
		state.remove_entry(player, uid)
		proxy.remove_proxy(player, uid)
	end
	return true
end

local function pickup_kind(pickup)
	if not pickup then
		return nil
	end
	local v = pickup.Variant
	if v == PickupVariant.PICKUP_COLLECTIBLE then
		local cfg = Isaac.GetItemConfig():GetCollectible(pickup.SubType)
		if cfg and cfg.Type == ItemType.ITEM_ACTIVE then
			return "active"
		end
		return nil
	end
	if v == PickupVariant.PICKUP_TRINKET then
		return "trinket"
	end
	if v == PickupVariant.PICKUP_TAROTCARD then
		return "card"
	end
	if v == PickupVariant.PICKUP_PILL then
		return "pill"
	end
	return nil
end

function M.is_absorbable_pickup(pickup)
	return pickup_kind(pickup) ~= nil
end

function M.get_absorb_kind(pickup)
	return pickup_kind(pickup)
end

--- 取得地上 pickup 的事务：capture / Options / 支付 / Remove。不写 Death Field entry。
local function acquire_absorb_pickup(player, pickup)
	if not auxi.check_all_exists(pickup) then
		return nil
	end
	local kind = pickup_kind(pickup)
	if not kind then
		return nil
	end

	local original_pos = Vector(pickup.Position.X, pickup.Position.Y)

	-- 商店 / 恶魔价：付得起才取得，并走统一支付
	local price = pickup.Price or 0
	if price ~= 0 then
		if not auxi.can_afford_pickup(player, pickup) then
			fail_full(player, pickup.Position)
			return nil
		end
	end

	-- Capture（任何支付 / Options / Remove 之前）
	local entry = {kind = kind}
	if kind == "active" then
		entry.collectible_id = pickup.SubType
		local st = charge.read_pickup_state(pickup, entry.collectible_id)
		entry.charge = st.charge
		entry.battery_charge = st.battery_charge
		entry.pickup_touched = st.touched == true
		entry.original_slot = st.original_slot or ActiveSlot.SLOT_PRIMARY
		if type(st.max_charge) == "number" and st.max_charge > 0 then
			entry.max_charge = st.max_charge
		end
	elseif kind == "trinket" then
		local base, golden = trinkets.split_trinket_id(pickup.SubType)
		entry.trinket_id = base
		entry.golden = golden
		entry.multiplier = 1
	elseif kind == "card" then
		entry.card_id = pickup.SubType
	elseif kind == "pill" then
		local fields = capture_pill_fields(player, pickup.SubType)
		entry.pill_color = fields.pill_color
		entry.pill_effect = fields.pill_effect
		entry.golden_use_seed = fields.golden_use_seed
	end

	-- Options：程序化取得等价于选中该成员
	if (pickup.OptionsPickupIndex or 0) ~= 0 then
		option_index_holder.commit_selection(pickup, player, {
			source = C.OWN_KEY,
			skip_will_collect = true,
			remove_siblings = true,
		})
	end

	if price ~= 0 then
		auxi.buy_a_pickup(pickup, player, {no_remove = true, NoAnim = true})
	end

	pickup:Remove()
	return {
		entry = entry,
		kind = kind,
		original_pos = original_pos,
	}
end

function M.try_absorb_pickup(player, pickup, opts)
	opts = type(opts) == "table" and opts or {}
	local spawn_proxy = opts.spawn_proxy ~= false
	local do_poof = opts.poof ~= false
	if not state.is_active(player) then
		return false
	end
	if not auxi.check_all_exists(pickup) then
		return false
	end
	local kind = pickup_kind(pickup)
	if not kind then
		return false
	end
	if not state.has_room(player) then
		fail_full(player, pickup.Position)
		return false
	end

	local tx = acquire_absorb_pickup(player, pickup)
	if not tx then
		return false
	end

	local placed = {}
	proxy.for_each_proxy(player, function(_, ent)
		placed[#placed + 1] = ent.Position
	end)
	local pos = layout.find_safe_deterministic(tx.original_pos, placed)
	state.update_norm_from_world(tx.entry, pos)

	local added = state.add_entry(player, tx.entry)
	if not added then
		fail_full(player, tx.original_pos)
		M.spawn_real_pickup(tx.entry, tx.original_pos)
		return false
	end

	if spawn_proxy then
		proxy.spawn_proxy(player, added, pos)
	end
	if kind == "trinket" then
		trinkets.refresh(player)
	end
	if do_poof then
		poof(pos)
	end
	return added
end

--- Card/Pill: 取得事务后立即使用，不进 Death Field；未消耗则原位 rematerialize。
function M.try_absorb_and_use_pickup(player, pickup)
	if not auxi.check_all_exists(pickup) then
		return false
	end
	local kind = pickup_kind(pickup)
	if kind ~= "card" and kind ~= "pill" then
		return false
	end
	local tx = acquire_absorb_pickup(player, pickup)
	if not tx then
		return false
	end
	if kind == "card" then
		player:UseCard(tx.entry.card_id, 0)
		return true
	end
	local consumed = execute_pill_entry(player, tx.entry)
	if not consumed then
		M.spawn_real_pickup(tx.entry, tx.original_pos)
	end
	return true
end

local function read_active_entry(player, slot)
	local colid = player:GetActiveItem(slot)
	if not colid or colid == 0 then
		return nil
	end
	local maxc = select(1, charge.get_active_charge_info(colid))
	if player.GetActiveMaxCharge then
		local m = player:GetActiveMaxCharge(slot)
		if type(m) == "number" and m > 0 then
			maxc = m
		end
	end
	return {
		kind = "active",
		collectible_id = colid,
		charge = player:GetActiveCharge(slot) or 0,
		battery_charge = player:GetBatteryCharge(slot) or 0,
		max_charge = maxc,
		original_slot = slot,
		pickup_touched = true,
	}
end

local function read_trinket_entry(player, slot)
	local raw = player:GetTrinket(slot)
	if not raw or raw == 0 then
		return nil
	end
	local base, golden = trinkets.split_trinket_id(raw)
	return {
		kind = "trinket",
		trinket_id = base,
		golden = golden,
		multiplier = 1,
	}
end

local function read_card_entry(player, slot)
	local id = player:GetCard(slot)
	if not id or id == 0 then
		return nil
	end
	return {kind = "card", card_id = id}
end

local function read_pill_entry(player, slot)
	local color = player:GetPill(slot)
	if not color or color == 0 then
		return nil
	end
	local fields = capture_pill_fields(player, color)
	return {
		kind = "pill",
		pill_color = fields.pill_color,
		pill_effect = fields.pill_effect,
		golden_use_seed = fields.golden_use_seed,
	}
end

--- 从玩家槽位卸下资源进入场；超出 max 的掉地上
function M.activate_from_player(player, opts)
	opts = opts or {}
	local max_slots = opts.cloth and C.MAX_FIELD_SLOTS_CLOTH or C.MAX_FIELD_SLOTS
	state.create_field(player, {max_slots = max_slots, cloth = opts.cloth == true})

	local queue = {}
	-- 优先级：active > pocket(card/pill) > trinket
	local function queue_active(slot)
		local e = read_active_entry(player, slot)
		if not e then
			return
		end
		table.insert(queue, {
			entry = e,
			remove = function()
				if player.RemoveCollectible then
					player:RemoveCollectible(e.collectible_id, false, slot, true)
				end
			end,
		})
	end
	queue_active(ActiveSlot.SLOT_PRIMARY)
	queue_active(ActiveSlot.SLOT_SECONDARY)
	queue_active(ActiveSlot.SLOT_POCKET)
	if ActiveSlot.SLOT_POCKET2 then
		queue_active(ActiveSlot.SLOT_POCKET2)
	end
	for slot = 0, 1 do
		local e = read_card_entry(player, slot)
		if e then
			local s = slot
			table.insert(queue, {
				entry = e,
				remove = function()
					player:SetCard(s, 0)
				end,
			})
		else
			local p = read_pill_entry(player, slot)
			if p then
				local s = slot
				table.insert(queue, {
					entry = p,
					remove = function()
						player:SetPill(s, 0)
					end,
				})
			end
		end
	end
	for slot = 0, 1 do
		local e = read_trinket_entry(player, slot)
		if e then
			table.insert(queue, {
				entry = e,
				remove = function()
					player:TryRemoveTrinket(trinkets.compose_trinket_id(e.trinket_id, e.golden))
				end,
			})
		end
	end

	local rng = player:GetCardRNG(C.ENTITY)
	if auxi.rng_for_sake then
		rng = auxi.rng_for_sake(rng)
	end
	local norms = layout.init_around_player(player, math.min(#queue, max_slots))
	local ni = 1
	local overflow = {}

	for _, item in ipairs(queue) do
		item.remove()
		if state.entry_count(player) < max_slots then
			local n = norms[ni] or {norm_x = 0.5, norm_y = 0.5}
			ni = ni + 1
			item.entry.norm_x = n.norm_x
			item.entry.norm_y = n.norm_y
			state.add_entry(player, item.entry)
		else
			table.insert(overflow, item.entry)
		end
	end

	local room = Game():GetRoom()
	for _, e in ipairs(overflow) do
		local pos = room:FindFreePickupSpawnPosition(player.Position, 0, true)
		M.spawn_real_pickup(e, pos)
	end

	proxy.rebuild_room(player, rng)
	trinkets.refresh(player)
	poof(player.Position)
	-- 隔断打出死神卡的同一次按键（ITEM / PILLCARD / DROP）
	player:GetData()[C.INPUT_GUARD_KEY] = Isaac.GetFrameCount() + (C.INPUT_GUARD_FRAMES or 4)
end

return M

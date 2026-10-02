local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local grid_wall = require("Qing_Remaster_scripts.grids.grid_wall")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")
local morph_txn = require("Qing_Remaster_scripts.others.Pickup_Morph_Transaction_holder")

local PRICE_SPIKES = (PickupPrice and PickupPrice.PRICE_SPIKES) or -5
local PRICE_ONE_HEART = (PickupPrice and PickupPrice.PRICE_ONE_HEART) or -1

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	pre_myToCall = {},
	myToCall = {},
	entity = enums.Cards.Devil_r,
	own_key = "Thoth_cd15r_Dev_",
	own_key2 = "Thoth_cd15r_Dev2_",
}

local RECORD_KEY = item.own_key .. "record"
local REROLL_PENDING_KEY = item.own_key .. "reroll_pending"
local TRADE_EFFECT_KEY = item.own_key .. "effect"
local REAL_SATAN_KEY = item.own_key .. "real_satan"
local SPAWN_REQUEST_KEY = item.own_key .. "spawn_request"

-- Runtime-only trade pickup index (not save.elses). Leave-room owns entity teardown.
local active_trade_pickups = {}

local function get_original_subtype(ent)
	if not ent then
		return nil
	end
	local d = ent:GetData()
	local data = d._Data and d._Data[item.own_key2]
	return data and data[RECORD_KEY] or nil
end

local function unregister_trade_seed(ent_or_seed, reason)
	local seed = ent_or_seed
	if type(ent_or_seed) ~= "number" then
		seed = ent_or_seed and ent_or_seed.InitSeed or nil
	end
	if seed == nil then
		return
	end
	if active_trade_pickups[seed] ~= nil then
		active_trade_pickups[seed] = nil
	end
end

local function clear_trade_tracking(ent, reason)
	if not ent then
		return
	end
	local original = get_original_subtype(ent)
	if original ~= nil then
		consistance_holder.try_remove_entity(ent, item.own_key, {record_subtype = original})
	else
		consistance_holder.try_remove_entity(ent, item.own_key)
	end
	consistance_holder.try_remove_entity(ent, item.own_key2)
	local d = ent:GetData()
	if d._Data and d._Data[item.own_key2] then
		d._Data[item.own_key2][RECORD_KEY] = nil
	end
	d[REROLL_PENDING_KEY] = nil
	unregister_trade_seed(ent, reason)
end

--- Unified trade pickup teardown (Morph / exit / purchase / robbery).
local function remove_trade_pickup(pickup, reason)
	if not pickup then
		return false
	end
	local ent = pickup.ToPickup and pickup:ToPickup() or pickup
	if not ent then
		return false
	end
	local seed = ent.InitSeed
	clear_trade_tracking(ent, reason or "remove")
	unregister_trade_seed(seed, reason or "remove")
	if ent.Exists and ent:Exists() then
		ent:Remove()
	end
	return true
end

-- Blueprint-style fixed shop quote: identity + freeze, then price_holder capture.
local function register_trade_pickup(q, price)
	if not q then
		return nil
	end
	q = q:ToPickup() or q
	q.ShopItemId = -1
	q.AutoUpdatePrice = false
	q.Price = price
	price_holder.catch_price_over(q)

	consistance_holder.try_hold_over_entity(q, item.own_key2)
	local d = q:GetData()
	d._Data[item.own_key2][RECORD_KEY] = q.SubType

	-- one_room: Consistance record only.
	-- Entity teardown awaits confirmed MC_PRE_ROOM_EXIT (probe this round; no PRE_NEW_ROOM Remove).
	consistance_holder.try_hold_entity(q, item.own_key, {
		one_room = true,
	})
	consistance_holder.try_hold_entity(q, item.own_key2, {
		one_room = true,
		ignore_subtype = true,
	})

	active_trade_pickups[q.InitSeed] = {
		type = q.Type,
		variant = q.Variant,
		subtype = q.SubType,
	}
	return q
end

--- Read-only ritual / trade index for diagnostics.
function item.get_debug_snapshot()
	local trade_effect = nil
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		local d = ent:GetData()
		if d[TRADE_EFFECT_KEY] then
			local spr = ent.GetSprite and ent:GetSprite()
			trade_effect = {
				ptr = GetPtrHash(ent),
				init_seed = ent.InitSeed,
				type = ent.Type,
				variant = ent.Variant,
				x = ent.Position.X,
				y = ent.Position.Y,
				animation = spr and spr:GetAnimation() or nil,
				anim_frame = spr and spr:GetFrame() or nil,
			}
			break
		end
	end
	local list = {}
	for seed, meta in pairs(active_trade_pickups) do
		list[#list + 1] = {
			init_seed = seed,
			type = meta.type,
			variant = meta.variant,
			subtype = meta.subtype,
		}
	end
	return {
		trade_effect = trade_effect,
		active_trade_pickups = list,
		active_count = #list,
	}
end

--- Read-only per-pickup trade identity for diagnostics.
function item.get_trade_debug_snapshot(ent)
	if not ent then
		return {tracked = false}
	end
	local pickup = ent.ToPickup and ent:ToPickup() or ent
	local seed = pickup.InitSeed
	return {
		tracked = active_trade_pickups[seed] ~= nil,
		init_seed = seed,
		ptr = GetPtrHash(pickup),
		type = pickup.Type,
		variant = pickup.Variant,
		subtype = pickup.SubType,
		original_subtype = get_original_subtype(pickup),
		reroll_pending = pickup:GetData()[REROLL_PENDING_KEY] == true,
		own_key = consistance_holder.try_check_entity(pickup, item.own_key) == true,
		own_key2 = consistance_holder.try_check_entity(pickup, item.own_key2) == true,
		touched = pickup.Touched == true,
		exists = pickup:Exists(),
	}
end

item.buff_info = {
	[1] = {
		work = function(pos, ent, info, card_item)
			local q = Isaac.Spawn(5, 0, 1, pos, Vector(0, 0), nil):ToPickup()
			return register_trade_pickup(q, PRICE_SPIKES)
		end,
		weigh = 10,
	},
	[2] = {
		work = function(pos, ent, info, card_item)
			local q = Isaac.Spawn(5, 100, 0, pos, Vector(0, 0), nil):ToPickup()
			return register_trade_pickup(q, PRICE_ONE_HEART)
		end,
		weigh = 10,
	},
	[3] = {
		work = function(pos, ent, info, card_item)
			local rng = ent:GetDropRNG()
			local colid = Game():GetItemPool():GetCollectible(3, true, rng:GetSeed())
			local q = Isaac.Spawn(5, 100, colid, pos, Vector(0, 0), nil):ToPickup()
			return register_trade_pickup(q, PRICE_ONE_HEART)
		end,
		weigh = 10,
	},
}

table.insert(item.pre_myToCall, #item.pre_myToCall + 1, {
	CallBack = enums.Callbacks.PRE_CHECK_PRICE,
	params = nil,
	Function = function(_, ent, val)
		local succ = consistance_holder.try_check_entity(ent, item.own_key2)
		if succ then
			return auxi.get_acceptible_devil_price(ent)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE,
	params = nil,
	Function = function(_, ent)
		local d = ent:GetData()
		local succ = consistance_holder.try_check_entity(ent, item.own_key2)
		if not succ then
			return
		end

		local purchased = ent.Touched == true
		-- Morph/reroll teardown is owned by morph_txn on_post (remove target).
		-- Legacy reroll_pending only covers residual same-seed cases.
		if d[REROLL_PENDING_KEY] == true then
			remove_trade_pickup(ent, "reroll_pending")
			return
		end
		if purchased then
			clear_trade_tracking(ent, "purchased")
		end
	end,
})

-- External Morph of a trade pickup → remove POST target (pairing via morph_txn).
morph_txn.register("DevilReversedTrade", {
	priority = 10,
	match_pre = function(pickup)
		return consistance_holder.try_check_entity(pickup, item.own_key2) == true
	end,
	capture = function(pickup)
		return {
			old_seed = pickup.InitSeed,
			original_subtype = get_original_subtype(pickup),
		}
	end,
	on_post = function(txn)
		local target = txn.target
		local snap = txn.source_snapshot or {}
		if snap.old_seed ~= nil then
			unregister_trade_seed(snap.old_seed, "morph_pre_seed")
		end
		if target and target:Exists() then
			remove_trade_pickup(target, "morph_" .. tostring(txn.kind or "post"))
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		if not continue then
			save.elses[item.own_key .. "effect"] = {}
			active_trade_pickups = {}
		end
	end,
})

-- Drop runtime trade index on room change only (no entity Remove here).
-- Explicit Remove must wait for confirmed MC_PRE_ROOM_EXIT timing via probe.
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	params = nil,
	Function = function()
		active_trade_pickups = {}
	end,
})

table.insert(item.post_ToCall, #item.post_ToCall + 1, {
	CallBack = ModCallbacks.MC_EVALUATE_CACHE,
	params = nil,
	Function = function(_, player, cacheFlag)
		local d = player:GetData()
		local idx = d.__Index
		if idx ~= nil then
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
	params = 6,
	Function = function(_, ent)
		local d = ent:GetData()
		local s = ent:GetSprite()
		local room = Game():GetRoom()
		if not d[item.own_key .. "effect"] then
			return
		end

		if s:IsPlaying("SmallIdle") and s:IsEventTriggered("Drop") then
			local q = auxi.fire_nil(ent.Position + Vector(0, -100), Vector(0, 0), {cooldown = 9999999})
			q.PositionOffset = Vector(0, 100)
			local qs = q:GetSprite()
			qs:Load("gfx/cards/cd15r_devil_pentagram.anm2", true)
			qs:Play("Appear", true)
			local d2 = q:GetData()
			d2.nil_mode = "card_15r_devil"
			d2[item.own_key .. "effect"] = true

			local rng = ent:GetDropRNG()
			local cnt = 2 + rng:RandomInt(2)
			if d[item.own_key .. "effect2"] then
				cnt = 4 + rng:RandomInt(2)
			end
			local spawn_pos = ent.Position + Vector(0, 40) + Vector(-cnt * 0.5 * 40, 0)
			unique_holder.try_spawn_shop_item()
			d[item.own_key .. "table"] = {}
			for i = 1, cnt do
				local pos = spawn_pos + Vector(40, 0) * (i - 0.5)
				local tbl = auxi.deepCopy(item.buff_info)
				local ret = auxi.random_in_weighed_table(tbl, rng)
				local pickup = ret.work(pos, ent, ret, item)
				table.insert(d[item.own_key .. "table"], #d[item.own_key .. "table"] + 1, {ent = pickup})
			end
			d[item.own_key .. "pentagram"] = q
		end

		if d[item.own_key .. "table"] then
			for i = #d[item.own_key .. "table"], 1, -1 do
				local v = d[item.own_key .. "table"][i]
				if v.ent:Exists() == false or consistance_holder.try_check_entity(v.ent, item.own_key2) ~= true then
					s:Play("SmallHappy")
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_GROW, 1, 1, false, 0, 2)
					table.remove(d[item.own_key .. "table"], i)
				end
			end
			if #d[item.own_key .. "table"] == 0 then
				d[item.own_key .. "table"] = nil
				s:Play("SmallLeave", true)
			end
		end

		if s:IsFinished("SmallLeave") then
			ent:Remove()
			return
		end
		if s:IsFinished("SmallIdle") then
			s:Play("Idle", true)
		end
		if s:IsFinished("SmallHappy") then
			s:Play("Idle", true)
		end

		if s:IsFinished("Idle") or s:IsPlaying("Idle") or s:IsPlaying("SmallHappy") then
			local succ = auxi.check_explosion(ent)
			if succ then
				MusicManager():Play(Music.MUSIC_SATAN_BOSS, Options.MusicVolume)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_GROW, 1, 1, false, 0, 2)
				if d[item.own_key .. "pentagram"] and d[item.own_key .. "pentagram"]:Exists() then
					d[item.own_key .. "pentagram"]:GetSprite():Play("DisAppear", true)
				end

				-- Baseline cfc0a635: spawn offset -80 + 300 manual Update(); no State=3.
				local satan_pos = ent.Position + Vector(0, -80)
				local q = Isaac.Spawn(EntityType.ENTITY_SATAN, 0, 0, satan_pos, Vector(0, 0), nil):ToNPC()
				local d2 = q:GetData()
				d2[REAL_SATAN_KEY] = true
				d2[SPAWN_REQUEST_KEY] = {x = satan_pos.X, y = satan_pos.Y}
				for _ = 1, 300 do
					q:Update()
				end
				for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
					local door = room:GetDoor(slot)
					if door then
						door:Close()
					end
				end

				d2[item.own_key .. "table"] = {}
				for _, v in pairs(d[item.own_key .. "table"] or {}) do
					local q2 = v.ent and v.ent:ToPickup()
					if q2 and q2:Exists() and q2.Touched ~= true then
						local original = get_original_subtype(q2)
						local rerolled = original ~= nil and q2.SubType ~= original
						if not rerolled then
							table.insert(d2[item.own_key .. "table"], #d2[item.own_key .. "table"] + 1, {
								vr = q2.Variant,
								st = q2.SubType,
							})
						end
						clear_trade_tracking(q2, "robbery_snapshot")
						q2:Remove()
					elseif q2 and q2:Exists() then
						clear_trade_tracking(q2, "robbery_clear")
						q2:Remove()
					end
				end
				ent:Remove()
				return
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_NPC_UPDATE,
	params = 84,
	Function = function(_, ent)
		local d = ent:GetData()
		local s = ent:GetSprite()
		local room = Game():GetRoom()
		if s:GetAnimation() == "Death" and s:GetFrame() == 29 then
			if d[item.own_key .. "table"] then
				for _, v in pairs(d[item.own_key .. "table"]) do
					local q = Isaac.Spawn(
						5,
						v.vr,
						v.st,
						room:FindFreePickupSpawnPosition(ent.Position, 10, true),
						Vector(0, 0),
						nil
					):ToPickup()
					q:Morph(5, v.vr, v.st, true, true, true)
					q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
					-- Free robbery loot: not a trade registration.
					q.ShopItemId = -1
					q.AutoUpdatePrice = false
					q.Price = 0
				end
				d[item.own_key .. "table"] = nil
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = item.entity,
	Function = function(_, cardtype, player, useFlags)
		local room = Game():GetRoom()
		local d = player:GetData()
		local rng = player:GetCardRNG(item.entity)
		rng = auxi.rng_for_sake(rng)

		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			return
		end

		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_APPEAR, 1, 1, false, 0, 2)
		grid_wall.ChangeRoomGfx({Backdrops = BackdropType.SHEOL})
		local q = Isaac.Spawn(
			1000,
			6,
			0,
			room:FindFreeTilePosition(player.Position + Vector(0, -80), 10),
			Vector(0, 0),
			nil
		):ToEffect()
		local s = q:GetSprite()
		s:Load("gfx/cards/cd15r_devil_satan.anm2", true)
		s:Play("SmallIdle", true)
		local effect_data = q:GetData()
		effect_data[item.own_key .. "effect"] = true
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			effect_data[item.own_key .. "effect2"] = true
		end
	end,
})

Nil_holder.register("card_15r_devil", {
	detect = function(d)
		return d[item.own_key .. "effect"]
	end,
	update = function(ent, d, s)
		if s:IsFinished("Appear") then
			s:Play("Idle", true)
		end
		if s:IsFinished("DisAppear") then
			ent:Remove()
			return
		end
	end,
})

return item

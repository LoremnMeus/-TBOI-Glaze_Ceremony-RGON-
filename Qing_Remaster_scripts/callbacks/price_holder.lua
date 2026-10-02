local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Assemble_holder = require("Qing_Remaster_scripts.others.Assemble_holder")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Price_holder_",
	move_price_basic = {
		["mx_heart"] = true,
		["gd_heart"] = true,
		["sl_heart"] = true,
		["bn_heart"] = true,
	},
}

Assemble_holder.register_on(item.own_key, item, {force = true})

local QUOTE_UNRESOLVED = "unresolved"
local QUOTE_RESOLVED = "resolved"

-- Runtime-only: next-frame native Price setter re-entry after FINALIZE writeback.
-- See codex_work/notes/price_holder_native_refresh_timing.md
local PRICE_VISUAL_COMMIT_KEY = item.own_key .. "native_visual_commit"

local function ensure_record(ent)
	if not ent then return nil end
	local d = ent:GetData()
	d._Data = d._Data or {}
	d._Data[item.own_key] = d._Data[item.own_key] or {}
	return d._Data[item.own_key]
end

local function get_record(ent)
	if not ent then return nil end
	local d = ent:GetData()
	local rec = d and d._Data and d._Data[item.own_key]
	return rec
end

local function bump_revision(rec)
	rec.revision = (tonumber(rec.revision) or 0) + 1
	return rec.revision
end

--- INVALIDATE→NATIVE REPRICE→FINALIZE 之后：下一帧 Price=Price 触发 native presentation commit。
--- 不是重新算价；同帧执行无效（须 due_frame >= current+1）。
--- 见 codex_work/notes/price_holder_native_refresh_timing.md
local function schedule_native_price_visual_commit(ent)
	if not ent then
		return
	end
	local d = ent:GetData()
	if not d then
		return
	end
	d[PRICE_VISUAL_COMMIT_KEY] = {
		due_frame = Game():GetFrameCount() + 1,
		expected_price = ent.Price,
	}
end

local function clear_native_price_visual_commit(ent)
	if not ent then
		return
	end
	local d = ent:GetData()
	if d then
		d[PRICE_VISUAL_COMMIT_KEY] = nil
	end
end

--- 下一稳定帧：相同数值再经 Price setter，刷新 native price sprite。
--- 禁止每帧执行；禁止对 Price==0 / 已失效实体执行；新 refresh 覆盖旧 pending。
local function try_commit_native_price_visual(ent)
	if not ent then
		return false
	end
	local d = ent:GetData()
	local pending = d and d[PRICE_VISUAL_COMMIT_KEY]
	if not pending then
		return false
	end
	if Game():GetFrameCount() < (pending.due_frame or 0) then
		return false
	end
	-- 等待期间价格又变：旧 commit 失效，等新的 FINALIZE 重新 schedule。
	if ent.Price ~= pending.expected_price then
		d[PRICE_VISUAL_COMMIT_KEY] = nil
		return false
	end
	local exists_ok, exists = pcall(function()
		return ent:Exists()
	end)
	if not exists_ok or not exists or ent.Price == 0 then
		d[PRICE_VISUAL_COMMIT_KEY] = nil
		return false
	end
	d[PRICE_VISUAL_COMMIT_KEY] = nil
	-- Intentional: re-enter Isaac Price setter after final quote is stable.
	-- Do not "optimize away" Price = Price — probe P1 confirmed it restores native sprites.
	local price = ent.Price
	ent.Price = price
	return true
end

function item.get_pending_visual_commit(ent)
	if not ent then
		return nil
	end
	local d = ent:GetData()
	local pending = d and d[PRICE_VISUAL_COMMIT_KEY]
	if type(pending) ~= "table" then
		return nil
	end
	return {
		due_frame = pending.due_frame,
		expected_price = pending.expected_price,
	}
end

-- DEBUG / regression
function item.debug_schedule_visual_commit(ent, expected_price, due_frame)
	if not ent then
		return false
	end
	local d = ent:GetData()
	d[PRICE_VISUAL_COMMIT_KEY] = {
		due_frame = due_frame or (Game():GetFrameCount() + 1),
		expected_price = expected_price ~= nil and expected_price or ent.Price,
	}
	return true
end

function item.debug_try_commit_visual(ent)
	return try_commit_native_price_visual(ent)
end

function item.debug_clear_visual_commit(ent)
	clear_native_price_visual_commit(ent)
end

local function run_pre_check_price(ent, seed_price)
	return callback_manager.work_with_result(
		"PRE_CHECK_PRICE",
		function(funct, params, value)
			if params == nil or params == ent.Variant then
				return funct(nil, ent, value)
			end
		end,
		seed_price
	) or seed_price
end

--- Shop + Price==0 在极早帧可能仍在 settle；非商店 Price==0 视为已结算免费。
local function is_live_quote_settled(ent)
	if not ent then return false end
	local price = ent.Price or 0
	if price ~= 0 then return true end
	if ent.IsShopItem and ent:IsShopItem() then
		return (ent.FrameCount or 0) >= 1
	end
	return true
end

local function quote_from_record(rec, ent)
	if not rec then return nil end
	if rec.locked == true and type(rec.price) == "number" then
		return {
			resolved = true,
			has_price = rec.has_price ~= false,
			price = rec.price,
			is_shop_item = rec.source_shop_item == true,
			locked = true,
			revision = tonumber(rec.revision) or 0,
		}
	end
	if rec.quote_state == QUOTE_RESOLVED then
		local has = rec.has_price == true
		if has == false and rec.set_the_price ~= nil then
			has = true
		end
		local price = rec.price
		if price == nil and type(rec.set_the_price) == "number" then
			price = rec.set_the_price
			has = true
		end
		return {
			resolved = true,
			has_price = has,
			price = has and price or nil,
			is_shop_item = rec.source_shop_item == true,
			locked = false,
			revision = tonumber(rec.revision) or 0,
		}
	end
	-- legacy：仅有 set_the_price 视为已捕获动态价
	if type(rec.set_the_price) == "number" then
		return {
			resolved = true,
			has_price = true,
			price = rec.set_the_price,
			is_shop_item = (ent and ent.IsShopItem and ent:IsShopItem()) or rec.source_shop_item == true,
			locked = rec.locked == true,
			revision = tonumber(rec.revision) or 0,
		}
	end
	return nil
end

local function observe_live_quote(ent)
	local shop = ent.IsShopItem and ent:IsShopItem() == true or false
	if not is_live_quote_settled(ent) then
		return {
			resolved = false,
			has_price = nil,
			price = nil,
			is_shop_item = shop,
			locked = false,
			revision = 0,
		}
	end
	local raw = ent.Price or 0
	local computed = run_pre_check_price(ent, raw)
	local has_price = shop or raw ~= 0 or computed ~= 0
	return {
		resolved = true,
		has_price = has_price,
		price = has_price and computed or nil,
		is_shop_item = shop,
		locked = false,
		revision = 0,
	}
end

--- Consumer 获取报价事实的唯一推荐入口。
function item.get_quote(ent)
	if not ent then return nil end
	local rec = get_record(ent)
	local from_rec = quote_from_record(rec, ent)
	if from_rec then
		return from_rec
	end
	local live = observe_live_quote(ent)
	if rec then
		live.revision = tonumber(rec.revision) or 0
		live.locked = rec.locked == true
	end
	return live
end

--- 将当前已 settle 的报价写入 price_holder Consistance record。
--- @return quote, success
function item.capture_quote(ent)
	if not ent then return nil, false end
	local rec = ensure_record(ent)
	if rec.locked == true then
		return item.get_quote(ent), true
	end
	local live = observe_live_quote(ent)
	if not live.resolved then
		rec.quote_state = QUOTE_UNRESOLVED
		return live, false
	end
	rec.quote_state = QUOTE_RESOLVED
	rec.has_price = live.has_price == true
	rec.price = live.has_price and live.price or nil
	rec.source_shop_item = live.is_shop_item == true
	rec.record_subtype = ent.SubType
	if live.has_price and type(live.price) == "number" then
		rec.set_the_price = live.price
		consistance_holder.try_hold_entity(ent, item.own_key, {ignore_subtype = true})
	else
		rec.set_the_price = nil
	end
	bump_revision(rec)
	return item.get_quote(ent), true
end

--- 外部业务 contract 决定报价；禁止普通动态重算改写。
function item.lock_price(ent, price, opts)
	if not ent or type(price) ~= "number" then return false end
	opts = opts or {}
	if (ent.ShopItemId or 0) <= 0 then
		ent.ShopItemId = -1
	end
	ent.AutoUpdatePrice = false
	ent.Price = price
	local rec = ensure_record(ent)
	rec.quote_state = QUOTE_RESOLVED
	rec.has_price = true
	rec.price = price
	rec.set_the_price = price
	rec.record_subtype = ent.SubType
	rec.locked = true
	if opts.was_shop_item ~= nil then
		rec.source_shop_item = opts.was_shop_item == true
	elseif opts.source_shop_item ~= nil then
		rec.source_shop_item = opts.source_shop_item == true
	end
	bump_revision(rec)
	consistance_holder.try_hold_entity(ent, item.own_key, {
		ignore_subtype = true,
		consistance = true,
	})
	schedule_native_price_visual_commit(ent)
	return true
end

function item.unlock_price(ent)
	if not ent then return false end
	local rec = get_record(ent)
	if not rec then return false end
	rec.locked = false
	ent.AutoUpdatePrice = true
	bump_revision(rec)
	return true
end

function item.is_locked(ent)
	local rec = get_record(ent)
	return rec ~= nil and rec.locked == true
end

local function apply_locked_to_entity(ent, rec)
	if type(rec.price) ~= "number" then return end
	if (ent.ShopItemId or 0) == 0 then
		ent.ShopItemId = -1
	end
	ent.AutoUpdatePrice = false
	local wrote = false
	if ent.Price ~= rec.price then
		ent.Price = rec.price
		wrote = true
	end
	rec.set_the_price = rec.price
	rec.quote_state = QUOTE_RESOLVED
	rec.has_price = true
	rec.record_subtype = ent.SubType
	consistance_holder.try_hold_entity(ent, item.own_key, {
		ignore_subtype = true,
		consistance = true,
	})
	if wrote then
		schedule_native_price_visual_commit(ent)
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE,
	params = nil,
	Function = function(_, ent)
		-- VISUAL COMMIT：须在 FINALIZE 之后的下一帧；同帧 schedule 不会在此触发。
		try_commit_native_price_visual(ent)

		local d = ent:GetData()
		d._Data = d._Data or {}
		local rec = d._Data[item.own_key]
		local succ = consistance_holder.try_check_entity(ent, item.own_key)

		-- Fixed quote contract：即使某帧 Price 被打成 0 也恢复，绝不卸 hold
		if rec and rec.locked == true then
			apply_locked_to_entity(ent, rec)
			return
		end

		if succ and ent.Price ~= 0 then
			if rec == nil then
				rec = ensure_record(ent)
			end
			if rec.set_the_price == nil or rec.record_subtype ~= ent.SubType then
				rec.record_subtype = ent.SubType
				rec.set_the_price = run_pre_check_price(ent, ent.Price)
				rec.quote_state = QUOTE_RESOLVED
				rec.has_price = true
				rec.price = rec.set_the_price
				bump_revision(rec)
			end
			if ent.Price ~= rec.set_the_price then
				ent.AutoUpdatePrice = false
				ent.Price = rec.set_the_price
				consistance_holder.try_hold_entity(ent, item.own_key, {ignore_subtype = true})
				-- FINALIZE writeback → schedule VISUAL COMMIT（下一帧 Price=Price）
				schedule_native_price_visual_commit(ent)
			end
		elseif rec and rec.locked ~= true then
			clear_native_price_visual_commit(ent)
			ent.AutoUpdatePrice = true
			consistance_holder.try_remove_entity(ent, item.own_key, {ignore_subtype = true})
		end
	end,
})

-- locked quote 参与 PRE_CHECK_PRICE 链（consumer 不得再自注册 fixed override）
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_CHECK_PRICE,
	params = nil,
	Function = function(_, ent, _val)
		local rec = get_record(ent)
		if rec and rec.locked == true and type(rec.price) == "number" then
			return rec.price
		end
	end,
})

function item.reset_price(ents)
	local n_pickup = ents or auxi.getothers(nil, 5)
	for _, v in pairs(n_pickup) do
		local ent = v:ToPickup()
		if ent then
			local rec = get_record(ent)
			if rec and rec.locked == true then
				apply_locked_to_entity(ent, rec)
			else
				local succ = consistance_holder.try_check_entity(ent, item.own_key)
				if succ then
					-- INVALIDATE：清旧 visual commit，等 NATIVE REPRICE → FINALIZE 再 schedule。
					clear_native_price_visual_commit(ent)
					ent.AutoUpdatePrice = true
					if rec then
						rec.set_the_price = nil
						rec.quote_state = QUOTE_UNRESOLVED
					end
					consistance_holder.try_hold_entity(ent, item.own_key, {ignore_subtype = true})
				end
			end
		end
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
	params = 5,
	Function = function(_, ent)
		if not g.is_gameplay_world_active() then
			return
		end
		item.reset_price()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	params = nil,
	Function = function()
		item.reset_price()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_CHANGE_TRINKET,
	params = nil,
	Function = function(_, player, tkid, isgold)
		item.reset_price()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE,
	params = nil,
	Function = function(_, player, collid, cnt)
		item.reset_price()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_CHANGE_BASIC,
	params = nil,
	Function = function(_, player, changetype, count)
		if item.move_price_basic[changetype] then
			item.reset_price()
		end
	end,
})

function item.catch_price_over(ent)
	if item.is_locked(ent) then
		return
	end
	local rec = ensure_record(ent)
	rec.set_the_price = nil
	rec.quote_state = QUOTE_UNRESOLVED
	rec.record_subtype = ent.SubType
	consistance_holder.try_hold_entity(ent, item.own_key, {ignore_subtype = true})
end

function item.try_catch_price(ent, params)
	if not item.have_catched_price(ent) then
		item.catch_price_over(ent)
	end
end

function item.have_catched_price(ent)
	return consistance_holder.try_check_entity(ent, item.own_key)
end

return item

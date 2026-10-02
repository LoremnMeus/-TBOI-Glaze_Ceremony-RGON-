local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")

local item = {
	ToCall = {},
	entity = enums.Items.Fate_s_Draw,
	cards = {},
	-- 第一份约 24 帧；每额外一份 +8；上限 56
	BASE_INTERVAL = 24,
	EXTRA_INTERVAL = 8,
	MAX_INTERVAL = 56,
	-- Drop 锁定蓄力：约 3 秒满；松手后缓慢回落
	LOCK_FULL = 90,
	LOCK_DRAIN = 2,
	own_key = "Item_FtsD_",
}

if #item.cards == 0 then
	local config = Isaac.GetItemConfig()
	local sz = config:GetCards().Size - 1
	for i = 1, sz do
		local cardinfo = config:GetCard(i)
		local id = tostring(cardinfo.CardType)
		item.cards[id] = item.cards[id] or {}
		table.insert(item.cards[id], #item.cards[id] + 1, cardinfo.ID)
		if cardinfo.GreedModeAllowed == true then
			local gid = "g_" .. id
			item.cards[gid] = item.cards[gid] or {}
			table.insert(item.cards[gid], #item.cards[gid] + 1, cardinfo.ID)
		end
	end
end

local function cycle_interval(player)
	local n = math.max(1, player:GetCollectibleNum(item.entity))
	return math.min(item.MAX_INTERVAL, item.BASE_INTERVAL + (n - 1) * item.EXTRA_INTERVAL)
end

local function drop_held(player)
	return Input.IsActionPressed(ButtonAction.ACTION_DROP, player.ControllerIndex)
end

-- 仅当口袋栏第一格是卡牌时才允许锁定/蓄力（无卡或第一格是药丸等则继续正常滚动）
local function can_lock_cards(player)
	local card = player:GetCard(0)
	return card ~= nil and card > 0
end

local function charge_key()
	return item.own_key .. "lock_charge"
end

local function exhausted_key()
	return item.own_key .. "lock_exhausted"
end

local function reshuffle_cards(player)
	local config = Isaac.GetItemConfig()
	for i = 0, 3 do
		local card = player:GetCard(i)
		if card and card > 0 then
			local cardinfo = config:GetCard(card)
			if cardinfo then
				local id = tostring(cardinfo.CardType)
				local rng = player:GetCardRNG(card)
				if Game():IsGreedMode() then id = "g_" .. id end
				local tg = item.cards[id] or item.cards["1"]
				if tg and #tg > 0 then
					local rnd = rng:RandomInt(#tg) + 1
					player:SetCard(i, tg[rnd])
				end
			end
		end
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	if Game():IsPaused() then
		item.should_change_now = true
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	if not auxi.has_have_coll(player, item.entity) then return end

	local d = player:GetData()
	local ck = charge_key()
	local ek = exhausted_key()
	d[ck] = d[ck] or 0

	local holding = drop_held(player)
	local lockable = can_lock_cards(player)
	local skip_cycle = false
	local just_broke = false

	if holding and lockable then
		if not d[ek] then
			d[ck] = math.min(item.LOCK_FULL, d[ck] + 1)
			if d[ck] >= item.LOCK_FULL then
				d[ek] = true
				just_broke = true
				reshuffle_cards(player)
				d[item.own_key .. "counter"] = 2
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME, 0.7, 1.1, false, 0, 2)
			else
				-- 蓄力未满：锁定手牌
				skip_cycle = true
			end
		end
		-- 已耗尽仍按住：不再锁定，允许继续滚动
	else
		-- 未按住，或第一格不是卡：不蓄力、不锁定，蓄力条回落
		d[ek] = nil
		if d[ck] > 0 then
			d[ck] = math.max(0, d[ck] - item.LOCK_DRAIN)
		end
	end

	if skip_cycle then return end
	if just_broke then return end

	d[item.own_key .. "counter"] = (d[item.own_key .. "counter"] or 0) + 1
	local cnt = cycle_interval(player)
	if d[item.own_key .. "counter"] % cnt == 1 or item.should_change_now then
		reshuffle_cards(player)
		d[item.own_key .. "counter"] = 2
		item.should_change_now = nil
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_, player)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	if not auxi.has_have_coll(player, item.entity) then return end

	local d = player:GetData()
	local ck = charge_key()
	d[ck] = d[ck] or 0
	local cnt = d[ck]
	local full = item.LOCK_FULL

	Charging_Bar_holder.render_me(player, {
		name1 = ck,
		name2 = item.own_key .. "lock_bar_sprite",
		name3 = item.own_key .. "lock",
		loadname = "gfx/effects/chargebar/chargebar.anm2",
		check1 = function()
			return cnt > 5
		end,
		check2 = function()
			return cnt >= full
		end,
		check3 = function()
			return math.ceil(cnt * 100 / full)
		end,
	})
end,
})

return item

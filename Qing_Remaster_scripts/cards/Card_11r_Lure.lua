local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")

-- XI - 欲望?：层数驱动伤害下限与攻击；使用后按层数兑换魂心/混合心。
-- 层数挂在玩家存档索引上，跨房/跨层保留；丢弃/重拾不清零，仅使用时清空。

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Lure_r,
	own_key = "Thoth_cd11r_Lur_",
	DAMAGE_PER_STACK = 0.75,
	-- 陵墓/炼狱门支付 2 滴血时的 flag 组合，不受欲望最低伤害放大
	ignore_flag = {
		[301998464] = true,
	},
	-- 口袋 HUD 层数相对卡牌渲染点的偏移（实测）
	HUD_STACK_OFFSET = Vector(-6, -16),
}

-- 与 Destiny Anchor / Book of Future 主动槽计数同字体；卡面 ui_cardfronts 轴心 (8,12)
local stack_font = Font()
stack_font:Load("font/luaminioutlined.fnt")

local function card_hud_state(player)
	if auxi.is_double_player() then
		if player:GetPlayerType() == PlayerType.PLAYER_ESAU then
			return 3
		end
		return 2
	end
	return 1
end

--- 1 层偏灰，3 层及以上鲜红；中间线性插值。
local function stack_kcolor(stacks, alpha)
	local t = math.min(1, (stacks or 0) / 3)
	local grey = 0.55
	local r = grey + (1 - grey) * t
	local g = grey + (0.15 - grey) * t
	local b = grey + (0.15 - grey) * t
	return KColor(r, g, b, alpha or 1)
end

local function ensure_store()
	save.elses[item.own_key .. "effect"] = save.elses[item.own_key .. "effect"] or {}
	return save.elses[item.own_key .. "effect"]
end

local function get_stacks(player)
	if not player then return 0 end
	local idx = player:GetData().__Index
	if idx == nil then return 0 end
	return ensure_store()[idx] or 0
end

local function set_stacks(player, value)
	if not player then return end
	local idx = player:GetData().__Index
	if idx == nil then return end
	ensure_store()[idx] = math.max(0, value or 0)
end

--- Isaac：1 = 半颗心。0 层下限 1，之后每层 +1。
local function get_min_damage(player)
	return 1 + get_stacks(player)
end

local function refresh_damage(player)
	if not player then return end
	player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
	player:EvaluateItems()
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key .. "effect"] = {}
	end
	ensure_store()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = CacheFlag.CACHE_DAMAGE,
Function = function(_, player, cacheFlag)
	if cacheFlag ~= CacheFlag.CACHE_DAMAGE then return end
	if not auxi.has_card(player, item.entity) then return end
	local stacks = get_stacks(player)
	if stacks > 0 then
		player.Damage = player.Damage + stacks * item.DAMAGE_PER_STACK
	end
end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_, ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if not player then return end
	if not auxi.has_card(player, item.entity) then return end
	if flag & DamageFlag.DAMAGE_CLONES ~= 0 then return end
	if item.ignore_flag[flag] == true then return end

	local min_damage = get_min_damage(player)
	if amt < min_damage then
		ent:TakeDamage(
			min_damage,
			flag | DamageFlag.DAMAGE_CLONES,
			source,
			cooldown / math.max(1, amt) * min_damage
		)
		return false
	end
end,
})

table.insert(item.post_ToCall, #item.post_ToCall + 1, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_, ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if not player then return end
	if not auxi.has_card(player, item.entity) then return end

	-- 被 PRE 取消的原伤害（未带 CLONES 且本应抬升）不记账；真正结算的一次（含 CLONES 替代）才 +1
	local min_damage = get_min_damage(player)
	local was_replaced =
		flag & DamageFlag.DAMAGE_CLONES == 0
		and item.ignore_flag[flag] ~= true
		and amt < min_damage
	if was_replaced then
		return
	end

	set_stacks(player, get_stacks(player) + 1)
	refresh_damage(player)
end,
})

-- 丢弃/重拾不清层数；仅在持有状态边沿刷新攻击，避免无卡时仍吃到层数加成
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	local d = player:GetData()
	local hold_key = item.own_key .. "holding"
	local holding = auxi.has_card(player, item.entity) ~= nil
	if d[hold_key] == holding then return end
	d[hold_key] = holding
	if get_stacks(player) > 0 then
		refresh_damage(player)
	end
end,
})

-- 口袋卡 HUD 左上角：当前层数（灰→红，≥3 鲜红）
local hud_render_cb = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = hud_render_cb, params = nil,
Function = function()
	if not Game():GetHUD():IsVisible() then return end
	local alpha = slot_render_holder.get_alpha()
	local offset = item.HUD_STACK_OFFSET
	local game = Game()
	for i = 0, game:GetNumPlayers() - 1 do
		local player = game:GetPlayer(i)
		if player and player.Parent == nil and player.Variant == 0 then
			local slot = auxi.has_card(player, item.entity)
			if slot ~= nil then
				local stacks = get_stacks(player)
				if stacks > 0 then
					local pos = ui.UICardPos(card_hud_state(player))
					if slot > 0 then
						pos = pos + Vector(-12, 1)
					end
					gui.draw_ch(
						pos + offset,
						tostring(stacks),
						1, 1,
						stack_kcolor(stacks, alpha),
						true,
						stack_font
					)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_, cardtype, player, useFlags)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return
	end

	local room = Game():GetRoom()
	local d = player:GetData()
	local stacks = get_stacks(player)
	set_stacks(player, 0)
	refresh_damage(player)

	local reward = 0
	if stacks > 0 then
		reward = math.max(1, math.floor(stacks / 2))
	end
	if reward <= 0 then return end

	local subtype = HeartSubType.HEART_SOUL
	if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
		subtype = HeartSubType.HEART_BLENDED
	end

	for _ = 1, reward do
		Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_HEART,
			subtype,
			room:FindFreePickupSpawnPosition(player.Position, 10, true),
			Vector(0, 0),
			player
		)
	end
end,
})

return item

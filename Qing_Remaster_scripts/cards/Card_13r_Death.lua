-- XIII - 死神?：死神场（最多 6/8 格场上资源）
-- 权威状态 = death_field.state records；虚影 = Death Field Proxy Effect（非 MeusNil）。
local enums = require("Qing_Remaster_scripts.core.enums")
local C = require("Qing_Remaster_scripts.cards.death_field.constants")
local state = require("Qing_Remaster_scripts.cards.death_field.state")
local proxy = require("Qing_Remaster_scripts.cards.death_field.proxy")
local executor = require("Qing_Remaster_scripts.cards.death_field.executor")
local interaction = require("Qing_Remaster_scripts.cards.death_field.interaction")
local visual = require("Qing_Remaster_scripts.cards.death_field.visual")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Death_r,
	own_key = C.OWN_KEY,
}

proxy.append_callbacks(item)

local trinkets = require("Qing_Remaster_scripts.cards.death_field.trinket_effects")
trinkets.append_callbacks(item)

-- Continue / 换房重建去重：POST_GAME_STARTED 与 POST_NEW_ROOM 可能同帧各调一次
local room_rebuilt_this_load = false

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		room_rebuilt_this_load = false
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player then
				executor.clear_pending_primary_charge(player)
			end
		end
		if not continue then
			state.reset_all()
			proxy.clear_all_room_cache()
		else
			-- continue：ensure 表存在；虚影由进房重建
			local save = require("Qing_Remaster_scripts.core.savedata")
			save.elses[C.SAVE_KEY] = save.elses[C.SAVE_KEY] or {}
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	Function = function()
		proxy.clear_all_room_cache()
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			-- 仍在举起/队列中的 PRIMARY 捡回：保留 pending，等 POST_GAIN
			if player and player.IsItemQueueEmpty and player:IsItemQueueEmpty()
				and not (player.IsHoldingItem and player:IsHoldingItem()) then
				executor.clear_pending_primary_charge(player)
			end
		end
	end,
})

local function rebuild_field_players()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player then
			interaction.on_new_room(player)
		end
	end
	room_rebuilt_this_load = true
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	Function = function(_, continue)
		if not continue then
			return
		end
		-- Continue：延后 1 逻辑帧；若 POST_NEW_ROOM 已重建则跳过
		delay_buffer.addeffe(function()
			if room_rebuilt_this_load then
				return
			end
			rebuild_field_players()
		end, {}, 1)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	Function = function()
		rebuild_field_players()
	end,
})

-- 按键 / 焦点：MC_POST_PLAYER_UPDATE = 60 Hz（IsActionTriggered 不可放 PEFFECT）
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	Function = function(_, player)
		interaction.tick_player(player)
	end,
})

-- 地上可纳入资源：紫色高亮（PRE 涂 / POST 还原）
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_RENDER,
	Function = function(_, pickup, _)
		interaction.render_absorb_pre(pickup)
	end,
})
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_RENDER,
	Function = function(_, pickup, _)
		interaction.render_absorb_post(pickup)
	end,
})

-- 充能条 / 长按条：实体层之后统一画，避免被后渲染实体挡住
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	Function = function()
		visual.flush_overlays()
	end,
})

-- 逻辑帧 30 Hz：场上 CHARGE_TIMED 主动本地 +1（不塞槽）
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	Function = function()
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and state.is_active(player) then
				executor.tick_timed_charges(player)
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup, collider, _)
		local player = collider and collider:ToPlayer()
		if not player then
			return
		end
		-- return true = 已消费碰撞，阻止 vanilla（与 glaze pickup 一致）
		-- PRIMARY returned active：try_collect 返回 false，交给 vanilla
		if executor.try_collect_returned_active(player, pickup) then
			return true
		end
	end,
})

-- PRIMARY：vanilla 入队/获得后，只修正 Death Field 保存的主/黄充能
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE,
	params = nil,
	Function = function(_, player, collectible_id, _count, _touched, _prev_num, _from_direct)
		executor.on_post_gain_returned_active(player, collectible_id)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD,
	Function = function()
		local amount = auxi.get_charge_from_room()
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and state.is_active(player) then
				executor.charge_field_actives(player, amount)
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = item.entity,
	Function = function(_, cardtype, player, useFlags)
		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			return
		end
		-- 已在场中再打一张：先结束旧场（实体化）再开新场
		if state.is_active(player) then
			executor.end_field(player)
		end
		local cloth = player:GetData().tarot_cloth_used == cardtype
		executor.activate_from_player(player, {cloth = cloth})
	end,
})

return item

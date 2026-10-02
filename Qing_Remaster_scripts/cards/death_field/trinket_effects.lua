-- Death Field trinket adapter：业务 state → MC_EVALUATE_IMITATE_TRINKET
-- 禁止直接 AddInnateTrinket / RemoveInnateTrinket；由 imitate_item_holder 同步。
local C = require("Qing_Remaster_scripts.cards.death_field.constants")
local state = require("Qing_Remaster_scripts.cards.death_field.state")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")

local M = {}

local GOLD = TrinketType.TRINKET_GOLDEN_FLAG

function M.split_trinket_id(raw)
	raw = tonumber(raw) or 0
	local golden = (raw & GOLD) ~= 0
	local base = raw & 0x7FFF
	return base, golden
end

function M.compose_trinket_id(base, golden)
	base = tonumber(base) or 0
	if golden then
		return base | GOLD
	end
	return base
end

--- 旧版 Death_r GroupKey 残留清理（一次性 / evaluate 前）
function M.clear_legacy_innate_group(player)
	if not player or not player.GetInnateTrinketGroup or not player.RemoveInnateTrinket then
		return
	end
	local group = player:GetInnateTrinketGroup(C.TRINKET_GROUP)
	if type(group) ~= "table" then
		return
	end
	for k, _ in pairs(group) do
		local id = tonumber(k)
		if id then
			player:RemoveInnateTrinket(id, 999, C.TRINKET_GROUP)
		end
	end
end

--- MC_EVALUATE_IMITATE_TRINKET：把场上饰品 entries 投影为 desired counts
function M.evaluate(player, target_id, value)
	M.clear_legacy_innate_group(player)
	if not state.is_active(player) then
		return value
	end
	for entry in state.iter_entries(player) do
		if entry.kind == "trinket" then
			local tid = M.compose_trinket_id(entry.trinket_id, entry.golden)
			if target_id == nil or target_id == tid then
				Imitate_item_holder.add(
					value,
					tid,
					math.max(1, tonumber(entry.multiplier) or 1),
					{costume = false}
				)
			end
		end
	end
	return value
end

function M.refresh(player)
	Imitate_item_holder.Evaluate_Imitate_Trinkets(player)
end

function M.append_callbacks(card_item)
	local enums = require("Qing_Remaster_scripts.core.enums")
	table.insert(card_item.myToCall, #card_item.myToCall + 1, {
		CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_TRINKET,
		params = nil,
		Function = function(_, player, target_id, value)
			return M.evaluate(player, target_id, value)
		end,
	})
end

return M

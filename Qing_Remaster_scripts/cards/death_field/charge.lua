-- Death Field active charge helpers
-- entry.charge = green main (0..max)
-- entry.battery_charge = The Battery overcharge (0..max)
-- Debug 8 (INFINITE_ITEM_CHARGES) only overrides effective main; never writes entry.

local C = require("Qing_Remaster_scripts.cards.death_field.constants")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local M = {}

-- 与 Book_of_Thoth 同模式：debug 8 / DebugFlag.INFINITE_ITEM_CHARGES
local INFINITE_ITEM_CHARGES = (DebugFlag and DebugFlag.INFINITE_ITEM_CHARGES) or (1 << 7)

function M.debug_infinite_charge()
	local game = Game()
	if not game or not game.GetDebugFlags then
		return false
	end
	return (game:GetDebugFlags() & INFINITE_ITEM_CHARGES) ~= 0
end

function M.get_active_charge_info(colid)
	local cfg = Isaac.GetItemConfig():GetCollectible(colid)
	if not cfg then
		return 0, 0
	end
	return cfg.MaxCharges or 0, cfg.ChargeType or 0
end

--- entry 保存的 max（玩家槽转入）优先于 XML MaxCharges
function M.entry_max_charge(entry)
	if entry and type(entry.max_charge) == "number" and entry.max_charge > 0 then
		return entry.max_charge
	end
	if not entry or not entry.collectible_id then
		return 0
	end
	return select(1, M.get_active_charge_info(entry.collectible_id))
end

--- total（仅兼容 Pickup.Charge）→ 主 + The Battery 过充
function M.split_total_charge(total, maxc)
	total = math.max(0, tonumber(total) or 0)
	maxc = math.max(0, tonumber(maxc) or 0)
	if maxc <= 0 then
		return 0, 0
	end
	local main = math.min(total, maxc)
	local battery = math.max(0, math.min(maxc, total - maxc))
	return main, battery
end

--- 有效显示/可用性充能；不改写 entry
--- returns main, battery, maxc, charge_type
function M.get_effective_charge(entry)
	local maxc = M.entry_max_charge(entry)
	local _, ctype = M.get_active_charge_info(entry and entry.collectible_id)
	local main = math.max(0, math.min(maxc, (entry and entry.charge) or 0))
	local battery = math.max(0, math.min(maxc, (entry and entry.battery_charge) or 0))
	if M.debug_infinite_charge() and maxc > 0 and ctype ~= ItemConfig.CHARGE_SPECIAL then
		main = maxc
		-- 不修改 battery：黄色严格反映真实 The Battery 过充
	end
	return main, battery, maxc, ctype
end

--- 自然地上主动（无 Death Field meta）
function M.read_natural_pickup_charge(pickup, colid)
	local maxc, ctype = M.get_active_charge_info(colid)
	if maxc <= 0 then
		return 0, 0
	end
	if ctype == ItemConfig.CHARGE_SPECIAL then
		return M.split_total_charge(pickup.Charge or 0, maxc)
	end
	if ctype == ItemConfig.CHARGE_TIMED then
		return math.max(0, math.min(maxc, pickup.Charge or 0)), 0
	end
	-- NORMAL：自然未触碰底座 Charge 常为 0 → 首次拾取语义满主充
	if pickup.Touched ~= true then
		return maxc, 0
	end
	return M.split_total_charge(pickup.Charge or 0, maxc)
end

--- 优先读 Death Field Consistance metadata；否则自然路径
--- 返回表：charge / battery_charge / max_charge / original_slot / touched
function M.read_pickup_state(pickup, colid)
	local touched = pickup and pickup.Touched == true
	if pickup and consistance_holder.try_check_entity(pickup, C.OWN_KEY) then
		local d2 = pickup:GetData()
		local meta = d2._Data and d2._Data[C.OWN_KEY]
		if meta and (meta.colid == nil or meta.colid == colid) then
			local maxc = M.get_active_charge_info(colid)
			if type(meta.max_charge) == "number" and meta.max_charge > 0 then
				maxc = meta.max_charge
			end
			if meta.touched ~= nil then
				touched = meta.touched == true
			end
			local main, battery
			if meta.battery_charge ~= nil then
				main = math.max(0, tonumber(meta.charge) or 0)
				battery = math.max(0, tonumber(meta.battery_charge) or 0)
				if maxc > 0 then
					main = math.min(main, maxc)
					battery = math.min(battery, maxc)
				end
			else
				main, battery = M.split_total_charge(meta.charge or 0, maxc)
			end
			return {
				charge = main,
				battery_charge = battery,
				max_charge = meta.max_charge,
				original_slot = meta.slot,
				touched = touched,
			}
		end
	end
	local main, battery = M.read_natural_pickup_charge(pickup, colid)
	return {
		charge = main,
		battery_charge = battery,
		max_charge = nil,
		original_slot = nil,
		touched = touched,
	}
end

--- 兼容旧多返回值调用
function M.read_pickup_into_field(pickup, colid)
	local st = M.read_pickup_state(pickup, colid)
	return st.charge, st.battery_charge, st.max_charge, st.original_slot, st.touched
end

--- 使用一次后：黄色过充补回主条（标准双充能）
function M.apply_active_use_charge(entry)
	local maxc = M.entry_max_charge(entry)
	if maxc <= 0 then
		return
	end
	local bat = entry.battery_charge or 0
	if bat > 0 then
		entry.charge = math.min(maxc, bat)
		entry.battery_charge = math.max(0, bat - maxc)
	else
		entry.charge = 0
		entry.battery_charge = 0
	end
end

--- 仅修正已在槽内主动的充能（PRIMARY vanilla 拾取后）。
--- 先 SetActiveCharge(main) 校正绿条（可拆开「Charge=main+battery 全塞绿条」），再补黄过充差值。
--- 禁止 SetActiveCharge(main+battery) 当作双条权威写入。
function M.restore_active_charge(player, slot, main, battery)
	if not player then
		return
	end
	main = math.max(0, tonumber(main) or 0)
	battery = math.max(0, tonumber(battery) or 0)
	local cur_main = (player.GetActiveCharge and player:GetActiveCharge(slot)) or 0
	local cur_bat = (player.GetBatteryCharge and player:GetBatteryCharge(slot)) or 0
	if cur_main == main and cur_bat == battery then
		return
	end
	if player.SetActiveCharge then
		player:SetActiveCharge(main, slot)
	end
	cur_bat = (player.GetBatteryCharge and player:GetBatteryCharge(slot)) or 0
	if player.AddActiveCharge then
		if battery > cur_bat then
			player:AddActiveCharge(battery - cur_bat, slot, false, true, true)
		end
	elseif player.SetActiveCharge and battery > 0 and cur_bat == 0 then
		-- 无 AddActiveCharge 时只能退化；仍避免把黄条语义写进绿条优先路径
		player:SetActiveCharge(main + battery, slot)
	end
end

--- Exact-slot：AddCollectible 进指定槽，再写主充能 + The Battery 过充。
--- first_time：对应 pickup.Touched 取反（未触碰底座 → first pickup）
function M.restore_active_to_slot(player, id, slot, main, battery, first_time)
	player:AddCollectible(id, 0, first_time == true, slot)
	main = math.max(0, tonumber(main) or 0)
	battery = math.max(0, tonumber(battery) or 0)
	if player.AddActiveCharge then
		if main > 0 then
			player:AddActiveCharge(main, slot, false, false, true)
		end
		if battery > 0 then
			player:AddActiveCharge(battery, slot, false, true, true)
		end
	elseif player.SetActiveCharge then
		player:SetActiveCharge(main + battery, slot)
	end
end

--- @deprecated 兼容旧名 → restore_active_to_slot
function M.restore_player_active_charges(player, id, slot, main, battery, first_time)
	M.restore_active_to_slot(player, id, slot, main, battery, first_time)
end

return M

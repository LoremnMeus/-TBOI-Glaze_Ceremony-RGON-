-- 黄金罗盘：一次性主动。使用后预约下一层为固定直道楼层。
-- 当前层 active 时可再预约 next_floor（不覆盖本层 Root Seed）。

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local compass_rng = require("Qing_Remaster_scripts.items.golden_compass.rng")
local compass_state = require("Qing_Remaster_scripts.items.golden_compass.state")
local runtime = require("Qing_Remaster_scripts.items.golden_compass.runtime")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	pre_ToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Golden_Compass,
	own_key = "Item_Golden_Compass_",
	q_weight = 4,
}

local force_seija = false

auxi.add_to_seija(item.entity)

function item.debug_force_seija()
	return force_seija == true
end

function item.debug_set_force_seija(value)
	force_seija = value == true
end

local function capture_use_compat(player)
	local virtues = false
	local belial = false
	local seija = force_seija == true
	pcall(function()
		virtues = player:HasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES) == true
	end)
	pcall(function()
		belial = auxi.should_do_belial(player) == true
	end)
	if not seija then
		pcall(function()
			seija = auxi.should_do_Seija(player) == true
		end)
	end
	return {
		room84_angel = virtues,
		room84_devil = belial,
		seija_curses = seija,
	}
end

do
	local function append_list(dst, src)
		if type(src) ~= "table" then
			return
		end
		for i = 1, #src do
			dst[#dst + 1] = src[i]
		end
	end
	append_list(item.ToCall, runtime.ToCall)
	append_list(item.myToCall, runtime.myToCall)
	append_list(item.post_ToCall, runtime.post_ToCall)
	append_list(item.pre_ToCall, runtime.pre_ToCall)
	append_list(item.pre_myToCall, runtime.pre_myToCall)
	append_list(item.post_myToCall, runtime.post_myToCall)
end

local function is_carbattery(use_flags)
	return use_flags and (use_flags & UseFlag.USE_CARBATTERY) == UseFlag.USE_CARBATTERY
end

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_USE_ITEM,
	params = item.entity,
	Function = function(_, _col, _rng, player, use_flags, _slot)
		if not player then
			return {Discharge = false, Remove = false, ShowAnim = false}
		end
		-- Greed / Greedier: consume like a normal use, but never arm / redirect floors.
		local greed = false
		pcall(function()
			greed = Game():IsGreedMode() == true
		end)
		if greed then
			return {Discharge = true, Remove = true, ShowAnim = true}
		end
		if is_carbattery(use_flags) then
			return {Discharge = false, Remove = false, ShowAnim = false}
		end

		local phase = compass_state.phase()
		-- Unconsumed appointment already exists (current armed/generating OR next while active).
		if phase == "armed" or phase == "generating" then
			return {Discharge = true, Remove = true, ShowAnim = true}
		end
		if phase == "active" and compass_state.has_next_arm() then
			return {Discharge = true, Remove = true, ShowAnim = true}
		end

		local root, err = compass_rng.take_root_seed(player, item.entity)
		if not root then
			print("[Golden Compass] arm failed: " .. tostring(err))
			return {Discharge = false, Remove = false, ShowAnim = false}
		end
		local ok, why = runtime.arm_with_root_seed(root, {
			compat = capture_use_compat(player),
		})
		if not ok then
			print("[Golden Compass] arm rejected: " .. tostring(why))
			return {Discharge = false, Remove = false, ShowAnim = false}
		end
		return {Discharge = true, Remove = true, ShowAnim = true}
	end,
})

function item.debug_status_text()
	local snap = compass_state.snapshot_for_status()
	return string.format(
		"GoldenCompass phase=%s root=%s next=%s layout=%s id=%s neg=%s gen=%s fail=%s angel=%s devil=%s seija=%s forceSeija=%s",
		tostring(snap.phase),
		tostring(snap.root_seed),
		tostring(snap.next_root_seed),
		tostring(snap.layout_ready),
		tostring(snap.identity_restored),
		tostring(snap.negative_ready),
		tostring(snap.generation_ok),
		tostring(snap.fail_reason),
		tostring(snap.compat_angel),
		tostring(snap.compat_devil),
		tostring(snap.compat_seija),
		tostring(force_seija)
	)
end

function item.arm_debug_root(root_seed, meta)
	meta = meta or {}
	if meta.compat == nil and force_seija then
		meta.compat = {
			room84_angel = false,
			room84_devil = false,
			seija_curses = true,
		}
	end
	return runtime.arm_with_root_seed(tonumber(root_seed), meta)
end

return item

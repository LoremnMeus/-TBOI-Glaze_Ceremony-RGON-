-- Death Field focus / Drop / Active / Pocket input
-- 按键监听放在 MC_POST_PLAYER_UPDATE（60Hz），与 Chariot/Book_of_Voice 等一致；
-- IsActionTriggered 在 PEFFECT(30Hz) 上会漏帧。
-- 焦点：ghost / absorb 统一候选池评分，无 Pickup 绝对优先。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local C = require("Qing_Remaster_scripts.cards.death_field.constants")
local state = require("Qing_Remaster_scripts.cards.death_field.state")
local proxy = require("Qing_Remaster_scripts.cards.death_field.proxy")
local executor = require("Qing_Remaster_scripts.cards.death_field.executor")

local M = {}

local HOLD_KEY = C.HOLD_KEY
local HOLD_UID_KEY = C.HOLD_UID_KEY
local FOCUS_KEY = C.FOCUS_KEY
local ABSORB_PTR_KEY = C.OWN_KEY .. "absorb_ptr"
local ABSORB_ENT_KEY = C.OWN_KEY .. "absorb_ent"
local GLOW_SAVE_KEY = C.OWN_KEY .. "absorb_glow"
local ABSORB_BLEND_KEY = C.ABSORB_FOCUS_BLEND_KEY

local absorb_blend_tick_frame = -1

local function ctrl(player)
	return player.ControllerIndex
end

local function drop_pressed(player)
	return Input.IsActionPressed(ButtonAction.ACTION_DROP, ctrl(player))
end

local function drop_triggered(player)
	return Input.IsActionTriggered(ButtonAction.ACTION_DROP, ctrl(player))
end

local function item_triggered(player)
	return Input.IsActionTriggered(ButtonAction.ACTION_ITEM, ctrl(player))
end

local function pocket_triggered(player)
	return Input.IsActionTriggered(ButtonAction.ACTION_PILLCARD, ctrl(player))
end

--- SECONDARY / POCKET / POCKET2 主动：ACTION_PILLCARD 也可发动（依 original_slot）
local function active_accepts_pocket_key(entry)
	if not entry or entry.kind ~= "active" then
		return false
	end
	local slot = entry.original_slot
	if slot == ActiveSlot.SLOT_SECONDARY or slot == ActiveSlot.SLOT_POCKET then
		return true
	end
	if ActiveSlot.SLOT_POCKET2 and slot == ActiveSlot.SLOT_POCKET2 then
		return true
	end
	return false
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

--- blend=0 → 原色；blend=1 → 完整紫色。基于 base 叠加，不硬塞固定 Tint。
local function build_absorb_color(base, blend)
	blend = math.max(0, math.min(1, blend or 0))
	local ro = base.RO or 0
	local go = base.GO or 0
	local bo = base.BO or 0
	local col = Color(
		base.R or 1,
		base.G or 1,
		base.B or 1,
		base.A or 1,
		ro + 0.12 * blend,
		go + 0.02 * blend,
		bo + 0.22 * blend
	)
	if col.SetColorize then
		col:SetColorize(
			lerp(base.RC or 0, 1.05, blend),
			lerp(base.GC or 0, 0.45, blend),
			lerp(base.BC or 0, 1.35, blend),
			lerp(base.AC or 0, 1, blend)
		)
	end
	return col
end

local function clear_absorb_focus(player)
	local d = player:GetData()
	d[ABSORB_ENT_KEY] = nil
	d[ABSORB_PTR_KEY] = nil
end

local function set_absorb_focus(player, pickup)
	local d = player:GetData()
	d[ABSORB_PTR_KEY] = GetPtrHash(pickup)
	d[ABSORB_ENT_KEY] = pickup
end

local function clear_hold(player)
	local d = player:GetData()
	d[HOLD_KEY] = nil
	d[HOLD_UID_KEY] = nil
end

local function clear_all_focus(player)
	player:GetData()[FOCUS_KEY] = nil
	clear_absorb_focus(player)
	clear_hold(player)
end

--- 恢复高亮染色；clear_blend 时同时清 ABSORB_BLEND（业务身份已变 / 场结束兜底）
local function restore_absorb_visual(pickup, clear_blend)
	if not pickup then
		return
	end
	local d = pickup:GetData()
	local saved = d[GLOW_SAVE_KEY]
	if saved then
		pickup:GetSprite().Color = auxi.table2color(saved)
		d[GLOW_SAVE_KEY] = nil
	end
	if clear_blend then
		d[ABSORB_BLEND_KEY] = nil
	end
end

--- 场结束 / 异常收尾：扫全房清掉残留紫色（兜底，主路径见 tick）
function M.clear_all_absorb_visuals()
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, false, false)) do
		local pickup = ent:ToPickup()
		if pickup then
			local d = pickup:GetData()
			if d[ABSORB_BLEND_KEY] ~= nil or d[GLOW_SAVE_KEY] ~= nil then
				restore_absorb_visual(pickup, true)
			end
		end
	end
end

function M.is_absorb_target(pickup)
	if not auxi.check_all_exists(pickup) then
		return false
	end
	local ptr = GetPtrHash(pickup)
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:GetData()[ABSORB_PTR_KEY] == ptr then
			return true
		end
	end
	return false
end

local function any_death_field_active()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and state.is_active(player) then
			return true
		end
	end
	return false
end

--- 视觉 blend：可吸收目标推进；不再 absorbable / SubType=0 空底座 → 当帧强清
--- 每 Isaac 帧只跑一次（PLAYER_UPDATE 多人会重复进入）
local function tick_absorb_visual_blends()
	local frame = Isaac.GetFrameCount()
	if absorb_blend_tick_frame == frame then
		return
	end
	absorb_blend_tick_frame = frame

	local speed = C.ABSORB_FOCUS_BLEND_SPEED or 0.25
	local field_active = any_death_field_active()
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, false, false)) do
		local pickup = ent:ToPickup()
		if pickup and auxi.check_all_exists(pickup) then
			local d = pickup:GetData()
			local has_visual_state = d[ABSORB_BLEND_KEY] ~= nil or d[GLOW_SAVE_KEY] ~= nil
			local absorbable = executor.is_absorbable_pickup(pickup)

			-- 业务身份已变（含 collectible→SubType 0 空底座）或场已全关：立即恢复，禁止渐隐泄漏
			if not absorbable or not field_active then
				if has_visual_state then
					restore_absorb_visual(pickup, true)
				end
			else
				local cur = tonumber(d[ABSORB_BLEND_KEY]) or 0
				local goal = M.is_absorb_target(pickup) and 1 or 0
				if goal > 0 or cur > 0 or has_visual_state then
					local nextv = cur + (goal - cur) * speed
					if math.abs(nextv - goal) < 0.01 then
						nextv = goal
					end
					if nextv < 0.01 then
						restore_absorb_visual(pickup, true)
					else
						d[ABSORB_BLEND_KEY] = nextv
					end
				end
			end
		end
	end
end

-- PRE_PICKUP_RENDER：仅当前帧仍 absorbable 才允许染色；否则强清
function M.render_absorb_pre(pickup)
	if not pickup then
		return
	end
	if not executor.is_absorbable_pickup(pickup) then
		restore_absorb_visual(pickup, true)
		return
	end
	local d = pickup:GetData()
	local blend = tonumber(d[ABSORB_BLEND_KEY]) or 0
	if blend <= 0.001 then
		return
	end
	if not d[GLOW_SAVE_KEY] then
		d[GLOW_SAVE_KEY] = auxi.color2table(pickup:GetSprite().Color)
	end
	pickup:GetSprite().Color = build_absorb_color(d[GLOW_SAVE_KEY], blend)
end

function M.render_absorb_post(pickup)
	restore_absorb_visual(pickup, false)
end

local function score_target(player, ent)
	local delta = ent.Position - player.Position
	local distance = delta:Length()
	local score = distance
	local move = player:GetMovementInput()
	if move and move:Length() > 0.05 and distance > 0.01 then
		local alignment = move:Normalized():Dot(delta:Normalized())
		score = score - alignment * (C.FOCUS_DIRECTION_BONUS or 20)
	end
	return score
end

local function collect_candidates(player)
	local list = {}
	local interact = C.INTERACT_RADIUS or 110
	local absorb_r = C.ABSORB_RADIUS or interact

	proxy.for_each_proxy(player, function(uid, ent)
		local dist = (ent.Position - player.Position):Length()
		if dist > interact then
			return
		end
		local entry = state.find_entry(player, uid)
		if not entry then
			return
		end
		list[#list + 1] = {
			kind = "ghost",
			ent = ent,
			uid = uid,
			score = score_target(player, ent),
		}
	end)

	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, false, false)) do
		local pickup = ent:ToPickup()
		if pickup and executor.is_absorbable_pickup(pickup) and auxi.check_all_exists(pickup) then
			local dist = (pickup.Position - player.Position):Length()
			if dist <= absorb_r then
				list[#list + 1] = {
					kind = "absorb",
					ent = pickup,
					score = score_target(player, pickup),
				}
			end
		end
	end
	return list
end

local function find_candidate(list, kind, uid, ptr)
	for i = 1, #list do
		local c = list[i]
		if c.kind == kind then
			if kind == "ghost" and c.uid == uid then
				return c
			end
			if kind == "absorb" and GetPtrHash(c.ent) == ptr then
				return c
			end
		end
	end
	return nil
end

local function pick_focus(player, list)
	local best = nil
	for i = 1, #list do
		local c = list[i]
		if best == nil or c.score < best.score then
			best = c
		end
	end

	local d = player:GetData()
	local prev_uid = d[FOCUS_KEY]
	local prev_ptr = d[ABSORB_PTR_KEY]
	local prev = nil
	if prev_uid ~= nil then
		prev = find_candidate(list, "ghost", prev_uid, nil)
	elseif prev_ptr ~= nil then
		prev = find_candidate(list, "absorb", nil, prev_ptr)
	end

	local bias = C.FOCUS_SWITCH_BIAS or 10
	if prev == nil then
		return best
	end
	if best == nil then
		return nil
	end
	if prev.kind == best.kind then
		if prev.kind == "ghost" and prev.uid == best.uid then
			return prev
		end
		if prev.kind == "absorb" and GetPtrHash(prev.ent) == GetPtrHash(best.ent) then
			return prev
		end
	end
	if best.score < prev.score - bias then
		return best
	end
	return prev
end

local function apply_focus(player, focus)
	local d = player:GetData()
	if not focus then
		if d[FOCUS_KEY] ~= nil or d[ABSORB_PTR_KEY] ~= nil then
			clear_hold(player)
		end
		d[FOCUS_KEY] = nil
		clear_absorb_focus(player)
		return
	end

	if focus.kind == "ghost" then
		local changed = d[FOCUS_KEY] ~= focus.uid or d[ABSORB_PTR_KEY] ~= nil
		clear_absorb_focus(player)
		d[FOCUS_KEY] = focus.uid
		if changed then
			clear_hold(player)
		end
		return
	end

	-- absorb
	local ptr = GetPtrHash(focus.ent)
	local changed = d[FOCUS_KEY] ~= nil or d[ABSORB_PTR_KEY] ~= ptr
	d[FOCUS_KEY] = nil
	set_absorb_focus(player, focus.ent)
	if changed then
		clear_hold(player)
	end
end

local function tick_hold_drop(player, focus_uid)
	local d = player:GetData()
	if not drop_pressed(player) then
		clear_hold(player)
		return false
	end
	local stored_uid = d[HOLD_UID_KEY]
	if stored_uid ~= focus_uid then
		d[HOLD_UID_KEY] = focus_uid
		d[HOLD_KEY] = 0
	end
	local hold = (tonumber(d[HOLD_KEY]) or 0) + 1
	d[HOLD_KEY] = hold
	if hold >= C.HOLD_DROP_FRAMES then
		clear_hold(player)
		return true
	end
	return false
end

function M.tick_player(player)
	-- 视觉 blend 与逻辑 focus 解耦：场结束后 goal=0 仍继续淡出
	tick_absorb_visual_blends()

	if not state.is_active(player) then
		clear_all_focus(player)
		return
	end

	if state.player_holds_real_inventory(player) then
		clear_all_focus(player)
		executor.end_field(player)
		return
	end

	-- 开场短保护：场/proxy/高亮照常，禁止 use / absorb / materialize（隔断打卡同键）
	local guard_until = tonumber(player:GetData()[C.INPUT_GUARD_KEY]) or -1
	if Isaac.GetFrameCount() <= guard_until then
		clear_hold(player)
		return
	end

	local candidates = collect_candidates(player)
	local focus = pick_focus(player, candidates)
	apply_focus(player, focus)

	if not focus then
		return
	end

	if focus.kind == "absorb" then
		if drop_triggered(player) then
			executor.try_absorb_pickup(player, focus.ent)
			clear_absorb_focus(player)
		elseif pocket_triggered(player) then
			local kind = executor.get_absorb_kind(focus.ent)
			if kind == "card" or kind == "pill" then
				executor.try_absorb_and_use_pickup(player, focus.ent)
				clear_absorb_focus(player)
			end
		end
		return
	end

	-- ghost
	local focus_uid = focus.uid
	if tick_hold_drop(player, focus_uid) then
		executor.materialize_entry(player, focus_uid)
		return
	end

	local entry = state.find_entry(player, focus_uid)
	if not entry then
		return
	end

	if entry.kind == "active" then
		local triggered = item_triggered(player)
			or (active_accepts_pocket_key(entry) and pocket_triggered(player))
		if triggered then
			executor.use_active(player, focus_uid)
		end
	elseif (entry.kind == "card" or entry.kind == "pill") and pocket_triggered(player) then
		if entry.kind == "card" then
			executor.use_card(player, focus_uid)
		else
			executor.use_pill(player, focus_uid)
		end
	end
end

function M.on_new_room(player)
	clear_all_focus(player)
	if not state.is_active(player) then
		proxy.clear_room_cache(player)
		return
	end
	local rng = player:GetCardRNG(C.ENTITY)
	proxy.rebuild_room(player, rng)
end

return M

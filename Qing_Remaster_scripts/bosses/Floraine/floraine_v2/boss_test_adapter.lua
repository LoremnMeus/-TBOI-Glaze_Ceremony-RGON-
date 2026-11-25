-- Floraine Boss Test Lab adapter (ID: floraine).
-- Thin façade over floraine_v2/test.lua + controller debug APIs.
-- Practice only: never claims Stone story unlock.

local boss_test_registry = require("Qing_Remaster_scripts.bosses.boss_test_registry")
local test = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.test")
local controller = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.controller")
local arena = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.arena")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local rewards = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.rewards")

local PHASES = { p1 = 1, p2 = 2, p3 = 3 }

local function require_arena()
	if not arena.is_arena_room() then
		return false, "not_in_floraine_arena"
	end
	return true
end

local function require_boss()
	local ok_a, why_a = require_arena()
	if not ok_a then
		return nil, why_a
	end
	local ent = controller.find_boss and controller.find_boss()
	if not ent then
		return nil, "no_boss"
	end
	return ent
end

local function clear_practice_unlock()
	local r = runtime.get()
	r.unlock_pending = false
	r.boss_defeated = false
	rewards.remove_all_seals()
end

local adapter = {
	id = "floraine",
	capabilities = {
		hp_control = true,
	},
	-- Floraine thresholds (not Glaze 66/33 defaults).
	hp_presets = { 100, 71, 70, 36, 35 },
	states = {
		{ id = "p1", label = "P1 · 棋军授令" },
		{ id = "p2", label = "P2 · 双列升变" },
		{ id = "p3", label = "P3 · 最终阶段" },
	},
	performances = {
		{ id = "to_p2", label = "P1 → P2 完整转场" },
		{ id = "to_p3", label = "P2 → P3 转场" },
		{ id = "staff_restore", label = "法杖 · 强制回收恢复" },
		{ id = "opening_camera", label = "开场 · 重播镜头" },
		{ id = "command_glow", label = "开场 · 红光完整授令预览" },
		{ id = "command_glow_diag", label = "开场 · 红光诊断打印" },
		{ id = "royal_drop", label = "重落子 · 强制执行" },
		{ id = "royal_align", label = "重落子 · 目标对位预览" },
		{ id = "royal_diag", label = "重落子 · 诊断打印" },
		{ id = "gold_next", label = "金棋 · 触发下一次" },
		{ id = "gold_spawn", label = "金棋 · 生成测试对象" },
		{ id = "gold_kill", label = "金棋 · 击杀与回归" },
		{ id = "gold_report", label = "金棋 · 状态报告" },
		{ id = "p2_entrance", label = "P2 · 侧翼入场重播" },
		{ id = "p2_step", label = "P2 · 完整列队步进" },
		{ id = "p2_lift", label = "P2 · 跳至 LIFT" },
		{ id = "p2_hover", label = "P2 · 跳至 HOVER" },
		{ id = "p2_transfer", label = "P2 · 跳至 TRANSFER" },
		{ id = "p2_land", label = "P2 · 跳至 LAND" },
		{ id = "p2_settle", label = "P2 · 跳至 SETTLE" },
		{ id = "p2_demote", label = "P2 · 原地退化" },
	},
}

function adapter.get_label()
	return "Floraine / 弗洛莱娜"
end

--- Enter Floraine Arena (async room change) or start combat if already there.
--- Goto is NOT reported as a completed spawn.
function adapter.spawn()
	if not arena.is_arena_room() then
		test.enter_arena()
		return false, "goto_arena_issued_reenter_then_spawn"
	end
	-- Already in arena: still ensure Stone board so royal-drop cell overlay can paint.
	test.ensure_stone_board()
	local ent = controller.find_boss and controller.find_boss()
	if ent then
		return true, "boss_already_present"
	end
	test.start_combat()
	ent = controller.find_boss and controller.find_boss()
	if not ent then
		return false, "start_combat_failed_no_boss"
	end
	return true, "combat_started"
end

function adapter.restart()
	if not arena.is_arena_room() then
		test.enter_arena()
		return false, "goto_arena_issued_reenter_then_restart"
	end
	local ok, why = controller.debug_reset_test_state()
	if ok == false then
		return false, why or "reset_failed"
	end
	clear_practice_unlock()
	test.start_combat()
	if not (controller.find_boss and controller.find_boss()) then
		return false, "restart_no_boss"
	end
	return true, "restarted"
end

function adapter.cleanup()
	clear_practice_unlock()
	if arena.is_arena_room() then
		local ok, why = controller.debug_reset_test_state()
		if ok == false then
			return false, why or "cleanup_failed"
		end
		return true, "arena_reset"
	end
	return true, "flags_cleared"
end

function adapter.kill()
	local ent, why = require_boss()
	if not ent then
		return false, why
	end
	-- Defeat animation path marks unlock_pending; clear before seal offer tick.
	controller.debug_defeat()
	clear_practice_unlock()
	return true, "defeated_practice_no_unlock"
end

function adapter.force_state(id)
	local p = PHASES[id]
	if not p then
		return false, "invalid_phase"
	end
	local ok_a, why_a = require_arena()
	if not ok_a then
		return false, why_a
	end
	if not (controller.find_boss and controller.find_boss()) then
		test.start_combat()
	end
	if not (controller.find_boss and controller.find_boss()) then
		return false, "no_boss"
	end
	return test.load_phase(p)
end

function adapter.play_performance(id)
	local ok_a, why_a = require_arena()
	if not ok_a then
		return false, why_a
	end
	if not (controller.find_boss and controller.find_boss()) then
		return false, "no_boss"
	end
	local sess = controller.get_session and controller.get_session()
	if not sess then
		return false, "no_session"
	end

	if id == "to_p2" then
		-- Always play P1→P2 from a legal P1 prelude (even when already on P3).
		if sess.phase ~= defs.PHASE.P1 or sess.state ~= defs.STATE.COMBAT then
			local ok, why = test.load_phase(1)
			if not ok then
				return false, why or "load_p1_failed"
			end
		end
		if not (controller.find_boss and controller.find_boss()) then
			return false, "no_boss_after_load_p1"
		end
		return test.transition_to_phase(2)
	elseif id == "to_p3" then
		if sess.phase ~= defs.PHASE.P2 or sess.state ~= defs.STATE.COMBAT then
			local ok, why = test.load_phase(2)
			if not ok then
				return false, why or "load_p2_failed"
			end
		end
		if not (controller.find_boss and controller.find_boss()) then
			return false, "no_boss_after_load_p2"
		end
		return test.transition_to_phase(3)
	elseif id == "staff_restore" then
		return test.staff_force_restore()
	elseif id == "opening_camera" then
		return test.replay_opening_camera()
	elseif id == "command_glow" then
		return test.preview_command_glow()
	elseif id == "command_glow_diag" then
		local d = test.command_glow_diag()
		return true, d
	elseif id == "royal_drop" then
		return test.force_royal_drop()
	elseif id == "royal_align" then
		return test.royal_align_preview()
	elseif id == "royal_diag" then
		local d = test.royal_drop_diag()
		Isaac.DebugString(string.format(
			"[FloraineV2] royal_diag phase=%s outline=%s a=%s",
			tostring(d and d.phase),
			tostring(d and d.target_outline and d.target_outline.phase),
			tostring(d and d.target_outline and d.target_outline.alpha)
		))
		return true, d
	elseif id == "gold_next" then
		return test.gold_trigger_next()
	elseif id == "gold_spawn" then
		return test.gold_spawn_test()
	elseif id == "gold_kill" then
		return test.gold_kill_reward()
	elseif id == "gold_report" then
		local d = test.gold_report()
		Isaac.DebugString("[FloraineV2] gold_report " .. tostring(d and d.summary))
		return true, d and d.summary
	elseif id == "p2_entrance" then
		if sess.phase ~= defs.PHASE.P2 then
			local ok, why = test.load_phase(2)
			if not ok then
				return false, why or "load_p2_failed"
			end
		end
		return test.p2_play_entrance()
	elseif id == "p2_demote" then
		if sess.phase ~= defs.PHASE.P2 then
			local ok, why = test.load_phase(2)
			if not ok then
				return false, why or "load_p2_failed"
			end
		end
		return test.p2_force_demote()
	elseif id == "p2_step" or id == "p2_lift" or id == "p2_hover"
		or id == "p2_transfer" or id == "p2_land" or id == "p2_settle" then
		if sess.phase ~= defs.PHASE.P2 then
			local ok, why = test.load_phase(2)
			if not ok then
				return false, why or "load_p2_failed"
			end
		end
		local cols = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
		if not cols.is_active() then
			local ok, why = cols.begin({ entrance = false })
			if not ok then
				return false, why or "p2_begin_failed"
			end
		elseif cols.is_entrance_busy and cols.is_entrance_busy() then
			-- March debug: snap entrance so step/phase jumps are usable.
			cols.debug_set_phase("IDLE")
		end
		if id == "p2_step" then
			return test.p2_step()
		end
		local phase = ({
			p2_lift = "LIFT",
			p2_hover = "HOVER",
			p2_transfer = "TRANSFER",
			p2_land = "LAND",
			p2_settle = "SETTLE",
		})[id]
		return test.p2_motion_phase(phase)
	end
	return false, "invalid_performance"
end

function adapter.set_hp_ratio(ratio)
	local ent, why = require_boss()
	if not ent then
		return false, why
	end
	return test.set_hp(ratio)
end

function adapter.inspect()
	local in_arena = arena.is_arena_room() == true
	if not in_arena then
		return {
			alive = false,
			state = "absent",
			phase = nil,
			note = "not_in_floraine_arena",
		}
	end
	local ent = controller.find_boss and controller.find_boss()
	if not ent then
		local sess = controller.get_session and controller.get_session()
		return {
			alive = false,
			state = (sess and sess.state) or "absent",
			phase = sess and sess.phase,
			note = "arena_without_boss",
		}
	end
	local d = test.phase_diag() or {}
	local max_hp = ent.MaxHitPoints or 1
	local hp = ent.HitPoints or 0
	local cols = d.p2_columns or {}
	local promo = d.p2_promotion or {}
	local staff = d.staff or {}
	local left = cols.left or {}
	local right = cols.right or {}
	return {
		alive = true,
		state = d.state,
		phase = d.phase,
		hp = hp / max_hp,
		hp_ratio = hp / max_hp,
		hit_points = hp,
		max_hit_points = max_hp,
		transition = d.transition_stage,
		transition_reason = d.transition_reason,
		pending_phase = d.pending_phase,
		frame = d.frame,
		commands_returned = d.commands_returned,
		souls_returned = d.souls_returned,
		staff_phase = staff.phase,
		staff_active = staff.active == true,
		p2_active = cols.active == true,
		p2_entrance_done = cols.entrance_done == true,
		p2_left = left.matte,
		p2_right = right.matte,
		p2_left_locked = left.locked,
		p2_right_locked = right.locked,
		p2_strays = cols.strays,
		p2_motion = cols.motion_phase,
		p2_motion_elapsed = cols.motion_elapsed,
		p2_left_x = left.x,
		p2_right_x = right.x,
		p2_left_top = left.top_y,
		p2_left_bot = left.bot_y,
		p2_left_band = left.band_cols,
		p2_right_band = right.band_cols,
		p2_count = left.count,
		promotions = promo.active,
		promo_pending = promo.pending,
		promo_phase = promo.phase,
		note = d.transition_reason,
	}
end

boss_test_registry.register("floraine", adapter)

return adapter

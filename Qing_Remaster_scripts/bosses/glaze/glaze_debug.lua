-- Glaze practice / Boss Test adapter.
-- Force State = stable phase jump (no transition playback).
-- Play Performance = prepare legal prelude, then call production transition().

local P = require("Qing_Remaster_scripts.bosses.glaze.glaze_placeholder")
local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local Attacks = require("Qing_Remaster_scripts.bosses.glaze.glaze_attacks")
local Palace = require("Qing_Remaster_scripts.bosses.glaze.glaze_palace")
local boss_test_registry = require("Qing_Remaster_scripts.bosses.boss_test_registry")
local M = {}

local preview_ctx = nil

local function destroy_preview()
	if preview_ctx then
		Palace.cleanup(preview_ctx)
		preview_ctx = nil
	end
end

function M.bind(api, controller)
	local debug = {}

	-- Boss Test must never drive a live story / formal encounter.
	local function current_any()
		for _, ctx in pairs(controller.active) do return ctx end
	end

	local function current_practice()
		for _, ctx in pairs(controller.active) do
			if ctx.practice then return ctx end
		end
	end

	local function refuse_non_practice()
		return false, "A live non-practice Glaze encounter is active"
	end

	local function require_practice(missing_msg)
		local ctx = current_practice()
		if ctx then return ctx end
		if current_any() then return nil, select(2, refuse_non_practice()) end
		return nil, missing_msg or "Spawn practice Glaze first"
	end

	local function practice_or_preview()
		return current_practice() or preview_ctx
	end

	local function ensure_palace(ctx)
		if not ctx.palace then Palace.create(ctx) end
		return ctx.palace
	end

	local function apply_palace_for_phase(ctx, phase)
		ensure_palace(ctx)
		if phase == 1 then
			Palace.reset(ctx)
		elseif phase == 2 then
			Palace.begin_build(ctx)
			Palace.set_build(ctx, 1)
			Palace.set_stability(ctx, 1)
			Palace.set_palette(ctx, "normal")
		else
			Palace.begin_build(ctx)
			Palace.set_build(ctx, 1)
			Palace.set_stability(ctx, 0)
			Palace.set_palette(ctx, "broken")
		end
	end

	function debug.spawn()
		destroy_preview()
		local practice = current_practice()
		if practice then return practice.boss end
		if current_any() then return refuse_non_practice() end
		return api.start(nil, {practice = true})
	end

	function debug.restart()
		if current_any() and not current_practice() then return refuse_non_practice() end
		debug.cleanup()
		return debug.spawn()
	end

	-- Force State: jump to stable phase. Does NOT play production transitions.
	function debug.force_phase(phase)
		if phase ~= 1 and phase ~= 2 and phase ~= 3 then return false, "Phase must be 1..3" end
		local ctx, err = require_practice(); if not ctx then return false, err end
		controller.cancel(ctx); controller.clear_objects(ctx)
		controller.clear_transition_visuals(ctx)
		ctx.phase, ctx.state, ctx.recovery, ctx.phase_frame = phase, "recovery", 30, 300
		ctx.transition, ctx.pending_transition, ctx.final_state = nil, nil, false
		ctx.did_transition_1, ctx.did_transition_2 = phase >= 2, phase >= 3
		ctx.crown_visible, ctx.cooldowns, ctx.previous_attack, ctx.previous_tags = phase == 1, {}, nil, nil
		ctx.crown_offset = Vector.Zero
		ctx.boss.HitPoints = ctx.boss.MaxHitPoints * ({.85, .5, .22})[phase]
		ctx.boss.PositionOffset = Vector(0, -25)
		apply_palace_for_phase(ctx, phase)
		return true
	end

	-- Play Performance helper: legal prelude then production transition().
	function debug.force_transition(index)
		if index ~= 1 and index ~= 2 then return false, "Transition must be 1 or 2" end
		local ctx, err = require_practice(); if not ctx then return false, err end
		local ok, msg = debug.force_phase(index); if not ok then return ok, msg end
		ctx = current_practice(); if not ctx then return refuse_non_practice() end
		ensure_palace(ctx)
		if index == 1 then
			Palace.reset(ctx)
			ctx.crown_visible = true
		else
			Palace.set_build(ctx, 1)
			Palace.set_stability(ctx, 1)
			Palace.set_palette(ctx, "normal")
		end
		ctx.boss.HitPoints = ctx.boss.MaxHitPoints * (index == 1 and .65 or .32)
		controller.transition(ctx, index)
		return true
	end

	function debug.force_finale()
		local ok, msg = debug.force_phase(3); if not ok then return ok, msg end
		local ctx = current_practice(); if not ctx then return refuse_non_practice() end
		ctx.boss.HitPoints = ctx.boss.MaxHitPoints * .09
		ctx.final_state = true
		ctx.boss.PositionOffset = Vector(0, -8)
		return true
	end

	function debug.force_state(id)
		if id == "p1" then return debug.force_phase(1) end
		if id == "p2" then return debug.force_phase(2) end
		if id == "p3" then return debug.force_phase(3) end
		if id == "finale" then return debug.force_finale() end
		return false, "Unknown state: " .. tostring(id)
	end

	function debug.play_performance(id)
		if id == "p1_to_p2" then return debug.force_transition(1) end
		if id == "p2_to_p3" then return debug.force_transition(2) end
		if id == "enter_finale" then return debug.force_finale() end
		return false, "Unknown performance: " .. tostring(id)
	end

	function debug.play_attack(id)
		if not Attacks.by_id[id] then return false, "Unknown attack: " .. tostring(id) end
		local phase = tonumber(id:match("^p(%d)")) or 3
		local ok, msg = debug.force_phase(phase); if not ok then return ok, msg end
		local ctx = current_practice(); if not ctx then return refuse_non_practice() end
		if id:match("^finale%.") then ctx.final_state = true; ctx.boss.HitPoints = ctx.boss.MaxHitPoints * .09 end
		return controller.play_attack(ctx, id)
	end

	function debug.reset_attack()
		local ctx, err = require_practice(); if not ctx then return false, err end
		controller.cancel(ctx); controller.clear_objects(ctx); ctx.state, ctx.recovery = "recovery", 30
		return true
	end

	function debug.next_attack()
		local ctx, err = require_practice(); if not ctx then return false, err end
		debug.reset_attack(); ctx.recovery = 0; ctx.cooldowns = {}
		return true
	end

	function debug.clear_objects()
		local ctx = current_practice()
		if ctx then controller.clear_objects(ctx); return true end
		if current_any() then return refuse_non_practice() end
		return false, "Spawn practice Glaze first"
	end

	function debug.kill()
		local ctx, err = require_practice(); if not ctx then return false, err end
		-- Already practice: refresh marks only; never promote a formal encounter.
		ctx.practice = true
		ctx.boss:GetData().glaze_practice = true
		ctx.boss:Kill()
		return true
	end

	function debug.labels(value)
		P.labels = value == nil and not P.labels or value
		return P.labels
	end

	function debug.set_hp_ratio(value)
		local ctx, err = require_practice(); if not ctx then return false, err end
		local ratio = math.max(0.01, math.min(1, tonumber(value) or 1))
		ctx.boss.HitPoints = ctx.boss.MaxHitPoints * ratio
		return true
	end

	function debug.set_frozen(value)
		local ctx, err = require_practice(); if not ctx then return false, err end
		ctx.debug_freeze = value == true
		if not ctx.debug_freeze then ctx.debug_step_frames = 0 end
		return true
	end

	function debug.step(frames)
		local ctx, err = require_practice(); if not ctx then return false, err end
		ctx.debug_freeze = true
		ctx.debug_step_frames = (ctx.debug_step_frames or 0) + math.max(1, math.floor(tonumber(frames) or 1))
		return true
	end

	function debug.set_palace_build(value)
		local ctx = practice_or_preview()
		if not ctx then
			if current_any() then return refuse_non_practice() end
			return false, "Spawn practice Glaze or Preview Palace first"
		end
		ensure_palace(ctx)
		Palace.set_build(ctx, tonumber(value) or 0)
		return true
	end

	function debug.set_palace_stability(value)
		local ctx = practice_or_preview()
		if not ctx then
			if current_any() then return refuse_non_practice() end
			return false, "Spawn practice Glaze or Preview Palace first"
		end
		ensure_palace(ctx)
		Palace.set_stability(ctx, tonumber(value) or 1)
		return true
	end

	function debug.begin_palace_collapse()
		local ctx = practice_or_preview()
		if not ctx then
			if current_any() then return refuse_non_practice() end
			return false, "Spawn practice Glaze or Preview Palace first"
		end
		ensure_palace(ctx)
		Palace.begin_collapse(ctx)
		return true
	end

	function debug.set_palace_palette(mode)
		local ctx = practice_or_preview()
		if not ctx then
			if current_any() then return refuse_non_practice() end
			return false, "Spawn practice Glaze or Preview Palace first"
		end
		ensure_palace(ctx)
		Palace.set_palette(ctx, mode)
		return true
	end

	function debug.set_palace_debug(key, value)
		local ctx = practice_or_preview()
		if not ctx then
			if current_any() then return refuse_non_practice() end
			return false, "Spawn practice Glaze or Preview Palace first"
		end
		ensure_palace(ctx)
		if ctx.palace.debug[key] ~= nil then ctx.palace.debug[key] = value == true end
		return true
	end

	function debug.preview_palace()
		if current_any() and not current_practice() then return refuse_non_practice() end
		destroy_preview()
		local room = Game():GetRoom()
		preview_ctx = {room = room, center = room:GetCenterPos()}
		Palace.create(preview_ctx)
		Palace.begin_build(preview_ctx)
		Palace.set_build(preview_ctx, 1)
		Palace.set_stability(preview_ctx, 1)
		return true
	end

	function debug.clear_palace()
		destroy_preview()
		local ctx = current_practice()
		if ctx and ctx.palace then Palace.reset(ctx); return true end
		if current_any() then return refuse_non_practice() end
		return true
	end

	function debug.inspect()
		local ctx = current_practice()
		if not ctx then
			if preview_ctx and preview_ctx.palace then
				return {alive = false, state = "preview_palace", palace = Palace.inspect(preview_ctx)}
			end
			if current_any() then
				return {alive = false, state = "blocked_by_live_encounter", practice = false}
			end
			return {alive = false, state = "absent"}
		end
		return controller.inspect(ctx)
	end

	function debug.cleanup()
		destroy_preview()
		-- Only remove practice encounters; never touch formal / story bosses.
		for _, ctx in pairs(controller.active) do
			if ctx.practice then
				local boss = ctx.boss
				controller.cleanup(ctx)
				if boss:Exists() then boss:Remove() end
			end
		end
	end

	function debug.render_preview()
		if preview_ctx and preview_ctx.palace then
			Palace.update(preview_ctx)
			Palace.render(preview_ctx)
		end
	end

	debug.story_test = {
		snapshot = function() return {labels = P.labels} end,
		reset = debug.cleanup,
		prepare = function()
			local any = current_any()
			if any and not any.practice then return refuse_non_practice() end
			debug.cleanup()
			return true
		end,
		trigger = function()
			local any = current_any()
			if any and not any.practice then return refuse_non_practice() end
			local boss, err = debug.spawn()
			if not boss then return false, err or "Failed to spawn practice Glaze" end
			local ctx = controller.init(boss)
			ctx.story_test = true
			-- Story Test overlay may advance Chapter1 when objective matches.
			ctx.story_owned = true
			return true, "Glaze practice encounter spawned (Story overlay only)"
		end,
		inspect = debug.inspect,
		cleanup = debug.cleanup,
		restore = function(snapshot) debug.cleanup(); P.labels = snapshot.labels ~= false; return true end,
	}

	local function attack_entries()
		local out = {}
		local groups = {
			{name = "P1", pool = Attacks.pools[1]},
			{name = "P2", pool = Attacks.pools[2]},
			{name = "P3", pool = Attacks.pools[3]},
			{name = "Finale", pool = Attacks.pools.finale},
		}
		for _, g in ipairs(groups) do
			for _, attack in ipairs(g.pool) do
				out[#out + 1] = {id = attack.id, label = attack.id, group = g.name}
			end
		end
		return out
	end

	function debug.as_boss_test_adapter()
		return {
			id = "glaze_prince",
			get_label = function() return "琉璃王子 / Prince of Glaze" end,
			capabilities = {hp_control = true, freeze = true, palace = true},
			spawn = debug.spawn,
			restart = debug.restart,
			cleanup = debug.cleanup,
			kill = debug.kill,
			inspect = debug.inspect,
			states = {
				{id = "p1", label = "P1 冠冕"},
				{id = "p2", label = "P2 琉璃宫"},
				{id = "p3", label = "P3 碎王"},
				{id = "finale", label = "Finale"},
			},
			performances = {
				{id = "p1_to_p2", label = "P1 → P2：打碎冠冕"},
				{id = "p2_to_p3", label = "P2 → P3：炼金失败"},
				{id = "enter_finale", label = "进入 Finale"},
			},
			attacks = attack_entries(),
			force_state = debug.force_state,
			play_performance = debug.play_performance,
			play_attack = debug.play_attack,
			next_attack = debug.next_attack,
			reset_attack = debug.reset_attack,
			clear_objects = debug.clear_objects,
			set_hp_ratio = debug.set_hp_ratio,
			set_frozen = debug.set_frozen,
			step = debug.step,
			set_palace_build = debug.set_palace_build,
			set_palace_stability = debug.set_palace_stability,
			begin_palace_collapse = debug.begin_palace_collapse,
			set_palace_palette = debug.set_palace_palette,
			set_palace_debug = debug.set_palace_debug,
			preview_palace = debug.preview_palace,
			clear_palace = debug.clear_palace,
			labels = debug.labels,
		}
	end

	function debug.command(command, params)
		if command ~= "glaze" then return end
		local action, arg = params:match("^(%S+)%s*(.-)%s*$")
		local ok, msg = true, nil
		if action == "spawn" then debug.spawn()
		elseif action == "restart" then debug.restart()
		elseif action == "phase" then ok, msg = debug.force_phase(tonumber(arg))
		elseif action == "transition" then ok, msg = debug.force_transition(tonumber(arg))
		elseif action == "finale" then ok, msg = debug.force_finale()
		elseif action == "attack" then ok, msg = debug.play_attack(arg)
		elseif action == "next" then debug.next_attack()
		elseif action == "reset" then debug.reset_attack()
		elseif action == "clear" then debug.clear_objects()
		elseif action == "cleanup" then debug.cleanup()
		elseif action == "labels" then debug.labels()
		elseif action == "kill" then debug.kill()
		elseif action == "hp" then ok, msg = debug.set_hp_ratio(tonumber(arg))
		elseif action == "freeze" then ok, msg = debug.set_frozen(arg ~= "0" and arg ~= "off")
		elseif action == "step" then ok, msg = debug.step(tonumber(arg) or 1)
		elseif action == "palace" then
			if arg == "preview" then ok, msg = debug.preview_palace()
			elseif arg == "clear" then ok, msg = debug.clear_palace()
			elseif arg:match("^build") then ok, msg = debug.set_palace_build(tonumber(arg:match("([%d%.]+)")))
			elseif arg:match("^stab") then ok, msg = debug.set_palace_stability(tonumber(arg:match("([%d%.]+)")))
			else msg = "glaze palace preview|clear|build <0..1>|stab <0..1>" end
		elseif action == "inspect" then for k, v in pairs(debug.inspect()) do Isaac.ConsoleOutput(k .. "=" .. tostring(v) .. "\n") end
		else
			msg = "glaze spawn|restart|phase 1..3|transition 1..2|finale|attack <id>|next|reset|clear|cleanup|labels|kill|hp <0..1>|freeze|step <n>|palace ...|inspect"
		end
		if msg then Isaac.ConsoleOutput((ok == false and "ERROR: " or "") .. msg .. "\n") end
	end

	-- Legacy Story Test panel kept minimal; full UI lives in Boss Test Lab.
	function debug.build(parent)
		if not ImGui then return end
		local prefix = parent .. "_GlazeBoss"
		ImGui.AddElement(parent, prefix, ImGuiElement.TreeNode, "Boss / Prince Glaze (legacy)")
		imgui_layout.add_wrapped_text(prefix, prefix .. "MoveNotice",
			"完整战斗调试已移至 Debug → Boss Test → 琉璃王子。此处保留兼容入口。")
		ImGui.AddButton(prefix, prefix .. "Spawn", "Spawn Glaze (practice)", debug.spawn)
		for phase = 1, 3 do local n = phase; ImGui.AddButton(prefix, prefix .. "Phase" .. n, "Force P" .. n, function() debug.force_phase(n) end) end
		for index = 1, 2 do local n = index; ImGui.AddButton(prefix, prefix .. "Transition" .. n, "Transition " .. n, function() debug.force_transition(n) end) end
		ImGui.AddButton(prefix, prefix .. "Finale", "Force Finale", debug.force_finale)
		ImGui.AddButton(prefix, prefix .. "Cleanup", "Remove Practice Encounter", debug.cleanup)
	end

	boss_test_registry.register("glaze_prince", debug.as_boss_test_adapter())
	return debug
end

return M

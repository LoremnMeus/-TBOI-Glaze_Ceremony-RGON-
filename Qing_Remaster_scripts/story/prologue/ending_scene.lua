-- Prologue Ending1 scene state machine (Update + HUD render).
-- Formal mode writes Story only at final commit; preview never writes Story / unlocks / Game:End.
-- Mid-scene achievement uses PlayAchievement (presentation only); UnlockData mirrors Story completion.
--
-- Dual-sprite presentation:
--   background Sprite → ANM2 "Scene" (shadow/bg/overlay/fade/Zero_gnd; no Body)
--   body Sprite       → ANM2 "BodyPanels" (Lua SetFrame 0..7 only; never auto-plays)

local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")
local defs = require("Qing_Remaster_scripts.story.prologue.ending_defs")

local scene = {
	ToCall = {},
	pre_ToCall = {},
	myToCall = {},
	own_key = "Prologue_EndingScene_",
	_active = nil,
	_bg_sprite = nil,
	_body_sprite = nil,
	_preview_audit = nil,
}

local function ensure_background_sprite()
	if scene._bg_sprite then return scene._bg_sprite end
	local spr = Sprite()
	spr:Load(defs.ANM2_PATH, true)
	spr:SetFrame(defs.ANM2_BACKGROUND_ANIM, defs.BG_FRAME.MAIN)
	scene._bg_sprite = spr
	return spr
end

local function ensure_body_sprite()
	if scene._body_sprite then return scene._body_sprite end
	local spr = Sprite()
	spr:Load(defs.ANM2_PATH, true)
	spr:SetFrame(defs.ANM2_BODY_ANIM, 0)
	scene._body_sprite = spr
	return spr
end

local function apply_art_frame(active, index)
	index = math.floor(tonumber(index) or 0)
	if index < 0 then index = 0 end
	if index >= defs.ART_FRAME_COUNT then index = defs.ART_FRAME_COUNT - 1 end
	active.art_frame = index
	local body = ensure_body_sprite()
	body:SetFrame(defs.ANM2_BODY_ANIM, index)
	return index
end

local function apply_bg_frame(active, index)
	index = math.floor(tonumber(index) or defs.BG_FRAME.MAIN)
	active.bg_frame = index
	local bg = ensure_background_sprite()
	bg:SetFrame(defs.ANM2_BACKGROUND_ANIM, index)
	return index
end

local function capture_control_lock(active)
	active.control_succs = {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player then
			local succ = Attribute_holder.try_hold_attribute(player, "ControlsEnabled", false)
			active.control_succs[playerNum] = succ
			player.Velocity = Vector.Zero
		end
	end
end

local function release_control_lock(active)
	if type(active.control_succs) ~= "table" then return end
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player then
			Attribute_holder.try_rewind_attribute(
				player,
				"ControlsEnabled",
				active.control_succs[playerNum]
			)
		end
	end
	active.control_succs = nil
end

local function deep_copy(v, seen)
	if type(v) ~= "table" then return v end
	seen = seen or {}
	if seen[v] then return seen[v] end
	local out = {}
	seen[v] = out
	for k, val in pairs(v) do
		out[deep_copy(k, seen)] = deep_copy(val, seen)
	end
	return out
end

local function snapshot_story()
	local story = require("Qing_Remaster_scripts.story.story_state")
	local root = story.get_permanent_root(false)
	local run = story.get_permanent_run_root and story.get_permanent_run_root(false)
	local unlock = save.UnlockData and save.UnlockData.Others and save.UnlockData.Others.Ending1
	return {
		story = deep_copy(root),
		run = deep_copy(run),
		ending1_unlock = unlock and unlock.Unlock == true,
	}
end

local function deep_equalish(a, b)
	if a == b then return true end
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return false end
	for k, v in pairs(a) do
		if not deep_equalish(v, b[k]) then return false end
	end
	for k, _ in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end

local function capture_music_id()
	local id = nil
	pcall(function()
		id = MusicManager():GetCurrentMusicID()
	end)
	return id
end

local function restore_music(music_id)
	if music_id == nil then return end
	pcall(function()
		local mm = MusicManager()
		if mm.Crossfade then
			mm:Crossfade(music_id, 0.08)
		else
			mm:Play(music_id, Options.MusicVolume or 1)
		end
		mm:UpdateVolume()
	end)
end

local function audit_preview_mutation(before)
	if not before then return false end
	local after = snapshot_story()
	local mutated = not (
		deep_equalish(before.story, after.story)
		and deep_equalish(before.run, after.run)
		and deep_equalish(before.ending1_unlock, after.ending1_unlock)
	)
	if mutated then
		print("[Qing] PREVIEW MUTATED STORY STATE")
	end
	return mutated
end

local function ending1_achievement_pages()
	local tbl = {}
	local graphics = enums.AchievementGraphics and enums.AchievementGraphics.others
		and enums.AchievementGraphics.others.Ending1
	if type(graphics) ~= "table" then return tbl end
	for i, v in ipairs(graphics) do
		tbl[i] = "gfx/ui/Some achievements/" .. tostring(v) .. ".png"
	end
	if #tbl == 0 then
		for _, v in pairs(graphics) do
			tbl[#tbl + 1] = "gfx/ui/Some achievements/" .. tostring(v) .. ".png"
		end
	end
	return tbl
end

local function is_ending1_already_unlocked()
	local rec = save.UnlockData and save.UnlockData.Others and save.UnlockData.Others.Ending1
	return type(rec) == "table" and rec.Unlock == true
end

local function set_phase(active, phase_id)
	active.phase = phase_id
	active.phase_age = 0
	active.line_index = 1
	active.line_age = 0
	local pdata = defs.PHASES[phase_id]
	active.auto_hold = pdata and pdata.auto_hold or nil
	active.entry_hold = (pdata and tonumber(pdata.entry_hold)) or 0
	apply_art_frame(active, defs.art_frame_for_phase(phase_id))
	if not active.finishing then
		apply_bg_frame(active, defs.BG_FRAME.MAIN)
	end
end

local function begin_finishing(active)
	active.finishing = true
	active.fin_age = 0
	active.body_alpha = 1
	apply_art_frame(active, defs.ART.AFTERMATH)
	apply_bg_frame(active, defs.BG_FRAME.MAIN)
end

local function advance_phase(active)
	local idx = defs.phase_index(active.phase) or 1
	local next_id = defs.PHASE_ORDER[idx + 1]
	if not next_id then
		begin_finishing(active)
		return
	end
	set_phase(active, next_id)
end

local function current_line(active)
	local pdata = defs.PHASES[active.phase]
	if not pdata or type(pdata.lines) ~= "table" then return nil end
	return pdata.lines[active.line_index]
end

local function line_event_key(active)
	return tostring(active.phase) .. ":" .. tostring(active.line_index)
end

local EVENTS = {}

--- Presentation-only achievement beat. Does not write UnlockData.
--- Formal: skip if already unlocked. Preview: always display for full rhythm test.
function EVENTS.ending1_achievement(active)
	if not active.preview and is_ending1_already_unlocked() then
		return false
	end
	local pages = ending1_achievement_pages()
	if #pages == 0 then
		return false
	end
	Achievement_Display_holder.PlayAchievement(pages)
	active.blocking = {kind = "achievement"}
	return true
end

local function run_event(active, event_id)
	local fn = EVENTS[event_id]
	if type(fn) ~= "function" then
		print("[Qing] ending event missing: " .. tostring(event_id))
		return false
	end
	return fn(active) == true
end

local function advance_past_line(active)
	local pdata = defs.PHASES[active.phase]
	local lines = pdata and pdata.lines or {}
	local line = lines[active.line_index]
	if line and line.fin then
		begin_finishing(active)
		return
	end
	if active.line_index < #lines then
		active.line_index = active.line_index + 1
		active.line_age = 0
		return
	end
	advance_phase(active)
end

local function try_advance_line(active, opts)
	opts = opts or {}
	local line = current_line(active)
	if line and line.after_event and not opts.skip_event then
		active.consumed_events = active.consumed_events or {}
		local key = line_event_key(active)
		if not active.consumed_events[key] then
			active.consumed_events[key] = true
			if run_event(active, line.after_event) then
				return
			end
		end
	end
	advance_past_line(active)
end

function scene.is_active()
	return scene._active ~= nil
end

function scene.get_phase()
	return scene._active and scene._active.phase or nil
end

function scene.get_art_frame()
	return scene._active and scene._active.art_frame or nil
end

function scene.set_phase_debug(phase_id)
	if not scene._active then return false end
	if not defs.PHASES[phase_id] then return false end
	set_phase(scene._active, phase_id)
	return true
end

--- Preview helper: force BodyPanels frame 0..7 without changing phase dialogue.
function scene.set_art_frame_debug(index)
	if not scene._active then return false end
	index = math.floor(tonumber(index) or -1)
	if index < 0 or index >= defs.ART_FRAME_COUNT then
		return false
	end
	apply_art_frame(scene._active, index)
	scene._active.art_preview_only = true
	return true
end

function scene.stop_preview()
	local active = scene._active
	if not active or not active.preview then return false end
	release_control_lock(active)
	if active.restore_music then
		restore_music(active.prev_music_id)
	end
	local audit = scene._preview_audit
	scene._active = nil
	scene._bg_sprite = nil
	scene._body_sprite = nil
	scene._preview_audit = nil
	if audit and audit.before then
		audit.mutated = audit_preview_mutation(audit.before)
	end
	return true
end

--- Story truth only. Keep Ending artwork owned until Game:End.
local function commit_formal(active)
	local story = require("Qing_Remaster_scripts.story.story_state")
	local ok, err = false, "missing_api"
	if story.on_prologue_ending_complete then
		ok, err = story.on_prologue_ending_complete()
	end
	if not ok then
		print("[Qing] formal ending blocked: " .. tostring(err or "invalid_prologue_state"))
		return false, err or "invalid_prologue_state"
	end
	-- complete_chapter mirrors Ending1.Unlock = true; achievement was already presented mid-scene.
	active.final_committed = true
	active.end_delay = 2
	return true
end

function scene.finish()
	local active = scene._active
	if not active then return false end
	if active.preview then
		return scene.stop_preview()
	end
	return commit_formal(active)
end

--- opts.preview: pure presentation; never writes Story.
--- opts.phase: start at named phase (debug / preview).
--- opts.art_frame: optional BodyPanels index override (0..7).
function scene.start(opts)
	opts = opts or {}
	if scene._active then
		if scene._active.preview then
			scene.stop_preview()
		else
			return false, "already_active"
		end
	end

	local preview = opts.preview == true
	if preview then
		scene._preview_audit = {before = snapshot_story(), mutated = false}
	end

	scene._bg_sprite = nil
	scene._body_sprite = nil

	local active = {
		preview = preview,
		phase = opts.phase or defs.PHASE.QING_CHARGES_BEAST,
		phase_age = 0,
		line_index = 1,
		line_age = 0,
		art_frame = 0,
		bg_frame = defs.BG_FRAME.MAIN,
		finishing = false,
		fin_age = 0,
		body_alpha = 1,
		entry_hold = 0,
		final_committed = false,
		end_delay = nil,
		blocking = nil,
		consumed_events = {},
		allow_skip_line = true,
		owns_controls = true,
		restore_music = preview,
		prev_music_id = preview and capture_music_id() or nil,
		art_preview_only = opts.art_frame ~= nil,
	}
	set_phase(active, active.phase)
	if opts.art_frame ~= nil then
		apply_art_frame(active, opts.art_frame)
		active.art_preview_only = true
	end

	pcall(function()
		MusicManager():Play(defs.MUSIC_ID, 1)
	end)
	if not preview then
		local player0 = Isaac.GetPlayer(0)
		if player0 and player0.UseActiveItem then
			player0:UseActiveItem(CollectibleType.COLLECTIBLE_PAUSE, UseFlag.USE_NOANIM)
		end
	end
	capture_control_lock(active)

	scene._active = active
	return true
end

function scene.preview(opts)
	opts = opts or {}
	opts.preview = true
	return scene.start(opts)
end

local function update_blocking(active)
	local block = active.blocking
	if not block then return false end
	if block.kind == "achievement" then
		if Achievement_Display_holder.Is_Finished_playing() then
			active.blocking = nil
			try_advance_line(active, {skip_event = true})
		end
		return true
	end
	active.blocking = nil
	return false
end

--- Hold SPACE to run Ending1 timeline at FAST_FORWARD_MULT (not per-line skip).
local function is_fast_forward_held()
	return Keyboard ~= nil and Input.IsButtonPressed(Keyboard.KEY_SPACE, 0)
end

local function timeline_step(active)
	-- Achievement blocking and final Game:End safety delay do not use this.
	if is_fast_forward_held() then
		return defs.FAST_FORWARD_MULT or 4
	end
	return 1
end

local function skip_hint_text(held)
	local lang = Options and Options.Language
	if held then
		if lang == "en" then
			return "FAST FORWARD"
		end
		return "快进中"
	end
	if lang == "en" then
		return "Hold SPACE to fast-forward"
	end
	return "按住空格快进"
end

local function update_finishing(active, step)
	-- Body hold → Body fade → Scene outro. BG stays MAIN until Body alpha hits 0.
	active.fin_age = (active.fin_age or 0) + step
	apply_art_frame(active, defs.ART.AFTERMATH)

	local outro = defs.OUTRO or {}
	local body_hold = tonumber(outro.BODY_HOLD) or 18
	local body_fade = math.max(1, tonumber(outro.BODY_FADE) or 24)
	local body_done = body_hold + body_fade
	local age = active.fin_age or 0

	if age <= body_hold then
		active.body_alpha = 1
		apply_bg_frame(active, defs.BG_FRAME.MAIN)
	elseif age < body_done then
		local t = (age - body_hold) / body_fade
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
		active.body_alpha = 1 - t
		apply_bg_frame(active, defs.BG_FRAME.MAIN)
	else
		active.body_alpha = 0
		-- Scene outro is manually stepped by Lua after Body is gone.
		local bg_age = age - body_done
		local bg_frame = math.min(
			defs.BG_FRAME.OUTRO_END,
			defs.BG_FRAME.OUTRO_BEGIN + math.floor(bg_age)
		)
		apply_bg_frame(active, bg_frame)
	end

	if age < defs.FIN_HOLD_FRAMES then
		return
	end

	if active.preview then
		scene.stop_preview()
		return
	end

	if not active.final_committed then
		commit_formal(active)
		return
	end

	-- Final commit → Game:End safety frames stay 1× (not presentation content).
	active.end_delay = (active.end_delay or 1) - 1
	if active.end_delay <= 0 then
		release_control_lock(active)
		scene._active = nil
		scene._bg_sprite = nil
		scene._body_sprite = nil
		Game():End(3)
	end
end

local function update_active(active)
	if update_blocking(active) then
		return
	end

	local step = timeline_step(active)

	if active.finishing then
		update_finishing(active, step)
		return
	end

	-- Art-only preview: hold still until MENUBACK.
	if active.art_preview_only then
		if active.preview and Input.IsActionTriggered(ButtonAction.ACTION_MENUBACK, 0) then
			scene.stop_preview()
		end
		return
	end

	active.phase_age = (active.phase_age or 0) + step

	local pdata = defs.PHASES[active.phase]
	local lines = pdata and pdata.lines or {}
	if #lines == 0 then
		local hold = active.auto_hold or 60
		if active.phase_age >= hold then
			advance_phase(active)
		end
		return
	end

	-- Sudden-cut reaction window before first dialogue line.
	if (active.entry_hold or 0) > 0 then
		active.entry_hold = math.max(0, (active.entry_hold or 0) - step)
		return
	end

	active.line_age = (active.line_age or 0) + step

	if active.preview and Input.IsActionTriggered(ButtonAction.ACTION_MENUBACK, 0) then
		scene.stop_preview()
		return
	end
	local line = current_line(active)
	local duration = (line and tonumber(line.duration)) or defs.LINE_AUTO_ADVANCE
	if active.line_age >= duration then
		try_advance_line(active)
	end
end

local function render_active(active)
	local bg = ensure_background_sprite()
	local body = ensure_body_sprite()
	local scz = gui.GetScreenSize()
	-- Stage layers keep 432×240 authored aspect (may non-uniform-stretch to viewport).
	local stage_sx = scz.X / defs.STAGE_WIDTH
	local stage_sy = scz.Y / defs.STAGE_HEIGHT
	bg.Scale = Vector(stage_sx, stage_sy)
	-- BodyPanels are 320×192 storyboard cells — keep aspect ratio.
	local body_scale = math.min(stage_sx, stage_sy)
	body.Scale = Vector(body_scale, body_scale)

	local origin = Vector(scz.X / 2, scz.Y / 2) - Game().ScreenShakeOffset
	bg:SetFrame(defs.ANM2_BACKGROUND_ANIM, active.bg_frame or defs.BG_FRAME.MAIN)
	bg:Render(origin, Vector(0, 0), Vector(0, 0))

	local body_alpha = active.body_alpha
	if body_alpha == nil then body_alpha = 1 end
	if body_alpha > 0.001 then
		body.Color = Color(1, 1, 1, body_alpha)
		body:SetFrame(defs.ANM2_BODY_ANIM, active.art_frame or 0)
		body:Render(origin, Vector(0, 0), Vector(0, 0))
		body.Color = Color(1, 1, 1, 1)
	end

	if SFXManager():IsPlaying(SoundEffect.SOUND_MEAT_JUMPS) then
		SFXManager():Stop(SoundEffect.SOUND_MEAT_JUMPS)
	end

	-- Hide dialogue + hint while achievement / final hold / art-only preview occupy the beat.
	if active.blocking or active.finishing or active.art_preview_only then
		return
	end
	-- entry_hold: art only (no dialogue yet); still show fast-forward hint.
	if (active.entry_hold or 0) <= 0 then
		local line = current_line(active)
		if line then
			local word = defs.line_text(line)
			if word and word ~= "" then
				local y = scz.Y * (defs.DIALOG_Y_RATIO or 0.82)
				gui.draw_ch(
					Vector(scz.X * 0.5 - (#word) * 2.5, y),
					word,
					1.5,
					1.5,
					defs.line_color(line),
					true
				)
			end
		end
	end

	local held = is_fast_forward_held()
	local hint = skip_hint_text(held)
	local hint_scale = 1
	local hint_y = scz.Y * (defs.SKIP_HINT_Y_RATIO or 0.94)
	local hint_col = held and KColor(0.7, 0.7, 0.7, 0.85) or KColor(0.55, 0.55, 0.55, 0.7)
	gui.draw_ch(
		Vector(scz.X * 0.5 - (#hint) * 2.0, hint_y),
		hint,
		hint_scale,
		hint_scale,
		hint_col,
		true
	)
end

table.insert(scene.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		local active = scene._active
		if not active then return end
		-- Blocking (achievement queue) must progress even if the game is paused.
		if active.blocking then
			update_blocking(active)
			return
		end
		if Game():IsPaused() then return end
		update_active(active)
	end,
})

table.insert(scene.ToCall, {
	-- Draw under GiantBook_holder (post_ToCall POST_RENDER +100) so achievements sit above Ending1.
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		local active = scene._active
		if not active then return end
		render_active(active)
	end,
})

table.insert(scene.pre_ToCall, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = nil,
	Function = function()
		if scene._active then
			return false
		end
	end,
})

table.insert(scene.ToCall, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		scene._active = nil
		scene._bg_sprite = nil
		scene._body_sprite = nil
		scene._preview_audit = nil
	end,
})

return scene

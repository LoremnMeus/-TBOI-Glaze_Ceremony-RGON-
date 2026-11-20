local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local history_hud = require("Qing_Remaster_scripts.callbacks.history_hud_render_holder")
local effects = require("Qing_Remaster_scripts.items.entombed_demon.effects")

local M = {}
local active = {}
local smoke_residue = {}
local smoke_sprite = nil
local smoke_path = nil
local config = {speed = 1, hand_width = 6, orb_diameter = 11, arc = 0.2}
local durations = {awaken = 10, aiming = 14, hand_extending = 18, grab = 5,
	hand_retracting = 6, dragging = 18, writhe = 36, flight = 27}
local REACH_HAND = 28
local OFFSCREEN = 30

local function ensure_smoke()
	if smoke_sprite then return smoke_sprite end
	local ok, path = pcall(function()
		local cfg = EntityConfig.GetEntity(EntityType.ENTITY_EFFECT, EffectVariant.DUST_CLOUD, 0)
		return cfg and cfg.GetAnm2Path and cfg:GetAnm2Path()
	end)
	if not ok or not path or path == "" then return nil end
	local sprite = Sprite()
	sprite:Load(path, true)
	smoke_sprite = sprite
	smoke_path = path
	return sprite
end

local function icon(id)
	local sprite = Sprite()
	sprite:Load("gfx/mimics/Rooted_Demon/flying_icon.anm2", true)
	if EntityPickup.SetupCollectibleGraphics then
		EntityPickup.SetupCollectibleGraphics(sprite, 0, id, false, 1, true)
	else
		local cfg = Isaac.GetItemConfig():GetCollectible(id)
		if cfg then sprite:ReplaceSpritesheet(0, cfg.GfxFileName) sprite:LoadGraphics() end
	end
	sprite:Play("Idle", true)
	return sprite
end

local function ref(index, id, time, occurrence)
	return {player_index = index, kind = "collectible", id = id,
		history_time = time, occurrence = occurrence}
end

-- Visibility chooses the performance only. full keeps the ritual, reach sends
-- the hand up from beneath the sacrifice, digest skips a stand-in target, and
-- spit starts at the orb when neither icon or the History HUD can be seen.
local function history_available()
	local hud = Game():GetHUD()
	return (hud and hud.IsVisible and hud:IsVisible() and (Options.ExtraHUDStyle or 0) > 0) and true or false
end

local function screen_size()
	return ui.GetScreenSize()
end

local function fresh(stamp)
	return (stamp and Game():GetFrameCount() - stamp <= 4) and true or false
end

local function visibility(anim)
	if not history_available() then return false, false end
	if not fresh(anim.hud_sample_frame) then return nil, nil end
	return fresh(anim.coffin_hud_frame), fresh(anim.target_hud_frame)
end

local function choose_mode(coffin_visible, target_visible)
	if not coffin_visible and not target_visible then return "spit" end
	if not coffin_visible then return "reach" end
	if not target_visible then return "digest" end
	return "full"
end

local function reach_points(anim)
	if anim.captured and anim.reach_frozen then
		return anim.reach_frozen, anim.capture_pos
	end
	local target = (anim.target_pos or Vector.Zero) + (anim.debug_shift or Vector.Zero)
	return Vector(target.X, screen_size().Y + OFFSCREEN), target
end

local function spit_origin(anim)
	if anim.spit_from then return anim.spit_from end
	local screen = screen_size()
	local key = tostring(anim.job and anim.job.coffin_key or "")
	local hash = 0
	for i = 1, #key do
		hash = (hash * 33 + string.byte(key, i)) % 997
	end
	local column = (tonumber(anim.player_index) or 0) % 2
	local x = screen.X * 0.5 + (column == 0 and -36 or 36) + ((hash % 5) - 2) * 28
	if x < 36 then x = 36 end
	if x > screen.X - 36 then x = screen.X - 36 end
	anim.spit_from = Vector(x, screen.Y + OFFSCREEN)
	return anim.spit_from
end

local function emit_from(anim)
	if anim.visual_mode == "reach" then
		if anim.reach_frozen then return anim.reach_frozen end
		return reach_points(anim)
	end
	if anim.visual_mode == "spit" then return spit_origin(anim) end
	return (anim.coffin_pos or spit_origin(anim)) + Vector(0, -6)
end

local function positions(anim)
	if anim.visual_mode == "reach" then return reach_points(anim) end
	local target = (anim.target_pos or Vector.Zero) + (anim.debug_shift or Vector.Zero)
	return anim.coffin_pos or Vector.Zero, target
end

local function angle(a, b)
	return (b - a):GetAngleDegrees() + 90
end

local function turn(from, toward, fraction)
	local delta = (toward - from + 180) % 360 - 180
	return from + delta * math.min(1, fraction)
end

local function advance(anim, phase)
	anim.phase = phase
	anim.tick = 0
end

local function mode_locked(anim)
	if anim.captured then return true end
	return anim.phase == "spitting" or anim.phase == "flight" or anim.phase == "commit"
end

local function enter_mode(anim, mode)
	if anim.visual_mode == mode then return end
	anim.visual_mode = mode
	anim.hand_progress = 0
	anim.emit_pos = nil
	if mode == "spit" then
		advance(anim, "spitting")
	elseif mode == "digest" then
		advance(anim, "writhe")
	elseif mode == "reach" then
		local coffin, target = reach_points(anim)
		anim.aim_coffin, anim.aim_target = coffin, target
		advance(anim, "hand_extending")
	else
		advance(anim, "awaken")
	end
end

local function sync_mode(anim)
	if mode_locked(anim) then return true end
	local coffin_visible, target_visible = visibility(anim)
	if coffin_visible == nil then
		if anim.visual_mode then return true end
		anim.mode_wait = (anim.mode_wait or 0) + 1
		if anim.mode_wait < 20 then return false end
		coffin_visible, target_visible = false, false
	end
	anim.mode_wait = 0
	enter_mode(anim, choose_mode(coffin_visible, target_visible))
	return true
end

local function coffin_shape(anim)
	local t = anim.tick
	if anim.phase == "writhe" then
		local compression = math.min(1, t / 5)
		local wobble = math.sin(t * 1.35) * 0.12
		return 1 + 0.20 * compression + wobble, 1 - 0.38 * compression - wobble * 0.6
	elseif anim.phase == "spitting" then
		local squeeze = math.min(1, t / 6)
		return 1 - 0.43 * squeeze, 1 + 0.48 * squeeze
	elseif anim.phase == "flight" then
		local recovery = math.min(1, t / 8)
		return 0.57 + 0.43 * recovery, 1.48 - 0.48 * recovery
	end
	return 1, 1
end

local function anim_key(index, coffin_key)
	return tostring(index) .. ":" .. tostring(coffin_key)
end

local function player_anims(index)
	local list = {}
	if index == nil then return list end
	for key, anim in pairs(active) do
		if anim.player_index == index then list[#list + 1] = {key = key, anim = anim} end
	end
	return list
end

local function drop_anim(key, reason)
	local anim = active[key]
	if not anim then return end
	if reason == "room changed" then
		for _, orb in pairs(anim.orbs) do
			if orb.last_pos then
				smoke_residue[#smoke_residue + 1] = {
					pos = orb.last_pos, frame = Game():GetFrameCount(), duration = 6,
					diameter = config.orb_diameter, fading_orb = true,
				}
			end
		end
	end
	active[key] = nil
	if reason ~= "commit" and anim.callbacks.cancel then
		anim.callbacks.cancel(reason or "canceled")
	end
end

function M.start(player, job, callbacks)
	local index = player and player:GetData().__Index
	if index == nil or not job or job.coffin_key == nil then return false end
	local key = anim_key(index, job.coffin_key)
	if active[key] then return false end
	ensure_smoke()
	active[key] = {
		player_index = index, job = job, callbacks = callbacks,
		phase = "awaken", tick = 0, captured = false, rotation = 0,
		coffin_pos = Vector.Zero, target_pos = Vector.Zero,
		coffin_icon = icon(job.coffin_id), target_icon = icon(job.target.id),
		orbs = {}, claim_conflict = false,
	}
	return true
end

function M.has_job(index)
	return #player_anims(index) > 0
end

function M.cancel(index, reason)
	if reason == "room changed" then
		for i = #smoke_residue, 1, -1 do
			if not smoke_residue[i].fading_orb then table.remove(smoke_residue, i) end
		end
	end
	for _, entry in ipairs(player_anims(index)) do
		drop_anim(entry.key, reason)
	end
end
function M.reset() active = {} smoke_residue = {} end

local function advance_anim(player, key, anim)
	local valid, reason = anim.callbacks.valid(player, anim.job)
	if not valid then drop_anim(key, reason or "history changed") return end
	if anim.claim_conflict and anim.last_hud_frame and Game():GetFrameCount() - anim.last_hud_frame <= 4 then return end
	if not sync_mode(anim) then return end
	local coffin_pos, target_pos = positions(anim)
	local phase = anim.phase
	if anim.visual_mode ~= "reach" and (phase == "hand_extending" or phase == "grab") and not anim.captured then
		if anim.aim_coffin and anim.aim_target and ((coffin_pos - anim.aim_coffin):Length() > 1
			or (target_pos - anim.aim_target):Length() > 1) then
			anim.retract_from = anim.hand_progress or 0
			advance(anim, "hand_retracting")
			phase = anim.phase
		end
	end
	if anim.visual_mode == "reach" and not anim.captured then
		anim.aim_coffin, anim.aim_target = coffin_pos, target_pos
	end
	anim.tick = anim.tick + config.speed
	local extend_ticks = anim.visual_mode == "reach" and REACH_HAND or durations.hand_extending
	if phase == "awaken" then
		if anim.tick >= durations.awaken then advance(anim, "aiming") end
	elseif phase == "aiming" then
		anim.rotation = turn(anim.rotation, angle(coffin_pos, target_pos), 0.3 * config.speed)
		if anim.tick >= durations.aiming then
			anim.aim_coffin, anim.aim_target = coffin_pos, target_pos
			advance(anim, "hand_extending")
		end
	elseif phase == "hand_extending" then
		anim.hand_progress = math.min(1, anim.tick / extend_ticks)
		if anim.tick >= extend_ticks then advance(anim, "grab") end
	elseif phase == "grab" then
		anim.hand_progress = 1
		if anim.tick >= durations.grab then
			anim.captured = true
			anim.capture_pos = target_pos
			if anim.visual_mode == "reach" then anim.reach_frozen = coffin_pos end
			advance(anim, "dragging")
		end
	elseif phase == "hand_retracting" then
		anim.hand_progress = math.max(0, (anim.retract_from or 0) * (1 - anim.tick / durations.hand_retracting))
		if anim.tick >= durations.hand_retracting then
			anim.hand_progress = 0
			advance(anim, "aiming")
		end
	elseif phase == "dragging" then
		anim.hand_progress = math.max(0, 1 - (anim.tick / durations.dragging)^3)
		if anim.tick >= durations.dragging then
			advance(anim, anim.visual_mode == "reach" and "spitting" or "writhe")
		end
	elseif phase == "writhe" then
		anim.rotation = turn(anim.rotation, 0, 0.4 * config.speed)
		if anim.tick >= durations.writhe then advance(anim, "spitting") end
	elseif phase == "spitting" then
		local count = #anim.job.positions
		local lead = (anim.visual_mode == "spit" or anim.visual_mode == "reach") and 0 or 9
		if not anim.emit_pos then anim.emit_pos = emit_from(anim) end
		for i = 1, count do
			if anim.tick >= lead + (i - 1) * 4 and not anim.orbs[i] then
				anim.orbs[i] = {age = 0, from = anim.emit_pos}
			end
		end
		if anim.tick >= lead + math.max(0, count - 1) * 4 then advance(anim, "flight") end
	elseif phase == "flight" then
		if anim.tick >= durations.flight then advance(anim, "commit") end
	elseif phase == "commit" then
		anim.holding_commit = true
	end
	for _, orb in pairs(anim.orbs) do orb.age = orb.age + config.speed end
end

function M.update(player)
	local index = player:GetData().__Index
	if index == nil or Game():IsPaused() then return end
	for _, entry in ipairs(player_anims(index)) do
		if active[entry.key] then advance_anim(player, entry.key, entry.anim) end
	end
	local holders = {}
	local waiting = false
	for _, entry in ipairs(player_anims(index)) do
		if entry.anim.holding_commit then holders[#holders + 1] = entry
		else waiting = true end
	end
	if waiting or #holders == 0 then return end
	table.sort(holders, function(a, b)
		local ia = a.anim.job.target and a.anim.job.target.history_index or 0
		local ib = b.anim.job.target and b.anim.job.target.history_index or 0
		return ia > ib
	end)
	for _, entry in ipairs(holders) do
		local anim = entry.anim
		local callbacks, job = anim.callbacks, anim.job
		active[entry.key] = nil
		if callbacks.commit(player, job) then
			for i, destination in ipairs(job.positions) do
				local pos = auxi.world_to_ui_screen(destination, ui.GetHUDRenderOffset())
				if pos then
					smoke_residue[#smoke_residue + 1] = {
						pos = pos, frame = Game():GetFrameCount(), duration = 26,
						diameter = config.orb_diameter, ordinal = i,
						world_destination = destination, player_index = index,
					}
				end
			end
		end
	end
end

local function draw_icon(sprite, slot, anim, target)
	if anim.visual_mode == "spit" then return end
	if target and anim.visual_mode ~= "full" and anim.visual_mode ~= "reach" then return end
	if not target and anim.visual_mode == "reach" then return end
	local scale = (Options.ExtraHUDStyle or 1) == 2 and 0.5 or 1
	local pulse = anim.phase == "awaken" and 1 + 0.12 * math.sin(math.pi * math.min(1, anim.tick / 10)) or 1
	if target and anim.captured then return end
	local rotation = target and 0 or anim.rotation
	local pos = target and slot.center + (anim.debug_shift or Vector.Zero) or slot.center
	local sx, sy = 1, 1
	if not target then sx, sy = coffin_shape(anim) end
	slot:render(sprite, pos, {base_scale = Vector(scale * pulse * sx, scale * pulse * sy), rotation = rotation})
end

local function behind_player(player, world_destination, launch, destination, progress)
	if not player or not world_destination or progress < 0.5 then return false end
	if world_destination.Y >= player.Position.Y - 8 then return false end
	local player_screen = auxi.world_to_ui_screen(player.Position, ui.GetHUDRenderOffset())
	local flight_base = launch + (destination - launch) * progress
	return player_screen and flight_base.Y < player_screen.Y - 8 or false
end

local function world_render_pixel(hud_pixel)
	-- HUD projection is mirror(WorldToScreen(world) + HUD offset); undo both for PRE_PLAYER_RENDER.
	return auxi.ui_screen_for_mirror(hud_pixel) - (ui.GetHUDRenderOffset() or Vector.Zero)
end

local function render_orb(anim, i, orb, destination, world_pass)
	local t = math.min(1, orb.age / (22 + i))
	local lift = math.max(70, math.min(125, (destination - orb.from):Length() * (0.45 + config.arc)))
	local function at(fraction)
		return orb.from + (destination - orb.from) * fraction
			+ Vector(0, -4 * lift * fraction * (1 - fraction))
	end
	local pos = at(t)
	orb.last_pos = pos
	local trail = {}
	for j = 1, 4 do trail[j] = at(math.max(0, t - j * 0.022)) end
	local origin = orb.from
	if anim.visual_mode == "reach" or anim.visual_mode == "spit" then
		local limit = screen_size().Y
		if pos.Y >= limit then return false end
		for j = 1, 4 do
			if trail[j] and trail[j].Y >= limit then trail[j] = nil end
		end
		origin = pos
	end
	if world_pass then
		pos = world_render_pixel(pos)
		origin = world_render_pixel(origin)
		for j = 1, 4 do
			if trail[j] then trail[j] = world_render_pixel(trail[j]) end
		end
	end
	local diameter = config.orb_diameter * (t < 1 and 1 or 0.55)
	effects.smoke(smoke_sprite, pos, trail, diameter, orb.age, false, 1, origin)
	effects.orb(pos, diameter, orb.age, 1)
	effects.smoke(smoke_sprite, pos, trail, diameter, orb.age, true, 1, origin)
	return true
end

history_hud.register_consumer("EntombedDemon", {
	priority = 1,
	collect = function(context, declare)
		for _, anim in pairs(active) do
			local frame = Game():GetFrameCount()
			anim.hud_sample_frame = frame
			anim.claim_conflict = false
			local job = anim.job
			local function claim(id, time, occurrence, target)
				local slots = context.find_slots({kind = "collectible", player_index = anim.player_index,
					id = id, history_time = time, occurrence = occurrence})
				local mode = anim.visual_mode
				local own = mode == "full" or mode == "reach" or (mode == "digest" and not target)
				for _, slot in ipairs(slots) do
					if slot.visible then
						if target then
							anim.target_pos = slot.center
							anim.target_hud_frame = frame
						else
							anim.coffin_pos = slot.center
							anim.coffin_hud_frame = frame
						end
						anim.last_hud_frame = frame
						if own then
							local result = declare.exclusive(slot, {render = function(ctx)
								draw_icon(target and anim.target_icon or anim.coffin_icon, ctx, anim, target)
							end})
							if #result.rejected > 0 then anim.claim_conflict = true end
						end
					end
				end
			end
			claim(job.coffin_id, job.coffin_time, job.coffin_hud_occurrence, false)
			claim(job.target.id, job.target.time, job.target.hud_occurrence, true)
		end
	end,
})

local function render_residue(residue, pos, age)
	local alpha = 1 - age / residue.duration
	local diameter = residue.diameter * (residue.fading_orb and 1 or 0.75)
	effects.smoke(smoke_sprite, pos, nil, diameter, age, false, alpha)
	if residue.fading_orb then effects.orb(pos, diameter, age, alpha * alpha) end
	effects.smoke(smoke_sprite, pos, nil, diameter, age, true, alpha)
end

function M.wants_behind(player)
	if not player then return false end
	local index = player:GetData().__Index
	if index == nil then return false end
	if #player_anims(index) > 0 then
		return true
	end
	for _, residue in ipairs(smoke_residue) do
		if residue.player_index == index then
			return true
		end
	end
	return false
end

function M.render_behind(player)
	if not player then return end
	local room = Game():GetRoom()
	if room and room.GetRenderMode and RenderMode
		and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local index = player:GetData().__Index
	if index == nil then return end
	local frame = Game():GetFrameCount()
	for _, entry in ipairs(player_anims(index)) do
		local anim = entry.anim
		if not anim.claim_conflict then
			for i, orb in pairs(anim.orbs) do
				local world_destination = anim.job.positions[i]
				local destination = auxi.world_to_ui_screen(world_destination, ui.GetHUDRenderOffset())
				if destination and behind_player(player, world_destination, orb.from, destination,
					math.min(1, orb.age / (22 + i))) then
					if render_orb(anim, i, orb, destination, true) then
						orb.drawn_behind_frame = frame
					end
				end
			end
		end
	end
	for _, residue in ipairs(smoke_residue) do
		if residue.player_index == index and residue.world_destination then
			local pos = auxi.world_to_ui_screen(residue.world_destination, ui.GetHUDRenderOffset())
			local age = frame - residue.frame
			if pos and age < residue.duration and behind_player(player, residue.world_destination,
				pos, pos, 1) then
				render_residue(residue, world_render_pixel(pos), age)
				residue.drawn_behind_frame = frame
			end
		end
	end
end

function M.render()
	for _, anim in pairs(active) do
		if anim.visual_mode and not anim.claim_conflict then
			local coffin_pos, target_pos = positions(anim)
			local frame = Game():GetFrameCount()
			local phase = anim.phase
			local hand = anim.hand_progress or 0
			if hand > 0 and (anim.visual_mode == "full" or anim.visual_mode == "reach") then
				local start = phase == "hand_retracting" and anim.aim_coffin or coffin_pos
				local finish = target_pos
				if phase == "hand_retracting" then finish = anim.aim_target end
				if anim.captured then
					local t = math.min(1, anim.tick / durations.dragging)
					finish = anim.capture_pos + (coffin_pos - anim.capture_pos) * (t^3)
					if phase == "dragging" then hand = 1 end
				end
				effects.hand(start, finish, hand, config.hand_width, math.min(18, (finish - start):Length() * 0.08), true)
			end
			if anim.captured and phase == "dragging" then
				local t = math.min(1, anim.tick / durations.dragging)
				local pos = anim.capture_pos + (coffin_pos - anim.capture_pos) * (t^3)
				local scale = ((Options.ExtraHUDStyle or 1) == 2 and 0.5 or 1) * (1 - 0.75 * t)
				history_hud.apply_to_sprite(anim.target_icon, ref(anim.player_index, anim.job.target.id,
					anim.job.target.time, anim.job.target.hud_occurrence), {base_scale = scale})
				anim.target_icon:Render(pos, Vector.Zero, Vector.Zero)
			end
			for i, orb in pairs(anim.orbs) do
				local destination = auxi.world_to_ui_screen(anim.job.positions[i], ui.GetHUDRenderOffset())
				if destination and orb.drawn_behind_frame ~= frame then render_orb(anim, i, orb, destination, false) end
			end
		end
	end
	for i = #smoke_residue, 1, -1 do
		local residue = smoke_residue[i]
		local age = Game():GetFrameCount() - residue.frame
		if age >= residue.duration then
			table.remove(smoke_residue, i)
		else
			if residue.drawn_behind_frame ~= Game():GetFrameCount() then
				local pos = residue.world_destination
					and auxi.world_to_ui_screen(residue.world_destination, ui.GetHUDRenderOffset()) or residue.pos
				if pos then render_residue(residue, pos, age) end
			end
		end
	end
end

function M.status(index)
	local parts = {}
	for _, entry in ipairs(player_anims(index)) do
		local anim = entry.anim
		parts[#parts + 1] = string.format("%s / %s / tick %.1f / coffin %s / target %s / captured %s",
			anim.visual_mode or "pending", anim.phase, anim.tick, anim.job.coffin_key,
			anim.job.target.id, tostring(anim.captured))
	end
	if #parts == 0 then return "idle" end
	return table.concat(parts, " | ")
end
function M.smoke_status() return smoke_path or "DUST_CLOUD graphics unavailable" end
function M.set_config(key, value) if config[key] then config[key] = value end end
function M.get_config(key) return config[key] end
function M.simulate_shift(index)
	for _, entry in ipairs(player_anims(index)) do
		entry.anim.debug_shift = (entry.anim.debug_shift or Vector.Zero) + Vector(24, 0)
	end
end
function M.simulate_missing(index) M.cancel(index, "debug target removed") end

return M

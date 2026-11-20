-- Zennith arrival V2. Free sprite only: no NPC, no collision, no damage.
-- Reveal stays opaque. The column carries the body off the top of the screen,
-- then a screen-space dive ends in a solid white burst.

local M = {
	ANM2 = "gfx/boss/Zennith/Zennith.anm2",
	ANIM = "Idle",
	COVER_ANM2 = "gfx/boss/Zennith/storm/impact/impact_cover.anm2",
	COVER_ANIM = "Cover",
	COVER_FRAMES = 14,
	CANVAS = 256,
	HOVER_FRAMES = 18,
	SURGE_FRAMES = 14,
	ASCEND_FRAMES = 14,
	HOLD_FRAMES = 36,
	DIVE_FRAMES = 14,
}

local state = nil
local cover_sprite = nil

local function ease_in_cubic(u)
	u = math.max(0, math.min(1, u or 0))
	return u * u * u
end

local function ensure_sprite()
	local s = Sprite()
	s:Load(M.ANM2, true)
	s:Play(M.ANIM, true)
	return s
end

local function ensure_cover()
	if cover_sprite then return cover_sprite end
	local s = Sprite()
	local ok = pcall(function()
		s:Load(M.COVER_ANM2, true)
		s:Play(M.COVER_ANIM, true)
	end)
	if not ok then return nil end
	cover_sprite = s
	return cover_sprite
end

function M.clear()
	state = nil
end

function M.is_active()
	return state ~= nil and state.active == true
end

function M.get_phase()
	return state and state.phase or "idle"
end

function M.is_finished()
	return state ~= nil and state.phase == "done"
end

function M.is_screen_covered()
	return state ~= nil and state.screen_covered == true
end

function M.should_draw_actor()
	if not state or state.active ~= true or state.actor == false then return false end
	local phase = state.phase
	return phase ~= "offscreen_hold" and phase ~= "impact_cover" and phase ~= "done"
end

function M.release_actor()
	if not state then return end
	state.actor = false
end

function M.get_surge()
	if not state then return 1 end
	local phase = state.phase
	if phase == "wind_surge" then
		local u = (state.t or 0) / math.max(1, M.SURGE_FRAMES)
		return 1 + 0.7 * ease_in_cubic(u)
	end
	if phase == "ascend" then
		local u = (state.t or 0) / math.max(1, M.ASCEND_FRAMES)
		return 1.7 + 1.5 * ease_in_cubic(u)
	end
	if phase == "offscreen_hold" or phase == "dive" or phase == "impact_cover" or phase == "done" then
		return 3.2
	end
	return 1
end

local function capture_player_screen()
	local player = Game():GetPlayer(0)
	local room = Game():GetRoom()
	if not player or not room then
		local w = (Isaac.GetScreenWidth and Isaac.GetScreenWidth()) or 480
		local h = (Isaac.GetScreenHeight and Isaac.GetScreenHeight()) or 270
		return Vector(w * 0.5, h * 0.55)
	end
	local pos = player.Position + (player.PositionOffset or Vector(0, 0))
	return room:WorldToScreenPosition(pos)
end

local function screen_size()
	local w = (Isaac.GetScreenWidth and Isaac.GetScreenWidth()) or 480
	local h = (Isaac.GetScreenHeight and Isaac.GetScreenHeight()) or 270
	if w < 8 then w = 480 end
	if h < 8 then h = 270 end
	return w, h
end

local function farthest_corner(screen)
	local w, h = screen_size()
	local corners = {
		Vector(0, 0), Vector(w, 0), Vector(0, h), Vector(w, h),
	}
	local far = 1
	for i = 1, 4 do
		local d = (corners[i] - screen):Length()
		if d > far then far = d end
	end
	return far, w, h
end

--- opts.start_phase: hover | wind_surge | ascend | dive | impact_cover
function M.begin(center, opts)
	opts = opts or {}
	center = center or Game():GetRoom():GetCenterPos()
	local base = opts.base_anchor or Vector(center.X, center.Y)
	local top = opts.top_anchor or Vector(base.X, base.Y - (tonumber(opts.height) or 160))
	local start_phase = opts.start_phase or ((tonumber(opts.hover_frames) == 0 or opts.skip_hover) and "wind_surge" or "hover")
	local hover = tonumber(opts.hover_frames) or M.HOVER_FRAMES
	state = {
		active = true,
		actor = true,
		phase = start_phase,
		t = 0,
		hover_frames = hover,
		anchor = Vector(top.X, top.Y),
		base = Vector(base.X, base.Y),
		lift = 0,
		sprite = ensure_sprite(),
		impact_screen = nil,
		dive_scale = 1,
		screen_covered = false,
		cover_alpha = 0,
	}
	if start_phase == "dive" or start_phase == "impact_cover" then
		state.impact_screen = capture_player_screen()
		state.actor = start_phase ~= "impact_cover"
	end
	if start_phase == "impact_cover" then
		ensure_cover()
	end
	state.sprite:Play(M.ANIM, true)
	return true
end

function M.set_anchor(top)
	if not state or not top or state.actor == false then return end
	local phase = state.phase
	if phase == "hover" or phase == "wind_surge" or phase == "ascend" then
		state.anchor = Vector(top.X, top.Y)
	end
end

local function advance_phase(next_phase)
	state.phase = next_phase
	state.t = 0
	if next_phase == "dive" and not state.impact_screen then
		state.impact_screen = capture_player_screen()
	end
	if next_phase == "dive" then
		state.dive_u = 0
		state.dive_scale = 1
	end
	if next_phase == "impact_cover" then
		state.actor = false
		ensure_cover()
	end
end

function M.update()
	if not state or not state.active then return end
	state.t = (state.t or 0) + 1
	local t = state.t
	local phase = state.phase
	if phase == "hover" then
		if t >= (state.hover_frames or M.HOVER_FRAMES) then
			advance_phase("wind_surge")
		end
	elseif phase == "wind_surge" then
		if t >= M.SURGE_FRAMES then
			advance_phase("ascend")
		end
	elseif phase == "ascend" then
		local u = math.min(1, t / M.ASCEND_FRAMES)
		state.lift = 90 * ease_in_cubic(u)
		if u >= 1 then
			advance_phase("offscreen_hold")
		end
	elseif phase == "offscreen_hold" then
		state.lift = 90
		if t >= M.HOLD_FRAMES then
			advance_phase("dive")
		end
	elseif phase == "dive" then
		local u = math.min(1, t / M.DIVE_FRAMES)
		local e = ease_in_cubic(u)
		state.dive_u = e
		state.dive_scale = 1 + 0.5 * e
		if u >= 1 then
			advance_phase("impact_cover")
		end
	elseif phase == "impact_cover" then
		if t >= M.COVER_FRAMES then
			state.screen_covered = true
			state.cover_alpha = 1
			state.phase = "done"
		end
	end
end

function M.get_world_pos()
	if not state then return nil end
	local anchor = state.anchor or state.base
	return Vector(anchor.X, anchor.Y - (state.lift or 0))
end

function M.get_cover_alpha()
	if not state then return 0 end
	if state.screen_covered or state.phase == "done" then return 1 end
	return state.cover_alpha or 0
end

local function render_actor()
	local room = Game():GetRoom()
	local screen
	local sx, sy = 1, 1
	local alpha = 1
	if state.phase == "hover" then
		local ht = math.min(1, (state.t or 0) / math.max(1, state.hover_frames or 1))
		alpha = ht
		local pos = M.get_world_pos()
		screen = room:WorldToScreenPosition(pos)
	elseif state.phase == "dive" then
		local origin = state.impact_screen or capture_player_screen()
		local _, h = screen_size()
		local e = state.dive_u or 0
		local y0 = origin.Y - h * 0.75
		screen = Vector(origin.X, y0 + (origin.Y - y0) * e)
		local s = 1 + 0.5 * e
		sx = s
		sy = -s
		alpha = 1
	else
		local pos = M.get_world_pos()
		screen = room:WorldToScreenPosition(pos)
		alpha = 1
	end
	if not screen then return end
	state.sprite.Color = Color(1, 1, 1, alpha)
	state.sprite.Scale = Vector(math.max(0.2, sx), sy)
	state.sprite:Render(screen, Vector(0, 0), Vector(0, 0))
	state.sprite.Color = Color(1, 1, 1, 1)
	state.sprite.Scale = Vector(1, 1)
end

local function draw_cover_frame(frame_index, screen, scale, alpha)
	local spr = ensure_cover()
	if not spr or not screen then return false end
	local frame = math.max(0, math.min(M.COVER_FRAMES - 1, frame_index or 0))
	pcall(function()
		spr:SetFrame(M.COVER_ANIM, frame)
	end)
	spr.Color = Color(1, 1, 1, math.max(0, math.min(1, alpha or 1)))
	spr.Scale = Vector(scale, scale)
	spr:Render(screen, Vector(0, 0), Vector(0, 0))
	spr.Color = Color(1, 1, 1, 1)
	spr.Scale = Vector(1, 1)
	return true
end

function M.render()
	if not M.should_draw_actor() then return end
	if state.sprite then
		state.sprite:Update()
		render_actor()
	end
end

function M.render_burst()
	if not state or state.phase ~= "impact_cover" then return end
	local origin = state.impact_screen or capture_player_screen()
	local far = farthest_corner(origin)
	local scale = (far / (M.CANVAS * 0.5)) * 1.05
	local frame = math.max(0, (state.t or 1) - 1)
	draw_cover_frame(frame, origin, scale, 1)
end

function M.render_solid(alpha)
	alpha = math.max(0, math.min(1, tonumber(alpha) or 0))
	if alpha <= 0.01 then return false end
	local w, h = screen_size()
	local screen = Vector(w * 0.5, h * 0.5)
	local far = farthest_corner(screen)
	local scale = (far / (M.CANVAS * 0.5)) * 1.08
	return draw_cover_frame(M.COVER_FRAMES - 1, screen, scale, alpha) == true
end

function M.count_real_boss()
	local enums = require("Qing_Remaster_scripts.core.enums")
	local n = 0
	local list = Isaac.FindByType(996, enums.Enemies.Zennith, -1, false, false)
	for i = 1, #list do
		local ent = list[i]
		if ent and ent:Exists() and not ent:IsDead() then
			n = n + 1
		end
	end
	return n
end

return M

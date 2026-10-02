-- Reversed Sting tether: independent strands with fixed pentagram roots.
local C = require("Qing_Remaster_scripts.cards.sting_reversed.constants")

local M = {}

local link_sprite = nil

local function ensure_sprite()
	if link_sprite then
		return link_sprite
	end
	link_sprite = Sprite()
	link_sprite:Load(C.LINK_ANM2, true)
	link_sprite:Play("Idle", true)
	link_sprite:SetFrame("Idle", 0)
	return link_sprite
end

local function enemy_attach_radius(npc)
	local size = tonumber(npc and npc.Size) or 10
	local r = size * C.ENEMY_RADIUS_SCALE
	if npc and npc:IsBoss() then
		r = r * 1.15
	end
	return math.min(math.max(r, C.ENEMY_RADIUS_MIN), C.ENEMY_RADIUS_MAX)
end

local function strand_endpoints(start_pos, target_pos, npc)
	local delta = target_pos - start_pos
	local len = delta:Length()
	if len < 2 then
		return nil
	end
	local dir = delta / len
	local finish = target_pos - dir * math.max(1, enemy_attach_radius(npc) - C.ENEMY_EMBED)
	local seg = finish - start_pos
	if seg:Length() < 2 then
		return nil
	end
	return start_pos, finish, dir
end

local function bezier(p0, p1, p2, p3, t)
	local u = 1 - t
	return p0 * (u * u * u)
		+ p1 * (3 * u * u * t)
		+ p2 * (3 * u * t * t)
		+ p3 * (t * t * t)
end

local function build_controls(start, finish, strand, link)
	local delta = finish - start
	local len = delta:Length()
	if len < 1 then
		return start, start, start, finish
	end
	local dir = delta / len
	local perp = Vector(-dir.Y, dir.X)
	local seed = tonumber(strand.curve_seed) or 0
	local phase = (tonumber(strand.sway_phase) or 0) + Game():GetFrameCount() * 0.04
	local sway = 0
	if link.state == "attached" then
		sway = math.sin(phase) * C.CURVE_SWAY
	elseif link.state == "extending" then
		sway = math.sin(phase) * (C.CURVE_SWAY * 0.5)
	end
	local amp = C.CURVE_BASE + (seed % 5) * 0.25
	local p1 = start + dir * (len * 0.30) + perp * (amp + sway)
	local p2 = start + dir * (len * 0.70) + perp * (-amp * 0.75 + sway * 0.35)
	return start, p1, p2, finish
end

local function display_progress(link)
	local p = math.min(1, math.max(0, tonumber(link.progress) or 0))
	if link.state == "extending" then
		-- Ease-out cubic: shoots out, settles onto the body.
		local inv = 1 - p
		return 1 - inv * inv * inv
	elseif link.state == "retracting" then
		-- Ease-in quad on remaining length: natural start, snap home.
		local t = 1 - p
		return 1 - (t * t)
	end
	return p
end

local function sample_ellipse_point(rng, rx, ry)
	local theta = rng:RandomFloat() * math.pi * 2
	local r = math.sqrt(rng:RandomFloat())
	return Vector(math.cos(theta) * rx * r, math.sin(theta) * ry * r)
end

local function strand_too_close(strands, pos, min_dist)
	local min2 = min_dist * min_dist
	for _, s in ipairs(strands) do
		local d = pos - s.anchor_local
		if d:LengthSquared() < min2 then
			return true
		end
	end
	return false
end

function M.create_strand(rng, anchor_local)
	rng = rng or RNG()
	return {
		anchor_local = anchor_local or Vector.Zero,
		curve_seed = rng:RandomInt(1000),
		sway_phase = rng:RandomFloat() * math.pi * 2,
	}
end

function M.init_strands(ritual)
	if not ritual then
		return
	end
	ritual.strands = {
		M.create_strand(ritual.rng, Vector.Zero),
	}
end

-- Grow strands to 1 + completed. New roots are sampled once and frozen.
function M.ensure_strands(ritual)
	if not ritual then
		return
	end
	if type(ritual.strands) ~= "table" then
		M.init_strands(ritual)
	end
	local want = math.max(1, 1 + (tonumber(ritual.completed) or 0))
	local rx = C.ANCHOR_RADIUS_X * C.STRAND_INNER_SCALE
	local ry = C.ANCHOR_RADIUS_Y * C.STRAND_INNER_SCALE
	local rng = ritual.rng or RNG()
	local guard = 0
	while #ritual.strands < want and guard < 64 do
		guard = guard + 1
		local pos = sample_ellipse_point(rng, rx, ry)
		local ok = true
		for _ = 1, 12 do
			if not strand_too_close(ritual.strands, pos, C.STRAND_MIN_SPACING) then
				ok = true
				break
			end
			pos = sample_ellipse_point(rng, rx, ry)
			ok = false
		end
		if not ok then
			-- Accept last sample if spacing cannot be satisfied (dense packs).
			pos = sample_ellipse_point(rng, rx, ry)
		end
		ritual.strands[#ritual.strands + 1] = M.create_strand(rng, pos)
	end
end

function M.create_link(npc, rng)
	local hash = GetPtrHash(npc)
	rng = rng or RNG()
	return {
		target = npc,
		target_hash = hash,
		state = "extending",
		progress = 0,
		visual_end = npc.Position,
		last_target_pos = npc.Position,
		occupies_slot = true,
	}
end

function M.begin_retract(link, npc)
	if not link then
		return
	end
	if npc and npc.Position then
		link.last_target_pos = npc.Position
		link.visual_end = npc.Position
	elseif link.visual_end then
		link.last_target_pos = link.visual_end
	end
	link.target = nil
	link.target_hash = nil
	link.state = "retracting"
	if (tonumber(link.progress) or 0) <= 0 then
		link.progress = 1
	end
end

function M.tick_link(link, anchor)
	if not link or not anchor or not anchor:Exists() then
		return "dead"
	end

	local npc = link.target
	if link.state == "attached" then
		if npc and npc:Exists() and not npc:IsDead() then
			link.visual_end = npc.Position
			link.last_target_pos = npc.Position
			link.target_dead_seen = false
		else
			-- Visual freeze only. Gameplay completion / retract is owned by MC_POST_NPC_DEATH.
			link.target_dead_seen = true
			if npc and npc.Position then
				link.last_target_pos = npc.Position
				link.visual_end = npc.Position
			elseif link.last_target_pos then
				link.visual_end = link.last_target_pos
			end
		end
	elseif link.state == "extending" then
		if npc and npc:Exists() and not npc:IsDead() then
			link.visual_end = npc.Position
			link.last_target_pos = npc.Position
			link.target_dead_seen = false
		else
			link.target_dead_seen = true
			if link.last_target_pos then
				link.visual_end = link.last_target_pos
			end
		end
		link.progress = math.min(1, (tonumber(link.progress) or 0) + 1 / C.EXTEND_FRAMES)
		if link.progress >= 1 then
			link.state = "attached"
			link.progress = 1
		end
	elseif link.state == "retracting" then
		if link.last_target_pos then
			link.visual_end = link.last_target_pos
		end
		link.progress = math.max(0, (tonumber(link.progress) or 1) - 1 / C.RETRACT_FRAMES)
		if link.progress <= 0 then
			return "gone"
		end
	end
	return link.state
end

local function draw_segment(spr, a, b, alpha, bright)
	local delta = b - a
	local len = delta:Length()
	if len < 0.5 then
		return
	end
	local mid = (a + b) * 0.5
	-- Slight overlap hides Bézier segment seams on a continuous strip.
	local draw_len = len + 1.0
	spr.Color = Color(1, 0.18, 0.18, alpha, 0.25 + bright, 0, 0)
	spr.Rotation = delta:GetAngleDegrees() - 90
	spr.Scale = Vector(C.LINK_BASE_WIDTH + bright * 0.15, draw_len / C.LINK_TEX_H)
	spr:Render(Isaac.WorldToScreen(mid), Vector.Zero, Vector.Zero)
end

function M.render_link(link, ritual)
	local anchor = ritual and ritual.anchor
	if not link or not anchor or not anchor:Exists() then
		return
	end
	local vis_p = display_progress(link)
	if vis_p <= 0.01 then
		return
	end

	local strands = ritual.strands
	if type(strands) ~= "table" or #strands == 0 then
		return
	end

	local spr = ensure_sprite()
	local completed = tonumber(ritual.completed) or 0
	local pulse = 0.5 + 0.5 * math.sin(Game():GetFrameCount() * 0.12)
	local bright = math.min(completed * 0.06, 0.35)
	local alpha = C.LINK_BASE_ALPHA + 0.08 * pulse + bright * 0.2
	if link.state == "extending" then
		alpha = alpha * (0.65 + 0.35 * vis_p)
	elseif link.state == "retracting" then
		alpha = alpha * (0.45 + 0.55 * vis_p)
	end

	local samples = C.BEZIER_SAMPLES
	for _, strand in ipairs(strands) do
		local start_pos = anchor.Position + (strand.anchor_local or Vector.Zero)
		local start, finish = strand_endpoints(start_pos, link.visual_end, link.target)
		if start then
			local p0, p1, p2, p3 = build_controls(start, finish, strand, link)
			local prev = nil
			for i = 0, samples do
				local t = (i / samples) * vis_p
				local pt = bezier(p0, p1, p2, p3, t)
				if prev then
					draw_segment(spr, prev, pt, alpha, bright)
				end
				prev = pt
			end
		end
	end
end

function M.render_all(ritual)
	if not ritual or not ritual.anchor or not ritual.anchor:Exists() then
		return
	end
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	for _, link in pairs(ritual.links or {}) do
		M.render_link(link, ritual)
	end
end

return M

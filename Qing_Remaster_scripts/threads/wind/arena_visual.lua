-- Zennith Arena scene. Vanilla walls stay. One low-depth Effect is only a render anchor.
-- Its MC_POST_EFFECT_RENDER is the stone-board timing: after backdrop, before later entities.
-- arena_visual draws the opaque black plate, then the storm sprites. The anchor holds no art.

local arena_room = require("Qing_Remaster_scripts.threads.wind.arena_room")
local enums = require("Qing_Remaster_scripts.core.enums")
local lightning_paths = require("Qing_Remaster_scripts.threads.wind.arena_lightning_paths")

local ANCHOR_DATA = "qing_arena_render_anchor"
local ANCHOR_DEPTH = -8000

local ANM2 = "gfx/boss/Zennith/storm/arena/arena_background.anm2"
local SETTLE_FRAMES = 90

-- Covers are fractions of the room's on-screen span. The black plate covers the screen separately.
-- Rotating sheets are 768px with the cloud body still in the old 512px circle.
-- cover is multiplied by 768/512 so that body keeps the previous on-screen size.
local ROT_PAD = 768 / 512
local LAYERS = {
	-- Deep uses screen_diameter (not room_span) so the opaque square never leaves a hard edge.
	{id = "deep", anim = "Deep", pass = "back", group = "far", spin = 0, px = 128, cover = 1.12, cover_mode = "screen", tint = {0.10, 0.14, 0.22}},
	{id = "far", anim = "Far", pass = "back", group = "far", spin = 360 / 300, px = 768, cover = 1.15 * ROT_PAD},
	{id = "outer", anim = "Outer", pass = "back", group = "rings", spin = 360 / 210, px = 768, cover = 1.00 * ROT_PAD},
	{id = "middle", anim = "Middle", pass = "back", group = "rings", spin = 360 / 150, px = 768, cover = 0.74 * ROT_PAD},
	{id = "inner", anim = "Inner", pass = "back", group = "rings", spin = 360 / 105, px = 768, cover = 0.52 * ROT_PAD},
	{id = "floor", anim = "Floor", pass = "back", group = "floor", spin = 0, px = 512, cover = 0.40},
	{id = "mist", anim = "Mist", pass = "front", group = "front", spin = 360 / 100, px = 768, cover = 1.05 * ROT_PAD, kind = "mist"},
}

-- One lightning event. Update runs on MC_POST_UPDATE (30 Hz). The sheet is anchored once, then stays put.
local BOLT_FRAMES = 8
local BOLT_SPRITES = {
	{id = "bolt1", anim = "Bolt1"},
	{id = "bolt2", anim = "Bolt2"},
	{id = "bolt3", anim = "Bolt3"},
	{id = "bolt4", anim = "Bolt4"},
	{id = "halo1", anim = "Halo1"},
	{id = "cloud1", anim = "Cloud1"},
	{id = "diff1", anim = "Diffuse1"},
	{id = "halo2", anim = "Halo2"},
	{id = "cloud2", anim = "Cloud2"},
	{id = "diff2", anim = "Diffuse2"},
	{id = "halo3", anim = "Halo3"},
	{id = "cloud3", anim = "Cloud3"},
	{id = "diff3", anim = "Diffuse3"},
	{id = "halo4", anim = "Halo4"},
	{id = "cloud4", anim = "Cloud4"},
	{id = "diff4", anim = "Diffuse4"},
}
local bolt_rng = 20261115

local M = {
	_active = false,
	_ready = false,
	_error = nil,
	_mask = {far = true, rings = true, floor = true, front = true},
	_solid = false,
	_angle = {},
	_sprites = {},
	_assets_ok = false,
	_black_draws = 0,
}

local function anchor_variant()
	local v = enums.Entities and enums.Entities.Arena_Render_Anchor
	if type(v) ~= "number" or v < 0 then return nil end
	return v
end

local function render_path_ready()
	return ModCallbacks
		and ModCallbacks.MC_POST_EFFECT_RENDER
		and ModCallbacks.MC_POST_ROOM_RENDER_ENTITIES
		and anchor_variant() ~= nil
end

function M.remove_anchor()
	local v = anchor_variant()
	if not v then return end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, v, -1, false, false)) do
		if ent and ent.Exists and ent:Exists() then
			ent:Remove()
		end
	end
end

function M.is_anchor(effect)
	local v = anchor_variant()
	if not effect or not v then return false end
	return effect.Type == EntityType.ENTITY_EFFECT
		and effect.Variant == v
		and effect.GetData and effect:GetData()[ANCHOR_DATA] == true
end

function M.ensure_anchor()
	if select(1, arena_room.validate_current()) ~= true then
		M.remove_anchor()
		return nil
	end
	local v = anchor_variant()
	if not v then return nil end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, v, -1, false, false)) do
		if ent and ent.Exists and ent:Exists() then
			ent:GetData()[ANCHOR_DATA] = true
			ent.Visible = true
			ent.DepthOffset = ANCHOR_DEPTH
			local spr = ent:GetSprite()
			if spr then
				spr.Color = Color(1, 1, 1, 0, 0, 0, 0)
			end
			return ent
		end
	end
	local room = Game():GetRoom()
	local ent = Isaac.Spawn(EntityType.ENTITY_EFFECT, v, 0, room:GetCenterPos(), Vector.Zero, nil)
	if not ent then return nil end
	ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	ent.Visible = true
	ent.DepthOffset = ANCHOR_DEPTH
	ent:GetData()[ANCHOR_DATA] = true
	local spr = ent:GetSprite()
	if spr then
		spr.Color = Color(1, 1, 1, 0, 0, 0, 0)
	end
	return ent
end

local function thunder_id()
	local id = enums.SoundEffect and enums.SoundEffect.Zennith_Arena_Thunder
	if type(id) ~= "number" or id < 0 then return nil end
	return id
end

local function stop_arena_thunder()
	local id = thunder_id()
	if not id or not SFXManager then return end
	local sfx = SFXManager()
	if sfx.IsPlaying and sfx:IsPlaying(id) and sfx.Stop then
		sfx:Stop(id)
	end
end

function M.shutdown()
	stop_arena_thunder()
	M._thunder = nil
	M.remove_anchor()
	M._active = false
	M._ready = false
	M._sgid = nil
	M._failed = false
	M._rebuilds = 0
	M._settled = nil
	M._settle_frame = 0
	M._bolt = nil
	M._bolt_wait = nil
	M._bolt_request = false
	M._floor_alpha = 1
	M._settle = 1
end

function M.is_active()
	return M._active == true
end

function M.is_ready()
	return M._ready == true and M._assets_ok == true
end

function M.get_last_error()
	return M._error
end

function M.set_layer(group, enabled)
	if M._mask[group] == nil then return false end
	M._mask[group] = enabled == true
	return true
end

function M.set_solid_test(enabled)
	M._solid = enabled == true
	return true
end

function M.get_mask()
	return M._mask
end

function M.solid_test()
	return M._solid == true
end

function M.notify_battle_ended()
	if not M._settled then
		M._settled = true
		M._settle_frame = 0
	end
end

local function load_sprite(anim, id)
	local spr = Sprite()
	local ok, err = pcall(function()
		spr:Load(ANM2, true)
	end)
	if not ok or not (spr.IsLoaded and spr:IsLoaded()) then
		return nil, "anm2_load_failed:" .. tostring(id) .. ":" .. ANM2 .. ":" .. tostring(err)
	end
	spr:Play(anim, true)
	spr.PlaybackSpeed = 0
	if spr.GetAnimation and spr:GetAnimation() ~= anim then
		return nil, "animation_missing:" .. tostring(id) .. ":" .. tostring(anim)
	end
	return spr
end

function M.load_assets()
	if not render_path_ready() then
		M._assets_ok = false
		return false, "render_path_missing"
	end
	if M._assets_ok and M._sprites.deep and M._sprites.solid and M._sprites.bolt1 and M._sprites.halo1 and M._sprites.diff4 then
		return true
	end
	M._sprites = {}
	for i = 1, #LAYERS do
		local spec = LAYERS[i]
		local spr, err = load_sprite(spec.anim, spec.id)
		if not spr then
			M._sprites = {}
			M._assets_ok = false
			return false, err
		end
		M._sprites[spec.id] = spr
		if M._angle[spec.id] == nil then
			M._angle[spec.id] = 0
		end
	end
	local solid, serr = load_sprite("Solid", "solid")
	if not solid then
		M._sprites = {}
		M._assets_ok = false
		return false, serr
	end
	M._sprites.solid = solid
	for i = 1, #BOLT_SPRITES do
		local spec = BOLT_SPRITES[i]
		local bolt, berr = load_sprite(spec.anim, spec.id)
		if not bolt then
			M._sprites = {}
			M._assets_ok = false
			return false, berr
		end
		M._sprites[spec.id] = bolt
	end
	M._assets_ok = true
	M._error = nil
	return true
end

function M.ensure_ready()
	local in_arena, why = arena_room.validate_current()
	if not in_arena then
		return false, why
	end
	local sgid = arena_room.get_sgid()
	if M.is_ready() and M._sgid == sgid then
		return true
	end
	if M._sgid == sgid and M._failed then
		return false, M._error or "arena_visual_failed"
	end
	local loaded, lerr = M.load_assets()
	M._sgid = sgid
	if not loaded then
		M._failed = true
		M._error = lerr
		M._ready = false
		M._active = false
		return false, lerr
	end
	if not M.ensure_anchor() then
		M._failed = true
		M._error = "anchor_missing"
		M._ready = false
		M._active = false
		return false, M._error
	end
	M._failed = false
	M._error = nil
	M._ready = true
	M._active = true
	return true
end

local screen_size
local scene_metrics

local function bolt_rand()
	bolt_rng = (bolt_rng * 1103515245 + 12345) % 2147483648
	return bolt_rng / 2147483648
end

local function play_arena_thunder(volume, kind)
	local id = thunder_id()
	local pitch = 0.96 + bolt_rand() * 0.08
	local result = {
		id = id or -1,
		volume = volume,
		pitch = pitch,
		played = false,
		replaced = false,
		reason = nil,
	}
	if not id or not SFXManager then
		result.reason = "id_invalid"
	else
		local sfx = SFXManager()
		if sfx.IsPlaying and sfx:IsPlaying(id) and sfx.Stop then
			sfx:Stop(id)
			result.replaced = true
		end
		sfx:Play(id, volume, 0, false, pitch)
		result.played = true
		result.reason = kind or (result.replaced and "replaced" or "played")
	end
	M._thunder = result
	return result
end

local function thunder_volume_for(ev)
	if ev.glow_only or not ev.arcs or #ev.arcs == 0 then
		return 0.50 + bolt_rand() * 0.15
	end
	if ev.strong then return 1.00 end
	return 0.80
end

local function maybe_play_thunder(ev)
	if not ev or ev.thunder_checked or ev.age < 3 then return end
	ev.thunder_checked = true
	play_arena_thunder(thunder_volume_for(ev))
end

function M.preview_thunder(volume)
	return play_arena_thunder(volume or 0.80, "preview")
end

local function atan2(y, x)
	if math.atan2 then return math.atan2(y, x) end
	return math.atan(y, x)
end

local function rot_xy(x, y, deg)
	local rad = math.rad(deg)
	local c = math.cos(rad)
	local s = math.sin(rad)
	return x * c - y * s, x * s + y * c
end

local function inside_screen(x, y, w, h, margin)
	margin = margin or 0
	return x >= margin and y >= margin and x <= w - margin and y <= h - margin
end

local function segment_clears_floor(ax, ay, bx, by, cx, cy, limit)
	local abx, aby = bx - ax, by - ay
	local den = abx * abx + aby * aby
	if den < 1 then return false end
	local t = ((cx - ax) * abx + (cy - ay) * aby) / den
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	local dx = ax + abx * t - cx
	local dy = ay + aby * t - cy
	return dx * dx + dy * dy >= limit * limit
end

local function ray_exit(x, y, dx, dy, w, h)
	local best = nil
	local function consider(dist, delta)
		if delta > -1e-4 and delta < 1e-4 then return end
		local t = dist / delta
		if t > 0.5 and (not best or t < best) then best = t end
	end
	if dx < 0 then consider(-x, dx) elseif dx > 0 then consider(w - x, dx) end
	if dy < 0 then consider(-y, dy) elseif dy > 0 then consider(h - y, dy) end
	return best
end

local function place_trunk(path, ax, ay, bx, by, flip)
	local dx = path.end_x - path.start_x
	local dy = path.end_y - path.start_y
	if flip then dx = -dx end
	local tex = math.sqrt(dx * dx + dy * dy)
	if tex < 1 then return nil end
	local chord = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
	local scale = chord / tex
	local rotation = math.deg(atan2(by - ay, bx - ax) - atan2(dy, dx))
	local lx = path.start_x - path.pivot
	local ly = path.start_y - path.pivot
	if flip then lx = -lx end
	local rx, ry = rot_xy(lx * scale, ly * scale, rotation)
	return {
		slot = path.slot,
		scale = scale,
		rotation = rotation,
		flip = flip,
		pos_x = ax - rx,
		pos_y = ay - ry,
	}
end

local function map_local(path, placed, px, py)
	local lx = px - path.pivot
	local ly = py - path.pivot
	if placed.flip then lx = -lx end
	local rx, ry = rot_xy(lx * placed.scale, ly * placed.scale, placed.rotation)
	return placed.pos_x + rx, placed.pos_y + ry
end

local function prefer_inward(path, ax, ay, bx, by, cx, cy, radius)
	local best, best_score
	for flip_i = 0, 1 do
		local placed = place_trunk(path, ax, ay, bx, by, flip_i == 1)
		local score = 0
		if placed and path.forks then
			for i = 1, #path.forks do
				local fx, fy = map_local(path, placed, path.forks[i].x, path.forks[i].y)
				local ddx, ddy = fx - cx, fy - cy
				if ddx * ddx + ddy * ddy < (radius * 1.02) * (radius * 1.02) then
					score = score + 1
				end
			end
		end
		if placed and (not best or score > best_score) then
			best = placed
			best_score = score
		end
	end
	if not best or best_score < 1 then return nil end
	return best
end

-- Bridge: score the transformed trunk samples and fork tips, not only fork origins.
local function place_bridge(path, ax, ay, bx, by, cx, cy, radius, floor_r)
	local best, best_score
	local outer_limit = radius * 1.10
	local eye_limit = floor_r * 1.12
	for flip_i = 0, 1 do
		local placed = place_trunk(path, ax, ay, bx, by, flip_i == 1)
		if placed then
			local ok = true
			local score = 0
			local samples = path.samples
			if samples then
				for i = 1, #samples do
					local sx, sy = map_local(path, placed, samples[i].x, samples[i].y)
					local dist = math.sqrt((sx - cx) ^ 2 + (sy - cy) ^ 2)
					if dist < eye_limit then
						ok = false
						break
					end
					if dist <= outer_limit then
						score = score + 1
					elseif dist > outer_limit * 1.18 then
						ok = false
						break
					end
				end
			end
			local tips = path.tips
			if ok and tips then
				local tip_ok = 0
				for i = 1, #tips do
					local tx, ty = map_local(path, placed, tips[i].x, tips[i].y)
					local dist = math.sqrt((tx - cx) ^ 2 + (ty - cy) ^ 2)
					if dist < eye_limit then
						ok = false
						break
					end
					if dist <= outer_limit then
						tip_ok = tip_ok + 1
						score = score + 2
					elseif dist > outer_limit * 1.22 then
						-- Long tips that leave the storm wall become a second silhouette.
						ok = false
						break
					end
				end
				if tip_ok < math.max(1, math.floor(#tips * 0.5)) then
					ok = false
				end
			end
			if ok and (not best or score > best_score) then
				best = placed
				best_score = score
			end
		end
	end
	return best
end

local function paths_with(profile)
	local out = {}
	for i = 1, #lightning_paths do
		if lightning_paths[i].profile == profile then
			out[#out + 1] = lightning_paths[i]
		end
	end
	return out
end

local function edge_hits(edge, cx, cy, radius, w, h)
	local found = {}
	local function add(x, y)
		if x >= -8 and x <= w + 8 and y >= -8 and y <= h + 8 then
			found[#found + 1] = {x, y}
		end
	end
	local disc
	if edge == "top" then
		disc = radius * radius - cy * cy
		if disc >= 0 then
			local span = math.sqrt(disc)
			add(cx - span, 0)
			add(cx + span, 0)
		end
	elseif edge == "left" then
		disc = radius * radius - cx * cx
		if disc >= 0 then
			local span = math.sqrt(disc)
			add(0, cy - span)
			add(0, cy + span)
		end
	else
		disc = radius * radius - (w - cx) * (w - cx)
		if disc >= 0 then
			local span = math.sqrt(disc)
			add(w, cy - span)
			add(w, cy + span)
		end
	end
	return found
end

local function push_off(sx, sy, ex, ey, w, h, margin)
	if not inside_screen(sx, sy, w, h, 0) then return sx, sy end
	local dx, dy = ex - sx, ey - sy
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 1 then return nil end
	local dist = ray_exit(sx, sy, -dx / length, -dy / length, w, h)
	if not dist then return nil end
	return sx - (dx / length) * (dist + margin), sy - (dy / length) * (dist + margin)
end

local function finish_event(placed, kind, band, group)
	if not placed or placed.scale < 0.12 or placed.scale > 0.9 then return nil end
	local glow = kind == "glow"
	placed.kind = kind
	placed.band = band
	placed.group = group
	placed.age = 1
	placed.life = 18 + math.floor(bolt_rand() * 3)
	placed.glow_only = glow
	placed.strong = (not glow) and bolt_rand() >= 0.76
	return placed
end

local function try_entry(cx, cy, w, h, room_span)
	local choices = paths_with("entry")
	if #choices == 0 then return nil end
	local path = choices[1 + math.floor(bolt_rand() * #choices)]
	local radius = room_span * (0.70 + bolt_rand() * 0.08) * 0.5
	local floor_r = room_span * 0.20
	local weights = {
		math.max(0, radius - cy) + 8,
		math.max(0, radius - cx) + 8,
		math.max(0, radius - (w - cx)) + 8,
	}
	local names = {"top", "left", "right"}
	local roll = bolt_rand() * (weights[1] + weights[2] + weights[3])
	local edge = names[3]
	local acc = 0
	for i = 1, 3 do
		acc = acc + weights[i]
		if roll <= acc then
			edge = names[i]
			break
		end
	end
	local hits = edge_hits(edge, cx, cy, radius, w, h)
	if #hits == 0 then
		local ang = edge == "top" and -math.pi / 2 or (edge == "left" and math.pi or 0)
		ang = ang + math.rad((bolt_rand() - 0.5) * 30)
		local hx = cx + math.cos(ang) * radius
		local hy = cy + math.sin(ang) * radius
		local depth = edge == "top" and hy or (edge == "left" and hx or (w - hx))
		if depth > 40 then return nil end
		hits[1] = {hx, hy}
	end
	local hit = hits[1 + math.floor(bolt_rand() * #hits)]
	local ang = atan2(hit[2] - cy, hit[1] - cx) + math.rad((bolt_rand() - 0.5) * 24)
	local span = math.rad(26 + bolt_rand() * 28)
	local a0, a1 = ang - span * 0.5, ang + span * 0.5
	local first = {cx + math.cos(a0) * radius, cy + math.sin(a0) * radius}
	local second = {cx + math.cos(a1) * radius, cy + math.sin(a1) * radius}
	local function outside_score(point)
		if edge == "top" then return -point[2] end
		if edge == "left" then return -point[1] end
		return point[1] - w
	end
	local start_pt, end_pt
	if outside_score(first) >= outside_score(second) then
		start_pt, end_pt = first, second
	else
		start_pt, end_pt = second, first
	end
	local sx, sy = push_off(start_pt[1], start_pt[2], end_pt[1], end_pt[2], w, h, 10 + bolt_rand() * 40)
	if not sx or inside_screen(sx, sy, w, h, 0) or not inside_screen(end_pt[1], end_pt[2], w, h, 6) then
		return nil
	end
	if not segment_clears_floor(sx, sy, end_pt[1], end_pt[2], cx, cy, floor_r) then return nil end
	local mid_x = (sx + end_pt[1]) * 0.5
	local mid_y = (sy + end_pt[2]) * 0.5
	local mid_r = math.sqrt((mid_x - cx) ^ 2 + (mid_y - cy) ^ 2)
	if mid_r < radius * 0.72 or mid_r > radius * 1.08 then return nil end
	return finish_event(prefer_inward(path, sx, sy, end_pt[1], end_pt[2], cx, cy, radius), "entry", "outer", "rings")
end

local function try_bridge(cx, cy, w, h, room_span)
	local choices = paths_with("bridge")
	if #choices == 0 then return nil end
	local path = choices[1]
	local r1 = room_span * (0.70 + bolt_rand() * 0.08) * 0.5
	local r2 = room_span * 0.74 * (0.56 + bolt_rand() * 0.12) * 0.5
	local a1 = bolt_rand() * math.pi * 2
	local delta = math.rad(24 + bolt_rand() * 36)
	if bolt_rand() < 0.5 then delta = -delta end
	local a2 = a1 + delta
	local sx = cx + math.cos(a1) * r1
	local sy = cy + math.sin(a1) * r1
	local ex = cx + math.cos(a2) * r2
	local ey = cy + math.sin(a2) * r2
	if not inside_screen(sx, sy, w, h, 10) or not inside_screen(ex, ey, w, h, 10) then return nil end
	local chord = math.sqrt((ex - sx) ^ 2 + (ey - sy) ^ 2)
	if chord < room_span * 0.16 or chord > room_span * 0.42 then return nil end
	if not segment_clears_floor(sx, sy, ex, ey, cx, cy, room_span * 0.20 * 1.15) then return nil end
	local radius = math.max(r1, r2)
	local floor_r = room_span * 0.20
	return finish_event(place_bridge(path, sx, sy, ex, ey, cx, cy, radius, floor_r), "bridge", "outer", "rings")
end

local function try_glow(cx, cy, w, h, room_span)
	local choices = paths_with("glow")
	if #choices == 0 then return nil end
	local path = choices[1]
	local radius = room_span * (0.70 + bolt_rand() * 0.08) * 0.5
	local ang = bolt_rand() * math.pi * 2
	local px = cx + math.cos(ang) * radius
	local py = cy + math.sin(ang) * radius
	if not inside_screen(px, py, w, h, 18) then return nil end
	if (px - cx) ^ 2 + (py - cy) ^ 2 < (room_span * 0.20 * 1.8) ^ 2 then return nil end
	local tang = ang + math.pi / 2 + math.rad((bolt_rand() - 0.5) * 40)
	local half = room_span * 0.085
	local sx = px - math.cos(tang) * half
	local sy = py - math.sin(tang) * half
	local ex = px + math.cos(tang) * half
	local ey = py + math.sin(tang) * half
	return finish_event(place_trunk(path, sx, sy, ex, ey, bolt_rand() < 0.5), "glow", "far", "far")
end

local function spawn_bolt()
	local center, _reach, room_span = scene_metrics()
	if not center or not room_span then return nil end
	local w, h = screen_size()
	local cx, cy = center.X, center.Y
	local roll = bolt_rand()
	local order
	if roll < 0.60 then
		order = {try_entry, try_bridge, try_glow}
	elseif roll < 0.85 then
		order = {try_bridge, try_entry, try_glow}
	else
		order = {try_glow, try_entry, try_bridge}
	end
	for pass = 1, #order do
		for _try = 1, 16 do
			local ev = order[pass](cx, cy, w, h, room_span)
			if ev then return ev end
		end
	end
	return nil
end

function M.request_lightning()
	M._bolt_request = true
	return true
end

local function advance_lightning()
	if M._bolt_request then
		M._bolt_request = false
		M._bolt = spawn_bolt()
		if M._bolt then M._bolt_wait = nil else M._bolt_wait = 30 end
		return
	end
	if M._bolt then
		M._bolt.age = M._bolt.age + 1
		if M._bolt.age > (M._bolt.life or 18) then
			M._bolt = nil
			M._bolt_wait = 90 + math.floor(bolt_rand() * 91)
			return
		end
		maybe_play_thunder(M._bolt)
		return
	end
	if M._bolt_wait == nil then
		M._bolt_wait = 45 + math.floor(bolt_rand() * 46)
	end
	M._bolt_wait = M._bolt_wait - 1
	if M._bolt_wait <= 0 then
		M._bolt = spawn_bolt()
		if M._bolt then M._bolt_wait = nil else M._bolt_wait = 30 end
	end
end

function M.update()
	local in_arena = select(1, arena_room.validate_current())
	if not in_arena then
		if M._active or M._ready then
			M.shutdown()
		end
		return
	end
	if not M.is_ready() then
		M.ensure_ready()
	end
	if not M.is_ready() then return end
	M.ensure_anchor()
	local frame = Game():GetFrameCount()
	if M._settled then
		M._settle_frame = math.min(SETTLE_FRAMES, (M._settle_frame or 0) + 1)
		M._settle = 1 - 0.6 * (M._settle_frame / SETTLE_FRAMES)
	else
		M._settle = 1
	end
	M._floor_alpha = 0.94 + 0.06 * math.sin(frame / 40)
	advance_lightning()
	for i = 1, #LAYERS do
		local spec = LAYERS[i]
		M._angle[spec.id] = (M._angle[spec.id] or 0) + (spec.spin or 0)
	end
end

screen_size = function()
	local w = (Isaac.GetScreenWidth and Isaac.GetScreenWidth()) or 480
	local h = (Isaac.GetScreenHeight and Isaac.GetScreenHeight()) or 270
	if w < 8 then w = 480 end
	if h < 8 then h = 270 end
	return w, h
end

--- Screen diameter hides the vanilla room. Room span sizes the storm so the rings stay readable.
scene_metrics = function()
	local room = Game():GetRoom()
	local center = Isaac.WorldToScreen(room:GetCenterPos())
	local tl = Isaac.WorldToScreen(room:GetTopLeftPos())
	local br = Isaac.WorldToScreen(room:GetBottomRightPos())
	local room_span = math.max(math.abs(br.X - tl.X), math.abs(br.Y - tl.Y), 80)
	local w, h = screen_size()
	local reach = 1
	local corners = {Vector(0, 0), Vector(w, 0), Vector(0, h), Vector(w, h)}
	for i = 1, 4 do
		local d = (corners[i] - center):Length()
		if d > reach then reach = d end
	end
	return center, reach * 2, room_span
end

local function draw_sprite(spr, screen, scale, rotation, alpha, tint, flip_x, frame)
	if not spr or alpha <= 0.01 then return end
	local r, g, b = 1, 1, 1
	if tint then
		r, g, b = tint[1] or 1, tint[2] or 1, tint[3] or 1
	end
	spr.Scale = Vector(scale, scale)
	spr.Rotation = rotation or 0
	spr.FlipX = flip_x == true
	spr.Color = Color(r, g, b, alpha)
	-- Set the frame immediately before Render. One cached sprite can draw several arcs.
	if frame then
		spr:SetFrame(frame)
	end
	spr:Render(screen, Vector(0, 0), Vector(0, 0))
	spr.Color = Color(1, 1, 1, 1)
	spr.Scale = Vector(1, 1)
	spr.Rotation = 0
	spr.FlipX = false
end

-- Matches scripts/dev/generate_zennith_arena_assets.py _preview_visual.
local function strike_visual(age, life)
	if age < 1 then return nil end
	local t = (age - 0.5) / life
	if t < 0.10 then
		return {bolt = 0, halo = 0, cloud = 0.16, diffuse = 0.10}
	elseif t < 0.28 then
		local u = (t - 0.10) / 0.18
		return {frame = math.min(2, math.floor(u * 3)), bolt = 0.45 + 0.4 * u, halo = 0.15 * u, cloud = 0.18 + 0.12 * u, diffuse = 0.10}
	elseif t < 0.42 then
		local u = (t - 0.28) / 0.14
		return {frame = 3 + math.min(2, math.floor(u * 3)), bolt = 0.82, halo = 0.35, cloud = 0.40, diffuse = 0.14}
	elseif t < 0.55 then
		return {frame = 5, bolt = 1, halo = 0.55, cloud = 0.58, diffuse = 0.20}
	elseif t < 0.72 then
		local u = (t - 0.55) / 0.17
		local bolt = u < 0.45 and (0.22 + u * 0.7) or (0.55 - (u - 0.45) * 0.5)
		return {frame = 7, bolt = bolt, halo = 0.40, cloud = 0.48, diffuse = 0.16}
	end
	local u = math.min(1, (t - 0.72) / 0.28)
	return {bolt = 0, halo = 0.32 * (1 - u), cloud = 0.40 * (1 - u), diffuse = 0.18 * (1 - u)}
end

local function draw_strike(layer_id, _screen, _room_span, settle)
	local ev = M._bolt
	if not ev or ev.band ~= layer_id or not ev.pos_x then return end
	if M._mask[ev.group] == false then return end
	local vis = strike_visual(ev.age, ev.life or 18)
	if not vis then return end
	local slot = ev.slot or 1
	local pos = Vector(ev.pos_x, ev.pos_y)
	local rot = ev.rotation or 0
	local scale = ev.scale or 0.4
	local bolt_mul = ev.kind == "glow" and 0.35 or 1
	local light_mul = ev.kind == "glow" and 1.35 or 1
	draw_sprite(M._sprites["diff" .. slot], pos, scale * 1.18, rot, (vis.diffuse or 0) * settle * light_mul, nil, ev.flip, 0)
	draw_sprite(M._sprites["cloud" .. slot], pos, scale * 1.06, rot, (vis.cloud or 0) * settle * light_mul, nil, ev.flip, 0)
	draw_sprite(M._sprites["halo" .. slot], pos, scale, rot, (vis.halo or 0) * settle * light_mul, nil, ev.flip, 0)
	if vis.frame and vis.bolt > 0 then
		local frame = math.max(0, math.min(BOLT_FRAMES - 1, vis.frame))
		draw_sprite(
			M._sprites["bolt" .. slot], pos, scale, rot,
			vis.bolt * settle * bolt_mul,
			nil, ev.flip, frame
		)
	end
end

local function draw_black(screen, screen_diameter)
	if not M._sprites.solid then return end
	draw_sprite(M._sprites.solid, screen, (screen_diameter * 1.08) / 64, 0, 1, {0, 0, 0})
	M._black_draws = (M._black_draws or 0) + 1
end

local function draw_pass(pass)
	if not M.is_ready() then return end
	if select(1, arena_room.validate_current()) ~= true then return end
	local screen, screen_diameter, room_span = scene_metrics()
	local settle = M._settle or 1
	local sw, sh = screen_size()
	if pass == "back" then
		draw_black(screen, screen_diameter)
		if M._solid then return end
	end
	for i = 1, #LAYERS do
		local spec = LAYERS[i]
		if spec.pass == pass then
			local alpha = M._mask[spec.group] ~= false and 1 or 0
			alpha = alpha * settle
			if spec.id == "floor" then
				alpha = alpha * (M._floor_alpha or 1)
			elseif spec.kind == "mist" then
				alpha = alpha * 0.42
			end
			local span = room_span
			if spec.cover_mode == "screen" or spec.id == "deep" then
				span = screen_diameter
			end
			local scale = (span * spec.cover) / spec.px
			if spec.id == "deep" then
				M._deep_scale = scale
				M._deep_span = span
				M._deep_cover = spec.cover
				M._screen_w = sw
				M._screen_h = sh
				M._screen_diameter = screen_diameter
				M._room_span = room_span
			end
			draw_sprite(M._sprites[spec.id], screen, scale, M._angle[spec.id] or 0, alpha, spec.tint)
			if pass == "back" then
				draw_strike(spec.id, screen, room_span, settle)
			end
		end
	end
end

function M.render_background()
	draw_pass("back")
end

function M.render_foreground()
	if M._solid then return end
	draw_pass("front")
end

function M.get_diagnostics()
	local loaded = 0
	for _, spr in pairs(M._sprites or {}) do
		if spr then loaded = loaded + 1 end
	end
	return {
		ready = M.is_ready(),
		error = M._error,
		art_effects = 0,
		backdrop_carriers = 0,
		backdrop_alive = false,
		sprites_loaded = loaded,
		black_draws = M._black_draws or 0,
		deep_scale = M._deep_scale,
		deep_span = M._deep_span,
		deep_cover = M._deep_cover,
		screen_w = M._screen_w,
		screen_h = M._screen_h,
		screen_diameter = M._screen_diameter,
		room_span = M._room_span,
		render_back = "MC_POST_EFFECT_RENDER",
		render_front = "MC_POST_ROOM_RENDER_ENTITIES",
		render_carrier = anchor_variant() ~= nil,
		carrier_variant = anchor_variant(),
		vanilla_backdrop = "kept",
		wall_limit = "opaque black plate on the low-depth anchor, after backdrop and before later entities",
		bolt = M._bolt and (tostring(M._bolt.kind) .. ":" .. tostring(M._bolt.slot) .. "@" .. tostring(M._bolt.age)) or "-",
		thunder_id = thunder_id() or -1,
		thunder_played = M._thunder and M._thunder.played == true or false,
		thunder_volume = M._thunder and M._thunder.volume or 0,
		thunder_replaced = M._thunder and M._thunder.replaced == true or false,
		thunder_skipped = M._thunder and M._thunder.reason or "-",
	}
end

return M

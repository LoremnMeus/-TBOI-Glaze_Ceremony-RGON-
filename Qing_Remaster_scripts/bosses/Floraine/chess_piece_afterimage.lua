-- Chess piece dash afterimages: history samples drawn with a dedicated Sprite.
-- Never mutates the live NPC Sprite (hurt flash / pivot / anim stay native).
-- Record / age / damage on Update (30Hz); Render only reads and draws.
--
-- Gold: each sample owns distance_remaining (param1) + fade_remaining (param2).
-- Param1 drains with subsequent piece travel; alpha softens with remaining distance.
-- When param1 hits 0 → FADING starts (param2 frames), damage off, then delete.
-- New moves must NOT clear gold samples or path meters (see reset_normal_action_trail).

local defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local fdefs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")

local afterimage = {}

local RECORD_EVERY = 2 -- logic frames between samples (normal trail)
local MIN_DIST = 10 -- world units; skip near-duplicate samples (normal)
local LIFE_FRAMES = 8
local ghost_by_kind = {}
local player_hit_cd = {} -- ControllerIndex / PtrHash → frames remaining
local last_cd_decay_frame = -1 -- Game():GetFrameCount(); decay shared CD once per logic frame

local function gold_cfg()
	return fdefs.P1_GOLD_AFTERIMAGE or {}
end

local function distance_life()
	return math.max(1, tonumber(gold_cfg().fade_start_distance) or 160)
end

local function fade_frames_gold()
	return math.max(1, tonumber(gold_cfg().fade_frames) or 10)
end

local function alpha0_gold()
	return tonumber(gold_cfg().alpha0) or 0.85
end

--- α = alpha0 * (floor + span * d_remain/life); soft early fade, still readable.
local function alpha_from_distance(d_remain, life, alpha0)
	life = math.max(1, life or distance_life())
	alpha0 = alpha0 or alpha0_gold()
	local floor_mul = tonumber(gold_cfg().alpha_floor_mul) or 0.65
	local span_mul = tonumber(gold_cfg().alpha_distance_mul) or 0.35
	local t = math.max(0, math.min(1, (d_remain or 0) / life))
	return alpha0 * (floor_mul + span_mul * t)
end

local function ensure_ghost(kind)
	kind = tonumber(kind) or defs.KIND.PAWN
	local ghost = ghost_by_kind[kind]
	if ghost then
		return ghost
	end
	local profile = defs.get(kind)
	ghost = Sprite()
	ghost:Load(defs.ANM2, true)
	ghost:ReplaceSpritesheet(0, profile.spritesheet)
	ghost:ReplaceSpritesheet(1, defs.outline_sheet(kind))
	ghost:LoadGraphics()
	ghost:Play("Idle", true)
	ghost_by_kind[kind] = ghost
	return ghost
end

local function set_ghost_layer(ghost, layer_id, rgb, alpha, visible)
	if not ghost or not ghost.GetLayer then
		return
	end
	local ok, layer = pcall(function()
		return ghost:GetLayer(layer_id) or ghost:GetLayer(layer_id == "outline" and 1 or 0)
	end)
	if not ok or not layer then
		return
	end
	if layer.SetVisible then
		layer:SetVisible(visible ~= false and (alpha or 0) > 0.01)
	end
	if layer.SetColor then
		layer:SetColor(Color(
			(rgb and rgb[1]) or 1,
			(rgb and rgb[2]) or 1,
			(rgb and rgb[3]) or 1,
			alpha or 0,
			0, 0, 0
		))
	end
end

local function trail_cap(profile, is_gold)
	if is_gold then
		local n = tonumber(gold_cfg().max_samples) or 16
		return math.max(1, math.floor(n))
	end
	local n = profile and tonumber(profile.afterimage_count)
	if not n or n < 1 then
		return 3
	end
	return math.min(4, math.floor(n))
end

local function life_frames_normal()
	return LIFE_FRAMES
end

local function push_sample(list, sample, cap, prefer_drop_fading)
	list[#list + 1] = sample
	while #list > cap do
		local drop = 1
		if prefer_drop_fading then
			for i = 1, #list - 1 do
				if list[i].phase == "FADING" then
					drop = i
					break
				end
			end
		end
		table.remove(list, drop)
	end
end

--- Drain param1 on every gold sample; start param2 when distance hits 0.
local function apply_gold_travel_delta(list, delta)
	if not list or not delta or delta <= 0 then
		return
	end
	local life = distance_life()
	local fade_n = fade_frames_gold()
	local a0 = alpha0_gold()
	for i = 1, #list do
		local sample = list[i]
		if sample and sample.gold then
			if sample.phase ~= "FADING" then
				local d = math.max(0, (sample.distance_remaining or life) - delta)
				sample.distance_remaining = d
				sample.alpha = alpha_from_distance(d, life, a0)
				if d <= 0 then
					sample.phase = "FADING"
					sample.fade_remaining = fade_n
					sample.fade_from_alpha = sample.alpha
					sample.alpha = sample.fade_from_alpha
				else
					sample.phase = "ACTIVE"
				end
			end
		end
	end
end

local function record_normal(ent, data, list, profile)
	data._ai_record_cd = (data._ai_record_cd or 0) - 1
	if data._ai_record_cd > 0 then
		return
	end
	data._ai_record_cd = RECORD_EVERY
	local pos = Vector(ent.Position.X, ent.Position.Y)
	local last = list[#list]
	local min_d = tonumber(data._ai_min_dist) or MIN_DIST
	if min_d < MIN_DIST then
		min_d = MIN_DIST
	end
	if last and last.position then
		local dx = pos.X - last.position.X
		local dy = pos.Y - last.position.Y
		if (dx * dx + dy * dy) < (min_d * min_d) then
			return
		end
	end
	push_sample(list, {
		position = pos,
		height = data.visual_height or 0,
		rotation = data.visual_tilt or 0,
		scale = data.visual_scale or 1,
		age = 0,
		kind = data.kind,
		gold = false,
	}, trail_cap(profile, false), false)
end

--- Distance-sampled gold trail; samples keep independent distance/fade params.
local function record_gold(ent, data, list, profile)
	local cfg = gold_cfg()
	local sample_d = math.max(4, tonumber(cfg.sample_distance) or 32)
	local life = distance_life()
	local a0 = alpha0_gold()
	local pos = Vector(ent.Position.X, ent.Position.Y)
	local last = data._gold_last_position
	if not last then
		-- Seed meters only; never wipe existing samples / totals on later calls.
		data._gold_last_position = Vector(pos.X, pos.Y)
		data._gold_total_distance = data._gold_total_distance or 0
		data._ai_gold_anchor = Vector(pos.X, pos.Y)
		return
	end
	local delta = pos - last
	local distance = delta:Length()
	if distance < 0.01 then
		return
	end
	-- Ignore absurd teleports (room snaps) so the trail does not flood.
	-- Keep samples and cumulative distance; only retarget the sampler.
	if distance > 240 then
		data._gold_last_position = Vector(pos.X, pos.Y)
		data._ai_gold_anchor = Vector(pos.X, pos.Y)
		return
	end

	-- Existing ghosts drain with this frame's travel before new births.
	apply_gold_travel_delta(list, distance)

	local path_start_total = data._gold_total_distance or 0
	local anchor = data._ai_gold_anchor or last
	local from_anchor = pos - anchor
	local remaining = from_anchor:Length()
	local max_burst = trail_cap(profile, true)
	local burst = 0
	while remaining >= sample_d and burst < max_burst do
		local direction = from_anchor / remaining
		local sample_pos = anchor + direction * sample_d
		push_sample(list, {
			position = Vector(sample_pos.X, sample_pos.Y),
			height = 0,
			rotation = data.visual_tilt or 0,
			scale = data.visual_scale or 1,
			kind = data.kind,
			gold = true,
			phase = "ACTIVE",
			distance_remaining = life,
			fade_remaining = nil,
			fade_from_alpha = nil,
			alpha = alpha_from_distance(life, life, a0),
			base_alpha = a0,
		}, max_burst, true)
		anchor = sample_pos
		from_anchor = pos - anchor
		remaining = from_anchor:Length()
		burst = burst + 1
		if remaining < 0.01 then
			break
		end
	end
	data._ai_gold_anchor = Vector(anchor.X, anchor.Y)
	data._gold_total_distance = path_start_total + distance
	data._gold_last_position = Vector(pos.X, pos.Y)
end

--- Call once per NPC Update while the piece is translating (or always for gold).
function afterimage.record(ent, data)
	if not ent or not data then
		return
	end
	local is_gold = data.is_gold == true
	local st = data.action_state
	if not is_gold then
		if st ~= "MOVING" and st ~= "ATTACKING" then
			return
		end
	end
	local profile = defs.get(data.kind)
	local list = data.afterimages
	if type(list) ~= "table" then
		list = {}
		data.afterimages = list
	end
	if is_gold then
		record_gold(ent, data, list, profile)
	else
		record_normal(ent, data, list, profile)
	end
end

--- Advance normal ages / gold fade timers on Update only (never in Render).
function afterimage.tick(data)
	if not data or type(data.afterimages) ~= "table" then
		return
	end
	local list = data.afterimages
	local write = 1
	for i = 1, #list do
		local sample = list[i]
		local keep = false
		if sample.gold then
			if sample.phase == "FADING" then
				local left = (sample.fade_remaining or 0) - 1
				sample.fade_remaining = left
				local from_a = sample.fade_from_alpha
					or alpha_from_distance(0, distance_life(), sample.base_alpha or alpha0_gold())
				local fade_n = fade_frames_gold()
				sample.alpha = from_a * math.max(0, left / fade_n)
				keep = left > 0
			else
				-- ACTIVE: alpha already refreshed when distance drained in record_gold.
				if sample.distance_remaining == nil then
					sample.distance_remaining = distance_life()
				end
				sample.alpha = alpha_from_distance(
					sample.distance_remaining,
					distance_life(),
					sample.base_alpha or alpha0_gold()
				)
				sample.phase = "ACTIVE"
				keep = true
			end
		else
			sample.age = (sample.age or 0) + 1
			keep = sample.age <= life_frames_normal()
		end
		if keep then
			list[write] = sample
			write = write + 1
		end
	end
	for i = write, #list do
		list[i] = nil
	end
end

local function player_key(player)
	if not player then
		return nil
	end
	if player.ControllerIndex ~= nil then
		return "c" .. tostring(player.ControllerIndex)
	end
	return "p" .. tostring(GetPtrHash(player))
end

--- Gold afterimage contact damage (shared per-player cooldown). ACTIVE / param1 only.
function afterimage.tick_damage(ent, data)
	if not ent or not data or data.is_gold ~= true then
		return
	end
	if type(data.afterimages) ~= "table" or #data.afterimages < 1 then
		return
	end
	local cfg = gold_cfg()
	local radius = tonumber(cfg.hit_radius) or 15
	local cd_max = tonumber(cfg.hit_cooldown) or 30
	local r2 = radius * radius
	local frame = Game():GetFrameCount()
	if frame ~= last_cd_decay_frame then
		last_cd_decay_frame = frame
		for k, v in pairs(player_hit_cd) do
			if v > 0 then
				player_hit_cd[k] = v - 1
			end
		end
	end
	local n = Game():GetNumPlayers()
	for i = 0, n - 1 do
		local player = Isaac.GetPlayer(i)
		if player and player:Exists() and not player:IsDead() then
			local key = player_key(player)
			if key and (player_hit_cd[key] or 0) <= 0 then
				local pp = player.Position
				for j = 1, #data.afterimages do
					local sample = data.afterimages[j]
					if sample and sample.gold
						and sample.phase == "ACTIVE"
						and (sample.distance_remaining or 0) > 0
						and sample.position then
						local dx = pp.X - sample.position.X
						local dy = pp.Y - sample.position.Y
						if (dx * dx + dy * dy) <= r2 then
							player:TakeDamage(
								1,
								0,
								EntityRef(ent),
								0
							)
							player_hit_cd[key] = cd_max
							break
						end
					end
				end
			end
		end
	end
end

--- New normal move/attack: drop short trail only. Never touches gold lifecycle.
function afterimage.reset_normal_action_trail(data)
	if not data then
		return
	end
	if data.is_gold == true then
		-- Keep gold samples + path meters across actions / royal drop.
		data._ai_record_cd = nil
		return
	end
	data.afterimages = nil
	data._ai_record_cd = nil
end

--- Full teardown: death / remove / leave room.
function afterimage.clear(data)
	if data then
		data.afterimages = nil
		data._ai_record_cd = nil
		data._ai_gold_anchor = nil
		data._gold_total_distance = nil
		data._gold_last_position = nil
	end
end

function afterimage.clear_player_cooldowns()
	player_hit_cd = {}
	last_cd_decay_frame = -1
end

--- Draw under the live piece (call from PRE_NPC_RENDER).
function afterimage.render(ent, data)
	if not ent or not data or type(data.afterimages) ~= "table" then
		return
	end
	local list = data.afterimages
	local cfg = gold_cfg()
	local gcol = cfg.color or { 1.0, 0.82, 0.28 }
	local ocol = cfg.outline_color or { 1.0, 0.92, 0.55 }
	local g_a0 = alpha0_gold()
	local o_a0 = tonumber(cfg.outline_alpha) or 0.90
	local draw_mul = tonumber(cfg.draw_mul) or 1.0
	for i = 1, #list do
		local sample = list[i]
		local is_gold = sample.gold == true
		local alpha
		if is_gold then
			alpha = tonumber(sample.alpha) or g_a0
		else
			local age = sample.age or 0
			alpha = 0.32 * (1 - age / life_frames_normal())
		end
		if alpha > 0.02 then
			local ghost = ensure_ghost(sample.kind or data.kind)
			ghost.Rotation = sample.rotation or 0
			local sc = sample.scale or 1
			ghost.Scale = Vector(sc, sc)
			ghost.Offset = Vector.Zero
			if is_gold then
				ghost.Color = Color(1, 1, 1, 1, 0, 0, 0)
				local body_a = alpha * draw_mul
				local outline_a = (alpha / g_a0) * o_a0 * draw_mul
				set_ghost_layer(ghost, "body", gcol, body_a, true)
				set_ghost_layer(ghost, "outline", ocol, outline_a, true)
			else
				set_ghost_layer(ghost, "outline", { 1, 1, 1 }, 0, false)
				set_ghost_layer(ghost, "body", { 1, 1, 1 }, 1, true)
				ghost.Color = Color(0.8, 0.86, 1, alpha, 0, 0, 0)
			end
			local world = sample.position + Vector(0, -(sample.height or 0))
			ghost:Render(Isaac.WorldToScreen(world), Vector.Zero, Vector.Zero)
		end
	end
end

return afterimage

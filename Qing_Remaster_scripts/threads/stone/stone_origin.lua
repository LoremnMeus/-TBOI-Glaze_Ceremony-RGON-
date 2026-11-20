-- Stone Giant Pawn: stationary destructible prop NPC (not a boss).
-- Stages 0–2 damageable; stage 3 (Pawn_03) final broken → invulnerable + board open.
-- Body sheets: Pawn_big → Pawn_01/02/03; burial stays on ground.png (floor-tinted).

local enums = require("Qing_Remaster_scripts.core.enums")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local route = require("Qing_Remaster_scripts.threads.stone.stone_route")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local occ = require("Qing_Remaster_scripts.threads.stone.stone_giant_pawn_occlusion")

local origin = {}

local DATA_KEY = "StoneGiantPawn"
local VARIANT = enums.Enemies.stone_giant_pawn
local ANM2 = "gfx/boss/Floraine/giant_pawn.anm2"
local BODY_SHEETS = {
	[0] = "gfx/boss/Floraine/Pawn_big.png",
	[1] = "gfx/boss/Floraine/Pawn_01.png",
	[2] = "gfx/boss/Floraine/Pawn_02.png",
	[3] = "gfx/boss/Floraine/Pawn_03.png",
}
local FINAL_STAGE = 3
local FINAL_HP_RATIO = 0.25
local BODY_ALPHA_NORMAL = 1.0
local BODY_ALPHA_OCCLUDED = 0.35
-- NPC Update is usually 30Hz; ~4–5 frames fade-in, ~5–6 fade-out.
local BODY_FADE_IN = (BODY_ALPHA_NORMAL - BODY_ALPHA_OCCLUDED) / 4.5
local BODY_FADE_OUT = (BODY_ALPHA_NORMAL - BODY_ALPHA_OCCLUDED) / 5.5

-- burial_mode: white | floor_color | pure_green (render-probe diagnostics only)
local VIS = {
	show_probe = false,
	base_hp = 30,
	burial_mode = "floor_color",
}

local debug_force_room = false
local STONE_DUST = Color(0.63, 0.59, 0.55, 1, 0, 0, 0)

-- Ground footprint GridPath under the burial base.
-- Docs: cost 900 is used by enemies and *degrades by 100 over time* — so we must
-- re-SetGridPath(900) every logic frame while the pawn (or remnant) exists.
-- Remnant (final broken) keeps marks until entity leave/remove.
local GRIDPATH_COST = 900
-- Full 3×3 grid neighborhood around feet (no circular radius cull; diagonal centers ≈56.57).
local FOOTPRINT_HALF = 1
local footprint_marks = {
	list_index = nil,
	-- gridIndex -> path value before we first claimed the cell (restore only this).
	saved = {},
	diag = {
		last_write_frame = -1,
		last_reapply_frame = -1,
		last_failure = "none",
		indices = {},
		expected_count = 0,
		marked_count = 0,
		samples = {}, -- idx -> {before, set_ok, after}
		post_update_decay = nil, -- set in origin.tick (POST_UPDATE): cells that dropped below 900
	},
}

local last_diag = {
	death_callback = false,
	npc_recognized = false,
	activate_ok = nil,
	activate_why = nil,
	expand_ok = nil,
	expand_why = nil,
	occlusion = false,
	player_behind = false,
	body_overlap = false,
	body_alpha = 1,
	burial_probe = nil,
}

local function rooms_mod()
	return require("Qing_Remaster_scripts.threads.stone.stone_rooms")
end

local function board_mod()
	return require("Qing_Remaster_scripts.threads.stone.stone_board")
end

local function encounter_mod()
	return require("Qing_Remaster_scripts.threads.stone.stone_encounter")
end

function origin.get_vis()
	return VIS
end

function origin.set_vis(patch)
	if type(patch) ~= "table" then return VIS end
	for k, v in pairs(patch) do
		if k == "burial_mode" and type(v) == "string" then
			if v == "white" or v == "floor_color" or v == "pure_green" then
				VIS.burial_mode = v
			end
		elseif VIS[k] == nil then
			-- skip unknown
		elseif type(v) == "number" or type(v) == "boolean" then
			VIS[k] = v
		end
	end
	return VIS
end

function origin.variant()
	return VARIANT
end

function origin.get_diag()
	return last_diag
end

--- Type identity only (safe in POST_NPC_DEATH; does not require Exists).
function origin.is_giant_pawn_type(ent)
	if ent == nil then return false end
	if ent.Type ~= 996 then return false end
	if VARIANT and ent.Variant == VARIANT then return true end
	local d = ent.GetData and ent:GetData()
	return d ~= nil and d[DATA_KEY] ~= nil
end

--- Living prop usable for damage / ensure lookups.
function origin.is_living_giant_pawn(ent)
	return origin.is_giant_pawn_type(ent)
		and ent.Exists
		and ent:Exists()
		and not (ent.IsDead and ent:IsDead())
end

--- Backward-compatible alias → living check (Update/Render).
function origin.is_giant_pawn(ent)
	return origin.is_living_giant_pawn(ent)
end

local function data_of(ent)
	if not ent then return nil end
	local d = ent:GetData()
	local row = d[DATA_KEY]
	if type(row) ~= "table" then
		row = {}
		d[DATA_KEY] = row
	end
	return row
end

--- Damage stage 0..3 from remaining HP (0 = intact, 3 = final broken look).
local function stage_from_ratio(ratio)
	if ratio > 0.75 then return 0 end
	if ratio > 0.50 then return 1 end
	if ratio > 0.25 then return 2 end
	return 3
end

local function floor_color_mod()
	return require("Qing_Remaster_scripts.threads.stone.stone_floor_color")
end

local function read_floor_modulation()
	return floor_color_mod().read_modulation(Game():GetRoom())
end

local function stamp_sample_timing(sample, room, world_pos, reason)
	if type(sample) ~= "table" then
		return sample
	end
	sample.sampled_at_game_frame = Game():GetFrameCount()
	sample.sampled_at_room_frame = room and room.GetFrameCount and room:GetFrameCount() or nil
	sample.sample_reason = reason or sample.sample_reason
	if world_pos then
		sample.sample_world = {x = world_pos.X, y = world_pos.Y}
	end
	return sample
end

--- Cache room modulation + sample texture RGB at world_pos (init / refresh only).
-- reason: "init" | "deferred" | "room_enter" | "probe_resample" | ...
function origin.cache_burial_floor_colors(world_pos, reason)
	local room = Game():GetRoom()
	local mod = floor_color_mod()
	local modulation = mod.read_modulation(room)
	local pos = world_pos or room:GetCenterPos()
	local texture = mod.sample_burial_ground(room, pos)
	stamp_sample_timing(texture, room, pos, reason or "cache")
	local r = runtime.get()
	if r.trigger then
		r.trigger.floor_modulation = modulation
		r.trigger.texture_rgb = texture
		-- Legacy key: burial tint used by resolve (prefer texture).
		r.trigger.floor_tint = texture
		r.trigger.texture_sample_at = {
			game_frame = texture.sampled_at_game_frame,
			room_frame = texture.sampled_at_room_frame,
			reason = texture.sample_reason,
		}
	end
	return texture, modulation
end

--- LEGACY name: now samples texture (with modulation fallback inside sample).
function origin.cache_room_floor_tint()
	local texture = origin.cache_burial_floor_colors(nil, "room_enter")
	return texture
end

local function shallow_rgb(t)
	if type(t) ~= "table" then return nil end
	return {
		r = t.r, g = t.g, b = t.b, a = t.a,
		ro = t.ro, go = t.go, bo = t.bo,
		source = t.source,
		mapping = t.mapping,
		texel = t.texel and {x = t.texel.x, y = t.texel.y} or nil,
		uv = t.uv and {u = t.uv.u, v = t.uv.v} or nil,
		image = t.image and {width = t.image.width, height = t.image.height} or nil,
		grid_index = t.grid_index,
		sampled_at_game_frame = t.sampled_at_game_frame,
		sampled_at_room_frame = t.sampled_at_room_frame,
		sample_reason = t.sample_reason,
		sample_world = t.sample_world,
	}
end

--- Probe / diagnostics: live cached Burial sample on pawn + trigger (not a fresh sample).
function origin.get_live_burial_sample()
	local room = Game():GetRoom()
	local out = {
		game_frame = Game():GetFrameCount(),
		room_frame = room and room.GetFrameCount and room:GetFrameCount() or nil,
		burial_mode = VIS.burial_mode,
		pawn_found = false,
		entity = nil,
		trigger = nil,
	}
	local r = runtime.get()
	if r.trigger then
		out.trigger = {
			texture_rgb = shallow_rgb(r.trigger.texture_rgb),
			floor_modulation = shallow_rgb(r.trigger.floor_modulation),
			texture_sample_at = r.trigger.texture_sample_at,
		}
	end
	local pawn = nil
	for _, ent in ipairs(Isaac.FindByType(996, -1, -1, false, false)) do
		if origin.is_living_giant_pawn(ent) then
			pawn = ent
			break
		end
	end
	if not pawn and VARIANT then
		for _, ent in ipairs(Isaac.FindByType(996, VARIANT, -1, false, false)) do
			if origin.is_living_giant_pawn(ent) then
				pawn = ent
				break
			end
		end
	end
	if not pawn then
		return out
	end
	local d = data_of(pawn)
	out.pawn_found = true
	out.entity = {
		ptr = GetPtrHash(pawn),
		pos = {x = pawn.Position.X, y = pawn.Position.Y},
		texture_rgb = shallow_rgb(d.texture_rgb),
		floor_modulation = shallow_rgb(d.floor_modulation),
		texture_refresh_pending = d.texture_refresh_pending == true,
		texture_refreshed = d.texture_refreshed == true,
		anchor = d.anchor and {x = d.anchor.X, y = d.anchor.Y} or nil,
	}
	return out
end

--- Force-resample production texture into living Giant Pawn (probe / recovery).
function origin.resample_burial_colors(reason)
	local pawn = nil
	for _, ent in ipairs(Isaac.FindByType(996, -1, -1, false, false)) do
		if origin.is_living_giant_pawn(ent) then
			pawn = ent
			break
		end
	end
	if not pawn then
		-- Still refresh room-level trigger cache at center.
		local texture, modulation = origin.cache_burial_floor_colors(nil, reason or "probe_resample")
		return false, "no_pawn", texture, modulation
	end
	local d = data_of(pawn)
	local pos = d.anchor or pawn.Position
	local texture, modulation = origin.cache_burial_floor_colors(pos, reason or "probe_resample")
	d.texture_rgb = texture
	d.floor_tint = texture
	d.floor_modulation = modulation
	d.texture_refresh_pending = false
	d.texture_refreshed = true
	-- Layer tint reapplies on next Update / PRE_NPC_RENDER (apply_layer_colors).
	return true, "ok", texture, modulation
end

local function maybe_deferred_texture_refresh(npc, d)
	if not d or d.texture_refresh_pending ~= true then
		return false
	end
	local room = Game():GetRoom()
	-- Wait until room has advanced at least one logic frame so floor buffer can settle.
	local room_frame = room and room.GetFrameCount and room:GetFrameCount() or 0
	if room_frame < 1 then
		return false
	end
	local pos = d.anchor or npc.Position
	local texture, modulation = origin.cache_burial_floor_colors(pos, "deferred")
	d.texture_rgb = texture
	d.floor_tint = texture
	d.floor_modulation = modulation
	d.texture_refresh_pending = false
	d.texture_refreshed = true
	return true
end

local function burial_tint_for(ent_data)
	if ent_data and type(ent_data.texture_rgb) == "table" then
		return ent_data.texture_rgb
	end
	if ent_data and type(ent_data.floor_tint) == "table" then
		return ent_data.floor_tint
	end
	local r = runtime.get()
	if r.trigger and type(r.trigger.texture_rgb) == "table" then
		return r.trigger.texture_rgb
	end
	if r.trigger and type(r.trigger.floor_tint) == "table" then
		return r.trigger.floor_tint
	end
	return read_floor_modulation()
end

local function color_approx_eq(a, b)
	if not a or not b then return false end
	local function n(x, d) return tonumber(x) or d end
	return math.abs(n(a.R, 1) - n(b.R, 1)) < 0.02
		and math.abs(n(a.G, 1) - n(b.G, 1)) < 0.02
		and math.abs(n(a.B, 1) - n(b.B, 1)) < 0.02
		and math.abs(n(a.A, 1) - n(b.A, 1)) < 0.02
end

local function resolve_burial_color(d)
	local mode = VIS.burial_mode or "floor_color"
	if mode == "pure_green" then
		return Color(0, 1, 0, 1, 0, 0, 0), mode
	end
	if mode == "white" then
		return Color(1, 1, 1, 1, 0, 0, 0), mode
	end
	-- Production: texture_rgb from GetFloorImage (Candidate B_grid_tiled). Do not also
	-- multiply Room:GetFloorColor — composed buffer already includes room modulation.
	local t = burial_tint_for(d)
	return Color(t.r or 1, t.g or 1, t.b or 1, 1, t.ro or 0, t.go or 0, t.bo or 0), mode
end

local function safe_get_layer(spr, id)
	if not spr or not spr.GetLayer or id == nil then
		return nil
	end
	local ok, layer = pcall(function()
		return spr:GetLayer(id)
	end)
	if ok then
		return layer
	end
	return nil
end

--- Layer colors only. Do NOT write whole Sprite.Color each frame — that kills native hurt flash.
-- Body alpha → body LayerState; burial tint → burial LayerState; engine owns Sprite.Color flash.
--- Must also run from MC_PRE_NPC_RENDER: ANM2 can overwrite LayerState between Update and draw.
local function apply_layer_colors(npc, d, opts)
	opts = opts or {}
	local spr = npc:GetSprite()
	if not spr then return end

	local body_a = d.body_alpha
	if type(body_a) ~= "number" then body_a = BODY_ALPHA_NORMAL end
	local burial_col, mode = resolve_burial_color(d)
	d.burial_color = burial_col

	if not (spr.GetLayer and REPENTOGON) then
		-- No LayerState: body alpha only; still avoid continuous white reset on PRE_RENDER.
		if not opts.skip_sprite_color then
			spr.Color = Color(1, 1, 1, body_a, 0, 0, 0)
		end
		return
	end

	local body = safe_get_layer(spr, "body") or safe_get_layer(spr, 0)
	local burial = safe_get_layer(spr, "burial") or safe_get_layer(spr, 1)
	if not body or not burial then
		if not opts.skip_sprite_color then
			spr.Color = Color(1, 1, 1, body_a, 0, 0, 0)
		end
		last_diag.burial_probe = {
			mode = mode,
			error = "missing_layer",
			floor = burial_tint_for(d),
		}
		return
	end

	if body.SetVisible then body:SetVisible(true) end
	if burial.SetVisible then burial:SetVisible(true) end

	local before = nil
	if not opts.skip_probe and burial.GetColor then
		before = burial:GetColor()
	end
	body:SetColor(Color(1, 1, 1, body_a, 0, 0, 0))
	burial:SetColor(burial_col)
	local after = burial.GetColor and burial:GetColor() or nil

	if opts.skip_probe then
		return
	end

	local sheet = nil
	if burial.GetSpritesheetPath then
		local ok, path = pcall(function() return burial:GetSpritesheetPath() end)
		if ok then sheet = path end
	end

	last_diag.burial_probe = {
		layer_name = burial.GetName and burial:GetName() or "burial",
		layer_id = burial.GetLayerID and burial:GetLayerID() or 1,
		visible = burial.IsVisible and burial:IsVisible() or true,
		sheet = sheet,
		mode = mode,
		before = before and {
			r = before.R, g = before.G, b = before.B, a = before.A,
		} or nil,
		after = after and {
			r = after.R, g = after.G, b = after.B, a = after.A,
		} or nil,
		readback_matches = color_approx_eq(after, burial_col),
		floor = burial_tint_for(d),
	}
end

function origin.apply_layer_colors_for_render(npc)
	if not origin.is_living_giant_pawn(npc) then return end
	local d = data_of(npc)
	-- Hot path: LayerState only — never overwrite Sprite.Color (hurt flash).
	apply_layer_colors(npc, d, {skip_probe = true, skip_sprite_color = true})
end

local function apply_body_sheet(spr, stage)
	stage = math.max(0, math.min(3, tonumber(stage) or 0))
	local path = BODY_SHEETS[stage] or BODY_SHEETS[0]
	spr:ReplaceSpritesheet(0, path)
	spr:LoadGraphics()
	spr:Play("Idle", true)
end

-- Break FX timeline (MC_NPC_UPDATE / ~30Hz): smoke over mask → swap sheet → settle.
local BREAK_SMOKE_FRAMES = 7
local BREAK_SWITCH_FRAME = 10
local BREAK_END_FRAME = 23

local function body_tex_to_world(npc, tex_x, tex_y)
	local body = occ.BODY
	local lx = (tex_x - body.pivot_x) * (body.x_scale ~= 0 and body.x_scale or 1)
	local ly = (tex_y - body.pivot_y) * (body.y_scale ~= 0 and body.y_scale or 1)
	local rad = math.rad(body.rotation or 0)
	local c = math.cos(rad)
	local s = math.sin(rad)
	local dx = lx * c - ly * s
	local dy = lx * s + ly * c
	return Vector(
		npc.Position.X + (body.x_pos or 0) + dx,
		npc.Position.Y + (body.y_pos or 0) + dy
	)
end

local function play_break_sounds(to_stage)
	-- Early cracks are brighter; later stages weight the deeper impact.
	local stage = tonumber(to_stage) or 1
	local crumble = 0.75 + stage * 0.08
	local impact = 0.35 + stage * 0.15
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_ROCK_CRUMBLE, crumble, 0.92 + stage * 0.03, false, 0, 2)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_STONE_IMPACT, impact, 1.0, false, 0, 1)
end

local function spawn_dust_at(world_pos, scale)
	local dust = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		EffectVariant.DUST_CLOUD,
		0,
		world_pos,
		Vector((math.random() - 0.5) * 0.6, (math.random() - 0.5) * 0.4 - 0.2),
		nil
	)
	if not dust then return end
	dust = dust:ToEffect() or dust
	dust:SetColor(Color(0.55, 0.5, 0.42, 0.9, 0.04, 0.03, 0.02), -1, 0, false, false)
	local sc = scale or (0.5 + math.random() * 0.25)
	dust.SpriteScale = Vector(sc, sc)
	local life = 12 + math.random(6)
	if dust.LifeSpan ~= nil then dust.LifeSpan = life end
	if dust.Timeout ~= nil then dust.Timeout = life end
end

local function pick_mask_world_points(npc, from_stage, to_stage, count)
	local base = occ.list_solid_cells(from_stage)
	local diff = occ.list_diff_cells(from_stage, to_stage)
	if #base < 1 then
		return {npc.Position}
	end
	local n_diff = math.floor(count * 0.3 + 0.5)
	if #diff < 1 then
		n_diff = 0
	end
	local n_base = count - n_diff
	local out = {}
	for _ = 1, n_base do
		local c = base[1 + math.random(#base) - 1]
		out[#out + 1] = body_tex_to_world(npc, c.tex_x, c.tex_y)
	end
	for _ = 1, n_diff do
		local c = diff[1 + math.random(#diff) - 1]
		out[#out + 1] = body_tex_to_world(npc, c.tex_x, c.tex_y)
	end
	return out
end

local function emit_break_particles(npc, from_stage, to_stage, burst)
	local count = burst and 14 or 8
	local points = pick_mask_world_points(npc, from_stage, to_stage, count)
	for i = 1, #points do
		spawn_dust_at(points[i], burst and 0.7 or 0.5)
	end
	-- A few rocks from mask points (not only center).
	local rock_n = burst and 6 or 3
	for i = 1, math.min(rock_n, #points) do
		Game():SpawnParticles(
			points[i],
			EffectVariant.ROCK_PARTICLE,
			1,
			3.5,
			STONE_DUST,
			-3
		)
	end
end

-- break_fx_phase: PRE_REVEAL (can merge pending) | POST_REVEAL (lock; queue next_pending_stage)
local function begin_break_fx(npc, d, new_stage)
	new_stage = math.max(0, math.min(FINAL_STAGE, tonumber(new_stage) or 0))
	local shown = d.damage_stage or 0
	if new_stage <= shown and not d.break_fx_active then
		return false
	end
	if d.break_fx_active then
		if d.break_fx_phase == "PRE_REVEAL" then
			if new_stage > (d.pending_stage or shown) then
				d.pending_stage = new_stage
			end
		else
			-- POST_REVEAL: sheet already shown; queue a following cycle only.
			local floor = d.damage_stage or shown
			if new_stage > floor then
				d.next_pending_stage = math.max(d.next_pending_stage or 0, new_stage)
			end
		end
		return true
	end
	d.break_fx_active = true
	d.break_fx_phase = "PRE_REVEAL"
	d.break_fx_elapsed = 0
	d.break_fx_from_stage = shown
	d.pending_stage = new_stage
	d.next_pending_stage = nil
	play_break_sounds(new_stage)
	emit_break_particles(npc, shown, new_stage, new_stage == FINAL_STAGE or (new_stage - shown) > 1)
	return true
end

local function tick_break_fx(npc, d)
	if not d.break_fx_active then
		return
	end
	d.break_fx_elapsed = (d.break_fx_elapsed or 0) + 1
	local t = d.break_fx_elapsed
	local from = d.break_fx_from_stage or d.damage_stage or 0
	local pending = d.pending_stage or from

	if t <= BREAK_SMOKE_FRAMES and (t % 2 == 1) then
		emit_break_particles(npc, from, pending, false)
	end

	if t == BREAK_SWITCH_FRAME then
		d.damage_stage = pending
		d.break_fx_phase = "POST_REVEAL"
		-- Lock this cycle's reveal; further damage goes to next_pending_stage.
		if npc.Exists and npc:Exists() then
			apply_body_sheet(npc:GetSprite(), pending)
			apply_layer_colors(npc, d)
		end
		if pending == FINAL_STAGE then
			-- Board opens when Pawn_03 is revealed under smoke, not on the damaging hit.
			origin.finish_breaking(npc, {skip_fx = true})
		end
	end

	if t >= BREAK_END_FRAME then
		d.break_fx_active = false
		d.break_fx_phase = nil
		d.break_fx_elapsed = 0
		local queued = d.next_pending_stage
		d.next_pending_stage = nil
		d.pending_stage = nil
		if not d.final_broken then
			local ratio = npc.HitPoints / math.max(0.01, npc.MaxHitPoints)
			local want = stage_from_ratio(ratio)
			if queued then
				want = math.max(want, queued)
			end
			if want > (d.damage_stage or 0) then
				begin_break_fx(npc, d, want)
			end
		end
	end
end

--- Legacy center burst (restore / debug force only).
local function play_stage_break_fx(pos, amount)
	amount = tonumber(amount) or 4
	play_break_sounds(amount >= 8 and 3 or 1)
	Game():SpawnParticles(pos, EffectVariant.ROCK_PARTICLE, amount, 4, STONE_DUST, -4)
	for i = 1, (amount >= 8 and 4 or 2) do
		spawn_dust_at(pos + Vector((math.random() - 0.5) * 10, -4), 0.55)
	end
end

function origin.resolve_anchor()
	return rooms_mod().resolve_origin_anchor()
end

local function room_list_index()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	return desc and desc.ListIndex or -1
end

local function collect_footprint_indices(npc)
	local room = Game():GetRoom()
	if not room or not npc then
		return {}
	end
	local anchor = npc.Position
	local center_idx = room:GetGridIndex(anchor)
	if type(center_idx) ~= "number" or center_idx < 0 then
		return {}
	end
	local width = room:GetGridWidth()
	local size = room:GetGridSize()
	local col = center_idx % width
	local row = math.floor(center_idx / width)
	local out = {}
	-- Exact 3×3 grid neighborhood around feet (9 cells when fully in-bounds).
	for dr = -FOOTPRINT_HALF, FOOTPRINT_HALF do
		for dc = -FOOTPRINT_HALF, FOOTPRINT_HALF do
			local c = col + dc
			local r = row + dr
			if c >= 0 and r >= 0 then
				local idx = r * width + c
				if idx >= 0 and idx < size then
					local world = room:GetGridPosition(idx)
					if room:IsPositionInRoom(world, 0) then
						out[#out + 1] = idx
					end
				end
			end
		end
	end
	if #out < 1 then
		out[1] = center_idx
	end
	return out
end

local function reset_footprint_diag()
	footprint_marks.diag = {
		last_write_frame = -1,
		last_reapply_frame = -1,
		last_failure = "none",
		indices = {},
		expected_count = 0,
		marked_count = 0,
		samples = {},
		post_update_decay = nil,
	}
end

--- Restore only cells this module previously marked (never blank the whole room).
function origin.clear_grid_footprint()
	local room = Game():GetRoom()
	if room and room.SetGridPath and room.GetGridPath then
		for idx, prev in pairs(footprint_marks.saved) do
			if type(idx) == "number" and type(prev) == "number" then
				room:SetGridPath(idx, prev)
			end
		end
	end
	footprint_marks.saved = {}
	footprint_marks.list_index = nil
	reset_footprint_diag()
end

--- Mark ground cells under the giant pawn every NPC Update.
--- Original GridPath is saved once; occupancy cost is force-written every call
--- because engine cost 900 degrades by 100 over time (see Room:SetGridPath docs).
function origin.update_grid_footprint(npc)
	if not origin.is_living_giant_pawn(npc) then
		return false
	end
	local room = Game():GetRoom()
	if not room or not room.SetGridPath or not room.GetGridPath then
		footprint_marks.diag.last_failure = "no_gridpath_api"
		return false
	end
	local li = room_list_index()
	if footprint_marks.list_index ~= nil and footprint_marks.list_index ~= li then
		-- Previous room's Path values are gone with the room; drop bookkeeping only.
		footprint_marks.saved = {}
		reset_footprint_diag()
	end
	footprint_marks.list_index = li

	local indices = collect_footprint_indices(npc)
	local desired = {}
	for _, idx in ipairs(indices) do
		desired[idx] = true
	end

	-- Release cells we no longer occupy (restore our saved original only).
	local release = {}
	for idx, prev in pairs(footprint_marks.saved) do
		if not desired[idx] then
			release[#release + 1] = {idx = idx, prev = prev}
		end
	end
	for _, row in ipairs(release) do
		room:SetGridPath(row.idx, row.prev)
		footprint_marks.saved[row.idx] = nil
	end

	local now = Game():GetFrameCount()
	local samples = {}
	local marked = 0
	local fail = "none"
	for idx in pairs(desired) do
		local before = room:GetGridPath(idx)
		if type(before) ~= "number" then
			before = 0
		end
		-- Save original once. Never overwrite with our 900 or a later degraded value.
		if footprint_marks.saved[idx] == nil then
			if before >= GRIDPATH_COST then
				-- Foreign / leftover high cost: still track so we can keep rewriting 900,
				-- but restore to 0 on release if we never observed a lower baseline.
				footprint_marks.saved[idx] = 0
			else
				footprint_marks.saved[idx] = before
			end
		end
		-- Unconditional per-logic-frame write (900 degrades otherwise).
		local set_ok = room:SetGridPath(idx, GRIDPATH_COST)
		local after = room:GetGridPath(idx)
		if type(after) ~= "number" then
			after = -1
		end
		samples[idx] = {before = before, set_ok = set_ok == true, after = after}
		if after == GRIDPATH_COST then
			marked = marked + 1
		else
			fail = "readback_not_900"
		end
		if set_ok == false then
			fail = "setgridpath_false"
		end
	end

	footprint_marks.diag.last_write_frame = now
	footprint_marks.diag.last_reapply_frame = now
	footprint_marks.diag.last_failure = fail
	footprint_marks.diag.indices = indices
	footprint_marks.diag.expected_count = #indices
	footprint_marks.diag.marked_count = marked
	footprint_marks.diag.samples = samples
	return fail == "none"
end

function origin.get_footprint_diag(npc)
	npc = npc or origin.find_room_pawn()
	local d = footprint_marks.diag or {}
	local pos = npc and npc.Position
	return {
		giant_pawn_exists = npc ~= nil and npc:Exists() == true,
		giant_pawn_position = pos and {x = pos.X, y = pos.Y} or nil,
		giant_pawn_final_broken = npc and data_of(npc) and data_of(npc).final_broken == true,
		footprint_indices = d.indices or {},
		footprint_expected_count = d.expected_count or 0,
		footprint_marked_count = d.marked_count or 0,
		last_gridpath_reapply_frame = d.last_reapply_frame or -1,
		last_gridpath_failure = d.last_failure or "none",
		samples = d.samples or {},
		post_update_decay = d.post_update_decay,
		saved_count = (function()
			local n = 0
			for _ in pairs(footprint_marks.saved) do n = n + 1 end
			return n
		end)(),
		gridpath_cost = GRIDPATH_COST,
	}
end

--- Force one footprint pass (debug / Inspect).
function origin.reapply_grid_footprint(npc)
	npc = npc or origin.find_room_pawn()
	if not npc then
		return false, "no_pawn"
	end
	local ok = origin.update_grid_footprint(npc)
	return ok, origin.get_footprint_diag(npc)
end

function origin.clear(opts)
	opts = opts or {}
	if not VARIANT then return end
	local kept = false
	for _, ent in ipairs(Isaac.FindByType(996, VARIANT, -1, false, false)) do
		local d = data_of(ent)
		if opts.sandbox_only and not (d and d.sandbox) then
			kept = true
		else
			ent:Remove()
		end
	end
	if not kept then
		origin.clear_grid_footprint()
	elseif origin.find_room_pawn() then
		origin.update_grid_footprint(origin.find_room_pawn())
	else
		origin.clear_grid_footprint()
	end
	debug_force_room = false
end

local function clamp_final_hp(npc)
	local max_hp = math.max(1, npc.MaxHitPoints)
	-- Pin to the final band so re-entry / inspect stay consistent at ~25%.
	npc.HitPoints = math.max(1, max_hp * FINAL_HP_RATIO)
end

local function init_npc(npc, opts)
	opts = opts or {}
	local d = data_of(npc)
	d.sandbox = opts.sandbox == true
	d.visual_only = opts.visual_only == true
	d.activated = false
	d.damage_stage = 0
	d.pending_stage = nil
	d.next_pending_stage = nil
	d.break_fx_active = false
	d.break_fx_phase = nil
	d.break_fx_elapsed = 0
	d.break_fx_from_stage = nil
	d.body_alpha = BODY_ALPHA_NORMAL
	d.anchor = Vector(npc.Position.X, npc.Position.Y)
	local texture, modulation = origin.cache_burial_floor_colors(d.anchor, "init")
	if opts.floor_tint then
		-- Explicit override (tests / restore); still record modulation separately.
		d.texture_rgb = opts.floor_tint
		d.floor_tint = opts.floor_tint
		d.texture_refresh_pending = false
		d.texture_refreshed = false
	else
		d.texture_rgb = texture
		d.floor_tint = texture
		-- NEW_ROOM / spawn often hits room_frame=0; floor image may still be settling.
		d.texture_refresh_pending = true
		d.texture_refreshed = false
	end
	d.floor_modulation = opts.floor_modulation or modulation

	npc.Velocity = Vector.Zero
	npc.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS
	npc.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	npc:AddEntityFlags(
		EntityFlag.FLAG_NO_STATUS_EFFECTS
		| EntityFlag.FLAG_NO_REWARD
		| EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK
		| EntityFlag.FLAG_NO_KNOCKBACK
	)
	-- Door-lock: entities2 Stone Giant Pawn shutdoors="false" only.
	-- Do not assign npc.CanShutDoors (RGON: non-writable userdata member).
	-- Gray/transparent splat: avoid red hit blood without ENTCOLL_NONE.
	npc.SplatColor = Color(0.55, 0.5, 0.42, 0, 0, 0, 0)

	local max_hp = tonumber(VIS.base_hp) or 30
	npc.MaxHitPoints = max_hp

	local r = runtime.get()
	local final_broken = opts.final_broken == true
		or (not opts.sandbox and r.trigger and r.trigger.pawn_final_broken == true)

	local ratio = opts.hp_ratio
	if ratio == nil and r.trigger then
		ratio = r.trigger.pawn_hp_ratio
	end

	local spr = npc:GetSprite()
	spr:Load(ANM2, true)
	spr.Offset = Vector.Zero
	spr.Color = Color(1, 1, 1, 1, 0, 0, 0)

	if final_broken then
		d.final_broken = true
		d.damage_stage = FINAL_STAGE
		d.activated = (r.board and r.board.activated) and true or d.activated
		npc.HitPoints = math.max(1, max_hp * FINAL_HP_RATIO)
		apply_body_sheet(spr, FINAL_STAGE)
	else
		d.final_broken = false
		if type(ratio) == "number" then
			ratio = math.max(FINAL_HP_RATIO + 0.01, math.min(1, ratio))
			npc.HitPoints = max_hp * ratio
		else
			npc.HitPoints = max_hp
		end
		d.damage_stage = stage_from_ratio(npc.HitPoints / math.max(0.01, npc.MaxHitPoints))
		apply_body_sheet(spr, d.damage_stage)
	end

	apply_layer_colors(npc, d)
	npc.Visible = true
	origin.update_grid_footprint(npc)
	return d
end

--- Spawn / restore giant pawn. Remnant Pawn_03 stays after board activation.
function origin.ensure(opts)
	opts = opts or {}
	if not VARIANT then
		return false, "no_variant"
	end
	local r0 = runtime.get()
	local final_broken = r0.trigger and r0.trigger.pawn_final_broken == true

	if runtime.is_board_active() and not opts.sandbox and not opts.visual_only then
		if not final_broken and not opts.force then
			origin.clear()
			return false, "board_active"
		end
		-- Board already open + final broken → keep / restore Pawn_03 remnant.
	end

	if r0.trigger and r0.trigger.pawn_destroyed and not final_broken
		and not opts.sandbox and not opts.force then
		return false, "already_destroyed"
	end

	local force = opts.force == true or debug_force_room
	if not force and not route.is_trigger_room() then
		return false, "not_trigger"
	end

	for _, ent in ipairs(Isaac.FindByType(996, VARIANT, -1, false, false)) do
		if origin.is_living_giant_pawn(ent) then
			local d = data_of(ent)
			if final_broken and d and not d.final_broken and not opts.sandbox then
				origin.finish_breaking(ent, { restore_only = true })
			end
			return true, "exists", ent
		end
	end

	local allow_fallback = opts.allow_fallback
	if allow_fallback == nil then allow_fallback = false end
	local pos, why = rooms_mod().find_safe_origin_anchor({ allow_fallback = allow_fallback })
	if not pos then
		return false, why or "origin_no_safe_anchor"
	end
	local r = runtime.get()
	if r.trigger then
		r.trigger.anchor = {x = pos.X, y = pos.Y}
		r.trigger.anchor_reason = why
	end

	local spawn_opts = {
		sandbox = opts.sandbox,
		visual_only = opts.visual_only,
	}
	if final_broken and not opts.sandbox then
		spawn_opts.final_broken = true
		spawn_opts.hp_ratio = FINAL_HP_RATIO
	elseif opts.hp_ratio ~= nil then
		spawn_opts.hp_ratio = opts.hp_ratio
	end

	local npc = Isaac.Spawn(996, VARIANT, 0, pos, Vector.Zero, nil):ToNPC()
	if not npc then
		return false, "spawn_failed"
	end
	init_npc(npc, spawn_opts)
	return true, why or "ok", npc
end

function origin.debug_place_in_current_room()
	if VARIANT then
		for _, ent in ipairs(Isaac.FindByType(996, VARIANT, -1, false, false)) do
			if origin.is_living_giant_pawn(ent) then
				local d = data_of(ent)
				if d and not d.sandbox then
					return false, "story_pawn_exists", ent
				end
			end
		end
	end
	debug_force_room = true
	origin.clear({ sandbox_only = true })
	local ok, why, ent = origin.ensure({
		force = true,
		sandbox = true,
		visual_only = true,
		allow_fallback = false,
	})
	if not ok then
		debug_force_room = false
	end
	return ok, why, ent
end

--- Final break: keep NPC, open board once. Idempotent per room/run trigger.
function origin.finish_breaking(npc, opts)
	opts = opts or {}
	if not origin.is_giant_pawn_type(npc) then
		return false, "not_pawn"
	end
	local d = data_of(npc)
	if d.final_broken and d.activated and not opts.force then
		return false, "already"
	end

	local was_final = d.final_broken == true
	d.final_broken = true
	d.damage_stage = FINAL_STAGE

	if npc.Exists and npc:Exists() then
		apply_body_sheet(npc:GetSprite(), FINAL_STAGE)
		clamp_final_hp(npc)
		apply_layer_colors(npc, d)
		if not was_final and not opts.restore_only and not opts.skip_fx then
			play_stage_break_fx(npc.Position, 10)
		end
	end

	local r = runtime.get()
	if r.trigger then
		r.trigger.pawn_final_broken = true
		r.trigger.pawn_hp_ratio = FINAL_HP_RATIO
		-- Remnant remains in room; do not treat as removed.
		r.trigger.pawn_destroyed = false
	end

	if opts.restore_only then
		d.activated = true
		return true, "restore"
	end

	if d.sandbox or d.visual_only then
		d.activated = true
		last_diag.activate_ok = true
		last_diag.activate_why = "sandbox"
		return true, "sandbox"
	end

	if d.activated and not opts.force then
		last_diag.activate_ok = false
		last_diag.activate_why = "already"
		return false, "already"
	end

	local ok, why = runtime.activate_board("origin_destroyed")
	last_diag.activate_ok = ok and true or false
	last_diag.activate_why = why or (ok and "activated" or "failed")
	d.last_activate_ok = last_diag.activate_ok
	d.last_activate_why = last_diag.activate_why

	if ok then
		d.activated = true
		-- Expand from route outgoing_slot toward interior (not giant-pawn feet).
		local slot = route.get_outgoing_slot()
		local expand_ok, expand_why = board_mod().begin_expand_from_door(slot, Game():GetFrameCount())
		last_diag.expand_ok = expand_ok and true or false
		last_diag.expand_why = expand_why
		d.last_expand_why = expand_why
		if expand_why == "missing_outgoing_slot" then
			Isaac.ConsoleOutput("[Stone] board expand: missing_outgoing_slot\n")
		end
		encounter_mod().on_board_activated()
		board_mod().mark_bootstrap_complete()
		return true, "activated"
	end

	-- Board may already be active (re-entry); still mark activated to stay idempotent.
	if why == "already" or why == "already_past" then
		d.activated = true
		-- Repair interrupted activate: board on but expand/first-wave missing.
		encounter_mod().ensure_bootstrap_after_interrupt()
	end
	return false, why or "activate_failed"
end

--- Legacy death path: safety net only. Prefer finish_breaking via stage / TAKE_DMG.
function origin.on_giant_pawn_death(npc)
	last_diag.death_callback = true
	last_diag.npc_recognized = origin.is_giant_pawn_type(npc)
	if not last_diag.npc_recognized then
		return false
	end
	local d = data_of(npc)
	if d.final_broken and d.activated then
		return false, "already"
	end
	return origin.finish_breaking(npc, { from_death = true, skip_fx = false })
end

function origin.debug_replay_shatter()
	local ent = origin.find_room_pawn()
	if not ent then
		local ok = origin.debug_place_in_current_room()
		if not ok then return false, "no_pawn" end
		ent = origin.find_room_pawn()
	end
	if not ent then return false, "no_pawn" end
	local d = data_of(ent)
	d.sandbox = true
	d.visual_only = true
	d.activated = false
	d.final_broken = false
	play_stage_break_fx(ent.Position, 10)
	return true
end

function origin.find_room_pawn()
	if not VARIANT then return nil end
	for _, ent in ipairs(Isaac.FindByType(996, VARIANT, -1, false, false)) do
		if origin.is_living_giant_pawn(ent) then
			return ent
		end
	end
	return nil
end

function origin.inspect_text()
	local ent = origin.find_room_pawn()
	local r = runtime.get()
	local lines = {}
	if not ent then
		lines[#lines + 1] = "Giant Pawn: (none in room)"
	else
		local d = data_of(ent)
		local ratio = ent.HitPoints / math.max(1, ent.MaxHitPoints)
		lines[#lines + 1] = string.format(
			"Giant Pawn HP=%.1f/%.1f (%.0f%%) stage=%d final=%s",
			ent.HitPoints,
			ent.MaxHitPoints,
			ratio * 100,
			d.damage_stage or 0,
			tostring(d.final_broken == true)
		)
		lines[#lines + 1] = string.format(
			"  DeathCB=%s recognized=%s activate=%s/%s",
			tostring(last_diag.death_callback),
			tostring(last_diag.npc_recognized),
			tostring(last_diag.activate_ok),
			tostring(last_diag.activate_why)
		)
		lines[#lines + 1] = string.format(
			"  Occlusion=%s behind=%s overlap=%s alpha=%.2f",
			tostring(last_diag.occlusion),
			tostring(last_diag.player_behind),
			tostring(last_diag.body_overlap),
			last_diag.body_alpha or 1
		)
		local bp = last_diag.burial_probe
		if bp then
			lines[#lines + 1] = string.format(
				"  Burial mode=%s sheet=%s readback=%s",
				tostring(bp.mode),
				tostring(bp.sheet),
				tostring(bp.readback_matches)
			)
			if bp.after then
				lines[#lines + 1] = string.format(
					"  Burial Color R=%.2f G=%.2f B=%.2f A=%.2f",
					bp.after.r or 1, bp.after.g or 1, bp.after.b or 1, bp.after.a or 1
				)
			end
			local t = bp.floor or burial_tint_for(d)
			lines[#lines + 1] = string.format(
				"  FloorColor R=%.2f G=%.2f B=%.2f",
				t.r or 1, t.g or 1, t.b or 1
			)
		else
			local t = burial_tint_for(d)
			lines[#lines + 1] = string.format(
				"  Burial tint R=%.2f G=%.2f B=%.2f",
				t.r or 1, t.g or 1, t.b or 1
			)
		end
	end
	lines[#lines + 1] = string.format(
		"StoneRun board=%s phase=%s final_broken=%s",
		tostring(r.board and r.board.activated),
		tostring(r.phase),
		tostring(r.trigger and r.trigger.pawn_final_broken)
	)
	return table.concat(lines, "\n")
end

function origin.debug_hit(amount)
	local ent = origin.find_room_pawn()
	if not ent then return false, "no_pawn" end
	amount = tonumber(amount) or 5
	ent:TakeDamage(amount, 0, EntityRef(Game():GetPlayer(0)), 0)
	return true, ent.HitPoints
end

function origin.debug_heal()
	local ent = origin.find_room_pawn()
	if not ent then return false, "no_pawn" end
	local d = data_of(ent)
	d.final_broken = false
	d.activated = false
	ent.HitPoints = ent.MaxHitPoints
	d.damage_stage = 0
	apply_body_sheet(ent:GetSprite(), 0)
	apply_layer_colors(ent, d)
	local r = runtime.get()
	if r.trigger and d.sandbox then
		r.trigger.pawn_final_broken = false
	end
	return true
end

function origin.debug_break()
	local ent = origin.find_room_pawn()
	if not ent then return false, "no_pawn" end
	local d = data_of(ent)
	d.sandbox = true
	d.visual_only = true
	d.activated = false
	d.final_broken = false
	return origin.finish_breaking(ent, { force = true })
end

--- World point → body texture pixel (accounts for ANM2 pivot + rotation).
local function world_to_body_tex(npc, world_pos)
	local body = occ.BODY
	local dx = world_pos.X - npc.Position.X - body.x_pos
	local dy = world_pos.Y - npc.Position.Y - body.y_pos
	local rad = -math.rad(body.rotation or 0)
	local cos_a = math.cos(rad)
	local sin_a = math.sin(rad)
	local lx = dx * cos_a - dy * sin_a
	local ly = dx * sin_a + dy * cos_a
	if body.x_scale and body.x_scale ~= 0 then
		lx = lx / body.x_scale
	end
	if body.y_scale and body.y_scale ~= 0 then
		ly = ly / body.y_scale
	end
	return body.pivot_x + lx, body.pivot_y + ly
end

local function player_occludes_body(npc, player, stage)
	if not player or not player:Exists() then
		return false, false, false
	end
	-- Behind = north of ground anchor (smaller room Y) so the upright body covers the player.
	local behind = player.Position.Y < npc.Position.Y + 10
	if not behind then
		return false, false, false
	end
	local samples = {
		player.Position,
		player.Position + Vector(0, -12),
		player.Position + Vector(-8, -6),
		player.Position + Vector(8, -6),
	}
	local overlap = false
	for _, p in ipairs(samples) do
		local tx, ty = world_to_body_tex(npc, p)
		if occ.sample(stage, tx, ty) then
			overlap = true
			break
		end
	end
	return behind and overlap, behind, overlap
end

local function update_occlusion(npc, d)
	local stage = d.damage_stage or 0
	local any = false
	local behind_any = false
	local overlap_any = false
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		local occluded, behind, overlap = player_occludes_body(npc, p, stage)
		if behind then behind_any = true end
		if overlap then overlap_any = true end
		if occluded then
			any = true
			break
		end
	end
	local target = any and BODY_ALPHA_OCCLUDED or BODY_ALPHA_NORMAL
	local cur = d.body_alpha
	if type(cur) ~= "number" then cur = BODY_ALPHA_NORMAL end
	if cur < target then
		cur = math.min(target, cur + BODY_FADE_OUT)
	elseif cur > target then
		cur = math.max(target, cur - BODY_FADE_IN)
	end
	d.body_alpha = cur
	last_diag.occlusion = any
	last_diag.player_behind = behind_any
	last_diag.body_overlap = overlap_any
	last_diag.body_alpha = cur
end

function origin.on_take_damage(ent, amount, _flags, _source, _countdown)
	if not origin.is_giant_pawn_type(ent) then
		return nil
	end
	local d = data_of(ent)
	if not d then
		return nil
	end

	if d.final_broken then
		return false
	end

	amount = tonumber(amount) or 0
	if amount <= 0 then
		return nil
	end

	local max_hp = math.max(0.01, ent.MaxHitPoints)
	local threshold = max_hp * FINAL_HP_RATIO
	-- Intercept hits that would enter / pass the final band so the engine never kills the NPC.
	if ent.HitPoints - amount <= threshold then
		ent.HitPoints = math.max(1, threshold)
		-- Smoke → reveal Pawn_03 → finish_breaking at switch frame (not immediately).
		begin_break_fx(ent, d, FINAL_STAGE)
		return false
	end

	return nil
end

function origin.update_npc(npc)
	if not origin.is_living_giant_pawn(npc) then return end
	local d = data_of(npc)
	npc.Velocity = Vector.Zero
	-- Remnant keeps GridPath until entity leave/remove (not cleared on finish_breaking).
	origin.update_grid_footprint(npc)

	maybe_deferred_texture_refresh(npc, d)

	if d.final_broken then
		clamp_final_hp(npc)
		d.damage_stage = FINAL_STAGE
		update_occlusion(npc, d)
		apply_layer_colors(npc, d)
		local r = runtime.get()
		if r.trigger and not d.sandbox then
			r.trigger.pawn_hp_ratio = FINAL_HP_RATIO
			r.trigger.pawn_final_broken = true
		end
		do
			local probe = package.loaded["Qing_Remaster_scripts.debug.stone_render_probe"]
			if probe and probe.is_enabled and probe.is_enabled() and probe.sample_burial then
				probe.sample_burial("npc_update", npc)
			end
		end
		return
	end

	local ratio = npc.HitPoints / math.max(0.01, npc.MaxHitPoints)
	local stage = stage_from_ratio(ratio)
	-- Displayed stage lags behind HP via break FX (mask smoke → sheet swap).
	if stage > (d.damage_stage or 0) then
		begin_break_fx(npc, d, stage)
	end
	tick_break_fx(npc, d)

	update_occlusion(npc, d)
	apply_layer_colors(npc, d)

	local r = runtime.get()
	if r.trigger and not d.sandbox then
		r.trigger.pawn_hp_ratio = d.final_broken and FINAL_HP_RATIO or ratio
	end

	-- Optional burial timeline sample (only if probe already loaded + enabled).
	do
		local probe = package.loaded["Qing_Remaster_scripts.debug.stone_render_probe"]
		if probe and probe.is_enabled and probe.is_enabled() and probe.sample_burial then
			probe.sample_burial("npc_update", npc)
		end
	end
end

--- Called from rooms.tick_scene → MC_POST_UPDATE (after NPC_UPDATE footprint writes).
--- Samples whether engine / others degraded our 900 marks before the next logic frame.
function origin.tick()
	local room = Game():GetRoom()
	if not room or not room.GetGridPath then
		return
	end
	if not next(footprint_marks.saved) then
		footprint_marks.diag.post_update_decay = nil
		return
	end
	local decayed = {}
	for idx in pairs(footprint_marks.saved) do
		local cur = room:GetGridPath(idx)
		if type(cur) ~= "number" or cur < GRIDPATH_COST then
			decayed[#decayed + 1] = {idx = idx, value = cur}
		end
	end
	if #decayed > 0 then
		footprint_marks.diag.post_update_decay = {
			frame = Game():GetFrameCount(),
			count = #decayed,
			cells = decayed,
		}
	else
		footprint_marks.diag.post_update_decay = {
			frame = Game():GetFrameCount(),
			count = 0,
			cells = {},
		}
	end
end

local function render_probe(anchor)
	if not VIS.show_probe or not Isaac.DrawLine then return end
	local ok = select(1, rooms_mod().probe_anchor_clearance(anchor))
	local col = ok and KColor(0.2, 0.9, 0.3, 0.55) or KColor(0.95, 0.2, 0.2, 0.55)
	local half = 60
	local p1 = Isaac.WorldToScreen(anchor + Vector(-half, -half))
	local p2 = Isaac.WorldToScreen(anchor + Vector(half, -half))
	local p3 = Isaac.WorldToScreen(anchor + Vector(-half, half))
	local p4 = Isaac.WorldToScreen(anchor + Vector(half, half))
	Isaac.DrawLine(p1, p2, col, col, 1)
	Isaac.DrawLine(p2, p4, col, col, 1)
	Isaac.DrawLine(p4, p3, col, col, 1)
	Isaac.DrawLine(p3, p1, col, col, 1)
end

--- Burial is engine-drawn via giant_pawn.anm2 layer order + LayerState:SetColor.
function origin.render_npc(npc, _offset)
	if not origin.is_living_giant_pawn(npc) then return end
	render_probe(npc.Position)
end

function origin.burial_probe_text()
	-- Prefer full timeline from stone_render_probe when armed.
	local probe = package.loaded["Qing_Remaster_scripts.debug.stone_render_probe"]
	if probe and probe.is_enabled and probe.is_enabled() and probe.get_summary then
		return probe.get_summary()
	end
	local bp = last_diag.burial_probe
	if not bp then
		return "Burial Layer Probe\n  (no data yet — need living Giant Pawn)\n  Tip: enable Stone Render Probe for Update/PRE/POST timeline."
	end
	local lines = {
		"Burial Layer Probe (Update snapshot only)",
		string.format("  Layer name: %s", tostring(bp.layer_name)),
		string.format("  Layer ID: %s", tostring(bp.layer_id)),
		string.format("  Visible: %s", tostring(bp.visible)),
		string.format("  Sheet: %s", tostring(bp.sheet)),
		"",
		string.format("  Mode: %s", tostring(bp.mode)),
	}
	if bp.after then
		lines[#lines + 1] = string.format(
			"  After Color: R=%.3f G=%.3f B=%.3f A=%.3f",
			bp.after.r or 0, bp.after.g or 0, bp.after.b or 0, bp.after.a or 0
		)
	else
		lines[#lines + 1] = "  After Color: (n/a)"
	end
	lines[#lines + 1] = string.format("  Readback Matches: %s", tostring(bp.readback_matches))
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Floor Sampling"
	local t = bp.floor or {}
	lines[#lines + 1] = string.format(
		"  FloorColor: R=%.3f G=%.3f B=%.3f",
		t.r or 1, t.g or 1, t.b or 1
	)
	lines[#lines + 1] = "  Mapping Validated: false (enable Stone Render Probe for full timeline)"
	return table.concat(lines, "\n")
end

function origin.render()
end

return origin

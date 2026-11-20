-- Alien Savior suction visuals.
-- NPC: Eclipse-style live Renderer:GetSprite():Render (no Sprite() snapshot).
-- Projectile / Grid: frozen sprite snapshot (source already removed).
-- Grid: morpher-style sheet resolve + progressive cyan tint on original Color.
--
-- MeusNil is NOT used here: ABDUCT_TARGETS may hold many concurrent jobs;
-- meusnil-usage forbids multi long-lived Nil shells. Motion stays in suction Jobs;
-- render formula matches Card_19_Eclipse Nil_holder render callback.
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local PX = {}

local function clamp01(x)
	if x < 0 then
		return 0
	end
	if x > 1 then
		return 1
	end
	return x
end

local function smoothstep(t)
	t = clamp01(t or 0)
	return t * t * (3 - 2 * t)
end

local function tint_color()
	local t = (C.SUCTION and C.SUCTION.TINT) or {}
	return Color(
		t.r or 0.82,
		t.g or 1.0,
		t.b or 0.95,
		t.a or 1.0,
		t.ro or 0,
		t.go or 0.04,
		t.bo or 0.08
	)
end

local function world_to_render(pos)
	-- Eclipse uses Isaac.WorldToScreen(ent.Position + PositionOffset).
	return Isaac.WorldToScreen(pos)
end

--- Job FSM → cyan overlay strength. Continuous at approaching→ascending (both 0.75).
function PX.tint_strength(job)
	if not job then
		return 0
	end
	local st = job.state
	local p = smoothstep(job.progress or 0)
	local peak = (C.SUCTION and C.SUCTION.TINT_APPROACH_PEAK) or 0.75
	if st == "shaking" then
		return 0
	end
	if st == "approaching" then
		return p * peak
	end
	if st == "ascending" then
		local ascend_peak = (C.SUCTION and C.SUCTION.TINT_ASCEND_PEAK) or 1.0
		return peak + p * (ascend_peak - peak)
	end
	if st == "consumed" then
		return (C.SUCTION and C.SUCTION.TINT_ASCEND_PEAK) or 1.0
	end
	return 0
end

--- Lerp RGB/Offset toward cyan; keep original Alpha (unless override) and Colorize.
--- Always blend from a frozen original — never from the previously tinted spr.Color.
function PX.compose_tint(original, strength, alpha_override)
	local o = original
	if not o then
		o = Color(1, 1, 1, 1)
	end
	local s = clamp01(strength or 0)
	if s <= 0 then
		local keep = auxi.copy_color(o)
		if alpha_override ~= nil then
			local t = auxi.color2table(keep)
			t.A = alpha_override
			return auxi.table2color(t)
		end
		return keep
	end
	local ot = auxi.color2table(o)
	local tt = auxi.color2table(tint_color())
	local out = {
		R = ot.R + (tt.R - ot.R) * s,
		G = ot.G + (tt.G - ot.G) * s,
		B = ot.B + (tt.B - ot.B) * s,
		A = alpha_override ~= nil and alpha_override or ot.A,
		RO = ot.RO + (tt.RO - ot.RO) * s,
		GO = ot.GO + (tt.GO - ot.GO) * s,
		BO = ot.BO + (tt.BO - ot.BO) * s,
		-- Preserve original Colorize (gold rocks / special grids).
		RC = ot.RC,
		GC = ot.GC,
		BC = ot.BC,
		AC = ot.AC,
	}
	return auxi.table2color(out)
end

--- Projectile / grid only. Do not use for NPC appearance.
function PX.snapshot_entity_sprite(ent)
	if not ent or not ent.GetSprite then
		return nil, nil
	end
	local src = ent:GetSprite()
	if not src then
		return nil, nil
	end
	local spr = Sprite()
	auxi.copy_sprite(src, spr)
	spr.PlaybackSpeed = 0
	local meta = {
		original_color = auxi.copy_color(src.Color),
		animation = spr.GetAnimation and spr:GetAnimation() or nil,
		frame = spr.GetFrame and spr:GetFrame() or nil,
	}
	return spr, meta
end

--- Resolve grid sheet like grid_morpher.morph_grid (backdrop rocks + poop variants).
--- String poop paths are forced; random-table variants keep the copied sheet.
function PX.snapshot_grid_sprite(grid)
	if not grid or not grid.GetSprite then
		return nil, nil
	end
	local src = grid:GetSprite()
	if not src then
		return nil, nil
	end
	local morpher = require("Qing_Remaster_scripts.grids.grid_morpher")
	local spr = Sprite()
	auxi.copy_sprite(src, spr)
	spr.PlaybackSpeed = 0

	local tp = grid:GetType()
	local variant = grid:GetVariant()
	local grid_info = (morpher.rock_grid and morpher.rock_grid[tp]) or {}
	local texture_path = nil
	local resolution = "copy_sprite"

	if tp == GridEntityType.GRID_POOP then
		local entry = morpher.poop_info and morpher.poop_info[variant]
		if type(entry) == "string" then
			texture_path = entry
			spr:ReplaceSpritesheet(0, texture_path)
			spr:LoadGraphics()
			resolution = "poop_variant_sheet"
		elseif type(entry) == "function" then
			-- Multi-sheet variants (normal/red/white): keep copied sheet so the
			-- already-chosen skin is preserved (Tower's random pick would re-roll).
			resolution = "poop_copy_keep"
		else
			resolution = "poop_copy_fallback"
		end
	elseif grid_info.info and morpher.get_morph_dir then
		local rk_info = morpher.get_morph_dir()
		if rk_info and rk_info.name then
			texture_path = rk_info.name
			spr:ReplaceSpritesheet(0, texture_path)
			spr:LoadGraphics()
			resolution = "rock_backdrop_sheet"
		end
	end

	local meta = {
		original_color = auxi.copy_color(src.Color),
		texture_path = texture_path,
		grid_texture_resolution = resolution,
		animation = spr.GetAnimation and spr:GetAnimation() or nil,
		frame = spr.GetFrame and spr:GetFrame() or nil,
		grid_type = tp,
		grid_variant = variant,
	}
	return spr, meta
end

function PX.apply_pose(spr, opts)
	if not spr then
		return
	end
	opts = opts or {}
	local scale = opts.scale or 1
	local base = opts.base_scale or Vector(1, 1)
	spr.Scale = Vector(base.X * scale, base.Y * scale)
	spr.Rotation = opts.rotation or 0
	local strength = opts.tint_strength
	if strength == nil then
		strength = 0
	end
	spr.Color = PX.compose_tint(opts.original_color, strength, opts.alpha)
end

function PX.render(spr, world_pos, opts)
	if not spr or not world_pos then
		return
	end
	PX.apply_pose(spr, opts)
	spr:Render(world_to_render(world_pos), Vector.Zero, Vector.Zero)
end

--- Eclipse Nil_holder render pattern: Renderer:GetSprite():Render(WorldToScreen(...)).
--- Temporarily applies job pose then restores sprite fields so the hidden NPC is unchanged.
function PX.render_live_npc(renderer, world_pos, opts)
	if not renderer or not world_pos then
		return false
	end
	if not auxi.check_all_exists(renderer) then
		return false
	end
	local spr = renderer:GetSprite()
	if not spr then
		return false
	end
	opts = opts or {}
	local old_scale = spr.Scale
	local old_rot = spr.Rotation
	local old_color = spr.Color
	local scale = opts.scale or 1
	local base = opts.base_scale or Vector(1, 1)
	spr.Scale = Vector(base.X * scale, base.Y * scale)
	spr.Rotation = (old_rot or 0) + (opts.rotation or 0)
	local strength = opts.tint_strength
	if strength == nil then
		strength = 0
	end
	-- Prefer frozen original_color; fall back to pre-tint sprite (restored below).
	local base_color = opts.original_color or old_color
	spr.Color = PX.compose_tint(base_color, strength, opts.alpha)
	-- Match Card_19_Eclipse.lua Nil_holder.render:
	-- effect.Renderer:GetSprite():Render(Isaac.WorldToScreen(ent.Position + ent.PositionOffset), ...)
	spr:Render(world_to_render(world_pos), Vector.Zero, Vector.Zero)
	spr.Scale = old_scale
	spr.Rotation = old_rot
	spr.Color = old_color
	return true
end

return PX

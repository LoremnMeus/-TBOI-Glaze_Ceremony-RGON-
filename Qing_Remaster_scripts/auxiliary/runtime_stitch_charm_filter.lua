-- Runtime Stitch charm-heart matcher (exact vanilla statuseffects Charm palette).
-- Keeps FLAG_CHARM for friendly AI. Scale geometry skips matching texels only while
-- still in SEARCH_BODY on the centerline (see measure_centerline).
--
-- Authoritative source (resource analysis, not heuristics):
--   extracted_resources/resources/gfx/statuseffects.anm2
--   Animation: Charm / Layer: Main / 9 frames × Delay 2
--   spritesheet: StatusEffects.png → statuseffects.png
-- Report:
--   codex_work/runtime_stitch/charm_status_effect_analysis.json
--   schema_version 3 / analysis date in that file
-- Measured opaque RGBA across all 9 full 32×32 frames (579 px):
--   (255,115,115,255) and (255,75,75,255) only; alpha always 255.

local M = {}

-- Production default ON. Probe ImGui can disable for A/B (does not touch entity flags).
local enabled = true

function M.set_enabled(on)
	enabled = on == true
end

function M.is_enabled()
	return enabled == true
end

--- Cache tag must change when matcher identity changes (GeometryNode key).
function M.cache_tag()
	return enabled and "charm_statuseffects_v1" or "charm_off"
end

--- Exact Charm membership. r,g,b,a are 0–255 integers
--- (callers convert f32 alpha via floor(a*255+0.5); RGB from texel_rgba_at is already u8).
function M.is_candidate(r, g, b, a)
	r = tonumber(r) or 0
	g = tonumber(g) or 0
	b = tonumber(b) or 0
	a = tonumber(a) or 0
	if a ~= 255 then
		return false
	end
	return (r == 255 and g == 115 and b == 115)
		or (r == 255 and g == 75 and b == 75)
end

--- Probe / diag snapshot (no head-zone).
function M.diag_snapshot(extra)
	extra = extra or {}
	return {
		enabled = M.is_enabled(),
		active = extra.active == true,
		mode = "exact_statuseffects_charm",
		palette = {
			{ 255, 115, 115, 255 },
			{ 255, 75, 75, 255 },
		},
		palette_hex = { "#FF7373", "#FF4B4B" },
		removed_pixels = tonumber(extra.removed_pixels) or 0,
		charm_skipped = tonumber(extra.charm_skipped) or tonumber(extra.removed_pixels) or 0,
		body_start_y = extra.body_start_y,
		cache_tag = M.cache_tag(),
	}
end

return M

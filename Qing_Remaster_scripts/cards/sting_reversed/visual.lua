-- Reversed Sting pentagram visual: blood_fill dyes Base/Blood; Glow = absorb flash only.
local C = require("Qing_Remaster_scripts.cards.sting_reversed.constants")

local M = {}

local function smoothstep(t)
	t = math.min(1, math.max(0, t))
	return t * t * (3 - 2 * t)
end

local function set_layer_color(sprite, layer_id, color)
	if not sprite or not sprite.GetLayer then
		return
	end
	pcall(function()
		local layer = sprite:GetLayer(layer_id)
		if layer and layer.SetColor then
			layer:SetColor(color)
		end
	end)
end

function M.init_ritual(ritual)
	if not ritual then
		return
	end
	ritual.blood_fill = 0
	ritual.blood_fill_visual = 0
end

function M.add_blood_fill(ritual, amount)
	if not ritual then
		return
	end
	local add = tonumber(amount) or 0
	ritual.blood_fill = math.min(1, (tonumber(ritual.blood_fill) or 0) + add)
end

-- Called when a blood orb actually reaches the pentagram.
function M.on_blood_absorbed(ritual, anchor, amount)
	M.add_blood_fill(ritual, amount)
	if not anchor or not anchor:Exists() then
		return
	end
	local ad = anchor:GetData()
	local cur = tonumber(ad.absorb_flash) or 0
	if cur <= 0 then
		ad.absorb_flash = C.ABSORB_FLASH_FRAMES
	else
		ad.absorb_flash = math.min(C.ABSORB_FLASH_MAX_FRAMES, cur + C.ABSORB_FLASH_ADD)
	end
end

function M.update_anchor(ritual, anchor)
	if not ritual or not anchor or not anchor:Exists() then
		return
	end

	local sprite = anchor:GetSprite()
	local completed = tonumber(ritual.completed) or 0
	local d = anchor:GetData()

	ritual.blood_fill = math.min(1, tonumber(ritual.blood_fill) or 0)
	ritual.blood_fill_visual = (tonumber(ritual.blood_fill_visual) or 0)
		+ (ritual.blood_fill - (tonumber(ritual.blood_fill_visual) or 0)) * C.BLOOD_FILL_VISUAL_LERP

	local fill = smoothstep(ritual.blood_fill_visual)
	sprite.PlaybackSpeed = 1 + math.min(completed, 6) * 0.12

	local pulse = tonumber(d.pulse) or 0
	if pulse > 0 then
		d.pulse = math.max(0, pulse - 0.12)
		pulse = d.pulse
	end

	local flash_left = tonumber(d.absorb_flash) or 0
	local flash = 0
	if flash_left > 0 then
		local t = flash_left / C.ABSORB_FLASH_FRAMES
		flash = t * t
		d.absorb_flash = flash_left - 1
	end

	local pulse_t = 1 - pulse
	local pulse_scale = 1
	if pulse > 0 then
		pulse_scale = 1 + 0.12 * math.sin(pulse_t * math.pi)
	end
	pulse_scale = pulse_scale + flash * 0.07 + fill * 0.03

	-- Idle / waiting (no links): tiny breath so the field still feels alive.
	local idle = (tonumber(ritual.link_count) or 0) == 0
	local idle_glow = 0
	if idle then
		local idle_wave = 0.5 + 0.5 * math.sin(Game():GetFrameCount() * 0.035)
		pulse_scale = pulse_scale + (idle_wave - 0.5) * 0.03
		idle_glow = 0.03 + idle_wave * 0.05
	end
	anchor.SpriteScale = Vector(pulse_scale, pulse_scale)

	local base_r = C.BASE_R0 + (C.BASE_R1 - C.BASE_R0) * fill
	local base_g = C.BASE_G0 + (C.BASE_G1 - C.BASE_G0) * fill
	local base_b = C.BASE_B0 + (C.BASE_B1 - C.BASE_B0) * fill
	local base_ro = C.BASE_RO0 + (C.BASE_RO1 - C.BASE_RO0) * fill
	set_layer_color(sprite, C.LAYER_BASE, Color(base_r, base_g, base_b, 1, base_ro, 0, 0))
	set_layer_color(
		sprite,
		C.LAYER_BLOOD,
		Color(1, 0.3 + fill * 0.3, 0.3, fill * 0.95, fill * 0.4, 0, 0)
	)
	-- Glow: absorb flash dominates; idle only adds a faint residual shimmer.
	set_layer_color(
		sprite,
		C.LAYER_GLOW,
		Color(
			1,
			0.55 + flash * 0.4,
			0.45 + flash * 0.45,
			flash * 0.95 + idle_glow,
			flash * 0.65 + idle_glow * 0.4,
			0,
			0
		)
	)

	if not sprite.GetLayer then
		sprite.Color = Color(
			base_r + flash * 0.35,
			base_g + flash * 0.25,
			base_b + flash * 0.2,
			1,
			base_ro + flash * 0.4,
			0,
			0
		)
	else
		sprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
	end
end

return M

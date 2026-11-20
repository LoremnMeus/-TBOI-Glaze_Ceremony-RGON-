-- Chess piece spritesheet + dynamic pose.
-- Static foot origin is owned by pieces.anm2 only — no Lua pivot Offset correction.
-- Native entity shadowSize (entities2.xml) owns ground shadows.

local defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local visual = {}

local function set_outline_alpha(s, alpha, rgb)
	if not s or not s.GetLayer then
		return
	end
	local ok, layer = pcall(function()
		return s:GetLayer("outline") or s:GetLayer(1)
	end)
	if not (ok and layer) then
		return
	end
	local a = math.max(0, math.min(1, alpha or 0))
	local r, g, b = 1, 1, 1
	if type(rgb) == "table" then
		r, g, b = rgb[1] or 1, rgb[2] or 1, rgb[3] or 1
	end
	if layer.SetVisible then
		layer:SetVisible(true)
	end
	if layer.SetColor then
		layer:SetColor(Color(r, g, b, a, 0, 0, 0))
	end
end

local function set_body_color(s, color)
	if not s or not s.GetLayer or not color then
		return
	end
	local ok, layer = pcall(function()
		return s:GetLayer("body") or s:GetLayer(0)
	end)
	if ok and layer and layer.SetColor then
		layer:SetColor(color)
	end
end

local function reserve_defs_settle()
	local ok, rd = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_defs")
	if ok and rd and rd.DEPLOY and rd.DEPLOY.SETTLE then
		return rd.DEPLOY.SETTLE
	end
	return 12
end

function visual.apply_sheet(ent, kind)
	local profile = defs.get(kind)
	local s = ent:GetSprite()
	s:Load(defs.ANM2, true)
	s:ReplaceSpritesheet(0, profile.spritesheet)
	-- Outline layer stays loaded; combat default is alpha 0 (ANM2 Idle Visible=true).
	s:ReplaceSpritesheet(1, defs.outline_sheet(kind))
	s:LoadGraphics()
	s:Play("Idle", true)
	s.Offset = Vector.Zero
	s.Rotation = 0
	s.Scale = Vector(1, 1)
	-- Neutral once at init; do not fight native hurt flash every frame.
	s.Color = Color(1, 1, 1, 1, 0, 0, 0)
	set_outline_alpha(s, 0)
	return profile
end

function visual.apply_pose(ent, data)
	if not ent or not data then return end
	local s = ent:GetSprite()
	local height = data.visual_height or 0
	local tilt = data.visual_tilt or 0
	-- Idle / settled: height must be 0 so ANM2 feet sit on the board.
	-- ROYAL_DROP keeps scripted height/tilt from floraine_v2.royal_drop.
	if data.action_state ~= "ROYAL_DROP" and not data.royal_drop then
		if data.action_state == "IDLE" or data.action_state == "RECOVERY" or data.action_state == "SPAWNING" then
			if data.action_state ~= "RECOVERY" or (data.phase_elapsed or 0) > 2 then
				height = data.action_state == "IDLE" and 0 or height
			end
		end
		if data.action_state == "IDLE" then
			height = 0
			tilt = 0
		end
	end
	ent.PositionOffset = Vector(0, -height)
	s.Rotation = tilt
	local scale = data.visual_scale or 1
	-- Optional squash from royal IMPACT (local Scale only; does not move Root / occupancy).
	local squash = data.visual_squash or 1
	s.Scale = Vector(scale * (2 - squash), scale * squash)

	local rdv = data.royal_drop_visual
	local royal_active = rdv and (
		rdv.empowered == true
		or (rdv.color_progress or 0) > 0.001
		or (rdv.outline_alpha or 0) > 0.001
		or (rdv.impact_progress or 0) > 0.001
	)
	if royal_active then
		-- ROYAL_DROP owns body tint + outline; pause deploy outline fade while empowered.
		local cp = math.max(0, math.min(1, rdv.color_progress or 0))
		local impact = math.max(0, math.min(1, rdv.impact_progress or 0))
		local er, eg, eb = 1.0, 0.48, 0.50
		local eo0, eo1, eo2 = 0.12, 0.02, 0.02
		if impact > 0 then
			er = er + (1.0 - er) * impact * 0.15
			eg = eg + (0.35 - eg) * impact
			eb = eb + (0.38 - eb) * impact
			eo0 = eo0 + (0.35 - eo0) * impact
			eo1 = eo1 + (0.05 - eo1) * impact
			eo2 = eo2 + (0.05 - eo2) * impact
		end
		set_body_color(s, Color(
			1 + (er - 1) * cp,
			1 + (eg - 1) * cp,
			1 + (eb - 1) * cp,
			1,
			eo0 * cp,
			eo1 * cp,
			eo2 * cp
		))
		set_outline_alpha(s, rdv.outline_alpha or 0, { 1.0, 0.16, 0.20 })
		s.Color = Color(1, 1, 1, 1, 0, 0, 0)
	elseif data._deploy_settle and data._deploy_settle > 0 then
		-- Deploy handoff: finish matte→normal and red outline fade on the NPC.
		local settle = reserve_defs_settle()
		local total = settle > 0 and settle or 12
		local left = data._deploy_settle
		local t = 1 - (left / total)
		local progress = data._deploy_color_progress or 1
		progress = progress + (1 - progress) * math.min(1, t)
		local matte = Color(0.22, 0.22, 0.24, 1, 0, 0, 0)
		local normal = Color(1, 1, 1, 1, 0, 0, 0)
		set_body_color(s, Color(
			matte.R + (normal.R - matte.R) * progress,
			matte.G + (normal.G - matte.G) * progress,
			matte.B + (normal.B - matte.B) * progress,
			1, 0, 0, 0
		))
		local oa = (data._deploy_outline_fade or 0) * (1 - t)
		set_outline_alpha(s, oa, { 1.0, 0.22, 0.26 })
		data._deploy_settle = left - 1
		if data._deploy_settle <= 0 then
			data._deploy_settle = nil
			data._deploy_color_progress = nil
			data._deploy_outline_fade = nil
			set_body_color(s, normal)
			set_outline_alpha(s, 0)
		end
	elseif data.action_state ~= "WINDUP" and data._flash_tint then
		visual.clear_tint(ent)
		data._flash_tint = false
	end
end

--- Soft windup hint only (small Color offset). Does not write LayerState; keep mild.
function visual.flash_tint(ent, amount)
	local s = ent:GetSprite()
	local a = math.max(0, math.min(1, amount or 0))
	-- Mild brightness only — leave room for native hurt flash on Sprite.Color.
	s.Color = Color(1, 1, 1, 1, a * 0.22, a * 0.08, a * 0.08)
	local data = ent:GetData().QingChessPiece
	if data then
		data._flash_tint = a > 0.01
	end
end

function visual.clear_tint(ent)
	ent:GetSprite().Color = Color(1, 1, 1, 1, 0, 0, 0)
end

--- One landing hit sound per move (deduped by attack_id / command serial on data).
function visual.on_landing(ent, data, profile)
	if not data or not profile then
		return
	end
	local token = data.landing_sound_token
	if token and data._land_sound_played == token then
		return
	end
	if token then
		data._land_sound_played = token
	end
	local kind = profile.land_sound or "soft"
	local vol = profile.land_volume or 0.4
	local sfx = SoundEffect.SOUND_STONE_IMPACT
	local pitch = 1.0
	if kind == "light" then
		sfx = SoundEffect.SOUND_FETUS_JUMP or SoundEffect.SOUND_STONE_IMPACT
		pitch = 1.15
		vol = vol * 0.85
	elseif kind == "soft" then
		sfx = SoundEffect.SOUND_STONE_IMPACT
		pitch = 1.2
	elseif kind == "impact" then
		sfx = SoundEffect.SOUND_ROCK_CRUMBLE
		pitch = 0.95
	elseif kind == "heavy" then
		sfx = SoundEffect.SOUND_STONE_IMPACT
		pitch = 0.85
		vol = vol * 1.1
	end
	sound_tracker.PlayStackedSound(sfx, vol, pitch, false, 0, 2)
end

return visual

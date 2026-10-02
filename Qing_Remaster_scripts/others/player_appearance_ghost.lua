-- Canonical shared owner for player-like ghosts.
-- Consumers MUST use Ghost.* rather than rebuilding base sheets, costume arbitration,
-- player head overlays, Extra-animation rendering, or held-item presentation.
-- Remaster binds the verified low-level implementation; Aeon/TianYi/etc. are consumers.
-- appearance.base_sheets is keyed by Sprite Layer ID, not ANM2 <Spritesheet> Id.
-- Cinematic Walk/Idle: base sprite is the reference clock.
-- Body: flying costumes stay persistent; ordinary costumes share matching lengths or advance only while Walk is running.
-- Head: idle directional Head* stays on frame 0; only a real overlay advances, then length matching applies.
-- Same costume ANM2 uses separate Lua Sprites for body-role vs head-role clocks (Spirit of the Night etc.).
-- Held visuals are {kind="collectible", gfx=} or {kind="pickup", variant, subtype}. A gfx string remains a collectible sheet.
local enums = require("Qing_Remaster_scripts.core.enums")

local Ghost = {
	ToCall = {},
	TAG = "_QingPlayerAppearanceGhost",
	APP_KEY = "_QingPlayerAppearanceGhostApp",
	POSE_MODE_KEY = "_QingPlayerAppearanceGhostPoseMode",
	RECORDED_STATE_KEY = "_QingPlayerAppearanceGhostRecordedState",
	LAYER_OVERRIDES_KEY = "_QingPlayerAppearanceGhostLayerOverrides",
	DEFAULT_TINT = Color(0.65, 0.8, 1.0, 0.45),
	POSE_MODE_CINEMATIC = "cinematic",
	POSE_MODE_RECORDED = "recorded",
}

local API = nil
local EFFECT_VAR = enums.Entities.ID_EFFECT_MeusNIL

function Ghost.bind(api)
	if type(api) ~= "table" then return end
	API = api
end

function Ghost.ensure_bound()
	if API then return true end
	pcall(function()
		require("Qing_Remaster_scripts.items.Item_Remaster")
	end)
	return API ~= nil
end

function Ghost.is_ghost(ent)
	return ent ~= nil and ent:GetData()[Ghost.TAG] == true
end

function Ghost.get_pose_mode(ghost)
	if not ghost then return Ghost.POSE_MODE_CINEMATIC end
	local mode = ghost:GetData()[Ghost.POSE_MODE_KEY]
	if mode == Ghost.POSE_MODE_RECORDED then
		return Ghost.POSE_MODE_RECORDED
	end
	return Ghost.POSE_MODE_CINEMATIC
end

function Ghost.is_recorded_pose(ghost)
	return Ghost.get_pose_mode(ghost) == Ghost.POSE_MODE_RECORDED
end

function Ghost.get_recorded_layer_overrides(ghost)
	if not ghost then return nil end
	local ov = ghost:GetData()[Ghost.LAYER_OVERRIDES_KEY]
	if type(ov) == "table" and next(ov) then
		return ov
	end
	return nil
end

function Ghost.begin_live_pose_capture(player, appearance)
	if not Ghost.ensure_bound() then return nil end
	if API.begin_live_pose_capture then
		return API.begin_live_pose_capture(player, appearance)
	end
	return { appearance = appearance or Ghost.capture(player) }
end

function Ghost.capture_live_pose(player, runtime)
	if not Ghost.ensure_bound() then return nil end
	if API.capture_live_pose then
		return API.capture_live_pose(player, runtime and runtime.appearance, runtime)
	end
	return nil
end

function Ghost.apply_recorded_pose(ghost, pose)
	if not ghost or not ghost:Exists() or type(pose) ~= "table" then return end
	local anim = pose.anim
	local anim_frame = pose.anim_frame
	local overlay_anim = pose.overlay_anim
	local overlay_frame = pose.overlay_frame
	local flip_x = pose.flip_x
	local overrides = pose.layer_overrides
	if pose.body then
		anim = pose.body.anim or anim
		anim_frame = pose.body.frame or anim_frame
	end
	if pose.head then
		overlay_anim = pose.head.anim or overlay_anim
		overlay_frame = pose.head.frame or overlay_frame
	end
	if pose.overrides ~= nil and overrides == nil then
		overrides = pose.overrides
	end
	Ghost.set_animation(ghost, anim, overlay_anim, anim_frame, overlay_frame, {
		mode = Ghost.POSE_MODE_RECORDED,
		flip_x = flip_x and true or false,
	})
	local d = ghost:GetData()
	if type(overrides) == "table" and next(overrides) then
		d[Ghost.LAYER_OVERRIDES_KEY] = overrides
	else
		d[Ghost.LAYER_OVERRIDES_KEY] = nil
	end
end

function Ghost.capture(player)
	if not Ghost.ensure_bound() or not API.capture then return nil end
	return API.capture(player)
end

function Ghost.sanitize(appearance)
	if not Ghost.ensure_bound() or not API.sanitize then return appearance end
	return API.sanitize(appearance)
end

--- opts: anim, subtype, owner_key, tint, setup_costumes (default true)
function Ghost.spawn(pos, appearance, opts)
	if not Ghost.ensure_bound() or not API.spawn then return nil end
	opts = opts or {}
	local ghost = API.spawn(pos, appearance, opts.anim or "WalkDown", {
		subtype = opts.subtype,
		owner_key = opts.owner_key,
	})
	if not ghost then return nil end
	local d = ghost:GetData()
	d[Ghost.TAG] = true
	d[Ghost.APP_KEY] = appearance
	d.skip_nil_holder = true
	d.skip_nil_distance_cull = true
	d.removecd = 999999
	if opts.setup_costumes ~= false and API.setup_costumes then
		API.setup_costumes(ghost, appearance)
	end
	Ghost.set_tint(ghost, opts.tint or Ghost.DEFAULT_TINT)
	return ghost
end

--- Apply / re-apply pose onto a ghost sprite.
---
--- CINEMATIC MODE (Remaster portal ghosts):
---   Animation clock owner = engine / cinematic renderer.
---   Recorded target is not used. Sprite may freely advance.
---
--- RECORDED MODE (Aeon echo / replay):
---   Animation clock owner = recorded pose.
---   Engine/Lua Sprite may update first, but recorded anim/frame must be
---   re-applied before rendering. Cache may skip Play/PlayOverlay, but must
---   never skip SetFrame / SetOverlayFrame (entity sprites auto-advance).
---
--- opts: mode ("cinematic"|"recorded", default cinematic), flip_x (optional)
function Ghost.set_animation(ghost, anim, overlay, frame, overlay_frame, opts)
	if not ghost or not ghost:Exists() then return end
	opts = type(opts) == "table" and opts or {}
	local mode = opts.mode
	if mode ~= Ghost.POSE_MODE_RECORDED then
		mode = Ghost.POSE_MODE_CINEMATIC
	end
	local d = ghost:GetData()
	if d[Ghost.POSE_MODE_KEY] ~= mode then
		d[Ghost.POSE_MODE_KEY] = mode
	end

	frame = frame or 0
	overlay_frame = overlay_frame or 0
	local flip_x = nil
	if opts.flip_x ~= nil then
		flip_x = opts.flip_x and true or false
	end
	local has_overlay = type(overlay) == "string" and overlay ~= ""
	if not has_overlay then
		overlay = nil
		overlay_frame = 0
	end

	if mode == Ghost.POSE_MODE_RECORDED then
		local cache = d[Ghost.RECORDED_STATE_KEY]
		if type(cache) ~= "table" then
			cache = {}
			d[Ghost.RECORDED_STATE_KEY] = cache
		end
		local anim_changed = cache.anim ~= anim
		local overlay_changed = cache.overlay ~= overlay
		local flip_changed = flip_x ~= nil and cache.flip_x ~= flip_x

		if flip_changed then
			ghost.FlipX = flip_x
		end

		local s = ghost:GetSprite()
		if not s then return end

		if type(anim) == "string" and anim ~= "" then
			if anim_changed then
				if API and API.ensure_anim then
					API.ensure_anim(ghost, anim)
				else
					pcall(function()
						if s:GetAnimation() ~= anim then
							s:Play(anim, true)
						end
					end)
				end
			end
			-- Recorded clock authority: always restore frame (engine may have advanced).
			pcall(function()
				s:SetFrame(anim, tonumber(frame) or 0)
			end)
		end

		if has_overlay then
			if overlay_changed then
				pcall(function()
					s:PlayOverlay(overlay, true)
				end)
			end
			-- Recorded overlay authority: always restore overlay frame.
			pcall(function()
				s:SetOverlayFrame(overlay, tonumber(overlay_frame) or 0)
			end)
		elseif overlay_changed then
			if API and API.clear_overlay then
				API.clear_overlay(ghost)
			else
				pcall(function() s:RemoveOverlay() end)
			end
		end

		cache.anim = anim
		cache.frame = tonumber(frame) or 0
		cache.overlay = overlay
		cache.overlay_frame = tonumber(overlay_frame) or 0
		if flip_x ~= nil then
			cache.flip_x = flip_x
		end
		cache.mode = mode
		return
	end

	-- cinematic path: free-run; do not force SetFrame every caller unless needed
	if flip_x ~= nil then
		ghost.FlipX = flip_x
	end

	local s = ghost:GetSprite()
	if not s then return end
	if type(anim) == "string" and anim ~= "" then
		if API and API.ensure_anim then
			API.ensure_anim(ghost, anim)
		else
			pcall(function()
				if s:GetAnimation() ~= anim then
					s:Play(anim, true)
				end
			end)
		end
		pcall(function() s:SetFrame(anim, frame) end)
	end

	if has_overlay then
		pcall(function()
			if s:GetOverlayAnimation() ~= overlay then
				s:PlayOverlay(overlay, true)
			end
			s:SetOverlayFrame(overlay, overlay_frame)
		end)
	elseif API and API.clear_overlay then
		API.clear_overlay(ghost)
	else
		pcall(function() s:RemoveOverlay() end)
	end

	-- cinematic：Remaster 行走头自动同步；recorded：保留录像 overlay，禁止 Head* 覆盖
	if API and API.sync_head then
		API.sync_head(ghost, anim)
	end
end

--- Re-apply cached recorded clocks onto the base Entity Sprite (pre-render).
--- Call after any free Update so Walk*/Head* stay pinned to the last apply_recorded_pose.
function Ghost.reassert_recorded_clock(ghost)
	if not ghost or not ghost:Exists() then return end
	if Ghost.get_pose_mode(ghost) ~= Ghost.POSE_MODE_RECORDED then return end
	local cache = ghost:GetData()[Ghost.RECORDED_STATE_KEY]
	if type(cache) ~= "table" then return end
	Ghost.set_animation(ghost, cache.anim, cache.overlay, cache.frame, cache.overlay_frame, {
		mode = Ghost.POSE_MODE_RECORDED,
		flip_x = cache.flip_x,
	})
end

function Ghost.set_tint(ghost, color)
	if not ghost or not ghost:Exists() or not color then return end
	local s = ghost:GetSprite()
	if s then
		s.Color = color
	end
end

function Ghost.setup_costumes(ghost, appearance)
	if not ghost or not ghost:Exists() then return end
	if not Ghost.ensure_bound() then return end
	if API.setup_costumes then
		API.setup_costumes(ghost, appearance)
	end
end

function Ghost.clear_costumes(ghost)
	if not ghost then return end
	if not Ghost.ensure_bound() then return end
	if API.clear_costumes then
		API.clear_costumes(ghost)
	end
end

function Ghost.play_animation(ghost, anim)
	if not ghost or not ghost:Exists() then return end
	if not Ghost.ensure_bound() then return end
	if API.ensure_anim then
		API.ensure_anim(ghost, anim)
	end
end

function Ghost.clear_overlay(ghost)
	if not ghost or not ghost:Exists() then return end
	if not Ghost.ensure_bound() then return end
	if API.clear_overlay then
		API.clear_overlay(ghost)
	end
end

function Ghost.sync_walk_head(ghost, anim)
	if not ghost or not ghost:Exists() then return end
	if not Ghost.ensure_bound() then return end
	if API.sync_head then
		API.sync_head(ghost, anim)
	end
end

function Ghost.get_probe_snapshot(ghost)
	if not Ghost.ensure_bound() then return nil end
	if API.get_probe_snapshot then
		return API.get_probe_snapshot(ghost)
	end
	return nil
end

function Ghost.ensure_held(ghost, visual)
	if not ghost or not ghost:Exists() then return nil end
	if not Ghost.ensure_bound() then return nil end
	if API.ensure_held then
		return API.ensure_held(ghost, visual)
	end
end

function Ghost.hide_held(ghost)
	if not ghost then return end
	if not Ghost.ensure_bound() then return end
	if API.hide_held then
		API.hide_held(ghost)
	end
end

function Ghost.get_held_info(ghost)
	if not ghost or not ghost:Exists() then return nil end
	if not Ghost.ensure_bound() then return nil end
	if API.get_held_info then
		return API.get_held_info(ghost)
	end
	return nil
end

function Ghost.sync_held(ghost, freeze)
	if not ghost or not ghost:Exists() then return end
	if not Ghost.ensure_bound() then return end
	if API.sync_held then
		API.sync_held(ghost, freeze == true)
	end
end

function Ghost.anim_done(ghost, anim, elapsed, fallback)
	if not Ghost.ensure_bound() then
		return (elapsed or 0) >= (fallback or 12)
	end
	if API.anim_done then
		return API.anim_done(ghost, anim, elapsed, fallback)
	end
	return (elapsed or 0) >= (fallback or 12)
end

function Ghost.destroy(ghost)
	if not ghost then return end
	pcall(function()
		local d = ghost:GetData()
		d[Ghost.RECORDED_STATE_KEY] = nil
		d[Ghost.LAYER_OVERRIDES_KEY] = nil
	end)
	if API and API.hide_held then
		API.hide_held(ghost)
	end
	if API and API.clear_costumes then
		API.clear_costumes(ghost)
	end
	pcall(function()
		if ghost:Exists() then ghost:Remove() end
	end)
end

-- Remaster already owns MeusNil PRE/UPDATE for its ghosts; these no-ops keep the module
-- loadable as a callback-bearing preload without duplicating Remaster's render path.
-- Pose/costume ticking continues to go through the Remaster-bound implementation when
-- the ghost was spawned via Ghost.spawn → API.spawn (which marks Remaster ghost keys).

return Ghost

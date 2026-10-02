-- Thin compatibility wrapper. Geometry lives in mimics/spirit_sword_geometry.lua.
-- Legacy Boss Qing authority: a frame without x1 is treated as no hitboxes
-- (even if x2 is present). Mimic uses Geometry.get_boxes directly and may use
-- Hit2-only frames.
local Geometry = require("Qing_Remaster_scripts.mimics.spirit_sword_geometry")

local item = {
	scaler = Geometry.BOSS_ATTACK_HITBOX_SCALE,
	posscaler = Geometry.BOSS_POSITION_SCALE,
	hit_info = Geometry.animations,
}

function item.get_hitbox(ent, currentFrame)
	local sprite = ent:GetSprite()
	local currentAnim = sprite:GetAnimation()
	currentFrame = currentFrame or sprite:GetFrame()
	return Geometry.get_raw_frame(currentAnim, currentFrame) or {}
end

local function boxes_for(ent, frame, scaler, posscaler)
	local sprite = ent:GetSprite()
	return Geometry.get_boxes({
		animation = sprite:GetAnimation(),
		frame = frame,
		origin = ent.Position,
		rotation = sprite.Rotation,
		scale = sprite.Scale,
		flip_x = sprite.FlipX == true,
		flip_y = sprite.FlipY == true,
		hitbox_scale = scaler,
		position_scale = posscaler,
	})
end

local function resolve_frame_from_raw(anim, hitbox)
	local frames = Geometry.animations[anim] or {}
	for i = 1, #frames do
		local f = frames[i]
		if f.x1 == hitbox.x1 and f.y1 == hitbox.y1 and f.rot1 == hitbox.rot1
			and f.x2 == hitbox.x2 and f.y2 == hitbox.y2 and f.rot2 == hitbox.rot2
		then
			return i - 1
		end
	end
	return nil
end

--- Legacy: require hitbox.x1 (Hit1). Hit2-only frames are ignored for Boss Qing.
function item.get_collision_boxes(ent, scaler, posscaler, hitbox, collision_boxes)
	posscaler = posscaler or item.posscaler
	scaler = scaler or item.scaler
	hitbox = hitbox or item.get_hitbox(ent)
	-- Legacy Boss authority: no Hit1 (x1) → no boxes for this call.
	-- If appending into an existing list (delay-frame path), keep prior boxes.
	if not hitbox or not hitbox.x1 then
		if collision_boxes ~= nil then
			return collision_boxes
		end
		return nil
	end

	local sprite = ent:GetSprite()
	local frame = sprite:GetFrame()
	-- When caller supplies a previous-frame raw hitbox, resolve its frame index.
	if hitbox ~= nil then
		local found = resolve_frame_from_raw(sprite:GetAnimation(), hitbox)
		if found ~= nil then
			frame = found
		end
	end

	local boxes = boxes_for(ent, frame, scaler, posscaler)
	collision_boxes = collision_boxes or {}
	for i = 1, #boxes do
		-- Geometry may still emit Hit2 for this frame; Boss legacy only used frames
		-- that had x1, which matches get_boxes when Hit1 exists.
		collision_boxes[#collision_boxes + 1] = boxes[i]
	end
	return collision_boxes
end

--- Legacy two-call pattern (not Geometry.get_frame_and_previous_boxes).
function item.get_collision_boxes_with_a_delay_frame(ent, scaler, posscaler)
	local collision_boxes = item.get_collision_boxes(ent, scaler, posscaler)
	collision_boxes = item.get_collision_boxes(
		ent,
		scaler,
		posscaler,
		item.get_hitbox(ent, ent:GetSprite():GetFrame() - 1),
		collision_boxes
	)
	return collision_boxes
end

return item

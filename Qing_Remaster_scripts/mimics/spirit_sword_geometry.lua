-- Shared Spirit Sword animation hit geometry (canonical Up-local).
-- Source: migrated from Boss_Qing_knife.hit_info (StabKnife Null Hit/Hit2 timeline).
-- Do not duplicate; Boss_Qing_knife and Spirit_Sword_holder both require this module.
local M = {}

M.animations = {
	SpinUp = {
		-- frame 0
			{x1 = 18, y1 = 18, rot1 = 45, scaleX1 = 450, scaleY1 = 100, x2 = 18, y2 = 18, rot2 = 67, scaleX2 = 450, scaleY2 = 100},
		-- frame 1
			{x1 = 18, y1 = 18, rot1 = 45, scaleX1 = 450, scaleY1 = 100, x2 = 18, y2 = 18, rot2 = 67, scaleX2 = 450, scaleY2 = 100},
		-- frame 2
			{x1 = 0, y1 = 24, rot1 = 90, scaleX1 = 450, scaleY1 = 300, x2 = 9, y2 = 22, rot2 = 67, scaleX2 = 450, scaleY2 = 100},
		-- frame 3
			{x1 = -18, y1 = 18, rot1 = 135, scaleX1 = 450, scaleY1 = 400, x2 = -10, y2 = 23, rot2 = 112, scaleX2 = 450, scaleY2 = 300},
		-- frame 4
			{x1 = -24, y1 = 0, rot1 = 180, scaleX1 = 450, scaleY1 = 400, x2 = -23, y2 = 10, rot2 = 157, scaleX2 = 450, scaleY2 = 400},
		-- frame 5
			{x1 = -18, y1 = -18, rot1 = 225, scaleX1 = 450, scaleY1 = 400, x2 = -24, y2 = -10, rot2 = 202, scaleX2 = 450, scaleY2 = 400},
		-- frame 6
			{x1 = 0, y1 = -24, rot1 = 270, scaleX1 = 450, scaleY1 = 400, x2 = -10, y2 = -21, rot2 = 247, scaleX2 = 450, scaleY2 = 400},
		-- frame 7
			{x1 = 18, y1 = -18, rot1 = 315, scaleX1 = 450, scaleY1 = 400, x2 = 10, y2 = -23, rot2 = 292, scaleX2 = 450, scaleY2 = 400},
		-- frame 8
			{x1 = 24, y1 = 0, rot1 = 0, scaleX1 = 450, scaleY1 = 400, x2 = 23, y2 = -11, rot2 = -23, scaleX2 = 450, scaleY2 = 400},
		-- frame 9
			{x1 = 18, y1 = 18, rot1 = 45, scaleX1 = 450, scaleY1 = 300, x2 = 23, y2 = 9, rot2 = 22, scaleX2 = 450, scaleY2 = 400},
		-- frame 10
			{x1 = 0, y1 = 24, rot1 = 90, scaleX1 = 450, scaleY1 = 100, x2 = 11, y2 = 21, rot2 = 67, scaleX2 = 450, scaleY2 = 300},
		-- frame 11
			{x1 = nil, y1 = nil, rot1 = nil, scaleX1 = nil, scaleY1 = nil, x2 = 0, y2 = 24, rot2 = 112, scaleX2 = 450, scaleY2 = 100},
	},
	AttackUp = {
		-- frame 0
			{x1 = 24, y1 = 0, rot1 = 0, scaleX1 = 450, scaleY1 = 100, x2 = 24, y2 = 0, rot2 = 0, scaleX2 = 450, scaleY2 = 100},
		-- frame 1
			{x1 = 18, y1 = 18, rot1 = 45, scaleX1 = 450, scaleY1 = 300, x2 = 21, y2 = 11, rot2 = 22, scaleX2 = 450, scaleY2 = 300},
		-- frame 2
			{x1 = 0, y1 = 24, rot1 = 90, scaleX1 = 450, scaleY1 = 400, x2 = 11, y2 = 21, rot2 = 67, scaleX2 = 450, scaleY2 = 300},
		-- frame 3
			{x1 = -18, y1 = 18, rot1 = 135, scaleX1 = 450, scaleY1 = 300, x2 = -10, y2 = 24, rot2 = 112, scaleX2 = 450, scaleY2 = 400},
		-- frame 4
			{x1 = -24, y1 = 0, rot1 = 180, scaleX1 = 450, scaleY1 = 100, x2 = -21, y2 = 11, rot2 = 157, scaleX2 = 450, scaleY2 = 300},
		-- frame 5
			{x1 = -24, y1 = 0, rot1 = 180, scaleX1 = 450, scaleY1 = 100, x2 = -24, y2 = 0, rot2 = 180, scaleX2 = 450, scaleY2 = 100},
	},
}

-- Boss Qing legacy defaults (gameplay); Mimic must use its own scales.
M.BOSS_ATTACK_HITBOX_SCALE = 10
M.BOSS_SPIN_HITBOX_SCALE = 20
M.BOSS_POSITION_SCALE = 2

-- Mimic placeholders pending NullCapsule calibration.
M.PLAYER_ATTACK_HITBOX_SCALE = 10
M.PLAYER_SPIN_HITBOX_SCALE = 12
M.PLAYER_POSITION_SCALE = 2

local function num(v, default)
	if v == nil then return default end
	return tonumber(v)
end

function M.get_raw_frame(animation, frame)
	local frames = M.animations[animation]
	if type(frames) ~= "table" then return nil end
	local idx = (tonumber(frame) or 0) + 1
	return frames[idx]
end

--- Transform one Null layer into a world oriented box.
--- Returns {center, rotation, half_length, half_width, scaleX, scaleY} (scale* = full extents).
local function transform_layer(origin, rotation_deg, sprite_scale, flip_x, flip_y, lx, ly, lrot, sx, sy, hitbox_scale, position_scale)
	if lx == nil or ly == nil then return nil end
	local scale_x = (sprite_scale and sprite_scale.X) or 1
	local scale_y = (sprite_scale and sprite_scale.Y) or 1
	local fx = flip_x and -1 or 1
	local fy = flip_y and -1 or 1
	local rad = math.rad(rotation_deg or 0)
	local cos_r = math.cos(rad)
	local sin_r = math.sin(rad)
	local rel_x = lx * scale_x * fx * position_scale
	local rel_y = ly * scale_y * fy * position_scale
	local rx = rel_x * cos_r - rel_y * sin_r
	local ry = rel_x * sin_r + rel_y * cos_r
	local local_rot = lrot or 0
	if fx == -1 then
		local_rot = 180 - local_rot
	end
	local world_rot = local_rot * fy + (rotation_deg or 0)
	local full_x = (sx or 100) / 100 * scale_x * math.abs(fx) * hitbox_scale
	local full_y = (sy or 100) / 100 * scale_y * math.abs(fy) * hitbox_scale
	return {
		center = Vector(origin.X + rx, origin.Y + ry),
		rotation = world_rot,
		half_length = full_x * 0.5,
		half_width = full_y * 0.5,
		scaleX = full_x,
		scaleY = full_y,
	}
end

--- opts: animation, frame, origin, rotation, scale(Vector), flip_x, flip_y, hitbox_scale, position_scale
function M.get_boxes(opts)
	opts = opts or {}
	local raw = M.get_raw_frame(opts.animation, opts.frame)
	if not raw then return {} end
	local origin = opts.origin or Vector.Zero
	local rotation = num(opts.rotation, 0)
	local scale = opts.scale or Vector(1, 1)
	local flip_x = opts.flip_x == true
	local flip_y = opts.flip_y == true
	local hitbox_scale = num(opts.hitbox_scale, 1)
	local position_scale = num(opts.position_scale, 1)
	local out = {}
	local b1 = transform_layer(origin, rotation, scale, flip_x, flip_y, raw.x1, raw.y1, raw.rot1, raw.scaleX1, raw.scaleY1, hitbox_scale, position_scale)
	if b1 then out[#out + 1] = b1 end
	local b2 = transform_layer(origin, rotation, scale, flip_x, flip_y, raw.x2, raw.y2, raw.rot2, raw.scaleX2, raw.scaleY2, hitbox_scale, position_scale)
	if b2 then out[#out + 1] = b2 end
	return out
end

function M.get_frame_and_previous_boxes(opts)
	opts = opts or {}
	local frame = num(opts.frame, 0)
	local boxes = M.get_boxes(opts)
	if frame > 0 then
		local prev = {}
		for k, v in pairs(opts) do prev[k] = v end
		prev.frame = frame - 1
		local prev_boxes = M.get_boxes(prev)
		for i = 1, #prev_boxes do
			boxes[#boxes + 1] = prev_boxes[i]
		end
	end
	return boxes
end

--- Point-vs-oriented-box (AABB in box local space). radius expands both axes.
function M.point_hits_box(point, box, radius)
	if not point or not box or not box.center then return false end
	radius = num(radius, 0)
	local relative = point - box.center
	local angle = math.rad(-(box.rotation or 0))
	local rx = relative.X * math.cos(angle) - relative.Y * math.sin(angle)
	local ry = relative.X * math.sin(angle) + relative.Y * math.cos(angle)
	local hl = num(box.half_length, (box.scaleX or 0) * 0.5) + radius
	local hw = num(box.half_width, (box.scaleY or 0) * 0.5) + radius
	return math.abs(rx) < hl and math.abs(ry) < hw
end

function M.draw_boxes(boxes, color)
	-- Isaac.DrawLine expects render/screen coords (same as glaze_placeholder debug lines).
	if type(boxes) ~= "table" or not Isaac.DrawLine then return end
	color = color or KColor(1, 0.2, 0.2, 0.9)
	for i = 1, #boxes do
		local box = boxes[i]
		if box and box.center then
			local hl = num(box.half_length, (box.scaleX or 0) * 0.5)
			local hw = num(box.half_width, (box.scaleY or 0) * 0.5)
			local rad = math.rad(box.rotation or 0)
			local c = math.cos(rad)
			local s = math.sin(rad)
			local function corner(lx, ly)
				local world = Vector(box.center.X + lx * c - ly * s, box.center.Y + lx * s + ly * c)
				return Isaac.WorldToScreen(world)
			end
			local p1 = corner(-hl, -hw)
			local p2 = corner(hl, -hw)
			local p3 = corner(hl, hw)
			local p4 = corner(-hl, hw)
			Isaac.DrawLine(p1, p2, color, color, 1)
			Isaac.DrawLine(p2, p3, color, color, 1)
			Isaac.DrawLine(p3, p4, color, color, 1)
			Isaac.DrawLine(p4, p1, color, color, 1)
		end
	end
end

return M

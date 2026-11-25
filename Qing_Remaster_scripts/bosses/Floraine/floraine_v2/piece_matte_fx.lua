-- Non-combat matte piece Effect: native entity Y-sort (not POST_RENDER Sprite).
-- Used by ante formation + Floraine reserve / deployment visuals.

local enums = require("Qing_Remaster_scripts.core.enums")
local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local reserve_defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_defs")

local fx = {}

local DATA_KEY = "QingFloraineMattePiece"
local spawn_stats = {
	spawns = 0,
	removes = 0,
	loadgraphics = 0,
	respawn_by_id = {}, -- piece_id -> consecutive respawn streak
}

local function variant()
	return enums.Entities.Floraine_Matte_Piece
end

local function safe_layer(sprite, id)
	if not sprite or not sprite.GetLayer then
		return nil
	end
	local ok, layer = pcall(function()
		if type(id) == "string" then
			return sprite:GetLayer(id) or sprite:GetLayer(id == "outline" and 1 or 0)
		end
		return sprite:GetLayer(id)
	end)
	if ok then
		return layer
	end
	return nil
end

local function set_layer(sprite, id, color, visible)
	local layer = safe_layer(sprite, id)
	if not layer then
		return
	end
	-- ANM2 Idle keeps outline Visible=true; hide via alpha / SetVisible when needed.
	if layer.SetVisible then
		layer:SetVisible(visible ~= false)
	end
	if layer.SetColor and color then
		layer:SetColor(color)
	end
end

local function lerp_color(a, b, t)
	t = math.max(0, math.min(1, t or 0))
	return Color(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t,
		a.A + (b.A - a.A) * t,
		0, 0, 0
	)
end

function fx.lerp_body_color(progress)
	local matte = reserve_defs.MATTE_COLOR
	local normal = Color(1, 1, 1, 1, 0, 0, 0)
	return lerp_color(matte, normal, progress or 0)
end

function fx.apply_sheet(ent, kind)
	local profile = piece_defs.get(kind)
	local s = ent:GetSprite()
	s:Load(piece_defs.ANM2, true)
	s:ReplaceSpritesheet(0, profile.spritesheet)
	s:ReplaceSpritesheet(1, piece_defs.outline_sheet(kind))
	s:LoadGraphics()
	s:Play("Idle", true)
	s.Offset = Vector.Zero
	s.Rotation = 0
	s.Scale = Vector(1, 1)
	s.Color = Color(1, 1, 1, 1, 0, 0, 0)
	return profile
end

--- Apply body / outline layers. outline_alpha 0 hides outline via transparent color.
function fx.apply_layers(ent, opts)
	opts = opts or {}
	local s = ent and ent:GetSprite()
	if not s then
		return
	end
	local progress = opts.color_progress or 0
	local body = opts.body_color or fx.lerp_body_color(progress)
	set_layer(s, "body", body, true)
	local oa = opts.outline_alpha or 0
	local rgb = opts.outline_rgb or { 1, 1, 1 }
	if oa > 0.01 then
		set_layer(s, "outline", Color(rgb[1], rgb[2], rgb[3], oa, 0, 0, 0), true)
	else
		-- Hide outline fully (Visible=false). Alpha-0 + Visible=true can flash white on sync.
		set_layer(s, "outline", Color(1, 1, 1, 0, 0, 0, 0), false)
	end
end

function fx.is_matte(ent)
	if not ent or not ent.Exists or not ent:Exists() then
		return false
	end
	if ent.Type ~= EntityType.ENTITY_EFFECT then
		return false
	end
	local v = variant()
	if not v or v < 0 or ent.Variant ~= v then
		return false
	end
	return ent:GetData()[DATA_KEY] ~= nil
end

function fx.spawn(kind, ground_pos, opts)
	opts = opts or {}
	local v = variant()
	if not v or v < 0 then
		return nil, "no_variant"
	end
	if not ground_pos then
		return nil, "no_pos"
	end
	kind = tonumber(kind) or piece_defs.KIND.PAWN
	local ent = Isaac.Spawn(EntityType.ENTITY_EFFECT, v, kind, ground_pos, Vector.Zero, nil)
	if not ent then
		return nil, "spawn_failed"
	end
	spawn_stats.spawns = spawn_stats.spawns + 1
	local pid = opts.piece_id
	if pid ~= nil then
		spawn_stats.respawn_by_id[pid] = (spawn_stats.respawn_by_id[pid] or 0) + 1
	end
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	if ent.CollisionDamage ~= nil then
		ent.CollisionDamage = 0
	end
	ent:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS | EntityFlag.FLAG_NO_TARGET)
	ent.Visible = true
	local data = ent:GetData()
	data[DATA_KEY] = {
		kind = kind,
		owner = opts.owner or "matte",
		piece_id = opts.piece_id,
	}
	fx.apply_sheet(ent, kind)
	spawn_stats.loadgraphics = spawn_stats.loadgraphics + 1
	local s = ent:GetSprite()
	if s then
		s.Rotation = tonumber(opts.visual_tilt) or 0
		local sx = tonumber(opts.scale_x) or 1
		local sy = tonumber(opts.scale_y) or 1
		s.Scale = Vector(sx, sy)
	end
	fx.apply_layers(ent, {
		color_progress = opts.color_progress or 0,
		outline_alpha = opts.outline_alpha or 0,
		outline_rgb = opts.outline_rgb,
	})
	-- Ground position owns Y-sort; height is visual-only via PositionOffset.
	ent.Position = Vector(ground_pos.X, ground_pos.Y)
	ent.PositionOffset = Vector(0, -(opts.visual_height or 0))
	return ent, "ok"
end

function fx.sync(ent, opts)
	if not fx.is_matte(ent) then
		return false
	end
	opts = opts or {}
	local ground = opts.ground_pos or opts.pos
	if ground then
		ent.Position = Vector(ground.X, ground.Y)
	end
	ent.PositionOffset = Vector(0, -(opts.visual_height or 0))
	ent.Visible = opts.hidden ~= true
	local s = ent:GetSprite()
	if s then
		s.Rotation = tonumber(opts.visual_tilt) or 0
		local sx = tonumber(opts.scale_x)
		local sy = tonumber(opts.scale_y)
		if sx ~= nil or sy ~= nil then
			s.Scale = Vector(sx or 1, sy or 1)
		end
	end
	fx.apply_layers(ent, opts)
	return true
end

function fx.remove(ent)
	if ent and ent.Exists and ent:Exists() then
		spawn_stats.removes = spawn_stats.removes + 1
		ent:Remove()
	end
end

function fx.get_spawn_stats()
	local max_streak, max_id = 0, nil
	for id, n in pairs(spawn_stats.respawn_by_id) do
		if n > max_streak then
			max_streak = n
			max_id = id
		end
	end
	return {
		spawns = spawn_stats.spawns,
		removes = spawn_stats.removes,
		loadgraphics = spawn_stats.loadgraphics,
		max_respawn_streak = max_streak,
		max_respawn_id = max_id,
	}
end

function fx.reset_spawn_stats()
	spawn_stats.spawns = 0
	spawn_stats.removes = 0
	spawn_stats.loadgraphics = 0
	spawn_stats.respawn_by_id = {}
end

fx.DATA_KEY = DATA_KEY
fx.variant = variant

return fx

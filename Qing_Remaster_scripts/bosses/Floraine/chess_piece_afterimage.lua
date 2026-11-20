-- Chess piece dash afterimages: history samples drawn with a dedicated Sprite.
-- Never mutates the live NPC Sprite (hurt flash / pivot / anim stay native).
-- Record on Update (30Hz); Render only reads and draws.

local defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")

local afterimage = {}

local RECORD_EVERY = 2 -- logic frames between samples
local MIN_DIST = 10 -- world units; skip near-duplicate samples
local LIFE_FRAMES = 8
local ghost_by_kind = {}

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
	if ghost.GetLayer then
		local ok, layer = pcall(function()
			return ghost:GetLayer("outline") or ghost:GetLayer(1)
		end)
		if ok and layer then
			if layer.SetVisible then layer:SetVisible(true) end
			if layer.SetColor then layer:SetColor(Color(1, 1, 1, 0, 0, 0, 0)) end
		end
	end
	ghost_by_kind[kind] = ghost
	return ghost
end

local function trail_cap(profile)
	local n = profile and tonumber(profile.afterimage_count)
	if not n or n < 1 then
		return 3
	end
	return math.min(4, math.floor(n))
end

--- Call once per NPC Update while the piece is translating.
function afterimage.record(ent, data)
	if not ent or not data then
		return
	end
	local st = data.action_state
	if st ~= "MOVING" and st ~= "ATTACKING" then
		return
	end
	data._ai_record_cd = (data._ai_record_cd or 0) - 1
	if data._ai_record_cd > 0 then
		return
	end
	data._ai_record_cd = RECORD_EVERY
	local profile = defs.get(data.kind)
	local list = data.afterimages
	if type(list) ~= "table" then
		list = {}
		data.afterimages = list
	end
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
	list[#list + 1] = {
		position = pos,
		height = data.visual_height or 0,
		rotation = data.visual_tilt or 0,
		scale = data.visual_scale or 1,
		age = 0,
		kind = data.kind,
	}
	local cap = trail_cap(profile)
	while #list > cap do
		table.remove(list, 1)
	end
end

--- Advance ages on Update only (never in Render).
function afterimage.tick(data)
	if not data or type(data.afterimages) ~= "table" then
		return
	end
	local list = data.afterimages
	local write = 1
	for i = 1, #list do
		local sample = list[i]
		sample.age = (sample.age or 0) + 1
		if sample.age <= LIFE_FRAMES then
			list[write] = sample
			write = write + 1
		end
	end
	for i = write, #list do
		list[i] = nil
	end
end

function afterimage.clear(data)
	if data then
		data.afterimages = nil
		data._ai_record_cd = nil
	end
end

--- Draw under the live piece (call from PRE_NPC_RENDER).
function afterimage.render(ent, data)
	if not ent or not data or type(data.afterimages) ~= "table" then
		return
	end
	local list = data.afterimages
	for i = 1, #list do
		local sample = list[i]
		local age = sample.age or 0
		local alpha = 0.32 * (1 - age / LIFE_FRAMES)
		if alpha > 0.02 then
			local ghost = ensure_ghost(sample.kind or data.kind)
			ghost.Rotation = sample.rotation or 0
			local sc = sample.scale or 1
			ghost.Scale = Vector(sc, sc)
			ghost.Color = Color(0.8, 0.86, 1, alpha, 0, 0, 0)
			ghost.Offset = Vector.Zero
			-- PositionOffset contract: world draw uses Position + visual height offset.
			local world = sample.position + Vector(0, -(sample.height or 0))
			ghost:Render(Isaac.WorldToScreen(world), Vector.Zero, Vector.Zero)
		end
	end
end

return afterimage

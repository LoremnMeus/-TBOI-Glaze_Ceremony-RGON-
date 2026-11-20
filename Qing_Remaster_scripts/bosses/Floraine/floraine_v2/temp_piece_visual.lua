-- Temp assault visuals: reuse piece ANM2/sheets with brighter translucent tint + trail.

local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")

local visual = {}

local LIFE_FRAMES = 8
local ghost_by_kind = {}

local function ensure_ghost(kind)
	kind = tonumber(kind) or piece_defs.KIND.PAWN
	local ghost = ghost_by_kind[kind]
	if ghost then return ghost end
	local profile = piece_defs.get(kind)
	ghost = Sprite()
	ghost:Load(piece_defs.ANM2, true)
	ghost:ReplaceSpritesheet(0, profile.spritesheet)
	ghost:ReplaceSpritesheet(1, piece_defs.outline_sheet(kind))
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

--- Brighter / slightly translucent vs permanent guards.
function visual.apply_sheet(effect, kind)
	local profile = piece_defs.get(kind)
	local s = effect:GetSprite()
	s:Load(piece_defs.ANM2, true)
	s:ReplaceSpritesheet(0, profile.spritesheet)
	s:ReplaceSpritesheet(1, piece_defs.outline_sheet(kind))
	s:LoadGraphics()
	s:Play("Idle", true)
	s.Offset = Vector.Zero
	s.Rotation = 0
	s.Scale = Vector(1, 1)
	s.Color = Color(1.15, 1.2, 1.35, 0.82, 0.15, 0.12, 0.05)
	if s.GetLayer then
		local ok, layer = pcall(function()
			return s:GetLayer("outline") or s:GetLayer(1)
		end)
		if ok and layer then
			if layer.SetVisible then layer:SetVisible(true) end
			if layer.SetColor then layer:SetColor(Color(1, 1, 1, 0, 0, 0, 0)) end
		end
	end
	return profile
end

function visual.set_phase_tint(effect, phase_name)
	local s = effect and effect:GetSprite()
	if not s then return end
	if phase_name == "PREPARE" then
		s.Color = Color(1.25, 1.3, 1.5, 0.9, 0.25, 0.18, 0.05)
	elseif phase_name == "DASH" then
		s.Color = Color(1.2, 1.25, 1.4, 0.95, 0.2, 0.1, 0.05)
	elseif phase_name == "FADE" then
		s.Color = Color(1.1, 1.1, 1.2, 0.35, 0.1, 0.08, 0.04)
	else
		s.Color = Color(1.15, 1.2, 1.35, 0.75, 0.15, 0.12, 0.05)
	end
end

function visual.record_trail(data, pos)
	if not data then return end
	data._ai_record_cd = (data._ai_record_cd or 0) - 1
	if data._ai_record_cd > 0 then return end
	data._ai_record_cd = 2
	local list = data.afterimages
	if type(list) ~= "table" then
		list = {}
		data.afterimages = list
	end
	list[#list + 1] = {
		position = Vector(pos.X, pos.Y),
		age = 0,
		kind = data.kind,
	}
	while #list > 4 do
		table.remove(list, 1)
	end
end

function visual.tick_trail(data)
	if not data or type(data.afterimages) ~= "table" then return end
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

function visual.render_trail(effect, data)
	if not effect or not data or type(data.afterimages) ~= "table" then return end
	for i = 1, #data.afterimages do
		local sample = data.afterimages[i]
		local alpha = 0.28 * (1 - (sample.age or 0) / LIFE_FRAMES)
		if alpha > 0.02 then
			local ghost = ensure_ghost(sample.kind or data.kind)
			ghost.Rotation = 0
			ghost.Scale = Vector(1, 1)
			ghost.Color = Color(0.95, 1.05, 1.25, alpha, 0.1, 0.08, 0.05)
			ghost:Render(Isaac.WorldToScreen(sample.position), Vector.Zero, Vector.Zero)
		end
	end
end

return visual

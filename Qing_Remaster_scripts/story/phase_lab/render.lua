-- Phase Lab code-drawn visuals (1px lines / diamonds / text placeholders).

local defs = require("Qing_Remaster_scripts.story.phase_lab.defs")
local puzzle = require("Qing_Remaster_scripts.story.phase_lab.puzzle")
local materials = require("Qing_Remaster_scripts.story.phase_lab.materials")
local anchor = require("Qing_Remaster_scripts.story.phase_lab.anchor")
local pixel_ui = require("Qing_Remaster_scripts.auxiliary.pixel_ui")

local render = {}

local function P(x)
	return math.floor((x or 0) + 0.5)
end

local function V(x, y)
	return Vector(P(x), P(y))
end

local function w2s(world)
	if not world then return Vector(0, 0) end
	return Isaac.WorldToScreen(world)
end

local function line(a, b, col, w)
	if not Isaac.DrawLine then return end
	Isaac.DrawLine(a, b, col, col, w or 1)
end

local function fill_diamond(cx, cy, r, col)
	r = math.max(1, P(r))
	for dy = -r, r do
		local half = r - math.abs(dy)
		line(V(cx - half, cy + dy), V(cx + half, cy + dy), col, 1)
	end
end

local function outline_diamond(cx, cy, r, col)
	r = math.max(1, P(r))
	line(V(cx, cy - r), V(cx + r, cy), col, 1)
	line(V(cx + r, cy), V(cx, cy + r), col, 1)
	line(V(cx, cy + r), V(cx - r, cy), col, 1)
	line(V(cx - r, cy), V(cx, cy - r), col, 1)
end

local COL = {
	dim = KColor(0.40, 0.38, 0.34, 0.55),
	line = KColor(0.72, 0.64, 0.48, 0.85),
	lit = KColor(0.95, 0.86, 0.55, 0.95),
	full = KColor(1.0, 0.92, 0.60, 1.0),
	block = KColor(0.78, 0.72, 0.58, 0.95),
	block_ok = KColor(0.70, 0.90, 0.68, 0.95),
	text = KColor(0.92, 0.90, 0.82, 0.95),
	mute = KColor(0.62, 0.60, 0.55, 0.80),
	reset = KColor(0.85, 0.55, 0.40, 0.95),
	slot = KColor(0.55, 0.70, 0.95, 0.90),
	slot_on = KColor(0.95, 0.82, 0.45, 0.95),
	anchor = KColor(0.90, 0.78, 0.42, 0.95),
	warn = KColor(0.95, 0.45, 0.40, 0.90),
}

local function draw_track(center, id)
	local b = defs.BLOCKS[id]
	if not b or b.type == "rotate" or b.type == "phase" then return end
	local lit = puzzle.segment_lit(id)
	local col = lit and COL.lit or COL.dim
	local count = b.count or 1
	for i = 0, count - 1 do
		local wp = defs.block_world_pos(center, id, i)
		local sp = w2s(wp)
		outline_diamond(sp.X, sp.Y, 3, col)
		if i < count - 1 then
			local wp2 = defs.block_world_pos(center, id, i + 1)
			local sp2 = w2s(wp2)
			line(sp, sp2, col, 1)
		end
	end
end

local function draw_block(center, id)
	local b = defs.BLOCKS[id]
	if not b then return end
	local wp = puzzle.presented_pos(center, id)
	local sp = w2s(wp)
	local ok = puzzle.segment_lit(id)
	local col = ok and COL.block_ok or COL.block
	-- body
	line(V(sp.X - 10, sp.Y - 8), V(sp.X + 10, sp.Y - 8), col, 1)
	line(V(sp.X + 10, sp.Y - 8), V(sp.X + 10, sp.Y + 8), col, 1)
	line(V(sp.X + 10, sp.Y + 8), V(sp.X - 10, sp.Y + 8), col, 1)
	line(V(sp.X - 10, sp.Y + 8), V(sp.X - 10, sp.Y - 8), col, 1)
	if b.type == "rotate" then
		local states = puzzle.get_states()
		local ang = (tonumber(states[id]) or 0) * 90
		local rad = math.rad(ang)
		local dx = math.cos(rad) * 10
		local dy = math.sin(rad) * 10
		line(V(sp.X, sp.Y), V(sp.X + dx, sp.Y + dy), COL.lit, 1)
		line(V(sp.X, sp.Y), V(sp.X - dy, sp.Y + dx), COL.dim, 1)
	elseif b.type == "phase" then
		local states = puzzle.get_states()
		local ph = tonumber(states[id]) or 0
		if ph == 0 then
			line(V(sp.X - 8, sp.Y), V(sp.X + 8, sp.Y), COL.line, 1)
		else
			-- dashed-like
			line(V(sp.X - 8, sp.Y), V(sp.X - 2, sp.Y), COL.lit, 1)
			line(V(sp.X + 2, sp.Y), V(sp.X + 8, sp.Y), COL.lit, 1)
		end
	end
	pixel_ui.draw_text_centered(sp.X, sp.Y - 14, b.label or id, 1, COL.text, {
		context = "PhaseLab.block",
	})
	if puzzle.get_debug_overlay() then
		local st = puzzle.get_states()[id]
		local tg = defs.SOLUTION[id]
		pixel_ui.draw_text_centered(
			sp.X, sp.Y + 12,
			string.format("%s=%s→%s", id, tostring(st), tostring(tg)),
			1, COL.mute, {context = "PhaseLab.debug"}
		)
	end
end

local function draw_anchor(center)
	local wp = center + defs.LAYOUT.anchor
	local sp = w2s(wp)
	local st = anchor.get_state()
	local col = COL.anchor
	if st == "ready" then col = COL.full end
	if st == "activating" or st == "open" then col = COL.lit end
	outline_diamond(sp.X, sp.Y, 6, col)
	outline_diamond(sp.X, sp.Y, 10, COL.dim)
	outline_diamond(sp.X, sp.Y, 14, COL.dim)
	fill_diamond(sp.X, sp.Y, 3, col)
	local prog = puzzle.completion_progress()
	if prog > 0 and prog < 1 then
		local r = 14 + math.floor(prog * 8)
		outline_diamond(sp.X, sp.Y, r, COL.lit)
	end
	local ap = anchor.activation_progress()
	if ap > 0 then
		outline_diamond(sp.X, sp.Y, 16 + math.floor(ap * 12), COL.full)
	end
	local label = "ANCHOR"
	if st == "ready" then label = "READY" end
	if st == "activating" then label = "LOCKING" end
	if st == "open" then label = "OPEN" end
	pixel_ui.draw_text_centered(sp.X, sp.Y + 20, label, 1, COL.text, {
		context = "PhaseLab.anchor",
	})
end

local function draw_slot(center, key)
	local def = defs.MATERIALS[key]
	if not def then return end
	local wp = center + def.offset
	local sp = w2s(wp)
	local on = materials.is_inserted(key)
	local col = on and COL.slot_on or COL.slot
	outline_diamond(sp.X, sp.Y, 7, col)
	if on then fill_diamond(sp.X, sp.Y, 3, col) end
	pixel_ui.draw_text_centered(sp.X, sp.Y - 16, def.short or key, 1, COL.text, {
		context = "PhaseLab.slot",
	})
end

local function draw_reset(center)
	local wp = center + defs.LAYOUT.reset
	local sp = w2s(wp)
	line(V(sp.X - 18, sp.Y - 10), V(sp.X + 18, sp.Y - 10), COL.reset, 1)
	line(V(sp.X + 18, sp.Y - 10), V(sp.X + 18, sp.Y + 10), COL.reset, 1)
	line(V(sp.X + 18, sp.Y + 10), V(sp.X - 18, sp.Y + 10), COL.reset, 1)
	line(V(sp.X - 18, sp.Y + 10), V(sp.X - 18, sp.Y - 10), COL.reset, 1)
	local zh = not (Options and Options.Language == "en")
	pixel_ui.draw_text_centered(
		sp.X, sp.Y - 4,
		zh and "↺ 重置" or "↺ RESET",
		1, COL.reset, {context = "PhaseLab.reset"}
	)
	pixel_ui.draw_text_centered(
		sp.X, sp.Y + 8,
		zh and "相位校准" or "CALIBRATE",
		1, COL.mute, {context = "PhaseLab.reset"}
	)
end

local function draw_terminal(center)
	local wp = center + defs.LAYOUT.terminal
	local sp = w2s(wp)
	line(V(sp.X - 52, sp.Y - 28), V(sp.X + 52, sp.Y - 28), COL.dim, 1)
	line(V(sp.X + 52, sp.Y - 28), V(sp.X + 52, sp.Y + 28), COL.dim, 1)
	line(V(sp.X + 52, sp.Y + 28), V(sp.X - 52, sp.Y + 28), COL.dim, 1)
	line(V(sp.X - 52, sp.Y + 28), V(sp.X - 52, sp.Y - 28), COL.dim, 1)
	local lines = anchor.status_lines()
	local y = sp.Y - 22
	for _, text in ipairs(lines) do
		pixel_ui.draw_text(V(sp.X - 48, y), text, 1, COL.text, {
			context = "PhaseLab.terminal",
		})
		y = y + 12
	end
end

local function draw_title(center)
	local sp = w2s(center + Vector(0, -150))
	local zh = not (Options and Options.Language == "en")
	pixel_ui.draw_text_centered(
		sp.X, sp.Y,
		zh and "相位锚炼金实验室" or "Phase Anchor Laboratory",
		1, COL.text, {context = "PhaseLab.title"}
	)
	if puzzle.is_replay() then
		pixel_ui.draw_text_centered(
			sp.X, sp.Y + 12,
			zh and "〔重新校准〕" or "[REPLAY MODE]",
			1, COL.warn, {context = "PhaseLab.title"}
		)
	elseif not puzzle.is_solved() then
		pixel_ui.draw_text_centered(
			sp.X, sp.Y + 12,
			zh and "法阵未校准" or "ARRAY UNSTABLE",
			1, COL.mute, {context = "PhaseLab.title"}
		)
	end
end

function render.draw_lab(center, opts)
	opts = opts or {}
	if not center then return end
	draw_title(center)
	for _, id in ipairs(defs.BLOCK_IDS) do
		draw_track(center, id)
	end
	if puzzle.is_solved() and not puzzle.is_replay() then
		-- solved ring
		local sp = w2s(center)
		outline_diamond(sp.X, sp.Y, 48, COL.lit)
		outline_diamond(sp.X, sp.Y, 56, COL.dim)
	end
	for _, id in ipairs(defs.BLOCK_IDS) do
		draw_block(center, id)
	end
	draw_anchor(center)
	draw_reset(center)
	draw_terminal(center)
	if puzzle.is_solved() and not puzzle.is_replay() then
		for key, _ in pairs(defs.MATERIALS) do
			draw_slot(center, key)
		end
	end
	if opts.prompt and opts.prompt ~= "" then
		local sp = w2s(center + Vector(0, 160))
		pixel_ui.draw_text_centered(sp.X, sp.Y, opts.prompt, 1, COL.mute, {
			context = "PhaseLab.prompt",
		})
	end
end

function render.draw_door_hint(world_pos)
	if not world_pos then return end
	local sp = w2s(world_pos)
	outline_diamond(sp.X, sp.Y - 20, 5, COL.lit)
	fill_diamond(sp.X, sp.Y - 20, 2, COL.full)
	local zh = not (Options and Options.Language == "en")
	pixel_ui.draw_text_centered(
		sp.X, sp.Y - 36,
		zh and "相位锚" or "PHASE",
		1, COL.text, {context = "PhaseLab.door"}
	)
end

return render

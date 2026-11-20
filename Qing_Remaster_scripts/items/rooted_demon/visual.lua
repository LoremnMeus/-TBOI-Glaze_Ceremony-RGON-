local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local history_hud = require("Qing_Remaster_scripts.callbacks.history_hud_render_holder")
local visual = {}
local cache, jobs, tick = {}, {}, 0
local phases = {{"wait",20},{"summon",8},{"extend",24},{"wrap",12},{"lift",18},{"hold",30},{"windup",8},{"release",3},{"throw",26},{"impact",3},{"poof",8},{"retract",18}}
local debug_anchors = false
local simulated_alpha = 0.5
local icon
local anchor
local redraw_icons = {}
local hud_diagnostic = "HUD callback pending"
local CONSUMER_NAME = "RootedDemon"

local function hud_scale()
	return (Options.ExtraHUDStyle or 1) == 2 and 0.5 or 1
end

local function sprite_origin(center, scale)
	-- 005.100_collectible.anm2 Idle/head uses a pedestal pivot. Match temp_item_hud_holder's
	-- (16,38) / (8,19) pad after converting a HUD slot to its icon center.
	return center + Vector(0, 22 * scale)
end

local function stage(age, anim)
	local passed = 0
	for _, row in ipairs(phases) do
		local duration = row[1] == "throw" and anim and anim.flight_frames or row[2]
		if age < passed + duration then return row[1], (age - passed) / duration end
		passed = passed + duration
	end
	return "done", 1
end

local function identity(id, time, occurrence)
	return table.concat({id, time, occurrence}, ":")
end

--- Refresh local cache from history_hud_render_holder layout (no second GetCollectibles pass).
function visual.capture_history(_hud, _pos, _redraw)
	local slot_diagnostics = {}
	local seen = {}
	for _, player in ipairs(auxi.GetPlayers()) do
		local pindex = player:GetData().__Index
		if pindex ~= nil and not seen[pindex] then
			seen[pindex] = true
			local lay = history_hud.get_layout(pindex)
			if lay then
				-- Keep only collectible rows for Rooted Demon anchors / growth.
				local positions, visible, rows = {}, {}, {}
				for _, row in ipairs(lay.rows or {}) do
					if row.kind == "collectible" then
						local pos = row.pos or (lay.positions and lay.positions[row.key])
						positions[row.key] = pos
						visible[row.key] = row.visible
						if lay.visible and lay.visible[row.key] ~= nil then
							visible[row.key] = lay.visible[row.key]
						end
						rows[#rows + 1] = row
					end
				end
				cache[pindex] = {
					frame = lay.frame or Game():GetFrameCount(),
					positions = positions,
					visible = visible,
					rows = rows,
				}
				local row_keys = {}
				for _, row in ipairs(rows) do row_keys[#row_keys + 1] = row.key end
				slot_diagnostics[#slot_diagnostics + 1] = string.format(
					"index=%s holder=Y rows=[%s]", tostring(pindex), table.concat(row_keys, ",")
				)
			else
				slot_diagnostics[#slot_diagnostics + 1] = string.format("index=%s holder=N", tostring(pindex))
			end
		end
	end
	hud_diagnostic = (#slot_diagnostics > 0) and table.concat(slot_diagnostics, " | ") or "holder layout pending"
	for _, anim in ipairs(jobs) do
		if anim.started and not anim.landed and not anim.offscreen then
			anim.source = anchor(anim, anim.job.root_id, anim.job.root_time, anim.job.root_occurrence) or anim.source
			anim.target = anchor(anim, anim.job.id, anim.job.time, anim.job.occurrence) or anim.target
		end
	end
end

anchor = function(anim, id, time, occurrence)
	local row = cache[anim.player_index]
	if row and Game():GetFrameCount() - row.frame <= 4 then
		local key = identity(id, time, occurrence)
		local found = row.visible[key] and row.positions[key]
		if found then return found end
	end
end

function visual.hidden_items(player_index)
	local hidden = {}
	for _, anim in ipairs(jobs) do
		local name = stage(tick - anim.start, anim)
		if (player_index == nil or anim.player_index == player_index)
			and anim.started and anim.source and name ~= "wait" and name ~= "done" then
			local hidden_rows = {
				{id = anim.job.id, time = anim.job.time, occurrence = anim.job.occurrence},
			}
			hidden_rows[#hidden_rows + 1] = {
				id = anim.job.root_id, time = anim.job.root_time,
				occurrence = anim.job.root_occurrence,
			}
			for _, row in ipairs(hidden_rows) do
				hidden[row.id] = hidden[row.id] or {}
				hidden[row.id][identity(row.id, row.time, row.occurrence)] = true
			end
		end
	end
	return hidden
end

--- Legacy no-op: HideCollectibles is owned by history_hud_render_holder.
function visual.pre_history()
	return nil
end

local function apply_slot_tint(sprite, player_index, id, time, occurrence, alpha_mul, base_scale)
	history_hud.apply_to_sprite(sprite, {
		player_index = player_index,
		kind = "collectible",
		id = id,
		history_time = time,
		occurrence = occurrence,
	}, {
		alpha_mul = alpha_mul,
		base_scale = base_scale,
	})
end

icon = function(id, centered)
	local s = Sprite()
	-- The flying icon has a 16x16 head pivot; the vanilla pedestal pivot rotates around its base.
	s:Load(centered and "gfx/mimics/Rooted_Demon/flying_icon.anm2" or "gfx/005.100_collectible.anm2", false)
	local layer = centered and 0 or 1
	if EntityPickup.SetupCollectibleGraphics then
		EntityPickup.SetupCollectibleGraphics(s, layer, id, false, 1, true)
	else
		local cfg = Isaac.GetItemConfig():GetCollectible(id)
		if cfg then s:ReplaceSpritesheet(layer, cfg.GfxFileName) s:LoadGraphics() end
	end
	s:Play(s:GetDefaultAnimation(), true)
	return s
end

function visual.draw_history_icon(id, center, alpha, meta)
	local sprite = redraw_icons[id]
	if not sprite then sprite = icon(id) redraw_icons[id] = sprite end
	local scale = hud_scale()
	sprite.Color = Color(1, 1, 1, alpha or 1)
	if meta then
		apply_slot_tint(sprite, meta.player_index, id, meta.time, meta.occurrence, alpha or 1, scale)
	else
		sprite.Scale = Vector(scale, scale)
	end
	sprite:Render(sprite_origin(center, scale), Vector.Zero, Vector.Zero)
end

function visual.make_root_brush()
	local brush = {}
	for name, file in pairs({root = "root_tendril", stem = "root_stem",
		tip = "root_tip", knot = "root_knot", junction = "root_junction"}) do
		local sprite = Sprite()
		sprite:Load("gfx/mimics/Rooted_Demon/" .. file .. ".anm2", true)
		sprite:Play("Idle", true)
		brush[name] = sprite
	end
	return brush
end

function visual.queue(player, job, ordinal, commit)
	local room = Game():GetRoom()
	local offset = Vector(((ordinal - 1) % 3 - 1) * 80, -52 + math.floor((ordinal - 1) / 3) * 50)
	if room:IsMirrorWorld() then
		offset = Vector(-offset.X, offset.Y)
	end
	local desired = room:GetCenterPos() + offset
	local brush = visual.make_root_brush()
	jobs[#jobs + 1] = {
		player = player, player_index = player:GetData().__Index, job = job, commit = commit,
		landing = room:FindFreePickupSpawnPosition(desired, 0, true),
		start = tick, started = false, icon = icon(job.id, true), root_icon = icon(job.root_id),
		root = brush.root, stem = brush.stem, tip = brush.tip, knot = brush.knot,
	}
end

local function path(a, b, bend)
	local delta = b - a
	local p1 = a + delta * 0.3 + Vector(0, bend)
	local p2 = a + delta * 0.7 + Vector(0, -bend * 0.6)
	return function(t) return auxi.Bezier4(a, p1, p2, b, t) end
end

local function draw_path(anim, curve, extent, width, sections)
	sections = sections or 9
	for n = 1, math.ceil(sections * extent) do
		local t0, t1 = (n - 1) / sections, math.min(n / sections, extent)
		if t1 > t0 then
			local a, b = curve(t0), curve(t1)
			local delta = b - a
			local segment = n == math.ceil(sections * extent) and anim.tip
				or (width >= 0.9 and anim.stem or anim.root)
			local length = segment == anim.root and 31 or 15
			segment.Scale = Vector(delta:Length() / length, width * (1 - t0 * 0.4))
			segment.Rotation = delta:GetAngleDegrees()
			segment.Color = Color(0.8, 0.7, 0.55, 0.95)
			segment:Render((a + b) * 0.5, Vector.Zero, Vector.Zero)
		end
	end
end

function visual.draw_root_path(brush, source, target, extent, width, bend, sections)
	if extent <= 0 then return end
	draw_path(brush, path(source, target, bend or 0), math.min(1, extent), width or 1, sections)
end

function visual.draw_root_knot(brush, center, scale)
	if scale <= 0 then return end
	-- root_knot is 24x24 with a centered (12,12) pivot; fit the HUD icon's scale.
	brush.knot.Scale = Vector(scale, scale) * hud_scale() * 1.25
	brush.knot.Color = Color(1, 1, 1, math.min(1, scale))
	brush.knot:Render(center, Vector.Zero, Vector.Zero)
end

function visual.draw_root_junction(brush, center, scale, alpha)
	if scale <= 0 then return end
	brush.junction.Scale = Vector(scale * 0.72, scale * 0.88) * hud_scale()
	brush.junction.Color = Color(0.58, 0.53, 0.46, alpha or 1)
	brush.junction:Render(center, Vector.Zero, Vector.Zero)
end

function visual.draw_root_strike(brush, source, target, extent, width, opts)
	opts = opts or {}
	local tip_extent = math.min(1, opts.tip_extent or extent)
	if tip_extent <= 0 then return end
	local delta = target - source
	if delta:Length() <= 0 then return end
	local main_extent = math.max(0, math.min(1, extent))
	local normal = Vector(-delta.Y, delta.X):Normalized()
	local bend = opts.bend or 0
	local function point(t)
		local arc = math.sin(math.pi * t)
		return source + delta * t + normal * (bend * arc * arc)
	end
	-- Overlap each stem section so transparent sprite margins cannot split the trunk.
	local sections = math.ceil(delta:Length() * main_extent / 18)
	if math.abs(bend) > 0.2 and delta:Length() * main_extent >= 8 then
		sections = math.max(sections, 3)
	end
	for i = 1, sections do
		local t0, t1 = main_extent * (i - 1) / sections, main_extent * i / sections
		local a, b = point(t0), point(t1)
		local section = b - a
		local sprite = brush.stem
		local overlap = math.min(5, section:Length() * 0.5 + 1)
		sprite.Scale = Vector((section:Length() + overlap) / 16, width * (1 - t0 * 0.34))
		sprite.Rotation = section:GetAngleDegrees()
		sprite.Color = Color(0.8, 0.7, 0.55, 0.98)
		sprite:Render((a + b) * 0.5, Vector.Zero, Vector.Zero)
	end
	if tip_extent > main_extent then
		local a, b = point(main_extent), point(tip_extent)
		local connector = brush.root
		connector.Scale = Vector(((b - a):Length() + 4) / 31, width * 0.42)
		connector.Rotation = (b - a):GetAngleDegrees()
		connector.Color = Color(0.78, 0.67, 0.52, 0.96)
		connector:Render((a + b) * 0.5, Vector.Zero, Vector.Zero)
	end
	if opts.branches and main_extent > 0.6 and delta:Length() > 75 then
		for i = 1, 2 do
			local t = i == 1 and 0.27 or 0.58
			if t < main_extent then
				local branch = brush.root
				branch.Scale = Vector(0.48, width * 0.33)
				branch.Rotation = delta:GetAngleDegrees() + (i == 1 and 37 or -42)
				branch.Color = Color(0.73, 0.62, 0.47, 0.9)
				branch:Render(point(t) + normal * (i == 1 and 3 or -3), Vector.Zero, Vector.Zero)
			end
		end
	end
	local tip = brush.tip
	tip.Scale = Vector(1.2 * (opts.tip_scale or 1), width * (opts.tip_width or 0.65))
	tip.Rotation = (point(tip_extent) - point(math.max(0, tip_extent - 0.05))):GetAngleDegrees()
	tip.Color = Color(0.9, 0.78, 0.57, 1)
	tip:Render(point(tip_extent), Vector.Zero, Vector.Zero)
end

function visual.draw_root_impact(brush, center, direction, alpha)
	if alpha <= 0 then return end
	local angle = direction:GetAngleDegrees()
	for _, side in ipairs({-1, 1}) do
		local splinter = brush.root
		splinter.Scale = Vector(0.43, 0.45)
		splinter.Rotation = angle + side * 55
		splinter.Color = Color(0.82, 0.69, 0.51, alpha)
		splinter:Render(center, Vector.Zero, Vector.Zero)
	end
end

local function draw_cross(point, color, label)
	if not point then return end
	Isaac.DrawLine(point + Vector(-5, 0), point + Vector(5, 0), color, color, 1)
	Isaac.DrawLine(point + Vector(0, -5), point + Vector(0, 5), color, color, 1)
	Isaac.RenderText(label, point.X + 7, point.Y - 7, color.Red, color.Green, color.Blue, 1)
end

local function history_has(anim, id, time, occurrence)
	local count = 0
	local history = anim.player:GetHistory():GetCollectiblesHistory()
	for _, entry in ipairs(history) do
		if not entry:IsTrinket() and entry:GetItemID() == id
			and entry:GetTime() == time then
			count = count + 1
			if count == occurrence then return true end
		end
	end
	return false
end

function visual.update()
	tick = tick + 1
	if #jobs == 0 then return end
	local hud = Game():GetHUD()
	local history_hud = hud and hud:GetHistoryHUD()
	local history_visible = hud and hud:IsVisible() and (Options.ExtraHUDStyle or 0) > 0
	if history_visible and history_hud then
		visual.capture_history(history_hud, history_hud:GetPosition(), false)
	end
	local waiting, fallback = false, {}
	for _, anim in ipairs(jobs) do
		if not anim.started then
			waiting = true
			anim.source = history_visible and anchor(anim, anim.job.root_id, anim.job.root_time, anim.job.root_occurrence)
			anim.target = history_visible and anchor(anim, anim.job.id, anim.job.time, anim.job.occurrence)
			if not anim.source or not anim.target then fallback[#fallback + 1] = anim end
		end
	end
	if #fallback > 0 then
		local screen = ui.GetScreenSize()
		local base_x = history_hud and history_hud:GetPosition().X + 16 or 32
		local spacing = math.min(48, (screen.X - 64) / math.max(1, #fallback - 1))
		local first_x = math.max(32, math.min(base_x, screen.X - 32 - spacing * (#fallback - 1)))
		for i, anim in ipairs(fallback) do
			local x = first_x + spacing * (i - 1)
			anim.offscreen = true
			anim.source = Vector(x, screen.Y + 24)
			anim.target = Vector(x, screen.Y - 28)
			anim.emerge = Vector(x, screen.Y + 36)
		end
	end
	if waiting then
		for _, anim in ipairs(jobs) do
			if not anim.started then
				local lifted = anim.target + Vector(0, -(anim.offscreen and 18 or 27))
				local finish = auxi.world_to_ui_screen(anim.landing, ui.GetHUDRenderOffset())
				local delta = finish - lifted
				anim.throw_direction = delta:Length() > 0 and delta:Normalized() or Vector(1, 0)
				anim.throw_origin = lifted + anim.throw_direction * 24
				anim.flight_frames = math.max(24, math.min(28, math.floor((finish - anim.throw_origin):Length() / 18 + 0.5)))
				anim.started = true
				anim.start = tick
			end
		end
	end
	-- Jobs are queued in descending history index, so commit in this order too.
	-- Removing a later duplicate first keeps earlier occurrence indices stable.
	for _, anim in ipairs(jobs) do
		local age = tick - anim.start
		local name = anim.started and stage(age, anim) or "anchor_wait"
		if name == "impact" and not anim.landed then
			anim.landed = true
			local poof = Isaac.Spawn(EntityType.ENTITY_EFFECT,
				EffectVariant.POOF02 or EffectVariant.ROCK_POOF or EffectVariant.POOF01,
				1, anim.landing, Vector.Zero, nil)
			if poof then
				local effect = poof:ToEffect() or poof
				effect.SpriteScale = Vector(1.25, 1.25)
				if effect.LifeSpan ~= nil then effect.LifeSpan = 18 end
				if effect.Timeout ~= nil then effect.Timeout = 18 end
			end
			if anim.commit then
				local ok, committed = pcall(anim.commit, anim.landing)
				anim.committed = ok and committed
			else
				anim.preview = true
			end
		end
	end
	for i = #jobs, 1, -1 do
		local anim = jobs[i]
		if (anim.started and stage(tick - anim.start, anim) == "done")
			or (not anim.landed and (not history_has(anim, anim.job.id, anim.job.time, anim.job.occurrence)
				or not history_has(anim, anim.job.root_id, anim.job.root_time, anim.job.root_occurrence))) then
			table.remove(jobs, i)
		end
	end
end

function visual.render()
	if #jobs == 0 then return end
	if Isaac.IsInGame and not Isaac.IsInGame() then return end
	local room = Game():GetRoom()
	if not room or room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	for _, anim in ipairs(jobs) do
		local name, t = stage(tick - anim.start, anim)
		local moving
		if anim.started and anim.source and name ~= "wait" and name ~= "done" then
			local target, source = anim.target, anim.source
			local lift_height = anim.offscreen and 18 or 27
			local lifted = target + Vector(0, -lift_height)
			local pos, extent = target, 1
			local support = pos
			if name == "summon" then
				extent = 0
				if anim.offscreen then pos = anim.emerge end
			elseif name == "extend" then
				extent = t
				if anim.offscreen then
					local rise = t * t * (3 - 2 * t)
					pos = anim.emerge + (target - anim.emerge) * rise
				end
			elseif name == "lift" then pos = target + Vector(0, -lift_height * t * t * (3 - 2 * t)) support = pos
			elseif name == "hold" then pos = lifted + Vector(0, math.sin(t * 6.28) * 1.5) support = pos
			elseif name == "windup" then pos = lifted - anim.throw_direction * (8 * t * t * (3 - 2 * t)) support = pos
			elseif name == "release" then
				local burst = 1 - (1 - t) * (1 - t)
				pos = lifted - anim.throw_direction * 8 + (anim.throw_origin - lifted + anim.throw_direction * 8) * burst
				support = pos
			elseif name == "throw" then
				local finish = auxi.world_to_ui_screen(anim.landing, ui.GetHUDRenderOffset())
				local start = anim.throw_origin
				local frames, gravity = anim.flight_frames, 1.1
				local velocity = (finish - start - Vector(0, gravity * frames * frames * 0.5)) / frames
				local elapsed = frames * t
				pos = start + velocity * elapsed + Vector(0, gravity * elapsed * elapsed * 0.5)
				local down = math.min(1, elapsed / 5)
				down = down * down * (3 - 2 * down)
				local recoil = math.sin(math.pi * math.min(1, elapsed / 5)) * 5
				support = start + (target - start) * down - anim.throw_direction * recoil
			elseif name == "impact" then
				pos = auxi.world_to_ui_screen(anim.landing, ui.GetHUDRenderOffset())
			elseif name == "retract" then
				extent = 1 - t
			end
			if extent > 0 then
				draw_path(anim, path(source, target + Vector(-7, 2), -18), extent, 1)
				draw_path(anim, path(source + Vector(2, 2), target + Vector(7, -2), 17), math.max(0, (extent - 0.16) / 0.84), 0.7)
				draw_path(anim, path(source + Vector(-2, 0), target + Vector(0, 8), -8), math.max(0, (extent - 0.32) / 0.68), 0.55)
				if name == "lift" or name == "hold" or name == "windup" or name == "release"
					or (name == "throw" and t * anim.flight_frames < 5) then
					draw_path(anim, path(target + Vector(-7, 2), support + Vector(-6, 1), -8), 1, 0.55)
					draw_path(anim, path(target + Vector(7, -2), support + Vector(6, 1), 8), 1, 0.55)
					draw_path(anim, path(target + Vector(0, 8), support + Vector(0, 9), 3), 1, 0.6)
				end
			end
			local bubble = name == "wrap" and t or ((name == "summon" or name == "extend") and 0 or 1)
			local bubble_pos = name == "throw" and support or ((name == "poof" or name == "impact") and target or pos)
			if name == "retract" then
				bubble = 1 - t
				bubble_pos = path(source, target, -18)(1 - t)
			end
			if bubble > 0 then
				anim.knot.Scale = Vector(bubble, bubble)
				anim.knot.Color = Color(1, 1, 1, bubble)
				anim.knot:Render(bubble_pos + Vector(0, 3), Vector.Zero, Vector.Zero)
			end
			moving = pos
			if name ~= "poof" and name ~= "retract" then
				local base_scale = hud_scale()
				local scale = name == "throw" and (base_scale + (1 - base_scale) * t)
					or (name == "impact" and 1 or base_scale)
				local sx, sy = 1, 1
				if name == "windup" then sx, sy = 1 - 0.08 * t, 1 + 0.08 * t
				elseif name == "release" then sx, sy = 0.92 + 0.23 * t, 1.08 - 0.22 * t
				elseif name == "throw" then
					local stretch = math.max(0, 1 - t * 5)
					sx, sy = 1 + 0.15 * stretch, 1 - 0.14 * stretch
				elseif name == "impact" then sx, sy = 1.2 - 0.1 * t, 0.78 + 0.12 * t end
				local base_xy = Vector(scale * sx, scale * sy)
				anim.icon.Rotation = name == "throw" and (20 + 520 * (1 - (1 - t)^3))
					or (name == "release" and 20 * t or (name == "impact" and 540 or 0))
				local alpha = name == "summon" and simulated_alpha
					or (name == "extend" and (simulated_alpha + (1 - simulated_alpha) * t) or 1)
				anim.icon.Color = Color(1, 1, 1, alpha)
				apply_slot_tint(
					anim.icon, anim.player_index, anim.job.id, anim.job.time, anim.job.occurrence, alpha, base_xy
				)
				anim.icon:Render(pos, Vector.Zero, Vector.Zero)
			end
			local source_alpha = name == "summon" and (simulated_alpha + (1 - simulated_alpha) * t)
				or (name == "retract" and (1 - (1 - simulated_alpha) * t) or 1)
			if source_alpha > 0 and not anim.offscreen then
				local scale = hud_scale()
				anim.root_icon.Color = Color(1, 1, 1, source_alpha)
				apply_slot_tint(
					anim.root_icon, anim.player_index,
					anim.job.root_id, anim.job.root_time, anim.job.root_occurrence, source_alpha, scale
				)
				anim.root_icon:Render(sprite_origin(source, scale), Vector.Zero, Vector.Zero)
			end
		end
		if debug_anchors then
			local source = anim.source or anchor(anim, anim.job.root_id, anim.job.root_time, anim.job.root_occurrence)
			local target = anim.target or anchor(anim, anim.job.id, anim.job.time, anim.job.occurrence)
			draw_cross(source, KColor(0.2, 1, 0.3, 1), "R" .. tostring(anim.job.root_occurrence))
			draw_cross(target, KColor(1, 0.25, 0.2, 1), "T" .. tostring(anim.job.occurrence))
			draw_cross(moving, KColor(1, 0.85, 0.2, 1), "M")
			draw_cross(auxi.world_to_ui_screen(anim.landing, ui.GetHUDRenderOffset()), KColor(0.2, 0.8, 1, 1), "L")
		end
	end
end

function visual.set_debug_anchors(value) debug_anchors = value == true end
function visual.get_debug_anchors() return debug_anchors end
function visual.get_history_layout(player_index)
	local lay = history_hud.get_layout(player_index)
	if lay then
		visual.capture_history(nil, nil, false)
		local row = cache[player_index]
		if row then return row end
	end
	local row = cache[player_index]
	if row and Game():GetFrameCount() - row.frame <= 4 then return row end
end
function visual.clear_animations() jobs = {} end
function visual.has_gameplay_jobs()
	for _, anim in ipairs(jobs) do
		if anim.commit then return true end
	end
	return false
end
function visual.reset() jobs = {} cache = {} redraw_icons = {} tick = 0 hud_diagnostic = "HUD callback pending" end
function visual.status()
	local first = jobs[1]
	if first and not first.started then return #jobs, tick, "anchor_wait" end
	return #jobs, tick, first and stage(tick - first.start, first) or "idle"
end
function visual.diagnostics()
	local rows = {}
	for i, anim in ipairs(jobs) do
		local phase = anim.started and stage(tick - anim.start, anim) or "anchor_wait"
		local player_cache = cache[anim.player_index]
		local root_key = identity(anim.job.root_id, anim.job.root_time, anim.job.root_occurrence)
		local target_key = identity(anim.job.id, anim.job.time, anim.job.occurrence)
		rows[#rows + 1] = string.format("%d:%s %s R%s T%s player=%s cache=%s keys=%s/%s", i, phase,
			anim.offscreen and "offscreen" or "history",
			anim.source and "Y" or "N", anim.target and "Y" or "N",
			tostring(anim.player_index), player_cache and tostring(Game():GetFrameCount() - player_cache.frame) or "none",
			player_cache and (player_cache.positions[root_key] and "R" or "-") or "?",
			player_cache and (player_cache.positions[target_key] and "T" or "-") or "?")
	end
	return table.concat(rows, " | ") .. " / " .. hud_diagnostic
end

-- Exclusive only for HistoryHUD slots this animation will actually redraw.
history_hud.register_consumer(CONSUMER_NAME, {
	priority = 0,
	collect = function(context, declare)
		for _, anim in ipairs(jobs) do
			local name = stage(tick - anim.start, anim)
			if anim.started and anim.source and name ~= "wait" and name ~= "done" then
				local function claim(id, time, occurrence)
					local found = context.find_slots({
						kind = "collectible",
						player_index = anim.player_index,
						id = id,
						history_time = time,
						occurrence = occurrence,
					})
					for i = 1, #found do
						local slot = found[i]
						if slot.visible then
							declare.exclusive(slot)
						end
					end
				end
				-- Extracted target is always redrawn by the flying icon while active.
				claim(anim.job.id, anim.job.time, anim.job.occurrence)
				-- Root icon is only redrawn when on-HUD (not offscreen fallback).
				if not anim.offscreen then
					claim(anim.job.root_id, anim.job.root_time, anim.job.root_occurrence)
				end
			end
		end
	end,
})

return visual

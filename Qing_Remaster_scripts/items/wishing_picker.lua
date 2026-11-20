local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local selection = require("Qing_Remaster_scripts.others.selection_holder")
local mouse = require("Qing_Remaster_scripts.others.Mouse_UI_holder")

local picker = {sessions = {}, reading_input = false}
local OPEN_FRAMES, CHOOSE_FRAMES, REJECT_FRAMES, CANCEL_FRAMES = 8, 46, 48, 10
local ROWS = {
	[1] = {1}, [2] = {2}, [3] = {3}, [4] = {4}, [5] = {5},
	[6] = {2, 4}, [7] = {3, 4}, [8] = {3, 5}, [9] = {4, 5},
	[10] = {2, 3, 5}, [11] = {2, 4, 5}, [12] = {3, 4, 5},
	[13] = {4, 4, 5}, [14] = {4, 5, 5}, [15] = {5, 5, 5},
}

local function key(player)
	return player and player:GetData().__Index
end

local function rows_for(count)
	if ROWS[count] then return ROWS[count] end
	local rows = {}
	while count > 0 do
		local take = math.min(5, count)
		table.insert(rows, 1, take)
		count = count - take
	end
	return rows
end

local function positions(count)
	local rows, points = rows_for(count), {}
	local index = 1
	for row, size in ipairs(rows) do
		local spread = math.rad(({0, 0, 35, 52, 74, 88})[size + 1] or 88)
		local radius = 76 + 5 * (size - 3)
		local height = 32 + (#rows - row) * 34
		for column = 1, size do
			local theta = size == 1 and 0 or -spread / 2 + spread * (column - 1) / (size - 1)
			points[index] = {row = row, column = column, row_size = size,
				x = radius * math.sin(theta), y = -height + radius * (1 - math.cos(theta))}
			index = index + 1
		end
	end
	return points, 8
end

local function smooth(t)
	t = math.max(0, math.min(1, t))
	return 1 - (1 - t) ^ 3
end

local function clamp(t)
	return math.max(0, math.min(1, t))
end

local function ease_in(t)
	t = clamp(t)
	return t * t
end

local function ease_in_out(t)
	t = clamp(t)
	return (1 - math.cos(math.pi * t)) * 0.5
end

local function sprite_for(path)
	local sprite = Sprite()
	sprite:Load("gfx/ui/collectible_icon_centered.anm2", true)
	sprite:ReplaceSpritesheet(0, path)
	sprite:LoadGraphics()
	sprite:Play("Idle", true)
	return sprite
end

-- The shared Qing icon ANM2 has one 32x32 layer at (0,0), pivot (16,16).
function picker.render_icon_centered(sprite, center, scale, color)
	sprite.Scale = Vector(scale, scale)
	sprite.Color = color
	sprite:Render(center, Vector.Zero, Vector.Zero)
end

local function action(player, button)
	picker.reading_input = true
	local value = Input.IsActionTriggered(button, player.ControllerIndex or 0)
	picker.reading_input = false
	return value
end

local function pressed(player, button)
	picker.reading_input = true
	local value = Input.IsActionPressed(button, player.ControllerIndex or 0)
	picker.reading_input = false
	return value
end

local function close(session, outcome)
	if session.phase == "closing" then return end
	session.phase = "closing"
	session.outcome = outcome
	session.age = 0
	session.selected_index = session.cursor
	session.visible_page = session.points[session.cursor].page
	session.close_visuals = session.last_visuals or {}
	session.close_start = session.last_start
	selection.remove_select(session.player, "Item_Wishing_picker")
	if outcome == "cancel" then session.focus = "options" end
	if outcome ~= "cancel" and session.on_finish then
		session.on_finish(session, outcome == "choose" and session.cursor or nil)
	end
end

function picker.open(player, item_id, slot, options, on_finish)
	local id = key(player)
	if not id or picker.sessions[id] or #options == 0 then return false end
	local sprites = {}
	for _, collectible in ipairs(options) do
		local config = Isaac.GetItemConfig():GetCollectible(collectible)
		if config then sprites[collectible] = sprite_for(config.GfxFileName) end
	end
	local point, reject_y = {}, 8
	for page_start = 1, #options, 15 do
		local page_points = positions(math.min(15, #options - page_start + 1))
		for i, entry in ipairs(page_points) do
			entry.page = math.floor((page_start - 1) / 15) + 1
			point[page_start + i - 1] = entry
		end
	end
	local session = {player = player, item_id = item_id, slot = slot, options = options,
		sprites = sprites, points = point, reject_y = reject_y, cross = sprite_for("gfx/mimics/Wishing/wish_reject.png"),
		cursor = 1, focus = "options", focus_age = 0, phase = "opening", age = 0,
		armed = false, on_finish = on_finish}
	picker.sessions[id] = session
	selection.try_select(player, "Item_Wishing_picker")
	player:AnimateCollectible(item_id, "LiftItem", "PlayerPickup")
	return true
end

function picker.active(player)
	return picker.sessions[key(player)]
end

local function nearest_in_row(session, current, row)
	local best, distance
	for i, point in ipairs(session.points) do
		if point.page == current.page and point.row == row then
			local d = math.abs(point.x - current.x)
			if not distance or d < distance then best, distance = i, d end
		end
	end
	return best
end

local function move(session, direction)
	local point = session.points[session.cursor]
	if session.focus == "reject" then
		if direction == "up" then session.focus = "options" end
		return
	end
	if direction == "left" or direction == "right" then
		local step = direction == "left" and -1 or 1
		local next_index = session.cursor + step
		if session.points[next_index] and (session.points[next_index].row == point.row
			or session.points[next_index].page ~= point.page) then
			session.cursor = next_index
		end
	elseif direction == "up" then
		session.cursor = nearest_in_row(session, point, point.row - 1) or session.cursor
	elseif direction == "down" then
		local next_index = nearest_in_row(session, point, point.row + 1)
		if next_index then session.cursor = next_index else session.focus = "reject" end
	end
end

function picker.update(player)
	local id = key(player)
	local session = id and picker.sessions[id]
	if not session then return end
	if not auxi.check_for_the_same(session.player, player) then
		picker.sessions[id] = nil
		return
	end
	session.player = player
	session.age = session.age + 1
	session.focus_age = (session.focus_age or 0) + 1
	if session.phase == "opening" and session.age >= OPEN_FRAMES then session.phase = "idle" end
	if session.phase == "closing" then
		if session.outcome == "reject" and session.age >= 8 and not session.depart_start then
			session.depart_start = session.last_start or session.close_start
		end
		if session.outcome == "choose" and session.age >= 24 and not session.descend_start then
			session.descend_start = (session.last_start or session.close_start) and
				((session.last_start or session.close_start)
					+ Vector(0, -16 + math.sin(13 * 0.32) * 1.2)) or nil
		end
		if session.outcome == "choose" and session.age >= 37 and not session.happy_played then
			if player:IsHoldingItem() then player:AnimateCollectible(session.item_id, "HideItem", "PlayerPickup") end
			player:AnimateHappy()
			session.happy_played = true
		end
		local duration = session.outcome == "choose" and CHOOSE_FRAMES
			or session.outcome == "reject" and REJECT_FRAMES or CANCEL_FRAMES
		if session.age >= duration then
			if session.outcome ~= "choose" and player:IsHoldingItem() then
				player:AnimateCollectible(session.item_id, "HideItem", "PlayerPickup")
			end
			picker.sessions[id] = nil
		end
		return
	end
	if player:GetActiveItem(session.slot) ~= session.item_id then close(session, "cancel"); return end
	if Game():IsPaused() then return end
	if not selection.check_select(player, "Item_Wishing_picker") then return end
	if not session.armed then
		if not pressed(player, ButtonAction.ACTION_ITEM) and not pressed(player, ButtonAction.ACTION_DROP) then
			session.armed = true
		end
		return
	end
	if action(player, ButtonAction.ACTION_DROP) then close(session, "reject"); return end
	if session.age < OPEN_FRAMES then return end
	local direction
	if action(player, ButtonAction.ACTION_SHOOTLEFT) then direction = "left"
	elseif action(player, ButtonAction.ACTION_SHOOTRIGHT) then direction = "right"
	elseif action(player, ButtonAction.ACTION_SHOOTUP) then direction = "up"
	elseif action(player, ButtonAction.ACTION_SHOOTDOWN) then direction = "down" end
	if direction then
		local previous_cursor, previous_focus = session.cursor, session.focus
		move(session, direction)
		if session.cursor ~= previous_cursor or session.focus ~= previous_focus then session.focus_age = 0 end
	end
	if action(player, ButtonAction.ACTION_ITEM) or action(player, ButtonAction.ACTION_MENUCONFIRM) then
		close(session, session.focus == "reject" and "reject" or "choose")
	elseif mouse.was_released(0) then
		local hovered = mouse.get_hovered_id()
		if hovered == "wishing_reject" then close(session, "reject")
		elseif hovered and hovered:sub(1, 15) == "wishing_option_" then
			local index = tonumber(hovered:sub(16))
			if index and session.options[index] then session.cursor = index; close(session, "choose") end
		end
	end
end

function picker.suppress(player, hook, button)
	if picker.reading_input or not picker.active(player)
		or not selection.check_select(player, "Item_Wishing_picker") then return end
	if button == ButtonAction.ACTION_SHOOTLEFT or button == ButtonAction.ACTION_SHOOTRIGHT
		or button == ButtonAction.ACTION_SHOOTUP or button == ButtonAction.ACTION_SHOOTDOWN
		or button == ButtonAction.ACTION_ITEM or button == ButtonAction.ACTION_DROP then
		if hook == InputHook.GET_ACTION_VALUE then return 0 end
		if hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED then return false end
	end
end

function picker.render(player, offset)
	local session = picker.active(player)
	if not session then return end
	local screen = Isaac.WorldToRenderPosition(player.Position + (player.PositionOffset or Vector.Zero))
		+ (offset or Vector.Zero)
	local start = screen + Vector(0, -54)
	-- Keep the bouquet attached to the player's world position even near a screen edge.
	local opening = session.phase == "opening" and smooth(session.age / OPEN_FRAMES) or 1
	local visible_page = session.phase == "closing" and session.visible_page
		or session.points[session.cursor].page
	session.last_start = start
	if session.phase ~= "closing" then
		session.last_visuals = {}
	end
	if session.phase ~= "closing" then mouse.begin_frame(player) end
	for i, collectible in ipairs(session.options) do
		local point, sprite = session.points[i], session.sprites[collectible]
		if sprite and point.page == visible_page then
			local stagger = math.max(0, math.min(1, (session.age - (i - 1) % 3) / OPEN_FRAMES))
			local emerge = session.phase == "opening" and smooth(stagger) or opening
			local selected = session.focus == "options" and i == session.cursor
			local pos = start + Vector(point.x * emerge, point.y * emerge)
			if session.phase ~= "closing" then
				mouse.register("wishing_option_" .. i, mouse.make_rect_centered(pos, 30, 30), {z = 10})
			end
			if selected and session.phase ~= "closing" then pos = pos + Vector(0, math.sin(Game():GetFrameCount() * 0.13) * 1.5) end
			local focus_t = selected and smooth(math.min(1, (session.focus_age or 0) / 6)) or 0
			local scale = (0.6 + 0.4 * emerge) * (1 + 0.14 * focus_t)
			local alpha = (0.5 + 0.5 * focus_t) * emerge
			if session.phase == "closing" then
				local age = session.age
				local initial = session.close_visuals[i]
				local origin = initial and initial.position or pos
				local initial_scale = initial and initial.scale or scale
				local initial_alpha = initial and initial.alpha or alpha
				if session.outcome == "choose" and i == session.selected_index then
					local hover = start + Vector(0, -16)
					if age <= 10 then
						pos = origin + (hover - origin) * ease_in_out(age / 10)
						scale = initial_scale + (1.14 - initial_scale) * smooth(age / 10)
					elseif age <= 23 then
						pos = hover + Vector(0, math.sin((age - 10) * 0.32) * 1.2)
						scale = 1.14 + 0.025 * math.sin((age - 10) * 0.32)
					else
						local descent = ease_in((age - 23) / 14)
						local departure = session.descend_start or hover
						pos = departure + (screen + Vector(0, -8) - departure) * descent
						scale = 1.14 - 0.98 * smooth((age - 23) / 14)
					end
					alpha = age <= 23 and (initial_alpha + (1 - initial_alpha) * smooth(age / 10))
						or 1 - smooth((age - 32) / 5)
				elseif session.outcome == "choose" then
					pos = origin + Vector(0, -5 * smooth(age / 10))
					alpha = initial_alpha * (1 - smooth(age / 10))
					scale = initial_scale * (1 - 0.15 * smooth(age / 10))
				elseif session.outcome == "reject" then
					local rise = ease_in_out(age / 8)
					local depart = ease_in((age - 8) / 22)
					local dissolve = smooth((age - 30) / 18)
					local spread = (point.column - (point.row_size + 1) / 2)
						/ math.max(1, (point.row_size - 1) / 2)
					local anchored_start = age < 8 and start or (session.depart_start or start)
					origin = origin + anchored_start - (session.close_start or start)
					pos = origin + Vector(spread * (70 * depart + 20 * dissolve),
						-12 * rise - (94 + (point.row - 1) * 5) * depart - 28 * dissolve)
					scale = initial_scale * (1 - 0.2 * dissolve)
					alpha = (initial_alpha + (0.85 - initial_alpha) * smooth(age / 8)) * (1 - dissolve)
				else
					pos = origin
					alpha = initial_alpha * (1 - smooth(age / CANCEL_FRAMES))
				end
			else
				session.last_visuals[i] = {position = pos, scale = scale, alpha = alpha}
			end
			picker.render_icon_centered(sprite, pos, scale, Color(1, 1, 1, alpha))
		end
	end
	local cross = session.cross
	local reject_scale = session.focus == "reject" and 1.18 or 0.9
	local cross_scale = reject_scale * opening
	local cross_alpha = (session.focus == "reject" and 1 or 0.5) * opening
	if session.phase == "closing" then
		if session.outcome == "choose" then cross_alpha = 0.5 * (1 - smooth(session.age / 5))
		else
			cross_alpha = 1 - smooth(math.max(0, session.age - 10) / 12)
			cross_scale = cross_scale * (1 + 0.18 * math.sin(math.pi * clamp(session.age / 10)))
		end
	end
	picker.render_icon_centered(cross, start + Vector(0, session.reject_y - 6), cross_scale,
		Color(1, (session.focus == "reject" or session.outcome == "reject") and 0.3 or 1,
			(session.focus == "reject" or session.outcome == "reject") and 0.3 or 1,
			cross_alpha))
	if session.phase ~= "closing" then
		mouse.register("wishing_reject", mouse.make_rect_centered(start + Vector(0, session.reject_y - 6), 27, 27), {z = 10})
		mouse.end_frame()
		local hovered = mouse.get_hovered_id()
		if hovered == "wishing_reject" then
			if session.focus ~= "reject" then session.focus_age = 0 end
			session.focus = "reject"
		elseif hovered and hovered:sub(1, 15) == "wishing_option_" then
			local index = tonumber(hovered:sub(16))
			if index and session.options[index] then
				if session.cursor ~= index or session.focus ~= "options" then session.focus_age = 0 end
				session.cursor = index
				session.focus = "options"
			end
		end
	end
end

function picker.clear()
	for _, session in pairs(picker.sessions) do
		local player = session.player
		pcall(function()
			if player and player:Exists() then
				selection.remove_select(player, "Item_Wishing_picker")
				if player:IsHoldingItem() then player:AnimateCollectible(session.item_id, "HideItem", "PlayerPickup") end
			end
		end)
	end
	picker.sessions = {}
end

return picker

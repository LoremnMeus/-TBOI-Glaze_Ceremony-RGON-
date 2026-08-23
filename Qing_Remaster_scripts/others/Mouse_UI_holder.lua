-- ImGui-like screen UI: widgets register rects each frame; topmost wins hover/press/release.
local holder = {
	own_key = "Mouse_UI_holder_",
	_btn_frame = -1,
	_prev = {},
	_clicked = {},
	_released = {},
	_down = {},
	_ui_frame = -1,
	_begun = false,
	_resolved = false,
	_widgets = {},
	_order = 0,
	_by_id = {},
	_release_active_id = nil,
	_prev_mouse = nil,
	mouse = Vector(0, 0),
	mouse_delta = Vector(0, 0),
	_allow_mouse = false,
	hovered_id = nil,
	pressed_id = nil,
	released_id = nil, -- 本帧松开时，按下开始时所在的控件（可已移出）
	drop_target_id = nil, -- 本帧松开时鼠标下的控件（投放目标）
	active_id = nil,
	_active_button = nil,
	want_capture_mouse = false,
}

local function refresh_buttons()
	local frame = Game():GetFrameCount()
	if holder._btn_frame == frame then return end
	holder._btn_frame = frame
	holder._release_active_id = nil
	for btn = 0, 2 do
		local down = Input.IsMouseBtnPressed(btn) == true
		local prev = holder._prev[btn] == true
		holder._down[btn] = down
		holder._clicked[btn] = down and not prev
		holder._released[btn] = (not down) and prev
		holder._prev[btn] = down
		if holder._released[btn] and holder.active_id and holder._active_button == btn then
			holder._release_active_id = holder.active_id
		end
	end
	if not holder._down[0] and not holder._down[1] and not holder._down[2] then
		holder.active_id = nil
		holder._active_button = nil
	end
end

-- Render coordinates for Font/Sprite HUD (NOT window pixels).
function holder.get_screen_pos()
	return Isaac.WorldToScreen(Input.GetMousePosition(true)) - Game().ScreenShakeOffset
end

function holder.mouse_allowed(player)
	if not player then return false end
	return player.ControllerIndex == 0
end

function holder.point_in_rect(pos, rect)
	if not pos or not rect then return false end
	local x = rect.x or rect.X or 0
	local y = rect.y or rect.Y or 0
	local w = rect.w or rect.W or rect.width or 0
	local h = rect.h or rect.H or rect.height or 0
	return pos.X >= x and pos.X <= x + w and pos.Y >= y and pos.Y <= y + h
end

function holder.rect_center(rect)
	return Vector((rect.x or 0) + (rect.w or 0) * 0.5, (rect.y or 0) + (rect.h or 0) * 0.5)
end

function holder.make_rect(x, y, w, h)
	return {x = x, y = y, w = w, h = h}
end

function holder.make_rect_centered(center, w, h)
	return holder.make_rect(center.X - w * 0.5, center.Y - h * 0.5, w, h)
end

function holder.is_down(button)
	refresh_buttons()
	return holder._down[button or 0] == true
end

function holder.was_clicked(button)
	refresh_buttons()
	return holder._clicked[button or 0] == true
end

function holder.was_released(button)
	refresh_buttons()
	return holder._released[button or 0] == true
end

function holder.begin_frame(player)
	refresh_buttons()
	local frame = Game():GetFrameCount()
	holder._ui_frame = frame
	holder._begun = true
	holder._resolved = false
	holder._widgets = {}
	holder._order = 0
	holder._by_id = {}
	local mouse = holder.get_screen_pos()
	if holder._prev_mouse then
		holder.mouse_delta = mouse - holder._prev_mouse
	else
		holder.mouse_delta = Vector(0, 0)
	end
	holder._prev_mouse = Vector(mouse.X, mouse.Y)
	holder.mouse = mouse
	holder._allow_mouse = holder.mouse_allowed(player)
	holder.hovered_id = nil
	holder.pressed_id = nil
	holder.released_id = nil
	holder.drop_target_id = nil
	holder.want_capture_mouse = false
end

function holder.register(id, rect, opts)
	if not holder._begun then
		error("Mouse_UI.register called before begin_frame")
	end
	opts = opts or {}
	holder._order = holder._order + 1
	local widget = {
		id = id,
		rect = rect,
		z = opts.z or holder._order,
		block = opts.block ~= false,
		enabled = opts.enabled ~= false,
		capture = opts.capture,
		button = opts.button or 0,
		order = holder._order,
		draggable = opts.draggable == true,
		drop_target = opts.drop_target == true,
	}
	if widget.capture == nil then
		widget.capture = widget.block
	end
	table.insert(holder._widgets, widget)
	holder._by_id[id] = widget
	return widget
end

local function sort_widgets()
	table.sort(holder._widgets, function(a, b)
		if a.z == b.z then
			return a.order < b.order
		end
		return a.z < b.z
	end)
end

function holder.end_frame()
	if not holder._begun then return end
	holder._begun = false
	holder._resolved = true
	sort_widgets()

	holder.hovered_id = nil
	holder.pressed_id = nil
	holder.released_id = holder._release_active_id
	holder._release_active_id = nil
	holder.drop_target_id = nil
	holder.want_capture_mouse = false

	if not holder._allow_mouse then
		return
	end

	local hit = nil
	for i = #holder._widgets, 1, -1 do
		local w = holder._widgets[i]
		if holder.point_in_rect(holder.mouse, w.rect) then
			if w.capture then
				holder.want_capture_mouse = true
			end
			if w.enabled then
				hit = w
				break
			elseif w.block then
				hit = nil
				break
			end
		end
	end

	if hit then
		holder.hovered_id = hit.id
		local btn = hit.button or 0
		if holder._clicked[btn] then
			holder.pressed_id = hit.id
			holder.active_id = hit.id
			holder._active_button = btn
			-- on_render 可能同逻辑帧跑多次；边沿只给第一次 end_frame
			holder._clicked[btn] = false
		end
	end

	if holder.released_id then
		holder.drop_target_id = holder.hovered_id
	end
end

function holder.is_hovered(id)
	return holder._resolved and holder.hovered_id == id
end

function holder.is_pressed(id)
	return holder._resolved and holder.pressed_id == id
end

function holder.is_released(id)
	return holder._resolved and holder.released_id == id
end

function holder.is_active(id)
	return holder.active_id == id and holder.is_down(holder._active_button or 0)
end

function holder.get_state(id)
	return {
		hovered = holder.is_hovered(id),
		pressed = holder.is_pressed(id),
		released = holder.is_released(id),
		active = holder.is_active(id),
		id = id,
	}
end

function holder.get_widget(id)
	return holder._by_id[id]
end

function holder.get_hovered_id()
	return holder.hovered_id
end

return holder

-- Shared RGON ImGui layout / nav helpers for Debug modules.
-- Pure UI helper; required by rgon_imgui_options_holder. No gameplay.
-- Glyphs: only layout.ICON (verified) or plain ASCII/language text.

local dev_env = require("Qing_Remaster_scripts.core.dev_environment")

local layout = {}

-- Official RGON ImGuiMenu example uses flask + bullhorn.
-- star (f005) also cited as official-example-safe; keep verified after gallery OK.
layout.ICON_VERIFIED = {
	flask = "\u{f0c3}",
	bullhorn = "\u{f0a1}",
	star = "\u{f005}",
}

-- Candidates: show in Icon Gallery; do NOT use in production UI until promoted.
layout.ICON_CANDIDATE = {
	lock = "\u{f023}",
	refresh = "\u{f021}",
	search = "\u{f002}",
	pin = "\u{f08d}",
	unlock = "\u{f09c}",
	help = "\u{f059}",
	trash = "\u{f1f8}",
	wrench = "\u{f0ad}",
}

-- Runtime alias: verified only. Pin stays text until thumbtack is promoted.
layout.ICON = {}
for k, v in pairs(layout.ICON_VERIFIED) do
	layout.ICON[k] = v
end

local ctx = {
	debug_window_width = 800,
}

local access = {
	restricted_unlocked = nil,
	push_notice = nil,
	error_notice_type = nil,
	focus_debug_module = nil,
	is_pinned = nil,
	toggle_pin = nil,
	path_label = nil,
	page_tab_label = nil,
	pin_label = nil,
	unpin_label = nil,
	get_value = nil,
	set_value = nil,
}

function layout.set_context(opts)
	opts = opts or {}
	for k, v in pairs(opts) do
		ctx[k] = v
	end
end

function layout.get_context()
	return ctx
end

function layout.bind_access(opts)
	opts = opts or {}
	for k, v in pairs(opts) do
		access[k] = v
	end
end

function layout.icon(name)
	return layout.ICON[name]
end

function layout.can_use(level)
	if level == nil or level == "safe" or level == "advanced" then
		return true
	end
	if level == "restricted" then
		if access.restricted_unlocked then
			return access.restricted_unlocked() == true
		end
		return dev_env.probes_allowed() == true
	end
	return true
end

function layout.guard_restricted(fn)
	return function(...)
		if not layout.can_use("restricted") then
			if access.push_notice then
				local typ = access.error_notice_type and access.error_notice_type() or nil
				access.push_notice("Restricted: unlock developer / debug access first.", typ)
			end
			return
		end
		return fn(...)
	end
end

-- ---------------------------------------------------------------------------
-- RGON ImGui text-format compatibility (REPENTOGON 1.1.3+)
-- Ordinary Text / TextWrapped / BulletText / AddText / UpdateText are literal
-- (TextUnformatted / "%s" wrappers). Do NOT escape '%' -> '%%' for display.
-- Tooltip still uses printf-style SetTooltip — use escape_printf_text only there.
-- Do NOT escape DragFloat/Slider format args (`%.2f`) or Button labels.
-- ---------------------------------------------------------------------------

--- Only for confirmed printf-format RGON APIs (currently: SetTooltip).
local function escape_printf_text(value)
	local text = tostring(value == nil and "" or value)
	return (text:gsub("%%", "%%%%"))
end

function layout.escape_printf_text(value)
	return escape_printf_text(value)
end

function layout.update_text(element_id, value)
	if not element_id then return end
	ImGui.UpdateText(element_id, tostring(value == nil and "" or value))
end

--- Button / Checkbox labels are not printf-format APIs — do not escape.
function layout.update_button_label(element_id, value)
	if not element_id then return end
	ImGui.UpdateText(element_id, tostring(value == nil and "" or value))
end

function layout.add_plain_text(parent_id, element_id, value)
	ImGui.AddElement(
		parent_id,
		element_id or "",
		ImGuiElement.Text,
		tostring(value == nil and "" or value)
	)
end

function layout.add_wrapped_text(parent_id, element_id, value)
	ImGui.AddElement(
		parent_id,
		element_id or "",
		ImGuiElement.TextWrapped,
		tostring(value == nil and "" or value)
	)
end

function layout.add_bullet_text(parent_id, element_id, value)
	ImGui.AddElement(
		parent_id,
		element_id or "",
		ImGuiElement.BulletText,
		tostring(value == nil and "" or value)
	)
end

function layout.add_imgui_text(parent_id, value, wrap_text, element_id)
	ImGui.AddText(
		parent_id,
		tostring(value == nil and "" or value),
		wrap_text == true,
		element_id or ""
	)
end

function layout.add_display_text(parent_id, element_id, value, opts)
	opts = opts or {}
	if opts.bullet == true then
		layout.add_bullet_text(parent_id, element_id, value)
	elseif opts.wrapped == false then
		layout.add_plain_text(parent_id, element_id, value)
	else
		layout.add_wrapped_text(parent_id, element_id, value)
	end
end

--- HelpMarker: RGON 1.1.3 uses TextUnformatted — literal-safe.
function layout.set_helpmarker(element_id, help)
	if not element_id or not help or not ImGui.SetHelpmarker then return end
	ImGui.SetHelpmarker(element_id, tostring(help))
end

--- Tooltip: current RGON still calls ImGui::SetTooltip (printf-style).
function layout.set_tooltip(element_id, help)
	if not element_id or not help or not ImGui.SetTooltip then return end
	ImGui.SetTooltip(element_id, escape_printf_text(help))
end

-- ---------------------------------------------------------------------------
-- Control Spec / Home mirror (same path, different element ID namespace)
-- ---------------------------------------------------------------------------

local control_touch = nil

function layout.bind_control_touch(fn)
	control_touch = fn
end

function layout.control_element_id(surface, module_id, key)
	surface = tostring(surface or "main")
	module_id = tostring(module_id or "mod")
	key = tostring(key or "ctrl")
	return string.format("QingRemasterOptions_%s_%s_%s", surface, module_id, key)
end

local function path_get(path)
	if type(path) ~= "table" then return nil end
	-- caller supplies get via access; default uses options holder binding
	if access.get_value then
		return access.get_value(path)
	end
	return nil
end

local function path_set(path, value)
	if type(path) ~= "table" then return end
	if access.set_value then
		access.set_value(path, value)
	end
end

--- Render one control spec onto a surface.
--- control: {key, kind, label, path, speed, min, max, fmt, help, home?, get?, set?, on_edit?}
function layout.render_control(parent_id, module_id, control, opts)
	opts = opts or {}
	if not parent_id or not control or not control.key then return nil end
	local surface = opts.surface or "main"
	if surface == "home" and control.home == false then
		return nil
	end
	local id = layout.control_element_id(surface, module_id, control.key)
	local kind = control.kind or "drag_float"
	local label = control.label or control.key
	local path = control.path

	local function notify_edit()
		if control_touch then
			control_touch(module_id, control.key, label)
		end
		if control.on_edit then
			control.on_edit()
		end
		if opts.on_edit then
			opts.on_edit(module_id, control.key)
		end
	end

	local function read_num()
		if control.get then
			return tonumber(control.get()) or tonumber(control.default) or 0
		end
		return tonumber(path_get(path)) or tonumber(control.default) or 0
	end

	local function write_num(value)
		local n = tonumber(value) or 0
		if control.set then
			control.set(n)
		else
			path_set(path, n)
		end
		notify_edit()
	end

	if kind == "checkbox" then
		local function read_bool()
			if control.get then return control.get() == true end
			return path_get(path) == true
		end
		local function write_bool(value)
			local b = value == true
			if control.set then control.set(b) else path_set(path, b) end
			notify_edit()
		end
		ImGui.AddCheckbox(parent_id, id, label, nil, read_bool())
		ImGui.AddCallback(id, ImGuiCallback.Render, function()
			ImGui.UpdateData(id, ImGuiData.Value, read_bool())
		end)
		ImGui.AddCallback(id, ImGuiCallback.Edited, function(value)
			write_bool(value)
		end)
	elseif kind == "drag_int" or kind == "slider_int" then
		local speed = tonumber(control.speed) or 1
		local min_v = tonumber(control.min) or 0
		local max_v = tonumber(control.max) or 100
		local fmt = control.fmt or "%d"
		if kind == "slider_int" and ImGui.AddSliderInt then
			ImGui.AddSliderInt(parent_id, id, label, write_num, read_num(), min_v, max_v, fmt)
		else
			ImGui.AddDragInt(parent_id, id, label, write_num, read_num(), speed, min_v, max_v, fmt)
		end
		ImGui.AddCallback(id, ImGuiCallback.Render, function()
			ImGui.UpdateData(id, ImGuiData.Value, read_num())
		end)
		ImGui.AddCallback(id, ImGuiCallback.Edited, write_num)
	else
		-- drag_float / slider_float default
		local speed = tonumber(control.speed) or 0.25
		local min_v = tonumber(control.min) or -16
		local max_v = tonumber(control.max) or 16
		local fmt = control.fmt or "%.2f"
		if kind == "slider_float" and ImGui.AddSliderFloat then
			ImGui.AddSliderFloat(parent_id, id, label, write_num, read_num(), min_v, max_v, fmt)
		else
			ImGui.AddDragFloat(parent_id, id, label, write_num, read_num(), speed, min_v, max_v, fmt)
		end
		ImGui.AddCallback(id, ImGuiCallback.Render, function()
			ImGui.UpdateData(id, ImGuiData.Value, read_num())
		end)
		ImGui.AddCallback(id, ImGuiCallback.Edited, write_num)
	end

	if control.help then
		layout.set_helpmarker(id, control.help)
	end
	return id
end

--- controls: array; home_keys optional filter for home surface
function layout.render_control_spec(parent_id, module_id, controls, surface, opts)
	opts = opts or {}
	opts.surface = surface or opts.surface or "main"
	local home_keys = opts.home_keys
	local key_set = nil
	if type(home_keys) == "table" then
		key_set = {}
		for _, k in ipairs(home_keys) do key_set[k] = true end
	end
	for _, control in ipairs(controls or {}) do
		if opts.surface == "home" then
			if control.home == false then
				-- skip
			elseif key_set and not key_set[control.key] then
				-- skip
			else
				layout.render_control(parent_id, module_id, control, opts)
			end
		else
			layout.render_control(parent_id, module_id, control, opts)
		end
	end
end

local function same_line(parent_id)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
end

function layout.add_separator_text(parent_id, element_id, label)
	ImGui.AddElement(parent_id, element_id or "", ImGuiElement.SeparatorText, label or "")
end

function layout.add_section(parent_id, element_id, label)
	ImGui.AddElement(parent_id, element_id, ImGuiElement.CollapsingHeader, label)
	return element_id
end

function layout.add_tree(parent_id, element_id, label)
	ImGui.AddElement(parent_id, element_id, ImGuiElement.TreeNode, label)
	return element_id
end

--- buttons: { {id=, label=, on_click=, small?=, help?=}, ... }
function layout.add_action_row(parent_id, buttons, opts)
	opts = opts or {}
	local small = opts.small == true
	for i, btn in ipairs(buttons or {}) do
		if i > 1 then same_line(parent_id) end
		local use_small = btn.small
		if use_small == nil then use_small = small end
		ImGui.AddButton(parent_id, btn.id, btn.label or "", btn.on_click, use_small == true)
		if btn.help then
			layout.set_helpmarker(btn.id, btn.help)
		end
	end
end

function layout.add_small_action_row(parent_id, buttons)
	layout.add_action_row(parent_id, buttons, {small = true})
end

--- flags: { {id=, label=, get=, set=, help?=}, ... } — up to 3 per row
function layout.add_checkbox_row(parent_id, flags)
	local row = {}
	local function flush()
		if #row == 0 then return end
		for i, f in ipairs(row) do
			if i > 1 then same_line(parent_id) end
			ImGui.AddCheckbox(parent_id, f.id, f.label, nil, false)
			ImGui.AddCallback(f.id, ImGuiCallback.Render, function()
				ImGui.UpdateData(f.id, ImGuiData.Value, f.get and f.get() == true)
			end)
			ImGui.AddCallback(f.id, ImGuiCallback.Edited, function(value)
				if f.set then f.set(value == true) end
			end)
			if f.help then
				layout.set_helpmarker(f.id, f.help)
			end
		end
		row = {}
	end
	for _, f in ipairs(flags or {}) do
		row[#row + 1] = f
		if #row >= 3 then flush() end
	end
	flush()
end

--- Logical pair of drag floats (one control per row).
--- RGON ImGui.SetSize does not resize Drag/Slider item width; do not SameLine them.
--- Each: {id, label, on_edit, get, default, speed, min, max, fmt, help}
function layout.add_drag_pair(parent_id, left, right, opts)
	opts = opts or {}

	local function add_one(spec)
		if not spec then return end
		ImGui.AddDragFloat(
			parent_id, spec.id, spec.label,
			spec.on_edit,
			tonumber(spec.default) or 0,
			tonumber(spec.speed) or 0.1,
			tonumber(spec.min) or 0,
			tonumber(spec.max) or 1,
			spec.fmt or "%.2f"
		)
		if spec.get then
			ImGui.AddCallback(spec.id, ImGuiCallback.Render, function()
				ImGui.UpdateData(spec.id, ImGuiData.Value, tonumber(spec.get()) or tonumber(spec.default) or 0)
			end)
		end
		if spec.help then
			layout.set_helpmarker(spec.id, spec.help)
		end
	end

	add_one(left)
	add_one(right)
end

--- Narrow primary utilities only (Refresh). Not for Pin. Not default.
function layout.add_inline_utilities(parent_id, opts)
	opts = opts or {}
	local stem = opts.id_stem or (parent_id .. "_Util")
	local buttons = {}
	if opts.refresh then
		buttons[#buttons + 1] = {
			id = stem .. "_Refresh",
			label = opts.refresh_label or "Refresh",
			on_click = opts.refresh,
			small = false,
		}
	end
	if #buttons > 0 then
		layout.add_action_row(parent_id, buttons)
	end
end

--- Deprecated as default top bar. Prefer add_module_footer + add_inline_utilities.
function layout.add_module_toolbar(parent_id, module_id, opts)
	opts = opts or {}
	-- Pin no longer belongs here.
	layout.add_inline_utilities(parent_id, opts)
	if opts.restore then
		layout.add_action_row(parent_id, {
			{
				id = (opts.id_stem or parent_id) .. "_Restore",
				label = opts.restore_label or "Restore",
				on_click = opts.restore,
				small = false,
			},
		})
	end
end

--- Module footer: Restore (optional) + Pin/Unpin as normal text buttons.
function layout.add_module_footer(parent_id, module_id, opts)
	opts = opts or {}
	if not parent_id or not module_id then return end
	local stem = opts.id_stem or (parent_id .. "_Footer")
	layout.add_separator_text(parent_id, stem .. "_Sep", "")
	local first = true
	if opts.restore then
		ImGui.AddButton(parent_id, stem .. "_Restore", opts.restore_label or "Restore Defaults", opts.restore, false)
		first = false
	end
	if access.toggle_pin then
		if not first then same_line(parent_id) end
		local pin_id = stem .. "_Pin"
		local pin_text = function()
			local pinned = access.is_pinned and access.is_pinned(module_id)
			if pinned then
				return (access.unpin_label and access.unpin_label()) or "Unpin this module"
			end
			return (access.pin_label and access.pin_label()) or "Pin this module"
		end
		ImGui.AddButton(parent_id, pin_id, pin_text(), function()
			access.toggle_pin(module_id)
		end, false)
		ImGui.AddCallback(pin_id, ImGuiCallback.Render, function()
			layout.update_button_label(pin_id, pin_text())
		end)
	end
end

--- Nav button: Normal size by default. opts.small only for verified icon-only utilities.
function layout.add_nav_button(parent_id, element_id, label, module_id, opts)
	opts = opts or {}
	local small = opts.small == true
	ImGui.AddButton(parent_id, element_id, label or module_id or "?", function()
		if access.focus_debug_module and module_id then
			access.focus_debug_module(module_id)
		end
	end, small)
end

function layout.add_module_link(parent_id, element_id, module_id, label, opts)
	layout.add_nav_button(parent_id, element_id, label or "Go to Data", module_id, opts)
end

--- Adjacent Pin small utility next to a nav button. Text "Pin"/"Unpin" until FA pin verified.
function layout.add_adjacent_pin(parent_id, element_id, module_id)
	if not access.toggle_pin or not module_id then return end
	same_line(parent_id)
	local label_fn = function()
		local pinned = access.is_pinned and access.is_pinned(module_id)
		return pinned and "Unpin" or "Pin"
	end
	ImGui.AddButton(parent_id, element_id, label_fn(), function()
		access.toggle_pin(module_id)
	end, true)
	ImGui.AddCallback(element_id, ImGuiCallback.Render, function()
		layout.update_button_label(element_id, label_fn())
	end)
end

function layout.add_location_notice(parent_id, element_id, get_text)
	layout.add_wrapped_text(parent_id, element_id, "")
	ImGui.AddCallback(element_id, ImGuiCallback.Render, function()
		local body = ""
		if type(get_text) == "function" then
			body = get_text() or ""
		elseif type(get_text) == "string" then
			body = get_text
		end
		layout.update_text(element_id, body)
	end)
	return element_id
end

--- Normal-button grid. Default 2 columns. items = { {id=, label=, module_id=, pin?=}, ... }
function layout.add_nav_grid(parent_id, items, opts)
	opts = opts or {}
	local per_row = tonumber(opts.per_row) or 2
	local with_pin = opts.with_pin == true
	local col = 0
	for _, it in ipairs(items or {}) do
		if col > 0 then same_line(parent_id) end
		layout.add_nav_button(parent_id, it.id, it.label, it.module_id, {small = false})
		if with_pin and it.module_id then
			layout.add_adjacent_pin(parent_id, it.id .. "_PinAdj", it.module_id)
		end
		col = col + 1
		if col >= per_row then col = 0 end
	end
end

function layout.path_text(path)
	if type(path) ~= "table" or #path == 0 then return "" end
	return table.concat(path, " / ")
end

--- Dev-only Icon Gallery: verified + candidates with codepoint labels.
function layout.add_icon_gallery(parent_id)
	local group = parent_id .. "_IconGallery"
	ImGui.AddElement(parent_id, group, ImGuiElement.CollapsingHeader, "ImGui Icon Gallery")
	layout.add_wrapped_text(group, "", "Verified glyphs may be used via layout.ICON. Candidates must pass in-game before promotion. No emoji.")
	layout.add_separator_text(group, group .. "_VerSep", "ICON_VERIFIED")
	local verified_names = {}
	for name in pairs(layout.ICON_VERIFIED) do
		verified_names[#verified_names + 1] = name
	end
	table.sort(verified_names)
	for _, name in ipairs(verified_names) do
		local glyph = layout.ICON_VERIFIED[name]
		layout.add_plain_text(group, "", string.format("%s  [%s]  %s", name, glyph, name))
	end
	layout.add_separator_text(group, group .. "_CandSep", "ICON_CANDIDATE")
	local cand_names = {}
	for name in pairs(layout.ICON_CANDIDATE) do
		cand_names[#cand_names + 1] = name
	end
	table.sort(cand_names)
	for _, name in ipairs(cand_names) do
		local glyph = layout.ICON_CANDIDATE[name]
		layout.add_plain_text(group, "", string.format("%s  [%s]  %s (candidate)", name, glyph, name))
	end
	return group
end

return layout

-- Shared helpers for probe UI / event buffering.
-- Keep ImGui Render callbacks cheap: never rebuild large strings every frame.
local M = {}

local text_cache = {}
local checkbox_cache = {}
local throttle_at = {}

local function game_frame()
	local ok, n = pcall(function()
		return Game():GetFrameCount()
	end)
	return ok and n or -1
end

--- Call fn at most once per `interval_frames` game frames for `key`.
function M.throttle(key, interval_frames, fn)
	interval_frames = tonumber(interval_frames) or 6
	if interval_frames < 1 then
		interval_frames = 1
	end
	local gf = game_frame()
	local last = throttle_at[key]
	if last and gf >= 0 and (gf - last) < interval_frames then
		return false
	end
	throttle_at[key] = gf
	if fn then
		fn()
	end
	return true
end

--- ImGui text: UpdateData / UpdateText only when the string actually changes.
function M.update_text_if_changed(element_id, text, update_fn)
	if not element_id then
		return false
	end
	text = tostring(text == nil and "" or text)
	if text_cache[element_id] == text then
		return false
	end
	text_cache[element_id] = text
	if update_fn then
		update_fn(element_id, text)
	else
		local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
		imgui_layout.update_text(element_id, text)
	end
	return true
end

--- ImGui checkbox Value: UpdateData only when the bool changes.
function M.update_checkbox_if_changed(element_id, enabled)
	if not element_id then
		return false
	end
	local value = enabled == true
	if checkbox_cache[element_id] == value then
		return false
	end
	checkbox_cache[element_id] = value
	ImGui.UpdateData(element_id, ImGuiData.Value, value)
	return true
end

--- Drop-on-full append (probes are not telemetry servers).
--- Returns true if appended, false if dropped.
function M.append_drop_on_full(events, row, max_events, drop_counter_tbl, drop_key)
	max_events = tonumber(max_events) or 256
	if #events >= max_events then
		if drop_counter_tbl and drop_key then
			drop_counter_tbl[drop_key] = (drop_counter_tbl[drop_key] or 0) + 1
		end
		return false
	end
	events[#events + 1] = row
	return true
end

--- Coerce probe get_output_status() table/string into one stable status line block.
function M.coerce_status_text(body)
	if body == nil then
		return ""
	end
	if type(body) == "string" then
		return body
	end
	if type(body) ~= "table" then
		return tostring(body)
	end
	local parts = {}
	if body.events ~= nil then
		parts[#parts + 1] = "events=" .. tostring(body.events)
	end
	if body.callback_hits ~= nil then
		parts[#parts + 1] = "cb=" .. tostring(body.callback_hits)
	end
	if body.target_hits ~= nil then
		parts[#parts + 1] = "tgt=" .. tostring(body.target_hits)
	end
	if body.render_hits ~= nil then
		parts[#parts + 1] = "rend=" .. tostring(body.render_hits)
	end
	if body.texture_changes ~= nil then
		parts[#parts + 1] = "tex=" .. tostring(body.texture_changes)
	end
	if body.lightweight_samples ~= nil then
		parts[#parts + 1] = "light=" .. tostring(body.lightweight_samples)
	end
	if body.geometry_recomputes ~= nil then
		parts[#parts + 1] = "geom=" .. tostring(body.geometry_recomputes)
	end
	if body.deep_captures ~= nil then
		parts[#parts + 1] = "deep=" .. tostring(body.deep_captures)
	end
	if body.alpha_scans ~= nil then
		parts[#parts + 1] = "alpha=" .. tostring(body.alpha_scans)
	end
	if body.export_timeline_count ~= nil then
		parts[#parts + 1] = "export_tl=" .. tostring(body.export_timeline_count)
	end
	if body.export_event_count ~= nil then
		parts[#parts + 1] = "export_ev=" .. tostring(body.export_event_count)
	end
	if body.ring_count ~= nil then
		parts[#parts + 1] = "ring=" .. tostring(body.ring_count)
	end
	if body.heavy_count ~= nil then
		parts[#parts + 1] = "heavy=" .. tostring(body.heavy_count)
	end
	if body.presence_count ~= nil then
		parts[#parts + 1] = "presence=" .. tostring(body.presence_count)
	end
	if body.dropped_events ~= nil then
		parts[#parts + 1] = "dropped=" .. tostring(body.dropped_events)
	end
	if body.last_export_path then
		parts[#parts + 1] = "export=" .. tostring(body.last_export_path)
	end
	if body.note then
		parts[#parts + 1] = "note=" .. tostring(body.note)
	end
	if #parts == 0 then
		-- Fall back to key=value dump for unknown shapes.
		for k, v in pairs(body) do
			if type(v) ~= "table" then
				parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
			end
		end
	end
	return table.concat(parts, "\n")
end

--- Probe-side summary cache: rebuild at most every interval_frames when dirty.
function M.make_summary_cache(build_fn, interval_frames)
	interval_frames = tonumber(interval_frames) or 6
	local state = {
		cache = "idle",
		dirty = true,
		last_frame = -1,
	}
	return {
		mark_dirty = function()
			state.dirty = true
		end,
		get = function()
			local gf = game_frame()
			if state.dirty
				and (state.last_frame < 0 or gf < 0 or (gf - state.last_frame) >= interval_frames)
			then
				state.cache = build_fn() or ""
				state.dirty = false
				state.last_frame = gf
			end
			return state.cache
		end,
		force = function()
			state.cache = build_fn() or ""
			state.dirty = false
			state.last_frame = game_frame()
			return state.cache
		end,
		set = function(text)
			state.cache = tostring(text or "")
			state.dirty = false
			state.last_frame = game_frame()
		end,
	}
end

function M.clear_ui_caches()
	text_cache = {}
	checkbox_cache = {}
	throttle_at = {}
end

return M

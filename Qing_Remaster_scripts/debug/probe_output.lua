-- Shared probe clipboard / JSON / export plumbing.
-- Probes own their events & diagnosis; this module only moves bytes to clipboard or disk.
local probe_output = {}

local json = require("json")

local REL_LOG_DIR = "codex_work/logs"
local MOD_FOLDER_NAME = "Qing_remaster"

probe_output._last_clipboard = {
	ok = false,
	kind = nil,
	bytes = 0,
	error = nil,
	at_frame = nil,
}

probe_output._last_export = {
	ok = false,
	path = nil,
	error = nil,
	tried = {},
	bytes = 0,
	at_frame = nil,
}

local cached_mod_root = nil
local cached_mod_root_source = nil

local function game_frame()
	local ok, n = pcall(function()
		return Game():GetFrameCount()
	end)
	if ok then return n end
	return nil
end

local function normalize_slashes(path)
	if type(path) ~= "string" then return path end
	return (path:gsub("\\", "/"))
end

local function dirname(path)
	path = normalize_slashes(path)
	local d = path:match("^(.*)/[^/]+$")
	return d
end

--- Resolve mod root from this module's load path (most reliable under Isaac CWD churn).
function probe_output.resolve_mod_root()
	if cached_mod_root then
		return cached_mod_root, cached_mod_root_source
	end
	local info = debug.getinfo(1, "S")
	local src = info and info.source
	if type(src) == "string" and src:sub(1, 1) == "@" then
		local file = normalize_slashes(src:sub(2))
		local root = file:match("^(.-)/Qing_Remaster_scripts/")
		if root and root ~= "" then
			cached_mod_root = root
			cached_mod_root_source = "debug.getinfo"
			return cached_mod_root, cached_mod_root_source
		end
	end
	cached_mod_root = nil
	cached_mod_root_source = "unresolved"
	return nil, cached_mod_root_source
end

function probe_output.candidate_log_paths(file_stem, extension)
	extension = extension or "jsonl"
	file_stem = tostring(file_stem or "probe")
	local name = file_stem .. "." .. extension
	local paths = {}
	local seen = {}
	local function add(p)
		p = normalize_slashes(p)
		if type(p) ~= "string" or p == "" or seen[p] then return end
		seen[p] = true
		paths[#paths + 1] = p
	end

	local root = probe_output.resolve_mod_root()
	if root then
		add(root .. "/" .. REL_LOG_DIR .. "/" .. name)
	end
	-- CWD-relative fallbacks (documented; each attempt is logged on failure)
	add("mods/" .. MOD_FOLDER_NAME .. "/" .. REL_LOG_DIR .. "/" .. name)
	add("../mods/" .. MOD_FOLDER_NAME .. "/" .. REL_LOG_DIR .. "/" .. name)
	add("./" .. REL_LOG_DIR .. "/" .. name)
	add("../" .. REL_LOG_DIR .. "/" .. name)
	return paths
end

function probe_output.encode_json(value)
	local ok, encoded = pcall(json.encode, value)
	if not ok then
		return nil, "json.encode failed: " .. tostring(encoded)
	end
	return encoded, nil
end

--- header table + events array → JSONL text (header line then one event per line).
function probe_output.encode_jsonl(header, events)
	local lines = {}
	local enc, err = probe_output.encode_json(header or {})
	if not enc then return nil, err end
	lines[#lines + 1] = enc
	if type(events) == "table" then
		for i = 1, #events do
			local row = events[i]
			local line, e2 = probe_output.encode_json(row)
			if not line then
				return nil, "json.encode event[" .. tostring(i) .. "] failed: " .. tostring(e2)
			end
			lines[#lines + 1] = line
		end
	end
	return table.concat(lines, "\n") .. "\n", nil
end

function probe_output.copy_text(text, kind)
	kind = kind or "text"
	probe_output._last_clipboard = {
		ok = false,
		kind = kind,
		bytes = 0,
		error = nil,
		at_frame = game_frame(),
	}
	if text == nil then
		probe_output._last_clipboard.error = "nil text"
		return false, probe_output._last_clipboard.error
	end
	if type(text) ~= "string" then
		probe_output._last_clipboard.error = "text must be string"
		return false, probe_output._last_clipboard.error
	end
	local nbytes = #text
	probe_output._last_clipboard.bytes = nbytes

	local copied = false
	local last_err = nil

	if Isaac and Isaac.SetClipboard then
		local ok, ret_or_err = pcall(function()
			return Isaac.SetClipboard(text)
		end)
		if ok then
			-- RGON may return boolean; treat nil as success if no error thrown
			if ret_or_err == false then
				last_err = "Isaac.SetClipboard returned false (possibly oversized)"
			else
				copied = true
			end
		else
			last_err = "Isaac.SetClipboard error: " .. tostring(ret_or_err)
		end
	end

	if not copied and ImGui and ImGui.SetClipboardText then
		local ok, err = pcall(function()
			ImGui.SetClipboardText(text)
		end)
		if ok then
			copied = true
		else
			last_err = "ImGui.SetClipboardText error: " .. tostring(err)
		end
	end

	if not copied then
		if not last_err then
			last_err = "no clipboard API (Isaac.SetClipboard / ImGui.SetClipboardText)"
		end
		probe_output._last_clipboard.error = last_err
		return false, last_err
	end

	probe_output._last_clipboard.ok = true
	probe_output._last_clipboard.error = nil
	return true, nil
end

function probe_output.copy_summary(summary)
	local text, err
	if type(summary) == "string" then
		text = summary
	else
		text, err = probe_output.encode_json(summary)
		if not text then
			probe_output._last_clipboard = {
				ok = false,
				kind = "summary",
				bytes = 0,
				error = err,
				at_frame = game_frame(),
			}
			return false, err
		end
	end
	return probe_output.copy_text(text, "summary")
end

function probe_output.copy_json(value)
	local text, err = probe_output.encode_json(value)
	if not text then
		probe_output._last_clipboard = {
			ok = false,
			kind = "json",
			bytes = 0,
			error = err,
			at_frame = game_frame(),
		}
		return false, err
	end
	return probe_output.copy_text(text, "json")
end

function probe_output.copy_jsonl(header, events)
	local text, err = probe_output.encode_jsonl(header, events)
	if not text then
		probe_output._last_clipboard = {
			ok = false,
			kind = "jsonl",
			bytes = 0,
			error = err,
			at_frame = game_frame(),
		}
		return false, err
	end
	return probe_output.copy_text(text, "full_report")
end

local function try_write_atomic(path, text)
	local tmp = path .. ".tmp"
	local f, open_err = io.open(tmp, "w")
	if not f then
		return false, "open tmp failed: " .. tostring(open_err)
	end
	local ok_write, write_err = pcall(function()
		f:write(text)
		f:close()
	end)
	if not ok_write then
		pcall(function() f:close() end)
		pcall(os.remove, tmp)
		return false, "write failed: " .. tostring(write_err)
	end
	local ok_rename = os.rename(tmp, path)
	if not ok_rename then
		pcall(os.remove, path)
		ok_rename = os.rename(tmp, path)
	end
	if not ok_rename then
		pcall(os.remove, tmp)
		return false, "rename failed"
	end
	return true, nil
end

--- Write text to codex_work/logs/<stem>.<ext>. Records every tried path + reason.
--- Returns: ok, path_or_error, detail_table
function probe_output.export_text(file_stem, extension, text)
	local tried = {}
	probe_output._last_export = {
		ok = false,
		path = nil,
		error = nil,
		tried = tried,
		bytes = type(text) == "string" and #text or 0,
		at_frame = game_frame(),
		mod_root = select(1, probe_output.resolve_mod_root()),
		mod_root_source = select(2, probe_output.resolve_mod_root()),
	}
	if type(text) ~= "string" then
		local err = "export text must be string"
		probe_output._last_export.error = err
		return false, err, probe_output._last_export
	end

	local paths = probe_output.candidate_log_paths(file_stem, extension)
	for _, path in ipairs(paths) do
		local ok, err = try_write_atomic(path, text)
		tried[#tried + 1] = { path = path, ok = ok, error = err }
		if ok then
			probe_output._last_export.ok = true
			probe_output._last_export.path = path
			probe_output._last_export.error = nil
			return true, path, probe_output._last_export
		end
	end

	local parts = {}
	for _, row in ipairs(tried) do
		parts[#parts + 1] = tostring(row.path) .. " => " .. tostring(row.error)
	end
	local err = "export failed; tried:\n" .. table.concat(parts, "\n")
	probe_output._last_export.error = err
	return false, err, probe_output._last_export
end

function probe_output.get_clipboard_status()
	local c = probe_output._last_clipboard
	if not c or c.kind == nil then
		return "Clipboard: (none yet)"
	end
	if c.ok then
		return string.format("Clipboard: OK kind=%s bytes=%d", tostring(c.kind), tonumber(c.bytes) or 0)
	end
	return string.format("Clipboard: FAILED kind=%s err=%s", tostring(c.kind), tostring(c.error))
end

function probe_output.get_export_status()
	local e = probe_output._last_export
	if not e or (e.path == nil and e.error == nil and #(e.tried or {}) == 0) then
		return "Export: (none yet)"
	end
	if e.ok then
		return string.format("Export: OK path=%s bytes=%d", tostring(e.path), tonumber(e.bytes) or 0)
	end
	local lines = { "Export: FAILED" }
	if e.mod_root then
		lines[#lines + 1] = "  mod_root=" .. tostring(e.mod_root) .. " (" .. tostring(e.mod_root_source) .. ")"
	else
		lines[#lines + 1] = "  mod_root=unresolved"
	end
	for _, row in ipairs(e.tried or {}) do
		lines[#lines + 1] = "  tried: " .. tostring(row.path) .. " => " .. tostring(row.error)
	end
	if e.error and #(e.tried or {}) == 0 then
		lines[#lines + 1] = "  error: " .. tostring(e.error)
	end
	return table.concat(lines, "\n")
end

function probe_output.format_output_status(extra_lines)
	local lines = {
		probe_output.get_clipboard_status(),
		probe_output.get_export_status(),
	}
	if type(extra_lines) == "table" then
		for _, s in ipairs(extra_lines) do
			lines[#lines + 1] = tostring(s)
		end
	elseif type(extra_lines) == "string" and extra_lines ~= "" then
		lines[#lines + 1] = extra_lines
	end
	return table.concat(lines, "\n")
end

--- Attach Copy Summary / Copy Full Report / Export / Clear + status text to an ImGui group.
--- probe must expose: copy_summary, copy_full_report, export (or export_jsonl), clear, get_output_status (optional).
function probe_output.add_probe_output_controls(group_id, probe_getter, opts)
	opts = opts or {}
	local prefix = opts.id_prefix or (group_id .. "_Out")
	local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")

	local function get_probe()
		if type(probe_getter) == "function" then
			return probe_getter()
		end
		return probe_getter
	end

	local function notice(msg, is_err)
		-- soft: ImGui UpdateData status is enough; optional print
		if is_err then
			print("[probe_output] " .. tostring(msg))
		end
	end

	ImGui.AddButton(group_id, prefix .. "_CopySummary", opts.summary_label or "Copy Summary", function()
		local probe = get_probe()
		if not probe or not probe.copy_summary then
			notice("Copy Summary unavailable", true)
			return
		end
		local ok, err = probe.copy_summary()
		if not ok then
			notice("Copy failed: " .. tostring(err), true)
		end
	end)

	ImGui.AddButton(group_id, prefix .. "_CopyFull", opts.full_label or "Copy Full Report", function()
		local probe = get_probe()
		if not probe or not probe.copy_full_report then
			notice("Copy Full Report unavailable", true)
			return
		end
		local ok, err = probe.copy_full_report()
		if not ok then
			notice("Copy failed: " .. tostring(err), true)
		end
	end)

	ImGui.AddButton(group_id, prefix .. "_Export", opts.export_label or "Export JSONL", function()
		local probe = get_probe()
		if not probe then
			notice("Export unavailable", true)
			return
		end
		local fn = probe.export or probe.export_jsonl
		if not fn then
			notice("Export unavailable", true)
			return
		end
		local ok, path_or_err = fn()
		if not ok then
			notice("Export failed: " .. tostring(path_or_err), true)
		end
	end)

	ImGui.AddButton(group_id, prefix .. "_Clear", opts.clear_label or "Clear", function()
		local probe = get_probe()
		if probe and probe.clear then
			probe.clear()
		end
	end)

	local status_id = prefix .. "_IOStatus"
	imgui_layout.add_wrapped_text(group_id, status_id, "Clipboard/Export: (none yet)")
	local live = require("Qing_Remaster_scripts.debug.probe_live_cache")
	ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
		local probe = get_probe()
		local body
		if probe and probe.get_output_status then
			body = live.coerce_status_text(probe.get_output_status())
		else
			body = probe_output.format_output_status()
		end
		-- Also append shared clipboard/export lines when probe status is sparse.
		if probe and probe.get_output_status then
			body = probe_output.format_output_status(body)
		end
		live.update_text_if_changed(status_id, body or "")
	end)
end

return probe_output

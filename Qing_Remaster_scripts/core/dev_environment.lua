-- 开发树 vs 正式 Release 包。正式包由 builder 写入 release_channel.lua。
-- 探针默认只在开发树工作；正式包即使用 ImGui 打开开关也不会采样或写盘。
local env = {}

local public_release = false
do
	local ok, channel = pcall(require, "Qing_Remaster_scripts.core.release_channel")
	if ok and type(channel) == "table" and channel.public == true then
		public_release = true
	end
end

function env.is_public_release()
	return public_release
end

function env.probes_allowed()
	return public_release ~= true
end

env.last_probe_error = env.last_probe_error or {}

function env.require_probe(module_path)
	if public_release then return nil end
	local registry = require("Qing_Remaster_scripts.debug.probe_registry")
	if not registry.is_runtime_active(module_path) then
		env.last_probe_error[module_path] = "runtime inactive / not registered"
		return nil
	end
	local ok, mod = pcall(require, module_path)
	if ok then
		env.last_probe_error[module_path] = nil
		return mod
	end
	local err = tostring(mod)
	env.last_probe_error[module_path] = err
	-- Dev tree: surface the first real require error (do not wait for ImGui "module not found").
	print("[Probe preload failed] " .. tostring(module_path) .. "\n" .. err)
	return nil
end

function env.get_probe_error(module_path)
	if not module_path then
		return nil
	end
	return env.last_probe_error and env.last_probe_error[module_path] or nil
end

function env.format_probe_unavailable(module_path, fallback)
	local err = env.get_probe_error(module_path)
	if err and err ~= "" then
		return "探针加载失败：\n" .. tostring(module_path) .. "\n" .. tostring(err)
	end
	return fallback or "开发探针不可用。"
end

function env.disabled_probe_stub()
	return {
		ToCall = {},
		pre_ToCall = {},
		post_ToCall = {},
		myToCall = {},
		set_enabled = function() end,
		set_overlay = function() end,
		set_recording = function() end,
		set_capture = function() end,
		set_focus_id = function() end,
		set_flag = function() end,
		disable_all = function() end,
		get_config = function() return {enabled = false, overlay = false, recording = false} end,
		get_summary = function() return "public release: probes disabled" end,
		get_summary_payload = function() return {disabled = true} end,
		get_full_payload = function() return {header = {disabled = true}, events = {}} end,
		copy_summary = function() return false, "public release: probes disabled" end,
		copy_full_report = function() return false, "public release: probes disabled" end,
		export_jsonl = function() return false, "public release: probes disabled" end,
		export_summary = function() end,
		export_and_disable = function() end,
		export = function() return false, "public release: probes disabled" end,
		get_output_status = function() return "public release: probes disabled" end,
		clear = function() end,
	}
end

return env

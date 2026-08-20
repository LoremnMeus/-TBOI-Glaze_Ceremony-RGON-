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

function env.require_probe(module_path)
	if public_release then return nil end
	local ok, mod = pcall(require, module_path)
	if ok then return mod end
	return nil
end

function env.disabled_probe_stub()
	return {
		ToCall = {},
		pre_ToCall = {},
		post_ToCall = {},
		myToCall = {},
		set_enabled = function() end,
		get_config = function() return {enabled = false} end,
		get_summary = function() return "public release: probes disabled" end,
		export_jsonl = function() end,
		clear = function() end,
	}
end

return env

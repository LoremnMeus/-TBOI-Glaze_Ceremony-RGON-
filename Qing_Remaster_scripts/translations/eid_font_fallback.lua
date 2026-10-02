local fallback = {}

-- EID's bundled Chinese fonts do not cover the same glyph set.  Keep this
-- table limited to characters used by Qing Remaster that are absent from the
-- corresponding font; eid_cn_old currently covers all of them.
local missing_by_font = {
	cn_alt = {
		["萦"] = true,
		["鲛"] = true,
	},
	cn_default = {
		["佬"] = true, ["冕"] = true, ["囤"] = true, ["帧"] = true,
		["忒"] = true, ["楔"] = true, ["泯"] = true, ["漩"] = true,
		["萦"] = true, ["谶"] = true, ["遐"] = true, ["邃"] = true,
		["锚"] = true, ["锥"] = true, ["镰"] = true, ["阈"] = true,
		["靶"] = true, ["鲛"] = true,
	},
}

local function font_key_from_path(path)
	local normalized = tostring(path or ""):lower():gsub("\\", "/")
	return normalized:match("/eid_([^/]+)%.fnt$")
		or normalized:match("^eid_([^/]+)%.fnt$")
end

local function contains_missing_character(text, missing)
	if type(text) ~= "string" or not missing then
		return false
	end
	for character in pairs(missing) do
		if text:find(character, 1, true) then
			return true
		end
	end
	return false
end

function fallback.install(eid)
	if not eid or not eid.font then
		return false, "EID font is unavailable"
	end
	if eid.QingFontFallbackInstalled then
		return true
	end

	local primary_font = eid.font
	local old_font = Font()
	old_font:Load(tostring(eid.modPath or "") .. "resources/font/eid_cn_old.fnt", "")
	old_font:SetMissingCharacter(2)
	if not old_font:IsLoaded() then
		return false, "eid_cn_old.fnt could not be loaded"
	end

	local current_font_key = eid.Config and eid.Config.FontType or nil
	local proxy = {}

	local function select_font(text)
		if contains_missing_character(text, missing_by_font[current_font_key]) then
			return old_font
		end
		return primary_font
	end

	function proxy:Load(path, extra)
		current_font_key = font_key_from_path(path)
		return primary_font:Load(path, extra or "")
	end

	function proxy:SetMissingCharacter(character_id)
		return primary_font:SetMissingCharacter(character_id)
	end

	function proxy:IsLoaded()
		return primary_font:IsLoaded()
	end

	function proxy:GetStringWidthUTF8(text)
		return select_font(text):GetStringWidthUTF8(text)
	end

	function proxy:DrawStringScaledUTF8(text, ...)
		return select_font(text):DrawStringScaledUTF8(text, ...)
	end

	setmetatable(proxy, {
		__index = function(_, key)
			local value = primary_font[key]
			if type(value) == "function" then
				return function(_, ...)
					return value(primary_font, ...)
				end
			end
			return value
		end,
	})

	eid.font = proxy
	eid.QingFontFallbackInstalled = true
	eid.QingFontFallbackPrimary = primary_font
	eid.QingFontFallbackFont = old_font
	return true
end

return fallback

-- Public packages get core/release_channel.lua from build_release.py.
-- Development trees have no such file: story chapters stay unrestricted.
-- Version strings are not parsed here; the builder writes content_scope.

local env = require("Qing_Remaster_scripts.core.dev_environment")

local scope = {}

local CHAPTER_RANK = {
	prologue = 1,
	chapter1 = 2,
}

local cached_channel = nil
local channel_loaded = false

local function load_channel()
	if channel_loaded then
		return cached_channel
	end
	channel_loaded = true
	local ok, channel = pcall(require, "Qing_Remaster_scripts.core.release_channel")
	if ok and type(channel) == "table" then
		cached_channel = channel
	else
		cached_channel = nil
	end
	return cached_channel
end

local function story_test_bypasses()
	local ok, session = pcall(require, "Qing_Remaster_scripts.story_test.story_test_session")
	if ok and session and session.is_active and session.is_active() == true then
		return true
	end
	return false
end

function scope.is_public()
	if env.is_public_release then
		return env.is_public_release() == true
	end
	local channel = load_channel()
	return channel ~= nil and channel.public == true
end

function scope.get_story_max_chapter()
	local channel = load_channel()
	if not channel then
		return nil
	end
	local content = channel.content_scope
	if type(content) ~= "table" then
		return nil
	end
	local max_ch = content.story_max_chapter
	if type(max_ch) ~= "string" or max_ch == "" then
		return nil
	end
	return max_ch
end

function scope.allows_story_chapter(chapter_id)
	if type(chapter_id) ~= "string" or chapter_id == "" then
		return false
	end
	if story_test_bypasses() then
		return true
	end
	local max_ch = scope.get_story_max_chapter()
	if max_ch == nil then
		return true
	end
	local want = CHAPTER_RANK[chapter_id]
	local cap = CHAPTER_RANK[max_ch]
	if not want or not cap then
		return false
	end
	return want <= cap
end

return scope

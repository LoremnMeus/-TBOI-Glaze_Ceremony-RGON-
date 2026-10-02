-- Prologue Home optional encounter: Story gates + complete/skip bridges.
-- Bedroom bed presentation apply lives in thread_End1; this owns Story truth + room sync.

local enums = require("Qing_Remaster_scripts.core.enums")
local story = require("Qing_Remaster_scripts.story.story_state")

local home = {
	ToCall = {},
	myToCall = {},
	own_key = "Prologue_HomeEncounter_",
	BEDROOM_SAFE_GRID = 84,
	_seen_bedroom = false,
	_pending_bed_sync = false,
}

local function is_eligible_player()
	if Isaac.GetChallenge() > 0 then return false end
	local game = Game()
	if game:GetVictoryLap() > 0 then return false end
	local player = Isaac.GetPlayer(0)
	if not player then return false end
	return player:GetPlayerType() == enums.Players.wq
end

function home.is_story_active()
	if not is_eligible_player() then return false end
	if story.get_current_node("prologue") ~= "prologue.home_encounter" then
		return false
	end
	local ch = story.get_chapter("prologue", false)
	return ch ~= nil and ch.status == story.STATUS.ACTIVE
end

function home.should_replace_bed()
	if not home.is_story_active() then return false end
	local level = Game():GetLevel()
	if not level or level:GetStage() ~= LevelStage.STAGE8 then return false end
	local desc = level:GetCurrentRoomDesc()
	if not desc or desc.SafeGridIndex ~= home.BEDROOM_SAFE_GRID then return false end
	return true
end

function home.is_in_bedroom()
	local level = Game():GetLevel()
	if not level or level:GetStage() ~= LevelStage.STAGE8 then return false end
	local desc = level:GetCurrentRoomDesc()
	return desc ~= nil and desc.SafeGridIndex == home.BEDROOM_SAFE_GRID
end

--- Presentation: ask thread_End1 to apply sleeping Isaac to one bed (idempotent).
function home.apply_sleeping_bed(ent)
	if not home.should_replace_bed() then return false end
	local ok, end1 = pcall(require, "Qing_Remaster_scripts.threads.thread_End1")
	if not ok or not end1 or not end1.apply_sleeping_isaac_to_bed then
		return false
	end
	return end1.apply_sleeping_isaac_to_bed(ent) == true
end

--- One-shot room reconciliation after Story becomes home_encounter (or enter bedroom).
function home.request_bed_sync()
	home._pending_bed_sync = true
	return true
end

--- Scan current room beds once. Clears pending even if gate fails (avoid sticky retry spam).
function home.sync_bedroom_once()
	home._pending_bed_sync = false
	if not home.should_replace_bed() then
		return false
	end
	local applied = 0
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BED, -1, false, false)) do
		if home.apply_sleeping_bed(ent) then
			applied = applied + 1
		end
	end
	return applied > 0
end

function home.on_dialog_completed()
	local save = require("Qing_Remaster_scripts.core.savedata")
	if type(save.elses) == "table" then
		save.elses.has_speak_1 = true
	end
	return story.on_prologue_home_encounter_completed()
end

--- Ensure Story is past optional home before Beast finale (skip if still on home_encounter).
function home.ensure_past_optional()
	if story.get_current_node("prologue") ~= "prologue.home_encounter" then
		return true
	end
	return story.on_prologue_home_encounter_skipped()
end

--- Leaving the bedroom after visiting it = skip optional encounter.
--- Players who never visit the bedroom are advanced at Beast handoff via ensure_past_optional.
function home.try_skip_on_leave()
	if not home.is_story_active() then return false end
	if home.is_in_bedroom() then
		home._seen_bedroom = true
		home.request_bed_sync()
		return false
	end
	if not home._seen_bedroom then return false end
	local save = require("Qing_Remaster_scripts.core.savedata")
	if type(save.elses) == "table" and save.elses.has_speak_1 == true then
		return false
	end
	return story.on_prologue_home_encounter_skipped()
end

table.insert(home.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		home.try_skip_on_leave()
		if home.is_story_active() and home.is_in_bedroom() then
			home.request_bed_sync()
		end
	end,
})

table.insert(home.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		if not home._pending_bed_sync then return end
		home.sync_bedroom_once()
	end,
})

table.insert(home.ToCall, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		home._seen_bedroom = false
		home._pending_bed_sync = false
	end,
})

return home

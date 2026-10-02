-- Public story scene entry points.
-- transitions = may mutate Story. previews = presentation only (never Story).

local story = require("Qing_Remaster_scripts.story.story_state")

local scenes = {
	wired = {},
	transitions = {},
	previews = {},
	_preview_active = nil,
}

--- State-only transitions (no dialogue). Used by Apply Transition in Test Lab.
scenes.transitions = {
	["prologue.hunt.opening"] = function()
		local ok, ctrl = pcall(require, "Qing_Remaster_scripts.story.prologue.controller")
		if ok and ctrl and ctrl.debug_start_prologue then
			return ctrl.debug_start_prologue({reset_story = true, play_opening = true})
		end
		return story.start_prologue_hunt({play_opening = true})
	end,
	["prologue.home_arrival"] = function()
		local ok, ctrl = pcall(require, "Qing_Remaster_scripts.story.prologue.controller")
		if ok and ctrl and ctrl.debug_home_arrival then
			return ctrl.debug_home_arrival()
		end
		return story.on_prologue_home_arrived()
	end,
	["prologue.home.complete"] = function()
		return story.on_prologue_home_encounter_completed()
	end,
	["prologue.home.skip"] = function()
		return story.on_prologue_home_encounter_skipped()
	end,
	["prologue.beast.defeated"] = function()
		return story.on_prologue_beast_defeated()
	end,
	["prologue.ending.complete"] = function()
		return story.on_prologue_ending_complete()
	end,
	["chapter1.commission"] = function()
		local ch = story.get_chapter("chapter1", true)
		if ch and ch.status == story.STATUS.LOCKED then
			ch.status = story.STATUS.AVAILABLE
		end
		if not story.get_flag("chapter1", "commission_accepted") then
			if not ch or ch.current_node ~= "chapter1.commission" then
				story.begin_chapter1_commission()
			end
		end
		return story.accept_chapter1_commission()
	end,
	["chapter1.alchemy_setup"] = function()
		return story.on_alchemy_setup_complete()
	end,
	["chapter1.post_qing"] = function()
		return story.on_post_qing_complete()
	end,
	["chapter1.revelation"] = function()
		return story.on_revelation()
	end,
	["chapter1.glaze_confrontation"] = function()
		return story.on_glaze_confrontation_complete()
	end,
	["chapter1.enter_realms"] = function()
		return story.on_enter_realms()
	end,
}

scenes.previews["prologue.opening"] = function()
	local ok, transition = pcall(require, "Qing_Remaster_scripts.story.chapter_transition")
	if not ok or not transition then
		return false, "chapter_transition_missing"
	end
	if transition.debug_play_title then
		return transition.debug_play_title({chapter_id = "prologue", after_delay = 0})
	end
	return false, "debug_play_title_missing"
end

scenes.previews["chapter1.opening"] = function()
	local ok, transition = pcall(require, "Qing_Remaster_scripts.story.chapter_transition")
	if not ok or not transition then
		return false, "chapter_transition_missing"
	end
	if transition.debug_play_title then
		return transition.debug_play_title({chapter_id = "chapter1", after_delay = 0})
	end
	return false, "debug_play_title_missing"
end

scenes.previews["prologue.ending"] = function(opts)
	local ok, ending_scene = pcall(require, "Qing_Remaster_scripts.story.prologue.ending_scene")
	if not ok or not ending_scene or not ending_scene.preview then
		return false, "ending_scene_missing"
	end
	return ending_scene.preview(opts)
end

do
	local ok, edefs = pcall(require, "Qing_Remaster_scripts.story.prologue.ending_defs")
	if ok and edefs and type(edefs.PHASE_ORDER) == "table" then
		for _, phase_id in ipairs(edefs.PHASE_ORDER) do
			local preview_id = "prologue.ending." .. phase_id
			scenes.previews[preview_id] = function()
				local eok, ending_scene = pcall(require, "Qing_Remaster_scripts.story.prologue.ending_scene")
				if not eok or not ending_scene or not ending_scene.preview then
					return false, "ending_scene_missing"
				end
				return ending_scene.preview({phase = phase_id})
			end
		end
	end
	if ok and edefs and type(edefs.ART_FRAME_COUNT) == "number" then
		for i = 0, edefs.ART_FRAME_COUNT - 1 do
			local preview_id = "prologue.ending.art." .. tostring(i)
			local art_index = i
			scenes.previews[preview_id] = function()
				local eok, ending_scene = pcall(require, "Qing_Remaster_scripts.story.prologue.ending_scene")
				if not eok or not ending_scene or not ending_scene.preview then
					return false, "ending_scene_missing"
				end
				return ending_scene.preview({art_frame = art_index})
			end
		end
	end
end

function scenes.is_available(id)
	return scenes.wired[id] == true or scenes.previews[id] ~= nil
end

function scenes.is_preview_available(id)
	return type(scenes.previews[id]) == "function"
end

function scenes.play(id)
	if scenes.previews[id] then
		return scenes.play_preview(id)
	end
	if not scenes.is_available(id) then
		return false, "scene not wired: " .. tostring(id)
	end
	local handler = scenes.wired[id]
	if type(handler) == "function" then
		local ok, err = pcall(handler)
		if not ok then return false, tostring(err) end
		return true, "played"
	end
	return false, "invalid handler"
end

function scenes.play_preview(id, opts)
	local fn = scenes.previews[id]
	if type(fn) ~= "function" then
		return false, "no preview: " .. tostring(id)
	end
	local ok, err = pcall(fn, opts)
	if not ok then return false, tostring(err) end
	scenes._preview_active = id
	return true, "preview"
end

function scenes.stop_preview()
	local ok, ending_scene = pcall(require, "Qing_Remaster_scripts.story.prologue.ending_scene")
	if ok and ending_scene and ending_scene.stop_preview then
		ending_scene.stop_preview()
	end
	scenes._preview_active = nil
	return true
end

function scenes.apply_transition(id)
	local fn = scenes.transitions[id]
	if type(fn) ~= "function" then
		return false, "no state transition: " .. tostring(id)
	end
	local ok, err = pcall(fn)
	if not ok then return false, tostring(err) end
	-- Chapter title owns Quest toast timing; caller must not notify mid-reveal.
	local tok, transition = pcall(require, "Qing_Remaster_scripts.story.chapter_transition")
	if tok and transition and transition.is_active and transition.is_active() then
		return true, "transition applied (quest toast deferred)"
	end
	return true, "transition applied (no scene)"
end

function scenes.stop()
	scenes.stop_preview()
	return true
end

function scenes.inspect()
	local wired = {}
	for id, _ in pairs(scenes.wired) do
		wired[#wired + 1] = id
	end
	local previews = {}
	for id, _ in pairs(scenes.previews) do
		previews[#previews + 1] = id
	end
	return {
		wired = wired,
		previews = previews,
		active = scenes._preview_active,
	}
end

return scenes

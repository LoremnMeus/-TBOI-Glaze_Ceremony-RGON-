-- 根植之魔 V1：每个实例在首次进入新房间时，挖出其历史区间内的上一件可用道具。
local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local pedestal_restore = require("Qing_Remaster_scripts.auxiliary.pedestal_restore")
local visual = require("Qing_Remaster_scripts.items.rooted_demon.visual")
local growth = require("Qing_Remaster_scripts.items.rooted_demon.growth")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Rooted_Demon,
	own_key = "Item_Rooted_Demon_",
}
local runtime_room_key
growth.item_id = item.entity

local function growth_states()
	local key = item.own_key .. "growth_states"
	if type(save.elses[key]) ~= "table" then save.elses[key] = {} end
	return save.elses[key]
end

local function processed_rooms()
	local key = item.own_key .. "processed_rooms"
	if type(save.elses[key]) ~= "table" then save.elses[key] = {} end
	return save.elses[key]
end

local function pending_rooms()
	local key = item.own_key .. "pending_rooms"
	if type(save.elses[key]) ~= "table" then save.elses[key] = {} end
	return save.elses[key]
end

local function room_key()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	if not desc then return nil end
	local dimension = auxi.GetDimension()
	return table.concat({level:GetStage(), level:GetStageType(), dimension, desc.SafeGridIndex}, ":")
end

local function eligible(player, id)
	if not id or id <= 0 or player:GetCollectibleNum(id, true) <= 0 then return false end
	local config = Isaac.GetItemConfig():GetCollectible(id)
	if not config or config.Hidden then return false end
	if config.Type ~= ItemType.ITEM_PASSIVE and config.Type ~= ItemType.ITEM_FAMILIAR then return false end
	local quest = ItemConfig.TAG_QUEST or (1 << 15)
	if config:HasTags(quest) then return false end
	return true
end

local function root_key(time, occurrence)
	return tostring(time) .. ":" .. tostring(occurrence)
end

local function player_growth(player)
	local index = player:GetData().__Index
	if index == nil then return nil end
	local states = growth_states()
	local key = tostring(index)
	if type(states[key]) ~= "table" then states[key] = {} end
	return states[key]
end

local function growth_members(history, states)
	local members, occurrences = {}, {}
	for i, entry in ipairs(history) do
		if not entry:IsTrinket() and entry:GetItemID() == item.entity then
			local time = entry:GetTime()
			occurrences[time] = (occurrences[time] or 0) + 1
			local key = root_key(time, occurrences[time])
			if states[key] then
				members[#members + 1] = {key = key, state = states[key], history_index = i}
			end
		end
	end
	return members
end

local function growing_roots(player)
	local excluded = {}
	for key in pairs(player_growth(player) or {}) do excluded[key] = true end
	return excluded
end

local function build_dig_jobs(player, history, completed_roots)
    -- Copy the native history before any removal changes its indices. Trinkets keep their slots.
    local snapshot = {}
    for i, entry in ipairs(history) do
        snapshot[i] = {id = entry:GetItemID(), trinket = entry:IsTrinket(), time = entry:GetTime()}
    end
    local jobs = {}
    local claimed = {}
    for root_index, root in ipairs(snapshot) do
        if not root.trinket and root.id == item.entity then
            local root_occurrence = 0
            for j = 1, root_index do
                if not snapshot[j].trinket and snapshot[j].id == item.entity
                    and snapshot[j].time == root.time then root_occurrence = root_occurrence + 1 end
            end
            if not (completed_roots and completed_roots[root_key(root.time, root_occurrence)]) then
                for i = root_index - 1, 1, -1 do
                    local previous = snapshot[i]
                    if not previous.trinket then
                        if previous.id ~= item.entity and not claimed[i]
                            and eligible(player, previous.id) then
                            local occurrence = 0
                            for j = 1, i do
                                if not snapshot[j].trinket and snapshot[j].id == previous.id
                                    and snapshot[j].time == previous.time then
                                    occurrence = occurrence + 1
                                end
                            end
                            jobs[#jobs + 1] = {
                                id = previous.id, history_index = i - 1,
                                time = previous.time, occurrence = occurrence,
                                root_time = root.time, root_occurrence = root_occurrence,
                                root_id = item.entity,
                                visual_ordinal = #jobs + 1,
                            }
                            claimed[i] = true
                            break
                        end
                    end
                end
            end
        end
    end
    table.sort(jobs, function(a, b) return a.history_index > b.history_index end)
    return jobs
end

local function resolve_history_index(player, job)
	local history = player:GetHistory():GetCollectiblesHistory()
	local occurrence = 0
	for i, entry in ipairs(history) do
		if not entry:IsTrinket() and entry:GetItemID() == job.id
			and entry:GetTime() == job.time then
			occurrence = occurrence + 1
			if occurrence == job.occurrence then return i - 1 end
		end
	end
end

local function commit_job(player, job, landing)
	local index = resolve_history_index(player, job)
	if not index then return false end
	local before = player:GetCollectibleNum(job.id, true)
	if before <= 0 then return false end
	local pedestal = pedestal_restore.spawn_owned_collectible(item.own_key, {
		collectible_id = job.id, touched = false, charge = 0,
	}, landing, player)
	if not pedestal then return false end
	if pedestal.SubType ~= job.id then pedestal:Remove() return false end
	player:RemoveCollectibleByHistoryIndex(index)
	if player:GetCollectibleNum(job.id, true) ~= before - 1 then
		pedestal:Remove()
		return false
	end
	job.completed = true
	return true
end

local function mark_room_processed(rooms, key)
    rooms[key] = true
end

local function refresh_pending_jobs(player, row)
	-- A pending room owns root attempts, not the item snapshot: another room may have dug that item.
	local history = player:GetHistory():GetCollectiblesHistory()
	if type(history) ~= "table" then return false end
	local completed_roots = growing_roots(player)
	for _, job in ipairs(row.jobs) do
		if job.completed then
			completed_roots[root_key(job.root_time, job.root_occurrence)] = true
		end
	end
	local available = {}
	for _, job in ipairs(build_dig_jobs(player, history, completed_roots)) do
		available[root_key(job.root_time, job.root_occurrence)] = job
	end
	for i, job in ipairs(row.jobs) do
		if not job.completed and not job.retired then
			if completed_roots[root_key(job.root_time, job.root_occurrence)] then
				job.retired = true
			else
				local replacement = available[root_key(job.root_time, job.root_occurrence)]
				if replacement then row.jobs[i] = replacement
				else job.blocked = true end
			end
		end
	end
	table.sort(row.jobs, function(a, b) return a.history_index > b.history_index end)
	return true
end

local function descend(player, rooms, pending, key)
	if not player.GetHistory then return end
	if pending[key] then
		if not refresh_pending_jobs(player, pending[key]) then return end
	else
		local history = player:GetHistory():GetCollectiblesHistory()
		if type(history) ~= "table" then return end
		pending[key] = {jobs = build_dig_jobs(player, history, growing_roots(player))}
	end
	local jobs = pending[key].jobs
	local unfinished, queued = 0, 0
	for _, job in ipairs(jobs) do
		if not job.completed and not job.retired then
			unfinished = unfinished + 1
			if not job.blocked then
				queued = queued + 1
				visual.queue(player, job, queued, function(landing)
					if commit_job(player, job, landing) then
						local done = true
						for _, other in ipairs(jobs) do
							if not other.completed and not other.retired then done = false break end
						end
						if done then mark_room_processed(processed_rooms(), key) end
						return true
					end
					return false
				end)
			end
		end
	end
	if unfinished == 0 then mark_room_processed(rooms, key) end
end

local function sync_growth(player)
	if not player.GetHistory or player:GetCollectibleNum(item.entity) <= 0 then return end
	local history = player:GetHistory():GetCollectiblesHistory()
	if type(history) ~= "table" then return end
	local layout = visual.get_history_layout(player:GetData().__Index)
	local states = player_growth(player)
	if not states then return end
	local planned = {}
	for _, job in ipairs(build_dig_jobs(player, history, growing_roots(player))) do
		planned[root_key(job.root_time, job.root_occurrence)] = true
	end
	local occurrences = {}
	for _, entry in ipairs(history) do
		if not entry:IsTrinket() and entry:GetItemID() == item.entity then
			local time = entry:GetTime()
			occurrences[time] = (occurrences[time] or 0) + 1
			local key = root_key(time, occurrences[time])
			if not planned[key] and not states[key] then
				states[key] = {root_time = time, root_occurrence = occurrences[time],
					phase = "grow", progress = 0, tick = 0}
			end
		end
	end
	local members = growth_members(history, states)
	if #members > 0 and not growth.debug_active(player, members[1].state) then
		growth.update(player, members[1].state, history, layout, members)
	end
	growth.update_debug(player, history, layout, members)
end

local function render_growth()
	for _, player in ipairs(auxi.GetPlayers()) do
		local states = player_growth(player)
		if states and player.GetHistory and player:GetCollectibleNum(item.entity) > 0 then
			local history = player:GetHistory():GetCollectiblesHistory()
			if type(history) == "table" then
				local layout = visual.get_history_layout(player:GetData().__Index)
				local members = growth_members(history, states)
				if #members > 0 and not growth.debug_active(player, members[1].state) then
					growth.render(player, members[1].state, history, layout,
						visual.draw_history_icon, members)
				end
				growth.render_debug(player, history, layout, visual.draw_history_icon, members)
			end
		end
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		visual.clear_animations()
		growth.clear_visuals()
		local room = Game():GetRoom()
		if not room then return end
		local room_id = room_key()
		if not room_id then return end
		runtime_room_key = room_id
		local rooms = processed_rooms()
		local pending = pending_rooms()
		for _, player in ipairs(auxi.GetPlayers()) do
			local player_index = player:GetData().__Index
			if player_index ~= nil and player:GetCollectibleNum(item.entity) > 0 then
				local key = tostring(player_index) .. ":" .. room_id
				if not rooms[key] and (room:IsFirstVisit() or pending[key]) then
					descend(player, rooms, pending, key)
				end
			end
		end
	end,
})

-- Layout cache only; hide/proxy paint is owned by history_hud_render_holder.
table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_HISTORYHUD_RENDER,
	Function = function(_, hud, render_pos)
		visual.capture_history(hud, render_pos, false)
	end})
table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_HUD_RENDER,
	Function = function()
		visual.render()
		render_growth()
		growth.render_flashes()
	end})
table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_UPDATE,
	Function = function()
		local current = room_key()
		if current and runtime_room_key ~= current then
			runtime_room_key = current
			local rooms, pending = processed_rooms(), pending_rooms()
			for _, player in ipairs(auxi.GetPlayers()) do
				local index = player:GetData().__Index
				if index ~= nil then
					local key = tostring(index) .. ":" .. current
					if pending[key] and not rooms[key] then descend(player, rooms, pending, key) end
				end
			end
		end
		visual.update()
		growth.advance_flashes()
		for _, player in ipairs(auxi.GetPlayers()) do sync_growth(player) end
	end})
table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	Function = function() visual.reset() growth.clear_visuals() runtime_room_key = nil end})
table.insert(item.myToCall, {CallBack = enums.Callbacks.POST_REWIND,
	Function = function() visual.reset() growth.clear_visuals() runtime_room_key = nil end})

function item.debug_status()
	local active, tick, phase = visual.status()
	local current = room_key()
	local pending_count, committed_count = 0, 0
	local blocked_count = 0
	local room_states = {}
	local growth_details = {}
	if current then
		local rooms, pending = processed_rooms(), pending_rooms()
		for _, player in ipairs(auxi.GetPlayers()) do
			local index = player:GetData().__Index
			local key = index ~= nil and (tostring(index) .. ":" .. current)
			local row = key and pending[key]
			room_states[#room_states + 1] = string.format("player=%s room=%s first=%s planned=%s processed=%s",
				tostring(index), current, tostring(Game():GetRoom():IsFirstVisit()),
				row and tostring(#row.jobs) or "none", tostring(key and rooms[key] == true))
			if row then
				for _, job in ipairs(row.jobs) do
					if job.completed then committed_count = committed_count + 1
					else
						pending_count = pending_count + 1
						if job.blocked then blocked_count = blocked_count + 1 end
					end
				end
			end
			for root, state in pairs(player_growth(player) or {}) do
				growth_details[#growth_details + 1] = string.format("P%s R%s %s %s/%s covered=%s",
					tostring(index), root, tostring(state.phase), tostring(state.progress or 0),
					tostring(state.tick or 0), tostring(state.covered or 0))
			end
		end
	end
	return active, tick, phase, pending_count, committed_count,
		visual.diagnostics() .. "\n" .. table.concat(room_states, " | ") .. " blocked=" .. blocked_count
			.. "\ngrowth: " .. table.concat(growth_details, " | ")
end

function item.debug_clear_visuals()
	visual.clear_animations()
end

function item.debug_set_anchors(value)
	visual.set_debug_anchors(value)
end

function item.debug_get_anchors()
	return visual.get_debug_anchors()
end

function item.debug_preview(player)
	if not player or not player.GetHistory then return false end
	local history = player:GetHistory():GetCollectiblesHistory()
	if type(history) ~= "table" then return false end
	local jobs = build_dig_jobs(player, history)
	if #jobs == 0 then return false end
	if visual.has_gameplay_jobs() then return false end
	for i, job in ipairs(jobs) do visual.queue(player, job, i, nil) end
	return true
end

function item.debug_growth_burst(player)
	if not player or not player.GetHistory then return false end
	local history = player:GetHistory():GetCollectiblesHistory()
	if type(history) ~= "table" then return false end
	local states = player_growth(player)
	if not states then return false end
	local layout = visual.get_history_layout(player:GetData().__Index)
	local members = growth_members(history, states)
	return #members > 0 and growth.debug_burst(player, members[1].state,
		history, layout, members) or false
end

function item.debug_plan(player)
	if not player or not player.GetHistory then return "no player history" end
	local history = player:GetHistory():GetCollectiblesHistory()
	if type(history) ~= "table" then return "history unavailable" end
	local roots = 0
	for _, entry in ipairs(history) do
		if not entry:IsTrinket() and entry:GetItemID() == item.entity then roots = roots + 1 end
	end
	local jobs = build_dig_jobs(player, history)
	local targets = {}
	for _, job in ipairs(jobs) do targets[#targets + 1] = tostring(job.id) end
	return string.format("history roots=%d planned=%d targets=[%s]", roots, #jobs,
		table.concat(targets, ","))
end

return item

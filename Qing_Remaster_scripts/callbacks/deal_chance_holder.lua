-- Deal Chance Holder：RGON total Deal calculation 的公共 runtime owner。
-- Room:GetDevilRoomChance / MC_POST_DEVIL_CALCULATE = 总 Deal 计算标量，不是最终 Devil HUD。
-- 不 upper-clamp；不因 Found-HUD 非法楼层清零。
-- Planetarium 不属于本 holder：无 state / callback / refresh；由业务方自有 POST 拥有。
-- snapshot_cached：calculation callback 内可用；snapshot_with_getters：禁止在 callback 内调用。

local M = {
	ToCall = {},
	myToCall = {},
}

local state = {
	frame = -1,
	stage = nil,
	stage_type = nil,

	raw_total_deal = nil,
	modified_total_deal = nil,
	total_deal_mod_applied = 0,

	devil_calc_seen_this_floor = false,
	devil_stage_penalty_seen_this_floor = false,

	last_devil_post_frame = nil,
}

-- key -> fn(): { total_deal = number? }
local providers = {}

local function game_frame()
	local ok, n = pcall(function() return Game():GetFrameCount() end)
	if ok then return n end
	return -1
end

local function refresh_stage()
	local level = Game():GetLevel()
	if not level then return end
	state.stage = level:GetStage()
	state.stage_type = level:GetStageType()
end

local function sum_provider_field(field)
	local total = 0
	for key, fn in pairs(providers) do
		if type(fn) == "function" then
			local ok, result = pcall(fn)
			if not ok then
				print(
					"[deal_chance_holder] provider failed: "
					.. tostring(key)
					.. " / "
					.. tostring(result)
				)
			elseif type(result) == "table" then
				total = total + (tonumber(result[field]) or 0)
			end
		end
	end
	return total
end

function M.register_provider(key, fn)
	key = tostring(key or "")
	if key == "" or type(fn) ~= "function" then
		return false
	end
	providers[key] = fn
	return true
end

function M.unregister_provider(key)
	key = tostring(key or "")
	providers[key] = nil
end

function M.reset_floor_flags()
	state.devil_calc_seen_this_floor = false
	state.devil_stage_penalty_seen_this_floor = false
end

function M.note_devil_stage_penalty()
	state.devil_stage_penalty_seen_this_floor = true
end

function M.get_raw_total_deal()
	return state.raw_total_deal
end

function M.get_modified_total_deal()
	return state.modified_total_deal
end

-- deprecated compatibility aliases
function M.get_raw_final_deal()
	return M.get_raw_total_deal()
end

function M.get_modified_final_deal()
	return M.get_modified_total_deal()
end

--- callback-safe：禁止 GetDevilRoomChance / GetPlanetariumChance。
function M.snapshot_cached()
	local game = Game()
	return {
		frame = state.frame,
		stage = state.stage,
		stage_type = state.stage_type,
		devil_spawned = game:GetStateFlag(GameStateFlag.STATE_DEVILROOM_SPAWNED) == true,
		devil_visited = game:GetStateFlag(GameStateFlag.STATE_DEVILROOM_VISITED) == true,
		angel_spawned = game:GetStateFlag(GameStateFlag.STATE_FAMINE_SPAWNED) == true,
		raw_total_deal = state.raw_total_deal,
		modified_total_deal = state.modified_total_deal,
		total_deal_mod_applied = state.total_deal_mod_applied,
		post_devil_calculate = state.raw_total_deal,
		modified_final_deal = state.modified_total_deal,
		devil_mod_applied = state.total_deal_mod_applied,
		devil_calc_seen_this_floor = state.devil_calc_seen_this_floor,
		devil_stage_penalty_seen_this_floor = state.devil_stage_penalty_seen_this_floor,
		last_devil_post_frame = state.last_devil_post_frame,
	}
end

--- 普通帧旁证；calculation callback 内禁止。
function M.snapshot_with_getters()
	local out = M.snapshot_cached()
	local game = Game()
	local level = game:GetLevel()
	local room = game:GetRoom()
	if room and room.GetDevilRoomChance then
		out.room_get_devil_chance = tonumber(room:GetDevilRoomChance())
	end
	if level then
		if level.CanSpawnDevilRoom then
			local ok, v = pcall(function() return level:CanSpawnDevilRoom() end)
			if ok then out.can_spawn_devil_room = v == true end
		end
		if level.IsDevilRoomDisabled then
			local ok, v = pcall(function() return level:IsDevilRoomDisabled() end)
			if ok then out.devil_room_disabled = v == true end
		end
		if level.GetAngelRoomChance then
			out.level_get_angel_modifier = tonumber(level:GetAngelRoomChance())
		end
		-- Planetarium 旁证 getter（本 holder 不拥有 Planetarium calculation）
		if level.GetPlanetariumChance then
			out.planetarium_getter = tonumber(level:GetPlanetariumChance())
		end
	end
	return out
end

function M.snapshot()
	return M.snapshot_with_getters()
end

--- 主动触发 total Deal calculation chain（含 POST_DEVIL）。
--- 仅普通 gameplay / action 上下文；禁止在 Devil calculation callback 内调用。
function M.refresh_total_deal()
	state.raw_total_deal = nil
	state.modified_total_deal = nil

	local room = Game():GetRoom()
	if not room or not room.GetDevilRoomChance then
		return nil
	end
	local ok, value = pcall(function()
		return room:GetDevilRoomChance()
	end)
	if not ok then
		return nil
	end
	return tonumber(value)
end

function M.on_post_devil_calculate(chance)
	refresh_stage()
	local raw = tonumber(chance) or 0
	state.frame = game_frame()
	state.raw_total_deal = raw
	state.devil_calc_seen_this_floor = true
	state.last_devil_post_frame = state.frame

	local mod = sum_provider_field("total_deal")
	state.total_deal_mod_applied = mod
	local modified = raw + mod
	if modified < 0 then
		modified = 0
	end
	state.modified_total_deal = modified

	if math.abs(mod) < 1e-9 then
		return nil
	end
	return modified
end

-- deprecated: single-provider shim for leftover callers（仅 total_deal）
function M.set_modifier_provider(fn)
	if type(fn) ~= "function" then
		M.unregister_provider("__legacy_single")
		return
	end
	M.register_provider("__legacy_single", function()
		return {
			total_deal = tonumber(fn("devil")) or 0,
		}
	end)
end

if ModCallbacks.MC_POST_DEVIL_CALCULATE then
	table.insert(M.ToCall, #M.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_DEVIL_CALCULATE,
		params = nil,
		Function = function(_, chance)
			return M.on_post_devil_calculate(chance)
		end,
	})
end

local enums = require("Qing_Remaster_scripts.core.enums")
table.insert(M.myToCall, #M.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function(_)
		M.reset_floor_flags()
		refresh_stage()
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function(_)
		state.raw_total_deal = nil
		state.modified_total_deal = nil
		state.total_deal_mod_applied = 0
		state.frame = -1
		M.reset_floor_flags()
		refresh_stage()
	end,
})

return M

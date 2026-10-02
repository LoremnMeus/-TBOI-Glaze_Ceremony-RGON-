local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Wavering_Eyes,
	own_key = "Item_Wav_Eye_",
	MISS_GAIN = 1,
	HIT_RECOVERY = 0.35,
	DEFOCUS_MAX = 4,
	WAVER_PER_TWO_GAZE = 3,
	WAVER_MAX_ANGLE = 25,
	WAVER_PHASE_STEP = 35,
	SOFT_HOMING_GAZE = 5,
	HOMING_GAZE = 8,
	HOOK_GAZE = 13,
	RUBBER_GAZE = 21,
	SOFT_HOMING_RADIUS = 90,
	SOFT_HOMING_STRENGTH = 0.04,
	BREAK_FLASH_FRAMES = 14,
	buff_offsets = {
		[8] = {flag = BitSet128(1 << 2, 0)},
		[13] = {flag = BitSet128(1 << 30, 0)},
		[21] = {flag = BitSet128(1 << 19, 0)},
	},
}

local function migrate_save()
	if save.elses[item.own_key.."effect"] and not save.elses[item.own_key.."gaze"] then
		save.elses[item.own_key.."gaze"] = save.elses[item.own_key.."effect"]
	end
	if save.elses[item.own_key.."effect2"] and not save.elses[item.own_key.."defocus"] then
		save.elses[item.own_key.."defocus"] = save.elses[item.own_key.."effect2"]
	end
end

local function gaze_table()
	migrate_save()
	save.elses[item.own_key.."gaze"] = save.elses[item.own_key.."gaze"] or {}
	return save.elses[item.own_key.."gaze"]
end

local function defocus_table()
	migrate_save()
	save.elses[item.own_key.."defocus"] = save.elses[item.own_key.."defocus"] or {}
	return save.elses[item.own_key.."defocus"]
end

local function player_idx(player)
	return player and player:GetData().__Index
end

function item.get_gaze(player)
	local idx = player_idx(player)
	if not idx then
		return 0
	end
	return gaze_table()[idx] or 0
end

function item.get_defocus(player)
	local idx = player_idx(player)
	if not idx then
		return 0
	end
	return defocus_table()[idx] or 0
end

local function waver_amplitude(gaze)
	return math.min(item.WAVER_MAX_ANGLE, math.floor((gaze or 0) / 2) * item.WAVER_PER_TWO_GAZE)
end

function item.waver_amplitude(gaze)
	return waver_amplitude(gaze)
end

local function tears_bonus(gaze)
	local tier = math.floor((gaze or 0) / 3)
	return tier > 0 and 0.5 * tier ^ 0.5 or 0
end

function item.tears_bonus_from_gaze(gaze)
	return tears_bonus(gaze)
end

local function defocus_ratio(player)
	return math.min(1, item.get_defocus(player) / item.DEFOCUS_MAX)
end

local function gaze_tear_color(gaze, defocus)
	local ratio = math.min(1, (defocus or 0) / item.DEFOCUS_MAX)
	local col
	if gaze >= item.RUBBER_GAZE then
		col = Color(0.85, 0.35, 1, 1, 0.85, 0.15, 0.95)
	elseif gaze >= item.HOOK_GAZE then
		col = Color(0.9, 0.3, 0.95, 1, 0.75, 0.05, 0.85)
	elseif gaze >= item.HOMING_GAZE then
		col = Color(0.88, 0.32, 0.9, 1, 0.7, 0, 0.8)
	elseif gaze >= item.SOFT_HOMING_GAZE then
		col = Color(0.86, 0.34, 0.82, 1, 0.65, 0, 0.75)
	else
		local mul = math.max(0, math.min(1, (gaze or 0) ^ 0.5 / 2))
		col = auxi.AddColor(Color(1, 1, 1, 1), Color(0.8, 0.3, 0.7, 1, 0.7, 0, 0.7), -0.5 + 1.5 * (1 - mul), 1.5 * mul)
	end
	if ratio >= 0.5 then
		local dark = 1 - (ratio - 0.5) * 0.65
		col = Color(col.R * dark, col.G * dark, col.B * dark, col.A, col.RO, col.GO, col.BO)
	end
	return col
end

function item.color_from_state(gaze, defocus)
	return gaze_tear_color(gaze, defocus)
end

function item.flags_from_gaze(gaze)
	local mask = BitSet128(0, 0)
	gaze = gaze or 0
	for threshold, info in pairs(item.buff_offsets) do
		if gaze >= threshold and info.flag then
			mask = mask | info.flag
		end
	end
	return mask
end

--- Per-craft independent Wavering state on Blue_Print rec.dynamic.
function item.ensure_craft_state(rec)
	if not rec then
		return {gaze = 0, defocus = 0, phase = 0}
	end
	rec.dynamic = rec.dynamic or {}
	local st = rec.dynamic.wavering
	if type(st) ~= "table" then
		st = {gaze = 0, defocus = 0, phase = 0}
		rec.dynamic.wavering = st
	end
	st.gaze = tonumber(st.gaze) or 0
	st.defocus = tonumber(st.defocus) or 0
	st.phase = tonumber(st.phase) or 0
	return st
end

function item.add_craft_hit(state)
	if type(state) ~= "table" then return end
	state.gaze = (tonumber(state.gaze) or 0) + 1
	state.defocus = math.max(0, (tonumber(state.defocus) or 0) - item.HIT_RECOVERY)
end

function item.add_craft_miss(state)
	if type(state) ~= "table" then return end
	state.defocus = (tonumber(state.defocus) or 0) + item.MISS_GAIN
	if state.defocus >= item.DEFOCUS_MAX then
		state.gaze = 0
		state.defocus = 0
	end
end

local function resolve_craft_state_from_tear(tear)
	local d = tear and tear:GetData()
	if not d or not d[item.own_key .. "craft"] then
		return nil, nil, nil
	end
	local ok_air, Air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
	local air = d[item.own_key .. "craft_air"]
	if not air and ok_air and Air and Air.own_key then
		air = d[Air.own_key .. "craft_air"]
	end
	if not air then return nil, nil, nil end
	local CraftIdentity = require("Qing_Remaster_scripts.mimics.craft_identity")
	local uid = CraftIdentity.get_uid(air)
	local player = auxi.check_spawner_player(air)
	if not uid or not player then return nil, nil, nil end
	local bp = require("Qing_Remaster_scripts.items.Item_Blue_Print")
	local rec = bp.find_craft and bp.find_craft(player, uid)
	if not rec then return nil, nil, nil end
	return item.ensure_craft_state(rec), air, player
end

--- Stamp / bend a Craft tear for Wavering Eyes (owner remains this module).
function item.on_craft_tear_fire(tear, air, player, craft_prof)
	if not tear or not air or not craft_prof then return end
	local id = item.entity
	if not id or id <= 0 then return end
	local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
	if CraftProfile.count_of(craft_prof.counts, id) <= 0 then return end
	local bp = require("Qing_Remaster_scripts.items.Item_Blue_Print")
	local CraftIdentity = require("Qing_Remaster_scripts.mimics.craft_identity")
	local uid = CraftIdentity.get_uid(air)
	local rec = uid and bp.find_craft and bp.find_craft(player, uid)
	local state = item.ensure_craft_state(rec)
	local d = tear:GetData()
	d[item.own_key .. "waver"] = true
	d[item.own_key .. "craft"] = true
	d[item.own_key .. "craft_air"] = air
	state.phase = (tonumber(state.phase) or 0) + math.rad(item.WAVER_PHASE_STEP)
	local offset = math.sin(state.phase) * waver_amplitude(state.gaze)
	local spd = tear.Velocity:Length()
	if spd > 0.01 then
		tear.Velocity = auxi.MakeVector(tear.Velocity:GetAngleDegrees() + offset) * spd
	end
	local flags = item.flags_from_gaze(state.gaze)
	if flags ~= BitSet128(0, 0) then
		tear.TearFlags = (tear.TearFlags or BitSet128(0, 0)) | flags
	end
	tear.Color = gaze_tear_color(state.gaze, state.defocus)
end

local function nearest_enemy(pos, radius)
	local best
	local best_dist = radius
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent:IsVulnerableEnemy() and ent:IsActiveEnemy() then
			local dist = (ent.Position - pos):Length()
			if dist < best_dist then
				best = ent
				best_dist = dist
			end
		end
	end
	return best
end

local function lerp_angle_deg(cur, tgt, t)
	local diff = tgt - cur
	while diff > 180 do
		diff = diff - 360
	end
	while diff < -180 do
		diff = diff + 360
	end
	return cur + diff * t
end

local function apply_soft_homing(tear, gaze)
	gaze = gaze or 0
	if gaze < item.SOFT_HOMING_GAZE or gaze >= item.HOMING_GAZE then
		return
	end
	local enemy = nearest_enemy(tear.Position, item.SOFT_HOMING_RADIUS)
	if not enemy then
		return
	end
	local spd = tear.Velocity:Length()
	if spd <= 0.01 then
		return
	end
	local cur = tear.Velocity:GetAngleDegrees()
	local tgt = (enemy.Position - tear.Position):GetAngleDegrees()
	local ang = lerp_angle_deg(cur, tgt, item.SOFT_HOMING_STRENGTH)
	tear.Velocity = auxi.MakeVector(ang) * spd
end

local function apply_tear_visual(tear, gaze)
	gaze = gaze or 0
	if gaze < item.HOMING_GAZE then
		return
	end
	local alpha = gaze >= item.RUBBER_GAZE and 0.78 or (gaze >= item.HOOK_GAZE and 0.86 or 0.92)
	local c = tear.Color or Color(1, 1, 1, 1)
	tear.Color = Color(c.R, c.G, c.B, alpha, c.RO, c.GO, c.BO)
end

local function play_break_feedback(player)
	local d = player:GetData()
	d[item.own_key.."break_flash"] = item.BREAK_FLASH_FRAMES
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_DIMEDOWN, 0.55, 1.05, false, 0, 2)
	player:AddCacheFlags(CacheFlag.CACHE_TEARCOLOR | CacheFlag.CACHE_TEARFLAG | CacheFlag.CACHE_FIREDELAY)
	player:GetData().should_evaluate_on_update_once = true
end

function item.add_waver_eye_charge(player)
	local idx = player_idx(player)
	if not idx then
		return
	end
	local gaze = gaze_table()
	local defocus = defocus_table()
	gaze[idx] = (gaze[idx] or 0) + 1
	defocus[idx] = math.max(0, (defocus[idx] or 0) - item.HIT_RECOVERY)
	if gaze[idx] % 3 == 0 then
		player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
	end
	if item.buff_offsets[gaze[idx]] then
		player:AddCacheFlags(CacheFlag.CACHE_TEARFLAG)
	end
	player:AddCacheFlags(CacheFlag.CACHE_TEARCOLOR)
	player:GetData().should_evaluate_on_update_once = true
end

function item.clear_waver_eye_charge(player)
	local idx = player_idx(player)
	if not idx then
		return
	end
	local gaze = gaze_table()
	local defocus = defocus_table()
	defocus[idx] = (defocus[idx] or 0) + item.MISS_GAIN
	if defocus[idx] >= item.DEFOCUS_MAX then
		gaze[idx] = 0
		defocus[idx] = 0
		play_break_feedback(player)
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	if not auxi.has_have_coll(player, item.entity) then
		return
	end
	local idx = player_idx(player)
	if not idx then
		return
	end
	local gaze = item.get_gaze(player)
	if cacheFlag == CacheFlag.CACHE_FIREDELAY then
		player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay, auxi.get_mxdelay_multiplier(player) * tears_bonus(gaze))
	end
	if cacheFlag == CacheFlag.CACHE_TEARFLAG then
		for threshold, info in pairs(item.buff_offsets) do
			if gaze >= threshold then
				player.TearFlags = player.TearFlags | info.flag
			end
		end
	end
	if cacheFlag == CacheFlag.CACHE_TEARCOLOR then
		player.TearColor = gaze_tear_color(gaze, item.get_defocus(player))
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_FIRE_TEAR, params = nil,
Function = function(_, ent)
	local player = auxi.check_spawner_player(ent)
	if not player or not auxi.has_have_coll(player, item.entity) then
		return
	end
	local idx = player_idx(player)
	if not idx then
		return
	end
	local d = ent:GetData()
	d[item.own_key.."waver"] = true
	local pdata = player:GetData()
	pdata[item.own_key.."phase"] = (pdata[item.own_key.."phase"] or 0) + math.rad(item.WAVER_PHASE_STEP)
	local offset = math.sin(pdata[item.own_key.."phase"]) * waver_amplitude(item.get_gaze(player))
	ent.Velocity = auxi.MakeVector(ent.Velocity:GetAngleDegrees() + offset) * ent.Velocity:Length()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_, tear)
	local d = tear:GetData()
	if d[item.own_key .. "craft"] then
		local state = resolve_craft_state_from_tear(tear)
		if state then
			apply_soft_homing(tear, state.gaze)
			apply_tear_visual(tear, state.gaze)
		end
		return
	end
	if tear.SpawnerType ~= 1 or not tear.Parent then
		return
	end
	local player = tear.Parent:ToPlayer()
	if not player or not auxi.has_have_coll(player, item.entity) then
		return
	end
	if not d[item.own_key.."waver"] then
		return
	end
	local gaze = item.get_gaze(player)
	apply_soft_homing(tear, gaze)
	apply_tear_visual(tear, gaze)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_, ent, col)
	local d = ent:GetData()
	if d[item.own_key .. "craft"] then
		if col and col:IsVulnerableEnemy() and col:IsActiveEnemy()
			and d[item.own_key.."waver"] and not d[item.own_key.."waver_hit"] then
			d[item.own_key.."waver_hit"] = true
			local state = resolve_craft_state_from_tear(ent)
			if state then item.add_craft_hit(state) end
		end
		return
	end
	if ent.SpawnerType == 1 and ent.Parent then
		local player = ent.Parent:ToPlayer()
		if player and col:IsVulnerableEnemy() and col:IsActiveEnemy() then
			if auxi.has_have_coll(player, item.entity) then
				if d[item.own_key.."waver"] and not d[item.own_key.."waver_hit"] then
					d[item.own_key.."waver_hit"] = true
					item.add_waver_eye_charge(player)
				end
			end
		end
	end
end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = nil,
Function = function(_, ent)
	if ent.Type == 2 then
		local d = ent:GetData()
		if d[item.own_key.."waver"] and not d[item.own_key.."waver_hit"] then
			if d[item.own_key .. "craft"] then
				local state = resolve_craft_state_from_tear(ent)
				if state then item.add_craft_miss(state) end
			elseif ent.Parent then
				local player = ent.Parent:ToPlayer()
				if player and auxi.has_have_coll(player, item.entity) then
					item.clear_waver_eye_charge(player)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	if not auxi.has_have_coll(player, item.entity) then
		return
	end
	local d = player:GetData()
	local flash = d[item.own_key.."break_flash"]
	if flash and flash > 0 then
		d[item.own_key.."break_flash"] = flash - 1
		local u = flash / item.BREAK_FLASH_FRAMES
		player:SetColor(Color(1, 1, 1, 0.35 + 0.65 * u, 0.9, 0.4, 0.95), -1, 0, false)
		return
	end
	local ratio = defocus_ratio(player)
	if ratio >= 0.75 then
		local flick = 0.72 + 0.28 * (0.5 + 0.5 * math.sin(Game():GetFrameCount() * 0.55))
		player:SetColor(Color(flick, flick * 0.95, flick, 1, 0.5, 0, 0.6), -1, 0, false)
		player:GetSprite().Rotation = 0
	elseif ratio >= 0.25 then
		player:SetColor(Color(1, 1, 1, 1), -1, 0, false)
		local jitter = math.sin(Game():GetFrameCount() * 0.85) * ratio * 1.8
		player:GetSprite().Rotation = jitter * 0.15
		d[item.own_key.."eye_jitter"] = true
	else
		player:SetColor(Color(1, 1, 1, 1), -1, 0, false)
		if d[item.own_key.."eye_jitter"] then
			player:GetSprite().Rotation = 0
			d[item.own_key.."eye_jitter"] = nil
		end
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."gaze"] = {}
		save.elses[item.own_key.."defocus"] = {}
	else
		migrate_save()
	end
	gaze_table()
	defocus_table()
end,
})

return item

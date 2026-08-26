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

local function tears_bonus(gaze)
	local tier = math.floor((gaze or 0) / 3)
	return tier > 0 and 0.5 * tier ^ 0.5 or 0
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

local function apply_soft_homing(tear, player)
	local gaze = item.get_gaze(player)
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

local function apply_tear_visual(tear, player)
	local gaze = item.get_gaze(player)
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
	if tear.SpawnerType ~= 1 or not tear.Parent then
		return
	end
	local player = tear.Parent:ToPlayer()
	if not player or not auxi.has_have_coll(player, item.entity) then
		return
	end
	local d = tear:GetData()
	if not d[item.own_key.."waver"] then
		return
	end
	apply_soft_homing(tear, player)
	apply_tear_visual(tear, player)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_, ent, col)
	if ent.SpawnerType == 1 and ent.Parent then
		local player = ent.Parent:ToPlayer()
		if player and col:IsVulnerableEnemy() and col:IsActiveEnemy() then
			if auxi.has_have_coll(player, item.entity) then
				local d = ent:GetData()
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
		if d[item.own_key.."waver"] and not d[item.own_key.."waver_hit"] and ent.Parent then
			local player = ent.Parent:ToPlayer()
			if player and auxi.has_have_coll(player, item.entity) then
				item.clear_waver_eye_charge(player)
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

-- Shared fullscreen Mental Desync controller (Qing_Mental_Desync shader).
-- Used by Mental Disorder and Hanged Man conflict VFX — do not duplicate this state.
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local DESYNC_SHADER = "Qing_Mental_Desync"
local DESYNC_MAX_DEFAULT = 10

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Qing_Screen_Desync_",
	_glitch = nil,
}

local function empty_desync_params()
	return {
		P1 = {0, 0, 0, 0},
		P2 = {0, 0, 0, 0},
		P3 = {0, 0, 0, 0},
	}
end

local function px_uv(px, axis)
	local m = auxi.check_screen_multi(Vector(1, 1)) * 256
	local den = axis == "y" and m.Y or m.X
	if den < 1 then den = 256 end
	return px / den
end

local function desync_strength(gch)
	if not gch or (gch.timer or 0) <= 0 then return 0 end
	if gch.mild then
		return 0.08 + 0.04 * (gch.timer / math.max(1, gch.max))
	end
	local t = gch.timer
	if t >= 8 then return 0.25
	elseif t >= 5 then return 0.65
	elseif t >= 3 then return 0.35
	else return 0.12 end
end

local function pack_desync_params()
	local gch = item._glitch
	if not gch or (gch.timer or 0) <= 0 then return empty_desync_params() end
	local strength = desync_strength(gch)
	local chromatic = px_uv(gch.mild and 1.2 or 2.4, "x")
	if not gch.mild and gch.timer >= 5 and gch.timer < 8 then
		chromatic = px_uv(3.2, "x")
	end
	local gx, gy = gch.global[1], gch.global[2]
	if not gch.mild and gch.timer >= 3 and gch.timer < 6 then
		gx = gx * 2.2
		gy = gy * 2.2
	elseif gch.timer >= 8 then
		gx, gy = gx * 0.25, gy * 0.25
	end
	return {
		P1 = {strength, chromatic, gch.off1, gch.off2},
		P2 = {gch.band1[1], gch.band1[2], gch.band2[1], gch.band2[2]},
		P3 = {gx, gy, gch.band3_y, gch.off3},
	}
end

--- Start fullscreen desync. mild = very light flash (leave-room / soft cue).
function item.trigger(frames, mild)
	frames = math.max(1, math.floor(tonumber(frames) or DESYNC_MAX_DEFAULT))
	local seed = Game():GetFrameCount() + (Game():GetRoom():GetDecorationSeed() or 0)
	local rng = RNG()
	rng:SetSeed(math.max(1, seed % 2147483646), 35)
	local function band_y(lo, hi)
		local y0 = lo + rng:RandomFloat() * (hi - lo)
		local h = 0.04 + rng:RandomFloat() * 0.04
		return y0, math.min(0.98, y0 + h)
	end
	local b1a, b1b = band_y(0.16, 0.28)
	local b2a, b2b = band_y(0.48, 0.58)
	local b3 = 0.68 + rng:RandomFloat() * 0.12
	local sign1 = rng:RandomInt(2) == 0 and 1 or -1
	local sign2 = -sign1
	item._glitch = {
		timer = frames,
		max = frames,
		mild = mild == true,
		seed = seed,
		band1 = {b1a, b1b},
		band2 = {b2a, b2b},
		band3_y = b3,
		off1 = sign1 * (0.005 + rng:RandomFloat() * 0.004),
		off2 = sign2 * (0.007 + rng:RandomFloat() * 0.005),
		off3 = sign1 * (0.012 + rng:RandomFloat() * 0.006),
		global = {
			(rng:RandomFloat() - 0.5) * px_uv(2, "x"),
			(rng:RandomFloat() - 0.5) * px_uv(1.5, "y"),
		},
	}
end

function item.update()
	local gch = item._glitch
	if not gch or (gch.timer or 0) <= 0 then
		return
	end
	gch.timer = gch.timer - 1
	if gch.timer <= 0 then
		item._glitch = nil
	end
end

function item.reset()
	item._glitch = nil
end

function item.get_shader_params(name)
	if name ~= DESYNC_SHADER then return end
	if auxi.shader_effect_idle() or auxi.is_pause_menu_open() then
		return empty_desync_params()
	end
	return pack_desync_params()
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	Function = function()
		item.update()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_GET_SHADER_PARAMS,
	Function = function(_, name)
		return item.get_shader_params(name)
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	Function = function()
		item.reset()
	end,
})

return item

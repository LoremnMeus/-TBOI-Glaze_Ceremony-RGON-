local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Aquarius_holder_",
}

-- Creep spawn rate ≠ proc opportunity rate. Cap synthetic samples per player
-- so continuous walking does not flood DPS consumers (Game frame clock = 30 Hz).
local SAMPLE_INTERVAL_FLOOR = 8

local function aquarius_sample_interval(player)
	local fire_delay = math.max(1, math.floor((player.MaxFireDelay or 10) + 1))
	return math.max(SAMPLE_INTERVAL_FLOOR, fire_delay)
end

local function can_emit_aquarius_sample(player)
	if not player then
		return false
	end
	local d = player:GetData()
	local key = item.own_key .. "synthetic_sample_frame"
	local frame = Game():GetFrameCount()
	local last = tonumber(d[key])
	local interval = aquarius_sample_interval(player)
	if last ~= nil and frame - last < interval then
		return false
	end
	d[key] = frame
	return true
end

function item.help_control(ent,params)
	local d = ent:GetData()
	d[item.own_key.."effect"] = params
	if params.init then item.work(ent) end
end

function item.work(ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		auxi.check_if_any(d[item.own_key.."effect"].special,ent)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 54,
Function = function(_,ent)
	item.work(ent)
	-- Observation point only: creep still spawns every step; synthetic sample is rate-limited.
	if ent.FrameCount == 1 and ent.SpawnerEntity and ent.SpawnerEntity.Type == EntityType.ENTITY_PLAYER then
		local player = ent.SpawnerEntity:ToPlayer()
		if can_emit_aquarius_sample(player) then
			attack_holder.EmitSyntheticSample(player, {
				family = "tear",
				source_entity = ent,
				position = ent.Position,
				sample_weight = 1,
				reason = "aquarius",
				synthetic_kind = "sample",
			})
		end
	end
end,
})

return item

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	entity = enums.Items.Multiknife,
	own_key = "Item_Multiknife_",
	max_charge = 10,
}

local function get_direction(player)
	local data = player:GetData()
	local direction = auxi.getdir(player)
	if direction:Length() < 0.05 then direction = player:GetMovementInput() end
	if direction:Length() < 0.05 then direction = data[item.own_key.."last_direction"] or Vector(0,-1) end
	return direction:Normalized()
end

local function slash(player,direction,charge)
	local multiplier = 2 ^ (charge - 1)
	local reach = multiplier
	local half_width = 24
	local damage = multiplier

	for _,entity in ipairs(Isaac.GetRoomEntities()) do
		if entity:IsVulnerableEnemy() and entity:IsActiveEnemy(false) and
			not entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			local relative = entity.Position - player.Position
			local forward = relative.X * direction.X + relative.Y * direction.Y
			local sideways = math.abs(relative.X * direction.Y - relative.Y * direction.X)
			if forward >= -entity.Size and forward <= reach + entity.Size and
				sideways <= half_width + entity.Size then
				entity:TakeDamage(damage,0,EntityRef(player),0)
				entity.Velocity = entity.Velocity + direction * math.min(18,5 + charge)
			end
		end
	end

	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SWORD_SPIN,1,1,false,0,2)
end

if REPENTOGON and ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE then
	table.insert(item.ToCall,{CallBack = ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE,params = item.entity,
	Function = function(_,_,_,_)
		return 1
	end,
	})
end

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,params = nil,
Function = function(_,player)
	local direction = auxi.getdir(player)
	if direction:Length() > 0.05 then
		player:GetData()[item.own_key.."last_direction"] = direction:Normalized()
	end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_USE_ITEM,params = item.entity,
Function = function(_,_,_,player,use_flags,active_slot)
	local data = player:GetData()
	local cache_key = item.own_key.."last_use"
	local cached = data[cache_key]
	local is_car_battery = use_flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY
	local charge

	if is_car_battery and cached and cached.frame == Game():GetFrameCount() and cached.slot == active_slot then
		charge = cached.charge
	else
		charge = math.min(item.max_charge,player:GetActiveCharge(active_slot))
	end
	if charge < 1 then return {Discharge = false,ShowAnim = false} end

	local direction = get_direction(player)
	if not is_car_battery then
		data[cache_key] = {
			frame = Game():GetFrameCount(),
			slot = active_slot,
			charge = charge,
		}
	end
	slash(player,direction,charge)
	return {Discharge = not is_car_battery,ShowAnim = not is_car_battery}
end,
})

return item

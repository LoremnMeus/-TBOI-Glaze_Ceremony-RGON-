local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local manager = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Custom_Attack_Manager_",
	default_mode = "default",
	modes = {},
	layers = {},
	profiles = {},
	states = {},
	debug = false,
}

local function safe_call(func,...)
	if func == nil then return nil end
	local ok,ret = pcall(func,...)
	if not ok then
		print(manager.own_key..tostring(ret))
		return nil
	end
	return ret
end

local function get_player_key(player)
	if player == nil then return nil end
	local data = player:GetData()
	data[manager.own_key.."player_key"] = data[manager.own_key.."player_key"] or tostring(player.InitSeed)..":"..tostring(player.ControllerIndex)
	return data[manager.own_key.."player_key"]
end

local function player_pairs()
	if PlayerManager and PlayerManager.GetPlayers then
		return pairs(PlayerManager:GetPlayers())
	end
	local players = {}
	for i = 0, Game():GetNumPlayers() - 1 do
		players[#players + 1] = Game():GetPlayer(i)
	end
	return ipairs(players)
end

local function entity_to_player(entity)
	if entity == nil then return nil end
	local ok,player = pcall(function() return entity:ToPlayer() end)
	if ok then return player end
	return nil
end

local function shallow_copy(value)
	local ret = {}
	if type(value) == "table" then
		for k,v in pairs(value) do
			ret[k] = v
		end
	end
	return ret
end

function manager.DebugLog(...)
	if not manager.debug then return end
	local texts = {}
	for i = 1,select("#",...) do
		texts[#texts + 1] = tostring(select(i,...))
	end
	print(manager.own_key..table.concat(texts," "))
end

function manager.RegisterMode(mode_id,mode)
	if mode_id == nil then return end
	mode = mode or {}
	mode.id = mode.id or mode_id
	manager.modes[mode_id] = mode
	return mode
end

function manager.RegisterLayer(layer_id,layer)
	if layer_id == nil then return end
	layer = layer or {}
	layer.id = layer.id or layer_id
	manager.layers[layer_id] = layer
	return layer
end

function manager.RegisterProfile(player_type,profile)
	if player_type == nil then return end
	profile = profile or {}
	manager.profiles[player_type] = profile
	return profile
end

function manager.GetProfile(player)
	if player == nil then return nil end
	return manager.profiles[player:GetPlayerType()]
end

function manager.GetState(player)
	local key = get_player_key(player)
	if key == nil then return nil end
	local state = manager.states[key]
	if state == nil then
		state = {
			key = key,
			playerType = player:GetPlayerType(),
			activeMode = nil,
			previousMode = nil,
			activeLayers = {},
			charge = 0,
			cooldown = 0,
			fireDir = Vector.Zero,
			rawFireDir = Vector.Zero,
			lockedWeaponType = nil,
			vanillaShootSuppressed = false,
			spawned = {},
			flags = {},
			input = {},
		}
		manager.states[key] = state
	end
	return state
end

function manager.GetMode(mode_id)
	return manager.modes[mode_id or manager.default_mode] or manager.modes[manager.default_mode]
end

function manager.SetDebug(enabled)
	manager.debug = enabled == true
end

function manager.GetWeapon(player,slot)
	if not REPENTOGON or player == nil or player.GetWeapon == nil then return nil end
	return player:GetWeapon(slot or 1)
end

function manager.GetWeaponType(player)
	local weapon = manager.GetWeapon(player,1)
	if weapon and weapon.GetWeaponType then
		return weapon:GetWeaponType()
	end
	return auxi.get_weapon(player)
end

function manager.GetRawShootingVector(player)
	if player == nil then return Vector.Zero end
	local cid = player.ControllerIndex
	local left = Input.GetActionValue(ButtonAction.ACTION_SHOOTLEFT,cid)
	local right = Input.GetActionValue(ButtonAction.ACTION_SHOOTRIGHT,cid)
	local up = Input.GetActionValue(ButtonAction.ACTION_SHOOTUP,cid)
	local down = Input.GetActionValue(ButtonAction.ACTION_SHOOTDOWN,cid)
	local vec = Vector(right - left,down - up)
	if vec:Length() > 1 then
		vec = vec:Normalized()
	end
	return vec
end

function manager.GetInput(player)
	local input = {
		fireDir = Vector.Zero,
		rawFireDir = Vector.Zero,
		isShooting = false,
		fireDirection = Direction.NO_DIRECTION,
		controllerIndex = player and player.ControllerIndex or 0,
		weapon = nil,
		weaponType = nil,
	}
	if player == nil then return input end
	input.rawFireDir = manager.GetRawShootingVector(player)
	input.fireDirection = player:GetFireDirection()
	if input.fireDirection ~= Direction.NO_DIRECTION then
		input.fireDir = auxi.GetDirVec(input.fireDirection)
	end
	if input.fireDir:Length() < 0.01 and player.GetAimDirection then
		input.fireDir = player:GetAimDirection()
	end
	if input.fireDir:Length() < 0.01 then
		input.fireDir = input.rawFireDir
	end
	input.isShooting = input.fireDir:Length() > 0.01 or input.fireDirection ~= Direction.NO_DIRECTION
	input.weapon = manager.GetWeapon(player,1)
	if input.weapon and input.weapon.GetWeaponType then
		input.weaponType = input.weapon:GetWeaponType()
	else
		input.weaponType = auxi.get_weapon(player)
	end
	return input
end

function manager.IsVanillaShootSuppressed(player)
	local state = manager.GetState(player)
	return state and state.vanillaShootSuppressed == true
end

function manager.SetVanillaShootSuppressed(player,state,suppressed,reason)
	if player == nil or state == nil then return end
	suppressed = suppressed == true
	local changed = state.vanillaShootSuppressed ~= suppressed
	state.vanillaShootSuppressed = suppressed
	local data = player:GetData()
	if suppressed and changed then
		state.previousShouldNotAttack = data.should_not_attack
	end
	if suppressed then
		data.should_not_attack = true
	end
	if REPENTOGON and player.SetCanShoot then
		player:SetCanShoot(not suppressed)
		if (not suppressed) and player.UpdateCanShoot then
			player:UpdateCanShoot()
		end
	else
		auxi.setCanShoot(player,not suppressed)
	end
	if not suppressed and changed then
		data.should_not_attack = state.previousShouldNotAttack
		state.previousShouldNotAttack = nil
	end
	if changed then
		manager.DebugLog("SetCanShoot",tostring(not suppressed),reason or "")
	end
end

function manager.CleanupSpawned(state)
	if state == nil or state.spawned == nil then return end
	for i = #state.spawned,1,-1 do
		local ent = state.spawned[i]
		if ent and ent.Exists and ent:Exists() then
			ent:Remove()
		end
		state.spawned[i] = nil
	end
end

function manager.TrackSpawned(player,entity)
	local state = manager.GetState(player)
	if state and entity then
		state.spawned[#state.spawned + 1] = entity
	end
	return entity
end

function manager.ResolveMode(player,state,reason)
	local best_mode = nil
	local best_priority = nil
	for id,mode in pairs(manager.modes) do
		if id ~= manager.default_mode and mode.is_active and safe_call(mode.is_active,player,state,reason) then
			local priority = mode.priority or 0
			if best_priority == nil or priority > best_priority then
				best_priority = priority
				best_mode = id
			end
		end
	end
	if best_mode ~= nil then return best_mode end
	local profile = manager.GetProfile(player)
	if profile then
		local resolved = safe_call(profile.get_mode,player,state,reason)
		if resolved ~= nil then return resolved end
		if profile.defaultMode ~= nil then return profile.defaultMode end
	end
	return manager.default_mode
end

function manager.ResolveLayers(player,state,reason)
	local profile = manager.GetProfile(player)
	local resolved = {}
	if profile and profile.layers then
		local layers = safe_call(profile.layers,player,state,reason) or profile.layers
		if type(layers) == "table" then
			for k,v in pairs(layers) do
				if type(k) == "number" then
					resolved[v] = true
				elseif v then
					resolved[k] = true
				end
			end
		end
	end
	for id,layer in pairs(manager.layers) do
		if layer.is_active and safe_call(layer.is_active,player,state,reason) then
			resolved[id] = true
		end
	end
	return resolved
end

function manager.SwitchMode(player,next_mode_id,reason)
	local state = manager.GetState(player)
	if state == nil then return end
	next_mode_id = next_mode_id or manager.default_mode
	if state.activeMode == next_mode_id then return state end
	local old_mode_id = state.activeMode
	local old_mode = manager.GetMode(old_mode_id)
	local next_mode = manager.GetMode(next_mode_id)
	if old_mode then
		safe_call(old_mode.exit,player,state,next_mode_id,reason)
	end
	manager.SetVanillaShootSuppressed(player,state,false,reason or "switch")
	state.previousMode = old_mode_id
	state.activeMode = next_mode_id
	state.charge = 0
	state.cooldown = 0
	state.lockedWeaponType = nil
	if next_mode then
		safe_call(next_mode.enter,player,state,old_mode_id,reason)
	end
	manager.DebugLog("SwitchMode",tostring(old_mode_id),"->",tostring(next_mode_id),reason or "")
	return state
end

function manager.UpdateLayers(player,state,reason)
	local next_layers = manager.ResolveLayers(player,state,reason)
	for id,_ in pairs(state.activeLayers) do
		if not next_layers[id] then
			local layer = manager.layers[id]
			if layer then
				safe_call(layer.exit,player,state,reason)
			end
			state.activeLayers[id] = nil
		end
	end
	for id,_ in pairs(next_layers) do
		if not state.activeLayers[id] then
			local layer = manager.layers[id]
			if layer then
				safe_call(layer.enter,player,state,reason)
			end
			state.activeLayers[id] = true
		end
	end
end

function manager.CleanupPlayer(player,reason)
	local state = manager.GetState(player)
	if state == nil then return end
	local mode = manager.GetMode(state.activeMode)
	if mode then
		safe_call(mode.exit,player,state,manager.default_mode,reason)
	end
	for id,_ in pairs(shallow_copy(state.activeLayers)) do
		local layer = manager.layers[id]
		if layer then
			safe_call(layer.exit,player,state,reason)
		end
	end
	manager.SetVanillaShootSuppressed(player,state,false,reason or "cleanup")
	manager.CleanupSpawned(state)
	state.activeMode = nil
	state.previousMode = nil
	state.activeLayers = {}
	state.charge = 0
	state.cooldown = 0
	state.flags = {}
end

function manager.Emit(event_name,player,context)
	local state = manager.GetState(player)
	if state == nil then return nil end
	context = context or {}
	context.event = event_name
	context.player = player
	context.state = state
	local result = nil
	local mode = manager.GetMode(state.activeMode)
	if mode and mode[event_name] then
		result = safe_call(mode[event_name],player,state,context)
	end
	for id,_ in pairs(state.activeLayers) do
		local layer = manager.layers[id]
		if layer and layer[event_name] then
			local layer_result = safe_call(layer[event_name],player,state,context)
			if layer_result ~= nil then result = layer_result end
		end
	end
	return result
end

function manager.UpdatePlayer(player,reason)
	if player == nil then return end
	local state = manager.GetState(player)
	local player_type = player:GetPlayerType()
	if state.playerType ~= player_type then
		manager.CleanupPlayer(player,"player_type_changed")
		state = manager.GetState(player)
		state.playerType = player_type
	end
	local next_mode = manager.ResolveMode(player,state,reason)
	manager.SwitchMode(player,next_mode,reason or "update")
	manager.UpdateLayers(player,state,reason or "update")
	state.input = manager.GetInput(player)
	state.fireDir = state.input.fireDir
	state.rawFireDir = state.input.rawFireDir
	manager.Emit("update",player,{input = state.input})
end

manager.RegisterMode(manager.default_mode,{
	id = manager.default_mode,
	kind = "passive",
})

table.insert(manager.ToCall,#manager.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	manager.UpdatePlayer(player,"player_update")
end,
})

table.insert(manager.ToCall,#manager.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	manager.Emit("render",player,{offset = offset})
end,
})

table.insert(manager.ToCall,#manager.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for _,player in player_pairs() do
		manager.CleanupPlayer(player,"new_room")
	end
end,
})

table.insert(manager.ToCall,#manager.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_)
	manager.states = {}
end,
})

if REPENTOGON and ModCallbacks.MC_POST_WEAPON_FIRE then
	table.insert(manager.ToCall,#manager.ToCall + 1,{CallBack = ModCallbacks.MC_POST_WEAPON_FIRE, params = nil,
	Function = function(_,weapon,fire_direction,is_shooting,is_interpolated)
		local owner = weapon and weapon.GetOwner and weapon:GetOwner()
		local player = entity_to_player(owner)
		if player then
			manager.Emit("on_weapon_fire",player,{
				weapon = weapon,
				fireDir = fire_direction,
				isShooting = is_shooting,
				isInterpolated = is_interpolated,
			})
		end
	end,
	})
end

if REPENTOGON and ModCallbacks.MC_POST_TRIGGER_WEAPON_FIRED then
	table.insert(manager.ToCall,#manager.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TRIGGER_WEAPON_FIRED, params = nil,
	Function = function(_,fire_direction,fire_amount,owner,weapon)
		local player = entity_to_player(owner)
		if player then
			manager.Emit("on_trigger_weapon_fired",player,{
				weapon = weapon,
				fireDir = fire_direction,
				fireAmount = fire_amount,
				owner = owner,
			})
		end
	end,
	})
end

return manager

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Chariot_r,
	own_key = "Thoth_cd7r_Cha_",
	MAX_SPEED = 17,
	ENEMY_DAMAGE_MUL = 20,
	WALL_DAMAGE_MUL = 40,
	HIT_COOLDOWN_FRAMES = 8, -- Game():GetFrameCount() 30Hz
	LAUNCH_FRAMES = 6, -- game frames
	BOUNCE_LAUNCH_FRAMES = 4,
	IMPACT_FRAMES = 8,
	BOUNCE_IMPACT_FRAMES = 4,
	FAILSAFE_FRAMES = 12 * 30, -- 12s hard failsafe only
	BOSS_SPEED_MUL = 0.75,
	BOSS_RECOVER_FRAMES = 6,
	TRAIL_INTERVAL = 3, -- game frames
	AFTERIMAGE_INTERVAL = 4,
	WALL_EXPLOSION_SCALE = 1.85,
}

local STATE_KEY = item.own_key .. "state"
local VISUAL_KEY = item.own_key .. "visual"

-- AIM：允许正常移动；Drop 用于取消，不得屏蔽
local AIM_BLOCK = {
	[ButtonAction.ACTION_BOMB] = true,
	[ButtonAction.ACTION_ITEM] = true,
	[ButtonAction.ACTION_PILLCARD] = true,
}

local FLIGHT_BLOCK = {
	[ButtonAction.ACTION_LEFT] = true,
	[ButtonAction.ACTION_RIGHT] = true,
	[ButtonAction.ACTION_UP] = true,
	[ButtonAction.ACTION_DOWN] = true,
	[ButtonAction.ACTION_SHOOTLEFT] = true,
	[ButtonAction.ACTION_SHOOTRIGHT] = true,
	[ButtonAction.ACTION_SHOOTUP] = true,
	[ButtonAction.ACTION_SHOOTDOWN] = true,
	[ButtonAction.ACTION_BOMB] = true,
	[ButtonAction.ACTION_ITEM] = true,
	[ButtonAction.ACTION_PILLCARD] = true,
	[ButtonAction.ACTION_DROP] = true,
}

local LAUNCH_SPEEDS = {4, 8, 12, 15, 17, 17}
local BOUNCE_SPEEDS = {8, 12, 15, 17}

local function game_frame()
	return Game():GetFrameCount()
end

local function get_state(player)
	return player:GetData()[STATE_KEY]
end

local function restore_visual(player)
	local d = player:GetData()
	local visual = d[VISUAL_KEY]
	if not visual then return end
	if visual.scale then
		player.SpriteScale = visual.scale
	end
	d[VISUAL_KEY] = nil
end

local function capture_visual(player)
	local d = player:GetData()
	if d[VISUAL_KEY] then return end
	d[VISUAL_KEY] = {
		scale = auxi.ProtectVector(player.SpriteScale),
	}
end

local function vector_to_head_direction(dir)
	if not dir or dir:Length() < 0.01 then
		return nil
	end
	if math.abs(dir.X) >= math.abs(dir.Y) then
		if dir.X >= 0 then
			return Direction.RIGHT
		end
		return Direction.LEFT
	end
	if dir.Y >= 0 then
		return Direction.DOWN
	end
	return Direction.UP
end

local function apply_flight_facing(player, state)
	if not state or not state.dir then
		return
	end
	if not player.SetHeadDirection then
		return
	end
	local head_dir = vector_to_head_direction(state.dir)
	if head_dir == nil then
		return
	end
	-- 短 Time + 每帧续锁；结束后自然失效，不在 clear_state 里快照恢复
	player:SetHeadDirection(head_dir, 2, true)
end

local function apply_flight_visual(player, state)
	capture_visual(player)
	local base = player:GetData()[VISUAL_KEY].scale or Vector.One
	local dir = state.dir or Vector(1, 0)
	local now = game_frame()
	local intensity = 0
	local phase = state.phase

	if phase == "launch" or phase == "bounce_launch" then
		-- 发射段短暂 squash/stretch，收尾回到原比例进入 Flight
		local elapsed = now - (state.phase_start or now)
		local total = math.max(1, (phase == "bounce_launch" and #BOUNCE_SPEEDS or #LAUNCH_SPEEDS) - 1)
		local t = math.min(1, elapsed / total)
		intensity = (1 - t) * (1 - t)
	elseif phase == "impact" then
		local elapsed = now - (state.phase_start or now)
		local need = state.impact_is_bounce and item.BOUNCE_IMPACT_FRAMES or item.IMPACT_FRAMES
		local t = math.min(1, elapsed / math.max(1, need))
		intensity = 1 - t
	elseif state.boss_slow_until and now < state.boss_slow_until then
		local remain = state.boss_slow_until - now
		local ratio = remain / math.max(1, item.BOSS_RECOVER_FRAMES)
		intensity = 0.55 * ratio
	end

	if intensity < 0.02 then
		player.SpriteScale = base
	else
		local ax = math.abs(dir.X)
		local ay = math.abs(dir.Y)
		local squash = 1 - 0.22 * intensity
		local stretch = 1 + 0.22 * intensity
		local sx, sy
		if ax >= ay then
			sx, sy = stretch, squash
		else
			sx, sy = squash, stretch
		end
		player.SpriteScale = Vector(base.X * sx, base.Y * sy)
	end
	apply_flight_facing(player, state)
end

local function clear_state(player)
	if not player then return end
	local d = player:GetData()
	local state = d[STATE_KEY]
	if state and state.holding_card and player.IsHoldingItem and player:IsHoldingItem() then
		player:AnimateCard(item.entity, "HideItem")
	end
	d[STATE_KEY] = nil
	restore_visual(player)
	player.Velocity = Vector.Zero
end

local function clear_all_players()
	for i = 0, Game():GetNumPlayers() - 1 do
		clear_state(Game():GetPlayer(i))
	end
end

local function spawn_poof(pos, scale, spawner)
	local e = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, pos, Vector.Zero, spawner)
	if e and scale then
		e.SpriteScale = Vector.One * scale
	end
	return e
end

local function spawn_dust(pos, spawner)
	local variant = EffectVariant.DUST_CLOUD or EffectVariant.POOF02 or EffectVariant.POOF01
	local e = Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, 0, pos, Vector.Zero, spawner)
	if e then
		e.SpriteScale = Vector.One * 0.55
	end
	return e
end

local function spawn_launch_effect(player, dir)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_ROCKET_LAUNCH_SHORT or SoundEffect.SOUND_EXPLOSION_WEAK, 1.1, 1.05, false, 0, 2)
	Game():ShakeScreen(8)
	local back = player.Position - dir * 18
	spawn_dust(back, player)
	spawn_poof(back, 0.7, player)
	spawn_poof(player.Position + dir * 12, 0.45, player)
	spawn_poof(player.Position - dir * 8, 0.5, player)
end

local function spawn_flight_effect(player, state)
	local now = game_frame()
	local dir = state.dir
	if (state.next_trail_frame or 0) <= now then
		state.next_trail_frame = now + item.TRAIL_INTERVAL
		spawn_dust(player.Position - dir * 14, player)
	end
	if (state.next_afterimage_frame or 0) <= now then
		state.next_afterimage_frame = now + item.AFTERIMAGE_INTERVAL
		local ghost = spawn_poof(player.Position - dir * 6, 0.35, player)
		if ghost then
			local s = ghost:GetSprite()
			s.Color = Color(1, 0.85, 0.55, 0.35, 0.1, 0.05, 0)
		end
	end
	-- 前方轻量风压（低频）
	if (state.next_nose_frame or 0) <= now then
		state.next_nose_frame = now + 5
		spawn_poof(player.Position + dir * 20, 0.28, player)
	end
end

local function spawn_enemy_impact(player, enemy, state)
	spawn_poof(enemy.Position, 0.55, player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_PUNCH, 0.85, 0.95, false, 0, 2)
end

local function spawn_wall_impact(player, state, heavy)
	local scale = heavy and item.WALL_EXPLOSION_SCALE or 1.45
	Game():BombExplosionEffects(
		player.Position,
		player.Damage * item.WALL_DAMAGE_MUL,
		BitSet128(0, 0),
		Color(1, 0.7, 0.25, 1),
		player,
		scale,
		false,
		false
	)
	Game():ShakeScreen(heavy and 16 or 12)
	spawn_dust(player.Position, player)
	spawn_poof(player.Position, 1.1, player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_ROCK_CRUMBLE, 1.1, 0.9, false, 0, 2)
end

local function begin_aim(player, bounce_charges)
	clear_state(player)
	local shoot = player:GetShootingInput()
	player:AnimateCard(item.entity, "LiftItem")
	player:GetData()[STATE_KEY] = {
		phase = "aim",
		dir = nil,
		speed = 0,
		max_speed = item.MAX_SPEED,
		bounce_left = bounce_charges or 0,
		hits = {},
		holding_card = true,
		-- 仅防使用瞬间仍按着射击立刻发射；移动不参与
		wait_release = shoot:Length() >= 0.15,
		start_frame = game_frame(),
		failsafe_until = game_frame() + item.FAILSAFE_FRAMES,
		last_safe_position = Vector(player.Position.X, player.Position.Y),
		trail_tick = 0,
	}
end

local function cancel_aim(player)
	local state = get_state(player)
	if not state or state.phase ~= "aim" then return end
	if player.IsHoldingItem and player:IsHoldingItem() then
		player:AnimateCard(item.entity, "HideItem")
	end
	state.holding_card = false
	clear_state(player)
	player:AddCard(item.entity)
end

local function get_aim_input(player, state)
	local shoot = player:GetShootingInput()
	if state.wait_release then
		if shoot:Length() < 0.12 then
			state.wait_release = false
		end
		return nil
	end
	if shoot:Length() < 0.35 then
		return nil
	end
	return shoot:Normalized()
end

local function begin_launch(player, dir, from_bounce)
	local state = get_state(player)
	if not state then return end
	if state.holding_card and player.IsHoldingItem and player:IsHoldingItem() then
		player:AnimateCard(item.entity, "HideItem")
	end
	state.holding_card = false
	state.phase = from_bounce and "bounce_launch" or "launch"
	state.dir = dir:Normalized()
	state.speed = 0
	state.phase_start = game_frame()
	state.last_safe_position = Vector(player.Position.X, player.Position.Y)
	capture_visual(player)
	apply_flight_visual(player, state)
	if not from_bounce then
		spawn_launch_effect(player, state.dir)
	else
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME, 1, 1.15, false, 0, 2)
		Game():ShakeScreen(6)
		spawn_poof(player.Position - state.dir * 10, 0.55, player)
	end
end

local function begin_flight(player, state)
	state.phase = "flight"
	state.speed = state.max_speed
	state.phase_start = game_frame()
	apply_flight_visual(player, state)
end

local function can_hit_enemy(state, enemy)
	local key = GetPtrHash(enemy)
	local until_frame = state.hits[key]
	if until_frame and until_frame > game_frame() then
		return false
	end
	return true
end

local function mark_enemy_hit(state, enemy)
	state.hits[GetPtrHash(enemy)] = game_frame() + item.HIT_COOLDOWN_FRAMES
end

local function hit_enemy(player, state, enemy)
	if not can_hit_enemy(state, enemy) then return end
	local npc = enemy:ToNPC()
	if not npc or not npc:IsVulnerableEnemy() then return end
	mark_enemy_hit(state, enemy)
	npc:TakeDamage(player.Damage * item.ENEMY_DAMAGE_MUL, DamageFlag.DAMAGE_CRUSH, EntityRef(player), 0)
	local is_boss = npc.IsBoss and npc:IsBoss()
	if is_boss then
		npc.Velocity = npc.Velocity + state.dir * 4
		state.speed = state.max_speed * item.BOSS_SPEED_MUL
		state.boss_slow_until = game_frame() + item.BOSS_RECOVER_FRAMES
		Game():ShakeScreen(4)
	else
		npc.Velocity = npc.Velocity + state.dir * 12
	end
	spawn_enemy_impact(player, npc, state)
end

local function break_grid_ahead(player, state)
	local room = Game():GetRoom()
	local probe = math.max(16, state.speed + 6)
	local np = player.Position + state.dir * probe
	local grid = room:GetGridEntityFromPos(np)
	if grid then
		grid:Destroy(true)
	end
	-- 近身再扫一遍，避免高速掠过
	local near = room:GetGridEntityFromPos(player.Position + state.dir * 8)
	if near then
		near:Destroy(true)
	end
end

local function wall_ahead(player, state)
	local room = Game():GetRoom()
	local probe = math.max(18, (state.speed or 0) + 8)
	local np = player.Position + state.dir * probe
	if not room:IsPositionInRoom(np, 4) then
		return true
	end
	local c = room:GetGridCollisionAtPos(np)
	return c == GridCollisionClass.COLLISION_WALL or c == GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
end

local function place_at_safe(player, state)
	local safe = state.last_safe_position or player.Position
	player.Position = Vector(safe.X, safe.Y)
	if state.dir then
		player.Position = player.Position - state.dir * 6
	end
	player.Velocity = Vector.Zero
end

local function begin_impact(player, state, is_bounce)
	place_at_safe(player, state)
	state.phase = "impact"
	state.phase_start = game_frame()
	state.impact_is_bounce = is_bounce and true or false
	state.speed = 0
	spawn_wall_impact(player, state, not is_bounce)
	apply_flight_visual(player, state)
end

local function begin_bounce(player, state)
	state.bounce_left = (state.bounce_left or 0) - 1
	state.hits = {}
	local dir = -(state.dir or Vector(1, 0))
	begin_launch(player, dir, true)
end

local function update_safe_position(player, state)
	local room = Game():GetRoom()
	local c = room:GetGridCollisionAtPos(player.Position)
	if room:IsPositionInRoom(player.Position, 2)
		and c ~= GridCollisionClass.COLLISION_WALL
		and c ~= GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER then
		state.last_safe_position = Vector(player.Position.X, player.Position.Y)
	end
end

local function update_speed_curve(state, table_speeds)
	local elapsed = game_frame() - (state.phase_start or game_frame())
	local idx = math.min(#table_speeds, elapsed + 1)
	state.speed = table_speeds[idx] or state.max_speed
	return elapsed >= (#table_speeds - 1)
end

local function apply_velocity(player, state)
	if state.boss_slow_until and game_frame() >= state.boss_slow_until then
		state.boss_slow_until = nil
		state.speed = state.max_speed
	end
	player.Velocity = state.dir * state.speed
end

local function update_aim(player, state)
	-- AIM 保留正常移动物理，不强制清 Velocity
	if not (player.IsHoldingItem and player:IsHoldingItem()) then
		player:AnimateCard(item.entity, "LiftItem")
	end
	if Input.IsActionTriggered(ButtonAction.ACTION_DROP, player.ControllerIndex) then
		cancel_aim(player)
		return
	end
	local dir = get_aim_input(player, state)
	if dir then
		begin_launch(player, dir, false)
	end
end

local function update_launch(player, state)
	local done = update_speed_curve(state, state.phase == "bounce_launch" and BOUNCE_SPEEDS or LAUNCH_SPEEDS)
	apply_flight_visual(player, state)
	apply_velocity(player, state)
	update_safe_position(player, state)
	spawn_flight_effect(player, state)
	break_grid_ahead(player, state)
	if wall_ahead(player, state) then
		local can_bounce = (state.bounce_left or 0) > 0
		begin_impact(player, state, can_bounce)
		return
	end
	for _, e in ipairs(Isaac.FindInRadius(player.Position, 34, EntityPartition.ENEMY)) do
		hit_enemy(player, state, e)
	end
	if done then
		begin_flight(player, state)
	end
end

local function update_flight(player, state)
	if state.boss_slow_until and game_frame() < state.boss_slow_until then
		-- 数帧内向 max_speed 回升
		local remain = state.boss_slow_until - game_frame()
		local t = 1 - (remain / item.BOSS_RECOVER_FRAMES)
		state.speed = state.max_speed * (item.BOSS_SPEED_MUL + (1 - item.BOSS_SPEED_MUL) * t)
	else
		state.speed = state.max_speed
	end
	apply_flight_visual(player, state)
	apply_velocity(player, state)
	update_safe_position(player, state)
	spawn_flight_effect(player, state)
	break_grid_ahead(player, state)
	if wall_ahead(player, state) then
		local can_bounce = (state.bounce_left or 0) > 0
		begin_impact(player, state, can_bounce)
		return
	end
	for _, e in ipairs(Isaac.FindInRadius(player.Position, 34, EntityPartition.ENEMY)) do
		hit_enemy(player, state, e)
	end
end

local function update_impact(player, state)
	player.Velocity = Vector.Zero
	apply_flight_visual(player, state)
	local elapsed = game_frame() - (state.phase_start or game_frame())
	local need = state.impact_is_bounce and item.BOUNCE_IMPACT_FRAMES or item.IMPACT_FRAMES
	if elapsed < need then
		return
	end
	if state.impact_is_bounce then
		begin_bounce(player, state)
	else
		clear_state(player)
	end
end

table.insert(item.myToCall, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	Function = function()
		clear_all_players()
	end,
})

table.insert(item.myToCall, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	Function = function()
		clear_all_players()
	end,
})

table.insert(item.myToCall, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	Function = function()
		clear_all_players()
	end,
})

table.insert(item.pre_ToCall, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = EntityType.ENTITY_PLAYER,
	Function = function(_, ent)
		local player = ent:ToPlayer()
		if not player then return end
		local state = get_state(player)
		if not state then return end
		if state.phase == "launch" or state.phase == "bounce_launch"
			or state.phase == "flight" or state.phase == "impact" then
			return false
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_INPUT_ACTION,
	Function = function(_, ent, hook, button)
		if ent == nil then return end
		local player = ent:ToPlayer()
		if not player then return end
		local state = get_state(player)
		if not state then return end
		local blocked
		if state.phase == "aim" then
			blocked = AIM_BLOCK
		elseif state.phase == "launch" or state.phase == "bounce_launch"
			or state.phase == "flight" or state.phase == "impact" then
			blocked = FLIGHT_BLOCK
		else
			return
		end
		if not blocked[button] then return end
		if hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED then
			return false
		elseif hook == InputHook.GET_ACTION_VALUE then
			return 0
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	Function = function(_, player)
		local state = get_state(player)
		if not state then return end
		if not auxi.check_all_exists(player) or player:IsDead() then
			clear_state(player)
			return
		end
		-- Failsafe：仅异常兜底，不作为正常结束
		if game_frame() >= (state.failsafe_until or 0) and state.phase ~= "aim" then
			clear_state(player)
			return
		end

		if state.phase == "aim" then
			update_aim(player, state)
		elseif state.phase == "launch" or state.phase == "bounce_launch" then
			update_launch(player, state)
		elseif state.phase == "flight" then
			update_flight(player, state)
		elseif state.phase == "impact" then
			update_impact(player, state)
		else
			clear_state(player)
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = item.entity,
	Function = function(_, card, player, flags)
		if flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			return
		end
		local bounce = 0
		if player:GetData().tarot_cloth_used and player:GetData().tarot_cloth_used == card then
			bounce = 1
		end
		begin_aim(player, bounce)
	end,
})

return item

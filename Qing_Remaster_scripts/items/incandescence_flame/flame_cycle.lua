-- 蓄力采样在 MC_POST_PLAYER_UPDATE（60 Hz）：240 帧 = 4 秒。
-- 喷火与直接伤害在 MC_POST_UPDATE（30 Hz）：90 帧 = 3 秒，每 6 帧 = 0.2 秒。

local cycle = {}

cycle.CHARGE_FRAMES = 240
cycle.FIRE_FRAMES = 90
cycle.HIT_INTERVAL = 6
cycle.HIT_SCALE = 0.5
cycle.BURN_FRAMES = 43
cycle.BURN_SCALE = 0.25

function cycle.blank()
	return {
		charge = 0,
		phase = "charge",
		fire_left = 0,
		dir_x = 1,
		dir_y = 0,
		has_dir = false,
		attack_held = false,
		release_pending = false,
		spray = 0,
		hit_clock = 0,
		burned = {},
	}
end

local function unit(x, y)
	local len = math.sqrt(x * x + y * y)
	if len < 0.0001 then
		return nil
	end
	return x / len, y / len
end

function cycle.sample_input(st, held, ax, ay)
	held = held == true
	local was_held = st.attack_held == true
	local ux, uy = unit(ax or 0, ay or 0)
	if held and ux then
		st.dir_x = ux
		st.dir_y = uy
		st.has_dir = true
	end
	if st.phase == "charge" then
		if held then
			st.charge = math.min(cycle.CHARGE_FRAMES, (st.charge or 0) + 1)
			if st.charge >= cycle.CHARGE_FRAMES then
				st.phase = "ready"
				st.charge = cycle.CHARGE_FRAMES
			end
		elseif was_held then
			st.charge = 0
		end
	elseif st.phase == "ready" then
		if held then
			st.release_pending = false
		elseif was_held then
			st.release_pending = true
		end
	end
	st.attack_held = held
end

function cycle.step(st, can_start)
	if can_start == nil then
		can_start = true
	end
	local flags = { start = false, stop = false, hit = false }
	if st.phase == "ready" and st.release_pending and can_start then
		st.release_pending = false
		st.phase = "fire"
		st.fire_left = cycle.FIRE_FRAMES
		st.spray = (st.spray or 0) + 1
		st.hit_clock = 0
		st.burned = {}
		flags.start = true
	end
	if st.phase == "fire" or st.phase == "fade" then
		st.hit_clock = (st.hit_clock or 0) + 1
		if st.hit_clock >= cycle.HIT_INTERVAL then
			st.hit_clock = 0
			flags.hit = true
		end
	end
	if st.phase == "fire" then
		st.fire_left = (st.fire_left or 0) - 1
		if st.fire_left <= 0 then
			st.phase = "fade"
			flags.stop = true
		end
	end
	return flags
end

function cycle.note_idle(st, idle)
	if idle and st.phase == "fade" then
		st.phase = "charge"
		st.charge = 0
		st.fire_left = 0
		st.hit_clock = 0
		return true
	end
	return false
end

function cycle.on_room(st)
	st.attack_held = false
	st.release_pending = false
	if st.phase == "fire" or st.phase == "fade" then
		st.phase = "charge"
		st.charge = 0
		st.fire_left = 0
		st.hit_clock = 0
		st.burned = {}
		return true
	end
	return false
end

function cycle.mark_burn(st, key)
	st.burned = st.burned or {}
	if st.burned[key] then
		return false
	end
	st.burned[key] = true
	return true
end

return cycle

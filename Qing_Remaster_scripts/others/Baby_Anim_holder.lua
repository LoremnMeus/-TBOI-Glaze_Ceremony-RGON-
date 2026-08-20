-- Shared float/idle timing for Qing sin babies.
local holder = {}

local function rand_between(rng, min_v, max_v)
	min_v = math.floor(min_v)
	max_v = math.floor(max_v)
	if max_v < min_v then min_v, max_v = max_v, min_v end
	if max_v <= min_v then return min_v end
	return min_v + rng:RandomInt(max_v - min_v + 1)
end

function holder.is_float_idle_anim(anim, opts)
	opts = opts or {}
	local float_name = opts.float_anim or "Float"
	local idle_name = opts.idle_anim or "Idle"
	return anim == float_name or anim == idle_name
end

function holder.reset(ent, data_key)
	ent:GetData()[data_key] = nil
end

-- Alternate Float and Idle so babies do not bob forever.
-- Returns true while the familiar is in float/idle rest poses.
function holder.tick_float_idle(ent, data_key, opts)
	opts = opts or {}
	local s = ent:GetSprite()
	local d = ent:GetData()
	local anim = s:GetAnimation()
	local float_name = opts.float_anim or "Float"
	local idle_name = opts.idle_anim or "Idle"
	if opts.locked and opts.locked[anim] then
		return false
	end
	if anim ~= float_name and anim ~= idle_name then
		-- Special animation in progress; leave it alone.
		return false
	end

	local st = d[data_key]
	local rng = ent:GetDropRNG()
	if type(st) ~= "table" or st.float_idle ~= true then
		st = {
			float_idle = true,
			mode = "float",
			timer = rand_between(rng, opts.float_min or 36, opts.float_max or 84),
		}
		d[data_key] = st
		if anim ~= float_name then
			s:Play(float_name, true)
		end
		return true
	end

	st.timer = (st.timer or 0) - 1
	if st.timer <= 0 then
		if st.mode == "float" then
			st.mode = "idle"
			st.timer = rand_between(rng, opts.idle_min or 24, opts.idle_max or 72)
			s:Play(idle_name, true)
		else
			st.mode = "float"
			st.timer = rand_between(rng, opts.float_min or 36, opts.float_max or 84)
			s:Play(float_name, true)
		end
	else
		if st.mode == "float" and anim ~= float_name then
			s:Play(float_name, true)
		elseif st.mode == "idle" and anim ~= idle_name then
			s:Play(idle_name, true)
		end
	end
	return true
end

return holder

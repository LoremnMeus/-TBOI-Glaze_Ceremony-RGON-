-- Aeon? Continue Save compact codec.
-- Runtime / Replay keep full record.frames / record.attacks.
-- Only finish_recording → pack, Continue → unpack.

local json = require("json")
local room_space = require("Qing_Remaster_scripts.others.room_space_mapper")

local M = {}

M.PACK_VERSION = 6
M.RUNTIME_SCHEMA_VERSION = 4

local POS_Q = 4
local VEL_Q = 100
local HEIGHT_Q = 100
local FALL_SPD_Q = 1000
local LASER_SCALE_Q = 1000
local DAMAGE_MUL_Q = 1000
local AIM_DIR_Q = 1000

local function iround(x)
	return math.floor((tonumber(x) or 0) + 0.5)
end

local function quantize(x, scale)
	return iround((tonumber(x) or 0) * scale)
end

local function dequantize(q, scale)
	return (tonumber(q) or 0) / scale
end

local function num_eq(a, b)
	return (tonumber(a) or 0) == (tonumber(b) or 0)
end

local function flags_eq(a, b)
	if a == b then return true end
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	return (tonumber(a[1]) or 0) == (tonumber(b[1]) or 0)
		and (tonumber(a[2]) or 0) == (tonumber(b[2]) or 0)
end

local function color_eq(a, b)
	if a == b then return true end
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	local keys = {"r", "g", "b", "a", "ro", "go", "bo", "cz_r", "cz_g", "cz_b", "cz_a"}
	for i = 1, #keys do
		local k = keys[i]
		if not num_eq(a[k], b[k]) then
			return false
		end
	end
	return true
end

local function copy_color(c)
	if type(c) ~= "table" then return nil end
	return {
		r = c.r, g = c.g, b = c.b, a = c.a,
		ro = c.ro, go = c.go, bo = c.bo,
		cz_r = c.cz_r, cz_g = c.cz_g, cz_b = c.cz_b, cz_a = c.cz_a,
	}
end

local function copy_flags(f)
	if type(f) ~= "table" then return f end
	return {tonumber(f[1]) or 0, tonumber(f[2]) or 0}
end

--- Flatten legacy dual tear payload (payload.* + payload.tear.*) into one table.
function M.normalize_tear_payload(payload)
	payload = type(payload) == "table" and payload or {}
	local nested = type(payload.tear) == "table" and payload.tear or nil
	local out = {
		type = payload.type,
		variant = (nested and nested.variant) or payload.variant,
		subtype = payload.subtype,
		damage = (nested and nested.damage) or payload.damage or payload.collision_damage,
		flags = (nested and nested.flags) or payload.flags or payload.tear_flags,
		scale = (nested and nested.scale) or payload.scale,
		sprite_scale = payload.sprite_scale or (nested and nested.sprite_scale),
		height = (nested and nested.height) or payload.height,
		falling_speed = (nested and nested.falling_speed) or payload.falling_speed,
		falling_accel = (nested and nested.falling_accel)
			or payload.falling_accel
			or payload.falling_acceleration,
		color = (nested and nested.color) or payload.color,
		velocity = (nested and nested.velocity) or payload.velocity,
		mass = payload.mass,
		timeout = payload.timeout,
		sprite_rotation = payload.sprite_rotation,
	}
	return out
end

function M.is_packed(data)
	return type(data) == "table"
		and tonumber(data.v) == M.PACK_VERSION
		and type(data.f) == "table"
		and data.frames == nil
end

local function pack_frames(frames, length)
	length = tonumber(length) or 0
	local p = {}
	local d = {}
	local d_index = {}
	local a = {}
	local af = {}
	local o = {}
	local of = {}
	local fx = {}

	local function dict_id(name)
		if type(name) ~= "string" or name == "" then
			return 0
		end
		local id = d_index[name]
		if id then return id end
		id = #d + 1
		d[id] = name
		d_index[name] = id
		return id
	end

	local last_anim = nil
	local last_overlay = nil
	local last_flip = nil
	local last_of = nil
	local of_run = 0
	local qx_prev, qy_prev

	for t = 0, length - 1 do
		local fs = frames[t] or {}
		local qx = quantize(fs.x, POS_Q)
		local qy = quantize(fs.y, POS_Q)
		if t == 0 then
			p[#p + 1] = qx
			p[#p + 1] = qy
		else
			p[#p + 1] = qx - (qx_prev or 0)
			p[#p + 1] = qy - (qy_prev or 0)
		end
		qx_prev, qy_prev = qx, qy

		af[#af + 1] = tonumber(fs.anim_frame) or 0

		local anim = fs.anim or "WalkDown"
		if anim ~= last_anim then
			a[#a + 1] = t
			a[#a + 1] = dict_id(anim)
			last_anim = anim
		end

		local oid = 0
		if type(fs.overlay_anim) == "string" and fs.overlay_anim ~= "" then
			oid = dict_id(fs.overlay_anim)
		end
		if last_overlay == nil or oid ~= last_overlay then
			o[#o + 1] = t
			o[#o + 1] = oid
			last_overlay = oid
		end

		local ofv = tonumber(fs.overlay_frame) or 0
		if last_of == nil then
			last_of = ofv
			of_run = 1
		elseif ofv == last_of then
			of_run = of_run + 1
		else
			of[#of + 1] = of_run
			of[#of + 1] = last_of
			last_of = ofv
			of_run = 1
		end

		local flip = fs.flip_x and true or false
		if last_flip == nil then
			last_flip = flip
			if flip then
				fx[#fx + 1] = t
				fx[#fx + 1] = 1
			end
		elseif flip ~= last_flip then
			fx[#fx + 1] = t
			fx[#fx + 1] = flip and 1 or 0
			last_flip = flip
		end
	end

	if of_run > 0 then
		of[#of + 1] = of_run
		of[#of + 1] = last_of or 0
	end

	-- Layer override streams: only slots that ever diverge from standard clocks
	local lo_by_slot = {}
	local lo_slot_order = {}
	for t = 0, length - 1 do
		local fs = frames[t] or {}
		local ov_table = fs.layer_overrides
		if type(ov_table) == "table" then
			for slot_key, ov in pairs(ov_table) do
				if type(slot_key) == "string" and type(ov) == "table" then
					local bucket = lo_by_slot[slot_key]
					if not bucket then
						bucket = { frames = {} }
						lo_by_slot[slot_key] = bucket
						lo_slot_order[#lo_slot_order + 1] = slot_key
					end
					bucket.frames[t] = ov
				end
			end
		end
	end

	local lo = nil
	if #lo_slot_order > 0 then
		lo = {}
		for i = 1, #lo_slot_order do
			local slot_key = lo_slot_order[i]
			local bucket = lo_by_slot[slot_key]
			local active = {}
			local t = 0
			while t < length do
				if bucket.frames[t] then
					local start = t
					while t < length and bucket.frames[t] do
						t = t + 1
					end
					active[#active + 1] = start
					active[#active + 1] = t - start
				else
					t = t + 1
				end
			end
			if #active > 0 then
				local a_ov = {}
				local af_ov = {}
				local o_ov = {}
				local of_ov = {}
				local fx_ov = {}
				local last_anim = nil
				local last_overlay = nil
				local last_flip = nil
				local has_flip = false
				for ri = 1, #active, 2 do
					local start = active[ri]
					local len = active[ri + 1]
					for dt = 0, len - 1 do
						local ft = start + dt
						local ov = bucket.frames[ft] or {}
						local anim = ov.anim or ""
						if anim ~= last_anim then
							a_ov[#a_ov + 1] = ft
							a_ov[#a_ov + 1] = dict_id(anim)
							last_anim = anim
						end
						af_ov[#af_ov + 1] = tonumber(ov.frame) or 0
						local oid = 0
						local want_ov = ov.has_overlay == true
							or (ov.has_overlay == nil and type(ov.overlay_anim) == "string" and ov.overlay_anim ~= "")
						if want_ov and type(ov.overlay_anim) == "string" and ov.overlay_anim ~= "" then
							oid = dict_id(ov.overlay_anim)
						end
						if last_overlay == nil or oid ~= last_overlay then
							o_ov[#o_ov + 1] = ft
							o_ov[#o_ov + 1] = oid
							last_overlay = oid
						end
						of_ov[#of_ov + 1] = tonumber(ov.overlay_frame) or 0
						if ov.flip_x ~= nil then
							has_flip = true
							local flip = ov.flip_x and true or false
							if last_flip == nil or flip ~= last_flip then
								fx_ov[#fx_ov + 1] = ft
								fx_ov[#fx_ov + 1] = flip and 1 or 0
								last_flip = flip
							end
						end
					end
				end
				local entry = {
					s = slot_key,
					r = active,
					a = a_ov,
					af = af_ov,
					-- Always pack overlay stream so "no overlay" can clear charge leftovers.
					o = o_ov,
					of = of_ov,
				}
				if has_flip and #fx_ov > 0 then
					entry.fx = fx_ov
				end
				-- Slot-level head_main: costume head sprite uses main anim as head clock.
				local slot_hm = false
				for ri = 1, #active, 2 do
					local start = active[ri]
					local len = active[ri + 1]
					for dt = 0, len - 1 do
						local ov = bucket.frames[start + dt]
						if type(ov) == "table" and ov.head_main == true then
							slot_hm = true
							break
						end
					end
					if slot_hm then break end
				end
				if slot_hm then
					entry.hm = true
				end
				lo[#lo + 1] = entry
			end
		end
	end

	local out = {
		p = p,
		d = d,
		a = a,
		af = af,
		o = o,
		of = of,
	}
	if #fx > 0 then
		out.fx = fx
	end
	if lo and #lo > 0 then
		out.lo = lo
	end

	-- Optional character_pose stream (v6): sparse canvas-relative aim targets / aim dirs.
	-- e = {t, qx, qy, ...} target_x/y; a = {t, ax, ay, ...} aim_x/y when no target.
	local cp_e = {}
	local cp_a = {}
	for t = 0, length - 1 do
		local fs = frames[t] or {}
		local pose = fs.character_pose
		if type(pose) == "table" then
			local tx = tonumber(pose.target_x)
			local ty = tonumber(pose.target_y)
			if tx ~= nil and ty ~= nil then
				cp_e[#cp_e + 1] = t
				cp_e[#cp_e + 1] = quantize(tx, POS_Q)
				cp_e[#cp_e + 1] = quantize(ty, POS_Q)
			else
				local ax = tonumber(pose.aim_x)
				local ay = tonumber(pose.aim_y)
				if ax ~= nil and ay ~= nil then
					cp_a[#cp_a + 1] = t
					cp_a[#cp_a + 1] = quantize(ax, AIM_DIR_Q)
					cp_a[#cp_a + 1] = quantize(ay, AIM_DIR_Q)
				end
			end
		end
	end
	if #cp_e > 0 or #cp_a > 0 then
		out.cp = {}
		if #cp_e > 0 then out.cp.e = cp_e end
		if #cp_a > 0 then out.cp.a = cp_a end
	end
	return out
end

local function unpack_frames(f, length)
	length = tonumber(length) or 0
	f = type(f) == "table" and f or {}
	local frames = {}
	local dict = type(f.d) == "table" and f.d or {}
	local p = type(f.p) == "table" and f.p or {}
	local a = type(f.a) == "table" and f.a or {}
	local af = type(f.af) == "table" and f.af or {}
	local o = type(f.o) == "table" and f.o or {}
	local of = type(f.of) == "table" and f.of or {}
	local fx = type(f.fx) == "table" and f.fx or {}

	local function dict_name(id)
		id = tonumber(id) or 0
		if id <= 0 then return nil end
		return dict[id]
	end

	local overlay_frames = {}
	local cursor = 0
	for i = 1, #of, 2 do
		local count = tonumber(of[i]) or 0
		local value = tonumber(of[i + 1]) or 0
		for _ = 1, count do
			overlay_frames[cursor] = value
			cursor = cursor + 1
		end
	end

	local qx, qy = 0, 0
	local cur_anim = "WalkDown"
	local cur_overlay = nil
	local cur_flip = false
	local next_ai, next_oi, next_fi = 1, 1, 1

	for t = 0, length - 1 do
		if t == 0 then
			qx = tonumber(p[1]) or 0
			qy = tonumber(p[2]) or 0
		else
			local base = t * 2 + 1
			qx = qx + (tonumber(p[base]) or 0)
			qy = qy + (tonumber(p[base + 1]) or 0)
		end

		while next_ai <= #a and (tonumber(a[next_ai]) or -1) == t do
			cur_anim = dict_name(a[next_ai + 1]) or "WalkDown"
			next_ai = next_ai + 2
		end
		while next_oi <= #o and (tonumber(o[next_oi]) or -1) == t do
			local id = tonumber(o[next_oi + 1]) or 0
			cur_overlay = id > 0 and dict_name(id) or nil
			next_oi = next_oi + 2
		end
		while next_fi <= #fx and (tonumber(fx[next_fi]) or -1) == t do
			cur_flip = (tonumber(fx[next_fi + 1]) or 0) ~= 0
			next_fi = next_fi + 2
		end

		frames[t] = {
			x = dequantize(qx, POS_Q),
			y = dequantize(qy, POS_Q),
			anim = cur_anim,
			anim_frame = tonumber(af[t + 1]) or 0,
			overlay_anim = cur_overlay,
			overlay_frame = overlay_frames[t] or 0,
			flip_x = cur_flip,
		}
	end

	-- Restore sparse layer overrides from f.lo
	local lo = type(f.lo) == "table" and f.lo or nil
	if lo then
		for i = 1, #lo do
			local entry = lo[i]
			if type(entry) == "table" and type(entry.s) == "string" and type(entry.r) == "table" then
				local slot_key = entry.s
				local a_ov = type(entry.a) == "table" and entry.a or {}
				local af_ov = type(entry.af) == "table" and entry.af or {}
				local o_ov = type(entry.o) == "table" and entry.o or {}
				local of_ov = type(entry.of) == "table" and entry.of or {}
				local fx_ov = type(entry.fx) == "table" and entry.fx or {}
				local cur_oanim = nil
				local next_ai, next_oi, next_fi = 1, 1, 1
				local cur_anim_name = nil
				local cur_flip = nil
				local af_i = 1
				local r = entry.r
				local has_of = type(entry.of) == "table"
				local has_o = type(entry.o) == "table" and #entry.o > 0
				for ri = 1, #r, 2 do
					local start = tonumber(r[ri]) or 0
					local len = tonumber(r[ri + 1]) or 0
					for dt = 0, len - 1 do
						local t = start + dt
						while next_ai <= #a_ov and (tonumber(a_ov[next_ai]) or -1) == t do
							cur_anim_name = dict_name(a_ov[next_ai + 1])
							next_ai = next_ai + 2
						end
						while next_oi <= #o_ov and (tonumber(o_ov[next_oi]) or -1) == t do
							local id = tonumber(o_ov[next_oi + 1]) or 0
							cur_oanim = id > 0 and dict_name(id) or nil
							next_oi = next_oi + 2
						end
						while next_fi <= #fx_ov and (tonumber(fx_ov[next_fi]) or -1) == t do
							cur_flip = (tonumber(fx_ov[next_fi + 1]) or 0) ~= 0
							next_fi = next_fi + 2
						end
						local ov = {
							anim = cur_anim_name,
							frame = tonumber(af_ov[af_i]) or 0,
						}
						if entry.hm == true then
							ov.head_main = true
						end
						if has_o or has_of then
							if cur_oanim then
								ov.has_overlay = true
								ov.overlay_anim = cur_oanim
								ov.overlay_frame = tonumber(of_ov[af_i]) or 0
							else
								ov.has_overlay = false
							end
						end
						af_i = af_i + 1
						if cur_flip ~= nil then
							ov.flip_x = cur_flip
						end
						local fs = frames[t]
						if fs then
							fs.layer_overrides = fs.layer_overrides or {}
							fs.layer_overrides[slot_key] = ov
						end
					end
				end
			end
		end
	end

	-- Restore optional character_pose (v6+; absent on older packs).
	local cp = type(f.cp) == "table" and f.cp or nil
	if cp then
		local e = type(cp.e) == "table" and cp.e or nil
		if e then
			for i = 1, #e, 3 do
				local t = tonumber(e[i])
				if t ~= nil and frames[t] then
					frames[t].character_pose = {
						target_x = dequantize(e[i + 1], POS_Q),
						target_y = dequantize(e[i + 2], POS_Q),
					}
				end
			end
		end
		local a_pose = type(cp.a) == "table" and cp.a or nil
		if a_pose then
			for i = 1, #a_pose, 3 do
				local t = tonumber(a_pose[i])
				if t ~= nil and frames[t] then
					local pose = frames[t].character_pose
					if type(pose) ~= "table" then
						pose = {}
						frames[t].character_pose = pose
					end
					if pose.target_x == nil then
						pose.aim_x = dequantize(a_pose[i + 1], AIM_DIR_Q)
						pose.aim_y = dequantize(a_pose[i + 2], AIM_DIR_Q)
					end
				end
			end
		end
	end

	return frames
end

local function tear_template_from_payload(payload)
	local ss = type(payload.sprite_scale) == "table" and payload.sprite_scale or nil
	return {
		k = "tear",
		ty = tonumber(payload.type),
		va = tonumber(payload.variant) or 0,
		su = tonumber(payload.subtype) or 0,
		dm = tonumber(payload.damage) or 0,
		fl = copy_flags(payload.flags),
		sc = tonumber(payload.scale) or 1,
		ssx = ss and tonumber(ss.x) or nil,
		ssy = ss and tonumber(ss.y) or nil,
		co = copy_color(payload.color),
		ms = tonumber(payload.mass),
		fa = tonumber(payload.falling_accel),
		sr = tonumber(payload.sprite_rotation),
		to = tonumber(payload.timeout),
	}
end

local function tear_template_eq(a, b)
	if not a or not b then return false end
	return a.k == b.k
		and num_eq(a.ty, b.ty)
		and num_eq(a.va, b.va)
		and num_eq(a.su, b.su)
		and num_eq(a.dm, b.dm)
		and flags_eq(a.fl, b.fl)
		and num_eq(a.sc, b.sc)
		and num_eq(a.ssx, b.ssx)
		and num_eq(a.ssy, b.ssy)
		and color_eq(a.co, b.co)
		and num_eq(a.ms, b.ms)
		and num_eq(a.fa, b.fa)
		and num_eq(a.sr, b.sr)
		and num_eq(a.to, b.to)
end

local function generic_template_from_entry(entry)
	local payload = type(entry.payload) == "table" and entry.payload or {}
	local copy = {}
	for k, v in pairs(payload) do
		if k ~= "velocity" and k ~= "tear" then
			copy[k] = v
		end
	end
	return {
		k = entry.kind or "generic",
		fm = entry.family,
		pl = copy,
	}
end

local function pack_attacks(attacks)
	local templates = {}
	local events = {}
	attacks = type(attacks) == "table" and attacks or {}

	for i = 1, #attacks do
		local entry = attacks[i]
		if type(entry) == "table" then
			local kind = entry.kind or "generic"
			local frame = tonumber(entry.frame) or 0
			local offset = type(entry.offset) == "table" and entry.offset or {}
			local payload = type(entry.payload) == "table" and entry.payload or {}

			if kind == "tear" then
				payload = M.normalize_tear_payload(payload)
				local tmpl = tear_template_from_payload(payload)
				local tid = nil
				for ti = 1, #templates do
					if tear_template_eq(templates[ti], tmpl) then
						tid = ti
						break
					end
				end
				if not tid then
					templates[#templates + 1] = tmpl
					tid = #templates
				end
				local vel = type(payload.velocity) == "table" and payload.velocity or {}
				-- flat: frame, tid, ox, oy, vx, vy, height, falling_speed
				events[#events + 1] = frame
				events[#events + 1] = tid
				events[#events + 1] = quantize(offset.x, POS_Q)
				events[#events + 1] = quantize(offset.y, POS_Q)
				events[#events + 1] = quantize(vel.x, VEL_Q)
				events[#events + 1] = quantize(vel.y, VEL_Q)
				events[#events + 1] = quantize(payload.height, HEIGHT_Q)
				events[#events + 1] = quantize(payload.falling_speed, FALL_SPD_Q)
			else
				local tmpl = generic_template_from_entry(entry)
				templates[#templates + 1] = tmpl
				local tid = #templates
				local vel = type(payload.velocity) == "table" and payload.velocity or {}
				-- generic stride same header + marker 0 height/fall unused
				events[#events + 1] = frame
				events[#events + 1] = tid
				events[#events + 1] = quantize(offset.x, POS_Q)
				events[#events + 1] = quantize(offset.y, POS_Q)
				events[#events + 1] = quantize(vel.x, VEL_Q)
				events[#events + 1] = quantize(vel.y, VEL_Q)
				events[#events + 1] = 0
				events[#events + 1] = 0
			end
		end
	end

	return templates, events
end

local function unpack_attacks(templates, events)
	templates = type(templates) == "table" and templates or {}
	events = type(events) == "table" and events or {}
	local attacks = {}
	local seq = 0

	for i = 1, #events, 8 do
		local frame = tonumber(events[i]) or 0
		local tid = tonumber(events[i + 1]) or 0
		local ox = dequantize(events[i + 2], POS_Q)
		local oy = dequantize(events[i + 3], POS_Q)
		local vx = dequantize(events[i + 4], VEL_Q)
		local vy = dequantize(events[i + 5], VEL_Q)
		local height = dequantize(events[i + 6], HEIGHT_Q)
		local falling_speed = dequantize(events[i + 7], FALL_SPD_Q)
		local tmpl = templates[tid]
		if tmpl then
			seq = seq + 1
			if tmpl.k == "tear" then
				local sprite_scale = nil
				if tmpl.ssx ~= nil or tmpl.ssy ~= nil then
					sprite_scale = {x = tonumber(tmpl.ssx) or 1, y = tonumber(tmpl.ssy) or 1}
				end
				attacks[#attacks + 1] = {
					family = "tear",
					kind = "tear",
					mode = "snapshot",
					frame = frame,
					sequence = seq,
					offset = {x = ox, y = oy},
					payload = {
						type = tmpl.ty,
						variant = tmpl.va,
						subtype = tmpl.su,
						damage = tmpl.dm,
						flags = copy_flags(tmpl.fl),
						scale = tmpl.sc,
						sprite_scale = sprite_scale,
						height = height,
						falling_speed = falling_speed,
						falling_accel = tmpl.fa,
						color = copy_color(tmpl.co),
						velocity = {x = vx, y = vy},
						mass = tmpl.ms,
						timeout = tmpl.to,
						sprite_rotation = tmpl.sr,
					},
				}
			else
				local payload = {}
				local src = type(tmpl.pl) == "table" and tmpl.pl or {}
				for k, v in pairs(src) do
					payload[k] = v
				end
				payload.velocity = {x = vx, y = vy}
				attacks[#attacks + 1] = {
					family = tmpl.fm or tmpl.k,
					kind = tmpl.k or "generic",
					frame = frame,
					sequence = seq,
					offset = {x = ox, y = oy},
					payload = payload,
				}
			end
		end
	end

	return attacks
end

local function pack_played_rooms(played)
	local r = {}
	if type(played) ~= "table" then return r end
	for key, value in pairs(played) do
		if value == true then
			local n = tonumber(key)
			if n ~= nil then
				r[#r + 1] = n
			else
				r[#r + 1] = tostring(key)
			end
		end
	end
	table.sort(r, function(a, b)
		local na, nb = tonumber(a), tonumber(b)
		if na and nb then return na < nb end
		return tostring(a) < tostring(b)
	end)
	return r
end

local function unpack_played_rooms(r)
	local played = {}
	if type(r) ~= "table" then return played end
	for i = 1, #r do
		played[tostring(r[i])] = true
	end
	return played
end

local ANGLE_Q = 100
local PATH_Q = 100

local function pack_xy_delta_stream(states, get_x, get_y)
	local p = {}
	local qx_prev, qy_prev
	for i = 1, #states do
		local st = states[i] or {}
		local qx = quantize(get_x(st), POS_Q)
		local qy = quantize(get_y(st), POS_Q)
		if i == 1 then
			p[#p + 1] = qx
			p[#p + 1] = qy
		else
			p[#p + 1] = qx - (qx_prev or 0)
			p[#p + 1] = qy - (qy_prev or 0)
		end
		qx_prev, qy_prev = qx, qy
	end
	return p
end

local function unpack_xy_delta_stream(p, n)
	local out = {}
	p = type(p) == "table" and p or {}
	local qx, qy = 0, 0
	for i = 1, n do
		if i == 1 then
			qx = tonumber(p[1]) or 0
			qy = tonumber(p[2]) or 0
		else
			local base = (i - 1) * 2 + 1
			qx = qx + (tonumber(p[base]) or 0)
			qy = qy + (tonumber(p[base + 1]) or 0)
		end
		out[i] = {x = dequantize(qx, POS_Q), y = dequantize(qy, POS_Q)}
	end
	return out
end

local function pack_change_events(states, get_v, scale, is_bool)
	local ev = {}
	local last = nil
	for i = 1, #states do
		local v = get_v(states[i] or {})
		local q
		if is_bool then
			q = v and 1 or 0
		elseif scale then
			q = quantize(v, scale)
		else
			q = tonumber(v) or 0
		end
		if last == nil or q ~= last then
			ev[#ev + 1] = i - 1
			ev[#ev + 1] = q
			last = q
		end
	end
	return ev
end

local function apply_change_events(n, ev, scale, is_bool)
	local values = {}
	ev = type(ev) == "table" and ev or {}
	local cur = is_bool and false or 0
	local next_i = 1
	for i = 0, n - 1 do
		while next_i <= #ev and (tonumber(ev[next_i]) or -1) == i do
			local q = tonumber(ev[next_i + 1]) or 0
			if is_bool then
				cur = q ~= 0
			elseif scale then
				cur = dequantize(q, scale)
			else
				cur = q
			end
			next_i = next_i + 2
		end
		values[i + 1] = cur
	end
	return values
end

local function pack_one_track(tr)
	local states = type(tr.states) == "table" and tr.states or {}
	local n = #states
	local packed = {
		k = tr.kind,
		fm = tr.family,
		sf = tonumber(tr.start_frame) or 0,
		ef = tonumber(tr.end_frame) or tonumber(tr.start_frame) or 0,
		n = n,
		b = tr.base,
		p = pack_xy_delta_stream(states, function(s) return s.ox end, function(s) return s.oy end),
	}
	local po_dynamic = tr.kind == "laser" and type(tr.base) == "table" and tr.base.po_dynamic == true
	if po_dynamic then
		packed.pp = pack_xy_delta_stream(states, function(s)
			return s.dynamic_pox ~= nil and s.dynamic_pox or s.pox
		end, function(s)
			return s.dynamic_poy ~= nil and s.dynamic_poy or s.poy
		end)
		packed.pd = 1
	elseif tr.kind ~= "laser" then
		-- Knife/sword still use per-frame PositionOffset when present.
		packed.pp = pack_xy_delta_stream(states, function(s) return s.pox end, function(s) return s.poy end)
	end
	-- Laser stable PO lives on base.position_offset; omit per-frame pp unless dynamic.
	if tr.kind == "laser" then
		local is_techx = tr.family == "techx"
		if not is_techx then
			packed.an = pack_change_events(states, function(s) return s.angle end, ANGLE_Q, false)
			packed.md = pack_change_events(states, function(s) return s.max_distance end, POS_Q, false)
			packed.sr = pack_change_events(states, function(s) return s.sprite_rotation end, ANGLE_Q, false)
		end
		-- Radius kept for settle/debug; Tech X replay uses base.techx_spawn_radius only.
		packed.rd = pack_change_events(states, function(s) return s.radius end, POS_Q, false)
		packed.vs = pack_change_events(states, function(s) return s.visible end, nil, true)
		if is_techx then
			packed.vx = pack_change_events(states, function(s) return s.vx end, VEL_Q, false)
			packed.vy = pack_change_events(states, function(s) return s.vy end, VEL_Q, false)
		end
		-- Beam thickness: EntityLaser GetScale (not Radius, not SpriteScale authority).
		local ls = type(tr.base) == "table" and tonumber(tr.base.laser_scale) or nil
		if ls ~= nil then
			packed.ls = quantize(ls, LASER_SCALE_Q)
		end
		-- Factory DamageMultiplier (nil = unknown / omit on replay).
		local dm = type(tr.base) == "table" and tonumber(tr.base.damage_multiplier) or nil
		if dm ~= nil then
			packed.dm = quantize(dm, DAMAGE_MUL_Q)
		end
		-- Recording owner PlayerType (Aeon Brimstone compatibility shims).
		local pt = type(tr.base) == "table" and tonumber(tr.base.owner_player_type) or nil
		if pt ~= nil then
			packed.pt = math.floor(pt + 0.5)
		end
	elseif tr.kind == "knife" or tr.kind == "sword" then
		packed.ro = pack_change_events(states, function(s) return s.rotation end, ANGLE_Q, false)
		packed.ch = pack_change_events(states, function(s) return s.charge end, PATH_Q, false)
		packed.po = pack_change_events(states, function(s) return s.path_offset end, PATH_Q, false)
		packed.pf = pack_change_events(states, function(s) return s.path_follow_speed end, PATH_Q, false)
		packed.md = pack_change_events(states, function(s) return s.max_distance end, POS_Q, false)
		packed.fl = pack_change_events(states, function(s) return s.is_flying end, nil, true)
		packed.cd = pack_change_events(states, function(s) return s.collision_damage end, PATH_Q, false)
		packed.vs = pack_change_events(states, function(s) return s.visible end, nil, true)
	end
	return packed
end

local function migrate_techx_spawn_radius(base, states, family)
	base = type(base) == "table" and base or {}
	if family ~= "techx" then return base end
	if tonumber(base.techx_spawn_radius) ~= nil then return base end
	if type(states) ~= "table" or #states < 1 then return base end
	local eps = 0.25
	local r1 = tonumber(states[1] and states[1].radius)
	local r2 = tonumber(states[2] and states[2].radius)
	local spawn = r2
	if spawn == nil then spawn = r1 end
	if spawn == nil then return base end
	-- Classic init settle: first sample differs from later; use second+.
	if r1 ~= nil and r2 ~= nil and math.abs(r1 - r2) > eps then
		spawn = r2
	end
	base.techx_spawn_radius = spawn
	if states[1] and states[1].radius ~= nil then
		states[1].radius = spawn
	end
	return base
end

local function migrate_laser_po_from_pp(base, poxy, n)
	base = type(base) == "table" and base or {}
	if type(base.position_offset) == "table" then
		return base, false
	end
	local last = nil
	for i = n, 1, -1 do
		local po = poxy and poxy[i]
		if po then
			last = po
			break
		end
	end
	if not last then
		return base, false
	end
	base.position_offset = {x = tonumber(last.x) or 0, y = tonumber(last.y) or 0}
	base.po_dynamic = false
	return base, true
end

local function unpack_one_track(p)
	if type(p) ~= "table" then return nil end
	local n = tonumber(p.n) or 0
	if n < 1 then n = 1 end
	local xy = unpack_xy_delta_stream(p.p, n)
	local has_pp = type(p.pp) == "table"
	local poxy = has_pp and unpack_xy_delta_stream(p.pp, n) or {}
	local base = type(p.b) == "table" and p.b or {}
	local states = {}
	if p.k == "laser" then
		local po_dynamic = p.pd == 1 or base.po_dynamic == true
		local migrated = false
		if not po_dynamic then
			base, migrated = migrate_laser_po_from_pp(base, poxy, n)
		end
		local an = apply_change_events(n, p.an, ANGLE_Q, false)
		local md = apply_change_events(n, p.md, POS_Q, false)
		local rd = apply_change_events(n, p.rd, POS_Q, false)
		local vs = apply_change_events(n, p.vs, nil, true)
		local sr = apply_change_events(n, p.sr, ANGLE_Q, false)
		local has_vel = type(p.vx) == "table" or type(p.vy) == "table"
		local vx = has_vel and apply_change_events(n, p.vx, VEL_Q, false) or nil
		local vy = has_vel and apply_change_events(n, p.vy, VEL_Q, false) or nil
		for i = 1, n do
			local st = {
				ox = xy[i].x,
				oy = xy[i].y,
				angle = an[i],
				max_distance = md[i],
				radius = rd[i],
				visible = vs[i],
				sprite_rotation = sr[i],
			}
			if vx and vy then
				st.vx = vx[i]
				st.vy = vy[i]
			end
			if po_dynamic and not migrated then
				local po = poxy[i] or {x = 0, y = 0}
				st.pox = po.x
				st.poy = po.y
				st.dynamic_pox = po.x
				st.dynamic_poy = po.y
			end
			states[i] = st
		end
		if not po_dynamic then
			base.po_dynamic = false
		else
			base.po_dynamic = true
		end
		if p.ht ~= nil then
			base.homing_type = tonumber(p.ht) or p.ht
		end
		if p.cs ~= nil then
			base.curve_strength = tonumber(p.cs) or p.cs
		end
		-- ls = quantized GetScale; optional. Old saves without ls keep base.sprite_scale fallback.
		if p.ls ~= nil then
			base.laser_scale = dequantize(p.ls, LASER_SCALE_Q)
		elseif base.laser_scale ~= nil then
			base.laser_scale = tonumber(base.laser_scale)
		end
		-- dm = quantized GetDamageMultiplier; nil means factory default (do not invent 1).
		if p.dm ~= nil then
			base.damage_multiplier = dequantize(p.dm, DAMAGE_MUL_Q)
		elseif base.damage_multiplier ~= nil then
			base.damage_multiplier = tonumber(base.damage_multiplier)
		else
			base.damage_multiplier = nil
		end
		-- pt = owner PlayerType; absent on old saves → no character-specific factory shim.
		if p.pt ~= nil then
			base.owner_player_type = tonumber(p.pt)
		elseif base.owner_player_type ~= nil then
			base.owner_player_type = tonumber(base.owner_player_type)
		else
			base.owner_player_type = nil
		end
		base = migrate_techx_spawn_radius(base, states, p.fm)
	else
		local ro = apply_change_events(n, p.ro, ANGLE_Q, false)
		local ch = apply_change_events(n, p.ch, PATH_Q, false)
		local po = apply_change_events(n, p.po, PATH_Q, false)
		local pf = apply_change_events(n, p.pf, PATH_Q, false)
		local md = apply_change_events(n, p.md, POS_Q, false)
		local fl = apply_change_events(n, p.fl, nil, true)
		local cd = apply_change_events(n, p.cd, PATH_Q, false)
		local vs = apply_change_events(n, p.vs, nil, true)
		for i = 1, n do
			local pof = poxy[i] or {x = 0, y = 0}
			states[i] = {
				ox = xy[i].x,
				oy = xy[i].y,
				pox = pof.x,
				poy = pof.y,
				rotation = ro[i],
				charge = ch[i],
				path_offset = po[i],
				path_follow_speed = pf[i],
				max_distance = md[i],
				is_flying = fl[i],
				collision_damage = cd[i],
				visible = vs[i],
			}
		end
	end
	return {
		mode = "persistent",
		kind = p.k,
		family = p.fm,
		start_frame = tonumber(p.sf) or 0,
		end_frame = tonumber(p.ef) or 0,
		base = base,
		states = states,
	}
end

local function pack_tracks(tracks)
	local out = {}
	if type(tracks) ~= "table" then return out end
	for i = 1, #tracks do
		local packed = pack_one_track(tracks[i])
		if packed then out[#out + 1] = packed end
	end
	return out
end

local function unpack_tracks(list)
	local out = {}
	if type(list) ~= "table" then return out end
	for i = 1, #list do
		local tr = unpack_one_track(list[i])
		if tr then out[#out + 1] = tr end
	end
	return out
end

local function pack_specials(list)
	local out = {}
	if type(list) ~= "table" then return out end
	for i = 1, #list do
		local sp = list[i]
		if type(sp) == "table" then
			local tox, toy = 0, 0
			if type(sp.target_offset) == "table" then
				tox = tonumber(sp.target_offset.x) or 0
				toy = tonumber(sp.target_offset.y) or 0
			end
			out[#out + 1] = {
				k = sp.kind or sp.mode or "epic",
				m = sp.mode,
				fm = sp.family,
				sf = tonumber(sp.start_frame) or 0,
				ef = tonumber(sp.end_frame) or tonumber(sp.impact_frame) or 0,
				im = tonumber(sp.impact_frame) or tonumber(sp.end_frame) or 0,
				ox = quantize(tox, POS_Q),
				oy = quantize(toy, POS_Q),
				b = sp.base,
			}
		end
	end
	return out
end

local function unpack_specials(list)
	local out = {}
	if type(list) ~= "table" then return out end
	for i = 1, #list do
		local p = list[i]
		if type(p) == "table" then
			local last_ox = dequantize(p.ox, POS_Q)
			local last_oy = dequantize(p.oy, POS_Q)
			local kind = p.k or "epic"
			local mode = p.m
			local base = p.b
			if type(base) ~= "table" then
				base = nil
			end
			if kind == "character_action" or mode == "character_action"
				or (p.fm == "character_action")
			then
				mode = "character_action"
				kind = "character_action"
			elseif kind == "sword_action" or mode == "sword_action"
				or kind == "normal" or kind == "spin"
			then
				mode = "sword_action"
				if kind == "sword_action" then
					kind = (base and base.action_kind) or "normal"
				end
				if kind ~= "spin" then
					kind = "normal"
				end
				if type(base) == "table" then
					base.action_kind = kind
				end
			else
				mode = "special"
			end
			local family = p.fm
			if mode == "character_action" then
				family = "character_action"
			elseif not family then
				family = (mode == "sword_action") and "sword" or "epic"
			end
			out[#out + 1] = {
				mode = mode,
				kind = kind,
				family = family,
				start_frame = tonumber(p.sf) or 0,
				end_frame = tonumber(p.ef) or 0,
				impact_frame = tonumber(p.im) or tonumber(p.ef) or 0,
				target_offset = {x = last_ox, y = last_oy},
				base = base,
			}
		end
	end
	return out
end

function M.pack_save_record(rec)
	if type(rec) ~= "table" then return nil end
	local length = tonumber(rec.length) or 0
	if length < 1 or type(rec.frames) ~= "table" then
		return nil
	end

	local at, ae = pack_attacks(rec.attacks)
	return {
		v = M.PACK_VERSION,
		rv = tonumber(rec.version) or M.RUNTIME_SCHEMA_VERSION,
		l = length,
		oi = rec.owner_index,
		oc = rec.owner_controller_index,
		sr = rec.source_room_key,
		ap = rec.appearance,
		f = pack_frames(rec.frames, length),
		at = at,
		ae = ae,
		pt = pack_tracks(rec.persistent_tracks),
		sp = pack_specials(rec.special_events),
		r = pack_played_rooms(rec.played_rooms),
	}
end

function M.unpack_save_record(data)
	if not M.is_packed(data) then
		return nil
	end
	local length = tonumber(data.l) or 0
	if length < 1 then return nil end

	local frames = unpack_frames(data.f, length)
	if not frames[0] or frames[0].x == nil or frames[0].y == nil then
		return nil
	end

	local attacks = unpack_attacks(data.at, data.ae)
	local tracks = unpack_tracks(data.pt)
	local specials = unpack_specials(data.sp)
	local played = unpack_played_rooms(data.r)
	if data.sr then
		played[tostring(data.sr)] = true
	end

	return {
		version = tonumber(data.rv) or M.RUNTIME_SCHEMA_VERSION,
		owner_index = data.oi,
		owner_controller_index = data.oc,
		length = length,
		appearance = data.ap,
		canvas = {
			grid_w = room_space.STANDARD_GRID_W,
			grid_h = room_space.STANDARD_GRID_H,
			tile = room_space.GRID_TILE,
		},
		frames = frames,
		attacks = attacks,
		persistent_tracks = tracks,
		special_events = specials,
		source_room_key = data.sr,
		played_rooms = played,
	}
end

local function json_bytes(tbl)
	if type(tbl) ~= "table" then return 0 end
	local ok, encoded = pcall(json.encode, tbl)
	if not ok or type(encoded) ~= "string" then return 0 end
	return #encoded
end

--- On-demand size audit (Debug only). Never call during normal record finish.
function M.audit_sizes(runtime_rec)
	local full = type(runtime_rec) == "table" and runtime_rec or {}
	local packed = M.pack_save_record(full)
	local appearance_b = json_bytes(full.appearance)
	local frames_b = json_bytes(full.frames)
	local attacks_b = json_bytes(full.attacks)
	local tracks_b = json_bytes(full.persistent_tracks)
	local specials_b = json_bytes(full.special_events)
	local full_total = appearance_b + frames_b + attacks_b + tracks_b + specials_b + json_bytes({
		version = full.version,
		length = full.length,
		played_rooms = full.played_rooms,
		source_room_key = full.source_room_key,
	})

	local packed_ap = packed and json_bytes(packed.ap) or 0
	local packed_f = packed and json_bytes(packed.f) or 0
	local packed_at = packed and json_bytes(packed.at) or 0
	local packed_ae = packed and json_bytes(packed.ae) or 0
	local packed_pt = packed and json_bytes(packed.pt) or 0
	local packed_sp = packed and json_bytes(packed.sp) or 0
	local packed_r = packed and json_bytes(packed.r) or 0
	local packed_total = packed and json_bytes(packed) or 0

	local ratio = 0
	if full_total > 0 and packed_total > 0 then
		ratio = 1 - (packed_total / full_total)
	end

	return {
		full = {
			appearance = appearance_b,
			frames = frames_b,
			attacks = attacks_b,
			persistent_tracks = tracks_b,
			special_events = specials_b,
			total_est = full_total,
		},
		packed = {
			appearance = packed_ap,
			frame_stream = packed_f,
			attack_templates = packed_at,
			attack_events = packed_ae,
			persistent_tracks = packed_pt,
			special_events = packed_sp,
			played_rooms = packed_r,
			total = packed_total,
		},
		compression_ratio = ratio,
		length = tonumber(full.length) or 0,
		attack_count = type(full.attacks) == "table" and #full.attacks or 0,
		track_count = type(full.persistent_tracks) == "table" and #full.persistent_tracks or 0,
		special_count = type(full.special_events) == "table" and #full.special_events or 0,
	}
end

function M.format_audit(report)
	report = report or {}
	local full = report.full or {}
	local packed = report.packed or {}
	local lines = {
		"Aeon Save Audit",
		"",
		"Full runtime estimate:",
		string.format("  appearance      %d B", full.appearance or 0),
		string.format("  frames          %d B", full.frames or 0),
		string.format("  attacks         %d B", full.attacks or 0),
		string.format("  tracks          %d B", full.persistent_tracks or 0),
		string.format("  specials        %d B", full.special_events or 0),
		string.format("  total (est)     %d B", full.total_est or 0),
		"",
		"Packed:",
		string.format("  appearance      %d B", packed.appearance or 0),
		string.format("  frame stream    %d B", packed.frame_stream or 0),
		string.format("  attack templates %d B", packed.attack_templates or 0),
		string.format("  attack events   %d B", packed.attack_events or 0),
		string.format("  tracks          %d B", packed.persistent_tracks or 0),
		string.format("  specials        %d B", packed.special_events or 0),
		string.format("  played rooms    %d B", packed.played_rooms or 0),
		string.format("  total           %d B", packed.total or 0),
		"",
		string.format("Compression ratio %.1f%%", (report.compression_ratio or 0) * 100),
		string.format(
			"length=%d attacks=%d tracks=%d specials=%d",
			report.length or 0,
			report.attack_count or 0,
			report.track_count or 0,
			report.special_count or 0
		),
	}
	return table.concat(lines, "\n")
end

return M

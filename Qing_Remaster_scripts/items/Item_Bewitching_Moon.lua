-- Bewitching Moon / 幻惑之月
-- Autonomous control familiar with mouse drag + precise eye attach.
-- Null costumes: Head while held; Head2 while any moon is eye-attached.
-- Attached combat/render aura is centered on the head/face anchor.

local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local head_anchor = require("Qing_Remaster_scripts.auxiliary.entity_head_anchor")
local Mouse_UI = require("Qing_Remaster_scripts.others.Mouse_UI_holder")
local Familiar_Follower_Arbiter = require("Qing_Remaster_scripts.mimics.Familiar_Follower_Arbiter")
local Familiar_Control_Selector = require("Qing_Remaster_scripts.mimics.Familiar_Control_Selector")
local QF = require("Qing_Remaster_scripts.mimics.Craft_Qing_Familiars_holder")
local player_visual_render = require("Qing_Remaster_scripts.callbacks.player_visual_render_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Bewitching_Moon,
	familiar = enums.Familiars.Bewitching_Moon,
	own_key = "Item_Bewitching_Moon_",
	CONTROLLER = "bewitching_moon",

	-- Combat aura radii (fixed during a form; pulse does not change hit radius).
	AURA_AUTO = 65,
	AURA_DRAG = 90,
	AURA_ATTACH = 65,
	-- Halo_Autio sheet is 144×144 with pivot 72 → effective radius ≈ 72 at scale 1.
	HALO_BASE_RADIUS = 72,
	HALO_ANM2 = "gfx/effects/Halo/Halo_Autio.anm2",
	HALO_FADE_IN = 0.14,
	HALO_FADE_OUT = 0.18,

	GRAB_DIST = 24,
	ATTACH_DIST = 8,
	ATTACH_REARM_DIST = 18,
	EYE_CLICK_DIST = 14,
	HOVER_HINT_DIST = 36,
	-- Leave hover a bit farther than enter so tip lean does not flicker at the edge.
	HOVER_HINT_EXIT = 46,
	-- Ignore near-center mouse vectors; angle noise there causes jittery spins.
	ROT_AIM_MIN = 12,
	ROT_LEAN_RATE = 0.16,
	ROT_LEAN_MAX_STEP = 9,
	ROT_RETURN_RATE = 0.28,
	ROT_RETURN_MAX_STEP = 14,

	RELEASE_FRAMES = 12,
	RELEASE_DAMP = 0.82,

	-- Moonlight pulse (30Hz): idle 39 + elastic 7 + diffuse 5 + settle 9 = 60 (~2s).
	PULSE_IDLE = 39,
	PULSE_PERIOD = 60,
	-- Relative to end of idle: fire statuses on first diffuse keyframe.
	PULSE_FIRE_AT = 7,
	COMP_FLASH_FRAMES = 5,

	STATUS_CD = 60,
	CHARM_DUR = 90,
	FEAR_DUR = 60,
	CONFUSE_DUR = 30,

	SPEED_PER = 0.3,
	TAUNT_RANGE = 190,
	ORBIT_MIN = 25,
	ORBIT_MAX = 45,
	RETARGET_MIN = 15,
	RETARGET_MAX = 30,
	GROUP_GAP = 32,
	DISPLAY_SCALE = 1.0,
	FLOAT_AMP = 2.2,

	-- Autonomous chase: soft distance ramp + higher long-range cap.
	AUTO_ACCEL = 0.18,
	AUTO_MAX_SPD = 12.0,
	AUTO_SPD_BASE = 2.5,
	AUTO_SPD_PER_DIST = 0.12,

	DUST_ANM2 = "gfx/mimics/Bewitching_Moon/moon_dust.anm2",
	DUST_SPAWN_DIST = 7,
	-- PLAYER_UPDATE is 60Hz: hover, then slow fall (no initial velocity).
	DUST_HOVER_MIN = 28,
	DUST_HOVER_MAX = 72,
	DUST_GRAVITY = 0.028,
	DUST_FADE_FRAMES = 28,
	DUST_MAX = 96,
	-- White sheet × stepped white→blue tint (inclusive white).
	DUST_COLOR_STEPS = 5,
	-- Logic-ground depth: dust.ground_y vs player.Position.Y (Isaac Y grows downward).
	-- ground_y <= Position.Y + bias → behind; else front. Bias keeps co-located dust behind.
	DUST_DEPTH_BIAS = 3,

	costumes = {
		head = enums.Costumes.Bewitching_Moon_Head,
		head2 = enums.Costumes.Bewitching_Moon_Head2,
	},
}

local STATE = {
	AUTONOMOUS = "AUTONOMOUS",
	DRAGGING = "DRAGGING",
	RELEASE = "RELEASE",
	ATTACHED = "ATTACHED",
	GROUP_FOLLOW = "GROUP_FOLLOW",
}

-- player_ptr -> { moon_ptr, origin = "world"|"eye", eye_exited = bool }
local drag_sessions = {}
-- Shared enemy status cooldown clock (game frame when next apply allowed).
local STATUS_CD_KEY = item.own_key .. "status_cd"
-- Lightweight room-session counters (not a probe; cleared on new room).
local diag = {
	pulses = 0,
	empty = 0,
	comps = 0,
	applied = 0,
}
-- Attached-form trail dust (sprite-only; no entity). Cleared on new room.
local dust_particles = {}
local dust_sprite = nil
local dust_spawn_accum = {}

-- Elastic pulse keyframes (anim-local t after idle). Bomb/heart style axis exchange.
-- fire marker is PULSE_FIRE_AT (first diffuse frame), not stored per-key.
local PULSE_KEYS = {
	{ t = 0, sx = 1.00, sy = 1.00, h = 1.00, a = 1.00, oy = 0 },
	{ t = 2, sx = 1.07, sy = 0.94, h = 1.00, a = 0.94, oy = 1.2 },
	{ t = 4, sx = 0.94, sy = 1.07, h = 1.00, a = 0.96, oy = -1.2 },
	{ t = 5, sx = 1.11, sy = 0.91, h = 1.00, a = 1.05, oy = 1.4 },
	{ t = 7, sx = 1.18, sy = 1.18, h = 1.00, a = 1.45, oy = 0 },
	{ t = 12, sx = 1.03, sy = 1.03, h = 1.23, a = 1.50, oy = 0 },
	{ t = 21, sx = 1.00, sy = 1.00, h = 1.00, a = 1.00, oy = 0 },
}

local function living(ent)
	return ent and ent.Exists and ent:Exists() and not ent:IsDead()
end

local function ptr(ent)
	return ent and GetPtrHash(ent) or nil
end

local function player_index(player)
	if not player then return nil end
	local idx = player:GetData().__Index
	if idx ~= nil then
		return tostring(idx)
	end
	return "tmp_" .. tostring(ptr(player))
end

local function elses_root()
	local root = save.elses[item.own_key .. "persist"]
	if type(root) ~= "table" then
		root = {}
		save.elses[item.own_key .. "persist"] = root
	end
	return root
end

local function get_attached_count(player)
	local key = player_index(player)
	if not key then return 0 end
	local row = elses_root()[key]
	return (row and tonumber(row.attached)) or 0
end

-- Forward-declared: toggles Head / Head2 null costumes from hold + attach state.
local sync_head_costume

local function set_attached_count(player, n)
	local key = player_index(player)
	if not key then return end
	n = math.max(0, math.floor(n or 0))
	local root = elses_root()
	root[key] = root[key] or {}
	root[key].attached = n
	player:GetData()[item.own_key .. "attached"] = n
	player:AddCacheFlags(CacheFlag.CACHE_SPEED)
	player:EvaluateItems()
	sync_head_costume(player)
end

local function rt_of(ent, create)
	if not ent then return nil end
	local d = ent:GetData()
	local rt = d[item.own_key .. "rt"]
	if not rt and create then
		local phase0 = 0
		if ent.InitSeed then
			phase0 = ent.InitSeed % item.PULSE_PERIOD
		else
			phase0 = (GetPtrHash(ent) or 0) % item.PULSE_PERIOD
		end
		rt = {
			state = STATE.AUTONOMOUS,
			target_ptr = nil,
			retarget = 0,
			orbit_ang = 0,
			orbit_r = 45,
			wander = Vector(0, 0),
			move_dir = Vector(1, 0),
			aura = item.AURA_AUTO,
			aura_visual = item.AURA_AUTO,
			pulse_t = phase0,
			pulse_moon_sx = 1,
			pulse_moon_sy = 1,
			pulse_halo_scale = 1,
			pulse_alpha = 1,
			pulse_oy = 0,
			compensation_pending = false,
			compensation_flash = 0,
			halo_t = 1,
			release_t = 0,
			float_blend = 1,
			group_slot = 0,
			hover = 0,
			hover_active = false,
			rot = 0,
			rot_want = 0,
			spawn_clock = Game():GetFrameCount(),
		}
		d[item.own_key .. "rt"] = rt
	end
	return rt
end

local function list_moons(player)
	local out = {}
	if not player then return out end
	local want = ptr(player)
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
		if living(ent) then
			local owner = auxi.check_spawner_player(ent)
			if owner and ptr(owner) == want then
				out[#out + 1] = ent
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.InitSeed or 0) < (b.InitSeed or 0)
	end)
	return out
end

local function count_targeting(enemy_ptr, exclude)
	if not enemy_ptr then return 0 end
	local n = 0
	local ex = ptr(exclude)
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
		if living(ent) and ptr(ent) ~= ex then
			local rt = rt_of(ent, false)
			if rt and rt.target_ptr == enemy_ptr and rt.state == STATE.AUTONOMOUS then
				n = n + 1
			end
		end
	end
	return n
end

local function rng_float(rng)
	if not rng then return math.random() end
	return rng:RandomFloat()
end

local function pick_target(ent, player)
	local rng = player and player:GetCollectibleRNG(item.entity) or nil
	local best, best_w = nil, 0
	local enemies = auxi.getenemies and auxi.getenemies() or {}
	for _, npc in pairs(enemies) do
		if living(npc) and auxi.isenemies(npc) and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			local d = (npc.Position - ent.Position):Length()
			local share = count_targeting(ptr(npc), ent)
			local w = (1 / (1 + d / 120)) * (1 / (1 + share))
			w = w * (0.75 + 0.5 * rng_float(rng))
			if w > best_w then
				best_w = w
				best = npc
			end
		end
	end
	return best
end

local function ensure_orbit(rt, rng)
	rt.orbit_ang = rng_float(rng) * 360
	rt.orbit_r = item.ORBIT_MIN + rng_float(rng) * (item.ORBIT_MAX - item.ORBIT_MIN)
end

local function moon_screen(ent)
	return Isaac.WorldToScreen(ent.Position + (ent.PositionOffset or Vector.Zero))
end

--- Face/eye screen point via entity_head_anchor (not a hardcoded head height).
--- face.center is Sprite-local after entity render transform; add to
--- WorldToScreen(Position+PositionOffset), then RenderToWorld for world space.
--- Fallback (-22 screen / -20 world) only when face anchor is unavailable.
local function face_screen(player, opts)
	opts = opts or {}
	if not player then return nil end
	local face = head_anchor.GetEntityFaceAnchor(player)
	-- Visual lift from player_offset_holder when open; do not also add native PO.
	local base = Isaac.WorldToScreen(player_visual_render.GetVisualWorld(player))
	if face and face.center then
		local bias_x = 0
		if opts.eye_bias then
			bias_x = (player.FlipX and -1 or 1) * math.min(6, (face.width or 12) * 0.22)
		end
		return base + face.center + Vector(bias_x, 0), face
	end
	return base + Vector(0, -22), nil
end

local function eye_screen(player)
	local s = face_screen(player, { eye_bias = true })
	return s
end

--- World-space face center (fusion / aura / dust upper bound).
local function face_world(player)
	local scr = face_screen(player, { eye_bias = false })
	if scr and Isaac.RenderToWorld then
		local ok, world = pcall(Isaac.RenderToWorld, scr)
		if ok and world then
			return world
		end
	end
	-- Fallback must still include visual lift (player_offset_holder).
	return player_visual_render.GetVisualWorld(player) + Vector(0, -20)
end

--- World-space eye-biased point for precise attach / detach pose.
local function eye_world(player)
	local eye_s = eye_screen(player)
	if eye_s and Isaac.RenderToWorld then
		local ok, world = pcall(Isaac.RenderToWorld, eye_s)
		if ok and world then
			return world
		end
	end
	return player.Position + Vector(0, -20)
end

local function mouse_screen()
	return Mouse_UI.get_screen_pos()
end

local function mouse_world()
	-- Mirror-safe world mouse (see auxi.mouse_world_pos).
	if auxi.mouse_world_pos then
		return auxi.mouse_world_pos()
	end
	return Input.GetMousePosition(true)
end

local function smoothstep(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

local function ensure_halo(d)
	local sp = d[item.own_key .. "halo"]
	if sp == nil then
		sp = Sprite()
		sp:Load(item.HALO_ANM2, true)
		sp:Play("Idle", true)
		d[item.own_key .. "halo"] = sp
	end
	return sp
end

--- Soft moonlight blue. Halo_Autio ANM2 bakes a purple tint; multiply/offset toward dust blue.
local function aura_halo_color(alpha, glow)
	glow = glow or 1
	local a = math.min(1, alpha or 1)
	return Color(
		0.40 * glow,
		0.78 * glow,
		1.0,
		a,
		0.0,
		0.08 * glow,
		0.28 * glow
	)
end

local function shortest_angle_delta(from, to)
	local d = (to or 0) - (from or 0)
	while d > 180 do d = d - 360 end
	while d < -180 do d = d + 360 end
	return d
end

local function apply_moon_rotation(s, rt, degrees)
	rt.rot = degrees
	s.Rotation = degrees
end

--- Ease sprite rotation toward want (degrees). Caps per-frame step to kill jitter.
local function ease_moon_rotation(s, rt, want, rate, max_step)
	local cur = rt.rot
	if cur == nil then
		cur = s.Rotation or 0
	end
	want = want or 0
	local d = shortest_angle_delta(cur, want)
	if math.abs(d) < 0.4 then
		apply_moon_rotation(s, rt, want)
		return
	end
	local step = d * (rate or 0.16)
	local cap = max_step or 9
	if step > cap then
		step = cap
	elseif step < -cap then
		step = -cap
	end
	apply_moon_rotation(s, rt, cur + step)
end

local function aura_radius_for(rt)
	if not rt then return item.AURA_AUTO end
	if rt.state == STATE.DRAGGING then
		return item.AURA_DRAG
	end
	if rt.state == STATE.ATTACHED then
		return item.AURA_ATTACH
	end
	if rt.state == STATE.RELEASE then
		local u = 1 - math.max(0, (rt.release_t or 0) / item.RELEASE_FRAMES)
		return item.AURA_DRAG + (item.AURA_AUTO - item.AURA_DRAG) * smoothstep(u)
	end
	return item.AURA_AUTO
end

local function tick_aura_vis(rt)
	-- Combat radius follows form; visual radius eases toward it (pulse multiplies separately).
	rt.aura = aura_radius_for(rt)
	local cur = rt.aura_visual or rt.aura
	rt.aura_visual = cur + (rt.aura - cur) * 0.18
end

local function lerp(a, b, u)
	return a + (b - a) * u
end

local function eval_pulse_keys(anim_t)
	local keys = PULSE_KEYS
	if anim_t <= keys[1].t then
		return keys[1]
	end
	local last = keys[#keys]
	if anim_t >= last.t then
		return last
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if anim_t >= a.t and anim_t <= b.t then
			local span = math.max(1e-6, b.t - a.t)
			local u = smoothstep((anim_t - a.t) / span)
			return {
				sx = lerp(a.sx, b.sx, u),
				sy = lerp(a.sy, b.sy, u),
				h = lerp(a.h, b.h, u),
				a = lerp(a.a, b.a, u),
				oy = lerp(a.oy, b.oy, u),
			}
		end
	end
	return last
end

--- Advance moonlight pulse visuals. Returns true on the diffuse fire frame.
local function tick_pulse(rt)
	rt.pulse_t = (rt.pulse_t or 0) + 1
	if rt.pulse_t >= item.PULSE_PERIOD then
		rt.pulse_t = 0
	end
	local fire = false
	rt.pulse_moon_sx = 1
	rt.pulse_moon_sy = 1
	rt.pulse_halo_scale = 1
	rt.pulse_alpha = 1
	rt.pulse_oy = 0
	local t = rt.pulse_t or 0
	if t < item.PULSE_IDLE then
		local breathe = 0.015 * math.sin(t * 0.11)
		rt.pulse_halo_scale = 1 + breathe
		rt.pulse_alpha = 1 + breathe * 0.5
	else
		local anim_t = t - item.PULSE_IDLE
		local pose = eval_pulse_keys(anim_t)
		rt.pulse_moon_sx = pose.sx
		rt.pulse_moon_sy = pose.sy
		rt.pulse_halo_scale = pose.h
		rt.pulse_alpha = pose.a
		rt.pulse_oy = pose.oy
		fire = (anim_t == item.PULSE_FIRE_AT)
	end
	-- Short compensation flash overlays visuals only (does not change combat radius).
	local flash = rt.compensation_flash or 0
	if flash > 0 then
		local u = flash / item.COMP_FLASH_FRAMES
		rt.pulse_halo_scale = math.max(rt.pulse_halo_scale, 1 + 0.2 * u)
		rt.pulse_alpha = math.max(rt.pulse_alpha, 1 + 0.55 * u)
		rt.pulse_moon_sx = math.max(rt.pulse_moon_sx, 1 + 0.06 * u)
		rt.pulse_moon_sy = math.max(rt.pulse_moon_sy, 1 + 0.06 * u)
		rt.compensation_flash = flash - 1
	end
	return fire
end

local function status_blocked(npc)
	if not living(npc) then return true end
	if npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return true end
	if EntityFlag.FLAG_NO_STATUS_EFFECTS
		and npc:HasEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS) then
		return true
	end
	return false
end

--- Presence for empty-pulse / compensation: in-aura enemy, even if CD / status-immune.
local function is_aura_presence(npc)
	return living(npc)
		and auxi.isenemies(npc)
		and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
end

--- Returns "blocked" | "cooldown" | "applied" | nil (not a presence target).
local function apply_status(npc, source, player)
	if not is_aura_presence(npc) then
		return nil
	end
	if status_blocked(npc) then
		return "blocked"
	end
	local frame = Game():GetFrameCount()
	local d = npc:GetData()
	local cd = d[STATUS_CD_KEY]
	if cd and frame < cd then
		return "cooldown"
	end
	d[STATUS_CD_KEY] = frame + item.STATUS_CD
	local rng = player and player:GetCollectibleRNG(item.entity) or nil
	local roll = rng_float(rng)
	local ref = EntityRef(source or player)
	if roll < (1 / 3) then
		if npc.AddCharmed then
			npc:AddCharmed(ref, item.CHARM_DUR)
		end
	elseif roll < (2 / 3) then
		if npc.AddFear then
			npc:AddFear(ref, item.FEAR_DUR)
		end
	else
		if npc.AddConfusion then
			npc:AddConfusion(ref, item.CONFUSE_DUR, false)
		end
	end
	diag.applied = diag.applied + 1
	return "applied"
end

--- Scan aura once at a world position. Returns present count and apply stats.
local function tick_aura_effects_at(pos, radius, player, source_for_ref, do_apply)
	local present, blocked, cooldown, applied = 0, 0, 0, 0
	if not pos or not radius or radius <= 0 then
		return present, blocked, cooldown, applied
	end
	for _, v in pairs(Isaac.GetRoomEntities()) do
		if is_aura_presence(v) and (v.Position - pos):Length() <= radius then
			present = present + 1
			if do_apply then
				local res = apply_status(v, source_for_ref or player, player)
				if res == "blocked" then
					blocked = blocked + 1
				elseif res == "cooldown" then
					cooldown = cooldown + 1
				elseif res == "applied" then
					applied = applied + 1
				end
			end
		end
	end
	return present, blocked, cooldown, applied
end

local function count_aura_presence_at(pos, radius)
	local present = tick_aura_effects_at(pos, radius, nil, nil, false)
	return present
end

local function fire_moonlight(rt, center_pos, player, source_ent, is_compensation)
	if not center_pos or not player then
		return
	end
	local radius = rt.aura or item.AURA_AUTO
	local source = source_ent or player
	if is_compensation then
		local present = count_aura_presence_at(center_pos, radius)
		if present <= 0 then
			return
		end
		tick_aura_effects_at(center_pos, radius, player, source, true)
		rt.compensation_pending = false
		rt.compensation_flash = item.COMP_FLASH_FRAMES
		diag.comps = diag.comps + 1
		return
	end
	-- Normal pulse fire: old compensation expires; re-arm only on true empty aura.
	diag.pulses = diag.pulses + 1
	local present = count_aura_presence_at(center_pos, radius)
	if present <= 0 then
		rt.compensation_pending = true
		diag.empty = diag.empty + 1
		return
	end
	rt.compensation_pending = false
	tick_aura_effects_at(center_pos, radius, player, source, true)
end

local function tick_compensation(rt, center_pos, player, source_ent)
	if not rt or not rt.compensation_pending then
		return
	end
	if not center_pos or not player then
		return
	end
	local present = count_aura_presence_at(center_pos, rt.aura or item.AURA_AUTO)
	if present > 0 then
		fire_moonlight(rt, center_pos, player, source_ent, true)
	end
end

local function enemy_has_priority_status(npc)
	return npc:HasEntityFlags(EntityFlag.FLAG_FEAR)
		or npc:HasEntityFlags(EntityFlag.FLAG_CHARM)
		or npc:HasEntityFlags(EntityFlag.FLAG_CONFUSION)
end

local function tick_taunt(moon, player)
	local rt = rt_of(moon, false)
	if not rt then return end
	if rt.state == STATE.ATTACHED then return end
	local pos = moon.Position
	for _, v in pairs(Isaac.GetRoomEntities()) do
		if auxi.isenemies(v) and living(v) and not v:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			if (v.Position - pos):Length() <= item.TAUNT_RANGE and not enemy_has_priority_status(v) then
				local npc = v:ToNPC()
				if npc then
					-- Soft taunt: only redirect when no higher-priority status owns behavior.
					pcall(function()
						npc.Target = moon
					end)
				end
			end
		end
	end
end

local function claim_detach(ent)
	Familiar_Follower_Arbiter.claim(ent, item.CONTROLLER, { followers = true, delayed = true })
	Familiar_Follower_Arbiter.maintain(ent)
end

local function can_write_move(ent)
	local owner = Familiar_Control_Selector.get_owner(ent)
	return owner == Familiar_Control_Selector.VANILLA or owner == item.CONTROLLER
end

local function set_state(ent, rt, state)
	rt.state = state
	if state == STATE.ATTACHED then
		ent.Visible = false
		ent.Velocity = Vector(0, 0)
	else
		ent.Visible = true
	end
end

local function begin_drag(player, moon, opts)
	opts = opts or {}
	local pkey = ptr(player)
	local mkey = ptr(moon)
	if not pkey or not mkey then return end
	local origin = opts.origin or "world"
	drag_sessions[pkey] = {
		moon_ptr = mkey,
		origin = origin,
		-- World grabs may attach on the next release; eye-detach must leave first.
		eye_exited = (origin ~= "eye"),
	}
	local rt = rt_of(moon, true)
	set_state(moon, rt, STATE.DRAGGING)
	-- Put sibling moons into temporary group follow.
	local moons = list_moons(player)
	local slot = 0
	for _, other in ipairs(moons) do
		if ptr(other) ~= mkey then
			local ort = rt_of(other, true)
			if ort.state ~= STATE.ATTACHED then
				slot = slot + 1
				ort.group_slot = slot
				set_state(other, ort, STATE.GROUP_FOLLOW)
			end
		end
	end
end

local function clear_group_follow(player, except)
	local ex = ptr(except)
	for _, other in ipairs(list_moons(player)) do
		if ptr(other) ~= ex then
			local ort = rt_of(other, false)
			if ort and ort.state == STATE.GROUP_FOLLOW then
				set_state(other, ort, STATE.RELEASE)
				ort.release_t = item.RELEASE_FRAMES
				ort.release_vel = Vector(other.Velocity.X, other.Velocity.Y)
			end
		end
	end
end

local function end_drag_release(player, moon)
	local pkey = ptr(player)
	if pkey then
		drag_sessions[pkey] = nil
	end
	local rt = rt_of(moon, true)
	set_state(moon, rt, STATE.RELEASE)
	rt.release_t = item.RELEASE_FRAMES
	rt.release_vel = Vector(moon.Velocity.X, moon.Velocity.Y)
	clear_group_follow(player, moon)
end

local function attach_moon(player, moon)
	local pkey = ptr(player)
	if pkey then
		drag_sessions[pkey] = nil
	end
	local rt = rt_of(moon, true)
	set_state(moon, rt, STATE.ATTACHED)
	clear_group_follow(player, moon)
	set_attached_count(player, get_attached_count(player) + 1)
end

--- Release-time attach: mouse↔eye distance; eye-origin sessions need eye_exited first.
local function try_attach_on_release(player, moon, sess)
	if not player or not moon or not sess then
		return false
	end
	if sess.origin == "eye" and not sess.eye_exited then
		return false
	end
	local eye = eye_screen(player)
	local mouse = mouse_screen()
	if not eye or not mouse then
		return false
	end
	if (eye - mouse):Length() > item.ATTACH_DIST then
		return false
	end
	attach_moon(player, moon)
	return true
end

-- Mirror Alien_Head: null costumes must be registered in content/costumes2.xml
-- (type="none") or GetCostumeIdByPath / AddNullCostume will not stick.
sync_head_costume = function(player)
	if not player then
		return
	end
	local head = item.costumes and item.costumes.head
	local head2 = item.costumes and item.costumes.head2
	if (head == nil or head < 0) and (head2 == nil or head2 < 0) then
		return
	end
	local has_item = player:GetCollectibleNum(item.entity) > 0
		or (player.GetEffects and player:GetEffects():GetCollectibleEffectNum(item.entity) > 0)
	local want = nil
	if has_item then
		if get_attached_count(player) > 0 then
			want = "head2"
		else
			want = "head"
		end
	end
	local d = player:GetData()
	local cur = d[item.own_key .. "costume"]
	if cur == want then
		return
	end
	if head ~= nil and head >= 0 then
		player:TryRemoveNullCostume(head)
	end
	if head2 ~= nil and head2 >= 0 then
		player:TryRemoveNullCostume(head2)
	end
	if want == "head" and head ~= nil and head >= 0 then
		player:AddNullCostume(head)
	elseif want == "head2" and head2 ~= nil and head2 >= 0 then
		player:AddNullCostume(head2)
	end
	d[item.own_key .. "costume"] = want
end

local function detach_one_to_drag(player)
	local moons = list_moons(player)
	for i = #moons, 1, -1 do
		local moon = moons[i]
		local rt = rt_of(moon, false)
		if rt and rt.state == STATE.ATTACHED then
			set_attached_count(player, math.max(0, get_attached_count(player) - 1))
			-- Place at formal eye anchor; drag target is mouse center (no grab offset).
			moon.Position = eye_world(player)
			moon.Visible = true
			begin_drag(player, moon, { origin = "eye" })
			return true
		end
	end
	return false
end

local function sync_attached_assignment(player)
	local want = get_attached_count(player)
	local moons = list_moons(player)
	local attached_list = {}
	local free_list = {}
	for _, moon in ipairs(moons) do
		local rt = rt_of(moon, true)
		if rt.state == STATE.ATTACHED then
			attached_list[#attached_list + 1] = moon
		else
			free_list[#free_list + 1] = moon
		end
	end
	-- Preserve which moons are already attached; only fill or trim the count.
	while #attached_list > want do
		local moon = table.remove(attached_list)
		set_state(moon, rt_of(moon, true), STATE.AUTONOMOUS)
	end
	while #attached_list < want and #free_list > 0 do
		local moon = table.remove(free_list, 1)
		set_state(moon, rt_of(moon, true), STATE.ATTACHED)
		attached_list[#attached_list + 1] = moon
	end
	sync_head_costume(player)
end

local function move_toward(ent, goal, accel, max_spd, spd_base, spd_per_dist)
	local to = goal - ent.Position
	local dist = to:Length()
	if dist < 0.5 then
		ent.Velocity = ent.Velocity * 0.85
		return
	end
	local base = spd_base or 2.2
	local per = spd_per_dist or 0.08
	local desired = to:Resized(math.min(max_spd, base + dist * per))
	ent.Velocity = ent.Velocity * (1 - accel) + desired * accel
end

local function ensure_dust_sprite()
	if dust_sprite == nil then
		dust_sprite = Sprite()
		dust_sprite:Load(item.DUST_ANM2, true)
		dust_sprite:Play("Idle", true)
	end
	return dust_sprite
end

--- Stepped white→blue multiply tint for a white dust sheet (step 0 = pure white).
local function dust_tint_color(step, alpha)
	local steps = math.max(1, item.DUST_COLOR_STEPS - 1)
	local t = math.max(0, math.min(steps, step or 0)) / steps
	-- White (1,1,1) → soft moon blue (~0.45, 0.72, 1).
	local r = 1 + (0.45 - 1) * t
	local g = 1 + (0.72 - 1) * t
	local b = 1
	return Color(r, g, b, math.min(1, alpha or 1), 0, 0, 0)
end

local function spawn_attach_dust(player)
	if not player or #dust_particles >= item.DUST_MAX then
		return
	end
	-- Spawn band: visual feet (low) → face (high). Landing stays on logic ground.
	local feet = player_visual_render.GetVisualWorld(player)
	local head = face_world(player)
	local top_y = head.Y
	if top_y > feet.Y then
		top_y = feet.Y - 20
	end
	local ground_y = player.Position.Y
	local rng = player:GetCollectibleRNG(item.entity)
	local u = rng_float(rng)
	local half_w = math.max(4, (player.Size or 12) * 0.9)
	local x = feet.X + (rng_float(rng) * 2 - 1) * half_w
	local y = feet.Y + (top_y - feet.Y) * u
	local hover = item.DUST_HOVER_MIN
		+ math.floor(rng_float(rng) * (item.DUST_HOVER_MAX - item.DUST_HOVER_MIN + 1))
	local color_step = math.floor(rng_float(rng) * item.DUST_COLOR_STEPS)
	dust_particles[#dust_particles + 1] = {
		x = x,
		y = y,
		ground_y = ground_y,
		vy = 0,
		hover = hover,
		fade = nil,
		alpha0 = 0.85 + rng_float(rng) * 0.15,
		alpha = 0.85,
		frame = math.floor(rng_float(rng) * 4),
		color_step = color_step,
	}
	dust_particles[#dust_particles].alpha = dust_particles[#dust_particles].alpha0
end

--- Depth from birth ground vs player logic ground. Do not use visual lift / hover Y.
local function dust_is_front(p, player)
	if not p or not player then
		return false
	end
	return (p.ground_y or p.y or 0) > (player.Position.Y + item.DUST_DEPTH_BIAS)
end

local function tick_attach_dust(player)
	if not player or get_attached_count(player) <= 0 then
		-- Still finish landing fades after detach.
	else
		local pkey = ptr(player)
		local spd = player.Velocity:Length()
		if spd > 0.85 then
			local moved = dust_spawn_accum[pkey] or 0
			moved = moved + spd
			while moved >= item.DUST_SPAWN_DIST do
				moved = moved - item.DUST_SPAWN_DIST
				spawn_attach_dust(player)
			end
			dust_spawn_accum[pkey] = moved
		else
			dust_spawn_accum[pkey] = 0
		end
	end
	-- Hover → fall → land & stop → alpha fade out. Isaac world Y grows downward.
	local i = 1
	while i <= #dust_particles do
		local p = dust_particles[i]
		if p.fade ~= nil then
			p.fade = p.fade - 1
			local u = math.max(0, p.fade) / item.DUST_FADE_FRAMES
			p.alpha = (p.alpha0 or 0.9) * u
			p.vy = 0
			p.y = p.ground_y or p.y
			if p.fade <= 0 then
				table.remove(dust_particles, i)
			else
				i = i + 1
			end
		elseif (p.hover or 0) > 0 then
			p.hover = p.hover - 1
			p.vy = 0
			i = i + 1
		else
			p.vy = (p.vy or 0) + item.DUST_GRAVITY
			p.y = (p.y or 0) + p.vy
			if (p.y or 0) >= (p.ground_y or p.y) then
				p.y = p.ground_y or p.y
				p.vy = 0
				p.fade = item.DUST_FADE_FRAMES
			end
			i = i + 1
		end
	end
end

--- layer: "back" | "front". Dust keeps absolute world positions after spawn.
local function render_attach_dust(ctx, layer)
	if #dust_particles <= 0 then
		return
	end
	local player = ctx and ctx.player
	if not player then
		return
	end
	local room = (ctx and ctx.room) or Game():GetRoom()
	if room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	local want_front = (layer == "front")
	local sp = ensure_dust_sprite()
	local scroll = room:GetRenderScrollOffset()
	local offset = (ctx and ctx.offset) or Vector.Zero
	for _, p in ipairs(dust_particles) do
		if dust_is_front(p, player) == want_front then
			sp:SetFrame("Idle", p.frame or 0)
			sp.Color = dust_tint_color(p.color_step, p.alpha or 0.9)
			local pos = room:WorldToScreenPosition(Vector(p.x, p.y))
				+ offset
				- scroll
			sp:Render(pos, Vector(0, 0), Vector(0, 0))
		end
	end
end

local function dust_wants_layer(player, layer)
	if #dust_particles <= 0 or not player then
		return false
	end
	local want_front = (layer == "front")
	for _, p in ipairs(dust_particles) do
		if dust_is_front(p, player) == want_front then
			return true
		end
	end
	return false
end

local function render_attached_aura(ctx)
	local player = ctx and ctx.player
	if not player or get_attached_count(player) <= 0 then
		return
	end
	local room = ctx.room or Game():GetRoom()
	if room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	local d = player:GetData()
	local sp = ensure_halo(d)
	local pulse_halo, pulse_a = 1, 1
	for _, moon in ipairs(list_moons(player)) do
		local rt = rt_of(moon, false)
		if rt and rt.state == STATE.ATTACHED then
			pulse_halo = rt.pulse_halo_scale or 1
			pulse_a = rt.pulse_alpha or 1
			break
		end
	end
	local scale = (item.AURA_ATTACH * pulse_halo) / item.HALO_BASE_RADIUS
	sp.Scale = Vector(scale, scale)
	sp.Color = aura_halo_color(0.5 * pulse_a, 1)
	local frame = Game():GetFrameCount()
	if d[item.own_key .. "player_halo_clock"] ~= frame then
		sp:Update()
		d[item.own_key .. "player_halo_clock"] = frame
	end
	local head_pos = face_world(player)
	local pos = room:WorldToScreenPosition(head_pos)
		+ (ctx.offset or Vector.Zero)
		- room:GetRenderScrollOffset()
	sp:Render(pos, Vector(0, 0), Vector(0, 0))
end

player_visual_render.register({
	id = "bewitching_moon",
	behind = {
		active = function(player)
			return dust_wants_layer(player, "back")
		end,
		render = function(ctx)
			render_attach_dust(ctx, "back")
		end,
	},
	front = {
		active = function(player)
			return dust_wants_layer(player, "front")
				or (player and get_attached_count(player) > 0)
		end,
		render = function(ctx)
			render_attached_aura(ctx)
			render_attach_dust(ctx, "front")
		end,
	},
})

local function tick_autonomous(ent, player, rt)
	local rng = player and player:GetCollectibleRNG(item.entity) or nil
	rt.retarget = (rt.retarget or 0) - 1
	local tg = nil
	if rt.target_ptr then
		for _, npc in pairs(auxi.getenemies() or {}) do
			if ptr(npc) == rt.target_ptr and living(npc) then
				tg = npc
				break
			end
		end
	end
	if not tg or rt.retarget <= 0 then
		tg = pick_target(ent, player)
		rt.target_ptr = ptr(tg)
		rt.retarget = item.RETARGET_MIN + math.floor(rng_float(rng) * (item.RETARGET_MAX - item.RETARGET_MIN + 1))
		ensure_orbit(rt, rng)
	end
	local goal
	if tg then
		local ang = rt.orbit_ang + Game():GetFrameCount() * 1.2
		local off = Vector.FromAngle(ang):Resized(rt.orbit_r or 45)
		goal = tg.Position + off
	elseif player then
		local ang = (ptr(ent) % 360) + Game():GetFrameCount() * 1.6
		goal = player.Position + Vector.FromAngle(ang):Resized(48 + (ptr(ent) % 17))
	else
		goal = ent.Position
	end
	move_toward(
		ent,
		goal,
		item.AUTO_ACCEL,
		item.AUTO_MAX_SPD,
		item.AUTO_SPD_BASE,
		item.AUTO_SPD_PER_DIST
	)
	if ent.Velocity:Length() > 0.4 then
		rt.move_dir = ent.Velocity:Normalized()
	end
end

local function tick_group_follow(ent, leader, rt)
	if not living(leader) then
		set_state(ent, rt, STATE.AUTONOMOUS)
		return
	end
	local lrt = rt_of(leader, false)
	local dir = (lrt and lrt.move_dir) or Vector(1, 0)
	if leader.Velocity:Length() > 0.35 then
		dir = leader.Velocity:Normalized()
		if lrt then lrt.move_dir = dir end
	end
	local slot = rt.group_slot or 1
	local back = -dir:Resized(item.GROUP_GAP * slot)
	local side = Vector(-dir.Y, dir.X):Resized(((slot % 2 == 0) and 1 or -1) * (6 + slot * 3))
	local goal = leader.Position + back + side
	move_toward(ent, goal, 0.22, 9.5)
end

local function tick_release(ent, rt)
	rt.release_t = (rt.release_t or 0) - 1
	local vel = rt.release_vel or ent.Velocity
	vel = vel * item.RELEASE_DAMP
	rt.release_vel = vel
	ent.Velocity = vel
	if rt.release_t <= 0 or vel:Length() < 0.35 then
		set_state(ent, rt, STATE.AUTONOMOUS)
		rt.release_vel = nil
	end
end

local function tick_dragging(ent, player, rt)
	local sess = drag_sessions[ptr(player)]
	if not sess or sess.moon_ptr ~= ptr(ent) then
		end_drag_release(player, ent)
		return
	end
	-- Center on mouse; smooth chase only (no grab offset, no hold-to-attach).
	local goal = mouse_world()
	local to = goal - ent.Position
	ent.Velocity = to * 0.55
	if ent.Velocity:Length() > 0.4 then
		rt.move_dir = ent.Velocity:Normalized()
	end
	-- Eye-origin sessions arm re-attach only after the mouse leaves the eye zone.
	if sess.origin == "eye" and not sess.eye_exited then
		local eye = eye_screen(player)
		local mouse = mouse_screen()
		if eye and mouse and (eye - mouse):Length() > item.ATTACH_REARM_DIST then
			sess.eye_exited = true
		end
	end
end

local function tick_hover_hint(ent, rt)
	local s = ent:GetSprite()
	-- Mouse-controlled moons straighten instead of chasing the cursor.
	if rt.state == STATE.DRAGGING or rt.state == STATE.GROUP_FOLLOW then
		rt.hover = 0
		rt.hover_active = false
		rt.rot_want = 0
		ease_moon_rotation(s, rt, 0, item.ROT_RETURN_RATE, item.ROT_RETURN_MAX_STEP)
		return
	end
	if rt.state == STATE.ATTACHED then
		rt.hover = 0
		rt.hover_active = false
		rt.rot_want = 0
		apply_moon_rotation(s, rt, 0)
		return
	end

	-- Aim from body Position (no float bob) so the tip does not wiggle with PositionOffset.
	local ms = Isaac.WorldToScreen(ent.Position)
	local mouse = mouse_screen()
	local dist = (ms - mouse):Length()
	local active = rt.hover_active
	if active then
		if dist > item.HOVER_HINT_EXIT or Mouse_UI.is_down(0) then
			active = false
		end
	else
		if dist <= item.HOVER_HINT_DIST and not Mouse_UI.is_down(0) then
			active = true
		end
	end
	rt.hover_active = active

	if active then
		rt.hover = math.min(1, (rt.hover or 0) + 0.12)
		if dist >= item.ROT_AIM_MIN then
			rt.rot_want = (mouse - ms):GetAngleDegrees()
		end
		ease_moon_rotation(s, rt, rt.rot_want or 0, item.ROT_LEAN_RATE, item.ROT_LEAN_MAX_STEP)
	else
		rt.hover = math.max(0, (rt.hover or 0) - 0.08)
		rt.rot_want = 0
		ease_moon_rotation(s, rt, 0, item.ROT_RETURN_RATE, item.ROT_RETURN_MAX_STEP)
	end
end

local function find_grab_candidate(player)
	local mouse = mouse_screen()
	local best, best_d = nil, item.GRAB_DIST + 0.01
	for _, moon in ipairs(list_moons(player)) do
		local rt = rt_of(moon, true)
		if rt.state ~= STATE.ATTACHED then
			local d = (moon_screen(moon) - mouse):Length()
			if d < best_d then
				best_d = d
				best = moon
			end
		end
	end
	return best, best_d
end

Familiar_Control_Selector.register(item.CONTROLLER, 35, function(fam)
	return fam and fam.Variant == item.familiar
end)

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_EVALUATE_CACHE,
	params = nil,
	Function = function(_, player, cacheFlag)
		local cnt = player:GetCollectibleNum(item.entity)
			+ player:GetEffects():GetCollectibleEffectNum(item.entity)
		if cacheFlag == CacheFlag.CACHE_FAMILIARS then
			player:CheckFamiliar(
				item.familiar,
				cnt,
				player:GetCollectibleRNG(item.entity),
				Isaac.GetItemConfig():GetCollectible(item.entity)
			)
		end
		if cacheFlag == CacheFlag.CACHE_SPEED then
			local attached = get_attached_count(player)
			if attached > 0 then
				player.MoveSpeed = player.MoveSpeed + item.SPEED_PER * attached
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_INIT,
	params = item.familiar,
	Function = function(_, ent)
		claim_detach(ent)
		local s = ent:GetSprite()
		s:Play("Idle", true)
		s.Scale = Vector(item.DISPLAY_SCALE, item.DISPLAY_SCALE)
		local rt = rt_of(ent, true)
		set_state(ent, rt, STATE.AUTONOMOUS)
		local player = auxi.check_spawner_player(ent)
		if player then
			sync_attached_assignment(player)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_FAMILIAR_RENDER,
	params = item.familiar,
	Function = function(_, ent, offset)
		local rt = rt_of(ent, false)
		if not rt or rt.state == STATE.ATTACHED then
			return
		end
		local room = Game():GetRoom()
		if room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
			return
		end
		local d = ent:GetData()
		local sp = ensure_halo(d)
		local vis = (rt.aura_visual or item.AURA_AUTO) * (rt.pulse_halo_scale or 1)
		local scale = vis / item.HALO_BASE_RADIUS
		local bright = (0.85 + 0.25 * (rt.hover or 0)) * (rt.pulse_alpha or 1)
		if rt.state == STATE.DRAGGING then
			bright = bright + 0.15
		end
		sp.Scale = Vector(scale, scale)
		sp.Color = aura_halo_color(0.52 * bright, 0.9 + 0.2 * (rt.hover or 0))
		local frame = Game():GetFrameCount()
		if d[item.own_key .. "halo_clock"] ~= frame then
			sp:Update()
			d[item.own_key .. "halo_clock"] = frame
		end
		local pos = room:WorldToScreenPosition(ent.Position + (ent.PositionOffset or Vector.Zero))
			+ offset
			- room:GetRenderScrollOffset()
		sp:Render(pos, Vector(0, 0), Vector(0, 0))
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_UPDATE,
	params = item.familiar,
	Function = function(_, ent)
		claim_detach(ent)
		local player = auxi.check_spawner_player(ent)
		local rt = rt_of(ent, true)
		local s = ent:GetSprite()
		if not s:IsPlaying("Idle") then
			s:Play("Idle", true)
		end
		local function apply_moon_sprite_visual()
			-- Pulse scales/offsets Sprite only — never Entity.Size / world Position.
			local sx = item.DISPLAY_SCALE * (rt.pulse_moon_sx or 1)
			local sy = item.DISPLAY_SCALE * (rt.pulse_moon_sy or 1)
			s.Scale = Vector(sx, sy)
			s.Offset = Vector(0, rt.pulse_oy or 0)
		end
		apply_moon_sprite_visual()

		local function run_moonlight(center_pos, source_ent)
			tick_aura_vis(rt)
			local fire = tick_pulse(rt)
			apply_moon_sprite_visual()
			if not player or not center_pos then
				return
			end
			if fire then
				fire_moonlight(rt, center_pos, player, source_ent, false)
			else
				tick_compensation(rt, center_pos, player, source_ent)
			end
		end

		if not can_write_move(ent) and rt.state ~= STATE.ATTACHED then
			run_moonlight(ent.Position, ent)
			return
		end

		if rt.state == STATE.ATTACHED then
			ent.Velocity = Vector(0, 0)
			ent.Position = player and (player.Position + Vector(0, -12)) or ent.Position
			ent.Visible = false
			-- Attached moons still pulse independently, centered on the face.
			run_moonlight(face_world(player), player)
			return
		end

		ent.Visible = true
		if rt.state == STATE.DRAGGING then
			tick_dragging(ent, player, rt)
		elseif rt.state == STATE.GROUP_FOLLOW then
			local leader = nil
			local sess = player and drag_sessions[ptr(player)]
			if sess then
				for _, moon in ipairs(list_moons(player)) do
					if ptr(moon) == sess.moon_ptr then
						leader = moon
						break
					end
				end
			end
			if leader then
				tick_group_follow(ent, leader, rt)
			else
				set_state(ent, rt, STATE.AUTONOMOUS)
			end
		elseif rt.state == STATE.RELEASE then
			tick_release(ent, rt)
		else
			tick_autonomous(ent, player, rt)
		end

		-- Float bob via PositionOffset; converge to zero while dragging so visual center matches mouse.
		if rt.state == STATE.DRAGGING then
			rt.float_blend = math.max(0, (rt.float_blend or 1) - 0.18)
		else
			rt.float_blend = math.min(1, (rt.float_blend or 1) + 0.1)
		end
		local blend = rt.float_blend or 1
		local bob = math.sin((Game():GetFrameCount() + (ptr(ent) % 40)) * 0.13) * item.FLOAT_AMP * blend
		ent.PositionOffset = Vector(0, bob - 8 * blend)

		tick_hover_hint(ent, rt)
		run_moonlight(ent.Position, ent)
		if player then
			tick_taunt(ent, player)
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE,
	params = item.entity,
	Function = function(_, player)
		sync_head_costume(player)
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_LOSE_COLLECTIBLE,
	params = item.entity,
	Function = function(_, player)
		sync_head_costume(player)
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE,
	params = item.entity,
	Function = function(_, player)
		sync_head_costume(player)
	end,
})

-- Player interaction: grab / release / eye detach. One arbitration per click.
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		if not player then return end
		local has_item = player:GetCollectibleNum(item.entity) > 0
		if has_item then
			sync_attached_assignment(player)
		else
			-- Clear leftover null costumes after the item is gone.
			if player:GetData()[item.own_key .. "costume"] ~= nil then
				sync_head_costume(player)
			end
		end
		-- Dust may still be fading after detach / item loss.
		if has_item or #dust_particles > 0 then
			tick_attach_dust(player)
		end
		if not has_item then return end
		if not Mouse_UI.mouse_allowed(player) then return end

		-- Attached combat is driven by each attached moon's pulse in FAMILIAR_UPDATE.

		local pkey = ptr(player)
		local sess = drag_sessions[pkey]

		if Mouse_UI.was_clicked(0) then
			local eye = eye_screen(player)
			local mouse = mouse_screen()
			if get_attached_count(player) > 0 and eye and (eye - mouse):Length() <= item.EYE_CLICK_DIST then
				detach_one_to_drag(player)
			else
				local moon, dist = find_grab_candidate(player)
				if moon and dist <= item.GRAB_DIST then
					begin_drag(player, moon, { origin = "world" })
				end
			end
		end

		sess = drag_sessions[pkey]
		-- While holding an eye-origin drag, also arm eye_exited on the faster player clock.
		if sess and sess.origin == "eye" and not sess.eye_exited and Mouse_UI.is_down(0) then
			local eye = eye_screen(player)
			local mouse = mouse_screen()
			if eye and mouse and (eye - mouse):Length() > item.ATTACH_REARM_DIST then
				sess.eye_exited = true
			end
		end

		if sess and Mouse_UI.was_released(0) then
			local moon = nil
			for _, ent in ipairs(list_moons(player)) do
				if ptr(ent) == sess.moon_ptr then
					moon = ent
					break
				end
			end
			if moon then
				local rt = rt_of(moon, false)
				if rt and rt.state == STATE.DRAGGING then
					-- One release event: attach on mouse↔eye, else inertial release.
					if not try_attach_on_release(player, moon, sess) then
						end_drag_release(player, moon)
					end
				else
					drag_sessions[pkey] = nil
				end
			else
				drag_sessions[pkey] = nil
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		drag_sessions = {}
		dust_particles = {}
		dust_spawn_accum = {}
		diag.pulses = 0
		diag.empty = 0
		diag.comps = 0
		diag.applied = 0
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and player:GetCollectibleNum(item.entity) > 0 then
				sync_attached_assignment(player)
				local moons = list_moons(player)
				for _, moon in ipairs(moons) do
					local rt = rt_of(moon, true)
					rt.compensation_pending = false
					rt.compensation_flash = 0
					if rt.state ~= STATE.ATTACHED then
						set_state(moon, rt, STATE.AUTONOMOUS)
						rt.target_ptr = nil
						rt.retarget = 0
						-- Soft redeploy near player without follower queue.
						local ang = (ptr(moon) % 360)
						moon.Position = player.Position + Vector.FromAngle(ang):Resized(40)
						moon.Velocity = Vector(0, 0)
					end
				end
				sync_head_costume(player)
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function()
		drag_sessions = {}
	end,
})

QF.register_mod_familiar({
	collectible = item.entity,
	variant = item.familiar,
	key = "bewitching_moon",
	zh = "幻惑之月",
	en = "Bewitching Moon",
	movement = "free",
	control_mode = "move_only",
	custom_move = true,
	exclude_from_formation = true,
	is_leaving_formation = function()
		return true
	end,
})

return item

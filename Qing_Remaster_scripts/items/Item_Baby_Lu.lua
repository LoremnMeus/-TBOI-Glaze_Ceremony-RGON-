local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Baby_Anim = require("Qing_Remaster_scripts.others.Baby_Anim_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Baby_Lu,
	familiar = enums.Familiars.Baby_Lu,
	own_key = "Item_Baby_Lu_",
	base_reveal = 2,
	orbit_frames = 26,
	rise_frames = 42,
	settle_frames = 22,
	depart_frames = 48,
	lift_peak = -100,
	icon_orbit_radius = 34,
	icon_orbit_radius_peak = 44,
	icon_depth_bias = 8,
	icon_depth_hysteresis = 10,
	icon_depth_near = 96,
	icon_min_fly_dist = 280,
	icon_dist_base = 160,
	icon_dist_per_room = 120,
	finish_reveal_frame = 1,
	finish_happy_frame = 8,
	finish_frames = 26,
	portal_spawn_delay = 12,
	portal_door_clear = 72,
	portal_clear_ring = 2,
	map_icon_anm2 = "gfx/cards/cd01_wiz_map.anm2",
	skip_room_types = {
		[RoomType.ROOM_DEFAULT] = true,
		[RoomType.ROOM_SECRET] = true,
		[RoomType.ROOM_SUPERSECRET] = true,
		[RoomType.ROOM_ULTRASECRET] = true,
	},
}

local runtime_ceremony = nil
local wizard_card = nil
local ceremony_tick_frame = -1
local probe_observer = nil

function item.set_probe_observer(fn)
	probe_observer = type(fn) == "function" and fn or nil
end

function item.debug_ceremony_state()
	if not ceremony_active() then
		return nil
	end
	local c = runtime_ceremony
	return {
		phase = c.phase,
		t = c.t,
		lift_peak = item.lift_peak,
		lift_calc = ceremony_lift(),
	}
end

local function vec_tbl(v)
	return {x = v.X, y = v.Y}
end

local function emit_probe_sample(ent, player, stage)
	if not probe_observer or not ent or not ent:Exists() then
		return
	end
	local room = Game():GetRoom()
	local po = ent.PositionOffset or Vector.Zero
	local so = ent.SpriteOffset or Vector.Zero
	local vel = ent.Velocity or Vector.Zero
	local scroll = room:GetRenderScrollOffset()
	local screen_pos = room:WorldToScreenPosition(ent.Position) - scroll
	local screen_po = room:WorldToScreenPosition(ent.Position + po) - scroll
	local screen_render = screen_po + so
	local screen_player = nil
	if player and player:Exists() then
		screen_player = room:WorldToScreenPosition(player.Position) - scroll
	end
	local dbg = item.debug_ceremony_state()
	local d = ent:GetData()
	local so_base = d[item.own_key.."ceremony_so_base"]
	probe_observer({
		stage = stage,
		InitSeed = ent.InitSeed,
		PtrHash = GetPtrHash(ent),
		ceremony_phase = dbg and dbg.phase or nil,
		ceremony_t = dbg and dbg.t or nil,
		lift_peak = dbg and dbg.lift_peak or item.lift_peak,
		lift_calc = dbg and dbg.lift_calc or nil,
		anim = ent:GetSprite():GetAnimation(),
		anim_frame = ent:GetSprite():GetFrame(),
		is_follower = ent:IsFollower(),
		pos = vec_tbl(ent.Position),
		po = vec_tbl(po),
		so = vec_tbl(so),
		so_base = so_base and vec_tbl(so_base) or nil,
		vel = vec_tbl(vel),
		sprite_rotation = ent:GetSprite().Rotation,
		entity_sprite_rotation = ent.SpriteRotation,
		world_delta = player and vec_tbl(ent.Position - player.Position) or nil,
		screen_pos = vec_tbl(screen_pos),
		screen_po = vec_tbl(screen_po),
		screen_render = vec_tbl(screen_render),
		screen_player = screen_player and vec_tbl(screen_player) or nil,
		screen_delta_y = screen_player and (screen_render.Y - screen_player.Y) or nil,
	})
end

local function get_wizard_card()
	if wizard_card == nil then
		wizard_card = require("Qing_Remaster_scripts.cards.Card_01_Wizard")
	end
	return wizard_card
end

local function smoothstep(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

local function bezier2(p0, p1, p2, t)
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

local function floor_key()
	local level = Game():GetLevel()
	return (level:GetStage() or 0) * 100 + (level:GetStageType() or 0)
end

local function lu_count(player)
	if not player then
		return 0
	end
	return player:GetCollectibleNum(item.entity) + player:GetEffects():GetCollectibleEffectNum(item.entity)
end

local function reveal_target_count(player)
	return math.max(3, item.base_reveal + lu_count(player))
end

local function floor_state()
	save.elses[item.own_key.."floor"] = save.elses[item.own_key.."floor"] or {
		chain = {},
		portals_spawned = {},
	}
	return save.elses[item.own_key.."floor"]
end

local function pick_rooms(options, cnt, rng)
	cnt = math.min(cnt or 1, #options)
	if cnt <= 0 then
		return {}
	end
	local shuffled = {}
	for i, v in ipairs(options) do
		shuffled[i] = v
	end
	for i = #shuffled, 2, -1 do
		local j = rng:RandomInt(i) + 1
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	local result = {}
	for i = 1, cnt do
		result[i] = shuffled[i]
	end
	return result
end

local function collect_special_rooms(level, dimen, current_sgid, allow_visited)
	local rooms = level:GetRooms()
	local fresh = {}
	local visited = {}
	for i = 0, rooms.Size - 1 do
		local targ = rooms:Get(i)
		if targ and targ.SafeGridIndex >= 0 and dimen == auxi.GetDimension(targ) then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex, -1)
			if desc and desc.SafeGridIndex >= 0 and desc.SafeGridIndex ~= current_sgid then
				local tp = desc.Data and desc.Data.Type or RoomType.ROOM_DEFAULT
				if not item.skip_room_types[tp] then
					local entry = {
						sgid = desc.SafeGridIndex,
						tp = tp,
						dim = dimen,
					}
					if (desc.VisitedCount or 0) > 0 then
						if allow_visited then
							visited[#visited + 1] = entry
						end
					else
						fresh[#fresh + 1] = entry
					end
				end
			end
		end
	end
	return fresh, visited
end

local function reveal_room_desc(level, entry)
	local desc = level:GetRoomByIdx(entry.sgid)
	if desc and desc.Data and desc.Data.Type == entry.tp then
		desc.DisplayFlags = (desc.DisplayFlags or 0) | 7
		return true
	end
	return false
end

local function room_map_screen_target(entry, origin_screen)
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	local target = level:GetRoomByIdx(entry.sgid)
	if not cur or not target or cur.GridIndex < 0 or target.GridIndex < 0 then
		return origin_screen + Vector(120, -40)
	end
	local dx = (target.GridIndex % 13) - (cur.GridIndex % 13)
	local dy = math.floor(target.GridIndex / 13) - math.floor(cur.GridIndex / 13)
	local dir = Vector(dx, dy)
	if dir:Length() < 0.01 then
		dir = Vector(1, -0.6)
	else
		dir = dir:Normalized()
	end
	local dist = math.sqrt(dx * dx + dy * dy)
	local scale = math.max(item.icon_min_fly_dist, item.icon_dist_base + dist * item.icon_dist_per_room)
	return origin_screen + Vector(dir.X * scale, dir.Y * scale * 0.82)
end

local function icon_slot_angle(entry, origin_screen, index, total)
	local target = room_map_screen_target(entry, origin_screen)
	local dir = target - origin_screen
	if dir:Length() < 0.01 then
		return (index - 1) * (360 / math.max(total, 1))
	end
	return dir:GetAngleDegrees()
end

local function build_ceremony_icons(pending)
	local icons = {}
	local n = #pending
	for i, entry in ipairs(pending) do
		local sp = Sprite()
		sp:Load(item.map_icon_anm2, true)
		sp:SetFrame("Idle", entry.tp or 1)
		sp.Scale = Vector(1.6, 1.6)
		icons[#icons + 1] = {
			sprite = sp,
			entry = entry,
			orbit_offset = (i - 1) * (360 / math.max(n, 1)),
			slot_angle = nil,
			orbit_radius = item.icon_orbit_radius,
			start = nil,
			control = nil,
			target = nil,
		}
	end
	return icons
end

local function finalize_icon_depart(icon, origin_screen)
	icon.target = room_map_screen_target(icon.entry, origin_screen)
	icon.start = origin_screen + auxi.MakeVector(icon.slot_angle or icon.orbit_offset) * (icon.orbit_radius or item.icon_orbit_radius)
	icon.start = Vector(icon.start.X, origin_screen.Y + (icon.start.Y - origin_screen.Y) * 0.58)
	local mid = (icon.start + icon.target) * 0.5
	local tangent = Vector(-(icon.target.Y - icon.start.Y), icon.target.X - icon.start.X)
	if tangent:Length() < 0.01 then
		tangent = Vector(0, -1)
	else
		tangent = tangent:Normalized()
	end
	icon.control = mid + tangent * 72
end

local function finalize_all_depart_icons(ceremony, origin_screen)
	for i, icon in ipairs(ceremony.icons or {}) do
		if icon.slot_angle == nil then
			icon.slot_angle = icon_slot_angle(icon.entry, origin_screen, i, #(ceremony.icons or {}))
		end
		finalize_icon_depart(icon, origin_screen)
	end
end

local function ceremony_active()
	return runtime_ceremony ~= nil
end

local function ceremony_phase_elapsed()
	if not ceremony_active() then
		return 0
	end
	local c = runtime_ceremony
	return math.max(0, Game():GetFrameCount() - (c.phase_start_frame or 0))
end

local function ceremony_phase_u(phase, frames)
	if frames <= 0 then
		return 1
	end
	return smoothstep(math.min(1, ceremony_phase_elapsed() / frames))
end

local function set_ceremony_phase(c, phase)
	c.phase = phase
	c.t = 0
	c.phase_start_frame = Game():GetFrameCount()
	if phase == "settle" then
		c.settle_from_angle = c.orbit_carry or 0
	end
end

local function orbit_speed_this_frame(c)
	if c.phase == "orbit" then
		local u = ceremony_phase_u("orbit", item.orbit_frames)
		return 0.35 + u * 0.55
	elseif c.phase == "rise" then
		local u = ceremony_phase_u("rise", item.rise_frames)
		return 0.9 + u * 3.4
	elseif c.phase == "settle" then
		local u = ceremony_phase_u("settle", item.settle_frames)
		return (1 - smoothstep(u)) * 3.8
	end
	return 0
end

local function ceremony_lift()
	if not ceremony_active() then
		return 0
	end
	local c = runtime_ceremony
	if c.phase == "orbit" then
		return 0
	end
	if c.phase == "rise" then
		return ceremony_phase_u("rise", item.rise_frames) * item.lift_peak
	end
	if c.phase == "settle" or c.phase == "depart" then
		return item.lift_peak
	end
	if c.phase == "finish" then
		return item.lift_peak * (1 - ceremony_phase_u("finish", item.finish_frames))
	end
	return 0
end

local function ceremony_flash_mul()
	if not ceremony_active() or runtime_ceremony.phase ~= "settle" then
		return 1
	end
	local elapsed = ceremony_phase_elapsed()
	local tail = math.max(1, item.settle_frames - 8)
	if elapsed < tail then
		return 1
	end
	local u = (elapsed - tail) / (item.settle_frames - tail)
	return 0.55 + 0.45 * math.abs(math.sin(u * math.pi))
end

local function apply_ceremony_reveal(ceremony)
	local level = Game():GetLevel()
	local state = floor_state()
	state.chain = {}
	state.portals_spawned = {}
	for _, entry in ipairs(ceremony.pending or {}) do
		if reveal_room_desc(level, entry) then
			state.chain[#state.chain + 1] = entry
		end
	end
	pcall(function()
		level:UpdateVisibility()
	end)
end

local function play_ceremony_happy(player)
	if player and player:Exists() then
		player:AnimateHappy()
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP, 0.85, 1.05, false, 0, 2)
	end
end

local function find_lu_familiar()
	local tgs = auxi.getothers(nil, 3, item.familiar)
	for _, ent in pairs(tgs) do
		if ent:Exists() then
			return ent
		end
	end
	return nil
end

local function finalize_ceremony()
	runtime_ceremony = nil
end

local function begin_ceremony(pending, player)
	if #pending <= 0 then
		if player and player:Exists() then
			player:AnimateHappy()
		end
		return
	end
	runtime_ceremony = {
		phase = "orbit",
		t = 0,
		phase_start_frame = Game():GetFrameCount(),
		player = player,
		pending = pending,
		icons = build_ceremony_icons(pending),
		orbit_carry = 0,
		settle_from_angle = 0,
		revealed = false,
		happy_played = false,
	}
end

-- POST_RENDER：纯屏幕层，不减 scroll（见 entity_render_scroll_offset_pitfalls.md）
local function lu_screen_pos_post(ent)
	local po = ent.PositionOffset or Vector.Zero
	local world = ent.Position + Vector(po.X, po.Y)
	return Isaac.WorldToScreen(world) + (ent.SpriteOffset or Vector.Zero)
end

-- PRE_FAMILIAR：须加 callback offset 并减 scroll
local function lu_screen_pos_pre(ent, offset)
	local room = Game():GetRoom()
	local po = ent.PositionOffset or Vector.Zero
	local world = ent.Position + Vector(po.X, po.Y)
	return Isaac.WorldToScreen(world)
		+ (offset or Vector.Zero)
		- room:GetRenderScrollOffset()
		+ (ent.SpriteOffset or Vector.Zero)
end

local function ceremony_lu_center(room, player, lu_ent, render_offset)
	if lu_ent and lu_ent:Exists() then
		if render_offset then
			return lu_screen_pos_pre(lu_ent, render_offset)
		end
		return lu_screen_pos_post(lu_ent)
	end
	local lu = find_lu_familiar()
	if lu then
		if render_offset then
			return lu_screen_pos_pre(lu, render_offset)
		end
		return lu_screen_pos_post(lu)
	end
	if player and player:Exists() then
		if render_offset then
			return Isaac.WorldToScreen(player.Position)
				+ render_offset
				- room:GetRenderScrollOffset()
		end
		return Isaac.WorldToScreen(player.Position)
	end
	return nil
end

local function tick_ceremony()
	if not ceremony_active() then
		return
	end
	local frame = Game():GetFrameCount()
	if ceremony_tick_frame == frame then
		return
	end
	ceremony_tick_frame = frame
	local c = runtime_ceremony
	c.t = c.t + 1
	c.orbit_carry = (c.orbit_carry or 0) + orbit_speed_this_frame(c)
	if c.phase == "orbit" then
		if c.t >= item.orbit_frames then
			set_ceremony_phase(c, "rise")
		end
	elseif c.phase == "rise" then
		if c.t >= item.rise_frames then
			set_ceremony_phase(c, "settle")
		end
	elseif c.phase == "settle" then
		if c.t == 1 then
			local room = Game():GetRoom()
			local origin = ceremony_lu_center(room, c.player)
			if origin then
				for i, icon in ipairs(c.icons or {}) do
					icon.slot_angle = icon_slot_angle(icon.entry, origin, i, #(c.icons or {}))
				end
			end
		end
		if c.t >= item.settle_frames then
			local room = Game():GetRoom()
			local origin = ceremony_lu_center(room, c.player)
			if origin then
				finalize_all_depart_icons(c, origin)
			end
			set_ceremony_phase(c, "depart")
		end
	elseif c.phase == "depart" then
		if c.t >= item.depart_frames then
			set_ceremony_phase(c, "finish")
		end
	elseif c.phase == "finish" then
		if c.t == item.finish_reveal_frame and not c.revealed then
			c.revealed = true
			apply_ceremony_reveal(c)
		end
		if c.t == item.finish_happy_frame and not c.happy_played then
			c.happy_played = true
			play_ceremony_happy(c.player)
		end
		if c.t >= item.finish_frames then
			finalize_ceremony()
		end
	end
end

function item.reveal_floor_rooms(player)
	local level = Game():GetLevel()
	local dimen = auxi.GetDimension()
	local current = level:GetCurrentRoomDesc()
	local current_sgid = current and current.SafeGridIndex or -1
	local want = reveal_target_count(player)
	local rng = player:GetCollectibleRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	local fresh, visited = collect_special_rooms(level, dimen, current_sgid, true)
	local picks = pick_rooms(fresh, math.min(#fresh, want), rng)
	if #picks < want then
		local more = pick_rooms(visited, want - #picks, rng)
		for _, entry in ipairs(more) do
			picks[#picks + 1] = entry
		end
	end
	local state = floor_state()
	state.chain = {}
	state.portals_spawned = {}
	begin_ceremony(picks, player)
	return #picks
end

local function try_reveal_on_floor(player)
	if not player then
		return
	end
	local key = floor_key()
	if save.elses[item.own_key.."floor_key"] == key then
		return
	end
	save.elses[item.own_key.."floor_key"] = key
	item.reveal_floor_rooms(player)
end

local function chain_index_for_sgid(sgid)
	local state = save.elses[item.own_key.."floor"]
	if not state or not state.chain then
		return nil
	end
	for i, entry in ipairs(state.chain) do
		if entry.sgid == sgid then
			return i
		end
	end
	return nil
end

local GRID_STEP = 40

local PORTAL_BLOCK_GRID = {
	[GridEntityType.GRID_SPIKES] = true,
	[GridEntityType.GRID_SPIKES_ONOFF] = true,
	[GridEntityType.GRID_TRAPDOOR] = true,
	[GridEntityType.GRID_STAIRS] = true,
	[GridEntityType.GRID_TNT] = true,
	[GridEntityType.GRID_PRESSURE_PLATE] = true,
}

local function portal_near_door(room, pos)
	local clear = item.portal_door_clear
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		local door = room:GetDoor(slot)
		if door and room:GetDoorSlotPosition(slot):Distance(pos) < clear then
			return true
		end
	end
	return false
end

-- 对齐 auxi.check_path_from：GridEntity 无 Exists()，只看 CollisionClass / 类型
local function portal_cell_walkable(room, idx)
	local gpos = room:GetGridPosition(idx)
	if not room:IsPositionInRoom(gpos, -20) then
		return false
	end
	if room:GetGridCollision(idx) ~= GridCollisionClass.COLLISION_NONE then
		return false
	end
	if not auxi.CanPassGrid(idx, false) then
		return false
	end
	local grid = room:GetGridEntity(idx)
	if grid then
		if PORTAL_BLOCK_GRID[grid:GetType()] then
			return false
		end
		if grid.CollisionClass ~= GridCollisionClass.COLLISION_NONE then
			return false
		end
	end
	return true
end

local function portal_open_space_score(room, idx)
	local gpos = room:GetGridPosition(idx)
	local ring = item.portal_clear_ring
	local open = 0
	for dx = -ring, ring do
		for dy = -ring, ring do
			if dx ~= 0 or dy ~= 0 then
				local pos = gpos + Vector(dx * GRID_STEP, dy * GRID_STEP)
				if room:IsPositionInRoom(pos, -20) then
					local ni = room:GetGridIndex(pos)
					if portal_cell_walkable(room, ni) then
						open = open + 1
					end
				end
			end
		end
	end
	return open * 4 + auxi.GetMinWallDistance(gpos) * 6
end

local function snap_portal_pos(room, pos)
	if not pos then
		return nil
	end
	local snapped = room:FindFreePickupSpawnPosition(pos, 0, true)
	if snapped and room:IsPositionInRoom(snapped, 16) and not portal_near_door(room, snapped) then
		return snapped
	end
	return nil
end

local function find_portal_spawn_pos(room)
	local candidates = {}
	local best_score = -1
	for i = 0, room:GetGridSize() - 1 do
		if portal_cell_walkable(room, i) then
			local gpos = room:GetGridPosition(i)
			if not portal_near_door(room, gpos) then
				local score = portal_open_space_score(room, i)
				if score > best_score then
					best_score = score
				end
				candidates[#candidates + 1] = {pos = gpos, score = score}
			end
		end
	end
	if #candidates <= 0 then
		return snap_portal_pos(room, room:GetCenterPos())
			or room:FindFreePickupSpawnPosition(room:GetCenterPos(), 40, true)
			or room:GetCenterPos()
	end
	local top = {}
	for _, entry in ipairs(candidates) do
		if entry.score >= best_score - 2 then
			top[#top + 1] = entry.pos
		end
	end
	local suited = auxi.find_suitable_pos_list(top, {})
	for i = 1, math.min(#suited, 10) do
		local snapped = snap_portal_pos(room, suited[i])
		if snapped then
			return snapped
		end
	end
	for _, entry in ipairs(candidates) do
		if entry.score >= best_score - 2 then
			local snapped = snap_portal_pos(room, entry.pos)
			if snapped then
				return snapped
			end
		end
	end
	return snap_portal_pos(room, room:GetCenterPos())
		or room:FindFreePickupSpawnPosition(room:GetCenterPos(), 40, true)
		or room:GetCenterPos()
end

local function spawn_chain_portal(room, from_idx, pos)
	local state = save.elses[item.own_key.."floor"]
	if not state or not state.chain or #state.chain < 2 then
		return
	end
	local chain = state.chain
	local next_idx = (from_idx % #chain) + 1
	local target = chain[next_idx]
	if not target then
		return
	end
	pos = pos or find_portal_spawn_pos(room)
	local wiz = get_wizard_card()
	wiz.spawn_a_fool_port(pos, {
		info = {
			id = from_idx,
			tp = target.tp,
			gidx = target.sgid,
			dim = target.dim or auxi.GetDimension(),
		},
	})
end

local function queue_chain_portal(sgid, from_idx)
	local state = floor_state()
	state.pending_portal = {
		sgid = sgid,
		from_idx = from_idx,
		spawn_frame = Game():GetFrameCount() + item.portal_spawn_delay,
	}
end

local function try_spawn_pending_portal()
	local state = save.elses[item.own_key.."floor"]
	if not state or not state.pending_portal then
		return
	end
	local pending = state.pending_portal
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc or desc.SafeGridIndex ~= pending.sgid then
		state.pending_portal = nil
		return
	end
	if Game():GetFrameCount() < pending.spawn_frame then
		return
	end
	state.pending_portal = nil
	spawn_chain_portal(Game():GetRoom(), pending.from_idx)
end

local function sync_lu_ceremony_motion(ent, d, s)
	if not ceremony_active() then
		if d[item.own_key.."ceremony_so_base"] then
			ent.SpriteOffset = d[item.own_key.."ceremony_so_base"]
			d[item.own_key.."ceremony_so_base"] = nil
		end
		if d[item.own_key.."ceremony_tint"] then
			s.Color = d[item.own_key.."ceremony_tint"]
			d[item.own_key.."ceremony_tint"] = nil
		end
		return
	end
	if d[item.own_key.."ceremony_so_base"] == nil then
		local so = ent.SpriteOffset or Vector.Zero
		d[item.own_key.."ceremony_so_base"] = Vector(so.X, so.Y)
	end
	local base = d[item.own_key.."ceremony_so_base"]
	ent.SpriteOffset = Vector(base.X, base.Y + ceremony_lift())
	ent.Velocity = Vector.Zero
	local flash = ceremony_flash_mul()
	if flash < 0.999 then
		if d[item.own_key.."ceremony_tint"] == nil then
			d[item.own_key.."ceremony_tint"] = s.Color
		end
		s.Color = Color(flash, flash, flash, 1)
	elseif d[item.own_key.."ceremony_tint"] then
		s.Color = d[item.own_key.."ceremony_tint"]
		d[item.own_key.."ceremony_tint"] = nil
	end
end

local function lerp_angle_deg(a, b, t)
	local diff = ((b - a + 180) % 360) - 180
	return a + diff * t
end

local function icon_orbit_pos(center, icon, phase)
	local radius = icon.orbit_radius or item.icon_orbit_radius
	if phase == "rise" then
		local u = ceremony_phase_u("rise", item.rise_frames)
		radius = item.icon_orbit_radius + (item.icon_orbit_radius_peak - item.icon_orbit_radius) * u
		icon.orbit_radius = radius
	end
	local angle
	if phase == "settle" then
		local u = ceremony_phase_u("settle", item.settle_frames)
		local from = (runtime_ceremony.settle_from_angle or 0) + icon.orbit_offset
		local to = icon.slot_angle or icon.orbit_offset
		angle = lerp_angle_deg(from, to, smoothstep(u))
	else
		angle = (runtime_ceremony.orbit_carry or 0) + icon.orbit_offset
	end
	local off = auxi.MakeVector(angle) * radius
	return Vector(center.X + off.X, center.Y + off.Y * 0.58)
end

local function compute_icon_draw(icon, phase, center)
	local pos
	local alpha = 1
	local scale = 2.0
	if phase == "orbit" or phase == "rise" or phase == "settle" then
		pos = icon_orbit_pos(center, icon, phase)
		if phase == "orbit" then
			local u = ceremony_phase_u("orbit", item.orbit_frames)
			alpha = smoothstep(u)
			scale = 1.5 + u * 0.7
		elseif phase == "rise" then
			scale = 2.0 + ceremony_phase_u("rise", item.rise_frames) * 0.25
		else
			scale = 2.25
		end
	elseif phase == "depart" then
		if not icon.start or not icon.target then
			finalize_icon_depart(icon, center)
		end
		local t = ceremony_phase_u("depart", item.depart_frames)
		pos = bezier2(icon.start, icon.control, icon.target, t)
		alpha = 1 - t * 0.12
		scale = 2.2 - t * 0.45
	else
		if not icon.target then
			finalize_icon_depart(icon, center)
		end
		pos = icon.target
		local u = ceremony_phase_u("finish", item.finish_frames)
		alpha = 1 - u * 0.85
		scale = 1.7 - u * 0.4
	end
	return pos, alpha, scale
end

-- 屏幕 Y 更小 = 更靠上 = 在 Lu 身后，应先于宝宝绘制
local function icon_depth_layer(center, pos, phase, icon)
	if phase == "finish" then
		return "overlay"
	end
	if phase == "depart" then
		local dx = pos.X - center.X
		local dy = pos.Y - center.Y
		if dx * dx + dy * dy > item.icon_depth_near * item.icon_depth_near then
			return "overlay"
		end
	end
	local threshold = center.Y + item.icon_depth_bias
	local h = item.icon_depth_hysteresis
	local prev = icon.depth_layer
	if prev == "behind" and pos.Y < threshold + h then
		return "behind"
	end
	if prev == "front" and pos.Y > threshold - h then
		return "front"
	end
	if pos.Y < threshold then
		icon.depth_layer = "behind"
	else
		icon.depth_layer = "front"
	end
	return icon.depth_layer
end

local function pass_matches_layer(depth_pass, layer)
	if depth_pass == "behind" then
		return layer == "behind"
	end
	if depth_pass == "screen" then
		return layer == "front" or layer == "overlay"
	end
	return false
end

local function render_ceremony_icons(depth_pass, lu_ent, render_offset)
	if not ceremony_active() then
		return
	end
	local ceremony = runtime_ceremony
	if not ceremony.icons or #ceremony.icons <= 0 then
		return
	end
	local room = Game():GetRoom()
	if room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	local phase = ceremony.phase
	if phase ~= "orbit" and phase ~= "rise" and phase ~= "settle"
		and phase ~= "depart" and phase ~= "finish" then
		return
	end
	local center = ceremony_lu_center(room, ceremony.player, lu_ent, render_offset)
	if center == nil then
		return
	end
	for _, icon in ipairs(ceremony.icons) do
		local sp = icon.sprite
		if sp then
			local pos, alpha, scale = compute_icon_draw(icon, phase, center)
			local layer = icon_depth_layer(center, pos, phase, icon)
			if pass_matches_layer(depth_pass, layer) then
				sp.Color = Color(1, 1, 1, alpha)
				sp.Scale = Vector(scale, scale)
				sp:Render(pos, Vector(0, 0), Vector(0, 0))
				sp.Color = Color(1, 1, 1, 1)
				sp.Scale = Vector(1, 1)
			end
		end
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_FAMILIAR_RENDER, params = item.familiar,
Function = function(_, ent, offset)
	if not ceremony_active() then
		return
	end
	local canon = find_lu_familiar()
	if not canon or GetPtrHash(ent) ~= GetPtrHash(canon) then
		return
	end
	render_ceremony_icons("behind", ent, offset)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	render_ceremony_icons("screen")
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	if lu_count(player) > 0 then
		try_spawn_pending_portal()
	end
	if ceremony_active() then
		local c = runtime_ceremony
		if c.player and player and auxi.check_for_the_same(c.player, player) then
			tick_ceremony()
		end
	elseif lu_count(player) > 0 then
		try_reveal_on_floor(player)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	local cnt = lu_count(player)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."floor"] = nil
		save.elses[item.own_key.."floor_key"] = nil
		finalize_ceremony()
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."floor_key"] = nil
	save.elses[item.own_key.."floor"] = nil
	finalize_ceremony()
	local tgs = auxi.getothers(nil, 3, item.familiar)
	for _, ent in pairs(tgs) do
		consistance_holder.try_hold_entity(ent, item.own_key)
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_, player)
	try_reveal_on_floor(player)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_, ent)
	local player = auxi.check_spawner_player(ent)
	local d = ent:GetData()
	local s = ent:GetSprite()

	consistance_holder.try_check_entity(ent, item.own_key)
	consistance_holder.try_hold_entity(ent, item.own_key)
	try_reveal_on_floor(player)
	emit_probe_sample(ent, player, "pre_follow")

	if not d[item.own_key.."IsFollow"] then
		ent:AddToFollowers()
		d[item.own_key.."IsFollow"] = true
	end
	Baby_Anim.tick_float_idle(ent, item.own_key.."float")
	if Baby_Anim.is_float_idle_anim(s:GetAnimation()) then
		ent:FollowParent()
	end
	sync_lu_ceremony_motion(ent, d, s)
	emit_probe_sample(ent, player, "post_sync")
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if not auxi.have_player_has_collectible(item.entity) then
		return
	end
	local state = save.elses[item.own_key.."floor"]
	if not state or not state.chain or #state.chain < 2 then
		return
	end
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	if not desc or desc.SafeGridIndex < 0 then
		return
	end
	local sgid = desc.SafeGridIndex
	state.portals_spawned = state.portals_spawned or {}
	if state.portals_spawned[sgid] then
		return
	end
	local idx = chain_index_for_sgid(sgid)
	if not idx then
		return
	end
	state.portals_spawned[sgid] = true
	queue_chain_portal(sgid, idx)
end,
})

return item

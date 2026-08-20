local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local SpriteTrails = require("Qing_Remaster_scripts.others.sprite_trail_presets")
local CraftTearParams = require("Qing_Remaster_scripts.others.craft_tear_params_data")
local dev_env = require("Qing_Remaster_scripts.core.dev_environment")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Seeker_s_Eye,
	own_key = "Item_Seeker_s_eye_",
	wall_probe_enabled = false,
	wall_probe_count = 0,
	wall_probe_last_path = "",
	wall_probe_last_err = "",
	wall_probe_last = "",
}

auxi.add_to_seija(item.entity)

local CHECK_INTERVAL = 2
-- 暗杀者之眼首次检查：counter 默认 5，命中后再隔 max(8, MaxFireDelay*1.3)。
local FIRST_CHECK = 5
local SEEK_DELAY = 15
local SEEK_DELAY_AGAIN = 8
local GRAZE_DELAY = 2
local GRAZE_DIST = 90
local MAX_SEEK = 3
local SEEK_PAUSE = 8
local WALL_PAUSE = 3
local SEEK_COOLDOWN = 3
local PO_SMOOTH = 8
local SLOW_END_MUL = 0
local WALL_AWAY = 16
local TRAIL_FADE = 10
local SAME_TARGET_WEIGHT = 1.15
local BOUNCE_ANGLE = 70
local AHEAD_ANGLE = 120
local BEHIND_MIN_DIST = 28
local STUCK_SPEED = 0.45
local STUCK_FRAMES = 4
local FA_EPS = 0.001
local DEFAULT_AIR_Y = -23.75
local MIN_AIR_Y = -14
local SEEK_FLIGHT_RANGE = 260
local SEEK_FLIGHT_RANGE_MAX = 340
local TOTAL_AIM_MAX = 900
local WALL_LOOKAHEAD = 20
local NEAR_WALL = 20
local WALL_LOOK_MAX = 80
local TURN_MARGIN = 10
local WAYPOINT_REACH = 18
local ASTAR_MAX = 120
local PROJECTILE_LINE = (LineCheckMode and LineCheckMode.PROJECTILE) or 3
local GRID_POOP = (GridEntityType and GridEntityType.GRID_POOP) or 14
local GRID_TNT = (GridEntityType and GridEntityType.GRID_TNT) or 12
local DAMAGE_MULT = {
	[0] = 1.00,
	[1] = 1.15,
	[2] = 1.30,
	[3] = 1.50,
}

local ENEMY_PARTITION = (EntityPartition and EntityPartition.ENEMY) or 8
local DATA_KEY = item.own_key.."seek"
local EFFECT_KEY = item.own_key.."effect"
local TRAIL_KEY = "trail"
local TRAIL_PRESET = {
	min_radius = 0.24,
	max_radius = 0.28,
	scale = 1.0,
	local_offset = { x = 0, y = 0 },
	color = { r = 1, g = 1, b = 1, a = 1, ro = 0, go = 0, bo = 0 },
	colorize = { r = 1, g = 1, b = 1, a = 1 },
	reapply_color_each_sync = true,
}

local glow_sprite = nil

local function ensure_glow_sprite()
	if glow_sprite then return glow_sprite end
	local spr = Sprite()
	spr:Load("gfx/deadeyeteareffect.anm2", true)
	spr:Play("Idle", true)
	spr:SetFrame(0)
	glow_sprite = spr
	return glow_sprite
end

local function now_frame()
	return Game():GetFrameCount()
end

local function has_tear_flag(tear, flag)
	if not tear or not flag then return false end
	if tear.HasTearFlags then
		return tear:HasTearFlags(flag) == true
	end
	if tear.TearFlags then
		return tear.TearFlags & flag == flag
	end
	return false
end

local function is_unsupported_tear(tear)
	if not tear then return true end
	if TearFlags then
		if TearFlags.TEAR_LUDOVICO and has_tear_flag(tear, TearFlags.TEAR_LUDOVICO) then return true end
		if TearFlags.TEAR_ORBIT and has_tear_flag(tear, TearFlags.TEAR_ORBIT) then return true end
		if TearFlags.TEAR_ORBIT_ADVANCED and has_tear_flag(tear, TearFlags.TEAR_ORBIT_ADVANCED) then return true end
	end
	return false
end

local function is_spectral(tear)
	return TearFlags and TearFlags.TEAR_SPECTRAL and has_tear_flag(tear, TearFlags.TEAR_SPECTRAL)
end

local function restore_grid(tear, seek)
	if not seek then return end
	if tear and seek.SavedGridColl ~= nil then
		tear.GridCollisionClass = seek.SavedGridColl
	end
	seek.SavedGridColl = nil
end

local function ignore_grid(tear, seek)
	if not tear or not seek then return end
	if seek.SavedGridColl == nil then
		seek.SavedGridColl = tear.GridCollisionClass
	end
	local none = (EntityGridCollisionClass and EntityGridCollisionClass.GRIDCOLL_NONE) or 0
	tear.GridCollisionClass = none
end

local function clear_trail(seek)
	if not seek then return end
	SpriteTrails.clear(seek, TRAIL_KEY)
end

local function reset_progress(seek, frame)
	if not seek then return end
	seek.BestDistance = nil
	seek.LastProgressFrame = frame or now_frame()
	seek.LastTrackHash = nil
end

local function fallback_speed(tear, seek)
	local speed = tonumber(seek and seek.StoredSpeed) or 0
	if speed < 1 then speed = tear.Velocity:Length() end
	if speed < 1 then
		local player = auxi.check_spawner_player(tear)
		speed = player and (player.ShotSpeed * 10) or 10
	end
	return speed
end

local function read_visual_y(tear)
	if not tear then return DEFAULT_AIR_Y end
	local fa = tonumber(tear.FallingAcceleration) or 0
	local h = tonumber(tear.Height) or DEFAULT_AIR_Y
	local y = auxi.height2offset(h, fa)
	if not y or y > -1 then return DEFAULT_AIR_Y end
	return y
end

-- 固定画面 Y 后按 FA 重写 Height；PO.Y 必须写成同一画面 Y。
-- 禁止 FA>eps 时 PO=0：Update 仍为 0、Render 才填回，转弯会闪一帧贴地。
local function write_air(tear, visual_y, fa, fs)
	if not tear then return end
	fa = tonumber(fa) or 0
	visual_y = tonumber(visual_y) or DEFAULT_AIR_Y
	if visual_y > 0 then visual_y = 0 end
	local h = auxi.offset2height(Vector(0, visual_y), fa)
	if tear.Height ~= nil then tear.Height = h end
	if tear.PositionOffset ~= nil then
		tear.PositionOffset = Vector(0, visual_y)
	end
	if tear.FallingAcceleration ~= nil then tear.FallingAcceleration = fa end
	if tear.FallingSpeed ~= nil then tear.FallingSpeed = tonumber(fs) or 0 end
end

local function start_po_smooth(seek, from_y, to_y)
	if not seek then return end
	to_y = tonumber(to_y) or DEFAULT_AIR_Y
	from_y = tonumber(from_y) or to_y
	seek.HoldY = to_y
	if math.abs(to_y - from_y) < 1.5 then
		seek.SmoothLeft = 0
		seek.SmoothFrames = 0
		seek.SmoothFromY = to_y
		return
	end
	seek.SmoothFromY = from_y
	seek.SmoothFrames = PO_SMOOTH
	seek.SmoothLeft = PO_SMOOTH
end

local function current_smooth_y(seek)
	local to = tonumber(seek and seek.HoldY) or DEFAULT_AIR_Y
	local left = tonumber(seek and seek.SmoothLeft) or 0
	local total = tonumber(seek and seek.SmoothFrames) or 0
	local from = tonumber(seek and seek.SmoothFromY) or to
	if total <= 0 or left <= 0 then return to end
	local t = 1 - (left / total)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	t = t * t * (3 - 2 * t)
	return from + (to - from) * t
end

local function tick_po_smooth(seek)
	if (seek.SmoothLeft or 0) > 0 then
		seek.SmoothLeft = seek.SmoothLeft - 1
	end
	return current_smooth_y(seek)
end

local function write_held_air(tear, seek, fs)
	if not tear or not seek then return end
	local y = current_smooth_y(seek)
	local fa = seek.HoldFA
	if fa == nil then fa = tear.FallingAcceleration end
	if fs == nil then fs = seek.HoldFS end
	if fs == nil then fs = 0 end
	write_air(tear, y, fa, fs)
end

local function hold_air(tear, seek)
	write_held_air(tear, seek, 0)
end

local function apply_smoothed_air(tear, seek, fs)
	if not tear or not seek then return end
	tick_po_smooth(seek)
	write_held_air(tear, seek, fs)
end

local function remaining_frames(tear)
	local h = tonumber(tear and tear.Height) or DEFAULT_AIR_Y
	local fa = tonumber(tear and tear.FallingAcceleration) or 0.5
	local fs = tonumber(tear and tear.FallingSpeed) or 0
	if h >= -1 then return 0 end
	if fa < 0.02 then
		if fs <= 0 then return 90 end
		local n = -h / fs
		if n < 0 then n = 0 elseif n > 90 then n = 90 end
		return n
	end
	local a = fa * 0.5
	local b = fs + fa * 0.5
	local disc = b * b - 4 * a * h
	if disc < 0 then return 90 end
	local n = (-b + disc ^ 0.5) / (2 * a)
	if n < 0 then n = 0 elseif n > 90 then n = 90 end
	return n
end

-- 当前弹道还能飞多远。只用于「是否正在逼近前方」，不得拿来挡住进入求索。
local function remaining_range(tear, seek)
	local speed = fallback_speed(tear, seek)
	local dist = speed * remaining_frames(tear)
	if dist < 24 then dist = 24 end
	if dist > SEEK_FLIGHT_RANGE_MAX then dist = SEEK_FLIGHT_RANGE_MAX end
	return dist
end

-- 瞄准半径按「还能求索几次」计：每次 hop 一段，最多 3 次。
local function hops_left(seek)
	local n = MAX_SEEK - (seek and seek.SearchCount or 0)
	if n < 1 then n = 1 end
	return n
end

local function seek_aim_range(seek)
	local dist = SEEK_FLIGHT_RANGE * hops_left(seek)
	if dist > TOTAL_AIM_MAX then dist = TOTAL_AIM_MAX end
	return dist
end

local function sync_po(tear)
	if not tear or not tear.PositionOffset then return end
	local y = auxi.height2offset(tonumber(tear.Height) or DEFAULT_AIR_Y, tonumber(tear.FallingAcceleration) or 0)
	if y then tear.PositionOffset = Vector(0, y) end
end

local function choose_hold_y(tear, seek)
	local y = read_visual_y(tear)
	local launch = tonumber(seek.LaunchY) or DEFAULT_AIR_Y
	if launch > -8 then launch = DEFAULT_AIR_Y end
	if y > MIN_AIR_Y then y = launch end
	return y
end

local function apply_damage(tear, seek)
	if not tear or not seek then return end
	local base = tonumber(seek.BaseDamage) or tear.CollisionDamage or 0
	local mul = DAMAGE_MULT[seek.SearchCount] or 1
	seek.DamageMult = mul
	tear.CollisionDamage = base * mul
end

local function apply_visual(tear, seek)
	if not tear or not seek then return end
	sync_po(tear)
	local n = seek.SearchCount or 0
	local seeking = (seek.SeekingFrames or 0) > 0
	if n <= 0 and not seeking then return end
	-- duration=1，避免每帧 SetColor 叠成多层发白。
	local w = 0.14 * n
	if seeking then w = w + 0.05 end
	local col = Color(1, 1, 1, 1, w, w, w)
	if col.SetColorize then
		col:SetColorize(0.6, 0.6, 0.6, 0.14 * n)
	end
	tear:SetColor(col, 1, 10, false, false)
	if n >= 3 then
		seek.TrailFade = math.min(TRAIL_FADE, (seek.TrailFade or 0) + 1)
		local u = seek.TrailFade / TRAIL_FADE
		if u < 0 then u = 0 elseif u > 1 then u = 1 end
		u = u * u * (3 - 2 * u)
		local r = TRAIL_PRESET.min_radius * (0.25 + 0.75 * u)
		local r2 = TRAIL_PRESET.max_radius * (0.25 + 0.75 * u)
		local sc = TRAIL_PRESET.scale * (0.4 + 0.6 * u)
		local a = 0.2 + 0.8 * u
		-- sample_pos = Position + PO + local_offset。PO 已是画面高度，勿再把 Height/PO 加进 local_offset。
		local trail = SpriteTrails.sync(tear, seek, TRAIL_KEY, {
			min_radius = r,
			max_radius = r2,
			scale = sc,
			local_offset = { x = 0, y = 0 },
			color = { r = 1, g = 1, b = 1, a = a, ro = 0, go = 0, bo = 0 },
			colorize = { r = 1, g = 1, b = 1, a = a },
			reapply_color_each_sync = true,
		})
		if trail then
			trail.MinRadius = r
			trail.MaxRadius = r2
			trail.SpriteScale = Vector(sc, sc)
		end
	else
		seek.TrailFade = 0
		clear_trail(seek)
	end
end

local function spawn_scan(player, tear)
	local pos = tear.Position
	local lift = read_visual_y(tear)
	local ring = Isaac.Spawn(1000, EffectVariant.WATER_RIPPLE or 133, 0, pos, Vector(0, 0), player)
	if ring then
		ring = ring:ToEffect() or ring
		ring.Parent = nil
		ring.Position = pos
		ring.Velocity = Vector(0, 0)
		ring.SpriteScale = Vector(1.15, 1.15)
		local col = Color(1, 1, 1, 0.55, 0.28, 0.22, 0.06)
		if col.SetColorize then col:SetColorize(0.55, 0.42, 0.12, 0.45) end
		ring:SetColor(col, -1, 1, false, false)
		if ring.SetTimeout then ring:SetTimeout(14) end
		ring.PositionOffset = Vector(0, lift)
		if ring.DepthOffset ~= nil then ring.DepthOffset = 20 end
	end
	if player then
		local ray_col = Color(1, 1, 1, 0.28, 0.4, 0.32, 0.08)
		for i = 1, 4 do
			local ang = i * 90 + (tear.FrameCount or 0) * 7
			item.Seeker_link(player, pos, pos + auxi.MakeVector(ang) * 28, nil, nil, {
				NoS2 = true,
				c1 = ray_col,
				Scaler = Vector(0.55, 0.9),
			})
		end
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_TEARS_FIRE, 0.35, 0.72, false, 0, 2)
end

local function find_target(tear, seek, radius)
	radius = tonumber(radius) or seek_aim_range(seek)
	local enemies = auxi.getenemies(Isaac.FindInRadius(tear.Position, radius, ENEMY_PARTITION))
	local missed = seek and seek.LastMissedHash
	local best = nil
	local best_w = nil
	local nearest = nil
	local nearest_d = nil
	for i = 1, #enemies do
		local enemy = enemies[i]
		if auxi.check_all_exists(enemy) then
			local dist = (enemy.Position - tear.Position):Length()
			if not nearest_d or dist < nearest_d then
				nearest = enemy
				nearest_d = dist
			end
			local weight = dist
			if missed and GetPtrHash(enemy) == missed then
				weight = dist * SAME_TARGET_WEIGHT
			end
			if not best_w or weight < best_w then
				best = enemy
				best_w = weight
			end
		end
	end
	return best, nearest, nearest_d
end

local function heading_dir(tear, seek)
	if not tear then return nil end
	local vel = tear.Velocity
	if vel and vel:Length() >= 0.2 then return vel:Normalized() end
	local ang = seek and seek.LastAngle
	if ang == nil then return nil end
	return auxi.MakeVector(ang)
end

local function heading_angle(tear, pos, seek)
	local dir = heading_dir(tear, seek)
	if not dir then return 180 end
	local to = pos - tear.Position
	if to:Length() < 0.2 then return 0 end
	return math.abs(auxi.get_correct_angle(to:GetAngleDegrees() - dir:GetAngleDegrees()))
end

local function nearest_ahead(tear, radius, seek)
	radius = tonumber(radius) or remaining_range(tear, seek)
	local enemies = auxi.getenemies(Isaac.FindInRadius(tear.Position, radius, ENEMY_PARTITION))
	local best = nil
	local best_d = nil
	for i = 1, #enemies do
		local enemy = enemies[i]
		if auxi.check_all_exists(enemy) then
			local dist = (enemy.Position - tear.Position):Length()
			if heading_angle(tear, enemy.Position, seek) <= AHEAD_ANGLE then
				if not best_d or dist < best_d then
					best = enemy
					best_d = dist
				end
			end
		end
	end
	return best, best_d
end

-- 前方没有敌人：相对速度方向角超过 120°，且距离不是贴身擦过。
local function no_enemies_ahead(tear, radius, seek)
	radius = tonumber(radius) or remaining_range(tear, seek)
	local ahead, ahead_d = nearest_ahead(tear, radius, seek)
	if ahead then return false, ahead, ahead_d end
	local _, nearest, dist = find_target(tear, seek, radius)
	if not nearest then return true, nil, nil end
	if (dist or 0) > BEHIND_MIN_DIST then return true, nearest, dist end
	return false, nearest, dist
end

local stageapi_break_frame = -1
local stageapi_break_idx = {}

local function custom_grid_is_tear_breakable(custom)
	if not custom then return false end
	if custom.PersistentData and custom.PersistentData.Destroyed then return true end
	local cfg = custom.GridConfig
	if not cfg then return false end
	local base = cfg.BaseType
	if base == GRID_POOP or base == GRID_TNT then return true end
	if cfg.PoopExplosionColor or cfg.PoopExplosionAnm2 or cfg.PoopExplosionSheet
		or cfg.PoopGibColor or cfg.PoopGibAnm2 or cfg.PoopGibSheet
		or cfg.CustomPoopGibs then
		return true
	end
	local broken_poop = StageAPI and StageAPI.DefaultBrokenGridStateByType and StageAPI.DefaultBrokenGridStateByType[GRID_POOP]
	if broken_poop and cfg.OverrideGridSpawnsState == broken_poop then return true end
	return false
end

local function refresh_stageapi_breakable()
	local frame = now_frame()
	if stageapi_break_frame == frame then return end
	stageapi_break_frame = frame
	stageapi_break_idx = {}
	if not StageAPI or not StageAPI.GetCustomGrids then return end
	local ok, grids = pcall(StageAPI.GetCustomGrids)
	if not ok or type(grids) ~= "table" then return end
	for i = 1, #grids do
		local custom = grids[i]
		if custom and custom.GridIndex and custom_grid_is_tear_breakable(custom) then
			stageapi_break_idx[custom.GridIndex] = true
		end
	end
end

local function tear_can_break_grid(grid, idx)
	if grid then
		if grid.ToPoop and grid:ToPoop() then return true end
		if grid.ToTNT and grid:ToTNT() then return true end
		if grid.GetType then
			local tp = grid:GetType()
			if tp == GRID_POOP or tp == GRID_TNT then return true end
		end
		if idx == nil and grid.GetGridIndex then idx = grid:GetGridIndex() end
	end
	if idx == nil then return false end
	refresh_stageapi_breakable()
	return stageapi_break_idx[idx] == true
end

local function grid_blocks_projectile(grid, idx)
	if not grid then return false end
	local col = grid.CollisionClass
	if not col or col == 0 then return false end
	if GridCollisionClass and col == GridCollisionClass.COLLISION_PIT then return false end
	if tear_can_break_grid(grid, idx) then return false end
	local tp = grid.GetType and grid:GetType()
	if tp == ((GridEntityType and GridEntityType.GRID_SPIKES) or 8)
		or tp == ((GridEntityType and GridEntityType.GRID_SPIKES_ONOFF) or 9)
		or tp == ((GridEntityType and GridEntityType.GRID_SPIDERWEB) or 10)
		or tp == ((GridEntityType and GridEntityType.GRID_DECORATION) or 1)
		or tp == ((GridEntityType and GridEntityType.GRID_PRESSURE_PLATE) or 20)
		or tp == ((GridEntityType and GridEntityType.GRID_TRAPDOOR) or 17)
		or tp == ((GridEntityType and GridEntityType.GRID_STAIRS) or 18)
		or tp == ((GridEntityType and GridEntityType.GRID_TELEPORTER) or 23) then
		return false
	end
	return true
end

-- CheckLine 的命中点经常落在格子外沿，不能用来认便便。沿线扫格子：
-- 只有会被眼泪打碎的粪块/TNT（含 StageAPI 自制同类）当通路，岩石/墙仍阻挡。
local function line_clear(from, to)
	local room = Game():GetRoom()
	if not room then return true end
	if room.CheckLine and room:CheckLine(from, to, PROJECTILE_LINE, 0, false, false) == true then
		return true
	end
	local span = to - from
	local span_len = span:Length()
	if span_len < 0.2 then return true end
	local along = span * (1 / span_len)
	local t = 0
	while t <= span_len + 0.01 do
		local p = from + along * math.min(t, span_len)
		if room.IsPositionInRoom and not room:IsPositionInRoom(p, 0) then
			return false
		end
		local idx = room.GetGridIndex and room:GetGridIndex(p) or nil
		local grid = nil
		if idx ~= nil and room.GetGridEntity then
			grid = room:GetGridEntity(idx)
		elseif room.GetGridEntityFromPos then
			grid = room:GetGridEntityFromPos(p)
		end
		if grid_blocks_projectile(grid, idx) then return false end
		t = t + 16
	end
	return true
end

local function probe_from(origin, ang, dist)
	local dir = auxi.MakeVector(ang)
	dist = tonumber(dist) or WALL_LOOKAHEAD
	local room = Game():GetRoom()
	local ahead = origin + dir * dist
	if room and room.IsPositionInRoom and not room:IsPositionInRoom(ahead, 0) then
		return true
	end
	return not line_clear(origin, ahead)
end

-- 检测「这一方向是不是墙」：沿探测方向略回退，避免起点已埋进碰撞。
local function probe_blocked(tear, ang, dist)
	if not tear then return true end
	local dir = auxi.MakeVector(ang)
	dist = tonumber(dist) or WALL_LOOKAHEAD
	return probe_from(tear.Position - dir * 6, ang, dist + 6)
end

local function octant_blocked_count(tear)
	local n = 0
	for a = 0, 359, 45 do
		if probe_blocked(tear, a, WALL_LOOKAHEAD) then
			n = n + 1
		end
	end
	return n
end

local function is_buried(tear)
	return octant_blocked_count(tear) >= 6
end

local function room_contains(pos)
	local room = Game():GetRoom()
	if not pos or not room or not room.IsPositionInRoom then return true end
	return room:IsPositionInRoom(pos, 0) == true
end

local function away_dist(tear)
	local sz = tonumber(tear and tear.Size) or 0
	local d = WALL_AWAY
	if sz + 4 > d then d = sz + 4 end
	return d
end

-- 切线检测必须沿墙法线反方向挪开。沿切线回退仍停在墙内，右/下墙会整段 CheckLine 失败。
local function away_origin(tear, inward)
	local back = auxi.MakeVector((inward or 0) + 180)
	return tear.Position + back * away_dist(tear)
end

local function tangent_clear(tear, ang, dist, inward)
	if not tear then return false end
	return not probe_from(away_origin(tear, inward), ang, dist)
end

local function unstick_from_wall(tear, inward)
	if not tear or inward == nil then return false end
	if room_contains(tear.Position) and not is_buried(tear) then
		return true
	end
	local back = auxi.MakeVector(inward + 180)
	local origin = tear.Position
	local placed = origin
	for d = 2, 12, 2 do
		local p = origin + back * d
		if not room_contains(p) then break end
		tear.Position = p
		placed = p
		if not is_buried(tear) then return true end
	end
	tear.Position = placed
	return room_contains(tear.Position) and not is_buried(tear)
end

local function pull_into_room(tear, seek)
	if not tear or room_contains(tear.Position) then return false end
	local origin = tear.Position
	local ang = (seek and seek.LastAngle) or 0
	local back = auxi.MakeVector(ang + 180)
	for d = 4, 80, 4 do
		local p = origin + back * d
		if room_contains(p) then
			tear.Position = p
			return true
		end
	end
	local room = Game():GetRoom()
	if room and room.GetCenterPos then
		local to = room:GetCenterPos() - origin
		if to:Length() > 0.2 then
			local dir = to:Normalized()
			for d = 8, 80, 8 do
				local p = origin + dir * d
				if room_contains(p) then
					tear.Position = p
					return true
				end
			end
		end
	end
	return false
end

local function wall_ahead(tear, dist, seek)
	if not tear then return false end
	local dir = heading_dir(tear, seek)
	if not dir then return false end
	return probe_blocked(tear, dir:GetAngleDegrees(), dist)
end

local function cruise_speed(tear, seek)
	local v = tear and tear.Velocity
	local n = v and v:Length() or 0
	if n >= 0.2 then return n end
	return fallback_speed(tear, seek)
end

-- 求索减速剩余帧还会飞多远（与 POST 里 t^2 曲线一致）。
local function brake_travel(from, left, total)
	from = tonumber(from) or 0
	left = math.floor(tonumber(left) or 0)
	total = tonumber(total) or SEEK_PAUSE
	if from < 0.1 or left < 1 then return 0 end
	if total < 1 then total = 1 end
	local dist = 0
	for i = 0, left - 1 do
		local remain = left - i
		local t = 1 - (remain / total)
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
		t = t * t
		dist = dist + from * (1 - (1 - SLOW_END_MUL) * t)
	end
	return dist
end

local function wall_distance(tear, seek, max_d)
	if not tear or is_spectral(tear) then return nil end
	local dir = heading_dir(tear, seek)
	if not dir then return nil end
	local ang = dir:GetAngleDegrees()
	max_d = tonumber(max_d) or WALL_LOOK_MAX
	if max_d < 8 then max_d = 8 end
	if not probe_blocked(tear, ang, max_d) then return nil end
	local lo = 0
	local hi = max_d
	for _ = 1, 10 do
		local mid = (lo + hi) * 0.5
		if probe_blocked(tear, ang, mid) then
			hi = mid
		else
			lo = mid
		end
	end
	return hi
end

-- 把剩余路程分配进 t^2 减速；刹不住则返回 0。
local function frames_for_brake(from, need)
	from = tonumber(from) or 0
	need = tonumber(need) or 0
	if from < 0.2 then return 0 end
	if need < from * 0.75 then return 0 end
	for n = 1, SEEK_PAUSE do
		if brake_travel(from, n, n) >= need then
			return n
		end
	end
	return SEEK_PAUSE
end

local function brake_horizon(spd)
	spd = tonumber(spd) or 0
	return brake_travel(spd, SEEK_PAUSE, SEEK_PAUSE) + TURN_MARGIN + 4
end

-- 墙已进入完整 SEEK_PAUSE 刹停距离：这时才开始减速，而不是远处钉死。
local function should_start_wall_brake(tear, seek)
	if not tear or is_spectral(tear) then return false end
	local spd = cruise_speed(tear, seek)
	local dist = wall_distance(tear, seek, brake_horizon(spd))
	if dist then
		return dist <= brake_travel(spd, SEEK_PAUSE, SEEK_PAUSE) + TURN_MARGIN
	end
	local vel = tear.Velocity
	if vel and vel:Length() < STUCK_SPEED and wall_ahead(tear, 12, seek) then
		return true
	end
	return false
end

local function cannot_advance(tear, seek)
	if not tear or is_spectral(tear) then return false end
	if wall_ahead(tear, NEAR_WALL, seek) then return true end
	local vel = tear.Velocity
	if vel and vel:Length() < STUCK_SPEED and wall_ahead(tear, 12, seek) then return true end
	return false
end

local function wall_close(tear, seek)
	if not tear or is_spectral(tear) then return false end
	return wall_ahead(tear, NEAR_WALL, seek)
end

local function grid_xy(idx, width)
	return idx % width, math.floor(idx / width)
end

local function manhattan(ax, ay, bx, by)
	local dx = ax - bx
	if dx < 0 then dx = -dx end
	local dy = ay - by
	if dy < 0 then dy = -dy end
	return dx + dy
end

local function astar_indices(room, start_idx, goal_idx, from_pos)
	local width = room:GetGridWidth()
	local height = room:GetGridHeight()
	local gx, gy = grid_xy(goal_idx, width)
	local open = {start_idx}
	local in_open = {[start_idx] = true}
	local came = {}
	local gscore = {[start_idx] = 0}
	local sx, sy = grid_xy(start_idx, width)
	local fscore = {[start_idx] = manhattan(sx, sy, gx, gy)}
	local dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	local expanded = 0
	while #open > 0 and expanded < ASTAR_MAX do
		expanded = expanded + 1
		local best_i = 1
		local best_f = fscore[open[1]] or 1e9
		for i = 2, #open do
			local f = fscore[open[i]] or 1e9
			if f < best_f then
				best_f = f
				best_i = i
			end
		end
		local current = table.remove(open, best_i)
		in_open[current] = nil
		if current == goal_idx then
			local path = {current}
			while came[path[1]] do
				table.insert(path, 1, came[path[1]])
			end
			return path
		end
		local cx, cy = grid_xy(current, width)
		local cur_pos = current == start_idx and from_pos or room:GetGridPosition(current)
		for d = 1, 4 do
			local nx = cx + dirs[d][1]
			local ny = cy + dirs[d][2]
			if nx >= 0 and ny >= 0 and nx < width and ny < height then
				local nidx = nx + ny * width
				local npos = room:GetGridPosition(nidx)
				if room:IsPositionInRoom(npos, 0) and line_clear(cur_pos, npos) then
					local ng = (gscore[current] or 1e9) + 1
					if ng < (gscore[nidx] or 1e9) then
						came[nidx] = current
						gscore[nidx] = ng
						fscore[nidx] = ng + manhattan(nx, ny, gx, gy)
						if not in_open[nidx] then
							open[#open + 1] = nidx
							in_open[nidx] = true
						end
					end
				end
			end
		end
	end
	return nil
end

local function simplify_waypoints(points)
	if not points or #points <= 2 then return points end
	local out = {points[1]}
	for i = 2, #points - 1 do
		local a, b, c = out[#out], points[i], points[i + 1]
		local d1 = b - a
		local d2 = c - b
		if math.abs(d1.X * d2.Y - d1.Y * d2.X) > 8 or (d1.X * d2.X + d1.Y * d2.Y) < 0 then
			out[#out + 1] = b
		end
	end
	out[#out + 1] = points[#points]
	return out
end

local function waypoint_length(from, wps)
	local len = 0
	local prev = from
	for i = 1, #(wps or {}) do
		len = len + (wps[i] - prev):Length()
		prev = wps[i]
	end
	return len
end

local function build_waypoints(tear, target)
	if not target then return nil end
	local to = target.Position
	if is_spectral(tear) or line_clear(tear.Position, to) then
		return {to}
	end
	local room = Game():GetRoom()
	if not room then return {to} end
	local start_idx = room:GetGridIndex(tear.Position)
	local goal_idx = room:GetGridIndex(to)
	local indices = astar_indices(room, start_idx, goal_idx, tear.Position)
	if not indices or #indices < 2 then
		return {to}
	end
	local wps = {}
	for i = 2, #indices do
		wps[#wps + 1] = room:GetGridPosition(indices[i])
	end
	wps[#wps] = to
	return simplify_waypoints(wps)
end

-- 把整段路径按 hop 切开，作为后续求索的路径点。
local function space_plan(from, path_pts, hop, mids)
	if not path_pts or #path_pts == 0 then return {from} end
	mids = tonumber(mids) or 0
	hop = tonumber(hop) or SEEK_FLIGHT_RANGE
	if mids <= 0 then return {path_pts[#path_pts]} end
	local plan = {}
	local acc = 0
	local prev = from
	local next_at = hop * 0.85
	local made = 0
	for i = 1, #path_pts do
		local p = path_pts[i]
		local seg = (p - prev):Length()
		if seg < 0.1 then
			prev = p
		else
			while made < mids and acc + seg >= next_at do
				local t = (next_at - acc) / seg
				plan[#plan + 1] = prev + (p - prev) * t
				made = made + 1
				next_at = next_at + hop * 0.85
			end
			acc = acc + seg
			prev = p
		end
	end
	local dest = path_pts[#path_pts]
	if #plan == 0 or (plan[#plan] - dest):Length() > 18 then
		plan[#plan + 1] = dest
	else
		plan[#plan] = dest
	end
	return plan
end

local function aim_at(tear, seek, pos, speed)
	local dir = pos - tear.Position
	if dir:Length() > 0.1 then
		tear.Velocity = dir:Normalized() * speed
	else
		tear.Velocity = auxi.MakeVector(seek.LastAngle or 0) * speed
	end
	seek.LastAngle = tear.Velocity:GetAngleDegrees()
end

local function follow_waypoints(tear, seek)
	local wps = seek.Waypoints
	if not wps or #wps == 0 then
		seek.Waypoints = nil
		return false
	end
	local speed = fallback_speed(tear, seek)
	local wp = wps[1]
	if (wp - tear.Position):Length() <= WAYPOINT_REACH then
		table.remove(wps, 1)
		if #wps == 0 then
			seek.Waypoints = nil
			seek.ReachedPlan = true
			return false
		end
	end
	if wps[1] then
		aim_at(tear, seek, wps[1], speed)
	end
	return true
end

local function path_wait(seek, player)
	if (seek.SearchCount or 0) > 0 then return SEEK_DELAY_AGAIN end
	local wait = SEEK_DELAY
	if player and player.MaxFireDelay then
		wait = math.max(SEEK_DELAY, player.MaxFireDelay * 1.3)
	end
	return wait
end

local function stall_and_fall(tear, seek)
	if not tear or not seek then return end
	restore_grid(tear, seek)
	seek.Stalling = true
	seek.Sliding = false
	seek.SlideSign = nil
	seek.WallInward = nil
	seek.WallClearFrames = 0
	seek.Waypoints = nil
	tear.Velocity = Vector(0, 0)
	local y = read_visual_y(tear)
	if y > -1 then y = choose_hold_y(tear, seek) end
	start_po_smooth(seek, read_visual_y(tear), y)
	seek.HoldFA = 0.28
	seek.HoldFS = 0.35
	apply_smoothed_air(tear, seek, 0.35)
end

local function continue_air(tear, seek, speed, travel)
	if not tear or not seek then return end
	local cur = read_visual_y(tear)
	local y = cur
	if y > MIN_AIR_Y then y = choose_hold_y(tear, seek) end
	travel = tonumber(travel) or SEEK_FLIGHT_RANGE
	if travel < SEEK_FLIGHT_RANGE then travel = SEEK_FLIGHT_RANGE end
	if travel > SEEK_FLIGHT_RANGE_MAX then travel = SEEK_FLIGHT_RANGE_MAX end
	local fa, fs = 0.5, 0
	if CraftTearParams and CraftTearParams.falling_for_range then
		fa, fs = CraftTearParams.falling_for_range(y, travel, nil, speed)
	end
	seek.HoldFA = fa
	seek.HoldFS = fs or 0
	start_po_smooth(seek, cur, y)
	apply_smoothed_air(tear, seek, seek.HoldFS)
end

local function heading_clear(tear, ang, dist)
	return not probe_blocked(tear, ang, dist)
end

-- 用一圈探针估墙的法线（指向墙内）。左右下上同一套，避免只搜 70° 斜向。
local function wall_inward_angle(tear, seek)
	local bx, by, n = 0, 0, 0
	for a = 0, 359, 45 do
		if probe_blocked(tear, a, WALL_LOOKAHEAD) then
			local d = auxi.MakeVector(a)
			bx = bx + d.X
			by = by + d.Y
			n = n + 1
		end
	end
	if n <= 0 or (bx * bx + by * by) < 0.04 then
		return nil
	end
	return Vector(bx, by):GetAngleDegrees()
end

local function toward_angle(tear, target)
	if not auxi.check_all_exists(target) then return nil end
	local to = target.Position - tear.Position
	if to:Length() < 0.2 then return nil end
	return to:GetAngleDegrees()
end

local function ang_abs(a)
	return math.abs(auxi.get_correct_angle(a))
end

local function travel_ang(inward, sign)
	return (inward or 0) + 90 * (sign or 1)
end

local function snap_oct(ang)
	ang = tonumber(ang) or 0
	local q = math.floor(ang / 45 + 0.5) * 45
	while q > 180 do q = q - 360 end
	while q <= -180 do q = q + 360 end
	return q
end

-- 墙的法线来自八向探针，不要用飞行朝向代替（否则切线永远是朝向±90°）。
local function impact_inward(tear, seek)
	local probed = wall_inward_angle(tear, seek)
	if probed ~= nil then return snap_oct(probed) end
	if seek and seek.WallInward ~= nil then return snap_oct(seek.WallInward) end
	local dir = heading_dir(tear, seek)
	if dir then return snap_oct(dir:GetAngleDegrees()) end
	return snap_oct((seek and seek.LastAngle) or 0)
end

local function tear_rng(tear, salt)
	local seed = math.floor((tonumber(tear and tear.InitSeed) or 1) + (tonumber(salt) or 0) * 16777619)
	seed = seed & 0xffffffff
	seed = seed ~ (seed >> 16)
	seed = (seed * 0x7feb352d) & 0xffffffff
	seed = seed ~ (seed >> 15)
	seed = (seed * 0x846ca68b) & 0xffffffff
	seed = seed ~ (seed >> 16)
	seed = seed & 0x7fffffff
	if seed == 0 then seed = 1 end
	local rng = RNG()
	rng:SetSeed(seed, 35)
	return rng
end

-- 沿墙切线：优先朝敌人；否则保留原飞行在墙面上的分量；再随机。
local function choose_first_sign(tear, seek, inward, target)
	local plus = travel_ang(inward, 1)
	local minus = travel_ang(inward, -1)
	local plus_ok = tangent_clear(tear, plus, WALL_LOOKAHEAD, inward)
	local minus_ok = tangent_clear(tear, minus, WALL_LOOKAHEAD, inward)
	if plus_ok and not minus_ok then return 1, plus end
	if minus_ok and not plus_ok then return -1, minus end
	local toward = toward_angle(tear, target)
	if toward then
		local dp = ang_abs(plus - toward)
		local dm = ang_abs(minus - toward)
		if dp + 25 < dm then return 1, plus end
		if dm + 25 < dp then return -1, minus end
	end
	local keep = seek and seek.LastAngle
	local dir = heading_dir(tear, seek)
	if dir then keep = dir:GetAngleDegrees() end
	if keep ~= nil then
		local dp = ang_abs(plus - keep)
		local dm = ang_abs(minus - keep)
		if dp + 8 < dm then return 1, plus end
		if dm + 8 < dp then return -1, minus end
	end
	local rng = tear_rng(tear, (seek and seek.SearchCount or 0) + 17)
	if rng:RandomInt(2) == 0 then
		return 1, plus
	end
	return -1, minus
end

local WALL_PROBE_KEYS = {
	"schema", "schema_version", "probe", "frame", "InitSeed",
	"reason", "posx", "posy", "vel", "heading", "inward", "size",
	"b0", "b45", "b90", "b135", "b180", "b225", "b270", "b315",
	"tplus", "tminus", "tplus_raw", "tminus_raw", "chosen", "ok",
	"sign", "mode", "travel",
}

local function wall_probe_escape(s)
	s = tostring(s or "")
	s = string.gsub(s, "\\", "\\\\")
	s = string.gsub(s, "\"", "\\\"")
	s = string.gsub(s, "\n", "\\n")
	return s
end

local function wall_probe_encode(row)
	local parts = {}
	for i = 1, #WALL_PROBE_KEYS do
		local k = WALL_PROBE_KEYS[i]
		local v = row[k]
		if v ~= nil then
			local ks = "\""..k.."\":"
			local vt = type(v)
			if vt == "number" then
				if v ~= v or v == math.huge or v == -math.huge then
					parts[#parts + 1] = ks.."null"
				elseif k == "frame" or k == "InitSeed" then
					parts[#parts + 1] = ks..string.format("%.0f", v)
				else
					parts[#parts + 1] = ks..string.format("%.4g", v)
				end
			elseif vt == "boolean" then
				parts[#parts + 1] = ks..(v and "true" or "false")
			else
				parts[#parts + 1] = ks.."\""..wall_probe_escape(v).."\""
			end
		end
	end
	return "{"..table.concat(parts, ",").."}"
end

local function wall_probe_write(row)
	if not dev_env.probes_allowed() then return end
	if not item.wall_probe_enabled then return end
	local line = wall_probe_encode(row)
	item.wall_probe_last = line
	local ok_write, err = pcall(function()
		if not io or not io.open then error("no io") end
		local paths = {
			"mods/Qing_remaster/codex_work/logs/seeker_wall_probe.jsonl",
			"../mods/Qing_remaster/codex_work/logs/seeker_wall_probe.jsonl",
		}
		local mode = item._wall_probe_ready and "a" or "w"
		local last_err = "open failed"
		for i = 1, #paths do
			local f = io.open(paths[i], mode)
			if f then
				f:write(line.."\n")
				f:close()
				item._wall_probe_ready = true
				item.wall_probe_count = (item.wall_probe_count or 0) + 1
				item.wall_probe_last_path = paths[i]
				item.wall_probe_last_err = ""
				return
			end
			last_err = paths[i]
		end
		error(last_err)
	end)
	if not ok_write then
		item.wall_probe_last_err = tostring(err or "write failed")
	end
end

local function wall_probe_log(tear, seek, extra)
	if not item.wall_probe_enabled or not tear then return end
	local vel = tear.Velocity
	local heading = seek and seek.LastAngle or 0
	if vel and vel:Length() >= 0.15 then heading = vel:GetAngleDegrees() end
	local inward = extra and extra.inward or (seek and seek.WallInward)
	if inward == nil then inward = wall_inward_angle(tear, seek) or heading end
	local blocked = {}
	local a = 0
	for i = 1, 8 do
		blocked[i] = probe_blocked(tear, a, WALL_LOOKAHEAD) and 1 or 0
		a = a + 45
	end
	local tplus = tangent_clear(tear, inward + 90, WALL_LOOKAHEAD, inward)
	local tminus = tangent_clear(tear, inward - 90, WALL_LOOKAHEAD, inward)
	local tplus_raw = heading_clear(tear, inward + 90, WALL_LOOKAHEAD)
	local tminus_raw = heading_clear(tear, inward - 90, WALL_LOOKAHEAD)
	local row = {
		schema = "seeker_wall_probe",
		schema_version = 2,
		probe = "seeker_wall",
		frame = now_frame(),
		InitSeed = tear.InitSeed or 0,
		reason = extra and extra.reason or "sample",
		posx = tear.Position.X,
		posy = tear.Position.Y,
		vel = vel and vel:Length() or 0,
		heading = heading,
		inward = inward,
		size = tonumber(tear.Size) or 0,
		b0 = blocked[1], b45 = blocked[2], b90 = blocked[3], b135 = blocked[4],
		b180 = blocked[5], b225 = blocked[6], b270 = blocked[7], b315 = blocked[8],
		tplus = tplus, tminus = tminus, tplus_raw = tplus_raw, tminus_raw = tminus_raw,
		chosen = extra and extra.chosen,
		ok = extra and extra.ok,
		sign = extra and extra.sign or (seek and seek.SlideSign),
		mode = extra and extra.mode,
		travel = extra and extra.travel or (seek and seek.LastAngle),
	}
	wall_probe_write(row)
end

local function start_wall_slide(tear, seek, speed, target, kind)
	if is_spectral(tear) then return false end
	kind = kind or "first"
	local inward = seek.WallInward
	local sign = seek.SlideSign
	local ang = nil
	if kind == "corner" then
		pull_into_room(tear, seek)
		inward = snap_oct(seek.LastAngle or impact_inward(tear, seek))
		sign = sign or 1
		ang = snap_oct(travel_ang(inward, sign))
		if is_buried(tear) then
			unstick_from_wall(tear, inward)
		end
		if not tangent_clear(tear, ang, WALL_LOOKAHEAD, inward) then
			local other = -sign
			local other_ang = snap_oct(travel_ang(inward, other))
			if tangent_clear(tear, other_ang, WALL_LOOKAHEAD, inward) then
				sign = other
				ang = other_ang
			end
		end
	else
		if kind == "first" or inward == nil then
			inward = seek.WallInward or impact_inward(tear, seek)
		end
		inward = snap_oct(inward)
		if is_buried(tear) then
			unstick_from_wall(tear, inward)
		end
		if sign == nil or kind == "first" then
			sign, ang = choose_first_sign(tear, seek, inward, target)
		else
			ang = snap_oct(travel_ang(inward, sign))
			if not tangent_clear(tear, ang, WALL_LOOKAHEAD, inward) then
				sign, ang = choose_first_sign(tear, seek, inward, target)
			end
		end
	end
	if ang == nil or sign == nil then
		inward = snap_oct(inward or impact_inward(tear, seek))
		sign = sign or 1
		ang = snap_oct(travel_ang(inward, sign))
	end
	ang = snap_oct(ang)
	restore_grid(tear, seek)
	speed = speed or fallback_speed(tear, seek)
	seek.Stalling = false
	seek.Sliding = true
	seek.WallInward = inward
	seek.SlideSign = sign
	seek.WallClearFrames = 0
	seek.CornerLock = 2
	seek.SlideTargetHash = auxi.check_all_exists(target) and GetPtrHash(target) or nil
	tear.Velocity = auxi.MakeVector(ang) * speed
	seek.LastAngle = ang
	continue_air(tear, seek, speed, SEEK_FLIGHT_RANGE)
	wall_probe_log(tear, seek, {
		reason = "slide_ok",
		chosen = ang,
		ok = true,
		mode = kind,
		sign = sign,
		travel = ang,
		inward = inward,
	})
	return true
end

local function tick_wall_slide(tear, seek, target)
	if not seek.Sliding then return false end
	local sign = seek.SlideSign
	if sign == nil then
		return start_wall_slide(tear, seek, fallback_speed(tear, seek), target, "first")
	end
	local travel = seek.LastAngle or travel_ang(seek.WallInward or 0, sign)
	local inward = seek.WallInward or (travel - 90 * sign)
	local speed = fallback_speed(tear, seek)
	local look = WALL_LOOKAHEAD
	if speed + 8 > look then look = speed + 8 end
	if not room_contains(tear.Position) then
		pull_into_room(tear, seek)
		start_wall_slide(tear, seek, speed, target, "corner")
		return true
	end
	if is_buried(tear) then
		unstick_from_wall(tear, inward)
		if item.wall_probe_enabled and ((tear.FrameCount or 0) % 8) == 0 then
			wall_probe_log(tear, seek, {reason = "buried_unstick", ok = true, mode = "unstick", sign = sign, travel = travel, inward = inward})
		end
	end
	local ahead = tear.Position + auxi.MakeVector(travel) * look
	local blocked_ahead = (not tangent_clear(tear, travel, look, inward)) or (not room_contains(ahead))
	if (seek.CornerLock or 0) > 0 then
		seek.CornerLock = seek.CornerLock - 1
	elseif blocked_ahead or is_buried(tear) then
		start_wall_slide(tear, seek, speed, target, "corner")
		return true
	end
	local hand = travel - 90 * sign
	if probe_blocked(tear, hand, WALL_LOOKAHEAD) then
		seek.WallInward = hand
	end
	tear.Velocity = auxi.MakeVector(travel) * speed
	seek.LastAngle = travel
	return true
end

local function mark_seek(tear, seek)
	local before = seek.SearchCount or 0
	seek.SearchCount = math.min(MAX_SEEK, before + 1)
	if seek.SearchCount > before then
		tear.Scale = (tear.Scale or 1) * (1 + 0.08 * seek.SearchCount) / (1 + 0.08 * before)
		if seek.SearchCount >= 3 then seek.TrailFade = 0 end
	end
	apply_damage(tear, seek)
end

local function finish_seek(tear, seek, player)
	seek.SeekingFrames = 0
	local speed = fallback_speed(tear, seek)
	local radius = seek_aim_range(seek)
	local target = find_target(tear, seek, radius)
	local blocked = seek.BlockedAtSeek or cannot_advance(tear, seek) or wall_close(tear, seek)
	seek.BlockedAtSeek = false
	if auxi.check_all_exists(target) then
		local path = build_waypoints(tear, target)
		local mids = math.max(0, hops_left(seek) - 1)
		local plan = space_plan(tear.Position, path or {target.Position}, SEEK_FLIGHT_RANGE, mids)
		local first = plan and plan[1]
		local inward = seek.WallInward or impact_inward(tear, seek)
		local into_wall = false
		if first and blocked then
			local to = first - tear.Position
			if to:Length() > 0.2 and inward ~= nil then
				local inn = auxi.MakeVector(inward)
				local nd = to:Normalized()
				into_wall = (nd.X * inn.X + nd.Y * inn.Y) > 0.2
			end
		end
		local can_leave = first and not into_wall and (is_spectral(tear) or line_clear(tear.Position, first))
		if blocked and not can_leave then
			local kind = seek.SlideSign and "resume" or "first"
			if not start_wall_slide(tear, seek, speed, target, kind) then
				seek.LastSeekMissed = true
				wall_probe_log(tear, seek, {reason = "stall_blocked_target", ok = false, mode = kind})
				stall_and_fall(tear, seek)
			else
				seek.LastSeekMissed = false
			end
		else
			tear.Velocity = Vector(0, 0)
			spawn_scan(player, tear)
			seek.LastSeekMissed = false
			seek.Sliding = false
			seek.SlideSign = nil
			seek.WallInward = nil
			seek.WallClearFrames = 0
			restore_grid(tear, seek)
			seek.Plan = plan
			seek.Waypoints = first and {first} or path
			aim_at(tear, seek, first or target.Position, speed)
			continue_air(tear, seek, speed, SEEK_FLIGHT_RANGE)
			mark_seek(tear, seek)
		end
	else
		seek.Waypoints = nil
		seek.Plan = nil
		if blocked then
			local kind = seek.SlideSign and "resume" or "first"
			if not start_wall_slide(tear, seek, speed, nil, kind) then
				seek.LastSeekMissed = true
				wall_probe_log(tear, seek, {reason = "stall_blocked_notarget", ok = false, mode = kind})
				stall_and_fall(tear, seek)
			else
				seek.LastSeekMissed = false
			end
		else
			seek.LastSeekMissed = true
			local ang = seek.LastAngle or tear.Velocity:GetAngleDegrees()
			restore_grid(tear, seek)
			tear.Velocity = auxi.MakeVector(ang) * speed
			seek.LastAngle = tear.Velocity:GetAngleDegrees()
			continue_air(tear, seek, speed, SEEK_FLIGHT_RANGE)
		end
	end
	seek.SearchCooldown = SEEK_COOLDOWN
	seek.StoredSpeed = speed
	reset_progress(seek)
	apply_visual(tear, seek)
end

local function begin_seek(tear, seek, player)
	seek.StoredSpeed = fallback_speed(tear, seek)
	local vel = tear.Velocity
	if vel and vel:Length() >= 0.2 then
		seek.LastAngle = vel:GetAngleDegrees()
	end
	seek.Waypoints = nil
	seek.Stalling = false
	seek.HoldFA = tear.FallingAcceleration
	seek.HoldFS = 0
	local cur = read_visual_y(tear)
	start_po_smooth(seek, cur, choose_hold_y(tear, seek))
	local spd = vel and vel:Length() or 0
	local dist = wall_distance(tear, seek, brake_horizon(math.max(spd, seek.StoredSpeed or 0)))
	seek.BlockedAtSeek = should_start_wall_brake(tear, seek) or cannot_advance(tear, seek)
	hold_air(tear, seek)
	seek.SlowFrom = spd
	if seek.SlowFrom < 1 then seek.SlowFrom = seek.StoredSpeed end
	seek.SlowDir = seek.LastAngle or 0
	if seek.BlockedAtSeek then
		local inward = impact_inward(tear, seek)
		seek.WallInward = inward
		local need = (dist or 0) - TURN_MARGIN
		if need < 0 then need = 0 end
		local n = 0
		if dist and spd >= 0.2 then
			n = frames_for_brake(spd, need)
		end
		local imminent = math.max(8, spd * 1.1)
		if n <= 0 or (dist and dist <= imminent) or spd < 0.2 then
			if spd < 0.2 and not (dist and dist <= imminent) then
				tear.Velocity = Vector(0, 0)
				seek.SlowFrom = 0
				seek.SeekingFrames = WALL_PAUSE
				seek.SeekingTotal = WALL_PAUSE
				wall_probe_log(tear, seek, {reason = "wall_pause", ok = true, mode = seek.SlideSign and "resume" or "first", inward = inward})
			else
				seek.SeekingFrames = 0
				seek.SeekingTotal = 0
				wall_probe_log(tear, seek, {reason = "wall_emergency", ok = true, mode = "skip_pause", inward = inward})
				finish_seek(tear, seek, player)
				return
			end
		else
			seek.SlowFrom = spd
			seek.SeekingFrames = n
			seek.SeekingTotal = n
			wall_probe_log(tear, seek, {reason = "wall_pause", ok = true, mode = "brake", inward = inward})
		end
	else
		seek.Sliding = false
		seek.SlideSign = nil
		seek.WallInward = nil
		seek.WallClearFrames = 0
		restore_grid(tear, seek)
		seek.SeekingFrames = SEEK_PAUSE
		seek.SeekingTotal = SEEK_PAUSE
	end
	seek.LastMissedHash = seek.LastTrackHash
	apply_visual(tear, seek)
end

local function lock_base(tear, seek)
	if seek.BaseLocked then return end
	seek.BaseDamage = tear.CollisionDamage
	seek.BaseScale = tear.Scale
	local speed = tear.Velocity:Length()
	if speed > (seek.StoredSpeed or 0) then seek.StoredSpeed = speed end
	if (tear.FrameCount or 0) >= 1 then
		seek.LaunchY = read_visual_y(tear)
		seek.LaunchFA = tear.FallingAcceleration
		seek.LaunchFS = tear.FallingSpeed or 0
		seek.HoldFA = seek.LaunchFA
		seek.BaseLocked = true
	end
end

local function note_bounce(tear, seek)
	local flags = TearFlags
	if not flags then return false end
	local bouncing = (flags.TEAR_BOUNCE and has_tear_flag(tear, flags.TEAR_BOUNCE))
		or (flags.TEAR_BOUNCE_WALLSONLY and has_tear_flag(tear, flags.TEAR_BOUNCE_WALLSONLY))
	if not bouncing then return false end
	local ang = tear.Velocity:GetAngleDegrees()
	local last = seek.LastAngle
	if last ~= nil then
		local delta = math.abs(auxi.get_correct_angle(ang - last))
		if delta >= BOUNCE_ANGLE then
			reset_progress(seek)
			seek.StoredSpeed = math.max(seek.StoredSpeed or 0, tear.Velocity:Length())
			seek.LastAngle = ang
			return true
		end
	end
	seek.LastAngle = ang
	return false
end

function item.Seeker_link(player, pos1, pos2, col, dmg, params)
	params = params or {}
	local q1 = Isaac.Spawn(1000, enums.Entities.MeusLink, 0, pos1 * 0.4 + pos2 * 0.6, Vector(0, 0), player)
	local s1 = q1:GetSprite()
	local dir = pos2 - pos1
	local ang = dir:GetAngleDegrees()
	local leg = dir:Length() + 5
	s1.Rotation = ang - 90
	s1.Color = params.c1 or Color(1, 1, 1, 0.3, 1, 1, 1)
	s1.Scale = auxi.mul_t(Vector(leg / 120, 1 / 10), params.Scaler or Vector(1.3, 1))
	if params.NoS2 ~= true then
		local q2 = Isaac.Spawn(1000, enums.Entities.MeusLink, 0, pos2, Vector(0, 0), player)
		local s2 = q2:GetSprite()
		s2.Rotation = ang + auxi.random_0() * 180
		s2.Color = params.c2 or Color(1, 1, 1, 0.5, 1, 1, 1)
		s2.Scale = auxi.mul_t(Vector(1 / 5, 1 / 10), params.Scaler or Vector(1.3, 1))
	end
	if col then col:TakeDamage(dmg, 0, EntityRef(player), 0) end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_FIRE_TEAR, params = nil,
Function = function(_, ent)
	local player = auxi.check_spawner_player(ent)
	if not player or not auxi.has_have_coll(player, item.entity) then return end
	if is_unsupported_tear(ent) then return end
	local d = ent:GetData()
	d[EFFECT_KEY] = true
	d[DATA_KEY] = {
		SearchCount = 0,
		SearchCooldown = FIRST_CHECK,
		BestDistance = nil,
		LastProgressFrame = now_frame(),
		SeekingFrames = 0,
		StoredSpeed = ent.Velocity:Length(),
		BaseDamage = ent.CollisionDamage,
		BaseScale = ent.Scale,
		DamageMult = 1,
		LastMissedHash = nil,
		LastTrackHash = nil,
		LastAngle = ent.Velocity:GetAngleDegrees(),
		BaseLocked = false,
		LastSeekMissed = false,
		Stalling = false,
		HadAhead = false,
		BlockedAtSeek = false,
		StuckFrames = 0,
		Sliding = false,
		SlideSign = nil,
		WallClearFrames = 0,
		ReachedPlan = false,
		TrailFade = 0,
	}
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_, ent, col, low)
	local d = ent:GetData()
	local seek = d[DATA_KEY]
	if not seek then return end
	if not col or not auxi.isenemies(col) then return end
	seek.LastMissedHash = GetPtrHash(col)
	reset_progress(seek)
end,
})

if REPENTOGON and ModCallbacks.MC_PRE_TEAR_UPDATE then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_UPDATE, params = nil,
	Function = function(_, ent)
		if not ent then return end
		local d = ent:GetData()
		local seek = d[DATA_KEY]
		if not seek or not d[EFFECT_KEY] then return end
		if (seek.SeekingFrames or 0) > 0 then
			hold_air(ent, seek)
		elseif (seek.SmoothLeft or 0) > 0 then
			write_held_air(ent, seek)
		end
	end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_, ent)
	local d = ent:GetData()
	if d.Ignore_me_flag ~= nil or not d[EFFECT_KEY] then return end
	local seek = d[DATA_KEY]
	if not seek then return end
	if not auxi.check_all_exists(ent) or ent:IsDead() then
		clear_trail(seek)
		return
	end
	if is_unsupported_tear(ent) then
		clear_trail(seek)
		d[EFFECT_KEY] = nil
		return
	end
	local player = auxi.check_spawner_player(ent)
	lock_base(ent, seek)
	if (seek.SearchCooldown or 0) > 0 then
		seek.SearchCooldown = seek.SearchCooldown - 1
	end
	if (seek.SeekingFrames or 0) > 0 then
		apply_smoothed_air(ent, seek, 0)
		local total = seek.SeekingTotal or SEEK_PAUSE
		if total < 1 then total = 1 end
		local t = 1 - (seek.SeekingFrames / total)
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
		t = t * t
		local from = seek.SlowFrom or fallback_speed(ent, seek)
		local speed = from * (1 - (1 - SLOW_END_MUL) * t)
		if (from or 0) > 0.2 then
			local imminent = math.max(8, speed * 1.1)
			if wall_ahead(ent, imminent, seek) then
				seek.BlockedAtSeek = true
				seek.WallInward = impact_inward(ent, seek)
				seek.SeekingFrames = 0
				wall_probe_log(ent, seek, {reason = "wall_emergency", ok = true, mode = "abort_brake", inward = seek.WallInward})
				finish_seek(ent, seek, player)
				return
			end
		end
		ent.Velocity = auxi.MakeVector(seek.SlowDir or seek.LastAngle or 0) * speed
		seek.SeekingFrames = seek.SeekingFrames - 1
		if seek.SeekingFrames <= 0 then
			finish_seek(ent, seek, player)
		else
			apply_visual(ent, seek)
		end
		return
	end
	if (seek.SmoothLeft or 0) > 0 then
		apply_smoothed_air(ent, seek)
	end
	if seek.Stalling then
		if ent.Velocity:Length() > 0.15 then
			ent.Velocity = ent.Velocity * 0.8
		else
			ent.Velocity = Vector(0, 0)
		end
		apply_visual(ent, seek)
		return
	end
	if note_bounce(ent, seek) then
		seek.Waypoints = nil
	end
	local wall_tgt = find_target(ent, seek, seek_aim_range(seek))
	if seek.Sliding then
		if not tick_wall_slide(ent, seek, wall_tgt) then
			stall_and_fall(ent, seek)
			apply_visual(ent, seek)
			return
		end
		if item.wall_probe_enabled and ent.Velocity:Length() < 0.3 then
			local fr = ent.FrameCount or 0
			if (fr % 8) == 0 then
				wall_probe_log(ent, seek, {reason = "slide_stuck", ok = false, chosen = seek.LastAngle})
			end
		end
	end
	follow_waypoints(ent, seek)
	apply_visual(ent, seek)
	local blocked = should_start_wall_brake(ent, seek) or cannot_advance(ent, seek)
	if blocked then
		seek.StuckFrames = (seek.StuckFrames or 0) + 1
	else
		seek.StuckFrames = 0
	end
	if blocked and not seek.Sliding then
		local can_turn = auxi.check_all_exists(wall_tgt)
			and (is_spectral(ent) or line_clear(ent.Position, wall_tgt.Position))
		if can_turn then
			-- 目标方向通路开着：不要沿墙乱拐，交给求索转向。
		elseif (seek.SearchCount or 0) >= MAX_SEEK then
			wall_probe_log(ent, seek, {reason = "stall_max_seek", ok = false})
			stall_and_fall(ent, seek)
			apply_visual(ent, seek)
			return
		elseif seek.SlideSign then
			-- 已经在沿墙：角上换边，不要再整段停顿。
			if not start_wall_slide(ent, seek, fallback_speed(ent, seek), wall_tgt, "resume") then
				stall_and_fall(ent, seek)
			end
			apply_visual(ent, seek)
			return
		else
			begin_seek(ent, seek, player)
			apply_visual(ent, seek)
			return
		end
	end
	if seek.Sliding then
		if (seek.SearchCount or 0) >= MAX_SEEK then return end
		if (seek.SearchCooldown or 0) > 0 then return end
		if auxi.check_all_exists(wall_tgt)
			and (is_spectral(ent) or line_clear(ent.Position, wall_tgt.Position)) then
			local to = wall_tgt.Position - ent.Position
			local inward = seek.WallInward
			local into = false
			if inward ~= nil and to:Length() > 0.2 then
				local inn = auxi.MakeVector(inward)
				local nd = to:Normalized()
				into = (nd.X * inn.X + nd.Y * inn.Y) > 0.2
			end
			local travel = seek.LastAngle or 0
			local face = to:Length() > 0.2 and to:GetAngleDegrees() or travel
			if not into and ang_abs(face - travel) <= 50 then
				seek.Sliding = false
				seek.SlideSign = nil
				seek.WallInward = nil
				restore_grid(ent, seek)
				aim_at(ent, seek, wall_tgt.Position, fallback_speed(ent, seek))
				continue_air(ent, seek, fallback_speed(ent, seek), SEEK_FLIGHT_RANGE)
			end
		end
		return
	end
	if (seek.SearchCount or 0) >= MAX_SEEK then return end
	if (seek.SearchCooldown or 0) > 0 then return end
	if (ent.FrameCount or 0) < FIRST_CHECK then return end
	if seek.ReachedPlan then
		seek.ReachedPlan = false
		begin_seek(ent, seek, player)
		return
	end
	local check_every = CHECK_INTERVAL
	if seek.HadAhead or (seek.SearchCount or 0) > 0 then check_every = 1 end
	if ((ent.FrameCount or 0) + (ent.InitSeed or 0)) % check_every ~= 0 then return end
	local reach = remaining_range(ent, seek)
	local aim = seek_aim_range(seek)
	local none_ahead, behind, behind_d = no_enemies_ahead(ent, reach, seek)
	local ahead, ahead_d = nearest_ahead(ent, reach, seek)
	local far_target = find_target(ent, seek, aim)
	local wait = path_wait(seek, player)
	local waited = now_frame() - (seek.LastProgressFrame or 0) >= wait
	local approaching = false
	local receding = false
	if ahead then
		seek.HadAhead = true
		seek.LastTrackHash = GetPtrHash(ahead)
		seek.LastSeekMissed = false
		if seek.BestDistance == nil or ahead_d < (seek.BestDistance - 1) then
			seek.BestDistance = ahead_d
			seek.LastProgressFrame = now_frame()
			approaching = true
		elseif ahead_d > (seek.BestDistance + 2) then
			receding = true
		end
	end
	-- 当前 hop 打不到人、但 3 次求索范围内有人：该求索。首次仍等 path_wait。
	local _, near_any = find_target(ent, seek, reach)
	if not near_any and auxi.check_all_exists(far_target) then
		if (seek.SearchCount or 0) > 0 or waited then
			begin_seek(ent, seek, player)
			return
		end
	end
	-- 正在逼近且当前弹道还飞得到：不求索。
	if approaching and not receding and ahead_d <= reach + 8 then return end
	local grazed = receding or (seek.HadAhead and none_ahead)
	if none_ahead and behind and (behind_d or 0) < GRAZE_DIST then
		grazed = true
	end
	if grazed then
		if now_frame() - (seek.LastProgressFrame or 0) >= GRAZE_DELAY then
			begin_seek(ent, seek, player)
		end
		return
	end
	if none_ahead then
		if seek.LastSeekMissed and not far_target then return end
		if not waited and not far_target then return end
		begin_seek(ent, seek, player)
		return
	end
	if waited then
		begin_seek(ent, seek, player)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = EntityType.ENTITY_TEAR,
Function = function(_, ent)
	if not ent then return end
	local d = ent:GetData()
	clear_trail(d[DATA_KEY])
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_TEAR_RENDER, params = nil,
Function = function(_, ent, offset)
	if not ent then return end
	local room = Game():GetRoom()
	if room and room.GetRenderMode and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	local d = ent:GetData()
	local seek = d[DATA_KEY]
	if not seek or not d[EFFECT_KEY] then return end
	local n = seek.SearchCount or 0
	local seeking = (seek.SeekingFrames or 0) > 0
	if n <= 0 and not seeking then return end
	local spr = ensure_glow_sprite()
	if not spr then return end
	local alpha = 0.16 + 0.14 * n
	if seeking then alpha = math.min(0.7, alpha + 0.12) end
	local scale = (0.24 + 0.08 * n) * (ent.Scale or 1)
	if seeking then scale = scale * 1.1 end
	spr.Scale = Vector(scale, scale)
	local w = 0.12 * n
	local col = Color(1, 1, 1, alpha, w, w, w)
	if col.SetColorize then
		col:SetColorize(0.7, 0.7, 0.7, 0.16 + 0.1 * n)
	end
	spr.Color = col
	spr:SetFrame(0)
	local po = ent.PositionOffset or Vector(0, 0)
	local visual = Vector(po.X, po.Y)
	if math.abs(visual.Y) < 0.5 then
		visual = Vector(0, read_visual_y(ent))
	end
	-- W2S 已是窗口坐标；POST offset 在大房间会再带 GetRenderScrollOffset。
	-- 必须减回 scroll，否则光球会多吃一次镜头位移。PO 走 W2S，禁止当屏幕 px 外加。
	local pos = Isaac.WorldToScreen(ent.Position + visual)
	if offset then pos = pos + offset end
	if room and room.GetRenderScrollOffset then
		pos = pos - room:GetRenderScrollOffset()
	end
	spr:Render(pos, Vector(0, 0), Vector(0, 0))
end,
})

function item.set_wall_probe_enabled(on)
	if not dev_env.probes_allowed() then
		item.wall_probe_enabled = false
		return
	end
	item.wall_probe_enabled = on == true
	item._wall_probe_ready = false
	item.wall_probe_last_err = ""
	if item.wall_probe_enabled then
		item.wall_probe_count = 0
		item.wall_probe_last = ""
	end
end

function item.get_wall_probe_summary()
	local on = item.wall_probe_enabled == true
	local n = item.wall_probe_count or 0
	local path = item.wall_probe_last_path or ""
	local err = item.wall_probe_last_err or ""
	if err ~= "" then
		return string.format("探针%s 样本=%d 错误=%s", on and "开启" or "关闭", n, err)
	end
	if path == "" then
		return string.format("探针%s 样本=%d 尚未写入", on and "开启" or "关闭", n)
	end
	return string.format("探针%s 样本=%d 路径=%s", on and "开启" or "关闭", n, path)
end

function item.clear_wall_probe()
	item.wall_probe_count = 0
	item.wall_probe_last = ""
	item.wall_probe_last_err = ""
	item._wall_probe_ready = false
	if not dev_env.probes_allowed() then return end
	pcall(function()
		if not io or not io.open then return end
		local paths = {
			"mods/Qing_remaster/codex_work/logs/seeker_wall_probe.jsonl",
			"../mods/Qing_remaster/codex_work/logs/seeker_wall_probe.jsonl",
		}
		for i = 1, #paths do
			local f = io.open(paths[i], "w")
			if f then
				f:close()
				item.wall_probe_last_path = paths[i]
				return
			end
		end
	end)
end

return item

-- Craft Watcher Network: shared controller + always-on Flight surveillance nodes.
-- Fixed craft range (no velocity awake FSM). Camera/halo render on MeusNil Effect.

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CraftIdentity = require("Qing_Remaster_scripts.mimics.craft_identity")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")
local Common = require("Qing_Remaster_scripts.mimics.watcher_common")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Watcher_holder_",
	-- Craft-only coverage (do not reuse player Watcher expand curve).
	CRAFT_RANGE = 160,
	CRAFT_RETENTION_MUL = 1.20,
	WATCHER_DEPTH = 2,
	CAMERA_OFFSET = Vector(0, -18),
}

local TRACK = Common.TRACK

local MEUS_NIL_VARIANT = enums.Entities.ID_EFFECT_MeusNIL
if not MEUS_NIL_VARIANT or MEUS_NIL_VARIANT < 0 then
	MEUS_NIL_VARIANT = 2338
end

local function W()
	return package.loaded["Qing_Remaster_scripts.items.Item_The_Watcher"]
		or require("Qing_Remaster_scripts.items.Item_The_Watcher")
end

local function BP()
	local ok, bp = pcall(require, "Qing_Remaster_scripts.items.Item_Blue_Print")
	if ok then return bp end
end

local function cfg()
	return W() or {}
end

local function ctrl_key()
	return item.own_key .. "controller"
end

local function ensure_controller(player)
	if not player then return nil end
	local d = player:GetData()
	local key = ctrl_key()
	local c = d[key]
	if type(c) ~= "table" then
		c = {nodes = {}, targets = {}, age = 0}
		d[key] = c
	end
	c.nodes = c.nodes or {}
	c.targets = c.targets or {}
	return c
end

local function air_uid(air)
	return air and CraftIdentity.get_uid(air) or nil
end

local function air_damage(air, owner)
	local prof = CraftIdentity.get_profile(air)
	local dmg = prof and prof.stats and tonumber(prof.stats.damage)
	if dmg then return dmg end
	if owner then return tonumber(owner.Damage) or 3.5 end
	return 3.5
end

local function explosion_damage_from_base(base)
	local w = cfg()
	return (tonumber(base) or 3.5) * (w.explosion_mul or 4) + (w.explosion_flat or 20)
end

local function craft_acq()
	return item.CRAFT_RANGE
end

local function craft_ret()
	return item.CRAFT_RANGE * item.CRAFT_RETENTION_MUL
end

local function new_sprite(path, anim)
	local spr = Sprite()
	spr:Load(path, true)
	if anim then spr:Play(anim, true) end
	return spr
end

local function play_anim(spr, anim, force)
	if not spr or not anim then return end
	if force or not spr:IsPlaying(anim) then
		spr:Play(anim, true)
	end
end

local function world_radius_to_render_px(center_world, world_r, offset)
	offset = offset or Vector(0, 0)
	local a = Isaac.WorldToRenderPosition(center_world) + offset
	local b = Isaac.WorldToRenderPosition(center_world + Vector(world_r, 0)) + offset
	return (b - a):Length()
end

function item.count_allocated_watchers(player)
	local wid = enums.Items.The_Watcher
	if not wid or wid <= 0 or not player then return 0 end
	local bp = BP()
	if not bp or not bp.count_allocated then return 0 end
	local used = bp.count_allocated(player)
	return tonumber(used and used[wid]) or 0
end

function item.player_has_active_node(player)
	local c = player and player:GetData()[ctrl_key()]
	if type(c) ~= "table" or type(c.nodes) ~= "table" then return false end
	for _, node in pairs(c.nodes) do
		if node and node.active and node.air and auxi.check_all_exists(node.air) then
			return true
		end
	end
	return false
end

function item.player_watcher_is_redirected(player)
	local wid = enums.Items.The_Watcher
	if not wid or wid <= 0 or not player then return false end
	local owned = player:GetCollectibleNum(wid, true) or 0
	if owned <= 0 then return false end
	return item.count_allocated_watchers(player) >= owned
end

local function release_node_nil(node)
	local ent = node and node.nil_ent
	if ent and ent.Exists and ent:Exists() then
		local nd = ent:GetData()
		nd.removecd = 0
		nd[item.own_key .. "cam"] = nil
		nd[item.own_key .. "node_uid"] = nil
		ent:Remove()
	end
	if node then
		node.nil_ent = nil
		node.nil_ptr = nil
	end
end

local function sync_nil_to_air(ent, air)
	if not ent or not air then return end
	ent.Position = air.Position
	ent.PositionOffset = air.PositionOffset or Vector.Zero
	ent.Velocity = air.Velocity or Vector.Zero
	ent.DepthOffset = (tonumber(air.DepthOffset) or 0) + item.WATCHER_DEPTH
	ent.Visible = true
	local spr = ent:GetSprite()
	if spr then
		spr.Color = Color(1, 1, 1, 0.01)
		spr.Scale = Vector(1, 1)
	end
end

local function ensure_node_nil(node, owner)
	if not node or not node.air or not auxi.check_all_exists(node.air) then return nil end
	local air = node.air
	local ent = node.nil_ent
	if not (ent and ent.Exists and ent:Exists() and node.nil_ptr == GetPtrHash(ent)) then
		ent = Isaac.Spawn(EntityType.ENTITY_EFFECT, MEUS_NIL_VARIANT, 0, air.Position, Vector.Zero, owner)
		if ent.ToEffect then ent = ent:ToEffect() or ent end
		ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
		ent.Visible = true
		local nd = ent:GetData()
		nd[item.own_key .. "cam"] = true
		nd[item.own_key .. "node_uid"] = node.uid
		nd.nil_mode = "visual_only"
		nd.skip_nil_distance_cull = true
		nd.Params = nd.Params or {}
		nd.Params.player = owner
		nd.Params.air = air
		nd.removecd = 999999
		nd[Nil_holder.own_key .. "work"] = function() return true end
		node.nil_ent = ent
		node.nil_ptr = GetPtrHash(ent)
		if not node.sprite then
			node.sprite = new_sprite(cfg().anm2 or "gfx/mimics/The_Watcher/the_watcher.anm2", "Watching")
			node.body_anim = "Watching"
		end
		if not node.halo_spr then
			node.halo_spr = new_sprite(cfg().halo_anm2 or "gfx/effects/Halo/Halo_Watcher.anm2", "Idle")
		end
	end
	sync_nil_to_air(ent, air)
	local nd = ent:GetData()
	nd.removecd = 999999
	nd[item.own_key .. "cam"] = true
	nd[item.own_key .. "node_uid"] = node.uid
	nd.Params = nd.Params or {}
	nd.Params.player = owner
	nd.Params.air = air
	return ent
end

local function remove_node(ctrl, uid)
	local node = ctrl.nodes[uid]
	if not node then return end
	release_node_nil(node)
	ctrl.nodes[uid] = nil
end

function item.release_for_air(air)
	local player = auxi.check_spawner_player(air) or (air and air.Player)
	if not player then return end
	local uid = air_uid(air)
	if not uid then return end
	local ctrl = player:GetData()[ctrl_key()]
	if type(ctrl) == "table" then
		remove_node(ctrl, uid)
		remove_node(ctrl, tostring(uid))
	end
end

function item.sync_air_flight(air, player, profile)
	if not air or not player then return end
	local uid = air_uid(air)
	if not uid then return end
	local wid = enums.Items.The_Watcher
	local counts = profile and profile.counts
	local n = 0
	if wid and wid > 0 and counts then
		n = tonumber(counts[wid]) or 0
	end
	local ctrl = ensure_controller(player)
	if n <= 0 then
		remove_node(ctrl, uid)
		return
	end
	local node = ctrl.nodes[uid]
	if not node then
		node = {uid = uid}
		ctrl.nodes[uid] = node
	end
	node.air = air
	node.active = true
	node.profile = profile
	ensure_node_nil(node, player)
	if not node.sprite then
		node.sprite = new_sprite(cfg().anm2 or "gfx/mimics/The_Watcher/the_watcher.anm2", "Watching")
		node.body_anim = "Watching"
	elseif node.body_anim ~= "Shoot" then
		play_anim(node.sprite, "Watching", false)
		node.body_anim = "Watching"
	end
end

local function tick_node(node, owner)
	if not node or not node.air or not auxi.check_all_exists(node.air) then
		if node then node.active = false end
		return false
	end
	node.active = true
	ensure_node_nil(node, owner)
	-- Shoot → Watching
	if node.body_anim == "Shoot" and node.sprite then
		node.fire_age = (node.fire_age or 0) + 1
		local end_fr = (cfg().shoot_end_frame or 70)
		if node.sprite:IsFinished("Shoot") or node.fire_age >= end_fr then
			play_anim(node.sprite, "Watching", true)
			node.body_anim = "Watching"
			node.fire_age = nil
		elseif node.sprite.Update then
			node.sprite:Update()
		end
	elseif node.sprite and node.sprite.Update then
		node.sprite:Update()
	end
	if node.halo_spr and node.halo_spr.Update then
		node.halo_spr:Update()
	end
	return true
end

local function collect_active_nodes(ctrl, owner)
	local list = {}
	for uid, node in pairs(ctrl.nodes) do
		if tick_node(node, owner) then
			list[#list + 1] = node
		else
			release_node_nil(node)
			ctrl.nodes[uid] = nil
		end
	end
	return list
end

local function target_key_ent(ent, kind)
	return (kind == "player" and "p:" or "e:") .. tostring(GetPtrHash(ent))
end

local function coverage_for(ent, nodes)
	local acq = craft_acq()
	local ret = craft_ret()
	local in_acq, in_ret = false, false
	local best_node, best_mul, best_dist = nil, 0, 1e9
	local count = 0
	local pos = ent.Position
	local w = cfg()
	for i = 1, #nodes do
		local node = nodes[i]
		local air = node.air
		local dist = pos:Distance(air.Position)
		if dist <= acq then
			in_acq = true
			count = count + 1
			local mul = Common.lock_speed_mul(dist, acq)
			if mul > best_mul or (mul == best_mul and dist < best_dist) then
				best_mul = mul
				best_dist = dist
				best_node = node
			end
		end
		if dist <= ret then
			in_ret = true
			if not best_node then
				best_node = node
				best_dist = dist
				best_mul = Common.lock_speed_mul(dist, acq)
			end
		end
	end
	-- fallback mul if inside but lock_speed_mul returned 0 (far edge)
	if in_acq and best_node and (best_mul or 0) <= 0 then
		best_mul = 0.45
	end
	return {
		in_acq = in_acq,
		in_ret = in_ret,
		count = count,
		best_node = best_node,
		best_mul = best_mul,
		best_dist = best_dist,
	}
end

local function cam_render_pos_from_ent(ent, offset)
	local center = Isaac.WorldToRenderPosition(ent.Position + (ent.PositionOffset or Vector.Zero))
		+ (offset or Vector.Zero)
	return center + item.CAMERA_OFFSET
end

local function cam_render_pos_from_air(air, offset)
	local center = Isaac.WorldToRenderPosition(air.Position + (air.PositionOffset or Vector.Zero))
		+ (offset or Vector.Zero)
	return center + item.CAMERA_OFFSET
end

local function target_render_pos(ent, offset, is_player)
	local world = ent.Position + (ent.PositionOffset or Vector.Zero)
	if is_player then
		world = world + Vector(0, -20)
	end
	return Isaac.WorldToRenderPosition(world) + (offset or Vector.Zero)
end

local function make_track(ent, hash, cam_pos, is_player)
	local w = cfg()
	return {
		hash = hash,
		ent = ent,
		is_player = is_player == true,
		phase = TRACK.SPAWN,
		age = 0,
		life = 0,
		spawn_t = 0,
		travel_t = 0,
		land_t = 0,
		confirm_t = 0,
		fade_t = 0,
		retract_t = 0,
		locked_t = 0,
		start_pos = Vector(cam_pos.X, cam_pos.Y),
		ratio = 0,
		sprite = new_sprite(w.target_anm2 or "gfx/mimics/The_Watcher/the_watcher_target.anm2", "Lock"),
		aim_sprite = nil,
		confirmed = false,
	}
end

local function begin_confirm_target(tgt, best_node, owner)
	local w = cfg()
	tgt.phase = "CONFIRM"
	tgt.fire_source_uid = best_node and best_node.uid or nil
	tgt.fire_damage = explosion_damage_from_base(air_damage(best_node and best_node.air, owner))
	tgt.fire_origin = best_node and best_node.air and Vector(best_node.air.Position.X, best_node.air.Position.Y) or nil
	tgt.confirm_t = 0
	tgt.pending_frame = 0
	if best_node then
		play_anim(best_node.sprite, "Shoot", true)
		best_node.body_anim = "Shoot"
		best_node.fire_age = 0
	end
	local tr = tgt.track
	if tr then
		tr.phase = TRACK.CONFIRM
		tr.confirm_t = 0
		tr.confirmed = true
		play_anim(tr.sprite, "Lock", true)
		if not tr.aim_sprite then
			tr.aim_sprite = new_sprite(w.target_anm2 or "gfx/mimics/The_Watcher/the_watcher_target.anm2", "Track")
		end
		play_anim(tr.aim_sprite, "Track", true)
	end
end

local function fire_blast(tgt, owner)
	if not tgt or not auxi.check_all_exists(tgt.ent) then return end
	local dmg = tonumber(tgt.fire_damage) or explosion_damage_from_base(owner and owner.Damage or 3.5)
	local hurt_self = false
	if tgt.kind == "player" and owner then
		hurt_self = not auxi.should_do_Seija(owner, true)
	end
	Game():BombExplosionEffects(
		tgt.ent.Position,
		dmg,
		TearFlags.TEAR_NORMAL,
		Color(1, 1, 1, 1, -1, -1, -1),
		owner,
		0.5,
		false,
		hurt_self,
		0
	)
	local w = cfg()
	if tgt.kind == "enemy" and tgt.ent:IsBoss() then
		tgt.cooldown = w.boss_cooldown or 210
	else
		tgt.cooldown = w.enemy_cooldown or 150
	end
	tgt.progress = 0
	tgt.phase = "COOLDOWN"
	if tgt.track then
		tgt.track.phase = TRACK.FADE
		tgt.track.fade_t = 0
	end
end

-- Enter RETRACT once: freeze screen start, remember progress + reclaim node uid.
local function begin_retract(tr, from_pos, return_node)
	if not tr then return end
	if Common.track_is_fire_locked(tr) then return end
	if tr.phase == TRACK.RETRACT then return end

	tr.phase = TRACK.RETRACT
	tr.retract_t = 0
	tr.retract_progress = tr.ratio or 0

	if from_pos then
		tr.retract_from = Vector(from_pos.X, from_pos.Y)
	elseif tr.filtered_target_pos then
		tr.retract_from = Vector(tr.filtered_target_pos.X, tr.filtered_target_pos.Y)
	end

	if return_node then
		tr.retract_uid = return_node.uid
		if return_node.air and auxi.check_all_exists(return_node.air) then
			local cam = cam_render_pos_from_air(return_node.air, Vector.Zero)
			tr.retract_to = Vector(cam.X, cam.Y)
		end
	end
end

local function resolve_retract_dest(ctrl, tr, offset, fallback_cam)
	local uid = tr and tr.retract_uid
	local node = uid and ctrl and ctrl.nodes and ctrl.nodes[uid]
	if node and node.air and auxi.check_all_exists(node.air) then
		local dest = cam_render_pos_from_air(node.air, offset)
		tr.retract_to = Vector(dest.X, dest.Y)
		return dest
	end
	local from = tr and tr.retract_from
	local best, bd = nil, 1e9
	for _, n in pairs((ctrl and ctrl.nodes) or {}) do
		if n and n.active ~= false and n.air and auxi.check_all_exists(n.air) then
			local cam = cam_render_pos_from_air(n.air, offset)
			local d = from and ((cam.X - from.X) ^ 2 + (cam.Y - from.Y) ^ 2) or 0
			if not from or d < bd then
				bd = d
				best = n
			end
		end
	end
	if best then
		tr.retract_uid = best.uid
		local dest = cam_render_pos_from_air(best.air, offset)
		tr.retract_to = Vector(dest.X, dest.Y)
		return dest
	end
	return (tr and tr.retract_to) or fallback_cam
end

-- request_retract: edge-trigger into RETRACT (must not re-init every frame).
local function tick_track(tr, ratio, alive, request_retract, return_node)
	local w = cfg()
	if not tr then return true end
	tr.age = (tr.age or 0) + 1
	tr.life = (tr.life or 0) + 1
	tr.ratio = ratio or tr.ratio or 0
	if Common.track_is_fire_locked(tr) then
		if (tr.life or 0) > ((w.track_ttl or 120) + 180) then return true end
	elseif (tr.life or 0) > (w.track_ttl or 120) then
		return true
	end
	if request_retract
		and tr.phase ~= TRACK.RETRACT
		and not Common.track_is_fire_locked(tr)
	then
		local from = tr.filtered_target_pos
		begin_retract(tr, from, return_node)
	elseif not alive
		and tr.phase ~= TRACK.RETRACT
		and not Common.track_is_fire_locked(tr)
	then
		tr.phase = TRACK.SHATTER
		tr.shatter_t = 0
	end
	local p = tr.phase
	if p == TRACK.SPAWN then
		tr.spawn_t = (tr.spawn_t or 0) + 1
		if tr.spawn_t >= (w.track_spawn_frames or 4) then
			tr.phase = TRACK.TRAVEL
			tr.travel_t = 0
			tr._capture_start = true
		end
	elseif p == TRACK.TRAVEL then
		tr.travel_t = (tr.travel_t or 0) + 1
		if tr.travel_t >= (w.track_travel_frames or 10) then
			tr.phase = TRACK.LAND
			tr.land_t = 0
		end
	elseif p == TRACK.LAND then
		tr.land_t = (tr.land_t or 0) + 1
		if tr.land_t >= (w.track_land_frames or 3) then
			tr.phase = TRACK.LOCK
		end
	elseif p == TRACK.CONFIRM then
		tr.confirm_t = (tr.confirm_t or 0) + 1
		if tr.confirm_t >= (w.track_confirm_frames or 6) then
			tr.phase = TRACK.LOCKED
			tr.locked_t = 0
		end
	elseif p == TRACK.LOCKED then
		tr.locked_t = (tr.locked_t or 0) + 1
	elseif p == TRACK.FADE then
		tr.fade_t = (tr.fade_t or 0) + 1
		if tr.fade_t >= (w.track_fade_frames or 10) then return true end
	elseif p == TRACK.RETRACT then
		tr.retract_t = (tr.retract_t or 0) + 1
		if tr.retract_t >= (w.track_retract_frames or 18) then return true end
	elseif p == TRACK.SHATTER then
		tr.shatter_t = (tr.shatter_t or 0) + 1
		if tr.shatter_t >= (w.track_shatter_frames or 10) then return true end
	end
	return false
end

local function gather_candidates()
	local list = {}
	local game = Game()
	for i = 0, game:GetNumPlayers() - 1 do
		local pl = game:GetPlayer(i)
		if auxi.check_all_exists(pl) and not pl:IsDead() then
			list[#list + 1] = {ent = pl, kind = "player"}
		end
	end
	for _, e in pairs(auxi.getenemies()) do
		if auxi.check_all_exists(e) and not e:IsDead() then
			if not e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
				list[#list + 1] = {ent = e, kind = "enemy"}
			end
		end
	end
	return list
end

local function process_target(player, ctrl, nodes, ent, kind, key, w)
	local cov = coverage_for(ent, nodes)
	local tgt = ctrl.targets[key]

	if tgt and (tgt.cooldown or 0) > 0 then
		tgt.cooldown = tgt.cooldown - 1
		if tgt.track and tick_track(tgt.track, 0, true, false, nil) then
			tgt.track = nil
		end
		return
	end

	if not tgt then
		if not cov.in_acq or not cov.best_node then return end
		local cam = cam_render_pos_from_air(cov.best_node.air, Vector.Zero)
		tgt = {
			ent = ent,
			hash = GetPtrHash(ent),
			kind = kind,
			progress = 0,
			limit = kind == "player" and (w.player_limit or 240) or (w.enemy_limit or 75),
			phase = "LOCK",
			lost_frames = 0,
			visual_source_uid = cov.best_node.uid,
			track = make_track(ent, GetPtrHash(ent), cam, kind == "player"),
		}
		ctrl.targets[key] = tgt
	else
		tgt.ent = ent
	end

	local fire_locked = tgt.phase == "CONFIRM" or tgt.phase == "LOCKED"
		or (tgt.track and Common.track_is_fire_locked(tgt.track))

	if fire_locked then
		tgt.pending_frame = (tgt.pending_frame or 0) + 1
		if tgt.track then
			tgt.track.ratio = 1
			if tgt.track.phase == TRACK.CONFIRM
				and (tgt.track.confirm_t or 0) >= (w.track_confirm_frames or 6)
			then
				tgt.track.phase = TRACK.LOCKED
				tgt.phase = "LOCKED"
			elseif tgt.track.phase == TRACK.LOCK or tgt.track.phase == TRACK.LAND then
				begin_confirm_target(tgt, cov.best_node or nodes[1], player)
			end
			tick_track(tgt.track, 1, auxi.check_all_exists(ent), false, nil)
		end
		if (tgt.pending_frame or 0) >= (w.enemy_blast_explode_frame or 12) then
			fire_blast(tgt, player)
		end
		return
	end

	if cov.in_acq or cov.in_ret then
		tgt.lost_frames = 0
		if cov.in_acq and cov.best_mul and cov.best_mul > 0 then
			tgt.progress = math.min(tgt.limit, (tgt.progress or 0) + (cov.best_mul or 1))
			tgt.visual_source_uid = cov.best_node and cov.best_node.uid or tgt.visual_source_uid
		end
		local ratio = Common.clamp01((tgt.progress or 0) / math.max(1, tgt.limit or 1))
		if tgt.track then
			tgt.track.ratio = ratio
			local src = ctrl.nodes[tgt.visual_source_uid]
			if tick_track(tgt.track, ratio, true, false, nil) then
				tgt.track = nil
			elseif ratio >= 0.999 and tgt.track.phase == TRACK.LOCK then
				begin_confirm_target(tgt, cov.best_node or src or nodes[1], player)
			end
		elseif cov.in_acq and cov.best_node then
			local cam = cam_render_pos_from_air(cov.best_node.air, Vector.Zero)
			tgt.track = make_track(ent, GetPtrHash(ent), cam, kind == "player")
			tgt.visual_source_uid = cov.best_node.uid
		end
	else
		tgt.lost_frames = (tgt.lost_frames or 0) + 1
		if (tgt.lost_frames or 0) <= (w.move_freeze_frames or 24) then
			if tgt.track then
				tick_track(tgt.track, Common.clamp01((tgt.progress or 0) / math.max(1, tgt.limit)), true, false, nil)
			end
		else
			tgt.progress = math.max(0, (tgt.progress or 0) - (w.move_decay_per_frame or 3))
			local nearest, nd = nil, 1e9
			for j = 1, #nodes do
				local d = ent.Position:Distance(nodes[j].air.Position)
				if d < nd then
					nd = d
					nearest = nodes[j]
				end
			end
			if tgt.track then
				-- If never rendered, seed retract_from from current target screen pos.
				if not tgt.track.filtered_target_pos and not tgt.track.retract_from then
					local seed = target_render_pos(ent, Vector.Zero, kind == "player")
					tgt.track.filtered_target_pos = Vector(seed.X, seed.Y)
				end
				if tick_track(
					tgt.track,
					Common.clamp01((tgt.progress or 0) / math.max(1, tgt.limit)),
					true,
					true,
					nearest
				) then
					tgt.track = nil
				end
			end
			if (tgt.progress or 0) <= 0 and not tgt.track then
				ctrl.targets[key] = nil
			end
		end
	end
end

local function tick_controller(player)
	local ctrl = ensure_controller(player)
	ctrl.age = (ctrl.age or 0) + 1
	local nodes = collect_active_nodes(ctrl, player)
	ctrl.node_count = #nodes
	local w = cfg()

	if #nodes == 0 then
		for k, tgt in pairs(ctrl.targets) do
			if not Common.track_is_fire_locked(tgt.track) and tgt.phase ~= "CONFIRM" and tgt.phase ~= "LOCKED" then
				ctrl.targets[k] = nil
			end
		end
		return
	end

	local seen = {}
	local candidates = gather_candidates()
	for i = 1, #candidates do
		local cand = candidates[i]
		local key = target_key_ent(cand.ent, cand.kind)
		seen[key] = true
		process_target(player, ctrl, nodes, cand.ent, cand.kind, key, w)
	end

	for k, tgt in pairs(ctrl.targets) do
		if not seen[k] then
			if not (tgt.phase == "CONFIRM" or tgt.phase == "LOCKED"
				or (tgt.track and Common.track_is_fire_locked(tgt.track))) then
				ctrl.targets[k] = nil
			end
		end
	end
end

function item.get_debug_snapshot(player)
	local ctrl = player and player:GetData()[ctrl_key()]
	if type(ctrl) ~= "table" then return {nodes = 0, targets = {}} end
	local targets = {}
	for k, t in pairs(ctrl.targets or {}) do
		targets[#targets + 1] = {
			key = k,
			kind = t.kind,
			progress = t.progress,
			limit = t.limit,
			phase = t.phase,
			fire_uid = t.fire_source_uid,
			visual_uid = t.visual_source_uid,
		}
	end
	return {
		nodes = ctrl.node_count or 0,
		range = item.CRAFT_RANGE,
		targets = targets,
		redirected = item.player_watcher_is_redirected(player),
		allocated = item.count_allocated_watchers(player),
	}
end

local function render_sprite(spr, pos, scale, alpha, tint)
	if not spr or not pos then return end
	alpha = tonumber(alpha) or 1
	if alpha < 0.02 then return end
	scale = tonumber(scale) or 1
	local c = Color(1, 1, 1, alpha)
	if tint then
		c = Color(tint.r or 1, tint.g or 1, tint.b or 1, alpha, tint.ro or 0, tint.go or 0, tint.bo or 0)
	end
	spr.Color = c
	spr.Scale = Vector(scale, scale)
	spr:Render(pos, Vector.Zero, Vector.Zero)
	spr.Scale = Vector(1, 1)
	spr.Color = Color(1, 1, 1, 1)
end

local function find_node_by_nil(ent)
	local nd = ent:GetData()
	if not nd[item.own_key .. "cam"] then return nil, nil end
	local owner = nd.Params and nd.Params.player
	if not owner then return nil, nil end
	local ctrl = owner:GetData()[ctrl_key()]
	if type(ctrl) ~= "table" then return nil, nil end
	local uid = nd[item.own_key .. "node_uid"]
	local node = uid and ctrl.nodes[uid]
	if node and node.nil_ptr == GetPtrHash(ent) then
		return node, owner
	end
	for _, n in pairs(ctrl.nodes or {}) do
		if n and n.nil_ptr == GetPtrHash(ent) then
			return n, owner
		end
	end
	return nil, nil
end

local function render_node_camera(node, ent, offset)
	if not node or not node.sprite then return end
	local w = cfg()
	local air = node.air
	if not air or not auxi.check_all_exists(air) then return end
	local cam = cam_render_pos_from_ent(ent, offset)
	render_sprite(node.sprite, cam, 1, 1)
	if node.halo_spr then
		local center_world = air.Position + (air.PositionOffset or Vector.Zero)
		local screen_r = world_radius_to_render_px(center_world, craft_acq(), offset)
		local scale = screen_r / (w.halo_base_radius_px or 72)
		local al = w.halo_alpha or 0.55
		node.halo_spr.Color = Color(1, 1, 1, al)
		node.halo_spr.Scale = Vector(scale, scale)
		local pos = Isaac.WorldToRenderPosition(center_world) + (offset or Vector.Zero)
		node.halo_spr:Render(pos, Vector.Zero, Vector.Zero)
		node.halo_spr.Scale = Vector(1, 1)
		node.halo_spr.Color = Color(1, 1, 1, 1)
	end
end

local function render_tracks(ctrl, offset)
	if not ctrl or not ctrl.targets then return end
	local w = cfg()
	for _, tgt in pairs(ctrl.targets) do
		local tr = tgt.track
		if tr and tr.sprite and auxi.check_all_exists(tgt.ent) then
			local src = ctrl.nodes[tgt.visual_source_uid]
			local cam = (src and src.air and cam_render_pos_from_air(src.air, offset)) or Vector.Zero
			local end_pos
			if tr.phase == TRACK.RETRACT then
				-- Frozen leave point; stop chasing the target.
				if not tr.retract_from then
					local seed = tr.filtered_target_pos
						or target_render_pos(tgt.ent, offset, tgt.kind == "player")
					tr.retract_from = Vector(seed.X, seed.Y)
				end
				end_pos = tr.retract_from
			else
				end_pos = target_render_pos(tgt.ent, offset, tgt.kind == "player")
				tr.filtered_target_pos = Common.filter_pos(
					tr.filtered_target_pos,
					end_pos,
					w.lock_filter_rate or 0.25
				)
				end_pos = tr.filtered_target_pos or end_pos
			end
			local pos = end_pos
			local al = 1
			local sc = w.enemy_display_scale or 1.05
			local prog = Common.clamp01(tr.ratio or 0)
			if tr.phase == TRACK.SPAWN or tr.phase == TRACK.TRAVEL then
				local t = tr.phase == TRACK.SPAWN
					and Common.clamp01((tr.spawn_t or 0) / (w.track_spawn_frames or 4))
					or Common.clamp01((tr.travel_t or 0) / (w.track_travel_frames or 10))
				if tr.phase == TRACK.TRAVEL then
					if tr._capture_start or not tr.start_pos then
						tr.start_pos = Vector(cam.X, cam.Y)
						tr._capture_start = false
					end
					local te = Common.ease_out_cubic(t)
					pos = Common.lerp_vec(tr.start_pos, end_pos, te)
						+ Vector(0, -math.sin(math.pi * t) * (w.track_arc_px or 8))
					sc = Common.lerp(0.75, w.enemy_scale_hi or 1.15, te)
					prog = 0
				else
					pos = Vector(cam.X, cam.Y)
					sc = Common.lerp(0.45, 0.75, t)
					al = Common.lerp(0.4, 0.85, t)
					prog = 0
				end
			elseif tr.phase == TRACK.RETRACT then
				local t = Common.clamp01((tr.retract_t or 0) / (w.track_retract_frames or 18))
				local te = Common.ease_out_cubic(t)
				local from = tr.retract_from or tr.filtered_target_pos or end_pos
				local dest = resolve_retract_dest(ctrl, tr, offset, cam)
				pos = Common.lerp_vec(from, dest or cam, te)
				prog = Common.lerp(tr.retract_progress or 0, 0, t)
				sc = Common.lerp(w.enemy_display_scale or 1.05, 0.65, te)
				al = 1 - 0.8 * t
			elseif Common.track_is_fire_locked(tr) then
				prog = 1
			end
			local sc2 = sc * Common.lerp(1.08, 1.0, prog)
			render_sprite(tr.sprite, pos, sc2, al)
			if Common.track_is_fire_locked(tr) and tr.aim_sprite then
				render_sprite(tr.aim_sprite, pos, sc * 0.92, al, {r = 1, g = 0.85, b = 0.75, ro = 0.2})
			end
		end
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
	params = MEUS_NIL_VARIANT,
	Function = function(_, ent)
		local nd = ent:GetData()
		if not nd[item.own_key .. "cam"] then return end
		local air = nd.Params and nd.Params.air
		if air and auxi.check_all_exists(air) then
			sync_nil_to_air(ent, air)
		else
			nd.removecd = 0
			ent:Remove()
		end
	end,
})

local function try_render_craft_cam(ent, offset)
	local node = find_node_by_nil(ent)
	if not node then return nil end
	render_node_camera(node, ent, offset)
	return false
end

if ModCallbacks.MC_PRE_EFFECT_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_EFFECT_RENDER,
		params = MEUS_NIL_VARIANT,
		Function = function(_, ent, offset)
			return try_render_craft_cam(ent, offset)
		end,
	})
else
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_EFFECT_RENDER,
		params = MEUS_NIL_VARIANT,
		Function = function(_, ent, offset)
			try_render_craft_cam(ent, offset)
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		if Game():IsPaused() then return end
		local ctrl = player:GetData()[ctrl_key()]
		if type(ctrl) ~= "table" then return end
		local has = false
		for _ in pairs(ctrl.nodes or {}) do
			has = true
			break
		end
		if not has then return end
		tick_controller(player)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_RENDER,
	params = nil,
	Function = function(_, player, offset)
		local ctrl = player:GetData()[ctrl_key()]
		if type(ctrl) ~= "table" then return end
		render_tracks(ctrl, offset)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			local ctrl = player and player:GetData()[ctrl_key()]
			if type(ctrl) == "table" then
				ctrl.targets = {}
				for _, node in pairs(ctrl.nodes or {}) do
					if node then
						release_node_nil(node)
						if node.sprite then
							play_anim(node.sprite, "Watching", true)
							node.body_anim = "Watching"
						end
					end
				end
			end
		end
	end,
})

return item

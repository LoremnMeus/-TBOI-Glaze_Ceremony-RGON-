local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local wall_geometry = require("Qing_Remaster_scripts.others.room_wall_geometry")
local rock_topology = require("Qing_Remaster_scripts.others.grid_rock_topology")

local item = {
	ToCall = {},
	pre_ToCall = {},
	entity = enums.Items.Gold_Rush,
	own_key = "Item_Gold_Rush_",
	familiar = {Variant = 73,SubType = 0,},
	fools_gold_chance = {
		base = 0.12,
		decay = 0.62,
		min = 0.018,
		extra = 0.025,
	},
	reset_rooms = {min = 3,max = 5,},
	fools_gold_indices = {},
	spider_no_collision_frames = 10,
	suppressed_rock_drops = {},
	spawning_custom_reward = false,
	spider_throw = {
		speed = 6.5,
		up_speed = -6.5,
		gravity = 0.55,
		start_offset = -12,
	},
	-- Empty-vein presentation rats (no reward). Count does not scale with copies.
	rat = {
		variant = enums.Entities.Gold_Rush_Rat,
		count_min = 2,
		count_max = 4,
		hp = 6,
		launch = {
			horizontal_speed_min = 4.0,
			horizontal_speed_max = 6.0,
			height_start = -6,
			vertical_speed_min = -5.0,
			vertical_speed_max = -3.8,
			gravity = 0.55,
			rotation_speed_min = 8,
			rotation_speed_max = 15,
		},
		land_frames_min = 4,
		land_frames_max = 7,
		run_speed_min = 2.8,
		run_speed_max = 4.2,
		steering = 0.18,
		wobble_angle = 7,
		wobble_speed = 0.65,
		wobble_y = 0.75,
		run_duration_min = 150,
		run_duration_max = 240,
		escape_speed_min = 6.0,
		escape_speed_max = 7.5,
		escape_accel = 0.45,
		escape_trigger_dist = 14,
		escape_wall_inset = 10,
		escape_edge_jitter = 20,
		fade_frames = 12,
		fade_speed = 2.5,
		spawn_protection = 10,
		avoid_player_dist = 100,
	},
}

local golden_spider_color = Color(1,1,1,1,0.8,0.8,0)

local function set_golden_spider(spider)
	local sprite = spider:GetSprite()
	local data = spider:GetData()
	data.is_golden = true
	sprite.Color = golden_spider_color
end

local function hold_golden_spider(spider)
	local data = spider:GetData()
	consistance_holder.try_hold_over_entity(spider,item.own_key)
	data._Data[item.own_key].is_golden = true
	consistance_holder.try_hold_entity(spider,item.own_key,{consistance = true,})
end

local function restore_golden_spider(spider)
	local data = spider:GetData()
	if data.is_golden == true then return true end
	if consistance_holder.try_check_entity(spider,item.own_key) then
		local info = data._Data and data._Data[item.own_key]
		if info and info.is_golden == true then
			set_golden_spider(spider)
			return true
		end
	end
	return false
end

local function remove_golden_spider_record(spider)
	local data = spider:GetData()
	data.is_golden = false
	if data._Data and data._Data[item.own_key] then
		data._Data[item.own_key].is_golden = false
	end
	consistance_holder.try_remove_entity(spider,item.own_key)
end

-- Eligible source rocks for fools-gold conversion.
-- GRID_ROCKB is a block (not rock topology); kept for historical Gold Rush eligibility.
local function can_change(grid)
	local tp = grid:GetType()
	local coll = grid.CollisionClass
	if tp == GridEntityType.GRID_ROCKB
		or rock_topology.is_rock_type(tp)
	then
		-- Exclude already-gold so we don't re-convert fools gold.
		if tp == GridEntityType.GRID_ROCK_GOLD
			or tp == GridEntityType.GRID_ROCK_BOMB
			or tp == GridEntityType.GRID_ROCK_SS
		then
			return false
		end
		if coll == GridCollisionClass.COLLISION_SOLID or coll == GridCollisionClass.COLLISION_OBJECT then
			return true
		end
	end
	return false
end

local function sprite_is_foolsgold(sprite)
	if not sprite then return false end
	if sprite:IsPlaying("foolsgold") == true then return true end
	local anim = rock_topology.get_anim_name(sprite)
	return anim ~= nil and string.lower(tostring(anim)) == "foolsgold"
end

local function get_gold_rush_count()
	local cnt = 0
	local player = Game():GetPlayer(0)
	for playerNum = 1, Game():GetNumPlayers() do
		local to_player = Game():GetPlayer(playerNum - 1)
		if to_player:HasCollectible(item.entity) or to_player:GetEffects():GetCollectibleEffectNum(item.entity) > 0 then
			cnt = cnt + to_player:GetCollectibleNum(item.entity) + to_player:GetEffects():GetCollectibleEffectNum(item.entity)
			player = to_player
		end
	end
	return cnt,player
end

local function get_fools_gold_chance(generated,count_bonus)
	local info = item.fools_gold_chance
	local base = info.base + math.max(0,(count_bonus or 1) - 1) * info.extra
	return math.max(info.min,base * (info.decay ^ generated))
end

local function get_decay_state()
	save.elses[item.own_key.."fools_gold_decay"] = save.elses[item.own_key.."fools_gold_decay"] or {}
	return save.elses[item.own_key.."fools_gold_decay"]
end

local function reroll_reset_rooms(state,rng)
	local info = item.reset_rooms
	state.rooms_left = rng:RandomInt(info.max - info.min + 1) + info.min
end

local function prepare_decay_state(rng)
	local state = get_decay_state()
	if state.rooms_left == nil then
		state.generated = state.generated or 0
		reroll_reset_rooms(state,rng)
	elseif state.rooms_left <= 0 then
		state.generated = 0
		reroll_reset_rooms(state,rng)
	end
	return state
end

-- Big-rock members are valid candidates.
-- rock_topology.replace_rocks detaches selected cells from their
-- big-rock component before converting them to standalone fool's gold.
local function collect_changeable_grid_indices(room)
	local ret = {}
	local size = room:GetGridSize()
	for i = 0, size - 1 do
		local gent = room:GetGridEntity(i)
		if gent and can_change(gent) == true then
			ret[#ret + 1] = i
		end
	end
	return ret
end

local function shuffle_list(list, rng)
	for i = #list, 2, -1 do
		local j = rng:RandomInt(i) + 1
		list[i], list[j] = list[j], list[i]
	end
end

local function snapshot_grid_cell(room, grid_index, extra)
	local row = rock_topology.snapshot(room, grid_index)
	row.tracked = item.fools_gold_indices[grid_index] ~= nil
	local sprite = room:GetGridEntity(grid_index)
	sprite = sprite and sprite:GetSprite()
	row.is_foolsgold = sprite_is_foolsgold(sprite)
	local neighbors = auxi.get_cardinal_grid_neighbor_indexes(room, grid_index)
	row.neighbors = {}
	for _, nidx in ipairs(neighbors) do
		local nsnap = rock_topology.snapshot(room, nidx)
		row.neighbors[#row.neighbors + 1] = {
			index = nidx,
			type = nsnap.type,
			anim = nsnap.anim,
			is_big = nsnap.is_big,
			big_frame = nsnap.big_frame,
		}
	end
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			row[k] = v
		end
	end
	return row
end

local function emit_grid_probe(phase, rows, meta)
	if item._probe_on_grid_phase then
		item._probe_on_grid_phase(phase, rows, meta)
	end
end

-- Selection + RNG stay local; topology mutation goes through rock_topology.replace_rocks.
-- Per-cell conversion: selecting one big-rock member does NOT convert its partners.
local function apply_fools_gold_selection(room, selected, selected_set)
	selected = selected or {}
	selected_set = selected_set or {}
	if #selected == 0 then
		return 0
	end

	local probing = item._probe_on_grid_phase ~= nil
	local replacements = {}
	local rejected_rows = {}
	for _, info in ipairs(selected) do
		local visual_frame = info.visual_frame
		replacements[#replacements + 1] = {
			index = info.index,
			metadata = info,
			new_type = GridEntityType.GRID_ROCK_GOLD,
			keep_single = true,
			validate = function(grid)
				return can_change(grid)
			end,
			apply_visual = function(grid, rock, sprite)
				if sprite then
					sprite:SetFrame("foolsgold", visual_frame)
				end
			end,
		}
	end

	local prev_listener = rock_topology.debug_listener
	local last_before_rows = nil
	local last_affected = {}
	local will_convert_set = {}
	for _, info in ipairs(selected) do
		will_convert_set[info.index] = true
	end

	local function enrich_rows(rows, converted_set, extra_fn)
		local out = {}
		for _, snap in ipairs(rows or {}) do
			local idx = snap.grid_index or snap.index
			local info = selected_set[idx]
			local row = snapshot_grid_cell(room, idx, {
				selected = selected_set[idx] ~= nil,
				will_convert = will_convert_set[idx] == true,
				converted = converted_set and converted_set[idx] == true or false,
				tracked = item.fools_gold_indices[idx] ~= nil,
				visual_frame = info and info.visual_frame or nil,
				reward_seed = info and info.reward_seed or nil,
				big_frame = snap.big_frame,
				was_big_before = info and info.was_big_before or nil,
			})
			if extra_fn then extra_fn(idx, row) end
			out[#out + 1] = row
		end
		for _, row in ipairs(rejected_rows) do
			out[#out + 1] = row
		end
		return out
	end

	if probing then
		rock_topology.set_debug_listener(function(phase, payload)
			payload = payload or {}
			last_affected = payload.affected_indices or last_affected
			local converted_set = payload.target_set
			if converted_set == nil and payload.target_indices then
				converted_set = {}
				for _, idx in ipairs(payload.target_indices) do
					converted_set[idx] = true
				end
			end
			local rows = payload.rows
			if rows == nil and last_affected and #last_affected > 0 then
				rows = {}
				for _, idx in ipairs(last_affected) do
					rows[#rows + 1] = rock_topology.snapshot(room, idx)
				end
			end
			if phase == "before_detach" then
				last_before_rows = enrich_rows(rows, nil, nil)
				emit_grid_probe("before_detach", last_before_rows, {
					affected_indices = last_affected,
					target_indices = payload.target_indices,
					changed_indices = payload.changed_indices,
					before_components = payload.before_components,
				})
			else
				emit_grid_probe(phase, enrich_rows(rows, converted_set, function(idx, row)
					row.accepted = converted_set and converted_set[idx] == true or false
					row.tracked = item.fools_gold_indices[idx] ~= nil
					row.applied_visual = phase == "after_visual"
						and converted_set
						and converted_set[idx] == true
				end), {
					affected_indices = last_affected,
					target_indices = payload.target_indices,
					changed_indices = payload.changed_indices,
					before_rows = last_before_rows,
					validation = payload.validation,
				})
			end
			if prev_listener then
				prev_listener(phase, payload)
			end
		end)
	end

	local result = rock_topology.replace_rocks(room, replacements, {
		refresh_radius = 1,
	})

	if probing then
		rock_topology.set_debug_listener(prev_listener)
	end

	for _, rej in ipairs(result.rejected or {}) do
		local info = rej.metadata
		rejected_rows[#rejected_rows + 1] = snapshot_grid_cell(room, rej.index, {
			selected = true,
			visual_frame = info and info.visual_frame or nil,
			reward_seed = info and info.reward_seed or nil,
			accepted = false,
			converted = false,
			reject_reason = rej.reason or "validation_failed",
			was_big_before = info and info.was_big_before or nil,
		})
	end

	local generated = 0
	local converted_set = {}
	for _, entry in ipairs(result.accepted or {}) do
		if entry.ok then
			local info = entry.metadata
			local grid = room:GetGridEntity(entry.index)
			if grid and grid:GetType() == GridEntityType.GRID_ROCK_GOLD and info then
				item.fools_gold_indices[entry.index] = {
					visual_frame = info.visual_frame,
					reward_seed = info.reward_seed,
				}
				converted_set[entry.index] = true
				generated = generated + 1
			end
		end
	end

	local affected_list = result.affected_indices or {}
	if probing then
		local snap_rows = {}
		for _, idx in ipairs(affected_list) do
			snap_rows[#snap_rows + 1] = rock_topology.snapshot(room, idx)
		end
		local final_rows = enrich_rows(snap_rows, converted_set, function(idx, row)
			row.tracked = item.fools_gold_indices[idx] ~= nil
			row.applied_visual = converted_set[idx] == true
				and item.fools_gold_indices[idx] ~= nil
		end)
		item._probe_last_affected = affected_list
		if item._probe_on_conversion_complete then
			item._probe_on_conversion_complete({
				frame = Game():GetFrameCount(),
				affected_indices = affected_list,
				before_rows = last_before_rows,
				final_rows = final_rows,
				validation = result.validation,
			})
		end
	end
	return generated, result
end

local function try_make_fools_gold(room, rng, count_bonus, generated_offset)
	local indices = collect_changeable_grid_indices(room)
	shuffle_list(indices, rng)

	local probing = item._probe_on_grid_phase ~= nil
	local candidate_rows = {}
	if probing then
		for _, index in ipairs(indices) do
			candidate_rows[#candidate_rows + 1] = snapshot_grid_cell(room, index, {selected = false})
		end
	end

	local selected = {}
	local selected_count = 0
	local selected_set = {}
	for _, index in ipairs(indices) do
		if rng:RandomFloat() < get_fools_gold_chance((generated_offset or 0) + selected_count, count_bonus) then
			local gent = room:GetGridEntity(index)
			local info = {
				index = index,
				visual_frame = rng:RandomInt(60),
				reward_seed = rng:Next(),
				was_big_before = gent and rock_topology.is_big(gent) or false,
			}
			selected[#selected + 1] = info
			selected_set[index] = info
			selected_count = selected_count + 1
			if probing then
				for _, row in ipairs(candidate_rows) do
					if row.grid_index == index then
						row.selected = true
						row.visual_frame = info.visual_frame
						row.reward_seed = info.reward_seed
						row.was_big_before = info.was_big_before
						break
					end
				end
			end
		end
	end
	if probing then
		emit_grid_probe("candidate_collect", candidate_rows)
	end

	return apply_fools_gold_selection(room, selected, selected_set)
end

local function make_golden_spider(player,pos)
	local spider = player:AddBlueSpider(pos)
	set_golden_spider(spider)
	hold_golden_spider(spider)
	return spider
end

local function throw_golden_spider(spider,dir,rng)
	local d = spider:GetData()
	d[item.own_key.."no_collision_frames"] = item.spider_no_collision_frames
	d[item.own_key.."entity_collision"] = spider.EntityCollisionClass
	d[item.own_key.."throw_height_speed"] = item.spider_throw.up_speed - rng:RandomFloat()
	d[item.own_key.."throw_gravity"] = item.spider_throw.gravity
	spider.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	spider.PositionOffset = Vector(0,item.spider_throw.start_offset)
	spider.Velocity = dir:Resized(item.spider_throw.speed + rng:RandomFloat() * 1.5)
end

local function spawn_golden_spiders(player,pos,rng,count_bonus)
	rng = auxi.rng_for_sake(rng)
	local count = 2 + rng:RandomInt(3) + math.max(0,(count_bonus or 1) - 1)
	local dirs = {Vector(1,0),Vector(-1,0),Vector(0,1),Vector(0,-1),}
	local offset = rng:RandomInt(4)
	for i = 1,count do
		local dir = dirs[((i + offset - 1) % #dirs) + 1]
		local spider = make_golden_spider(player,pos + dir * 4)
		throw_golden_spider(spider,dir,rng)
	end
end

local function spawn_pickup(player,pos,variant,subtype,rng)
	local velocity = auxi.MakeVector(rng:RandomFloat() * 360) * (1.5 + rng:RandomFloat() * 2.5)
	item.spawning_custom_reward = true
	local pickup = Isaac.Spawn(EntityType.ENTITY_PICKUP,variant,subtype,pos,velocity,player):ToPickup()
	item.spawning_custom_reward = false
	if pickup then pickup:GetData()[item.own_key.."custom_reward"] = true end
	return pickup
end

local function spawn_pennies(player,pos,count,rng)
	for _ = 1,count do
		spawn_pickup(player,pos,PickupVariant.PICKUP_COIN,CoinSubType.COIN_PENNY,rng)
	end
end

local function is_gold_rush_rat(ent)
	if not ent or not ent:ToNPC() then return false end
	return ent.Type == 996 and ent.Variant == item.rat.variant
end

local function rk(name)
	return item.own_key .. "rat_" .. name
end

local function set_sprite_alpha(spr, alpha)
	if not spr then return end
	local c = spr.Color
	spr.Color = Color(c.R, c.G, c.B, alpha, c.RO, c.GO, c.BO)
end

local function apply_rat_flip(spr, velocity)
	if not spr then return end
	if velocity.X < -0.1 then
		spr.FlipX = true
	elseif velocity.X > 0.1 then
		spr.FlipX = false
	end
end

local function apply_rat_wobble(ent, d, cfg, speed_mul, angle_mul)
	local spr = ent:GetSprite()
	if not spr then return end
	apply_rat_flip(spr, ent.Velocity)
	local phase = ent.FrameCount * (cfg.wobble_speed * (speed_mul or 1))
		+ (d[rk("wobble_phase")] or 0)
	spr.Rotation = math.sin(phase) * (cfg.wobble_angle * (angle_mul or 1))
	ent.PositionOffset = Vector(0, math.sin(phase * 2) * (cfg.wobble_y or 0.75))
end

local function init_gold_rush_rat(ent)
	if not is_gold_rush_rat(ent) then return end
	local d = ent:GetData()
	d[item.own_key.."rat"] = true
	ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	ent:AddEntityFlags(
		EntityFlag.FLAG_NO_REWARD
		| EntityFlag.FLAG_NO_STATUS_EFFECTS
		| EntityFlag.FLAG_NO_BLOOD_SPLASH
		| EntityFlag.FLAG_HIDE_HP_BAR
	)
	if d[rk("state")] == nil then
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
	end
	ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
	ent.CollisionDamage = 0
	if ent.CanShutDoors ~= nil then
		ent.CanShutDoors = false
	end
	local hp = item.rat.hp
	ent.MaxHitPoints = hp
	ent.HitPoints = hp
	local spr = ent:GetSprite()
	if spr and not spr:IsPlaying("Idle") then
		spr:Play("Idle", true)
	end
end

local function pick_wall_escape_dir(room, pos, run_dir)
	local tries = {
		run_dir:Rotated(90),
		run_dir:Rotated(-90),
		run_dir:Rotated(135),
		run_dir:Rotated(-135),
		-run_dir,
	}
	for _, dir in ipairs(tries) do
		local future = pos + dir:Resized(18)
		if room:GetGridCollisionAtPos(future) == GridCollisionClass.COLLISION_NONE then
			return dir:Normalized()
		end
	end
	return (-run_dir):Normalized()
end

local function begin_rat_escape(ent, d, cfg)
	local wall = wall_geometry.get_nearest_wall(ent.Position, {
		inset = cfg.escape_wall_inset or 10,
	})
	if wall then
		local tangent = Vector(-wall.inward.Y, wall.inward.X)
		local jitter = (d[rk("escape_offset")] or 0) * (cfg.escape_edge_jitter or 20)
		d[rk("escape_target")] = wall.target_pos + tangent * jitter
		d[rk("escape_outward")] = wall.outward
	else
		local dir = d[rk("run_dir")] or ent.Velocity
		if dir:Length() < 0.01 then dir = Vector(1, 0) end
		dir = dir:Normalized()
		d[rk("escape_target")] = ent.Position + dir * 80
		d[rk("escape_outward")] = dir
	end
	d[rk("state")] = "escape"
end

local function begin_rat_fade(ent, d, cfg)
	d[rk("state")] = "fade"
	d[rk("fade_timer")] = cfg.fade_frames or 12
	d[rk("fade_frames")] = cfg.fade_frames or 12
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	-- FADE must pierce into the wall; keep GRIDCOLL_WALLS only until now (ESCAPE).
	ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
end

local function update_rat_launch(ent, d, cfg)
	local spr = ent:GetSprite()
	local vs = d[rk("vertical_speed")] or 0
	local y = ent.PositionOffset.Y + vs
	vs = vs + (cfg.launch.gravity or 0.55)
	d[rk("vertical_speed")] = vs
	ent.PositionOffset = Vector(0, y)
	if spr then
		spr.Rotation = (spr.Rotation or 0) + (d[rk("rotation_speed")] or 0)
		apply_rat_flip(spr, ent.Velocity)
	end
	ent.CollisionDamage = 0
	if y >= 0 and vs > 0 then
		ent.PositionOffset = Vector(0, 0)
		if spr then spr.Rotation = 0 end
		ent.Velocity = ent.Velocity * 0.45
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
		d[rk("state")] = "land"
		d[rk("land_timer")] = d[rk("land_frames")] or cfg.land_frames_min or 4
	end
end

local function update_rat_land(ent, d, cfg)
	ent.CollisionDamage = 0
	ent.Velocity = ent.Velocity * 0.92
	local spr = ent:GetSprite()
	if spr then
		spr.Rotation = 0
		apply_rat_flip(spr, ent.Velocity)
	end
	ent.PositionOffset = Vector(0, 0)
	d[rk("land_timer")] = (d[rk("land_timer")] or 1) - 1
	if (d[rk("land_timer")] or 0) <= 0 then
		d[rk("state")] = "run"
	end
end

local function update_rat_run(ent, d, cfg)
	local run_dir = d[rk("run_dir")] or Vector(1, 0)
	local run_speed = d[rk("run_speed")] or cfg.run_speed_min
	local room = Game():GetRoom()

	local nearest, nearest_dist = nil, nil
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() then
			local dist = ent.Position:Distance(p.Position)
			if not nearest_dist or dist < nearest_dist then
				nearest = p
				nearest_dist = dist
			end
		end
	end
	if nearest and nearest_dist and nearest_dist < cfg.avoid_player_dist then
		local away = ent.Position - nearest.Position
		if away:Length() > 0.01 then
			away = away:Normalized()
			run_dir = (run_dir * 0.8 + away * 0.2):Normalized()
		end
	end

	local future = ent.Position + run_dir:Resized(18)
	if room:GetGridCollisionAtPos(future) ~= GridCollisionClass.COLLISION_NONE then
		run_dir = pick_wall_escape_dir(room, ent.Position, run_dir)
	end
	d[rk("run_dir")] = run_dir

	local desired = run_dir:Resized(run_speed)
	ent.Velocity = ent.Velocity * 0.75 + desired * 0.25
	ent.CollisionDamage = 0
	apply_rat_wobble(ent, d, cfg, 1, 1)

	d[rk("run_timer")] = (d[rk("run_timer")] or cfg.run_duration_min) - 1
	if (d[rk("run_timer")] or 0) <= 0 then
		begin_rat_escape(ent, d, cfg)
	end
end

local function update_rat_escape(ent, d, cfg)
	local target = d[rk("escape_target")]
	local speed = d[rk("escape_speed")] or cfg.escape_speed_min
	local accel = cfg.escape_accel or 0.45
	if target then
		local to = target - ent.Position
		if to:Length() > 0.01 then
			local desired = to:Normalized():Resized(speed)
			ent.Velocity = ent.Velocity * (1 - accel) + desired * accel
		end
	else
		local outward = d[rk("escape_outward")] or Vector(1, 0)
		ent.Velocity = outward:Resized(speed)
	end
	ent.CollisionDamage = 0
	apply_rat_wobble(ent, d, cfg, 1.4, 1.2)

	local trigger = cfg.escape_trigger_dist or 14
	local room = Game():GetRoom()
	local near_target = target and (ent.Position - target):Length() <= trigger
	local near_edge = not room:IsPositionInRoom(ent.Position, 12)
	if near_target or near_edge then
		begin_rat_fade(ent, d, cfg)
	end
end

local function update_rat_fade(ent, d, cfg)
	local outward = d[rk("escape_outward")]
	if not outward or outward:Length() < 0.01 then
		outward = ent.Velocity
		if outward:Length() < 0.01 then outward = Vector(1, 0) end
		outward = outward:Normalized()
	else
		outward = outward:Normalized()
	end
	ent.Velocity = outward:Resized(cfg.fade_speed or 2.5)
	ent.CollisionDamage = 0

	d[rk("fade_timer")] = (d[rk("fade_timer")] or 1) - 1
	local total = d[rk("fade_frames")] or cfg.fade_frames or 12
	local remain = math.max(0, d[rk("fade_timer")] or 0)
	local alpha = remain / math.max(1, total)
	local spr = ent:GetSprite()
	set_sprite_alpha(spr, alpha)
	apply_rat_flip(spr, ent.Velocity)
	if spr then
		spr.Rotation = math.sin(ent.FrameCount * cfg.wobble_speed * 1.4) * cfg.wobble_angle * 1.2
	end

	if remain <= 0 then
		ent:Remove()
	end
end

local function spawn_gold_rush_rats(player, pos, rng, source)
	local cfg = item.rat
	local launch = cfg.launch
	local count = cfg.count_min + rng:RandomInt(cfg.count_max - cfg.count_min + 1)
	local start_angle = rng:RandomFloat() * 360
	if source and source.Entity and source.Entity:Exists() then
		local away = pos - source.Entity.Position
		if away:Length() > 0.01 then
			start_angle = away:GetAngleDegrees() - 90
		end
	end

	for i = 1, count do
		local angle = start_angle + (i - 1) * (360 / count) + (rng:RandomFloat() - 0.5) * 35
		local dir = Vector.FromAngle(angle)
		local h_speed = launch.horizontal_speed_min
			+ rng:RandomFloat() * (launch.horizontal_speed_max - launch.horizontal_speed_min)
		local rat = Isaac.Spawn(996, cfg.variant, 0, pos + dir * 4, dir * h_speed, player):ToNPC()
		if rat then
			init_gold_rush_rat(rat)
			local d = rat:GetData()
			d[rk("state")] = "launch"
			d[rk("run_dir")] = dir
			d[rk("run_speed")] =
				cfg.run_speed_min + rng:RandomFloat() * (cfg.run_speed_max - cfg.run_speed_min)
			d[rk("wobble_phase")] = rng:RandomFloat() * math.pi * 2
			d[rk("run_timer")] =
				cfg.run_duration_min + rng:RandomInt(cfg.run_duration_max - cfg.run_duration_min + 1)
			d[rk("land_frames")] =
				cfg.land_frames_min + rng:RandomInt(cfg.land_frames_max - cfg.land_frames_min + 1)
			d[rk("vertical_speed")] =
				launch.vertical_speed_min
				+ rng:RandomFloat() * (launch.vertical_speed_max - launch.vertical_speed_min)
			local rot = launch.rotation_speed_min
				+ rng:RandomFloat() * (launch.rotation_speed_max - launch.rotation_speed_min)
			if rng:RandomFloat() < 0.5 then rot = -rot end
			d[rk("rotation_speed")] = rot
			d[rk("escape_speed")] =
				cfg.escape_speed_min + rng:RandomFloat() * (cfg.escape_speed_max - cfg.escape_speed_min)
			d[rk("escape_offset")] = rng:RandomFloat() * 2 - 1
			d[item.own_key.."spawn_protection"] = cfg.spawn_protection
			rat.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			rat.PositionOffset = Vector(0, launch.height_start or -6)
		end
	end
end

local function reward_fools_gold(player,pos,rng,count_bonus,source)
	local roll = rng:RandomInt(100)
	local result = {roll = roll, kind = nil, detail = nil}
	if roll < 35 then
		result.kind = "rat_nest"
		spawn_gold_rush_rats(player, pos, rng, source)
	elseif roll < 80 then
		local count = 1 + rng:RandomInt(4)
		result.kind = "pennies"
		result.detail = count
		spawn_pennies(player,pos,count,rng)
	elseif roll < 95 then
		local value = 5 + rng:RandomInt(6)
		result.kind = "rich"
		local had_nickel = false
		if value >= 7 and rng:RandomInt(100) < 45 then
			spawn_pickup(player,pos,PickupVariant.PICKUP_COIN,CoinSubType.COIN_NICKEL,rng)
			value = value - 5
			had_nickel = true
		end
		result.detail = had_nickel and (tostring(value) .. "+nickel") or tostring(value)
		spawn_pennies(player,pos,value,rng)
	else
		local special = rng:RandomInt(4)
		if special == 0 then
			result.kind = "lucky_penny"
			spawn_pickup(player,pos,PickupVariant.PICKUP_COIN,CoinSubType.COIN_LUCKYPENNY,rng)
		elseif special == 1 then
			result.kind = "gold_bomb"
			spawn_pickup(player,pos,PickupVariant.PICKUP_BOMB,BombSubType.BOMB_GOLDEN,rng)
		elseif special == 2 then
			result.kind = "golden_spiders"
			spawn_golden_spiders(player,pos,rng,count_bonus)
		else
			result.kind = "troll_bomb"
			spawn_pickup(player,pos,PickupVariant.PICKUP_BOMB,BombSubType.BOMB_TROLL,rng)
		end
	end
	return result
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item.fools_gold_indices = {}
	item.suppressed_rock_drops = {}
	wall_geometry.invalidate()
	local room = Game():GetRoom()
	if room:IsFirstVisit() then
		local player = auxi.have_player_has_collectible(item.entity)
		if player then
			local cnt = get_gold_rush_count()
			cnt = math.max(1,cnt or 1)
			local rng = player:GetCollectibleRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			local state = prepare_decay_state(rng)
			local generated = try_make_fools_gold(room,rng,cnt,state.generated or 0)
			state.generated = (state.generated or 0) + generated
			state.rooms_left = (state.rooms_left or 1) - 1
		end
	end
end,
})

if ModCallbacks.MC_POST_GRID_ROCK_DESTROY then
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GRID_ROCK_DESTROY, params = GridEntityType.GRID_ROCK_GOLD,
Function = function(_,rock,grid_type,immediate,source)
	local grid_index = rock:GetGridIndex()
	local meta = item.fools_gold_indices[grid_index]
	if not meta then return end
	item.fools_gold_indices[grid_index] = nil
	local cnt,player = get_gold_rush_count()
	if cnt <= 0 or player == nil then return end
	if source and source.Entity then
		player = auxi.check_spawner_player(source.Entity) or player
	end
	-- Reward RNG is fixed at fools-gold selection via Gold Rush collectible RNG.
	-- Blast source only affects player ownership / rat flee direction — never reward rolls.
	local reward_seed = (type(meta) == "table" and meta.reward_seed) or rock:GetRNG():GetSeed()
	local rng = auxi.seed_rng(reward_seed)
	rng = auxi.rng_for_sake(rng)
	-- MC_POST_GRID_ROCK_DESTROY 是只读通知；原版金岩石的金币会在回调返回后生成。
	-- 先登记位置，再由 pickup init 精确移除原生金币；本模块自己的奖励用标记绕过。
	item.suppressed_rock_drops[#item.suppressed_rock_drops + 1] = {
		position = Vector(rock.Position.X,rock.Position.Y),
		frame = Game():GetFrameCount(),
	}
	local result = reward_fools_gold(player,rock.Position,rng,cnt,source)
	if item._probe_on_reward then
		item._probe_on_reward({
			grid_index = grid_index,
			reward_seed = reward_seed,
			visual_frame = type(meta) == "table" and meta.visual_frame or nil,
			kind = result and result.kind or nil,
			roll = result and result.roll or nil,
			detail = result and result.detail or nil,
			source_type = source and source.Type or nil,
			source_variant = source and source.Variant or nil,
		})
	end
end,
})
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_COIN,
Function = function(_,pickup)
	if item.spawning_custom_reward or pickup:GetData()[item.own_key.."custom_reward"] then return end
	local frame = Game():GetFrameCount()
	for i = #item.suppressed_rock_drops,1,-1 do
		local info = item.suppressed_rock_drops[i]
		local age = frame - info.frame
		if age > 3 then
			table.remove(item.suppressed_rock_drops,i)
		elseif age >= 0 and (pickup.Position - info.position):Length() <= 55 then
			pickup:Remove()
			return
		end
	end
end,
})

-- 与 StageAPI 的 altRockOverride 相同：在实体生成前把原生格子掉落替换掉。
-- POST_GRID_ROCK_DESTROY 本身不接受返回值，不能用于取消掉落。
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_ENTITY_SPAWN, params = nil,
Function = function(_,tp,variant,subtype,position,velocity,spawner,seed)
	if item.spawning_custom_reward or tp ~= EntityType.ENTITY_PICKUP or variant ~= PickupVariant.PICKUP_COIN then return end
	local frame = Game():GetFrameCount()
	for _,info in ipairs(item.suppressed_rock_drops) do
		local age = frame - info.frame
		if age >= 0 and age <= 3 and (position - info.position):Length() <= 55 then
			return {EntityType.ENTITY_EFFECT,enums.Entities.AnnaHelper,item.entity,seed}
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = enums.Entities.AnnaHelper,
Function = function(_,effect)
	if effect.SubType == item.entity then
		effect:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
		effect:Remove()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	local frame = Game():GetFrameCount()
	for i = #item.suppressed_rock_drops,1,-1 do
		local info = item.suppressed_rock_drops[i]
		local age = frame - info.frame
		if age >= 0 and age <= 3 then
			for _,ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COIN)) do
				local pickup = ent:ToPickup()
				if pickup and pickup.FrameCount <= 3 and not pickup:GetData()[item.own_key.."custom_reward"] and (pickup.Position - info.position):Length() <= 55 then
					pickup:Remove()
				end
			end
		elseif age > 3 then
			table.remove(item.suppressed_rock_drops,i)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar.Variant,
Function = function(_,ent)
	if ent.Variant ~= item.familiar.Variant then return end
	restore_golden_spider(ent)
	local d = ent:GetData()
	local key = item.own_key.."no_collision_frames"
	if (d[key] or 0) > 0 then
		d[key] = d[key] - 1
		if d[key] <= 0 then
			if d[item.own_key.."entity_collision"] then ent.EntityCollisionClass = d[item.own_key.."entity_collision"] end
			d[item.own_key.."entity_collision"] = nil
		end
	end
	if d[item.own_key.."throw_height_speed"] then
		local height_speed = d[item.own_key.."throw_height_speed"]
		ent.PositionOffset = Vector(ent.PositionOffset.X,math.min(0,ent.PositionOffset.Y + height_speed))
		d[item.own_key.."throw_height_speed"] = height_speed + (d[item.own_key.."throw_gravity"] or item.spider_throw.gravity)
		ent.Velocity = ent.Velocity * 0.93
		if ent.PositionOffset.Y >= 0 and d[item.own_key.."throw_height_speed"] > 0 then
			ent.PositionOffset = Vector(ent.PositionOffset.X,0)
			d[item.own_key.."throw_height_speed"] = nil
			d[item.own_key.."throw_gravity"] = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar.Variant,
Function = function(_,ent)
	if ent.Variant ~= item.familiar.Variant then return end
	restore_golden_spider(ent)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = item.familiar.Variant,
Function = function(_,ent, col, low)
	if ent.Variant == item.familiar.Variant then
		local d = ent:GetData()
		if d.is_golden and d.is_golden == true then
			if (d[item.own_key.."no_collision_frames"] or 0) > 0 then return {Collide = false,SkipCollisionEffects = true,} end
			if col:IsVulnerableEnemy() and col:IsActiveEnemy() and (not col:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and col:CanShutDoors() == true then
				col:AddMidasFreeze(EntityRef(ent),150)
				remove_golden_spider_record(ent)
			end
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_INIT,
	params = 996,
	Function = function(_, ent)
		if is_gold_rush_rat(ent) then
			init_gold_rush_rat(ent)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_NPC_UPDATE,
	params = 996,
	Function = function(_, ent)
		if not is_gold_rush_rat(ent) then return end
		local d = ent:GetData()
		if d[item.own_key.."rat"] ~= true then
			init_gold_rush_rat(ent)
		end
		local cfg = item.rat
		if (d[item.own_key.."spawn_protection"] or 0) > 0 then
			d[item.own_key.."spawn_protection"] = d[item.own_key.."spawn_protection"] - 1
		end

		local state = d[rk("state")]
		if state == nil then
			d[rk("state")] = "run"
			d[rk("run_dir")] = d[rk("run_dir")] or Vector(1, 0)
			d[rk("run_speed")] = d[rk("run_speed")] or cfg.run_speed_min
			d[rk("run_timer")] = d[rk("run_timer")] or cfg.run_duration_min
			state = "run"
		end

		if state == "launch" then
			update_rat_launch(ent, d, cfg)
		elseif state == "land" then
			update_rat_land(ent, d, cfg)
		elseif state == "run" then
			update_rat_run(ent, d, cfg)
		elseif state == "escape" then
			update_rat_escape(ent, d, cfg)
		elseif state == "fade" then
			update_rat_fade(ent, d, cfg)
		end
	end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = 996,
	Function = function(_, ent, amount, flags, source, countdown)
		if not is_gold_rush_rat(ent) then return end
		local d = ent:GetData()
		if (d[item.own_key.."spawn_protection"] or 0) > 0 then
			return false
		end
	end,
})

function item.debug_spawn_rat_nest(player, pos)
	player = player or Game():GetPlayer(0)
	pos = pos or player.Position
	local rng = player:GetCollectibleRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	spawn_gold_rush_rats(player, pos, rng, nil)
end

function item.debug_dump_tracked_fools_gold()
	local room = Game():GetRoom()
	local rows = {}
	for index, meta in pairs(item.fools_gold_indices) do
		rows[#rows + 1] = snapshot_grid_cell(room, index, {
			reward_seed = type(meta) == "table" and meta.reward_seed or nil,
			visual_frame = type(meta) == "table" and meta.visual_frame or nil,
		})
	end
	table.sort(rows, function(a, b) return (a.grid_index or 0) < (b.grid_index or 0) end)
	return rows
end

function item.debug_force_make_fools_gold_now()
	local player = auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
	if not player then return 0 end
	local room = Game():GetRoom()
	local cnt = math.max(1, select(1, get_gold_rush_count()) or 1)
	local rng = player:GetCollectibleRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	return try_make_fools_gold(room, rng, cnt, 0)
end

--- Deterministic probe helper: convert the first changeable big-rock member.
--- Uses the same replace_rocks pipeline as normal Gold Rush (per-cell, keep_single).
function item.debug_force_convert_big_member()
	local player = auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
	if not player then
		return 0, nil, "no_player"
	end
	local room = Game():GetRoom()
	local size = room:GetGridSize()
	local target_index = nil
	for i = 0, size - 1 do
		local gent = room:GetGridEntity(i)
		if gent and can_change(gent) and rock_topology.is_big(gent) then
			target_index = i
			break
		end
	end
	if target_index == nil then
		return 0, nil, "no_big_candidate"
	end

	local rng = player:GetCollectibleRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	local info = {
		index = target_index,
		visual_frame = rng:RandomInt(60),
		reward_seed = rng:Next(),
		was_big_before = true,
	}
	local selected = {info}
	local selected_set = {[target_index] = info}
	if item._probe_on_grid_phase then
		emit_grid_probe("candidate_collect", {
			snapshot_grid_cell(room, target_index, {
				selected = true,
				visual_frame = info.visual_frame,
				reward_seed = info.reward_seed,
				was_big_before = true,
				force_big = true,
			}),
		})
	end
	local generated, result = apply_fools_gold_selection(room, selected, selected_set)
	return generated, target_index, result and result.validation or nil
end

--l local player = Game():GetPlayer(0);local spider = player:AddBlueSpider(player.Position);local s = spider:GetSprite();spider:SetColor(Color(1,1,1,1,1,1,0),-1,99,false,false);

return item

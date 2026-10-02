local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")

-- 和谐号：逻辑 Controller + 无碰撞视觉 Effect + Lua OBB Hitbox
-- 方向在召唤时正交固定，永不读 entity Velocity 作为真相。

local item = {
	ToCall = {},
	entity = enums.Items.Hyper_Velocity,
	own_key = "Items_Hyper_Velocity_",
	familiar = enums.Entities.Harmony, -- 旧 NPC 变体；新视觉走 Effect
	track = enums.Entities.Hyper_Velocity_Track,
	color_map = {
		{frame = 0, A = 0},
		{frame = 30, A = 1},
		{frame = 2 * 30, A = 1},
		{frame = 3 * 30, A = 0},
		total = 3 * 30,
	},
	APPROACH_DISTANCE = 1100,
	BASE_SPEED = 28,
	MAX_SPEED = 55,
	ACCEL = 0.35,
	HALF_LENGTH = 90,
	HALF_WIDTH = 24,
	ENEMY_HIT_CD = 3,
	PLAYER_HIT_CD = 8,
	PLAYER_DAMAGE = 5, -- 与 EID / 旧 collisionDamage 一致（半心单位）
	CRASH_DAMAGE = 1000,
	CRASH_VISUAL_FRAMES = 12,
	HIT_CACHE_PRUNE = 90,
}

local trains = {} -- [train_id] = controller
local next_train_id = 1

local function ortho_dir(vel)
	if not vel then return Vector(1, 0) end
	if math.abs(vel.X) >= math.abs(vel.Y) then
		return Vector(vel.X >= 0 and 1 or -1, 0)
	end
	return Vector(0, vel.Y >= 0 and 1 or -1)
end

local function dir_angle(dir)
	return dir:GetAngleDegrees()
end

local function train_center(tr)
	return tr.origin + tr.direction * tr.distance
end

local function project_local(rel, dir)
	local along = rel:Dot(dir)
	local perp = Vector(-dir.Y, dir.X)
	local lat = rel:Dot(perp)
	return along, lat
end

local function point_in_obb(pos, center, dir, half_len, half_wid, pad)
	pad = pad or 0
	local along, lat = project_local(pos - center, dir)
	return math.abs(along) <= half_len + pad and math.abs(lat) <= half_wid + pad
end

-- 上一帧→本帧扫掠：任一点落入则命中（防高速穿模）
local function swept_hit(prev_c, cur_c, dir, half_len, half_wid, target_pos, target_size)
	local pad = target_size or 0
	if point_in_obb(target_pos, cur_c, dir, half_len, half_wid, pad) then return true end
	if point_in_obb(target_pos, prev_c, dir, half_len, half_wid, pad) then return true end
	local steps = math.max(1, math.ceil((cur_c - prev_c):Length() / 16))
	for i = 1, steps - 1 do
		local t = i / steps
		local mid = prev_c * (1 - t) + cur_c * t
		if point_in_obb(target_pos, mid, dir, half_len, half_wid, pad) then return true end
	end
	return false
end

local function obb_overlap(a_c, a_dir, b_c, b_dir, hl, hw)
	local delta = b_c - a_c
	local a_perp = Vector(-a_dir.Y,a_dir.X)
	local b_perp = Vector(-b_dir.Y,b_dir.X)
	local axes = {a_dir,a_perp,b_dir,b_perp}
	for _,axis in ipairs(axes) do
		local a_radius = hl * math.abs(a_dir:Dot(axis)) + hw * math.abs(a_perp:Dot(axis))
		local b_radius = hl * math.abs(b_dir:Dot(axis)) + hw * math.abs(b_perp:Dot(axis))
		if math.abs(delta:Dot(axis)) > a_radius + b_radius then return false end
	end
	return true
end

local function swept_train_overlap(a,b)
	local a_prev,a_cur = a.prev_center,train_center(a)
	local b_prev,b_cur = b.prev_center,train_center(b)
	local relative_motion = (a_cur - a_prev) - (b_cur - b_prev)
	local steps = math.max(1,math.ceil(relative_motion:Length() / 12))
	for index = 0,steps do
		local amount = index / steps
		local a_center = a_prev * (1 - amount) + a_cur * amount
		local b_center = b_prev * (1 - amount) + b_cur * amount
		if obb_overlap(a_center,a.direction,b_center,b.direction,item.HALF_LENGTH,item.HALF_WIDTH) then
			return true,(a_center + b_center) * 0.5,a_center,b_center
		end
	end
	return false,nil,nil,nil
end

local function hit_key(train_id, seed)
	return tostring(train_id) .. "_" .. tostring(seed)
end

local function prune_hit_cache(tr, frame)
	local cache = tr.hit_cache
	if not cache then return end
	for k, until_f in pairs(cache) do
		if until_f < frame then cache[k] = nil end
	end
end

local function mark_hit(tr, key, cd, frame)
	tr.hit_cache = tr.hit_cache or {}
	tr.hit_cache[key] = frame + cd
end

local function can_hit(tr, key, frame)
	tr.hit_cache = tr.hit_cache or {}
	local until_f = tr.hit_cache[key]
	return not until_f or until_f < frame
end

local function destroy_train(tr, reason)
	if not tr or tr.dead then return end
	tr.dead = true
	tr.death_reason = reason
	if tr.visual and tr.visual:Exists() then
		tr.visual:Remove()
	end
end

local function valid_visual(tr)
	return tr.visual and tr.visual:Exists() and not tr.visual:IsDead()
end

local function spawn_track_light(pos, dir)
	local q2 = Isaac.Spawn(1000, item.track, 0, pos, Vector(0, 0), nil)
	q2.TargetPosition = pos
	q2.SortingLayer = 0
	local s2 = q2:GetSprite()
	s2:Load("gfx/mimics/Hyper_Velocity/Hyper_Velocity.anm2", true)
	s2:Play("TrackLight", true)
	s2.Rotation = dir_angle(dir) - 90
	s2.Color = Color(0, 0, 0, 0)
	q2:GetData()[item.own_key.."is_track"] = true
	return q2
end

local function spawn_visual(pos, dir)
	-- 无碰撞 Effect：只跟 controller 走
	local vis = Isaac.Spawn(1000, item.track, 1, pos, Vector(0, 0), nil)
	vis.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	vis.GridCollisionClass = GridCollisionClass.COLLISION_NONE
	local s = vis:GetSprite()
	s:Load("gfx/mimics/Hyper_Velocity/Hyper_Velocity.anm2", true)
	s:Play("Carin", true)
	s.Rotation = dir_angle(dir) - 90
	vis:GetData()[item.own_key.."is_train_visual"] = true
	return vis
end

function item.Fire_Harmony(player, pos, vel)
	local room = Game():GetRoom()
	player = player or Game():GetPlayer(0)
	local dir = ortho_dir(vel)
	local spawn_pos = room:GetClampedPosition(pos - dir * 600, 5)
	local origin = spawn_pos - dir * item.APPROACH_DISTANCE
	local train_id = next_train_id
	next_train_id = next_train_id + 1

	local visual = spawn_visual(origin, dir)
	spawn_track_light(spawn_pos, dir)

	local tr = {
		train_id = train_id,
		origin = origin,
		direction = dir,
		distance = 0,
		speed = item.BASE_SPEED,
		age = 0,
		owner = player,
		visual = visual,
		hit_cache = {},
		grid_cache = {},
		prev_center = origin,
		entered_room = false,
		dead = false,
	}
	trains[train_id] = tr
	visual:GetData()[item.own_key.."train_id"] = train_id
	return visual
end

local function destroy_grids_along(tr, room, center)
	local dir = tr.direction
	local head = center + dir * item.HALF_LENGTH
	local perp = Vector(-dir.Y, dir.X)
	local frame = Game():GetFrameCount()
	for lat = -1, 1 do
		for along = -2, 4 do
			local sample = head + dir * (along * 20) + perp * (lat * item.HALF_WIDTH * 0.6)
			local gid = room:GetGridIndex(sample)
			if gid ~= -1 and not tr.grid_cache[gid] then
				local grid = room:GetGridEntity(gid)
				if grid and auxi.issolid(grid) then
					tr.grid_cache[gid] = frame
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS, 1.2, 1, false, 0, 2)
					Game():BombExplosionEffects(
						room:GetGridPosition(gid),
						10,
						0,
						Color(1, 1, 1, 1),
						nil,
						math.min(3, tr.speed / 30),
						false,
						false
					)
					room:DestroyGrid(gid)
				elseif grid and auxi.iswall(grid) then
					tr.grid_cache[gid] = frame
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS, 1.5, 1, false, 0, 2)
					Game():BombExplosionEffects(
						room:GetGridPosition(gid),
						10,
						0,
						Color(1, 1, 1, 1),
						nil,
						math.min(3, tr.speed / 30),
						false,
						false
					)
				end
			end
		end
	end
end

local function destroy_grids_swept(tr, room, prev_c, cur_c)
	local delta = cur_c - prev_c
	local steps = math.max(1,math.ceil(delta:Length() / 20))
	for index = 0,steps do
		local amount = index / steps
		destroy_grids_along(tr,room,prev_c * (1 - amount) + cur_c * amount)
	end
end

local function hit_enemies(tr, room, prev_c, cur_c)
	local player = tr.owner
	if not auxi.check_all_exists(player) then player = Game():GetPlayer(0) end
	local frame = Game():GetFrameCount()
	local enemies = auxi.getenemies(Isaac.GetRoomEntities())
	for _, ent in pairs(enemies) do
		if ent:IsVulnerableEnemy() then
			local seed = ent.InitSeed or GetPtrHash(ent)
			local key = hit_key(tr.train_id, seed)
			if can_hit(tr, key, frame)
				and swept_hit(prev_c, cur_c, tr.direction, item.HALF_LENGTH, item.HALF_WIDTH, ent.Position, ent.Size or 0)
			then
				mark_hit(tr, key, item.ENEMY_HIT_CD, frame)
				ent:AddEntityFlags(EntityFlag.FLAG_EXTRA_GORE | EntityFlag.FLAG_KNOCKED_BACK)
				ent:TakeDamage(5 * player.Damage + 250, DamageFlag.DAMAGE_IGNORE_ARMOR, EntityRef(player), 0)
				Game():ShakeScreen(5)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS, 1.5, 1, false, 0, 2)
			end
		end
	end
end

local function hit_players(tr, prev_c, cur_c)
	local frame = Game():GetFrameCount()
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() and not p:IsDead() then
			local key = hit_key(tr.train_id, "p" .. tostring(p:GetData().__Index or i))
			if can_hit(tr, key, frame)
				and swept_hit(prev_c, cur_c, tr.direction, item.HALF_LENGTH, item.HALF_WIDTH, p.Position, p.Size or 12)
			then
				mark_hit(tr, key, item.PLAYER_HIT_CD, frame)
				local before = p:GetHearts() + p:GetSoulHearts() + p:GetBoneHearts()
				local source
				if valid_visual(tr) then
					source = EntityRef(tr.visual)
				elseif tr.owner and tr.owner:Exists() then
					source = EntityRef(tr.owner)
				else
					source = EntityRef(Game():GetPlayer(0))
				end
				p:TakeDamage(item.PLAYER_DAMAGE, 0, source, 30)
				p.Velocity = p.Velocity + tr.direction * 12
				if before > 0 and p:GetHearts() + p:GetSoulHearts() + p:GetBoneHearts() <= 0 then
					Unlocker.unlock_achievement(
						save.UnlockData.Others.Crushed,
						"Unlock",
						{Achievement_page = "gfx/ui/Some achievements/" .. enums.AchievementGraphics.others.Crush .. ".png"}
					)
				end
			end
		end
	end
end

local function begin_crash_visual(tr,position,spin)
	if not valid_visual(tr) then return end
	local visual = tr.visual
	visual.Position = position
	visual.Velocity = Vector.Zero
	visual.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	visual.GridCollisionClass = GridCollisionClass.COLLISION_NONE
	local sprite = visual:GetSprite()
	visual:GetData()[item.own_key.."crash_visual"] = {
		age = 0,
		life = item.CRASH_VISUAL_FRAMES,
		position = position,
		spin = spin,
		base_rotation = sprite.Rotation,
		base_scale = auxi.ProtectVector(visual.SpriteScale),
	}
	tr.visual = nil
end

local function check_crashes()
	local list = {}
	for _, tr in pairs(trains) do
		if not tr.dead and tr.entered_room and tr.age > 15 then
			table.insert(list, tr)
		end
	end
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if (not a.dead) and (not b.dead) then
				local hit,mid,a_center,b_center = swept_train_overlap(a,b)
				if hit then
					Game():BombExplosionEffects(mid, item.CRASH_DAMAGE, 0, Color(1, 1, 1, 1), nil, 5, false, false)
					Game():ShakeScreen(60)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS, 2, 1, false, 0, 2)
					begin_crash_visual(a,a_center,-4.5)
					begin_crash_visual(b,b_center,4.5)
					destroy_train(a, "crash")
					destroy_train(b, "crash")
				end
			end
		end
	end
end

local function fully_outside(room, center, dir)
	local corners = {
		center + dir * item.HALF_LENGTH + Vector(-dir.Y, dir.X) * item.HALF_WIDTH,
		center + dir * item.HALF_LENGTH - Vector(-dir.Y, dir.X) * item.HALF_WIDTH,
		center - dir * item.HALF_LENGTH + Vector(-dir.Y, dir.X) * item.HALF_WIDTH,
		center - dir * item.HALF_LENGTH - Vector(-dir.Y, dir.X) * item.HALF_WIDTH,
	}
	for _, c in ipairs(corners) do
		if room:IsPositionInRoom(c, 0) then return false end
	end
	return true
end

local function update_train_visual(tr, prev, cur)
	if not valid_visual(tr) then return false end
	local visual = tr.visual
	visual.Position = cur
	visual.Velocity = cur - prev
	visual.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	visual.GridCollisionClass = GridCollisionClass.COLLISION_NONE
	visual:GetSprite().Rotation = dir_angle(tr.direction) - 90
	return true
end

local function update_room_lifecycle(tr, room, center)
	local outside = fully_outside(room,center,tr.direction)
	if not tr.entered_room then
		if not outside then tr.entered_room = true end
		return false
	end
	if outside then
		destroy_train(tr,"left_room")
		return true
	end
	return false
end

local function clear_all_trains(reason)
	for _,tr in pairs(trains) do destroy_train(tr,reason) end
	trains = {}
end

local function tick_trains()
	local room = Game():GetRoom()
	local frame = Game():GetFrameCount()
	for id, tr in pairs(trains) do
		if tr.dead then
			trains[id] = nil
		elseif not valid_visual(tr) then
			destroy_train(tr,"visual_missing")
		else
			tr.age = tr.age + 1
			tr.speed = math.min(item.MAX_SPEED,item.BASE_SPEED + item.ACCEL * tr.age)
			local prev = train_center(tr)
			tr.prev_center = prev
			tr.distance = tr.distance + tr.speed
			local cur = train_center(tr)
			update_train_visual(tr,prev,cur)

			if not update_room_lifecycle(tr,room,cur) then
				destroy_grids_swept(tr,room,prev,cur)
				hit_enemies(tr,room,prev,cur)
				hit_players(tr,prev,cur)
				prune_hit_cache(tr,frame)
			end
		end
	end
	check_crashes()
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local d = player:GetData()
		if (useFlags & (UseFlag.USE_MIMIC | UseFlag.USE_OWNED | UseFlag.USE_NOANIM) == UseFlag.USE_MIMIC | UseFlag.USE_OWNED | UseFlag.USE_NOANIM) then
		else
			if d.is_holding_H_V_item ~= true then
				player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
				d.is_holding_H_V_item = true
			else
				player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
				d.is_holding_H_V_item = false
			end
			return {Discharge = false}
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local room = Game():GetRoom()
	if d.is_holding_H_V_item == true then
		if player:IsHoldingItem() == false then
			d.is_holding_H_V_item = false
		else
			local dir = 0
			local ctrlid = player.ControllerIndex
			for i = 4,7 do
				if (Input.IsActionPressed(i,ctrlid) and input_holder.actionsData[tostring(ctrlid)] and input_holder.actionsData[tostring(ctrlid)][i] and input_holder.actionsData[tostring(ctrlid)][i].ActionHoldTime and input_holder.actionsData[tostring(ctrlid)][i].ActionHoldTime == 1) then
					dir = i
				end
			end
			if dir > 0 then
				local vel = Vector(0,0)
				if room:IsMirrorWorld() == true and (dir == 4 or dir == 5) then dir = 9 - dir end
				if dir == 4 then vel = vel + Vector(-1,0)
				elseif dir == 5 then vel = vel + Vector(1,0)
				elseif dir == 6 then vel = vel + Vector(0,-1)
				elseif dir == 7 then vel = vel + Vector(0,1) end
				if d.is_holding_H_V_card then
					player:AnimateCard(d.is_holding_H_V_card,"HideItem")
					d.is_holding_H_V_card = nil
				else
					local slot = auxi.check_slot_with_item(player,item.entity)
					player:UseActiveItem(item.entity,UseFlag.USE_MIMIC | UseFlag.USE_OWNED | UseFlag.USE_NOANIM,slot)
					player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
					player:SetActiveCharge(player:GetBatteryCharge(slot), slot)
					if auxi.should_spawn_wisp(player) then
						for i = 1,2 do
							player:AddWisp(item.entity,player.Position,false,false)
						end
					end
				end
				d.is_holding_H_V_item = false
				item.Fire_Harmony(player,player.Position,vel)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	tick_trains()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.track,
Function = function(_,ent)
	local data = ent:GetData()
	if ent.SubType == 0 then
		-- TrackLight 只维护自己的固定位置与渐隐生命周期。
		ent.Velocity = Vector(0, 0)
		if ent.TargetPosition then
			ent.Position = ent.TargetPosition
		end
		local info = auxi.check_lerp(ent.FrameCount, item.color_map)
		local s = ent:GetSprite()
		s.Color = auxi.table2color(info)
		if ent.FrameCount > item.color_map.total then ent:Remove() end
		return
	end
	if ent.SubType == 1 then
		local crash = data[item.own_key.."crash_visual"]
		if crash then
			crash.age = (crash.age or 0) + 1
			local age = crash.age
			local life = math.max(1,crash.life or item.CRASH_VISUAL_FRAMES)
			local sprite = ent:GetSprite()
			ent.Position = crash.position
			ent.Velocity = Vector.Zero
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			ent.GridCollisionClass = GridCollisionClass.COLLISION_NONE
			sprite.Rotation = (crash.base_rotation or 0) + (crash.spin or 0) * math.min(age,6)
			local sx,sy = 1,1
			if age == 1 then sx,sy = 1.14,0.82
			elseif age == 2 then sx,sy = 0.94,1.10
			elseif age == 3 then sx,sy = 1.05,0.94
			else
				local fade = math.min(1,(age - 3) / math.max(1,life - 3))
				sx,sy = 1 - 0.30 * fade,1 - 0.30 * fade
			end
			local base = crash.base_scale or Vector.One
			ent.SpriteScale = Vector(base.X * sx,base.Y * sy)
			local alpha = age <= 3 and 1 or math.max(0,1 - (age - 3) / math.max(1,life - 3))
			local flash = age <= 3 and 0.30 or 0.08
			sprite.Color = Color(1,0.82,0.76,alpha,flash,flash * 0.35,0)
			if age >= life then ent:Remove() end
			return
		end
		-- Train Visual 的 Position / Velocity 完全由 Controller 同步。
		return
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	clear_all_trains("new_room")
end,
})

-- 美德书和平魂火：抵消 ≥2 心伤害
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player then
		if amt >= 2 then
			local n_wisp = auxi.get_wisps(player,item.entity)
			if #n_wisp > 0 then
				for _, v in pairs(n_wisp) do
					v:Remove()
				end
				player:SetMinDamageCooldown(cooldown)
				return false
			end
		end
	end
end,
})

return item

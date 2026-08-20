local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Familiar_Control_Selector = require("Qing_Remaster_scripts.mimics.Familiar_Control_Selector")
local Familiar_Move_Driver = require("Qing_Remaster_scripts.mimics.Familiar_Move_Driver")
local Familiar_Follower_Arbiter = require("Qing_Remaster_scripts.mimics.Familiar_Follower_Arbiter")

local item = {
	ToCall = {},
	entity = enums.Items.My_Emblem,
	familiar = enums.Familiars.Emblem,
	exe_fami = {
		[FamiliarVariant.GUILLOTINE] = true,			--断头台很有趣，眼泪并不和环绕物绑定。
		[FamiliarVariant.SAMSONS_CHAINS] = true,		--脚链不能被拉。
		[FamiliarVariant.LOST_FLY] = true,				--迷路苍蝇不能被拉。
		[FamiliarVariant.LIL_GURDY] = true,				--优化一下小加迪。
		[FamiliarVariant.SPRINKLER] = true,
		[FamiliarVariant.DAMOCLES] = true,
		[FamiliarVariant.FORGOTTEN_BODY] = true,
		[FamiliarVariant.UMBILICAL_BABY] = true,		--Gello：保留原版移动/脐带，禁止 Emblem 接管。
		[enums.Familiars.QingsAirs] = true,
		[enums.Familiars.Star_Pendulum] = true,			--灵摆读阵不可以
		[enums.Familiars.Air_Terror] = true,
		[enums.Familiars.Nazca] = true,
	},
	rd_fami = {
		[FamiliarVariant.LITTLE_CHUBBY] = true,
		[FamiliarVariant.ABEL] = true,
		[FamiliarVariant.HOLY_WATER] = true,
	},
	path_step_min_distance = 8,
	path_drive_min_speed = 10,
	path_drive_speed_margin = 12,
	target_reach_distance = 14,
	return_join_ratio = 0.2,
	return_join_min_distance = 28,
	relink_cooldown = 6,
	tear_stationary_frames = 45,
	tear_stationary_radius = 0.5,
}

local function ensure_emblem_list(player)
	local d = player:GetData()
	d.Emblem_lists = d.Emblem_lists or {}
	return d.Emblem_lists
end

local function emblem_wants_control(familiar)
	if not familiar or familiar:Exists() == false or familiar:IsDead() then return false end
	local player = familiar.Player
	local var = familiar.Variant
	return player ~= nil
		and item.exe_fami[var] ~= true
		and familiar:GetData().ignore_me == nil
		and auxi.has_have_coll(player, item.entity)
end

local function emblem_owns(familiar)
	return Familiar_Control_Selector.is_owner(familiar, Familiar_Control_Selector.MY_EMBLEM)
end

local function is_projectile_alive(ent)
	return ent ~= nil and ent:Exists() and ent:IsDead() == false and ent:GetData().out_of_room ~= true
end

local function familiar_is_busy(familiar)
	if familiar == nil or familiar:Exists() == false or familiar:IsDead() == true then return true end
	local d = familiar:GetData()
	if is_projectile_alive(d.tear_link) then return true end
	if d.Emblem_target_position ~= nil or d.re_link == true then return true end
	if (d.Emblem_relink_cooldown or 0) > 0 then return true end
	return false
end

local function remove_familiar_from_list(list,familiar)
	for i = #list,1,-1 do
		local v = list[i]
		if v == familiar or v == nil or v:Exists() == false or v:IsDead() == true then
			table.remove(list,i)
		end
	end
end

local function add_available_familiar(player,familiar)
	if familiar == nil or familiar:Exists() == false or familiar:IsDead() == true then return end
	if not emblem_owns(familiar) then return end
	if familiar_is_busy(familiar) then return end
	local list = ensure_emblem_list(player)
	for _,v in ipairs(list) do
		if v == familiar then return end
	end
	familiar:GetData().tear_list_alocate = true
	table.insert(list,#list + 1,familiar)
end

local function pop_available_familiar(player)
	local list = ensure_emblem_list(player)
	while #list > 0 do
		local familiar = table.remove(list,1)
		if familiar ~= nil and familiar:Exists() and familiar:IsDead() == false
			and emblem_owns(familiar) and familiar_is_busy(familiar) == false then
			familiar:GetData().tear_list_alocate = nil
			return familiar
		end
	end
end

local function get_motion_step_distance(ent,d)
	local moved = 0
	if d.Emblem_last_position ~= nil then
		moved = (ent.Position - d.Emblem_last_position):Length()
	end
	d.Emblem_last_position = ent.Position
	return math.max(item.path_step_min_distance,moved,ent.Velocity:Length())
end

local function drive_to_position(ent,target,target_velocity)
	Familiar_Move_Driver.drive_to_position(ent, target, target_velocity, {
		min_speed = item.path_drive_min_speed,
		speed_margin = item.path_drive_speed_margin,
		reach_distance = item.target_reach_distance,
	})
end

local function stop_mimicking_projectile(ent)
	local d = ent:GetData()
	d.Emblem_cannot_mimic = true
	local familiar = d.Familiar_link
	if familiar and familiar:Exists() and familiar:IsDead() == false then
		local fd = familiar:GetData()
		if auxi.check_for_the_same(fd.tear_link, ent) then
			fd.tear_link = nil
			fd.Emblem_target_position = nil
			fd.Emblem_last_position = nil
			fd.re_link = true
		end
	end
	d.Familiar_link = nil
end

local function update_tear_stationary_state(ent,d)
	if d.Emblem_cannot_mimic then return true end
	if d.Emblem_stationary_anchor == nil then
		d.Emblem_stationary_anchor = ent.Position
		d.Emblem_stationary_counter = 0
	elseif (ent.Position - d.Emblem_stationary_anchor):Length() > item.tear_stationary_radius then
		d.Emblem_stationary_anchor = ent.Position
		d.Emblem_stationary_counter = 0
	else
		d.Emblem_stationary_counter = (d.Emblem_stationary_counter or 0) + 1
		if d.Emblem_stationary_counter >= item.tear_stationary_frames then
			stop_mimicking_projectile(ent)
			return true
		end
	end
	return false
end

local function assign_emblem_to_projectile(player,ent)
	local d2 = ent:GetData()
	if d2.Emblem_cannot_mimic then return end
	if d2.Familiar_link == nil then
		local familiar = pop_available_familiar(player)
		if familiar == nil then return end
		local fd = familiar:GetData()
		d2.Familiar_link = familiar
		d2.Emblem_target_position = d2.Emblem_target_position or ent.Position
		fd.tear_link = ent
		fd.tear_list_alocate = nil
		fd.re_link = true
		fd.re_add_to = nil
		fd.Emblem_target_position = d2.Emblem_target_position
		fd.Emblem_last_position = familiar.Position
	end
end

local function detach_from_followers(ent,d)
	if d.Emblem_orbit_state == nil and tonumber(ent.OrbitLayer) and tonumber(ent.OrbitLayer) >= 0 then
		d.Emblem_orbit_state = {
			layer = ent.OrbitLayer,
			distance = ent.OrbitDistance and Vector(ent.OrbitDistance.X, ent.OrbitDistance.Y) or nil,
			speed = ent.OrbitSpeed,
			angle = ent.OrbitAngleOffset,
		}
		if ent.RemoveFromOrbit then ent:RemoveFromOrbit() end
	end
	Familiar_Follower_Arbiter.claim(ent, Familiar_Control_Selector.MY_EMBLEM, {followers = true})
	d.Emblem_detached = true
	d.IsFollowing = nil
end

local function attach_to_followers(ent,d,force_follower)
	if d.Emblem_detached == true or force_follower == true then
		local released = Familiar_Follower_Arbiter.release(ent, Familiar_Control_Selector.MY_EMBLEM)
		local orbit = d.Emblem_orbit_state
		if orbit then
			if ent.AddToOrbit then ent:AddToOrbit(math.max(0, tonumber(orbit.layer) or 0)) end
			if orbit.distance then ent.OrbitDistance = Vector(orbit.distance.X, orbit.distance.Y) end
			if orbit.speed ~= nil then ent.OrbitSpeed = orbit.speed end
			if orbit.angle ~= nil then ent.OrbitAngleOffset = orbit.angle end
			d.Emblem_orbit_state = nil
		elseif not released and ent.AddToFollowers then
			ent:AddToFollowers()
		end
		d.Emblem_detached = nil
		d.IsFollowing = ent.IsFollower == true
	end
end

local function release_emblem_control(ent, next_owner)
	local player = ent and ent.Player
	if not player then return end
	local d = ent:GetData()
	remove_familiar_from_list(ensure_emblem_list(player), ent)
	d.tear_list_alocate = nil
	if is_projectile_alive(d.tear_link) then
		local td = d.tear_link:GetData()
		if auxi.check_for_the_same(td.Familiar_link, ent) then td.Familiar_link = nil end
	end
	d.tear_link = nil
	d.Emblem_target_position = nil
	d.Emblem_last_position = nil
	d.Emblem_return_distance = nil
	d.re_link = nil
	d.re_add_to = nil
	-- 先恢复认领前的 follower/orbit 身份；若下一控制器是蓝图，它会在
	-- on_gain 后按自己的规则再次离队，且能采到正确的原始轨道参数。
	attach_to_followers(ent, d)
end

Familiar_Control_Selector.register(Familiar_Control_Selector.MY_EMBLEM, 100, emblem_wants_control, {
	on_lost = release_emblem_control,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cnt > 0 then cnt = cnt + 2 end
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local room = Game():GetRoom()
	local player
	if ent.SpawnerEntity and ent.SpawnerEntity:ToPlayer() then
		player = ent.SpawnerEntity:ToPlayer()
	end
	if is_projectile_alive(d.tear_link) or d.Emblem_target_position ~= nil or d.re_link == true then
		detach_from_followers(ent,d)
	elseif (not d.IsFollowing) then
		attach_to_followers(ent,d,true)
    end
	if s:IsFinished("Appear") then
		s:Play("Idle")
	end
	if s:IsPlaying("Idle") then
	end
	if ent.Velocity:Length() > 0.01 then
		s.Rotation = ent.Velocity:GetAngleDegrees()
	end
	if is_projectile_alive(d.tear_link) or d.Emblem_target_position ~= nil or d.re_link == true then
	else
		attach_to_followers(ent,d,true)
		ent:FollowParent()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = item.familiar,
Function = function(_,ent,col,low)
	local d = ent:GetData()
	if d.coll_cnt == nil then d.coll_cnt = 0 end
	if ent:IsFrame(15,0) == true then
		local player = Game():GetPlayer(0)
		if ent.Player then player = ent.Player end
		if col:IsVulnerableEnemy() and col:IsActiveEnemy() and not col:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			col:TakeDamage(7,0,EntityRef(player),0)
			d.coll_cnt = d.coll_cnt + 1
		end
	end
	if col.Type == 9 and d.coll_cnt > 0 then
		col:Remove()
		d.coll_cnt = d.coll_cnt - 1
	end
	if ent:IsFrame(250,0) == true then
		d.coll_cnt = math.min(d.coll_cnt,5)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_FAMILIAR_RENDER, params = nil,
Function = function(_,ent,offset)
	local d = ent:GetData()
	if d.Emblem_visible_id then
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			local s = ent:GetSprite()
			d.r_pos = (ent.Position * 0.35 + d.r_pos * 0.65)
			s:Render(Isaac.WorldToScreen(d.r_pos) - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
		end
	end
end,
})

local cnt = 0

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = nil,
Function = function(_,ent)
	if auxi.is_time_stopped() then
		ent.Velocity = Vector(0, 0)
		return
	end
	local player = ent.Player
	local var = ent.Variant
	if player and item.exe_fami[var] ~= true and ent:GetData().ignore_me == nil then
		local d = player:GetData()
		if emblem_owns(ent) then
			ensure_emblem_list(player)
			if d.Emblem_counter == nil then d.Emblem_counter = 0 end
			local d2 = ent:GetData()
			if d2.baby_index == nil then
				d2.baby_index = d.Emblem_counter
				d.Emblem_counter = d.Emblem_counter + 1
			end
			if (d2.Emblem_relink_cooldown or 0) > 0 then
				d2.Emblem_relink_cooldown = d2.Emblem_relink_cooldown - 1
			end
			if is_projectile_alive(d2.tear_link) == false then
				d2.tear_link = nil
				if d2.Emblem_target_position ~= nil and (ent.Position - d2.Emblem_target_position):Length() > item.target_reach_distance then
					get_motion_step_distance(ent,d2)
					drive_to_position(ent,d2.Emblem_target_position)
					d2.re_link = true
				elseif d2.re_link == true then
					d2.Emblem_target_position = nil
					d2.Emblem_last_position = nil
					local return_distance = (ent.Position - player.Position):Length()
					d2.Emblem_return_distance = d2.Emblem_return_distance or return_distance
					local join_distance = math.max(item.return_join_min_distance,d2.Emblem_return_distance * item.return_join_ratio)
					if return_distance > join_distance then
						get_motion_step_distance(ent,d2)
						drive_to_position(ent,player.Position)
					else
						attach_to_followers(ent,d2)
						d2.Emblem_last_position = nil
						d2.Emblem_return_distance = nil
						if d2.re_vis ~= nil then
							if item.rd_fami[var] ~= true then
								local succ = Attribute_holder.try_hold_attribute(ent,"Visible",false)
								cnt = cnt + 1
								if succ ~= nil then
									d2.Emblem_visible_id = succ
									if d2.r_pos == nil then	d2.r_pos = ent.Position end
									--控制10帧的渲染，问题不大。
									delay_buffer.addeffe(function(params)
										local ent = params.ent
										if ent and ent:Exists() and ent:IsDead() == false then
											local succ = params.id
											if succ ~= nil then
												local succc = Attribute_holder.try_rewind_attribute(ent,"Visible",succ)
												cnt = cnt - 1
												--if succc == false then print("fail") end
												--print(cnt)
											end
											if ent:GetData().Emblem_visible_id and ent:GetData().Emblem_visible_id == succ then 
												ent:GetData().Emblem_visible_id = nil 
												ent:GetData().r_pos = nil
											end
										end
									end,{ent = ent,id = d2.Emblem_visible_id},3)
								end
							end
							d2.re_vis = nil
							d2.re_link = nil
							d2.Emblem_relink_cooldown = 0
						else
							d2.re_link = nil
							d2.Emblem_relink_cooldown = 0
						end
					end
				end
				if d2.tear_list_alocate == nil and d2.Emblem_target_position == nil and d2.re_link ~= true then
					add_available_familiar(player,ent)
					d2.re_add_to = nil
				end
			else
				local list = ensure_emblem_list(player)
				remove_familiar_from_list(list,ent)
				if d2.re_add_to == nil then
					d2.re_add_to = true
					d2.re_vis = true
					detach_from_followers(ent,d2)
					--ent:RemoveFromDelayed()
					--ent:RemoveFromOrbit()
				end
				local tear = d2.tear_link
				local td = tear:GetData()
				td.Emblem_target_position = tear.Position + tear.Velocity * 3
				d2.Emblem_target_position = td.Emblem_target_position
				get_motion_step_distance(ent,d2)
				drive_to_position(ent,d2.Emblem_target_position,tear.Velocity)
			end
		else
			-- get_owner 已在所有权切换瞬间调用 on_lost；这里不再重复清理。
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local room = Game():GetRoom()
	if ent.SpawnerEntity ~= nil then
		local spet = ent.SpawnerEntity--auxi.to_find_spawner(ent.SpawnerEntity)
		if spet.Type == 1 then
			local player = spet:ToPlayer()
			local d = player:GetData()
			if auxi.has_have_coll(player,item.entity) then
				local d2 = ent:GetData()
				if update_tear_stationary_state(ent,d2) then return end
				local pos = ent.Position
				d2.Emblem_target_position = pos + ent.Velocity * 3
				if d2.out_of_room ~= true then
					if room:IsPositionInRoom(pos,-10) == true then
						assign_emblem_to_projectile(player,ent)
					else
						d2.out_of_room = true
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE, params = nil,
Function = function(_,ent)
	local room = Game():GetRoom()
	if ent.Variant == enums.Entities.StabberKnife then
		if ent.SpawnerEntity ~= nil then
			local spet = ent.SpawnerEntity--auxi.to_find_spawner(ent.SpawnerEntity)
			if spet.Type == 1 then
				local player = spet:ToPlayer()
				local d = player:GetData()
				if auxi.has_have_coll(player,item.entity) then
					local d2 = ent:GetData()
					local pos = ent.Position
					d2.Emblem_target_position = pos + ent.Velocity * 3
					if d2.out_of_room ~= true then
						if room:IsPositionInRoom(pos,-10) == true then
							assign_emblem_to_projectile(player,ent)
						else
							d2.out_of_room = true
						end
					end
				end
			end
		end
	end
end,
})

return item

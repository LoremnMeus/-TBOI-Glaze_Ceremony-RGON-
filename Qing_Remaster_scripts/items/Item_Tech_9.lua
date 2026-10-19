local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local classifier = attack_holder.classifier

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Tech_9,
	own_key = "Item_Tech_9_",
	-- Attack-level consumer key for SourceCanConsume / module delegation.
	consumer_key = "tech9",
}

local function player_has_item(player)
	return player and auxi.has_have_coll(player,item.entity)
end

local function normalize_dir(player,vel)
	if vel and vel:Length() > 0.01 then return vel:Normalized() end
	return classifier.GetPlayerAimDirection(player)
end

local function as_shot_velocity(player,vec,force_direction)
	local fallback_speed = math.max(6,(player and player.ShotSpeed or 1) * 10)
	if vec == nil or vec:Length() < 0.01 then
		return classifier.GetPlayerAimDirection(player) * fallback_speed
	end
	if force_direction == true then
		return vec:Normalized() * fallback_speed
	end
	local length = vec:Length()
	if length < 1 then return vec:Normalized() * fallback_speed end
	if length < fallback_speed then
		local target = vec:Normalized() * fallback_speed
		local alpha = (fallback_speed - length) / math.max(0.01,fallback_speed - 1)
		return vec * (1 - alpha) + target * alpha
	end
	return vec
end

local function mark_laser(laser,tag)
	if laser then
		laser:GetData()[tag or item.own_key.."laser"] = true
	end
	return laser
end

-- Attack inherit: `emitter` + `Source` both keep the intermediate member (tear/knife/…).
-- Holder splits Source → engine Spawner (player/mimic) + Parent = intermediate (see attack_fire_api).
local function inherit_opts(attack, emitter, reason, damage_scale)
	return {
		mode = "inherit",
		attack = attack,
		emitter = emitter,
		role = "derived",
		reason = reason or "tech9",
		damage_multiplier = damage_scale or 1,
		Source = emitter,
	}
end

local function aim_fire_opts(attack, emitter, reason, damage_scale)
	local opts = inherit_opts(attack, emitter, reason, damage_scale)
	if not attack or not attack.active or attack.ending then
		opts.mode = "untracked"
		opts.attack = nil
	end
	return opts
end

local function roll_bonus(rng, luck, count)
	luck = tonumber(luck) or 0
	count = math.max(1, math.floor(tonumber(count) or 1))
	if rng:RandomInt(1000) > math.max(600, 1000 - count * 60 - luck * 10) then
		return {kind = "techx", radius = rng:RandomInt(50) + 20}
	end
	if rng:RandomInt(1000) > math.max(800, 1000 - count * 100 - luck * 5) then
		return {kind = "tech"}
	end
	if rng:RandomInt(1000) > math.max(900, 1000 - count * 30 - luck * 3) then
		return {kind = "tech_eye"}
	end
	if rng:RandomInt(1000) > math.max(500, 1000 - count * 50 - luck * 35) then
		return {kind = "tech_onehit"}
	end
	return nil
end

local function apply_bonus(player, pos, vel, damage_scale, force_direction, attack, emitter, plan)
	if not plan or player == nil or not attack or not vel then return end
	if pos == nil then pos = player.Position end
	local shot_vel = as_shot_velocity(player, vel, force_direction)
	local dir = normalize_dir(player, shot_vel)
	damage_scale = damage_scale or 1
	if plan.kind == "techx" then
		local radius = plan.radius
		local q = attack_holder.FireTechXLaser(
			player,
			pos,
			shot_vel * ((auxi.random_1() + 1) / 2),
			radius,
			aim_fire_opts(attack, emitter, "tech9_techx", (radius / 70) * damage_scale)
		)
		mark_laser(q, item.own_key.."techx_laser")
		return true
	end
	if plan.kind == "tech" then
		local opts = aim_fire_opts(attack, emitter, "tech9_tech", 0.75 * damage_scale)
		opts.offset_id = LaserOffset.LASER_TECH1_OFFSET
		mark_laser(attack_holder.FireTechLaser(player, pos, dir, opts))
		return true
	end
	if plan.kind == "tech_eye" then
		local opts = aim_fire_opts(attack, emitter, "tech9_tech_eye", 0.75 * damage_scale)
		opts.offset_id = LaserOffset.LASER_TECH1_OFFSET
		opts.left_eye = true
		mark_laser(attack_holder.FireTechLaser(player, pos, dir, opts))
		return true
	end
	if plan.kind == "tech_onehit" then
		local opts = aim_fire_opts(attack, emitter, "tech9_tech_onehit", 1.3 * damage_scale)
		opts.offset_id = LaserOffset.LASER_TECH1_OFFSET
		opts.one_hit = true
		mark_laser(attack_holder.FireTechLaser(player, pos, dir, opts))
		return true
	end
	return false
end

local function fire_bonus(player, pos, vel, rng, damage_scale, force_direction, attack, emitter, luck, count)
	if player == nil or not attack or not vel then return end
	rng = rng or player:GetCollectibleRNG(item.entity)
	local plan = roll_bonus(rng, luck, count)
	return apply_bonus(player, pos, vel, damage_scale, force_direction, attack, emitter, plan)
end

local function resolve_tech9_roll_stats(player, attack, source)
	local luck = (player and player.Luck) or 0
	local count = player and player:GetCollectibleNum(item.entity) or 1
	if classifier.IsIndependentMimicSource(source) then
		local prof, fam = classifier.GetCraftProfileFromSource(source)
		local ok_air, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
		if ok_air and air and fam then
			luck = air.get_effective_luck(fam, prof)
		end
		count = math.max(1, classifier.GetCraftCollectibleCount(source, item.entity))
	end
	return luck, count
end

-- One Attack → at most one Tech9 bonus wave; lasers inherit the same Attack.
-- Policy: player Attack + inventory Tech IX, OR attack_mimic with SourceCanConsume("tech9").
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_ATTACK_ONCE, params = nil,
Function = function(_, event)
	local player = event and event.player
	local attack = event and event.attack
	local ent = event and event.member
	if not player or not attack or not ent then return end
	-- Skip Aquarius/Dark Art sample only; Ludo cadence Once is consumable.
	if classifier.IsSyntheticSampleAttack(attack) then return end
	local source = event.attack_source or attack.source
	if classifier.IsPlayerAttackSource(source) then
		if not player_has_item(player) then return end
	elseif not classifier.SourceCanConsume(source, item.consumer_key, player, attack) then
		return
	end
	local d = ent:GetData()
	if d[item.own_key.."laser"] == true or d[item.own_key.."techx_laser"] == true then return end
	local rng = player:GetCollectibleRNG(item.entity)
	local aim = classifier.GetAttackAimContext(source, attack, event)
	local luck, count = resolve_tech9_roll_stats(player, attack, source)
	local plan = roll_bonus(rng, luck, count)
	if not plan then return end
	local function launch(pos, dir)
		if not dir then return end
		apply_bonus(player, pos, dir, 1, true, attack, ent, plan)
	end
	if aim and aim.state == "pending" then
		attack_holder.WhenAttackDirectionReady(attack, function(atk, dir, state)
			if state ~= "resolved" or not dir then return end
			local pos = (aim and aim.position) or (atk and atk.position) or player.Position
			launch(pos, dir)
		end)
		return
	end
	local dir = aim and aim.direction
	if not dir then return end
	launch((aim and aim.position) or player.Position, dir)
end
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."techx_laser"] == true then
		if ent.FrameCount > 8 and ent.Velocity:Length() < 0.3 then
			ent:Remove()
		end
		return
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local d = ent:GetData()
		if ent.State == -1 then 
			if d[item.own_key.."counter"] == nil then 
				local player = auxi.check_spawner_player(ent)
				d[item.own_key.."counter"] = true
				local rng = ent:GetDropRNG()
				if player and rng:RandomFloat() > 0.7 then 
					-- Locust skill proc: not a player Attack round.
					local q = attack_holder.FireTechXLaser(player, ent.Position, ent.Velocity, 30, {
						mode = "untracked",
						reason = "tech9_locust",
						damage_multiplier = 0.3,
						Source = player,
					})
					if q then
						q.PositionOffset = ent.PositionOffset
						q.SubType = 3
						q.Parent = ent
						d[item.own_key.."effect"] = q
					end
				end
			end
		else
			if auxi.check_all_exists(d[item.own_key.."effect"]) then
				d[item.own_key.."effect"]:SetTimeout(1)
				d[item.own_key.."effect"] = nil
			end
			d[item.own_key.."counter"] = nil
		end
	end
end,
})

return item

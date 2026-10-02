local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Laser_holder = require("Qing_Remaster_scripts.mimics.Laser_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Evil_Intervention,
	own_key = "Item_Evil_Intervention_",
	consumer_key = "evil_intervention",
	tear_sprite = "gfx/mimics/Evil_Intervention/Evil_I_Tear.anm2",
}

local function player_has_evil(player)
	return player and auxi.has_have_coll(player, item.entity)
end

--- Player inventory Evil Intervention, OR Craft Attack whose recipe includes it.
local function attack_can_use_evil(player, attack, source)
	source = source or (attack and attack.source)
	if not player or not source then
		return false
	end
	if attack_holder.classifier.IsPlayerAttackSource(source) then
		return player_has_evil(player)
	end
	return attack_holder.classifier.SourceCanConsume(source, item.consumer_key, player, attack)
end

local function craft_or_player_luck(player, attack, source)
	source = source or (attack and attack.source)
	local luck = (player and player.Luck) or 0
	if attack_holder.classifier.IsIndependentMimicSource(source) then
		local prof, fam = attack_holder.classifier.GetCraftProfileFromSource(source)
		local ok_air, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
		if ok_air and air and fam then
			luck = air.get_effective_luck(fam, prof)
		end
	end
	return luck
end

function item.have_Ev_I_tear()
	local n_entity = Isaac.GetRoomEntities()
	local n_tear = auxi.getothers(n_entity,2)
	for u,v in pairs(n_tear) do if v:GetData()[item.own_key.."effect"] then return true end end
end

function item.load_tear_sprite(q)
	if not q then return end
	local s2 = q:GetSprite()
	s2:Load(item.tear_sprite,true)
	s2:Play("Idle",true)
	return q
end

function item.fire_fetus_tear(player,pos,vel,params)
	params = params or {}
	local q = auxi.fire_fetus(nil,player,pos,vel,true,true,{
		dmg = params.dmg,
		tearflags = params.tearflags,
		should_not_sound = params.should_not_sound,
		attack_ctx = params.attack_ctx,
		attack = params.attack,
		fire_mode = params.fire_mode or (params.attack_ctx == nil and params.attack == nil and "untracked") or nil,
		reason = params.reason or "evil_intervention_fetus",
	})
	item.load_tear_sprite(q)
	q.TearFlags = q.TearFlags | BitSet128(1<<0,0) | BitSet128(1<<1,0)
	return q
end

function item.fire_Ev_I_tear(q,pos,vel,player)
	q = q or Isaac.Spawn(2,0,0,pos,vel,player):ToTear()
	item.load_tear_sprite(q)
	q:GetData()[item.own_key.."effect"] = {}
	q.TearFlags = q.TearFlags & (~BitSet128(1<<60,0))
	q.TearFlags = q.TearFlags | BitSet128(1<<1,0) | BitSet128(1<<0,0) | BitSet128(1<<2,0) | BitSet128(0,1<<(114-64))
	q.FallingSpeed = q.FallingSpeed - auxi.random_1() * 2
	q.FallingAcceleration = q.FallingAcceleration - auxi.random_1() * 0.1
	return q
end

local function sample_shot_dir(event)
	local dir = event and event.direction
	if dir and dir:Length() > 0.01 then return dir end
	local ent = event and event.member
	if ent and ent.Velocity and ent.Velocity:Length() > 0.01 then return ent.Velocity end
	return Vector(1, 0)
end

local function inherit_conversion_opts(event, ent, reason)
	if event and event.attack then
		return {
			mode = "inherit",
			attack = event.attack,
			emitter = ent,
			role = "derived",
			reason = reason or "evil_intervention_conversion",
		}
	end
	attack_holder.warn_missing_parent_once(
		"evil_intervention_conversion",
		"Evil Intervention conversion without parent Attack; FireTear falls back to untracked."
	)
	return {
		mode = "untracked",
		reason = (reason or "evil_intervention_conversion") .. "_orphan",
	}
end

local warned_evil_orphan_burst = false
local function warn_evil_orphan_burst()
	local env = require("Qing_Remaster_scripts.core.dev_environment")
	if env.is_public_release and env.is_public_release() then return end
	if warned_evil_orphan_burst then return end
	warned_evil_orphan_burst = true
	Isaac.DebugString("[Qing AttackHolder] Evil Intervention carrier lost parent Attack; death burst falls back to untracked.")
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_ATTACK_DPS_SAMPLE, params = nil,
Function = function(_, event)
	local player = event and event.player
	local ent = event and event.member
	local attack = event and event.attack
	local source = event and event.attack_source or (attack and attack.source)
	if not attack_can_use_evil(player, attack, source) or not ent then return end
	if unique_holder.quest_signal_hash(item.own_key) == true then return end
	if not auxi.check_rand(craft_or_player_luck(player, attack, source), 20, 5, 7) then return end
	local d = ent:GetData()
	local is_tear = ent.Type == EntityType.ENTITY_TEAR
	if is_tear then
		if not d.Dont_Remove then
			item.fire_Ev_I_tear(ent, nil, nil, player)
		else
			-- Keep original tear; spawn a bound Evil Tear as derived member.
			local q = attack_holder.FireTear(player, ent.Position, ent.Velocity, inherit_conversion_opts(event, ent, "evil_intervention_conversion_copy"))
			if q then item.fire_Ev_I_tear(q, nil, nil, player) end
		end
		return
	end
	-- Non-tear sample: FireTear inherit so death burst can resolve parent Attack.
	local tdir = sample_shot_dir(event):Normalized() * player.ShotSpeed * 10
	local q = attack_holder.FireTear(
		player,
		event.position or ent.Position,
		tdir,
		inherit_conversion_opts(event, ent, "evil_intervention_conversion")
	)
	if q then
		item.fire_Ev_I_tear(q, nil, nil, player)
	end
end,
})
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local n_entity = Isaac.GetRoomEntities()
		local n_proj = auxi.getothers(n_entity,9)
		for u,v in pairs(n_proj) do
			if (v.Position - ent.Position):Length() < ent.Size + v.Size + 5 and math.abs(v.PositionOffset.Y - ent.PositionOffset.Y) < 30 then
				d[item.own_key.."effect"].tear = (d[item.own_key.."effect"].tear or 0) + 1
				v:Remove()
			end
		end
		--ent:GetSprite().Scale = Vector(1,1) * math.sqrt((d[item.own_key.."effect"].size or ent.Size)/ent.Size)
		--ent.Scale = (d[item.own_key.."effect"].size or ent.Size)/ent.Size
		--ent:ResetSpriteScale()
		local n_laser = auxi.getothers(n_entity,7)
		for u,v in pairs(n_laser) do
			if v.SubType == 0 and auxi.check_spawner_player(v) == nil and auxi.check_all_exists(v:GetData()[item.own_key.."Linker"]) ~= true then
				if auxi.on_laser_path(v:ToLaser(),ent.Position,{margin = ent.Size + v.Size,}) then v:GetData()[item.own_key.."Linker"] = ent v:ToLaser().TearFlags = BitSet128(0,0) d[item.own_key.."effect"].Attached = true end
			end
		end
		if d[item.own_key.."effect"].Attached then 
			if not d[item.own_key.."effect"].ChangeFlag then 
				ent.TearFlags = ent.TearFlags | BitSet128(0,1<<(82-64)) 
				ent.TearFlags = ent.TearFlags & ~(BitSet128(1<<2,0)|BitSet128(0,1<<(114-64)))
			end
		end
		if ent:IsDead() then
			local player = auxi.check_spawner_player(ent)
			local parent_attack = select(1, attack_holder.GetAttackForMember(ent))
			if not parent_attack then
				warn_evil_orphan_burst()
			end
			unique_holder.signal_hash(item.own_key,true)
			for i = 1,(d[item.own_key.."effect"].tear or 0) do
				local vel = auxi.random_r() * player.ShotSpeed * 10
				if parent_attack then
					attack_holder.FireTear(player, ent.Position, vel, {
						mode = "inherit",
						attack = parent_attack,
						emitter = ent,
						role = "derived",
						reason = "evil_intervention_burst",
					})
				else
					attack_holder.FireTear(player, ent.Position, vel, {
						mode = "untracked",
						reason = "evil_intervention_burst_orphan",
					})
				end
			end
			local cnt2 = 3 * math.ceil(d[item.own_key.."effect"].laser or 0)
			for i = 1,cnt2 do
				local q
				if parent_attack then
					q = attack_holder.FireBrimstone(player, auxi.random_r(), {
						mode = "inherit",
						attack = parent_attack,
						emitter = ent,
						role = "derived",
						reason = "evil_intervention_brim",
						damage_multiplier = 0.5,
					})
				else
					q = attack_holder.FireBrimstone(player, auxi.random_r(), {
						mode = "untracked",
						reason = "evil_intervention_brim_orphan",
						damage_multiplier = 0.5,
					})
				end
				if q then
					q.DisableFollowParent = true
					q.TearFlags = q.TearFlags & ~(BitSet128(1<<19,0))
					q.Position = ent.Position
				end
			end
			unique_holder.signal_hash(item.own_key,nil)
		end
		--d[item.own_key.."effect"].height = d[item.own_key.."effect"].height or ent.Height
		--ent.Height = d[item.own_key.."effect"].height
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_LASER_INIT_2_UPDATE, params = nil,
Function = function(_,v)
	if v.SubType == 0 and auxi.check_spawner_player(v) == nil and Laser_holder.is_new_laser(v) and auxi.check_all_exists(v:GetData()[item.own_key.."Linker"]) ~= true and item.have_Ev_I_tear() then
		local ep = EntityLaser.CalculateEndPoint(v.Position,auxi.get_by_rotate(Vector(1,0),v.Angle),v.PositionOffset,v.Parent,0)
		local n_entity = Isaac.GetRoomEntities()
		local n_tear = auxi.getothers(n_entity,2)
		for uu,vv in pairs(n_tear) do if vv:GetData()[item.own_key.."effect"] then
			if auxi.on_laser_path(v:ToLaser(),vv.Position,{margin = vv.Size + v.Size,ep = ep,}) then
			v:GetData()[item.own_key.."Linker"] = vv v:ToLaser().TearFlags = BitSet128(0,0) vv:GetData()[item.own_key.."effect"].Attached = true 
			Laser_holder.ProtectLaser(v) v:GetData()[item.own_key.."Protected"] = true 
			--v:Update()
			break end
		end end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if auxi.check_all_exists(d[item.own_key.."Linker"]) then
		local tg = d[item.own_key.."Linker"] local d2 = tg:GetData() 
		if d2[item.own_key.."effect"] then d2[item.own_key.."effect"].laser = (d2[item.own_key.."effect"].laser or 0) + 0.1 end
		local dir = tg.Position - ent.Position
		ent.Angle = dir:GetAngleDegrees()
		ent.MaxDistance = math.max(0,dir:Length() - ent.Size)
	end
	if d[item.own_key.."Protected"] then Laser_holder.UnProtectLaser(ent) end
end,
})

return item

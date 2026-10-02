local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local registry = require("Qing_Remaster_scripts.callbacks.attack_registry")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local weapon_path = require("Qing_Remaster_scripts.auxiliary.weapon_path_geometry")
local combat_output = require("Qing_Remaster_scripts.callbacks.combat_output_classifier")

local item = {
	myToCall = {},
	ToCall = {},
	entity = enums.Items.Assassin_s_Eye,
	own_key = "Item_Assassin_s_Eye_",
	consumer_key = "assassin",
}

local CHECKPOINT_SEARCH = 48
local LASER_DMG_MUL = 0.6
local MELEE_DMG_MUL = 0.75
-- MC_POST_TEAR_UPDATE ≈ 30Hz；Ludo 泪常驻，暗杀后另加约 0.5s CD，禁止连刺。
local LUDO_ASSASSIN_CD_FRAMES = 15

local function player_has_assassin(player)
	return player and auxi.has_have_coll(player, item.entity)
end

--- Player inventory Assassin, OR Craft Attack whose recipe includes Assassin's Eye.
local function attack_can_use_assassin(player, attack, source)
	source = source or (attack and attack.source)
	if not player or not source then
		return false
	end
	if attack_holder.classifier.IsPlayerAttackSource(source) then
		return player_has_assassin(player)
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

local function is_ludo_tear(ent)
	if not ent or not ent.TearFlags or not TearFlags or not TearFlags.TEAR_LUDOVICO then
		return false
	end
	return ent.TearFlags & TearFlags.TEAR_LUDOVICO == TearFlags.TEAR_LUDOVICO
end

--- Tear Assassin flag eligibility (Attack member or auxiliary player projectile).
--- Does not create Attacks; Fate / reactive tears qualify via output affiliation.
function item.ShouldMarkTear(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_TEAR then
		return false
	end
	local d = ent:GetData()
	if d[item.own_key .. "generated"] or attack_holder.IsIgnored(ent) then
		return false
	end
	local attack = select(1, registry.GetAttackForMember(ent))
	if attack and not attack_holder.IsSyntheticSampleAttack(attack) then
		return true
	end
	local out = combat_output.ClassifyCombatOutput(ent)
	if out and out.tier == "auxiliary_player_output" then
		local st = out.subtype
		if st == nil or st == "reactive_familiar_projectile" or st == "reactive_projectile" then
			return true
		end
	end
	return false
end

function item.fire_Assassin_tear(player, pos, vel, params)
	params = params or {}
	player = player or Game():GetPlayer(0)
	pos = pos or player.Position
	vel = vel or Vector(0, 0)
	local q = params.ent or Isaac.Spawn(2, 1, 0, pos, vel, player):ToTear()
	local d = q:GetData()
	d[item.own_key .. "effect"] = true
	d[item.own_key .. "generated"] = true
	d[item.own_key .. "counter"] = params.counter or 5
	return q
end

function item.Assassin_link(player, ent, col, dmg, params)
	params = params or {}
	player = player or Game():GetPlayer(0)
	local start_pos = params.start_pos or (ent and ent.Position) or player.Position
	local start_po_y = (ent and ent.PositionOffset and ent.PositionOffset.Y) or 0
	local q1 = Isaac.Spawn(1000, enums.Entities.MeusLink, 0, start_pos / 2 + col.Position / 2, Vector(0, 0), player)
	local s1 = q1:GetSprite()
	local dir = params.dir or (col.Position - start_pos)
	local ang = dir:GetAngleDegrees() + math.random(20000) / 1000 - 10
	local leg = dir:Length() + col.Size * 1.3 + 5
	s1.Rotation = ang - 90
	s1.Scale = auxi.mul_t(Vector(leg / 120, 1 / 10), params.Scaler or Vector(1, 1))
	q1.PositionOffset = Vector(0, start_po_y)
	col:TakeDamage(dmg, 0, EntityRef(player), 0)
	if not params.Ignore_ent and ent then
		ent.Position = ent.Position + auxi.MakeVector(ang) * (leg)
		ent.Velocity = auxi.MakeVector(ang) * (params.endleg or ent.Velocity:Length())
		ent:SetColor(Color(1, 1, 1, 1, -2, -2, -2), 15, 99, true, false)
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_TOOTH_AND_NAIL, math.random(1000) / 10000 + 0.95, math.random(1000) / 10000 + 0.95, false, 0, 2)
	return q1
end

local function nearest_enemy_at(pos, radius)
	local list = auxi.getenemies(Isaac.FindInRadius(pos, radius, 1 << 3))
	if not list or #list == 0 then return nil end
	return auxi.getdisenemies(list, pos, 100) or auxi.random_in_table(list)
end

local function try_checkpoint_assassin(player, laser, checkpoint, dmg, attack, source)
	if not player or not laser or not checkpoint then return end
	local d = laser:GetData()
	local slots = d[item.own_key .. "assassin_slots"]
	if not slots then
		slots = {}
		d[item.own_key .. "assassin_slots"] = slots
	end
	local sid = checkpoint.id
	-- Topology slot (L# / R#): empty space does not consume; first valid target → one roll.
	if slots[sid] then return end
	local targ = nearest_enemy_at(checkpoint.position, CHECKPOINT_SEARCH)
	if not auxi.check_all_exists(targ) then
		return
	end
	slots[sid] = true
	if not auxi.check_rand(craft_or_player_luck(player, attack, source), 10, 5, 5) then
		return
	end
	local dir = targ.Position - checkpoint.position
	item.Assassin_link(player, laser, targ, dmg, {
		Ignore_ent = true,
		start_pos = checkpoint.position,
		dir = dir,
	})
end

-- Tear path: Attack members (MEMBER_BOUND) + auxiliary reactive tears (INIT).
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_ATTACK_MEMBER_BOUND,
	params = nil,
	Function = function(_, event)
		local player = event and event.player
		local attack = event and event.attack
		local ent = event and event.member
		if not attack_can_use_assassin(player, attack, event.attack_source or (attack and attack.source)) then return end
		if not attack or attack_holder.IsSyntheticSampleAttack(attack) then return end
		if not ent or ent.Type ~= EntityType.ENTITY_TEAR then return end
		if item.ShouldMarkTear(ent) then
			ent:GetData()[item.own_key .. "effect"] = true
		end
	end,
})

-- Fate / reactive familiar tears: no Attack Bind — mark via output affiliation.
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_TEAR_INIT,
	params = nil,
	Function = function(_, ent)
		if not ent or not item.ShouldMarkTear(ent) then return end
		local out = combat_output.ClassifyCombatOutput(ent)
		local player = (out and out.owner_player)
			or auxi.check_spawner_player(ent)
		if not player_has_assassin(player) then return end
		ent:GetData()[item.own_key .. "effect"] = true
	end,
})

-- Bomb / Epic / other non-laser once-per-Attack (first suitable DPS sample).
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_ATTACK_DPS_SAMPLE,
	params = nil,
	Function = function(_, event)
		local player = event and event.player
		local attack = event and event.attack
		local ent = event and event.member
		local source = event and event.attack_source or (attack and attack.source)
		if not attack_can_use_assassin(player, attack, source) or not attack or not ent then return end
		if attack_holder.IsSyntheticSampleAttack(attack) then return end
		local family = attack.family
		if family ~= "bomb" and family ~= "epic" then return end
		attack.tags = attack.tags or {}
		if attack.tags.assassin_other_checked then return end
		attack.tags.assassin_other_checked = true
		if not auxi.check_rand(craft_or_player_luck(player, attack, source), 10, 5, 5) then return end
		local pos = event.position or ent.Position
		local targ = nearest_enemy_at(pos, 100)
		if not auxi.check_all_exists(targ) then return end
		local dmg = (ent.CollisionDamage or player.Damage or 3.5) * MELEE_DMG_MUL
		item.Assassin_link(player, ent, targ, dmg, {
			Ignore_ent = true,
			start_pos = pos,
			dir = targ.Position - pos,
		})
	end,
})

-- Knife / sword / melee: one chance per logical Attack (do not teleport the weapon).
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_ATTACK_ONCE,
	params = nil,
	Function = function(_, event)
		local player = event and event.player
		local attack = event and event.attack
		local ent = event and event.member
		local source = event and event.attack_source or (attack and attack.source)
		if not attack_can_use_assassin(player, attack, source) or not attack or not ent then return end
		if attack_holder.IsSyntheticSampleAttack(attack) then return end
		local family = attack.family
		if family ~= "knife" and family ~= "sword" and family ~= "bone_club" then return end
		attack.tags = attack.tags or {}
		if attack.tags.assassin_other_checked then return end
		attack.tags.assassin_other_checked = true
		if not auxi.check_rand(craft_or_player_luck(player, attack, source), 10, 5, 5) then return end
		local pos = event.position or ent.Position or player.Position
		local targ = nearest_enemy_at(pos, 120)
		if not auxi.check_all_exists(targ) then return end
		local dmg = (ent.CollisionDamage or player.Damage or 3.5) * MELEE_DMG_MUL
		item.Assassin_link(player, ent, targ, dmg, {
			Ignore_ent = true,
			start_pos = pos,
			dir = targ.Position - pos,
		})
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_TEAR_UPDATE,
	params = nil,
	Function = function(_, ent)
		local player = auxi.check_spawner_player(ent)
		local d = ent:GetData()
		if player and (
			(d[item.own_key .. "effect"] and not attack_holder.IsIgnored(ent))
			or d.is_assassin ~= nil
		) then
			d[item.own_key .. "counter"] = (d[item.own_key .. "counter"] or 5) - 1
			if d[item.own_key .. "counter"] <= 0 then
				local range = math.min(180, player.TearRange * 0.3)
				local n_enemy = auxi.getenemies(Isaac.FindInRadius(ent.Position, range, 1 << 3))
				if #n_enemy > 0 then
					local targ = auxi.getdisenemies(n_enemy, ent.Position, 100) or auxi.random_in_table(n_enemy)
					if auxi.check_all_exists(targ) then
						item.Assassin_link(player, ent, targ, ent.CollisionDamage * 0.75, {
							Scaler = Vector(1, ent.Scale),
							endleg = 1,
						})
						if is_ludo_tear(ent) then
							d[item.own_key .. "counter"] = LUDO_ASSASSIN_CD_FRAMES
						elseif d.is_assassin then
							d[item.own_key .. "counter"] = 5
						else
							d[item.own_key .. "counter"] = math.max(8, player.MaxFireDelay * 1.3)
						end
					end
				end
			end
		end
	end,
})

-- Laser / Brim / Tech X: Gospel-aligned checkpoints; one roll per slot lifetime.
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_LASER_UPDATE,
	params = nil,
	Function = function(_, laser)
		if not laser then return end
		local attack = select(1, registry.GetAttackForMember(laser))
		if not attack or attack_holder.IsSyntheticSampleAttack(attack) then return end
		local player = attack.player or auxi.check_spawner_player(laser)
		local source = attack.source
		if not attack_can_use_assassin(player, attack, source) then return end
		local points
		if weapon_path.is_ring_laser(laser) or attack.family == "techx" then
			points = weapon_path.GetRingLaserPoints(laser)
		else
			points = weapon_path.GetLinearLaserPoints(laser)
		end
		local dmg = (laser.CollisionDamage or player.Damage or 3.5) * LASER_DMG_MUL
		for i = 1, #points do
			try_checkpoint_assassin(player, laser, points[i], dmg, attack, source)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_UPDATE,
	params = FamiliarVariant.ABYSS_LOCUST,
	Function = function(_, ent)
		if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
			local d = ent:GetData()
			if (d[item.own_key .. "counter"] or 0) > 0 then
				d[item.own_key .. "counter"] = d[item.own_key .. "counter"] - 1
			elseif ent.State == -1 then
				local n_enemy = auxi.getenemies(Isaac.FindInRadius(ent.Position, 100, 1 << 3))
				if #n_enemy > 0 then
					local player = auxi.check_spawner_player(ent)
					local targ = auxi.getdisenemies(n_enemy, ent.Position, 100) or auxi.random_in_table(n_enemy)
					if auxi.check_all_exists(targ) then
						item.Assassin_link(player, ent, targ, 3.5)
						d[item.own_key .. "counter"] = 3
						d[item.own_key .. "counter2"] = (d[item.own_key .. "counter2"] or 0) + 1
						if d[item.own_key .. "counter2"] > 3 then
							d[item.own_key .. "counter2"] = 0
							d[item.own_key .. "counter"] = 30
						end
					end
				end
			end
		end
	end,
})

return item

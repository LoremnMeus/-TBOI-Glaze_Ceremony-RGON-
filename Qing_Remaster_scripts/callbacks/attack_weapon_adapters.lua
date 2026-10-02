-- Weapon adapters: Tear/Tech/Brim/TechX/Knife/Ludo volleys. END only via registry.EndAttack.
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local registry = require("Qing_Remaster_scripts.callbacks.attack_registry")
local grouping = require("Qing_Remaster_scripts.callbacks.attack_grouping")
local dps = require("Qing_Remaster_scripts.callbacks.attack_dps_sampler")
local classifier = require("Qing_Remaster_scripts.callbacks.attack_source_classifier")
local fire_context = require("Qing_Remaster_scripts.callbacks.attack_fire_context")

local EVIL_EYE_VARIANT = (EffectVariant and EffectVariant.EVIL_EYE) or 84

local M = {
	ToCall = {},
	myToCall = {},
	own_key = "attack_weapon_adapters_",
	-- Exclude from Mom's-Knife IsFlying Attack path.
	-- Knife family ownership (ENTITY_KNIFE Type 8):
	--   bone_club: 8.1 / 8.2 / 8.3 / 8.9 (BONE_CLUB / BONE_SCYTHE / BERSERK|DONKEY_JAWBONE / NOTCHED_AXE)
	--   moms_knife: 8.0 / 8.5 (MOMS_KNIFE / SUMPTORIUM) only
	--   spirit_sword: 8.10 / 8.11 (SPIRIT_SWORD / TECH_SWORD) only
	-- Bag of Crafting (8.4) and Tecro spears stay blacklisted (not weapon Attack collectors).
	knife_blacklist = {
		[4] = true, -- Bag of Crafting
		[enums.Entities.Tecro_Spear] = true,
		[enums.Entities.Tecro_Laser_Spear] = true,
	},
	-- ptr -> Mom's Knife flying state only (not Bone Club / Spirit Sword).
	knife_state = {},
	-- ptr -> Bone Club swing/throw instance state (must not share knife_state.flying).
	bone_club_state = {},
	-- Epic: InitSeed → true after first successful Bind (survives GetData wipe / post-remove zombie UPDATE).
	epic_claimed = {},
	-- source_id -> ludo synthetic cadence (player and mimic familiars do not share).
	source_ludo_state = {},
}

-- Forward decl: laser SubType-1 UPDATE runs before the tear-ludo block defines the body.
local resolve_ludo_source
local source_ludo_state
local ludo_fire_direction
local begin_ludo_cadence_attack

local function should_ignore(ent)
	return classifier.IsIgnored(ent)
end

local function resolve_ctx_attack(ctx)
	if not ctx then return nil end
	if ctx.attack and ctx.attack.active and not ctx.attack.ending then
		return ctx.attack
	end
	if ctx.attack_id then
		local a = registry.GetAttack(ctx.attack_id)
		if a and a.active and not a.ending then
			return a
		end
	end
	if ctx.emitter then
		local a = select(1, registry.GetAttackForMember(ctx.emitter))
		if a and a.active and not a.ending then
			return a
		end
	end
	return nil
end

--- Explicit Fire Context first; otherwise ResolveCandidate inference.
--- When ctx ~= nil: execute ONLY ctx.mode (never rewrite new_attack→inherit via Parent/Spawner heuristics).
--- When ctx == nil: existing binding / proxy inherit → MarkIgnore / DATA_IGNORE → ResolveCandidate.
local function bind_from_candidate(ent, family, opts)
	opts = opts or {}
	local ctx = fire_context.Peek()
	if ctx ~= nil then
		local existing = select(1, registry.GetAttackForMember(ent))
		if ctx.mode == "untracked" or ctx.mode == "ignore" then
			return { mode = "ignore", reason = "fire_context_untracked" }
		end
		if ctx.mode == "inherit" then
			local parent = resolve_ctx_attack(ctx)
			if not parent then
				return { mode = "ignore", reason = "fire_context_inherit_missing" }
			end
			if existing then
				if existing.id == parent.id then
					return {
						mode = "already",
						parent_attack = existing,
						attack = existing,
						owner_player = existing.player,
						source_id = existing.source_id,
						source = existing.source,
						reason = "fire_context_inherit_already",
					}
				end
				-- Conflict: do not silently rebind / rewrite semantics.
				Isaac.DebugString("[Qing AttackFire] inherit conflict: member already on other Attack")
				return {
					mode = "already",
					parent_attack = existing,
					attack = existing,
					owner_player = existing.player,
					source_id = existing.source_id,
					source = existing.source,
					reason = "fire_context_inherit_conflict",
				}
			end
			local role = opts.role or ctx.role or "derived"
			local ok = registry.BindMember(parent, ent, {
				allow_sealed = true,
				role = role,
				reason = opts.reason or ctx.reason or "fire_inherit",
				direction = opts.direction,
				position = opts.position,
			})
			local resolved = {
				mode = "inherit",
				parent_attack = parent,
				owner_player = parent.player,
				source_id = parent.source_id,
				source = parent.source,
				role_hint = role,
				reason = "fire_context_inherit",
			}
			if ok then
				resolved.attack = parent
				if role == "proxy" then
					ent:GetData()[classifier.DATA_PROXY_MARK] = true
				end
			end
			return resolved
		end
		if ctx.mode == "new_attack" then
			-- Never fall through to proxy/Parent inherit heuristics while ctx is set.
			if existing then
				Isaac.DebugString("[Qing AttackFire] new_attack: member already bound; keep existing")
				return {
					mode = "already",
					parent_attack = existing,
					attack = existing,
					owner_player = existing.player,
					source_id = existing.source_id,
					source = existing.source,
					reason = "fire_context_new_attack_already",
				}
			end
			local source = ctx.source or ctx.source_entity
			local owner_player = nil
			local source_id = nil
			local source_desc = nil
			if source and classifier.IsMimicFamiliar(source) then
				owner_player = classifier.resolve_owner_player(source)
				source_desc = classifier.make_mimic_source(source, owner_player)
				source_id = source_desc and source_desc.source_id
			elseif source and source.ToPlayer and source:ToPlayer() then
				owner_player = source:ToPlayer()
				source_desc = classifier.make_player_source(owner_player)
				source_id = source_desc and source_desc.source_id
			end
			if not owner_player or not source_id or not source_desc then
				return { mode = "ignore", reason = "fire_context_new_attack_no_source" }
			end
			local role = opts.role or ctx.role or "primary"
			-- Explicit new_attack: do not auto-promote to proxy via is_proxy_entity heuristics.
			local attack = grouping.create_or_join(owner_player, family or ctx.family or "unknown", {
				max_frame_delta = opts.max_frame_delta or 0,
				direction = opts.direction,
				position = opts.position,
				source_id = source_id,
				source = source_desc,
				synthetic = opts.synthetic,
				reason = opts.reason or ctx.reason or "fire_new_attack",
			})
			local ok = registry.BindMember(attack, ent, {
				role = role,
				reason = opts.reason or ctx.reason or "fire_new_attack",
				direction = opts.direction,
				position = opts.position,
				allow_sealed = opts.allow_sealed,
			})
			local resolved = {
				mode = classifier.IsMimicFamiliar(source) and "mimic" or "player",
				owner_player = owner_player,
				source_id = source_id,
				source = source_desc,
				role_hint = role,
				reason = "fire_context_new_attack",
			}
			if ok then
				resolved.attack = attack
				if role == "proxy" then
					ent:GetData()[classifier.DATA_PROXY_MARK] = true
				end
			end
			return resolved
		end
		-- Unknown ctx.mode under explicit context: drop (never invent new_attack).
		return { mode = "ignore", reason = "fire_context_unknown_mode" }
	end

	-- No explicit Fire Context: vanilla inference (MarkIgnore / DATA_IGNORE via IsIgnored).
	local resolved = classifier.ResolveCandidate(ent, family, opts)
	if resolved.mode == "ignore" or resolved.mode == "already" then
		return resolved
	end
	if resolved.mode == "inherit" then
		local role = opts.role or resolved.role_hint
			or (classifier.is_proxy_entity(ent) and "proxy")
			or "derived"
		local ok = registry.BindMember(resolved.parent_attack, ent, {
			allow_sealed = true,
			role = role,
			reason = opts.reason or "inherit",
			direction = opts.direction,
			position = opts.position,
		})
		if ok then
			resolved.attack = resolved.parent_attack
		end
		return resolved
	end
	if resolved.mode == "player" or resolved.mode == "mimic" then
		local role = opts.role or resolved.role_hint
			or (classifier.is_proxy_entity(ent) and "proxy")
			or "primary"
		local attack = grouping.create_or_join(resolved.owner_player, family, {
			max_frame_delta = opts.max_frame_delta or 0,
			direction = opts.direction,
			position = opts.position,
			source_id = resolved.source_id,
			source = resolved.source,
			synthetic = opts.synthetic,
			reason = opts.reason or resolved.mode or family,
		})
		local ok = registry.BindMember(attack, ent, {
			role = role,
			reason = opts.reason or resolved.mode,
			direction = opts.direction,
			position = opts.position,
			allow_sealed = opts.allow_sealed,
		})
		if ok then
			resolved.attack = attack
			if role == "proxy" then
				ent:GetData()[classifier.DATA_PROXY_MARK] = true
			end
		end
		return resolved
	end
	return resolved
end

local function is_weapon_laser(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_LASER then return false end
	local sub = ent.SubType or 0
	if sub == 1 or sub == 2 then return true end
	local v = ent.Variant or -1
	return v == 1 or v == 2 or v == 6 or v == 9 or v == 11 or v == 12 or v == 14 or v == 15
end

local function laser_family(ent)
	if not ent then return "technology" end
	if ent.SubType == 2 then return "techx" end
	if ent.SubType == 1 then return "technology" end -- LaserLudo treated as technology synthetic
	if ent.Variant == 2 then return "technology" end
	return "brimstone"
end

local function laser_rate(ent, player)
	if not player or not player.Damage or player.Damage == 0 then return 1 end
	local rate = (ent.CollisionDamage or 0) / player.Damage
	if ent.MaxDistance and ent.MaxDistance >= 30 and ent.MaxDistance <= 100 then
		rate = rate * 0.5
	end
	return rate
end

local function family_sealed_ready(ent)
	return ent.FrameCount >= 2
end

--- Tear: same Game frame cohort (max_frame_delta=0). Seal on next update via seal_expired.
--- Full-health Spirit Sword beams (SWORD_BEAM / TECH_SWORD_BEAM) join the sword Attack instead.
local function is_sword_beam_tear(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_TEAR then return false end
	local v = ent.Variant or -1
	if TearVariant then
		if TearVariant.SWORD_BEAM and v == TearVariant.SWORD_BEAM then return true end
		if TearVariant.TECH_SWORD_BEAM and v == TearVariant.TECH_SWORD_BEAM then return true end
	end
	return v == 47 or v == 49
end

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_FIRE_TEAR,
	params = nil,
	Function = function(_, ent)
		if should_ignore(ent) then return end
		-- Ludovico tear is not a fire-tear volley member.
		if ent.TearFlags & BitSet128(0, 1 << (127 - 64)) == BitSet128(0, 1 << (127 - 64)) then
			return
		end

		if is_sword_beam_tear(ent) then
			-- Join the live Spirit Sword Attack (gospel Once already on that Attack).
			local owner = classifier.resolve_owner_player(ent)
			if owner and M.try_bind_sword_beam_tear then
				M.try_bind_sword_beam_tear(ent, owner)
			end
			return
		end

		local resolved = bind_from_candidate(ent, "tear", {
			from_fire_callback = true,
			max_frame_delta = 0,
			direction = ent.Velocity,
			position = ent.Position,
		})
		if resolved.attack and (resolved.mode == "player" or resolved.mode == "mimic" or resolved.mode == "inherit") then
			dps.sample_tear_member(resolved.attack, ent, { direction = ent.Velocity })
		end
	end,
})

-- Fate's Reward / Incubus / Twisted / etc. use Familiar:FireProjectile — NOT MC_POST_FIRE_TEAR.
local function bind_familiar_fired_tear(ent)
	if should_ignore(ent) then return end
	if not ent then return end
	-- Ludo satellites still use the synthetic tear UPDATE path.
	if ent.TearFlags and ent.TearFlags & BitSet128(0, 1 << (127 - 64)) == BitSet128(0, 1 << (127 - 64)) then
		return
	end
	local resolved = bind_from_candidate(ent, "tear", {
		from_fire_callback = true,
		allow_create = true,
		allow_mimic_create = true,
		max_frame_delta = 0,
		direction = ent.Velocity,
		position = ent.Position,
		reason = "familiar_fire_projectile",
	})
	if resolved.attack and (resolved.mode == "mimic" or resolved.mode == "inherit" or resolved.mode == "player") then
		dps.sample_tear_member(resolved.attack, ent, { direction = ent.Velocity })
	end
end

if ModCallbacks.MC_POST_FAMILIAR_FIRE_PROJECTILE then
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_FAMILIAR_FIRE_PROJECTILE,
	params = nil,
	Function = function(_, ent)
		bind_familiar_fired_tear(ent)
	end,
})
end

-- Incubus/Twisted brim / tech via familiar fire APIs (whitelist only via ResolveCandidate).
if ModCallbacks.MC_POST_FAMILIAR_FIRE_BRIMSTONE then
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_FAMILIAR_FIRE_BRIMSTONE,
	params = nil,
	Function = function(_, ent)
		if should_ignore(ent) then return end
		bind_from_candidate(ent, "brimstone", {
			from_fire_callback = true,
			allow_create = true,
			allow_mimic_create = true,
			max_frame_delta = 1,
			position = ent.Position,
			reason = "familiar_fire_brimstone",
		})
	end,
})
end

if ModCallbacks.MC_POST_FAMILIAR_FIRE_TECH_LASER then
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_FAMILIAR_FIRE_TECH_LASER,
	params = nil,
	Function = function(_, ent)
		if should_ignore(ent) then return end
		bind_from_candidate(ent, laser_family(ent), {
			from_fire_callback = true,
			allow_create = true,
			allow_mimic_create = true,
			max_frame_delta = 1,
			position = ent.Position,
			reason = "familiar_fire_tech",
		})
	end,
})
end

-- Evil Eye: proxy carrier for the firing Attack (does not create its own Once later).
if ModCallbacks.MC_POST_EFFECT_INIT then
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_INIT,
	params = EVIL_EYE_VARIANT,
	Function = function(_, ent)
		if should_ignore(ent) then return end
		if not classifier.is_evil_eye_effect(ent) then return end
		bind_from_candidate(ent, "tear", {
			from_fire_callback = true,
			allow_create = true,
			max_frame_delta = 0,
			role = "proxy",
			reason = "evil_eye_proxy",
			position = ent.Position,
		})
	end,
})
end

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
	params = nil,
	Function = function(_, ent)
		if not ent then return end
		local hash = GetPtrHash(ent)
		local binding = registry.bindings[hash]
		if binding then
			local attack = registry.GetAttack(binding.attack_id)
			-- Bomb/Epic explode after remove; sword melee attributes via ExtraSource and may
			-- land the same frame the hitbox is removed — remember briefly.
			if attack and (attack.family == "bomb" or attack.family == "epic" or attack.family == "sword" or attack.family == "bone_club") then
				registry.remember_for_damage(ent, attack, binding.generation)
				local player = attack.player
				if player then
					registry.remember_player_blast(player, attack, binding.generation, ent.Position)
				end
			end
			registry.UnbindMember(ent, "entity_removed")
		end
		dps.clear_hash(hash)
		M.knife_state[hash] = nil
		M.bone_club_state[hash] = nil
	end,
})

local function try_bind_laser(ent)
	if should_ignore(ent) then return end
	if not is_weapon_laser(ent) then return end
	-- Persistent ludo ring: synthetic cadence in UPDATE, not init bind-once.
	if ent.SubType == 1 then return end
	local hash = GetPtrHash(ent)
	if registry.bindings[hash] then return end

	local family = laser_family(ent)
	local max_delta = 0
	if family == "technology" or family == "brimstone" then
		max_delta = 1
	end
	if family == "techx" then
		max_delta = 0
	end

	-- Familiar lasers (Little Brimstone, etc.) ignore; Incubus/mimic create; parent proxy inherits.
	bind_from_candidate(ent, family, {
		allow_create = true,
		allow_mimic_create = true,
		max_frame_delta = max_delta,
		position = ent.Position,
		reason = "laser_bind",
	})
end

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_LASER_INIT,
	params = nil,
	Function = function(_, ent)
		try_bind_laser(ent)
	end,
})

table.insert(M.myToCall, #M.myToCall + 1, {
	CallBack = enums.Callbacks.POST_LASER_INIT_2_UPDATE,
	params = nil,
	Function = function(_, ent)
		try_bind_laser(ent)
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_LASER_UPDATE,
	params = nil,
	Function = function(_, ent)
		if should_ignore(ent) then return end

		-- Tech X: bind on early frame if missed init.
		if ent.SubType == 2 then
			try_bind_laser(ent)
			local attack = select(1, registry.GetAttackForMember(ent))
			if attack and attack.open_for_members and ent.FrameCount >= 2 then
				grouping.seal_attack_and_clear(attack)
			end
			return
		end

		-- Laser Ludo / Tech+Ludo / Brim+Ludo floating ring (SubType 1).
		-- Same cadence Once model as tear Ludo (family=ludo); direction = Velocity else random.
		if ent.SubType == 1 then
			local player, source_id, source = resolve_ludo_source(ent)
			if not player or not source_id then return end
			local delay = math.max(1, (player.MaxFireDelay or 10) * 1.5)
			local st = source_ludo_state(source_id)
			local frame = Game():GetFrameCount()
			local cur = st.attack_id and registry.GetAttack(st.attack_id)
			if cur and (not cur.active or cur.ending) then
				cur = nil
				st.attack_id = nil
			end
			-- Reclassify non-ludo bindings on the floating ring.
			local bound = select(1, registry.GetAttackForMember(ent))
			if bound and bound.family ~= "ludo" then
				registry.UnbindMember(ent, "ludo_laser_reclassify")
			end
			if st.last_frame ~= frame then
				st.last_frame = frame
				if not cur then
					cur = begin_ludo_cadence_attack(player, source_id, source, ent, "ludo_open")
					st.attack_id = cur and cur.id or nil
					st.cd = 0
				else
					st.cd = (st.cd or 0) + 1
					if cur.active and not cur.ending then
						dps.feed_rate(cur, ent, laser_rate(ent, player) / delay, {
							direction = ludo_fire_direction(ent, player),
							reason = "laser_ludo",
						})
					end
					if st.cd >= delay then
						st.cd = 0
						registry.EndAttack(cur, "ludo_rollover")
						local neu = begin_ludo_cadence_attack(
							player,
							source_id,
							cur.source or source,
							ent,
							"ludo_rollover"
						)
						st.attack_id = neu and neu.id or nil
					end
				end
			elseif cur and cur.active and not cur.ending then
				registry.BindMember(cur, ent, {
					direction = ludo_fire_direction(ent, player),
					role = "primary",
					reason = "ludo_laser_same_frame",
					allow_sealed = true,
				})
			end
			return
		end

		if ent.SubType ~= 0 then return end
		if ent.Variant == 10 or ent.Variant == 7 then return end

		try_bind_laser(ent)
		local attack = select(1, registry.GetAttackForMember(ent))
		if not attack then return end
		local player = attack.player or classifier.resolve_owner_player(ent)
		if not player then return end

		if attack.open_for_members and family_sealed_ready(ent) then
			grouping.seal_attack_and_clear(attack)
		end

		if not attack.active or attack.ending then return end
		local rate = laser_rate(ent, player)
		dps.feed_rate(attack, ent, rate / 5, {
			direction = ent.Velocity,
			reason = laser_family(ent),
		})
	end,
})

local function is_ludo_tear(ent)
	if not ent or not ent.TearFlags then return false end
	return ent.TearFlags & BitSet128(0, 1 << (127 - 64)) == BitSet128(0, 1 << (127 - 64))
end

--- Ludovico is a controlled player weapon. Spawner may be Flight/craft Air (Type=Familiar)
--- after spawn; that must NOT be treated like Brother Bobby / Little Brimstone.
--- Only mimic-whitelist familiars keep an independent source_id.
resolve_ludo_source = function(ent)
	local player = classifier.resolve_owner_player(ent)
	if not player then return nil, nil, nil end
	local emitter = classifier.get_immediate_emitter(ent)
	if classifier.IsMimicFamiliar(emitter) then
		local source = classifier.make_mimic_source(emitter, player)
		return player, source.source_id, source
	end
	local source = classifier.make_player_source(player)
	return player, source.source_id, source
end

local function collect_source_ludo_tears(source_id, owner_player)
	local list = {}
	if not source_id then return list end
	local tears = Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, false, false)
	for i = 1, #tears do
		local tear = tears[i]
		if is_ludo_tear(tear) and not should_ignore(tear) then
			local _, sid = resolve_ludo_source(tear)
			if sid == source_id then
				list[#list + 1] = tear
			end
		end
	end
	return list
end

source_ludo_state = function(source_id)
	local st = M.source_ludo_state[source_id]
	if type(st) ~= "table" then
		st = { cd = 0, last_frame = -1, attack_id = nil }
		M.source_ludo_state[source_id] = st
	end
	return st
end

ludo_fire_direction = function(ent, owner)
	if ent and ent.Velocity and ent.Velocity:Length() > 0.01 then
		return ent.Velocity:Normalized()
	end
	local seed = (ent and ent.InitSeed) or (owner and owner.InitSeed) or Random()
	local rng = RNG()
	rng:SetSeed((seed % 2147483646) + 1, 35)
	return auxi.MakeVector(rng:RandomInt(360))
end

local function bind_ludo_member(attack, ent, reason)
	if not attack or not ent then return false end
	local hash = GetPtrHash(ent)
	local binding = registry.bindings[hash]
	if binding and binding.attack_id ~= attack.id then
		registry.UnbindMember(ent, "rebind")
	end
	if registry.bindings[hash] and registry.bindings[hash].attack_id == attack.id then
		return true
	end
	local dir = ludo_fire_direction(ent, attack.player)
	return registry.BindMember(attack, ent, {
		direction = dir,
		role = "primary",
		reason = reason or "ludo_bind",
		allow_sealed = false,
	})
end

local function bind_all_ludo_to_attack(attack, source_id, owner_player, seed_ent)
	if not attack or not attack.open_for_members then return end
	-- Always bind the cadence seed first (FindByType can miss the current UPDATE entity).
	if seed_ent then
		bind_ludo_member(attack, seed_ent, "ludo_seed")
	end
	local tears = collect_source_ludo_tears(source_id, owner_player)
	for i = 1, #tears do
		bind_ludo_member(attack, tears[i], "ludo_bind")
	end
end

--- Open one Ludo cadence Attack (tear or floating laser): Bind → Once → Seal.
begin_ludo_cadence_attack = function(player, source_id, source, seed_ent, reason)
	local dir = ludo_fire_direction(seed_ent, player)
	local attack = registry.CreateAttack(player, "ludo", {
		synthetic = true,
		synthetic_kind = "ludo",
		synthetic_reason = reason or "ludo_open",
		position = seed_ent and seed_ent.Position or player.Position,
		direction = dir,
		source_id = source_id,
		source = source,
		reason = reason or "ludo_open",
		collector = "ludo",
	})
	if not attack then return nil end
	if seed_ent and seed_ent.Type == EntityType.ENTITY_TEAR then
		bind_all_ludo_to_attack(attack, source_id, player, seed_ent)
	else
		bind_ludo_member(attack, seed_ent, reason or "ludo_open")
	end
	if attack.open_for_members then
		registry.SealAttack(attack)
	end
	return attack
end

-- Ludovico: per-source cadence Attack. Each fire-delay beat = one Once (like Bone Club swing).
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_TEAR_UPDATE,
	params = nil,
	Function = function(_, ent)
		if should_ignore(ent) then return end
		-- Late-join if POST_FIRE_TEAR raced ahead of FIRE_SWORD / hold.
		if is_sword_beam_tear(ent) and not registry.bindings[GetPtrHash(ent)] then
			local player = classifier.resolve_owner_player(ent)
			if player and M.try_bind_sword_beam_tear then
				M.try_bind_sword_beam_tear(ent, player)
			end
			return
		end
		-- Late-bind mimic familiar tears if FAMILIAR_FIRE_PROJECTILE was missed
		-- (Spawner/Parent assigned after FireProjectile return, e.g. craft finish_tear).
		if not is_ludo_tear(ent) and not registry.bindings[GetPtrHash(ent)] then
			local emitter = classifier.get_immediate_emitter(ent)
			if classifier.IsMimicFamiliar(emitter) then
				bind_familiar_fired_tear(ent)
				return
			end
			-- C Section: Variant/TEAR_FETUS often applied after FireTear returns.
			if classifier.is_fetus_tear(ent) then
				local resolved = bind_from_candidate(ent, "tear", {
					from_fire_callback = true,
					allow_create = true,
					max_frame_delta = 0,
					direction = ent.Velocity,
					position = ent.Position,
					role = "proxy",
					reason = "fetus_late_bind",
				})
				if resolved.attack then
					ent:GetData()[classifier.DATA_PROXY_MARK] = true
				end
				return
			end
		end
		if not is_ludo_tear(ent) then return end
		local player, source_id, source = resolve_ludo_source(ent)
		if not player or not source_id then return end

		-- Craft FireTear often binds as family "tear" before LUDOVICO flags are applied.
		local existing = select(1, registry.GetAttackForMember(ent))
		if existing and existing.family ~= "ludo" then
			registry.UnbindMember(ent, "ludo_reclassify")
			existing = nil
		end

		local delay = math.max(1, (player.MaxFireDelay or 10) * 1.5)
		local st = source_ludo_state(source_id)
		local frame = Game():GetFrameCount()
		local cur = st.attack_id and registry.GetAttack(st.attack_id)
		if cur and (not cur.active or cur.ending) then
			cur = nil
			st.attack_id = nil
		end

		-- One cadence tick per Game frame (not per tear entity).
		if st.last_frame ~= frame then
			st.last_frame = frame
			if not cur then
				cur = begin_ludo_cadence_attack(player, source_id, source, ent, "ludo_open")
				st.attack_id = cur and cur.id or nil
				st.cd = 0
			else
				st.cd = (st.cd or 0) + 1
				if cur.active and not cur.ending then
					dps.feed_rate(cur, ent, 1 / delay, {
						direction = ludo_fire_direction(ent, player),
						reason = "ludo",
					})
				end
				if st.cd >= delay then
					st.cd = 0
					registry.EndAttack(cur, "ludo_rollover")
					local neu = begin_ludo_cadence_attack(
						player,
						source_id,
						cur.source or source,
						ent,
						"ludo_rollover"
					)
					st.attack_id = neu and neu.id or nil
				end
			end
		else
			-- Same frame, another ludo tear: join sealed Attack as additional primary.
			if cur and cur.active and not cur.ending then
				registry.BindMember(cur, ent, {
					direction = ludo_fire_direction(ent, player),
					role = "primary",
					reason = "ludo_same_frame",
					allow_sealed = true,
				})
			end
		end
	end,
})

local function resolve_attack_player(ent)
	return classifier.resolve_owner_player(ent)
end

local function knife_dir(knife)
	local rot = (knife and knife.Rotation) or 0
	return auxi.get_by_rotate(Vector(1, 0), rot)
end

--- Prefer player aim / fire input over knife.Rotation (Rotation can be 0 while facing other dirs).
local function sword_fire_direction(knife, player)
	if player and player.GetAimDirection then
		local ok, aim = pcall(function() return player:GetAimDirection() end)
		if ok and aim and aim:Length() > 0.01 then
			return aim:Normalized()
		end
	end
	if player and player.GetShootingJoystick then
		local ok, joy = pcall(function() return player:GetShootingJoystick() end)
		if ok and joy and joy:Length() > 0.01 then
			return joy:Normalized()
		end
	end
	return knife_dir(knife)
end

--- Bone Club swing/throw bind direction: live aim first.
--- knife_dir(Rotation) alone is often Vector(1,0) even when swinging/throwing left.
local function bone_club_fire_direction(knife, player)
	if player and player.GetAimDirection then
		local ok, aim = pcall(function() return player:GetAimDirection() end)
		if ok and aim and aim:Length() > 0.01 then
			return aim:Normalized()
		end
	end
	if player and player.GetShootingJoystick then
		local ok, joy = pcall(function() return player:GetShootingJoystick() end)
		if ok and joy and joy:Length() > 0.01 then
			return joy:Normalized()
		end
	end
	if player and player.GetShootingInput then
		local ok, input = pcall(function() return player:GetShootingInput() end)
		if ok and input and input:Length() > 0.01 then
			return input:Normalized()
		end
	end
	if knife and knife.Velocity and knife.Velocity:Length() > 0.01 then
		return knife.Velocity:Normalized()
	end
	return knife_dir(knife)
end

local function club_hitbox_subtype()
	if KnifeSubType and KnifeSubType.CLUB_HITBOX then
		return KnifeSubType.CLUB_HITBOX
	end
	return 4
end

local function is_club_hitbox(ent)
	return ent and ent.Type == EntityType.ENTITY_KNIFE and ent.SubType == club_hitbox_subtype()
end

--- Spirit Sword / Tech Sword only (8.10 / 8.11).
local function spirit_sword_variant(v)
	if KnifeVariant then
		if KnifeVariant.SPIRIT_SWORD and v == KnifeVariant.SPIRIT_SWORD then return true end
		if KnifeVariant.TECH_SWORD and v == KnifeVariant.TECH_SWORD then return true end
	end
	return v == 10 or v == 11
end

--- Bone Club family: Bone Club / Bone Scythe / Berserk Club|Donkey Jawbone / Notched Axe (8.1 / 8.2 / 8.3 / 8.9).
local function bone_club_family_variant(v)
	if KnifeVariant then
		if KnifeVariant.BONE_CLUB and v == KnifeVariant.BONE_CLUB then return true end
		if KnifeVariant.BONE_SCYTHE and v == KnifeVariant.BONE_SCYTHE then return true end
		if KnifeVariant.BERSERK_CLUB and v == KnifeVariant.BERSERK_CLUB then return true end
		if KnifeVariant.DONKEY_JAWBONE and v == KnifeVariant.DONKEY_JAWBONE then return true end
		if KnifeVariant.NOTCHED_AXE and v == KnifeVariant.NOTCHED_AXE then return true end
	end
	return v == 1 or v == 2 or v == 3 or v == 9
end

--- Mom's Knife / Sumptorium only (8.0 / 8.5). Never absorb bone_club / spirit_sword / bag / other variants.
local function moms_knife_family_variant(v)
	if KnifeVariant then
		if KnifeVariant.MOMS_KNIFE and v == KnifeVariant.MOMS_KNIFE then return true end
		if KnifeVariant.SUMPTORIUM and v == KnifeVariant.SUMPTORIUM then return true end
	end
	return v == 0 or v == 5
end

-- Swing-capable blades for CLUB_HITBOX parent matching (spirit sword + bone_club family).
local function is_known_swing_variant(v)
	return spirit_sword_variant(v) or bone_club_family_variant(v)
end

--- Bone Club family blade (not CLUB_HITBOX). Instance melee — not Spirit Sword hold Attack.
local function is_bone_club_blade(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_KNIFE then
		return false
	end
	if is_club_hitbox(ent) then
		return false
	end
	return bone_club_family_variant(ent.Variant)
end

local function is_spirit_sword_blade(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_KNIFE then
		return false
	end
	if is_club_hitbox(ent) then
		return false
	end
	return spirit_sword_variant(ent.Variant)
end

local function is_moms_knife_blade(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_KNIFE then
		return false
	end
	if is_club_hitbox(ent) then
		return false
	end
	return moms_knife_family_variant(ent.Variant)
end

local function knife_ownership_snap(ent)
	if not ent then return nil end
	local attack = select(1, registry.GetAttackForMember(ent))
	return {
		entity_ptr = GetPtrHash(ent),
		type = ent.Type,
		variant = ent.Variant,
		subtype = ent.SubType,
		current_attack_id = attack and attack.id or nil,
		current_family = attack and attack.family or nil,
	}
end

local function emit_collector_reject(ent, collector, requested_family, reason, actual_owner)
	registry.EmitAudit("collector_reject", nil, {
		collector = collector,
		requested_family = requested_family,
		actual_owner = actual_owner,
		reason = reason or "owned_by_other_weapon_family",
		reject_reason = reason or "owned_by_other_weapon_family",
		member = ent,
		member_ptr = ent and GetPtrHash(ent) or nil,
		ownership = knife_ownership_snap(ent),
	})
end

local function emit_collector_ownership(ent, collector, requested_family)
	registry.EmitAudit("collector_ownership", nil, {
		collector = collector,
		requested_family = requested_family,
		member = ent,
		member_ptr = ent and GetPtrHash(ent) or nil,
		ownership = knife_ownership_snap(ent),
	})
end

--- Mom's Knife throw only (IsFlying). Only 8.0 / 8.5 — never absorb other Knife variants.
local function can_collect_moms_knife_throw(ent)
	if not is_moms_knife_blade(ent) then return false end
	if M.knife_blacklist[ent.Variant] then return false end
	if should_ignore(ent) then return false end
	-- Belt-and-suspenders: bone_club / spirit_sword own their blades.
	if is_bone_club_blade(ent) then return false end
	if is_spirit_sword_blade(ent) then return false end
	local ctx = fire_context.Peek()
	if ctx and ctx.mode == "inherit" then
		return false
	end
	return true
end

local function block_moms_knife_for_bone_club(ent)
	if not is_bone_club_blade(ent) then return false end
	registry.EmitAudit("moms_knife_block_bone_club", nil, {
		collector = "moms_knife",
		member = ent,
		member_ptr = GetPtrHash(ent),
		variant = ent.Variant,
		reason = "bone_club_owner",
		reject_reason = "bone_club_owner",
		requested_family = "knife",
		actual_owner = "bone_club",
	})
	return true
end

--- Spirit Sword / Tech Sword swing only (no IsFlying launch).
local function can_collect_spirit_sword_swing(ent)
	if not is_spirit_sword_blade(ent) then return false end
	if M.knife_blacklist[ent.Variant] then return false end
	if should_ignore(ent) then return false end
	local ctx = fire_context.Peek()
	if ctx and ctx.mode == "inherit" then
		return false
	end
	return true
end

--- Bone Club family (8.1/8.2/8.3/8.9): swing + throw instance (not Mom's Knife / Spirit Sword).
local function can_collect_bone_club_action(ent)
	if not is_bone_club_blade(ent) then return false end
	if M.knife_blacklist[ent.Variant] then return false end
	if should_ignore(ent) then return false end
	local ctx = fire_context.Peek()
	if ctx and ctx.mode == "inherit" then
		return false
	end
	return true
end

-- LEGACY-API: thin OR of spirit sword + moms knife collectors.
-- Bone Club has its own owner (POST_FIRE_BONE_CLUB + tick_bone_club_*); never enter here.
local function can_auto_collect_knife_action(ent)
	if is_bone_club_blade(ent) then
		registry.EmitAudit("bone_club_generic_knife_block", nil, {
			collector = "generic_knife",
			member = ent,
			member_ptr = GetPtrHash(ent),
			variant = ent.Variant,
			rejected = true,
			reason = "bone_club_owned",
			reject_reason = "bone_club_owned",
			caller = "can_auto_collect_knife_action",
		})
		return false
	end
	return can_collect_spirit_sword_swing(ent)
		or can_collect_moms_knife_throw(ent)
end

local function bone_club_audit(event_name, knife, extras)
	extras = extras or {}
	extras.collector = extras.collector or "bone_club"
	extras.member = extras.member or knife
	if knife then
		extras.member_ptr = extras.member_ptr or GetPtrHash(knife)
		extras.variant = extras.variant or knife.Variant
	end
	registry.EmitAudit(event_name, extras.attack, extras)
end

-- Legacy alias name used in older notes; prefer is_known_swing_variant.
local swing_melee_variant = is_known_swing_variant

local function hitbox_parent_knife(ent)
	if not ent then return nil end
	if ent.GetHitboxParentKnife then
		local ok, parent = pcall(function() return ent:GetHitboxParentKnife() end)
		if ok and parent then return parent end
	end
	local p = ent.Parent
	if p and p.Type == EntityType.ENTITY_KNIFE then return p end
	return nil
end

local function set_hitbox_parent_knife(hitbox, parent)
	if not hitbox or not parent then return end
	if hitbox.SetHitboxParentKnife then
		pcall(function() hitbox:SetHitboxParentKnife(parent) end)
	end
end

--- Same-player swing blade (SubType≠CLUB_HITBOX) that already owns / can own a melee Attack.
local function find_player_sword_blade(hitbox, player)
	if not hitbox or not player then return nil end
	local ph = GetPtrHash(player)
	local knives = Isaac.FindByType(EntityType.ENTITY_KNIFE, -1, -1, false, false)
	local best, best_score = nil, -1
	for i = 1, #knives do
		local k = knives[i]
		if k and not is_club_hitbox(k) and (
			is_known_swing_variant(k.Variant)
			or can_collect_spirit_sword_swing(k)
			or can_collect_bone_club_action(k)
		) then
			local kp = resolve_attack_player(k)
			if kp and GetPtrHash(kp) == ph then
				local attack = select(1, registry.GetAttackForMember(k))
				local score = 0
				local want_bone = bone_club_family_variant(hitbox.Variant)
				if attack and attack.active and not attack.ending
					and (attack.family == "sword" or attack.family == "bone_club") then
					score = score + 100
					if is_bone_club_blade(k) == want_bone then
						score = score + 20
					end
				end
				-- Prefer known Spirit/Bone blades when scores tie.
				if is_known_swing_variant(k.Variant) then
					score = score + 10
				end
				local age = math.abs((k.FrameCount or 0) - (hitbox.FrameCount or 0))
				score = score + math.max(0, 8 - age)
				if score > best_score then
					best_score = score
					best = k
				end
			end
		end
	end
	return best
end

local function remember_sword_player_blast(player, attack, member)
	if not player or not attack then return end
	local binding = member and registry.bindings[GetPtrHash(member)] or nil
	local gen = (binding and binding.generation)
		or (attack.bound_members[attack.primary_hash] and attack.bound_members[attack.primary_hash].generation)
		or 1
	-- Spirit Sword capsule hits attribute TAKE_DMG to the player, not KNIFE_COLLISION.
	registry.remember_player_blast(player, attack, gen, (member and member.Position) or player.Position)
end

local function sword_anim_kind(anim)
	if not anim or anim == "" then return "other" end
	if string.sub(anim, 1, 4) == "Idle" then return "idle" end
	if string.sub(anim, 1, 4) == "Spin" then return "spin" end
	if string.sub(anim, 1, 6) == "Attack" or string.sub(anim, 1, 5) == "Swing" then
		return "swing"
	end
	return "other"
end

local function end_sword_attack(attack, reason)
	if not attack or not attack.active or attack.ending then return end
	if attack.family ~= "sword" then return end
	for _, rec in pairs(attack.bound_members) do
		if rec and rec.entity then
			registry.remember_for_damage(rec.entity, attack, rec.generation)
		end
	end
	local player = attack.player
	local aid = attack.id
	registry.EndAttack(attack, reason or "sword_end")
	if player then
		registry.clear_player_blast_for_attack(player, aid)
	end
end

local function end_bone_club_attack(attack, reason)
	if not attack or not attack.active or attack.ending then return end
	if attack.family ~= "bone_club" then return end
	for _, rec in pairs(attack.bound_members) do
		if rec and rec.entity then
			registry.remember_for_damage(rec.entity, attack, rec.generation)
		end
	end
	local player = attack.player
	local aid = attack.id
	local end_reason = reason or "bone_club_end"
	bone_club_audit("bone_club_attack_end", nil, {
		attack_id = aid,
		reason = end_reason,
		family = "bone_club",
		source_id = attack.source_id,
		frame = Game():GetFrameCount(),
	})
	-- Attack Registry End ≠ cohort close; drop grouping row before EndAttack.
	grouping.close_attack_cohort(attack)
	registry.EndAttack(attack, end_reason)
	if player then
		registry.clear_player_blast_for_attack(player, aid)
	end
end

--- Unbind knife/hitbox only. Full-health SWORD_BEAM tears stay on the Attack until they despawn.
--- reason sword_melee_hold: keep empty sealed Attack briefly so same-swing beams can still Bind.
local function detach_sword_melee_members(attack, reason)
	if not attack or not attack.active or attack.ending then return end
	if attack.family ~= "sword" then return end
	local to_unbind = {}
	for _, rec in pairs(attack.bound_members) do
		local e = rec and rec.entity
		if e and e.Type == EntityType.ENTITY_KNIFE then
			to_unbind[#to_unbind + 1] = e
		end
	end
	local hold = reason or "sword_melee_hold"
	for i = 1, #to_unbind do
		local e = to_unbind[i]
		local binding = registry.bindings[GetPtrHash(e)]
		if binding then
			registry.remember_for_damage(e, attack, binding.generation)
		end
		registry.UnbindMember(e, hold)
	end
	local player = attack.player
	if player then
		registry.clear_player_blast_for_attack(player, attack.id)
	end
	if (attack.bound_count or 0) <= 0 then
		attack.sword_beam_hold_frame = Game():GetFrameCount()
	end
end

--- Persistent Spirit Sword blade leaves melee members before a new Once; beams keep the old Attack.
local function end_bound_sword_attack(ent, reason)
	if not ent then return end
	local binding = registry.bindings[GetPtrHash(ent)]
	if not binding then return end
	local attack = registry.GetAttack(binding.attack_id)
	detach_sword_melee_members(attack, reason or "sword_melee_hold")
end

--- Bone Club instance: Idle / replace ends the whole Attack (no sword-beam hold).
local function end_bound_bone_club_attack(ent, reason)
	if not ent then return end
	local binding = registry.bindings[GetPtrHash(ent)]
	if not binding then return end
	local attack = registry.GetAttack(binding.attack_id)
	if not attack or attack.family ~= "bone_club" then return end
	end_bone_club_attack(attack, reason or "bone_club_idle")
end

local function find_player_sword_attack(player)
	if not player then return nil end
	local open = grouping.get_open(player, "sword")
	if open and open.active and not open.ending then
		return open
	end
	local ph = GetPtrHash(player)
	local best, best_id = nil, -1
	local knives = Isaac.FindByType(EntityType.ENTITY_KNIFE, -1, -1, false, false)
	for i = 1, #knives do
		local k = knives[i]
		if k and not is_club_hitbox(k) then
			local kp = resolve_attack_player(k)
			if kp and GetPtrHash(kp) == ph then
				local attack = select(1, registry.GetAttackForMember(k))
				if attack and attack.family == "sword" and attack.active and not attack.ending then
					if attack.id > best_id then
						best_id = attack.id
						best = attack
					end
				end
			end
		end
	end
	-- After Idle melee detach, Attack may be empty but held for beams.
	if not best then
		for _, attack in pairs(registry.attacks) do
			if attack and attack.active and not attack.ending
				and attack.family == "sword"
				and attack.player and GetPtrHash(attack.player) == ph
				and attack.id > best_id then
				best_id = attack.id
				best = attack
			end
		end
	end
	return best
end

function M.try_bind_sword_beam_tear(ent, player)
	if not ent or not player then return false end
	local attack = find_player_sword_attack(player)
	if not attack then return false end
	local ok = registry.BindMember(attack, ent, {
		allow_sealed = true,
		reason = "sword_beam",
		direction = ent.Velocity,
		position = ent.Position,
	})
	if ok then
		attack.sword_beam_hold_frame = nil
	end
	return ok == true
end

--- Empty sword Attacks held for beams expire if nothing joins.
local function tick_sword_beam_holds()
	local frame = Game():GetFrameCount()
	for _, attack in pairs(registry.attacks) do
		if attack and attack.active and not attack.ending
			and attack.family == "sword"
			and (attack.bound_count or 0) <= 0
			and attack.sword_beam_hold_frame
			and (frame - attack.sword_beam_hold_frame) >= 3 then
			end_sword_attack(attack, "sword_beam_hold_expired")
		end
	end
end

local function bind_club_hitbox_to_attack(attack, hitbox, parent, reason)
	if not attack or not hitbox then return false end
	local hash = GetPtrHash(hitbox)
	local existing = registry.bindings[hash]
	if existing and existing.attack_id ~= attack.id then
		registry.UnbindMember(hitbox, "sword_rebind")
	end
	if parent then
		set_hitbox_parent_knife(hitbox, parent)
	end
	local ok = registry.BindMember(attack, hitbox, {
		allow_sealed = true,
		reason = reason or "club_hitbox",
		direction = knife_dir(parent or hitbox),
	})
	if ok then
		remember_sword_player_blast(attack.player or resolve_attack_player(hitbox), attack, hitbox)
	end
	return ok
end

--- Collect CLUB_HITBOX for this swing (GetHitboxParentKnife is often nil at spawn).
local function collect_swing_hitboxes(blade, player)
	local out = {}
	if not blade then return out end
	local bh = GetPtrHash(blade)
	local ph = player and GetPtrHash(player) or nil
	local knives = Isaac.FindByType(EntityType.ENTITY_KNIFE, -1, -1, false, false)
	for i = 1, #knives do
		local other = knives[i]
		if is_club_hitbox(other) then
			local oh = GetPtrHash(other)
			-- Allow rebinding hitboxes still stuck on a previous sealed swing.
			local parent = hitbox_parent_knife(other)
			local owned = parent and GetPtrHash(parent) == bh
			if not owned and ph then
				local op = resolve_attack_player(other) or (parent and resolve_attack_player(parent))
				if op and GetPtrHash(op) == ph
					and is_known_swing_variant(other.Variant)
					and (other.FrameCount or 0) <= 2 then
					owned = true
				end
			end
			if owned then
				out[#out + 1] = other
			end
		end
	end
	return out
end

--- Custom / StabberKnife spawned under inherit Fire Context (wq combo via Isaac.Spawn).
--- Mom's Knife path uses IsFlying; these never fly, so Bind must happen on INIT.
local function try_bind_knife_under_fire_context(ent)
	if not ent or should_ignore(ent) then return end
	if M.knife_blacklist[ent.Variant] then return end
	if is_club_hitbox(ent) then return end
	local ctx = fire_context.Peek()
	if not ctx or ctx.mode ~= "inherit" then return end
	local parent = resolve_ctx_attack(ctx)
	if not parent then return end
	local hash = GetPtrHash(ent)
	if registry.bindings[hash] then
		registry.GetAttackForMember(ent)
		return
	end
	registry.BindMember(parent, ent, {
		role = ctx.role or "primary",
		reason = ctx.reason or "knife_spawn_inherit",
		direction = knife_dir(ent),
		position = ent.Position,
	})
end

--- Spirit Sword / Bone Club hitbox: join the parent's swing Attack only — never open a second Once.
local function try_bind_club_hitbox(ent)
	if should_ignore(ent) or not is_club_hitbox(ent) then return end
	local hash = GetPtrHash(ent)
	local parent = hitbox_parent_knife(ent)
	-- C Section fetus-held clubs: Parent/Spawner may be the fetus tear (proxy Attack).
	local resolved = classifier.ResolveCandidate(ent, "sword", {
		allow_create = true,
		allow_mimic_create = true,
		from_fire_callback = true,
	})
	if resolved.mode == "inherit" and resolved.parent_attack then
		local existing = registry.bindings[hash]
		if existing and existing.attack_id == resolved.parent_attack.id then
			registry.GetAttackForMember(ent)
			return
		end
		bind_club_hitbox_to_attack(resolved.parent_attack, ent, parent or resolved.via, "club_hitbox_proxy")
		return
	end

	local player = resolve_attack_player(ent)
		or (parent and resolve_attack_player(parent))
		or resolved.owner_player
	if not parent and player then
		parent = find_player_sword_blade(ent, player)
	end
	if not player then
		player = parent and resolve_attack_player(parent)
	end
	if not player then return end

	local attack = parent and select(1, registry.GetAttackForMember(parent)) or nil
	if not attack then
		local sid = resolved.source_id or classifier.player_source_id(player)
		local family = (parent and is_bone_club_blade(parent)) and "bone_club" or "sword"
		-- No cross-family fallback: Bone Club hitboxes must not join Spirit Sword Attacks.
		attack = grouping.get_open(sid, family) or grouping.get_open(player, family)
	end
	-- Hitbox must never create_or_join alone (that double-fires POST_ATTACK_ONCE per swing).
	if not attack then return end
	-- Already on this Attack: refresh wrapper only.
	local existing = registry.bindings[hash]
	if existing and existing.attack_id == attack.id then
		registry.GetAttackForMember(ent)
		return
	end
	bind_club_hitbox_to_attack(attack, ent, parent, "club_hitbox")
end

local function begin_sword_attack(knife, reason)
	if should_ignore(knife) then return nil end
	local resolved = classifier.ResolveCandidate(knife, "sword", {
		from_fire_callback = true,
		allow_create = true,
		allow_mimic_create = true,
	})
	if resolved.mode == "ignore" then return nil end
	if resolved.mode == "inherit" then
		-- Fetus-held Spirit Sword / Forgotten club: stay on the fetus Attack (no new Once).
		local fire_dir = sword_fire_direction(knife, resolved.owner_player or (resolved.parent_attack and resolved.parent_attack.player))
		registry.BindMember(resolved.parent_attack, knife, {
			allow_sealed = true,
			role = "derived",
			direction = fire_dir,
			reason = reason or "fire_sword_inherit",
		})
		remember_sword_player_blast(
			resolved.owner_player or resolved.parent_attack.player,
			resolved.parent_attack,
			knife
		)
		return resolved.parent_attack
	end
	local player = resolved.owner_player
	if not player then return nil end
	-- Detach melee from prior Attack (beams keep that Attack). Drop empty beam-holds.
	end_bound_sword_attack(knife, "sword_melee_hold")
	local sid = resolved.source_id or classifier.player_source_id(player)
	for _, prev in pairs(registry.attacks) do
		if prev and prev.active and not prev.ending
			and prev.family == "sword"
			and prev.source_id == sid
			and (prev.bound_count or 0) <= 0 then
			end_sword_attack(prev, "sword_new_swing_clear_hold")
		end
	end
	local fire_dir = sword_fire_direction(knife, player)
	emit_collector_ownership(knife, "spirit_sword", "sword")
	local attack = grouping.create_or_join(player, "sword", {
		max_frame_delta = 0,
		direction = fire_dir,
		position = knife.Position,
		source_id = sid,
		source = resolved.source,
		reason = reason or "fire_sword",
		collector = "spirit_sword",
	})
	registry.BindMember(attack, knife, {
		direction = fire_dir,
		reason = reason or "fire_sword",
		role = "primary",
	})
	remember_sword_player_blast(player, attack, knife)
	local hitboxes = collect_swing_hitboxes(knife, player)
	for i = 1, #hitboxes do
		bind_club_hitbox_to_attack(attack, hitboxes[i], knife, "club_hitbox")
	end
	if attack.open_for_members then
		grouping.seal_attack_and_clear(attack)
	end
	return attack
end

--- Bone Club / Berserk: one swing entity = one Attack instance (not Spirit Sword hold+append).
--- force_new_instance: never inherit/reuse a parent Attack for a new swing.
local function begin_bone_club_attack(knife, reason)
	if should_ignore(knife) then return nil end
	bone_club_audit("bone_club_begin", knife, {
		reason = reason or "fire_bone_club",
		frame = Game():GetFrameCount(),
	})
	local resolved = classifier.ResolveCandidate(knife, "bone_club", {
		from_fire_callback = true,
		allow_create = true,
		allow_mimic_create = true,
		force_new_instance = true,
	})
	local existing_attack = resolved.previous_attack
		or resolved.parent_attack
		or select(1, registry.GetAttackForMember(knife))
	bone_club_audit("bone_club_resolve", knife, {
		reason = reason or "fire_bone_club",
		resolve_mode = resolved.mode,
		existing_attack_id = existing_attack and existing_attack.id or nil,
		existing_family = existing_attack and existing_attack.family or nil,
		owner_ptr = resolved.owner_player and GetPtrHash(resolved.owner_player) or nil,
		frame = Game():GetFrameCount(),
	})
	if resolved.mode == "ignore" then return nil end
	-- Bone Club swing is never a derived hold (Spirit Sword / fetus inherit model).
	-- Even if classifier returned inherit historically, force a new instance below.
	local player = resolved.owner_player or resolve_attack_player(knife)
	if not player then return nil end
	local sid = resolved.source_id or classifier.player_source_id(player)
	-- Close any prior instance for this source before opening a new swing Once.
	for _, prev in pairs(registry.attacks) do
		if prev and prev.active and not prev.ending
			and prev.family == "bone_club"
			and prev.source_id == sid then
			end_bone_club_attack(prev, "swing_finished")
		end
	end
	-- Ensure this blade is free before BindMember (force_new may have left a stale binding).
	local hash = GetPtrHash(knife)
	if registry.bindings[hash] then
		registry.UnbindMember(knife, "bone_club_force_new")
	end
	local fire_dir = bone_club_fire_direction(knife, player)
	emit_collector_ownership(knife, "bone_club", "bone_club")
	local attack, is_new = grouping.create_or_join(player, "bone_club", {
		max_frame_delta = 0,
		direction = fire_dir,
		position = knife.Position,
		source_id = sid,
		source = resolved.source,
		reason = reason or "fire_bone_club",
		collector = "bone_club",
	})
	bone_club_audit("bone_club_attack_created", knife, {
		attack = attack,
		attack_id = attack and attack.id or nil,
		reason = reason or "fire_bone_club",
		created = attack ~= nil,
		inherited = false,
		is_new = is_new == true,
		cohort_reused = is_new ~= true,
		cohort_key = tostring(sid) .. "|bone_club",
		attack_active = attack and attack.active == true or false,
		attack_open_for_members = attack and attack.open_for_members == true or false,
		frame = Game():GetFrameCount(),
	})
	registry.BindMember(attack, knife, {
		direction = fire_dir,
		reason = reason or "fire_bone_club",
		role = "primary",
	})
	remember_sword_player_blast(player, attack, knife)
	local hitboxes = collect_swing_hitboxes(knife, player)
	for i = 1, #hitboxes do
		bind_club_hitbox_to_attack(attack, hitboxes[i], knife, "club_hitbox")
	end
	if attack.open_for_members then
		grouping.seal_attack_and_clear(attack)
	end
	local st = M.bone_club_state[hash] or {}
	st.active_attack_id = attack and attack.id or nil
	M.bone_club_state[hash] = st
	return attack
end

--- Bone Club throw: new instance Attack (not Mom's Knife IsFlying cohort).
local function begin_bone_club_throw_attack(knife, reason)
	if should_ignore(knife) or not is_bone_club_blade(knife) then return nil end
	local resolved = classifier.ResolveCandidate(knife, "bone_club", {
		from_fire_callback = true,
		allow_create = true,
		allow_mimic_create = true,
		force_new_instance = true,
	})
	if resolved.mode == "ignore" then return nil end
	local player = resolved.owner_player or resolve_attack_player(knife)
	if not player then return nil end
	local sid = resolved.source_id or classifier.player_source_id(player)
	-- Close prior bone_club swing/throw for this source before opening throw Once.
	for _, prev in pairs(registry.attacks) do
		if prev and prev.active and not prev.ending
			and prev.family == "bone_club"
			and prev.source_id == sid then
			end_bone_club_attack(prev, "throw_transition")
		end
	end
	local hash = GetPtrHash(knife)
	if registry.bindings[hash] then
		registry.UnbindMember(knife, "bone_club_force_new")
	end
	local fire_dir = bone_club_fire_direction(knife, player)
	emit_collector_ownership(knife, "bone_club", "bone_club")
	local attack, is_new = grouping.create_or_join(player, "bone_club", {
		max_frame_delta = 0,
		direction = fire_dir,
		position = knife.Position,
		source_id = sid,
		source = resolved.source,
		reason = reason or "bone_club_throw",
		collector = "bone_club",
	})
	bone_club_audit("bone_club_attack_created", knife, {
		attack = attack,
		attack_id = attack and attack.id or nil,
		reason = reason or "bone_club_throw",
		created = attack ~= nil,
		inherited = false,
		is_new = is_new == true,
		cohort_reused = is_new ~= true,
		cohort_key = tostring(sid) .. "|bone_club",
		attack_active = attack and attack.active == true or false,
		attack_open_for_members = attack and attack.open_for_members == true or false,
		frame = Game():GetFrameCount(),
	})
	registry.BindMember(attack, knife, {
		direction = fire_dir,
		reason = reason or "bone_club_throw",
		role = "projectile",
	})
	remember_sword_player_blast(player, attack, knife)
	if attack.open_for_members then
		grouping.seal_attack_and_clear(attack)
	end
	local st = M.bone_club_state[hash] or {}
	st.active_attack_id = attack and attack.id or nil
	st.flying = true
	M.bone_club_state[hash] = st
	return attack
end

local function on_post_fire_sword(knife)
	begin_sword_attack(knife, "fire_sword")
end

--- Spirit Sword swing tick: Idle detaches melee (beam hold); Attack*/Swing*/Spin* opens sword Once.
local function tick_spirit_sword_swing(ent, player)
	if not ent or not player or is_club_hitbox(ent) then return end
	if not can_collect_spirit_sword_swing(ent) then return end
	local hash = GetPtrHash(ent)
	local st = M.knife_state[hash] or { flying = false }
	M.knife_state[hash] = st
	local spr = ent:GetSprite()
	local anim = spr and spr:GetAnimation() or nil
	local kind = sword_anim_kind(anim)
	local prev = st.sword_anim_kind
	st.sword_anim_kind = kind

	if kind == "idle" then
		local cur = select(1, registry.GetAttackForMember(ent))
		if cur and cur.family ~= "sword" then
			return
		end
		end_bound_sword_attack(ent, "sword_melee_hold")
		return
	end

	local frame = Game():GetFrameCount()
	if (kind == "swing" or kind == "spin") and prev ~= kind then
		local cur = select(1, registry.GetAttackForMember(ent))
		if not (cur and cur.family == "sword" and cur.created_frame == frame) then
			begin_sword_attack(ent, kind == "spin" and "sword_spin" or "sword_swing")
		end
		return
	end

	if kind == "swing" or kind == "spin" then
		local attack, binding = registry.GetAttackForMember(ent)
		if attack and binding and attack.family == "sword" then
			remember_sword_player_blast(player, attack, ent)
			registry.remember_for_damage(ent, attack, binding.generation)
		end
	end
end

--- Bone Club swing tick (throw is handled separately on IsFlying rising edge).
--- Instance owner: new swing = anim_name_changed or sprite frame_reset (not Spirit Sword kind edge).
--- State lives in M.bone_club_state — never share Mom's Knife M.knife_state.flying.
local function tick_bone_club_swing(ent, player)
	if not ent or not player or is_club_hitbox(ent) then return end
	if not can_collect_bone_club_action(ent) then return end
	local hash = GetPtrHash(ent)
	local st = M.bone_club_state[hash] or { flying = false }
	M.bone_club_state[hash] = st
	-- While thrown, swing anim edges must not reopen a swing Attack.
	if st.flying or (ent.IsFlying and ent:IsFlying()) then
		return
	end
	local spr = ent:GetSprite()
	local anim = spr and spr:GetAnimation() or nil
	local sprite_frame = spr and spr:GetFrame() or -1
	local kind = sword_anim_kind(anim)
	local prev = st.bone_kind
	local prev_anim = st.bone_anim_name
	local prev_sprite_frame = st.bone_sprite_frame
	local cur_attack = select(1, registry.GetAttackForMember(ent))
	local anim_name_changed = anim ~= prev_anim
	local kind_changed = kind ~= prev
	local frame_reset = (prev_sprite_frame or -1) >= 0 and sprite_frame >= 0
		and sprite_frame < prev_sprite_frame
	local anim_changed = anim_name_changed or kind_changed or frame_reset
	if anim_changed then
		bone_club_audit("bone_club_anim", ent, {
			animation = anim,
			kind = kind,
			previous_kind = prev,
			previous_animation = prev_anim,
			sprite_frame = sprite_frame,
			previous_sprite_frame = prev_sprite_frame,
			frame_reset = frame_reset,
			attack_id = cur_attack and cur_attack.id or nil,
			is_bone = true,
			frame = Game():GetFrameCount(),
		})
	end
	st.bone_kind = kind
	st.bone_anim_name = anim
	st.bone_sprite_frame = sprite_frame

	if kind == "idle" then
		if cur_attack and cur_attack.family ~= "bone_club" then
			return
		end
		if cur_attack then
			end_bone_club_attack(cur_attack, "swing_finished")
		else
			end_bound_bone_club_attack(ent, "swing_finished")
		end
		st.active_attack_id = nil
		return
	end

	local frame = Game():GetFrameCount()
	if kind == "swing" or kind == "spin" then
		local new_swing = false
		if prev_anim == nil and (kind == "swing" or kind == "spin") then
			new_swing = true
		elseif anim_name_changed or frame_reset then
			new_swing = true
		elseif kind_changed and (prev == "idle" or prev == "other" or prev == nil) then
			new_swing = true
		end
		local same_frame_dup = cur_attack
			and cur_attack.family == "bone_club"
			and cur_attack.created_frame == frame
		if new_swing or anim_name_changed or frame_reset or kind_changed then
			bone_club_audit("bone_club_swing_edge", ent, {
				animation = anim,
				kind = kind,
				previous_kind = prev,
				previous_animation = prev_anim,
				sprite_frame = sprite_frame,
				triggered = new_swing,
				anim_name_changed = anim_name_changed,
				frame_reset = frame_reset,
				same_frame_dup = same_frame_dup == true,
				will_begin = new_swing and not same_frame_dup,
				attack_id = cur_attack and cur_attack.id or nil,
				frame = frame,
			})
		end
		if new_swing and not same_frame_dup then
			if cur_attack and cur_attack.family == "bone_club" then
				end_bone_club_attack(cur_attack, "swing_finished")
			end
			local attack = begin_bone_club_attack(
				ent,
				kind == "spin" and "bone_club_spin" or "bone_club_swing"
			)
			st.active_attack_id = attack and attack.id or nil
			st.swing_generation = (st.swing_generation or 0) + 1
			return
		end
	end

	if kind == "swing" or kind == "spin" then
		local attack, binding = registry.GetAttackForMember(ent)
		if attack and binding and attack.family == "bone_club" then
			remember_sword_player_blast(player, attack, ent)
			registry.remember_for_damage(ent, attack, binding.generation)
			st.active_attack_id = attack.id
		end
	end
end

--- Bone Club throw tick: IsFlying rising → throw Attack; return → end.
local function tick_bone_club_throw(ent, player)
	if not ent or not player or not can_collect_bone_club_action(ent) then return end
	local hash = GetPtrHash(ent)
	local st = M.bone_club_state[hash] or { flying = false }
	M.bone_club_state[hash] = st
	local flying = ent.IsFlying and ent:IsFlying()
	if flying then
		if not st.flying then
			st.flying = true
			local cur = select(1, registry.GetAttackForMember(ent))
			if cur and cur.family == "bone_club" then
				end_bone_club_attack(cur, "throw_transition")
			elseif registry.bindings[hash] then
				registry.UnbindMember(ent, "bone_club_throw_rebind")
			end
			local attack = begin_bone_club_throw_attack(ent, "bone_club_throw")
			st.active_attack_id = attack and attack.id or nil
		else
			local attack, binding = registry.GetAttackForMember(ent)
			if attack and binding and attack.family == "bone_club" then
				remember_sword_player_blast(player, attack, ent)
				registry.remember_for_damage(ent, attack, binding.generation)
			elseif not registry.bindings[hash] then
				begin_bone_club_throw_attack(ent, "bone_club_throw_rejoin")
			end
		end
	elseif st.flying then
		st.flying = false
		local attack = select(1, registry.GetAttackForMember(ent))
		if attack and attack.family == "bone_club" then
			end_bone_club_attack(attack, "swing_finished")
			st.active_attack_id = nil
		elseif registry.bindings[hash] then
			registry.UnbindMember(ent, "weapon_return")
		end
	end
end

local function tick_bone_club_action(ent, player)
	tick_bone_club_throw(ent, player)
	tick_bone_club_swing(ent, player)
end

local tick_spirit_sword_blade = tick_spirit_sword_swing

local function knife_source_bundle(ent)
	local resolved = classifier.ResolveCandidate(ent, "knife", {
		allow_create = true,
		allow_mimic_create = true,
		from_fire_callback = true,
	})
	return resolved
end

local function bind_all_flying_knives(seed_ent)
	if block_moms_knife_for_bone_club(seed_ent) then
		return nil
	end
	if is_spirit_sword_blade(seed_ent) then
		emit_collector_reject(seed_ent, "moms_knife", "knife", "owned_by_spirit_sword", "spirit_sword")
		return nil
	end
	if not can_collect_moms_knife_throw(seed_ent) then
		if seed_ent and seed_ent.Type == EntityType.ENTITY_KNIFE then
			emit_collector_reject(seed_ent, "moms_knife", "knife", "not_moms_knife_variant", "none")
		end
		return nil
	end
	local resolved = knife_source_bundle(seed_ent)
	if resolved.mode == "ignore" or resolved.mode == "already" then
		return resolved.parent_attack or select(1, registry.GetAttackForMember(seed_ent))
	end
	if resolved.mode == "inherit" then
		registry.BindMember(resolved.parent_attack, seed_ent, {
			allow_sealed = true,
			role = "derived",
			direction = knife_dir(seed_ent),
			reason = "knife_isflying_inherit",
		})
		return resolved.parent_attack
	end
	if resolved.mode ~= "player" and resolved.mode ~= "mimic" then
		return nil
	end
	local player = resolved.owner_player
	if not player then return nil end
	emit_collector_ownership(seed_ent, "moms_knife", "knife")
	local attack = grouping.create_or_join(player, "knife", {
		max_frame_delta = 2,
		direction = seed_ent and knife_dir(seed_ent) or nil,
		position = seed_ent and seed_ent.Position or nil,
		source_id = resolved.source_id,
		source = resolved.source,
		reason = "knife_isflying",
		collector = "moms_knife",
	})
	local knives = Isaac.FindByType(EntityType.ENTITY_KNIFE, -1, -1, false, false)
	for i = 1, #knives do
		local knife = knives[i]
		-- Bone Club / Spirit Sword are other owners — never join Mom's Knife throw cohort.
		if not should_ignore(knife) and M.knife_blacklist[knife.Variant] ~= true
			and can_collect_moms_knife_throw(knife)
			and knife.IsFlying and knife:IsFlying() then
			local kr = classifier.ResolveCandidate(knife, "knife", {
				allow_create = true,
				allow_mimic_create = true,
			})
			if kr.mode == "ignore" then
				-- skip familiar knives
			elseif kr.mode == "inherit" and kr.parent_attack and kr.parent_attack.id == attack.id then
				local kh = GetPtrHash(knife)
				if not registry.bindings[kh] then
					registry.BindMember(attack, knife, {
						direction = knife_dir(knife),
						role = "derived",
						reason = "knife_isflying_inherit",
					})
				end
			elseif (kr.mode == "player" or kr.mode == "mimic")
				and kr.source_id == resolved.source_id then
				local kh = GetPtrHash(knife)
				local binding = registry.bindings[kh]
				if binding and binding.attack_id ~= attack.id then
					registry.UnbindMember(knife, "rebind")
					binding = nil
				end
				if not binding then
					registry.BindMember(attack, knife, {
						direction = knife_dir(knife),
						role = "primary",
						reason = "knife_isflying",
					})
				end
				local st = M.knife_state[kh] or { flying = false }
				st.flying = true
				M.knife_state[kh] = st
			end
		end
	end
	return attack
end

--- Mom's Knife IsFlying rising / join path (never Bone Club / Spirit Sword).
local function tick_moms_knife_throw(ent)
	if block_moms_knife_for_bone_club(ent) then return end
	if not can_collect_moms_knife_throw(ent) then return end
	local hash = GetPtrHash(ent)
	local st = M.knife_state[hash] or { flying = false }
	M.knife_state[hash] = st
	if not (ent.IsFlying and ent:IsFlying()) then
		if st.flying then
			st.flying = false
			if registry.bindings[hash] then
				registry.UnbindMember(ent, "weapon_return")
			end
		end
		return
	end
	local resolved = knife_source_bundle(ent)
	if resolved.mode == "ignore" then return end
	local player = resolved.owner_player or resolve_attack_player(ent)
	if not player then return end
	if not st.flying then
		st.flying = true
		if registry.bindings[hash] then
			registry.UnbindMember(ent, "rebind")
		end
		bind_all_flying_knives(ent)
	else
		local sid = resolved.source_id
			or (resolved.parent_attack and resolved.parent_attack.source_id)
			or classifier.player_source_id(player)
		local attack = grouping.get_open(sid, "knife")
		if attack and attack.open_for_members and not registry.bindings[hash] then
			registry.BindMember(attack, ent, {
				direction = knife_dir(ent),
				role = "primary",
				reason = "knife_isflying_join",
			})
		elseif not registry.bindings[hash] then
			bind_all_flying_knives(ent)
		end
	end
end

-- Knife: multi-knife volleys share one Attack.
-- Secondary knives often Parent→primary knife; must resolve player recursively and sweep-bind.
-- Spirit Sword / Bone Club swings: POST_FIRE_SWORD (+ POST_FIRE_BONE_CLUB) + CLUB_HITBOX bind (not IsFlying).
if ModCallbacks.MC_POST_FIRE_SWORD then
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_FIRE_SWORD,
	params = nil,
	Function = function(_, knife)
		on_post_fire_sword(knife)
	end,
})
end

if ModCallbacks.MC_POST_FIRE_BONE_CLUB then
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_FIRE_BONE_CLUB,
	params = nil,
	Function = function(_, knife)
		-- Spawn-only per RGON docs; swing edges still come from anim tick.
		-- Instance Attack — do not reuse Spirit Sword hold/append model.
		begin_bone_club_attack(knife, "fire_bone_club")
	end,
})
end

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_KNIFE_INIT,
	params = nil,
	Function = function(_, ent)
		try_bind_club_hitbox(ent)
		-- Qing StabberKnife / custom knives: Isaac.Spawn under inherit Fire Context
		-- (wq combo). They never use Mom IsFlying, so bind here or Attack dies empty.
		try_bind_knife_under_fire_context(ent)
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE,
	params = nil,
	Function = function(_, ent)
		if should_ignore(ent) then return end
		if M.knife_blacklist[ent.Variant] then return end

		-- Melee swing hitbox (Spirit Sword / Bone Club / etc.).
		if is_club_hitbox(ent) then
			local spr = ent:GetSprite()
			local kind = sword_anim_kind(spr and spr:GetAnimation() or nil)
			if kind == "idle" then
				local attack = select(1, registry.GetAttackForMember(ent))
				if attack and attack.family == "bone_club" then
					end_bound_bone_club_attack(ent, "bone_club_hitbox_idle")
				else
					end_bound_sword_attack(ent, "sword_hitbox_idle")
				end
				return
			end
			try_bind_club_hitbox(ent)
			if kind == "swing" or kind == "spin" then
				local attack, binding = registry.GetAttackForMember(ent)
				if attack and binding and (attack.family == "sword" or attack.family == "bone_club") then
					remember_sword_player_blast(attack.player or resolve_attack_player(ent), attack, ent)
					registry.remember_for_damage(ent, attack, binding.generation)
				end
			end
			return
		end

		-- Three separate owners — do not share one knife action collector.
		if is_bone_club_blade(ent) then
			local player = resolve_attack_player(ent)
			if not player then return end
			-- Do not early-out on ResolveCandidate ignore: throw/swing owners live inside ticks.
			tick_bone_club_action(ent, player)
			return
		end

		if is_spirit_sword_blade(ent) then
			local player = resolve_attack_player(ent)
			if not player then return end
			local resolved = classifier.ResolveCandidate(ent, "sword", {
				allow_create = true,
				allow_mimic_create = true,
				from_fire_callback = true,
			})
			if resolved.mode == "ignore" then return end
			tick_spirit_sword_swing(ent, player)
			return
		end

		-- Mom's Knife / ordinary throw knives: IsFlying only.
		tick_moms_knife_throw(ent)
	end,
})

-- Dr. Fetus bombs: multi-shot cohort; bind early; remember attack across explode/remove for damage.
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_BOMB_UPDATE,
	params = nil,
	Function = function(_, ent)
		if should_ignore(ent) then return end
		if ent.IsFetus ~= true then return end
		local d = ent:GetData()
		local once_key = M.own_key .. "bomb_bound"
		if d[once_key] then return end
		-- FrameCount==1 can be missed if UPDATE ordering skips; allow early frames once.
		if (ent.FrameCount or 0) > 2 then return end
		if Game():GetRoom():GetFrameCount() == 1 and ent.Velocity:Length() < 0.01 then return end
		local resolved = bind_from_candidate(ent, "bomb", {
			from_fire_callback = true,
			allow_create = true,
			allow_mimic_create = true,
			max_frame_delta = 1,
			position = ent.Position,
			direction = ent.Velocity,
			role = "primary",
			reason = "bomb_fetus",
		})
		if resolved.attack then
			d[once_key] = true
		end
	end,
})

local function try_link_epic_target(rocket)
	if not rocket then return end
	local attack = select(1, registry.GetAttackForMember(rocket))
	if not attack then return end
	local parent = rocket.Parent
	if not parent or parent.Type ~= EntityType.ENTITY_EFFECT then return end
	if parent.Variant ~= EffectVariant.TARGET then return end
	local ph = GetPtrHash(parent)
	local existing = registry.bindings[ph]
	if existing then
		if existing.attack_id == attack.id then
			registry.GetAttackForMember(parent)
		end
		return
	end
	-- Parent appears at FrameCount≈1; attack may already be sealed (max_delta=2).
	registry.BindMember(attack, parent, {
		allow_sealed = true,
		reason = "epic_target",
		position = parent.Position,
	})
end

local function remember_epic_impact(ent)
	local attack, binding = registry.GetAttackForMember(ent)
	if not attack then return end
	if attack.open_for_members then
		grouping.seal_attack_and_clear(attack)
	end
	local gen = binding and binding.generation
	registry.remember_for_damage(ent, attack, gen)
	local player = attack.player or resolve_attack_player(ent)
	if player then
		registry.remember_player_blast(player, attack, gen, ent.Position)
	end
end

local function try_bind_epic_rocket(ent)
	if should_ignore(ent) then return end
	-- Epiphany/Benighted: vanilla missile is EffectVariant.ROCKET; SpawnerEntity→player.
	-- Also accept Qing simulated MeusRocket.
	local hash = GetPtrHash(ent)
	-- Already bound: keep flight Attack (do not emit a second ONCE at landing).
	if registry.bindings[hash] then
		registry.GetAttackForMember(ent) -- repair wiped meta if needed
		try_link_epic_target(ent)
		return
	end
	local seed = ent.InitSeed
	-- Probe 2026-09-02: every rocket rebound at Timeout=0 / PO.Y=0 into a 1-frame Attack;
	-- gospel tagged that ghost Attack, while flight Attack + Timeout==1 remember stayed untagged.
	if seed and M.epic_claimed[seed] then
		try_link_epic_target(ent)
		return
	end
	local d = ent:GetData()
	local once_key = M.own_key .. "epic_bound"
	if d[once_key] then
		try_link_epic_target(ent)
		return
	end
	-- Prefer inherit from MeusFetus / TARGET Parent Attack (Qing simulated Epic lifecycle).
	local parent = ent.Parent
	if parent and classifier.is_epic_lifecycle_entity(parent) then
		local parent_attack = select(1, registry.GetAttackForMember(parent))
		if parent_attack and parent_attack.active and not parent_attack.ending then
			local ok = registry.BindMember(parent_attack, ent, {
				allow_sealed = true,
				role = "proxy",
				reason = "epic_rocket_from_carrier",
				position = ent.Position,
			})
			if ok then
				d[once_key] = true
				if seed then
					M.epic_claimed[seed] = true
				end
				try_link_epic_target(ent)
				return
			end
		end
	end
	local resolved = bind_from_candidate(ent, "epic", {
		from_fire_callback = true,
		allow_create = true,
		allow_mimic_create = true,
		max_frame_delta = 2,
		position = ent.Position,
		role = "proxy",
		reason = "epic_rocket",
	})
	if not resolved.attack then
		return
	end
	d[once_key] = true
	if seed then
		M.epic_claimed[seed] = true
	end
	try_link_epic_target(ent)
end

local function is_epic_rocket_variant(v)
	if v == EffectVariant.ROCKET then return true end
	if EffectVariant.SMALL_ROCKET and v == EffectVariant.SMALL_ROCKET then return true end
	if enums.Entities.ID_EFFECT_MeusRocket and v == enums.Entities.ID_EFFECT_MeusRocket then return true end
	return false
end

-- Vanilla Epic: mark on INIT (Spawner often ready). Epiphany pattern.
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_INIT,
	params = EffectVariant.ROCKET,
	Function = function(_, ent)
		try_bind_epic_rocket(ent)
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
	params = EffectVariant.ROCKET,
	Function = function(_, ent)
		-- INIT may miss Spawner; retry early frames. Timeout==1 ≈ impact (Benighted).
		try_bind_epic_rocket(ent)
		if ent.Timeout == 1 then
			remember_epic_impact(ent)
		end
	end,
})

if EffectVariant.SMALL_ROCKET then
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_INIT,
	params = EffectVariant.SMALL_ROCKET,
	Function = function(_, ent) try_bind_epic_rocket(ent) end,
})
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
	params = EffectVariant.SMALL_ROCKET,
	Function = function(_, ent)
		try_bind_epic_rocket(ent)
		if ent.Timeout == 1 then
			remember_epic_impact(ent)
		end
	end,
})
end

-- Qing simulated epic rocket (Epic_holder).
if enums.Entities.ID_EFFECT_MeusRocket then
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_INIT,
	params = enums.Entities.ID_EFFECT_MeusRocket,
	Function = function(_, ent) try_bind_epic_rocket(ent) end,
})
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
	params = enums.Entities.ID_EFFECT_MeusRocket,
	Function = function(_, ent)
		try_bind_epic_rocket(ent)
		if ent.Timeout == 1 then
			remember_epic_impact(ent)
		end
	end,
})
end

-- Untyped fallback for loaders that drop variant params.
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
	params = nil,
	Function = function(_, ent)
		if not ent or not is_epic_rocket_variant(ent.Variant) then return end
		try_bind_epic_rocket(ent)
	end,
})

-- Vanilla Epic TARGET is bound as a sealed-allowed satellite of the rocket Attack (see try_link_epic_target).

-- RGON: Game():BombDamage() hooks. Epic/Dr explosions go through here with explicit Source.
-- PRE runs before per-entity TAKE_DMG; remember attack so damage binding can resolve.
local function resolve_blast_attack(source, position)
	if source then
		local attack, binding = registry.GetAttackForMember(source)
		if attack then return attack, binding, source end
		attack, binding = registry.lookup_recent_for_damage(source)
		if attack then return attack, binding, source end
		local player = (source.ToPlayer and source:ToPlayer())
			or auxi.check_spawner_player(source)
			or auxi.check_near_spawner_player(source)
		if player then
			attack, binding = registry.lookup_recent_player_blast(player, position)
			if attack then return attack, binding, source end
		end
	end
	if position and EffectVariant.ROCKET then
		local rockets = Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.ROCKET, -1, false, false)
		for i = 1, #rockets do
			local rocket = rockets[i]
			if rocket and rocket.Position:Distance(position) <= 48 then
				local attack, binding = registry.GetAttackForMember(rocket)
				if not attack then
					attack, binding = registry.lookup_recent_for_damage(rocket)
				end
				if attack then return attack, binding, rocket end
			end
		end
	end
	return nil, nil, nil
end

if ModCallbacks.MC_PRE_BOMB_DAMAGE then
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_BOMB_DAMAGE,
	params = nil,
	Function = function(_, position, damage, radius, lineCheck, source, tearFlags, damageFlags, damageSource)
		local attack, binding, member = resolve_blast_attack(source, position)
		if not attack then return end
		local gen = binding and binding.generation
		if member then
			registry.remember_for_damage(member, attack, gen)
		end
		local player = attack.player
			or (source and source.ToPlayer and source:ToPlayer())
			or (source and auxi.check_spawner_player(source))
		if player then
			registry.remember_player_blast(player, attack, gen, position)
		end
	end,
})
end

local DEAD_BINDING_SWEEP_INTERVAL = 4
local REGISTRY_INTEGRITY_SWEEP_INTERVAL = 30
do
	-- Public builds: slightly slower integrity safety net (still always on).
	local ok, release = pcall(require, "Qing_Remaster_scripts.core.release_channel")
	if ok and release and release.public == true then
		REGISTRY_INTEGRITY_SWEEP_INTERVAL = 60
	end
end
do
	local st = registry.maintenance_stats
	if st then
		st.dead_interval = DEAD_BINDING_SWEEP_INTERVAL
		st.integrity_interval = REGISTRY_INTEGRITY_SWEEP_INTERVAL
	end
end

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		local frame = Game():GetFrameCount()
		grouping.seal_expired()
		-- Layer 2 / Layer 3 throttled separately (do not merge intervals).
		if frame % DEAD_BINDING_SWEEP_INTERVAL == 0 then
			registry.sweep_dead_bindings()
		end
		if frame % REGISTRY_INTEGRITY_SWEEP_INTERVAL == 0 then
			registry.sweep_registry_integrity()
		end
		registry.tick_tombstones()
		tick_sword_beam_holds()
	end,
})

table.insert(M.myToCall, #M.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	params = nil,
	Function = function()
		-- EndAll clears bindings; do not also run Layer 2/3 sweeps in the same callback.
		registry.EndAllAttacks("room_change")
		grouping.clear_all()
		dps.reset()
		M.knife_state = {}
		M.bone_club_state = {}
		M.epic_claimed = {}
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		registry.reset_all()
		grouping.clear_all()
		dps.reset()
		M.knife_state = {}
		M.bone_club_state = {}
		M.epic_claimed = {}
	end,
})

return M

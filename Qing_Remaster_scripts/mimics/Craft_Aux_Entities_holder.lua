-- 批次 4 + 三位一体盾：400 命运长枪 / 243 三位一体盾 / 693 苍蝇军团 / 702 复仇之火
-- 全部挂 Flight / craft_uid；禁止临时 AddCollectible。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local dev_env = require("Qing_Remaster_scripts.core.dev_environment")

local item = {
	ToCall = {},
	pre_ToCall = {},
	own_key = "Craft_Aux_Entities_holder_",
	cfg = {},
}

local IDS = {
	TRINITY = CollectibleType.COLLECTIBLE_TRINITY_SHIELD or 243,
	SPEAR = CollectibleType.COLLECTIBLE_SPEAR_OF_DESTINY or 400,
	SWARM = CollectibleType.COLLECTIBLE_SWARM or 693,
	VENGEFUL = CollectibleType.COLLECTIBLE_VENGEFUL_SPIRIT or 702,
	MOMS_KNIFE = 114,
}

local SPEAR_VAR = (EffectVariant and EffectVariant.SPEAR_OF_DESTINY) or 83
local SHIELD_VAR = (EffectVariant and EffectVariant.TRINITY_SHIELD) or 47
local SWARM_VAR = (FamiliarVariant and FamiliarVariant.SWARM_FLY_ORBITAL) or 229
local BLUE_FLY_VAR = (FamiliarVariant and FamiliarVariant.BLUE_FLY) or 43
-- 3.206.702：Familiar / WISP / Vengeful Spirit collectible subtype
local VENGEFUL_VAR = (FamiliarVariant and FamiliarVariant.WISP) or 206

local DEFAULTS = {
	spear_reach = 48,
	spear_hit_cd = 7,
	spear_fear_chance = 0.05,
	shield_reach = 36,
	shield_block_radius = 22,
	swarm_init = 8,
	swarm_cap = 16,
	swarm_orbit_r = 28,
	swarm_omega = 8,
	swarm_lift_extra = 6,
	vengeful_cap = 6,
	vengeful_orbit_r = 40,
	vengeful_omega = 5,
	vengeful_lift_extra = 6,
	vengeful_tear_speed = 10,
	vengeful_tear_height = -23,
	vengeful_contact_mul = 0.5,
	vengeful_contact_hit_cd = 4,
	vengeful_fire_interval = 30, -- 逻辑帧；与 Flight volley 解耦，同帧齐射全部魂火
}

-- 与 Craft_Familiar_holder / Craft_Orbital_holder 同源：小实体可见中心比 Flight 原点高约 16 screen px
local FAMILIAR_CENTER_PO_Y = 16 * 61 / 40

-- Flight 附属： [air_seed] = {spear=, shield=}
local ATTACH = {}
-- 苍蝇/复仇：轨道与相位由 Craft_Orbital_holder 统一管理（rebuild_orbit_layout）
-- 命中 CD： [InitSeed] = { [npc_seed]=frame }
local HIT_CD = {}
local SWARM_PURGE_INTERVAL = 15

local function get_air_mod()
	return require("Qing_Remaster_scripts.items.Item_Air_Flight")
end

local function get_blueprint()
	return require("Qing_Remaster_scripts.items.Item_Blue_Print")
end

local function get_orbital()
	return require("Qing_Remaster_scripts.mimics.Craft_Orbital_holder")
end

local function venge_probe_trace(event, fam, extra)
	local Probe = dev_env.require_probe("Qing_Remaster_scripts.others.vengeful_craft_lifecycle_probe")
	if Probe and Probe.trace then
		Probe.trace(event, fam, extra)
	end
end

local function craft_uid_of(air)
	if not air then return nil end
	return air:GetData()[get_blueprint().own_key.."craft_uid"]
end

local function air_for_seed(air_seed)
	if not air_seed then return nil end
	local Air = get_air_mod()
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, Air.familiar or enums.Familiars.QingsAirs, -1, false, false)) do
		local air = ent:ToFamiliar()
		if air and air:Exists() and air.InitSeed == air_seed then
			return air
		end
	end
	return nil
end

local function air_for_craft_uid(craft_uid, player)
	if not craft_uid then return nil end
	local Air = get_air_mod()
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, Air.familiar or enums.Familiars.QingsAirs, -1, false, false)) do
		local air = ent:ToFamiliar()
		if air and air:Exists() and tostring(craft_uid_of(air)) == tostring(craft_uid) then
			local p = auxi.check_spawner_player(air)
			if not player or (p and GetPtrHash(p) == GetPtrHash(player)) then
				return air
			end
		end
	end
	return nil
end

local function player_from_hash(ph)
	if not ph then return nil end
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Isaac.GetPlayer(i)
		if p and GetPtrHash(p) == ph then return p end
	end
	return nil
end

local function cfg(key)
	local v = item.cfg[key]
	if v ~= nil then return v end
	return DEFAULTS[key]
end

function item.get_cfg(key)
	return cfg(key)
end

local function count_of(profile, id)
	return CraftProfile.count_of(profile and profile.counts, id)
end

local function flight_damage(profile, player)
	return (profile and profile.stats and tonumber(profile.stats.damage))
		or (player and tonumber(player.Damage))
		or 3.5
end

--- 原版弹伤：0.10×层数 + 2.90（层数 = AbsoluteStage）
local function vengeful_tear_damage()
	local n = tonumber(Game():GetLevel():GetAbsoluteStage()) or 1
	return 0.10 * n + 2.90
end

local function last_aim(air)
	local Air = get_air_mod()
	local aim = air:GetData()[Air.own_key.."last_aim"]
	if aim and aim:Length() > 0.01 then return aim:Normalized() end
	return Vector(0, 1)
end

--- Flight 巡航 PO + 宝宝可见中心补正（对齐 apply_render_offset / bind_familiar）
local function flight_visual_po_y(air, extra_bias)
	extra_bias = tonumber(extra_bias) or 0
	if not air then return FAMILIAR_CENTER_PO_Y + extra_bias end
	local po = air.PositionOffset or Vector(0, 0)
	local y = po.Y
	if math.abs(y) < 0.5 then
		local Air = get_air_mod()
		local z = tonumber(air:GetData()[Air.own_key.."OffsetZ"])
		y = z ~= nil and z or -38
	end
	return y + FAMILIAR_CENTER_PO_Y + extra_bias
end

local function apply_flight_visual_po(ent, air, extra_bias)
	if not ent or not air or ent.PositionOffset == nil then return end
	local po = air.PositionOffset or Vector(0, 0)
	ent.PositionOffset = Vector(po.X, flight_visual_po_y(air, extra_bias))
end

local function player_stock(player)
	local d = player:GetData()
	local s = d[item.own_key.."stock"]
	if not s then
		s = {
			swarm = tonumber(cfg("swarm_init")) or 8,
			vengeful = 0,
			swarm_inited = true,
		}
		d[item.own_key.."stock"] = s
	end
	if not s.swarm_inited then
		s.swarm = tonumber(cfg("swarm_init")) or 8
		s.swarm_inited = true
	end
	return s
end

local function list_player_flights(player)
	local Air = get_air_mod()
	local out = {}
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, Air.familiar or enums.Familiars.QingsAirs, -1, false, false)) do
		local air = ent:ToFamiliar()
		if air and auxi.check_all_exists(air) then
			local p = auxi.check_spawner_player(air)
			if p and GetPtrHash(p) == GetPtrHash(player) then
				local profile = air:GetData()[Air.own_key.."craft_profile"]
				local uid = craft_uid_of(air)
				if profile and uid then
					out[#out + 1] = {air = air, profile = profile, uid = tostring(uid)}
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.uid < b.uid end)
	return out
end

local function claim_effect(fx, air, tag)
	if not fx then return end
	fx:GetData()[item.own_key..tag] = true
	fx.Parent = nil
	fx.SpawnerEntity = air
	if fx.SetDisableFollowParent then
		pcall(function() fx:SetDisableFollowParent(true) end)
	elseif fx.DisableFollowParent ~= nil then
		fx.DisableFollowParent = true
	end
	if fx.Timeout ~= nil then fx.Timeout = -1 end
	fx.CollisionDamage = 0
	-- 不推挤敌人；挡弹用半径判定，不依赖实体碰撞盒
	if fx.EntityCollisionClass ~= nil then
		fx.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	end
end

local function remove_attach(air_seed, key)
	local row = ATTACH[air_seed]
	if not row then return end
	local ent = row[key]
	if ent and ent:Exists() then ent:Remove() end
	row[key] = nil
end

--- 瞄准角 → Rotation 动画八向帧（anm2 每向 Delay=2，时间轴帧 0,2,…,14）
local function aim_octant_frame(aim)
	if not aim or aim:Length() < 0.01 then aim = Vector(0, 1) end
	local ang = aim:GetAngleDegrees() + 22.5
	ang = ang % 360
	if ang < 0 then ang = ang + 360 end
	local oct = math.floor(ang / 45) % 8
	return oct * 2
end

local function apply_aim_sprite(ent, aim)
	if not ent then return end
	local spr = ent:GetSprite()
	if not spr then return end
	-- 枪/盾朝向靠 Rotation 八向贴图，禁止用 Sprite.Rotation（Idle 层已带固定角）
	if ent.SpriteRotation ~= nil then ent.SpriteRotation = 0 end
	spr.Rotation = 0
	if spr.PlaybackSpeed ~= nil then spr.PlaybackSpeed = 0 end
	local frame = aim_octant_frame(aim)
	pcall(function()
		if spr:GetAnimation() ~= "Rotation" then
			spr:Play("Rotation", true)
		end
		spr:SetFrame("Rotation", frame)
	end)
end

local function ensure_attach(air, player, profile, key, variant, reach)
	local seed = air.InitSeed
	ATTACH[seed] = ATTACH[seed] or {}
	local row = ATTACH[seed]
	local ent = row[key]
	if not ent or not ent:Exists() then
		local spawned = Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, 0, air.Position, Vector.Zero, air)
		ent = spawned and (spawned:ToEffect() or spawned) or nil
		if not ent then return nil end
		claim_effect(ent, air, key)
		row[key] = ent
	end
	local aim = last_aim(air)
	ent.Position = air.Position + aim * reach
	ent.Velocity = Vector.Zero
	-- 跟随 Flight 升空 PO，避免贴地
	if ent.PositionOffset ~= nil and air.PositionOffset then
		ent.PositionOffset = Vector(air.PositionOffset.X, air.PositionOffset.Y)
	end
	claim_effect(ent, air, key)
	apply_aim_sprite(ent, aim)
	return ent
end

local function contact_tick(ent, air, player, profile, opts)
	if not ent or not air then return end
	opts = opts or {}
	local dmg = (tonumber(opts.damage) or flight_damage(profile, player)) * (tonumber(opts.mul) or 1)
	if opts.use_orbital_mul ~= false then
		local Orb = get_orbital()
		if Orb and Orb.aura_damage_mul then
			dmg = dmg * (Orb.aura_damage_mul(air, opts.group or "normal") or 1)
		end
	end
	local cd = math.max(1, math.floor(tonumber(opts.hit_cd) or 10))
	local frame = Game():GetFrameCount()
	local store = HIT_CD[ent.InitSeed]
	if not store then
		store = {}
		HIT_CD[ent.InitSeed] = store
	end
	local radius = tonumber(opts.radius) or 18
	for _, npc in ipairs(Isaac.FindInRadius(ent.Position, radius, EntityPartition.ENEMY)) do
		if npc and npc:Exists() and npc:IsVulnerableEnemy() then
			local ns = npc.InitSeed
			if (store[ns] or 0) <= frame then
				store[ns] = frame + cd
				npc:TakeDamage(dmg, 0, EntityRef(air), 0)
				if opts.fear_chance and opts.fear_chance > 0 and npc.AddFear then
					local rng = player and player:GetCollectibleRNG(opts.rng_id or IDS.SPEAR)
					if rng and rng:RandomFloat() < opts.fear_chance then
						npc:AddFear(EntityRef(air), 60)
					end
				end
			end
		end
	end
end

--- 三位一体盾：挡敌弹，无接触伤
local function shield_block_tick(shield, air)
	if not shield or not air then return end
	local radius = tonumber(cfg("shield_block_radius")) or 22
	local Orb = get_orbital()
	for _, ent in ipairs(Isaac.FindInRadius(shield.Position, radius, EntityPartition.BULLET)) do
		local proj = ent:ToProjectile()
		if proj and proj:Exists() then
			local blockable = true
			if Orb and Orb.is_sworn_blockable_projectile then
				blockable = Orb.is_sworn_blockable_projectile(proj) == true
			else
				local sp = proj.SpawnerEntity
				if sp and (sp:ToPlayer() or (sp:ToFamiliar() and sp:ToFamiliar().Player)) then
					blockable = false
				end
			end
			if blockable then
				proj:Die()
			end
		end
	end
end

local function sync_spear_shield(air, player, profile)
	local seed = air.InitSeed
	local has_spear = count_of(profile, IDS.SPEAR) > 0
	local has_shield = count_of(profile, IDS.TRINITY) > 0

	if has_spear then
		local spear = ensure_attach(air, player, profile, "spear", SPEAR_VAR, tonumber(cfg("spear_reach")) or 48)
		if spear then
			contact_tick(spear, air, player, profile, {
				damage = 2 * flight_damage(profile, player),
				mul = 1,
				use_orbital_mul = false,
				hit_cd = cfg("spear_hit_cd"),
				radius = 16,
				fear_chance = tonumber(cfg("spear_fear_chance")) or 0.05,
				rng_id = IDS.SPEAR,
			})
		end
	else
		remove_attach(seed, "spear")
	end

	if has_shield then
		local shield = ensure_attach(air, player, profile, "shield", SHIELD_VAR, tonumber(cfg("shield_reach")) or 36)
		if shield then
			-- 无碰撞伤害；只挡弹
			shield.CollisionDamage = 0
			shield_block_tick(shield, air)
		end
	else
		remove_attach(seed, "shield")
	end
end

-- ----- Swarm -----

local function orbital_assigned(fam)
	if not fam then return false end
	local Orb = get_orbital()
	if Orb.get_bind(fam) then return true end
	if Orb.is_pending_orbital and Orb.is_pending_orbital(fam) then return true end
	return false
end

local function clear_orbitals_for_air(air, kind, player, soft_venge)
	if not air then return end
	local Orb = get_orbital()
	local list = (Orb.find_reserved_for_air and Orb.find_reserved_for_air(air, kind))
		or Orb.find_bound_for_air(air, kind)
	-- 真实持有 702：飞回玩家轨道，禁止 immediate 解绑后停在 Flight 旁。
	local flyback = kind == "vengeful_spirit" and soft_venge == true
	local release = Orb.release_reserved_orbital or Orb.release_orbital
	for _, fam in ipairs(list) do
		release(fam, {
			immediate = not flyback,
			reason = flyback and "venge_soft_clear" or "air_clear",
		})
	end
end

local function is_managed_swarm(fam)
	local bind = get_orbital().get_bind(fam)
	return bind and bind.kind == "swarm"
end

--- 与 Craft_Familiar_holder.find_unbound 同源：至少两帧且 Sprite 文件/动画已由原版初始化。
local function familiar_vanilla_ready(fam)
	if not fam or not auxi.check_all_exists(fam) then return false end
	if fam.Visible == false then return false end
	if fam.IsDead and fam:IsDead() then return false end
	local sprite = fam:GetSprite()
	if not sprite then return false end
	local filename = sprite:GetFilename() or ""
	local animation = sprite:GetAnimation() or ""
	return (fam.FrameCount or 0) >= 2 and filename ~= "" and animation ~= ""
end

local function swarm_player_match(fam, player)
	if not fam or not player then return false end
	local p = fam.Player
	if p and GetPtrHash(p) == GetPtrHash(player) then return true end
	local sp = fam.SpawnerEntity and fam.SpawnerEntity:ToFamiliar()
	if sp and sp.Player and GetPtrHash(sp.Player) == GetPtrHash(player) then return true end
	return false
end

--- 制造侧接管 693 时，清掉玩家身上未绑定的原版苍蝇军团（真实持 693 + 配方叠加时会 EvaluateItems 再刷）
local function purge_unmanaged_swarm(player)
	if not player then return end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, SWARM_VAR, -1, false, false)) do
		local fam = ent:ToFamiliar()
		if fam and fam:Exists() and not orbital_assigned(fam) and swarm_player_match(fam, player) then
			if familiar_vanilla_ready(fam) then
				fam:Remove()
			end
		end
	end
end

local function find_unassigned_swarm(player)
	local out = {}
	if not player then return out end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, SWARM_VAR, -1, false, false)) do
		local fam = ent:ToFamiliar()
		if fam and fam:Exists() and not orbital_assigned(fam) and swarm_player_match(fam, player) then
			out[#out + 1] = fam
		end
	end
	table.sort(out, function(a, b)
		local ra = familiar_vanilla_ready(a)
		local rb = familiar_vanilla_ready(b)
		if ra ~= rb then return ra end
		return a.InitSeed < b.InitSeed
	end)
	return out
end

local function find_loose_swarm(player)
	local out = {}
	for _, fam in ipairs(find_unassigned_swarm(player)) do
		if familiar_vanilla_ready(fam) then
			out[#out + 1] = fam
		end
	end
	return out
end

local function venge_player_match(fam, player)
	if not fam or not player then return false end
	local fp = fam.Player
	if fp and GetPtrHash(fp) == GetPtrHash(player) then return true end
	local sp = fam.SpawnerEntity
	if sp and sp:Exists() then
		local owner = auxi.check_spawner_player(sp)
		if owner and GetPtrHash(owner) == GetPtrHash(player) then return true end
	end
	return false
end

local function truly_owns_venge(player)
	return player and player.HasCollectible and player:HasCollectible(IDS.VENGEFUL, true) == true
end

local function count_player_venge_wisps(player)
	local n = 0
	if not player then return 0 end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, VENGEFUL_VAR, IDS.VENGEFUL, false, false)) do
		local fam = ent:ToFamiliar()
		if fam and fam:Exists() and venge_player_match(fam, player) then
			n = n + 1
		end
	end
	return n
end

--- 真实持有：解绑并交还原版玩家轨道；模拟份：直接 Remove。
local function release_venge_wisp(fam, player, soft)
	if not fam then return end
	local Orb = get_orbital()
	if not fam:Exists() then return end
	if soft and player and truly_owns_venge(player) then
		Orb.release_orbital(fam, {immediate = false, reason = "venge_soft_release"})
	else
		Orb.release_orbital(fam, {immediate = true, reason = "venge_release"})
	end
end

local function find_unassigned_venge(player)
	local out = {}
	if not player then return out end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, VENGEFUL_VAR, IDS.VENGEFUL, false, false)) do
		local fam = ent:ToFamiliar()
		if fam and fam:Exists() and not orbital_assigned(fam) and venge_player_match(fam, player) then
			out[#out + 1] = fam
		end
	end
	table.sort(out, function(a, b)
		local ra = familiar_vanilla_ready(a)
		local rb = familiar_vanilla_ready(b)
		if ra ~= rb then return ra end
		return a.InitSeed < b.InitSeed
	end)
	return out
end

local function find_loose_venge(player)
	local out = {}
	for _, fam in ipairs(find_unassigned_venge(player)) do
		if familiar_vanilla_ready(fam) then
			out[#out + 1] = fam
		end
	end
	return out
end

--- 优先删未绑定/合成 spawn，把场上魂火数压回 limit（修复历史重复 spawn 残留）。
local function purge_excess_venge(player, limit)
	limit = math.max(0, math.floor(tonumber(limit) or 0))
	if not player or limit < 0 then return end
	local wisps = {}
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, VENGEFUL_VAR, IDS.VENGEFUL, false, false)) do
		local fam = ent:ToFamiliar()
		if fam and fam:Exists() and venge_player_match(fam, player) then
			wisps[#wisps + 1] = fam
		end
	end
	while #wisps > limit do
		local pick, pick_rank = nil, nil
		for _, fam in ipairs(wisps) do
			local Orb = get_orbital()
			if Orb.is_pending_orbital and Orb.is_pending_orbital(fam) then
				goto continue_scan
			end
			local rank = 0
			if orbital_assigned(fam) then
				local bind = Orb.get_bind(fam)
				if bind and bind.synthetic == false then
					rank = 3
				else
					rank = 2
				end
			else
				rank = 0
			end
			if pick == nil or rank < pick_rank or (rank == pick_rank and fam.InitSeed < pick.InitSeed) then
				pick, pick_rank = fam, rank
			end
			::continue_scan::
		end
		if not pick then break end
		for i, fam in ipairs(wisps) do
			if GetPtrHash(fam) == GetPtrHash(pick) then
				table.remove(wisps, i)
				break
			end
		end
		if pick_rank <= 1 then
			local Orb = get_orbital()
			if Orb.clear_pending_orbital then Orb.clear_pending_orbital(pick) end
			venge_probe_trace("lua_remove", pick, {reason = "purge_excess", rank = pick_rank})
			if pick:Exists() then pick:Remove() end
		else
			venge_probe_trace("purge_excess_release", pick, {rank = pick_rank})
			release_venge_wisp(pick, player, pick_rank >= 3)
		end
	end
end

local function clear_swarm_for_air(air_seed, craft_uid)
	local air = air_for_seed(air_seed)
	if air then clear_orbitals_for_air(air, "swarm", auxi.check_spawner_player(air), false) end
end

local function clear_venge_for_air(air_seed, craft_uid, player)
	local air = air_for_seed(air_seed)
	if air then
		clear_orbitals_for_air(air, "vengeful_spirit", player, player and truly_owns_venge(player))
	end
end

local function allocate_stock(flights, total, need_id)
	local eligible = {}
	for _, row in ipairs(flights) do
		if count_of(row.profile, need_id) > 0 then
			eligible[#eligible + 1] = row
		end
	end
	local n = #eligible
	if n == 0 then return {} end
	local shares = {}
	for i, row in ipairs(eligible) do
		shares[i] = {air = row.air, profile = row.profile, uid = row.uid, count = 0}
	end
	for i = 0, total - 1 do
		local idx = (i % n) + 1
		shares[idx].count = shares[idx].count + 1
	end
	return shares
end

local function reconcile_swarm_for_share(share, player, _group_phase)
	local Orb = get_orbital()
	local air = share.air
	local want = math.max(0, math.floor(share.count or 0))
	local leftover = find_unassigned_swarm(player)
	Orb.ensure_kind_orbitals(air, player, "swarm", want, {
		synthetic_claim = false,
		claim_next = function(pl, _a, _slot)
			local list = find_unassigned_swarm(pl)
			return list[1]
		end,
	})
	for _, fam in ipairs(leftover) do
		if fam and fam:Exists() and not orbital_assigned(fam) then
			fam:Remove()
		end
	end
end

local function reconcile_swarm(player, flights)
	if not player then return end
	flights = flights or list_player_flights(player)
	local stock = player_stock(player)
	local has_any = false
	for _, row in ipairs(flights) do
		if count_of(row.profile, IDS.SWARM) > 0 then has_any = true break end
	end
	if not has_any then
		for _, row in ipairs(flights) do
			clear_swarm_for_air(row.air.InitSeed, row.uid)
		end
		player:GetData()[item.own_key.."swarm_share_map"] = nil
		return
	end
	purge_unmanaged_swarm(player)
	local total = math.max(0, math.min(tonumber(cfg("swarm_cap")) or 16, math.floor(stock.swarm or 0)))
	local shares = allocate_stock(flights, total, IDS.SWARM)
	local seen = {}
	local nshare = math.max(1, #shares)
	local share_map = {}
	for i, share in ipairs(shares) do
		seen[share.air.InitSeed] = true
		local group_phase = (nshare > 1) and ((i - 1) * (360 / nshare)) or 0
		share_map[share.air.InitSeed] = {share = share, group_phase = group_phase}
		reconcile_swarm_for_share(share, player, group_phase)
	end
	player:GetData()[item.own_key.."swarm_share_map"] = share_map
	for _, row in ipairs(flights) do
		if not seen[row.air.InitSeed] then
			clear_swarm_for_air(row.air.InitSeed, row.uid)
		end
	end
end

function item.on_swarm_block(fam, proj, player)
	local Orb = get_orbital()
	local bind = Orb.get_bind(fam)
	if not bind or bind.kind ~= "swarm" then return false end
	local p = player or auxi.check_spawner_player(bind.air) or fam.Player
	local pos = fam.Position
	get_orbital().release_orbital(fam, {immediate = true, reason = "swarm_block"})
	if p then
		local stock = player_stock(p)
		stock.swarm = math.max(0, (stock.swarm or 0) - 1)
		p:GetData()[item.own_key.."reconcile_sig"] = nil
		Isaac.Spawn(EntityType.ENTITY_FAMILIAR, BLUE_FLY_VAR, 0, pos, Vector.Zero, p)
	end
	if proj and proj:Exists() then
		proj:Remove()
	end
	return true
end

-- ----- Vengeful（轨道在 Craft_Orbital_holder；此处仅库存 / 齐射 / purge） -----

local function is_craft_venge_entity(fam)
	if not fam or not fam:Exists() then return false end
	if fam.Variant ~= VENGEFUL_VAR or fam.SubType ~= IDS.VENGEFUL then return false end
	return orbital_assigned(fam)
end

--- 配方含 702 时清掉未绑定的原版魂火（真实持 702 + 配方叠加时 EvaluateItems 会再刷）
local function purge_unmanaged_venge(player)
	if not player then return end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, VENGEFUL_VAR, IDS.VENGEFUL, false, false)) do
		local fam = ent:ToFamiliar()
		if fam and fam:Exists() and not is_craft_venge_entity(fam) and venge_player_match(fam, player) then
			if familiar_vanilla_ready(fam) then
				venge_probe_trace("lua_remove", fam, {reason = "purge_unmanaged"})
				fam:Remove()
			end
		end
	end
end

--- 须走 wisp:FireProjectile，引擎才会套 wisps.xml id=702 的 tear_vengeful（or=200 → 红白灵火）。
local function fire_venge_tear(wisp, air, player, profile, aim)
	if not wisp or not air or not player or not profile then return end
	if not aim or aim:Length() < 0.01 then
		aim = last_aim(air)
	end
	if not aim or aim:Length() < 0.01 then return end
	aim = aim:Normalized()
	local shot_speed = (profile.stats and profile.stats.shotspeed) or player.ShotSpeed or 1
	local speed = shot_speed * (tonumber(cfg("vengeful_tear_speed")) or 10)
	local n = aim * speed
	local ent = nil
	if wisp.FireProjectile then
		ent = wisp:FireProjectile(n)
	end
	if not ent then
		ent = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.BLUE or 0, 0, wisp.Position, n, wisp)
	end
	if ent and ent.GetData then
		ent:GetData()[item.own_key.."venge_tear"] = true
	end
	local q = ent and ent:ToTear()
	if not q then return end
	-- FireProjectile 可能被玩家射击输入改向；强制写回 Flight 瞄准
	q.Velocity = n
	q.SpawnerEntity = wisp
	q.Parent = wisp
	q.Height = tonumber(cfg("vengeful_tear_height")) or -23
	q.Scale = 1
	q.CollisionDamage = vengeful_tear_damage()
	-- 探针：Variant=0 SubType=0，无 TEAR_SPECTRAL；勿手改 Color/Tint（会盖掉 tear_vengeful）
	local Air = get_air_mod()
	q:GetData()[Air.own_key.."craft_air"] = air
	q:GetData()[Air.own_key.."craft_uid"] = craft_uid_of(air)
	q:GetData()[item.own_key.."venge_tear"] = true
	local FamiliarH = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
	if FamiliarH.arm_tear_visual_lift then
		FamiliarH.arm_tear_visual_lift(q, wisp, air)
	elseif q.PositionOffset ~= nil then
		q.PositionOffset = Vector(0, 0)
	end
end

--- 该 Flight 绑定的全部魂火同帧齐射（由 try_craft_volley 在 Flight volley 时调用）。
local function fire_venge_volley(air, player, craft_prof, aim_dir)
	if not air or not player or not craft_prof then return end
	if count_of(craft_prof, IDS.VENGEFUL) <= 0 then return end
	local aim = aim_dir
	if not aim or aim:Length() < 0.01 then
		aim = last_aim(air)
	end
	if not aim or aim:Length() < 0.01 then return end
	aim = aim:Normalized()
	local Orb = get_orbital()
	for _, fam in ipairs(Orb.find_bound_for_air(air, "vengeful_spirit")) do
		if fam and fam:Exists() and fam.SubType == IDS.VENGEFUL then
			fire_venge_tear(fam, air, player, craft_prof, aim)
		end
	end
end

--- Flight volley 触发；同帧齐射全部魂火，最短间隔 vengeful_fire_interval（默认 30 逻辑帧）。
function item.try_craft_volley(air, player, craft_prof, aim_dir)
	if not air or not player or not craft_prof then return end
	if count_of(craft_prof, IDS.VENGEFUL) <= 0 then return end
	local Orb = get_orbital()
	if #Orb.find_bound_for_air(air, "vengeful_spirit") <= 0 then return end
	local frame = Game():GetFrameCount()
	local d = air:GetData()
	local last_key = item.own_key.."venge_fire_frame"
	local last = tonumber(d[last_key])
	local interval = math.max(1, math.floor(tonumber(cfg("vengeful_fire_interval")) or 30))
	if player:HasTrinket(TrinketType.TRINKET_FORGOTTEN_LULLABY) then
		interval = math.max(1, math.floor(interval * 0.5))
	end
	if last and (frame - last) < interval then return end
	fire_venge_volley(air, player, craft_prof, aim_dir)
	d[last_key] = frame
end

local function reconcile_venge_for_share(share, player)
	local Orb = get_orbital()
	local air = share.air
	local want = math.max(0, math.floor(share.count or 0))
	local owned = truly_owns_venge(player)
	local leftover = find_unassigned_venge(player)
	Orb.ensure_kind_orbitals(air, player, "vengeful_spirit", want, {
		spawn = not owned,
		synthetic_claim = owned and false or nil,
		release_immediate = not owned,
		meta = {spawn_subtype = IDS.VENGEFUL},
		claim_next = function(pl, _a, _slot)
			local list = find_unassigned_venge(pl)
			return list[1]
		end,
	})
	for _, fam in ipairs(leftover) do
		if fam and fam:Exists() and not orbital_assigned(fam) then
			if owned then
				-- 超额原版魂火由 purge 处理
			else
				venge_probe_trace("lua_remove", fam, {reason = "leftover_unassigned"})
				fam:Remove()
			end
		end
	end
end

local function reconcile_vengeful(player, flights)
	if not player then return end
	flights = flights or list_player_flights(player)
	local stock = player_stock(player)
	local has_any = false
	for _, row in ipairs(flights) do
		if count_of(row.profile, IDS.VENGEFUL) > 0 then has_any = true break end
	end
	if not has_any then
		venge_probe_trace("reconcile", nil, {
			owned = truly_owns_venge(player) and true or false,
			total = 0,
			stock = stock.vengeful,
			flight_n = #flights,
			world_n = count_player_venge_wisps(player),
			has_any = false,
		})
		for _, row in ipairs(flights) do
			clear_venge_for_air(row.air.InitSeed, row.uid, player)
		end
		player:GetData()[item.own_key.."venge_share_map"] = nil
		return
	end
	local cap = tonumber(cfg("vengeful_cap")) or 6
	local owned = truly_owns_venge(player)
	if not owned then
		purge_unmanaged_venge(player)
	end
	-- 真实持有 702：场上已有原版魂火。库存可能仍为 0（刚把 702 装进配方），
	-- 绝不能按 stock=0 去 purge_excess，否则会把玩家已有魂火整批删掉。
	local world_n = count_player_venge_wisps(player)
	if owned then
		stock.vengeful = math.max(math.floor(stock.vengeful or 0), world_n)
	end
	local total = math.max(0, math.min(cap, math.floor(stock.vengeful or 0)))
	if owned then
		total = math.max(0, math.min(cap, world_n))
	end
	venge_probe_trace("reconcile", nil, {
		owned = owned and true or false,
		total = total,
		stock = stock.vengeful,
		flight_n = #flights,
		world_n = world_n,
	})
	local shares = allocate_stock(flights, total, IDS.VENGEFUL)
	local seen = {}
	local share_map = {}
	for _, share in ipairs(shares) do
		seen[share.air.InitSeed] = true
		share_map[share.air.InitSeed] = share
		reconcile_venge_for_share(share, player)
	end
	if not owned then
		purge_excess_venge(player, total)
	end
	player:GetData()[item.own_key.."venge_share_map"] = share_map
	for _, row in ipairs(flights) do
		if not seen[row.air.InitSeed] then
			clear_venge_for_air(row.air.InitSeed, row.uid, player)
		end
	end
	if owned then
		purge_unmanaged_venge(player)
	end
end

--- 玩家受伤：模拟份库存 +1（上限 6）；真实持有时由原版 EvaluateItems 生魂火，只触发 reconcile。
function item.on_hurt_vengeful(player)
	if not player then return end
	local stock = player_stock(player)
	local cap = tonumber(cfg("vengeful_cap")) or 6
	stock.vengeful = math.min(cap, (stock.vengeful or 0) + 1)
	local d = player:GetData()
	d[item.own_key.."reconcile_sig"] = nil
	d[item.own_key.."reconcile_frame"] = nil
end

--- hurt router 签名兼容：每 Flight 都会调到，但库存只加一次（同帧锁）
function item.effect_vengeful_hurt(air, player, _profile, _event, _budget)
	if not player then return end
	local d = player:GetData()
	local frame = Game():GetFrameCount()
	if d[item.own_key.."venge_hurt_frame"] == frame then return end
	d[item.own_key.."venge_hurt_frame"] = frame
	if truly_owns_venge(player) then
		d[item.own_key.."reconcile_sig"] = nil
		d[item.own_key.."reconcile_frame"] = nil
		local stock = player_stock(player)
		local cap = tonumber(cfg("vengeful_cap")) or 6
		stock.vengeful = math.min(cap, (stock.vengeful or 0) + 1)
	else
		item.on_hurt_vengeful(player)
	end
end

function item.truly_owns_venge(player)
	return truly_owns_venge(player)
end

function item.on_room_cleared(player)
	if not player then return end
	local flights = list_player_flights(player)
	local has = false
	for _, row in ipairs(flights) do
		if count_of(row.profile, IDS.SWARM) > 0 then has = true break end
	end
	if not has then return end
	local stock = player_stock(player)
	local cap = tonumber(cfg("swarm_cap")) or 16
	stock.swarm = math.min(cap, (stock.swarm or 0) + 1)
	player:GetData()[item.own_key.."reconcile_sig"] = nil
end

function item.clear_for_air(air)
	if not air then return end
	local seed = air.InitSeed
	local uid = craft_uid_of(air)
	remove_attach(seed, "spear")
	remove_attach(seed, "shield")
	ATTACH[seed] = nil
	clear_swarm_for_air(seed, uid)
	clear_venge_for_air(seed, uid, auxi.check_spawner_player(air))
end

function item.on_new_level()
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Isaac.GetPlayer(i)
		if p then
			local stock = player_stock(p)
			stock.vengeful = 0
			local flights = list_player_flights(p)
			for _, row in ipairs(flights) do
				clear_venge_for_air(row.air.InitSeed, row.uid, p)
			end
		end
	end
end

local function aux_reconcile_sig(player, flights)
	local stock = player_stock(player)
	local parts = {
		tostring(stock.swarm or 0),
		tostring(stock.vengeful or 0),
		tostring(#flights),
	}
	for _, row in ipairs(flights) do
		parts[#parts + 1] = tostring(row.uid)
		parts[#parts + 1] = tostring(count_of(row.profile, IDS.SWARM))
		parts[#parts + 1] = tostring(count_of(row.profile, IDS.VENGEFUL))
	end
	if truly_owns_venge(player) then
		parts[#parts + 1] = "own_w:" .. tostring(stock.vengeful or 0)
	end
	return table.concat(parts, "|")
end

local function ensure_player_reconcile(player)
	if not player then return end
	local frame = Game():GetFrameCount()
	local d = player:GetData()
	if d[item.own_key.."reconcile_frame"] == frame then return end
	d[item.own_key.."reconcile_frame"] = frame
	local flights = list_player_flights(player)
	local sig = aux_reconcile_sig(player, flights)
	if d[item.own_key.."reconcile_sig"] ~= sig then
		d[item.own_key.."reconcile_sig"] = sig
		reconcile_swarm(player, flights)
		reconcile_vengeful(player, flights)
	end
end

function item.tick_flight(air, player, profile)
	if not air or not player or not profile then return end
	sync_spear_shield(air, player, profile)
	-- 卸下 702/693 后本 Flight 可能已无 aux，仍必须 reconcile，否则魂火/苍蝇会一直绑在 Flight 上。
	ensure_player_reconcile(player)
	if count_of(profile, IDS.SWARM) > 0 then
		if Game():GetFrameCount() % SWARM_PURGE_INTERVAL == 0 then
			purge_unmanaged_swarm(player)
		end
	end
	if count_of(profile, IDS.VENGEFUL) > 0 then
		if Game():GetFrameCount() % SWARM_PURGE_INTERVAL == 0 then
			if truly_owns_venge(player) then
				purge_unmanaged_venge(player)
			else
				local cap = tonumber(cfg("vengeful_cap")) or 6
				local stock = player_stock(player)
				local limit = math.max(0, math.min(cap, math.floor(stock.vengeful or 0)))
				purge_unmanaged_venge(player)
				purge_excess_venge(player, limit)
			end
		end
	end
end

function item.tick_player(player)
	-- 兼容旧调用；重 reconcile 已迁到 tick_flight + ensure_player_reconcile
	if not player then return end
	ensure_player_reconcile(player)
end

-- PRE Effect：跳过枪/盾原版 AI
local function skip_aux_effect(effect)
	local d = effect:GetData()
	return d[item.own_key.."spear"] or d[item.own_key.."shield"]
end

if ModCallbacks.MC_PRE_EFFECT_UPDATE then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_PRE_EFFECT_UPDATE,
		params = SPEAR_VAR,
		Function = function(_, effect)
			if skip_aux_effect(effect) then return true end
		end,
	})
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_PRE_EFFECT_UPDATE,
		params = SHIELD_VAR,
		Function = function(_, effect)
			if skip_aux_effect(effect) then return true end
		end,
	})
end

-- 挡弹：敌弹撞到 swarm fly（orbital on_block 为主路径；此处兜底）
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_PRE_PROJECTILE_COLLISION,
	params = nil,
	Function = function(_, proj, collider)
		if not proj or not collider then return end
		local fam = collider:ToFamiliar()
		if not fam then return end
		local bind = get_orbital().get_bind(fam)
		if not bind or bind.kind ~= "swarm" then return end
		local Orb = get_orbital()
		local blockable = true
		if Orb and Orb.is_sworn_blockable_projectile then
			blockable = Orb.is_sworn_blockable_projectile(proj) == true
		else
			local sp = proj.SpawnerEntity
			if sp and sp:ToPlayer() then blockable = false end
		end
		if not blockable then return end
		item.on_swarm_block(fam, proj, nil)
		return true
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD,
	params = nil,
	Function = function()
		for i = 0, Game():GetNumPlayers() - 1 do
			item.on_room_cleared(Isaac.GetPlayer(i))
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_LEVEL,
	params = nil,
	Function = function()
		item.on_new_level()
	end,
})

return item

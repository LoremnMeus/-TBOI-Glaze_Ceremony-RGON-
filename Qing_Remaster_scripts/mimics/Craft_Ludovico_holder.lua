-- Craft Ludovico：制造 Flight 的持久受控载体。
-- 形态：普通泪 / 妈刀贴图泪（原版亦为可控泪换刀外观）/ 硫磺环 / 科技环（Tech≡Tech X）。
-- 控制权来自 Flight；多发=卫星；Incubus/该隐另一只眼/Twisted=宝宝卫星。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local CraftTearColors = require("Qing_Remaster_scripts.others.craft_tear_color_data")
local CraftTearParams = require("Qing_Remaster_scripts.others.craft_tear_params_data")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Ludovico_",
	registry = {},
}

local KNIFE_ANM2 = "gfx/008.000_moms knife.anm2"
local RING_SUBTYPE = (LaserSubType and LaserSubType.LASER_SUBTYPE_RING_LUDOVICO) or 1
local BRIM_RING_VARS = {[1]=true,[9]=true,[10]=true,[11]=true,[14]=true,[15]=true}
local AIR_CRAFT_AIR_KEY = "Item_Air_Flight_craft_air"

local function air_ptr(air)
	if not air then return nil end
	return GetPtrHash(air)
end

local function tear_alive(t)
	return t and auxi.check_all_exists(t) and t:ToTear()
end

local function laser_alive(l)
	return l and auxi.check_all_exists(l) and l:ToLaser()
end

local function base_ludo_flags()
	local f = TearFlags.TEAR_LUDOVICO
	if TearFlags.TEAR_SPECTRAL then f = f | TearFlags.TEAR_SPECTRAL end
	if TearFlags.TEAR_PIERCING then f = f | TearFlags.TEAR_PIERCING end
	return f
end

local function resolve_mode(profile)
	local syn = profile and profile.synergy or {}
	if syn.ludo_knife then return "knife" end
	if syn.ludo_brim then return "brim" end
	if syn.ludo_tech then return "tech" end
	return "tear"
end

local function is_lilith(player)
	return player and player:GetPlayerType() == PlayerType.PLAYER_LILITH
end

local function has_bffs(player)
	return player and player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS)
end

local function has_forgotten_lullaby(player)
	return player and player:HasTrinket(TrinketType.TRINKET_FORGOTTEN_LULLABY)
end

-- 仅宝宝弯勺饰品（有弯勺泪弹道具时不叠）
local function has_baby_bender(player)
	return player and player:HasTrinket(TrinketType.TRINKET_BABY_BENDER)
		and not player:HasCollectible(CollectibleType.COLLECTIBLE_SPOON_BENDER)
end

--- 收集已绑定的 Incubus / 该隐另一只眼 / Twisted Pair。
--- BFFS×2；摇篮曲只加快该卫星命中节奏（不复制实体）；宝宝弯勺仅卫星 HOMING。
local function collect_baby_satellites(air, player, profile)
	local out = {}
	if not air or not profile or not profile.extras then return out end
	local extras = profile.extras
	local air_h = air_ptr(air)
	local CraftFam = package.loaded["Qing_Remaster_scripts.mimics.Craft_Familiar_holder"]
		or require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
	local rows = {
		{
			variant = FamiliarVariant.INCUBUS,
			key = "incubus",
			want = extras.incubus == true,
			mul = 0.75,
			lilith_mul = 1,
		},
		{
			variant = FamiliarVariant.CAINS_OTHER_EYE,
			key = "cains_other_eye",
			want = extras.cains_other_eye == true,
			mul = 0.75,
			lilith_mul = 0.75,
		},
		{
			variant = FamiliarVariant.TWISTED_BABY,
			key = "twisted_pair",
			want = extras.twisted_pair == true,
			mul = 0.375,
			lilith_mul = 0.5,
		},
	}
	local lilith = is_lilith(player)
	local bffs = has_bffs(player)
	local lullaby = has_forgotten_lullaby(player)
	local bender = has_baby_bender(player)
	for _, row in ipairs(rows) do
		if row.want and row.variant then
			for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, row.variant, -1, false, false)) do
				if auxi.check_all_exists(fam) then
					local bind = fam:GetData()[CraftFam.own_key.."bind"]
					if bind and bind.air_ptr == air_h then
						local mul = lilith and row.lilith_mul or row.mul
						if bffs then mul = mul * 2 end
						out[#out + 1] = {
							key = row.key .. "_" .. tostring(fam.InitSeed or GetPtrHash(fam)),
							pos = fam.Position,
							damage_mul = mul,
							scale_mul = bffs and 0.85 or 0.72,
							follow_pos = true,
							lullaby = lullaby,
							baby_bender = bender,
						}
					end
				end
			end
		end
	end
	table.sort(out, function(a, b) return tostring(a.key) < tostring(b.key) end)
	return out
end

local function apply_knife_look(tear)
	if not tear then return end
	local s = tear:GetSprite()
	if not s then return end
	local ok = pcall(function()
		s:Load(KNIFE_ANM2, true)
		s:Play("Idle", true)
	end)
	if not ok then
		if tear.ChangeVariant and TearVariant.NAIL then
			pcall(function() tear:ChangeVariant(TearVariant.NAIL) end)
		end
	end
	tear:GetData()[item.own_key.."knife_look"] = true
end

local function clear_hit_caches(ent)
	if not ent or not ent.GetData then return end
	local d = ent:GetData()
	d["Item_Air_Flight_fire_mind_hits"] = nil
	d[item.own_key.."hit_gate"] = nil
end

local function stamp_craft_source_on(ent, rec, slot)
	if not ent then return end
	local d = ent:GetData()
	d[item.own_key.."craft"] = true
	d[item.own_key.."air_ptr"] = rec.air_ptr
	d[item.own_key.."slot_key"] = slot and (slot.key or slot.proj_index)
	d[AIR_CRAFT_AIR_KEY] = rec.air
	d[item.own_key.."rolled_flags"] = slot and slot.rolled_flags
	local profile = rec.profile
	-- 卢多覆盖血泪：不挂会在 REMOVE 时引爆的 craft_haemo；改伤害 tick 低概率爆发
	d.craft_haemo = nil
	if profile and CraftProfile.profile_has_haemolacria and CraftProfile.profile_has_haemolacria(profile) then
		d.craft_haemo_ludo = {
			profile = profile,
			player = rec.player,
			mods = {damage_mul = rec.damage_mul or 1, size_mul = rec.scale or 1},
		}
	else
		d.craft_haemo_ludo = nil
	end
end

local function apply_haemo_ludo_look(tear, profile)
	if not tear or not profile then return end
	if not CraftProfile.profile_has_haemolacria or not CraftProfile.profile_has_haemolacria(profile) then
		return
	end
	CraftProfile.clear_craft_haemo_burst_flag(tear)
	if CraftProfile.apply_haemo_ludo_color then
		CraftProfile.apply_haemo_ludo_color(tear)
	end
end

local function apply_attrs(tear, rec, flags, dmg_mul, scale_mul, slot)
	if not tear then return end
	local profile = rec.profile
	if not profile then return end
	dmg_mul = dmg_mul or 1
	scale_mul = scale_mul or 1
	flags = flags or base_ludo_flags()
	flags = flags | base_ludo_flags()
	if slot and slot.baby_bender and TearFlags.TEAR_HOMING then
		flags = flags | TearFlags.TEAR_HOMING
	end
	local mode = rec.mode or "tear"
	local knife_mul = (mode == "knife") and 2 or 1
	CraftProfile.apply_tear_stats(tear, profile, dmg_mul * knife_mul * (rec.damage_mul or 1), flags, {
		damage_add = rec.damage_add or 0,
		damage_mul = rec.eye_damage_mul or 1,
	})
	CraftTearColors.apply(tear, profile.counts, flags, CraftProfile.TEAR_EFFECTS)
	CraftTearParams.apply(tear, profile.counts, flags, CraftProfile.TEAR_EFFECTS, {})
	tear.FallingSpeed = 0
	tear.FallingAcceleration = 0
	if tear.Height ~= nil then tear.Height = -23 end
	local sc = (tonumber(rec.scale) or 1) * scale_mul
	if mode == "knife" then sc = sc * 1.35 end
	if mode == "brim" or mode == "tech" then
		tear.Visible = false
		tear.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		if tear.CollisionDamage ~= nil then tear.CollisionDamage = 0 end
	else
		tear.Visible = true
		tear.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ENEMIES
	end
	if tear.Scale ~= nil then
		tear.Scale = math.max(0.35, sc * 1.15)
		if tear.ResetSpriteScale then tear:ResetSpriteScale() end
	end
	if mode == "knife" then
		apply_knife_look(tear)
	end
	local td = tear:GetData()
	td[item.own_key.."is_sat"] = td[item.own_key.."is_sat"] == true
	stamp_craft_source_on(tear, rec, slot)
	apply_haemo_ludo_look(tear, profile)
end

local function sample_slot_flags(rec, slot)
	local profile = rec.profile
	local luck = rec.luck or 0
	local seed_ent = slot.tear or slot.ring
	local rolled = CraftProfile.sample_tear_flags(
		rec.player, luck, profile, WeaponType.WEAPON_LUDOVICO_TECHNIQUE,
		{
			shot_serial = rec.epoch or 0,
			craft_uid = rec.craft_uid,
			projectile_index = slot.proj_index or 1,
			init_seed = (seed_ent and seed_ent.InitSeed) or (slot.seed) or (rec.air_ptr or 1),
		}
	)
	local flags = (rolled or base_ludo_flags()) | base_ludo_flags()
	-- rolled_flags 只保存本 epoch 的配方投掷结果。Baby Bender 属于实时饰品状态，
	-- 在 apply_attrs/apply_ring_attrs 时动态 OR，避免中途失去饰品后 HOMING 残留。
	slot.rolled_flags = flags
	return flags
end

local function spawn_tear(rec, slot, is_sat, scale_mul, dmg_mul)
	local player = rec.player
	local air = rec.air
	if not player or not air or not auxi.check_all_exists(air) then return nil end
	local pos = air.Position
	local q = player:FireTear(pos, Vector.Zero, false, true, false)
	if not q then return nil end
	q = q:ToTear() or q
	q.Parent = air
	if q.SpawnerEntity ~= nil then q.SpawnerEntity = air end
	local td = q:GetData()
	td[item.own_key.."is_sat"] = is_sat == true
	slot = slot or {}
	if not slot.rolled_flags then
		sample_slot_flags(rec, slot)
	end
	local flags = slot.rolled_flags or base_ludo_flags()
	if q.AddTearFlags then
		q:AddTearFlags(flags)
	elseif q.TearFlags ~= nil then
		q.TearFlags = (q.TearFlags or BitSet128(0, 0)) | flags
	end
	apply_attrs(q, rec, flags, (is_sat and 0.85 or 1) * (dmg_mul or 1), scale_mul or (is_sat and 0.75 or 1), slot)
	return q
end

local function to_brim_ring_variant(laser, thick)
	if not laser then return end
	if BRIM_RING_VARS[laser.Variant] then
		laser.Variant = 3
	end
	if thick and LaserVariant and LaserVariant.THICKER_RED then
		laser.Variant = LaserVariant.THICKER_RED
	elseif thick then
		laser.Variant = 11
	end
end

local function apply_ring_attrs(ring, rec, slot, is_brim, dmg_mul, radius_mul)
	if not laser_alive(ring) then return end
	local profile = rec.profile
	local syn = profile and profile.synergy or {}
	local flags = slot.rolled_flags or base_ludo_flags()
	if slot.baby_bender and TearFlags.TEAR_HOMING then
		flags = flags | TearFlags.TEAR_HOMING
	end
	if ring.TearFlags ~= nil then
		CraftProfile.write_entity_tear_flags(ring, flags)
	end
	local base_mul = is_brim and 1 or 0.85
	if is_brim and syn.brim_tech then
		base_mul = base_mul * (CraftProfile.brimstone_synergy_mul(profile) or 1.5)
	end
	local stats = profile and profile.stats
	-- 与 CraftProfile.apply_tear_stats / Air Flight 单眼链一致：先加平伤，再乘单眼与载体倍率。
	local dmg = ((stats and stats.damage or 3.5) + (rec.damage_add or 0))
		* (rec.eye_damage_mul or 1)
		* base_mul * (dmg_mul or 1) * (rec.damage_mul or 1)
	ring.CollisionDamage = dmg
	-- 最终伤害写在 bind 之后，覆盖 decorate 的中间缓存，供 reassert 用
	CraftProfile.bind_craft_laser(ring, rec.air, flags, {
		damage = dmg,
		variant = ring.Variant,
	})
	local rad = (is_brim and 42 or 55) * (tonumber(rec.scale) or 1) * (radius_mul or 1)
	if ring.Radius ~= nil then ring.Radius = rad end
	stamp_craft_source_on(ring, rec, slot)
	local ld = ring:GetData()
	ld[item.own_key.."ring"] = true
	ld[item.own_key.."is_brim"] = is_brim == true
end

local function spawn_ring(rec, slot, anchor, is_brim, dmg_mul, radius_mul)
	local player = rec.player
	if not player or not tear_alive(anchor) then return nil end
	local profile = rec.profile
	local syn = profile and profile.synergy or {}
	local rad = (is_brim and 42 or 55) * (tonumber(rec.scale) or 1) * (radius_mul or 1)
	local base_mul = is_brim and 1 or 0.85
	if is_brim and syn.brim_tech then
		base_mul = base_mul * (CraftProfile.brimstone_synergy_mul(profile) or 1.5)
	end
	local q = player:FireTechXLaser(anchor.Position, Vector.Zero, rad, player, base_mul * (dmg_mul or 1))
	if not q then return nil end
	q = q:ToLaser() or q
	q.Parent = anchor
	q.SubType = RING_SUBTYPE
	q.Velocity = Vector.Zero
	q.DisableFollowParent = false
	q:SetTimeout(999999)
	if is_brim then
		to_brim_ring_variant(q, syn.thick_brim == true)
		if CraftProfile.decorate_brimstone then
			pcall(CraftProfile.decorate_brimstone, q, profile, rec.air, player, Vector(1, 0), anchor.Position)
		end
		q.SubType = RING_SUBTYPE
	else
		q.Variant = LaserVariant and LaserVariant.THIN_RED or 2
		q.SubType = RING_SUBTYPE
	end
	if not slot.rolled_flags then
		sample_slot_flags(rec, slot)
	end
	apply_ring_attrs(q, rec, slot, is_brim, dmg_mul, radius_mul)
	return q
end

local function ensure_ring_for(rec, slot, is_brim, dmg_mul, radius_mul)
	slot = slot or {}
	local anchor = slot.tear
	if not tear_alive(anchor) then
		anchor = spawn_tear(rec, slot, slot.is_sat == true, slot.scale_mul, dmg_mul)
		slot.tear = anchor
	end
	if not tear_alive(anchor) then return slot end
	if not laser_alive(slot.ring) then
		slot.ring = spawn_ring(rec, slot, anchor, is_brim, dmg_mul, radius_mul)
	else
		local ring = slot.ring
		ring.Parent = anchor
		ring.Position = anchor.Position
		ring.Velocity = Vector.Zero
		ring:SetTimeout(999999)
		ring.SubType = RING_SUBTYPE
		apply_ring_attrs(ring, rec, slot, is_brim, dmg_mul, radius_mul)
	end
	return slot
end

local function clear_slot_ring(slot)
	if not slot then return end
	if laser_alive(slot.ring) then slot.ring:Remove() end
	slot.ring = nil
end

local function clear_slot(slot)
	if not slot then return end
	clear_slot_ring(slot)
	if tear_alive(slot.tear) then slot.tear:Remove() end
	slot.tear = nil
	slot.rolled_flags = nil
	slot.hit_gate = nil
end

local function ensure_tears(rec)
	local mode = rec.mode or "tear"
	local want_multi = math.max(1, math.floor(tonumber(rec.multi) or 1))
	if mode == "brim" then want_multi = 1 end
	rec.slots = rec.slots or {}

	rec.slots[1] = rec.slots[1] or {is_sat = false, scale_mul = 1, proj_index = 1}
	rec.slots[1].proj_index = 1
	if mode == "brim" or mode == "tech" then
		ensure_ring_for(rec, rec.slots[1], mode == "brim", 1, 1)
	else
		clear_slot_ring(rec.slots[1])
		if not tear_alive(rec.slots[1].tear) then
			rec.slots[1].tear = spawn_tear(rec, rec.slots[1], false, 1, 1)
		end
	end

	while #rec.slots < want_multi do
		local i = #rec.slots + 1
		local slot = {is_sat = true, scale_mul = 0.75, proj_index = i}
		if mode == "tech" then
			ensure_ring_for(rec, slot, false, 0.85, 0.7)
		elseif mode == "brim" then
			clear_slot(slot)
		else
			slot.tear = spawn_tear(rec, slot, true, 0.75, 0.85)
		end
		rec.slots[i] = slot
	end
	while #rec.slots > want_multi do
		clear_slot(table.remove(rec.slots))
	end
	for i, slot in ipairs(rec.slots) do
		slot.proj_index = i
	end

	local baby_specs = rec.baby_specs or {}
	rec.baby_slots = rec.baby_slots or {}
	local keep = {}
	for bi, spec in ipairs(baby_specs) do
		keep[spec.key] = true
		local slot = rec.baby_slots[spec.key]
		if not slot then
			slot = {
				is_sat = true,
				scale_mul = spec.scale_mul or 0.72,
				key = spec.key,
				follow_pos = spec.follow_pos,
				proj_index = 100 + bi,
			}
			rec.baby_slots[spec.key] = slot
		end
		slot.proj_index = 100 + bi
		slot.follow_pos = spec.follow_pos
		slot.home_pos = spec.pos
		slot.damage_mul = spec.damage_mul or 0.75
		slot.scale_mul = spec.scale_mul or slot.scale_mul or 0.72
		slot.lullaby = spec.lullaby == true
		slot.baby_bender = spec.baby_bender == true
		if mode == "brim" or mode == "tech" then
			ensure_ring_for(rec, slot, mode == "brim", slot.damage_mul, 0.65)
		else
			clear_slot_ring(slot)
			if not tear_alive(slot.tear) then
				slot.tear = spawn_tear(rec, slot, true, slot.scale_mul, slot.damage_mul)
			end
		end
	end
	for key, slot in pairs(rec.baby_slots) do
		if not keep[key] then
			clear_slot(slot)
			rec.baby_slots[key] = nil
		end
	end

	rec.tears = {}
	for i, slot in ipairs(rec.slots) do
		rec.tears[i] = slot.tear
	end
end

local function ensure_direction_slots(rec)
	rec.direction_slots = rec.direction_slots or {}
	local keep = {}
	for i, angle in ipairs(rec.direction_angles or {}) do
		local key = "volley_" .. tostring(i)
		keep[key] = true
		local slot = rec.direction_slots[key]
		if not slot then
			slot = {is_sat = true, scale_mul = 0.75, key = key, proj_index = 200 + i}
			rec.direction_slots[key] = slot
		end
		slot.symmetry_angle = angle
		slot.proj_index = 200 + i
		if rec.mode == "brim" or rec.mode == "tech" then
			ensure_ring_for(rec, slot, rec.mode == "brim", 0.85, 0.7)
		else
			clear_slot_ring(slot)
			if not tear_alive(slot.tear) then
				slot.tear = spawn_tear(rec, slot, true, slot.scale_mul, 0.85)
			end
		end
	end
	for key, slot in pairs(rec.direction_slots) do
		if not keep[key] then
			clear_slot(slot)
			rec.direction_slots[key] = nil
		end
	end
end

--- 稳定顺序：主槽 1..N，再按 key 排序的宝宝槽
local function iter_all_slots_stable(rec)
	local list = {}
	for i, slot in ipairs(rec.slots or {}) do
		slot.proj_index = i
		list[#list + 1] = slot
	end
	local keys = {}
	for k in pairs(rec.baby_slots or {}) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for i, k in ipairs(keys) do
		local slot = rec.baby_slots[k]
		slot.proj_index = 100 + i
		list[#list + 1] = slot
	end
	local direction_keys = {}
	for k in pairs(rec.direction_slots or {}) do direction_keys[#direction_keys + 1] = k end
	table.sort(direction_keys)
	for _, k in ipairs(direction_keys) do list[#list + 1] = rec.direction_slots[k] end
	return list
end

local function refresh_all(rec, force_flags)
	if not rec then return end
	local profile = rec.profile
	rec.epoch = (rec.epoch or 0) + (force_flags and 1 or 0)
	local mode = rec.mode or "tear"
	for _, slot in ipairs(iter_all_slots_stable(rec)) do
		local flags
		if force_flags or not slot.rolled_flags then
			flags = sample_slot_flags(rec, slot)
			-- 新 epoch：清空该载体上的命中去重，允许 Fire Mind 等再触发
			if tear_alive(slot.tear) then clear_hit_caches(slot.tear) end
			if laser_alive(slot.ring) then clear_hit_caches(slot.ring) end
		else
			flags = slot.rolled_flags
			if slot.baby_bender and TearFlags.TEAR_HOMING then
				flags = flags | TearFlags.TEAR_HOMING
			end
		end
		local dmg = slot.damage_mul or ((slot.is_sat and 0.85) or 1)
		if tear_alive(slot.tear) then
			apply_attrs(slot.tear, rec, flags, dmg, slot.scale_mul or 1, slot)
		end
		if laser_alive(slot.ring) then
			apply_ring_attrs(slot.ring, rec, slot, mode == "brim", dmg, slot.is_sat and 0.65 or 1)
		end
	end
end

local LUDO_KP = 0.22
local LUDO_DAMPING = 0.32
local LUDO_DEADZONE = 11
local LUDO_MID_DIST = 80

local function clamp_vec(v, max_len)
	if not v then return Vector.Zero end
	local len = v:Length()
	if len > max_len and len > 0.0001 then
		return v * (max_len / len)
	end
	return v
end

local function seek_velocity(from_pos, desired_pos, old_vel, max_speed, inherit_vel)
	from_pos = from_pos or Vector.Zero
	desired_pos = desired_pos or from_pos
	old_vel = old_vel or Vector.Zero
	max_speed = math.max(0.5, tonumber(max_speed) or 5)
	local err = desired_pos - from_pos
	local dist = err:Length()
	local desired
	if dist <= LUDO_DEADZONE then
		desired = inherit_vel or Vector.Zero
	elseif dist < LUDO_MID_DIST then
		desired = clamp_vec(err * LUDO_KP, max_speed)
	else
		desired = err:Normalized() * max_speed
	end
	return clamp_vec(old_vel * LUDO_DAMPING + desired * (1 - LUDO_DAMPING), max_speed)
end

local function resolve_desired_pos(rec, should_shoot, opts)
	local air = rec.air
	if not air or not auxi.check_all_exists(air) then
		return nil, nil
	end
	if not should_shoot then
		return air.Position, nil
	end
	local target = opts and opts.target
	if target and auxi.check_all_exists(target) then
		local main = rec.tears and rec.tears[1]
		local from = (tear_alive(main) and main.Position) or air.Position
		local to = target.Position
		local lead = Vector.Zero
		if target.Velocity then
			local dist = (to - from):Length()
			lead = target.Velocity * math.min(0.35, dist / 220)
		end
		return to + lead, target.Velocity
	end
	if opts and opts.aim_pos then
		return opts.aim_pos, nil
	end
	local aim_dir = opts and opts.aim_dir
	if aim_dir and aim_dir:Length() > 0.01 then
		local main = rec.tears and rec.tears[1]
		local from = (tear_alive(main) and main.Position) or air.Position
		return from + aim_dir:Normalized() * 40, nil
	end
	return air.Position, nil
end

local KNIFE_LOOK_ROT_BIAS = 90 -- 刀 anm2 默认尖朝上；Velocity/瞄准角 0=右，需 +90
local KNIFE_ROT_VEL_MIN = 1.0 -- 低于此速度不更新朝向，避免悬浮微振导致抽搐

local function apply_knife_sprite_rotation(td, spr, aim_dir, vel, allow_vel_update)
	if not td or not spr then return end
	local ang = nil
	if aim_dir and aim_dir:Length() > 0.01 then
		ang = aim_dir:GetAngleDegrees() + KNIFE_LOOK_ROT_BIAS
	elseif allow_vel_update and vel and vel:Length() >= KNIFE_ROT_VEL_MIN then
		ang = vel:GetAngleDegrees() + KNIFE_LOOK_ROT_BIAS
	end
	if ang then
		spr.Rotation = ang
		td[item.own_key.."knife_ang"] = ang
	elseif td[item.own_key.."knife_ang"] ~= nil then
		spr.Rotation = td[item.own_key.."knife_ang"]
	end
end

local function drive_slot(slot, vel, room, aim_dir, allow_vel_rot)
	local t = slot and slot.tear
	if not tear_alive(t) then return end
	local td = t:GetData()
	td[item.own_key.."vel"] = vel
	t.Velocity = vel
	t.FallingSpeed = 0
	t.FallingAcceleration = 0
	if t.Height ~= nil and t.Height > -10 then t.Height = -23 end
	local clamped = room:GetClampedPosition(t.Position, 8)
	if (clamped - t.Position):Length() > 0.5 then
		t.Position = clamped
	end
	if td[item.own_key.."knife_look"] then
		apply_knife_sprite_rotation(td, t:GetSprite(), aim_dir, vel, allow_vel_rot == true)
	end
	if laser_alive(slot.ring) then
		slot.ring.Position = t.Position
		slot.ring.Velocity = Vector.Zero
		slot.ring.Parent = t
		slot.ring:SetTimeout(999999)
		slot.ring.SubType = RING_SUBTYPE
	end
end

local function hit_delay_for(rec, slot)
	local d = math.max(1, math.floor(tonumber(rec.delay) or 10))
	if slot and slot.lullaby then
		d = math.max(1, math.floor(d / 2))
	end
	return d
end

--- 按 slot×目标门控真实伤害；使 rec.delay 实际影响 DPS。
local function find_slot_for_attack(attack)
	if not attack then return nil, nil end
	local d = attack:GetData()
	if not d[item.own_key.."craft"] then return nil, nil end
	local ap = d[item.own_key.."air_ptr"]
	local rec = ap and item.registry[ap]
	if not rec then return nil, nil end
	local key = d[item.own_key.."slot_key"]
	for _, slot in ipairs(iter_all_slots_stable(rec)) do
		if slot.key == key or slot.proj_index == key then
			return rec, slot
		end
		if slot.tear and GetPtrHash(slot.tear) == GetPtrHash(attack) then
			return rec, slot
		end
		if slot.ring and GetPtrHash(slot.ring) == GetPtrHash(attack) then
			return rec, slot
		end
	end
	-- 环伤害源可能是激光；锚点泪无伤
	return rec, rec.slots and rec.slots[1] or nil
end

function item.tick(air, player, craft_prof, opts)
	opts = opts or {}
	if not air or not player or not craft_prof then return 0 end
	if not auxi.check_all_exists(air) then
		item.release(air)
		return 0
	end
	local ptr = air_ptr(air)
	local d = air:GetData()
	local rec = item.registry[ptr]
	if not rec then
			rec = {
			air = air,
			air_ptr = ptr,
			player = player,
			slots = {},
				baby_slots = {},
				direction_slots = {},
			tears = {},
			epoch = 0,
			epoch_cd = 0,
		}
		item.registry[ptr] = rec
		d[item.own_key.."active"] = true
	end
	rec.air = air
	rec.player = player
	rec.profile = craft_prof
	rec.craft_uid = opts.craft_uid
	rec.damage_mul = tonumber(opts.damage_mul) or 1
	rec.damage_add = tonumber(opts.damage_add) or 0
	rec.eye_damage_mul = tonumber(opts.eye_damage_mul) or 1
	rec.shotspeed = tonumber(opts.shotspeed) or (craft_prof.stats and craft_prof.stats.shotspeed) or 1
	rec.scale = tonumber(opts.scale) or 1
	rec.luck = tonumber(opts.luck) or (craft_prof.stats and craft_prof.stats.luck) or 0
	rec.multi = math.max(1, math.floor(tonumber(opts.multi) or 1))
	rec.delay = math.max(1, tonumber(opts.delay) or 10)
	local prev_mode = rec.mode
	rec.mode = resolve_mode(craft_prof)
	if prev_mode and prev_mode ~= rec.mode then
		for _, slot in ipairs(iter_all_slots_stable(rec)) do
			clear_slot(slot)
		end
		rec.slots = {}
		rec.baby_slots = {}
		rec.direction_slots = {}
	end
	if rec.mode == "knife" then
		rec.delay = math.max(1, rec.delay * 4)
	end
	if rec.mode == "brim" or rec.mode == "tech" then
		rec.shotspeed = math.max(0.6, (tonumber(rec.shotspeed) or 1) * 0.85)
	end

	local should_shoot = opts.should_shoot == true
	-- 下方攻击节奏会先 epoch_cd - 1 再判断；这里预判同一帧的新 epoch。
	local starts_epoch = should_shoot and (tonumber(rec.epoch_cd) or 0) <= 1
	if starts_epoch then
		local base = opts.aim_dir
		if not base or base:Length() < 0.01 then base = Vector(1, 0) end
		local seed = (tonumber(opts.volley_seed) or (air.InitSeed or 0)) + (rec.epoch or 0) * 17
		local moms_eye_hit, lokis_horns_hit = CraftProfile.roll_directional_extras(craft_prof, rec.luck, seed)
		rec.direction_angles = {}
		if moms_eye_hit then rec.direction_angles[#rec.direction_angles + 1] = 180 end
		if lokis_horns_hit then
			for _, angle in ipairs({90, 180, 270}) do rec.direction_angles[#rec.direction_angles + 1] = angle end
		end
	end

	rec.baby_specs = collect_baby_satellites(air, player, craft_prof)
	ensure_tears(rec)
	ensure_direction_slots(rec)

	local max_speed = math.max(0.5, (tonumber(rec.shotspeed) or 1) * (rec.mode == "knife" and 5.5 or 5))
	local desired_pos, inherit_vel = resolve_desired_pos(rec, should_shoot, opts)
	if inherit_vel then inherit_vel = inherit_vel * 0.75 end
	local room = Game():GetRoom()
	local frame = Game():GetFrameCount()
	local main = rec.slots[1] and rec.slots[1].tear
	local aim_dir = opts and opts.aim_dir
	if should_shoot and (not aim_dir or aim_dir:Length() < 0.01) and desired_pos and tear_alive(main) then
		local d = desired_pos - main.Position
		if d:Length() > 0.01 then aim_dir = d:Normalized() end
	end
	local main_old = (tear_alive(main) and main.Velocity) or Vector.Zero
	local main_intent = Vector.Zero
	if tear_alive(main) and desired_pos then
		main_intent = seek_velocity(main.Position, desired_pos, main_old, max_speed, inherit_vel)
	end

	for i, slot in ipairs(rec.slots or {}) do
		local vel = main_intent
		if i > 1 and tear_alive(main) and tear_alive(slot.tear) then
			local n = #rec.slots - 1
			local ang = frame * 3.5 + (i - 2) * (360 / math.max(1, n))
			local orbit = Vector.FromAngle(ang) * (30 + math.min(24, n * 3))
			vel = seek_velocity(slot.tear.Position, main.Position + orbit, slot.tear.Velocity or Vector.Zero, max_speed * 1.35, main_intent)
		end
		drive_slot(slot, vel, room, should_shoot and aim_dir or nil, should_shoot)
	end

	-- 妈眼/洛基角：以飞行器为中心，将主受控泪的半径向量旋转到对称位置。
	if tear_alive(main) then
		local radius = main.Position - air.Position
		if radius:Length() < 8 then
			local aim = opts.aim_dir
			radius = (aim and aim:Length() > 0.01) and aim:Normalized() * 30 or Vector(30, 0)
		end
		for _, slot in pairs(rec.direction_slots or {}) do
			if tear_alive(slot.tear) then
				local target = air.Position + auxi.get_by_rotate(radius, slot.symmetry_angle or 0)
				local vel = seek_velocity(slot.tear.Position, target, slot.tear.Velocity or Vector.Zero, max_speed * 1.35, main_intent)
				drive_slot(slot, vel, room, should_shoot and aim_dir or nil, should_shoot)
			end
		end
	end

	for _, slot in pairs(rec.baby_slots or {}) do
		if tear_alive(slot.tear) then
			local home = slot.home_pos or air.Position
			local target = home
			if should_shoot then
				-- 宝宝卫星：从宝宝位置朝主瞄准方向伸出，而不是贴着宝宝原地转圈
				local reach = (rec.mode == "knife") and 36 or 28
				if aim_dir and aim_dir:Length() > 0.01 then
					target = home + aim_dir:Normalized() * reach
				elseif desired_pos then
					local d = desired_pos - home
					if d:Length() > 0.01 then
						target = home + d:Normalized() * reach
					end
				end
			elseif slot.home_pos then
				target = slot.tear.Position * 0.35 + slot.home_pos * 0.65
			end
			local vel = seek_velocity(slot.tear.Position, target, slot.tear.Velocity or Vector.Zero, max_speed * 1.25, main_intent)
			drive_slot(slot, vel, room, should_shoot and aim_dir or nil, should_shoot)
		end
	end

	if (frame % 8) == 0 then
		refresh_all(rec, false)
	end

	local epochs = 0
	if should_shoot then
		rec.epoch_cd = (tonumber(rec.epoch_cd) or 0) - 1
		if rec.epoch_cd <= 0 then
			rec.epoch_cd = rec.delay
			refresh_all(rec, true)
			epochs = 1
		end
	else
		rec.epoch_cd = math.min(rec.delay, (tonumber(rec.epoch_cd) or 0) + 0.25)
	end
	return epochs
end

function item.release(air)
	local ptr = air_ptr(air)
	local rec = ptr and item.registry[ptr]
	if not rec then return end
	for _, slot in ipairs(iter_all_slots_stable(rec)) do
		clear_slot(slot)
	end
	item.registry[ptr] = nil
	if air and air.GetData then
		air:GetData()[item.own_key.."active"] = nil
	end
end

function item.release_if_not_ludo(air, craft_prof)
	if not air then return end
	if craft_prof and craft_prof.weapon == 8 then return end
	if air:GetData()[item.own_key.."active"] then
		item.release(air)
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_TEAR_UPDATE,
	params = nil,
	Function = function(_, tear)
		local td = tear:GetData()
		if not td[item.own_key.."craft"] then return end
		local vel = td[item.own_key.."vel"]
		if vel then tear.Velocity = vel end
		tear.FallingSpeed = 0
		tear.FallingAcceleration = 0
		if td[item.own_key.."knife_look"] then
			-- 只回写已锁定朝向；禁止用微速度重算，否则悬浮会抖
			apply_knife_sprite_rotation(td, tear:GetSprite(), nil, nil, false)
		end
		-- 持续清 BURSTSPLIT + 重涂血泪色（避免其它 stamp 冲掉）
		if td.craft_haemo_ludo then
			if CraftProfile.clear_craft_haemo_burst_flag then
				CraftProfile.clear_craft_haemo_burst_flag(tear)
			end
			if CraftProfile.apply_haemo_ludo_color then
				CraftProfile.apply_haemo_ludo_color(tear)
			end
		end
	end,
})

-- 真实伤害门控：delay（及宝宝摇篮曲减半）控制持续载体 DPS
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = nil,
	Function = function(_, target, amount, flags, source, countdown, extra_source)
		if not target or not target:IsVulnerableEnemy() then return end
		-- RGON：激光/刀的 Source 通常是 parent，真实攻击实体在 ExtraSource。
		-- 只接受带本模块 stamp 的候选，避免 ExtraSource 存在但属于别的攻击时误归属。
		local attack = extra_source and extra_source.Entity
		local ad = attack and attack.GetData and attack:GetData() or nil
		if not (ad and ad[item.own_key.."craft"]) then
			attack = source and source.Entity
			ad = attack and attack.GetData and attack:GetData() or nil
		end
		if not attack or not ad or not ad[item.own_key.."craft"] then return end
		-- 环形态锚点泪不造成伤害
		if attack.Type == EntityType.ENTITY_TEAR and ad[item.own_key.."ring"] then
			return false
		end
		local rec, slot = find_slot_for_attack(attack)
		if not rec or not slot then return end
		local frame = Game():GetFrameCount()
		slot.hit_gate = slot.hit_gate or {}
		local tptr = GetPtrHash(target)
		local next_f = tonumber(slot.hit_gate[tptr]) or 0
		if frame < next_f then
			return false
		end
		slot.hit_gate[tptr] = frame + hit_delay_for(rec, slot)
		-- 卢多 + 血泪：本 tick 真正造成伤害时低概率爆发（继承攻击实体伤害）
		local td = ad
		local hae = td and td.craft_haemo_ludo
		if hae and CraftProfile.try_ludo_haemo_burst then
			local dir = nil
			if attack.Velocity and attack.Velocity:Length() > 0.01 then
				dir = attack.Velocity
			elseif target.Position and attack.Position then
				dir = target.Position - attack.Position
			end
			CraftProfile.try_ludo_haemo_burst(attack, target, rec.profile, rec.player, {
				luck = rec.luck,
				dir = dir,
				parent_damage = attack.CollisionDamage,
				size_mul = attack.Scale,
				mods = hae.mods,
				shot_serial = rec.epoch,
				projectile_index = slot.proj_index or 1,
			})
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		for _, rec in pairs(item.registry) do
			for _, slot in ipairs(iter_all_slots_stable(rec)) do
				clear_slot(slot)
			end
			rec.slots = {}
			rec.baby_slots = {}
			rec.tears = {}
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
	params = EntityType.ENTITY_FAMILIAR,
	Function = function(_, ent)
		if not ent then return end
		if item.registry[GetPtrHash(ent)] then
			item.release(ent)
		end
	end,
})

return item

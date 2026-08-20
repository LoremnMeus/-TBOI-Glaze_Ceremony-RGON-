-- §16.7 第一批：普通泪弹射手 adapter 注册表
-- 数值按 wiki.gg Repentance+；冷却按实测 30Hz 逻辑帧换算
local Craft_Familiar_holder = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local CraftTearColors = require("Qing_Remaster_scripts.others.craft_tear_color_data")
local CraftTearParams = require("Qing_Remaster_scripts.others.craft_tear_params_data")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Tear_Babies_holder_",
}

local H = Craft_Familiar_holder

local function merge_fire_opts(ctx, extra)
	local opts = {}
	if ctx and type(ctx.fire_opts) == "table" then
		for k, v in pairs(ctx.fire_opts) do opts[k] = v end
	end
	if type(extra) == "table" then
		for k, v in pairs(extra) do opts[k] = v end
	end
	return opts
end

local function basic_fire(adapter, ctx)
	return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, merge_fire_opts(ctx)) ~= nil
end

-- Rep：约 1.88/s → ~16f；1.36/s → ~22f；0.75s → ~23f；Mongo 0.5s → ~15f；Fate 1.4s → ~42f
local CD_FAST = 16
local CD_STD = 22
local CD_075 = 23
local CD_MONGO = 15
local CD_FATE = 42

local MAGGY_RED = Color(0.9, 0.2, 0.2, 1, 0, 0, 0)
local GISH_DARK = Color(0.15, 0.15, 0.15, 1, 0, 0, 0)
local CHARM_PURPLE = Color(1, 0, 1, 1, 0.4, 0, 0.4)
-- 圣心 / 六翼天使同色：来自 tear_color_audit 的 182
local function color_from_audit(id)
	local v = CraftTearColors.DATA and CraftTearColors.DATA[id]
	if type(v) ~= "table" then return nil end
	return Color(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8] or 0, v[9] or 0, v[10] or 0, v[11] or 0)
end
local SACRED_HEART_COLOR = color_from_audit(182)
	or Color(1.5, 2, 2, 1, 0, 0, 0)

local STEVEN_TEAR_ANM2 = "gfx/mimics/Blueprint/steven_tear.anm2"

local function apply_steven_tear(_adapter, _fam, _player, tear, _opts)
	if not tear or not tear.GetSprite then return end
	local s = tear:GetSprite()
	if not s or not s.Load then return end
	s:Load(STEVEN_TEAR_ANM2, true)
	s:Play("Idle", true)
	-- 清掉弯勺/旧紫染，避免染色盖住 Time Fcuk 贴图
	if tear.Color ~= nil then
		tear.Color = Color(1, 1, 1, 1, 0, 0, 0)
	end
	if tear.ResetSpriteScale then tear:ResetSpriteScale() end
end

local function register(variant, adapter)
	-- 默认 capability：泪弹射手吃 BFFS / 摇篮曲 / 弯勺；显式 false 可关
	if adapter.supports_bffs == nil then adapter.supports_bffs = true end
	if adapter.supports_lullaby == nil then adapter.supports_lullaby = true end
	if adapter.supports_bender == nil then adapter.supports_bender = true end
	H.register_adapter(variant, adapter)
end

register(FamiliarVariant.BROTHER_BOBBY, {
	name = "brother_bobby",
	extra_key = "brother_bobby",
	collectible = CollectibleType.COLLECTIBLE_BROTHER_BOBBY or 8,
	class = "basic_tear",
	mongo_copyable = true,
	base_cooldown = CD_FAST,
	projectile_speed = 10,
	damage = 3.5,
	head_delay = 8,
	fire = basic_fire,
})

register(FamiliarVariant.SISTER_MAGGY, {
	name = "sister_maggy",
	extra_key = "sister_maggy",
	collectible = CollectibleType.COLLECTIBLE_SISTER_MAGGY or 67,
	class = "basic_tear",
	mongo_copyable = true,
	base_cooldown = CD_STD,
	projectile_speed = 10,
	damage = 6,
	tear_color = MAGGY_RED,
	head_delay = 8,
	fire = basic_fire,
})

register(FamiliarVariant.LITTLE_STEVEN, {
	name = "little_steven",
	extra_key = "little_steven",
	collectible = CollectibleType.COLLECTIBLE_LITTLE_STEVEN or 100,
	class = "basic_tear",
	mongo_copyable = true,
	base_cooldown = CD_STD,
	projectile_speed = 10,
	damage = 3.5,
	tear_flags = TearFlags.TEAR_HOMING,
	head_delay = 8,
	apply_tear = apply_steven_tear,
	fire = basic_fire,
})

register(FamiliarVariant.GHOST_BABY, {
	name = "ghost_baby",
	extra_key = "ghost_baby",
	collectible = CollectibleType.COLLECTIBLE_GHOST_BABY or 163,
	class = "basic_tear",
	mongo_copyable = true,
	base_cooldown = CD_STD,
	projectile_speed = 10,
	damage = 3.5,
	tear_flags = TearFlags.TEAR_SPECTRAL,
	head_delay = 8,
	fire = basic_fire,
})

register(FamiliarVariant.HARLEQUIN_BABY, {
	name = "harlequin_baby",
	extra_key = "harlequin_baby",
	collectible = CollectibleType.COLLECTIBLE_HARLEQUIN_BABY or 167,
	class = "multi_tear",
	capture_multi = true,
	mongo_copyable = true,
	base_cooldown = CD_STD,
	projectile_speed = 10,
	damage = 4,
	head_delay = 8,
	-- 本变体 FireProjectile 自带 V 字；Mongo 复制时变体不同，改走夹角双发。
	fire = function(adapter, ctx)
		local fam = ctx.familiar
		if fam and fam.Variant == FamiliarVariant.HARLEQUIN_BABY then
			return basic_fire(adapter, ctx)
		end
		return H.fire_tears_angled(
			ctx.familiar, ctx.player, ctx.aim_vector, adapter, {15, -15},
			merge_fire_opts(ctx, { damage = adapter.damage or 4 })
		)
	end,
})

register(FamiliarVariant.LIL_LOKI, {
	name = "lil_loki",
	extra_key = "lil_loki",
	collectible = CollectibleType.COLLECTIBLE_LIL_LOKI or 435,
	class = "multi_tear",
	mongo_copyable = true,
	base_cooldown = CD_075,
	projectile_speed = 10,
	damage = 3.5,
	head_delay = 8,
	-- 原版为房间四向，不随瞄准旋转
	fire = function(adapter, ctx)
		local dirs = {
			Vector(1, 0),
			Vector(-1, 0),
			Vector(0, 1),
			Vector(0, -1),
		}
		local opts = merge_fire_opts(ctx)
		local any = false
		for i = 1, #dirs do
			if H.fire_basic_tear(ctx.familiar, ctx.player, dirs[i], adapter, opts) then
				any = true
			end
		end
		return any
	end,
})

register(FamiliarVariant.LITTLE_GISH, {
	name = "little_gish",
	extra_key = "little_gish",
	collectible = CollectibleType.COLLECTIBLE_LITTLE_GISH or 99,
	class = "basic_tear",
	mongo_copyable = true,
	base_cooldown = CD_STD,
	projectile_speed = 10,
	damage = 3.5,
	tear_flags = TearFlags.TEAR_SLOW | TearFlags.TEAR_GISH,
	tear_color = GISH_DARK,
	head_delay = 8,
	fire = basic_fire,
})

register(FamiliarVariant.FREEZER_BABY, {
	name = "freezer_baby",
	extra_key = "freezer_baby",
	collectible = CollectibleType.COLLECTIBLE_FREEZER_BABY or 608,
	class = "basic_tear",
	mongo_copyable = true,
	base_cooldown = CD_075,
	projectile_speed = 10,
	damage = 3.5,
	tear_flags = TearFlags.TEAR_ICE,
	tear_variant = TearVariant.ICE,
	head_delay = 8,
	fire = basic_fire,
})

register(FamiliarVariant.SERAPHIM, {
	name = "seraphim",
	extra_key = "seraphim",
	collectible = CollectibleType.COLLECTIBLE_SERAPHIM or 390,
	class = "basic_tear",
	mongo_copyable = false,
	base_cooldown = CD_STD,
	projectile_speed = 7.5, -- wiki：75% shot speed
	damage = 10,
	-- 原版六翼发圣心泪：灵体+追踪，配色与圣心一致（勿用弯勺紫）
	tear_flags = TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_HOMING,
	tear_color = SACRED_HEART_COLOR,
	head_delay = 8,
	fire = basic_fire,
})

-- 魅魔不读取瞄准输入：保留原版 AI/动画，只接管跟随位置。
register(FamiliarVariant.SUCCUBUS, {
	name = "succubus",
	extra_key = "succubus",
	collectible = CollectibleType.COLLECTIBLE_SUCCUBUS or 417,
	class = "passive_aura",
	control_mode = "move_only",
	mongo_copyable = false,
	supports_bffs = false,
	supports_lullaby = false,
	supports_bender = false,
	always_spawn_synthetic = true,
	spawn = function(adapter, air, player)
		return Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.SUCCUBUS, 0,
			air.Position, Vector(0, 0), player)
	end,
})

-- ---------- Rotten Baby：一只归属本 adapter 的蓝苍蝇 ----------
-- 性质：蓝苍蝇 InitSeed 在小退重进后会变，不可靠；续局 userdata 失效时改认领随机普通蓝苍蝇。
local FLY_VARIANT = FamiliarVariant.BLUE_FLY or 43
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
-- POST_GAME_STARTED(continued) 后短时打开；仅用于 InitSeed 对不上时的随机认领
local fly_reclaim_until_frame = -1

local function fly_slot_key(slot)
	return item.own_key .. "fly_" .. tostring(slot or "rotten")
end

local function write_fly_ref(d, slot, ent, craft_uid, fam)
	if not d then return end
	if not ent then
		d[fly_slot_key(slot)] = nil
		return
	end
	d[fly_slot_key(slot)] = {
		entity = ent,
		init_seed = ent.InitSeed,
		craft_uid = craft_uid,
		fam_ptr = fam and GetPtrHash(fam) or nil,
	}
end

local function read_fly_ref(d, slot)
	return d and d[fly_slot_key(slot)]
end

local function fly_owned_by(ent, player)
	if not ent or not player then return false end
	local p = ent.Player or (ent.SpawnerEntity and ent.SpawnerEntity:ToPlayer())
	return p and GetPtrHash(p) == GetPtrHash(player)
end

local function list_ordinary_blue_flies(player, exclude_fam)
	local claimed = {}
	for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, -1, -1, false, false)) do
		if not exclude_fam or GetPtrHash(fam) ~= GetPtrHash(exclude_fam) then
			local d = fam:GetData()
			if d then
				for _, slot in ipairs({"rotten", "mongo"}) do
					local ref = read_fly_ref(d, slot)
					if ref then
						if ref.entity and auxi.check_all_exists(ref.entity) then
							claimed[GetPtrHash(ref.entity)] = true
						elseif ref.init_seed then
							claimed["seed:" .. tostring(ref.init_seed)] = true
						end
					end
				end
			end
		end
	end
	local out = {}
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FLY_VARIANT, -1, false, false)) do
		-- 普通蓝苍蝇：SubType 0；跳过已被其它 Rotten/Mongo 槽占用的
		if fly_owned_by(ent, player) and (ent.SubType or 0) == 0
			and not claimed[GetPtrHash(ent)]
			and not claimed["seed:" .. tostring(ent.InitSeed)] then
			out[#out + 1] = ent
		end
	end
	return out
end

local function pick_random_fly(fam, candidates)
	if not candidates or #candidates == 0 then return nil end
	local rng = fam and fam.GetDropRNG and fam:GetDropRNG()
	local idx = 1
	if rng then
		idx = rng:RandomInt(#candidates) + 1
	else
		idx = (((fam and fam.InitSeed) or 0) % #candidates) + 1
	end
	return candidates[idx]
end

local function resolve_owned_fly(fam, player, craft_uid, slot)
	local d = fam and fam:GetData()
	if not d then return nil end
	local ref = read_fly_ref(d, slot)
	local frame = Game():GetFrameCount() or 0
	local in_reclaim = frame <= fly_reclaim_until_frame

	-- 小退续局后 GetData 可能已空：窗口内直接认领场上普通苍蝇，避免再招一只
	if not ref then
		if in_reclaim then
			local pick = pick_random_fly(fam, list_ordinary_blue_flies(player, fam))
			if pick then
				write_fly_ref(d, slot, pick, craft_uid, fam)
				return pick
			end
		end
		return nil
	end

	if ref.entity and auxi.check_all_exists(ref.entity) then
		return ref.entity
	end

	-- 局内 userdata 偶发失效时 InitSeed 仍可能对上；小退重进后 InitSeed 会变，不可依赖。
	if ref.init_seed then
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FLY_VARIANT, -1, false, false)) do
			if ent.InitSeed == ref.init_seed and fly_owned_by(ent, player) then
				write_fly_ref(d, slot, ent, craft_uid or ref.craft_uid, fam)
				return ent
			end
		end
	end

	-- 小退续局窗口：InitSeed 对不上则随机认领一只普通蓝苍蝇
	if in_reclaim then
		local pick = pick_random_fly(fam, list_ordinary_blue_flies(player, fam))
		if pick then
			write_fly_ref(d, slot, pick, craft_uid or ref.craft_uid, fam)
			return pick
		end
	end

	-- 正常死亡或无可认领苍蝇：清槽，允许再招
	write_fly_ref(d, slot, nil)
	return nil
end

local function spawn_owned_fly(fam, player, craft_uid, slot)
	if not fam or not player or not player.AddBlueFlies then return nil end
	local fly = player:AddBlueFlies(1, fam.Position, player)
	if not fly then return nil end
	write_fly_ref(fam:GetData(), slot, fly, craft_uid, fam)
	return fly
end

local function clear_fly_slots_matching(ent)
	if not ent then return end
	local seed = ent.InitSeed
	local ptr = GetPtrHash(ent)
	for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, -1, -1, false, false)) do
		local d = fam:GetData()
		if d then
			for _, slot in ipairs({"rotten", "mongo"}) do
				local ref = read_fly_ref(d, slot)
				if ref and ((ref.init_seed and ref.init_seed == seed)
					or (ref.entity and GetPtrHash(ref.entity) == ptr)) then
					write_fly_ref(d, slot, nil)
					d[item.own_key .. "had_fly_" .. slot] = nil
				end
			end
		end
	end
end

local function rotten_fire(adapter, ctx, slot)
	slot = slot or (ctx and ctx.fly_slot) or "rotten"
	local fam = ctx.familiar
	local player = ctx.player
	local bind = ctx.bind
	local craft_uid = bind and bind.craft_uid
	if resolve_owned_fly(fam, player, craft_uid, slot) then
		return false
	end
	return spawn_owned_fly(fam, player, craft_uid, slot) ~= nil
end

register(FamiliarVariant.ROTTEN_BABY, {
	name = "rotten_baby",
	extra_key = "rotten_baby",
	collectible = CollectibleType.COLLECTIBLE_ROTTEN_BABY or 268,
	class = "blue_fly",
	mongo_copyable = true,
	supports_bender = false,
	base_cooldown = CD_FAST,
	head_delay = 8,
	pause_cooldown = function(adapter, fam, player, bind)
		local craft_uid = bind and bind.craft_uid
		return resolve_owned_fly(fam, player, craft_uid, "rotten") ~= nil
	end,
	update = function(adapter, ctx)
		local fam = ctx.familiar
		local player = ctx.player
		local bind = ctx.bind
		local d = fam and fam:GetData()
		if not d then return end
		local craft_uid = bind and bind.craft_uid
		local fly = resolve_owned_fly(fam, player, craft_uid, "rotten")
		local cd_key = H.own_key .. "craft_fire_cooldown"
		if fly then
			d[cd_key] = math.max(1, tonumber(d[cd_key]) or 1)
			d[item.own_key .. "had_fly_rotten"] = true
		elseif d[item.own_key .. "had_fly_rotten"] then
			d[cd_key] = 0
			d[item.own_key .. "had_fly_rotten"] = nil
		end
	end,
	release = function(adapter, fam, bind, _reason)
		if fam and fam.GetData then
			write_fly_ref(fam:GetData(), "rotten", nil)
			fam:GetData()[item.own_key .. "had_fly_rotten"] = nil
		end
	end,
	fire = function(adapter, ctx)
		local slot = (ctx.fly_slot) or "rotten"
		return rotten_fire(adapter, ctx, slot)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function(_, is_continued)
		if is_continued then
			-- 约 2 秒窗口：让已绑定 Rotten/Mongo 有机会认领续局后的苍蝇
			fly_reclaim_until_frame = (Game():GetFrameCount() or 0) + 60
		else
			fly_reclaim_until_frame = -1
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
	params = EntityType.ENTITY_FAMILIAR,
	Function = function(_, ent)
		if not ent or ent.Variant ~= FLY_VARIANT then return end
		clear_fly_slots_matching(ent)
	end,
})

-- ---------- Rainbow：十种等权模式（完整弹体参数）----------
local function rainbow_mode_opts(ctx, extra)
	return merge_fire_opts(ctx, extra)
end

local RAINBOW_MODES = {
	-- 1 短射程血泪 3.00
	function(adapter, ctx)
		return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, rainbow_mode_opts(ctx, {
			damage = 3,
			tear_variant = TearVariant.BLOOD,
			projectile_speed = 10,
			short_range = true,
		})) ~= nil
	end,
	-- 2 Sister Maggy：红泪 6.00
	function(adapter, ctx)
		return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, rainbow_mode_opts(ctx, {
			damage = 6,
			tear_color = MAGGY_RED,
		})) ~= nil
	end,
	-- 3 Harlequin：V 字双发，各 3.50（捕获 FireProjectile 多发，不叠角）
	function(adapter, ctx)
		return H.fire_tears_angled(ctx.familiar, ctx.player, ctx.aim_vector, adapter, {15, -15}, rainbow_mode_opts(ctx, {
			damage = 3.5,
		}))
	end,
	-- 4 Multidimensional：紫魅惑 3.50
	function(adapter, ctx)
		return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, rainbow_mode_opts(ctx, {
			damage = 3.5,
			tear_flags = TearFlags.TEAR_CHARM,
			tear_color = CHARM_PURPLE,
		})) ~= nil
	end,
	-- 5 Little Gish
	function(adapter, ctx)
		return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, rainbow_mode_opts(ctx, {
			damage = 3.5,
			tear_flags = TearFlags.TEAR_SLOW | TearFlags.TEAR_GISH,
			tear_color = GISH_DARK,
		})) ~= nil
	end,
	-- 6 Ghost Baby
	function(adapter, ctx)
		return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, rainbow_mode_opts(ctx, {
			damage = 3.5,
			tear_flags = TearFlags.TEAR_SPECTRAL,
		})) ~= nil
	end,
	-- 7 Little Steven：追踪长射程 + Time Fcuk 外观
	function(adapter, ctx)
		return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, rainbow_mode_opts(ctx, {
			damage = 3.5,
			tear_flags = TearFlags.TEAR_HOMING,
			projectile_speed = 12,
			apply_tear = apply_steven_tear,
			skip_bender_color = true,
		})) ~= nil
	end,
	-- 8 Sacred Heart：灵体+追踪 + 圣心外观色
	function(adapter, ctx)
		return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, rainbow_mode_opts(ctx, {
			damage = 3.5,
			tear_flags = TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_HOMING,
			projectile_speed = 12,
			tear_color = SACRED_HEART_COLOR,
			skip_bender_color = true,
		})) ~= nil
	end,
	-- 9 Meat：血泪 4.00
	function(adapter, ctx)
		return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, rainbow_mode_opts(ctx, {
			damage = 4,
			tear_variant = TearVariant.BLOOD,
		})) ~= nil
	end,
	-- 10 大血泪 5.00
	function(adapter, ctx)
		return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, rainbow_mode_opts(ctx, {
			damage = 5,
			tear_variant = TearVariant.BLOOD,
			tear_scale = 1.5,
		})) ~= nil
	end,
}

register(FamiliarVariant.RAINBOW_BABY, {
	name = "rainbow_baby",
	extra_key = "rainbow_baby",
	collectible = CollectibleType.COLLECTIBLE_RAINBOW_BABY or 174,
	class = "multi_tear",
	mongo_copyable = true,
	base_cooldown = CD_STD,
	projectile_speed = 10,
	damage = 3.5,
	head_delay = 8,
	fire = function(adapter, ctx)
		local fam = ctx.familiar
		local rng = fam and fam.GetDropRNG and fam:GetDropRNG()
		local idx = 1
		if rng then
			idx = rng:RandomInt(#RAINBOW_MODES) + 1
		else
			local seed = (fam and fam.InitSeed or 0) + (Game():GetFrameCount() or 0)
			idx = (seed % #RAINBOW_MODES) + 1
		end
		local mode = RAINBOW_MODES[idx]
		return mode and mode(adapter, ctx) or false
	end,
})

-- ---------- Fate's Reward：Flight 档案伤 / BFFS×4 ----------
register(FamiliarVariant.FATES_REWARD, {
	name = "fates_reward",
	extra_key = "fates_reward",
	collectible = CollectibleType.COLLECTIBLE_FATES_REWARD or 361,
	class = "basic_tear",
	mongo_copyable = false,
	bffs_damage_mul = 4,
	base_cooldown = CD_FATE,
	projectile_speed = 10,
	damage = 3.5,
	head_delay = 8,
	fire = function(adapter, ctx)
		local fam = ctx.familiar
		local player = ctx.player
		local bind = ctx.bind
		local profile = bind and bind.profile
		local opts = merge_fire_opts(ctx, { bffs_damage_mul = 4 })
		if profile and profile.stats then
			opts.damage = profile.stats.damage
			opts.projectile_speed = (tonumber(profile.stats.shotspeed) or 1) * 10
			local luck = tonumber(profile.stats.luck) or 0
			local flags = CraftProfile.sample_tear_flags(
				player, luck, profile, WeaponType.WEAPON_TEARS,
				{
					shot_serial = tonumber(fam and fam:GetData()[H.own_key .. "craft_fire_cooldown"]) or 0,
					craft_uid = bind and bind.craft_uid,
					projectile_index = 1,
					init_seed = fam and fam.InitSeed,
				}
			)
			opts.tear_flags = flags
			local tear = H.fire_basic_tear(fam, player, ctx.aim_vector, adapter, opts)
			if tear and flags then
				CraftTearColors.apply(tear, profile.counts, flags, CraftProfile.TEAR_EFFECTS)
				CraftTearParams.apply(tear, profile.counts, flags, CraftProfile.TEAR_EFFECTS, {
					range = profile.stats.range,
					shotspeed = profile.stats.shotspeed,
				})
			end
			return tear ~= nil
		end
		return H.fire_basic_tear(fam, player, ctx.aim_vector, adapter, opts) ~= nil
	end,
})

-- ---------- Mongo：复制同配方 mongo_copyable adapter ----------
local function mongo_candidates(profile)
	local out = {}
	local extras = profile and profile.extras or {}
	-- 稳定顺序：按 collectible id
	local rows = {}
	for _, adapter in pairs(H.ADAPTERS) do
		if adapter.mongo_copyable == true and adapter.extra_key and extras[adapter.extra_key] == true
			and adapter.extra_key ~= "mongo_baby" then
			rows[#rows + 1] = adapter
		end
	end
	table.sort(rows, function(a, b)
		local ca = tonumber(a.collectible) or 0
		local cb = tonumber(b.collectible) or 0
		if ca ~= cb then return ca < cb end
		return tostring(a.extra_key) < tostring(b.extra_key)
	end)
	return rows
end

register(FamiliarVariant.MONGO_BABY, {
	name = "mongo_baby",
	extra_key = "mongo_baby",
	collectible = CollectibleType.COLLECTIBLE_MONGO_BABY or 322,
	class = "meta_copy",
	mongo_copyable = false,
	base_cooldown = CD_MONGO,
	projectile_speed = 10,
	damage = 3.5,
	head_delay = 8,
	fire = function(adapter, ctx)
		local bind = ctx.bind
		local list = mongo_candidates(bind and bind.profile)
		local d = ctx.familiar and ctx.familiar:GetData()
		local craft_uid = bind and bind.craft_uid
		if #list == 0 then
			return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, merge_fire_opts(ctx, {
				damage = 3.5,
			})) ~= nil
		end
		local start = 1
		if d then
			start = ((tonumber(d[item.own_key .. "mongo_idx"]) or 0) % #list) + 1
		end
		for offset = 0, #list - 1 do
			local idx = ((start - 1 + offset) % #list) + 1
			local src = list[idx]
			if src then
				-- Rotten 苍蝇仍存活：跳过该候选，避免 Mongo CD=0 空转刷帧
				if src.extra_key == "rotten_baby"
					and resolve_owned_fly(ctx.familiar, ctx.player, craft_uid, "mongo") then
					-- skip
				elseif src.fire then
					local copy_ctx = {
						familiar = ctx.familiar,
						player = ctx.player,
						air = ctx.air,
						bind = ctx.bind,
						intent = ctx.intent,
						aim_vector = ctx.aim_vector,
						holder = ctx.holder,
						fire_opts = merge_fire_opts(ctx, { damage_mul = 2 }),
						fly_slot = "mongo",
						force_rotten = true,
					}
					local ok, ret = pcall(src.fire, src, copy_ctx)
					if ok and ret ~= false then
						if d then d[item.own_key .. "mongo_idx"] = idx end
						return true
					end
				else
					local tear = H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, merge_fire_opts(ctx, {
						damage = src.damage or 3.5,
						damage_mul = 2,
						tear_flags = src.tear_flags,
						tear_color = src.tear_color,
						tear_variant = src.tear_variant,
						apply_tear = src.apply_tear,
						projectile_speed = src.projectile_speed,
					}))
					if tear then
						if d then d[item.own_key .. "mongo_idx"] = idx end
						return true
					end
				end
			end
		end
		-- 全部忙或失败：普通泪兜底，仍推进循环下标
		if d then d[item.own_key .. "mongo_idx"] = start end
		return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, merge_fire_opts(ctx, {
			damage = 3.5,
		})) ~= nil
	end,
})

function item.sync_air_flight(air, player, profile)
	return H.sync_air_flight(air, player, profile)
end

function item.release_for_air(air)
	return H.release_for_air(air)
end

return item

local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
local SpriteTrails = require("Qing_Remaster_scripts.others.sprite_trail_presets")
local tear_snapshot = require("Qing_Remaster_scripts.auxiliary.tear_snapshot")

local item = {
	myToCall = {},
	ToCall = {},
	pre_ToCall = {},
	entity = enums.Items.Crown_of_the_glaze,
	own_key = "Item_Glaze_Crown",
	max_stacks = 5,

	damage_per_stack = 0.3,
	luck_per_stack = 1,

	refract_unlock_stack = 3,
	refract_chance = 0.50,
	-- 4 companion × 0.18 ≈ 旧 2×0.35 的平均额外收益
	refract_damage = 0.18,
	-- Ludo：一轮时长上限约 1s（无新 Once 时到期解绑）；新一轮 Once 到来时也会先解绑
	glaze_core_ludo_ttl = 30,

	shatter_damage = 0.35,
	shatter_base_count = 2,
	shatter_per_stack = 2,
	full_shatter_bonus = 2,

	shatter_drop_chance = 0.25,

	crown_spawn_mul = 2.0,

	crown_anm2 = "gfx/mimics/Glaze Crown/crown_of_glaze.anm2",
	shard_anm2 = "gfx/mimics/Glaze Crown/glaze_shard.anm2",
	-- Float* 层帧：Pivot(16,24) 画在 Render 点 + 该偏移；粒子同 Pivot，须对准此点而非角色头顶
	CROWN_ANM2_OFFSET = Vector(0, -30),
	upgrade_fly_frames = 11, -- compat alias → regular_upgrade_fly_frames
	regular_upgrade_fly_frames = 11,
	complete_upgrade_fly_frames = 15,
	upgrade_pulse_frames = 10,
	awaken_frames = 12,
	complete_frames = 30,
	-- 王冠本体裂解闪白（与碎冠 Flash 阶段分开；在 Crack 瞬间触发）
	crown_crack_flash_frames = 1,
	-- 碎冠演出（POST_UPDATE 30Hz）：recoil → crack → disassemble → release → freeze → flash → break/burst
	shatter_recoil_frames = 7,
	shatter_crack_frames = 2,
	shatter_disassemble_frames = 4,
	shatter_release_frames = 2,
	-- legacy: 正式流程已跳过 eject（保留字段兼容）
	shatter_eject_frames = 0,
	-- compat alias（旧 Debug / 注释）；正式状态机用 crack
	shatter_fracture_frames = 2,
	shatter_freeze_frames = 12,
	shatter_flash_frames = 3,
	shatter_break_frames = 1,
	shatter_trail_fade_frames = 4,
}

-- 材质三态：结构由 FloatN 表达，shader 只负责琉璃感
item.CROWN_ROLL = {
	dormant = {
		alpha = 0.48,
		speed = 0.30,
		density = 1.25,
		gray = 0.30,
		bend = 0.08,
		contrast = 0.38,
		angle = 25,
	},
	awakened = {
		alpha = 0.70,
		speed = 0.55,
		density = 1.80,
		gray = 0.42,
		bend = 0.12,
		contrast = 0.46,
		angle = 35,
	},
	complete = {
		alpha = 0.90,
		speed = 0.80,
		density = 2.30,
		gray = 0.52,
		bend = 0.16,
		contrast = 0.54,
		angle = 45,
	},
}

item.SHARD_ROLL = {
	alpha = 0.85,
	speed = 1.10,
	density = 2.60,
	gray = 0.50,
	bend = 0.12,
	contrast = 0.42,
	angle = 15,
	lum_low = 0.08,
	lum_high = 0.92,
}

local PITCH_BY_STACK = {0.96, 1.03, 1.10, 1.17, 1.27}

-- 飞入方向：左上45 / 右上45 / 正上 / 左上22.5 / 右上22.5
local FLY_DIRS = {
	Vector(-1, -1):Normalized(),
	Vector(1, -1):Normalized(),
	Vector(0, -1),
	Vector(-math.sin(math.rad(22.5)), -math.cos(math.rad(22.5))),
	Vector(math.sin(math.rad(22.5)), -math.cos(math.rad(22.5))),
}

auxi.add_to_seija(item.entity)

local skip_hurt_flags = DamageFlag.DAMAGE_FAKE
	| DamageFlag.DAMAGE_DEVIL
	| DamageFlag.DAMAGE_IV_BAG
	| DamageFlag.DAMAGE_CURSED_DOOR
	| DamageFlag.DAMAGE_NO_PENALTIES
	| DamageFlag.DAMAGE_CLONES

local upgrade_fx = {}
local shatter_fx = {}
local shatter_seq = 0

local function world_to_entity_render(world, offset)
	local pos = Isaac.WorldToScreen(world)
	if offset then
		pos = pos + offset
		local room = Game():GetRoom()
		if room and room.GetRenderScrollOffset then
			pos = pos - room:GetRenderScrollOffset()
		end
	end
	return pos
end

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

function item.force_seija()
	local debug = debug_root()
	return debug and debug.GlazeCrownForceSeija == true
end

function item.is_seija(player)
	if item.force_seija() then return true end
	return player and auxi.should_do_Seija(player) == true
end

local function mix_seed(seed, salt)
	seed = (tonumber(seed) or 1) + (tonumber(salt) or 0)
	seed = seed % 4294967296
	seed = seed ~ math.floor(seed / 65536)
	seed = (seed * 2127912214) % 4294967296
	seed = seed ~ math.floor(seed / 32768)
	if seed == 0 then seed = 1 end
	return seed
end

local function make_rng(seed, salt)
	local rng = RNG()
	rng:SetSeed(mix_seed(seed, salt), 35)
	return rng
end

local function player_key(player)
	if not player then return nil end
	return player:GetData().__Index or player.InitSeed
end

local function stack_store()
	save.elses = save.elses or {}
	save.elses[item.own_key.."stacks"] = save.elses[item.own_key.."stacks"] or {}
	return save.elses[item.own_key.."stacks"]
end

function item.has_item(player)
	return auxi.has_and_have_coll(player, item.entity)
end

function item.has_any()
	for i = 0, Game():GetNumPlayers() - 1 do
		if item.has_item(Game():GetPlayer(i)) then return true end
	end
	return false
end

function item.crown_copies()
	local n = 0
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player then n = n + (player:GetCollectibleNum(item.entity) or 0) end
	end
	return n
end

function item.any_seija()
	if item.force_seija() then return true end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if item.has_item(player) and auxi.should_do_Seija(player) then return true end
	end
	return false
end

function item.any_complete()
	for i = 0, Game():GetNumPlayers() - 1 do
		if item.should_empower(Game():GetPlayer(i)) then return true end
	end
	return false
end

function item.get_spawn_mul()
	if not item.has_any() then return 1 end
	local n = item.crown_copies()
	if n < 1 then n = 1 end
	local mul = item.crown_spawn_mul or 2.0
	if n >= 2 then mul = 2.5 end
	if n >= 3 then mul = 3.0 end
	-- Seija：不压生成倍率；惩罚改为碎冠时每层额外半心（见 crown_seija_shatter_penalty.md）
	return mul
end

function item.roll_convert(rng, denom)
	denom = tonumber(denom) or 40
	if denom < 1 then denom = 1 end
	rng = auxi.rng_for_sake(rng)
	if not rng then return false end
	local chance = item.get_spawn_mul() / denom
	if chance > 0.25 then chance = 0.25 end
	return rng:RandomInt(10000) < math.floor(chance * 10000 + 0.5)
end

function item.get_stacks(player)
	if not player then return 0 end
	local n = tonumber(stack_store()[player_key(player)]) or 0
	if n < 0 then n = 0 elseif n > item.max_stacks then n = item.max_stacks end
	return n
end

function item.set_stacks(player, n)
	if not player then return 0 end
	n = math.floor(tonumber(n) or 0)
	if n < 0 then n = 0 elseif n > item.max_stacks then n = item.max_stacks end
	local prev = item.get_stacks(player)
	stack_store()[player_key(player)] = n
	if prev ~= n then
		player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_LUCK)
		player:GetData().should_evaluate_on_update_once = true
		player:GetData()[item.own_key.."sprite_dirty"] = true
	end
	return n
end

function item.is_complete(player)
	return item.get_stacks(player) >= item.max_stacks
end

function item.should_empower(player)
	return item.has_item(player) and item.is_complete(player)
end

item.IsGlassCrownComplete = item.is_complete

local function crown_visual_state(stacks)
	stacks = tonumber(stacks) or 0
	if stacks >= item.max_stacks then
		return "complete"
	elseif stacks >= item.refract_unlock_stack then
		return "awakened"
	end
	return "dormant"
end

function item.get_crown_render_position(player, offset)
	-- MC_POST_PLAYER_RENDER：W2S 已是窗口坐标；回调 offset 在大房间会再带
	-- GetRenderScrollOffset，必须加 offset 后再减 scroll，否则王冠漂离角色。
	-- 见 codex_work/notes/entity_render_scroll_offset_pitfalls.md
	local pos = Isaac.WorldToScreen(player.Position + player_offset_holder.GetPlayerOffset(player))
	if offset then
		pos = pos + offset
		local room = Game():GetRoom()
		if room and room.GetRenderScrollOffset then
			pos = pos - room:GetRenderScrollOffset()
		end
	end
	local recoil_y = tonumber(player:GetData()[item.own_key.."shatter_recoil_y"]) or 0
	if recoil_y ~= 0 then
		pos = pos + Vector(0, recoil_y)
	end
	return pos
end

-- 王冠 / Halo / 辉片层的共同 Pivot 落点（屏幕渲染坐标）
function item.get_crown_pivot_screen(player, offset)
	return item.get_crown_render_position(player, offset) + item.CROWN_ANM2_OFFSET
end

--- HaloPulse 层自带 CROWN_ANM2_OFFSET；Scale 会连内部 offset 一起缩放。
--- 反解 RenderOrigin，使可见中心始终锁在 Crown Pivot（+ optional lift）。
local function get_scaled_halo_render_origin(player, offset, scale, extra_lift)
	scale = tonumber(scale) or 1
	extra_lift = tonumber(extra_lift) or 0
	local desired_pivot =
		item.get_crown_pivot_screen(player, offset)
		+ Vector(0, extra_lift)
	local anm2_off = item.CROWN_ANM2_OFFSET
	return desired_pivot - Vector(anm2_off.X * scale, anm2_off.Y * scale)
end

-- 碎冠弹片等世界逻辑用：尽量是 Pivot 的真逆变换
function item.get_crown_world_position(player)
	if not player then return Vector(0, 0) end
	local screen = item.get_crown_pivot_screen(player, nil)
	if Isaac.RenderToWorld then
		return Isaac.RenderToWorld(screen)
	end
	return player.Position + player_offset_holder.GetPlayerOffset(player) + Vector(0, -28)
end

local function smoothstep(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

local function pulse_scale(age, duration)
	duration = duration or item.upgrade_pulse_frames
	if age < 0 or age >= duration then return 1 end
	if age < 3 then
		return 1.00 + 0.10 * (age / 3)
	elseif age < 6 then
		return 1.10 + (0.97 - 1.10) * ((age - 3) / 3)
	else
		return 0.97 + (1.00 - 0.97) * ((age - 6) / math.max(1, duration - 6))
	end
end

-- 统一琉璃辉片材质：只在创建时 apply shader，每帧只改 Color
local function glaze_particle_seed(player, stack_index)
	local base = (player and player.InitSeed) or 1
	local mixed = ((base + (stack_index or 0) * 137) % 1000) / 1000
	return mixed
end

local function apply_glaze_particle_shader(spr, seed)
	if not spr or not REPENTOGON then return end
	temp_hud.apply_sprite_shader(spr, temp_hud.RAINBOW_ROLL_SHADER)
	item.paint_glaze_shard_sprite(spr, seed, "upgrade")
end

-- 碎冠移动期统一材质 speed（与 lock_shatter_shader_phase 一致）
local SHATTER_MOVE_SPEED = 0.68

function item.paint_glaze_shard_sprite(spr, seed, phase, opts)
	if not spr or not REPENTOGON then return end
	opts = opts or {}
	local cfg = item.SHARD_ROLL
	local alpha = cfg.alpha
	local speed = cfg.speed
	local gray = cfg.gray
	local contrast = cfg.contrast
	phase = phase or "flight"
	if phase == "upgrade" then
		alpha = 0.95
		speed = cfg.speed * 1.15
		gray = math.min(1, cfg.gray + 0.05)
	elseif phase == "shatter_move" then
		-- Disassemble / Release：连续滚色，略慢于旧 scatter 1.10
		alpha = 0.85
		speed = SHATTER_MOVE_SPEED
		gray = 0.50
		contrast = 0.42
	elseif phase == "scatter" or phase == "crack" then
		-- Debris / legacy；Primary 碎冠链改用 shatter_move
		alpha = 0.85
		speed = 1.10
	elseif phase == "freeze" then
		-- 与 shatter_move 同参起步；后半段仅提亮，phase 由 opts.phase_override 锁死
		local buildup = math.max(0, math.min(1, tonumber(opts.buildup) or 0))
		alpha = 0.85 + 0.10 * buildup
		speed = 0
		gray = 0.50 + 0.16 * buildup
		contrast = 0.42 + 0.10 * buildup
	elseif phase == "flash" then
		local step = math.max(1, math.min(3, math.floor(tonumber(opts.flash_step) or 1)))
		alpha = 1.0
		speed = 0
		if step <= 1 then
			gray = 0.76
			contrast = 0.58
		elseif step == 2 then
			gray = 0.86
			contrast = 0.63
		else
			gray = 0.92
			contrast = 0.68
		end
	elseif phase == "break" then
		alpha = tonumber(opts.alpha) or 0.4
		speed = 0
		gray = 0.92
		contrast = 0.68
	elseif phase == "glaze_core" then
		-- 主泪琉璃核：比 companion 更稳、更慢、对比更低
		alpha = 0.88
		speed = 0.28
		gray = 0.30
		contrast = 0.18
	else
		-- flight / tear
		alpha = cfg.alpha
		speed = cfg.speed
	end
	-- 可选覆盖/乘算（Crack Debris 淡出等）；向后兼容
	if opts.alpha ~= nil and phase ~= "break" then
		alpha = tonumber(opts.alpha) or alpha
	end
	if opts.alpha_mul ~= nil then
		alpha = alpha * (tonumber(opts.alpha_mul) or 1)
	end
	if opts.phase_override ~= nil and temp_hud.make_rainbow_roll_color_from_phase then
		spr.Color = temp_hud.make_rainbow_roll_color_from_phase(
			alpha,
			opts.phase_override,
			cfg.lum_low,
			cfg.lum_high,
			cfg.angle,
			cfg.density,
			gray,
			cfg.bend,
			contrast
		)
	else
		spr.Color = temp_hud.make_rainbow_roll_color(
			alpha,
			seed or 0.37,
			cfg.lum_low,
			cfg.lum_high,
			cfg.angle,
			cfg.density,
			speed,
			1,
			gray,
			cfg.bend,
			contrast,
			false
		)
	end
end

local function make_particle_sprite(stack_index)
	local spr = Sprite()
	spr:Load(item.crown_anm2, true)
	spr:Play("Particle" .. tostring(stack_index), true)
	return spr
end

local function begin_upgrade_fx(player, new_stacks, _source_position)
	local pk = player_key(player)
	local dir = FLY_DIRS[new_stacks] or Vector(0, -1)
	local seed = glaze_particle_seed(player, new_stacks)
	local spr = make_particle_sprite(new_stacks)
	apply_glaze_particle_shader(spr, seed)
	local duration = item.regular_upgrade_fly_frames or item.upgrade_fly_frames
	if new_stacks >= item.max_stacks then
		duration = item.complete_upgrade_fly_frames or duration
	end
	upgrade_fx[#upgrade_fx + 1] = {
		player_key = pk,
		player = player,
		new_stacks = new_stacks,
		age = 0,
		duration = duration,
		start_offset = dir * 36,
		spr = spr,
		roll_seed = seed,
		applied = false,
	}
end

local function finish_upgrade_embed(player, new_stacks)
	item.set_stacks(player, new_stacks)
	local d = player:GetData()
	local pitch = PITCH_BY_STACK[new_stacks] or 1.1
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_STONE_IMPACT, 0.45, pitch, false, 0, 2)
	if new_stacks >= item.max_stacks then
		-- 第五片：只跑 Complete，禁用普通 Pulse / Awaken 叠乘
		d[item.own_key.."pulse"] = nil
		d[item.own_key.."pulse_age"] = nil
		d[item.own_key.."awaken"] = nil
		d[item.own_key.."awaken_age"] = nil
		d[item.own_key.."awaken_spr"] = nil
		d[item.own_key.."complete"] = item.complete_frames
		d[item.own_key.."complete_age"] = 0
		d[item.own_key.."complete_holy_played"] = false
		d[item.own_key.."complete_halo_spr"] = nil
	else
		d[item.own_key.."pulse"] = item.upgrade_pulse_frames
		d[item.own_key.."pulse_age"] = 0
		if new_stacks == item.refract_unlock_stack then
			d[item.own_key.."awaken"] = item.awaken_frames
			d[item.own_key.."awaken_age"] = 0
		end
	end
end

function item.notify_pickup(player, source_position)
	if not item.has_item(player) then return false end
	local n = item.get_stacks(player)
	if n >= item.max_stacks then return false end
	begin_upgrade_fx(player, n + 1, source_position)
	return true
end

function item.debug_set_stacks(player, n)
	if not player then return end
	item.set_stacks(player, n)
	player:GetData()[item.own_key.."sprite_dirty"] = true
end

function item.debug_trigger_upgrade_vfx(player)
	if not item.has_item(player) then return end
	local n = item.get_stacks(player)
	if n >= item.max_stacks then return end
	begin_upgrade_fx(player, n + 1, nil)
end

function item.debug_trigger_shatter_vfx(player)
	if not item.has_item(player) then return end
	if item.get_stacks(player) <= 0 then
		item.set_stacks(player, 3)
	end
	item.shatter(player)
end

function item.debug_trigger_shatter_at(player, stacks)
	if not player then return end
	stacks = math.max(1, math.min(item.max_stacks, tonumber(stacks) or 1))
	if not item.has_item(player) then return end
	item.set_stacks(player, stacks)
	item.shatter(player)
end

function item.debug_trigger_full_crown_vfx(player)
	if not player then return end
	item.set_stacks(player, 4)
	begin_upgrade_fx(player, 5, nil)
end

-- Debug toggles (render hooks below). Mode triggers defined after shatter helpers.
function item.debug_set_show_particle_centers(on)
	item._debug_show_particle_centers = on and true or false
end

function item.debug_get_show_particle_centers()
	return item._debug_show_particle_centers == true
end

function item.debug_set_show_particle_reconstruction(on)
	item._debug_show_particle_reconstruction = on and true or false
end

--- Debug：临时覆盖 Release 帧数（1~4）；nil 恢复正式 shatter_release_frames
function item.debug_set_release_frames(n)
	if n == nil then
		item._debug_release_frames = nil
		return
	end
	item._debug_release_frames = math.max(1, math.min(4, math.floor(tonumber(n) or 2)))
end

function item.debug_get_release_frames()
	return item._debug_release_frames
end

function item.debug_get_show_particle_reconstruction()
	return item._debug_show_particle_reconstruction == true
end

local function glaze_enemy_mod()
	return require("Qing_Remaster_scripts.pickups.pickup_glaze_enemy")
end

function item.is_glazed_enemy(ent)
	if not auxi.check_all_exists(ent) then return false end
	local glaze = glaze_enemy_mod()
	local d = ent:GetData()
	return d and d[glaze.own_key.."effect"] ~= nil
end

local function mark_special_tear(tear, kind, shatter_token)
	if not tear then return tear end
	local d = tear:GetData()
	d[item.own_key.."kind"] = kind
	d[item.own_key.."shatter"] = shatter_token
	-- refract 附着主泪：高度/下坠由 parent 同步，不自造抛物线
	if kind ~= "refract" then
		tear.Height = -20
		tear.FallingSpeed = -1.5
		tear.FallingAcceleration = 0.4
	end
	return tear
end

local function apply_shard_visual(tear, rng)
	if not tear or not REPENTOGON then return end
	local d = tear:GetData()
	if d[item.own_key.."shard_visual"] then return end
	d[item.own_key.."shard_visual"] = true
	rng = rng or make_rng(tear.InitSeed, 44)
	local variant = rng:RandomInt(4)
	local spin_sign = (rng:RandomInt(2) == 0) and 1 or -1
	local spin = spin_sign * (6 + rng:RandomInt(14))
	d[item.own_key.."spin"] = spin
	d[item.own_key.."roll_seed"] = ((tear.InitSeed or 1) % 1000) / 1000
	local spr = tear:GetSprite()
	if not spr then return end
	pcall(function()
		-- 与 companion 共用 item.shard_anm2（glaze_shard.anm2）
		spr:Load(item.shard_anm2, true)
		spr:Play("Shard" .. tostring(variant), true)
		spr.Rotation = rng:RandomInt(360)
		tear.SpriteRotation = 0
		temp_hud.apply_sprite_shader(spr, temp_hud.RAINBOW_ROLL_SHADER)
	end)
	item.paint_shard_roll(tear)
end

--- companion 冠尖：同 glaze_shard.anm2，但由槽位固定 anim/rot，无随机、无自转
local function apply_companion_shard_visual(tear, slot)
	if not tear or not slot or not REPENTOGON then return end
	local d = tear:GetData()
	if d[item.own_key.."shard_visual"] then return end
	d[item.own_key.."shard_visual"] = true
	d[item.own_key.."spin"] = 0
	d[item.own_key.."companion_rot"] = tonumber(slot.rot) or 0
	d[item.own_key.."companion_anim"] = slot.anim or "Shard0"
	d[item.own_key.."roll_seed"] = ((tear.InitSeed or 1) % 1000) / 1000
	local spr = tear:GetSprite()
	if not spr then return end
	local anim = d[item.own_key.."companion_anim"]
	local rot = d[item.own_key.."companion_rot"]
	pcall(function()
		spr:Load(item.shard_anm2, true)
		spr:Play(anim, true)
		spr.Rotation = rot
		tear.SpriteRotation = 0
		temp_hud.apply_sprite_shader(spr, temp_hud.RAINBOW_ROLL_SHADER)
	end)
	item.paint_shard_roll(tear)
end

function item.paint_shard_roll(tear)
	if not tear or not REPENTOGON then return end
	local d = tear:GetData()
	if not d[item.own_key.."shard_visual"] then return end
	local spr = tear:GetSprite()
	if not spr then return end
	local seed = tonumber(d[item.own_key.."roll_seed"]) or 0.37
	item.paint_glaze_shard_sprite(spr, seed, "flight")
end

local function fire_glaze_shard(player, pos, vel, dmg_mul, kind, shatter_token)
	if not player or not player.FireTear then return nil end
	local tear = attack_holder.FireTear(player, pos, vel, {
		mode = "untracked",
		reason = "crown_glaze_" .. tostring(kind or "shard"),
		can_be_eye = false,
		no_tracer = true,
		can_trigger_streak_end = false,
		Source = player,
		damage_multiplier = dmg_mul,
	})
	if not tear then return nil end
	mark_special_tear(tear, kind, shatter_token)
	tear.CollisionDamage = (player.Damage or 3.5) * dmg_mul
	if kind == "shatter" then
		local rng = make_rng(tear.InitSeed, (shatter_token or 0) * 17 + 9)
		apply_shard_visual(tear, rng)
	end
	return tear
end

--- 3 层冠冕弹：中心底座 + 4 枚均匀环绕附属（非四向固定槽）
-- 仅用 Shard0/Shard1 作冠尖；碎冠仍可随机 Shard0~3
local REFRACT_ORBIT_RADIUS = 15
local REFRACT_ORBIT_ANG_LERP = 0.22 -- 角度最短路径插值（抗转向抽搐）
local REFRACT_ORBIT_FACING_LERP = 0.12 -- 朝向平滑
local REFRACT_ORBIT_SPIN = 2.0 -- 世界系缓转（度 / game-frame）
local REFRACT_SLOT = {
	{ anim = "Shard1", rot = 0 },
	{ anim = "Shard0", rot = 0 },
	{ anim = "Shard1", rot = 0 },
	{ anim = "Shard0", rot = 0 },
}

local function normalize_angle_deg(a)
	while a > 180 do a = a - 360 end
	while a < -180 do a = a + 360 end
	return a
end

local function lerp_angle_deg(cur, target, t)
	return cur + normalize_angle_deg((target or 0) - (cur or 0)) * (t or 0)
end

--- 每 game-frame 更新一次：平滑 facing + 累积 orbit_phase（勿绑瞬时 Velocity 角）
local function tick_refract_orbit_basis(parent)
	if not parent then return 0, 0 end
	local pd = parent:GetData()
	local frame = Game():GetFrameCount()
	if pd[item.own_key.."orbit_tick_frame"] ~= frame then
		pd[item.own_key.."orbit_tick_frame"] = frame
		local vel = parent.Velocity or Vector.Zero
		local facing = tonumber(pd[item.own_key.."orbit_facing"])
		if vel:Length() >= 0.35 then
			local want = vel:GetAngleDegrees()
			if facing == nil then
				facing = want
			else
				facing = lerp_angle_deg(facing, want, REFRACT_ORBIT_FACING_LERP)
			end
		elseif facing == nil then
			facing = 0
		end
		pd[item.own_key.."orbit_facing"] = facing
		pd[item.own_key.."orbit_phase"] = (tonumber(pd[item.own_key.."orbit_phase"]) or 0) + REFRACT_ORBIT_SPIN
	end
	return tonumber(pd[item.own_key.."orbit_facing"]) or 0,
		tonumber(pd[item.own_key.."orbit_phase"]) or 0
end

local function refract_slot_target_angle(slot_index, facing_deg, phase_deg)
	local step = 360 / #REFRACT_SLOT
	return (facing_deg or 0) + (phase_deg or 0) + (slot_index - 1) * step
end

local function refract_orbit_offset(slot_index, facing_deg, phase_deg, radius_mul)
	local ang = refract_slot_target_angle(slot_index, facing_deg, phase_deg)
	return auxi.MakeVector(ang) * (REFRACT_ORBIT_RADIUS * (radius_mul or 1))
end

--- companion 弹道完全从属于 parent：只同步 Height / Falling*（普通泪勿同时写 PositionOffset）
local function sync_refract_ballistics(tear, parent)
	if not tear or not parent then return end
	local ptear = parent.ToTear and parent:ToTear() or parent
	tear.Height = ptear.Height
	tear.FallingSpeed = ptear.FallingSpeed
	tear.FallingAcceleration = ptear.FallingAcceleration
end

local function is_ludo_tear(ent)
	if not ent or not ent.TearFlags or not TearFlags or not TearFlags.TEAR_LUDOVICO then
		return false
	end
	return ent.TearFlags & TearFlags.TEAR_LUDOVICO == TearFlags.TEAR_LUDOVICO
end

--- 自定义 anm2 Load 后，同 Variant 的 ChangeVariant 会被跳过 → 贴图卡在王冠上。
--- 强制变体往返，让引擎重建原泪贴图；不回写 Height/Falling（Ludo 会坏）。
local function restore_glaze_core_visual(tear, snap)
	if not tear or type(snap) ~= "table" then return end
	local t = tear.ToTear and tear:ToTear() or tear
	local spr = t:GetSprite()
	if spr and REPENTOGON and temp_hud.clear_sprite_shader then
		temp_hud.clear_sprite_shader(spr)
	end

	local want = snap.variant
	if t.ChangeVariant and want ~= nil then
		local cur = t.Variant
		if cur == want then
			local tmp = TearVariant.BLOOD or 1
			if want == tmp then
				tmp = TearVariant.BLUE or 0
			end
			pcall(function()
				t:ChangeVariant(tmp)
			end)
		end
		pcall(function()
			t:ChangeVariant(want)
		end)
	end

	if snap.flags ~= nil then
		t.TearFlags = snap.flags
	end
	if snap.scale ~= nil then
		t.Scale = snap.scale
	end
	if snap.color ~= nil then
		t.Color = snap.color
	end
	if snap.damage ~= nil then
		t.CollisionDamage = snap.damage
	end

	if t.ResetSpriteScale then
		pcall(function()
			t:ResetSpriteScale(true)
		end)
	end
	local ss = snap.sprite_scale
	if ss and t.SpriteScale then
		local sx, sy
		if type(ss) == "userdata" or (ss.X ~= nil) then
			sx, sy = ss.X, ss.Y
		elseif type(ss) == "table" then
			sx, sy = ss.x or ss[1], ss.y or ss[2]
		end
		if sx ~= nil and sy ~= nil then
			t.SpriteScale = Vector(tonumber(sx) or 1, tonumber(sy) or 1)
		end
	end
	spr = t:GetSprite()
	if spr and spr.LoadGraphics then
		pcall(function()
			spr:LoadGraphics()
		end)
	end
end

--- 主泪：ProjectileBase（泪弹坐标 0,0 / pivot 16,16），勿用头顶 ShatterBase
local function apply_glaze_core_visual(tear, proc_seed)
	if not tear then return end
	local d = tear:GetData()
	if d[item.own_key.."glaze_core_visual"] then return end
	-- 王冠化前快照，供 clear_glaze_core 还原原贴图 / 物理
	if not d[item.own_key.."pre_glaze_snap"] then
		d[item.own_key.."pre_glaze_snap"] = tear_snapshot.capture(tear)
	end
	d[item.own_key.."glaze_core_visual"] = true
	local seed = ((tonumber(proc_seed) or tear.InitSeed or 1) % 1000) / 1000
	d[item.own_key.."glaze_core_seed"] = seed
	local spr = tear:GetSprite()
	if not spr then return end
	pcall(function()
		spr:Load(item.crown_anm2, true)
		spr:Play("ProjectileBase", true)
		tear.SpriteRotation = 0
		if REPENTOGON then
			temp_hud.apply_sprite_shader(spr, temp_hud.RAINBOW_ROLL_SHADER)
		end
	end)
	item.paint_glaze_shard_sprite(spr, seed, "glaze_core")
end

function item.paint_glaze_core(tear)
	if not tear or not REPENTOGON then return end
	local d = tear:GetData()
	if not d[item.own_key.."glaze_core_visual"] then return end
	local spr = tear:GetSprite()
	if not spr then return end
	local seed = tonumber(d[item.own_key.."glaze_core_seed"]) or 0.37
	item.paint_glaze_shard_sprite(spr, seed, "glaze_core")
end

--- 将 4 枚 refract companion 解绑为四散飞出的伤害泪（保留 CollisionDamage）
local function release_refract_as_scatter(core)
	if not core then return end
	local parent_hash = GetPtrHash(core)
	local core_pos = core.Position
	local core_vel = core.Velocity or Vector.Zero
	local tears = Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, false, false)
	for i = 1, #tears do
		local ent = tears[i]
		if ent and ent.Exists and ent:Exists() then
			local td = ent:GetData()
			if td[item.own_key.."kind"] == "refract"
				and td[item.own_key.."refract_parent_hash"] == parent_hash
			then
				local t = ent.ToTear and ent:ToTear() or ent
				local slot_index = math.floor(tonumber(td[item.own_key.."refract_slot"]) or 1)
				td[item.own_key.."kind"] = "uncrown_scatter"
				td[item.own_key.."refract_parent"] = nil
				td[item.own_key.."refract_parent_hash"] = nil
				local radial = t.Position - core_pos
				if radial:Length() < 0.5 then
					radial = auxi.MakeVector((slot_index - 1) * (360 / #REFRACT_SLOT))
				end
				radial = radial:Normalized()
				local out = core_vel * 0.35 + radial * 6.8
				t.Velocity = out
				t.FallingSpeed = 0.9
				t.FallingAcceleration = 0.75
				-- 保持已有 CollisionDamage / 碰撞，作为伤害泪飞散
			end
		end
	end
end

--- 公开入口：解除王冠化 —— 还原主泪贴图，四枚冠尖作为伤害泪四散飞出
function item.clear_glaze_core(tear)
	if not tear then return false end
	local d = tear:GetData()
	if not d[item.own_key.."glaze_core"] and not d[item.own_key.."glaze_core_visual"] then
		return false
	end

	release_refract_as_scatter(tear)

	local snap = d[item.own_key.."pre_glaze_snap"]
	if snap then
		restore_glaze_core_visual(tear, snap)
	else
		local spr = tear:GetSprite()
		if spr and REPENTOGON and temp_hud.clear_sprite_shader then
			temp_hud.clear_sprite_shader(spr)
		end
		if tear.ChangeVariant then
			local want = tear.Variant
			local tmp = TearVariant.BLOOD or 1
			if want == tmp then tmp = TearVariant.BLUE or 0 end
			pcall(function()
				tear:ChangeVariant(tmp)
				tear:ChangeVariant(want)
			end)
		end
		if tear.ResetSpriteScale then
			pcall(function()
				tear:ResetSpriteScale(true)
			end)
		end
	end

	d[item.own_key.."glaze_core"] = nil
	d[item.own_key.."glaze_core_visual"] = nil
	d[item.own_key.."glaze_core_seed"] = nil
	d[item.own_key.."glaze_proc_seed"] = nil
	d[item.own_key.."pre_glaze_snap"] = nil
	d[item.own_key.."glaze_core_ttl"] = nil
	d[item.own_key.."orbit_facing"] = nil
	d[item.own_key.."orbit_phase"] = nil
	d[item.own_key.."orbit_tick_frame"] = nil
	return true
end

local function fire_refract_companion(player, attack, emitter, slot_index)
	if not player or not attack or not emitter then return nil end
	local slot = REFRACT_SLOT[slot_index]
	if not slot then return nil end

	local vel = emitter.Velocity or Vector.Zero
	local facing, phase = tick_refract_orbit_basis(emitter)
	local pos = emitter.Position + refract_orbit_offset(slot_index, facing, phase, 1)
	local fire_vel = vel
	if fire_vel:Length() < 0.2 then
		fire_vel = auxi.MakeVector(facing) * 0.25
	end

	local tear = attack_holder.FireTear(player, pos, fire_vel, {
		mode = "inherit",
		attack = attack,
		emitter = emitter,
		Source = emitter,
		role = "derived",
		reason = "crown_glaze_refract",
		damage_multiplier = item.refract_damage,
		can_be_eye = false,
		no_tracer = true,
		can_trigger_streak_end = false,
	})
	if not tear then return nil end

	mark_special_tear(tear, "refract", nil)

	local d = tear:GetData()
	d[item.own_key.."refract_parent"] = emitter
	d[item.own_key.."refract_slot"] = slot_index
	d[item.own_key.."refract_parent_hash"] = GetPtrHash(emitter)
	d[item.own_key.."orbit_ang"] = refract_slot_target_angle(slot_index, facing, phase)

	tear.CollisionDamage = (player.Damage or 3.5) * item.refract_damage
	-- FireTear 的 damage_multiplier 可能缩小 Scale；冠尖用原尺寸
	tear.Scale = 1
	sync_refract_ballistics(tear, emitter)

	apply_companion_shard_visual(tear, slot)
	-- 换皮后再写一次，避免生成帧引擎默认抛物线盖掉
	sync_refract_ballistics(tear, emitter)
	return tear
end

--- 每帧：均匀环绕 + 角度插值顺滑，同步 parent 弹道/高度
local function update_refract_companion(tear)
	if not tear then return end
	local d = tear:GetData()
	local parent = d[item.own_key.."refract_parent"]
	if not parent or not parent.Exists or not parent:Exists() then
		tear:Remove()
		return
	end
	if parent.Type ~= EntityType.ENTITY_TEAR then
		tear:Remove()
		return
	end

	local parent_hash = d[item.own_key.."refract_parent_hash"]
	if parent_hash and GetPtrHash(parent) ~= parent_hash then
		tear:Remove()
		return
	end

	local slot_index = math.floor(tonumber(d[item.own_key.."refract_slot"]) or 0)
	local slot = REFRACT_SLOT[slot_index]
	if not slot then
		tear:Remove()
		return
	end

	-- 无论速度是否有效，先锁死弹道，防止独立落地
	sync_refract_ballistics(tear, parent)
	tear.Scale = 1

	local facing, phase = tick_refract_orbit_basis(parent)
	local want_ang = refract_slot_target_angle(slot_index, facing, phase)
	local cur_ang = tonumber(d[item.own_key.."orbit_ang"])
	if cur_ang == nil then
		cur_ang = want_ang
	else
		cur_ang = lerp_angle_deg(cur_ang, want_ang, REFRACT_ORBIT_ANG_LERP)
	end
	d[item.own_key.."orbit_ang"] = cur_ang

	local frame = Game():GetFrameCount()
	local breath = 1.0 + 0.03 * math.sin(frame * 0.16 + slot_index)
	tear.Position = parent.Position + auxi.MakeVector(cur_ang) * (REFRACT_ORBIT_RADIUS * breath)
	tear.Velocity = parent.Velocity or Vector.Zero
	-- Position 写完后再同步一次 Height/Falling*，避免引擎同帧改写后漂移
	sync_refract_ballistics(tear, parent)

	-- 朝向沿环切线
	local spr = tear:GetSprite()
	if spr then
		local base_rot = tonumber(d[item.own_key.."companion_rot"]) or slot.rot or 0
		spr.Rotation = cur_ang + 90 + base_rot
	end
end

local function spawn_weighted_glaze(pos, rng)
	local glaze = glaze_enemy_mod()
	local info = glaze.pickup
	local wei = 0
	for _, v in pairs(enums.Pickups) do
		wei = wei + (v.wei or 0)
	end
	if wei < 1 then return end
	wei = rng:RandomInt(wei)
	for u, v in pairs(enums.Pickups) do
		if (v.wei or 0) > 0 then
			wei = wei - v.wei
			if wei <= 0 then
				info = v
				if u == "Glaze_bomb" and auxi.has_poop_player() then
					info = enums.Pickups.Glaze_big_poop
				end
				break
			end
		end
	end
	local q = Isaac.Spawn(5, info.Variant, info.SubType, pos, auxi.MakeVector(rng:RandomInt(360)) * 3, nil)
	if q then auxi.special_morph(q, info) end
end

local function shatter_shard_count(n)
	local count = item.shatter_base_count + n * item.shatter_per_stack
	if n >= item.max_stacks then
		count = count + item.full_shatter_bonus
	end
	return count
end

-- 碎冠首段：recoil → crack → disassemble → release → freeze → flash → break
local ENABLE_SHATTER_PRIMARY_TRAIL = true
local ENABLE_SHATTER_SHOCK_RING = false
-- Particle visual centers: user crop-local (cx,cy) → local = (cx-16, cy-24)
-- crop≈ P1(13,10) P2(20,17) P3(16,16) P4(12,0) P5(21,0)；Case A: start_offset = Zero
local PARTICLE_VISUAL_CENTER = {
	[1] = Vector(-3, -14),
	[2] = Vector(4, -7),
	[3] = Vector(0, -8),
	[4] = Vector(-4, -24),
	[5] = Vector(5, -24),
}

local PRIMARY_EJECT = {
	[1] = {
		start = Vector(0, 0),
		velocity = Vector(-9.4, -2.2),
		delay = 0,
		rotation_delta = -7,
	},
	[2] = {
		start = Vector(0, 0),
		velocity = Vector(6.3, -7.7),
		delay = 1,
		rotation_delta = 6,
	},
	[3] = {
		start = Vector(0, 0),
		velocity = Vector(2.0, -10.8),
		delay = 0,
		rotation_delta = 2,
	},
	[4] = {
		start = Vector(0, 0),
		velocity = Vector(-7.1, 4.4),
		delay = 1,
		rotation_delta = -8,
	},
	[5] = {
		start = Vector(0, 0),
		velocity = Vector(9.8, 2.7),
		delay = 0,
		rotation_delta = 7,
	},
}

-- 每枚 Primary 按发出数量取非对称角度；禁止对称扇形生成器
local PRIMARY_BURST_PATTERNS = {
	[1] = {
		[2] = {-9, 16},
		[3] = {-18, 1, 20},
		[4] = {-21, -7, 10, 24},
	},
	[2] = {
		[2] = {-14, 8},
		[3] = {-19, 4, 17},
		[4] = {-25, -6, 11, 23},
	},
	[3] = {
		[2] = {-6, 18},
		[3] = {-23, -3, 15},
		[4] = {-20, -5, 12, 27},
	},
	[4] = {
		[2] = {-18, 5},
		[3] = {-17, 6, 22},
		[4] = {-28, -9, 8, 19},
	},
	[5] = {
		[2] = {-5, 17},
		[3] = {-15, 3, 24},
		[4] = {-19, -4, 13, 29},
	},
}

local CROWN_TRAIL_PRESET = {
	min_radius = 0.10,
	max_radius = 0.13,
	scale = 0.75,
	local_offset = { x = 0, y = 0 },
	-- 默认占位；实际每枚 Primary 用随机彩虹覆写 color/colorize（无 shader）
	color = {
		r = 1, g = 1, b = 1, a = 0.78,
		ro = 0, go = 0, bo = 0,
	},
	colorize = {
		r = 1, g = 1, b = 1, a = 0.90,
	},
	reapply_color_each_sync = true,
}

local TRAIL_FADE_STEPS = {
	{ alpha = 0.45, radius_mul = 0.70, scale_mul = 0.78 },
	{ alpha = 0.20, radius_mul = 0.42, scale_mul = 0.52 },
	{ alpha = 0.06, radius_mul = 0.20, scale_mul = 0.28 },
}

local SHOCK_RING_SCALES = {0.30, 0.60, 1.00, 1.40}
local SHOCK_RING_ALPHAS = {0.95, 0.78, 0.42, 0}

--- h∈[0,1), s/v∈[0,1] → r,g,b∈[0,1]
local function hsv_to_rgb(h, s, v)
	h = (tonumber(h) or 0) % 1
	if h < 0 then h = h + 1 end
	s = math.max(0, math.min(1, tonumber(s) or 1))
	v = math.max(0, math.min(1, tonumber(v) or 1))
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return v, t, p end
	if i == 1 then return q, v, p end
	if i == 2 then return p, v, t end
	if i == 3 then return p, q, v end
	if i == 4 then return t, p, v end
	return v, p, q
end

--- 随机彩虹拖尾色：Tint 乘色 + Colorize（手挂 Trail 不吃 Null，无 shader）
local function roll_trail_rainbow(rng)
	local hue = 0.5
	if rng and rng.RandomFloat then
		hue = rng:RandomFloat()
	else
		hue = Random() / 4294967295
	end
	local r, g, b = hsv_to_rgb(hue, 0.85, 1.0)
	return {
		color = {
			r = r, g = g, b = b, a = 0.78,
			ro = 0, go = 0, bo = 0,
		},
		colorize = {
			r = r, g = g, b = b, a = 0.92,
		},
	}
end

local function crown_trail_preset_for(p)
	local base = CROWN_TRAIL_PRESET
	local c = (p and p.trail_color) or base.color
	local cz = (p and p.trail_colorize) or base.colorize
	return {
		min_radius = base.min_radius,
		max_radius = base.max_radius,
		scale = base.scale,
		local_offset = base.local_offset,
		color = c,
		colorize = cz,
		reapply_color_each_sync = true,
	}
end

--- Release 专用：短尾迹，看得出速度但不形成粗彩带
local function crown_release_trail_preset(p)
	local base = crown_trail_preset_for(p)
	local c = base.color
	local cz = base.colorize
	return {
		min_radius = base.min_radius * 0.72,
		max_radius = base.max_radius * 0.72,
		scale = base.scale * 0.78,
		local_offset = base.local_offset,
		color = {
			r = c.r, g = c.g, b = c.b,
			a = (c.a or 1) * 0.68,
			ro = c.ro or 0, go = c.go or 0, bo = c.bo or 0,
		},
		colorize = {
			r = cz.r, g = cz.g, b = cz.b,
			a = (cz.a or 1) * 0.72,
		},
		reapply_color_each_sync = true,
	}
end

--- World-space visual center of a primary ParticleN (pivot + offset + rotated local center).
local function get_primary_visual_center_world(fx, p, scale)
	local origin = (fx and fx.origin) or Vector.Zero
	local local_center = PARTICLE_VISUAL_CENTER[p and p.index] or Vector.Zero
	scale = tonumber(scale) or 1
	local_center = Vector(local_center.X * scale, local_center.Y * scale)
	local_center = local_center:Rotated(p and p.rotation or 0)
	local offset = (p and (p.offset or p.start_offset)) or Vector.Zero
	return origin + offset + local_center
end

local function make_primary_shard_sprite(index, seed)
	local spr = Sprite()
	spr:Load(item.crown_anm2, true)
	spr:Play("Particle" .. tostring(index), true)
	if REPENTOGON then
		apply_glaze_particle_shader(spr, seed)
		item.paint_glaze_shard_sprite(spr, seed, "scatter")
	end
	return spr
end

local function build_primary_shards(stacks, player, rng)
	local shards = {}
	stacks = math.max(0, math.min(item.max_stacks, tonumber(stacks) or 0))
	for i = 1, stacks do
		local cfg = PRIMARY_EJECT[i]
		if cfg then
			local seed = glaze_particle_seed(player, i)
			if rng then
				seed = ((seed * 997 + rng:RandomInt(1000)) % 1000) / 1000
			end
			local speed_mul = 0.94 + rng:RandomFloat() * 0.12
			local vel = cfg.velocity * speed_mul
			local exit_dir = Vector(0, -1)
			if vel:Length() > 0.001 then
				exit_dir = vel:Normalized()
			end
			local trail_paint = roll_trail_rainbow(rng)
			shards[#shards + 1] = {
				index = i,
				start_offset = cfg.start,
				offset = cfg.start,
				velocity = vel,
				delay = cfg.delay or 0,
				rotation_delta = cfg.rotation_delta or 0,
				exit_dir = exit_dir,
				spr = make_primary_shard_sprite(i, seed),
				seed = seed,
				rotation = 0,
				base_scale = 1,
				frozen_seed = nil,
				ejected = false,
				frozen = false,
				freeze_offset = nil,
				trail_carrier = nil,
				trail_store = {},
				trail_fade = nil,
				trail_color = trail_paint.color,
				trail_colorize = trail_paint.colorize,
			}
		end
	end
	return shards
end

local function crack_debris_count(stacks)
	return 2 + math.max(0, tonumber(stacks) or 0)
end

local function make_crack_debris_sprite(rng, seed)
	local spr = Sprite()
	spr:Load(item.shard_anm2, true)
	local variant = rng:RandomInt(4)
	spr:Play("Shard" .. tostring(variant), true)
	spr.Rotation = rng:RandomInt(360)
	if REPENTOGON then
		temp_hud.apply_sprite_shader(spr, temp_hud.RAINBOW_ROLL_SHADER)
		item.paint_glaze_shard_sprite(spr, seed, "scatter")
	end
	return spr
end

local function build_crack_debris(primary_shards, stacks, rng, fx)
	local debris = {}
	if not rng or not primary_shards or #primary_shards <= 0 then
		return debris
	end
	local origin = (fx and fx.origin) or Vector(0, 0)
	local count = crack_debris_count(stacks)
	for _ = 1, count do
		local primary = primary_shards[1 + rng:RandomInt(#primary_shards)]
		local world = get_primary_visual_center_world(fx or {origin = origin}, primary, 1)
		local spawn_offset = (world - origin) + Vector(rng:RandomInt(5) - 2, rng:RandomInt(5) - 2)
		local main = primary.velocity or Vector(0, -1)
		if main:Length() < 0.001 then
			main = Vector(0, -1)
		else
			main = main:Normalized()
		end
		local angle = main:GetAngleDegrees() + (-35 + rng:RandomFloat() * 70)
		local speed = 4 + rng:RandomFloat() * 3
		local seed = (rng:RandomInt(1000) % 1000) / 1000
		debris[#debris + 1] = {
			pos = spawn_offset,
			velocity = auxi.MakeVector(angle) * speed,
			spr = make_crack_debris_sprite(rng, seed),
			rotation = rng:RandomInt(360),
			spin = -18 + rng:RandomFloat() * 36,
			scale = 0.22 + rng:RandomFloat() * 0.16,
			seed = seed,
			age = 0,
			life = 4 + rng:RandomInt(3),
			base_alpha = 0.75,
		}
	end
	return debris
end

local function tick_crack_debris(fx)
	local list = fx.crack_debris
	if not list then return end
	local remain = {}
	for i = 1, #list do
		local d = list[i]
		d.age = (d.age or 0) + 1
		d.pos = d.pos + d.velocity
		d.velocity = d.velocity * 0.94
		d.rotation = (d.rotation or 0) + (d.spin or 0)
		if d.age < (d.life or 1) then
			remain[#remain + 1] = d
		end
	end
	fx.crack_debris = remain
end

local function render_crack_debris(fx, offset)
	local list = fx.crack_debris
	if not list or #list <= 0 then return end
	local origin = fx.origin or Vector(0, 0)
	for i = 1, #list do
		local d = list[i]
		if d.spr then
			local life = math.max(1, d.life or 1)
			local left = 1 - (d.age or 0) / life
			if left < 0 then left = 0 end
			local alpha = (d.base_alpha or 0.65) * left
			local screen = world_to_entity_render(origin + d.pos, offset)
			local sc = d.scale or 0.35
			d.spr.Scale = Vector(sc, sc)
			d.spr.Rotation = d.rotation or 0
			item.paint_glaze_shard_sprite(d.spr, d.seed, "scatter", {alpha = alpha})
			d.spr:Render(screen, Vector(0, 0), Vector(0, 0))
		end
	end
end

local function distribute_attack_shards(total, primary_count)
	local result = {}
	primary_count = math.max(1, tonumber(primary_count) or 1)
	total = math.max(0, tonumber(total) or 0)
	local base = math.floor(total / primary_count)
	local extra = total % primary_count
	for i = 1, primary_count do
		result[i] = base + ((i <= extra) and 1 or 0)
	end
	return result
end

local function burst_angles_for(primary_index, n)
	local by_primary = PRIMARY_BURST_PATTERNS[primary_index]
	if by_primary and by_primary[n] then
		return by_primary[n]
	end
	return {0}
end

local function lateral_offsets_for(n)
	if n <= 1 then
		return {0}
	elseif n == 2 then
		return {-1.5, 1.5}
	elseif n == 3 then
		return {-2, 0, 2}
	elseif n == 4 then
		return {-3, -1, 1, 3}
	end
	local out = {}
	local span = 3
	for i = 1, n do
		out[i] = -span + (2 * span) * ((i - 1) / math.max(1, n - 1))
	end
	return out
end

local function cancel_upgrade_fx_for(player)
	local pk = player_key(player)
	local remain = {}
	for i = 1, #upgrade_fx do
		if upgrade_fx[i].player_key ~= pk then
			remain[#remain + 1] = upgrade_fx[i]
		end
	end
	upgrade_fx = remain
end

local function clear_primary_trail(p)
	if not p then return end
	if p.trail_store then
		SpriteTrails.clear(p.trail_store, "crown_trail")
	end
	local carrier = p.trail_carrier
	if carrier and carrier.Exists and carrier:Exists() then
		carrier:Remove()
	end
	p.trail_carrier = nil
end

local function clear_shatter_trails(fx)
	if not fx then return end
	for j = 1, #(fx.primary_shards or {}) do
		clear_primary_trail(fx.primary_shards[j])
	end
end

local function drop_shatter_fx(fx)
	if not fx then return end
	clear_shatter_trails(fx)
	if fx.shock_ring and fx.shock_ring.spr then
		fx.shock_ring.spr = nil
	end
	fx.shock_ring = nil
	fx.base_spr = nil
	if fx.player and fx.player.Exists and fx.player:Exists() then
		local d = fx.player:GetData()
		d[item.own_key.."shatter_recoil_y"] = nil
		d[item.own_key.."shatter_recoil_scale"] = nil
	end
end

local function clear_all_shatter_fx()
	for i = 1, #shatter_fx do
		drop_shatter_fx(shatter_fx[i])
	end
	shatter_fx = {}
end

local function shatter_burst(fx)
	local player = fx.player
	if not player or not player.Exists or not player:Exists() then return end
	local origin = fx.origin or Vector(0, 0)
	local speed = fx.speed
	local dmg_mul = fx.dmg_mul
	local token = fx.token
	local primaries = fx.primary_shards or {}
	local counts = distribute_attack_shards(fx.attack_count or 0, math.max(1, #primaries))
	local rng = make_rng(fx.burst_rng_seed or token or 1, 41)
	for i = 1, #primaries do
		local p = primaries[i]
		local exit_dir = p.exit_dir
		if not exit_dir or exit_dir:Length() < 0.001 then
			exit_dir = Vector(0, -1)
		else
			exit_dir = exit_dir:Normalized()
		end
		local center_angle = exit_dir:GetAngleDegrees()
		local lateral_dir = Vector(-exit_dir.Y, exit_dir.X)
		local primary_pos = origin + (p.freeze_offset or p.offset or Vector(0, 0))
		local n = counts[i] or 0
		local angles = burst_angles_for(p.index or i, n)
		local laterals = lateral_offsets_for(n)
		for j = 1, n do
			local ang = center_angle + (angles[j] or 0)
			local lateral = laterals[j] or 0
			local spawn_pos = primary_pos + lateral_dir * lateral
			local speed_mul = 0.82 + rng:RandomFloat() * 0.36
			local vel = auxi.MakeVector(ang) * speed * speed_mul
			fire_glaze_shard(player, spawn_pos, vel, dmg_mul, "shatter", token)
		end
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_GLASS_BREAK, 1.1, 0.95, false, 0, 2)
	Game():ShakeScreen(8 + (fx.old_stacks or 1))
	if fx.complete then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MIRROR_BREAK, 0.85, 1.05, false, 0, 2)
	end
	local penalty = tonumber(fx.seija_penalty) or 0
	if penalty > 0 and item.is_seija(player) then
		player:SetColor(Color(1, 0.35, 0.4, 1, 0.35, 0.05, 0.05), 8, 8, true, false)
		player:TakeDamage(penalty, DamageFlag.DAMAGE_NO_PENALTIES, EntityRef(player), 30)
	end
	fx.burst_spawned = true
end

local function lock_shatter_shader_phase(fx)
	if not fx or fx.shader_locked then return end
	fx.shader_locked = true
	for j = 1, #(fx.primary_shards or {}) do
		local p = fx.primary_shards[j]
		p.freeze_phase = temp_hud.rainbow_roll_phase(p.seed, SHATTER_MOVE_SPEED, 1, false)
	end
	local state = (fx.base_visual_state) or "dormant"
	local cfg = item.CROWN_ROLL[state] or item.CROWN_ROLL.dormant
	fx.base_freeze_phase = temp_hud.rainbow_roll_phase(
		fx.base_roll_seed or 0.41,
		cfg.speed or 0,
		1,
		false
	)
end

local function make_shock_ring_sprite()
	local spr = Sprite()
	spr:Load(item.crown_anm2, true)
	spr:Play("HaloPulse", true)
	return spr
end

local RECOIL_KEYS = {
	[1] = { y = -1, scale = 1.02 },
	[2] = { y = -3, scale = 1.05 },
	[3] = { y = -5, scale = 1.09 },
	[4] = { y = -7, scale = 1.13 },
	[5] = { y = -8, scale = 1.15 },
	[6] = { y = -7, scale = 1.13 },
	[7] = { y = -5, scale = 1.10 },
}

local CRACK_SHAKE = {
	[1] = Vector(-1, 0),
	[2] = Vector(1, -1),
}

local DISASSEMBLE_DISTANCE = {
	[1] = 0.6,
	[2] = 1.4,
	[3] = 2.4,
	[4] = 3.6,
}

local DISASSEMBLE_ROT_MUL = {
	[1] = 0.10,
	[2] = 0.20,
	[3] = 0.32,
	[4] = 0.45,
}

-- Base disassemble / release 用 smoothstep 轻沉；legacy eject 表仅 tick_eject_phase 使用
local BASE_EJECT_Y = {
	[1] = 2.0,
	[2] = 3.0,
	[3] = 4.0,
	[4] = 4.5,
	[5] = 4.8,
	[6] = 5.0,
}

-- Release：旧版真实 velocity + delay（禁止固定距离平移）
local RELEASE_INITIAL_KICK = 1.12
local RELEASE_DAMPING = 0.92

local DEBUG_STOP_PHASE = {
	recoil = "recoil",
	crack = "crack",
	disassemble = "disassemble",
	release = "release",
	eject = "release", -- 旧 UI → release
	trail = "freeze",
	-- 旧 Debug 名兼容
	fracture = "crack",
	shock = "crack",
}

local function effective_release_frames()
	return item._debug_release_frames
		or item.shatter_release_frames
		or 2
end

local function sync_player_recoil(player, phase_age)
	if not player then return end
	local d = player:GetData()
	local key = RECOIL_KEYS[phase_age]
	if key then
		d[item.own_key.."shatter_recoil_y"] = key.y
		d[item.own_key.."shatter_recoil_scale"] = key.scale
	else
		d[item.own_key.."shatter_recoil_y"] = nil
		d[item.own_key.."shatter_recoil_scale"] = nil
	end
end

local function shatter_phase_log(fx, msg)
	if not fx then return end
	if fx.debug_mode or fx.debug_stop_after ~= nil or item._debug_shatter_phases then
		print("[CrownShatter] " .. tostring(msg))
	end
end

local function find_player_shatter_fx(player)
	if not player then return nil end
	local pk = player_key(player)
	for i = 1, #shatter_fx do
		local fx = shatter_fx[i]
		if fx.player_key == pk and not fx.burst_done then
			return fx
		end
	end
	return nil
end

local function make_shatter_base_sprite(player)
	local spr = Sprite()
	spr:Load(item.crown_anm2, true)
	spr:Play("ShatterBase", true)
	if REPENTOGON then
		temp_hud.apply_sprite_shader(spr, temp_hud.RAINBOW_ROLL_SHADER)
	end
	return spr
end

--- ShatterBase 专用：复用 Crown roll 状态，禁止 scatter 高速
local function paint_shatter_base(spr, fx, opts)
	if not spr then return end
	opts = opts or {}
	local state = (fx and fx.base_visual_state) or "dormant"
	local cfg = item.CROWN_ROLL[state] or item.CROWN_ROLL.dormant
	local alpha_mul = tonumber(opts.alpha_mul) or 1
	local frozen = opts.frozen == true
	local alpha = (cfg.alpha or 1) * alpha_mul
	local speed = frozen and 0 or (cfg.speed or 0)
	if REPENTOGON then
		if frozen and fx and fx.base_freeze_phase ~= nil and temp_hud.make_rainbow_roll_color_from_phase then
			spr.Color = temp_hud.make_rainbow_roll_color_from_phase(
				alpha,
				fx.base_freeze_phase,
				0.05,
				0.95,
				cfg.angle,
				cfg.density,
				cfg.gray,
				cfg.bend,
				cfg.contrast
			)
		else
			spr.Color = temp_hud.make_rainbow_roll_color(
				alpha,
				(fx and fx.base_roll_seed) or 0.41,
				0.05,
				0.95,
				cfg.angle,
				cfg.density,
				speed,
				1,
				cfg.gray,
				cfg.bend,
				cfg.contrast,
				false
			)
		end
	else
		spr.Color = Color(1, 1, 1, alpha, 0, 0, 0)
	end
end

local function crown_trail_preset_weak(p)
	local base = crown_trail_preset_for(p)
	local c = base.color
	local cz = base.colorize
	return {
		min_radius = base.min_radius * 0.6,
		max_radius = base.max_radius * 0.6,
		scale = base.scale * 0.7,
		local_offset = base.local_offset,
		color = {
			r = c.r, g = c.g, b = c.b,
			a = (c.a or 1) * 0.45,
			ro = c.ro or 0, go = c.go or 0, bo = c.bo or 0,
		},
		colorize = {
			r = cz.r, g = cz.g, b = cz.b,
			a = (cz.a or 1) * 0.45,
		},
		reapply_color_each_sync = true,
	}
end

--- opts.lead_velocity: SPRITE_TRAIL 白带相对采样点约晚 1 逻辑帧；
--- 用 Position += shard velocity 领先一帧。禁止写 trail.Velocity（会再积分一次）。
local function sync_carrier_to_visual_center(fx, p, opts)
	local carrier = p and p.trail_carrier
	if not carrier or not carrier.Exists or not carrier:Exists() then return end
	local center = get_primary_visual_center_world(fx, p, 1)
	local lead = Vector.Zero
	if opts and opts.lead_velocity and not p.frozen then
		lead = p.release_velocity or p.velocity or Vector.Zero
	end
	carrier.Position = center + lead
	carrier.Velocity = Vector.Zero
end

--- Crack：锁定升起后的 origin；保持完整 Crown；预建 Primary/Trail/Debris/Ring，但 Primary 不可见。
local function fire_crack_event(fx)
	if not fx or fx.crack_fired then return end
	fx.crack_fired = true
	local player = fx.player
	if player and player.Exists and player:Exists() then
		local d = player:GetData()
		d[item.own_key.."shatter_holding"] = true
		d[item.own_key.."shatter_flash"] = math.max(2, item.crown_crack_flash_frames or 1)
		d[item.own_key.."sprite_dirty"] = true
		-- Crack 期间保持升起高度，不要清 recoil
		d[item.own_key.."shatter_recoil_y"] = -5
		d[item.own_key.."shatter_recoil_scale"] = 1.10
	end
	fx.crack_debris = build_crack_debris(fx.primary_shards, fx.old_stacks, fx.rng, fx)
	if ENABLE_SHATTER_SHOCK_RING then
		fx.shock_ring = {
			age = 0,
			duration = 4,
			await_first_render = true,
			spr = make_shock_ring_sprite(),
			world_origin = fx.origin,
		}
	else
		fx.shock_ring = nil
	end
	for j = 1, #(fx.primary_shards or {}) do
		local p = fx.primary_shards[j]
		p.ejected = false
		p.visible = false
		p.offset = p.start_offset or Vector.Zero
		p.rotation = 0
		if ENABLE_SHATTER_PRIMARY_TRAIL then
			local carrier_pos = get_primary_visual_center_world(fx, p, 1)
			local carrier = auxi.fire_nil(carrier_pos, Vector.Zero, {
				cooldown = 9999,
				player = fx.player,
			})
			if carrier then
				carrier.Visible = false
				carrier.Velocity = Vector.Zero
				pcall(function()
					local spr = carrier:GetSprite()
					if spr then spr.Color = Color(1, 1, 1, 0) end
				end)
				p.trail_carrier = carrier
				p.trail_store = {}
			end
		end
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_STONE_IMPACT, 0.48, 1.55, false, 0, 2)
end

local function apply_trail_fade_preset(p, step)
	local fade = TRAIL_FADE_STEPS[step]
	if not fade then return nil end
	-- 从 Release 弱尾迹强度衰减，避免 Freeze 第一帧突然变粗
	local base = crown_release_trail_preset(p)
	local base_c = base.color
	local base_cz = base.colorize
	return {
		min_radius = base.min_radius * fade.radius_mul,
		max_radius = base.max_radius * fade.radius_mul,
		scale = base.scale * fade.scale_mul,
		local_offset = base.local_offset,
		color = {
			r = base_c.r, g = base_c.g, b = base_c.b,
			a = (base_c.a or 1) * fade.alpha,
			ro = base_c.ro or 0, go = base_c.go or 0, bo = base_c.bo or 0,
		},
		colorize = {
			r = base_cz.r, g = base_cz.g, b = base_cz.b,
			a = (base_cz.a or 1) * fade.alpha,
		},
		reapply_color_each_sync = true,
	}
end

local function tick_primary_trail_fade(p)
	if p.trail_fade == nil then return end
	local step = (p.trail_fade or 0) + 1
	if step > #TRAIL_FADE_STEPS then
		clear_primary_trail(p)
		p.trail_fade = nil
		return
	end
	p.trail_fade = step
	local preset = apply_trail_fade_preset(p, step)
	local carrier = p.trail_carrier
	if preset and carrier and carrier.Exists and carrier:Exists() then
		local trail = SpriteTrails.sync(carrier, p.trail_store, "crown_trail", preset)
		if trail then
			trail.MinRadius = preset.min_radius
			trail.MaxRadius = preset.max_radius
			trail.SpriteScale = Vector(preset.scale, preset.scale)
		end
	else
		clear_primary_trail(p)
		p.trail_fade = nil
	end
end

local function hard_freeze_primary(p)
	if p.frozen then return end
	p.frozen = true
	-- 不覆盖 p.exit_dir：Final Burst 使用创建时方向
	p.velocity = Vector.Zero
	p.release_velocity = Vector.Zero
	p.freeze_offset = p.offset or p.start_offset or Vector.Zero
	p.freeze_rotation = p.rotation or 0
	if ENABLE_SHATTER_PRIMARY_TRAIL then
		p.trail_fade = 0
	else
		p.trail_fade = nil
	end
end

local function tick_shock_ring(fx)
	local ring = fx.shock_ring
	if not ring or not ring.spr then return end
	if ring.await_first_render then
		ring.await_first_render = false
		return
	end
	ring.age = (ring.age or 0) + 1
	if ring.age >= (ring.duration or 3) then
		fx.shock_ring = nil
	end
end

local function render_shock_ring(fx, offset)
	local ring = fx.shock_ring
	if not ring or not ring.spr then return end
	local idx = math.min((ring.age or 0) + 1, #SHOCK_RING_SCALES)
	local scale = SHOCK_RING_SCALES[idx] or 1
	local alpha = SHOCK_RING_ALPHAS[idx] or 0
	if alpha <= 0 then return end
	local spr = ring.spr
	spr.Scale = Vector(scale, scale)
	spr.Color = Color(0.85, 1, 1, alpha, 0.05, 0.2, 0.25)
	local world = ring.world_origin or fx.origin
	if not world then return end
	-- HaloPulse 层自带 Y=-30；world_origin 已是升起后的 Crown pivot
	local pos = world_to_entity_render(world, offset)
	-- 对齐旧 get_crown_render_position：pivot = render + CROWN_ANM2_OFFSET
	pos = pos - item.CROWN_ANM2_OFFSET
	spr:Render(pos, Vector(0, 0), Vector(0, 0))
end

local function render_shatter_base(fx, offset)
	if not fx or not fx.base_spr then return end
	local phase = fx.phase
	if phase ~= "disassemble"
		and phase ~= "release"
		and phase ~= "eject"
		and phase ~= "freeze"
		and phase ~= "flash"
		and phase ~= "break"
	then
		return
	end
	local alpha = fx.base_alpha or 1
	if alpha <= 0 then return end
	local base_offset = fx.base_offset or Vector.Zero
	local base_scale = fx.base_scale or 1
	local base_rotation = fx.base_rotation or 0
	local frozen = false
	if phase == "freeze" or phase == "flash" or phase == "break" then
		base_offset = fx.base_freeze_offset or base_offset
		base_scale = fx.base_freeze_scale or base_scale
		base_rotation = fx.base_freeze_rotation or base_rotation
		frozen = true
	end
	local origin = fx.origin or Vector.Zero
	local world = origin + base_offset
	local screen = world_to_entity_render(world, offset)
	local spr = fx.base_spr
	spr.Scale = Vector(base_scale, base_scale)
	spr.Rotation = base_rotation
	paint_shatter_base(spr, fx, { alpha_mul = alpha, frozen = frozen })
	spr:Render(screen, Vector(0, 0), Vector(0, 0))
end

local function request_next_phase(fx, next_phase)
	if not fx then return end
	if fx.debug_stop_after == fx.phase then
		fx.next_phase = "done"
	else
		fx.next_phase = next_phase
	end
end

local function enter_shatter_phase(fx, phase)
	if not fx then return end

	fx.phase = phase
	fx.phase_age = 0
	fx.next_phase = nil

	local player = fx.player
	shatter_phase_log(fx, "ENTER " .. tostring(phase))

	if phase == "recoil" then
		if player then
			sync_player_recoil(player, 0)
		end

	elseif phase == "crack" then
		-- 必须在清 recoil 之前锁定升起后的 Crown pivot
		if player and player.Exists and player:Exists() then
			fx.origin = item.get_crown_world_position(player)
		end
		fire_crack_event(fx)

	elseif phase == "disassemble" then
		if player and player.Exists and player:Exists() then
			local d = player:GetData()
			d[item.own_key.."shatter_holding"] = nil
			d[item.own_key.."sprite_dirty"] = true
			sync_player_recoil(player, nil)
		end
		fx.base_offset = Vector.Zero
		fx.base_scale = 1.08
		fx.base_alpha = 1
		fx.base_rotation = 0
		fx.disassemble_scale_start = 1.08
		for _, p in ipairs(fx.primary_shards or {}) do
			p.visible = true
			p.ejected = true
			p.offset = Vector.Zero
			p.rotation = 0
			-- 在 Disassemble 初始原点种下 Trail 采样点，后续尾巴从王冠中心拉出
			if ENABLE_SHATTER_PRIMARY_TRAIL then
				sync_carrier_to_visual_center(fx, p, nil)
				local carrier = p.trail_carrier
				if carrier and carrier.Exists and carrier:Exists() then
					SpriteTrails.sync(
						carrier,
						p.trail_store,
						"crown_trail",
						crown_release_trail_preset(p)
					)
				end
			end
		end

	elseif phase == "release" then
		-- 从 Disassemble 最终 offset 接着走；不重置位置
		for _, p in ipairs(fx.primary_shards or {}) do
			p.release_start_rotation = p.rotation or 0
			p.release_delay = p.delay or 0
			local vel = p.velocity or Vector.Zero
			p.release_velocity = vel * RELEASE_INITIAL_KICK
		end
		fx.base_release_offset = fx.base_offset or Vector.Zero
		fx.base_release_scale = fx.base_scale or 1.04
		fx.base_alpha = 1

	elseif phase == "eject" then
		-- legacy / Debug only：正式流程不再进入
		fx.eject_started = true
		for _, p in ipairs(fx.primary_shards or {}) do
			p.ejected = true
			p.visible = true
			p.eject_rot_base = p.rotation or 0
			if p.velocity then
				p.velocity = p.velocity * RELEASE_INITIAL_KICK
			end
		end

	elseif phase == "freeze" then
		lock_shatter_shader_phase(fx)
		for _, p in ipairs(fx.primary_shards or {}) do
			hard_freeze_primary(p)
			p.freeze_rotation = p.rotation or 0
			p.freeze_scale = fx.base_scale or 1
		end
		local bo = fx.base_offset or Vector.Zero
		fx.base_freeze_offset = Vector(bo.X, bo.Y)
		fx.base_freeze_scale = fx.base_scale or 1
		fx.base_freeze_rotation = fx.base_rotation or 0
		fx.freeze_age = 0
		fx.base_alpha = 1

	elseif phase == "flash" then
		fx.flash_age = 0
		fx.flash_sfx_played = true
		fx.base_alpha = 1
		sound_tracker.PlayStackedSound(
			SoundEffect.SOUND_HOLY,
			0.28,
			1.55,
			false,
			0,
			2
		)

	elseif phase == "break" then
		fx.base_alpha = 1
		if not fx.burst_spawned then
			shatter_burst(fx)
		end

	elseif phase == "done" then
		drop_shatter_fx(fx)
		fx.primary_shards = {}
		fx.crack_debris = {}
		fx.burst_done = true
	end
end

local function tick_recoil_phase(fx)
	local player = fx.player
	local age = fx.phase_age or 0
	sync_player_recoil(player, age)
	if age >= item.shatter_recoil_frames then
		request_next_phase(fx, "crack")
	end
end

local function tick_crack_phase(fx)
	local player = fx.player
	if player and player.Exists and player:Exists() then
		local d = player:GetData()
		d[item.own_key.."shatter_holding"] = true
		d[item.own_key.."shatter_recoil_y"] = -5
		d[item.own_key.."shatter_recoil_scale"] = 1.10
	end
	-- Crack：只推进 Ring / Debris；Primary 仍隐藏
	if (fx.phase_age or 0) >= (item.shatter_crack_frames or 2) then
		request_next_phase(fx, "disassemble")
	end
end

local function tick_disassemble_phase(fx)
	local age = fx.phase_age or 0
	local frames = item.shatter_disassemble_frames or 4
	local t = smoothstep(math.min(1, age / frames))
	local dist = DISASSEMBLE_DISTANCE[age] or DISASSEMBLE_DISTANCE[4]
	local rot_mul = DISASSEMBLE_ROT_MUL[age] or DISASSEMBLE_ROT_MUL[4]
	fx.base_offset = Vector(0, 1.5 * t)
	fx.base_scale = 1.08 + (1.04 - 1.08) * t
	fx.base_rotation = 0
	fx.base_alpha = 1

	for _, p in ipairs(fx.primary_shards or {}) do
		local exit = p.exit_dir or Vector(0, -1)
		p.visible = true
		p.ejected = true
		p.offset = exit * dist
		p.rotation = (p.rotation_delta or 0) * rot_mul
		if ENABLE_SHATTER_PRIMARY_TRAIL then
			-- 从 Disassemble 起点持续采样，尾巴从王冠初始位置拉出
			sync_carrier_to_visual_center(fx, p, nil)
			local carrier = p.trail_carrier
			if carrier and carrier.Exists and carrier:Exists() then
				SpriteTrails.sync(
					carrier,
					p.trail_store,
					"crown_trail",
					crown_release_trail_preset(p)
				)
			end
		end
	end

	if age >= frames then
		request_next_phase(fx, "release")
	end
end

local function tick_release_base(fx, age)
	local start = fx.base_release_offset or Vector.Zero
	local extra_y = math.min(age, 3) * 0.20
	fx.base_offset = Vector(start.X, start.Y + extra_y)
	fx.base_scale = fx.base_release_scale or 1.04
	fx.base_rotation = 0
	fx.base_alpha = 1
end

local function tick_release_phase(fx)
	local age = fx.phase_age or 0
	local frames = effective_release_frames()
	local t = smoothstep(math.min(1, age / frames))

	for _, p in ipairs(fx.primary_shards or {}) do
		local delay = p.release_delay or p.delay or 0
		p.visible = true
		p.ejected = true

		local moving = age > delay
		if moving then
			local vel = p.release_velocity or Vector.Zero
			p.offset = (p.offset or Vector.Zero) + vel
			p.release_velocity = vel * RELEASE_DAMPING
		end

		if ENABLE_SHATTER_PRIMARY_TRAIL then
			-- delay 中的碎片仍继续同步，保持从 Disassemble 拉出的连续尾巴
			sync_carrier_to_visual_center(fx, p, moving and { lead_velocity = true } or nil)
			local carrier = p.trail_carrier
			if carrier and carrier.Exists and carrier:Exists() then
				SpriteTrails.sync(
					carrier,
					p.trail_store,
					"crown_trail",
					crown_release_trail_preset(p)
				)
			end
		end

		local start_rot = p.release_start_rotation or 0
		p.rotation = start_rot + ((p.rotation_delta or 0) - start_rot) * t
	end

	tick_release_base(fx, age)

	if age >= frames then
		-- 在最后一帧 Release Update 锁相，避免进 Freeze 再晚一帧跳色
		lock_shatter_shader_phase(fx)
		request_next_phase(fx, "freeze")
	end
end

--- legacy / Debug only：正式流程不再进入 eject
local function tick_eject_phase(fx)
	local age = fx.phase_age or 0
	local eject_frames = math.max(1, item.shatter_eject_frames or 6)
	local t = math.min(1, age / eject_frames)
	local st = smoothstep(t)
	fx.base_offset = Vector(0, BASE_EJECT_Y[age] or 5.0)
	fx.base_scale = 1.04 + (1.00 - 1.04) * st
	fx.base_alpha = 1

	for _, p in ipairs(fx.primary_shards or {}) do
		local delay = p.delay or 0
		if age > delay then
			p.ejected = true
			p.visible = true
			p.offset = (p.offset or Vector.Zero) + p.velocity
			p.velocity = p.velocity * 0.92
			local base_rot = p.eject_rot_base or 0
			local remain = (p.rotation_delta or 0) - base_rot
			p.rotation = base_rot + remain * st
			if ENABLE_SHATTER_PRIMARY_TRAIL then
				sync_carrier_to_visual_center(fx, p, { lead_velocity = true })
				local carrier = p.trail_carrier
				if carrier and carrier.Exists and carrier:Exists() then
					SpriteTrails.sync(carrier, p.trail_store, "crown_trail", crown_trail_preset_for(p))
				end
			end
		end
	end

	if age >= eject_frames then
		request_next_phase(fx, "freeze")
	end
end

local function tick_freeze_phase(fx)
	fx.freeze_age = fx.phase_age
	local age = fx.phase_age or 0
	fx.base_alpha = 1
	-- 禁止改 base_offset / scale / rotation：只读 enter 时快照
	if ENABLE_SHATTER_PRIMARY_TRAIL then
		for _, p in ipairs(fx.primary_shards or {}) do
			tick_primary_trail_fade(p)
		end
	end
	if age >= item.shatter_freeze_frames then
		request_next_phase(fx, "flash")
	end
end

local function tick_flash_phase(fx)
	fx.flash_age = fx.phase_age
	fx.base_alpha = 1
	if ENABLE_SHATTER_PRIMARY_TRAIL then
		for _, p in ipairs(fx.primary_shards or {}) do
			if p.trail_fade ~= nil then
				tick_primary_trail_fade(p)
			end
		end
	end
	if (fx.phase_age or 0) >= item.shatter_flash_frames then
		request_next_phase(fx, "break")
	end
end

local function tick_break_phase(fx)
	fx.base_alpha = 1
	if ENABLE_SHATTER_PRIMARY_TRAIL then
		for _, p in ipairs(fx.primary_shards or {}) do
			if p.trail_fade ~= nil then
				tick_primary_trail_fade(p)
			end
		end
	end
	if (fx.phase_age or 0) >= item.shatter_break_frames then
		request_next_phase(fx, "done")
	end
end

local function tick_current_shatter_phase(fx)
	local phase = fx.phase
	fx.phase_age = (fx.phase_age or 0) + 1
	shatter_phase_log(fx, "phase=" .. tostring(phase) .. " phase_age=" .. tostring(fx.phase_age))

	if phase == "recoil" then
		tick_recoil_phase(fx)
	elseif phase == "crack" then
		tick_crack_phase(fx)
	elseif phase == "disassemble" then
		tick_disassemble_phase(fx)
	elseif phase == "release" then
		tick_release_phase(fx)
	elseif phase == "eject" then
		-- legacy only；正式流程不会进入
		tick_eject_phase(fx)
	elseif phase == "freeze" then
		tick_freeze_phase(fx)
	elseif phase == "flash" then
		tick_flash_phase(fx)
	elseif phase == "break" then
		tick_break_phase(fx)
	end

	if phase ~= "done" and phase ~= "recoil" then
		tick_shock_ring(fx)
		tick_crack_debris(fx)
	end
end

local function tick_shatter_fx()
	if Game():IsPaused() then return end
	local remain = {}
	for i = 1, #shatter_fx do
		local fx = shatter_fx[i]
		local player = fx.player
		if not player or not player.Exists or not player:Exists() then
			drop_shatter_fx(fx)
		else
			if fx.next_phase then
				enter_shatter_phase(fx, fx.next_phase)
			end

			if fx.phase == "done" or fx.burst_done then
				-- dropped
			else
				fx.age = (fx.age or 0) + 1
				tick_current_shatter_phase(fx)
				if not (fx.phase == "done" or fx.burst_done) then
					remain[#remain + 1] = fx
				end
			end
		end
	end
	shatter_fx = remain
end

local function render_shatter_fx(player, offset)
	local pk = player_key(player)
	for i = 1, #shatter_fx do
		local fx = shatter_fx[i]
		if fx.player_key == pk and not fx.burst_done then
			local phase = fx.phase or "recoil"
			local phase_age = fx.phase_age or 0
			local flash_age = 0
			local freeze_age = 0
			if phase == "freeze" then
				freeze_age = phase_age
				fx.freeze_age = freeze_age
			elseif phase == "flash" then
				flash_age = phase_age
				fx.flash_age = flash_age
			end
			local buildup = 0
			if phase == "freeze" then
				-- 前 7f 纯定格；后 5f 仅 shader buildup
				buildup = math.max(0, (freeze_age - 7) / 5)
				if buildup > 1 then buildup = 1 end
			end

			local paint_phase = phase
			if phase == "disassemble" or phase == "release" then
				paint_phase = "shatter_move"
			elseif phase == "eject" then
				paint_phase = "scatter"
			end

			render_shock_ring(fx, offset)
			render_crack_debris(fx, offset)
			render_shatter_base(fx, offset)

			local show_primary =
				phase == "disassemble"
				or phase == "release"
				or phase == "eject"
				or phase == "freeze"
				or phase == "flash"
				or phase == "break"

			if show_primary then
				local origin = fx.origin or Vector(0, 0)
				for j = 1, #(fx.primary_shards or {}) do
					local p = fx.primary_shards[j]
					if p.visible ~= false and p.ejected and p.spr then
						local pos_off = p.offset or p.start_offset
						local rot = p.rotation or 0
						if phase == "freeze" or phase == "flash" or phase == "break" then
							pos_off = p.freeze_offset or pos_off
							rot = p.freeze_rotation or rot
						end
						local screen = world_to_entity_render(origin + pos_off, offset)
						p.spr.Rotation = rot
						local scale = 1.0
						local paint_opts = nil
						if phase == "disassemble" or phase == "release" then
							scale = fx.base_scale or 1.08
						elseif phase == "eject" then
							scale = 1.0
						elseif phase == "freeze" then
							scale = p.freeze_scale or 1
							paint_opts = {
								buildup = buildup,
								phase_override = p.freeze_phase,
							}
						elseif phase == "flash" then
							if flash_age <= 1 then
								scale = 1.18
							elseif flash_age == 2 then
								scale = 1.11
							else
								scale = 1.05
							end
							paint_opts = {
								flash_step = flash_age,
								phase_override = p.freeze_phase,
							}
						elseif phase == "break" then
							scale = 0.72
							paint_phase = "break"
							paint_opts = {
								alpha = 0.4,
								phase_override = p.freeze_phase,
							}
						end
						p.spr.Scale = Vector(scale, scale)
						item.paint_glaze_shard_sprite(
							p.spr,
							p.seed,
							paint_phase,
							paint_opts
						)
						p.spr:Render(screen, Vector(0, 0), Vector(0, 0))
					end
				end
			end
		end
	end
end

function item.shatter(player)
	local n = item.get_stacks(player)
	if n <= 0 then return end
	local complete = n >= item.max_stacks
	local d = player:GetData()
	d[item.own_key.."shatter_flash"] = 0
	d[item.own_key.."shatter_holding"] = true
	d[item.own_key.."shatter_hold_stacks"] = n
	d[item.own_key.."awaken"] = nil
	d[item.own_key.."complete"] = nil
	d[item.own_key.."pulse"] = nil
	d[item.own_key.."sprite_dirty"] = true
	cancel_upgrade_fx_for(player)

	local origin_initial = item.get_crown_world_position(player)
	local base_visual_state = crown_visual_state(n)
	local base_roll_seed = tonumber(d[item.own_key.."roll_seed"]) or 0.41
	item.set_stacks(player, 0)

	shatter_seq = shatter_seq + 1
	local token = shatter_seq
	save.elses[item.own_key.."shatter_epoch"] = token
	save.elses[item.own_key.."shatter_dropped"] = false
	local copies = math.max(1, player:GetCollectibleNum(item.entity) or 1)
	local dmg_mul = item.shatter_damage * (1 + 0.15 * (copies - 1))
	local attack_count = shatter_shard_count(n)
	local speed = 10.5 * (player.ShotSpeed or 1)
	local rng = player:GetCollectibleRNG(item.entity)
	rng = auxi.rng_for_sake(rng) or make_rng(player.InitSeed, token + 3)

	local primary_shards = build_primary_shards(n, player, rng)
	local fx = {
		player_key = player_key(player),
		player = player,
		origin_initial = origin_initial,
		-- Crack enter 再锁定升起后的真正碎裂中心；此前仅 fallback
		origin = origin_initial,
		age = 0,
		phase = "recoil",
		phase_age = 0,
		next_phase = nil,
		old_stacks = n,
		complete = complete,
		primary_count = n,
		attack_count = attack_count,
		primary_shards = primary_shards,
		crack_debris = {},
		rng = rng,
		dmg_mul = dmg_mul,
		token = token,
		speed = speed,
		burst_rng_seed = (player.InitSeed or 1) + token * 131 + n * 17,
		seija_penalty = item.is_seija(player) and n or 0,
		burst_done = false,
		burst_spawned = false,
		shader_locked = false,
		flash_sfx_played = false,
		crack_fired = false,
		freeze_age = 0,
		flash_age = 0,
		base_spr = make_shatter_base_sprite(player),
		base_offset = Vector.Zero,
		base_scale = 1.10,
		base_rotation = 0,
		base_alpha = 0,
		base_visual_state = base_visual_state,
		base_roll_seed = base_roll_seed,
		eject_started = false,
	}
	shatter_fx[#shatter_fx + 1] = fx
	enter_shatter_phase(fx, "recoil")
end

--- mode: "recoil" | "crack" | "disassemble" | "release" | "trail" | "full"
--- 旧名 fracture/shock → crack；eject → release。全部走正式 item.shatter。
function item.debug_trigger_shatter_mode(player, mode)
	mode = tostring(mode or "full")
	if not player then return end
	if not item.has_item(player) then return end
	if item.get_stacks(player) <= 0 then
		item.set_stacks(player, 5)
	end
	clear_all_shatter_fx()
	item.shatter(player)
	local fx = shatter_fx[#shatter_fx]
	if not fx then return end
	fx.debug_mode = mode
	if mode == "full" then
		fx.debug_stop_after = nil
	else
		fx.debug_stop_after = DEBUG_STOP_PHASE[mode]
	end
end

local function ensure_debug_particle_sprites()
	if item._debug_particle_sprs then
		return item._debug_particle_sprs
	end
	local sprs = {}
	for i = 1, 5 do
		local spr = Sprite()
		spr:Load(item.crown_anm2, true)
		spr:Play("Particle" .. tostring(i), true)
		sprs[i] = spr
	end
	item._debug_particle_sprs = sprs
	return sprs
end

local function render_debug_particle_overlays(player, offset)
	local show_centers = item._debug_show_particle_centers == true
	local show_recon = item._debug_show_particle_reconstruction == true
	if not show_centers and not show_recon then return end
	local pivot = item.get_crown_pivot_screen(player, offset)
	if show_recon then
		local sprs = ensure_debug_particle_sprites()
		for i = 1, 5 do
			local spr = sprs[i]
			if spr then
				spr.Scale = Vector(1, 1)
				spr.Rotation = 0
				spr.Color = Color(1, 1, 1, 0.65, 0, 0, 0)
				spr:Render(pivot, Vector(0, 0), Vector(0, 0))
			end
		end
	end
	if show_centers and Isaac.RenderText then
		for i = 1, 5 do
			local c = PARTICLE_VISUAL_CENTER[i]
			if c then
				local pos = pivot + Vector(c.X, c.Y)
				Isaac.RenderText("+", pos.X - 2, pos.Y - 3, 1, 0.15, 0.2, 1)
			end
		end
	end
end

--- 一次 Tear Attack → 将该主泪升级为琉璃冠冕弹（core + 4 companion）
--- Ludo 轮模型：本拍若已王冠化 → 仅轮末解绑（不立刻重绑）；未王冠化 → 掷骰绑定。
local function try_fire_crown_companions(player, attack, member, _event)
	if not player or not attack or not member then return end
	if member.Type ~= EntityType.ENTITY_TEAR then return end
	local d = member:GetData()
	local ludo = is_ludo_tear(member)
	local vel = member.Velocity or Vector.Zero
	-- 普通泪仍要求有速度；Ludo 可在近静止时绑定（环绕用 facing=0）
	if not ludo and vel:Length() < 0.2 then return end

	-- 轮末：已绑定则本拍只解绑并飞散，下一次 Once 再竞争新一轮
	if d[item.own_key.."glaze_core"] or d[item.own_key.."glaze_core_visual"] then
		item.clear_glaze_core(member)
		return
	end

	-- 禁止用 InitSeed 重建 RNG：Ludo 同泪会永远同一结果（0% 或 100%）
	local rng = player.GetCollectibleRNG and player:GetCollectibleRNG(item.entity) or nil
	if not rng then
		rng = make_rng((member.InitSeed or 1) + (Game():GetFrameCount() or 0), 91)
	end
	if rng:RandomInt(10000) >= math.floor(item.refract_chance * 10000) then
		return
	end

	d[item.own_key.."glaze_core"] = true
	d[item.own_key.."glaze_proc_seed"] = rng:RandomInt(1000000)
	-- Ludo：无新轮时的时长上限；新 Once 到来会走上方轮末 clear
	if ludo then
		d[item.own_key.."glaze_core_ttl"] = item.glaze_core_ludo_ttl or 30
	end
	apply_glaze_core_visual(member, d[item.own_key.."glaze_proc_seed"])

	for i = 1, #REFRACT_SLOT do
		fire_refract_companion(player, attack, member, i)
	end
end

local function real_hurt(player, amt, flag)
	if not player or (tonumber(amt) or 0) <= 0 then return false end
	if (flag & skip_hurt_flags) ~= 0 then return false end
	if auxi.is_player_has_mantle(player) then return false end
	return true
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	if not item.has_item(player) then return end
	local stacks = item.get_stacks(player)
	if cacheFlag == CacheFlag.CACHE_DAMAGE and stacks >= 1 then
		player.Damage = player.Damage
			+ item.damage_per_stack * stacks * auxi.get_damage_multiplier(player)
	end
	if cacheFlag == CacheFlag.CACHE_LUCK and stacks >= 1 then
		player.Luck = player.Luck + item.luck_per_stack * stacks
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_, ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if not item.has_item(player) then return end
	if not real_hurt(player, amt, flag) then return end
	if item.get_stacks(player) <= 0 then return end
	item.shatter(player)
end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_, ent, amt, flag, source, cooldown)
	if not auxi.check_all_exists(ent) or not auxi.isenemies(ent) then return end
	if (tonumber(amt) or 0) <= 0 then return end
	if not source or not source.Entity then return end
	local src = source.Entity
	local player = src:ToPlayer() or auxi.check_spawner_player(src)
	if not item.has_item(player) then return end
	-- 仅碎冠攻击命中标记（死亡掉落琉璃）；3 层伴飞已改走 POST_ATTACK_ONCE
	if src.Type == EntityType.ENTITY_TEAR then
		local kind = src:GetData()[item.own_key.."kind"]
		if kind == "shatter" then
			ent:GetData()[item.own_key.."hit_shatter"] = src:GetData()[item.own_key.."shatter"]
		end
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_ATTACK_ONCE, params = nil,
Function = function(_, event)
	local player = event and event.player
	local attack = event and event.attack
	local member = event and event.member
	if not player or not attack or not member then return end
	if attack_holder.IsSyntheticSampleAttack(attack) then return end
	if not item.has_item(player) then return end
	if item.get_stacks(player) < item.refract_unlock_stack then return end
	try_fire_crown_companions(player, attack, member, event)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = nil,
Function = function(_, ent)
	if not ent then return end
	local token = ent:GetData()[item.own_key.."hit_shatter"]
	if not token then return end
	if save.elses[item.own_key.."shatter_epoch"] ~= token then return end
	if save.elses[item.own_key.."shatter_dropped"] then return end
	local rng = make_rng(ent.InitSeed, token + 5)
	if rng:RandomInt(10000) >= math.floor(item.shatter_drop_chance * 10000) then return end
	save.elses[item.own_key.."shatter_dropped"] = true
	spawn_weighted_glaze(ent.Position, rng)
end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {CallBack = ModCallbacks.MC_PRE_NPC_COLLISION, params = nil,
Function = function(_, ent, col, low)
	local player = col and col:ToPlayer()
	if not item.should_empower(player) then return end
	if item.is_glazed_enemy(ent) then return true end
end,
})

local function ensure_sprite(player)
	local d = player:GetData()
	if d[item.own_key.."sprite"] then return d[item.own_key.."sprite"] end
	local spr = Sprite()
	spr:Load(item.crown_anm2, true)
	spr:Play("Float0", true)
	d[item.own_key.."sprite"] = spr
	d[item.own_key.."sprite_anim"] = "Float0"
	d[item.own_key.."sprite_dirty"] = true
	d[item.own_key.."roll_seed"] = ((player.InitSeed or 1) % 1000) / 1000
	if REPENTOGON then
		temp_hud.apply_sprite_shader(spr, temp_hud.RAINBOW_ROLL_SHADER)
	end
	return spr
end

local function crown_roll_cfg(stacks)
	local state = crown_visual_state(stacks)
	return item.CROWN_ROLL[state] or item.CROWN_ROLL.dormant
end


--- Complete 仪式统一时间轴（complete_age，30Hz PEFFECT）
local function complete_crown_state(age)
	age = tonumber(age) or 0
	local lift = 0
	local scale = 1.00
	local glow = 0

	if age <= 0 then
		return { lift = 0, scale = 1.00, glow = 0 }
	elseif age <= 5 then
		-- Phase A: Embed Confirm
		local t = smoothstep(age / 5)
		scale = 1.00 + 0.03 * t
		lift = 0
		glow = 0.08 * t
	elseif age <= 12 then
		-- Phase B: Ascend
		local t = smoothstep((age - 6) / 6)
		lift = -4 * t
		scale = 1.03 + 0.11 * t
		glow = 0.08 + 0.22 * t
	elseif age <= 19 then
		-- Phase C: Coronation Hold
		lift = -4
		scale = 1.14
		glow = 0.30
	else
		-- Phase D: Settle (20~30)
		local t = smoothstep((age - 20) / 10)
		lift = -4 * (1 - t)
		scale = 1.14 + (1.00 - 1.14) * t
		glow = 0.30 * (1 - t)
	end

	-- shader 高光窗：10~13 渐亮 / 14~18 最亮 / 19~21 渐回
	if age >= 10 and age <= 21 then
		if age <= 13 then
			glow = smoothstep((age - 10) / 3)
		elseif age <= 18 then
			glow = 1
		else
			glow = 1 - smoothstep((age - 19) / 2)
		end
	end

	return { lift = lift, scale = scale, glow = glow }
end

local function complete_halo_state(age)
	age = tonumber(age) or 0
	if age < 1 then
		return { scale = 0.80, alpha = 0 }
	elseif age <= 4 then
		local t = smoothstep((age - 1) / 3)
		return { scale = 0.80, alpha = 0.18 * t }
	elseif age <= 12 then
		-- Expand：0.80→1.60 / alpha→0.72
		local t = smoothstep((age - 5) / 7)
		return {
			scale = 0.80 + 0.80 * t,
			alpha = 0.18 + 0.54 * t,
		}
	elseif age <= 18 then
		-- Hold 轻呼吸：1.60→1.70→1.60；alpha 峰值约 0.80
		if age <= 15 then
			local t = (age - 13) / 2
			return {
				scale = 1.60 + 0.10 * t,
				alpha = 0.72 + 0.08 * t,
			}
		end
		local t = (age - 15) / 3
		return {
			scale = 1.70 + (1.60 - 1.70) * t,
			alpha = 0.80 + (0.68 - 0.80) * t,
		}
	else
		-- Contract：1.60→1.05，淡出
		local t = smoothstep((age - 19) / 11)
		return {
			scale = 1.60 + (1.05 - 1.60) * t,
			alpha = 0.68 * (1 - t),
		}
	end
end

local function get_complete_visual_state(age)
	local crown = complete_crown_state(age)
	local halo = complete_halo_state(age)
	return {
		crown_lift = crown.lift,
		crown_scale = crown.scale,
		glow = crown.glow,
		halo_scale = halo.scale,
		halo_alpha = halo.alpha,
	}
end

local function is_complete_vfx_active(player)
	if not player then return false end
	local d = player:GetData()
	local age = tonumber(d[item.own_key.."complete_age"]) or 0
	return age >= 1 and age <= (item.complete_frames or 30)
end

local function get_complete_visual_lift(player)
	if not is_complete_vfx_active(player) then return 0 end
	local age = tonumber(player:GetData()[item.own_key.."complete_age"]) or 0
	return complete_crown_state(age).lift or 0
end

local function sync_sprite(player)
	local spr = ensure_sprite(player)
	local d = player:GetData()
	local stacks = item.get_stacks(player)
	local flash = tonumber(d[item.own_key.."shatter_flash"]) or 0
	local hold = tonumber(d[item.own_key.."shatter_hold_stacks"])
	local holding = d[item.own_key.."shatter_holding"]
	-- recoil/crack 期间仍画完整 CrownN；disassemble 起由 Shatter FX 接管
	local display_stacks = stacks
	if holding or (hold and flash > 0) then
		display_stacks = hold or stacks
	elseif flash <= 0 then
		d[item.own_key.."shatter_hold_stacks"] = nil
	end
	local anim = "Float" .. tostring(display_stacks)
	if d[item.own_key.."sprite_anim"] ~= anim or d[item.own_key.."sprite_dirty"] then
		spr:Play(anim, true)
		d[item.own_key.."sprite_anim"] = anim
		d[item.own_key.."sprite_dirty"] = nil
		if REPENTOGON then
			temp_hud.apply_sprite_shader(spr, temp_hud.RAINBOW_ROLL_SHADER)
		end
	end

	local cfg = crown_roll_cfg(display_stacks)
	local alpha = cfg.alpha
	local speed = cfg.speed
	local density = cfg.density
	local gray = cfg.gray
	local bend = cfg.bend
	local contrast = cfg.contrast
	if flash > 0 then
		alpha = 1
		gray = math.min(1, gray + 0.35)
		contrast = math.min(1, contrast + 0.2)
	end
	local complete_age = tonumber(d[item.own_key.."complete_age"])
	local complete_vis = nil
	if complete_age and complete_age >= 1 and complete_age <= (item.complete_frames or 30) then
		complete_vis = get_complete_visual_state(complete_age)
		local glow = complete_vis.glow or 0
		alpha = alpha + (1 - alpha) * glow
		gray = math.min(1, gray + 0.25 * glow)
		contrast = math.min(1, contrast + 0.15 * glow)
	end
	local seed = tonumber(d[item.own_key.."roll_seed"]) or 0.41
	if REPENTOGON then
		spr.Color = temp_hud.make_rainbow_roll_color(
			alpha,
			seed,
			0.05,
			0.95,
			cfg.angle,
			density,
			speed,
			1,
			gray,
			bend,
			contrast,
			false
		)
	else
		spr.Color = Color(1, 1, 1, alpha, 0, 0, 0)
	end

	local scale = 1
	local pulse_left = tonumber(d[item.own_key.."pulse"]) or 0
	local pulse_age = tonumber(d[item.own_key.."pulse_age"]) or 0
	-- Complete 期间禁止 pulse×complete 叠乘
	if pulse_left > 0 and not complete_vis then
		scale = pulse_scale(pulse_age, item.upgrade_pulse_frames)
	end
	if complete_vis then
		scale = scale * (complete_vis.crown_scale or 1)
	end
	local recoil_scale = tonumber(d[item.own_key.."shatter_recoil_scale"])
	if recoil_scale and recoil_scale > 0 then
		scale = scale * recoil_scale
	end
	spr.Scale = Vector(scale, scale)
	return spr
end

local function tick_upgrade_fx()
	if Game():IsPaused() then return end
	local remain = {}
	for i = 1, #upgrade_fx do
		local fx = upgrade_fx[i]
		local player = fx.player
		if player and player.Exists and player:Exists() then
			fx.age = (fx.age or 0) + 1
			if not fx.applied and fx.age >= fx.duration then
				fx.applied = true
				finish_upgrade_embed(player, fx.new_stacks)
			end
			if fx.age < fx.duration + 2 then
				remain[#remain + 1] = fx
			end
		end
	end
	upgrade_fx = remain
end

local function render_awaken_halo(player, offset)
	local d = player:GetData()
	local left = tonumber(d[item.own_key.."awaken"]) or 0
	if left <= 0 then return end
	local age = tonumber(d[item.own_key.."awaken_age"]) or 0
	local total = item.awaken_frames
	local t = age / math.max(1, total)
	local scale = 0.70 + 0.65 * t
	local alpha = 220 * (1 - t)
	local spr = d[item.own_key.."awaken_spr"]
	if not spr then
		spr = Sprite()
		spr:Load(item.crown_anm2, true)
		spr:Play("HaloPulse", true)
		d[item.own_key.."awaken_spr"] = spr
	end
	spr.Scale = Vector(scale, scale)
	spr.Color = Color(0.85, 1, 1, alpha / 255, 0.05, 0.2, 0.25)
	local pos = get_scaled_halo_render_origin(player, offset, scale, 0)
	spr:Render(pos, Vector(0, 0), Vector(0, 0))
end

local function render_complete_halo(player, offset)
	if not is_complete_vfx_active(player) then return end
	local d = player:GetData()
	local age = tonumber(d[item.own_key.."complete_age"]) or 0
	local vis = get_complete_visual_state(age)
	local alpha = vis.halo_alpha or 0
	if alpha <= 0.001 then return end
	local spr = d[item.own_key.."complete_halo_spr"]
	if not spr then
		spr = Sprite()
		spr:Load(item.crown_anm2, true)
		spr:Play("HaloPulse", true)
		d[item.own_key.."complete_halo_spr"] = spr
	end
	local scale = vis.halo_scale or 1
	spr.Scale = Vector(scale, scale)
	spr.Color = Color(0.85, 1, 1, alpha, 0.05, 0.2, 0.25)
	local pos = get_scaled_halo_render_origin(player, offset, scale, vis.crown_lift or 0)
	spr:Render(pos, Vector(0, 0), Vector(0, 0))
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_, player, offset)
	if not item.has_item(player) then return end
	local room = Game():GetRoom()
	if room and room.GetRenderMode and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local spr = sync_sprite(player)
	local pos = item.get_crown_render_position(player, offset)
	local complete_lift = get_complete_visual_lift(player)
	if complete_lift ~= 0 then
		pos = pos + Vector(0, complete_lift)
	end
	local sfx = find_player_shatter_fx(player)
	local hide_crown = false
	if sfx then
		local sp = sfx.phase
		if sp == "disassemble"
			or sp == "release"
			or sp == "eject"
			or sp == "freeze"
			or sp == "flash"
			or sp == "break"
		then
			hide_crown = true
		elseif sp == "crack" then
			local shake = CRACK_SHAKE[sfx.phase_age or 0]
			if shake then
				pos = pos + shake
			end
		end
	end
	-- Halo 在 Crown 后方
	render_awaken_halo(player, offset)
	render_complete_halo(player, offset)
	if not hide_crown then
		spr:Render(pos, Vector(0, 0), Vector(0, 0))
	end
	render_shatter_fx(player, offset)
	render_debug_particle_overlays(player, offset)
	local pk = player_key(player)
	for i = 1, #upgrade_fx do
		local fx = upgrade_fx[i]
		if fx.player_key == pk and fx.spr and not fx.applied then
			local raw_t = (fx.age or 0) / math.max(1, fx.duration)
			local t = smoothstep(raw_t)
			local pivot = item.get_crown_pivot_screen(player, offset)
			local start = pivot + (fx.start_offset or Vector(0, -36))
			local screen = start + (pivot - start) * t
			item.paint_glaze_shard_sprite(fx.spr, fx.roll_seed, "upgrade")
			fx.spr:Render(screen, Vector(0, 0), Vector(0, 0))
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PEFFECT_UPDATE, params = nil,
Function = function(_, player)
	if not item.has_item(player) then return end
	local d = player:GetData()
	local spr = ensure_sprite(player)
	if Game():IsPaused() == false then
		spr:Update()
		if (d[item.own_key.."shatter_flash"] or 0) > 0 then
			d[item.own_key.."shatter_flash"] = d[item.own_key.."shatter_flash"] - 1
		end
		if (d[item.own_key.."pulse"] or 0) > 0 then
			d[item.own_key.."pulse_age"] = (d[item.own_key.."pulse_age"] or 0) + 1
			d[item.own_key.."pulse"] = d[item.own_key.."pulse"] - 1
		end
		if (d[item.own_key.."awaken"] or 0) > 0 then
			d[item.own_key.."awaken_age"] = (d[item.own_key.."awaken_age"] or 0) + 1
			d[item.own_key.."awaken"] = d[item.own_key.."awaken"] - 1
			local aspr = d[item.own_key.."awaken_spr"]
			if aspr then aspr:Update() end
		else
			d[item.own_key.."awaken_spr"] = nil
		end
		if (d[item.own_key.."complete"] or 0) > 0 then
			d[item.own_key.."complete_age"] = (d[item.own_key.."complete_age"] or 0) + 1
			d[item.own_key.."complete"] = d[item.own_key.."complete"] - 1
			local complete_age = d[item.own_key.."complete_age"]
			-- Ascend 起点再播 Holy，与镶嵌石音错开
			if complete_age == 6 and not d[item.own_key.."complete_holy_played"] then
				d[item.own_key.."complete_holy_played"] = true
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_HOLY, 0.35, 1.35, false, 0, 2)
			end
			local chspr = d[item.own_key.."complete_halo_spr"]
			if chspr then chspr:Update() end
		elseif (d[item.own_key.."complete_age"] or 0) > 0 then
			-- 上一帧已播完 age=complete_frames；本帧清理
			d[item.own_key.."complete_age"] = nil
			d[item.own_key.."complete_halo_spr"] = nil
			d[item.own_key.."complete_holy_played"] = nil
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	tick_upgrade_fx()
	tick_shatter_fx()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_, tear)
	local d = tear:GetData()
	local kind = d[item.own_key.."kind"]

	-- 解绑后的飞散冠尖：自由伤害泪，靠弹道落地自然消亡
	if kind == "uncrown_scatter" then
		local spin = tonumber(d[item.own_key.."spin"]) or 8
		local spr = tear:GetSprite()
		if spr then
			spr.Rotation = (spr.Rotation or 0) + spin
		end
		item.paint_shard_roll(tear)
		return
	end

	-- 琉璃主泪：维持 ProjectileBase + 克制滚色；Ludo TTL 到期则解除王冠化
	if d[item.own_key.."glaze_core"] then
		local ttl = d[item.own_key.."glaze_core_ttl"]
		if ttl ~= nil then
			ttl = (tonumber(ttl) or 0) - 1
			d[item.own_key.."glaze_core_ttl"] = ttl
			if ttl <= 0 then
				item.clear_glaze_core(tear)
				return
			end
		end
		local spr = tear:GetSprite()
		if spr and REPENTOGON then
			local anim = spr.GetAnimation and spr:GetAnimation() or ""
			if anim ~= "ProjectileBase" then
				d[item.own_key.."glaze_core_visual"] = nil
				apply_glaze_core_visual(tear, d[item.own_key.."glaze_proc_seed"])
			else
				item.paint_glaze_core(tear)
			end
		end
	end

	-- 4 槽 companion：entity-level 附着维护（非 Attack 判定）
	if kind == "refract" then
		update_refract_companion(tear)
		if not tear.Exists or not tear:Exists() then return end
		local spr = tear:GetSprite()
		local want = d[item.own_key.."companion_anim"]
		if spr and want and REPENTOGON then
			local anim = spr.GetAnimation and spr:GetAnimation() or ""
			if anim ~= want then
				local slot = REFRACT_SLOT[math.floor(tonumber(d[item.own_key.."refract_slot"]) or 0)]
				if slot then
					d[item.own_key.."shard_visual"] = nil
					apply_companion_shard_visual(tear, slot)
				end
			end
		end
		item.paint_shard_roll(tear)
		return
	end

	if kind ~= "shatter" then return end
	local spr = tear:GetSprite()
	if d[item.own_key.."shard_visual"] then
		if spr then
			local anim = spr.GetAnimation and spr:GetAnimation() or ""
			if type(anim) ~= "string" or anim:sub(1, 5) ~= "Shard" then
				d[item.own_key.."shard_visual"] = nil
				apply_shard_visual(tear, make_rng(tear.InitSeed, 77))
				spr = tear:GetSprite()
			end
		end
	elseif REPENTOGON then
		apply_shard_visual(tear, make_rng(tear.InitSeed, 77))
		spr = tear:GetSprite()
	end
	local spin = tonumber(d[item.own_key.."spin"]) or 0
	if spin ~= 0 and spr then
		spr.Rotation = (spr.Rotation or 0) + spin
	end
	item.paint_shard_roll(tear)
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."stacks"] = {}
	end
	save.elses[item.own_key.."stacks"] = save.elses[item.own_key.."stacks"] or {}
	upgrade_fx = {}
	clear_all_shatter_fx()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then return end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if item.has_item(player) and item.get_stacks(player) > 0 then
			player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_LUCK)
			player:GetData().should_evaluate_on_update_once = true
			player:GetData()[item.own_key.."sprite_dirty"] = true
			player:GetData()[item.own_key.."sprite"] = nil
			player:GetData()[item.own_key.."pulse"] = nil
			player:GetData()[item.own_key.."awaken"] = nil
			player:GetData()[item.own_key.."complete"] = nil
		end
	end
	upgrade_fx = {}
	clear_all_shatter_fx()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	clear_all_shatter_fx()
end,
})

function item.install_glaze_crown_pickup_eid(pickup_def, texts, entity_check)
	if not EID or not pickup_def then return end
	local crown = item.entity
	local vr = pickup_def.Variant
	local st = pickup_def.SubType
	local mod_id = "qing_glaze_crown_pickup_"..tostring(vr).."_"..tostring(st)
	EID:addDescriptionModifier(mod_id, function(desc)
		if not item.any_complete() then return false end
		if entity_check then return entity_check(desc) end
		return desc.ObjType == 5 and desc.ObjVariant == vr and desc.ObjSubType == st
	end, function(desc)
		if desc.ObjType ~= 5 then return desc end
		if entity_check then
			if not entity_check(desc) then return desc end
		elseif desc.ObjVariant ~= vr or desc.ObjSubType ~= st then
			return desc
		end
		local lang = auxi.get_EID_language()
		local info = (lang == "zh" or lang == "zh_cn" or lang == "zh_tw") and texts.zh or texts.en
		if info and info ~= "" then
			info = "#"..info
			local repl = "#{{Collectible"..tostring(crown).."}} "
			info = string.gsub(info, "#", repl)
			EID:appendToDescription(desc, info)
		end
		return desc
	end)
end

return item

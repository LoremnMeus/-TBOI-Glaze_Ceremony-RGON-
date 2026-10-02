local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Pause_Screen_holder = require("Qing_Remaster_scripts.others.Pause_Screen_holder")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local electric_chain = require("Qing_Remaster_scripts.auxiliary.electric_chain")

-- Whole Baby sprite vs HUD item center. Not an Eye-layer offset.
local AWAKENING_BABY_OFFSET = Vector(1, -6)

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Abiogenesis,
	familiar = enums.Familiars.Abiogenesis,
	own_key = "Item_Abiogenesis_",
	anm2 = "gfx/mimics/Abiogenesis/Abiogenesis.anm2",
	awakenings = {},
	-- Awakening ceremony (~160 PLAYER_UPDATE ticks @ 60Hz ≈ 2.6s)
	-- Presentation runs fully before COMMIT creates the real Familiar.
	awake_stir_frames = 12,
	awake_mist_frames = 18,
	awake_eye_appear_frames = 12,
	awake_eye_alive_frames = 18,
	awake_body_frames = 14,
	awake_body_hold_frames = 8,
	awake_star_frames = 12,
	awake_reveal_frames = 14,
	awake_hold_frames = 14,
	awake_glide_frames = 36,
	awake_handoff_frames = 2,
	awake_mist_particle_count = 10,
	familiar_visual_offset = Vector(0, -16),
	star_speed = 2.7, -- awakening ceremony only
	star_idle_speed = 1.5,
	eye_lerp = 0.26,
	eye_return_delay = 15,
	orbit_radius = 24,
	weapon_rotate_speed = 12,
	weapon_align_tolerance = 5,
	weapon_switch_pause = 14,
	weapon_charge_frames = 7,
	weapon_recoil_frames = 4,
	weapon_charge_pull = 4,
	weapon_recoil_push = 3,
	initial_charge = 3,
	coin_speed = 19,
	coin_damage = 1.5,
	coin_interval = 2,
	coin_spread = 8,
	key_speed = 22,
	key_damage = 5,
	key_real_chance = 0.30,
	key_interval = 22,
	bomb_speed = 15,
	bomb_damage = 28,
	bomb_radius = 48,
	bomb_fuse = 48,
	bomb_post_fire_cooldown = 65,
	bomb_height = -10,
	bomb_fall_speed = -7.5,
	bomb_fall_accel = 0.75,
	bomb_aim_range = 260,
	bomb_aim_cone = 40,
	bomb_aim_strength = 0.65,
	bomb_lead_strength = 0.55,
	charge_damage = 1.25,
	charge_primary_spread = 40,
	charge_segment_length = 80,
	charge_segment_length_jitter = 50,
	charge_segment_delay = 2,
	charge_segment_turn_base = 40,
	charge_segment_turn_add = 30,
	charge_max_local_turn = 45,
	charge_target_range = 140,
	charge_target_max_turn = 100,
	charge_target_steer = 0.18,
	charge_target_branch_chance = 0.6,
	charge_interval = 18,
	debug_resource_override = {
		enabled = false,
		coin = 0,
		key = 0,
		bomb = 0,
		charge = 0,
	},
	debug_attack_interval_scale = 1,
	layout_velocity_keep = 0.65,
	layout_velocity_chase = 0.12,
	avatar_grow_frames = 12,
	avatar_retire_frames = 12,
	avatar_particle_budget = 12,
	-- Resource icons are Familiar POST_RENDER sprites, not world Effects.
	-- Awakening GLIDE may rewrite state.screen_pos (self-drawn sprite only).
}

auxi.add_to_seija(item.entity)

local RESOURCE_ORDER = {"charge", "coin", "key", "bomb"}
local RESOURCE_DROPS = {
	charge = {Variant = PickupVariant.PICKUP_LIL_BATTERY, SubType = 0},
	coin = {Variant = PickupVariant.PICKUP_COIN, SubType = 0},
	key = {Variant = PickupVariant.PICKUP_KEY, SubType = 0},
	bomb = {Variant = PickupVariant.PICKUP_BOMB, SubType = 0},
}
local RESOURCE_WISPS = {
	charge = item.entity,
	coin = CollectibleType.COLLECTIBLE_WOODEN_NICKEL,
	key = CollectibleType.COLLECTIBLE_DADS_KEY,
	bomb = CollectibleType.COLLECTIBLE_MR_BOOM,
}
local COMBAT_RESOURCE_ORDER = {"coin", "key", "bomb", "charge"}
local COIN_DURATION_BY_TIER = {24, 48, 84, 132, 210}
local CHARGE_DURATION = 32
local CHARGE_PRIMARY_COUNT_BY_TIER = {3, 5, 7, 9, 12}
local CHARGE_DAMAGE_BY_TIER = {1.25, 1.75, 2.25, 3.0, 4.0}
local CHARGE_SEGMENT_COUNTS_BY_TIER = {
	{2, 2, 3},
	{2, 3, 3},
	{3, 3, 4},
	{3, 4, 4},
	{4, 4, 4},
}
local CHARGE_TIMEOUT_BY_DEPTH = {9, 8, 6, 4}
local KEY_SHOTS_BY_TIER = {1, 1, 2, 2, 3}
local KEY_DAMAGE_BY_TIER = {5, 7, 9, 12, 15}
local KEY_INTERVAL_BY_TIER = {24, 20, 16, 12, 8}
local BOMB_COUNT_BY_TIER = {1, 2, 3, 4, 5}
local BOMB_SPREAD_BY_TIER = {0, 8, 12, 16, 20}
local COIN_SPREAD_PATTERN = {0, -3, 4, -6, 2, 7, -2, 5, -7, 1}
local RESOURCE_ORBIT_VISUALS = {
	coin = {anm2 = "gfx/005.021_penny.anm2", anim = "Idle"},
	key = {anm2 = "gfx/005.031_key.anm2", anim = "Idle"},
	bomb = {anm2 = "gfx/005.041_bomb.anm2", anim = "Idle"},
	charge = {anm2 = "gfx/005.090_littlebattery.anm2", anim = "Idle"},
}
-- Tint for short-lived gather/scatter sparkles (EffectVariant.TEAR_POOF_VERYSMALL).
local RESOURCE_PARTICLE_TINT = {
	coin = Color(1.0, 0.85, 0.25, 1),
	key = Color(0.75, 0.88, 1.0, 1),
	bomb = Color(0.45, 0.38, 0.36, 1, 0.2, 0.05, 0.0),
	charge = Color(0.45, 0.8, 1.0, 1, 0.1, 0.2, 0.35),
}
local AVATAR_TARGET_SCALE = 0.5
local _particle_budget_frame = -1
local _particle_budget_left = 0
local EXCLUDE_TEXT = {
	zh = {
		title = "实验记录",
		charge = "根据实验数据，电能本底过高，充能不纳入统计",
		coin = "根据实验数据，货币属混杂因素，硬币不纳入统计",
		key = "根据实验数据，开锁变量不可复现，钥匙不纳入统计",
		bomb = "根据实验数据，爆破冲击污染对照，炸弹不纳入统计",
	},
	en = {
		title = "Lab Notes",
		charge = "Charge treated as background noise and excluded",
		coin = "Coins treated as a confounder and excluded",
		key = "Keys failed replication and were excluded",
		bomb = "Bombs contaminated the control and were excluded",
	},
}

local function proved_bag()
	save.elses[item.own_key.."proved"] = save.elses[item.own_key.."proved"] or {}
	return save.elses[item.own_key.."proved"]
end

function item.get_proved_count(player)
	local idx = player and player:GetData() and player:GetData().__Index
	if idx == nil then return 0 end
	return proved_bag()[idx] or 0
end

function item.add_proved(player)
	local idx = player and player:GetData() and player:GetData().__Index
	if idx == nil then return 0 end
	local bag = proved_bag()
	bag[idx] = (bag[idx] or 0) + 1
	return bag[idx]
end

local function player_idx(player)
	return player and player:GetData() and player:GetData().__Index
end

local function exclude_bag(player)
	local idx = player_idx(player)
	if idx == nil then return nil end
	save.elses[item.own_key.."exclude"] = save.elses[item.own_key.."exclude"] or {}
	save.elses[item.own_key.."exclude"][idx] = save.elses[item.own_key.."exclude"][idx] or {}
	return save.elses[item.own_key.."exclude"][idx]
end

local function is_excluded(player, kind)
	local idx = player_idx(player)
	if idx == nil then return false end
	local root = save.elses[item.own_key.."exclude"]
	local bag = root and root[idx]
	return bag and bag[kind] == true
end

local function clear_exclude(player)
	local idx = player_idx(player)
	if idx == nil then return end
	save.elses[item.own_key.."exclude"] = save.elses[item.own_key.."exclude"] or {}
	save.elses[item.own_key.."exclude"][idx] = {}
end

local function is_zh()
	local lang = Options.Language
	return lang == "zh" or lang == "zh_cn"
end

local function resolve_slot(player, active_slot)
	if active_slot and active_slot >= 0 and player:GetActiveItem(active_slot) == item.entity then
		return active_slot
	end
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		if player:GetActiveItem(slot) == item.entity then
			return slot
		end
	end
	return -1
end

local function slot_charge(player, slot)
	if not slot or slot < 0 then return 0 end
	return (player:GetActiveCharge(slot) or 0) + (player:GetBatteryCharge(slot) or 0)
end

local function raw_resource_amounts(player, slot)
	local keys = player:GetNumKeys() or 0
	local bombs = player:GetNumBombs() or 0
	if player:HasGoldenKey() and keys <= 0 then keys = 1 end
	if player:HasGoldenBomb() and bombs <= 0 then bombs = 1 end
	return {
		charge = slot_charge(player, slot),
		coin = player:GetNumCoins() or 0,
		key = keys,
		bomb = bombs,
	}
end

local function observed_amounts(player, slot)
	local amounts = raw_resource_amounts(player, slot)
	for _, kind in ipairs(RESOURCE_ORDER) do
		if is_excluded(player, kind) then amounts[kind] = 0 end
	end
	return amounts
end

local function extra_costs_ok(player)
	if not player then return false end
	if not is_excluded(player, "coin") and (player:GetNumCoins() or 0) < 1 then return false end
	if not is_excluded(player, "key") and (player:GetNumKeys() or 0) < 1 and not player:HasGoldenKey() then return false end
	if not is_excluded(player, "bomb") and (player:GetNumBombs() or 0) < 1 and not player:HasGoldenBomb() then return false end
	return true
end

local function can_pay(player, slot)
	if not player or not slot or slot < 0 then return false end
	if not is_excluded(player, "charge") and slot_charge(player, slot) < 1 then return false end
	return extra_costs_ok(player)
end

local function consume_cost(player, slot)
	if not is_excluded(player, "coin") then player:AddCoins(-1) end
	if not is_excluded(player, "key") then player:AddKeys(-1) end
	if not is_excluded(player, "bomb") then player:AddBombs(-1) end
	if not is_excluded(player, "charge") then
		player:SetActiveCharge(math.max(0, slot_charge(player, slot) - 1), slot)
	end
end

local function pick_max_resource(amounts, rng)
	local max_v = 0
	local cands = {}
	for _, kind in ipairs(RESOURCE_ORDER) do
		local v = amounts[kind] or 0
		if v > max_v then
			max_v = v
			cands = {kind}
		elseif v == max_v and v > 0 then
			cands[#cands + 1] = kind
		end
	end
	if max_v <= 0 or #cands == 0 then return nil end
	if #cands == 1 then return cands[1] end
	rng = auxi.rng_for_sake(rng)
	if not rng then return cands[1] end
	return cands[rng:RandomInt(#cands) + 1]
end

local function play_fail_feedback(player)
	Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, player.Position, Vector(0, 0), player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBS_DOWN, 1, 1, false, 0, 2)
end

local function spawn_fail_drop(player, kind)
	local drop = RESOURCE_DROPS[kind]
	if not drop then
		play_fail_feedback(player)
		return
	end
	local room = Game():GetRoom()
	local pos = room:FindFreePickupSpawnPosition(player.Position, 10, true)
	Isaac.Spawn(EntityType.ENTITY_PICKUP, drop.Variant, drop.SubType, pos, Vector(0, 0), player)
	Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, pos, Vector(0, 0), player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBS_DOWN, 1, 1, false, 0, 2)
end

local function spawn_resource_wisp(player, kind, useFlags)
	if not kind or not auxi.should_spawn_wisp(player, useFlags) then return end
	local wisp_id = RESOURCE_WISPS[kind]
	if not wisp_id then return end
	player:AddWisp(wisp_id, player.Position, true)
end

local function show_exclude_text(kind)
	local pack = is_zh() and EXCLUDE_TEXT.zh or EXCLUDE_TEXT.en
	local hud = Game():GetHUD()
	if hud and hud.ShowItemText then
		hud:ShowItemText(pack.title, pack[kind] or "")
	end
end

local function belial_exclude_one(player, raw, rng)
	if not auxi.should_do_belial(player) then return end
	local bag = exclude_bag(player)
	if not bag then return end
	local cands = {}
	for _, kind in ipairs(RESOURCE_ORDER) do
		if not bag[kind] and (raw[kind] or 0) > 0 then
			cands[#cands + 1] = kind
		end
	end
	if #cands == 0 then return end
	rng = auxi.rng_for_sake(rng)
	local kind = cands[1]
	if rng and #cands > 1 then
		kind = cands[rng:RandomInt(#cands) + 1]
	end
	bag[kind] = true
	show_exclude_text(kind)
end

local function owner_hash(entity)
	if not entity then return "nil" end
	if GetPtrHash then return tostring(GetPtrHash(entity)) end
	return tostring(entity.InitSeed or entity.Index or 0)
end

local function awakening_key(player, slot)
	return owner_hash(player)..":"..tostring(slot)
end

-- Black mist visual source: same EffectVariant.DUST_CLOUD (59) / "Clouds" as Charon's Sign.
-- Only the sprite asset is reused; do not pull Charon's room-tide system.
local mist_anm2_path = nil
local mist_animation = "Clouds"
local mist_frame_max = 7

local function ensure_mist_source()
	if mist_anm2_path and mist_anm2_path ~= "" then
		return true
	end
	local ok, path = pcall(function()
		local cfg = EntityConfig.GetEntity(EntityType.ENTITY_EFFECT, EffectVariant.DUST_CLOUD, 0)
		return cfg and cfg.GetAnm2Path and cfg:GetAnm2Path()
	end)
	if ok and path and path ~= "" then
		mist_anm2_path = path
		return true
	end
	local room = Game():GetRoom()
	local anchor = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		EffectVariant.DUST_CLOUD,
		0,
		room:GetCenterPos(),
		Vector.Zero,
		nil
	):ToEffect()
	if not anchor then return false end
	local sprite = anchor:GetSprite()
	mist_anm2_path = sprite:GetFilename()
	local anim = sprite:GetAnimation()
	if anim and anim ~= "" then mist_animation = anim end
	anchor:Remove()
	return mist_anm2_path ~= nil and mist_anm2_path ~= ""
end

local function new_mist_sprite(frame)
	local sprite = Sprite()
	if not ensure_mist_source() then return sprite end
	sprite:Load(mist_anm2_path, true)
	sprite:SetFrame(mist_animation, math.max(0, math.min(mist_frame_max, frame or 0)))
	return sprite
end

local function make_awakening_sprite(animation)
	local sprite = Sprite()
	sprite:Load(item.anm2,true)
	sprite:Play(animation or "Idle",true)
	return sprite
end

local function get_awakening(player,slot)
	return item.awakenings[awakening_key(player,slot)]
end

local function find_committing_state(player)
	local hash = owner_hash(player)
	local best
	for _, state in pairs(item.awakenings) do
		if state.player_hash == hash
			and state.committed
			and state.awaiting_familiar
			and not state.familiar
			and not state.done then
			if not best or state.started_frame < best.started_frame then
				best = state
			end
		end
	end
	return best
end

local function refresh_hud_snapshot(state)
	local player = state.player
	if not player or not player:Exists() then return false end
	local info = ui.GetActiveSlotRenderInfo(player,state.slot)
	if info then
		state.hud_alpha = tonumber(info.alpha) or 1
		state.hud_scale = tonumber(info.scale) or 1
		state.hud_pos = ui.ActiveSlotSpriteRenderPos(player,state.slot,state.sprite,0)
		return true
	end
	if not state.hud_pos then
		state.hud_alpha = 1
		state.hud_scale = 1
		state.hud_pos = ui.ActiveSlotSpriteRenderPos(player,state.slot,state.sprite,0)
	end
	return state.hud_pos ~= nil
end

local function refresh_hud_presentation(state)
	local player = state.player
	if not player or not player:Exists() then return false end
	local info = ui.GetActiveSlotRenderInfo(player,state.slot)
	if info then
		state.hud_alpha = tonumber(info.alpha) or state.hud_alpha or 1
		return true
	end
	return false
end

local function smoothstep(edge0, edge1, x)
	if edge1 == edge0 then return 0 end
	local t = math.min(1, math.max(0, (x - edge0) / (edge1 - edge0)))
	return t * t * (3 - 2 * t)
end

local function ease_out_back(t)
	t = math.min(1, math.max(0, t))
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function awakening_bounds()
	local b = {}
	b.stir_end = item.awake_stir_frames
	b.mist_end = b.stir_end + item.awake_mist_frames
	b.eye_appear_end = b.mist_end + item.awake_eye_appear_frames
	b.eye_alive_end = b.eye_appear_end + item.awake_eye_alive_frames
	b.body_end = b.eye_alive_end + item.awake_body_frames
	b.body_hold_end = b.body_end + item.awake_body_hold_frames
	b.star_end = b.body_hold_end + item.awake_star_frames
	b.reveal_end = b.star_end + item.awake_reveal_frames
	b.hold_end = b.reveal_end + item.awake_hold_frames
	b.glide_end = b.hold_end + item.awake_glide_frames
	b.handoff_end = b.glide_end + item.awake_handoff_frames
	return b
end

local function cubic_bezier(p0, p1, p2, p3, t)
	local u = 1 - t
	return p0 * (u * u * u)
		+ p1 * (3 * u * u * t)
		+ p2 * (3 * u * t * t)
		+ p3 * (t * t * t)
end

local function apply_familiar_visual_offset(familiar)
	if familiar and familiar:Exists() then
		familiar.PositionOffset = item.familiar_visual_offset
	end
end

local function familiar_visual_center(familiar)
	return familiar.Position + (familiar.PositionOffset or Vector.Zero)
end

local function reset_particle_budget()
	local frame = Game():GetFrameCount()
	if frame ~= _particle_budget_frame then
		_particle_budget_frame = frame
		_particle_budget_left = item.avatar_particle_budget
	end
end

local function spawn_resource_particle(position, velocity, kind, mode)
	reset_particle_budget()
	if _particle_budget_left <= 0 then return nil end
	_particle_budget_left = _particle_budget_left - 1
	local effect = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		EffectVariant.TEAR_POOF_VERYSMALL,
		0,
		position,
		velocity or Vector.Zero,
		nil
	):ToEffect()
	if not effect then return nil end
	effect.DepthOffset = 40
	effect.SpriteScale = Vector(0.35, 0.35)
	local tint = RESOURCE_PARTICLE_TINT[kind] or Color(1, 1, 1, 1)
	effect.Color = tint
	if effect.Timeout then
		effect.Timeout = (mode == "scatter") and 14 or 12
	end
	return effect
end

local function burst_gather_particles(center, kind, count)
	count = count or 8
	for _ = 1, count do
		local radius = 16 + math.random() * 8
		local offset = RandomVector() * radius
		local pos = center + offset
		local speed = 1.5 + math.random() * 1.5
		local vel = (center - pos)
		if vel:Length() > 0.01 then vel = vel:Resized(speed) else vel = Vector.Zero end
		spawn_resource_particle(pos, vel, kind, "gather")
	end
end

local function burst_scatter_particles(center, kind, count, inherit_vel)
	count = count or 2
	inherit_vel = inherit_vel or Vector.Zero
	for _ = 1, count do
		local speed = 1.5 + math.random() * 2.0
		local vel = RandomVector() * speed + inherit_vel * 0.25
		spawn_resource_particle(center, vel, kind, "scatter")
	end
end

local function init_awakening_mist(state)
	if state.mist_spawned then return end
	if not ensure_mist_source() then
		state.mist_spawned = true
		state.mist_particles = {}
		return
	end
	state.mist_particles = {}
	local count = item.awake_mist_particle_count or 10
	for i = 1, count do
		local radius = 4 + math.random() * 10
		local offset = auxi.random_v2() * radius
		local scale_v = 1.0 + math.random() * 0.8
		local drift_speed = 0.05 + math.random() * 0.20
		state.mist_particles[#state.mist_particles + 1] = {
			sprite = new_mist_sprite(math.random(0, mist_frame_max)),
			offset = offset,
			drift = auxi.random_v2() * drift_speed,
			scale = Vector(scale_v, scale_v),
			rotation = math.random() * 360,
			alpha_mul = 0.55 + math.random() * 0.45,
			frame_offset = math.random(0, mist_frame_max),
			foreground = math.random() < 0.4,
		}
	end
	state.mist_spawned = true
end

local function awakening_mist_alpha(state, bounds)
	local age = state.age or 0
	if age <= bounds.stir_end then
		return 0
	elseif age <= bounds.mist_end then
		local t = (age - bounds.stir_end) / math.max(1, item.awake_mist_frames)
		return smoothstep(0, 1, t)
	elseif age <= bounds.eye_alive_end then
		-- Keep mist nearly opaque while the eye wakes and looks around.
		local t = (age - bounds.mist_end) / math.max(1, bounds.eye_alive_end - bounds.mist_end)
		return 1.0 + (0.90 - 1.0) * smoothstep(0, 1, t)
	elseif age <= bounds.body_end then
		local t = (age - bounds.eye_alive_end) / math.max(1, item.awake_body_frames)
		return 0.90 + (0.78 - 0.90) * smoothstep(0, 1, t)
	elseif age <= bounds.body_hold_end then
		return 0.78
	elseif age <= bounds.star_end then
		local t = (age - bounds.body_hold_end) / math.max(1, item.awake_star_frames)
		return 0.78 + (0.75 - 0.78) * smoothstep(0, 1, t)
	elseif age <= bounds.reveal_end then
		local t = (age - bounds.star_end) / math.max(1, item.awake_reveal_frames)
		return 0.75 + (0.10 - 0.75) * smoothstep(0, 1, t)
	elseif age <= bounds.hold_end then
		local t = (age - bounds.reveal_end) / math.max(1, item.awake_hold_frames)
		return 0.10 * (1 - smoothstep(0, 1, t))
	end
	return 0
end

local function update_awakening_mist(state)
	if not state.mist_particles then return end
	for _, particle in ipairs(state.mist_particles) do
		particle.offset = particle.offset + (particle.drift or Vector.Zero)
		particle.rotation = (particle.rotation or 0) + 0.15
	end
end

local function render_awakening_mist(state, mist_alpha, foreground)
	if mist_alpha <= 0.01 or not state.mist_particles then return end
	local origin = state.item_center_pos or state.hud_pos
	if not origin then return end
	for _, particle in ipairs(state.mist_particles) do
		local is_fg = particle.foreground == true
		if is_fg == foreground and particle.sprite then
			local a = mist_alpha * (particle.alpha_mul or 1)
			-- Charon-style black dust tint.
			particle.sprite.Color = Color(-1, -1, -1, a)
			particle.sprite.Scale = particle.scale or Vector.One
			particle.sprite.Rotation = particle.rotation or 0
			particle.sprite:SetFrame(mist_animation, particle.frame_offset or 0)
			particle.sprite:Render(origin + particle.offset, Vector.Zero, Vector.Zero)
		end
	end
end

local function find_unbound_familiar(player)
	if not player or not player:Exists() then return nil end
	local ph = owner_hash(player)
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
		local fam = ent:ToFamiliar()
		if fam and auxi.check_all_exists(fam) then
			local owner = fam.Player or (fam.SpawnerEntity and fam.SpawnerEntity:ToPlayer())
			if owner and owner_hash(owner) == ph then
				local data = fam:GetData()
				if not data[item.own_key.."bound_awakening"] then
					return fam
				end
			end
		end
	end
	return nil
end

local function bind_awakening_familiar(state, familiar, silent)
	if not state or not familiar or not auxi.check_all_exists(familiar) then return false end
	state.familiar = familiar
	state.awaiting_familiar = false
	local data = familiar:GetData()
	data[item.own_key.."bound_awakening"] = true
	apply_familiar_visual_offset(familiar)
	familiar.Velocity = Vector.Zero
	if silent then
		familiar.Visible = true
		data[item.own_key.."awakening_hidden"] = nil
	else
		familiar.Visible = false
		data[item.own_key.."awakening_hidden"] = true
	end
	return true
end

local function capture_item_center(state)
	if state.item_center_pos or not state.hud_pos then return end
	state.item_center_pos = Vector(state.hud_pos.X, state.hud_pos.Y)
end

local function awakening_baby_screen_pos(state)
	local base = state.item_center_pos or state.hud_pos
	if not base then return nil end
	return base + AWAKENING_BABY_OFFSET
end

local function set_layer(sprite,id,opts)
	if not sprite or not sprite.GetLayer then return end
	local layer = sprite:GetLayer(id)
	if not layer then return end
	opts = opts or {}
	if opts.visible ~= nil and layer.SetVisible then layer:SetVisible(opts.visible) end
	if opts.rotation ~= nil and layer.SetRotation then layer:SetRotation(opts.rotation) end
	if opts.scale and layer.SetSize then layer:SetSize(opts.scale) end
	if opts.offset and layer.SetPos then layer:SetPos(opts.offset) end
	if opts.color and layer.SetColor then
		layer:SetColor(opts.color)
	elseif opts.alpha ~= nil and layer.SetColor then
		local offset = opts.color_offset or 0
		layer:SetColor(Color(1, 1, 1, opts.alpha, offset, offset, offset))
	end
end

local function begin_awakening(player,slot)
	local key = awakening_key(player,slot)
	if item.awakenings[key] then return false end
	local state = {
		key = key,
		player = player,
		player_hash = owner_hash(player),
		slot = slot,
		age = 0,
		phase = "STIR",
		committed = false,
		awaiting_familiar = false,
		done = false,
		visual_baby_ready = false,
		holy_played = false,
		eye_sound_played = false,
		started_frame = Game():GetFrameCount(),
		sprite = make_awakening_sprite("Idle"),
		eye_overlay = make_awakening_sprite("Baby"),
		star_angle = 0,
		screen_pos = nil,
		item_center_pos = nil,
		mist_particles = {},
		mist_spawned = false,
		glide_started = false,
		sprite_draw = true,
		handoff_age = 0,
	}
	item.awakenings[key] = state
	refresh_hud_snapshot(state)
	capture_item_center(state)
	local baby_pos = awakening_baby_screen_pos(state)
	if baby_pos then
		state.screen_pos = Vector(baby_pos.X, baby_pos.Y)
	end
	return true
end

local function clear_awakening_presentation(state)
	if not state then return end
	state.sprite_draw = false
	state.eye_overlay = nil
	state.mist_particles = nil
end

local function prepare_visual_baby(state)
	if state.visual_baby_ready then return end
	state.sprite:Play("Baby", true)
	-- Eye lives on eye_overlay from EYE_APPEAR onward; never draw Eye on main sprite.
	set_layer(state.sprite, 2, {visible = false})
	if state.eye_overlay then
		state.eye_overlay:Play("Baby", true)
		set_layer(state.eye_overlay, 0, {visible = false})
		set_layer(state.eye_overlay, 1, {visible = false})
		set_layer(state.eye_overlay, 2, {visible = false})
	end
	state.visual_baby_ready = true
end

--- Gameplay commit only. No AnimateHappy / mist / holy / glide.
local function commit_awakening_logic(state)
	if not state or state.done then return state and state.familiar or nil end
	local player = state.player
	if not player or not player:Exists() then return nil end

	if not state.committed then
		state.committed = true
		state.awaiting_familiar = true
		item.add_proved(player)
		clear_exclude(player)
		player:RemoveCollectible(item.entity)
		player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
		player:EvaluateItems()
	end

	if (not state.familiar or not auxi.check_all_exists(state.familiar)) and state.awaiting_familiar then
		local found = find_unbound_familiar(player)
		if found then
			bind_awakening_familiar(state, found, false)
		end
	end
	return state.familiar
end

local function finish_awakening_visual(state)
	if not state or state.done then return true end
	local player = state.player
	local familiar = commit_awakening_logic(state)
	if not familiar or not auxi.check_all_exists(familiar) or not player or not player:Exists() then
		return false
	end
	local data = familiar:GetData()
	local screen = state.screen_pos or awakening_baby_screen_pos(state) or state.hud_pos
		or Isaac.WorldToScreen(player.Position)
	familiar.Position = ui.myScreenToWorld(screen)
	familiar.Velocity = Vector.Zero
	apply_familiar_visual_offset(familiar)
	familiar.Visible = true
	data[item.own_key.."awakening_hidden"] = nil
	if not data[item.own_key.."IsFollow"] then
		familiar:AddToFollowers()
		data[item.own_key.."IsFollow"] = true
	end
	clear_awakening_presentation(state)
	state.done = true
	state.phase = "DONE"
	item.awakenings[state.key] = nil
	player:AnimateHappy()
	return true
end

local function finish_awakening_silent(state)
	if not state or state.done then return true end
	local player = state.player
	local familiar = commit_awakening_logic(state)
	if player and player:Exists() then
		if (not familiar or not auxi.check_all_exists(familiar)) then
			player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
			player:EvaluateItems()
			familiar = state.familiar
			if not familiar or not auxi.check_all_exists(familiar) then
				local found = find_unbound_familiar(player)
				if found then
					bind_awakening_familiar(state, found, true)
					familiar = found
				end
			end
		end
	end
	if familiar and auxi.check_all_exists(familiar) and player and player:Exists() then
		local data = familiar:GetData()
		familiar.Position = player.Position + Vector(0, 12)
		familiar.Velocity = Vector.Zero
		apply_familiar_visual_offset(familiar)
		familiar.Visible = true
		data[item.own_key.."awakening_hidden"] = nil
		if not data[item.own_key.."IsFollow"] then
			familiar:AddToFollowers()
			data[item.own_key.."IsFollow"] = true
		end
	end
	clear_awakening_presentation(state)
	state.done = true
	state.phase = "DONE"
	item.awakenings[state.key] = nil
	return true
end

local function force_finish_awakening(state)
	return finish_awakening_silent(state)
end

local function prove(player,slot)
	return begin_awakening(player,slot)
end

local function get_shooting_input(player)
	if player and player.GetShootingInput then
		local direction = player:GetShootingInput()
		if direction and direction:Length() > 0.1 then return direction:Normalized() end
	end
	local fire = player and player:GetFireDirection() or Direction.NO_DIRECTION
	if fire == Direction.LEFT then return Vector(-1,0) end
	if fire == Direction.RIGHT then return Vector(1,0) end
	if fire == Direction.UP then return Vector(0,-1) end
	if fire == Direction.DOWN then return Vector(0,1) end
	return Vector.Zero
end

local function familiar_player(familiar)
	return familiar.Player or (familiar.SpawnerEntity and familiar.SpawnerEntity:ToPlayer())
end

local function make_resource_sprite(kind)
	local visual = RESOURCE_ORBIT_VISUALS[kind]
	local sprite = Sprite()
	sprite:Load(visual.anm2, true)
	sprite:Play(visual.anim or "Idle", true)
	return sprite
end

local function valid_enemy(entity)
	local npc = entity and entity:ToNPC()
	return npc and npc:IsActiveEnemy(false) and npc:IsVulnerableEnemy()
		and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) and npc or nil
end

local function mark_ignore(ent)
	if ent then attack_holder.MarkIgnore(ent) end
	return ent
end

local function ensure_combat(data)
	data.combat = data.combat or {
		phase = "IDLE",
		selected_kind = nil,
		burst_remaining = 0,
		burst_mode = "shots",
		shot_cd = 0,
		charge_cd = 0,
		switch_pause = 0,
		weapon_index = 0,
		coin_shot_index = 0,
		weapon_cooldowns = {
			coin = 0,
			key = 0,
			bomb = 0,
			charge = 0,
		},
	}
	data.combat.weapon_cooldowns = data.combat.weapon_cooldowns or {
		coin = 0,
		key = 0,
		bomb = 0,
		charge = 0,
	}
	data.resources = data.resources or {}
	return data.combat
end

local function resource_orbit_offset(data, visual)
	local angle = (data.star_angle or 0) + (visual.phase or 0)
	local radius = item.orbit_radius + (visual.radial_offset or 0)
	return Vector(radius, 0):Rotated(angle)
end

local function visual_world_pos(familiar, data, visual)
	return familiar.Position
		+ (familiar.PositionOffset or Vector.Zero)
		+ resource_orbit_offset(data, visual)
end

local function resource_tear_muzzle(familiar, data, visual)
	local orbit = resource_orbit_offset(data, visual)
	local pos = familiar.Position + orbit
	local height = (familiar.PositionOffset or Vector.Zero).Y
	return pos, height
end

local function resource_power(amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return 0 end
	if amount <= 2 then return 1 end
	if amount <= 5 then return 2 end
	if amount <= 10 then return 3 end
	if amount <= 20 then return 4 end
	return 5
end

local function combat_amounts(player)
	local ov = item.debug_resource_override
	if ov and ov.enabled then
		return {
			coin = math.max(0, math.floor(ov.coin or 0)),
			key = math.max(0, math.floor(ov.key or 0)),
			bomb = math.max(0, math.floor(ov.bomb or 0)),
			charge = math.max(0, math.floor(ov.charge or 0)),
		}
	end
	local keys = player:GetNumKeys() or 0
	if player:HasGoldenKey() then keys = math.max(keys, 1) end
	local bombs = player:GetNumBombs() or 0
	if player:HasGoldenBomb() then bombs = math.max(bombs, 1) end
	local charge = 0
	for _, slot in ipairs({ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_SECONDARY, ActiveSlot.SLOT_POCKET}) do
		local active = player:GetActiveItem(slot)
		if active and active > 0 then
			charge = charge + slot_charge(player, slot)
		end
	end
	return {
		coin = player:GetNumCoins() or 0,
		key = keys,
		bomb = bombs,
		charge = charge,
	}
end

local function combat_resources(player)
	local amounts = combat_amounts(player)
	return {
		coin = (amounts.coin or 0) > 0,
		key = (amounts.key or 0) > 0,
		bomb = (amounts.bomb or 0) > 0,
		charge = (amounts.charge or 0) > 0,
	}
end

local function burst_plan(kind, amounts)
	local tier = resource_power(amounts[kind] or 0)
	if tier <= 0 then
		return 0, "shots"
	end
	if kind == "coin" then
		return COIN_DURATION_BY_TIER[tier], "frames"
	elseif kind == "charge" then
		return CHARGE_DURATION, "frames"
	elseif kind == "key" then
		return KEY_SHOTS_BY_TIER[tier], "shots"
	elseif kind == "bomb" then
		return 1, "shots"
	end
	return 1, "shots"
end

local function shot_interval(kind, tier)
	local base
	tier = math.max(1, math.min(5, tier or 1))
	if kind == "coin" then
		base = item.coin_interval
	elseif kind == "key" then
		base = KEY_INTERVAL_BY_TIER[tier] or item.key_interval
	elseif kind == "charge" then
		base = item.charge_interval
	else
		return 1
	end
	local scale = tonumber(item.debug_attack_interval_scale) or 1
	return math.max(1, math.floor(base * scale + 0.5))
end

local function charge_segment_count(tier)
	tier = math.max(1, math.min(5, tier or 1))
	local options = CHARGE_SEGMENT_COUNTS_BY_TIER[tier]
	return auxi.choose(options[1], options[2], options[3])
end

local function charge_timeout_for_depth(depth)
	return CHARGE_TIMEOUT_BY_DEPTH[depth] or CHARGE_TIMEOUT_BY_DEPTH[#CHARGE_TIMEOUT_BY_DEPTH]
end

local function initialize_new_abiogenesis_charge(player)
	if not player then return end
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		if player:GetActiveItem(slot) == item.entity then
			local current = (player:GetActiveCharge(slot) or 0) + (player:GetBatteryCharge(slot) or 0)
			if current < item.initial_charge then
				player:SetActiveCharge(item.initial_charge, slot)
			end
			return
		end
	end
end

local function assign_resource_layout(data)
	local active = {}
	for _, kind in ipairs(COMBAT_RESOURCE_ORDER) do
		local visual = data.resources[kind]
		if visual and (visual.state == "ENTER" or visual.state == "SLOT") then
			active[#active + 1] = kind
		end
	end
	local n = #active
	if n <= 0 then return end
	local slots = {}
	for i = 1, n do
		slots[i] = (i - 1) * (360 / n)
	end
	local best_perm, best_cost
	local used = {}
	local perm = {}
	local function search(idx)
		if idx > n then
			local cost = 0
			for i = 1, n do
				local visual = data.resources[perm[i]]
				if visual.phase ~= nil then
					cost = cost + math.abs(auxi.get_correct_angle(slots[i] - visual.phase))
				end
			end
			if not best_cost or cost < best_cost then
				best_cost = cost
				best_perm = {}
				for i = 1, n do best_perm[i] = perm[i] end
			end
			return
		end
		for i = 1, n do
			local kind = active[i]
			if not used[kind] then
				used[kind] = true
				perm[idx] = kind
				search(idx + 1)
				used[kind] = nil
			end
		end
	end
	search(1)
	if not best_perm then return end
	for i = 1, n do
		local visual = data.resources[best_perm[i]]
		visual.target_phase = slots[i]
		if visual.phase == nil then
			visual.phase = slots[i]
			visual.phase_velocity = 0
		end
	end
end

local function tick_resource_layout(data)
	for _, kind in ipairs(COMBAT_RESOURCE_ORDER) do
		local visual = data.resources[kind]
		if visual and visual.phase ~= nil and visual.target_phase ~= nil then
			local delta = auxi.get_correct_angle(visual.target_phase - visual.phase)
			visual.phase_velocity = (visual.phase_velocity or 0) * item.layout_velocity_keep
				+ delta * item.layout_velocity_chase
			visual.phase = (visual.phase + visual.phase_velocity) % 360
		end
	end
end

local function visual_ready(visual)
	return visual and visual.state == "SLOT"
end

local function spawn_muzzle_spark(pos, kind, familiar)
	if kind == "charge" then
		return
	end
	local fx = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		EffectVariant.TEAR_POOF_VERYSMALL,
		0,
		pos,
		Vector.Zero,
		familiar
	):ToEffect()
	if not fx then return end
	fx.DepthOffset = 45
	fx.SpriteScale = Vector(0.45, 0.45)
	if kind == "coin" then
		fx.Color = Color(1.0, 0.85, 0.25, 1)
	elseif kind == "key" then
		fx.Color = Color(0.85, 0.95, 1.0, 1, 0.15, 0.2, 0.25)
	elseif kind == "bomb" then
		fx.Color = Color(0.55, 0.45, 0.35, 1, 0.15, 0.08, 0)
	end
	if fx.Timeout then fx.Timeout = 8 end
end

local function spawn_coin_particle(pos, familiar)
	Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		EffectVariant.COIN_PARTICLE or 98,
		0,
		pos,
		Vector.Zero,
		familiar
	)
end

local function spawn_key_poof(pos, familiar)
	local fx = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		EffectVariant.TEAR_POOF_A or 12,
		0,
		pos,
		Vector.Zero,
		familiar
	):ToEffect()
	if not fx then return end
	local spr = fx:GetSprite()
	spr:Load("gfx/1000.012d_key poof.anm2", true)
	spr:Play("Poof", true)
	fx.DepthOffset = 40
	if fx.Timeout then fx.Timeout = 6 end
end

local function configure_shot_tear(tear, familiar, speed_vec, height, spawner)
	if not tear then return nil end
	mark_ignore(tear)
	tear.Parent = familiar
	tear.SpawnerEntity = spawner or familiar
	tear.Height = tonumber(height) or 0
	tear.FallingSpeed = 0
	tear.FallingAcceleration = 0
	tear.Velocity = speed_vec
	return tear
end

local function fire_coin_shot(familiar, muzzle, direction, shot_index, height)
	shot_index = math.max(1, math.floor(shot_index or 1))
	local pattern_index = ((shot_index - 1) % #COIN_SPREAD_PATTERN) + 1
	local base_offset = COIN_SPREAD_PATTERN[pattern_index]
	local jitter = (math.random() * 2 - 1) * 1.0
	local angle = base_offset + jitter
	angle = math.max(-item.coin_spread, math.min(item.coin_spread, angle))
	local speed_mul = 0.92 + math.random() * 0.16
	local fire_dir = direction:Rotated(angle)
	local vel = fire_dir:Resized(item.coin_speed * speed_mul)
	local ent = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.BLUE, 0, muzzle, vel, familiar)
	local tear = ent and ent:ToTear()
	if not configure_shot_tear(tear, familiar, vel, height) then return end
	tear.CollisionDamage = item.coin_damage
	tear.Scale = 1
	tear.SpriteScale = Vector(0.7, 0.7)
	if tear.AddTearFlags and TearFlags.TEAR_GREED_COIN then
		tear:AddTearFlags(TearFlags.TEAR_GREED_COIN)
	end
	local spr = tear:GetSprite()
	spr:Load("gfx/002.020_coin tear.anm2", true)
	spr.Scale = Vector.One
	spr:Play("Rotate1", true)
	tear:GetData()[item.own_key.."coin_shot"] = true
end

local function fire_key_shot(familiar, muzzle, direction, height, tier)
	local vel = direction:Resized(item.key_speed)
	local player = familiar_player(familiar)
	local real_key = player and math.random() < item.key_real_chance
	tier = math.max(1, math.min(5, tier or 1))
	local variant = real_key and (TearVariant.KEY_BLOOD or 44) or (TearVariant.KEY or 43)
	local subtype = real_key and 1 or 0
	local spawner = real_key and player or familiar
	local ent = Isaac.Spawn(EntityType.ENTITY_TEAR, variant, subtype, muzzle, vel, spawner)
	local tear = ent and ent:ToTear()
	if not configure_shot_tear(tear, familiar, vel, height, spawner) then return end
	tear.CollisionDamage = KEY_DAMAGE_BY_TIER[tier] or item.key_damage
	if tear.AddTearFlags then
		local flags = 0
		if TearFlags.TEAR_PIERCING then
			flags = flags | TearFlags.TEAR_PIERCING
		end
		if TearFlags.TEAR_SPECTRAL then
			flags = flags | TearFlags.TEAR_SPECTRAL
		end
		if flags ~= 0 then
			tear:AddTearFlags(flags)
		end
	end
	local td = tear:GetData()
	td[item.own_key.."key_shot"] = true
	td[item.own_key.."real_key_shot"] = real_key and true or false
end

local function apply_bomb_blast(pos, familiar)
	for _, entity in ipairs(Isaac.FindInRadius(pos, item.bomb_radius, EntityPartition.ENEMY)) do
		local npc = valid_enemy(entity)
		if npc then
			npc:TakeDamage(item.bomb_damage, DamageFlag.DAMAGE_EXPLOSION, EntityRef(familiar), 0)
		end
	end
end

local function pick_bomb_target(muzzle, direction)
	local best, best_score
	local fire_angle = direction:GetAngleDegrees()
	for _, entity in ipairs(Isaac.FindInRadius(muzzle, item.bomb_aim_range, EntityPartition.ENEMY)) do
		local npc = valid_enemy(entity)
		if npc then
			local delta = npc.Position - muzzle
			local dist = delta:Length()
			if dist > 0.01 then
				local angle = math.abs(auxi.get_correct_angle(delta:GetAngleDegrees() - fire_angle))
				if angle <= item.bomb_aim_cone then
					local score = dist / item.bomb_aim_range + angle / item.bomb_aim_cone * 0.7
					if not best_score or score < best_score then
						best, best_score = npc, score
					end
				end
			end
		end
	end
	return best
end

local function bomb_fire_direction(muzzle, input_direction)
	local target = pick_bomb_target(muzzle, input_direction)
	if not target then
		return input_direction
	end
	local delta = target.Position - muzzle
	local dist = delta:Length()
	local travel_frames = dist / math.max(1, item.bomb_speed)
	local lead_frames = math.min(travel_frames, 12)
	local predicted = target.Position + target.Velocity * lead_frames * item.bomb_lead_strength
	local aim = predicted - muzzle
	if aim:LengthSquared() <= 0.001 then
		return input_direction
	end
	aim = aim:Normalized()
	local mixed = input_direction * (1 - item.bomb_aim_strength) + aim * item.bomb_aim_strength
	if mixed:LengthSquared() <= 0.001 then
		return input_direction
	end
	return mixed:Normalized()
end

local function fire_one_bomb(familiar, muzzle, direction)
	local vel = direction:Resized(item.bomb_speed)
	local variant = BombVariant.BOMB_THROWABLE or 13
	local ent = Isaac.Spawn(EntityType.ENTITY_BOMB, variant, 0, muzzle, vel, familiar)
	local bomb = ent and ent:ToBomb()
	if not bomb then return end
	mark_ignore(bomb)
	bomb.Parent = familiar
	bomb.SpawnerEntity = familiar
	bomb.ExplosionDamage = 0
	if bomb.AddEntityFlags and EntityFlag.FLAG_FRIENDLY then
		bomb:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
	end
	if bomb.TryThrow then
		pcall(function()
			bomb:TryThrow(EntityRef(familiar), vel, math.abs(item.bomb_height))
		end)
	end
	bomb.Velocity = vel
	if bomb.SetFallSpeed then bomb:SetFallSpeed(item.bomb_fall_speed) end
	if bomb.SetFallAcceleration then bomb:SetFallAcceleration(item.bomb_fall_accel) end
	if bomb.Height ~= nil then bomb.Height = item.bomb_height end
	if bomb.SetExplosionCountdown then
		bomb:SetExplosionCountdown(item.bomb_fuse)
	end
	bomb:GetData()[item.own_key.."bomb_shot"] = {
		owner = familiar,
		exploded = false,
	}
end

local function fire_bomb_shot(familiar, muzzle, direction, tier)
	tier = math.max(1, math.min(5, tier or 1))
	local count = BOMB_COUNT_BY_TIER[tier] or 1
	local spread = BOMB_SPREAD_BY_TIER[tier] or 0
	local base_dir = bomb_fire_direction(muzzle, direction)
	for i = 1, count do
		local offset = 0
		if count > 1 then
			local t = (i - 1) / (count - 1)
			offset = -spread * 0.5 + spread * t
		end
		fire_one_bomb(familiar, muzzle, base_dir:Rotated(offset))
	end
end

local function charge_segment_length()
	return item.charge_segment_length + auxi.random_2() * item.charge_segment_length_jitter
end

local function charge_laser_end_tangent(laser)
	if not laser then
		return Vector(1, 0)
	end
	local fallback = Vector.FromAngle(laser.Angle or 0)
	if not laser.GetSamples then
		return fallback
	end
	local ok, samples = pcall(function() return laser:GetSamples() end)
	if not ok or not samples or #samples <= 1 then
		return fallback
	end
	local last = samples:Get(#samples - 1)
	local prev = samples:Get(#samples - 2)
	local dir = last - prev
	if dir:LengthSquared() <= 0.001 then
		return fallback
	end
	return dir:Normalized()
end

local function constrain_charge_side(angle, base_angle, side)
	if not side or side == 0 or base_angle == nil then
		return angle
	end
	local offset = auxi.get_correct_angle(angle - base_angle)
	local min_side_angle = 5
	if side < 0 and offset > -min_side_angle then
		offset = -min_side_angle
	elseif side > 0 and offset < min_side_angle then
		offset = min_side_angle
	end
	return base_angle + offset
end

local function pick_charge_target(origin, natural_angle, base_angle, side)
	local best, best_score
	local arc_side = side or 0
	for _, entity in ipairs(Isaac.FindInRadius(origin, item.charge_target_range, EntityPartition.ENEMY)) do
		local npc = valid_enemy(entity)
		if npc then
			local target_pos = npc.Position + (npc.PositionOffset or Vector.Zero)
			local delta = target_pos - origin
			local dist = delta:Length()
			if dist > 0.01 then
				local target_angle = delta:GetAngleDegrees()
				local target_offset = auxi.get_correct_angle(target_angle - (base_angle or natural_angle))
				local wrong_side = (arc_side < 0 and target_offset > 0) or (arc_side > 0 and target_offset < 0)
				local turn = math.abs(auxi.get_correct_angle(target_angle - natural_angle))
				if not wrong_side and turn <= item.charge_target_max_turn then
					local score = dist / item.charge_target_range
						+ turn / item.charge_target_max_turn * 0.8
					if not best_score or score < best_score then
						best, best_score = npc, score
					end
				end
			end
		end
	end
	return best
end

local function charge_next_angle(origin, natural_angle, target, steer)
	if not target then
		return natural_angle
	end
	local target_pos = target.Position + (target.PositionOffset or Vector.Zero)
	local delta = target_pos - origin
	if delta:LengthSquared() <= 0.001 then
		return natural_angle
	end
	local target_angle = delta:GetAngleDegrees()
	local turn = auxi.get_correct_angle(target_angle - natural_angle)
	return natural_angle + turn * steer
end

local function fire_charge_shot(familiar, muzzle, direction, tier)
	local primary_count = CHARGE_PRIMARY_COUNT_BY_TIER[tier] or 3
	local arc_key = item.own_key.."charge_arc"
	local base_angle = direction:GetAngleDegrees()
	for _ = 1, primary_count do
		local offset = auxi.random_2() * item.charge_primary_spread
		local angle = base_angle + offset
		local side = 0
		if offset < -8 then
			side = -1
		elseif offset > 8 then
			side = 1
		end
		local length = charge_segment_length()
		local segment_count = charge_segment_count(tier)
		local damage = CHARGE_DAMAGE_BY_TIER[tier] or item.charge_damage
		local seek_target = math.random() < item.charge_target_branch_chance
		local laser = electric_chain.fire_segment({
			source_entity = familiar,
			from_pos = muzzle,
			from_offset = Vector.Zero,
			angle = angle,
			length = length,
			damage = damage,
			timeout = charge_timeout_for_depth(1),
			one_hit = true,
		})
		if laser and segment_count > 1 then
			laser:GetData()[arc_key] = {
				owner = familiar,
				segments_left = segment_count - 1,
				total_segments = segment_count,
				depth = 1,
				damage = damage * 0.85,
				turn = item.charge_segment_turn_base,
				base_angle = base_angle,
				side = side,
				seek_target = seek_target,
				target = nil,
			}
		end
	end
end

local function update_charge_arc(laser)
	if not laser or not laser.GetData then
		return
	end
	local key = item.own_key.."charge_arc"
	local info = laser:GetData()[key]
	if not info then
		return
	end
	if laser.FrameCount < item.charge_segment_delay then
		return
	end
	-- Current segment may extend only once.
	laser:GetData()[key] = nil
	if (info.segments_left or 0) <= 0 then
		return
	end
	local owner = info.owner
	if not owner or not auxi.check_all_exists(owner) then
		return
	end
	local origin = laser.EndPoint
	if not origin then
		return
	end
	local tangent = charge_laser_end_tangent(laser)
	local current_turn = info.turn or item.charge_segment_turn_base
	local tangent_angle = tangent:GetAngleDegrees()
	local proposed = tangent_angle + auxi.random_2() * current_turn
	local local_delta = auxi.get_correct_angle(proposed - tangent_angle)
	local max_local = item.charge_max_local_turn
	local_delta = math.max(-max_local, math.min(max_local, local_delta))
	local natural_angle = constrain_charge_side(tangent_angle + local_delta, info.base_angle, info.side)
	local target = nil
	if info.seek_target then
		target = info.target
		if not target or not auxi.check_all_exists(target) then
			target = pick_charge_target(origin, natural_angle, info.base_angle, info.side)
			info.target = target
		end
	end
	local next_angle = charge_next_angle(origin, natural_angle, target, item.charge_target_steer)
	next_angle = constrain_charge_side(next_angle, info.base_angle, info.side)
	local next_depth = (info.depth or 1) + 1
	local next_laser = electric_chain.fire_segment({
		source_entity = owner,
		from_pos = origin,
		from_offset = Vector.Zero,
		angle = next_angle,
		length = charge_segment_length(),
		damage = info.damage or (item.charge_damage * 0.85),
		timeout = charge_timeout_for_depth(next_depth),
		one_hit = true,
	})
	if next_laser and info.segments_left > 1 then
		next_laser:GetData()[key] = {
			owner = owner,
			segments_left = info.segments_left - 1,
			total_segments = info.total_segments,
			depth = next_depth,
			damage = info.damage,
			turn = current_turn + item.charge_segment_turn_add,
			base_angle = info.base_angle,
			side = info.side,
			seek_target = info.seek_target,
			target = info.target,
		}
	end
end

local function fire_weapon_shot(familiar, data, kind, direction, amounts)
	local visual = data.resources and data.resources[kind]
	if not visual then return false end
	local visual_muzzle = visual_world_pos(familiar, data, visual)
	local tear_muzzle, tear_height = resource_tear_muzzle(familiar, data, visual)
	visual.recoil_age = item.weapon_recoil_frames
	visual.charge_age = 0
	visual.radial_offset = item.weapon_recoil_push
	local do_muzzle_fx = true
	if kind == "coin" then
		data.combat.coin_shot_index = (data.combat.coin_shot_index or 0) + 1
		do_muzzle_fx = data.combat.coin_shot_index % 3 == 1
	end
	if do_muzzle_fx then
		spawn_muzzle_spark(visual_muzzle, kind, familiar)
	end
	if kind == "coin" then
		fire_coin_shot(familiar, tear_muzzle, direction, data.combat.coin_shot_index, tear_height)
	elseif kind == "key" then
		local tier = resource_power((amounts and amounts.key) or 0)
		fire_key_shot(familiar, tear_muzzle, direction, tear_height, tier)
	elseif kind == "bomb" then
		local tier = resource_power((amounts and amounts.bomb) or 0)
		fire_bomb_shot(familiar, visual_muzzle, direction, tier)
		data.combat.weapon_cooldowns = data.combat.weapon_cooldowns or {
			coin = 0, key = 0, bomb = 0, charge = 0,
		}
		data.combat.weapon_cooldowns.bomb = item.bomb_post_fire_cooldown
	elseif kind == "charge" then
		local tier = resource_power((amounts and amounts.charge) or 0)
		fire_charge_shot(familiar, visual_muzzle, direction, tier)
	end
	return true
end

local function select_next_weapon(data, amounts)
	local combat = data.combat
	local cooldowns = combat.weapon_cooldowns or {}
	local start = combat.weapon_index or 0
	for step = 1, #COMBAT_RESOURCE_ORDER do
		local index = (start + step - 1) % #COMBAT_RESOURCE_ORDER + 1
		local kind = COMBAT_RESOURCE_ORDER[index]
		local ready = (cooldowns[kind] or 0) <= 0
		if (amounts[kind] or 0) > 0 and visual_ready(data.resources[kind]) and ready then
			combat.selected_kind = kind
			combat.weapon_index = index
			local remaining, mode = burst_plan(kind, amounts)
			combat.burst_remaining = remaining
			combat.burst_mode = mode
			combat.shot_cd = 0
			if kind == "coin" then
				combat.coin_shot_index = 0
			end
			return kind
		end
	end
	combat.selected_kind = nil
	combat.burst_remaining = 0
	return nil
end

local function rotate_star_toward(data, target_angle, speed)
	local current = data.star_angle or 0
	local delta = auxi.get_correct_angle(target_angle - current)
	local step = math.max(-speed, math.min(speed, delta))
	data.star_angle = (current + step) % 360
	return auxi.get_correct_angle(target_angle - data.star_angle)
end

local function ensure_baby_pose(familiar,data)
	local sprite = familiar:GetSprite()
	if not sprite:IsPlaying("Baby") then sprite:Play("Baby",true) end
	set_layer(sprite,1,{visible = true,rotation = data.star_angle or 0})
	set_layer(sprite,2,{visible = true,rotation = data.eye_angle or 0})
end

local function update_baby_aim(player,data)
	local direction = get_shooting_input(player)
	local shooting = direction:Length() > 0.1
	local target_angle = 0
	if shooting then
		data.last_fire_dir = direction
		data.eye_hold = item.eye_return_delay
		target_angle = direction:GetAngleDegrees() - Vector(-1,1):GetAngleDegrees()
	elseif (data.eye_hold or 0) > 0 and data.last_fire_dir then
		data.eye_hold = data.eye_hold - 1
		target_angle = data.last_fire_dir:GetAngleDegrees() - Vector(-1,1):GetAngleDegrees()
	end
	local current = data.eye_angle or 0
	data.eye_angle = current + auxi.get_correct_angle(target_angle - current) * item.eye_lerp
	return direction,shooting
end

local function sync_resource_visuals(familiar, player, data)
	local amounts = combat_amounts(player)
	data.resources = data.resources or {}
	local changed = false
	for _, kind in ipairs(COMBAT_RESOURCE_ORDER) do
		local visual = data.resources[kind]
		local present = (amounts[kind] or 0) > 0
		if present then
			if not visual or visual.state == "EXIT" then
				data.resources[kind] = {
					kind = kind,
					sprite = make_resource_sprite(kind),
					alpha = 0,
					scale = 0.15,
					phase = nil,
					target_phase = nil,
					phase_velocity = 0,
					state = "ENTER",
					grow_age = 0,
					retire_age = 0,
					charge_age = 0,
					recoil_age = 0,
					radial_offset = 0,
					particle_tick = 0,
				}
				changed = true
			end
		elseif visual and visual.state ~= "EXIT" then
			visual.state = "EXIT"
			visual.retire_age = 0
			visual.particle_tick = 0
			changed = true
			local combat = data.combat
			if combat and combat.selected_kind == kind then
				combat.phase = "SELECT"
				combat.selected_kind = nil
				combat.burst_remaining = 0
			end
		end
	end
	if changed then assign_resource_layout(data) end
	tick_resource_layout(data)

	for _, kind in ipairs(COMBAT_RESOURCE_ORDER) do
		local visual = data.resources[kind]
		if visual then
			local world = visual_world_pos(familiar, data, visual)
			if visual.sprite and visual.sprite.Update then
				visual.sprite:Update()
			end
			if visual.state == "ENTER" then
				visual.grow_age = math.min(item.avatar_grow_frames, (visual.grow_age or 0) + 1)
				local t = visual.grow_age / item.avatar_grow_frames
				visual.alpha = smoothstep(0.25, 1.0, t)
				visual.scale = AVATAR_TARGET_SCALE * (0.3 + 0.7 * ease_out_back(t))
				visual.particle_tick = (visual.particle_tick or 0) + 1
				if visual.particle_tick == 1 then
					burst_gather_particles(world, kind, 6 + math.random(4))
				elseif visual.particle_tick % 3 == 0 and t < 0.85 then
					burst_gather_particles(world, kind, 1)
				end
				if visual.grow_age >= item.avatar_grow_frames then
					visual.state = "SLOT"
					visual.alpha = 1
					visual.scale = AVATAR_TARGET_SCALE
				end
			elseif visual.state == "SLOT" then
				local scale = AVATAR_TARGET_SCALE
				if (visual.charge_age or 0) > 0 then
					local t = math.min(1, visual.charge_age / item.weapon_charge_frames)
					scale = AVATAR_TARGET_SCALE * (1 + 0.25 * smoothstep(0, 1, t))
					visual.radial_offset = -item.weapon_charge_pull * smoothstep(0, 1, t)
				elseif (visual.recoil_age or 0) > 0 then
					local t = visual.recoil_age / item.weapon_recoil_frames
					scale = AVATAR_TARGET_SCALE * (1 + 0.16 * t)
					visual.radial_offset = item.weapon_recoil_push * t
					visual.recoil_age = visual.recoil_age - 1
					if visual.recoil_age <= 0 then
						visual.radial_offset = 0
					end
				else
					visual.radial_offset = 0
				end
				visual.alpha = 1
				visual.scale = scale
			elseif visual.state == "EXIT" then
				visual.retire_age = (visual.retire_age or 0) + 1
				local progress = math.min(1, visual.retire_age / item.avatar_retire_frames)
				visual.alpha = 1 - progress
				visual.scale = AVATAR_TARGET_SCALE * (1 - 0.6 * progress)
				visual.particle_tick = (visual.particle_tick or 0) + 1
				if visual.particle_tick % 2 == 0 then
					burst_scatter_particles(world, kind, 1)
				end
				if progress >= 1 then
					data.resources[kind] = nil
					assign_resource_layout(data)
				end
			end
		end
	end
	return amounts
end

local function aim_selected_to_muzzle(data, direction)
	local combat = data.combat
	local visual = combat.selected_kind and data.resources[combat.selected_kind]
	if not visual or visual.phase == nil then return 180 end
	local fire_angle = direction:GetAngleDegrees()
	local target = fire_angle - visual.phase
	return rotate_star_toward(data, target, item.weapon_rotate_speed)
end

local function update_baby_combat(familiar,player,data,direction,shooting)
	local combat = ensure_combat(data)
	local amounts = sync_resource_visuals(familiar, player, data)
	local cooldowns = combat.weapon_cooldowns
	if cooldowns then
		for kind, cd in pairs(cooldowns) do
			if (cd or 0) > 0 then
				cooldowns[kind] = math.max(0, cd - 1)
			end
		end
	end
	if not shooting then
		combat.phase = "IDLE"
		combat.selected_kind = nil
		combat.burst_remaining = 0
		combat.shot_cd = 0
		combat.charge_cd = 0
		combat.switch_pause = 0
		if data.resources then
			for _, visual in pairs(data.resources) do
				if type(visual) == "table" then
					visual.charge_age = 0
					visual.radial_offset = 0
				end
			end
		end
		data.star_angle = ((data.star_angle or 0) + item.star_idle_speed) % 360
		return
	end

	if combat.phase == "IDLE" then
		combat.phase = "SELECT"
	end

	if combat.phase == "SELECT" then
		if select_next_weapon(data, amounts) then
			combat.phase = "INDEX"
		else
			data.star_angle = ((data.star_angle or 0) + item.star_idle_speed) % 360
			return
		end
	end

	local kind = combat.selected_kind
	if not kind or (amounts[kind] or 0) <= 0 or not visual_ready(data.resources[kind]) then
		combat.phase = "SELECT"
		combat.selected_kind = nil
		combat.burst_remaining = 0
		if select_next_weapon(data, amounts) then
			combat.phase = "INDEX"
		else
			data.star_angle = ((data.star_angle or 0) + item.star_idle_speed) % 360
		end
		return
	end

	if combat.phase == "INDEX" then
		local remain = aim_selected_to_muzzle(data, direction)
		if math.abs(remain) <= item.weapon_align_tolerance then
			combat.phase = "CHARGE"
			combat.charge_cd = item.weapon_charge_frames
		end
		return
	end

	if combat.phase == "CHARGE" then
		aim_selected_to_muzzle(data, direction)
		local visual = data.resources[combat.selected_kind]
		if visual then
			local elapsed = item.weapon_charge_frames - (combat.charge_cd or 0)
			visual.charge_age = math.max(0, elapsed + 1)
			local t = math.min(1, visual.charge_age / item.weapon_charge_frames)
			visual.radial_offset = -item.weapon_charge_pull * smoothstep(0, 1, t)
		end
		combat.charge_cd = (combat.charge_cd or 0) - 1
		if combat.charge_cd <= 0 then
			combat.phase = "BURST"
			combat.shot_cd = 0
			if visual then
				visual.charge_age = 0
			end
		end
		return
	end

	if combat.phase == "BURST" then
		aim_selected_to_muzzle(data, direction)
		if (combat.shot_cd or 0) > 0 then
			combat.shot_cd = combat.shot_cd - 1
		end
		if combat.burst_mode == "frames" then
			if (combat.shot_cd or 0) <= 0 then
				fire_weapon_shot(familiar, data, kind, direction, amounts)
				combat.shot_cd = shot_interval(kind, resource_power(amounts[kind] or 0))
			end
			combat.burst_remaining = (combat.burst_remaining or 0) - 1
			if combat.burst_remaining <= 0 then
				combat.phase = "COOLDOWN"
				combat.switch_pause = item.weapon_switch_pause
			end
		else
			if (combat.shot_cd or 0) <= 0 and (combat.burst_remaining or 0) > 0 then
				fire_weapon_shot(familiar, data, kind, direction, amounts)
				combat.burst_remaining = combat.burst_remaining - 1
				if combat.burst_remaining <= 0 then
					combat.phase = "COOLDOWN"
					combat.switch_pause = item.weapon_switch_pause
				else
					combat.shot_cd = shot_interval(kind, resource_power(amounts[kind] or 0))
				end
			end
		end
		return
	end

	if combat.phase == "COOLDOWN" then
		combat.switch_pause = (combat.switch_pause or 0) - 1
		if combat.switch_pause <= 0 then
			combat.phase = "SELECT"
			combat.selected_kind = nil
		end
	end
end

local function familiar_render_base(familiar, offset)
	local room = Game():GetRoom()
	local scroll = room.GetRenderScrollOffset and room:GetRenderScrollOffset() or Vector.Zero
	return Isaac.WorldToScreen(familiar.Position + (familiar.PositionOffset or Vector.Zero))
		+ (offset or Vector.Zero)
		- scroll
end

local function render_resource_visuals(familiar, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local data = familiar:GetData()
	if not data.resources then return end
	local base = familiar_render_base(familiar, offset)
	local center = familiar.Position + (familiar.PositionOffset or Vector.Zero)
	local center_screen = Isaac.WorldToScreen(center)
	for _, kind in ipairs(COMBAT_RESOURCE_ORDER) do
		local visual = data.resources[kind]
		if visual and visual.sprite and (visual.alpha or 0) > 0.01 then
			local world = visual_world_pos(familiar, data, visual)
			local screen = base + (Isaac.WorldToScreen(world) - center_screen)
			local scale = visual.scale or AVATAR_TARGET_SCALE
			visual.sprite.Scale = Vector(scale, scale)
			if (visual.charge_age or 0) > 0 then
				local t = visual.charge_age / item.weapon_charge_frames
				visual.sprite.Color = Color(1, 1, 1, visual.alpha or 1, 0.18 * t, 0.18 * t, 0.18 * t)
			else
				visual.sprite.Color = Color(1, 1, 1, visual.alpha or 1)
			end
			visual.sprite:Render(screen, Vector.Zero, Vector.Zero)
		end
	end
end

local function glide_player_screen_target(player)
	local world = player.Position
		+ (player.PositionOffset or Vector.Zero)
		+ Vector(0, -8)
	return Isaac.WorldToScreen(world)
end

local function begin_glide(state)
	local p0 = state.screen_pos or awakening_baby_screen_pos(state)
	if not p0 then return false end
	state.glide_p0 = Vector(p0.X, p0.Y)
	state.glide_started = true
	state.glide_age = 0
	state.phase = "GLIDE"
	return true
end

local function update_glide_controls(state, player)
	local p0 = state.glide_p0
	local p3 = glide_player_screen_target(player)
	local delta = p3 - p0
	local distance = delta:Length()
	local dir = distance > 0.01 and delta:Normalized() or Vector(0, -1)
	local perp = Vector(-dir.Y, dir.X)
	if perp.Y > 0 then perp = -perp end
	local curve = math.min(45, math.max(20, distance * 0.18))
	state.glide_p1 = p0 + dir * math.min(55, distance * 0.30) + perp * curve
	state.glide_p2 = p3 - dir * math.min(70, distance * 0.35) + perp * curve * 0.45
	state.glide_p3 = p3
end

local function resolve_awakening_phase(age, bounds)
	if age <= bounds.stir_end then return "STIR"
	elseif age <= bounds.mist_end then return "MIST_BUILD"
	elseif age <= bounds.eye_appear_end then return "EYE_APPEAR"
	elseif age <= bounds.eye_alive_end then return "EYE_ALIVE"
	elseif age <= bounds.body_end then return "BODY_APPEAR"
	elseif age <= bounds.body_hold_end then return "BODY_HOLD"
	elseif age <= bounds.star_end then return "STAR_APPEAR"
	elseif age <= bounds.reveal_end then return "REVEAL"
	elseif age <= bounds.hold_end then return "HOLD"
	elseif age <= bounds.glide_end then return "GLIDE"
	elseif age <= bounds.handoff_end then return "HANDOFF"
	else return "COMMIT"
	end
end

local function tick_awakening(state)
	local player = state.player
	if not player or not player:Exists() then
		item.awakenings[state.key] = nil
		return
	end
	if Pause_Screen_holder.check_info("Menu") or Pause_Screen_holder.check_info("NoUpdate") then return end
	if state.committed then
		refresh_hud_presentation(state)
	else
		refresh_hud_snapshot(state)
	end
	if not state.hud_pos and not state.item_center_pos and not state.screen_pos then return end
	capture_item_center(state)
	if not state.screen_pos then
		local baby_pos = awakening_baby_screen_pos(state)
		if baby_pos then
			state.screen_pos = Vector(baby_pos.X, baby_pos.Y)
		end
	end

	state.age = (state.age or 0) + 1
	local bounds = awakening_bounds()
	state.phase = resolve_awakening_phase(state.age, bounds)

	if state.age > bounds.stir_end then
		init_awakening_mist(state)
		update_awakening_mist(state)
	end

	-- Pure visual Baby sprite only — no EvaluateItems until COMMIT.
	if state.age > bounds.mist_end then
		prepare_visual_baby(state)
	end

	if state.phase == "EYE_APPEAR" then
		local eye_t = (state.age - bounds.mist_end) / math.max(1, item.awake_eye_appear_frames)
		if eye_t >= 0.70 and not state.eye_sound_played then
			state.eye_sound_played = true
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEVIL_CARD, 0.30, 0.85, false, 0, 1)
		end
	end

	if state.phase == "STAR_APPEAR" or state.phase == "REVEAL" or state.phase == "HOLD"
		or state.phase == "GLIDE" or state.phase == "HANDOFF" or state.phase == "COMMIT" then
		state.star_angle = (state.star_angle + item.star_speed) % 360
	end

	if state.phase == "STAR_APPEAR" then
		local star_t = (state.age - bounds.body_hold_end) / math.max(1, item.awake_star_frames)
		if star_t >= 0.95 and not state.holy_played then
			state.holy_played = true
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_HOLY, 1, 1, false, 0, 2)
		end
	end

	if state.age == bounds.hold_end + 1 or (state.phase == "GLIDE" and not state.glide_started) then
		begin_glide(state)
	end

	if state.glide_started and state.age <= bounds.glide_end then
		state.glide_age = (state.glide_age or 0) + 1
		update_glide_controls(state, player)
		local raw_t = math.min(1, state.glide_age / math.max(1, item.awake_glide_frames))
		local t = raw_t * raw_t * (3 - 2 * raw_t)
		local bezier = cubic_bezier(state.glide_p0, state.glide_p1, state.glide_p2, state.glide_p3, t)
		local bob = math.sin(raw_t * math.pi * 2) * 1.5
		state.screen_pos = bezier + Vector(0, bob)
		state.glide_raw_t = raw_t
	end

	-- COMMIT after GLIDE: create real Familiar; HANDOFF keeps fake Baby covering spawn.
	if state.age > bounds.glide_end then
		state.phase = state.age <= bounds.handoff_end and "HANDOFF" or "COMMIT"
		commit_awakening_logic(state)
		local familiar = state.familiar
		if familiar and auxi.check_all_exists(familiar) then
			local screen = state.screen_pos or awakening_baby_screen_pos(state) or state.hud_pos
				or Isaac.WorldToScreen(player.Position)
			familiar.Position = ui.myScreenToWorld(screen)
			familiar.Velocity = Vector.Zero
			apply_familiar_visual_offset(familiar)
			familiar.Visible = false
			familiar:GetData()[item.own_key.."awakening_hidden"] = true
		end
		state.handoff_age = (state.handoff_age or 0) + 1
		if state.handoff_age >= item.awake_handoff_frames and state.familiar and auxi.check_all_exists(state.familiar) then
			finish_awakening_visual(state)
		elseif state.handoff_age > 10 then
			finish_awakening_silent(state)
		end
	end
end

local function render_awakening_main(state, position, scale, root_alpha, body_a, star_a, body_scale, star_scale)
	if not state.sprite then return end
	set_layer(state.sprite, 0, {
		visible = body_a > 0.01,
		alpha = root_alpha * body_a,
		scale = Vector(body_scale, body_scale),
	})
	set_layer(state.sprite, 1, {
		visible = star_a > 0.01,
		alpha = root_alpha * star_a,
		scale = Vector(star_scale, star_scale),
		rotation = state.star_angle or 0,
	})
	-- Eye is drawn by eye_overlay after foreground mist.
	set_layer(state.sprite, 2, {visible = false})
	state.sprite.Color = Color(1, 1, 1, root_alpha)
	state.sprite.Scale = Vector(scale, scale)
	if body_a > 0.01 or star_a > 0.01 then
		state.sprite:Render(position, Vector.Zero, Vector.Zero)
	end
end

local function render_awakening_eye(state, position, scale, root_alpha, eye_a, eye_sx, eye_sy, look, color_offset)
	if not state.eye_overlay or eye_a <= 0.01 then return end
	local look_v = look or Vector.Zero
	set_layer(state.eye_overlay, 0, {visible = false})
	set_layer(state.eye_overlay, 1, {visible = false})
	set_layer(state.eye_overlay, 2, {
		visible = true,
		alpha = root_alpha * eye_a,
		scale = Vector(eye_sx, eye_sy),
		offset = look_v,
		color_offset = color_offset or 0,
	})
	state.eye_overlay.Color = Color(1, 1, 1, root_alpha)
	state.eye_overlay.Scale = Vector(scale, scale)
	state.eye_overlay:Render(position, Vector.Zero, Vector.Zero)
end

local function render_awakening(state)
	if state.done or state.phase == "DONE" then return end
	if state.sprite_draw == false then return end
	if not state.hud_pos and not state.screen_pos and not state.item_center_pos then return end
	local alpha = state.hud_alpha or 1
	local base_scale = state.hud_scale or 1
	local bounds = awakening_bounds()
	local age = state.age or 0
	local mist_alpha = awakening_mist_alpha(state, bounds) * alpha

	render_awakening_mist(state, mist_alpha, false)

	local position = state.item_center_pos or state.hud_pos
	local scale = base_scale

	if age <= bounds.stir_end then
		-- STIR: Idle sprite only (no eye overlay).
		local local_t = age / math.max(1, bounds.stir_end)
		local shake
		if local_t < 1/3 then shake = 0.8
		elseif local_t < 2/3 then shake = 1.6
		else shake = 2.5 end
		position = (state.item_center_pos or state.hud_pos or position) + Vector(math.sin(age * 2.1) * shake, math.cos(age * 1.8) * shake)
		set_layer(state.sprite,0,{visible = true,alpha = alpha})
		set_layer(state.sprite,1,{visible = false})
		local eye_alpha = math.min(1, age / 4)
		set_layer(state.sprite,2,{visible = true,alpha = alpha * eye_alpha * 0.55,scale = Vector(0.85,0.85)})
		state.sprite.Color = Color(1,1,1,alpha)
		state.sprite.Scale = Vector(scale, scale)
		state.sprite:Render(position, Vector.Zero, Vector.Zero)
		render_awakening_mist(state, mist_alpha, true)

	elseif age <= bounds.mist_end then
		-- MIST_BUILD: Idle fades under mist; no eye overlay.
		local mist_t = (age - bounds.stir_end) / math.max(1, item.awake_mist_frames)
		local item_alpha = alpha * (1 - smoothstep(0.45, 0.95, mist_t))
		position = state.item_center_pos or state.hud_pos or position
		set_layer(state.sprite,0,{visible = item_alpha > 0.02,alpha = item_alpha})
		set_layer(state.sprite,1,{visible = false})
		set_layer(state.sprite,2,{visible = item_alpha > 0.02,alpha = item_alpha,scale = Vector.One})
		if item_alpha > 0.02 then
			state.sprite.Color = Color(1,1,1,item_alpha)
			state.sprite.Scale = Vector(scale, scale)
			state.sprite:Render(position, Vector.Zero, Vector.Zero)
		end
		render_awakening_mist(state, mist_alpha, true)

	elseif state.visual_baby_ready then
		if state.glide_started then
			position = state.screen_pos or awakening_baby_screen_pos(state) or state.hud_pos or position
		else
			position = awakening_baby_screen_pos(state) or state.hud_pos or position
		end

		local eye_a, body_a, star_a = 0, 0, 0
		local eye_sx, eye_sy, body_scale, star_scale = 1, 1, 1, 1
		local look = Vector.Zero

		if age <= bounds.eye_appear_end then
			local t = (age - bounds.mist_end) / math.max(1, item.awake_eye_appear_frames)
			eye_a = smoothstep(0, 1, t)
			local s = 0.65 + 0.35 * ease_out_back(math.min(1, t * 1.15))
			eye_sx, eye_sy = s, s
		elseif age <= bounds.eye_alive_end then
			eye_sx, eye_sy = 1.0, 1.0
			eye_a = 1.0
			look = Vector.Zero
		elseif age <= bounds.body_end then
			local t = (age - bounds.eye_alive_end) / math.max(1, item.awake_body_frames)
			eye_a = 1
			body_a = smoothstep(0, 1, t)
			body_scale = 0.88 + 0.12 * smoothstep(0, 1, t)
		elseif age <= bounds.body_hold_end then
			eye_a, body_a = 1, 1
		elseif age <= bounds.star_end then
			local t = (age - bounds.body_hold_end) / math.max(1, item.awake_star_frames)
			eye_a, body_a = 1, 1
			star_a = smoothstep(0, 1, t)
			star_scale = 0.45 + 0.55 * ease_out_back(math.min(1, t * 1.1))
		else
			eye_a, body_a, star_a = 1, 1, 1
		end

		-- z-order: back mist (already) → Body+Star → foreground mist → Eye
		render_awakening_main(state, position, scale, alpha, body_a, star_a, body_scale, star_scale)
		render_awakening_mist(state, mist_alpha, true)
		render_awakening_eye(state, position, scale, alpha, eye_a, eye_sx, eye_sy, look, 0)
	else
		render_awakening_mist(state, mist_alpha, true)
	end
end


if REPENTOGON and ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE, params = item.entity,
	Function = function(_, _, player, _)
		if not extra_costs_ok(player) then return 13 end
		if is_excluded(player, "charge") then return 0 end
		return 1
	end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, _, rng, player, useFlags, activeSlot)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return {Discharge = false, ShowAnim = false}
	end
	if useFlags & UseFlag.USE_VOID == UseFlag.USE_VOID then
		return {Discharge = false, ShowAnim = false}
	end
	local slot = resolve_slot(player, activeSlot)
	if get_awakening(player,slot) then
		return {Discharge = false, ShowAnim = false}
	end
	if not can_pay(player, slot) then
		play_fail_feedback(player)
		return {Discharge = false, ShowAnim = false}
	end
	consume_cost(player, slot)
	local raw = raw_resource_amounts(player, slot)
	local amounts = observed_amounts(player, slot)
	local all_zero = true
	for _, kind in ipairs(RESOURCE_ORDER) do
		if (amounts[kind] or 0) > 0 then
			all_zero = false
			break
		end
	end
	if all_zero then
		prove(player,slot)
		return {Discharge = false, Remove = false, ShowAnim = false}
	end
	local kind = pick_max_resource(amounts, rng)
	spawn_fail_drop(player, kind)
	spawn_resource_wisp(player, kind, useFlags)
	belial_exclude_one(player, raw, rng)
	return {Discharge = false, Remove = false, ShowAnim = true}
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_, ent)
	if ent.Type ~= 3 or ent.Variant ~= FamiliarVariant.WISP or ent.SubType ~= item.entity then return end
	local drop = RESOURCE_DROPS.charge
	local pos = Game():GetRoom():FindFreePickupSpawnPosition(ent.Position, 10, true)
	Isaac.Spawn(EntityType.ENTITY_PICKUP, drop.Variant, drop.SubType, pos, Vector(0, 0), nil)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	if cacheFlag ~= CacheFlag.CACHE_FAMILIARS then return end
	local cnt = item.get_proved_count(player)
	local cfg = Isaac.GetItemConfig():GetCollectible(item.entity)
	player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), cfg)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_, ent)
	local data = ent:GetData()
	ent:GetSprite():Play("Baby",true)
	data.eye_angle = 0
	data.eye_hold = 0
	data.star_angle = (ent.InitSeed or 0) % 360
	data.resources = {}
	ensure_combat(data)
	data.combat.weapon_index = (ent.InitSeed or ent.Index or 0) % #COMBAT_RESOURCE_ORDER
	local player = familiar_player(ent)
	apply_familiar_visual_offset(ent)
	local awakening = player and find_committing_state(player)
	if awakening then
		bind_awakening_familiar(awakening, ent, false)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_, ent)
	local data = ent:GetData()
	local player = familiar_player(ent)
	if not player then return end
	apply_familiar_visual_offset(ent)
	if data[item.own_key.."awakening_hidden"] then
		ent.Visible = false
		ent.Velocity = Vector.Zero
		return
	end
	if not data[item.own_key.."IsFollow"] then
		ent:AddToFollowers()
		data[item.own_key.."IsFollow"] = true
	end
	ent.Visible = true
	local direction,shooting = update_baby_aim(player,data)
	update_baby_combat(ent,player,data,direction,shooting)
	ensure_baby_pose(ent,data)
	ent:FollowParent()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_FAMILIAR_RENDER, params = item.familiar,
Function = function(_, ent, offset)
	if not ent or ent:GetData()[item.own_key.."awakening_hidden"] then return end
	render_resource_visuals(ent, offset)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = TearVariant.KEY_BLOOD or 44,
Function = function(_, tear, collider, _)
	if not tear then return end
	local td = tear:GetData()
	if not td[item.own_key.."key_shot"] then return end
	local npc = valid_enemy(collider)
	if not npc then return end
	spawn_key_poof(npc.Position, tear.Parent or tear.SpawnerEntity)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = TearVariant.KEY or 43,
Function = function(_, tear, collider, _)
	if not tear then return end
	local td = tear:GetData()
	if not td[item.own_key.."key_shot"] then return end
	local npc = valid_enemy(collider)
	if not npc then return end
	spawn_key_poof(npc.Position, tear.SpawnerEntity or tear.Parent)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = EntityType.ENTITY_TEAR,
Function = function(_, ent)
	if not ent then return end
	local td = ent:GetData()
	if td[item.own_key.."coin_shot"] then
		spawn_coin_particle(ent.Position, ent.SpawnerEntity)
	elseif td[item.own_key.."key_shot"] then
		spawn_key_poof(ent.Position, ent.SpawnerEntity)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_BOMB_UPDATE, params = BombVariant.BOMB_THROWABLE,
Function = function(_, bomb)
	if not bomb then return end
	local bd = bomb:GetData()[item.own_key.."bomb_shot"]
	if type(bd) ~= "table" or bd.exploded then return end
	local spr = bomb:GetSprite()
	local anim = spr and spr:GetAnimation() or nil
	local timed_out = bomb.FrameCount >= (item.bomb_fuse + 1)
	if anim == "Explode" or timed_out then
		bd.exploded = true
		apply_bomb_blast(bomb.Position, bd.owner or bomb.SpawnerEntity)
		if timed_out and anim ~= "Explode" then
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BOMB_EXPLOSION, 0, bomb.Position, Vector.Zero, bd.owner)
			bomb:Remove()
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_LASER_UPDATE,
	params = nil,
	Function = function(_, laser)
		update_charge_arc(laser)
	end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,params = nil,
Function = function(_,player)
	local hash = owner_hash(player)
	local states = {}
	for _,state in pairs(item.awakenings) do
		if state.player_hash == hash then states[#states + 1] = state end
	end
	for _,state in ipairs(states) do tick_awakening(state) end
end,
})

if REPENTOGON and ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM then
	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM,params = nil,
	Function = function(_,player,slot)
		local state = get_awakening(player,slot)
		if state and not state.done and not state.committed then
			refresh_hud_snapshot(state)
			return {HideItem = true}
		end
	end,
	})
end

local awakening_render_callback = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = awakening_render_callback,params = nil,
Function = function(_)
	for _,state in pairs(item.awakenings) do render_awakening(state) end
end,
})

local function refresh_proved_familiars()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if item.get_proved_count(player) > 0 then
			player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
			player:EvaluateItems()
		end
	end
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_, player, colid, cnt, touched)
	-- Fresh acquire only: never crush existing charge, never run on Continue.
	if touched then return end
	if (cnt or 0) <= 0 then return end
	initialize_new_abiogenesis_charge(player)
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	item.awakenings = {}
	if not continue then
		save.elses[item.own_key.."proved"] = {}
		save.elses[item.own_key.."exclude"] = {}
	else
		save.elses[item.own_key.."proved"] = save.elses[item.own_key.."proved"] or {}
		save.elses[item.own_key.."exclude"] = save.elses[item.own_key.."exclude"] or {}
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM,params = nil,
Function = function(_)
	local states = {}
	for _,state in pairs(item.awakenings) do states[#states + 1] = state end
	for _,state in ipairs(states) do finish_awakening_silent(state) end
	-- Leftover world avatars from older builds; icons are now Familiar sprites.
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, enums.Entities.AbiogenesisAvatar, -1, false, false)) do
		if ent and ent.Remove then ent:Remove() end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT,params = nil,
Function = function(_)
	local states = {}
	for _,state in pairs(item.awakenings) do states[#states + 1] = state end
	for _,state in ipairs(states) do finish_awakening_silent(state) end
	-- Game exit teardown: do not scan world or play retire VFX; engine drops entities.
	item.awakenings = {}
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_PRE_GAME_STARTED, params = nil,
Function = function(_)
	refresh_proved_familiars()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	refresh_proved_familiars()
end,
})

local function awakening_phase_ends()
	local b = awakening_bounds()
	return {
		b.stir_end, b.mist_end, b.eye_appear_end, b.eye_alive_end,
		b.body_end, b.body_hold_end, b.star_end, b.reveal_end,
		b.hold_end, b.glide_end, b.handoff_end,
	}
end

local function list_awakenings()
	local states = {}
	for _, state in pairs(item.awakenings) do
		states[#states + 1] = state
	end
	return states
end

--- Debug: 立刻开始「化为宝宝」演出（跳过资源全零判定与消耗）
function item.debug_force_awaken(player)
	player = player or Game():GetPlayer(0)
	if not player or not player.Exists or not player:Exists() then
		return false, "no player"
	end
	if player:GetCollectibleNum(item.entity) <= 0 then
		player:AddCollectible(item.entity, 0, false)
	end
	local slot = resolve_slot(player, ActiveSlot.SLOT_PRIMARY)
	if slot < 0 then
		slot = ActiveSlot.SLOT_PRIMARY
	end
	local existing = get_awakening(player, slot)
	if existing then
		return true, "already awakening", existing
	end
	local ok = begin_awakening(player, slot)
	if not ok then
		return false, "begin failed"
	end
	return true, "started", get_awakening(player, slot)
end

--- Debug: 推进当前觉醒 age（默认 +8，约一阶段）
function item.debug_advance_awakening(amount)
	amount = math.max(1, math.floor(tonumber(amount) or 8))
	local states = list_awakenings()
	if #states < 1 then
		return 0
	end
	for _, state in ipairs(states) do
		state.age = (state.age or 0) + amount
	end
	return #states
end

--- Debug: 跳到下一阶段边界
function item.debug_advance_phase()
	local ends = awakening_phase_ends()
	local states = list_awakenings()
	local n = 0
	for _, state in ipairs(states) do
		local age = state.age or 0
		for _, boundary in ipairs(ends) do
			if age < boundary then
				state.age = boundary
				n = n + 1
				break
			end
		end
	end
	return n
end

--- Debug: 直接跳到宝宝显现（convert + Baby pose）
function item.debug_skip_to_baby()
	local b = awakening_bounds()
	local states = list_awakenings()
	if #states < 1 then
		return 0
	end
	for _, state in ipairs(states) do
		if (state.age or 0) < b.mist_end then
			state.age = b.mist_end
		end
		prepare_visual_baby(state)
	end
	return #states
end

--- Debug: 立刻完成并交接为宝宝 Familiar
function item.debug_force_finish()
	local states = list_awakenings()
	for _, state in ipairs(states) do
		force_finish_awakening(state)
	end
	return #states
end

function item.debug_status_text()
	local player = Game():GetPlayer(0)
	local amounts = player and combat_amounts(player) or {coin = 0, key = 0, bomb = 0, charge = 0}
	local states = list_awakenings()
	local phase = "none"
	if #states >= 1 then
		phase = tostring(states[1].phase or "?")
	end
	local combat_line = "Combat: none"
	if player then
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
			if auxi.check_all_exists(ent) then
				local combat = ent:GetData().combat
				if combat then
					combat_line = string.format(
						"Combat: %s / %s",
						tostring(combat.phase or "IDLE"),
						tostring(combat.selected_kind or "-")
					)
					break
				end
			end
		end
	end
	return table.concat({
		"Awakening: " .. phase,
		string.format("Baby offset: (%.1f, %.1f)", AWAKENING_BABY_OFFSET.X, AWAKENING_BABY_OFFSET.Y),
		combat_line,
		string.format("Resources: %d / %d / %d / %d",
			amounts.coin or 0, amounts.key or 0, amounts.bomb or 0, amounts.charge or 0),
	}, "\n")
end

local RESOURCE_DEBUG_KINDS = {coin = true, key = true, bomb = true, charge = true}
local RESOURCE_DEBUG_PRESETS = {
	[1] = {coin = 10, key = 0, bomb = 0, charge = 0},
	[2] = {coin = 10, key = 0, bomb = 5, charge = 0},
	[3] = {coin = 10, key = 5, bomb = 5, charge = 0},
	[4] = {coin = 10, key = 5, bomb = 5, charge = 6},
}

local function ensure_resource_override()
	item.debug_resource_override = item.debug_resource_override or {
		enabled = false,
		coin = 0,
		key = 0,
		bomb = 0,
		charge = 0,
	}
	return item.debug_resource_override
end

function item.debug_set_resource_override_enabled(v)
	ensure_resource_override().enabled = v == true
end

function item.debug_get_resource_override_enabled()
	return ensure_resource_override().enabled == true
end

function item.debug_set_resource_amount(kind, value)
	if not RESOURCE_DEBUG_KINDS[kind] then return end
	ensure_resource_override()[kind] = math.max(0, math.min(99, math.floor(tonumber(value) or 0)))
end

function item.debug_get_resource_amount(kind)
	if not RESOURCE_DEBUG_KINDS[kind] then return 0 end
	return math.max(0, math.floor(ensure_resource_override()[kind] or 0))
end

function item.debug_set_resource_preset(count)
	local preset = RESOURCE_DEBUG_PRESETS[math.floor(tonumber(count) or 0)]
	if not preset then return end
	local ov = ensure_resource_override()
	ov.enabled = true
	ov.coin = preset.coin
	ov.key = preset.key
	ov.bomb = preset.bomb
	ov.charge = preset.charge
end

function item.restore_debug_defaults()
	item.debug_attack_interval_scale = 1
	item.bomb_speed = 15
	item.bomb_fuse = 48
	item.bomb_fall_speed = -7.5
	item.bomb_fall_accel = 0.75
	local ov = ensure_resource_override()
	ov.enabled = false
	ov.coin = 0
	ov.key = 0
	ov.bomb = 0
	ov.charge = 0
end

return item

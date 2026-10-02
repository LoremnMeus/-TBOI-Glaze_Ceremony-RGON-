-- 悲欢之凶剧：交替面具泪真正戴到脸上；悲剧死亡传播，喜剧拒绝谢幕，凶剧先演后留
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local head_anchor = require("Qing_Remaster_scripts.auxiliary.entity_head_anchor")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")
local enemy_death_guard = require("Qing_Remaster_scripts.auxiliary.enemy_death_guard")
-- Enemy lethal/death-interception semantics are owned by
-- auxiliary/enemy_death_guard.lua.

local KIND_TRAGEDY = 0
local KIND_COMEDY = 1
local TEAR_ANM2 = "gfx/mimics/Drama_of_sorrow_and_joy/Despia_Tear.anm2"
-- Head_1 = smile (comedy), Head_2 = frown (tragedy), Head_3 = fused costume.
local HEAD_ANM2 = {
	tragedy = "gfx/characters/Despia_Head_2.anm2",
	comedy = "gfx/characters/Despia_Head_1.anm2",
	fusion = "gfx/characters/Despia_Head_3.anm2",
}
local HEAD_BASE = 64
local POOF_BLACK = EffectVariant.POOF02
local POOF_BLACK_SUB = 1
local MASK_HEAD_PROFILE = {
	width_mul = 1.00,
	min_scale = 0.52,
	max_scale = 0.82,
}
local MASK_POS_FILTER = 0.50
local MASK_SCALE_FILTER = 0.35
local DRAMA_SPOTLIGHT_ANM2 = "gfx/effects/Drama_of_sorrow_and_joy/comedy_spotlight.anm2"
local DRAMA_STAGE_ANM2 = "gfx/Black.anm2"
local DRAMA_SPOTLIGHT_HOLD = 8
local DRAMA_DIM_DEPTH = 80
local DRAMA_SPOTLIGHT_DEPTH = 100
local COMEDY_SPOTLIGHT_COLOR = Color(1.00, 0.88, 0.48, 0.90, 0.12, 0.07, 0.00)
local FUSION_SPOTLIGHT_COLOR = Color(0.82, 0.52, 1.00, 0.88, 0.10, 0.00, 0.16)
local COMEDY_DIM_ALPHA = 0.07
local FUSION_DIM_ALPHA = 0.11
local DRAMA_DIM_ATTACK_FRAMES = 16
local DRAMA_DIM_HOLD_FRAMES = 8
local DRAMA_DIM_RELEASE_FRAMES = 6

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},

	entity = enums.Items.Drama_of_sorrow_and_joy,
	own_key = "Item_DSOAJ_",
	stage_dim_fx = nil,

	chance = 15,

	-- Tragedy
	tragedy_radius = 150,
	tragedy_damage_mul = 1.5,
	tragedy_hp_mul = 0.04,

	-- Tragicomedy
	fusion_radius = 200,
	fusion_damage_mul = 2.5,
	fusion_hp_mul = 0.07,

	-- Comedy
	comedy_heal_ratio = 0.20,
	fusion_heal_ratio = 0.30,

	-- 对不能转友军者的保底治疗
	comedy_immune_heal_ratio = 0.08,
	fusion_immune_heal_ratio = 0.12,
}

local comedy_convert_blacklist = {
	-- [type] = true / subtype table
}

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

function item.force_mask()
	local debug = debug_root()
	return debug and debug.DramaForceMask == true
end

function item.force_mask_kind()
	local debug = debug_root()
	if not debug then return nil end
	local k = tonumber(debug.DramaMaskKind)
	if k == 1 then return KIND_TRAGEDY end
	if k == 2 then return KIND_COMEDY end
	return nil
end

local function player_slot(player)
	if not player then return 0 end
	local d = player:GetData()
	if d.__Index ~= nil then return d.__Index end
	if player.GetPlayerIndex then return player:GetPlayerIndex() end
	return 0
end

local function next_kind_table()
	save.elses[item.own_key.."next"] = save.elses[item.own_key.."next"] or {}
	return save.elses[item.own_key.."next"]
end

local function get_next_kind(player)
	local tbl = next_kind_table()
	local slot = player_slot(player)
	return tbl[slot] or KIND_TRAGEDY
end

local function set_next_kind(player, kind)
	next_kind_table()[player_slot(player)] = kind
end

local function collectible_rng(player)
	if not player then return nil end
	return auxi.rng_for_sake(player:GetCollectibleRNG(item.entity))
end

local function clamp(v, lo, hi)
	return math.max(lo, math.min(v, hi))
end

local function smoothstep(t)
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function filter_vec2(prev, cur, rate)
	if not cur then
		return prev
	end
	if not prev then
		return Vector(cur.X, cur.Y)
	end
	rate = rate or 0.5
	return prev + (cur - prev) * rate
end

local function filter_scalar(prev, cur, rate)
	if cur == nil then
		return prev
	end
	if prev == nil then
		return cur
	end
	rate = rate or 0.5
	return prev + (cur - prev) * rate
end

local function mark_of(ent)
	if not ent then return nil end
	return ent:GetData()[item.own_key.."mark"]
end

local function ensure_mark(ent, player)
	local data = ent:GetData()
	local mark = data[item.own_key.."mark"]
	if not mark then
		mark = {
			tragedy = false,
			comedy = false,
			player = player,
			settling = false,
			settled = false,
			head_anchor_lock = {},
			mask_face_center = nil,
			mask_face_width = nil,
			mask_face_source = nil,
		}
		data[item.own_key.."mark"] = mark
	end
	if auxi.check_all_exists(player) then
		mark.player = player
	end
	mark.head_anchor_lock = mark.head_anchor_lock or {}
	return mark
end

local function is_fusion(mark)
	return mark and mark.tragedy == true and mark.comedy == true
end

local function resolve_mark_player(mark)
	local player = mark and mark.player
	if auxi.check_all_exists(player) then return player end
	return Game():GetPlayer(0)
end

local function is_comedy_immune(npc)
	return npc
		and npc:GetData()[item.own_key.."comedy_immune"] == true
end

local function set_comedy_immune(npc)
	npc:GetData()[item.own_key.."comedy_immune"] = true
end

local function clear_all_masks(npc)
	if not npc then return end
	npc:GetData()[item.own_key.."mark"] = nil
end

local function blacklist_blocks_convert(npc)
	local row = comedy_convert_blacklist[npc.Type]
	if row == true then return true end
	if type(row) == "table" then
		if row[npc.Variant] == true then return true end
		if row[npc.SubType] == true then return true end
	end
	return false
end

local function can_comedy_convert(npc)
	if not npc or not npc:Exists() then return false end
	if not npc:IsActiveEnemy(false) then return false end
	if not npc:IsVulnerableEnemy() then return false end
	if npc:IsBoss() then return false end
	if npc:HasEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS) then return false end
	if npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return false end
	if npc:HasEntityFlags(EntityFlag.FLAG_CHARM) then return false end
	if blacklist_blocks_convert(npc) then return false end
	return true
end

local function convert_to_friendly(npc, player)
	if not can_comedy_convert(npc) then
		return false
	end
	npc:AddEntityFlags(
		EntityFlag.FLAG_FRIENDLY
		| EntityFlag.FLAG_CHARM
	)
	return npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
end

local function restore_hp(npc, ratio)
	local max_hp = math.max(npc.MaxHitPoints or 0, 1)
	local heal = math.max(1, max_hp * ratio)
	npc.HitPoints = math.min(max_hp, math.max(1, heal))
end

local function is_ludo_tear(ent)
	if not ent or not ent.TearFlags then return false end
	return ent.TearFlags & TearFlags.TEAR_LUDOVICO == TearFlags.TEAR_LUDOVICO
end

local function dress_mask_tear(ent, kind, params)
	params = params or {}
	ent = ent:ToTear()
	if not ent then return nil end
	local d = ent:GetData()
	local s = ent:GetSprite()
	s:Load(TEAR_ANM2, true)
	s:Play(kind == KIND_COMEDY and "Idle1" or "Idle2", true)
	attack_holder.MarkIgnore(ent)
	d[item.own_key.."mask"] = true
	d[item.own_key.."kind"] = kind
	return ent
end

function item.try_convert_mask_tear(player, ent, params)
	params = params or {}
	if not player or not ent or not ent:ToTear() then return nil end
	ent = ent:ToTear()
	local d = ent:GetData()
	if d[item.own_key.."mask"] then return nil end
	if is_ludo_tear(ent) then return nil end
	local rng = collectible_rng(player)
	if not params.Force and not item.force_mask() then
		if not rng or rng:RandomInt(100) >= item.chance then return nil end
	end
	local kind = params.Kind
	if kind == nil then
		kind = item.force_mask_kind()
	end
	if kind == nil then
		kind = get_next_kind(player)
		set_next_kind(player, 1 - kind)
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_PLOP, 0.7, 0.85 + math.random() * 0.3, false, 0, 2)
	return dress_mask_tear(ent, kind, params)
end

local function spawn_light_poof(pos, player, scale, col)
	local poof = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, pos, Vector.Zero, player)
	if not poof then return end
	poof = poof:ToEffect() or poof
	local sc = scale or 1
	poof.SpriteScale = Vector(sc, sc)
	local spr = poof.GetSprite and poof:GetSprite()
	if spr and col then
		spr.Color = col
	end
	if col and poof.SetColor then
		poof:SetColor(col, 20, 1, false, false)
	end
end

local function get_stage_dim()
	local fx = item.stage_dim_fx
	if auxi.check_all_exists(fx) then
		return fx
	end
	item.stage_dim_fx = nil
	return nil
end

local function begin_stage_attack(data, alpha)
	data.stage_dim_state = "attack"
	data.stage_dim_phase_frame = 0
	data.stage_dim_phase_start_alpha = alpha or 0
end

local function clear_stage_dim_ref(ent)
	local fx = item.stage_dim_fx
	if not fx then return end
	if not ent or GetPtrHash(fx) == GetPtrHash(ent) then
		item.stage_dim_fx = nil
	end
end

local function request_stage_dim(alpha, hold)
	alpha = tonumber(alpha) or 0
	if alpha <= 0 then return nil end
	hold = math.max(0, math.floor(tonumber(hold) or DRAMA_DIM_HOLD_FRAMES))
	local fx = get_stage_dim()
	if fx then
		local data = fx:GetData()
		local cur = data.stage_dim_alpha or 0
		local target = math.max(data.stage_dim_target_alpha or 0, alpha)
		data.stage_dim_target_alpha = target
		data.stage_dim_hold = math.max(data.stage_dim_hold or 0, hold)
		if cur >= target - 0.001 then
			data.stage_dim_state = "hold"
			data.stage_dim_alpha = target
			data.stage_dim_phase_frame = 0
		else
			begin_stage_attack(data, cur)
		end
		item.stage_dim_fx = fx
		return fx
	end
	local room = Game():GetRoom()
	local pos = room and room:GetCenterPos() or Vector(320, 280)
	local spawned = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		enums.Entities.ID_EFFECT_MeusNIL,
		0,
		pos,
		Vector.Zero,
		nil
	)
	spawned = spawned and spawned:ToEffect()
	if not spawned then return nil end
	spawned:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	spawned.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	spawned.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	spawned.CollisionDamage = 0
	spawned.Velocity = Vector.Zero
	spawned.DepthOffset = DRAMA_DIM_DEPTH
	if spawned.SortingLayer ~= nil and SortingLayer and SortingLayer.SORTING_NORMAL ~= nil then
		spawned.SortingLayer = SortingLayer.SORTING_NORMAL
	end
	local data = spawned:GetData()
	data[item.own_key .. "stage_dim"] = true
	data.stage_dim_alpha = 0
	data.stage_dim_target_alpha = alpha
	data.stage_dim_hold = hold
	begin_stage_attack(data, 0)
	data.skip_nil_distance_cull = true
	data.removecd = 999999
	data[Nil_holder.own_key .. "work"] = function() return true end
	local spr = spawned:GetSprite()
	spr:Load(DRAMA_STAGE_ANM2, true)
	spr:Play("Idle", true)
	spr.Color = Color(1, 1, 1, 0)
	item.stage_dim_fx = spawned
	return spawned
end

local function update_stage_dim(ent)
	if not ent or not ent.GetData then return end
	local data = ent:GetData()
	if not data[item.own_key .. "stage_dim"] then return end
	item.stage_dim_fx = ent
	local alpha = data.stage_dim_alpha or 0
	local target = data.stage_dim_target_alpha or 0
	local state = data.stage_dim_state or "release"
	if state == "attack" then
		local frame = (data.stage_dim_phase_frame or 0) + 1
		data.stage_dim_phase_frame = frame
		local start_alpha = data.stage_dim_phase_start_alpha or 0
		local u = frame / math.max(1, DRAMA_DIM_ATTACK_FRAMES)
		alpha = start_alpha + (target - start_alpha) * smoothstep(u)
		if frame >= DRAMA_DIM_ATTACK_FRAMES then
			alpha = target
			data.stage_dim_state = "hold"
			data.stage_dim_phase_frame = 0
		end
	elseif state == "hold" then
		alpha = target
		local left = math.max(0, (data.stage_dim_hold or 0) - 1)
		data.stage_dim_hold = left
		if left <= 0 then
			data.stage_dim_state = "release"
			data.stage_dim_phase_frame = 0
			data.stage_dim_phase_start_alpha = alpha
		end
	elseif state == "release" then
		local frame = (data.stage_dim_phase_frame or 0) + 1
		data.stage_dim_phase_frame = frame
		local start_alpha = data.stage_dim_phase_start_alpha or alpha
		local u = frame / math.max(1, DRAMA_DIM_RELEASE_FRAMES)
		alpha = start_alpha * (1 - smoothstep(u))
		if frame >= DRAMA_DIM_RELEASE_FRAMES or alpha <= 0.001 then
			clear_stage_dim_ref(ent)
			ent:Remove()
			return
		end
	end
	data.stage_dim_alpha = alpha
	local spr = ent:GetSprite()
	if spr then
		spr.Color = Color(1, 1, 1, alpha)
	end
end

local function update_drama_spotlight(ent)
	if not ent or not ent.GetData then return end
	local data = ent:GetData()
	if not data[item.own_key .. "drama_spotlight"] then return end

	local target = data[item.own_key .. "spotlight_target"]
	local last_pos = data[item.own_key .. "spotlight_last_pos"]
	local target_alive = target and target.Exists and target:Exists()
	if target_alive then
		local p = target.Position
		ent.Position = Vector(p.X, p.Y)
		data[item.own_key .. "spotlight_last_pos"] = Vector(p.X, p.Y)
	elseif last_pos then
		ent.Position = Vector(last_pos.X, last_pos.Y)
		data[item.own_key .. "spotlight_target"] = nil
	end

	local spr = ent:GetSprite()
	local state = data[item.own_key .. "spotlight_state"]
	if state == "appear" then
		if spr:IsFinished("Appear") then
			data[item.own_key .. "spotlight_state"] = "hold"
		end
	elseif state == "hold" then
		local left = tonumber(data[item.own_key .. "spotlight_hold"]) or 0
		left = left - 1
		data[item.own_key .. "spotlight_hold"] = left
		if left <= 0 then
			data[item.own_key .. "spotlight_state"] = "disappear"
			spr:Play("Disappear", true)
		end
	elseif state == "disappear" then
		if spr:IsFinished("Disappear") then
			ent:Remove()
		end
	end
end

local function spawn_drama_spotlight(pos, player, color, target)
	if not pos then return nil end
	local fx = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		enums.Entities.ID_EFFECT_MeusNIL,
		0,
		pos,
		Vector.Zero,
		player
	)
	fx = fx and fx:ToEffect()
	if not fx then return nil end
	fx:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	fx.CollisionDamage = 0
	fx.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	fx.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	fx.DepthOffset = DRAMA_SPOTLIGHT_DEPTH
	if fx.SortingLayer ~= nil and SortingLayer and SortingLayer.SORTING_NORMAL ~= nil then
		fx.SortingLayer = SortingLayer.SORTING_NORMAL
	end
	local data = fx:GetData()
	data[item.own_key .. "drama_spotlight"] = true
	data[item.own_key .. "spotlight_state"] = "appear"
	data[item.own_key .. "spotlight_hold"] = DRAMA_SPOTLIGHT_HOLD
	data[item.own_key .. "spotlight_target"] = target
	data[item.own_key .. "spotlight_last_pos"] = Vector(pos.X, pos.Y)
	data.skip_nil_distance_cull = true
	data.removecd = 90
	data[Nil_holder.own_key .. "work"] = function() return true end
	local spr = fx:GetSprite()
	spr:Load(DRAMA_SPOTLIGHT_ANM2, true)
	spr:Play("Appear", true)
	spr.Color = color or COMEDY_SPOTLIGHT_COLOR
	return fx
end

local function spawn_comedy_spotlight(npc, player)
	if not npc then return nil end
	request_stage_dim(COMEDY_DIM_ALPHA, DRAMA_DIM_HOLD_FRAMES)
	return spawn_drama_spotlight(npc.Position, player, COMEDY_SPOTLIGHT_COLOR, npc)
end

local function spawn_fusion_spotlight(npc, player)
	if not npc then return nil end
	request_stage_dim(FUSION_DIM_ALPHA, DRAMA_DIM_HOLD_FRAMES)
	return spawn_drama_spotlight(npc.Position, player, FUSION_SPOTLIGHT_COLOR, npc)
end

local function spawn_tragedy_poof(pos, player, fusion)
	local poof = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		POOF_BLACK,
		POOF_BLACK_SUB,
		pos,
		Vector.Zero,
		player
	)
	if not poof then return end
	poof = poof:ToEffect() or poof
	local sc = fusion and 1.15 or 1.0
	poof.SpriteScale = Vector(sc, sc)
	local col = fusion
		and Color(1, 0.55, 0.9, 1, 0.15, 0, 0.18)
		or Color(0.65, 0.45, 0.9, 1, 0.08, 0, 0.15)
	if poof.SetColor then
		poof:SetColor(col, 24, 1, false, false)
	end
	local spr = poof.GetSprite and poof:GetSprite()
	if spr then
		spr.Color = col
	end
end

local function play_mask_apply_feedback(npc, kind, fusion, opts)
	opts = opts or {}
	if fusion then
		npc:SetColor(Color(0.88, 0.60, 1.00, 1.00, 0.12, 0.00, 0.18), 16, 1, false, false)
		spawn_fusion_spotlight(npc, opts.player)
		return
	end
	if kind == KIND_COMEDY then
		npc:SetColor(Color(1, 0.85, 0.35, 1, 0.2, 0.1, 0), 12, 1, false, false)
	else
		npc:SetColor(Color(0.55, 0.35, 0.9, 1, 0.05, 0, 0.2), 12, 1, false, false)
	end
	if opts.propagated then
		spawn_light_poof(npc.Position, npc, 0.65, Color(0.7, 0.45, 1, 1, 0.08, 0, 0.12))
	end
end

local function ensure_mark_sprite(mark, which)
	local key = which .. "_spr"
	if not mark[key] then
		local spr = Sprite()
		spr:Load(HEAD_ANM2[which], true)
		spr:Play("HeadDown", true)
		if spr.SetFrame then
			spr:SetFrame("HeadDown", 0)
		end
		mark[key] = spr
	end
	return mark[key]
end

-- Status-icon visibility gate only (Epiphany-style OverlayEffect hide).
-- Not face/head geometry; placement is owned by entity_head_anchor.
local function overlay_temporarily_hidden(ent)
	local spr = ent.GetSprite and ent:GetSprite()
	if spr and spr.GetNullFrame then
		local nf = spr:GetNullFrame("OverlayEffect")
		if nf and nf.IsVisible and not nf:IsVisible() then
			return true
		end
	end
	return false
end

local function render_mask_sprite(spr, ent, anchor, tint)
	local profile = MASK_HEAD_PROFILE
	local scale = clamp(
		anchor.width * (profile.width_mul or 1) / HEAD_BASE,
		profile.min_scale,
		profile.max_scale
	)
	local alpha = ent:GetSprite().Color.A
	spr.Scale = Vector(scale, scale)
	spr.FlipX = ent:GetSprite().FlipX
	spr.Rotation = 0
	if tint then
		spr.Color = Color(tint[1], tint[2], tint[3], alpha * (tint[4] or 1), tint[5] or 0, tint[6] or 0, tint[7] or 0)
	else
		spr.Color = Color(1, 1, 1, alpha)
	end
	spr:Render(anchor.center, Vector.Zero, Vector.Zero)
end

local apply_mask
local trigger_tragedy_wave

function apply_mask(npc, kind, player, opts)
	opts = opts or {}
	if not auxi.isenemies(npc) then
		return false
	end
	if npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
		return false
	end
	if kind == KIND_COMEDY and is_comedy_immune(npc) then
		return false
	end
	local mark = ensure_mark(npc, player)
	if kind == KIND_TRAGEDY then
		if mark.tragedy then return false end
		mark.tragedy = true
	else
		if mark.comedy then return false end
		mark.comedy = true
	end
	play_mask_apply_feedback(npc, kind, is_fusion(mark), {
		propagated = opts.propagated,
		player = player,
	})
	return true
end

function trigger_tragedy_wave(npc, player, fusion)
	if not npc then return end
	player = player or Game():GetPlayer(0)
	local pos = Vector(npc.Position.X, npc.Position.Y)
	local radius = fusion and item.fusion_radius or item.tragedy_radius
	local damage_mul = fusion and item.fusion_damage_mul or item.tragedy_damage_mul
	local hp_mul = fusion and item.fusion_hp_mul or item.tragedy_hp_mul
	local atk = player and player.Damage or 3.5
	local hp_part = (npc.MaxHitPoints or 0) * hp_mul
	if npc.IsBoss and npc:IsBoss() then
		hp_part = math.min(hp_part, atk * 3)
	end
	local damage = atk * damage_mul + hp_part
	local src_hash = GetPtrHash(npc)

	spawn_tragedy_poof(pos, player, fusion)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_BURST_LARGE, 0.85, 0.9 + math.random() * 0.2, false, 0, 2)

	local function in_wave(ent)
		if not ent then return false end
		if GetPtrHash(ent) == src_hash then return false end
		if not ent:IsActiveEnemy(false) then return false end
		if not ent:IsVulnerableEnemy() then return false end
		if ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return false end
		return ent.Position:Distance(pos) <= radius
	end

	local targets = auxi.getenemies(Isaac.GetRoomEntities(), in_wave)
	for i = 1, #targets do
		local target = targets[i]
		if auxi.check_all_exists(target) then
			target:TakeDamage(damage, DamageFlag.DAMAGE_CLONES, EntityRef(player), 0)
		end
	end

	local inheritors = auxi.getenemies(Isaac.GetRoomEntities(), function(ent)
		if not in_wave(ent) then return false end
		if not auxi.check_all_exists(ent) then return false end
		local m = mark_of(ent)
		if m and m.tragedy == true then return false end
		return true
	end)
	table.sort(inheritors, function(a, b)
		return a.Position:DistanceSquared(pos) < b.Position:DistanceSquared(pos)
	end)
	local heir = inheritors[1]
	if heir then
		apply_mask(heir, KIND_TRAGEDY, player, {propagated = true})
	end
end

local function settle_comedy_survival(npc, mark, player, fusion)
	local convert_ratio = fusion and item.fusion_heal_ratio or item.comedy_heal_ratio
	local immune_ratio = fusion and item.fusion_immune_heal_ratio or item.comedy_immune_heal_ratio
	if can_comedy_convert(npc) then
		restore_hp(npc, convert_ratio)
		if convert_to_friendly(npc, player) then
			clear_all_masks(npc)
			spawn_comedy_spotlight(npc, player)
			return true
		end
	end
	restore_hp(npc, immune_ratio)
	set_comedy_immune(npc)
	clear_all_masks(npc)
	npc:SetColor(Color(1.0, 0.85, 0.45, 1.0, 0.12, 0.06, 0), 10, 1, false, false)
	return false
end

local function settle_real_death(npc)
	local mark = mark_of(npc)
	if not mark then return end
	if mark.settled or mark.settling then return end
	if mark.tragedy ~= true then return end
	mark.settling = true
	local player = resolve_mark_player(mark)
	local fusion = is_fusion(mark)
	trigger_tragedy_wave(npc, player, fusion)
	mark.settled = true
	mark.settling = false
	clear_all_masks(npc)
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."next"] = {}
	end
	save.elses[item.own_key.."next"] = save.elses[item.own_key.."next"] or {}
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_ATTACK_DPS_SAMPLE, params = nil,
Function = function(_, event)
	local player = event and event.player
	local ent = event and event.member
	if not player or not auxi.has_have_coll(player, item.entity) then return end
	if event.family ~= "tear" then return end
	if not ent or not ent.ToTear or not ent:ToTear() then return end
	item.try_convert_mask_tear(player, ent)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_, ent, col, low)
	local d = ent:GetData()
	if not d[item.own_key.."mask"] then return end
	if not auxi.isenemies(col) then return end
	local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
	apply_mask(col, d[item.own_key.."kind"] or KIND_TRAGEDY, player)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_, ent, amount, flags, source, cooldown)
	local npc = ent and ent.ToNPC and ent:ToNPC()
	if not npc then return end
	local mark = mark_of(npc)
	if not mark or not mark.comedy then return end
	if mark.settling or mark.settled then return end
	if not enemy_death_guard.can_intercept_current_death(npc, amount, flags) then
		return
	end

	mark.settling = true
	local fusion = is_fusion(mark)
	local player = resolve_mark_player(mark)
	if fusion then
		trigger_tragedy_wave(npc, player, true)
	end
	settle_comedy_survival(npc, mark, player, fusion)
	if mark_of(npc) then
		local live = mark_of(npc)
		live.settled = true
		live.settling = false
	end
	return false
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = nil,
Function = function(_, ent)
	if mark_of(ent) then settle_real_death(ent) end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_, ent)
	if ent and ent.ToNPC and ent:ToNPC() and mark_of(ent) then
		settle_real_death(ent)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_NEW_ROOM, params = nil,
Function = function(_)
	item.stage_dim_fx = nil
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.ID_EFFECT_MeusNIL,
Function = function(_, ent)
	update_stage_dim(ent)
	update_drama_spotlight(ent)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_UPDATE, params = nil,
Function = function(_, ent)
	local mark = mark_of(ent)
	if not mark or mark.settled then return end
	if not mark.tragedy and not mark.comedy then return end
	mark.head_anchor_lock = mark.head_anchor_lock or {}
	local face = head_anchor.GetEntityFaceAnchor(ent, {
		lockData = mark.head_anchor_lock,
	})
	if not face or not face.center then return end
	if mark.mask_face_source and mark.mask_face_source ~= face.source then
		mark.mask_face_center = Vector(face.center.X, face.center.Y)
		mark.mask_face_width = face.width
	else
		mark.mask_face_center = filter_vec2(mark.mask_face_center, face.center, MASK_POS_FILTER)
		mark.mask_face_width = filter_scalar(mark.mask_face_width, face.width, MASK_SCALE_FILTER)
	end
	mark.mask_face_source = face.source
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_, ent, offset)
	if not ent.Visible then return end
	if overlay_temporarily_hidden(ent) then return end
	local mark = mark_of(ent)
	if not mark or mark.settled then return end
	if not mark.tragedy and not mark.comedy then return end
	mark.head_anchor_lock = mark.head_anchor_lock or {}
	local base = Isaac.WorldToRenderPosition(
		ent.Position + (ent.PositionOffset or Vector.Zero)
	) + (offset or Vector.Zero)
	local center = mark.mask_face_center
	local width = mark.mask_face_width
	if not center or not width then
		local face = head_anchor.GetEntityFaceAnchor(ent, {
			lockData = mark.head_anchor_lock,
		})
		center = face and face.center
		width = face and face.width
	end
	if not center or not width then return end
	local anchor = {
		center = base + center,
		width = width,
	}
	if mark.tragedy and not mark.comedy then
		render_mask_sprite(ensure_mark_sprite(mark, "tragedy"), ent, anchor)
		return
	end
	if mark.comedy and not mark.tragedy then
		render_mask_sprite(ensure_mark_sprite(mark, "comedy"), ent, anchor)
		return
	end
	render_mask_sprite(
		ensure_mark_sprite(mark, "fusion"),
		ent,
		anchor,
		{1, 0.7, 1, 1, 0.12, 0, 0.18}
	)
end,
})

return item

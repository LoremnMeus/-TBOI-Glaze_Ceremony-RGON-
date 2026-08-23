local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local save = require("Qing_Remaster_scripts.core.savedata")

local item = {
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Multiknife,
	own_key = "Item_Multiknife_",
	max_charge = 10,
	belial_bonus = 2,
	fall_after_charge = 6,
}

local KNIFE_ANM2 = "gfx/mimics/Multiknife/Knife.anm2"
local EMPTY_ANM2 = "gfx/mimics/Multiknife/Empty.anm2"
local BODY_LAYER = 0
local BOTTOM_LAYER = 1
local EDGE_LAYER = 2
local BODY_H = 10
-- 剑柄 pivot 在 21px，刀身仍从旧的中心 16px 往上长。
local BODY_ATTACH_Y = 16 - 21
local HUD_POS_Y = 10
local SQUASH_DUR = 5
local GROW_DUR = 10
local SHAKE_DUR = 8
local FALL_DUR = 14
local LIFT_HOLD_DUR = 5
local LIFT_GROW_BASE = 14
local LIFT_GROW_PER = 2
local AIM_HOLD_DUR = 6
local AIM_TIMEOUT = 90
local DROP_DUR = 18
local PITCH_SLICES = 10

-- HUD 1–6 仍按 Idle 翻倍；7–12 从 3.2 爬到 56，避免再按 2^n 冲屏。
local HUD_BODY_DEFAULT = {
	[1] = 0.10, [2] = 0.20, [3] = 0.40, [4] = 0.80, [5] = 1.60,
	[6] = 3.20, [7] = 5.50, [8] = 9.50, [9] = 16.50, [10] = 28.00,
	[11] = 40.00, [12] = 56.00,
}
local HUD_DEBUG_KEYS = {
	[7] = "MultiknifeHud7",
	[8] = "MultiknifeHud8",
	[9] = "MultiknifeHud9",
	[10] = "MultiknifeHud10",
	[11] = "MultiknifeHud11",
	[12] = "MultiknifeHud12",
}
local LIFT_Y_DEFAULT = -20
local LIFT_X_DEFAULT = 0

-- 刺/挥的碰撞倍率（sprite.Scale:Length()），与视觉长度拆开。
local COLLIDE_SCALE = {
	[1] = 1.10, [2] = 1.35, [3] = 1.60,
	[4] = 1.15, [5] = 1.35, [6] = 1.55,
}

local ATTACK_SWING = {0, 30, 90, 135, 188, 188, 180, 180}
local ATTACK_SWING2 = {180, 150, 90, 45, -8, -8, 0, 0}

local knife_spr = Sprite()
local knife_loaded = false
local world_spr = Sprite()
local world_loaded = false
local empty_spr = Sprite()
local empty_loaded = false

local function ensure_knife()
	if knife_loaded then return knife_spr end
	knife_spr:Load(KNIFE_ANM2, true)
	knife_spr:Play("Idle", true)
	knife_spr:SetFrame(0)
	knife_loaded = true
	return knife_spr
end

local function ensure_world_knife()
	if world_loaded then return world_spr end
	world_spr:Load(KNIFE_ANM2, true)
	world_spr:Play("Idle", true)
	world_spr:SetFrame(0)
	world_loaded = true
	return world_spr
end

local function ensure_empty()
	if empty_loaded then return empty_spr end
	empty_spr:Load(EMPTY_ANM2, true)
	empty_spr:Play("Idle", true)
	empty_spr:SetFrame(0)
	empty_loaded = true
	return empty_spr
end

local function debug_num(key, default)
	local root = save.ModConfigSettings
	local dbg = root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
	local v = dbg and tonumber(dbg[key])
	if v == nil then return default end
	return v
end

local function lerp(a, b, t)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	return a + (b - a) * t
end

local function ease_out_cubic(t)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	local u = 1 - t
	return 1 - u * u * u
end

local function ease_in_quad(t)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	return t * t
end

local function ease_in_cubic(t)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	return t * t * t
end

local function abs_max_charge()
	return item.max_charge + item.belial_bonus
end

local function has_belial(player)
	return player and auxi.should_do_belial(player) == true
end

local function charge_cap_for(player)
	if has_belial(player) then return abs_max_charge() end
	return item.max_charge
end

local function clamp_charge(charge)
	charge = math.floor(tonumber(charge) or 0)
	local cap = abs_max_charge()
	if charge < 0 then return 0 end
	if charge > cap then return cap end
	return charge
end

local function body_scale_for_charge(charge)
	charge = clamp_charge(charge)
	if charge <= 0 then return 0 end
	local default = HUD_BODY_DEFAULT[charge] or (0.10 * (2 ^ (charge - 1)))
	local key = HUD_DEBUG_KEYS[charge]
	if not key then return default end
	local v = debug_num(key, default)
	if v < 0 then v = 0 end
	return v
end

local function world_body_scale_for_charge(charge)
	return body_scale_for_charge(charge)
end

local function knife_color(alpha, blood)
	local col = Color(1, 1, 1, tonumber(alpha) or 1)
	if blood and col.SetColorize then
		col:SetColorize(1.35, 0.08, 0.08, 1)
	end
	return col
end

local function lift_grow_dur(charge)
	return LIFT_GROW_BASE + LIFT_GROW_PER * math.max(0, clamp_charge(charge) - 1)
end

local function knife_up_px(vis)
	return 21 + BODY_H * (tonumber(vis) or 0) + 16
end

local function screen_px_to_world(px)
	local p = Game():GetRoom():GetCenterPos()
	local s0 = Isaac.WorldToScreen(p)
	local s1 = Isaac.WorldToScreen(p + Vector(40, 0))
	local tile = math.abs(s1.X - s0.X)
	if tile < 1 then return px end
	return px * (40 / tile)
end

local function blade_length(vis)
	return screen_px_to_world(knife_up_px(vis))
end

local function damage_for_charge(player, charge)
	local mul = 2 ^ (clamp_charge(charge) - 1)
	return (player.Damage or 3.5) * mul
end

local function fall_dir_for_slot(slot)
	if slot == ActiveSlot.SLOT_PRIMARY then return 1 end
	return -1
end

local function hud_root(player)
	local d = player:GetData()
	local bag = d[item.own_key.."hud"]
	if type(bag) ~= "table" then
		bag = {}
		d[item.own_key.."hud"] = bag
	end
	return bag
end

local function slot_state(player, slot)
	local bag = hud_root(player)
	local st = bag[slot]
	if type(st) ~= "table" then
		st = {
			charge = 0,
			vis = 0,
			from_s = 0,
			to_s = 0,
			phase = "idle",
			t0 = 0,
			sx = 1,
			sy_mul = 1,
			rot = 0,
			shake = 0,
			fallen = false,
			will_fall = false,
			landed = false,
		}
		bag[slot] = st
	end
	return st
end

local function reset_pose(st, charge)
	charge = clamp_charge(charge)
	st.charge = charge
	st.vis = body_scale_for_charge(charge)
	st.from_s = st.vis
	st.to_s = st.vis
	st.phase = "idle"
	st.sx = 1
	st.sy_mul = 1
	st.rot = 0
	st.shake = 0
	st.fallen = false
	st.will_fall = false
	st.landed = false
end

local function start_grow(st, charge, now)
	charge = clamp_charge(charge)
	local target = body_scale_for_charge(charge)
	st.charge = charge
	st.from_s = st.vis
	st.to_s = target
	st.will_fall = charge > item.fall_after_charge and not st.fallen
	st.phase = "squash"
	st.t0 = now
	st.sx = 1
	st.sy_mul = 1
	st.shake = 0
end

local function tick_anim(st, now)
	if st.phase == "idle" then
		st.sx = 1
		st.sy_mul = 1
		st.shake = 0
		if st.fallen then
			st.rot = 90 * (st.fall_sign or 1)
		end
		return
	end
	local elapsed = now - (st.t0 or now)
	if st.phase == "squash" then
		local u = elapsed / SQUASH_DUR
		if u >= 1 then
			st.phase = "grow"
			st.t0 = now
			st.sx = 1.28
			st.sy_mul = 0.72
			return
		end
		st.sx = lerp(1, 1.28, u)
		st.sy_mul = lerp(1, 0.72, u)
	elseif st.phase == "grow" then
		local u = elapsed / GROW_DUR
		if u >= 1 then
			st.vis = st.to_s
			st.sx = 1
			st.sy_mul = 1
			if st.will_fall then
				st.will_fall = false
				st.phase = "shake"
				st.t0 = now
			else
				st.phase = "idle"
			end
			return
		end
		local e = ease_out_cubic(u)
		local over = 1 + 0.14 * math.sin(u * math.pi) * (1 - u)
		st.vis = st.from_s + (st.to_s - st.from_s) * math.min(1, e * over)
		st.sx = lerp(1.28, 1, e)
		st.sy_mul = lerp(0.72, 1, e)
	elseif st.phase == "shake" then
		local u = elapsed / SHAKE_DUR
		if u >= 1 then
			st.shake = 0
			st.phase = "fall"
			st.t0 = now
			return
		end
		st.shake = math.sin(elapsed * 1.7) * 8 * (1 - u)
	elseif st.phase == "fall" then
		local u = elapsed / FALL_DUR
		local dest = 90 * (st.fall_sign or 1)
		if u >= 1 then
			st.rot = dest
			st.shake = 0
			st.fallen = true
			st.phase = "idle"
			if not st.landed then
				st.landed = true
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_FORESTBOSS_STOMPS, 1, 0.85, false, 0, 2)
			end
			return
		end
		st.rot = dest * ease_in_quad(u)
		st.shake = 0
	end
end

local function sync_slot(player, slot)
	if not player or player:GetActiveItem(slot) ~= item.entity then return end
	local charge = clamp_charge(player:GetActiveCharge(slot))
	local st = slot_state(player, slot)
	local now = Game():GetFrameCount()
	st.fall_sign = fall_dir_for_slot(slot)
	if st.ready ~= true then
		st.ready = true
		st.charge = charge
		st.vis = body_scale_for_charge(charge)
		st.from_s = st.vis
		st.to_s = st.vis
		if charge > item.fall_after_charge then
			st.fallen = true
			st.landed = true
			st.rot = 90 * st.fall_sign
		end
		tick_anim(st, now)
		return
	end
	if charge < st.charge then
		reset_pose(st, charge)
	elseif charge > st.charge then
		if st.phase == "squash" or st.phase == "grow" then
			st.charge = charge
			st.to_s = body_scale_for_charge(charge)
			if charge > item.fall_after_charge and not st.fallen then
				st.will_fall = true
			end
		else
			start_grow(st, charge, now)
		end
	elseif st.charge == 0 and st.vis == 0 and charge == 0 and not st.fallen then
		-- keep idle
	end
	if charge > item.fall_after_charge and st.fallen and st.phase == "idle" then
		st.rot = 90 * st.fall_sign
	end
	tick_anim(st, now)
	if st.phase == "idle" then
		st.vis = body_scale_for_charge(charge)
		st.to_s = st.vis
		st.from_s = st.vis
	end
end

local function apply_layers(spr, vis)
	if not spr or not spr.GetLayer then return end
	local function layer(id)
		local ok, lay = pcall(function() return spr:GetLayer(id) end)
		if ok then return lay end
	end
	local bottom = layer(BOTTOM_LAYER)
	local body = layer(BODY_LAYER)
	local edge = layer(EDGE_LAYER)
	if bottom then
		if bottom.SetPos then bottom:SetPos(Vector(0, 0)) end
		if bottom.SetSize then bottom:SetSize(Vector(1, 1)) end
		if bottom.SetRotation then bottom:SetRotation(0) end
	end
	if body then
		if body.SetPos then body:SetPos(Vector(0, BODY_ATTACH_Y)) end
		if body.SetSize then body:SetSize(Vector(1, vis)) end
		if body.SetRotation then body:SetRotation(0) end
	end
	if edge then
		if edge.SetPos then edge:SetPos(Vector(0, BODY_ATTACH_Y - BODY_H * vis)) end
		if edge.SetSize then edge:SetSize(Vector(1, 1)) end
		if edge.SetRotation then edge:SetRotation(0) end
	end
end

local function reset_sprite(spr)
	spr.Scale = Vector(1, 1)
	spr.Rotation = 0
	spr.Offset = Vector(0, 0)
	spr.FlipX = false
	spr.FlipY = false
	spr.Color = Color(1, 1, 1, 1)
end

local function render_knife_at(spr, pos, vis, rot, scale, alpha, blood)
	spr:Play("Idle", true)
	spr:SetFrame(0)
	apply_layers(spr, vis)
	local sc = scale or 1
	if type(sc) == "number" then
		spr.Scale = Vector(sc, sc)
	else
		spr.Scale = sc
	end
	spr.Rotation = rot or 0
	spr.Color = knife_color(alpha or 1, blood)
	spr:Render(pos, Vector(0, 0), Vector(0, 0))
	reset_sprite(spr)
end

local function pitch_sx(away, s, amid)
	local sx
	if away then
		sx = (1 - 0.62 * s * amid) * (1 - 0.18 * s)
	else
		sx = 1 + 1.2 * s * amid
	end
	if sx < 0.18 then sx = 0.18 end
	return sx
end

-- 上下倒：不绕 Z 转。Render 裁剪吃的是源像素，不能按拉伸后的刀长去 clip。
-- 改成按层分片 RenderLayer，Y 用 cos(pitch) 压扁，X 按远近做成透视。
local function render_knife_pitch(spr, pos, vis, u, away, blood)
	if u < 0 then u = 0 elseif u > 1 then u = 1 end
	local pitch = (math.pi * 0.5) * ease_in_quad(u)
	local c = math.cos(pitch)
	local s = math.sin(pitch)
	if c < 0.12 then c = 0.12 end
	local alpha = 1
	if away then
		alpha = 1 - 0.32 * s
	end
	spr:Play("Idle", true)
	spr:SetFrame(0)
	apply_layers(spr, vis)
	spr.Rotation = 0
	spr.Color = knife_color(alpha, blood)
	if not spr.RenderLayer then
		local scx = pitch_sx(away, s, 0.5)
		render_knife_at(spr, pos, vis, 0, Vector(scx, c), alpha, blood)
		return
	end
	local function layer(id)
		local ok, lay = pcall(function() return spr:GetLayer(id) end)
		if ok then return lay end
	end
	local body = layer(BODY_LAYER)
	local n = PITCH_SLICES
	local vis_n = (tonumber(vis) or 0) / n
	spr.Scale = Vector(pitch_sx(away, s, 0.08), c)
	spr:RenderLayer(BOTTOM_LAYER, pos, Vector(0, 0), Vector(0, 0))
	if body and body.SetPos and body.SetSize then
		for i = 0, n - 1 do
			local amid = (i + 0.5) / n
			body:SetPos(Vector(0, BODY_ATTACH_Y - BODY_H * vis * (i / n)))
			body:SetSize(Vector(1, vis_n))
			spr.Scale = Vector(pitch_sx(away, s, amid), c)
			spr:RenderLayer(BODY_LAYER, pos, Vector(0, 0), Vector(0, 0))
		end
	end
	local edge = layer(EDGE_LAYER)
	if edge and edge.SetPos then
		edge:SetPos(Vector(0, BODY_ATTACH_Y - BODY_H * vis))
	end
	spr.Scale = Vector(pitch_sx(away, s, 1), c)
	spr:RenderLayer(EDGE_LAYER, pos, Vector(0, 0), Vector(0, 0))
	apply_layers(spr, vis)
	reset_sprite(spr)
end

local function get_cast(player)
	return player:GetData()[item.own_key.."cast"]
end

local function lock_attack(player)
	local d = player:GetData()
	if d[item.own_key.."atk_lock"] == nil then
		d[item.own_key.."atk_lock"] = Attribute_holder.try_hold_attribute(
			player,
			"Data_should_not_attack",
			true,
			Attribute_holder.descriptors.data_field("should_not_attack")
		)
	end
end

local function unlock_attack(player)
	local d = player:GetData()
	if d[item.own_key.."atk_lock"] then
		Attribute_holder.try_rewind_attribute(player, "Data_should_not_attack", d[item.own_key.."atk_lock"], {
			toget = function(ent) return ent:GetData().should_not_attack end,
			tochange = function(ent, value) ent:GetData().should_not_attack = value end,
		})
		d[item.own_key.."atk_lock"] = nil
	end
end

local function hide_item(player)
	if not player then return end
	pcall(function()
		player:AnimatePickup(ensure_empty(), true, "HideItem")
	end)
end

local function clear_cast(player)
	local d = player:GetData()
	if d[item.own_key.."cast"] then
		hide_item(player)
	end
	d[item.own_key.."cast"] = nil
	unlock_attack(player)
end

local function remember_dir(player, direction)
	if direction and direction:Length() > 0.05 then
		player:GetData()[item.own_key.."last_direction"] = direction:Normalized()
	end
end

local function shoot_dir(player)
	local direction = auxi.getdir(player)
	if direction:Length() > 0.05 then
		remember_dir(player, direction)
		return direction:Normalized()
	end
	return nil
end

local function fallback_dir(player)
	local data = player:GetData()
	local direction = data[item.own_key.."last_direction"]
	if direction and direction:Length() > 0.05 then return direction:Normalized() end
	direction = player:GetMovementInput()
	if direction:Length() > 0.05 then return direction:Normalized() end
	return Vector(0, 1)
end

local function wrap_deg(ang)
	while ang > 180 do ang = ang - 360 end
	while ang <= -180 do ang = ang + 360 end
	return ang
end

local function classify_aim(direction)
	local ang = direction:GetAngleDegrees()
	if ang > -50 and ang < 50 then
		return "right"
	elseif ang >= 50 and ang <= 130 then
		return "down"
	elseif ang <= -130 or ang >= 130 then
		return "left"
	end
	return "up"
end

local function drop_yaw_rot(kind)
	if kind == "right" then return 90 end
	if kind == "left" then return -90 end
	return 0
end

local FALL_KINDS = {"right", "down", "left", "up"}
local FALL_DIRS = {
	right = Vector(1, 0),
	down = Vector(0, 1),
	left = Vector(-1, 0),
	up = Vector(0, -1),
}

local function is_hold_phase(phase)
	return phase == "grow_hold" or phase == "grow" or phase == "aim"
end

local function random_fall_kind(player)
	local rng = player:GetCollectibleRNG(item.entity)
	local idx = rng:RandomInt(4)
	if idx < 0 then idx = 0 elseif idx > 3 then idx = 3 end
	return FALL_KINDS[idx + 1]
end

local function hide_held_sprite(player)
	if not player or not player.GetHeldSprite then return Vector(0, 0) end
	local ok, held = pcall(function() return player:GetHeldSprite() end)
	if not ok or not held then return Vector(0, 0) end
	held.Color = Color(1, 1, 1, 0)
	local off = held.Offset
	if off then return Vector(off.X, off.Y) end
	return Vector(0, 0)
end

-- PRE/POST_*_RENDER 自绘：W2S 已是窗口坐标，回调 offset 在大房间会再带 scroll。
-- 见 codex_work/notes/entity_render_scroll_offset_pitfalls.md
local function entity_screen_pos(ent, offset)
	local po = ent.PositionOffset or Vector(0, 0)
	local pos = Isaac.WorldToScreen(ent.Position + po)
	if offset then pos = pos + offset end
	local room = Game():GetRoom()
	if room and room.GetRenderScrollOffset then
		pos = pos - room:GetRenderScrollOffset()
	end
	return pos
end

local function lift_screen_pos(player, offset)
	local held_off = hide_held_sprite(player)
	local lift_x = debug_num("MultiknifeLiftX", LIFT_X_DEFAULT)
	local lift_y = debug_num("MultiknifeLiftY", LIFT_Y_DEFAULT)
	return entity_screen_pos(player, offset) + held_off + Vector(lift_x, lift_y)
end

local function hide_stab_body(ent)
	local s = ent:GetSprite()
	if not s then return end
	s.Color = Color(1, 1, 1, 0)
	if not s.GetLayer then return end
	local n = 5
	if s.GetLayerCount then
		local ok, cnt = pcall(function() return s:GetLayerCount() end)
		if ok and type(cnt) == "number" then n = cnt end
	end
	for i = 0, n - 1 do
		local ok, lay = pcall(function() return s:GetLayer(i) end)
		if ok and lay then
			if lay.SetVisible then lay:SetVisible(false) end
			if lay.SetColor then lay:SetColor(Color(1, 1, 1, 0)) end
		end
	end
end

local function overlay_rot_for_knife(ent, d)
	local face = ent.RotationOffset or 0
	if d.mk_mode == "stab" then
		return wrap_deg(face + 90)
	end
	local s = ent:GetSprite()
	local frame = s and s:GetFrame() or 0
	local table_ = d.mk_flip and ATTACK_SWING2 or ATTACK_SWING
	local swing = table_[frame + 1] or 90
	return wrap_deg(face + swing)
end

local function fire_qing_knife(player, direction, charge, mode)
	local vis = world_body_scale_for_charge(charge)
	local dmg = damage_for_charge(player, charge)
	local s = COLLIDE_SCALE[charge] or 1.2
	local tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS, 1, 1)
	local pos = player.Position + player.Velocity
	local knife
	if mode == "stab" then
		local vel = player.Velocity + direction * 10
		knife = auxi.fire_dosome_knife(pos, vel, tearHitParams, "StabDown", {
			player = player,
			repel = direction * 10,
			dmg = dmg,
			dmgmul = 1,
			scale = Vector(s, s),
			size2 = Vector(1, 1),
			list = {},
			ignore_divi = true,
		}, {charge = 1})
	else
		local vel = (player.Velocity + direction * 10):Normalized() / 1000
		local flip = direction.X < 0
		knife = auxi.fire_dosome_knife(pos, vel, tearHitParams, "AttackUp", {
			player = player,
			Flip = flip,
			dmg = dmg,
			dmgmul = 1,
			scale = Vector(s, s),
			size2 = Vector(1, 1),
			list = {},
			ignore_divi = true,
		}, {charge = 1})
		if knife then
			knife:GetData().mk_flip = flip
		end
	end
	if not knife then return end
	local d = knife:GetData()
	d.mk_draw = true
	d.mk_vis = vis
	d.mk_mode = mode
	d.mk_charge = charge
	d.mk_blood = has_belial(player)
	hide_stab_body(knife)
	return knife
end

local function spawn_spent_wisps(player, charge, use_flags)
	if not player or not auxi.should_spawn_wisp(player, use_flags) then return end
	charge = math.floor(tonumber(charge) or 0)
	if charge < 1 then return end
	for _ = 1, charge do
		local wisp = player:AddWisp(item.entity, player.Position, true, false)
		if wisp then
			wisp.MaxHitPoints = 1
			wisp.HitPoints = 1
			wisp.CollisionDamage = 1
		end
	end
end

local function spawn_slam_smoke(pos, charge, heavy)
	local n = heavy and (12 + charge) or (5 + math.floor(charge / 2))
	if n > 24 then n = 24 end
	local core_var = EffectVariant.POOF02 or EffectVariant.ROCK_POOF or EffectVariant.POOF01
	local core = Isaac.Spawn(EntityType.ENTITY_EFFECT, core_var, 1, pos, Vector.Zero, nil)
	if core then
		core = core:ToEffect() or core
		local sc = heavy and (1.25 + charge * 0.1) or 0.85
		core.SpriteScale = Vector(sc, sc)
		if core.LifeSpan ~= nil then core.LifeSpan = 18 end
		if core.Timeout ~= nil then core.Timeout = 18 end
	end
	local dust = EffectVariant.DUST_CLOUD or EffectVariant.POOF01
	local spread = heavy and (16 + charge * 2.4) or (8 + charge * 1.2)
	for i = 1, n do
		local ang = (360 / n) * (i - 1) + (i * 17) % 23
		local r = spread * (0.15 + (i % 6) * 0.14)
		local spawn_pos = pos + auxi.MakeVector(ang):Resized(r)
		local dir = auxi.MakeVector(ang):Resized(1.8 + (i % 5) * 0.45)
		local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, dust, 0, spawn_pos, dir, nil)
		if fx then
			fx = fx:ToEffect() or fx
			fx:SetColor(Color(0.55, 0.5, 0.42, 0.85, 0, 0, 0), -1, 0)
			local sc = 0.5 + (i % 4) * 0.12
			fx.SpriteScale = Vector(sc, sc)
			if fx.LifeSpan ~= nil then fx.LifeSpan = 14 end
			if fx.Timeout ~= nil then fx.Timeout = 14 end
		end
	end
end

local SLAM_GRID_RING = 1
local SLAM_TILE = 40
local BLOCKED_DOOR_TARGET = {
	[-10] = true,
	[-7] = true,
	[-1] = true,
}

local function is_breakable_slam_grid(ge)
	if not ge then return false end
	if ge.CollisionClass == GridCollisionClass.COLLISION_NONE then return false end
	if ge.ToPoop and ge:ToPoop() then return true end
	local gt = ge:GetType()
	return gt == GridEntityType.GRID_POOP
		or gt == GridEntityType.GRID_ROCK or gt == GridEntityType.GRID_ROCKT
		or gt == GridEntityType.GRID_ROCK_BOMB or gt == GridEntityType.GRID_ROCK_ALT
		or gt == GridEntityType.GRID_ROCK_SS or gt == GridEntityType.GRID_ROCK_SPIKED
		or gt == GridEntityType.GRID_ROCK_ALT2 or gt == GridEntityType.GRID_ROCK_GOLD
end

local function try_blow_slam_door(ge, player)
	if not ge or not ge.ToDoor then return false end
	local door = ge:ToDoor()
	if not door then return false end
	if door:IsOpen() then return false end
	local target = door.TargetRoomIndex
	if BLOCKED_DOOR_TARGET[target] then return false end
	if door.CanBlowOpen and not door:CanBlowOpen() then return false end
	return door:TryBlowOpen(true, player) == true
end

local function in_slam_band(pos, origin, direction, length, half_width)
	local relative = pos - origin
	local forward = relative.X * direction.X + relative.Y * direction.Y
	local sideways = math.abs(relative.X * direction.Y - relative.Y * direction.X)
	return forward >= -SLAM_TILE and forward <= length + SLAM_TILE
		and sideways <= half_width + SLAM_TILE
end

local function destroy_slam_grids(room, pos, seen, ring, player)
	local idx = room:GetGridIndex(pos)
	if not idx or idx < 0 then return end
	local width = room:GetGridWidth()
	local height = room:GetGridHeight()
	if not width or width < 1 then return end
	local gx = idx % width
	local gy = math.floor(idx / width)
	ring = ring or SLAM_GRID_RING
	for dy = -ring, ring do
		for dx = -ring, ring do
			local nx = gx + dx
			local ny = gy + dy
			if nx >= 0 and ny >= 0 and nx < width and ny < height then
				local nidx = ny * width + nx
				if not seen[nidx] then
					seen[nidx] = true
					local ge = room:GetGridEntity(nidx)
					if not try_blow_slam_door(ge, player) and is_breakable_slam_grid(ge) then
						ge:Destroy(true)
					end
				end
			end
		end
	end
end

local function blow_slam_doors(room, player, direction, length, half_width)
	local origin = player.Position
	local n = (DoorSlot and DoorSlot.NUM_DOOR_SLOTS) or 8
	for slot = 0, n - 1 do
		local door = room:GetDoor(slot)
		if door and in_slam_band(door.Position, origin, direction, length, half_width) then
			try_blow_slam_door(door, player)
		end
	end
end

local function slam_hit(player, direction, charge, vis, dmg_mul)
	local length = blade_length(vis)
	local half_width = 22 + charge * 2
	local damage = damage_for_charge(player, charge) * (dmg_mul or 1)
	for _, entity in ipairs(Isaac.GetRoomEntities()) do
		if entity:IsVulnerableEnemy() and entity:IsActiveEnemy(false)
			and not entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			local relative = entity.Position - player.Position
			local forward = relative.X * direction.X + relative.Y * direction.Y
			local sideways = math.abs(relative.X * direction.Y - relative.Y * direction.X)
			if forward >= -entity.Size and forward <= length + entity.Size
				and sideways <= half_width + entity.Size then
				entity:TakeDamage(damage, 0, EntityRef(player), 0)
				entity.Velocity = entity.Velocity + direction * math.min(22, 6 + charge)
			end
		end
	end
	local room = Game():GetRoom()
	local start_dist = math.min(14, length * 0.06)
	local steps = 5 + math.max(0, charge - 6)
	local perp = Vector(-direction.Y, direction.X)
	local seen = {}
	for i = 0, steps do
		local t = i / steps
		local dist = start_dist + (length - start_dist) * t
		local p = player.Position + direction * dist
		destroy_slam_grids(room, p, seen, SLAM_GRID_RING, player)
		local heavy = i == steps
		spawn_slam_smoke(p, charge, heavy)
		if charge >= 7 and i ~= steps and (i % 2 == 0) then
			local w = (10 + charge * 1.6) * (0.35 + 0.65 * t)
			spawn_slam_smoke(p + perp * w, charge, false)
			spawn_slam_smoke(p - perp * w, charge, false)
		end
	end
	blow_slam_doors(room, player, direction, length, half_width)
	Game():ShakeScreen(math.min(12, 4 + charge))
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_FORESTBOSS_STOMPS, 1.2, 0.7, false, 0, 2)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_ROCK_CRUMBLE, 1, 0.85, false, 0, 2)
end

local function fire_swing(player, cast, direction)
	local charge = cast.charge
	local times = 1
	if cast.double then times = 2 end
	if charge <= 3 then
		for _ = 1, times do
			fire_qing_knife(player, direction, charge, "stab")
		end
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SWORD_SPIN, 0.85, 1.1, false, 0, 2)
	elseif charge <= 6 then
		for i = 1, times do
			local dir = direction
			if i == 2 then
				dir = auxi.get_by_rotate(direction, 18)
			end
			fire_qing_knife(player, dir, charge, "slash")
		end
	end
end

local function current_lift_vis(cast)
	local now = Game():GetFrameCount()
	if cast.phase == "grow_hold" then
		return cast.from_s or body_scale_for_charge(1)
	end
	if cast.phase == "grow" then
		local dur = math.max(1, lift_grow_dur(cast.charge))
		local u = (now - (cast.t0 or now)) / dur
		if u >= 1 then return cast.to_s end
		return lerp(cast.from_s, cast.to_s, ease_in_quad(u))
	end
	return cast.vis or cast.to_s or body_scale_for_charge(1)
end

local function begin_drop(player, cast, direction)
	local kind = classify_aim(direction)
	cast.dir = direction
	cast.vis = current_lift_vis(cast)
	cast.phase = "drop"
	cast.t0 = Game():GetFrameCount()
	cast.drop_kind = kind
	cast.drop_rot = 0
	cast.target_rot = drop_yaw_rot(kind)
	cast.drop_u = 0
end

local function begin_action(player, cast, direction)
	if cast.charge >= 7 then
		begin_drop(player, cast, direction)
		return
	end
	hide_item(player)
	fire_swing(player, cast, direction)
	player:GetData()[item.own_key.."cast"] = nil
	unlock_attack(player)
end

local function interrupt_drop(player, cast)
	if not player or not cast then return end
	if not is_hold_phase(cast.phase) then return end
	local kind = random_fall_kind(player)
	begin_drop(player, cast, FALL_DIRS[kind])
end

local function relift_ready(player, cast)
	local vis = cast.to_s or body_scale_for_charge(cast.charge)
	cast.need_relift = nil
	cast.phase = "aim"
	cast.from_s = vis
	cast.vis = vis
	cast.drop_kind = nil
	cast.drop_rot = 0
	cast.drop_u = 0
	cast.t0 = Game():GetFrameCount()
	cast.hold_ok_frame = Game():GetFrameCount() + 8
	lock_attack(player)
	pcall(function()
		player:AnimatePickup(ensure_empty(), true, "LiftItem")
	end)
end

local function tick_cast(player)
	local cast = get_cast(player)
	if not cast then return end
	if not auxi.check_all_exists(player) then
		clear_cast(player)
		return
	end
	local now = Game():GetFrameCount()
	if cast.need_relift then
		relift_ready(player, cast)
	end
	if is_hold_phase(cast.phase) then
		local holding = false
		pcall(function() holding = player:IsHoldingItem() == true end)
		if not holding then
			if now < (cast.hold_ok_frame or 0) then
				pcall(function()
					player:AnimatePickup(ensure_empty(), true, "LiftItem")
				end)
			else
				interrupt_drop(player, cast)
			end
		end
	end
	if cast.phase == "grow_hold" then
		cast.vis = cast.from_s
		if now - cast.t0 >= LIFT_HOLD_DUR then
			cast.t0 = now
			if math.abs((cast.to_s or 0) - (cast.from_s or 0)) < 0.02 then
				cast.vis = cast.to_s
				cast.phase = "aim"
			else
				cast.phase = "grow"
			end
		end
	elseif cast.phase == "grow" then
		local dur = math.max(1, lift_grow_dur(cast.charge))
		local u = (now - cast.t0) / dur
		if u >= 1 then
			cast.vis = cast.to_s
			cast.phase = "aim"
			cast.t0 = now
		else
			cast.vis = lerp(cast.from_s, cast.to_s, ease_in_quad(u))
		end
	elseif cast.phase == "aim" then
		local waiting = now - cast.t0 < AIM_HOLD_DUR
		local dir = shoot_dir(player)
		if dir and not waiting then
			begin_action(player, cast, dir)
		elseif now - cast.t0 >= AIM_TIMEOUT then
			begin_action(player, cast, fallback_dir(player))
		end
	elseif cast.phase == "drop" then
		local u = (now - cast.t0) / DROP_DUR
		if u >= 1 then
			cast.drop_u = 1
			cast.drop_rot = cast.target_rot or 0
			local dir = cast.dir or fallback_dir(player)
			slam_hit(player, dir, cast.charge, cast.vis, cast.double and 2 or 1)
			clear_cast(player)
			return
		end
		cast.drop_u = u
		if (cast.drop_kind or "") == "left" or cast.drop_kind == "right" then
			cast.drop_rot = (cast.target_rot or 90) * ease_in_quad(u)
		else
			cast.drop_rot = 0
		end
	end
end

local function render_cast(player, offset)
	local cast = get_cast(player)
	if not cast then return end
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local vis = current_lift_vis(cast)
	local pos = lift_screen_pos(player, offset)
	local blood = has_belial(player)
	local kind = cast.drop_kind
	if cast.phase == "drop" and (kind == "up" or kind == "down") then
		render_knife_pitch(ensure_world_knife(), pos, vis, cast.drop_u or 0, kind == "up", blood)
		return
	end
	local rot = 0
	if cast.phase == "drop" then
		rot = cast.drop_rot or 0
	end
	render_knife_at(ensure_world_knife(), pos, vis, rot, 1, 1, blood)
end

local function render_slot_hud(player, slot)
	if player:GetActiveItem(slot) ~= item.entity then return end
	sync_slot(player, slot)
	local st = slot_state(player, slot)
	local spr = ensure_knife()
	spr:Play("Idle", true)
	spr:SetFrame(0)
	apply_layers(spr, st.vis)
	local info = ui.GetActiveSlotRenderInfo(player, slot)
	local hud_scale = (info and tonumber(info.scale)) or 1
	local alpha = (info and tonumber(info.alpha)) or 1
	local center = ui.PlayerActiveUIPos(player, slot, auxi.GetPlayerOrder(player), item.entity)
	local pos = center + Vector(0, HUD_POS_Y * hud_scale)
	spr.Scale = Vector(hud_scale * (st.sx or 1), hud_scale * (st.sy_mul or 1))
	spr.Rotation = (st.rot or 0) + (st.shake or 0)
	spr.Color = knife_color(alpha, has_belial(player))
	spr:Render(pos, Vector(0, 0), Vector(0, 0))
	reset_sprite(spr)
end

if REPENTOGON and ModCallbacks.MC_PLAYER_GET_ACTIVE_MAX_CHARGE then
	table.insert(item.post_ToCall, {CallBack = ModCallbacks.MC_PLAYER_GET_ACTIVE_MAX_CHARGE, params = item.entity,
	Function = function(_, _, player, _, current_max)
		if not has_belial(player) then return end
		current_max = math.floor(tonumber(current_max) or item.max_charge)
		if current_max < 0 then current_max = 0 end
		return current_max + item.belial_bonus
	end,
	})
end

if REPENTOGON and ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE then
	table.insert(item.ToCall, {CallBack = ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE, params = item.entity,
	Function = function(_, _, _, _)
		return 1
	end,
	})
end

if REPENTOGON and ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM then
	table.insert(item.ToCall, {CallBack = ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM, params = item.entity,
	Function = function(_, _, _, _, _, _)
		return {HideItem = true}
	end,
	})
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	local direction = auxi.getdir(player)
	if direction:Length() > 0.05 then
		remember_dir(player, direction)
	end
	for slot = 0, 3 do
		if player:GetActiveItem(slot) == item.entity then
			sync_slot(player, slot)
		end
	end
	tick_cast(player)
end,
})

if REPENTOGON and ModCallbacks.MC_PRE_PLAYER_RENDER then
	table.insert(item.ToCall, {CallBack = ModCallbacks.MC_PRE_PLAYER_RENDER, params = nil,
	Function = function(_, player, _)
		if get_cast(player) then
			hide_held_sprite(player)
		end
	end,
	})
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_, player, offset)
	render_cast(player, offset)
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE, params = nil,
Function = function(_, ent)
	if not ent or ent.Variant ~= enums.Entities.StabberKnife then return end
	local d = ent:GetData()
	if d.mk_draw ~= true then return end
	hide_stab_body(ent)
end,
})

if ModCallbacks.MC_PRE_KNIFE_RENDER then
	table.insert(item.ToCall, {CallBack = ModCallbacks.MC_PRE_KNIFE_RENDER, params = nil,
	Function = function(_, ent, offset)
		if not ent or ent.Variant ~= enums.Entities.StabberKnife then return end
		local d = ent:GetData()
		if d.mk_draw ~= true then return end
		hide_stab_body(ent)
		if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
		local vis = d.mk_vis or world_body_scale_for_charge(d.mk_charge or 1)
		local rot = overlay_rot_for_knife(ent, d)
		local pos = entity_screen_pos(ent, offset)
		local blood = d.mk_blood
		if blood == nil then blood = has_belial(d.player) end
		render_knife_at(ensure_world_knife(), pos, vis, rot, 1, 1, blood)
		return false
	end,
	})
end

table.insert(item.myToCall, {CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_, player, _, cid, slot)
	if cid ~= item.entity then return end
	render_slot_hud(player, slot)
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		local cast = player and get_cast(player)
		if cast and is_hold_phase(cast.phase) then
			cast.need_relift = true
		end
	end
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_, ent, amount, flags)
	local player = ent and ent:ToPlayer()
	if not player then return end
	if (amount or 0) <= 0 then return end
	if flags and DamageFlag.DAMAGE_FAKE and (flags & DamageFlag.DAMAGE_FAKE ~= 0) then return end
	local cast = get_cast(player)
	if cast then
		interrupt_drop(player, cast)
	end
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_)
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and get_cast(player) then
			clear_cast(player)
		end
	end
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.WISP,
Function = function(_, familiar)
	if not familiar or familiar.SubType ~= item.entity then return end
	familiar.CollisionDamage = 1
	if (familiar.MaxHitPoints or 0) > 1 then
		familiar.MaxHitPoints = 1
		if (familiar.HitPoints or 0) > 1 then
			familiar.HitPoints = 1
		end
	end
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, _, _, player, use_flags, active_slot)
	local data = player:GetData()
	local cache_key = item.own_key.."last_use"
	local cached = data[cache_key]
	local is_car_battery = use_flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY
	local charge

	if is_car_battery and cached and cached.frame == Game():GetFrameCount() and cached.slot == active_slot then
		charge = cached.charge
		local cast = get_cast(player)
		if cast then
			cast.double = true
		end
		return {Discharge = false, ShowAnim = false}
	end

	if get_cast(player) then
		return {Discharge = false, ShowAnim = false}
	end

	charge = math.min(charge_cap_for(player), player:GetActiveCharge(active_slot))
	if charge < 1 then return {Discharge = false, ShowAnim = false} end

	data[cache_key] = {
		frame = Game():GetFrameCount(),
		slot = active_slot,
		charge = charge,
	}
	reset_pose(slot_state(player, active_slot), 0)
	spawn_spent_wisps(player, charge, use_flags)

	data[item.own_key.."cast"] = {
		phase = "grow_hold",
		charge = charge,
		slot = active_slot,
		from_s = body_scale_for_charge(1),
		to_s = body_scale_for_charge(charge),
		vis = body_scale_for_charge(1),
		t0 = Game():GetFrameCount(),
		hold_ok_frame = Game():GetFrameCount() + 2,
		drop_rot = 0,
		drop_u = 0,
		double = false,
	}
	lock_attack(player)
	player:AnimatePickup(ensure_empty(), true, "LiftItem")
	return {Discharge = true, ShowAnim = false}
end,
})

return item

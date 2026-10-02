-- 福音：每 4 次攻击给 Attack 打 tags.gospel；命中/伤害接受福音；光环→光环传播；启示累计后最终启示。
-- 不挂 entity.gospel_carrier；不识别具体武器类型。
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local attack_registry = require("Qing_Remaster_scripts.callbacks.attack_registry")
local entity_head_anchor = require("Qing_Remaster_scripts.auxiliary.entity_head_anchor")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")
local weapon_path = require("Qing_Remaster_scripts.auxiliary.weapon_path_geometry")

local item = {
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Gospel,
	own_key = "Item_Gospel_",
	consumer_key = "gospel",
	tear_every = 4,
	halo_fade = 0.14,
	orbit_tears = 3,
	spread_radius = 200,
	preach_need_mul = 2.5,
	preach_mul = 1.0,
	revelation_mul = 1.5,
	death_spread = 2,
	boss_revelation_need_mul = 8.0,
	dark_revelation_mul = 0.75,
	judgement_need = 6,
	judgement_mul = 3.0,
	preach_burst_cap = 8,
	-- Final revelation phases (Game():GetFrameCount / POST_UPDATE = 30 Hz).
	final_silence = 12,
	final_network = 10,
	final_rise = 8,
	link_life = 10,
	carrier_ring_scale = 0.34,
	-- Carrier overlay fade (POST_*_RENDER ≈ 60 Hz).
	carrier_fade = 0.16,
}

auxi.add_to_seija(item.entity)

local skip_hurt_flags = DamageFlag.DAMAGE_FAKE | DamageFlag.DAMAGE_CLONES

local function gospel_tag_from_member(ent)
	local attack = attack_holder.GetAttackForMember(ent)
	if attack and attack.tags and attack.tags.gospel then
		return attack.tags.gospel, attack
	end
	return nil, attack
end

-- Spirit Sword: collision is often on CLUB_HITBOX; tags may live on parent sword.
local function club_hitbox_subtype()
	if KnifeSubType and KnifeSubType.CLUB_HITBOX then
		return KnifeSubType.CLUB_HITBOX
	end
	return 4
end

local function is_club_hitbox(ent)
	return ent and ent.Type == EntityType.ENTITY_KNIFE and ent.SubType == club_hitbox_subtype()
end

local function spirit_sword_variant(v)
	if KnifeVariant then
		if KnifeVariant.SPIRIT_SWORD and v == KnifeVariant.SPIRIT_SWORD then return true end
		if KnifeVariant.TECH_SWORD and v == KnifeVariant.TECH_SWORD then return true end
	end
	return v == 10 or v == 11
end

local function hitbox_parent_knife(knife)
	if not knife then return nil end
	if knife.GetHitboxParentKnife then
		local ok, p = pcall(function() return knife:GetHitboxParentKnife() end)
		if ok and p then return p end
	end
	if knife.Parent and knife.Parent.Type == EntityType.ENTITY_KNIFE then
		return knife.Parent
	end
	return nil
end

local function gospel_tag_from_knife(knife)
	local gtag, attack = gospel_tag_from_member(knife)
	if gtag then return gtag, attack, knife end
	local parent = hitbox_parent_knife(knife)
	if parent then
		gtag, attack = gospel_tag_from_member(parent)
		if gtag then return gtag, attack, parent end
	end
	return nil, attack, knife
end

-- Trisagion (TEAR_LASERSHOT): damage/FX live on child lasers; Attack/gospel often on the parent tear.
local function gospel_tag_from_laser(laser)
	local gtag, attack = gospel_tag_from_member(laser)
	if gtag then return gtag, attack, laser end
	local parent = laser and laser.Parent
	if parent and parent.Type == EntityType.ENTITY_TEAR then
		gtag, attack = gospel_tag_from_member(parent)
		if gtag then return gtag, attack, parent end
	end
	local spawner = laser and laser.SpawnerEntity
	if spawner and spawner.Type == EntityType.ENTITY_TEAR and spawner ~= parent then
		gtag, attack = gospel_tag_from_member(spawner)
		if gtag then return gtag, attack, spawner end
	end
	return nil, attack, laser
end

local function collect_club_hitboxes_for(sword)
	local out = {}
	if not sword then return out end
	local sh = GetPtrHash(sword)
	local swords_attack = attack_holder.GetAttackForMember(sword)
	local knives = Isaac.FindByType(EntityType.ENTITY_KNIFE, -1, -1, false, false)
	for i = 1, #knives do
		local k = knives[i]
		if is_club_hitbox(k) then
			local p = hitbox_parent_knife(k)
			if p and GetPtrHash(p) == sh then
				out[#out + 1] = k
			elseif swords_attack then
				local ka = attack_holder.GetAttackForMember(k)
				if ka and ka.id == swords_attack.id then
					out[#out + 1] = k
				end
			end
		end
	end
	return out
end

local halo_spr = Sprite()
halo_spr:Load("gfx/effects/Halo/Halo_godhead_ring.anm2", true)
halo_spr:Play("Idle", true)
local symbol_spr = Sprite()
symbol_spr:Load("gfx/mimics/Gospel/Gospel_Tear.anm2", true)
symbol_spr:Play("Idle", true)
-- Attack carrier arcs only (enemy orbiters still use symbol_spr).
local carrier_arc_spr = Sprite()
carrier_arc_spr:Load("gfx/mimics/Gospel/Gospel_Carrier_Arc.anm2", true)
carrier_arc_spr:Play("Idle", true)

local ARC_COUNT = 3
local ARC_OFFSET = 120 -- equal gaps when midpoints are 120° apart
local ARC_SCALE = 1.35
-- PNG arc is centered on top (−90°) at Rotation=0; gap/particle angles share this.
local ARC_ART_MID_DEG = -90
local CARRIER_STYLE_FULL = "full"
local LASER_CARRIER_SPACING = weapon_path.LASER_PATH_SPACING
-- PNG stroke radius at scale 1 (see generate_gospel_arc.py).
local ARC_PNG_RADIUS = 42

local halo_update_frame = -1
local halo_pos_cache = {}
local halo_pos_tick = -1
local lingering_halos = {}
local gospel_links = {}
local receive_flashes = {}
-- Epic ground marker linger after TARGET despawns / rocket removes (screen-space).
local epic_ground_lingers = {}

local CARRIER_VIS_KEY = item.own_key .. "carrier_vis"
local CARRIER_DARK_KEY = item.own_key .. "carrier_dark"
local GROUND_VIS_KEY = item.own_key .. "ground_vis"

local function size_radius(ent)
	local multi = ent.SizeMulti or Vector(1, 1)
	return ent.Size * (0.5 * ((multi.X or 1) + (multi.Y or 1)))
end

local function filter_vec2(prev, cur)
	if not prev then return cur end
	return Vector((prev.X + cur.X) * 0.5, (prev.Y + cur.Y) * 0.5)
end

local function entity_po(ent)
	local po = ent and ent.PositionOffset
	if not po then return Vector(0, 0) end
	return Vector(po.X, po.Y)
end

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function head_halo_local(ent, data)
	return entity_head_anchor.GetEntityHeadHaloAnchor(ent, data)
end

local function current_head_geometry_key(npc)
	local spr = npc and npc.GetSprite and npc:GetSprite()
	if not spr then
		return ""
	end
	local anim = spr.GetAnimation and spr:GetAnimation() or ""
	local frame = spr.GetFrame and spr:GetFrame() or -1
	local oanim = spr.GetOverlayAnimation and spr:GetOverlayAnimation() or ""
	local oframe = spr.GetOverlayFrame and spr:GetOverlayFrame() or -1
	local rot = math.floor((tonumber(spr.Rotation) or 0) * 100 + 0.5)
	return table.concat({
		anim,
		tostring(frame),
		oanim,
		tostring(oframe),
		spr.FlipX and "1" or "0",
		spr.FlipY and "1" or "0",
		tostring(rot),
	}, "|")
end

local function halo_screen_pos(ent, offset, data)
	local tick = Isaac.GetFrameCount()
	if halo_pos_tick ~= tick then
		halo_pos_cache = {}
		halo_pos_tick = tick
	end
	local hash = GetPtrHash(ent)
	local cached = halo_pos_cache[hash]
	if cached then return cached end
	offset = offset or Vector(0, 0)
	local po = entity_po(ent)
	local pos = Isaac.WorldToRenderPosition(ent.Position + po) + offset
	local head_off = (data and data.halo_off) or head_halo_local(ent, data)
	if head_off then
		pos = pos + head_off
	end
	halo_pos_cache[hash] = pos
	return pos
end

local function follow_halo(ent, data)
	if not ent or not data then return end
	local key = current_head_geometry_key(ent)
	if data.head_geometry_key ~= key or not data.target_halo_off then
		data.head_geometry_key = key
		data.target_halo_off = head_halo_local(ent, data)
	end
	if not data.target_halo_off then
		return
	end
	data.halo_off = filter_vec2(data.halo_off, data.target_halo_off)
end

local function halo_scale_for(ent)
	local r = size_radius(ent)
	return math.max(0.26, math.min(1.25, 0.16 + r * 0.028))
end

local function fade_color(col, vis)
	vis = clamp(vis or 1, 0, 1)
	local c = Color(col.R, col.G, col.B, (col.A or 1) * vis, col.RO or 0, col.GO or 0, col.BO or 0)
	if col.GetColorize and c.SetColorize then
		local z = col:GetColorize()
		c:SetColorize(z.R, z.G, z.B, z.A)
	end
	return c
end

local function tick_halo_vis(data, target)
	if not data then return 0 end
	data.vis = data.vis or 0
	data.vis = data.vis + (target - data.vis) * item.halo_fade
	if target <= 0 and data.vis < 0.02 then
		data.vis = 0
	elseif target >= 1 and data.vis > 0.98 then
		data.vis = 1
	end
	return data.vis
end

-- Temporary leave / burrow / hide / empty head surface:
-- hard gate via GetEntityHeadPose (Layer1 Visible/IsVisible + Layer2 empty scalp).
-- Does not fade data.vis (birth / permanent fade / final keep using data.vis).

local function gold_color(alpha, dark)
	alpha = alpha or 1
	local col = Color(1, 1, 1, alpha, dark and 0 or 0.18, dark and 0 or 0.12, dark and 0.04 or 0)
	if col.SetColorize then
		if dark then col:SetColorize(0.18, 0.08, 0.32, 1)
		else col:SetColorize(1.15, 0.92, 0.32, 1) end
	end
	return col
end

local function render_halo_at(pos, scale, col)
	if (col.A or 1) < 0.02 or scale < 0.02 then return end
	halo_spr.Rotation = 0
	halo_spr.Color = col
	halo_spr.Scale = Vector(scale * 1.18, scale * 1.18)
	halo_spr:Render(pos, Vector(0, 0), Vector(0, 0))
	halo_spr.Scale = Vector(scale * 0.78, scale * 0.78)
	halo_spr:Render(pos, Vector(0, 0), Vector(0, 0))
	halo_spr.Scale = Vector(1, 1)
	halo_spr.Color = Color(1, 1, 1, 1)
end

local function carrier_anim_state(seed, dark)
	local t = Isaac.GetFrameCount()
	seed = seed or 0
	local phase = seed * 0.37
	local rot_mul = dark and 0.82 or 1
	local rotation = t * 2.0 * rot_mul + math.sin(t * 0.045 + phase) * 10
	local breathe = 1 + math.sin(t * 0.085 + phase) * 0.055
	-- Shared brightness pulse (all arcs dim/brighten together, no chase).
	local pulse_a = 0.55 + math.sin(t * 0.07 + phase) * 0.22
	local alphas = {}
	for i = 1, ARC_COUNT do
		alphas[i] = pulse_a
	end
	return rotation, breathe, alphas
end

local function gospel_birth_pulse(gtag)
	if not gtag or not gtag.birth_frame then return 1 end
	local age = Isaac.GetFrameCount() - gtag.birth_frame
	if age < 0 or age > 5 then return 1 end
	local u = age / 5
	return 1 + math.sin(u * math.pi) * 0.28
end

local function reset_carrier_arc_spr()
	carrier_arc_spr.Rotation = 0
	carrier_arc_spr.Scale = Vector(1, 1)
	carrier_arc_spr.Color = Color(1, 1, 1, 1)
end

--- Unified sacred ring (always ARC_COUNT arcs).
--- with_halo=false skips the inner glow (enemy heads already draw their own halo).
local function render_carrier_sacred_ring(screen_pos, scale, dark, vis, seed, pulse, with_halo)
	if not screen_pos or (vis or 0) < 0.02 then return end
	scale = (scale or item.carrier_ring_scale) * (pulse or 1)
	local rot, breathe, alphas = carrier_anim_state(seed, dark)
	local base_col = gold_color(1, dark)
	if with_halo ~= false then
		render_halo_at(screen_pos, scale * 0.88, fade_color(base_col, vis * 0.72))
	end
	local t = Isaac.GetFrameCount()
	local seed_n = seed or 0
	local base_scale = scale * ARC_SCALE * breathe
	for i = 1, ARC_COUNT do
		local sway = math.sin(t * 0.036 + seed_n * 0.11 + (i - 1) * 1.7) * 3
		local sc = base_scale * (0.96 + (i - 2) * 0.02)
		carrier_arc_spr.Rotation = rot + (i - 1) * ARC_OFFSET + sway
		carrier_arc_spr.Scale = Vector(sc, sc)
		local a = alphas and alphas[i] or (0.55 + math.sin(t * 0.07 + seed_n * 0.37) * 0.22)
		carrier_arc_spr.Color = fade_color(base_col, vis * a)
		carrier_arc_spr:Render(screen_pos, Vector(0, 0), Vector(0, 0))
	end
	reset_carrier_arc_spr()
end

local function enemy_gospel_arc_scale(halo_scale)
	local hs = halo_scale or 0.5
	return (item.carrier_ring_scale or 0.34) * math.max(0.75, 0.55 + hs * 0.95)
end

local function render_carrier_mark(mark, dark, vis, pulse)
	if not mark or (vis or 0) < 0.02 then return end
	render_carrier_sacred_ring(
		Vector(mark.X, mark.Y),
		mark.scale or item.carrier_ring_scale,
		dark,
		vis,
		mark.seed or 0,
		pulse
	)
end

local function render_carrier_marks(marks, dark, vis, pulse)
	if not marks or (vis or 0) < 0.02 then return end
	for i = 1, #marks do
		render_carrier_mark(marks[i], dark, vis, pulse)
	end
end

local function put_carrier_mark(out, screen, scale, style, seed)
	if not out or not screen then return end
	local n = #out + 1
	local slot = out[n]
	if not slot then
		slot = {}
		out[n] = slot
	end
	slot.X = screen.X
	slot.Y = screen.Y
	slot.scale = scale or item.carrier_ring_scale
	slot.style = style or CARRIER_STYLE_FULL
	slot.seed = seed or 0
end

local function clear_mark_list(list)
	if not list then return end
	for i = #list, 1, -1 do
		list[i] = nil
	end
end

-- Orbit tear particles locked to sacred-arc gap centers (same rot clock as arcs).
local function render_orbiters(center, halo_scale, col, vis, tear_col, seed, dark)
	if vis < 0.02 then return end
	local rot, breathe = carrier_anim_state(seed, dark)
	local arc_scale = enemy_gospel_arc_scale(halo_scale)
	local radius = ARC_PNG_RADIUS * arc_scale * ARC_SCALE * breathe
	local small = (halo_scale or 0.5) * 0.4
	local tear_scale = math.max(0.28, (halo_scale or 0.5) * 0.7)
	local n = math.min(item.orbit_tears or ARC_COUNT, ARC_COUNT)
	for i = 1, n do
		-- Arc i midpoint: rot + (i-1)*OFFSET + ART_MID; gap center = + OFFSET/2.
		local ang = rot + (i - 1) * ARC_OFFSET + ARC_OFFSET * 0.5 + ARC_ART_MID_DEG
		local pos = center + auxi.MakeVector(ang) * radius
		render_halo_at(pos, small, fade_color(col, vis))
		symbol_spr.Color = tear_col
		symbol_spr.Scale = Vector(tear_scale, tear_scale)
		symbol_spr.Rotation = 0
		symbol_spr:Render(pos, Vector(0, 0), Vector(0, 0))
	end
	symbol_spr.Scale = Vector(1, 1)
	symbol_spr.Rotation = 0
	symbol_spr.Color = Color(1, 1, 1, 1)
end

local function render_halo_stack(ent, offset, col, vis, data)
	local pos = halo_screen_pos(ent, offset, data)
	local base_scale = halo_scale_for(ent)
	render_halo_at(pos, base_scale, fade_color(col, vis))
	return pos, base_scale
end

--- Tear/knife/bomb carrier: W2R(Position + PO) + callback offset.
local function carrier_screen_pos(ent, offset)
	offset = offset or Vector(0, 0)
	local po = ent.PositionOffset or Vector(0, 0)
	return Isaac.WorldToRenderPosition(ent.Position + po) + offset
end

local function tick_smooth_vis(store, key, want, rate)
	if not store then return 0 end
	rate = rate or item.carrier_fade or 0.16
	local vis = store[key] or 0
	local target = want and 1 or 0
	vis = vis + (target - vis) * rate
	if target <= 0 and vis < 0.02 then
		vis = 0
	elseif target >= 1 and vis > 0.98 then
		vis = 1
	end
	store[key] = vis
	return vis
end

local function render_carrier_at(screen_pos, dark, vis, scale, seed, pulse)
	if not screen_pos then return end
	render_carrier_mark({
		X = screen_pos.X,
		Y = screen_pos.Y,
		scale = scale,
		style = CARRIER_STYLE_FULL,
		seed = seed or 0,
	}, dark, vis, pulse)
end

--- Smooth appear/disappear. Call even when want=false so fade-out can finish while entity still exists.
local function render_carrier_overlay(ent, offset, dark, want, gtag)
	if not ent then return end
	if want == nil then want = true end
	local d = ent:GetData()
	if dark ~= nil then
		d[CARRIER_DARK_KEY] = dark and true or false
	end
	dark = d[CARRIER_DARK_KEY] == true
	local vis = tick_smooth_vis(d, CARRIER_VIS_KEY, want)
	if vis < 0.02 then return end
	local scale = item.carrier_ring_scale
	if ent.Scale then
		scale = scale * math.max(0.7, math.min(1.4, ent.Scale))
	end
	local pulse = gospel_birth_pulse(gtag)
	render_carrier_at(
		carrier_screen_pos(ent, offset),
		dark,
		vis,
		scale,
		ent.InitSeed or GetPtrHash(ent),
		pulse
	)
end

local function carrier_should_draw(ent, want)
	if want then return true end
	local d = ent and ent:GetData()
	return d and (d[CARRIER_VIS_KEY] or 0) >= 0.02
end

-- Spirit Sword FX: MeusNIL holds Hit1/Hit2 bead screens; fade out when capsules die (no player-pos fallback).
local SWORD_HIT_NULL_LAYERS = { "Hit1", "Hit2" }
local SWORD_FX_KEY = item.own_key .. "sword_fx"
local SWORD_HELPER_KEY = item.own_key .. "sword_fx_helper"

local function knife_hitbox_carrier_scale(size)
	local base = item.carrier_ring_scale or 0.34
	local sz = size or 10
	return base * math.max(0.75, sz / 10)
end

local function sword_hit_capsules(hitbox)
	local out = {}
	if not hitbox or not hitbox.GetNullCapsule then return out end
	for i = 1, #SWORD_HIT_NULL_LAYERS do
		local name = SWORD_HIT_NULL_LAYERS[i]
		local ok, cap = pcall(function() return hitbox:GetNullCapsule(name) end)
		if ok and cap and cap.GetPosition then
			local pos = cap:GetPosition()
			local size = (cap.GetF1 and cap:GetF1()) or 0
			if pos and size and size > 0.5 then
				out[#out + 1] = { pos = Vector(pos.X, pos.Y), size = size }
			end
		end
	end
	return out
end

local function collect_sword_carrier_marks(hitbox, offset, marks_out)
	marks_out = marks_out or {}
	clear_mark_list(marks_out)
	offset = offset or Vector(0, 0)
	local caps = sword_hit_capsules(hitbox)
	for i = 1, #caps do
		local c = caps[i]
		local s = Isaac.WorldToRenderPosition(c.pos) + offset
		put_carrier_mark(marks_out, s, knife_hitbox_carrier_scale(c.size), CARRIER_STYLE_FULL, i * 31)
	end
	return marks_out
end

local function ensure_sword_fx_helper(hitbox)
	if not hitbox then return nil end
	local d = hitbox:GetData()
	local helper = d[SWORD_HELPER_KEY]
	if helper and helper.Exists and helper:Exists() then
		local hd = helper:GetData()
		if hd and hd[SWORD_FX_KEY] then
			return helper
		end
	end
	local player = auxi.check_spawner_player(hitbox)
		or auxi.check_near_spawner_player(hitbox)
		or auxi.check_near_spawner_player(hitbox, { checklist = { "Parent" } })
	helper = auxi.fire_nil(hitbox.Position, Vector(0, 0), {
		cooldown = 999999,
		player = player,
	})
	if not helper then return nil end
	helper = helper:ToEffect() or helper
	helper.Visible = true
	helper.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	helper.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	helper.Velocity = Vector.Zero
	if helper.ClearEntityFlags then
		helper:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	end
	local spr = helper:GetSprite()
	if spr then
		spr.Color = Color(1, 1, 1, 0)
	end
	local hd = helper:GetData()
	hd.skip_nil_distance_cull = true
	hd.removecd = 999999
	hd.nil_mode = "visual_only"
	hd[Nil_holder.own_key .. "work"] = function() return true end
	hd[SWORD_FX_KEY] = {
		vis = 0,
		want = false,
		dark = false,
		marks = {},
		touch_frame = Isaac.GetFrameCount(),
		hitbox_ptr = GetPtrHash(hitbox),
	}
	d[SWORD_HELPER_KEY] = helper
	return helper
end

-- Called from POST_KNIFE_RENDER: sync only. No entity-Position fallback when capsules are inactive.
local function sync_sword_fx_helper(hitbox, offset, dark_owner)
	if not hitbox then return end
	local gtag = select(1, gospel_tag_from_knife(hitbox))
	local spr = hitbox:GetSprite()
	local anim = spr and spr:GetAnimation() or ""
	local active_swing = anim ~= "" and (string.sub(anim, 1, 4) == "Spin"
		or string.sub(anim, 1, 6) == "Attack"
		or string.sub(anim, 1, 5) == "Swing")
	local want_gospel = gtag ~= nil and active_swing
	local d = hitbox:GetData()
	local helper = d[SWORD_HELPER_KEY]
	local alive_helper = helper and helper.Exists and helper:Exists() and helper:GetData()[SWORD_FX_KEY]
	local probe_marks = {}
	collect_sword_carrier_marks(hitbox, offset, probe_marks)
	local want = want_gospel and #probe_marks > 0
	if not want and not alive_helper then return end
	if not want and alive_helper then
		local fx = helper:GetData()[SWORD_FX_KEY]
		fx.want = false
		fx.touch_frame = Isaac.GetFrameCount()
		-- Keep last marks so MeusNIL can fade them out (do not snap to player).
		return
	end
	helper = ensure_sword_fx_helper(hitbox)
	if not helper then return end
	local fx = helper:GetData()[SWORD_FX_KEY]
	local owner = (gtag and gtag.owner) or dark_owner
	helper.Position = hitbox.Position
	if hitbox.PositionOffset then
		helper.PositionOffset = Vector(hitbox.PositionOffset.X, hitbox.PositionOffset.Y)
	end
	fx.want = true
	fx.dark = item.is_seija(owner)
	if not fx.marks then fx.marks = {} end
	collect_sword_carrier_marks(hitbox, offset, fx.marks)
	fx.touch_frame = Isaac.GetFrameCount()
	fx.hitbox_ptr = GetPtrHash(hitbox)
end

local function tick_and_render_sword_fx_helper(helper)
	if not helper or not helper.Exists or not helper:Exists() then return end
	local fx = helper:GetData()[SWORD_FX_KEY]
	if not fx then return end
	local frame = Isaac.GetFrameCount()
	if (fx.touch_frame or frame) < frame - 2 then
		fx.want = false
	end
	local vis = tick_smooth_vis(fx, "vis", fx.want == true)
	if vis < 0.02 and fx.want ~= true then
		helper:GetData()[SWORD_FX_KEY] = nil
		helper:Remove()
		return
	end
	-- Hit capsules: full sacred rings (same as tear/laser carriers).
	render_carrier_marks(fx.marks, fx.dark, vis, 1)
end

local function clear_sword_fx_helpers()
	for _, effect in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, enums.Entities.ID_EFFECT_MeusNIL, -1, false, false)) do
		if effect and effect:GetData()[SWORD_FX_KEY] then
			effect:Remove()
		end
	end
end

-- Laser overlay: one MeusNIL helper per gospel laser.
-- POST_LASER_RENDER only syncs path/offset; POST_EFFECT_RENDER draws + fades.
-- MeusNIL is fine — must stay Visible (nil sprite) so RENDER fires, and skip Nil_holder cull.
local LASER_FX_KEY = item.own_key .. "laser_fx"
local LASER_HELPER_KEY = item.own_key .. "laser_fx_helper"

-- Visible / collision polyline only. Do NOT append GetEndPoint(): that is the
-- theoretical max-range tip and continues through rocks/walls. Reverie (and
-- similar) walk GetSamples() alone for laser path work.
local function laser_path_world_points(laser, out)
	return weapon_path.laser_path_world_points(laser, out)
end

local function for_each_path_bead(path, spacing, fn)
	weapon_path.for_each_path_bead(path, spacing, function(world, _idx)
		fn(world)
	end)
end

-- Laser beads: WorldToRenderPosition(world + laser.PositionOffset) + callback offset.
local function laser_bead_screen(world, po, offset)
	return Isaac.WorldToRenderPosition(world + po) + (offset or Vector(0, 0))
end

local function collect_laser_carrier_marks(laser, offset, marks_out, path_buf, scale, seed)
	marks_out = marks_out or {}
	clear_mark_list(marks_out)
	if not laser then return marks_out end
	local po = laser.PositionOffset or Vector(0, 0)
	local path = laser_path_world_points(laser, path_buf)
	local beads = {}
	for_each_path_bead(path, LASER_CARRIER_SPACING, function(world)
		beads[#beads + 1] = laser_bead_screen(world, po, offset)
	end)
	local n = #beads
	scale = scale or item.carrier_ring_scale
	seed = seed or 0
	for i = 1, n do
		-- Full 3-arc sacred ring on every bead (ends slightly larger).
		local sc = scale * 0.9
		if i == 1 or i == n then
			sc = scale
		end
		put_carrier_mark(marks_out, beads[i], sc, CARRIER_STYLE_FULL, seed + i * 17)
	end
	return marks_out
end

local function ensure_laser_fx_helper(laser)
	if not laser then return nil end
	local d = laser:GetData()
	local helper = d[LASER_HELPER_KEY]
	if helper and helper.Exists and helper:Exists() then
		local hd = helper:GetData()
		if hd and hd[LASER_FX_KEY] then
			return helper
		end
	end
	local player = auxi.check_spawner_player(laser) or auxi.check_near_spawner_player(laser)
	helper = auxi.fire_nil(laser.Position, Vector(0, 0), {
		cooldown = 999999,
		player = player,
	})
	if not helper then return nil end
	helper = helper:ToEffect() or helper
	-- Keep Visible so POST_EFFECT_RENDER runs; nil_effect has no visible art.
	helper.Visible = true
	helper.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	helper.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	helper.Velocity = Vector.Zero
	if helper.ClearEntityFlags then
		helper:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	end
	local spr = helper:GetSprite()
	if spr then
		spr.Color = Color(1, 1, 1, 0)
	end
	local hd = helper:GetData()
	hd.skip_nil_distance_cull = true
	hd.removecd = 999999
	hd.nil_mode = "visual_only"
	hd[Nil_holder.own_key .. "work"] = function() return true end
	hd[LASER_FX_KEY] = {
		vis = 0,
		want = false,
		dark = false,
		scale = item.carrier_ring_scale,
		marks = {},
		path_buffer = {},
		birth_frame = nil,
		seed = laser.InitSeed or GetPtrHash(laser),
		touch_frame = Isaac.GetFrameCount(),
		laser_ptr = GetPtrHash(laser),
	}
	d[LASER_HELPER_KEY] = helper
	return helper
end

-- Called from POST_LASER_RENDER: keep helper path/offset in sync while laser exists.
local function sync_laser_fx_helper(laser, offset, dark_owner)
	if not laser then return end
	local gtag = gospel_tag_from_laser(laser)
	local want = gtag ~= nil
	local d = laser:GetData()
	local helper = d[LASER_HELPER_KEY]
	local alive_helper = helper and helper.Exists and helper:Exists() and helper:GetData()[LASER_FX_KEY]
	if not want and not alive_helper then return end
	if not want and alive_helper then
		local fx = helper:GetData()[LASER_FX_KEY]
		fx.want = false
		fx.touch_frame = Isaac.GetFrameCount()
		return
	end
	helper = ensure_laser_fx_helper(laser)
	if not helper then return end
	local fx = helper:GetData()[LASER_FX_KEY]
	local owner = (gtag and gtag.owner) or dark_owner
	local dark = item.is_seija(owner)
	local scale = item.carrier_ring_scale
	if laser.Scale then
		scale = scale * math.max(0.7, math.min(1.4, laser.Scale))
	end
	helper.Position = laser.Position
	if laser.PositionOffset then
		helper.PositionOffset = Vector(laser.PositionOffset.X, laser.PositionOffset.Y)
	end
	fx.want = true
	fx.dark = dark
	fx.scale = scale
	if gtag then
		fx.birth_frame = gtag.birth_frame
		fx.seed = (laser.InitSeed or GetPtrHash(laser))
	end
	if not fx.marks then fx.marks = {} end
	if not fx.path_buffer then fx.path_buffer = {} end
	-- Refresh every laser render callback (no multi-frame path cache — avoids lag vs beam).
	collect_laser_carrier_marks(laser, offset, fx.marks, fx.path_buffer, scale, fx.seed)
	fx.touch_frame = Isaac.GetFrameCount()
	fx.laser_ptr = GetPtrHash(laser)
end

local function tick_and_render_laser_fx_helper(helper)
	if not helper or not helper.Exists or not helper:Exists() then return end
	local fx = helper:GetData()[LASER_FX_KEY]
	if not fx then return end
	local frame = Isaac.GetFrameCount()
	-- Laser POST_LASER_RENDER stopped touching us → laser is gone; fade out in place.
	if (fx.touch_frame or frame) < frame - 2 then
		fx.want = false
	end
	local vis = tick_smooth_vis(fx, "vis", fx.want == true)
	if vis < 0.02 and fx.want ~= true then
		helper:GetData()[LASER_FX_KEY] = nil
		helper:Remove()
		return
	end
	render_carrier_marks(
		fx.marks,
		fx.dark,
		vis,
		gospel_birth_pulse(fx.birth_frame and { birth_frame = fx.birth_frame } or nil)
	)
end

local function clear_laser_fx_helpers()
	for _, effect in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, enums.Entities.ID_EFFECT_MeusNIL, -1, false, false)) do
		if effect and effect:GetData()[LASER_FX_KEY] then
			effect:Remove()
		end
	end
end

local function push_epic_ground_linger(screen, dark, vis)
	if not screen or (vis or 0) < 0.02 then return end
	epic_ground_lingers[#epic_ground_lingers + 1] = {
		screen = Vector(screen.X, screen.Y),
		dark = dark and true or false,
		vis = vis,
	}
end

local function render_epic_ground_for_rocket(ent, offset, dark, want)
	if not ent then return end
	local d = ent:GetData()
	if dark ~= nil then
		d[CARRIER_DARK_KEY] = dark and true or false
	end
	dark = d[CARRIER_DARK_KEY] == true
	local vis = tick_smooth_vis(d, GROUND_VIS_KEY, want)
	local screen = Isaac.WorldToRenderPosition(ent.Position) + (offset or Vector(0, 0))
	d[item.own_key.."ground_screen"] = { X = screen.X, Y = screen.Y }
	if vis < 0.02 then return end
	render_carrier_at(screen, dark, vis, item.carrier_ring_scale * 1.05, ent.InitSeed or GetPtrHash(ent), 1)
end

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

function item.force_seija()
	local debug = debug_root()
	return debug and debug.GospelForceSeija == true
end

function item.is_seija(player)
	if item.force_seija() then return true end
	return player and auxi.should_do_Seija(player) == true
end

local function room_state()
	item.room = item.room or {
		revelations = 0,
		judgement = false,
		accept_serial = 0,
		final = nil,
	}
	return item.room
end

local function gospel_data(npc)
	if not npc then return nil end
	return npc:GetData()[item.own_key]
end

local function ref_entity(ref)
	if not ref then return nil end
	if ref.Entity then return ref.Entity end
	if ref.GetData and ref.Type then return ref end
	return nil
end

local function spawn_light(player, pos, dmg_mul, dark, po, visual_only)
	player = player or auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
	pos = pos or player.Position
	local sub = dark and 2 or 0
	local q = Isaac.Spawn(1000, EffectVariant.CRACK_THE_SKY, sub, pos, Vector(0, 0), player):ToEffect()
	if visual_only then
		q.CollisionDamage = 0
	else
		q.CollisionDamage = (player.Damage or 3.5) * (dmg_mul or item.revelation_mul)
	end
	if po then
		q.PositionOffset = po
	end
	local d = q:GetData()
	d[item.own_key.."revelation"] = true
	d[item.own_key.."dark"] = dark and true or false
	if dark then
		q:GetSprite().Color = gold_color(1, true)
	end
	if not visual_only then
		sound_tracker.PlayStackedSound(dark and SoundEffect.SOUND_HOLY or SoundEffect.SOUND_ANGEL_BEAM, 1, 1, false, 0, 2)
	end
	return q
end

local function is_boss(ent)
	local npc = ent and ent.ToNPC and ent:ToNPC()
	return npc and npc.IsBoss and npc:IsBoss() == true
end

local function has_gospel(ent)
	local data = gospel_data(ent)
	return data ~= nil and data.fading ~= true
end

local function push_receive_flash(screen, dark)
	if not screen then return end
	receive_flashes[#receive_flashes + 1] = {
		screen = Vector(screen.X, screen.Y),
		age = 0,
		life = 8,
		dark = dark and true or false,
	}
end

local function push_gospel_link(from_screen, to_screen, dark, from_hash, to_hash)
	if not from_screen or not to_screen then return end
	gospel_links[#gospel_links + 1] = {
		from_screen = Vector(from_screen.X, from_screen.Y),
		to_screen = Vector(to_screen.X, to_screen.Y),
		from_hash = from_hash,
		to_hash = to_hash,
		age = 0,
		life = item.link_life,
		dark = dark and true or false,
	}
end

-- Links / flashes draw in MC_POST_RENDER (no entity callback offset).
-- Prefer this-frame NPC_RENDER halo cache; fall back to frozen screen snapshots.
local function link_screen_ends(link)
	local a = (link.from_hash and halo_pos_cache[link.from_hash]) or link.from_screen
	local b = (link.to_hash and halo_pos_cache[link.to_hash]) or link.to_screen
	return a, b
end

local function render_gospel_links()
	for i = 1, #gospel_links do
		local link = gospel_links[i]
		local t = link.age / math.max(1, link.life)
		local grow = clamp(link.age / 4, 0, 1)
		local fade = 1
		if t > 0.55 then
			fade = 1 - (t - 0.55) / 0.45
		end
		if fade >= 0.02 then
			local a, b = link_screen_ends(link)
			if a and b then
				local tip = Vector(lerp(a.X, b.X, grow), lerp(a.Y, b.Y, grow))
				local col = link.dark and KColor(0.45, 0.2, 0.75, 0.75 * fade) or KColor(1.0, 0.88, 0.35, 0.8 * fade)
				if Isaac.DrawLine then
					Isaac.DrawLine(a, tip, col, col, 1.25)
				end
				if grow > 0.92 then
					render_halo_at(b, 0.22, fade_color(gold_color(0.95, link.dark), fade))
				end
			end
		end
	end
end

local function render_receive_flashes()
	for i = 1, #receive_flashes do
		local flash = receive_flashes[i]
		local u = flash.age / math.max(1, flash.life)
		local vis = 1 - u
		if vis > 0.02 and flash.screen then
			local sc = lerp(0.18, 0.55, u)
			render_halo_at(flash.screen, sc, fade_color(gold_color(1, flash.dark), vis))
		end
	end
end

local function halo_screen_snapshot(ent, data, linger)
	if linger and linger.screen then
		return Vector(linger.screen.X, linger.screen.Y)
	end
	if not ent then return nil end
	local hash = GetPtrHash(ent)
	local cached = halo_pos_cache[hash]
	if cached then return Vector(cached.X, cached.Y) end
	local gd = data or gospel_data(ent)
	if gd and gd.last_halo_screen then
		return Vector(gd.last_halo_screen.X, gd.last_halo_screen.Y)
	end
	-- Fresh convert before first NPC_RENDER: approximate callback offset ≈ scroll.
	if gd then follow_halo(ent, gd) end
	local head = (gd and gd.halo_off) or head_halo_local(ent, gd) or Vector(0, -12)
	local room = Game():GetRoom()
	local scroll = (room and room.GetRenderScrollOffset and room:GetRenderScrollOffset()) or Vector(0, 0)
	return Isaac.WorldToRenderPosition(ent.Position + entity_po(ent)) + scroll + head
end

local function find_spread_targets(source, count)
	count = count or 1
	local pos = source.Position
	local blocked = {[GetPtrHash(source)] = true}
	local list = {}
	for _ = 1, count do
		local target = auxi.get_by_nearest_enemy(pos, function(ent)
			if blocked[GetPtrHash(ent)] then return false end
			if (ent.Position - pos):Length() > item.spread_radius then return false end
			if has_gospel(ent) then return false end
			return true
		end)
		if not target then break end
		list[#list + 1] = target
		blocked[GetPtrHash(target)] = true
	end
	return list
end

local function clear_gospel(npc)
	if not npc then return end
	npc:GetData()[item.own_key] = nil
end

local function apply_gospel(npc, player)
	if not auxi.isenemies(npc) then return end
	local d = npc:GetData()
	local data = d[item.own_key]
	local room = room_state()
	if type(data) ~= "table" then
		room.accept_serial = (room.accept_serial or 0) + 1
		data = {
			preach_dmg = 0,
			boss_dmg = 0,
			vis = 0.45,
			accept_serial = room.accept_serial,
		}
		d[item.own_key] = data
	end
	data.fading = nil
	if (data.vis or 0) < 0.45 then
		data.vis = 0.45
	end
	if not data.accept_serial then
		room.accept_serial = (room.accept_serial or 0) + 1
		data.accept_serial = room.accept_serial
	end
	if player then data.owner = player end
	follow_halo(npc, data)
end

-- RGON EntityKnife:GetHitList() = engine melee Null-capsule hits (Entity.Index).
-- Not KNIFE_COLLISION (Size@player) and not FindInCapsule DIY.
local HITLIST_APPLIED_KEY = item.own_key .. "hitlist_applied"
local HITLIST_ATTACK_KEY = item.own_key .. "hitlist_attack"

local function foreach_hitlist_index(list, fn)
	if not list or not fn then return end
	if type(list) == "table" then
		for _, idx in pairs(list) do
			if type(idx) == "number" then fn(idx) end
		end
		return
	end
	local i = 0
	local v = list[i]
	if v ~= nil then
		while v ~= nil do
			if type(v) == "number" then fn(v) end
			i = i + 1
			v = list[i]
		end
		return
	end
	i = 1
	v = list[i]
	while v ~= nil do
		if type(v) == "number" then fn(v) end
		i = i + 1
		v = list[i]
	end
end

local function apply_gospel_from_knife_hitlist(knife)
	if not knife or not knife.GetHitList then return end
	local gtag, attack = gospel_tag_from_knife(knife)
	if not gtag or not attack then return end
	local ok, list = pcall(function() return knife:GetHitList() end)
	if not ok or not list then return end
	local d = knife:GetData()
	if d[HITLIST_ATTACK_KEY] ~= attack.id then
		d[HITLIST_ATTACK_KEY] = attack.id
		d[HITLIST_APPLIED_KEY] = {}
	end
	local applied = d[HITLIST_APPLIED_KEY]
	local by_index = nil
	local player = gtag.owner
		or auxi.check_spawner_player(knife)
		or auxi.check_near_spawner_player(knife, { checklist = { "Parent" } })
	foreach_hitlist_index(list, function(idx)
		if applied[idx] then return end
		if not by_index then
			by_index = {}
			for _, ent in pairs(auxi.getenemies()) do
				if ent and ent.Index ~= nil then
					by_index[ent.Index] = ent
				end
			end
		end
		local ent = by_index[idx]
		if ent and auxi.isenemies(ent) then
			applied[idx] = true
			apply_gospel(ent, player)
		end
	end)
end

local function play_spread_to(from_ent, to_ent, player, dark, from_linger)
	if not to_ent then return end
	local from_data = from_ent and gospel_data(from_ent)
	local to_data = gospel_data(to_ent)
	if to_ent and not to_data then
		to_data = gospel_data(to_ent)
	end
	if to_data then follow_halo(to_ent, to_data) end
	if from_ent and from_data then follow_halo(from_ent, from_data) end

	-- Must use NPC_RENDER screen anchors (WTRP + callback offset + head). Recomputing from
	-- world+head_off in POST_RENDER skips scroll/interpolation and drifts in large rooms.
	local from_screen = halo_screen_snapshot(from_ent, from_data, from_linger)
	local to_screen = halo_screen_snapshot(to_ent, to_data, nil)
	if not from_screen or not to_screen then return end

	local from_hash = from_ent and GetPtrHash(from_ent) or nil
	local to_hash = GetPtrHash(to_ent)
	push_gospel_link(from_screen, to_screen, dark, from_hash, to_hash)
	push_receive_flash(to_screen, dark)
end

local function collect_gospel_enemies()
	local list = {}
	for _, ent in pairs(auxi.getenemies()) do
		if has_gospel(ent) then
			list[#list + 1] = ent
		end
	end
	table.sort(list, function(a, b)
		local da = gospel_data(a)
		local db = gospel_data(b)
		return (da and da.accept_serial or 0) < (db and db.accept_serial or 0)
	end)
	return list
end

local function build_gospel_tree(nodes)
	local edges = {}
	if #nodes <= 1 then return edges end
	local in_tree = {[GetPtrHash(nodes[1])] = true}
	for i = 2, #nodes do
		local best = nil
		local best_d = 1e12
		local node = nodes[i]
		for j = 1, #nodes do
			local other = nodes[j]
			if in_tree[GetPtrHash(other)] then
				local d = (node.Position - other.Position):Length()
				if d < best_d then
					best_d = d
					best = other
				end
			end
		end
		if best then
			edges[#edges + 1] = {from = best, to = node}
			in_tree[GetPtrHash(node)] = true
		end
	end
	return edges
end

local function clear_all_gospel_marks()
	for _, ent in pairs(auxi.getenemies()) do
		if gospel_data(ent) then
			clear_gospel(ent)
		end
	end
end

local function begin_final_revelation(player)
	local room = room_state()
	if room.judgement or room.final then return end
	room.judgement = true
	local dark = item.is_seija(player)
	local nodes = collect_gospel_enemies()
	if not dark then
		-- Fill remaining living enemies into the network.
		for _, ent in pairs(auxi.getenemies()) do
			if not has_gospel(ent) then
				apply_gospel(ent, player)
			end
		end
		nodes = collect_gospel_enemies()
	end
	local edges = dark and {} or build_gospel_tree(nodes)
	room.final = {
		player = player,
		dark = dark,
		t = 0,
		phase = "silence",
		nodes = nodes,
		edges = edges,
		struck = false,
	}
	Game():ShakeScreen(8)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SUPERHOLY, 0.85, 1.05, false, 0, 2)
end

local function strike_final_revelation(final)
	if final.struck then return end
	final.struck = true
	local player = final.player
	local dark = final.dark
	local targets = {}
	for _, ent in pairs(auxi.getenemies()) do
		if has_gospel(ent) then
			targets[#targets + 1] = ent
		end
	end
	-- Deal judgement damage immediately so batched pillars do not desync combat.
	local dmg = (player and player.Damage or 3.5) * (item.judgement_mul or 3)
	for i = 1, #targets do
		local ent = targets[i]
		if ent and ent.TakeDamage then
			ent:TakeDamage(dmg, 0, EntityRef(player), 0)
		end
	end
	local batch = 5
	for i = 1, #targets do
		local ent = targets[i]
		local delay = math.floor((i - 1) / batch)
		delay_buffer.addeffe(function()
			if not ent or not ent.Exists or not ent:Exists() then return end
			spawn_light(player, ent.Position, item.judgement_mul, dark, entity_po(ent), true)
		end, {}, delay)
	end
	Game():ShakeScreen(16)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_ANGEL_BEAM, 1.1, 0.95, false, 0, 2)
	delay_buffer.addeffe(function()
		clear_all_gospel_marks()
		local room = room_state()
		room.final = nil
	end, {}, 10)
end

local function tick_final_revelation()
	local room = room_state()
	local final = room.final
	if not final then return end
	final.t = (final.t or 0) + 1
	local t = final.t
	if final.phase == "silence" then
		if t >= item.final_silence then
			final.phase = "network"
			final.t = 0
			-- Reveal tree links quickly.
			for i = 1, #(final.edges or {}) do
				local e = final.edges[i]
				play_spread_to(e.from, e.to, final.player, final.dark)
			end
		end
	elseif final.phase == "network" then
		if t >= item.final_network then
			final.phase = "rise"
			final.t = 0
		end
	elseif final.phase == "rise" then
		if t >= item.final_rise then
			final.phase = "strike"
			final.t = 0
			strike_final_revelation(final)
		end
	end
end

local function trigger_revelation(player, pos, po)
	local dark = item.is_seija(player)
	spawn_light(player, pos, dark and item.dark_revelation_mul or item.revelation_mul, dark, po)
	local room = room_state()
	if room.judgement or room.final then return end
	room.revelations = (room.revelations or 0) + 1
	if room.revelations >= item.judgement_need then
		begin_final_revelation(player)
	end
end

local function preach(npc, player)
	if not npc or not player then return false end
	if item.is_seija(player) then
		-- Seija: no spread; meeting the preach threshold drops a dark revelation on the source.
		trigger_revelation(player, npc.Position, entity_po(npc))
		return true
	end
	local targets = find_spread_targets(npc, 1)
	local target = targets[1]
	if not target then return false end
	apply_gospel(target, player)
	play_spread_to(npc, target, player, false)
	target:TakeDamage((player.Damage or 3.5) * item.preach_mul, 0, EntityRef(player), 0)
	return true
end

local function spread_on_death(npc, player, linger)
	if item.is_seija(player) then return end
	local targets = find_spread_targets(npc, item.death_spread)
	for i = 1, #targets do
		apply_gospel(targets[i], player)
		play_spread_to(npc, targets[i], player, false, linger)
	end
end

local function on_gospel_damage(npc, amount, player)
	local data = gospel_data(npc)
	if not data or data.fading then return end
	player = player or data.owner
	if not player then return end
	local atk = player.Damage or 3.5
	data.preach_dmg = (data.preach_dmg or 0) + amount
	local preach_need = atk * item.preach_need_mul
	local n = 0
	while data.preach_dmg >= preach_need and n < item.preach_burst_cap do
		if not preach(npc, player) then break end
		data.preach_dmg = data.preach_dmg - preach_need
		n = n + 1
	end
	if not is_boss(npc) then return end
	data.boss_dmg = (data.boss_dmg or 0) + amount
	local boss_need = atk * item.boss_revelation_need_mul
	n = 0
	while data.boss_dmg >= boss_need and n < item.preach_burst_cap do
		data.boss_dmg = data.boss_dmg - boss_need
		trigger_revelation(player, npc.Position, entity_po(npc))
		n = n + 1
	end
end

local function source_is_revelation(source)
	local ent = source and source.Entity
	if not ent then return false end
	local d = ent:GetData()
	return d and d[item.own_key.."revelation"] == true
end

local function source_player(source, extra_source)
	local ent = ref_entity(extra_source) or ref_entity(source)
	if not ent then return nil end
	if ent.ToPlayer and ent:ToPlayer() then return ent:ToPlayer() end
	return auxi.check_spawner_player(ent) or auxi.check_near_spawner_player(ent)
end

local function source_applies_gospel(source, extra_source, target_ent)
	local function try_ent(ent)
		if not ent then return false, nil end
		if ent.Type == EntityType.ENTITY_FAMILIAR
			and ent.Variant == FamiliarVariant.ABYSS_LOCUST
			and ent.SubType == item.entity then
			return true, auxi.check_spawner_player(ent)
		end
		-- Knives (incl. CLUB_HITBOX): resolve parent sword Attack when needed.
		-- Lasers (Trisagion child beams): resolve parent LASERSHOT tear Attack when needed.
		local gtag
		if ent.Type == EntityType.ENTITY_KNIFE then
			gtag = select(1, gospel_tag_from_knife(ent))
		elseif ent.Type == EntityType.ENTITY_LASER then
			gtag = select(1, gospel_tag_from_laser(ent))
		else
			gtag = gospel_tag_from_member(ent)
		end
		if gtag then
			return true, gtag.owner or auxi.check_spawner_player(ent) or auxi.check_near_spawner_player(ent)
		end
		local attack = select(1, attack_registry.lookup_recent_for_damage(ent))
		if attack and attack.tags and attack.tags.gospel then
			return true, attack.tags.gospel.owner or attack.player
		end
		-- CLUB_HITBOX may already be unbound; parent blade still carries the Attack.
		if ent.Type == EntityType.ENTITY_KNIFE then
			local parent = hitbox_parent_knife(ent)
			if parent then
				gtag = select(1, gospel_tag_from_member(parent))
				if gtag then
					return true, gtag.owner or auxi.check_spawner_player(parent)
				end
				attack = select(1, attack_registry.lookup_recent_for_damage(parent))
				if attack and attack.tags and attack.tags.gospel then
					return true, attack.tags.gospel.owner or attack.player
				end
			end
		end
		if ent.Type == EntityType.ENTITY_LASER then
			local parent = ent.Parent
			if parent and parent.Type == EntityType.ENTITY_TEAR then
				attack = select(1, attack_registry.lookup_recent_for_damage(parent))
				if attack and attack.tags and attack.tags.gospel then
					return true, attack.tags.gospel.owner or attack.player
				end
			end
		end
		return false, nil
	end
	-- RGON: lasers AND melee hitboxes put the real weapon on ExtraSource; Source is often the player.
	local ok, owner = try_ent(ref_entity(extra_source))
	if ok then return true, owner end
	ok, owner = try_ent(ref_entity(source))
	if ok then return true, owner end

	-- Epic/Dr + sword swing window: Source is often the player.
	local player = source_player(source, extra_source)
	if player then
		local attack = select(1, attack_registry.lookup_recent_player_blast(player, target_ent and target_ent.Position))
		if attack and attack.tags and attack.tags.gospel then
			return true, attack.tags.gospel.owner or player
		end
	end
	return false, nil
end

local function push_linger(npc, data)
	if not npc or not data then return end
	local screen = data.last_halo_screen and Vector(data.last_halo_screen.X, data.last_halo_screen.Y) or nil
	lingering_halos[#lingering_halos + 1] = {
		pos = Vector(npc.Position.X, npc.Position.Y),
		po = entity_po(npc),
		off = data.halo_off and Vector(data.halo_off.X, data.halo_off.Y) or Vector(0, 0),
		screen = screen,
		vis = math.max(data.vis or 0, 0.45),
		scale = halo_scale_for(npc),
		dark = item.is_seija(data.owner),
		seed = npc.InitSeed or GetPtrHash(npc),
		hold = 12,
	}
end

local function on_gospel_killed(npc)
	local data = gospel_data(npc)
	if not data or data.done then return end
	data.done = true
	data.fading = true
	follow_halo(npc, data)
	local linger = {
		pos = Vector(npc.Position.X, npc.Position.Y),
		off = data.halo_off and Vector(data.halo_off.X, data.halo_off.Y) or Vector(0, 0),
		screen = data.last_halo_screen and Vector(data.last_halo_screen.X, data.last_halo_screen.Y) or nil,
	}
	push_linger(npc, data)
	local player = data.owner or auxi.have_player_has_collectible(item.entity)
	local pos = npc.Position
	local po = entity_po(npc)
	clear_gospel(npc)
	if player then
		spread_on_death(npc, player, linger)
		trigger_revelation(player, pos, po)
	end
end

local SERIAL_KEY = item.own_key .. "attack_serial"
local SERIAL_BY_SOURCE_KEY = item.own_key .. "attack_serial_by_source"

local function player_source_counters(player)
	if not player then return nil end
	local pd = player:GetData()
	local t = pd[SERIAL_BY_SOURCE_KEY]
	if type(t) ~= "table" then
		t = {}
		pd[SERIAL_BY_SOURCE_KEY] = t
	end
	return t
end

local function attack_source_id(event, player)
	if event and event.source_id then return event.source_id end
	if event and event.attack and event.attack.source_id then
		return event.attack.source_id
	end
	if player then
		return "player:" .. tostring(GetPtrHash(player))
	end
	return "player:nil"
end

local function source_attack_serial(player, source_id)
	local t = player_source_counters(player)
	if not t or not source_id then return 0 end
	return t[source_id] or 0
end

local function player_attack_serial(player)
	if not player then return 0 end
	-- Legacy single counter (pre per-source); prefer source map for player id.
	local t = player_source_counters(player)
	local sid = "player:" .. tostring(GetPtrHash(player))
	if t and t[sid] ~= nil then return t[sid] end
	return player:GetData()[SERIAL_KEY] or 0
end

local function next_attack_is_gospel(player)
	if not player then return false end
	local every = item.tear_every or 4
	return ((player_attack_serial(player) + 1) % every) == 0
end

local function player_source_id(player)
	if not player then return "player:nil" end
	return "player:" .. tostring(GetPtrHash(player))
end

--- Clear one source counter only (player / craft:<uid>). Never wipe the whole map.
local function clear_source_attack_serial(player, source_id)
	if not player or not source_id then return end
	local pd = player:GetData()
	local t = pd[SERIAL_BY_SOURCE_KEY]
	if type(t) == "table" then
		t[source_id] = nil
	end
	if source_id == player_source_id(player) then
		pd[SERIAL_KEY] = nil
		pd[item.own_key.."shots"] = nil
	end
end

--- Full wipe (new run). Do not use when player merely lacks inventory Gospel.
local function clear_player_attack_serial(player)
	if not player then return end
	player:GetData()[SERIAL_KEY] = nil
	player:GetData()[SERIAL_BY_SOURCE_KEY] = nil
	player:GetData()[item.own_key.."shots"] = nil
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_ATTACK_ONCE, params = nil,
Function = function(_, event)
	local player = event and event.player
	local attack = event and event.attack
	if not player or not attack then return end
	local classifier = attack_holder.classifier
	local source = event.attack_source or attack.source
	local player_source = classifier.IsPlayerAttackSource(source)
	local craft_source = (not player_source)
		and classifier.SourceCanConsume(source, item.consumer_key, player, attack)
	if player_source then
		if not auxi.has_have_coll(player, item.entity) then
			clear_source_attack_serial(player, player_source_id(player))
			return
		end
	elseif not craft_source then
		return
	end
	local every = item.tear_every or 4
	local source_id = attack_source_id(event, player)
	local counters = player_source_counters(player)
	local serial = (counters[source_id] or 0) + 1
	counters[source_id] = serial
	if player_source then
		player:GetData()[SERIAL_KEY] = serial
	end
	if (serial % every) ~= 0 then return end
	attack.tags = attack.tags or {}
	attack.tags.gospel = {
		owner = player,
		source_id = source_id,
		birth_frame = Isaac.GetFrameCount(),
	}
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_ATTACK_DAMAGE, params = nil,
Function = function(_, event)
	if not event or not event.attack or not event.target then return end
	local gtag = event.attack.tags and event.attack.tags.gospel
	if not gtag then return end
	if not auxi.isenemies(event.target) then return end
	local amount = event.damage or 0
	if amount <= 0 then return end
	if event.flags and (event.flags & skip_hurt_flags) ~= 0 then return end
	-- Laser gospel apply is MC_POST_LASER_COLLISION only (not Source/ExtraSource inference).
	-- Melee CLUB_HITBOX: RGON puts the knife on ExtraSource — apply via TAKE_DMG / POST_ATTACK_DAMAGE.
	local member = event.member
	if member and member.Type == EntityType.ENTITY_LASER then return end
	local player = gtag.owner or event.player
	apply_gospel(event.target, player)
	-- Preach accumulation stays on MC_ENTITY_TAKE_DMG to avoid double-count.
end,
})

-- Thin overlay on members of a gospel-tagged Attack (smooth fade in/out).
local function draw_member_carrier(ent, offset, dark_owner)
	local gtag = gospel_tag_from_member(ent)
	local want = gtag ~= nil
	if not carrier_should_draw(ent, want) then return end
	local owner = (gtag and gtag.owner) or dark_owner
	local dark = item.is_seija(owner)
	render_carrier_overlay(ent, offset, dark, want, gtag)
end

local function epic_rocket_want_ground(ent)
	if not ent then return false end
	local to = ent.Timeout or 0
	local po_y = ent.PositionOffset and ent.PositionOffset.Y or 0
	-- Keep ground mark while falling; fade only when nearly landed.
	return to > 0 or po_y < -40
end

local function draw_epic_rocket_carriers(ent, offset)
	local gtag = gospel_tag_from_member(ent)
	local owner = gtag and gtag.owner
		or auxi.check_spawner_player(ent)
		or auxi.check_near_spawner_player(ent)
	local dark = item.is_seija(owner)
	local want_air = gtag ~= nil
	if carrier_should_draw(ent, want_air) then
		render_carrier_overlay(ent, offset, dark, want_air, gtag)
	end
	-- Ground mark follows the missile XY (survives TARGET despawn before impact).
	local want_ground = want_air and epic_rocket_want_ground(ent)
	local d = ent:GetData()
	if want_ground or (d[GROUND_VIS_KEY] or 0) >= 0.02 then
		render_epic_ground_for_rocket(ent, offset, dark, want_ground)
	end
end

if ModCallbacks.MC_POST_TEAR_RENDER then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_TEAR_RENDER, params = nil,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	draw_member_carrier(ent, offset, auxi.check_spawner_player(ent))
end,
})
end

if ModCallbacks.MC_POST_LASER_RENDER then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_LASER_RENDER, params = nil,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	sync_laser_fx_helper(ent, offset, auxi.check_spawner_player(ent))
end,
})
end

if ModCallbacks.MC_POST_EFFECT_RENDER then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = enums.Entities.ID_EFFECT_MeusNIL,
Function = function(_, effect, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	if not effect then return end
	local d = effect:GetData()
	if d[LASER_FX_KEY] then
		tick_and_render_laser_fx_helper(effect)
	elseif d[SWORD_FX_KEY] then
		tick_and_render_sword_fx_helper(effect)
	end
end,
})
end

if ModCallbacks.MC_POST_KNIFE_RENDER then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_KNIFE_RENDER, params = nil,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	-- Spirit Sword / Tech Sword: only CLUB_HITBOX MeusNIL on Hit capsules — never main blade at player.
	if spirit_sword_variant(ent.Variant) and not is_club_hitbox(ent) then
		return
	end
	if is_club_hitbox(ent) then
		local gtag = select(1, gospel_tag_from_knife(ent))
		local owner = (gtag and gtag.owner)
			or auxi.check_spawner_player(ent)
			or auxi.check_near_spawner_player(ent, {checklist = {"Parent"}})
		sync_sword_fx_helper(ent, offset, owner)
		return
	end
	local gtag = select(1, gospel_tag_from_knife(ent))
	local want = gtag ~= nil
	if not carrier_should_draw(ent, want) then return end
	local owner = (gtag and gtag.owner)
		or auxi.check_spawner_player(ent)
		or auxi.check_near_spawner_player(ent, {checklist = {"Parent"}})
	render_carrier_overlay(ent, offset, item.is_seija(owner), want, gtag)
end,
})
end

-- Spirit Sword / bone club: engine already filled GetHitList from Hit1/Hit2 capsules.
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE, params = nil,
Function = function(_, knife)
	if not is_club_hitbox(knife) then return end
	apply_gospel_from_knife_hitlist(knife)
end,
})

if ModCallbacks.MC_POST_BOMB_RENDER then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_BOMB_RENDER, params = nil,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	draw_member_carrier(ent, offset, auxi.check_spawner_player(ent) or auxi.check_near_spawner_player(ent))
end,
})
end

if ModCallbacks.MC_POST_EFFECT_RENDER then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = EffectVariant.ROCKET,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	draw_epic_rocket_carriers(ent, offset)
end,
})
if EffectVariant.SMALL_ROCKET then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = EffectVariant.SMALL_ROCKET,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	draw_epic_rocket_carriers(ent, offset)
end,
})
end
if enums.Entities.ID_EFFECT_MeusRocket then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = enums.Entities.ID_EFFECT_MeusRocket,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	draw_epic_rocket_carriers(ent, offset)
end,
})
end
-- Epic crosshair mark: keep showing while aiming OR while a gospel rocket is locked to this TARGET.
-- Do not drop the mark when a child rocket appears but TARGET bind has not landed yet.
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = EffectVariant.TARGET,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local gtag = gospel_tag_from_member(ent)
	local want = gtag ~= nil
	local th = GetPtrHash(ent)
	if not want then
		local rockets = Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.ROCKET, -1, false, false)
		for i = 1, #rockets do
			local rocket = rockets[i]
			if rocket and rocket.Parent and GetPtrHash(rocket.Parent) == th then
				local rtag = gospel_tag_from_member(rocket)
				if rtag then
					want = true
					gtag = rtag
					break
				end
			end
		end
	end
	if not want then
		local player = auxi.check_spawner_player(ent) or auxi.check_near_spawner_player(ent)
		if player and auxi.has_have_coll(player, item.entity)
			and player.HasWeaponType and player:HasWeaponType(WeaponType.WEAPON_ROCKETS)
			and next_attack_is_gospel(player) then
			local has_child = false
			local rockets = Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.ROCKET, -1, false, false)
			for i = 1, #rockets do
				local rocket = rockets[i]
				if rocket and rocket.Parent and GetPtrHash(rocket.Parent) == th then
					has_child = true
					break
				end
			end
			-- Preview only while still aiming (no child yet).
			if not has_child then
				want = true
				gtag = { owner = player }
			end
		end
	end
	if not carrier_should_draw(ent, want) then return end
	local dark = item.is_seija((gtag and gtag.owner) or auxi.check_spawner_player(ent) or auxi.check_near_spawner_player(ent))
	render_carrier_overlay(ent, offset, dark, want, gtag)
end,
})
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_, tear, col, low)
	local gtag = gospel_tag_from_member(tear)
	if not gtag then return end
	if not auxi.isenemies(col) then return end
	local player = gtag.owner or auxi.check_spawner_player(tear)
	apply_gospel(col, player)
end,
})

if ModCallbacks.MC_PRE_KNIFE_COLLISION then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_KNIFE_COLLISION, params = nil,
Function = function(_, knife, col, low)
	local gtag = select(1, gospel_tag_from_knife(knife))
	if not gtag then return end
	if not auxi.isenemies(col) then return end
	local player = gtag.owner or auxi.check_spawner_player(knife) or auxi.check_near_spawner_player(knife, {checklist = {"Parent"}})
	apply_gospel(col, player)
end,
})
end

-- RGON: hard knife hit (Spirit Sword CLUB_HITBOX etc.), same role as POST_LASER_COLLISION.
if ModCallbacks.MC_POST_KNIFE_COLLISION then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_KNIFE_COLLISION, params = nil,
Function = function(_, knife, col, low)
	local gtag = select(1, gospel_tag_from_knife(knife))
	if not gtag then return end
	if not auxi.isenemies(col) then return end
	local player = gtag.owner or auxi.check_spawner_player(knife) or auxi.check_near_spawner_player(knife, {checklist = {"Parent"}})
	apply_gospel(col, player)
end,
})
end

-- Hard laser hit (RGON): Laser + Collider — same role as tear/knife collision.
if ModCallbacks.MC_POST_LASER_COLLISION then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_LASER_COLLISION, params = nil,
Function = function(_, laser, col)
	local gtag = select(1, gospel_tag_from_laser(laser))
	if not gtag then return end
	if not auxi.isenemies(col) then return end
	local player = gtag.owner or auxi.check_spawner_player(laser) or auxi.check_near_spawner_player(laser)
	apply_gospel(col, player)
end,
})
end

-- Epic impact (same timing as Item_Moment): ROCKET remove still has Spawner + Position.
-- Prefer RGON MC_POST_BOMB_DAMAGE (real Radius + Source); keep Timeout/REMOVE as fallback.
local EPIC_GOSPEL_RADIUS = 100
local function is_gospel_epic_rocket(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_EFFECT then return false end
	local v = ent.Variant
	if v == EffectVariant.ROCKET then return true end
	if EffectVariant.SMALL_ROCKET and v == EffectVariant.SMALL_ROCKET then return true end
	if enums.Entities.ID_EFFECT_MeusRocket and v == enums.Entities.ID_EFFECT_MeusRocket then return true end
	return false
end

local function apply_gospel_at_blast(position, radius, attack, fallback_player)
	local gtag = attack and attack.tags and attack.tags.gospel
	if not gtag or not position then return end
	local player = gtag.owner or attack.player or fallback_player
	if not player then return end
	local r = radius or EPIC_GOSPEL_RADIUS
	if r < 1 then r = EPIC_GOSPEL_RADIUS end
	local list = Isaac.FindInRadius(position, r, EntityPartition.ENEMY)
	for i = 1, #list do
		local npc = list[i]
		if auxi.isenemies(npc) then
			apply_gospel(npc, player)
		end
	end
end

local function apply_gospel_epic_blast(ent)
	if not is_gospel_epic_rocket(ent) then return end
	local attack = select(1, attack_holder.GetAttackForMember(ent))
		or select(1, attack_registry.lookup_recent_for_damage(ent))
	apply_gospel_at_blast(ent.Position, EPIC_GOSPEL_RADIUS, attack, auxi.check_spawner_player(ent))
end

if ModCallbacks.MC_POST_BOMB_DAMAGE then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_BOMB_DAMAGE, params = nil,
Function = function(_, position, damage, radius, lineCheck, source, tearFlags, damageFlags, damageSource)
	local attack = nil
	if source then
		attack = select(1, attack_holder.GetAttackForMember(source))
			or select(1, attack_registry.lookup_recent_for_damage(source))
	end
	if not attack then
		local player = source and ((source.ToPlayer and source:ToPlayer()) or auxi.check_spawner_player(source))
		if player then
			attack = select(1, attack_registry.lookup_recent_player_blast(player, position))
		end
	end
	if not attack or not attack.tags or not attack.tags.gospel then return end
	local fallback = attack.player
		or (source and ((source.ToPlayer and source:ToPlayer()) or auxi.check_spawner_player(source)))
	apply_gospel_at_blast(position, radius, attack, fallback)
end,
})
end

-- Do not apply enemy marks at Timeout==1 (missile still visibly falling). Moment/BombDamage/REMOVE only.
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = EntityType.ENTITY_EFFECT,
Function = function(_, ent)
	if not g.is_gameplay_world_active() then return end
	if is_gospel_epic_rocket(ent) then
		local d = ent:GetData()
		local gscr = d[item.own_key.."ground_screen"]
		local gvis = d[GROUND_VIS_KEY] or 0
		if gscr and gvis >= 0.02 then
			push_epic_ground_linger(Vector(gscr.X, gscr.Y), d[CARRIER_DARK_KEY], gvis)
		end
	end
	apply_gospel_epic_blast(ent)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_, ent, amount, flags, source, countdown, extra_source)
	if not auxi.isenemies(ent) then return end
	if (amount or 0) <= 0 then return end
	if (flags & skip_hurt_flags) ~= 0 then return end
	if source_is_revelation(source) then return end
	-- Non-attack sources (e.g. abyss locust) still apply via entity check.
	-- Laser: MC_POST_LASER_COLLISION only (skip ExtraSource laser here).
	-- Melee hitboxes: Source is often the player; real knife is ExtraSource (RGON docs) —
	-- source_applies_gospel prefers ExtraSource and gospel_tag_from_knife.
	local applies, gplayer = source_applies_gospel(source, extra_source, ent)
	local player = gplayer or source_player(source, extra_source)
	if applies then
		local hit = ref_entity(extra_source) or ref_entity(source)
		if not (hit and hit.Type == EntityType.ENTITY_LASER) then
			apply_gospel(ent, player)
		end
	end
	local data = gospel_data(ent)
	if not data then return end
	player = player or data.owner
	if not player then return end
	on_gospel_damage(ent, amount, player)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = nil,
Function = function(_, npc)
	on_gospel_killed(npc)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_, ent)
	local npc = ent and ent.ToNPC and ent:ToNPC()
	if npc then on_gospel_killed(npc) end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_UPDATE, params = nil,
Function = function(_, npc)
	local data = gospel_data(npc)
	if not data then return end

	local pose = entity_head_anchor.GetEntityHeadPose(npc, {
		lockData = data,
		skipOverlay = true,
	})
	local pose_visible = pose and pose.visible ~= false
	data.render_hidden = not pose_visible
	data.render_hidden_reason = pose_visible and "visible" or (pose and pose.hidden_reason or "no_pose")

	local final = room_state().final
	-- data.vis only for Gospel birth/permanent fade/final — not render_hidden.
	local target_vis = 1
	if data.fading then
		target_vis = 0
	elseif final and final.phase == "silence" then
		target_vis = 1
		data.vis = math.min(1, (data.vis or 0) + 0.08)
	end
	local vis = tick_halo_vis(data, target_vis)
	if data.fading and vis <= 0 then
		clear_gospel(npc)
		return
	end

	-- Hidden segments / empty scalp: no head geometry / halo follow this frame.
	if data.render_hidden then
		return
	end
	follow_halo(npc, data)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	local frame = Game():GetFrameCount()
	if halo_update_frame ~= frame and Game():IsPaused() == false then
		halo_spr:Update()
		symbol_spr:Update()
		carrier_arc_spr:Update()
		halo_update_frame = frame
	end
	tick_final_revelation()
	for i = #gospel_links, 1, -1 do
		local link = gospel_links[i]
		link.age = (link.age or 0) + 1
		if link.age >= link.life then
			table.remove(gospel_links, i)
		end
	end
	for i = #receive_flashes, 1, -1 do
		local flash = receive_flashes[i]
		flash.age = (flash.age or 0) + 1
		if flash.age >= flash.life then
			table.remove(receive_flashes, i)
		end
	end
	for i = #lingering_halos, 1, -1 do
		local linger = lingering_halos[i]
		if (linger.hold or 0) > 0 then
			linger.hold = linger.hold - 1
		elseif tick_halo_vis(linger, 0) <= 0 then
			table.remove(lingering_halos, i)
		end
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function()
	-- Room-local gospel state only. Attack serial persists across rooms.
	item.room = {revelations = 0, judgement = false, accept_serial = 0, final = nil}
	entity_head_anchor.ClearCaches()
	halo_pos_cache = {}
	lingering_halos = {}
	gospel_links = {}
	receive_flashes = {}
	epic_ground_lingers = {}
	clear_laser_fx_helpers()
	clear_sword_fx_helpers()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function()
	item.room = {revelations = 0, judgement = false, accept_serial = 0, final = nil}
	lingering_halos = {}
	gospel_links = {}
	receive_flashes = {}
	epic_ground_lingers = {}
	clear_laser_fx_helpers()
	clear_sword_fx_helpers()
	for i = 0, Game():GetNumPlayers() - 1 do
		clear_player_attack_serial(Game():GetPlayer(i))
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local data = gospel_data(ent)
	if not data then return end
	-- Final render-time pose gate. Pin can flip Visible after POST_NPC_UPDATE;
	-- empty scalp also hides (same owner as UPDATE).
	local pose = entity_head_anchor.GetEntityHeadPose(ent, {
		lockData = data,
		skipOverlay = true,
	})
	if not pose or pose.visible == false then
		data.render_hidden = true
		data.render_hidden_reason = (pose and pose.hidden_reason) or "no_pose"
		return
	end
	data.render_hidden = false
	data.render_hidden_reason = "visible"
	local vis = data.vis or 0
	if vis <= 0 then return end
	offset = offset or Vector(0, 0)
	if not data.halo_off then
		data.halo_off = head_halo_local(ent, data)
	end
	local dark = item.is_seija(data.owner)
	local col = dark and gold_color(0.95, true) or Color(1, 1, 1, 1)
	if not halo_spr:IsPlaying("Idle") then
		halo_spr:Play("Idle", true)
	end
	local final = room_state().final
	local scale_mul = 1
	if final and (final.phase == "silence" or final.phase == "network" or final.phase == "rise") then
		scale_mul = 1.12
	end
	local halo_pos = halo_screen_pos(ent, offset, data)
	data.last_halo_screen = Vector(halo_pos.X, halo_pos.Y)
	local scale = halo_scale_for(ent) * scale_mul
	local seed = ent.InitSeed or GetPtrHash(ent)
	render_halo_at(halo_pos, scale, fade_color(col, vis))
	render_orbiters(halo_pos, scale, col, vis, gold_color(0.85 * vis, dark), seed, dark)
	-- Sacred arcs on top of the existing halo + orbit tear particles.
	render_carrier_sacred_ring(
		halo_pos,
		enemy_gospel_arc_scale(scale),
		dark,
		vis,
		seed,
		1,
		false
	)
	-- Rise phase: thin vertical cue.
	if final and final.phase == "rise" and Isaac.DrawLine then
		local up = halo_pos + Vector(0, -48)
		local c = dark and KColor(0.4, 0.15, 0.7, 0.55) or KColor(1, 0.9, 0.4, 0.55)
		Isaac.DrawLine(halo_pos, up, c, c, 1)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function()
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	render_gospel_links()
	render_receive_flashes()
	for i = 1, #lingering_halos do
		local linger = lingering_halos[i]
		local vis = linger.vis or 0
		if vis > 0 then
			-- Frozen screen snapshot from last NPC_RENDER (includes callback offset).
			local pos = linger.screen
			if not pos then
				-- Legacy fallback only; may drift in large rooms.
				pos = Isaac.WorldToRenderPosition(linger.pos + linger.po) + linger.off
			end
			local col = linger.dark and gold_color(0.95, true) or Color(1, 1, 1, 1)
			local seed = linger.seed or 0
			render_halo_at(pos, linger.scale, fade_color(col, vis))
			render_orbiters(pos, linger.scale, col, vis, gold_color(0.85 * vis, linger.dark), seed, linger.dark)
			render_carrier_sacred_ring(
				pos,
				enemy_gospel_arc_scale(linger.scale),
				linger.dark,
				vis,
				seed,
				1,
				false
			)
		end
	end
	for i = #epic_ground_lingers, 1, -1 do
		local linger = epic_ground_lingers[i]
		linger.vis = tick_smooth_vis(linger, "vis", false)
		if (linger.vis or 0) < 0.02 then
			table.remove(epic_ground_lingers, i)
		elseif linger.screen then
			render_carrier_at(linger.screen, linger.dark, linger.vis, item.carrier_ring_scale * 1.05, 0, 1)
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_, ent)
	if ent.SubType ~= item.entity then return end
	local d = ent:GetData()
	if (d[item.own_key.."counter"] or 0) > 0 then
		d[item.own_key.."counter"] = d[item.own_key.."counter"] - 1
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_, ent, col, low)
	if ent.SubType ~= item.entity then return end
	if not auxi.isenemies(col) then return end
	if ent.State ~= -1 then return end
	local d = ent:GetData()
	if (d[item.own_key.."counter"] or 0) > 0 then return end
	d[item.own_key.."counter"] = 18
	local player = auxi.check_spawner_player(ent)
	apply_gospel(col, player)
end,
})

return item

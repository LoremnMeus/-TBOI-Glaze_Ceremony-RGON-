-- 悲欢之凶剧：交替面具泪命中标记；死亡后悲剧残响 / 喜剧演员 / 凶剧双演出
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local KIND_TRAGEDY = 0
local KIND_COMEDY = 1
local TEAR_ANM2 = "gfx/mimics/Drama_of_sorrow_and_joy/Despia_Tear.anm2"
local FUSION_ANM2 = "gfx/characters/Despia_Head_3.anm2"

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Drama_of_sorrow_and_joy,
	own_key = "Item_DSOAJ_",
	costumes = {
		[1] = enums.Costumes.Despia_1,
		[2] = enums.Costumes.Despia_2,
		[3] = enums.Costumes.Despia_3,
	},
	chance = 15,
	echo_wait = 8,
	actor_wait = 15,
	actor_life = 120,
	fusion_actor_life = 180,
	echo_range = 280,
	echo_speed = 24,
	fragment_speed = 16,
	fusion_spin = 18,
}

local overlay_fusion = Sprite()
overlay_fusion:Load(FUSION_ANM2, true)
overlay_fusion:Play("HeadDown", true)

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

function item.force_mask()
	local debug = debug_root()
	return debug and debug.DramaForceMask == true
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

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function size_radius(ent)
	local multi = ent.SizeMulti or Vector(1, 1)
	return ent.Size * lerp(multi.X or 1, multi.Y or 1, 0.5)
end

local function overlay_offset(ent)
	if ent.GetNullOffset then
		local ov = ent:GetNullOffset("OverlayEffect")
		if ov and ov:Length() > 0.5 then
			return Vector(ov.X, ov.Y * 0.72)
		end
	end
	local sprite = ent:GetSprite()
	if sprite and sprite.GetNullFrame then
		local nf = sprite:GetNullFrame("OverlayEffect")
		if nf and nf.IsVisible and nf:IsVisible() and nf.GetPos then
			local pos = nf:GetPos()
			if pos and pos:Length() > 0.5 then
				return Vector(pos.X, pos.Y * 0.72)
			end
		end
	end
	return Vector(0, -(size_radius(ent) + 6))
end

local function mask_scale(ent)
	local size = size_radius(ent)
	return math.min(0.85 + (size - 13) / 55, 1.7)
end

local function overlay_render_pos(ent, offset)
	local world = ent.Position + (ent.PositionOffset or Vector.Zero)
	return Isaac.WorldToRenderPosition(world) + (offset or Vector.Zero) + overlay_offset(ent)
end

local function mark_of(ent)
	if not ent then return nil end
	return ent:GetData()[item.own_key.."mark"]
end

local function ensure_mark_sprite(mark, anim)
	if not mark.spr then
		mark.spr = Sprite()
		mark.spr:Load(TEAR_ANM2, true)
	end
	if mark.anim ~= anim then
		mark.spr:Play(anim, true)
		mark.anim = anim
	end
	return mark.spr
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
	d.Ignore_me_flag = true
	d[item.own_key.."mask"] = true
	d[item.own_key.."kind"] = kind
	d[item.own_key.."no_mark"] = params.no_mark == true
	return ent
end

function item.try_convert_mask_tear(player, ent, params)
	params = params or {}
	if not player or not ent or not ent:ToTear() then return nil end
	ent = ent:ToTear()
	local d = ent:GetData()
	if d[item.own_key.."mask"] or d.Ignore_me_flag then return nil end
	if is_ludo_tear(ent) then return nil end
	local rng = collectible_rng(player)
	if not params.Force and not item.force_mask() then
		if not rng or rng:RandomInt(100) >= item.chance then return nil end
	end
	local kind = params.Kind
	if kind == nil then
		kind = get_next_kind(player)
		set_next_kind(player, 1 - kind)
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_PLOP, 0.7, 0.85 + math.random() * 0.3, false, 0, 2)
	return dress_mask_tear(ent, kind, params)
end

local function fire_stage_tear(player, pos, vel, kind, dmg_mul, no_mark)
	local q = Isaac.Spawn(EntityType.ENTITY_TEAR, 0, 0, pos, vel, player):ToTear()
	if not q then return nil end
	dress_mask_tear(q, kind, {no_mark = no_mark ~= false})
	q.CollisionDamage = (player and player.Damage or 3.5) * (dmg_mul or 1)
	q.TearFlags = (q.TearFlags or TearFlags.TEAR_NORMAL) | TearFlags.TEAR_SPECTRAL
	q.FallingAcceleration = 0.04
	q.FallingSpeed = -0.2
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	q.Scale = math.max(0.7, q.Scale or 1)
	return q
end

local function nearest_enemy(pos, except)
	local except_hash = except and GetPtrHash(except) or nil
	return auxi.get_by_nearest_enemy(pos, function(ent)
		if except_hash and GetPtrHash(ent) == except_hash then return false end
		return true
	end)
end

local function nearest_enemies(pos, except, count)
	local except_hash = except and GetPtrHash(except) or nil
	local list = auxi.getenemies(Isaac.GetRoomEntities(), function(ent)
		if except_hash and GetPtrHash(ent) == except_hash then return false end
		return true
	end)
	table.sort(list, function(a, b)
		return a.Position:DistanceSquared(pos) < b.Position:DistanceSquared(pos)
	end)
	local ret = {}
	for i = 1, math.min(count or 1, #list) do
		ret[i] = list[i]
	end
	return ret
end

local function hp_bonus(player, max_hp, is_boss, fusion)
	local atk = (player and player.Damage) or 3.5
	local add = max_hp * (fusion and 0.08 or 0.05)
	if is_boss then add = math.min(add, atk * 3) end
	return add
end

local function safe_explode(pos, dmg, player, radius)
	Game():BombExplosionEffects(
		pos,
		dmg,
		TearFlags.TEAR_NORMAL,
		Color(0.35, 0.05, 0.55, 1),
		player,
		radius or 0.55,
		true,
		false
	)
end

local function spawn_stage(kind, pos, player, extra)
	local q = Isaac.Spawn(EntityType.ENTITY_EFFECT, enums.Entities.ID_EFFECT_MeusNIL, 0, pos, Vector.Zero, player):ToEffect()
	if not q then return nil end
	q.Visible = true
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	q.DepthOffset = 12
	local d = q:GetData()
	d[item.own_key.."stage"] = extra or {}
	local st = d[item.own_key.."stage"]
	st.kind = kind
	st.player = player
	local s = q:GetSprite()
	s:Load(TEAR_ANM2, true)
	if kind == "echo" then
		s:Play("Idle2", true)
	else
		s:Play("Idle1", true)
	end
	if st.fusion then
		s.Color = Color(1, 0.55, 1, 1, 0.15, 0, 0.2)
		s.Scale = Vector(1.15, 1.15)
	end
	return q
end

local function spawn_fragments(player, pos, except, fusion)
	if not fusion then return end
	local rng = collectible_rng(player)
	local n = 1
	if rng then n = 1 + rng:RandomInt(2) end
	local targs = nearest_enemies(pos, except, n)
	for i = 1, #targs do
		local dir = (targs[i].Position - pos)
		if dir:Length() < 0.1 then dir = Vector(1, 0) end
		fire_stage_tear(player, pos, dir:Normalized() * ((player and player.ShotSpeed or 1) * item.fragment_speed), KIND_TRAGEDY, 1, true)
	end
end

local function spawn_echo(player, pos, dead, fusion)
	local atk = (player and player.Damage) or 3.5
	local dmg = atk * (fusion and 3.0 or 2.0) + hp_bonus(player, dead and dead.MaxHitPoints or 0, dead and dead:IsBoss() or false, fusion)
	local q = spawn_stage("echo", pos, player, {
		wait = item.echo_wait,
		fusion = fusion == true,
		damage = dmg,
		radius = fusion and 0.9 or 0.55,
		except = dead,
	})
	return q
end

local function spawn_actor(player, pos, fusion)
	local rng = collectible_rng(player)
	local fire_min = fusion and 15 or 18
	local fire_span = fusion and 4 or 5
	local interval = fire_min
	if rng then interval = fire_min + rng:RandomInt(fire_span) end
	return spawn_stage("actor", pos, player, {
		wait = item.actor_wait,
		fusion = fusion == true,
		life = fusion and item.fusion_actor_life or item.actor_life,
		fire_cd = interval,
		fire_interval = interval,
		dmg_mul = fusion and 1.25 or 1.0,
		shot_kind = fusion and KIND_TRAGEDY or KIND_COMEDY,
	})
end

local function on_marked_death(ent)
	local mark = mark_of(ent)
	if not mark or mark.spent then return end
	mark.spent = true
	local player = mark.player
	if not auxi.check_all_exists(player) then player = Game():GetPlayer(0) end
	local pos = Vector(ent.Position.X, ent.Position.Y)
	local fusion = mark.fusion == true
	if fusion or mark.tragedy then
		spawn_echo(player, pos, ent, fusion)
	end
	if fusion or mark.comedy then
		spawn_actor(player, pos, fusion)
	end
end

local function apply_mask(col, kind, player)
	if not auxi.isenemies(col) then return end
	local d = col:GetData()
	local mark = d[item.own_key.."mark"]
	if not mark then
		mark = {
			tragedy = false,
			comedy = false,
			fusion = false,
			fusion_t = 0,
			player = player,
		}
		d[item.own_key.."mark"] = mark
	end
	if auxi.check_all_exists(player) then mark.player = player end
	if mark.fusion then return end
	local is_comedy = kind == KIND_COMEDY
	if is_comedy then
		if mark.comedy then return end
		mark.comedy = true
	else
		if mark.tragedy then return end
		mark.tragedy = true
	end
	if mark.tragedy and mark.comedy then
		mark.fusion = true
		mark.fusion_t = item.fusion_spin
		col:SetColor(Color(1, 0.45, 1, 1, 0.2, 0, 0.25), 24, 1, false, false)
		Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, col.Position, Vector.Zero, col)
	elseif is_comedy then
		col:SetColor(Color(1, 0.85, 0.35, 1, 0.2, 0.1, 0), 12, 1, false, false)
	else
		col:SetColor(Color(0.55, 0.35, 0.9, 1, 0.05, 0, 0.2), 12, 1, false, false)
	end
end

local function clear_player_costumes(player)
	if not player then return end
	for i = 1, 3 do
		player:TryRemoveNullCostume(item.costumes[i])
	end
end

local function remove_stage_effects()
	local list = Isaac.FindByType(EntityType.ENTITY_EFFECT, enums.Entities.ID_EFFECT_MeusNIL)
	for i = 1, #list do
		local ent = list[i]
		if ent:GetData()[item.own_key.."stage"] then
			ent:Remove()
		end
	end
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."next"] = {}
	end
	save.elses[item.own_key.."next"] = save.elses[item.own_key.."next"] or {}
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = item.entity,
Function = function(_, player, collid, count, lastnumber)
	if count < 0 and not auxi.has_have_coll(player, item.entity) then
		clear_player_costumes(player)
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_FIRE_TRIGGER_IN_FRAME, params = nil,
Function = function(_, tp, ent, pos, player, dir)
	if not player or not auxi.has_have_coll(player, item.entity) then return end
	if tp ~= "Tear" or not ent or not ent:ToTear() then return end
	item.try_convert_mask_tear(player, ent)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_, ent, col, low)
	local d = ent:GetData()
	if not d[item.own_key.."mask"] then return end
	if d[item.own_key.."no_mark"] then return end
	if not auxi.isenemies(col) then return end
	local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
	apply_mask(col, d[item.own_key.."kind"] or KIND_TRAGEDY, player)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = nil,
Function = function(_, ent)
	if mark_of(ent) then on_marked_death(ent) end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_, ent)
	if ent and ent:ToNPC() and mark_of(ent) then on_marked_death(ent) end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_UPDATE, params = nil,
Function = function(_, ent)
	local mark = mark_of(ent)
	if not mark then return end
	if not auxi.check_all_exists(ent) then return end
	if mark.fusion_t and mark.fusion_t > 0 then
		mark.fusion_t = mark.fusion_t - 1
	end
	local anim = "Idle2"
	if mark.comedy and not mark.tragedy then anim = "Idle1" end
	local spr = ensure_mark_sprite(mark, anim)
	spr:Update()
	if mark.fusion and mark.fusion_t > 0 then
		if not mark.spr_b then
			mark.spr_b = Sprite()
			mark.spr_b:Load(TEAR_ANM2, true)
			mark.spr_b:Play("Idle1", true)
		end
		mark.spr_b:Update()
		mark.spr:Play("Idle2", false)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_, ent, offset)
	if not ent.Visible then return end
	local mark = mark_of(ent)
	if not mark or mark.spent then return end
	local pos = overlay_render_pos(ent, offset)
	local scale = mask_scale(ent)
	local flip = ent:GetSprite().FlipX
	local alpha = ent:GetSprite().Color.A
	if mark.fusion and mark.fusion_t > 0 and mark.spr and mark.spr_b then
		local spin = (item.fusion_spin - mark.fusion_t) * 22
		mark.spr.Scale = Vector(scale, scale)
		mark.spr_b.Scale = Vector(scale, scale)
		mark.spr.FlipX = flip
		mark.spr_b.FlipX = flip
		mark.spr.Rotation = -spin
		mark.spr_b.Rotation = spin
		mark.spr.Color = Color(0.7, 0.45, 1, alpha)
		mark.spr_b.Color = Color(1, 0.85, 0.3, alpha)
		mark.spr:Render(pos + Vector(-6, 0), Vector.Zero, Vector.Zero)
		mark.spr_b:Render(pos + Vector(6, 0), Vector.Zero, Vector.Zero)
		return
	end
	if mark.fusion then
		overlay_fusion.Scale = Vector(scale * 0.55, scale * 0.55)
		overlay_fusion.FlipX = flip
		overlay_fusion.Color = Color(1, 0.7, 1, alpha, 0.12, 0, 0.18)
		overlay_fusion:Render(pos, Vector.Zero, Vector.Zero)
		return
	end
	local spr = mark.spr
	if not spr then return end
	spr.Scale = Vector(scale, scale)
	spr.FlipX = flip
	spr.Rotation = 0
	spr.Color = Color(1, 1, 1, alpha)
	spr:Render(pos, Vector.Zero, Vector.Zero)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.ID_EFFECT_MeusNIL,
Function = function(_, ent)
	local st = ent:GetData()[item.own_key.."stage"]
	if not st then return end
	local player = st.player
	if not auxi.check_all_exists(player) then player = Game():GetPlayer(0) st.player = player end
	st.wait = (st.wait or 0) - 1
	ent.Velocity = ent.Velocity * 0.85
	if st.kind == "echo" then
		if st.wait > 0 then return end
		local target = st.target
		if not auxi.check_all_exists(target) then
			target = nearest_enemy(ent.Position, st.except)
			st.target = target
		end
		local function detonate()
			safe_explode(ent.Position, st.damage or 3.5, player, st.radius)
			if st.fusion then spawn_fragments(player, ent.Position, st.except, true) end
			ent:Remove()
		end
		if not auxi.check_all_exists(target) then
			detonate()
			return
		end
		local delta = target.Position - ent.Position
		local hit = target.Size + 12
		if delta:Length() <= hit then
			detonate()
			return
		end
		ent.Velocity = delta:Normalized() * item.echo_speed
		return
	end
	if st.kind == "actor" then
		if st.wait > 0 then return end
		st.life = (st.life or item.actor_life) - 1
		if st.life <= 0 then
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, ent.Position, Vector.Zero, player)
			ent:Remove()
			return
		end
		local target = nearest_enemy(ent.Position, nil)
		if auxi.check_all_exists(target) then
			local dest = target.Position
			local delta = dest - ent.Position
			local hold = 70
			if delta:Length() > hold then
				ent.Velocity = ent.Velocity * 0.7 + delta:Normalized() * 4.5
			else
				ent.Velocity = ent.Velocity * 0.8
			end
			st.fire_cd = (st.fire_cd or st.fire_interval or 20) - 1
			if st.fire_cd <= 0 then
				st.fire_cd = st.fire_interval or 20
				local dir = delta
				if dir:Length() < 0.1 then dir = Vector(1, 0) end
				dir = dir:Normalized()
				local spd = (player and player.ShotSpeed or 1) * 14
				local kind = st.shot_kind or KIND_COMEDY
				fire_stage_tear(player, ent.Position, dir * spd, kind, st.dmg_mul or 1, true)
				if st.fusion then
					local rng = collectible_rng(player)
					if rng and rng:RandomInt(100) < 32 then
						fire_stage_tear(player, ent.Position, auxi.get_by_rotate(dir, 11) * spd, kind, st.dmg_mul or 1, true)
					end
				end
			end
		else
			ent.Velocity = ent.Velocity * 0.75
		end
		local s = ent:GetSprite()
		s.Rotation = s.Rotation + (st.fusion and 8 or 4)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	remove_stage_effects()
end,
})

return item

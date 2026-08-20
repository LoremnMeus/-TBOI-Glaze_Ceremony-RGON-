local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	entity = enums.Items.Suture_Needle,
	own_key = "Item_Suture_Needle_",
	wave_radius = 180,
	wave_speed = 18,
	mark_frames = 180,
	corpse_frames = 60,
	seija_corpse_frames = 120,
	hit_flat = 8,
	hit_coef = 2,
	seija_hit_mul = 2,
	rupture_radius = 90,
	rupture_base_mul = 1.5,
	rupture_stored_mul = 0.2,
	rupture_cap_mul = 6,
	boss_rupture_mul = 5,
	belial_per = 0.2,
	belial_cap = 2,
	wisp_mul_cap = 10,
	waves = {},
	room_belial = {},
	wave_serial = 0,
}
auxi.add_to_seija(item.entity)

local skip_dmg_flags = DamageFlag.DAMAGE_FAKE | DamageFlag.DAMAGE_CLONES
local stitch_spr = Sprite()
stitch_spr:Load("gfx/mimics/Gospel/Gospel_Tear.anm2", true)

local UNSAFE_BOSS = {
	[45] = true,
	[78] = true,
	[84] = true,
	[102] = true,
	[273] = true,
	[274] = true,
	[275] = true,
	[406] = true,
	[407] = true,
	[412] = true,
	[912] = true,
	[950] = true,
	[951] = true,
}

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

function item.force_seija()
	local debug = debug_root()
	return debug and debug.SutureNeedleForceSeija == true
end

function item.is_seija(player)
	if item.force_seija() then return true end
	return player and auxi.should_do_Seija(player) == true
end

function item.find_player_by_idx(idx)
	if idx == nil then return nil end
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player:GetData().__Index == idx then
			return player
		end
	end
end

function item.npc_state(ent, create)
	if not ent then return nil end
	local d = ent:GetData()
	local st = d[item.own_key]
	if st == nil and create then
		st = {}
		d[item.own_key] = st
	end
	return st
end

function item.clear_state(ent)
	if not ent then return end
	ent:GetData()[item.own_key] = nil
end

function item.ent_key(ent)
	if not ent then return nil end
	local seed = ent.InitSeed
	if seed and seed ~= 0 then return seed end
	return GetPtrHash(ent)
end

function item.can_mark(ent)
	if not ent or not ent:Exists() or ent:IsDead() then return false end
	if not auxi.isenemies(ent) then return false end
	if ent.Type == 996 then return false end
	if ent.Type == EntityType.ENTITY_GLOBIN then return false end
	if UNSAFE_BOSS[ent.Type] then return false end
	return true
end

function item.can_full_corpse(ent)
	if not item.can_mark(ent) then return false end
	if ent:IsBoss() then return false end
	return true
end

function item.thread_color(alpha, strong)
	alpha = alpha or 0.9
	local col = Color(1, 1, 1, alpha)
	if col.SetColorize then
		if strong then col:SetColorize(0.78, 0.12, 0.16, 1)
		else col:SetColorize(0.58, 0.14, 0.2, 0.7) end
	end
	return col
end

function item.source_player(source)
	if not source or not source.Entity then return nil end
	return auxi.check_spawner_player(source.Entity)
end

function item.is_lethal(ent, amt)
	if not ent or amt == nil or amt <= 0 then return false end
	if ent.HitPoints - amt <= 0 then return true end
	if ent.HasMortalDamage and ent:HasMortalDamage() then return true end
	return false
end

function item.ensure_wisp(player, useFlags)
	if not player or not auxi.should_spawn_wisp(player, useFlags) then return nil end
	local wisps = auxi.get_wisps(player, item.entity)
	local ent = wisps[1]
	if ent then
		for i = 2, #wisps do
			if wisps[i] then wisps[i]:Remove() end
		end
	else
		ent = player:AddWisp(item.entity, player.Position, false, false)
	end
	return ent
end

function item.grow_wisp(player)
	if not player then return end
	local wisps = auxi.get_wisps(player, item.entity)
	local ent = wisps[1]
	if not ent or not ent:Exists() then return end
	for i = 2, #wisps do
		if wisps[i] then wisps[i]:Remove() end
	end
	local d = ent:GetData()
	d.Suture_Needle_mul = math.min(item.wisp_mul_cap, (d.Suture_Needle_mul or 0) + 1)
	ent.MaxHitPoints = ent.MaxHitPoints + 1
	ent.HitPoints = math.min(ent.MaxHitPoints, ent.HitPoints + 1)
end

function item.fire_wisp_at(player, pos)
	if not player or not pos then return end
	local wisps = auxi.get_wisps(player, item.entity)
	for i = 1, #wisps do
		local wisp = wisps[i]
		if wisp and wisp:Exists() and not wisp:IsDead() then
			local dir = pos - wisp.Position
			if dir:Length() < 0.1 then dir = RandomVector() end
			local tear = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.BLOOD, 0, wisp.Position, dir:Resized(12), wisp):ToTear()
			if tear then
				tear.CollisionDamage = wisp.CollisionDamage
				tear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
			end
		end
	end
end

function item.add_belial(player)
	if not player or not auxi.should_do_belial(player) then return end
	local idx = player:GetData().__Index
	if idx == nil then return end
	item.room_belial = item.room_belial or {}
	local cur = item.room_belial[idx] or 0
	if cur >= item.belial_cap then return end
	item.room_belial[idx] = math.min(item.belial_cap, cur + item.belial_per)
	player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
	player:GetData().should_evaluate_on_update_once = true
end

function item.rupture_damage(player, st, is_boss)
	if not player then return 0 end
	if is_boss then
		return player.Damage * item.boss_rupture_mul
	end
	local stored = (st and st.SutureDamage) or 0
	local dmg = player.Damage * item.rupture_base_mul + stored * item.rupture_stored_mul
	return math.min(dmg, player.Damage * item.rupture_cap_mul)
end

function item.play_hit_fx(ent, st)
	if not ent then return end
	ent:BloodExplode()
	local hits = (st and st.SutureHits) or 0
	if hits >= 2 then
		for i = 1, math.min(4, hits) do
			Isaac.Spawn(1000, EffectVariant.BLOOD_DROP, 0, ent.Position, RandomVector() * (2 + i), ent)
		end
	end
	if hits % 2 == 1 then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_BURST_SMALL, 0.7, 1.1, false, 0, 2)
	end
end

function item.play_rupture_fx(pos, st)
	local hits = (st and st.SutureHits) or 0
	Isaac.Spawn(1000, EffectVariant.BLOOD_EXPLOSION, 0, pos, Vector(0, 0), nil)
	if hits >= 2 then
		for i = 1, 3 do
			Isaac.Spawn(1000, EffectVariant.BLOOD_EXPLOSION, 0, pos + RandomVector() * 18, Vector(0, 0), nil)
		end
	end
	if hits >= 5 then
		Game():ShakeScreen(8)
		Isaac.Spawn(1000, EffectVariant.LARGE_BLOOD_EXPLOSION, 0, pos, Vector(0, 0), nil)
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS, 1.1, 0.95, false, 0, 2)
end

function item.deal_rupture(pos, st, skip_hash, is_boss)
	local player = item.find_player_by_idx(st and st.owner_idx)
	player = player or Game():GetPlayer(0)
	local dmg = item.rupture_damage(player, st, is_boss)
	if dmg <= 0 then return end
	local enemies = auxi.getenemies()
	for i = 1, #enemies do
		local ent = enemies[i]
		if ent and ent:Exists() and not ent:IsDead() then
			if GetPtrHash(ent) ~= skip_hash then
				if (ent.Position - pos):Length() <= item.rupture_radius then
					ent:TakeDamage(dmg, 0, EntityRef(player), 0)
				end
			end
		end
	end
end

function item.rupture_corpse(ent, st, deal, already_dying)
	if not ent then return end
	st = st or item.npc_state(ent)
	if st and st.ruptured then
		item.clear_state(ent)
		if (not already_dying) and ent:Exists() then ent:Remove() end
		return
	end
	if st then st.ruptured = true end
	local pos = Vector(ent.Position.X, ent.Position.Y)
	local hash = GetPtrHash(ent)
	local owner = item.find_player_by_idx(st and st.owner_idx)
	if deal ~= false then
		item.deal_rupture(pos, st, hash, false)
	end
	item.play_rupture_fx(pos, st)
	if owner then item.fire_wisp_at(owner, pos) end
	item.clear_state(ent)
	if (not already_dying) and ent:Exists() then ent:Remove() end
end

function item.enter_corpse(ent, player)
	if not ent or not item.can_full_corpse(ent) then return false end
	local st = item.npc_state(ent, true)
	if st.SutureDead then return false end
	st.Sutured = true
	st.SutureDead = true
	st.SutureHits = 0
	st.SutureDamage = 0
	st.dummy_hp = 1
	if player then
		st.owner_idx = player:GetData().__Index
	end
	local seija = item.is_seija(player)
	st.SutureLifeMax = seija and item.seija_corpse_frames or item.corpse_frames
	st.SutureLife = st.SutureLifeMax
	ent.HitPoints = st.dummy_hp
	ent.CanShutDoors = true
	if EntityFlag.FLAG_HIDE_HP_BAR then
		ent:AddEntityFlags(EntityFlag.FLAG_HIDE_HP_BAR)
	end
	ent:BloodExplode()
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_BURST_LARGE, 0.85, 1.05, false, 0, 2)
	item.grow_wisp(player)
	item.add_belial(player)
	return true
end

function item.mark_enemy(ent, player, wave_id)
	if not item.can_mark(ent) then return false end
	local st = item.npc_state(ent)
	if st and (st.Sutured or st.SutureDead) then return false end
	st = item.npc_state(ent, true)
	st.Sutured = true
	st.SutureDead = false
	st.SutureHits = 0
	st.SutureDamage = 0
	st.SutureLife = 0
	st.SutureLifeMax = 0
	st.wave_id = wave_id
	st.mark_until = Game():GetFrameCount() + item.mark_frames
	if player then
		st.owner_idx = player:GetData().__Index
	end
	return true
end

function item.keep_corpse_alive(ent, st)
	if not ent or not st or not st.SutureDead then return end
	if not ent:Exists() then return end
	ent.HitPoints = math.max(st.dummy_hp or 1, math.min(ent.HitPoints, st.dummy_hp or 1))
	ent.CanShutDoors = true
end

function item.tick_npc(ent)
	local st = item.npc_state(ent)
	if not st then return end
	if not ent:Exists() then
		item.clear_state(ent)
		return
	end
	if st.SutureDead then
		item.keep_corpse_alive(ent, st)
		st.SutureLife = (st.SutureLife or 0) - 1
		if st.SutureLife <= 0 or ent:IsDead() then
			item.rupture_corpse(ent, st, true)
		end
		return
	end
	if st.Sutured then
		if Game():GetFrameCount() >= (st.mark_until or 0) then
			item.clear_state(ent)
		end
	end
end

function item.apply_unstitch(ent, st, amt, player)
	if not st or not st.SutureDead then return end
	local mul = item.hit_coef
	if item.is_seija(player) then mul = mul * item.seija_hit_mul end
	local cut = item.hit_flat + amt * mul
	st.SutureHits = (st.SutureHits or 0) + 1
	st.SutureDamage = (st.SutureDamage or 0) + amt
	st.SutureLife = (st.SutureLife or 0) - cut
	item.play_hit_fx(ent, st)
	if st.SutureLife <= 0 then
		item.rupture_corpse(ent, st, true)
	end
end

function item.color_ring(ring)
	if not ring then return end
	local col = item.thread_color(0.85, true)
	ring.Color = col
	if ring.GetSprite then
		local s = ring:GetSprite()
		if s then s.Color = col end
	end
end

function item.spawn_wave(player)
	if not player then return end
	item.wave_serial = (item.wave_serial or 0) + 1
	local wave = {
		id = item.wave_serial,
		pos = Vector(player.Position.X, player.Position.Y),
		radius = 0,
		max_radius = item.wave_radius,
		speed = item.wave_speed,
		owner_idx = player:GetData().__Index,
		hit = {},
		ring = nil,
	}
	local var = LaserVariant.LIGHT_RING or 8
	local spawned = Isaac.Spawn(EntityType.ENTITY_LASER, var, 0, wave.pos, Vector(0, 0), nil)
	local ring = spawned and spawned:ToLaser()
	if ring then
		ring.Radius = 8
		ring.CollisionDamage = 0
		ring.OneHit = false
		ring.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		ring.GridCollisionClass = GridCollisionClass.COLLISION_NONE
		if ring.SetTimeout then ring:SetTimeout(20) else ring.Timeout = 20 end
		item.color_ring(ring)
		wave.ring = ring
	end
	item.waves[#item.waves + 1] = wave
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_TOOTH_AND_NAIL, 1.05, 1.05, false, 0, 2)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_TOOTH_AND_NAIL, 0.85, 0.9, false, 2, 2)
end

function item.tick_wave(wave)
	if not wave then return false end
	local player = item.find_player_by_idx(wave.owner_idx)
	wave.radius = (wave.radius or 0) + (wave.speed or item.wave_speed)
	local ring = wave.ring
	if ring and ring:Exists() then
		ring.Position = wave.pos
		ring.Velocity = Vector(0, 0)
		ring.Radius = wave.radius
		item.color_ring(ring)
	else
		wave.ring = nil
	end
	local enemies = auxi.getenemies()
	for i = 1, #enemies do
		local ent = enemies[i]
		local key = item.ent_key(ent)
		if key and not wave.hit[key] then
			if (ent.Position - wave.pos):Length() <= wave.radius then
				wave.hit[key] = true
				item.mark_enemy(ent, player, wave.id)
			end
		end
	end
	if wave.radius >= (wave.max_radius or item.wave_radius) then
		if ring and ring:Exists() then ring:Remove() end
		return false
	end
	return true
end

function item.clear_room()
	item.waves = {}
	item.room_belial = {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
		player:GetData().should_evaluate_on_update_once = true
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, collect, rng, player, useFlags, activeSlot, varData)
	if (useFlags & UseFlag.USE_CARBATTERY) == UseFlag.USE_CARBATTERY then
	else
		item.ensure_wisp(player, useFlags)
		item.spawn_wave(player)
		return true
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	for i = #item.waves, 1, -1 do
		if not item.tick_wave(item.waves[i]) then
			table.remove(item.waves, i)
		end
	end
end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {CallBack = ModCallbacks.MC_PRE_NPC_UPDATE, params = nil,
Function = function(_, ent)
	local st = item.npc_state(ent)
	if st and st.SutureDead then
		item.keep_corpse_alive(ent, st)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_, ent)
	item.tick_npc(ent)
end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_, ent, amt, flag, source, cooldown)
	if not ent or not ent:ToNPC() then return end
	local st = item.npc_state(ent)
	if not st then return end
	if (flag & skip_dmg_flags) ~= 0 then return end
	if amt == nil or amt <= 0 then return end
	local player = item.source_player(source)
	if st.SutureDead then
		if player then
			item.apply_unstitch(ent, st, amt, player)
		end
		return false
	end
	if st.Sutured and item.is_lethal(ent, amt) and item.can_full_corpse(ent) then
		item.enter_corpse(ent, player or item.find_player_by_idx(st.owner_idx))
		return false
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = nil,
Function = function(_, ent)
	local st = item.npc_state(ent)
	if not st then return end
	if st.SutureDead then
		item.rupture_corpse(ent, st, true, true)
		return
	end
	if not st.Sutured then return end
	local pos = Vector(ent.Position.X, ent.Position.Y)
	local owner = item.find_player_by_idx(st.owner_idx)
	item.deal_rupture(pos, st, GetPtrHash(ent), ent:IsBoss())
	item.play_rupture_fx(pos, st)
	if owner then item.fire_wisp_at(owner, pos) end
	item.clear_state(ent)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	if (cacheFlag & CacheFlag.CACHE_DAMAGE) ~= CacheFlag.CACHE_DAMAGE then return end
	local idx = player:GetData().__Index
	local bonus = (item.room_belial or {})[idx] or 0
	if bonus <= 0 then return end
	player.Damage = player.Damage + auxi.get_damage_multiplier(player) * bonus
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	item.clear_room()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function()
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	for i = 1, #item.waves do
		local wave = item.waves[i]
		if wave and (wave.radius or 0) > 0 then
			local pos = Isaac.WorldToScreen(wave.pos)
			local scale = math.max(0.4, (wave.radius or 0) / 42)
			stitch_spr.Color = item.thread_color(0.55, true)
			stitch_spr.Scale = Vector(scale, scale * 0.42)
			stitch_spr.Rotation = Game():GetFrameCount() * 9
			stitch_spr:SetFrame("Idle", 0)
			stitch_spr:Render(pos, Vector(0, 0), Vector(0, 0))
		end
	end
	stitch_spr.Scale = Vector(1, 1)
	stitch_spr.Rotation = 0
	stitch_spr.Color = Color(1, 1, 1, 1)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local st = item.npc_state(ent)
	if not st or not st.Sutured then return end
	offset = offset or Vector(0, 0)
	local frame = Game():GetFrameCount()
	local count = st.SutureDead and 5 or 3
	if st.SutureDead then
		count = math.min(8, 4 + (st.SutureHits or 0))
	end
	local radius = ent.Size + (st.SutureDead and 10 or 6)
	local base = Isaac.WorldToScreen(ent.Position + ent.PositionOffset) + offset
	stitch_spr.Color = item.thread_color(st.SutureDead and 0.35 or 0.22, false)
	stitch_spr.Scale = Vector(1.05 + (st.SutureDead and 0.25 or 0), 0.42)
	stitch_spr.Rotation = frame * 2
	stitch_spr:SetFrame("Idle", 0)
	stitch_spr:Render(base, Vector(0, 0), Vector(0, 0))
	for i = 1, count do
		local ang = frame * 4 + (i - 1) * (360 / count)
		local world = ent.Position + ent.PositionOffset + auxi.MakeVector(ang) * radius
		local pos = Isaac.WorldToScreen(world) + offset
		stitch_spr.Color = item.thread_color(st.SutureDead and 0.95 or 0.7, true)
		stitch_spr.Scale = Vector(0.42, 0.42)
		stitch_spr.Rotation = ang + 90
		stitch_spr:SetFrame("Idle", 0)
		stitch_spr:Render(pos, Vector(0, 0), Vector(0, 0))
	end
	stitch_spr.Scale = Vector(1, 1)
	stitch_spr.Rotation = 0
	stitch_spr.Color = Color(1, 1, 1, 1)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.WISP,
Function = function(_, ent)
	if ent.Type ~= 3 or ent.Variant ~= FamiliarVariant.WISP or ent.SubType ~= item.entity then return end
	local d = ent:GetData()
	local s = ent:GetSprite()
	local mul = d.Suture_Needle_mul or 0
	d.Suture_Needle_scale = (d.Suture_Needle_scale or Vector(1, 1)) * 0.9 + Vector(1 + mul * 0.08, 1 + mul * 0.08) * 0.1
	s.Scale = d.Suture_Needle_scale
	s.Color = item.thread_color(1, true)
	ent.CollisionDamage = 2 + mul * 0.45
end,
})

return item


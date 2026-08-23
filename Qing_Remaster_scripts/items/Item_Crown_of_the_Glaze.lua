local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")

local item = {
	myToCall = {},
	ToCall = {},
	pre_ToCall = {},
	entity = enums.Items.Crown_of_the_glaze,
	own_key = "Item_Glaze_Crown",
	max_stacks = 5,
	damage_bonus = 0.6,
	luck_bonus = 1,
	refract_chance = 0.22,
	refract_damage = 0.3,
	infect_chance = 0.06,
	infect_cooldown = 45,
	shatter_damage = 0.4,
	shatter_drop_chance = 0.25,
	effect_chance_mul = 1.25,
	shard_counts = {6, 8, 10, 12, 16},
}

auxi.add_to_seija(item.entity)

local skip_hurt_flags = DamageFlag.DAMAGE_FAKE
	| DamageFlag.DAMAGE_DEVIL
	| DamageFlag.DAMAGE_IV_BAG
	| DamageFlag.DAMAGE_CURSED_DOOR
	| DamageFlag.DAMAGE_NO_PENALTIES
	| DamageFlag.DAMAGE_CLONES

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

function item.any_infect()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if item.has_item(player) and item.get_stacks(player) >= 4 then return true end
	end
	return false
end

function item.get_spawn_mul()
	if not item.has_any() then return 1 end
	local n = item.crown_copies()
	if n < 1 then n = 1 end
	local mul = 1.5
	if n >= 2 then mul = 1.75 end
	if n >= 3 then mul = 2.0 end
	if item.any_seija() then
		mul = math.min(mul, 1.2)
	end
	return mul
end

-- 把原 1/denom 琉璃化判定改成乘冠冕生成倍率。无冠冕时倍率=1。
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

function item.get_effect_chance_mul(player)
	if not item.has_item(player) then return 1 end
	if item.get_stacks(player) < 3 then return 1 end
	if item.is_seija(player) then return 1 end
	return item.effect_chance_mul
end

function item.notify_pickup(player)
	if not item.has_item(player) then return false end
	local n = item.get_stacks(player)
	if n >= item.max_stacks then return false end
	item.set_stacks(player, n + 1)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_STONE_IMPACT, 0.45, 1.4, false, 0, 2)
	return true
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
	tear.CollisionDamage = tear.CollisionDamage
	local col = Color(0.75, 1, 1, 0.72, 0.15, 0.35, 0.45)
	if col.SetColorize then col:SetColorize(0.35, 0.85, 1, 0.28) end
	tear:SetColor(col, -1, 8, false, false)
	if kind == "refract" then
		tear.Scale = (tear.Scale or 1) * 0.45
	else
		tear.Scale = (tear.Scale or 1) * 0.55
	end
	tear.Height = -20
	tear.FallingSpeed = -1.5
	tear.FallingAcceleration = 0.4
	return tear
end

local function fire_glaze_shard(player, pos, vel, dmg_mul, kind, shatter_token)
	if not player or not player.FireTear then return nil end
	local tear = player:FireTear(pos, vel, false, true, false, player, dmg_mul)
	if not tear then return nil end
	mark_special_tear(tear, kind, shatter_token)
	tear.CollisionDamage = (player.Damage or 3.5) * dmg_mul
	return tear
end

local shatter_seq = 0

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

function item.shatter(player)
	local n = item.get_stacks(player)
	if n <= 0 then return end
	local complete = n >= item.max_stacks
	item.set_stacks(player, 0)
	shatter_seq = shatter_seq + 1
	local token = shatter_seq
	save.elses[item.own_key.."shatter_epoch"] = token
	save.elses[item.own_key.."shatter_dropped"] = false
	local copies = math.max(1, player:GetCollectibleNum(item.entity) or 1)
	local dmg_mul = item.shatter_damage * (1 + 0.15 * (copies - 1))
	if item.is_seija(player) then dmg_mul = dmg_mul * 0.5 end
	local count = item.shard_counts[n] or 6
	local speed = 9 * (player.ShotSpeed or 1)
	local rng = player:GetCollectibleRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	for i = 1, count do
		local ang = (360 / count) * (i - 1) + (rng and rng:RandomInt(12) or 0)
		fire_glaze_shard(player, player.Position, auxi.MakeVector(ang) * speed, dmg_mul, "shatter", token)
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_GLASS_BREAK, 1.1, 0.95, false, 0, 2)
	Game():ShakeScreen(8 + n)
	player:GetData()[item.own_key.."flash"] = 12
	if complete then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MIRROR_BREAK, 0.85, 1.05, false, 0, 2)
		Game():Darken(0.35, 18)
		local enemies = auxi.getenemies(Isaac.GetRoomEntities())
		for i = 1, #enemies do
			local ent = enemies[i]
			if auxi.check_all_exists(ent) and ent:IsVulnerableEnemy() then
				ent:TakeDamage((player.Damage or 3.5) * 0.25, 0, EntityRef(player), 0)
			end
		end
		for i = 1, 8 do
			local ang = (360 / 8) * i
			fire_glaze_shard(player, player.Position, auxi.MakeVector(ang) * (speed * 0.7), dmg_mul * 0.6, "shatter", token)
		end
	end
end

local function try_refract(player, tear, victim)
	if item.get_stacks(player) < 2 then return end
	if not tear or not victim then return end
	local td = tear:GetData()
	if td[item.own_key.."kind"] then return end
	if td[item.own_key.."did_refract"] then return end
	td[item.own_key.."did_refract"] = true
	local rng = make_rng(tear.InitSeed, 91)
	local chance = item.refract_chance * item.get_effect_chance_mul(player)
	if rng:RandomInt(10000) >= math.floor(chance * 10000) then return end
	local dir = tear.Velocity
	if not dir or dir:Length() < 0.2 then
		dir = victim.Position - player.Position
	end
	if dir:Length() < 0.2 then dir = Vector(1, 0) end
	local speed = dir:Length()
	if speed < 6 then speed = 8 * (player.ShotSpeed or 1) end
	local base = dir:Normalized() * speed
	fire_glaze_shard(player, tear.Position, auxi.get_by_rotate(base, 28, speed), item.refract_damage, "refract")
	fire_glaze_shard(player, tear.Position, auxi.get_by_rotate(base, -28, speed), item.refract_damage, "refract")
end

local infect_cd = {}

local function try_infect(player, ent, source_ent)
	if item.get_stacks(player) < 4 then return end
	if not auxi.check_all_exists(ent) or not auxi.isenemies(ent) then return end
	if ent:IsBoss() or ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return end
	if item.is_glazed_enemy(ent) then return end
	local seed = ent.InitSeed or 0
	local now = Game():GetFrameCount()
	if (infect_cd[seed] or 0) > now then return end
	local chance = item.infect_chance * item.get_effect_chance_mul(player)
	local luck = tonumber(player.Luck) or 0
	if luck > 0 then chance = chance + math.min(0.06, luck * 0.008) end
	if chance > 0.12 then chance = 0.12 end
	local rng = make_rng((source_ent and source_ent.InitSeed) or player.InitSeed, seed % 10007 + 17)
	if rng:RandomInt(10000) >= math.floor(chance * 10000) then
		infect_cd[seed] = now + 8
		return
	end
	infect_cd[seed] = now + item.infect_cooldown
	glaze_enemy_mod().Make_Glazed_Enemy(ent)
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
		player.Damage = player.Damage + item.damage_bonus * auxi.get_damage_multiplier(player)
	end
	if cacheFlag == CacheFlag.CACHE_LUCK and stacks >= 3 then
		player.Luck = player.Luck + item.luck_bonus
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
	local kind = src:GetData()[item.own_key.."kind"]
	if src.Type == EntityType.ENTITY_TEAR then
		if kind == "shatter" then
			ent:GetData()[item.own_key.."hit_shatter"] = src:GetData()[item.own_key.."shatter"]
		else
			try_refract(player, src, ent)
		end
	end
	if kind == "shatter" then return end
	try_infect(player, ent, src)
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

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	infect_cd = {}
end,
})

local function ensure_sprite(player)
	local d = player:GetData()
	if d[item.own_key.."sprite"] then return d[item.own_key.."sprite"] end
	local spr = Sprite()
	spr:Load("gfx/mimics/Glaze Crown/crown_of_glaze.anm2", true)
	spr:Play("FloatNoGlow", true)
	d[item.own_key.."sprite"] = spr
	d[item.own_key.."sprite_anim"] = "FloatNoGlow"
	d[item.own_key.."sprite_dirty"] = true
	return spr
end

local function sync_sprite(player)
	local spr = ensure_sprite(player)
	local d = player:GetData()
	local stacks = item.get_stacks(player)
	local anim = (stacks <= 0) and "FloatNoGlow" or "FloatGlow"
	if d[item.own_key.."sprite_anim"] ~= anim or d[item.own_key.."sprite_dirty"] then
		spr:Play(anim, true)
		d[item.own_key.."sprite_anim"] = anim
		d[item.own_key.."sprite_dirty"] = nil
	end
	local alpha = 0.28 + 0.12 * stacks
	if stacks <= 0 then alpha = 0.22 end
	local col = Color(1, 1, 1, alpha, 0, 0, 0)
	if stacks >= 5 and col.SetColorize then
		col:SetColorize(0.45, 0.95, 1.1, 0.4)
	elseif stacks >= 4 and col.SetColorize then
		col:SetColorize(0.25, 0.7, 1.0, 0.22)
	elseif stacks >= 1 and col.SetColorize then
		col:SetColorize(0.1, 0.35, 0.5, 0.08)
	end
	local flash = tonumber(d[item.own_key.."flash"]) or 0
	if flash > 0 then
		if col.SetColorize then col:SetColorize(1.2, 1.2, 1.4, 0.8) end
		col.A = math.min(1, alpha + 0.4)
	end
	spr.Color = col
	return spr
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_, player, offset)
	if not item.has_item(player) then return end
	local room = Game():GetRoom()
	if room and room.GetRenderMode and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local spr = sync_sprite(player)
	local pos = Isaac.WorldToScreen(player.Position + player_offset_holder.GetPlayerOffset(player))
	if offset then pos = pos + offset end
	spr:Render(pos, Vector(0, 0), Vector(0, 0))
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PEFFECT_UPDATE, params = nil,
Function = function(_, player)
	if not item.has_item(player) then return end
	local d = player:GetData()
	local spr = ensure_sprite(player)
	if Game():IsPaused() == false then
		spr:Update()
		if (d[item.own_key.."flash"] or 0) > 0 then
			d[item.own_key.."flash"] = d[item.own_key.."flash"] - 1
		end
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."stacks"] = {}
	end
	save.elses[item.own_key.."stacks"] = save.elses[item.own_key.."stacks"] or {}
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
		end
	end
end,
})

-- 冠冕满层（5 辉片）对各琉璃掉落的额外增幅：由各 pickup 脚本注册，勿写进 translate 静态文案。
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

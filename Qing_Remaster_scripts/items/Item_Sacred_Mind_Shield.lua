local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	pre_ToCall = {},
	entity = enums.Items.Sacred_Mind_Shield,
	own_key = "Item_Sacred_Mind_Shield_",
	damage_mul_per_kill = 0.05,
	shotspeed_per_kill = -0.02,
	max_kills_per_wave = 5,
	shockwave_damage_mul = 10,
	shockwave_damage_flat = 40,
	wave_radius_speed = 22,
	wave_radius_accel = -0.15,
	wave_fade = 0.005,
	wave_fade_mul = 0.994,
	wave_min_alpha = 0.08,
	-- HUD / 破碎演出
	hud_anm2 = "gfx/ui/ui_sacred_mind_shield.anm2",
	hud_anim = "Idle",
	hud_explode_anim = "Explode",
	hud_fallback_anm2 = "gfx/ui/ui_hearts.anm2",
	hud_fallback_anim = "HolyMantle",
	heart_anm2 = "gfx/ui/ui_hearts.anm2",
	heart_anim = "RedHeartFull",
	-- anm2: Fps=30, Explode FrameNum=13（与游戏 30ups 对齐：1 逻辑帧 = 1 动画帧）
	explode_frame_num = 13,
	explode_reveal_frame = 10, -- 第10帧后（0-based: GetFrame()>=10）淡入下方心
	heart_fade_frames = 3,
	fly_duration_ms = 900, -- 飞行用真实时间，按渲染帧插值，避免卡顿
}

-- 带 DAMAGE_NO_PENALTIES 的为非惩罚性伤害，不应触发护盾
local skip_damage_flags = DamageFlag.DAMAGE_FAKE
	| DamageFlag.DAMAGE_DEVIL
	| DamageFlag.DAMAGE_IV_BAG
	| DamageFlag.DAMAGE_CURSED_DOOR
	| DamageFlag.DAMAGE_NO_PENALTIES
local break_fx_list = {}

local shield_sprite = Sprite()
local shield_sprite_ready = false
local shield_sprite_tried = false
local shield_anim_name = nil

local function ensure_shield_sprite()
	if shield_sprite_tried then return shield_sprite_ready end
	shield_sprite_tried = true
	if pcall(function()
		shield_sprite:Load(item.hud_anm2, true)
		shield_sprite:Play(item.hud_anim, true)
		shield_sprite:SetFrame(item.hud_anim, 0)
	end) then
		shield_anim_name = item.hud_anim
		shield_sprite_ready = true
		return true
	end
	if pcall(function()
		shield_sprite:Load(item.hud_fallback_anm2, true)
		shield_sprite:Play(item.hud_fallback_anim, true)
		shield_sprite:SetFrame(item.hud_fallback_anim, 0)
	end) then
		shield_anim_name = item.hud_fallback_anim
		shield_sprite_ready = true
		return true
	end
	shield_sprite_ready = false
	return false
end

local function run_bucket()
	save.elses = save.elses or {}
	save.elses[item.own_key.."run"] = save.elses[item.own_key.."run"] or {}
	return save.elses[item.own_key.."run"]
end

local function floor_bucket()
	save.elses = save.elses or {}
	save.elses[item.own_key.."floor"] = save.elses[item.own_key.."floor"] or {}
	return save.elses[item.own_key.."floor"]
end

local function player_bonus(player)
	local idx = player and player:GetData().__Index
	if idx == nil then return nil end
	local run = run_bucket()
	run.bonus = run.bonus or {}
	run.bonus[idx] = run.bonus[idx] or {mul = 0, shot = 0}
	return run.bonus[idx]
end

local function find_player_by_idx(idx)
	if idx == nil then return nil end
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player:GetData().__Index == idx then
			return player
		end
	end
end

local function find_player_by_hash(hash)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if GetPtrHash(player) == hash then
			return player
		end
	end
end

function item.get_charges(player)
	if not player or not auxi.has_have_coll(player,item.entity) then return 0 end
	local idx = player:GetData().__Index
	if idx == nil then return 0 end
	local run = run_bucket()
	run.used = run.used or {}
	local used = math.max(0, math.floor(tonumber(run.used[idx]) or 0))
	local owned = math.max(0, player:GetCollectibleNum(item.entity))
	return math.max(0, owned - used)
end

function item.consume_charge(player)
	local idx = player:GetData().__Index
	if idx == nil then return false end
	if item.get_charges(player) <= 0 then return false end
	local run = run_bucket()
	run.used = run.used or {}
	run.used[idx] = (run.used[idx] or 0) + 1
	return true
end

function item.add_kill_bonus(player, count)
	count = math.max(0, math.floor(tonumber(count) or 0))
	if count <= 0 or not player then return end
	local bonus = player_bonus(player)
	if not bonus then return end
	bonus.mul = (bonus.mul or 0) + item.damage_mul_per_kill * count
	bonus.shot = (bonus.shot or 0) + item.shotspeed_per_kill * count
	player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED)
	if player.EvaluateItems then
		player:EvaluateItems()
	else
		player:GetData().should_evaluate_on_update_once = true
	end
end

local function grant_heart_container(player)
	if not player then return end
	if auxi.is_player_lost_(player) then
		player:AddSoulHearts(2)
		return
	end
	local before = player:GetMaxHearts()
	player:AddMaxHearts(2)
	if player:GetMaxHearts() > before then
		player:AddHearts(2)
	else
		player:AddSoulHearts(2)
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SUPERHOLY, 1, 1, false, 0, 2)
end

local function is_punitive_damage(amt, flag)
	if not amt or amt <= 0 then return false end
	flag = flag or 0
	-- 无 NO_PENALTIES 等排除旗标的才是惩罚性伤害（影响恶魔交易等）
	return (flag & skip_damage_flags) == 0
end

local function current_room_key()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return nil end
	return auxi.get_acceptible_index(desc.SafeGridIndex)
end

local function mark_floor_rooms(exclude_key)
	local floor = floor_bucket()
	floor.pending = {}
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local dimen = auxi.GetDimension()
	for i = 0, rooms.Size - 1 do
		local desc = rooms:Get(i)
		if desc and desc.Data and auxi.GetDimension(desc) == dimen then
			local key = auxi.get_acceptible_index(desc.SafeGridIndex)
			if key and key ~= exclude_key then
				floor.pending[tostring(key)] = true
			end
		end
	end
end

-- 击杀归属：只认「本冲击波致死」的敌人
-- 存活敌人绝不能打长寿命标记，否则之后被眼泪打死也会误加
-- 参考 Tecro：TAKE_DMG 里 amt >= HitPoints 判定致死；InitSeed 仅作去重键
local pending_lethal = {} -- [seed] = {idx, token, expire}
local wave_context = nil -- {idx, token} 仅在 release_shockwave 的 TakeDamage 循环内

local function enemy_seed(ent)
	if not ent then return nil end
	local seed = ent.InitSeed
	if seed and seed ~= 0 then return seed end
	return ent.Index
end

local function next_wave_token(player_idx)
	local run = run_bucket()
	run.wave_token = (run.wave_token or 0) + 1
	run.wave_kills = run.wave_kills or {}
	run.wave_kills[run.wave_token] = {
		idx = player_idx,
		count = 0,
	}
	return run.wave_token
end

-- 仅在已确认致死时调用；expire 只覆盖死亡动画延迟（2 帧），不是“挨过打窗口”
local function mark_lethal_kill(ent)
	if not wave_context or not ent then return end
	local seed = enemy_seed(ent)
	if not seed then return end
	pending_lethal[seed] = {
		idx = wave_context.idx,
		token = wave_context.token,
		expire = Game():GetFrameCount() + 2,
	}
end

local function is_dead_now(ent)
	if not ent then return true end
	if not ent:Exists() or ent:IsDead() then return true end
	if ent.HitPoints <= 0 then return true end
	if ent.HasMortalDamage and ent:HasMortalDamage() then return true end
	return false
end

local function try_count_wave_kill(ent)
	if not ent then return end
	if ent:IsEnemy() == false or ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return end
	local seed = enemy_seed(ent)
	if not seed then return end
	local tag = pending_lethal[seed]
	if not tag then return end
	pending_lethal[seed] = nil
	if Game():GetFrameCount() > (tag.expire or 0) then return end

	local run = run_bucket()
	local info = run.wave_kills and run.wave_kills[tag.token]
	if not info then return end
	if info.count >= item.max_kills_per_wave then return end
	info.count = info.count + 1
	local player = find_player_by_idx(info.idx)
	if player then
		item.add_kill_bonus(player, 1)
	end
end

local function default_hud_pos()
	return Vector(48, 12)
end

function item.start_break_fx(player)
	local d = player:GetData()
	local start_pos = d[item.own_key.."hud_pos"] or default_hud_pos()
	local scale = d[item.own_key.."hud_scale"] or 1

	local explode = Sprite()
	explode:Load(item.hud_anm2, true)
	explode.PlaybackSpeed = 1
	explode:Play(item.hud_explode_anim, true)
	explode:SetFrame(item.hud_explode_anim, 0)

	local heart = Sprite()
	heart:Load(item.heart_anm2, true)
	heart.PlaybackSpeed = 1
	heart:Play(item.heart_anim, true)
	heart:SetFrame(item.heart_anim, 0)

	table.insert(break_fx_list, {
		player_hash = GetPtrHash(player),
		pos = Vector(start_pos.X, start_pos.Y),
		fly_from = Vector(start_pos.X, start_pos.Y),
		scale = scale,
		explode = explode,
		heart = heart,
		phase = "explode",
		-- 用游戏逻辑帧驱动，避免 Update/渲染帧率不同步
		start_game_frame = Game():GetFrameCount(),
		last_update_frame = -1,
		heart_alpha = 0,
		fly_start_time = 0,
		granted = false,
	})
end

-- Explode 阶段：跟游戏逻辑帧（与 anm2 Fps=30 对齐）
local function update_break_fx()
	local game_frame = Game():GetFrameCount()
	for i = #break_fx_list, 1, -1 do
		local fx = break_fx_list[i]
		local player = find_player_by_hash(fx.player_hash)
		if not player then
			table.remove(break_fx_list, i)
		elseif fx.phase ~= "explode" then
			-- 飞行阶段改在渲染时每帧插值
		elseif fx.last_update_frame == game_frame then
			-- 同一逻辑帧只推进一次
		else
			fx.last_update_frame = game_frame
			local anim_frame = game_frame - fx.start_game_frame
			if anim_frame < 0 then anim_frame = 0 end
			local clamp_frame = math.min(item.explode_frame_num - 1, anim_frame)
			fx.explode:SetFrame(item.hud_explode_anim, clamp_frame)

			if anim_frame >= item.explode_reveal_frame then
				local fade_t = (anim_frame - item.explode_reveal_frame + 1) / item.heart_fade_frames
				fx.heart_alpha = math.min(1, math.max(0, fade_t))
				fx.heart:SetFrame(item.heart_anim, 0)
			end

			if anim_frame >= item.explode_frame_num then
				fx.heart_alpha = 1
				fx.phase = "fly"
				fx.fly_from = Vector(fx.pos.X, fx.pos.Y)
				fx.fly_start_time = Isaac.GetTime()
			end
		end
	end
end

-- 飞行阶段：每渲染帧更新位置（跟屏幕刷新，不卡在 30ups）
local function update_fly_fx_on_render()
	local now = Isaac.GetTime()
	for i = #break_fx_list, 1, -1 do
		local fx = break_fx_list[i]
		if fx.phase ~= "fly" then
		else
			local player = find_player_by_hash(fx.player_hash)
			if not player then
				table.remove(break_fx_list, i)
			else
				local elapsed = now - (fx.fly_start_time or now)
				local t = math.min(1, elapsed / item.fly_duration_ms)
				t = t * t * (3 - 2 * t)
				local target = Isaac.WorldToScreen(player.Position + Vector(0, -24)) - Game().ScreenShakeOffset
				fx.pos = fx.fly_from * (1 - t) + target * t
				fx.heart:SetFrame(item.heart_anim, 0)
				if elapsed >= item.fly_duration_ms then
					if not fx.granted then
						fx.granted = true
						grant_heart_container(player)
					end
					table.remove(break_fx_list, i)
				end
			end
		end
	end
end

local function render_break_fx()
	update_fly_fx_on_render()
	for _, fx in ipairs(break_fx_list) do
		local scale = fx.scale or 1
		if fx.phase == "explode" then
			if fx.heart_alpha > 0 then
				fx.heart.Scale = Vector(scale, scale)
				fx.heart.Color = Color(1, 1, 1, fx.heart_alpha, 0, 0, 0)
				fx.heart:Render(fx.pos, Vector.Zero, Vector.Zero)
			end
			fx.explode.Scale = Vector(scale, scale)
			fx.explode.Color = Color(1, 1, 1, 1, 0, 0, 0)
			fx.explode:Render(fx.pos, Vector.Zero, Vector.Zero)
		elseif fx.phase == "fly" then
			fx.heart.Scale = Vector(scale, scale)
			fx.heart.Color = Color(1, 1, 1, 1, 0, 0, 0)
			fx.heart:Render(fx.pos, Vector.Zero, Vector.Zero)
		end
	end
end

function item.spawn_wave_visual(player, damage)
	local q = Isaac.Spawn(7, 5, 3, player.Position, Vector(0, 0), player):ToLaser()
	q.Parent = player
	q.Radius = 0
	q.CollisionDamage = 0
	local d2 = q:GetData()
	d2[item.own_key.."wave"] = true
	d2.basic_damage = damage
	local s = q:GetSprite()
	s:Load("gfx/laser_concerter.anm2", true)
	s:ReplaceSpritesheet(0, "gfx/effects/lasers/lofty_brim.png")
	s:LoadGraphics()
	s:Play("LargeRedLaser", true)
	s.Color = Color(1, 1, 1, 1, 0, 0, 0)

	local d = player:GetData()
	d[item.own_key.."waves"] = d[item.own_key.."waves"] or {}
	table.insert(d[item.own_key.."waves"], {
		ent = q,
		Radius_adder = item.wave_radius_speed,
		Radius_vel_adder = item.wave_radius_accel,
	})
	return q
end

function item.release_shockwave(player, params)
	params = params or {}
	local ignore_armor = params.ignore_armor == true
	local count_kills = params.count_kills ~= false
	local damage = player.Damage * item.shockwave_damage_mul + item.shockwave_damage_flat
	local idx = player:GetData().__Index
	local token = count_kills and idx and next_wave_token(idx) or nil

	item.spawn_wave_visual(player, damage)

	local n_entity = Isaac.GetRoomEntities()
	for _, proj in pairs(auxi.getothers(n_entity, 9)) do
		proj:Remove()
	end

	-- 不用 DAMAGE_EXPLOSION：部分敌人死亡回调/归属会异常
	local flags = 0
	if ignore_armor then
		flags = flags | DamageFlag.DAMAGE_IGNORE_ARMOR
	end

	if token then
		wave_context = {idx = idx, token = token}
	end
	for _, ent in ipairs(auxi.getenemies(n_entity)) do
		if auxi.check_all_exists(ent) then
			local taken = ent:TakeDamage(damage, flags, EntityRef(player), 0)
			-- 只有本次伤害致死才进 pending；活着的敌人不留标记
			if token and taken ~= false and is_dead_now(ent) then
				mark_lethal_kill(ent)
				try_count_wave_kill(ent)
			end
		end
	end
	wave_context = nil

	local e1 = Isaac.Spawn(1000, 16, 2, player.Position + Vector(0, 1), Vector(0, 0), player)
	local e2 = Isaac.Spawn(1000, 16, 1, player.Position + Vector(0, 1), Vector(0, 0), player)
	e1:GetSprite().Scale = Vector(2.5, 2.5)
	e2:GetSprite().Scale = Vector(2.5, 2.5)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_HOLY_MANTLE, 1, 1, false, 0, 2)
end

local function trigger_shield(player)
	if not item.consume_charge(player) then return false end

	item.start_break_fx(player)

	local enemies = auxi.getenemies()
	local ignore_armor = #enemies >= 5
	item.release_shockwave(player, {ignore_armor = ignore_armor, count_kills = true})

	if ignore_armor then
		mark_floor_rooms(current_room_key())
	end

	player:SetMinDamageCooldown(60)
	return true
end

local function get_heart_row_max(hud)
	if hud and hud.GetLayout then
		local layout = hud:GetLayout()
		if layout == 2 or layout == 3 then return 3 end
	end
	return 6
end

local function get_heart_pos(index, scale, rowmax)
	scale = scale or 1
	rowmax = rowmax or 6
	local row = math.floor((index - 1) / rowmax)
	local column = (index - 1) - row * rowmax
	return Vector(column * 12 * scale, row * 10 * scale)
end

local function get_player_hud(player)
	if player.GetPlayerHUD then return player:GetPlayerHUD() end
	if g.HUD and g.HUD.GetPlayerHUD then
		for i = 0, 3 do
			local hud = g.HUD:GetPlayerHUD(i)
			if hud and hud:GetPlayer() and GetPtrHash(hud:GetPlayer()) == GetPtrHash(player) then
				return hud
			end
		end
	end
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if not auxi.has_have_coll(player,item.entity) then return end
	local bonus = player_bonus(player)
	if not bonus then return end
	if cacheFlag == CacheFlag.CACHE_DAMAGE then
		local mul = 1 + (bonus.mul or 0)
		if mul ~= 1 then
			player.Damage = player.Damage * mul
		end
	end
	if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
		player.ShotSpeed = player.ShotSpeed + (bonus.shot or 0)
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if not player or not auxi.has_have_coll(player,item.entity) then return end
	if not is_punitive_damage(amt, flag) then return end
	if item.get_charges(player) <= 0 then return end
	if trigger_shield(player) then
		return false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local waves = d[item.own_key.."waves"]
	if not waves or #waves == 0 then return end

	local n_entity = Isaac.GetRoomEntities()
	local n_proj = auxi.getothers(n_entity, 9)
	for i = #waves, 1, -1 do
		local info = waves[i]
		local ent = info.ent
		if ent == nil or not ent:Exists() then
			table.remove(waves, i)
		else
			ent.Radius = ent.Radius + (info.Radius_adder or item.wave_radius_speed)
			info.Radius_adder = math.max(0, (info.Radius_adder or item.wave_radius_speed) + (info.Radius_vel_adder or item.wave_radius_accel))
			local s = ent:GetSprite()
			local alpha = s.Color.A
			alpha = math.max(0, math.min(alpha - item.wave_fade, alpha * item.wave_fade_mul))
			s.Color = Color(1, 1, 1, alpha, 0, 0, 0)
			if alpha < item.wave_min_alpha then
				ent:Remove()
				table.remove(waves, i)
			elseif alpha > 0.12 then
				for u2 = #n_proj, 1, -1 do
					local proj = n_proj[u2]
					if proj and math.abs((proj.Position - ent.Position):Length() - ent.Radius) < 40 then
						proj:Remove()
						table.remove(n_proj, u2)
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	update_break_fx()
end,
})

-- TAKE_DMG 在扣血前：wave_context 期间且 amt 足以致死 → 记入 pending（覆盖延迟死亡动画）
table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
	if not wave_context then return end
	if not ent or not ent:ToNPC() then return end
	if not ent:IsEnemy() or ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return end
	if not amt or amt < ent.HitPoints then return end
	mark_lethal_kill(ent)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = nil,
Function = function(_,npc)
	try_count_wave_kill(npc)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_,ent)
	try_count_wave_kill(ent)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local floor = floor_bucket()
	if not floor.pending then return end
	local key = current_room_key()
	if key == nil then return end
	local skey = tostring(key)
	if not floor.pending[skey] then return end
	floor.pending[skey] = nil

	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			item.release_shockwave(player, {ignore_armor = true, count_kills = true})
			break
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	floor_bucket().pending = nil
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	pending_lethal = {}
	wave_context = nil
	break_fx_list = {}
	if not continue then
		save.elses[item.own_key.."run"] = {}
		save.elses[item.own_key.."floor"] = {}
	end
	save.elses[item.own_key.."run"] = save.elses[item.own_key.."run"] or {}
	save.elses[item.own_key.."floor"] = save.elses[item.own_key.."floor"] or {}
end,
})

local hud_render_cb = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = hud_render_cb, params = nil,
Function = function(_)
	render_break_fx()
end,
})

if REPENTOGON and ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS then
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS, params = nil,
Function = function(_,offset,heartsSprite,position,spriteScale,player)
	if player == nil then return end
	if Game():GetLevel():GetCurses() & LevelCurse.CURSE_OF_THE_UNKNOWN ~= 0 then return end

	local hud = get_player_hud(player)
	local rowmax = get_heart_row_max(hud)
	local last = 0
	if hud and hud.GetHearts then
		local hearts = hud:GetHearts()
		for i, heart in ipairs(hearts) do
			if heart:IsVisible() then
				last = i
			end
		end
	else
		last = math.max(1, math.ceil((player:GetMaxHearts() + player:GetSoulHearts()) / 2))
	end

	local scale = 1
	if heartsSprite and heartsSprite.Scale then
		scale = heartsSprite.Scale.X
	elseif spriteScale then
		scale = spriteScale
	end
	local pos = position + get_heart_pos(last + 1, scale, rowmax)
	local d = player:GetData()
	d[item.own_key.."hud_pos"] = pos
	d[item.own_key.."hud_scale"] = scale

	if item.get_charges(player) <= 0 then return end
	if not ensure_shield_sprite() then return end

	shield_sprite.Scale = Vector(scale, scale)
	shield_sprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
	if shield_anim_name then
		shield_sprite:SetFrame(shield_anim_name, 0)
	end
	shield_sprite:Render(pos, Vector.Zero, Vector.Zero)
end,
})
end

return item

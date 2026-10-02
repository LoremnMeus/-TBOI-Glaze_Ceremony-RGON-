local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local revive_holder = require("Qing_Remaster_scripts.callbacks.revive_holder")
local enemy_death_guard = require("Qing_Remaster_scripts.auxiliary.enemy_death_guard")
-- Enemy lethal/death-interception semantics are owned by
-- auxiliary/enemy_death_guard.lua.
-- Player revive transaction is owned by callbacks/revive_holder.lua.
-- Pact / PactFollower are runtime GetData only (never save.elses).
-- Debt remains in save.elses across continue.

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Devil_s_Heart,
	revive_counter = 95,
	costumes = {
		enums.Costumes.Devil_s_Heart_Head,
		enums.Costumes.D_s_H_2,
		enums.Costumes.D_s_H_3,
		enums.Costumes.D_s_H_4,
	},
	own_key = "Item_Devil_s_Heart_",
	-- Host pays for player death: bosses lose MaxHP fraction (non-boss hostiles die).
	BOSS_PAY_FRAC = 0.12,
	-- Convert hostile pact NPC into permanent follower.
	FOLLOWER_CONVERT_HP_FRAC = 0.20,
	HOST_RETURN_RADIUS = 48,
	MAX_PACT_FOLLOWERS = 3,
	-- Debt harvest: Game():GetFrameCount() @ 30 Hz.
	-- Interval triangular-ish in [MIN, MAX] (~24–36s, denser near 30s).
	DEBT_INTERVAL_MIN = 720,
	DEBT_INTERVAL_MAX = 1080,
	DEBT_WARNING_MIN = 75,
	DEBT_WARNING_MAX = 120,
	DEBT_FINAL_WARNING = 30,
	DEBT_COLLECT_DELAY = 6,
	BELIAL_ROOM_DAMAGE = 1.0,
	DEBT_CROSS_ANM2 = "gfx/ui/devils_heart_debt_cross.anm2",
	DEBT_SMOKE_ANM2 = "gfx/ui/devils_heart_debt_smoke.anm2",
	DEBT_CROSS_SPACING = 12,
	DEBT_DAMAGE_FLAGS = DamageFlag.DAMAGE_SPIKES
		| DamageFlag.DAMAGE_INVINCIBLE
		| DamageFlag.DAMAGE_NO_PENALTIES
		| DamageFlag.DAMAGE_NO_MODIFIERS,
	-- Bumped on every run start / continue so leftover GetData pacts expire.
	pact_epoch = 0,
}
auxi.add_to_seija(item.entity)

local debt_cross_sprite = nil
local debt_smoke_sprite = nil
local FOLLOWER_FLAGS = EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_CHARM | EntityFlag.FLAG_PERSISTENT

local function ensure_debt_cross_sprite()
	if debt_cross_sprite and debt_cross_sprite.GetFilename then
		return debt_cross_sprite
	end
	local spr = Sprite()
	local ok = pcall(function()
		spr:Load(item.DEBT_CROSS_ANM2, true)
		spr:Play("Idle", true)
	end)
	if ok then
		debt_cross_sprite = spr
	end
	return debt_cross_sprite
end

local function ensure_debt_smoke_sprite()
	if debt_smoke_sprite and debt_smoke_sprite.GetFilename then
		return debt_smoke_sprite
	end
	local spr = Sprite()
	local ok = pcall(function()
		spr:Load(item.DEBT_SMOKE_ANM2, true)
		spr:Play("Idle", true)
	end)
	if ok then
		debt_smoke_sprite = spr
	end
	return debt_smoke_sprite
end

-- ----- pact (runtime only) -----
-- Ownership is OwnerIndex (__Index), NOT "player entity is alive".
-- Queries never clear_pact; stale epochs are simply ignored.
-- Do NOT use auxi.getenemies() here — it excludes FLAG_FRIENDLY followers.

local function clear_pact(ent)
	if not ent then return end
	local d = ent:GetData()
	d[item.own_key.."Seeded"] = nil
	d[item.own_key.."player"] = nil
	d[item.own_key.."OwnerIndex"] = nil
	d[item.own_key.."PactFollower"] = nil
	d[item.own_key.."PactEpoch"] = nil
	d.devil_seed_to_render = nil
	-- Do not clear FRIENDLY / CHARM / PERSISTENT.
end

local function ensure_follower_flags(ent)
	if not ent then return end
	ent:AddEntityFlags(FOLLOWER_FLAGS)
end

local function can_receive_pact(ent)
	local npc = ent and ent:ToNPC()
	if not npc then return false end
	if not npc:IsVulnerableEnemy() then return false end
	if not npc:IsActiveEnemy() then return false end
	return true
end

--- Vulnerable active NPCs including Friendly (pact candidates).
local function get_contract_npcs()
	local ret = {}
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		local npc = ent:ToNPC()
		if npc and npc:IsVulnerableEnemy() and npc:IsActiveEnemy() then
			ret[#ret + 1] = npc
		end
	end
	return ret
end

local function find_player_by_owner_index(owner_idx)
	if owner_idx == nil then return nil end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:GetData().__Index == owner_idx then
			-- Intentionally no Exists/IsDead gate: PRE_PLAYER_KILL needs dead owners.
			return player
		end
	end
	return nil
end

local function migrate_owner_index(d)
	local idx = d[item.own_key.."OwnerIndex"]
	if idx ~= nil then return idx end
	local raw = d[item.own_key.."player"]
	if not raw then return nil end
	local pl = raw.ToPlayer and raw:ToPlayer() or nil
	if not pl then return nil end
	idx = pl:GetData().__Index
	if idx ~= nil then
		d[item.own_key.."OwnerIndex"] = idx
	end
	return idx
end

--- Query only: Seeded + current epoch + OwnerIndex. No clear_pact side effects.
local function pact_owner_index(ent)
	if not ent then return nil end
	local d = ent:GetData()
	if d[item.own_key.."Seeded"] ~= true then return nil end
	if d[item.own_key.."PactEpoch"] ~= item.pact_epoch then return nil end
	return migrate_owner_index(d)
end

local function is_same_pact_player(ent, player)
	if not player then return false end
	local idx = player:GetData().__Index
	return idx ~= nil and pact_owner_index(ent) == idx
end

--- Resolve Player for VFX / debt only. Dead players still resolve.
local function pact_player_of(ent)
	local idx = pact_owner_index(ent)
	if idx == nil then return nil end
	return find_player_by_owner_index(idx)
end

local function bind_pact_owner(d, player)
	d[item.own_key.."Seeded"] = true
	d[item.own_key.."player"] = player
	d[item.own_key.."OwnerIndex"] = player:GetData().__Index
	d[item.own_key.."PactEpoch"] = item.pact_epoch
end

local function is_hostile_pact(ent, player)
	if not is_same_pact_player(ent, player) then return false end
	local d = ent:GetData()
	if d[item.own_key.."PactFollower"] then return false end
	if ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return false end
	return true
end

local function is_follower_pact(ent, player)
	if not is_same_pact_player(ent, player) then return false end
	local d = ent:GetData()
	if not d[item.own_key.."PactFollower"] then return false end
	if not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return false end
	return true
end

local function find_nearest_matching_pact(player, predicate)
	if not player then return nil end
	local best, best_dist = nil, nil
	for _, v in ipairs(get_contract_npcs()) do
		if predicate(v, player) then
			local dist = player.Position:Distance(v.Position)
			if not best_dist or dist < best_dist then
				best = v
				best_dist = dist
			end
		end
	end
	return best
end

function item.find_nearest_hostile_pact(player)
	return find_nearest_matching_pact(player, is_hostile_pact)
end

function item.find_nearest_follower_pact(player)
	return find_nearest_matching_pact(player, is_follower_pact)
end

-- Compat aliases.
function item.find_hostile_pact_body(player)
	return item.find_nearest_hostile_pact(player)
end

function item.find_follower_pact_body(player)
	return item.find_nearest_follower_pact(player)
end

function item.find_revive_body(player)
	return item.find_nearest_hostile_pact(player) or item.find_nearest_follower_pact(player)
end

-- Compatibility alias used by older debug callers.
function item.find_a_seeded_ent(player)
	return item.find_revive_body(player)
end

function item.has_active_pact(player)
	return item.find_a_seeded_ent(player) ~= nil
end

function item.count_active_pacts(player)
	local n = 0
	for _, v in ipairs(get_contract_npcs()) do
		if is_same_pact_player(v, player) then
			n = n + 1
		end
	end
	return n
end

function item.count_hostile_pacts(player)
	local n = 0
	for _, v in ipairs(get_contract_npcs()) do
		if is_hostile_pact(v, player) then
			n = n + 1
		end
	end
	return n
end

function item.count_pact_followers(player)
	local n = 0
	for _, v in ipairs(get_contract_npcs()) do
		if is_follower_pact(v, player) then
			n = n + 1
		end
	end
	return n
end

--- Apply devil seed / locust pact. Friendly hits become followers if under cap.
local function try_apply_pact(player, ent)
	if not player or not can_receive_pact(ent) then return false end
	local d = ent:GetData()
	local already_mine = is_same_pact_player(ent, player)
	local friendly = ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)

	if already_mine then
		-- Already-signed target later made Friendly by another system:
		-- re-hit tries to register as formal PactFollower (if slot free).
		-- Do not clear Seeded/OwnerIndex when the follower cap is full.
		if friendly and not d[item.own_key.."PactFollower"] then
			if item.count_pact_followers(player) >= item.MAX_PACT_FOLLOWERS then
				return false
			end
			d[item.own_key.."PactFollower"] = true
			ensure_follower_flags(ent)
		end
		return true
	end

	if friendly then
		if item.count_pact_followers(player) >= item.MAX_PACT_FOLLOWERS then
			return false
		end
		bind_pact_owner(d, player)
		d[item.own_key.."PactFollower"] = true
		ensure_follower_flags(ent)
		return true
	end

	-- Hostile: unlimited temporary pacts.
	bind_pact_owner(d, player)
	d[item.own_key.."PactFollower"] = nil
	return true
end

-- ----- debt (run save) -----

local function debt_root()
	save.elses[item.own_key.."Debt"] = save.elses[item.own_key.."Debt"] or {}
	return save.elses[item.own_key.."Debt"]
end

local function player_debt_index(player)
	if not player then return nil end
	return player:GetData().__Index
end

local function roll_debt_interval(player)
	local rng = player:GetCollectibleRNG(item.entity)
	local span = item.DEBT_INTERVAL_MAX - item.DEBT_INTERVAL_MIN
	local a = rng:RandomInt(span + 1)
	local b = rng:RandomInt(span + 1)
	return item.DEBT_INTERVAL_MIN + math.floor((a + b) * 0.5)
end

local function roll_debt_warning(player)
	local rng = player:GetCollectibleRNG(item.entity)
	local span = item.DEBT_WARNING_MAX - item.DEBT_WARNING_MIN
	return item.DEBT_WARNING_MIN + rng:RandomInt(span + 1)
end

local function reset_debt_timer(player, st)
	st.timer = roll_debt_interval(player)
	st.warning_threshold = roll_debt_warning(player)
	st.warning_started = false
	st.warning_final = false
	st.collect_pending = false
	st.collect_delay = 0
	st.collecting = false
	st.last_game_frame = Game():GetFrameCount()
end

-- Continue must keep timer / warning_threshold; only fill missing fields.
local function ensure_debt_timer_fields(player, st)
	if st.timer == nil then
		st.timer = roll_debt_interval(player)
	end
	if st.warning_threshold == nil then
		st.warning_threshold = roll_debt_warning(player)
	end
	if st.warning_started == nil then
		st.warning_started = false
	end
	if st.warning_final == nil then
		st.warning_final = false
	end
	if st.collect_pending == nil then
		st.collect_pending = false
	end
	if st.collect_delay == nil then
		st.collect_delay = 0
	end
	if st.collecting == nil then
		st.collecting = false
	end
	if st.last_game_frame == nil then
		st.last_game_frame = Game():GetFrameCount()
	end
end

local function get_debt_state(player)
	local idx = player_debt_index(player)
	if idx == nil then return nil end
	local root = debt_root()
	local st = root[idx]
	if type(st) ~= "table" then
		st = {
			active = false,
			hearts = 0,
			timer = nil,
			warning_threshold = nil,
			warning_started = false,
			warning_final = false,
			collect_pending = false,
			collect_delay = 0,
			collecting = false,
			last_game_frame = nil,
		}
		root[idx] = st
	end
	return st
end

local function debt_warning_phase(st)
	if not st or not st.active or (st.hearts or 0) <= 0 then
		return "none"
	end
	if st.collect_pending then
		return "collect"
	end
	local timer = st.timer or 0
	local warn = st.warning_threshold or item.DEBT_WARNING_MIN
	if timer <= item.DEBT_FINAL_WARNING then
		return "final"
	end
	if timer <= warn then
		return "warning"
	end
	return "normal"
end

local function increase_debt(player)
	local st = get_debt_state(player)
	if not st then return end
	st.active = true
	st.hearts = (st.hearts or 0) + 1
	reset_debt_timer(player, st)
end

-- Seija: skip debt +1, but still clear collecting and restart timer if debt already active.
local function finish_debt_after_pact_revive(player)
	local st = get_debt_state(player)
	if not st then return end
	if item.is_seija_buff(player) then
		st.collecting = false
		if st.active and (st.hearts or 0) > 0 then
			reset_debt_timer(player, st)
		end
		return
	end
	increase_debt(player)
end

local function collect_debt(player, hearts)
	if not player or not player:Exists() then return end
	local st = get_debt_state(player)
	if not st then return end
	hearts = math.max(1, math.floor(tonumber(hearts) or 1))
	st.collecting = true
	player:TakeDamage(hearts * 2, item.DEBT_DAMAGE_FLAGS, EntityRef(player), 0)
	-- Pact revive owns the next timer via finish_debt_after_pact_revive; otherwise reset here once.
	local d = player:GetData()
	if st.collecting
		and not d[item.own_key.."has_revive"]
		and not d[revive_holder.own_key.."effect"]
	then
		st.collecting = false
		if st.active and (st.hearts or 0) > 0 then
			reset_debt_timer(player, st)
		end
	end
end

local function tick_debt(player)
	local st = get_debt_state(player)
	if not st or not st.active then return end
	ensure_debt_timer_fields(player, st)
	local d = player:GetData()
	local gf = Game():GetFrameCount()
	if d[revive_holder.own_key.."effect"] then
		st.last_game_frame = gf
		return
	end
	local last = st.last_game_frame
	if type(last) ~= "number" then
		st.last_game_frame = gf
		return
	end
	if gf <= last then return end
	local delta = gf - last
	st.last_game_frame = gf

	if st.collect_pending then
		st.collect_delay = (st.collect_delay or 0) - delta
		if st.collect_delay <= 0 then
			st.collect_pending = false
			collect_debt(player, st.hearts or 1)
		end
		return
	end

	st.timer = math.max(0, (st.timer or 0) - delta)
	local phase = debt_warning_phase(st)
	st.warning_started = (phase == "warning" or phase == "final" or phase == "collect")
	st.warning_final = (phase == "final" or phase == "collect")
	if st.timer <= 0 then
		st.collect_pending = true
		st.collect_delay = item.DEBT_COLLECT_DELAY
		st.warning_started = true
		st.warning_final = true
	end
end

-- ----- costume / belial -----

function item.recheck_costume(player)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."Costume"] = save.elses[item.own_key.."Costume"] or {}
	for i = 1, math.min(save.elses[item.own_key.."Costume"][idx] or 0, #item.costumes) do
		player:AddNullCostume(item.costumes[i])
	end
end

local function advance_costume(player)
	local d = player:GetData()
	local idx = d.__Index
	if not idx then return end
	save.elses[item.own_key.."Costume"] = save.elses[item.own_key.."Costume"] or {}
	save.elses[item.own_key.."Costume"][idx] = math.min(#item.costumes, (save.elses[item.own_key.."Costume"][idx] or 0) + 1)
	item.recheck_costume(player)
end

local function consume_virtue_wisp(player)
	local wisps = auxi.getothers(Isaac.GetRoomEntities(), 3, FamiliarVariant.WISP, item.entity)
	if #wisps <= 0 then return false end
	wisps[1]:Remove()
	return true
end

local function apply_belial_room_buff(player)
	if not auxi.should_do_belial(player) then return end
	local d = player:GetData()
	d[item.own_key.."belial_dmg"] = item.BELIAL_ROOM_DAMAGE
	player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
	player:GetData().should_evaluate_on_update_once = true
end

-- ----- VFX -----

local function tint_smoke_effect(fx, scale, alpha)
	if not fx then return end
	fx = fx:ToEffect() or fx
	local col = Color(0.12, 0.08, 0.14, alpha or 1, 0.02, 0, 0.04)
	if col.SetColorize then
		col:SetColorize(0.08, 0.04, 0.1, 1)
	end
	pcall(function()
		fx:SetColor(col, 40, 1, false, false)
	end)
	local s = fx:GetSprite()
	if s then
		s.Color = col
	end
	if scale then
		fx.SpriteScale = Vector(scale, scale)
	end
	local life = 20
	if fx.LifeSpan ~= nil then fx.LifeSpan = life end
	if fx.Timeout ~= nil then fx.Timeout = life end
	fx.DepthOffset = -12
end

local function spawn_contract_smoke(pos, strong)
	if not pos then return end
	local poof_scale = strong and 1.45 or 0.9
	local poof = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, pos, Vector.Zero, nil)
	tint_smoke_effect(poof, poof_scale, strong and 1 or 0.85)
	if strong then
		local dust = Isaac.Spawn(
			EntityType.ENTITY_EFFECT,
			EffectVariant.DUST_CLOUD,
			0,
			pos + Vector(0, -3),
			Vector(0, -0.35),
			nil
		)
		tint_smoke_effect(dust, 1.05, 0.9)
		pcall(function()
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF, 0.7, 0.95, false, 0, 1)
		end)
	end
end

local function find_host_return_position(player, ent)
	local room = Game():GetRoom()
	local rng = player:GetCollectibleRNG(item.entity)
	local ang = rng:RandomInt(360)
	local wanted = player.Position + Vector.FromAngle(ang):Resized(item.HOST_RETURN_RADIUS)
	if room.FindFreeTilePosition then
		return room:FindFreeTilePosition(wanted, 20)
	end
	return wanted
end

-- intensity: 1 normal, 1.5 warning (player feet), 2 final.
-- final_warning: stronger red pulse on all seeded targets.
local function render_pact_effect(anchor, _offset, intensity, final_warning)
	if not anchor or not anchor:Exists() then return end
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	intensity = intensity or 1.0
	final_warning = final_warning == true
	local d = anchor:GetData()
	if d.devil_seed_to_render == nil then d.devil_seed_to_render = {} end
	for u, v in pairs(d.devil_seed_to_render) do
		if v.id <= 4 then
			local s = v.sprite
			if s:IsFinished(v.now_play) then
				table.remove(d.devil_seed_to_render, u)
			else
				s:Render(Isaac.WorldToScreen(anchor.Position + v.offset), Vector(0, 0), Vector(0, 0))
				if Game():GetFrameCount() % 2 == 1 then
					if v.color then
						s.Color = auxi.AddColor(s.Color, v.color, 0.9, 0.1)
					end
					s:Update()
				end
			end
		end
	end
	for u, v in pairs(d.devil_seed_to_render) do
		if v.id > 4 then
			local s = v.sprite
			if s:IsFinished(v.now_play) then
				table.remove(d.devil_seed_to_render, u)
			else
				s:Render(Isaac.WorldToScreen(anchor.Position + v.offset), Vector(0, 0), Vector(0, 0))
				if Game():GetFrameCount() % 2 == 1 then
					if v.color then
						s.Color = auxi.AddColor(s.Color, v.color, 0.9, 0.1)
					end
					s:Update()
				end
			end
		end
	end
	-- Warning/final: spawn every render; normal: every other game frame.
	-- Note: (n % 1 == 1) is never true in Lua, so do not use gate=1 with modulo.
	local do_spawn = (intensity >= 1.5 or final_warning)
		or (Game():GetFrameCount() % 2 == 1)
	if do_spawn then
		local n_s = Sprite()
		n_s:Load("gfx/mimics/Devil_s_Heart/Dark_tentacle.anm2", true)
		local name = "Overlay"
		local rnd = math.random(10)
		local red_boost = 0.2 + math.random(100) / 100 * 0.3
		if final_warning then
			red_boost = 0.45 + math.random(100) / 100 * 0.4
		end
		local scale_hi = math.floor(160 * intensity)
		local scale_lo = math.floor(100 * math.min(intensity, 1.4))
		if rnd > 4 then
			name = name .. tostring(rnd)
			n_s:Play(name, true)
			n_s.PlaybackSpeed = math.random(30, 100) / 100
			n_s.FlipX = (math.random(2) > 1 and true or false)
			local offset = Vector(0, 0)
			if rnd > 4 then
				offset.X = math.random(8) * (math.random(2) > 1 and -1 or 1)
				n_s.PlaybackSpeed = math.random(30, 100) / 100
				local scale = math.random(scale_lo, math.max(scale_lo, scale_hi)) / 100
				n_s.Scale = Vector(scale, scale)
				n_s.Color = Color(1, 1, 1, 1, red_boost, 0, 0)
			else
				offset.X = math.random(10) * (math.random(2) > 1 and -1 or 1)
				local scale = math.random(70, math.max(70, math.floor(110 * intensity))) / 100
				n_s.Scale = Vector(scale, scale)
			end
			local tab = {sprite = n_s, now_play = name, offset = offset, id = rnd}
			if rnd > 4 then
				tab.color = Color(1, 1, 1, 1, 0, 0, 0)
			end
			table.insert(d.devil_seed_to_render, tab)
		end
	end
end

local function render_debt_crosses(position, spriteScale, hearts, phase)
	local spr = ensure_debt_cross_sprite()
	if not spr or not hearts or hearts <= 0 then return end
	if phase == "collect" then return end
	local scale = tonumber(spriteScale) or 1
	local spacing = item.DEBT_CROSS_SPACING * scale
	local frame = Game():GetFrameCount()
	local period = 30
	local alpha_lo, alpha_hi = 0.35, 1.0
	local jitter = 0
	local tint_r, tint_g, tint_b = 1, 1, 1
	local off_r, off_g, off_b = 0, 0, 0
	if phase == "warning" then
		period = 10
		alpha_lo, alpha_hi = 0.2, 1.0
		jitter = 0.75
	elseif phase == "final" then
		period = 6
		alpha_lo, alpha_hi = 0.15, 1.0
		jitter = 1.25
		tint_r, tint_g, tint_b = 1, 0.55, 0.55
		off_r, off_b = 0.12, 0.05
	end
	spr.Scale = Vector(scale, scale)
	for i = 0, hearts - 1 do
		local alpha
		if phase == "final" then
			local sync = (frame % period) / period
			alpha = alpha_lo + (alpha_hi - alpha_lo) * (0.5 + 0.5 * math.sin(sync * math.pi * 2))
		else
			local wave = (frame + i * 4) % period
			alpha = alpha_lo + (alpha_hi - alpha_lo) * (0.5 + 0.5 * math.sin((wave / period) * math.pi * 2))
		end
		local jx = 0
		if jitter > 0 then
			jx = math.sin((frame + i * 7) * 0.9) * jitter
		end
		spr.Color = Color(tint_r, tint_g, tint_b, alpha, off_r, off_g, off_b)
		local pos = position + Vector(i * spacing + jx, 0)
		spr:Render(pos, Vector.Zero, Vector.Zero)
	end
end

local function render_debt_warning_smoke(position, spriteScale, st, phase)
	if not st or not st.warning_started then return end
	if phase ~= "warning" and phase ~= "final" and phase ~= "collect" then return end
	local spr = ensure_debt_smoke_sprite()
	if not spr then return end
	local scale = tonumber(spriteScale) or 1
	local frame = Game():GetFrameCount()
	local base_alpha = (phase == "final" or phase == "collect") and 0.7 or 0.4
	local pull = (phase == "final" or phase == "collect") and 0.55 or 0.0
	local offsets = {
		Vector(-10, -2),
		Vector(8, 1),
		Vector(-2, 4),
	}
	for i, off in ipairs(offsets) do
		local toward = Vector(0, 0) - off
		local pos = position + off * (1 - pull) + toward * pull * 0.35
		local wobble = math.sin((frame + i * 11) * 0.15) * 1.5
		local alpha = base_alpha * (0.75 + 0.25 * math.sin((frame + i * 5) * 0.2))
		local s = 0.85 + (i % 3) * 0.12
		if phase == "collect" then
			local frac = math.max(0, (st.collect_delay or 0) / item.DEBT_COLLECT_DELAY)
			s = s * (0.4 + 0.6 * frac)
			alpha = alpha * 1.2
		end
		spr.Scale = Vector(scale * s, scale * s)
		spr.Color = Color(1, 1, 1, alpha, 0, 0, 0)
		spr:Render(Vector(pos.X + wobble, pos.Y), Vector.Zero, Vector.Zero)
	end
	spr:Update()
end

-- ----- settlements -----

function item.is_seija_buff(player)
	if item._force_seija == true then
		return true
	end
	return player and auxi.should_do_Seija(player, true) == true
end

function item.debug_set_force_seija(value)
	item._force_seija = value == true
end

function item.debug_get_force_seija()
	return item._force_seija == true
end

local function follower_pays_for_player(player, ent)
	-- Spare-life stock: always Kill. No Book of Virtues host-save.
	clear_pact(ent)
	player.Position = ent.Position
	spawn_contract_smoke(ent.Position, true)
	advance_costume(player)
	apply_belial_room_buff(player)
	ent:Kill()
	finish_debt_after_pact_revive(player)
end

local function host_pays_for_player(player, ent)
	local d = ent:GetData()
	local was_follower = d[item.own_key.."PactFollower"] == true
	if was_follower then
		follower_pays_for_player(player, ent)
		return
	end

	clear_pact(ent)
	player.Position = ent.Position
	advance_costume(player)
	apply_belial_room_buff(player)

	if ent:IsBoss() then
		local pay = math.max(1, ent.MaxHitPoints * item.BOSS_PAY_FRAC)
		if consume_virtue_wisp(player) then
			pay = pay * 0.5
		end
		ent:TakeDamage(pay, DamageFlag.DAMAGE_IGNORE_ARMOR | DamageFlag.DAMAGE_NOKILL, EntityRef(player), 0)
	else
		if consume_virtue_wisp(player) then
			local pay = math.max(1, ent.HitPoints * 0.65)
			ent:TakeDamage(pay, DamageFlag.DAMAGE_IGNORE_ARMOR | DamageFlag.DAMAGE_NOKILL, EntityRef(player), 0)
			ent.HitPoints = math.max(1, ent.HitPoints)
		else
			ent:Kill()
		end
	end

	finish_debt_after_pact_revive(player)
end

--- First lethal hit on a hostile pact NPC: convert into permanent follower if under cap.
local function try_convert_host_to_follower(player, ent)
	if not player or not ent then return false end
	local d = ent:GetData()

	-- Already a pact follower: second death is final.
	if d[item.own_key.."PactFollower"] then
		clear_pact(ent)
		return false
	end

	-- Bosses stay temporary sacrifice bodies only.
	if ent:IsBoss() then
		clear_pact(ent)
		return false
	end

	if item.count_pact_followers(player) >= item.MAX_PACT_FOLLOWERS then
		clear_pact(ent)
		return false
	end

	local old_pos = Vector(ent.Position.X, ent.Position.Y)
	spawn_contract_smoke(old_pos, true)
	ent.Position = find_host_return_position(player, ent)
	ent.Velocity = Vector.Zero
	local hp = math.max(1, ent.MaxHitPoints * item.FOLLOWER_CONVERT_HP_FRAC)
	ent.HitPoints = math.min(ent.MaxHitPoints, hp)
	ensure_follower_flags(ent)
	-- Keep the same contract owner; do not re-derive identity.
	d[item.own_key.."Seeded"] = true
	d[item.own_key.."PactFollower"] = true
	d[item.own_key.."player"] = player
	d[item.own_key.."OwnerIndex"] = d[item.own_key.."OwnerIndex"] or player:GetData().__Index
	d[item.own_key.."PactEpoch"] = item.pact_epoch
	spawn_contract_smoke(ent.Position, false)
	return true
end

-- ----- callbacks -----

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		item.pact_epoch = (item.pact_epoch or 0) + 1
		if not continue then
			save.elses[item.own_key.."Costume"] = {}
			save.elses[item.own_key.."Debt"] = {}
		end
		save.elses[item.own_key.."Costume"] = save.elses[item.own_key.."Costume"] or {}
		save.elses[item.own_key.."Debt"] = save.elses[item.own_key.."Debt"] or {}
		-- Continue keeps Debt; epoch bump invalidates any leftover runtime pacts.
		-- FRIENDLY / PERSISTENT engine flags on followers are intentionally untouched.
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_ITEM,
	params = item.entity,
	Function = function(_, coltyp, rng, player, useFlags, activeSlot, customVarData)
		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		else
			local d = player:GetData()
			if d.is_holding_D_S_H_item ~= true then
				player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
				d.is_holding_D_S_H_item = true
				return {Discharge = false}
			else
				player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
				d.is_holding_D_S_H_item = false
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		local d = player:GetData()
		local room = Game():GetRoom()
		tick_debt(player)
		if d.is_holding_D_S_H_item == true then
			if player:IsHoldingItem() == false then
				d.is_holding_D_S_H_item = false
			else
				local dir = 0
				local ctrlid = player.ControllerIndex
				for i = 4, 7 do
					if (Input.IsActionPressed(i, ctrlid) and input_holder.actionsData[tostring(ctrlid)] and input_holder.actionsData[tostring(ctrlid)][i] and input_holder.actionsData[tostring(ctrlid)][i].ActionHoldTime and input_holder.actionsData[tostring(ctrlid)][i].ActionHoldTime == 1) then
						dir = i
					end
				end
				if dir > 0 then
					local vel = Vector(0, 0)
					if room:IsMirrorWorld() == true and (dir == 4 or dir == 5) then dir = 9 - dir end
					if dir == 4 then vel = vel + Vector(-1, 0)
					elseif dir == 5 then vel = vel + Vector(1, 0)
					elseif dir == 6 then vel = vel + Vector(0, -1)
					elseif dir == 7 then vel = vel + Vector(0, 1) end
					player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
					d.is_holding_D_S_H_item = false
					local q = Isaac.Spawn(2, 1, 0, player.Position + player.Velocity * 0.2 + vel * player.ShotSpeed * 5, vel * player.ShotSpeed * 10 + player.Velocity * 0.3, player):ToTear()
					local s = q:GetSprite()
					s:Load("gfx/mimics/Devil_s_Heart/Devil_s_Heart_Tear.anm2", true)
					s:Play("Idle", true)
					q.CollisionDamage = 0
					local d2 = q:GetData()
					d2[item.own_key.."Seeded"] = true
					d2[item.own_key.."player"] = player
				end
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_TEAR_UPDATE,
	params = nil,
	Function = function(_, ent)
		local d = ent:GetData()
		if d[item.own_key.."Seeded"] and d[item.own_key.."Seeded"] == true then
			local s = ent:GetSprite()
			s.Rotation = ent.Velocity:GetAngleDegrees()
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION,
	params = nil,
	Function = function(_, ent, col, low)
		local d = ent:GetData()
		if d[item.own_key.."Seeded"] then
			local player = d[item.own_key.."player"]
			if player and player:ToPlayer() then
				player = player:ToPlayer()
			end
			if try_apply_pact(player, col) then
				d[item.own_key.."Seeded"] = nil
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_RENDER,
	params = nil,
	Function = function(_, ent, offset)
		local owner = pact_player_of(ent)
		if not owner then return end
		local st = get_debt_state(owner)
		local phase = debt_warning_phase(st)
		-- Warning amplifies player feet only; final pulses all seeded targets.
		local final = (phase == "final" or phase == "collect")
		local intensity = final and 2.0 or 1.0
		render_pact_effect(ent, offset, intensity, final)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_RENDER,
	params = nil,
	Function = function(_, player, offset)
		if not item.has_active_pact(player) then return end
		local st = get_debt_state(player)
		local phase = debt_warning_phase(st)
		local intensity = 1.0
		if phase == "warning" then
			intensity = 1.5
		elseif phase == "final" or phase == "collect" then
			intensity = 2.0
		end
		render_pact_effect(player, offset, intensity, phase == "final" or phase == "collect")
	end,
})

if REPENTOGON and ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS,
		params = nil,
		Function = function(_, offset, heartsSprite, position, spriteScale, player)
			if not auxi.can_render_health_hud() then return end
			local st = get_debt_state(player)
			if not st or not st.active or (st.hearts or 0) <= 0 then return end
			local phase = debt_warning_phase(st)
			render_debt_warning_smoke(position, spriteScale, st, phase)
			render_debt_crosses(position, spriteScale, st.hearts, phase)
		end,
	})
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_PLAYER_KILL,
	params = nil,
	Function = function(_, player)
		if player:WillPlayerRevive() then return end
		local d = player:GetData()
		if d[item.own_key.."has_revive"] then return end
		local hostile_before = item.count_hostile_pacts(player)
		local follower_before = item.count_pact_followers(player)
		local reviver = item.find_revive_body(player)
		if item._probe_on_kill_query then
			item._probe_on_kill_query(player, {
				player_dead = player:IsDead() and true or false,
				hostile_pacts_before = hostile_before,
				follower_pacts_before = follower_before,
				total_pacts_before = hostile_before + follower_before,
				revive_body_ptr = reviver and GetPtrHash(reviver) or nil,
				revive_is_follower = reviver and reviver:GetData()[item.own_key.."PactFollower"] and true or false,
			})
		end
		if not reviver then return end
		local ret = {
			should_revive = true,
			on_revive = function(p)
				local pd = p:GetData()
				-- Fallback only if the locked body vanished; not for owner-invalid.
				if auxi.check_all_exists(pd[item.own_key.."revive_ent"]) == false then
					pd[item.own_key.."revive_ent"] = item.find_revive_body(p)
				end
				local ent = pd[item.own_key.."revive_ent"]
				if auxi.check_all_exists(ent) then
					host_pays_for_player(p, ent)
				else
					p:Kill()
					pd[item.own_key.."has_revive"] = nil
					pd[item.own_key.."revive_ent"] = nil
					return
				end
				if item._probe_on_revive_query then
					local h = item.count_hostile_pacts(p)
					local f = item.count_pact_followers(p)
					item._probe_on_revive_query(p, {
						hostile_pacts_after = h,
						follower_pacts_after = f,
						total_pacts_after = h + f,
					})
				end
				pd[item.own_key.."has_revive"] = nil
				pd[item.own_key.."revive_ent"] = nil
			end,
		}
		d[item.own_key.."revive_ent"] = reviver
		d[item.own_key.."has_revive"] = true
		return ret
	end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = nil,
	Function = function(_, ent, amount, flags, source, countdown)
		if not ent or not ent:ToNPC() then return end
		local player = pact_player_of(ent)
		if not player then return end
		if not enemy_death_guard.can_intercept_current_death(ent, amount, flags) then
			return
		end
		if try_convert_host_to_follower(player, ent) then
			return false
		end
		-- Conversion rejected (follower / boss / cap): pact cleared; allow death.
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_EVALUATE_CACHE,
	params = nil,
	Function = function(_, player, cacheFlag)
		if cacheFlag ~= CacheFlag.CACHE_DAMAGE then return end
		local bonus = player:GetData()[item.own_key.."belial_dmg"]
		if bonus and bonus > 0 then
			player.Damage = player.Damage + bonus * auxi.get_damage_multiplier(player)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and player:GetData()[item.own_key.."belial_dmg"] then
				player:GetData()[item.own_key.."belial_dmg"] = nil
				player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
				player:GetData().should_evaluate_on_update_once = true
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_INIT,
	params = nil,
	Function = function(_, player)
		local d = player:GetData()
		local idx = d.__Index
		if idx and Game():GetFrameCount() > 2 then
			item.recheck_costume(player)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_ITEM,
	params = nil,
	Function = function(_, collid, itemRng, player, useFlags, activeSlot, customVarData)
		if collid == 283 or collid == 284 or collid == 703 then
			item.recheck_costume(player)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION,
	params = FamiliarVariant.ABYSS_LOCUST,
	Function = function(_, ent, col, low)
		if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
			local player = auxi.check_spawner_player(ent)
			if ent.State == -1 then
				try_apply_pact(player, col)
			end
		end
	end,
})

-- ----- debug / probe helpers -----

function item.debug_get_debt(player)
	local st = get_debt_state(player)
	if not st then return nil end
	local phase = debt_warning_phase(st)
	return {
		active = st.active and true or false,
		hearts = st.hearts or 0,
		timer = st.timer or 0,
		warning_threshold = st.warning_threshold or 0,
		warning_state = phase,
		warning_started = st.warning_started and true or false,
		warning_final = st.warning_final and true or false,
		collect_pending = st.collect_pending and true or false,
		collect_delay = st.collect_delay or 0,
		total_pacts = item.count_active_pacts(player),
		hostile_pacts = item.count_hostile_pacts(player),
		follower_pacts = item.count_pact_followers(player),
		pact_count = item.count_active_pacts(player),
	}
end

function item.debug_set_debt_hearts(player, hearts)
	local st = get_debt_state(player)
	if not st then return end
	hearts = math.max(0, math.floor(tonumber(hearts) or 0))
	st.hearts = hearts
	st.active = hearts > 0
	if st.active then
		ensure_debt_timer_fields(player, st)
	end
end

function item.debug_adjust_debt_hearts(player, delta)
	local st = get_debt_state(player)
	if not st then return end
	item.debug_set_debt_hearts(player, (st.hearts or 0) + (tonumber(delta) or 0))
end

function item.debug_set_debt_timer(player, frames)
	local st = get_debt_state(player)
	if not st then return end
	ensure_debt_timer_fields(player, st)
	st.timer = math.max(0, math.floor(tonumber(frames) or 0))
	st.collect_pending = false
	st.last_game_frame = Game():GetFrameCount()
	if (st.hearts or 0) > 0 then
		st.active = true
	end
end

function item.debug_fast_warning(player)
	local st = get_debt_state(player)
	if not st then return end
	if (st.hearts or 0) <= 0 then
		st.hearts = 1
		st.active = true
	end
	ensure_debt_timer_fields(player, st)
	st.timer = (st.warning_threshold or item.DEBT_WARNING_MIN) - 1
	st.collect_pending = false
	st.last_game_frame = Game():GetFrameCount()
end

function item.debug_fast_final(player)
	local st = get_debt_state(player)
	if not st then return end
	if (st.hearts or 0) <= 0 then
		st.hearts = 1
		st.active = true
	end
	ensure_debt_timer_fields(player, st)
	st.timer = item.DEBT_FINAL_WARNING - 1
	st.collect_pending = false
	st.last_game_frame = Game():GetFrameCount()
end

function item.debug_force_collect(player)
	local st = get_debt_state(player)
	if not st then return end
	if (st.hearts or 0) <= 0 then
		st.hearts = 1
		st.active = true
	end
	ensure_debt_timer_fields(player, st)
	st.timer = 1
	st.collect_pending = false
	st.last_game_frame = Game():GetFrameCount()
end

function item.debug_force_pact(player, ent)
	return try_apply_pact(player, ent)
end

function item.debug_convert_host(player)
	local host = item.find_nearest_hostile_pact(player)
	if not host then return false end
	return try_convert_host_to_follower(player, host)
end

function item.debug_kill_host(player)
	local body = item.find_revive_body(player)
	if not body then return false end
	clear_pact(body)
	body:Kill()
	return true
end

function item.debug_pact_snapshot(player)
	return {
		total_pacts = item.count_active_pacts(player),
		hostile_pacts = item.count_hostile_pacts(player),
		follower_pacts = item.count_pact_followers(player),
		revive_body = item.find_revive_body(player) and GetPtrHash(item.find_revive_body(player)) or nil,
		hostile_body = item.find_nearest_hostile_pact(player) and GetPtrHash(item.find_nearest_hostile_pact(player)) or nil,
		follower_body = item.find_nearest_follower_pact(player) and GetPtrHash(item.find_nearest_follower_pact(player)) or nil,
		pact_epoch = item.pact_epoch,
	}
end

function item.roll_debt_interval_public(player)
	return roll_debt_interval(player)
end

function item.debt_warning_phase_of(player)
	return debt_warning_phase(get_debt_state(player))
end

return item

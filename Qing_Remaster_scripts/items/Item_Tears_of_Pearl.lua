local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local tear_snapshot = require("Qing_Remaster_scripts.auxiliary.tear_snapshot")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")

local item = {
	myToCall = {},
	ToCall = {},
	post_ToCall = {},
	entity = enums.Items.Tears_of_Pearl,
	own_key = "Item_Tears_of_Pearl_",
	consumer_key = "pearl",
	-- Ludo 珍珠轮时长上限（POST_TEAR_UPDATE ≈ 30Hz）；新一轮到来也会先解绑
	pearl_ludo_ttl = 30,
}

local function player_has_pearl(player)
	return player and auxi.has_have_coll(player, item.entity)
end

--- Player inventory Pearl, OR Craft Attack whose recipe includes Tears of Pearl.
local function attack_can_use_pearl(player, attack, source)
	source = source or (attack and attack.source)
	if not player or not source then
		return false
	end
	if attack_holder.classifier.IsPlayerAttackSource(source) then
		return player_has_pearl(player)
	end
	return attack_holder.classifier.SourceCanConsume(source, item.consumer_key, player, attack)
end

local function craft_or_player_luck(player, attack, source)
	source = source or (attack and attack.source)
	local luck = (player and player.Luck) or 0
	if attack_holder.classifier.IsIndependentMimicSource(source) then
		local prof, fam = attack_holder.classifier.GetCraftProfileFromSource(source)
		local ok_air, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
		if ok_air and air and fam then
			luck = air.get_effective_luck(fam, prof)
		end
	end
	return luck
end

local function is_ludo_tear(ent)
	if not ent or not ent.TearFlags or not TearFlags or not TearFlags.TEAR_LUDOVICO then
		return false
	end
	return ent.TearFlags & TearFlags.TEAR_LUDOVICO == TearFlags.TEAR_LUDOVICO
end

--- 自定义 Pearl anm2 Load 后，同 Variant 的 ChangeVariant 会被跳过 → 贴图卡在珍珠上。
--- 强制变体往返重建原泪贴图；不回写 Height/Falling（Ludo 会坏）。
local function restore_pearl_visual(tear, snap)
	if not tear then return end
	local t = tear.ToTear and tear:ToTear() or tear

	local want = snap and snap.variant
	if want == nil then
		want = t.Variant
	end
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

	if type(snap) == "table" then
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
	end

	if t.ResetSpriteScale then
		pcall(function()
			t:ResetSpriteScale(true)
		end)
	end
	local ss = snap and snap.sprite_scale
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
	local spr = t:GetSprite()
	if spr and spr.LoadGraphics then
		pcall(function()
			spr:LoadGraphics()
		end)
	end
end

--- 原地珍珠化前快照；生成独立珍珠粒子时不写快照。
function item.fire_pearl_tear(ent, pos, vel, player)
	local q = ent or Isaac.Spawn(2, 0, 0, pos, vel, player):ToTear()
	if not q then return nil end
	if not ent and q.ToTear then
		q = q:ToTear() or q
	end
	local d = q:GetData()
	if ent and not d[item.own_key .. "pre_pearl_snap"] then
		d[item.own_key .. "pre_pearl_snap"] = tear_snapshot.capture(q)
	end
	local s2 = q:GetSprite()
	s2:Load("gfx/mimics/Tears_of_Pearl/Pearl_Tear.anm2", true)
	s2:Play("Idle", true)
	d.is_pearl_tear = true
	q.TearFlags = q.TearFlags & (~BitSet128(1 << 60, 0))
	return q
end

--- 轮末吐出的珍珠粒子：同高度/同速度，保留下落，落地后才进入滚地态
local function spawn_falling_pearl_particle(source, player)
	if not source then return nil end
	local src = source.ToTear and source:ToTear() or source
	local q = item.fire_pearl_tear(nil, src.Position, src.Velocity, player)
	if not q then return nil end
	if q.ToTear then
		q = q:ToTear() or q
	end
	q.Height = src.Height or -23
	-- 确保有下落过程，勿直接锁地
	local fall = tonumber(src.FallingSpeed) or 0
	if fall < 0.4 then
		fall = 0.8
	end
	q.FallingSpeed = fall
	local accel = tonumber(src.FallingAcceleration) or 0
	if accel < 0.4 then
		accel = 0.9
	end
	q.FallingAcceleration = accel
	if src.Scale then
		q.Scale = src.Scale
	end
	-- 禁止立刻 Pearl_state_2；等 Height > -5 再进滚地
	return q
end

--- 公开入口：轮末拆掉珍珠贴图还原，并吐出会先下落再滚地的粒子
function item.clear_pearl_tear(ent, player)
	if not ent then return false end
	local d = ent:GetData()
	if not d.is_pearl_tear then return false end

	player = player or auxi.check_spawner_player(ent)
	spawn_falling_pearl_particle(ent, player)

	local snap = d[item.own_key .. "pre_pearl_snap"]
	d.is_pearl_tear = nil
	d.Pearl_state_2 = nil
	d.Pearl_acce_del = nil
	d.pearl_bounce_counter = nil
	d[item.own_key .. "pre_pearl_snap"] = nil
	d[item.own_key .. "pearl_ttl"] = nil

	restore_pearl_visual(ent, snap)
	return true
end

local function sample_shot_dir(event)
	local dir = event and event.direction
	if dir and dir:Length() > 0.01 then return dir end
	local ent = event and event.member
	if ent and ent.Velocity and ent.Velocity:Length() > 0.01 then return ent.Velocity end
	return Vector(1, 0)
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_ATTACK_DPS_SAMPLE, params = nil,
Function = function(_, event)
	local player = event and event.player
	local ent = event and event.member
	local attack = event and event.attack
	local source = event and event.attack_source or (attack and attack.source)
	if not attack_can_use_pearl(player, attack, source) or not ent then return end
	local d = ent:GetData()
	-- 轮内已珍珠化：等 TTL 轮末解绑（DPS_SAMPLE 会连发，不能当轮界）
	if d.is_pearl_tear then return end
	if not auxi.check_rand(craft_or_player_luck(player, attack, source), 15, 5, 15) then return end

	local is_tear = ent.Type == EntityType.ENTITY_TEAR
	local ludo = is_tear and is_ludo_tear(ent)

	if is_tear then
		if ludo then
			-- 轮内：原地珍珠化；轮末由 TTL 解绑并吐下落粒子
			item.fire_pearl_tear(ent, nil, nil, player)
			d[item.own_key .. "pearl_ttl"] = item.pearl_ludo_ttl or 30
		elseif d.Dont_Remove then
			-- 不可原地换皮：直接吐会下落的珍珠粒子
			spawn_falling_pearl_particle(ent, player)
		else
			item.fire_pearl_tear(ent, nil, nil, player)
		end
		return
	end
	local tdir = sample_shot_dir(event):Normalized() * player.ShotSpeed * 10
	item.fire_pearl_tear(nil, event.position or ent.Position, tdir, player)
end,
})
table.insert(item.post_ToCall, #item.post_ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_, ent, col, low)
	local d = ent:GetData()
	if d.is_pearl_tear then
		d.pearl_bounce_counter = (d.pearl_bounce_counter or 0) + 1
	end
end,
})


table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_, ent)
	local d = ent:GetData()
	if not d.is_pearl_tear then return end

	-- Ludo：无新轮时 TTL 到期 → 轮末解绑
	if is_ludo_tear(ent) then
		local ttl = d[item.own_key .. "pearl_ttl"]
		if ttl ~= nil then
			ttl = (tonumber(ttl) or 0) - 1
			d[item.own_key .. "pearl_ttl"] = ttl
			if ttl <= 0 then
				item.clear_pearl_tear(ent, auxi.check_spawner_player(ent))
				return
			end
		end
		-- 轮内保持珍珠贴图，不落地滚（Ludo 主泪不进 Pearl_state_2）
		return
	end

	if d.Pearl_state_2 or ent.Height > -5 then
		d.Pearl_state_2 = true
		ent.TearFlags = ent.TearFlags & (~BitSet128(1 << 1, 0))
		ent.Height = -5
		ent.FallingSpeed = 0
		d.Pearl_acce_del = (d.Pearl_acce_del or 0.6) * 0.98 + 0.6 * 0.02
		ent.Velocity = ent.Velocity * d.Pearl_acce_del
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local dir = player.Position - ent.Position
			if dir:Length() < 20 then
				ent.Velocity = ent.Velocity - dir * 0.2 + player.Velocity * 0.4
				d.Pearl_acce_del = 1
			end
		end
		local n_entity = Isaac.GetRoomEntities()
		local n_proj = auxi.getothers(n_entity, 9)
		for u, v in pairs(n_proj) do
			if (d.pearl_bounce_counter or 0) < 5 and (v.Position - ent.Position):Length() < 20 then
				v = v:ToProjectile()
				local q = Isaac.Spawn(2, 0, 0, v.Position, -v.Velocity, nil):ToTear()
				local s2 = v:GetSprite()
				local s3 = q:GetSprite()
				s3:Load(s2:GetFilename(), true)
				s3:Play(s2:GetAnimation(), true)
				s3.Color = s2.Color
				s3.Scale = s2.Scale
				q.Height = v.Height
				q.FallingSpeed = v.FallingSpeed
				q.FallingAcceleration = v.FallingAccel
				local q2 = Isaac.Spawn(1000, 133, 0, ent.Position, Vector(0, 0), nil)
				d.pearl_bounce_counter = (d.pearl_bounce_counter or 0) + 1
				v:Remove()
			end
		end
		if (d.pearl_bounce_counter or 0) < 5 then
			ent.TearFlags = ent.TearFlags | BitSet128(1 << 19, 0)
		else
			ent.TearFlags = ent.TearFlags & (~BitSet128(1 << 19, 0))
		end
	end
end,
})

return item

-- 蓝图第一组·普通跟随与特效（推荐施工批次 3）
-- 范围：blueprint_familiar_batch_scope_v2.md §2–§4 可直接跟随项
-- 资源宝宝（第二组）与专属状态机难题另批；本文件先落地跟随/射击骨架。
local H = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Selector = require("Qing_Remaster_scripts.mimics.Familiar_Control_Selector")
local FollowerArbiter = require("Qing_Remaster_scripts.mimics.Familiar_Follower_Arbiter")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Follow_Extras_holder_",
}

local function register(variant, adapter)
	if adapter.supports_bffs == nil then adapter.supports_bffs = true end
	if adapter.supports_lullaby == nil then adapter.supports_lullaby = true end
	if adapter.supports_bender == nil then adapter.supports_bender = false end
	H.register_adapter(variant, adapter)
end

-- 387 Censer：链式软跟随 Flight（禁止 orbital 焊死）；减速光环中心=Flight
-- 范围见 blueprint_familiar_batch_scope_v2：跟随/环绕，光环以 Flight 为中心
register(FamiliarVariant.CENSER or 89, {
	name = "censer",
	extra_key = "censer",
	collectible = CollectibleType.COLLECTIBLE_CENSER or 387,
	no_fire = true,
	supports_bffs = false,
	supports_lullaby = false,
	control_mode = "full", -- 禁止 move_only：原版会 FollowParent 钉回玩家
	formation_priority = 500,
	update = function(_adapter, ctx)
		local air = ctx.air
		if not air then return end
		local center = air.Position
		local radius = 90
		local slow_mul = 0.55
		for _, npc in ipairs(Isaac.FindInRadius(center, radius, EntityPartition.ENEMY)) do
			if npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
				if npc.AddEntityFlags and EntityFlag.FLAG_SLOW then
					npc:AddEntityFlags(EntityFlag.FLAG_SLOW)
				end
			end
		end
		for _, ent in ipairs(Isaac.FindInRadius(center, radius, EntityPartition.BULLET)) do
			local proj = ent:ToProjectile()
			if proj and proj.Velocity and not proj:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
				local sp = proj.SpawnerEntity
				if not (sp and (sp:ToPlayer() or sp.Type == EntityType.ENTITY_FAMILIAR)) then
					proj.Velocity = proj.Velocity * slow_mul
				end
			end
		end
	end,
})

-- 430 Papa Fly：keep_vanilla_ai 保留射击；MoveDelay=0 退出玩家延迟队列；位移跟 Flight trail
register(FamiliarVariant.PAPA_FLY or 99, {
	name = "papa_fly",
	extra_key = "papa_fly",
	collectible = CollectibleType.COLLECTIBLE_PAPA_FLY or 430,
	no_fire = true,
	supports_bffs = true,
	supports_lullaby = true,
	keep_vanilla_ai = true,
	soft_rebind = true,
	exclude_from_formation = true,
	trail_follow = true,
	trail_priority = 100,
})

-- 431 Multidimensional Baby：保留原版弹幕复制；同上退出 MoveDelay 队列
register(FamiliarVariant.MULTIDIMENSIONAL_BABY or 101, {
	name = "multidimensional_baby",
	extra_key = "multidimensional_baby",
	collectible = CollectibleType.COLLECTIBLE_MULTIDIMENSIONAL_BABY or 431,
	no_fire = true,
	supports_bffs = false,
	supports_lullaby = false,
	keep_vanilla_ai = true,
	soft_rebind = true,
	exclude_from_formation = true,
	trail_follow = true,
	trail_priority = 200,
})

-- 467 Finger：已迁到 Craft_Orbital_Batch2（尖肋骨同款瞄准定位；只接管移动/朝向）

-- 普通跟随 + 原版 AI：保持脱离玩家 follower 链；AI 后 FollowPosition + 强 Velocity。
-- 不是 keep_vanilla_ai 的轨迹/原版 Orbit 特殊路径。
local function register_move_ai(variant, opts)
	register(variant, {
		name = opts.name,
		extra_key = opts.key,
		collectible = opts.collectible,
		no_fire = true,
		supports_bffs = opts.supports_bffs == true,
		supports_lullaby = opts.supports_lullaby == true,
		supports_bender = opts.supports_bender == true,
		control_mode = "move_only",
		keep_vanilla_ai = false,
	})
end

-- 472 King Baby：它自身作为无攻击 full-control follower 跟随所属 Flight，
-- 跳过原版会重排整条玩家 familiar 队列的 AI。其“统领其他宝宝”在下方通过
-- 选择器的低优先级临时所有权实现，不写 Craft bind。
local ACTIVE_KINGS = setmetatable({}, {__mode = "k"})
local KING_CANDIDATES = setmetatable({}, {__mode = "k"})
local KING_CONTROLLER_PRIORITY = 50
local KING_STATE_KEY = item.own_key.."king_follow_state"
local KING_EXTERNAL_BIND_KEY = item.own_key.."king_external_bind"

local function entity_alive(ent)
	if not ent then return false end
	local ok, alive = pcall(function() return ent:Exists() and not ent:IsDead() end)
	return ok and alive == true
end

local function familiar_player(fam)
	if not fam then return nil end
	local ok, player = pcall(function() return fam.Player end)
	if ok and player then return player end
	return auxi.check_spawner_player(fam)
end

local assignment_frame = -1
local king_assignment = setmetatable({}, {__mode = "k"})

local function rebuild_king_assignments()
	local frame = Game():GetFrameCount()
	if assignment_frame == frame then return end
	assignment_frame = frame
	king_assignment = setmetatable({}, {__mode = "k"})

	local kings = {}
	for king in pairs(ACTIVE_KINGS) do
		local bind = entity_alive(king) and H.get_bind(king) or nil
		if bind and bind.air and entity_alive(bind.air) then
			kings[#kings + 1] = king
		else
			ACTIVE_KINGS[king] = nil
		end
	end
	if #kings == 0 then return end
	table.sort(kings, function(a, b) return (a.InitSeed or 0) < (b.InitSeed or 0) end)
	local kings_by_player = {}
	for _, king in ipairs(kings) do
		local player = familiar_player(king)
		if player then
			local key = GetPtrHash(player)
			kings_by_player[key] = kings_by_player[key] or {}
			kings_by_player[key][#kings_by_player[key] + 1] = king
		end
	end

	local candidates_by_player = {}
	for fam in pairs(KING_CANDIDATES) do
		local adapter = entity_alive(fam) and H.get_adapter(fam.Variant) or nil
		local retired = entity_alive(fam) and fam:GetData()[H.own_key.."craft_retired"] == true
		local claimed = adapter and Selector.has_claim_above(fam, KING_CONTROLLER_PRIORITY, Selector.KING_BABY)
		if adapter and fam.Variant ~= (FamiliarVariant.KING_BABY or 109)
		and not retired and not claimed then
			local player = familiar_player(fam)
			if player then
				local key = GetPtrHash(player)
				candidates_by_player[key] = candidates_by_player[key] or {}
				candidates_by_player[key][#candidates_by_player[key] + 1] = fam
			end
		elseif not entity_alive(fam) then
			KING_CANDIDATES[fam] = nil
		end
	end

	-- 按玩家分别轮询分配，避免联机串权；高优先级已申请的宝宝不参与计数。
	for player_key, candidates in pairs(candidates_by_player) do
		local available = kings_by_player[player_key]
		if available and #available > 0 then
			table.sort(candidates, function(a, b) return (a.InitSeed or 0) < (b.InitSeed or 0) end)
			for index, fam in ipairs(candidates) do
				king_assignment[fam] = available[(index - 1) % #available + 1]
			end
		end
	end
end

local function assigned_king(fam)
	rebuild_king_assignments()
	local king = king_assignment[fam]
	return entity_alive(king) and king or nil
end

register(FamiliarVariant.KING_BABY or 109, {
	name = "king_baby",
	extra_key = "king_baby",
	collectible = CollectibleType.COLLECTIBLE_KING_BABY or 472,
	no_fire = true,
	supports_bffs = false,
	supports_lullaby = false,
	control_mode = "full",
	update = function(_adapter, ctx)
		if ctx.familiar then ACTIVE_KINGS[ctx.familiar] = true end
	end,
	release = function(_adapter, fam)
		ACTIVE_KINGS[fam] = nil
		assignment_frame = -1
	end,
})

Selector.register(Selector.KING_BABY, KING_CONTROLLER_PRIORITY, function(fam)
	return fam ~= nil and assigned_king(fam) ~= nil
end, {
	on_gain = function(fam)
		if fam then FollowerArbiter.claim(fam, Selector.KING_BABY, {followers = true}) end
	end,
	on_lost = function(fam)
		if fam then
			FollowerArbiter.release(fam, Selector.KING_BABY)
			H.release_external_full(fam)
			local d = fam:GetData()
			d[KING_STATE_KEY] = nil
			d[KING_EXTERNAL_BIND_KEY] = nil
		end
	end,
})

-- full adapter（波比等）必须跳过读取玩家输入的原版 AI，稍后改由国王所属 Flight
-- 的 intent 驱动；move_only/keep_vanilla_ai 才继续放行原版能力。
table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_FAMILIAR_UPDATE,
	params = nil,
	Function = function(_, fam)
		if not fam then return end
		local adapter = H.get_adapter(fam.Variant)
		if not adapter or H.adapter_allows_vanilla_ai(adapter) then return end
		if Selector.is_owner(fam, Selector.KING_BABY) then
			FollowerArbiter.claim(fam, Selector.KING_BABY, {followers = true})
			return true
		end
	end,
})

-- 放行原版 AI 的目标只覆盖其本帧 AI 算完后的位移。保留 follower 身份是为了
-- 高优先级控制器接手时能看到真实原始队列状态；这里不靠 FollowParent 决定锚点。
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_UPDATE,
	params = nil,
	Function = function(_, fam)
		if not fam then return end
		local adapter = H.get_adapter(fam.Variant)
		if not adapter then return end
		KING_CANDIDATES[fam] = true
		if not Selector.is_owner(fam, Selector.KING_BABY) then return end
		FollowerArbiter.claim(fam, Selector.KING_BABY, {
			followers = true,
			delayed = adapter.trail_follow == true,
		})
		if not H.adapter_allows_vanilla_ai(adapter) then return end
		local king = assigned_king(fam)
		if not king then return end
		local d = fam:GetData()
		d[KING_STATE_KEY] = d[KING_STATE_KEY] or {}
		local target = H.external_chain_target(king, fam, 40, 20, d[KING_STATE_KEY])
		if fam.FollowPosition then fam:FollowPosition(target) end
		local delta = target - fam.Position
		local dist = delta:Length()
		if dist > 8 then
			local desired = delta:Resized(math.min(18, (dist - 8) * 0.4))
			fam.Velocity = (fam.Velocity or Vector.Zero) * 0.45 + desired * 0.55
			if fam.Velocity:Length() > 18 then fam.Velocity = fam.Velocity:Resized(18) end
		else
			fam.Velocity = (fam.Velocity or Vector.Zero) * 0.2
			if fam.Velocity:Length() < 0.35 then fam.Velocity = Vector.Zero end
		end
	end,
})

-- full adapter 复用蓝图同一套火控；follow_leader 指向分配到的国王宝宝，
-- air 则决定攻击意图和射击方向。没有给目标写 Craft bind，因此 Emblem/其它 Flight
-- 的更高优先级申请仍会立即胜出。
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		for fam in pairs(KING_CANDIDATES) do
			if entity_alive(fam) and Selector.is_owner(fam, Selector.KING_BABY) then
				local adapter = H.get_adapter(fam.Variant)
				if adapter and not H.adapter_allows_vanilla_ai(adapter) then
					FollowerArbiter.claim(fam, Selector.KING_BABY, {followers = true})
					local king = assigned_king(fam)
					local king_bind = king and H.get_bind(king) or nil
					local air = king_bind and king_bind.air
					local player = king_bind and king_bind.player or familiar_player(king)
					if entity_alive(air) and player then
						local d = fam:GetData()
						d[KING_EXTERNAL_BIND_KEY] = d[KING_EXTERNAL_BIND_KEY] or {}
						local external = d[KING_EXTERNAL_BIND_KEY]
						external.air = air
						external.player = player
						external.profile = king_bind.profile
						external.craft_uid = king_bind.craft_uid
						external.follow_leader = king
						H.update_external_full(fam, air, player, external)
					end
				end
			end
		end
	end,
})

-- 469 Depression：原版水迹/圣光
register_move_ai(FamiliarVariant.DEPRESSION or 105, {
	name = "depression",
	key = "depression",
	collectible = CollectibleType.COLLECTIBLE_DEPRESSION or 469,
})

-- 269 Headless Baby：原版血迹
register_move_ai(FamiliarVariant.HEADLESS_BABY or 55, {
	name = "headless_baby",
	key = "headless_baby",
	collectible = CollectibleType.COLLECTIBLE_HEADLESS_BABY or 269,
})

-- 404 Farting Baby：原版被弹屁
register_move_ai(FamiliarVariant.FARTING_BABY or 95, {
	name = "farting_baby",
	key = "farting_baby",
	collectible = CollectibleType.COLLECTIBLE_FARTING_BABY or 404,
})

-- 607 Boiled Baby：原版周期环射
register_move_ai(FamiliarVariant.BOILED_BABY or 208, {
	name = "boiled_baby",
	key = "boiled_baby",
	collectible = CollectibleType.COLLECTIBLE_BOILED_BABY or 607,
	supports_bffs = true,
	supports_lullaby = true,
})

-- 266 Juicy Sack：原版水迹/蜘蛛
register_move_ai(FamiliarVariant.JUICY_SACK or 52, {
	name = "juicy_sack",
	key = "juicy_sack",
	collectible = CollectibleType.COLLECTIBLE_JUICY_SACK or 266,
})

-- 273 Bob's Brain：已迁至 Craft_Projectile_Familiars_holder（冲锋/爆炸/重生）

-- 265 Dry Baby：原版挡弹/全房伤
register_move_ai(FamiliarVariant.DRY_BABY or 51, {
	name = "dry_baby",
	key = "dry_baby",
	collectible = CollectibleType.COLLECTIBLE_DRY_BABY or 265,
})

-- 426 Obsessed Fan：keep_vanilla_ai + 退出 MoveDelay；位移跟 Flight trail；接触伤可走原版
register(FamiliarVariant.OBSESSED_FAN or 98, {
	name = "obsessed_fan",
	extra_key = "obsessed_fan",
	collectible = CollectibleType.COLLECTIBLE_OBSESSED_FAN or 426,
	no_fire = true,
	supports_bffs = true,
	supports_lullaby = false,
	keep_vanilla_ai = true,
	soft_rebind = true,
	exclude_from_formation = true,
	trail_follow = true,
	trail_priority = 50,
})

-- 543 Hallowed Ground：展示跟随；白大便仍走 on-hurt
register_move_ai(FamiliarVariant.HALLOWED_GROUND or 129, {
	name = "hallowed_ground",
	key = "hallowed_ground",
	collectible = CollectibleType.COLLECTIBLE_HALLOWED_GROUND or 543,
})

-- 433 My Shadow：独立轨迹队列，Velocity 紧跟 Flight 历史相位；接触生成冲锋怪走原版 AI
-- FamiliarVariant 未进 Docs：entities2.xml variant=131
register(FamiliarVariant.MY_SHADOW or 131, {
	name = "my_shadow",
	extra_key = "my_shadow",
	collectible = CollectibleType.COLLECTIBLE_MY_SHADOW or 433,
	no_fire = true,
	supports_bffs = false,
	supports_lullaby = false,
	keep_vanilla_ai = true,
	soft_rebind = true,
	exclude_from_formation = true,
	trail_follow = true,
	trail_priority = 40,
})

-- 468 Shade：严格跟随 Flight（不进波比链）；自绘飞行器三层黑白剪影；接触成长走原版 AI
local SHADE_AIR_ANM2 = "gfx/familiar/Airs/Qing_Air.anm2"
local SHADE_LAYER_BLACK = Color(0, 0, 0, 1)
local SHADE_LAYER_WHITE = Color(1, 1, 1, 1)
local SHADE_SHADOW_FALLBACK = 11

local function shade_bind(fam)
	if not fam then return nil end
	return fam:GetData()[H.own_key.."bind"]
end

local function ensure_shade_sprite(fam, air)
	local d = fam:GetData()
	local spr = d[item.own_key.."shade_spr"]
	if not spr then
		spr = Sprite()
		spr:Load(SHADE_AIR_ANM2, true)
		d[item.own_key.."shade_spr"] = spr
	end
	local src = air and air:GetSprite()
	if src then
		local anim = src:GetAnimation() or "View"
		if d[item.own_key.."shade_anim"] ~= anim then
			spr:Play(anim, true)
			d[item.own_key.."shade_anim"] = anim
		end
		if spr.SetFrame then
			spr:SetFrame(anim, src:GetFrame() or 0)
		end
		spr.FlipX = src.FlipX
		spr.FlipY = src.FlipY
		spr.Rotation = src.Rotation or 0
		spr.Scale = src.Scale or Vector(1, 1)
	end
	return spr
end

local function shade_screen_pos(fam, offset)
	local world = fam.Position
	if fam.PositionOffset then
		world = world + fam.PositionOffset
	end
	local pos = Isaac.WorldToScreen(world)
	if offset then pos = pos + offset end
	local room = Game():GetRoom()
	if room and room.GetRenderScrollOffset then
		pos = pos - room:GetRenderScrollOffset()
	end
	return pos
end

register(FamiliarVariant.SHADE or 106, {
	name = "shade",
	extra_key = "shade",
	collectible = CollectibleType.COLLECTIBLE_SHADE or 468,
	no_fire = true,
	supports_bffs = true,
	supports_lullaby = false,
	keep_vanilla_ai = true,
	soft_rebind = true,
	exclude_from_formation = true,
	strict_follow = true,
	update = function(_adapter, ctx)
		local fam = ctx.familiar
		if not fam then return end
		local d = fam:GetData()
		if d[item.own_key.."shadow_size"] == nil then
			d[item.own_key.."shadow_size"] = fam.GetShadowSize and fam:GetShadowSize() or SHADE_SHADOW_FALLBACK
		end
		if fam.SetShadowSize then fam:SetShadowSize(0) end
		if ctx.air then ensure_shade_sprite(fam, ctx.air) end
	end,
	release = function(_adapter, fam)
		local d = fam and fam:GetData()
		if not d then return end
		local sz = tonumber(d[item.own_key.."shadow_size"]) or SHADE_SHADOW_FALLBACK
		if fam.SetShadowSize then fam:SetShadowSize(sz) end
		d[item.own_key.."shade_spr"] = nil
		d[item.own_key.."shade_anim"] = nil
		d[item.own_key.."shadow_size"] = nil
	end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_FAMILIAR_RENDER,
	params = FamiliarVariant.SHADE or 106,
	Function = function(_, fam, offset)
		local bind = shade_bind(fam)
		if not bind or not bind.air then return end
		if bind.adapter_name ~= "shade" then return end
		local Selector = require("Qing_Remaster_scripts.mimics.Familiar_Control_Selector")
		if not Selector.is_owner(fam, Selector.BLUEPRINT) then return end
		local spr = ensure_shade_sprite(fam, bind.air)
		local pos = shade_screen_pos(fam, offset)
		spr.Color = SHADE_LAYER_BLACK
		spr:RenderLayer(0, pos, Vector.Zero, Vector.Zero)
		spr:RenderLayer(1, pos, Vector.Zero, Vector.Zero)
		spr.Color = SHADE_LAYER_WHITE
		spr:RenderLayer(2, pos, Vector.Zero, Vector.Zero)
		return false
	end,
})

-- 187 Guppy's Hairball：Flight 锚点软绳 flail（探针 L0≈26 / Lmax≈75 / k≈0.03）。
-- 成长 n = SubType（0–4）；伤 2n+5；动画 Idle/Float(n+1)；接触 tick 14。
-- 禁止 keep_vanilla_ai+FollowPosition（会压掉鞭梢）；禁止 trail_follow（互拖 0xc0000409）。
local HAIRBALL_VARIANT = FamiliarVariant.GUPPYS_HAIRBALL or 42
local HAIRBALL_L0 = 26
local HAIRBALL_LMAX = 75
local HAIRBALL_K = 0.03
local HAIRBALL_DAMP = 0.985
local HAIRBALL_VMAX = 16
local HAIRBALL_CONTACT_INTERVAL = 14
local HAIRBALL_BIND_KEY = H.own_key .. "bind"
local HAIRBALL_TICK_KEY = item.own_key .. "hairball_tick"

local function get_orbital()
	return require("Qing_Remaster_scripts.mimics.Craft_Orbital_holder")
end

--- 与环绕接触伤同一套：contact_mul / √n（及追敌折扣）
local function hairball_orbital_mul(air)
	local Orb = get_orbital()
	if Orb and Orb.aura_damage_mul then
		local ok, mul = pcall(Orb.aura_damage_mul, air, "normal")
		if ok and tonumber(mul) then return tonumber(mul) end
	end
	local fallback = Orb and Orb.debug and tonumber(Orb.debug.contact_mul)
	return fallback or 0.45
end

local function hairball_alive(fam)
	if not fam then return false end
	local ok, alive = pcall(function() return fam:Exists() and not fam:IsDead() end)
	return ok and alive == true
end

local function hairball_bound(fam)
	if not hairball_alive(fam) then return false end
	local d = fam:GetData()
	return d and d[HAIRBALL_BIND_KEY] ~= nil
end

local function hairball_n(fam)
	local n = math.floor(tonumber(fam.SubType) or 0)
	if n < 0 then n = 0 elseif n > 4 then n = 4 end
	return n
end

local function hairball_set_n(fam, n)
	n = math.floor(tonumber(n) or 0)
	if n < 0 then n = 0 elseif n > 4 then n = 4 end
	fam.SubType = n
	return n
end

local function hairball_update(_adapter, ctx)
	local fam = ctx.familiar
	local air = ctx.air
	if not fam or not air then return end
	local d = fam:GetData()
	local anchor = air.Position
	local delta = fam.Position - anchor
	local dist = delta:Length()
	local vel = fam.Velocity or Vector.Zero

	if dist > HAIRBALL_LMAX and dist > 0.01 then
		local radial = delta:Resized(1)
		fam.Position = anchor + radial * HAIRBALL_LMAX
		delta = fam.Position - anchor
		dist = HAIRBALL_LMAX
		local v_rad = vel:Dot(radial)
		if v_rad > 0 then
			vel = vel - radial * v_rad
		end
	elseif dist > 120 then
		-- 换房漏 snap 等异常：软拉，禁止瞬移
		vel = vel + delta:Resized(-math.min(8, (dist - 120) * 0.08))
	end

	if dist > 0.01 then
		local a = HAIRBALL_K * (dist - HAIRBALL_L0)
		vel = vel + delta:Resized(-a)
	end
	vel = vel * HAIRBALL_DAMP
	if vel:Length() > HAIRBALL_VMAX then
		vel = vel:Resized(HAIRBALL_VMAX)
	end
	fam.Velocity = vel

	local n = hairball_n(fam)
	local mul = 1
	if fam.GetMultiplier then
		mul = tonumber(fam:GetMultiplier()) or 1
	end
	local orb_mul = hairball_orbital_mul(air)
	local base_dmg = 2 * n + 5
	local tick = tonumber(d[HAIRBALL_TICK_KEY]) or 0
	tick = tick + 1
	if tick >= HAIRBALL_CONTACT_INTERVAL then
		tick = 0
		fam.CollisionDamage = base_dmg * mul * orb_mul
	else
		fam.CollisionDamage = 0
	end
	d[HAIRBALL_TICK_KEY] = tick

	local spr = fam:GetSprite()
	if spr then
		local moving = vel:Length() > 0.8
		local anim = (moving and "Float" or "Idle") .. tostring(n + 1)
		if not spr:IsPlaying(anim) then
			spr:Play(anim, true)
		end
	end
end

register(HAIRBALL_VARIANT, {
	name = "guppys_hairball",
	extra_key = "guppys_hairball",
	collectible = CollectibleType.COLLECTIBLE_GUPPYS_HAIRBALL or 187,
	no_fire = true,
	supports_bffs = true,
	supports_lullaby = false,
	soft_rebind = true,
	exclude_from_formation = true,
	custom_move = true,
	custom_animation = true,
	update = hairball_update,
	on_snap = function(_, fam)
		local d = fam:GetData()
		d[HAIRBALL_TICK_KEY] = 0
		fam.Velocity = Vector.Zero
	end,
	release = function(_, fam)
		local d = fam:GetData()
		d[HAIRBALL_TICK_KEY] = nil
	end,
})

-- 击杀成长：n+=1（封顶 4）；下楼衰减见 NEW_LEVEL
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = nil,
	Function = function(_, ent, amount, _flags, source, _countdown)
		if not ent or not source then return end
		if not ent:IsVulnerableEnemy() then return end
		local se = source.Entity
		local fam = se and se:ToFamiliar()
		if not fam or fam.Variant ~= HAIRBALL_VARIANT then return end
		if not hairball_bound(fam) then return end
		local hp = tonumber(ent.HitPoints) or 0
		local dmg = tonumber(amount) or 0
		if hp - dmg > 0 then return end
		local n = hairball_n(fam)
		if n < 4 then hairball_set_n(fam, n + 1) end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_LEVEL,
	params = nil,
	Function = function()
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, HAIRBALL_VARIANT, -1, false, false)) do
			local fam = ent:ToFamiliar()
			if fam and hairball_bound(fam) then
				local n = hairball_n(fam)
				if n <= 2 then
					n = n - 1
				else
					n = n - 2
				end
				hairball_set_n(fam, math.max(0, n))
			end
		end
	end,
})

-- 178 Holy Water：已迁至 Craft_Projectile_Familiars_holder

return item

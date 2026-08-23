-- Gemini / Incubus / Twisted Pair：Flight 特殊位置与完整攻击复用。
local H = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {pre_ToCall = {}, ToCall = {}, myToCall = {}, own_key = "Craft_Advanced_Familiars_holder_"}

local function is_lilith(player)
	return player and player:GetPlayerType() == PlayerType.PLAYER_LILITH
end

local function queue_flight_attack(adapter, ctx)
	local profile = ctx.bind and ctx.bind.profile
	-- Ludovico：由 Craft_Ludovico_holder 维护持久卫星，禁止离散 AuxAttackQueue
	if profile and profile.weapon == 8 then
		return true
	end
	local Air = require("Qing_Remaster_scripts.items.Item_Air_Flight")
	local mul = is_lilith(ctx.player) and adapter.lilith_damage_mul or adapter.damage_mul
	return Air.queue_craft_aux_attack(ctx.air, ctx.familiar.Position, ctx.aim_vector, mul, adapter.name, ctx.familiar, adapter.knife_scale)
end

local function flight_cooldown(_, ctx)
	local profile = ctx.bind and ctx.bind.profile
	if not profile then return 16 end
	local mods = CraftProfile.attack_modifiers_from_profile(profile)
	return CraftProfile.attack_delay_from_modifiers(
		CraftProfile.craft_fire_delay(profile, profile.weapon or 1),
		mods
	)
end

local function ensure_gemini_render_sprite(fam)
	local d = fam:GetData()
	if d[item.own_key.."render_sprite"] == nil then
		local render_sprite = Sprite()
		-- 从实体实际使用的 ANM2 载入，兼容游戏版本及其他模组替换的 Gemini 文件。
		local filename = fam:GetSprite():GetFilename()
		if not filename or filename == "" then filename = "gfx/003.079_gemini familiar.anm2" end
		render_sprite:Load(filename, true)
		d[item.own_key.."render_sprite"] = render_sprite
	end
end

-- 屏幕坐标（大房间审计已验证，见 gemini_cord_render_pitfalls.md）：
--   PRE offset 在大房间会带上 GetRenderScrollOffset；W2S 已是窗口坐标。
--   Gemini：W2S(world) + offset - scroll（本端 callback 已含其渲染抬高，禁止再叠 PO）。
--   Flight：W2S(world + PositionOffset) + SpriteOffset（PO 是世界/实体单位，禁止 W2S+PO）。
--   world 用 Position + Velocity * render_frac 做逻辑/渲染帧插值（约 30↔60）。
--
-- ANM2 挂点：Gemini body YPivot=32 → 上移 18。
-- Cord 层裁剪为 21x18、Pivot=(10,16)，但真实 alpha 只向反方向延伸11px（见下方常量）。
-- Flight 端必须按这个真实贴图长度避让机体，不能只移动一个无尺寸数学端点。
-- 影子：shadow_replace.anm2 的 100% 帧完整覆盖 120x48；Sprite.Scale 直接使用
-- EntityConfig:GetShadowSize() 的运行时值（Gemini XML shadowSize=11 -> 0.11），保持原始宽高比。
local GEMINI_CORD_HANG = Vector(0, -18)
local FLIGHT_CORD_RADIUS = Vector(10, 10) -- 用户实测 Flight 可见本体 20x20px，中心到边界 10px
-- Cord 裁剪 21x18 / PivotY=16，但原版图集该裁剪内实际 alpha bbox Y=5..12；
-- 有色像素向 Pivot 后方只延伸 16-5=11px。按裁剪框 16px 避让会凭空制造 5px 透明断口。
local CORD_PIECE_BACK_EXTENT = 11
local CORD_FLIGHT_CLEARANCE = 0
local CORD_LAYER_FIRST = 1
local CORD_LAYER_LAST = 9
local GEMINI_SHADOW_SIZE_FALLBACK = 0.11 -- xml shadowSize 11 → EntityConfig/GetShadowSize 单位
local GEMINI_SHADOW_ANM2 = "gfx/shadow_replace.anm2"

local function gemini_shadow_size(fam)
	local d = fam:GetData()
	local cached = tonumber(d[item.own_key.."shadow_size"])
	if cached and cached > 0 then return cached end
	-- 优先 EntityConfig（接管后 GetShadowSize 常为 0），勿先写 fallback 挡住 config
	local sz = nil
	if fam.GetEntityConfigEntity then
		local ok, cfg = pcall(function() return fam:GetEntityConfigEntity() end)
		if ok and cfg and cfg.GetShadowSize then
			local s = tonumber(cfg:GetShadowSize())
			if s and s > 0 then sz = s end
		end
	end
	if (not sz or sz <= 0) and EntityConfig and EntityConfig.GetEntity then
		local ok, cfg = pcall(EntityConfig.GetEntity, fam.Type, fam.Variant, fam.SubType or 0)
		if ok and cfg and cfg.GetShadowSize then
			local s = tonumber(cfg:GetShadowSize())
			if s and s > 0 then sz = s end
		end
	end
	if (not sz or sz <= 0) and fam.GetShadowSize then
		local s = tonumber(fam:GetShadowSize())
		if s and s > 0 then sz = s end
	end
	sz = (sz and sz > 0) and sz or GEMINI_SHADOW_SIZE_FALLBACK
	d[item.own_key.."shadow_size"] = sz
	return sz
end

-- 必须在 render_gemini 之前声明：否则函数体里的 get_probe 会解析成全局 nil
local function get_probe()
	return package.loaded["Qing_Remaster_scripts.others.gemini_motion_probe"]
end

--- 逻辑≈30Hz、渲染≈60Hz：用半步速度插值，避免自绘相对引擎实体「一顿一顿」
local function render_interp_frac()
	if Isaac.GetFrameCount then
		return (Isaac.GetFrameCount() % 2) * 0.5
	end
	return 0.5
end

local function world_for_render(ent)
	local vel = ent.Velocity or Vector.Zero
	return ent.Position + vel * render_interp_frac()
end

--- Gemini：W2S(插值世界) + PRE offset - scroll（禁止再叠 fam.PositionOffset）
local function gemini_render_pos(fam, callback_offset)
	local room = Game():GetRoom()
	return Isaac.WorldToScreen(world_for_render(fam))
		+ (callback_offset or Vector.Zero)
		- room:GetRenderScrollOffset()
end

--- Flight：无 PRE callback；PO 进 W2S，SO 按屏幕量另加（见 pitfalls 标尺实测）
local function flight_render_pos(air)
	local world = world_for_render(air) + (air.PositionOffset or Vector.Zero)
	return Isaac.WorldToScreen(world) + (air.SpriteOffset or Vector.Zero)
end

--- Flight 端脐带几何（全程屏幕坐标）。
--- 返回 first_pivot / Gemini 挂点 / 方向 / Flight 轮廓交点。
--- 第一段 Cord 的 Pivot 按真实 alpha 后伸量外移，使有色贴图后沿接在机体边界。
local function flight_cord_geometry(air, flight_center, gemini_anchor)
	if not air or not flight_center or not gemini_anchor then return nil end
	local ray = gemini_anchor - flight_center
	local ray_len = ray:Length()
	if ray_len < 0.001 then return nil end
	local dir = ray:Normalized()

	local sx, sy = 1, 1
	local air_sprite = air:GetSprite()
	if air_sprite and air_sprite.Scale then
		sx = math.abs(tonumber(air_sprite.Scale.X) or 1)
		sy = math.abs(tonumber(air_sprite.Scale.Y) or 1)
	end
	-- Item_Air_Flight.apply_body_scale 每帧把 profile.body_scale_mul 写入 Entity.SpriteScale；
	-- Magic Mushroom/Mini Mush/Binky/Pluto/Inner Child 等会改变它。两层 Scale 都要计入。
	if air.SpriteScale then
		sx = sx * math.abs(tonumber(air.SpriteScale.X) or 1)
		sy = sy * math.abs(tonumber(air.SpriteScale.Y) or 1)
	end
	local rx = math.max(1, FLIGHT_CORD_RADIUS.X * sx)
	local ry = math.max(1, FLIGHT_CORD_RADIUS.Y * sy)
	local denom = math.sqrt((dir.X / rx) ^ 2 + (dir.Y / ry) ^ 2)
	if denom <= 0 then return nil end
	local edge_dist = 1 / denom
	local edge = flight_center + dir * edge_dist
	local first_pivot = edge + dir * (CORD_PIECE_BACK_EXTENT + CORD_FLIGHT_CLEARANCE)

	-- 两端过近时，第一段若继续绘制只能反向穿入 Flight；宁可隐藏整条短绳。
	if ray_len <= edge_dist + CORD_PIECE_BACK_EXTENT + CORD_FLIGHT_CLEARANCE then
		return nil, gemini_anchor, dir, edge
	end
	return first_pivot, gemini_anchor, dir, edge
end

local function ensure_fallback_shadow_sprite(fam)
	local d = fam:GetData()
	local spr = d[item.own_key.."shadow_sprite"]
	if spr then return spr end
	spr = Sprite()
	spr:Load(GEMINI_SHADOW_ANM2, true)
	spr:Play("Idle", true)
	d[item.own_key.."shadow_sprite"] = spr
	return spr
end

local function render_gemini_shadow(fam, body_screen_pos)
	-- 与身体同一屏幕空间（body_screen_pos 已含 offset-scroll / 插值）
	local spr = ensure_fallback_shadow_sprite(fam)
	if not spr then return end
	-- 资源帧为 120x48 @ 100%；配置值 0.11 应在 Sprite 层等比应用一次。
	local scale = gemini_shadow_size(fam)
	spr.Scale = Vector(scale, scale)
	spr.Color = Color(1, 1, 1, 1)
	spr:SetFrame("Idle", 0)
	spr:Render(body_screen_pos, Vector.Zero, Vector.Zero)
	-- 接管期引擎影子保持 0，避免叠一层偏小的 RenderShadowLayer
	if fam.SetShadowSize then fam:SetShadowSize(0) end
end

local function render_gemini(fam, bind, offset)
	if not bind or not auxi.check_all_exists(bind.air) then return end
	local source = fam:GetSprite()
	local render_sprite = fam:GetData()[item.own_key.."render_sprite"]
	if not render_sprite then return end
	offset = offset or Vector.Zero

	local gemini_pos = gemini_render_pos(fam, offset)
	local flight_pos = flight_render_pos(bind.air)
	local to = gemini_pos + GEMINI_CORD_HANG
	local from, _, cord_dir, flight_edge = flight_cord_geometry(bind.air, flight_pos, to)
	local delta = from and (to - from) or Vector.Zero
	local anim = source:GetAnimation()
	local d = fam:GetData()
	-- 动画变化时才 Play 一次；每帧只 SetFrame，避免 render 里反复 Play(..., true)
	if d[item.own_key.."render_anim"] ~= anim then
		render_sprite:Play(anim, true)
		d[item.own_key.."render_anim"] = anim
	end
	render_sprite:SetFrame(anim, source:GetFrame())
	render_sprite.FlipX = source.FlipX
	render_sprite.FlipY = source.FlipY
	render_sprite.Color = source.Color

	render_gemini_shadow(fam, gemini_pos)

	-- 留下可直接由 ImGui/探针读取的几何结果；不写盘、不改变正式渲染。
	d[item.own_key.."cord_flight_center"] = flight_pos
	d[item.own_key.."cord_flight_edge"] = flight_edge
	d[item.own_key.."cord_first_pivot"] = from
	d[item.own_key.."cord_gemini_anchor"] = to
	d[item.own_key.."cord_direction"] = cord_dir
	d[item.own_key.."cord_visible_length"] = from and delta:Length() or 0
	d[item.own_key.."cord_geometry_frame"] = Isaac.GetFrameCount and Isaac.GetFrameCount() or Game():GetFrameCount()

	if from and delta:Length() > 1 then
		-- 九个 Cord 层都是 21x18 / Pivot=(10,16)。第一层 Pivot 已避开 Flight，
		-- 最后一层落在 Gemini 挂点并由稍后绘制的 Gemini 身体自然遮住；禁止人工淡出。
		render_sprite.Rotation = delta:GetAngleDegrees() - 90
		render_sprite.Scale = Vector(1, 1)
		local layer_span = CORD_LAYER_LAST - CORD_LAYER_FIRST
		for layer = CORD_LAYER_FIRST, CORD_LAYER_LAST do
			local u = (layer_span > 0) and ((layer - CORD_LAYER_FIRST) / layer_span) or 0
			render_sprite:RenderLayer(layer, from + delta * u, Vector.Zero, Vector.Zero)
		end
	end
	render_sprite.Rotation = source.Rotation
	render_sprite.Scale = source.Scale
	render_sprite:RenderLayer(0, gemini_pos, Vector.Zero, Vector.Zero)
end

-- 索敌/脱锁相对 Flight；探针 vanilla 相对玩家距离约 max≈160
local GEMINI_ENTER_RANGE = 120
local GEMINI_EXIT_RANGE = 150
local GEMINI_LEASH_HARD = 160
local GEMINI_TARGET_LOST_GRACE = 12
local GEMINI_CHASE_MAX_SPEED = 9
local GEMINI_RETURN_MAX_SPEED = 10
-- 探针 idle：radial_speed med≈4.9 / p75≈7.1 / max≈18；CAP=8 ≈ p75，作单帧上限合理
-- radial_per_dist idle med≈0.082；比例用 0.08，远距由 CAP 封顶（勿用 0.15，会过早顶满）
local GEMINI_LEASH_STEP = 8
local GEMINI_RETURN_PULL = 0.08
local GEMINI_RETURN_SOFT = 28
local GEMINI_CHASE_LEASH_SOFT = 100

--- 软拉扯：只写 Velocity（供引擎位移 + 渲染插值）。禁止硬改 Position（除 SNAP）。
local function soft_leash_velocity(fam, dest, soft_radius, max_step)
	if not fam or not dest then return 0 end
	local delta = dest - fam.Position
	local dist = delta:Length()
	local soft = soft_radius or GEMINI_RETURN_SOFT
	local cap = max_step or GEMINI_LEASH_STEP
	if dist <= soft or delta:Length() < 0.01 then return 0 end
	local step = math.min(cap, (dist - soft) * GEMINI_RETURN_PULL)
	if step < 0.05 then return 0 end
	local desired = delta:Resized(step)
	fam.Velocity = fam.Velocity * 0.55 + desired * 0.45
	if fam.Velocity:Length() > GEMINI_RETURN_MAX_SPEED then
		fam.Velocity = fam.Velocity:Resized(GEMINI_RETURN_MAX_SPEED)
	end
	return step
end

local function sprite_play(fam, sprite, animation, force)
	local probe = get_probe()
	local collecting = probe and probe.is_collecting and probe.is_collecting()
	local before_anim, before_frame
	if collecting then
		before_anim, before_frame = sprite:GetAnimation(), sprite:GetFrame()
	end
	sprite:Play(animation, force == nil and true or force)
	if collecting and probe.note_anim_action then
		probe.note_anim_action(fam, "Play", before_anim, before_frame, sprite:GetAnimation(), sprite:GetFrame())
	end
end

--- 正式默认 manual30（PRE 跳过原版后每逻辑帧推进一次）。
--- 探针可切 native / legacy15 做 A/B；不再把 15Hz 当分频默认。
local function sprite_update_by_clock(fam, sprite)
	local probe = get_probe()
	local collecting = probe and probe.is_collecting and probe.is_collecting()
	local clock = "manual30"
	if probe and probe.is_enabled and probe.is_enabled() and probe.get_anim_clock_mode then
		clock = probe.get_anim_clock_mode() or clock
	end
	local d = fam:GetData()
	local before_anim, before_frame
	if collecting then
		before_anim, before_frame = sprite:GetAnimation(), sprite:GetFrame()
	end
	local did = false
	if clock == "native" then
		-- 探针档：不手动 Update
	elseif clock == "legacy15" then
		d[item.own_key.."gemini_anim_phase"] = not d[item.own_key.."gemini_anim_phase"]
		if d[item.own_key.."gemini_anim_phase"] then
			sprite:Update()
			did = true
		end
	else
		-- manual30（正式默认）
		sprite:Update()
		did = true
	end
	if did and collecting and probe.note_anim_action then
		probe.note_anim_action(fam, "Update", before_anim, before_frame, sprite:GetAnimation(), sprite:GetFrame())
	end
end

local function target_is_valid(npc)
	return npc
		and auxi.check_all_exists(npc)
		and not npc:IsDead()
		and npc:IsVulnerableEnemy()
		and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
end

--- 索敌/脱锁一律相对 Flight：禁止「Gemini 贴着敌人」单独维持锁定，否则 Flight 飞远仍会咬住。
--- 进出半径分离 + 丢失宽限，避免边界抖 Rage/RageEnd。
local function resolve_gemini_target(fam, air, d)
	if not air or not auxi.check_all_exists(air) then
		d[item.own_key.."gemini_lost_grace"] = nil
		return nil
	end
	local locked = d[item.own_key.."gemini_target"]
	if target_is_valid(locked) then
		local dist_air = locked.Position:Distance(air.Position)
		local fam_leash = fam.Position:Distance(air.Position)
		-- 敌人须仍在 Flight 退出半径内，且 Gemini 自身未超出硬牵引圈
		if dist_air <= GEMINI_EXIT_RANGE and fam_leash <= GEMINI_LEASH_HARD then
			d[item.own_key.."gemini_lost_grace"] = nil
			return locked
		end
	end
	local grace = tonumber(d[item.own_key.."gemini_lost_grace"]) or 0
	if locked and grace < GEMINI_TARGET_LOST_GRACE then
		d[item.own_key.."gemini_lost_grace"] = grace + 1
		if target_is_valid(locked) and locked.Position:Distance(air.Position) <= GEMINI_LEASH_HARD then
			return locked
		end
	end

	local found = H.find_closest_enemy(air.Position, GEMINI_ENTER_RANGE)
	if found then
		d[item.own_key.."gemini_lost_grace"] = nil
		d[item.own_key.."gemini_target_lock_frame"] = Game():GetFrameCount()
		return found
	end
	d[item.own_key.."gemini_lost_grace"] = nil
	return nil
end

local function set_gemini_state(d, fam, sprite, state, anim)
	local prev = d[item.own_key.."gemini_state"]
	if prev == state then
		if anim and not sprite:IsPlaying(anim) then
			sprite_play(fam, sprite, anim, true)
		end
		return
	end
	d[item.own_key.."gemini_state"] = state
	d[item.own_key.."gemini_state_enter_frame"] = Game():GetFrameCount()
	if anim then
		sprite_play(fam, sprite, anim, true)
	end
end

local function update_gemini(_, ctx)
	local fam = ctx.familiar
	local d = fam:GetData()
	local target = resolve_gemini_target(fam, ctx.air, d)
	d[item.own_key.."gemini_target"] = target
	local base = tonumber(d[item.own_key.."gemini_base_collision_damage"])
	if not base then
		base = tonumber(fam.CollisionDamage) or 0
		if base <= 0 then base = 3.5 end
		d[item.own_key.."gemini_base_collision_damage"] = base
	end
	local bff = ctx.player and ctx.player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS)
	fam.CollisionDamage = base * (bff and 2 or 1)

	local sprite = fam:GetSprite()
	-- full adapter PRE 跳过原版 familiar update；正式默认每逻辑帧 Update 一次。
	sprite_update_by_clock(fam, sprite)
	local state = d[item.own_key.."gemini_state"] or "idle"

	-- idle -> rage -> chase -> recover -> idle；rage/recover 必须等动画真正结束
	if target then
		if state == "idle" or state == "recover" then
			-- recover 被打断：等 RageEnd 播完再发怒，避免硬切
			if state == "recover" and not sprite:IsFinished("RageEnd") and sprite:IsPlaying("RageEnd") then
				-- 保持 recover 阻尼
			else
				set_gemini_state(d, fam, sprite, "rage", "Rage")
				state = "rage"
			end
		elseif state == "rage" then
			if sprite:IsFinished("Rage") then
				set_gemini_state(d, fam, sprite, "chase", "FloatDownRage")
				d[item.own_key.."gemini_chase_age"] = 0
				state = "chase"
			elseif not sprite:IsPlaying("Rage") then
				sprite_play(fam, sprite, "Rage", true)
			end
		elseif state == "chase" then
			if not sprite:IsPlaying("FloatDownRage") then
				sprite_play(fam, sprite, "FloatDownRage", true)
			end
		end
	else
		if state == "rage" or state == "chase" then
			set_gemini_state(d, fam, sprite, "recover", "RageEnd")
			state = "recover"
		elseif state == "recover" then
			if sprite:IsFinished("RageEnd") then
				set_gemini_state(d, fam, sprite, "idle", "FloatDown")
				state = "idle"
			elseif not sprite:IsPlaying("RageEnd") then
				sprite_play(fam, sprite, "RageEnd", true)
			end
		elseif state == "idle" then
			if not sprite:IsPlaying("FloatDown") then
				sprite_play(fam, sprite, "FloatDown", true)
			end
		end
	end

	if state == "chase" and target then
		local delta = target.Position - fam.Position
		local age = (tonumber(d[item.own_key.."gemini_chase_age"]) or 0) + 1
		d[item.own_key.."gemini_chase_age"] = age
		local ramp = math.min(1, age / 30)
		local desired_speed = GEMINI_CHASE_MAX_SPEED * (0.2 + 0.8 * ramp)
		local desired = Vector.Zero
		if delta:Length() > 0.01 then
			desired = delta:Resized(desired_speed)
		end
		fam.Velocity = fam.Velocity * 0.86 + desired * 0.14
		if fam.Velocity:Length() > GEMINI_CHASE_MAX_SPEED then
			fam.Velocity = fam.Velocity:Resized(GEMINI_CHASE_MAX_SPEED)
		end
		-- 超软牵引圈：速度拉回 Flight（只写 Velocity，供插值）
		soft_leash_velocity(fam, ctx.air.Position, GEMINI_CHASE_LEASH_SOFT, GEMINI_LEASH_STEP * 0.75)
	elseif state == "idle" then
		soft_leash_velocity(fam, ctx.air.Position, GEMINI_RETURN_SOFT, GEMINI_LEASH_STEP)
		if fam.Velocity:Length() < 0.05 then
			fam.Velocity = fam.Velocity * 0.7
		end
	else
		-- rage / recover：阻尼 + 过远软拉
		fam.Velocity = fam.Velocity * 0.82
		soft_leash_velocity(fam, ctx.air.Position, GEMINI_CHASE_LEASH_SOFT, GEMINI_LEASH_STEP * 0.6)
	end

	d[item.own_key.."gemini_state"] = state
	if state ~= "chase" then d[item.own_key.."gemini_chase_age"] = nil end
	ensure_gemini_render_sprite(fam)
	-- 影子在 PRE_RENDER 里用 RenderShadowLayer 画；这里保持 0，避免 cancel 后引擎再画一遍
	if fam.SetShadowSize then fam:SetShadowSize(0) end
end

H.register_adapter(FamiliarVariant.GEMINI, {
	name = "gemini", extra_key = "gemini",
	collectible = CollectibleType.COLLECTIBLE_GEMINI or 318,
	exclude_from_formation = true,
	base_cooldown = 999999, custom_animation = true, custom_move = true,
	-- Gemini 飘浮动在 ANM2；不要拷 Flight 的 PositionOffset，否则 callback offset 抬到巡航高度、渲染错位
	sync_air_position_offset = false,
	fire = function() return false end,
	acquire = function(_, fam)
		ensure_gemini_render_sprite(fam)
		gemini_shadow_size(fam)
	end,
	-- 换房/传送 snap 后清战斗态，避免带着旧目标在新房间继续追
	on_snap = function(_, fam)
		local d = fam:GetData()
		d[item.own_key.."gemini_target"] = nil
		d[item.own_key.."gemini_lost_grace"] = nil
		d[item.own_key.."gemini_chase_age"] = nil
		d[item.own_key.."gemini_target_lock_frame"] = nil
		d[item.own_key.."gemini_state"] = "idle"
		local sprite = fam:GetSprite()
		if sprite and not sprite:IsPlaying("FloatDown") then
			sprite_play(fam, sprite, "FloatDown", true)
		end
	end,
	update = update_gemini,
	release = function(_, fam)
		local d = fam:GetData()
		local sz = tonumber(d[item.own_key.."shadow_size"]) or GEMINI_SHADOW_SIZE_FALLBACK
		if fam.SetShadowSize then fam:SetShadowSize(sz) end
		d[item.own_key.."render_sprite"] = nil
		d[item.own_key.."render_anim"] = nil
		d[item.own_key.."shadow_sprite"] = nil
		d[item.own_key.."shadow_size"] = nil
		d[item.own_key.."gemini_target"] = nil
		d[item.own_key.."gemini_state"] = nil
		d[item.own_key.."gemini_state_enter_frame"] = nil
		d[item.own_key.."gemini_chase_age"] = nil
		d[item.own_key.."gemini_anim_phase"] = nil
		d[item.own_key.."gemini_lost_grace"] = nil
		d[item.own_key.."gemini_target_lock_frame"] = nil
		d[item.own_key.."gemini_base_collision_damage"] = nil
		d[item.own_key.."cord_flight_center"] = nil
		d[item.own_key.."cord_flight_edge"] = nil
		d[item.own_key.."cord_first_pivot"] = nil
		d[item.own_key.."cord_gemini_anchor"] = nil
		d[item.own_key.."cord_direction"] = nil
		d[item.own_key.."cord_visible_length"] = nil
		d[item.own_key.."cord_geometry_frame"] = nil
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_PRE_FAMILIAR_RENDER,
	params = FamiliarVariant.GEMINI,
	Function = function(_, fam, offset)
		local bind = fam and fam:GetData()[H.own_key.."bind"]
		if not bind or bind.adapter_name ~= "gemini" then return end
		ensure_gemini_render_sprite(fam)
		render_gemini(fam, bind, offset)
		return false
	end,
})

H.register_adapter(FamiliarVariant.INCUBUS, {
	name = "incubus", extra_key = "incubus",
	collectible = CollectibleType.COLLECTIBLE_INCUBUS or 360,
	formation_priority = -10000,
	damage_mul = 0.75, lilith_damage_mul = 1,
	knife_scale = 0.72,
	get_cooldown = flight_cooldown, fire = queue_flight_attack,
})

-- 模拟摇杆 / 鼠标 / Marked：360° 随机；否则四正方向。
function item.uses_free_aim(player)
	if not player then return false end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_MARKED) then return true end
	if Options and Options.MouseControl then return true end
	local joy = player.GetShootingJoystick and player:GetShootingJoystick()
	if joy and joy:Length() > 0.15 then
		local ax, ay = math.abs(joy.X), math.abs(joy.Y)
		if ax > 0.15 and ay > 0.15 then return true end
		if (ax > 0.02 and ax < 0.92) or (ay > 0.02 and ay < 0.92) then return true end
	end
	return false
end

function item.random_cain_other_eye_aim(player)
	if item.uses_free_aim(player) then
		return auxi.MakeVector((math.random() * 3600) / 10)
	end
	local dirs = {Vector(1, 0), Vector(-1, 0), Vector(0, 1), Vector(0, -1)}
	return dirs[math.random(4)]
end

local function queue_cain_other_eye_attack(adapter, ctx)
	local profile = ctx.bind and ctx.bind.profile
	if profile and profile.weapon == 8 then
		return true
	end
	local Air = require("Qing_Remaster_scripts.items.Item_Air_Flight")
	local aim = ctx.aim_vector
	if not aim or aim:Length() < 0.01 then
		aim = item.random_cain_other_eye_aim(ctx.player)
	end
	-- 始终 75%；与 Lilith 无关（有别于 Incubus）。
	return Air.queue_craft_aux_attack(ctx.air, ctx.familiar.Position, aim, 0.75, adapter.name, ctx.familiar, adapter.knife_scale)
end

H.register_adapter(FamiliarVariant.CAINS_OTHER_EYE, {
	name = "cains_other_eye", extra_key = "cains_other_eye",
	collectible = CollectibleType.COLLECTIBLE_CAINS_OTHER_EYE or 319,
	formation_priority = -9000,
	damage_mul = 0.75, lilith_damage_mul = 0.75,
	knife_scale = 0.72,
	aim_while_shooting = function(_, ctx)
		return item.random_cain_other_eye_aim(ctx.player)
	end,
	get_cooldown = flight_cooldown, fire = queue_cain_other_eye_attack,
})

local function twisted_position(_, ctx)
	local bind = ctx.bind or {}
	local facing = ctx.intent and ctx.intent.aim_direction
	if not facing or facing:Length() < 0.01 then facing = ctx.air.Velocity end
	if not facing or facing:Length() < 0.01 then facing = Vector(0, 1) end
	facing = facing:Normalized()
	local side = Vector(-facing.Y, facing.X)
	local sign = (bind.instance_index or 1) == 1 and -1 or 1
	return ctx.air.Position + facing * 2 + side * (18 * sign)
end

H.register_adapter(FamiliarVariant.TWISTED_BABY, {
	name = "twisted_pair", extra_key = "twisted_pair",
	collectible = CollectibleType.COLLECTIBLE_TWISTED_PAIR or 698,
	instances = 2, formation_priority = -9500, exclude_from_formation = true,
	damage_mul = 0.375, lilith_damage_mul = 0.5,
	knife_scale = 0.58,
	follow_position = twisted_position,
	get_cooldown = flight_cooldown, fire = queue_flight_attack,
})

return item

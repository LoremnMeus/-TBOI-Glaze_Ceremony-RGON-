-- Baby Zeis：普通 Familiar 轻量状态机（禁止 Boss_All / 禁止把 room ListIndex 当楼层身份）
-- SLEEP → WAKE → DETACH → APPROACH → OBSERVE → COPY → RETURN → DONE
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local Baby_Anim = require("Qing_Remaster_scripts.others.Baby_Anim_holder")
local Familiar_Follower_Arbiter = require("Qing_Remaster_scripts.mimics.Familiar_Follower_Arbiter")

-- Zeis 单体 dogma chromatic（与 player_Zeis / temp_hud 同源）
local temp_hud = nil
local function get_temp_hud()
	if temp_hud ~= nil then return temp_hud end
	if not REPENTOGON then
		temp_hud = false
		return nil
	end
	local ok, mod = pcall(require, "Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	temp_hud = (ok and mod) or false
	return temp_hud ~= false and temp_hud or nil
end

local STATIC_FLAG = 1 << 5
local GOLD_FLAG = 1 << 7

local function apply_zeis_dogma_sprite(sprite, glitch)
	local hud = get_temp_hud()
	if not hud or not sprite or not sprite.SetCustomShader then return end
	if sprite.GetRenderFlags and sprite.SetRenderFlags then
		local flags = sprite:GetRenderFlags() or 0
		local cleared = flags & ~(STATIC_FLAG | GOLD_FLAG)
		if cleared ~= flags then sprite:SetRenderFlags(cleared) end
	end
	hud.apply_sprite_shader(sprite, hud.DOGMA_CHROMATIC_SHADER)
	local col = sprite.Color
	local t = hud.dogma_shader_time()
	glitch = glitch or 0
	if col.SetColorize then
		local next_col = Color(col.R, col.G, col.B, col.A, col.RO, col.GO, col.BO)
		next_col:SetColorize(glitch, 0, 0, t)
		sprite.Color = next_col
	else
		sprite.Color = Color(col.R, col.G, col.B, col.A, col.RO, col.GO, col.BO, glitch, 0, 0, t)
	end
end

--- 复制完成：白烟 POOF01（勿用 POOF02 红漩涡；见 qing_vfx_effect_cheatsheet.md）
local function spawn_copy_poof(pos)
	local poof = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, pos, Vector.Zero, nil)
	if not poof then return end
	poof = poof:ToEffect() or poof
	if poof.SetColor then
		poof:SetColor(Color(1, 1, 1, 1, 0.85, 0.85, 0.85), 30, 1, false, false)
	end
	local s = poof:GetSprite()
	if s then
		s.Color = Color(1, 1, 1, 1, 0.7, 0.7, 0.7)
		s.Scale = Vector(1.15, 1.15)
	end
end

-- Dogma visual ownership：仅 Baby Zeis 真正生成的 copy pedestal generation
-- 权威源：dogma_bag[generation_id]；DOGMA_COPY_GEN_ID 只是 runtime cache，不得跨 generation 短路
local DOGMA_COPY_GEN_ID = "dogma_copy_generation_id"
local DOGMA_SHADER_FLAG = "dogma_shader_applied"
local DOGMA_PENDING_MARK = "dogma_pending_mark"
local dogma_pickup_bag
local get_dogma_generation_id
local register_dogma_generation
local clear_dogma_runtime_cache
local apply_pickup_dogma
local clear_pickup_dogma_visual
local mark_copy_dogma
local try_resolve_pending_dogma
local pickup_wants_dogma
local reset_only_dogma_colorize_channels

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Baby_Zeis,
	familiar = enums.Familiars.Baby_Zeis,
	own_key = "Item_Baby_Zeis_",
	float_lock = { Wake = true },
	sleep_opts = {
		float_anim = "SleepFloat",
		idle_anim = "SleepIdle",
	},
}

local PHASE = {
	SLEEP = "SLEEP",
	WAKE = "WAKE",
	DETACH = "DETACH",
	APPROACH = "APPROACH",
	OBSERVE = "OBSERVE",
	COPY = "COPY",
	RETURN = "RETURN",
	DONE = "DONE",
}

local FOLLOWER_OWNER = "Baby_Zeis_mission"
local RT_KEY = "rt"
local OWNER_KEY = "owner_ptr"
local DETACH_FRAMES = 8
local OBSERVE_FRAMES = 16
local APPROACH_ARRIVAL = 14
local APPROACH_MAX_SPEED = 7
local APPROACH_ACCEL = 0.2
local HOVER_OFFSET_Y = -24
local RETURN_ARRIVAL = 48
local RETURN_MAX_SPEED = 9
local RETURN_ACCEL = 0.25

local function ptr_of(ent)
	if not ent then return nil end
	local ok, h = pcall(GetPtrHash, ent)
	return ok and h or nil
end

local function get_dimension(level)
	local ok, dim = pcall(function() return level:GetDimension() end)
	if ok and dim ~= nil then return dim end
	return 0
end

--- Floor identity：Stage + StageType + Dimension（禁止 ListIndex）
local function floor_key()
	local level = Game():GetLevel()
	return table.concat({
		tostring(level:GetStage()),
		tostring(level:GetStageType()),
		tostring(get_dimension(level)),
	}, ":")
end

local function persist_bag()
	save.elses[item.own_key .. "run"] = save.elses[item.own_key .. "run"] or {}
	return save.elses[item.own_key .. "run"]
end

dogma_pickup_bag = function()
	local bag = persist_bag()
	-- generation_id → true；换层由 PRE_NEW_LEVEL 整袋清空。stale id 不复用，可不逐 pedestal 删。
	bag.dogma = bag.dogma or {}
	return bag.dogma
end

get_dogma_generation_id = function(pickup)
	if not pickup then return nil end
	-- resolve：同帧 copy 更可能直接拿到 id；DOGMA_PENDING_MARK 仍作安全网
	local gen = unique_holder.resolve_generation(pickup)
	if not gen or gen.id == nil then return nil end
	return tonumber(gen.id)
end

register_dogma_generation = function(gen_id)
	gen_id = tonumber(gen_id)
	if not gen_id then return false end
	dogma_pickup_bag()[tostring(gen_id)] = true
	return true
end

clear_dogma_runtime_cache = function(d)
	if type(d) ~= "table" then return end
	d[item.own_key .. DOGMA_COPY_GEN_ID] = nil
	d[item.own_key .. DOGMA_PENDING_MARK] = nil
	-- 旧版 DOGMA_COPY_FLAG 不得再当权威；一并清掉防残留
	d[item.own_key .. "dogma_copy"] = nil
end

--- 只重置 Baby Zeis dogma 写入的 Colorize 通道，不覆盖 Tint/Offset 业务态
reset_only_dogma_colorize_channels = function(sprite)
	if not sprite then return end
	local col = sprite.Color
	if not col or not col.SetColorize then return end
	local next_col = Color(col.R, col.G, col.B, col.A, col.RO, col.GO, col.BO)
	next_col:SetColorize(0, 0, 0, 0)
	sprite.Color = next_col
end

--- 已确认该有 → 挂 shader（不负责判定）
apply_pickup_dogma = function(pickup)
	if not pickup then return end
	local d = pickup:GetData()
	apply_zeis_dogma_sprite(pickup:GetSprite(), 0)
	d[item.own_key .. DOGMA_SHADER_FLAG] = true
end

--- 只清确认仍为 dogma chromatic 的 shader；禁止 fallback 无脑 ClearCustomShader
clear_pickup_dogma_visual = function(pickup)
	if not pickup then return end
	local d = pickup:GetData()
	local applied_key = item.own_key .. DOGMA_SHADER_FLAG
	if d[applied_key] ~= true then return end
	local hud = get_temp_hud()
	local sprite = pickup:GetSprite()
	local dogma_path = hud and hud.DOGMA_CHROMATIC_SHADER
	if hud and hud.clear_sprite_shader and sprite and sprite.HasCustomShader
		and dogma_path and sprite:HasCustomShader(dogma_path)
	then
		hud.clear_sprite_shader(sprite)
		reset_only_dogma_colorize_channels(sprite)
	end
	d[applied_key] = nil
end

--- 仅标记真正的 copy 自身；权威写入 dogma[generation_id]
mark_copy_dogma = function(pickup)
	if not pickup then return end
	if pickup.Type ~= EntityType.ENTITY_PICKUP then return end
	if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return end
	if (pickup.SubType or 0) <= 0 then return end
	local d = pickup:GetData()
	local gen_id = get_dogma_generation_id(pickup)
	if gen_id then
		register_dogma_generation(gen_id)
		d[item.own_key .. DOGMA_COPY_GEN_ID] = gen_id
		d[item.own_key .. DOGMA_PENDING_MARK] = nil
		d[item.own_key .. "dogma_copy"] = nil
	else
		-- Unique INIT 可能尚未写 generation；禁止 seed fallback / 禁止假 COPY_FLAG
		clear_dogma_runtime_cache(d)
		d[item.own_key .. DOGMA_PENDING_MARK] = true
	end
	apply_pickup_dogma(pickup)
end

try_resolve_pending_dogma = function(pickup)
	if not pickup then return end
	local d = pickup:GetData()
	if d[item.own_key .. DOGMA_PENDING_MARK] ~= true then return end
	local gen_id = get_dogma_generation_id(pickup)
	if not gen_id then return end
	register_dogma_generation(gen_id)
	d[item.own_key .. DOGMA_COPY_GEN_ID] = gen_id
	d[item.own_key .. DOGMA_PENDING_MARK] = nil
	d[item.own_key .. "dogma_copy"] = nil
end

--- 权威：仅 dogma_bag[current_gen]==true。DOGMA_COPY_GEN_ID 只是 cache，不得单独 return true。
pickup_wants_dogma = function(pickup)
	if not pickup then return false end
	if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return false end
	if (pickup.SubType or 0) <= 0 then
		clear_dogma_runtime_cache(pickup:GetData())
		return false
	end
	local d = pickup:GetData()
	try_resolve_pending_dogma(pickup)
	local current_gen = get_dogma_generation_id(pickup)
	if not current_gen then
		clear_dogma_runtime_cache(d)
		return false
	end
	local cached = tonumber(d[item.own_key .. DOGMA_COPY_GEN_ID])
	if cached ~= nil and cached ~= current_gen then
		-- D6 / seed-changing Morph 换了 generation：旧 cache 作废，不得继承 shader
		d[item.own_key .. DOGMA_COPY_GEN_ID] = nil
		d[item.own_key .. "dogma_copy"] = nil
	end
	if dogma_pickup_bag()[tostring(current_gen)] == true then
		d[item.own_key .. DOGMA_COPY_GEN_ID] = current_gen
		return true
	end
	clear_dogma_runtime_cache(d)
	return false
end

local function player_persist_key(player)
	if not player then return nil end
	return tostring(player.InitSeed)
end

--- 本层完成配额：宝宝可互换，只记 completed_count；运行时用 rt.finished（不按 familiar InitSeed）
local function player_run_bag(player)
	local key = player_persist_key(player)
	if not key then return nil end
	local bag = persist_bag()
	local st = bag[key]
	local fk = floor_key()
	if type(st) ~= "table" then
		st = { floor_key = fk, completed_count = 0 }
		bag[key] = st
	end
	if st.floor_key ~= fk then
		st.floor_key = fk
		st.completed_count = 0
	end
	if st.completed_count == nil then
		local n = 0
		if type(st.slots) == "table" then
			for _, slot_st in pairs(st.slots) do
				if type(slot_st) == "table" and slot_st.completed then
					n = n + 1
				end
			end
		end
		st.completed_count = n
		st.slots = nil
	end
	return st
end

local function completed_count(player)
	local st = player_run_bag(player)
	return (st and st.completed_count) or 0
end

local runtime

local function is_fam_finished(ent, _player)
	local rt = runtime(ent, false)
	return rt ~= nil and rt.finished == true
end

local function mark_fam_finished(ent, player)
	local rt = runtime(ent)
	if rt.finished then return end
	rt.finished = true
	local st = player_run_bag(player)
	if not st then return end
	st.completed_count = (st.completed_count or 0) + 1
end

--- 换房/重建后：按配额给第 1..N 个未完成宝宝补 finished（可互换）
local function sync_finished_quota(player)
	local need = completed_count(player)
	if need <= 0 then return end
	local fams = {}
	for _, fam in pairs(auxi.getothers(nil, 3, item.familiar) or {}) do
		local spawner = auxi.check_spawner_player(fam)
		if spawner and auxi.check_for_the_same(spawner, player) then
			table.insert(fams, fam)
		end
	end
	table.sort(fams, function(a, b)
		local sa = runtime(a).slot or 0
		local sb = runtime(b).slot or 0
		if sa ~= sb then return sa < sb end
		return (ptr_of(a) or 0) < (ptr_of(b) or 0)
	end)
	local have = 0
	for _, fam in ipairs(fams) do
		if runtime(fam).finished then have = have + 1 end
	end
	if have >= need then return end
	for _, fam in ipairs(fams) do
		if have >= need then break end
		local rt = runtime(fam)
		if not rt.finished then
			rt.finished = true
			have = have + 1
		end
	end
end

runtime = function(ent, create)
	local d = ent:GetData()
	local rt = d[item.own_key .. RT_KEY]
	if type(rt) ~= "table" and create ~= false then
		rt = {
			phase = PHASE.SLEEP,
			timer = 0,
			following = nil,
			slot = nil,
			finished = false,
			target_ref = nil,
		}
		d[item.own_key .. RT_KEY] = rt
	end
	return rt
end

local function ensure_following(ent, on)
	local rt = runtime(ent)
	local want = on == true
	if rt.following == want then
		if not want then
			Familiar_Follower_Arbiter.maintain(ent)
		end
		return
	end
	if want then
		Familiar_Follower_Arbiter.release(ent, FOLLOWER_OWNER)
		if ent.AddToFollowers then
			ent:AddToFollowers()
		end
	else
		Familiar_Follower_Arbiter.claim(ent, FOLLOWER_OWNER, { followers = true })
	end
	rt.following = want
end

local function release_target_owner(pickup, fam_ptr)
	if not pickup then return end
	local ok, td = pcall(function() return pickup:GetData() end)
	if not ok or type(td) ~= "table" then return end
	local key = item.own_key .. OWNER_KEY
	if fam_ptr == nil or td[key] == fam_ptr then
		td[key] = nil
	end
end

local function clear_target(ent)
	local rt = runtime(ent)
	local tg = rt.target_ref
	if tg then
		release_target_owner(tg, ptr_of(ent))
	end
	rt.target_ref = nil
end

local function set_target(ent, pickup)
	local rt = runtime(ent)
	clear_target(ent)
	if not pickup then return end
	pickup:GetData()[item.own_key .. OWNER_KEY] = ptr_of(ent)
	rt.target_ref = pickup
end

local function target_still_valid(ent)
	local rt = runtime(ent)
	local tg = rt.target_ref
	if auxi.check_all_exists(tg) ~= true then return false end
	if (tg.SubType or 0) <= 0 then return false end
	local owner = tg:GetData()[item.own_key .. OWNER_KEY]
	local self_ptr = ptr_of(ent)
	if owner ~= nil and self_ptr ~= nil and owner ~= self_ptr then
		return false
	end
	return true
end

local function find_pedestal(ent)
	local self_ptr = ptr_of(ent)
	return auxi.getothers(nil, 5, 100, nil, function(pick)
		if (pick.SubType or 0) == 0 then return false end
		local owner = pick:GetData()[item.own_key .. OWNER_KEY]
		if owner ~= nil and owner ~= self_ptr then
			-- 占用者仍存活则跳过
			local still = false
			for _, fam in pairs(auxi.getothers(nil, 3, item.familiar) or {}) do
				if ptr_of(fam) == owner and auxi.check_all_exists(fam) == true then
					still = true
					break
				end
			end
			if still then return false end
		end
		return true
	end)
end

--- 第 N 个宝宝：只给未分配者补号，不重排已有 slot（宝宝可互换，不绑 InitSeed）
local function slot_index(ent, player)
	local rt = runtime(ent)
	if rt.slot then return rt.slot end
	local used = {}
	local unassigned = {}
	for _, fam in pairs(auxi.getothers(nil, 3, item.familiar) or {}) do
		local spawner = auxi.check_spawner_player(fam)
		if spawner and auxi.check_for_the_same(spawner, player) then
			local frt = runtime(fam)
			if frt.slot then
				used[frt.slot] = true
			else
				table.insert(unassigned, fam)
			end
		end
	end
	table.sort(unassigned, function(a, b)
		return (ptr_of(a) or 0) < (ptr_of(b) or 0)
	end)
	for _, fam in ipairs(unassigned) do
		local i = 1
		while used[i] do i = i + 1 end
		runtime(fam).slot = i
		used[i] = true
	end
	return rt.slot
end

local function play_once(ent, anim)
	local s = ent:GetSprite()
	if s:GetAnimation() ~= anim then
		s:Play(anim, true)
	end
end

local function steer_to(ent, pos, max_speed, accel)
	local delta = pos - ent.Position
	local dist = delta:Length()
	if dist <= 0.01 then
		ent.Velocity = ent.Velocity * 0.8
		return dist
	end
	local desired = delta:Normalized() * math.min(max_speed, math.max(1, dist / 6))
	ent.Velocity = ent.Velocity * (1 - accel) + desired * accel
	return dist
end

local function hover_pos(tg)
	return tg.Position + Vector(0, HOVER_OFFSET_Y)
end

local enter_phase
local do_copy

local function abort_to_return(ent, player, slot)
	clear_target(ent)
	enter_phase(ent, player, slot, PHASE.RETURN)
end

enter_phase = function(ent, player, slot, new_phase)
	local rt = runtime(ent)
	if rt.phase == new_phase then return end
	rt.phase = new_phase
	rt.timer = 0
	Baby_Anim.reset(ent, item.own_key .. "float")
	Baby_Anim.reset(ent, item.own_key .. "sleep")

	if new_phase == PHASE.SLEEP then
		ensure_following(ent, true)
		play_once(ent, "SleepFloat")
	elseif new_phase == PHASE.WAKE then
		ensure_following(ent, true)
		play_once(ent, "Wake")
	elseif new_phase == PHASE.DETACH then
		ensure_following(ent, false)
		rt.timer = DETACH_FRAMES
		play_once(ent, "Float")
	elseif new_phase == PHASE.APPROACH then
		ensure_following(ent, false)
		play_once(ent, "Float")
	elseif new_phase == PHASE.OBSERVE then
		ensure_following(ent, false)
		rt.timer = OBSERVE_FRAMES
		play_once(ent, "Idle")
	elseif new_phase == PHASE.COPY then
		ensure_following(ent, false)
		play_once(ent, "Idle")
		do_copy(ent, player, slot)
	elseif new_phase == PHASE.RETURN then
		ensure_following(ent, false)
		play_once(ent, "Float")
	elseif new_phase == PHASE.DONE then
		ensure_following(ent, true)
		play_once(ent, "Float")
	end
end

do_copy = function(ent, player, slot)
	if not target_still_valid(ent) then
		abort_to_return(ent, player, slot)
		return
	end
	local tg = runtime(ent).target_ref
	local subtype = tg.SubType
	local room = Game():GetRoom()
	local copy = unique_holder.with_missing(33, function()
		local c = Isaac.Spawn(
			5,
			100,
			subtype,
			room:FindFreePickupSpawnPosition(ent.Position, 10, true),
			Vector.Zero,
			ent
		):ToPickup()
		if c then
			auxi.self_morph(c, { 5, 100, subtype })
		end
		return c
	end)
	if not copy then
		clear_target(ent)
		enter_phase(ent, player, slot, PHASE.RETURN)
		return
	end
	-- ownership 属于 copy B，不是 source A
	mark_copy_dogma(copy)
	spawn_copy_poof(copy.Position)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP, 1, 1, false, 0, 2)
	mark_fam_finished(ent, player)
	clear_target(ent)
	local rt = runtime(ent)
	rt.phase = PHASE.RETURN
	rt.timer = 0
	ensure_following(ent, false)
	play_once(ent, "Float")
end

local function update_sleep(ent, player, slot)
	ensure_following(ent, true)
	local s = ent:GetSprite()
	Baby_Anim.tick_float_idle(ent, item.own_key .. "sleep", item.sleep_opts)
	if Baby_Anim.is_float_idle_anim(s:GetAnimation(), item.sleep_opts) then
		ent:FollowParent()
	end
	if is_fam_finished(ent, player) then
		enter_phase(ent, player, slot, PHASE.DONE)
		return
	end
	local tgs = find_pedestal(ent)
	if #tgs > 0 then
		local q = auxi.random_in_table(tgs)
		set_target(ent, q)
		enter_phase(ent, player, slot, PHASE.WAKE)
	end
end

local function update_wake(ent, player, slot)
	if not target_still_valid(ent) then
		abort_to_return(ent, player, slot)
		return
	end
	ensure_following(ent, true)
	ent:FollowParent()
	local s = ent:GetSprite()
	if s:IsFinished("Wake") then
		enter_phase(ent, player, slot, PHASE.DETACH)
	elseif not s:IsPlaying("Wake") then
		s:Play("Wake", true)
	end
end

local function update_detach(ent, player, slot)
	if not target_still_valid(ent) then
		abort_to_return(ent, player, slot)
		return
	end
	ensure_following(ent, false)
	play_once(ent, "Float")
	ent.Velocity = ent.Velocity * 0.8
	local rt = runtime(ent)
	rt.timer = (rt.timer or 0) - 1
	if rt.timer <= 0 then
		enter_phase(ent, player, slot, PHASE.APPROACH)
	end
end

local function update_approach(ent, player, slot)
	if not target_still_valid(ent) then
		abort_to_return(ent, player, slot)
		return
	end
	ensure_following(ent, false)
	play_once(ent, "Float")
	local dist = steer_to(ent, hover_pos(runtime(ent).target_ref), APPROACH_MAX_SPEED, APPROACH_ACCEL)
	if dist <= APPROACH_ARRIVAL then
		enter_phase(ent, player, slot, PHASE.OBSERVE)
	end
end

local function update_observe(ent, player, slot)
	if not target_still_valid(ent) then
		abort_to_return(ent, player, slot)
		return
	end
	ensure_following(ent, false)
	play_once(ent, "Idle")
	steer_to(ent, hover_pos(runtime(ent).target_ref), 3, 0.15)
	ent.Velocity = ent.Velocity * 0.75
	local rt = runtime(ent)
	rt.timer = (rt.timer or 0) - 1
	if rt.timer <= 0 then
		enter_phase(ent, player, slot, PHASE.COPY)
	end
end

local function update_return(ent, player, slot)
	ensure_following(ent, false)
	play_once(ent, "Float")
	local player_pos = player.Position
	local dist = steer_to(ent, player_pos, RETURN_MAX_SPEED, RETURN_ACCEL)
	if dist <= RETURN_ARRIVAL then
		ent.Velocity = ent.Velocity * 0.3
		ensure_following(ent, true)
		if is_fam_finished(ent, player) then
			enter_phase(ent, player, slot, PHASE.DONE)
		else
			enter_phase(ent, player, slot, PHASE.SLEEP)
		end
	end
end

local function update_done(ent, player, slot)
	ensure_following(ent, true)
	local s = ent:GetSprite()
	Baby_Anim.tick_float_idle(ent, item.own_key .. "float", { locked = item.float_lock })
	if Baby_Anim.is_float_idle_anim(s:GetAnimation()) then
		ent:FollowParent()
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_EVALUATE_CACHE,
	params = nil,
	Function = function(_, player, cacheFlag)
		local cnt = player:GetCollectibleNum(item.entity) + player:GetEffects():GetCollectibleEffectNum(item.entity)
		if cacheFlag == CacheFlag.CACHE_FAMILIARS then
			player:CheckFamiliar(
				item.familiar,
				cnt,
				player:GetCollectibleRNG(item.entity),
				Isaac.GetItemConfig():GetCollectible(item.entity)
			)
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		if not continue then
			save.elses[item.own_key .. "run"] = {}
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function(_)
		save.elses[item.own_key .. "run"] = {}
		for _, v in pairs(auxi.getothers(nil, 3, item.familiar) or {}) do
			local rt = runtime(v)
			clear_target(v)
			rt.slot = nil
			rt.finished = false
			rt.phase = PHASE.SLEEP
			rt.timer = 0
			rt.following = nil
			ensure_following(v, true)
			Baby_Anim.reset(v, item.own_key .. "float")
			Baby_Anim.reset(v, item.own_key .. "sleep")
			v:GetSprite():Play("SleepFloat", true)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_INIT,
	params = item.familiar,
	Function = function(_, ent)
		local rt = runtime(ent)
		rt.phase = PHASE.SLEEP
		rt.following = nil
		-- finished 由 sync_finished_quota 按本层配额补齐（宝宝可互换）
		ensure_following(ent, true)
		ent:GetSprite():Play("SleepFloat", true)
		apply_zeis_dogma_sprite(ent:GetSprite(), 0)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE,
	params = 100,
	Function = function(_, pickup)
		try_resolve_pending_dogma(pickup)
		-- generation 驱动：Cycle/同 id 保留；D6 新 id → wants=false → 立即清视觉
		-- persistence stale id 可残留至换层；不在 PRE_COLLISION 猜是否收购
		if pickup_wants_dogma(pickup) then
			apply_pickup_dogma(pickup)
		else
			clear_pickup_dogma_visual(pickup)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_UPDATE,
	params = item.familiar,
	Function = function(_, ent)
		apply_zeis_dogma_sprite(ent:GetSprite(), 0)
		local player = auxi.check_spawner_player(ent)
		if not player then return end
		local slot = slot_index(ent, player)
		if not slot then return end
		sync_finished_quota(player)
		local rt = runtime(ent)
		-- 本层该宝宝已完成：强制 DONE（换房不得因 ListIndex 重置）
		if is_fam_finished(ent, player) and rt.phase ~= PHASE.RETURN and rt.phase ~= PHASE.COPY then
			if rt.phase ~= PHASE.DONE then
				clear_target(ent)
				enter_phase(ent, player, slot, PHASE.DONE)
			end
		end

		local phase = rt.phase or PHASE.SLEEP
		if phase == PHASE.SLEEP then
			update_sleep(ent, player, slot)
		elseif phase == PHASE.WAKE then
			update_wake(ent, player, slot)
		elseif phase == PHASE.DETACH then
			update_detach(ent, player, slot)
		elseif phase == PHASE.APPROACH then
			update_approach(ent, player, slot)
		elseif phase == PHASE.OBSERVE then
			update_observe(ent, player, slot)
		elseif phase == PHASE.COPY then
			-- enter 已处理；兜底进 RETURN
			if not is_fam_finished(ent, player) then
				abort_to_return(ent, player, slot)
			else
				enter_phase(ent, player, slot, PHASE.RETURN)
			end
		elseif phase == PHASE.RETURN then
			update_return(ent, player, slot)
		else
			update_done(ent, player, slot)
		end
	end,
})

return item

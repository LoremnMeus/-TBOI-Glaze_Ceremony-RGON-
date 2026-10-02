-- 妖刀·逢魔：妖鬼重塑玩家。
-- 属性/资源/恶魔↔星象：灵质守恒；天使节点：Deal 分配重塑（无灵质）。
-- HUD 拓扑 + 定长软体 + Q/E 加减（输入重复/缓冲）+ RGON 资源上限 / 天魔 / 星象。
-- Compatibility policy:
--   Book of Virtues: disabled by content/wisps.xml id=65 count=0.
--   Book of Belial passive: intentionally no Spectralsword synergy.
-- 旧铭刻系统见 systems/item_inscription.lua

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")

local hud_nodes = require("Qing_Remaster_scripts.items.spectralsword.hud_nodes")
local ghost_controller = require("Qing_Remaster_scripts.items.spectralsword.ghost_controller")
local spirit_vfx = require("Qing_Remaster_scripts.items.spectralsword.spirit_vfx")
local hud_render = require("Qing_Remaster_scripts.items.spectralsword.hud_render")
local input_repeater = require("Qing_Remaster_scripts.items.spectralsword.input_repeater")
local angel_reshape = require("Qing_Remaster_scripts.items.spectralsword.angel_reshape")
local deal_chance_holder = require("Qing_Remaster_scripts.callbacks.deal_chance_holder")
local deal_chance_semantics = require("Qing_Remaster_scripts.auxiliary.deal_chance_semantics")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Spectralsword,
	own_key = "Item_Spectralsword_",
	session = nil,
	INITIAL_ESSENCE = {stat = 0, resource = 0, chance = 0},
	DEBUG_SOFTBODY = false,
	-- 仅影响支付/消耗；pdata.essence 与 VFX 仍用真实有限值。不进存档。
	DEBUG_INFINITE_SPIRIT = false,
	-- 调试：强制视为 Seija 削弱（extract 50% 不产灵质）。不进存档。
	DEBUG_FORCE_SEIJA = false,
}

local CACHE_ALL = CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_RANGE |
	CacheFlag.CACHE_SPEED | CacheFlag.CACHE_LUCK | CacheFlag.CACHE_SHOTSPEED

local CAP_TAGS = {"maxcoins", "maxbombs", "maxkeys"}

local STAT_DEF = {
	speed = {
		cache = CacheFlag.CACHE_SPEED,
		apply = function(player, d) player.MoveSpeed = player.MoveSpeed + d end,
	},
	tears = {
		cache = CacheFlag.CACHE_FIREDELAY,
		apply = function(player, d) player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay, d) end,
	},
	damage = {
		cache = CacheFlag.CACHE_DAMAGE,
		apply = function(player, d) player.Damage = player.Damage + auxi.get_damage_multiplier(player) * d end,
	},
	range = {
		cache = CacheFlag.CACHE_RANGE,
		apply = function(player, d) player.TearRange = player.TearRange + d * 40 end,
	},
	shotspeed = {
		cache = CacheFlag.CACHE_SHOTSPEED,
		apply = function(player, d) player.ShotSpeed = player.ShotSpeed + d end,
	},
	luck = {
		cache = CacheFlag.CACHE_LUCK,
		apply = function(player, d) player.Luck = player.Luck + d end,
	},
}

local blocked_panel_actions = {
	[ButtonAction.ACTION_LEFT] = true,
	[ButtonAction.ACTION_RIGHT] = true,
	[ButtonAction.ACTION_UP] = true,
	[ButtonAction.ACTION_DOWN] = true,
	[ButtonAction.ACTION_SHOOTLEFT] = true,
	[ButtonAction.ACTION_SHOOTRIGHT] = true,
	[ButtonAction.ACTION_SHOOTUP] = true,
	[ButtonAction.ACTION_SHOOTDOWN] = true,
	[ButtonAction.ACTION_DROP] = true,
	[ButtonAction.ACTION_PILLCARD] = true,
	[ButtonAction.ACTION_MAP] = true,
	[ButtonAction.ACTION_BOMB] = true,
	[ButtonAction.ACTION_ITEM] = true,
	[ButtonAction.ACTION_CONSOLE] = true,
	[ButtonAction.ACTION_MENUBACK] = true,
	[ButtonAction.ACTION_MENUTAB] = true,
	[ButtonAction.ACTION_FULLSCREEN] = true,
	[ButtonAction.ACTION_MUTE] = true,
	[ButtonAction.ACTION_RESTART] = true,
}

local function lang_zh()
	local language = Options and Options.Language or ""
	return language == "zh" or language == "zh_cn" or language == "zh_CN"
end

local function player_key(player)
	if not player then return nil end
	local data = player:GetData()
	if data and data.__Index ~= nil then
		return tostring(data.__Index)
	end
	-- 极早期 fallback：__Index 尚未写入时
	return tostring(player.InitSeed)
end

local function run_store()
	save.elses = save.elses or {}
	save.elses[item.own_key .. "reshape"] = save.elses[item.own_key .. "reshape"] or {}
	return save.elses[item.own_key .. "reshape"]
end

function item.get_shared_caps(create)
	save.elses = save.elses or {}
	local key = item.own_key .. "shared_caps"
	if save.elses[key] == nil and create then
		save.elses[key] = hud_nodes.empty_caps()
	end
	local caps = save.elses[key]
	if caps then
		for _, k in ipairs(hud_nodes.CAP_KEYS) do
			caps[k] = caps[k] or 0
		end
	end
	return caps
end

local function deal_bag()
	save.elses = save.elses or {}
	local key = item.own_key .. "deal_sync"
	save.elses[key] = save.elses[key] or {level_angel_applied = 0}
	return save.elses[key]
end

-- Planetarium 显示：cached = 原生 Stat HUD 镜像；live = 低频 getter 采样；delta = live - cached。
-- 禁止在 MC_POST_RENDER 每帧调 GetPlanetariumChance。
local PLANETARIUM_LIVE_SAMPLE_INTERVAL = 30 -- Game():GetFrameCount() 30Hz
local planetarium_live = nil
local planetarium_live_frame = -1

local function read_planetarium_getter()
	local level = Game():GetLevel()
	if not level or not level.GetPlanetariumChance then
		return 0
	end
	local ok, value = pcall(function()
		return level:GetPlanetariumChance()
	end)
	if not ok then
		return 0
	end
	return math.max(0, math.min(1, tonumber(value) or 0))
end

--- 不调用任何 Planetarium holder API（holder 已不拥有 Planetarium）。
function item.capture_planetarium_hud_cache()
	local live = read_planetarium_getter()
	local bag = deal_bag()
	bag.planetarium_hud_cache = live
	bag.planetarium_hud_cache_valid = true
	planetarium_live = live
	planetarium_live_frame = Game():GetFrameCount()
	return live
end

--- 采样实时 Planetarium chance；force=true 时无视间隔（打开面板 / Q/E 后）。
function item.sample_planetarium_live(force)
	local frame = Game():GetFrameCount()
	if not force and planetarium_live ~= nil and planetarium_live_frame >= 0 then
		if frame == planetarium_live_frame then
			return planetarium_live
		end
		if (frame - planetarium_live_frame) < PLANETARIUM_LIVE_SAMPLE_INTERVAL then
			return planetarium_live
		end
	end
	local live = read_planetarium_getter()
	planetarium_live = live
	planetarium_live_frame = frame
	return live
end

--- 妖刀 HUD 视图：主值=cached，后缀=live-cached（非零才画）。
function item.get_planetarium_hud_view()
	local bag = deal_bag()
	local live = planetarium_live
	if live == nil then
		live = item.sample_planetarium_live(true)
	end
	local cached = tonumber(bag.planetarium_hud_cache)
	if bag.planetarium_hud_cache_valid ~= true or cached == nil then
		cached = live
	end
	return {
		cached = cached,
		live = live,
		delta = live - cached,
	}
end

--- 纯读：calculation callback / getter 重入路径不得走 normalize。
local function peek_player_data(player)
	if not player then return nil end
	local store = run_store()
	local key = player_key(player)
	if key == nil then return nil end
	return store[key]
end

--- 本局所有已有妖刀重塑记录玩家的 deal modifier 求和（天魔/星象/转化均为层/全局语义）。
--- 失去妖刀不撤销已完成重塑；持有只是编辑入口。
--- 必须用 peek：POST_*_CALCULATE 可能由 Get*Chance 重入，禁止顺带 normalize。
local function sum_deal_modifier(field)
	local total = 0
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p then
			local pdata = peek_player_data(p)
			if pdata and pdata.modifiers then
				total = total + (tonumber(pdata.modifiers[field]) or 0)
			end
		end
	end
	return total
end

local function sync_level_angel_conversion()
	local level = Game():GetLevel()
	if not level or not level.AddAngelRoomChance then return end
	local bag = deal_bag()
	local want = sum_deal_modifier("angel")
	local applied = tonumber(bag.level_angel_applied) or 0
	if want ~= applied then
		level:AddAngelRoomChance(want - applied)
		bag.level_angel_applied = want
	end
end

--- 原地 normalize：已有 modifiers/essence table 绝不能因普通 getter 被换掉（cd528c3d copy-on-read 回归）。
local function normalize_pdata(pdata)
	if not pdata then return nil end

	if type(pdata.modifiers) ~= "table" then
		pdata.modifiers = hud_nodes.empty_modifiers()
	end
	local mods = pdata.modifiers
	for _, key in ipairs(hud_nodes.STAT_KEYS) do
		mods[key] = tonumber(mods[key]) or 0
	end
	for _, key in ipairs(hud_nodes.DEAL_KEYS) do
		mods[key] = tonumber(mods[key]) or 0
	end
	mods.max_coins = nil
	mods.max_bombs = nil
	mods.max_keys = nil

	-- LEGACY-SAVE-001: 旧 pending_planetarium one-shot → 永久 modifiers.planetarium
	local bag = deal_bag()
	local pending = tonumber(bag.pending_planetarium) or 0
	if math.abs(pending) > 1e-9 and not bag.pending_planetarium_migrated then
		mods.planetarium = (tonumber(mods.planetarium) or 0) + pending
		bag.pending_planetarium = 0
		bag.consume_planetarium_on_next_calc = false
		bag.pending_planetarium_migrated = true
	end

	if type(pdata.essence) ~= "table" then
		pdata.essence = hud_nodes.copy_essence(item.INITIAL_ESSENCE)
	else
		local ess = pdata.essence
		for _, key in ipairs(hud_nodes.ESSENCE_KINDS) do
			local v = ess[key]
			if v ~= math.huge then
				ess[key] = math.max(0, math.floor(tonumber(v) or 0))
			end
		end
	end
	return pdata
end

function item.get_player_data(player, create)
	local store = run_store()
	local key = player_key(player)
	if store[key] == nil and create then
		store[key] = {
			essence = hud_nodes.copy_essence(item.INITIAL_ESSENCE),
			modifiers = hud_nodes.empty_modifiers(),
			last_node = nil,
		}
	end
	local pdata = store[key]
	if not pdata then return nil end
	local mods_before = pdata.modifiers
	local essence_before = pdata.essence
	normalize_pdata(pdata)
	-- 开发树 identity 断言：封死 copy-on-read 回归
	local env = require("Qing_Remaster_scripts.core.dev_environment")
	if not env.is_public_release() then
		if mods_before ~= nil and pdata.modifiers ~= mods_before then
			error("[Spectralsword] normalize_pdata replaced modifiers table identity")
		end
		if essence_before ~= nil and pdata.essence ~= essence_before then
			error("[Spectralsword] normalize_pdata replaced essence table identity")
		end
	end
	return pdata
end

local function has_active_enemies()
	local room = Game():GetRoom()
	if not room then return false end
	if room.GetAliveEnemiesCount then
		return room:GetAliveEnemiesCount() > 0
	end
	return not room:IsClear()
end

local function pause_menu_open()
	return auxi.is_pause_menu_open()
end

function item.get_stat_hud_anchor(stat_index, player)
	return hud_nodes.get_stat_hud_anchor(stat_index, player)
end

local function apply_stat_cache(player)
	player:AddCacheFlags(CACHE_ALL)
	player:EvaluateItems()
end

local function refresh_cap_cache(player, tag)
	if not player or not player.AddCustomCacheTag then return end
	if tag then
		player:AddCustomCacheTag(tag, true)
	else
		player:AddCustomCacheTag(CAP_TAGS, true)
	end
end

local function session_exists()
	return item.session ~= nil
		and item.session.ghost ~= nil
		and item.session.ghost.active == true
end

local function session_interactive()
	return session_exists()
		and item.session.closing ~= true
		and item.session.presentation_only ~= true
end

--- @deprecated use session_exists / session_interactive
local function session_active()
	return session_exists()
end

local function player_screen_pos(player)
	local cfg = ghost_controller.get_spawn_config and ghost_controller.get_spawn_config() or {}
	local y = cfg.orbit_center_y or -10
	if auxi.get_entity_screen_pos then
		local pos = auxi.get_entity_screen_pos(player)
		if pos then
			return pos + Vector(0, y)
		end
	end
	local room = Game():GetRoom()
	if room and room.WorldToScreenPosition then
		return room:WorldToScreenPosition(player.Position + player.PositionOffset + Vector(0, y))
	end
	return Isaac.WorldToScreen(player.Position + Vector(0, y))
end

local function sword_screen_anchor(player)
	local cfg = ghost_controller.get_spawn_config and ghost_controller.get_spawn_config() or {}
	local local_off = Vector(cfg.sword_anchor_x or 0, cfg.sword_anchor_y or -20)
	if auxi.get_held_item_screen_anchor then
		local pos = auxi.get_held_item_screen_anchor(player, nil, local_off)
		if pos then return pos end
	end
	return player_screen_pos(player) + local_off
end

--- 举起妖刀：世界继续跑，玩家操作被面板接管（不用 time_stop）。
local function show_held_item(player)
	if not player then return end
	pcall(function()
		if player.IsHoldingItem and player:IsHoldingItem() then
			player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
		end
		player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
	end)
end

local function hide_held_item(player)
	if not player then return end
	pcall(function()
		if player.IsHoldingItem and player:IsHoldingItem() then
			player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
		end
	end)
end

local function close_session(immediate)
	local sess = item.session
	if sess == nil then return end
	local player = sess.player
	if sess.input then
		input_repeater.clear(sess.input)
	end
	sess.input_armed = false
	if immediate or not sess.ghost or not sess.ghost.active then
		if player then selection_holder.remove_select(player, "Spectralsword") end
		hide_held_item(player)
		spirit_vfx.clear(sess.vfx)
		item.session = nil
		return
	end
	-- 正常退出：妖鬼 RETURN→SINK 期间继续举刀，finish_close 再 HideItem
	local return_target = player_screen_pos(player)
	ghost_controller.request_exit(sess.ghost, return_target)
	sess.closing = true
end

local function finish_close()
	local sess = item.session
	if sess == nil then return end
	local player = sess.player
	if sess.input then
		input_repeater.clear(sess.input)
	end
	if player then selection_holder.remove_select(player, "Spectralsword") end
	hide_held_item(player)
	spirit_vfx.clear(sess.vfx)
	item.session = nil
end

local function open_session(player)
	if session_exists() then return false end
	if has_active_enemies() then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 1, 1, false, 0, 1)
		return false
	end
	local pdata = item.get_player_data(player, true)
	item.get_shared_caps(true)
	local essence_before_open = hud_nodes.copy_essence(pdata.essence)
	-- 先举起，再读 HeldSprite.Offset，才能与刀对齐
	show_held_item(player)
	local sword_anchor = sword_screen_anchor(player)
	local orbit_center = player_screen_pos(player)
	local ctx = hud_nodes.get_hud_context(player)
	local presentation_only = ctx.no_hud_seed == true
	local start_node = nil
	local ghost
	if presentation_only then
		ghost = ghost_controller.create_ghost({
			sword_anchor = sword_anchor,
			orbit_center = orbit_center,
			entry_mode = "orbit_return",
			orbit_revs = 1.0,
			target_node_id = nil,
		})
	else
		start_node = hud_nodes.resolve_start_node(pdata.last_node, player, ctx)
		ghost = ghost_controller.create_ghost({
			sword_anchor = sword_anchor,
			orbit_center = orbit_center,
			entry_mode = "hud",
			target_node_id = start_node,
		})
		local node = hud_nodes.get(start_node)
		if node then
			if node.get_ghost_anchor then
				ghost.target_pos = node.get_ghost_anchor(player)
			elseif node.get_anchor then
				ghost.target_pos = node.get_anchor(player)
			end
			if node.get_anchor then
				ghost.hud_anchor = node.get_anchor(player)
			end
		end
		if start_node then
			pdata.last_node = start_node
		end
	end
	ghost.debug = item.DEBUG_SOFTBODY == true
	local vfx = spirit_vfx.create()
	-- 只把库存投影成 orbit；禁止打开面板本身赠送灵质。
	spirit_vfx.set_spirit_visual(vfx, ghost, pdata.essence, {immediate = true})
	local essence_after_open = hud_nodes.copy_essence(pdata.essence)
	if essence_before_open.stat ~= essence_after_open.stat
		or essence_before_open.resource ~= essence_after_open.resource
		or essence_before_open.chance ~= essence_after_open.chance
	then
		Isaac.DebugString("[Spectralsword] open_session mutated essence; restoring snapshot")
		pdata.essence = essence_before_open
		spirit_vfx.set_spirit_visual(vfx, ghost, pdata.essence, {immediate = true})
	end
	item.session = {
		player = player,
		ghost = ghost,
		vfx = vfx,
		input = input_repeater.create(),
		closing = false,
		input_armed = false,
		wait_input_release = true,
		was_paused = false,
		presentation_only = presentation_only,
		hud_context = ctx,
	}
	if not presentation_only then
		selection_holder.try_select(player, "Spectralsword")
		-- 打开面板：采样 live（不改动原生 HUD 镜像 cache）
		item.sample_planetarium_live(true)
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_GROW, 0.7, 1.2, false, 0, 1)
	return true
end

local function lacks_required_essence(node, essence)
	if not node or not node.essence_kind then
		return false
	end
	local need = node.spirit_value or 1
	local have = essence and essence[node.essence_kind] or 0
	return have + 0.001 < need
end

local function fail_notice(reason, node_id, essence)
	local zh = lang_zh()
	if reason == "locked" then
		return zh and "尚未开放" or "Locked"
	end
	if reason == "unavailable" then
		return zh and "无法操作" or "Cannot"
	end
	local node = hud_nodes.get(node_id)
	local kind = node and node.essence_kind
	local need = (node and node.spirit_value) or 1
	local have = essence and essence[kind] or 0
	if reason == "cannot" and kind and (have == nil or have + 0.001 < need) and not item.DEBUG_INFINITE_SPIRIT then
		if kind == "stat" then
			return zh and "紫灵质不足" or "Need purple essence"
		elseif kind == "resource" then
			return zh and "金灵质不足" or "Need gold essence"
		elseif kind == "chance" then
			return zh and "青灵质不足" or "Need cyan essence"
		end
		return zh and "灵质不足" or "Not enough essence"
	end
	if reason == "cannot" and node and node.group == "resource" then
		return zh and "已达上限" or "At cap"
	end
	if reason == "cannot" and node and node.group == "resource_cap" then
		return zh and "不能低于持有量" or "Below held"
	end
	if reason == "cannot" then
		return zh and "无法操作" or "Cannot"
	end
	return zh and "失败" or "Failed"
end

local function action_ctx(player, pdata)
	local ess
	if item.DEBUG_INFINITE_SPIRIT then
		ess = {stat = math.huge, resource = math.huge, chance = math.huge}
	else
		ess = pdata.essence
	end
	local bag = deal_bag()
	local applied = tonumber(bag.level_angel_applied) or 0
	local player_sword = tonumber(pdata.modifiers and pdata.modifiers.angel) or 0
	return {
		modifiers = pdata.modifiers,
		caps = item.get_shared_caps(true),
		essence = ess,
		angel_reshape_opts = {
			applied_sword_x = applied,
			player_sword_x = player_sword,
		},
	}
end

local function read_deal_display(side)
	local snap = deal_chance_semantics.snapshot({allow_getter_fallback = true})
	return tonumber(snap and snap.display and snap.display[side]) or 0
end

--- 解析反解 modifiers.devil，使 Devil HUD（或 Duality 下总 Deal）精确落到 target。
--- DevilHUD = min(T,1) * S；固定 S 时 T_target = H_target / S。
local DEVIL_DISPLAY_MATCH = 1e-6

local function set_devil_display_target(pdata, target, action)
	if not pdata or not pdata.modifiers then return end
	target = math.max(0, math.min(1, tonumber(target) or 0))

	deal_chance_holder.refresh_total_deal()
	local snap = deal_chance_semantics.snapshot({allow_getter_fallback = true})
	local duality = deal_chance_semantics.has_duality()
	local S = 1.0
	if not duality then
		S = tonumber(snap.split and snap.split.devil_share) or 0
	end

	local player_sword = tonumber(pdata.modifiers.devil) or 0
	local sword_sum = sum_deal_modifier("devil")
	local others = sword_sum - player_sword
	local T_now = tonumber(snap.internal and snap.internal.modified_total) or 0
	local external = T_now - sword_sum

	local blocked_reason = nil
	local T_target
	if duality then
		T_target = target
	elseif S <= 1e-12 then
		blocked_reason = "zero_devil_share"
		T_target = nil
	else
		T_target = target / S
	end

	local new_sword = player_sword
	if T_target ~= nil and blocked_reason == nil then
		local sword_sum_target = T_target - external
		new_sword = sword_sum_target - others
		new_sword = hud_nodes.clamp_deal_mod(new_sword)
		if math.abs(new_sword - (sword_sum_target - others)) > 1e-9 then
			-- 钳制后仍尽量接近
			blocked_reason = nil
		end
	end

	pdata.modifiers.devil = new_sword
	deal_chance_holder.refresh_total_deal()
	local display_after
	if duality then
		local snap2 = deal_chance_semantics.snapshot({allow_getter_fallback = true})
		display_after = tonumber(snap2.display and snap2.display.total) or 0
	else
		display_after = read_deal_display("devil")
	end
	local solver_error = display_after - target
	if blocked_reason == nil and math.abs(solver_error) > DEVIL_DISPLAY_MATCH then
		blocked_reason = "display_mismatch"
	end

	return {
		target = target,
		display_after = display_after,
		solver_error = solver_error,
		duality = duality,
		blocked_reason = blocked_reason,
	}
end

--- 按 angel_plan 只写本玩家 modifiers.angel（delta → AddAngelRoomChance）。
local function apply_angel_plan(pdata, plan)
	if not pdata or not pdata.modifiers or not plan or plan.kind == "blocked" then
		return nil
	end
	local bag = deal_bag()
	local applied = tonumber(bag.level_angel_applied) or 0
	local player_sword = tonumber(pdata.modifiers.angel) or 0
	local bounds = angel_reshape.x_bounds(applied, player_sword)
	local others = applied - player_sword
	local new_sword = select(1, angel_reshape.sword_delta_for_target_x(
		plan.target_x,
		bounds.external_x,
		others,
		player_sword
	))
	new_sword = hud_nodes.clamp_deal_mod(new_sword)
	pdata.modifiers.angel = new_sword
	sync_level_angel_conversion()
	local after = angel_reshape.evaluate_angel_display_at(
		(Game():GetLevel() and Game():GetLevel().GetAngelRoomChance
			and Game():GetLevel():GetAngelRoomChance()) or plan.target_x
	)
	return {
		side = "angel",
		display_before = plan.current,
		target = plan.target,
		display_after = after.angel,
		actual_delta = after.angel - (plan.current or 0),
		solver_error = after.angel - (plan.target or after.angel),
		angel_kind = plan.kind,
		target_x = plan.target_x,
	}
end

--- action: "extract" | "inject"
local function apply_deal_result(result, pdata, snap_before, action)
	if not result then return nil end
	if result.deal_semantic == "planetarium" then
		local live_before = planetarium_live
		-- modifier 已写入 → 采样 Level:GetPlanetariumChance()；不写 HUD cache
		local live = item.sample_planetarium_live(true)
		return {
			side = "planetarium",
			display_before = live_before,
			display_after = live,
			target = live,
			actual_delta = (live or 0) - (live_before or 0),
		}
	end
	if result.deal_semantic == "angel_conversion" then
		local plan = result.angel_plan
		if not plan then
			local dir = action == "inject" and 1 or -1
			local ctx = action_ctx(nil, pdata)
			plan = angel_reshape.find_angel_target(dir, ctx.angel_reshape_opts)
		end
		local meta = apply_angel_plan(pdata, plan)
		return meta
	end
	if result.deal_semantic == "deal" then
		local side = result.node and result.node.id
		if side == "devil" and snap_before and snap_before.display then
			local duality = deal_chance_semantics.has_duality()
			local current
			if duality then
				current = tonumber(snap_before.display.total) or 0
			else
				current = tonumber(snap_before.display.devil) or 0
			end
			local step = hud_nodes.DEAL_STEP or 0.05
			local target
			if action == "inject" then
				local delta = math.min(step, math.max(0, 1.0 - current))
				target = math.min(1.0, current + delta)
			else
				local delta = math.min(step, math.max(0, current))
				target = math.max(0.0, current - delta)
			end
			local solved = set_devil_display_target(pdata, target, action)
			return {
				side = side,
				display_before = current,
				target = target,
				display_after = solved and solved.display_after,
				actual_delta = solved and ((solved.display_after or 0) - current),
				solver_error = solved and solved.solver_error,
				duality = duality,
			}
		else
			deal_chance_holder.refresh_total_deal()
			sync_level_angel_conversion()
		end
	end
	return nil
end

--- Seija 削弱：抽取成功后 50% 不产灵质（数值已扣除）。inject 不受影响。
--- 玩家主动 Q 抽取 → 是否获得灵质：必须走道具绑定 Isaac RNG，禁止 auxi.random_1。
local function should_lose_extract_essence(player)
	if item.DEBUG_INFINITE_SPIRIT then
		return false
	end
	local seija = item.DEBUG_FORCE_SEIJA == true
		or (player and auxi.should_do_Seija(player) == true)
	if not seija or not player then
		return false
	end
	local rng = player:GetCollectibleRNG(item.entity)
	return rng:RandomFloat() < 0.5
end

local function do_extract(sess)
	local player = sess.player
	local pdata = item.get_player_data(player, true)
	local ghost = sess.ghost
	local snap_before = deal_chance_semantics.snapshot({allow_getter_fallback = true})
	local result = hud_nodes.try_extract(player, ghost.target_node, action_ctx(player, pdata))
	if not result.ok then
		return {ok = false, reason = result.reason, notice = fail_notice(result.reason, ghost.target_node, pdata.essence)}
	end
	local skip_essence = result.essence_kind == nil
	local kind = result.essence_kind or "stat"
	local before = hud_nodes.copy_essence(pdata.essence)
	local nominal_delta = result.essence_delta or 0
	local seija_lost = false
	local actual_delta = 0
	if not skip_essence then
		nominal_delta = result.essence_delta or 1
		seija_lost = should_lose_extract_essence(player)
		actual_delta = seija_lost and 0 or nominal_delta
		if actual_delta > 0 then
			pdata.essence[kind] = (pdata.essence[kind] or 0) + actual_delta
		end
	end
	local after = hud_nodes.copy_essence(pdata.essence)
	local node = hud_nodes.get(ghost.target_node)
	if not skip_essence then
		local from = node and node.get_anchor(player) or ghost.hud_anchor or ghost.target_pos
		spirit_vfx.spawn_extract(sess.vfx, from, ghost.head_pos, {
			visual_count = 1,
			essence_kind = kind,
			essence_before = before,
			essence_after = after,
			dissipate = seija_lost,
			ghost = ghost,
		})
		spirit_vfx.set_spirit_visual(sess.vfx, ghost, after)
	end
	if result.needs_stat_cache then apply_stat_cache(player) end
	if result.needs_cap_cache then refresh_cap_cache(player, result.cache_tag) end
	local apply_meta = apply_deal_result(result, pdata, snap_before, "extract")
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_TOOTH_AND_NAIL, 0.8, 1.25, false, 0, 2)
	ghost.notice = nil
	local out = {
		ok = true,
		essence_kind = skip_essence and nil or kind,
		essence_nominal_delta = nominal_delta,
		essence_delta = actual_delta,
		spirit_delta = actual_delta,
		seija_lost_essence = seija_lost,
		node_id = ghost.target_node,
		deal_semantic = result.deal_semantic,
		angel_kind = apply_meta and apply_meta.angel_kind,
	}
	return out
end

local function do_inject(sess)
	local player = sess.player
	local pdata = item.get_player_data(player, true)
	local ghost = sess.ghost
	local snap_before = deal_chance_semantics.snapshot({allow_getter_fallback = true})
	local result = hud_nodes.try_inject(player, ghost.target_node, action_ctx(player, pdata))
	if not result.ok then
		local node = hud_nodes.get(ghost.target_node)
		if result.reason == "cannot"
			and not item.DEBUG_INFINITE_SPIRIT
			and lacks_required_essence(node, pdata.essence)
		then
			sound_tracker.PlayStackedSound(
				SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ,
				0.7,
				1.1,
				false,
				0,
				1
			)
		end
		return {
			ok = false,
			reason = result.reason,
			notice = fail_notice(result.reason, ghost.target_node, pdata.essence),
		}
	end
	local skip_essence = result.essence_kind == nil
	local kind = result.essence_kind or "stat"
	local before = hud_nodes.copy_essence(pdata.essence)
	local delta = 0
	if not skip_essence then
		delta = result.essence_delta or -1
		if not item.DEBUG_INFINITE_SPIRIT then
			pdata.essence[kind] = math.max(0, (pdata.essence[kind] or 0) + delta)
		end
	end
	local after = hud_nodes.copy_essence(pdata.essence)
	local node = hud_nodes.get(ghost.target_node)
	if not skip_essence then
		local to = node and node.get_anchor(player) or ghost.hud_anchor or ghost.target_pos
		spirit_vfx.spawn_inject(sess.vfx, to, {
			visual_count = 1,
			essence_kind = kind,
			essence_before = before,
			essence_after = after,
			node_id = ghost.target_node,
			from = ghost.head_pos,
		})
		spirit_vfx.set_spirit_visual(sess.vfx, ghost, after)
	end
	if result.needs_stat_cache then apply_stat_cache(player) end
	if result.needs_cap_cache then refresh_cap_cache(player, result.cache_tag) end
	local apply_meta = apply_deal_result(result, pdata, snap_before, "inject")
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_NICKELPICKUP, 1, 1.1, false, 0, 1)
	ghost.notice = nil
	local out = {
		ok = true,
		essence_kind = skip_essence and nil or kind,
		essence_delta = delta,
		spirit_delta = delta,
		node_id = ghost.target_node,
		deal_semantic = result.deal_semantic,
		angel_kind = apply_meta and apply_meta.angel_kind,
	}
	return out
end

local function peek_action_pressed(ctrl, btn)
	item._reading_input = true
	local held = Input.IsActionPressed(btn, ctrl)
	item._reading_input = false
	return held
end

local function peek_button_pressed(key)
	item._reading_input = true
	local held = Input.IsButtonPressed(key, 0)
	item._reading_input = false
	return held
end

local function peek_button_triggered(key)
	item._reading_input = true
	local trig = Input.IsButtonTriggered(key, 0)
	item._reading_input = false
	return trig
end

local function peek_action_triggered(ctrl, btn)
	item._reading_input = true
	local trig = Input.IsActionTriggered(btn, ctrl)
	item._reading_input = false
	return trig
end

local function panel_inputs_held(sess)
	local player = sess and sess.player
	if not player then return false end
	local ctrl = player.ControllerIndex
	if peek_action_pressed(ctrl, ButtonAction.ACTION_SHOOTUP)
		or peek_action_pressed(ctrl, ButtonAction.ACTION_SHOOTDOWN)
		or peek_action_pressed(ctrl, ButtonAction.ACTION_SHOOTLEFT)
		or peek_action_pressed(ctrl, ButtonAction.ACTION_SHOOTRIGHT)
	then
		return true
	end
	if Keyboard then
		return peek_button_pressed(Keyboard.KEY_UP)
			or peek_button_pressed(Keyboard.KEY_DOWN)
			or peek_button_pressed(Keyboard.KEY_LEFT)
			or peek_button_pressed(Keyboard.KEY_RIGHT)
			or peek_button_pressed(Keyboard.KEY_Q)
			or peek_button_pressed(Keyboard.KEY_E)
			or peek_button_pressed(Keyboard.KEY_ESCAPE)
	end
	return false
end

local function note_input_for_probe(sess, sample)
	local env = require("Qing_Remaster_scripts.core.dev_environment")
	if not env.probes_allowed() then return end
	local probe = env.require_probe("Qing_Remaster_scripts.debug.spectralsword_input_probe")
	if not probe or not probe.is_enabled or not probe.is_enabled() or not probe.note_frame then
		return
	end
	probe.note_frame(sess, sample)
end

local function remember_last_node(sess)
	local player = sess and sess.player
	local ghost = sess and sess.ghost
	if not player or not ghost or not ghost.target_node then
		return
	end
	local pdata = item.get_player_data(player, true)
	if pdata then
		pdata.last_node = ghost.target_node
	end
end

local function apply_nav(sess, direction)
	local ghost = sess.ghost
	local player = sess.player
	if ghost_controller.is_input_ready(ghost) then
		if ghost_controller.request_navigate(ghost, player, direction) then
			remember_last_node(sess)
		end
		return direction, nil
	end
	input_repeater.buffer_nav(sess.input, direction)
	return nil, nil
end

local function apply_action(sess, action)
	local ghost = sess.ghost
	if ghost_controller.is_input_ready(ghost) then
		if action == "extract" then
			ghost_controller.request_extract(ghost)
		elseif action == "inject" then
			ghost_controller.request_inject(ghost)
		end
		return nil, action
	end
	input_repeater.buffer_action(sess.input, action)
	return nil, nil
end

local function consume_input_buffers(sess)
	if not sess.input or not ghost_controller.is_input_ready(sess.ghost) then
		return nil, nil
	end
	local buf = input_repeater.consume_buffers(sess.input)
	if buf.nav then
		if ghost_controller.request_navigate(sess.ghost, sess.player, buf.nav) then
			remember_last_node(sess)
		end
		return buf.nav, nil
	end
	if buf.action then
		apply_action(sess, buf.action)
		return nil, buf.action
	end
	return nil, nil
end

local function update_session_input(sess)
	if sess.closing then
		return {skipped = "closing"}
	end
	if sess.presentation_only then
		return {skipped = "presentation_only"}
	end

	local player = sess.player
	local ghost = sess.ghost
	local ctrl = player.ControllerIndex
	local esc = peek_button_triggered(Keyboard.KEY_ESCAPE)
		or peek_action_triggered(ctrl, ButtonAction.ACTION_DROP)
	if esc then
		close_session(false)
		return {skipped = "escape_close"}
	end

	if not sess.input_armed then
		if not panel_inputs_held(sess) then
			sess.input_armed = true
			sess.wait_input_release = false
		end
		return {skipped = "arm_wait", input_armed = sess.input_armed}
	end

	local has_kb = Keyboard ~= nil
	local triggered = {
		up = peek_action_triggered(ctrl, ButtonAction.ACTION_SHOOTUP)
			or (has_kb and peek_button_triggered(Keyboard.KEY_UP)),
		down = peek_action_triggered(ctrl, ButtonAction.ACTION_SHOOTDOWN)
			or (has_kb and peek_button_triggered(Keyboard.KEY_DOWN)),
		left = peek_action_triggered(ctrl, ButtonAction.ACTION_SHOOTLEFT)
			or (has_kb and peek_button_triggered(Keyboard.KEY_LEFT)),
		right = peek_action_triggered(ctrl, ButtonAction.ACTION_SHOOTRIGHT)
			or (has_kb and peek_button_triggered(Keyboard.KEY_RIGHT)),
		decrease = has_kb and peek_button_triggered(Keyboard.KEY_Q),
		increase = has_kb and peek_button_triggered(Keyboard.KEY_E),
	}
	local pressed = {
		up = peek_action_pressed(ctrl, ButtonAction.ACTION_SHOOTUP)
			or (has_kb and peek_button_pressed(Keyboard.KEY_UP)),
		down = peek_action_pressed(ctrl, ButtonAction.ACTION_SHOOTDOWN)
			or (has_kb and peek_button_pressed(Keyboard.KEY_DOWN)),
		left = peek_action_pressed(ctrl, ButtonAction.ACTION_SHOOTLEFT)
			or (has_kb and peek_button_pressed(Keyboard.KEY_LEFT)),
		right = peek_action_pressed(ctrl, ButtonAction.ACTION_SHOOTRIGHT)
			or (has_kb and peek_button_pressed(Keyboard.KEY_RIGHT)),
		decrease = has_kb and peek_button_pressed(Keyboard.KEY_Q),
		increase = has_kb and peek_button_pressed(Keyboard.KEY_E),
	}

	local fired = input_repeater.tick(sess.input, {
		triggered = triggered,
		pressed = pressed,
	})
	local executed_nav, executed_action = nil, nil
	if fired.nav then
		executed_nav = select(1, apply_nav(sess, fired.nav))
	elseif fired.action then
		local _, act = apply_action(sess, fired.action)
		executed_action = act
	end

	return {
		triggered = triggered,
		pressed = pressed,
		fired = fired,
		executed_nav = executed_nav,
		executed_action = executed_action,
	}
end

local function tick_session(sess, player)
	if sess == nil then return end
	sess.player = player

	if pause_menu_open() then
		sess.was_paused = true
		sess.input_armed = false
		if sess.input then input_repeater.clear(sess.input) end
		return
	end

	if sess.was_paused then
		if panel_inputs_held(sess) then
			return
		end
		sess.was_paused = false
		sess.input_armed = true
	end

	if not player or not player:Exists() then
		close_session(true)
		return
	end
	if has_active_enemies() then
		close_session(true)
		return
	end
	if player:GetCollectibleNum(item.entity, true) <= 0 then
		close_session(true)
		return
	end

	-- 1) 读输入（非 HOVER 时写入 pending）
	local input_sample = update_session_input(sess)
	if item.session == nil then return end
	sess = item.session

	-- 2) 推进状态机（可能 TRAVEL → HOVER）
	ghost_controller.tick(sess.ghost, player, {
		on_extract = function()
			return do_extract(sess)
		end,
		on_inject = function()
			return do_inject(sess)
		end,
		on_entry_orbit_done = function(ghost)
			if sess.presentation_only then
				-- 环绕刚结束时取玩家当前位置，勿锁死 open 时坐标。
				ghost_controller.request_exit(ghost, player_screen_pos(sess.player))
				sess.closing = true
			end
		end,
		on_exit_done = function()
			finish_close()
		end,
	})
	if item.session == nil then return end
	sess = item.session

	-- 3) 刚进入 HOVER 时消费缓冲，避免丢键
	local buf_nav, buf_action = consume_input_buffers(sess)
	if item.session == nil then return end
	sess = item.session

	if input_sample then
		if buf_nav then input_sample.executed_nav = input_sample.executed_nav or buf_nav end
		if buf_action then input_sample.executed_action = input_sample.executed_action or buf_action end
		note_input_for_probe(sess, input_sample)
	end

	spirit_vfx.tick(sess.vfx, sess.ghost)
	-- Duality / FoundHUD 等动态拓扑变化时，离开不可导航节点
	if not sess.presentation_only
		and sess.ghost
		and sess.ghost.target_node
		and not hud_nodes.is_node_navigable(sess.ghost.target_node)
	then
		local ctx = hud_nodes.get_hud_context(sess.player)
		local fallback = hud_nodes.neighbor(sess.ghost.target_node, "up", ctx)
			or hud_nodes.neighbor(sess.ghost.target_node, "down", ctx)
			or hud_nodes.resolve_start_node(nil, sess.player, ctx)
		if fallback and hud_nodes.is_node_navigable(fallback, ctx) then
			if ghost_controller.begin_travel(sess.ghost, sess.player, fallback) then
				remember_last_node(sess)
			end
		end
	end
	-- 面板开启期间低频采样 live（默认 30 Game 帧），禁止 render 调 getter
	item.sample_planetarium_live(false)
end

local function render_session()
	local sess = item.session
	if sess == nil or not sess.ghost or not sess.ghost.active then return end
	if pause_menu_open() then return end
	local pdata = item.get_player_data(sess.player, false)
	hud_render.render({
		player = sess.player,
		ghost = sess.ghost,
		vfx = sess.vfx,
		essence = pdata and pdata.essence or nil,
		spirit = pdata and hud_nodes.essence_total(pdata.essence) or 0,
		modifiers = pdata and pdata.modifiers or nil,
		planetarium_view = item.get_planetarium_hud_view(),
		zh = lang_zh(),
	})
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if continue ~= true and save.elses then
		save.elses[item.own_key .. "reshape"] = nil
		save.elses[item.own_key .. "shared_caps"] = nil
		save.elses[item.own_key .. "deal_sync"] = nil
	end
	item.session = nil
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, coltyp, rng, player, useFlags, activeSlot, customVarData)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then return end
	if session_interactive() and item.session.player and auxi.check_for_the_same(item.session.player, player) then
		close_session(false)
		return
	end
	if session_exists() then
		return
	end
	open_session(player)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	-- 属性重塑属于本局 pdata，不要求仍持有妖刀。
	local pdata = item.get_player_data(player, false)
	if pdata == nil then return end
	local mods = pdata.modifiers or {}
	for key, def in pairs(STAT_DEF) do
		if def.cache == cacheFlag then
			local d = mods[key] or 0
			if d ~= 0 then def.apply(player, d) end
		end
	end
end,
})

if REPENTOGON and ModCallbacks.MC_EVALUATE_CUSTOM_CACHE then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CUSTOM_CACHE, params = nil,
	Function = function(_, player, tag, value)
		-- 共享上限一经修改，本局始终生效；不以是否持有妖刀为门。
		local caps = item.get_shared_caps(false)
		if caps == nil then return end
		tag = tostring(tag or ""):lower()
		if tag == "maxcoins" then
			return hud_nodes.clamp_storage((value or 0) + (caps.max_coins or 0))
		elseif tag == "maxbombs" then
			return hud_nodes.clamp_storage((value or 0) + (caps.max_bombs or 0))
		elseif tag == "maxkeys" then
			return hud_nodes.clamp_storage((value or 0) + (caps.max_keys or 0))
		end
	end,
	})
end

-- Devil：永久 provider offset（total_deal）。
-- Planetarium：由下方独立 MC_POST_PLANETARIUM_CALCULATE 拥有，不走 holder provider。
deal_chance_holder.register_provider("spectralsword", function()
	return {
		total_deal = sum_deal_modifier("devil"),
	}
end)

-- Planetarium gameplay 唯一修改 owner（clamp [0,1]）。
-- deal_chance_holder 不再注册任何 Planetarium callback。
if ModCallbacks.MC_POST_PLANETARIUM_CALCULATE then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PLANETARIUM_CALCULATE,
		params = nil,
		Function = function(_, chance)
			local chance_in = tonumber(chance) or 0
			local mod = sum_deal_modifier("planetarium")
			local chance_out = chance_in
			if math.abs(mod) >= 1e-9 then
				chance_out = math.max(0, math.min(1, chance_in + mod))
			end
			do
				local env = require("Qing_Remaster_scripts.core.dev_environment")
				if env.probes_allowed() then
					local probe = env.require_probe("Qing_Remaster_scripts.debug.spectralsword_lazarus_identity_probe")
					if probe and probe.note_planetarium_calc then
						pcall(probe.note_planetarium_calc, chance_in, mod, chance_out)
					end
				end
			end
			if math.abs(mod) < 1e-9 then
				return
			end
			return chance_out
		end,
	})
end

function item.set_debug_infinite_spirit(on)
	item.DEBUG_INFINITE_SPIRIT = on == true
end

function item.get_debug_infinite_spirit()
	return item.DEBUG_INFINITE_SPIRIT == true
end

function item.set_debug_force_seija(on)
	item.DEBUG_FORCE_SEIJA = on == true
end

function item.get_debug_force_seija()
	return item.DEBUG_FORCE_SEIJA == true
end

function item.set_debug_softbody(on)
	item.DEBUG_SOFTBODY = on == true
	if item.session and item.session.ghost then
		item.session.ghost.debug = item.DEBUG_SOFTBODY == true
	end
end

function item.get_debug_softbody()
	return item.DEBUG_SOFTBODY == true
end

--- Session-only 调试快照；不进存档。Probe 可只读记录，不得拥有这些开关。
function item.get_debug_config()
	local rep = input_repeater.get_repeat_config and input_repeater.get_repeat_config() or {
		initial = input_repeater.INITIAL_REPEAT_DELAY,
		interval = input_repeater.REPEAT_INTERVAL,
	}
	local spawn = ghost_controller.get_spawn_config and ghost_controller.get_spawn_config() or {}
	return {
		infinite_essence = item.DEBUG_INFINITE_SPIRIT == true,
		force_seija = item.DEBUG_FORCE_SEIJA == true,
		softbody = item.DEBUG_SOFTBODY == true,
		repeat_initial = rep.initial,
		repeat_interval = rep.interval,
		spawn = spawn,
	}
end

function item.reset_debug_config()
	item.set_debug_infinite_spirit(false)
	item.set_debug_force_seija(false)
	item.set_debug_softbody(false)
	if input_repeater.reset_repeat_config then
		input_repeater.reset_repeat_config()
	end
	if ghost_controller.reset_spawn_config then
		ghost_controller.reset_spawn_config()
	end
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_, player, collid, count)
	if collid ~= item.entity then return end
	if count <= 0 and session_active() and item.session.player and auxi.check_for_the_same(item.session.player, player) then
		close_session(true)
	end
	-- 失去妖刀只关掉编辑入口；Evaluate 后仍会重新应用本局 reshape / caps。
	player:AddCacheFlags(CACHE_ALL)
	player:EvaluateItems()
	refresh_cap_cache(player, nil)
	sync_level_angel_conversion()
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	deal_bag().level_angel_applied = 0
	sync_level_angel_conversion()
	-- 对齐原生 Stat HUD 新层刷新：更新 Planetarium 缓存镜像
	item.capture_planetarium_hud_cache()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if item.session then close_session(true) end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_)
	if item.session then close_session(true) end
	-- Continue：按本局已有 reshape / caps 恢复，不要求当前仍持有妖刀。
	local caps = item.get_shared_caps(false)
	if caps then
		refresh_cap_cache(Game():GetPlayer(0), nil)
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p then
			local pdata = item.get_player_data(p, false)
			if pdata then
				p:AddCacheFlags(CACHE_ALL)
				p:EvaluateItems()
			end
		end
	end
	sync_level_angel_conversion()
	item.capture_planetarium_hud_cache()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	local sess = item.session
	if not sess or not sess.player then
		return
	end
	local ok, same = pcall(function()
		return auxi.check_for_the_same(sess.player, player)
	end)
	if not ok or not same then
		return
	end
	tick_session(sess, player)
end,
})

local hud_cb = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = hud_cb, params = nil,
Function = function(_)
	render_session()
end,
})

-- Input contract:
-- MC_POST_PLAYER_UPDATE owns interactive input sampling/ticking.
-- MC_INPUT_ACTION only suppresses native gameplay actions.

local function spectral_input_active(ent)
	if item._reading_input then return false end
	if pause_menu_open() then return false end
	if not session_exists() then return false end
	if item.session.presentation_only then return false end
	local player = ent and ent:ToPlayer()
	if player and item.session.player then
		local ok, same = pcall(function()
			return auxi.check_for_the_same(item.session.player, player)
		end)
		if ok and same == false then return false end
	end
	return true
end

table.insert(item.pre_ToCall, {CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil, priority = -1000,
Function = function(_, ent, hook, button)
	if button ~= ButtonAction.ACTION_RESTART or not spectral_input_active(ent) then return end
	if hook == InputHook.GET_ACTION_VALUE then return 0 end
	return false
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_, ent, hook, button)
	if spectral_input_active(ent) and blocked_panel_actions[button] then
		if hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED then return false
		elseif hook == InputHook.GET_ACTION_VALUE then return 0 end
	end
end,
})

if EID then
	EID:addDescriptionModifier("qing_spectralsword_hide_eid_panel", function(desc)
		return session_exists()
	end, function(desc)
		desc.Name = ""
		desc.Description = ""
		desc.Icon = nil
		return desc
	end, 1)
end

auxi.add_to_seija(item.entity)

item.STAT_DEF = STAT_DEF
item.hud_nodes = hud_nodes
item.ghost_controller = ghost_controller
item.sum_deal_modifier = sum_deal_modifier

return item

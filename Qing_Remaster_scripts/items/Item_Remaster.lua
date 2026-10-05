local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local A2ZFont = require("Qing_Remaster_scripts.others.a2z_font_renderer")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Remaster,
	own_key = "Item_Remaster_",
	panel = nil,
	floor_targets = {},
	pending_reopen_until = nil,
	-- 续关后首个 NEW_LEVEL 不触发回传，避免载入即弹回
	_suppress_return = false,
	-- 同层演出状态机（不进存档）
	cinematic = nil,
	fx = {},
	_force_emerge = nil,
	_force_return_emerge = nil,
}

-- 演出/幽灵常量（合并为单表，避免主 chunk local 上限 200）
local C = {
	PERM_CHANNELS_KEY = "Item_Remaster_channels",
	SELECTION_KEY = "Item_Remaster_selection",
	PENDING_FX_KEY = "Item_Remaster_pending_fx",
	RUN_ID_KEY = "Item_Remaster_run_id",
	DESCENT_LOCK_KEY = "Item_Remaster_await_descent",
	BELIAL_LAYER_KEY = "Item_Remaster_belial_layer",
	PORTAL_ANM2 = "gfx/cards/cd01_wiz_port.anm2",
	PORTAL_SHEET = "gfx/effects/portals/remaster_port.png",
	OPEN_SETTLE = 12,
	JUMP_IN_WAIT = 40,
	JUMP_OUT_WAIT = 28,
	LIFT_WAIT = 32,
	WAKE_WAIT = 28,
	SUCK_DUR = 30,
	GHOST_SPIT_WAIT = 26,
	PORTAL_SPIT_DUR = 20,
	GHOST_JUMP_WAIT = 26,
	GHOST_LIFT_FALLBACK = 16,
	GHOST_LIFT_HOLD = 14,
	GHOST_HIDE_FALLBACK = 12,
	GHOST_WALK_SPEED = 4.2,
	GHOST_DOOR_REACH = 22,
	GHOST_FADE_DUR = 14,
	GHOST_HIDE_SETTLE = 6,
	WISP_FLY_SPEED = 8,
	WISP_FLY_ARRIVE = 5,
	WISP_ORBIT_RADIUS = 28,
	WISP_ORBIT_SPEED = 0.11,
	WISP_HOVER_PO_Y = -18,
	WISP_FALL_DUR = 18,
	WISP_PO_EMERGE_DUR = 14,
	WISP_CHANNEL_EMERGE_PO_Y = 10,
	WISP_PORTAL_LEAVE_RADIUS = 20,
	WISP_PORTAL_LEAVE_TIMEOUT = 150,
	GHOST_WISP_FALL_DIST = 40,
	GHOST_DOOR_UNLOCK_RANGE = 36,
	PORTAL_SHADER = "Qing_Remaster_Portal",
	PORTAL_TRANSITION_DUR = 48,
	PORTAL_ZOOM_MAX = 48,
	GHOST_LUA_SPRITE_STEP = 2,
	GHOST_WALK_HEAD = {
		WalkDown = "HeadDown",
		WalkUp = "HeadUp",
		WalkLeft = "HeadLeft",
		WalkRight = "HeadRight",
	},
	REMASTER_GFX = "gfx/items/collectibles/collectibles_Remaster.png",
	HELD_ITEM_ANM2 = "gfx/005.100_collectible.anm2",
	DEFAULT_GHOST_ANM2 = "gfx/001.000_player.anm2",
	PICKUP_NULL_FALLBACK = Vector(0, -25),
	HELD_ITEM_Y_BIAS = -16,
	COSTUME_LAYER_RANK = {
		glow = 10, back = 20, body = 30, body0 = 31, body1 = 32,
		head = 40, head0 = 41, head1 = 42, head2 = 43, head3 = 44, head4 = 45, head5 = 46,
		skull = 42, face = 43, hair = 44, top0 = 50, extra = 60,
	},
	PSL_LAYER_KEYS = {
		"glow", "body", "body0", "body1", "head", "head0", "head1", "head2", "head3", "head4", "head5",
		"top0", "extra", "ghost", "back",
	},
	WALK_LAYER_ANIMS = {"WalkDown", "WalkUp", "WalkLeft", "WalkRight", "Idle"},
	HEAD_LAYER_ANIMS = {"HeadDown", "HeadUp", "HeadLeft", "HeadRight"},
}

local RM = {}
local PORTAL_EFFECT_VAR = enums.Entities.ID_EFFECT_MeusNIL
local GHOST_HELD_SPR_KEY = item.own_key.."held_spr"
local GHOST_HELD_VISIBLE_KEY = item.own_key.."held_visible"
local GHOST_HELD_META_KEY = item.own_key.."held_meta"
local GHOST_COSTUME_SPRS_KEY = item.own_key.."walk_costume_sprs"
local GHOST_COSTUME_WINNERS_KEY = item.own_key.."costume_winners"
local GHOST_COSTUME_CANDIDATES_KEY = item.own_key.."costume_candidates"
local GHOST_COSTUME_DRIVER_KEY = item.own_key.."costume_driver_key"
local GHOST_COSTUME_CLOCK_KEY = item.own_key.."costume_clocks"
local GHOST_CLOCK_PROBE_KEY = item.own_key.."costume_clock_probe"
local GHOST_PLAN_CACHE_KEY = item.own_key.."composite_plan_cache"
local GHOST_DIRECTIONAL_HEAD_KEY = item.own_key.."directional_head_overlay"
local GHOST_PROBE_SNAP_KEY = item.own_key.."probe_snap"
local GHOST_CAN_FLY_KEY = item.own_key.."can_fly"
local CHANNEL_WISP_KEY = item.own_key.."channel_wisp"
local CHANNEL_WISP_FLIGHT_KEY = item.own_key.."channel_wisp_flight"
local NEXT_CHANNEL_WISP_KEY = item.own_key.."next_wisp_channel"

function RM.psl_index_to_key(idx)
	idx = tonumber(idx)
	if idx == nil then return nil end
	return C.PSL_LAYER_KEYS[idx + 1]
end

function RM.sprite_is_usable(spr)
	if not spr then return false end
	local ok_n, n = pcall(function() return spr:GetLayerCount() end)
	return ok_n and type(n) == "number" and n > 0
end

function RM.sprite_layer_usable(spr, layer_id)
	if not RM.sprite_is_usable(spr) then return false end
	layer_id = tonumber(layer_id)
	if not layer_id or layer_id < 0 then return false end
	local ok_n, n = pcall(function() return spr:GetLayerCount() end)
	return ok_n and type(n) == "number" and layer_id < n
end

--- 行走段有衣装层槽表时，PRE 取消实体默认绘制，POST 按槽完整合成
function RM.ghost_count_drawable_slots(ghost)
	if not ghost then return 0 end
	local winners = ghost:GetData()[GHOST_COSTUME_WINNERS_KEY]
	if type(winners) ~= "table" then return 0 end
	local n = 0
	for _, slot in pairs(winners) do
		if slot and slot.spr and RM.sprite_layer_usable(slot.spr, slot.layer_id) then
			n = n + 1
		end
	end
	return n
end

function RM.ghost_has_walk_composite(ghost)
	if not ghost then return false end
	if not ghost:GetData()[item.own_key.."walk_composite"] then return false end
	return RM.ghost_count_drawable_slots(ghost) > 0
end

function RM.ghost_costume_candidates(ghost)
	if not ghost or not ghost.GetData then return nil end
	local gd = ghost:GetData()
	local cands = gd[GHOST_COSTUME_CANDIDATES_KEY]
	if type(cands) == "table" and #cands > 0 then
		return cands
	end
	return gd[GHOST_COSTUME_WINNERS_KEY]
end

function RM.ghost_current_composite_plan(ghost)
	if not ghost or not ghost:Exists() then return {} end
	local gd = ghost:GetData()
	local body = ghost:GetSprite()
	local body_anim = nil
	pcall(function()
		if body then body_anim = body:GetAnimation() end
	end)
	local overlay_anim, overlay_frame, overlay_active = RM.ghost_walk_overlay_state(body, body_anim, ghost)
	local cache = gd[GHOST_PLAN_CACHE_KEY]
	if type(cache) == "table"
		and cache.main_anim == body_anim
		and cache.overlay_anim == overlay_anim
		and type(cache.plan) == "table"
	then
		return cache.plan, body_anim, overlay_anim, overlay_frame, overlay_active
	end
	local plan = RM.ghost_build_render_plan(RM.ghost_costume_candidates(ghost), body_anim, overlay_anim)
	gd[GHOST_PLAN_CACHE_KEY] = {
		main_anim = body_anim,
		overlay_anim = overlay_anim,
		plan = plan,
	}
	return plan, body_anim, overlay_anim, overlay_frame, overlay_active
end

function RM.ghost_should_render_composite(ghost)
	if not RM.ghost_has_walk_composite(ghost) then
		return false
	end
	local plan = RM.ghost_current_composite_plan(ghost)
	return type(plan) == "table" and #plan > 0
end

function RM.ghost_should_render_walk_composite(ghost)
	return RM.ghost_should_render_composite(ghost)
end

local ghost_probe_observer = nil
local ghost_probe_pre_last = {cancel = nil, frame = 0}

function item.set_ghost_probe_observer(fn)
	ghost_probe_observer = type(fn) == "function" and fn or nil
end

--- Latest Walk-composite probe snapshot for shared Validation Suite / Aeon / TianYi.
function RM.get_ghost_probe_snapshot(ghost)
	if not ghost or not ghost:Exists() then return nil end
	local gd = ghost:GetData()
	local body = ghost:GetSprite()
	local body_anim, body_frame, speed = nil, nil, nil
	pcall(function()
		body_anim = body:GetAnimation()
		body_frame = body:GetFrame()
		speed = body.PlaybackSpeed
	end)
	local overlay_anim, overlay_frame, overlay_active = RM.ghost_walk_overlay_state(body, body_anim, ghost)
	local snap = gd[GHOST_PROBE_SNAP_KEY]
	if type(snap) ~= "table" then
		snap = {stage = "live"}
	else
		-- Shallow copy so live refresh does not mutate the stored render row mid-flight.
		local copy = {}
		for k, v in pairs(snap) do
			copy[k] = v
		end
		snap = copy
	end
	snap.frame = Game():GetFrameCount()
	snap.body_anim = body_anim
	snap.body_frame = body_frame
	snap.playback_speed = speed
	snap.overlay_anim = overlay_anim
	snap.overlay_frame = overlay_frame
	snap.overlay_active = overlay_active and true or false
	snap.walk_composite = gd[item.own_key.."walk_composite"] and true or false
	snap.should_walk_composite = RM.ghost_should_render_walk_composite(ghost) and true or false
	snap.body_clock_running = RM.ghost_body_clock_running(body, body_anim)
	return snap
end

function item.get_ghost_probe_snapshot(ghost)
	return RM.get_ghost_probe_snapshot(ghost)
end

function RM.sprite_layer_snapshot(spr, anim, frame)
	if not spr or not RM.sprite_is_usable(spr) then
		return {usable = false}
	end
	local snap = {
		usable = true,
		filename = nil,
		anim = anim,
		frame = frame,
		layer_count = 0,
		layers = {},
	}
	pcall(function() snap.filename = spr:GetFilename() end)
	pcall(function() snap.layer_count = spr:GetLayerCount() end)
	local ok_n, n = pcall(function() return spr:GetLayerCount() end)
	if not ok_n or type(n) ~= "number" then return snap end
	for i = 0, math.min(n - 1, 24) do
		local lay = {}
		pcall(function()
			local ls = spr:GetLayer(i)
			if ls and ls.GetName then lay.name = ls:GetName() end
			if ls and ls.IsVisible then lay.visible = ls:IsVisible() end
		end)
		local vis_frame = false
		pcall(function()
			local ad = spr.GetCurrentAnimationData and spr:GetCurrentAnimationData()
			if ad and ad.GetLayer then
				local ld = ad:GetLayer(i)
				if ld and ld.GetFrame and frame ~= nil then
					local fd = ld:GetFrame(frame)
					if fd and fd.IsVisible then vis_frame = fd:IsVisible() end
				end
			end
		end)
		lay.frame_visible = vis_frame
		snap.layers[#snap.layers + 1] = lay
	end
	return snap
end

function RM.emit_ghost_probe(stage, ghost, extra)
	extra = type(extra) == "table" and extra or {}
	local skip_observer = false
	if stage == "pre_render" then
		local fc = Game():GetFrameCount()
		if extra.pre_cancel == ghost_probe_pre_last.cancel and fc - ghost_probe_pre_last.frame < 12 then
			skip_observer = true
		else
			ghost_probe_pre_last.cancel = extra.pre_cancel
			ghost_probe_pre_last.frame = fc
		end
	end
	extra.stage = stage
	extra.game_frame = Game():GetFrameCount()
	if ghost and ghost.Exists and ghost:Exists() then
		local gd = ghost:GetData()
		local body = ghost:GetSprite()
		local app = gd[item.own_key.."ghost_app"]
		extra.visible = ghost.Visible and true or false
		extra.pos_x = ghost.Position.X
		extra.pos_y = ghost.Position.Y
		extra.walk_composite = gd[item.own_key.."walk_composite"] and true or false
		extra.should_walk_composite = RM.ghost_should_render_walk_composite(ghost) and true or false
		extra.drawable_slot_count = RM.ghost_count_drawable_slots(ghost)
		extra.winner_count = 0
		local winners = gd[GHOST_COSTUME_WINNERS_KEY]
		if type(winners) == "table" then
			for k, slot in pairs(winners) do
				extra.winner_count = extra.winner_count + 1
				if not extra.winners then extra.winners = {} end
				if extra.winner_count <= 16 then
					local anm2 = nil
					if slot and slot.spr then
						pcall(function() anm2 = slot.spr:GetFilename() end)
					end
					extra.winners[#extra.winners + 1] = {
						key = tostring(slot and slot.key or k),
						plan_key = slot and slot.plan_key,
						layer_id = slot and slot.layer_id,
						logical_layer_id = slot and slot.logical_layer_id,
						anim_source = slot and slot.anim_source,
						priority = slot and slot.priority,
						from_base = slot and (slot.from_base == true or slot.spr == body),
						is_flying = slot and slot.is_flying and true or false,
						anm2 = anm2,
					}
				end
			end
		end
		if type(app) == "table" then
			extra.base_anm2 = app.base_anm2
			extra.player_type = app.player_type
			extra.can_fly = app.can_fly and true or false
			extra.costume_count = type(app.costumes) == "table" and #app.costumes or 0
			extra.costume_layer_count = type(app.costume_layers) == "table" and #app.costume_layers or 0
		end
		if body then
			pcall(function() extra.body_anim = extra.body_anim or body:GetAnimation() end)
			pcall(function() extra.body_frame = extra.body_frame or body:GetFrame() end)
			pcall(function() extra.anim = extra.anim or body:GetAnimation() end)
			-- Keep caller's sample frame; body frame lives in body_frame.
			if extra.frame == nil then
				pcall(function() extra.frame = body:GetFrame() end)
			end
			pcall(function()
				if extra.overlay_anim == nil then
					extra.overlay_anim = body:GetOverlayAnimation()
				end
			end)
			pcall(function()
				if extra.overlay_frame == nil then
					extra.overlay_frame = body:GetOverlayFrame()
				end
			end)
			if body.Color then extra.alpha = body.Color.A end
			extra.body = RM.sprite_layer_snapshot(body, extra.body_anim or extra.anim, extra.body_frame or extra.frame)
		end
		if stage == "render_post" or stage == "pre_render" then
			gd[GHOST_PROBE_SNAP_KEY] = extra
		end
	end
	local cine = item.cinematic
	if cine then
		extra.cine_kind = cine.kind
		extra.cine_phase = cine.phase
		extra.ghost_walk_anim = cine.ghost_walk_anim
	end
	if skip_observer or not ghost_probe_observer then return end
	pcall(ghost_probe_observer, extra)
end

--- costumes2 层序：同层仅最高 priority 生效；head* 与 body 分开叠绘

function RM.get_current_run_id()
	local id = save.elses[C.RUN_ID_KEY]
	if type(id) ~= "string" or id == "" then
		id = tostring(Game():GetSeeds():GetStartSeed()).."_"..tostring(Game():GetFrameCount())
		save.elses[C.RUN_ID_KEY] = id
	end
	return id
end

function RM.reset_current_run_id()
	save.elses[C.RUN_ID_KEY] = tostring(Game():GetSeeds():GetStartSeed()).."_"..tostring(Game():GetFrameCount())
end

function RM.costume_layer_key(layer_name)
	if type(layer_name) ~= "string" then return nil end
	local key = string.lower(layer_name)
	if key == "" then return nil end
	return key
end

function RM.costume_layer_rank(key)
	if not key then return 999 end
	return C.COSTUME_LAYER_RANK[key] or 35
end

--- True Head overlay slots only. `top0` is a PSL render slot, not head ownership.
function RM.costume_layer_is_head(key)
	if not key then return false end
	return key:match("^head") ~= nil or key == "skull" or key == "face" or key == "hair"
end

function RM.costume_layer_role(key)
	return RM.costume_layer_is_head(key) and "head" or "body"
end

function RM.ghost_psl_index(key)
	if type(key) ~= "string" then return nil end
	for i, name in ipairs(C.PSL_LAYER_KEYS) do
		if name == key then
			return i - 1
		end
	end
	return nil
end

function RM.ghost_logical_layer_id(key, native_id)
	local psl = RM.ghost_psl_index(key)
	if psl ~= nil then return psl end
	return tonumber(native_id) or 0
end

function RM.ghost_anim_source_order(source)
	return source == "head" and 1 or 0
end

function RM.sprite_animation_data(spr, anim)
	local ad = nil
	if not spr or type(anim) ~= "string" or anim == "" then return nil end
	pcall(function()
		if spr.GetAnimationData then
			ad = spr:GetAnimationData(anim)
		end
	end)
	return ad
end

--- LayerAnimation declared in AnimationData counts as present.
--- Layer/Frame Visible is playback, not ownership.
function RM.sprite_anim_has_layer(spr, anim, layer_id)
	layer_id = tonumber(layer_id)
	if not RM.sprite_is_usable(spr) or not layer_id or layer_id < 0 then return false end
	local ad = RM.sprite_animation_data(spr, anim)
	if not ad then return false end
	local present = false
	pcall(function()
		if ad.GetAllLayers then
			local layers = ad:GetAllLayers()
			if type(layers) == "table" then
				for i = 1, #layers do
					local ld = layers[i]
					if ld and ld.GetLayerID and ld:GetLayerID() == layer_id then
						present = true
						return
					end
				end
			end
		end
		if not present and ad.GetLayer then
			local ld = ad:GetLayer(layer_id)
			present = ld ~= nil
		end
	end)
	return present
end

function RM.ghost_layer_in_anim_list(spr, layer_id, names)
	if type(names) ~= "table" then return false end
	for i = 1, #names do
		if RM.sprite_anim_has_layer(spr, names[i], layer_id) then
			return true
		end
	end
	return false
end

--- Classify a native ANM2 layer by which animation family actually contains it.
function RM.ghost_layer_anim_sources(spr, layer_id)
	local in_walk = RM.ghost_layer_in_anim_list(spr, layer_id, C.WALK_LAYER_ANIMS)
	local in_head = RM.ghost_layer_in_anim_list(spr, layer_id, C.HEAD_LAYER_ANIMS)
	return in_walk, in_head
end

function RM.ghost_read_sprite_anim_frame(spr)
	local anim, frame = nil, 0
	if not spr then return anim, frame end
	pcall(function()
		anim = spr:GetAnimation()
		frame = spr:GetFrame()
	end)
	return anim, frame
end

function RM.ghost_desired_walk_anim(ghost)
	local anim = nil
	if ghost and ghost:Exists() then
		pcall(function() anim = ghost:GetSprite():GetAnimation() end)
	end
	if type(anim) ~= "string" or anim == "" then return "WalkDown" end
	return anim
end

function RM.ghost_slot_is_body_driver_candidate(slot)
	if not slot or not slot.spr or slot.from_base then return false end
	if slot.anim_source == "head" then return false end
	local key = slot.key
	if RM.costume_layer_is_head(key) then return false end
	return true
end

--- 行走合成的主时钟：优先非底模、body-source 的 body 衣装层（Az 等可见身体）
function RM.ghost_pick_body_driver(winners)
	if type(winners) ~= "table" then return nil end
	local best, best_rank = nil, 9999
	for _, slot in pairs(winners) do
		if RM.ghost_slot_is_body_driver_candidate(slot) then
			local rank = RM.costume_layer_rank(slot.key)
			if rank >= 30 and rank <= 32 then
				if not best
					or (slot.priority or 0) > (best.priority or 0)
					or ((slot.priority or 0) == (best.priority or 0) and rank < best_rank) then
					best = slot
					best_rank = rank
				end
			end
		end
	end
	if best then return best end
	for _, slot in pairs(winners) do
		if RM.ghost_slot_is_body_driver_candidate(slot) then
			if not best or (slot.priority or 0) > (best.priority or 0) then
				best = slot
			end
		end
	end
	return best
end

function RM.ghost_find_winner_slot(winners, driver_key)
	if type(winners) ~= "table" or type(driver_key) ~= "string" then return nil end
	if winners[driver_key] then return winners[driver_key] end
	for _, slot in pairs(winners) do
		if slot and (slot.plan_key == driver_key or slot.key == driver_key) then
			return slot
		end
	end
	return nil
end

function RM.ghost_get_costume_driver(ghost, winners)
	winners = winners or (ghost and ghost:GetData()[GHOST_COSTUME_WINNERS_KEY])
	if type(winners) ~= "table" then return nil end
	local gd = ghost and ghost:GetData()
	local driver_key = gd and gd[GHOST_COSTUME_DRIVER_KEY]
	local slot = RM.ghost_find_winner_slot(winners, driver_key)
	if slot and slot.spr and not slot.from_base then return slot end
	local picked = RM.ghost_pick_body_driver(winners)
	if picked and gd then gd[GHOST_COSTUME_DRIVER_KEY] = picked.plan_key or picked.key end
	return picked
end

--- Load 失败或 anm2/贴图缺失时返回 false，不向外抛错
function RM.try_sprite_load(spr, path)
	if not spr or type(path) ~= "string" or path == "" then return false end
	local ok = pcall(function() spr:Load(path, true) end)
	return ok and RM.sprite_is_usable(spr)
end

function RM.display_code(code)
	code = tostring(code or "")
	local body, floor = code:match("^(.-)(%d)$")
	if floor then
		body = body:gsub("%-", "")
		body = string.sub(body, 1, 7)
		return string.rep("-", math.max(0, 7 - #body))..body..floor
	end
	body = code:gsub("%-", "")
	body = string.sub(body, 1, 8)
	return string.rep("-", math.max(0, 8 - #body))..body
end

function RM.add(code, name, command, seed_stage)
	assert(#code == 8, "Remaster floor code must contain exactly 8 characters: "..code)
	table.insert(item.floor_targets, {
		code = RM.display_code(code),
		name = name,
		command = command,
		seed_stage = seed_stage,
	})
end

-- 八字符 code 会在后续直接映射到 26 字母与连字符贴图。
local chapters = {
	{first = 1, names = {
		{"BASEMNT", "Basement", ""}, {"CELLAR-", "Cellar", "a"}, {"BURNBAS", "Burning Basement", "b"},
		{"DOWNPOR", "Downpour", "c"}, {"DROSS--", "Dross", "d"},
	}},
	{first = 3, names = {
		{"CAVES--", "Caves", ""}, {"CATACMB", "Catacombs", "a"}, {"FLOODCV", "Flooded Caves", "b"},
		{"MINES--", "Mines", "c"}, {"ASHPIT-", "Ashpit", "d"},
	}},
	{first = 5, names = {
		{"DEPTHS-", "Depths", ""}, {"NECROP-", "Necropolis", "a"}, {"DANKDEP", "Dank Depths", "b"},
		{"MAUSOLM", "Mausoleum", "c"}, {"GEHENNA", "Gehenna", "d"},
	}},
	{first = 7, names = {
		{"WOMB---", "Womb", ""}, {"UTERO--", "Utero", "a"}, {"SCARWMB", "Scarred Womb", "b"},
		{"CORPSE-", "Corpse", "c"},
	}},
}

for _, chapter in ipairs(chapters) do
	for floor_offset = 0, 1 do
		local floor_number = floor_offset + 1
		local stage = chapter.first + floor_offset
		for _, variant in ipairs(chapter.names) do
			RM.add(variant[1]..floor_number, variant[2]..(floor_number == 1 and " I" or " II"), tostring(stage)..variant[3], stage)
		end
	end
end

RM.add("BLUEWOMB", "Blue Womb", "9", 9)
RM.add("SHEOL---", "Sheol", "10", 10)
RM.add("CATHEDRL", "Cathedral", "10a", 10)
RM.add("DARKROOM", "Dark Room", "11", 11)
RM.add("CHEST---", "Chest", "11a", 11)
RM.add("VOID----", "Void", "12", 12)
RM.add("HOME----", "Home", "13", 13)

-- ---------- 楼层身份 / 渠道 ----------
function RM.stage_type_suffix(stage_type)
	if stage_type == StageType.STAGETYPE_WOTL then return "a" end
	if stage_type == StageType.STAGETYPE_AFTERBIRTH then return "b" end
	if stage_type == StageType.STAGETYPE_REPENTANCE then return "c" end
	if stage_type == StageType.STAGETYPE_REPENTANCE_B then return "d" end
	return ""
end

function RM.suffix_to_stage_type(suffix)
	if suffix == "a" then return StageType.STAGETYPE_WOTL end
	if suffix == "b" then return StageType.STAGETYPE_AFTERBIRTH end
	if suffix == "c" then return StageType.STAGETYPE_REPENTANCE end
	if suffix == "d" then return StageType.STAGETYPE_REPENTANCE_B end
	return StageType.STAGETYPE_ORIGINAL
end

function RM.parse_command(command)
	command = tostring(command or "")
	local stage_s, suffix = command:match("^(%d+)([abcd]?)$")
	local stage = tonumber(stage_s)
	if not stage then return nil end
	return {
		stage = stage,
		stage_type = RM.suffix_to_stage_type(suffix or ""),
		command = command,
		seed_stage = stage,
	}
end

--- 楼层信息压成纯表，避免枚举 userdata 进 RUN.ELSES 后无法续关还原
function RM.sanitize_floor_info(info)
	if type(info) ~= "table" then return nil end
	return {
		stage = tonumber(info.stage),
		stage_type = tonumber(info.stage_type) or 0,
		command = tostring(info.command or ""),
		seed_stage = tonumber(info.seed_stage) or tonumber(info.stage),
	}
end

--- 演出够用：角色底模 + 肤色 + 体型 + 衣装（RGON GetCostumeLayerMap 精确层绑定）
function RM.capture_costume_layer_bindings(player, descs)
	if not player or not player.GetCostumeLayerMap then return nil end
	local ok_map, map = pcall(function() return player:GetCostumeLayerMap() end)
	if not ok_map or type(map) ~= "table" then return nil end
	if type(descs) ~= "table" then
		local ok_d, got = pcall(function() return player:GetCostumeSpriteDescs() end)
		if not ok_d or type(got) ~= "table" then return nil end
		descs = got
	end
	local bindings = {}
	for idx, mapData in ipairs(map) do
		if type(mapData) ~= "table" then goto continue end
		local ci = tonumber(mapData.costumeIndex)
		local lid = tonumber(mapData.layerID)
		if not ci or ci < 0 or not lid or lid < 0 then goto continue end
		local desc = descs[ci + 1]
		if not desc then goto continue end
		local anm2, prio, is_flying = nil, tonumber(mapData.priority), false
		pcall(function()
			local cs = desc:GetSprite()
			if cs and cs.GetFilename then anm2 = cs:GetFilename() end
		end)
		if desc.IsFlying then
			pcall(function() is_flying = desc:IsFlying() and true or false end)
		end
		if type(anm2) ~= "string" or anm2 == "" then goto continue end
		bindings[#bindings + 1] = {
			sprite_layer = idx - 1,
			layer_id = lid,
			priority = prio,
			is_body = mapData.isBodyLayer and true or false,
			anm2 = anm2,
			is_flying = is_flying,
		}
		::continue::
	end
	if #bindings == 0 then return nil end
	return bindings
end

function RM.sprite_read(spr, fn)
	if not spr or type(fn) ~= "function" then return nil end
	local v = nil
	pcall(function() v = fn(spr) end)
	return v
end

function RM.ghost_render_sprite_overlay_only(spr, screen, sc, flip_x, tint, alpha)
	if not spr or not RM.sprite_is_usable(spr) then return false end
	local overlay_anim = RM.sprite_read(spr, function(s) return s:GetOverlayAnimation() end)
	if type(overlay_anim) ~= "string" or overlay_anim == "" then return false end
	local saved = {}
	local n = tonumber(RM.sprite_read(spr, function(s) return s:GetLayerCount() end)) or 0
	for i = 0, n - 1 do
		pcall(function()
			local lay = spr:GetLayer(i)
			if lay and lay.IsVisible and lay.SetVisible then
				saved[i] = lay:IsVisible()
				lay:SetVisible(false)
			end
		end)
	end
	local drew = false
	pcall(function()
		spr.Scale = sc
		spr.FlipX = flip_x
		spr.Color = Color(tint.R, tint.G, tint.B, alpha)
		spr:Render(screen, Vector.Zero, Vector.Zero)
		drew = true
	end)
	for i, vis in pairs(saved) do
		pcall(function()
			local lay = spr:GetLayer(i)
			if lay and lay.SetVisible then lay:SetVisible(vis) end
		end)
	end
	return drew
end

function RM.ghost_render_fallback_full_body(ghost, body, screen, sc, tint, alpha)
	if not ghost or not body then return false end
	local ok = false
	pcall(function()
		body.Scale = sc
		body.FlipX = ghost.FlipX
		body.Color = Color(tint.R, tint.G, tint.B, alpha)
		body:Render(screen, Vector.Zero, Vector.Zero)
		ok = true
	end)
	return ok
end

function RM.capture_player_appearance(player)
	if not player or not player:Exists() then return nil end
	local spr = player:GetSprite()
	local base_sheets = {}
	if spr and spr.GetLayerCount then
		local ok_n, n = pcall(function() return spr:GetLayerCount() end)
		if ok_n and type(n) == "number" then
			for i = 0, n - 1 do
				local ok, path = pcall(function()
					local lay = spr:GetLayer(i)
					if lay and lay.GetSpritesheetPath then return lay:GetSpritesheetPath() end
				end)
				if ok and type(path) == "string" and path ~= "" then
					base_sheets[tostring(i)] = path
				end
			end
		end
	end
	local costumes = {}
	local descs = nil
	if player.GetCostumeSpriteDescs then
		local ok, got = pcall(function() return player:GetCostumeSpriteDescs() end)
		if ok and type(got) == "table" then
			descs = got
			for _, desc in ipairs(descs) do
				local entry = {}
				local ok_s, cs = pcall(function() return desc:GetSprite() end)
				if ok_s and cs and cs.GetFilename then
					entry.anm2 = cs:GetFilename()
				end
				if desc.GetPriority then
					local ok_p, prio = pcall(function() return desc:GetPriority() end)
					if ok_p then entry.priority = tonumber(prio) end
				end
				if desc.GetSkinColor then
					local ok_c, sc = pcall(function() return desc:GetSkinColor() end)
					if ok_c then entry.skin_color = tonumber(sc) end
				end
				if desc.IsFlying then
					local ok_f, fly = pcall(function() return desc:IsFlying() end)
					if ok_f then entry.is_flying = fly and true or false end
				end
				if desc.GetItemConfig then
					local ok_i, cfg = pcall(function() return desc:GetItemConfig() end)
					if ok_i and cfg then
						entry.item_id = tonumber(cfg.ID)
					end
				end
				if entry.anm2 then costumes[#costumes + 1] = entry end
			end
		end
	end
	local scale = player.SpriteScale or Vector(1, 1)
	local costume_layers = RM.capture_costume_layer_bindings(player, descs)
	RM.emit_ghost_probe("capture_appearance", nil, {
		player_type = tonumber(player:GetPlayerType()) or 0,
		can_fly = player.CanFly and true or false,
		base_anm2 = RM.sprite_read(spr, function(s) return s:GetFilename() end),
		costume_count = #costumes,
		costume_layer_count = type(costume_layers) == "table" and #costume_layers or 0,
		body_anim = RM.sprite_read(spr, function(s) return s:GetAnimation() end),
		body_frame = RM.sprite_read(spr, function(s) return s:GetFrame() end),
		overlay_anim = RM.sprite_read(spr, function(s) return s:GetOverlayAnimation() end),
		overlay_frame = RM.sprite_read(spr, function(s) return s:GetOverlayFrame() end),
	})
	return {
		player_type = tonumber(player:GetPlayerType()) or 0,
		body_color = tonumber(player:GetBodyColor()) or 0,
		head_color = tonumber(player:GetHeadColor()) or 0,
		sprite_scale = {X = tonumber(scale.X) or 1, Y = tonumber(scale.Y) or 1},
		can_fly = player.CanFly and true or false,
		base_anm2 = spr and spr:GetFilename() or nil,
		base_sheets = base_sheets,
		costumes = costumes,
		costume_layers = costume_layers,
	}
end

function RM.sanitize_appearance(app)
	if type(app) ~= "table" then return nil end
	local costumes = {}
	if type(app.costumes) == "table" then
		for _, c in ipairs(app.costumes) do
			if type(c) == "table" and type(c.anm2) == "string" then
				costumes[#costumes + 1] = {
					anm2 = c.anm2,
					item_id = tonumber(c.item_id),
					priority = tonumber(c.priority),
					skin_color = tonumber(c.skin_color),
					is_flying = c.is_flying and true or false,
				}
			end
		end
	end
	local sheets = {}
	if type(app.base_sheets) == "table" then
		for k, v in pairs(app.base_sheets) do
			if type(v) == "string" then sheets[tostring(k)] = v end
		end
	end
	local scale = app.sprite_scale
	local costume_layers = {}
	if type(app.costume_layers) == "table" then
		for _, b in ipairs(app.costume_layers) do
			if type(b) == "table" and type(b.anm2) == "string" then
				costume_layers[#costume_layers + 1] = {
					sprite_layer = tonumber(b.sprite_layer),
					layer_id = tonumber(b.layer_id),
					priority = tonumber(b.priority),
					is_body = b.is_body and true or false,
					anm2 = b.anm2,
					is_flying = b.is_flying and true or false,
				}
			end
		end
	end
	return {
		player_type = tonumber(app.player_type) or 0,
		body_color = tonumber(app.body_color) or 0,
		head_color = tonumber(app.head_color) or 0,
		sprite_scale = {
			X = tonumber(type(scale) == "table" and scale.X) or 1,
			Y = tonumber(type(scale) == "table" and scale.Y) or 1,
		},
		can_fly = app.can_fly and true or false,
		base_anm2 = type(app.base_anm2) == "string" and app.base_anm2 or nil,
		base_sheets = sheets,
		costumes = costumes,
		costume_layers = #costume_layers > 0 and costume_layers or nil,
	}
end

--- Shared costume winner arbitration (ghost setup + live player capture).
--- opts.base_sprite: bottom-layer fallback (ghost/player sprite)
--- opts.appearance: sanitized appearance with costume_layers / costumes
--- opts.live_descs: when set, bind winners to live CostumeSpriteDesc sprites (player capture)
--- Returns { winners, pool, driver_key }
---
--- Cinematic Lua Sprite pool is keyed by ANM2 + animation role (body|head), not ANM2 alone.
--- Vanilla costumes such as Spirit of the Night put body and head in one ANM2; sharing a single
--- Sprite between Walk* and Head* clocks makes the body disappear after the head pass.
function RM.resolve_costume_winners(opts)
	opts = type(opts) == "table" and opts or {}
	local appearance = RM.sanitize_appearance(opts.appearance) or {}
	local base_sprite = opts.base_sprite
	local live_descs = opts.live_descs
	local use_live = type(live_descs) == "table"
	local has_layers = type(appearance.costume_layers) == "table" and #appearance.costume_layers > 0
	local has_costumes = type(appearance.costumes) == "table" and #appearance.costumes > 0
	if not has_layers and not has_costumes and not use_live then
		return { winners = {}, pool = {}, driver_key = nil, candidates = {} }
	end
	local pool = {}
	local pool_by_anm2_role = {}
	local winners = {}
	local candidates = {}
	local function pool_sprite_for(anm2, role)
		if type(anm2) ~= "string" or anm2 == "" then return nil end
		role = role == "head" and "head" or "body"
		local bucket = pool_by_anm2_role[anm2]
		if not bucket then
			bucket = {}
			pool_by_anm2_role[anm2] = bucket
		end
		if bucket[role] then return bucket[role] end
		local spr = Sprite()
		if RM.try_sprite_load(spr, anm2) then
			pool[#pool + 1] = spr
			bucket[role] = spr
			return spr
		end
		return nil
	end
	local function sprite_anm2(spr)
		local path = nil
		if spr then
			pcall(function() path = spr:GetFilename() end)
		end
		return path
	end
	local function make_slot(spr, layer_id, key, priority, is_flying, from_base, anm2, anim_source)
		anim_source = anim_source == "head" and "head" or "body"
		local plan_key = anim_source .. "|" .. key
		return {
			spr = spr,
			layer_id = layer_id,
			native_layer_id = layer_id,
			logical_layer_id = RM.ghost_logical_layer_id(key, layer_id),
			priority = priority or 0,
			key = key,
			plan_key = plan_key,
			clock_key = (from_base and "base" or (anm2 or "spr")) .. "|" .. anim_source,
			from_base = from_base and true or false,
			is_flying = is_flying and true or false,
			anim_source = anim_source,
			role = anim_source,
			anm2 = anm2 or sprite_anm2(spr),
		}
	end
	local function commit_slot(slot)
		if not slot or not slot.plan_key then return end
		candidates[#candidates + 1] = slot
		local prev = winners[slot.plan_key]
		if not prev or (slot.priority or 0) >= (prev.priority or 0) then
			winners[slot.plan_key] = slot
		end
	end
	local function collect_slots(probe_spr, priority, is_flying, from_base, anm2)
		if not RM.sprite_is_usable(probe_spr) then return end
		local ok_n, n = pcall(function() return probe_spr:GetLayerCount() end)
		if not ok_n or type(n) ~= "number" then return end
		for i = 0, n - 1 do
			if not RM.sprite_layer_usable(probe_spr, i) then goto continue end
			local key = nil
			pcall(function()
				local lay = probe_spr:GetLayer(i)
				if lay and lay.GetName then
					key = RM.costume_layer_key(lay:GetName())
				end
			end)
			if type(key) ~= "string" or key == "" then
				key = "n" .. tostring(i)
			end
			if from_base then
				commit_slot(make_slot(probe_spr, i, key, priority, is_flying, true, anm2, "body"))
			else
				local body_spr = probe_spr
				local head_spr = probe_spr
				if type(anm2) == "string" then
					body_spr = pool_sprite_for(anm2, "body") or probe_spr
					head_spr = pool_sprite_for(anm2, "head") or probe_spr
				end
				commit_slot(make_slot(body_spr, i, key, priority, is_flying, false, anm2, "body"))
				commit_slot(make_slot(head_spr, i, key, priority, is_flying, false, anm2, "head"))
			end
			::continue::
		end
	end
	if base_sprite then
		pcall(function()
			collect_slots(base_sprite, 0, appearance.can_fly, true, sprite_anm2(base_sprite))
		end)
	end
	if use_live and has_layers then
		for _, bind in ipairs(appearance.costume_layers) do
			local key = RM.psl_index_to_key(bind.sprite_layer)
			local ci = nil
			local spr, lid = nil, tonumber(bind.layer_id)
			if opts.live_map and key then
				local map_idx = (tonumber(bind.sprite_layer) or -1) + 1
				local mapData = opts.live_map[map_idx]
				if type(mapData) == "table" then
					ci = tonumber(mapData.costumeIndex)
					if ci and ci >= 0 then
						local desc = live_descs[ci + 1]
						if desc then
							pcall(function() spr = desc:GetSprite() end)
						end
					end
				end
			end
			-- Live capture must use real costume sprites; never fall back to a freshly loaded anm2.
			if key and spr and lid and lid >= 0 then
				local function live_commit(anim_source)
					local slot = make_slot(spr, lid, key, tonumber(bind.priority) or 1, bind.is_flying, false, bind.anm2, anim_source)
					slot.sprite_layer = tonumber(bind.sprite_layer)
					slot.costume_index = ci
					commit_slot(slot)
				end
				live_commit("body")
				live_commit("head")
			end
		end
	elseif has_layers then
		for _, bind in ipairs(appearance.costume_layers) do
			local key = RM.psl_index_to_key(bind.sprite_layer)
			local lid = tonumber(bind.layer_id)
			local probe = pool_sprite_for(bind.anm2, "body") or pool_sprite_for(bind.anm2, "head")
			if key and probe and lid and lid >= 0 then
				local body_spr = pool_sprite_for(bind.anm2, "body") or probe
				local head_spr = pool_sprite_for(bind.anm2, "head") or probe
				local body_slot = make_slot(body_spr, lid, key, tonumber(bind.priority) or 1, bind.is_flying, false, bind.anm2, "body")
				body_slot.sprite_layer = tonumber(bind.sprite_layer)
				commit_slot(body_slot)
				local head_slot = make_slot(head_spr, lid, key, tonumber(bind.priority) or 1, bind.is_flying, false, bind.anm2, "head")
				head_slot.sprite_layer = tonumber(bind.sprite_layer)
				commit_slot(head_slot)
			end
		end
	else
		for _, c in ipairs(appearance.costumes or {}) do
			-- Probe layer names from either role sprite (same ANM2 layout).
			local probe = pool_sprite_for(c.anm2, "body") or pool_sprite_for(c.anm2, "head")
			if probe then
				collect_slots(probe, tonumber(c.priority) or 1, c.is_flying, false, c.anm2)
			end
		end
	end
	local driver = RM.ghost_pick_body_driver(winners)
	return {
		winners = winners,
		candidates = candidates,
		pool = pool,
		driver_key = driver and (driver.plan_key or driver.key) or nil,
	}
end

function RM.read_sprite_full_pose(spr)
	local anim, frame, overlay_anim, overlay_frame, flip_x =
		nil, 0, nil, 0, false
	if not spr then return anim, frame, overlay_anim, overlay_frame, flip_x end
	pcall(function()
		anim = spr:GetAnimation()
		frame = spr:GetFrame() or 0
		overlay_anim = spr:GetOverlayAnimation()
		overlay_frame = spr:GetOverlayFrame() or 0
		flip_x = spr.FlipX and true or false
	end)
	if type(overlay_anim) ~= "string" or overlay_anim == "" then
		overlay_anim = nil
		overlay_frame = 0
	end
	return anim, frame, overlay_anim, overlay_frame, flip_x
end

function RM.pose_clock_eq(anim_a, frame_a, anim_b, frame_b)
	local a = type(anim_a) == "string" and anim_a or ""
	local b = type(anim_b) == "string" and anim_b or ""
	return a == b and (tonumber(frame_a) or 0) == (tonumber(frame_b) or 0)
end

function RM.live_costume_fingerprint(player, appearance)
	local parts = {}
	if type(appearance) == "table" and type(appearance.costume_layers) == "table" then
		for i = 1, #appearance.costume_layers do
			local b = appearance.costume_layers[i]
			parts[#parts + 1] = tostring(b and b.sprite_layer)
			parts[#parts + 1] = tostring(b and b.anm2)
			parts[#parts + 1] = tostring(b and b.layer_id)
			parts[#parts + 1] = tostring(b and b.priority)
		end
	end
	local n = 0
	if player and player.GetCostumeSpriteDescs then
		pcall(function()
			local descs = player:GetCostumeSpriteDescs()
			if type(descs) == "table" then n = #descs end
		end)
	end
	parts[#parts + 1] = "n" .. tostring(n)
	return table.concat(parts, "|")
end

--- Runtime-only cache for Aeon recording (do not save).
function RM.begin_live_pose_capture(player, appearance)
	appearance = appearance or RM.capture_player_appearance(player)
	appearance = RM.sanitize_appearance(appearance) or appearance
	return {
		appearance = appearance,
		fingerprint = RM.live_costume_fingerprint(player, appearance),
	}
end

function RM.refresh_live_pose_capture(runtime, player)
	if type(runtime) ~= "table" or not player then return runtime end
	local appearance = RM.capture_player_appearance(player)
	appearance = RM.sanitize_appearance(appearance) or appearance
	runtime.appearance = appearance
	runtime.fingerprint = RM.live_costume_fingerprint(player, appearance)
	return runtime
end

--- Capture standard body/head clocks + sparse winning-layer overrides that diverge.
function RM.capture_player_composite_pose(player, appearance, runtime)
	if not player or not player:Exists() then return nil end
	local base = player:GetSprite()
	local body_anim, body_frame, head_anim, head_frame, flip_x =
		"WalkDown", 0, nil, 0, false
	if base then
		body_anim, body_frame, head_anim, head_frame, flip_x = RM.read_sprite_full_pose(base)
		if type(body_anim) ~= "string" or body_anim == "" then
			body_anim = "WalkDown"
		end
	end
	local pose = {
		body = { anim = body_anim, frame = body_frame or 0 },
		head = { anim = head_anim, frame = head_frame or 0 },
		flip_x = flip_x and true or false,
		overrides = nil,
	}
	appearance = (runtime and runtime.appearance) or appearance
	if not appearance then
		appearance = RM.capture_player_appearance(player)
	end
	appearance = RM.sanitize_appearance(appearance) or appearance
	if runtime then
		local fp = RM.live_costume_fingerprint(player, appearance)
		if runtime.fingerprint ~= fp then
			RM.refresh_live_pose_capture(runtime, player)
			appearance = runtime.appearance
		end
	end
	local live_descs, live_map = nil, nil
	if player.GetCostumeSpriteDescs then
		pcall(function() live_descs = player:GetCostumeSpriteDescs() end)
	end
	if player.GetCostumeLayerMap then
		pcall(function() live_map = player:GetCostumeLayerMap() end)
	end
	local resolved = RM.resolve_costume_winners({
		appearance = appearance,
		base_sprite = base,
		live_descs = live_descs,
		live_map = live_map,
	})
	local winners = resolved and resolved.winners
	if type(winners) ~= "table" then
		return pose
	end
	local overrides = nil
	for key, slot in pairs(winners) do
		if not slot or slot.from_base or not slot.spr then goto continue end
		local anim, frame, oanim, oframe, sflip = RM.read_sprite_full_pose(slot.spr)
		local is_head = slot.anim_source == "head"
		local need = false
		if is_head then
			local main_ok = RM.pose_clock_eq(anim, frame, body_anim, body_frame)
			local has_ov = type(oanim) == "string" and oanim ~= ""
			local ov_ok = (not has_ov and (not head_anim or head_anim == ""))
				or (has_ov and RM.pose_clock_eq(oanim, oframe, head_anim, head_frame))
			if not has_ov and RM.pose_clock_eq(anim, frame, head_anim, head_frame) then
				main_ok, ov_ok = true, true
			end
			need = not (main_ok and ov_ok)
		else
			need = not RM.pose_clock_eq(anim, frame, body_anim, body_frame)
			if not need and type(oanim) == "string" and oanim ~= "" then
				if not RM.pose_clock_eq(oanim, oframe, head_anim, head_frame) then
					need = true
				end
			end
		end
		if need then
			local has_overlay = type(oanim) == "string" and oanim ~= ""
			-- Head costume whose main clock is the head anim (not Walk* + overlay).
			local head_main = is_head and (not has_overlay)
				and not RM.pose_clock_eq(anim, frame, body_anim, body_frame)
			local ov = {
				anim = anim,
				frame = tonumber(frame) or 0,
				has_overlay = has_overlay and true or false,
			}
			if has_overlay then
				ov.overlay_anim = oanim
				ov.overlay_frame = tonumber(oframe) or 0
			end
			if head_main then
				ov.head_main = true
			end
			if sflip ~= flip_x then
				ov.flip_x = sflip and true or false
			end
			if slot.sprite_layer ~= nil then
				ov.slot = tonumber(slot.sprite_layer)
			end
			overrides = overrides or {}
			overrides[slot.plan_key or key] = ov
		end
		::continue::
	end
	pose.overrides = overrides
	local override_count = 0
	if overrides then
		for _ in pairs(overrides) do
			override_count = override_count + 1
		end
	end
	RM.emit_ghost_probe("capture_composite_pose", nil, {
		body_anim = body_anim,
		body_frame = body_frame,
		head_anim = head_anim,
		head_frame = head_frame,
		override_count = override_count,
	})
	return pose
end

--- replace=true：完整替代 sprite 时钟（先清 overlay），用于 recorded layer override。
function RM.ghost_apply_layer_override(spr, ov, opts)
	if not spr or type(ov) ~= "table" then return end
	opts = type(opts) == "table" and opts or {}
	local replace = opts.replace == true
	if replace then
		local want_overlay = ov.has_overlay == true
			or (ov.has_overlay == nil and type(ov.overlay_anim) == "string" and ov.overlay_anim ~= "")
		if not want_overlay then
			pcall(function()
				if spr.RemoveOverlay then spr:RemoveOverlay() end
			end)
		end
	end
	if type(ov.anim) == "string" and ov.anim ~= "" then
		pcall(function()
			if spr:GetAnimation() ~= ov.anim then
				spr:Play(ov.anim, true)
			end
			spr:SetFrame(ov.anim, tonumber(ov.frame) or 0)
		end)
	elseif ov.frame ~= nil then
		pcall(function() spr:SetFrame(tonumber(ov.frame) or 0) end)
	end
	local want_overlay = ov.has_overlay == true
		or (ov.has_overlay == nil and type(ov.overlay_anim) == "string" and ov.overlay_anim ~= "")
	if want_overlay and type(ov.overlay_anim) == "string" and ov.overlay_anim ~= "" then
		pcall(function()
			if spr:GetOverlayAnimation() ~= ov.overlay_anim then
				spr:PlayOverlay(ov.overlay_anim, true)
			end
			spr:SetOverlayFrame(ov.overlay_anim, tonumber(ov.overlay_frame) or 0)
		end)
	elseif replace or ov.has_overlay == false then
		pcall(function()
			if spr.RemoveOverlay then spr:RemoveOverlay() end
		end)
	end
	if ov.flip_x ~= nil then
		spr.FlipX = ov.flip_x and true or false
	end
end

--- Explicit alias: full main+overlay clock replace (body / custom slots).
function RM.ghost_apply_full_layer_override(spr, ov, opts)
	opts = type(opts) == "table" and opts or {}
	opts.replace = true
	return RM.ghost_apply_layer_override(spr, ov, opts)
end

local function anim_looks_like_body_walk(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	local lower = string.lower(name)
	return string.find(lower, "walk", 1, true) ~= nil
		or string.find(lower, "idle", 1, true) ~= nil
end

--- Recorded head slot clock ownership (not the player's body main clock).
--- head_main: this costume sprite's main anim IS the head (e.g. HeadDownCharge).
--- else: main follows recorded body; overlay follows recorded head.
function RM.ghost_apply_recorded_head_override(spr, ov, body_anim, body_frame, fallback_overlay_anim, fallback_overlay_frame)
	if not RM.sprite_is_usable(spr) or type(ov) ~= "table" then
		return
	end
	local has_overlay = ov.has_overlay == true
		or (type(ov.overlay_anim) == "string" and ov.overlay_anim ~= "")
	-- head_main: costume stores head animation on main (no overlay). Legacy saves may omit the flag.
	local head_main = ov.head_main == true
		or (not has_overlay and type(ov.anim) == "string" and ov.anim ~= "" and not anim_looks_like_body_walk(ov.anim))

	pcall(function()
		if head_main then
			-- This sprite itself is the recorded head clock (not body Walk*).
			if type(ov.anim) == "string" and ov.anim ~= "" then
				RM.sprite_ensure_one_of(spr, {ov.anim})
				spr:SetFrame(ov.anim, tonumber(ov.frame) or 0)
			end
			if spr.RemoveOverlay then
				spr:RemoveOverlay()
			end
		else
			-- Main clock always belongs to recorded body.
			if type(body_anim) == "string" and body_anim ~= "" then
				RM.sprite_ensure_one_of(spr, RM.ghost_walk_anim_candidates(body_anim))
				spr:SetFrame(body_anim, tonumber(body_frame) or 0)
			end
			local oanim = ov.overlay_anim or fallback_overlay_anim
			local oframe = ov.overlay_frame
			if oframe == nil then
				oframe = fallback_overlay_frame
			end
			oframe = tonumber(oframe) or 0
			if type(oanim) == "string" and oanim ~= "" then
				if spr:GetOverlayAnimation() ~= oanim then
					spr:PlayOverlay(oanim, true)
				end
				spr:SetOverlayFrame(oanim, oframe)
			elseif spr.RemoveOverlay then
				spr:RemoveOverlay()
			end
		end
		if ov.flip_x ~= nil then
			spr.FlipX = ov.flip_x and true or false
		end
	end)
end

function RM.capture_current_floor()
	local level = Game():GetLevel()
	local stage = level:GetStage()
	local stage_type = level:GetStageType()
	local command = tostring(stage)..RM.stage_type_suffix(stage_type)
	return RM.sanitize_floor_info({
		stage = stage,
		stage_type = stage_type,
		command = command,
		seed_stage = stage,
	})
end

function RM.floor_equals(info)
	if not info then return false end
	local level = Game():GetLevel()
	return level:GetStage() == info.stage and level:GetStageType() == info.stage_type
end

function RM.level_stage_snapshot()
	local level = Game():GetLevel()
	return {
		stage = level:GetStage(),
		stage_type = level:GetStageType(),
	}
end

function RM.snapshot_equals(a, b)
	return type(a) == "table" and type(b) == "table"
		and a.stage == b.stage and a.stage_type == b.stage_type
end

--- Remaster 抵达/回传后，须换到任意不同层才允许再次自动回传（不限制主动出发）。
function RM.remaster_return_blocked()
	local lock = save.elses[C.DESCENT_LOCK_KEY]
	if type(lock) ~= "table" then return false end
	return RM.snapshot_equals(lock, RM.level_stage_snapshot())
end

--- 抵达目标层或回传落地后写入；切换到任意不同层解除，仅挡自动回传。
function RM.arm_descent_lock()
	save.elses[C.DESCENT_LOCK_KEY] = RM.level_stage_snapshot()
end

function RM.clear_descent_lock()
	save.elses[C.DESCENT_LOCK_KEY] = nil
end

function RM.try_clear_descent_lock_on_level_change()
	if item._remaster_level_change then
		item._remaster_level_change = false
		return
	end
	local lock = save.elses[C.DESCENT_LOCK_KEY]
	if type(lock) ~= "table" then return end
	local cur = RM.level_stage_snapshot()
	if not RM.snapshot_equals(cur, lock) then
		RM.clear_descent_lock()
	end
end

function RM.on_remaster_arrival()
	RM.arm_descent_lock()
end

function RM.checkpoint_save(reason)
	if save.RuntimeLoaded == true and type(save.SaveModData) == "function" then
		pcall(save.SaveModData, "remaster:"..tostring(reason or "channel"))
	end
end

function RM.player_has_belial_synergy(player)
	if not player or not player:Exists() then return false end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_BELIAL, true) then return true end
	if CollectibleType.COLLECTIBLE_BOOK_OF_BELIAL_PASSIVE
		and player:HasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_BELIAL_PASSIVE, true) then
		return true
	end
	return auxi.should_do_belial(player)
end

function RM.sanitize_belial_stats(stats)
	if type(stats) ~= "table" then return nil end
	local out = {
		damage = tonumber(stats.damage),
		max_firedelay = tonumber(stats.max_firedelay),
		range = tonumber(stats.range),
		speed = tonumber(stats.speed),
		luck = tonumber(stats.luck),
		shotspeed = tonumber(stats.shotspeed),
	}
	if not out.damage and not out.max_firedelay and not out.range
		and not out.speed and not out.luck and not out.shotspeed then
		return nil
	end
	return out
end

function RM.player_has_virtues_book(player)
	return player
		and player:Exists()
		and player:HasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES, true)
end

function RM.resolve_cine_wisp(cine)
	if not cine then return nil end
	local w = cine.channel_wisp
	if w and w.Exists and w:Exists() then return w end
	cine.channel_wisp = nil
	return nil
end

function RM.prep_channel_wisp(wisp, opts)
	if not wisp or not wisp.Exists or not wisp:Exists() then return end
	opts = opts or {}
	pcall(function()
		if wisp.ClearEntityFlags and EntityFlag.FLAG_APPEAR then
			wisp:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
		end
	end)
	pcall(function()
		wisp.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	end)
	if opts.emerge_from_channel then
		local po_y = opts.emerge_po_y or C.WISP_CHANNEL_EMERGE_PO_Y
		wisp.PositionOffset = Vector(0, po_y)
	end
end

function RM.build_channel_wisp_flight(opts)
	opts = opts or {}
	local mode = opts.mode or "fly"
	local flight = {
		mode = mode,
		t = 0,
		remove_on_arrive = opts.remove_on_arrive ~= false,
		on_arrive = opts.on_arrive,
	}
	if mode == "orbit" then
		flight.orbit_player = opts.orbit_player
		flight.angle = opts.angle or 0
		flight.radius = opts.radius or C.WISP_ORBIT_RADIUS
		flight.orbit_speed = opts.orbit_speed or C.WISP_ORBIT_SPEED
	elseif mode == "hover" then
		flight.portal_pos = opts.portal_pos and Vector(opts.portal_pos.X, opts.portal_pos.Y) or nil
		flight.hover_po_y = opts.hover_po_y or C.WISP_HOVER_PO_Y
	elseif mode == "fall" then
		flight.portal_pos = opts.portal_pos and Vector(opts.portal_pos.X, opts.portal_pos.Y) or nil
		flight.fall_t = 0
		flight.fall_dur = opts.fall_dur or C.WISP_FALL_DUR
		flight.po_from = opts.po_from or Vector(0, C.WISP_HOVER_PO_Y)
		flight.po_to = opts.po_to or Vector(0, 0)
	elseif mode == "fly" then
		flight.to = opts.to_pos and Vector(opts.to_pos.X, opts.to_pos.Y) or nil
		flight.to_player = opts.to_player
		flight.speed = opts.speed or C.WISP_FLY_SPEED
		flight.arrive = opts.arrive or C.WISP_FLY_ARRIVE
		if opts.emerge_from_channel then
			local po_y = opts.emerge_po_y or C.WISP_CHANNEL_EMERGE_PO_Y
			flight.po_from = Vector(0, po_y)
			flight.po_to = Vector.Zero
			flight.po_dur = opts.po_dur or C.WISP_PO_EMERGE_DUR
		end
	end
	return flight
end

function RM.spawn_channel_wisp(player, spawn_pos, opts)
	if not player or not player:Exists() or not spawn_pos then return nil end
	opts = opts or {}
	local pd = player:GetData()
	pd[NEXT_CHANNEL_WISP_KEY] = opts
	local wisp = player:AddWisp(item.entity, spawn_pos, true, false)
	pd[NEXT_CHANNEL_WISP_KEY] = nil
	if not wisp or not wisp.Exists or not wisp:Exists() then return nil end
	RM.prep_channel_wisp(wisp, opts)
	local d = wisp:GetData()
	d[CHANNEL_WISP_KEY] = true
	local flight = RM.build_channel_wisp_flight(opts)
	d[CHANNEL_WISP_FLIGHT_KEY] = flight
	if flight.mode == "hover" or flight.mode == "fall" then
		if flight.portal_pos then
			wisp.Position = flight.portal_pos
		end
		if flight.mode == "hover" then
			wisp.PositionOffset = Vector(0, flight.hover_po_y)
		elseif flight.mode == "fall" then
			wisp.PositionOffset = Vector(flight.po_from.X, flight.po_from.Y)
		end
	end
	wisp.Velocity = Vector.Zero
	return wisp
end

function RM.begin_channel_wisp_fall(wisp, opts)
	if not wisp or not wisp.Exists or not wisp:Exists() then return end
	opts = opts or {}
	local d = wisp:GetData()
	if not d[CHANNEL_WISP_KEY] then return end
	local portal_pos = opts.portal_pos or wisp.Position
	local flight = RM.build_channel_wisp_flight({
		mode = "fall",
		portal_pos = portal_pos,
		fall_dur = opts.fall_dur,
		po_from = opts.po_from or Vector(0, C.WISP_HOVER_PO_Y),
		po_to = opts.po_to or Vector(0, 0),
		remove_on_arrive = opts.remove_on_arrive,
		on_arrive = opts.on_arrive,
	})
	d[CHANNEL_WISP_FLIGHT_KEY] = flight
	wisp.Position = portal_pos
	wisp.Velocity = Vector.Zero
end

function RM.tick_channel_wisp_flight(wisp)
	if not wisp or not wisp.Exists or not wisp:Exists() then return false end
	local d = wisp:GetData()
	if not d[CHANNEL_WISP_KEY] then return false end
	local flight = d[CHANNEL_WISP_FLIGHT_KEY]
	if type(flight) ~= "table" then return false end
	flight.t = (flight.t or 0) + 1
	local mode = flight.mode or "fly"

	if mode == "orbit" then
		local center_p = flight.orbit_player
		if not (center_p and center_p.Exists and center_p:Exists()) then return true end
		flight.angle = (flight.angle or 0) + (flight.orbit_speed or C.WISP_ORBIT_SPEED)
		local r = flight.radius or C.WISP_ORBIT_RADIUS
		local c = center_p.Position
		wisp.Position = Vector(c.X + math.cos(flight.angle) * r, c.Y + math.sin(flight.angle) * r)
		wisp.Velocity = Vector.Zero
		wisp.PositionOffset = Vector.Zero
		return true
	end

	if mode == "hover" then
		if flight.portal_pos then
			wisp.Position = flight.portal_pos
		end
		wisp.Velocity = Vector.Zero
		wisp.PositionOffset = Vector(0, flight.hover_po_y or C.WISP_HOVER_PO_Y)
		return true
	end

	if mode == "fall" then
		flight.fall_t = (flight.fall_t or 0) + 1
		local dur = flight.fall_dur or C.WISP_FALL_DUR
		local u = math.min(1, flight.fall_t / dur)
		u = u * u * (3 - 2 * u)
		if flight.portal_pos then
			wisp.Position = flight.portal_pos
		end
		wisp.Velocity = Vector.Zero
		wisp.PositionOffset = RM.vec_lerp(flight.po_from or Vector(0, C.WISP_HOVER_PO_Y), flight.po_to or Vector.Zero, u)
		if u >= 1 then
			if flight.on_arrive then pcall(flight.on_arrive, wisp) end
			if flight.remove_on_arrive then
				pcall(function() wisp:Remove() end)
			else
				d[CHANNEL_WISP_FLIGHT_KEY] = nil
			end
		end
		return true
	end

	-- fly
	if flight.po_from and flight.po_to then
		local po_u = math.min(1, flight.t / (flight.po_dur or C.WISP_PO_EMERGE_DUR))
		wisp.PositionOffset = RM.vec_lerp(flight.po_from, flight.po_to, po_u)
	end
	local to = flight.to
	if flight.to_player and flight.to_player.Exists and flight.to_player:Exists() then
		to = flight.to_player.Position
	end
	if not to then return false end
	local pos = wisp.Position
	local delta = to - pos
	local dist = delta:Length()
	local speed = flight.speed or C.WISP_FLY_SPEED
	local arrive = flight.arrive or C.WISP_FLY_ARRIVE
	if dist <= arrive then
		wisp.Position = to
		wisp.Velocity = Vector.Zero
		if flight.po_to then wisp.PositionOffset = flight.po_to end
		if flight.on_arrive then pcall(flight.on_arrive, wisp) end
		if flight.remove_on_arrive then
			pcall(function() wisp:Remove() end)
		else
			d[CHANNEL_WISP_FLIGHT_KEY] = nil
		end
		return true
	end
	local dir = delta:Normalized()
	local step = math.min(speed, dist)
	wisp.Velocity = dir * speed
	wisp.Position = pos + dir * step
	return true
end

function RM.ensure_outbound_orbit_wisp(cine, player)
	if not cine or not cine.remaster_wisp or cine._orbit_wisp_spawned then return end
	if not player or not player:Exists() then return end
	cine._orbit_wisp_spawned = true
	cine.channel_wisp = RM.spawn_channel_wisp(player, player.Position, {
		mode = "orbit",
		orbit_player = player,
	})
end

function RM.trigger_outbound_wisp_fall(cine, player)
	if not cine or cine._wisp_fall_started then return end
	local wisp = RM.resolve_cine_wisp(cine)
	if not wisp then return end
	cine._wisp_fall_started = true
	local portal_pos = RM.cine_portal_pos(cine, player)
	RM.begin_channel_wisp_fall(wisp, {
		portal_pos = portal_pos,
		remove_on_arrive = true,
	})
end

function RM.ensure_arrival_hover_wisp(cine, player)
	if not cine or cine._hover_wisp_spawned then return end
	if not RM.channel_has_remaster_wisp() then return end
	player = player or cine.player
	if not player or not player:Exists() then return end
	cine._hover_wisp_spawned = true
	local portal_pos = RM.cine_portal_pos(cine, player)
	cine.channel_wisp = RM.spawn_channel_wisp(player, portal_pos, {
		mode = "hover",
		portal_pos = portal_pos,
	})
end

function RM.trigger_arrival_wisp_fall_and_close(cine, player, portal)
	if not cine or cine._wisp_fall_started then return end
	local wisp = RM.resolve_cine_wisp(cine)
	if not wisp then
		if portal and portal:Exists() then RM.close_portal(portal) end
		cine.portal = nil
		return
	end
	cine._wisp_fall_started = true
	cine.phase = "wisp_fall_close"
	cine.t0 = Game():GetFrameCount()
	local portal_pos = RM.cine_portal_pos(cine, player)
	RM.begin_channel_wisp_fall(wisp, {
		portal_pos = portal_pos,
		remove_on_arrive = true,
		on_arrive = function()
			if portal and portal.Exists and portal:Exists() then
				RM.close_portal(portal)
			end
			cine.portal = nil
		end,
	})
end

function RM.return_cine_has_remaster_wisp(cine)
	local ch = cine and cine.channel
	local head = ch and type(ch.return_pending) == "table" and ch.return_pending[1]
	return head and head.remaster_wisp == true
end

function RM.ensure_return_ghost_hover_wisp(cine)
	if not cine or cine._ghost_hover_wisp_spawned then return end
	if not RM.return_cine_has_remaster_wisp(cine) then return end
	local player = cine.player
	if not player or not player:Exists() then return end
	cine._ghost_hover_wisp_spawned = true
	local portal_pos = RM.cine_portal_pos(cine, player)
	cine.channel_wisp = RM.spawn_channel_wisp(player, portal_pos, {
		mode = "hover",
		portal_pos = portal_pos,
	})
end

function RM.trigger_return_ghost_wisp_fall(cine)
	if not cine or cine._ghost_wisp_fall_started then return end
	local wisp = RM.resolve_cine_wisp(cine)
	if not wisp then return end
	cine._ghost_wisp_fall_started = true
	local portal_pos = RM.cine_portal_pos(cine, cine.player)
	RM.begin_channel_wisp_fall(wisp, {
		portal_pos = portal_pos,
		remove_on_arrive = true,
	})
end

function RM.try_play_return_wisp_grant(cine, player, portal_pos)
	if not player or not player:Exists() then return end
	portal_pos = portal_pos or (player and player.Position)
	cine.channel_wisp = RM.spawn_channel_wisp(player, portal_pos, {
		mode = "fly",
		to_player = player,
		remove_on_arrive = false,
		emerge_from_channel = true,
	})
end

function RM.cine_portal_pos(cine, player)
	if cine and cine.portal and cine.portal.Exists and cine.portal:Exists() then
		return cine.portal.Position
	end
	if cine and cine.portal_pos then return cine.portal_pos end
	return RM.pick_portal_pos(player)
end

function RM.channel_has_remaster_wisp()
	for _, ch in ipairs(item.get_channels() or {}) do
		if type(ch.return_pending) == "table" and ch.return_pending[1] and ch.return_pending[1].remaster_wisp then
			return true
		end
	end
	return false
end

function RM.capture_remaster_wisp_flag(player)
	if not RM.player_has_virtues_book(player) then return nil end
	return true
end

function RM.grant_remaster_channel_wisp(player)
	if not player or not player:Exists() then return end
	pcall(function() player:AddWisp(item.entity, player.Position, true, false) end)
end

function RM.capture_belial_stats(player)
	if not RM.player_has_belial_synergy(player) then return nil end
	return RM.sanitize_belial_stats({
		damage = player.Damage,
		max_firedelay = player.MaxFireDelay,
		range = player.TearRange,
		speed = player.MoveSpeed,
		luck = player.Luck,
		shotspeed = player.ShotSpeed,
	})
end

function RM.capture_outbound_synergy(player)
	return {
		remaster_wisp = RM.capture_remaster_wisp_flag(player),
		belial_stats = RM.capture_belial_stats(player),
	}
end

function RM.belial_layer_matches(level)
	local boost = save.elses[C.BELIAL_LAYER_KEY]
	if type(boost) ~= "table" or not boost.stats then return false end
	level = level or Game():GetLevel()
	return level:GetStage() == boost.stage and level:GetStageType() == boost.stage_type
end

function RM.arm_belial_layer_boost(stats)
	stats = RM.sanitize_belial_stats(stats)
	if not stats then return end
	local level = Game():GetLevel()
	save.elses[C.BELIAL_LAYER_KEY] = {
		stage = level:GetStage(),
		stage_type = level:GetStageType(),
		stats = stats,
	}
end

function RM.apply_belial_layer_cache(player, cacheFlag)
	if not player or not RM.belial_layer_matches() then return end
	local s = save.elses[C.BELIAL_LAYER_KEY].stats
	if not s then return end
	if cacheFlag == CacheFlag.CACHE_DAMAGE and s.damage and player.Damage < s.damage then
		player.Damage = s.damage
	end
	if cacheFlag == CacheFlag.CACHE_FIREDELAY and s.max_firedelay and player.MaxFireDelay > s.max_firedelay then
		player.MaxFireDelay = s.max_firedelay
	end
	if cacheFlag == CacheFlag.CACHE_RANGE and s.range and player.TearRange < s.range then
		player.TearRange = s.range
	end
	if cacheFlag == CacheFlag.CACHE_SPEED and s.speed and player.MoveSpeed < s.speed then
		player.MoveSpeed = s.speed
	end
	if cacheFlag == CacheFlag.CACHE_LUCK and s.luck and player.Luck < s.luck then
		player.Luck = s.luck
	end
	if cacheFlag == CacheFlag.CACHE_SHOTSPEED and s.shotspeed and player.ShotSpeed < s.shotspeed then
		player.ShotSpeed = s.shotspeed
	end
end

function RM.apply_remaster_synergy_on_return(player, payload, opts)
	opts = opts or {}
	if not player or type(payload) ~= "table" then return end
	if payload.remaster_wisp and not opts.skip_remaster_wisp then
		RM.grant_remaster_channel_wisp(player)
	end
	if payload.belial_stats then
		-- 回程落地层：写入出发角色的属性快照，本层内 EVALUATE_CACHE 取双方较高值。
		RM.arm_belial_layer_boost(payload.belial_stats)
		player:AddCacheFlags(
			CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_RANGE
				| CacheFlag.CACHE_SPEED | CacheFlag.CACHE_LUCK | CacheFlag.CACHE_SHOTSPEED
		)
	end
end

function RM.sanitize_passenger_entry(entry)
	if type(entry) ~= "table" then return nil end
	local app = RM.sanitize_appearance(entry.appearance)
	if not app then return nil end
	local remaster_wisp = entry.remaster_wisp == true
		or entry.has_virtues_book == true
		or (type(entry.virtue_wisps) == "table" and #entry.virtue_wisps > 0)
		or (tonumber(entry.virtue_wisp_count) or 0) > 0
	return {
		appearance = app,
		opened_run_id = type(entry.opened_run_id) == "string" and entry.opened_run_id or nil,
		remaster_wisp = remaster_wisp and true or nil,
		belial_stats = RM.sanitize_belial_stats(entry.belial_stats),
	}
end

function RM.sanitize_passenger_list(list)
	if type(list) ~= "table" then return {} end
	local out = {}
	for _, entry in ipairs(list) do
		local norm = RM.sanitize_passenger_entry(entry)
		if norm then out[#out + 1] = norm end
	end
	return out
end

function RM.channel_active_return_passenger(ch)
	if not ch then return nil end
	local pending = ch.return_pending
	if type(pending) == "table" and pending[1] then return pending[1] end
	if ch.armed and ch.appearance then
		return {
			appearance = ch.appearance,
			opened_run_id = ch.opened_run_id,
		}
	end
	return nil
end

function RM.passenger_blocks_return_this_run(passenger)
	if not passenger then return false end
	local opened = passenger.opened_run_id
	if type(opened) ~= "string" or opened == "" then return false end
	return opened == RM.get_current_run_id()
end

function RM.channel_blocks_return_this_run(ch)
	return RM.passenger_blocks_return_this_run(RM.channel_active_return_passenger(ch))
end

function RM.normalize_channel(ch)
	if type(ch) ~= "table" then return nil end
	local from = RM.sanitize_floor_info(ch.from)
	local to = RM.sanitize_floor_info(ch.to)
	if not from or not to or not from.command or not to.command then return nil end
	if from.command == "" or to.command == "" then return nil end
	local outbound_pending = RM.sanitize_passenger_list(ch.outbound_pending)
	local return_pending = RM.sanitize_passenger_list(ch.return_pending)
	local appearance = RM.sanitize_appearance(ch.appearance)
	local opened_run_id = type(ch.opened_run_id) == "string" and ch.opened_run_id or nil
	local armed = ch.armed and true or false
	if armed and #return_pending == 0 and appearance then
		return_pending[1] = {
			appearance = appearance,
			opened_run_id = opened_run_id,
		}
	end
	local active = return_pending[1]
	if active then
		appearance = active.appearance
		opened_run_id = active.opened_run_id
	end
	return {
		from = from,
		to = to,
		target_code = ch.target_code and tostring(ch.target_code) or nil,
		target_name = ch.target_name and tostring(ch.target_name) or nil,
		appearance = appearance,
		armed = armed,
		skip_arrive_once = ch.skip_arrive_once and true or nil,
		returning = ch.returning and true or nil,
		opened_run_id = opened_run_id,
		outbound_pending = outbound_pending,
		return_pending = return_pending,
	}
end

function RM.channels_bag()
	save.PermanentData = save.PermanentData or {}
	local bag = save.PermanentData[C.PERM_CHANNELS_KEY]
	if type(bag) ~= "table" then
		bag = {list = {}}
		save.PermanentData[C.PERM_CHANNELS_KEY] = bag
	end
	if type(bag.list) ~= "table" then bag.list = {} end
	return bag
end

function item.get_channels()
	return RM.channels_bag().list
end

function RM.find_channel_index_by_to(to_command)
	to_command = tostring(to_command or "")
	local list = item.get_channels()
	for i, ch in ipairs(list) do
		if ch.to and tostring(ch.to.command) == to_command then return i, ch end
	end
	return nil, nil
end

function RM.find_channel_index_by_route(from_command, to_command)
	from_command = tostring(from_command or "")
	to_command = tostring(to_command or "")
	local list = item.get_channels()
	for i, ch in ipairs(list) do
		if ch.from and ch.to
			and tostring(ch.from.command) == from_command
			and tostring(ch.to.command) == to_command then
			return i, ch
		end
	end
	return nil, nil
end

function RM.write_channels(list, reason)
	local bag = RM.channels_bag()
	bag.list = list or {}
	RM.checkpoint_save(reason or "channels")
end

--- 调试/ImGui：按目标楼层（to）去重写入；同 to 覆盖旧渠道。
function RM.upsert_channel(ch)
	local norm = RM.normalize_channel(ch)
	if not norm then return nil end
	local list = item.get_channels()
	local idx = RM.find_channel_index_by_to(norm.to.command)
	if idx then
		list[idx] = norm
	else
		list[#list + 1] = norm
		idx = #list
	end
	RM.write_channels(list, norm.armed and "arm" or "set")
	return idx, norm
end

--- 同一路线（from->to）追加出发乘客；支持多次使用并按 FIFO 依次回传。
function RM.register_outbound_passenger(from, to, target, appearance, opened_run_id, synergy)
	local passenger = RM.sanitize_passenger_entry({
		appearance = appearance,
		opened_run_id = opened_run_id,
		remaster_wisp = synergy and synergy.remaster_wisp,
		belial_stats = synergy and synergy.belial_stats,
	})
	if not passenger then return nil end
	local list = item.get_channels()
	local idx = RM.find_channel_index_by_route(from.command, to.command)
	if idx then
		local ch = list[idx]
		ch.outbound_pending = ch.outbound_pending or {}
		ch.outbound_pending[#ch.outbound_pending + 1] = passenger
		ch.skip_arrive_once = true
		if target then
			if target.code then ch.target_code = tostring(target.code) end
			if target.name then ch.target_name = tostring(target.name) end
		end
		local norm = RM.normalize_channel(ch)
		if not norm then return nil end
		list[idx] = norm
		RM.write_channels(list, "outbound_append")
		return idx, norm
	end
	local norm = RM.normalize_channel({
		from = from,
		to = to,
		target_code = target and target.code,
		target_name = target and target.name,
		appearance = appearance,
		armed = false,
		skip_arrive_once = true,
		opened_run_id = opened_run_id,
		outbound_pending = {passenger},
		return_pending = {},
	})
	if not norm then return nil end
	list[#list + 1] = norm
	RM.write_channels(list, "outbound_new")
	return #list, norm
end

function RM.update_channel_at(index, ch)
	local list = item.get_channels()
	local norm = RM.normalize_channel(ch)
	if not index or not list[index] or not norm then return false end
	list[index] = norm
	RM.write_channels(list, "update")
	return true
end

function item.remove_channel_at(index)
	local list = item.get_channels()
	index = tonumber(index)
	if not index or not list[index] then return false end
	table.remove(list, index)
	RM.write_channels(list, "remove")
	return true
end

function item.clear_all_channels()
	RM.write_channels({}, "clear_all")
end

function item.format_channel_label(ch, index)
	if not ch or not ch.from or not ch.to then return tostring(index or "?")..": <invalid>" end
	local state = ch.returning and "RETURNING" or (ch.skip_arrive_once and "OUTBOUND") or (ch.armed and "ARMED") or "IDLE"
	if RM.channel_blocks_return_this_run(ch) then
		state = state.."+SAME_RUN"
	end
	local name = ch.target_code or ch.target_name or ""
	if name ~= "" then name = " "..name end
	local ob = type(ch.outbound_pending) == "table" and #ch.outbound_pending or 0
	local ret = type(ch.return_pending) == "table" and #ch.return_pending or 0
	local queue = ""
	if ob > 0 or ret > 0 then
		queue = string.format(" q(out=%d,ret=%d)", ob, ret)
	end
	return string.format("%d: %s -> %s [%s]%s%s", index or 0, tostring(ch.from.command), tostring(ch.to.command), state, queue, name)
end

--- 调试/ImGui：用 stage 命令串添加永久渠道（默认已武装，便于立刻测回传）
function item.debug_add_channel(from_command, to_command, opts)
	opts = opts or {}
	local from = RM.sanitize_floor_info(RM.parse_command(from_command))
	local to = RM.sanitize_floor_info(RM.parse_command(to_command))
	if not from or not to then return nil, "invalid stage command" end
	if from.command == to.command and from.stage_type == to.stage_type then
		return nil, "from and to are the same floor"
	end
	local target_code, target_name
	for _, target in ipairs(item.floor_targets) do
		if target.command == to.command then
			target_code, target_name = target.code, target.name
			break
		end
	end
	local idx, norm = RM.upsert_channel({
		from = from,
		to = to,
		target_code = target_code,
		target_name = target_name,
		armed = opts.armed ~= false,
		skip_arrive_once = opts.skip_arrive_once and true or nil,
	})
	return idx, norm
end

function item.debug_fill_from_current_floor()
	if not Game() or not Game():GetLevel() then return nil end
	local cur = RM.capture_current_floor()
	return cur and cur.command or nil
end

--- 执行 stage 跳转；seed_stage 可选（用于重掷该层种子）
function RM.execute_stage_travel(floor_info, opts)
	opts = opts or {}
	if not floor_info or not floor_info.command then return end
	if opts.reseed ~= false then
		local new_seed = Random()
		if new_seed == 0 then new_seed = 1 end
		local seeds = Game():GetSeeds()
		local seed_stage = floor_info.seed_stage or floor_info.stage
		if seeds.SetStageSeed and seed_stage then
			seeds:SetStageSeed(seed_stage, new_seed)
		end
	end
	item._remaster_level_change = true
	Isaac.ExecuteCommand("stage "..floor_info.command)
end

function RM.set_pending_fx(payload)
	-- 内存备份：stage 跳转时 ELSES 偶发未及时带上
	item._pending_fx = payload
	save.elses[C.PENDING_FX_KEY] = payload
end

function RM.take_pending_fx()
	local p = item._pending_fx
	if type(p) ~= "table" then
		p = save.elses[C.PENDING_FX_KEY]
	end
	item._pending_fx = nil
	save.elses[C.PENDING_FX_KEY] = nil
	return p
end

--- 前向声明；完整实现在 clear_ghost_walk_costumes 之后
local clear_cinematic

function RM.revert_channel_returning_state(cine)
	if not cine or cine.kind ~= "return" then return end
	local idx = cine.channel_index
	local ch = cine.channel
	if not idx or type(ch) ~= "table" or not ch.returning then return end
	ch.returning = nil
	RM.update_channel_at(idx, ch)
end

--- 演出隐身：直接写 Entity.Visible，不用 Attribute_holder
function RM.hide_party_for_cinematic(player, opts)
	opts = opts or {}
	if item._party_hide then
		if opts.player_keep_hidden and player and player:Exists() then
			player.Visible = false
			item._party_hide.player_keep_hidden = true
		end
		return
	end
	local st = {
		familiars = {},
		player_keep_hidden = opts.player_keep_hidden ~= false,
	}
	if player and player:Exists() then
		st.player_was_visible = player.Visible ~= false
		if st.player_keep_hidden then
			player.Visible = false
		end
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR)) do
			if ent:Exists() then
				local fam = ent:ToFamiliar()
				local owner = fam and fam.Player
				if owner and GetPtrHash(owner) == GetPtrHash(player) then
					if ent:GetData()[CHANNEL_WISP_KEY] then
						ent.Visible = true
					else
						local ptr = GetPtrHash(ent)
						st.familiars[ptr] = ent.Visible ~= false
						ent.Visible = false
					end
				end
			end
		end
	end
	item._party_hide = st
end

function RM.restore_party_familiars()
	local st = item._party_hide
	if not st or type(st.familiars) ~= "table" then return end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR)) do
		if ent:Exists() then
			local ptr = GetPtrHash(ent)
			if st.familiars[ptr] ~= nil then
				ent.Visible = st.familiars[ptr]
				st.familiars[ptr] = nil
			end
		end
	end
end

function RM.restore_party_player(player, force)
	local st = item._party_hide
	if not st then return end
	if force or not st.player_keep_hidden then
		if player and player:Exists() and st.player_was_visible ~= nil then
			player.Visible = st.player_was_visible
		end
		item._party_hide = nil
	end
end

function RM.unfreeze_cinematic_player(player)
	if not player or not player:Exists() then return end
	player.Velocity = Vector.Zero
	pcall(function() player:StopExtraAnimation() end)
end

function RM.restore_cinematic_party_visibility(fallback_visible)
	fallback_visible = fallback_visible ~= false
	RM.restore_party_familiars()
	local st = item._party_hide
	if st then
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and p:Exists() then
				if st.player_was_visible ~= nil and (fallback_visible or not st.player_keep_hidden) then
					p.Visible = st.player_was_visible
				elseif fallback_visible then
					p.Visible = true
				end
				RM.unfreeze_cinematic_player(p)
			end
		end
		item._party_hide = nil
	elseif fallback_visible then
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and p:Exists() then
				p.Visible = true
				RM.unfreeze_cinematic_player(p)
			end
		end
	end
end

function RM.set_player_hidden(player, hidden)
	if not player or not player:Exists() then return end
	player.Visible = not hidden
end

function RM.freeze_player(player, on)
	if not player or not player:Exists() then return end
	if on then
		player.ControlsCooldown = math.max(player.ControlsCooldown, 8)
		player.Velocity = Vector.Zero
	end
end

--- 演出门：出发用玩家身边；抵达/回传用房间中心
function RM.pick_portal_pos(near_player)
	if near_player and near_player:Exists() then
		return Vector(near_player.Position.X, near_player.Position.Y)
	end
	return Game():GetRoom():GetCenterPos()
end

function RM.remaster_gfx_path()
	local conf = Isaac.GetItemConfig():GetCollectible(item.entity)
	local raw = conf and conf.GfxFileName
	if type(raw) == "string" and raw ~= "" then
		if string.sub(raw, 1, 4) == "gfx/" then return raw end
		return "gfx/items/collectibles/"..raw
	end
	return C.REMASTER_GFX
end

function RM.extra_anim_done(player, min_elapsed, elapsed, fallback)
	if elapsed < (min_elapsed or 8) then return false end
	-- 优先听引擎；但绝不能因一直 false 而卡死（隐身/Jump 失败时）
	local finished = nil
	pcall(function()
		if player and player.IsExtraAnimationFinished then
			finished = player:IsExtraAnimationFinished()
		end
	end)
	if finished == true then return true end
	return elapsed >= (fallback or 30)
end

function RM.vec_lerp(a, b, t)
	t = math.max(0, math.min(1, t or 0))
	return Vector(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
end

function RM.spawn_remaster_portal(pos)
	pos = pos or RM.pick_portal_pos()
	local q = Isaac.Spawn(EntityType.ENTITY_EFFECT, PORTAL_EFFECT_VAR, item.entity, pos, Vector.Zero, nil):ToEffect()
	if not q then return nil end
	q.Visible = true
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	local s = q:GetSprite()
	-- 先换 sheet 再 Play Appear，避免动画被 LoadGraphics 掐掉
	s:Load(C.PORTAL_ANM2, true)
	for i = 0, 5 do
		pcall(function() s:ReplaceSpritesheet(i, C.PORTAL_SHEET) end)
	end
	pcall(function() s:LoadGraphics() end)
	s:Play("Appear", true)
	local d = q:GetData()
	d[item.own_key.."portal"] = true
	d[item.own_key.."portal_phase"] = "appear"
	d[item.own_key.."appear_t0"] = Game():GetFrameCount()
	d.removecd = 999999
	d.skip_nil_distance_cull = true
	q.DepthOffset = -8
	q.SpriteScale = Vector(1.05, 1.05)
	pcall(function()
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_PORTAL_OPEN, 1.0, 1, false, 0, 2)
	end)
	return q
end

function RM.portal_tick(ent)
	if not ent or not ent:Exists() then return end
	local d = ent:GetData()
	if not d[item.own_key.."portal"] then return end
	local s = ent:GetSprite()
	local phase = d[item.own_key.."portal_phase"]
	local appear_age = Game():GetFrameCount() - (d[item.own_key.."appear_t0"] or 0)
	if phase == "appear" and (s:IsFinished("Appear") or appear_age >= 22) then
		if s:GetAnimation() ~= "Opened" then
			s:Play("Opened", true)
		end
		d[item.own_key.."portal_phase"] = "opened"
	elseif phase == "closing" and s:IsFinished("Disappear") then
		ent:Remove()
	end
end

function RM.portal_spit_pulse(ent, elapsed, dur)
	if not ent or not ent:Exists() then return end
	dur = math.max(1, dur or C.PORTAL_SPIT_DUR)
	local t = math.min(1, elapsed / dur)
	local pulse = math.sin(t * math.pi)
	local base = 1.05
	ent.SpriteScale = Vector(base * (1 - 0.18 * pulse), base * (1 + 0.42 * pulse))
end

function RM.portal_reset_scale(ent)
	if ent and ent:Exists() then
		ent.SpriteScale = Vector(1.05, 1.05)
	end
end

function RM.portal_is_ready(ent)
	if not ent or not ent:Exists() then return false end
	return ent:GetData()[item.own_key.."portal_phase"] == "opened"
end

function RM.close_portal(ent)
	if not ent or not ent:Exists() then return end
	local d = ent:GetData()
	local s = ent:GetSprite()
	d[item.own_key.."portal_phase"] = "closing"
	s:Play("Disappear", true)
	pcall(function()
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_PORTAL_OPEN, 0.85, 0.9, false, 0, 2)
	end)
end

function RM.play_portal_transition_sfx(mode)
	pcall(function()
		local vol = (mode == "exit") and 1.0 or 0.92
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_PORTAL_OPEN, vol, 1, false, 0, 2)
	end)
end

function RM.shader_screen_metrics()
	local size = auxi.GetScreenSize()
	local mult = auxi.check_screen_multi(Vector(1, 1)) * 256
	local max_u = size.X / math.max(1e-4, mult.X)
	local max_v = size.Y / math.max(1e-4, mult.Y)
	return {
		size = size,
		mult = mult,
		max_u = max_u,
		max_v = max_v,
		center_u = max_u * 0.5,
		center_v = max_v * 0.5,
	}
end

function RM.world_to_shader_uv(world_pos)
	local screen = Isaac.WorldToScreen(world_pos)
	local m = RM.shader_screen_metrics()
	local u = screen.X / m.mult.X
	local v = screen.Y / m.mult.Y
	if Game():GetRoom():IsMirrorWorld() then
		local sz = m.size.X
		while sz > 256 do sz = sz / 2 end
		u = (sz / 256) - u
	end
	return u, v, m
end

function RM.portal_shader_emerge_cover_params(cine)
	local m = RM.shader_screen_metrics()
	local world = cine.portal_pos
	if cine.portal and cine.portal:Exists() then
		world = cine.portal.Position
		cine.portal_pos = world
	end
	local cu, cv = m.center_u, m.center_v
	if world then
		cu, cv = RM.world_to_shader_uv(world)
	end
	return {
		P1 = {1, 0, 1, 1},
		P2 = {cu, cv, 0, 0},
	}
end

function RM.portal_shader_params_from_cine(cine)
	if not cine then
		return {P1 = {0, 0, 0, 0}, P2 = {0, 0, 0, 0}}
	end
	if (cine.kind == "outbound_emerge" or cine.kind == "return_emerge") and cine.phase == "portal_open" then
		return RM.portal_shader_emerge_cover_params(cine)
	end
	if cine.phase ~= "portal_transition" then
		return {P1 = {0, 0, 0, 0}, P2 = {0, 0, 0, 0}}
	end
	local m = RM.shader_screen_metrics()
	local elapsed = Game():GetFrameCount() - (cine.t0 or 0)
	local t = math.min(1, elapsed / C.PORTAL_TRANSITION_DUR)
	local ease = t * t * (3 - 2 * t)
	local world = cine.portal_pos
	if cine.portal and cine.portal:Exists() then
		world = cine.portal.Position
		cine.portal_pos = world
	end
	local cu, cv = m.center_u, m.center_v
	if world then
		cu, cv = RM.world_to_shader_uv(world)
	end
	local mode = cine.portal_transition_mode or "enter"
	local zoom, black
	if mode == "exit" then
		zoom = 1 - ease
		black = (1 - ease) ^ 1.35
	else
		zoom = ease
		black = math.max(0, (t - 0.42) / 0.58) ^ 1.12
	end
	return {
		P1 = {zoom, 0, black, 1},
		P2 = {cu, cv, 0, 0},
	}
end

function RM.begin_portal_screen_transition(cine, mode, on_complete)
	cine.portal_transition_mode = mode or "enter"
	cine.portal_transition_fn = on_complete
	cine.phase = "portal_transition"
	cine.t0 = Game():GetFrameCount()
	RM.play_portal_transition_sfx(cine.portal_transition_mode)
	if cine.portal and cine.portal:Exists() then
		local s = cine.portal:GetSprite()
		local d = cine.portal:GetData()
		pcall(function()
			if s:GetAnimation() ~= "Opened" then
				s:Play("Opened", true)
			end
		end)
		d[item.own_key.."portal_phase"] = "opened"
		cine.portal_pos = cine.portal.Position
		RM.portal_reset_scale(cine.portal)
	end
end

function RM.tick_portal_screen_transition(cine, elapsed)
	if elapsed >= C.PORTAL_TRANSITION_DUR then
		local fn = cine.portal_transition_fn
		cine.portal_transition_fn = nil
		if (cine.portal_transition_mode or "enter") == "enter" then
			if cine.portal and cine.portal:Exists() then
				pcall(function() cine.portal:Remove() end)
				cine.portal = nil
			end
		end
		if fn then fn() end
		return true
	end
	return false
end

function RM.apply_sheets(spr, sheets)
	if not spr or type(sheets) ~= "table" then return end
	local any = false
	for k, path in pairs(sheets) do
		local layer = tonumber(k)
		if layer and type(path) == "string" and path ~= "" then
			local ok = pcall(function() spr:ReplaceSpritesheet(layer, path) end)
			if ok then any = true end
		end
	end
	if any then pcall(function() spr:LoadGraphics() end) end
end

function RM.load_ghost_base_sprite(s, appearance)
	if not s or not appearance then return false end
	local paths = {}
	if type(appearance.base_anm2) == "string" and appearance.base_anm2 ~= "" then
		paths[#paths + 1] = appearance.base_anm2
	end
	paths[#paths + 1] = C.DEFAULT_GHOST_ANM2
	for i = 1, #paths do
		if RM.try_sprite_load(s, paths[i]) then
			RM.apply_sheets(s, appearance.base_sheets)
			return true
		end
	end
	return false
end

--- 演出幽灵：底模 anm2 + 贴图层。Extra 段只画身体；行走段叠 head overlay + 衣装精灵
--- opts.subtype / opts.owner_key：外部调用方（如永恒?）可指定，避免与 Remaster SubType 冲突
function RM.spawn_appearance_ghost(pos, appearance, anim, opts)
	appearance = RM.sanitize_appearance(appearance)
	if not appearance then return nil end
	opts = opts or {}
	local subtype = tonumber(opts.subtype) or (item.entity + 1)
	local owner_key = opts.owner_key or item.own_key
	local q = Isaac.Spawn(EntityType.ENTITY_EFFECT, PORTAL_EFFECT_VAR, subtype, pos, Vector.Zero, nil):ToEffect()
	if not q then return nil end
	q.Visible = true
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	local s = q:GetSprite()
	if not RM.load_ghost_base_sprite(s, appearance) then
		q:Remove()
		return nil
	end
	local played = false
	local anim_candidates = {anim or "Jump", "Jump", "WalkDown", "Idle"}
	for _, name in ipairs(anim_candidates) do
		if type(name) == "string" and name ~= "" then
			local ok = pcall(function() s:Play(name, true) end)
			if ok then
				local ok_play = pcall(function() return s:IsPlaying(name) end)
				if ok_play and s:IsPlaying(name) then
					played = true
					break
				end
				local ok_anim = pcall(function() return s:GetAnimation() end)
				if ok_anim and s:GetAnimation() == name then
					played = true
					break
				end
			end
		end
	end
	if not played then
		q:Remove()
		return nil
	end
	local sx = appearance.sprite_scale and appearance.sprite_scale.X or 1
	local sy = appearance.sprite_scale and appearance.sprite_scale.Y or 1
	q.SpriteScale = Vector(sx, sy)
	q.DepthOffset = 10
	local d = q:GetData()
	-- Remaster costume/render 路径仍认 own_key.."ghost"；共享 TAG 供外部识别
	d[item.own_key.."ghost"] = true
	d[owner_key.."ghost"] = true
	d[item.own_key.."ghost_app"] = appearance
	d[GHOST_CAN_FLY_KEY] = appearance.can_fly and true or false
	d.skip_nil_holder = true
	d.removecd = 999999
	d.skip_nil_distance_cull = true
	local Ghost = require("Qing_Remaster_scripts.others.player_appearance_ghost")
	d[Ghost.TAG] = true
	d[Ghost.APP_KEY] = appearance
	return q
end

--- 仅用于游离 Lua Sprite；实体 GetSprite() 由引擎按 30fps 推进，勿再 Update
function RM.tick_lua_sprite(spr, advance)
	if not spr or advance == false then return end
	if (Game():GetFrameCount() % C.GHOST_LUA_SPRITE_STEP) ~= 0 then return end
	pcall(function() spr:Update() end)
end

function RM.ghost_clock_bind(clocks, clock_key, spr, fields)
	if type(clocks) ~= "table" or type(clock_key) ~= "string" or clock_key == "" then
		return nil
	end
	local state = clocks[clock_key]
	if type(state) ~= "table" then
		state = {
			update_accum = 0,
			ticks_this_update = 0,
		}
		clocks[clock_key] = state
	end
	state.spr = spr
	state.clock_key = clock_key
	if type(fields) == "table" then
		for k, v in pairs(fields) do
			state[k] = v
		end
	end
	return state
end

function RM.ghost_is_actually_moving(ghost)
	if not ghost then return false end
	local vel = ghost.Velocity
	if not vel then return false end
	local len2 = nil
	pcall(function()
		if vel.LengthSquared then
			len2 = vel:LengthSquared()
		elseif vel.X and vel.Y then
			len2 = vel.X * vel.X + vel.Y * vel.Y
		end
	end)
	return type(len2) == "number" and len2 > 0.01
end

--- Player-appearance policy: Walk body is 2x while actually moving. Clock engine only receives this number.
function RM.ghost_costume_playback_rate(state, ghost, body_anim, appearance)
	local rate = 1
	if type(state) == "table" then
		rate = tonumber(state.update_rate) or rate
	end
	if appearance then
		rate = tonumber(state and state.update_rate)
			or tonumber(appearance.playback_rate)
			or tonumber(appearance.animation_rate)
			or rate
	end
	local source = type(state) == "table" and state.anim_source or nil
	if (source == "body" or source == "main")
		and RM.ghost_is_walk_family(body_anim)
		and RM.ghost_is_actually_moving(ghost) then
		rate = rate * 2
	end
	return rate
end

--- Generic Lua Sprite clock. Knows only rate, accumulator, and Update().
function RM.advance_sprite_clock(state, rate)
	if type(state) ~= "table" or not state.spr then
		return 0, tonumber(rate) or 1
	end
	local effective = tonumber(rate) or 1
	local unit = 1 / (C.GHOST_LUA_SPRITE_STEP or 2)
	state.update_accum = (tonumber(state.update_accum) or 0) + effective * unit
	local ticks = 0
	local frame_before = nil
	pcall(function() frame_before = state.spr:GetFrame() end)
	state.frame_before = frame_before
	while state.update_accum >= 1 do
		pcall(function() state.spr:Update() end)
		state.update_accum = state.update_accum - 1
		ticks = ticks + 1
		if ticks > 8 then break end
	end
	local frame_after = frame_before
	pcall(function() frame_after = state.spr:GetFrame() end)
	state.frame_after = frame_after
	state.ticks_this_update = ticks
	state.effective_rate = effective
	return ticks, effective
end

function RM.ghost_anim_sync_candidates(anim, overlay)
	if overlay then
		return RM.ghost_head_anim_candidates(anim)
	end
	if RM.ghost_is_walk_family(anim) then
		return RM.ghost_walk_anim_candidates(anim)
	end
	if type(anim) == "string" and anim ~= "" then
		return {anim}
	end
	return {}
end

function RM.ghost_walk_anim_candidates(walk_anim)
	local list = {}
	if type(walk_anim) == "string" and walk_anim ~= "" then
		list[#list + 1] = walk_anim
	end
	for _, name in ipairs({"WalkDown", "WalkUp", "WalkLeft", "WalkRight", "Idle"}) do
		list[#list + 1] = name
	end
	return list
end

function RM.sprite_play_anim(s, names)
	if not s or type(names) ~= "table" then return nil end
	for _, name in ipairs(names) do
		if type(name) ~= "string" or name == "" then goto continue end
		local ok = pcall(function() s:Play(name, true) end)
		if ok then
			local ok_anim = pcall(function() return s:GetAnimation() end)
			if ok_anim and s:GetAnimation() == name then
				return name
			end
			local ok_play = pcall(function() return s:IsPlaying(name) end)
			if ok_play and s:IsPlaying(name) then
				return name
			end
		end
		::continue::
	end
	return nil
end

--- 返回 names 中第一个在 spr 上真实存在的动画名（GetAnimationData 可读），不 Play。
function RM.sprite_resolve_one_of(s, names)
	if not s or type(names) ~= "table" then return nil end
	for _, name in ipairs(names) do
		if type(name) == "string" and name ~= "" then
			if RM.sprite_animation_length(s, name) ~= nil then
				return name
			end
		end
	end
	return nil
end

--- AnimationData:GetLength()（RGON）。动画不存在时返回 nil。
function RM.sprite_animation_length(spr, anim)
	if not spr or type(anim) ~= "string" or anim == "" then return nil end
	local len = nil
	pcall(function()
		local data = spr:GetAnimationData(anim)
		if data and data.GetLength then
			len = data:GetLength()
		end
	end)
	return tonumber(len)
end

--- Overlay 参考长度：优先 GetOverlayAnimationData，否则按名 GetAnimationData。
function RM.sprite_overlay_animation_length(spr, overlay_anim)
	if not spr then return nil end
	local len = nil
	pcall(function()
		local data = spr:GetOverlayAnimationData()
		if data and data.GetLength then
			local name = nil
			if data.GetName then name = data:GetName() end
			if type(overlay_anim) ~= "string" or overlay_anim == "" or name == overlay_anim then
				len = data:GetLength()
				return
			end
		end
		if type(overlay_anim) == "string" and overlay_anim ~= "" then
			local fallback = spr:GetAnimationData(overlay_anim)
			if fallback and fallback.GetLength then
				len = fallback:GetLength()
			end
		end
	end)
	return tonumber(len)
end

function RM.ghost_head_anim_candidates(overlay_anim)
	local list = {}
	if type(overlay_anim) == "string" and overlay_anim ~= "" then
		list[#list + 1] = overlay_anim
	end
	for _, name in ipairs({"HeadDown", "HeadUp", "HeadLeft", "HeadRight"}) do
		list[#list + 1] = name
	end
	return list
end

--- Map HeadDown / HeadDownShoot / HeadDown_Idle → HeadDown. Walk families return nil.
--- Lua patterns do not support `|` alternation; match the four fixed prefixes explicitly.
function RM.ghost_head_family_base(anim)
	if type(anim) ~= "string" or anim == "" then return nil end
	for _, dir in ipairs({"Down", "Up", "Left", "Right"}) do
		local base = "Head" .. dir
		if anim:sub(1, #base) == base then
			return base
		end
	end
	return nil
end

function RM.ghost_head_family_base_self_test()
	local cases = {
		{"HeadDown", "HeadDown"},
		{"HeadUp", "HeadUp"},
		{"HeadLeft_Idle", "HeadLeft"},
		{"HeadRight_Overlay", "HeadRight"},
		{"HeadDownShoot", "HeadDown"},
		{"HeadDown_Idle", "HeadDown"},
		{"HeadDown_Overlay", "HeadDown"},
		{"WalkDown", nil},
	}
	local fails = {}
	for i = 1, #cases do
		local input, expected = cases[i][1], cases[i][2]
		local got = RM.ghost_head_family_base(input)
		if got ~= expected then
			fails[#fails + 1] = {input = input, expected = expected, got = got}
		end
	end
	return #fails == 0, fails
end

function RM.ghost_head_held_on_first_frame(head_frame, head_active)
	if head_active == true then return false end
	return (tonumber(head_frame) or 0) == 0
end

function RM.ghost_head_display_anim(spr, head_anim, use_idle)
	if type(head_anim) ~= "string" or head_anim == "" then return head_anim end
	if use_idle then
		local base = RM.ghost_head_family_base(head_anim)
		local idle = base and (base .. "_Idle")
		if idle and RM.sprite_animation_data(spr, idle) then
			return idle
		end
	end
	return head_anim
end

function RM.ghost_animation_layer_ids(spr, anim)
	local ids = {}
	if not RM.sprite_is_usable(spr) or type(anim) ~= "string" or anim == "" then
		return ids
	end
	local n = 0
	pcall(function() n = spr:GetLayerCount() end)
	if type(n) ~= "number" then return ids end
	for i = 0, n - 1 do
		if RM.sprite_anim_has_layer(spr, anim, i) then
			ids[#ids + 1] = i
		end
	end
	return ids
end

function RM.ghost_head_overlay_extra_anim(spr, head_anim)
	local base = RM.ghost_head_family_base(head_anim)
	if not base then return nil end
	local extra = base .. "_Overlay"
	if RM.sprite_animation_data(spr, extra) then
		return extra
	end
	return nil
end

--- 已在播「首选」动画时不重 Play，避免 PRE 每帧 Render 把帧重置为 0。
--- Fallbacks 只在首选动画不存在/无法播放时经 sprite_play_anim 尝试；
--- 不得把 candidates 里其它已在播的 Walk* 当成首选成功（否则 WalkRight 请求会卡在 WalkDown）。
function RM.sprite_ensure_one_of(s, names)
	if not s or type(names) ~= "table" then return nil end
	local preferred = nil
	for _, name in ipairs(names) do
		if type(name) == "string" and name ~= "" then
			preferred = name
			break
		end
	end
	if preferred then
		local playing = false
		pcall(function() playing = s:IsPlaying(preferred) end)
		if playing then return preferred end
		local cur = nil
		pcall(function() cur = s:GetAnimation() end)
		if cur == preferred then
			local finished = false
			pcall(function() finished = s:IsFinished(preferred) end)
			if not finished then return preferred end
		end
	end
	return RM.sprite_play_anim(s, names)
end

function RM.ghost_play_walk_anim(s, walk_anim)
	if not s then return walk_anim end
	local candidates = RM.ghost_walk_anim_candidates(walk_anim)
	return RM.sprite_ensure_one_of(s, candidates) or walk_anim
end

function RM.ghost_play_resolved_anim(s, anim)
	return RM.ghost_play_walk_anim(s, anim)
end

function RM.ghost_set_anim(ghost, anim, cache)
	if not ghost or not ghost:Exists() or not anim then return cache end
	cache = cache or {}
	local s = ghost:GetSprite()
	local cur, speed = nil, 1
	pcall(function()
		cur = s:GetAnimation()
		speed = s.PlaybackSpeed
	end)
	local walk_family = anim == "WalkDown" or anim == "WalkUp" or anim == "WalkLeft" or anim == "WalkRight" or anim == "Idle"
	-- 同名 Walk 被 SetFrame(0)+PlaybackSpeed=0 冻住后，sprite_ensure_one_of 会当成已在播而跳过 Play。
	local frozen_same_walk = walk_family and cur == anim and speed == 0
	if frozen_same_walk then
		pcall(function() s:Play(anim, true) end)
		cache.anim = anim
	elseif cache.anim ~= anim or cur ~= anim then
		if walk_family then
			RM.ghost_play_walk_anim(s, anim)
		else
			RM.sprite_play_anim(s, {anim})
		end
		cache.anim = anim
	end
	return cache
end

function RM.ghost_ensure_anim(ghost, anim, cache)
	return RM.ghost_set_anim(ghost, anim, cache)
end

function RM.ghost_clear_walk_head_overlay(ghost, cache)
	if not ghost or not ghost:Exists() then return cache end
	cache = cache or {}
	pcall(function() ghost:GetSprite():RemoveOverlay() end)
	cache.overlay_head = nil
	ghost:GetData()[GHOST_DIRECTIONAL_HEAD_KEY] = nil
	return cache
end

function RM.ghost_set_walk_head_overlay(ghost, body_anim, cache)
	if not ghost or not ghost:Exists() then return cache end
	cache = cache or {}
	local gd = ghost:GetData()
	local head = C.GHOST_WALK_HEAD[body_anim]
	if not head then
		pcall(function() ghost:GetSprite():RemoveOverlay() end)
		cache.overlay_head = nil
		gd[GHOST_DIRECTIONAL_HEAD_KEY] = nil
		return cache
	end
	local s = ghost:GetSprite()
	if cache.overlay_head ~= head then
		pcall(function() s:PlayOverlay(head, true) end)
		cache.overlay_head = head
	end
	-- Synthetic directional Head* frame0 — not a real attack overlay.
	gd[GHOST_DIRECTIONAL_HEAD_KEY] = {anim = head, frame = 0}
	return cache
end

--- 行走 head overlay：按方向选 Head*，固定第 0 帧（睁眼 idle 头）
function RM.ghost_sync_walk_head_overlay(ghost, body_anim, cache)
	if not ghost or not ghost:Exists() then return cache end
	cache = RM.ghost_set_walk_head_overlay(ghost, body_anim, cache)
	local head = cache and cache.overlay_head
	if not head then return cache end
	local s = ghost:GetSprite()
	pcall(function() s:SetOverlayFrame(head, 0) end)
	ghost:GetData()[GHOST_DIRECTIONAL_HEAD_KEY] = {anim = head, frame = 0}
	return cache
end

function RM.setup_ghost_walk_costumes(ghost, appearance)
	if not ghost or not ghost:Exists() then return end
	appearance = RM.sanitize_appearance(appearance)
	local gd = ghost:GetData()
	gd[GHOST_COSTUME_WINNERS_KEY] = nil
	gd[GHOST_COSTUME_CANDIDATES_KEY] = nil
	gd[GHOST_COSTUME_SPRS_KEY] = nil
	gd[GHOST_COSTUME_CLOCK_KEY] = nil
	gd[GHOST_CLOCK_PROBE_KEY] = nil
	gd[GHOST_PLAN_CACHE_KEY] = nil
	gd[item.own_key.."walk_composite"] = nil
	local has_layers = type(appearance.costume_layers) == "table" and #appearance.costume_layers > 0
	local has_costumes = type(appearance.costumes) == "table" and #appearance.costumes > 0
	if not appearance or (not has_layers and not has_costumes) then
		return
	end
	local resolved = RM.resolve_costume_winners({
		appearance = appearance,
		base_sprite = ghost:GetSprite(),
	})
	local winners = resolved and resolved.winners
	local pool = resolved and resolved.pool or {}
	if type(winners) == "table" and next(winners) then
		gd[GHOST_COSTUME_SPRS_KEY] = pool
		gd[GHOST_COSTUME_WINNERS_KEY] = winners
		gd[GHOST_COSTUME_CANDIDATES_KEY] = resolved.candidates or {}
		gd[item.own_key.."walk_composite"] = has_layers or has_costumes
		gd[GHOST_COSTUME_DRIVER_KEY] = resolved.driver_key
	end
	RM.emit_ghost_probe("setup_costumes", ghost, {
		has_layers = has_layers,
		has_costumes = has_costumes,
		pool_count = #pool,
		winner_count = RM.ghost_count_drawable_slots(ghost),
		driver_key = ghost:GetData()[GHOST_COSTUME_DRIVER_KEY],
	})
end

function RM.ghost_restore_base_layer_visibility(ghost)
	if not ghost or not ghost:Exists() then return end
	local body = ghost:GetSprite()
	if not body or not body.GetLayerCount then return end
	local ok_n, n = pcall(function() return body:GetLayerCount() end)
	if not ok_n or type(n) ~= "number" then return end
	for i = 0, n - 1 do
		pcall(function()
			local lay = body:GetLayer(i)
			if lay and lay.SetVisible then lay:SetVisible(true) end
		end)
	end
end

--- Costume owns base Head overlay only when a non-base winner actually uses the head animation source.
function RM.ghost_head_slots_have_costume_winner(slots)
	if type(slots) ~= "table" then return false end
	for i = 1, #slots do
		local slot = slots[i]
		if slot and slot.from_base ~= true and slot.anim_source == "head" then
			return true
		end
	end
	return false
end

--- 暂存并隐藏底模上「被 costume 抢走」的同名层；返回 saved[{layer_id]=was_visible}。
function RM.ghost_suppress_replaced_base_layers(body, winners)
	local saved = {}
	if not body or type(winners) ~= "table" or not body.GetLayer then
		return saved
	end
	local replaced = {}
	for _, slot in pairs(winners) do
		local name = slot and slot.key
		if slot and slot.from_base ~= true and type(name) == "string" then
			replaced[name] = true
		end
	end
	if not next(replaced) then return saved end
	local ok_n, n = pcall(function() return body:GetLayerCount() end)
	if not ok_n or type(n) ~= "number" then return saved end
	for i = 0, n - 1 do
		pcall(function()
			local lay = body:GetLayer(i)
			if not lay or not lay.GetName or not lay.IsVisible or not lay.SetVisible then return end
			local name = lay:GetName()
			if replaced[name] then
				saved[i] = lay:IsVisible()
				lay:SetVisible(false)
			end
		end)
	end
	return saved
end

function RM.ghost_restore_layer_visibility_map(body, saved)
	if not body or type(saved) ~= "table" then return end
	for i, vis in pairs(saved) do
		pcall(function()
			local lay = body:GetLayer(i)
			if lay and lay.SetVisible then lay:SetVisible(vis) end
		end)
	end
end

function RM.ghost_slot_active_reason(slot, body_anim, overlay_anim)
	if not slot then return "missing_slot" end
	if slot.anim_source == "head"
		and not RM.ghost_directional_head_participates(body_anim, overlay_anim) then
		return "head_not_participating"
	end
	local anim = slot.anim_source == "head" and overlay_anim or body_anim
	if type(anim) ~= "string" or anim == "" then
		return "no_source_animation"
	end
	if not RM.sprite_animation_data(slot.spr, anim) then
		return "animation_missing"
	end
	if RM.sprite_anim_has_layer(slot.spr, anim, slot.layer_id) then
		return "current_animation"
	end
	return "layer_missing"
end

function RM.ghost_inactive_costume_slots(winners, plan, body_anim, overlay_anim)
	local out = {}
	if type(winners) ~= "table" then return out end
	local in_plan = {}
	if type(plan) == "table" then
		for i = 1, #plan do
			local pk = plan[i] and plan[i].plan_key
			if type(pk) == "string" then
				in_plan[pk] = true
			end
		end
	end
	for _, slot in pairs(winners) do
		if slot and slot.from_base ~= true then
			local pk = slot.plan_key or ((slot.anim_source or "body") .. "|" .. tostring(slot.key))
			if not in_plan[pk] then
				local anm2 = slot.anm2
				if type(anm2) ~= "string" or anm2 == "" then
					pcall(function()
						if slot.spr then anm2 = slot.spr:GetFilename() end
					end)
				end
				out[#out + 1] = {
					slot_key = slot.key,
					plan_key = pk,
					anim_source = slot.anim_source,
					anm2 = anm2,
					layer_id = slot.layer_id,
					slot_active_reason = RM.ghost_slot_active_reason(slot, body_anim, overlay_anim),
				}
				if #out >= 24 then break end
			end
		end
	end
	return out
end

--- Animation-level ownership: declared LayerAnimation in the current main/overlay anim.
--- Frame Visible/Delay belongs to Sprite playback, not compositor arbitration.
function RM.ghost_build_render_plan(candidates, body_anim, overlay_anim)
	local list = {}
	if type(candidates) ~= "table" then return list end
	local participating = {}
	local function consider(slot)
		if not slot or not slot.spr or not RM.sprite_layer_usable(slot.spr, slot.layer_id) then
			return
		end
		local active_reason = RM.ghost_slot_active_reason(slot, body_anim, overlay_anim)
		if active_reason ~= "current_animation" then
			return
		end
		local anm2 = slot.anm2
		if type(anm2) ~= "string" or anm2 == "" then
			pcall(function() anm2 = slot.spr:GetFilename() end)
		end
		local key = slot.key
		local anim_source = slot.anim_source == "head" and "head" or "body"
		participating[#participating + 1] = {
			key = key,
			plan_key = slot.plan_key or (anim_source .. "|" .. tostring(key)),
			clock_key = slot.clock_key or slot.plan_key or key,
			spr = slot.spr,
			layer_id = slot.layer_id,
			native_layer_id = slot.native_layer_id or slot.layer_id,
			logical_layer_id = slot.logical_layer_id or RM.ghost_logical_layer_id(key, slot.layer_id),
			from_base = slot.from_base and true or false,
			is_flying = slot.is_flying and true or false,
			anim_source = anim_source,
			role = anim_source,
			anm2 = anm2,
			priority = slot.priority or 0,
			update_rate = slot.update_rate,
			active_reason = active_reason,
		}
	end
	if candidates[1] ~= nil then
		for i = 1, #candidates do
			consider(candidates[i])
		end
	else
		for _, slot in pairs(candidates) do
			consider(slot)
		end
	end
	local anim_winners = {}
	for i = 1, #participating do
		local cand = participating[i]
		local prev = anim_winners[cand.plan_key]
		if not prev or (cand.priority or 0) >= (prev.priority or 0) then
			anim_winners[cand.plan_key] = cand
		end
	end
	for _, slot in pairs(anim_winners) do
		list[#list + 1] = slot
	end
	local groups = {}
	for i = 1, #list do
		local slot = list[i]
		local gk = tostring(slot.anm2 or "") .. "|" .. tostring(slot.anim_source or "body")
		slot._group = gk
		local g = groups[gk]
		if not g then
			g = {has_known = false, max_known = -1}
			groups[gk] = g
		end
		local psl = RM.ghost_psl_index(slot.key)
		if psl ~= nil then
			g.has_known = true
			if psl > g.max_known then g.max_known = psl end
			slot.sort_logical = psl
			slot.unknown_tail = 0
		end
	end
	for i = 1, #list do
		local slot = list[i]
		if slot.sort_logical == nil then
			local g = groups[slot._group]
			local native = tonumber(slot.native_layer_id) or 0
			if g and g.has_known then
				slot.sort_logical = g.max_known
				slot.unknown_tail = 1
			else
				slot.sort_logical = native
				slot.unknown_tail = 0
			end
		end
		slot._group = nil
	end
	table.sort(list, function(a, b)
		local la = tonumber(a.sort_logical) or 0
		local lb = tonumber(b.sort_logical) or 0
		if la ~= lb then return la < lb end
		local ta = tonumber(a.unknown_tail) or 0
		local tb = tonumber(b.unknown_tail) or 0
		if ta ~= tb then return ta < tb end
		local na = tonumber(a.native_layer_id) or 0
		local nb = tonumber(b.native_layer_id) or 0
		if na ~= nb then return na < nb end
		local sa = RM.ghost_anim_source_order(a.anim_source)
		local sb = RM.ghost_anim_source_order(b.anim_source)
		if sa ~= sb then return sa < sb end
		return tostring(a.plan_key or a.key) < tostring(b.plan_key or b.key)
	end)
	return list
end

function RM.ghost_sort_winner_slots(winners, head_pass)
	local plan = RM.ghost_build_render_plan(winners, nil, nil)
	if head_pass == nil then return plan end
	local list = {}
	for i = 1, #plan do
		local is_head = plan[i].anim_source == "head"
		if (head_pass and is_head) or (not head_pass and not is_head) then
			list[#list + 1] = plan[i]
		end
	end
	return list
end

function RM.ghost_is_walk_family(anim)
	return anim == "WalkDown"
		or anim == "WalkUp"
		or anim == "WalkLeft"
		or anim == "WalkRight"
		or anim == "Idle"
end

--- Walk*/Idle are the only body poses that composite a directional Head* overlay.
function RM.ghost_body_accepts_directional_head(anim)
	return RM.ghost_is_walk_family(anim)
end

function RM.ghost_is_directional_head_anim(anim)
	return RM.ghost_head_family_base(anim) ~= nil
end

--- Clock may still hold HeadLeft during Hit; that does not mean the composite draws it.
function RM.ghost_directional_head_participates(body_anim, overlay_anim)
	if not RM.ghost_is_directional_head_anim(overlay_anim) then
		return true
	end
	return RM.ghost_body_accepts_directional_head(body_anim)
end

function RM.ghost_directional_head_participation_self_test()
	local cases = {
		{"WalkDown", "HeadDown", true},
		{"WalkLeft", "HeadLeft", true},
		{"Idle", "HeadDown", true},
		{"Hit", "HeadLeft", false},
		{"Hit", "HeadDown_Idle", false},
		{"WalkRight", "HeadRight_Overlay", true},
		{"Trapdoor", "HeadUp", false},
		{"WalkDown", "WalkDown", true},
	}
	local fails = {}
	for i = 1, #cases do
		local body, overlay, expected = cases[i][1], cases[i][2], cases[i][3]
		local got = RM.ghost_directional_head_participates(body, overlay)
		if got ~= expected then
			fails[#fails + 1] = {body = body, overlay = overlay, expected = expected, got = got}
		end
	end
	return #fails == 0, fails
end

--- Ordinary body clock is running when the base sprite is on Walk* and PlaybackSpeed > 0.
function RM.ghost_body_clock_running(body, body_anim)
	if not body or not RM.ghost_is_walk_family(body_anim) then return false end
	local speed = 0
	pcall(function() speed = body.PlaybackSpeed or 0 end)
	return speed > 0
end

function RM.ghost_world_screen_pos(ghost, world_offset, render_offset)
	local room = Game():GetRoom()
	world_offset = world_offset or Vector.Zero
	-- 与 entity_render_scroll_offset_pitfalls 一致：W2S + callback offset - scroll
	-- GetRenderScrollOffset 已含 shake，勿再减 ScreenShakeOffset
	local screen = room:WorldToScreenPosition(ghost.Position + world_offset)
	if render_offset then
		screen = screen + render_offset
	end
	return screen - room:GetRenderScrollOffset()
end

function RM.ghost_costume_sync_body_sprite(spr, source_body, source_anim, source_frame, clocks, slot_key, is_flying, clock_meta)
	if not RM.sprite_is_usable(spr)
		or not RM.sprite_is_usable(source_body)
		or type(source_anim) ~= "string"
		or source_anim == "" then
		return nil
	end
	local target_anim = RM.sprite_resolve_one_of(spr, RM.ghost_anim_sync_candidates(source_anim, false))
	if not target_anim then return nil end
	local source_len = RM.sprite_animation_length(source_body, source_anim)
	local target_len = RM.sprite_animation_length(spr, target_anim)
	-- Flying costumes keep a persistent clock even when lengths match base Walk*.
	local mode
	if is_flying then
		mode = "persistent"
	elseif source_len and target_len and source_len == target_len then
		mode = "shared"
	else
		mode = "movement_independent"
	end
	clock_meta = type(clock_meta) == "table" and clock_meta or {}
	local prev = clocks and clocks[slot_key]
	local changed = not prev or prev.anim ~= target_anim or prev.mode ~= mode
	local fields = {
		anim = target_anim,
		mode = mode,
		anim_source = clock_meta.anim_source or "body",
		update_rate = tonumber(clock_meta.update_rate) or 1,
		is_flying = is_flying and true or false,
	}
	RM.ghost_clock_bind(clocks, slot_key, spr, fields)
	if mode == "shared" then
		pcall(function()
			spr:SetFrame(target_anim, tonumber(source_frame) or 0)
		end)
	elseif changed then
		pcall(function() spr:Play(target_anim, true) end)
	end
	local target_frame = nil
	pcall(function() target_frame = spr:GetFrame() end)
	return {
		source_anim = source_anim,
		target_anim = target_anim,
		source_len = source_len,
		target_len = target_len,
		clock_mode = mode,
		clock_key = slot_key,
		is_flying = is_flying and true or false,
		source_frame = tonumber(source_frame) or 0,
		target_frame = target_frame,
	}
end

function RM.ghost_walk_overlay_state(body, body_anim, ghost)
	local overlay_anim, overlay_frame = nil, 0
	local overlay_active = false
	if body then
		pcall(function()
			overlay_anim = body:GetOverlayAnimation()
			overlay_frame = body:GetOverlayFrame() or 0
		end)
	end
	local synthetic = nil
	if ghost and ghost.GetData then
		synthetic = ghost:GetData()[GHOST_DIRECTIONAL_HEAD_KEY]
	end
	local syn_anim, syn_frame = nil, 0
	if type(synthetic) == "table" then
		syn_anim = synthetic.anim
		syn_frame = tonumber(synthetic.frame) or 0
	elseif type(synthetic) == "string" then
		syn_anim = synthetic
		syn_frame = 0
	end
	if type(overlay_anim) == "string" and overlay_anim ~= "" then
		local frame_n = tonumber(overlay_frame) or 0
		if syn_anim == overlay_anim and frame_n == syn_frame then
			-- Shared Ghost synthetic directional head, not a real attack overlay.
			overlay_active = false
			overlay_frame = 0
			if not RM.ghost_is_walk_family(body_anim) then
				overlay_anim = nil
			end
		else
			overlay_active = true
			if ghost and ghost.GetData and syn_anim then
				ghost:GetData()[GHOST_DIRECTIONAL_HEAD_KEY] = nil
			end
		end
	else
		overlay_anim = C.GHOST_WALK_HEAD[body_anim]
		overlay_frame = 0
		overlay_active = false
	end
	return overlay_anim, overlay_frame, overlay_active
end

--- Head: idle directional Head* stays on frame 0; only a real overlay advances frames.
function RM.ghost_costume_sync_head_sprite(spr, source_body, head_anim, head_frame, head_active, clocks, slot_key)
	if not RM.sprite_is_usable(spr)
		or not RM.sprite_is_usable(source_body)
		or type(head_anim) ~= "string"
		or head_anim == "" then
		return nil
	end
	local use_idle = RM.ghost_head_held_on_first_frame(head_frame, head_active)
	local display_anim = RM.ghost_head_display_anim(spr, head_anim, use_idle)
	local target_anim = RM.sprite_resolve_one_of(spr, RM.ghost_anim_sync_candidates(display_anim, true))
	if not target_anim then return nil end
	local mode
	local source_len, target_len = nil, nil
	if not head_active then
		mode = "head_idle"
		pcall(function()
			if spr:GetAnimation() ~= target_anim then
				spr:Play(target_anim, true)
			end
			spr:SetFrame(target_anim, 0)
		end)
		RM.ghost_clock_bind(clocks, slot_key, spr, {
			anim = target_anim,
			mode = mode,
			anim_source = "head",
			update_rate = 1,
		})
	else
		source_len = RM.sprite_overlay_animation_length(source_body, head_anim)
		target_len = RM.sprite_animation_length(spr, target_anim)
		local same_clock = source_len and target_len and source_len == target_len
		mode = same_clock and "shared" or "head_independent"
		local prev = clocks and clocks[slot_key]
		local changed = not prev or prev.anim ~= target_anim or prev.mode ~= mode
		RM.ghost_clock_bind(clocks, slot_key, spr, {
			anim = target_anim,
			mode = mode,
			anim_source = "head",
			update_rate = 1,
		})
		if mode == "shared" then
			pcall(function()
				spr:SetFrame(target_anim, tonumber(head_frame) or 0)
			end)
		elseif changed then
			pcall(function() spr:Play(target_anim, true) end)
		end
	end
	local target_frame = nil
	pcall(function() target_frame = spr:GetFrame() end)
	return {
		source_anim = head_anim,
		target_anim = target_anim,
		head_display_anim = display_anim,
		head_use_idle = use_idle and true or false,
		source_len = source_len,
		target_len = target_len,
		clock_mode = mode,
		overlay_active = head_active and true or false,
		source_frame = head_active and (tonumber(head_frame) or 0) or 0,
		target_frame = target_frame,
	}
end

--- Recorded: pin costume sprites to the recorded body/head clocks.
function RM.ghost_costume_pin_recorded_body(spr, body_anim, body_frame)
	if not RM.sprite_is_usable(spr) or type(body_anim) ~= "string" or body_anim == "" then return end
	local target = RM.sprite_resolve_one_of(spr, RM.ghost_walk_anim_candidates(body_anim)) or body_anim
	pcall(function()
		if spr:GetAnimation() ~= target then
			spr:Play(target, true)
		end
		spr:SetFrame(target, tonumber(body_frame) or 0)
	end)
end

function RM.ghost_costume_pin_recorded_head(spr, overlay_anim, overlay_frame)
	if not RM.sprite_is_usable(spr) or type(overlay_anim) ~= "string" or overlay_anim == "" then return end
	local use_idle = (tonumber(overlay_frame) or 0) == 0
	local display = RM.ghost_head_display_anim(spr, overlay_anim, use_idle)
	local target = RM.sprite_resolve_one_of(spr, RM.ghost_head_anim_candidates(display)) or display
	pcall(function()
		if spr:GetAnimation() ~= target then
			spr:Play(target, true)
		end
		spr:SetFrame(target, tonumber(overlay_frame) or 0)
	end)
end

function RM.ghost_draw_winner_layers(ghost, body, slots, anim, frame, overlay_anim, overlay_frame, overlay_active, _head_pass, render_offset)
	if not ghost or not body or #slots == 0 then return 0, nil end
	local sc = ghost.SpriteScale or Vector(1, 1)
	local tint = body.Color or Color(1, 1, 1, 1)
	local alpha = tint.A or 1
	local screen = RM.ghost_world_screen_pos(ghost, nil, render_offset)
	local layer_overrides = nil
	local recorded_pose = false
	pcall(function()
		local Ghost = require("Qing_Remaster_scripts.others.player_appearance_ghost")
		if Ghost.get_recorded_layer_overrides then
			layer_overrides = Ghost.get_recorded_layer_overrides(ghost)
		end
		if Ghost.is_recorded_pose then
			recorded_pose = Ghost.is_recorded_pose(ghost) and true or false
		end
	end)
	local gd = ghost:GetData()
	local clocks = gd[GHOST_COSTUME_CLOCK_KEY]
	if type(clocks) ~= "table" then
		clocks = {}
		gd[GHOST_COSTUME_CLOCK_KEY] = clocks
	end
	local drawn = 0
	local slot_probe = {}
	local body_running = RM.ghost_body_clock_running(body, anim)
	for _, slot in ipairs(slots) do
		local spr = slot.spr
		if not RM.sprite_layer_usable(spr, slot.layer_id) then goto continue end
		local use_head_clock = slot.anim_source == "head"
		local ov = layer_overrides and (
			layer_overrides[slot.plan_key] or layer_overrides[slot.key]
		)
		local sync_info = nil
		local clock_key = slot.clock_key or slot.plan_key or slot.key
		-- Recorded layer override wins. Base winners are the reference clock and never SetFrame themselves.
		if ov then
			if recorded_pose and use_head_clock then
				RM.ghost_apply_recorded_head_override(spr, ov, anim, frame, overlay_anim, overlay_frame)
			else
				RM.ghost_apply_full_layer_override(spr, ov, {replace = true})
			end
			sync_info = { clock_mode = "recorded_override", source_anim = use_head_clock and overlay_anim or anim }
		elseif slot.from_base then
			sync_info = {
				clock_mode = "base_source",
				source_anim = use_head_clock and overlay_anim or anim,
				target_anim = use_head_clock and overlay_anim or anim,
				source_frame = use_head_clock and (tonumber(overlay_frame) or 0) or (tonumber(frame) or 0),
				is_flying = slot.is_flying and true or false,
				overlay_active = overlay_active and true or false,
			}
		elseif recorded_pose then
			if use_head_clock then
				if type(overlay_anim) ~= "string" or overlay_anim == "" then
					goto continue
				end
				RM.ghost_costume_pin_recorded_head(spr, overlay_anim, overlay_frame)
				sync_info = {
					clock_mode = "recorded_pin",
					source_anim = overlay_anim,
					source_frame = tonumber(overlay_frame) or 0,
					overlay_active = true,
				}
			else
				RM.ghost_costume_pin_recorded_body(spr, anim, frame)
				sync_info = {
					clock_mode = "recorded_pin",
					source_anim = anim,
					source_frame = tonumber(frame) or 0,
				}
			end
		elseif use_head_clock then
			sync_info = RM.ghost_costume_sync_head_sprite(
				spr, body, overlay_anim, overlay_frame, overlay_active == true, clocks, clock_key
			)
		else
			local app = gd[item.own_key.."ghost_app"]
			local update_rate = tonumber(slot.update_rate)
				or tonumber(app and app.animation_rate)
				or 1
			sync_info = RM.ghost_costume_sync_body_sprite(
				spr, body, anim, frame, clocks, clock_key, slot.is_flying == true, {
					anim_source = "body",
					update_rate = update_rate,
				}
			)
		end
		if not slot.from_base and not ov and not sync_info then
			goto continue
		end
		local ok = pcall(function()
			spr.Scale = sc
			spr.FlipX = ghost.FlipX
			if ov and ov.flip_x ~= nil then
				spr.FlipX = ov.flip_x and true or false
			end
			spr.Color = Color(tint.R, tint.G, tint.B, alpha)
			spr:RenderLayer(slot.layer_id, screen, Vector.Zero, Vector.Zero)
		end)
		if ok then drawn = drawn + 1 end
		if #slot_probe < 40 then
			local actual_anim, actual_frame = nil, nil
			pcall(function()
				actual_anim = spr:GetAnimation()
				actual_frame = spr:GetFrame()
			end)
			slot_probe[#slot_probe + 1] = {
				slot_key = slot.key,
				plan_key = slot.plan_key,
				clock_key = clock_key,
				from_base = slot.from_base and true or false,
				is_flying = slot.is_flying and true or false,
				head_pass = use_head_clock and true or false,
				anim_source = use_head_clock and "head" or "body",
				role = use_head_clock and "head" or "body",
				anm2 = slot.anm2,
				layer_id = slot.layer_id,
				native_layer_id = slot.native_layer_id or slot.layer_id,
				logical_layer_id = slot.logical_layer_id,
				sort_logical = slot.sort_logical,
				unknown_tail = slot.unknown_tail,
				slot_active_reason = slot.active_reason or "current_animation",
				render_index = #slot_probe,
				render_ok = ok and true or false,
				sprite_ptr = slot.spr and tostring(slot.spr) or nil,
				source_anim = sync_info and sync_info.source_anim or nil,
				target_anim = sync_info and sync_info.target_anim or actual_anim,
				source_len = sync_info and sync_info.source_len or nil,
				target_len = sync_info and sync_info.target_len or nil,
				clock_mode = sync_info and sync_info.clock_mode or nil,
				overlay_active = sync_info and sync_info.overlay_active or nil,
				head_use_idle = sync_info and sync_info.head_use_idle,
				head_display_anim = sync_info and sync_info.head_display_anim or nil,
				body_clock_running = body_running,
				source_frame = sync_info and sync_info.source_frame or nil,
				target_frame = sync_info and sync_info.target_frame or actual_frame,
				actual_anim = actual_anim,
				actual_frame = actual_frame,
			}
			if not slot_probe[#slot_probe].anm2 then
				pcall(function()
					slot_probe[#slot_probe].anm2 = spr:GetFilename()
				end)
			end
		end
		::continue::
	end
	if type(overlay_anim) == "string" and overlay_anim ~= "" then
		local seen = {}
		for _, slot in ipairs(slots) do
			local spr = slot.spr
			if slot.anim_source == "head" and slot.from_base ~= true and spr then
				local h = GetPtrHash(spr)
				if not seen[h] then
					seen[h] = true
					local extra = RM.ghost_head_overlay_extra_anim(spr, overlay_anim)
					if extra then
						local restore_anim, restore_frame = nil, 0
						pcall(function()
							restore_anim = spr:GetAnimation()
							restore_frame = spr:GetFrame()
						end)
						local ids = RM.ghost_animation_layer_ids(spr, extra)
						pcall(function()
							if spr:GetAnimation() ~= extra then
								spr:Play(extra, true)
							end
							local len = RM.sprite_animation_length(spr, extra) or 1
							if len < 1 then len = 1 end
							local fr = Game():GetFrameCount() % len
							spr:SetFrame(extra, fr)
						end)
						for i = 1, #ids do
							local lid = ids[i]
							if RM.sprite_layer_usable(spr, lid) then
								local ok = pcall(function()
									spr.Scale = sc
									spr.FlipX = ghost.FlipX
									spr.Color = Color(tint.R, tint.G, tint.B, alpha)
									spr:RenderLayer(lid, screen, Vector.Zero, Vector.Zero)
								end)
								if ok then drawn = drawn + 1 end
								if #slot_probe < 40 then
									slot_probe[#slot_probe + 1] = {
										slot_key = slot.key,
										plan_key = (slot.plan_key or slot.key) .. "|overlay_extra",
										anim_source = "head",
										role = "head_overlay_extra",
										anm2 = slot.anm2,
										layer_id = lid,
										slot_active_reason = "head_overlay_extra",
										source_anim = overlay_anim,
										target_anim = extra,
										actual_anim = extra,
										render_ok = ok and true or false,
									}
								end
							end
						end
						if type(restore_anim) == "string" and restore_anim ~= "" then
							pcall(function()
								spr:SetFrame(restore_anim, tonumber(restore_frame) or 0)
							end)
						end
					end
				end
			end
		end
	end
	return drawn, slot_probe
end

function RM.ghost_costume_sync_sprite(spr, anim, frame)
	if not RM.sprite_is_usable(spr) or type(anim) ~= "string" or anim == "" then return end
	local target = RM.sprite_resolve_one_of(spr, RM.ghost_walk_anim_candidates(anim))
	if not target then return end
	pcall(function() spr:SetFrame(target, tonumber(frame) or 0) end)
end

function RM.clear_ghost_walk_costumes(ghost)
	if not ghost then return end
	RM.ghost_restore_base_layer_visibility(ghost)
	local gd = ghost:GetData()
	gd[GHOST_COSTUME_WINNERS_KEY] = nil
	gd[GHOST_COSTUME_CANDIDATES_KEY] = nil
	gd[GHOST_COSTUME_SPRS_KEY] = nil
	gd[GHOST_COSTUME_DRIVER_KEY] = nil
	gd[GHOST_COSTUME_CLOCK_KEY] = nil
	gd[GHOST_CLOCK_PROBE_KEY] = nil
	gd[GHOST_PLAN_CACHE_KEY] = nil
	gd[item.own_key.."walk_composite"] = nil
end

function RM.remove_remaster_cinematic_effect(ent)
	if not ent or not ent:Exists() then return end
	local d = ent:GetData()
	if not d[item.own_key.."portal"] and not d[item.own_key.."ghost"] then return end
	if d[item.own_key.."ghost"] then
		RM.clear_ghost_walk_costumes(ent)
		d[GHOST_HELD_VISIBLE_KEY] = false
		d[GHOST_HELD_SPR_KEY] = nil
		d[GHOST_HELD_META_KEY] = nil
	end
	pcall(function() ent:Remove() end)
end

function RM.cleanup_remaster_cinematic_entities(cine)
	if cine then
		cine.portal_transition_fn = nil
		cine.portal_transition_mode = nil
		if cine.portal then RM.remove_remaster_cinematic_effect(cine.portal) end
		if cine.ghost then RM.remove_remaster_cinematic_effect(cine.ghost) end
	end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, PORTAL_EFFECT_VAR, item.entity)) do
		RM.remove_remaster_cinematic_effect(ent)
	end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, PORTAL_EFFECT_VAR, item.entity + 1)) do
		RM.remove_remaster_cinematic_effect(ent)
	end
end

clear_cinematic = function(opts)
	opts = type(opts) == "table" and opts or {}
	local cine = item.cinematic
	if cine then
		RM.revert_channel_returning_state(cine)
		RM.cleanup_remaster_cinematic_entities(cine)
	end
	item.cinematic = nil
	if opts.clear_pending ~= false then
		item._force_emerge = nil
		item._force_return_emerge = nil
		item._pending_fx = nil
		save.elses[C.PENDING_FX_KEY] = nil
	end
	RM.restore_cinematic_party_visibility(opts.fallback_visible ~= false)
end

function RM.render_ghost_walk_costumes(ghost, render_offset)
	if not ghost or not ghost:Exists() or not ghost.Visible then
		RM.emit_ghost_probe("render_skip", ghost, {render_early = "invisible_or_missing"})
		return
	end
	local winners = ghost:GetData()[GHOST_COSTUME_WINNERS_KEY]
	if type(winners) ~= "table" then
		RM.emit_ghost_probe("render_skip", ghost, {render_early = "no_winners"})
		return
	end
	local body = ghost:GetSprite()
	if not RM.sprite_is_usable(body) then
		RM.emit_ghost_probe("render_skip", ghost, {render_early = "body_not_usable"})
		return
	end
	local driver = RM.ghost_get_costume_driver(ghost, winners)
	local Ghost = require("Qing_Remaster_scripts.others.player_appearance_ghost")
	local recorded_pose = Ghost.is_recorded_pose and Ghost.is_recorded_pose(ghost)
	-- Recorded: engine may have advanced Entity Sprite since apply_recorded_pose; pin clocks before sync/render.
	if recorded_pose and Ghost.reassert_recorded_clock then
		Ghost.reassert_recorded_clock(ghost)
	end
	-- Cinematic body clock is the entity sprite. Costume sprites, including head-only hair, follow it.
	local body_anim, body_frame = RM.ghost_read_sprite_anim_frame(body)
	local anim, frame = body_anim, body_frame
	local driver_anim, driver_frame = nil, nil
	if driver and driver.spr then
		driver_anim, driver_frame = RM.ghost_read_sprite_anim_frame(driver.spr)
	end
	if recorded_pose then
		-- Aeon recorded：身体/头姿态以 reassert 后的 ghost sprite 为准，勿用速度推导 Walk*
	elseif type(anim) ~= "string" or anim == "" then
		local desired = RM.ghost_desired_walk_anim(ghost)
		if type(desired) == "string" and desired ~= "" then anim = desired end
	end
	if type(anim) ~= "string" or anim == "" then
		RM.emit_ghost_probe("render_skip", ghost, {render_early = "no_anim"})
		return
	end
	-- 读 body 上真实 overlay（recorded 已写入；空时 cinematic 仍可回退 Head* frame 0）
	local overlay_anim, overlay_frame, overlay_active = RM.ghost_walk_overlay_state(body, anim, ghost)
	local gd = ghost:GetData()
	local sources = RM.ghost_costume_candidates(ghost)
	local cache = gd[GHOST_PLAN_CACHE_KEY]
	local plan
	if type(cache) == "table"
		and cache.main_anim == anim
		and cache.overlay_anim == overlay_anim
		and type(cache.plan) == "table"
	then
		plan = cache.plan
	else
		plan = RM.ghost_build_render_plan(sources, anim, overlay_anim)
		gd[GHOST_PLAN_CACHE_KEY] = {
			main_anim = anim,
			overlay_anim = overlay_anim,
			plan = plan,
		}
	end
	local sc = ghost.SpriteScale or Vector(1, 1)
	local tint = body.Color or Color(1, 1, 1, 1)
	local alpha = tint.A or 1
	local screen = RM.ghost_world_screen_pos(ghost, nil, render_offset)
	local body_running = RM.ghost_body_clock_running(body, anim)
	-- Phase B/C：暂隐被当前 animation plan 中 costume winner 取代的底模同名层
	local suppressed = RM.ghost_suppress_replaced_base_layers(body, plan)
	local drawn_layers, slot_probe = RM.ghost_draw_winner_layers(
		ghost, body, plan, anim, frame, overlay_anim, overlay_frame, overlay_active, nil, render_offset
	)
	drawn_layers = drawn_layers or 0
	-- 底模 Head* overlay 只在「没有 head-source costume winner」时绘制。
	local costume_owns_head = RM.ghost_head_slots_have_costume_winner(plan)
	local head_participates = RM.ghost_directional_head_participates(anim, overlay_anim)
	local overlay_drawn = false
	if not costume_owns_head and head_participates then
		overlay_drawn = RM.ghost_render_sprite_overlay_only(body, screen, sc, ghost.FlipX, tint, alpha)
	end
	local total_drawn = drawn_layers + (overlay_drawn and 1 or 0)
	local render_fallback = false
	if total_drawn == 0 then
		local restore_ov, restore_of = nil, 0
		if not head_participates and type(overlay_anim) == "string" and overlay_anim ~= "" then
			restore_ov = overlay_anim
			restore_of = tonumber(overlay_frame) or 0
			pcall(function() body:RemoveOverlay() end)
		end
		render_fallback = RM.ghost_render_fallback_full_body(ghost, body, screen, sc, tint, alpha)
		if restore_ov then
			pcall(function()
				body:PlayOverlay(restore_ov, true)
				body:SetOverlayFrame(restore_ov, restore_of)
			end)
		end
	end
	-- Phase E：恢复底模 Visible（勿永久改层）
	RM.ghost_restore_layer_visibility_map(body, suppressed)

	local suppressed_count = 0
	for _ in pairs(suppressed) do suppressed_count = suppressed_count + 1 end
	local render_sequence = {}
	if type(slot_probe) == "table" then
		for i = 1, #slot_probe do
			local s = slot_probe[i]
			render_sequence[#render_sequence + 1] = string.format(
				"#%d %s layer=%s logical=%s src=%s %s",
				i,
				tostring(s.slot_key),
				tostring(s.layer_id),
				tostring(s.logical_layer_id),
				tostring(s.anim_source),
				tostring(s.anm2)
			)
		end
	end
	RM.emit_ghost_probe("render_post", ghost, {
		anim = anim,
		frame = frame,
		body_anim = body_anim,
		body_frame = body_frame,
		current_main_anim = anim,
		current_overlay_anim = overlay_anim,
		render_anim = anim,
		render_frame = frame,
		costume_driver = driver and (driver.plan_key or driver.key) or nil,
		driver_anim = driver_anim,
		driver_frame = driver_frame,
		driver_key = driver and (driver.plan_key or driver.key) or nil,
		overlay_anim = overlay_anim,
		overlay_frame = overlay_frame,
		overlay_active = overlay_active and true or false,
		head_participates = head_participates and true or false,
		body_clock_running = body_running,
		plan_slot_count = #plan,
		layers_drawn = drawn_layers,
		overlay_drawn = overlay_drawn,
		costume_owns_head = costume_owns_head,
		base_overlay_suppressed = costume_owns_head,
		base_layers_suppressed = suppressed_count,
		winner_slot_probe = slot_probe,
		clock_probe = ghost:GetData()[GHOST_CLOCK_PROBE_KEY],
		actually_moving = RM.ghost_is_actually_moving(ghost),
		inactive_costume_probe = RM.ghost_inactive_costume_slots(sources, plan, anim, overlay_anim),
		render_sequence = render_sequence,
		render_fallback = render_fallback,
		recorded_pose = recorded_pose and true or false,
	})
end

function RM.play_jump_in(player)
	if not player or not player:Exists() then return end
	player.Velocity = Vector.Zero
	player.Visible = true
	pcall(function() player:PlayExtraAnimation("Trapdoor") end)
end

function RM.play_jump_out(player)
	if not player or not player:Exists() then return end
	player.Velocity = Vector.Zero
	player.Visible = true
	pcall(function() player:PlayExtraAnimation("Jump") end)
end

function RM.play_remaster_lift_sfx()
	-- 与蓝图/Death Sentence 等 AnimateCollectible LiftItem 一致
	pcall(function()
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP, 1, 1, false, 0, 2)
	end)
end

function RM.play_lift_remaster(player)
	if not player or not player:Exists() then return end
	player.Visible = true
	player.Velocity = Vector.Zero
	pcall(function()
		player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
	end)
	RM.play_remaster_lift_sfx()
end

function RM.play_hide_remaster(player)
	if not player or not player:Exists() then return end
	pcall(function()
		if player:IsHoldingItem() then
			player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
		end
	end)
end

function RM.ghost_anim_done(ghost, anim, elapsed, fallback)
	if not ghost or not ghost:Exists() then return (elapsed or 0) >= (fallback or 12) end
	local s = ghost:GetSprite()
	if not RM.sprite_is_usable(s) then return (elapsed or 0) >= (fallback or 12) end
	local done = false
	pcall(function()
		if anim and s:IsFinished(anim) then done = true end
	end)
	if done then return true end
	return (elapsed or 0) >= (fallback or 12)
end

--- LiftItem 的 pickup item 空帧（相对幽灵 Position；Y 负值=上）
function RM.ghost_pickup_null_offset(ghost)
	if not ghost or not ghost:Exists() then return C.PICKUP_NULL_FALLBACK + Vector(0, C.HELD_ITEM_Y_BIAS) end
	local s = ghost:GetSprite()
	if s and s.GetNullFrame then
		local nf = s:GetNullFrame("pickup item")
		if nf and nf.GetPos then
			local pos = nf:GetPos()
			if pos then
				return Vector(pos.X, pos.Y + C.HELD_ITEM_Y_BIAS)
			end
		end
	end
	return C.PICKUP_NULL_FALLBACK + Vector(0, C.HELD_ITEM_Y_BIAS)
end

function RM.walk_anim_for_delta(delta)
	delta = delta or Vector.Zero
	if math.abs(delta.X) >= math.abs(delta.Y) then
		return delta.X >= 0 and "WalkRight" or "WalkLeft"
	end
	return delta.Y >= 0 and "WalkDown" or "WalkUp"
end

function RM.door_is_hidden_closed(door)
	if not door then return true end
	local hidden = false
	pcall(function() hidden = door.Variant == DoorVariant.DOOR_HIDDEN end)
	if not hidden then return false end
	local open = false
	pcall(function() open = door:IsOpen() end)
	return not open
end

function RM.collect_ghost_door_choices(from_pos)
	local room = Game():GetRoom()
	local open_doors = {}
	local locked_doors = {}
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		if room:IsDoorSlotAllowed(slot) then
			local door = room:GetDoor(slot)
			if door and not RM.door_is_hidden_closed(door) then
				local pos = room:GetDoorSlotPosition(slot)
				local entry = {
					slot = slot,
					door = door,
					pos = pos,
					dist = (pos - from_pos):Length(),
				}
				local is_open = false
				pcall(function() is_open = door:IsOpen() end)
				if is_open then
					open_doors[#open_doors + 1] = entry
				else
					local locked = false
					pcall(function() locked = door:IsLocked() end)
					if locked then
						locked_doors[#locked_doors + 1] = entry
					end
				end
			end
		end
	end
	return open_doors, locked_doors
end

function RM.pick_random_door_pos(from_pos)
	local open_doors, locked_doors = RM.collect_ghost_door_choices(from_pos)
	local pool = #open_doors > 0 and open_doors or locked_doors
	if #pool == 0 then
		return from_pos + Vector(0, 72), nil
	end
	table.sort(pool, function(a, b) return a.dist < b.dist end)
	local n = math.min(#pool, 3)
	local pick = pool[math.random(1, n)]
	return pick.pos, pick
end

function RM.try_unlock_ghost_door(cine, door, dist)
	if not cine or not door or cine.door_unlock_tried then return end
	if dist > C.GHOST_DOOR_UNLOCK_RANGE then return end
	local player = cine.player
	pcall(function()
		if not (door.Exists and door:Exists()) then return end
		local locked = door.IsLocked and door:IsLocked()
		if locked then
			door:TryUnlock(player, true)
			cine.door_unlock_tried = true
			return
		end
		local open = door.IsOpen and door:IsOpen()
		if not open and door.Open then
			door:Open()
			cine.door_unlock_tried = true
		end
	end)
end

function RM.ghost_play_anim(ghost, names)
	if not ghost or not ghost:Exists() then return nil end
	return RM.sprite_play_anim(ghost:GetSprite(), names)
end

local function held_visual_identity(spec)
	if type(spec) ~= "table" then
		return "collectible:" .. tostring(spec or "")
	end
	if spec.kind == "pickup" then
		return "pickup:" .. tostring(spec.variant) .. ":" .. tostring(spec.subtype or 0) .. ":" .. tostring(spec.anm2 or "")
	end
	return "collectible:" .. tostring(spec.gfx or "")
end

function RM.normalize_held_visual(spec)
	if spec == nil then
		return { kind = "collectible", gfx = RM.remaster_gfx_path() }
	end
	if type(spec) == "string" then
		return { kind = "collectible", gfx = spec }
	end
	if type(spec) ~= "table" then
		return { kind = "collectible", gfx = RM.remaster_gfx_path() }
	end
	if spec.kind == "pickup" then
		return {
			kind = "pickup",
			variant = tonumber(spec.variant) or 0,
			subtype = tonumber(spec.subtype) or 0,
			anm2 = type(spec.anm2) == "string" and spec.anm2 or nil,
		}
	end
	local gfx = spec.gfx
	if type(gfx) ~= "string" or gfx == "" then
		gfx = RM.remaster_gfx_path()
	end
	return { kind = "collectible", gfx = gfx }
end

local PICKUP_HELD_FALLBACK_ANM2 = {
	[PickupVariant.PICKUP_HEART] = "gfx/005.011_heart.anm2",
	[PickupVariant.PICKUP_COIN] = "gfx/005.021_penny.anm2",
	[PickupVariant.PICKUP_BOMB] = "gfx/005.041_bomb.anm2",
	[PickupVariant.PICKUP_KEY] = "gfx/005.031_key.anm2",
	[PickupVariant.PICKUP_LIL_BATTERY] = "gfx/005.090_littlebattery.anm2",
	[PickupVariant.PICKUP_TAROTCARD] = "gfx/005.301_tarot card.anm2",
	[PickupVariant.PICKUP_CHEST] = "gfx/005.050_chest.anm2",
	[PickupVariant.PICKUP_ETERNALCHEST] = "gfx/005.053_eternalchest.anm2",
	[PickupVariant.PICKUP_OLDCHEST] = "gfx/005.055_oldchest.anm2",
	[PickupVariant.PICKUP_LOCKEDCHEST] = "gfx/005.060_lockedchest.anm2",
}

function RM.pickup_held_anm2(variant, subtype)
	local path = nil
	pcall(function()
		local cfg = EntityConfig.GetEntity(EntityType.ENTITY_PICKUP, variant, subtype or -1)
		if cfg and cfg.GetAnm2Path then
			path = cfg:GetAnm2Path()
		end
	end)
	if type(path) == "string" and path ~= "" then return path end
	if subtype and subtype ~= 0 and subtype ~= -1 then
		pcall(function()
			local cfg = EntityConfig.GetEntity(EntityType.ENTITY_PICKUP, variant, -1)
			if cfg and cfg.GetAnm2Path then
				path = cfg:GetAnm2Path()
			end
		end)
		if type(path) == "string" and path ~= "" then return path end
	end
	return PICKUP_HELD_FALLBACK_ANM2[variant]
end

local function play_held_idle(spr)
	pcall(function()
		spr:Play("Idle", true)
		if spr:GetAnimation() ~= "Idle" then
			spr:Play("Idle", false)
		end
	end)
	return RM.sprite_is_usable(spr)
end

--- Build a held Sprite for PICKUP_TAROTCARD from concrete Card ID / subtype.
--- Uses shared pocket_visual (ModdedCardFront / PickupSubtype / CardType).
--- Returns spr, meta or nil, meta.
function RM.build_held_card_sprite(subtype)
	local pocket = require("Qing_Remaster_scripts.others.pocket_visual")
	local visual = pocket.resolve_card_visual(subtype)
	local meta = {
		variant = PickupVariant.PICKUP_TAROTCARD,
		subtype = tonumber(subtype) or 0,
		card_id = visual and visual.card_id or (tonumber(subtype) or 0),
		anm2 = visual and visual.anm2 or nil,
		family = visual and visual.family or nil,
		exact = visual and visual.exact or false,
		is_rune = visual and visual.is_rune or false,
		pickup_subtype = visual and visual.pickup_subtype or nil,
		card_type = visual and visual.card_type or nil,
	}
	if not visual then
		return nil, meta
	end
	if visual.exact and visual.sprite then
		local spr = visual.sprite
		play_held_idle(spr)
		if RM.sprite_is_usable(spr) then
			pcall(function() meta.anm2 = spr:GetFilename() end)
			return spr, meta
		end
	end
	local anm2 = visual.anm2
	if type(anm2) ~= "string" or anm2 == "" then
		anm2 = "gfx/005.301_tarot card.anm2"
	end
	meta.anm2 = anm2
	local spr = Sprite()
	if RM.try_sprite_load(spr, anm2) and play_held_idle(spr) then
		return spr, meta
	end
	return nil, meta
end

function RM.get_ghost_held_info(ghost)
	if not ghost or not ghost:Exists() then return nil end
	local gd = ghost:GetData()
	local meta = gd[GHOST_HELD_META_KEY]
	if type(meta) ~= "table" then return nil end
	local copy = {}
	for k, v in pairs(meta) do
		copy[k] = v
	end
	copy.identity = gd[item.own_key.."held_gfx"]
	copy.visible = gd[GHOST_HELD_VISIBLE_KEY] and true or false
	local spr = gd[GHOST_HELD_SPR_KEY]
	if spr then
		pcall(function() copy.filename = spr:GetFilename() end)
		pcall(function() copy.anim = spr:GetAnimation() end)
	end
	return copy
end

--- visual: nil / gfx string / {kind="collectible", gfx=} keeps the collectible sheet.
--- {kind="pickup", variant, subtype} loads that pickup's ANM2 and holds Idle.
--- PICKUP_TAROTCARD uses pocket_visual so Card ID subtype maps to rune/tarot/special fronts.
function RM.ensure_ghost_held_sprite(ghost, spec)
	if not ghost or not ghost:Exists() then return nil end
	local visual = RM.normalize_held_visual(spec)
	local identity = held_visual_identity(visual)
	local gd = ghost:GetData()
	local spr = gd[GHOST_HELD_SPR_KEY]
	if spr and gd[item.own_key.."held_gfx"] ~= identity then
		spr = nil
		gd[GHOST_HELD_SPR_KEY] = nil
		gd[GHOST_HELD_META_KEY] = nil
	end
	if not spr then
		local ok = false
		local meta = {
			kind = visual.kind,
			variant = visual.variant,
			subtype = visual.subtype,
		}
		if visual.kind == "pickup" and visual.variant == PickupVariant.PICKUP_TAROTCARD then
			spr, meta = RM.build_held_card_sprite(visual.subtype)
			ok = spr ~= nil and RM.sprite_is_usable(spr)
			if not ok then
				spr = Sprite()
				local fallback = visual.anm2 or "gfx/005.301_tarot card.anm2"
				ok = RM.try_sprite_load(spr, fallback) and play_held_idle(spr)
				meta = meta or {}
				meta.anm2 = fallback
				meta.fallback = true
			end
		elseif visual.kind == "pickup" then
			spr = Sprite()
			local anm2 = visual.anm2 or RM.pickup_held_anm2(visual.variant, visual.subtype)
			if type(anm2) ~= "string" or anm2 == "" then
				anm2 = "gfx/005.021_penny.anm2"
			end
			ok = RM.try_sprite_load(spr, anm2) and play_held_idle(spr)
			if not ok then
				ok = RM.try_sprite_load(spr, "gfx/005.021_penny.anm2") and play_held_idle(spr)
				anm2 = "gfx/005.021_penny.anm2"
			end
			meta.anm2 = anm2
		else
			spr = Sprite()
			local sheet = visual.gfx
			ok = pcall(function()
				spr:Load(C.HELD_ITEM_ANM2, true)
				spr:ReplaceSpritesheet(0, sheet)
				spr:ReplaceSpritesheet(1, sheet)
				spr:LoadGraphics()
				spr:Play("PlayerPickup", true)
				if not spr:IsPlaying("PlayerPickup") then
					spr:Play("Idle", true)
				end
			end)
			ok = ok and RM.sprite_is_usable(spr)
			meta.gfx = sheet
			meta.anm2 = C.HELD_ITEM_ANM2
		end
		if ok then
			gd[GHOST_HELD_SPR_KEY] = spr
			gd[GHOST_HELD_META_KEY] = meta
		else
			spr = nil
			gd[GHOST_HELD_META_KEY] = nil
		end
	end
	if spr then
		gd[item.own_key.."held_gfx"] = identity
		gd[GHOST_HELD_VISIBLE_KEY] = true
	end
	return spr
end

function RM.tick_ghost_walk_costume_sprites(ghost)
	if not ghost or not ghost:Exists() then return end
	local gd = ghost:GetData()
	if not gd[item.own_key.."walk_composite"] then return end
	local Ghost = require("Qing_Remaster_scripts.others.player_appearance_ghost")
	local pool = gd[GHOST_COSTUME_SPRS_KEY]
	if type(pool) ~= "table" then return end
	-- Recorded: allow Lua Sprite Update (layer events), but never rewrite Walk* from velocity.
	-- Recorded clocks are re-applied in render (reassert + draw winners).
	if Ghost.is_recorded_pose and Ghost.is_recorded_pose(ghost) then
		for _, spr in ipairs(pool) do
			RM.tick_lua_sprite(spr, true)
		end
		return
	end
	-- Cinematic: only advance clocks that own their own timeline.
	-- shared / head_idle: render-time SetFrame only.
	-- movement_independent: only while base Walk PlaybackSpeed > 0.
	-- persistent / head_independent: always tick.
	local clocks = gd[GHOST_COSTUME_CLOCK_KEY]
	if type(clocks) ~= "table" then return end
	local body = ghost:GetSprite()
	local body_anim = nil
	pcall(function() body_anim = body:GetAnimation() end)
	local body_running = RM.ghost_body_clock_running(body, body_anim)
	local app = gd[item.own_key.."ghost_app"]
	local seen = {}
	local probe = {}
	for key, state in pairs(clocks) do
		local mode = state and state.mode
		local should_tick = mode == "persistent" or mode == "head_independent"
			or (mode == "movement_independent" and body_running)
		local spr = state and state.spr
		local rate = RM.ghost_costume_playback_rate(state, ghost, body_anim, app)
		if should_tick and spr and not seen[spr] then
			seen[spr] = true
			RM.advance_sprite_clock(state, rate)
		elseif state then
			state.ticks_this_update = 0
			state.effective_rate = rate
		end
		if state and #probe < 16 then
			probe[#probe + 1] = {
				clock_key = key,
				sprite_ptr = spr and tostring(spr) or nil,
				anim = state.anim,
				mode = mode,
				anim_source = state.anim_source,
				base_rate = tonumber(state.update_rate) or 1,
				effective_rate = state.effective_rate or rate,
				accumulator = state.update_accum,
				ticks_this_update = state.ticks_this_update or 0,
				frame_before = state.frame_before,
				frame_after = state.frame_after,
				should_tick = should_tick and true or false,
			}
		end
	end
	gd[GHOST_CLOCK_PROBE_KEY] = probe
end

function RM.hide_ghost_held_sprite(ghost)
	if not ghost then return end
	local gd = ghost:GetData()
	gd[GHOST_HELD_VISIBLE_KEY] = false
	gd[GHOST_HELD_SPR_KEY] = nil
	gd[GHOST_HELD_META_KEY] = nil
end

function RM.tick_ghost_held_sprite(ghost, advance)
	if not ghost or not ghost:Exists() then return end
	local gd = ghost:GetData()
	if not gd[GHOST_HELD_VISIBLE_KEY] then return end
	local spr = gd[GHOST_HELD_SPR_KEY]
	if not spr or advance == false then return end
	RM.tick_lua_sprite(spr, true)
end

function RM.render_ghost_held_sprite(ghost, render_offset)
	if not ghost or not ghost:Exists() or not ghost.Visible then return end
	local gd = ghost:GetData()
	if not gd[GHOST_HELD_VISIBLE_KEY] then return end
	local spr = gd[GHOST_HELD_SPR_KEY]
	if not RM.sprite_is_usable(spr) then return end
	local sc = ghost.SpriteScale and ghost.SpriteScale.Y or 1
	local off = RM.ghost_pickup_null_offset(ghost)
	local screen = RM.ghost_world_screen_pos(ghost, Vector(off.X * sc, off.Y * sc), render_offset)
	local alpha = 1
	pcall(function()
		local body = ghost:GetSprite()
		if body and body.Color then alpha = body.Color.A or 1 end
	end)
	pcall(function()
		spr.Scale = Vector(sc, sc)
		spr.FlipX = ghost.FlipX
		spr.Color = Color(1, 1, 1, alpha)
		spr:Render(screen, Vector.Zero, Vector.Zero)
	end)
end

function RM.sync_ghost_held_visual(ghost, freeze_body)
	if not ghost or not ghost:Exists() then return end
	RM.tick_ghost_held_sprite(ghost, not freeze_body)
end

function RM.ghost_apply_walk_facing(ghost, _anim)
	if not ghost or not ghost:Exists() then return end
	-- WalkLeft/Right 已是独立朝向动画；再 FlipX 会镜像过头
	ghost.FlipX = false
end

function RM.begin_ghost_lift(cine)
	if not cine.ghost or not cine.ghost:Exists() then return end
	cine.ghost_anim_cache = {}
	RM.ghost_clear_walk_head_overlay(cine.ghost, cine.ghost_anim_cache)
	RM.ghost_ensure_anim(cine.ghost, "LiftItem", cine.ghost_anim_cache)
	RM.ensure_ghost_held_sprite(cine.ghost)
	RM.sync_ghost_held_visual(cine.ghost, false)
	RM.play_remaster_lift_sfx()
end

function RM.begin_ghost_walk_to_door(cine)
	if not cine.ghost or not cine.ghost:Exists() then return end
	RM.hide_ghost_held_sprite(cine.ghost)
	RM.ghost_clear_walk_head_overlay(cine.ghost, cine.ghost_anim_cache)
	local from = Vector(cine.ghost.Position.X, cine.ghost.Position.Y)
	cine.walk_from = from
	cine.door_target, cine.door_entry = RM.pick_random_door_pos(from)
	cine.door_unlock_tried = nil
	cine.ghost_walk_origin = Vector(from.X, from.Y)
	local delta = cine.door_target - from
	cine.ghost_walk_anim = RM.walk_anim_for_delta(delta)
	cine.ghost_anim_cache = {}
	RM.setup_ghost_walk_costumes(cine.ghost, cine.appearance)
	RM.ghost_apply_walk_facing(cine.ghost, cine.ghost_walk_anim)
	RM.ghost_ensure_anim(cine.ghost, cine.ghost_walk_anim, cine.ghost_anim_cache)
	RM.ghost_sync_walk_head_overlay(cine.ghost, cine.ghost_walk_anim, cine.ghost_anim_cache)
	RM.emit_ghost_probe("begin_walk", cine.ghost, {walk_anim = cine.ghost_walk_anim})
end

function RM.finish_return_travel(cine)
	local ch = cine.channel
	local dest = ch and ch.from
	local app = cine.appearance
	local idx = cine.channel_index
	local synergy = nil
	if type(ch.return_pending) == "table" and ch.return_pending[1] then
		synergy = {
			remaster_wisp = ch.return_pending[1].remaster_wisp,
			belial_stats = ch.return_pending[1].belial_stats,
		}
	end
	if not idx and ch and ch.from and ch.to then
		idx = select(1, RM.find_channel_index_by_route(ch.from.command, ch.to.command))
	end
	if idx and ch then
		if type(ch.return_pending) == "table" and #ch.return_pending > 0 then
			table.remove(ch.return_pending, 1)
		end
		local next_passenger = ch.return_pending and ch.return_pending[1]
		local still_outbound = type(ch.outbound_pending) == "table" and #ch.outbound_pending > 0
		if next_passenger then
			ch.appearance = next_passenger.appearance
			ch.opened_run_id = next_passenger.opened_run_id
			ch.armed = true
			ch.returning = nil
			ch.skip_arrive_once = still_outbound and true or nil
			RM.update_channel_at(idx, ch)
		elseif still_outbound then
			ch.armed = false
			ch.returning = nil
			ch.skip_arrive_once = true
			RM.update_channel_at(idx, ch)
		else
			item.remove_channel_at(idx)
		end
	end
	RM.set_pending_fx({
		kind = "return_emerge",
		appearance = app,
		remaster_wisp = synergy and synergy.remaster_wisp,
		belial_stats = synergy and synergy.belial_stats,
	})
	item._force_return_emerge = {appearance = app, synergy = synergy}
	item.cinematic = nil
	if dest then
		RM.execute_stage_travel(dest, {reseed = true})
	end
end

function RM.finish_return_emerge(cine)
	local player = cine and cine.player
	local portal = cine.portal
	if portal and portal:Exists() then
		RM.close_portal(portal)
		cine.portal = nil
	end
	if player and player:Exists() then
		player.Visible = true
		player.Velocity = Vector.Zero
	end
	local payload = RM.take_pending_fx()
	if type(payload) ~= "table" then payload = {} end
	if (not payload.remaster_wisp and not payload.belial_stats) and cine.return_synergy then
		payload.remaster_wisp = cine.return_synergy.remaster_wisp
		payload.belial_stats = cine.return_synergy.belial_stats
	end
	local portal_pos = cine.portal_pos or (player and player.Position)
	if payload.remaster_wisp then
		RM.try_play_return_wisp_grant(cine, player, portal_pos)
		RM.apply_remaster_synergy_on_return(player, payload, {skip_remaster_wisp = true})
	else
		RM.apply_remaster_synergy_on_return(player, payload)
	end
	local ch = cine.channel
	item.cinematic = nil
	item._party_hide = nil
	RM.on_remaster_arrival()
	pcall(function()
		item.fx.after_return({dir = "return", channel = ch})
	end)
end

-- ---------- 特效缺口（默认无表现；后续替换） ----------
function item.fx.before_outbound(ctx)
end

function item.fx.after_outbound(ctx)
end

function item.fx.before_return(ctx)
end

function item.fx.after_return(ctx)
end

--- 供外部/后续动画模块查询（返回永久渠道列表）
function item.get_active_channel()
	local list = item.get_channels()
	return list[1]
end

function item.has_pending_return()
	for _, ch in ipairs(item.get_channels()) do
		if ch.armed == true then return true end
	end
	return false
end

function RM.player_index_of(player)
	if not player then return 0 end
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and GetPtrHash(p) == GetPtrHash(player) then return i end
	end
	return 0
end

function RM.resolve_cine_player(cine)
	local p = Game():GetPlayer(cine.player_index or 0)
	if p and p:Exists() then
		cine.player = p
		return p
	end
	if cine.player and cine.player:Exists() then return cine.player end
	return nil
end

function RM.begin_outbound_cinematic(player, slot, from, to, target)
	local appearance = RM.capture_player_appearance(player)
	local synergy = RM.capture_outbound_synergy(player)
	RM.register_outbound_passenger(from, to, target, appearance, RM.get_current_run_id(), synergy)
	local portal_pos = RM.pick_portal_pos(player)
	local portal = RM.spawn_remaster_portal(portal_pos)
	item.cinematic = {
		kind = "outbound",
		phase = "portal_open",
		t0 = Game():GetFrameCount(),
		player = player,
		player_index = RM.player_index_of(player),
		slot = slot,
		from = from,
		to = to,
		target = target,
		appearance = appearance,
		remaster_wisp = synergy and synergy.remaster_wisp,
		portal = portal,
		portal_pos = portal_pos,
		suck_from = Vector(player.Position.X, player.Position.Y),
	}
	if synergy and synergy.remaster_wisp then
		RM.ensure_outbound_orbit_wisp(item.cinematic, player)
	end
	RM.freeze_player(player, true)
	RM.hide_party_for_cinematic(player, {player_keep_hidden = false})
	pcall(function()
		item.fx.before_outbound({
			dir = "outbound",
			from = from,
			to = to,
			target = target,
			player = player,
			slot = slot,
		})
	end)
end

function RM.begin_outbound_emerge(player, appearance)
	if item.cinematic and item.cinematic.kind == "outbound_emerge" then
		item._force_emerge = nil
		return
	end
	player = player or Game():GetPlayer(0)
	if not player or not player:Exists() then return end
	item._force_emerge = nil
	RM.set_player_hidden(player, true)
	player.Velocity = Vector.Zero
	local portal_pos = RM.pick_portal_pos()
	player.Position = portal_pos
	local portal = RM.spawn_remaster_portal(portal_pos)
	RM.restore_party_familiars()
	item.cinematic = {
		kind = "outbound_emerge",
		phase = "portal_open",
		t0 = Game():GetFrameCount(),
		born = Game():GetFrameCount(),
		player = player,
		player_index = RM.player_index_of(player),
		appearance = appearance,
		portal = portal,
		portal_pos = portal_pos,
	}
	RM.freeze_player(player, true)
end

function RM.begin_return_emerge(player, appearance, synergy)
	if item.cinematic and item.cinematic.kind == "return_emerge" then
		item._force_return_emerge = nil
		return
	end
	player = player or Game():GetPlayer(0)
	if not player or not player:Exists() then return end
	item._force_return_emerge = nil
	RM.set_player_hidden(player, true)
	player.Velocity = Vector.Zero
	local portal_pos = RM.pick_portal_pos()
	player.Position = portal_pos
	local portal = RM.spawn_remaster_portal(portal_pos)
	RM.restore_party_familiars()
	item.cinematic = {
		kind = "return_emerge",
		phase = "portal_open",
		t0 = Game():GetFrameCount(),
		born = Game():GetFrameCount(),
		player = player,
		player_index = RM.player_index_of(player),
		appearance = appearance,
		return_synergy = type(synergy) == "table" and synergy or nil,
		portal = portal,
		portal_pos = portal_pos,
	}
	RM.freeze_player(player, true)
end

function RM.begin_return_cinematic(player, channel_index, channel)
	player = player or Game():GetPlayer(0)
	if not player or not player:Exists() then return end
	local active = RM.channel_active_return_passenger(channel)
	channel.returning = true
	RM.update_channel_at(channel_index, channel)
	item.cinematic = {
		kind = "return",
		phase = "wake",
		t0 = Game():GetFrameCount(),
		player = player,
		player_index = RM.player_index_of(player),
		channel_index = channel_index,
		channel = channel,
		appearance = (active and active.appearance) or channel.appearance,
	}
	RM.freeze_player(player, true)
	pcall(function()
		item.fx.before_return({
			dir = "return",
			from = channel.to,
			to = channel.from,
			channel = channel,
			channel_index = channel_index,
		})
	end)
end

function RM.tick_cinematic()
	local cine = item.cinematic
	if not cine then return end
	local player = RM.resolve_cine_player(cine)
	if not player then
		clear_cinematic({fallback_visible = true})
		return
	end
	local allow_move = cine.kind == "outbound_emerge"
		and (cine.phase == "await_portal_leave" or cine.phase == "wisp_fall_close")
	if not allow_move then
		RM.freeze_player(player, true)
	end
	local elapsed = Game():GetFrameCount() - (cine.t0 or 0)
	local portal = cine.portal
	if portal and portal:Exists() then RM.portal_tick(portal) else portal = nil end
	local channel_wisp = RM.resolve_cine_wisp(cine)
	if channel_wisp then channel_wisp.Visible = true end
	if cine.ghost and cine.ghost:Exists() then
		if cine.phase == "ghost_lift" or cine.phase == "ghost_lift_hold" then
			RM.sync_ghost_held_visual(cine.ghost, cine.phase == "ghost_lift_hold")
		end
	end

	if cine.phase == "portal_transition" then
		RM.tick_portal_screen_transition(cine, elapsed)
		return
	end

	local function start_suck_then_jump()
		local target = (portal and portal.Position) or cine.portal_pos or RM.pick_portal_pos()
		cine.portal_pos = target
		RM.ensure_outbound_orbit_wisp(cine, player)
		-- 已在门附近：直接跳入，避免无意义瞬移感
		if (player.Position - target):Length() < 20 then
			player.Position = target
			cine.phase = "jump_in"
			cine.t0 = Game():GetFrameCount()
			RM.play_jump_in(player)
			return
		end
		cine.phase = "suck_in"
		cine.t0 = Game():GetFrameCount()
		cine.suck_from = Vector(player.Position.X, player.Position.Y)
	end

	local function commit_outbound_travel(to_floor, appearance)
		local app = appearance
		RM.set_pending_fx({
			kind = "outbound_emerge",
			appearance = app,
		})
		item._force_emerge = {appearance = app}
		item.cinematic = nil
		if to_floor then
			RM.execute_stage_travel(to_floor, {reseed = true})
		end
	end

	if cine.kind == "outbound" then
		if cine.phase == "portal_open" then
			if RM.portal_is_ready(portal) and elapsed >= C.OPEN_SETTLE then
				start_suck_then_jump()
			end
		elseif cine.phase == "suck_in" then
			local target = cine.portal_pos or RM.pick_portal_pos()
			local t = elapsed / C.SUCK_DUR
			if t >= 1 or (player.Position - target):Length() < 6 then
				player.Position = target
				cine.phase = "jump_in"
				cine.t0 = Game():GetFrameCount()
				RM.play_jump_in(player)
			else
				local ease = t * t
				player.Position = RM.vec_lerp(cine.suck_from, target, ease)
			end
		elseif cine.phase == "jump_in" then
			-- 等 Trapdoor 播完再 portal shader 换层，传送门保持开启
			if RM.extra_anim_done(player, 12, elapsed, C.JUMP_IN_WAIT) then
				RM.trigger_outbound_wisp_fall(cine, player)
				RM.hide_party_for_cinematic(player, {player_keep_hidden = true})
				local to_floor = cine.to
				local app = cine.appearance
				RM.begin_portal_screen_transition(cine, "enter", function()
					commit_outbound_travel(to_floor, app)
				end)
			end
		end
	elseif cine.kind == "outbound_emerge" then
		-- 安全阀：演出卡死时强制现身
		local total_age = Game():GetFrameCount() - (cine.born or cine.t0 or 0)
		if total_age > 240 then
			RM.restore_party_player(player, true)
			RM.play_hide_remaster(player)
			clear_cinematic({fallback_visible = true})
			return
		end
		if cine.phase == "portal_open" then
			RM.set_player_hidden(player, true)
			if RM.portal_is_ready(portal) and elapsed >= C.OPEN_SETTLE then
				RM.begin_portal_screen_transition(cine, "exit", function()
					cine.phase = "jump_out"
					cine.t0 = Game():GetFrameCount()
					if cine.portal and cine.portal:Exists() then
						player.Position = cine.portal.Position
					elseif cine.portal_pos then
						player.Position = cine.portal_pos
					end
					RM.restore_party_familiars()
					RM.restore_party_player(player, true)
					RM.play_jump_out(player)
				end)
			end
		elseif cine.phase == "jump_out" then
			-- 落地后立刻举起，更连贯
			if RM.extra_anim_done(player, 10, elapsed, C.JUMP_OUT_WAIT) then
				RM.ensure_arrival_hover_wisp(cine, player)
				cine.phase = "lift"
				cine.t0 = Game():GetFrameCount()
				RM.restore_party_familiars()
				RM.restore_party_player(player, true)
				RM.play_lift_remaster(player)
			end
		elseif cine.phase == "lift" then
			if elapsed >= C.LIFT_WAIT then
				RM.play_hide_remaster(player)
				RM.ensure_arrival_hover_wisp(cine, player)
				cine.phase = "await_portal_leave"
				cine.t0 = Game():GetFrameCount()
				RM.restore_party_familiars()
				RM.unfreeze_cinematic_player(player)
			end
		elseif cine.phase == "await_portal_leave" then
			local portal_pos = RM.cine_portal_pos(cine, player)
			local dist = (player.Position - portal_pos):Length()
			local left = dist > C.WISP_PORTAL_LEAVE_RADIUS
			local timed_out = elapsed >= C.WISP_PORTAL_LEAVE_TIMEOUT
			if left or timed_out then
				if RM.resolve_cine_wisp(cine) then
					RM.trigger_arrival_wisp_fall_and_close(cine, player, portal)
				else
					if portal and portal:Exists() then RM.close_portal(portal) end
					cine.portal = nil
					local app = cine.appearance
					item.cinematic = nil
					item._party_hide = nil
					RM.on_remaster_arrival()
					pcall(function()
						item.fx.after_outbound({dir = "outbound_arrive", appearance = app})
					end)
				end
			end
		elseif cine.phase == "wisp_fall_close" then
			local stuck = elapsed >= C.WISP_PORTAL_LEAVE_TIMEOUT + C.WISP_FALL_DUR + 30
			local wisp = RM.resolve_cine_wisp(cine)
			if not wisp or stuck then
				if stuck and wisp then pcall(function() wisp:Remove() end) end
				if portal and portal:Exists() then RM.close_portal(portal) end
				cine.portal = nil
				local app = cine.appearance
				item.cinematic = nil
				item._party_hide = nil
				RM.on_remaster_arrival()
				pcall(function()
					item.fx.after_outbound({dir = "outbound_arrive", appearance = app})
				end)
			end
		end
	elseif cine.kind == "return_emerge" then
		local total_age = Game():GetFrameCount() - (cine.born or cine.t0 or 0)
		if total_age > 240 then
			RM.restore_party_player(player, true)
			RM.finish_return_emerge(cine)
			return
		end
		if cine.phase == "portal_open" then
			RM.set_player_hidden(player, true)
			if RM.portal_is_ready(portal) and elapsed >= C.OPEN_SETTLE then
				RM.begin_portal_screen_transition(cine, "exit", function()
					cine.phase = "jump_out"
					cine.t0 = Game():GetFrameCount()
					if cine.portal and cine.portal:Exists() then
						player.Position = cine.portal.Position
					elseif cine.portal_pos then
						player.Position = cine.portal_pos
					end
					RM.restore_party_familiars()
					RM.restore_party_player(player, true)
					RM.play_jump_out(player)
				end)
			end
		elseif cine.phase == "jump_out" then
			if RM.extra_anim_done(player, 10, elapsed, C.JUMP_OUT_WAIT) then
				RM.finish_return_emerge(cine)
			end
		end
	elseif cine.kind == "return" then
		if cine.phase == "wake" then
			local woke = true
			pcall(function()
				if player.IsExtraAnimationFinished then
					woke = player:IsExtraAnimationFinished()
				end
			end)
			if elapsed >= C.WAKE_WAIT and woke then
				cine.phase = "portal_open"
				cine.t0 = Game():GetFrameCount()
				local portal_pos = RM.pick_portal_pos()
				cine.portal_pos = portal_pos
				cine.portal = RM.spawn_remaster_portal(portal_pos)
			end
		elseif cine.phase == "portal_open" then
			if RM.portal_is_ready(cine.portal) and elapsed >= C.OPEN_SETTLE then
				start_suck_then_jump()
			end
		elseif cine.phase == "suck_in" then
			local target = cine.portal_pos or RM.pick_portal_pos()
			local t = elapsed / C.SUCK_DUR
			if t >= 1 or (player.Position - target):Length() < 6 then
				player.Position = target
				cine.phase = "jump_in"
				cine.t0 = Game():GetFrameCount()
				RM.play_jump_in(player)
			else
				local ease = t * t
				player.Position = RM.vec_lerp(cine.suck_from, target, ease)
			end
		elseif cine.phase == "jump_in" then
			if RM.extra_anim_done(player, 12, elapsed, C.JUMP_IN_WAIT) then
				RM.hide_party_for_cinematic(player, {player_keep_hidden = true})
				cine.phase = "portal_digest"
				cine.t0 = Game():GetFrameCount()
			end
		elseif cine.phase == "portal_digest" then
			if elapsed >= C.GHOST_SPIT_WAIT then
				cine.phase = "ghost_spit"
				cine.t0 = Game():GetFrameCount()
				local pos = cine.portal_pos or RM.pick_portal_pos()
				cine.spit_from = pos + Vector(0, -10)
				cine.spit_to = pos + Vector(0, 10)
				cine.ghost = RM.spawn_appearance_ghost(cine.spit_from, cine.appearance, "Jump")
				if not cine.ghost then
					local bare = RM.sanitize_appearance({
						base_anm2 = C.DEFAULT_GHOST_ANM2,
						sprite_scale = cine.appearance and cine.appearance.sprite_scale,
						costumes = {},
					})
					cine.ghost = RM.spawn_appearance_ghost(cine.spit_from, bare, "Jump")
				end
				RM.ensure_return_ghost_hover_wisp(cine)
				RM.portal_reset_scale(cine.portal)
				pcall(function()
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_PORTAL_OPEN, 1.0, 1, false, 0, 2)
				end)
			end
		elseif cine.phase == "ghost_spit" then
			if cine.ghost and cine.ghost:Exists() then
				local t = math.min(1, elapsed / C.GHOST_JUMP_WAIT)
				local ease = 1 - (1 - t) ^ 2
				cine.ghost.Position = RM.vec_lerp(cine.spit_from, cine.spit_to, ease)
			end
			if RM.ghost_anim_done(cine.ghost, "Jump", elapsed, C.GHOST_JUMP_WAIT) then
				cine.phase = "ghost_lift"
				cine.t0 = Game():GetFrameCount()
				cine.lift_hold = false
				RM.begin_ghost_lift(cine)
			end
		elseif cine.phase == "ghost_lift" then
			if not cine.lift_hold then
				RM.sync_ghost_held_visual(cine.ghost, false)
				if RM.ghost_anim_done(cine.ghost, "LiftItem", elapsed, C.GHOST_LIFT_FALLBACK) then
					cine.lift_hold = true
					cine.phase = "ghost_lift_hold"
					cine.t0 = Game():GetFrameCount()
				end
			end
		elseif cine.phase == "ghost_lift_hold" then
			RM.sync_ghost_held_visual(cine.ghost, true)
			if elapsed >= C.GHOST_LIFT_HOLD then
				cine.phase = "ghost_hide_item"
				cine.t0 = Game():GetFrameCount()
				RM.hide_ghost_held_sprite(cine.ghost)
				RM.ghost_clear_walk_head_overlay(cine.ghost, cine.ghost_anim_cache)
				cine.ghost_anim_cache = {}
				RM.ghost_ensure_anim(cine.ghost, "HideItem", cine.ghost_anim_cache)
			end
		elseif cine.phase == "ghost_hide_item" then
			if RM.ghost_anim_done(cine.ghost, "HideItem", elapsed, C.GHOST_HIDE_FALLBACK) then
				cine.phase = "ghost_hide_settle"
				cine.t0 = Game():GetFrameCount()
			end
		elseif cine.phase == "ghost_hide_settle" then
			if elapsed >= C.GHOST_HIDE_SETTLE then
				cine.phase = "ghost_walk_door"
				cine.t0 = Game():GetFrameCount()
				RM.begin_ghost_walk_to_door(cine)
			end
		elseif cine.phase == "ghost_walk_door" then
			local ghost = cine.ghost
			local target = cine.door_target
			if ghost and ghost:Exists() and target then
				local pos = ghost.Position
				local walk_from = cine.ghost_walk_origin or pos
				if (pos - walk_from):Length() >= C.GHOST_WISP_FALL_DIST then
					RM.trigger_return_ghost_wisp_fall(cine)
				end
				local delta = target - pos
				local dist = delta:Length()
				local door = cine.door_entry and cine.door_entry.door
				RM.try_unlock_ghost_door(cine, door, dist)
				if dist > C.GHOST_DOOR_REACH then
					local step = math.min(C.GHOST_WALK_SPEED, dist)
					local dir = delta:Normalized()
					local step_vec = dir * step
					ghost.Position = pos + step_vec
					ghost.Velocity = dir * C.GHOST_WALK_SPEED
					local anim = RM.walk_anim_for_delta(delta)
					if cine.ghost_walk_anim ~= anim then
						cine.ghost_walk_anim = anim
						cine.ghost_anim_cache = {}
					end
					RM.ghost_apply_walk_facing(ghost, cine.ghost_walk_anim)
					cine.ghost_anim_cache = RM.ghost_set_anim(ghost, cine.ghost_walk_anim, cine.ghost_anim_cache)
					cine.ghost_anim_cache = RM.ghost_sync_walk_head_overlay(ghost, cine.ghost_walk_anim, cine.ghost_anim_cache)
				else
					ghost.Velocity = Vector.Zero
					cine.phase = "ghost_fade_out"
					cine.t0 = Game():GetFrameCount()
				end
			else
				cine.phase = "ghost_fade_out"
				cine.t0 = Game():GetFrameCount()
			end
		elseif cine.phase == "ghost_fade_out" then
			RM.trigger_return_ghost_wisp_fall(cine)
			local ghost = cine.ghost
			if ghost and ghost:Exists() then
				local t = math.min(1, elapsed / C.GHOST_FADE_DUR)
				local alpha = 1 - t
				ghost:GetSprite().Color = Color(1, 1, 1, alpha)
				if elapsed >= C.GHOST_FADE_DUR then
					RM.clear_ghost_walk_costumes(ghost)
					RM.hide_ghost_held_sprite(ghost)
					ghost:Remove()
					cine.ghost = nil
					local snap = {
						channel = cine.channel,
						channel_index = cine.channel_index,
						appearance = cine.appearance,
						portal = cine.portal,
						portal_pos = cine.portal_pos,
					}
					RM.begin_portal_screen_transition(cine, "enter", function()
						RM.finish_return_travel({
							channel = snap.channel,
							channel_index = snap.channel_index,
							appearance = snap.appearance,
						})
					end)
				end
			else
				local snap = {
					channel = cine.channel,
					channel_index = cine.channel_index,
					appearance = cine.appearance,
					portal = cine.portal,
					portal_pos = cine.portal_pos,
				}
				RM.begin_portal_screen_transition(cine, "enter", function()
					RM.finish_return_travel({
						channel = snap.channel,
						channel_index = snap.channel_index,
						appearance = snap.appearance,
					})
				end)
			end
		end
	end
end

function RM.travel_to_selected()
	local panel = item.panel
	if not panel then return end
	local target = item.floor_targets[panel.index]
	local player, slot = panel.player, panel.slot
	if not target then
		return
	end

	local from = RM.capture_current_floor()
	local to = RM.parse_command(target.command)
	if not to then
		RM.close_panel()
		return
	end
	-- 同层不消耗、不建渠道
	if from.stage == to.stage and from.stage_type == to.stage_type then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1, false, 0, 2)
		return
	end
	if item.cinematic then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1, false, 0, 2)
		return
	end

	RM.close_panel()
	if player and player:Exists() then
		player:SetActiveCharge(0, slot)
	end
	RM.begin_outbound_cinematic(player, slot, from, to, target)
end

function RM.arm_channel_after_outbound(index, ch, keep_skip_arrive)
	if not ch or not index then return end
	if keep_skip_arrive then
		ch.skip_arrive_once = true
	else
		ch.skip_arrive_once = nil
	end
	ch.armed = true
	ch.returning = nil
	RM.update_channel_at(index, ch)
	-- after_outbound 在 outbound_emerge 跳出结束后再调，避免双触发
end

function RM.consume_outbound_arrival(index, ch, fx_app)
	ch.outbound_pending = ch.outbound_pending or {}
	local passenger
	if #ch.outbound_pending > 0 then
		passenger = table.remove(ch.outbound_pending, 1)
	end
	local app = fx_app or (passenger and passenger.appearance) or ch.appearance
	if not app then return nil end
	ch.return_pending = ch.return_pending or {}
	ch.return_pending[#ch.return_pending + 1] = {
		appearance = app,
		opened_run_id = (passenger and passenger.opened_run_id) or ch.opened_run_id,
		remaster_wisp = passenger and passenger.remaster_wisp or nil,
		belial_stats = passenger and passenger.belial_stats or nil,
	}
	local head = ch.return_pending[1]
	if head then
		ch.appearance = head.appearance
		ch.opened_run_id = head.opened_run_id
	end
	local more_outbound = type(ch.outbound_pending) == "table" and #ch.outbound_pending > 0
	RM.arm_channel_after_outbound(index, ch, more_outbound)
	return app
end

function RM.try_trigger_return_channel()
	local list = item.get_channels()
	if #list == 0 then return end

	-- 续关：只补齐武装状态，不立刻回传
	if item._suppress_return then
		item._suppress_return = false
		for i, ch in ipairs(list) do
			ch.from = RM.sanitize_floor_info(ch.from) or ch.from
			ch.to = RM.sanitize_floor_info(ch.to) or ch.to
			if ch.skip_arrive_once and RM.floor_equals(ch.to) then
				RM.consume_outbound_arrival(i, ch, nil)
			elseif ch.armed or ch.skip_arrive_once then
				RM.update_channel_at(i, ch)
			end
		end
		return
	end

	-- 回传抵达原层：portal 反向 zoom 后抛出玩家（不举道具）
	local force_ret = item._force_return_emerge
	if force_ret then
		item._force_return_emerge = nil
		RM.begin_return_emerge(Game():GetPlayer(0), force_ret.appearance, force_ret.synergy)
		return
	end
	local peek = item._pending_fx or save.elses[C.PENDING_FX_KEY]
	if type(peek) == "table" and peek.kind == "return_emerge" then
		RM.begin_return_emerge(Game():GetPlayer(0), peek.appearance, {
			remaster_wisp = peek.remaster_wisp,
			belial_stats = peek.belial_stats,
		})
		return
	end

	-- 出发抵达 B：武装渠道，并播跳出演出（无论 pending 是否还在，都必须现身）
	for i, ch in ipairs(list) do
		ch.from = RM.sanitize_floor_info(ch.from) or ch.from
		ch.to = RM.sanitize_floor_info(ch.to) or ch.to
		if RM.floor_equals(ch.to) and ch.skip_arrive_once then
			local pending = RM.take_pending_fx()
			local fx_app = pending and pending.appearance
			local app = RM.consume_outbound_arrival(i, ch, fx_app)
			if app then
				RM.begin_outbound_emerge(Game():GetPlayer(0), app)
			end
			return
		end
	end

	local hit_index, hit = nil, nil
	for i, ch in ipairs(list) do
		ch.from = RM.sanitize_floor_info(ch.from) or ch.from
		ch.to = RM.sanitize_floor_info(ch.to) or ch.to
		if RM.floor_equals(ch.to) and ch.armed and not ch.returning and not RM.channel_blocks_return_this_run(ch) then
			hit_index, hit = i, ch
			break
		end
	end
	if not hit_index or not hit then
		-- 仅消费 pending / force emerge（无渠道武装场景）
		local pending = RM.take_pending_fx()
		local force = item._force_emerge
		item._force_emerge = nil
		if (pending and pending.kind == "outbound_emerge") or force then
			RM.begin_outbound_emerge(Game():GetPlayer(0), (pending and pending.appearance) or (force and force.appearance))
		end
		return
	end

	if RM.remaster_return_blocked() then
		return
	end

	RM.begin_return_cinematic(Game():GetPlayer(0), hit_index, hit)
end

-- ---------- 面板 UI（Tptron 背景 + icon 槽位八字） ----------
do
local TPTRON_ANM2 = "gfx/mimics/Remaster/Tptron.anm2"
local TPTRON_LAYER_MAIN = 0
local TPTRON_LAYER_ICON = 1
local TPTRON_LAYER_COVER = 2
local OPEN_RISE_DUR = 14
local OPEN_RISE_DISTANCE = 96

local panel_font
local code_font = A2ZFont.new()
local tptron_sprite
local icon_slot_cache -- [1..8] = Vector relative to sprite pivot

function RM.get_font()
	if not panel_font then
		panel_font = Font()
		panel_font:Load("font/cjk/lanapixel.fnt")
	end
	return panel_font
end

function RM.ensure_tptron_sprite()
	if tptron_sprite then return tptron_sprite end
	tptron_sprite = Sprite()
	tptron_sprite:Load(TPTRON_ANM2, true)
	tptron_sprite:Play("Idle", true)
	tptron_sprite:SetFrame("Idle", 0)
	return tptron_sprite
end

--- Idle 动画 icon 层 8 帧的相对位置（相对 Tptron 渲染原点/pivot）
local ICON_SLOT_FALLBACK = {
	{-105, 10}, {-74, 10}, {-40, 8}, {-8, 5},
	{22, 2}, {52, -1}, {78, -1}, {103, -3},
}

function RM.get_icon_slot_offsets()
	if icon_slot_cache then return icon_slot_cache end
	local spr = RM.ensure_tptron_sprite()
	local slots = {}
	for i = 0, 7 do
		local fb = ICON_SLOT_FALLBACK[i + 1]
		local pos = Vector(fb[1], fb[2])
		spr:SetFrame("Idle", i)
		if spr.GetLayerFrameData then
			local ok, frame = pcall(function() return spr:GetLayerFrameData(TPTRON_LAYER_ICON) end)
			if ok and frame and frame.GetPos then
				local p = frame:GetPos()
				if p then pos = p end
			end
		end
		slots[i + 1] = pos
	end
	spr:SetFrame("Idle", 0)
	icon_slot_cache = slots
	return slots
end

local flip_options_mod
function RM.get_remaster_debug_number(key, default)
	if flip_options_mod == nil then
		local ok, options = pcall(require, "Qing_Remaster_scripts.callbacks.rgon_imgui_options_holder")
		flip_options_mod = (ok and options) or false
	end
	if flip_options_mod and flip_options_mod.get_value then
		local v = tonumber(flip_options_mod.get_value({"QingRemasterOptions", "Debug", key}))
		if v ~= nil then return v end
	end
	return default
end

function RM.get_flip_spacing()
	local v = RM.get_remaster_debug_number("RemasterCodeFlipSpacing", 4)
	if v and v > 0 then return v end
	return 4
end

function RM.get_panel_offset()
	return Vector(
		RM.get_remaster_debug_number("RemasterPanelOffsetX", 0),
		RM.get_remaster_debug_number("RemasterPanelOffsetY", 40)
	)
end

function RM.panel_origin(panel, sw, sh)
	local open_t = 1
	if panel and panel.opened_frame then
		local dur = math.max(1, OPEN_RISE_DUR)
		open_t = (Game():GetFrameCount() - panel.opened_frame) / dur
		if open_t < 0 then open_t = 0 elseif open_t > 1 then open_t = 1 end
	end
	local rise_ease = 1 - (1 - open_t) ^ 3
	local ui_rise = (1 - rise_ease) * OPEN_RISE_DISTANCE
	local ui_alpha = (open_t < 0.55) and (open_t / 0.55) or 1
	local offset = RM.get_panel_offset()
	return Vector(sw * 0.5 + offset.X, sh * 0.42 + ui_rise + offset.Y), ui_alpha, open_t
end

function RM.close_panel()
	local panel = item.panel
	if panel and panel.player and panel.player:Exists() and panel.player:IsHoldingItem() then
		panel.player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
	end
	item.panel = nil
end

function RM.open_panel(player, slot)
	local saved_index = tonumber(save.elses[C.SELECTION_KEY])
	if not saved_index or saved_index < 1 or saved_index > #item.floor_targets then saved_index = nil end
	item.panel = {
		player = player,
		slot = slot or ActiveSlot.SLOT_PRIMARY,
		index = saved_index,
		input_armed = false,
		transition = nil,
		display_code = saved_index and item.floor_targets[saved_index].code or "REMASTER",
		opened_frame = Game():GetFrameCount(),
	}
	player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
	RM.ensure_tptron_sprite()
	RM.get_icon_slot_offsets()
end

-- Menu input must not be tied to the player entity that opened the panel.
function RM.is_action_triggered(action)
	for controller = 0, 7 do
		if Input.IsActionTriggered(action, controller) then return true end
	end
	return false
end

function RM.is_action_pressed(action)
	for controller = 0, 7 do
		if Input.IsActionPressed(action, controller) then return true end
	end
	return false
end

function RM.menu_input_is_pressed()
	return RM.is_action_pressed(ButtonAction.ACTION_MENUUP)
		or RM.is_action_pressed(ButtonAction.ACTION_MENUDOWN)
		or RM.is_action_pressed(ButtonAction.ACTION_MENULEFT)
		or RM.is_action_pressed(ButtonAction.ACTION_MENURIGHT)
		or RM.is_action_pressed(ButtonAction.ACTION_MENUCONFIRM)
		or Input.IsButtonPressed(Keyboard.KEY_LEFT_CONTROL, 0)
		or Input.IsButtonPressed(Keyboard.KEY_RIGHT_CONTROL, 0)
end

function RM.ctrl_cancel_triggered()
	return Input.IsButtonTriggered(Keyboard.KEY_LEFT_CONTROL, 0)
		or Input.IsButtonTriggered(Keyboard.KEY_RIGHT_CONTROL, 0)
end

function RM.alphabet_index(char)
	if type(char) ~= "string" or #char ~= 1 then return nil end
	local b = string.byte(char)
	if b >= 65 and b <= 90 then return b - 64 end
	if b >= 97 and b <= 122 then return b - 96 end
	return nil
end

--- B→D => {B,C,D}；C→B => {C,B}。非字母则直接两帧对切。
function RM.build_flip_path(from_char, to_char)
	from_char = tostring(from_char or " ")
	to_char = tostring(to_char or " ")
	if from_char == to_char then return {from_char}, 0 end
	local fi, ti = RM.alphabet_index(from_char), RM.alphabet_index(to_char)
	if not fi or not ti then
		return {from_char, to_char}, (string.byte(to_char) or 0) >= (string.byte(from_char) or 0) and 1 or -1
	end
	local path = {}
	local step = ti >= fi and 1 or -1
	for i = fi, ti, step do
		path[#path + 1] = string.char(64 + i)
	end
	return path, step
end

--- 路径越靠中间的字母步切换越快；spacing 越大整体越慢。
function RM.segment_duration(seg_index, seg_count, spacing)
	spacing = math.max(0.5, tonumber(spacing) or 4)
	local base = 0.028 * spacing
	if seg_count <= 1 then return base end
	local t = (seg_index - 0.5) / seg_count
	local mid = 1 - 4 * (t - 0.5) * (t - 0.5) -- 端点0、中央1
	return base * (1 - 0.55 * mid)
end

function RM.begin_code_transition(panel, old_code, new_code)
	old_code = tostring(old_code or "REMASTER")
	new_code = tostring(new_code or "REMASTER")
	if old_code == new_code then
		panel.display_code = new_code
		panel.transition = nil
		return
	end
	local slots = {}
	local any = false
	for i = 1, 8 do
		local a = string.sub(old_code, i, i)
		local b = string.sub(new_code, i, i)
		if a == "" then a = "-" end
		if b == "" then b = "-" end
		if a ~= b then
			local path, dir = RM.build_flip_path(a, b)
			slots[i] = {
				path = path,
				dir = dir >= 0 and 1 or -1,
				segment = 1,
				progress = 0,
			}
			any = true
		end
	end
	panel.display_code = new_code
	if any then
		panel.transition = {
			slots = slots,
			final_code = new_code,
			last_time = ((Isaac.GetTime and Isaac.GetTime()) or 0) / 1000,
		}
	else
		panel.transition = nil
	end
end

function RM.change_selection(delta)
	local panel = item.panel
	if panel then
		local old_code = panel.display_code or "REMASTER"
		if panel.transition and panel.transition.final_code then
			old_code = panel.transition.final_code
		end
		if not panel.index then
			panel.index = delta < 0 and #item.floor_targets or 1
		else
			panel.index = ((panel.index - 1 + delta) % #item.floor_targets) + 1
		end
		local new = item.floor_targets[panel.index]
		if new then
			RM.begin_code_transition(panel, old_code, new.code)
		end
		save.elses[C.SELECTION_KEY] = panel.index
	end
end

function RM.render_code_char_at(char, screen_pos, alpha, scale_y)
	if not char or alpha <= 0 or not screen_pos then return end
	local frame, _, _, source = code_font:glyph_metrics(char, 0)
	if not frame then return end
	local glyph = {
		char = char, frame = frame,
		x = screen_pos.X,
		y = screen_pos.Y,
		edge_layer = source and source.edge_layer or 0,
		glyph_layer = source and source.glyph_layer or 1,
	}
	local color = Color(1, 0.85, 0.35, alpha)
	local edge = Color(1, 1, 1, alpha, 0.32, 0.22, 0.04)
	local scale = Vector(1, math.max(0.05, scale_y or 1))
	code_font:render({glyph},
		function(g) return Vector(g.x, g.y) end,
		function() return edge, scale end,
		function() return color, scale end
	)
end

function RM.slot_screen_pos(origin, slot_index)
	local slots = RM.get_icon_slot_offsets()
	local off = slots[slot_index] or Vector(0, 0)
	return origin + off
end

--- 切换翻字：目的地暂时留在 icon 槽位原地，仅旧字做位移淡出。
function RM.render_selected_code(panel, selected, origin, alpha)
	alpha = alpha or 1
	local transition = panel.transition
	if not transition then
		local code = panel.display_code or (selected and selected.code) or "REMASTER"
		for i = 1, 8 do
			local ch = string.sub(code, i, i)
			if ch == "" then ch = "-" end
			RM.render_code_char_at(ch, RM.slot_screen_pos(origin, i), alpha, 1)
		end
		return
	end
	local now = ((Isaac.GetTime and Isaac.GetTime()) or 0) / 1000
	local dt = math.max(0, math.min(0.05, now - (transition.last_time or now)))
	transition.last_time = now
	local spacing = RM.get_flip_spacing()
	local travel = 18
	local all_done = true
	local final_code = transition.final_code or panel.display_code or "REMASTER"

	for i = 1, 8 do
		local base = RM.slot_screen_pos(origin, i)
		local slot = transition.slots[i]
		local settled = string.sub(final_code, i, i)
		if settled == "" then settled = "-" end
		if not slot then
			RM.render_code_char_at(settled, base, alpha, 1)
		else
			local path = slot.path
			local seg_count = math.max(1, #path - 1)
			if slot.segment > seg_count then
				RM.render_code_char_at(path[#path] or settled, base, alpha, 1)
			else
				all_done = false
				local dur = math.max(0.001, RM.segment_duration(slot.segment, seg_count, spacing))
				local time_acc = (slot.progress or 0) * dur + dt
				while time_acc >= dur and slot.segment <= seg_count do
					time_acc = time_acc - dur
					slot.segment = slot.segment + 1
					if slot.segment <= seg_count then
						dur = math.max(0.001, RM.segment_duration(slot.segment, seg_count, spacing))
					else
						break
					end
				end
				if slot.segment > seg_count then
					slot.progress = 0
					RM.render_code_char_at(path[#path] or settled, base, alpha, 1)
				else
					slot.progress = time_acc / dur
					local p = math.max(0, math.min(1, slot.progress))
					local cur = path[slot.segment]
					local nxt = path[slot.segment + 1]
					local dir = slot.dir >= 0 and 1 or -1
					-- 旧字移出；新字目的地暂时留在槽位原地
					RM.render_code_char_at(cur, base + Vector(0, dir * p * travel), alpha * (1 - p), 1 - p * 0.88)
					RM.render_code_char_at(nxt, base, alpha * p, 0.12 + p * 0.88)
				end
			end
		end
	end
	if all_done then
		panel.display_code = final_code
		panel.transition = nil
	end
end

function RM.render_tptron_panel(panel, selected)
	local spr = RM.ensure_tptron_sprite()
	local sw, sh = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
	local origin, ui_alpha = RM.panel_origin(panel, sw, sh)
	spr:SetFrame("Idle", 0)
	spr.Color = Color(1, 1, 1, ui_alpha)
	spr.Scale = Vector(1, 1)
	spr.Rotation = 0
	-- main → 八字 → cover（icon 层只提供槽位，不绘制占位图）
	spr:RenderLayer(TPTRON_LAYER_MAIN, origin, Vector.Zero, Vector.Zero)
	RM.render_selected_code(panel, selected, origin, ui_alpha)
	spr:RenderLayer(TPTRON_LAYER_COVER, origin, Vector.Zero, Vector.Zero)
	return origin, ui_alpha, sw, sh
end

end -- panel UI scope


table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, _, _, player, use_flags, active_slot)
	if use_flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then return end
	if item.panel or item.cinematic then
		return {Discharge = false, ShowAnim = false}
	end
	RM.open_panel(player, active_slot)
	return {Discharge = false, ShowAnim = false}
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	RM.tick_cinematic()
	local panel = item.panel
	if not panel then
		-- 换层/换房丢弃 panel 后：仍举着则重开；超时则放下
		if item.pending_reopen_until then
			if Game():GetFrameCount() > item.pending_reopen_until then
				item.pending_reopen_until = nil
				for i = 0, Game():GetNumPlayers() - 1 do
					local player = Game():GetPlayer(i)
					if player and player:Exists() and player:HasCollectible(item.entity) and player:IsHoldingItem() then
						player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
					end
				end
			else
				for i = 0, Game():GetNumPlayers() - 1 do
					local player = Game():GetPlayer(i)
					if player and player:Exists() and player:HasCollectible(item.entity) and player:IsHoldingItem() then
						item.pending_reopen_until = nil
						RM.open_panel(player, ActiveSlot.SLOT_PRIMARY)
						break
					end
				end
			end
		end
		return
	end
	local player = panel.player
	if not player or not player:Exists() then
		RM.close_panel()
		return
	end
	player.ControlsCooldown = math.max(player.ControlsCooldown, 2)
	if not player:IsHoldingItem() then
		player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
		RM.play_remaster_lift_sfx()
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = PORTAL_EFFECT_VAR,
Function = function(_, ent)
	if not ent then return end
	local d = ent:GetData()
	if d[item.own_key.."portal"] then
		RM.portal_tick(ent)
	end
	local Ghost = require("Qing_Remaster_scripts.others.player_appearance_ghost")
	if d[item.own_key.."ghost"] or Ghost.is_ghost(ent) then
		RM.tick_ghost_walk_costume_sprites(ent)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_, name)
	if name ~= C.PORTAL_SHADER then return end
	if auxi.shader_effect_idle() or auxi.is_pause_menu_open() then
		return {P1 = {0, 0, 0, 0}, P2 = {0, 0, 0, 0}}
	end
	return RM.portal_shader_params_from_cine(item.cinematic)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_EFFECT_RENDER, params = PORTAL_EFFECT_VAR,
Function = function(_, ent, offset)
	local Ghost = require("Qing_Remaster_scripts.others.player_appearance_ghost")
	if not ent or not (ent:GetData()[item.own_key.."ghost"] or Ghost.is_ghost(ent)) then return end
	local cancel = RM.ghost_should_render_walk_composite(ent)
	RM.emit_ghost_probe("pre_render", ent, {pre_cancel = cancel})
	-- PRE 返回 false 会跳过引擎默认绘制，且 POST_EFFECT_RENDER 不再触发；合成须在 PRE 内完成
	if cancel then
		RM.render_ghost_walk_costumes(ent, offset)
		return false
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = PORTAL_EFFECT_VAR,
Function = function(_, ent, offset)
	local Ghost = require("Qing_Remaster_scripts.others.player_appearance_ghost")
	if not ent or not (ent:GetData()[item.own_key.."ghost"] or Ghost.is_ghost(ent)) then return end
	if RM.ghost_should_render_walk_composite(ent) then return end
	if not RM.ghost_has_walk_composite(ent) then
		RM.render_ghost_walk_costumes(ent, offset)
	end
	RM.render_ghost_held_sprite(ent, offset)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = FamiliarVariant.WISP,
Function = function(_, ent)
	if not ent then return end
	local player = ent.Player
	if not player then return end
	local pending = player:GetData()[NEXT_CHANNEL_WISP_KEY]
	if type(pending) ~= "table" then return end
	ent:GetData()[CHANNEL_WISP_KEY] = true
	RM.prep_channel_wisp(ent, pending)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_FAMILIAR_UPDATE, params = FamiliarVariant.WISP,
Function = function(_, ent)
	if not ent or not ent:GetData()[CHANNEL_WISP_KEY] then return end
	if RM.tick_channel_wisp_flight(ent) then
		return true
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	local panel = item.panel
	if not panel then return end
	if not panel.input_armed then
		if not RM.menu_input_is_pressed() then panel.input_armed = true end
	else
		if RM.is_action_triggered(ButtonAction.ACTION_MENUUP) then RM.change_selection(-1) end
		if RM.is_action_triggered(ButtonAction.ACTION_MENUDOWN) then RM.change_selection(1) end
		if RM.is_action_triggered(ButtonAction.ACTION_MENULEFT) then RM.change_selection(-5) end
		if RM.is_action_triggered(ButtonAction.ACTION_MENURIGHT) then RM.change_selection(5) end
		if RM.is_action_triggered(ButtonAction.ACTION_MENUCONFIRM) then
			RM.travel_to_selected()
		elseif RM.ctrl_cancel_triggered() then
			RM.close_panel()
		end
	end
	panel = item.panel
	if not panel then return end
	local font = RM.get_font()
	local selected = item.floor_targets[panel.index]
	local _, ui_alpha, sw, sh = RM.render_tptron_panel(panel, selected)
	local tip_a = ui_alpha or 1
	local first = panel.index and math.max(1, math.min(math.max(1, #item.floor_targets - 6), panel.index - 3)) or 1
	for index = first, math.min(#item.floor_targets, first + 6) do
		local target = item.floor_targets[index]
		local selected_row = index == panel.index
		local color = selected_row and KColor(1, 0.85, 0.35, tip_a) or KColor(0.65, 0.65, 0.65, tip_a * 0.85)
		font:DrawStringUTF8((selected_row and "> " or "  ")..target.code.."  "..target.name, sw * 0.22, sh * 0.76 + (index - first) * 11, color, sw * 0.7, false)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	-- 与蓝图相同：禁止碰旧 panel.player；仍举着则由 POST_UPDATE 重开
	-- NEW_LEVEL 与 NEW_ROOM 常成对触发：只在当时仍有 panel 时置 pending，勿清掉另一回调已设的标记
	if item.panel then
		item.panel = nil
		item.pending_reopen_until = Game():GetFrameCount() + 8
	end
	-- 换层后 NEW_ROOM：补接 emerge（防 NEW_LEVEL 时序漏接）
	if item._force_return_emerge and not item.cinematic then
		local snap = item._force_return_emerge
		item._force_return_emerge = nil
		RM.begin_return_emerge(Game():GetPlayer(0), snap.appearance, snap.synergy)
	elseif item._force_emerge and not item.cinematic then
		local app = item._force_emerge.appearance
		item._force_emerge = nil
		RM.take_pending_fx()
		RM.begin_outbound_emerge(Game():GetPlayer(0), app)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	RM.try_clear_descent_lock_on_level_change()
	local boost = save.elses[C.BELIAL_LAYER_KEY]
	if type(boost) == "table" then
		local level = Game():GetLevel()
		if level:GetStage() ~= boost.stage or level:GetStageType() ~= boost.stage_type then
			save.elses[C.BELIAL_LAYER_KEY] = nil
		end
	end
	-- 新层边界只丢弃 Lua 缓存，禁止调用旧 panel.player 的原生方法。
	if item.panel then
		item.panel = nil
		item.pending_reopen_until = Game():GetFrameCount() + 8
	end
	if item.cinematic and item.cinematic.kind ~= "outbound_emerge"
		and item.cinematic.kind ~= "return_emerge"
		and item.cinematic.kind ~= "return" then
		clear_cinematic({clear_pending = false, fallback_visible = true})
	end
	RM.restore_party_familiars()
	local cine = item.cinematic
	if not cine or (cine.kind ~= "outbound_emerge" and cine.kind ~= "return_emerge" and cine.kind ~= "return") then
		local p = Game():GetPlayer(0)
		if p and p:Exists() then
			RM.restore_party_player(p, true)
			if p.Visible == false then p.Visible = true end
			RM.unfreeze_cinematic_player(p)
		end
	end
	RM.try_trigger_return_channel()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_)
	if not item.cinematic then
		RM.restore_cinematic_party_visibility(true)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	if not player or not player:Exists() then return end
	RM.apply_belial_layer_cache(player, cacheFlag)
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	item.panel = nil
	item.pending_reopen_until = nil
	clear_cinematic({clear_pending = true, fallback_visible = true})
	if not continue then
		RM.reset_current_run_id()
		RM.clear_descent_lock()
	else
		RM.get_current_run_id()
	end
	if continue then
		item._suppress_return = true
	else
		item._suppress_return = false
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_)
	item.panel = nil
	item.pending_reopen_until = nil
	clear_cinematic({clear_pending = true, fallback_visible = true})
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_END, params = nil,
Function = function(_)
	item.panel = nil
	item.pending_reopen_until = nil
	clear_cinematic({clear_pending = true, fallback_visible = true})
end,
})

do
	local Ghost = require("Qing_Remaster_scripts.others.player_appearance_ghost")
	Ghost.bind({
		capture = RM.capture_player_appearance,
		sanitize = RM.sanitize_appearance,
		spawn = RM.spawn_appearance_ghost,
		setup_costumes = RM.setup_ghost_walk_costumes,
		clear_costumes = RM.clear_ghost_walk_costumes,
		begin_live_pose_capture = RM.begin_live_pose_capture,
		capture_live_pose = RM.capture_player_composite_pose,
		refresh_live_pose_capture = RM.refresh_live_pose_capture,
		ensure_anim = function(ghost, anim)
			RM.ghost_ensure_anim(ghost, anim, ghost:GetData())
		end,
		clear_overlay = function(ghost)
			RM.ghost_clear_walk_head_overlay(ghost, ghost:GetData())
		end,
		sync_head = function(ghost, anim)
			RM.ghost_sync_walk_head_overlay(ghost, anim, ghost:GetData())
		end,
		body_accepts_directional_head = RM.ghost_body_accepts_directional_head,
		is_directional_head_anim = RM.ghost_is_directional_head_anim,
		directional_head_participates = RM.ghost_directional_head_participates,
		get_probe_snapshot = RM.get_ghost_probe_snapshot,
		ensure_held = RM.ensure_ghost_held_sprite,
		hide_held = RM.hide_ghost_held_sprite,
		get_held_info = RM.get_ghost_held_info,
		sync_held = RM.sync_ghost_held_visual,
		anim_done = RM.ghost_anim_done,
	})
end

return item

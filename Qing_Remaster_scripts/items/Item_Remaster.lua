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
	LEGACY_ELSES_KEY = "Item_Remaster_channel",
	SELECTION_KEY = "Item_Remaster_selection",
	PENDING_FX_KEY = "Item_Remaster_pending_fx",
	RUN_ID_KEY = "Item_Remaster_run_id",
	DESCENT_LOCK_KEY = "Item_Remaster_await_descent",
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
}
local PORTAL_EFFECT_VAR = enums.Entities.ID_EFFECT_MeusNIL
local GHOST_HELD_SPR_KEY = item.own_key.."held_spr"
local GHOST_HELD_VISIBLE_KEY = item.own_key.."held_visible"
local GHOST_COSTUME_SPRS_KEY = item.own_key.."walk_costume_sprs"
local GHOST_COSTUME_WINNERS_KEY = item.own_key.."costume_winners"
local GHOST_COSTUME_DRIVER_KEY = item.own_key.."costume_driver_key"
local GHOST_CAN_FLY_KEY = item.own_key.."can_fly"

local function psl_index_to_key(idx)
	idx = tonumber(idx)
	if idx == nil then return nil end
	return C.PSL_LAYER_KEYS[idx + 1]
end

local function sprite_is_usable(spr)
	if not spr then return false end
	local ok_n, n = pcall(function() return spr:GetLayerCount() end)
	return ok_n and type(n) == "number" and n > 0
end

local function sprite_layer_usable(spr, layer_id)
	if not sprite_is_usable(spr) then return false end
	layer_id = tonumber(layer_id)
	if not layer_id or layer_id < 0 then return false end
	local ok_n, n = pcall(function() return spr:GetLayerCount() end)
	return ok_n and type(n) == "number" and layer_id < n
end

--- 行走段有衣装层槽表时，PRE 取消实体默认绘制，POST 按槽完整合成
local function ghost_count_drawable_slots(ghost)
	if not ghost then return 0 end
	local winners = ghost:GetData()[GHOST_COSTUME_WINNERS_KEY]
	if type(winners) ~= "table" then return 0 end
	local n = 0
	for _, slot in pairs(winners) do
		if slot and slot.spr and sprite_layer_usable(slot.spr, slot.layer_id) then
			n = n + 1
		end
	end
	return n
end

local function ghost_has_walk_composite(ghost)
	if not ghost then return false end
	if not ghost:GetData()[item.own_key.."walk_composite"] then return false end
	return ghost_count_drawable_slots(ghost) > 0
end

local ghost_probe_observer = nil
local ghost_probe_pre_last = {cancel = nil, frame = 0}

function item.set_ghost_probe_observer(fn)
	ghost_probe_observer = type(fn) == "function" and fn or nil
end

local function sprite_layer_snapshot(spr, anim, frame)
	if not spr or not sprite_is_usable(spr) then
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

local function emit_ghost_probe(stage, ghost, extra)
	if not ghost_probe_observer then return end
	extra = type(extra) == "table" and extra or {}
	if stage == "pre_render" then
		local fc = Game():GetFrameCount()
		if extra.pre_cancel == ghost_probe_pre_last.cancel and fc - ghost_probe_pre_last.frame < 12 then
			return
		end
		ghost_probe_pre_last.cancel = extra.pre_cancel
		ghost_probe_pre_last.frame = fc
	end
	extra.stage = stage
	extra.frame = Game():GetFrameCount()
	if ghost and ghost.Exists and ghost:Exists() then
		local gd = ghost:GetData()
		local body = ghost:GetSprite()
		local app = gd[item.own_key.."ghost_app"]
		extra.visible = ghost.Visible and true or false
		extra.pos_x = ghost.Position.X
		extra.pos_y = ghost.Position.Y
		extra.walk_composite = gd[item.own_key.."walk_composite"] and true or false
		extra.drawable_slot_count = ghost_count_drawable_slots(ghost)
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
						key = tostring(k),
						layer_id = slot and slot.layer_id,
						priority = slot and slot.priority,
						from_base = slot and slot.spr == body,
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
			pcall(function() extra.anim = body:GetAnimation() end)
			pcall(function() extra.frame = body:GetFrame() end)
			pcall(function() extra.overlay_anim = body:GetOverlayAnimation() end)
			pcall(function() extra.overlay_frame = body:GetOverlayFrame() end)
			if body.Color then extra.alpha = body.Color.A end
			extra.body = sprite_layer_snapshot(body, extra.anim, extra.frame)
		end
	end
	local cine = item.cinematic
	if cine then
		extra.cine_kind = cine.kind
		extra.cine_phase = cine.phase
		extra.ghost_walk_anim = cine.ghost_walk_anim
	end
	pcall(ghost_probe_observer, extra)
end

--- costumes2 层序：同层仅最高 priority 生效；head* 与 body 分开叠绘

local function get_current_run_id()
	local id = save.elses[C.RUN_ID_KEY]
	if type(id) ~= "string" or id == "" then
		id = tostring(Game():GetSeeds():GetStartSeed()).."_"..tostring(Game():GetFrameCount())
		save.elses[C.RUN_ID_KEY] = id
	end
	return id
end

local function reset_current_run_id()
	save.elses[C.RUN_ID_KEY] = tostring(Game():GetSeeds():GetStartSeed()).."_"..tostring(Game():GetFrameCount())
end

local function costume_layer_key(layer_name)
	if type(layer_name) ~= "string" then return nil end
	local key = string.lower(layer_name)
	if key == "" then return nil end
	return key
end

local function costume_layer_rank(key)
	if not key then return 999 end
	return C.COSTUME_LAYER_RANK[key] or 35
end

local function costume_layer_is_head(key)
	if not key then return false end
	return key:match("^head") ~= nil or key == "skull" or key == "face" or key == "hair" or key == "top0"
end

local function ghost_read_sprite_anim_frame(spr)
	local anim, frame = nil, 0
	if not spr then return anim, frame end
	pcall(function()
		anim = spr:GetAnimation()
		frame = spr:GetFrame()
	end)
	return anim, frame
end

local function ghost_desired_walk_anim(ghost)
	local anim = nil
	if ghost and ghost:Exists() then
		pcall(function() anim = ghost:GetSprite():GetAnimation() end)
	end
	if type(anim) ~= "string" or anim == "" then return "WalkDown" end
	return anim
end

--- 行走合成的主时钟：优先非底模、非头部的 body 衣装层（Az 等可见身体）
local function ghost_pick_body_driver(winners)
	if type(winners) ~= "table" then return nil end
	local best, best_rank = nil, 9999
	for key, slot in pairs(winners) do
		if slot and slot.spr and not slot.from_base and not costume_layer_is_head(key) then
			local rank = costume_layer_rank(key)
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
	for key, slot in pairs(winners) do
		if slot and slot.spr and not slot.from_base and not costume_layer_is_head(key) then
			if not best or (slot.priority or 0) > (best.priority or 0) then
				best = slot
			end
		end
	end
	return best
end

local function ghost_get_costume_driver(ghost, winners)
	winners = winners or (ghost and ghost:GetData()[GHOST_COSTUME_WINNERS_KEY])
	if type(winners) ~= "table" then return nil end
	local gd = ghost and ghost:GetData()
	local driver_key = gd and gd[GHOST_COSTUME_DRIVER_KEY]
	if type(driver_key) == "string" and winners[driver_key] then
		local slot = winners[driver_key]
		if slot and slot.spr and not slot.from_base then return slot end
	end
	local picked = ghost_pick_body_driver(winners)
	if picked and gd then gd[GHOST_COSTUME_DRIVER_KEY] = picked.key end
	return picked
end

--- Load 失败或 anm2/贴图缺失时返回 false，不向外抛错
local function try_sprite_load(spr, path)
	if not spr or type(path) ~= "string" or path == "" then return false end
	local ok = pcall(function() spr:Load(path, true) end)
	return ok and sprite_is_usable(spr)
end

local function display_code(code)
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

local function add(code, name, command, seed_stage)
	assert(#code == 8, "Remaster floor code must contain exactly 8 characters: "..code)
	table.insert(item.floor_targets, {
		code = display_code(code),
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
			add(variant[1]..floor_number, variant[2]..(floor_number == 1 and " I" or " II"), tostring(stage)..variant[3], stage)
		end
	end
end

add("BLUEWOMB", "Blue Womb", "9", 9)
add("SHEOL---", "Sheol", "10", 10)
add("CATHEDRL", "Cathedral", "10a", 10)
add("DARKROOM", "Dark Room", "11", 11)
add("CHEST---", "Chest", "11a", 11)
add("VOID----", "Void", "12", 12)
add("HOME----", "Home", "13", 13)

-- ---------- 楼层身份 / 渠道 ----------
local function stage_type_suffix(stage_type)
	if stage_type == StageType.STAGETYPE_WOTL then return "a" end
	if stage_type == StageType.STAGETYPE_AFTERBIRTH then return "b" end
	if stage_type == StageType.STAGETYPE_REPENTANCE then return "c" end
	if stage_type == StageType.STAGETYPE_REPENTANCE_B then return "d" end
	return ""
end

local function suffix_to_stage_type(suffix)
	if suffix == "a" then return StageType.STAGETYPE_WOTL end
	if suffix == "b" then return StageType.STAGETYPE_AFTERBIRTH end
	if suffix == "c" then return StageType.STAGETYPE_REPENTANCE end
	if suffix == "d" then return StageType.STAGETYPE_REPENTANCE_B end
	return StageType.STAGETYPE_ORIGINAL
end

local function parse_command(command)
	command = tostring(command or "")
	local stage_s, suffix = command:match("^(%d+)([abcd]?)$")
	local stage = tonumber(stage_s)
	if not stage then return nil end
	return {
		stage = stage,
		stage_type = suffix_to_stage_type(suffix or ""),
		command = command,
		seed_stage = stage,
	}
end

--- 楼层信息压成纯表，避免枚举 userdata 进 RUN.ELSES 后无法续关还原
local function sanitize_floor_info(info)
	if type(info) ~= "table" then return nil end
	return {
		stage = tonumber(info.stage),
		stage_type = tonumber(info.stage_type) or 0,
		command = tostring(info.command or ""),
		seed_stage = tonumber(info.seed_stage) or tonumber(info.stage),
	}
end

--- 演出够用：角色底模 + 肤色 + 体型 + 衣装（RGON GetCostumeLayerMap 精确层绑定）
local function capture_costume_layer_bindings(player, descs)
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

local function sprite_read(spr, fn)
	if not spr or type(fn) ~= "function" then return nil end
	local v = nil
	pcall(function() v = fn(spr) end)
	return v
end

local function ghost_render_sprite_overlay_only(spr, screen, sc, flip_x, tint, alpha)
	if not spr or not sprite_is_usable(spr) then return false end
	local overlay_anim = sprite_read(spr, function(s) return s:GetOverlayAnimation() end)
	if type(overlay_anim) ~= "string" or overlay_anim == "" then return false end
	local saved = {}
	local n = tonumber(sprite_read(spr, function(s) return s:GetLayerCount() end)) or 0
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

local function ghost_render_fallback_full_body(ghost, body, screen, sc, tint, alpha)
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

local function capture_player_appearance(player)
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
	local costume_layers = capture_costume_layer_bindings(player, descs)
	emit_ghost_probe("capture_appearance", nil, {
		player_type = tonumber(player:GetPlayerType()) or 0,
		can_fly = player.CanFly and true or false,
		base_anm2 = sprite_read(spr, function(s) return s:GetFilename() end),
		costume_count = #costumes,
		costume_layer_count = type(costume_layers) == "table" and #costume_layers or 0,
		body_anim = sprite_read(spr, function(s) return s:GetAnimation() end),
		body_frame = sprite_read(spr, function(s) return s:GetFrame() end),
		overlay_anim = sprite_read(spr, function(s) return s:GetOverlayAnimation() end),
		overlay_frame = sprite_read(spr, function(s) return s:GetOverlayFrame() end),
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

local function sanitize_appearance(app)
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

local function capture_current_floor()
	local level = Game():GetLevel()
	local stage = level:GetStage()
	local stage_type = level:GetStageType()
	local command = tostring(stage)..stage_type_suffix(stage_type)
	return sanitize_floor_info({
		stage = stage,
		stage_type = stage_type,
		command = command,
		seed_stage = stage,
	})
end

local function floor_equals(info)
	if not info then return false end
	local level = Game():GetLevel()
	return level:GetStage() == info.stage and level:GetStageType() == info.stage_type
end

local function level_stage_snapshot()
	local level = Game():GetLevel()
	return {
		stage = level:GetStage(),
		stage_type = level:GetStageType(),
	}
end

local function snapshot_equals(a, b)
	return type(a) == "table" and type(b) == "table"
		and a.stage == b.stage and a.stage_type == b.stage_type
end

--- Remaster 抵达/回传后，须换到任意不同层才允许再次自动回传（不限制主动出发）。
local function remaster_return_blocked()
	local lock = save.elses[C.DESCENT_LOCK_KEY]
	if type(lock) ~= "table" then return false end
	return snapshot_equals(lock, level_stage_snapshot())
end

--- 抵达目标层或回传落地后写入；切换到任意不同层解除，仅挡自动回传。
local function arm_descent_lock()
	save.elses[C.DESCENT_LOCK_KEY] = level_stage_snapshot()
end

local function clear_descent_lock()
	save.elses[C.DESCENT_LOCK_KEY] = nil
end

local function try_clear_descent_lock_on_level_change()
	if item._remaster_level_change then
		item._remaster_level_change = false
		return
	end
	local lock = save.elses[C.DESCENT_LOCK_KEY]
	if type(lock) ~= "table" then return end
	local cur = level_stage_snapshot()
	if not snapshot_equals(cur, lock) then
		clear_descent_lock()
	end
end

local function on_remaster_arrival()
	arm_descent_lock()
end

local function checkpoint_save(reason)
	if save.RuntimeLoaded == true and type(save.SaveModData) == "function" then
		pcall(save.SaveModData, "remaster:"..tostring(reason or "channel"))
	end
end

local function sanitize_passenger_entry(entry)
	if type(entry) ~= "table" then return nil end
	local app = sanitize_appearance(entry.appearance)
	if not app then return nil end
	return {
		appearance = app,
		opened_run_id = type(entry.opened_run_id) == "string" and entry.opened_run_id or nil,
	}
end

local function sanitize_passenger_list(list)
	if type(list) ~= "table" then return {} end
	local out = {}
	for _, entry in ipairs(list) do
		local norm = sanitize_passenger_entry(entry)
		if norm then out[#out + 1] = norm end
	end
	return out
end

local function channel_active_return_passenger(ch)
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

local function passenger_blocks_return_this_run(passenger)
	if not passenger then return false end
	local opened = passenger.opened_run_id
	if type(opened) ~= "string" or opened == "" then return false end
	return opened == get_current_run_id()
end

local function channel_blocks_return_this_run(ch)
	return passenger_blocks_return_this_run(channel_active_return_passenger(ch))
end

local function normalize_channel(ch)
	if type(ch) ~= "table" then return nil end
	local from = sanitize_floor_info(ch.from)
	local to = sanitize_floor_info(ch.to)
	if not from or not to or not from.command or not to.command then return nil end
	if from.command == "" or to.command == "" then return nil end
	local outbound_pending = sanitize_passenger_list(ch.outbound_pending)
	local return_pending = sanitize_passenger_list(ch.return_pending)
	local appearance = sanitize_appearance(ch.appearance)
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

local function channels_bag()
	save.PermanentData = save.PermanentData or {}
	local bag = save.PermanentData[C.PERM_CHANNELS_KEY]
	if type(bag) ~= "table" then
		bag = {list = {}}
		-- 兼容误写入 ELSES 的单渠道旧档
		local legacy = save.elses and save.elses[C.LEGACY_ELSES_KEY]
		if type(legacy) == "table" then
			local norm = normalize_channel(legacy)
			if norm then bag.list[1] = norm end
			save.elses[C.LEGACY_ELSES_KEY] = nil
		end
		save.PermanentData[C.PERM_CHANNELS_KEY] = bag
	end
	if type(bag.list) ~= "table" then bag.list = {} end
	return bag
end

local function get_channels()
	return channels_bag().list
end

local function find_channel_index_by_to(to_command)
	to_command = tostring(to_command or "")
	local list = get_channels()
	for i, ch in ipairs(list) do
		if ch.to and tostring(ch.to.command) == to_command then return i, ch end
	end
	return nil, nil
end

local function find_channel_index_by_route(from_command, to_command)
	from_command = tostring(from_command or "")
	to_command = tostring(to_command or "")
	local list = get_channels()
	for i, ch in ipairs(list) do
		if ch.from and ch.to
			and tostring(ch.from.command) == from_command
			and tostring(ch.to.command) == to_command then
			return i, ch
		end
	end
	return nil, nil
end

local function write_channels(list, reason)
	local bag = channels_bag()
	bag.list = list or {}
	checkpoint_save(reason or "channels")
end

--- 调试/ImGui：按目标楼层（to）去重写入；同 to 覆盖旧渠道。
local function upsert_channel(ch)
	local norm = normalize_channel(ch)
	if not norm then return nil end
	local list = get_channels()
	local idx = find_channel_index_by_to(norm.to.command)
	if idx then
		list[idx] = norm
	else
		list[#list + 1] = norm
		idx = #list
	end
	write_channels(list, norm.armed and "arm" or "set")
	return idx, norm
end

--- 同一路线（from->to）追加出发乘客；支持多次使用并按 FIFO 依次回传。
local function register_outbound_passenger(from, to, target, appearance, opened_run_id)
	local passenger = sanitize_passenger_entry({
		appearance = appearance,
		opened_run_id = opened_run_id,
	})
	if not passenger then return nil end
	local list = get_channels()
	local idx = find_channel_index_by_route(from.command, to.command)
	if idx then
		local ch = list[idx]
		ch.outbound_pending = ch.outbound_pending or {}
		ch.outbound_pending[#ch.outbound_pending + 1] = passenger
		ch.skip_arrive_once = true
		if target then
			if target.code then ch.target_code = tostring(target.code) end
			if target.name then ch.target_name = tostring(target.name) end
		end
		local norm = normalize_channel(ch)
		if not norm then return nil end
		list[idx] = norm
		write_channels(list, "outbound_append")
		return idx, norm
	end
	local norm = normalize_channel({
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
	write_channels(list, "outbound_new")
	return #list, norm
end

local function update_channel_at(index, ch)
	local list = get_channels()
	local norm = normalize_channel(ch)
	if not index or not list[index] or not norm then return false end
	list[index] = norm
	write_channels(list, "update")
	return true
end

local function remove_channel_at(index)
	local list = get_channels()
	index = tonumber(index)
	if not index or not list[index] then return false end
	table.remove(list, index)
	write_channels(list, "remove")
	return true
end

local function clear_all_channels()
	write_channels({}, "clear_all")
end

local function format_channel_label(ch, index)
	if not ch or not ch.from or not ch.to then return tostring(index or "?")..": <invalid>" end
	local state = ch.returning and "RETURNING" or (ch.skip_arrive_once and "OUTBOUND") or (ch.armed and "ARMED") or "IDLE"
	if channel_blocks_return_this_run(ch) then
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

function item.get_channels()
	return get_channels()
end

function item.format_channel_label(ch, index)
	return format_channel_label(ch, index)
end

function item.clear_all_channels()
	clear_all_channels()
	return true
end

function item.remove_channel_at(index)
	return remove_channel_at(index)
end

--- 调试/ImGui：用 stage 命令串添加永久渠道（默认已武装，便于立刻测回传）
function item.debug_add_channel(from_command, to_command, opts)
	opts = opts or {}
	local from = sanitize_floor_info(parse_command(from_command))
	local to = sanitize_floor_info(parse_command(to_command))
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
	local idx, norm = upsert_channel({
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
	local cur = capture_current_floor()
	return cur and cur.command or nil
end

--- 执行 stage 跳转；seed_stage 可选（用于重掷该层种子）
local function execute_stage_travel(floor_info, opts)
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

local function set_pending_fx(payload)
	-- 内存备份：stage 跳转时 ELSES 偶发未及时带上
	item._pending_fx = payload
	save.elses[C.PENDING_FX_KEY] = payload
end

local function take_pending_fx()
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

local function revert_channel_returning_state(cine)
	if not cine or cine.kind ~= "return" then return end
	local idx = cine.channel_index
	local ch = cine.channel
	if not idx or type(ch) ~= "table" or not ch.returning then return end
	ch.returning = nil
	update_channel_at(idx, ch)
end

--- 演出隐身：直接写 Entity.Visible，不用 Attribute_holder
local function hide_party_for_cinematic(player, opts)
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
					local ptr = GetPtrHash(ent)
					st.familiars[ptr] = ent.Visible ~= false
					ent.Visible = false
				end
			end
		end
	end
	item._party_hide = st
end

local function restore_party_familiars()
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

local function restore_party_player(player, force)
	local st = item._party_hide
	if not st then return end
	if force or not st.player_keep_hidden then
		if player and player:Exists() and st.player_was_visible ~= nil then
			player.Visible = st.player_was_visible
		end
		item._party_hide = nil
	end
end

local function unfreeze_cinematic_player(player)
	if not player or not player:Exists() then return end
	player.Velocity = Vector.Zero
	pcall(function() player:StopExtraAnimation() end)
end

local function restore_cinematic_party_visibility(fallback_visible)
	fallback_visible = fallback_visible ~= false
	restore_party_familiars()
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
				unfreeze_cinematic_player(p)
			end
		end
		item._party_hide = nil
	elseif fallback_visible then
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and p:Exists() then
				p.Visible = true
				unfreeze_cinematic_player(p)
			end
		end
	end
end

local function set_player_hidden(player, hidden)
	if not player or not player:Exists() then return end
	player.Visible = not hidden
end

local function freeze_player(player, on)
	if not player or not player:Exists() then return end
	if on then
		player.ControlsCooldown = math.max(player.ControlsCooldown, 8)
		player.Velocity = Vector.Zero
	end
end

--- 演出门：出发用玩家身边；抵达/回传用房间中心
local function pick_portal_pos(near_player)
	if near_player and near_player:Exists() then
		return Vector(near_player.Position.X, near_player.Position.Y)
	end
	return Game():GetRoom():GetCenterPos()
end

local function remaster_gfx_path()
	local conf = Isaac.GetItemConfig():GetCollectible(item.entity)
	local raw = conf and conf.GfxFileName
	if type(raw) == "string" and raw ~= "" then
		if string.sub(raw, 1, 4) == "gfx/" then return raw end
		return "gfx/items/collectibles/"..raw
	end
	return C.REMASTER_GFX
end

local function extra_anim_done(player, min_elapsed, elapsed, fallback)
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

local function vec_lerp(a, b, t)
	t = math.max(0, math.min(1, t or 0))
	return Vector(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
end

local function spawn_remaster_portal(pos)
	pos = pos or pick_portal_pos()
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

local function portal_tick(ent)
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

local function portal_spit_pulse(ent, elapsed, dur)
	if not ent or not ent:Exists() then return end
	dur = math.max(1, dur or C.PORTAL_SPIT_DUR)
	local t = math.min(1, elapsed / dur)
	local pulse = math.sin(t * math.pi)
	local base = 1.05
	ent.SpriteScale = Vector(base * (1 - 0.18 * pulse), base * (1 + 0.42 * pulse))
end

local function portal_reset_scale(ent)
	if ent and ent:Exists() then
		ent.SpriteScale = Vector(1.05, 1.05)
	end
end

local function portal_is_ready(ent)
	if not ent or not ent:Exists() then return false end
	return ent:GetData()[item.own_key.."portal_phase"] == "opened"
end

local function close_portal(ent)
	if not ent or not ent:Exists() then return end
	local d = ent:GetData()
	local s = ent:GetSprite()
	d[item.own_key.."portal_phase"] = "closing"
	s:Play("Disappear", true)
	pcall(function()
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_PORTAL_OPEN, 0.85, 0.9, false, 0, 2)
	end)
end

local function play_portal_transition_sfx(mode)
	pcall(function()
		local vol = (mode == "exit") and 1.0 or 0.92
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_PORTAL_OPEN, vol, 1, false, 0, 2)
	end)
end

local function shader_screen_metrics()
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

local function world_to_shader_uv(world_pos)
	local screen = Isaac.WorldToScreen(world_pos)
	local m = shader_screen_metrics()
	local u = screen.X / m.mult.X
	local v = screen.Y / m.mult.Y
	if Game():GetRoom():IsMirrorWorld() then
		local sz = m.size.X
		while sz > 256 do sz = sz / 2 end
		u = (sz / 256) - u
	end
	return u, v, m
end

local function portal_shader_emerge_cover_params(cine)
	local m = shader_screen_metrics()
	local world = cine.portal_pos
	if cine.portal and cine.portal:Exists() then
		world = cine.portal.Position
		cine.portal_pos = world
	end
	local cu, cv = m.center_u, m.center_v
	if world then
		cu, cv = world_to_shader_uv(world)
	end
	return {
		P1 = {1, 0, 1, 1},
		P2 = {cu, cv, 0, 0},
	}
end

local function portal_shader_params_from_cine(cine)
	if not cine then
		return {P1 = {0, 0, 0, 0}, P2 = {0, 0, 0, 0}}
	end
	if (cine.kind == "outbound_emerge" or cine.kind == "return_emerge") and cine.phase == "portal_open" then
		return portal_shader_emerge_cover_params(cine)
	end
	if cine.phase ~= "portal_transition" then
		return {P1 = {0, 0, 0, 0}, P2 = {0, 0, 0, 0}}
	end
	local m = shader_screen_metrics()
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
		cu, cv = world_to_shader_uv(world)
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

local function begin_portal_screen_transition(cine, mode, on_complete)
	cine.portal_transition_mode = mode or "enter"
	cine.portal_transition_fn = on_complete
	cine.phase = "portal_transition"
	cine.t0 = Game():GetFrameCount()
	play_portal_transition_sfx(cine.portal_transition_mode)
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
		portal_reset_scale(cine.portal)
	end
end

local function tick_portal_screen_transition(cine, elapsed)
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

local function apply_sheets(spr, sheets)
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

local function load_ghost_base_sprite(s, appearance)
	if not s or not appearance then return false end
	local paths = {}
	if type(appearance.base_anm2) == "string" and appearance.base_anm2 ~= "" then
		paths[#paths + 1] = appearance.base_anm2
	end
	paths[#paths + 1] = C.DEFAULT_GHOST_ANM2
	for i = 1, #paths do
		if try_sprite_load(s, paths[i]) then
			apply_sheets(s, appearance.base_sheets)
			return true
		end
	end
	return false
end

--- 演出幽灵：底模 anm2 + 贴图层。Extra 段只画身体；行走段叠 head overlay + 衣装精灵
local function spawn_appearance_ghost(pos, appearance, anim)
	appearance = sanitize_appearance(appearance)
	if not appearance then return nil end
	local q = Isaac.Spawn(EntityType.ENTITY_EFFECT, PORTAL_EFFECT_VAR, item.entity + 1, pos, Vector.Zero, nil):ToEffect()
	if not q then return nil end
	q.Visible = true
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	local s = q:GetSprite()
	if not load_ghost_base_sprite(s, appearance) then
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
	d[item.own_key.."ghost"] = true
	d[item.own_key.."ghost_app"] = appearance
	d[GHOST_CAN_FLY_KEY] = appearance.can_fly and true or false
	d.skip_nil_holder = true
	d.removecd = 999999
	d.skip_nil_distance_cull = true
	return q
end

--- 仅用于游离 Lua Sprite；实体 GetSprite() 由引擎按 30fps 推进，勿再 Update
local function tick_lua_sprite(spr, advance)
	if not spr or advance == false then return end
	if (Game():GetFrameCount() % C.GHOST_LUA_SPRITE_STEP) ~= 0 then return end
	pcall(function() spr:Update() end)
end

local function ghost_walk_anim_candidates(walk_anim)
	local list = {}
	if type(walk_anim) == "string" and walk_anim ~= "" then
		list[#list + 1] = walk_anim
	end
	for _, name in ipairs({"WalkDown", "WalkUp", "WalkLeft", "WalkRight", "Idle"}) do
		list[#list + 1] = name
	end
	return list
end

local function sprite_play_anim(s, names)
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

--- 已在播目标动画时不重 Play，避免 PRE 每帧 Render 把帧重置为 0
local function sprite_ensure_one_of(s, names)
	if not s or type(names) ~= "table" then return nil end
	for _, name in ipairs(names) do
		if type(name) ~= "string" or name == "" then goto continue end
		local playing = false
		pcall(function() playing = s:IsPlaying(name) end)
		if playing then return name end
		local cur = nil
		pcall(function() cur = s:GetAnimation() end)
		if cur == name then
			local finished = false
			pcall(function() finished = s:IsFinished(name) end)
			if not finished then return name end
		end
		::continue::
	end
	return sprite_play_anim(s, names)
end

local function ghost_play_walk_anim(s, walk_anim)
	if not s then return walk_anim end
	local candidates = ghost_walk_anim_candidates(walk_anim)
	return sprite_ensure_one_of(s, candidates) or walk_anim
end

local function ghost_play_resolved_anim(s, anim)
	return ghost_play_walk_anim(s, anim)
end

local function ghost_set_anim(ghost, anim, cache)
	if not ghost or not ghost:Exists() or not anim then return cache end
	cache = cache or {}
	if cache.anim ~= anim then
		local s = ghost:GetSprite()
		ghost_play_walk_anim(s, anim)
		cache.anim = anim
	end
	return cache
end

local function ghost_ensure_anim(ghost, anim, cache)
	return ghost_set_anim(ghost, anim, cache)
end

local function ghost_clear_walk_head_overlay(ghost, cache)
	if not ghost or not ghost:Exists() then return cache end
	cache = cache or {}
	if not cache.overlay_head then return cache end
	pcall(function() ghost:GetSprite():RemoveOverlay() end)
	cache.overlay_head = nil
	return cache
end

local function ghost_set_walk_head_overlay(ghost, body_anim, cache)
	if not ghost or not ghost:Exists() then return cache end
	cache = cache or {}
	local head = C.GHOST_WALK_HEAD[body_anim]
	if cache.overlay_head == head then return cache end
	local s = ghost:GetSprite()
	if head then
		pcall(function() s:PlayOverlay(head, true) end)
	else
		pcall(function() s:RemoveOverlay() end)
	end
	cache.overlay_head = head
	return cache
end

--- 行走 head overlay：按方向选 Head*，固定第 0 帧（睁眼 idle 头）
local function ghost_sync_walk_head_overlay(ghost, body_anim, cache)
	if not ghost or not ghost:Exists() then return cache end
	cache = ghost_set_walk_head_overlay(ghost, body_anim, cache)
	local head = cache and cache.overlay_head
	if not head then return cache end
	local s = ghost:GetSprite()
	pcall(function() s:SetOverlayFrame(head, 0) end)
	return cache
end

local function setup_ghost_walk_costumes(ghost, appearance)
	if not ghost or not ghost:Exists() then return end
	appearance = sanitize_appearance(appearance)
	local gd = ghost:GetData()
	gd[GHOST_COSTUME_WINNERS_KEY] = nil
	gd[GHOST_COSTUME_SPRS_KEY] = nil
	gd[item.own_key.."walk_composite"] = nil
	local has_layers = type(appearance.costume_layers) == "table" and #appearance.costume_layers > 0
	local has_costumes = type(appearance.costumes) == "table" and #appearance.costumes > 0
	if not appearance or (not has_layers and not has_costumes) then
		return
	end
	local pool = {}
	local pool_by_anm2 = {}
	local winners = {}
	local function pool_sprite_for(anm2)
		if type(anm2) ~= "string" or anm2 == "" then return nil end
		if pool_by_anm2[anm2] then return pool_by_anm2[anm2] end
		local spr = Sprite()
		if try_sprite_load(spr, anm2) then
			pool[#pool + 1] = spr
			pool_by_anm2[anm2] = spr
			return spr
		end
		return nil
	end
	local function collect_slots(spr, priority, is_flying, from_base)
		if not sprite_is_usable(spr) then return end
		local ok_n, n = pcall(function() return spr:GetLayerCount() end)
		if not ok_n or type(n) ~= "number" then return end
		for i = 0, n - 1 do
			if not sprite_layer_usable(spr, i) then goto continue end
			local key = nil
			pcall(function()
				local lay = spr:GetLayer(i)
				if lay and lay.GetName then
					key = costume_layer_key(lay:GetName())
				end
			end)
			if key then
				local prev = winners[key]
				if not prev or (priority or 0) >= (prev.priority or 0) then
					winners[key] = {
						spr = spr,
						layer_id = i,
						priority = priority or 0,
						key = key,
						from_base = from_base and true or false,
						is_flying = is_flying and true or false,
					}
				end
			end
			::continue::
		end
	end
	pcall(function() collect_slots(ghost:GetSprite(), 0, appearance.can_fly, true) end)
	if has_layers then
		for _, bind in ipairs(appearance.costume_layers) do
			local key = psl_index_to_key(bind.sprite_layer)
			local spr = pool_sprite_for(bind.anm2)
			local lid = tonumber(bind.layer_id)
			if key and spr and lid and lid >= 0 then
				winners[key] = {
					spr = spr,
					layer_id = lid,
					priority = tonumber(bind.priority) or 1,
					key = key,
					from_base = false,
					is_flying = bind.is_flying and true or false,
				}
			end
		end
	else
		for _, c in ipairs(appearance.costumes) do
			local spr = pool_sprite_for(c.anm2)
			if spr then collect_slots(spr, tonumber(c.priority) or 1, c.is_flying, false) end
		end
	end
	if next(winners) then
		gd[GHOST_COSTUME_SPRS_KEY] = pool
		gd[GHOST_COSTUME_WINNERS_KEY] = winners
		gd[item.own_key.."walk_composite"] = has_layers or has_costumes
		local driver = ghost_pick_body_driver(winners)
		gd[GHOST_COSTUME_DRIVER_KEY] = driver and driver.key or nil
	end
	emit_ghost_probe("setup_costumes", ghost, {
		has_layers = has_layers,
		has_costumes = has_costumes,
		pool_count = #pool,
		winner_count = ghost_count_drawable_slots(ghost),
		driver_key = ghost:GetData()[GHOST_COSTUME_DRIVER_KEY],
	})
end

local function ghost_restore_base_layer_visibility(ghost)
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

local function ghost_sort_winner_slots(winners, head_pass)
	local list = {}
	if type(winners) ~= "table" then return list end
	for key, slot in pairs(winners) do
		if slot and slot.spr and sprite_layer_usable(slot.spr, slot.layer_id) then
			local is_head = costume_layer_is_head(key)
			if (head_pass and is_head) or (not head_pass and not is_head) then
				list[#list + 1] = {
					key = key,
					spr = slot.spr,
					layer_id = slot.layer_id,
					from_base = slot.from_base and true or false,
				}
			end
		end
	end
	table.sort(list, function(a, b)
		local ra = costume_layer_rank(a.key)
		local rb = costume_layer_rank(b.key)
		if ra ~= rb then return ra < rb end
		return (a.layer_id or 0) < (b.layer_id or 0)
	end)
	return list
end

local function ghost_world_screen_pos(ghost, world_offset)
	local room = Game():GetRoom()
	world_offset = world_offset or Vector.Zero
	return room:WorldToScreenPosition(ghost.Position + world_offset) - Game().ScreenShakeOffset
end

local function ghost_costume_sync_body_sprite(spr, walk_anim, frame, sync_frame)
	if not sprite_is_usable(spr) or type(walk_anim) ~= "string" or walk_anim == "" then return end
	local candidates = ghost_walk_anim_candidates(walk_anim)
	pcall(function()
		sprite_ensure_one_of(spr, candidates)
		if sync_frame ~= false then
			spr:SetFrame(frame or 0)
		end
	end)
end

local function ghost_walk_overlay_state(body, body_anim)
	local overlay_anim, overlay_frame = nil, 0
	if body then
		pcall(function()
			overlay_anim = body:GetOverlayAnimation()
			overlay_frame = body:GetOverlayFrame()
		end)
	end
	if type(overlay_anim) ~= "string" or overlay_anim == "" then
		overlay_anim = C.GHOST_WALK_HEAD[body_anim]
		overlay_frame = 0
	end
	return overlay_anim, overlay_frame
end

--- 头部层与身体 Walk* 分离：同步 overlay（Head*）帧，再 RenderLayer head 槽
local function ghost_costume_sync_head_sprite(spr, body_anim, body_frame, overlay_anim, overlay_frame, sync_body_frame)
	if not sprite_is_usable(spr) then return end
	pcall(function()
		if type(body_anim) == "string" and body_anim ~= "" then
			sprite_ensure_one_of(spr, ghost_walk_anim_candidates(body_anim))
			if sync_body_frame ~= false then
				spr:SetFrame(body_frame or 0)
			end
		end
		if type(overlay_anim) == "string" and overlay_anim ~= "" then
			if spr:GetOverlayAnimation() ~= overlay_anim then
				spr:PlayOverlay(overlay_anim, true)
			end
			spr:SetOverlayFrame(overlay_anim, overlay_frame or 0)
		end
	end)
end

local function ghost_draw_winner_layers(ghost, body, slots, anim, frame, overlay_anim, overlay_frame, head_pass)
	if not ghost or not body or #slots == 0 then return 0 end
	local sc = ghost.SpriteScale or Vector(1, 1)
	local tint = body.Color or Color(1, 1, 1, 1)
	local alpha = tint.A or 1
	local screen = ghost_world_screen_pos(ghost)
	local drawn = 0
	for _, slot in ipairs(slots) do
		local spr = slot.spr
		if not sprite_layer_usable(spr, slot.layer_id) then goto continue end
		if head_pass then
			ghost_costume_sync_head_sprite(spr, anim, frame, overlay_anim, overlay_frame, slot.from_base)
		else
			ghost_costume_sync_body_sprite(spr, anim, frame, slot.from_base)
		end
		local ok = pcall(function()
			spr.Scale = sc
			spr.FlipX = ghost.FlipX
			spr.Color = Color(tint.R, tint.G, tint.B, alpha)
			spr:RenderLayer(slot.layer_id, screen, Vector.Zero, Vector.Zero)
		end)
		if ok then drawn = drawn + 1 end
		::continue::
	end
	return drawn
end

local function ghost_costume_sync_sprite(spr, anim, frame)
	ghost_costume_sync_body_sprite(spr, anim, frame)
end

local function clear_ghost_walk_costumes(ghost)
	if not ghost then return end
	ghost_restore_base_layer_visibility(ghost)
	local gd = ghost:GetData()
	gd[GHOST_COSTUME_WINNERS_KEY] = nil
	gd[GHOST_COSTUME_SPRS_KEY] = nil
	gd[GHOST_COSTUME_DRIVER_KEY] = nil
	gd[item.own_key.."walk_composite"] = nil
end

local function remove_remaster_cinematic_effect(ent)
	if not ent or not ent:Exists() then return end
	local d = ent:GetData()
	if not d[item.own_key.."portal"] and not d[item.own_key.."ghost"] then return end
	if d[item.own_key.."ghost"] then
		clear_ghost_walk_costumes(ent)
		d[GHOST_HELD_VISIBLE_KEY] = false
		d[GHOST_HELD_SPR_KEY] = nil
	end
	pcall(function() ent:Remove() end)
end

local function cleanup_remaster_cinematic_entities(cine)
	if cine then
		cine.portal_transition_fn = nil
		cine.portal_transition_mode = nil
		if cine.portal then remove_remaster_cinematic_effect(cine.portal) end
		if cine.ghost then remove_remaster_cinematic_effect(cine.ghost) end
	end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, PORTAL_EFFECT_VAR, item.entity)) do
		remove_remaster_cinematic_effect(ent)
	end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, PORTAL_EFFECT_VAR, item.entity + 1)) do
		remove_remaster_cinematic_effect(ent)
	end
end

clear_cinematic = function(opts)
	opts = type(opts) == "table" and opts or {}
	local cine = item.cinematic
	if cine then
		revert_channel_returning_state(cine)
		cleanup_remaster_cinematic_entities(cine)
	end
	item.cinematic = nil
	if opts.clear_pending ~= false then
		item._force_emerge = nil
		item._force_return_emerge = nil
		item._pending_fx = nil
		save.elses[C.PENDING_FX_KEY] = nil
	end
	restore_cinematic_party_visibility(opts.fallback_visible ~= false)
end

local function render_ghost_walk_costumes(ghost)
	if not ghost or not ghost:Exists() or not ghost.Visible then
		emit_ghost_probe("render_skip", ghost, {render_early = "invisible_or_missing"})
		return
	end
	local winners = ghost:GetData()[GHOST_COSTUME_WINNERS_KEY]
	if type(winners) ~= "table" then
		emit_ghost_probe("render_skip", ghost, {render_early = "no_winners"})
		return
	end
	local body = ghost:GetSprite()
	if not sprite_is_usable(body) then
		emit_ghost_probe("render_skip", ghost, {render_early = "body_not_usable"})
		return
	end
	local driver = ghost_get_costume_driver(ghost, winners)
	local anim, frame = ghost_read_sprite_anim_frame(body)
	if driver and driver.spr then
		local driver_anim, driver_frame = ghost_read_sprite_anim_frame(driver.spr)
		if type(driver_anim) == "string" and driver_anim ~= "" then
			anim, frame = driver_anim, driver_frame
		end
	else
		local desired = ghost_desired_walk_anim(ghost)
		if type(desired) == "string" and desired ~= "" then anim = desired end
	end
	if type(anim) ~= "string" or anim == "" then
		emit_ghost_probe("render_skip", ghost, {render_early = "no_anim"})
		return
	end
	local overlay_anim, overlay_frame = ghost_walk_overlay_state(body, anim)
	local body_slots = ghost_sort_winner_slots(winners, false)
	local head_slots = ghost_sort_winner_slots(winners, true)
	local sc = ghost.SpriteScale or Vector(1, 1)
	local tint = body.Color or Color(1, 1, 1, 1)
	local alpha = tint.A or 1
	local screen = ghost_world_screen_pos(ghost)
	local drawn_body = ghost_draw_winner_layers(ghost, body, body_slots, anim, frame, overlay_anim, overlay_frame, false)
	local drawn_head = ghost_draw_winner_layers(ghost, body, head_slots, anim, frame, overlay_anim, overlay_frame, true)
	local overlay_drawn = ghost_render_sprite_overlay_only(body, screen, sc, ghost.FlipX, tint, alpha)
	local total_drawn = drawn_body + drawn_head + (overlay_drawn and 1 or 0)
	local render_fallback = false
	if total_drawn == 0 then
		render_fallback = ghost_render_fallback_full_body(ghost, body, screen, sc, tint, alpha)
	end
	emit_ghost_probe("render_post", ghost, {
		anim = anim,
		frame = frame,
		driver_key = driver and driver.key or nil,
		overlay_anim = overlay_anim,
		overlay_frame = overlay_frame,
		body_slot_count = #body_slots,
		head_slot_count = #head_slots,
		layers_drawn = drawn_body + drawn_head,
		overlay_drawn = overlay_drawn,
		render_fallback = render_fallback,
	})
end

local function play_jump_in(player)
	if not player or not player:Exists() then return end
	player.Velocity = Vector.Zero
	player.Visible = true
	pcall(function() player:PlayExtraAnimation("Trapdoor") end)
end

local function play_jump_out(player)
	if not player or not player:Exists() then return end
	player.Velocity = Vector.Zero
	player.Visible = true
	pcall(function() player:PlayExtraAnimation("Jump") end)
end

local function play_remaster_lift_sfx()
	-- 与蓝图/Death Sentence 等 AnimateCollectible LiftItem 一致
	pcall(function()
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP, 1, 1, false, 0, 2)
	end)
end

local function play_lift_remaster(player)
	if not player or not player:Exists() then return end
	player.Visible = true
	player.Velocity = Vector.Zero
	pcall(function()
		player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
	end)
	play_remaster_lift_sfx()
end

local function play_hide_remaster(player)
	if not player or not player:Exists() then return end
	pcall(function()
		if player:IsHoldingItem() then
			player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
		end
	end)
end

local function ghost_anim_done(ghost, anim, elapsed, fallback)
	if not ghost or not ghost:Exists() then return (elapsed or 0) >= (fallback or 12) end
	local s = ghost:GetSprite()
	if not sprite_is_usable(s) then return (elapsed or 0) >= (fallback or 12) end
	local done = false
	pcall(function()
		if anim and s:IsFinished(anim) then done = true end
	end)
	if done then return true end
	return (elapsed or 0) >= (fallback or 12)
end

--- LiftItem 的 pickup item 空帧（相对幽灵 Position；Y 负值=上）
local function ghost_pickup_null_offset(ghost)
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

local function walk_anim_for_delta(delta)
	delta = delta or Vector.Zero
	if math.abs(delta.X) >= math.abs(delta.Y) then
		return delta.X >= 0 and "WalkRight" or "WalkLeft"
	end
	return delta.Y >= 0 and "WalkDown" or "WalkUp"
end

local function pick_random_door_pos(from_pos)
	local room = Game():GetRoom()
	local choices = {}
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		if room:IsDoorSlotAllowed(slot) and room:GetDoor(slot) then
			choices[#choices + 1] = room:GetDoorSlotPosition(slot)
		end
	end
	if #choices == 0 then
		return from_pos + Vector(0, 72)
	end
	return choices[math.random(1, #choices)]
end

local function ghost_play_anim(ghost, names)
	if not ghost or not ghost:Exists() then return nil end
	return sprite_play_anim(ghost:GetSprite(), names)
end

--- 举起段：在幽灵 POST_EFFECT_RENDER 上叠绘 collectible 精灵（不另 spawn 实体）
local function ensure_ghost_held_sprite(ghost)
	if not ghost or not ghost:Exists() then return nil end
	local gd = ghost:GetData()
	local spr = gd[GHOST_HELD_SPR_KEY]
	if not spr then
		spr = Sprite()
		local gfx = remaster_gfx_path()
		local ok = pcall(function()
			spr:Load(C.HELD_ITEM_ANM2, true)
			spr:ReplaceSpritesheet(0, gfx)
			spr:ReplaceSpritesheet(1, gfx)
			spr:LoadGraphics()
			spr:Play("PlayerPickup", true)
			if not spr:IsPlaying("PlayerPickup") then
				spr:Play("Idle", true)
			end
		end)
		if ok and sprite_is_usable(spr) then
			gd[GHOST_HELD_SPR_KEY] = spr
		else
			spr = nil
		end
	end
	if spr then
		gd[GHOST_HELD_VISIBLE_KEY] = true
	end
	return spr
end

local function tick_ghost_walk_costume_sprites(ghost)
	if not ghost or not ghost:Exists() then return end
	local gd = ghost:GetData()
	if not gd[item.own_key.."walk_composite"] then return end
	local walk_anim = ghost_desired_walk_anim(ghost)
	local candidates = ghost_walk_anim_candidates(walk_anim)
	local pool = gd[GHOST_COSTUME_SPRS_KEY]
	if type(pool) ~= "table" then return end
	for _, spr in ipairs(pool) do
		sprite_ensure_one_of(spr, candidates)
		tick_lua_sprite(spr, true)
	end
end

local function hide_ghost_held_sprite(ghost)
	if not ghost then return end
	local gd = ghost:GetData()
	gd[GHOST_HELD_VISIBLE_KEY] = false
	gd[GHOST_HELD_SPR_KEY] = nil
end

local function tick_ghost_held_sprite(ghost, advance)
	if not ghost or not ghost:Exists() then return end
	local gd = ghost:GetData()
	if not gd[GHOST_HELD_VISIBLE_KEY] then return end
	local spr = gd[GHOST_HELD_SPR_KEY]
	if not spr or advance == false then return end
	tick_lua_sprite(spr, true)
end

local function render_ghost_held_sprite(ghost)
	if not ghost or not ghost:Exists() or not ghost.Visible then return end
	local gd = ghost:GetData()
	if not gd[GHOST_HELD_VISIBLE_KEY] then return end
	local spr = gd[GHOST_HELD_SPR_KEY]
	if not sprite_is_usable(spr) then return end
	local sc = ghost.SpriteScale and ghost.SpriteScale.Y or 1
	local off = ghost_pickup_null_offset(ghost)
	local screen = ghost_world_screen_pos(ghost, Vector(off.X * sc, off.Y * sc))
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

local function sync_ghost_held_visual(ghost, freeze_body)
	if not ghost or not ghost:Exists() then return end
	tick_ghost_held_sprite(ghost, not freeze_body)
end

local function ghost_apply_walk_facing(ghost, _anim)
	if not ghost or not ghost:Exists() then return end
	-- WalkLeft/Right 已是独立朝向动画；再 FlipX 会镜像过头
	ghost.FlipX = false
end

local function begin_ghost_lift(cine)
	if not cine.ghost or not cine.ghost:Exists() then return end
	cine.ghost_anim_cache = {}
	ghost_clear_walk_head_overlay(cine.ghost, cine.ghost_anim_cache)
	ghost_ensure_anim(cine.ghost, "LiftItem", cine.ghost_anim_cache)
	ensure_ghost_held_sprite(cine.ghost)
	sync_ghost_held_visual(cine.ghost, false)
	play_remaster_lift_sfx()
end

local function begin_ghost_walk_to_door(cine)
	if not cine.ghost or not cine.ghost:Exists() then return end
	hide_ghost_held_sprite(cine.ghost)
	ghost_clear_walk_head_overlay(cine.ghost, cine.ghost_anim_cache)
	local from = Vector(cine.ghost.Position.X, cine.ghost.Position.Y)
	cine.walk_from = from
	cine.door_target = pick_random_door_pos(from)
	local delta = cine.door_target - from
	cine.ghost_walk_anim = walk_anim_for_delta(delta)
	cine.ghost_anim_cache = {}
	setup_ghost_walk_costumes(cine.ghost, cine.appearance)
	ghost_apply_walk_facing(cine.ghost, cine.ghost_walk_anim)
	ghost_ensure_anim(cine.ghost, cine.ghost_walk_anim, cine.ghost_anim_cache)
	ghost_sync_walk_head_overlay(cine.ghost, cine.ghost_walk_anim, cine.ghost_anim_cache)
	emit_ghost_probe("begin_walk", cine.ghost, {walk_anim = cine.ghost_walk_anim})
end

local function finish_return_travel(cine)
	local ch = cine.channel
	local dest = ch and ch.from
	local app = cine.appearance
	local idx = cine.channel_index
	if not idx and ch and ch.from and ch.to then
		idx = select(1, find_channel_index_by_route(ch.from.command, ch.to.command))
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
			update_channel_at(idx, ch)
		elseif still_outbound then
			ch.armed = false
			ch.returning = nil
			ch.skip_arrive_once = true
			update_channel_at(idx, ch)
		else
			remove_channel_at(idx)
		end
	end
	set_pending_fx({
		kind = "return_emerge",
		appearance = app,
	})
	item._force_return_emerge = {appearance = app}
	item.cinematic = nil
	if dest then
		execute_stage_travel(dest, {reseed = true})
	end
end

local function finish_return_emerge(cine)
	local player = cine and cine.player
	local portal = cine.portal
	if portal and portal:Exists() then
		close_portal(portal)
		cine.portal = nil
	end
	if player and player:Exists() then
		player.Visible = true
		player.Velocity = Vector.Zero
	end
	local ch = cine.channel
	item.cinematic = nil
	item._party_hide = nil
	on_remaster_arrival()
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
	local list = get_channels()
	return list[1]
end

function item.has_pending_return()
	for _, ch in ipairs(get_channels()) do
		if ch.armed == true then return true end
	end
	return false
end

local function player_index_of(player)
	if not player then return 0 end
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and GetPtrHash(p) == GetPtrHash(player) then return i end
	end
	return 0
end

local function resolve_cine_player(cine)
	local p = Game():GetPlayer(cine.player_index or 0)
	if p and p:Exists() then
		cine.player = p
		return p
	end
	if cine.player and cine.player:Exists() then return cine.player end
	return nil
end

local function begin_outbound_cinematic(player, slot, from, to, target)
	local appearance = capture_player_appearance(player)
	register_outbound_passenger(from, to, target, appearance, get_current_run_id())
	local portal_pos = pick_portal_pos(player)
	local portal = spawn_remaster_portal(portal_pos)
	item.cinematic = {
		kind = "outbound",
		phase = "portal_open",
		t0 = Game():GetFrameCount(),
		player = player,
		player_index = player_index_of(player),
		slot = slot,
		from = from,
		to = to,
		target = target,
		appearance = appearance,
		portal = portal,
		portal_pos = portal_pos,
		suck_from = Vector(player.Position.X, player.Position.Y),
	}
	freeze_player(player, true)
	hide_party_for_cinematic(player, {player_keep_hidden = false})
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

local function begin_outbound_emerge(player, appearance)
	if item.cinematic and item.cinematic.kind == "outbound_emerge" then
		item._force_emerge = nil
		return
	end
	player = player or Game():GetPlayer(0)
	if not player or not player:Exists() then return end
	item._force_emerge = nil
	set_player_hidden(player, true)
	player.Velocity = Vector.Zero
	local portal_pos = pick_portal_pos()
	player.Position = portal_pos
	local portal = spawn_remaster_portal(portal_pos)
	restore_party_familiars()
	item.cinematic = {
		kind = "outbound_emerge",
		phase = "portal_open",
		t0 = Game():GetFrameCount(),
		born = Game():GetFrameCount(),
		player = player,
		player_index = player_index_of(player),
		appearance = appearance,
		portal = portal,
		portal_pos = portal_pos,
	}
	freeze_player(player, true)
end

local function begin_return_emerge(player, appearance)
	if item.cinematic and item.cinematic.kind == "return_emerge" then
		item._force_return_emerge = nil
		return
	end
	player = player or Game():GetPlayer(0)
	if not player or not player:Exists() then return end
	item._force_return_emerge = nil
	set_player_hidden(player, true)
	player.Velocity = Vector.Zero
	local portal_pos = pick_portal_pos()
	player.Position = portal_pos
	local portal = spawn_remaster_portal(portal_pos)
	restore_party_familiars()
	item.cinematic = {
		kind = "return_emerge",
		phase = "portal_open",
		t0 = Game():GetFrameCount(),
		born = Game():GetFrameCount(),
		player = player,
		player_index = player_index_of(player),
		appearance = appearance,
		portal = portal,
		portal_pos = portal_pos,
	}
	freeze_player(player, true)
end

local function begin_return_cinematic(player, channel_index, channel)
	player = player or Game():GetPlayer(0)
	if not player or not player:Exists() then return end
	local active = channel_active_return_passenger(channel)
	channel.returning = true
	update_channel_at(channel_index, channel)
	item.cinematic = {
		kind = "return",
		phase = "wake",
		t0 = Game():GetFrameCount(),
		player = player,
		player_index = player_index_of(player),
		channel_index = channel_index,
		channel = channel,
		appearance = (active and active.appearance) or channel.appearance,
	}
	freeze_player(player, true)
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

local function tick_cinematic()
	local cine = item.cinematic
	if not cine then return end
	local player = resolve_cine_player(cine)
	if not player then
		clear_cinematic({fallback_visible = true})
		return
	end
	freeze_player(player, true)
	local elapsed = Game():GetFrameCount() - (cine.t0 or 0)
	local portal = cine.portal
	if portal and portal:Exists() then portal_tick(portal) else portal = nil end
	if cine.ghost and cine.ghost:Exists() then
		if cine.phase == "ghost_lift" or cine.phase == "ghost_lift_hold" then
			sync_ghost_held_visual(cine.ghost, cine.phase == "ghost_lift_hold")
		end
	end

	if cine.phase == "portal_transition" then
		tick_portal_screen_transition(cine, elapsed)
		return
	end

	local function start_suck_then_jump()
		local target = (portal and portal.Position) or cine.portal_pos or pick_portal_pos()
		cine.portal_pos = target
		-- 已在门附近：直接跳入，避免无意义瞬移感
		if (player.Position - target):Length() < 20 then
			player.Position = target
			cine.phase = "jump_in"
			cine.t0 = Game():GetFrameCount()
			play_jump_in(player)
			return
		end
		cine.phase = "suck_in"
		cine.t0 = Game():GetFrameCount()
		cine.suck_from = Vector(player.Position.X, player.Position.Y)
	end

	local function commit_outbound_travel(to_floor, appearance)
		local app = appearance
		set_pending_fx({
			kind = "outbound_emerge",
			appearance = app,
		})
		item._force_emerge = {appearance = app}
		item.cinematic = nil
		if to_floor then
			execute_stage_travel(to_floor, {reseed = true})
		end
	end

	if cine.kind == "outbound" then
		if cine.phase == "portal_open" then
			if portal_is_ready(portal) and elapsed >= C.OPEN_SETTLE then
				start_suck_then_jump()
			end
		elseif cine.phase == "suck_in" then
			local target = cine.portal_pos or pick_portal_pos()
			local t = elapsed / C.SUCK_DUR
			if t >= 1 or (player.Position - target):Length() < 6 then
				player.Position = target
				cine.phase = "jump_in"
				cine.t0 = Game():GetFrameCount()
				play_jump_in(player)
			else
				local ease = t * t
				player.Position = vec_lerp(cine.suck_from, target, ease)
			end
		elseif cine.phase == "jump_in" then
			-- 等 Trapdoor 播完再 portal shader 换层，传送门保持开启
			if extra_anim_done(player, 12, elapsed, C.JUMP_IN_WAIT) then
				hide_party_for_cinematic(player, {player_keep_hidden = true})
				local to_floor = cine.to
				local app = cine.appearance
				begin_portal_screen_transition(cine, "enter", function()
					commit_outbound_travel(to_floor, app)
				end)
			end
		end
	elseif cine.kind == "outbound_emerge" then
		-- 安全阀：演出卡死时强制现身
		local total_age = Game():GetFrameCount() - (cine.born or cine.t0 or 0)
		if total_age > 240 then
			restore_party_player(player, true)
			play_hide_remaster(player)
			clear_cinematic({fallback_visible = true})
			return
		end
		if cine.phase == "portal_open" then
			set_player_hidden(player, true)
			if portal_is_ready(portal) and elapsed >= C.OPEN_SETTLE then
				begin_portal_screen_transition(cine, "exit", function()
					cine.phase = "jump_out"
					cine.t0 = Game():GetFrameCount()
					if cine.portal and cine.portal:Exists() then
						player.Position = cine.portal.Position
					elseif cine.portal_pos then
						player.Position = cine.portal_pos
					end
					restore_party_familiars()
					restore_party_player(player, true)
					play_jump_out(player)
				end)
			end
		elseif cine.phase == "jump_out" then
			-- 落地后立刻举起，更连贯
			if extra_anim_done(player, 10, elapsed, C.JUMP_OUT_WAIT) then
				cine.phase = "lift"
				cine.t0 = Game():GetFrameCount()
				restore_party_familiars()
				restore_party_player(player, true)
				play_lift_remaster(player)
			end
		elseif cine.phase == "lift" then
			if elapsed >= C.LIFT_WAIT then
				play_hide_remaster(player)
				if portal then
					close_portal(portal)
					cine.portal = nil
				end
				local app = cine.appearance
				item.cinematic = nil
				item._party_hide = nil
				on_remaster_arrival()
				pcall(function()
					item.fx.after_outbound({dir = "outbound_arrive", appearance = app})
				end)
			end
		end
	elseif cine.kind == "return_emerge" then
		local total_age = Game():GetFrameCount() - (cine.born or cine.t0 or 0)
		if total_age > 240 then
			restore_party_player(player, true)
			finish_return_emerge(cine)
			return
		end
		if cine.phase == "portal_open" then
			set_player_hidden(player, true)
			if portal_is_ready(portal) and elapsed >= C.OPEN_SETTLE then
				begin_portal_screen_transition(cine, "exit", function()
					cine.phase = "jump_out"
					cine.t0 = Game():GetFrameCount()
					if cine.portal and cine.portal:Exists() then
						player.Position = cine.portal.Position
					elseif cine.portal_pos then
						player.Position = cine.portal_pos
					end
					restore_party_familiars()
					restore_party_player(player, true)
					play_jump_out(player)
				end)
			end
		elseif cine.phase == "jump_out" then
			if extra_anim_done(player, 10, elapsed, C.JUMP_OUT_WAIT) then
				finish_return_emerge(cine)
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
				local portal_pos = pick_portal_pos()
				cine.portal_pos = portal_pos
				cine.portal = spawn_remaster_portal(portal_pos)
			end
		elseif cine.phase == "portal_open" then
			if portal_is_ready(cine.portal) and elapsed >= C.OPEN_SETTLE then
				start_suck_then_jump()
			end
		elseif cine.phase == "suck_in" then
			local target = cine.portal_pos or pick_portal_pos()
			local t = elapsed / C.SUCK_DUR
			if t >= 1 or (player.Position - target):Length() < 6 then
				player.Position = target
				cine.phase = "jump_in"
				cine.t0 = Game():GetFrameCount()
				play_jump_in(player)
			else
				local ease = t * t
				player.Position = vec_lerp(cine.suck_from, target, ease)
			end
		elseif cine.phase == "jump_in" then
			if extra_anim_done(player, 12, elapsed, C.JUMP_IN_WAIT) then
				hide_party_for_cinematic(player, {player_keep_hidden = true})
				cine.phase = "portal_digest"
				cine.t0 = Game():GetFrameCount()
			end
		elseif cine.phase == "portal_digest" then
			if elapsed >= C.GHOST_SPIT_WAIT then
				cine.phase = "ghost_spit"
				cine.t0 = Game():GetFrameCount()
				local pos = cine.portal_pos or pick_portal_pos()
				cine.spit_from = pos + Vector(0, -10)
				cine.spit_to = pos + Vector(0, 10)
				cine.ghost = spawn_appearance_ghost(cine.spit_from, cine.appearance, "Jump")
				if not cine.ghost then
					local bare = sanitize_appearance({
						base_anm2 = C.DEFAULT_GHOST_ANM2,
						sprite_scale = cine.appearance and cine.appearance.sprite_scale,
						costumes = {},
					})
					cine.ghost = spawn_appearance_ghost(cine.spit_from, bare, "Jump")
				end
				portal_reset_scale(cine.portal)
				pcall(function()
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_PORTAL_OPEN, 1.0, 1, false, 0, 2)
				end)
			end
		elseif cine.phase == "ghost_spit" then
			if cine.ghost and cine.ghost:Exists() then
				local t = math.min(1, elapsed / C.GHOST_JUMP_WAIT)
				local ease = 1 - (1 - t) ^ 2
				cine.ghost.Position = vec_lerp(cine.spit_from, cine.spit_to, ease)
			end
			if ghost_anim_done(cine.ghost, "Jump", elapsed, C.GHOST_JUMP_WAIT) then
				cine.phase = "ghost_lift"
				cine.t0 = Game():GetFrameCount()
				cine.lift_hold = false
				begin_ghost_lift(cine)
			end
		elseif cine.phase == "ghost_lift" then
			if not cine.lift_hold then
				sync_ghost_held_visual(cine.ghost, false)
				if ghost_anim_done(cine.ghost, "LiftItem", elapsed, C.GHOST_LIFT_FALLBACK) then
					cine.lift_hold = true
					cine.phase = "ghost_lift_hold"
					cine.t0 = Game():GetFrameCount()
				end
			end
		elseif cine.phase == "ghost_lift_hold" then
			sync_ghost_held_visual(cine.ghost, true)
			if elapsed >= C.GHOST_LIFT_HOLD then
				cine.phase = "ghost_hide_item"
				cine.t0 = Game():GetFrameCount()
				hide_ghost_held_sprite(cine.ghost)
				ghost_clear_walk_head_overlay(cine.ghost, cine.ghost_anim_cache)
				cine.ghost_anim_cache = {}
				ghost_ensure_anim(cine.ghost, "HideItem", cine.ghost_anim_cache)
			end
		elseif cine.phase == "ghost_hide_item" then
			if ghost_anim_done(cine.ghost, "HideItem", elapsed, C.GHOST_HIDE_FALLBACK) then
				cine.phase = "ghost_hide_settle"
				cine.t0 = Game():GetFrameCount()
			end
		elseif cine.phase == "ghost_hide_settle" then
			if elapsed >= C.GHOST_HIDE_SETTLE then
				cine.phase = "ghost_walk_door"
				cine.t0 = Game():GetFrameCount()
				begin_ghost_walk_to_door(cine)
			end
		elseif cine.phase == "ghost_walk_door" then
			local ghost = cine.ghost
			local target = cine.door_target
			if ghost and ghost:Exists() and target then
				local pos = ghost.Position
				local delta = target - pos
				local dist = delta:Length()
				if dist > C.GHOST_DOOR_REACH then
					local step = math.min(C.GHOST_WALK_SPEED, dist)
					local dir = delta:Normalized()
					local step_vec = dir * step
					ghost.Position = pos + step_vec
					ghost.Velocity = dir * C.GHOST_WALK_SPEED
					local anim = walk_anim_for_delta(delta)
					if cine.ghost_walk_anim ~= anim then
						cine.ghost_walk_anim = anim
						cine.ghost_anim_cache = {}
					end
					ghost_apply_walk_facing(ghost, cine.ghost_walk_anim)
					cine.ghost_anim_cache = ghost_set_anim(ghost, cine.ghost_walk_anim, cine.ghost_anim_cache)
					cine.ghost_anim_cache = ghost_sync_walk_head_overlay(ghost, cine.ghost_walk_anim, cine.ghost_anim_cache)
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
			local ghost = cine.ghost
			if ghost and ghost:Exists() then
				local t = math.min(1, elapsed / C.GHOST_FADE_DUR)
				local alpha = 1 - t
				ghost:GetSprite().Color = Color(1, 1, 1, alpha)
				if elapsed >= C.GHOST_FADE_DUR then
					clear_ghost_walk_costumes(ghost)
					hide_ghost_held_sprite(ghost)
					ghost:Remove()
					cine.ghost = nil
					local snap = {
						channel = cine.channel,
						channel_index = cine.channel_index,
						appearance = cine.appearance,
						portal = cine.portal,
						portal_pos = cine.portal_pos,
					}
					begin_portal_screen_transition(cine, "enter", function()
						finish_return_travel({
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
				begin_portal_screen_transition(cine, "enter", function()
					finish_return_travel({
						channel = snap.channel,
						channel_index = snap.channel_index,
						appearance = snap.appearance,
					})
				end)
			end
		end
	end
end

-- 面板开/关在文件后段定义；此处前向声明，供 travel_to_selected 作 upvalue
local close_panel
local open_panel
local change_selection, render_tptron_panel, get_font
local menu_input_is_pressed, is_action_triggered, ctrl_cancel_triggered

local function travel_to_selected()
	local panel = item.panel
	if not panel then return end
	local target = item.floor_targets[panel.index]
	local player, slot = panel.player, panel.slot
	if not target then
		return
	end

	local from = capture_current_floor()
	local to = parse_command(target.command)
	if not to then
		close_panel()
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

	close_panel()
	if player and player:Exists() then
		player:SetActiveCharge(0, slot)
	end
	begin_outbound_cinematic(player, slot, from, to, target)
end

local function arm_channel_after_outbound(index, ch, keep_skip_arrive)
	if not ch or not index then return end
	if keep_skip_arrive then
		ch.skip_arrive_once = true
	else
		ch.skip_arrive_once = nil
	end
	ch.armed = true
	ch.returning = nil
	update_channel_at(index, ch)
	-- after_outbound 在 outbound_emerge 跳出结束后再调，避免双触发
end

local function consume_outbound_arrival(index, ch, fx_app)
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
	}
	local head = ch.return_pending[1]
	if head then
		ch.appearance = head.appearance
		ch.opened_run_id = head.opened_run_id
	end
	local more_outbound = type(ch.outbound_pending) == "table" and #ch.outbound_pending > 0
	arm_channel_after_outbound(index, ch, more_outbound)
	return app
end

local function try_trigger_return_channel()
	local list = get_channels()
	if #list == 0 then return end

	-- 续关：只补齐武装状态，不立刻回传
	if item._suppress_return then
		item._suppress_return = false
		for i, ch in ipairs(list) do
			ch.from = sanitize_floor_info(ch.from) or ch.from
			ch.to = sanitize_floor_info(ch.to) or ch.to
			if ch.skip_arrive_once and floor_equals(ch.to) then
				consume_outbound_arrival(i, ch, nil)
			elseif ch.armed or ch.skip_arrive_once then
				update_channel_at(i, ch)
			end
		end
		return
	end

	-- 回传抵达原层：portal 反向 zoom 后抛出玩家（不举道具）
	local force_ret = item._force_return_emerge
	if force_ret then
		item._force_return_emerge = nil
		take_pending_fx()
		begin_return_emerge(Game():GetPlayer(0), force_ret.appearance)
		return
	end
	local peek = item._pending_fx or save.elses[C.PENDING_FX_KEY]
	if type(peek) == "table" and peek.kind == "return_emerge" then
		take_pending_fx()
		begin_return_emerge(Game():GetPlayer(0), peek.appearance)
		return
	end

	-- 出发抵达 B：武装渠道，并播跳出演出（无论 pending 是否还在，都必须现身）
	for i, ch in ipairs(list) do
		ch.from = sanitize_floor_info(ch.from) or ch.from
		ch.to = sanitize_floor_info(ch.to) or ch.to
		if floor_equals(ch.to) and ch.skip_arrive_once then
			local pending = take_pending_fx()
			local fx_app = pending and pending.appearance
			local app = consume_outbound_arrival(i, ch, fx_app)
			if app then
				begin_outbound_emerge(Game():GetPlayer(0), app)
			end
			return
		end
	end

	local hit_index, hit = nil, nil
	for i, ch in ipairs(list) do
		ch.from = sanitize_floor_info(ch.from) or ch.from
		ch.to = sanitize_floor_info(ch.to) or ch.to
		if floor_equals(ch.to) and ch.armed and not ch.returning and not channel_blocks_return_this_run(ch) then
			hit_index, hit = i, ch
			break
		end
	end
	if not hit_index or not hit then
		-- 仅消费 pending / force emerge（无渠道武装场景）
		local pending = take_pending_fx()
		local force = item._force_emerge
		item._force_emerge = nil
		if (pending and pending.kind == "outbound_emerge") or force then
			begin_outbound_emerge(Game():GetPlayer(0), (pending and pending.appearance) or (force and force.appearance))
		end
		return
	end

	if remaster_return_blocked() then
		return
	end

	begin_return_cinematic(Game():GetPlayer(0), hit_index, hit)
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

function get_font()
	if not panel_font then
		panel_font = Font()
		panel_font:Load("font/cjk/lanapixel.fnt")
	end
	return panel_font
end

local function ensure_tptron_sprite()
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

local function get_icon_slot_offsets()
	if icon_slot_cache then return icon_slot_cache end
	local spr = ensure_tptron_sprite()
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
local function get_remaster_debug_number(key, default)
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

local function get_flip_spacing()
	local v = get_remaster_debug_number("RemasterCodeFlipSpacing", 4)
	if v and v > 0 then return v end
	return 4
end

local function get_panel_offset()
	return Vector(
		get_remaster_debug_number("RemasterPanelOffsetX", 0),
		get_remaster_debug_number("RemasterPanelOffsetY", 40)
	)
end

local function panel_origin(panel, sw, sh)
	local open_t = 1
	if panel and panel.opened_frame then
		local dur = math.max(1, OPEN_RISE_DUR)
		open_t = (Game():GetFrameCount() - panel.opened_frame) / dur
		if open_t < 0 then open_t = 0 elseif open_t > 1 then open_t = 1 end
	end
	local rise_ease = 1 - (1 - open_t) ^ 3
	local ui_rise = (1 - rise_ease) * OPEN_RISE_DISTANCE
	local ui_alpha = (open_t < 0.55) and (open_t / 0.55) or 1
	local offset = get_panel_offset()
	return Vector(sw * 0.5 + offset.X, sh * 0.42 + ui_rise + offset.Y), ui_alpha, open_t
end

function close_panel()
	local panel = item.panel
	if panel and panel.player and panel.player:Exists() and panel.player:IsHoldingItem() then
		panel.player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
	end
	item.panel = nil
end

function open_panel(player, slot)
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
	ensure_tptron_sprite()
	get_icon_slot_offsets()
end

-- Menu input must not be tied to the player entity that opened the panel.
function is_action_triggered(action)
	for controller = 0, 7 do
		if Input.IsActionTriggered(action, controller) then return true end
	end
	return false
end

local function is_action_pressed(action)
	for controller = 0, 7 do
		if Input.IsActionPressed(action, controller) then return true end
	end
	return false
end

function menu_input_is_pressed()
	return is_action_pressed(ButtonAction.ACTION_MENUUP)
		or is_action_pressed(ButtonAction.ACTION_MENUDOWN)
		or is_action_pressed(ButtonAction.ACTION_MENULEFT)
		or is_action_pressed(ButtonAction.ACTION_MENURIGHT)
		or is_action_pressed(ButtonAction.ACTION_MENUCONFIRM)
		or Input.IsButtonPressed(Keyboard.KEY_LEFT_CONTROL, 0)
		or Input.IsButtonPressed(Keyboard.KEY_RIGHT_CONTROL, 0)
end

function ctrl_cancel_triggered()
	return Input.IsButtonTriggered(Keyboard.KEY_LEFT_CONTROL, 0)
		or Input.IsButtonTriggered(Keyboard.KEY_RIGHT_CONTROL, 0)
end

local function alphabet_index(char)
	if type(char) ~= "string" or #char ~= 1 then return nil end
	local b = string.byte(char)
	if b >= 65 and b <= 90 then return b - 64 end
	if b >= 97 and b <= 122 then return b - 96 end
	return nil
end

--- B→D => {B,C,D}；C→B => {C,B}。非字母则直接两帧对切。
local function build_flip_path(from_char, to_char)
	from_char = tostring(from_char or " ")
	to_char = tostring(to_char or " ")
	if from_char == to_char then return {from_char}, 0 end
	local fi, ti = alphabet_index(from_char), alphabet_index(to_char)
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
local function segment_duration(seg_index, seg_count, spacing)
	spacing = math.max(0.5, tonumber(spacing) or 4)
	local base = 0.028 * spacing
	if seg_count <= 1 then return base end
	local t = (seg_index - 0.5) / seg_count
	local mid = 1 - 4 * (t - 0.5) * (t - 0.5) -- 端点0、中央1
	return base * (1 - 0.55 * mid)
end

local function begin_code_transition(panel, old_code, new_code)
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
			local path, dir = build_flip_path(a, b)
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

function change_selection(delta)
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
			begin_code_transition(panel, old_code, new.code)
		end
		save.elses[C.SELECTION_KEY] = panel.index
	end
end

local function render_code_char_at(char, screen_pos, alpha, scale_y)
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

local function slot_screen_pos(origin, slot_index)
	local slots = get_icon_slot_offsets()
	local off = slots[slot_index] or Vector(0, 0)
	return origin + off
end

--- 切换翻字：目的地暂时留在 icon 槽位原地，仅旧字做位移淡出。
local function render_selected_code(panel, selected, origin, alpha)
	alpha = alpha or 1
	local transition = panel.transition
	if not transition then
		local code = panel.display_code or (selected and selected.code) or "REMASTER"
		for i = 1, 8 do
			local ch = string.sub(code, i, i)
			if ch == "" then ch = "-" end
			render_code_char_at(ch, slot_screen_pos(origin, i), alpha, 1)
		end
		return
	end
	local now = ((Isaac.GetTime and Isaac.GetTime()) or 0) / 1000
	local dt = math.max(0, math.min(0.05, now - (transition.last_time or now)))
	transition.last_time = now
	local spacing = get_flip_spacing()
	local travel = 18
	local all_done = true
	local final_code = transition.final_code or panel.display_code or "REMASTER"

	for i = 1, 8 do
		local base = slot_screen_pos(origin, i)
		local slot = transition.slots[i]
		local settled = string.sub(final_code, i, i)
		if settled == "" then settled = "-" end
		if not slot then
			render_code_char_at(settled, base, alpha, 1)
		else
			local path = slot.path
			local seg_count = math.max(1, #path - 1)
			if slot.segment > seg_count then
				render_code_char_at(path[#path] or settled, base, alpha, 1)
			else
				all_done = false
				local dur = math.max(0.001, segment_duration(slot.segment, seg_count, spacing))
				local time_acc = (slot.progress or 0) * dur + dt
				while time_acc >= dur and slot.segment <= seg_count do
					time_acc = time_acc - dur
					slot.segment = slot.segment + 1
					if slot.segment <= seg_count then
						dur = math.max(0.001, segment_duration(slot.segment, seg_count, spacing))
					else
						break
					end
				end
				if slot.segment > seg_count then
					slot.progress = 0
					render_code_char_at(path[#path] or settled, base, alpha, 1)
				else
					slot.progress = time_acc / dur
					local p = math.max(0, math.min(1, slot.progress))
					local cur = path[slot.segment]
					local nxt = path[slot.segment + 1]
					local dir = slot.dir >= 0 and 1 or -1
					-- 旧字移出；新字目的地暂时留在槽位原地
					render_code_char_at(cur, base + Vector(0, dir * p * travel), alpha * (1 - p), 1 - p * 0.88)
					render_code_char_at(nxt, base, alpha * p, 0.12 + p * 0.88)
				end
			end
		end
	end
	if all_done then
		panel.display_code = final_code
		panel.transition = nil
	end
end

function render_tptron_panel(panel, selected)
	local spr = ensure_tptron_sprite()
	local sw, sh = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
	local origin, ui_alpha = panel_origin(panel, sw, sh)
	spr:SetFrame("Idle", 0)
	spr.Color = Color(1, 1, 1, ui_alpha)
	spr.Scale = Vector(1, 1)
	spr.Rotation = 0
	-- main → 八字 → cover（icon 层只提供槽位，不绘制占位图）
	spr:RenderLayer(TPTRON_LAYER_MAIN, origin, Vector.Zero, Vector.Zero)
	render_selected_code(panel, selected, origin, ui_alpha)
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
	open_panel(player, active_slot)
	return {Discharge = false, ShowAnim = false}
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	tick_cinematic()
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
						open_panel(player, ActiveSlot.SLOT_PRIMARY)
						break
					end
				end
			end
		end
		return
	end
	local player = panel.player
	if not player or not player:Exists() then
		close_panel()
		return
	end
	player.ControlsCooldown = math.max(player.ControlsCooldown, 2)
	if not player:IsHoldingItem() then
		player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
		play_remaster_lift_sfx()
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = PORTAL_EFFECT_VAR,
Function = function(_, ent)
	if not ent then return end
	local d = ent:GetData()
	if d[item.own_key.."portal"] then
		portal_tick(ent)
	end
	if d[item.own_key.."ghost"] then
		tick_ghost_walk_costume_sprites(ent)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_, name)
	if name ~= C.PORTAL_SHADER then return end
	if Game():IsPauseMenuOpen() then
		return {P1 = {0, 0, 0, 0}, P2 = {0, 0, 0, 0}}
	end
	return portal_shader_params_from_cine(item.cinematic)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_EFFECT_RENDER, params = PORTAL_EFFECT_VAR,
Function = function(_, ent)
	if not ent or not ent:GetData()[item.own_key.."ghost"] then return end
	local cancel = ghost_has_walk_composite(ent)
	emit_ghost_probe("pre_render", ent, {pre_cancel = cancel})
	-- PRE 返回 false 会跳过引擎默认绘制，且 POST_EFFECT_RENDER 不再触发；合成须在 PRE 内完成
	if cancel then
		render_ghost_walk_costumes(ent)
		return false
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = PORTAL_EFFECT_VAR,
Function = function(_, ent)
	if not ent or not ent:GetData()[item.own_key.."ghost"] then return end
	if ghost_has_walk_composite(ent) then return end
	render_ghost_walk_costumes(ent)
	render_ghost_held_sprite(ent)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	local panel = item.panel
	if not panel then return end
	if not panel.input_armed then
		if not menu_input_is_pressed() then panel.input_armed = true end
	else
		if is_action_triggered(ButtonAction.ACTION_MENUUP) then change_selection(-1) end
		if is_action_triggered(ButtonAction.ACTION_MENUDOWN) then change_selection(1) end
		if is_action_triggered(ButtonAction.ACTION_MENULEFT) then change_selection(-5) end
		if is_action_triggered(ButtonAction.ACTION_MENURIGHT) then change_selection(5) end
		if is_action_triggered(ButtonAction.ACTION_MENUCONFIRM) then
			travel_to_selected()
		elseif ctrl_cancel_triggered() then
			close_panel()
		end
	end
	panel = item.panel
	if not panel then return end
	local font = get_font()
	local selected = item.floor_targets[panel.index]
	local _, ui_alpha, sw, sh = render_tptron_panel(panel, selected)
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
		local app = item._force_return_emerge.appearance
		item._force_return_emerge = nil
		take_pending_fx()
		begin_return_emerge(Game():GetPlayer(0), app)
	elseif item._force_emerge and not item.cinematic then
		local app = item._force_emerge.appearance
		item._force_emerge = nil
		take_pending_fx()
		begin_outbound_emerge(Game():GetPlayer(0), app)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	try_clear_descent_lock_on_level_change()
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
	restore_party_familiars()
	local cine = item.cinematic
	if not cine or (cine.kind ~= "outbound_emerge" and cine.kind ~= "return_emerge" and cine.kind ~= "return") then
		local p = Game():GetPlayer(0)
		if p and p:Exists() then
			restore_party_player(p, true)
			if p.Visible == false then p.Visible = true end
			unfreeze_cinematic_player(p)
		end
	end
	try_trigger_return_channel()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_)
	if not item.cinematic then
		restore_cinematic_party_visibility(true)
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	item.panel = nil
	item.pending_reopen_until = nil
	clear_cinematic({clear_pending = true, fallback_visible = true})
	if not continue then
		reset_current_run_id()
		clear_descent_lock()
	else
		get_current_run_id()
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

return item

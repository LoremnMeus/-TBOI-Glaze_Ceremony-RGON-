local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local grid_wall = require("Qing_Remaster_scripts.grids.grid_wall")
local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Destiny_Anchor,
	own_key = "Item_Destiny_Anchor_",
	max_anchors = 3,
	marker_anm2 = "gfx/mimics/Destiny_Anchor/Anchor.anm2",
	gridpos_anm2 = "gfx/mimics/Destiny_Anchor/Gridpos.anm2",
	runtime_configs = {},
	current_floor_seed = nil,
	place_session = nil,
	pending_failure_notice = nil,
	-- body 底部距 pivot 48px：落地后 PositionOffset.Y=-48，使锚底落在实体 Position（地面）
	body_bottom = 48,
	chain_step = 28,
	chain_count = 7,
	chain_layer = 1,
	body_layer = 0,
	-- 屏外高度（PO 负向=向上）；收起比落下更高
	fall_height = 460,
	retract_height = 520,
	hang_frames = 10,
	drop_frames = 11,
	retract_hang_frames = 4,
	retract_frames = 14,
	marker_shader = temp_hud.RAINBOW_CELLULAR_SHADER,
	-- 彩虹 phase：默认 HUD 用 1200 帧几乎看不出动；锚/框线用短周期 + 离散步进
	marker_phase_cycle = 72,
	marker_phase_steps = 18,
	-- 1×1 holder 房（special rooms variant）；BR：goto s.default.25500
	holder_room_variant = 25500,
	holder_config_cache = nil,
	-- 复现房内收起后再锚定：暂存源身份+已烘焙快照，避免按 holder/25500 Spawns 重采丢内容
	reanchor_cache = {},
	-- 命运魂火：绑房、无接触伤；自管自动弹；配额每层最多 3（仅锚定消耗）
	wisp_damage = 1.25,
	wisp_fire_delay = 22,
	wisp_tear_speed = 9,
	wisp_range = 320,
	Colorinfo = {
		{frame = 0 * 12,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 12,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 12,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 12,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 12,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 12,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 6 * 12,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 12,
	},
}

local save_key = item.own_key.."floors"
local reproduced_key = item.own_key.."reproduced"
local force_devil_key = item.own_key.."force_devil_next"
local wisp_state_key = item.own_key.."wisp_states"
local wisp_quota_key = item.own_key.."wisp_quota"
local marker_key = item.own_key.."marker"
local marker_echo_key = item.own_key.."marker_echo"
local marker_hl_key = item.own_key.."marker_hl" -- 框线代理：DepthOffset 很低，盖地形、不盖物品
local wisp_flag_key = item.own_key.."destiny_wisp"
local wisp_stash_key = item.own_key.."wisp_stashing"
local HL_DEPTH = -800
local WISP_DEPTH = 120 -- 画在锚/链前面

local valid_room_types = {
	[RoomType.ROOM_DEFAULT] = true,
	[RoomType.ROOM_SHOP] = true,
	[RoomType.ROOM_TREASURE] = true,
	[RoomType.ROOM_BOSS] = true,
	[RoomType.ROOM_MINIBOSS] = true,
	[RoomType.ROOM_SECRET] = true,
	[RoomType.ROOM_SUPERSECRET] = true,
	[RoomType.ROOM_ARCADE] = true,
	[RoomType.ROOM_CURSE] = true,
	[RoomType.ROOM_CHALLENGE] = true,
	[RoomType.ROOM_LIBRARY] = true,
	[RoomType.ROOM_SACRIFICE] = true,
	[RoomType.ROOM_ISAACS] = true,
	[RoomType.ROOM_BARREN] = true,
	[RoomType.ROOM_CHEST] = true,
	[RoomType.ROOM_DICE] = true,
	[RoomType.ROOM_PLANETARIUM] = true,
	[RoomType.ROOM_ULTRASECRET] = true,
}

-- Boss 源锚点只映射到普通/奖励向房间，禁止盖下层 Boss。
local REWARD_TARGET_PRIORITY = {
	[RoomType.ROOM_DEFAULT] = 100,
	[RoomType.ROOM_TREASURE] = 90,
	[RoomType.ROOM_SHOP] = 85,
	[RoomType.ROOM_PLANETARIUM] = 85,
	[RoomType.ROOM_LIBRARY] = 80,
	[RoomType.ROOM_CHEST] = 80,
	[RoomType.ROOM_DICE] = 75,
	[RoomType.ROOM_ARCADE] = 75,
	[RoomType.ROOM_ISAACS] = 70,
	[RoomType.ROOM_BARREN] = 70,
}

local LEVEL_GRID_WIDTH = 13
-- 标准 1×1 可玩区（不含墙）：与 Destiny holder 房内 DestinyToken 铺法一致
local SNAP_W = 13 -- 原 11，外扩一圈；对齐 1×1 可玩宽
local SNAP_H = 7  -- 原 5，外扩一圈；对齐 1×1 可玩高
local GRID_TILE = 40
local GRIDPOS_BORDER = 8
local GRIDPOS_EDGE_H = 48
local GRIDPOS_EDGE_V = 48

local SNAPSHOT_GRID_TYPES = {}
do
	local names = {
		"GRID_DECORATION","GRID_ROCK","GRID_ROCKT","GRID_ROCK_BOMB","GRID_ROCK_ALT","GRID_ROCK_SS",
		"GRID_ROCK_SPIKED","GRID_ROCK_ALT2","GRID_ROCK_GOLD","GRID_ROCKB","GRID_PILLAR",
		"GRID_POOP","GRID_TNT","GRID_SPIKES","GRID_SPIKES_ONOFF","GRID_SPIDERWEB","GRID_PIT",
		"GRID_LOCK","GRID_PRESSURE_PLATE","GRID_STATUE","GRID_TELEPORTER",
		"GRID_TRAPDOOR","GRID_STAIRS","GRID_WALL","GRID_GRAVITY",
	}
	for _,name in ipairs(names) do
		local gt = GridEntityType[name]
		if gt ~= nil then SNAPSHOT_GRID_TYPES[gt] = true end
	end
end

-- 与 StageAPI.PoopVariant 数值一致（无 StageAPI 时也可走其表）
local POOP_VARIANT = {
	Normal = 0,
	Red = 1,
	Eternal = 2,
	Golden = 3,
	Rainbow = 4,
	Black = 5,
	White = 6,
	Charming = 11,
}

-- 本地兜底：与 stageapi15 `StageAPI.CorrectedGridTypes` 对齐（有 StageAPI 时优先用官方表）
local STB_TO_GRID_FALLBACK = {
	[0] = GridEntityType.GRID_DECORATION,
	[1000] = GridEntityType.GRID_ROCK,
	[1001] = GridEntityType.GRID_ROCK_BOMB,
	[1002] = GridEntityType.GRID_ROCK_ALT,
	[1008] = GridEntityType.GRID_ROCK_ALT2,
	[1010] = GridEntityType.GRID_ROCK_SPIKED,
	[1011] = GridEntityType.GRID_ROCK_GOLD,
	[1300] = GridEntityType.GRID_TNT,
	[1499] = {Type = GridEntityType.GRID_POOP,Variant = POOP_VARIANT.Normal}, -- giant, does not work
	[1498] = {Type = GridEntityType.GRID_POOP,Variant = POOP_VARIANT.White},
	[1497] = {Type = GridEntityType.GRID_POOP,Variant = POOP_VARIANT.Black},
	[1496] = {Type = GridEntityType.GRID_POOP,Variant = POOP_VARIANT.Golden},
	[1495] = {Type = GridEntityType.GRID_POOP,Variant = POOP_VARIANT.Eternal},
	[1494] = {Type = GridEntityType.GRID_POOP,Variant = POOP_VARIANT.Rainbow},
	[1490] = {Type = GridEntityType.GRID_POOP,Variant = POOP_VARIANT.Red},
	[1500] = GridEntityType.GRID_POOP,
	[1501] = {Type = GridEntityType.GRID_POOP,Variant = POOP_VARIANT.Charming},
	[1900] = GridEntityType.GRID_ROCKB,
	[1901] = GridEntityType.GRID_PILLAR,
	[1930] = GridEntityType.GRID_SPIKES,
	[1931] = GridEntityType.GRID_SPIKES_ONOFF,
	[1940] = GridEntityType.GRID_SPIDERWEB,
	[1999] = GridEntityType.GRID_WALL, -- invisible block（StageAPI 同向；勿当 NPC）
	[3000] = GridEntityType.GRID_PIT,
	[4000] = GridEntityType.GRID_LOCK,
	[4500] = GridEntityType.GRID_PRESSURE_PLATE,
	[5000] = GridEntityType.GRID_STATUE,
	[5001] = {Type = GridEntityType.GRID_STATUE,Variant = 1},
	[6100] = GridEntityType.GRID_TELEPORTER,
	[9000] = GridEntityType.GRID_TRAPDOOR,
	[9100] = GridEntityType.GRID_STAIRS,
	[10000] = GridEntityType.GRID_GRAVITY,
}

-- StageAPI.ConsoleSpawnedGridTypes：仍用 STB Type 调 GridSpawn，不能当 NPC
local STB_CONSOLE_GRID_FALLBACK = {
	[1009] = true, -- event rock
	[3009] = true, -- event pit
	[3002] = true, -- button rail
	[6000] = true, -- rail
	[6001] = true, -- rail over pit
}

-- StageAPI.UnsupportedTypes：元数据/水流等，禁止刷实体
local STB_UNSUPPORTED_ENTITY = {
	[969] = true, -- event triggers
	[970] = true, -- water flow / darkness / quest door 等
}

local function stb_corrected_grid_table()
	if StageAPI and StageAPI.Loaded and StageAPI.CorrectedGridTypes then
		return StageAPI.CorrectedGridTypes
	end
	return STB_TO_GRID_FALLBACK
end

local function stb_console_grid_table()
	if StageAPI and StageAPI.Loaded and StageAPI.ConsoleSpawnedGridTypes then
		return StageAPI.ConsoleSpawnedGridTypes
	end
	return STB_CONSOLE_GRID_FALLBACK
end

-- 兼容旧引用名
local STB_TO_GRID = STB_TO_GRID_FALLBACK

-- 挡路硬地形：连通修复时优先换成便便/火堆；便便本身视为已软化
local HARD_PATH_GRID = {}
do
	local names = {
		"GRID_ROCK","GRID_ROCKT","GRID_ROCK_BOMB","GRID_ROCK_ALT","GRID_ROCK_SS",
		"GRID_ROCK_SPIKED","GRID_ROCK_ALT2","GRID_ROCK_GOLD","GRID_ROCKB","GRID_PILLAR",
		"GRID_TNT","GRID_SPIKES","GRID_SPIKES_ONOFF","GRID_PIT","GRID_LOCK","GRID_STATUE",
	}
	for _,name in ipairs(names) do
		local gt = GridEntityType[name]
		if gt ~= nil then HARD_PATH_GRID[gt] = true end
	end
end

--- 与 capture_snapshot_1x1 同一套钳制，供落地后高亮框使用。
--- 奇数边长用 floor(N/2) 居中（11→左右各 5；旧 floor(N/2-ε) 会多偏左一格，锚显得偏右）。
--- 贴边钳制后，玩家格仍是该窗口下「最近可居中」的落点；锚实体优先落在玩家位置。
local function compute_snapshot_origin(pos)
	local room = Game():GetRoom()
	local wd = room:GetGridWidth()
	local ht = room:GetGridHeight()
	local pidx = room:GetGridIndex(pos)
	local px = pidx % wd
	local py = math.floor(pidx / wd)
	local ox = px - math.floor(SNAP_W / 2)
	local oy = py - math.floor(SNAP_H / 2)
	ox = math.max(1, math.min(ox, math.max(1, wd - 1 - SNAP_W)))
	oy = math.max(1, math.min(oy, math.max(1, ht - 1 - SNAP_H)))
	return ox,oy,wd,ht
end

local function floor_seed()
	return Game():GetLevel():GetDungeonPlacementSeed()
end

local function stageapi_loaded()
	return StageAPI and StageAPI.Loaded
end

local function get_floor_records(seed,create)
	save.elses[save_key] = save.elses[save_key] or {}
	local key = tostring(seed or floor_seed())
	if create then save.elses[save_key][key] = save.elses[save_key][key] or {} end
	return save.elses[save_key][key],key
end

local function get_reproduced_records(seed,create)
	save.elses[reproduced_key] = save.elses[reproduced_key] or {}
	local key = tostring(seed or floor_seed())
	if create then save.elses[reproduced_key][key] = save.elses[reproduced_key][key] or {} end
	return save.elses[reproduced_key][key],key
end

local function config_key(seed,safe_grid_index)
	return tostring(seed)..":"..tostring(safe_grid_index)
end

local function room_dimension(desc)
	-- 统一成 number，避免 Find 时 0 ~= 字符串/异常类型导致「有锚却不收起」
	local dim
	if REPENTOGON and desc and desc.GetDimension then
		dim = desc:GetDimension()
	else
		dim = auxi.GetDimension(desc)
	end
	return tonumber(dim) or 0
end

local function room_data(desc)
	return desc and (desc.OverrideData or desc.Data)
end

local function room_config_mode()
	-- RoomConfigRoom.Mode 在 RGON 中是坏掉的 userdata，禁止写入/回传。
	return Game():IsGreedMode() and 1 or 0
end

local function is_destiny_holder_config(data)
	return data ~= nil and tonumber(data.Variant) == item.holder_room_variant
end

local function reanchor_cache_key(sgid)
	return tostring(floor_seed())..":"..tostring(sgid)
end

local function stash_reanchor_payload(record,reproduced_entry)
	if not record then return end
	local sgid = tonumber(record.safe_grid_index)
	if sgid == nil then return end
	local snap = record.snapshot_1x1
	local gfx = record.room_gfx
	local source_sgid = record.source_safe_grid_index
	if reproduced_entry then
		if reproduced_entry.snapshot_1x1 then snap = reproduced_entry.snapshot_1x1 end
		if reproduced_entry.room_gfx then gfx = reproduced_entry.room_gfx end
		if reproduced_entry.source_safe_grid_index ~= nil then
			source_sgid = reproduced_entry.source_safe_grid_index
		end
	end
	if not snap then return end
	item.reanchor_cache[reanchor_cache_key(sgid)] = {
		snapshot_1x1 = snap,
		room_gfx = gfx,
		stage_id = record.stage_id,
		room_type = record.room_type,
		variant = record.variant,
		mode = record.mode,
		shape = record.shape,
		doors = record.doors,
		snapshot_only = record.snapshot_only == true or is_destiny_holder_config({Variant = record.variant}),
		devil_source = record.devil_source == true,
		source_safe_grid_index = source_sgid,
	}
end

local function take_reanchor_payload(sgid)
	local key = reanchor_cache_key(sgid)
	local payload = item.reanchor_cache[key]
	item.reanchor_cache[key] = nil
	return payload
end

local function is_stage_allowed()
	if Game():IsGreedMode() then return false, "greed" end
	local level = Game():GetLevel()
	if level:IsAscent() or level:IsPreAscent() then return false, "ascent" end
	if auxi.get_acceptible_level() >= 9 then return false, "late_stage" end
	return true, nil
end

local function player_has_belial(player)
	if not player then return false end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_BELIAL) then return true end
	if CollectibleType.COLLECTIBLE_BOOK_OF_BELIAL_PASSIVE
		and player:HasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_BELIAL_PASSIVE) then
		return true
	end
	return auxi.should_do_belial(player)
end

local function any_player_has_belial()
	for i = 0,Game():GetNumPlayers() - 1 do
		if player_has_belial(Game():GetPlayer(i)) then return true end
	end
	return false
end

local function is_devil_room_type(room_type)
	return room_type == RoomType.ROOM_DEVIL
end

local function is_anchorable(desc)
	local ok_stage, stage_reason = is_stage_allowed()
	if not ok_stage then return false, stage_reason end
	local data = room_data(desc)
	if not REPENTOGON then return false, "need_repentogon" end
	if not data then return false, "no_room_data" end
	local dim = room_dimension(desc)
	if dim ~= 0 then return false, "bad_dimension:"..tostring(dim) end
	local sgid = tonumber(desc and desc.SafeGridIndex)
	local devil = is_devil_room_type(data.Type)
	-- 恶魔房 SafeGridIndex 为 -1；仅彼列书允许锚定
	if devil then
		if not any_player_has_belial() then return false, "devil_need_belial" end
		if sgid == nil then return false, "bad_sgid" end
	else
		if sgid == nil or sgid < 0 then return false, "bad_sgid" end
		if valid_room_types[data.Type] ~= true then
			return false, "room_type:"..tostring(data.Type)
		end
	end
	return true, nil
end

local function find_record(records,safe_grid_index,dimension)
	local sgid = tonumber(safe_grid_index)
	local dim = tonumber(dimension) or 0
	if sgid == nil then return end
	for _,record in ipairs(records or {}) do
		if tonumber(record.safe_grid_index) == sgid and (tonumber(record.dimension) or 0) == dim then
			return record
		end
	end
end

local function current_room_ids()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	return {
		sgid = tonumber(desc and desc.SafeGridIndex),
		dim = room_dimension(desc),
		floor = floor_seed(),
	}
end

local function clear_destiny_markers()
	-- 引擎换房本就会清实体；此处仅作防御（luamod / 同帧残留），并非 MeusNIL 有「跨房不清理」标签
	for _,effect in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT,enums.Entities.ID_EFFECT_MeusNIL)) do
		local data = effect:GetData()
		if data[marker_key] or data[marker_hl_key] then
			effect:Remove()
		end
	end
end

local function bind_marker_room_ids(data,ids)
	if not data or not ids then return end
	data[item.own_key.."sgid"] = ids.sgid
	data[item.own_key.."dim"] = ids.dim
	data[item.own_key.."floor"] = ids.floor
	-- 仅跳过 Nil_holder 的「距玩家>1000 误杀」；与换房清理无关
	data.skip_nil_distance_cull = true
	data.removecd = 999999
end

local function marker_matches_room(data,ids)
	if not data or not ids then return false end
	if tonumber(data[item.own_key.."sgid"]) ~= tonumber(ids.sgid) then return false end
	if (tonumber(data[item.own_key.."dim"]) or 0) ~= (tonumber(ids.dim) or 0) then return false end
	if ids.floor ~= nil and data[item.own_key.."floor"] ~= nil and data[item.own_key.."floor"] ~= ids.floor then
		return false
	end
	return true
end

local function copy_backdrop_table(backdrop)
	if type(backdrop) == "number" then return backdrop end
	if type(backdrop) ~= "table" then return nil end
	local copy = {}
	for key,value in pairs(backdrop) do
		local value_type = type(value)
		if value_type == "string" or value_type == "number" or value_type == "boolean" then
			copy[key] = value
		elseif value_type == "table" then
			if value[1] and type(value[1]) == "string" then
				copy[key] = {}
				for index,entry in ipairs(value) do copy[key][index] = entry end
			elseif value[1] and type(value[1]) == "table" then
				copy[key] = {}
				for index,entry in ipairs(value) do
					copy[key][index] = copy_backdrop_table(entry) or {}
				end
			end
		end
	end
	return copy
end

local function serialize_backdrops(backdrops)
	if type(backdrops) == "number" then return backdrops end
	if type(backdrops) ~= "table" then return nil end
	if backdrops.WallAnm2 or backdrops.FloorAnm2 or backdrops.WallVariants or backdrops.FloorVariants then
		return copy_backdrop_table(backdrops)
	end
	local pool = {}
	for index,entry in ipairs(backdrops) do
		pool[index] = serialize_backdrops(entry)
	end
	if #pool > 0 then return pool end
	return copy_backdrop_table(backdrops)
end

-- 需要按层换石头皮肤的格类型（与 StageAPI.RockTypes 同向）
local ROCK_SHEET_TYPES = {}
do
	local names = {
		"GRID_ROCK","GRID_ROCKT","GRID_ROCK_BOMB","GRID_ROCK_ALT","GRID_ROCK_SS",
		"GRID_ROCK_SPIKED","GRID_ROCK_ALT2","GRID_ROCK_GOLD","GRID_ROCKB","GRID_PILLAR",
	}
	for _,name in ipairs(names) do
		local gt = GridEntityType[name]
		if gt ~= nil then ROCK_SHEET_TYPES[gt] = true end
	end
end

local function normalize_gfx_path(path)
	if type(path) ~= "string" or path == "" then return nil end
	local norm = path:gsub("\\","/")
	local lower = norm:lower()
	local idx = lower:find("gfx/",1,true)
	if idx then return norm:sub(idx) end
	return norm
end

local function capture_rock_sheet()
	if stageapi_loaded() and StageAPI.GetCurrentRoomGfx then
		local ok,room_gfx = pcall(StageAPI.GetCurrentRoomGfx)
		if ok and room_gfx and room_gfx.Grids and type(room_gfx.Grids.Rocks) == "string" then
			local p = normalize_gfx_path(room_gfx.Grids.Rocks)
			if p then return p end
		end
	end
	local ok,morpher = pcall(require,"Qing_Remaster_scripts.grids.grid_morpher")
	if ok and morpher and morpher.get_morph_dir then
		local info = morpher.get_morph_dir()
		if info and type(info.name) == "string" and info.name ~= "" then
			return info.name
		end
	end
	return "gfx/grid/rocks_basement.png"
end

local function capture_room_gfx()
	local room = Game():GetRoom()
	local gfx = {
		backdrop_type = room:GetBackdropType(),
		decoration_seed = room:GetDecorationSeed(),
		rock_sheet = capture_rock_sheet(),
	}
	if stageapi_loaded() and StageAPI.GetCurrentRoomGfx then
		local ok,room_gfx = pcall(StageAPI.GetCurrentRoomGfx)
		if ok and room_gfx and room_gfx.Backdrops then
			gfx.stageapi_backdrops = serialize_backdrops(room_gfx.Backdrops)
		end
	end
	return gfx
end

local function apply_room_gfx(gfx_record)
	if not gfx_record then return end
	local backdrops = gfx_record.stageapi_backdrops
	local grids = nil
	local rock = normalize_gfx_path(gfx_record.rock_sheet)
	if type(rock) == "string" and rock:find("gfx/",1,true) and rock:match("%.png$") then
		grids = {Rocks = rock,}
	end
	if backdrops then
		if stageapi_loaded() and StageAPI.ChangeRoomGfx then
			if gfx_record.decoration_seed and StageAPI.BackdropRNG then
				StageAPI.BackdropRNG:SetSeed(gfx_record.decoration_seed,0)
			end
			local payload = {Backdrops = backdrops,}
			if grids then payload.Grids = grids end
			pcall(StageAPI.ChangeRoomGfx,payload)
			return
		end
		if gfx_record.decoration_seed then
			grid_wall.BackdropRNG:SetSeed(gfx_record.decoration_seed,0)
		end
		local payload = {Backdrops = backdrops,}
		if grids then payload.Grids = grids end
		grid_wall.ChangeRoomGfx(payload)
		return
	end
	if gfx_record.backdrop_type ~= nil then
		grid_wall.ChangeBackdrop(gfx_record.backdrop_type)
	end
end

local function show_destiny_message(mode)
	local hud = Game():GetHUD()
	if not hud or not hud.ShowItemText then return end
	if mode == "snapshot" then mode = "echo" end
	if auxi.get_EID_language() == "zh_cn" then
		if mode == "echo" then
			hud:ShowItemText("命运锚点","命运发生了偏移……")
		elseif mode == "exact" then
			hud:ShowItemText("命运锚点","命运复现")
		else
			hud:ShowItemText("命运锚点","锚点未能复现")
		end
	else
		if mode == "echo" then
			hud:ShowItemText("Destiny Anchor","Fate has shifted...")
		elseif mode == "exact" then
			hud:ShowItemText("Destiny Anchor","Fate restored")
		else
			hud:ShowItemText("Destiny Anchor","Anchor failed to return")
		end
	end
end

local function marker_screen_pos(effect,offset)
	local room = Game():GetRoom()
	local world = effect.Position + (effect.PositionOffset or Vector(0,0))
	return Isaac.WorldToScreen(world)
		+ (offset or Vector(0,0))
		- room:GetRenderScrollOffset()
end

local function rest_po_y()
	return -(item.body_bottom or 48)
end

local function marker_shader_phase(phase_cycle)
	phase_cycle = math.max(1, math.floor(tonumber(phase_cycle) or item.marker_phase_cycle or 72))
	local steps = math.max(1, math.floor(tonumber(item.marker_phase_steps) or 18))
	local raw = (Game():GetFrameCount() % phase_cycle) / phase_cycle
	-- 离散档：色块像在「跳」而不是 40s 缓漂
	return math.floor(raw * steps + 1e-6) / steps
end

local function apply_marker_shader(sprite,data,effect,alpha_mul,phase_cycle)
	if not sprite then return end
	temp_hud.apply_sprite_shader(sprite,item.marker_shader)
	local seed = data and data[item.own_key.."shader_seed"] or 0.41
	if data and data[marker_echo_key] then
		seed = (seed + 0.17) % 1
	end
	alpha_mul = tonumber(alpha_mul) or 1
	phase_cycle = tonumber(phase_cycle) or item.marker_phase_cycle or 72
	local phase = marker_shader_phase(phase_cycle)
	local a = math.max(0,math.min(1,alpha_mul))
	local col = Color(1,1,1,a,0,0,0)
	if col.SetColorize then
		col:SetColorize(seed,0,0,phase)
	else
		col = Color(1,1,1,a,0,0,0,seed,0,0,phase)
	end
	sprite.Color = col
	if effect and effect.SetColor then
		effect:SetColor(col,-1,1,false,false)
	end
end

local function ensure_chain_sprite(data)
	local spr = data[item.own_key.."chain_spr"]
	if spr then return spr end
	spr = Sprite()
	spr:Load(item.marker_anm2,true)
	spr:Play("Idle",true)
	data[item.own_key.."chain_spr"] = spr
	return spr
end

local function ensure_gridpos_sprite(data)
	local spr = data[item.own_key.."gridpos_spr"]
	if spr then return spr end
	spr = Sprite()
	spr:Load(item.gridpos_anm2,true)
	spr:Play("CornerTL",true)
	data[item.own_key.."gridpos_spr"] = spr
	return spr
end

local function bind_snapshot_origin(data,snapshot_or_pos)
	if not data then return end
	if type(snapshot_or_pos) == "table" and snapshot_or_pos.origin_gx ~= nil then
		data[item.own_key.."snap_ox"] = snapshot_or_pos.origin_gx
		data[item.own_key.."snap_oy"] = snapshot_or_pos.origin_gy
		return
	end
	local ox,oy = compute_snapshot_origin(snapshot_or_pos or Vector.Zero)
	data[item.own_key.."snap_ox"] = ox
	data[item.own_key.."snap_oy"] = oy
end

local function highlight_alpha(data)
	local age = tonumber(data[item.own_key.."hl_age"]) or 0
	local fade = data[item.own_key.."hl_fade"]
	-- 淡入 ~14 帧；收起时 hl_fade 再乘淡出
	local appear = math.min(1,age / 14)
	appear = appear * appear * (3 - 2 * appear) -- smoothstep
	local pulse = 0.82 + 0.18 * (0.5 + 0.5 * math.sin(age * 0.11))
	local a = appear * pulse
	if fade ~= nil then
		local f = math.max(0,math.min(1,tonumber(fade) or 0))
		a = a * (f * f * (3 - 2 * f))
	end
	return a
end

--- 异形房：锚落地后用 Gridpos 九宫描边。
--- 边长必须用「角点屏幕距离 / 边贴图像素」算 Scale；世界长度当 Scale 会在右侧/下方拉出多余十字线。
local function render_capture_highlight(effect,data,offset)
	if not data then return end
	local phase = data[item.own_key.."phase"]
	if phase ~= "settled" and phase ~= "retract" then return end
	local room = Game():GetRoom()
	if room:GetRoomShape() == RoomShape.ROOMSHAPE_1x1 then return end
	local ox = data[item.own_key.."snap_ox"]
	local oy = data[item.own_key.."snap_oy"]
	if ox == nil or oy == nil then
		bind_snapshot_origin(data,effect.Position)
		ox = data[item.own_key.."snap_ox"]
		oy = data[item.own_key.."snap_oy"]
	end
	if ox == nil then return end

	local alpha = highlight_alpha(data)
	if alpha <= 0.01 then return end

	local wd = room:GetGridWidth()
	local tl = room:GetGridPosition(ox + oy * wd)
	local br = room:GetGridPosition((ox + SNAP_W - 1) + (oy + SNAP_H - 1) * wd)
	local half = GRID_TILE * 0.5
	local age = tonumber(data[item.own_key.."hl_age"]) or 0
	local fade = data[item.own_key.."hl_fade"]
	-- 呼吸外扩；出现略从小放大，收起略缩
	local breath = math.sin(age * 0.09) * 1.8
	local pop = 1
	if age < 14 then
		local t = age / 14
		pop = 0.88 + 0.12 * (t * t * (3 - 2 * t))
	elseif fade ~= nil then
		local f = math.max(0,math.min(1,tonumber(fade) or 0))
		pop = 0.92 + 0.08 * f
	end
	local pad = half + breath
	local x0,y0 = tl.X - pad,tl.Y - pad
	local x1,y1 = br.X + pad,br.Y + pad

	local function w2s(wx,wy)
		return Isaac.WorldToScreen(Vector(wx,wy))
			+ (offset or Vector(0,0))
			- room:GetRenderScrollOffset()
	end

	local tl_s = w2s(x0,y0)
	local tr_s = w2s(x1,y0)
	local bl_s = w2s(x0,y1)
	local br_s = w2s(x1,y1)
	-- 用对角两边取平均，避免大房间透视/滚动下单边偏长
	local screen_w = 0.5 * ((tr_s.X - tl_s.X) + (br_s.X - bl_s.X))
	local screen_h = 0.5 * ((bl_s.Y - tl_s.Y) + (br_s.Y - tr_s.Y))
	if screen_w < 4 or screen_h < 4 then return end

	local b = GRIDPOS_BORDER
	local inner_w = math.max(1,screen_w * pop - 2 * b)
	local inner_h = math.max(1,screen_h * pop - 2 * b)
	-- 角点随 pop 向中心收一点，与边长同步
	local mid = Vector((tl_s.X + br_s.X) * 0.5,(tl_s.Y + br_s.Y) * 0.5)
	local function pinch(p)
		return mid + (p - mid) * pop
	end
	tl_s,tr_s,bl_s,br_s = pinch(tl_s),pinch(tr_s),pinch(bl_s),pinch(br_s)

	local spr = ensure_gridpos_sprite(data)
	-- 先设 Scale=1 再上 shader 色；边线用原尺寸铺码，避免「着色后再大幅拉伸」拉花细胞
	spr.Scale = Vector(1,1)
	apply_marker_shader(spr,data,nil,alpha,item.marker_phase_cycle)

	local function draw(anim,pos,scx,scy)
		if spr:GetAnimation() ~= anim then spr:Play(anim,true) end
		spr.Scale = Vector(scx or 1,scy or 1)
		local piece_seed = (data[item.own_key.."shader_seed"] or 0.41)
			+ (string.byte(anim,1) or 0) * 0.017
			+ (string.byte(anim,#anim) or 0) * 0.011
		local col = Color(1,1,1,alpha,0,0,0)
		local ph = marker_shader_phase(item.marker_phase_cycle)
		if col.SetColorize then col:SetColorize(piece_seed % 1,0,0,ph) end
		spr.Color = col
		spr:Render(pos,Vector(0,0),Vector(0,0))
	end

	--- 水平边：尽量整段 48px 铺码，仅末段微调 Scale（减少 shader 拉伸）
	local function draw_edge_h(anim,x,y,total_w)
		local placed = 0
		local n = 0
		while placed < total_w - 0.05 do
			local remain = total_w - placed
			local use = math.min(GRIDPOS_EDGE_H,remain)
			local scx = use / GRIDPOS_EDGE_H
			draw(anim,Vector(x + placed,y),scx,1)
			placed = placed + use
			n = n + 1
			if n > 64 then break end
		end
	end

	local function draw_edge_v(anim,x,y,total_h)
		local placed = 0
		local n = 0
		while placed < total_h - 0.05 do
			local remain = total_h - placed
			local use = math.min(GRIDPOS_EDGE_V,remain)
			local scy = use / GRIDPOS_EDGE_V
			draw(anim,Vector(x,y + placed),1,scy)
			placed = placed + use
			n = n + 1
			if n > 64 then break end
		end
	end

	draw("CornerTL",tl_s,1,1)
	draw("CornerTR",tr_s,1,1)
	draw("CornerBL",bl_s,1,1)
	draw("CornerBR",br_s,1,1)
	draw_edge_h("EdgeTop",tl_s.X + b,tl_s.Y,inner_w)
	draw_edge_h("EdgeBottom",bl_s.X + b,bl_s.Y,inner_w)
	draw_edge_v("EdgeLeft",tl_s.X,tl_s.Y + b,inner_h)
	draw_edge_v("EdgeRight",tr_s.X,tr_s.Y + b,inner_h)
	spr.Scale = Vector(1,1)
end

local function play_land_fx(pos)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_STONE_IMPACT,1.05,0.85,false,0,1)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_ROCK_CRUMBLE,0.75,0.9,false,0,1)
	Game():ShakeScreen(11)
	-- 白/灰烟：POOF01（勿用 POOF02 物品生成 puff）
	for i = 0,1 do
		local smoke = Isaac.Spawn(
			EntityType.ENTITY_EFFECT,
			EffectVariant.POOF01,
			0,
			pos + Vector((i * 2 - 1) * 6, -2 - i),
			Vector(0,-0.15),
			nil
		)
		if smoke then
			smoke = smoke:ToEffect() or smoke
			smoke:SetColor(Color(0.82,0.8,0.78,1,0.35,0.35,0.32),24,1,false,false)
			local s = smoke:GetSprite()
			if s then s.Color = Color(0.85,0.82,0.8,1,0.25,0.25,0.22) end
			smoke.SpriteScale = Vector(1.35 + i * 0.2,1.05 + i * 0.1)
			local life = 18
			if smoke.LifeSpan ~= nil then smoke.LifeSpan = life end
			if smoke.Timeout ~= nil then smoke.Timeout = life end
			smoke.DepthOffset = -15
		end
	end
	-- 径向扬尘：DUST_CLOUD
	local n = 9
	for i = 1,n do
		local ang = (360 / n) * (i - 1) + (i * 13) % 17
		local dir = auxi.MakeVector(ang):Resized(1.6 + (i % 4) * 0.45)
		local dust = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.DUST_CLOUD,0,pos + Vector(0,-1),dir,nil)
		if dust then
			dust = dust:ToEffect() or dust
			dust:SetColor(Color(0.58,0.52,0.44,0.9,0.05,0.04,0.03),-1,0,false,false)
			local sc = 0.55 + (i % 4) * 0.12
			dust.SpriteScale = Vector(sc,sc)
			local life = 14 + (i % 5)
			if dust.LifeSpan ~= nil then dust.LifeSpan = life end
			if dust.Timeout ~= nil then dust.Timeout = life end
			dust.DepthOffset = -18
		end
	end
end

--- 锚与整条链共用同一 root（含 PositionOffset），整组一起下落/收起。
local function render_marker_chains(effect,data,offset)
	local chain_spr = ensure_chain_sprite(data)
	apply_marker_shader(chain_spr,data)
	local root = marker_screen_pos(effect,offset)
	local step = item.chain_step
	local max_n = item.chain_count
	local frame = Game():GetFrameCount()
	local sway_seed = (data[item.own_key.."sway_seed"] or 0.3) * 6.283185307
	local phase = data[item.own_key.."phase"]
	local sway_mul = 0.12
	if phase == "settled" then
		sway_mul = 1
	elseif phase == "hang" then
		sway_mul = 0.35
	end
	for i = 0,max_n - 1 do
		local height_mul = i / math.max(1,max_n - 1)
		local sway = math.sin(frame * 0.07 + sway_seed + i * 0.55) * (1.2 + 3.5 * height_mul) * sway_mul
		local pos = root + Vector(sway,-i * step)
		if chain_spr.RenderLayer then
			chain_spr:RenderLayer(item.chain_layer,pos,Vector(0,0),Vector(0,0))
		end
	end
end

local function render_marker_body(effect,sprite,offset)
	local pos = marker_screen_pos(effect,offset)
	if sprite.RenderLayer then
		sprite:RenderLayer(item.body_layer,pos,Vector(0,0),Vector(0,0))
	else
		sprite:Render(pos,Vector(0,0),Vector(0,0))
	end
end

local function marker_po_y(effect)
	local po = effect and effect.PositionOffset
	return (po and po.Y) or rest_po_y()
end

--- 从当前高度接到落下（收起中途再锚定不会瞬移）。
local function begin_drop_motion(effect,data,from_y)
	local rest = rest_po_y()
	local fall_h = item.fall_height
	from_y = tonumber(from_y) or (rest - fall_h)
	if from_y > rest then from_y = rest end
	data[item.own_key.."phase"] = "drop"
	data[item.own_key.."settled"] = false
	data[item.own_key.."fall_from"] = from_y
	data[item.own_key.."fall_frame"] = 0
	data[item.own_key.."retract_frame"] = nil
	data[item.own_key.."retract_from"] = nil
	data[item.own_key.."hl_fade"] = nil
	-- 仍在空中则落地特效可再播；贴地接续不重播
	if from_y < rest - 6 then
		data[item.own_key.."landed"] = false
		data[item.own_key.."hl_age"] = nil
	end
	effect.PositionOffset = Vector(0,from_y)
end

--- 从当前高度接到收起（下落中途收起不会先弹回 rest）。
local function begin_retract_motion(effect,data)
	local rest = rest_po_y()
	local cur = marker_po_y(effect)
	data[item.own_key.."phase"] = "retract"
	data[item.own_key.."retract_from"] = cur
	data[item.own_key.."retract_frame"] = 0
	data[item.own_key.."fall_frame"] = nil
	data[item.own_key.."fall_from"] = nil
	data[item.own_key.."hl_fade"] = 1
	data[item.own_key.."settled"] = true
	effect.PositionOffset = Vector(0,cur)
end

local function tick_marker_motion(effect,data)
	local rest = rest_po_y()
	local fall_h = item.fall_height
	local phase = data[item.own_key.."phase"] or "settled"

	if phase == "retract" then
		local f = (data[item.own_key.."retract_frame"] or 0) + 1
		data[item.own_key.."retract_frame"] = f
		local from_y = tonumber(data[item.own_key.."retract_from"]) or rest
		local end_y = rest - item.retract_height
		-- 贴地收起才短停；空中打断直接上抽
		local hang = (from_y >= rest - 2) and item.retract_hang_frames or 0
		local fade = 1 - math.min(1,(f - 1) / 16)
		data[item.own_key.."hl_fade"] = fade
		if f <= hang then
			effect.PositionOffset = Vector(0,from_y)
			return
		end
		local t = math.min(1,(f - hang) / math.max(1,item.retract_frames))
		local e = t * t
		effect.PositionOffset = Vector(0,from_y + (end_y - from_y) * e)
		if t >= 1 then
			local proxy = data[item.own_key.."hl_proxy"]
			if proxy and proxy.Exists and proxy:Exists() then proxy:Remove() end
			data[item.own_key.."hl_proxy"] = nil
			effect:Remove()
		end
		return
	end

	if phase == "settled" then
		effect.PositionOffset = Vector(0,rest)
		data[item.own_key.."hl_age"] = (tonumber(data[item.own_key.."hl_age"]) or 0) + 1
		data[item.own_key.."hl_fade"] = nil
		return
	end

	-- hang / drop：从 fall_from 插值到 rest（支持中途接入）
	local from_y = tonumber(data[item.own_key.."fall_from"]) or (rest - fall_h)
	local f = (data[item.own_key.."fall_frame"] or 0) + 1
	data[item.own_key.."fall_frame"] = f
	-- 仅从「屏外顶点」开落时保留 hang；中途接入直接砸
	local hang = 0
	if from_y <= (rest - fall_h) + 2 then
		hang = item.hang_frames
	end
	if f <= hang then
		data[item.own_key.."phase"] = "hang"
		effect.PositionOffset = Vector(0,from_y)
		return
	end
	data[item.own_key.."phase"] = "drop"
	local t = math.min(1,(f - hang) / math.max(1,item.drop_frames))
	local e = t * t * t
	local y = from_y + (rest - from_y) * e
	effect.PositionOffset = Vector(0,y)
	if t >= 1 then
		effect.PositionOffset = Vector(0,rest)
		data[item.own_key.."phase"] = "settled"
		data[item.own_key.."settled"] = true
		data[item.own_key.."hl_age"] = 0
		data[item.own_key.."hl_fade"] = nil
		if not data[item.own_key.."landed"] then
			data[item.own_key.."landed"] = true
			play_land_fx(effect.Position)
		end
	end
end

local function ensure_hl_proxy(marker,data)
	if not marker or not data then return end
	local phase = data[item.own_key.."phase"]
	if phase ~= "settled" and phase ~= "retract" then
		local old = data[item.own_key.."hl_proxy"]
		if old and old.Exists and old:Exists() then old:Remove() end
		data[item.own_key.."hl_proxy"] = nil
		return
	end
	local proxy = data[item.own_key.."hl_proxy"]
	if proxy and proxy.Exists and proxy:Exists() and proxy:GetData()[marker_hl_key] then
		proxy.Position = marker.Position
		proxy.DepthOffset = HL_DEPTH
		if proxy.SortingLayer ~= nil then
			local layer = 2
			if SortingLayer and SortingLayer.SORTING_NORMAL ~= nil then
				layer = SortingLayer.SORTING_NORMAL
			end
			proxy.SortingLayer = layer
		end
		local pd = proxy:GetData()
		pd[item.own_key.."link_ptr"] = GetPtrHash(marker)
		pd.removecd = 999999
		pd.skip_nil_distance_cull = true
		return proxy
	end
	proxy = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		enums.Entities.ID_EFFECT_MeusNIL,
		0,
		marker.Position,
		Vector.Zero,
		nil
	)
	if not proxy then return end
	proxy = proxy:ToEffect() or proxy
	proxy.DepthOffset = HL_DEPTH
	if proxy.SortingLayer ~= nil then
		local layer = 2
		if SortingLayer and SortingLayer.SORTING_NORMAL ~= nil then
			layer = SortingLayer.SORTING_NORMAL
		end
		proxy.SortingLayer = layer
	end
	proxy.PositionOffset = Vector(0,0)
	local pd = proxy:GetData()
	pd[marker_hl_key] = true
	pd[item.own_key.."link_ptr"] = GetPtrHash(marker)
	pd.removecd = 999999
	pd.skip_nil_distance_cull = true
	-- 不播默认贴图
	local spr = proxy:GetSprite()
	if spr then
		spr.Color = Color(1,1,1,0,0,0,0)
		if spr.Load then spr:Load(item.marker_anm2,true) end
	end
	data[item.own_key.."hl_proxy"] = proxy
	return proxy
end

local function find_marker_for_hl(proxy_data)
	local want = proxy_data and proxy_data[item.own_key.."link_ptr"]
	if not want then return nil,nil end
	for _,effect in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT,enums.Entities.ID_EFFECT_MeusNIL)) do
		local data = effect:GetData()
		if data[marker_key] and GetPtrHash(effect) == want then
			return effect,data
		end
	end
	return nil,nil
end

local function spawn_marker(position,appear,echo,snapshot,room_ids)
	-- 锚优先落在玩家位置；采集窗以玩家格为中心（贴边钳制后即「最近可居中」窗口）
	local anchor_pos = position
	room_ids = room_ids or current_room_ids()

	for _,effect in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT,enums.Entities.ID_EFFECT_MeusNIL)) do
		local data = effect:GetData()
		if data[marker_key] and data[marker_echo_key] == (echo and true or false)
			and marker_matches_room(data,room_ids) then
			-- 同房连拍：复用实体，从当前高度平滑接入落下
			if snapshot then bind_snapshot_origin(data,snapshot) else bind_snapshot_origin(data,position) end
			effect.Position = anchor_pos
			bind_marker_room_ids(data,room_ids)
			if appear then
				begin_drop_motion(effect,data,marker_po_y(effect))
			end
			ensure_hl_proxy(effect,data)
			return effect
		end
	end
	local effect = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		enums.Entities.ID_EFFECT_MeusNIL,
		0,
		anchor_pos,
		Vector.Zero,
		nil
	):ToEffect()
	if not effect then return end
	local data = effect:GetData()
	data[marker_key] = true
	data[marker_echo_key] = echo and true or false
	bind_marker_room_ids(data,room_ids)
	data[item.own_key.."settled"] = appear ~= true
	data[item.own_key.."landed"] = appear ~= true
	data[item.own_key.."shader_seed"] = ((anchor_pos.X * 0.013 + anchor_pos.Y * 0.007) % 1)
	data[item.own_key.."sway_seed"] = ((anchor_pos.X * 0.019 + anchor_pos.Y * 0.011) % 1)
	data[item.own_key.."hl_age"] = appear and nil or 8
	data[item.own_key.."hl_fade"] = nil
	if snapshot then
		bind_snapshot_origin(data,snapshot)
	else
		bind_snapshot_origin(data,position)
	end
	local sprite = effect:GetSprite()
	sprite:Load(item.marker_anm2,true)
	sprite:Play("Idle",true)
	if sprite.GetLayer and sprite:GetLayer(item.chain_layer) then
		pcall(function() sprite:GetLayer(item.chain_layer):SetVisible(false) end)
	end
	apply_marker_shader(sprite,data,effect)
	local rest = rest_po_y()
	if appear then
		begin_drop_motion(effect,data,rest - item.fall_height)
	else
		data[item.own_key.."phase"] = "settled"
		effect.PositionOffset = Vector(0,rest)
		ensure_hl_proxy(effect,data)
	end
	effect.DepthOffset = -20
	return effect
end

local function begin_retract_markers(echo)
	-- echo == nil：收起本房全部标记（含 carried/echo）；否则只收匹配 echo 的
	local ids = current_room_ids()
	local filter_echo = echo ~= nil
	local echo_flag = echo and true or false
	for _,effect in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT,enums.Entities.ID_EFFECT_MeusNIL)) do
		local data = effect:GetData()
		if data[marker_key] and marker_matches_room(data,ids)
			and ((not filter_echo) or data[marker_echo_key] == echo_flag) then
			if data[item.own_key.."phase"] ~= "retract" then
				begin_retract_motion(effect,data)
			end
			ensure_hl_proxy(effect,data)
		end
	end
end

local function find_destiny_marker_in_room()
	local ids = current_room_ids()
	for _,effect in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT,enums.Entities.ID_EFFECT_MeusNIL)) do
		local data = effect:GetData()
		if data[marker_key] and marker_matches_room(data,ids) then
			return effect,data
		end
	end
end

local function count_destiny_wisps()
	local n = 0
	for _,ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR,FamiliarVariant.WISP,item.entity,false,false)) do
		if ent and ent:Exists() and not ent:IsDead() then
			n = n + 1
		end
	end
	return n
end

local function wisp_room_key(sgid,dim)
	return tostring(sgid)..":"..tostring(tonumber(dim) or 0)
end

local function get_wisp_state_bucket(seed,create)
	save.elses[wisp_state_key] = save.elses[wisp_state_key] or {}
	local key = tostring(seed or floor_seed())
	if create then
		save.elses[wisp_state_key][key] = save.elses[wisp_state_key][key] or {}
	end
	return save.elses[wisp_state_key][key]
end

local function get_wisp_state(seed,sgid,dim)
	local bucket = get_wisp_state_bucket(seed,false)
	if not bucket or sgid == nil then return nil end
	return bucket[wisp_room_key(sgid,dim)]
end

local function set_wisp_state(seed,sgid,dim,state)
	if sgid == nil then return end
	local bucket = get_wisp_state_bucket(seed,true)
	bucket[wisp_room_key(sgid,dim)] = state
end

local function get_wisp_quota(seed)
	save.elses[wisp_quota_key] = save.elses[wisp_quota_key] or {}
	return tonumber(save.elses[wisp_quota_key][tostring(seed or floor_seed())]) or 0
end

local function add_wisp_quota(seed,delta)
	save.elses[wisp_quota_key] = save.elses[wisp_quota_key] or {}
	local key = tostring(seed or floor_seed())
	local next_v = math.max(0,(tonumber(save.elses[wisp_quota_key][key]) or 0) + (delta or 1))
	save.elses[wisp_quota_key][key] = next_v
	return next_v
end

local function apply_destiny_wisp_look(wisp)
	if not wisp then return end
	local d = wisp:GetData()
	d[wisp_flag_key] = true
	-- 无接触伤害；原版射击用 FireCooldown 压掉，改自管弹
	wisp.CollisionDamage = 0
	wisp.DepthOffset = WISP_DEPTH
	if wisp.FireCooldown ~= nil then
		wisp.FireCooldown = 999999
	end
	local col = auxi.table2color(auxi.check_lerp(Game():GetFrameCount() % item.Colorinfo.total,item.Colorinfo))
	local spr = wisp:GetSprite()
	if spr then spr.Color = col end
end

local function bind_destiny_wisp(wisp,ids,hp)
	if not wisp or not ids then return end
	apply_destiny_wisp_look(wisp)
	local d = wisp:GetData()
	d[item.own_key.."wisp_sgid"] = ids.sgid
	d[item.own_key.."wisp_dim"] = ids.dim
	d[item.own_key.."wisp_floor"] = ids.floor
	d[item.own_key.."wisp_fire_cd"] = 0
	if hp ~= nil and wisp.MaxHitPoints then
		wisp.HitPoints = math.max(0.1,math.min(wisp.MaxHitPoints,tonumber(hp) or wisp.MaxHitPoints))
	end
end

local function mark_wisp_extinguished(seed,sgid,dim)
	set_wisp_state(seed,sgid,dim,{
		extinguished = true,
	})
end

local function extinguish_destiny_wisps_in_room(sgid,dim)
	local ids = current_room_ids()
	sgid = sgid ~= nil and sgid or ids.sgid
	dim = dim ~= nil and dim or ids.dim
	mark_wisp_extinguished(ids.floor,sgid,dim)
	for _,ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR,FamiliarVariant.WISP,item.entity,false,false)) do
		if ent and ent:Exists() then
			local d = ent:GetData()
			if tonumber(d[item.own_key.."wisp_sgid"]) == tonumber(sgid)
				and (tonumber(d[item.own_key.."wisp_dim"]) or 0) == (tonumber(dim) or 0) then
				d[wisp_stash_key] = true
				ent:Remove()
			end
		end
	end
end

--- 离房：写入未熄灭魂火的 HP，并移除实体（不改变 extinguished）。
local function stash_and_remove_destiny_wisps()
	for _,ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR,FamiliarVariant.WISP,item.entity,false,false)) do
		if ent and ent:Exists() then
			local d = ent:GetData()
			if d[wisp_stash_key] then
				-- already handled
			else
				local sgid = tonumber(d[item.own_key.."wisp_sgid"])
				local dim = tonumber(d[item.own_key.."wisp_dim"]) or 0
				local floor = d[item.own_key.."wisp_floor"] or floor_seed()
				local prev = get_wisp_state(floor,sgid,dim)
				if prev and prev.extinguished then
					-- keep extinguished
				elseif sgid ~= nil and ent:Exists() and not ent:IsDead() then
					set_wisp_state(floor,sgid,dim,{
						extinguished = false,
						hp = ent.HitPoints,
						max_hp = ent.MaxHitPoints,
					})
				end
				d[wisp_stash_key] = true
				ent:Remove()
			end
		end
	end
end

local function spawn_destiny_wisp_entity(player,pos,ids,hp)
	if not player then return nil end
	local spawn_pos = pos or player.Position
	local marker = find_destiny_marker_in_room()
	if marker then spawn_pos = marker.Position end
	-- 允许本帧 AddWisp；顺带挡掉美德书在收回/失败时自动刷的多余魂火
	item.wisp_spawn_budget = (item.wisp_spawn_budget or 0) + 1
	local wisp = player:AddWisp(item.entity,spawn_pos,false,false)
	if not wisp then
		item.wisp_spawn_budget = math.max(0,(item.wisp_spawn_budget or 1) - 1)
		return nil
	end
	bind_destiny_wisp(wisp,ids,hp)
	return wisp
end

--- 仅「成功建立新锚」时调用；消耗本层配额。收回/离房再生不得走这里。
local function try_spawn_destiny_wisp(player,pos,use_flags)
	if not player or not auxi.should_spawn_wisp(player,use_flags) then return end
	local floor = floor_seed()
	if get_wisp_quota(floor) >= item.max_anchors then return end
	local ids = current_room_ids()
	local wisp = spawn_destiny_wisp_entity(player,pos,ids,nil)
	if not wisp then return end
	add_wisp_quota(floor,1)
	set_wisp_state(floor,ids.sgid,ids.dim,{
		extinguished = false,
		hp = wisp.HitPoints,
		max_hp = wisp.MaxHitPoints,
	})
	return wisp
end

--- 回房 / 复现：不耗配额。state.extinguished 则跳过。
local function respawn_destiny_wisp_from_state(player,heal_full)
	local ids = current_room_ids()
	local state = get_wisp_state(ids.floor,ids.sgid,ids.dim)
	if not state or state.extinguished then return end
	if count_destiny_wisps() > 0 then
		if heal_full then
			for _,ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR,FamiliarVariant.WISP,item.entity,false,false)) do
				if ent and ent:Exists() and not ent:IsDead() then
					ent.HitPoints = ent.MaxHitPoints
					apply_destiny_wisp_look(ent)
				end
			end
		end
		return
	end
	local hp = heal_full and nil or state.hp
	local wisp = spawn_destiny_wisp_entity(player,player and player.Position,ids,hp)
	if wisp and heal_full then
		wisp.HitPoints = wisp.MaxHitPoints
	end
	if wisp then
		set_wisp_state(ids.floor,ids.sgid,ids.dim,{
			extinguished = false,
			hp = wisp.HitPoints,
			max_hp = wisp.MaxHitPoints,
		})
	end
	return wisp
end

local function heal_destiny_wisps()
	for _,ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR,FamiliarVariant.WISP,item.entity,false,false)) do
		if ent and ent:Exists() and not ent:IsDead() then
			ent.HitPoints = ent.MaxHitPoints
			apply_destiny_wisp_look(ent)
			local d = ent:GetData()
			local sgid = tonumber(d[item.own_key.."wisp_sgid"])
			local dim = tonumber(d[item.own_key.."wisp_dim"]) or 0
			local floor = d[item.own_key.."wisp_floor"] or floor_seed()
			if sgid ~= nil then
				set_wisp_state(floor,sgid,dim,{
					extinguished = false,
					hp = ent.HitPoints,
					max_hp = ent.MaxHitPoints,
				})
			end
		end
	end
end

--- 下层复现：源房未熄灭 → 目标房满血可生成（不耗新层配额）。
local function transfer_wisp_state_on_reproduce(record,target_sgid)
	local source_seed = item.reproduce_source_seed
	if not source_seed or not record or target_sgid == nil then return end
	local src = get_wisp_state(source_seed,record.safe_grid_index,record.dimension or 0)
	if not src or src.extinguished then return end
	set_wisp_state(floor_seed(),target_sgid,0,{
		extinguished = false,
		hp = nil,
		max_hp = src.max_hp,
		full = true,
	})
end

local function destiny_wisp_try_fire(wisp)
	local d = wisp:GetData()
	local cd = tonumber(d[item.own_key.."wisp_fire_cd"]) or 0
	if cd > 0 then
		d[item.own_key.."wisp_fire_cd"] = cd - 1
		return
	end
	local target = auxi.get_nearest_enemy(nil,wisp.Position)
	if not target or not target:Exists() or target:IsDead() then return end
	local dist = (target.Position - wisp.Position):Length()
	if dist > item.wisp_range or dist < 0.5 then return end
	local dir = (target.Position - wisp.Position):Normalized()
	local tear = Isaac.Spawn(
		EntityType.ENTITY_TEAR,
		TearVariant.BLUE,
		0,
		wisp.Position,
		dir * item.wisp_tear_speed,
		wisp
	):ToTear()
	if not tear then return end
	tear.CollisionDamage = item.wisp_damage
	tear.Scale = 0.55
	tear.Height = -23
	local col = auxi.table2color(auxi.check_lerp(Game():GetFrameCount() % item.Colorinfo.total,item.Colorinfo))
	tear.Color = col
	d[item.own_key.."wisp_fire_cd"] = item.wisp_fire_delay
end

local function devil_room_idx()
	return (GridRooms and GridRooms.ROOM_DEVIL_IDX) or -1
end

--- 保证本层有恶魔房（若已锁天使则清掉重 roll 为恶魔）。返回 RoomDescriptor, idx。
local function ensure_devil_room_desc()
	local level = Game():GetLevel()
	local idx = devil_room_idx()
	local desc = level:GetRoomByIdx(idx)
	local data = room_data(desc)
	if data and data.Type == RoomType.ROOM_DEVIL then
		return desc,idx
	end
	if desc then
		desc.Data = nil
		if desc.OverrideData ~= nil then desc.OverrideData = nil end
	end
	pcall(function() level:InitializeDevilAngelRoom(false,true) end)
	return level:GetRoomByIdx(idx),idx
end

local function remove_floor_record(safe_grid_index,dimension)
	local records = get_floor_records(nil,false)
	if not records then return nil end
	local sgid = tonumber(safe_grid_index)
	local dim = tonumber(dimension) or 0
	for i,record in ipairs(records) do
		if tonumber(record.safe_grid_index) == sgid and (tonumber(record.dimension) or 0) == dim then
			local removed = table.remove(records,i)
			item.runtime_configs[config_key(floor_seed(),sgid)] = nil
			local reproduced = get_reproduced_records(nil,false)
			local entry = reproduced and (reproduced[sgid] or reproduced[tostring(sgid)])
			-- 收起前暂存：复现房再锚定时不能改采 holder Spawns
			stash_reanchor_payload(removed,entry)
			if reproduced then
				reproduced[sgid] = nil
				reproduced[tostring(sgid)] = nil
			end
			return removed
		end
	end
end

local function marker_world_pos(record)
	local room = Game():GetRoom()
	if not room or not record then
		return Game():GetRoom():GetCenterPos()
	end
	local pos_info = record.position or {}
	local snap = record.snapshot_1x1
	local wd = room:GetGridWidth()

	-- 跨层携带：用相对格重算。snapshot/echo→holder(1,1)；exact→快照 origin（与源房同格）
	if record.carried or record.echo then
		if pos_info.rel_rx ~= nil and pos_info.rel_ry ~= nil then
			local use_holder = record.echo == true
				or record.snapshot_only == true
				or record.reproduction_mode == "snapshot"
				or record.reproduction_mode == "echo"
			local gx,gy
			if use_holder then
				gx = math.max(1,math.min(wd - 2,1 + (tonumber(pos_info.rel_rx) or 0)))
				gy = math.max(1,math.min(room:GetGridHeight() - 2,1 + (tonumber(pos_info.rel_ry) or 0)))
			else
				local ox = tonumber(snap and snap.origin_gx) or 1
				local oy = tonumber(snap and snap.origin_gy) or 1
				gx = math.max(1,math.min(wd - 2,ox + (tonumber(pos_info.rel_rx) or 0)))
				gy = math.max(1,math.min(room:GetGridHeight() - 2,oy + (tonumber(pos_info.rel_ry) or 0)))
			end
			local pos = room:GetGridPosition(gx + gy * wd)
			if room:IsPositionInRoom(pos,0) then return pos end
		end
		return room:GetCenterPos()
	end
	if pos_info.grid_index ~= nil then
		local gidx = tonumber(pos_info.grid_index)
		if gidx and gidx >= 0 and gidx < room:GetGridSize() then
			local pos = room:GetGridPosition(gidx)
			if room:IsPositionInRoom(pos,0) then return pos end
		end
	end
	local pos = Vector(tonumber(pos_info.X) or 0,tonumber(pos_info.Y) or 0)
	if room:IsPositionInRoom(pos,0) then return pos end
	return room:GetCenterPos()
end

local function resolve_stb_grid(tp,vr,_st)
	if tp == nil then return nil end
	local console = stb_console_grid_table()
	if console[tp] then
		-- StageAPI：ConsoleSpawned 仍用 STB Type 调 GridSpawn
		return tp,vr or 0,true
	end
	local mapped = stb_corrected_grid_table()[tp]
	if mapped == nil then return nil end
	if type(mapped) == "table" then
		local gt = mapped.Type
		if not SNAPSHOT_GRID_TYPES[gt] and gt ~= GridEntityType.GRID_WALL and gt ~= GridEntityType.GRID_GRAVITY then
			return nil
		end
		return gt,mapped.Variant or vr or 0,false
	end
	if not SNAPSHOT_GRID_TYPES[mapped]
		and mapped ~= GridEntityType.GRID_WALL
		and mapped ~= GridEntityType.GRID_GRAVITY then
		return nil
	end
	return mapped,vr or 0,false
end

local function remap_stb_entity(tp,vr,st)
	-- StageAPI 同向：火堆在 STB 里是 1400/1410，不是 EntityType.ENTITY_FIREPLACE
	if tp == 1400 then return EntityType.ENTITY_FIREPLACE,0,st or 0 end
	if tp == 1410 then return EntityType.ENTITY_FIREPLACE,1,st or 0 end
	-- StageAPI layout：999→Effect 1000；3001→裂缝特效（此处跳过，不当 NPC）
	if tp == 999 or tp == 3001 then return nil end
	return tp,vr or 0,st or 0
end

local function should_keep_spawn_entry(tp,vr,_st)
	if not tp or tp <= 0 then return false end
	if stb_corrected_grid_table()[tp] then return false end
	if stb_console_grid_table()[tp] then return false end
	if STB_UNSUPPORTED_ENTITY[tp] then return false end
	-- 未映射的 STB 格类型（≥1000，除火堆）禁止当 NPC 刷，否则无 entity config 会崩
	if tp >= 1000 and tp ~= 1400 and tp ~= 1410 then return false end
	if tp == 999 or tp == 3001 then return false end
	if tp == EntityType.ENTITY_PLAYER then return false end
	if tp == EntityType.ENTITY_TEAR or tp == EntityType.ENTITY_LASER then return false end
	if tp == EntityType.ENTITY_KNIFE or tp == EntityType.ENTITY_PROJECTILE then return false end
	if tp == EntityType.ENTITY_EFFECT or tp == EntityType.ENTITY_FAMILIAR then return false end
	if tp == 303 then
		if vr == enums.Enemies.DestinyToken or vr == enums.Enemies.RemoverToken
			or vr == enums.Enemies.ShadowToken or vr == enums.Enemies.ZToken then
			return false
		end
	end
	return true
end

--- 从房间配置 Spawns 取初始分布（非运行时活体）；坐标为 STB 可玩格 X/Y → 房间格 (X+1,Y+1)
local function capture_spawns_from_room_config(ox,oy)
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local data = room_data(desc)
	local spawns = data and data.Spawns
	if not spawns or not spawns.Size then return {},{} end
	local entities,grids = {},{}
	local size = spawns.Size
	for i = 0,size - 1 do
		local info = spawns:Get(i)
		if info and info.X ~= nil and info.Y ~= nil then
			local gx = info.X + 1
			local gy = info.Y + 1
			local rx = gx - ox
			local ry = gy - oy
			if rx >= 0 and ry >= 0 and rx < SNAP_W and ry < SNAP_H then
				local entinfo = nil
				if info.PickEntry then
					local ok,picked = pcall(function() return info:PickEntry(0) end)
					if ok then entinfo = picked end
				end
				if entinfo then
					local tp = entinfo.Type
					local vr = entinfo.Variant or 0
					local st = entinfo.Subtype or 0
					local gt,gvr,is_console = resolve_stb_grid(tp,vr,st)
					if gt then
						-- 不写 State：配置生成用引擎默认态；强行 State=0 容易导致无贴图碰撞块
						table.insert(grids,{
							rx = rx,
							ry = ry,
							Type = gt,
							Variant = gvr,
							VarData = 0,
							stb_console = is_console or nil,
						})
					else
						tp,vr,st = remap_stb_entity(tp,vr,st)
						if tp and should_keep_spawn_entry(tp,vr,st) then
							table.insert(entities,{
								rx = rx,
								ry = ry,
								Type = tp,
								Variant = vr,
								SubType = st,
							})
						end
					end
				end
			end
		end
	end
	return entities,grids
end

--- holder/已落地复现房：Spawns 只是 Token 或空壳，必须采当前活体格+实体。
local function capture_live_from_room(ox,oy)
	local room = Game():GetRoom()
	local wd = room:GetGridWidth()
	local entities,grids = {},{}
	local fire_gidx = {}
	for _,ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FIREPLACE,-1,-1,false,false)) do
		if ent and ent:Exists() then
			local gidx = room:GetGridIndex(ent.Position)
			local gx = gidx % wd
			local gy = math.floor(gidx / wd)
			local rx,ry = gx - ox,gy - oy
			if rx >= 0 and ry >= 0 and rx < SNAP_W and ry < SNAP_H then
				fire_gidx[gidx] = true
				table.insert(grids,{
					rx = rx,
					ry = ry,
					Type = GridEntityType.GRID_POOP,
					Variant = 0,
					VarData = 0,
					soft_fire = true,
				})
			end
		end
	end
	for ry = 0,SNAP_H - 1 do
		for rx = 0,SNAP_W - 1 do
			local gidx = (ox + rx) + (oy + ry) * wd
			if not fire_gidx[gidx] then
				local grid = room:GetGridEntity(gidx)
				if grid then
					local gt = grid:GetType()
					local destroyed = ROCK_SHEET_TYPES[gt] and grid.State == 2
					if SNAPSHOT_GRID_TYPES[gt] and not destroyed then
						table.insert(grids,{
							rx = rx,
							ry = ry,
							Type = gt,
							Variant = grid:GetVariant() or 0,
							VarData = grid.VarData or 0,
						})
					end
				end
			end
		end
	end
	for _,ent in ipairs(Isaac.GetRoomEntities()) do
		if ent and ent:Exists() and should_keep_spawn_entry(ent.Type,ent.Variant,ent.SubType) then
			local gidx = room:GetGridIndex(ent.Position)
			local gx = gidx % wd
			local gy = math.floor(gidx / wd)
			local rx,ry = gx - ox,gy - oy
			if rx >= 0 and ry >= 0 and rx < SNAP_W and ry < SNAP_H then
				local cell = room:GetGridPosition(gidx)
				table.insert(entities,{
					rx = rx,
					ry = ry,
					Type = ent.Type,
					Variant = ent.Variant or 0,
					SubType = ent.SubType or 0,
					off_x = ent.Position.X - cell.X,
					off_y = ent.Position.Y - cell.Y,
					MaxHitPoints = ent.MaxHitPoints,
					HitPoints = ent.HitPoints,
				})
			end
		end
	end
	return entities,grids
end

local function capture_snapshot_1x1(player,opts)
	opts = opts or {}
	local room = Game():GetRoom()
	local ox,oy = compute_snapshot_origin(player.Position)
	local entities,grids
	if opts.live then
		entities,grids = capture_live_from_room(ox,oy)
	else
		-- 敌人与障碍均取房间数据 Spawns 初始快照（不采运行时已毁/已清的实况）
		entities,grids = capture_spawns_from_room_config(ox,oy)
	end
	return {
		origin_gx = ox,
		origin_gy = oy,
		width = SNAP_W,
		height = SNAP_H,
		entities = entities,
		grids = grids,
		layout_baked = opts.live == true or nil,
	}
end

local function get_destiny_holder_config()
	if item.holder_config_cache then return item.holder_config_cache end
	if not REPENTOGON then return nil end
	local holder = rawget(_G,"RoomConfig") or rawget(_G,"RoomConfigHolder")
	if not holder or not holder.GetRoomByStageTypeAndVariant then return nil end
	local mode = 0
	local success,config = pcall(
		holder.GetRoomByStageTypeAndVariant,
		StbType.SPECIAL_ROOMS,
		RoomType.ROOM_DEFAULT,
		item.holder_room_variant,
		mode
	)
	if success and config then
		item.holder_config_cache = config
		return config
	end
	success,config = pcall(
		holder.GetRoomByStageTypeAndVariant,
		StbType.SPECIAL_ROOMS,
		RoomType.ROOM_DEFAULT,
		item.holder_room_variant,
		-1
	)
	if success and config then
		item.holder_config_cache = config
		return config
	end
end

local function probe_emit(row)
	if item._probe_observer then
		pcall(item._probe_observer,row)
	end
end

function item.set_probe_observer(fn)
	item._probe_observer = type(fn) == "function" and fn or nil
end

function item.debug_current_room()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local data = room_data(desc)
	local ok,reason = is_anchorable(desc)
	local records = get_floor_records(nil,false) or {}
	local dim = room_dimension(desc)
	local existing = find_record(records,desc and desc.SafeGridIndex,dim)
	return {
		frame = Game():GetFrameCount(),
		repentogon = REPENTOGON and true or false,
		anchorable = ok == true,
		reason = reason,
		sgid = desc and desc.SafeGridIndex,
		dimension = dim,
		room_type = data and data.Type,
		stage_id = data and data.StageID,
		variant = data and data.Variant,
		shape = data and data.Shape,
		doors = data and data.Doors,
		allowed_doors = desc and desc.AllowedDoors,
		floor_seed = floor_seed(),
		current_floor_seed = item.current_floor_seed,
		record_count = #records,
		already_anchored = existing ~= nil,
		runtime_cached = existing and item.runtime_configs[config_key(floor_seed(),desc.SafeGridIndex)] ~= nil,
		room_config_api = (rawget(_G,"RoomConfig") or rawget(_G,"RoomConfigHolder")) ~= nil,
	}
end

local function record_current_room(player)
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local ok,reason = is_anchorable(desc)
	if not ok then
		probe_emit({kind = "use_fail",reason = reason or "not_anchorable",snap = item.debug_current_room()})
		return false
	end
	local records = get_floor_records(nil,true)
	local dimension = room_dimension(desc)
	if find_record(records,desc.SafeGridIndex,dimension) then
		remove_floor_record(desc.SafeGridIndex,dimension)
		extinguish_destiny_wisps_in_room(desc.SafeGridIndex,dimension)
		begin_retract_markers(nil)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SUMMON_POOF,0.7,1.1,false,0,1)
		probe_emit({kind = "retract",sgid = desc.SafeGridIndex,snap = item.debug_current_room()})
		return "retract"
	end
	if #records >= item.max_anchors then
		probe_emit({kind = "use_fail",reason = "max_anchors",snap = item.debug_current_room()})
		return false
	end

	local data = room_data(desc)
	local room = Game():GetRoom()
	local pidx = room:GetGridIndex(player.Position)
	local sgid = tonumber(desc.SafeGridIndex)
	local stash = take_reanchor_payload(sgid)
	local holder_now = is_destiny_holder_config(data)
	local snap
	local snapshot_only = false
	local room_gfx
	local stage_id,room_type,variant,shape,doors,cfg_mode
	local source_safe_grid_index

	if stash and stash.snapshot_1x1 then
		-- 复现房收起后再锚：恢复源房身份 + 已烘焙内容，禁止按 25500 holder Spawns 重采
		snap = stash.snapshot_1x1
		room_gfx = stash.room_gfx or capture_room_gfx()
		stage_id = stash.stage_id
		room_type = stash.room_type
		variant = stash.variant
		shape = stash.shape
		doors = stash.doors
		cfg_mode = stash.mode
		snapshot_only = stash.snapshot_only == true
		source_safe_grid_index = stash.source_safe_grid_index
		if is_destiny_holder_config({Variant = variant}) then
			snapshot_only = true
		end
	elseif holder_now then
		-- 仍站在 holder 壳里但无暂存：只能采活体，且禁止 exact 把空基础房带去下层
		snap = capture_snapshot_1x1(player,{live = true})
		room_gfx = capture_room_gfx()
		stage_id = data.StageID
		room_type = data.Type
		variant = data.Variant
		shape = data.Shape
		doors = data.Doors
		cfg_mode = room_config_mode()
		snapshot_only = true
	else
		snap = capture_snapshot_1x1(player)
		room_gfx = capture_room_gfx()
		stage_id = data.StageID
		room_type = data.Type
		variant = data.Variant
		shape = data.Shape
		doors = data.Doors
		cfg_mode = room_config_mode()
	end

	local ox,oy = snap.origin_gx,snap.origin_gy
	local wd = room:GetGridWidth()
	local record = {
		safe_grid_index = sgid,
		dimension = dimension,
		stage_id = stage_id,
		room_type = room_type,
		variant = variant,
		mode = cfg_mode,
		shape = shape,
		doors = doors,
		position = {
			X = player.Position.X,
			Y = player.Position.Y,
			grid_index = pidx,
			rel_rx = (pidx % wd) - ox,
			rel_ry = math.floor(pidx / wd) - oy,
		},
		room_gfx = room_gfx,
		snapshot_1x1 = snap,
		snapshot_only = snapshot_only,
		source_safe_grid_index = source_safe_grid_index,
	}
	-- 彼列：恶魔房可锚；下层保证恶魔房并把源房 config exact 盖过去
	if is_devil_room_type(room_type) or (stash and stash.devil_source) then
		record.devil_source = true
		save.elses[force_devil_key] = true
	end
	table.insert(records,record)
	-- holder 空壳禁止写入 runtime，否则下层 recover 会 exact 出基础房
	if not holder_now and not snapshot_only then
		item.runtime_configs[config_key(floor_seed(),sgid)] = data
	else
		item.runtime_configs[config_key(floor_seed(),sgid)] = nil
	end
	spawn_marker(player.Position,true,false,record.snapshot_1x1,{
		sgid = record.safe_grid_index,
		dim = dimension,
		floor = floor_seed(),
	})
	probe_emit({
		kind = "anchor",
		sgid = sgid,
		stage_id = record.stage_id,
		room_type = record.room_type,
		variant = record.variant,
		mode = record.mode,
		shape = record.shape,
		snapshot_only = record.snapshot_only,
		from_reanchor_stash = stash ~= nil,
		snap = item.debug_current_room(),
	})
	return "anchor"
end

local function recover_room_config(record,source_seed)
	local runtime = item.runtime_configs[config_key(source_seed,record.safe_grid_index)]
	if runtime then return runtime,"runtime" end
	local holder = rawget(_G,"RoomConfig") or rawget(_G,"RoomConfigHolder")
	if not holder or not holder.GetRoomByStageTypeAndVariant then return nil,"no_api" end
	local mode = tonumber(record.mode)
	if mode == nil then mode = room_config_mode() end
	local success,config = pcall(
		holder.GetRoomByStageTypeAndVariant,
		record.stage_id,
		record.room_type,
		record.variant,
		mode
	)
	if success and config then return config,"lookup_mode" end
	success,config = pcall(
		holder.GetRoomByStageTypeAndVariant,
		record.stage_id,
		record.room_type,
		record.variant,
		-1
	)
	if success and config then return config,"lookup_m1" end
	return nil,"lookup_miss"
end

local function is_boss_source(record)
	return record and record.room_type == RoomType.ROOM_BOSS
end

--- 目标房型评分：<0 表示禁止。Boss 源只打普通/奖励向；其它源优先同类型，其次普通房。
--- 恶魔源不走候选表（专用 ROOM_DEVIL_IDX 路径）；候选里仍禁止恶魔/天使房。
local function target_type_score(record,target_type)
	if target_type == nil then return -1 end
	if target_type == RoomType.ROOM_BOSS then return -1 end
	if target_type == RoomType.ROOM_DEVIL or target_type == RoomType.ROOM_ANGEL then return -1 end
	if record and record.devil_source then
		return -1
	end
	if is_boss_source(record) then
		return REWARD_TARGET_PRIORITY[target_type] or -1
	end
	if target_type == record.room_type then return 100 end
	if target_type == RoomType.ROOM_DEFAULT then return 40 end
	return -1
end

--- 门兼容：槽位所需门洞（AllowedDoors / DoorMask）必须全部出现在配置 Doors 中。
--- 否则替换后会把邻接连通门封死。配置可有多余门洞（通常呈木板墙），与 StageAPI DoLayoutDoorsMatch 同向。
local function doors_are_compatible(required_mask,room_config)
	if not room_config or room_config.Doors == nil or required_mask == nil then return false end
	return (room_config.Doors & required_mask) == required_mask
end

local function required_doors_of_desc(desc)
	return (desc and desc.AllowedDoors) or 0
end

local function is_forbidden_target_desc(desc,level)
	if not desc or not level or not desc.SafeGridIndex or desc.SafeGridIndex < 0 then return true end
	if desc.SafeGridIndex == level:GetStartingRoomIndex() then return true end
	local cur = level:GetCurrentRoomDesc()
	if cur and desc.SafeGridIndex == cur.SafeGridIndex then return true end
	local data = room_data(desc)
	if data and data.Type == RoomType.ROOM_BOSS then return true end
	if level.GetLastBossRoomListIndex then
		local boss_list = level:GetLastBossRoomListIndex()
		if boss_list and boss_list >= 0 and desc.ListIndex == boss_list then return true end
	end
	return false
end

local function clear_place_session()
	item.place_session = nil
end

local function begin_place_session(source_seed)
	if not REPENTOGON or not source_seed then
		clear_place_session()
		return nil
	end
	if not is_stage_allowed() then
		clear_place_session()
		probe_emit({kind = "place_session_skip",reason = "stage_banned",source_seed = source_seed})
		return nil
	end
	local records = get_floor_records(source_seed,false)
	if not records or #records == 0 then
		clear_place_session()
		return nil
	end
	local pendings = {}
	for _,record in ipairs(records) do
		-- 恶魔源不占布局槽：POST_NEW_LEVEL 专用 exact 到 ROOM_DEVIL_IDX
		if record.devil_source then
			table.insert(pendings,{
				record = record,
				room_config = nil,
				recover_via = "devil_deferred",
				claimed = false,
				needs_echo = false,
				devil_deferred = true,
				mode = nil,
				column = nil,
				row = nil,
				generation_index = nil,
				intended_type = nil,
				placed_config = nil,
				planned_generation_index = nil,
			})
		else
			local room_config,recover_via = recover_room_config(record,source_seed)
			local snapshot_only = record.snapshot_only == true
				or is_destiny_holder_config({Variant = record.variant})
				or is_destiny_holder_config(room_config)
			if snapshot_only then
				-- 禁止用 holder/25500 做 exact 预占
				room_config = nil
				recover_via = "snapshot_only"
			end
			table.insert(pendings,{
				record = record,
				room_config = room_config,
				recover_via = recover_via,
				claimed = false,
				needs_echo = room_config == nil,
				mode = nil,
				column = nil,
				row = nil,
				generation_index = nil,
				intended_type = nil,
				placed_config = nil,
				planned_generation_index = nil,
			})
		end
	end
	item.place_session = {
		source_seed = source_seed,
		pendings = pendings,
		reserved = {},
		active = true,
	}
	probe_emit({
		kind = "place_session_begin",
		source_seed = source_seed,
		pending = #pendings,
	})
	return item.place_session
end

--- 布局图就绪后：按 Shape + DoorMask 预占槽位（尚不知房型；房型在 PLACE 时再校验）。
local function plan_place_session(level_generator)
	local session = item.place_session
	if not session or not session.active or not level_generator or not level_generator.GetAllRooms then return end
	local rooms = level_generator:GetAllRooms()
	if type(rooms) ~= "table" then return end
	local rng = RNG()
	rng:SetSeed((session.source_seed or 1) + item.entity * 3,35)
	local reserved = {}
	for _,pending in ipairs(session.pendings) do
		if pending.devil_deferred then
			-- 恶魔源留给 POST_NEW_LEVEL 的 ROOM_DEVIL_IDX 路径
		else
			local cfg = pending.room_config
			if not cfg then
				pending.needs_echo = true
			else
				local matches = {}
				for _,slot in ipairs(rooms) do
					local gen = slot:GenerationIndex()
					if not reserved[gen] and slot:Shape() == cfg.Shape and doors_are_compatible(slot:DoorMask(),cfg) then
						table.insert(matches,slot)
					end
				end
				if #matches == 0 then
					pending.needs_echo = true
				else
					local pick = matches[(rng:RandomInt(#matches)) + 1]
					reserved[pick:GenerationIndex()] = pending
					pending.planned_generation_index = pick:GenerationIndex()
					pending.needs_echo = false
				end
			end
			rng:Next()
		end
	end
	session.reserved = reserved
	probe_emit({
		kind = "place_session_plan",
		source_seed = session.source_seed,
		reserved = (function()
			local n = 0
			for _ in pairs(reserved) do n = n + 1 end
			return n
		end)(),
	})
end

local function claim_pending_on_slot(pending,slot,vanilla_config,mode,placed_config)
	pending.claimed = true
	pending.mode = mode
	pending.column = slot:Column()
	pending.row = slot:Row()
	pending.generation_index = slot:GenerationIndex()
	pending.intended_type = vanilla_config and vanilla_config.Type
	pending.placed_config = placed_config
	pending.needs_echo = false
	probe_emit({
		kind = "place_claim",
		mode = mode,
		source_sgid = pending.record.safe_grid_index,
		room_type = pending.record.room_type,
		intended_type = pending.intended_type,
		generation_index = pending.generation_index,
		column = pending.column,
		row = pending.row,
		shape = slot:Shape(),
	})
end

local function try_place_room_for_slot(slot,vanilla_config,seed)
	local session = item.place_session
	if not session or not session.active then return nil end
	local gen = slot:GenerationIndex()
	local shape = slot:Shape()
	local door_mask = slot:DoorMask()
	local room_type = vanilla_config and vanilla_config.Type

	-- 精确：同 Shape + 门兼容 + 目标房型允许；预占槽略加分
	local best,best_score,best_cfg = nil,-1,nil
	for _,pending in ipairs(session.pendings) do
		local cfg = pending.room_config
		if not pending.claimed and cfg then
			local score = target_type_score(pending.record,room_type)
			if score >= 0 and cfg.Shape == shape and doors_are_compatible(door_mask,cfg) then
				local boosted = score
				if pending.planned_generation_index == gen then boosted = boosted + 1 end
				if boosted > best_score then
					best = pending
					best_score = boosted
					best_cfg = cfg
				end
			end
		end
	end
	if best and best_cfg then
		local reserved = session.reserved
		if reserved and best.planned_generation_index and reserved[best.planned_generation_index] == best then
			reserved[best.planned_generation_index] = nil
		end
		claim_pending_on_slot(best,slot,vanilla_config,"exact",best_cfg)
		return best_cfg
	end

	-- 形状对不上：导入 Destiny holder 1×1（满 DestinyToken），进房按 snapshot 替换
	if shape ~= RoomShape.ROOMSHAPE_1x1 then return nil end
	local snap_best,snap_score = nil,-1
	for _,pending in ipairs(session.pendings) do
		if not pending.claimed and pending.needs_echo and pending.record.snapshot_1x1 then
			local score = target_type_score(pending.record,room_type)
			if score > snap_score then
				snap_best = pending
				snap_score = score
			end
		end
	end
	if snap_best and snap_score >= 40 then
		local holder_cfg = get_destiny_holder_config()
		if holder_cfg and doors_are_compatible(door_mask,holder_cfg) then
			claim_pending_on_slot(snap_best,slot,vanilla_config,"snapshot",holder_cfg)
			return holder_cfg
		end
	end
	return nil
end

local function get_replacement_candidates(room_config,record,used,require_same_shape)
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local candidates = {}
	for index = 0,rooms.Size - 1 do
		local desc = rooms:Get(index)
		local data = room_data(desc)
		if desc and data and room_dimension(desc) == 0 and
			desc.VisitedCount == 0 and not used[desc.SafeGridIndex] and
			not is_forbidden_target_desc(desc,level) then
			local score = target_type_score(record,data.Type)
			if score >= 0 and
				(not require_same_shape or data.Shape == record.shape) and
				(not require_same_shape or doors_are_compatible(required_doors_of_desc(desc),room_config)) then
				table.insert(candidates,{
					desc = desc,
					score = score,
				})
			end
		end
	end
	return candidates
end

local function get_echo_candidates(record,used)
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local candidates = {}
	for index = 0,rooms.Size - 1 do
		local desc = rooms:Get(index)
		local data = room_data(desc)
		if desc and data and room_dimension(desc) == 0 and
			desc.VisitedCount == 0 and not used[desc.SafeGridIndex] and
			not is_forbidden_target_desc(desc,level) and
			data.Shape == RoomShape.ROOMSHAPE_1x1 then
			local score = target_type_score(record,data.Type)
			if score >= 0 then
				table.insert(candidates,{
					desc = desc,
					score = score,
				})
			end
		end
	end
	return candidates
end

local function choose_candidate(candidates,rng)
	for _,candidate in ipairs(candidates) do candidate.roll = rng:RandomInt(1000000) end
	table.sort(candidates,function(a,b)
		if a.score ~= b.score then return a.score > b.score end
		return a.roll < b.roll
	end)
	return candidates[1] and candidates[1].desc
end

local function register_reproduction(target_sgid,record,mode,room_config)
	local reproduced = get_reproduced_records(nil,true)
	reproduced[target_sgid] = {
		mode = mode,
		room_gfx = record.room_gfx,
		announced = false,
		source_safe_grid_index = record.safe_grid_index,
		snapshot_1x1 = record.snapshot_1x1,
		contents_applied = false,
	}
	record.reproduction_mode = mode
	transfer_wisp_state_on_reproduce(record,target_sgid)
	-- 复现房写入本层 floor 记录，保持「仍被锚定」；再使用会收起而非再落一次
	local floors = get_floor_records(nil,true)
	if not find_record(floors,target_sgid,0) then
		table.insert(floors,{
			safe_grid_index = tonumber(target_sgid),
			dimension = 0,
			stage_id = record.stage_id,
			room_type = record.room_type,
			variant = record.variant,
			mode = record.mode,
			shape = record.shape,
			doors = record.doors,
			-- 源房世界坐标对新房无效；进房时用 rel / 中心重算
			position = {
				rel_rx = record.position and record.position.rel_rx,
				rel_ry = record.position and record.position.rel_ry,
			},
			room_gfx = record.room_gfx,
			snapshot_1x1 = record.snapshot_1x1,
			snapshot_only = record.snapshot_only == true or mode == "snapshot" or mode == "echo",
			echo = mode == "echo" or mode == "snapshot",
			reproduction_mode = mode,
			devil_source = record.devil_source == true,
			carried = true,
			source_safe_grid_index = record.safe_grid_index,
		})
	end
	if room_config then
		item.runtime_configs[config_key(floor_seed(),target_sgid)] = room_config
	end
end

--- 彼列恶魔源：保证恶魔房后把源 config exact 盖到 ROOM_DEVIL_IDX（不占普通房槽）。
local function reproduce_devil_source_anchor(record,source_seed,used)
	if not record or not record.devil_source then return false end
	local idx = devil_room_idx()
	if used and used[idx] then return false end
	local desc = select(1,ensure_devil_room_desc())
	if not desc then return false end
	local room_config,recover_via = recover_room_config(record,source_seed)
	if not room_config or is_destiny_holder_config(room_config) then
		probe_emit({
			kind = "reproduce_fail",
			recover_via = recover_via or "nil",
			source_sgid = record.safe_grid_index,
			room_type = record.room_type,
			variant = record.variant,
			mode = "devil_exact",
			has_config = room_config ~= nil,
		})
		return false
	end
	Room_holder.Replace_with(idx,0,{
		data = room_config,
		others = {OverrideData = room_config,},
	})
	if used then used[idx] = true end
	register_reproduction(idx,record,"exact",room_config)
	probe_emit({
		kind = "reproduce_ok",
		mode = "exact",
		via = "devil_slot",
		recover_via = recover_via,
		source_sgid = record.safe_grid_index,
		target_sgid = idx,
		room_type = record.room_type,
	})
	return true
end

local function apply_replacement(target_desc,room_config,record,mode,used)
	Room_holder.Replace_with(target_desc.SafeGridIndex,0,{
		data = room_config,
		others = {OverrideData = room_config,},
	})
	used[target_desc.SafeGridIndex] = true
	register_reproduction(target_desc.SafeGridIndex,record,mode,room_config)
end

local function try_snapshot_reproduction(record,used,rng)
	if not record.snapshot_1x1 then return false end
	local holder_cfg = get_destiny_holder_config()
	if not holder_cfg then return false end
	local candidates = get_echo_candidates(record,used)
	if #candidates == 0 then return false end
	for _,candidate in ipairs(candidates) do candidate.roll = rng:RandomInt(1000000) end
	table.sort(candidates,function(a,b)
		if a.score ~= b.score then return a.score > b.score end
		return a.roll < b.roll
	end)
	for _,candidate in ipairs(candidates) do
		if doors_are_compatible(required_doors_of_desc(candidate.desc),holder_cfg) then
			apply_replacement(candidate.desc,holder_cfg,record,"snapshot",used)
			return true
		end
		rng:Next()
	end
	return false
end

local function finalize_place_session(used)
	local session = item.place_session
	if not session or not session.pendings then return 0 end
	local level = Game():GetLevel()
	local count = 0
	for _,pending in ipairs(session.pendings) do
		if pending.claimed and pending.column ~= nil and pending.row ~= nil then
			local sgid = pending.row * LEVEL_GRID_WIDTH + pending.column
			if not used[sgid] then
				local cfg = pending.placed_config or pending.room_config
				local desc = level:GetRoomByIdx(sgid)
				if desc and cfg then
					-- 生成期已写入 Data；此处补 OverrideData，避免 StageAPI 再挂 LevelRoom
					Room_holder.Replace_with(sgid,0,{
						data = cfg,
						others = {OverrideData = cfg,},
					})
					used[sgid] = true
					register_reproduction(sgid,pending.record,pending.mode or "exact",cfg)
					count = count + 1
					probe_emit({
						kind = "reproduce_ok",
						mode = pending.mode or "exact",
						via = "pre_place",
						recover_via = pending.recover_via,
						source_sgid = pending.record.safe_grid_index,
						target_sgid = sgid,
						room_type = pending.record.room_type,
						intended_type = pending.intended_type,
					})
				end
			end
		end
	end
	return count
end

local function reproduce_single_anchor(record,source_seed,used,rng,room_config,recover_via)
	if record and record.devil_source then
		return reproduce_devil_source_anchor(record,source_seed,used)
	end
	local same_shape_n = 0
	local skip_exact = record.snapshot_only == true
		or is_destiny_holder_config({Variant = record.variant})
	if not skip_exact then
		if room_config == nil and recover_via == nil then
			room_config,recover_via = recover_room_config(record,source_seed)
		elseif room_config == nil then
			room_config = select(1,recover_room_config(record,source_seed))
		end
		if room_config and not is_destiny_holder_config(room_config) then
			local cands = get_replacement_candidates(room_config,record,used,true)
			same_shape_n = #cands
			local target = choose_candidate(cands,rng)
			if target then
				apply_replacement(target,room_config,record,"exact",used)
				probe_emit({
					kind = "reproduce_ok",
					mode = "exact",
					via = "post_fallback",
					recover_via = recover_via,
					source_sgid = record.safe_grid_index,
					target_sgid = target.SafeGridIndex,
					room_type = record.room_type,
					shape = record.shape,
					candidates = same_shape_n,
				})
				return true
			end
		end
	end
	if try_snapshot_reproduction(record,used,rng) then
		probe_emit({
			kind = "reproduce_ok",
			mode = "snapshot",
			via = "post_fallback",
			recover_via = recover_via,
			source_sgid = record.safe_grid_index,
			room_type = record.room_type,
			candidates = same_shape_n,
			snapshot_only = record.snapshot_only == true,
		})
		return true
	end
	probe_emit({
		kind = "reproduce_fail",
		recover_via = recover_via or "nil",
		source_sgid = record.safe_grid_index,
		stage_id = record.stage_id,
		room_type = record.room_type,
		variant = record.variant,
		mode = record.mode,
		shape = record.shape,
		candidates = same_shape_n,
		has_config = room_config ~= nil,
		has_snapshot = record.snapshot_1x1 ~= nil,
		snapshot_only = record.snapshot_only == true,
	})
	return false
end

local function reproduce_anchors(source_seed)
	item.reproduce_source_seed = source_seed
	if not is_stage_allowed() then
		probe_emit({kind = "reproduce_skip",reason = "stage_banned",source_seed = source_seed,new_seed = floor_seed()})
		clear_place_session()
		item.reproduce_source_seed = nil
		return 0
	end
	local records = get_floor_records(source_seed,false)
	if not records or #records == 0 then
		probe_emit({kind = "reproduce_skip",reason = "no_records",source_seed = source_seed,new_seed = floor_seed()})
		clear_place_session()
		item.reproduce_source_seed = nil
		return 0
	end
	local level = Game():GetLevel()
	local rng = RNG()
	rng:SetSeed(level:GetDungeonPlacementSeed() + item.entity,35)
	local used = {}
	local reproduced = 0
	local failed = 0
	probe_emit({
		kind = "reproduce_begin",
		source_seed = source_seed,
		new_seed = floor_seed(),
		record_count = #records,
		has_place_session = item.place_session ~= nil,
	})

	reproduced = reproduced + finalize_place_session(used)

	local claimed_sources = {}
	if item.place_session and item.place_session.pendings then
		for _,pending in ipairs(item.place_session.pendings) do
			if pending.claimed then
				claimed_sources[pending.record.safe_grid_index] = true
			end
		end
	end

	for i,record in ipairs(records) do
		if claimed_sources[record.safe_grid_index] then
			-- already placed during generation
		else
			local room_config,recover_via
			if item.place_session and item.place_session.pendings and item.place_session.pendings[i] then
				local pending = item.place_session.pendings[i]
				room_config,recover_via = pending.room_config,pending.recover_via
			end
			if reproduce_single_anchor(record,source_seed,used,rng,room_config,recover_via) then
				reproduced = reproduced + 1
			else
				failed = failed + 1
			end
		end
		rng:Next()
	end
	if failed > 0 then item.pending_failure_notice = failed end
	probe_emit({
		kind = "reproduce_end",
		source_seed = source_seed,
		reproduced = reproduced,
		failed = failed,
	})
	clear_place_session()
	item.reproduce_source_seed = nil
	return reproduced
end

-- holder(snapshot/echo)：相对格映到 1×1 可玩区 (1,1) 起；exact：用快照 origin
local function snap_uses_holder_layout(entry)
	local mode = entry and entry.mode
	return mode == "snapshot" or mode == "echo"
end

local function snapshot_cell_grid_index(snap,rx,ry,holder_layout)
	local room = Game():GetRoom()
	local wd = room:GetGridWidth()
	rx,ry = rx or 0,ry or 0
	if holder_layout then
		return (1 + rx) + (1 + ry) * wd
	end
	local ox = tonumber(snap and snap.origin_gx) or 1
	local oy = tonumber(snap and snap.origin_gy) or 1
	return (ox + rx) + (oy + ry) * wd
end

local function apply_grid_visual(grid,grid_info)
	if not grid or not grid_info then return end
	-- 禁止写 State/Frame：配置快照没有可靠状态；误写会导致无贴图或存档后变碎石（StageAPI 也只在有 GridInformation 时才写 State）
	local spr = grid:GetSprite()
	if not spr then return end
	local sheets = grid_info.sheets
	if type(sheets) ~= "table" then return end
	local replaced = false
	for layer_key,path in pairs(sheets) do
		local layer = tonumber(layer_key)
		local p = normalize_gfx_path(path)
		if layer and p and p:match("%.png$") then
			if spr.ReplaceSpritesheet then
				pcall(function() spr:ReplaceSpritesheet(layer,p,false) end)
			else
				pcall(function() spr:ReplaceSpritesheet(layer,p) end)
			end
			replaced = true
		end
	end
	if replaced then
		pcall(function() spr:LoadGraphics() end)
	end
end

--- StageAPI.CallGridPostInit 同向：GridSpawn 后必须 PostInit，石头再 UpdateAnimFrame，否则有碰撞无贴图，小退后还会存成碎石。
local function call_grids_post_init(room,gindices)
	for _,gidx in ipairs(gindices) do
		local grid = room:GetGridEntity(gidx)
		if grid then
			pcall(function() grid:PostInit() end)
			if ROCK_SHEET_TYPES[grid:GetType()] then
				local rock = grid:ToRock()
				if rock and rock.UpdateAnimFrame then
					pcall(function() rock:UpdateAnimFrame() end)
				end
			end
		end
	end
end

local function rock_sheet_usable(sheet)
	if type(sheet) ~= "string" or sheet == "" then return false end
	local p = normalize_gfx_path(sheet)
	return p and p:find("gfx/",1,true) and p:match("%.png$") ~= nil
end

--- 对齐 StageAPI.ChangeRock：仅在有明确 png 时换肤；优先让 PostInit 吃当前 backdrop。
local function apply_rock_sheet(grid,sheet)
	if not grid or not rock_sheet_usable(sheet) then return end
	if not ROCK_SHEET_TYPES[grid:GetType()] then return end
	local path = normalize_gfx_path(sheet)
	local spr = grid:GetSprite()
	if not spr then return end
	for i = 0,4 do
		if spr.ReplaceSpritesheet then
			pcall(function() spr:ReplaceSpritesheet(i,path,false) end)
		else
			pcall(function() spr:ReplaceSpritesheet(i,path) end)
		end
	end
	pcall(function() spr:LoadGraphics() end)
	local rock = grid:ToRock()
	if rock and rock.UpdateAnimFrame then
		pcall(function() rock:UpdateAnimFrame() end)
	end
end

local function grid_is_destroyed_rock(grid)
	if not grid then return true end
	local gt = grid:GetType()
	if not ROCK_SHEET_TYPES[gt] then return false end
	-- 原版碎石 State=2；未 PostInit 的异常态也可能被存成碎石
	return grid.State == 2
end

local function paint_snapshot_rocks(entry,snap,holder)
	local room = Game():GetRoom()
	-- StageAPI：有当前 RoomGfx.Grids 时走官方换肤（apply_room_gfx 已尽量带上 Rocks）
	if stageapi_loaded() and StageAPI.UpdateGrids then
		local ok,did = pcall(StageAPI.UpdateGrids)
		if ok and did then
			for gidx = 0,room:GetGridSize() - 1 do
				local grid = room:GetGridEntity(gidx)
				if grid and ROCK_SHEET_TYPES[grid:GetType()] then
					local rock = grid:ToRock()
					if rock and rock.UpdateAnimFrame then
						pcall(function() rock:UpdateAnimFrame() end)
					end
				end
			end
			return
		end
	end
	local sheet = entry.room_gfx and entry.room_gfx.rock_sheet
	if not rock_sheet_usable(sheet) then return end
	-- exact：整房 config 石头都要换肤；snapshot/echo：1×1 窗内即可
	local whole_room = entry.mode == "exact" or not snap_uses_holder_layout(entry)
	if whole_room then
		for gidx = 0,room:GetGridSize() - 1 do
			apply_rock_sheet(room:GetGridEntity(gidx),sheet)
		end
		return
	end
	for _,grid_info in ipairs(snap.grids or {}) do
		local gidx = snapshot_cell_grid_index(snap,grid_info.rx,grid_info.ry,holder)
		apply_rock_sheet(room:GetGridEntity(gidx),sheet)
	end
end

local remove_grid_now
local spawn_snapshot_grid
local clear_cell_empty
local soften_grid_to_poop_or_fire
local spawn_pit_at

local function cell_key_rxry(rx,ry)
	return tostring(rx)..","..tostring(ry)
end

local function virtual_type_cost(gt)
	if gt == nil then return 0 end
	if gt == GridEntityType.GRID_WALL or gt == GridEntityType.GRID_DOOR then return nil end
	if gt == GridEntityType.GRID_PRESSURE_PLATE
		or gt == GridEntityType.GRID_TELEPORTER
		or gt == GridEntityType.GRID_SPIDERWEB
		or gt == GridEntityType.GRID_DECORATION then
		return 0
	end
	if gt == GridEntityType.GRID_POOP or HARD_PATH_GRID[gt] then return 1 end
	return 1
end

--- 生成前虚拟代价：快照 want 优先，门口强制 0；不依赖已刷出的格。
local function layout_cell_cost(room,gidx,want_by_gidx,entry_set)
	if gidx == nil or gidx < 0 or gidx >= room:GetGridSize() then return nil end
	local coll = room:GetGridCollision(gidx)
	if coll == GridCollisionClass.COLLISION_WALL
		or coll == GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER then
		return nil
	end
	local pos = room:GetGridPosition(gidx)
	if not room:IsPositionInRoom(pos,0) then return nil end
	if entry_set and entry_set[gidx] then return 0 end
	local want = want_by_gidx and want_by_gidx[gidx]
	if want then return virtual_type_cost(want.Type) end
	local have = room:GetGridEntity(gidx)
	if have then return virtual_type_cost(have:GetType()) end
	return 0
end

clear_cell_empty = function(room,gidx)
	room:SetGridPath(gidx,0)
	if room:GetGridEntity(gidx) then
		remove_grid_now(room,gidx)
	end
	local pos = room:GetGridPosition(gidx)
	for _,ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FIREPLACE,-1,-1,false,false)) do
		if ent and ent:Exists() and room:GetGridIndex(ent.Position) == gidx then
			ent:Remove()
		end
	end
end

soften_grid_to_poop_or_fire = function(room,gidx,use_fire)
	clear_cell_empty(room,gidx)
	local pos = room:GetGridPosition(gidx)
	if use_fire then
		Isaac.Spawn(EntityType.ENTITY_FIREPLACE,0,0,pos,Vector.Zero,nil)
	else
		local seed = room:GetSpawnSeed()
		if not seed or seed == 0 then seed = 1 end
		room:SpawnGridEntity(gidx,GridEntityType.GRID_POOP,0,seed,0)
	end
end

spawn_pit_at = function(room,gidx)
	clear_cell_empty(room,gidx)
	local seed = room:GetSpawnSeed()
	if not seed or seed == 0 then seed = 1 end
	room:SpawnGridEntity(gidx,GridEntityType.GRID_PIT,0,seed,0)
end

local function room_is_narrow_or_flat(room)
	local shape = room:GetRoomShape()
	return shape == RoomShape.ROOMSHAPE_IH
		or shape == RoomShape.ROOMSHAPE_IV
		or shape == RoomShape.ROOMSHAPE_IIH
		or shape == RoomShape.ROOMSHAPE_IIV
end

local function door_entry_terminals(room,want_by_gidx)
	local terminals = {}
	local seen = {}
	local center = room:GetCenterPos()
	local entry_set = {}
	for slot = 0,DoorSlot.NUM_DOOR_SLOTS - 1 do
		local door = room:GetDoor(slot)
		if door then
			local door_pos = room:GetDoorSlotPosition(slot)
			local delta = center - door_pos
			if delta:LengthSquared() < 1 then delta = Vector(0,40) end
			for step = 1,2 do
				local inward = room:GetClampedPosition(door_pos + delta:Resized(40 * step),0)
				local gidx = room:GetGridIndex(inward)
				if layout_cell_cost(room,gidx,want_by_gidx,nil) ~= nil and not seen[gidx] then
					seen[gidx] = true
					entry_set[gidx] = true
					table.insert(terminals,{
						gidx = gidx,
						is_entry = step == 1,
					})
				end
			end
		end
	end
	return terminals,entry_set
end

local function bfs01_layout(room,sources,want_by_gidx,entry_set,wd,size)
	local dist,prev = {},{}
	local deque = {}
	local head = 1
	for _,s in ipairs(sources) do
		dist[s] = 0
		table.insert(deque,s)
	end
	while head <= #deque do
		local cur = deque[head]
		head = head + 1
		local dcur = dist[cur]
		for _,nb in ipairs({cur - 1,cur + 1,cur - wd,cur + wd}) do
			if nb >= 0 and nb < size
				and not ((cur % wd == 0 and nb == cur - 1) or (cur % wd == wd - 1 and nb == cur + 1)) then
				local step = layout_cell_cost(room,nb,want_by_gidx,entry_set)
				if step ~= nil then
					local nd = dcur + step
					local old = dist[nb]
					if old == nil or nd < old then
						dist[nb] = nd
						prev[nb] = cur
						if step == 0 then
							table.insert(deque,head,nb)
						else
							table.insert(deque,nb)
						end
					end
				end
			end
		end
	end
	return dist,prev
end

--- 生成前算通路 mask（gidx → empty/soft/pit），不改房间实体。
local function compute_layout_mask(entry)
	local room = Game():GetRoom()
	local snap = entry.snapshot_1x1
	local holder = snap_uses_holder_layout(entry)
	local wd = room:GetGridWidth()
	local size = room:GetGridSize()
	local want_by_gidx = {}
	local gidx_to_rxry = {}
	for _,grid_info in ipairs(snap.grids or {}) do
		local gidx = snapshot_cell_grid_index(snap,grid_info.rx,grid_info.ry,holder)
		want_by_gidx[gidx] = grid_info
		gidx_to_rxry[gidx] = {rx = grid_info.rx,ry = grid_info.ry}
	end
	-- 窗内无 want 的格也登记 rxry，供 pit/empty 烘焙
	for ry = 0,SNAP_H - 1 do
		for rx = 0,SNAP_W - 1 do
			local gidx = snapshot_cell_grid_index(snap,rx,ry,holder)
			if not gidx_to_rxry[gidx] then
				gidx_to_rxry[gidx] = {rx = rx,ry = ry}
			end
		end
	end

	local terminals,entry_set = door_entry_terminals(room,want_by_gidx)
	local clears = {} -- gidx -> mode
	for gidx,_ in pairs(entry_set) do
		clears[gidx] = "empty"
	end

	local goals = {}
	local seen_goal = {}
	for _,t in ipairs(terminals) do
		if t.is_entry and not seen_goal[t.gidx] then
			seen_goal[t.gidx] = true
			table.insert(goals,t.gidx)
		end
	end

	local function expand_free(reached,seed)
		local q = {seed}
		local qi = 1
		reached[seed] = true
		while qi <= #q do
			local cur = q[qi]
			qi = qi + 1
			for _,nb in ipairs({cur - 1,cur + 1,cur - wd,cur + wd}) do
				if nb >= 0 and nb < size
					and not ((cur % wd == 0 and nb == cur - 1) or (cur % wd == wd - 1 and nb == cur + 1))
					and not reached[nb]
					and layout_cell_cost(room,nb,want_by_gidx,entry_set) == 0 then
					reached[nb] = true
					table.insert(q,nb)
				end
			end
		end
	end

	if #goals >= 2 then
		local reached = {}
		expand_free(reached,goals[1])
		local pending = {}
		for i = 2,#goals do
			if not reached[goals[i]] then table.insert(pending,goals[i]) end
		end
		local convert_i = 0
		local guard = 0
		while #pending > 0 and guard < 48 do
			guard = guard + 1
			local sources = {}
			for idx,_ in pairs(reached) do table.insert(sources,idx) end
			local dist,prev = bfs01_layout(room,sources,want_by_gidx,entry_set,wd,size)
			local best_goal,best_cost = nil,nil
			for _,g in ipairs(pending) do
				local d = dist[g]
				if d ~= nil and (best_cost == nil or d < best_cost) then
					best_cost,best_goal = d,g
				end
			end
			if not best_goal then break end
			local cur = best_goal
			local g2 = 0
			while cur ~= nil and g2 < 512 do
				g2 = g2 + 1
				if layout_cell_cost(room,cur,want_by_gidx,entry_set) == 1 then
					if entry_set[cur] then
						clears[cur] = "empty"
					else
						convert_i = convert_i + 1
						clears[cur] = "soft"
						-- 虚拟层：该格视为已软化可走（对后续 BFS 当 entry 旁路）
						want_by_gidx[cur] = nil
						entry_set[cur] = true -- 代价 0
					end
				end
				reached[cur] = true
				cur = prev[cur]
			end
			expand_free(reached,best_goal)
			local still = {}
			for _,g in ipairs(pending) do
				if not reached[g] then table.insert(still,g) end
			end
			pending = still
		end
	end

	-- 窄/扁：外侧 → pit（通路= empty/soft + 空地洪水 + 扩一圈）
	if room_is_narrow_or_flat(room) and #goals >= 1 then
		local corridor = {}
		for gidx,mode in pairs(clears) do
			if mode == "empty" or mode == "soft" then corridor[gidx] = true end
		end
		local q = {}
		for _,g in ipairs(goals) do
			if not corridor[g] then
				corridor[g] = true
				table.insert(q,g)
			end
		end
		local qi = 1
		while qi <= #q do
			local cur = q[qi]
			qi = qi + 1
			for _,nb in ipairs({cur - 1,cur + 1,cur - wd,cur + wd}) do
				if nb >= 0 and nb < size
					and not ((cur % wd == 0 and nb == cur - 1) or (cur % wd == wd - 1 and nb == cur + 1))
					and not corridor[nb]
					and layout_cell_cost(room,nb,want_by_gidx,entry_set) == 0 then
					corridor[nb] = true
					table.insert(q,nb)
				end
			end
		end
		local thicken = {}
		for gidx,_ in pairs(corridor) do
			for _,nb in ipairs({gidx - 1,gidx + 1,gidx - wd,gidx + wd}) do
				if nb >= 0 and nb < size
					and not ((gidx % wd == 0 and nb == gidx - 1) or (gidx % wd == wd - 1 and nb == gidx + 1))
					and layout_cell_cost(room,nb,want_by_gidx,entry_set) ~= nil then
					thicken[nb] = true
				end
			end
		end
		for gidx,_ in pairs(thicken) do corridor[gidx] = true end

		for gidx = 0,size - 1 do
			if not corridor[gidx] and not clears[gidx] then
				local pos = room:GetGridPosition(gidx)
				if room:IsPositionInRoom(pos,0)
					and layout_cell_cost(room,gidx,want_by_gidx,entry_set) ~= nil then
					clears[gidx] = "pit"
				end
			end
		end
	end

	local by_rxry = {}
	for gidx,mode in pairs(clears) do
		local rr = gidx_to_rxry[gidx]
		if rr then
			by_rxry[cell_key_rxry(rr.rx,rr.ry)] = mode
		end
	end
	return clears,by_rxry
end

--- 把 mask 写进 snapshot.grids，供下一层携带复用（与 floor 记录共享同一表引用）。
local function bake_layout_mask_into_snapshot(entry,clears_gidx,by_rxry)
	local snap = entry.snapshot_1x1
	if not snap then return end
	local holder = snap_uses_holder_layout(entry)
	local old = {}
	for _,grid_info in ipairs(snap.grids or {}) do
		old[cell_key_rxry(grid_info.rx,grid_info.ry)] = grid_info
	end
	local new_grids = {}
	local soft_i = 0
	for ry = 0,SNAP_H - 1 do
		for rx = 0,SNAP_W - 1 do
			local key = cell_key_rxry(rx,ry)
			local mode = by_rxry[key]
			local gidx = snapshot_cell_grid_index(snap,rx,ry,holder)
			if not mode and clears_gidx then mode = clears_gidx[gidx] end
			if mode == "empty" then
				-- 不放障碍
			elseif mode == "soft" then
				soft_i = soft_i + 1
				table.insert(new_grids,{
					rx = rx,
					ry = ry,
					Type = GridEntityType.GRID_POOP,
					Variant = 0,
					VarData = 0,
					soft_fire = (soft_i % 2 == 0),
				})
			elseif mode == "pit" then
				table.insert(new_grids,{
					rx = rx,
					ry = ry,
					Type = GridEntityType.GRID_PIT,
					Variant = 0,
					VarData = 0,
				})
			elseif old[key] then
				table.insert(new_grids,old[key])
			end
		end
	end
	snap.grids = new_grids
	snap.layout_mask = by_rxry
	snap.layout_baked = true
end

--- 按 mask 一次生成；先算通路再刷格，避免后处理拆石头导致未 PostInit。
local function apply_snapshot_grids(entry)
	if not entry or not entry.snapshot_1x1 then return end
	local room = Game():GetRoom()
	local snap = entry.snapshot_1x1
	local holder = snap_uses_holder_layout(entry)

	local clears_gidx,by_rxry = compute_layout_mask(entry)
	entry.path_clears = {}
	for gidx,mode in pairs(clears_gidx) do
		entry.path_clears[tostring(gidx)] = mode
	end
	bake_layout_mask_into_snapshot(entry,clears_gidx,by_rxry)

	local want_grid = {}
	for _,grid_info in ipairs(snap.grids or {}) do
		want_grid[cell_key_rxry(grid_info.rx,grid_info.ry)] = grid_info
	end

	local touched = {}
	local soft_i = 0
	local touched_set = {}
	for ry = 0,SNAP_H - 1 do
		for rx = 0,SNAP_W - 1 do
			local gidx = snapshot_cell_grid_index(snap,rx,ry,holder)
			local key = cell_key_rxry(rx,ry)
			local mode = by_rxry[key] or clears_gidx[gidx]
			local want = want_grid[key]
			if mode == "empty" then
				clear_cell_empty(room,gidx)
				touched_set[gidx] = true
				table.insert(touched,gidx)
			elseif mode == "soft" then
				soft_i = soft_i + 1
				local use_fire = want and want.soft_fire
				if use_fire == nil then use_fire = (soft_i % 2 == 0) end
				soften_grid_to_poop_or_fire(room,gidx,use_fire)
				touched_set[gidx] = true
				table.insert(touched,gidx)
			elseif mode == "pit" or (want and want.Type == GridEntityType.GRID_PIT) then
				spawn_pit_at(room,gidx)
				touched_set[gidx] = true
				table.insert(touched,gidx)
			elseif want then
				if want.soft_fire then
					soften_grid_to_poop_or_fire(room,gidx,true)
				else
					spawn_snapshot_grid(room,gidx,want)
					apply_grid_visual(room:GetGridEntity(gidx),want)
				end
				touched_set[gidx] = true
				table.insert(touched,gidx)
			else
				local have = room:GetGridEntity(gidx)
				if have and SNAPSHOT_GRID_TYPES[have:GetType()] then
					remove_grid_now(room,gidx)
				end
			end
		end
	end

	-- 窄房外侧 pit 可能在 snap 窗外
	for gidx,mode in pairs(clears_gidx) do
		if mode == "pit" and not touched_set[gidx] then
			spawn_pit_at(room,gidx)
			touched_set[gidx] = true
			table.insert(touched,gidx)
		elseif mode == "empty" and not touched_set[gidx] then
			clear_cell_empty(room,gidx)
			touched_set[gidx] = true
			table.insert(touched,gidx)
		end
	end

	call_grids_post_init(room,touched)
	paint_snapshot_rocks(entry,snap,holder)
end

local function refresh_snapshot_grid_visuals(entry)
	if not entry or not entry.snapshot_1x1 then return end
	-- 重进/晚帧：缺格或碎石则按已烘焙快照重刷；否则只 PostInit+换肤（禁止再跑后处理拆石）
	local room = Game():GetRoom()
	local snap = entry.snapshot_1x1
	local holder = snap_uses_holder_layout(entry)
	local need_full = false
	for _,grid_info in ipairs(snap.grids or {}) do
		local gidx = snapshot_cell_grid_index(snap,grid_info.rx,grid_info.ry,holder)
		local clears = entry.path_clears or {}
		if clears[tostring(gidx)] then
			-- empty/soft/pit：由 apply_snapshot_grids 按 mask 维护
		else
			local have = room:GetGridEntity(gidx)
			local want_type = grid_info.Type
			if grid_info.soft_fire then
				-- 火堆不占 GridEntity
				local found_fire = false
				for _,ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FIREPLACE,-1,-1,false,false)) do
					if ent and ent:Exists() and room:GetGridIndex(ent.Position) == gidx then
						found_fire = true
						break
					end
				end
				if not found_fire then
					need_full = true
					break
				end
			elseif (not have) or have:GetType() ~= want_type or grid_is_destroyed_rock(have) then
				need_full = true
				break
			end
		end
	end
	if need_full then
		apply_snapshot_grids(entry)
	else
		local touched = {}
		for _,grid_info in ipairs(snap.grids or {}) do
			table.insert(touched,snapshot_cell_grid_index(snap,grid_info.rx,grid_info.ry,holder))
		end
		call_grids_post_init(room,touched)
		paint_snapshot_rocks(entry,snap,holder)
	end
end

local function clear_snap_region_live(room,snap,holder)
	local wd = room:GetGridWidth()
	local keys = {}
	for ry = 0,SNAP_H - 1 do
		for rx = 0,SNAP_W - 1 do
			keys[snapshot_cell_grid_index(snap,rx,ry,holder)] = true
		end
	end
	for _,ent in ipairs(Isaac.GetRoomEntities()) do
		if should_keep_spawn_entry(ent.Type,ent.Variant,ent.SubType) then
			local gidx = room:GetGridIndex(ent.Position)
			if keys[gidx] then
				ent:Remove()
			end
		end
	end
end

local function spawn_snapshot_entity(ent_info,pos)
	if not ent_info then return end
	local tp = ent_info.Type
	local vr = ent_info.Variant or 0
	local st = ent_info.SubType or 0
	-- 旧存档可能把 STB 蛛网等误记成实体；生成前再拦一次
	if not should_keep_spawn_entry(tp,vr,st) then return end
	if EntityConfig and EntityConfig.GetEntity then
		local ok,cfg = pcall(EntityConfig.GetEntity,tp,vr,st)
		if ok and cfg == nil then return end
	end
	local ok,spawned = pcall(Isaac.Spawn,tp,vr,st,pos,Vector.Zero,nil)
	if not ok or not spawned then return end
	if ent_info.MaxHitPoints and spawned.MaxHitPoints then
		spawned.MaxHitPoints = ent_info.MaxHitPoints
	end
	if ent_info.HitPoints and spawned.HitPoints then
		spawned.HitPoints = ent_info.HitPoints
	end
	local npc = spawned:ToNPC()
	if npc and ent_info.Champion ~= nil and npc.MakeChampion then
		pcall(function() npc:MakeChampion(spawned.InitSeed or Random(),ent_info.Champion,true) end)
	end
	return spawned
end

remove_grid_now = function(room,gidx)
	if room.RemoveGridEntityImmediate then
		room:RemoveGridEntityImmediate(gidx,0,false)
	else
		room:RemoveGridEntity(gidx,0,false)
		local g = room:GetGridEntity(gidx)
		if g then pcall(function() g:Update() end) end
	end
end

spawn_snapshot_grid = function(room,gidx,want)
	if not want then return nil end
	room:SetGridPath(gidx,0)
	if room:GetGridEntity(gidx) then
		remove_grid_now(room,gidx)
	end
	local pos = room:GetGridPosition(gidx)
	-- StageAPI 同向：GridSpawn + force；刷完后必须再 PostInit（见 call_grids_post_init）
	local grid = Isaac.GridSpawn(want.Type,want.Variant or 0,pos,true)
	if not grid then
		local seed = tonumber(want.SpawnSeed) or room:GetSpawnSeed() or 1
		if seed == 0 then seed = 1 end
		room:SpawnGridEntity(gidx,want.Type,want.Variant or 0,seed,tonumber(want.VarData) or 0)
		grid = room:GetGridEntity(gidx)
	elseif want.VarData ~= nil and grid.VarData ~= nil then
		grid.VarData = want.VarData
	end
	return grid
end

--- 把锚定当时格点窗内的障碍+实体铺回。snapshot/echo 用 holder 映射；exact 也套配置快照（先清窗内再刷）。
--- 通路 mask 在 apply_snapshot_grids 内生成前算完并烘焙进 snapshot_1x1（供下一层携带）。
local function apply_snapshot_contents(entry)
	if not entry or not entry.snapshot_1x1 then return end
	local mode = entry.mode
	if mode ~= "snapshot" and mode ~= "echo" and mode ~= "exact" then return end
	local room = Game():GetRoom()
	local snap = entry.snapshot_1x1
	local holder = snap_uses_holder_layout(entry)

	if not entry.contents_applied then
		clear_snap_region_live(room,snap,holder)
	end
	apply_snapshot_grids(entry)

	if not entry.contents_applied then
		entry.contents_applied = true
		for _,ent_info in ipairs(snap.entities or {}) do
			local gidx = snapshot_cell_grid_index(snap,ent_info.rx,ent_info.ry,holder)
			local cell = room:GetGridPosition(gidx)
			local pos = cell + Vector(tonumber(ent_info.off_x) or 0,tonumber(ent_info.off_y) or 0)
			if not room:IsPositionInRoom(pos,0) then pos = cell end
			spawn_snapshot_entity(ent_info,pos)
		end
	end
end

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_USE_ITEM,params = item.entity,
Function = function(_,_,_,player,use_flags)
	if use_flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then return end
	local result = record_current_room(player)
	if not result then
		player:AnimateSad()
		return {Discharge = false,ShowAnim = false}
	end
	-- 仅新建锚点刷魂火；收回不得刷。默认预算 0 挡美德书误刷。
	item.wisp_spawn_budget = 0
	if result == "anchor" then
		try_spawn_destiny_wisp(player,player.Position,use_flags)
	end
	return {Discharge = false,ShowAnim = true}
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,params = enums.Entities.ID_EFFECT_MeusNIL,
Function = function(_,effect)
	local data = effect:GetData()
	if data[marker_hl_key] then
		-- 框线代理：主人没了就自清
		local marker = find_marker_for_hl(data)
		if not marker then
			effect:Remove()
		else
			effect.Position = marker.Position
			effect.DepthOffset = HL_DEPTH
		end
		return
	end
	if not data[marker_key] then return end
	tick_marker_motion(effect,data)
	if not effect:Exists() then return end
	ensure_hl_proxy(effect,data)
	local sprite = effect:GetSprite()
	if sprite:GetAnimation() ~= "Idle" then
		sprite:Play("Idle",true)
	end
	apply_marker_shader(sprite,data,effect)
end,
})

if ModCallbacks.MC_PRE_EFFECT_RENDER then
	table.insert(item.ToCall,{CallBack = ModCallbacks.MC_PRE_EFFECT_RENDER,params = enums.Entities.ID_EFFECT_MeusNIL,
	Function = function(_,effect,offset)
		local data = effect:GetData()
		if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
			if data[marker_key] or data[marker_hl_key] then return false end
			return
		end
		-- 框线走低 DepthOffset 代理：盖地形、尽量不挡物品
		if data[marker_hl_key] then
			local marker,md = find_marker_for_hl(data)
			if marker and md then
				render_capture_highlight(marker,md,offset)
			end
			return false
		end
		if not data[marker_key] then return end
		local sprite = effect:GetSprite()
		apply_marker_shader(sprite,data,effect)
		-- 先锚后链：链盖在锚顶衔接处之上；框线由 hl 代理绘制
		render_marker_body(effect,sprite,offset)
		render_marker_chains(effect,data,offset)
		return false
	end,
	})
else
	table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER,params = enums.Entities.ID_EFFECT_MeusNIL,
	Function = function(_,effect,offset)
		local data = effect:GetData()
		if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
		if data[marker_hl_key] then
			local marker,md = find_marker_for_hl(data)
			if marker and md then
				render_capture_highlight(marker,md,offset)
			end
			return
		end
		if not data[marker_key] then return end
		local sprite = effect:GetSprite()
		apply_marker_shader(sprite,data,effect)
		render_marker_chains(effect,data,offset)
	end,
	})
end

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN,params = nil,priority = -40,
Function = function(_,tp,vr,st,gidx,seed)
	if tp ~= 303 or vr ~= enums.Enemies.DestinyToken then return end
	-- holder 占位：一律换成 RemoverToken，实际内容在 POST_NEW_ROOM 按 snapshot 生成
	return {303,enums.Enemies.RemoverToken,0}
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NPC_INIT,params = 303,
Function = function(_,ent)
	if ent.Variant == enums.Enemies.RemoverToken then
		ent:Remove()
	end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NEW_ROOM,params = nil,
Function = function(_)
	-- 防御性清理（luamod 等）；正常换房引擎已清空实体
	clear_destiny_markers()
	-- 命运魂火绑房：离房先存状态并移除，再按本房状态决定是否重生
	stash_and_remove_destiny_wisps()
	item.wisp_spawn_budget = 0
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local records = get_floor_records(nil,false)
	local dim = room_dimension(desc)
	local sgid = tonumber(desc and desc.SafeGridIndex)
	local reproduced = get_reproduced_records(nil,false)
	local entry = reproduced and sgid and (reproduced[sgid] or reproduced[tostring(sgid)])
	-- 必须先换房背景，再刷障碍：否则石头会吃当前层皮肤，形态/皮肤对不上
	if entry then
		apply_room_gfx(entry.room_gfx)
		-- exact / snapshot / echo：首访铺实体+障碍；再访/小退也对齐障碍（PostInit，修碎石）
		if Game():GetRoom():IsFirstVisit() then
			apply_snapshot_contents(entry)
		elseif entry.mode == "snapshot" or entry.mode == "echo" or entry.mode == "exact" then
			refresh_snapshot_grid_visuals(entry)
		end
	end
	local record = records and find_record(records,sgid,dim)
	if record then
		spawn_marker(marker_world_pos(record),false,record.echo == true,record.snapshot_1x1,{
			sgid = sgid,
			dim = dim,
			floor = floor_seed(),
		})
		local player = Game():GetPlayer(0)
		local heal_full = entry ~= nil
		respawn_destiny_wisp_from_state(player,heal_full)
		if heal_full then
			heal_destiny_wisps()
		end
	end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NEW_ROOM,params = nil,priority = 50,
Function = function(_)
	if item.pending_failure_notice then
		show_destiny_message("failed")
		item.pending_failure_notice = nil
	end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local reproduced = get_reproduced_records(nil,false)
	local sgid = tonumber(desc and desc.SafeGridIndex)
	local entry = reproduced and sgid and (reproduced[sgid] or reproduced[tostring(sgid)])
	if not entry then return end
	-- 晚一点再刷一次 gfx（StageAPI 可能稍后改写），并 PostInit/换肤障碍
	apply_room_gfx(entry.room_gfx)
	if entry.mode == "snapshot" or entry.mode == "echo" or entry.mode == "exact" then
		refresh_snapshot_grid_visuals(entry)
	end
	if not entry.announced then
		show_destiny_message(entry.mode)
		entry.announced = true
	end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL,params = nil,priority = -50,
Function = function(_)
	local new_seed = floor_seed()
	local source_seed = item.current_floor_seed
	local force_devil = save.elses[force_devil_key] == true
	-- 彼列：先保证本层恶魔房槽位，再让 reproduce 把源 config exact 盖上去
	if force_devil then
		save.elses[force_devil_key] = nil
		ensure_devil_room_desc()
	end
	if source_seed and source_seed ~= new_seed then
		reproduce_anchors(source_seed)
	else
		clear_place_session()
	end
	item.current_floor_seed = new_seed
	item.holder_config_cache = nil
	item.reanchor_cache = {}
	get_floor_records(new_seed,true)
	get_reproduced_records(new_seed,true)
end,
})

if ModCallbacks.MC_PRE_LEVEL_INIT then
	table.insert(item.ToCall,{CallBack = ModCallbacks.MC_PRE_LEVEL_INIT,params = nil,priority = -50,
	Function = function(_)
		item.holder_config_cache = nil
		local source = item.current_floor_seed
		local now = floor_seed()
		if source and source ~= now then
			begin_place_session(source)
		else
			clear_place_session()
		end
	end,
	})
end

if ModCallbacks.MC_POST_LEVEL_LAYOUT_GENERATED then
	table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_LEVEL_LAYOUT_GENERATED,params = nil,priority = -50,
	Function = function(_,level_generator)
		plan_place_session(level_generator)
	end,
	})
end

if ModCallbacks.MC_PRE_LEVEL_PLACE_ROOM then
	table.insert(item.ToCall,{CallBack = ModCallbacks.MC_PRE_LEVEL_PLACE_ROOM,params = nil,priority = -50,
	Function = function(_,slot,room_config,seed)
		return try_place_room_for_slot(slot,room_config,seed)
	end,
	})
end

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_FAMILIAR_INIT,params = FamiliarVariant.WISP,
Function = function(_,ent)
	if ent.SubType ~= item.entity then return end
	local budget = item.wisp_spawn_budget or 0
	if budget <= 0 then
		-- 非本模组显式生成（美德书误刷等）直接丢弃，且不记熄灭
		ent:GetData()[wisp_stash_key] = true
		ent:Remove()
		return
	end
	item.wisp_spawn_budget = budget - 1
	apply_destiny_wisp_look(ent)
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE,params = FamiliarVariant.WISP,
Function = function(_,ent)
	if ent.SubType ~= item.entity then return end
	apply_destiny_wisp_look(ent)
	-- 钉在本房命运锚前；自管射击（原版 FireCooldown 已压死）
	local marker = find_destiny_marker_in_room()
	if marker and marker:Exists() then
		ent.Position = marker.Position
		ent.Velocity = Vector.Zero
		ent.DepthOffset = WISP_DEPTH
	end
	destiny_wisp_try_fire(ent)
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL,params = EntityType.ENTITY_FAMILIAR,
Function = function(_,ent)
	if not ent or ent.Variant ~= FamiliarVariant.WISP or ent.SubType ~= item.entity then return end
	local d = ent:GetData()
	if d[wisp_stash_key] then return end
	local sgid = tonumber(d[item.own_key.."wisp_sgid"])
	local dim = tonumber(d[item.own_key.."wisp_dim"]) or 0
	local floor = d[item.own_key.."wisp_floor"] or floor_seed()
	if sgid ~= nil then
		mark_wisp_extinguished(floor,sgid,dim)
	end
end,
})

table.insert(item.myToCall,{CallBack = enums.Callbacks.PRE_GAME_STARTED,params = nil,
Function = function(_,continue)
	if not continue then
		save.elses[save_key] = {}
		save.elses[reproduced_key] = {}
		save.elses[force_devil_key] = nil
		save.elses[wisp_state_key] = {}
		save.elses[wisp_quota_key] = {}
	end
	save.elses[save_key] = save.elses[save_key] or {}
	save.elses[reproduced_key] = save.elses[reproduced_key] or {}
	save.elses[wisp_state_key] = save.elses[wisp_state_key] or {}
	save.elses[wisp_quota_key] = save.elses[wisp_quota_key] or {}
	item.runtime_configs = {}
	item.pending_failure_notice = nil
	item.holder_config_cache = nil
	item.reproduce_source_seed = nil
	clear_place_session()
	item.current_floor_seed = floor_seed()
	get_floor_records(item.current_floor_seed,true)
	get_reproduced_records(item.current_floor_seed,true)
end,
})

-- 主动槽左上角：剩余可锚定次数（与 Core Brooch / Book of Rune 同字体）
local anchor_count_font = Font()
anchor_count_font:Load("font/luaminioutlined.fnt")

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_RENDER,params = "Active",
Function = function(_,player,tp,cid,slot)
	if cid ~= item.entity then return end
	local records = get_floor_records(nil,false) or {}
	local remain = math.max(0,item.max_anchors - #records)
	local pos = ui.PlayerActiveUIPos(player,slot,auxi.GetPlayerOrder(player),cid)
	local alpha = slot_render_holder.get_alpha()
	-- 红色字：x1 / x2 / x3（剩余可用锚）
	gui.draw_ch(pos + Vector(-16,-16),"x"..tostring(remain),1,1,KColor(1,0.15,0.15,alpha),true,anchor_count_font)
end,
})

return item

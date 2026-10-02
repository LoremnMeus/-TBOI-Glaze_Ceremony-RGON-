local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

-- 纳兹卡巨画：逻辑 Painter + 按玩家归属的 Heat Map + 地板视觉层
-- 不再用大量真实 familiar 承担绘图/碰撞。

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Nazca,
	familiar = enums.Familiars.Nazca, -- 仅用于 CheckFamiliar(0) 清旧实体
	CELL = 12,
	STEP_INTERVAL = 5,
	HEAT_CAP_BASE = 10,
	HEAT_CAP_PER_COPY = 2,
	SEIJA_HEAT_CAP = 5,
	DMG_PER_HEAT = 0.03, -- 乘算，上限见 DMG_MUL_CAP
	DMG_MUL_CAP = 0.5,
	SPEED_PER_HEAT = 0.015,
	ENEMY_DMG_FACTOR = 0.15,
	ANM2 = "gfx/mimics/Nazca/Nazca.anm2",
	dirs = {
		Up = {move = Vector(1, 0), dir_move = 0},
		Right = {move = Vector(0, 1), dir_move = 90},
		Left = {move = Vector(0, -1), dir_move = -90},
		Down = {move = Vector(-1, 0), dir_move = 180},
	},
	record_dirs = {"Up", "Right", "Left", "Down"},
	maps = {}, -- [owner_idx] = { ["x_y"] = intensity }
	-- stroke visual: [owner|cell|SignedName|rotation] = effect；Heat 与笔画拓扑分离
	visuals = {},
	painters = {}, -- list of logic painters（含纯视觉 head proxy）
	last_player_heat = {}, -- [owner_idx] = sampled heat for cache dirty
}

auxi.add_to_seija(item.entity)

local function cell_pos(pos)
	return auxi.GetChampPosition(pos, item.CELL)
end

local function cell_key(pos)
	local p = cell_pos(pos)
	return ("" .. p.X .. "_" .. p.Y), p
end

local function owner_map(idx)
	item.maps[idx] = item.maps[idx] or {}
	return item.maps[idx]
end

local function heat_cap_of(player)
	local copies = math.max(1, player:GetCollectibleNum(item.entity))
	local cap = item.HEAT_CAP_BASE + (copies - 1) * item.HEAT_CAP_PER_COPY
	if auxi.should_do_Seija(player) then
		cap = math.min(cap, item.SEIJA_HEAT_CAP)
	end
	return math.max(1, cap)
end

local function painter_count_of(player)
	if auxi.should_do_Seija(player) then return 1 end
	local copies = math.max(1, player:GetCollectibleNum(item.entity))
	local stage = Game():GetLevel():GetStage()
	return copies * 2 + 4 + math.floor(stage / 2)
end

local function step_interval_of(player)
	return item.STEP_INTERVAL
end

local function get_heat(idx, pos)
	local key = cell_key(pos)
	local m = item.maps[idx]
	if not m then return 0 end
	return m[key] or 0
end

local function sample_heat(idx, pos)
	local ret = 0
	local c = item.CELL
	for i = 1, 3 do
		for j = 1, 3 do
			ret = ret + get_heat(idx, Vector(pos.X + (i - 2) * c, pos.Y + (j - 2) * c))
		end
	end
	return ret / 9
end

-- Heat → 白→红浓度；Alpha 始终保持高可见（首笔约 0.78，满热 1.0）
local function stroke_color(intensity, cap)
	local t = math.min(1, intensity / math.max(1, cap))
	local alpha = 0.78 + 0.22 * t
	local col = auxi.AddColor(Color(1, 1, 1, 1), Color(1, 0, 0, 1, 1, 0, 0), 1 - t, t)
	return Color(col.R, col.G, col.B, alpha, col.RO, col.GO, col.BO)
end

local function stroke_visual_key(idx, cell, signed_name, rotation)
	return idx .. "|" .. cell .. "|" .. (signed_name or "SignedUp") .. "|" .. tostring((rotation or 0) % 360)
end

-- 旧 Familiar 在 Rotation 90/270 特定格点上有 1px 对齐补偿（12px 格 + 旋转纹理）
local function apply_stroke_pixel_nudge(ent, rotation)
	local rot = (rotation or 0) % 360
	if rot == 270 then
		local m = ent.Position.X % 60
		if m == 24 or m == 36 then
			ent.Position = ent.Position + Vector(1, 0)
		end
	elseif rot == 90 then
		local m = ent.Position.Y % 60
		if m == 24 or m == 36 then
			ent.Position = ent.Position + Vector(0, 1)
		end
	end
end

local function ensure_visual(idx, pos, intensity, cap, signed_name, rotation)
	local cell = select(1, cell_key(pos))
	local key = stroke_visual_key(idx, cell, signed_name, rotation)
	local col = stroke_color(intensity, cap)
	local ent = item.visuals[key]
	if ent and ent:Exists() then
		ent:GetSprite().Color = col
		return ent
	end
	local q = auxi.fire_nil(cell_pos(pos), Vector(0, 0), {cooldown = 999999})
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	q.GridCollisionClass = GridCollisionClass.COLLISION_NONE
	local s = q:GetSprite()
	s:Load(item.ANM2, true)
	s:Play(signed_name or "SignedUp", true)
	s.Rotation = rotation or 0
	s.Color = col
	apply_stroke_pixel_nudge(q, rotation)
	q:AddEntityFlags(EntityFlag.FLAG_RENDER_FLOOR)
	item.visuals[key] = q
	return q
end

local function add_heat(player, idx, pos, signed_name, rotation)
	local key, snapped = cell_key(pos)
	local m = owner_map(idx)
	local cap = heat_cap_of(player)
	local nextv = math.min(cap, (m[key] or 0) + 1)
	m[key] = nextv
	ensure_visual(idx, snapped, nextv, cap, signed_name, rotation)
	return nextv
end

local function remove_painter_head(p)
	if p and p.head and p.head:Exists() then
		p.head:Remove()
	end
	if p then
		p.head = nil
		p.pending_stroke = nil
	end
end

local function spawn_painter_head(pos)
	local q = auxi.fire_nil(cell_pos(pos), Vector(0, 0), {cooldown = 999999})
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	q.GridCollisionClass = GridCollisionClass.COLLISION_NONE
	-- 不用 FLAG_RENDER_FLOOR（会每帧印到地板）；用很小的 DepthOffset 压在角色之下
	q.DepthOffset = -200
	local s = q:GetSprite()
	s:Load(item.ANM2, true)
	s:Play("Up", true)
	s.Color = Color(1, 1, 1, 1)
	return q
end

-- 方案 A：笔头实体停在 from_pos，用 Up/Right/Left/Down 动画表现格内位移
local function update_painter_head(p, from_pos, local_dir, from_rotation, player)
	if not p.head or not p.head:Exists() then
		p.head = spawn_painter_head(from_pos)
	end
	local head = p.head
	head.Position = from_pos
	head.Velocity = Vector(0, 0)
	head.DepthOffset = -200
	local hs = head:GetSprite()
	hs.Rotation = from_rotation
	hs:Play(local_dir or "Up", true)
	local heat = sample_heat(p.owner_idx, from_pos)
	local cap = heat_cap_of(player)
	local t = math.min(1, heat / math.max(1, cap))
	hs.Color = auxi.AddColor(Color(1, 1, 1, 1), Color(1, 0, 0, 1, 1, 0, 0), 1 - t, t)
end

local function clear_room_state()
	for _, p in ipairs(item.painters) do
		remove_painter_head(p)
	end
	for _, ent in pairs(item.visuals) do
		if ent and ent:Exists() then
			ent:Remove()
		end
	end
	item.maps = {}
	item.visuals = {}
	item.painters = {}
	item.last_player_heat = {}
end

local function player_by_idx(idx)
	for playerNum = 1, Game():GetNumPlayers() do
		local p = Game():GetPlayer(playerNum - 1)
		if p and p:GetData().__Index == idx then
			return p
		end
	end
	return nil
end

-- path states（保留原「道/直线/转弯/环/初始/朝敌」思想，落在逻辑 painter 上）
item.move_stag = {
	[1] = {
		stag = function(p)
			local counter = p.counter
			local mx_counter = p.mx_counter
			local r, l = "Right", "Left"
			if counter == 0 then
				if p.dir_dice and p.ignore_dice_counter then
					p.ignore_dice_counter = nil
				else
					p.dir_dice = math.random(2)
				end
				p.counter_dis_part = math.floor(mx_counter / 2) - 1 + math.floor(mx_counter / 8) * (math.random(2) * 2 - 3)
			end
			if p.dir_dice == 1 then l, r = "Right", "Left" end
			if p.counter_dis_part == nil then
				p.counter_dis_part = math.floor(mx_counter / 2) - 1 + math.floor(mx_counter / 8) * (math.random(2) * 2 - 3)
			end
			if counter == p.counter_dis_part - 1 or counter == p.counter_dis_part then return l end
			if counter == mx_counter - 2 or counter == mx_counter - 1 then return r end
			return "Up"
		end,
		mx_counter = function() return math.random(6) + 8 end,
		trans_stag = function(p)
			if math.random(1000) < 850 then
				p.ignore_dice_counter = true
				return 1
			end
			if math.random(1000) < 400 then return 3 end
		end,
	},
	[2] = {
		stag = function() return "Up" end,
		mx_counter = function() return math.random(7) end,
		trans_stag = function()
			if math.random(1000) < 400 then return 3 end
			if math.random(1000) < 200 then return 4 end
		end,
	},
	[3] = {
		stag = function()
			if math.random(2) == 1 then return "Right" else return "Left" end
		end,
		mx_counter = function() return 1 end,
		trans_stag = function()
			if math.random(1000) < 400 then return 2 end
			if math.random(1000) < 300 then return 1 end
			return 5
		end,
	},
	[4] = {
		stag = function(p)
			local counter = p.counter
			local mx_counter = p.mx_counter
			local r, l = "Right", "Left"
			if counter == 0 then p.dir_dice = math.random(2) end
			if p.dir_dice == 1 then l, r = "Right", "Left" end
			if counter == 0 or counter == mx_counter - 1 then return l end
			local a = math.floor(mx_counter * 0.125)
			local b = math.floor(mx_counter * 0.375)
			local c = math.floor(mx_counter * 0.625)
			local d = math.floor(mx_counter * 0.875)
			if counter == a or counter == b or counter == c or counter == d then return r end
			return "Up"
		end,
		mx_counter = function() return math.random(10) + 14 end,
		trans_stag = function()
			if math.random(1000) < 500 then return 2 end
		end,
	},
	[5] = {
		stag = function() return "Up" end,
		mx_counter = function() return 3 end,
		trans_stag = function() return 2 end,
	},
	[6] = {
		stag = function(p, player)
			local target = p.target
			if target == nil or (not target:Exists()) or target:IsDead() then
				target = auxi.get_by_nearest_enemy(p.Position)
				p.target = target
			end
			if target then
				return auxi.Get_dir_name(auxi.Get_direction_by_angle((target.Position - p.Position):GetAngleDegrees() - p.now_dir))
			end
			return auxi.Get_dir_name(auxi.Get_direction_by_angle((player.Position - p.Position):GetAngleDegrees() - p.now_dir))
		end,
		mx_counter = function() return 5 + math.random(10) end,
		trans_stag = function() end,
	},
}

local function free_dirs(p)
	local room = Game():GetRoom()
	local tbl = {}
	local r_tbl = {}
	for name, info in pairs(item.dirs) do
		local t_pos = p.Position + item.CELL * auxi.get_by_rotate(info.move, p.now_dir)
		if room:GetGridCollisionAtPos(t_pos) == GridCollisionClass.COLLISION_NONE and room:IsPositionInRoom(t_pos, 5) then
			tbl[#tbl + 1] = name
			r_tbl[name] = true
		end
	end
	return tbl, r_tbl
end

local function heat_ahead(idx, p, local_dir)
	local info = item.dirs[local_dir] or item.dirs.Up
	return get_heat(idx, p.Position + auxi.get_by_rotate(info.move, p.now_dir) * item.CELL)
end

local function choose_dir(p, player)
	local idx = p.owner_idx
	local tbl, r_tbl = free_dirs(p)
	if #tbl == 0 then
		local dir = auxi.Get_dir_name(auxi.Get_direction_by_angle((player.Position - p.Position):GetAngleDegrees() - p.now_dir))
		p.move_state = 5
		p.mx_counter = 6
		p.counter = 0
		p.state = 1
		p.dir_stack = 0
		p.threshold = math.max(20, (p.threshold or 0) + 2)
		p.Position = cell_pos(player.Position)
		p.spawn_head = true
		return dir
	end

	p.state = p.state or 0
	p.counter = (p.counter or 0) + 1
	p.move_state = p.move_state or 5
	p.mx_counter = p.mx_counter or 1
	p.threshold = p.threshold or 1
	p.dir_stack = p.dir_stack or 0

	local info = item.move_stag[p.move_state]
	if p.counter >= p.mx_counter then
		local next_state = info.trans_stag and info.trans_stag(p) or nil
		if next_state == nil then next_state = math.random(#item.move_stag) end
		p.move_state = next_state
		info = item.move_stag[p.move_state]
		p.counter = 0
		p.mx_counter = info.mx_counter()
		if p.state == 1 then p.state = 0 end
	end

	if (p.threshold or 0) > 70 and math.random(1000) > 700 then
		p.move_state = 6
		info = item.move_stag[6]
		p.counter = 0
		p.mx_counter = info.mx_counter()
	end

	local dir = info.stag(p, player)
	local ignore_it = false
	if not r_tbl[dir] then
		if math.random(1000) > 200 then
			local l, r = "Left", "Right"
			if math.random(2) == 1 then l, r = "Right", "Left" end
			if r_tbl[l] then dir = l
			elseif r_tbl[r] then dir = r
			elseif r_tbl["Up"] then dir = "Up"
			else dir = "Down" end
		else
			ignore_it = true
		end
	end

	if dir == "Left" then p.dir_stack = p.dir_stack + 1 end
	if dir == "Right" then p.dir_stack = p.dir_stack - 1 end
	if dir == "Down" then p.dir_stack = -p.dir_stack end
	if dir == "Up" then p.dir_stack = p.dir_stack * 0.9 end
	if p.dir_stack > 2.5 and r_tbl["Right"] then
		dir = "Right"
		p.dir_stack = 2
	elseif p.dir_stack < -2.5 and r_tbl["Left"] then
		dir = "Left"
		p.dir_stack = -2
	end

	if not ignore_it and heat_ahead(idx, p, dir) >= 1 then
		local best, best_v = dir, 1000000
		for _, name in ipairs(tbl) do
			local offset = (name == "Down") and 2 or 0
			local ck = heat_ahead(idx, p, name) + offset
			if ck < best_v then
				best_v = ck
				best = name
			end
		end
		dir = best
		p.threshold = (p.threshold or 0) + 1
	else
		p.threshold = math.max(0, (p.threshold or 0) - 1)
	end
	return dir
end

local function step_painter(p)
	local player = player_by_idx(p.owner_idx)
	if not player or not player:Exists() or not auxi.has_have_coll(player, item.entity) then
		remove_painter_head(p)
		return false
	end

	-- 旧 Familiar：动画 IsFinished 后才在当前格落下 Signed，再移动。
	-- 逻辑节奏仍由 step_cd 驱动；到期时先提交上一格笔触，再开下一格笔头动作。
	if p.pending_stroke then
		local ps = p.pending_stroke
		-- Stroke belongs to FROM cell.
		-- Match pre-logic-painter Familiar rendering semantics.
		add_heat(player, p.owner_idx, ps.from_pos, ps.signed, ps.rotation)
		p.Position = ps.to_pos
		p.now_dir = ps.to_dir
		p.pending_stroke = nil
	end

	local local_dir = choose_dir(p, player)
	-- choose_dir 可能卡死传送；新笔头从传送后位置开始画
	local from_pos = cell_pos(p.Position)
	local from_rotation = p.now_dir

	local dir_info = item.dirs[local_dir] or item.dirs.Up
	local world_move = auxi.get_by_rotate(dir_info.move, from_rotation)
	local to_pos = cell_pos(from_pos + world_move * item.CELL)
	local to_dir = (from_rotation + dir_info.dir_move) % 360

	if p.spawn_head then
		-- 重定位痕迹（地板印记）；移动笔头由 head proxy 承担
		ensure_visual(p.owner_idx, from_pos, math.max(1, get_heat(p.owner_idx, from_pos)), heat_cap_of(player), "SignedHead", from_rotation)
		p.spawn_head = nil
	end

	-- 本步只播笔头；笔触挂到 pending，等下一次 step 到期再落下
	update_painter_head(p, from_pos, local_dir, from_rotation, player)
	p.pending_stroke = {
		from_pos = from_pos,
		to_pos = to_pos,
		rotation = from_rotation,
		to_dir = to_dir,
		signed = "Signed" .. local_dir,
	}
	p.step_cd = step_interval_of(player)
	return true
end

local function rebuild_painters_for_player(player)
	local idx = player:GetData().__Index
	if idx == nil then return end
	local kept = {}
	for _, p in ipairs(item.painters) do
		if p.owner_idx ~= idx then
			kept[#kept + 1] = p
		else
			remove_painter_head(p)
		end
	end
	item.painters = kept
	local n = painter_count_of(player)
	local base = cell_pos(player.Position)
	for i = 1, n do
		local pos = base + Vector(((i - 1) % 2) * item.CELL, math.floor((i - 1) / 2) * item.CELL)
		local painter = {
			owner_idx = idx,
			Position = pos,
			now_dir = (i - 1) * 90,
			move_state = 5,
			counter = 0,
			mx_counter = 3,
			threshold = 0,
			dir_stack = 0,
			state = 0,
			step_cd = i,
			trail_id = i,
			head = nil,
		}
		update_painter_head(painter, pos, "Up", painter.now_dir, player)
		item.painters[#item.painters + 1] = painter
	end
end

local function sync_all_painters()
	local seen = {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player, item.entity) then
			local idx = player:GetData().__Index
			seen[idx] = true
			local have = 0
			for _, p in ipairs(item.painters) do
				if p.owner_idx == idx then have = have + 1 end
			end
			if have ~= painter_count_of(player) then
				rebuild_painters_for_player(player)
			end
		end
	end
	local kept = {}
	for _, p in ipairs(item.painters) do
		if seen[p.owner_idx] then
			kept[#kept + 1] = p
		else
			remove_painter_head(p)
		end
	end
	item.painters = kept
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	-- 清掉旧 Nazca familiar，避免残留实体进入 follower/Emblem 系统
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, 0, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
	if not auxi.has_have_coll(player, item.entity) then return end
	local idx = player:GetData().__Index
	if idx == nil then return end
	local heat = sample_heat(idx, player.Position)
	local d = player:GetData()
	d.Nazca_counter_delay = (d.Nazca_counter_delay or 0) * 0.7 + heat * 0.3
	heat = d.Nazca_counter_delay
	if heat <= 0 then return end
	if cacheFlag == CacheFlag.CACHE_DAMAGE then
		local mul = 1 + math.min(item.DMG_MUL_CAP, heat * item.DMG_PER_HEAT)
		player.Damage = player.Damage * mul
	end
	if cacheFlag == CacheFlag.CACHE_SPEED then
		player.MoveSpeed = player.MoveSpeed + heat * item.SPEED_PER_HEAT
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_, ent)
	if not (ent:IsVulnerableEnemy() and ent:IsActiveEnemy() and not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) then
		return
	end
	if not ent:IsFrame(10, 0) then return end
	local best_player, best_heat = nil, 0
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player, item.entity) then
			local idx = player:GetData().__Index
			if idx then
				local h = sample_heat(idx, ent.Position)
				if h > best_heat then
					best_heat = h
					best_player = player
				end
			end
		end
	end
	if best_player and best_heat >= 1 then
		ent:TakeDamage(item.ENEMY_DMG_FACTOR * best_player.Damage * best_heat, 0, EntityRef(best_player), 0)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	sync_all_painters()
	local alive = {}
	for i = 1, #item.painters do
		local p = item.painters[i]
		p.step_cd = (p.step_cd or 0) - 1
		if p.step_cd <= 0 then
			if step_painter(p) then
				alive[#alive + 1] = p
			end
		else
			alive[#alive + 1] = p
		end
	end
	item.painters = alive

	-- 仅当脚下 heat 变化时刷新属性，避免无条件全体每帧 Evaluate
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player, item.entity) then
			local idx = player:GetData().__Index
			if idx then
				local heat = sample_heat(idx, player.Position)
				local prev = item.last_player_heat[idx] or -1
				if math.abs(heat - prev) > 0.05 then
					item.last_player_heat[idx] = heat
					player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SPEED)
					player:GetData().should_evaluate_on_update_once = true
				end
			end
		end
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	clear_room_state()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player, item.entity) then
			rebuild_painters_for_player(player)
			player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SPEED)
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player, item.entity) then
			rebuild_painters_for_player(player)
			player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_)
	clear_room_state()
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_)
	clear_room_state()
end,
})

return item

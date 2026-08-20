local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

-- 中枢挂在本层 13×13 地图格上（MakeRedRoomDoor + Room_holder），不是 StageAPI ExtraRoom，也不是 -3 调试房。
-- 进出用愚者漩涡（1000/161 + PORTAL_TELEPORT），贴图 tp=120。
-- 布局是超级隐藏房（type 8），用该类型自带背景；不在这里强行换 LIBRARY。
local M = {
	ToCall = {},
	core = nil,
	own_key = "zeiz_hub_room_",
	hub_room_variant = 24830,
	hub_room_type = RoomType.ROOM_SUPERSECRET,
	hub_goto = "supersecret",
	fallback_room_variant = 24820,
	fallback_room_type = RoomType.ROOM_DEFAULT,
	fallback_goto = "default",
	portal_tp = 120,
}

function M.bind(core)
	M.core = core
end

local function hub_data()
	return M.core.save.data().hub
end

local function wizard()
	return require("Qing_Remaster_scripts.cards.Card_01_Wizard")
end

local function get_room_config(variant, room_type)
	if not REPENTOGON then return nil end
	local holder = rawget(_G, "RoomConfig") or rawget(_G, "RoomConfigHolder")
	if not holder or not holder.GetRoomByStageTypeAndVariant then return nil end
	local mode = Game():IsGreedMode() and 1 or 0
	local success, room_config = pcall(
		holder.GetRoomByStageTypeAndVariant,
		StbType.SPECIAL_ROOMS,
		room_type,
		variant,
		mode
	)
	if success then return room_config end
	return nil
end

function M.get_hub_room_config()
	return get_room_config(M.hub_room_variant, M.hub_room_type)
		or get_room_config(M.fallback_room_variant, M.fallback_room_type)
end

function M.is_current()
	local data = hub_data()
	local idx = tonumber(data.hub_index)
	if idx == nil or idx < 0 then return false end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return false end
	if desc.SafeGridIndex ~= idx then return false end
	local dim = tonumber(data.hub_dimension) or 0
	return auxi.check_equal(auxi.GetDimension(), dim)
end

local function hide_desc(desc)
	if not desc then return end
	desc.DisplayFlags = 0
	if desc.Flags then
		desc.Flags = desc.Flags & ~(1 << 10)
	end
end

-- 与 DVF/Chasm 相同：先占地图格，真正进房前再注入 special room Data。
function M.queue_layout(hub_index, dimension)
	Room_holder.Try_replace_with(hub_index, dimension, {
		data = function()
			local room_config = M.get_hub_room_config()
			if room_config then return room_config end
			Isaac.ExecuteCommand("goto s."..M.hub_goto.."."..tostring(M.hub_room_variant))
			local debug_desc = Game():GetLevel():GetRoomByIdx(-3)
			if debug_desc and debug_desc.Data then return debug_desc.Data end
			Isaac.ExecuteCommand("goto s."..M.fallback_goto.."."..tostring(M.fallback_room_variant))
			debug_desc = Game():GetLevel():GetRoomByIdx(-3)
			return debug_desc and debug_desc.Data
		end,
	})
end

function M.ensure_placed()
	local core = M.core
	if not core.util.any_zeiz() then return nil end
	local data = hub_data()
	local floor = core.util.floor_id()
	local dim = auxi.GetDimension() or 0
	if data.hub_index and data.hub_floor == floor then
		local desc = Game():GetLevel():GetRoomByIdx(data.hub_index, data.hub_dimension or dim)
		if desc and desc.Data then
			hide_desc(desc)
			return data.hub_index
		end
	end

	local level = Game():GetLevel()
	local room_config = M.get_hub_room_config()
	local hub_index = nil
	if room_config and level.TryPlaceRoom then
		local seed = level:GetDungeonPlacementSeed()
		for grid_index = 0, 168 do
			local desc = level:GetRoomByIdx(grid_index, dim)
			if desc and desc.Data == nil then
				local success, placed = pcall(function()
					return level:TryPlaceRoom(
						room_config,
						grid_index,
						dim,
						seed + grid_index,
						true,
						true,
						true
					)
				end)
				if success and placed then
					hub_index = placed.SafeGridIndex
					break
				end
			end
		end
	end
	if hub_index == nil then
		hub_index = Room_holder.Allocate_with()
		if hub_index and hub_index >= 0 then
			M.queue_layout(hub_index, dim)
		end
	elseif room_config == nil then
		M.queue_layout(hub_index, dim)
	end
	if hub_index == nil or hub_index < 0 then return nil end

	data.hub_index = hub_index
	data.hub_dimension = dim
	data.hub_floor = floor
	hide_desc(level:GetRoomByIdx(hub_index, dim))
	return hub_index
end

local function find_tagged_portal(tag)
	local n_entity = Isaac.GetRoomEntities()
	for i = 1, #n_entity do
		local ent = n_entity[i]
		if ent and ent:Exists() and ent:GetData()[M.own_key.."portal"] == tag then
			return ent
		end
	end
	return nil
end

-- 与 Zeis 相同：自定义 chromatic dogma，避开原版 STATIC→coloroffset_dogma 吃 PixelationAmount 的马赛克残留。
-- Colorize.r=glitch，Colorize.a=时间轴（见 qing_dogma_chromatic.fs）。
local function apply_hub_portal_dogma(ent)
	if not REPENTOGON or not ent then return end
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	local sprite = ent:GetSprite()
	if not sprite then return end
	temp_hud.apply_sprite_shader(sprite, temp_hud.DOGMA_CHROMATIC_SHADER)
	local col = sprite.Color
	local t = temp_hud.dogma_shader_time()
	if col.SetColorize then
		local next_col = Color(col.R, col.G, col.B, col.A, col.RO, col.GO, col.BO)
		next_col:SetColorize(0, 0, 0, t)
		sprite.Color = next_col
	else
		sprite.Color = Color(col.R, col.G, col.B, col.A, col.RO, col.GO, col.BO, 0, 0, 0, t)
	end
end

function M.prepare_visit(player)
	local core = M.core
	local data = hub_data()
	player = player or core.util.zeiz_player() or Game():GetPlayer(0)
	local level = Game():GetLevel()
	local current = level:GetCurrentRoomDesc()
	data.origin_index = current and current.SafeGridIndex or level:GetStartingRoomIndex()
	data.origin_dimension = auxi.GetDimension() or 0
	data.origin_x = player.Position.X
	data.origin_y = player.Position.Y
	data.initialized = true
	if not data.currentCandidates or #data.currentCandidates == 0 then
		core.hub.roll_candidates()
	end
	core.proposal.offer_pending()
end

local function spawn_hub_portal(pos, tag, gidx, dim, extra)
	extra = extra or {}
	local q = wizard().spawn_a_fool_port(pos, {
		info = {
			id = -1,
			tp = M.portal_tp,
			gidx = gidx,
			dim = dim or 0,
		},
		Special = extra.Special,
		On_Arrive = extra.On_Arrive,
	})
	q:GetData()[M.own_key.."portal"] = tag
	apply_hub_portal_dogma(q)
	return q
end

function M.entrance_pos()
	local room = Game():GetRoom()
	local center = room:GetCenterPos()
	return room:GetClampedPosition(center + Vector(0, 80), 20)
end

function M.try_spawn_entrance()
	local core = M.core
	if not core.util.any_zeiz() then return false end
	if M.is_current() then return false end
	local level = Game():GetLevel()
	if level:GetCurrentRoomIndex() ~= level:GetStartingRoomIndex() then return false end
	if not core.hub.legal_room() then return false end
	local hub_index = M.ensure_placed()
	if not hub_index then return false end
	if find_tagged_portal("enter") then return true end
	local data = hub_data()
	spawn_hub_portal(M.entrance_pos(), "enter", hub_index, data.hub_dimension, {
		Special = function(player)
			M.prepare_visit(player)
		end,
		On_Arrive = function()
			hub_data().transitionLock = false
		end,
	})
	data.trapdoor_room = Game():GetLevel():GetCurrentRoomIndex()
	return true
end

function M.enter(player)
	local core = M.core
	if M.is_current() then return true end
	local data = hub_data()
	if data.transitionLock then return false end
	local hub_index = M.ensure_placed()
	if not hub_index then return false end
	player = player or core.util.zeiz_player() or Game():GetPlayer(0)
	M.prepare_visit(player)
	data.transitionLock = true
	Room_holder.Trans_to(
		hub_index,
		Direction.NO_DIRECTION,
		RoomTransitionAnim.PORTAL_TELEPORT,
		player,
		data.hub_dimension,
		{ On_Arrive = function()
			data.transitionLock = false
		end }
	)
	return true
end

function M.leave(player)
	local data = hub_data()
	if data.transitionLock then return false end
	local origin = tonumber(data.origin_index)
	if origin == nil then
		origin = Game():GetLevel():GetStartingRoomIndex()
	end
	player = player or M.core.util.zeiz_player() or Game():GetPlayer(0)
	data.transitionLock = true
	data.open = false
	Room_holder.Trans_to(
		origin,
		Direction.NO_DIRECTION,
		RoomTransitionAnim.PORTAL_TELEPORT,
		player,
		data.origin_dimension or 0,
		{
			On_Arrive = function()
				data.transitionLock = false
				if data.origin_x and data.origin_y then
					player.Position = Vector(data.origin_x, data.origin_y)
				end
			end,
		}
	)
	return true
end

function M.configure_current()
	if not M.is_current() then return end
	local data = hub_data()
	data.open = true
	data.transitionLock = false
	local room = Game():GetRoom()
	local center = room:GetCenterPos()
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		player.Position = room:GetClampedPosition(center + Vector(0, 40), 0)
		player.ControlsEnabled = true
	end
	if not find_tagged_portal("leave") then
		local origin = tonumber(data.origin_index) or Game():GetLevel():GetStartingRoomIndex()
		spawn_hub_portal(room:GetClampedPosition(center + Vector(0, 80), 20), "leave", origin, data.origin_dimension or 0, {
			On_Arrive = function()
				local hub = hub_data()
				hub.open = false
				hub.transitionLock = false
				if hub.origin_x and hub.origin_y then
					local p = M.core.util.zeiz_player() or Game():GetPlayer(0)
					p.Position = Vector(hub.origin_x, hub.origin_y)
				end
			end,
		})
	end
	if M.core.hub_phantom then
		M.core.hub_phantom.spawn_candidates()
	end
end

function M.reset_floor()
	local data = hub_data()
	data.hub_index = nil
	data.hub_dimension = 0
	data.hub_floor = nil
	data.origin_index = nil
	data.origin_dimension = 0
	data.origin_x = nil
	data.origin_y = nil
	data.trapdoor_room = nil
	data.open = false
	data.transitionLock = false
end

table.insert(M.ToCall, #M.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 161,
Function = function(_, ent)
	if not ent:GetData()[M.own_key.."portal"] then return end
	apply_hub_portal_dogma(ent)
end,
})

table.insert(M.ToCall, #M.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	local core = M.core
	if not core or not core.util.any_zeiz() then return end
	local data = hub_data()
	if M.is_current() then
		M.configure_current()
		return
	end
	data.open = false
	data.transitionLock = false
	if data.pendingEntry then
		M.try_spawn_entrance()
	end
end,
})

return M

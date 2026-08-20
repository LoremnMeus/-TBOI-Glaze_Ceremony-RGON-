-- Isaac Dynamic Lighting System（Phase 1 全屏）
-- 全屏黑暗 overlay + 玩家圆形光。不做房间裁剪、不改 POST_RENDER 黑块。
-- 自定义 attribute 仅 P1–P3。换房/暂停菜单时直通，避免切换闪坏。
local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "DynamicLighting_",
	shader_name = "Qing_DynamicLighting",
	buffer = {
		roomInfo = nil,
		lights = {},
		blockers = {},
	},
	defaults = {
		Enabled = false,
		-- 高对比默认：暗部更黑、中心更亮、边缘更利
		Ambient = 0.03,
		Radius = 220,
		Intensity = 1.45,
		Soft = 0.18,
		ColorR = 1,
		ColorG = 1,
		ColorB = 1,
	},
}

local function options_debug()
	local root = save.ModConfigSettings
	return root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
end

local function cfg(key)
	local debug = options_debug()
	local v = debug and debug["DynamicLighting" .. key]
	if v == nil then return item.defaults[key] end
	return v
end

function item.is_enabled()
	return cfg("Enabled") == true
end

local function shader_screen_metrics()
	local size = auxi.GetScreenSize()
	local mult = auxi.check_screen_multi(Vector(1, 1)) * 256
	return {
		size = size,
		mult = mult,
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

local function world_radius_to_uv(world_pos, radius)
	radius = math.max(1, tonumber(radius) or 220)
	local u0, v0, m = world_to_shader_uv(world_pos)
	local u1 = select(1, world_to_shader_uv(world_pos + Vector(radius, 0)))
	local v1 = select(2, world_to_shader_uv(world_pos + Vector(0, radius)))
	local ru = math.abs(u1 - u0)
	local rv = math.abs(v1 - v0)
	local r = 0.5 * (ru + rv)
	if r < 1e-4 then
		r = radius / math.max(m.mult.X, m.mult.Y)
	end
	return r, u0, v0, m
end

local function refresh_room_info()
	local room = Game():GetRoom()
	item.buffer.roomInfo = {
		width = room:GetGridWidth(),
		height = room:GetGridHeight(),
		gridSize = 40,
		shape = room:GetRoomShape(),
	}
	return item.buffer.roomInfo
end

function item.collect_frame_buffer()
	refresh_room_info()
	local lights = {}
	if item.is_enabled() and Game():GetNumPlayers() > 0 then
		local player = Game():GetPlayer(0)
		if player and player:Exists() then
			lights[1] = {
				position = Vector(player.Position.X, player.Position.Y),
				radius = tonumber(cfg("Radius")) or item.defaults.Radius,
				intensity = tonumber(cfg("Intensity")) or item.defaults.Intensity,
				color = {
					tonumber(cfg("ColorR")) or 1,
					tonumber(cfg("ColorG")) or 1,
					tonumber(cfg("ColorB")) or 1,
				},
				type = "player",
			}
		end
	end
	item.buffer.lights = lights
	item.buffer.blockers = {}
	return item.buffer
end

local function pass_through()
	return {
		P1 = {0, 0, 0, 0},
		P2 = {0, 0, 0, 0},
		P3 = {0, 0, 0, 0},
	}
end

local function build_shader_params()
	if not item.is_enabled() then return pass_through() end
	-- 暂停菜单 + 换房等暂停态直通，避免切换时 UV/位置错乱
	if Game():IsPauseMenuOpen() or Game():IsPaused() then return pass_through() end

	local buf = item.collect_frame_buffer()
	local light = buf.lights[1]
	if not light then return pass_through() end

	local radius_uv, cu, cv = world_radius_to_uv(light.position, light.radius)
	local ambient = tonumber(cfg("Ambient")) or item.defaults.Ambient
	local soft = tonumber(cfg("Soft")) or item.defaults.Soft
	local intensity = tonumber(light.intensity) or item.defaults.Intensity
	local col = light.color or {1, 1, 1}
	return {
		P1 = {
			1,
			math.max(0, math.min(1, ambient)),
			math.max(0, intensity),
			math.max(0.001, math.min(1, soft)),
		},
		P2 = {
			cu,
			cv,
			math.max(0.0001, radius_uv),
			0,
		},
		P3 = {
			tonumber(col[1]) or 1,
			tonumber(col[2]) or 1,
			tonumber(col[3]) or 1,
			0,
		},
	}
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		refresh_room_info()
		item.buffer.lights = {}
		item.buffer.blockers = {}
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_GET_SHADER_PARAMS,
	params = nil,
	Function = function(_, name)
		if name ~= item.shader_name then return end
		return build_shader_params()
	end,
})

return item

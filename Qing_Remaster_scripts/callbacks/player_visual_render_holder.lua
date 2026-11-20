-- Player Visual Render Layer
-- Registration-based behind/front VFX dispatch, independent of MC_PRE_PLAYER_RENDER.
-- Spawns Player Visual Proxy effects only while at least one consumer is active
-- for that player+layer. Visual offset comes from player_offset_holder.
--
-- Consumer API:
--   register({
--     id = "unique_id",
--     behind = { active = function(player) return bool end, render = function(ctx) end },
--     front  = { active = function(player) return bool end, render = function(ctx) end },
--   })
--   unregister(id)
--   GetVisualOffset / GetVisualWorld / GetVisualScreen
--
-- ctx fields: player, layer, visual_offset, visual_world, screen_pos, offset, room

local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")

local item = {
	ToCall = {},
	own_key = "player_visual_render_holder_",
	entity = enums.Entities.Player_Visual_Proxy,
	DEPTH_BEHIND = -140,
	DEPTH_FRONT = 140,
	SUB_BEHIND = 1,
	SUB_FRONT = 2,
}

-- id -> spec
local registry = {}
-- GetPtrHash(player) -> { player=wrapper, behind=ent?, front=ent? }
local proxies = {}

local function ptr(ent)
	if not ent then return nil end
	return GetPtrHash(ent)
end

local function alive(ent)
	return ent and ent.Exists and ent:Exists() and not ent:IsDead()
end

function item.GetVisualOffset(player)
	if not player then
		return Vector(0, 0)
	end
	return player_offset_holder.GetVisualPositionOffset(player) or Vector(0, 0)
end

function item.GetVisualWorld(player)
	if not player then
		return Vector(0, 0)
	end
	return player.Position + item.GetVisualOffset(player)
end

function item.GetVisualScreen(player, render_offset)
	if not player then
		return Vector(0, 0)
	end
	local room = Game():GetRoom()
	return room:WorldToScreenPosition(item.GetVisualWorld(player))
		+ (render_offset or Vector.Zero)
		- room:GetRenderScrollOffset()
end

--- Register a consumer. `behind` / `front` are optional lane tables.
--- Lane.active(player) default true when omitted; lane.render(ctx) required if lane present.
function item.register(spec)
	if type(spec) ~= "table" or type(spec.id) ~= "string" or spec.id == "" then
		error("player_visual_render_holder.register: id required")
	end
	registry[spec.id] = spec
end

function item.unregister(id)
	if type(id) == "string" then
		registry[id] = nil
	end
end

local function lane_active(lane, player)
	if not lane or type(lane.render) ~= "function" then
		return false
	end
	if lane.active == nil then
		return true
	end
	return lane.active(player) == true
end

local function any_lane_active(player, layer_name)
	for _, spec in pairs(registry) do
		if lane_active(spec[layer_name], player) then
			return true
		end
	end
	return false
end

local function sorted_ids()
	local ids = {}
	for id in pairs(registry) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return ids
end

local function build_ctx(player, layer_name, render_offset)
	local room = Game():GetRoom()
	local vo = item.GetVisualOffset(player)
	local vw = player.Position + vo
	local screen = room:WorldToScreenPosition(vw)
		+ (render_offset or Vector.Zero)
		- room:GetRenderScrollOffset()
	return {
		player = player,
		layer = layer_name,
		visual_offset = vo,
		visual_world = vw,
		screen_pos = screen,
		offset = render_offset or Vector.Zero,
		room = room,
	}
end

local function dispatch(player, layer_name, render_offset)
	if not player then
		return
	end
	local room = Game():GetRoom()
	if room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	local ctx = build_ctx(player, layer_name, render_offset)
	for _, id in ipairs(sorted_ids()) do
		local spec = registry[id]
		local lane = spec and spec[layer_name]
		if lane_active(lane, player) then
			lane.render(ctx)
		end
	end
end

local function destroy_proxy_ent(ent)
	if alive(ent) then
		ent:Remove()
	end
end

local function clear_slot(pkey)
	local slot = proxies[pkey]
	if not slot then
		return
	end
	destroy_proxy_ent(slot.behind)
	destroy_proxy_ent(slot.front)
	proxies[pkey] = nil
end

local function ensure_proxy(player, layer_name, field, subtype, depth)
	local pkey = ptr(player)
	if not pkey then
		return
	end
	local slot = proxies[pkey]
	if not slot then
		slot = { player = player }
		proxies[pkey] = slot
	else
		slot.player = player
	end

	local need = any_lane_active(player, layer_name)
	local ent = slot[field]
	if not need then
		destroy_proxy_ent(ent)
		slot[field] = nil
		if not slot.behind and not slot.front then
			proxies[pkey] = nil
		end
		return
	end

	if not alive(ent) then
		ent = Isaac.Spawn(
			EntityType.ENTITY_EFFECT,
			item.entity,
			subtype,
			player.Position,
			Vector.Zero,
			player
		)
		if not ent then
			return
		end
		ent = ent:ToEffect() or ent
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
		local s = ent:GetSprite()
		s:Play("Idle", true)
		s.Color = Color(1, 1, 1, 0, 0, 0, 0)
		local d = ent:GetData()
		d[item.own_key .. "player_hash"] = pkey
		d[item.own_key .. "layer"] = layer_name
		slot[field] = ent
	end

	ent.Position = player.Position
	ent.Velocity = player.Velocity
	-- Bake visual lift into PositionOffset so entity W2S matches player visual.
	ent.PositionOffset = item.GetVisualOffset(player)
	ent.DepthOffset = depth
	local d = ent:GetData()
	d[item.own_key .. "player_hash"] = pkey
	d[item.own_key .. "layer"] = layer_name
end

local function sync_player(player)
	if not player or not player:Exists() then
		return
	end
	if g.is_gameplay_world_active and not g.is_gameplay_world_active() then
		return
	end
	ensure_proxy(player, "behind", "behind", item.SUB_BEHIND, item.DEPTH_BEHIND)
	ensure_proxy(player, "front", "front", item.SUB_FRONT, item.DEPTH_FRONT)
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		sync_player(player)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_RENDER,
	params = item.entity,
	Function = function(_, ent, offset)
		if not ent or ent.Variant ~= item.entity then
			return
		end
		if g.is_gameplay_world_active and not g.is_gameplay_world_active() then
			return
		end
		local d = ent:GetData()
		local layer_name = d[item.own_key .. "layer"]
		local pkey = d[item.own_key .. "player_hash"]
		if layer_name ~= "behind" and layer_name ~= "front" then
			return
		end
		local slot = pkey and proxies[pkey] or nil
		local player = slot and slot.player or nil
		if not player or not player:Exists() or ptr(player) ~= pkey then
			return
		end
		dispatch(player, layer_name, offset)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		for pkey, _ in pairs(proxies) do
			clear_slot(pkey)
		end
		proxies = {}
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function()
		for pkey, _ in pairs(proxies) do
			clear_slot(pkey)
		end
		proxies = {}
	end,
})

return item

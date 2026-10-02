-- Death Field ghost proxies: dedicated Effect (Death Field Proxy), not MeusNil
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local C = require("Qing_Remaster_scripts.cards.death_field.constants")
local state = require("Qing_Remaster_scripts.cards.death_field.state")
local layout = require("Qing_Remaster_scripts.cards.death_field.layout")
local visual = require("Qing_Remaster_scripts.cards.death_field.visual")
local trinkets = require("Qing_Remaster_scripts.cards.death_field.trinket_effects")

local M = {}

local EID_KEY = C.OWN_KEY .. "eid"
M.VARIANT = enums.Entities.Death_Field_Proxy

-- room-local: [playerIndex] = { [uid] = effect }
local room_proxies = {}

local function owner_index(player)
	return state.player_index(player)
end

local function store_for(player)
	local idx = owner_index(player)
	if idx == nil then
		return nil
	end
	room_proxies[idx] = room_proxies[idx] or {}
	return room_proxies[idx]
end

function M.clear_room_cache(player)
	local idx = owner_index(player)
	if idx ~= nil then
		room_proxies[idx] = nil
	end
end

function M.clear_all_room_cache()
	room_proxies = {}
end

function M.is_proxy(ent)
	if not ent or not ent:Exists() then
		return false
	end
	if ent.Type ~= EntityType.ENTITY_EFFECT or ent.Variant ~= M.VARIANT then
		return false
	end
	return ent:GetData()[C.DATA_TAG] == true
end

local function load_entry_sprite(sprite, entry)
	if entry.kind == "active" then
		auxi.load_item(entry.collectible_id, {sprite = sprite})
		return
	end
	if entry.kind == "trinket" then
		local tid = entry.trinket_id or 0
		if entry.golden then
			tid = tid | TrinketType.TRINKET_GOLDEN_FLAG
		end
		auxi.load_trinket(tid, {sprite = sprite})
		return
	end
	if entry.kind == "card" then
		-- 用地上卡牌 pickup 贴图，勿用 HUD ui_cardfronts（16×20 在世界里又小又扁）
		local room = Game():GetRoom()
		local dummy = Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_TAROTCARD,
			entry.card_id or 0,
			room:GetCenterPos() + Vector(20000, 20000),
			Vector.Zero,
			nil
		):ToPickup()
		if dummy then
			dummy.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			dummy.Visible = false
			local ds = dummy:GetSprite()
			sprite:Load(ds:GetFilename(), true)
			sprite:Play(ds:GetAnimation(), true)
			sprite:SetFrame(ds:GetFrame())
			sprite:LoadGraphics()
			dummy:Remove()
		end
		return
	end
	if entry.kind == "pill" then
		-- TECH DEBT：dummy PICKUP_PILL 仅在 rebuild 时 Spawn 一次以抄贴图
		local room = Game():GetRoom()
		local dummy = Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_PILL,
			entry.pill_color or 0,
			room:GetCenterPos() + Vector(20000, 20000),
			Vector.Zero,
			nil
		):ToPickup()
		if dummy then
			dummy.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			dummy.Visible = false
			local ds = dummy:GetSprite()
			sprite:Load(ds:GetFilename(), true)
			sprite:Play(ds:GetAnimation(), true)
			sprite:SetFrame(ds:GetFrame())
			sprite:LoadGraphics()
			dummy:Remove()
		end
		return
	end
end

local function entry_eid_ids(entry)
	if not entry then
		return nil
	end
	if entry.kind == "active" then
		return 5, 100, entry.collectible_id
	end
	if entry.kind == "trinket" then
		return 5, 350, trinkets.compose_trinket_id(entry.trinket_id, entry.golden)
	end
	if entry.kind == "card" then
		return 5, 300, entry.card_id
	end
	if entry.kind == "pill" then
		return 5, 70, entry.pill_color
	end
	return nil
end

local function remove_eid_anchor(d)
	if not d then
		return
	end
	local eid = d[EID_KEY]
	if auxi.check_all_exists(eid) then
		eid:Remove()
	end
	d[EID_KEY] = nil
end

--- 虚影不在 EID.effectList；旁挂已登记的 EID_Descriptier（同 Fool）
local function spawn_eid_anchor(pos, entry)
	if not EID then
		return nil
	end
	local tp, vr, st = entry_eid_ids(entry)
	if not tp or not st then
		return nil
	end
	local q = Isaac.Spawn(1000, enums.Entities.EID_Descriptier, 0, pos, Vector.Zero, nil)
	if not q then
		return nil
	end
	q.Visible = false
	q.Size = 22
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	local d = q:GetData()
	d[C.OWN_KEY .. "eid_anchor"] = true
	local desc = EID:getDescriptionObj(tp, vr, st, nil, true)
	if desc then
		d.EID_Description = desc
	end
	return q
end

local function sync_eid_anchor(ent, d, entry)
	local eid = d[EID_KEY]
	if auxi.check_all_exists(eid) then
		eid.Position = ent.Position
		eid.Velocity = Vector.Zero
		eid.PositionOffset = ent.PositionOffset or Vector.Zero
	elseif EID and entry then
		d[EID_KEY] = spawn_eid_anchor(ent.Position, entry)
	end
end

local function resolve_owner(d, idx)
	local player = d.Params and d.Params.player
	if auxi.check_all_exists(player) and player:GetData().__Index == idx then
		return player
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:GetData().__Index == idx then
			d.Params = d.Params or {}
			d.Params.player = p
			return p
		end
	end
	return nil
end

function M.spawn_proxy(player, entry, pos)
	pos = pos or entry._spawn_pos or player.Position
	if not M.VARIANT or M.VARIANT < 0 then
		return nil
	end
	local q = Isaac.Spawn(EntityType.ENTITY_EFFECT, M.VARIANT, 0, pos, Vector.Zero, player)
	if not q then
		return nil
	end
	q = q:ToEffect() or q
	local s = q:GetSprite()
	load_entry_sprite(s, entry)
	local d = q:GetData()
	d[C.DATA_TAG] = true
	d[C.DATA_UID] = entry.uid
	d[C.DATA_OWNER] = owner_index(player)
	d.death_field_entry = entry
	d.Params = {player = player}
	d.EID_Hide = true
	d[EID_KEY] = spawn_eid_anchor(pos, entry)
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	q.DepthOffset = C.PROXY_DEPTH_OFFSET
	if q.Timeout ~= nil then
		q.Timeout = 999999
	end
	local activatable = true
	local ex = package.loaded["Qing_Remaster_scripts.cards.death_field.executor"]
	if ex and ex.can_activate then
		activatable = ex.can_activate(entry)
	end
	visual.update_proxy(q, entry, false, activatable)

	local store = store_for(player)
	if store then
		store[entry.uid] = q
	end
	return q
end

function M.remove_proxy(player, uid)
	local store = store_for(player)
	local ent = store and store[uid]
	if store then
		store[uid] = nil
	end
	if auxi.check_all_exists(ent) then
		remove_eid_anchor(ent:GetData())
		ent:Remove()
	end
end

function M.remove_all_proxies(player)
	local store = store_for(player)
	if not store then
		return
	end
	for uid, ent in pairs(store) do
		if auxi.check_all_exists(ent) then
			remove_eid_anchor(ent:GetData())
			ent:Remove()
		end
		store[uid] = nil
	end
	M.clear_room_cache(player)
end

function M.rebuild_room(player, rng, opts)
	opts = opts or {}
	M.remove_all_proxies(player)
	if not state.is_active(player) then
		return
	end
	local f = state.get_field(player)
	if not f then
		return
	end
	-- 只映射稳定 norm → 本房安全点；不改写 norm、不用 RNG
	layout.place_entries(f.entries)
	for _, e in ipairs(f.entries) do
		M.spawn_proxy(player, e, e._spawn_pos)
		e._spawn_pos = nil
	end
end

function M.get_proxy(player, uid)
	local store = store_for(player)
	local ent = store and store[uid]
	if auxi.check_all_exists(ent) then
		return ent
	end
	if store then
		store[uid] = nil
	end
	return nil
end

function M.for_each_proxy(player, fn)
	local store = store_for(player)
	if not store then
		return
	end
	for uid, ent in pairs(store) do
		if auxi.check_all_exists(ent) then
			fn(uid, ent)
		else
			store[uid] = nil
		end
	end
end

function M.find_nearest(player, radius)
	radius = radius or C.INTERACT_RADIUS
	local best, best_d, best_uid = nil, radius + 1, nil
	M.for_each_proxy(player, function(uid, ent)
		local dist = (ent.Position - player.Position):Length()
		if dist < best_d then
			best_d = dist
			best = ent
			best_uid = uid
		end
	end)
	return best, best_uid, best_d
end

function M.on_update(ent)
	if not M.is_proxy(ent) then
		return
	end
	local d = ent:GetData()
	local s = ent:GetSprite()
	local idx = d[C.DATA_OWNER]
	local uid = d[C.DATA_UID]
	if idx == nil or uid == nil then
		remove_eid_anchor(d)
		ent:Remove()
		return
	end
	local player = resolve_owner(d, idx)
	if not auxi.check_all_exists(player) or not state.is_active(player) then
		remove_eid_anchor(d)
		ent:Remove()
		return
	end
	local entry = d.death_field_entry
	if not entry or entry.uid ~= uid then
		entry = state.find_entry(player, uid)
		d.death_field_entry = entry
	end
	if not entry then
		remove_eid_anchor(d)
		ent:Remove()
		return
	end
	ent.Velocity = Vector.Zero
	if ent.Timeout ~= nil and ent.Timeout < 1000 then
		ent.Timeout = 999999
	end
	local focus = player:GetData()[C.FOCUS_KEY]
	local executor = package.loaded["Qing_Remaster_scripts.cards.death_field.executor"]
		or require("Qing_Remaster_scripts.cards.death_field.executor")
	local activatable = executor.can_activate(entry)
	visual.update_proxy(ent, entry, focus == uid, activatable)
	sync_eid_anchor(ent, d, entry)
	if s and s.Update then
		s:Update()
	end
end

function M.on_render(ent, offset)
	if not M.is_proxy(ent) then
		return
	end
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	local d = ent:GetData()
	local s = ent:GetSprite()
	local player = d.Params and d.Params.player
	visual.render_proxy(ent, d, s, player, offset)
end

function M.on_remove(ent)
	if not ent then
		return
	end
	local d = ent:GetData()
	if d[C.DATA_TAG] then
		remove_eid_anchor(d)
	end
end

--- 把专用 Effect 回调挂到卡牌 item.ToCall
function M.append_callbacks(item)
	local var = M.VARIANT
	if not var or var < 0 then
		return
	end
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
		params = var,
		Function = function(_, ent)
			if ent.Variant ~= var then
				return
			end
			M.on_update(ent)
		end,
	})
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_EFFECT_RENDER,
		params = var,
		Function = function(_, ent, offset)
			if ent.Variant ~= var then
				return
			end
			M.on_render(ent, offset)
		end,
	})
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
		params = EntityType.ENTITY_EFFECT,
		Function = function(_, ent)
			if ent.Variant ~= var then
				return
			end
			M.on_remove(ent)
		end,
	})
end

return M

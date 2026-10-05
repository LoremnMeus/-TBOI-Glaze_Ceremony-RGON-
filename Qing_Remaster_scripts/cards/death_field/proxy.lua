-- Death Field ghost proxies: dedicated Effect (Death Field Proxy), not MeusNil
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local pocket_visual = require("Qing_Remaster_scripts.others.pocket_visual")
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

local function note_proxy_probe(row)
	local probe = package.loaded["Qing_Remaster_scripts.debug.portal_restore_rewind_probe"]
	if type(probe) ~= "table" or type(probe.record_external) ~= "function" then
		return
	end
	pcall(probe.record_external, row)
end

function M.count_world_proxies()
	local n = 0
	if not M.VARIANT or M.VARIANT < 0 then
		return 0
	end
	local list = Isaac.FindByType(EntityType.ENTITY_EFFECT, M.VARIANT, -1, false, false)
	for i = 1, #list do
		local ent = list[i]
		if ent and ent.Exists and ent:Exists() then
			n = n + 1
		end
	end
	return n
end

local function count_cached_proxies(player)
	local n = 0
	M.for_each_proxy(player, function()
		n = n + 1
	end)
	return n
end

local function emit_spawn_probe(player, entry, q)
	local exists = false
	local pos = "nil"
	local ptr = "nil"
	if q and q.Exists and q:Exists() then
		exists = true
		ptr = tostring(GetPtrHash(q))
		pcall(function()
			pos = string.format("%.2f,%.2f", q.Position.X, q.Position.Y)
		end)
	end
	note_proxy_probe({
		source = "death_field",
		event = "DEATH_FIELD_PROXY_SPAWN",
		uid = tostring(entry and entry.uid),
		ptr = ptr,
		exists = exists,
		position = pos,
		owner_idx = tostring(owner_index(player)),
		proxy_count = M.count_world_proxies(),
	})
end

local function apply_static_idle(sprite, anim)
	anim = (type(anim) == "string" and anim ~= "") and anim or "Idle"
	pcall(function()
		sprite:Play(anim, true)
		sprite:SetFrame(0)
		if sprite.LoadGraphics then
			sprite:LoadGraphics()
		end
	end)
end

local function load_card_proxy_sprite(sprite, card_id)
	local visual = pocket_visual.resolve_card_visual(card_id)
	if not visual then
		return
	end
	if visual.exact and visual.sprite then
		pcall(function()
			visual.sprite:Play(visual.animation or "Idle", true)
			visual.sprite:SetFrame(0)
		end)
		local fn
		pcall(function() fn = visual.sprite:GetFilename() end)
		if type(fn) == "string" and fn ~= "" then
			sprite:Load(fn, true)
		end
	elseif type(visual.anm2) == "string" and visual.anm2 ~= "" then
		sprite:Load(visual.anm2, true)
	end
	apply_static_idle(sprite, visual.animation)
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
		load_card_proxy_sprite(sprite, entry.card_id)
		return
	end
	if entry.kind == "pill" then
		local visual = pocket_visual.resolve_pill_visual(entry.pill_color)
		if visual and type(visual.anm2) == "string" and visual.anm2 ~= "" then
			sprite:Load(visual.anm2, true)
			apply_static_idle(sprite, visual.animation)
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
		emit_spawn_probe(player, entry, nil)
		return nil
	end
	local q = Isaac.Spawn(EntityType.ENTITY_EFFECT, M.VARIANT, 0, pos, Vector.Zero, player)
	if not q then
		emit_spawn_probe(player, entry, nil)
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
	emit_spawn_probe(player, entry, q)
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
	note_proxy_probe({
		source = "death_field",
		event = "DEATH_FIELD_PROXY_REBUILD_BEGIN",
		idx = tostring(owner_index(player)),
		entries = state.entry_count(player),
		existing_proxy_count = M.count_world_proxies(),
		cached_proxy_count = count_cached_proxies(player),
	})
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

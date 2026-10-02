-- Pedestal Encounter Holder
-- Normal Pedestal Encounter（generation 机会）与 Death Certificate Display Encounter（room appearance）
-- 是两条独立事件流；禁止用 OptionsPickupIndex 单独猜 DC，禁止建立通用选择组 identity。

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")

local DATA_SUPPRESS = "_QingPedestalEncounterSuppressed"
local DATA_CLASS = "_QingPedestalEncounterClass"
local DATA_PUBLISHED = "_QingPedestalEncounterPublished"
local DATA_RESIDUE = "_QingPedestalEncounterResidue"
local DATA_DISPLAY_MEMBER = "_QingPedestalEncounterDisplayMember"

local DC_DIMENSION = 2 -- Dimension.DEATH_CERTIFICATE

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Pedestal_Encounter_holder_",
	_normal_serial = 0,
	_dc_display_serial = 0,
	_suppress_depth = 0,
	_suppress_owner = nil,
	_published_normal_gens = {},
	_dc_display_published_epoch = nil,
	_dc_display_members = {},
	_recent_acquisitions = {},
	debug = {
		normal_offer_count = 0,
		player_residue_count = 0,
		residue_exact_count = 0,
		residue_heuristic_count = 0, -- 恒为 0：宽泛启发式已删除
		suppressed_count = 0,
		dc_display_count = 0,
		dc_display_members_seen = 0,
		last_normal = nil,
		last_dc_display = nil,
		last_class = nil,
	},
}

local function game_frame()
	local f = 0
	pcall(function()
		f = Game():GetFrameCount()
	end)
	return f
end

local function room_list_index()
	local idx = nil
	pcall(function()
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		idx = desc and desc.ListIndex
	end)
	return idx
end

local function bump_debug(key, n)
	item.debug[key] = (item.debug[key] or 0) + (n or 1)
end

--- Death Certificate dimension（RGON Level:GetDimension 优先，fallback auxi.GetDimension）。
function item.is_in_death_certificate_dimension()
	local dim = nil
	if REPENTOGON then
		local level = Game():GetLevel()
		if level and level.GetDimension then
			local ok, d = pcall(function()
				return level:GetDimension()
			end)
			if ok and d ~= nil then
				dim = tonumber(d)
			end
		end
		if dim == nil then
			local desc = Game():GetLevel():GetCurrentRoomDesc()
			if desc and desc.GetDimension then
				local ok2, d2 = pcall(function()
					return desc:GetDimension()
				end)
				if ok2 and d2 ~= nil then
					dim = tonumber(d2)
				end
			end
		end
	end
	if dim == nil then
		dim = tonumber(auxi.GetDimension())
	end
	if Dimension and Dimension.DEATH_CERTIFICATE ~= nil then
		return dim == Dimension.DEATH_CERTIFICATE
	end
	return dim == DC_DIMENSION
end

--- 原版死亡证明陈列 pedestal：Dimension==DC AND OptionsPickupIndex==1。
function item.is_death_certificate_display(pickup)
	if not pickup then
		return false
	end
	local p = pickup.ToPickup and pickup:ToPickup() or pickup
	if not p or p.Type ~= EntityType.ENTITY_PICKUP then
		return false
	end
	if p.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		return false
	end
	if not item.is_in_death_certificate_dimension() then
		return false
	end
	return (tonumber(p.OptionsPickupIndex) or 0) == 1
end

function item.mark_suppressed(pickup, owner)
	if not pickup then
		return
	end
	local p = pickup.ToPickup and pickup:ToPickup() or pickup
	if not p then
		return
	end
	local d = p:GetData()
	d[DATA_SUPPRESS] = true
	d[DATA_CLASS] = "SUPPRESSED"
	d._QingPedestalEncounterSuppressOwner = owner
	bump_debug("suppressed_count")
end

function item.is_suppressed(pickup)
	if not pickup then
		return false
	end
	local d = pickup:GetData()
	return d and d[DATA_SUPPRESS] == true
end

--- 本模组自产辅助 pedestal：fn 期间 INIT 的 collectible 自动 mark_suppressed。
function item.with_suppressed_encounter(owner, fn)
	item._suppress_depth = (item._suppress_depth or 0) + 1
	item._suppress_owner = owner or item._suppress_owner or "anonymous"
	local ok, a, b, c, d, e = pcall(fn)
	item._suppress_depth = item._suppress_depth - 1
	if item._suppress_depth <= 0 then
		item._suppress_depth = 0
		item._suppress_owner = nil
	end
	if not ok then
		error(a)
	end
	return a, b, c, d, e
end

function item.get_debug_snapshot()
	return {
		normal_serial = item._normal_serial or 0,
		normal_offer_count = item.debug.normal_offer_count or 0,
		player_residue_count = item.debug.player_residue_count or 0,
		residue_exact_count = item.debug.residue_exact_count or 0,
		residue_heuristic_count = item.debug.residue_heuristic_count or 0,
		suppressed_count = item.debug.suppressed_count or 0,
		dc_display_serial = item._dc_display_serial or 0,
		dc_display_count = item.debug.dc_display_count or 0,
		dc_display_members_seen = item.debug.dc_display_members_seen or 0,
		last_normal = item.debug.last_normal,
		last_dc_display = item.debug.last_dc_display,
		last_class = item.debug.last_class,
		room_epoch = unique_holder.get_room_generation_epoch and unique_holder.get_room_generation_epoch() or 0,
		in_dc_dimension = item.is_in_death_certificate_dimension(),
	}
end

function item.reset_debug()
	item.debug.normal_offer_count = 0
	item.debug.player_residue_count = 0
	item.debug.residue_exact_count = 0
	item.debug.residue_heuristic_count = 0
	item.debug.suppressed_count = 0
	item.debug.dc_display_count = 0
	item.debug.dc_display_members_seen = 0
	item.debug.last_normal = nil
	item.debug.last_dc_display = nil
	item.debug.last_class = nil
end

local function note_acquisition(player, collected_id, ent)
	-- debug/probe only：不参与 authoritative residue
	local list = item._recent_acquisitions
	list[#list + 1] = {
		frame = game_frame(),
		player_ptr = player and GetPtrHash(player) or nil,
		collected_id = collected_id,
		ent_ptr = ent and GetPtrHash(ent) or nil,
	}
	while #list > 16 do
		table.remove(list, 1)
	end
	-- Exact acquisition correlation：callback 直接给出 surviving replacement pedestal
	if ent and ent:Exists() and ent.Type == EntityType.ENTITY_PICKUP
		and ent.Variant == PickupVariant.PICKUP_COLLECTIBLE
		and (ent.SubType or 0) > 0
		and (ent.FrameCount or 0) <= 1
	then
		local d = ent:GetData()
		d[DATA_RESIDUE] = true
		d[DATA_CLASS] = "PLAYER_RESIDUE"
		bump_debug("residue_exact_count")
	end
end

--- 仅认可 exact DATA_RESIDUE；禁止 Touched + 时间/距离启发式。
local function is_player_residue(pickup)
	local d = pickup:GetData()
	return d and d[DATA_RESIDUE] == true
end

local function dispatch_normal(event)
	callback_manager.work(enums.Callbacks.POST_PEDESTAL_ENCOUNTER, function(funct, params)
		if params == nil or params == event.generation_id or params == event.subtype then
			funct(nil, event)
		end
	end)
end

local function dispatch_dc_display(event)
	callback_manager.work(enums.Callbacks.POST_DEATH_CERTIFICATE_DISPLAY_ENCOUNTER, function(funct, params)
		if params == nil then
			funct(nil, event)
		end
	end)
end

local function publish_dc_display(pickup, gen)
	local room_epoch = unique_holder.get_room_generation_epoch and unique_holder.get_room_generation_epoch() or 0
	if item._dc_display_published_epoch == room_epoch then
		return false
	end
	item._dc_display_published_epoch = room_epoch
	item._dc_display_serial = (item._dc_display_serial or 0) + 1
	bump_debug("dc_display_count")
	local event = {
		display_serial = item._dc_display_serial,
		room_epoch = room_epoch,
		room_index = room_list_index(),
		representative_generation_id = gen and gen.id,
		representative_subtype = pickup.SubType or 0,
		frame = game_frame(),
		pickup = pickup,
	}
	item.debug.last_dc_display = {
		room_epoch = event.room_epoch,
		representative_generation_id = event.representative_generation_id,
		display_serial = event.display_serial,
	}
	item.debug.last_class = "DC_DISPLAY"
	dispatch_dc_display(event)
	return true
end

local function publish_normal(pickup, gen)
	local gid = gen and tonumber(gen.id)
	if gid == nil then
		return false
	end
	if item._published_normal_gens[gid] then
		return false
	end
	item._published_normal_gens[gid] = true
	item._normal_serial = (item._normal_serial or 0) + 1
	bump_debug("normal_offer_count")
	local is_shop = false
	pcall(function()
		is_shop = pickup.IsShopItem and pickup:IsShopItem()
	end)
	local event = {
		serial = item._normal_serial,
		generation_id = gid,
		subtype = pickup.SubType or 0,
		frame = game_frame(),
		room_epoch = unique_holder.get_room_generation_epoch and unique_holder.get_room_generation_epoch() or 0,
		is_shop = is_shop == true,
		price = pickup.Price or 0,
		options_index = pickup.OptionsPickupIndex or 0,
		pickup = pickup,
	}
	local d = pickup:GetData()
	d[DATA_PUBLISHED] = true
	d[DATA_CLASS] = "NORMAL_OFFER"
	item.debug.last_normal = {
		generation_id = event.generation_id,
		subtype = event.subtype,
		options_index = event.options_index,
		serial = event.serial,
	}
	item.debug.last_class = "NORMAL_OFFER"
	dispatch_normal(event)
	return true
end

local function classify_and_maybe_publish(pickup)
	if not pickup or not pickup:Exists() then
		return
	end
	if pickup.Type ~= EntityType.ENTITY_PICKUP then
		return
	end
	if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		return
	end
	if (pickup.SubType or 0) <= 0 then
		return
	end

	local d = pickup:GetData()
	if d[DATA_PUBLISHED] == true then
		return
	end

	-- 1–2. resolve + explicit suppression
	if item._suppress_depth and item._suppress_depth > 0 then
		item.mark_suppressed(pickup, item._suppress_owner)
		return
	end
	if d[DATA_SUPPRESS] == true then
		d[DATA_CLASS] = "SUPPRESSED"
		item.debug.last_class = "SUPPRESSED"
		return
	end

	local gen = unique_holder.resolve_generation(pickup)
	local gid = gen and tonumber(gen.id)

	-- 3. Death Certificate display（优先于 fresh）
	if item.is_death_certificate_display(pickup) then
		d[DATA_DISPLAY_MEMBER] = true
		d[DATA_CLASS] = "DISPLAY_MEMBER"
		if gid and not item._dc_display_members[gid] then
			item._dc_display_members[gid] = true
			bump_debug("dc_display_members_seen")
		end
		publish_dc_display(pickup, gen)
		item.debug.last_class = "DISPLAY_MEMBER"
		return
	end

	-- 已作为 display member 记录：禁止再走 normal
	if d[DATA_DISPLAY_MEMBER] == true then
		return
	end

	-- 4. restored / same old generation：非 fresh → 无 normal
	if not unique_holder.is_fresh_generation(pickup) then
		item.debug.last_class = "NOT_FRESH"
		return
	end

	if gid and item._published_normal_gens[gid] then
		return
	end

	-- 5. player replacement residue
	if is_player_residue(pickup) then
		d[DATA_RESIDUE] = true
		d[DATA_CLASS] = "PLAYER_RESIDUE"
		bump_debug("player_residue_count")
		item.debug.last_class = "PLAYER_RESIDUE"
		-- 仍记为「已处理该 generation」，避免 residue 后 Touched 消失又误发
		if gid then
			item._published_normal_gens[gid] = true
		end
		d[DATA_PUBLISHED] = true
		return
	end

	-- 6. NORMAL OFFER（无固定 FrameCount settle；consumer 延迟不得倒逼 producer）
	publish_normal(pickup, gen)
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		item._published_normal_gens = {}
		item._dc_display_members = {}
		item._dc_display_published_epoch = nil
		item._recent_acquisitions = {}
		item._suppress_depth = 0
		item._suppress_owner = nil
		if not continue then
			item._normal_serial = 0
			item._dc_display_serial = 0
			item.reset_debug()
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	params = nil,
	Function = function(_)
		-- Display 按 room appearance；members 表可清，published normal gens 跨房保留（restored 不再发）
		item._dc_display_members = {}
		item._dc_display_published_epoch = nil
		item._recent_acquisitions = {}
	end,
})

-- Hourglass / project rewind：撤销未来时间线的 derived encounter history。
-- 普通回房故意不清 _published_normal_gens；只有真正 rewind 才清空。
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_REWIND,
	params = nil,
	Function = function(_)
		item._published_normal_gens = {}
		item._dc_display_members = {}
		item._dc_display_published_epoch = nil
		item._recent_acquisitions = {}
		-- _normal_serial / _dc_display_serial 保持单调，不是业务 identity
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_PICKUP_COLLECTIBLE,
	params = nil,
	Function = function(_, player, id, _touched, ent)
		note_acquisition(player, id, ent)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_INIT,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup)
		if not pickup then
			return
		end
		if item._suppress_depth and item._suppress_depth > 0 then
			item.mark_suppressed(pickup, item._suppress_owner)
			return
		end
		-- DC display：尽早拦，避免后续 normal 路径
		if item.is_death_certificate_display(pickup) then
			local d = pickup:GetData()
			d[DATA_DISPLAY_MEMBER] = true
			d[DATA_CLASS] = "DISPLAY_MEMBER"
			local gen = unique_holder.resolve_generation(pickup)
			local gid = gen and tonumber(gen.id)
			if gid and not item._dc_display_members[gid] then
				item._dc_display_members[gid] = true
				bump_debug("dc_display_members_seen")
			end
			publish_dc_display(pickup, gen)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup)
		classify_and_maybe_publish(pickup)
	end,
})

return item

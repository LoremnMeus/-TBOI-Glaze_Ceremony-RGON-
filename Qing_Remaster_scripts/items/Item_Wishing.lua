local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local picker = require("Qing_Remaster_scripts.items.wishing_picker")
local morph_txn = require("Qing_Remaster_scripts.others.Pickup_Morph_Transaction_holder")
local unique = require("Qing_Remaster_scripts.others.Unique_holder")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Wishing,
	own_key = "Item_Wishing_",
}

local VAR_MAGIC = 1000000
local sprite_cache = {}
local devil_ids

local function decode_wish(value)
	local raw = (tonumber(value) or 0) - VAR_MAGIC
	if raw <= 0 then return nil end
	return raw % 10000
end

local function pedestal_bindings()
	save.elses = save.elses or {}
	local bindings = save.elses[item.own_key .. "pedestal_wishes"]
	if type(bindings) ~= "table" then
		bindings = {}
		save.elses[item.own_key .. "pedestal_wishes"] = bindings
	end
	return bindings
end

local function progress(player)
	local index = player and player:GetData().__Index
	if not index then return nil end
	save.elses = save.elses or {}
	local root = save.elses[item.own_key .. "progress"]
	if type(root) ~= "table" then
		root = {}
		save.elses[item.own_key .. "progress"] = root
	end
	if type(root[index]) ~= "table" then root[index] = {reject_count = 0} end
	return root[index]
end

local function valid_collectible(id)
	if type(id) ~= "number" or id <= 0 or id == item.entity then return false end
	local config = Isaac.GetItemConfig():GetCollectible(id)
	if not config or config.Hidden == true then return false end
	return (config.Tags & ItemConfig.TAG_QUEST) == 0
end

local function initial_devil_ids()
	if devil_ids then return devil_ids end
	-- Initial pool membership is read without drawing from or advancing the Devil Room pool.
	local ids = {}
	local pool = Game():GetItemPool()
	for _, entry in pairs(pool:GetCollectiblesFromPool(ItemPoolType.POOL_DEVIL) or {}) do
		if type(entry) == "table" and (tonumber(entry.initialWeight) or 0) > 0
			and valid_collectible(entry.itemID) then
			ids[entry.itemID] = true
		end
	end
	devil_ids = ids
	return ids
end

local function candidates(player)
	local pool = {}
	local config = Isaac.GetItemConfig()
	for id = 1, config:GetCollectibles().Size - 1 do
		if valid_collectible(id) then pool[#pool + 1] = id end
	end
	local state = progress(player)
	local count = math.min(#pool, 3 + (state and state.reject_count or 0))
	local rng = player:GetCollectibleRNG(item.entity)
	local result = {}
	if count > 0 and auxi.should_do_belial(player) then
		local devil = {}
		local ids = initial_devil_ids()
		for _, id in ipairs(pool) do
			if ids[id] then devil[#devil + 1] = id end
		end
		if #devil > 0 then
			local chosen = devil[rng:RandomInt(#devil) + 1]
			for i, id in ipairs(pool) do
				if id == chosen then pool[i], pool[1] = pool[1], pool[i] break end
			end
			result[1] = chosen
		end
	end
	for i = #result + 1, count do
		local j = i + rng:RandomInt(#pool - i + 1)
		pool[i], pool[j] = pool[j], pool[i]
		result[i] = pool[i]
	end
	for i = #result, 2, -1 do
		local j = rng:RandomInt(i) + 1
		result[i], result[j] = result[j], result[i]
	end
	return result
end

local function item_sprite(id)
	if sprite_cache[id] then return sprite_cache[id] end
	local config = Isaac.GetItemConfig():GetCollectible(id)
	if not config then return nil end
	local sprite = Sprite()
	sprite:Load("gfx/ui/collectible_icon_centered.anm2", true)
	sprite:ReplaceSpritesheet(0, config.GfxFileName)
	sprite:LoadGraphics()
	sprite:Play("Idle", true)
	sprite_cache[id] = sprite
	return sprite
end

local function slot_wish(player, slot)
	if not player or player:GetActiveItem(slot) ~= item.entity then return nil end
	local desc = player:GetActiveItemDesc(slot)
	local data = desc and tonumber(desc.VarData) or 0
	local wished = decode_wish(data)
	if valid_collectible(wished) then return wished end
	return nil
end

local function pedestal_wish(pickup)
	if not pickup or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE
		or pickup.SubType ~= item.entity then return nil end
	local generation = unique.resolve_generation(pickup)
	local generation_id = generation and generation.id
	local bound = generation_id and pedestal_bindings()[generation_id]
	if valid_collectible(bound) then return bound end
	local encoded_wish = decode_wish(pickup:GetVarData())
	if valid_collectible(encoded_wish) then
		if generation_id then pedestal_bindings()[generation_id] = encoded_wish end
		return encoded_wish
	end
end

local function render_wish_icon(wished, position, scale, alpha)
	local sprite = sprite_cache[wished]
	if not sprite then return end
	picker.render_icon_centered(sprite, position, scale, Color(1, 1, 1, alpha))
end

local function settle(session, selected, use_flags)
	local player, slot = session.player, session.slot
	if player:GetActiveItem(slot) ~= item.entity then return end
	local state = progress(player)
	if selected then
		local wished = session.options[selected]
		if not wished or not valid_collectible(wished) then return end
		player:SetActiveVarData(VAR_MAGIC + wished, slot)
		if state then state.reject_count = 0 end
	elseif state then
		state.reject_count = (state.reject_count or 0) + 1
	end
	player:DischargeActiveItem(slot)
	if auxi.should_spawn_wisp(player, use_flags) then
		player:AddWisp(item.entity, player.Position, false, false)
	end
end

local function fulfill_wisps(wished)
	local wisps = Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.WISP, item.entity)
	for _, ent in ipairs(wisps) do
		local wisp = ent:ToFamiliar()
		if wisp and wisp:Exists() and wisp.Player then
			local player = wisp.Player
			local position = wisp.Position
			wisp:Remove()
			player:AddItemWisp(wished, position, false)
		end
	end
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
	Function = function(_, _, _, player, use_flags, active_slot)
		if use_flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY or picker.active(player) then
			return {Discharge = false, ShowAnim = false}
		end
		local slot = active_slot or ActiveSlot.SLOT_PRIMARY
		if player:GetActiveItem(slot) ~= item.entity then return {Discharge = false, ShowAnim = false} end
		picker.open(player, item.entity, slot, candidates(player), function(session, selected)
			settle(session, selected, use_flags)
		end)
		return {Discharge = false, ShowAnim = false}
	end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
	Function = function(_, player)
		picker.update(player)
		for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
			local wished = slot_wish(player, slot)
			if wished then item_sprite(wished) end
		end
	end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup)
		local wished = pedestal_wish(pickup)
		pickup:GetData()[item.own_key .. "visual_wish"] = wished
		if wished then item_sprite(wished) end
	end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
	Function = function(_, ent, hook, button)
		local player = ent and ent:ToPlayer()
		if player then return picker.suppress(player, hook, button) end
	end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
	Function = function(_, player, offset)
		if Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT then
			picker.render(player, offset)
		end
	end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
	Function = function() picker.clear() end,
})
table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
	Function = function()
		picker.clear()
		devil_ids = nil
		initial_devil_ids()
	end,
})

if REPENTOGON and ModCallbacks.MC_POST_PLAYERHUD_RENDER_ACTIVE_ITEM then
	table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PLAYERHUD_RENDER_ACTIVE_ITEM, params = nil,
	Function = function(_, player, slot, offset, alpha, scale)
		if player:GetActiveItem(slot) ~= item.entity then return end
		local wished = slot_wish(player, slot)
		if not wished then return end
		local hud = Game():GetHUD()
		if hud and not hud:IsVisible() then return end
		local center = offset + Vector(16 * scale, 16 * scale) + ui.GetHUDRenderOffset()
		render_wish_icon(wished, center + Vector(9 * scale, -8 * scale), 0.5 * scale, 0.38 * alpha)
	end,
	})
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup, offset)
		local wished = pickup:GetData()[item.own_key .. "visual_wish"]
		if not wished then return end
		local pos = Isaac.WorldToRenderPosition(pickup.Position + (pickup.PositionOffset or Vector.Zero))
			+ (offset or Vector.Zero) + (pickup.SpriteOffset or Vector.Zero) + Vector(0, -35)
		local pedestal_sprite = pickup:GetSprite()
		if pedestal_sprite:GetAnimation() == "Idle" and pedestal_sprite.GetLayerFrameData then
			local head_frame = pedestal_sprite:GetLayerFrameData(1)
			if head_frame then pos = pos + Vector(0, head_frame:GetPos().Y + 8) end
		end
		local alpha = 0.28 + 0.06 * math.sin(Game():GetFrameCount() * 0.08)
		render_wish_icon(wished, pos, 1, alpha)
	end,
})

morph_txn.register("Wishing", {
	priority = -100,
	match_pre = function(pickup)
		return pickup and pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE and pickup.SubType == item.entity
	end,
	capture = function(pickup)
		local wished = pedestal_wish(pickup)
		if not wished then return nil end
		local generation = unique.resolve_generation(pickup)
		return {wish_id = wished, generation_id = generation and generation.id}
	end,
	rewrite_target = function(_, target, snapshot)
		if target[1] == EntityType.ENTITY_PICKUP and target[2] == PickupVariant.PICKUP_COLLECTIBLE
			and target[3] == item.entity then return nil end
		snapshot.did_rewrite = true
		return {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE,
			snapshot.wish_id, target[4], target[5], target[6]}
	end,
	on_post = function(txn)
		if txn.source_snapshot.did_rewrite and not txn.target_mismatch and txn.after.subtype == txn.source_snapshot.wish_id then
			if txn.source_snapshot.generation_id then
				pedestal_bindings()[txn.source_snapshot.generation_id] = nil
			end
			txn.target:SetVarData(0)
			fulfill_wisps(txn.source_snapshot.wish_id)
		end
	end,
})

function item.debug_status(player)
	local state = player and progress(player)
	local lines = {"reject=" .. tostring(state and state.reject_count or 0)}
	if player then
		for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
			if player:GetActiveItem(slot) == item.entity then
				lines[#lines + 1] = "slot " .. slot .. " wish=" .. tostring(slot_wish(player, slot))
			end
		end
	end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)) do
		local pickup = ent:ToPickup()
		if pickup and pickup.SubType == item.entity then
			lines[#lines + 1] = "pedestal gen=" .. tostring((unique.resolve_generation(pickup) or {}).id)
				.. " var=" .. tostring(pickup:GetVarData()) .. " wish=" .. tostring(pedestal_wish(pickup))
		end
	end
	return table.concat(lines, "\n")
end

function item.debug_open(player)
	if not player then return false end
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		if player:GetActiveItem(slot) == item.entity then
			return picker.open(player, item.entity, slot, candidates(player), settle)
		end
	end
	return false
end

function item.debug_set_wish(player, wished)
	if not player or not valid_collectible(wished) then return false end
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		if player:GetActiveItem(slot) == item.entity then
			player:SetActiveVarData(VAR_MAGIC + wished, slot)
			return true
		end
	end
	return false
end

function item.debug_spawn_pedestal(player)
	if not player then return nil end
	local wished
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		wished = slot_wish(player, slot)
		if wished then break end
	end
	if not wished then return nil end
	local pos = Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 20, true)
	local pedestal = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE,
		item.entity, pos, Vector.Zero, player):ToPickup()
	if pedestal then pedestal:SetVarData(VAR_MAGIC + wished) end
	return pedestal
end

function item.debug_reroll_pedestal(player)
	if not player then return false end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)) do
		local pedestal = ent:ToPickup()
		if pedestal and pedestal.SubType == item.entity and pedestal_wish(pedestal) then
			local options = candidates(player)
			local target = options[1]
			if not target then return false end
			pedestal:Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, target, true, true, false)
			return true
		end
	end
	return false
end

table.insert(item.myToCall, {CallBack = enums.Callbacks.POST_REWIND, params = nil,
	Function = function() picker.clear() end,
})

return item

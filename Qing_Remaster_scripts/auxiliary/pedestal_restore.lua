-- Restored / rematerialized owned collectible pedestal adapter.
-- Does NOT own generation / price / options / Consistance.
-- Orchestrates: Encounter suppression + Spawn + auxi.self_morph + owned physical normalize.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local pedestal_encounter = require("Qing_Remaster_scripts.others.Pedestal_Encounter_holder")

local M = {}

--- Owned-resource return: clear offer-only fields; restore acquisition metadata after morph.
function M.normalize_owned_collectible(q, snapshot)
	if not q then
		return
	end
	snapshot = snapshot or {}
	q.Touched = snapshot.touched == true
	q.Charge = math.max(0, tonumber(snapshot.charge) or 0)
	q.OptionsPickupIndex = 0
	q.Price = 0
	q.ShopItemId = -1
	if q.AutoUpdatePrice ~= nil then
		q.AutoUpdatePrice = false
	end
end

--- Spawn a RESTORED OWNED collectible pedestal (not a NEW OFFER).
--- snapshot: { collectible_id, touched?, charge? }
--- on_ready(q): caller writes business payload + Consistance
function M.spawn_owned_collectible(owner, snapshot, pos, spawner, on_ready)
	snapshot = snapshot or {}
	local id = tonumber(snapshot.collectible_id) or 0
	if id <= 0 then
		return nil
	end
	local room = Game():GetRoom()
	pos = room:FindFreePickupSpawnPosition(pos or room:GetCenterPos(), 0, true)

	local q = nil
	pedestal_encounter.with_suppressed_encounter(owner or "owned_restore", function()
		q = Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_COLLECTIBLE,
			id,
			pos,
			Vector.Zero,
			spawner
		):ToPickup()
		if q then
			auxi.self_morph(q, {
				EntityType.ENTITY_PICKUP,
				PickupVariant.PICKUP_COLLECTIBLE,
				id,
			})
			pedestal_encounter.mark_suppressed(q, owner or "owned_restore")
		end
	end)

	if not q then
		return nil
	end

	M.normalize_owned_collectible(q, snapshot)

	if on_ready then
		on_ready(q)
	end
	return q
end

--- Rematerialize an owned collectible onto an existing empty collectible pedestal.
--- Semantic: RESTORE / REMATERIALIZE (not NEW OFFER).
--- Requires pickup.Variant == COLLECTIBLE and SubType <= 0 (already taken / empty).
--- snapshot: { collectible_id, touched?, charge? }
function M.rematerialize_on_existing(pickup, snapshot, owner, on_ready)
	snapshot = snapshot or {}
	local id = tonumber(snapshot.collectible_id) or 0
	if id <= 0 or not pickup then
		return nil
	end
	local q = pickup.ToPickup and pickup:ToPickup() or nil
	if not q or not q:Exists() then
		return nil
	end
	if q.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		return nil
	end
	if (tonumber(q.SubType) or 0) > 0 then
		return nil
	end

	pedestal_encounter.with_suppressed_encounter(owner or "owned_restore", function()
		auxi.self_morph(q, {
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_COLLECTIBLE,
			id,
		})
		pedestal_encounter.mark_suppressed(q, owner or "owned_restore")
	end)

	if not q:Exists() or (tonumber(q.SubType) or 0) ~= id then
		return nil
	end

	M.normalize_owned_collectible(q, snapshot)

	if on_ready then
		on_ready(q)
	end
	return q
end

return M

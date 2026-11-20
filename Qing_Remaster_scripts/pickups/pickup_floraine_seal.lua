-- Floraine Seal: first-clear quest pickup. Claim story then remove; never AddCollectible.

local enums = require("Qing_Remaster_scripts.core.enums")
local rewards = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.rewards")

local item = {
	ToCall = {},
	own_key = "Pickup_Floraine_Seal_",
	pickup = enums.Pickups.Floraine_Seal,
}

local function is_seal(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_PICKUP then
		return false
	end
	local v = item.pickup and item.pickup.Variant
	return v ~= nil and ent.Variant == v
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_INIT,
	params = nil,
	Function = function(_, pickup)
		if not is_seal(pickup) then return end
		local s = pickup:GetSprite()
		-- King sheet as temporary seal crest.
		pcall(function()
			s:ReplaceSpritesheet(0, "gfx/boss/Floraine/King.png")
			s:LoadGraphics()
			s:Play("Idle", true)
		end)
		pickup.Timeout = -1
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION,
	params = nil,
	Function = function(_, pickup, collider, _)
		if not is_seal(pickup) then return end
		local player = collider and collider:ToPlayer()
		if not player then return end
		-- Only remove after story registration succeeds (or already first-cleared).
		local ok = rewards.claim(player, {})
		if ok then
			rewards.remove_all_seals()
			pickup:Remove()
		end
		-- Always cancel native collectible-style pickup (seal stays if claim failed).
		return true
	end,
})

return item

-- First-clear Floraine Seal: spawn / restore / claim. No random reward pool.

local enums = require("Qing_Remaster_scripts.core.enums")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local arena = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.arena")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local rewards = {}

local function seal_variant()
	return enums.Pickups.Floraine_Seal and enums.Pickups.Floraine_Seal.Variant
end

function rewards.should_offer_unlock()
	if not runtime.is_unlock_pending() then
		return false
	end
	-- Permanent first clear = chapter1.stone node, not material token alone.
	if runtime.has_stone_first_clear() then
		return false
	end
	return true
end

function rewards.find_seal()
	local variant = seal_variant()
	if not variant then return nil end
	local list = Isaac.FindByType(EntityType.ENTITY_PICKUP, variant, -1, false, false)
	for _, ent in ipairs(list) do
		if ent:Exists() then
			return ent
		end
	end
	return nil
end

function rewards.spawn_seal(pos)
	if not rewards.should_offer_unlock() then
		return nil, "not_eligible"
	end
	local existing = rewards.find_seal()
	if existing then
		return existing, "exists"
	end
	local variant = seal_variant()
	if not variant then
		return nil, "no_variant"
	end
	pos = pos or arena.unlock_spawn_pos()
	local ent = Isaac.Spawn(EntityType.ENTITY_PICKUP, variant, 0, pos, Vector.Zero, nil)
	if ent then
		local pickup = ent:ToPickup()
		if pickup then
			pickup.Timeout = -1
			pickup.Wait = 20
		end
	end
	return ent, "spawned"
end

function rewards.restore_if_pending()
	if rewards.should_offer_unlock() then
		return rewards.spawn_seal()
	end
	return nil, "none"
end

--- Claim permanent clear. Must succeed before removing the pickup.
-- @param opts {debug_skip_story=bool, story_test=bool, force=bool}
function rewards.claim(player, opts)
	opts = opts or {}
	local ok, why = runtime.claim_boss_unlock(player, {
		skip_story = opts.debug_skip_story == true,
		story_test = opts.story_test == true,
		force = opts.force == true,
		require_story = opts.debug_skip_story ~= true,
	})
	if not ok then
		return false, why
	end
	pcall(function()
		sound_tracker.play(SoundEffect.SOUND_POWERUP1, 1, 0, false, 1)
	end)
	return true
end

function rewards.remove_all_seals()
	local variant = seal_variant()
	if not variant then return end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, variant, -1, false, false)) do
		ent:Remove()
	end
end

return rewards

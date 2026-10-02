-- Cohort / volley helpers only. Weapon-specific policy lives in attack_weapon_adapters.
-- Cohort key is source_id + family (player and each mimic familiar are separate sources).
local registry = require("Qing_Remaster_scripts.callbacks.attack_registry")

local M = {
	-- key -> { attack, open_frame, max_frame_delta }
	open_cohorts = {},
}

local function source_key(source_id)
	if source_id == nil then return "nil" end
	return tostring(source_id)
end

function M.cohort_key(source_id, family)
	return source_key(source_id) .. "|" .. tostring(family or "unknown")
end

-- Back-compat: old callers passed (player, family). Prefer opts.source_id.
function M.player_fallback_source_id(player)
	if not player then return "player:nil" end
	return "player:" .. tostring(GetPtrHash(player))
end

--- Open or join a cohort for same source_id+family within max_frame_delta (default 0 = same Game frame).
--- Returns attack, is_new
function M.create_or_join(player, family, opts)
	opts = opts or {}
	local max_delta = opts.max_frame_delta
	if max_delta == nil then max_delta = 0 end
	local frame = Game():GetFrameCount()
	local source_id = opts.source_id or M.player_fallback_source_id(player)
	local key = M.cohort_key(source_id, family)
	local cohort = M.open_cohorts[key]
	-- Drop stale cohort rows (EndAttack without close_attack_cohort left a dead pointer).
	if cohort and cohort.attack
		and (not cohort.attack.active or cohort.attack.ending or not cohort.attack.open_for_members) then
		M.open_cohorts[key] = nil
		cohort = nil
	end
	if cohort and cohort.attack and cohort.attack.active and cohort.attack.open_for_members then
		local age = frame - (cohort.open_frame or frame)
		if age <= max_delta then
			if registry.EmitAudit then
				registry.EmitAudit("attack_cohort_reuse", cohort.attack, {
					family = family,
					source_id = source_id,
					attack_id = cohort.attack.id,
					open_frame = cohort.open_frame,
					current_frame = frame,
					age = age,
					cohort_key = key,
					is_new = false,
					cohort_reused = true,
				})
			end
			return cohort.attack, false
		end
		-- Window expired: seal old and start new.
		registry.SealAttack(cohort.attack)
		M.open_cohorts[key] = nil
	end

	local attack = registry.CreateAttack(player, family, opts)
	M.open_cohorts[key] = {
		attack = attack,
		open_frame = frame,
		max_frame_delta = max_delta,
		source_id = source_id,
	}
	return attack, true
end

function M.get_open(source_id_or_player, family)
	local source_id = source_id_or_player
	if type(source_id_or_player) ~= "string" and source_id_or_player then
		-- Legacy: EntityPlayer userdata
		if source_id_or_player.ToPlayer or source_id_or_player.GetPlayerType then
			source_id = M.player_fallback_source_id(source_id_or_player)
		end
	end
	local key = M.cohort_key(source_id, family)
	local cohort = M.open_cohorts[key]
	if cohort and cohort.attack and cohort.attack.open_for_members and cohort.attack.active
		and not cohort.attack.ending then
		return cohort.attack
	end
	return nil
end

function M.seal_cohort(source_id_or_player, family)
	local source_id = source_id_or_player
	if type(source_id_or_player) ~= "string" and source_id_or_player then
		if source_id_or_player.ToPlayer or source_id_or_player.GetPlayerType then
			source_id = M.player_fallback_source_id(source_id_or_player)
		end
	end
	local key = M.cohort_key(source_id, family)
	local cohort = M.open_cohorts[key]
	if not cohort or not cohort.attack then return false end
	registry.SealAttack(cohort.attack)
	M.open_cohorts[key] = nil
	return true
end

--- Drop cohort rows that still point at this Attack (does not Seal/End).
function M.close_attack_cohort(attack)
	if not attack then return end
	local drop = {}
	for key, cohort in pairs(M.open_cohorts) do
		if cohort.attack and cohort.attack.id == attack.id then
			drop[#drop + 1] = key
		end
	end
	for i = 1, #drop do
		M.open_cohorts[drop[i]] = nil
	end
end

function M.seal_attack_and_clear(attack)
	if not attack then return end
	M.close_attack_cohort(attack)
	registry.SealAttack(attack)
end

--- Seal cohorts whose open_frame is older than their max_frame_delta relative to current frame.
function M.seal_expired()
	local frame = Game():GetFrameCount()
	local drop = {}
	for key, cohort in pairs(M.open_cohorts) do
		local max_delta = cohort.max_frame_delta or 0
		if cohort.attack and (frame - (cohort.open_frame or frame)) > max_delta then
			registry.SealAttack(cohort.attack)
			drop[#drop + 1] = key
		end
	end
	for i = 1, #drop do
		M.open_cohorts[drop[i]] = nil
	end
end

function M.clear_all()
	M.open_cohorts = {}
end

return M

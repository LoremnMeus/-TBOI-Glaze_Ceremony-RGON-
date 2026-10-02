-- Quest Run Scope Gate.
-- Unified policy: which run kinds may run Story Quests / future challenge quests.
-- Default for defs without run_scope: kind = "normal" (non-Challenge only).
--
-- Formal runtime (Panel / Toast / Tracker / Chapter1 threads) must consult this.
-- Debug Visual previews may bypass explicitly; do not write Challenge into StoryProgress.

local scope = {}

function scope.challenge_id()
	if not Isaac or not Isaac.GetChallenge then
		return 0
	end
	return Isaac.GetChallenge() or 0
end

function scope.is_challenge()
	return scope.challenge_id() > 0
end

--- Alias used by some call sites.
function scope.is_challenge_run()
	return scope.is_challenge()
end

function scope.is_normal_run()
	return not scope.is_challenge()
end

--- All existing Story / Chapter1 / ordinary side quests are normal-run only.
function scope.allows_story_quests()
	return not scope.is_challenge()
end

--- Per-definition scope. Missing run_scope ⇒ "normal".
--- kind:
---   normal    → non-Challenge only
---   challenge → Challenge only; optional ids = { challenge_id, ... }
---   any       → always
function scope.allows_quest(def)
	local cfg = def and def.run_scope
	local kind = (cfg and cfg.kind) or "normal"

	if kind == "any" then
		return true
	end

	if kind == "normal" then
		return not scope.is_challenge()
	end

	if kind == "challenge" then
		if not scope.is_challenge() then
			return false
		end
		local ids = cfg and cfg.ids
		if type(ids) ~= "table" or #ids == 0 then
			return true
		end
		local current = scope.challenge_id()
		for _, id in ipairs(ids) do
			if id == current then
				return true
			end
		end
		return false
	end

	return false
end

return scope

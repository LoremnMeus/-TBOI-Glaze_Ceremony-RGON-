-- DPS sampler: fractional rate accumulates internally; each Emit is one normalized opportunity.
local enums = require("Qing_Remaster_scripts.core.enums")
local registry = require("Qing_Remaster_scripts.callbacks.attack_registry")

local M = {
	own_key = "attack_dps_sampler_",
	-- hash -> accumulator number (for continuous weapons)
	accumulators = {},
}

function M.reset()
	M.accumulators = {}
end

function M.clear_hash(hash)
	if hash then M.accumulators[hash] = nil end
end

function M.emit_sample(attack, ent, extras)
	extras = extras or {}
	if not attack then return end
	registry.dispatch(enums.Callbacks.POST_ATTACK_DPS_SAMPLE, registry.make_event(attack, {
		member = ent,
		generation = extras.generation,
		position = extras.position or (ent and ent.Position),
		direction = extras.direction,
		sample_weight = extras.sample_weight, -- debug/source only; consumers must not re-scale
		reason = extras.reason or "sample",
	}))
end

--- Tear family: one Emit per tear member (normalized contribution 1.0).
function M.sample_tear_member(attack, ent, opts)
	opts = opts or {}
	local aid, gen = registry.read_entity_binding_meta(ent)
	M.emit_sample(attack, ent, {
		generation = gen,
		position = opts.position,
		direction = opts.direction or (ent and ent.Velocity),
		sample_weight = 1,
		reason = "tear_member",
	})
end

--- Continuous weapons: add normalized_rate; emit once per whole unit.
function M.feed_rate(attack, ent, normalized_rate, opts)
	opts = opts or {}
	if not attack or not ent then return 0 end
	if not normalized_rate or normalized_rate <= 0 then return 0 end
	local hash = GetPtrHash(ent)
	local acc = (M.accumulators[hash] or 0) + normalized_rate
	local emitted = 0
	local aid, gen = registry.read_entity_binding_meta(ent)
	while acc >= 1 do
		acc = acc - 1
		emitted = emitted + 1
		M.emit_sample(attack, ent, {
			generation = gen,
			position = opts.position,
			direction = opts.direction,
			sample_weight = normalized_rate,
			reason = opts.reason or "rate",
		})
	end
	M.accumulators[hash] = acc
	return emitted
end

return M

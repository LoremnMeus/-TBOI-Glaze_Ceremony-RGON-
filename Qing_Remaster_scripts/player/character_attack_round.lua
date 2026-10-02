-- Character Attack round helpers (M6 / M6.1).
-- Prefer wrapping a whole release/volley with begin/finish instead of per-Fire* patches.
--
-- Cohort Attack  = same-frame / short grouping.create_or_join (managed by attack_grouping)
-- Persistent Attack = multi-frame logical action; NOT in open_cohorts; caller SealAttack
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local CharacterAttackCompat = require("Qing_Remaster_scripts.player.character_attack_compat")

local M = {}

--- Same-frame / short cohort only. Joins attack_grouping.open_cohorts (seal_expired may Seal).
--- Alias kept as open_player_attack for M6 call sites; do not use for multi-frame actions.
function M.open_player_cohort(player, family, opts)
	opts = opts or {}
	if not player then return nil end
	family = family or opts.family or "tear"
	local source = attack_holder.classifier.make_player_source(player)
	return attack_holder.grouping.create_or_join(player, family, {
		max_frame_delta = opts.max_frame_delta or 0,
		source_id = source.source_id,
		source = source,
		position = opts.position or player.Position,
		direction = opts.direction,
	})
end

--- @deprecated name: use open_player_cohort for same-frame; use open_persistent_player_attack for multi-frame.
function M.open_player_attack(player, family, opts)
	return M.open_player_cohort(player, family, opts)
end

--- Multi-frame player action Attack. Not registered in open_cohorts; caller must Seal.
--- When opts.character_snapshot is a table, attach it BEFORE POST_ATTACK_ONCE so
--- Attack-level character actions (no BindMember) are visible to Aeon on Once.
function M.open_persistent_player_attack(player, family, opts)
	opts = opts or {}
	if not player then return nil end
	family = family or opts.family or "tear"
	local source = attack_holder.classifier.make_player_source(player)
	local position = opts.position or player.Position
	local direction = opts.direction
	local attack = attack_holder.CreateAttack(player, family, {
		source = source,
		source_id = source.source_id,
		position = position,
		direction = direction,
		synthetic = false,
	})
	if not attack then return nil end
	if type(opts.character_snapshot) == "table" then
		if CharacterAttackCompat.attach_attack_snapshot(attack, opts.character_snapshot) then
			-- Member-less persistent Attacks never reach BindMember Once; publish here.
			attack_holder.EmitAttackOnce(attack, {
				position = position,
				direction = direction,
				generation = 0,
				reason = opts.reason or "character_snapshot_once",
			})
		end
	end
	return attack
end

--- Multi-frame mimic/craft action Attack (e.g. Kidney). Not in open_cohorts; caller must Seal.
function M.open_persistent_mimic_attack(fam, player, family, opts)
	opts = opts or {}
	if not fam or not player then return nil end
	family = family or opts.family or "tear"
	local source = attack_holder.classifier.make_mimic_source(fam, player)
	return attack_holder.CreateAttack(player, family, {
		source = source,
		source_id = source.source_id,
		position = opts.position or fam.Position or player.Position,
		direction = opts.direction,
		synthetic = false,
	})
end

function M.seal_persistent_attack(attack)
	if not attack then return end
	if attack.active and not attack.ending then
		attack_holder.SealAttack(attack)
	end
end

--- Open a same-frame cohort Attack and push inherit Fire Context for a custom volley.
--- Returns token, attack (token may be nil if skipped).
function M.begin_player_round(player, family, opts)
	opts = opts or {}
	if not player then return nil, nil end
	local attack = M.open_player_cohort(player, family, opts)
	if not attack then return nil, nil end
	local pushed = attack_holder.PushFireContext({
		mode = "inherit",
		attack = attack,
		emitter = opts.emitter or player,
		role = opts.role or "primary",
		reason = opts.reason or "character_fire_round",
	})
	return pushed.token, attack
end

function M.finish(token)
	if token then
		attack_holder.PopFireContext(token)
	end
end

--- Run fn under a player Attack round (inherit context). Always finishes token.
function M.with_player_round(player, family, opts, fn)
	local token, attack = M.begin_player_round(player, family, opts)
	local ok, a, b, c, d = xpcall(fn, debug.traceback, attack)
	M.finish(token)
	if not ok then
		error(a)
	end
	return a, b, c, d
end

--- Run fn under untracked Fire Context (skill/bonus/continuous beams).
function M.with_untracked(reason, fn)
	local pushed = attack_holder.PushFireContext({
		mode = "untracked",
		reason = reason or "character_untracked",
	})
	local ok, a, b, c, d = xpcall(fn, debug.traceback)
	attack_holder.PopFireContext(pushed.token)
	if not ok then
		error(a)
	end
	return a, b, c, d
end

--- Inherit an existing Attack (e.g. tear death → Dr/Epic burst).
function M.with_inherit_attack(attack, opts, fn)
	opts = opts or {}
	if not attack or not attack.active or attack.ending then
		return M.with_untracked(opts.reason or "character_inherit_missing", fn)
	end
	local pushed = attack_holder.PushFireContext({
		mode = "inherit",
		attack = attack,
		emitter = opts.emitter,
		role = opts.role or "derived",
		reason = opts.reason or "character_inherit",
	})
	local ok, a, b, c, d = xpcall(fn, debug.traceback)
	attack_holder.PopFireContext(pushed.token)
	if not ok then
		error(a)
	end
	return a, b, c, d
end

M.holder = attack_holder

return M

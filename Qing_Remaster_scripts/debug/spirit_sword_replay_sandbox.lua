-- Spirit Sword Mimic sandbox (dev).
-- Spawn Attack/Spin via Spirit_Sword_holder; toggle hitbox debug.
-- Default OFF. No save writes. Does not use auxi.fire_Sword.
local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
local env = require("Qing_Remaster_scripts.core.dev_environment")
if not env.probes_allowed() then return env.disabled_probe_stub() end

local Sword = require("Qing_Remaster_scripts.mimics.Spirit_Sword_holder")

local item = {
	ToCall = {},
	own_key = "spirit_sword_replay_sandbox_",
}

local SCHEMA = "qing_spirit_sword_replay_sandbox"
local SCHEMA_VERSION = 1
local FILE_STEM = "spirit_sword_replay_sandbox"

local cfg = {
	enabled = false,
	draw_hitboxes = true,
	play_sound = true,
}

local runtime = nil

local DIRS = {
	Right = Vector(1, 0),
	Left = Vector(-1, 0),
	Up = Vector(0, -1),
	Down = Vector(0, 1),
}

local function ensure_runtime()
	if runtime then return runtime end
	runtime = {
		samples = 0,
		events = {},
		session_start = Game():GetFrameCount(),
		export_path = nil,
		export_error = nil,
	}
	return runtime
end

local function push_event(row)
	local rt = ensure_runtime()
	row.schema = SCHEMA
	row.schema_version = SCHEMA_VERSION
	row.game_frame = Game():GetFrameCount()
	rt.events[#rt.events + 1] = row
	rt.samples = rt.samples + 1
end

local function flush(force)
	local rt = ensure_runtime()
	if not force and #rt.events < 1 then
		return rt.export_path, rt.export_error
	end
	local header = {
		schema = SCHEMA,
		schema_version = SCHEMA_VERSION,
		probe = FILE_STEM,
		samples = rt.samples,
	}
	local text, err = probe_output.encode_jsonl(header, rt.events)
	if not text then
		rt.export_error = err
		return nil, err
	end
	local ok, path_or_err = probe_output.export_text(FILE_STEM, "jsonl", text)
	if ok then
		rt.export_path = path_or_err
		rt.export_error = nil
		return path_or_err, nil
	end
	rt.export_error = path_or_err
	return nil, path_or_err
end

local function primary_player()
	local p = Isaac.GetPlayer(0)
	if p and p.Exists and p:Exists() then return p end
	return nil
end

local function spawn_kind(kind, dir_name, with_beam)
	if not cfg.enabled then
		item.set_enabled(true)
	end
	local player = primary_player()
	if not player then
		return false, "no_player"
	end
	local dir = DIRS[dir_name] or Vector(1, 0)
	local opts = {
		kind = kind,
		owner = player,
		source = player,
		position = player.Position,
		direction = dir,
		damage = player.Damage,
		fire_mode = "untracked",
		play_sound = cfg.play_sound ~= false,
	}
	if with_beam then
		opts.beam = {enabled = true}
	end
	local ent, ctrl = Sword.spawn(opts)
	if not ent then
		return false, "spawn_nil"
	end
	push_event({
		phase = "spawn",
		kind = kind,
		dir = dir_name,
		ptr = GetPtrHash(ent),
		damage = opts.damage,
		beam = opts.beam ~= nil,
		play_sound = opts.play_sound ~= false,
	})
	flush(true)
	return true
end

function item.get_config()
	local rt = runtime
	return {
		enabled = cfg.enabled,
		draw_hitboxes = cfg.draw_hitboxes,
		play_sound = cfg.play_sound ~= false,
		samples = rt and rt.samples or 0,
		export_path = rt and rt.export_path or nil,
		export_error = rt and rt.export_error or nil,
	}
end

function item.set_enabled(on)
	cfg.enabled = on == true
	Sword.set_draw_hitboxes(cfg.enabled and cfg.draw_hitboxes)
	if cfg.enabled then
		runtime = nil
		ensure_runtime()
		push_event({phase = "session_start"})
		flush(true)
	else
		flush(true)
		Sword.set_draw_hitboxes(false)
	end
end

function item.set_draw_hitboxes(on)
	cfg.draw_hitboxes = on == true
	Sword.set_draw_hitboxes(cfg.enabled and cfg.draw_hitboxes)
end

function item.set_play_sound(on)
	cfg.play_sound = on ~= false
end

function item.spawn_attack(dir_name)
	return spawn_kind("attack", dir_name or "Right", false)
end

function item.spawn_spin(dir_name)
	-- Spin melee only — no Sword Beam (Beam Test is separate).
	return spawn_kind("spin", dir_name or "Right", false)
end

function item.spawn_beam_test(dir_name)
	-- Spin + Sword Beam experiment.
	return spawn_kind("spin", dir_name or "Right", true)
end

function item.clear_events()
	runtime = nil
	ensure_runtime()
end

function item.clear()
	flush(true)
	runtime = nil
	cfg.enabled = false
	Sword.set_draw_hitboxes(false)
end

function item.export_jsonl(force)
	return flush(force ~= false)
end

function item.get_summary()
	local c = item.get_config()
	return string.format(
		"Spirit Sword Replay Sandbox\nenabled=%s draw_hitboxes=%s play_sound=%s samples=%s\nexport=%s",
		tostring(c.enabled),
		tostring(c.draw_hitboxes),
		tostring(c.play_sound),
		tostring(c.samples),
		tostring(c.export_path or c.export_error or "none")
	)
end

function item.get_status_text()
	return item.get_summary()
end

function item.copy_summary()
	return probe_output.copy_summary(item.get_summary())
end

function item.copy_full_report()
	local rt = ensure_runtime()
	return probe_output.copy_jsonl({
		schema = SCHEMA,
		schema_version = SCHEMA_VERSION,
		probe = FILE_STEM,
		samples = rt.samples,
	}, rt.events)
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function(_)
		if cfg.enabled then flush(true) end
	end,
})

return item

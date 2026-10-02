-- Runtime Stitch enemy profiles — thin registry over Native Mixture sources.
-- MOVEMENT_CHOICES / ATTACK_CHOICES drive production 3+3 rolls and Debug matrix.
-- Do NOT invent handmade movement/attack AI; native NPC AI + catalog Extra only.
-- profile.mixture overlays are reserved for true Runtime incompatibilities — not
-- for re-copying Extra_Mixture_data hooks that already load via source_mixture_entry.

local profiles = {
	movement = {
		move_chase = {
			id = "move_chase",
			ui = { category = "movement", name = "Gaper" },
			source = { type = 10, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 1 },
			mixture_side = "Left",
			geometry_prior = {
				avg_mid_y = 18.42,
				avg_vertical_span = 15.32,
			},
		},
		move_pursuit = {
			id = "move_pursuit",
			ui = { category = "movement", name = "Charger" },
			source = { type = 23, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 20 },
			mixture_side = "Left",
			geometry_prior = {
				avg_mid_y = 15.6667,
				avg_vertical_span = 18.1333,
			},
		},
		move_wander = {
			id = "move_wander",
			ui = { category = "movement", name = "Globin" },
			source = { type = 24, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 24 },
			mixture_side = "Left",
			geometry_prior = {
				avg_mid_y = 27.7812,
				avg_vertical_span = 17.1875,
			},
		},
		move_pacer = {
			id = "move_pacer",
			ui = { category = "movement", name = "Pacer" },
			source = { type = 11, variant = 1, subtype = 0 },
			source_mixture_entry = { group = 2, id = 5 },
			mixture_side = "Left",
			geometry_prior = {
				avg_mid_y = 18.45,
				avg_vertical_span = 13.1,
			},
		},
		move_maggot = {
			id = "move_maggot",
			ui = { category = "movement", name = "Maggot" },
			source = { type = 21, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 17 },
			mixture_side = "Left",
			geometry_prior = {
				avg_mid_y = 15.9167,
				avg_vertical_span = 18.0,
			},
		},
		move_hopper = {
			id = "move_hopper",
			ui = { category = "movement", name = "Hopper" },
			source = { type = 29, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 35 },
			mixture_side = "Left",
			-- Compat: Extra.swap_weight=9 is not a Runtime Stitch controller capability yet.
			-- Batch 2 validates native jump + KeepTarget + order via catalog only.
			geometry_prior = {
				avg_mid_y = 15.625,
				avg_vertical_span = 14.25,
			},
		},
		move_leaper = {
			id = "move_leaper",
			ui = { category = "movement", name = "Leaper" },
			source = { type = 34, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 42 },
			mixture_side = "Left",
			-- Inherits Hopper KeepTarget/order via Extra check=35.
			geometry_prior = {
				avg_mid_y = 15.625,
				avg_vertical_span = 14.25,
			},
		},
	},

	attack = {
		attack_single = {
			id = "attack_single",
			ui = { category = "attack", name = "Horf" },
			source = { type = 12, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 6 },
			mixture_side = "Right",
			geometry_prior = {
				avg_mid_y = 17.75,
				avg_vertical_span = 26.5,
			},
			visual = {
				-- Optional explicit donor scale; omit / 1.0 = no uniform resize.
			},
		},
		attack_burst = {
			id = "attack_burst",
			ui = { category = "attack", name = "Pooter" },
			source = { type = 14, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 8 },
			mixture_side = "Right",
			geometry_prior = {
				avg_mid_y = 14.0,
				avg_vertical_span = 15.625,
			},
			-- Geometry-frame filter (NOT CoverDetail st/ed).
			-- Evidence: Monster_001_Pooter.png centerline spans — Fly#0=13 (body),
			-- Fly#1=18 (wings raised). Attack tiles with cl_span>=18 inflate seam.
			-- Appear odd-ish frames reuse Fly#1 crop (XCrop=32). Visual still plays.
			visual = {
				ignore_geometry_frames = {
					Fly = { [1] = true },
					Attack = {
						[6] = true,
						[7] = true,
						[11] = true,
						[13] = true,
					},
					Appear = {
						[2] = true,
						[4] = true,
						[6] = true,
						[8] = true,
						[10] = true,
						[12] = true,
						[14] = true,
						[16] = true,
						[18] = true,
					},
				},
			},
		},
		attack_spread = {
			id = "attack_spread",
			ui = { category = "attack", name = "Host" },
			source = { type = 27, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 33 },
			mixture_side = "Right",
			geometry_prior = {
				avg_mid_y = 33.0,
				avg_vertical_span = 29.3333,
			},
		},
		attack_clotty = {
			id = "attack_clotty",
			ui = { category = "attack", name = "Clotty" },
			source = { type = 15, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 10 },
			mixture_side = "Right",
			geometry_prior = {
				avg_mid_y = 39.6364,
				avg_vertical_span = 26.3636,
			},
		},
		attack_gusher = {
			id = "attack_gusher",
			ui = { category = "attack", name = "Gusher" },
			source = { type = 11, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 4 },
			mixture_side = "Right",
			-- Compat: Extra no_overlay/reload are non-runtime metadata under native sprites.
			geometry_prior = {
				avg_mid_y = 17.55,
				avg_vertical_span = 13.1,
			},
		},
		attack_maw = {
			id = "attack_maw",
			ui = { category = "attack", name = "Maw" },
			source = { type = 26, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 30 },
			mixture_side = "Right",
			geometry_prior = {
				avg_mid_y = 16.25,
				avg_vertical_span = 15.5,
			},
		},
		attack_boil = {
			id = "attack_boil",
			ui = { category = "attack", name = "Boil" },
			source = { type = 30, variant = 0, subtype = 0 },
			source_mixture_entry = { group = 2, id = 37 },
			mixture_side = "Right",
			geometry_prior = {
				avg_mid_y = 25.4,
				avg_vertical_span = 13.2,
			},
			-- After seam match (both halves at host span H), shrink/grow the whole
			-- composite toward Attack span D: T=lerp(H,D,w); common_scale=T/H.
			-- w=0 Movement-only, w=0.5 equal, w=1 Attack-only. Not Sprite.Scale.
			visual = {
				seam_size_attack_weight = 0.5,
			},
		},
	},
}

profiles.MOVEMENT_CHOICES = {
	"move_chase",
	"move_pursuit",
	"move_wander",
	"move_pacer",
	"move_maggot",
	"move_hopper",
	"move_leaper",
}

profiles.ATTACK_CHOICES = {
	"attack_single",
	"attack_burst",
	"attack_spread",
	"attack_clotty",
	"attack_gusher",
	"attack_maw",
	"attack_boil",
}

local forbidden_sources = {
	["201:0:0"] = "non-standard stone mechanism",
	["202:0:0"] = "non-standard stone mechanism",
	["85:0:0"] = "spider special movement",
	["18:0:0"] = "tiny fly offset — not geometry baseline",
}

local function source_key(src)
	if type(src) ~= "table" then
		return nil
	end
	return string.format(
		"%d:%d:%d",
		tonumber(src.type) or -1,
		tonumber(src.variant) or 0,
		tonumber(src.subtype) or 0
	)
end

local function value_kind(v)
	local t = type(v)
	if t == "number" then
		return "number", v
	end
	if t == "boolean" then
		return "boolean", v
	end
	if t == "function" then
		return "function", true
	end
	if t == "string" then
		return "string", v
	end
	if t == "table" then
		return "table", true
	end
	return t, nil
end

function profiles.get(id)
	if type(id) ~= "string" then
		return nil
	end
	return profiles.movement[id] or profiles.attack[id]
end

function profiles.get_movement(id)
	return profiles.movement[id]
end

function profiles.get_attack(id)
	return profiles.attack[id]
end

function profiles.display_name(id)
	local p = profiles.get(id)
	local name = p and p.ui and p.ui.name
	if type(name) == "string" and name ~= "" then
		return name
	end
	return tostring(id or "?")
end

--- Declarative geometry-frame ignore map from profile.visual (live + Bestiary).
function profiles.ignore_geometry_frames_of(profile)
	local vis = profile and profile.visual
	if type(vis) ~= "table" then
		return nil
	end
	local map = vis.ignore_geometry_frames
	if type(map) ~= "table" then
		return nil
	end
	return map
end

function profiles.list_movement_ids()
	local out = {}
	for i = 1, #profiles.MOVEMENT_CHOICES do
		out[i] = profiles.MOVEMENT_CHOICES[i]
	end
	return out
end

function profiles.list_attack_ids()
	local out = {}
	for i = 1, #profiles.ATTACK_CHOICES do
		out[i] = profiles.ATTACK_CHOICES[i]
	end
	return out
end

function profiles.is_forbidden_source(src)
	local key = source_key(src)
	return key and forbidden_sources[key] or nil
end

local function audit_mixture_capabilities(id, mixture, errors)
	local controller = require("Qing_Remaster_scripts.auxiliary.native_mixture.controller")
	local caps = controller.CAPABILITIES or {}
	local non = controller.NON_RUNTIME_METADATA or {}
	for key in pairs(mixture or {}) do
		if caps[key] == false then
			errors[#errors + 1] = id .. ": mixture." .. key .. " unsupported (CAPABILITIES=false)"
		elseif caps[key] == nil and not non[key] then
			errors[#errors + 1] = id .. ": mixture." .. key .. " unknown (not in CAPABILITIES / NON_RUNTIME_METADATA)"
		end
	end
end

--- Soft audit: merged catalog entry keys unknown to Runtime (print only, never fail).
local function warn_merged_unsupported_fields(id, p)
	local sme = p and p.source_mixture_entry
	if type(sme) ~= "table" or sme.group == nil or sme.id == nil then
		return
	end
	local catalog = require("Qing_Remaster_scripts.auxiliary.native_mixture.catalog")
	local controller = require("Qing_Remaster_scripts.auxiliary.native_mixture.controller")
	local caps = controller.CAPABILITIES or {}
	local non = controller.NON_RUNTIME_METADATA or {}
	local entry = catalog.get(p.mixture_side, sme.group, sme.id)
	if type(entry) ~= "table" then
		return
	end
	for key in pairs(entry) do
		if caps[key] == nil and not non[key] then
			print(
				"[runtime_stitch_enemy_profiles] warn "
					.. tostring(id)
					.. ": merged entry contains unsupported runtime field `"
					.. tostring(key)
					.. "`"
			)
		end
	end
end

local function validate_choice_pool(pool, expect_cat, fail)
	local seen = {}
	for i = 1, #pool do
		local id = pool[i]
		if type(id) ~= "string" then
			fail("choice pool #" .. tostring(i) .. ": non-string id")
		elseif seen[id] then
			fail(id .. ": duplicated in " .. expect_cat .. " choice pool")
		else
			seen[id] = true
			local p = profiles.get(id)
			if not p then
				fail(id .. ": listed in " .. expect_cat .. " choice pool but profile missing")
			elseif not p.ui or p.ui.category ~= expect_cat then
				fail(id .. ": choice pool category must be " .. expect_cat)
			end
		end
	end
end

function profiles.validate()
	local errors = {}
	local function fail(msg)
		errors[#errors + 1] = msg
	end
	local function check_profile(id, p, expect_cat, handmade_key)
		if not p.ui or p.ui.category ~= expect_cat then
			fail(id .. ": ui.category must be " .. expect_cat)
		end
		if not p.ui.name or type(p.ui.name) ~= "string" or p.ui.name == "" then
			fail(id .. ": missing ui.name")
		end
		if type(p.mixture) == "table" then
			audit_mixture_capabilities(id, p.mixture, errors)
		end
		-- mixture{} optional: scalars/functions come from merged Mixture_data;
		-- profile.mixture only overlays Qing-ported function hooks when needed.
		if p[handmade_key] ~= nil then
			fail(id .. ": handmade " .. handmade_key .. "{} forbidden")
		end
		if type(p.source) ~= "table" or p.source.type == nil then
			fail(id .. ": incomplete source")
		end
		if type(p.geometry_prior) ~= "table" then
			fail(id .. ": missing geometry_prior{}")
		end
		if type(p.source_mixture_entry) ~= "table"
			or p.source_mixture_entry.group == nil
			or p.source_mixture_entry.id == nil
		then
			fail(id .. ": missing source_mixture_entry{group,id}")
		end
		local why = profiles.is_forbidden_source(p.source)
		if why then
			fail(id .. ": forbidden source " .. why)
		end
		warn_merged_unsupported_fields(id, p)
	end
	for id, p in pairs(profiles.movement) do
		check_profile(id, p, "movement", "movement")
	end
	for id, p in pairs(profiles.attack) do
		check_profile(id, p, "attack", "attack")
	end
	validate_choice_pool(profiles.MOVEMENT_CHOICES, "movement", fail)
	validate_choice_pool(profiles.ATTACK_CHOICES, "attack", fail)
	return #errors == 0, errors
end

--- Compare live profiles against codex_work reference snapshot (dev only).
--- Does not require() the snapshot through package.path (codex_work is not runtime).
function profiles.audit_against_reference_snapshot()
	local baseline = nil
	local load_err = nil
	local candidates = {}
	if Isaac and Isaac.GetCurrentModPath then
		candidates[#candidates + 1] = Isaac.GetCurrentModPath()
			.. "codex_work/reference/stitch_edition/runtime_stitch_baseline_metadata.lua"
	end
	candidates[#candidates + 1] = "codex_work/reference/stitch_edition/runtime_stitch_baseline_metadata.lua"
	for i = 1, #candidates do
		local path = candidates[i]
		local chunk, err = loadfile(path)
		if chunk then
			local ok, ret = pcall(chunk)
			if ok and type(ret) == "table" then
				baseline = ret
				break
			end
			load_err = tostring(ret)
		else
			load_err = tostring(err)
		end
	end
	if type(baseline) ~= "table" then
		return false, { "baseline snapshot missing or unloadable: " .. tostring(load_err) }
	end
	local errors = {}
	local function check_one(pid, expect)
		local p = profiles.get(pid)
		if not p then
			errors[#errors + 1] = pid .. ": profile missing"
			return
		end
		if expect.source then
			local s = p.source or {}
			if (s.type or -1) ~= expect.source.type
				or (s.variant or 0) ~= (expect.source.variant or 0)
				or (s.subtype or 0) ~= (expect.source.subtype or 0)
			then
				errors[#errors + 1] = pid .. ": source Type/Var/Sub mismatch"
			end
		end
		if expect.source_mixture_entry then
			local e = p.source_mixture_entry or {}
			if e.group ~= expect.source_mixture_entry.group or e.id ~= expect.source_mixture_entry.id then
				errors[#errors + 1] = pid .. ": source_mixture_entry mismatch"
			end
		end
		local mix = p.mixture or {}
		local expect_keys = expect.keys or {}
		local have = {}
		for k in pairs(mix) do
			have[k] = true
		end
		for i = 1, #expect_keys do
			local k = expect_keys[i]
			if not have[k] then
				errors[#errors + 1] = pid .. ": missing mixture key " .. k
			end
		end
		for k in pairs(have) do
			local allowed = false
			for i = 1, #expect_keys do
				if expect_keys[i] == k then
					allowed = true
					break
				end
			end
			if not allowed then
				errors[#errors + 1] = pid .. ": unexpected mixture key " .. k
			end
		end
		if expect.scalars then
			for k, want in pairs(expect.scalars) do
				local kind, val = value_kind(mix[k])
				if want == "function" then
					if kind ~= "function" then
						errors[#errors + 1] = pid .. ": " .. k .. " expected function got " .. kind
					end
				elseif val ~= want then
					errors[#errors + 1] = pid .. ": " .. k .. " expected " .. tostring(want) .. " got " .. tostring(val)
				end
			end
		end
		if expect.merged_expect then
			local catalog = require("Qing_Remaster_scripts.auxiliary.native_mixture.catalog")
			local sme = p.source_mixture_entry or {}
			local entry = catalog.get(p.mixture_side, sme.group, sme.id)
			if not entry then
				errors[#errors + 1] = pid
					.. ": catalog entry missing for "
					.. tostring(sme.group)
					.. "/"
					.. tostring(sme.id)
			else
				for k, want in pairs(expect.merged_expect) do
					if entry[k] ~= want then
						errors[#errors + 1] = pid
							.. ": merged."
							.. k
							.. " expected "
							.. tostring(want)
							.. " got "
							.. tostring(entry[k])
					end
				end
			end
		end
	end
	for pid, expect in pairs(baseline.profiles or {}) do
		check_one(pid, expect)
	end
	return #errors == 0, errors
end

do
	local ok, errs = profiles.validate()
	if not ok then
		for i = 1, #errs do
			print("[runtime_stitch_enemy_profiles] " .. tostring(errs[i]))
		end
	end
end

return profiles

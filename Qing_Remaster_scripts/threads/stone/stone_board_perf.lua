-- Stone Board Render V3.2 — Performance Attribution (probe-only).
-- Default OFF: all hooks no-op when disabled. Uses Isaac.GetNanoTime (ns).

local perf = {}

local SAMPLE_N = 120
local enabled = false
local fixed_view = false
local fixed_anchor = nil -- { list_index, px, py }

local cur = nil -- current render-frame accumulators
local samples = {} -- ring of completed frame records
local sample_i = 0
local sample_count = 0
local last_flush_serial = -1
local events = {}
local MAX_EVENTS = 64

local function nano()
	if Isaac.GetNanoTime then
		return Isaac.GetNanoTime()
	end
	-- Fallback: Isaac.GetTime is ms-scale wall clock (not as precise).
	if Isaac.GetTime then
		return Isaac.GetTime() * 1000000
	end
	return 0
end

local function ns_to_ms(ns)
	return (tonumber(ns) or 0) / 1e6
end

local function new_frame()
	return {
		visibility_ns = 0,
		ownership_ns = 0,
		render_ctx_ns = 0,
		sprite_render_ns = 0,
		grid_callback_ns = 0,
		empty_overlay_ns = 0,
		fallback_scan_ns = 0,
		stone_update_ns = 0,
		path = {
			EMPTY_HELPER = 0,
			GRID_PRE = 0,
			GRID_PIT_POST = 0,
			PIT_POST = 0,
		},
		counts = {
			grid_callbacks = 0,
			resolve_index_direct = 0,
			resolve_index_position = 0,
			resolve_index_fullscan = 0,
			resolve_index_fullscan_skipped = 0,
			fullscan_grid_visits = 0,
			render_context_builds = 0,
			frame_ctx_hits = 0,
			frame_ctx_misses = 0,
			visibility_cache_hits = 0,
			visibility_cache_misses = 0,
			owner_verified_indices = 0,
			verify_owner_calls = 0,
			verify_owner_local_calls = 0,
			sprite_renders = 0,
			sprite_renders_skipped = 0,
			empty_overlay_calls = 0,
			duplicate_draws = 0,
			overlay_effect_renders = 0,
		},
		draw_hits = {}, -- index -> { source=count }
		overlay_hashes = {},
	}
end

local function ensure_cur(serial)
	serial = serial or (Isaac.GetFrameCount and Isaac.GetFrameCount() or Game():GetFrameCount())
	if cur and cur.serial == serial then
		return cur
	end
	if cur and cur.serial ~= serial then
		perf.flush_frame()
	end
	cur = new_frame()
	cur.serial = serial
	return cur
end

function perf.set_enabled(on)
	enabled = on == true
	if not enabled then
		cur = nil
		last_flush_serial = -1
	end
end

function perf.is_enabled()
	return enabled
end

function perf.set_sample_size(n)
	SAMPLE_N = math.max(30, math.min(600, tonumber(n) or 120))
end

function perf.get_sample_size()
	return SAMPLE_N
end

function perf.reset()
	samples = {}
	sample_i = 0
	sample_count = 0
	cur = nil
	events = {}
	last_flush_serial = -1
	fixed_anchor = nil
end

function perf.set_fixed_view(on)
	fixed_view = on == true
	if fixed_view then
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		local p = Game():GetPlayer(0)
		fixed_anchor = {
			list_index = desc and desc.ListIndex,
			px = p and p.Position.X,
			py = p and p.Position.Y,
		}
	else
		fixed_anchor = nil
	end
end

function perf.fixed_view_ok()
	if not fixed_view or not fixed_anchor then
		return true, "off"
	end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local p = Game():GetPlayer(0)
	if not desc or desc.ListIndex ~= fixed_anchor.list_index then
		return false, "room_changed"
	end
	if p and fixed_anchor.px then
		local d = (p.Position - Vector(fixed_anchor.px, fixed_anchor.py)):Length()
		if d > 24 then
			return false, "player_moved"
		end
	end
	return true, "locked"
end

local function push_event(kind, payload)
	if #events >= MAX_EVENTS then
		table.remove(events, 1)
	end
	events[#events + 1] = {
		frame = Game():GetFrameCount(),
		kind = kind,
		payload = payload,
	}
end

function perf.flush_frame()
	if not enabled or not cur then
		return
	end
	local serial = cur.serial
	if serial == last_flush_serial then
		return
	end
	last_flush_serial = serial
	-- Count duplicate draws.
	local dup = 0
	for _, sources in pairs(cur.draw_hits) do
		local n = 0
		for _, c in pairs(sources) do
			n = n + c
		end
		if n > 1 then
			dup = dup + 1
		end
	end
	cur.counts.duplicate_draws = dup
	local overlay_n = 0
	for _ in pairs(cur.overlay_hashes) do
		overlay_n = overlay_n + 1
	end
	if overlay_n > 1 then
		push_event("multi_overlay", { count = overlay_n })
	end
	if dup > 0 then
		push_event("duplicate_draws", { cells = dup })
	end

	sample_i = (sample_i % SAMPLE_N) + 1
	samples[sample_i] = cur
	if sample_count < SAMPLE_N then
		sample_count = sample_count + 1
	end
	cur = nil
end

--- Call at start of each board entry / POST_RENDER to roll frames.
function perf.touch_frame()
	if not enabled then
		return
	end
	ensure_cur()
end

function perf.inc(key, n)
	if not enabled then
		return
	end
	local f = ensure_cur()
	f.counts[key] = (f.counts[key] or 0) + (n or 1)
end

function perf.add_ns(bucket, ns)
	if not enabled or not bucket then
		return
	end
	local f = ensure_cur()
	f[bucket] = (f[bucket] or 0) + (ns or 0)
end

function perf.add_path_ns(source, ns)
	if not enabled then
		return
	end
	local f = ensure_cur()
	local key = source or "UNKNOWN"
	if key == "PIT_POST" then
		key = "GRID_PIT_POST"
	end
	f.path[key] = (f.path[key] or 0) + (ns or 0)
end

--- Timed scope. Returns end function (or no-op).
function perf.scope(bucket)
	if not enabled then
		return function() end
	end
	ensure_cur()
	local t0 = nano()
	return function()
		perf.add_ns(bucket, nano() - t0)
	end
end

function perf.scope_path(source)
	if not enabled then
		return function() end
	end
	ensure_cur()
	local t0 = nano()
	return function()
		perf.add_path_ns(source, nano() - t0)
	end
end

function perf.mark_draw(index, source)
	if not enabled or index == nil then
		return
	end
	local f = ensure_cur()
	local row = f.draw_hits[index]
	if not row then
		row = {}
		f.draw_hits[index] = row
	end
	local s = source or "?"
	row[s] = (row[s] or 0) + 1
end

function perf.mark_overlay(effect)
	if not enabled or not effect then
		return
	end
	local f = ensure_cur()
	f.counts.overlay_effect_renders = (f.counts.overlay_effect_renders or 0) + 1
	local h = GetPtrHash(effect)
	f.overlay_hashes[h] = (f.overlay_hashes[h] or 0) + 1
end

local function percentile(sorted, p)
	if #sorted < 1 then
		return 0
	end
	local idx = math.max(1, math.min(#sorted, math.ceil(#sorted * p)))
	return sorted[idx]
end

local function collect_metric(getter)
	local vals = {}
	for i = 1, sample_count do
		local fr = samples[i]
		if fr then
			vals[#vals + 1] = getter(fr)
		end
	end
	table.sort(vals)
	local sum = 0
	local peak = 0
	for _, v in ipairs(vals) do
		sum = sum + v
		if v > peak then peak = v end
	end
	local n = #vals
	return {
		avg = n > 0 and (sum / n) or 0,
		p95 = percentile(vals, 0.95),
		max = peak,
		n = n,
	}
end

function perf.get_live_counts()
	if cur then
		return cur.counts
	end
	if sample_count > 0 then
		local fr = samples[sample_i]
		return fr and fr.counts or {}
	end
	return {}
end

function perf.summary_stats()
	perf.flush_frame()
	local buckets = {
		"visibility_ns",
		"ownership_ns",
		"render_ctx_ns",
		"sprite_render_ns",
		"grid_callback_ns",
		"empty_overlay_ns",
		"fallback_scan_ns",
		"stone_update_ns",
	}
	local out = { sample_n = sample_count, sample_cap = SAMPLE_N, metrics = {}, paths = {}, counts_last = perf.get_live_counts() }
	for _, b in ipairs(buckets) do
		local st = collect_metric(function(fr) return ns_to_ms(fr[b] or 0) end)
		out.metrics[b:gsub("_ns$", "_ms")] = st
	end
	for _, path in ipairs({ "EMPTY_HELPER", "GRID_PRE", "GRID_PIT_POST" }) do
		out.paths[path] = collect_metric(function(fr) return ns_to_ms((fr.path and fr.path[path]) or 0) end)
	end
	local count_keys = {
		"grid_callbacks",
		"resolve_index_direct",
		"resolve_index_position",
		"resolve_index_fullscan",
		"resolve_index_fullscan_skipped",
		"fullscan_grid_visits",
		"render_context_builds",
		"frame_ctx_hits",
		"frame_ctx_misses",
		"visibility_cache_hits",
		"visibility_cache_misses",
		"owner_verified_indices",
		"verify_owner_calls",
		"verify_owner_local_calls",
		"sprite_renders",
		"sprite_renders_skipped",
		"empty_overlay_calls",
		"duplicate_draws",
		"overlay_effect_renders",
	}
	out.counts_avg = {}
	for _, k in ipairs(count_keys) do
		out.counts_avg[k] = collect_metric(function(fr) return (fr.counts and fr.counts[k]) or 0 end)
	end
	local ok_fv, fv_why = perf.fixed_view_ok()
	out.fixed_view = { enabled = fixed_view, ok = ok_fv, why = fv_why }
	out.events = events
	return out
end

local function fmt_ms(st)
	if not st then return "n/a" end
	return string.format("avg=%.3f p95=%.3f max=%.3f (n=%d)", st.avg or 0, st.p95 or 0, st.max or 0, st.n or 0)
end

local function fmt_cnt(st)
	if not st then return "n/a" end
	return string.format("avg=%.1f p95=%.0f max=%.0f", st.avg or 0, st.p95 or 0, st.max or 0)
end

function perf.format_summary_lines()
	local s = perf.summary_stats()
	local lines = {
		"Stone Board Performance Attribution (V3.2)",
		string.format("  Samples: %d / %d   timer=Isaac.GetNanoTime (ns→ms)", s.sample_n, s.sample_cap),
		string.format("  Fixed view: enabled=%s ok=%s (%s)",
			tostring(s.fixed_view.enabled), tostring(s.fixed_view.ok), tostring(s.fixed_view.why)),
		"  --- Phase ms ---",
		"  visibility_ms: " .. fmt_ms(s.metrics.visibility_ms),
		"  ownership_ms:  " .. fmt_ms(s.metrics.ownership_ms),
		"  render_ctx_ms: " .. fmt_ms(s.metrics.render_ctx_ms),
		"  sprite_render_ms: " .. fmt_ms(s.metrics.sprite_render_ms),
		"  grid_callback_ms: " .. fmt_ms(s.metrics.grid_callback_ms),
		"  empty_overlay_ms: " .. fmt_ms(s.metrics.empty_overlay_ms),
		"  fallback_scan_ms: " .. fmt_ms(s.metrics.fallback_scan_ms),
		"  stone_update_ms:  " .. fmt_ms(s.metrics.stone_update_ms),
		"  --- Path ms ---",
		"  EMPTY_HELPER: " .. fmt_ms(s.paths.EMPTY_HELPER),
		"  GRID_PRE:     " .. fmt_ms(s.paths.GRID_PRE),
		"  PIT_POST:     " .. fmt_ms(s.paths.GRID_PIT_POST),
		"  --- Counts (per render frame) ---",
		"  render_context_builds: " .. fmt_cnt(s.counts_avg.render_context_builds),
		"  frame_ctx hit/miss:    "
			.. fmt_cnt(s.counts_avg.frame_ctx_hits) .. " / "
			.. fmt_cnt(s.counts_avg.frame_ctx_misses),
		"  verify_owner_calls:    " .. fmt_cnt(s.counts_avg.verify_owner_calls),
		"  verify_owner_local:    " .. fmt_cnt(s.counts_avg.verify_owner_local_calls),
		"  owner_verified_indices:" .. fmt_cnt(s.counts_avg.owner_verified_indices),
		"  grid_callbacks:        " .. fmt_cnt(s.counts_avg.grid_callbacks),
		"  resolve_direct/pos/fullscan: "
			.. fmt_cnt(s.counts_avg.resolve_index_direct) .. " / "
			.. fmt_cnt(s.counts_avg.resolve_index_position) .. " / "
			.. fmt_cnt(s.counts_avg.resolve_index_fullscan),
		"  fullscan_skipped:      " .. fmt_cnt(s.counts_avg.resolve_index_fullscan_skipped),
		"  fullscan_grid_visits:  " .. fmt_cnt(s.counts_avg.fullscan_grid_visits),
		"  vis cache hit/miss:    "
			.. fmt_cnt(s.counts_avg.visibility_cache_hits) .. " / "
			.. fmt_cnt(s.counts_avg.visibility_cache_misses),
		"  sprite_renders / skipped: "
			.. fmt_cnt(s.counts_avg.sprite_renders) .. " / "
			.. fmt_cnt(s.counts_avg.sprite_renders_skipped),
		"  duplicate_draw_cells:  " .. fmt_cnt(s.counts_avg.duplicate_draws),
		"  overlay_effect_renders:" .. fmt_cnt(s.counts_avg.overlay_effect_renders),
	}
	local last = s.counts_last or {}
	lines[#lines + 1] = string.format(
		"  Last frame spotlight: ctx_builds=%s fullscan_visits=%s grid_cb=%s dup_cells=%s",
		tostring(last.render_context_builds),
		tostring(last.fullscan_grid_visits),
		tostring(last.grid_callbacks),
		tostring(last.duplicate_draws)
	)
	if #events > 0 then
		lines[#lines + 1] = string.format("  Recent events: %d (see Full Report)", #events)
	end
	return lines, s
end

return perf

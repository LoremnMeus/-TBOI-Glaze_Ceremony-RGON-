local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

-- GROW: Space Colonization 骨架 → WEAVE: 架桥+菌毯萌生 → COCOON: 增厚遮挡 Morph → HATCH: 破茧
-- 禁止 tip scoring；禁止用骨架填满；菌毯必须从菌丝密度/桥接生长。
local item = {
	myToCall = {},
	ToCall = {},
	entity = enums.Items.Glaze_Mushroom,
	own_key = "Item_Glaze_Mushroom_",
	anm2 = "gfx/mimics/Glaze_Mushroom/mushroom.anm2",
	growths = {},

	-- GROW / SC
	step = 1.35,
	kill_dist = 2.4,
	influence_radius = 14,
	dir_noise = 0.15,
	attractor_pedestal = 28,
	item_bands = 5,
	item_per_band_l = 3,
	item_per_band_m = 3,
	item_per_band_r = 3,
	item_per_band_extra = 4,
	end_remaining = 10,
	root_count = 3,
	item_pivot_y = -8,
	max_nodes = 280,
	growth_timeout = 100,

	-- WEAVE
	weave_frames = 14,
	bridge_min = 3,
	bridge_max = 8,
	bridge_max_per_node = 2,
	bridge_max_total = 40,
	mat_density_r = 5.5,
	mat_seed_min_density = 3,
	mat_seed_spacing = 4,
	mat_seed_target_lo = 8,
	mat_seed_target_hi = 14,

	-- MAT grid
	cell_size = 2,
	mat_x0 = -20,
	mat_x1 = 20,
	mat_y0 = -42,
	mat_y1 = 14,
	mat_expand = 3,
	mat_tick = 1,
	mat_base_chance = 0.18,
	mat_per_neighbor = 0.14,
	mat_hypha_bonus = 0.25,
	mat_thick0 = 0.15,
	mat_thick_base = 0.025,
	mat_thick_nei = 0.005,

	-- FUZZ：成熟菌毯边缘/表面短绒毛（不改 SC / bridge / mat 密度）
	fuzz_start_thickness = 0.30,
	fuzz_full_thickness = 0.80,
	fuzz_age_full = 8,
	fuzz_edge_chance_base = 0.15,
	fuzz_edge_chance_span = 0.40,
	fuzz_surface_chance = 0.08,
	fuzz_edge_len_min = 1.5,
	fuzz_edge_len_max = 3.5,
	fuzz_surface_len_min = 1.0,
	fuzz_surface_len_max = 2.2,
	fuzz_scale_min = 0.20,
	fuzz_scale_max = 0.30,
	fuzz_alpha_min = 0.20,
	fuzz_alpha_max = 0.48,
	fuzz_edge_angle_jit = 25,
	fuzz_surface_angle_jit = 55,
	fuzz_hypha_age = 6,
	fuzz_hypha_spacing_min = 4,
	fuzz_hypha_spacing_max = 6,
	fuzz_hypha_chance = 0.18,
	fuzz_hypha_len_min = 1.0,
	fuzz_hypha_len_max = 2.0,
	fuzz_hypha_alpha_mul = 0.42,

	-- COCOON
	cocoon_min = 10,
	cocoon_max = 24,
	cov_fade_start = 0.35,
	cov_heavy = 0.65,
	cov_morph = 0.78,
	morph_item_alpha = 0.12,

	-- HATCH：先顶部红白熟成，再自上而下散开
	hatch_blush_frames = 10,
	hatch_open_frames = 14,
	hatch_hypha_start = 8,
	hatch_hypha_frames = 14,
	hatch_total = 24,
	magic_mushroom_id = 12,

	pending_frame_slack = 2,
	texel_alpha = 0.10,
}

local function clamp(v, a, b)
	return math.max(a, math.min(b, v))
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function len2(x, y)
	return math.sqrt(x * x + y * y)
end

local function norm(x, y)
	local L = len2(x, y)
	if L < 1e-6 then return 0, -1 end
	return x / L, y / L
end

-- 白 texel 贴图：写 Tint/Offset 时强制清 Colorize，避免残留把灰绿洗成死白。
local function make_dot_color(r, g, b, a, ro, go, bo)
	local col = Color(r, g, b, a, ro or 0, go or 0, bo or 0)
	if col.SetColorize then
		col:SetColorize(0, 0, 0, 0)
	end
	return col
end

local function hypha_color(roll, alpha)
	if roll < 0.85 then
		return make_dot_color(0.85, 0.88, 0.80, alpha, 0.04, 0.05, 0.03)
	elseif roll < 0.95 then
		return make_dot_color(0.72, 0.92, 0.90, alpha, 0.03, 0.10, 0.10)
	end
	return make_dot_color(0.70, 0.82, 0.95, alpha, 0.04, 0.08, 0.14)
end

-- 贴图为纯白 texel：Tint+Offset 之和必须明显 < 1，否则绒毛会钳成死白盖住菌丝。
-- 比主体略亮、更透，禁止再用 0.96 Tint + 0.08 Offset。
local function fuzz_color(roll, alpha)
	local a = clamp(alpha or 0.3, 0, 1)
	roll = roll or 0.5
	if roll < 0.87 then
		return make_dot_color(0.90, 0.93, 0.88, a, 0.02, 0.025, 0.015)
	elseif roll < 0.97 then
		return make_dot_color(0.78, 0.94, 0.92, a, 0.015, 0.04, 0.035)
	end
	return make_dot_color(0.76, 0.86, 0.96, a, 0.02, 0.03, 0.05)
end

local function rot2(x, y, deg)
	local v = Vector(x, y):Rotated(deg)
	return v.X, v.Y
end

local function mat_color(thickness, age, alpha_mul, blush)
	local t = clamp(thickness or 0, 0, 1)
	blush = clamp(blush or 0, 0, 1)
	local a
	local r, g, b
	-- 基色：灰白菌毯
	if t < 0.35 then
		local u = t / 0.35
		r, g, b = lerp(0.72, 0.82, u), lerp(0.82, 0.89, u), lerp(0.77, 0.84, u)
		a = lerp(0.25, 0.4, u)
	elseif t < 0.65 then
		local u = (t - 0.35) / 0.3
		r, g, b = lerp(0.82, 0.92, u), lerp(0.89, 0.96, u), lerp(0.84, 0.91, u)
		a = lerp(0.55, 0.7, u)
	else
		local u = (t - 0.65) / 0.35
		r, g, b = lerp(0.92, 0.95, u), lerp(0.96, 0.98, u), lerp(0.91, 0.94, u)
		a = lerp(0.8, 0.95, u)
	end
	-- 红白熟成（大蘑菇配色）：白底 + 红斑
	if blush > 0.01 then
		local white_r, white_g, white_b = 0.96, 0.95, 0.93
		local red_r, red_g, red_b = 0.92, 0.22, 0.28
		local mottled = (((age or 0) * 17 + math.floor((thickness or 0) * 10)) % 5) < 2
		local tr, tg, tb = white_r, white_g, white_b
		if mottled then tr, tg, tb = red_r, red_g, red_b end
		r = lerp(r, tr, blush)
		g = lerp(g, tg, blush)
		b = lerp(b, tb, blush)
		a = lerp(a, mottled and 0.92 or 0.88, blush * 0.5)
	end
	if (age or 99) < 4 and blush < 0.2 then
		r, g, b = r + 0.08, g + 0.08, b + 0.06
		a = a + 0.06
	end
	a = a * (alpha_mul or 1)
	return make_dot_color(clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1), clamp(a, 0, 1), 0.03, 0.05, 0.04)
end

local function altar_geom(x, y)
	local nx = x / 22
	local ny = (y - 5) / 9
	return nx * nx + ny * ny <= 1.05
end

local function item_geom(x, y)
	local py = item.item_pivot_y
	if x < -16 or x > 16 or y < py - 32 or y > py + 1 then
		return false
	end
	local nx = x / 15.5
	local ny = (y - (py - 16)) / 16.5
	return nx * nx * 0.92 + ny * ny * 0.85 <= 1.08
end

local function texel_alpha(col)
	if not col then return 0 end
	local a = col.Alpha
	if a == nil then a = col.A end
	if a == nil then return 0 end
	if a > 1.01 then return a / 255 end
	return a
end

local function sample_mask(pickup, x, y, mode)
	local s = pickup and pickup:GetSprite()
	if s and s.GetTexel then
		local layers = (mode == "item") and {1} or {0, 5}
		for i = 1, #layers do
			local ok, col = pcall(function()
				return s:GetTexel(Vector(x, y), Vector(0, 0), 0.05, layers[i])
			end)
			if ok and texel_alpha(col) >= item.texel_alpha then
				return true
			end
		end
	end
	if mode == "item" then
		return item_geom(x, y)
	end
	return altar_geom(x, y)
end

local function current_room_index()
	local level = Game():GetLevel()
	if level and level.GetCurrentRoomIndex then
		return level:GetCurrentRoomIndex()
	end
	return -1
end

local function room_is_boss_ish()
	local room = Game():GetRoom()
	if not room then return false end
	local rt = room:GetType()
	return rt == RoomType.ROOM_BOSS
		or rt == RoomType.ROOM_BOSSRUSH
		or rt == RoomType.ROOM_MINIBOSS
end

local function clear_pending()
	save.elses[item.own_key.."pending"] = nil
end

local function set_pending(seed)
	save.elses[item.own_key.."pending"] = {
		roomIndex = current_room_index(),
		frame = Game():GetFrameCount(),
		seed = seed,
	}
end

local function pending_matches(_ent)
	local p = save.elses[item.own_key.."pending"]
	if type(p) ~= "table" then return false end
	if p.roomIndex ~= current_room_index() then return false end
	local now = Game():GetFrameCount()
	local pf = p.frame or -999
	local dt = now - pf
	if now < pf or dt > item.pending_frame_slack then return false end
	if not room_is_boss_ish() and dt > 1 then return false end
	return true
end

local function bind_state(pickup, st)
	if not pickup then return end
	local d = pickup:GetData()
	d[item.own_key.."growing"] = true
	d[item.own_key.."state"] = st
	st.pickup = pickup
	st.init_seed = pickup.InitSeed
	st.ptr = GetPtrHash(pickup)
	item.growths[st.ptr] = st
end

local function refresh_pickup(st)
	if auxi.check_all_exists(st.pickup) then
		local d = st.pickup:GetData()
		if d[item.own_key.."state"] ~= st then
			d[item.own_key.."state"] = st
			d[item.own_key.."growing"] = true
		end
		local nk = GetPtrHash(st.pickup)
		if st.ptr and st.ptr ~= nk then
			item.growths[st.ptr] = nil
			st.ptr = nk
			item.growths[nk] = st
		end
		return st.pickup
	end
	for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false, false)) do
		local d = e:GetData()
		if d[item.own_key.."state"] == st or (st.init_seed and e.InitSeed == st.init_seed) then
			bind_state(e, st)
			return e
		end
	end
	return nil
end

local function apply_pickup_alpha(st)
	local pickup = refresh_pickup(st)
	if not pickup then return end
	local spr = pickup:GetSprite()
	if not spr then return end
	local a = st.itemAlpha
	if a == nil then
		if st.phase == "HATCH" then
			a = st.newAlpha or 1
		elseif st.phase == "DONE" then
			a = 1
		else
			a = 1
		end
	end
	spr.Color = Color(1, 1, 1, clamp(a, 0, 1), 0, 0, 0)
end

local function try_sample_in_rect(pickup, mode, x0, x1, y0, y1, attempts)
	for _ = 1, attempts or 24 do
		local x = x0 + math.random() * (x1 - x0)
		local y = y0 + math.random() * (y1 - y0)
		if sample_mask(pickup, x, y, mode) then
			return x, y
		end
	end
	return x0 + (x1 - x0) * 0.5, y0 + (y1 - y0) * 0.5
end

local function build_attractors(st, pickup)
	st.attractors = {}
	for _ = 1, item.attractor_pedestal do
		local x, y = try_sample_in_rect(pickup, "pedestal", -20, 20, 2, 13, 30)
		st.attractors[#st.attractors + 1] = {x = x, y = y, reached = false}
	end
	-- 道具分带采样：保证左/中/右与各高度带都有点，避免 winner-takes-all
	local py = item.item_pivot_y
	local y_bot, y_top = py, py - 32
	for band = 1, item.item_bands do
		local t0 = (band - 1) / item.item_bands
		local t1 = band / item.item_bands
		local y0 = y_bot + (y_top - y_bot) * t0
		local y1 = y_bot + (y_top - y_bot) * t1
		local function add_n(xa, xb, n)
			for _ = 1, n do
				local x, y = try_sample_in_rect(pickup, "item", xa, xb, y1, y0, 28)
				st.attractors[#st.attractors + 1] = {x = x, y = y, reached = false}
			end
		end
		add_n(-16, -5.5, item.item_per_band_l)
		add_n(-5.5, 5.5, item.item_per_band_m)
		add_n(5.5, 16, item.item_per_band_r)
		add_n(-16, 16, item.item_per_band_extra)
	end
	st.remaining = #st.attractors
end

local function add_node(st, x, y, parent)
	local idx = #st.nodes + 1
	st.nodes[idx] = {x = x, y = y, parent = parent}
	if parent then
		local p = st.nodes[parent]
		local mid_y = (p.y + y) * 0.5
		st.segments[#st.segments + 1] = {
			ax = p.x, ay = p.y, bx = x, by = y,
			width = (math.random() < 0.3) and 2 or 1,
			bornFrame = st.frame,
			retractOrder = (-mid_y) + math.random() * 3,
			color_roll = math.random(),
			alive = true,
			progress = 1,
		}
	end
	return idx
end

local function spawn_roots(st, pickup)
	st.nodes = {}
	st.segments = {}
	for _ = 1, item.root_count do
		local x, y = try_sample_in_rect(pickup, "pedestal", -18, 18, 8, 13, 28)
		add_node(st, x, y, nil)
	end
end

local function count_remaining(st)
	local n = 0
	for i = 1, #st.attractors do
		if not st.attractors[i].reached then n = n + 1 end
	end
	st.remaining = n
	return n
end

local function space_colonize_step(st)
	local nodes = st.nodes
	if #nodes == 0 or #nodes >= item.max_nodes then return end
	for i = 1, #nodes do
		nodes[i].gx, nodes[i].gy, nodes[i].inf = 0, 0, 0
	end
	for ai = 1, #st.attractors do
		local att = st.attractors[ai]
		if not att.reached then
			local best_i, best_d = nil, 1e9
			for ni = 1, #nodes do
				local d = len2(att.x - nodes[ni].x, att.y - nodes[ni].y)
				if d < best_d then best_d, best_i = d, ni end
			end
			if best_i then
				if best_d < item.kill_dist then
					att.reached = true
				elseif best_d < item.influence_radius then
					local nd = nodes[best_i]
					local dx, dy = norm(att.x - nd.x, att.y - nd.y)
					nd.gx, nd.gy, nd.inf = nd.gx + dx, nd.gy + dy, nd.inf + 1
				end
			end
		end
	end
	local grown = {}
	for ni = 1, #nodes do
		local nd = nodes[ni]
		if nd.inf > 0 and #st.nodes + #grown < item.max_nodes then
			local dx, dy = norm(nd.gx / nd.inf, nd.gy / nd.inf)
			dx = dx + (math.random() * 2 - 1) * item.dir_noise
			dy = dy + (math.random() * 2 - 1) * item.dir_noise
			dx, dy = norm(dx, dy)
			grown[#grown + 1] = {x = nd.x + dx * item.step, y = nd.y + dy * item.step, parent = ni}
		end
	end
	if #grown == 0 and (st.remaining or 0) > item.end_remaining and #st.nodes < item.max_nodes then
		local best_att, best_node, best_d = nil, nil, 1e9
		for ai = 1, #st.attractors do
			local att = st.attractors[ai]
			if not att.reached then
				for ni = 1, #nodes do
					local d = len2(att.x - nodes[ni].x, att.y - nodes[ni].y)
					if d < best_d then best_d, best_att, best_node = d, att, ni end
				end
			end
		end
		if best_att and best_node then
			local nd = nodes[best_node]
			local dx, dy = norm(best_att.x - nd.x, best_att.y - nd.y)
			grown[1] = {x = nd.x + dx * item.step, y = nd.y + dy * item.step, parent = best_node}
		end
	end
	for i = 1, #grown do
		add_node(st, grown[i].x, grown[i].y, grown[i].parent)
	end
	count_remaining(st)
end

-- ---- Mat grid ----
local function cell_key(ix, iy)
	return ix * 4096 + iy
end

local function world_to_cell(x, y)
	local cs = item.cell_size
	local ix = math.floor((x - item.mat_x0) / cs)
	local iy = math.floor((y - item.mat_y0) / cs)
	return ix, iy
end

local function cell_to_world(ix, iy)
	local cs = item.cell_size
	return item.mat_x0 + (ix + 0.5) * cs, item.mat_y0 + (iy + 0.5) * cs
end

local function dist_to_hypha(st, x, y)
	local best = 1e9
	for i = 1, #st.nodes do
		local d = len2(x - st.nodes[i].x, y - st.nodes[i].y)
		if d < best then best = d end
	end
	for i = 1, #st.bridges do
		local br = st.bridges[i]
		local mx, my = (br.ax + br.bx) * 0.5, (br.ay + br.by) * 0.5
		local d = len2(x - mx, y - my)
		if d < best then best = d end
	end
	return best
end

local function init_mat_grid(st, _pickup)
	-- 几何判定即可：WEAVE 首帧禁止对 ~560 格 GetTexel（会造成明显卡顿）
	st.mat = {}
	st.mat_list = {}
	local cs = item.cell_size
	local w = math.floor((item.mat_x1 - item.mat_x0) / cs)
	local h = math.floor((item.mat_y1 - item.mat_y0) / cs)
	st.mat_w, st.mat_h = w, h
	local valid_item = 0
	for iy = 0, h - 1 do
		for ix = 0, w - 1 do
			local x, y = cell_to_world(ix, iy)
			local on_item = item_geom(x, y)
			local on_ped = altar_geom(x, y)
			local near_h = dist_to_hypha(st, x, y) <= item.mat_expand
			local valid = on_item or on_ped or near_h
			if not valid then
				for ox = -2, 2 do
					for oy = -2, 2 do
						if item_geom(x + ox, y + oy) then
							valid = true
							break
						end
					end
					if valid then break end
				end
			end
			if valid then
				local c = {
					ix = ix, iy = iy, x = x, y = y,
					occupied = false, thickness = 0, age = 0,
					front = math.random() < 0.35,
					variant = 1 + math.floor(math.random() * 4),
					jx = (math.random() - 0.5) * 0.8,
					jy = (math.random() - 0.5) * 0.8,
					blue = math.random() < 0.05,
					break_order = 0,
					blush = 0,
					alive = true,
				}
				st.mat[cell_key(ix, iy)] = c
				st.mat_list[#st.mat_list + 1] = c
				if on_item then
					valid_item = valid_item + 1
					c.is_item = true
				end
			end
		end
	end
	st.valid_item_cells = math.max(1, valid_item)
	st._mat_ready = true
end

local function node_density(st, ni)
	local a = st.nodes[ni]
	local n = 0
	for j = 1, #st.nodes do
		if j ~= ni and len2(a.x - st.nodes[j].x, a.y - st.nodes[j].y) <= item.mat_density_r then
			n = n + 1
		end
	end
	for i = 1, #st.bridges do
		local br = st.bridges[i]
		if (br.ai == ni or br.bi == ni) then n = n + 0.5 end
	end
	return n
end

local function plan_bridges(st, pickup)
	st.bridges = {}
	local counts = {}
	local pair = {}
	for i = 1, #st.nodes do counts[i] = 0 end
	local order = {}
	for i = 1, #st.nodes do order[i] = i end
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for oi = 1, #order do
		local ai = order[oi]
		if counts[ai] < item.bridge_max_per_node and #st.bridges < item.bridge_max_total then
			local A = st.nodes[ai]
			local cands = {}
			for bi = 1, #st.nodes do
				if bi ~= ai and counts[bi] < item.bridge_max_per_node then
					local B = st.nodes[bi]
					if A.parent ~= bi and B.parent ~= ai then
						local d = len2(A.x - B.x, A.y - B.y)
						if d > item.bridge_min and d < item.bridge_max then
							local pk = math.min(ai, bi) * 10000 + math.max(ai, bi)
							if not pair[pk] then
								local mx, my = (A.x + B.x) * 0.5, (A.y + B.y) * 0.5
								local ok = item_geom(mx, my) or altar_geom(mx, my)
									or dist_to_hypha(st, mx, my) <= 4
								if ok then
									cands[#cands + 1] = {bi = bi, d = d, pk = pk}
								end
							end
						end
					end
				end
			end
			table.sort(cands, function(u, v) return u.d < v.d end)
			for ci = 1, #cands do
				if counts[ai] >= item.bridge_max_per_node then break end
				if #st.bridges >= item.bridge_max_total then break end
				local c = cands[ci]
				local p = lerp(0.55, 0.15, (c.d - item.bridge_min) / (item.bridge_max - item.bridge_min))
				if math.random() < p then
					pair[c.pk] = true
					counts[ai] = counts[ai] + 1
					counts[c.bi] = counts[c.bi] + 1
					local B = st.nodes[c.bi]
					st.bridges[#st.bridges + 1] = {
						ai = ai, bi = c.bi,
						ax = A.x, ay = A.y, bx = B.x, by = B.y,
						progress = 0, delay = math.floor(math.random() * 4),
						color_roll = math.random(), alive = true,
						retractOrder = (-(A.y + B.y) * 0.5) + math.random() * 2,
					}
				end
			end
		end
		if #st.bridges >= item.bridge_max_total then break end
	end
end

local function plant_mat_seeds(st)
	local seeds = {}
	local ranked = {}
	for i = 1, #st.nodes do
		local dens = node_density(st, i)
		if dens >= item.mat_seed_min_density then
			ranked[#ranked + 1] = {i = i, dens = dens}
		end
	end
	table.sort(ranked, function(a, b) return a.dens > b.dens end)
	local target = item.mat_seed_target_lo + math.random(0, item.mat_seed_target_hi - item.mat_seed_target_lo)
	for r = 1, #ranked do
		if #seeds >= target then break end
		local nd = st.nodes[ranked[r].i]
		local ok = true
		for s = 1, #seeds do
			if len2(nd.x - seeds[s].x, nd.y - seeds[s].y) < item.mat_seed_spacing then
				ok = false
				break
			end
		end
		if ok then
			seeds[#seeds + 1] = {x = nd.x, y = nd.y}
			local ix, iy = world_to_cell(nd.x, nd.y)
			local c = st.mat[cell_key(ix, iy)]
			if c then
				c.occupied = true
				c.thickness = item.mat_thick0
				c.age = 0
				c.front = math.random() < 0.4
			end
		end
	end
	st.mat_seeds = seeds
end

local function mat_neighbors_occupied(st, ix, iy)
	local n = 0
	for dy = -1, 1 do
		for dx = -1, 1 do
			if not (dx == 0 and dy == 0) then
				local c = st.mat[cell_key(ix + dx, iy + dy)]
				if c and c.occupied then n = n + 1 end
			end
		end
	end
	return n
end

-- 空邻域（无 cell / 未 occupied）→ 外法向；禁止在 Render 里随机。
local function empty_outward(st, ix, iy)
	local ox, oy, empty = 0, 0, 0
	for dy = -1, 1 do
		for dx = -1, 1 do
			if not (dx == 0 and dy == 0) then
				local n = st.mat[cell_key(ix + dx, iy + dy)]
				if not n or not n.occupied then
					ox, oy = ox + dx, oy + dy
					empty = empty + 1
				end
			end
		end
	end
	return empty > 0, ox, oy
end

local function fuzz_strength(thickness)
	local a = item.fuzz_start_thickness
	local b = item.fuzz_full_thickness
	return clamp(((thickness or 0) - a) / math.max(1e-3, b - a), 0, 1)
end

local function make_fuzz_hair(dx, dy, len, front)
	local L = len2(dx, dy)
	if L < 1e-6 then dx, dy = 0, -1 else dx, dy = dx / L, dy / L end
	return {
		dx = dx,
		dy = dy,
		len = len,
		scale = item.fuzz_scale_min + math.random() * (item.fuzz_scale_max - item.fuzz_scale_min),
		alpha = item.fuzz_alpha_min + math.random() * (item.fuzz_alpha_max - item.fuzz_alpha_min),
		roll = math.random(),
		front = front and true or false,
	}
end

local function build_cell_fuzz(st, c)
	if c.fuzz ~= nil then return end
	if (c.thickness or 0) < item.fuzz_start_thickness then return end
	-- 等略成熟再烘焙，边缘概率随 thickness 升高，避免刚铺开就定死稀疏结果
	if (c.age or 0) < 4 and (c.thickness or 0) < 0.55 then return end
	local fs = fuzz_strength(c.thickness)
	local fuzz = {}
	local is_front = c.front or ((c.thickness or 0) > 0.45)
	local is_edge, ox, oy = empty_outward(st, c.ix, c.iy)
	if is_edge then
		local edge_chance = item.fuzz_edge_chance_base + fs * item.fuzz_edge_chance_span
		if math.random() < edge_chance then
			local nx, ny = norm(ox, oy)
			local jit = (math.random() * 2 - 1) * item.fuzz_edge_angle_jit
			nx, ny = rot2(nx, ny, jit)
			local len = item.fuzz_edge_len_min + math.random() * (item.fuzz_edge_len_max - item.fuzz_edge_len_min)
			fuzz[#fuzz + 1] = make_fuzz_hair(nx, ny, len, is_front)
		end
	end
	-- 气生菌丝：稀；仅较厚表面
	if (c.thickness or 0) > 0.45 then
		local surface_chance = fs * item.fuzz_surface_chance
		if math.random() < surface_chance then
			local sx = (math.random() * 2 - 1) * 0.6
			local sy = -0.2 - math.random() * 0.8
			local jit = (math.random() * 2 - 1) * item.fuzz_surface_angle_jit
			sx, sy = rot2(sx, sy, jit)
			local len = item.fuzz_surface_len_min + math.random() * (item.fuzz_surface_len_max - item.fuzz_surface_len_min)
			fuzz[#fuzz + 1] = make_fuzz_hair(sx, sy, len, true)
		end
	end
	c.fuzz = fuzz
end

local function ensure_all_mat_fuzz(st)
	for i = 1, #st.mat_list do
		local c = st.mat_list[i]
		if c.occupied and c.alive ~= false and c.fuzz == nil then
			build_cell_fuzz(st, c)
		end
	end
end

local function build_seg_fuzz(seg, st)
	if seg.fuzz ~= nil then return end
	local age = (st.frame or 0) - (seg.bornFrame or 0)
	if age < item.fuzz_hypha_age then return end
	local dx, dy = seg.bx - seg.ax, seg.by - seg.ay
	local dist = len2(dx, dy)
	local fuzz = {}
	if dist >= 1 then
		local ux, uy = dx / dist, dy / dist
		local nx, ny = -uy, ux
		local spacing = item.fuzz_hypha_spacing_min
			+ math.random() * (item.fuzz_hypha_spacing_max - item.fuzz_hypha_spacing_min)
		local t = spacing * 0.5
		while t < dist - 0.4 do
			if math.random() < item.fuzz_hypha_chance then
				local side = (math.random() < 0.5) and 1 or -1
				local jit = (math.random() * 2 - 1) * 20
				local fx, fy = rot2(nx * side, ny * side, jit)
				local len = item.fuzz_hypha_len_min
					+ math.random() * (item.fuzz_hypha_len_max - item.fuzz_hypha_len_min)
				fuzz[#fuzz + 1] = {
					x = seg.ax + ux * t,
					y = seg.ay + uy * t,
					dx = fx,
					dy = fy,
					len = len,
					scale = item.fuzz_scale_min + math.random() * 0.06,
					alpha = (item.fuzz_alpha_min + math.random() * 0.12) * (item.fuzz_hypha_alpha_mul or 0.42),
					roll = math.random(),
					from_hypha = true,
				}
			end
			t = t + spacing
		end
	end
	seg.fuzz = fuzz
end

local function ensure_all_seg_fuzz(st)
	for i = 1, #st.segments do
		local seg = st.segments[i]
		if seg.alive then
			build_seg_fuzz(seg, st)
		end
	end
end

local function tick_mat_spread(st)
	local infect = {}
	for i = 1, #st.mat_list do
		local c = st.mat_list[i]
		if not c.occupied then
			local nei = mat_neighbors_occupied(st, c.ix, c.iy)
			if nei >= 1 then
				local hypha = clamp((4 - dist_to_hypha(st, c.x, c.y)) / 4, 0, 1)
				local chance = item.mat_base_chance + nei * item.mat_per_neighbor + hypha * item.mat_hypha_bonus
				if math.random() < chance then
					infect[#infect + 1] = c
				end
			end
		else
			local nei = mat_neighbors_occupied(st, c.ix, c.iy)
			c.thickness = math.min(1, c.thickness + item.mat_thick_base + nei * item.mat_thick_nei)
			c.age = (c.age or 0) + 1
			if c.thickness > 0.45 and math.random() < 0.08 then
				c.front = true
			end
		end
	end
	for i = 1, #infect do
		local c = infect[i]
		c.occupied = true
		c.thickness = item.mat_thick0
		c.age = 0
		c.front = math.random() < (0.55 + c.thickness * 0.2)
	end
	ensure_all_mat_fuzz(st)
end

local function mat_coverage(st)
	local sum = 0
	for i = 1, #st.mat_list do
		local c = st.mat_list[i]
		if c.is_item and c.occupied then
			sum = sum + (c.thickness or 0)
		end
	end
	return sum / st.valid_item_cells
end

local function item_alpha_from_coverage(cov)
	if cov < item.cov_fade_start then
		return 1
	elseif cov < item.cov_heavy then
		local u = (cov - item.cov_fade_start) / (item.cov_heavy - item.cov_fade_start)
		return lerp(1, 0.55, u)
	else
		local u = clamp((cov - item.cov_heavy) / (1 - item.cov_heavy), 0, 1)
		return lerp(0.55, 0.06, u)
	end
end

local function force_thicken_mat(st)
	for i = 1, #st.mat_list do
		local c = st.mat_list[i]
		if c.is_item and dist_to_hypha(st, c.x, c.y) <= 6 then
			c.occupied = true
			c.thickness = math.max(c.thickness, 0.55)
			c.front = true
		end
	end
	ensure_all_mat_fuzz(st)
end

local function prepare_hatch_orders(st)
	-- 顶部（y 更小）先散开
	for i = 1, #st.mat_list do
		local c = st.mat_list[i]
		c.break_order = c.y + math.random() * 2.5
	end
end

local function silent_morph_to_mushroom(pickup)
	local p = pickup:ToPickup()
	if not p then return end
	-- 底座道具本身没有 Appear/AppearFast；静默换装 = Morph，不自播音效
	p:Morph(5, 100, item.magic_mushroom_id, true, true, true)
end

local function do_morph(st)
	local pickup = refresh_pickup(st)
	if not pickup or st.morphed then return end
	st.morphed = true
	silent_morph_to_mushroom(pickup)
	refresh_pickup(st)
	if auxi.check_all_exists(st.pickup) then
		bind_state(st.pickup, st)
		st.newAlpha = 0.04
		st.itemAlpha = 0.04
		apply_pickup_alpha(st)
	end
end

local function begin_weave(st, pickup)
	st.phase = "WEAVE"
	st.phase_age = 0
	-- 网格若已在 GROW 末预热则跳过；否则本帧只建几何网格（无 GetTexel）
	if not st._mat_ready then
		init_mat_grid(st, pickup)
	end
	plan_bridges(st, pickup)
	plant_mat_seeds(st)
	st.itemAlpha = 1
	st.mat_alpha = 1
	-- 立刻扩散一拍，避免“织网前空等”
	tick_mat_spread(st)
end

local function begin_cocoon(st)
	st.phase = "COCOON"
	st.phase_age = 0
end

local function begin_hatch(st)
	st.phase = "HATCH"
	st.phase_age = 0
	st.hatch_sub = "blush" -- blush → open
	prepare_hatch_orders(st)
	if not st.morphed then do_morph(st) end
	st.newAlpha = 0.04
	st.itemAlpha = 0.04
	local orders = {}
	for i = 1, #st.segments do orders[#orders + 1] = st.segments[i].retractOrder end
	for i = 1, #st.bridges do orders[#orders + 1] = st.bridges[i].retractOrder or 0 end
	table.sort(orders, function(a, b) return a > b end)
	st._hypha_retract = orders
end

local function start_growth(pickup)
	local d = pickup:GetData()
	if d[item.own_key.."state"] then return end
	local key = GetPtrHash(pickup)
	if item.growths[key] then return end
	local st = {
		pickup = pickup,
		init_seed = pickup.InitSeed,
		ptr = key,
		phase = "GROW",
		frame = 0,
		phase_age = 0,
		nodes = {},
		segments = {},
		bridges = {},
		attractors = {},
		remaining = 0,
		mat = {},
		mat_list = {},
		itemAlpha = 1,
		newAlpha = 0,
		mat_alpha = 1,
		morphed = false,
		missing_frames = 0,
		mycelium_alpha = 1,
	}
	bind_state(pickup, st)
	build_attractors(st, pickup)
	spawn_roots(st, pickup)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MUSHROOM_POOF, 0.7, 1.1, false, 0, 2)
end

local function tick_bridges(st)
	for i = 1, #st.bridges do
		local br = st.bridges[i]
		if br.alive and st.phase_age >= (br.delay or 0) then
			br.progress = math.min(1, (br.progress or 0) + 0.18)
		end
	end
end

local function tick_growth(st)
	local pickup = refresh_pickup(st)
	if not pickup then
		st.missing_frames = (st.missing_frames or 0) + 1
		return st.missing_frames < 45
	end
	st.missing_frames = 0
	st.frame = st.frame + 1
	st.phase_age = (st.phase_age or 0) + 1

	if st.phase == "GROW" then
		space_colonize_step(st)
		ensure_all_seg_fuzz(st)
		local rem = st.remaining or count_remaining(st)
		-- GROW 末尾预热菌毯网格，避免切入 WEAVE 时单帧卡顿
		if (not st._mat_ready) and rem <= item.end_remaining + 18 then
			init_mat_grid(st, pickup)
		end
		if rem <= item.end_remaining or st.frame >= item.growth_timeout or #st.nodes >= item.max_nodes then
			begin_weave(st, pickup)
		end
		st.itemAlpha = 1
		apply_pickup_alpha(st)
		return true
	end

	if st.phase == "WEAVE" then
		tick_bridges(st)
		tick_mat_spread(st)
		ensure_all_seg_fuzz(st)
		st.itemAlpha = math.max(0.9, st.itemAlpha or 1)
		apply_pickup_alpha(st)
		if st.phase_age >= item.weave_frames then
			begin_cocoon(st)
		end
		return true
	end

	if st.phase == "COCOON" then
		tick_mat_spread(st)
		for i = 1, #st.mat_list do
			local c = st.mat_list[i]
			if c.occupied then
				c.thickness = math.min(1, c.thickness + 0.02)
				if c.thickness > 0.45 then c.front = true end
			end
		end
		ensure_all_mat_fuzz(st)
		local cov = mat_coverage(st)
		st.coverage = cov
		st.itemAlpha = item_alpha_from_coverage(cov)
		if st.phase_age >= item.cocoon_max then
			force_thicken_mat(st)
			cov = mat_coverage(st)
			st.coverage = cov
			st.itemAlpha = math.min(st.itemAlpha, 0.08)
		end
		apply_pickup_alpha(st)
		if (not st.morphed) and cov >= item.cov_morph and st.itemAlpha <= item.morph_item_alpha then
			do_morph(st)
		end
		if st.morphed and st.phase_age >= item.cocoon_min then
			begin_hatch(st)
		elseif st.phase_age >= item.cocoon_max then
			if not st.morphed then do_morph(st) end
			begin_hatch(st)
		end
		return true
	end

	if st.phase == "HATCH" then
		local blush_n = math.max(1, item.hatch_blush_frames)
		local open_n = math.max(1, item.hatch_open_frames)
		if (st.hatch_sub or "blush") == "blush" then
			local wave = clamp(st.phase_age / blush_n, 0, 1)
			local span = math.max(1e-3, item.mat_y1 - item.mat_y0)
			for i = 1, #st.mat_list do
				local c = st.mat_list[i]
				if c.occupied then
					-- y 小 = 顶部，先变红白
					local topness = clamp((item.mat_y1 - c.y) / span, 0, 1)
					c.blush = clamp((wave - (1 - topness) * 0.9) / 0.28, 0, 1)
				end
			end
			st.itemAlpha = 0.04
			st.newAlpha = 0.04
			st.mat_alpha = 1
			apply_pickup_alpha(st)
			if st.phase_age >= blush_n then
				st.hatch_sub = "open"
				st.phase_age = 0
			end
			return true
		end

		-- open：自上而下散开，露出内部大蘑菇
		local t = clamp(st.phase_age / open_n, 0, 1)
		st.newAlpha = lerp(0.04, 1, t)
		st.itemAlpha = st.newAlpha
		local orders = {}
		for i = 1, #st.mat_list do
			if st.mat_list[i].occupied then
				orders[#orders + 1] = st.mat_list[i].break_order
			end
		end
		table.sort(orders) -- 小 y（顶部）先
		local n_kill = math.floor(t * #orders)
		if n_kill > 0 and #orders > 0 then
			local cutoff = orders[math.min(n_kill, #orders)]
			for i = 1, #st.mat_list do
				local c = st.mat_list[i]
				if c.occupied and c.break_order <= cutoff then
					c.alive = false
					c.occupied = false
					c.thickness = 0
				end
			end
		end
		st.mat_alpha = 1 - t * 0.9
		local absolute_age = blush_n + st.phase_age
		if absolute_age >= item.hatch_hypha_start then
			local ht = clamp((absolute_age - item.hatch_hypha_start) / item.hatch_hypha_frames, 0, 1)
			st.mycelium_alpha = 1 - ht
			local hy = st._hypha_retract or {}
			local nk = math.floor(ht * #hy)
			if nk > 0 and #hy > 0 then
				local cut = hy[math.min(nk, #hy)]
				for i = 1, #st.segments do
					if st.segments[i].retractOrder >= cut then st.segments[i].alive = false end
				end
				for i = 1, #st.bridges do
					if (st.bridges[i].retractOrder or 0) >= cut then st.bridges[i].alive = false end
				end
			end
		end
		apply_pickup_alpha(st)
		if st.phase_age >= open_n then
			st.phase = "DONE"
			st.itemAlpha = 1
			st.mat_alpha = 0
			st.mycelium_alpha = 0
			apply_pickup_alpha(st)
			return false
		end
		return true
	end

	return false
end

local function ensure_dot(cache, key, anim)
	local spr = cache[key]
	if not spr then
		spr = Sprite()
		spr:Load(item.anm2, true)
		spr:Play(anim, true)
		cache[key] = spr
	end
	return spr
end

local function render_seg_line(ax, ay, bx, by, origin, alpha, width, roll, spr_cache, progress)
	progress = progress == nil and 1 or progress
	if progress <= 0.02 or alpha <= 0.02 then return end
	local ex = lerp(ax, bx, progress)
	local ey = lerp(ay, by, progress)
	local dx, dy = ex - ax, ey - ay
	local dist = len2(dx, dy)
	if dist < 0.01 then return end
	local steps = math.max(1, math.floor(dist / 1.35))
	local spr = ensure_dot(spr_cache, width >= 2 and "Dot2" or "Dot1", width >= 2 and "Dot2" or "Dot1")
	local sc = (width >= 2) and 0.75 or 0.5
	spr.Scale = Vector(sc, sc)
	spr.Color = hypha_color(roll or 0.5, alpha)
	for i = 0, steps do
		local u = i / steps
		spr:Render(origin + Vector(lerp(ax, ex, u), lerp(ay, ey, u)), Vector(0, 0), Vector(0, 0))
	end
end

-- 2–4 个极小 Dot1 构成短绒毛；数据固定，Render 不随机。
local function render_fuzz_line(ox, oy, dx, dy, len, origin, alpha, scale, roll, spr_cache, from_hypha)
	if len < 0.35 or alpha < 0.04 then return end
	local L = len2(dx, dy)
	if L < 1e-6 then dx, dy = 0, -1 else dx, dy = dx / L, dy / L end
	local bx, by = ox + dx * len, oy + dy * len
	local steps = math.max(2, math.min(4, math.floor(len / 0.9) + 1))
	local spr = ensure_dot(spr_cache, "fuzzDot", "Dot1")
	spr.Scale = Vector(scale or 0.25, scale or 0.25)
	-- 主菌丝侧毛跟菌丝同色系，避免最早长出的骨架被死白绒毛盖住
	if from_hypha then
		spr.Color = hypha_color(roll or 0.5, alpha)
	else
		spr.Color = fuzz_color(roll or 0.5, alpha)
	end
	for i = 0, steps do
		local u = i / steps
		spr:Render(origin + Vector(lerp(ox, bx, u), lerp(oy, by, u)), Vector(0, 0), Vector(0, 0))
	end
end

local function render_mat_fuzz_layer(st, origin, front_only, spr_cache)
	local alpha_mul = st.mat_alpha or 1
	if alpha_mul <= 0.02 then return end
	for i = 1, #st.mat_list do
		local c = st.mat_list[i]
		local fuzz = c.fuzz
		if fuzz and c.occupied and c.alive ~= false and (c.thickness or 0) >= item.fuzz_start_thickness then
			local age_f = clamp((c.age or 0) / item.fuzz_age_full, 0, 1)
			if age_f > 0.05 then
				local thick_f = 0.55 + 0.45 * fuzz_strength(c.thickness)
				for fi = 1, #fuzz do
					local h = fuzz[fi]
					local is_front = h.front
					if (front_only and is_front) or ((not front_only) and (not is_front)) then
						local len = h.len * age_f * thick_f
						local a = h.alpha * alpha_mul * (0.7 + 0.3 * age_f)
						render_fuzz_line(
							c.x + (c.jx or 0), c.y + (c.jy or 0),
							h.dx, h.dy, len, origin, a, h.scale, h.roll, spr_cache, false
						)
					end
				end
			end
		end
	end
end

local function render_mat_layer(st, origin, front_only, spr_cache)
	local alpha_mul = st.mat_alpha or 1
	if alpha_mul <= 0.02 then return end
	for i = 1, #st.mat_list do
		local c = st.mat_list[i]
		if c.occupied and c.alive ~= false and (c.thickness or 0) > 0.05 then
			local is_front = c.front or ((c.thickness or 0) > 0.45)
			if (front_only and is_front) or ((not front_only) and (not is_front)) then
				local spr = ensure_dot(spr_cache, "mat"..tostring(c.variant), (c.variant % 2 == 0) and "Dot2" or "Dot1")
				local sc = 0.45 + (c.thickness or 0) * 0.55
				local sx, sy = sc, sc
				if c.variant == 2 then sx = sx * 1.2 end
				if c.variant == 3 then sy = sy * 1.25; sx = sx * 0.85 end
				if c.variant == 4 then sx = sx * 1.15; sy = sy * 1.15 end
				spr.Scale = Vector(sx, sy)
				local col = mat_color(c.thickness, c.age, alpha_mul, c.blush or 0)
				if c.blue and (c.blush or 0) < 0.35 then
					local ca = col.A
					if ca == nil then ca = col.Alpha end
					col = make_dot_color(0.7, 0.84, 0.95, ca or 0.7, 0.04, 0.08, 0.12)
				end
				spr.Color = col
				spr:Render(origin + Vector(c.x + c.jx, c.y + c.jy), Vector(0, 0), Vector(0, 0))
			end
		end
	end
end

local function render_hyphae(st, origin, spr_cache)
	local alpha = st.mycelium_alpha or 1
	for i = 1, #st.segments do
		local seg = st.segments[i]
		if seg.alive then
			render_seg_line(seg.ax, seg.ay, seg.bx, seg.by, origin, alpha, seg.width, seg.color_roll, spr_cache, 1)
			local fuzz = seg.fuzz
			if fuzz then
				for fi = 1, #fuzz do
					local h = fuzz[fi]
					render_fuzz_line(h.x, h.y, h.dx, h.dy, h.len, origin, h.alpha * alpha * 0.85, h.scale, h.roll, spr_cache, true)
				end
			end
		end
	end
	for i = 1, #st.bridges do
		local br = st.bridges[i]
		if br.alive then
			render_seg_line(br.ax, br.ay, br.bx, br.by, origin, alpha * 0.85, 1, br.color_roll, spr_cache, br.progress or 0)
		end
	end
end

local function render_pass(st, offset, back)
	local pickup = refresh_pickup(st)
	if not pickup then return end
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	offset = offset or Vector(0, 0)
	local origin = Isaac.WorldToScreen(pickup.Position) + offset - Game():GetRoom():GetRenderScrollOffset()
	st._spr_cache = st._spr_cache or {}
	if back then
		render_mat_layer(st, origin, false, st._spr_cache)
		render_mat_fuzz_layer(st, origin, false, st._spr_cache)
	else
		render_hyphae(st, origin, st._spr_cache)
		render_mat_layer(st, origin, true, st._spr_cache)
		render_mat_fuzz_layer(st, origin, true, st._spr_cache)
	end
end

local function find_state(ent)
	local d = ent:GetData()
	if d[item.own_key.."state"] then return d[item.own_key.."state"] end
	local st = item.growths[GetPtrHash(ent)]
	if st then return st end
	for _, cand in pairs(item.growths) do
		if cand.init_seed == ent.InitSeed then return cand end
	end
	return nil
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil,
Function = function(_, pool, decrease, seed)
	if auxi.have_player_has_collectible(item.entity)
		and (not auxi.have_player_has_collectible(12))
		and pool == ItemPoolType.POOL_BOSS
		and (save.elses[item.own_key.."effect"] ~= true)
		and Game():GetFrameCount() > 5
	then
		local rng = RNG()
		rng:SetSeed(seed, 0)
		rng = auxi.rng_for_sake(rng)
		if rng:RandomInt(5) == 1 and decrease == true then
			save.elses[item.own_key.."effect"] = true
			set_pending(seed)
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 100,
Function = function(_, ent)
	if ent.SubType == 12 then
		for _, cand in pairs(item.growths) do
			if cand.morphed and cand.init_seed == ent.InitSeed then
				bind_state(ent, cand)
				return
			end
		end
		return
	end
	if type(save.elses[item.own_key.."pending"]) ~= "table" then return end
	if ent.Variant ~= 100 or ent.SubType <= 0 then return end
	if not pending_matches(ent) then
		clear_pending()
		return
	end
	clear_pending()
	start_growth(ent)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local dead = {}
	for key, st in pairs(item.growths) do
		if not tick_growth(st) then
			dead[#dead + 1] = st.ptr or key
			local p = st.pickup
			if auxi.check_all_exists(p) then
				local d = p:GetData()
				d[item.own_key.."growing"] = nil
				d[item.own_key.."state"] = nil
				local spr = p:GetSprite()
				if spr then spr.Color = Color(1, 1, 1, 1, 0, 0, 0) end
			end
		end
	end
	for i = 1, #dead do item.growths[dead[i]] = nil end
end,
})

-- 背层菌毯（道具 sprite 之前）
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PICKUP_RENDER, params = 100,
Function = function(_, ent, offset)
	local st = find_state(ent)
	if not st then return end
	st.pickup = ent
	render_pass(st, offset, true)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = 100,
Function = function(_, ent, offset)
	local st = find_state(ent)
	if not st then return end
	st.pickup = ent
	render_pass(st, offset, false)
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."effect"] = nil
		clear_pending()
	end
	item.growths = {}
end,
})

return item

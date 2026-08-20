-- Generated from codex_work/logs/tear_color_audit.json (schema v2).
-- Layout: Tint RGBA, Offset RGB, Colorize RGBA. Runtime data must stay publishable.
local M = {}

M.DATA = {
	[3]={0.400,0.150,0.380,1, 0.278,0,0.455, 0,0,0,0}, [6]={1,1,0,1, 0.176,0.059,0, 0,0,0,0},
	[69]={0.330,0.180,0.180,1, 0.259,0.157,0.157, 0,0,0,0}, [89]={2,2,2,1, 0.196,0.196,0.196, 0,0,0,0},
	[103]={0.400,0.970,0.500,1, 0,0,0, 0,0,0,0}, [104]={0.900,0.300,0.080,1, 0,0,0, 0,0,0,0},
	[110]={1.250,0.050,0.150,1, 0,0,0, 0,0,0,0}, [115]={1.5,2,2,0.5, 0,0,0, 0,0,0,0},
	[132]={0.200,0.090,0.065,1, 0,0,0, 0,0,0,0}, [149]={0.5,0.9,0.4,1, 0,0,0, 0,0,0,0},
	[159]={1.5,2,2,0.5, 0,0,0, 0,0,0,0}, [182]={1.5,2,2,1, 0,0,0, 0,0,0,0},
	[185]={1.5,2,2,0.5, 0,0,0, 0,0,0,0}, [200]={1,0,1,1, 0.196,0,0, 0,0,0,0},
	[201]={0.5,0.5,0.5,1, 0,0,0, 0,0,0,0}, [221]={1,1,0.8,1, 0.1,0.1,0.1, 0,0,0,0},
	[228]={1,1,0.455,1, 0.169,0.145,0, 0,0,0,0}, [230]={0.392,0.392,0.392,1, 0,0,0, 0,0,0,0},
	[231]={0.15,0.15,0.15,1, 0,0,0, 0,0,0,0}, [257]={1,1,1,1, 0.3,0,0, 1.8,0.9,0.3,1},
	[259]={1,1,1,1, 0,0,0, 0.3,0.3,0.3,1}, [305]={0.196,1,0.196,1, 0,0,0, 0,0,0,0},
	[310]={0.2,0.2,0.2,1, 0,0,0, 0,0,0,0}, [317]={1,1,1,1, 0,0.2,0, 0.2,1,0.2,1},
	[330]={1.5,2,2,1, 0,0,0, 0,0,0,0}, [336]={0.5,0.25,0.1,0.9, 0,0,0, 0,0,0,0},
	[393]={0.5,0.97,0.5,1, 0,0,0, 0,0,0,0}, [463]={1,1,0.1,1, 0,0,0, 0,0,0,0},
	[503]={0,0,0,1, 0,0,0, 0,0,0,0}, [561]={1.8,1.7,1,1, 0,0,0, 0,0,0,0},
	[572]={1,1,1,1, 0,0,0, 0.3,0,0.25,1}, [606]={0,0,0,1, 0,0,0, 0,0,0,0},
	[617]={1,1,1,1, 0,0,0, 0.5,0.5,0.5,1}, [618]={0.7,0.14,0.1,1, 0.3,0,0, 0,0,0,0},
}

M.DATA[570] = {
	{1,1,1,1, 0,0,0, 0.3,0.4,1,1.5}, {1,1,1,1, 0,0,0, 0.4,0.7,1,1.5},
	{1,1,1,1, 0,0,0, 0.4,0.8,0.5,1.5}, {1,1,1,1, 0,0,0, 0.7,0.6,0.4,1.5},
	{1,1,1,1, 0,0,0, 0.8,0.9,0.1,1.5}, {1,1,1,1, 0,0,0, 0.9,0.2,0.2,1.5},
	{1,1,1,1, 0,0,0, 1,0.4,0.2,1.5}, {1,1,1,1, 0,0,0, 1,0.4,0.7,1.5},
	{1,1,1,1, 0,0,0, 1,0.4,1.2,1.5},
}

local ORDER = {}
for id in pairs(M.DATA) do ORDER[#ORDER + 1] = id end
table.sort(ORDER)

local function flag_is_present(flags, flag)
	if not flag then return true end
	local ok, found = pcall(function() return (flags & flag) == flag end)
	return ok and found
end

local function make_color(v)
	return Color(v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8],v[9],v[10],v[11])
end

function M.resolve(counts, flags, init_seed, tear_effects)
	local selected
	for _, id in ipairs(ORDER) do
		if (counts and counts[id] or 0) > 0 then
			local effect = tear_effects and tear_effects[id]
			if not effect or flag_is_present(flags, effect.flag) then selected = id end
		end
	end
	if not selected then return nil end
	local value = M.DATA[selected]
	if selected == 570 then
		local index = ((tonumber(init_seed) or 0) % #value) + 1
		value = value[index]
	end
	return make_color(value), selected
end

function M.apply(ent, counts, flags, tear_effects)
	if not ent then return nil end
	local color, source = M.resolve(counts, flags, ent.InitSeed, tear_effects)
	-- 无配方染色时强制回默认，避免玩家吐根绿等污染 FireTear 结果。
	if not color then
		color = Color(1, 1, 1, 1, 0, 0, 0)
		source = nil
	end
	ent.Color = color
	local ok, spr = pcall(function() return ent:GetSprite() end)
	if ok and spr then spr.Color = color end
	return source
end

return M

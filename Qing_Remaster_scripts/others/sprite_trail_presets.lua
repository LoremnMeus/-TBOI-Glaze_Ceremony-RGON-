-- 可复用 SpriteTrail 预设（运行时 helper）。
-- 小型档：半径/Scale/位移来自 Psy Fly 探针；手挂拖尾须自写 Colorize（不吃 Parent Null）。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	TRAIL_VARIANT = EffectVariant.SPRITE_TRAIL or 166,
}

--- 小型拖尾
--- 探针（原版引擎拖尾）：Effect Tint 白、Colorize 0，紫靠 Parent anm2 Null。
--- 手挂拖尾：引擎不会用 Parent Null 上色 → 必须自写 Colorize（Null RGB 210,100,255）。
item.SMALL = {
	id = "small",
	label = "小型拖尾",
	source = "psy_fly_vanilla_probe v3 + manual Colorize (anm2 Null)",
	min_radius = 0.12,
	max_radius = 0.12,
	scale = 0.6,
	local_offset = { x = 0, y = -15 },
	color = { r = 1, g = 1, b = 1, a = 1, ro = 0, go = 0, bo = 0 },
	-- anm2 Null Tint → 手挂时的 Colorize（Amount=1）
	colorize = { r = 210 / 255, g = 100 / 255, b = 1, a = 1 },
	--- 每帧重涂色：Parent 挂接不会带来 Null 紫，且可能冲掉 Colorize
	reapply_color_each_sync = true,
}

local function color_from_preset(preset)
	local c = (preset and preset.color) or item.SMALL.color
	local col = Color(
		tonumber(c.r) or 1,
		tonumber(c.g) or 1,
		tonumber(c.b) or 1,
		tonumber(c.a) or 1,
		tonumber(c.ro) or 0,
		tonumber(c.go) or 0,
		tonumber(c.bo) or 0
	)
	local cz = preset and preset.colorize
	if cz and col.SetColorize then
		col:SetColorize(
			tonumber(cz.r) or 0,
			tonumber(cz.g) or 0,
			tonumber(cz.b) or 0,
			tonumber(cz.a) or 1
		)
	end
	return col
end

local function apply_trail_color(trail, preset)
	if not trail then return end
	local col = color_from_preset(preset)
	trail:SetColor(col, -1, 0)
	local spr = trail.GetSprite and trail:GetSprite()
	if spr then
		spr.Color = col
	end
end

local function sample_pos(ent, preset)
	local po = ent.PositionOffset or Vector.Zero
	local lo = (preset and preset.local_offset) or item.SMALL.local_offset or { x = 0, y = 0 }
	return ent.Position + po + Vector(tonumber(lo.x) or 0, tonumber(lo.y) or 0)
end

--- 同步拖尾：必须在实体 PositionOffset 写好之后调用。
--- 手挂拖尾不吃 Parent anm2 Null，靠 preset.colorize；每帧可重涂。
function item.sync(ent, store, key, preset)
	if not ent or not store or not key then return nil end
	preset = preset or item.SMALL
	local sample = sample_pos(ent, preset)
	local trail = store[key]
	local fresh = false
	if not auxi.check_all_exists(trail) then
		trail = Isaac.Spawn(EntityType.ENTITY_EFFECT, item.TRAIL_VARIANT, 0, sample, Vector.Zero, ent)
		trail = trail and trail:ToEffect()
		if not trail then return nil end
		trail.MinRadius = tonumber(preset.min_radius) or 0.12
		trail.MaxRadius = tonumber(preset.max_radius) or trail.MinRadius
		local sc = tonumber(preset.scale) or 0.6
		trail.SpriteScale = Vector(sc, sc)
		store[key] = trail
		fresh = true
	end
	trail.Parent = ent
	trail.Position = sample
	trail.Velocity = Vector.Zero
	if fresh or preset.reapply_color_each_sync ~= false then
		apply_trail_color(trail, preset)
	end
	return trail
end

function item.clear(store, key)
	if not store or not key then return end
	local trail = store[key]
	if auxi.check_all_exists(trail) then
		trail:Remove()
	end
	store[key] = nil
end

return item

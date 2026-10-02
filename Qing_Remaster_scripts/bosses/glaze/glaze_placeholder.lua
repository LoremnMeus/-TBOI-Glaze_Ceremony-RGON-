-- Visual-only Tears; never player attacks. Warning paths remain visible with labels disabled.
local M = {labels = true}
local function valid(e) return e and e:Exists() end

function M.spawn(ctx, kind, pos, opts)
	opts = opts or {}
	local tear = Isaac.Spawn(EntityType.ENTITY_TEAR, 0, 0, pos, Vector.Zero, ctx.boss):ToTear()
	tear.CollisionDamage = 0
	tear.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	tear.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	tear.CanTriggerStreakEnd = false
	tear.TearFlags = BitSet128(0, 0)
	tear.Height, tear.FallingSpeed, tear.FallingAcceleration = -10, 0, 0
	local data = tear:GetData()
	data.glaze_placeholder = true
	data.glaze_placeholder_label = opts.label or kind
	ctx.serial = ctx.serial + 1
	local obj = {id = ctx.serial, entity = tear, kind = kind, position = pos,
		lifetime = opts.lifetime or 300, direction = opts.direction or Vector(0, 1)}
	ctx.objects[obj.id] = obj
	return obj
end

function M.move(obj, pos)
	obj.position = pos
	if valid(obj.entity) then obj.entity.Position = pos; obj.entity.Velocity = Vector.Zero end
end

function M.label(obj, text)
	if valid(obj.entity) then obj.entity:GetData().glaze_placeholder_label = text end
end

function M.remove(ctx, obj)
	if not obj then return end
	if valid(obj.entity) then obj.entity:Remove() end
	ctx.objects[obj.id] = nil
end

function M.line(ctx, a, b, lifetime, label)
	ctx.warnings[#ctx.warnings + 1] = {a = a, b = b, lifetime = lifetime, label = label}
end

function M.tick(ctx)
	for id, obj in pairs(ctx.objects) do
		obj.lifetime = obj.lifetime - 1
		if obj.lifetime <= 0 or not valid(obj.entity) then M.remove(ctx, obj)
		else
			local e = obj.entity
			e.CollisionDamage = 0
			e.EntityCollisionClass, e.GridCollisionClass = 0, 0
			e.Height, e.FallingSpeed, e.FallingAcceleration = -10, 0, 0
			e.CanTriggerStreakEnd = false
			e.Velocity = Vector.Zero
		end
	end
	for i = #ctx.warnings, 1, -1 do
		ctx.warnings[i].lifetime = ctx.warnings[i].lifetime - 1
		if ctx.warnings[i].lifetime <= 0 then table.remove(ctx.warnings, i) end
	end
end

function M.render(ctx)
	for _, w in ipairs(ctx.warnings) do
		local a, b = Isaac.WorldToScreen(w.a), Isaac.WorldToScreen(w.b)
		if Isaac.DrawLine then Isaac.DrawLine(a, b, KColor(.4, .9, 1, .85), KColor(1, .6, .4, .85), 2)
		else
			local steps = math.max(1, math.floor(a:Distance(b) / 10))
			for i = 0, steps do local p = a + (b - a) * (i / steps); Isaac.RenderText(".", p.X, p.Y, .4, .9, 1, .9) end
		end
		if M.labels and w.label then Isaac.RenderText(w.label, a.X, a.Y - 12, 1, 1, 1, 1) end
	end
	if not M.labels then return end
	for _, obj in pairs(ctx.objects) do
		if valid(obj.entity) then
			local p = Isaac.WorldToScreen(obj.entity.Position)
			Isaac.RenderText("[" .. obj.entity:GetData().glaze_placeholder_label .. "]", p.X - 25, p.Y - 18, .7, 1, 1, 1)
		end
	end
end

function M.clear(ctx)
	for _, obj in pairs(ctx.objects) do if valid(obj.entity) then obj.entity:Remove() end end
	ctx.objects, ctx.warnings = {}, {}
end

return M

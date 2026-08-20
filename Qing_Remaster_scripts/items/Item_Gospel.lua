local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local tear_trigger_holder = require("Qing_Remaster_scripts.callbacks.tear_trigger_holder")

local item = {
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Gospel,
	own_key = "Item_Gospel_",
	tear_every = 4,
	tear_damage_mul = 0.75,
	halo_fade = 0.14,
	orbit_tears = 3,
	spread_radius = 200,
	preach_need_mul = 2.5,
	preach_mul = 1.0,
	revelation_mul = 1.5,
	death_spread = 2,
	boss_revelation_need_mul = 8.0,
	dark_revelation_mul = 0.75,
	judgement_need = 6,
	judgement_mul = 2.0,
	judgement_delay = 12,
	preach_burst_cap = 8,
}
auxi.add_to_seija(item.entity)

local skip_hurt_flags = DamageFlag.DAMAGE_FAKE | DamageFlag.DAMAGE_CLONES
local halo_spr = Sprite()
halo_spr:Load("gfx/effects/Halo/Halo_godhead_ring.anm2", true)
halo_spr:Play("Idle", true)
local tear_spr = Sprite()
tear_spr:Load("gfx/mimics/Gospel/Gospel_Tear.anm2", true)
tear_spr:Play("Idle", true)
local head_helper = Sprite()
head_helper:Load("gfx/mimics/Gospel/gospel_head_helper.anm2", true)
head_helper:Play("Idle", true)
local halo_update_frame = -1
local head_layer_cache = {}
local scalp_cache = {}
local halo_pos_cache = {}
local halo_pos_tick = -1
local lingering_halos = {}

local HEAD_LAYER_NAMES = {
	"head", "skull", "face", "brain", "hair", "helmet", "hat", "top", "main", "body",
}
local HEAD_LAYER_IGNORE = {
	"glow", "shadow", "dirt", "hole", "effect", "fx", "particle",
	"darkness", "ray", "wing", "halo", "rag", "rope", "noose",
}

local function size_radius(ent)
	local multi = ent.SizeMulti or Vector(1, 1)
	return ent.Size * (0.5 * ((multi.X or 1) + (multi.Y or 1)))
end

local function layer_name_ignored(name)
	for i = 1, #HEAD_LAYER_IGNORE do
		if string.find(name, HEAD_LAYER_IGNORE[i], 1, true) then
			return true
		end
	end
	return false
end

local function layer_name_priority(name)
	local best = 9999
	for i = 1, #HEAD_LAYER_NAMES do
		if string.find(name, HEAD_LAYER_NAMES[i], 1, true) and i < best then
			best = i
		end
	end
	return best
end

local function is_layer_valid(sprite, layer_id, ignore_state, ignore_overlay)
	local layer_state = sprite:GetLayer(layer_id)
	if not layer_state then return false, false end
	if not ignore_state and layer_state.IsVisible and not layer_state:IsVisible() then
		return false, false
	end
	local overlay_name = sprite.GetOverlayAnimation and sprite:GetOverlayAnimation() or ""
	for pass = 1, 2 do
		local use_overlay = pass == 2
		if use_overlay and (ignore_overlay or overlay_name == "") then
		else
			local anim_data
			if use_overlay then
				anim_data = sprite.GetOverlayAnimationData and sprite:GetOverlayAnimationData()
			else
				anim_data = sprite.GetCurrentAnimationData and sprite:GetCurrentAnimationData()
			end
			local layer_data = anim_data and anim_data.GetLayer and anim_data:GetLayer(layer_id)
			if layer_data and layer_data.IsVisible and layer_data:IsVisible() then
				local frame_id = 0
				if use_overlay then
					frame_id = sprite.GetOverlayFrame and sprite:GetOverlayFrame() or 0
				else
					frame_id = sprite.GetFrame and sprite:GetFrame() or 0
				end
				local frame_data = layer_data.GetFrame and layer_data:GetFrame(frame_id)
				if frame_data and frame_data.IsVisible and frame_data:IsVisible() then
					return true, use_overlay
				end
			end
		end
	end
	return false, false
end

local function get_head_layer(sprite)
	if not sprite or not sprite.GetLayerCount or not sprite.GetLayer then return nil, false end
	local overlay_name = sprite.GetOverlayAnimation and sprite:GetOverlayAnimation() or ""
	local anim_name = sprite.GetAnimation and sprite:GetAnimation() or ""
	local key = (sprite:GetFilename() or "") .. "|" .. overlay_name .. "|" .. anim_name
	if not head_layer_cache[key] then
		local ranked = {}
		for layer_id = 0, sprite:GetLayerCount() - 1 do
			local ok = is_layer_valid(sprite, layer_id, true, false)
			if ok then
				local layer_state = sprite:GetLayer(layer_id)
				local name = string.lower(layer_state and layer_state.GetName and layer_state:GetName() or "")
				if not layer_name_ignored(name) then
					ranked[#ranked + 1] = {
						id = layer_id,
						priority = layer_name_priority(name) + layer_id * 0.01,
					}
				end
			end
		end
		table.sort(ranked, function(a, b)
			return a.priority < b.priority
		end)
		head_layer_cache[key] = ranked
	end
	local ranked = head_layer_cache[key]
	for i = 1, #ranked do
		local ok, from_overlay = is_layer_valid(sprite, ranked[i].id, false, false)
		if ok then
			return ranked[i].id, from_overlay
		end
	end
	return nil, false
end

local function scan_scalp_y(sprite, layer_id, frame_data, layer_state)
	if not frame_data or not layer_state or not head_helper.GetTexel then return nil end
	local crop = frame_data:GetCrop()
	if layer_state.GetCropOffset then
		crop = crop + layer_state:GetCropOffset()
	end
	local size = Vector(frame_data:GetWidth(), frame_data:GetHeight())
	if size.X < 2 or size.Y < 2 then return nil end
	size = Vector(math.min(size.X, 512), math.min(size.Y, 512))
	local sheet = layer_state.GetSpritesheetPath and layer_state:GetSpritesheetPath() or ""
	local key = sheet .. "|" .. crop.X .. "|" .. crop.Y .. "|" .. size.X .. "|" .. size.Y
	if scalp_cache[key] ~= nil then
		return scalp_cache[key]
	end
	if sheet == "" then return nil end
	local replaced = pcall(function()
		head_helper:ReplaceSpritesheet(0, sheet, true)
	end)
	if not replaced then
		head_helper:ReplaceSpritesheet(0, sheet)
		if head_helper.LoadGraphics then
			head_helper:LoadGraphics()
		end
	end
	if head_helper.GetLayer then
		local helper_layer = head_helper:GetLayer(0)
		if helper_layer and helper_layer.SetCropOffset then
			helper_layer:SetCropOffset(crop)
		end
	end
	head_helper.FlipY = false
	local image = sprite.GetSpritesheet and sprite:GetSpritesheet(layer_id)
	local distances = {size.Y, 10, 5, 1}
	local start_x = size.X * 0.5
	local start_y = 0
	local found = nil
	for i = 1, #distances - 1 do
		local span = distances[i]
		local step = distances[i + 1]
		local hit = false
		for j = 0, span, step do
			local sample = Vector(start_x, start_y + j)
			local ok, texel = pcall(function()
				return head_helper:GetTexel(sample, Vector.Zero, 0.1)
			end)
			if ok and texel and (texel.Alpha or 0) > 0 then
				local sheet_pos = Vector(crop.X + start_x, crop.Y + start_y + j)
				if image and image.GetWidth and (
					sheet_pos.X < 0 or sheet_pos.X > image:GetWidth()
					or sheet_pos.Y < 0 or sheet_pos.Y > image:GetHeight()
				) then
				else
					if i == #distances - 1 then
						found = start_y + j
					else
						start_y = math.max(0, start_y + j - step)
						hit = true
					end
					break
				end
			end
		end
		if found then break end
		if not hit then break end
	end
	scalp_cache[key] = found
	return found
end

local function lock_head_layer(sprite, data, layer_id, from_overlay)
	if not data then return layer_id, from_overlay end
	if data.head_layer == nil then
		data.head_layer = layer_id
		data.head_overlay = from_overlay
		data.head_pending = nil
		data.head_pending_n = 0
		return layer_id, from_overlay
	end
	if not layer_id then
		return data.head_layer, data.head_overlay
	end
	if data.head_layer == layer_id and data.head_overlay == from_overlay then
		data.head_pending = nil
		data.head_pending_n = 0
		return data.head_layer, data.head_overlay
	end
	local pend = tostring(layer_id).."|"..tostring(from_overlay)
	if data.head_pending ~= pend then
		data.head_pending = pend
		data.head_pending_n = 1
		return data.head_layer, data.head_overlay
	end
	data.head_pending_n = (data.head_pending_n or 0) + 1
	if data.head_pending_n >= 2 then
		data.head_layer = layer_id
		data.head_overlay = from_overlay
		data.head_pending = nil
		data.head_pending_n = 0
	end
	return data.head_layer, data.head_overlay
end

local function filter_vec2(prev, cur)
	if not prev then return cur end
	return Vector((prev.X + cur.X) * 0.5, (prev.Y + cur.Y) * 0.5)
end

local function entity_po(ent)
	local po = ent and ent.PositionOffset
	if not po then return Vector(0, 0) end
	return Vector(po.X, po.Y)
end

local function visual_pos(ent)
	if not ent then return Vector(0, 0) end
	return ent.Position
end

local function head_halo_local(ent, data)
	local sprite = ent:GetSprite()
	if not sprite then return Vector(0, -(size_radius(ent) * 0.55)) end
	local layer_id, from_overlay = get_head_layer(sprite)
	layer_id, from_overlay = lock_head_layer(sprite, data, layer_id, from_overlay)
	if not layer_id or not sprite.GetLayerFrameData then
		return Vector(0, -(size_radius(ent) * 0.55))
	end
	local frame_data
	if from_overlay and sprite.GetOverlayLayerFrameData then
		frame_data = sprite:GetOverlayLayerFrameData(layer_id)
	else
		frame_data = sprite:GetLayerFrameData(layer_id)
	end
	local layer_state = sprite:GetLayer(layer_id)
	if not frame_data or not layer_state then
		return Vector(0, -(size_radius(ent) * 0.55))
	end
	local width = frame_data:GetWidth()
	local height = frame_data:GetHeight()
	local scalp = scan_scalp_y(sprite, layer_id, frame_data, layer_state)
	if not scalp then
		scalp = height * 0.15
	end
	local remain = math.max(0, height - scalp)
	local halo_y = scalp + math.min(remain * 0.38, math.max(8, height * 0.22))
	local scale_multi = frame_data:GetScale()
	if layer_state.GetSize then
		scale_multi = scale_multi * layer_state:GetSize()
	end
	local rotation = frame_data:GetRotation()
	if layer_state.GetRotation then
		rotation = rotation + layer_state:GetRotation()
	end
	local base = frame_data:GetPos()
	if layer_state.GetPos then
		base = base + layer_state:GetPos()
	end
	local pivot = (frame_data:GetPivot() * scale_multi):Rotated(rotation)
	local halo_off = Vector(width * scale_multi.X * 0.5, halo_y * scale_multi.Y):Rotated(rotation)
	local local_off = base - pivot + halo_off
	local spr_scale = sprite.Scale or Vector(1, 1)
	local_off = Vector(local_off.X * spr_scale.X, local_off.Y * spr_scale.Y)
	if sprite.FlipX then local_off = Vector(-local_off.X, local_off.Y) end
	if sprite.FlipY then local_off = Vector(local_off.X, -local_off.Y) end
	if (sprite.Rotation or 0) ~= 0 then
		local_off = local_off:Rotated(sprite.Rotation)
	end
	if sprite.Offset then
		local_off = local_off + sprite.Offset
	end
	return local_off
end

local function halo_screen_pos(ent, offset, data)
	local tick = Isaac.GetFrameCount()
	if halo_pos_tick ~= tick then
		halo_pos_cache = {}
		halo_pos_tick = tick
	end
	local hash = GetPtrHash(ent)
	local cached = halo_pos_cache[hash]
	if cached then return cached end
	offset = offset or Vector(0, 0)
	local po = entity_po(ent)
	local world = ent.Position + po
	local pos = Isaac.WorldToScreen(world) + offset
	local room = Game():GetRoom()
	if room and room.GetRenderScrollOffset then
		pos = pos - room:GetRenderScrollOffset()
	end
	local head_off = (data and data.halo_off) or head_halo_local(ent, data)
	pos = pos + head_off
	halo_pos_cache[hash] = pos
	return pos
end

local function follow_halo(ent, data)
	if not ent or not data then return end
	local raw = head_halo_local(ent, data)
	data.halo_off = filter_vec2(data.halo_off, raw)
end

local function halo_scale_for(ent)
	local r = size_radius(ent)
	return math.max(0.26, math.min(1.25, 0.16 + r * 0.028))
end

local function fade_color(col, vis)
	vis = math.max(0, math.min(1, vis or 1))
	local c = Color(col.R, col.G, col.B, (col.A or 1) * vis, col.RO or 0, col.GO or 0, col.BO or 0)
	if col.GetColorize and c.SetColorize then
		local z = col:GetColorize()
		c:SetColorize(z.R, z.G, z.B, z.A)
	end
	return c
end

local function tick_halo_vis(data, target)
	if not data then return 0 end
	data.vis = data.vis or 0
	data.vis = data.vis + (target - data.vis) * item.halo_fade
	if target <= 0 and data.vis < 0.02 then
		data.vis = 0
	elseif target >= 1 and data.vis > 0.98 then
		data.vis = 1
	end
	return data.vis
end

local function render_halo_at(pos, scale, col)
	if (col.A or 1) < 0.02 or scale < 0.02 then return end
	halo_spr.Rotation = 0
	halo_spr.Color = col
	halo_spr.Scale = Vector(scale * 1.18, scale * 1.18)
	halo_spr:Render(pos, Vector(0, 0), Vector(0, 0))
	halo_spr.Scale = Vector(scale * 0.78, scale * 0.78)
	halo_spr:Render(pos, Vector(0, 0), Vector(0, 0))
	halo_spr.Scale = Vector(1, 1)
	halo_spr.Color = Color(1, 1, 1, 1)
end

local function render_orbiters(center, scale, col, vis, tear_col)
	if vis < 0.02 then return end
	local radius = 40 * scale
	local frame = Game():GetFrameCount()
	local small = scale * 0.4
	local tear_scale = math.max(0.28, scale * 0.7)
	for i = 1, item.orbit_tears do
		local ang = frame * 4 + (i - 1) * 120
		local pos = center + auxi.MakeVector(ang) * radius
		render_halo_at(pos, small, fade_color(col, vis))
		tear_spr.Color = tear_col
		tear_spr.Scale = Vector(tear_scale, tear_scale)
		tear_spr.Rotation = 0
		tear_spr:Render(pos, Vector(0, 0), Vector(0, 0))
	end
	tear_spr.Scale = Vector(1, 1)
	tear_spr.Rotation = 0
	tear_spr.Color = Color(1, 1, 1, 1)
end

local function render_halo_stack(ent, offset, col, vis, data)
	local pos = halo_screen_pos(ent, offset, data)
	local base_scale = halo_scale_for(ent)
	render_halo_at(pos, base_scale, fade_color(col, vis))
	return pos, base_scale
end

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

function item.force_seija()
	local debug = debug_root()
	return debug and debug.GospelForceSeija == true
end

function item.is_seija(player)
	if item.force_seija() then return true end
	return player and auxi.should_do_Seija(player) == true
end

local function room_state()
	item.room = item.room or {revelations = 0, judgement = false}
	return item.room
end

local function gospel_data(npc)
	if not npc then return nil end
	return npc:GetData()[item.own_key]
end

local function gold_color(alpha, dark)
	alpha = alpha or 1
	local col = Color(1, 1, 1, alpha, dark and 0 or 0.18, dark and 0 or 0.12, dark and 0.04 or 0)
	if col.SetColorize then
		if dark then col:SetColorize(0.18, 0.08, 0.32, 1)
		else col:SetColorize(1.15, 0.92, 0.32, 1) end
	end
	return col
end

local function style_gospel_tear(tear, params)
	if not tear then return end
	params = params or {}
	local d = tear:GetData()
	local s = tear:GetSprite()
	d.is_gospel_tear = true
	if params.extra then
		d.Ignore_me_flag = true
		d.ignore_field = true
	end
	s:Load("gfx/mimics/Gospel/Gospel_Tear.anm2", true)
	s:Play("Idle2", true)
	s.Color = gold_color(1, false)
	s.Scale = Vector(1.12, 1.12)
	if params.boost and not d.gospel_boosted then
		tear.CollisionDamage = tear.CollisionDamage * (1 + item.tear_damage_mul)
		d.gospel_boosted = true
	end
	if params.damage then
		tear.CollisionDamage = params.damage
	end
end

function item.fire_gospel(player, pos, vel)
	if not player or not player.FireTear then return nil end
	vel = vel or Vector(0, 0)
	if vel:Length() < 0.05 then
		local dir = auxi.ggdir(player, true, true)
		if dir:Length() < 0.05 then return nil end
		vel = dir:Resized(player.ShotSpeed * 10)
	end
	pos = pos or player.Position
	item.spawning_gospel = true
	local tear = player:FireTear(pos, vel, false, true, false, player, item.tear_damage_mul)
	item.spawning_gospel = false
	if not tear then return nil end
	style_gospel_tear(tear, {
		extra = true,
		damage = (player.Damage or 3.5) * item.tear_damage_mul,
	})
	return tear
end

local function spawn_light(player, pos, dmg_mul, dark, po)
	player = player or auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
	pos = pos or player.Position
	local sub = dark and 2 or 0
	local q = Isaac.Spawn(1000, EffectVariant.CRACK_THE_SKY, sub, pos, Vector(0, 0), player):ToEffect()
	q.CollisionDamage = (player.Damage or 3.5) * (dmg_mul or item.revelation_mul)
	if po then
		q.PositionOffset = po
	end
	local d = q:GetData()
	d[item.own_key.."revelation"] = true
	d[item.own_key.."dark"] = dark and true or false
	if dark then
		q:GetSprite().Color = gold_color(1, true)
	end
	sound_tracker.PlayStackedSound(dark and SoundEffect.SOUND_HOLY or SoundEffect.SOUND_ANGEL_BEAM, 1, 1, false, 0, 2)
	return q
end

local function is_boss(ent)
	local npc = ent and ent.ToNPC and ent:ToNPC()
	return npc and npc.IsBoss and npc:IsBoss() == true
end

local function has_gospel(ent)
	local data = gospel_data(ent)
	return data ~= nil and data.fading ~= true
end

local function play_spread_beam(from_ent, to_ent, player, dark)
	if not from_ent or not to_ent then return end
	local from_pos = visual_pos(from_ent)
	local to_pos = visual_pos(to_ent)
	local delta = to_pos - from_pos
	if delta:Length() < 1 then return end
	local laser = Isaac.Spawn(EntityType.ENTITY_LASER, LaserVariant.LIGHT_BEAM, 0, from_pos, Vector(0, 0), player):ToLaser()
	laser.Angle = delta:GetAngleDegrees()
	laser.MaxDistance = delta:Length()
	local po_a = entity_po(from_ent)
	local po_b = entity_po(to_ent)
	laser.PositionOffset = Vector((po_a.X + po_b.X) * 0.5, (po_a.Y + po_b.Y) * 0.5)
	laser:SetTimeout(6)
	laser.CollisionDamage = 0
	laser.SpriteScale = Vector(0.55, 0.55)
	laser.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	laser.GridCollisionClass = GridCollisionClass.COLLISION_NONE
	laser:GetSprite().Color = gold_color(0.85, dark)
	laser:GetData()[item.own_key.."beam"] = true
end

local function find_spread_targets(source, count)
	count = count or 1
	local pos = source.Position
	local blocked = {[GetPtrHash(source)] = true}
	local list = {}
	for _ = 1, count do
		local target = auxi.get_by_nearest_enemy(pos, function(ent)
			if blocked[GetPtrHash(ent)] then return false end
			if (ent.Position - pos):Length() > item.spread_radius then return false end
			if has_gospel(ent) then return false end
			return true
		end)
		if not target then break end
		list[#list + 1] = target
		blocked[GetPtrHash(target)] = true
	end
	return list
end

local function clear_gospel(npc)
	if not npc then return end
	npc:GetData()[item.own_key] = nil
end

local function apply_gospel(npc, player)
	if not auxi.isenemies(npc) then return end
	local d = npc:GetData()
	local data = d[item.own_key]
	if type(data) ~= "table" then
		data = {preach_dmg = 0, boss_dmg = 0, vis = 0}
		d[item.own_key] = data
	end
	data.fading = nil
	if player then data.owner = player end
end

local function trigger_judgement(player)
	local room = room_state()
	if room.judgement then return end
	room.judgement = true
	local dark = item.is_seija(player)
	Game():ShakeScreen(18)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SUPERHOLY, 1, 1, false, 0, 2)
	local marks = {}
	for _, ent in pairs(auxi.getenemies()) do
		if has_gospel(ent) then
			marks[#marks + 1] = {seed = ent.InitSeed, pos = Vector(ent.Position.X, ent.Position.Y), po = entity_po(ent)}
			local mark = Isaac.Spawn(1000, EffectVariant.TARGET, 0, ent.Position, Vector(0, 0), player):ToEffect()
			if mark then
				mark:GetSprite().Color = gold_color(0.9, dark)
				mark.PositionOffset = entity_po(ent)
				mark:GetData()[item.own_key.."mark"] = true
			end
		end
	end
	delay_buffer.addeffe(function()
		for i = 1, #marks do
			local info = marks[i]
			local living = nil
			for _, ent in pairs(auxi.getenemies()) do
				if ent.InitSeed == info.seed then
					living = ent
					break
				end
			end
			spawn_light(player, living and living.Position or info.pos, item.judgement_mul, dark, living and entity_po(living) or info.po)
		end
	end, {}, item.judgement_delay)
end

local function trigger_revelation(player, pos, po)
	local dark = item.is_seija(player)
	spawn_light(player, pos, dark and item.dark_revelation_mul or item.revelation_mul, dark, po)
	local room = room_state()
	if room.judgement then return end
	room.revelations = (room.revelations or 0) + 1
	if room.revelations >= item.judgement_need then
		trigger_judgement(player)
	end
end

local function preach(npc, player)
	if not npc or not player then return false end
	if item.is_seija(player) then
		spawn_light(player, npc.Position, item.dark_revelation_mul, true, entity_po(npc))
		return true
	end
	local targets = find_spread_targets(npc, 1)
	local target = targets[1]
	if not target then return false end
	apply_gospel(target, player)
	play_spread_beam(npc, target, player, false)
	target:TakeDamage((player.Damage or 3.5) * item.preach_mul, 0, EntityRef(player), 0)
	return true
end

local function spread_on_death(npc, player)
	if item.is_seija(player) then return end
	local targets = find_spread_targets(npc, item.death_spread)
	for i = 1, #targets do
		apply_gospel(targets[i], player)
		play_spread_beam(npc, targets[i], player, false)
	end
end

local function on_gospel_damage(npc, amount, player)
	local data = gospel_data(npc)
	if not data or data.fading then return end
	player = player or data.owner
	if not player then return end
	local atk = player.Damage or 3.5
	data.preach_dmg = (data.preach_dmg or 0) + amount
	local preach_need = atk * item.preach_need_mul
	local n = 0
	while data.preach_dmg >= preach_need and n < item.preach_burst_cap do
		if not preach(npc, player) then break end
		data.preach_dmg = data.preach_dmg - preach_need
		n = n + 1
	end
	if not is_boss(npc) then return end
	data.boss_dmg = (data.boss_dmg or 0) + amount
	local boss_need = atk * item.boss_revelation_need_mul
	n = 0
	while data.boss_dmg >= boss_need and n < item.preach_burst_cap do
		data.boss_dmg = data.boss_dmg - boss_need
		trigger_revelation(player, npc.Position, entity_po(npc))
		n = n + 1
	end
end

local function source_is_revelation(source)
	local ent = source and source.Entity
	if not ent then return false end
	local d = ent:GetData()
	return d and d[item.own_key.."revelation"] == true
end

local function source_player(source)
	local ent = source and source.Entity
	if not ent then return nil end
	return auxi.check_spawner_player(ent)
end

local function source_applies_gospel(source)
	local ent = source and source.Entity
	if not ent then return false, nil end
	local d = ent:GetData()
	if d and d.is_gospel_tear then
		return true, auxi.check_spawner_player(ent)
	end
	if ent.Type == EntityType.ENTITY_FAMILIAR
		and ent.Variant == FamiliarVariant.ABYSS_LOCUST
		and ent.SubType == item.entity then
		return true, auxi.check_spawner_player(ent)
	end
	return false, nil
end

local function push_linger(npc, data)
	if not npc or not data then return end
	lingering_halos[#lingering_halos + 1] = {
		pos = Vector(npc.Position.X, npc.Position.Y),
		po = entity_po(npc),
		off = data.halo_off and Vector(data.halo_off.X, data.halo_off.Y) or Vector(0, 0),
		vis = math.max(data.vis or 0, 0.35),
		scale = halo_scale_for(npc),
		dark = item.is_seija(data.owner),
	}
end

local function on_gospel_killed(npc)
	local data = gospel_data(npc)
	if not data or data.done then return end
	data.done = true
	data.fading = true
	follow_halo(npc, data)
	push_linger(npc, data)
	local player = data.owner or auxi.have_player_has_collectible(item.entity)
	local pos = npc.Position
	local po = entity_po(npc)
	clear_gospel(npc)
	if player then
		spread_on_death(npc, player)
		trigger_revelation(player, pos, po)
	end
end

local function tear_screen_pos(ent, offset)
	offset = offset or Vector(0, 0)
	local po = ent.PositionOffset or Vector(0, 0)
	local pos = Isaac.WorldToScreen(ent.Position + po)
	pos = pos + offset
	local room = Game():GetRoom()
	if room and room.GetRenderScrollOffset then
		pos = pos - room:GetRenderScrollOffset()
	end
	return pos
end

local function tear_halo_scale(ent)
	return math.max(0.22, math.min(0.55, 0.28 * (ent.Scale or 1)))
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_FIRE_TRIGGER, params = nil,
Function = function(_, tp, ent, pos, player, dir, rate)
	if item.spawning_gospel then return end
	if not player or not auxi.has_have_coll(player, item.entity) then return end
	if tear_trigger_holder.should_ignore_trigger(ent) then return end
	if not tear_trigger_holder.framecheck(tp, ent, player, {Update = true,
		["Dr."] = {frame = 1, banished = true},
		["Dr. Explode"] = {frame = 1},
		["Brim"] = {frame = 5},
		["BrimFire"] = {frame = 1, banished = true},
	}) then return end
	local pd = player:GetData()
	pd[item.own_key.."shots"] = (pd[item.own_key.."shots"] or 0) + 1
	if pd[item.own_key.."shots"] < item.tear_every then return end
	pd[item.own_key.."shots"] = 0
	if ent and ent.Type == EntityType.ENTITY_TEAR then
		local td = ent:GetData()
		if not td.is_gospel_tear then
			style_gospel_tear(ent, {boost = true})
			return
		end
	end
	local mulinfo = tear_trigger_holder.multi_check(tp, ent, player)
	local rounded = mulinfo.rounded
	if dir == nil or dir:Length() < 0.01 then rounded = true end
	local ddir = tear_trigger_holder.dir_info_check(tp, ent, dir)
	for i = 1, mulinfo.cnt or 1 do
		local tdir = tear_trigger_holder.dir_info_check(tp, ent, dir)
		if rounded then tdir = auxi.get_by_rotate(ddir, i * 360 / math.max(1, mulinfo.cnt)) end
		item.fire_gospel(player, pos or (ent and ent.Position), tdir * player.ShotSpeed * 10)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_, ent)
	local d = ent:GetData()
	if not d.is_gospel_tear then return end
	local s = ent:GetSprite()
	if not s:IsPlaying("Idle2") then s:Play("Idle2", false) end
	s.Rotation = s.Rotation + 3
	s.Color = gold_color(1, false)
end,
})

if ModCallbacks.MC_PRE_TEAR_RENDER then
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_RENDER, params = nil,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local d = ent:GetData()
	if not d.is_gospel_tear then return end
	local vis = math.min(1, (ent.FrameCount or 0) / 8)
	if vis < 0.02 then return end
	local dark = false
	local player = auxi.check_spawner_player(ent)
	if player then dark = item.is_seija(player) end
	local col = dark and gold_color(0.95, true) or Color(1, 1, 1, 1)
	local scale = tear_halo_scale(ent)
	render_halo_at(tear_screen_pos(ent, offset), scale, fade_color(col, vis))
end,
})
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_TEAR_RENDER, params = nil,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local d = ent:GetData()
	if not d.is_gospel_tear then return end
	local vis = math.min(1, (ent.FrameCount or 0) / 8)
	if vis < 0.02 then return end
	local dark = false
	local player = auxi.check_spawner_player(ent)
	if player then dark = item.is_seija(player) end
	local col = dark and gold_color(0.95, true) or Color(1, 1, 1, 1)
	local scale = tear_halo_scale(ent)
	if not ModCallbacks.MC_PRE_TEAR_RENDER then
		render_halo_at(tear_screen_pos(ent, offset), scale, fade_color(col, vis))
	end
	render_orbiters(tear_screen_pos(ent, offset), scale, col, vis, gold_color(0.85 * vis, dark))
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_, tear, col, low)
	local d = tear:GetData()
	if not d.is_gospel_tear then return end
	if not auxi.isenemies(col) then return end
	local player = auxi.check_spawner_player(tear)
	apply_gospel(col, player)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_, ent, amount, flags, source, countdown)
	if not auxi.isenemies(ent) then return end
	if (amount or 0) <= 0 then return end
	if (flags & skip_hurt_flags) ~= 0 then return end
	if source_is_revelation(source) then return end
	local applies, gplayer = source_applies_gospel(source)
	local player = gplayer or source_player(source)
	if applies then
		apply_gospel(ent, player)
	end
	local data = gospel_data(ent)
	if not data then return end
	player = player or data.owner
	if not player then return end
	if applies then return end
	on_gospel_damage(ent, amount, player)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = nil,
Function = function(_, npc)
	on_gospel_killed(npc)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_, ent)
	local npc = ent and ent.ToNPC and ent:ToNPC()
	if npc then on_gospel_killed(npc) end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_UPDATE, params = nil,
Function = function(_, npc)
	local data = gospel_data(npc)
	if not data then return end
	follow_halo(npc, data)
	local vis = tick_halo_vis(data, data.fading and 0 or 1)
	if data.fading and vis <= 0 then
		clear_gospel(npc)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	local frame = Game():GetFrameCount()
	if halo_update_frame ~= frame and Game():IsPaused() == false then
		halo_spr:Update()
		halo_update_frame = frame
	end
	for i = #lingering_halos, 1, -1 do
		local linger = lingering_halos[i]
		if tick_halo_vis(linger, 0) <= 0 then
			table.remove(lingering_halos, i)
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	item.room = {revelations = 0, judgement = false}
	head_layer_cache = {}
	scalp_cache = {}
	halo_pos_cache = {}
	lingering_halos = {}
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_NPC_RENDER, params = nil,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local data = gospel_data(ent)
	if not data then return end
	offset = offset or Vector(0, 0)
	local vis = data.vis or 0
	if vis <= 0 then return end
	if not data.halo_off then
		data.halo_off = head_halo_local(ent, data)
	end
	local dark = item.is_seija(data.owner)
	local col = dark and gold_color(0.95, true) or Color(1, 1, 1, 1)
	render_halo_stack(ent, offset, col, vis, data)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_, ent, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local data = gospel_data(ent)
	if not data then return end
	local vis = data.vis or 0
	if vis <= 0 then return end
	offset = offset or Vector(0, 0)
	local dark = item.is_seija(data.owner)
	local col = dark and gold_color(0.95, true) or Color(1, 1, 1, 1)
	local halo_pos = halo_screen_pos(ent, offset, data)
	local scale = halo_scale_for(ent)
	render_orbiters(halo_pos, scale, col, vis, gold_color(0.85 * vis, dark))
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function()
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	for i = 1, #lingering_halos do
		local linger = lingering_halos[i]
		local vis = linger.vis or 0
		if vis > 0 then
			local pos = Isaac.WorldToScreen(linger.pos + linger.po) + linger.off
			local col = linger.dark and gold_color(0.95, true) or Color(1, 1, 1, 1)
			render_halo_at(pos, linger.scale, fade_color(col, vis))
			render_orbiters(pos, linger.scale, col, vis, gold_color(0.85 * vis, linger.dark))
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_, ent)
	if ent.SubType ~= item.entity then return end
	local d = ent:GetData()
	if (d[item.own_key.."counter"] or 0) > 0 then
		d[item.own_key.."counter"] = d[item.own_key.."counter"] - 1
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_, ent, col, low)
	if ent.SubType ~= item.entity then return end
	if not auxi.isenemies(col) then return end
	if ent.State ~= -1 then return end
	local d = ent:GetData()
	if (d[item.own_key.."counter"] or 0) > 0 then return end
	d[item.own_key.."counter"] = 18
	local player = auxi.check_spawner_player(ent)
	apply_gospel(col, player)
end,
})

return item

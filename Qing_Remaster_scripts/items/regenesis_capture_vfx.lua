-- Regenesis capture VFX: screen-space loss icons fly into the Regenesis familiar.
-- Presentation only. Does not own stored/dormant/progress/save.
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local slot_offer_lift = require("Qing_Remaster_scripts.slots.slot_offer_lift")

local item = {
	ToCall = {},
	myToCall = {},
	particles = {},
	_serial = 0,
	_last_game_frame = -1,
}

-- Timeline is gated to Game():GetFrameCount() (30 Hz), so these counts are ~1.6s total.
local MAX_CAPTURE_VISIBLE = 6
local tune = {
	rise = 10,
	travel = 18,
	hover = 12,
	drop = 8,
	rise_height = 18,
	hover_height = 30,
}

local HEART_ANM2 = {
	red_heart = "gfx/005.012_heart (half).anm2",
	soul_heart = "gfx/005.013_heart (soul).anm2",
	black_heart = "gfx/005.016_black heart.anm2",
	eternal_heart = "gfx/005.014_heart (eternal).anm2",
	bone_heart = "gfx/005.01a_bone heart.anm2",
}

local familiar_resolver = nil
local arrive_handler = nil

local function clamp01(t)
	return math.max(0, math.min(1, t))
end

local function smoothstep(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end

local function player_index(player)
	if not player or not player.GetData then return nil end
	local d = player:GetData()
	return d and d.__Index or nil
end

local function find_player_by_index(idx)
	if idx == nil then return nil end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:Exists() and player_index(player) == idx then
			return player
		end
	end
	return nil
end

function item.set_familiar_resolver(fn)
	familiar_resolver = fn
end

function item.set_arrive_handler(fn)
	arrive_handler = fn
end

local function resolve_familiar(player, hint)
	if familiar_resolver then
		return familiar_resolver(player, hint)
	end
	return nil
end

local function hud_offset()
	return ui.GetHUDRenderOffset()
end

local function player_screen_pos(player, y_off)
	if not player then return Vector(0, 0) end
	return Isaac.WorldToScreen(player.Position + Vector(0, y_off or -24)) + hud_offset()
end

local function familiar_body_target(familiar, player)
	if familiar then
		return Isaac.WorldToScreen(familiar.Position) + hud_offset()
	end
	return player_screen_pos(player, 0)
end

local function familiar_hover_target(familiar, player, hover_x)
	local height = tune.hover_height or 30
	local base
	if familiar then
		base = Isaac.WorldToScreen(familiar.Position + Vector(0, -height)) + hud_offset()
	else
		base = player_screen_pos(player, -height)
	end
	return base + Vector(hover_x or 0, 0)
end

function item.get_tune()
	return tune
end

function item.set_tune(key, value)
	if tune[key] == nil then return end
	tune[key] = value
end

function item.get_status()
	local phases = {}
	for _, p in ipairs(item.particles) do
		phases[#phases + 1] = tostring(p.phase) .. ":" .. tostring(p.frame)
	end
	return {
		count = #item.particles,
		phase = item.particles[1] and item.particles[1].phase or nil,
		frame = item.particles[1] and item.particles[1].frame or nil,
		summary = table.concat(phases, ", "),
	}
end

local function apply_look(p)
	local sprite = p.sprite
	if not sprite then return end
	local scale = (p.base_scale or 1) * (p.scale or 1)
	local bright = p.bright or 0
	local alpha = p.alpha or 1
	sprite.Scale = Vector(scale, scale)
	sprite.Color = Color(1, 1, 1, alpha, bright * 0.45, bright * 0.4, bright * 0.3)
end

local function make_pickup_anm2_sprite(anm2, scale)
	scale = scale or 0.45
	if slot_offer_lift.make_pickup_fly_sprite then
		return slot_offer_lift.make_pickup_fly_sprite(anm2, scale)
	end
	local sprite = Sprite()
	sprite:Load(anm2, true)
	sprite:Play("Idle", true)
	if sprite.SetLastFrame then sprite:SetLastFrame() end
	sprite.Scale = Vector(scale, scale)
	return sprite
end

local function make_loss_sprite(record)
	local kind = record and record.kind
	if kind == "coin" or kind == "bomb" or kind == "key" then
		local scale = slot_offer_lift.get_creditor_hud_fly_scale(kind) or 0.5
		return slot_offer_lift.make_creditor_hud_fly_sprite(kind, scale), scale
	end
	if kind == "red_heart" or kind == "soul_heart" then
		local hud_kind = (kind == "red_heart") and "heart" or "soul"
		local scale = slot_offer_lift.get_creditor_hud_fly_scale(hud_kind) or 0.375
		return slot_offer_lift.make_creditor_hud_fly_sprite(hud_kind, scale), scale
	end
	if HEART_ANM2[kind] then
		local scale = 0.4
		return make_pickup_anm2_sprite(HEART_ANM2[kind], scale), scale
	end
	if kind == "card" then
		local id = tonumber(record.subtype) or 0
		local sprite = Sprite()
		sprite:Load("gfx/ui/content/ui_cardfronts.anm2", true)
		if id > 0 then
			sprite:SetFrame("CardFronts", id)
		else
			sprite:Play("CardFronts", true)
			sprite:SetFrame(0)
		end
		local scale = 0.85
		sprite.Scale = Vector(scale, scale)
		return sprite, scale
	end
	if kind == "pill" then
		local color = tonumber(record.subtype) or 0
		local sprite = Sprite()
		sprite:Load("gfx/ui/ui_cardspills.anm2", true)
		sprite:Play("Pills", true)
		if color ~= 0 then
			sprite:SetFrame(color)
		else
			sprite:SetFrame(0)
		end
		local scale = 0.85
		sprite.Scale = Vector(scale, scale)
		return sprite, scale
	end
	if kind == "collectible" or kind == "charge" then
		local id = tonumber(record.collectible_id) or tonumber(record.active_item) or 0
		local sprite = Sprite()
		sprite:Load("gfx/005.100_collectible.anm2", true)
		sprite:Play("Idle", true)
		local cfg = id > 0 and Isaac.GetItemConfig():GetCollectible(id) or nil
		if cfg and cfg.GfxFileName then
			sprite:ReplaceSpritesheet(1, cfg.GfxFileName)
			sprite:LoadGraphics()
		end
		local scale = 0.55
		sprite.Scale = Vector(scale, scale)
		return sprite, scale
	end
	-- Fallback: coin icon
	local scale = 0.5
	return slot_offer_lift.make_creditor_hud_fly_sprite("coin", scale), scale
end

local function resolve_start_pos(player, record)
	local kind = record and record.kind
	if kind == "coin" or kind == "bomb" or kind == "key" then
		local pos = slot_offer_lift.get_pickup_hud_screen_pos(player, kind, 0)
		if pos then return pos end
	end
	if kind == "charge" then
		local slot = record.active_slot or ActiveSlot.SLOT_PRIMARY
		local info = ui.GetActiveSlotRenderInfo(player, slot)
		if info and info.offset then
			local scale = info.scale or Vector(1, 1)
			return info.offset + Vector(16 * scale.X, 16 * scale.Y) + hud_offset()
		end
		local order = auxi.GetPlayerOrder and auxi.GetPlayerOrder(player) or 0
		if ui.PlayerActiveUIPos then
			local pos = ui.PlayerActiveUIPos(player, slot, order, record.active_item)
			if pos then return pos end
		end
		return player_screen_pos(player, -24)
	end
	if kind == "red_heart" or kind == "soul_heart" or kind == "black_heart"
		or kind == "eternal_heart" or kind == "bone_heart"
	then
		return player_screen_pos(player, -20)
	end
	return player_screen_pos(player, -24)
end

function item.capture(player, record)
	if not player or type(record) ~= "table" then return nil end
	if #item.particles >= MAX_CAPTURE_VISIBLE then return nil end
	local idx = player_index(player)
	if idx == nil then return nil end
	local start = resolve_start_pos(player, record)
	local sprite, base_scale = make_loss_sprite(record)
	item._serial = item._serial + 1
	local hover_x = ((item._serial % 5) - 2) * 6
	local particle = {
		player_index = idx,
		kind = record.kind,
		subtype = record.subtype,
		collectible_id = record.collectible_id or record.active_item,
		active_slot = record.active_slot,
		active_item = record.active_item,
		sprite = sprite,
		pos = Vector(start.X, start.Y),
		phase = "rise",
		frame = 0,
		start_pos = Vector(start.X, start.Y),
		rise_pos = Vector(start.X, start.Y - (tune.rise_height or 18)),
		hover_x = hover_x,
		scale = 1,
		alpha = 1,
		bright = 0,
		base_scale = base_scale or 1,
		done = false,
	}
	apply_look(particle)
	item.particles[#item.particles + 1] = particle
	return particle
end

function item.get_particle_count()
	return #item.particles
end

function item.clear_all()
	item.particles = {}
end

function item.debug_spawn(player, loss)
	player = player or Isaac.GetPlayer(0)
	loss = loss or {kind = "coin", amount = 1}
	return item.capture(player, loss)
end

local function finish_drop(p, player, familiar)
	if arrive_handler then
		arrive_handler(player, familiar, {
			kind = p.kind,
			subtype = p.subtype,
			collectible_id = p.collectible_id,
			active_slot = p.active_slot,
			active_item = p.active_item,
		})
	end
	p.done = true
end

local function tick_particle(p)
	if p.done then return end
	local player = find_player_by_index(p.player_index)
	if not player or not player:Exists() then
		p.done = true
		return
	end
	local hint = {seed = p.worker_seed, pos = p.start_pos or p.pos}
	local familiar = resolve_familiar(player, hint)
	if familiar and not p.worker_seed then
		p.worker_seed = familiar.InitSeed
	end
	local rise_n = math.max(1, math.floor(tune.rise or 10))
	local travel_n = math.max(1, math.floor(tune.travel or 18))
	local hover_n = math.max(1, math.floor(tune.hover or 12))
	local drop_n = math.max(1, math.floor(tune.drop or 8))

	if p.phase == "rise" then
		p.frame = p.frame + 1
		local t = smoothstep(p.frame / rise_n)
		p.rise_pos = Vector(p.start_pos.X, p.start_pos.Y - (tune.rise_height or 18))
		p.pos = p.start_pos + (p.rise_pos - p.start_pos) * t
		p.scale = 1 + math.sin(t * math.pi) * 0.08
		p.alpha = 1
		p.bright = 0
		apply_look(p)
		if p.frame >= rise_n then
			p.phase = "travel"
			p.frame = 0
			p.travel_start = Vector(p.pos.X, p.pos.Y)
		end
		return
	end

	if p.phase == "travel" then
		p.frame = p.frame + 1
		local t = smoothstep(p.frame / travel_n)
		local live = familiar_hover_target(familiar, player, p.hover_x)
		local start = p.travel_start or p.pos
		p.pos = start + (live - start) * t
		p.scale = 1
		p.alpha = 1
		p.bright = 0
		apply_look(p)
		if p.frame >= travel_n then
			p.phase = "hover"
			p.frame = 0
		end
		return
	end

	if p.phase == "hover" then
		p.frame = p.frame + 1
		local live = familiar_hover_target(familiar, player, p.hover_x)
		local bob = math.sin(p.frame * 0.45) * 1.5
		p.pos = live + Vector(0, bob)
		p.scale = 1.08
		p.alpha = 1
		p.bright = 0.15
		apply_look(p)
		if p.frame >= hover_n then
			p.phase = "drop"
			p.frame = 0
			p.drop_start = Vector(p.pos.X, p.pos.Y)
		end
		return
	end

	if p.phase == "drop" then
		p.frame = p.frame + 1
		local t = clamp01(p.frame / drop_n)
		local accel = t * t
		local body = familiar_body_target(familiar, player)
		local start = p.drop_start or p.pos
		p.pos = start + (body - start) * accel
		local fade_from = math.max(1, drop_n - 2)
		if p.frame <= fade_from then
			local u = clamp01(p.frame / fade_from)
			p.scale = 1.08 + (0.65 - 1.08) * u
			p.alpha = 1 + (0.8 - 1) * u
		else
			local u = clamp01((p.frame - fade_from) / math.max(1, drop_n - fade_from))
			p.scale = 0.65 * (1 - u)
			p.alpha = 0.8 * (1 - u)
		end
		p.bright = 0.1
		apply_look(p)
		if p.frame >= drop_n then
			finish_drop(p, player, familiar)
		end
	end
end

function item.tick()
	local frame = Game():GetFrameCount()
	if item._last_game_frame == frame then
		return
	end
	item._last_game_frame = frame
	for i = #item.particles, 1, -1 do
		local p = item.particles[i]
		tick_particle(p)
		if p.done then
			table.remove(item.particles, i)
		end
	end
end

function item.render()
	local room = Game():GetRoom()
	if room and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	for _, p in ipairs(item.particles) do
		if p.sprite and not p.done then
			apply_look(p)
			p.sprite:Render(p.pos, Vector(0, 0), Vector(0, 0))
		end
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		if player and player.Index == 0 then
			item.tick()
		end
	end,
})

local hud_cb = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = hud_cb,
	params = nil,
	Function = function(_)
		item.render()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		item.clear_all()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_REWIND,
	params = nil,
	Function = function(_)
		item.clear_all()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_)
		item.clear_all()
	end,
})

return item

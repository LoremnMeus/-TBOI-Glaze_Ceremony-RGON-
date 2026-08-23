local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local DIR_LEFT = 4
local DIR_RIGHT = 5
local DIR_UP = 6
local DIR_DOWN = 7
local DIR_ITEM = 9
local DIR_DROP = 11
local HOLD_REPEAT_AFTER = 12
local HOLD_REPEAT_EVERY = 8
local HOLD_MISS_LIMIT = 20
local DEFAULT_ANM2 = "gfx/005.021_penny.anm2"
local HUD_GHOST_SCALE = 0.62
local HUD_TOKEN_CENTER = 9
-- Idle 首帧 pivot/尺寸（来自原版 pickup anm2），用于把虚影中心对齐到 token 格。
local PICKUP_HUD_FRAME = {
	["gfx/005.021_penny.anm2"] = {x = 0, y = -4, xp = 16, yp = 8, w = 32, h = 16},
	["gfx/005.031_key.anm2"] = {x = 1, y = 2, xp = 8, yp = 25, w = 16, h = 32},
	["gfx/005.041_bomb.anm2"] = {x = 0, y = 2, xp = 16, yp = 25, w = 32, h = 32},
	["gfx/005.011_heart.anm2"] = {x = 0, y = -1, xp = 16, yp = 20, w = 32, h = 32, hud_frame = 0},
	["gfx/005.013_heart (soul).anm2"] = {x = 0, y = -1, xp = 16, yp = 20, w = 32, h = 32, hud_frame = 0},
}
local PICKUP_HUD_OFFSET_KIND = {
	["gfx/005.021_penny.anm2"] = "Penny",
	["gfx/005.031_key.anm2"] = "Key",
	["gfx/005.041_bomb.anm2"] = "Bomb",
	["gfx/005.011_heart.anm2"] = "Heart",
	["gfx/005.013_heart (soul).anm2"] = "Soul",
}

local item = {
	range = 48,
	_reading_input = false,
	_ghosts = {},
	_eid_pending = {},
	hud_defaults = {
		BaseOffsetX = 0,
		BaseOffsetY = 0,
		PennyOffsetX = -4,
		PennyOffsetY = -2.5,
		KeyOffsetX = -8,
		KeyOffsetY = -2.5,
		BombOffsetX = -8,
		BombOffsetY = -2.5,
		HeartOffsetX = -8,
		HeartOffsetY = -2.5,
		SoulOffsetX = -8,
		SoulOffsetY = -2.5,
	},
}

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

local function debug_number(key, default, min_value, max_value)
	local debug = debug_root()
	local value = tonumber(debug and debug["CreditorHud"..key])
	if value == nil then value = default end
	if min_value ~= nil then value = math.max(min_value, value) end
	if max_value ~= nil then value = math.min(max_value, value) end
	return value
end

function item.get_hud_pickup_offset(anm2)
	local d = item.hud_defaults
	local kind = PICKUP_HUD_OFFSET_KIND[anm2] or "Penny"
	return Vector(
		debug_number("BaseOffsetX", d.BaseOffsetX, -80, 80) + debug_number(kind.."OffsetX", d[kind.."OffsetX"], -80, 80),
		debug_number("BaseOffsetY", d.BaseOffsetY, -80, 80) + debug_number(kind.."OffsetY", d[kind.."OffsetY"], -80, 80)
	)
end

local function lang_zh()
	local getter = auxi.get_EID_language
	local lang = getter and getter() or ""
	return lang == "zh" or lang == "zh_cn" or lang == "zh_tw"
end

function item.lang_zh()
	return lang_zh()
end

local function session_of(player, key)
	return player and player:GetData()[key.."sess"]
end

function item.has_session(player, key)
	return session_of(player, key) ~= nil
end

function item.current_option(player, key)
	local sess = session_of(player, key)
	if not sess or not sess.options then return nil end
	return sess.options[sess.idx]
end

local function opt_anm2(opt)
	if not opt then return DEFAULT_ANM2 end
	return opt.anm2 or opt.anm2 or DEFAULT_ANM2
end

local function pickup_hud_anchor(anm2, scale)
	local def = PICKUP_HUD_FRAME[anm2]
	if not def then return Vector(HUD_TOKEN_CENTER, HUD_TOKEN_CENTER) end
	local ox = def.x + def.w * 0.5 - def.xp
	local oy = def.y + def.h * 0.5 - def.yp
	return Vector(HUD_TOKEN_CENTER - ox * scale, HUD_TOKEN_CENTER - oy * scale)
end

local function stop_overlay(sprite)
	pcall(function()
		if sprite.StopOverlay then sprite:StopOverlay() end
	end)
end

-- 玩家举起：固定单帧，禁止 PlayOverlay（会把 Idle 再叠一层并各自播帧，红心会双影不同步）。
local function make_lift_sprite(anm2)
	local sprite = Sprite()
	if anm2 and anm2 ~= "" then
		sprite:Load(anm2, true)
		sprite:Play("Idle", true)
		if sprite:IsPlaying("Idle") then
			sprite:SetFrame(0)
		else
			sprite:Play("Appear", true)
			if sprite.SetLastFrame then sprite:SetLastFrame() end
		end
		stop_overlay(sprite)
	end
	return sprite
end

-- HUD 虚影：Appear/Idle 末帧静态图，同样不播 overlay。
local function make_hud_sprite(anm2)
	local sprite = Sprite()
	if anm2 and anm2 ~= "" then
		sprite:Load(anm2, true)
		sprite:Play("Idle", true)
		if not sprite:IsPlaying("Idle") then
			sprite:Play("Appear", true)
		end
		if not sprite:IsPlaying("Idle") and not sprite:IsPlaying("Appear") then
			local anim = sprite:GetDefaultAnimation()
			if anim and anim ~= "" then
				sprite:Play(anim, true)
			end
		end
		if sprite.SetLastFrame then
			local frame_def = PICKUP_HUD_FRAME[anm2]
			if frame_def and frame_def.hud_frame ~= nil then
				sprite:SetFrame(frame_def.hud_frame)
			else
				sprite:SetLastFrame()
			end
		end
		stop_overlay(sprite)
	end
	return sprite
end

function item.make_pickup_fly_sprite(anm2, scale)
	scale = scale or HUD_GHOST_SCALE
	local sprite = make_hud_sprite(anm2)
	sprite.Scale = Vector(scale, scale)
	return sprite
end

function item.get_pickup_hud_screen_pos(player, kind)
	local base = ui.GetScreenTopLeft(ui.GetHudOffsetLevel() or 0)
	local twin = player and player:GetPlayerType() == PlayerType.PLAYER_ESAU
	local del = {
		coin = Vector(22, twin and 72 or 68),
		key = Vector(8, twin and 42 or 38),
		bomb = Vector(8, twin and 68 or 54),
		heart = Vector(40, twin and 35 or 4),
		soul = Vector(58, twin and 35 or 4),
	}
	return base + (del[kind] or del.coin) + ui.GetHUDRenderOffset()
end

function item.draw_pickup_hud_icon(anm2, pos, alpha, color)
	local sprite = ghost_sprite(anm2)
	if not sprite then return end
	local anchor = pickup_hud_anchor(anm2, sprite.Scale.X)
	local tweak = item.get_hud_pickup_offset(anm2)
	sprite.Color = color or Color(1, 1, 1, alpha or 1, 0, 0, 0)
	sprite:Render(pos + anchor + tweak, Vector(0, 0), Vector(0, 0))
	sprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
end

local function ghost_sprite(anm2)
	if not anm2 or anm2 == "" then return nil end
	local cached = item._ghosts[anm2]
	if cached then return cached end
	local sprite = make_hud_sprite(anm2)
	sprite.Scale = Vector(HUD_GHOST_SCALE, HUD_GHOST_SCALE)
	item._ghosts[anm2] = sprite
	return sprite
end

local function find_ent(hash, etype, variant)
	if not hash then return nil end
	local list = auxi.getothers(nil, etype, variant) or {}
	for _, ent in pairs(list) do
		if ent and ent:Exists() and GetPtrHash(ent) == hash then
			return ent
		end
	end
	return nil
end

local function nearest_ent(player, etype, variant)
	if not variant or variant < 0 then return nil, nil end
	local best, best_dist = nil, nil
	local list = auxi.getothers(nil, etype, variant) or {}
	for _, ent in pairs(list) do
		if ent and ent:Exists() then
			local dist = player.Position:Distance(ent.Position)
			if best_dist == nil or dist < best_dist then
				best = ent
				best_dist = dist
			end
		end
	end
	return best, best_dist
end

local function peek_action(player, btn)
	item._reading_input = true
	local trig = Input.IsActionTriggered(btn, player.ControllerIndex)
	local held = Input.IsActionPressed(btn, player.ControllerIndex)
	item._reading_input = false
	return trig, held
end

function item.end_session(player, key, hide)
	local d = player:GetData()
	local sess = d[key.."sess"]
	if hide and player:IsHoldingItem() then
		player:AnimatePickup(make_lift_sprite(opt_anm2(sess and sess.options and sess.options[sess.idx])), true, "HideItem")
	end
	selection_holder.remove_select(player, key)
	d[key.."sess"] = nil
	d[key.."last_dir"] = nil
	d[key.."last_dir_counter"] = nil
end

function item.begin_session(player, ent, key, options)
	if not player or not ent or not options or #options <= 0 then return false end
	local d = player:GetData()
	d[key.."sess"] = {
		ent_ptr = GetPtrHash(ent),
		options = options,
		idx = 1,
		lifting = true,
		need_sep = nil,
		last_hit_frame = nil,
		hold_miss = 0,
	}
	d[key.."last_dir"] = DIR_ITEM
	d[key.."last_dir_counter"] = 0
	selection_holder.try_select(player, key)
	player:AnimatePickup(make_lift_sprite(opt_anm2(options[1])), true, "LiftItem")
	return true
end

function item.block_input(player, key, hook, button)
	if item._reading_input then return end
	if not player or not session_of(player, key) then return end
	for _, i in pairs({DIR_LEFT, DIR_RIGHT, DIR_UP, DIR_DOWN, DIR_ITEM, DIR_DROP}) do
		if button == i and (hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED) then
			return false
		end
	end
end

function item.try_confirm(player, ent, spec)
	if not player or not ent or not spec then return false end
	local sess = session_of(player, spec.key)
	if not sess then return false end
	-- 只认 RGON MC_POST_SLOT_COLLISION（经 enums.Callbacks.POST_SLOT_COLLISION 转发）。
	sess.last_hit_frame = Game():GetFrameCount()
	if sess.lifting then
		sess.need_sep = true
		return false
	end
	if sess.need_sep then return false end
	if not player:IsHoldingItem() then return false end
	if GetPtrHash(ent) ~= sess.ent_ptr then return false end
	local opt = sess.options and sess.options[sess.idx]
	if not opt then return false end
	item.end_session(player, spec.key, true)
	player:GetData()[spec.key.."blocked"] = true
	if spec.on_confirm then spec.on_confirm(player, ent, opt) end
	return true
end

local function relift(player, sess)
	local opt = sess.options[sess.idx]
	if not opt then return end
	sess.lifting = true
	sess.hold_miss = 0
	player:AnimatePickup(make_lift_sprite(opt_anm2(opt)), true, "LiftItem")
	sound_tracker.PlayStackedSound(194, 1, 1, false, 0, 2)
end

local function read_dir(player)
	local dir = nil
	local triggered = false
	for _, btn in pairs({DIR_LEFT, DIR_RIGHT, DIR_UP, DIR_DOWN, DIR_ITEM, DIR_DROP}) do
		local trig, held = peek_action(player, btn)
		if trig or held then
			dir = btn
			if trig then triggered = true end
		end
	end
	return dir, triggered
end

local function finish_lift(player, key, sess)
	if not sess.lifting then return end
	-- 举起姿势会让额外动画一直不算结束。钻石商人在 extra 结束后再播一次 LiftItem；
	-- 这里只要已经举起，就立刻允许切换/确认，禁止再播一次 LiftItem（会把 IsHoldingItem 打成 false）。
	if player:IsHoldingItem() or player:IsExtraAnimationFinished() then
		sess.lifting = nil
		selection_holder.check_and_try_select(player, key)
	end
end

function item.tick(player, spec)
	if not player or not spec or not spec.variant then return end
	item.flush_eid()
	local d = player:GetData()
	local key = spec.key
	local ent, dist = nearest_ent(player, 6, spec.variant)
	local in_range = ent and dist and dist <= (spec.range or item.range)
	local can_open = in_range and spec.can_open and spec.can_open(ent)

	if d[key.."blocked"] and not in_range then
		d[key.."blocked"] = nil
	end

	local sess = session_of(player, key)
	if sess then
		local live = find_ent(sess.ent_ptr, 6, spec.variant)
		if not live or not in_range or GetPtrHash(live) ~= sess.ent_ptr then
			item.end_session(player, key, true)
			if in_range then d[key.."blocked"] = true end
			return
		end
		if spec.can_open and not spec.can_open(live) then
			item.end_session(player, key, true)
			if in_range then d[key.."blocked"] = true end
			return
		end
		selection_holder.check_and_try_select(player, key)
		local frame = Game():GetFrameCount()
		if sess.need_sep and (not sess.last_hit_frame or (frame - sess.last_hit_frame) >= 2) then
			sess.need_sep = nil
		end
		finish_lift(player, key, sess)
		if not sess.lifting then
			if player:IsHoldingItem() then
				sess.hold_miss = 0
			else
				sess.hold_miss = (sess.hold_miss or 0) + 1
				if sess.hold_miss >= HOLD_MISS_LIMIT then
					item.end_session(player, key, false)
					d[key.."blocked"] = true
					return
				end
			end
			if Game():IsPaused() == false then
				local dir, triggered = read_dir(player)
				local should_count = false
				if dir then
					if dir == DIR_DROP then
						item.end_session(player, key, true)
						d[key.."blocked"] = true
						d[key.."last_dir"] = dir
						return
					end
					if dir == DIR_ITEM or dir == DIR_UP or dir == DIR_DOWN then
						d[key.."last_dir"] = dir
						return
					end
					if triggered then
						should_count = true
						d[key.."last_dir_counter"] = 0
					elseif dir == d[key.."last_dir"] then
						d[key.."last_dir_counter"] = (d[key.."last_dir_counter"] or 0) + 1
						if d[key.."last_dir_counter"] > HOLD_REPEAT_AFTER and d[key.."last_dir_counter"] % HOLD_REPEAT_EVERY == 1 then
							should_count = true
						end
					else
						d[key.."last_dir_counter"] = 0
						should_count = true
					end
				else
					d[key.."last_dir_counter"] = 0
				end
				d[key.."last_dir"] = dir
				if should_count and dir and sess.options and #sess.options > 1 then
					if dir == DIR_LEFT then
						sess.idx = sess.idx - 1
						if sess.idx < 1 then sess.idx = #sess.options end
						relift(player, sess)
					elseif dir == DIR_RIGHT then
						sess.idx = sess.idx + 1
						if sess.idx > #sess.options then sess.idx = 1 end
						relift(player, sess)
					end
				end
			end
		end
		return
	end

	if in_range and can_open and not d[key.."blocked"] and player:IsExtraAnimationFinished() then
		local options = spec.get_options and spec.get_options(player, ent)
		if options and #options > 0 then
			item.begin_session(player, ent, key, options)
		end
	end
end

local function token_color(kind)
	if kind == "gain" then return KColor(0.45, 1, 0.55, 1) end
	if kind == "debt" then return KColor(1, 0.42, 0.38, 1) end
	if kind == "arrow" then return KColor(0.92, 0.92, 0.92, 1) end
	return KColor(1, 0.95, 0.55, 1)
end

local function render_tokens(tokens, origin)
	if not tokens or #tokens == 0 then return end
	local widths = {}
	local total = 0
	for i, tok in ipairs(tokens) do
		local w = tok.w
		if not w then
			if tok.t == "num" or tok.t == "txt" then
				w = math.max(8, #tostring(tok.v or "") * 6)
			else
				w = 16
			end
		end
		widths[i] = w
		total = total + w
	end
	local pos = origin + Vector(-total * 0.5, 0)
	for i, tok in ipairs(tokens) do
		if tok.t == "num" or tok.t == "txt" then
			gui.draw_ch(pos + Vector(0, -2), tostring(tok.v or ""), tok.scale or 1, tok.scale or 1, token_color(tok.c), true)
		elseif tok.t == "spr" then
			local sprite = ghost_sprite(tok.anm2)
			if sprite then
				local scale = sprite.Scale.X
				local anchor = tok.anchor or pickup_hud_anchor(tok.anm2, scale)
				local tweak = item.get_hud_pickup_offset(tok.anm2)
				sprite.Color = Color(1, 1, 1, tok.a or 0.7, 0, 0, 0)
				sprite:Render(pos + anchor + tweak, Vector(0, 0), Vector(0, 0))
			end
		end
		pos = pos + Vector(widths[i], 0)
	end
end

function item.render(player, spec)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	if not player or not spec or spec.render_hud == false then return end
	if not player:IsHoldingItem() then return end
	local opt = item.current_option(player, spec.key)
	if not opt then return end
	local pos = Isaac.WorldToScreen(player.Position) + Vector(0, -54)
	if opt.hud_tokens then
		render_tokens(opt.hud_tokens, pos)
		return
	end
	if opt.hud_num then
		local tokens = {
			{t = "num", v = opt.hud_num, c = opt.hud_take and "gain" or "neutral", w = 18},
			{t = "spr", anm2 = opt_anm2(opt), a = 0.85, w = 18},
		}
		if opt.hud_take then
			tokens[#tokens + 1] = {t = "txt", v = "->", c = "arrow", w = 16, scale = 1}
			tokens[#tokens + 1] = {t = "num", v = "-"..tostring(opt.hud_take), c = "debt", w = 20}
			tokens[#tokens + 1] = {t = "spr", anm2 = opt.hud_take_anm2 or opt_anm2(opt), a = 0.45, w = 18}
		end
		render_tokens(tokens, pos)
	end
end

local function apply_eid(entry)
	if not EID or not EID.addDescriptionModifier then return false end
	EID:addDescriptionModifier(entry.name, function(desc)
		return desc.ObjType == 6 and desc.ObjVariant == entry.variant
	end, function(desc)
		local player = (EID and EID.player) or Game():GetPlayer(0)
		local opt = item.current_option(player, entry.key)
		if opt and entry.option_fn then
			desc.Description = entry.option_fn(player, opt)
		elseif entry.static_fn then
			desc.Description = entry.static_fn(player)
		end
		return desc
	end)
	return true
end

function item.flush_eid()
	if not item._eid_pending or #item._eid_pending == 0 then return end
	local remain = {}
	for _, entry in ipairs(item._eid_pending) do
		if not apply_eid(entry) then
			remain[#remain + 1] = entry
		end
	end
	item._eid_pending = remain
end

function item.install_eid(name, variant, key, static_fn, option_fn)
	local entry = {name = name, variant = variant, key = key, static_fn = static_fn, option_fn = option_fn}
	if not apply_eid(entry) then
		item._eid_pending[#item._eid_pending + 1] = entry
	end
end

item.DIR_DROP = DIR_DROP
item.DIR_LEFT = DIR_LEFT
item.DIR_RIGHT = DIR_RIGHT
item.lang_zh = item.lang_zh
item.install_eid = item.install_eid
item.try_confirm = item.try_confirm
item.tick = item.tick
item.block_input = item.block_input
item.render = item.render
item.current_option = item.current_option
item.make_pickup_fly_sprite = item.make_pickup_fly_sprite
item.get_pickup_hud_screen_pos = item.get_pickup_hud_screen_pos
item.draw_pickup_hud_icon = item.draw_pickup_hud_icon
item.get_hud_pickup_offset = item.get_hud_pickup_offset

return item

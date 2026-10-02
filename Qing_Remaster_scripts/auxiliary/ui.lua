local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	post_ToCall = {},
	active_slot_render = {},
	-- Runtime only. Not saved, not written into optional_maker.
	debug_hud_tune = {
		card = {},
		coin = {},
		bomb = {},
		key = {},
	},
	debug_hud_audit = {
		draw_card_guide = false,
		draw_resource_guide = false,
		-- nil = follow the current HUD. 1 = normal, 2 = twin.
		resource_state = nil,
		heart = nil,
	},
	CARD_UI_STATE = {
		NORMAL = 1,
		MAIN_TWIN = 2,
		OTHER_TWIN = 3,
	},
	-- Extra sprite-geometry correction on top of the visible-card center. Not a HUD layout offset.
	CARD_OVERLAY_LOCAL_OFFSET = {
		tarot_cloth = Vector(0, 0),
		oblivion = Vector(0, 0),
	},
	-- ui_cardfronts.anm2 的 Frame Crop 是 16×20、pivot 8,12。
	-- cards.png 上全部 56 张 16×20 裁切的不透明像素都是 14×18，四边各 1px 透明。
	-- 含黑边的可见卡面是 14×18。HUD 对齐和审计按可见区域，不能按 Crop 尺寸。
	CARD_VISIBLE_SIZE = Vector(14, 18),
	CARD_VISIBLE_PIVOT = Vector(7, 9),
	-- 可见区域在 crop 内从 (1,1) 起，中心是 (8,10)。相对 ANM2 pivot (8,12) 为 (0,-2)。
	CARD_VISIBLE_CENTER_OFFSET = Vector(0, -2),
	optional_maker = {
		["heart"] = {
			[1] = {name = "GetScreenTopLeft",del = Vector(40,4),},		--正常的血条
			[2] = {name = "GetScreenTopLeft",del = Vector(40,35),},		--双子的血条
		},
		-- 金币/炸弹/钥匙：Y 对齐 Epiphany HudHelper（32/44/56）再按本模组炸弹 icon 中心偏置 +10；双子 +14。
		["coin"] = {
			[1] = {name = "GetScreenTopLeft",del = Vector(8,42),},		--正常的金币
			[2] = {name = "GetScreenTopLeft",del = Vector(8,56),},		--双子的金币
		},
		["bomb"] = {
			--[1] = {name = "GetScreenTopLeft",del = Vector(8,52),},		--正常的炸弹
			[1] = {name = "GetScreenTopLeft",del = Vector(8,54),},		--正常的炸弹
			--[2] = {name = "GetScreenTopLeft",del = Vector(8,66),},		--双子的炸弹
			[2] = {name = "GetScreenTopLeft",del = Vector(8,68),},		--双子的炸弹
		},
		["key"] = {
			[1] = {name = "GetScreenTopLeft",del = Vector(8,66),},		--正常的钥匙
			[2] = {name = "GetScreenTopLeft",del = Vector(8,80),},		--双子的钥匙
		},
		["poop"] = {
			[1] = {name = "GetScreenTopLeft",del = Vector(0,40),},		--正常的便便
			[2] = {name = "GetScreenTopLeft",del = Vector(0,56),},		--双子的便便
		},
		["chargebar"] = {
			[1] = {name = "GetScreenTopLeft",del = Vector(38,17),},			--正常的充能条
			[2] = {name = "GetScreenTopRight",del = Vector(-36,-22),},		--副手主动
			[3] = {name = "GetScreenBottomRight",del = Vector(-2,-13),},	--2p
		},
		["active"] = {
			[1] = {name = "GetScreenTopLeft",del = Vector(20,16),},			--正常主动
			[2] = {name = "GetScreenBottomRight",del = Vector(-20,-23),},	--双子主动
			[3] = {name = "GetScreenBottomRight",del = Vector(-20,-14),},	--副手主动
		},
		["card"] = {
			[1] = {name = "GetScreenBottomRight",del = Vector(-15,-12),},	--正常卡牌
			-- Rep+ Jacob / main twin. Measured: old (11,41) + tune (34,0.5).
			[2] = {name = "GetScreenTopLeft",del = Vector(45,41.5),},
			-- Rep+ Esau / other twin. Measured: old (-10,-44) + tune (-38,38.5).
			[3] = {name = "GetScreenBottomRight",del = Vector(-48,-5.5),},
		},
	},
}

function item.GetScreenSize()
	if Isaac.GetScreenWidth and Isaac.GetScreenHeight then
		local width = Isaac.GetScreenWidth()
		local height = Isaac.GetScreenHeight()
		if width and height and width > 0 and height > 0 then
			return Vector(width,height)
		end
	end
	local game = Game()
	local room = game:GetRoom()
	local pos = room:WorldToScreenPosition(Vector(0,0)) - room:GetRenderScrollOffset() - game.ScreenShakeOffset
	local rx = pos.X + 60 * 26 / 40
	local ry = pos.Y + 140 * (26 / 40)
	return Vector(rx*2 + 13*26, ry*2 + 7*26)
end

function item.GetScreenCenter()
	return item.GetScreenSize()/2
end

function item.GetScreenBottomRight(offset)
	offset = offset or 0
	local pos = item.GetScreenSize()
	local hudOffset = Vector(-offset * 1.6, -offset * 0.6)
	pos = pos + hudOffset
	return pos
end

function item.GetScreenBottomLeft(offset)
	offset = offset or 0
	local pos = Vector(0, item.GetScreenBottomRight(0).Y)
	local hudOffset = Vector(offset * 2.2, -offset * 1.6)
	pos = pos + hudOffset
	return pos
end

function item.GetScreenTopRight(offset)
	offset = offset or 0
	local pos = Vector(item.GetScreenBottomRight(0).X, 0)
	local hudOffset = Vector(-offset * 2.2, offset * 1.2)
	pos = pos + hudOffset
	return pos
end

function item.GetScreenTopLeft(offset,del)
	offset = offset or 0
	local pos = Vector(0,0)
	local hudOffset = Vector(offset * 2, offset * 1.2)
	pos = pos + hudOffset
	return pos
end

function item.GetHudOffsetLevel()
	local raw = Options.HUDOffset
	raw = raw * 10
	if raw%1 < 0.5 then return math.floor(raw)
	else return math.ceil(raw) end
end

-- Screen-space overlays attached to the vanilla HUD must follow its shake.
function item.GetHUDRenderOffset()
	return Game().ScreenShakeOffset
end

-- HUD 槽位锚点：optional_maker / UIHeartPos 的 del 均为槽位左上角；CENTER 再按槽位尺寸换算。
item.HUD_ANCHOR = {
	TOP_LEFT = "topleft",
	CENTER = "center",
	PIVOT = "pivot",
	VISUAL_CENTER = "visual_center",
}

-- 原版 HUD 槽位外框（非 pickup anm2 尺寸）；心 12×12，资源 icon 约 16×16。
item.HUD_SLOT_BOX = {
	heart = Vector(12, 12),
	coin = Vector(16, 16),
	bomb = Vector(16, 16),
	key = Vector(16, 16),
	poop = Vector(16, 16),
}

-- 对齐原版 HUD icon pivot 落点（2026-03-24，DrawLine 十字实测）
item.HUD_ICON_TUNE = {
	heart = Vector(0, 2),
	coin = Vector(-8, -8),
	bomb = Vector(-8, -8),
	key = Vector(-8, -8),
}

function item.GetHudIconTuneOffset(kind)
	if kind == "soul" then kind = "heart" end
	local tune = item.HUD_ICON_TUNE[kind]
	return tune and Vector(tune.X, tune.Y) or Vector(0, 0)
end

local function resolve_anchor_params(offset, params)
	if type(offset) == "table" and offset.anchor and offset.X == nil and offset.Y == nil then
		return Vector(0, 0), offset
	end
	return offset or Vector(0, 0), params or {}
end

function item.BoxAnchorPos(box_top_left, box_size, anchor, extra_offset)
	box_top_left = box_top_left or Vector(0, 0)
	box_size = box_size or Vector(12, 12)
	anchor = anchor or item.HUD_ANCHOR.TOP_LEFT
	extra_offset = extra_offset or Vector(0, 0)
	if anchor == item.HUD_ANCHOR.CENTER or anchor == item.HUD_ANCHOR.VISUAL_CENTER then
		return box_top_left + Vector(box_size.X * 0.5, box_size.Y * 0.5) + extra_offset
	end
	if anchor == item.HUD_ANCHOR.PIVOT then
		return box_top_left + extra_offset
	end
	return box_top_left + extra_offset
end

function item.GetSpriteLayerMetrics(sprite, layer_id)
	local metrics = {
		pivot = Vector(16, 16),
		pos = Vector(0, 0),
		width = 32,
		height = 32,
		crop = Vector(0, 0),
	}
	if not sprite or not sprite.GetLayerFrameData then return metrics end
	local frame = sprite:GetLayerFrameData(layer_id or 0)
	if not frame then return metrics end
	if frame.GetPivot then metrics.pivot = frame:GetPivot() or metrics.pivot end
	if frame.GetPos then metrics.pos = frame:GetPos() or metrics.pos end
	if frame.GetWidth then metrics.width = frame:GetWidth() or metrics.width end
	if frame.GetHeight then metrics.height = frame:GetHeight() or metrics.height end
	if frame.GetCrop then metrics.crop = frame:GetCrop() or metrics.crop end
	return metrics
end

-- pivot → 贴图可见几何中心（未乘 Sprite.Scale）
function item.SpriteVisualCenterOffset(sprite, layer_id)
	local m = item.GetSpriteLayerMetrics(sprite, layer_id)
	return m.pos + Vector(m.width * 0.5, m.height * 0.5) - m.pivot
end

-- pivot → 贴图可见几何左上角（未乘 Sprite.Scale）
function item.SpriteVisualTopLeftOffset(sprite, layer_id)
	local m = item.GetSpriteLayerMetrics(sprite, layer_id)
	return m.pos - m.pivot
end

-- 令 Sprite:Render(render_pos) 时，可见几何中心落在 visual_center
function item.VisualCenterToRenderPos(visual_center, sprite, scale, layer_id)
	scale = scale or 1
	local off = item.SpriteVisualCenterOffset(sprite, layer_id)
	return visual_center - Vector(off.X * scale, off.Y * scale)
end

function item.RenderPosToVisualCenter(render_pos, sprite, scale, layer_id)
	scale = scale or 1
	local off = item.SpriteVisualCenterOffset(sprite, layer_id)
	return render_pos + Vector(off.X * scale, off.Y * scale)
end

-- HUD 槽位左上角 + 已知 sprite：按 anchor 返回屏幕点
function item.HUDSlotAnchorPos(box_top_left, slot_name, sprite, scale, anchor, layer_id, extra_offset)
	local box = (item.HUD_SLOT_BOX or {})[slot_name] or Vector(12, 12)
	local pt = item.BoxAnchorPos(box_top_left, box, anchor, extra_offset)
	if anchor == item.HUD_ANCHOR.PIVOT and sprite then
		scale = scale or 1
		local m = item.GetSpriteLayerMetrics(sprite, layer_id)
		return pt + Vector((m.pivot.X - m.pos.X) * scale, (m.pivot.Y - m.pos.Y) * scale)
	end
	if anchor == item.HUD_ANCHOR.VISUAL_CENTER and sprite then
		return pt
	end
	return pt
end

local function get_player_hash(player)
	if player == nil then return "nil" end
	if GetPtrHash then return tostring(GetPtrHash(player)) end
	return tostring(player.InitSeed or player.Index or 0)
end

local function get_active_slot_key(player,slot)
	return get_player_hash(player)..":"..tostring(slot or 0)
end

function item.SetActiveSlotRenderInfo(player,slot,offset,alpha,scale,chargeBarOffset)
	if player == nil or slot == nil then return end
	item.active_slot_render[get_active_slot_key(player,slot)] = {
		offset = offset,
		alpha = alpha,
		scale = scale,
		chargeBarOffset = chargeBarOffset,
		frame = Game():GetFrameCount(),
	}
end

function item.GetActiveSlotRenderInfo(player,slot)
	local info = item.active_slot_render[get_active_slot_key(player,slot)]
	if info and Game():GetFrameCount() - (info.frame or 0) <= 2 then
		return info
	end
end

local function is_jacob_or_esau(player)
	local tp = player:GetPlayerType()
	return tp == PlayerType.PLAYER_JACOB or tp == PlayerType.PLAYER_ESAU
end

local function is_rep_plus_small_hud(order)
	if not REPENTOGON then return false end
	if order and order > 0 then return true end
	if GetPtrHash == nil then return false end
	local game = Game()
	local player_count = 0
	for i = 0,game:GetNumPlayers() - 1 do
		local player = game:GetPlayer(i)
		if player and player.Parent == nil and player.Variant == 0 then
			local main_twin = player.GetMainTwin and player:GetMainTwin() or player
			if main_twin and GetPtrHash(main_twin) == GetPtrHash(player) then
				player_count = player_count + 1
				if player_count > 2 then return true end
				if player_count > 1 and main_twin:GetPlayerType() == PlayerType.PLAYER_JACOB then return true end
			end
		end
	end
	return false
end

local function get_rep_plus_active_anchor(player,order)
	local tp = player:GetPlayerType()
	local hud = Options.HUDOffset
	local sc = item.GetScreenSize()
	local small_hud = is_rep_plus_small_hud(order)
	local x = -10000000
	local y = -10000000
	local left_top_x = 20 * hud
	local right_top_x = -24 * hud
	local left_bottom_x = 22 * hud
	local right_bottom_x = -16 * hud
	local top_y = 12 * hud
	local bottom_y = -6 * hud
	if order == 0 then
		if tp == PlayerType.PLAYER_ESAU and not small_hud then
			x,y = sc.X + 126 + right_bottom_x,sc.Y + 21 + bottom_y
		else
			x,y = 166 + left_top_x,66 + top_y
		end
	elseif order == 1 then
		x,y = sc.X - 9 + right_top_x,66 + top_y
	elseif order == 2 then
		x,y = 176 + left_bottom_x,sc.Y + 21 + bottom_y
	elseif order == 3 then
		x,y = sc.X - 17 + right_bottom_x,sc.Y + 21 + bottom_y
	end
	if order and order >= 2 and is_jacob_or_esau(player) and small_hud then
		y = y - 22 - bottom_y
	end
	if tp == PlayerType.PLAYER_ESAU and small_hud then
		y = y + 32
	end
	return x,y
end

local function get_active_ui_scale(player,slot,order)
	local scale = Vector(1,1)
	local small_hud = is_rep_plus_small_hud(order)
	if REPENTOGON then
		if (slot == ActiveSlot.SLOT_PRIMARY or slot == ActiveSlot.SLOT_SECONDARY) and small_hud and is_jacob_or_esau(player) then
			scale = scale * 0.5
		end
		if slot == ActiveSlot.SLOT_POCKET and ((order or 0) > 0 or small_hud or is_jacob_or_esau(player)) then
			scale = scale * 0.5
		end
		if slot == ActiveSlot.SLOT_SECONDARY then
			scale = scale * 0.5
		end
		return scale
	end
	if slot == ActiveSlot.SLOT_POCKET and order > 0 then scale = scale * 0.5 end
	if slot == ActiveSlot.SLOT_SECONDARY then scale = scale * 0.5 end
	return scale
end

local function get_rep_plus_player_active_pos(player,slot,order)
	local anchor_x,anchor_y = get_rep_plus_active_anchor(player,order)
	local scale = get_active_ui_scale(player,slot,order)
	local tp = player:GetPlayerType()
	local small_hud = is_rep_plus_small_hud(order)
	if slot == ActiveSlot.SLOT_SECONDARY then
		if tp == PlayerType.PLAYER_ESAU and not small_hud then
			return Vector(anchor_x - 124 - 8 * scale.X,anchor_y - 52)
		end
		return Vector(anchor_x - 124 - 60 * scale.X - 9,anchor_y - 52)
	elseif slot == ActiveSlot.SLOT_POCKET then
		local jacob = tp == PlayerType.PLAYER_JACOB
		local esau = tp == PlayerType.PLAYER_ESAU
		if esau and not small_hud then
			return Vector(anchor_x - 175,anchor_y - 25)
		elseif (jacob or esau) and small_hud then
			return Vector(anchor_x - 133,anchor_y - 27)
		elseif jacob or small_hud then
			local x = anchor_x - 122
			local trinket_count = 0
			for slot_id = 0,1 do
				if player:GetTrinket(slot_id) > 0 then trinket_count = trinket_count + 1 end
			end
			if trinket_count > 0 then x = x + trinket_count * 16 - 3 end
			return Vector(x,anchor_y - 25)
		end
		local sc = item.GetScreenSize()
		local hud = Options.HUDOffset
		return Vector(sc.X - 20 - 16 * hud,sc.Y - 14 - 6 * hud)
	end
	return Vector(anchor_x - 124 - 22 * scale.X,anchor_y - 52 + 8 * scale.Y)
end

function item.UI_Pos(name,state,offset,params)
	params = params or {}
	if type(offset) == "table" and offset.X == nil and offset.Y == nil then
		params = offset
		offset = nil
	end
	offset, params = resolve_anchor_params(offset, params)
	state = state or 1
	name = name or params.name
	local hud = item.GetHudOffsetLevel()
	local info = (item.optional_maker[name] or {})[state]
	if info == nil then return Vector(1000,1000) end
	local pos_offset = item[info.name](hud) + (auxi.check_if_any(info.special,hud) or Vector(0,0))
	local top_left = pos_offset + info.del + offset + item.GetHUDRenderOffset()
	local anchor = params.anchor or item.HUD_ANCHOR.TOP_LEFT
	local box = (item.HUD_SLOT_BOX or {})[name] or Vector(12, 12)
	return item.BoxAnchorPos(top_left, box, anchor)
end

function item.PlayerActive_UI_Pos(player,slot,order)
	if REPENTOGON then
		return get_rep_plus_player_active_pos(player,slot or ActiveSlot.SLOT_PRIMARY,order or 0)
	end
	local tp = player:GetPlayerType()
	local hud = item.GetHudOffsetLevel()
	local sc = item.GetScreenSize()
	local ret = Vector(-1000,-1000)
	if (order == 0) then
		if (tp == PlayerType.PLAYER_ESAU) then ret = item.UI_Pos("active",2) - item.GetHUDRenderOffset()
		else ret = item.UI_Pos("active",1) - item.GetHUDRenderOffset() end
	elseif (order == 1) then
		ret = auxi.mul_t(sc,Vector(1,0)) + Vector(-139,0) + Vector(-2.4,1.2) * hud
	elseif (order == 2) then
		ret = auxi.mul_t(sc,Vector(0,1)) + Vector(30,-23) + Vector(2.2,-0.6) * hud
	elseif (order == 3) then
		ret = sc + Vector(-147,-23) + Vector(1.6,-0.6) * hud
	end
	return ret
end

function item.PlayerActiveUIPos(player,slot,order,cid,opts)
	opts = opts or {}
	if REPENTOGON and not opts.ignore_capture then
		local render_info = item.GetActiveSlotRenderInfo(player,slot)
		if render_info and render_info.offset then
			local scale = tonumber(render_info.scale) or 1
			-- RGON Offset = 主动图标框左上角；此处返回「假定 pivot=(16,16)、无层偏移」时的 Render 点（框中心）。
			-- 仅适用于中心锚点贴图/文字。dropping_collectible 等非中心锚点请用 ActiveSlotSpriteRenderPos。
			return render_info.offset + Vector(16 * scale,16 * scale) + item.GetHUDRenderOffset()
		end
	end
	local tp = player:GetPlayerType()
	local hudOffset = Options.HUDOffset
	local sc = item.GetScreenSize()
	local ret = item.PlayerActive_UI_Pos(player,slot,order)
	if (slot == ActiveSlot.SLOT_PRIMARY) then	
		if (auxi.has_have_coll(player,584) and cid ~= 584) or (auxi.has_have_coll(player,59) and cid ~= 59) then ret = ret + Vector(0,-4) end
	elseif (slot == ActiveSlot.SLOT_SECONDARY) then
		if not REPENTOGON then ret = ret - Vector(17,8) end
	elseif (slot == ActiveSlot.SLOT_POCKET) then
		if not REPENTOGON and (order == 0) then
			if (tp == PlayerType.PLAYER_ESAU) then ret = sc - Vector(15,46) - Vector(16,6) * hudOffset
			elseif (tp == PlayerType.PLAYER_JACOB) then ret = Vector(3,39) + Vector(20,12) * hudOffset
			else ret = sc - Vector(20,14) - Vector(16,6) * hudOffset end
		elseif not REPENTOGON then ret = ret + Vector(-24,18) end
	end
	return ret + item.GetHUDRenderOffset()
end

-- 把 RGON 主动槽 Offset（图标框左上角）换成 Sprite:Render 用的 pivot 落点。
-- 用当前层帧的 Pivot/Pos，避免「一边是左上角、贴图却不是左上角锚点」的错位。
function item.ActiveSlotSpriteRenderPos(player,slot,sprite,layer_id)
	local render_info = item.GetActiveSlotRenderInfo(player,slot)
	local scale = (render_info and tonumber(render_info.scale)) or 1
	local top_left = render_info and render_info.offset
	if not top_left then
		return item.PlayerActiveUIPos(player,slot,auxi.GetPlayerOrder(player))
	end
	layer_id = layer_id or 0
	local pivot = Vector(16,16)
	local layer_pos = Vector(0,0)
	if sprite and sprite.GetLayerFrameData then
		local frame = sprite:GetLayerFrameData(layer_id)
		if frame then
			if frame.GetPivot then pivot = frame:GetPivot() or pivot end
			if frame.GetPos then layer_pos = frame:GetPos() or layer_pos end
		end
	end
	-- screen_top_left = render_pos + (layer_pos - pivot) * scale  ⇒  render_pos = top_left + (pivot - layer_pos) * scale
	return top_left + Vector((pivot.X - layer_pos.X) * scale,(pivot.Y - layer_pos.Y) * scale) + item.GetHUDRenderOffset()
end

function item.UIHeartPos(x, player, offset, params)
	if not player then player = 1 end
	if not x then x = 0 end
	offset, params = resolve_anchor_params(offset, params)
	local hud = item.GetHudOffsetLevel()
	local rep_plus = (REPENTANCE_PLUS and Vector(0, 6)) or Vector(0, 0)
	local anchor = params.anchor or item.HUD_ANCHOR.TOP_LEFT
	local box = item.HUD_SLOT_BOX.heart or Vector(12, 12)
	if player == 1 then
		local topleft = Vector(40, 4) + Vector(2, 1.2) * hud + rep_plus
		local rows = math.floor(x / 6)
		local top_left = topleft + Vector(12 * (x % 6), 10 * rows) + offset + item.GetHUDRenderOffset()
		return item.BoxAnchorPos(top_left, box, anchor)
	end
	if player == 2 then
		local topright = item.GetScreenSize() - Vector(40, 35) - Vector(1.6, 0.6) * hud + rep_plus
		local rows = math.floor(x / 6)
		local top_left = topright + Vector(-12 * (x % 6), 10 * rows) + offset + item.GetHUDRenderOffset()
		return item.BoxAnchorPos(top_left, box, anchor)
	end
end

function item.UIBombPos(doubleplayer, offset, params)
	local state = 1
	if doubleplayer then state = 2 end
	return item.UI_Pos("bomb", state, offset, params)
end

function item.UIPoopPos(doubleplayer,offset)
	local state = 1
	if doubleplayer then state = 2 end
	
	return item.UI_Pos("poop",state,offset)
end

function item.UIChargeBarPos(slot,offset)
	if type(offset) == "table" and offset.X == nil and offset.Y == nil then offset = nil end
	local state = 1
	if slot == 1 then state = 2 end
	if slot == 2 then state = 3 end
	
	return item.UI_Pos("chargebar",state,offset)
end

function item.UIActivePos(slot,offset,params)
	if type(offset) == "table" and offset.X == nil and offset.Y == nil then
		params = offset
		offset = nil
	end
	params = params or {}
	if params.player then
		return item.PlayerActiveUIPos(params.player,slot or ActiveSlot.SLOT_PRIMARY,params.order or auxi.GetPlayerOrder(params.player),params.cid) + (offset or Vector(0,0))
	end
	local state = 1
	if slot == 1 then state = 2 end
	if slot == 2 then state = 3 end
	
	return item.UI_Pos("active",state,offset,params)
end

function item.UICardPos(state,offset,params)
	params = params or {}
	if type(offset) == "table" and offset.X == nil and offset.Y == nil then
		params = offset
		offset = nil
	end
	state = state or 1
	if params.doubleplayer then state = 2 end
	
	return item.UI_Pos("card",state,offset,params)
end

local function player_hud(player)
	if player.GetPlayerHUD then
		local ok, hud = pcall(function()
			return player:GetPlayerHUD()
		end)
		if ok and hud then return hud end
	end
	local game_hud = Game():GetHUD()
	if not (game_hud and game_hud.GetPlayerHUD) then return nil end
	for i = 0, 3 do
		local ok, hud = pcall(function()
			return game_hud:GetPlayerHUD(i)
		end)
		if ok and hud and hud.GetPlayer then
			local ok_player, owner = pcall(function()
				return hud:GetPlayer()
			end)
			if ok_player and owner and GetPtrHash(owner) == GetPtrHash(player) then
				return hud
			end
		end
	end
	return nil
end

local function read_hud_layout(player)
	local hud = player_hud(player)
	if not (hud and hud.GetLayout) then return nil end
	local ok, layout = pcall(function()
		return hud:GetLayout()
	end)
	if ok then return layout end
	return nil
end

local function layout_equals(layout, enum_name, numeric)
	if layout == nil then return false end
	local enum_value = nil
	if PlayerHUDLayout then
		if enum_name == "NORMAL" then enum_value = PlayerHUDLayout.NORMAL
		elseif enum_name == "JACOB_AND_ESAU" then enum_value = PlayerHUDLayout.JACOB_AND_ESAU
		elseif enum_name == "COMPACT" then enum_value = PlayerHUDLayout.COMPACT
		elseif enum_name == "COMPACT_JACOB_AND_ESAU" then enum_value = PlayerHUDLayout.COMPACT_JACOB_AND_ESAU
		end
	end
	if enum_value ~= nil then return layout == enum_value end
	return layout == numeric
end

local function is_esau_seat(player)
	if player:GetPlayerType() == PlayerType.PLAYER_ESAU then return true end
	if not player.GetMainTwin then return false end
	local main = player:GetMainTwin()
	if not main or GetPtrHash(main) == GetPtrHash(player) then return false end
	local tp = player:GetPlayerType()
	return tp == PlayerType.PLAYER_JACOB or tp == PlayerType.PLAYER_ESAU
end

--- Spectralsword / HUD: solo | main | other（优先 Twin 关系 API，兼容模组 InitTwin）。
function item.GetPlayerHUDTwinRole(player)
	if not player then
		return "solo"
	end
	local main = player.GetMainTwin and player:GetMainTwin() or nil
	local other = player.GetOtherTwin and player:GetOtherTwin() or nil
	local self_hash = GetPtrHash(player)
	local has_other = other and other.Exists and other:Exists()
	local main_is_self = main and GetPtrHash(main) == self_hash
	if has_other then
		if main_is_self or not main then
			return "main"
		end
		return "other"
	end
	-- Other twin may lack GetOtherTwin on some seats; MainTwin ≠ self ⇒ other.
	if main and GetPtrHash(main) ~= self_hash and main.Exists and main:Exists() then
		return "other"
	end
	return "solo"
end

function item.CardHudLayoutName(layout)
	if layout == nil then return "none" end
	if layout_equals(layout, "NORMAL", 0) then return "NORMAL" end
	if layout_equals(layout, "JACOB_AND_ESAU", 1) then return "JACOB_AND_ESAU" end
	if layout_equals(layout, "COMPACT", 2) then return "COMPACT" end
	if layout_equals(layout, "COMPACT_JACOB_AND_ESAU", 3) then return "COMPACT_JACOB_AND_ESAU" end
	return tostring(layout)
end

function item.CardUiStateName(state)
	if state == item.CARD_UI_STATE.NORMAL then return "NORMAL" end
	if state == item.CARD_UI_STATE.MAIN_TWIN then return "MAIN_TWIN" end
	if state == item.CARD_UI_STATE.OTHER_TWIN then return "OTHER_TWIN" end
	return "unsupported"
end

-- Player -> supported card anchor. Compact coop has no measured anchor and returns nil.
function item.GetPrimaryCardUIState(player)
	if not player then return nil end
	local layout = read_hud_layout(player)
	if layout ~= nil then
		if layout_equals(layout, "JACOB_AND_ESAU", 1) then
			if is_esau_seat(player) then return item.CARD_UI_STATE.OTHER_TWIN end
			return item.CARD_UI_STATE.MAIN_TWIN
		end
		if layout_equals(layout, "NORMAL", 0) then
			return item.CARD_UI_STATE.NORMAL
		end
		return nil
	end
	local tp = player:GetPlayerType()
	if tp == PlayerType.PLAYER_ESAU then return item.CARD_UI_STATE.OTHER_TWIN end
	if tp == PlayerType.PLAYER_JACOB then return item.CARD_UI_STATE.MAIN_TWIN end
	local p0 = Game():GetPlayer(0)
	if p0 and GetPtrHash(p0) == GetPtrHash(player) then
		return item.CARD_UI_STATE.NORMAL
	end
	return nil
end

-- Resource icons only have normal (1) and twin (2) anchors.
function item.GetResourceHUDState()
	local player = Game():GetPlayer(0)
	if not player then return 1 end
	local layout = read_hud_layout(player)
	if layout ~= nil then
		if layout_equals(layout, "JACOB_AND_ESAU", 1) or layout_equals(layout, "COMPACT_JACOB_AND_ESAU", 3) then
			return 2
		end
		return 1
	end
	local tp = player:GetPlayerType()
	if tp == PlayerType.PLAYER_JACOB or tp == PlayerType.PLAYER_ESAU then
		return 2
	end
	return 1
end

function item.GetHudAuditResourceState()
	local forced = item.debug_hud_audit and item.debug_hud_audit.resource_state
	if forced == 1 or forced == 2 then return forced end
	return item.GetResourceHUDState()
end

function item.DescribePrimaryCardHud(player)
	if not player then return nil end
	local state = item.GetPrimaryCardUIState(player)
	return {
		layout_name = item.CardHudLayoutName(read_hud_layout(player)),
		state_name = item.CardUiStateName(state),
		pos = item.PrimaryCardUIPos(player),
		player_type = player:GetPlayerType(),
	}
end

function item.GetHudDebugTune(kind, state)
	local root = item.debug_hud_tune and item.debug_hud_tune[kind]
	local tune = root and root[state]
	if tune then return Vector(tune.X or 0, tune.Y or 0) end
	return Vector(0, 0)
end

function item.GetCardDebugTune(state)
	return item.GetHudDebugTune("card", state)
end

function item.SetHudDebugTune(kind, state, axis, value)
	if not item.debug_hud_tune[kind] then item.debug_hud_tune[kind] = {} end
	local cur = item.GetHudDebugTune(kind, state)
	value = tonumber(value) or 0
	if axis == "x" then
		item.debug_hud_tune[kind][state] = Vector(value, cur.Y)
	else
		item.debug_hud_tune[kind][state] = Vector(cur.X, value)
	end
end

function item.ResetHudDebugTune(kind)
	if item.debug_hud_tune then item.debug_hud_tune[kind] = {} end
end

function item.ResetHudDebugTuneState(kind, state)
	local root = item.debug_hud_tune and item.debug_hud_tune[kind]
	if root then root[state] = nil end
end

function item.GetHudBaseDel(kind, state)
	local info = (item.optional_maker[kind] or {})[state]
	if not info or not info.del then return nil end
	return Vector(info.del.X, info.del.Y)
end

function item.GetHudAuditValues(kind, state)
	local base = item.GetHudBaseDel(kind, state)
	if not base then return nil end
	local tune = item.GetHudDebugTune(kind, state)
	return {
		base = base,
		tune = tune,
		final = Vector(base.X + tune.X, base.Y + tune.Y),
	}
end

function item.HudAuditFinalDel(kind, state)
	local values = item.GetHudAuditValues(kind, state)
	return values and values.final or nil
end

-- Primary pocket card render anchor. Debug tune stays here so UICardPos consumers are unchanged.
function item.PrimaryCardUIPos(player)
	local state = item.GetPrimaryCardUIState(player)
	if not state then return nil end
	return item.UICardPos(state) + item.GetCardDebugTune(state)
end

function item.CardRenderAnchorToVisibleCenter(render_pos)
	if not render_pos then return nil end
	return render_pos + (item.CARD_VISIBLE_CENTER_OFFSET or Vector(0, 0))
end

function item.PrimaryCardVisibleCenter(player)
	return item.CardRenderAnchorToVisibleCenter(item.PrimaryCardUIPos(player))
end

-- Overlay sprites for the visible 14×18 card use a center pivot, so they render at the visible center.
-- CARD_OVERLAY_LOCAL_OFFSET is only an extra measured nudge, not the crop-to-visible conversion.
function item.CardOverlayPos(player, kind)
	local pos = item.PrimaryCardVisibleCenter(player)
	if not pos then return nil end
	local off = item.CARD_OVERLAY_LOCAL_OFFSET and item.CARD_OVERLAY_LOCAL_OFFSET[kind]
	if off then return pos + off end
	return pos
end

function item.HudAuditGuidePos(kind, state)
	return item.UI_Pos(kind, state) + item.GetHudDebugTune(kind, state)
end

local function hud_audit_line(line)
	print(line)
	if Isaac.ConsoleOutput then Isaac.ConsoleOutput(line .. "\n") end
end

function item.PrintCardHudAudit()
	hud_audit_line("[HUD AUDIT]")
	local rows = {
		{ item.CARD_UI_STATE.NORMAL, "normal" },
		{ item.CARD_UI_STATE.MAIN_TWIN, "main_twin" },
		{ item.CARD_UI_STATE.OTHER_TWIN, "other_twin" },
	}
	for _, row in ipairs(rows) do
		local final = item.HudAuditFinalDel("card", row[1])
		if final then
			hud_audit_line(string.format("card.%s = Vector(%.1f, %.1f)", row[2], final.X, final.Y))
		end
	end
end

function item.PrintResourceHudAudit()
	hud_audit_line("[HUD AUDIT]")
	local kinds = { "coin", "bomb", "key" }
	local rows = { { 1, "normal" }, { 2, "twin" } }
	for _, kind in ipairs(kinds) do
		for _, row in ipairs(rows) do
			local final = item.HudAuditFinalDel(kind, row[1])
			if final then
				hud_audit_line(string.format("%s.%s = Vector(%.1f, %.1f)", kind, row[2], final.X, final.Y))
			end
		end
	end
end

local function draw_cross(pos, color, arm)
	if not (pos and Isaac.DrawLine and color) then return end
	arm = arm or 6
	Isaac.DrawLine(pos + Vector(-arm, 0), pos + Vector(arm, 0), color, color, 1)
	Isaac.DrawLine(pos + Vector(0, -arm), pos + Vector(0, arm), color, color, 1)
end

local function draw_pivot_box(pos, pivot_x, pivot_y, width, height, color)
	if not (pos and Isaac.DrawLine and color) then return end
	local top_left = pos - Vector(pivot_x, pivot_y)
	local size = Vector(width, height)
	local a = top_left
	local b = top_left + Vector(size.X, 0)
	local c = top_left + size
	local d = top_left + Vector(0, size.Y)
	Isaac.DrawLine(a, b, color, color, 1)
	Isaac.DrawLine(b, c, color, color, 1)
	Isaac.DrawLine(c, d, color, color, 1)
	Isaac.DrawLine(d, a, color, color, 1)
end

local function draw_label(pos, text, y_off)
	if not (pos and text and Isaac.RenderText) then return end
	Isaac.RenderText(text, math.floor(pos.X + 8), math.floor(pos.Y + (y_off or -14)), 1, 1, 1, 1)
end

function item.DrawHudAuditGuides()
	local audit = item.debug_hud_audit
	if not audit then return end
	local hud = Game():GetHUD()
	if hud and hud.IsVisible and not hud:IsVisible() then return end
	if audit.draw_card_guide then
		local anchor_color = KColor(1, 0.9, 0.2, 1)
		local visible_color = KColor(0.3, 0.9, 1, 1)
		local game = Game()
		local visible_size = item.CARD_VISIBLE_SIZE or Vector(14, 18)
		local visible_pivot = item.CARD_VISIBLE_PIVOT or Vector(7, 9)
		local short_name = {
			[item.CARD_UI_STATE.NORMAL] = "NORMAL",
			[item.CARD_UI_STATE.MAIN_TWIN] = "MAIN",
			[item.CARD_UI_STATE.OTHER_TWIN] = "OTHER",
		}
		for i = 0, game:GetNumPlayers() - 1 do
			local player = game:GetPlayer(i)
			local pos = player and item.PrimaryCardUIPos(player)
			if pos then
				local state = item.GetPrimaryCardUIState(player)
				draw_cross(pos, anchor_color, 7)
				-- Draw only the measured 14×18 visible card. Do not draw the 16×20 ANM2 crop:
				-- that crop includes 1px of transparent padding and is not the on-screen card.
				local visible = item.CardRenderAnchorToVisibleCenter(pos)
				if visible then
					draw_pivot_box(visible, visible_pivot.X, visible_pivot.Y, visible_size.X, visible_size.Y, visible_color)
					draw_cross(visible, visible_color, 2)
				end
				draw_label(pos, string.format("%s (%.1f, %.1f)", short_name[state] or item.CardUiStateName(state), pos.X, pos.Y), -14)
			end
		end
	end
	if audit.draw_resource_guide then
		local colors = {
			coin = KColor(1, 0.85, 0.2, 1),
			bomb = KColor(1, 0.35, 0.25, 1),
			key = KColor(0.4, 0.75, 1, 1),
		}
		local state = item.GetHudAuditResourceState()
		local state_name = state == 2 and "TWIN" or "NORMAL"
		for _, kind in ipairs({ "coin", "bomb", "key" }) do
			local pos = item.HudAuditGuidePos(kind, state)
			draw_cross(pos, colors[kind], 5)
			draw_label(pos, string.format("%s %s", string.upper(kind), state_name), -12)
		end
	end
end

function item.Screen2ScaleWorld(v) 
	return auxi.mul_t(v,item.myScreenToWorld(Vector(1,1)) - item.myScreenToWorld(Vector(0,0)))
end

function item.myScreenToWorld(pos)
	local room = Game():GetRoom()
	local pos_z = Vector(0,0)
	local r_pos_z = Isaac.WorldToScreen(pos_z) - room:GetRenderScrollOffset() - Game().ScreenShakeOffset
	local pos_d = Vector(100,100)
	local r_pos_d = Isaac.WorldToScreen(pos_d) - r_pos_z - room:GetRenderScrollOffset() - Game().ScreenShakeOffset
	r_pos_d = r_pos_d / 100
	local ret = (pos - r_pos_z)
	if r_pos_d.X ~= 0 then ret.X = ret.X / r_pos_d.X end
	if r_pos_d.Y ~= 0 then ret.Y = ret.Y / r_pos_d.Y end
	return ret
end

function item.myRenderPositionToWorld(pos)
	local room = Game():GetRoom()
	local pos_z = Vector(0,0)
	local r_pos_z = Isaac.WorldToRenderPosition(pos_z) - room:GetRenderScrollOffset() - Game().ScreenShakeOffset
	local pos_d = Vector(100,100)
	local r_pos_d = Isaac.WorldToRenderPosition(pos_d) - r_pos_z - room:GetRenderScrollOffset() - Game().ScreenShakeOffset
	r_pos_d = r_pos_d / 100
	local ret = (pos - r_pos_z)
	if r_pos_d.X ~= 0 then ret.X = ret.X / r_pos_d.X end
	if r_pos_d.Y ~= 0 then ret.Y = ret.Y / r_pos_d.Y end
	return ret
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_,cmd,params)
	if string.lower(cmd) == "meus" and params ~= nil then
		local args={}
		for str in string.gmatch(params, "([^ ]+)") do
			table.insert(args, str)
		end
		if args[1] then
			if string.lower(args[1]) == "please" then
				if args[2] and args[3] and args[4] and args[5] and args[6] then
					if args[2] == "ui" and tonumber(args[4]) ~= nil and tonumber(args[5]) ~= nil and tonumber(args[6]) ~= nil then
						if item.optional_maker[args[3]] and item.optional_maker[args[3]][tonumber(args[4])] then
							item.optional_maker[args[3]][tonumber(args[4])].del = Vector(tonumber(args[5]),tonumber(args[6]))
							print("Successfully turn to")
							print(item.optional_maker[args[3]][tonumber(args[4])].del)
						else
							print("Fail")
						end
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	item.active_slot_render = {}
end,
})

--meus please ui card 1 -20 -23

if ModCallbacks.MC_PRE_PLAYERHUD_RENDER_HEARTS then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_PLAYERHUD_RENDER_HEARTS,
		params = nil,
		Function = function(_, offset, _sprite, position, sprite_scale, player)
			if not item.debug_hud_audit then return end
			local seat = 1
			local p0 = Game():GetPlayer(0)
			if player and p0 and GetPtrHash(player) ~= GetPtrHash(p0) then
				seat = 2
			end
			item.debug_hud_audit.heart = {
				position = position and Vector(position.X, position.Y) or nil,
				offset = offset and Vector(offset.X, offset.Y) or nil,
				scale = sprite_scale,
				seat = seat,
				frame = Game():GetFrameCount(),
			}
		end,
	})
end

if ModCallbacks.MC_POST_HUD_RENDER then
	table.insert(item.post_ToCall, #item.post_ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_HUD_RENDER,
		params = nil,
		Function = function()
			item.DrawHudAuditGuides()
		end,
	})
end

local entity_head_anchor = require("Qing_Remaster_scripts.auxiliary.entity_head_anchor")

--- 实体头顶 Sprite 局部锚点（头层中轴 + 顶部 texel；见 entity_head_anchor）。
function item.GetEntityHeadAnchor(ent, options)
	return entity_head_anchor.GetEntityHeadAnchor(ent, options)
end

return item

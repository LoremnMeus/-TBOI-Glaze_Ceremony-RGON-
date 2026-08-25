local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	active_slot_render = {},
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
			[2] = {name = "GetScreenTopLeft",del = Vector(11,41),},			--双子卡牌
			[3] = {name = "GetScreenBottomRight",del = Vector(-10,-44),},	--双子卡牌
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

function item.PlayerActiveUIPos(player,slot,order,cid)
	if REPENTOGON then
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

return item

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Book_of_The_Law,
	own_key = "Item_Book_of_The_Law_",
	icon_anm2 = "gfx/ui/EID/eid_inline_icons.anm2",
	hud_orbit_speed = 0.012,
	hud_orbit_rx = 13,
	hud_orbit_ry = 10,
	fly_lift_frames = 14,
	fly_wait_frames = 16,
	fly_home_lerp = 0.22,
	fly_retire_lerp = 0.16,
	fly_arrive_dist = 8,
}

local TAU = math.pi * 2
local orbit_visual = {}
local hud_spin = {}
local hud_spin_frame = {}
local pool_icon_sprite = nil
local pool_border_sprite = nil

local POOL_MARKUP = {
	[ItemPoolType.POOL_TREASURE] = "{{ItemPoolTreasure}}",
	[ItemPoolType.POOL_SHOP] = "{{ItemPoolShop}}",
	[ItemPoolType.POOL_BOSS] = "{{ItemPoolBoss}}",
	[ItemPoolType.POOL_DEVIL] = "{{ItemPoolDevil}}",
	[ItemPoolType.POOL_ANGEL] = "{{ItemPoolAngel}}",
	[ItemPoolType.POOL_SECRET] = "{{ItemPoolSecret}}",
	[ItemPoolType.POOL_LIBRARY] = "{{ItemPoolLibrary}}",
	[ItemPoolType.POOL_SHELL_GAME] = "{{ItemPoolShellGame}}",
	[ItemPoolType.POOL_GOLDEN_CHEST] = "{{ItemPoolGoldenChest}}",
	[ItemPoolType.POOL_RED_CHEST] = "{{ItemPoolRedChest}}",
	[ItemPoolType.POOL_BEGGAR] = "{{ItemPoolBeggar}}",
	[ItemPoolType.POOL_DEMON_BEGGAR] = "{{ItemPoolDemonBeggar}}",
	[ItemPoolType.POOL_CURSE] = "{{ItemPoolCurse}}",
	[ItemPoolType.POOL_KEY_MASTER] = "{{ItemPoolKeyMaster}}",
	[ItemPoolType.POOL_BATTERY_BUM] = "{{ItemPoolBatteryBum}}",
	[ItemPoolType.POOL_MOMS_CHEST] = "{{ItemPoolMomsChest}}",
	[ItemPoolType.POOL_GREED_TREASURE] = "{{ItemPoolGreedTreasure}}",
	[ItemPoolType.POOL_GREED_BOSS] = "{{ItemPoolGreedBoss}}",
	[ItemPoolType.POOL_GREED_SHOP] = "{{ItemPoolGreedShop}}",
	[ItemPoolType.POOL_GREED_DEVIL] = "{{ItemPoolGreedDevil}}",
	[ItemPoolType.POOL_GREED_ANGEL] = "{{ItemPoolGreedAngel}}",
	[ItemPoolType.POOL_GREED_CURSE] = "{{ItemPoolGreedCurse}}",
	[ItemPoolType.POOL_GREED_SECRET] = "{{ItemPoolGreedSecret}}",
	[ItemPoolType.POOL_CRANE_GAME] = "{{ItemPoolCraneGame}}",
	[ItemPoolType.POOL_ULTRA_SECRET] = "{{ItemPoolUltraSecret}}",
	[ItemPoolType.POOL_BOMB_BUM] = "{{ItemPoolBombBum}}",
	[ItemPoolType.POOL_PLANETARIUM] = "{{ItemPoolPlanetarium}}",
	[ItemPoolType.POOL_OLD_CHEST] = "{{ItemPoolOldChest}}",
	[ItemPoolType.POOL_BABY_SHOP] = "{{ItemPoolBabyShop}}",
	[ItemPoolType.POOL_WOODEN_CHEST] = "{{ItemPoolWoodenChest}}",
	[ItemPoolType.POOL_ROTTEN_BEGGAR] = "{{ItemPoolRottenBeggar}}",
}

local function law_queue()
	save.elses.book_of_the_law = save.elses.book_of_the_law or {}
	return save.elses.book_of_the_law
end

local function pool_frame(pool)
	pool = tonumber(pool) or ItemPoolType.POOL_TREASURE
	if pool < 0 or pool >= ItemPoolType.NUM_ITEMPOOLS then
		return ItemPoolType.POOL_TREASURE
	end
	return pool
end

local function pool_markup(pool)
	pool = pool_frame(pool)
	if EID and EID.ItemPoolTypeToMarkup and EID.ItemPoolTypeToMarkup[pool] then
		return EID.ItemPoolTypeToMarkup[pool]
	end
	return POOL_MARKUP[pool] or "{{ItemPoolTreasure}}"
end

local function ensure_pool_sprites()
	if pool_icon_sprite then
		return
	end
	pool_icon_sprite = Sprite()
	pool_icon_sprite:Load(item.icon_anm2, true)
	pool_border_sprite = Sprite()
	pool_border_sprite:Load(item.icon_anm2, true)
	pool_border_sprite:SetFrame("Blank", 0)
end

local function wrap_angle(a)
	local t = a / TAU
	return (t - math.floor(t)) * TAU
end

local function lerp_angle(a, b, t)
	local d = wrap_angle(b - a)
	if d > math.pi then
		d = d - TAU
	end
	return a + d * math.max(0, math.min(1, t))
end

local function orbit_target(i, n, spin)
	if n <= 0 then
		return spin or 0
	end
	return (spin or 0) + (i - 1) * (TAU / n) - math.pi * 0.5
end

local function icon_center_shift(scale)
	scale = scale or 1
	local frame = pool_icon_sprite and pool_icon_sprite.GetLayerFrameData and pool_icon_sprite:GetLayerFrameData(0)
	if frame and frame.GetPivot and frame.GetWidth and frame.GetHeight then
		local pivot = frame:GetPivot()
		local w, h = frame:GetWidth(), frame:GetHeight()
		if pivot and w and h and w > 0 and h > 0 then
			return Vector((pivot.X - w * 0.5) * scale, (pivot.Y - h * 0.5) * scale)
		end
	end
	return Vector(-5.5 * scale, -5.5 * scale)
end

local function player_visual(player)
	local idx = player and player:GetData().__Index
	if idx == nil then
		return nil
	end
	orbit_visual[idx] = orbit_visual[idx] or {icons = {}}
	return orbit_visual[idx]
end

local function collect_orbit_icons(vis)
	local out = {}
	for _, ic in ipairs(vis.icons or {}) do
		if ic.mode == "orbit" then
			out[#out + 1] = ic
		end
	end
	table.sort(out, function(a, b)
		return (a.queue_idx or 0) < (b.queue_idx or 0)
	end)
	return out
end

local function sync_orbit_icons(player)
	local vis = player_visual(player)
	if not vis then
		return
	end
	local queue = law_queue()
	local orbit_icons = collect_orbit_icons(vis)
	while #orbit_icons < #queue do
		local pool = queue[#orbit_icons + 1]
		local idx = #orbit_icons + 1
		vis.icons[#vis.icons + 1] = {
			pool = pool_frame(pool),
			mode = "orbit",
			queue_idx = idx,
			angle = nil,
			screen = Vector.Zero,
			alpha = 1,
		}
		orbit_icons[#orbit_icons + 1] = vis.icons[#vis.icons]
	end
	for i, ic in ipairs(orbit_icons) do
		ic.queue_idx = i
	end
end

local function find_law_pickup(colid)
	if not colid or colid <= 0 then
		return nil
	end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, colid)) do
		if ent:Exists() then
			local d = ent:GetData()
			if d[item.own_key.."law_spawn"] then
				return ent
			end
		end
	end
	return nil
end

local function pickup_screen_pos(pickup)
	local po = pickup.PositionOffset or Vector.Zero
	return Isaac.WorldToScreen(pickup.Position + po)
end

local function smoothstep(t)
	if t < 0 then
		return 0
	end
	if t > 1 then
		return 1
	end
	return t * t * (3 - 2 * t)
end

local function player_fly_retire_pos(player)
	local po = player.PositionOffset or Vector.Zero
	return Isaac.WorldToScreen(player.Position + po) + Vector(0, -28)
end

local function begin_fly_icon(ic)
	ic.mode = "fly"
	ic.fly_phase = "lift"
	ic.fly_timer = 0
	ic.fly_start = Vector(ic.screen.X, ic.screen.Y)
	ic.fly_lift_end = ic.fly_start + Vector(0, -10)
end

local function tick_fly_icon(ic, player)
	ic.fly_timer = (ic.fly_timer or 0) + 1
	local phase = ic.fly_phase or "lift"
	local pickup = find_law_pickup(ic.fly_colid)

	if phase == "lift" then
		local u = smoothstep(ic.fly_timer / math.max(1, item.fly_lift_frames))
		ic.screen = ic.fly_start + (ic.fly_lift_end - ic.fly_start) * u
		if ic.fly_timer >= item.fly_lift_frames then
			ic.fly_phase = "wait"
			ic.fly_timer = 0
			ic.screen = Vector(ic.fly_lift_end.X, ic.fly_lift_end.Y)
		end
		return
	end

	if phase == "wait" then
		local bob = math.sin(ic.fly_timer * 0.28) * 1.2
		ic.screen = ic.fly_lift_end + Vector(0, bob)
		if ic.fly_timer >= item.fly_wait_frames then
			if pickup then
				ic.fly_phase = "home"
			else
				ic.fly_phase = "retire"
				ic.mode = "fade"
			end
			ic.fly_timer = 0
		end
		return
	end

	if phase == "home" then
		if not pickup then
			ic.fly_phase = "retire"
			ic.mode = "fade"
			ic.fly_timer = 0
			return
		end
		local target = pickup_screen_pos(pickup)
		ic.screen = ic.screen + (target - ic.screen) * item.fly_home_lerp
		if (target - ic.screen):Length() <= item.fly_arrive_dist then
			ic.alpha = (ic.alpha or 1) - 0.12
		end
		return
	end

	if phase == "retire" then
		local target = player_fly_retire_pos(player)
		ic.screen = ic.screen + (target - ic.screen) * item.fly_retire_lerp
		ic.alpha = (ic.alpha or 1) - 0.045
	end
end

function item.notify_pool_consumed(pool, colid, player)
	if not player then
		player = auxi.have_player_has_collectible(item.entity)
	end
	if not player then
		return
	end
	local vis = player_visual(player)
	if not vis then
		return
	end
	save.elses[item.own_key.."pending_colid"] = colid
	local orbit_icons = collect_orbit_icons(vis)
	if orbit_icons[1] then
		begin_fly_icon(orbit_icons[1])
		orbit_icons[1].fly_colid = colid
		orbit_icons[1].fly_pool = pool_frame(pool)
	end
	for i, ic in ipairs(collect_orbit_icons(vis)) do
		ic.queue_idx = i
	end
end

local function tick_fly_visuals(player)
	if not auxi.has_have_coll(player, item.entity) then
		return
	end
	sync_orbit_icons(player)
	local vis = player_visual(player)
	if not vis or #(vis.icons or {}) <= 0 then
		return
	end

	for i = #vis.icons, 1, -1 do
		local ic = vis.icons[i]
		if ic.mode == "fly" or ic.mode == "fade" then
			tick_fly_icon(ic, player)
			if (ic.alpha or 1) <= 0.02 then
				table.remove(vis.icons, i)
			end
		end
	end
end

local function render_pool_icon(screen_pos, pool, alpha, highlight, scale)
	ensure_pool_sprites()
	scale = scale or 1
	local draw_pos = screen_pos + icon_center_shift(scale)
	if highlight then
		pool_border_sprite.Color = Color(1, 1, 1, alpha * 0.95, 1, 1, 1)
		pool_border_sprite.Scale = Vector(scale * 1.18, scale * 1.18)
		pool_border_sprite:Render(draw_pos, Vector.Zero, Vector.Zero)
	end
	pool_icon_sprite:SetFrame("ItemPools", pool_frame(pool))
	pool_icon_sprite.Color = Color(1, 1, 1, alpha)
	pool_icon_sprite.Scale = Vector(scale, scale)
	pool_icon_sprite:Render(draw_pos, Vector.Zero, Vector.Zero)
end

local function render_orbit_visuals(player, slot)
	if not auxi.has_have_coll(player, item.entity) then
		return
	end
	sync_orbit_icons(player)
	local vis = player_visual(player)
	if not vis or #(vis.icons or {}) <= 0 then
		return
	end
	local info = ui.GetActiveSlotRenderInfo(player, slot)
	local hud_a = (info and info.alpha) or 1
	local slot_scale = (info and tonumber(info.scale)) or 1
	local center = ui.PlayerActiveUIPos(player, slot, auxi.GetPlayerOrder(player), item.entity)
	local idx = player:GetData().__Index
	if idx == nil then
		return
	end
	local frame = Game():GetFrameCount()
	if hud_spin_frame[idx] ~= frame then
		hud_spin[idx] = (hud_spin[idx] or 0) + (item.hud_orbit_speed or 0.012)
		hud_spin_frame[idx] = frame
	end
	local spin = hud_spin[idx] or 0
	local rx = (item.hud_orbit_rx or 13) * slot_scale
	local ry = (item.hud_orbit_ry or 10) * slot_scale
	local orbit_icons = collect_orbit_icons(vis)
	local n = math.max(#law_queue(), #orbit_icons)
	for i, ic in ipairs(orbit_icons) do
		local target = orbit_target(i, n, spin)
		ic.angle = lerp_angle(ic.angle or target, target, 0.12)
		ic.screen = center + Vector(math.cos(ic.angle) * rx, math.sin(ic.angle) * ry)
	end
	for i, ic in ipairs(vis.icons) do
		if ic.mode == "orbit" or ic.mode == "fly" or ic.mode == "fade" then
			local highlight = ic.mode == "orbit" and (ic.queue_idx or 0) == 1
			render_pool_icon(ic.screen, ic.pool, (ic.alpha or 1) * hud_a, highlight, slot_scale)
		end
	end
end

local function pool_queue_eid_line(queue)
	if not queue or #queue <= 0 then
		return ""
	end
	local zh = auxi.get_EID_language() == "zh_cn"
	local parts = {}
	for i, pool in ipairs(queue) do
		parts[#parts + 1] = pool_markup(pool)
	end
	if zh then
		return "#待生效池：" .. table.concat(parts, " → ")
	end
	return "#Queued pools: " .. table.concat(parts, " → ")
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, coltyp, rng, player, useFlags, activeSlot, customVarData)
	if coltyp ~= item.entity then
		return
	end
	local queue = law_queue()
	local typ = Game():GetItemPool():GetPoolForRoom(
		Game():GetRoom():GetType(),
		Game():GetLevel():GetCurrentRoomDesc().SpawnSeed
	)
	if typ == -1 then
		typ = ItemPoolType.POOL_TREASURE
	end
	table.insert(queue, typ)
	if auxi.should_do_belial(player) and typ == ItemPoolType.POOL_DEVIL then
		table.insert(queue, typ)
		table.insert(queue, typ)
	end
	sync_orbit_icons(player)
	return true
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = nil,
Function = function(_, ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.WISP and ent.SubType == item.entity then
		local player = ent.Player
		if player then
			player:UseActiveItem(item.entity, 11, -1)
		end
	end
end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil,
Function = function(_, pooltp, decrease, seed)
	local queue = law_queue()
	if #queue <= 0 or Game():GetFrameCount() <= 5 then
		return
	end
	if save.elses.book_of_the_law_mutex == true then
		return
	end
	local typ = pool_frame(queue[1])
	if typ == pooltp then
		return
	end
	save.elses.book_of_the_law_mutex = true
	local colid = Game():GetItemPool():GetCollectible(typ, decrease, seed)
	if decrease then
		local player = auxi.have_player_has_collectible(item.entity)
		item.notify_pool_consumed(typ, colid, player)
		table.remove(queue, 1)
	end
	save.elses.book_of_the_law_mutex = nil
	return colid
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = nil,
Function = function(_, pickup)
	if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		return
	end
	local pending = save.elses[item.own_key.."pending_colid"]
	if pending and pickup.SubType == pending then
		pickup:GetData()[item.own_key.."law_spawn"] = true
		save.elses[item.own_key.."pending_colid"] = nil
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	if auxi.has_have_coll(player, item.entity) then
		tick_fly_visuals(player)
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_, player, tp, cid, slot)
	if cid ~= item.entity then
		return
	end
	render_orbit_visuals(player, slot)
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses.book_of_the_law = {}
		save.elses.book_of_the_law_mutex = nil
		save.elses[item.own_key.."pending_colid"] = nil
		orbit_visual = {}
		hud_spin = {}
		hud_spin_frame = {}
	end
end,
})

if EID then
	EID:addDescriptionModifier("qing_book_of_the_law_queue", function(desc)
		return desc.ObjType == 5
			and desc.ObjVariant == 100
			and desc.ObjSubType == item.entity
			and #law_queue() > 0
	end, function(desc)
		EID:appendToDescription(desc, pool_queue_eid_line(law_queue()))
		return desc
	end)
end

return item

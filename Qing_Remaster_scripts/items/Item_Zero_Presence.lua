-- Zero Presence：地面只藏道具图标层；攻击经 Attack Trigger 追加不存在感眼泪；
-- 获得新道具时可能逃逸回刚刚被取走的底座（RESTORE，非 NEW OFFER）。
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local classifier = attack_holder.classifier
local collectible_holder = require("Qing_Remaster_scripts.callbacks.collectible_holder")
local pedestal_restore = require("Qing_Remaster_scripts.auxiliary.pedestal_restore")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Zero_Presence,
	own_key = "Item_Zero_Presence_",
	tear_chance = 0.20,
	escape_chance = 0.20,
	-- Vanilla 005.100_collectible.anm2：道具图标在 head；sparkle/itemshadow 随图标一起藏。
	-- pedestal 相关 body / shadow / altar 保持可见。
	icon_layers = { "head", "sparkle", "itemshadow" },
	flicker_hide_min = 90,
	flicker_hide_max = 240,
	flicker_show_min = 8,
	flicker_show_max = 20,
	-- Pickup UPDATE is ~30Hz; short fades read as “presence restored then lost”.
	flicker_fade_in_frames = 5,
	flicker_fade_out_frames = 6,
	-- Ground EID stays blank while the icon is still mostly gone.
	eid_visible_alpha = 0.15,
	tear_alpha = 0.22,
	-- Session-only debug: next eligible POST_GAIN skips escape roll.
	force_next_escape = false,
	-- 本房间逃逸成功后，举起零存在感时复写风味 Desc（换房清除）
	escape_flavor_room = false,
}

local function player_has_item(player)
	return player and auxi.has_have_coll(player, item.entity)
end

local function safe_layer(sprite, id)
	if not sprite or not sprite.GetLayer or id == nil then
		return nil
	end
	local ok, layer = pcall(function()
		return sprite:GetLayer(id)
	end)
	if ok then
		return layer
	end
	return nil
end

local function set_icon_alpha(sprite, alpha)
	if not sprite then
		return
	end
	local a = math.max(0, math.min(1, tonumber(alpha) or 0))
	local color = Color(1, 1, 1, a, 0, 0, 0)
	for _, name in ipairs(item.icon_layers) do
		local layer = safe_layer(sprite, name)
		if layer and layer.SetColor then
			layer:SetColor(color)
			if layer.SetVisible then
				layer:SetVisible(a > 0.01)
			end
		end
	end
end

local function roll_hide_frames(rng)
	local span = item.flicker_hide_max - item.flicker_hide_min
	return item.flicker_hide_min + rng:RandomInt(span + 1)
end

local function roll_show_frames(rng)
	local span = item.flicker_show_max - item.flicker_show_min
	return item.flicker_show_min + rng:RandomInt(span + 1)
end

local function flicker_alpha(st)
	return math.max(0, math.min(1, tonumber(st and st.alpha) or 0))
end

--- True while the ground icon is absent / nearly absent (EID ground gate).
function item.is_ground_overlay_hidden(pickup)
	if not pickup or pickup.SubType ~= item.entity then
		return false
	end
	local st = pickup:GetData()[item.own_key .. "flicker"]
	if not st then
		return true
	end
	return flicker_alpha(st) < item.eid_visible_alpha
end

-- EID skips entities with GetData().EID_Hide (hasDescription → false). Same flag Fool / Death Field use.
local function sync_eid_hide(pickup)
	if not pickup then
		return
	end
	local d = pickup:GetData()
	if item.is_ground_overlay_hidden(pickup) then
		d.EID_Hide = true
	else
		d.EID_Hide = nil
	end
end

local function ensure_flicker_state(pickup)
	local d = pickup:GetData()
	local st = d[item.own_key .. "flicker"]
	if st then
		return st
	end
	local rng = pickup:GetDropRNG()
	st = {
		-- hidden | fade_in | shown | fade_out
		phase = "hidden",
		timer = roll_hide_frames(rng),
		alpha = 0,
	}
	d[item.own_key .. "flicker"] = st
	set_icon_alpha(pickup:GetSprite(), 0)
	return st
end

local function tick_flicker(pickup)
	local st = ensure_flicker_state(pickup)
	local rng = pickup:GetDropRNG()
	st.timer = (st.timer or 0) - 1

	if st.phase == "hidden" then
		st.alpha = 0
		if st.timer <= 0 then
			st.phase = "fade_in"
			st.timer = item.flicker_fade_in_frames
		end
	elseif st.phase == "fade_in" then
		local total = math.max(1, item.flicker_fade_in_frames)
		local left = math.max(0, st.timer)
		st.alpha = 1 - (left / total)
		if st.timer <= 0 then
			st.phase = "shown"
			st.timer = roll_show_frames(rng)
			st.alpha = 1
		end
	elseif st.phase == "shown" then
		st.alpha = 1
		if st.timer <= 0 then
			st.phase = "fade_out"
			st.timer = item.flicker_fade_out_frames
		end
	elseif st.phase == "fade_out" then
		local total = math.max(1, item.flicker_fade_out_frames)
		local left = math.max(0, st.timer)
		st.alpha = left / total
		if st.timer <= 0 then
			st.phase = "hidden"
			st.timer = roll_hide_frames(rng)
			st.alpha = 0
		end
	else
		st.phase = "hidden"
		st.timer = roll_hide_frames(rng)
		st.alpha = 0
	end

	set_icon_alpha(pickup:GetSprite(), flicker_alpha(st))
	sync_eid_hide(pickup)
	return st
end

local function apply_zero_presence_tear(tear)
	if not tear then
		return
	end
	if tear.AddTearFlags then
		if TearFlags.TEAR_PIERCING then
			tear:AddTearFlags(TearFlags.TEAR_PIERCING)
		end
		if TearFlags.TEAR_HOMING then
			tear:AddTearFlags(TearFlags.TEAR_HOMING)
		end
	else
		local flags = tear.TearFlags or TearFlags.TEAR_NORMAL
		if TearFlags.TEAR_PIERCING then
			flags = flags | TearFlags.TEAR_PIERCING
		end
		if TearFlags.TEAR_HOMING then
			flags = flags | TearFlags.TEAR_HOMING
		end
		tear.TearFlags = flags
	end
	local c = tear.Color
	tear.Color = Color(c.R, c.G, c.B, item.tear_alpha, c.RO, c.GO, c.BO)
	tear:GetData()[item.own_key .. "tear"] = true
end

local function pedestal_is_valid_escape_target(pedestal)
	if not pedestal or not pedestal.Exists or not pedestal:Exists() then
		return false
	end
	local q = pedestal.ToPickup and pedestal:ToPickup() or nil
	if not q then
		return false
	end
	if q.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		return false
	end
	return (tonumber(q.SubType) or 0) <= 0
end

function item.debug_force_next_escape()
	item.force_next_escape = true
	return true
end

function item.debug_clear_force_escape()
	item.force_next_escape = false
end

local function try_escape(player, gained_id, gain_context)
	if not player_has_item(player) then
		return false
	end
	if gained_id == item.entity then
		return false
	end

	local force = item.force_next_escape == true
	if force then
		item.force_next_escape = false
	else
		local rng = player:GetCollectibleRNG(item.entity)
		if rng:RandomFloat() >= item.escape_chance then
			return false
		end
	end

	if not gain_context then
		return false
	end
	local pedestal = gain_context.pedestal or gain_context.pickup
	if not pedestal_is_valid_escape_target(pedestal) then
		return false
	end

	-- Rematerialize first; only remove inventory copy on success.
	local restored = pedestal_restore.rematerialize_on_existing(
		pedestal,
		{
			collectible_id = item.entity,
			touched = true,
			charge = 0,
		},
		item.own_key
	)
	if not restored then
		return false
	end

	player:RemoveCollectible(item.entity)
	collectible_holder.clear_last_gain_context(player)
	item.escape_flavor_room = true
	return true
end

local function escape_flavor_text()
	local lang = Options and Options.Language or ""
	if lang == "zh" or lang == "zh_cn" or lang == "zh_CN" then
		return "你差点忘了它"
	end
	if auxi.get_EID_language and auxi.get_EID_language() == "zh_cn" then
		return "你差点忘了它"
	end
	return "You almost forgot it"
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		item.escape_flavor_room = false
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM,
	params = "Item",
	Function = function(_, player, tp, id, value)
		if id ~= item.entity or not item.escape_flavor_room then
			return
		end
		return {
			Name = value and value.Name or "",
			Description = escape_flavor_text(),
		}
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_INIT,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup)
		if pickup.SubType ~= item.entity then
			return
		end
		pickup:GetData()[item.own_key .. "ground"] = true
		ensure_flicker_state(pickup)
		sync_eid_hide(pickup)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup)
		if pickup.SubType ~= item.entity then
			return
		end
		tick_flicker(pickup)
	end,
})

-- Keep icon alpha after engine sprite refresh (Appear / Idle swap).
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_RENDER,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup, _)
		if pickup.SubType ~= item.entity then
			return
		end
		local st = pickup:GetData()[item.own_key .. "flicker"]
		if not st then
			return
		end
		set_icon_alpha(pickup:GetSprite(), flicker_alpha(st))
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_ATTACK_ONCE,
	params = nil,
	Function = function(_, event)
		local player = event and event.player
		local attack = event and event.attack
		local ent = event and event.member
		if not player_has_item(player) or not attack or not ent then
			return
		end
		if classifier.IsSyntheticSampleAttack(attack) then
			return
		end
		attack.tags = attack.tags or {}
		if attack.tags.zero_presence_checked then
			return
		end
		attack.tags.zero_presence_checked = true

		local rng = player:GetCollectibleRNG(item.entity)
		if rng:RandomFloat() >= item.tear_chance then
			return
		end

		local source = event.attack_source or attack.source
		local aim = classifier.GetAttackAimContext(source, attack, event)
		local speed = (player.ShotSpeed or 1) * 10
		local pos = (aim and aim.position) or player.Position
		local dir = (aim and aim.direction) or Vector(1, 0)
		local q = attack_holder.FireTear(player, pos, dir * speed, {
			mode = "inherit",
			role = "derived",
			reason = "zero_presence",
			attack = attack,
			family = "tear",
			can_be_eye = false,
		})
		if q then
			apply_zero_presence_tear(q)
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE,
	params = nil,
	Function = function(_, player, colid, _cnt, _touched, _prev, _from_direct, gain_context)
		try_escape(player, colid, gain_context)
	end,
})

return item

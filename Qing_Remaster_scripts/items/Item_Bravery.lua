-- 勇气：未清理的 Boss / 挑战 / Boss Rush 中，按指定方式离开后，在新房间掉落并拒绝再次拾取。
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local g = require("Qing_Remaster_scripts.core.globals")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local pedestal_restore = require("Qing_Remaster_scripts.auxiliary.pedestal_restore")
local morph_txn = require("Qing_Remaster_scripts.others.Pickup_Morph_Transaction_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Bravery,
	own_key = "Item_Bravery_",
}

local ESCAPE_WINDOW = 2
-- 新房间持续重试掉落。超过该房间帧仍失败才放弃，避免前两帧生成失败把待掉落丢掉。
local DROP_GIVE_UP_FRAME = 30
local TOUCH_COOLDOWN = 30
local SPEECH_DURATION = 30
local SPEECH_RISE = 40
local PICKUP_COLLECTIBLE = PickupVariant.PICKUP_COLLECTIBLE

local LINES = {
	zh = {
		coward = "懦夫。",
		refuse = "我拒绝你。",
		kill = "杀了我吧。",
	},
	en = {
		coward = "Coward.",
		refuse = "I refuse you.",
		kill = "Kill me, then.",
	},
}

-- 短命离房提示与待掉落标记只活在当前 Lua 运行时。后悔药 / Continue rewind 会清掉它们。
local use_hint = {}
local door_hint = {}
local portal_hint = {}
local pending = {}
local exit_token = 0
local settle_token = 0
local touch_cd = {}
local touch_step = {}
local speech = nil

local function game_frame()
	return Game():GetFrameCount()
end

local function rewind_transition()
	return save.should_load == true or save.should_load2 == true
end

local function player_key(player)
	if not player or not player.ToPlayer then
		return nil
	end
	player = player:ToPlayer()
	if not player then
		return nil
	end
	local data = player:GetData()
	local idx = data and data.__Index
	if idx == nil then
		return nil
	end
	return tostring(idx)
end

local function holds_bravery(player)
	return player and player:GetCollectibleNum(item.entity) > 0
end

local function escape_room()
	local room = Game():GetRoom()
	if not room or room:IsClear() then
		return false
	end
	local kind = room:GetType()
	return kind == RoomType.ROOM_BOSS
		or kind == RoomType.ROOM_CHALLENGE
		or kind == RoomType.ROOM_BOSSRUSH
end

local function hint_fresh(frame, now)
	if type(frame) ~= "number" then
		return false
	end
	local delta = now - frame
	return delta >= 0 and delta <= ESCAPE_WINDOW
end

local function extra_animation_finished(player)
	if not player or not player.IsExtraAnimationFinished then
		return true
	end
	return player:IsExtraAnimationFinished() == true
end

-- 使用后 2 帧内离开，或这次使用立刻接上的 Extra 动画结束前后离开。
local function use_escape_ready(rec, now)
	if type(rec) ~= "table" or type(rec.use_frame) ~= "number" then
		return false
	end
	if hint_fresh(rec.use_frame, now) then
		return true
	end
	if rec.saw_extra_animation ~= true then
		return false
	end
	if type(rec.extra_finish_frame) ~= "number" then
		return true
	end
	return hint_fresh(rec.extra_finish_frame, now)
end

local function observe_use_hint(player)
	local key = player_key(player)
	if not key then
		return
	end
	local rec = use_hint[key]
	if type(rec) ~= "table" or type(rec.use_frame) ~= "number" then
		return
	end
	local now = game_frame()
	local finished = extra_animation_finished(player)
	if rec.saw_extra_animation ~= true then
		if not finished and now - rec.use_frame <= ESCAPE_WINDOW then
			rec.saw_extra_animation = true
			return
		end
		if now - rec.use_frame > ESCAPE_WINDOW then
			use_hint[key] = nil
		end
		return
	end
	if rec.extra_finish_frame == nil then
		if finished then
			rec.extra_finish_frame = now
		end
		return
	end
	if now - rec.extra_finish_frame > ESCAPE_WINDOW then
		use_hint[key] = nil
	end
end

local function language_key()
	local language = Options and Options.Language or "en"
	if language == "zh" or language == "zh_cn" or language == "zh_CN" or language == "zh_tw" or language == "zh_TW" then
		return "zh"
	end
	return "en"
end

local function clear_speech()
	speech = nil
end

local function say(pos, key)
	local line = LINES[language_key()][key]
	if not line or not pos then
		return
	end
	local chars = auxi.spilt_string(line)
	speech = {
		text = line,
		position = Vector(pos.X - (#chars) / 2, pos.Y - 36),
		age = 0,
		duration = SPEECH_DURATION,
		offset = Vector(0, 0),
		alpha = 1,
	}
end

local function advance_speech()
	if not speech then
		return
	end
	local duration = speech.duration or SPEECH_DURATION
	if duration <= 0 then
		clear_speech()
		return
	end
	speech.age = (speech.age or 0) + 1
	if speech.age >= duration then
		clear_speech()
		return
	end
	local t = speech.age / duration
	speech.offset = Vector(0, -SPEECH_RISE * t)
	speech.alpha = 1 - t
end

local function draw_speech()
	if not speech or not speech.text or not speech.position then
		return
	end
	local alpha = speech.alpha or 1
	if alpha <= 0 then
		return
	end
	local offset = speech.offset or Vector(0, 0)
	local pos = Isaac.WorldToScreen(speech.position + offset)
	gui.draw_text_units(speech.text, pos.X, pos.Y, 1, 1, KColor(1, 1, 1, alpha), nil)
end

local function clear_hints()
	use_hint = {}
	door_hint = {}
	portal_hint = {}
end

local function clear_runtime()
	clear_hints()
	pending = {}
	touch_cd = {}
	touch_step = {}
	exit_token = 0
	settle_token = 0
	clear_speech()
end

local function note_use(player)
	if rewind_transition() or not g.is_gameplay_world_active() then
		return
	end
	if not escape_room() or not holds_bravery(player) then
		return
	end
	local key = player_key(player)
	if not key then
		return
	end
	use_hint[key] = {
		use_frame = game_frame(),
		saw_extra_animation = false,
		extra_finish_frame = nil,
	}
end

local function note_hint(store, player)
	if rewind_transition() or not g.is_gameplay_world_active() then
		return
	end
	if not escape_room() or not holds_bravery(player) then
		return
	end
	local key = player_key(player)
	if not key then
		return
	end
	store[key] = game_frame()
end

local function rejected_data(pickup)
	if not pickup or not pickup.GetData then
		return nil
	end

	local data = pickup:GetData()

	local function get_rejected()
		local bag = data._Data and data._Data[item.own_key]
		if type(bag) == "table" and bag.rejected == true then
			return bag
		end
		return nil
	end

	local bag = get_rejected()
	if bag then
		return bag
	end

	-- 回房后的实体可能没有原来的 GetData，通过 Consistance 恢复已登记的业务记录。
	if consistance_holder.try_check_entity(pickup, item.own_key) then
		return get_rejected()
	end

	return nil
end

local function mark_rejected(pickup)
	local data = pickup:GetData()
	data._Data = data._Data or {}
	data._Data[item.own_key] = { rejected = true }
	consistance_holder.try_hold_entity(pickup, item.own_key, {
		consistance = true,
	})
end

local function drop_rejected(player)
	local pedestal = pedestal_restore.spawn_owned_collectible(
		item.own_key,
		{
			collectible_id = item.entity,
			touched = true,
			charge = 0,
		},
		player.Position,
		player,
		mark_rejected
	)
	if not pedestal then
		return false
	end
	player:RemoveCollectible(item.entity)
	unique_holder.request_evaluate_items(player, CacheFlag.CACHE_DAMAGE)
	say(pedestal.Position, "refuse")
	return true
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_EVALUATE_CACHE,
	params = nil,
	Function = function(_, player, cacheFlag)
		if cacheFlag ~= CacheFlag.CACHE_DAMAGE then
			return
		end
		local count = player:GetCollectibleNum(item.entity)
		if count > 0 then
			player.Damage = player.Damage + 2 * count
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_ITEM,
	params = nil,
	Function = function(_, _collectible, _rng, player)
		note_use(player)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = nil,
	Function = function(_, _card, player)
		note_use(player)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_PILL,
	params = nil,
	Function = function(_, _pill, player)
		note_use(player)
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GET_TELEPORT,
	params = nil,
	Function = function(_, player, kind)
		if kind == "door" then
			note_hint(door_hint, player)
		elseif kind == "portal" then
			note_hint(portal_hint, player)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_ROOM_EXIT,
	params = nil,
	Function = function(_, _player, newLevel)
		exit_token = exit_token + 1
		if rewind_transition() or not g.is_gameplay_world_active() or not escape_room() then
			clear_hints()
			return
		end
		local now = game_frame()
		local leaving_level = newLevel == true
		for _, player in ipairs(auxi.GetPlayers()) do
			local key = player_key(player)
			if key and holds_bravery(player) then
				local fled = leaving_level
					or use_escape_ready(use_hint[key], now)
					or hint_fresh(door_hint[key], now)
					or hint_fresh(portal_hint[key], now)
				if fled then
					pending[key] = exit_token
				end
			end
		end
		clear_hints()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		settle_token = exit_token
		touch_cd = {}
		touch_step = {}
		use_hint = {}
		clear_speech()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PEFFECT_UPDATE,
	params = nil,
	Function = function(_, player)
		observe_use_hint(player)
		local key = player_key(player)
		if not key then
			return
		end
		local mark = pending[key]
		if mark == nil or mark ~= settle_token then
			return
		end
		if rewind_transition() or not g.is_gameplay_world_active() then
			pending[key] = nil
			return
		end
		local room = Game():GetRoom()
		if not room then
			return
		end
		local frame = tonumber(room:GetFrameCount()) or 0
		if frame > DROP_GIVE_UP_FRAME then
			pending[key] = nil
			return
		end
		if not holds_bravery(player) then
			pending[key] = nil
			return
		end
		if drop_rejected(player) then
			pending[key] = nil
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		advance_speech()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		draw_speech()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE,
	params = PICKUP_COLLECTIBLE,
	Function = function(_, pickup)
		if pickup.SubType ~= item.entity then
			return
		end
		rejected_data(pickup)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION,
	params = PICKUP_COLLECTIBLE,
	priority = -150,
	Function = function(_, pickup, collider)
		if not pickup or pickup.SubType ~= item.entity or not rejected_data(pickup) then
			return
		end
		local player = collider and collider.ToPlayer and collider:ToPlayer()
		if not player then
			return
		end
		local hash = GetPtrHash(pickup)
		local now = game_frame()
		local last = touch_cd[hash]
		if last == nil or now - last >= TOUCH_COOLDOWN then
			touch_cd[hash] = now
			local step = touch_step[hash] or 0
			touch_step[hash] = 1 - step
			say(pickup.Position, step == 0 and "coward" or "refuse")
		end
		return true
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_REWIND,
	params = nil,
	Function = function()
		clear_runtime()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		clear_runtime()
	end,
})

local function replaced_away(txn)
	if not txn or not txn.source_snapshot or txn.source_snapshot.rejected ~= true then
		return false
	end
	local after = txn.after or {}
	local variant = tonumber(after.variant) or 0
	local subtype = tonumber(after.subtype) or 0
	if variant == PICKUP_COLLECTIBLE and (subtype == item.entity or subtype <= 0) then
		return false
	end
	return true
end

morph_txn.register(item.own_key, {
	match_pre = function(pickup)
		return pickup
			and pickup.Type == EntityType.ENTITY_PICKUP
			and pickup.Variant == PICKUP_COLLECTIBLE
			and pickup.SubType == item.entity
			and rejected_data(pickup) ~= nil
	end,
	capture = function(pickup)
		if not rejected_data(pickup) then
			return nil
		end
		return {
			rejected = true,
			x = pickup.Position.X,
			y = pickup.Position.Y,
		}
	end,
	on_post = function(txn)
		if not replaced_away(txn) then
			return
		end
		local pos = nil
		if txn.target and txn.target.Position then
			pos = txn.target.Position
		elseif txn.source_snapshot then
			pos = Vector(txn.source_snapshot.x or 0, txn.source_snapshot.y or 0)
		end
		say(pos, "kill")
	end,
})

return item

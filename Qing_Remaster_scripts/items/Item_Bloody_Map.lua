local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local every_entity_holder = require("Qing_Remaster_scripts.callbacks.every_entity_holder")
local card_01_wizard = require("Qing_Remaster_scripts.cards.Card_01_Wizard")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Bloody_Map,
	own_key = "Item_Bloody_Map_",
	max_ultra_grants = 2,
	ultra_grant_amount = 1,
	messenger_spawn_chance = 0.4,
	pay_nothing_chance = 0.3,
	double_reward_chance = 0.3,
	-- 弱档（魂心角色）默认权重；强档去掉 nothing，并提高其余项。
	default_weights = {
		nothing = 40,
		ultra_room = 15,
		cracked_key = 25,
		ultra_item = 20,
	},
	boosted_weights = {
		ultra_room = 30,
		cracked_key = 40,
		ultra_item = 30,
	},
}

-- 本道具有独立 Seija 增幅，排除 Reverie 默认反转。
auxi.add_to_seija(item.entity)

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

local function debug_number(key, default, min_value, max_value)
	local debug = debug_root()
	local value = tonumber(debug and debug[key]) or default
	if min_value then value = math.max(min_value, value) end
	if max_value then value = math.min(max_value, value) end
	return value
end

local function debug_boolean(key, default)
	local debug = debug_root()
	local value = debug and debug[key]
	if value == nil then return default end
	return value == true
end

function item.get_messenger_spawn_chance_base()
	return debug_number("BloodyMapMessengerSpawnChance", item.messenger_spawn_chance, 0, 1)
end

function item.get_pay_nothing_chance()
	return debug_number("BloodyMessengerPayNothingChance", item.pay_nothing_chance, 0, 1)
end

function item.get_double_reward_chance()
	return debug_number("BloodyMessengerDoubleRewardChance", item.double_reward_chance, 0, 1)
end

function item.get_max_ultra_grants()
	return math.floor(debug_number("BloodyMapUltraGrantMax", item.max_ultra_grants, 0, 20) + 0.5)
end

function item.get_ultra_grant_amount()
	return math.floor(debug_number("BloodyMapUltraGrantAmount", item.ultra_grant_amount, 1, 10) + 0.5)
end

function item.get_reward_weight(key, boosted)
	local map = {
		nothing = "BloodyMessengerWeightNothing",
		ultra_room = "BloodyMessengerWeightUltraRoom",
		cracked_key = "BloodyMessengerWeightCrackedKey",
		ultra_item = "BloodyMessengerWeightItem",
	}
	local defaults = item.default_weights
	if boosted and item.boosted_weights[key] then
		defaults = item.boosted_weights
		map = {
			ultra_room = "BloodyMessengerBoostedWeightUltraRoom",
			cracked_key = "BloodyMessengerBoostedWeightCrackedKey",
			ultra_item = "BloodyMessengerBoostedWeightItem",
		}
	end
	return debug_number(map[key], defaults[key] or item.default_weights[key], 0, 1000)
end

function item.force_seija()
	return debug_boolean("BloodyMapForceSeijaEnhancement", false)
end

function item.is_seija_active()
	if item.force_seija() then return true end
	for player_num = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		if auxi.has_have_coll(player, item.entity) then
			-- quality 0：走 Seija 增幅判定
			if auxi.should_do_Seija(player, true) then return true end
		end
	end
	return false
end

function item.get_ultra_grants()
	return save.elses[item.own_key.."ultra_grants"] or 0
end

function item.get_pending_ultra()
	return save.elses[item.own_key.."pending_ultra"] or 0
end

function item.can_grant_extra_ultra()
	return item.get_ultra_grants() + item.get_pending_ultra() < item.get_max_ultra_grants()
end

function item.queue_extra_ultra()
	local room_left = item.get_max_ultra_grants() - item.get_ultra_grants() - item.get_pending_ultra()
	local amount = math.min(item.get_ultra_grant_amount(), room_left)
	if amount <= 0 then return false end
	save.elses[item.own_key.."pending_ultra"] = item.get_pending_ultra() + amount
	return amount
end

function item.reveal_ultra_secrets()
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local changed = false
	for i = 0, rooms.Size - 1 do
		local targ = rooms:Get(i)
		if targ and targ.Data and targ.Data.Type == RoomType.ROOM_ULTRASECRET then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex)
			if desc and (desc.DisplayFlags & 5) ~= 5 then
				desc.DisplayFlags = desc.DisplayFlags | 5
				changed = true
			end
		end
	end
	if changed then
		level:UpdateVisibility()
		if REPENTOGON and Minimap and Minimap.Refresh then
			Minimap.Refresh()
		end
	end
end

function item.find_ultra_secret_info(prefer_other)
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local dimen = auxi.GetDimension()
	local current = level:GetCurrentRoomDesc().SafeGridIndex
	local fallback = nil
	for i = 1, rooms.Size do
		local targ = rooms:Get(i - 1)
		if targ and dimen == auxi.GetDimension(targ) then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex)
			if desc and desc.Data and desc.Data.Type == RoomType.ROOM_ULTRASECRET then
				local info = {id = i, gidx = targ.SafeGridIndex, tp = RoomType.ROOM_ULTRASECRET}
				if prefer_other and targ.SafeGridIndex == current then
					fallback = info
				else
					return info
				end
			end
		end
	end
	return fallback
end

function item.spawn_ultra_portal(pos)
	local info = item.find_ultra_secret_info(true)
	if not info then return nil end
	local room = Game():GetRoom()
	pos = pos or room:FindFreePickupSpawnPosition(room:GetCenterPos(), 10, true)
	return card_01_wizard.spawn_a_fool_port(pos, {info = info})
end

function item.try_seija_portal()
	if not auxi.have_player_has_collectible(item.entity) then return end
	if not item.is_seija_active() then return end
	item.spawn_ultra_portal()
end

function item.add_one_extra_ultra_secret()
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local dimen = auxi.GetDimension()
	local UltraSecret = nil
	for i = 0, rooms.Size - 1 do
		local tg = rooms:Get(i)
		if tg and tg.Data and auxi.GetDimension(tg) == dimen and tg.Data.Type == RoomType.ROOM_ULTRASECRET then
			UltraSecret = level:GetRoomByIdx(tg.SafeGridIndex)
			break
		end
	end
	if not UltraSecret then return false end

	local idx = Room_holder.Allocate_with()
	if idx < 0 then return false end
	local desc = level:GetRoomByIdx(idx)
	if not (desc and desc.Data) then return false end

	desc.Data = UltraSecret.Data
	desc.Flags = desc.Flags & ~(1 << 10)
	desc.DisplayFlags = UltraSecret.DisplayFlags
	if auxi.have_player_has_collectible(item.entity) then
		desc.DisplayFlags = desc.DisplayFlags | 5
	end
	Room_holder.Try_replace_with(desc.SafeGridIndex, auxi.GetDimension(), {
		data = function()
			Isaac.ExecuteCommand("goto s.ultrasecret."..tostring(auxi.choose(0,1,2,3,4,5,6,7,8)))
			return Game():GetLevel():GetRoomByIdx(-3).Data
		end,
	})
	return true
end

function item.process_pending_ultra()
	local pending = item.get_pending_ultra()
	local remaining = 0
	local made = 0
	for i = 1, pending do
		if item.add_one_extra_ultra_secret() then
			made = made + 1
			save.elses[item.own_key.."ultra_grants"] = item.get_ultra_grants() + 1
		else
			remaining = pending - i + 1
			break
		end
	end
	save.elses[item.own_key.."pending_ultra"] = remaining
	if made > 0 then
		Game():GetLevel():UpdateVisibility()
		if REPENTOGON and Minimap and Minimap.Refresh then
			Minimap.Refresh()
		end
	end
	return made
end

function item.get_messenger_spawn_chance()
	local count = auxi.get_collectible_num_all(item.entity)
	if count <= 0 then return 0 end
	return math.min(1, item.get_messenger_spawn_chance_base() * count)
end

function item.try_spawn_messenger()
	local room = Game():GetRoom()
	if room:GetType() ~= RoomType.ROOM_ULTRASECRET then return end
	if not room:IsFirstVisit() then return end
	if not auxi.have_player_has_collectible(item.entity) then return end

	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local key = item.own_key.."spawned_"..tostring(desc.ListIndex).."_"..tostring(Game():GetLevel():GetStage())
	if save.elses[key] then return end
	save.elses[key] = true

	local seed = room:GetSpawnSeed()
	local rng = RNG()
	rng:SetSeed(seed, 35)
	if rng:RandomFloat() >= item.get_messenger_spawn_chance() then return end

	local slot = enums.Slots.Bloody_Messenger
	local pos = room:FindFreeTilePosition(room:GetCenterPos() + Vector(40, 0), 40)
	local q = Isaac.Spawn(slot.Type, slot.Variant, 0, pos, Vector(0, 0), nil)
	every_entity_holder.init_slot(q)
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if not continue then
		save.elses[item.own_key.."pending_ultra"] = 0
		save.elses[item.own_key.."ultra_grants"] = 0
	end
	save.elses[item.own_key.."pending_ultra"] = save.elses[item.own_key.."pending_ultra"] or 0
	save.elses[item.own_key.."ultra_grants"] = save.elses[item.own_key.."ultra_grants"] or 0
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil, priority = 110,
Function = function(_)
	item.process_pending_ultra()
	if auxi.have_player_has_collectible(item.entity) then
		item.reveal_ultra_secrets()
		item.try_seija_portal()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if auxi.have_player_has_collectible(item.entity) then
		item.reveal_ultra_secrets()
		item.try_spawn_messenger()
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = item.entity,
Function = function(_,player,id,diff,curNum)
	if diff and diff > 0 then
		item.reveal_ultra_secrets()
		if item.force_seija() or auxi.should_do_Seija(player, true) then
			item.spawn_ultra_portal()
		end
	end
end,
})

return item

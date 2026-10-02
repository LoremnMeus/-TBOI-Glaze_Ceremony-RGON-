-- Coin story thread: HQ entrance availability, Boss placement, Story token acquisition.
-- Bank HQ room graph / terminals live in threads/bank/bank_rooms.lua.
-- Legacy physical Coin Shard reward is dormant (XML/enum retained; not spawned).

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local Screen_Filter = require("Qing_Remaster_scripts.others.Screen_Filter")
local record_holder = require("Qing_Remaster_scripts.others.Record_holder")
local gate = require("Qing_Remaster_scripts.story.story_runtime_gate")
local bank_rooms = require("Qing_Remaster_scripts.threads.bank.bank_rooms")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	own_key = "Thread_Coin",
}

local function ensure_bank_entrance()
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	if level:GetStage() == LevelStage.STAGE7_GREED
		and room:GetType() == RoomType.ROOM_BOSS
		and level:GetCurrentRoomDesc().SafeGridIndex == 45
		and room:IsClear()
	then
		save.elses.coins = true
		-- DOWN1 on the final Greed boss room → HQ Entrance.
		grid_door.try_spawn_grid_door(room, 6, nil, {
			check_and_leave = "s.arcade.23509",
			loadname = "gfx/grid/door_bankdoor.anm2",
			playname = "Opened",
		})
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD,
	params = nil,
	Function = function(_)
		ensure_bank_entrance()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		ensure_bank_entrance()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function(_)
		save.elses.coin = false
		save.elses.coins = false
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		local level = Game():GetLevel()
		local room = Game():GetRoom()
		local desc = level:GetCurrentRoomDesc()
		if not desc or not desc.Data then return end

		if Game():IsGreedMode() then
			local gidx = level:GetCurrentRoomDesc().SafeGridIndex
			if gidx < 0 then
				local rdesc = level:GetRoomByIdx(gidx)
				if rdesc then
					rdesc.Flags = rdesc.Flags & (~RoomDescriptor.FLAG_CURSED_MIST)
				end
			end

			-- Treasury: first-clear Story token / repeat coin reward via bank_rooms.
			if desc.Data.Type == 20 and desc.Data.Variant == 23520 then
				local rdesc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
				if rdesc then
					rdesc.Flags = rdesc.Flags | RoomDescriptor.FLAG_CURSED_MIST
				end
				bank_rooms.grant_treasury_reward()
			end

			-- Boss room (HQ).
			if desc.Data.Type == 9 and desc.Data.Variant == 23503 then
				local center = room:GetCenterPos()
				local posX = center.X
				local posY = center.Y
				local t_n = 1
				for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
					if room:IsDoorSlotAllowed(slot) then
						local pos = room:GetDoorSlotPosition(slot)
						if pos.Y > posY + 5 then
							t_n = 1
							posX = pos.X
							posY = pos.Y
						elseif pos.Y > posY - 5 and pos.Y < posY + 5 then
							posX = pos.X + posX
							t_n = t_n + 1
						end
					end
				end
				local pos = room:GetClampedPosition(Vector(posX / t_n, posY), 10)
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					player.Position = pos
					player.Velocity = Vector(0, 0)
					Screen_Filter.add_filter(10)
				end
				if gate.should_spawn_event_boss("chapter1.coin", {story_owned = true}) then
					Isaac.Spawn(996, enums.Enemies.Bum_Emperor, 0, Vector(0, 0), Vector(0, 0), nil)
					for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
						if room:GetDoor(slot) then
							room:RemoveDoor(slot)
						end
					end
				end
			end
		else
			if desc.Data.Type == 9 and desc.Data.Variant == 23800 then
				local pos = room:GetGridPosition(82)
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					player.Position = pos
					player.Velocity = Vector(0, 0)
					Screen_Filter.add_filter(10)
				end
				if gate.should_spawn_event_boss("chapter1.coin", {story_owned = true}) then
					Isaac.Spawn(996, enums.Enemies.Bum_Emperor, 0, Vector(0, 0), Vector(0, 0), nil)
				end
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		if not continue then
			save.elses.coin = false
			save.elses.coins = false
		end
	end,
})

-- Legacy Coin Shard spawn / POST_GAIN teleport / shopkeeper shard drops retired.
-- First-clear Story token + permanent Others.Coin flag come from bank_rooms.grant_treasury_reward().
-- Do not play "Unlocked: A Shard of Coin" — physical reward is dormant.
function item.hold_by_record(ent)
	local seed = ent.InitSeed
	record_holder.try_hold(ent, {
		check = function(et)
			if et.InitSeed ~= seed then return true, "Turn" end
			return false, nil
		end,
		Function = function(tp, et)
			if tp == "Turn" and auxi.check_all_exists(et) then
				consistance_holder.try_hold_entity(et, item.own_key, { ignore_subtype = true })
				local s = et:GetSprite()
				s:ReplaceSpritesheet(5, "gfx/items/to_item_altar.png")
				s:LoadGraphics()
				s:SetOverlayFrame("Alternates", 1)
			end
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_INIT,
	params = 100,
	Function = function(_, ent)
		if ent.Type == 5 and ent.Variant == 100 then
			if consistance_holder.try_check_entity(ent, item.own_key) then
				item.hold_by_record(ent)
				local s = ent:GetSprite()
				s:ReplaceSpritesheet(5, "gfx/items/to_item_altar.png")
				s:LoadGraphics()
				s:SetOverlayFrame("Alternates", 1)
			end
		end
	end,
})

item.story_test = {
	snapshot = function(_ctx)
		return {
			coin = save.elses.coin,
			coins = save.elses.coins,
		}
	end,
	restore = function(snap, _ctx)
		save.elses.coin = nil
		save.elses.coins = nil
		if type(snap) ~= "table" then return end
		save.elses.coin = snap.coin
		save.elses.coins = snap.coins
	end,
	reset = function(_ctx)
		save.elses.coin = false
		save.elses.coins = false
		return true
	end,
	prepare = function(ctx)
		ctx = ctx or {}
		local phase = ctx.phase or "pre_trigger"
		item.story_test.reset(ctx)
		if phase == "discovered" or phase == "boss" or phase == "repeat_acquisition" then
			save.elses.coins = true
		end
		return true
	end,
	trigger = function(ctx)
		ctx = ctx or {}
		if ctx.phase == "boss" then
			-- Story Test boss phase defaults to standalone spawn so combat can be
			-- exercised without forging first-clear StoryProgress.
			local story_owned = ctx.story_owned == true
			if gate.should_spawn_event_boss("chapter1.coin", {story_owned = story_owned}) then
				Isaac.Spawn(996, enums.Enemies.Bum_Emperor, 0, Game():GetRoom():GetCenterPos(), Vector(0, 0), nil)
				return true
			end
			return false, "boss not required for this story state"
		end
		return false, "no direct trigger"
	end,
	inspect = function(_ctx)
		return {
			phase = save.elses.coins and "bank_open" or "idle",
			first_clear_required = gate.requires_first_clear_boss("chapter1.coin"),
			first_cleared = gate.is_event_first_cleared("chapter1.coin"),
			run_token = gate.has_material("chapter1.material.coin"),
			gate = gate.is_material_event_enabled("chapter1.coin"),
		}
	end,
	cleanup = function(_ctx)
		return item.story_test.reset(_ctx)
	end,
}

return item

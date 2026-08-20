local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Profound,
	own_key = "Thoth_cd21_Pro_",
}

function item.random_secret_room()
	return math.random(33) - 1
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then end
		local level = Game():GetLevel()
		local rooms = level:GetRooms()
		local dimen = auxi.GetDimension()
		local tbl = {}
		for i = 1, rooms.Size do
			local targ = rooms:Get(i - 1)
			if targ and dimen == auxi.GetDimension(targ) then
				local desc = level:GetRoomByIdx(targ.SafeGridIndex)
				if desc then
					local tp = desc.Data.Type
					if tp == RoomType.ROOM_SUPERSECRET then table.insert(tbl,#tbl + 1,{id = i,tp = tp,gidx = targ.SafeGridIndex,}) end
				end
			end
		end
		player:AnimateTeleport(true)
		if #tbl > 0 then 
			local tg = auxi.random_in_table(tbl)
			Room_holder.Trans_to(tg.gidx,Direction.NO_DIRECTION,RoomTransitionAnim.TELEPORT,player,-1)
		else player:UseActiveItem(CollectibleType.COLLECTIBLE_TELEPORT,false,true,false,false) end
	end
end,
})

function item.make_a_supersecret_room(player)
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local dimen = auxi.GetDimension()
	local tbl = {}
	local TargetSecret = nil
	for i = 1, rooms.Size do
		local tgroom = rooms:Get(i - 1)
		if tgroom and tgroom.Data and auxi.GetDimension(tgroom) == dimen then
			local tgdesc = auxi.get_all_gridindexs(tgroom)
			local sgid = tgroom.SafeGridIndex
			for u,v in pairs(tgdesc) do tbl[v] = {invalid = true,} end
			local sgids = auxi.get_moves_in_gridroom(tgroom.Data.Shape)
			for u,v in pairs(sgids) do
				if auxi.is_safe_move_in_grids(sgid,v) then
					tbl[v + sgid] = tbl[v + sgid] or {}
					tbl[v + sgid].counter = (tbl[v + sgid].counter or 0) + 1
					if tgroom.Data.Type ~= 1 or (tgroom.Data.Doors & (1<<u) ~= (1<<u)) then tbl[v + sgid].invalid = true end
				end
			end
			local sgid2 = auxi.get_banished_moves_in_gridroom(tgroom.Data.Shape)
			for u,v in pairs(sgid2) do
				if auxi.is_safe_move_in_grids(sgid,v) then
					tbl[v + sgid] = tbl[v + sgid] or {}
					tbl[v + sgid].invalid = true
				end
			end
			if tgroom.Data.Type == RoomType.ROOM_SUPERSECRET then TargetSecret = tgroom end
		end
	end
	local sel = {}
	for u,v in pairs(tbl) do
		if v.invalid ~= true and (v.counter or 0) == 1 then table.insert(sel,#sel + 1,u) end
	end
	local rng = player:GetCardRNG(item.entity)
	local tg = auxi.random_in_table(sel,rng)
	if tg then
		local succ = auxi.make_red_room(tg)
		if succ then 
			local desc2 = level:GetRoomByIdx(tg)
			desc2.Flags = desc2.Flags & ~(1<<10) 
			if TargetSecret then 
				desc2.Data = TargetSecret.Data
				desc2.DisplayFlags = TargetSecret.DisplayFlags
			end
			Room_holder.Try_replace_with(tg,auxi.GetDimension(),{data = function() Isaac.ExecuteCommand("goto s.supersecret."..tostring(item.random_secret_room())) return Game():GetLevel():GetRoomByIdx(-3).Data end,}) 
		end
		level:UpdateVisibility()
	end
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	local player = auxi.have_card(item.entity)
	if player then
		item.make_a_supersecret_room(player)
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_TAROT_CLOTH) then item.make_a_supersecret_room(player)	end
	end
end,
})

return item
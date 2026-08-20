local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local AI = require("Qing_Remaster_scripts.bosses.Boss_All")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Baby_Anim = require("Qing_Remaster_scripts.others.Baby_Anim_holder")

local item = {
	float_lock = {
		Show = true,
	},
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Baby_Lu,
	familiar = enums.Familiars.Baby_Lu,
	own_key = "Item_Baby_Lu_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	local tgs = auxi.getothers(nil,3,item.familiar)
	for u,v in pairs(tgs) do
		local d = v:GetData()
		d._Data = d._Data or {}
		d._Data[item.own_key] = {state = 0,}
		consistance_holder.try_hold_entity(v,item.own_key)
	end
end,
})

function item.record_maps(ent)
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
				if tp ~= RoomType.ROOM_DEFAULT then table.insert(tbl,#tbl + 1,{id = i,tp = tp,sgid = targ.SafeGridIndex,}) end
			end
		end
	end
	local tgs = auxi.choose3(tbl,math.min(#tbl,3))
	for u,v in pairs(tgs) do
		local desc = level:GetRoomByIdx(v.sgid)
		if desc then
			local tp = desc.Data.Type
			if tp == v.tp then
				desc.DisplayFlags = 5
			end
		end
	end
	level:UpdateVisibility()
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_, ent)
	local player = auxi.check_spawner_player(ent)
	local d = ent:GetData()
	local s = ent:GetSprite()

	consistance_holder.try_check_entity(ent,item.own_key)

	d._Data = d._Data or {}
	if d._Data[item.own_key] then
		if d._Data[item.own_key].state == 0 then
			Baby_Anim.reset(ent, item.own_key.."float")
			s:Play("Show",true)
			d._Data[item.own_key].state = 1
		end
		if d._Data[item.own_key].state == 1 then
			if s:IsEventTriggered("ShowMap") then
				item.record_maps(ent)
			end
			if s:IsFinished("Show") then
				d._Data[item.own_key] = nil
				Baby_Anim.reset(ent, item.own_key.."float")
				s:Play("Float",true)
			end
		end
	end

	if not d[item.own_key.."IsFollow"] then
		ent:AddToFollowers()
		d[item.own_key.."IsFollow"] = true
	end
	Baby_Anim.tick_float_idle(ent, item.own_key.."float", {locked = item.float_lock})
	ent:FollowParent()
end
})

return item
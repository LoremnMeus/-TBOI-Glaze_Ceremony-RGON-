local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Dark_Particle,
	own_key = "Trinkets_Dark_Particle_",
}

local function debt_tbl()
	local t = save.elses[item.own_key.."cnt"]
	if type(t) ~= "table" then
		t = {}
		save.elses[item.own_key.."cnt"] = t
	end
	return t
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_TRINKET, params = item.entity,
Function = function(_,player,tid,cnt,touched,curNum,known,golden,total)
	if touched ~= true then
		local gain = total or cnt
		if (not known and curNum ~= 0) or player:HasTrinket(item.entity) ~= true then gain = 0 end
		local idx = player:GetData().__Index
		if idx == nil then return end
		for _ = 1,gain do
			-- AddBlackHearts 以半心计：4 = 玩家理解的「2 颗黑心」
			player:AddBlackHearts(4)
		end
		local debt = debt_tbl()
		debt[tostring(idx)] = (debt[tostring(idx)] or 0) + gain
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_LOSE_TRINKET, params = item.entity,
Function = function(_,player,tid,cnt,curNum)
	local idx = player:GetData().__Index
	if idx == nil then return end
	local debt = debt_tbl()
	local key = tostring(idx)
	local owed = debt[key] or 0
	if owed > 0 then
		local take = math.min(owed,cnt)
		player:AddBrokenHearts(take)
		debt[key] = owed - take
		if debt[key] <= 0 then debt[key] = nil end
	end
end,
})

return item

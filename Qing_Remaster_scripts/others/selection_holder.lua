local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
}

--这个委托器只负责管理与通知需要select的部分，而具体的管理内容则由委托者控制。也就是说只决策并控制不同的select程序的优先级。
--此外，所有的委托并不进行保存。当玩家被重新生成的时候，委托者应该重新申请管理。

function item.check_and_try_select(player,name,tail)
	item.try_select(player,name,tail)
	return item.check_select(player,name)
end

function item.check_select(player,name)
	player = player or Game():GetPlayer(0)
	if not player then return false end
	local ok, d = pcall(function() return player:GetData() end)
	if not ok or type(d) ~= "table" then return false end
	d.selection_holder_heap = d.selection_holder_heap or {}
	if d.selection_holder_heap[1] == nil or d.selection_holder_heap[1].name ~= name then return false end
	return true
end

function item.try_select(player,name,tail)
	player = player or Game():GetPlayer(0)
	if not player then return end
	local ok, d = pcall(function() return player:GetData() end)
	if not ok or type(d) ~= "table" then return end
	d.selection_holder_heap = d.selection_holder_heap or {}
	d.selection_holder_r_heap = d.selection_holder_r_heap or {}
	if d.selection_holder_r_heap[name] ~= nil then
	else
		local pos = 1
		if tail then pos = #d.selection_holder_heap + 1 end
		table.insert(d.selection_holder_heap,pos,{name = name,})
		d.selection_holder_r_heap[name] = true
	end
end

function item.remove_select(player,name)
	player = player or Game():GetPlayer(0)
	if not player then return false end
	-- 暂停菜单重置/换房时 Player userdata 可能 Exists 但 GetData 会崩
	local ok, d = pcall(function() return player:GetData() end)
	if not ok or type(d) ~= "table" then return false end
	d.selection_holder_heap = d.selection_holder_heap or {}
	d.selection_holder_r_heap = d.selection_holder_r_heap or {}
	if d.selection_holder_r_heap[name] == nil then return false end
	d.selection_holder_r_heap[name] = nil
	for u,v in pairs(d.selection_holder_heap) do
		if v.name == name then
			table.remove(d.selection_holder_heap,u)
			return true
		end
	end
	return false
end

return item
local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")

local item = {
	ToCall = {},
	grid_table = {},
	-- 每次进房（含重进同房、沙漏、维度切换）无条件 +1；与 room_key 一起绑定 wrapper
	visit_epoch = 0,
}

-- room_key：诊断/辅助隔离；visit_epoch 才是每次进房代次的硬边界
local function current_room_key()
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level and level:GetCurrentRoomDesc() or nil
	local list_idx = desc and desc.ListIndex or -1
	local stage = level and level:GetStage() or -1
	local stage_type = level and level:GetStageType() or -1
	local room_idx = level and level:GetCurrentRoomIndex() or -1
	local deco = room and room.GetDecorationSeed and room:GetDecorationSeed() or 0
	return tostring(stage).."|"..tostring(stage_type).."|"..tostring(room_idx).."|"..tostring(list_idx).."|"..tostring(deco)
end

local function wrapper_matches_visit(ent)
	return ent and ent.visit_epoch == item.visit_epoch
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item.visit_epoch = (item.visit_epoch or 0) + 1
	item.grid_table = {}
end,
})

local function full_change(grid)
	if grid == nil then return nil end
	if grid:ToDoor() then grid = grid:ToDoor()
	elseif grid:ToPit() then grid = grid:ToPit()
	elseif grid:ToPoop() then grid = grid:ToPoop()
	elseif grid:ToRock() then grid = grid:ToRock()
	elseif grid:ToPressurePlate() then grid = grid:ToPressurePlate()
	elseif grid:ToSpikes() then grid = grid:ToSpikes()
	elseif grid:ToTNT() then grid = grid:ToTNT()
	end
	return grid
end

local function fetch_grid_raw(grididx)
	local ok, grid = pcall(function()
		return full_change(Game():GetRoom():GetGridEntity(grididx))
	end)
	if not ok then return nil end
	return grid
end

function item.get_visit_epoch()
	return item.visit_epoch or 0
end

function item.get_grid_table()
	for u,v in pairs(item.grid_table) do
		if v:Exists() ~= true then item.grid_table[u] = nil end
	end
	return item.grid_table
end

function item.get_grid_entity(grid,grididx)
	if grididx then grid = grid or Game():GetRoom():GetGridEntity(grididx) end
	if grid then
		grididx = grididx or grid:GetGridIndex()
		local wrap = item.grid_table[grididx]
		local stale = wrap == nil or wrap:Exists() ~= true
		if not stale then
			local ok, gnow = pcall(function() return wrap:get_grid() end)
			if not ok or gnow == nil then
				stale = true
			else
				local okv, variant = pcall(function() return gnow:GetVariant() end)
				if not okv or variant == nil then stale = true end
			end
		end
		if stale then
			local key = current_room_key()
			local epoch = item.visit_epoch or 0
			item.grid_table[grididx] = {
				IsGrid = true,
				room_key = key,
				visit_epoch = epoch,
				get_grid = function(ent)
					if not wrapper_matches_visit(ent) then return nil end
					if ent.room_key ~= current_room_key() then return nil end
					return fetch_grid_raw(ent.grididx)
				end,
				grididx = grididx,
				GetData = function(ent) return ent.Data end,
				Data = {},
				PositionOffset = Vector(0,0),
				Position = function(ent) return (ent:get_grid() or {Position = Vector(200,200),}).Position or Vector(200,200) end,
				GetSprite = function(ent)
					local g2 = ent:get_grid()
					if g2 then return g2:GetSprite() else return Sprite() end
				end,
				Exists = function(ent)
					if not wrapper_matches_visit(ent) then return false end
					if ent.room_key ~= current_room_key() then return false end
					return fetch_grid_raw(ent.grididx) ~= nil
				end,
				IsDead = function(ent) return false end,
				Type = 1001,
			}
		end
		return item.grid_table[grididx]
	end
	return nil
end


return item

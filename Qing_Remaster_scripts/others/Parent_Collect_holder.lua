-- ParentNPC / Runtime Stitch linkage graph helpers.
-- Ported from Stitch Edition Parent_Collect_holder; linkage edges use
-- native_mixture.controller.get_linkage_neighbors (not Boss_Mixturer keys).

local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	own_key = "Parent_Collect_holder_",
}

local function controller_mod()
	local ok, controller = pcall(require, "Qing_Remaster_scripts.auxiliary.native_mixture.controller")
	if ok and type(controller) == "table" then
		return controller
	end
	return nil
end

local function linkage_neighbors(ent)
	local controller = controller_mod()
	if not controller or not controller.get_linkage_neighbors then
		return {}
	end
	return controller.get_linkage_neighbors(ent) or {}
end

function item.collect_all_parents(ent)
	local npc = ent and ent:ToNPC()
	if not npc or not npc:Exists() then
		return {}
	end
	local n_entity = Isaac.GetRoomEntities()
	local ret = {}
	for _, v in pairs(n_entity) do
		local vn = v:ToNPC()
		if vn and auxi.check_for_the_same(auxi.get_last_parentnpc(vn), npc) == true then
			table.insert(ret, v)
		end
	end
	return ret
end

function item.collect(ent)
	local npc = ent and ent:ToNPC()
	if not npc or not npc:Exists() then
		return {}
	end
	local n_entity = Isaac.GetRoomEntities()
	local ret = {}
	for _, v in pairs(n_entity) do
		local vn = v:ToNPC()
		if vn and auxi.check_for_the_same(vn.ParentNPC, npc) == true then
			table.insert(ret, v)
		end
	end
	return ret
end

function item.try_collect(ent, params)
	params = params or {}
	local d = ent:GetData()
	d[item.own_key .. "data"] = d[item.own_key .. "data"] or {}
	if #d[item.own_key .. "data"] > 0 then
		for i = #d[item.own_key .. "data"], 1, -1 do
			local v = d[item.own_key .. "data"][i]
			if auxi.check_all_exists(v) and auxi.check_for_the_same(v:ToNPC().ParentNPC, ent) == true then
				if params.just_one then
					return v
				end
			else
				table.remove(d[item.own_key .. "data"], i)
			end
		end
	end
	if #(d[item.own_key .. "data"]) == 0 or params.force then
		d[item.own_key .. "data"] = item.collect(ent)
	end
	if params.just_one then
		return d[item.own_key .. "data"][1]
	end
	return d[item.own_key .. "data"]
end

function item.search_for_linkage(ent, _key, _tbl, params)
	params = params or {}
	local ents = Isaac.GetRoomEntities()
	local tgs = {}
	for _, v in pairs(ents) do
		if v:ToNPC() and v:IsEnemy() then
			local vn = v:ToNPC()
			if vn.ParentNPC then
				local vd = vn.ParentNPC:GetData()
				vd[item.own_key .. "check"] = vd[item.own_key .. "check"] or {}
				table.insert(vd[item.own_key .. "check"], v)
			end
			if params.check_parent and v.Parent and v.Parent:ToNPC() then
				local vd = v.Parent:GetData()
				vd[item.own_key .. "check"] = vd[item.own_key .. "check"] or {}
				table.insert(vd[item.own_key .. "check"], v)
			end
			table.insert(tgs, v)
		end
	end

	local stack = params.stack or { ent }
	local connectedEntities = {}
	local controller = controller_mod()

	while #stack > 0 do
		local current = table.remove(stack)
		if current and not current:GetData()[item.own_key .. "Visited"] then
			current:GetData()[item.own_key .. "Visited"] = true
			table.insert(connectedEntities, current)

			for _, neighbor in ipairs(current:GetData()[item.own_key .. "check"] or {}) do
				if not neighbor:GetData()[item.own_key .. "Visited"] then
					table.insert(stack, neighbor)
				end
			end
			local cn = current:ToNPC()
			if cn and cn.ParentNPC and not cn.ParentNPC:GetData()[item.own_key .. "Visited"] then
				table.insert(stack, cn.ParentNPC)
			end
			if params.check_parent and current.Parent and current.Parent:ToNPC() then
				table.insert(stack, current.Parent)
			end

			-- Runtime Stitch linkage (replaces Boss_Mixturer linkee/effect walk).
			local neighbors = linkage_neighbors(current)
			for i = 1, #neighbors do
				local n = neighbors[i]
				if n and n.GetData and not n:GetData()[item.own_key .. "Visited"] then
					local is_linker = controller and controller.is_linker and controller.is_linker(n)
					if is_linker then
						if params.take_linker then
							table.insert(stack, n)
						end
					else
						table.insert(stack, n)
					end
				end
			end
		end
	end

	for _, v in pairs(tgs) do
		v:GetData()[item.own_key .. "Visited"] = nil
		v:GetData()[item.own_key .. "check"] = nil
	end
	return connectedEntities
end

function item.is_in_the_same_npc_group(e1, e2)
	local tbl = item.search_for_linkage(e2)
	for _, v in pairs(tbl) do
		if auxi.check_for_the_same(v, e1) then
			return true
		end
	end
	return false
end

--- Isolate ent:Update() from other enemies (Stitch Edition semantics).
function item.update_npc(ent, tbl, i_flag)
	local tab = {}
	tbl = tbl or auxi.getallenemies()
	i_flag = i_flag or (EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_PERSISTENT | EntityFlag.FLAG_CHARM)
	for _, v in pairs(tbl) do
		if auxi.check_for_the_same(v, ent) ~= true then
			local vn = v:ToNPC()
			if vn then
				tab[v] = vn.CanShutDoors
				vn.CanShutDoors = false
			end
			v:AddEntityFlags(i_flag)
		end
	end
	ent:Update()
	for _, v in pairs(tbl) do
		if auxi.check_for_the_same(v, ent) ~= true then
			v:ClearEntityFlags(i_flag)
			local vn = v:ToNPC()
			if vn then
				vn.CanShutDoors = tab[v]
			end
		end
	end
end

return item

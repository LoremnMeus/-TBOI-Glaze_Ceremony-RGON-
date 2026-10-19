-- Blueprint integrity: allocation, missing materials, revive lock, broken crafts.
-- Structural extract from Item_Blue_Print.lua. Callers keep requiring the item façade.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local CraftIdentity = require("Qing_Remaster_scripts.mimics.craft_identity")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")

local M = {}

function M.attach(item, BP)
function item.count_allocated(player, exclude_uid)
	local used = {}
	local function add_id(id)
		id = tonumber(id) or id
		if id and id ~= 0 then used[id] = (used[id] or 0) + 1 end
	end
	for _, rec in ipairs(item.get_craft_store(player)) do
		-- 仅 real 条目占背包配额；audit/prototype 不占
		-- 制造复活锁定：材料不占用配额，便于背包取回后改其它配方/手动修理
		if rec.uid ~= exclude_uid and not CraftProfile.craft_revive_is_locked(rec) then
			local fb = rec.audit == true
			for _, entry in pairs(rec.ingredients or {}) do
				if CraftProfile.is_real_entry(entry, fb) then
					add_id(CraftProfile.ingredient_id(entry))
				end
			end
			for _, entry in ipairs(rec.cost_items or {}) do
				if CraftProfile.is_real_entry(entry, fb) then
					add_id(CraftProfile.ingredient_id(entry))
				end
			end
		end
	end
	return used
end

--- 统计某配方需要的真实道具份数（不含原型/审计）
function BP.craft_need_real_counts(rec)
	local need = {}
	if not rec then return need end
	local fb = rec.audit == true
	local function add(id)
		id = tonumber(id)
		if id and id > 0 then need[id] = (need[id] or 0) + 1 end
	end
	for _, entry in pairs(rec.ingredients or {}) do
		if CraftProfile.is_real_entry(entry, fb) then
			add(CraftProfile.ingredient_id(entry))
		end
	end
	for _, entry in ipairs(rec.cost_items or {}) do
		if CraftProfile.is_real_entry(entry, fb) then
			add(CraftProfile.ingredient_id(entry))
		end
	end
	return need
end

function BP.craft_need_prototype_uids(rec)
	local uids = {}
	if not rec then return uids end
	for _, entry in pairs(rec.ingredients or {}) do
		if CraftProfile.is_prototype_entry(entry) then
			local uid = entry.prototype_uid
			if uid ~= nil then
				uids[uid] = true
				uids[tostring(uid)] = true
			end
		end
	end
	return uids
end

--- 同名多份匹配：优先「场上已绑定飞行器」的配方，其余按 uid 升序（先造先占）
function item.ordered_crafts_for_allocation(player)
	local bound = {}
	if player then
		for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, enums.Familiars.QingsAirs, -1, false, false)) do
			local p = auxi.check_spawner_player(fam)
			if p and auxi.check_for_the_same(p, player) and auxi.check_all_exists(fam) then
				local uid = CraftIdentity.get_uid(fam)
				if uid then bound[uid] = true end
			end
		end
	end
	local list = {}
	for _, rec in ipairs(item.get_craft_store(player) or {}) do
		-- 纯审计无 real/prototype 配额；混装仍参与完整性/分配
		if not CraftProfile.craft_is_pure_audit_rec(rec) then list[#list + 1] = rec end
	end
	table.sort(list, function(a, b)
		local ab = bound[a.uid] and 1 or 0
		local bb = bound[b.uid] and 1 or 0
		if ab ~= bb then return ab > bb end
		return (tonumber(a.uid) or 0) < (tonumber(b.uid) or 0)
	end)
	return list
end

--- 刷新配方完整性：缺真实材料或原型丢失 → rec.broken=true
--- 返回 map[uid]=broken
function item.refresh_craft_integrity(player)
	local result = {}
	if not player then return result end
	local fr = Game():GetFrameCount()
	local ptr = GetPtrHash(player)
	if item._integrity_fr == fr and item._integrity_player == ptr and item._integrity_result then
		return item._integrity_result
	end
	local store = item.get_craft_store(player)
	if not store or #store == 0 then
		item._integrity_fr = fr
		item._integrity_player = ptr
		item._integrity_result = result
		return result
	end
	local remain = {}
	local config = Isaac.GetItemConfig()
	local size = config and config:GetCollectibles() and config:GetCollectibles().Size or 0
	for id = 1, size do
		local n = player:GetCollectibleNum(id, true)
		if n and n > 0 then remain[id] = n end
	end
	local proto_inv = BP.get_prototype_inv(player)
	local proto_ok = {}
	for _, prec in pairs(proto_inv or {}) do
		local uid = prec.uid
		if uid ~= nil then
			proto_ok[uid] = true
			proto_ok[tostring(uid)] = true
		end
	end
	for _, rec in ipairs(item.ordered_crafts_for_allocation(player)) do
		BP.migrate_rec_mirror_fields(rec)
		local locked = CraftProfile.craft_revive_is_locked(rec)
		local broken = false
		local missing = {}
		local need = BP.craft_need_real_counts(rec)
		if locked then
			-- 有制造复活状态：材料即使齐也不自动修好/回填；且不扣 remain
			broken = true
			for id, n in pairs(need) do
				local have = remain[id] or 0
				if have < n then
					missing[id] = n - have
				end
			end
			missing.craft_revive_locked = true
			local seen_proto = {}
			for _, entry in pairs(rec.ingredients or {}) do
				if CraftProfile.is_prototype_entry(entry) then
					local uid = entry.prototype_uid
					local key = tostring(uid)
					if uid ~= nil and not seen_proto[key] then
						seen_proto[key] = true
						if not proto_ok[uid] and not proto_ok[key] then
							missing.prototype = true
							missing.prototype_uids = missing.prototype_uids or {}
							missing.prototype_uids[uid] = true
							missing.prototype_uids[key] = true
							local id = CraftProfile.ingredient_id(entry)
							if id then
								missing[id] = (missing[id] or 0) + 1
							end
						end
					end
				end
			end
		else
			for id, n in pairs(need) do
				local have = remain[id] or 0
				if have < n then
					broken = true
					missing[id] = n - have
					remain[id] = 0
				else
					remain[id] = have - n
				end
			end
			local seen_proto = {}
			for _, entry in pairs(rec.ingredients or {}) do
				if CraftProfile.is_prototype_entry(entry) then
					local uid = entry.prototype_uid
					local key = tostring(uid)
					if uid ~= nil and not seen_proto[key] then
						seen_proto[key] = true
						if not proto_ok[uid] and not proto_ok[key] then
							broken = true
							missing.prototype = true
							missing.prototype_uids = missing.prototype_uids or {}
							missing.prototype_uids[uid] = true
							missing.prototype_uids[key] = true
							local id = CraftProfile.ingredient_id(entry)
							if id then
								missing[id] = (missing[id] or 0) + 1
							end
						end
					end
				end
			end
			local mm = rec.mirror_module
			if mm then
				if not BP.player_has_mirror_birthright(player) then
					broken = true
					missing.mirror = true
				else
					local id = CraftProfile.ingredient_id(mm)
					if not id or not CraftProfile.has_impl(id) then
						broken = true
						missing.mirror = true
					elseif (player:GetCollectibleNum(id, true) or 0) <= 0 then
						broken = true
						missing.mirror = true
						missing[id] = (missing[id] or 0) + 1
					end
				end
			end
		end
		rec.broken = broken
		rec.broken_missing = broken and missing or nil
		result[rec.uid] = broken
	end
	-- 缺料变化后重算 imitate：卸掉「普通配方失去材料却补发的临时宝宝」
	local parts = {}
	for uid, br in pairs(result) do
		parts[#parts + 1] = tostring(uid) .. (br and ":1" or ":0")
	end
	table.sort(parts)
	local sig = table.concat(parts, ",")
	item._integrity_sim_sig = item._integrity_sim_sig or {}
	if item._integrity_sim_sig[ptr] ~= sig then
		item._integrity_sim_sig[ptr] = sig
		Imitate_item_holder.Evaluate_Imitate_Items(player)
	end
	item._integrity_fr = fr
	item._integrity_player = ptr
	item._integrity_result = result
	return result
end

function item.is_craft_broken(player, uid)
	if not player or not uid then return false end
	-- 只读上次事件刷新的 rec.broken。禁止在 FAMILIAR_UPDATE / 面板渲染里再扫全道具表。
	-- 带宽快照已维护 UID 索引；Flight/环绕物逐帧查询优先走 O(1) 路径。
	local ok, BW = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Bandwidth_Manager")
	if ok and BW and BW.get_snapshot then
		local snap = BW.get_snapshot(player)
		local rec = snap and snap.rec_by_uid and snap.rec_by_uid[tostring(uid)]
		if rec then return rec.broken == true end
	end
	local rec = item.find_craft(player, uid)
	return rec and rec.broken == true
end


function BP.ingredients_fit_allocation(player, ingredients, exclude_uid, cost_items, mirror_module)
	local need_real = {}
	local need_proto = {}
	for _, entry in pairs(ingredients or {}) do
		local src = CraftProfile.ingredient_source(entry, false)
		if src == "prototype" then
			need_proto[entry.prototype_uid] = CraftProfile.ingredient_id(entry)
		elseif src == "real" then
			local id = CraftProfile.ingredient_id(entry)
			if id and id ~= 0 then
				need_real[id] = (need_real[id] or 0) + 1
			end
		end
		-- audit / mirror（旧材料槽）不占配额
	end
	for _, entry in ipairs(cost_items or {}) do
		if CraftProfile.is_mirror_entry(entry) then return false end
		if CraftProfile.ingredient_source(entry, false) == "real" then
			local id = CraftProfile.ingredient_id(entry)
			if id and id ~= 0 then need_real[id] = (need_real[id] or 0) + 1 end
		end
	end
	if mirror_module then
		if not BP.player_has_mirror_birthright(player) then return false end
		local id = CraftProfile.ingredient_id(mirror_module)
		if not id or id == 0 or not CraftProfile.has_impl(id) then return false end
		if (player:GetCollectibleNum(id, true) or 0) <= 0 then return false end
	end
	local used = item.count_allocated(player, exclude_uid)
	for id, n in pairs(need_real) do
		local have = player:GetCollectibleNum(id, true) - (used[id] or 0)
		if id == item.entity then have = have - 1 end
		if have < n then return false end
	end
	local used_proto = item.count_allocated_prototypes(player, exclude_uid)
	for uid, id in pairs(need_proto) do
		local inv = item.get_prototype(player, uid)
		if not inv or inv.id ~= id then return false end
		if used_proto[uid] or used_proto[tostring(uid)] then return false end
	end
	return true
end

	M.refresh = item.refresh_craft_integrity
	M.is_broken = item.is_craft_broken
	M.ingredients_fit = BP.ingredients_fit_allocation
end

return M

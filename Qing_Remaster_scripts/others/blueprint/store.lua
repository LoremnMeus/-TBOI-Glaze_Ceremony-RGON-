-- Blueprint persistence: crafts, prototypes, drafts, naming.
-- Structural extract from Item_Blue_Print.lua. Callers keep requiring the item façade.
local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local CraftIdentity = require("Qing_Remaster_scripts.mimics.craft_identity")

local M = {}

function M.attach(item, BP)

--- 本件制造锁定的成本槽数（编辑不跟「下一件」阶梯走）
function BP.locked_required_cost_from_rec(rec)
	if not rec then return 0 end
	local n = tonumber(rec.required_cost)
	if n ~= nil then return math.max(0, math.floor(n + 0.5)) end
	-- 旧存档未写 required_cost：按当时写入的成本条目数锁定
	return math.max(0, #(rec.cost_items or {}))
end

function BP.resolve_session_required_cost(player, edit_uid, edit_rec, draft)
	if edit_uid then
		local n = BP.locked_required_cost_from_rec(edit_rec)
		if draft then
			local dn = tonumber(draft.required_cost)
			if dn ~= nil then n = math.max(n, math.floor(dn + 0.5)) end
			-- 草稿多塞了成本只影响显示 have；不抬高锁定 need
		end
		return math.max(0, n)
	end
	local n = item.get_required_cost(player)
	if draft then
		local dn = tonumber(draft.required_cost)
		if dn ~= nil then n = math.max(n, math.floor(dn + 0.5)) end
	end
	return math.max(0, n)
end

--- 始终至少 1 个灰色底座槽；里小青首架隐藏；确认是否必填仍看 required_cost


--- 下一件非「纯审计」制造所需成本基底数。
--- 所有角色：一架 = 1 个基底（品质由该唯一基底决定）。
--- 里小青角色优惠：尚无真实飞行器时第一架 = 0，之后 = 1。
function item.get_required_cost(player)
	if player and player:GetPlayerType() == enums.Players.Spwq then
		local n = 0
		for _, rec in ipairs(item.get_craft_store(player)) do
			if rec.tutorial ~= true and not CraftProfile.craft_is_pure_audit_rec(rec) then
				n = n + 1
			end
		end
		if n <= 0 then return 0 end
		return 1
	end
	return 1
end

--- 里小青第一架真实飞行器：不显示底座，始终按品质 2（3 槽、倍率 1）填充。
local SPWQ_FIRST_AIR_QUALITY = 2

function BP.get_spwq_first_air_quality()
	return SPWQ_FIRST_AIR_QUALITY
end

function BP.is_spwq_free_first_air(player, craft)
	if not player or player:GetPlayerType() ~= enums.Players.Spwq then return false end
	if not craft then return false end
	if craft.tutorial_bag or craft.tutorial then return false end
	if craft.target and craft.target ~= enums.Items.Air_Flight then return false end
	return (tonumber(craft.required_cost) or 0) <= 0
end

function BP.apply_spwq_first_air_quality(rec, player)
	if not rec or rec.tutorial == true then return rec end
	if not BP.is_spwq_free_first_air(player, rec) then return rec end
	rec.base_quality = BP.get_spwq_first_air_quality()
	rec.remembered_quality = BP.get_spwq_first_air_quality()
	return rec
end

function BP.migrate_required_cost_once(bucket)
	if type(bucket) ~= "table" or bucket.cost_migrated_v2 == true then return end
	for _, rec in ipairs(bucket) do
		if type(rec) == "table" then
			local n = BP.locked_required_cost_from_rec(rec)
			if n > 1 then
				local kept = {}
				local kept_real = 0
				for _, entry in ipairs(rec.cost_items or {}) do
					if CraftProfile.is_real_entry(entry, rec.audit == true) then
						if kept_real < 1 then
							kept[#kept + 1] = entry
							kept_real = kept_real + 1
						end
					else
						kept[#kept + 1] = entry
					end
				end
				rec.cost_items = kept
				rec.required_cost = 1
			elseif n == 0 then
				rec.required_cost = 0
			else
				rec.required_cost = 1
			end
		end
	end
	bucket.cost_migrated_v2 = true
end


function BP.next_serial_for_target(player, target, exclude_uid)
	local max_s = 0
	for _, rec in ipairs(item.get_crafted_list(player) or {}) do
		if rec.target == target and rec.uid ~= exclude_uid then
			local s = tonumber(rec.serial) or 0
			if s > max_s then max_s = s end
		end
	end
	return max_s + 1
end

--- 建造页入口标签。仅一种底盘时显示「新建设计」，避免像选职业。
function BP.target_label(info, player)
	if not info then return "?" end
	if #item.build_targets <= 1 then
		return BP.lang_is_zh() and "新建设计" or "New Design"
	end
	local serial = BP.next_serial_for_target(player, info.id)
	return CraftProfile.build_display_name(info.id, serial, nil, BP.lang_is_zh())
end

--- 材料 + 成本槽道具一并参与附加型号字母抽取
function BP.naming_ingredients(ingredients, cost_items)
	local merged = {}
	local n = 0
	for k, entry in pairs(ingredients or {}) do
		local idx = tonumber(k)
		if idx then
			merged[idx] = CraftProfile.ingredient_id(entry) or entry
			if idx > n then n = idx end
		end
	end
	for _, id in ipairs(cost_items or {}) do
		n = n + 1
		merged[n] = CraftProfile.ingredient_id(id) or id
	end
	return merged
end

function BP.ensure_rec_serial(player, rec)
	if not rec or tonumber(rec.serial) then return end
	local n = 0
	for _, r in ipairs(item.get_crafted_list(player) or {}) do
		if r.target == rec.target then
			n = n + 1
			if r.uid == rec.uid then
				rec.serial = n
				return
			end
		end
	end
	rec.serial = n + 1
end

function BP.refresh_rec_display_name(rec, player)
	if not rec then return end
	if player then BP.ensure_rec_serial(player, rec) end
	local serial = tonumber(rec.serial) or 1
	local src = BP.naming_ingredients(rec.ingredients, rec.cost_items)
	rec.display_name = CraftProfile.build_display_name(rec.target, serial, src, true)
	rec.display_name_en = CraftProfile.build_display_name(rec.target, serial, src, false)
end

function BP.rec_label(rec)
	if not rec then return "?" end
	local zh = BP.lang_is_zh()
	local name = zh and rec.display_name or rec.display_name_en
	if not name or name == "" then
		name = CraftProfile.build_display_name(rec.target, rec.serial or 1, BP.naming_ingredients(rec.ingredients, rec.cost_items), zh)
	end
	local tag = (rec.audit and rec.tutorial ~= true) and (zh and " [审]" or " [A]") or ""
	local bang = rec.broken and "!" or ""
	return bang .. name .. tag
end


function BP.player_key(player)
	if not player or not BP.player_exists_safe(player) then return "0" end
	local ok, key = pcall(function()
		local data = player:GetData()
		return data.__Index or player.InitSeed
	end)
	return (ok and key ~= nil) and tostring(key) or "0"
end

-- pack 曾把 tostring 键误收成数字键；读档后 by_player[0] 有数据但运行时查 ["0"]。
function BP.merge_blueprint_bucket(dst, src)
	if type(dst) ~= "table" or type(src) ~= "table" then return dst or src end
	for i = 1, #src do
		table.insert(dst, src[i])
	end
	if type(src.prototypes) == "table" then
		dst.prototypes = dst.prototypes or {}
		for pk, pv in pairs(src.prototypes) do
			local sk = tostring(pk)
			if dst.prototypes[sk] == nil then dst.prototypes[sk] = pv end
		end
	end
	if type(src.drafts) == "table" then
		dst.drafts = dst.drafts or {}
		for dk, dv in pairs(src.drafts) do
			if dst.drafts[dk] == nil then dst.drafts[dk] = dv end
		end
	end
	if type(src.audit_ui) == "table" and dst.audit_ui == nil then
		dst.audit_ui = src.audit_ui
	end
	return dst
end

function BP.heal_string_keyed_map(map)
	if type(map) ~= "table" then return map end
	local moved = {}
	for k, v in pairs(map) do
		if type(k) == "number" and k == math.floor(k) then
			moved[#moved + 1] = {k, v}
		end
	end
	for i = 1, #moved do
		local nk, v = moved[i][1], moved[i][2]
		local sk = tostring(nk)
		if map[sk] == nil then
			map[sk] = v
		elseif type(map[sk]) == "table" and type(v) == "table" then
			-- 两边都有：合并字段，避免丢原型
			for fk, fv in pairs(v) do
				if map[sk][fk] == nil then map[sk][fk] = fv end
			end
		end
		map[nk] = nil
	end
	return map
end

function BP.heal_blueprint_root(root)
	if type(root) ~= "table" then return root end
	root.by_player = root.by_player or {}
	local bp = root.by_player
	local numeric = {}
	for k, bucket in pairs(bp) do
		if type(k) == "number" then
			numeric[#numeric + 1] = {k, bucket}
		end
	end
	for i = 1, #numeric do
		local nk, bucket = numeric[i][1], numeric[i][2]
		local sk = tostring(nk)
		if bp[sk] == nil then
			bp[sk] = bucket
		else
			bp[sk] = BP.merge_blueprint_bucket(bp[sk], bucket)
		end
		bp[nk] = nil
	end
	for _, bucket in pairs(bp) do
		if type(bucket) == "table" then
			bucket.prototypes = BP.heal_string_keyed_map(bucket.prototypes)
		end
	end
	return root
end

function BP.ensure_save()
	save.elses.Qing_Blue_Print = BP.heal_blueprint_root(save.elses.Qing_Blue_Print or {
		uid_counter = 0,
		by_player = {},
	})
	return save.elses.Qing_Blue_Print
end

function BP.checkpoint_run_save(reason)
	if save.RuntimeLoaded ~= true or type(save.SaveModData) ~= "function" then return false end
	local ok, result = pcall(save.SaveModData, "blueprint:"..tostring(reason or "unknown"))
	if not ok then
		print("QING:: Blueprint checkpoint failed ("..tostring(reason or "unknown").."): "..tostring(result))
		return false
	end
	return result ~= false
end

function BP.get_player_bucket(player)
	local root = BP.ensure_save()
	local key = BP.player_key(player)
	root.by_player[key] = root.by_player[key] or {}
	return root.by_player[key]
end

function item.get_craft_store(player)
	local bucket = BP.get_player_bucket(player)
	if player and player:GetPlayerType() == enums.Players.Spwq then
		BP.migrate_required_cost_once(bucket)
	end
	return bucket
end

function item.count_crafts_for_target(player, target_id)
	target_id = tonumber(target_id)
	if not player or not target_id then return 0 end
	local n = 0
	for _, rec in ipairs(item.get_craft_store(player) or {}) do
		if rec and rec.target == target_id then
			n = n + 1
		end
	end
	return n
end

--- 旧档曾给每架成品发过对应收藏品；按成品数各扣一件，剩下的才是底座拾取。
function item.migrate_strip_granted_craft_items(player)
	if not player then return false end
	local bucket = BP.get_player_bucket(player)
	if bucket.stripped_granted_craft_items then return false end
	bucket.stripped_granted_craft_items = true
	local removed = false
	for _, rec in ipairs(bucket) do
		local t = rec and rec.target
		if t == enums.Items.Air_Flight or t == enums.Items.Air_Terror then
			if player:HasCollectible(t, true) then
				player:RemoveCollectible(t)
				removed = true
			end
		end
	end
	if removed then
		BP.checkpoint_run_save("strip_granted_craft_items")
	end
	return removed
end

--- CheckFamiliar 用：真实持有份数 + 蓝图库存份数（制造不再发收藏品）
function item.familiar_check_count(player, collectible_id)
	collectible_id = tonumber(collectible_id)
	if not player or not collectible_id then return 0 end
	item.migrate_strip_granted_craft_items(player)
	local held = player:GetCollectibleNum(collectible_id) or 0
	return held + item.count_crafts_for_target(player, collectible_id)
end

--- 原型全局元数据（清房保底、交易房限额等）
function item.ensure_prototype_root()
	local root = BP.ensure_save()
	root.prototype_uid_counter = root.prototype_uid_counter or 0
	root.clean_streak = root.clean_streak or 0
	root.shop_proto_rooms = root.shop_proto_rooms or {}
	return root
end

function BP.get_prototype_inv(player)
	local bucket = BP.get_player_bucket(player)
	bucket.prototypes = bucket.prototypes or {}
	return bucket.prototypes
end

function item.add_prototype(player, collectible_id, meta)
	if not player then return nil end
	collectible_id = tonumber(collectible_id)
	if not collectible_id or not CraftProfile.is_prototype_eligible(collectible_id) then
		return nil
	end
	local root = item.ensure_prototype_root()
	root.prototype_uid_counter = (root.prototype_uid_counter or 0) + 1
	local uid = root.prototype_uid_counter
	local inv = BP.get_prototype_inv(player)
	inv[tostring(uid)] = {
		uid = uid,
		id = collectible_id,
		pool = meta and meta.pool,
		quality = meta and meta.quality,
		source = meta and meta.source or "pickup",
	}
	BP.checkpoint_run_save("prototype_add")
	item.refresh_craft_integrity(player)
	return uid
end

function item.get_prototype(player, uid)
	if not player or uid == nil then return nil end
	return BP.get_prototype_inv(player)[tostring(uid)]
end

function item.clear_prototypes(player)
	if not player then return end
	local bucket = BP.get_player_bucket(player)
	bucket.prototypes = {}
	BP.checkpoint_run_save("prototype_clear")
end

function item.list_free_prototypes(player, exclude_uid)
	local out = {}
	local used = item.count_allocated_prototypes(player, exclude_uid)
	for _, rec in pairs(BP.get_prototype_inv(player)) do
		local uid = rec.uid or tonumber(rec.uid)
		if uid and not used[uid] and not used[tostring(uid)]
			and not CraftProfile.is_ingredient_banned(rec.id) then
			out[#out + 1] = {
				collectible = rec.id,
				source = "prototype",
				prototype_uid = uid,
			}
		end
	end
	table.sort(out, function(a, b)
		return (a.prototype_uid or 0) < (b.prototype_uid or 0)
	end)
	return out
end

function item.count_allocated_prototypes(player, exclude_uid)
	local used = {}
	for _, rec in ipairs(item.get_craft_store(player)) do
		-- 按条目占用：审计槽不占原型；混装配方里的原型仍占
		if rec.uid ~= exclude_uid and not CraftProfile.craft_revive_is_locked(rec) then
			for _, entry in pairs(rec.ingredients or {}) do
				if CraftProfile.is_prototype_entry(entry) then
					local uid = entry.prototype_uid
					used[uid] = true
					used[tostring(uid)] = true
				end
			end
		end
	end
	return used
end

--- 旧档：材料槽里的 mirror 迁入专用 mirror_module 字段。
function BP.migrate_rec_mirror_fields(rec)
	if type(rec) ~= "table" then return end
	if rec.mirror_module then return end
	for k, entry in pairs(rec.ingredients or {}) do
		if CraftProfile.is_mirror_entry(entry) then
			local id = CraftProfile.ingredient_id(entry)
			if id and id ~= 0 then
				rec.mirror_module = {id = id, source = "mirror"}
			end
			rec.ingredients[k] = nil
			break
		end
	end
end

function BP.player_has_mirror_birthright(player)
	if not player or player:GetPlayerType() ~= enums.Players.Spwq then return false end
	return player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT, true)
end

function BP.draft_key(target_id, edit_uid)
	if edit_uid then return "e_"..tostring(edit_uid) end
	return "t_"..tostring(target_id or 0)
end

function BP.get_drafts(player)
	local bucket = BP.get_player_bucket(player)
	bucket.drafts = bucket.drafts or {}
	return bucket.drafts
end

--- 审计全道具 UI 偏好（标签筛选等），跨打开复原
--- tag_status_schema=2：状态标签并入后，清掉旧「仅有效」迁移留下的 invalid/unimplemented=false
local AUDIT_TAG_STATUS_SCHEMA = 2
function BP.get_audit_ui_prefs(player)
	local bucket = BP.get_player_bucket(player)
	bucket.audit_ui = bucket.audit_ui or {}
	local prefs = bucket.audit_ui
	if prefs.tag_status_schema ~= AUDIT_TAG_STATUS_SCHEMA then
		prefs.tag_status_schema = AUDIT_TAG_STATUS_SCHEMA
		if type(prefs.tag_enabled) == "table" then
			prefs.tag_enabled.valid = true
			prefs.tag_enabled.invalid = true
			prefs.tag_enabled.unimplemented = true
		end
		prefs.hide_gray = false
		prefs.audit_filter = "all"
	end
	return prefs
end

function BP.clear_craft_draft(player, target_id, edit_uid)
	if not player then return end
	local drafts = BP.get_drafts(player)
	drafts[BP.draft_key(target_id, edit_uid)] = nil
end


function item.get_crafted_list(player)
	return item.get_craft_store(player)
end

--- Collectible instances already locked into other crafts (items stay in bag, but cannot be reused).


function item.find_craft(player, uid)
	for _, rec in ipairs(item.get_craft_store(player)) do
		if rec.uid == uid then return rec end
	end
end

--- 从库存永久删除一件飞行器/空怖成品：释放宝宝、开放成本档位（不再扣收藏品）
function item.delete_craft(player, uid)
	if not player or uid == nil then return false end
	local store = item.get_craft_store(player)
	local idx, rec
	for i, r in ipairs(store) do
		if r.uid == uid then
			idx = i
			rec = r
			break
		end
	end
	if not rec or not idx then return false end

	local Craft_Familiar_holder = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
	local function release_bound_airs(variant)
		for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant, -1, false, false)) do
			local p = auxi.check_spawner_player(fam)
			if p and auxi.check_for_the_same(p, player) and auxi.check_all_exists(fam) then
				local d = fam:GetData()
				if CraftIdentity.get_uid(fam) == uid then
					if Craft_Familiar_holder.release_for_air then
						pcall(Craft_Familiar_holder.release_for_air, fam)
					end
					fam:Remove()
				end
			end
		end
	end
	if enums.Familiars.QingsAirs then
		release_bound_airs(enums.Familiars.QingsAirs)
	end
	if enums.Familiars.Air_Terror then
		release_bound_airs(enums.Familiars.Air_Terror)
	end

	table.remove(store, idx)
	BP.clear_craft_draft(player, rec.target, uid)

	player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
	player:EvaluateItems()
	item.refresh_craft_integrity(player)
	BP.checkpoint_run_save("craft_delete")
	pcall(function() BP.get_bandwidth().on_craft_removed(player, uid) end)
	return true
end

function item.get_tutorial_save(player)
	local bucket = BP.get_player_bucket(player)
	if type(bucket.tutorial) ~= "table" then
		bucket.tutorial = {offered = false, done = false, declined = false}
	end
	return bucket.tutorial
end

--- 审计练习机：不占真实配额。spec.skip_eval 时由调用方一次性 EvaluateItems。
function item.create_audit_craft(player, spec)
	spec = spec or {}
	if not player then return nil end
	local root = BP.ensure_save()
	local store = item.get_craft_store(player)
	root.uid_counter = (root.uid_counter or 0) + 1
	local uid = root.uid_counter
	local target = spec.target or enums.Items.Air_Flight
	local rec = {
		uid = uid,
		target = target,
		ingredients = spec.ingredients or {},
		cost_items = spec.cost_items or {},
		required_cost = spec.required_cost or 0,
		audit = spec.audit ~= false,
		tutorial = spec.tutorial == true,
		lesson_kind = spec.lesson_kind,
		serial = spec.serial or BP.next_serial_for_target(player, target),
		experimental = false,
		eye_phase = 0,
		base_quality = spec.base_quality,
		remembered_quality = spec.base_quality,
	}
	rec.profile = CraftProfile.build_profile(
		CraftProfile.ingredients_with_mirror(rec.ingredients, rec.mirror_module),
		{
		player = player,
		rec = rec,
		commit_state = true,
		base_quality = spec.base_quality,
	})
	if spec.display_name then rec.display_name = spec.display_name end
	if spec.display_name_en then rec.display_name_en = spec.display_name_en end
	if not rec.display_name then
		BP.refresh_rec_display_name(rec, player)
	end
	table.insert(store, rec)
	pcall(function() BP.get_bandwidth().on_craft_added(player, uid) end)
	if spec.active == false then
		pcall(function() BP.get_bandwidth().set_active(player, uid, false) end)
	end
	BP.checkpoint_run_save("craft_tutorial_add")
	if spec.skip_eval ~= true then
		player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
		player:EvaluateItems()
	end
	return rec
end

function item.delete_tutorial_crafts(player)
	if not player then return 0 end
	local uids = {}
	for _, rec in ipairs(item.get_craft_store(player) or {}) do
		if type(rec) == "table" and rec.tutorial == true and rec.uid ~= nil then
			uids[#uids + 1] = rec.uid
		end
	end
	for i = 1, #uids do
		item.delete_craft(player, uids[i])
	end
	return #uids
end

--- opts = {air=, runtime=}；传入后合并动态属性（金币/嗜血/191 等）
function item.get_profile_for_uid(player, uid, opts)
	local rec = item.find_craft(player, uid)
	if not rec then return nil end
	BP.apply_spwq_first_air_quality(rec, player)
	opts = opts or {}
	-- 始终按当前配方重建，保证库存「更改」后立刻生效；动态项随所属玩家实时重算
	rec.profile = CraftProfile.build_profile(
		CraftProfile.ingredients_with_mirror(rec.ingredients, rec.mirror_module),
		{
		player = player,
		rec = rec,
		air = opts.air,
		runtime = opts.runtime,
	})
	-- per-craft 设置（巧克力 / Tech X 蓄力）挂在 rec 上，重建后合并
	if rec.main_charge_ratio == nil then
		rec.main_charge_ratio = math.max(rec.chocolate_charge_ratio or 1, rec.techx_charge_ratio or 1)
	end
	CraftProfile.apply_craft_settings(rec.profile, {
		main_charge_ratio = rec.main_charge_ratio,
	})
	rec.profile.craft_uid = uid
	return rec.profile
end


--- Next unbound Air Flight craft uid for this player (for familiar Init).
function item.claim_air_flight_uid(player)
	local store = item.get_craft_store(player)
	local bound = {}
	for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, enums.Familiars.QingsAirs, -1, false, false)) do
		local p = auxi.check_spawner_player(fam)
		if p and auxi.check_for_the_same(p, player) then
			local uid = CraftIdentity.get_uid(fam)
			if uid then bound[uid] = true end
		end
	end
	for _, rec in ipairs(store) do
		if rec.target == enums.Items.Air_Flight and not bound[rec.uid] then
			return rec.uid, item.get_profile_for_uid(player, rec.uid)
		end
	end
end

	M.ensure_save = BP.ensure_save
	M.get_player_bucket = BP.get_player_bucket
	M.get_craft_store = item.get_craft_store
	M.find_craft = item.find_craft
	M.delete_craft = item.delete_craft
	M.get_profile_for_uid = item.get_profile_for_uid
	M.claim_air_flight_uid = item.claim_air_flight_uid
	M.add_prototype = item.add_prototype
	M.get_prototype = item.get_prototype
	M.clear_prototypes = item.clear_prototypes
	M.checkpoint_run_save = BP.checkpoint_run_save
	M.get_drafts = BP.get_drafts
end

return M

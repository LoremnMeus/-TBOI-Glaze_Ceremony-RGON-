-- Craft combat resolver: recipe / context → profile, charge domain, attack semantics.
-- Structural extract from craft_combat_profile.lua. No combat semantic changes.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local dev_env = require("Qing_Remaster_scripts.core.dev_environment")

local Mod = {}

function Mod.attach(M)

function M.weapon_fire_delay_mul(weapon)
	return M.WEAPON_FIRE_DELAY_MUL[weapon or 1] or 1
end

--- 制造档案开火延迟：build_profile 已把主武器倍率写入 stats.firedelay
function M.craft_fire_delay(profile, weapon)
	if not profile or not profile.stats then return 10 end
	local st = profile.stats
	-- 兼容旧档案：未烘焙时按 base×mul 现算
	if st.firedelay_base ~= nil then
		return tonumber(st.firedelay) or 10
	end
	local base = tonumber(st.firedelay) or 10
	weapon = weapon or profile.weapon or 1
	return base * M.weapon_fire_delay_mul(weapon)
end

-- 幸运概率：分母保持正数，结果 clamp 到 [0, cap]
function M.craft_revive_get_spent(rec)
	if not rec then return {} end
	local spent = rec.craft_revive_spent
	if type(spent) ~= "table" then
		spent = {}
		rec.craft_revive_spent = spent
	end
	-- 旧字段迁移
	if rec.one_up_spent and (tonumber(spent.one_up) or 0) < 1 then
		spent.one_up = 1
	end
	return spent
end

function M.craft_revive_source_spent(rec, key)
	if not key then return 0 end
	local spent = M.craft_revive_get_spent(rec)
	return tonumber(spent[key]) or 0
end

function M.craft_revive_is_locked(rec)
	return rec ~= nil and rec.craft_revive_locked == true
end

function M.craft_revive_recipe_has(craft_prof, rec, src)
	if not src then return false end
	if craft_prof and craft_prof.extras and craft_prof.extras[src.key] == true then
		return true
	end
	local counts = craft_prof and craft_prof.counts
	if type(counts) == "table" and (tonumber(counts[src.id]) or 0) > 0 then
		return true
	end
	if rec and type(rec.ingredients) == "table" then
		local c = M.counts_from_ingredients(rec.ingredients)
		return (tonumber(c[src.id]) or 0) > 0
	end
	return false
end

--- 复活道具仍在玩家身上（真实持有）；消失后不得再救飞行器 / 不得用 MeusNil 冒充
function M.craft_revive_player_has(player, src)
	if not player or not src or not src.id then return false end
	local n = player.GetCollectibleNum and player:GetCollectibleNum(src.id, true)
	return (tonumber(n) or 0) > 0
end

function M.craft_revive_remaining(rec, src)
	if not src then return 0 end
	if src.chance then return 1 end -- 概率源每次可再掷
	local uses = tonumber(src.uses) or 0
	if uses <= 0 then return 0 end
	local used = M.craft_revive_source_spent(rec, src.key)
	local left = uses - used
	if left < 0 then left = 0 end
	return left
end

function M.craft_revive_follower_dimmed(rec, src)
	if not src or not src.follower then return false end
	local uses = tonumber(src.uses) or 0
	if uses <= 0 then return false end
	return M.craft_revive_source_spent(rec, src.key) >= uses
end

--- 坠毁触发时选源：配方有 +（玩家仍持有 或 audit/prototype 虚拟源）；确定次数优先；项圈失败则继续尝试后续源
function M.craft_revive_try_pick(craft_prof, rec, player)
	for _, src in ipairs(M.CRAFT_REVIVE_SOURCES) do
		local available = M.craft_revive_player_has(player, src)
			or M.craft_has_virtual_source_for(rec, src.id)
		if M.craft_revive_recipe_has(craft_prof, rec, src) and available then
			if src.chance then
				local roll = Random() % 100
				if roll < (tonumber(src.chance) or 0) then
					return src
				end
			elseif M.craft_revive_remaining(rec, src) > 0 then
				return src
			end
		end
	end
	return nil
end

function M.craft_revive_spend(rec, src)
	if not rec or not src then return end
	local spent = M.craft_revive_get_spent(rec)
	local uses = tonumber(src.uses) or 0
	if uses > 0 then
		spent[src.key] = (tonumber(spent[src.key]) or 0) + 1
	end
	rec.craft_revive_locked = true
	rec.one_up_spent = (tonumber(spent.one_up) or 0) > 0 or nil
end

--- 蓝图确认修改：解除锁定；已不在配方中的源清 spent
function M.craft_revive_on_confirm(rec, profile)
	if not rec then return end
	rec.craft_revive_locked = nil
	local spent = rec.craft_revive_spent
	if type(spent) ~= "table" then
		rec.one_up_spent = nil
		return
	end
	local extras = profile and profile.extras or {}
	local counts = profile and profile.counts or {}
	for key, _ in pairs(spent) do
		local src = M.CRAFT_REVIVE_BY_KEY[key]
		local keep = extras[key] == true
		if not keep and src then
			keep = (tonumber(counts[src.id]) or 0) > 0
		end
		if not keep then
			spent[key] = nil
		end
	end
	rec.one_up_spent = (tonumber(spent.one_up) or 0) > 0 or nil
end

--- Flight 从 broken 真正恢复为有效时，为仍装载的一次性复活源开启新一轮充能。
--- 必须由完整性检查确认 repaired 后调用；普通面板确认不得调用。
function M.craft_revive_on_repaired(rec, profile)
	if not rec then return end
	local spent = rec.craft_revive_spent
	if type(spent) == "table" then
		local extras = profile and profile.extras or {}
		local counts = profile and profile.counts or {}
		for key, _ in pairs(spent) do
			local src = M.CRAFT_REVIVE_BY_KEY[key]
			local loaded = extras[key] == true
			if not loaded and src then
				loaded = (tonumber(counts[src.id]) or 0) > 0
			end
			if loaded then spent[key] = nil end
		end
	end
	rec.craft_revive_locked = nil
	rec.one_up_spent = nil
	rec.craft_revive_repair_epoch = (tonumber(rec.craft_revive_repair_epoch) or 0) + 1
end

function M.body_scale_from_counts(counts)
	local mul = 1
	for id, n in pairs(counts or {}) do
		if n and n > 0 then
			local b = M.BODY_SCALE_MUL[id]
			if b then
				for _ = 1, n do
					mul = mul * b
				end
			end
		end
	end
	return math.max(0.25, math.min(3, mul))
end

--- 属性类：原版必须有手写 STAT_DELTA；模组道具才允许 CacheFlags 兜底。
function M.ingredient_id(entry)
	if type(entry) == "table" then
		return tonumber(entry.id or entry.collectible)
	end
	return tonumber(entry)
end

function M.is_prototype_entry(entry)
	return type(entry) == "table" and entry.source == "prototype"
		and entry.prototype_uid ~= nil
end

function M.is_mirror_entry(entry)
	return type(entry) == "table" and entry.source == "mirror"
end

--- 合并专用镜像槽到材料表（_mirror 键供 counts/build_profile 消费）。
function M.ingredients_with_mirror(ingredients, mirror_module)
	local out = {}
	for k, v in pairs(ingredients or {}) do
		out[k] = v
	end
	local id = M.ingredient_id(mirror_module)
	if id and id ~= 0 then
		if type(mirror_module) == "table" then
			out._mirror = mirror_module
		else
			out._mirror = {id = id, source = "mirror"}
		end
	end
	return out
end

--- 单条材料来源。旧档：纯 number + rec.audit=true → 视为 audit。
function M.ingredient_source(entry, audit_fallback)
	if type(entry) == "table" then
		local src = entry.source
		if src == "prototype" or src == "audit" or src == "real" or src == "mirror" then
			return src
		end
		if entry.prototype_uid ~= nil then
			return "prototype"
		end
	end
	if audit_fallback then
		return "audit"
	end
	return "real"
end

function M.is_audit_entry(entry, audit_fallback)
	return M.ingredient_source(entry, audit_fallback) == "audit"
end

function M.is_real_entry(entry, audit_fallback)
	return M.ingredient_source(entry, audit_fallback) == "real"
end

function M.normalize_base_quality(q)
	q = tonumber(q)
	if q == nil then return nil end
	if q < 0 then return 0 end
	if q > 4 then return 4 end
	return math.floor(q)
end

function M.collectible_quality(id)
	id = tonumber(id)
	if not id or id <= 0 then return nil end
	local ok, cfg = pcall(function()
		return Isaac.GetItemConfig():GetCollectible(id)
	end)
	if not ok or not cfg then return 0 end
	return M.normalize_base_quality(cfg.Quality) or 0
end

function M.quality_from_cost_items(cost_items)
	for _, entry in ipairs(cost_items or {}) do
		local id = M.ingredient_id(entry)
		local q = M.collectible_quality(id)
		if q ~= nil then return q end
	end
	return nil
end

function M.resolve_base_quality(ctx)
	if type(ctx) ~= "table" then return nil end
	if ctx.base_quality ~= nil then
		return M.normalize_base_quality(ctx.base_quality)
	end
	local rec = ctx.rec
	if type(rec) ~= "table" then return nil end
	if rec.base_quality ~= nil then
		return M.normalize_base_quality(rec.base_quality)
	end
	if rec.remembered_quality ~= nil then
		return M.normalize_base_quality(rec.remembered_quality)
	end
	return M.quality_from_cost_items(rec.cost_items)
end

function M.slots_for_base_quality(q)
	q = M.normalize_base_quality(q)
	if q == nil then return 0 end
	return M.BASE_QUALITY_SLOTS[q] or 3
end

function M.stat_mul_for_base_quality(q)
	q = M.normalize_base_quality(q)
	if q == nil then return 1 end
	return M.BASE_QUALITY_STAT_MUL[q] or 1
end

function M.apply_base_quality_to_stats(stats, quality)
	if type(stats) ~= "table" then return stats end
	local q = M.normalize_base_quality(quality)
	local mul = M.stat_mul_for_base_quality(q)
	stats.base_quality = q
	stats.base_quality_mul = mul
	if math.abs(mul - 1) <= 0.001 then return stats end
	stats.damage = (tonumber(stats.damage) or 0) * mul
	stats.range = (tonumber(stats.range) or 0) * mul
	stats.shotspeed = (tonumber(stats.shotspeed) or 0) * mul
	stats.speed = (tonumber(stats.speed) or 0) * mul
	stats.luck = (tonumber(stats.luck) or 0) * mul
	stats.firedelay = math.max(1, (tonumber(stats.firedelay) or 10) / mul)
	return stats
end

--- 遍历材料+成本条目
function M.for_each_craft_entry(ingredients, cost_items, fn)
	if not fn then return end
	for slot, entry in pairs(ingredients or {}) do
		fn(entry, "ingredient", slot)
	end
	for i, entry in ipairs(cost_items or {}) do
		fn(entry, "cost", i)
	end
end

--- 整机「属审计」：存在至少一条 audit 材料/成本（并非「全部都不来自审计」）
function M.craft_has_any_audit(ingredients, cost_items, audit_fallback)
	local found = false
	M.for_each_craft_entry(ingredients, cost_items, function(entry)
		if found then return end
		if M.ingredient_source(entry, audit_fallback) == "audit" then
			found = true
		end
	end)
	if found then return true end
	-- 无条目时：仅当旧档 fallback 且无任何材料时不标审计
	return false
end

function M.craft_has_any_audit_rec(rec)
	if not rec then return false end
	return M.craft_has_any_audit(rec.ingredients, rec.cost_items, rec.audit == true)
end

--- 纯审计：有至少一条条目，且全部为 audit（无 real/prototype）
--- 用于豁免成本阶梯/确认时的真实成本与配额校验
function M.craft_is_pure_audit(ingredients, cost_items, audit_fallback)
	local any = false
	local all_audit = true
	M.for_each_craft_entry(ingredients, cost_items, function(entry)
		any = true
		if M.ingredient_source(entry, audit_fallback) ~= "audit" then
			all_audit = false
		end
	end)
	return any and all_audit
end

function M.craft_is_pure_audit_rec(rec)
	if not rec then return false end
	return M.craft_is_pure_audit(rec.ingredients, rec.cost_items, rec.audit == true)
end

--- 原型 UID 是否已被 integrity 标为丢失
local function craft_prototype_uid_missing(rec, uid)
	if uid == nil or not rec or not rec.broken_missing then return false end
	local pu = rec.broken_missing.prototype_uids
	if type(pu) ~= "table" then return false end
	return pu[uid] == true or pu[tostring(uid)] == true
end

--- 配方中该 collectible 是否以仍有效的 audit/prototype 虚拟持有（可 MeusNil / 不依赖玩家 innate）
--- 丢失的 prototype UID 不算虚拟源。
function M.craft_has_virtual_source_for(rec, collectible_id, opts)
	collectible_id = tonumber(collectible_id)
	if not rec or not collectible_id then return false end
	opts = opts or {}
	for _, entry in pairs(rec.ingredients or {}) do
		if M.ingredient_id(entry) == collectible_id then
			local src = M.ingredient_source(entry, rec.audit == true)
			if src == "audit" then
				return true
			elseif src == "prototype" then
				local uid = entry.prototype_uid
				if opts.prototype_alive then
					if opts.prototype_alive(uid) then return true end
				elseif not craft_prototype_uid_missing(rec, uid) then
					return true
				end
			elseif src == "mirror" then
				return true
			end
		end
	end
	return false
end

--- 捕捉类制造宝宝材料是否仍可用（audit 恒可用；prototype 需 UID 仍在；real 需本配方未记缺且玩家仍持有）。
--- always_spawn_synthetic 不走此判定（不依赖原版实体，缺料时暂维持 extras）。
--- opts.prototype_alive = function(uid) -> boolean
function M.craft_familiar_material_available(player, rec, collectible_id, opts)
	collectible_id = tonumber(collectible_id)
	if not rec or not collectible_id then return false end
	opts = opts or {}
	local fb = rec.audit == true
	local miss_n = rec.broken_missing and tonumber(rec.broken_missing[collectible_id]) or 0
	for _, entry in pairs(rec.ingredients or {}) do
		if M.ingredient_id(entry) == collectible_id then
			local src = M.ingredient_source(entry, fb)
			if src == "audit" then
				return true
			elseif src == "prototype" then
				local uid = entry.prototype_uid
				if opts.prototype_alive then
					if opts.prototype_alive(uid) then return true end
				elseif not craft_prototype_uid_missing(rec, uid) then
					return true
				end
			elseif src == "real" or src == "mirror" then
				if miss_n <= 0
					and player
					and player.HasCollectible
					and player:HasCollectible(collectible_id, true)
				then
					return true
				end
			end
		end
	end
	local mm = rec.mirror_module
	if mm and M.ingredient_id(mm) == collectible_id then
		if miss_n <= 0
			and player
			and player.HasCollectible
			and player:HasCollectible(collectible_id, true)
		then
			return true
		end
	end
	return false
end

--- 蓝图「道具原型」抽池资格（唯一入口）
function M.is_prototype_eligible(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	-- 池耗尽哨兵；禁止当作可用原型
	if id == (CollectibleType.COLLECTIBLE_BREAKFAST or 25) then return false end
	if M.is_ingredient_banned(id) then return false end
	if M.STAT_AUDIT_EXCLUDE[id] then return false end
	-- 缺数值幅度（审计黄标）≠ 可用原型
	if M.missing_stat_delta(id) then return false end
	local col = Isaac.GetItemConfig():GetCollectible(id)
	if not col or col.Hidden then return false end
	-- 首版：仅被动与宝宝
	if col.Type ~= ItemType.ITEM_PASSIVE and col.Type ~= ItemType.ITEM_FAMILIAR then
		return false
	end
	if ItemConfig.TAG_QUEST and col.Tags and (col.Tags & ItemConfig.TAG_QUEST) ~= 0 then
		return false
	end
	if not M.has_impl(id) then return false end
	local pool = Game():GetItemPool()
	if pool and pool.CanSpawnCollectible then
		local ok = pool:CanSpawnCollectible(id, false)
		if ok == false then return false end
	end
	return true
end

function M.counts_from_ingredients(ingredients)
	local counts = {}
	if not ingredients then return counts end
	for _, entry in pairs(ingredients) do
		local id = M.ingredient_id(entry)
		if id and id ~= 0 and not M.is_ingredient_banned(id) then
			counts[id] = (counts[id] or 0) + 1
		end
	end
	return counts
end

--- 按来源拆分材料份数：{ [id] = {real=, audit=, prototype=} }
function M.source_counts_from_ingredients(ingredients, audit_fallback)
	local out = {}
	if not ingredients then return out end
	for _, entry in pairs(ingredients) do
		local id = M.ingredient_id(entry)
		if id and id ~= 0 and not M.is_ingredient_banned(id) then
			local src = M.ingredient_source(entry, audit_fallback)
			local bucket = out[id]
			if not bucket then
				bucket = {real = 0, audit = 0, prototype = 0}
				out[id] = bucket
			end
			if src == "prototype" then
				bucket.prototype = bucket.prototype + 1
			elseif src == "audit" then
				bucket.audit = bucket.audit + 1
			elseif src == "mirror" then
				bucket.mirror = (bucket.mirror or 0) + 1
			else
				bucket.real = bucket.real + 1
			end
		end
	end
	return out
end

function M.source_bucket_for(profile_or_rec, id)
	id = tonumber(id)
	if not id or id <= 0 or not profile_or_rec then
		return {real = 0, audit = 0, prototype = 0}
	end
	local sc = profile_or_rec.source_counts and profile_or_rec.source_counts[id]
	if sc then
		return {
			real = tonumber(sc.real) or 0,
			audit = tonumber(sc.audit) or 0,
			prototype = tonumber(sc.prototype) or 0,
		}
	end
	local total = 0
	if profile_or_rec.counts then
		total = tonumber(profile_or_rec.counts[id]) or 0
	elseif profile_or_rec.ingredients then
		total = (M.counts_from_ingredients(profile_or_rec.ingredients) or {})[id] or 0
	end
	-- 旧档无 source_counts：整份记为 audit（避免误认领玩家原版实体）
	return {real = 0, audit = total, prototype = 0}
end

function M.bomb_effects_from_counts(counts, init_seed)
	local flags = BitSet128(0, 0)
	local variant = nil
	local nancy = false
	local available = {}
	local ids = {}
	for id in pairs(M.BOMB_EFFECTS) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local effect = M.BOMB_EFFECTS[id]
		if not effect.nancy then available[#available + 1] = effect end
		if (counts and counts[id] or 0) > 0 then
			if effect.flag then flags = flags | effect.flag end
			if effect.variant ~= nil then variant = effect.variant end
			if effect.nancy then nancy = true end
		end
	end
	if nancy and #available > 0 then
		table.sort(available, function(a, b) return (a.variant or -1) < (b.variant or -1) end)
		local chosen = available[((tonumber(init_seed) or 0) % #available) + 1]
		if chosen.flag then flags = flags | chosen.flag end
		if chosen.variant ~= nil then variant = chosen.variant end
	end
	return flags, variant
end

function M.form_synergy_for_collectible(id, player)
	id = tonumber(id)
	if not id or id <= 0 or not player then return nil end
	-- inherited / excluded：不因套装 TAG 被点亮或当成有效模块
	if M.is_inherited_player_effect and M.is_inherited_player_effect(id) then
		return nil
	end
	if M.is_craft_excluded and M.is_craft_excluded(id) then
		return nil
	end
	local TAG_BOOK = ItemConfig.TAG_BOOK or (1 << 13)
	local TAG_BABY = ItemConfig.TAG_BABY or (1 << 9)
	local TAG_GUPPY = ItemConfig.TAG_GUPPY or (1 << 5)
	local TAG_SYRINGE = ItemConfig.TAG_SYRINGE or (1 << 1)
	if M.collectible_has_tag(id, TAG_BOOK)
		and M.player_has_form(player, PlayerForm.PLAYERFORM_BOOK_WORM)
	then
		return "bookworm"
	end
	if M.collectible_has_tag(id, TAG_BABY)
		and M.player_has_form(player, PlayerForm.PLAYERFORM_BABY)
	then
		return "conjoined"
	end
	-- 超级猫套：玩家已是 Guppy + 材料带 TAG_GUPPY → 可亮起（提供 TEAR_MULLIGAN 协同）
	if M.collectible_has_tag(id, TAG_GUPPY)
		and M.player_has_form(player, PlayerForm.PLAYERFORM_GUPPY)
	then
		return "guppy"
	end
	if M.collectible_has_tag(id, TAG_SYRINGE)
		and M.player_has_form(player, PlayerForm.PLAYERFORM_DRUGS)
	then
		return "spun"
	end
	return nil
end

function M.is_effectively_lit(id, ctx)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	ctx = ctx or {}
	if M.is_inherited_player_effect and M.is_inherited_player_effect(id) then
		return false
	end
	if M.is_craft_excluded and M.is_craft_excluded(id) then
		return false
	end
	-- 套装材料：玩家已变身 + 对应 TAG → 亮起（圣经等主动书无独立接线也适用）
	if M.form_synergy_for_collectible(id, ctx.player) then
		return true
	end
	if not M.has_impl(id) then return false end
	-- 主 morph（博士/硫磺/妈刀等）始终亮起
	if M.is_morph_item(id) then return true end
	local kind = M.effect_gate_kind(id)
	if not kind then return true end
	local weapon = tonumber(ctx.weapon) or 1
	local list = ctx.list or {}
	local counts = ctx.counts or {}
	if kind == "bomb" then
		return weapon == 5 or weapon == 6
			or (list.dr or 0) > 0
			or (list.epic or 0) > 0
			or (counts[378] or 0) > 0 -- No. 2 掉落炸弹，配方炸弹效果可亮起
			or (counts[273] or 0) > 0 -- 脑浆爆炸吃 BOMB_EFFECTS
			or (list.bobs_brain or 0) > 0
	end
	if kind == "fetus_sec" then
		return weapon == 14 or (list.sec or 0) > 0
	end
	if kind == "moms_wig" then
		return (counts[217] or 0) > 0
	end
	return true
end

--- 从蓝图草稿槽位统计 counts，并解析预览武器上下文
--- opts/player：传入玩家以便套装材料亮起
function M.preview_weapon_context_from_craft(craft, player)
	local counts = {}
	if craft then
		for _, slot in ipairs(craft.slots or {}) do
			local tok = slot.token and craft.token_map and craft.token_map[slot.token]
			local id = tok and tonumber(tok.collectible)
			if id and id > 0 then
				counts[id] = (counts[id] or 0) + 1
			end
		end
	end
	local list = M.list_from_counts(counts)
	local weapon = select(1, M.resolve_weapon(list, counts))
	return {
		weapon = weapon or 1,
		list = list,
		counts = counts,
		player = player,
	}
end

function M.list_from_counts(counts)
	counts = counts or {}
	local function n(id) return counts[id] or 0 end
	local result = {
		brimstone = n(118),
		tech = n(68),
		techX = n(395),
		knife = n(114),
		lung = n(229),
		dr = n(52),
		epic = n(168),
		sword = n(579),
		ludo = n(329),
		pol = n(169),
		cho = n(69),
		soy = n(330),
		soy2 = n(561),
		sec = n(678),
		ipec = n(149),
		godhead = n(331),
		tri = n(533),
		hae = n(531),
		coal = n(132),
		pro = n(261),
		divi = n(453) + n(224) + n(104),
		redfire = n(616),
		bluefire = n(495),
		eye = n(558),
		tech2 = n(152),
		tech5 = n(244),
		cursed_eye = n(316),
		fruit_cake = n(418),
		bobby = n(8),
		maggy = n(67),
		gish = n(99),
		steven = n(100),
		ghost_baby = n(163),
		harlequin = n(167),
		rainbow = n(174),
		rotten = n(268),
		mongo = n(322),
		fates_reward = n(361),
		seraphim = n(390),
		succubus = n(417),
		lil_loki = n(435),
		freezer = n(608),
		robo = n(95),
		demon = n(113),
		robo2 = n(267),
		milk = n(436),
		one_up = n(11),
		dead_cat = n(81),
		inner_child = n(688),
		guppys_collar = n(212),
		lazarus_rags = n(332),
		ankh = n(161),
		judas_shadow = n(311),
		gemini = n(318),
		cains_other_eye = n(319),
		incubus = n(360),
		twisted_pair = n(698),
		lil_brimstone = n(275),
		lil_abaddon = n(679),
		lil_monstro = n(471),
		little_chubby = n(88),
		big_chubby = n(473),
		lil_gurdy = n(384),
		censer = n(387),
		papa_fly = n(430),
		multidimensional_baby = n(431),
		finger = n(467),
		depression = n(469),
		headless_baby = n(269),
		farting_baby = n(404),
		boiled_baby = n(607),
		juicy_sack = n(266),
		bobs_brain = n(273),
		dry_baby = n(265),
		obsessed_fan = n(426),
		lil_spewer = n(537),
		guppys_hairball = n(187),
		holy_water = n(178),
		hallowed_ground = n(543),
		my_shadow = n(433),
		shade = n(468),
		king_baby = n(472),
		sack_of_pennies = n(94),
		little_chad = n(96),
		relic = n(98),
		bomb_bag = n(131),
		mystery_sack = n(271),
		lil_chest = n(362),
		charged_baby = n(372),
		rune_bag = n(389),
		acid_baby = n(491),
		sack_of_sacks = n(500),
		mystery_egg = n(539),
		inner = n(2),
		mutant = n(153),
		twenty = n(245),
		wiz = n(358),
		sacred = n(182),
	}
	-- 新兼容只需 register_compat 一次，不再要求手工补本函数。
	-- familiar 默认 list = key；规范化漏写时这里仍按同一语义投影，禁止静默丢计数。
	for id, def in pairs(M.COMPAT_REGISTRY or {}) do
		local list_key = def.list
		if not list_key and def.category == "familiar" then
			list_key = def.key
		end
		if list_key then
			result[list_key] = n(id)
		end
	end
	return result
end

--- Recipe-only multishot count (mirrors attack_list_calculator manual path).
function M.build_multishot(counts)
	counts = counts or {}
	local inner = counts[2] or 0
	local mutant = counts[153] or 0
	local twenty = counts[245] or 0
	local wiz = counts[358] or 0
	local cnt1 = 1
	if inner > 0 or mutant > 0 then
		cnt1 = cnt1 + 1
	end
	local perfect = twenty
	if inner > 0 or mutant > 0 then
		perfect = perfect - 1
	end
	cnt1 = cnt1 + mutant * 2 + inner + math.max(0, perfect) + wiz
	return {
		count = math.max(1, cnt1),
		inner = inner,
		mutant = mutant,
		twenty = twenty,
		wiz = wiz,
	}
end

function M.collectible_has_tag(id, tag)
	id = tonumber(id)
	if not id or id <= 0 or tag == nil then return false end
	-- 勿 tonumber(tag)：运行时 TAG_* 可能不是 plain number，tonumber 会变 nil 导致套装全失效
	local col = Isaac.GetItemConfig():GetCollectible(id)
	if not col then return false end
	-- HasTags / Tags 位运算；API 可能返回 1/0 而非 boolean，禁止 == true
	if col.HasTags then
		if col:HasTags(tag) then return true end
		return false
	end
	local tags = col.Tags
	if tags == nil then return false end
	return (tags & tag) == tag
end

function M.counts_have_item_tag(counts, tag)
	for id, n in pairs(counts or {}) do
		if n and n > 0 and M.collectible_has_tag(id, tag) then
			return true
		end
	end
	return false
end

--- 是否已变身；勿用 player.HasPlayerForm 字段探测；勿对返回值 == true（引擎常给 1/0）
function M.player_has_form(player, form)
	if not player or form == nil then return false end
	local ok, has = pcall(function()
		return player:HasPlayerForm(form)
	end)
	if ok and has then return true end
	-- RGON：计数满 3 也视为变身
	if player.GetPlayerFormCounter then
		local ok2, n = pcall(function()
			return player:GetPlayerFormCounter(form)
		end)
		if ok2 and type(n) == "number" and n >= 3 then return true end
	end
	return false
end

-- ---------- 套装诊断 jsonl ----------
-- 输出：codex_work/logs/craft_form_debug.jsonl
local function form_log_escape(s)
	s = tostring(s or "")
	s = string.gsub(s, "\\", "\\\\")
	s = string.gsub(s, "\"", "\\\"")
	s = string.gsub(s, "\n", "\\n")
	s = string.gsub(s, "\r", "\\r")
	return s
end

local function form_log_encode_value(v)
	local vt = type(v)
	if v == nil then return "null" end
	if vt == "boolean" then return v and "true" or "false" end
	if vt == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		return string.format("%.6g", v)
	end
	if vt == "table" then
		-- 数组优先
		local n = #v
		if n > 0 then
			local parts = {}
			for i = 1, n do parts[i] = form_log_encode_value(v[i]) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, val in pairs(v) do
			parts[#parts + 1] = "\"" .. form_log_escape(k) .. "\":" .. form_log_encode_value(val)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "\"" .. form_log_escape(v) .. "\""
end

local function form_log_write(row)
	if not dev_env.probes_allowed() then return end
	if not M.enable_form_log then return end
	row = row or {}
	row.fr = Game():GetFrameCount()
	local line = form_log_encode_value(row)
	pcall(function()
		if not io or not io.open then return end
		-- 唯一规范文件；仅两种相对写法（禁止根目录/机器绝对路径兜底）
		local paths = {
			"mods/Qing_remaster/codex_work/logs/craft_form_debug.jsonl",
			"../mods/Qing_remaster/codex_work/logs/craft_form_debug.jsonl",
		}
		local mode = M._form_log_ready and "a" or "w"
		for _, path in ipairs(paths) do
			local f = io.open(path, mode)
			if f then
				f:write(line .. "\n")
				f:close()
				M._form_log_ready = true
				M._form_log_path = path
				return
			end
		end
	end)
end

local function form_probe_player(player, form)
	local out = {
		form = form,
		ok = false,
		raw = nil,
		raw_type = "nil",
		truthy = false,
		counter = nil,
	}
	if not player or form == nil then return out end
	local ok, raw = pcall(function() return player:HasPlayerForm(form) end)
	out.ok = ok
	if ok then
		out.raw = raw
		out.raw_type = type(raw)
		out.truthy = not not raw
		out.eq_true = (raw == true)
		out.eq_one = (raw == 1)
	else
		out.err = tostring(raw)
	end
	if player.GetPlayerFormCounter then
		local ok2, n = pcall(function() return player:GetPlayerFormCounter(form) end)
		if ok2 then out.counter = n end
	end
	return out
end

local function form_probe_collectible(id, tags)
	id = tonumber(id)
	local out = {id = id, name = "?"}
	if not id or id <= 0 then return out end
	local col = Isaac.GetItemConfig():GetCollectible(id)
	if not col then
		out.missing = true
		return out
	end
	out.name = col.Name or "?"
	out.type = col.Type
	out.tags_raw = col.Tags
	out.tags_type = type(col.Tags)
	out.has_HasTags = col.HasTags ~= nil
	out.hit = {}
	for key, tag in pairs(tags) do
		local row = {tag = key, tag_val = tag, tag_type = type(tag)}
		if col.HasTags then
			local ok, r = pcall(function() return col:HasTags(tag) end)
			row.hasTags_ok = ok
			if ok then
				row.hasTags_raw = r
				row.hasTags_type = type(r)
				row.hasTags_truthy = not not r
			else
				row.hasTags_err = tostring(r)
			end
		end
		if col.Tags ~= nil and tag ~= nil then
			local ok2, bit_ok = pcall(function()
				return (col.Tags & tag) == tag
			end)
			row.bit_ok = ok2 and bit_ok or false
			if not ok2 then row.bit_err = tostring(bit_ok) end
		end
		row.helper = M.collectible_has_tag(id, tag)
		out.hit[key] = row
	end
	return out
end

--- 套装解析诊断（节流：同签名约 30 帧写一次）
function M.log_form_resolve(src, player, counts, forms)
	if not M.enable_form_log then return end
	counts = counts or {}
	forms = forms or {}
	local TAGS = {
		book = ItemConfig.TAG_BOOK or (1 << 13),
		baby = ItemConfig.TAG_BABY or (1 << 9),
		guppy = ItemConfig.TAG_GUPPY or (1 << 5),
		syringe = ItemConfig.TAG_SYRINGE or (1 << 1),
	}
	local count_keys = {}
	for id, n in pairs(counts) do
		if n and n > 0 then
			count_keys[#count_keys + 1] = {id = tonumber(id) or id, n = n}
		end
	end
	table.sort(count_keys, function(a, b)
		local ai, bi = tonumber(a.id) or 0, tonumber(b.id) or 0
		return ai < bi
	end)
	local sig_parts = {tostring(src or "?")}
	for _, row in ipairs(count_keys) do
		sig_parts[#sig_parts + 1] = tostring(row.id) .. "x" .. tostring(row.n)
	end
	if player then
		sig_parts[#sig_parts + 1] = "p" .. tostring(GetPtrHash(player))
	end
	sig_parts[#sig_parts + 1] = "f"
		.. (forms.bookworm and "B" or "-")
		.. (forms.spun and "S" or "-")
		.. (forms.guppy and "G" or "-")
		.. (forms.conjoined and "C" or "-")
	local sig = table.concat(sig_parts, "|")
	local fr = Game():GetFrameCount()
	if M._form_log_sig == sig and fr < (M._form_log_next or 0) then
		return
	end
	M._form_log_sig = sig
	M._form_log_next = fr + 30

	local items = {}
	for _, row in ipairs(count_keys) do
		items[#items + 1] = form_probe_collectible(row.id, TAGS)
		items[#items].n = row.n
	end

	form_log_write({
		e = "resolve",
		src = src or "?",
		player = player and true or false,
		tag_book = TAGS.book,
		tag_book_type = type(TAGS.book),
		tag_syringe = TAGS.syringe,
		tag_syringe_type = type(TAGS.syringe),
		pf_bookworm = PlayerForm and PlayerForm.PLAYERFORM_BOOK_WORM,
		pf_drugs = PlayerForm and PlayerForm.PLAYERFORM_DRUGS,
		has_bookworm = form_probe_player(player, PlayerForm and PlayerForm.PLAYERFORM_BOOK_WORM),
		has_drugs = form_probe_player(player, PlayerForm and PlayerForm.PLAYERFORM_DRUGS),
		has_baby = form_probe_player(player, PlayerForm and PlayerForm.PLAYERFORM_BABY),
		has_guppy = form_probe_player(player, PlayerForm and PlayerForm.PLAYERFORM_GUPPY),
		counts_n = #count_keys,
		items = items,
		helper_has_book_tag = M.counts_have_item_tag(counts, TAGS.book),
		helper_has_syringe_tag = M.counts_have_item_tag(counts, TAGS.syringe),
		helper_player_book = M.player_has_form(player, PlayerForm and PlayerForm.PLAYERFORM_BOOK_WORM),
		helper_player_drugs = M.player_has_form(player, PlayerForm and PlayerForm.PLAYERFORM_DRUGS),
		forms = {
			bookworm = forms.bookworm and true or false,
			spun = forms.spun and true or false,
			guppy = forms.guppy and true or false,
			conjoined = forms.conjoined and true or false,
		},
		dmg = nil,
	})
end

--- 显示射速（≈ tears）加减：内部 MaxFireDelay ↔ 30/(delay+1)
function M.add_tears_stat(stats, delta)
	if not stats then return end
	delta = tonumber(delta) or 0
	if delta == 0 then return end
	local fr = 30 / (math.max(-0.75, tonumber(stats.firedelay) or 10) + 1)
	fr = math.max(0.1, fr + delta)
	stats.firedelay = math.max(1, 30 / fr - 1)
end

--- 玩家套装 × 配方材料 → 每飞行器至多生效一次（不叠层）
--- Conjoined / Bookworm / Spun：玩家已变身 + 配方含对应 TAG。
--- Guppy → 超级猫套：玩家已变身 + 配方含有效 TAG_GUPPY 模块（不含 inherited/excluded）
---   → forms.guppy；主攻显式 OR TEAR_MULLIGAN。玩家仅有猫套、无模块时不算超级猫套。
function M.resolve_player_forms(player, counts, src)
	local forms = {}
	if not player then
		M.log_form_resolve(src or "no_player", player, counts, forms)
		return forms
	end
	local TAG_BOOK = ItemConfig.TAG_BOOK or (1 << 13)
	local TAG_BABY = ItemConfig.TAG_BABY or (1 << 9)
	local TAG_GUPPY = ItemConfig.TAG_GUPPY or (1 << 5)
	local TAG_SYRINGE = ItemConfig.TAG_SYRINGE or (1 << 1)
	if M.player_has_form(player, PlayerForm.PLAYERFORM_BABY)
		and M.counts_have_item_tag(counts, TAG_BABY)
	then
		forms.conjoined = true
	end
	if M.player_has_form(player, PlayerForm.PLAYERFORM_GUPPY) then
		for id, n in pairs(counts or {}) do
			if n and n > 0
				and not (M.is_inherited_player_effect and M.is_inherited_player_effect(id))
				and not (M.is_craft_excluded and M.is_craft_excluded(id))
				and M.collectible_has_tag(id, TAG_GUPPY)
			then
				forms.guppy = true
				break
			end
		end
	end
	if M.player_has_form(player, PlayerForm.PLAYERFORM_BOOK_WORM)
		and M.counts_have_item_tag(counts, TAG_BOOK)
	then
		forms.bookworm = true
	end
	if M.player_has_form(player, PlayerForm.PLAYERFORM_DRUGS)
		and M.counts_have_item_tag(counts, TAG_SYRINGE)
	then
		forms.spun = true
	end
	M.log_form_resolve(src or "resolve", player, counts, forms)
	return forms
end

function M.apply_player_form_stats(stats, forms)
	if not stats or not forms then return end
	if forms.conjoined then
		stats.damage = (tonumber(stats.damage) or 0) - 0.3
		M.add_tears_stat(stats, -0.3)
	end
	if forms.spun then
		stats.damage = (tonumber(stats.damage) or 0) + 2
		stats.speed = (tonumber(stats.speed) or 0) + 0.15
	end
end

--- 套装额外弹道相对瞄准角（度）。Bookworm 仅在 roll_bookworm 时掷 25%。
function M.form_extra_angles(profile, opts)
	opts = opts or {}
	local angs = {}
	local forms = profile and profile.forms
	if not forms then return angs end
	if forms.conjoined then
		angs[#angs + 1] = -45
		angs[#angs + 1] = 45
	end
	if forms.bookworm and opts.roll_bookworm then
		local hit = false
		if opts.rng and opts.rng.RandomFloat then
			hit = opts.rng:RandomFloat() < 0.25
		else
			hit = math.random(4) == 1
		end
		if hit then angs[#angs + 1] = 0 end
	end
	return angs
end

function M.form_extra_shot_dirs(base_dir, profile, opts)
	local dirs = {}
	for _, ang in ipairs(M.form_extra_angles(profile, opts)) do
		if ang == 0 then
			dirs[#dirs + 1] = base_dir
		else
			dirs[#dirs + 1] = auxi.get_by_rotate(base_dir, ang)
		end
	end
	return dirs
end

local function morph_set_key(present_weapons)
	local ids = {}
	for w in pairs(present_weapons) do ids[#ids + 1] = w end
	table.sort(ids)
	local parts = {}
	for i = 1, #ids do parts[i] = tostring(ids[i]) end
	return table.concat(parts, ",")
end

local function fallback_pri_weapon(present_weapons)
	local best_w, best_p = 1, -1
	for _, m in ipairs(M.MORPH) do
		if present_weapons[m.weapon] and m.pri > best_p then
			best_p = m.pri
			best_w = m.weapon
		end
	end
	return best_w
end

local function ludo_is_overridden(present)
	for w in pairs(present or {}) do
		if M.LUDO_OVERRIDDEN_BY[w] then return true end
	end
	return false
end

--- 动态主武器表决（§14）：覆盖数量优先，同分看 CARRIER_PRI，零覆盖回退旧 pri。
--- Ludovico 可消费 Brim/Tech/TechX/Knife 改形；仍被 Epic/剖腹产/英灵剑覆盖。
function M.resolve_weapon(list, counts)
	list = list or {}
	counts = counts or {}
	local morph_items = {}
	local present = {} -- weapon -> true（重复份数不参与表决）
	for _, m in ipairs(M.MORPH) do
		local c = counts[m.id] or 0
		if c > 0 then
			morph_items[#morph_items + 1] = m.id
			present[m.weapon] = true
		end
	end

	local weapon = 1
	local compat_consumed = {}
	local used_fallback_pri = false

	local override = M.EXACT_MORPH_SET_OVERRIDE[morph_set_key(present)]
	if override then
		weapon = override
	elseif present[M.LUDO_WEAPON] and not ludo_is_overridden(present) then
		-- Ludo 单独或与可改形副 morph：主武器固定 8（Tech X 视为 Tech 环）
		weapon = M.LUDO_WEAPON
	else
		local best_score, best_carrier, best_w = -1, -1, 1
		local any_positive = false
		for cand in pairs(present) do
			local score = 0
			local can = M.BRANCH_COMPAT[cand]
			if can then
				for other in pairs(present) do
					if other ~= cand and can[other] then
						score = score + 1
					end
				end
			end
			if score > 0 then any_positive = true end
			local carrier = M.CARRIER_PRI[cand] or 0
			if score > best_score or (score == best_score and carrier > best_carrier) then
				best_score = score
				best_carrier = carrier
				best_w = cand
			end
		end
		if any_positive then
			weapon = best_w
		else
			weapon = fallback_pri_weapon(present)
			used_fallback_pri = true
		end
	end

	local can = M.BRANCH_COMPAT[weapon] or {}
	for other in pairs(present) do
		if other ~= weapon and can[other] then
			compat_consumed[#compat_consumed + 1] = other
		end
	end
	table.sort(compat_consumed)

	local consumed_set = {[weapon] = true}
	for _, w in ipairs(compat_consumed) do consumed_set[w] = true end
	local unsupported_morphs = {}
	for other in pairs(present) do
		if not consumed_set[other] then
			unsupported_morphs[#unsupported_morphs + 1] = other
		end
	end
	table.sort(unsupported_morphs)

	-- 血泪小攻击：主武为 Brim/Tech/TechX/Dr/Knife 时覆盖为眼泪；多 guest 仍 1 发主气球，
	-- 落地 shared 均分各 mode 面额。肺/史诗/剖腹产/英灵剑/鲁多维科胜出时不覆盖。
	local haemo_override = false
	local haemo_guests = {}
	local haemo_share_guests = {}
	local haemo_burst_mode = "tears"
	if (list.hae or 0) > 0 and M.HAEMO_OVERRIDE_WEAPONS[weapon] then
		haemo_override = true
		local guests = {}
		for other in pairs(present) do
			if M.HAEMO_OVERRIDE_WEAPONS[other] then
				guests[#guests + 1] = other
			end
		end
		table.sort(guests)
		haemo_guests = guests
		local share = {}
		for _, g in ipairs(haemo_guests) do
			if M.HAEMO_SHAREABLE[g] and M.HAEMO_BURST_MODE[g] then
				share[#share + 1] = g
			end
		end
		table.sort(share)
		haemo_share_guests = share
		if #share == 0 then
			haemo_burst_mode = "tears"
		elseif #share == 1 then
			haemo_burst_mode = M.HAEMO_BURST_MODE[share[1]] or "tears"
		else
			haemo_burst_mode = "shared"
		end
		weapon = 1
		compat_consumed = {}
		consumed_set = {[1] = true}
		for _, g in ipairs(haemo_guests) do
			compat_consumed[#compat_consumed + 1] = g
			consumed_set[g] = true
		end
		table.sort(compat_consumed)
		unsupported_morphs = {}
		for other in pairs(present) do
			if not consumed_set[other] then
				unsupported_morphs[#unsupported_morphs + 1] = other
			end
		end
		table.sort(unsupported_morphs)
	end

	local extras = {
		lung = list.lung or 0,
		tech2 = (list.tech2 or 0) > 0,
		tech5 = (list.tech5 or 0) > 0,
		chocolate = (list.cho or 0) > 0,
		cursed_eye = (list.cursed_eye or 0) > 0,
		haemolacria = (list.hae or 0) > 0,
		haemo_override = haemo_override,
		haemo_guests = haemo_guests,
		haemo_share_guests = haemo_share_guests,
		haemo_burst_mode = haemo_burst_mode,
		-- 卢多/剖腹产保留主武时仍标记血泪侧车效果
		haemo_ludo_proc = (list.hae or 0) > 0 and weapon == 8,
		haemo_fetus_proc = (list.hae or 0) > 0 and weapon == 14,
		brother_bobby = (list.bobby or 0) > 0,
		sister_maggy = (list.maggy or 0) > 0,
		little_steven = (list.steven or 0) > 0,
		ghost_baby = (list.ghost_baby or 0) > 0,
		harlequin_baby = (list.harlequin or 0) > 0,
		lil_loki = (list.lil_loki or 0) > 0,
		little_gish = (list.gish or 0) > 0,
		freezer_baby = (list.freezer or 0) > 0,
		seraphim = (list.seraphim or 0) > 0,
		succubus = (list.succubus or 0) > 0,
		rainbow_baby = (list.rainbow or 0) > 0,
		rotten_baby = (list.rotten or 0) > 0,
		mongo_baby = (list.mongo or 0) > 0,
		fates_reward = (list.fates_reward or 0) > 0,
		robo_baby = (list.robo or 0) > 0,
		robo_baby_2 = (list.robo2 or 0) > 0,
		demon_baby = (list.demon or 0) > 0,
		gemini = (list.gemini or 0) > 0,
		cains_other_eye = (list.cains_other_eye or 0) > 0,
		incubus = (list.incubus or 0) > 0,
		twisted_pair = (list.twisted_pair or 0) > 0,
		lil_brimstone = (list.lil_brimstone or 0) > 0,
		lil_abaddon = (list.lil_abaddon or 0) > 0,
		lil_monstro = (list.lil_monstro or 0) > 0,
		little_chubby = (list.little_chubby or 0) > 0,
		big_chubby = (list.big_chubby or 0) > 0,
		lil_gurdy = (list.lil_gurdy or 0) > 0,
		fruit_cake = (list.fruit_cake or 0) > 0,
		candle_red = (list.redfire or 0) > 0,
		candle_blue = (list.bluefire or 0) > 0,
		milk = (list.milk or 0) > 0,
		one_up = (list.one_up or 0) > 0,
		dead_cat = (list.dead_cat or 0) > 0,
		inner_child = (list.inner_child or 0) > 0,
		guppys_collar = (list.guppys_collar or 0) > 0,
		lazarus_rags = (list.lazarus_rags or 0) > 0,
		ankh = (list.ankh or 0) > 0,
		judas_shadow = (list.judas_shadow or 0) > 0,
		censer = (list.censer or 0) > 0,
		papa_fly = (list.papa_fly or 0) > 0,
		multidimensional_baby = (list.multidimensional_baby or 0) > 0,
		finger = (list.finger or 0) > 0,
		depression = (list.depression or 0) > 0,
		headless_baby = (list.headless_baby or 0) > 0,
		farting_baby = (list.farting_baby or 0) > 0,
		boiled_baby = (list.boiled_baby or 0) > 0,
		juicy_sack = (list.juicy_sack or 0) > 0,
		bobs_brain = (list.bobs_brain or 0) > 0,
		dry_baby = (list.dry_baby or 0) > 0,
		obsessed_fan = (list.obsessed_fan or 0) > 0,
		lil_spewer = (list.lil_spewer or 0) > 0,
		guppys_hairball = (list.guppys_hairball or 0) > 0,
		holy_water = (list.holy_water or 0) > 0,
		hallowed_ground = (list.hallowed_ground or 0) > 0,
		my_shadow = (list.my_shadow or 0) > 0,
		shade = (list.shade or 0) > 0,
		king_baby = (list.king_baby or 0) > 0,
		sack_of_pennies = (list.sack_of_pennies or 0) > 0,
		little_chad = (list.little_chad or 0) > 0,
		relic = (list.relic or 0) > 0,
		bomb_bag = (list.bomb_bag or 0) > 0,
		mystery_sack = (list.mystery_sack or 0) > 0,
		lil_chest = (list.lil_chest or 0) > 0,
		charged_baby = (list.charged_baby or 0) > 0,
		rune_bag = (list.rune_bag or 0) > 0,
		acid_baby = (list.acid_baby or 0) > 0,
		sack_of_sacks = (list.sack_of_sacks or 0) > 0,
		mystery_egg = (list.mystery_egg or 0) > 0,
		used_fallback_pri = used_fallback_pri,
	}
	for _, def in pairs(M.COMPAT_REGISTRY or {}) do
		if def and def.category == "familiar" and type(def.key) == "string" then
			local list_key = def.list or def.key
			extras[def.key] = (tonumber(list[list_key]) or 0) > 0
		end
	end
	return weapon, morph_items, extras, compat_consumed, unsupported_morphs
end

function M.build_synergy(weapon, list, extras)
	list = list or {}
	extras = extras or {}
	local brim = list.brimstone or 0
	local tech = list.tech or 0
	local techX = list.techX or 0
	local knife = list.knife or 0
	local dr = list.dr or 0
	local sword = list.sword or 0
	local stack_key = M.WEAPON_STACK_KEY[weapon]
	local extra_shots = 0
	if stack_key then
		extra_shots = math.max(0, (list[stack_key] or 0) - 1)
	end
	-- 血泪覆盖：叠份 guest morph → 额外主血泪基数（再经均分加成）
	if extras.haemo_override then
		local stack_src = extras.haemo_share_guests
		if not stack_src or #stack_src == 0 then
			stack_src = extras.haemo_guests or {}
		end
		for _, g in ipairs(stack_src) do
			local sk = M.WEAPON_STACK_KEY[g]
			if sk then
				extra_shots = extra_shots + math.max(0, (list[sk] or 0) - 1)
			end
		end
	end
	-- Ludovico 改形优先级：刀 > 硫磺环（可叠 Tech 外观）> 科技环（含 Tech X）
	local ludo_knife = weapon == 8 and knife > 0
	local ludo_brim = weapon == 8 and brim > 0 and not ludo_knife
	local ludo_tech = weapon == 8 and (tech > 0 or techX > 0) and not ludo_knife and not ludo_brim
	local haemo_mode = extras.haemo_burst_mode or "tears"
	local share_guests = extras.haemo_share_guests or {}
	local haemo_has_brim = false
	for _, g in ipairs(share_guests) do
		if g == 2 then
			haemo_has_brim = true
			break
		end
	end
	-- 无均分 guest 时回退旧单 mode
	if not haemo_has_brim and haemo_mode == "brim" then haemo_has_brim = true end
	return {
		thick_brim = brim >= 2,
		brim_tech = (weapon == 2 and tech > 0) or (ludo_brim and (tech > 0 or techX > 0))
			or (extras.haemo_override and haemo_has_brim and tech > 0),
		brim_techx = (weapon == 2 and techX > 0) or (weapon == 9 and brim > 0),
		brim_sword = weapon == 2 and sword > 0,
		knife_brim = weapon == 4 and brim > 0,
		knife_techx = weapon == 4 and techX > 0,
		knife_tech = weapon == 4 and tech > 0,
		techx_tech = weapon == 9 and tech > 0,
		sword_tech = (weapon == 10 or weapon == 13) and (tech > 0 or techX > 0),
		dr_brim = weapon == 5 and brim > 0,
		dr_techx = weapon == 5 and techX > 0,
		dr_tech = weapon == 5 and tech > 0,
		dr_sword = weapon == 5 and sword > 0,
		ludo_knife = ludo_knife,
		ludo_brim = ludo_brim,
		ludo_tech = ludo_tech,
		haemo_burst_mode = haemo_mode,
		haemo_share_guests = share_guests,
		haemo_brim_tech = extras.haemo_override and haemo_has_brim and tech > 0,
		epic_burst = {
			knife = knife,
			brimstone = brim,
			tech = tech,
			techX = techX,
			dr = dr,
			sword = sword,
		},
		extra_shots = extra_shots,
		brim_copies = brim,
		tech_copies = tech,
		techx_copies = techX,
		knife_copies = knife,
	}
end

function M.mask_from_counts(counts)
	local mask = BitSet128(0, 0)
	for id, n in pairs(counts or {}) do
		if n and n > 0 then
			local e = M.TEAR_EFFECTS[id]
			local f = M.TEAR_FLAG_MASK[id] or (e and e.flag)
			if f then mask = mask | f end
		end
	end
	return mask
end

--- 由 base_seed + salt 派生独立 RNG（每道具/每弹各一流，避免 pairs 顺序污染）
function M.derived_rng(base_seed, salt)
	local seed = math.floor((tonumber(base_seed) or 1) + (tonumber(salt) or 0) * 16777619) & 0xffffffff
	-- 不把线性相邻 seed 直接交给 SetSeed 后只取首值；先做 32 位雪崩混合。
	-- 旧实现还强制奇数，会把相邻的 (2n, 2n+1) 折叠成同一 seed。
	seed = seed ~ (seed >> 16)
	seed = (seed * 0x7feb352d) & 0xffffffff
	seed = seed ~ (seed >> 15)
	seed = (seed * 0x846ca68b) & 0xffffffff
	seed = seed ~ (seed >> 16)
	seed = seed & 0x7fffffff
	if seed == 0 then seed = 1 end
	local rng = RNG()
	rng:SetSeed(seed, 35)
	return rng
end

--- counts 安全读取（兼容 number / string 键）
function M.count_of(counts, id)
	if not counts then return 0 end
	id = tonumber(id)
	if not id then return 0 end
	local n = counts[id]
	if n == nil then n = counts[tostring(id)] end
	return tonumber(n) or 0
end

function M.tear_flag_base_seed(opts)
	opts = opts or {}
	if opts.seed and tonumber(opts.seed) and tonumber(opts.seed) ~= 0 then
		return tonumber(opts.seed)
	end
	local room = Game() and Game():GetRoom()
	local seed = (room and room.GetDecorationSeed and room:GetDecorationSeed()) or 1
	seed = seed + (tonumber(opts.shot_serial) or 0) * 17
	seed = seed + (tonumber(opts.craft_uid) or 0) * 131
	seed = seed + (tonumber(opts.projectile_index) or 0) * 8191
	seed = seed + (tonumber(opts.init_seed) or 0) % 1000003
	return seed
end

--- Almond Milk（561）：每泪从打包池抽 1–2 个 TearFlag（不另采样；避开爆炸/分裂等重形态）
function M.roll_almond_milk_flags(rng)
	local pool = M.ALMOND_MILK_FLAG_POOL
	local n = #pool
	if n <= 0 then return BitSet128(0, 0) end
	local pick_n = 1
	if rng and rng.RandomInt then
		pick_n = 1 + rng:RandomInt(2) -- 1 或 2
	else
		pick_n = 1 + (math.random(2) - 1)
	end
	if pick_n > n then pick_n = n end
	local idx = {}
	for i = 1, n do idx[i] = i end
	local mask = BitSet128(0, 0)
	for _ = 1, pick_n do
		local j
		if rng and rng.RandomInt then
			j = rng:RandomInt(#idx) + 1
		else
			j = math.random(#idx)
		end
		local p = table.remove(idx, j)
		local flag = pool[p]
		if flag then mask = mask | flag end
	end
	return mask
end

--- 按配方独立投掷 TearFlags（不读玩家缓存 / GetTearHitParams）
--- opts: {seed=, shot_serial=, craft_uid=, projectile_index=, init_seed=}
--- 概率项按「排序后的道具 ID」各自派生 RNG，不再顺序消耗同一流。
function M.roll_tear_flags(luck, profile, opts)
	opts = opts or {}
	local counts = (profile and profile.counts) or opts.counts or {}
	local mask = BitSet128(0, 0)
	local base_seed = M.tear_flag_base_seed(opts)
	luck = tonumber(luck) or 0
	local ids = {}
	for id, n in pairs(counts) do
		id = tonumber(id)
		if id and n and n > 0 and M.TEAR_EFFECTS[id] then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	local proj = tonumber(opts.projectile_index) or 0
	for _, id in ipairs(ids) do
		local e = M.TEAR_EFFECTS[id]
		if e then
			if e.always_flag then mask = mask | e.always_flag end
			-- craft_sim_burst（血泪等）：不写引擎分裂 flag，落地由自模拟触发
			if e.flag and not e.craft_sim_burst then
				local ok = true
				if e.roll then
					local rng = M.derived_rng(base_seed, id * 65537 + proj * 13)
					ok = e.roll(luck, rng) == true
				end
				if ok then mask = mask | e.flag end
			end
		end
	end
	-- 杏仁奶：每泪独立抽 1–2 个打包 flag
	if (counts[561] or 0) > 0 then
		local rng = M.derived_rng(base_seed, 561 * 65537 + proj * 13)
		mask = mask | M.roll_almond_milk_flags(rng)
	end
	if profile and profile.runtime and profile.runtime.flag_extra then
		mask = mask | profile.runtime.flag_extra
	end
	-- 超级猫套：玩家 Guppy + 配方有效 TAG_GUPPY 模块 → 主攻显式 TEAR_MULLIGAN（命中产蝇）
	if profile and profile.forms and profile.forms.guppy
		and TearFlags and TearFlags.TEAR_MULLIGAN
	then
		mask = mask | TearFlags.TEAR_MULLIGAN
	end
	if profile and profile.runtime and profile.runtime.occult_stats_only
		and TearFlags and TearFlags.TEAR_OCCULT then
		mask = mask & ~TearFlags.TEAR_OCCULT
	end
	-- 双保险：制造血泪绝不带 TEAR_BURSTSPLIT（stamp 会整表赋值 flags，旧逻辑曾写回该 flag）
	if (counts[531] or 0) > 0 and TearFlags and TearFlags.TEAR_BURSTSPLIT then
		mask = mask & ~TearFlags.TEAR_BURSTSPLIT
	end
	return mask
end

function M.stats_from_counts(counts)
	local s = {
		damage = M.BASE_STATS.damage,
		firedelay = M.BASE_STATS.firedelay,
		shotspeed = M.BASE_STATS.shotspeed,
		range = M.BASE_STATS.range,
		luck = M.BASE_STATS.luck,
		speed = M.BASE_STATS.speed,
		scale = 1,
	}
	local dmg_mul, delay_mul, range_mul, shotspeed_mul, speed_mul, luck_mul, scale_mul = 1, 1, 1, 1, 1, 1, 1
	local scale_add = 0
	local once_done = {}
	for id, n in pairs(counts or {}) do
		if n and n > 0 then
			local d = M.STAT_DELTA[id]
			if d then
				local reps = d.once and 1 or n
				if d.once then
					if once_done[id] then reps = 0 else once_done[id] = true end
				end
				for _ = 1, reps do
					s.damage = s.damage + (d.damage or 0)
					s.firedelay = s.firedelay + (d.firedelay or 0)
					s.shotspeed = s.shotspeed + (d.shotspeed or 0)
					s.range = s.range + (d.range or 0)
					s.luck = s.luck + (d.luck or 0)
					s.speed = s.speed + (d.speed or 0)
					dmg_mul = dmg_mul * (d.damage_mul or 1)
					delay_mul = delay_mul * (d.firedelay_mul or 1)
					range_mul = range_mul * (d.range_mul or 1)
					shotspeed_mul = shotspeed_mul * (d.shotspeed_mul or 1)
					speed_mul = speed_mul * (d.speed_mul or 1)
					luck_mul = luck_mul * (d.luck_mul or 1)
					scale_mul = scale_mul * (d.scale_mul or 1)
					scale_add = scale_add + (d.scale_add or 0)
				end
			end
		end
	end
	s.damage = s.damage * dmg_mul
	s.firedelay = math.max(1, s.firedelay * delay_mul)
	s.range = s.range * range_mul
	s.shotspeed = s.shotspeed * shotspeed_mul
	s.speed = s.speed * speed_mul
	s.luck = s.luck * luck_mul
	s.scale = math.max(0.12, scale_mul + scale_add)
	s.scale_add_applied = scale_add
	s.dmg_mul_applied = dmg_mul
	s.delay_mul_applied = delay_mul
	s.range_mul_applied = range_mul
	s.shotspeed_mul_applied = shotspeed_mul
	s.speed_mul_applied = speed_mul
	s.luck_mul_applied = luck_mul
	s.scale_mul_applied = scale_mul
	return s
end

function M.needs_eye_phase(counts)
	if (counts and counts[600] or 0) > 0 then return true end
	for id, n in pairs(counts or {}) do
		if n and n > 0 and M.ONE_EYE[id] then return true end
	end
	return false
end

--- 当前眼睛相位的单眼加成（side：0 左 / 1 右）
function M.one_eye_bonus(counts, side)
	local out = {damage = 0, range = 0, shotspeed = 0, damage_mul = 1, blood_variant = false}
	side = (side or 0) % 2
	for id, n in pairs(counts or {}) do
		local oe = M.ONE_EYE[id]
		if oe and n and n > 0 and oe.side == side then
			local copies = oe.once and 1 or n
			for _ = 1, copies do
				out.damage = out.damage + (oe.damage or 0)
				out.range = out.range + (oe.range or 0)
				out.shotspeed = out.shotspeed + (oe.shotspeed or 0)
				out.damage_mul = out.damage_mul * (oe.damage_mul or 1)
				out.blood_variant = out.blood_variant or oe.blood_variant == true
			end
		end
	end
	return out
end

function M.multishot_dirs(base_dir, count)
	count = math.max(1, math.floor(tonumber(count) or 1))
	local dirs = {}
	if count <= 1 then
		dirs[1] = base_dir
		return dirs
	end
	local span = math.min(60, 10 * (count - 1))
	for i = 1, count do
		local t = (i - 1) / (count - 1) - 0.5
		dirs[i] = auxi.get_by_rotate(base_dir, t * span * 2)
	end
	return dirs
end

--- Mom's Eye（55）：min(100, luck*10+50)% 向后额外 1 发；幸运≥5 必出。
function M.moms_eye_chance(luck)
	luck = tonumber(luck) or 0
	return math.min(1, math.max(0, luck * 0.1 + 0.5))
end

--- Loki's Horns（87）：min(100, luck*5+25)% 另三正方向；幸运≤-5 为 0，≥15 必出。
function M.lokis_horns_chance(luck)
	luck = tonumber(luck) or 0
	return math.min(1, math.max(0, luck * 0.05 + 0.25))
end

--- 主弹道 + 套装额外弹道（Conjoined ±45°；Bookworm 25% 再 +1）
--- + Mom's Eye / Loki's Horns（按配方 counts 与档案 luck）
--- opts: {count=, roll_bookworm=, rng=, seed=}
function M.volley_dirs(base_dir, profile, opts)
	opts = opts or {}
	local count = opts.count
	if count == nil then
		count = (profile and profile.multishot and profile.multishot.count) or 1
	end
	local dirs = M.multishot_dirs(base_dir, count)
	local roll_opts = {
		roll_bookworm = opts.roll_bookworm == true,
		rng = opts.rng,
	}
	if roll_opts.roll_bookworm and not roll_opts.rng and opts.seed then
		roll_opts.rng = M.derived_rng(opts.seed, 91001)
	end
	for _, d in ipairs(M.form_extra_shot_dirs(base_dir, profile, roll_opts)) do
		dirs[#dirs + 1] = d
	end
	local counts = profile and profile.counts or {}
	local luck = opts.luck
	if luck == nil then
		luck = profile and profile.stats and profile.stats.luck or 0
	end
	luck = tonumber(luck) or 0
	local base_seed = opts.seed
	local function roll_with_salt(p, salt)
		if p <= 0 then return false end
		if p >= 1 then return true end
		local rng = opts.rng
		if not rng and base_seed then
			rng = M.derived_rng(base_seed, salt)
		end
		if rng and rng.RandomFloat then
			return rng:RandomFloat() < p
		end
		return math.random() < p
	end
	local aim = base_dir
	if not aim or aim:Length() < 0.01 then
		aim = Vector(10, 0)
	end
	local len = aim:Length()
	local aim_n = aim:Normalized()
	-- 妈妈的眼睛：向后 1 发（独立 RNG，不与洛基角抢同一流）
	-- 幸运 0 → 50%；幸运≥5 → 100%。不是接近 0。
	if M.count_of(counts, 55) > 0 and roll_with_salt(M.moms_eye_chance(luck), 55087) then
		dirs[#dirs + 1] = aim_n * (-len)
	end
	-- 洛基的角：其余三个正方向（相对当前射击方向四向对齐）
	-- 幸运 0 → 25%；幸运≥15 → 100%。
	-- 注意：用 get_by_rotate 相对瞄准，避免 MakeVector 与引擎角约定不一致时「四向看起来没变」。
	if M.count_of(counts, 87) > 0 and roll_with_salt(M.lokis_horns_chance(luck), 55097) then
		for _, add in ipairs({90, 180, 270}) do
			dirs[#dirs + 1] = auxi.get_by_rotate(aim, add, len)
		end
	end
	-- 眼瘤（558）：每份 1/3 出 1 发任意方向（对齐 attack_list_calculator 无 RGON 回退）。
	-- 禁止走玩家 GetMultiShotParams：那是持有者库存，不是配方。
	local eye_n = math.max(0, math.floor(M.count_of(counts, 558)))
	if eye_n > 0 then
		for copy = 1, eye_n do
			local rng = opts.rng
			if not rng and base_seed then
				rng = M.derived_rng(base_seed, 55800 + copy)
			end
			local proc = false
			local ang = nil
			if rng and rng.RandomFloat then
				proc = rng:RandomFloat() < (1 / 3)
				if proc then ang = rng:RandomFloat() * 360 end
			else
				proc = math.random() < (1 / 3)
				if proc then ang = math.random() * 360 end
			end
			if proc then
				dirs[#dirs + 1] = auxi.get_by_rotate(aim, ang or 0, len)
			end
		end
	end
	return dirs
end

--- ctx = {player=, rec=, air=, runtime=}；无 ctx 时仅静态配方（审计/预览）
function M.build_profile(ingredients, ctx)
	local counts = M.counts_from_ingredients(ingredients)
	local audit_fb = ctx and ctx.rec and ctx.rec.audit == true
	local source_counts = M.source_counts_from_ingredients(ingredients, audit_fb)
	-- 392 十二宫：虚拟叠加本层星座（不改 source_counts / 材料清单）
	local zodiac_effect = nil
	do
		local ok, Zodiac = pcall(require, "Qing_Remaster_scripts.others.craft_zodiac")
		if ok and Zodiac and Zodiac.apply_to_counts then
			zodiac_effect = Zodiac.apply_to_counts(counts, ctx)
		end
	end
	local list = M.list_from_counts(counts)
	local weapon, morph_items, extras, compat_consumed, unsupported_morphs = M.resolve_weapon(list, counts)
	extras.paschal_candle_visual = (counts[567] or 0) > 0
	extras.crown_of_light_visual = (counts[415] or 0) > 0
	extras.dark_princes_crown_visual = (counts[442] or 0) > 0
	local synergy = M.build_synergy(weapon, list, extras)
	local multishot = M.build_multishot(counts)
	local stats = M.stats_from_counts(counts)
	local body_scale_mul = M.body_scale_from_counts(counts)
	local dyn_tags = {}
	local runtime = {}

	local Dyn = require("Qing_Remaster_scripts.others.craft_dynamic_stats")
	if Dyn and Dyn.apply_to_stats then
		local dyn = Dyn.apply_to_stats(stats, {
			player = ctx and ctx.player,
			rec = ctx and ctx.rec,
			air = ctx and ctx.air,
			counts = counts,
			runtime = ctx and ctx.runtime,
		})
		if dyn then
			body_scale_mul = body_scale_mul * (dyn.body_scale_mul or 1)
			dyn_tags = dyn.tags or dyn_tags
			runtime = dyn.runtime or runtime
			if dyn.extras then
				for k, v in pairs(dyn.extras) do
					extras[k] = v
				end
			end
			if dyn.flag_extra and stats then
				-- flag OR 由调用方合并；此处挂到 profile
			end
			if dyn.flag_extra then
				runtime.flag_extra = dyn.flag_extra
			end
		end
	end

	-- 主武器射速倍率写入数值（审计行与开火共用）
	local wmul = M.weapon_fire_delay_mul(weapon)
	stats.firedelay_base = stats.firedelay
	stats.weapon_delay_mul = wmul
	-- 动态 fire_rate 倍率（溢泪/眼药水等）在武器倍率之后再折算
	local fr_mul = tonumber(stats.fire_rate_mul) or 1
	if fr_mul ~= 1 and fr_mul > 0 then
		local fr = 30 / (math.max(1, stats.firedelay) + 1)
		fr = fr * fr_mul
		stats.firedelay = math.max(1, 30 / fr - 1)
	end
	stats.firedelay = math.max(1, stats.firedelay * wmul)
	-- 血泪覆盖硫磺/博士：Wiki 在血泪 tears down 后再加固定 delay（不再叠武器倍率）
	if extras.haemo_override and extras.haemo_guests then
		local has_brim, has_dr = false, false
		for _, g in ipairs(extras.haemo_guests) do
			if g == 2 then has_brim = true end
			if g == 5 then has_dr = true end
		end
		if has_brim then
			stats.firedelay = stats.firedelay + 20
		elseif has_dr then
			stats.firedelay = stats.firedelay + 10
		end
	end
	stats.fire_rate_mul = 1
	body_scale_mul = math.max(0.25, math.min(3, body_scale_mul))

	local flag_mask = M.mask_from_counts(counts)
	local bomb_flag_mask, bomb_variant = M.bomb_effects_from_counts(counts, 0)
	if runtime.flag_extra then
		flag_mask = flag_mask | runtime.flag_extra
	end
	-- 血泪：不写 TEAR_BURSTSPLIT（原版 flag 会读玩家背包生成硫磺/炸弹等）；改自模拟。
	if extras.haemolacria and TearFlags and TearFlags.TEAR_BURSTSPLIT then
		flag_mask = flag_mask & ~TearFlags.TEAR_BURSTSPLIT
	end
	-- 玄秘：仅泪弹系主武保留 TEAR_OCCULT；其余只吃属性
	local occult_tear_weap = {
		[1] = true, [7] = true, [8] = true, [10] = true, [14] = true,
	}
	if (counts[572] or 0) > 0 and TearFlags and TearFlags.TEAR_OCCULT and not occult_tear_weap[weapon] then
		flag_mask = flag_mask & ~TearFlags.TEAR_OCCULT
		runtime.occult_stats_only = true
	end

	local forms = M.resolve_player_forms(
		ctx and ctx.player,
		counts,
		(ctx and ctx.air) and "air_bind" or ((ctx and ctx.commit_state) and "confirm" or "preview")
	)
	M.apply_player_form_stats(stats, forms)
	if forms.guppy and TearFlags and TearFlags.TEAR_MULLIGAN then
		flag_mask = flag_mask | TearFlags.TEAR_MULLIGAN
	end
	if M.enable_form_log then
		form_log_write({
			e = "profile_stats",
			src = (ctx and ctx.air) and "air_bind" or "preview",
			dmg = stats and stats.damage,
			spd = stats and stats.speed,
			forms = {
				bookworm = forms.bookworm and true or false,
				spun = forms.spun and true or false,
				guppy = forms.guppy and true or false,
				conjoined = forms.conjoined and true or false,
			},
			player = (ctx and ctx.player) and true or false,
		})
	end

	local rec = ctx and ctx.rec
	local commit_state = ctx and (ctx.commit_state == true or ctx.air ~= nil)
	-- 谷底石头允许在制造预览阶段就计入峰值；其它持续状态仍只服从 commit_state。
	local commit_rock_bottom = commit_state or (ctx and ctx.commit_rock_bottom == true)
	-- 562 移除时清峰值；保留 562 时：底层算完 → 更新峰值并覆写 → Libra
	if (counts[562] or 0) <= 0 then
		if commit_rock_bottom and rec then rec.rock_bottom_max = nil end
	elseif Dyn and Dyn.apply_rock_bottom and rec then
		if commit_rock_bottom then
			Dyn.apply_rock_bottom(stats, rec)
		elseif rec.rock_bottom_max then
			-- 预览：只读应用已有峰值，不更新
			local maxv = rec.rock_bottom_max
			if type(maxv) == "table" then
				if maxv.damage ~= nil then stats.damage = maxv.damage end
				if maxv.speed ~= nil then stats.speed = maxv.speed end
				if maxv.range ~= nil then stats.range = maxv.range end
				if maxv.shotspeed ~= nil then stats.shotspeed = maxv.shotspeed end
				if maxv.luck ~= nil then stats.luck = maxv.luck end
				if maxv.fire_rate ~= nil then
					stats.firedelay = math.max(1, 30 / math.max(0.1, maxv.fire_rate) - 1)
				end
			end
		end
	end
	if (counts[304] or 0) > 0 and Dyn and Dyn.apply_libra then
		Dyn.apply_libra(stats, ctx and ctx.player)
	end

	if zodiac_effect then
		runtime.zodiac_effect = zodiac_effect
		extras.zodiac = true
		extras.zodiac_effect = zodiac_effect
	elseif (counts[392] or 0) > 0 then
		extras.zodiac = true
	end

	M.apply_base_quality_to_stats(stats, M.resolve_base_quality(ctx))

	return {
		weapon = weapon,
		morph_items = morph_items,
		counts = counts,
		source_counts = source_counts,
		list = list,
		extras = extras,
		synergy = synergy,
		multishot = multishot,
		compat_consumed = compat_consumed or {},
		unsupported_morphs = unsupported_morphs or {},
		flag_mask = flag_mask,
		bomb_flag_mask = bomb_flag_mask,
		bomb_variant = bomb_variant,
		stats = stats,
		body_scale_mul = body_scale_mul,
		dyn_tags = dyn_tags,
		runtime = runtime,
		forms = forms,
		source_ingredients = ingredients,
	}
end

--- 纯逻辑自检（不依赖 Isaac API）：§14.3 样例 + BRANCH_COMPAT 成对消费
function M.verify_weapon_vote_examples()
	local function counts_from_ids(ids)
		local c = {}
		for _, id in ipairs(ids) do c[id] = (c[id] or 0) + 1 end
		return c
	end
	local cases = {
		{name = "Epic+Knife+Brim", ids = {168, 114, 118}, expect = 6},
		{name = "CSec+Knife+Tech", ids = {678, 114, 68}, expect = 14},
		{name = "Sword+Knife+Tech", ids = {579, 114, 68}, expect = 13},
		{name = "Knife+Brim+TechX+Lung", ids = {114, 118, 395, 229}, expect = 4},
		{name = "Dr+Lung", ids = {52, 229}, expect = 7},
		{name = "exact Brim+CSec", ids = {118, 678}, expect = 2},
		{name = "exact Brim+TechX", ids = {118, 395}, expect = 9},
		{name = "exact Brim+TechX stacked", ids = {118, 118, 395}, expect = 9},
		{name = "Brim+CSec+Knife", ids = {118, 678, 114}, expect = 14}, -- CSec 可消费两者
		-- §14.7.1–9 两件表决
		{name = "Knife+Tech", ids = {114, 68}, expect = 4},
		{name = "Brim+Dr", ids = {118, 52}, expect = 5},
		{name = "Brim+Sword", ids = {118, 579}, expect = 2},
		{name = "TechX+Tech", ids = {395, 68}, expect = 9},
		{name = "TechX+Dr", ids = {395, 52}, expect = 5},
		{name = "Tech+Dr", ids = {68, 52}, expect = 5},
		{name = "Epic+Dr", ids = {168, 52}, expect = 6},
		{name = "Epic+Sword", ids = {168, 579}, expect = 6},
		{name = "Dr+Sword", ids = {52, 579}, expect = 5},
		-- Ludovico 改形 / 仍被覆盖
		{name = "Ludo alone", ids = {329}, expect = 8},
		{name = "Ludo+Brim", ids = {329, 118}, expect = 8},
		{name = "Ludo+Tech", ids = {329, 68}, expect = 8},
		{name = "Ludo+TechX", ids = {329, 395}, expect = 8},
		{name = "Ludo+Knife", ids = {329, 114}, expect = 8},
		{name = "Ludo+Epic", ids = {329, 168}, expect = 6},
		{name = "Ludo+CSec", ids = {329, 678}, expect = 14},
		{name = "Ludo+Sword", ids = {329, 579}, expect = 13},
		-- §15.4 血泪覆盖可覆盖主武 → 眼泪（含妈刀）；卢多/剖腹产保留主武
		{name = "Hae+Brim", ids = {531, 118}, expect = 1},
		{name = "Hae+Tech", ids = {531, 68}, expect = 1},
		{name = "Hae+TechX", ids = {531, 395}, expect = 1},
		{name = "Hae+Dr", ids = {531, 52}, expect = 1},
		{name = "Hae+Knife", ids = {531, 114}, expect = 1},
		{name = "Hae+Brim+TechX", ids = {531, 118, 395}, expect = 1},
		{name = "Hae+Ludo", ids = {531, 329}, expect = 8},
		{name = "Hae+CSec", ids = {531, 678}, expect = 14},
		-- 肺/史诗仍优先于血泪
		{name = "Hae+Lung", ids = {531, 229}, expect = 7},
		{name = "Hae+Epic", ids = {531, 168}, expect = 6},
	}
	local report = {}
	local ok_all = true
	for _, case in ipairs(cases) do
		local counts = counts_from_ids(case.ids)
		local list = M.list_from_counts(counts)
		local w = M.resolve_weapon(list, counts)
		local pass = w == case.expect
		if not pass then ok_all = false end
		report[#report + 1] = {
			name = case.name, expect = case.expect, got = w, pass = pass,
		}
	end
	-- pair：两件配方必须选到能消费另一件的分支
	for host, can in pairs(M.BRANCH_COMPAT) do
		for guest in pairs(can) do
			local host_id, guest_id
			for _, m in ipairs(M.MORPH) do
				if m.weapon == host then host_id = m.id end
				if m.weapon == guest then guest_id = m.id end
			end
			if host_id and guest_id then
				local counts = counts_from_ids({host_id, guest_id})
				local list = M.list_from_counts(counts)
				local w, _, _, consumed = M.resolve_weapon(list, counts)
				local consumes = false
				for _, cw in ipairs(consumed or {}) do
					if cw == guest or cw == host then consumes = true end
				end
				-- 胜者必须是二者之一，且胜者 BRANCH_COMPAT 含另一者
				local other = (w == host) and guest or host
				local good = (w == host or w == guest)
					and M.BRANCH_COMPAT[w] and M.BRANCH_COMPAT[w][other]
				if not good then ok_all = false end
				report[#report + 1] = {
					name = "pair "..tostring(host).."+"..tostring(guest),
					expect = "either consumes",
					got = w,
					pass = good == true,
				}
			end
		end
	end
	return ok_all, report
end

--- 整表写入 TearFlags。激光优先 Clear+Add，避免 Fire* 继承玩家位后赋值粘滞。
local function copy_charge_domain(domain)
	domain = domain or {}
	local intervals = {}
	for _, iv in ipairs(domain.intervals or {}) do
		local a, b = tonumber(iv[1]), tonumber(iv[2])
		if a and b then
			if a > b then a, b = b, a end
			intervals[#intervals + 1] = { a, b }
		end
	end
	local points = {}
	for _, p in ipairs(domain.points or {}) do
		p = tonumber(p)
		if p then points[#points + 1] = p end
	end
	return { intervals = intervals, points = points }
end

local function merge_charge_intervals(intervals)
	if #intervals <= 0 then return {} end
	table.sort(intervals, function(a, b)
		if a[1] ~= b[1] then return a[1] < b[1] end
		return a[2] < b[2]
	end)
	local out = { { intervals[1][1], intervals[1][2] } }
	for i = 2, #intervals do
		local cur = intervals[i]
		local last = out[#out]
		if cur[1] <= last[2] + 1e-9 then
			if cur[2] > last[2] then last[2] = cur[2] end
		else
			out[#out + 1] = { cur[1], cur[2] }
		end
	end
	return out
end

local function charge_point_in_intervals(p, intervals)
	for _, iv in ipairs(intervals) do
		if p >= iv[1] - 1e-9 and p <= iv[2] + 1e-9 then
			return true
		end
	end
	return false
end

function M.normalize_charge_domain(domain)
	local d = copy_charge_domain(domain)
	d.intervals = merge_charge_intervals(d.intervals)
	local pts = {}
	local seen = {}
	for _, p in ipairs(d.points) do
		local key = string.format("%.6f", p)
		if not seen[key] and not charge_point_in_intervals(p, d.intervals) then
			seen[key] = true
			pts[#pts + 1] = p
		end
	end
	table.sort(pts)
	d.points = pts
	return d
end

function M.union_charge_domains(domains)
	local intervals = {}
	local points = {}
	for _, dom in ipairs(domains or {}) do
		local d = copy_charge_domain(dom)
		for _, iv in ipairs(d.intervals) do
			intervals[#intervals + 1] = iv
		end
		for _, p in ipairs(d.points) do
			points[#points + 1] = p
		end
	end
	return M.normalize_charge_domain({ intervals = intervals, points = points })
end

function M.charge_domain_bounds(domain)
	domain = M.normalize_charge_domain(domain)
	local min_r, max_r = nil, nil
	for _, iv in ipairs(domain.intervals) do
		if min_r == nil or iv[1] < min_r then min_r = iv[1] end
		if max_r == nil or iv[2] > max_r then max_r = iv[2] end
	end
	for _, p in ipairs(domain.points) do
		if min_r == nil or p < min_r then min_r = p end
		if max_r == nil or p > max_r then max_r = p end
	end
	return min_r or 0.25, max_r or 1
end

--- raw 投影到 domain：落在区间内保持；否则吸附最近边界/点（等距取较高值）。
function M.project_charge_to_domain(raw, domain)
	domain = M.normalize_charge_domain(domain)
	raw = tonumber(raw)
	if raw == nil then
		if domain.intervals[1] then return domain.intervals[1][1] end
		if domain.points[1] then return domain.points[1] end
		return 1
	end
	for _, iv in ipairs(domain.intervals) do
		if raw >= iv[1] - 1e-9 and raw <= iv[2] + 1e-9 then
			if raw < iv[1] then return iv[1] end
			if raw > iv[2] then return iv[2] end
			return raw
		end
	end
	local best, best_dist = nil, nil
	local function consider(v)
		local dist = math.abs(raw - v)
		if best == nil
			or dist < best_dist - 1e-12
			or (math.abs(dist - best_dist) <= 1e-12 and v > best)
		then
			best = v
			best_dist = dist
		end
	end
	for _, iv in ipairs(domain.intervals) do
		consider(iv[1])
		consider(iv[2])
	end
	for _, p in ipairs(domain.points) do
		consider(p)
	end
	return best or raw
end

function M.get_mechanism_charge_domain(mechanism)
	local rule = M.CHARGE_RULES[mechanism]
	if not rule then return nil end
	return M.normalize_charge_domain(rule.domain)
end

function M.get_active_charge_rules(profile)
	local out = {}
	local ex = profile and profile.extras or {}
	local wpn = (profile and profile.weapon) or 1
	if ex.chocolate then
		out[#out + 1] = { id = "chocolate", rule = M.CHARGE_RULES.chocolate }
	end
	if wpn == 9 then
		out[#out + 1] = { id = "techx", rule = M.CHARGE_RULES.techx }
	end
	if wpn == 4 then
		out[#out + 1] = { id = "knife", rule = M.CHARGE_RULES.knife }
	end
	if ex.cursed_eye then
		out[#out + 1] = { id = "cursed_eye", rule = M.CHARGE_RULES.cursed_eye }
	end
	return out
end

function M.get_union_charge_domain(profile)
	local active = M.get_active_charge_rules(profile)
	if #active <= 0 then
		return M.normalize_charge_domain({ intervals = { { 0.25, 1.0 } } })
	end
	local domains = {}
	for _, row in ipairs(active) do
		domains[#domains + 1] = row.rule.domain
	end
	return M.union_charge_domains(domains)
end

--- 共享滑条外包络（仅用于鼠标线性映射；最终值仍要 project 到并集）。
function M.get_charge_slider_range(profile)
	return M.charge_domain_bounds(M.get_union_charge_domain(profile))
end

function M.charge_ratio_min(profile)
	local min_r = M.get_charge_slider_range(profile)
	return min_r
end

function M.charge_ratio_max(profile)
	local _, max_r = M.get_charge_slider_range(profile)
	return max_r
end

--- UI / 存档：投影到 active domains 的并集。
function M.canonicalize_main_charge(profile, raw)
	return M.project_charge_to_domain(raw, M.get_union_charge_domain(profile))
end

--- 各机制：把共享 main_charge_ratio 投影到自己的 domain。
function M.resolve_charge_for_mechanism(_profile, mechanism, main_ratio)
	local domain = M.get_mechanism_charge_domain(mechanism)
	if not domain then return nil end
	return M.project_charge_to_domain(main_ratio, domain)
end

--- 视觉槽 0..1 → 外包络线性插值，再投影到并集。
function M.ratio_from_slider_x(x, profile)
	x = tonumber(x) or 0
	if x < 0 then x = 0 elseif x > 1 then x = 1 end
	local domain = M.get_union_charge_domain(profile)
	local min_r, max_r = M.charge_domain_bounds(domain)
	local raw = min_r + x * (max_r - min_r)
	return M.project_charge_to_domain(raw, domain)
end

--- 滑条视觉进度 0..1：相对并集外包络。
function M.slider_progress(r, profile)
	local domain = M.get_union_charge_domain(profile)
	r = M.project_charge_to_domain(r, domain)
	local min_r, max_r = M.charge_domain_bounds(domain)
	if max_r <= min_r then return 0 end
	return math.max(0, math.min(1, (r - min_r) / (max_r - min_r)))
end

--- 合法 cursed_ratio → 额外重放次数（0–4）。派生产物，不是存档权威。
function M.cursed_extra_shots_from_charge(ratio)
	local r = M.resolve_charge_for_mechanism(nil, "cursed_eye", ratio) or 1
	return math.max(0, math.min(4, math.floor((r - 1) / 0.5 + 0.0001)))
end

function M.cursed_shot_count_from_charge(ratio)
	return M.cursed_extra_shots_from_charge(ratio) + 1
end

--- Rep+ 巧克力：200%=完整蓄力；伤害按蓄力帧连续增长，最高 400%。
function M.chocolate_modifiers(ratio, base_delay)
	local r = M.resolve_charge_for_mechanism(nil, "chocolate", ratio) or 1
	base_delay = math.max(-0.75, tonumber(base_delay) or 10)
	local tears = 30 / (base_delay + 1)
	if tears >= 30 then
		local damage_mul = tears / 75 * 4
		return {
			ratio = r, damage_mul = damage_mul, size_mul = damage_mul ^ 0.5,
			charge_frames = 2, delay_override = 1, continuous = true,
		}
	end
	local charge_frac = r / 2
	local max_frames = math.max(2, math.floor(75 / tears))
	local charge_frames = math.max(2, math.floor(max_frames * charge_frac + 0.5))
	local damage_mul = math.min(4, charge_frames * tears / 75 * 4)
	return {
		ratio = r,
		damage_mul = damage_mul,
		size_mul = damage_mul ^ 0.5,
		charge_frames = charge_frames,
		delay_override = math.max(1, charge_frames - 1),
	}
end

--- Tech X 蓄力：最低 25%；比例同时控制环尺寸、伤害与下一次攻击前的蓄力时间。
--- 半径语义：requested_radius = 60 * charge_ratio（15–60），调用侧再乘 projectile_scale。
--- damage_mul = r；Radius 不自动定伤害（见 notes/craft_techx_radius_thickness.md）。
function M.techx_charge_modifiers(ratio)
	local r = M.resolve_charge_for_mechanism(nil, "techx", ratio) or 1
	return {
		ratio = r,
		radius_mul = r,
		damage_mul = r,
		delay_mul = r,
	}
end

--- 妈刀蓄力（wiki）：蓄力时长约 4/t 秒，t 为眼泪射速 30/(tearDelay+1)。
--- 满蓄力帧 = 4*(tearDelay+1)；未蓄 200%，1/3 蓄力起 600%，再蓄只加射程。
--- tearDelay 用 firedelay_base（武器倍率之前），不要把妈刀 ×2 再乘进 4/t。
function M.knife_charge_modifiers(ratio, base_delay)
	local r = M.resolve_charge_for_mechanism(nil, "knife", ratio) or 1
	local dmg_t = math.min(1, r / (1 / 3))
	base_delay = math.max(-0.75, tonumber(base_delay) or 10)
	local full_frames = math.max(1, math.floor(4 * (base_delay + 1) + 0.5))
	return {
		ratio = r,
		damage_mul = 2 + 4 * dmg_t,
		range_mul = r,
		maxdist_mul = 0.6 * r,
		charge_frames = math.max(1, math.floor(full_frames * r + 0.5)),
	}
end

--- 把 per-craft 设置合并进 profile（巧克力 / Tech X / 妈刀 / 诅咒蓄力）
function M.apply_craft_settings(profile, settings)
	if not profile then return profile end
	settings = settings or {}
	local ex = profile.extras or {}
	local legacy = settings.chocolate_charge_ratio or settings.techx_charge_ratio
	local raw = settings.main_charge_ratio or profile.main_charge_ratio or legacy or 1
	profile.main_charge_ratio = M.canonicalize_main_charge(profile, raw)
	profile.chocolate_charge_ratio = ex.chocolate
		and M.resolve_charge_for_mechanism(profile, "chocolate", profile.main_charge_ratio)
		or nil
	if (profile.weapon or 1) == 9 then
		profile.techx_charge_ratio = M.resolve_charge_for_mechanism(profile, "techx", profile.main_charge_ratio)
	else
		profile.techx_charge_ratio = nil
	end
	if (profile.weapon or 1) == 4 then
		profile.knife_charge_ratio = M.resolve_charge_for_mechanism(profile, "knife", profile.main_charge_ratio)
	else
		profile.knife_charge_ratio = nil
	end
	return profile
end

--- 一次攻击开始时生成不可变倍率
function M.attack_modifiers_from_profile(profile)
	local mods = {
		chocolate = false,
		techx = false,
		ratio = 1,
		damage_mul = 1,
		size_mul = 1,
		delay_override = nil,
		charge_ratio = 1,
		cursed_ratio = nil,
		cursed_replays = 0,
		cursed_shots = 1,
		techx_ratio = 1,
		techx_radius_mul = 1,
		techx_damage_mul = 1,
		techx_delay_mul = 1,
		knife = false,
		knife_ratio = 1,
		knife_range_mul = 1,
		knife_damage_mul = 1,
		knife_charge_frames = nil,
	}
	if not profile then return mods end
	mods.charge_ratio = M.canonicalize_main_charge(profile, profile.main_charge_ratio)
	if profile.extras and profile.extras.cursed_eye then
		mods.cursed_ratio = M.resolve_charge_for_mechanism(profile, "cursed_eye", mods.charge_ratio)
		mods.cursed_replays = M.cursed_extra_shots_from_charge(mods.cursed_ratio)
		mods.cursed_shots = mods.cursed_replays + 1
	end
	if profile.extras and profile.extras.chocolate then
		local choco_r = M.resolve_charge_for_mechanism(profile, "chocolate", mods.charge_ratio)
		local c = M.chocolate_modifiers(choco_r, profile.stats and profile.stats.firedelay)
		mods.chocolate = true
		mods.ratio = c.ratio
		mods.damage_mul = c.damage_mul
		mods.size_mul = c.size_mul
		mods.delay_override = c.delay_override
		mods.charge_frames = c.charge_frames
	end
	if (profile.weapon or 1) == 9 then
		local tech_r = M.resolve_charge_for_mechanism(profile, "techx", mods.charge_ratio)
		local t = M.techx_charge_modifiers(tech_r)
		mods.techx = true
		mods.techx_ratio = t.ratio
		mods.techx_radius_mul = t.radius_mul
		mods.techx_damage_mul = t.damage_mul
		mods.techx_delay_mul = t.delay_mul
	end
	if (profile.weapon or 1) == 4 then
		local knife_r = M.resolve_charge_for_mechanism(profile, "knife", mods.charge_ratio)
		local k = M.knife_charge_modifiers(
			knife_r,
			profile.stats and (profile.stats.firedelay_base or profile.stats.firedelay)
		)
		mods.knife = true
		mods.knife_ratio = k.ratio
		mods.knife_range_mul = k.range_mul
		mods.knife_damage_mul = k.damage_mul
		mods.knife_charge_frames = k.charge_frames
		mods.knife_maxdist_mul = k.maxdist_mul
	end
	return mods
end

--- 各蓄力机制按自己的 ratio 算出 required delay，最终取 max（共享一次蓄力周期）。
function M.attack_delay_from_modifiers(base_delay, mods)
	base_delay = math.max(1, tonumber(base_delay) or 10)
	mods = mods or {}
	local best = nil
	local function consider(v)
		v = tonumber(v)
		if v == nil then return end
		v = math.max(1, v)
		if best == nil or v > best then best = v end
	end
	if mods.chocolate and mods.delay_override ~= nil then
		consider(mods.delay_override)
	end
	if mods.knife and mods.knife_charge_frames ~= nil then
		consider(mods.knife_charge_frames)
	end
	if mods.techx then
		consider(base_delay * (tonumber(mods.techx_delay_mul) or 1))
	end
	if mods.cursed_ratio ~= nil then
		consider(base_delay * (tonumber(mods.cursed_ratio) or 1))
	end
	if best == nil then return base_delay end
	return best
end

--- Fruit Cake 可随机的主武器（排除卢多占位 8、无开火分支 11/12）
function M.pick_fruit_cake_weapon(rng)
	local pool = M.SUPPORTED_RANDOM_WEAPONS
	local i
	if rng and rng.RandomInt then
		i = rng:RandomInt(#pool) + 1
	else
		i = math.random(#pool)
	end
	return pool[i] or 1
end

--- 统一弹道方向：多发 + 套装 + 妈眼 + 洛基角（包装 volley_dirs）
function M.build_volley_directions(profile, aim_dir, opts)
	return M.volley_dirs(aim_dir, profile, opts)
end

--- 妈眼/洛基角独立判定；供离散齐射和 Ludo epoch 共用。
function M.roll_directional_extras(profile, luck, seed)
	local counts = profile and profile.counts or {}
	luck = tonumber(luck) or 0
	local function hit(id, chance, salt)
		if M.count_of(counts, id) <= 0 or chance <= 0 then return false end
		if chance >= 1 then return true end
		return M.derived_rng(seed, salt):RandomFloat() < chance
	end
	return hit(55, M.moms_eye_chance(luck), 55087),
		hit(87, M.lokis_horns_chance(luck), 55097)
end

--- 一次攻击上下文：伤害/冷却/弹速/射程/尺寸/诅咒眼重放
--- opts: {eye_bonus=, atk_mods=, aux_mul=, dead_eye_mul=, weapon=}
function M.build_attack_context(profile, opts)
	opts = opts or {}
	local mods = opts.atk_mods or M.attack_modifiers_from_profile(profile)
	local eye = opts.eye_bonus or {damage = 0, range = 0, shotspeed = 0, damage_mul = 1, blood_variant = false}
	local aux_mul = tonumber(opts.aux_mul) or 1
	local dead_eye_mul = tonumber(opts.dead_eye_mul) or 1
	local st = (profile and profile.stats) or {}
	local base_dmg = (tonumber(st.damage) or 3.5) + (tonumber(eye.damage) or 0)
	base_dmg = base_dmg * (tonumber(eye.damage_mul) or 1)
	local damage = base_dmg * (mods.damage_mul or 1) * aux_mul * dead_eye_mul
	local weapon = opts.weapon or (profile and profile.weapon) or 1
	local base_delay = M.craft_fire_delay(profile, weapon)
	local delay = M.attack_delay_from_modifiers(base_delay, mods)
	local shotspeed = (tonumber(st.shotspeed) or 1) + (tonumber(eye.shotspeed) or 0)
	local range = (tonumber(st.range) or 260) + (tonumber(eye.range) or 0)
	return {
		profile = profile,
		mods = mods,
		eye = eye,
		aux_mul = aux_mul,
		dead_eye_mul = dead_eye_mul,
		weapon = weapon,
		damage = damage,
		base_damage = base_dmg,
		delay = delay,
		shotspeed = shotspeed,
		range = range,
		scale = M.projectile_scale(profile, mods),
		luck = tonumber(st.luck) or 0,
		cursed_replays = tonumber(mods.cursed_replays) or 0,
		blood_variant = eye.blood_variant == true,
	}
end

--- 硫磺 synergy 伤害倍率（相对已 stamp 的 CollisionDamage；不回写基础伤）
function M.brimstone_synergy_mul(profile)
	local syn = profile and profile.synergy
	if not syn then return 1 end
	if syn.brim_tech then
		return 1.5 * (syn.thick_brim and 1.5 or 1)
	end
	if syn.thick_brim then return 1.5 end
	return 1
end

--- 按配方 synergy 选硫磺激光 Variant（禁止沿用玩家 FireBrimstone 的 Brim+Tech 等外观）。
--- 单份→THICK_RED；双份→THICKER_RED；+科技→BRIM_TECH / THICKER_BRIM_TECH。
function M.profile_has_haemolacria(profile)
	if not profile then return false end
	if profile.extras and profile.extras.haemolacria then return true end
	return profile.list and (profile.list.hae or 0) > 0
end

function M.haemo_burst_mode(profile)
	if not profile then return "tears" end
	local syn = profile.synergy or {}
	local ex = profile.extras or {}
	local mode = syn.haemo_burst_mode or ex.haemo_burst_mode or "tears"
	-- 旧档案 mixed / 多 guest：落地一次 shared，不再拆成多发主气球
	if mode == "mixed" or mode == "multi" then
		return "shared"
	end
	return mode
end

--- 妈刀是否已作为血泪均分 guest（不再在 tears/brim burst 里二次分摊刀）
function M.haemo_knife_is_share_guest(profile)
	if not profile then return false end
	local syn = profile.synergy or {}
	local ex = profile.extras or {}
	local guests = syn.haemo_share_guests or ex.haemo_share_guests or {}
	for _, g in ipairs(guests) do
		if g == 4 then return true end
	end
	return false
end

--- 掷某一 mode 的自然产量（自身倍率区间）
function M.haemo_roll_mode_count(mode)
	local r = M.HAEMO_MODE_BASE_COUNT[mode or "tears"] or M.HAEMO_MODE_BASE_COUNT.tears
	local lo, hi = r[1] or 6, r[2] or 11
	if hi < lo then lo, hi = hi, lo end
	return math.random(lo, hi)
end

--- 多 mode 并存：面额均分 × 总加成 → 该 mode 实际发数
--- count = max(1, round(base * (1+0.2*(n-1)) / n))
function M.haemo_scale_mode_count(base_count, n_modes)
	base_count = math.max(1, math.floor(tonumber(base_count) or 1))
	n_modes = math.max(1, math.floor(tonumber(n_modes) or 1))
	if n_modes <= 1 then return base_count end
	local mul = 1 + (tonumber(M.HAEMO_SHARE_BONUS) or 0.2) * (n_modes - 1)
	return math.max(1, math.floor(base_count * mul / n_modes + 0.5))
end

--- 侧车爆发（卢多等）可参与的 mode 列表：配方里出现的可分摊 guest；皆无则 tears
function M.haemo_burst_guest_modes(profile)
	local list = profile and profile.list or {}
	local modes = {}
	local function add(cond, mode)
		if cond and mode then modes[#modes + 1] = mode end
	end
	add((list.brimstone or 0) > 0, "brim")
	add((list.tech or 0) > 0, "tech")
	add((list.techX or 0) > 0, "techx")
	add((list.dr or 0) > 0, "bombs")
	add((list.knife or 0) > 0, "knife")
	if #modes == 0 then
		modes[1] = "tears"
	end
	return modes
end

--- 给制造主血泪挂上自模拟 burst 标记（禁止依赖 TEAR_BURSTSPLIT）
function M.sample_tear_flags(player, luck, profile, weapon_type, opts)
	opts = opts or {}
	if opts.craft_uid == nil and profile and profile.craft_uid then
		opts.craft_uid = profile.craft_uid
	end
	if opts.seed == nil and player and player.InitSeed then
		opts.seed = M.tear_flag_base_seed({
			shot_serial = opts.shot_serial,
			craft_uid = opts.craft_uid,
			projectile_index = opts.projectile_index,
			init_seed = opts.init_seed or (player.InitSeed % 1000003),
		})
	end
	return M.roll_tear_flags(luck, profile, opts)
end

--- opts: {damage_add=, damage_mul=} 单眼等额外伤

end

return Mod

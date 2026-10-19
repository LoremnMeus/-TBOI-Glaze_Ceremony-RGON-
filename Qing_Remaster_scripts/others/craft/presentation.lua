-- Craft presentation: labels, EID, audit, model/name generation.
-- Structural extract from craft_combat_profile.lua. No combat semantic changes.
local Mod = {}

function Mod.attach(M)

function M.craft_revive_fx_label(key, rec, zh)
	local src = M.CRAFT_REVIVE_BY_KEY[key]
	local base = M.EXTRA_NAME[key]
	local name = base and (zh and base.zh or base.en) or key
	if not src or not rec then return name end
	if src.chance then return name end
	local uses = tonumber(src.uses) or 0
	if uses <= 0 then return name end
	local used = M.craft_revive_source_spent(rec, key)
	if used >= uses then
		return zh and (name .. "(已用尽)") or (name .. "(spent)")
	end
	if used > 0 then
		local left = uses - used
		return zh and (name .. "(剩" .. tostring(left) .. ")") or (name .. "(left" .. tostring(left) .. ")")
	end
	return name
end

-- 审计「缺数值」明确排除（非可移植战斗加算 / 行为待办）
function M.audit_item_is_valid(id, player)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	if M.is_inherited_player_effect and M.is_inherited_player_effect(id) then
		return false
	end
	if M.is_craft_excluded and M.is_craft_excluded(id) then
		return false
	end
	if M.has_impl(id) then return true end
	if M.form_synergy_for_collectible(id, player) then return true end
	return false
end

function M.collectible_audit_tag_set(id, player)
	id = tonumber(id)
	local set = {}
	if not id or id <= 0 then return set end
	local is_valid = M.audit_item_is_valid(id, player)
	if is_valid then
		set.valid = true
	else
		set.invalid = true
	end
	if M.missing_stat_delta(id) then
		set.unimplemented = true
	end
	local is_morph = false
	for _, m in ipairs(M.MORPH) do
		if m.id == id then is_morph = true break end
	end
	if is_morph or M.FETUS_SEC_FLAGS[id] then set.weapon = true end
	if M.is_stat_item(id) or M.STAT_DELTA[id] or M.ONE_EYE[id] then set.stat = true end
	if M.TEAR_FLAG_MASK[id] or M.FLAG_NAME[id] then set.tear = true end
	if M.BOMB_EFFECTS[id] then set.bomb = true end
	local ek = M.EXTRA_IMPL[id]
	if ek then
		if M.CRAFT_FAMILIAR_EXTRAS_KEY_SET[ek] then
			set.familiar = true
			if M.CRAFT_FAMILIAR_ALSO_FX[ek] then set.extra = true end
		elseif M.CRAFT_ORBITAL_EXTRAS_KEY_SET[ek] then
			set.orbital = true
		else
			set.extra = true
		end
	end
	if M.form_synergy_for_collectible(id, player) then set.form = true end
	return set
end

--- 状态组与类别组各自 OR，组间 AND；两组都全关则空目录。
--- 无任何类别标签的道具（典型「无效」未接线项）：仅在「类别全开」或「类别全关」时通过类别侧，
--- 避免类别默认全开时把它们全部滤掉。
function M.collectible_matches_audit_tags(id, enabled_map, player)
	enabled_map = enabled_map or {}
	local status_on, cat_on = false, false
	local cat_total, cat_enabled_n = 0, 0
	for _, def in ipairs(M.AUDIT_FILTER_TAG_DEFS) do
		if def.group == "status" then
			if enabled_map[def.key] == true then status_on = true end
		else
			cat_total = cat_total + 1
			if enabled_map[def.key] == true then
				cat_on = true
				cat_enabled_n = cat_enabled_n + 1
			end
		end
	end
	if not status_on and not cat_on then return false end
	local set = M.collectible_audit_tag_set(id, player)
	local status_ok = not status_on
	local cat_hit = false
	local has_category = false
	for _, def in ipairs(M.AUDIT_FILTER_TAG_DEFS) do
		if def.group ~= "status" and set[def.key] then
			has_category = true
		end
		if enabled_map[def.key] == true and set[def.key] then
			if def.group == "status" then
				status_ok = true
			else
				cat_hit = true
			end
		end
	end
	local all_cats_on = cat_total > 0 and cat_enabled_n >= cat_total
	local cat_ok = (not cat_on) or cat_hit or ((not has_category) and all_cats_on)
	return status_ok and cat_ok
end

--- 材料槽条目：number 或 {id/collectible=, source=, prototype_uid=}
--- source: "real" | "audit" | "prototype" | "mirror"
function M.effect_labels(counts, zh)
	local labels = {}
	local seen = {}
	local function push(name)
		if not name or seen[name] then return end
		seen[name] = true
		labels[#labels + 1] = name
	end
	for id, n in pairs(counts or {}) do
		if n and n > 0 then
			id = tonumber(id) or id
			local info = M.FLAG_NAME[id]
			if info then push(zh and info.zh or info.en) end
			local bn = M.BOMB_NAME and M.BOMB_NAME[id]
			if bn then push(zh and bn.zh or bn.en) end
			-- 无正式短名时不输出带 ID 的占位符（面板也不冒充已完成）
			local oe = M.ONE_EYE[id]
			if oe then push(zh and oe.zh or oe.en) end
			local ek = M.EXTRA_IMPL[id]
			-- 单眼已用 ONE_EYE 标签；多发/主武器 morph 另有行；纯宝宝走「宝宝」行；环绕物走「环绕物」行
			-- also_fx 宝宝（如牛奶）仍可在特效行显示 EXTRA_NAME
			if ek and M.EXTRA_NAME[ek] and not oe
				and ek ~= "multishot" and ek ~= "fetus" and ek ~= "lung"
				and (not M.CRAFT_FAMILIAR_EXTRAS_KEY_SET[ek] or M.CRAFT_FAMILIAR_ALSO_FX[ek])
				and not M.CRAFT_ORBITAL_EXTRAS_KEY_SET[ek]
			then
				-- 妈妈的假发 + 虫群之心 → 合并为「妈妈的假发+」；虫群之心本身不再单列
				if ek == "moms_wig" then
					if (counts[248] or 0) > 0 then
						push(zh and "妈妈的假发+" or "Mom's Wig+")
					else
						local en = M.EXTRA_NAME[ek]
						push(zh and en.zh or en.en)
					end
				elseif ek == "hive_mind" then
					-- 有假发时已并入「妈妈的假发+」
					if (counts[217] or 0) <= 0 then
						local en = M.EXTRA_NAME[ek]
						push(zh and en.zh or en.en)
					end
				else
					local en = M.EXTRA_NAME[ek]
					push(zh and en.zh or en.en)
				end
			end
		end
	end
	table.sort(labels)
	return labels
end

--- 套装特效栏短名。
--- Conjoined / Bookworm / Spun：看 profile.forms。
--- Guppy：玩家是猫套但无超级猫套 →「猫套」；forms.guppy（超级猫套）→ 只显示「超级猫套」。
function M.form_effect_labels(forms, zh, player)
	local labels = {}
	forms = forms or {}
	if forms.conjoined then
		labels[#labels + 1] = zh and "宝宝套" or "Conjoined"
	end
	if forms.guppy then
		labels[#labels + 1] = zh and "超级猫套" or "Super Guppy"
	elseif player and M.player_has_form
		and M.player_has_form(player, PlayerForm.PLAYERFORM_GUPPY)
	then
		labels[#labels + 1] = zh and "猫套" or "Guppy"
	end
	if forms.bookworm then
		labels[#labels + 1] = zh and "书套" or "Bookworm"
	end
	if forms.spun then
		labels[#labels + 1] = zh and "针套" or "Spun"
	end
	return labels
end

--- 审计 / 展示共用：能解析出名字即可，EXTRA_NAME 不是 familiar 硬来源。
function M.compat_display_name(id, key, zh)
	if type(key) == "string" and key ~= "" then
		local extra = M.EXTRA_NAME[key]
		if extra then
			local name = zh and extra.zh or extra.en
			if name and name ~= "" then return name end
		end
		for _, row in ipairs(M.CRAFT_FAMILIAR_EXTRAS or {}) do
			if row.key == key then
				local name = zh and row.zh or row.en
				if name and name ~= "" then return name end
			end
		end
		for _, row in ipairs(M.CRAFT_ORBITAL_EXTRAS or {}) do
			if row.key == key then
				local name = zh and row.zh or row.en
				if name and name ~= "" then return name end
			end
		end
	end
	local def = M.COMPAT_REGISTRY and M.COMPAT_REGISTRY[tonumber(id) or id]
	if def then
		local name = zh and def.zh or def.en
		if name and name ~= "" then return name end
	end
	id = tonumber(id)
	if id and id > 0 and Isaac and Isaac.GetItemConfig then
		local cfg = Isaac.GetItemConfig():GetCollectible(id)
		if cfg and cfg.Name and cfg.Name ~= "" then
			return cfg.Name
		end
	end
	return nil
end

-- CRAFT_FAMILIAR_EXTRAS 键集合（避免特效行重复纯宝宝名）
function M.compatibility_audit()
	local issues = {}
	local familiar_keys = {}
	for _, row in ipairs(M.CRAFT_FAMILIAR_EXTRAS) do
		familiar_keys[row.key] = true
		if not row.list or row.list == "" then issues[#issues + 1] = "familiar "..tostring(row.key).." missing list" end
	end
	local orbital_keys = {}
	for _, row in ipairs(M.CRAFT_ORBITAL_EXTRAS) do orbital_keys[row.key] = true end
	for id, key in pairs(M.EXTRA_IMPL) do
		if type(key) == "string" and key ~= "multishot"
			and not M.compat_display_name(id, key, true)
			and not M.compat_display_name(id, key, false)
		then
			issues[#issues + 1] = "collectible "..tostring(id).." key "..key.." missing display name"
		end
		if familiar_keys[key] and not M.CRAFT_FAMILIAR_EXTRA_LIST_KEY[key] then
			issues[#issues + 1] = "familiar "..key.." missing derived list mapping"
		end
		if orbital_keys[key] and not M.CRAFT_ORBITAL_EXTRAS_KEY_SET[key] then
			issues[#issues + 1] = "orbital "..key.." missing derived key"
		end
	end
	for id, def in pairs(M.COMPAT_REGISTRY) do
		if not M.COMPAT_RUNTIME_ADAPTERS[def.key] then
			issues[#issues + 1] = "registered collectible "..tostring(id).." ("..def.key..") missing runtime adapter"
		end
		if def.category == "familiar" then
			local key = def.key
			if type(key) ~= "string" or key == "" then
				issues[#issues + 1] = "familiar id="..tostring(id).." missing key"
			else
				local list_key = def.list
				if type(list_key) ~= "string" or list_key == "" then
					issues[#issues + 1] = "familiar "..key.." missing list after normalize"
					list_key = key
				end
				if M.CRAFT_FAMILIAR_EXTRA_LIST_KEY[key] ~= list_key then
					issues[#issues + 1] = "familiar "..key.." EXTRA_LIST_KEY mismatch"
				end
				local counts = {[id] = 1}
				local list = M.list_from_counts(counts)
				local list_n = tonumber(list and list[list_key]) or 0
				if list_n ~= 1 then
					issues[#issues + 1] = "familiar projection broken: id="..tostring(id).." key="..key.." count=1 list="..tostring(list_n)
				end
				local _, _, extras = M.resolve_weapon(list, counts)
				if not extras or extras[key] ~= true then
					issues[#issues + 1] = "familiar projection broken: id="..tostring(id).." key="..key.." extra=false"
				end
			end
		end
	end
	table.sort(issues)
	return {ok = #issues == 0, issues = issues, registered = M.COMPAT_REGISTRY}
end

function M.familiar_labels(extras, zh)
	local labels = {}
	extras = extras or {}
	for _, row in ipairs(M.CRAFT_FAMILIAR_EXTRAS) do
		if extras[row.key] then
			labels[#labels + 1] = zh and row.zh or row.en
		end
	end
	return labels
end

--- 制造环绕物审计短名（独立「环绕物」行；按配方 counts）
function M.orbital_labels(counts, zh)
	local labels = {}
	counts = counts or {}
	for _, row in ipairs(M.CRAFT_ORBITAL_EXTRAS) do
		local id = tonumber(row.id)
		if id and (counts[id] or 0) > 0 then
			labels[#labels + 1] = zh and row.zh or row.en
		end
	end
	return labels
end

--- 配方是否需要左右眼相位（眼药水 / 单眼道具）
function M.weapon_label(weapon, zh)
	local info = M.WEAPON_NAME[weapon or 1]
	if not info then return tostring(weapon or 1) end
	return zh and info.zh or info.en
end

--- 血泪作主攻击方式时（武器表决为眼泪），审计「方式」写血泪而非眼泪
function M.profile_shows_haemo_weapon(profile)
	if not profile then return false end
	local ex = profile.extras or {}
	if not ex.haemolacria then return false end
	return (profile.weapon or 1) == 1
end

function M.profile_attack_label(profile, zh)
	if M.profile_shows_haemo_weapon(profile) then
		return zh and "血泪" or "Haemolacria"
	end
	return M.weapon_label(profile and profile.weapon, zh)
end

--- 蓝图 pedestal EID：正式句式，见 craft_eid_copy.lua / blueprint_craft_eid_copy_review.md
function M.collectible_craft_eid_lines(id, zh)
	local copy = require("Qing_Remaster_scripts.others.craft_eid_copy")
	return copy.collectible_craft_eid_lines(id, zh)
end

function M.collectible_craft_eid_text(id, zh)
	local copy = require("Qing_Remaster_scripts.others.craft_eid_copy")
	return copy.collectible_craft_eid_text(id, zh)
end

function M.target_base_label(target, zh)
	local info = M.TARGET_BASE[target]
	if not info then return nil end
	return zh and info.zh or info.en
end

function M.fmt_num(n, digits)
	digits = digits or 2
	local m = 10 ^ digits
	local v = math.floor((n or 0) * m + 0.5) / m
	return tostring(v)
end

--- 当前主武器实际消费的兼容组合标签（写入审计「特效」行）
--- 血泪：方式已写「血泪」时，特效只挂简略 guest 名（硫磺/科技/…），不写长串「覆盖/眼泪+X/爆裂X」
function M.compat_labels(profile, zh)
	local labels = {}
	local syn = (profile and profile.synergy) or {}
	local host = profile and profile.weapon
	local consumed = (profile and profile.compat_consumed) or {}
	local ex = profile and profile.extras or {}

	if ex.haemolacria then
		if ex.haemo_override then
			-- 均分 guest 优先；否则列 haemo_guests
			local guests = ex.haemo_share_guests
			if not guests or #guests == 0 then
				guests = ex.haemo_guests or {}
			end
			local seen = {}
			for _, w in ipairs(guests) do
				w = tonumber(w) or w
				if w and not seen[w] then
					seen[w] = true
					labels[#labels + 1] = M.weapon_label(w, zh)
				end
			end
		elseif ex.haemo_ludo_proc then
			labels[#labels + 1] = zh and "血泪触发" or "HaeProc"
		elseif ex.haemo_fetus_proc then
			labels[#labels + 1] = zh and "落地爆发" or "LandBurst"
		end
		-- 刀/剑作主武时「方式」已写刀/剑；特效靠 FLAG_NAME「血泪」，不再写长兼容串
	else
		local host_name = M.weapon_label(host, zh)
		for _, w in ipairs(consumed) do
			labels[#labels + 1] = host_name .. "+" .. M.weapon_label(w, zh)
		end
	end

	-- 同种叠层等非 BRANCH_COMPAT 形态变化，也并入特效标注
	if syn.thick_brim then
		labels[#labels + 1] = zh and "粗硫磺" or "ThickBrim"
	end
	if (syn.extra_shots or 0) > 0 then
		labels[#labels + 1] = (zh and "叠+" or "stk+") .. tostring(syn.extra_shots)
	end
	return labels
end

local function filter_fx_for_weapon(parts, profile, zh)
	local host = tonumber(profile and profile.weapon) or 1
	if host ~= (M.LUDO_WEAPON or 8) then
		return parts
	end
	-- 只藏 spectral 展示名；从 FLAG_NAME 取正式短名，避免写死翻译。
	local hidden = {}
	for _, id in ipairs({115, 159, 185, 329, 336, 358, 379}) do
		local info = M.FLAG_NAME and M.FLAG_NAME[id]
		if info then
			local name = zh and info.zh or info.en
			if name and name ~= "" then hidden[name] = true end
		end
	end
	local out = {}
	for _, name in ipairs(parts or {}) do
		if not hidden[name] then
			out[#out + 1] = name
		end
	end
	return out
end

local function audit_display_width(s)
	if not s or s == "" then return 0 end
	local n, i, len = 0, 1, #s
	while i <= len do
		local c = s:byte(i)
		if not c then break end
		if c < 0x80 then
			n = n + 1
			i = i + 1
		elseif c < 0xE0 then
			n = n + 2
			i = i + 2
		elseif c < 0xF0 then
			n = n + 2
			i = i + 3
		else
			n = n + 2
			i = i + 4
		end
	end
	return n
end

local function wrap_audit_parts(parts, opts)
	opts = opts or {}
	parts = parts or {}
	local prefix = opts.prefix or ""
	local continuation = opts.continuation
	if continuation == nil then
		continuation = string.rep(" ", audit_display_width(prefix))
	end
	local separator = opts.separator or "  "
	local limit = tonumber(opts.limit) or 42
	local max_lines = tonumber(opts.max_lines) or 2
	local lines = {}
	local current = ""
	local index = 1
	while index <= #parts and #lines < max_lines do
		local part = tostring(parts[index] or "")
		local candidate = current == "" and part or (current .. separator .. part)
		local head = #lines == 0 and prefix or continuation
		local width = audit_display_width(head .. candidate)
		if width <= limit or current == "" then
			current = candidate
			index = index + 1
		else
			lines[#lines + 1] = head .. current
			current = ""
		end
	end
	if current ~= "" and #lines < max_lines then
		local head = #lines == 0 and prefix or continuation
		lines[#lines + 1] = head .. current
	end
	if index <= #parts and #lines > 0 then
		lines[#lines] = lines[#lines] .. "…"
	end
	return lines
end

--- Compact audit lines for Blueprint UI.
--- player 可选：再解析一次套装，写入独立「套装」行
function M.audit_lines(profile, zh, player)
	if not profile then
		return {zh and "（空配方）" or "(empty recipe)"}
	end
	local st = profile.stats or M.BASE_STATS
	local ms = profile.multishot or {count = 1}
	local lines = {}
	lines[#lines + 1] = (zh and "方式 " or "Wpn ") .. M.profile_attack_label(profile, zh)
		.. "  x" .. tostring(ms.count)
	-- 显示端与 Found HUD / EID 对齐：内部 MaxFireDelay → 每秒攻击数。
	local function display_fire_rate(delay)
		return 30 / (math.max(-0.75, tonumber(delay) or 10) + 1)
	end
	local tear_txt = M.fmt_num(display_fire_rate(st.firedelay), 2)
	local wmul = tonumber(st.weapon_delay_mul) or 1
	if wmul ~= 1 and st.firedelay_base ~= nil then
		-- 主武器倍率作用于内部 delay；括号只辅助展示基础 Fire Rate。
		tear_txt = tear_txt .. "(" .. (zh and "底" or "base ")
			.. M.fmt_num(display_fire_rate(st.firedelay_base), 2) .. ")"
	end
	lines[#lines + 1] = (zh and "伤害 " or "DMG ") .. M.fmt_num(st.damage, 2)
		.. (zh and "  射速 " or "  Tear ") .. tear_txt
	lines[#lines + 1] = (zh and "弹速 " or "SS ") .. M.fmt_num(st.shotspeed, 2)
		.. (zh and "  射程 " or "  Rng ") .. M.fmt_num((tonumber(st.range) or 0) / 40, 2)
	lines[#lines + 1] = (zh and "移速 " or "Spd ") .. M.fmt_num(st.speed, 2)
		.. (zh and "  幸运 " or "  Luk ") .. M.fmt_num(st.luck, 1)
	local mods = M.attack_modifiers_from_profile(profile)
	if mods and mods.chocolate then
		local pct = math.floor(mods.ratio * 100 + 0.5)
		local base_delay = tonumber(st.firedelay) or 10
		local final_delay = M.attack_delay_from_modifiers(base_delay, mods)
		lines[#lines + 1] = (zh and "巧克力 " or "Choco ")
			.. tostring(pct) .. "%"
			.. (zh and " 伤×" or " dmg×") .. M.fmt_num(mods.damage_mul, 2)
			.. (zh and " 尺×" or " sz×") .. M.fmt_num(mods.size_mul, 2)
			.. (zh and " 蓄" or " charge ") .. tostring(mods.charge_frames or 0) .. (zh and "帧" or "f")
			.. (zh and " 射速 " or " rate ") .. M.fmt_num(display_fire_rate(final_delay), 2)
	end
	if mods and mods.techx then
		local pct = math.floor((mods.techx_ratio or 1) * 100 + 0.5)
		lines[#lines + 1] = (zh and "科技X " or "TechX ")
			.. tostring(pct) .. "%"
			.. (zh and " 环×" or " rad×") .. M.fmt_num(mods.techx_radius_mul, 2)
			.. (zh and " 伤×" or " dmg×") .. M.fmt_num(mods.techx_damage_mul, 2)
			.. (zh and " 间隔×" or " delay×") .. M.fmt_num(mods.techx_delay_mul, 2)
	end
	if mods and mods.knife then
		local pct = math.floor((mods.knife_ratio or 1) * 100 + 0.5)
		lines[#lines + 1] = (zh and "妈刀蓄力 " or "Knife ")
			.. tostring(pct) .. "%"
			.. (zh and " 伤×" or " dmg×") .. M.fmt_num(mods.knife_damage_mul, 2)
			.. (zh and " 距×" or " rng×") .. M.fmt_num(mods.knife_range_mul, 2)
			.. (zh and " 蓄" or " charge ") .. tostring(mods.knife_charge_frames or 0) .. (zh and "帧" or "f")
	end
	if profile.extras and profile.extras.cursed_eye then
		local shots = tonumber(mods.cursed_shots) or (M.cursed_shot_count_from_charge(mods.cursed_ratio or mods.charge_ratio))
		lines[#lines + 1] = (zh and "诅咒眼 " or "CursedEye ")
			.. tostring(math.floor((mods.cursed_ratio or mods.charge_ratio or 1) * 100 + 0.5)) .. "%"
			.. (zh and " 总发 " or " shots ") .. tostring(shots)
	end
	local sc = tonumber(st.scale) or 1
	if math.abs(sc - 1) > 0.01 then
		lines[#lines + 1] = (zh and "弹体 " or "Size ") .. M.fmt_num(sc, 2)
			.. (zh and "×（泪/弹/炸）" or "x (tear/bomb)")
	end
	local fx_parts = M.effect_labels(profile.counts, zh)
	fx_parts = filter_fx_for_weapon(fx_parts, profile, zh)
	local ex = profile.extras or {}
	local seen_fx = {}
	for _, p in ipairs(fx_parts) do seen_fx[p] = true end
	local function push_fx(name)
		if not name or seen_fx[name] then return end
		seen_fx[name] = true
		fx_parts[#fx_parts + 1] = name
	end
	-- 方式已写「血泪」时，特效不再重复「血泪」短名
	if M.profile_shows_haemo_weapon(profile) then
		local hae_name = zh and "血泪" or "Haemolacria"
		seen_fx[hae_name] = true
		for i = #fx_parts, 1, -1 do
			if fx_parts[i] == hae_name then
				table.remove(fx_parts, i)
			end
		end
	end
	-- extras 布尔（科技2 等）：确保描述可见
	if ex.tech2 then push_fx(zh and "科技2" or "Tech2") end
	if ex.tech5 then push_fx(zh and "科技0.5" or "Tech5") end
	if ex.chocolate then push_fx(zh and "巧克力奶" or "Choco") end
	if ex.cursed_eye then push_fx(zh and "诅咒眼" or "CursedEye") end
	if ex.fruit_cake then push_fx(zh and "水果蛋糕" or "FruitCake") end
	-- 宝宝不进特效行；见下方独立「宝宝」行（also_fx 项仍可由 effect_labels/EXTRA_NAME 进特效）
	-- 制造复活源：特效行显示剩余/已用尽
	if player and profile.craft_uid then
		local ok_bp, bp = pcall(require, "Qing_Remaster_scripts.items.Item_Blue_Print")
		local rec = (ok_bp and bp and bp.find_craft) and bp.find_craft(player, profile.craft_uid) or nil
		if rec then
			for _, src in ipairs(M.CRAFT_REVIVE_SOURCES) do
				if ex[src.key] then
					local base = M.EXTRA_NAME[src.key]
					local old = base and (zh and base.zh or base.en)
					local neu = M.craft_revive_fx_label(src.key, rec, zh)
					if old and neu and old ~= neu then
						for i = #fx_parts, 1, -1 do
							if fx_parts[i] == old then fx_parts[i] = neu end
						end
					end
				end
			end
		end
	end
	local dyn_label = {
		money = {zh = "金钱力量", en = "Money"},
		whore = {zh = "大淫妇", en = "Whore"},
		bloody_lust = {zh = "嗜血", en = "Lust"},
		bloody_gust = {zh = "血怒", en = "Gust"},
		experimental = {zh = "针剂", en = "Exp"},
		adrenaline = {zh = "肾上腺素", en = "Adr"},
		crown_light = {zh = "白王冠", en = "CoL"},
		dark_crown = {zh = "黑王冠", en = "DPC"},
		purity = {zh = "白莲", en = "Purity"},
		lusty_blood = {zh = "杀戮嗜血", en = "Lusty"},
		libra = {zh = "天平", en = "Libra"},
		milk = {zh = "牛奶", en = "Milk"},
		camo_undies = {zh = "迷彩", en = "Camo"},
		jupiter = {zh = "木星", en = "Jupiter"},
		paschal_candle = {zh = "蜡烛层", en = "Paschal"},
		rock_bottom = {zh = "谷底石", en = "Rock Bottom"},
		red_stew = {zh = "红豆汤", en = "RedStew"},
		candy_heart = {zh = "糖心", en = "CandyHeart"},
		soul_locket = {zh = "魂匣", en = "SoulLocket"},
		heartbreak = {zh = "心碎", en = "Heartbreak"},
		keepers_sack = {zh = "店长袋", en = "KeepersSack"},
		binge_eater = {zh = "暴食", en = "Binge"},
		false_phd = {zh = "假博士", en = "FalsePHD"},
		neptunus = {zh = "海王星", en = "Neptunus"},
	}
	for _, tag in ipairs(profile.dyn_tags or {}) do
		local info = dyn_label[tag]
		if info then push_fx(zh and info.zh or info.en) end
	end
	if profile.runtime and profile.runtime.occult_stats_only then
		-- 覆盖泪弹 flag 名「可控泪弹」为降级标签
		for i = #fx_parts, 1, -1 do
			if fx_parts[i] == (zh and "可控泪弹" or "Eye of the Occult") then
				table.remove(fx_parts, i)
			end
		end
		seen_fx[zh and "可控泪弹" or "Eye of the Occult"] = nil
		push_fx(zh and "玄秘(属性)" or "Occult (stats)")
	end
	local body_m = tonumber(profile.body_scale_mul) or 1
	if math.abs(body_m - 1) > 0.01 then
		push_fx((zh and "体型×" or "Body×") .. M.fmt_num(body_m, 2))
	end
	for _, c in ipairs(M.compat_labels(profile, zh)) do
		push_fx(c)
	end
	-- 套装 / 宝宝单独一行；不再写入「特效」串，避免挤占与重复
	local forms = profile.forms or {}
	if player and profile.counts then
		local live_forms = M.resolve_player_forms(player, profile.counts, "audit_lines")
		for k, v in pairs(live_forms) do
			if v then forms[k] = true end
		end
	end
	local form_parts = M.form_effect_labels(forms, zh, player)
	if #form_parts > 0 then
		lines[#lines + 1] = (zh and "套装 " or "Form ") .. table.concat(form_parts, zh and "·" or ",")
	end
	local fam_parts = M.familiar_labels(ex, zh)
	if #fam_parts > 0 then
		-- 制造复活宝宝：标注剩余/已用尽
		if player and profile.craft_uid then
			local ok_bp, bp = pcall(require, "Qing_Remaster_scripts.items.Item_Blue_Print")
			local rec = (ok_bp and bp and bp.find_craft) and bp.find_craft(player, profile.craft_uid) or nil
			if rec then
				for _, src in ipairs(M.CRAFT_REVIVE_SOURCES) do
					if src.follower and ex[src.key] then
						local row_zh = nil
						local row_en = nil
						for _, row in ipairs(M.CRAFT_FAMILIAR_EXTRAS) do
							if row.key == src.key then
								row_zh, row_en = row.zh, row.en
								break
							end
						end
						local old = zh and row_zh or row_en
						local used = M.craft_revive_source_spent(rec, src.key)
						local uses = tonumber(src.uses) or 0
						local neu = old
						if old and uses > 0 then
							if used >= uses then
								neu = zh and (old .. "(已用尽)") or (old .. "(spent)")
							elseif used > 0 then
								local left = uses - used
								neu = zh and (old .. "(剩" .. tostring(left) .. ")") or (old .. "(left" .. tostring(left) .. ")")
							end
						end
						if old and neu and old ~= neu then
							for i, name in ipairs(fam_parts) do
								if name == old then fam_parts[i] = neu end
							end
						end
					end
				end
			end
		end
		local fam_lines = wrap_audit_parts(fam_parts, {
			prefix = zh and "宝宝 " or "Fam ",
			separator = "  ",
			limit = 42,
			max_lines = 2,
		})
		for _, line in ipairs(fam_lines) do
			lines[#lines + 1] = line
		end
	end
	local orb_parts = M.orbital_labels(profile.counts, zh)
	if #orb_parts > 0 then
		local orb_lines = wrap_audit_parts(orb_parts, {
			prefix = zh and "环绕物 " or "Orb ",
			separator = "  ",
			limit = 42,
			max_lines = 2,
		})
		for _, line in ipairs(orb_lines) do
			lines[#lines + 1] = line
		end
	end
	if #fx_parts > 0 then
		local fx_lines = wrap_audit_parts(fx_parts, {
			prefix = zh and "特效 " or "FX ",
			separator = "  ",
			limit = 42,
			max_lines = 2,
		})
		for _, line in ipairs(fx_lines) do
			lines[#lines + 1] = line
		end
	else
		lines[#lines + 1] = zh and "特效 无" or "FX none"
	end
	local uns = profile.unsupported_morphs or {}
	if #uns > 0 then
		local names = {}
		for _, w in ipairs(uns) do names[#names + 1] = M.weapon_label(w, zh) end
		lines[#lines + 1] = (zh and "未兼容 " or "Miss ") .. table.concat(names, "·")
	end
	return lines
end

--- Spread directions for multishot (count >= 1).
local ROMAN_VAL = {I = 1, V = 5, X = 10, L = 50, C = 100, D = 500, M = 1000}
local _hanzi_pinyin = nil
local NAME_STOP = {
	THE = true, OF = true, A = true, AN = true, AND = true, OR = true,
	TO = true, IN = true, ON = true, FOR = true, WITH = true, FROM = true,
	BY = true, AT = true, AS = true, IS = true,
}
local NAME_VOWEL = {A = true, E = true, I = true, O = true, U = true, Y = true}

local function split_utf8(str)
	local ret = {}
	local i = 1
	str = str or ""
	while i <= #str do
		local b = string.byte(str, i)
		local len = 1
		if b and b >= 240 then len = 4
		elseif b and b >= 224 then len = 3
		elseif b and b >= 192 then len = 2 end
		ret[#ret + 1] = string.sub(str, i, i + len - 1)
		i = i + len
	end
	return ret
end

local function ensure_hanzi_pinyin()
	if _hanzi_pinyin then return end
	_hanzi_pinyin = {}
	local ok, cih = pcall(require, "Qing_Remaster_scripts.others.Chinese_input_holder")
	if not ok or not cih or not cih.data then return end
	for syl, chars in pairs(cih.data) do
		for _, ch in ipairs(split_utf8(chars)) do
			if not _hanzi_pinyin[ch] then
				_hanzi_pinyin[ch] = syl
			end
		end
	end
end

local function name_to_latin(name)
	name = name or ""
	ensure_hanzi_pinyin()
	local parts = {}
	for _, ch in ipairs(split_utf8(name)) do
		local b = string.byte(ch, 1)
		if b and b < 128 then
			parts[#parts + 1] = ch
		else
			local py = _hanzi_pinyin and _hanzi_pinyin[ch]
			if py then parts[#parts + 1] = py end
		end
	end
	return table.concat(parts)
end

local function arabic_to_roman(n)
	n = math.floor(tonumber(n) or 0)
	if n <= 0 then return nil end
	if n > 3999 then n = ((n - 1) % 3999) + 1 end
	local vals = {1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1}
	local syms = {"M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"}
	local s = ""
	for i, v in ipairs(vals) do
		while n >= v do
			n = n - v
			s = s .. syms[i]
		end
	end
	return s ~= "" and s or nil
end

local function collectible_latin_name(id)
	id = tonumber(id) or id
	if not id or id == 0 then return "" end
	local col = Isaac.GetItemConfig():GetCollectible(id)
	if not col then return "" end
	return name_to_latin(col.Name or "")
end

-- 常用罗马数字（长到短）
local ROMAN_FIND = {
	"XXXIX", "XXXVIII", "XXXVII", "XXXVI", "XXXV", "XXXIV", "XXXIII", "XXXII", "XXXI", "XXX",
	"XXIX", "XXVIII", "XXVII", "XXVI", "XXV", "XXIV", "XXIII", "XXII", "XXI", "XX",
	"XIX", "XVIII", "XVII", "XVI", "XV", "XIV", "XIII", "XII", "XI", "X",
	"IX", "VIII", "VII", "VI", "IV", "V", "III", "II", "I",
	"XL", "L", "XC", "C", "CD", "D", "CM", "M",
}
local ROMAN_WORD = {}
for _, r in ipairs(ROMAN_FIND) do ROMAN_WORD[r] = true end

--- 在大写串中挑「最好」的罗马：更长优先；单字母仅词界匹配，且可被 min_len 排除以免抢占 II/CM 等
local function find_best_roman_in_upper(upper, opts)
	opts = opts or {}
	local min_len = tonumber(opts.min_len) or 1
	local best, best_len, best_pos = nil, 0, math.huge
	upper = upper or ""
	for _, r in ipairs(ROMAN_FIND) do
		if #r >= min_len then
			local pos = 1
			while true do
				local a, b = string.find(upper, r, pos, true)
				if not a then break end
				local ok = true
				if #r == 1 then
					local prev = a > 1 and string.sub(upper, a - 1, a - 1) or ""
					local nxt = b < #upper and string.sub(upper, b + 1, b + 1) or ""
					if prev:match("%a") or nxt:match("%a") then ok = false end
				end
				if ok and (#r > best_len or (#r == best_len and a < best_pos)) then
					best, best_len, best_pos = r, #r, a
				end
				pos = a + 1
			end
		end
	end
	return best
end

local function words_from_latin(latin)
	local upper = string.upper(latin or "")
	local words, digits = {}, {}
	for w in upper:gmatch("%a+") do
		if ROMAN_WORD[w] then
			words[#words + 1] = {roman = w}
		elseif NAME_STOP[w] then
			-- skip
		elseif #w == 1 and w == "S" then
			-- 所有格残留（Mom's → S）
		elseif #w >= 1 then
			words[#words + 1] = {text = w}
		end
	end
	for d in upper:gmatch("%d+") do
		digits[#digits + 1] = d
	end
	return words, digits, upper:gsub("[^%w]", "")
end

local function push_unique(bag, ch, max_same)
	max_same = max_same or 2
	local n = 0
	for i = 1, #bag do
		if bag[i] == ch then n = n + 1 end
	end
	if n < max_same then bag[#bag + 1] = ch end
end

local function take_from_pool(pool, count, used)
	used = used or {}
	local out = {}
	local i = 1
	while #out < count and i <= #pool do
		local ch = pool[i]
		if not used[ch] or used[ch] < 1 then
			out[#out + 1] = ch
			used[ch] = (used[ch] or 0) + 1
		elseif #pool - i < count - #out then
			out[#out + 1] = ch
			used[ch] = (used[ch] or 0) + 1
		end
		i = i + 1
	end
	i = 1
	while #out < count and #pool > 0 do
		out[#out + 1] = pool[((i - 1) % #pool) + 1]
		i = i + 1
		if i > #pool * 3 then break end
	end
	return table.concat(out), used
end

local function mark_roman_used(used, roman)
	used = used or {}
	for ch in (roman or ""):gmatch("%a") do
		used[ch] = (used[ch] or 0) + 1
	end
	return used
end

--- 从材料英文名组合附加型号，如 "MK NF 型"
--- 罗马：数字优先；再取最长匹配（≥2 可嵌在词内）；单字母 M/X…可整词采用，但单独作型号时会补字母，避免「OM M」
function M.build_model_code(ingredients)
	local initials, consonants, vowels, romans = {}, {}, {}, {}
	local digit_chunks = {}
	local joined_upper = {}
	local keys = {}
	for k, _ in pairs(ingredients or {}) do
		local idx = tonumber(k) or k
		if type(idx) == "number" then keys[#keys + 1] = idx end
	end
	table.sort(keys)
	if #keys == 0 then return nil end

	for _, idx in ipairs(keys) do
		local id = ingredients[idx] or ingredients[tostring(idx)]
		local latin = collectible_latin_name(id)
		local words, digs, compact = words_from_latin(latin)
		joined_upper[#joined_upper + 1] = compact or ""
		for _, d in ipairs(digs) do digit_chunks[#digit_chunks + 1] = d end
		for _, w in ipairs(words) do
			if w.roman then
				romans[#romans + 1] = w.roman
			elseif w.text then
				local t = w.text
				local first = string.sub(t, 1, 1)
				push_unique(initials, first, 2)
				for i = 2, #t do
					local ch = string.sub(t, i, i)
					if NAME_VOWEL[ch] then
						push_unique(vowels, ch, 2)
					else
						push_unique(consonants, ch, 2)
					end
				end
			end
		end
	end

	if #initials == 0 and #consonants == 0 and #vowels == 0
		and #romans == 0 and #digit_chunks == 0
	then
		return nil
	end

	local roman = nil
	if #digit_chunks > 0 then
		local num = tonumber(table.concat(digit_chunks))
		if num and num > 0 then roman = arabic_to_roman(num) end
	end
	-- 整词罗马：先要长度≥2（III/XIV…），避免单字母 M 抢占
	if not roman and #romans > 0 then
		table.sort(romans, function(a, b)
			if #a ~= #b then return #a > #b end
			return a < b
		end)
		for _, r in ipairs(romans) do
			if #r >= 2 then roman = r break end
		end
	end
	-- 子串同样只认 ≥2，MOM/KNIFE 内的 M、I 不会抢走 CM/II
	if not roman then
		roman = find_best_roman_in_upper(table.concat(joined_upper), {min_len = 2})
	end
	-- 再允许整词单字母罗马（M/X/V…）
	if not roman and #romans > 0 then
		for _, r in ipairs(romans) do
			if #r == 1 then roman = r break end
		end
	end
	if not roman then
		roman = find_best_roman_in_upper(table.concat(joined_upper), {min_len = 1})
	end

	local n_ing = #keys
	local want_prefix = math.max(2, math.min(5, math.max(#initials, 1 + n_ing)))
	local short_roman = roman ~= nil and #roman == 1
	local want_model = roman and (short_roman and 2 or 0)
		or math.max(2, math.min(3, 1 + math.floor(n_ing / 2)))

	local used = {}
	if roman and not short_roman then
		used = mark_roman_used(used, roman)
	elseif roman and short_roman then
		-- 单字母罗马可保留语义，但先占位；补字母后再统一 mark
		used[roman] = (used[roman] or 0) + 1
	end

	local prefix, used2 = take_from_pool(initials, want_prefix, used)
	used = used2
	if #prefix < want_prefix then
		local extra
		extra, used = take_from_pool(consonants, want_prefix - #prefix, used)
		prefix = prefix .. extra
	end
	if #prefix < want_prefix then
		local extra
		extra, used = take_from_pool(vowels, want_prefix - #prefix, used)
		prefix = prefix .. extra
	end
	if #prefix < 2 then
		local fill = consonants[1] or vowels[1] or initials[1] or "X"
		while #prefix < 2 do prefix = prefix .. fill end
	end
	if #prefix > 5 then prefix = string.sub(prefix, 1, 5) end

	if not roman then
		local model
		model, used = take_from_pool(consonants, want_model, used)
		if #model < want_model then
			local extra
			extra, used = take_from_pool(initials, want_model - #model, used)
			model = model .. extra
		end
		if #model < want_model then
			local extra
			extra, used = take_from_pool(vowels, want_model - #model, used)
			model = model .. extra
		end
		while #model < 2 do model = model .. "X" end
		if #model > 3 then model = string.sub(model, 1, 3) end
		roman = model
	elseif short_roman then
		-- 「M」可接受为罗马，但单独作型号太干：补 1–2 个未占用字母 → 如 M + NF
		local pad
		pad, used = take_from_pool(consonants, want_model, used)
		if #pad < want_model then
			local extra
			extra, used = take_from_pool(initials, want_model - #pad, used)
			pad = pad .. extra
		end
		if #pad < 1 then
			local extra
			extra, used = take_from_pool(vowels, 1, used)
			pad = pad .. extra
		end
		if #pad < 1 then pad = "X" end
		roman = roman .. pad
		if #roman > 3 then roman = string.sub(roman, 1, 3) end
	end

	return prefix .. " " .. roman .. " 型"
end

function M.build_display_name(target, serial, ingredients, zh)
	zh = zh ~= false
	local base_info = M.TARGET_BASE[target]
	local serial_s = string.format("%02d", math.max(1, math.floor(tonumber(serial) or 1)))
	local head
	if base_info then
		head = (zh and base_info.zh or base_info.en) .. serial_s .. (zh and "号" or "")
	else
		head = "#" .. serial_s
	end
	local model = M.build_model_code(ingredients)
	if model and model ~= "" then
		return head .. "·" .. model
	end
	return head
end

end

return Mod

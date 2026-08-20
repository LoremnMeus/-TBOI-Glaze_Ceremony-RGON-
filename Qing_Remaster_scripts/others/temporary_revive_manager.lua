-- 临时/Innate 消耗型复活账本。
-- 原版会消耗 innate 份数，但本模组 provider 下次 sync 又会写回 → 无限复活。
-- 方案见 codex_work/notes/temporary_revive_items_audit.md：账本 + Held Sprite 主证据。
local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local M = {
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	own_key = "TempRevive_",
	PROVIDER_QING = "qing_imitate",
	CAPTURE_FRAMES = 90,
	-- 运行时调试（ImGui 可开）；默认关
	debug_log = false,
	last_events = {},
}

-- uses_per_grant=0：概率/不消耗自身，只作优先级障碍（不扣账）
local CONSUMABLES = {
	[CollectibleType.COLLECTIBLE_1UP or 11] = {
		uses_per_grant = 1, name = "1up",
	},
	[CollectibleType.COLLECTIBLE_DEAD_CAT or 81] = {
		uses_per_grant = 9, name = "DeadCat",
	},
	[CollectibleType.COLLECTIBLE_INNER_CHILD or 688] = {
		uses_per_grant = 1, name = "InnerChild",
	},
	[CollectibleType.COLLECTIBLE_LAZARUS_RAGS or 332] = {
		uses_per_grant = 1, name = "LazarusRags",
	},
	[CollectibleType.COLLECTIBLE_ANKH or 161] = {
		uses_per_grant = 1, name = "Ankh",
	},
	[CollectibleType.COLLECTIBLE_JUDAS_SHADOW or 311] = {
		uses_per_grant = 1, name = "JudasShadow",
	},
	[CollectibleType.COLLECTIBLE_GUPPYS_COLLAR or 212] = {
		uses_per_grant = 0, name = "GuppysCollar", probabilistic = true,
	},
}

-- 原版大致优先级（仅本模组可扣账的临时 collectible；夹档障碍仍列入）
local PRIORITY = {
	{kind = "collectible", id = CollectibleType.COLLECTIBLE_1UP or 11},
	{kind = "collectible", id = CollectibleType.COLLECTIBLE_DEAD_CAT or 81},
	{kind = "collectible", id = CollectibleType.COLLECTIBLE_INNER_CHILD or 688},
	{kind = "collectible", id = CollectibleType.COLLECTIBLE_GUPPYS_COLLAR or 212},
	{kind = "collectible", id = CollectibleType.COLLECTIBLE_LAZARUS_RAGS or 332},
	{kind = "collectible", id = CollectibleType.COLLECTIBLE_ANKH or 161},
	{kind = "trinket", id = TrinketType.TRINKET_BROKEN_ANKH or 28},
	{kind = "collectible", id = CollectibleType.COLLECTIBLE_JUDAS_SHADOW or 311},
	{kind = "trinket", id = TrinketType.TRINKET_MISSING_POSTER or 23},
	{kind = "trinket", id = TrinketType.TRINKET_MYSTERIOUS_PAPER or 21},
}

local DISPLAY_ALIASES = {
	-- Broken Ankh 成功时举起 Ankh 图
	[CollectibleType.COLLECTIBLE_ANKH or 161] = {
		{kind = "collectible", id = CollectibleType.COLLECTIBLE_ANKH or 161},
		{kind = "trinket", id = TrinketType.TRINKET_BROKEN_ANKH or 28},
	},
	-- Mysterious Paper → Missing Poster 图
	["missing_poster"] = {
		{kind = "trinket", id = TrinketType.TRINKET_MISSING_POSTER or 23},
		{kind = "trinket", id = TrinketType.TRINKET_MYSTERIOUS_PAPER or 21},
	},
}

local _gfx_basename_cache = nil
local _pending = {} -- [player_index] = capture state
local _grants = {} -- [player_index][provider][id] = granted copies（内存；spent 进存档）

local function dbg(msg)
	if not M.debug_log then return end
	local line = "[TempRevive] " .. tostring(msg)
	print(line)
	local list = M.last_events
	list[#list + 1] = {frame = Game():GetFrameCount(), text = line}
	while #list > 24 do table.remove(list, 1) end
end

local function player_index(player)
	if not player or not player.GetData then return nil end
	return player:GetData().__Index
end

local function spent_root()
	save.elses[M.own_key .. "spent"] = save.elses[M.own_key .. "spent"] or {}
	return save.elses[M.own_key .. "spent"]
end

local function get_spent(idx, provider, id)
	local root = spent_root()
	local p = root[idx] and root[idx][provider]
	if not p then return 0 end
	return tonumber(p[id] or p[tostring(id)]) or 0
end

local function set_spent(idx, provider, id, n)
	local root = spent_root()
	root[idx] = root[idx] or {}
	root[idx][provider] = root[idx][provider] or {}
	root[idx][provider][id] = math.max(0, tonumber(n) or 0)
	root[idx][provider][tostring(id)] = nil
end

local function add_spent(idx, provider, id, delta)
	set_spent(idx, provider, id, get_spent(idx, provider, id) + (delta or 1))
end

local function basename_of(path)
	if not path or path == "" then return nil end
	path = string.lower(tostring(path)):gsub("\\", "/")
	local base = path:match("([^/]+)$")
	return base
end

local function ensure_gfx_cache()
	if _gfx_basename_cache then return _gfx_basename_cache end
	_gfx_basename_cache = {}
	local cfg = Isaac.GetItemConfig()
	for id, _ in pairs(CONSUMABLES) do
		local col = cfg and cfg:GetCollectible(id)
		local bn = col and basename_of(col.GfxFileName)
		if bn then
			_gfx_basename_cache[bn] = _gfx_basename_cache[bn] or {}
			local list = _gfx_basename_cache[bn]
			list[#list + 1] = {kind = "collectible", id = id, display_id = id}
		end
	end
	for _, tid in ipairs({
		TrinketType.TRINKET_BROKEN_ANKH or 28,
		TrinketType.TRINKET_MISSING_POSTER or 23,
		TrinketType.TRINKET_MYSTERIOUS_PAPER or 21,
	}) do
		local tr = cfg and cfg:GetTrinket(tid)
		local bn = tr and basename_of(tr.GfxFileName)
		if bn then
			_gfx_basename_cache[bn] = _gfx_basename_cache[bn] or {}
			local list = _gfx_basename_cache[bn]
			list[#list + 1] = {kind = "trinket", id = tid, display_id = tid}
		end
	end
	return _gfx_basename_cache
end

local function copy_counts(src)
	local out = {}
	for id, n in pairs(src or {}) do
		local nid = tonumber(id)
		if nid then out[nid] = tonumber(n) or 0 end
	end
	return out
end

-- OnlyCountTrueItems + IgnoreSpoof：尽量不含 innate/spoof，便于区分「真实持有」与临时份
local function real_collectible_counts(player, ids)
	local out = {}
	for id, _ in pairs(ids or CONSUMABLES) do
		local n = 0
		if player.GetCollectibleNum then
			local ok, v = pcall(function()
				return player:GetCollectibleNum(id, true, true)
			end)
			if ok and v ~= nil then
				n = v
			else
				n = player:GetCollectibleNum(id, true) or 0
			end
		end
		out[id] = tonumber(n) or 0
	end
	return out
end

local function real_trinket_flags(player)
	return {
		[TrinketType.TRINKET_BROKEN_ANKH or 28] = player:HasTrinket(TrinketType.TRINKET_BROKEN_ANKH or 28) and true or false,
		[TrinketType.TRINKET_MISSING_POSTER or 23] = player:HasTrinket(TrinketType.TRINKET_MISSING_POSTER or 23) and true or false,
		[TrinketType.TRINKET_MYSTERIOUS_PAPER or 21] = player:HasTrinket(TrinketType.TRINKET_MYSTERIOUS_PAPER or 21) and true or false,
	}
end

local function temp_available(idx, provider, id)
	local cfg = CONSUMABLES[id]
	if not cfg or (cfg.uses_per_grant or 0) <= 0 then return false end
	local grants = (_grants[idx] and _grants[idx][provider] and _grants[idx][provider][id]) or 0
	if grants <= 0 then return false end
	local spent = get_spent(idx, provider, id)
	return spent < grants * cfg.uses_per_grant
end

--- provider 申报的期望份数 → 写入 grants，并在消失/缩减时整理 spent
function M.sync_grants_from_desired(player, desired, provider)
	provider = provider or M.PROVIDER_QING
	local idx = player_index(player)
	if not idx then return end
	desired = desired or {}
	_grants[idx] = _grants[idx] or {}
	_grants[idx][provider] = _grants[idx][provider] or {}
	local bag = _grants[idx][provider]
	for id, cfg in pairs(CONSUMABLES) do
		local g = tonumber(desired[id]) or 0
		if g < 0 then g = 0 end
		local prev = tonumber(bag[id]) or 0
		bag[id] = g
		if g <= 0 then
			set_spent(idx, provider, id, 0)
		elseif g < prev and (cfg.uses_per_grant or 0) > 0 then
			local cap = g * cfg.uses_per_grant
			set_spent(idx, provider, id, math.min(get_spent(idx, provider, id), cap))
		end
	end
end

--- 把 recorder/desired 扣成有效 innate 份数（供 sync_rgon_fake_items）
function M.apply_effective_desired(player, desired, provider)
	provider = provider or M.PROVIDER_QING
	local idx = player_index(player)
	local out = copy_counts(desired)
	if not idx then return out end
	for id, cfg in pairs(CONSUMABLES) do
		local uses = tonumber(cfg.uses_per_grant) or 0
		if uses > 0 and (out[id] or 0) > 0 then
			local g = out[id]
			local spent = get_spent(idx, provider, id)
			local remain = math.max(0, g * uses - spent)
			if uses == 1 then
				out[id] = math.min(g, remain)
			else
				-- Dead Cat：额度未耗尽时保留 innate 份数，耗尽后清零
				out[id] = (remain > 0) and g or 0
			end
		end
	end
	return out
end

local function snapshot_player(player)
	local idx = player_index(player)
	local provider = M.PROVIDER_QING
	local temp = {}
	local avail = {}
	for id, cfg in pairs(CONSUMABLES) do
		local g = (_grants[idx] and _grants[idx][provider] and _grants[idx][provider][id]) or 0
		temp[id] = g
		local uses = tonumber(cfg.uses_per_grant) or 0
		if uses > 0 then
			avail[id] = math.max(0, g * uses - get_spent(idx, provider, id))
		elseif cfg.probabilistic then
			avail[id] = g > 0 and 1 or 0
		else
			avail[id] = 0
		end
	end
	return {
		frame = Game():GetFrameCount(),
		player_type = player:GetPlayerType(),
		extra_lives = player.GetExtraLives and player:GetExtraLives() or 0,
		real = real_collectible_counts(player),
		trinkets = real_trinket_flags(player),
		temp_grants = temp,
		temp_avail = avail,
		will_revive = player.WillPlayerRevive and player:WillPlayerRevive() or nil,
	}
end

local function collect_held_paths(player)
	local paths = {}
	if not player or not player.GetHeldSprite then return paths, nil, nil end
	local ok, held = pcall(function() return player:GetHeldSprite() end)
	if not ok or not held then return paths, nil, nil end
	local anim = nil
	if held.GetAnimation then
		local ok_a, a = pcall(function() return held:GetAnimation() end)
		if ok_a then anim = a end
	end
	local filename = nil
	if held.GetFilename then
		local ok_f, f = pcall(function() return held:GetFilename() end)
		if ok_f then filename = f end
	end
	if held.GetAllLayers then
		local ok_l, layers = pcall(function() return held:GetAllLayers() end)
		if ok_l and type(layers) == "table" then
			for _, layer in pairs(layers) do
				if layer and layer.GetSpritesheetPath then
					local ok_p, p = pcall(function() return layer:GetSpritesheetPath() end)
					if ok_p and p and p ~= "" then
						paths[#paths + 1] = p
					end
				end
			end
		end
	end
	return paths, filename, anim
end

local function resolve_display_from_paths(paths)
	local cache = ensure_gfx_cache()
	for _, path in ipairs(paths or {}) do
		local bn = basename_of(path)
		if bn and bn ~= "" and not bn:find("collectibles%_005%.100") then
			local hits = cache[bn]
			if hits and #hits > 0 then
				return hits[1], bn, path
			end
		end
	end
	return nil, nil, nil
end

local function candidates_for_display(hit)
	if not hit then return {} end
	if hit.kind == "collectible" then
		local aliases = DISPLAY_ALIASES[hit.id]
		if aliases then return aliases end
		return {{kind = "collectible", id = hit.id}}
	end
	if hit.kind == "trinket" then
		local tid = hit.id
		if tid == (TrinketType.TRINKET_MISSING_POSTER or 23)
			or tid == (TrinketType.TRINKET_MYSTERIOUS_PAPER or 21) then
			return DISPLAY_ALIASES["missing_poster"]
		end
		if tid == (TrinketType.TRINKET_BROKEN_ANKH or 28) then
			return DISPLAY_ALIASES[CollectibleType.COLLECTIBLE_ANKH or 161]
		end
		return {{kind = "trinket", id = tid}}
	end
	return {}
end

local function pick_spend_candidate(pending, candidates)
	local snap = pending.death
	if not snap then return nil, "no_snapshot" end
	-- 真实道具已在 PRE_REVIVE 下降：不扣临时
	if pending.pre_revive_real then
		for _, c in ipairs(candidates) do
			if c.kind == "collectible" then
				local before = snap.real[c.id] or 0
				local after = pending.pre_revive_real[c.id] or 0
				if after < before then
					return nil, "real_collectible_consumed:" .. tostring(c.id)
				end
			end
		end
	end
	-- 按原版优先级，在「死亡时临时仍可用」的候选里唯一选择可扣账项
	local order = {}
	for _, c in ipairs(candidates) do
		order[c.kind .. ":" .. tostring(c.id)] = c
	end
	local matches = {}
	for _, step in ipairs(PRIORITY) do
		local key = step.kind .. ":" .. tostring(step.id)
		local c = order[key]
		if c then
			if c.kind == "collectible" then
				local cfg = CONSUMABLES[c.id]
				if cfg and (cfg.uses_per_grant or 0) > 0 then
					local avail = snap.temp_avail[c.id] or 0
					if avail > 0 then
						matches[#matches + 1] = c
					end
				elseif cfg and cfg.probabilistic then
					-- 概率项：成功时不扣；若它是唯一匹配则标记为障碍命中
					if (snap.temp_avail[c.id] or 0) > 0 or (snap.real[c.id] or 0) > 0 then
						return nil, "probabilistic_barrier:" .. tostring(c.id)
					end
				end
			elseif c.kind == "trinket" then
				if snap.trinkets and snap.trinkets[c.id] then
					return nil, "trinket_source:" .. tostring(c.id)
				end
			end
		end
	end
	if #matches == 1 then
		return matches[1], "unique"
	end
	if #matches == 0 then
		return nil, "no_temp_candidate"
	end
	return nil, "ambiguous:" .. tostring(#matches)
end

local function commit_spend(player, pending, candidate, reason)
	local idx = player_index(player)
	if not idx or not candidate or candidate.kind ~= "collectible" then return false end
	local id = candidate.id
	local cfg = CONSUMABLES[id]
	if not cfg or (cfg.uses_per_grant or 0) <= 0 then return false end
	add_spent(idx, M.PROVIDER_QING, id, 1)
	pending.resolved = true
	pending.result = {
		id = id,
		reason = reason,
		spent = get_spent(idx, M.PROVIDER_QING, id),
	}
	dbg(string.format("spend id=%s reason=%s spent=%s", tostring(id), tostring(reason), tostring(pending.result.spent)))
	local Imitate = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
	if Imitate and Imitate.Evaluate_Imitate_Items then
		Imitate.Evaluate_Imitate_Items(player)
	end
	return true
end

--- 复活生效前：能唯一判定时立刻扣临时额度并 sync 卸 innate。
--- 不要等 POST_PLAYER_REVIVE / Held Sprite——那是「死后又活了」才卸。
local function try_spend_before_revive(player, pending)
	if not pending or pending.resolved then return end
	local snap = pending.death
	if not snap then return end
	local pre_real = pending.pre_revive_real or real_collectible_counts(player)

	-- 真实道具数量已下降：原版吃掉了真货，绝不扣临时
	for id, cfg in pairs(CONSUMABLES) do
		if (cfg.uses_per_grant or 0) > 0 then
			local before = snap.real[id] or 0
			local after = pre_real[id] or 0
			if after < before then
				pending.resolved = true
				pending.result = {id = nil, reason = "pre_revive_real_consumed:" .. tostring(id)}
				dbg(pending.result.reason)
				return
			end
		end
	end

	-- 按原版优先级：更高档真实/概率/饰品挡路则留给 Held；否则扣当前档临时消耗项
	for _, step in ipairs(PRIORITY) do
		if step.kind == "collectible" then
			local id = step.id
			local cfg = CONSUMABLES[id]
			if cfg and cfg.probabilistic then
				if (snap.real[id] or 0) > 0 or (snap.temp_avail[id] or 0) > 0 then
					pending.early_blocked = "probabilistic:" .. tostring(id)
					dbg("pre_revive defer: " .. pending.early_blocked)
					return
				end
			elseif cfg and (cfg.uses_per_grant or 0) > 0 then
				local real_n = snap.real[id] or 0
				local temp_n = snap.temp_avail[id] or 0
				if real_n > 0 then
					pending.early_blocked = "has_real:" .. tostring(id)
					dbg("pre_revive defer: " .. pending.early_blocked)
					return
				end
				if temp_n > 0 then
					commit_spend(player, pending, {kind = "collectible", id = id}, "pre_revive_priority")
					return
				end
			end
		elseif step.kind == "trinket" then
			if snap.trinkets and snap.trinkets[step.id] then
				pending.early_blocked = "trinket:" .. tostring(step.id)
				dbg("pre_revive defer: " .. pending.early_blocked)
				return
			end
		end
	end
end

local function try_resolve_pending(player, pending)
	if not pending or pending.resolved then return end
	if not player:IsHoldingItem() then return end
	local paths, filename, anim = collect_held_paths(player)
	pending.last_held = {paths = paths, filename = filename, anim = anim}
	if M.debug_log then
		dbg("held anim=" .. tostring(anim) .. " file=" .. tostring(filename) .. " layers=" .. tostring(#paths))
		for i = 1, #paths do dbg("  layer[" .. i .. "]=" .. tostring(paths[i])) end
	end
	local hit, bn, path = resolve_display_from_paths(paths)
	if not hit then return end
	pending.displayed = {basename = bn, path = path, hit = hit}
	local candidates = candidates_for_display(hit)
	local pick, why = pick_spend_candidate(pending, candidates)
	if pick then
		commit_spend(player, pending, pick, "held:" .. tostring(why))
	else
		pending.ambiguous = why
		dbg("no spend: " .. tostring(why))
		-- 概率/饰品/真实来源：关闭窗口，避免误扣
		if why and (why:find("real_") or why:find("trinket_") or why:find("probabilistic_")) then
			pending.resolved = true
			pending.result = {id = nil, reason = why}
		end
	end
end

local function fallback_resolve(player, pending)
	if not pending or pending.resolved then return end
	local snap = pending.death
	if not snap then
		pending.resolved = true
		pending.result = {reason = "timeout_no_snapshot"}
		return
	end
	-- 仅当死亡时恰好一个临时确定性来源仍有额度，且真实数量未下降
	local only = nil
	for id, avail in pairs(snap.temp_avail or {}) do
		local cfg = CONSUMABLES[id]
		if cfg and (cfg.uses_per_grant or 0) > 0 and avail > 0 then
			local real_before = snap.real[id] or 0
			local real_now = player:GetCollectibleNum(id, true) or 0
			if real_now < real_before then
				pending.resolved = true
				pending.result = {reason = "fallback_real_consumed:" .. tostring(id)}
				return
			end
			if only then
				pending.resolved = true
				pending.result = {reason = "timeout_ambiguous"}
				pending.ambiguous = "fallback_multi"
				dbg("timeout ambiguous")
				return
			end
			only = id
		end
	end
	if only then
		commit_spend(player, pending, {kind = "collectible", id = only}, "fallback_unique")
	else
		pending.resolved = true
		pending.result = {reason = "timeout_none"}
		dbg("timeout none")
	end
end

-- ---------- public debug ----------

function M.get_debug_text()
	local lines = {}
	lines[#lines + 1] = "debug_log=" .. tostring(M.debug_log)
	local root = spent_root()
	for idx, providers in pairs(root) do
		for prov, bag in pairs(providers or {}) do
			for id, n in pairs(bag or {}) do
				if tonumber(id) and (tonumber(n) or 0) > 0 then
					local cfg = CONSUMABLES[tonumber(id)]
					lines[#lines + 1] = string.format(
						"spent p%s/%s/%s=%s",
						tostring(idx), tostring(prov),
						cfg and cfg.name or tostring(id), tostring(n)
					)
				end
			end
		end
	end
	for idx, providers in pairs(_grants) do
		for prov, bag in pairs(providers or {}) do
			for id, n in pairs(bag or {}) do
				if (tonumber(n) or 0) > 0 then
					local cfg = CONSUMABLES[id]
					lines[#lines + 1] = string.format(
						"grant p%s/%s/%s=%s",
						tostring(idx), tostring(prov),
						cfg and cfg.name or tostring(id), tostring(n)
					)
				end
			end
		end
	end
	for i = 1, #M.last_events do
		local e = M.last_events[i]
		lines[#lines + 1] = string.format("@%s %s", tostring(e.frame), e.text)
	end
	if #lines == 1 then lines[#lines + 1] = "(no spent / grants yet)" end
	return table.concat(lines, "\n")
end

function M.clear_spent_for_player(player)
	local idx = player_index(player)
	if not idx then return end
	local root = spent_root()
	root[idx] = {}
	dbg("cleared spent for " .. tostring(idx))
end

-- ---------- callbacks ----------

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_TRIGGER_PLAYER_DEATH,
	params = nil,
	Function = function(_, player)
		if not REPENTOGON or not player then return end
		local idx = player_index(player)
		if not idx then return end
		_pending[idx] = {
			death = snapshot_player(player),
			capture_until = nil,
			resolved = false,
		}
		dbg("death snapshot lives=" .. tostring(_pending[idx].death.extra_lives))
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PLAYER_REVIVE,
	params = nil,
	Function = function(_, player)
		if not REPENTOGON or not player then return end
		local idx = player_index(player)
		local pending = idx and _pending[idx]
		if not pending then return end
		pending.pre_revive_real = real_collectible_counts(player)
		pending.pre_revive_type = player:GetPlayerType()
		pending.pre_revive_lives = player.GetExtraLives and player:GetExtraLives() or 0
		-- 主路径：复活生效前扣账并卸临时 innate（与 RGON 示例「先 Remove 再复活」同序）
		try_spend_before_revive(player, pending)
		if pending.resolved then
			_pending[idx] = nil
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_REVIVE,
	params = nil,
	Function = function(_, player)
		if not REPENTOGON or not player then return end
		local idx = player_index(player)
		if not idx then return end
		local pending = _pending[idx]
		-- 已在 PRE_REVIVE 扣完则无需再开 Held 窗口
		if pending and pending.resolved then
			_pending[idx] = nil
			return
		end
		if not pending then
			pending = {death = snapshot_player(player), resolved = false}
			_pending[idx] = pending
		end
		-- 仅歧义（真货/项圈/饰品挡路）时，死后短窗口用 Held Sprite 补判
		pending.capture_until = Game():GetFrameCount() + M.CAPTURE_FRAMES
		pending.post_type = player:GetPlayerType()
		pending.post_lives = player.GetExtraLives and player:GetExtraLives() or 0
		dbg("post revive; deferred capture until " .. tostring(pending.capture_until)
			.. " blocked=" .. tostring(pending.early_blocked))
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		if not REPENTOGON or not player then return end
		local idx = player_index(player)
		local pending = idx and _pending[idx]
		if not pending or pending.resolved then return end
		if not pending.capture_until then return end
		try_resolve_pending(player, pending)
		if pending.resolved then
			_pending[idx] = nil
			return
		end
		if Game():GetFrameCount() >= pending.capture_until then
			fallback_resolve(player, pending)
			_pending[idx] = nil
		end
	end,
})

table.insert(M.myToCall, #M.myToCall + 1, {
	CallBack = require("Qing_Remaster_scripts.core.enums").Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		_pending = {}
		_grants = {}
		if not continue then
			save.elses[M.own_key .. "spent"] = {}
		else
			spent_root()
		end
		_gfx_basename_cache = nil
	end,
})

return M

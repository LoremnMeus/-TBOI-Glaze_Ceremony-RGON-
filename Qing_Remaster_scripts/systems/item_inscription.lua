-- 道具铭刻系统（前缀/后缀/名字/Desc 改写）
-- 自旧妖刀·逢魔拆离；当前无 collectible 绑定，供未来独立道具复用。

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Item_Inscription_",
	SAVE_KEY = "Item_Inscription_data",
	affix_registry = {},
	prefixes = {},
	suffixes = {},
	-- 旧妖刀 entity id；format_affixes 图标引用保留，未来可改宿主
	host_collectible = enums.Items.Spectralsword,
}

local stat_cache_flags = CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_RANGE |
	CacheFlag.CACHE_SPEED | CacheFlag.CACHE_LUCK | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG

local function lang_key()
	local language = Options and Options.Language or ""
	if language == "zh" or language == "zh_cn" or language == "zh_CN" then return "zh_cn" end
	return "en_us"
end

function item.get_save()
	local permanent = save.PermanentData or {}
	save.PermanentData = permanent
	permanent[item.SAVE_KEY] = permanent[item.SAVE_KEY] or {rewrites = {}, affixes = {}}
	permanent[item.SAVE_KEY].rewrites = permanent[item.SAVE_KEY].rewrites or {}
	permanent[item.SAVE_KEY].affixes = permanent[item.SAVE_KEY].affixes or {}
	for _, rewrite in pairs(permanent[item.SAVE_KEY].rewrites) do
		if type(rewrite) == "table" and rewrite.Desc == nil and rewrite.Description ~= nil then
			rewrite.Desc = rewrite.Description
			rewrite.Description = nil
		end
	end
	return permanent[item.SAVE_KEY]
end

function item.get_rewrite(id, create)
	local data = item.get_save()
	local key = tostring(id)
	if create then data.rewrites[key] = data.rewrites[key] or {} end
	return data.rewrites[key]
end

function item.register_affix(id, info)
	if id == nil or type(info) ~= "table" then return false end
	item.affix_registry[id] = info
	if info.slot == "prefix" then table.insert(item.prefixes, id)
	elseif info.slot == "suffix" then table.insert(item.suffixes, id) end
	return true
end

item.register_affix("keen", {
	slot = "prefix", name_zh = "锋利的", name_en = "Keen ", cache = CacheFlag.CACHE_DAMAGE,
	zh_cn = "锋利：每份该道具获得{{Damage}} +0.4伤害", en_us = "Keen: Each copy grants {{Damage}} +0.4 damage",
	apply = function(player, count) player.Damage = player.Damage + auxi.get_damage_multiplier(player) * 0.4 * count end,
})
item.register_affix("frenzied", {
	slot = "prefix", name_zh = "狂热的", name_en = "Frenzied ", cache = CacheFlag.CACHE_FIREDELAY,
	zh_cn = "狂热：每份该道具获得{{Tears}} +0.5射速", en_us = "Frenzied: Each copy grants {{Tears}} +0.5 tears",
	apply = function(player, count) player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay, auxi.get_mxdelay_multiplier(player) * 0.5 * count) end,
})
item.register_affix("farseeing", {
	slot = "prefix", name_zh = "远视的", name_en = "Farseeing ", cache = CacheFlag.CACHE_RANGE,
	zh_cn = "远视：每份该道具获得{{Range}} +1.5射程", en_us = "Farseeing: Each copy grants {{Range}} +1.5 range",
	apply = function(player, count) player.TearRange = player.TearRange + 60 * count end,
})
item.register_affix("ethereal", {
	slot = "prefix", name_zh = "灵质的", name_en = "Ethereal ", cache = CacheFlag.CACHE_TEARFLAG,
	zh_cn = "灵质：泪弹获得穿透障碍物效果", en_us = "Ethereal: Tears pass through obstacles",
	apply = function(player) player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL end,
})
item.register_affix("haste", {
	slot = "suffix", name_zh = "·疾行", name_en = " of Haste", cache = CacheFlag.CACHE_SPEED,
	zh_cn = "疾行：每份该道具获得{{Speed}} +0.15移速", en_us = "of Haste: Each copy grants {{Speed}} +0.15 speed",
	apply = function(player, count) player.MoveSpeed = player.MoveSpeed + 0.15 * count end,
})
item.register_affix("fortune", {
	slot = "suffix", name_zh = "·鸿运", name_en = " of Fortune", cache = CacheFlag.CACHE_LUCK,
	zh_cn = "鸿运：每份该道具获得{{Luck}} +1幸运", en_us = "of Fortune: Each copy grants {{Luck}} +1 luck",
	apply = function(player, count) player.Luck = player.Luck + count end,
})
item.register_affix("force", {
	slot = "suffix", name_zh = "·强袭", name_en = " of Force", cache = CacheFlag.CACHE_SHOTSPEED,
	zh_cn = "强袭：每份该道具获得{{ShotSpeed}} +0.2弹速", en_us = "of Force: Each copy grants {{ShotSpeed}} +0.2 shot speed",
	apply = function(player, count) player.ShotSpeed = player.ShotSpeed + 0.2 * count end,
})
item.register_affix("guidance", {
	slot = "suffix", name_zh = "·导引", name_en = " of Guidance", cache = CacheFlag.CACHE_TEARFLAG,
	zh_cn = "导引：泪弹获得追踪效果", en_us = "of Guidance: Tears gain homing",
	apply = function(player) player.TearFlags = player.TearFlags | TearFlags.TEAR_HOMING end,
})

function item.get_affix_list(collectible_id, create)
	local data = item.get_save()
	local key = tostring(collectible_id)
	if create then data.affixes[key] = data.affixes[key] or {} end
	return data.affixes[key] or {}
end

function item.format_affix(affix_id, language)
	local info = item.affix_registry[affix_id]
	if info == nil then return nil end
	local text = info[language] or info.en_us or info.zh_cn
	if type(text) == "function" then text = text(info, language) end
	return text
end

function item.format_affixes(collectible_id, language)
	local list = item.get_affix_list(collectible_id)
	local ret = ""
	local icon_id = item.host_collectible
	for _, affix_id in ipairs(list) do
		local text = item.format_affix(affix_id, language)
		if text and text ~= "" then
			ret = ret .. "#{{Collectible" .. tostring(icon_id) .. "}} " .. text
		end
	end
	return ret
end

function item.format_affix_name(collectible_id, name, language)
	local prefix, suffix = "", ""
	for _, affix_id in ipairs(item.get_affix_list(collectible_id)) do
		local info = item.affix_registry[affix_id]
		if info then
			local value = language == "zh_cn" and info.name_zh or info.name_en
			if info.slot == "prefix" then prefix = value or ""
			elseif info.slot == "suffix" then suffix = value or "" end
		end
	end
	return prefix .. (name or "") .. suffix
end

local function roll_other(rng, pool, old_id)
	if #pool == 0 then return nil end
	local id = pool[rng:RandomInt(#pool) + 1]
	if #pool > 1 and id == old_id then
		for _, candidate in ipairs(pool) do
			if candidate ~= old_id then id = candidate break end
		end
	end
	return id
end

--- 供未来道具调用：随机重铸前缀+后缀
function item.try_reforge(player, collectible_id, opts)
	opts = opts or {}
	if player == nil or collectible_id == nil then return false end
	local cost = opts.cost or 1
	if player:GetNumCoins() < cost or next(item.affix_registry) == nil then return false end
	player:AddCoins(-cost)
	local list = item.get_affix_list(collectible_id, true)
	local rng = opts.rng or player:GetCollectibleRNG(opts.rng_item or item.host_collectible)
	list[1] = roll_other(rng, item.prefixes, list[1])
	list[2] = roll_other(rng, item.suffixes, list[2])
	for i = 0, Game():GetNumPlayers() - 1 do
		local target_player = Game():GetPlayer(i)
		if target_player:GetCollectibleNum(collectible_id, true) > 0 then
			target_player:AddCacheFlags(stat_cache_flags)
			target_player:EvaluateItems()
		end
	end
	return true
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if continue ~= true and save.elses then
		save.elses[item.SAVE_KEY] = nil
	end
	item.get_save()
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = "Item",
Function = function(_, player, tp, id, value)
	local rewrite = item.get_rewrite(id, false)
	if rewrite then
		value.Name = rewrite.Name or value.Name
		value.Description = rewrite.Desc or value.Description
	end
	value.Name = item.format_affix_name(id, value.Name, lang_key())
	local info = item.format_affixes(id, lang_key())
	if info ~= "" then value.Description = (value.Description or "") .. info end
	return value
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	for collectible_id, list in pairs(item.get_save().affixes) do
		local id = tonumber(collectible_id)
		local count = id and player:GetCollectibleNum(id, true) or 0
		if count > 0 then
			for _, affix_id in ipairs(list) do
				local info = item.affix_registry[affix_id]
				if info and info.cache == cacheFlag and info.apply then info.apply(player, count) end
			end
		end
	end
end,
})

if EID then
	EID:addDescriptionModifier("qing_item_inscription_rewrite_decorator", function(desc)
		return desc.ObjType == 5 and desc.ObjVariant == 100 and desc.ObjSubType
			and (item.get_rewrite(desc.ObjSubType, false) ~= nil or item.format_affixes(desc.ObjSubType, lang_key()) ~= "")
	end, function(desc)
		local rewrite = item.get_rewrite(desc.ObjSubType, false)
		if rewrite then
			desc.Name = rewrite.Name or desc.Name
		end
		desc.Name = item.format_affix_name(desc.ObjSubType, desc.Name, lang_key())
		EID:appendToDescription(desc, item.format_affixes(desc.ObjSubType, lang_key()))
		return desc
	end)
end

item.stat_cache_flags = stat_cache_flags
item.lang_key = lang_key

return item

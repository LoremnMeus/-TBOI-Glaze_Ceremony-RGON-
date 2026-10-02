-- Special Destination registry: shared destinations for Wizard portals / Emperor doors.
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Special_Destination_",
	_destinations = {},
	_by_room_index = {},
	_by_portal_type = {},
	_fool_portal_spawner = nil,
	_mega_rewarded = false,
}

local function block_ascent(ctx)
	return not (ctx.is_ascent or ctx.is_home)
end

local function block_ascent_and_hush(ctx)
	return block_ascent(ctx) and not ctx.is_hush
end

local function register(def)
	item._destinations[def.key] = def
	if def.room_index ~= nil then
		item._by_room_index[def.room_index] = def
	end
	if def.portal_type ~= nil and type(def.portal_type) ~= "function" then
		item._by_portal_type[def.portal_type] = def
	end
end

register({
	key = "devil_angel",
	room_index = -1,
	portal_type = function()
		local desc = Game():GetLevel():GetRoomByIdx(-1)
		return desc and desc.Data and desc.Data.Type or RoomType.ROOM_DEVIL
	end,
	door_type = function()
		local desc = Game():GetLevel():GetRoomByIdx(-1)
		return desc and desc.Data and desc.Data.Type or RoomType.ROOM_DEVIL
	end,
	category = "utility",
	door_footprint = "normal",
	wizard_pool = true,
	emperor_other = true,
	prepare = function()
		local desc = Game():GetLevel():GetRoomByIdx(-1)
		if desc and desc.Data == nil then
			Game():GetLevel():InitializeDevilAngelRoom(false, false)
		end
	end,
	wiki = {
		visible = false,
		zh = {name = "恶魔房 / 天使房", description = "进入本层恶魔房或天使房。"},
		en = {name = "Devil / Angel Room", description = "Enters this floor's Devil or Angel Room."},
	},
	eid = {
		zh_cn = {Name = "恶魔/天使传送旋涡", Description = "#{{DevilRoom}}{{AngelRoom}} 将你传送到恶魔房或天使房"},
		en_us = {Name = "Devil/Angel portal", Description = "#{{DevilRoom}}{{AngelRoom}} Teleport you to the devil or angel room"},
	},
})

register({
	key = "error_room",
	room_index = -2,
	portal_type = 3,
	door_type = 3,
	category = "rare",
	weight = 40,
	door_footprint = "normal",
	wizard_pool = true,
	wiki = {
		visible = true,
		zh = {name = "错误房", description = "进入错误房。"},
		en = {name = "Error Room", description = "Enters an Error Room."},
	},
	eid = {
		zh_cn = {Name = "错误传送旋涡", Description = "#{{ErrorRoom}} 将你传送到错误房"},
		en_us = {Name = "Error portal", Description = "#{{ErrorRoom}} Teleport you to the error room"},
	},
})

register({
	key = "dungeon",
	room_index = -4,
	portal_type = 16,
	door_type = 16,
	category = "utility",
	door_footprint = "normal",
	wizard_pool = true,
	emperor_other = true,
	wiki = {
		visible = false,
		zh = {name = "地下室", description = "进入地下室。"},
		en = {name = "Dungeon", description = "Enters the dungeon."},
	},
	eid = {
		zh_cn = {Name = "大地传送旋涡", Description = "#{{LadderRoom}} 将你传送到地下室"},
		en_us = {Name = "Ground portal", Description = "#{{LadderRoom}} Teleport you to the dungeon"},
	},
})

register({
	key = "boss_rush",
	room_index = -5,
	portal_type = 17,
	door_type = 17,
	category = "rare",
	weight = 25,
	door_footprint = "wide",
	wizard_pool = true,
	availability = block_ascent_and_hush,
	wiki = {
		visible = true,
		zh = {name = "Boss Rush", description = "进入 Boss Rush。"},
		en = {name = "Boss Rush", description = "Enters Boss Rush."},
	},
	eid = {
		zh_cn = {Name = "究极挑战传送旋涡", Description = "#{{BossRushRoom}} 将你传送到BossRush房"},
		en_us = {Name = "Ultra Challenge portal", Description = "#{{BossRushRoom}} Teleport you to the Boss Rush room"},
	},
})

register({
	key = "black_market",
	room_index = -6,
	portal_type = 22,
	door_type = 22,
	category = "rare",
	weight = 20,
	door_footprint = "normal",
	wizard_pool = true,
	return_policy = "fool_portal",
	wiki = {
		visible = true,
		zh = {name = "黑市", description = "进入后会提供返回通道。"},
		en = {name = "Black Market", description = "Provides a return route after entering."},
	},
	eid = {
		zh_cn = {Name = "黑市传送旋涡", Description = "#将你传送到黑市"},
		en_us = {Name = "Market portal", Description = "#Teleport you to the black market"},
	},
})

register({
	key = "mega_satan",
	room_index = -7,
	portal_type = 114,
	door_type = 105,
	replace_tp = 30,
	category = "rare",
	weight = 5,
	door_footprint = "wide",
	wizard_pool = true,
	availability = block_ascent,
	return_policy = "fool_portal",
	wiki = {
		visible = true,
		specialReward = true,
		zh = {
			name = "超级撒旦",
			description = "击败后生成返回通道，并生成 1 件恶魔房道具和 1 件天使房道具。",
		},
		en = {
			name = "Mega Satan",
			description = "After victory, opens a return route and spawns 1 Devil Room item and 1 Angel Room item.",
		},
	},
	eid = {
		zh_cn = {
			Name = "五芒星传送旋涡",
			Description = "#将你传送到超级撒旦"..
			"#胜利后生成1件恶魔房道具和1件天使房道具，并开启返回通道",
		},
		en_us = {
			Name = "Pentacle Portal",
			Description = "#Teleports you to Mega Satan"..
			"#After victory, spawns 1 Devil Room item and 1 Angel Room item and opens a return route",
		},
	},
})

register({
	key = "underground_shop",
	room_index = -13,
	portal_type = 116,
	door_type = 16,
	replace_tp = 31,
	category = "utility",
	door_footprint = "normal",
	wizard_pool = true,
	emperor_other = true,
	wiki = {
		visible = false,
		zh = {name = "地下商店", description = "进入地下商店。"},
		en = {name = "Secret Shop", description = "Enters the secret shop."},
	},
	eid = {
		zh_cn = {Name = "地下商店传送旋涡", Description = "#将你传送到地下商店"},
		en_us = {Name = "Secret shop portal", Description = "#Teleport you to the secret shop"},
	},
})

register({
	key = "angel_shop",
	room_index = -18,
	portal_type = 115,
	door_type = 15,
	replace_tp = 32,
	category = "utility",
	door_footprint = "normal",
	wizard_pool = true,
	emperor_other = true,
	wiki = {
		visible = false,
		zh = {name = "天使商店", description = "进入天使商店。"},
		en = {name = "Angel Shop", description = "Enters the angel shop."},
	},
	eid = {
		zh_cn = {Name = "天使商店传送旋涡", Description = "#{{AngelRoom}} 将你传送到天使商店"},
		en_us = {Name = "Angel shop portal", Description = "#{{AngelRoom}} Teleport you to the angel shop"},
	},
})

function item.build_context()
	local level = Game():GetLevel()
	local door_info = auxi.get_level_door_info()
	return {
		level = level,
		stage = level:GetStage(),
		stage_type = level:GetStageType(),
		dimension = auxi.GetDimension(),
		door_info = door_info,
		is_ascent = level:IsAscent() == true,
		is_home = door_info == 9,
		is_hush = door_info == 5,
	}
end

function item.get(key)
	return item._destinations[key]
end

function item.get_by_room_index(room_index)
	return item._by_room_index[room_index]
end

function item.is_available(key_or_def, ctx)
	local def = type(key_or_def) == "string" and item._destinations[key_or_def] or key_or_def
	if not def then
		return false
	end
	ctx = ctx or item.build_context()
	if def.availability then
		return def.availability(ctx) == true
	end
	return true
end

function item.get_available(category_or_filter, ctx)
	ctx = ctx or item.build_context()
	local filter = category_or_filter
	if type(filter) == "string" then
		filter = {category = filter}
	end
	filter = filter or {}
	local out = {}
	for _, def in pairs(item._destinations) do
		local ok = true
		if filter.category and def.category ~= filter.category then
			ok = false
		end
		if filter.wizard_pool and not def.wizard_pool then
			ok = false
		end
		if filter.emperor_other and not def.emperor_other then
			ok = false
		end
		if filter.door_footprint and (def.door_footprint or "normal") ~= filter.door_footprint then
			ok = false
		end
		if ok and item.is_available(def, ctx) then
			out[#out + 1] = def
		end
	end
	table.sort(out, function(a, b)
		return tostring(a.key) < tostring(b.key)
	end)
	return out
end

local function pick_weighted_from_list(list, rng)
	local total = 0
	for i = 1, #list do
		total = total + (list[i].weight or 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:RandomInt(total)
	local acc = 0
	for i = 1, #list do
		acc = acc + (list[i].weight or 0)
		if roll < acc then
			return list[i], i
		end
	end
	return list[#list], #list
end

--- filter may be category string ("rare") or table ({category="rare", wizard_pool=true}).
function item.pick_weighted(filter, rng, ctx)
	ctx = ctx or item.build_context()
	rng = auxi.rng_for_sake(rng)
	local list = item.get_available(filter, ctx)
	local picked = pick_weighted_from_list(list, rng)
	return picked
end

--- Without-replacement weighted picks. Returns array of defs (may be shorter than count).
function item.pick_weighted_unique(filter, count, rng, ctx)
	ctx = ctx or item.build_context()
	rng = auxi.rng_for_sake(rng)
	count = count or 1
	local list = item.get_available(filter, ctx)
	local out = {}
	for _ = 1, count do
		local picked, idx = pick_weighted_from_list(list, rng)
		if not picked then
			break
		end
		out[#out + 1] = picked
		table.remove(list, idx)
	end
	return out
end

function item.pick_any(filter, rng, ctx)
	ctx = ctx or item.build_context()
	rng = auxi.rng_for_sake(rng)
	local list = item.get_available(filter, ctx)
	if #list <= 0 then
		return nil
	end
	return auxi.random_in_table(list, rng)
end

local function resolve_type(value)
	return auxi.check_if_any(value, nil)
end

function item.prepare(def)
	if def and def.prepare then
		def.prepare()
	end
end

function item.to_portal_info(def)
	if not def then
		return nil
	end
	item.prepare(def)
	return {
		id = -1,
		tp = resolve_type(def.portal_type),
		gidx = def.room_index,
		replace_tp = def.replace_tp,
	}
end

function item.to_door_info(def)
	if not def then
		return nil
	end
	item.prepare(def)
	return {
		id = def.room_index,
		tp = resolve_type(def.door_type or def.portal_type),
		gidx = def.room_index,
	}
end

function item.list_portal_infos(filter, ctx)
	local list = item.get_available(filter, ctx)
	local out = {}
	for i = 1, #list do
		out[#out + 1] = item.to_portal_info(list[i])
	end
	return out
end

function item.get_public_info(key, lang)
	local def = item.get(key)
	if not def or not def.wiki then
		return nil
	end
	if lang == "en" or lang == "en_us" then
		return def.wiki.en
	end
	return def.wiki.zh
end

function item.get_portal_eid(portal_type, lang)
	local def = item._by_portal_type[portal_type]
	if not def or not def.eid then
		return nil
	end
	lang = lang or "zh_cn"
	return def.eid[lang] or def.eid.zh_cn
end

function item.bind_fool_portal_spawner(fn)
	item._fool_portal_spawner = fn
end

function item.spawn_return_portal(pos)
	if item._fool_portal_spawner then
		return item._fool_portal_spawner(pos)
	end
end

function item.setup_return_for_room_index(room_index)
	local def = item.get_by_room_index(room_index)
	if not def or def.return_policy ~= "fool_portal" then
		return
	end
	if room_index == -6 then
		delay_buffer.addeffe(function()
			item.spawn_return_portal(Vector(320, 280))
		end, {}, 1)
	elseif room_index == -7 then
		delay_buffer.addeffe(function()
			local room = Game():GetRoom()
			if room:IsClear() then
				item.spawn_return_portal(room:GetCenterPos())
			end
		end, {}, 1)
	end
end

function item.export_public_metadata()
	local out = {}
	for _, def in pairs(item._destinations) do
		if def.wiki and def.wiki.visible then
			out[#out + 1] = {
				key = def.key,
				category = def.category,
				weight = def.weight,
				zhName = def.wiki.zh and def.wiki.zh.name,
				enName = def.wiki.en and def.wiki.en.name,
				zhDescription = def.wiki.zh and def.wiki.zh.description,
				enDescription = def.wiki.en and def.wiki.en.description,
				returnRoute = def.return_policy == "fool_portal",
				specialReward = def.wiki.specialReward == true,
			}
		end
	end
	table.sort(out, function(a, b)
		return (a.weight or 0) > (b.weight or 0)
	end)
	return out
end

function item.get_debug_text()
	local ctx = item.build_context()
	local lines = {
		string.format(
			"stage=%s door_info=%s ascent=%s hush=%s home=%s",
			tostring(ctx.stage),
			tostring(ctx.door_info),
			tostring(ctx.is_ascent),
			tostring(ctx.is_hush),
			tostring(ctx.is_home)
		),
	}
	local keys = {}
	for k in pairs(item._destinations) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for i = 1, #keys do
		local def = item._destinations[keys[i]]
		lines[#lines + 1] = string.format(
			"%s | %s | w=%s | fp=%s | avail=%s | idx=%s | portal=%s",
			def.key,
			tostring(def.category),
			tostring(def.weight or "-"),
			tostring(def.door_footprint or "normal"),
			tostring(item.is_available(def, ctx)),
			tostring(def.room_index),
			tostring(type(def.portal_type) == "function" and "fn" or def.portal_type)
		)
	end
	return table.concat(lines, "\n")
end

function item.debug_force_portal(key, pos)
	local def = item.get(key)
	if not def then
		return nil
	end
	local info = item.to_portal_info(def)
	pos = pos or Game():GetRoom():GetCenterPos()
	local wizard = require("Qing_Remaster_scripts.cards.Card_01_Wizard")
	return wizard.spawn_a_fool_port(pos, {info = info})
end

function item.debug_test_rare_roll(n, seed)
	n = n or 1000
	local rng = RNG()
	rng:SetSeed(seed or 1, 35)
	local counts = {}
	local ctx = item.build_context()
	for _ = 1, n do
		local picked = item.pick_weighted("rare", rng, ctx)
		if picked then
			counts[picked.key] = (counts[picked.key] or 0) + 1
		else
			counts["(none)"] = (counts["(none)"] or 0) + 1
		end
	end
	return counts
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	Function = function(_, continue)
		if not continue then
			item._mega_rewarded = false
			save.elses[item.own_key.."mega_rewarded"] = nil
		else
			item._mega_rewarded = save.elses[item.own_key.."mega_rewarded"] == true
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	Function = function()
		item._mega_rewarded = false
		save.elses[item.own_key.."mega_rewarded"] = nil
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD,
	Function = function(_, rng, pos)
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		if not desc or desc.SafeGridIndex ~= -7 then
			return
		end
		if Game():GetLevel():GetStage() == LevelStage.STAGE6 then
			return
		end
		if item._mega_rewarded or save.elses[item.own_key.."mega_rewarded"] then
			return
		end
		item._mega_rewarded = true
		save.elses[item.own_key.."mega_rewarded"] = true

		item.spawn_return_portal(Game():GetRoom():GetCenterPos())
		local room = Game():GetRoom()
		local itempool = Game():GetItemPool()
		local seed = rng:GetSeed()
		local colid = itempool:GetCollectible(3, true, seed)
		rng:Next()
		if colid and colid ~= 0 then
			local q = Isaac.Spawn(5, 100, colid, room:FindFreePickupSpawnPosition(pos + Vector(-40, 0), 10, true), Vector(0, 0), nil):ToPickup()
			q:Morph(5, 100, colid, true, true, true)
		end
		seed = rng:GetSeed()
		colid = itempool:GetCollectible(4, true, seed)
		rng:Next()
		if colid and colid ~= 0 then
			local q = Isaac.Spawn(5, 100, colid, room:FindFreePickupSpawnPosition(pos + Vector(40, 0), 10, true), Vector(0, 0), nil):ToPickup()
			q:Morph(5, 100, colid, true, true, true)
		end
	end,
})

return item

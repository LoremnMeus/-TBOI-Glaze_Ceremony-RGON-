local json = require("json")
local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local unlock_board = require("Qing_Remaster_scripts.data.unlock_board")
local unlock_codec = require("Qing_Remaster_scripts.core.unlock_codec")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	pre_myToCall = {},
	myToCall = {},
	post_myToCall = {},
	own_key = "SaveData_",
	target_id = 508,
	over_unlock_info = {
		["wq"] = "UnlocksTemplate",
		["Spwq"] = "UnlocksTemplate",
		["Tecro"] = "UnlocksTemplate",
		["Tecrorun"] = "UnlocksTemplate",
		["Anna"] = "UnlocksTemplate",
		["annA"] = "UnlocksTemplate",
		["Zeis"] = "UnlocksTemplate",
		["Zeiz"] = "UnlocksTemplate",
		["Glaze"] = "boss_players",
		["BossZeis"] = "boss_players",
		["Others"] = "others_achievements",
	},
	Unlock_info = {
		UnlocksTemplate = {
			MomsHeart = {Unlock = false, Hard = false},
			Isaac = {Unlock = false, Hard = false},
			Satan = {Unlock = false, Hard = false},
			BlueBaby = {Unlock = false, Hard = false},
			Lamb = {Unlock = false, Hard = false},
			BossRush = {Unlock = false, Hard = false},
			Hush = {Unlock = false, Hard = false},
			MegaSatan = {Unlock = false, Hard = false},
			Delirium = {Unlock = false, Hard = false},
			Mother = {Unlock = false, Hard = false},
			Beast = {Unlock = false, Hard = false},
			GreedMode = {Unlock = false, Hard = false},
			FullCompletion = {Unlock = false, Hard = false},
		},
		boss_players = {
			Isaac = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Maggy = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Cain = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Judas = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			BlueBaby = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Eve = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Samson = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Azazel = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Lazarus = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Eden = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Lost = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			--Lazarus2 = {Unlock = false, Tainted = false},	
			--BlackJudas = {Unlock = false, Tainted = false},
			Lilith = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Keeper = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Apollyon = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Forgotten = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Bethany = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Jacob_and_Esau = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			wq = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Tecro = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Anna = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
			Zeis = {Unlock = false, Hard = false, Tainted = false, TaintedHard = false},
		},
		others_achievements = {
			Ending1 = {Unlock = false},
			Ending2 = {Unlock = false},
			Ending3 = {Unlock = false},
			Crown_of_the_Glaze = {Unlock = false},
			Crushed = {Unlock = false},		--被车撞到！
			Coin = {Unlock = false},
		},
	},
	Forgot = {
		[PlayerType.PLAYER_THEFORGOTTEN] = true,
		[PlayerType.PLAYER_THESOUL] = true,
	},
	Lazarus = {
		[PlayerType.PLAYER_LAZARUS_B] = 29,
		[PlayerType.PLAYER_LAZARUS2_B] = 38,
	},
}

item.dynamic_boss_categories = {}
for _,column in ipairs(unlock_board.boss_columns or {}) do
	local key = tostring(column.key or "")
	if key ~= "" and string.sub(key,1,5) ~= "Glaze" and string.sub(key,1,4) ~= "Zeis" then
		local category = "BossBoard_"..key
		local template = category.."_template"
		item.over_unlock_info[category] = template
		item.Unlock_info[template] = {}
		for _,row in ipairs(unlock_board.boss_rows or {}) do
			if row.code and row.code ~= "" then item.Unlock_info[template][row.code] = {Unlock = false} end
		end
		table.insert(item.dynamic_boss_categories,{category = category,key = key,label = column.label or key})
	end
end

local modReference
local Continue = false
local SAVE_STATE = {}
-- SAVE_VER 2：PROFILE（成就位图/配置/永久）与 RUN（本局）拆分；仍单次 SaveData 勤落盘
local SAVE_FORMAT = 2
item.RuntimeLoaded = false
-- 玩家看到的三个存档文件对应 API 槽 1/2/3。第一个存档是 1，不是 0。
-- RGON rawslot==0 只表示「尚未点选」，此时 LoadData 读的就是第一档。
item.FIRST_SAVE_SLOT = 1
item.LoadedSaveslot = nil
item.DefaultSlotPreload = false
item.PERSISTENT_PLAYER_DATA = {}
item.elses = {}
item.UnlockData = {}
-- Forward decl: identity callbacks registered above the helper body close over this upvalue.
local identity_probe_notify
-- PermanentData：档案级永久数据（含「下局生效」）。ConsistData 已并入，仅作别名兼容。
item.PermanentData = {}
item.ConsistData = item.PermanentData
-- 独立紧凑区：模组道具颜色标签缓存（不进 ELSES，避免被 run 态 deepCopy 放大）
item.ItemColorCache = nil

local unlock_schema = unlock_codec.build_schema(item.over_unlock_info, item.Unlock_info)
unlock_codec.bind_schema(unlock_schema)

local function sanitize_persistent_players_for_save(players)
	local out = {}
	for i,pData in ipairs(players or {}) do
		local meta = pData.__META or {}
		out[i] = {
			__INDEX = pData.__INDEX,
			__META = {
				Index = meta.Index,
				Seed = meta.Seed,
				PlayerType = meta.PlayerType,
				shared = meta.shared,
				Seeded = meta.Seeded,
				Once_type = meta.Once_type,
				Frame = meta.Frame,
				CIndex = meta.CIndex,
				-- Found Soul sequence: interchangeable souls share a reusable slot list.
				FoundSoul = meta.FoundSoul == true or nil,
				FoundSoulSeq = meta.FoundSoulSeq,
				-- 故意不写入 meta.player（Entity 引用），避免脏 userdata / 无意义体积
			},
		}
	end
	return out
end

local REGENESIS_STATE_KEY = "Item_Regenesis_state"

local function regenesis_module()
	return package.loaded["Qing_Remaster_scripts.items.Item_Regenesis"]
end

local function pack_elses_for_save(elses)
	local tmp = {}
	for k,v in pairs(elses or {}) do
		if k == "collectible_counter" then
			tmp[k] = auxi.pack_collectible_counter(v)
		elseif k == "trinket_counter" then
			tmp[k] = auxi.pack_trinket_counter(v)
		elseif k == REGENESIS_STATE_KEY then
			local regenesis = regenesis_module()
			if regenesis and regenesis.pack_for_save then
				tmp[k] = regenesis.pack_for_save(v)
			else
				tmp[k] = v
			end
		else
			tmp[k] = v
		end
	end
	return auxi.pack_for_save(tmp)
end

function item.get_achievement_init(name,init)
	local ret = {}
	for i, v in pairs(item.Unlock_info[name]) do ret[i] = {} for uu,vv in pairs(v) do ret[i][uu] = init end end
	return ret
end

function item.make_all_data(init)
	local ret = {}
	for u,v in pairs(item.over_unlock_info) do ret[u] = item.get_achievement_init(v,init) end
	return ret
end

function item.LockAll()
	for u,v in pairs(item.over_unlock_info) do item.UnlockData[u] = item.get_achievement_init(v,false) end
	local marks = package.loaded["Qing_Remaster_scripts.core.completion_marks_manager"]
	if marks and marks.lock_all then marks.lock_all() end
	Achievement_Display_holder.PlayAchievement("gfx/ui/Some achievements/achievement_All_Locked.png")
end

function item.UnLockAll()
	for u,v in pairs(item.over_unlock_info) do item.UnlockData[u] = item.get_achievement_init(v,true) end
	local marks = package.loaded["Qing_Remaster_scripts.core.completion_marks_manager"]
	if marks and marks.unlock_all then marks.unlock_all() end
	Achievement_Display_holder.PlayAchievement("gfx/ui/Some achievements/achievement_All_Unlocked.png")
end

function item.ensure_board_special_records()
	item.UnlockData.Others = item.UnlockData.Others or {}
	local function add(key)
		if type(key) ~= "string" or key == "" then return end
		local rec = item.UnlockData.Others[key]
		if rec == true then
			item.UnlockData.Others[key] = {Unlock = true}
		elseif type(rec) ~= "table" then
			item.UnlockData.Others[key] = {Unlock = false}
		elseif rec.Unlock == nil then
			rec.Unlock = false
		end
	end
	for _,event in ipairs(unlock_board.special_events or {}) do
		add(event.key)
	end
	for mark,_ in pairs((unlock_board.special_unlocks or {}).Others or {}) do
		add(mark)
	end
end

function item.CheckAchievementAll()
	local tmp = item.make_all_data(false)
	for u,v in pairs(tmp) do 
		for uu,vv in pairs(v) do
			item.UnlockData[u][uu] = item.UnlockData[u][uu] or auxi.deepCopy(tmp[u][uu])
			for field,default in pairs(vv) do
				if item.UnlockData[u][uu][field] == nil then
					item.UnlockData[u][uu][field] = default
				end
			end
		end
	end
end

function item.SaveModData(reason)
	-- POST_MODS_LOADED 等早期回调可能先于完整 Load；此时绝不能拿空内存覆盖现有存档。
	if item.RuntimeLoaded ~= true then
		return false
	end
	-- Canonical layout only: PROFILE + RUN. Top-level category / ELSES mirrors are not written.
	SAVE_STATE = {
		SAVE_VER = SAVE_FORMAT,
		PROFILE = {
			UNLOCKS = unlock_codec.pack(item.UnlockData, unlock_schema),
			MODCONFIG = item.ModConfigSettings,
			PERMANENT_DATA = auxi.pack_for_save(item.PermanentData),
			ITEM_COLOR_CACHE = item.ItemColorCache,
		},
		RUN = {
			ELSES = pack_elses_for_save(item.elses),
			PERSISTENT_PLAYER_DATA = sanitize_persistent_players_for_save(item.PERSISTENT_PLAYER_DATA),
		},
	}
	local payload = json.encode(SAVE_STATE)
	modReference:SaveData(payload)
	return true
end

-- 供颜色扫描在 POST_MODS_LOADED 时读取（早于 PRE_GAME_STARTED 的完整 LoadModData）
function item.PeekItemColorCache()
	if type(item.ItemColorCache) == "table" and item.ItemColorCache.v then
		return item.ItemColorCache
	end
	if not modReference or not Isaac.HasModData(modReference) then return nil end
	local dec = modReference:LoadData()
	local decoded
	local succ = pcall(function() decoded = json.decode(dec) end)
	if not succ or type(decoded) ~= "table" then return nil end
	local blob = type(decoded.PROFILE) == "table" and decoded.PROFILE.ITEM_COLOR_CACHE or nil
	if type(blob) == "table" then
		item.ItemColorCache = blob
		return item.ItemColorCache
	end
	return nil
end

function item.SaveItemColorCache(blob)
	item.ItemColorCache = blob
	-- 合并写入：先 peek 当前存档其余字段，避免仅写颜色时冲掉未 Load 的内存态
	if not modReference then return end
	if Isaac.HasModData(modReference) then
		local dec = modReference:LoadData()
		local decoded
		local succ = pcall(function() decoded = json.decode(dec) end)
		if succ and type(decoded) == "table" then
			SAVE_STATE = decoded
		end
	end
	SAVE_STATE = SAVE_STATE or {}
	SAVE_STATE.PROFILE = SAVE_STATE.PROFILE or {}
	SAVE_STATE.PROFILE.ITEM_COLOR_CACHE = blob
	-- 若完整运行态已就绪，走常规 Save；否则只更新颜色缓存并写回
	if item.RuntimeLoaded == true then
		item.SaveModData()
	else
		modReference:SaveData(json.encode(SAVE_STATE))
	end
end

local function initialize_current_save()
	SAVE_STATE = {
		SAVE_VER = SAVE_FORMAT,
		PROFILE = {},
		RUN = {},
	}
end

--- Pre-release: only PROFILE+RUN with current SAVE_VER are accepted. Older layouts reset.
local function is_canonical_save(state)
	return type(state) == "table"
		and type(state.PROFILE) == "table"
		and type(state.RUN) == "table"
		and state.SAVE_VER == SAVE_FORMAT
end

function item.LoadModData(continue)
	item.RuntimeLoaded = false
	if Isaac.HasModData(modReference) then
		local dec = modReference:LoadData()
		local succ = pcall(function() SAVE_STATE = json.decode(dec) end)
		if not succ or type(SAVE_STATE) ~= "table" then
			print("QING:: Error: Failed to load Mod data. They will be re-initialized again.")
			initialize_current_save()
		end
	else
		initialize_current_save()
	end

	if not is_canonical_save(SAVE_STATE) then
		print("QING:: Save layout outdated or incomplete; re-initializing canonical PROFILE/RUN.")
		initialize_current_save()
	end

	local profile = SAVE_STATE.PROFILE
	local run = SAVE_STATE.RUN
	local unlock_packed = profile.UNLOCKS
	item.ModConfigSettings = profile.MODCONFIG
	item.ItemColorCache = profile.ITEM_COLOR_CACHE
	local elses = auxi.unpack_from_save(run.ELSES) or {}
	local regenesis = regenesis_module()
	if regenesis and regenesis.unpack_from_save and type(elses[REGENESIS_STATE_KEY]) == "table" then
		elses[REGENESIS_STATE_KEY] = regenesis.unpack_from_save(elses[REGENESIS_STATE_KEY])
	end
	local permanent = auxi.unpack_from_save(profile.PERMANENT_DATA) or {}
	item.PERSISTENT_PLAYER_DATA = run.PERSISTENT_PLAYER_DATA or {}

	if continue ~= true then
		local tbl = {}
		callback_manager.work("POST_INHERIT_SAVE",function(funct,params) funct(nil,elses,tbl) end)
		elses = tbl
		item.PERSISTENT_PLAYER_DATA = {}
	end

	if type(unlock_packed) == "table" and type(unlock_packed.b) == "table" then
		item.UnlockData = unlock_codec.unpack(unlock_packed, unlock_schema)
	else
		item.UnlockData = item.make_all_data(false)
	end
	for cat,_ in pairs(item.over_unlock_info) do
		item.UnlockData[cat] = item.UnlockData[cat] or {}
	end

	item.elses = elses
	item.PermanentData = permanent
	-- Runtime API alias only (not a save field). Callers may still use save.ConsistData.
	item.ConsistData = item.PermanentData
	item.CompletionMarksV2 = item.PermanentData.CompletionMarksV2
	item.CheckAchievementAll()
	item.ensure_board_special_records()
	for _,record in pairs(item.UnlockData.Others or {}) do
		if type(record) == "table" then
			record.Tainted = nil
		end
	end
	item.RuntimeLoaded = true
end

local function load_profile_for_slot(saveslot, is_default_preload)
	item.LoadModData(true)
	item.LoadedSaveslot = saveslot
	item.DefaultSlotPreload = is_default_preload == true
end

-- 进游戏/模组加载后立刻预加载第一档，方便主菜单 ImGui；用户改选 2/3 再切换。
-- 已选定真实槽之后，忽略后续 rawslot==0 的刷回调，避免把第二/三档冲回第一档。
local function preload_first_saveslot()
	if item.LoadedSaveslot ~= nil then return end
	load_profile_for_slot(item.FIRST_SAVE_SLOT, true)
end

if REPENTOGON and ModCallbacks.MC_POST_MODS_LOADED then
	table.insert(item.ToCall,#item.ToCall + 1,{
		CallBack = ModCallbacks.MC_POST_MODS_LOADED,
		priority = -10000000,
		Function = function()
			preload_first_saveslot()
		end,
	})
end

-- 新开局仍由 PRE_PRE_GAME_STARTED 以 continue=false 清 RUN。
if REPENTOGON and ModCallbacks.MC_POST_SAVESLOT_LOAD then
	table.insert(item.ToCall,#item.ToCall + 1,{
		CallBack = ModCallbacks.MC_POST_SAVESLOT_LOAD,
		priority = -10000000,
		Function = function(_,saveslot,isslotselected,rawslot)
			saveslot = tonumber(saveslot)
			if rawslot == 0 then
				preload_first_saveslot()
				return
			end
			if not saveslot or saveslot < 1 then return end
			if item.LoadedSaveslot == saveslot and item.RuntimeLoaded == true and item.DefaultSlotPreload ~= true then
				return
			end
			load_profile_for_slot(saveslot, false)
		end,
	})
end

table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.LoadModData(continue)
end,
})

table.insert(item.post_myToCall,#item.post_myToCall + 1,{CallBack = enums.Callbacks.POST_PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue ~= true then item.SaveModData("post_pre_game_started_new_run") end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue ~= true then item.SaveModData("post_game_started_new_run") end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function()		--新下层
	item.SaveModData("post_new_level")
end,
})

-- Boundary markers for player_identity_probe (registered after notify helper exists).
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil, priority = 100000,
Function = function()
	identity_probe_notify("BOUNDARY_NEW_LEVEL", nil, {match_method = "post_new_level"})
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldSave)		--离开游戏
	identity_probe_notify("BOUNDARY_PRE_GAME_EXIT", nil, {
		match_method = "pre_game_exit",
		should_save = shouldSave == true,
		record_count = #item.PERSISTENT_PLAYER_DATA,
	})
	if shouldSave == false then 
		local tbl = {}
		callback_manager.work("POST_CLEAR_SAVE",function(funct,params) funct(nil,item.elses,tbl) end)
		item.elses = tbl
	else
		--for i, plyr in ipairs(item.PERSISTENT_PLAYER_DATA) do if auxi.check_all_exists(plyr.__META.player) then plyr.__META.CIndex = plyr.__META.player:GetCollectibleRNG(item.target_id):GetSeed() end	end
	end
	item.SaveModData("pre_game_exit:"..tostring(shouldSave))
end,
})

function item.get_sub_idx(player)
	local idx = player:GetData().__Index
	if idx and item.PERSISTENT_PLAYER_DATA[idx] and item.PERSISTENT_PLAYER_DATA[idx].__META.shared then return item.PERSISTENT_PLAYER_DATA[idx].__META.shared end
	return idx
end

-- Read-only player-identity probe hooks. No match-rule changes; no-op when probe off.
local IDENTITY_PROBE_PATH = "Qing_Remaster_scripts.debug.player_identity_probe"

local function identity_probe_snapshot(player, extra)
	local row = type(extra) == "table" and extra or {}
	if player then
		pcall(function()
			row.ptr_hash = GetPtrHash(player)
			row.init_seed = player.InitSeed
			row.controller_index = player.ControllerIndex
			row.player_type = player:GetPlayerType()
			row.variant = player.Variant
			row.persistent_index = player:GetData().__Index
			row.shared_index = item.get_sub_idx(player)
		end)
	end
	pcall(function()
		row.frame = Isaac.GetFrameCount()
	end)
	pcall(function()
		row.record_count = #item.PERSISTENT_PLAYER_DATA
	end)
	return row
end

identity_probe_notify = function(event, player, extra)
	local probe = package.loaded[IDENTITY_PROBE_PATH]
	if type(probe) ~= "table" or type(probe.record_owner_event) ~= "function" then
		return
	end
	if probe.is_enabled and probe.is_enabled() ~= true then
		return
	end
	local row = identity_probe_snapshot(player, extra)
	row.event = tostring(event or "?")
	row.source = "savedata"
	pcall(probe.record_owner_event, row)
end

-- Found Soul (小罗): Variant=FOUND_SOUL(1) + BabySkin=BABY_FOUND_SOUL(59).
-- Interchangeable across respawns; reuse free sequence slots instead of endless add_player.
local FOUND_SOUL_VARIANT = (PlayerVariant and PlayerVariant.FOUND_SOUL) or 1
local FOUND_SOUL_BABY = (BabySubType and BabySubType.BABY_FOUND_SOUL) or 59

function item.is_found_soul_player(player)
	if not player then
		return false
	end
	if player.Variant ~= FOUND_SOUL_VARIANT then
		return false
	end
	if not player.GetBabySkin then
		return false
	end
	local ok, skin = pcall(function()
		return player:GetBabySkin()
	end)
	return ok and skin == FOUND_SOUL_BABY
end

local function list_found_soul_slots()
	local slots = {}
	for i, pData in ipairs(item.PERSISTENT_PLAYER_DATA) do
		local meta = pData and pData.__META
		if meta and meta.FoundSoul then
			slots[#slots + 1] = {
				index = i,
				seq = tonumber(meta.FoundSoulSeq) or i,
			}
		end
	end
	table.sort(slots, function(a, b)
		if a.seq == b.seq then
			return a.index < b.index
		end
		return a.seq < b.seq
	end)
	return slots
end

local function next_found_soul_seq()
	local max_seq = 0
	for _, slot in ipairs(list_found_soul_slots()) do
		if slot.seq > max_seq then
			max_seq = slot.seq
		end
	end
	return max_seq + 1
end

local function is_persistent_index_on_field(idx, except_player)
	if not idx then
		return false
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() then
			local same = except_player and auxi.check_for_the_same(p, except_player)
			if not same then
				local pidx = p:GetData().__Index
				if pidx == idx then
					return true
				end
			end
		end
	end
	return false
end

local function bind_player_to_persistent_index(player, idx, match_method, reason)
	local pData = item.PERSISTENT_PLAYER_DATA[idx]
	if not pData or not pData.__META then
		return false
	end
	local old_idx = player:GetData().__Index
	local meta = pData.__META
	player:GetData().__Index = idx
	meta.player = player
	meta.Seed = player.InitSeed
	meta.Index = player.ControllerIndex
	meta.CIndex = nil
	meta.PlayerType = player:GetPlayerType()
	meta.Frame = Isaac.GetFrameCount()
	meta.NowFrame = Isaac.GetFrameCount()
	identity_probe_notify("PLAYER_ID_REUSED", player, {
		match_method = match_method,
		reason = reason,
		old_index = old_idx,
		new_index = idx,
		found_soul_seq = meta.FoundSoulSeq,
	})
	return true
end

function item.try_reclaim_found_soul(player, reason)
	if not item.is_found_soul_player(player) then
		return false
	end
	if player:GetData().__Index ~= nil then
		return false
	end
	for _, slot in ipairs(list_found_soul_slots()) do
		if not is_persistent_index_on_field(slot.index, player) then
			local ok = bind_player_to_persistent_index(
				player,
				slot.index,
				"found_soul_sequence_reclaim",
				reason
			)
			if ok then
				identity_probe_notify("RECONCILIATION", player, {
					match_method = "found_soul_sequence_reclaim",
					reason = reason,
					decision = "reclaim_free_slot",
					new_index = slot.index,
					found_soul_seq = slot.seq,
					check_p_data_result = false,
				})
				return true
			end
		end
	end
	return false
end

local function sync_found_soul_meta(player, idx)
	local pData = item.PERSISTENT_PLAYER_DATA[idx]
	if not pData or not pData.__META or not pData.__META.FoundSoul then
		return false
	end
	if not item.is_found_soul_player(player) then
		return false
	end
	local meta = pData.__META
	meta.player = player
	meta.Seed = player.InitSeed
	meta.Index = player.ControllerIndex
	meta.CIndex = nil
	meta.PlayerType = player:GetPlayerType()
	meta.NowFrame = Isaac.GetFrameCount()
	return true
end

function item.add_player(player,tp,opts)
	opts = opts or {}
	local before_idx = player and player:GetData() and player:GetData().__Index or nil
	local mark_found_soul = opts.found_soul == true or item.is_found_soul_player(player)
	local pData = {
		__INDEX = #item.PERSISTENT_PLAYER_DATA + 1,
		__META = {
			Index = player.ControllerIndex,
			Seed = player.InitSeed,
			Frame = Isaac.GetFrameCount(),
			PlayerType = player:GetPlayerType(),
			player = player,		--有点危险
		}
	}
	if mark_found_soul then
		pData.__META.FoundSoul = true
		pData.__META.FoundSoulSeq = next_found_soul_seq()
	end
	if item.Lazarus_player then 
		if item.PERSISTENT_PLAYER_DATA[item.Lazarus_player].__META.Frame == Isaac.GetFrameCount() and item.Lazarus[player:GetPlayerType()] then 
			item.PERSISTENT_PLAYER_DATA[item.Lazarus_player].__META.shared = #item.PERSISTENT_PLAYER_DATA + 1
			pData.__META.shared = item.Lazarus_player
		end 
		item.Lazarus_player = nil 
	elseif item.Lazarus[player:GetPlayerType()] then item.Lazarus_player = #item.PERSISTENT_PLAYER_DATA + 1 end
	table.insert(item.PERSISTENT_PLAYER_DATA, pData)
	player:GetData().__Index = #item.PERSISTENT_PLAYER_DATA
	identity_probe_notify("PLAYER_ID_ALLOCATED", player, {
		match_method = mark_found_soul and "add_player_found_soul" or "add_player",
		reason = tp,
		old_index = before_idx,
		new_index = player:GetData().__Index,
		found_soul_seq = pData.__META.FoundSoulSeq,
	})
	callback_manager.work("POST_PLAYER_INIT_OVER",function(funct,params) funct(nil,player) end)		--这个函数
	--delay_buffer.addeffe(function() print("Add player "..player.InitSeed.." "..player:GetPlayerType().." "..player.ControllerIndex.." "..player:GetData().__Index.." "..(tp or "")) end,{},1)
end
--l Game():GetPlayer(1):TakeDamage(0,0,EntityRef(Game():GetPlayer(1)),121)
table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,priority = -200,
Function = function(_,player)
	-- Observe only: tg_player is never assigned in-repo; `tp` is unbound in this scope.
	local same_tg = auxi.check_for_the_same(player, item.tg_player)
	if same_tg then
		local tp_global = rawget(_G, "tp")
		identity_probe_notify("CINDEX_RECOVERY_ENTERED", player, {
			match_method = "cindex_priority_-200",
			tg_player_set = item.tg_player ~= nil,
			tp_global = tp_global,
			tp_unbound = tp_global == nil,
		})
	end
	if same_tg then
		for i, plyr in ipairs(item.PERSISTENT_PLAYER_DATA) do
			if auxi.check_all_exists(plyr.__META.player) ~= true and player.ControllerIndex == plyr.__META.Index and (plyr.__META.CIndex and plyr.__META.CIndex == player:GetCollectibleRNG(item.target_id):GetSeed()) and tp == plyr.__META.PlayerType then
				local old_idx = player:GetData().__Index
				player:GetData().__Index = i
				plyr.__META.player = player
				plyr.__META.Seed = player.InitSeed
				plyr.__META.CIndex = nil
				plyr.__META.Frame = Isaac.GetFrameCount()
				identity_probe_notify("PLAYER_ID_REUSED", player, {
					match_method = "cindex_priority_-200",
					old_index = old_idx,
					new_index = i,
				})
				break
			end
		end
	end
end,
})

function item.check_p_data(player)
	local tp = player:GetPlayerType()
	for i, plyr in ipairs(item.PERSISTENT_PLAYER_DATA) do
		if player.ControllerIndex == plyr.__META.Index and ((player.InitSeed == plyr.__META.Seed and tp == plyr.__META.PlayerType) or (item.Forgot[tp] and item.Forgot[plyr.__META.PlayerType] and plyr.__META.Frame == Isaac.GetFrameCount())) then		--(auxi.check_all_exists(plyr.__META.player) ~= true and 		--似乎rewind会出问题
			local old_idx = player:GetData().__Index
			local forgot_path = not (player.InitSeed == plyr.__META.Seed and tp == plyr.__META.PlayerType)
			player:GetData().__Index = i
			plyr.__META.player = player
			plyr.__META.Seed = player.InitSeed
			plyr.__META.CIndex = nil
			plyr.__META.PlayerType = tp
			plyr.__META.Frame = Isaac.GetFrameCount()
			identity_probe_notify("PLAYER_ID_REUSED", player, {
				match_method = forgot_path and "check_p_data_forgot" or "check_p_data",
				old_index = old_idx,
				new_index = i,
			})
			--delay_buffer.addeffe(function() print("Init Player m1 "..player.InitSeed.." "..player:GetPlayerType().." "..player.ControllerIndex.." "..player:GetData().__Index) end,{},1)
			return true
		end
	end
end

function item.check_vague_data(player)
	local tp = player:GetPlayerType()
	local best_fit = nil local best_i = nil
	for i, plyr in ipairs(item.PERSISTENT_PLAYER_DATA) do
		if player.ControllerIndex == plyr.__META.Index and ((tp == plyr.__META.PlayerType) or (item.Forgot[tp] and item.Forgot[plyr.__META.PlayerType]) or (tp == 0 and plyr.__META.Once_type == 0)) and auxi.check_all_exists(plyr.__META.player) ~= true then
			if best_fit == nil or ((best_fit.NowFrame or 0) > (plyr.__META.NowFrame or 0)) then
				best_fit = plyr.__META best_i = i
			end
		end
	end
	if best_fit then
		local old_idx = player:GetData().__Index
		local old_seed = best_fit.Seed
		player:GetData().__Index = best_i
		best_fit.Seeded = best_fit.Seed
		best_fit.Seed = player.InitSeed
		best_fit.player = player
		best_fit.PlayerType = tp
		best_fit.Frame = Isaac.GetFrameCount()
		player:GetData()[item.own_key.."check"] = true
		identity_probe_notify("PLAYER_ID_REUSED", player, {
			match_method = "check_vague_data",
			old_index = old_idx,
			new_index = best_i,
			old_seed = old_seed,
		})
		--delay_buffer.addeffe(function() print("Init Player m2 "..player.InitSeed.." "..player:GetPlayerType().." "..player.ControllerIndex.." "..player:GetData().__Index) end,{},1)
		return true
	end
end

function item.try_find_idx(player,tp)
	local before_idx = player:GetData().__Index
	local succ = item.check_p_data(player) if succ then return end
	local vague_eligible = Game():GetFrameCount() ~= 0 and not g.is_gameplay_world_active()
	if vague_eligible then local succ = item.check_vague_data(player) if succ then return end end

	-- Found Soul already bound to a sequence slot: refresh engine fields, do not allocate.
	if before_idx
		and item.PERSISTENT_PLAYER_DATA[before_idx]
		and item.PERSISTENT_PLAYER_DATA[before_idx].__META
		and item.PERSISTENT_PLAYER_DATA[before_idx].__META.FoundSoul
		and item.is_found_soul_player(player)
	then
		sync_found_soul_meta(player, before_idx)
		return
	end

	if player:GetData().__Index == nil then
		if item.try_reclaim_found_soul(player, tp) then
			return
		end
		local mark_fs = item.is_found_soul_player(player)
		identity_probe_notify("RECONCILIATION", player, {
			match_method = "try_find_idx",
			reason = tp,
			decision = mark_fs and "add_player_found_soul" or "add_player",
			old_index = before_idx,
			vague_eligible = vague_eligible,
			check_p_data_result = false,
			check_vague_result = vague_eligible and false or "skipped",
		})
		item.add_player(player, tp, {found_soul = mark_fs})
	else
		identity_probe_notify("RECONCILIATION", player, {
			match_method = "try_find_idx",
			reason = tp,
			decision = "keep_existing_index",
			old_index = before_idx,
			new_index = player:GetData().__Index,
			vague_eligible = vague_eligible,
			check_p_data_result = false,
			check_vague_result = vague_eligible and false or "skipped",
		})
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,		--小红罐、里拉萨路会让角色的种子反复变化，这点异常诡异。所以需要使用额外的策略来保证其正确。 此外，小红罐还会导致角色生成时类型变为0。
Function = function(_,player)
	item.try_find_idx(player,"Init")
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local idx = player:GetData().__Index
	-- Late adopt: BabySkin may become readable after Init; fold this index into FS sequence.
	if item.is_found_soul_player(player)
		and idx
		and item.PERSISTENT_PLAYER_DATA[idx]
		and item.PERSISTENT_PLAYER_DATA[idx].__META
		and not item.PERSISTENT_PLAYER_DATA[idx].__META.FoundSoul
	then
		local meta = item.PERSISTENT_PLAYER_DATA[idx].__META
		meta.FoundSoul = true
		meta.FoundSoulSeq = meta.FoundSoulSeq or next_found_soul_seq()
		sync_found_soul_meta(player, idx)
		identity_probe_notify("RECONCILIATION", player, {
			match_method = "found_soul_sequence_adopt",
			decision = "adopt_existing_index",
			new_index = idx,
			found_soul_seq = meta.FoundSoulSeq,
		})
	end
	if idx and item.PERSISTENT_PLAYER_DATA[idx] and item.PERSISTENT_PLAYER_DATA[idx].__INDEX == idx then
		local meta = item.PERSISTENT_PLAYER_DATA[idx].__META
		if meta.Index == player.ControllerIndex and player.InitSeed == meta.Seed then
			local pt = player:GetPlayerType()
			if meta.PlayerType ~= pt then 
				local old_type = meta.PlayerType
				if old_type == 0 then meta.Once_type = 0 end
				callback_manager.work("POST_PLAYER_SHIFT",function(funct,params) funct(nil,player,meta.PlayerType) end)
				meta.PlayerType = pt
				identity_probe_notify("PLAYER_TYPE_SHIFT", player, {
					match_method = "post_player_update",
					old_player_type = old_type,
					new_player_type = pt,
					persistent_index = idx,
				})
			end
			meta.NowFrame = Isaac.GetFrameCount()
			return
		end
		-- Found Soul: InitSeed/ControllerIndex often change across respawn or Init→Update.
		-- Keep the sequence slot and refresh binding fields instead of allocating.
		if meta.FoundSoul and item.is_found_soul_player(player) then
			sync_found_soul_meta(player, idx)
			return
		end
	end
	item.try_find_idx(player,"Update")
end,
})

local function note_rewind_portal(event, extra)
	local probe = package.loaded["Qing_Remaster_scripts.debug.portal_restore_rewind_probe"]
	if type(probe) ~= "table" or type(probe.record_external) ~= "function" then
		return
	end
	local row = {
		source = "savedata",
		event = tostring(event or "?"),
		should_load = item.should_load == true,
		should_load2 = item.should_load2 == true,
	}
	if type(probe.snapshot_rewind_state) == "function" then
		if event == "REWIND_SOURCE" and extra and extra.source_store then
			row.state = probe.snapshot_rewind_state(extra.source_store)
		elseif event == "REWIND_AFTER_RESTORE" then
			row.current_state = probe.snapshot_rewind_state(item.elses)
		else
			row.current_state = probe.snapshot_rewind_state(item.elses)
			row.lst_state = probe.snapshot_rewind_state(item.lst)
			row.lst2_state = probe.snapshot_rewind_state(item.lst2)
		end
	end
	pcall(function()
		row.frame = Isaac.GetFrameCount()
	end)
	pcall(function()
		row.room = Game():GetLevel():GetCurrentRoomIndex()
	end)
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			if k ~= "source_store" then
				row[k] = v
			end
		end
	end
	pcall(probe.record_external, row)
end

local function player_bind_index(player)
	local idx
	pcall(function()
		idx = player:GetData().__Index
	end)
	return idx
end

-- Wholesale restore must rebind EntityPlayer to PERSISTENT_PLAYER_DATA before
-- POST_REWIND / POST_NEW_ROOM consumers look up player:GetData().__Index.
local function rebind_players_for_restore(tp)
	identity_probe_notify("BOUNDARY_REWIND_REBIND", nil, {
		match_method = "rebind_players_for_restore",
		rewind_type = tp,
	})
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local before_idx = player_bind_index(player)
		local p_ok = item.check_p_data(player) == true
		local v_ok = false
		if not p_ok then
			v_ok = item.check_vague_data(player) == true
		end
		identity_probe_notify("RECONCILIATION", player, {
			match_method = "rebind_players_for_restore",
			rewind_type = tp,
			player_slot = playerNum - 1,
			old_index = before_idx,
			new_index = player_bind_index(player),
			check_p_data_result = p_ok,
			check_vague_result = v_ok,
			decision = p_ok and "check_p_data" or (v_ok and "check_vague_data" or "unbound"),
		})
		local probe = package.loaded["Qing_Remaster_scripts.debug.portal_restore_rewind_probe"]
		if type(probe) == "table" and type(probe.record_external) == "function" then
			pcall(probe.record_external, {
				source = "savedata",
				event = "RESTORE_PLAYER_BINDING",
				rewind_type = tp,
				player = playerNum - 1,
				before_idx = tostring(before_idx),
				check_p_data_result = p_ok,
				check_vague_result = v_ok,
				after_idx = tostring(player_bind_index(player)),
			})
		end
	end
end

-- Run-state timeline snapshots.
-- save.elses is the authoritative rewindable run-state store:
--   * lst  = previous room snapshot used by Glowing Hour Glass / RGON rewind
--   * lst2 = fallback older snapshot where applicable
-- Restoring a snapshot replaces item.elses wholesale, then POST_REWIND is fired
-- so runtime/derived caches can rebuild themselves.
-- Consumers MUST NOT manually restore business state already stored in save.elses.
function item.collect_data()
	--Isaac.DebugString("Data Collected")
	local rewind_pending = item.should_load2 == true
	local glass_pending = item.should_load == true
	if item.should_load then
		item.should_load = nil
		rebind_players_for_restore("Glass")
		if item.lst then
			local data = auxi.deepCopy(item.lst)
			local desc = item.elses
			item.elses = data
			callback_manager.work("POST_REWIND",function(funct,params) funct(nil,"Glass",desc) end)
		end
	end
	if item.should_load2 then
		--Isaac.DebugString("Accept Reload")
		note_rewind_portal("REWIND_BEFORE_RESTORE")
		item.should_load2 = nil
		rebind_players_for_restore("Rewind")
		local tg
		local snapshot_src
		if REPENTOGON then
			tg = item.lst
			snapshot_src = "lst"
		else
			tg = item.lst2
			snapshot_src = "lst2"
		end
		if tg then
			note_rewind_portal("REWIND_SOURCE", {
				snapshot_src = snapshot_src,
				source_store = tg,
			})
			local data = auxi.deepCopy(tg)
			local desc = item.elses
			item.elses = data
			note_rewind_portal("REWIND_AFTER_RESTORE")
			callback_manager.work("POST_REWIND",function(funct,params) funct(nil,"Rewind",desc) end)
		end
	end
	local should_save = true
	local level = Game():GetLevel()
	if level:GetStage() == LevelStage.STAGE1_2 and (level:GetStageType() == StageType.STAGETYPE_REPENTANCE or level:GetStageType() == StageType.STAGETYPE_REPENTANCE_B) then
		local desc = level:GetCurrentRoomDesc()
		if desc.Data.Type == RoomType.ROOM_DEFAULT and desc.Data.Variant >= 10000 and desc.Data.Variant <= 10500 then		--镜子房间，不进行存储。
			should_save = false
		end
	end
	if should_save then
		if not rewind_pending and not glass_pending then
			note_rewind_portal("SAVE_BEFORE_ROOM_SNAPSHOT")
		end
		item.lst2 = auxi.deepCopy(item.lst) or auxi.deepCopy(item.elses)
		item.lst = auxi.deepCopy(item.elses)
		if not rewind_pending and not glass_pending then
			note_rewind_portal("SAVE_AFTER_ROOM_SNAPSHOT")
		end
	end
end

table.insert(item.post_myToCall,#item.post_myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = item.collect_data,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS,
Function = function(_, colid, rng, player, flags, slot, data)
	item.should_load = true
end,
})

function item.Init(mod)
	modReference = mod
	if REPENTOGON then
		preload_first_saveslot()
	end
end

return item

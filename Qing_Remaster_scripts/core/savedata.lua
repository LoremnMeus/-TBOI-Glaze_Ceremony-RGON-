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
				-- 故意不写入 meta.player（Entity 引用），避免脏 userdata / 无意义体积
			},
		}
	end
	return out
end

local function pack_elses_for_save(elses)
	local tmp = {}
	for k,v in pairs(elses or {}) do
		if k == "collectible_counter" then
			tmp[k] = auxi.pack_collectible_counter(v)
		elseif k == "trinket_counter" then
			tmp[k] = auxi.pack_trinket_counter(v)
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

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldSave)		--离开游戏
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

function item.add_player(player,tp)
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
	if item.Lazarus_player then 
		if item.PERSISTENT_PLAYER_DATA[item.Lazarus_player].__META.Frame == Isaac.GetFrameCount() and item.Lazarus[player:GetPlayerType()] then 
			item.PERSISTENT_PLAYER_DATA[item.Lazarus_player].__META.shared = #item.PERSISTENT_PLAYER_DATA + 1
			pData.__META.shared = item.Lazarus_player
		end 
		item.Lazarus_player = nil 
	elseif item.Lazarus[player:GetPlayerType()] then item.Lazarus_player = #item.PERSISTENT_PLAYER_DATA + 1 end
	table.insert(item.PERSISTENT_PLAYER_DATA, pData)
	player:GetData().__Index = #item.PERSISTENT_PLAYER_DATA
	callback_manager.work("POST_PLAYER_INIT_OVER",function(funct,params) funct(nil,player) end)		--这个函数
	--delay_buffer.addeffe(function() print("Add player "..player.InitSeed.." "..player:GetPlayerType().." "..player.ControllerIndex.." "..player:GetData().__Index.." "..(tp or "")) end,{},1)
end
--l Game():GetPlayer(1):TakeDamage(0,0,EntityRef(Game():GetPlayer(1)),121)
table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,priority = -200,
Function = function(_,player)
	if auxi.check_for_the_same(player,item.tg_player) then
		for i, plyr in ipairs(item.PERSISTENT_PLAYER_DATA) do
			if auxi.check_all_exists(plyr.__META.player) ~= true and player.ControllerIndex == plyr.__META.Index and (plyr.__META.CIndex and plyr.__META.CIndex == player:GetCollectibleRNG(item.target_id):GetSeed()) and tp == plyr.__META.PlayerType then
				player:GetData().__Index = i
				plyr.__META.player = player
				plyr.__META.Seed = player.InitSeed
				plyr.__META.CIndex = nil
				plyr.__META.Frame = Isaac.GetFrameCount()
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
			player:GetData().__Index = i
			plyr.__META.player = player
			plyr.__META.Seed = player.InitSeed
			plyr.__META.CIndex = nil
			plyr.__META.PlayerType = tp
			plyr.__META.Frame = Isaac.GetFrameCount()
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
		player:GetData().__Index = best_i
		best_fit.Seeded = best_fit.Seed
		best_fit.Seed = player.InitSeed
		best_fit.player = player
		best_fit.PlayerType = tp
		best_fit.Frame = Isaac.GetFrameCount()
		player:GetData()[item.own_key.."check"] = true
		--delay_buffer.addeffe(function() print("Init Player m2 "..player.InitSeed.." "..player:GetPlayerType().." "..player.ControllerIndex.." "..player:GetData().__Index) end,{},1)
		return true
	end
end

function item.try_find_idx(player,tp)
	local succ = item.check_p_data(player) if succ then return end
	if Game():GetFrameCount() ~= 0 and g.Started ~= true then local succ = item.check_vague_data(player) if succ then return end end
	if player:GetData().__Index == nil then item.add_player(player,tp) end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,		--小红罐、里拉萨路会让角色的种子反复变化，这点异常诡异。所以需要使用额外的策略来保证其正确。 此外，小红罐还会导致角色生成时类型变为0。
Function = function(_,player)
	item.try_find_idx(player,"Init")
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local idx = player:GetData().__Index
	if idx and item.PERSISTENT_PLAYER_DATA[idx] and item.PERSISTENT_PLAYER_DATA[idx].__INDEX == idx then
		if item.PERSISTENT_PLAYER_DATA[idx].__META.Index == player.ControllerIndex and player.InitSeed == item.PERSISTENT_PLAYER_DATA[idx].__META.Seed then
			local pt = player:GetPlayerType()
			if item.PERSISTENT_PLAYER_DATA[idx].__META.PlayerType ~= pt then 
				if item.PERSISTENT_PLAYER_DATA[idx].__META.PlayerType == 0 then item.PERSISTENT_PLAYER_DATA[idx].__META.Once_type = 0 end
				callback_manager.work("POST_PLAYER_SHIFT",function(funct,params) funct(nil,player,item.PERSISTENT_PLAYER_DATA[idx].__META.PlayerType) end)
				item.PERSISTENT_PLAYER_DATA[idx].__META.PlayerType = pt 
			end
			item.PERSISTENT_PLAYER_DATA[idx].__META.NowFrame = Isaac.GetFrameCount()
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
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local before_idx = player_bind_index(player)
		local p_ok = item.check_p_data(player) == true
		local v_ok = false
		if not p_ok then
			v_ok = item.check_vague_data(player) == true
		end
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

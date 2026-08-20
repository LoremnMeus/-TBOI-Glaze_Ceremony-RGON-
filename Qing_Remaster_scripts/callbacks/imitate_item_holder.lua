local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local Assemble_holder = require("Qing_Remaster_scripts.others.Assemble_holder")

local item = {
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	position = Vector(2000,2000),
	own_key = "Imi_item_",
	rgon_group_key = "Qing_Remaster_Imitate_Item",
	rgon_applied = {},
	reuser = {
		[CollectibleType.COLLECTIBLE_SACRIFICIAL_ALTAR] = {should_re_evaluate = true,},
		--[CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS] = {},
	},
	re_evaluater = {
		[CollectibleType.COLLECTIBLE_FLIP] = {},
	},
}
Assemble_holder.register_on(item.own_key,item,{force = true,})
--这个委托器提供假道具的赋予与删除功能。
--后悔药复原的实体具有一致的生成数，可以正常控制
--rewind指令似乎已修复。
--煲仔饭在使用前移除所有魂火，使用后再生成即可
--创世纪？
--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 3 and v.Variant == 237 then print(v.InitSeed) end end
function item.rgon_backend_enabled()
	local cfg = save.ModConfigSettings
	if type(cfg) == "table" and type(cfg.QingRemasterOptions) == "table" and type(cfg.QingRemasterOptions.Compatibility) == "table" then
		if cfg.QingRemasterOptions.Compatibility.UseRgonImitateItems == false then return false end
	end
	return true
end

function item.can_use_rgon_backend(player)
	return item.rgon_backend_enabled() and REPENTOGON and player and player.AddInnateCollectible ~= nil and player.RemoveInnateCollectible ~= nil
end

function item.get_player_index(player)
	if player and player:GetData() then return player:GetData().__Index end
	return nil
end

function item.ensure_rgon_record(idx)
	item.rgon_applied[idx] = item.rgon_applied[idx] or {}
	return item.rgon_applied[idx]
end

function item.recorder_key()
	return item.own_key.."r_recorder"
end

function item.meta_key()
	return item.own_key.."r_meta"
end

function item.ensure_meta_bag(idx)
	save.elses[item.meta_key()] = save.elses[item.meta_key()] or {}
	save.elses[item.meta_key()][idx] = save.elses[item.meta_key()][idx] or {}
	return save.elses[item.meta_key()][idx]
end

function item.get_meta_entry(idx,collid)
	local bag = save.elses[item.meta_key()]
	if not bag or not idx then return nil end
	local player_meta = bag[idx]
	if not player_meta then return nil end
	return player_meta[collid] or player_meta[tostring(collid)]
end

-- 解析 evaluate / add 条目：number 或 {count, display?, costume?}
function item.parse_entry(raw)
	if type(raw) == "number" then
		return tonumber(raw) or 0,nil,nil
	end
	if type(raw) == "table" then
		local count = tonumber(raw.count)
		if count == nil and tonumber(raw[1]) then count = tonumber(raw[1]) end
		return count or 0,raw.display,raw.costume
	end
	return 0,nil,nil
end

local function or_bool(a,b)
	if a == nil then return b end
	if b == nil then return a end
	return a or b
end

-- MC_EVALUATE_IMITATE_ITEM 用：累加份数，并可附带 display/costume
function item.add(value,id,amount,opts)
	if not value or id == nil then return value end
	amount = amount or 1
	opts = opts or {}
	local key = tonumber(id) or id
	local count,display,costume = item.parse_entry(value[key])
	if value[key] == nil and value[tostring(key)] ~= nil then
		count,display,costume = item.parse_entry(value[tostring(key)])
	end
	count = count + amount
	if opts.display ~= nil then display = or_bool(display,opts.display) end
	if opts.costume ~= nil then costume = or_bool(costume,opts.costume) end
	if display ~= nil or costume ~= nil then
		value[key] = {count = count,display = display,costume = costume}
	else
		value[key] = count
	end
	return value
end

function item.normalize_evaluate_result(ret)
	local counts = {}
	local meta = {}
	for id,raw in pairs(ret or {}) do
		if tonumber(id) then
			local count,display,costume = item.parse_entry(raw)
			local nid = tonumber(id)
			counts[nid] = count
			if display ~= nil or costume ~= nil then
				meta[nid] = {}
				if display ~= nil then meta[nid].display = display == true end
				if costume ~= nil then meta[nid].costume = costume == true end
			end
		end
	end
	return counts,meta
end

-- 存档/深拷贝后 id 可能变成字符串键；合并为纯 number 键，避免同一道具被加两遍
local function collapse_count_map(src)
	local out = {}
	for id,count in pairs(src or {}) do
		local nid = tonumber(id)
		if nid then
			local n = tonumber(count) or 0
			-- 同 id 的 string/number 别名取较大值，绝不累加
			if out[nid] == nil or n > out[nid] then out[nid] = n end
		end
	end
	return out
end

function item.write_player_evaluate(idx,counts,meta,only_id)
	save.elses[item.recorder_key()] = save.elses[item.recorder_key()] or {}
	save.elses[item.recorder_key()][idx] = save.elses[item.recorder_key()][idx] or {}
	local recorder = save.elses[item.recorder_key()][idx]
	local meta_bag = item.ensure_meta_bag(idx)
	if only_id then
		local nid = tonumber(only_id)
		-- 清掉同 id 的字符串别名
		for id,_ in pairs(recorder) do
			if tonumber(id) == nid then recorder[id] = nil end
		end
		recorder[nid] = counts[nid] or 0
		for id,_ in pairs(meta_bag) do
			if tonumber(id) == nid then meta_bag[id] = nil end
		end
		if meta[nid] then
			meta_bag[nid] = meta[nid]
		end
		return
	end
	local collapsed = collapse_count_map(counts)
	for id,_ in pairs(recorder) do
		recorder[id] = nil
	end
	for id,count in pairs(collapsed) do
		recorder[id] = count
	end
	-- 全量刷新该玩家 meta（同样折叠键）
	for id,_ in pairs(meta_bag) do
		meta_bag[id] = nil
	end
	for id,entry in pairs(meta or {}) do
		local nid = tonumber(id)
		if nid then meta_bag[nid] = entry end
	end
end

function item.merge_meta_opts(idx,collid,opts)
	if not opts or (opts.display == nil and opts.costume == nil) then return end
	local meta_bag = item.ensure_meta_bag(idx)
	local cur = meta_bag[collid] or {}
	local display = cur.display
	local costume = cur.costume
	if opts.display ~= nil then display = or_bool(display,opts.display) end
	if opts.costume ~= nil then costume = or_bool(costume,opts.costume) end
	if display ~= nil or costume ~= nil then
		meta_bag[collid] = {}
		if display ~= nil then meta_bag[collid].display = display == true end
		if costume ~= nil then meta_bag[collid].costume = costume == true end
	else
		meta_bag[collid] = nil
	end
end

-- costume 默认跟随「是否会进 HUD/EID」：meta.display 或 register_provider
function item.resolve_add_costume(player,collid,opts)
	opts = opts or {}
	if opts.costume ~= nil then return opts.costume == true end
	local idx = item.get_player_index(player)
	local m = item.get_meta_entry(idx,collid)
	if m and m.costume ~= nil then return m.costume == true end
	local shown = false
	if opts.display == true then shown = true end
	if m and m.display == true then shown = true end
	if not shown then
		local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
		if temp_hud.id_shown_by_providers and temp_hud.id_shown_by_providers(player,collid) then
			shown = true
		end
	end
	return shown
end

--- 以引擎侧 Group 实况为准，把 innate 精确同步到 desired（大退/沙漏后 rgon_applied 会失真）
function item.sync_rgon_fake_items(player,infos)
	if not item.can_use_rgon_backend(player) then return false end
	local idx = item.get_player_index(player)
	if not idx then return false end
	local desired = collapse_count_map(infos)
	local ok = pcall(function()
		if player.GetInnateCollectibleGroup and player.SetInnateCollectibleCount then
			local current = player:GetInnateCollectibleGroup(item.rgon_group_key) or {}
			local seen = {}
			for collid,_ in pairs(current) do
				local id = tonumber(collid)
				if id then
					seen[id] = true
					local want = desired[id] or 0
					local costume = want > 0 and item.resolve_add_costume(player,id) or false
					player:SetInnateCollectibleCount(id,want,item.rgon_group_key,costume)
				end
			end
			for id,want in pairs(desired) do
				if not seen[id] and want > 0 then
					player:SetInnateCollectibleCount(id,want,item.rgon_group_key,item.resolve_add_costume(player,id))
				end
			end
		else
			-- 旧 API：先按 Group 实况清空，再按 desired 添加
			if player.GetInnateCollectibleGroup then
				local current = player:GetInnateCollectibleGroup(item.rgon_group_key) or {}
				for collid,count in pairs(current) do
					local id = tonumber(collid)
					local amount = tonumber(count) or 0
					if id and amount > 0 then
						player:RemoveInnateCollectible(id,amount,item.rgon_group_key)
					end
				end
			else
				local applied = item.rgon_applied[idx] or {}
				for collid,count in pairs(applied) do
					local id = tonumber(collid)
					local amount = tonumber(count) or 0
					if id and amount > 0 then
						player:RemoveInnateCollectible(id,amount,item.rgon_group_key)
					end
				end
			end
			for id,want in pairs(desired) do
				if want > 0 then
					player:AddInnateCollectible(id,want,item.rgon_group_key,-1,item.resolve_add_costume(player,id))
				end
			end
		end
	end)
	if ok then
		item.rgon_applied[idx] = desired
	else
		item.rgon_applied[idx] = {}
	end
	return ok
end

function item.remove_rgon_applied(player)
	if not item.can_use_rgon_backend(player) then return false end
	local idx = item.get_player_index(player)
	if not idx then return false end
	local had = false
	if player.GetInnateCollectibleGroup then
		local ok,current = pcall(function()
			return player:GetInnateCollectibleGroup(item.rgon_group_key) or {}
		end)
		if ok and current then
			for collid,count in pairs(current) do
				if (tonumber(count) or 0) > 0 and tonumber(collid) then had = true break end
			end
		end
	elseif item.rgon_applied[idx] then
		for _,count in pairs(item.rgon_applied[idx]) do
			if (tonumber(count) or 0) > 0 then had = true break end
		end
	end
	local ok = item.sync_rgon_fake_items(player,{})
	return had and ok
end

function item.apply_rgon_fake_items(player,infos)
	return item.sync_rgon_fake_items(player,infos)
end

function item.assign_rgon_fake_item(player,collid,opts)
	if not item.can_use_rgon_backend(player) then return false end
	local idx = item.get_player_index(player)
	if not idx then return false end
	collid = tonumber(collid)
	if not collid then return false end
	local add_costume = item.resolve_add_costume(player,collid,opts)
	local ok = pcall(function()
		if player.GetInnateCollectibleCount and player.SetInnateCollectibleCount then
			local cur = player:GetInnateCollectibleCount(collid,item.rgon_group_key) or 0
			player:SetInnateCollectibleCount(collid,cur + 1,item.rgon_group_key,add_costume)
		else
			player:AddInnateCollectible(collid,1,item.rgon_group_key,-1,add_costume)
		end
	end)
	if ok then
		item.ensure_rgon_record(idx)[collid] = (item.ensure_rgon_record(idx)[collid] or 0) + 1
	end
	return ok
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = 237,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ then
		--print(1)
		d.ignore_me = true
		ent:RemoveFromOrbit()
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		ent.Velocity = Vector(0,0)
		ent.Position = item.position
		ent:AddEntityFlags(EntityFlag.FLAG_NO_QUERY)
		ent.Visible = false
	end
end,
})
--l local q = Isaac.Spawn(3,206,175,Vector(2000,2000),Vector(0,0),Game():GetPlayer(0)):ToFamiliar() q.Visible = false q:RemoveFromOrbit()
--175,521
function item.assign_fake_item(player,collid,no_record,opts)
	player = player or Game():GetPlayer(0)
	opts = opts or {}
	if no_record == nil then
		local idx = player:GetData().__Index
		if idx then
			save.elses[item.recorder_key()] = save.elses[item.recorder_key()] or {}
			save.elses[item.recorder_key()][idx] = save.elses[item.recorder_key()][idx] or {}
			save.elses[item.recorder_key()][idx][collid] = (save.elses[item.recorder_key()][idx][collid] or 0) + 1
			item.merge_meta_opts(idx,collid,opts)
		end
	end
	--local q = Game():Spawn(3,237,item.position,Vector(0,0),player,collid,6666666):ToFamiliar()
	if item.assign_rgon_fake_item(player,collid,opts) then return true end
	local q = Isaac.Spawn(3,237,collid,item.position,Vector(0,0),player):ToFamiliar()
	if q then
		--print(q.InitSeed)
		local d = q:GetData()
		local s = q:GetSprite()
		consistance_holder.try_hold_entity(q,item.own_key,{keep_level = true,consistance = true,})
		
		q:RemoveFromOrbit()
		q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		q:AddEntityFlags(EntityFlag.FLAG_NO_QUERY)
		q.Visible = false
	end
	return q
end

function item.get_legacy_imitate_item_wisps()
	local ret = {}
	local n_entity = Isaac.GetRoomEntities()
	for u,v in pairs(n_entity) do
		if v.Type == 3 and v.Variant == 237 then
			local succ = consistance_holder.try_check_entity(v,item.own_key)
			if succ then
				table.insert(ret,#ret + 1,v:ToFamiliar())
			end
		end
	end
	return ret
end

function item.get_imitate_item_wisps()
	return item.get_legacy_imitate_item_wisps()
end

function item.re_assign_fake_item()
	local n_wisps = item.get_imitate_item_wisps()
	local infos = {}
	local info_player = {}
	save.elses[item.recorder_key()] = save.elses[item.recorder_key()] or {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local idx = player:GetData().__Index
		if idx then
			infos[idx] = collapse_count_map(save.elses[item.recorder_key()][idx])
			info_player[idx] = player
		end
	end
	-- RGON：不再先按内存账本 remove 再 Add（大退后会叠份）；按 Group 实况 sync
	for u,v in pairs(n_wisps) do
		local st = v.SubType
		local t_player = v.Player or Game():GetPlayer(0)
		local t_idx = t_player:GetData().__Index
		if t_idx and infos[t_idx] then
			if (infos[t_idx][st] or 0) <= 0 then
				delay_buffer.addeffe(function(params)
					if v and v:Exists() then
						v:Kill()
						SFXManager():Stop(SoundEffect.SOUND_STEAM_HALFSEC)
					end
				end,{},1)
			else
				infos[t_idx][st] = infos[t_idx][st] - 1
			end
		end
	end
	for u,v in pairs(infos) do
		local t_player = info_player[u] or Game():GetPlayer(0)
		local TempRevive = require("Qing_Remaster_scripts.others.temporary_revive_manager")
		if TempRevive and TempRevive.sync_grants_from_desired then
			TempRevive.sync_grants_from_desired(t_player, v)
			v = TempRevive.apply_effective_desired(t_player, v)
		end
		if item.can_use_rgon_backend(t_player) then
			item.sync_rgon_fake_items(t_player,v)
		else
			for uu,vv in pairs(v) do
				for i = 1,vv do
					item.assign_fake_item(t_player,tonumber(uu),true)
				end
			end
		end
		callback_manager.work("POST_REASSIGN_IMITATE_ITEM",function(funct,params) funct(nil,t_player) end)		--一定会在POST_CHANGE_ALL_COLLECTIBLE后被调用一次
	end
end

function item.clear_fake_item()
	save.elses[item.recorder_key()] = save.elses[item.recorder_key()] or {}
	save.elses[item.meta_key()] = save.elses[item.meta_key()] or {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local idx = player:GetData().__Index
		if idx then
			save.elses[item.recorder_key()][idx] = save.elses[item.recorder_key()][idx] or {}
			for u,v in pairs(save.elses[item.recorder_key()][idx]) do
				if tonumber(u) then
					save.elses[item.recorder_key()][idx][u] = nil
				end
			end
			save.elses[item.meta_key()][idx] = {}
		end
	end
	item.re_assign_fake_item()
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	end
end

function item.remove_fake_items(fake)
	local ret = false
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if item.remove_rgon_applied(player) then ret = true end
	end
	local n_wisps = item.get_imitate_item_wisps()
	if #n_wisps > 0 then ret = true end
	for u,v in pairs(n_wisps) do
		if fake then
			v:Remove()
		else
			v:Kill()
			SFXManager():Stop(SoundEffect.SOUND_STEAM_HALFSEC)
		end
	end
	return ret
end

function item.Evaluate_Imitate_Items(players,val)
	if players == nil then players = {} for playerNum = 1, Game():GetNumPlayers() do table.insert(players,#players + 1,Game():GetPlayer(playerNum - 1)) end end
	if type(players) ~= "table" then players = {players} end
	save.elses[item.recorder_key()] = save.elses[item.recorder_key()] or {}
	save.elses[item.meta_key()] = save.elses[item.meta_key()] or {}
	for u,player in pairs(players) do
		if auxi.check_all_exists(player) and player:ToPlayer() then
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.recorder_key()][idx] = save.elses[item.recorder_key()][idx] or {}
			if val then
				local ret = callback_manager.work_with_result("MC_EVALUATE_IMITATE_ITEM",function(funct,params,value) if params == nil or params == val then return funct(nil,player,val,value) end end,{[val] = 0,})
				local counts,meta = item.normalize_evaluate_result(ret)
				item.write_player_evaluate(idx,counts,meta,val)
			else
				local ret = callback_manager.work_with_result("MC_EVALUATE_IMITATE_ITEM",function(funct,params,value) return funct(nil,player,nil,value) end,{})
				local counts,meta = item.normalize_evaluate_result(ret)
				item.write_player_evaluate(idx,counts,meta)
			end
		end
	end
	item.re_assign_fake_item()
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	end
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	delay_buffer.addeffe(function(params)
		item.Evaluate_Imitate_Items()
	end,{},1)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_ALL_COLLECTIBLE, params = nil,
Function = function(_,player)
	delay_buffer.addeffe(function(params)
		item.Evaluate_Imitate_Items(player)
	end,{},1)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_POCKET_ITEM, params = nil,
Function = function(_,player,data)
	delay_buffer.addeffe(function(params)
		item.Evaluate_Imitate_Items(player)
	end,{},1)
end,
})
-- 大退/沙漏：elses 已回滚，但引擎 innate Group 与内存 rgon_applied 可能不一致；延迟按 recorder 精确 sync
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_REWIND, params = nil,
Function = function(_,tp)
	item.rgon_applied = {}
	delay_buffer.addeffe(function(params)
		item.Evaluate_Imitate_Items()
	end,{},1)
end,
})
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_USE_ITEM, params = nil,
Function = function(_, colid, rng, player, flags, slot, data)
	if item.reuser[colid] then
		local ret = item.remove_fake_items()
		if ret then
			delay_buffer.addeffe(function(params)
				if player and player:Exists() then
					player:UseActiveItem(colid, true, false, true, false)
					if item.reuser[colid].should_re_evaluate then item.Evaluate_Imitate_Items(player) end
				end
			end,{},1)
			return true
		end
	end
	if item.re_evaluater[colid] then
		delay_buffer.addeffe(function(params)
			item.Evaluate_Imitate_Items(player)
		end,{},1)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.rgon_applied = {}
	if continue then
		save.elses[item.recorder_key()] = save.elses[item.recorder_key()] or {}
		save.elses[item.meta_key()] = save.elses[item.meta_key()] or {}
	else
		save.elses[item.recorder_key()] = {}
		save.elses[item.meta_key()] = {}
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_,str,params)
	if string.lower(str) == "meus" and params ~= nil then
		local args={}
		for str in string.gmatch(params, "([^ ]+)") do
			table.insert(args, str)
		end
		if args[1] and args[1] == "please" then
			if args[2] and args[2] == "imitate" then
				if args[3] and tonumber(args[3]) then
					local ret = item.assign_fake_item(nil,tonumber(args[3]))
					if ret then print("Success")
					else print("Fail") end
				end
			end
		end
	end
end,
})

return item

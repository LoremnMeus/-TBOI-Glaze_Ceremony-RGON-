local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local chinese_input = require("Qing_Remaster_scripts.others.Chinese_input_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Spectralsword,
	own_key = "Item_Spectralsword_",
	base_reforge_cost = 1,
	target = nil,
	panel = nil,
	affix_registry = {},
	debug = true,
	last_debug_frame = -1,
	prefixes = {},
	suffixes = {},
}

local stat_cache_flags = CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_RANGE |
	CacheFlag.CACHE_SPEED | CacheFlag.CACHE_LUCK | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG

local blocked_panel_actions = {
	[ButtonAction.ACTION_LEFT] = true,
	[ButtonAction.ACTION_RIGHT] = true,
	[ButtonAction.ACTION_UP] = true,
	[ButtonAction.ACTION_DOWN] = true,
	[ButtonAction.ACTION_SHOOTLEFT] = true,
	[ButtonAction.ACTION_SHOOTRIGHT] = true,
	[ButtonAction.ACTION_SHOOTUP] = true,
	[ButtonAction.ACTION_SHOOTDOWN] = true,
	[ButtonAction.ACTION_DROP] = true,
	[ButtonAction.ACTION_PILLCARD] = true,
	[ButtonAction.ACTION_MAP] = true,
	[ButtonAction.ACTION_BOMB] = true,
	[ButtonAction.ACTION_ITEM] = true,
	[ButtonAction.ACTION_CONSOLE] = true,
	[ButtonAction.ACTION_MENUBACK] = true,
	[ButtonAction.ACTION_MENUTAB] = true,
	[ButtonAction.ACTION_FULLSCREEN] = true,
	[ButtonAction.ACTION_MUTE] = true,
	[ButtonAction.ACTION_RESTART] = true,
}

local function lang_key()
	local language = Options and Options.Language or ""
	if language == "zh" or language == "zh_cn" or language == "zh_CN" then return "zh_cn" end
	return "en_us"
end

local function is_valid_collectible(ent)
	return ent and ent:Exists() and not ent:IsDead() and ent.Type == EntityType.ENTITY_PICKUP and ent.Variant == PickupVariant.PICKUP_COLLECTIBLE and ent.SubType > 0
end

local function get_default_desc(id)
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if cfg then return cfg.Name or "",cfg.Description or "" end
	return "", ""
end

local function debug_log(text,force)
	if not item.debug then return end
	local frame = Isaac.GetFrameCount()
	if force or item.last_debug_frame ~= frame then
		item.last_debug_frame = frame
		Isaac.DebugString("[Qing Spectralsword] "..tostring(text))
	end
end

local function get_display_desc(player,id)
	local name,desc = get_default_desc(id)
	local ret = callback_manager.work_with_result("PRE_DESCRIPT_ITEM",function(funct,params,value)
		if params == nil or params == "Item" then return funct(nil,player,"Item",id,value) end
	end,{Name = auxi.check_name_data(name),Description = auxi.check_name_data(desc),})
	if ret then return ret.Name or name,ret.Description or desc end
	return auxi.check_name_data(name),auxi.check_name_data(desc)
end

local function action_label(action,fallback)
	return fallback or tostring(action)
end

local function panel_text(field)
	if item.panel == nil then return "" end
	if chinese_input.active and item.panel.field == field then return chinese_input.text_with_cursor(chinese_input.active) end
	return field == "name" and item.panel.name or item.panel.description
end

local function pause_menu_open()
	if not REPENTOGON then return false end
	return Game():IsPauseMenuOpen()
end

local start_edit

function item.get_save()
	local key = item.own_key.."data"
	save.PermanentData = save.PermanentData or {}
	if save.PermanentData[key] == nil and save.elses and save.elses[key] ~= nil then
		save.PermanentData[key] = auxi.deepCopy(save.elses[key])
	end
	save.PermanentData[key] = save.PermanentData[key] or {rewrites = {},affixes = {}}
	save.PermanentData[key].rewrites = save.PermanentData[key].rewrites or {}
	save.PermanentData[key].affixes = save.PermanentData[key].affixes or {}
	-- 旧版把拾取副标题误命名为 Description，容易与 EID 机械说明混淆。
	-- 一次性迁移为 Desc，之后该字段只用于拾取字幕，不写入 EID Description。
	for _,rewrite in pairs(save.PermanentData[key].rewrites) do
		if type(rewrite) == "table" and rewrite.Desc == nil and rewrite.Description ~= nil then
			rewrite.Desc = rewrite.Description
			rewrite.Description = nil
		end
	end
	return save.PermanentData[key]
end

function item.get_rewrite(id,create)
	local data = item.get_save()
	local key = tostring(id)
	if create then data.rewrites[key] = data.rewrites[key] or {} end
	return data.rewrites[key]
end

function item.get_reforge_cost(player)
	local cost = item.base_reforge_cost
	if player and auxi.should_do_Seija and auxi.should_do_Seija(player) then cost = cost + 4 end
	return cost
end

function item.register_affix(id,info)
	if id == nil or type(info) ~= "table" then return false end
	item.affix_registry[id] = info
	if info.slot == "prefix" then table.insert(item.prefixes,id)
	elseif info.slot == "suffix" then table.insert(item.suffixes,id) end
	return true
end

item.register_affix("keen",{
	slot = "prefix", name_zh = "锋利的", name_en = "Keen ", cache = CacheFlag.CACHE_DAMAGE,
	zh_cn = "锋利：每份该道具获得{{Damage}} +0.4伤害", en_us = "Keen: Each copy grants {{Damage}} +0.4 damage",
	apply = function(player,count) player.Damage = player.Damage + auxi.get_damage_multiplier(player) * 0.4 * count end,
})
item.register_affix("frenzied",{
	slot = "prefix", name_zh = "狂热的", name_en = "Frenzied ", cache = CacheFlag.CACHE_FIREDELAY,
	zh_cn = "狂热：每份该道具获得{{Tears}} +0.5射速", en_us = "Frenzied: Each copy grants {{Tears}} +0.5 tears",
	apply = function(player,count) player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * 0.5 * count) end,
})
item.register_affix("farseeing",{
	slot = "prefix", name_zh = "远视的", name_en = "Farseeing ", cache = CacheFlag.CACHE_RANGE,
	zh_cn = "远视：每份该道具获得{{Range}} +1.5射程", en_us = "Farseeing: Each copy grants {{Range}} +1.5 range",
	apply = function(player,count) player.TearRange = player.TearRange + 60 * count end,
})
item.register_affix("ethereal",{
	slot = "prefix", name_zh = "灵质的", name_en = "Ethereal ", cache = CacheFlag.CACHE_TEARFLAG,
	zh_cn = "灵质：泪弹获得穿透障碍物效果", en_us = "Ethereal: Tears pass through obstacles",
	apply = function(player) player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL end,
})
item.register_affix("haste",{
	slot = "suffix", name_zh = "·疾行", name_en = " of Haste", cache = CacheFlag.CACHE_SPEED,
	zh_cn = "疾行：每份该道具获得{{Speed}} +0.15移速", en_us = "of Haste: Each copy grants {{Speed}} +0.15 speed",
	apply = function(player,count) player.MoveSpeed = player.MoveSpeed + 0.15 * count end,
})
item.register_affix("fortune",{
	slot = "suffix", name_zh = "·鸿运", name_en = " of Fortune", cache = CacheFlag.CACHE_LUCK,
	zh_cn = "鸿运：每份该道具获得{{Luck}} +1幸运", en_us = "of Fortune: Each copy grants {{Luck}} +1 luck",
	apply = function(player,count) player.Luck = player.Luck + count end,
})
item.register_affix("force",{
	slot = "suffix", name_zh = "·强袭", name_en = " of Force", cache = CacheFlag.CACHE_SHOTSPEED,
	zh_cn = "强袭：每份该道具获得{{ShotSpeed}} +0.2弹速", en_us = "of Force: Each copy grants {{ShotSpeed}} +0.2 shot speed",
	apply = function(player,count) player.ShotSpeed = player.ShotSpeed + 0.2 * count end,
})
item.register_affix("guidance",{
	slot = "suffix", name_zh = "·导引", name_en = " of Guidance", cache = CacheFlag.CACHE_TEARFLAG,
	zh_cn = "导引：泪弹获得追踪效果", en_us = "of Guidance: Tears gain homing",
	apply = function(player) player.TearFlags = player.TearFlags | TearFlags.TEAR_HOMING end,
})

function item.get_affix_list(collectible_id,create)
	local data = item.get_save()
	local key = tostring(collectible_id)
	if create then data.affixes[key] = data.affixes[key] or {} end
	return data.affixes[key] or {}
end

function item.format_affix(affix_id,language)
	local info = item.affix_registry[affix_id]
	if info == nil then return nil end
	local text = info[language] or info.en_us or info.zh_cn
	if type(text) == "function" then text = text(info,language) end
	return text
end

function item.format_affixes(collectible_id,language)
	local list = item.get_affix_list(collectible_id)
	local ret = ""
	for _,affix_id in ipairs(list) do
		local text = item.format_affix(affix_id,language)
		if text and text ~= "" then ret = ret.."#{{Collectible"..tostring(item.entity).."}} "..text end
	end
	return ret
end

function item.format_affix_name(collectible_id,name,language)
	local prefix,suffix = "",""
	for _,affix_id in ipairs(item.get_affix_list(collectible_id)) do
		local info = item.affix_registry[affix_id]
		if info then
			local value = language == "zh_cn" and info.name_zh or info.name_en
			if info.slot == "prefix" then prefix = value or ""
			elseif info.slot == "suffix" then suffix = value or "" end
		end
	end
	return prefix..(name or "")..suffix
end

local function roll_other(rng,pool,old_id)
	if #pool == 0 then return nil end
	local id = pool[rng:RandomInt(#pool) + 1]
	if #pool > 1 and id == old_id then
		for _,candidate in ipairs(pool) do if candidate ~= old_id then id = candidate break end end
	end
	return id
end

function item.try_reforge(player,collectible_id)
	if player == nil or collectible_id == nil then return false end
	local cost = item.get_reforge_cost(player)
	if player:GetNumCoins() < cost or next(item.affix_registry) == nil then return false end
	player:AddCoins(-cost)
	local list = item.get_affix_list(collectible_id,true)
	local rng = player:GetCollectibleRNG(item.entity)
	list[1] = roll_other(rng,item.prefixes,list[1])
	list[2] = roll_other(rng,item.suffixes,list[2])
	for i = 0,Game():GetNumPlayers() - 1 do
		local target_player = Game():GetPlayer(i)
		if target_player:GetCollectibleNum(collectible_id,true) > 0 then
			target_player:AddCacheFlags(stat_cache_flags)
			target_player:EvaluateItems()
		end
	end
	debug_log("reforge id="..tostring(collectible_id).." affixes="..tostring(list[1])..","..tostring(list[2]),true)
	return true
end

function item.start_swing(player)
	if player == nil then return false end
	local d = player:GetData()
	if d[item.own_key.."holding"] ~= true then
		player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
		d[item.own_key.."holding"] = true
	else
		player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
		d[item.own_key.."holding"] = false
	end
	return true
end

local function open_panel(player,pickup)
	local id = pickup.SubType
	local rewrite = item.get_rewrite(id,true)
	local name,desc = get_display_desc(player,id)
	item.target = pickup
	item.panel = {
		player = player,
		target = pickup,
		id = id,
		field = "name",
		original_name = name,
		original_description = desc,
		name = rewrite.Name or name,
		description = rewrite.Desc or desc,
	}
	selection_holder.try_select(player,"Spectralsword")
	auxi.time_stop(item.own_key)
	chinese_input.try_register_console_names(false)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_TOOTH_AND_NAIL,1,1,false,0,2)
	debug_log("open panel id="..tostring(id).." name="..tostring(name).." desc="..tostring(desc),true)
	if start_edit then start_edit("name") end
end

local function close_panel(save_changes)
	if item.panel then
		debug_log("close panel save="..tostring(save_changes).." id="..tostring(item.panel.id),true)
		if save_changes then
			local rewrite = item.get_rewrite(item.panel.id,true)
			rewrite.Name = item.panel.name
			rewrite.Desc = item.panel.description
		end
		if item.panel.player then selection_holder.remove_select(item.panel.player,"Spectralsword") end
	end
	chinese_input.close(false)
	item.panel = nil
	item.target = nil
	item.room_selection_cleanup_until = Game():GetFrameCount() + 2
	auxi.time_free(item.own_key)
end

start_edit = function(field)
	if item.panel == nil then return end
	item.panel.field = field
	if field == "reforge" then
		chinese_input.close(false)
		return
	end
	local text = field == "name" and item.panel.name or item.panel.description
	local state = chinese_input.open(item.own_key..field,text,function(value)
		if field == "name" then item.panel.name = value
		else item.panel.description = value end
		debug_log("input change field="..tostring(field).." value="..tostring(value))
	end,function(value)
		if field == "name" then item.panel.name = value
		else item.panel.description = value end
	end,0)
	state.debug_name = item.own_key..field
end

local function update_panel_input()
	if item.panel == nil then return end
	local tab_key = Input.IsButtonTriggered(Keyboard.KEY_TAB,0)
	local reforge_key = item.panel.field == "reforge" and Input.IsButtonTriggered(Keyboard.KEY_ENTER,0)
	local typed = item.panel.field ~= "reforge" and chinese_input.update_keyboard_input(0)
	local save_key = Input.IsButtonTriggered(Keyboard.KEY_LEFT_CONTROL,0) or
		Input.IsButtonTriggered(Keyboard.KEY_RIGHT_CONTROL,0)
	local active = chinese_input.active

	if typed or tab_key or save_key or reforge_key then
		debug_log("panel input typed="..tostring(typed)..
			" tab="..tostring(tab_key)..
			" ctrl="..tostring(save_key)..
			" field="..tostring(item.panel.field)..
			" mode="..tostring(active and active.mode)..
			" text="..tostring(active and chinese_input.get_text(active) or ""),true)
	end

	if active and active.cancelled then
		close_panel(false)
	elseif save_key then
		close_panel(true)
	elseif reforge_key then
		local success = item.try_reforge(item.panel.player,item.panel.id)
		item.panel.notice = success and (lang_key() == "zh_cn" and "重铸完成" or "Reforged") or
			(lang_key() == "zh_cn" and "硬币不足" or "Not enough coins")
	elseif tab_key then
		if item.panel.field == "name" then start_edit("description")
		elseif item.panel.field == "description" then start_edit("reforge")
		else start_edit("name") end
	elseif active and active.submitted then
		active.submitted = false
	end
end

local function try_find_collectible(pos,rotation,range)
	local nearest = nil
	local nearest_dis = nil
	local nearest_any = nil
	local nearest_any_dis = nil
	for _,ent in pairs(Isaac.GetRoomEntities()) do
		if is_valid_collectible(ent) then
			local offset = ent.Position - pos
			local dis = offset:Length()
			if dis < (range + ent.Size) and (nearest_any == nil or dis < nearest_any_dis) then
				nearest_any = ent
				nearest_any_dis = dis
			end
			if dis < (range + ent.Size) and auxi.MakeVector(offset:GetAngleDegrees() - rotation).X < 0.45 then
				if nearest == nil or dis < nearest_dis then
					nearest = ent
					nearest_dis = dis
				end
			end
		end
	end
	return nearest or nearest_any
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue ~= true and save.elses then
		save.elses[item.own_key.."data"] = nil
	end
	item.get_save()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	if useFlags & UseFlag.USE_CARBATTERY ~= UseFlag.USE_CARBATTERY then item.start_swing(player) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	-- 旧房间 panel.player 可能是悬空 userdata；不要经 selection_holder/GetData 清理。
	chinese_input.close(false)
	item.panel = nil
	item.target = nil
	item.room_selection_cleanup_until = Game():GetFrameCount() + 2
	auxi.time_free(item.own_key)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_)
	chinese_input.close(false)
	item.panel = nil
	item.target = nil
	item.room_selection_cleanup_until = Game():GetFrameCount() + 2
	pcall(function() auxi.time_free(item.own_key) end)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if item.room_selection_cleanup_until then
		if Game():GetFrameCount() <= item.room_selection_cleanup_until then
			selection_holder.remove_select(player,"Spectralsword")
		else
			item.room_selection_cleanup_until = nil
		end
	end
	-- 兼容旧字段
	if item.room_selection_cleanup then
		selection_holder.remove_select(player,"Spectralsword")
		item.room_selection_cleanup = nil
	end
	local ctrlid = player.ControllerIndex
	local d = player:GetData()
	if d[item.own_key.."holding"] == true then
		if player:IsHoldingItem() == false then
			d[item.own_key.."holding"] = false
		else
			local dir = 0
			for i = ButtonAction.ACTION_SHOOTLEFT,ButtonAction.ACTION_SHOOTDOWN do
				if Input.IsActionPressed(i,ctrlid) or Input.IsActionTriggered(i,ctrlid) then
					dir = i
				end
			end
			if dir > 0 then
				local vel = Vector(0,0)
				if Game():GetRoom():IsMirrorWorld() and (dir == ButtonAction.ACTION_SHOOTLEFT or dir == ButtonAction.ACTION_SHOOTRIGHT) then dir = ButtonAction.ACTION_SHOOTLEFT + ButtonAction.ACTION_SHOOTRIGHT - dir end
				if dir == ButtonAction.ACTION_SHOOTLEFT then vel = Vector(-1,0)
				elseif dir == ButtonAction.ACTION_SHOOTRIGHT then vel = Vector(1,0)
				elseif dir == ButtonAction.ACTION_SHOOTUP then vel = Vector(0,-1)
				elseif dir == ButtonAction.ACTION_SHOOTDOWN then vel = Vector(0,1) end
				player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
				d[item.own_key.."holding"] = false
				auxi.fire_dosome_knife(player.Position + player.Velocity,vel/1000,nil,"AttackUp",{list = {spectral = 1},anti_tearflag = ~BitSet128(0,0),dmg = 0,color = Color(1,1,1,1),spectralsword = true,no_repel = true,no_open = true,no_grid = true,Flip = auxi.random_bool(),player = player},nil)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if ent.Variant == enums.Entities.StabberKnife and d.params and d.params.spectralsword then
		if ((s:IsPlaying("AttackUp") and not s:IsFinished("AttackUp")) or (s:IsPlaying("AttackUp2") and not s:IsFinished("AttackUp2"))) and (d.inner_frame or 0) >= 5 and (d.inner_frame or 0) <= 12 and not d[item.own_key.."hit_checked"] then
			d[item.own_key.."hit_checked"] = true
			local player = d.params.player or Game():GetPlayer(0)
			local target = try_find_collectible(ent.Position,ent.RotationOffset,120 * ent:GetSprite().Scale:Length())
			if target then open_panel(player,target) end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	if item.panel == nil then return end
	if pause_menu_open() then
		item.panel.was_paused = true
		return
	elseif item.panel.was_paused then
		item.panel.was_paused = false
		if chinese_input.active then chinese_input.active.suppress_escape_until_release = true end
	end
	if not is_valid_collectible(item.panel.target) then close_panel(false) return end
	update_panel_input()
	if item.panel == nil then return end
	local pos = Isaac.WorldToScreen(item.panel.target.Position + item.panel.target.PositionOffset) + Vector(-72,-54)
	local active = chinese_input.active
	local lang = lang_key()
	local title = lang == "zh_cn" and "妖刀·逢魔" or "Spectral Sword"
	local mode = (active and active.mode or "zh") == "zh" and "中文" or "EN"
	local caps = active and active.caps_lock and "ON" or "OFF"
	local hint = lang == "zh_cn" and ("Tab: 切换  Enter: 重铸  Shift: "..mode.."  Ctrl: 保存退出  Esc: 取消") or ("Tab: Field  Enter: Reforge  Shift: "..mode.."  Ctrl: Save & Exit  Esc: Cancel")
	local target_line = lang == "zh_cn" and ("目标: "..tostring(item.panel.id).." / "..item.panel.original_name) or ("Target: "..tostring(item.panel.id).." / "..item.panel.original_name)
	local cost = item.get_reforge_cost(item.panel.player)
	local affix_name = item.format_affix_name(item.panel.id,"",lang)
	local notice = item.panel.notice and ("  "..item.panel.notice) or ""
	local reforge_line = lang == "zh_cn" and ("重铸词缀  ["..tostring(cost).."¢]  "..affix_name..notice) or ("Reforge affixes  ["..tostring(cost).."¢]  "..affix_name..notice)
	gui.draw_ch(pos,title,1,1,KColor(1,0.85,0.85,1),true)
	gui.draw_ch(pos + Vector(0,14),target_line,1,1,KColor(0.85,0.95,1,1),true)
	gui.draw_ch(pos + Vector(0,30),(item.panel.field == "name" and "> " or "  ")..panel_text("name"),1,1,KColor(1,1,1,1),true)
	gui.draw_ch(pos + Vector(0,44),(item.panel.field == "description" and "> " or "  ")..panel_text("description"),1,1,KColor(0.9,0.9,0.9,1),true)
	gui.draw_ch(pos + Vector(0,58),(item.panel.field == "reforge" and "> " or "  ")..reforge_line,1,1,KColor(1,0.85,0.55,1),true)
	gui.draw_ch(pos + Vector(0,74),hint,1,1,KColor(0.7,0.85,1,1),true)
	if active then
		local candidates,total,query,rest,segments = chinese_input.get_candidates(active.pinyin,active.page,active.page_size)
		local cand_text = {}
		for i,ch in ipairs(candidates) do table.insert(cand_text,tostring(i)..ch) end
		local page,page_count = chinese_input.get_page_info(active)
		local segmented = table.concat(segments or {},"'")
		local input_line = active.mode == "zh" and
			("[-] ["..segmented.."] "..table.concat(cand_text," ").." [+] "..tostring(page).."/"..tostring(page_count)) or
			"[English]"
		gui.draw_ch(pos + Vector(0,90),input_line,1,1,KColor(1,1,0.7,1),true)
	end
end,
})

local function spectral_input_active(ent)
	if pause_menu_open() then return false end
	-- 只认面板本身：换房/重开后 panel 已清但 selection 残留时，不得继续把射击 GET_ACTION_VALUE 置 0（准星失灵）
	if item.panel == nil then return false end
	local player = ent and ent:ToPlayer()
	if player and item.panel.player then
		local ok, same = pcall(function()
			return auxi.check_for_the_same(item.panel.player, player)
		end)
		if ok and same == false then return false end
	end
	-- ent==nil（如 ACTION_RESTART 全局查询）时，只要面板开着就拦截
	return true
end

local function block_spectral_restart(_,ent,hook,button)
	if button ~= ButtonAction.ACTION_RESTART or not spectral_input_active(ent) then return end
	if hook == InputHook.GET_ACTION_VALUE then return 0 end
	return false
end

-- 中文/英文输入中的字母 R 也会映射到 ACTION_RESTART。和 Remaster! 一样，
-- 对两个数字输入 hook 分别前置拦截，避免输入文字时触发原版长按重开。
table.insert(item.pre_ToCall,{CallBack = ModCallbacks.MC_INPUT_ACTION,params = nil,priority = -1000,
Function = block_spectral_restart,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if spectral_input_active(ent) then
		if blocked_panel_actions[button] then
			if hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED then return false
			elseif hook == InputHook.GET_ACTION_VALUE then return 0 end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = "Item",
Function = function(_,player,tp,id,value)
	local rewrite = item.get_rewrite(id,false)
	if rewrite then
		value.Name = rewrite.Name or value.Name
		value.Description = rewrite.Desc or value.Description
	end
	value.Name = item.format_affix_name(id,value.Name,lang_key())
	local info = item.format_affixes(id,lang_key())
	if info ~= "" then value.Description = (value.Description or "")..info end
	return value
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	for collectible_id,list in pairs(item.get_save().affixes) do
		local id = tonumber(collectible_id)
		local count = id and player:GetCollectibleNum(id,true) or 0
		if count > 0 then
			for _,affix_id in ipairs(list) do
				local info = item.affix_registry[affix_id]
				if info and info.cache == cacheFlag and info.apply then info.apply(player,count) end
			end
		end
	end
end,
})

if EID then
	EID:addDescriptionModifier("qing_spectralsword_hide_eid_panel", function(desc)
		return item.panel ~= nil
	end, function(desc)
		desc.Name = ""
		desc.Description = ""
		desc.Icon = nil
		return desc
	end, 1)

	EID:addDescriptionModifier("qing_spectralsword_rewrite_decorator", function(desc)
		return desc.ObjType == 5 and desc.ObjVariant == 100 and desc.ObjSubType and (item.get_rewrite(desc.ObjSubType,false) ~= nil or item.format_affixes(desc.ObjSubType,lang_key()) ~= "")
	end, function(desc)
		local rewrite = item.get_rewrite(desc.ObjSubType,false)
		if rewrite then
			desc.Name = rewrite.Name or desc.Name
		end
		desc.Name = item.format_affix_name(desc.ObjSubType,desc.Name,lang_key())
		EID:appendToDescription(desc,item.format_affixes(desc.ObjSubType,lang_key()))
		return desc
	end)
end

return item

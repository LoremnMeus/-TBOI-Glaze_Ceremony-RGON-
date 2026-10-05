-- Debug ImGui builders (extracted from rgon_imgui_options_holder).
-- Uses start_mod / register_debug_module only; probes live in rgon_imgui_probes_ui.

local M = {}

function M.build(api)
	local item = api.item
	local text = api.text
	local add_text = api.add_text
	local add_checkbox = api.add_checkbox
	local add_drag_float = api.add_drag_float
	local add_drag_pair_path = api.add_drag_pair_path
	local add_group = api.add_group
	local add_separator = api.add_separator
	local add_reset_button = api.add_reset_button
	local imgui_layout = api.imgui_layout
	local ImGui = api.ImGui
	local enums = api.enums
	local auxi = api.auxi
	local save = api.save
	local ModConfig = api.ModConfig
	local translations = api.translations
	local item_color_holder = api.item_color_holder
	local achievement_tracker = api.achievement_tracker
	local CompletionMarks = api.CompletionMarks
	local unlock_board = api.unlock_board
	local dev_env = api.dev_env
	local probe_registry = api.probe_registry
	local push_notice = api.push_notice
	local error_notice_type = api.error_notice_type
	local language_key = api.language_key
	local setup_window = api.setup_window
	local save_mod_data = api.save_mod_data
	local DEBUG_PAGE = api.DEBUG_PAGE
	local register_debug_module = api.register_debug_module
	local set_module_footer = api.set_module_footer
	local register_home_controls = api.register_home_controls
	local start_mod = api.start_mod
	local start_probe_module = api.start_probe_module
	local page_parent = api.page_parent
	local recent_tab = api.recent_tab
	local items_tab = api.items_tab
	local cards_tab = api.cards_tab
	local characters_tab = api.characters_tab
	local systems_tab = api.systems_tab
	local visual_tab = api.visual_tab
	local data_tab = api.data_tab
	local tests_tab = api.tests_tab
	local story_test_tab = api.story_test_tab


local function item_color_state_text(state)
	local zh = language_key() == "zh"
	local states = zh and {
		waiting = "等待扫描",
		scanning = "扫描中",
		complete = "已完成",
		unavailable = "忏悔龙图像接口不可用",
	} or {
		waiting = "Waiting",
		scanning = "Scanning",
		complete = "Complete",
		unavailable = "REPENTOGON image API unavailable",
	}
	return states[state] or tostring(state)
end

local function item_color_status_text()
	local stats = item_color_holder.get_stats()
	if language_key() == "zh" then
		return string.format(
			"状态：%s\n已处理：%d / %d    成功：%d    失败：%d    缓存命中：%d\n手工对照：%d    有交集：%d    完全一致：%d    冲突：%d\n最近：%d  %s",
			item_color_state_text(stats.state),
			stats.processed or 0,stats.total or 0,stats.succeeded or 0,stats.failed or 0,stats.cached or 0,
			stats.compared or 0,stats.overlap or 0,stats.exact or 0,stats.conflict or 0,
			stats.last_id or 0,stats.last_name or ""
		)
	end
	return string.format(
		"State: %s\nProcessed: %d / %d    Success: %d    Failed: %d    Cache hits: %d\nManual comparisons: %d    Overlap: %d    Exact: %d    Conflicts: %d\nLatest: %d  %s",
		item_color_state_text(stats.state),
		stats.processed or 0,stats.total or 0,stats.succeeded or 0,stats.failed or 0,stats.cached or 0,
		stats.compared or 0,stats.overlap or 0,stats.exact or 0,stats.conflict or 0,
		stats.last_id or 0,stats.last_name or ""
	)
end

local function item_color_failure_text()
	local failures = item_color_holder.get_stats().failures or {}
	if #failures == 0 then
		return language_key() == "zh" and "最近失败：无" or "Recent failures: none"
	end
	local lines = {language_key() == "zh" and "最近失败：" or "Recent failures:"}
	for i = math.max(1,#failures - 4),#failures do
		local failure = failures[i]
		lines[#lines + 1] = string.format("%d %s: %s",failure.id or 0,failure.name or "",failure.reason or "")
	end
	return table.concat(lines,"\n")
end

local function add_item_color_panel(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupItemColors",text("group_item_colors"))
	add_text(group,text("item_colors_help"))

	local progress_id = "QingRemasterOptions_ItemColorProgress"
	local status_id = "QingRemasterOptions_ItemColorStatus"
	local categories_id = "QingRemasterOptions_ItemColorCategories"
	local failures_id = "QingRemasterOptions_ItemColorFailures"
	local stats = item_color_holder.get_stats()
	local progress = stats.total > 0 and stats.processed / stats.total or 0
	ImGui.AddProgressBar(group,progress_id,"",progress,tostring(stats.processed or 0).."/"..tostring(stats.total or 0))
	ImGui.AddCallback(progress_id,ImGuiCallback.Render,function()
		local current = item_color_holder.get_stats()
		local value = current.total > 0 and current.processed / current.total or 0
		ImGui.UpdateData(progress_id,ImGuiData.Value,value)
		ImGui.UpdateData(progress_id,ImGuiData.HintText,tostring(current.processed or 0).."/"..tostring(current.total or 0))
	end)

	imgui_layout.add_wrapped_text(group, status_id, item_color_status_text())
	ImGui.AddCallback(status_id,ImGuiCallback.Render,function()
		imgui_layout.update_text(status_id,item_color_status_text())
	end)
	imgui_layout.add_wrapped_text(group, categories_id, item_color_holder.get_category_summary())
	ImGui.AddCallback(categories_id,ImGuiCallback.Render,function()
		local summary = item_color_holder.get_category_summary()
		if summary == "" then summary = language_key() == "zh" and "颜色分布：等待数据" or "Color distribution: waiting for data" end
		imgui_layout.update_text(categories_id,summary)
	end)
	imgui_layout.add_wrapped_text(group, failures_id, item_color_failure_text())
	ImGui.AddCallback(failures_id,ImGuiCallback.Render,function()
		imgui_layout.update_text(failures_id,item_color_failure_text())
	end)

	ImGui.AddButton(group,"QingRemasterOptions_ItemColorRestart",text("item_colors_restart"),function()
		item_color_holder.start_scan(true)
		push_notice(text("item_colors_restarted"))
	end)
	ImGui.AddElement(group,"",ImGuiElement.SameLine)
	ImGui.AddButton(group,"QingRemasterOptions_ItemColorPrint",text("item_colors_print"),function()
		item_color_holder.print_report()
		push_notice(text("item_colors_printed"))
	end)
end

local function spectral_data()
	local inscription = package.loaded["Qing_Remaster_scripts.systems.item_inscription"]
	if inscription and inscription.get_save then
		return inscription.get_save()
	end
	local key = "Item_Inscription_data"
	save.PermanentData = save.PermanentData or {}
	save.PermanentData[key] = save.PermanentData[key] or {rewrites = {},affixes = {}}
	save.PermanentData[key].rewrites = save.PermanentData[key].rewrites or {}
	save.PermanentData[key].affixes = save.PermanentData[key].affixes or {}
	for _,rewrite in pairs(save.PermanentData[key].rewrites) do
		if type(rewrite) == "table" and rewrite.Desc == nil and rewrite.Description ~= nil then
			rewrite.Desc = rewrite.Description
			rewrite.Description = nil
		end
	end
	return save.PermanentData[key]
end

local function spectral_load_selected()
	local editor = item.spectral_editor
	local rewrite = editor.selected_id and spectral_data().rewrites[tostring(editor.selected_id)] or nil
	editor.draft_name = rewrite and tostring(rewrite.Name or "") or ""
	editor.draft_description = rewrite and tostring(rewrite.Desc or "") or ""
end

local function spectral_refresh(force)
	local editor = item.spectral_editor
	local rewrites = spectral_data().rewrites
	local ids = {}
	for raw_id,rewrite in pairs(rewrites) do
		local id = tonumber(raw_id)
		if id and type(rewrite) == "table" and (rewrite.Name ~= nil or rewrite.Desc ~= nil) then
			table.insert(ids,id)
		end
	end
	table.sort(ids)
	local signature_parts = {}
	for _,id in ipairs(ids) do
		local rewrite = rewrites[tostring(id)] or {}
		table.insert(signature_parts,tostring(id).."\31"..tostring(rewrite.Name or "").."\31"..tostring(rewrite.Desc or ""))
	end
	local signature = table.concat(signature_parts,"\30")
	if not force and signature == editor.signature then return false end

	local previous_id = editor.selected_id
	editor.ids = ids
	editor.options = {}
	editor.selected_index = 1
	editor.selected_id = nil
	for index,id in ipairs(ids) do
		local rewrite = rewrites[tostring(id)] or {}
		local display_name = tostring(rewrite.Name or "")
		if display_name == "" and Isaac.GetItemConfig then
			local config = Isaac.GetItemConfig():GetCollectible(id)
			display_name = config and tostring(config.Name or "") or ""
		end
		table.insert(editor.options,tostring(id).." - "..display_name)
		if id == previous_id then editor.selected_index = index end
	end
	if #ids > 0 then
		editor.selected_id = ids[editor.selected_index] or ids[1]
	else
		editor.options = {text("spectral_no_entries")}
	end
	editor.signature = signature
	spectral_load_selected()
	return true
end

local function spectral_select(index,value)
	local editor = item.spectral_editor
	if #editor.ids == 0 then return end
	local selected = nil
	for option_index,option in ipairs(editor.options) do
		if option == value then selected = option_index break end
	end
	if selected == nil then
		selected = math.max(1,math.min(#editor.ids,(tonumber(index) or 0) + 1))
	end
	editor.selected_index = selected
	editor.selected_id = editor.ids[selected]
	spectral_load_selected()
end

local function create_spectral_editor_panel(parent_id)
	local prefix = item.debug_id.."_SpectralSwordEditor"
	local group_id = prefix.."_Rewrites"
	local combo_id = prefix.."_Entry"
	local name_id = prefix.."_Name"
	local description_id = prefix.."_Description"

	spectral_refresh(true)
	local group = add_group(parent_id, group_id, text("group_spectral_rewrites"))
	add_text(group,text("spectral_editor_help"))
	ImGui.AddCombobox(group,combo_id,text("spectral_entry"),spectral_select,item.spectral_editor.options,math.max(0,item.spectral_editor.selected_index - 1))
	ImGui.AddCallback(combo_id,ImGuiCallback.Render,function()
		spectral_refresh(false)
		ImGui.UpdateData(combo_id,ImGuiData.ListValues,item.spectral_editor.options)
		ImGui.UpdateData(combo_id,ImGuiData.Value,math.max(0,item.spectral_editor.selected_index - 1))
	end)

	ImGui.AddInputText(group,name_id,text("spectral_name"),function(value)
		item.spectral_editor.draft_name = tostring(value or "")
	end,item.spectral_editor.draft_name,"")
	ImGui.AddCallback(name_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(name_id,ImGuiData.Value,item.spectral_editor.draft_name)
	end)

	ImGui.AddInputTextMultiline(group,description_id,text("spectral_description"),function(value)
		item.spectral_editor.draft_description = tostring(value or "")
	end,item.spectral_editor.draft_description,8)
	ImGui.AddCallback(description_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(description_id,ImGuiData.Value,item.spectral_editor.draft_description)
	end)

	ImGui.AddButton(group,prefix.."_Save",text("spectral_save"),imgui_layout.guard_restricted(function()
		local editor = item.spectral_editor
		if editor.selected_id == nil then push_notice(text("spectral_no_selection"),error_notice_type()) return end
		local rewrite = spectral_data().rewrites[tostring(editor.selected_id)] or {}
		rewrite.Name = editor.draft_name
		rewrite.Desc = editor.draft_description
		spectral_data().rewrites[tostring(editor.selected_id)] = rewrite
		editor.signature = nil
		save_mod_data()
		spectral_refresh(true)
		push_notice(text("spectral_saved_notice"))
	end))
	ImGui.AddElement(group,"",ImGuiElement.SameLine)
	ImGui.AddButton(group,prefix.."_Reload",text("spectral_reload"),imgui_layout.guard_restricted(function()
		if item.spectral_editor.selected_id == nil then push_notice(text("spectral_no_selection"),error_notice_type()) return end
		spectral_load_selected()
	end))

	ImGui.AddButton(group,prefix.."_Delete",text("spectral_delete"),imgui_layout.guard_restricted(function()
		local editor = item.spectral_editor
		if editor.selected_id == nil then push_notice(text("spectral_no_selection"),error_notice_type()) return end
		local key = tostring(editor.selected_id)
		local rewrite = spectral_data().rewrites[key]
		editor.last_deleted = {id = editor.selected_id,rewrite = {Name = rewrite and rewrite.Name,Desc = rewrite and rewrite.Desc}}
		spectral_data().rewrites[key] = nil
		editor.selected_id = nil
		editor.signature = nil
		save_mod_data()
		spectral_refresh(true)
		push_notice(text("spectral_deleted_notice"))
	end))
	ImGui.AddElement(group,"",ImGuiElement.SameLine)
	ImGui.AddButton(group,prefix.."_UndoDelete",text("spectral_undo_delete"),function()
		local deleted = item.spectral_editor.last_deleted
		if deleted == nil then push_notice(text("spectral_nothing_to_undo"),error_notice_type()) return end
		spectral_data().rewrites[tostring(deleted.id)] = {
			Name = deleted.rewrite.Name,
			Desc = deleted.rewrite.Desc,
		}
		item.spectral_editor.selected_id = deleted.id
		item.spectral_editor.last_deleted = nil
		item.spectral_editor.signature = nil
		save_mod_data()
		spectral_refresh(true)
		push_notice(text("spectral_restored_notice"))
	end)
	ImGui.AddButton(group,prefix.."_ClearAll",text("spectral_clear_all"),imgui_layout.guard_restricted(function()
		spectral_data().rewrites = {}
		item.spectral_editor.selected_id = nil
		item.spectral_editor.last_deleted = nil
		item.spectral_editor.signature = nil
		save_mod_data()
		spectral_refresh(true)
		push_notice(text("spectral_cleared_notice"))
	end))
end

local function add_live_broadcast_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupLiveBroadcast",text("live_item"))
	add_checkbox(group,"QingRemasterOptions_LiveAutoLive",text("auto_live"),{"Auto_Live"},text("auto_live_help"))
	add_drag_float(group,"QingRemasterOptions_LiveInterval",text("live_interval"),{"QingRemasterOptions","Live","MessageIntervalScale"},text("live_interval_help"),0.05,0.25,4,"%.2fx")
	add_drag_float(group,"QingRemasterOptions_LiveSoftLimit",text("live_soft_limit"),{"QingRemasterOptions","Live","BulletSoftLimit"},text("live_soft_limit_help"),1,10,300,"%.0f")
	add_drag_float(group,"QingRemasterOptions_LiveHardLimit",text("live_hard_limit"),{"QingRemasterOptions","Live","BulletHardLimit"},text("live_hard_limit_help"),1,20,500,"%.0f")
	add_drag_float(group,"QingRemasterOptions_LiveSpeed",text("live_speed"),{"QingRemasterOptions","Live","BulletSpeed"},text("live_speed_help"),0.05,0.25,6,"%.2f")
	add_drag_float(group,"QingRemasterOptions_LiveScale",text("live_scale"),{"QingRemasterOptions","Live","BulletScale"},text("live_scale_help"),0.05,0.5,2,"%.2fx")
	add_drag_float(group,"QingRemasterOptions_LiveOpacity",text("live_opacity"),{"QingRemasterOptions","Live","BulletOpacity"},text("live_opacity_help"),0.05,0.1,1,"%.2f")
end

local function add_ritual_sting_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupRitualSting",text("group_ritual_sting"))
	add_text(group,text("ritual_sting_help"))
	local ritual_sting = require("Qing_Remaster_scripts.items.Item_Ritual_Sting")
	local labels = {"red","orange","yellow","green","blue","purple"}
	local cap = ritual_sting.cap or 200
	local threshold = ritual_sting.threshold or 100
	local function any_player()
		if not Isaac.IsInGame or not Isaac.IsInGame() then return nil end
		return Game():GetPlayer(0)
	end
	local function holder()
		if not Isaac.IsInGame or not Isaac.IsInGame() then return nil end
		for player_num = 0,Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(player_num)
			if player and player:HasCollectible(ritual_sting.entity) then return player end
		end
		return nil
	end
	local function ensure_holder()
		local player = holder()
		if player then return player end
		player = any_player()
		if not player then return nil end
		player:AddCollectible(ritual_sting.entity)
		return player
	end
	for color_id,label in ipairs(labels) do
		local element_id = "QingRemasterOptions_RitualSting_"..label
		local function set_value(value)
			local player = ensure_holder()
			if not player then push_notice(text("start_run_first"),error_notice_type()) return end
			ritual_sting.get_values(player)[color_id] = math.max(0,math.min(cap,tonumber(value) or 0))
			ritual_sting.refresh_effects(player,true)
		end
		ImGui.AddDragFloat(group,element_id,text("ritual_sting_"..label),set_value,threshold,1,0,cap,"%.0f")
		ImGui.AddCallback(element_id,ImGuiCallback.Render,function()
			local player = holder()
			local value = player and ritual_sting.get_values(player)[color_id] or 0
			ImGui.UpdateData(element_id,ImGuiData.Value,value)
		end)
		ImGui.AddCallback(element_id,ImGuiCallback.Edited,set_value)
	end
	ImGui.AddButton(group,"QingRemasterOptions_RitualStingGive",text("ritual_sting_give"),function()
		local player = ensure_holder()
		if not player then push_notice(text("start_run_first"),error_notice_type()) return end
		push_notice(text("ritual_sting_give_ok"),0)
	end)
	imgui_layout.set_helpmarker("QingRemasterOptions_RitualStingGive",text("ritual_sting_give_help"))
	ImGui.AddButton(group,"QingRemasterOptions_RitualStingEnableBlue",text("ritual_sting_enable_blue"),function()
		local player = ensure_holder()
		if not player then push_notice(text("start_run_first"),error_notice_type()) return end
		local values = ritual_sting.get_values(player)
		values[5] = math.max(values[5] or 0, threshold)
		ritual_sting.refresh_effects(player,true)
		push_notice(text("ritual_sting_enable_blue_ok"),0)
	end)
	imgui_layout.set_helpmarker("QingRemasterOptions_RitualStingEnableBlue",text("ritual_sting_enable_blue_help"))
	ImGui.AddButton(group,"QingRemasterOptions_RitualStingFillAll",text("ritual_sting_fill_all"),function()
		local player = ensure_holder()
		if not player then push_notice(text("start_run_first"),error_notice_type()) return end
		local values = ritual_sting.get_values(player)
		for color_id = 1,6 do values[color_id] = threshold end
		ritual_sting.refresh_effects(player,true)
	end)
	ImGui.AddButton(group,"QingRemasterOptions_RitualStingReset",text("ritual_sting_reset"),function()
		local player = holder() or any_player()
		if not player or not player:HasCollectible(ritual_sting.entity) then
			push_notice(text("start_run_first"),error_notice_type())
			return
		end
		local values = ritual_sting.get_values(player)
		for color_id = 1,6 do values[color_id] = 0 end
		ritual_sting.refresh_effects(player,true)
	end)
end

local function add_death_sentence_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupDeathSentence",text("group_death_sentence"))
	add_text(group,text("death_sentence_help"))
	local death_sentence = require("Qing_Remaster_scripts.items.Item_Death_Sentence")
	local function holder()
		if not Isaac.IsInGame or not Isaac.IsInGame() then return nil end
		for player_num = 0,Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(player_num)
			if player:HasCollectible(death_sentence.entity) then return player end
		end
	end

	local death_id = "QingRemasterOptions_DeathSentence_DeathWord"
	ImGui.AddInputText(group,death_id,text("death_sentence_death_word"),function(value)
		death_sentence.set_death_word(value)
	end,death_sentence.get_death_word(),"")
	ImGui.AddCallback(death_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(death_id,ImGuiData.Value,death_sentence.get_death_word())
	end)

	local letters_id = "QingRemasterOptions_DeathSentence_Letters"
	ImGui.AddInputText(group,letters_id,text("death_sentence_letters"),function(value)
		local player = holder()
		if not player then push_notice(text("start_run_first"),error_notice_type()) return end
		death_sentence.set_letters_string(player,value)
	end,"","")
	ImGui.AddCallback(letters_id,ImGuiCallback.Render,function()
		local player = holder()
		ImGui.UpdateData(letters_id,ImGuiData.Value,player and death_sentence.get_letters_string(player) or "")
	end)

	set_module_footer("item_death_sentence", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		local player = holder()
		if not player then push_notice(text("start_run_first"),error_notice_type()) return end
		death_sentence.reset_debug(player)
	end,
})
end

local function add_book_of_voice_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupBookOfVoice",text("group_book_of_voice"))
	add_text(group,text("book_of_voice_help"))
	local voice = require("Qing_Remaster_scripts.items.Item_Book_of_Voice")
	add_checkbox(group,"QingRemasterOptions_VoiceForceSeija",text("book_of_voice_seija"),{"QingRemasterOptions","Debug","VoiceForceSeijaDefy"},text("book_of_voice_seija_help"))
	local function holder()
		if not Isaac.IsInGame or not Isaac.IsInGame() then return nil end
		for player_num = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(player_num)
			if player:HasCollectible(voice.entity) or (voice.voice_entity and player:HasCollectible(voice.voice_entity)) then return player end
		end
		return Game():GetPlayer(0)
	end
	local poss_id = "QingRemasterOptions_VoicePossession"
	ImGui.AddDragFloat(group,poss_id,text("book_of_voice_possession"),function(value)
		local player = holder()
		if not player then return end
		voice.debug_set_possession(player, value)
	end,0,1,0,20,"%.0f")
	ImGui.AddCallback(poss_id,ImGuiCallback.Render,function()
		local player = holder()
		ImGui.UpdateData(poss_id,ImGuiData.Value,player and voice.debug_get_possession(player) or 0)
	end)
	imgui_layout.set_helpmarker(poss_id,text("book_of_voice_possession_help"))
	set_module_footer("item_book_of_voice", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		item.set_value({"QingRemasterOptions","Debug","VoiceForceSeijaDefy"},false)
		local player = holder()
		if player then voice.debug_set_possession(player, 0) end
	end,
})
end

local function add_regenesis_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupRegenesis",text("group_regenesis"))
	add_text(group,text("regenesis_help"))
	local regenesis = require("Qing_Remaster_scripts.items.Item_Regenesis")
	local capture_vfx = require("Qing_Remaster_scripts.items.regenesis_capture_vfx")

	local function fmt_record(rec)
		if not rec then return "(none)" end
		local parts = {tostring(rec.kind)}
		if rec.collectible_id then parts[#parts + 1] = "id=" .. tostring(rec.collectible_id) end
		if rec.subtype then parts[#parts + 1] = "sub=" .. tostring(rec.subtype) end
		parts[#parts + 1] = "x" .. tostring(rec.amount or 1)
		if rec.rooms then
			parts[#parts + 1] = "progress=" .. tostring(rec.progress or 0) .. "/" .. tostring(rec.rooms)
		end
		return table.concat(parts, " ")
	end

	local function format_queue_lines(entries, limit, dormant)
		limit = limit or 12
		if not entries or #entries == 0 then
			return dormant and "Dormant [0]" or "Stored [0]"
		end
		local lines = {}
		local shown = math.min(#entries, limit)
		if dormant then
			lines[#lines + 1] = string.format("Dormant [%d / 12] — newest first", #entries)
		else
			lines[#lines + 1] = string.format("Stored [%d / 12] — next restore first", #entries)
		end
		for i = 1, shown do
			local e = entries[i]
			local mark = ""
			if e.is_top then mark = " [TOP]"
			elseif e.newest then mark = " newest"
			elseif dormant and i == shown and #entries == shown then mark = " oldest"
			end
			lines[#lines + 1] = string.format(
				"#%d%s  %s",
				e.index or i,
				mark,
				fmt_record(e)
			)
			if e.preview and e.preview ~= "" then
				lines[#lines + 1] = "        restore=" .. tostring(e.preview)
			end
		end
		if #entries > limit then
			lines[#lines + 1] = string.format("... +%d older records", #entries - limit)
		end
		return table.concat(lines, "\n")
	end

	-- ① Runtime Status
	add_separator(group)
	add_text(group, text("regenesis_runtime_status"))
	local runtime_id = "QingRemasterOptions_RegenesisRuntimeStatus"
	imgui_layout.add_wrapped_text(group, runtime_id, "...")
	ImGui.AddCallback(runtime_id, ImGuiCallback.Render, function()
		local s = regenesis.get_debug_snapshot and regenesis.get_debug_snapshot() or {}
		local q = s.queue or {}
		local room = s.room or {}
		local rec = s.recovery or {}
		local top = q.top
		imgui_layout.update_text(runtime_id, string.format(
			"Player: P%s\nHas Regenesis: %s\nFamiliars: %s\nActive jobs: %s\nRoom eligible: %s\nRoom settled: %s\n\nQueue: %s / %s\nDormant: %s / %s\n\nCurrent target: %s\nProgress: %s / %s\nRooms remaining: %s\n\nLast loss: %s",
			tostring(s.player_index or "?"),
			tostring(s.has_regenesis),
			tostring(s.familiars or (s.familiar and s.familiar.count) or 0),
			tostring(s.active_jobs or 0),
			tostring(room.eligible),
			tostring(room.rewarded),
			tostring(q.stored_count or 0),
			tostring(q.cap or 12),
			tostring(q.dormant_count or 0),
			tostring(q.cap or 12),
			fmt_record(top),
			tostring(rec.progress or 0),
			tostring(rec.rooms_required or 0),
			tostring(rec.rooms_remaining or 0),
			fmt_record(q.last_loss)
		))
	end)

	-- ② Queue Inspector
	add_separator(group)
	add_text(group, text("regenesis_queue_inspector"))
	local stored_id = "QingRemasterOptions_RegenesisStoredQueue"
	local dormant_id = "QingRemasterOptions_RegenesisDormantQueue"
	imgui_layout.add_wrapped_text(group, stored_id, "Stored ...")
	imgui_layout.add_wrapped_text(group, dormant_id, "Dormant ...")
	ImGui.AddCallback(stored_id, ImGuiCallback.Render, function()
		local q = regenesis.debug_queue_entries and regenesis.debug_queue_entries() or {stored = {}}
		imgui_layout.update_text(stored_id, format_queue_lines(q.stored, 12, false))
	end)
	ImGui.AddCallback(dormant_id, ImGuiCallback.Render, function()
		local q = regenesis.debug_queue_entries and regenesis.debug_queue_entries() or {dormant = {}}
		imgui_layout.update_text(dormant_id, format_queue_lines(q.dormant, 12, true))
	end)

	-- ③ Simulation / Recovery
	add_separator(group)
	add_text(group, text("regenesis_simulation"))
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisSimClear", text("regenesis_simulate_room_clear"), function()
		if regenesis.debug_simulate_room_clear then regenesis.debug_simulate_room_clear() end
		push_notice("Regenesis: simulate combat-room clear")
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisAddProgress", text("regenesis_add_progress"), function()
		if regenesis.debug_add_progress then regenesis.debug_add_progress(nil, 1) end
		push_notice("Regenesis: active jobs +1")
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisTryRestore", text("regenesis_try_restore"), function()
		if regenesis.try_restore then regenesis.try_restore(Isaac.GetPlayer(0)) end
		push_notice("Regenesis: try restore")
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisForceNext", text("regenesis_force_next_restore"), function()
		if regenesis.debug_force_next_restore then regenesis.debug_force_next_restore() end
		push_notice("Regenesis: force next restore")
	end)

	add_text(group, text("regenesis_inject_header"))
	local amount_id = "QingRemasterOptions_RegenesisResourceAmount"
	ImGui.AddDragFloat(group, amount_id, text("regenesis_resource_amount"), function(value)
		local n = math.max(1, math.min(99, math.floor(tonumber(value) or 1)))
		if regenesis.set_visual_tune then regenesis.set_visual_tune("resource_amount", n) end
	end, 1, 1, 1, 99, "%.0f")
	local function inject(kind, extra)
		local tune = regenesis.get_visual_tune and regenesis.get_visual_tune() or {}
		local amount = math.max(1, math.floor(tonumber(tune.resource_amount) or 1))
		local loss = {kind = kind, amount = amount, source = "debug"}
		if extra then for k, v in pairs(extra) do loss[k] = v end end
		if regenesis.debug_inject_loss then regenesis.debug_inject_loss(nil, loss) end
		push_notice("Regenesis inject " .. kind .. " x" .. tostring(amount))
	end
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisInjCoin", text("regenesis_inject_coin"), function() inject("coin") end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisInjBomb", text("regenesis_inject_bomb"), function() inject("bomb") end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisInjKey", text("regenesis_inject_key"), function() inject("key") end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisInjCharge", text("regenesis_inject_charge"), function() inject("charge") end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisInjSoul", text("regenesis_inject_soul"), function() inject("soul_heart") end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisInjCard", text("regenesis_inject_card"), function()
		inject("card", {subtype = Card.CARD_FOOL})
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisInjQ0", text("regenesis_inject_q0"), function()
		local id = regenesis.debug_find_collectible_by_quality and regenesis.debug_find_collectible_by_quality(0)
		if id then inject("collectible", {collectible_id = id}) else push_notice("No Q0 collectible found") end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisInjQ4", text("regenesis_inject_q4"), function()
		local id = regenesis.debug_find_collectible_by_quality and regenesis.debug_find_collectible_by_quality(4)
		if id then inject("collectible", {collectible_id = id}) else push_notice("No Q4 collectible found") end
	end)

	ImGui.AddButton(group, "QingRemasterOptions_RegenesisClearStored", text("regenesis_clear_stored"), function()
		if regenesis.debug_clear_stored then regenesis.debug_clear_stored() end
		push_notice("Regenesis stored cleared")
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisClearDormant", text("regenesis_clear_dormant"), function()
		if regenesis.debug_clear_dormant then regenesis.debug_clear_dormant() end
		push_notice("Regenesis dormant cleared")
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisReset", text("regenesis_reset_state"), function()
		if regenesis.reset_debug then regenesis.reset_debug() end
		push_notice("Regenesis state reset")
	end)

	-- ④ Familiar & Capture VFX
	add_separator(group)
	add_text(group, text("regenesis_familiar_vfx"))
	local fam_id = "QingRemasterOptions_RegenesisFamInfo"
	imgui_layout.add_wrapped_text(group, fam_id, "...")
	ImGui.AddCallback(fam_id, ImGuiCallback.Render, function()
		local s = regenesis.get_debug_snapshot and regenesis.get_debug_snapshot() or {}
		local f = s.familiar or {}
		local pos = f.position
		local pos_s = pos and string.format("(%.1f, %.1f)", pos.x, pos.y) or "-"
		local count = capture_vfx.get_particle_count and capture_vfx.get_particle_count() or 0
		imgui_layout.update_text(fam_id, string.format(
			"Familiar present: %s\nVariant: %s\nInitSeed: %s\nOwner: P%s\nPosition: %s\nAnimation: %s\n\nCapture particles: %s",
			tostring(f.present),
			tostring(f.variant),
			tostring(f.init_seed or "-"),
			tostring(f.owner_index or "?"),
			pos_s,
			tostring(f.animation or "-"),
			tostring(count)
		))
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisRefreshFam", text("regenesis_refresh_familiar"), function()
		if regenesis.debug_refresh_familiar then regenesis.debug_refresh_familiar() end
		push_notice("Regenesis familiar cache re-evaluated")
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisDumpFam", text("regenesis_dump_familiar"), function()
		local locate = regenesis.debug_locate_familiar and regenesis.debug_locate_familiar() or "n/a"
		push_notice(tostring(locate))
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisTestCoinVfx", text("regenesis_test_coin_vfx"), function()
		if capture_vfx.debug_spawn then capture_vfx.debug_spawn(nil, {kind = "coin", amount = 1}) end
		push_notice("Capture VFX: coin")
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisTestItemVfx", text("regenesis_test_item_vfx"), function()
		local id = regenesis.debug_find_collectible_by_quality and regenesis.debug_find_collectible_by_quality(2)
		if capture_vfx.debug_spawn then
			capture_vfx.debug_spawn(nil, {kind = "collectible", collectible_id = id or 1, amount = 1})
		end
		push_notice("Capture VFX: collectible")
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RegenesisClearVfx", text("regenesis_clear_vfx"), function()
		if capture_vfx.clear_all then capture_vfx.clear_all() end
		push_notice("Capture VFX cleared")
	end)

	-- Charge / Effort visual
	add_separator(group)
	add_text(group, text("regenesis_charge_visual"))
	local visual_id = "QingRemasterOptions_RegenesisChargeVisual"
	imgui_layout.add_wrapped_text(group, visual_id, "...")
	ImGui.AddCallback(visual_id, ImGuiCallback.Render, function()
		local s = regenesis.get_debug_snapshot and regenesis.get_debug_snapshot() or {}
		local rec = s.recovery or {}
		local top = (s.queue or {}).top
		local pres = s.presentation or {}
		local cap = capture_vfx.get_status and capture_vfx.get_status() or {}
		imgui_layout.update_text(visual_id, string.format(
			"Current visual target: %s\nrooms=%s  progress=%s/%s  interval=%s\nPresentation: %s  frame=%s\nCapture: particles=%s  phase=%s",
			top and (tostring(top.kind) .. (top.collectible_id and (" " .. tostring(top.collectible_id)) or "")) or "(none)",
			tostring(rec.rooms_required or 0),
			tostring(rec.progress or 0),
			tostring(rec.rooms_required or 0),
			tostring(pres.interval or "-"),
			tostring(pres.mode or "idle"),
			tostring(pres.frame or "-"),
			tostring(cap.count or 0),
			tostring(cap.phase or "-")
		))
	end)
	local tune = regenesis.get_visual_tune and regenesis.get_visual_tune() or {}
	ImGui.AddCheckbox(group, "QingRemasterOptions_RegenesisEffort", text("regenesis_effort_enabled"), function(value)
		if regenesis.set_visual_tune then regenesis.set_visual_tune("effort", value) end
	end, tune.effort ~= false)
	ImGui.AddDragFloat(group, "QingRemasterOptions_RegenesisResInterval", text("regenesis_effort_resource"), function(value)
		if regenesis.set_visual_tune then regenesis.set_visual_tune("resource_interval", math.floor(tonumber(value) or 50)) end
	end, tune.resource_interval or 50, 1, 8, 120, "%.0f")
	ImGui.AddDragFloat(group, "QingRemasterOptions_RegenesisFarInterval", text("regenesis_effort_far"), function(value)
		if regenesis.set_visual_tune then regenesis.set_visual_tune("far_interval", math.floor(tonumber(value) or 55)) end
	end, tune.far_interval or 55, 1, 8, 160, "%.0f")
	ImGui.AddDragFloat(group, "QingRemasterOptions_RegenesisNearInterval", text("regenesis_effort_near"), function(value)
		if regenesis.set_visual_tune then regenesis.set_visual_tune("near_interval", math.floor(tonumber(value) or 25)) end
	end, tune.near_interval or 25, 1, 4, 80, "%.0f")
	ImGui.AddDragFloat(group, "QingRemasterOptions_RegenesisSquashX", text("regenesis_squash_x"), function(value)
		if regenesis.set_visual_tune then regenesis.set_visual_tune("squash_x", tonumber(value) or 1.16) end
	end, tune.squash_x or 1.16, 0.01, 0.5, 1.8, "%.2f")
	ImGui.AddDragFloat(group, "QingRemasterOptions_RegenesisSquashY", text("regenesis_squash_y"), function(value)
		if regenesis.set_visual_tune then regenesis.set_visual_tune("squash_y", tonumber(value) or 0.84) end
	end, tune.squash_y or 0.84, 0.01, 0.4, 1.6, "%.2f")
	ImGui.AddDragFloat(group, "QingRemasterOptions_RegenesisStretchX", text("regenesis_stretch_x"), function(value)
		if regenesis.set_visual_tune then regenesis.set_visual_tune("stretch_x", tonumber(value) or 0.86) end
	end, tune.stretch_x or 0.86, 0.01, 0.4, 1.6, "%.2f")
	ImGui.AddDragFloat(group, "QingRemasterOptions_RegenesisStretchY", text("regenesis_stretch_y"), function(value)
		if regenesis.set_visual_tune then regenesis.set_visual_tune("stretch_y", tonumber(value) or 1.18) end
	end, tune.stretch_y or 1.18, 0.01, 0.5, 1.8, "%.2f")
	ImGui.AddDragFloat(group, "QingRemasterOptions_RegenesisRedOffset", text("regenesis_red_offset"), function(value)
		if regenesis.set_visual_tune then regenesis.set_visual_tune("red_offset", tonumber(value) or 0.45) end
	end, tune.red_offset or 0.45, 0.01, 0, 1, "%.2f")
	ImGui.AddDragFloat(group, "QingRemasterOptions_RegenesisEffortDur", text("regenesis_effort_duration"), function(value)
		if regenesis.set_visual_tune then regenesis.set_visual_tune("effort_duration", math.floor(tonumber(value) or 12)) end
	end, tune.effort_duration or 12, 1, 4, 24, "%.0f")

	add_text(group, text("regenesis_capture_timing"))
	local cap_tune = capture_vfx.get_tune and capture_vfx.get_tune() or {}
	local function cap_drag(id, label_key, key, fallback, speed, min_v, max_v, fmt)
		ImGui.AddDragFloat(group, id, text(label_key), function(value)
			if capture_vfx.set_tune then capture_vfx.set_tune(key, tonumber(value) or fallback) end
		end, cap_tune[key] or fallback, speed, min_v, max_v, fmt)
	end
	cap_drag("QingRemasterOptions_RegenesisRise", "regenesis_rise_frames", "rise", 10, 1, 1, 40, "%.0f")
	cap_drag("QingRemasterOptions_RegenesisTravel", "regenesis_travel_frames", "travel", 18, 1, 1, 60, "%.0f")
	cap_drag("QingRemasterOptions_RegenesisHover", "regenesis_hover_frames", "hover", 12, 1, 1, 40, "%.0f")
	cap_drag("QingRemasterOptions_RegenesisDrop", "regenesis_drop_frames", "drop", 8, 1, 1, 30, "%.0f")
	cap_drag("QingRemasterOptions_RegenesisHoverH", "regenesis_hover_height", "hover_height", 30, 1, 0, 80, "%.0f")

	set_module_footer("item_regenesis", {
		restore_label = text("restore_item_defaults"),
		restore = function()
			if regenesis.reset_debug then regenesis.reset_debug() end
		end,
	})
end

local function add_bloody_map_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupBloodyMap",text("group_bloody_map"))
	add_text(group,text("bloody_map_help"))
	add_checkbox(group,"QingRemasterOptions_BloodyMapForceSeija",text("bloody_map_seija"),{"QingRemasterOptions","Debug","BloodyMapForceSeijaEnhancement"},text("bloody_map_seija_help"))
	add_drag_float(group,"QingRemasterOptions_BloodyMapSpawnChance",text("bloody_map_spawn_chance"),{"QingRemasterOptions","Debug","BloodyMapMessengerSpawnChance"},text("bloody_map_spawn_chance_help"),0.01,0,1,"%.2f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerPayNothing",text("bloody_messenger_pay_nothing"),{"QingRemasterOptions","Debug","BloodyMessengerPayNothingChance"},text("bloody_messenger_pay_nothing_help"),0.01,0,1,"%.2f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerDouble",text("bloody_messenger_double"),{"QingRemasterOptions","Debug","BloodyMessengerDoubleRewardChance"},text("bloody_messenger_double_help"),0.01,0,1,"%.2f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerWeightNothing",text("bloody_messenger_weight_nothing"),{"QingRemasterOptions","Debug","BloodyMessengerWeightNothing"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerWeightUltra",text("bloody_messenger_weight_ultra"),{"QingRemasterOptions","Debug","BloodyMessengerWeightUltraRoom"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerWeightKey",text("bloody_messenger_weight_key"),{"QingRemasterOptions","Debug","BloodyMessengerWeightCrackedKey"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerWeightItem",text("bloody_messenger_weight_item"),{"QingRemasterOptions","Debug","BloodyMessengerWeightItem"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerBoostUltra",text("bloody_messenger_boost_ultra"),{"QingRemasterOptions","Debug","BloodyMessengerBoostedWeightUltraRoom"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerBoostKey",text("bloody_messenger_boost_key"),{"QingRemasterOptions","Debug","BloodyMessengerBoostedWeightCrackedKey"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerBoostItem",text("bloody_messenger_boost_item"),{"QingRemasterOptions","Debug","BloodyMessengerBoostedWeightItem"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMapUltraAmount",text("bloody_map_ultra_amount"),{"QingRemasterOptions","Debug","BloodyMapUltraGrantAmount"},text("bloody_map_ultra_amount_help"),1,1,10,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMapUltraMax",text("bloody_map_ultra_max"),{"QingRemasterOptions","Debug","BloodyMapUltraGrantMax"},text("bloody_map_ultra_max_help"),1,0,20,"%.0f")
	set_module_footer("item_bloody_map", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		local defaults = {
			BloodyMapForceSeijaEnhancement = false,
			BloodyMapMessengerSpawnChance = 0.4,
			BloodyMessengerPayNothingChance = 0.3,
			BloodyMessengerDoubleRewardChance = 0.3,
			BloodyMessengerWeightNothing = 40,
			BloodyMessengerWeightUltraRoom = 15,
			BloodyMessengerWeightCrackedKey = 25,
			BloodyMessengerWeightItem = 20,
			BloodyMessengerBoostedWeightUltraRoom = 30,
			BloodyMessengerBoostedWeightCrackedKey = 40,
			BloodyMessengerBoostedWeightItem = 30,
			BloodyMapUltraGrantAmount = 1,
			BloodyMapUltraGrantMax = 2,
		}
		for key,value in pairs(defaults) do item.set_value({"QingRemasterOptions","Debug",key},value) end
	end,
})
end

local function add_zero_presence_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupZeroPresence",text("group_zero_presence"))
	add_text(group,text("zero_presence_help"))
	local zp = require("Qing_Remaster_scripts.items.Item_Zero_Presence")
	ImGui.AddButton(group, "QingRemasterOptions_ZeroPresenceForceEscape", text("zero_presence_force_escape"), function()
		if zp.debug_force_next_escape then
			zp.debug_force_next_escape()
		end
		push_notice(text("zero_presence_force_escape_notice"))
	end)
	set_module_footer("item_zero_presence", {
		restore_label = text("restore_item_defaults"),
		restore = function()
			if zp.debug_clear_force_escape then
				zp.debug_clear_force_escape()
			end
		end,
	})
end

local function add_perhaps_chosen_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupPerhapsChosen",text("group_perhaps_chosen"))
	add_text(group,text("perhaps_chosen_help"))
	local pc = require("Qing_Remaster_scripts.items.Item_Perhaps_Chosen")

	local status_id = "QingRemasterOptions_PerhapsChosenStatus"
	imgui_layout.add_wrapped_text(group, status_id, text("perhaps_chosen_status")..": ...")
	ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
		local body = text("perhaps_chosen_status")..": "..(pc.debug_status_text and pc.debug_status_text() or "?")
		imgui_layout.update_text(status_id, body)
	end)

	add_checkbox(group,"QingRemasterOptions_PerhapsChosenForceSeija",text("perhaps_chosen_seija"),{"QingRemasterOptions","Debug","PerhapsChosenForceSeija"},text("perhaps_chosen_seija_help"))

	local pending_id = "QingRemasterOptions_PerhapsChosenPending"
	ImGui.AddDragFloat(group, pending_id, text("perhaps_chosen_pending"), function(value)
		pc.set_pending_count(value)
	end, pc.get_pending_count(), 1, 0, 32, "%.0f")
	ImGui.AddCallback(pending_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(pending_id, ImGuiData.Value, pc.get_pending_count())
	end)
	ImGui.AddCallback(pending_id, ImGuiCallback.Edited, function(value)
		pc.set_pending_count(value)
	end)
	imgui_layout.set_helpmarker(pending_id, text("perhaps_chosen_pending_help"))

	ImGui.AddButton(group, "QingRemasterOptions_PerhapsChosenForceAttach", text("perhaps_chosen_force_attach"), function()
		if not Isaac.IsInGame or not Isaac.IsInGame() then
			push_notice(text("start_run_first"), error_notice_type())
			return
		end
		local ok, err = pc.debug_force_attach()
		if ok then return end
		if err == "empty_queue" then
			push_notice(text("perhaps_chosen_attach_empty"), error_notice_type())
		elseif err == "no_host" then
			push_notice(text("perhaps_chosen_attach_no_host"), error_notice_type())
		else
			push_notice(text("start_run_first"), error_notice_type())
		end
	end)
	imgui_layout.set_helpmarker("QingRemasterOptions_PerhapsChosenForceAttach", text("perhaps_chosen_force_attach_help"))

	ImGui.AddButton(group, "QingRemasterOptions_PerhapsChosenClearPending", text("perhaps_chosen_clear_pending"), function()
		pc.debug_remove_active_carriers(true)
		pc.debug_clear_pending()
	end)

	ImGui.AddButton(group, "QingRemasterOptions_PerhapsChosenDump", "Dump Q/Carriers", function()
		local body = (pc.debug_status_text and pc.debug_status_text()) or "?"
		push_notice(body)
	end)

	ImGui.AddButton(group, "QingRemasterOptions_PerhapsChosenForceReroll", "Force reroll carriers", function()
		if not Isaac.IsInGame or not Isaac.IsInGame() then
			push_notice(text("start_run_first"), error_notice_type())
			return
		end
		local ok, n = pc.debug_force_reroll_carriers()
		if ok then
			push_notice("rerolled " .. tostring(n))
		else
			push_notice("no active carrier", error_notice_type())
		end
	end)

	set_module_footer("item_perhaps_chosen", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		item.set_value({"QingRemasterOptions","Debug","PerhapsChosenForceSeija"},false)
		pc.debug_remove_active_carriers(true)
		pc.debug_clear_pending()
	end,
})
end

local function add_gospel_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupGospel",text("group_gospel"))
	add_text(group,text("gospel_help"))
	add_checkbox(group,"QingRemasterOptions_GospelForceSeija",text("gospel_seija"),{"QingRemasterOptions","Debug","GospelForceSeija"},text("gospel_seija_help"))
	set_module_footer("item_gospel", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		item.set_value({"QingRemasterOptions","Debug","GospelForceSeija"},false)
	end,
})
	add_text(group, "Attack inheritance / member / Gospel tag audit:\nDebug -> Systems -> Attack Audit")
end

local function add_dark_mysticism_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupDarkMysticism",text("group_dark_mysticism"))
	add_text(group,text("dark_mysticism_help"))
	add_checkbox(group,"QingRemasterOptions_DarkMysticismForceSeija",text("dark_mysticism_seija"),{"QingRemasterOptions","Debug","DarkMysticismForceSeija"},text("dark_mysticism_seija_help"))
	ImGui.AddButton(group,"QingRemasterOptions_DarkMysticismApplyFear",text("dark_mysticism_apply_fear"),function()
		if not Isaac.IsInGame or not Isaac.IsInGame() then
			push_notice(text("start_run_first"),error_notice_type())
			return
		end
		local Player_Pseudo_Fear = require("Qing_Remaster_scripts.mimics.Player_Pseudo_Fear_holder")
		local player = Game():GetPlayer(0)
		if player then Player_Pseudo_Fear.apply(player) end
	end)
	imgui_layout.set_helpmarker("QingRemasterOptions_DarkMysticismApplyFear",text("dark_mysticism_apply_fear_help"))
	set_module_footer("item_dark_mysticism", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		item.set_value({"QingRemasterOptions","Debug","DarkMysticismForceSeija"},false)
	end,
})
end

local function add_suture_needle_group(parent_id)
	local zh = language_key() == "zh"
	local group = add_group(parent_id,"QingRemasterOptions_GroupSutureNeedle",text("group_suture_needle"))
	add_text(group,text("suture_needle_help"))
	add_checkbox(group,"QingRemasterOptions_SutureNeedleForceSeija",text("suture_needle_seija"),{"QingRemasterOptions","Debug","SutureNeedleForceSeija"},text("suture_needle_seija_help"))

	local profiles = require("Qing_Remaster_scripts.config.runtime_stitch_enemy_profiles")
	local function pair_mod()
		local ok, mod = pcall(require, "Qing_Remaster_scripts.others.runtime_stitch_pair")
		if ok then return mod end
		return nil
	end
	local function gameplay_mod()
		local ok, mod = pcall(require, "Qing_Remaster_scripts.others.runtime_stitch_gameplay")
		if ok then return mod end
		return nil
	end
	local function require_in_game()
		if not Isaac.IsInGame or not Isaac.IsInGame() then
			push_notice(text("start_run_first"), error_notice_type())
			return false
		end
		return true
	end

	local pool_sec = imgui_layout.add_section(
		group,
		"QingRemasterOptions_SutureNeedlePoolSec",
		zh and "正式候选池" or "Production pool"
	)
	add_text(
		pool_sec,
		zh
			and "生产界面每次只随机显示移动 3 + 攻击 3。取消重开复用同一组 pending_roll；成功缝合后才重抽。"
			or "Production UI rolls 3 movement + 3 attack. Cancel/reopen reuses pending_roll; successful stitch clears it."
	)
	local pool_status_id = "QingRemasterOptions_SutureNeedlePoolStatus"
	imgui_layout.add_wrapped_text(pool_sec, pool_status_id, "")
	ImGui.AddCallback(pool_status_id, ImGuiCallback.Render, function()
		local moves = profiles.list_movement_ids()
		local attacks = profiles.list_attack_ids()
		local lines = {}
		local move_names = {}
		for i = 1, #moves do
			move_names[i] = profiles.display_name(moves[i])
		end
		local atk_names = {}
		for i = 1, #attacks do
			atk_names[i] = profiles.display_name(attacks[i])
		end
		lines[#lines + 1] = (zh and "移动池 (" or "Movement (")
			.. tostring(#moves)
			.. "): "
			.. table.concat(move_names, ", ")
		lines[#lines + 1] = (zh and "攻击池 (" or "Attack (")
			.. tostring(#attacks)
			.. "): "
			.. table.concat(atk_names, ", ")
		local gp = gameplay_mod()
		local player = Isaac.IsInGame and Isaac.IsInGame() and Isaac.GetPlayer(0) or nil
		local pending = gp and gp.get_pending_roll and player and gp.get_pending_roll(player) or nil
		if pending then
			local pm = {}
			for i = 1, #pending.movement do
				pm[i] = profiles.display_name(pending.movement[i])
			end
			local pa = {}
			for i = 1, #pending.attack do
				pa[i] = profiles.display_name(pending.attack[i])
			end
			lines[#lines + 1] = (zh and "当前 pending 移动: " or "Pending movement: ") .. table.concat(pm, ", ")
			lines[#lines + 1] = (zh and "当前 pending 攻击: " or "Pending attack: ") .. table.concat(pa, ", ")
		else
			lines[#lines + 1] = zh and "当前 pending_roll: （无）" or "pending_roll: (none)"
		end
		imgui_layout.update_text(pool_status_id, table.concat(lines, "\n"))
	end)
	ImGui.AddButton(pool_sec, "QingRemasterOptions_SutureNeedleClearPending", zh and "清除 pending_roll" or "Clear pending_roll", function()
		local gp = gameplay_mod()
		local player = Isaac.GetPlayer(0)
		if gp and gp.clear_pending_roll and player then
			gp.clear_pending_roll(player)
			push_notice(zh and "已清除 pending_roll" or "pending_roll cleared", 0)
		end
	end)

	local matrix_sec = imgui_layout.add_section(
		group,
		"QingRemasterOptions_SutureNeedleMatrixSec",
		zh and "组合矩阵（Debug）" or "Combo matrix (Debug)"
	)
	add_text(
		matrix_sec,
		zh
			and "行=移动 / 列=攻击。点击任意格直接 spawn_pair，不耗充能、不经选择面板。不预建 49 个 preview。"
			or "Rows=movement / cols=attack. Click spawns via spawn_pair (no charge / no selection UI). No 49 previews."
	)
	local matrix_status_id = "QingRemasterOptions_SutureNeedleMatrixStatus"
	imgui_layout.add_wrapped_text(matrix_sec, matrix_status_id, "")
	ImGui.AddCallback(matrix_status_id, ImGuiCallback.Render, function()
		local p = pair_mod()
		local st = p and p.get_debug_state and p.get_debug_state() or {}
		local last = "(none)"
		if st.last_movement and st.last_attack then
			last = profiles.display_name(st.last_movement) .. " × " .. profiles.display_name(st.last_attack)
		end
		local body = (zh and "上次组合: " or "Last combo: ")
			.. last
			.. "\n"
			.. (zh and "下一组合序号: " or "Next index: ")
			.. tostring(st.next_index or 1)
		imgui_layout.update_text(matrix_status_id, body)
	end)

	imgui_layout.add_action_row(matrix_sec, {
		{
			id = "QingRemasterOptions_SutureNeedleMatrixClear",
			label = zh and "清除所有缝合体" or "Clear all pairs",
			on_click = function()
				if not require_in_game() then return end
				local p = pair_mod()
				if p and p.clear_all_pairs then
					p.clear_all_pairs("manual_cleanup")
					push_notice(zh and "已清除缝合体" or "Pairs cleared", 0)
				end
			end,
		},
		{
			id = "QingRemasterOptions_SutureNeedleMatrixRespawn",
			label = zh and "重生当前组合" or "Respawn last combo",
			on_click = function()
				if not require_in_game() then return end
				local p = pair_mod()
				if not p or not p.debug_respawn_last then return end
				local linker = p.debug_respawn_last()
				if linker then
					local st = p.get_debug_state()
					push_notice(
						(zh and "已重生 " or "Respawned ")
							.. profiles.display_name(st.last_movement)
							.. " × "
							.. profiles.display_name(st.last_attack),
						0
					)
				else
					push_notice(zh and "没有上次组合" or "No last combo", error_notice_type())
				end
			end,
		},
		{
			id = "QingRemasterOptions_SutureNeedleMatrixNext",
			label = zh and "下一组合" or "Next combo",
			on_click = function()
				if not require_in_game() then return end
				local p = pair_mod()
				if not p or not p.debug_spawn_next then return end
				local linker = p.debug_spawn_next()
				if linker then
					local st = p.get_debug_state()
					push_notice(
						(zh and "已生成 " or "Spawned ")
							.. profiles.display_name(st.last_movement)
							.. " × "
							.. profiles.display_name(st.last_attack),
						0
					)
				else
					push_notice(zh and "生成失败" or "Spawn failed", error_notice_type())
				end
			end,
		},
	})

	local moves = profiles.list_movement_ids()
	local attacks = profiles.list_attack_ids()
	-- Column header row (AddText: ParentId, Text, WrapText, ElementId)
	local header_id = "QingRemasterOptions_SutureNeedleMatrixHdr"
	ImGui.AddText(matrix_sec, " ", false, header_id .. "_Blank")
	for ai = 1, #attacks do
		ImGui.AddElement(matrix_sec, "", ImGuiElement.SameLine)
		ImGui.AddText(matrix_sec, profiles.display_name(attacks[ai]), false, header_id .. "_C" .. tostring(ai))
	end
	for mi = 1, #moves do
		local move_id = moves[mi]
		local row_label_id = "QingRemasterOptions_SutureNeedleMatrixRow_" .. tostring(mi)
		ImGui.AddText(matrix_sec, profiles.display_name(move_id), false, row_label_id)
		for ai = 1, #attacks do
			local attack_id = attacks[ai]
			local btn_id = "QingRemasterOptions_SutureNeedleMatrix_" .. tostring(mi) .. "_" .. tostring(ai)
			ImGui.AddElement(matrix_sec, "", ImGuiElement.SameLine)
			ImGui.AddButton(matrix_sec, btn_id, "Spawn", function()
				if not require_in_game() then return end
				local p = pair_mod()
				if not p or not p.debug_spawn_combo then return end
				local linker = p.debug_spawn_combo(move_id, attack_id)
				if linker then
					push_notice(
						(zh and "已生成 " or "Spawned ")
							.. profiles.display_name(move_id)
							.. " × "
							.. profiles.display_name(attack_id),
						0
					)
				else
					push_notice(zh and "生成失败" or "Spawn failed", error_notice_type())
				end
			end)
			ImGui.AddCallback(btn_id, ImGuiCallback.Render, function()
				local p = pair_mod()
				local st = p and p.get_debug_state and p.get_debug_state() or {}
				local active = st.last_movement == move_id and st.last_attack == attack_id
				local label = active and "! Spawn" or "Spawn"
				ImGui.UpdateData(btn_id, ImGuiData.Label, label)
			end)
		end
	end

	set_module_footer("item_suture_needle", {
		restore_label = text("restore_item_defaults"),
		restore = function()
			item.set_value({"QingRemasterOptions","Debug","SutureNeedleForceSeija"},false)
		end,
	})
end

local function zeiz_mod()
	local ok, mod = pcall(require, "Qing_Remaster_scripts.player.zeiz.zeiz")
	if ok then return mod end
end

local function zeiz_status_text()
	local zh = language_key() == "zh"
	local mod = zeiz_mod()
	if not mod or not mod.debug_snapshot then
		return zh and "Zeiz 模块未加载" or "Zeiz module not loaded"
	end
	local snap = mod.debug_snapshot()
	local lines = {}
	lines[#lines + 1] = (zh and "是否 Zeiz：" or "Is Zeiz: ")..tostring(snap.isZeiz)
	lines[#lines + 1] = (zh and "等待进入中枢：" or "Pending hub: ")..tostring(snap.pending)
	lines[#lines + 1] = (zh and "中枢已打开：" or "Hub open: ")..tostring(snap.open)
	lines[#lines + 1] = (zh and "位于中枢房：" or "In hub room: ")..tostring(snap.inHub)
	lines[#lines + 1] = (zh and "中枢房间号：" or "Hub index: ")..tostring(snap.hubIndex)
	local cands = snap.candidates or {}
	lines[#lines + 1] = (zh and "当前候选：" or "Candidates: ")..table.concat(cands, ", ")
	local appointed = snap.appointed or {}
	lines[#lines + 1] = (zh and "已任命：" or "Appointed: ")..table.concat(appointed, ", ")
	for id, st in pairs(snap.admins or {}) do
		local prop = st.proposal or {}
		lines[#lines + 1] = string.format("%s  app=%s  I=%.1f  %s  ready=%s offered=%s approved=%s folly=%s",
			id, tostring(st.appointed), tonumber(st.interest) or 0, tostring(st.interestState),
			tostring(prop.ready), tostring(prop.offered), tostring(prop.approved), tostring(st.follyEnabled))
	end
	local events = snap.events or {}
	lines[#lines + 1] = zh and "最近事件：" or "Recent events:"
	local start = math.max(1, #events - 7)
	for i = start, #events do
		local e = events[i]
		lines[#lines + 1] = string.format("  %s src=%s room=%s", tostring(e.kind), tostring(e.source), tostring(e.room))
	end
	lines[#lines + 1] = (zh and "当前链：" or "Chain: ")..tostring(snap.chain)
	return table.concat(lines, "\n")
end

local function add_zeiz_hub_group(parent_id)
	local group = add_group(parent_id, "QingRemasterOptions_GroupZeizHub", "Zeiz Control Hub")
	add_text(group, language_key() == "zh"
		and "起点房南侧蓝色漩涡进入中枢。走近虚影看 EID 愚见，使用/胶囊/炸弹任命。中枢内漩涡返回。"
		or "Blue portal in the start room enters the hub. Walk up to a phantom for EID Folly; Use/Pill/Bomb appoints. Hub portal returns.")
	local status_id = "QingRemasterOptions_ZeizStatus"
	imgui_layout.add_wrapped_text(group, status_id, zeiz_status_text())
	ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
		imgui_layout.update_text(status_id, zeiz_status_text())
	end)
	local function core()
		local mod = zeiz_mod()
		return mod and mod.api
	end
	ImGui.AddButton(group, "QingRemasterOptions_ZeizForceHub", "Force Enter Hub", function()
		local c = core()
		if c then c.hub.open() end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizAppointCain", "Appoint Cain", function()
		local c = core()
		if c then c.admins.appoint("CAIN") end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizAppointKeeper", "Appoint Keeper", function()
		local c = core()
		if c then c.admins.appoint("KEEPER") end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizEmitLock", "Emit LOCK", function()
		local c = core()
		if c then
			c.events.emit("LOCK", { source = "DEBUG", targetId = "dbg"..tostring(Game():GetFrameCount()) })
		end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizAddInterest", "+1 Keeper Interest", function()
		local c = core()
		if c then c.interest.add("KEEPER", 1) end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizReadyProposal", "Ready Keeper Proposal", function()
		local c = core()
		if c then c.proposal.force_ready("KEEPER") end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizToggleCainFolly", "Toggle Cain Folly", function()
		local c = core()
		if not c then return end
		local st = c.admins.state("CAIN")
		c.folly.set_enabled("CAIN", not (st and st.follyEnabled))
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizClearAdmins", "Clear Administrators", function()
		local c = core()
		if c then c.admins.clear_all() end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizReset", "Reset Zeiz Run State", function()
		local c = core()
		if c then
			c.save.reset()
			c.admins.ensure_all()
		end
	end)
end

local function add_pendulum_star_group(parent_id)
	local group = add_group(parent_id, "QingRemasterOptions_GroupPendulumStar", "灵摆之星")
	add_text(group, "统一几何调试：锚点 / 左右端点 / 绳与刻度 / 最近交点 / phase。默认关闭。")
	local geo_id = "QingRemasterOptions_PendulumStarGeometry"
	ImGui.AddCheckbox(group, geo_id, "Pendulum Star Geometry", nil, false)
	imgui_layout.set_helpmarker(geo_id, "开启后在持有者附近绘制 A/L/R 标记与 Phase/Theta/Memory 文本。")
	ImGui.AddCallback(geo_id, ImGuiCallback.Render, function()
		local ok, mod = pcall(require, "Qing_Remaster_scripts.items.Item_Star_Pendulum")
		ImGui.UpdateData(geo_id, ImGuiData.Value, ok and mod and mod.debug_geometry == true)
	end)
	ImGui.AddCallback(geo_id, ImGuiCallback.Edited, function(value)
		local ok, mod = pcall(require, "Qing_Remaster_scripts.items.Item_Star_Pendulum")
		if ok and mod then mod.debug_geometry = value == true end
	end)
	set_module_footer("item_pendulum_star", {
		restore_label = text("restore_item_defaults"),
		restore = function()
			local ok, mod = pcall(require, "Qing_Remaster_scripts.items.Item_Star_Pendulum")
			if ok and mod and mod.restore_debug_defaults then
				mod.restore_debug_defaults()
			elseif ok and mod then
				mod.debug_geometry = false
			end
		end,
	})
end

local function add_my_hat_group(parent_id)
	local group = add_group(parent_id, "QingRemasterOptions_GroupMyHat", "小青的帽子")
	add_text(group, "罩住敌人时绘制头锚点：红=实体、黄=scalp、绿=帽子原点。默认关闭。")
	local dbg_id = "QingRemasterOptions_MyHatAnchor"
	ImGui.AddCheckbox(group, dbg_id, "My Hat Head Anchor", nil, false)
	imgui_layout.set_helpmarker(dbg_id, "IMPACT/COVER 时在 POST_NPC_RENDER 画锚点与 source/layer/frame。")
	ImGui.AddCallback(dbg_id, ImGuiCallback.Render, function()
		local ok, mod = pcall(require, "Qing_Remaster_scripts.items.Item_My_Hat")
		ImGui.UpdateData(dbg_id, ImGuiData.Value, ok and mod and mod.debug_hat_anchor == true)
	end)
	ImGui.AddCallback(dbg_id, ImGuiCallback.Edited, function(value)
		local ok, mod = pcall(require, "Qing_Remaster_scripts.items.Item_My_Hat")
		if ok and mod then mod.debug_hat_anchor = value == true end
	end)
	set_module_footer("item_my_hat", {
		restore_label = text("restore_item_defaults"),
		restore = function()
			local ok, mod = pcall(require, "Qing_Remaster_scripts.items.Item_My_Hat")
			if ok and mod then mod.debug_hat_anchor = false end
		end,
	})
end

local function add_field_group(parent_id)
	local group = add_group(parent_id, "QingRemasterOptions_GroupField", "逆反力场")
	local mod_path = "Qing_Remaster_scripts.items.Item_Field"
	local function field_mod()
		local ok, mod = pcall(require, mod_path)
		if ok then return mod end
		return nil
	end
	add_text(group, "房间内固定一片逆反区域。调试滑条只改当前运行参数，不写入存档。")
	local status_id = "QingRemasterOptions_FieldStatus"
	imgui_layout.add_imgui_text(group, "no field", true, status_id)
	ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
		local mod = field_mod()
		local msg = (mod and mod.field_status_text and mod.field_status_text()) or "no field"
		ImGui.UpdateData(status_id, ImGuiData.Label, msg)
	end)
	local function bind_float(id, label, field_name, speed, minv, maxv, fmt, as_int, default_value)
		ImGui.AddDragFloat(group, id, label, function(value)
			local mod = field_mod()
			if not mod then return end
			local n = tonumber(value) or default_value
			if as_int then n = math.floor(n + 0.5) end
			mod[field_name] = n
		end, default_value, speed, minv, maxv, fmt)
		ImGui.AddCallback(id, ImGuiCallback.Render, function()
			local mod = field_mod()
			if mod then ImGui.UpdateData(id, ImGuiData.Value, mod[field_name]) end
		end)
	end
	local function bind_bool(id, label, field_name)
		ImGui.AddCheckbox(group, id, label, nil, false)
		ImGui.AddCallback(id, ImGuiCallback.Render, function()
			local mod = field_mod()
			ImGui.UpdateData(id, ImGuiData.Value, mod and mod[field_name] == true)
		end)
		ImGui.AddCallback(id, ImGuiCallback.Edited, function(value)
			local mod = field_mod()
			if mod then mod[field_name] = value == true end
		end)
	end
	bind_float("QingRemasterOptions_FieldRadius", "Radius", "FIELD_RADIUS", 1, 40, 160, "%.0f", true, 80)
	bind_float("QingRemasterOptions_FieldDamping", "Capture damping", "CAPTURE_DAMPING", 0.01, 0.5, 0.98, "%.2f", false, 0.86)
	bind_float("QingRemasterOptions_FieldStop", "Stop speed", "CAPTURE_STOP_SPEED", 0.01, 0.05, 2, "%.2f", false, 0.25)
	bind_float("QingRemasterOptions_FieldBrakeFrames", "Vertical brake frames", "CAPTURE_VERTICAL_BRAKE_FRAMES", 1, 1, 8, "%.0f", true, 3)
	bind_float("QingRemasterOptions_FieldRiseAccel", "Rise accel", "RISE_ACCEL_SCALE", 0.05, 0.2, 3, "%.2f", false, 1.20)
	bind_float("QingRemasterOptions_FieldRiseMax", "Rise speed max", "RISE_SPEED_MAX", 0.1, 2, 28, "%.1f", false, 14)
	bind_float("QingRemasterOptions_FieldTop", "Screen top Y", "RISE_SCREEN_TOP_Y", 1, -80, 40, "%.0f", true, 0)
	bind_float("QingRemasterOptions_FieldRespawn", "Respawn height", "RISE_RESPAWN_HEIGHT", 1, -30, -2, "%.0f", true, -10)
	bind_float("QingRemasterOptions_FieldGrace", "Grace cycles", "LIFE_GRACE_CYCLES", 1, 0, 8, "%.0f", true, 4)
	bind_float("QingRemasterOptions_FieldSoft", "Soft fade end", "LIFE_SOFT_END", 1, 1, 12, "%.0f", true, 7)
	bind_float("QingRemasterOptions_FieldHard", "Hard fade end", "LIFE_HARD_END", 1, 2, 20, "%.0f", true, 11)
	bind_float("QingRemasterOptions_FieldParticles", "Boundary particles", "BOUNDARY_PARTICLES", 1, 8, 40, "%.0f", true, 20)
	bind_bool("QingRemasterOptions_FieldDebugCircle", "Draw debug circle", "debug_circle")
	bind_bool("QingRemasterOptions_FieldDebugLabels", "Show tear cycles", "debug_labels")
	set_module_footer("item_field", {
		restore_label = text("restore_item_defaults"),
		restore = function()
			local mod = field_mod()
			if mod and mod.restore_debug_defaults then mod.restore_debug_defaults() end
		end,
	})
end

local function add_drama_group(parent_id)
	local group = add_group(parent_id, "QingRemasterOptions_GroupDrama", "悲欢之凶剧")
	add_text(group, "15% 面具泪固定交替悲剧/喜剧。调试用：强制每次眼泪都转化，并可锁定面具种类。")
	add_checkbox(group, "QingRemasterOptions_DramaForceMask", "强制转化面具眼泪", {"QingRemasterOptions", "Debug", "DramaForceMask"}, "开启后仍按交替顺序发悲剧/喜剧，只是不再掷 15%。")
	add_drag_float(group, "QingRemasterOptions_DramaMaskKind", "强制面具种类 (0交替 1悲剧 2喜剧)", {"QingRemasterOptions", "Debug", "DramaMaskKind"}, "0=继续交替；1=每发悲剧；2=每发喜剧。需同时打开强制转化，或等自然 15% 触发。", 1, 0, 2, "%.0f")
	set_module_footer("item_drama", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		item.set_value({"QingRemasterOptions", "Debug", "DramaForceMask"}, false)
		item.set_value({"QingRemasterOptions", "Debug", "DramaMaskKind"}, 0)
	end,
})
end

local function add_mental_group(parent_id)
	local group = add_group(parent_id, "QingRemasterOptions_GroupMental", "精神失序")
	add_text(group, "进房 25% 错认掉落物/敌人/已有被动。调试用：强制每次进房都发生错认。")
	add_checkbox(group, "QingRemasterOptions_MentalForceError", "强制发生错认", {"QingRemasterOptions", "Debug", "MentalForceError"}, "开启后进入新房间必定错认（仍按权重在掉落物/敌人/道具间选择）。")
	set_module_footer("item_mental", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		item.set_value({"QingRemasterOptions", "Debug", "MentalForceError"}, false)
	end,
})
end

--- Debug > Items > 妖刀·逢魔：session-only 运行配置（不进存档）。Probe 只观察/导出。
local function add_spectralsword_group(_parent_id)
	local zh = language_key() == "zh"
	local group = start_mod(
		"item_spectralsword",
		DEBUG_PAGE.items,
		zh and "妖刀·逢魔" or "Spectral Sword",
		"QingRemasterOptions_GroupSpectralsword",
		{
			path = {"Spectralsword"},
			kind = "tool",
			footer = {
				restore_label = zh and "恢复妖刀调试默认值" or "Restore Spectralsword debug defaults",
				restore = function()
					local ok, sword = pcall(require, "Qing_Remaster_scripts.items.Item_Spectralsword")
					if ok and sword and sword.reset_debug_config then
						sword.reset_debug_config()
					end
					local ok_n, nodes = pcall(require, "Qing_Remaster_scripts.items.spectralsword.hud_nodes")
					if ok_n and nodes and nodes.reset_layout_config then
						nodes.reset_layout_config()
					end
					local ok_f, fonts = pcall(require, "Qing_Remaster_scripts.items.spectralsword.hud_fonts")
					if ok_f and fonts then
						fonts.STAT_FONT_MODE = "outlined"
						fonts.DEAL_PERCENT_MODE = "one_decimal"
					end
					local ok_g, ghost = pcall(require, "Qing_Remaster_scripts.items.spectralsword.ghost_controller")
					if ok_g and ghost and ghost.reset_spawn_config then
						ghost.reset_spawn_config()
					end
				end,
			},
		}
	)
	if not group then return end

	local function sword_mod()
		local ok, sword = pcall(require, "Qing_Remaster_scripts.items.Item_Spectralsword")
		if ok then return sword end
		return nil
	end
	local function nodes_mod()
		local ok, nodes = pcall(require, "Qing_Remaster_scripts.items.spectralsword.hud_nodes")
		if ok then return nodes end
		return nil
	end
	local function repeater_mod()
		local ok, rep = pcall(require, "Qing_Remaster_scripts.items.spectralsword.input_repeater")
		if ok then return rep end
		return nil
	end
	local function fonts_mod()
		local ok, fonts = pcall(require, "Qing_Remaster_scripts.items.spectralsword.hud_fonts")
		if ok then return fonts end
		return nil
	end

	local function add_runtime_checkbox(id, label, getter, setter, help)
		ImGui.AddCheckbox(group, id, label, nil, false)
		if help and help ~= "" then
			add_text(group, help)
		end
		ImGui.AddCallback(id, ImGuiCallback.Render, function()
			local sword = sword_mod()
			local on = sword and getter(sword) == true
			ImGui.UpdateData(id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(id, ImGuiCallback.Edited, function(value)
			local sword = sword_mod()
			if sword and setter then
				setter(sword, value == true)
			end
		end)
	end

	local function add_layout_drag(id, label, key, def, step, lo, hi, fmt)
		ImGui.AddDragFloat(group, id, label, function(value)
			local nodes = nodes_mod()
			if nodes and nodes.set_debug_layout then
				nodes.set_debug_layout(key, value)
			end
		end, def, step, lo, hi, fmt)
		ImGui.AddCallback(id, ImGuiCallback.Render, function()
			local nodes = nodes_mod()
			local cfg = nodes and nodes.get_layout_config and nodes.get_layout_config() or {}
			ImGui.UpdateData(id, ImGuiData.Value, tonumber(cfg[key]) or def)
		end)
	end

	add_text(group, zh
		and "Session-only：不进存档。Debug 改环境；Probe 只观察/导出。"
		or "Session-only (not saved). Debug changes the environment; Probes observe/export.")

	add_separator(group)
	add_text(group, zh and "=== 玩法模拟 ===" or "=== Gameplay simulation ===")
	add_runtime_checkbox(
		"QingRemasterOptions_SSDebugInfiniteSpirit",
		zh and "无限灵质" or "Infinite essence",
		function(s) return s.get_debug_infinite_spirit and s.get_debug_infinite_spirit() end,
		function(s, on) if s.set_debug_infinite_spirit then s.set_debug_infinite_spirit(on) end end,
		zh and "注入不消耗灵质，并忽略不足。不会向真实灵质库存凭空添加。"
			or "Inject ignores cost; does not invent real essence stock."
	)
	add_runtime_checkbox(
		"QingRemasterOptions_SSDebugForceSeija",
		zh and "强制模拟 Seija 削弱" or "Force Seija nerf",
		function(s) return s.get_debug_force_seija and s.get_debug_force_seija() end,
		function(s, on) if s.set_debug_force_seija then s.set_debug_force_seija(on) end end,
		zh and "即使角色不受 Seija 影响，抽取也有 50% 概率不产生灵质。"
			or "Even without Seija, extract has 50% chance to produce no essence."
	)

	add_separator(group)
	add_text(group, zh and "=== 交互手感 ===" or "=== Input feel ===")
	do
		local init_id = "QingRemasterOptions_SSDebugRepeatInitial"
		ImGui.AddDragFloat(group, init_id, zh and "首次连发延迟（帧）" or "First repeat delay (frames)", function(value)
			local rep = repeater_mod()
			if rep and rep.set_repeat_config then
				rep.set_repeat_config(value, rep.REPEAT_INTERVAL)
			end
		end, 22, 1, 1, 60, "%.0f")
		ImGui.AddCallback(init_id, ImGuiCallback.Render, function()
			local rep = repeater_mod()
			ImGui.UpdateData(init_id, ImGuiData.Value, (rep and rep.INITIAL_REPEAT_DELAY) or 22)
		end)
		local int_id = "QingRemasterOptions_SSDebugRepeatInterval"
		ImGui.AddDragFloat(group, int_id, zh and "连发间隔（帧）" or "Repeat interval (frames)", function(value)
			local rep = repeater_mod()
			if rep and rep.set_repeat_config then
				rep.set_repeat_config(rep.INITIAL_REPEAT_DELAY, value)
			end
		end, 6, 1, 1, 30, "%.0f")
		ImGui.AddCallback(int_id, ImGuiCallback.Render, function()
			local rep = repeater_mod()
			ImGui.UpdateData(int_id, ImGuiData.Value, (rep and rep.REPEAT_INTERVAL) or 6)
		end)
		ImGui.AddButton(group, "QingRemasterOptions_SSDebugRepeatReset", zh and "恢复交互默认值" or "Reset input defaults", function()
			local rep = repeater_mod()
			if rep and rep.reset_repeat_config then
				rep.reset_repeat_config()
			end
		end)
	end

	add_separator(group)
	add_text(group, zh and "=== 出场表现 ===" or "=== Spawn presentation ===")
	do
		local function ghost_mod()
			local ok, g = pcall(require, "Qing_Remaster_scripts.items.spectralsword.ghost_controller")
			if ok then return g end
			return nil
		end
		local function add_spawn_drag(id, label, key, def, step, lo, hi, fmt)
			ImGui.AddDragFloat(group, id, label, function(value)
				local g = ghost_mod()
				if g and g.set_spawn_config then
					g.set_spawn_config(key, value)
				end
			end, def, step, lo, hi, fmt)
			ImGui.AddCallback(id, ImGuiCallback.Render, function()
				local g = ghost_mod()
				local cfg = g and g.get_spawn_config and g.get_spawn_config() or {}
				ImGui.UpdateData(id, ImGuiData.Value, tonumber(cfg[key]) or def)
			end)
		end
		add_spawn_drag("QingRemasterOptions_SSDebugSwordAX", zh and "刀锚点 X" or "Sword anchor X", "sword_anchor_x", 0, 0.5, -40, 40, "%.1f")
		add_spawn_drag("QingRemasterOptions_SSDebugSwordAY", zh and "刀锚点 Y" or "Sword anchor Y", "sword_anchor_y", -20, 0.5, -48, 16, "%.1f")
		add_spawn_drag("QingRemasterOptions_SSDebugSwordEX", zh and "刀刃冒出 X" or "Blade emerge X", "sword_emerge_x", 0, 0.5, -16, 16, "%.1f")
		add_spawn_drag("QingRemasterOptions_SSDebugSwordEY", zh and "刀刃冒出 Y" or "Blade emerge Y", "sword_emerge_y", -4, 0.5, -24, 8, "%.1f")
		add_spawn_drag("QingRemasterOptions_SSDebugRise", zh and "升起距离" or "Rise distance", "rise_distance", 26, 1, 8, 64, "%.0f")
		add_spawn_drag("QingRemasterOptions_SSDebugOrbitRX", zh and "环绕 X 半径" or "Orbit radius X", "orbit_rx", 42, 1, 8, 96, "%.0f")
		add_spawn_drag("QingRemasterOptions_SSDebugOrbitRY", zh and "环绕 Y 半径" or "Orbit radius Y", "orbit_ry", 14, 1, 4, 48, "%.0f")
		add_spawn_drag("QingRemasterOptions_SSDebugOrbitFrames", zh and "环绕时长（帧）" or "Orbit frames", "orbit_frames", 34, 1, 8, 90, "%.0f")
		add_spawn_drag("QingRemasterOptions_SSDebugOrbitRevs", zh and "环绕圈数" or "Orbit revolutions", "orbit_revs", 0.875, 0.025, 0.25, 2.0, "%.3f")
		add_spawn_drag("QingRemasterOptions_SSDebugLeaveTan", zh and "脱离切线长度" or "Leave tangent length", "leave_tangent", 26, 1, 4, 64, "%.0f")
		add_spawn_drag("QingRemasterOptions_SSDebugOrbitCY", zh and "环绕中心 Y（相对玩家）" or "Orbit center Y", "orbit_center_y", -10, 0.5, -40, 16, "%.1f")
		ImGui.AddButton(group, "QingRemasterOptions_SSDebugSpawnReset", zh and "恢复出场默认值" or "Reset spawn defaults", function()
			local g = ghost_mod()
			if g and g.reset_spawn_config then
				g.reset_spawn_config()
			end
		end)
	end

	add_separator(group)
	add_text(group, zh and "=== HUD / 布局（正式锚点）===" or "=== HUD / layout (production anchors) ===")
	add_layout_drag("QingRemasterOptions_SSDebugResValX", zh and "资源值偏移 X" or "Resource value X", "resource_value_x", 8, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugResValY", zh and "资源值偏移 Y" or "Resource value Y", "resource_value_y", -7, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugResCapX", zh and "上限列偏移 X（旧）" or "Cap column X (legacy)", "resource_cap_x", 32, 1, -32, 80, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugResCapY", zh and "上限列偏移 Y（旧）" or "Cap column Y (legacy)", "resource_cap_y", -7, 1, -32, 32, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugCapTextX", zh and "上限文字 X" or "Cap text X", "cap_text_x", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugCapTextY", zh and "上限文字 Y" or "Cap text Y", "cap_text_y", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugStatBaseX", zh and "属性基准 X" or "Stat base X", "stat_base_x", -12, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugStatBaseY", zh and "属性基准 Y" or "Stat base Y", "stat_base_y", -14, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugRowSpacing", zh and "属性行距" or "Stat row spacing", "stat_row_spacing", 12, 0.5, 8, 24, "%.1f")
	add_layout_drag("QingRemasterOptions_SSDebugModeHeaderY", zh and "模式额外行 Y" or "Mode header Y", "mode_header_y", 16, 1, -48, 48, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugTwinStatBaseX", zh and "双子属性基准 X" or "Twin stat base X", "twin_stat_base_x", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugTwinStatBaseY", zh and "双子属性基准 Y" or "Twin stat base Y", "twin_stat_base_y", 15, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugTwinStatRow", zh and "双子属性行距" or "Twin stat row spacing", "twin_stat_row_spacing", 14, 0.5, 4, 24, "%.1f")
	add_layout_drag("QingRemasterOptions_SSDebugTwinSplitMainX", zh and "属性拆分·哥哥 X" or "Stat split main X", "twin_stat_split_main_x", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugTwinSplitMainY", zh and "属性拆分·哥哥 Y" or "Stat split main Y", "twin_stat_split_main_y", -5, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugTwinSplitOtherX", zh and "属性拆分·弟弟 X" or "Stat split other X", "twin_stat_split_other_x", 4, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugTwinSplitOtherY", zh and "属性拆分·弟弟 Y" or "Stat split other Y", "twin_stat_split_other_y", 2, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugTwinDealX", zh and "双子交易偏移 X" or "Twin deal offset X", "twin_deal_x", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugTwinDealY", zh and "双子交易偏移 Y" or "Twin deal offset Y", "twin_deal_y", -1, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugTwinDealRow", zh and "双子交易行距" or "Twin deal row spacing", "twin_deal_row_spacing", 14, 0.5, 4, 24, "%.1f")
	add_layout_drag("QingRemasterOptions_SSDebugStatTextX", zh and "属性文字 X" or "Stat text X", "stat_text_x", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugStatTextY", zh and "属性文字 Y" or "Stat text Y", "stat_text_y", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugDealBaseX", zh and "概率基准 X" or "Deal base X", "deal_base_x", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugDealBaseY", zh and "概率基准 Y" or "Deal base Y", "deal_base_y", 1, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugDealRow", zh and "概率行距" or "Deal row spacing", "deal_row_spacing", 12, 0.5, 8, 24, "%.1f")
	add_layout_drag("QingRemasterOptions_SSDebugDealTextX", zh and "概率文字 X" or "Deal text X", "deal_text_x", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugDealTextY", zh and "概率文字 Y" or "Deal text Y", "deal_text_y", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugGhostStatX", "Ghost Stat X", "ghost_stat_x", 22, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugGhostStatY", "Ghost Stat Y", "ghost_stat_y", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugGhostResX", "Ghost Resource X", "ghost_resource_x", -18, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugGhostResY", "Ghost Resource Y", "ghost_resource_y", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugGhostCapX", "Ghost Cap X", "ghost_cap_x", 20, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugGhostCapY", "Ghost Cap Y", "ghost_cap_y", 0, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugGhostDealX", "Ghost Deal X", "ghost_deal_x", 22, 1, -64, 64, "%.0f")
	add_layout_drag("QingRemasterOptions_SSDebugGhostDealY", "Ghost Deal Y", "ghost_deal_y", 0, 1, -64, 64, "%.0f")
	ImGui.AddButton(group, "QingRemasterOptions_SSDebugResetLayout", zh and "恢复 HUD 布局默认" or "Reset HUD layout", function()
		local nodes = nodes_mod()
		if nodes and nodes.reset_layout_config then
			nodes.reset_layout_config()
		end
	end)

	add_separator(group)
	add_text(group, zh and "=== 正式字体 / 概率格式 ===" or "=== Production font / deal format ===")
	ImGui.AddButton(group, "QingRemasterOptions_SSDebugFontPlain", "luamini", function()
		local fonts = fonts_mod()
		if fonts then fonts.STAT_FONT_MODE = "plain" end
	end)
	ImGui.AddElement(group, "", ImGuiElement.SameLine)
	ImGui.AddButton(group, "QingRemasterOptions_SSDebugFontOutline", "luaminioutlined", function()
		local fonts = fonts_mod()
		if fonts then fonts.STAT_FONT_MODE = "outlined" end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_SSDebugPctInt", zh and "概率整数" or "Deal integer %", function()
		local fonts = fonts_mod()
		if fonts then fonts.DEAL_PERCENT_MODE = "integer" end
	end)
	ImGui.AddElement(group, "", ImGuiElement.SameLine)
	ImGui.AddButton(group, "QingRemasterOptions_SSDebugPctDec", zh and "概率一位小数" or "Deal 1 decimal", function()
		local fonts = fonts_mod()
		if fonts then fonts.DEAL_PERCENT_MODE = "one_decimal" end
	end)

	add_separator(group)
	add_text(group, zh and "=== 表现调试 ===" or "=== Presentation debug ===")
	add_runtime_checkbox(
		"QingRemasterOptions_SSDebugSoftbody",
		zh and "显示软体调试" or "Softbody debug",
		function(s) return s.get_debug_softbody and s.get_debug_softbody() end,
		function(s, on) if s.set_debug_softbody then s.set_debug_softbody(on) end end,
		nil
	)
end

local function add_book_of_thoth_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupBookOfThoth",text("group_book_of_thoth"))
	add_text(group,text("book_of_thoth_help"))
	add_checkbox(group,"QingRemasterOptions_BookOfThothForceSeija",text("book_of_thoth_seija"),{"QingRemasterOptions","Debug","BookOfThothForceSeija"},text("book_of_thoth_seija_help"))
	add_drag_float(group,"QingRemasterOptions_BookOfThothHudCardScale",text("book_of_thoth_hud_card_scale"),{"QingRemasterOptions","Debug","BookOfThothHudCardScale"},text("book_of_thoth_hud_card_help"),0.05,0.2,1.2,"%.2f")
	add_drag_float(group,"QingRemasterOptions_BookOfThothHudCardOffsetX",text("book_of_thoth_hud_card_x"),{"QingRemasterOptions","Debug","BookOfThothHudCardOffsetX"},text("book_of_thoth_hud_card_pos_help"),0.5,-48,48,"%.1f")
	add_drag_float(group,"QingRemasterOptions_BookOfThothHudCardOffsetY",text("book_of_thoth_hud_card_y"),{"QingRemasterOptions","Debug","BookOfThothHudCardOffsetY"},text("book_of_thoth_hud_card_pos_help"),0.5,-48,48,"%.1f")
	add_drag_float(group,"QingRemasterOptions_BookOfThothCupHitOffsetX",text("book_of_thoth_cup_hit_x"),{"QingRemasterOptions","Debug","BookOfThothCupHitOffsetX"},text("book_of_thoth_cup_hit_pos_help"),0.5,-200,200,"%.1f")
	add_drag_float(group,"QingRemasterOptions_BookOfThothCupHitOffsetY",text("book_of_thoth_cup_hit_y"),{"QingRemasterOptions","Debug","BookOfThothCupHitOffsetY"},text("book_of_thoth_cup_hit_pos_help"),0.5,-200,200,"%.1f")
	add_drag_float(group,"QingRemasterOptions_BookOfThothCupHitW",text("book_of_thoth_cup_hit_w"),{"QingRemasterOptions","Debug","BookOfThothCupHitW"},text("book_of_thoth_cup_hit_size_help"),1,16,448,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BookOfThothCupHitH",text("book_of_thoth_cup_hit_h"),{"QingRemasterOptions","Debug","BookOfThothCupHitH"},text("book_of_thoth_cup_hit_size_help"),1,16,96,"%.0f")
	ImGui.AddButton(group,"QingRemasterOptions_BookOfThothUnlockAll",text("book_of_thoth_unlock_all"),function()
		local thoth = require("Qing_Remaster_scripts.items.Item_Book_of_Thoth")
		if thoth and thoth.debug_unlock_all_faces then thoth.debug_unlock_all_faces() end
	end)
	do
		local use_status_id = "QingRemasterOptions_BookOfThothUseSemantics"
		imgui_layout.add_wrapped_text(group, use_status_id, text("book_of_thoth_use_semantics_empty"))
		ImGui.AddCallback(use_status_id, ImGuiCallback.Render, function()
			local ok, thoth = pcall(require, "Qing_Remaster_scripts.items.Item_Book_of_Thoth")
			local body = (ok and thoth and thoth.debug_thoth_use_status and thoth.debug_thoth_use_status())
				or text("book_of_thoth_use_semantics_empty")
			imgui_layout.update_text(use_status_id, body)
		end)
	end
	do
		local aeon_status_id = "QingRemasterOptions_AeonSaveAuditStatus"
		imgui_layout.add_wrapped_text(group, aeon_status_id, "尚未运行 Aeon Save Audit")
		ImGui.AddCallback(aeon_status_id, ImGuiCallback.Render, function()
			local ok, aeon = pcall(require, "Qing_Remaster_scripts.cards.Card_20r_Aeon")
			local body = (ok and aeon and aeon.get_last_save_audit_text and aeon.get_last_save_audit_text())
				or "无法加载 Aeon"
			imgui_layout.update_text(aeon_status_id, body)
		end)
		ImGui.AddButton(group, "QingRemasterOptions_AeonSaveAuditRun", "Aeon Save Audit", function()
			local aeon = require("Qing_Remaster_scripts.cards.Card_20r_Aeon")
			if aeon and aeon.debug_save_audit then
				aeon.debug_save_audit()
			end
		end)
	end
	set_module_footer("item_book_of_thoth", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		item.set_value({"QingRemasterOptions","Debug","BookOfThothForceSeija"},false)
		item.set_value({"QingRemasterOptions","Debug","BookOfThothHudCardScale"},0.5)
		item.set_value({"QingRemasterOptions","Debug","BookOfThothHudCardOffsetX"},0)
		item.set_value({"QingRemasterOptions","Debug","BookOfThothHudCardOffsetY"},0)
		item.set_value({"QingRemasterOptions","Debug","BookOfThothCupHitOffsetX"},0)
		item.set_value({"QingRemasterOptions","Debug","BookOfThothCupHitOffsetY"},1)
		item.set_value({"QingRemasterOptions","Debug","BookOfThothCupHitW"},44)
		item.set_value({"QingRemasterOptions","Debug","BookOfThothCupHitH"},66)
	end,
})
end

local function add_glaze_crown_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupGlazeCrown",text("group_glaze_crown"))
	add_text(group,text("glaze_crown_help"))
	add_checkbox(group,"QingRemasterOptions_GlazeCrownForceSeija",text("glaze_crown_seija"),{"QingRemasterOptions","Debug","GlazeCrownForceSeija"},text("glaze_crown_seija_help"))
	local crown = require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze")
	local function p0()
		return Game():GetPlayer(0)
	end
	local add_slider = ImGui.AddSliderInteger or ImGui.AddSliderInt
	if add_slider then
		add_slider(group, "QingRemasterOptions_GlazeCrownStack", "Crown Stack", function(v)
			local player = p0()
			if player then crown.debug_set_stacks(player, v) end
		end, 0, 0, 5)
		ImGui.AddCallback("QingRemasterOptions_GlazeCrownStack", ImGuiCallback.Render, function()
			local player = p0()
			local n = player and crown.get_stacks(player) or 0
			ImGui.UpdateData("QingRemasterOptions_GlazeCrownStack", ImGuiData.Value, n)
		end)
	end
	ImGui.AddButton(group, "QingRemasterOptions_GlazeCrownUpgradeVfx", "Trigger Upgrade VFX", function()
		local player = p0()
		if player then crown.debug_trigger_upgrade_vfx(player) end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_GlazeCrownShatterVfx", "Trigger Shatter VFX", function()
		local player = p0()
		if player then crown.debug_trigger_shatter_vfx(player) end
	end)
	for n = 1, 5 do
		ImGui.AddButton(group, "QingRemasterOptions_GlazeCrownShatterAt" .. n, "Shatter at " .. n, function()
			local player = p0()
			if player and crown.debug_trigger_shatter_at then
				crown.debug_trigger_shatter_at(player, n)
			end
		end)
	end
	ImGui.AddButton(group, "QingRemasterOptions_GlazeCrownFullVfx", "Trigger Full Crown VFX", function()
		local player = p0()
		if player then crown.debug_trigger_full_crown_vfx(player) end
	end)
	add_text(group, "Crown Shatter Geometry Debug")
	do
		local centers_id = "QingRemasterOptions_GlazeCrownShowCenters"
		ImGui.AddCheckbox(group, centers_id, "Show Crown Particle Centers", nil, false)
		imgui_layout.set_helpmarker(centers_id, "在 Crown Pivot 上按 PARTICLE_VISUAL_CENTER 画 Debug 点；不启动碎冠。5 点应落在辉片像素中心附近。")
		ImGui.AddCallback(centers_id, ImGuiCallback.Render, function()
			ImGui.UpdateData(centers_id, ImGuiData.Value, crown.debug_get_show_particle_centers and crown.debug_get_show_particle_centers() == true)
		end)
		ImGui.AddCallback(centers_id, ImGuiCallback.Edited, function(value)
			if crown.debug_set_show_particle_centers then
				crown.debug_set_show_particle_centers(value == true)
			end
		end)
	end
	do
		local recon_id = "QingRemasterOptions_GlazeCrownShowRecon"
		ImGui.AddCheckbox(group, recon_id, "Show Crown Particle Reconstruction", nil, false)
		imgui_layout.set_helpmarker(recon_id, "在同一 Pivot 上叠加 Particle1~5（offset=0）。应与 Float5 辉片位置一致。")
		ImGui.AddCallback(recon_id, ImGuiCallback.Render, function()
			ImGui.UpdateData(recon_id, ImGuiData.Value, crown.debug_get_show_particle_reconstruction and crown.debug_get_show_particle_reconstruction() == true)
		end)
		ImGui.AddCallback(recon_id, ImGuiCallback.Edited, function(value)
			if crown.debug_set_show_particle_reconstruction then
				crown.debug_set_show_particle_reconstruction(value == true)
			end
		end)
	end
	add_text(group, "Release Freeze Frame Compare")
	add_text(group, "Set release frames, run shatter, stop at Freeze. Compare Freeze composition only.")
	for n = 1, 4 do
		ImGui.AddButton(group, "QingRemasterOptions_GlazeCrownReleaseFreeze" .. n, "Release Freeze @ " .. n, function()
			local player = p0()
			if not player then return end
			if crown.debug_set_release_frames then
				crown.debug_set_release_frames(n)
			end
			if crown.debug_trigger_shatter_mode then
				-- trail → stop after freeze
				crown.debug_trigger_shatter_mode(player, "trail")
			end
		end)
	end
	ImGui.AddButton(group, "QingRemasterOptions_GlazeCrownReleaseFramesClear", "Clear Release Frames Override", function()
		if crown.debug_set_release_frames then
			crown.debug_set_release_frames(nil)
		end
	end)
	add_text(group, "Debug Crown Shatter Modes")
	local shatter_modes = {
		{"QingRemasterOptions_GlazeCrownShatterRecoil", "Recoil Only", "recoil"},
		{"QingRemasterOptions_GlazeCrownShatterCrack", "Crack Only", "crack"},
		{"QingRemasterOptions_GlazeCrownShatterDisassemble", "Disassemble Only", "disassemble"},
		{"QingRemasterOptions_GlazeCrownShatterRelease", "Release Only", "release"},
		{"QingRemasterOptions_GlazeCrownShatterShock", "Shock Ring Only", "shock"},
		{"QingRemasterOptions_GlazeCrownShatterFracture", "Fracture Only", "fracture"},
		{"QingRemasterOptions_GlazeCrownShatterEject", "Eject Only", "eject"},
		{"QingRemasterOptions_GlazeCrownShatterTrail", "Freeze Stop", "trail"},
		{"QingRemasterOptions_GlazeCrownShatterFull", "Full Sequence", "full"},
	}
	for i = 1, #shatter_modes do
		local id, label, mode = shatter_modes[i][1], shatter_modes[i][2], shatter_modes[i][3]
		ImGui.AddButton(group, id, label, function()
			local player = p0()
			if player and crown.debug_trigger_shatter_mode then
				crown.debug_trigger_shatter_mode(player, mode)
			end
		end)
	end
	set_module_footer("item_glaze_crown", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		item.set_value({"QingRemasterOptions","Debug","GlazeCrownForceSeija"},false)
		if crown.debug_set_show_particle_centers then
			crown.debug_set_show_particle_centers(false)
		end
		if crown.debug_set_show_particle_reconstruction then
			crown.debug_set_show_particle_reconstruction(false)
		end
		if crown.debug_set_release_frames then
			crown.debug_set_release_frames(nil)
		end
	end,
})
end

local function add_tianyi_group(parent_id)
	local group = add_group(parent_id, "QingRemasterOptions_GroupTianYi", text("group_tianyi"))
	add_text(group, text("tianyi_help"))
	local tianyi = require("Qing_Remaster_scripts.items.Item_TianYi")
	local reward_path = {"QingRemasterOptions", "Debug", "TianYiDebugReward"}
	local reason_key = {
		forbidden_room = "tianyi_reason_forbidden_room",
		no_open_door = "tianyi_reason_no_open_door",
		path_failed = "tianyi_reason_path_failed",
		no_player = "tianyi_reason_no_player",
		busy = "tianyi_reason_busy",
		pending = "tianyi_reason_pending",
		no_copies = "tianyi_reason_no_copies",
		failed = "tianyi_reason_failed",
	}
	local function reason_text(reason)
		local key = reason_key[reason]
		return key and text(key) or tostring(reason or "failed")
	end
	local function notify(ok, info)
		if not push_notice then return end
		if ok then
			push_notice(text("tianyi_spawned"))
		else
			push_notice(reason_text(info), error_notice_type())
		end
	end
	local status_id = "QingRemasterOptions_TianYiStatus"
	imgui_layout.add_wrapped_text(group, status_id, "...")
	ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
		local s = tianyi.debug_snapshot and tianyi.debug_snapshot() or {}
		imgui_layout.update_text(status_id, string.format(
			"Copies: %s\nProc chance: %.0f%%\nRolls / procs: %s / %s\nPending: %s\nState: %s\nReward: %s  variant %s  subtype %s\nRoute: %s\nEntry / exit: %s / %s\nPath cost: %s",
			tostring(s.copies or 0),
			(tonumber(s.chance) or 0) * 100,
			tostring(s.rolls or 0),
			tostring(s.procs or 0),
			tostring(s.pending),
			tostring(s.state or "none"),
			tostring(s.reward_kind or ""),
			tostring(s.reward_variant or 0),
			tostring(s.reward_subtype or 0),
			tostring(s.route or ""),
			tostring(s.entry_slot),
			tostring(s.exit_slot),
			tostring(s.path_cost or 0)
		))
	end)
	ImGui.AddButton(group, "QingRemasterOptions_TianYiForceClear", text("tianyi_force_clear"), function()
		local ok, info = tianyi.debug_force_clear_proc()
		if not push_notice then return end
		if ok then
			push_notice(text("tianyi_pending"))
		else
			push_notice(reason_text(info), error_notice_type())
		end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_TianYiForce", text("tianyi_force"), function()
		local ok, info = tianyi.debug_force_spawn({
			suppress_reward = item.get_value(reward_path) ~= true,
		})
		notify(ok, info)
	end)
	ImGui.AddButton(group, "QingRemasterOptions_TianYiClear", text("tianyi_clear"), function()
		tianyi.debug_clear()
		if push_notice then push_notice(text("tianyi_cleared")) end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_TianYiReroll", text("tianyi_reroll"), function()
		tianyi.debug_clear()
		local ok, info = tianyi.debug_force_spawn({
			suppress_reward = item.get_value(reward_path) ~= true,
		})
		notify(ok, info)
	end)
	ImGui.AddButton(group, "QingRemasterOptions_TianYiPrintDoors", text("tianyi_print_doors"), function()
		local report = tianyi.debug_inspect_room()
		print("[Qing][TianYi]")
		print(string.format("RoomType=%s Forbidden=%s Reason=%s",
			tostring(report.room_type), tostring(report.forbidden), tostring(report.reason)))
		for _, door in ipairs(report.doors or {}) do
			print(string.format("Door %s:", tostring(door.slot)))
			print("  allowed=" .. tostring(door.allowed))
			print("  exists=" .. tostring(door.exists))
			print("  open=" .. tostring(door.open))
			print("  eligible=" .. tostring(door.eligible))
		end
		local route = report.route
		if route then
			print("Route:")
			print("  kind=" .. tostring(route.kind))
			print("  entry_slot=" .. tostring(route.entry_slot))
			print("  exit_slot=" .. tostring(route.exit_slot))
		else
			print("Route: none")
		end
	end)
	add_checkbox(group, "QingRemasterOptions_TianYiDebugReward", text("tianyi_debug_reward"), reward_path)
	local walk_path = {"QingRemasterOptions", "Debug", "TianYiWalkSpeed"}
	local anim_path = {"QingRemasterOptions", "Debug", "TianYiAnimSpeed"}
	local show_path = {"QingRemasterOptions", "Debug", "TianYiShowPath"}
	local walk_id = "QingRemasterOptions_TianYiWalkSpeed"
	local anim_id = "QingRemasterOptions_TianYiAnimSpeed"
	ImGui.AddDragFloat(group, walk_id, text("tianyi_walk_speed"), function(value)
		item.set_value(walk_path, value)
	end, 2.4, 0.05, 0.4, 3.0, "%.2f")
	ImGui.AddCallback(walk_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(walk_id, ImGuiData.Value, tonumber(item.get_value(walk_path)) or 2.4)
	end)
	ImGui.AddDragFloat(group, anim_id, text("tianyi_anim_speed"), function(value)
		item.set_value(anim_path, value)
	end, 1.0, 0.05, 0.3, 2.0, "%.2f")
	ImGui.AddCallback(anim_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(anim_id, ImGuiData.Value, tonumber(item.get_value(anim_path)) or 1.0)
	end)
	add_checkbox(group, "QingRemasterOptions_TianYiShowPath", text("tianyi_show_path"), show_path)
	local hair_id = "QingRemasterOptions_TianYiPlayerHairProbe"
	ImGui.AddCheckbox(group, hair_id, text("tianyi_player_hair"), function(value)
		tianyi.debug_set_player_hair(value == true)
	end, false)
	ImGui.AddCallback(hair_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(hair_id, ImGuiData.Value, tianyi.player_hair_probe == true)
	end)
	set_module_footer("item_tianyi", {
		restore_label = text("restore_item_defaults"),
		restore = function()
			item.set_value(reward_path, false)
			item.set_value(walk_path, 2.4)
			item.set_value(anim_path, 1.0)
			item.set_value(show_path, false)
			tianyi.debug_set_player_hair(false)
		end,
	})
end

local function add_abiogenesis_group(parent_id)
	local group = add_group(parent_id, "QingRemasterOptions_GroupAbiogenesis", text("group_abiogenesis"))
	add_text(group, text("abiogenesis_help"))
	local abio = require("Qing_Remaster_scripts.items.Item_Abiogenesis")
	local function p0()
		return Game():GetPlayer(0)
	end

	ImGui.AddButton(group, "QingRemasterOptions_AbiogenesisForceAwaken", text("abiogenesis_force_awaken"), function()
		local player = p0()
		if not player or not abio.debug_force_awaken then return end
		local ok, msg = abio.debug_force_awaken(player)
		if push_notice then
			if ok then
				push_notice(tostring(msg or "started"))
			else
				push_notice(tostring(msg or "failed"), error_notice_type())
			end
		end
	end)
	imgui_layout.set_helpmarker("QingRemasterOptions_AbiogenesisForceAwaken", text("abiogenesis_force_awaken_help"))

	ImGui.AddButton(group, "QingRemasterOptions_AbiogenesisAdvancePhase", text("abiogenesis_advance"), function()
		if abio.debug_advance_phase then abio.debug_advance_phase() end
	end)
	imgui_layout.set_helpmarker("QingRemasterOptions_AbiogenesisAdvancePhase", text("abiogenesis_advance_help"))

	ImGui.AddButton(group, "QingRemasterOptions_AbiogenesisForceFinish", text("abiogenesis_force_finish"), function()
		local n = abio.debug_force_finish and abio.debug_force_finish() or 0
		if push_notice then
			push_notice("finished awakenings: " .. tostring(n))
		end
	end)
	imgui_layout.set_helpmarker("QingRemasterOptions_AbiogenesisForceFinish", text("abiogenesis_force_finish_help"))

	add_separator(group)
	add_text(group, text("abiogenesis_resource_debug"))
	local override_id = "QingRemasterOptions_AbiogenesisResourceOverride"
	ImGui.AddCheckbox(group, override_id, text("abiogenesis_resource_override"), nil, false)
	ImGui.AddCallback(override_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(override_id, ImGuiData.Value, abio.debug_get_resource_override_enabled and abio.debug_get_resource_override_enabled() or false)
	end)
	ImGui.AddCallback(override_id, ImGuiCallback.Edited, function(value)
		if abio.debug_set_resource_override_enabled then
			abio.debug_set_resource_override_enabled(value == true)
		end
	end)

	local function add_resource_drag(kind, label_key)
		local eid = "QingRemasterOptions_AbiogenesisRes_" .. kind
		ImGui.AddDragFloat(group, eid, text(label_key), function(value)
			if abio.debug_set_resource_amount then
				abio.debug_set_resource_amount(kind, value)
			end
		end, 0, 1, 0, 99, "%.0f")
		ImGui.AddCallback(eid, ImGuiCallback.Render, function()
			local v = abio.debug_get_resource_amount and abio.debug_get_resource_amount(kind) or 0
			ImGui.UpdateData(eid, ImGuiData.Value, v)
		end)
	end
	add_resource_drag("coin", "abiogenesis_coin")
	add_resource_drag("key", "abiogenesis_key")
	add_resource_drag("bomb", "abiogenesis_bomb")
	add_resource_drag("charge", "abiogenesis_charge")

	imgui_layout.add_small_action_row(group, {
		{id = "QingRemasterOptions_AbiogenesisPreset1", label = text("abiogenesis_preset_1"), on_click = function()
			if abio.debug_set_resource_preset then abio.debug_set_resource_preset(1) end
		end},
		{id = "QingRemasterOptions_AbiogenesisPreset2", label = text("abiogenesis_preset_2"), on_click = function()
			if abio.debug_set_resource_preset then abio.debug_set_resource_preset(2) end
		end},
		{id = "QingRemasterOptions_AbiogenesisPreset3", label = text("abiogenesis_preset_3"), on_click = function()
			if abio.debug_set_resource_preset then abio.debug_set_resource_preset(3) end
		end},
		{id = "QingRemasterOptions_AbiogenesisPreset4", label = text("abiogenesis_preset_4"), on_click = function()
			if abio.debug_set_resource_preset then abio.debug_set_resource_preset(4) end
		end},
	})

	add_separator(group)
	add_text(group, text("abiogenesis_combat_tuning"))
	local function add_item_float(suffix, field, label_key, speed, min_v, max_v, fmt, as_int)
		local eid = "QingRemasterOptions_AbiogenesisTune_" .. suffix
		ImGui.AddDragFloat(group, eid, text(label_key), function(value)
			value = tonumber(value) or min_v
			if as_int then value = math.floor(value + 0.5) end
			abio[field] = value
		end, tonumber(abio[field]) or min_v, speed, min_v, max_v, fmt)
		ImGui.AddCallback(eid, ImGuiCallback.Render, function()
			ImGui.UpdateData(eid, ImGuiData.Value, tonumber(abio[field]) or min_v)
		end)
	end
	add_item_float("IntervalScale", "debug_attack_interval_scale", "abiogenesis_interval_scale", 0.05, 0.5, 3.0, "%.2f", false)
	add_item_float("BombSpeed", "bomb_speed", "abiogenesis_bomb_speed", 0.1, 1, 20, "%.1f", false)
	add_item_float("BombFuse", "bomb_fuse", "abiogenesis_bomb_fuse", 1, 10, 120, "%.0f", true)

	add_separator(group)
	local status_id = "QingRemasterOptions_AbiogenesisStatus"
	imgui_layout.add_plain_text(group, status_id, "")
	ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
		local ok, txt = pcall(function()
			return abio.debug_status_text and abio.debug_status_text() or ""
		end)
		imgui_layout.update_text(status_id, (ok and txt) or "")
	end)

	set_module_footer("item_abiogenesis", {
		restore_label = text("restore_item_defaults"),
		restore = function()
			if abio.restore_debug_defaults then abio.restore_debug_defaults() end
		end,
	})
end

local function add_ingestion_night_group(parent_id)
	local night_vis = require("Qing_Remaster_scripts.items.ingestion_night_visual")
	local group = add_group(parent_id,"QingRemasterOptions_GroupIngestionNight",text("group_ingestion_night"))
	add_text(group,text("ingestion_night_help"))
	local function add_param_drag(element_id, label, param_key, speed, min_v, max_v)
		ImGui.AddDragFloat(group, element_id, label, function(value)
			night_vis.set_param(param_key, value)
		end, tonumber(night_vis.get_params()[param_key]) or 0, speed, min_v, max_v, "%.3f")
		ImGui.AddCallback(element_id, ImGuiCallback.Render, function()
			ImGui.UpdateData(element_id, ImGuiData.Value, tonumber(night_vis.get_params()[param_key]) or 0)
		end)
	end
	add_param_drag("QingRemasterOptions_I2N_BaseDepth", "base_depth", "base_depth", 0.02, 0.2, 2)
	add_param_drag("QingRemasterOptions_I2N_NoiseAmp", "noise_amp", "noise_amp", 0.02, 0, 2)
	add_param_drag("QingRemasterOptions_I2N_NoiseAlpha", "noise_alpha", "noise_alpha", 0.02, 0, 2)
	add_param_drag("QingRemasterOptions_I2N_Drift", "drift_speed", "drift_speed", 0.02, 0, 3)
	add_param_drag("QingRemasterOptions_I2N_FangLen", "fang_length", "fang_length", 0.02, 0, 3)
	add_param_drag("QingRemasterOptions_I2N_FangWidth", "fang_width", "fang_width", 0.02, 0.2, 3)
	add_param_drag("QingRemasterOptions_I2N_FangAlpha", "fang_alpha", "fang_alpha", 0.02, 0, 2)
	add_param_drag("QingRemasterOptions_I2N_RimBoost", "rim_boost", "rim_boost", 0.02, 0.5, 2)
	-- Night Body Mask
	add_param_drag("QingRemasterOptions_I2N_BodyAlphaMax", "body_alpha_max", "body_alpha_max", 0.01, 0, 1)
	add_param_drag("QingRemasterOptions_I2N_BodyAlphaStart", "body_alpha_start", "body_alpha_start", 1, 0, 120)
	add_param_drag("QingRemasterOptions_I2N_BodyAlphaFull", "body_alpha_full", "body_alpha_full", 1, 60, 240)
	-- Bite / closure
	add_param_drag("QingRemasterOptions_I2N_ClosureMargin", "closure_margin", "closure_margin", 1, 10, 120)
	add_param_drag("QingRemasterOptions_I2N_FangClosureR", "fang_closure_radius", "fang_closure_radius", 1, 8, 80)
	add_param_drag("QingRemasterOptions_I2N_BiteMoveStart", "bite_move_start", "bite_move_start", 1, 0, 30)
	add_param_drag("QingRemasterOptions_I2N_BiteMoveEnd", "bite_move_end", "bite_move_end", 1, 5, 40)
	-- Fang root
	add_param_drag("QingRemasterOptions_I2N_FangEmbedMin", "fang_embed_min", "fang_embed_min", 1, 4, 48)
	add_param_drag("QingRemasterOptions_I2N_FangEmbedRatio", "fang_embed_ratio", "fang_embed_ratio", 0.01, 0.05, 0.6)
	add_param_drag("QingRemasterOptions_I2N_FangRootAlpha", "fang_root_alpha", "fang_root_alpha", 0.01, 0, 1)
	add_param_drag("QingRemasterOptions_I2N_FangRootScale", "fang_root_scale", "fang_root_scale", 0.02, 0.2, 2.5)
	add_param_drag("QingRemasterOptions_I2N_MedCover", "medium_cover_mul", "medium_cover_mul", 0.01, 0, 1)
	add_param_drag("QingRemasterOptions_I2N_DetCover", "detail_cover_mul", "detail_cover_mul", 0.01, 0, 1)
	for _, c in ipairs({30, 90, 130, 170, 180}) do
		ImGui.AddButton(group, "QingRemasterOptions_I2N_Force"..tostring(c), "Preview "..tostring(c), function()
			night_vis.debug_force_counter = c
			night_vis.debug_freeze_release_t = nil
		end)
		ImGui.AddElement(group, "", ImGuiElement.SameLine)
	end
	ImGui.AddButton(group, "QingRemasterOptions_I2N_ClearForce", text("ingestion_clear_force"), function()
		night_vis.debug_force_counter = nil
		night_vis.debug_freeze_release_t = nil
	end)
	local function start_debug_release(freeze_t)
		local player = Game():GetPlayer(0)
		if not player then return end
		local d = player:GetData()
		d.Ingestion2n = d.Ingestion2n or {state = "idle", counter = 0, release_t = 0}
		d.Ingestion2n.state = "releasing"
		d.Ingestion2n.release_t = freeze_t or 0
		d.Ingestion2n.release_charge = math.max(180, d.Ingestion2n.counter or 180)
		d.Ingestion2n.counter = d.Ingestion2n.release_charge
		d.Ingestion2n.damage_done = false
		d.Ingestion2n.input_lock = true
		night_vis.debug_force_counter = nil
		night_vis.debug_freeze_release_t = freeze_t
	end
	ImGui.AddButton(group, "QingRemasterOptions_I2N_Bite", "Trigger Bite", function()
		start_debug_release(nil)
	end)
	ImGui.AddButton(group, "QingRemasterOptions_I2N_Freeze170", "Freeze at 170", function()
		night_vis.debug_force_counter = 170
		night_vis.debug_freeze_release_t = nil
	end)
	ImGui.AddElement(group, "", ImGuiElement.SameLine)
	ImGui.AddButton(group, "QingRemasterOptions_I2N_Freeze180", "Freeze at 180", function()
		night_vis.debug_force_counter = 180
		night_vis.debug_freeze_release_t = nil
	end)
	ImGui.AddButton(group, "QingRemasterOptions_I2N_PauseR10", "Pause Release t=10", function()
		start_debug_release(10)
	end)
	ImGui.AddElement(group, "", ImGuiElement.SameLine)
	ImGui.AddButton(group, "QingRemasterOptions_I2N_PauseR15", "Pause Release t=15", function()
		start_debug_release(15)
	end)
	ImGui.AddElement(group, "", ImGuiElement.SameLine)
	ImGui.AddButton(group, "QingRemasterOptions_I2N_PauseR20", "Pause Release t=20", function()
		start_debug_release(20)
	end)
	set_module_footer("item_ingestion_night", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		night_vis.reset_params()
	end,
})
end

local function add_golden_slot_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupGoldenSlot",text("group_golden_slot"))
	add_text(group,text("golden_slot_help"))
	local golden_slot = require("Qing_Remaster_scripts.items.Item_Golden_Slot")
	local streak_id = "QingRemasterOptions_GoldenSlotLossStreak"
	imgui_layout.add_imgui_text(group, text("golden_slot_loss_streak")..": 0", true, streak_id)
	ImGui.AddCallback(streak_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(streak_id, ImGuiData.Value, text("golden_slot_loss_streak")..": "..tostring(golden_slot.get_loss_streak()))
	end)
	imgui_layout.set_helpmarker(streak_id,text("golden_slot_loss_streak_help"))
	local chance_id = "QingRemasterOptions_GoldenSlotNextChance"
	imgui_layout.add_imgui_text(group, text("golden_slot_next_chance")..": 15", true, chance_id)
	ImGui.AddCallback(chance_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(chance_id, ImGuiData.Value, text("golden_slot_next_chance")..": "..string.format("%.1f", golden_slot.get_win_chance() * 100))
	end)
	local restore_golden = function()
		local defaults = {
			GoldenSlotBaseWinChance = 10,
			GoldenSlotWinChancePerLoss = 4,
			GoldenSlotMaxWinChance = 40,
			GoldenSlotRewardWeightMidasFly = 24,
			GoldenSlotRewardWeightGoldTroll = 15,
			GoldenSlotRewardWeightGoldCoin = 18,
			GoldenSlotRewardWeightGoldHeart = 11,
			GoldenSlotRewardWeightGoldPill = 8,
			GoldenSlotRewardWeightGoldBattery = 6,
			GoldenSlotRewardWeightGoldBomb = 5,
			GoldenSlotRewardWeightGoldKey = 5,
			GoldenSlotRewardWeightGoldMegaPill = 3,
			GoldenSlotRewardWeightGoldTrinket = 4,
			GoldenSlotRewardWeightEnding = 1,
			GoldenSlotEndingMegaWeight = 95,
			GoldenSlotEndingTrophyWeight = 5,
		}
		for key,value in pairs(defaults) do item.set_value({"QingRemasterOptions","Debug",key},value) end
		golden_slot.set_loss_streak(0)
	end
	local GOLDEN_CONTROLS = {
		{key = "base_chance", kind = "drag_float", label = text("golden_slot_base_chance"), path = {"QingRemasterOptions","Debug","GoldenSlotBaseWinChance"}, speed = 0.5, min = 0, max = 100, fmt = "%.1f", home = true},
		{key = "chance_per_loss", kind = "drag_float", label = text("golden_slot_chance_per_loss"), path = {"QingRemasterOptions","Debug","GoldenSlotWinChancePerLoss"}, speed = 0.5, min = 0, max = 100, fmt = "%.1f", home = true},
		{key = "max_chance", kind = "drag_float", label = text("golden_slot_max_chance"), path = {"QingRemasterOptions","Debug","GoldenSlotMaxWinChance"}, speed = 0.5, min = 0, max = 100, fmt = "%.1f", home = true},
		{key = "w_fly", kind = "drag_float", label = text("golden_slot_w_fly"), path = {"QingRemasterOptions","Debug","GoldenSlotRewardWeightMidasFly"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
		{key = "w_troll", kind = "drag_float", label = text("golden_slot_w_troll"), path = {"QingRemasterOptions","Debug","GoldenSlotRewardWeightGoldTroll"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
		{key = "w_coin", kind = "drag_float", label = text("golden_slot_w_coin"), path = {"QingRemasterOptions","Debug","GoldenSlotRewardWeightGoldCoin"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
		{key = "w_heart", kind = "drag_float", label = text("golden_slot_w_heart"), path = {"QingRemasterOptions","Debug","GoldenSlotRewardWeightGoldHeart"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
		{key = "w_pill", kind = "drag_float", label = text("golden_slot_w_pill"), path = {"QingRemasterOptions","Debug","GoldenSlotRewardWeightGoldPill"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
		{key = "w_battery", kind = "drag_float", label = text("golden_slot_w_battery"), path = {"QingRemasterOptions","Debug","GoldenSlotRewardWeightGoldBattery"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
		{key = "w_bomb", kind = "drag_float", label = text("golden_slot_w_bomb"), path = {"QingRemasterOptions","Debug","GoldenSlotRewardWeightGoldBomb"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
		{key = "w_key", kind = "drag_float", label = text("golden_slot_w_key"), path = {"QingRemasterOptions","Debug","GoldenSlotRewardWeightGoldKey"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
		{key = "w_mega_pill", kind = "drag_float", label = text("golden_slot_w_mega_pill"), path = {"QingRemasterOptions","Debug","GoldenSlotRewardWeightGoldMegaPill"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
		{key = "w_trinket", kind = "drag_float", label = text("golden_slot_w_trinket"), path = {"QingRemasterOptions","Debug","GoldenSlotRewardWeightGoldTrinket"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
		{key = "w_ending", kind = "drag_float", label = text("golden_slot_w_ending"), path = {"QingRemasterOptions","Debug","GoldenSlotRewardWeightEnding"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
		{key = "w_mega_chest", kind = "drag_float", label = text("golden_slot_w_mega_chest"), path = {"QingRemasterOptions","Debug","GoldenSlotEndingMegaWeight"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
		{key = "w_trophy", kind = "drag_float", label = text("golden_slot_w_trophy"), path = {"QingRemasterOptions","Debug","GoldenSlotEndingTrophyWeight"}, speed = 1, min = 0, max = 1000, fmt = "%.0f", home = false},
	}
	-- register_built later; pre-register home controls + footer here, then merge home on register_built
	set_module_footer("item_golden_slot", {
		restore_label = text("restore_item_defaults"),
		restore = restore_golden,
	})
	register_home_controls("item_golden_slot", {
		label = text("group_golden_slot"),
		path = {"Golden Slot"},
		controls = GOLDEN_CONTROLS,
		home_keys = {"base_chance", "chance_per_loss", "max_chance"},
		restore = restore_golden,
		restore_label = text("restore_item_defaults"),
		page = "items",
	})
	imgui_layout.render_control_spec(group, "item_golden_slot", GOLDEN_CONTROLS, "main")
end

local function add_remaster_flip_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupRemasterFlip",text("group_remaster"))
	add_text(group,text("remaster_help"))
	add_drag_float(group,"QingRemasterOptions_RemasterCodeFlipSpacing",text("remaster_flip_spacing"),{"QingRemasterOptions","Debug","RemasterCodeFlipSpacing"},text("remaster_flip_spacing_help"),0.25,0.5,24,"%.2f")
	add_drag_float(group,"QingRemasterOptions_RemasterPanelOffsetX",text("remaster_panel_offset_x"),{"QingRemasterOptions","Debug","RemasterPanelOffsetX"},text("remaster_panel_offset_help"),1,-240,240,"%.0f")
	add_drag_float(group,"QingRemasterOptions_RemasterPanelOffsetY",text("remaster_panel_offset_y"),{"QingRemasterOptions","Debug","RemasterPanelOffsetY"},text("remaster_panel_offset_help"),1,-240,240,"%.0f")
	set_module_footer("item_remaster", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		item.set_value({"QingRemasterOptions","Debug","RemasterCodeFlipSpacing"},4)
		item.set_value({"QingRemasterOptions","Debug","RemasterPanelOffsetX"},0)
		item.set_value({"QingRemasterOptions","Debug","RemasterPanelOffsetY"},40)
	end,
})
end

local function add_remaster_channels_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupRemasterChannels",text("group_remaster"))
	local remaster = require("Qing_Remaster_scripts.items.Item_Remaster")
	item.remaster_debug = item.remaster_debug or {
		from_command = "1",
		to_command = "5c",
		selected_index = 1,
		options = {text("remaster_channel_empty")},
	}
	local dbg = item.remaster_debug

	local function refresh_channel_options()
		local list = remaster.get_channels() or {}
		dbg.options = {}
		if #list == 0 then
			dbg.options[1] = text("remaster_channel_empty")
			dbg.selected_index = 1
		else
			for i, ch in ipairs(list) do
				dbg.options[i] = remaster.format_channel_label(ch, i)
			end
			if dbg.selected_index < 1 or dbg.selected_index > #list then
				dbg.selected_index = 1
			end
		end
	end

	add_text(group,text("remaster_channels_help"))
	local list_id = "QingRemasterOptions_RemasterChannelList"
	imgui_layout.add_imgui_text(group, text("remaster_channel_list")..":\n"..text("remaster_channel_empty"), true, list_id)
	ImGui.AddCallback(list_id,ImGuiCallback.Render,function()
		refresh_channel_options()
		local list = remaster.get_channels() or {}
		local body
		if #list == 0 then
			body = text("remaster_channel_empty")
		else
			local lines = {}
			for i, ch in ipairs(list) do
				lines[#lines + 1] = remaster.format_channel_label(ch, i)
			end
			body = table.concat(lines, "\n")
		end
		ImGui.UpdateData(list_id,ImGuiData.Label,text("remaster_channel_list")..":\n"..body)
	end)

	local combo_id = "QingRemasterOptions_RemasterChannelSelect"
	refresh_channel_options()
	ImGui.AddCombobox(group,combo_id,text("remaster_channel_select"),function(index)
		dbg.selected_index = (tonumber(index) or 0) + 1
	end,dbg.options,math.max(0,dbg.selected_index - 1))
	ImGui.AddCallback(combo_id,ImGuiCallback.Render,function()
		refresh_channel_options()
		ImGui.UpdateData(combo_id,ImGuiData.ListValues,dbg.options)
		ImGui.UpdateData(combo_id,ImGuiData.Value,math.max(0,dbg.selected_index - 1))
	end)

	local from_id = "QingRemasterOptions_RemasterChannelFrom"
	ImGui.AddInputText(group,from_id,text("remaster_channel_from"),function(value)
		dbg.from_command = tostring(value or "")
	end,dbg.from_command)
	imgui_layout.set_helpmarker(from_id,text("remaster_channel_from_help"))
	ImGui.AddCallback(from_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(from_id,ImGuiData.Value,dbg.from_command or "")
	end)

	local to_id = "QingRemasterOptions_RemasterChannelTo"
	ImGui.AddInputText(group,to_id,text("remaster_channel_to"),function(value)
		dbg.to_command = tostring(value or "")
	end,dbg.to_command)
	imgui_layout.set_helpmarker(to_id,text("remaster_channel_to_help"))
	ImGui.AddCallback(to_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(to_id,ImGuiData.Value,dbg.to_command or "")
	end)

	ImGui.AddButton(group,"QingRemasterOptions_RemasterChannelFillFrom",text("remaster_channel_fill_from"),function()
		local cmd = remaster.debug_fill_from_current_floor()
		if not cmd then
			push_notice(text("start_run_first"),error_notice_type())
			return
		end
		dbg.from_command = cmd
	end)
	ImGui.AddButton(group,"QingRemasterOptions_RemasterChannelAdd",text("remaster_channel_add"),imgui_layout.guard_restricted(function()
		local idx, err = remaster.debug_add_channel(dbg.from_command, dbg.to_command, {armed = true})
		if not idx then
			push_notice(err == "invalid stage command" and text("remaster_channel_bad_cmd") or tostring(err),error_notice_type())
			return
		end
		dbg.selected_index = idx
		push_notice(text("remaster_channel_added"))
	end))
	ImGui.AddButton(group,"QingRemasterOptions_RemasterChannelRemove",text("remaster_channel_remove"),function()
		local list = remaster.get_channels() or {}
		if #list == 0 or not remaster.remove_channel_at(dbg.selected_index) then
			push_notice(text("remaster_channel_empty"),error_notice_type())
			return
		end
		push_notice(text("remaster_channel_removed"))
	end)
	ImGui.AddButton(group,"QingRemasterOptions_RemasterChannelClearAll",text("remaster_channel_clear_all"),imgui_layout.guard_restricted(function()
		remaster.clear_all_channels()
		dbg.selected_index = 1
		push_notice(text("remaster_channel_cleared"))
	end))
end

local function add_colorblind_bans_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupColorblindBans",text("group_colorblind_bans"))
	add_text(group,text("colorblind_bans_help"))
	local colorblind = require("Qing_Remaster_scripts.items.Item_Colorblindness")
	local list_id = "QingRemasterOptions_ColorblindBanList"
	imgui_layout.add_imgui_text(group, text("group_colorblind_bans")..":\n"..text("colorblind_bans_empty"), true, list_id)
	ImGui.AddCallback(list_id,ImGuiCallback.Render,function()
		local bans = colorblind.list_next_run_bans() or {}
		local body
		if #bans == 0 then
			body = text("colorblind_bans_empty")
		else
			local lines = {}
			for _, id in ipairs(bans) do
				local cfg = Isaac.GetItemConfig and Isaac.GetItemConfig():GetCollectible(id)
				local name = cfg and tostring(cfg.Name or "") or ""
				lines[#lines + 1] = tostring(id)..(name ~= "" and (" - "..name) or "")
			end
			body = table.concat(lines, "\n")
		end
		ImGui.UpdateData(list_id,ImGuiData.Label,text("group_colorblind_bans")..":\n"..body)
	end)
	ImGui.AddButton(group,"QingRemasterOptions_ColorblindClearBans",text("colorblind_bans_clear"),imgui_layout.guard_restricted(function()
		colorblind.clear_next_run_bans()
		push_notice(text("colorblind_bans_cleared"))
	end))
end

local function add_diamond_permanent_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupDiamondPermanent",text("group_diamond_permanent"))
	add_text(group,text("diamond_permanent_help"))
	local diamond = require("Qing_Remaster_scripts.items.Item_Qing_Faceted_Market_Diamond")
	local price_id = "QingRemasterOptions_DiamondPermanentShopPrice"
	ImGui.AddDragFloat(group,price_id,text("diamond_shop_price"),function(value)
		diamond.set_shop_price(value)
	end,diamond.get_shop_price(),1,0,99,"%.0f")
	ImGui.AddCallback(price_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(price_id,ImGuiData.Value,diamond.get_shop_price())
	end)
	imgui_layout.set_helpmarker(price_id,text("diamond_shop_price_help"))
	local sale_id = "QingRemasterOptions_DiamondPermanentLastSale"
	ImGui.AddDragFloat(group,sale_id,text("diamond_last_sale"),function(value)
		diamond.set_last_sale_price(value)
	end,diamond.get_last_sale_price(),1,0,99,"%.0f")
	ImGui.AddCallback(sale_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(sale_id,ImGuiData.Value,diamond.get_last_sale_price())
	end)
	ImGui.AddButton(group,"QingRemasterOptions_DiamondPermanentRestore",text("diamond_permanent_restore"),function()
		diamond.set_shop_price(diamond.base_price or 5)
		diamond.set_last_sale_price(diamond.base_price or 5)
		push_notice(text("diamond_permanent_restore"))
	end)
end

local function add_book_of_future_permanent_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupBookOfFuturePermanent",text("group_book_of_future_permanent"))
	add_text(group,text("book_of_future_progress_help"))
	local future = require("Qing_Remaster_scripts.items.Item_Book_of_Future")
	local progress_id = "QingRemasterOptions_BookOfFutureProgress"
	ImGui.AddDragFloat(group,progress_id,text("book_of_future_progress"),imgui_layout.guard_restricted(function(value)
		future.set_progress(value)
	end),future.get_progress(),1,0,(future.goal or 50) - 1,"%.0f")
	ImGui.AddCallback(progress_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(progress_id,ImGuiData.Value,future.get_progress())
	end)
	ImGui.AddButton(group,"QingRemasterOptions_BookOfFutureProgressRestore",text("book_of_future_progress_restore"),imgui_layout.guard_restricted(function()
		future.set_progress(0)
		push_notice(text("book_of_future_progress_restore"))
	end))
end

local function create_permanent_data_panel(parent_id)
	add_text(parent_id,text("permanent_data_help"))
	create_spectral_editor_panel(parent_id)
	add_remaster_channels_group(parent_id)
	add_colorblind_bans_group(parent_id)
	add_diamond_permanent_group(parent_id)
	add_book_of_future_permanent_group(parent_id)
end

local function add_reserved_judgment_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupReservedJudgment",text("group_reserved_judgment"))
	add_text(group,text("reserved_judgment_help"))
	local reserved = require("Qing_Remaster_scripts.items.Item_Reserved_Judgment")
	add_drag_float(group,"QingRemasterOptions_ReservedJudgmentMarkRange",text("reserved_judgment_mark_range"),{"QingRemasterOptions","Debug","ReservedJudgmentMarkRange"},text("reserved_judgment_mark_range_help"),1,20,240,"%.0f")
	add_drag_float(group,"QingRemasterOptions_ReservedJudgmentIconOffsetX",text("reserved_judgment_icon_x"),{"QingRemasterOptions","Debug","ReservedJudgmentIconOffsetX"},nil,0.25,-64,64,"%.2f")
	add_drag_float(group,"QingRemasterOptions_ReservedJudgmentIconOffsetY",text("reserved_judgment_icon_y"),{"QingRemasterOptions","Debug","ReservedJudgmentIconOffsetY"},nil,0.25,-96,64,"%.2f")
	add_drag_float(group,"QingRemasterOptions_ReservedJudgmentIconScale",text("reserved_judgment_icon_scale"),{"QingRemasterOptions","Debug","ReservedJudgmentIconScale"},nil,0.05,0.1,3,"%.2f")
	ImGui.AddButton(group,"QingRemasterOptions_ReservedJudgmentGive",text("reserved_judgment_give_item"),function()
		if not reserved.debug_give_item() then push_notice(text("start_run_first"),error_notice_type()) end
	end)
	ImGui.AddButton(group,"QingRemasterOptions_ReservedJudgmentSpawnChoices",text("reserved_judgment_spawn_choices"),function()
		if not reserved.debug_spawn_option_choices(3) then push_notice(text("start_run_first"),error_notice_type()) end
	end)
	ImGui.AddButton(group,"QingRemasterOptions_ReservedJudgmentClearTrial",text("reserved_judgment_clear_trial"),function()
		if not reserved.debug_clear_trial() then push_notice(text("start_run_first"),error_notice_type()) end
	end)
	set_module_footer("item_reserved_judgment", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		local defaults = {
			ReservedJudgmentMarkRange = 90,
			ReservedJudgmentIconOffsetX = 18,
			ReservedJudgmentIconOffsetY = 22,
			ReservedJudgmentIconScale = 1,
		}
		for key,value in pairs(defaults) do item.set_value({"QingRemasterOptions","Debug",key},value) end
	end,
})
end

local function add_diamond_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupDiamond",text("group_diamond"))
	add_text(group,text("diamond_help"))
	local diamond = require("Qing_Remaster_scripts.items.Item_Qing_Faceted_Market_Diamond")
	add_drag_float(group,"QingRemasterOptions_DiamondMerchantChance",text("diamond_merchant_chance"),{"QingRemasterOptions","Debug","DiamondMerchantChance"},text("diamond_merchant_chance_help"),0.01,0,1,"%.2f")
	add_text(group,text("diamond_hud_help"))
	add_drag_float(group,"QingRemasterOptions_DiamondHudBaseX",text("diamond_hud_base_x"),{"QingRemasterOptions","Debug","DiamondHudBaseOffsetX"},nil,0.5,-120,120,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudBaseY",text("diamond_hud_base_y"),{"QingRemasterOptions","Debug","DiamondHudBaseOffsetY"},nil,0.5,-160,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudIconX",text("diamond_hud_icon_x"),{"QingRemasterOptions","Debug","DiamondHudIconOffsetX"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudIconY",text("diamond_hud_icon_y"),{"QingRemasterOptions","Debug","DiamondHudIconOffsetY"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudIconScale",text("diamond_hud_icon_scale"),{"QingRemasterOptions","Debug","DiamondHudIconScale"},nil,0.01,0.1,2,"%.2f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudArrowX",text("diamond_hud_arrow_x"),{"QingRemasterOptions","Debug","DiamondHudArrowOffsetX"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudArrowY",text("diamond_hud_arrow_y"),{"QingRemasterOptions","Debug","DiamondHudArrowOffsetY"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudArrowScale",text("diamond_hud_arrow_scale"),{"QingRemasterOptions","Debug","DiamondHudArrowScale"},nil,0.05,0.2,3,"%.2f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudTensX",text("diamond_hud_tens_x"),{"QingRemasterOptions","Debug","DiamondHudDigitTensOffsetX"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudOnesX",text("diamond_hud_ones_x"),{"QingRemasterOptions","Debug","DiamondHudDigitOnesOffsetX"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudDigitY",text("diamond_hud_digit_y"),{"QingRemasterOptions","Debug","DiamondHudDigitOffsetY"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudDigitScale",text("diamond_hud_digit_scale"),{"QingRemasterOptions","Debug","DiamondHudDigitScale"},nil,0.05,0.2,3,"%.2f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudCentX",text("diamond_hud_cent_x"),{"QingRemasterOptions","Debug","DiamondHudCentOffsetX"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudCentY",text("diamond_hud_cent_y"),{"QingRemasterOptions","Debug","DiamondHudCentOffsetY"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudCentScale",text("diamond_hud_cent_scale"),{"QingRemasterOptions","Debug","DiamondHudCentScale"},nil,0.05,0.2,3,"%.2f")
	set_module_footer("item_diamond", {
	restore_label = text("restore_item_defaults"),
	restore = function()
		local hud = diamond.hud_defaults
		local defaults = {
			DiamondMerchantChance = 0.5,
			DiamondHudBaseOffsetX = hud.BaseOffsetX,
			DiamondHudBaseOffsetY = hud.BaseOffsetY,
			DiamondHudIconOffsetX = hud.IconOffsetX,
			DiamondHudIconOffsetY = hud.IconOffsetY,
			DiamondHudIconScale = hud.IconScale,
			DiamondHudArrowOffsetX = hud.ArrowOffsetX,
			DiamondHudArrowOffsetY = hud.ArrowOffsetY,
			DiamondHudArrowScale = hud.ArrowScale,
			DiamondHudDigitTensOffsetX = hud.DigitTensOffsetX,
			DiamondHudDigitOnesOffsetX = hud.DigitOnesOffsetX,
			DiamondHudDigitOffsetY = hud.DigitOffsetY,
			DiamondHudDigitScale = hud.DigitScale,
			DiamondHudCentOffsetX = hud.CentOffsetX,
			DiamondHudCentOffsetY = hud.CentOffsetY,
			DiamondHudCentScale = hud.CentScale,
		}
		for key,value in pairs(defaults) do item.set_value({"QingRemasterOptions","Debug",key},value) end
	end,
})
end

	local title_group = start_mod("visual_title_marquee", DEBUG_PAGE.visual, text("group_title_marquee"), "QingRemasterOptions_GroupTitleMarquee", {
		path = {"Title Marquee"}, kind = "tool",
		footer = {
			restore_label = text("restore_item_defaults"),
			restore = function()
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeStartX"}, 320)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeEndX"}, 80)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeY"}, 95)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeSpeed"}, 28)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeFadeWidth"}, 48)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeLetterSpacing"}, 4)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeRainbowSpeed"}, 0.7)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeWaveSpeed"}, 0.26)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeEdgeIntensity"}, 0.45)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeEdgeWaveWidth"}, 0.75)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeEdgePeakSharpness"}, 6)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeBounceSpeed"}, 2.5)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeBounceTravelSpeed"}, 24)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeBounceHeight"}, 9)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeSquashX"}, 0.10)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeSquashY"}, 0.95)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeImpactSharpness"}, 6)
				item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeTangentRotation"}, 1)
			end,
		},
	})

	do
		local ok_qui, quest_ui_debug = pcall(require, "Qing_Remaster_scripts.debug.quest_ui_debug")
		if ok_qui and quest_ui_debug and quest_ui_debug.build then
			quest_ui_debug.build(api)
		end
	end
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeStartX", text("title_marquee_start_x"), {"QingRemasterOptions", "Debug", "TitleMarqueeStartX"}, text("title_marquee_help"), 1, -200, 800, "%.0f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeEndX", text("title_marquee_end_x"), {"QingRemasterOptions", "Debug", "TitleMarqueeEndX"}, text("title_marquee_help"), 1, -200, 800, "%.0f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeY", text("title_marquee_y"), {"QingRemasterOptions", "Debug", "TitleMarqueeY"}, nil, 1, -100, 400, "%.0f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeSpeed", text("title_marquee_speed"), {"QingRemasterOptions", "Debug", "TitleMarqueeSpeed"}, nil, 1, 0, 240, "%.0f px/s")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeFadeWidth", text("title_marquee_fade"), {"QingRemasterOptions", "Debug", "TitleMarqueeFadeWidth"}, nil, 1, 1, 240, "%.0f px")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeLetterSpacing", text("title_marquee_spacing"), {"QingRemasterOptions", "Debug", "TitleMarqueeLetterSpacing"}, nil, 0.25, 0, 12, "%.1f px")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeRainbowSpeed", text("title_marquee_rainbow_speed"), {"QingRemasterOptions", "Debug", "TitleMarqueeRainbowSpeed"}, nil, 0.01, -2, 2, "%.2f cycle/s")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeWaveSpeed", text("title_marquee_wave_speed"), {"QingRemasterOptions", "Debug", "TitleMarqueeWaveSpeed"}, nil, 0.01, -2, 2, "%.2f cycle/s")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeEdgeIntensity", text("title_marquee_edge_intensity"), {"QingRemasterOptions", "Debug", "TitleMarqueeEdgeIntensity"}, nil, 0.05, 0, 2, "%.2f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeEdgeWaveWidth", text("title_marquee_edge_wave_width"), {"QingRemasterOptions", "Debug", "TitleMarqueeEdgeWaveWidth"}, nil, 0.05, 0.05, 1, "%.2f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeEdgePeakSharpness", text("title_marquee_edge_peak_sharpness"), {"QingRemasterOptions", "Debug", "TitleMarqueeEdgePeakSharpness"}, nil, 0.25, 1, 16, "%.2f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeBounceSpeed", text("title_marquee_bounce_speed"), {"QingRemasterOptions", "Debug", "TitleMarqueeBounceSpeed"}, nil, 0.1, 0, 20, "%.2f rad/s")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeBounceTravelSpeed", text("title_marquee_bounce_travel_speed"), {"QingRemasterOptions", "Debug", "TitleMarqueeBounceTravelSpeed"}, nil, 0.25, 0.1, 60, "%.2f glyph/s")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeBounceHeight", text("title_marquee_bounce_height"), {"QingRemasterOptions", "Debug", "TitleMarqueeBounceHeight"}, nil, 0.25, 0, 20, "%.2f px")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeSquashX", text("title_marquee_squash_x"), {"QingRemasterOptions", "Debug", "TitleMarqueeSquashX"}, nil, 0.01, 0, 1, "%.2f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeSquashY", text("title_marquee_squash_y"), {"QingRemasterOptions", "Debug", "TitleMarqueeSquashY"}, nil, 0.01, 0, 0.95, "%.2f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeImpactSharpness", text("title_marquee_impact_sharpness"), {"QingRemasterOptions", "Debug", "TitleMarqueeImpactSharpness"}, nil, 0.25, 0.25, 16, "%.2f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeTangentRotation", text("title_marquee_tangent_rotation"), {"QingRemasterOptions", "Debug", "TitleMarqueeTangentRotation"}, nil, 0.05, -3, 3, "%.2f x")

		do
		local restore_lighting = function()
			item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingEnabled"}, false)
			item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingAmbient"}, 0.03)
			item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingRadius"}, 220)
			item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingIntensity"}, 1.45)
			item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingSoft"}, 0.18)
			item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingColorR"}, 1)
			item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingColorG"}, 1)
			item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingColorB"}, 1)
		end
		local LIGHTING_CONTROLS = {
			{key = "enabled", kind = "checkbox", label = text("dynamic_lighting_enabled"), path = {"QingRemasterOptions", "Debug", "DynamicLightingEnabled"}, home = true},
			{key = "ambient", kind = "drag_float", label = text("dynamic_lighting_ambient"), path = {"QingRemasterOptions", "Debug", "DynamicLightingAmbient"}, speed = 0.01, min = 0, max = 1, fmt = "%.2f", help = text("dynamic_lighting_ambient_help"), home = true},
			{key = "radius", kind = "drag_float", label = text("dynamic_lighting_radius"), path = {"QingRemasterOptions", "Debug", "DynamicLightingRadius"}, speed = 5, min = 40, max = 800, fmt = "%.0f", home = true},
			{key = "intensity", kind = "drag_float", label = text("dynamic_lighting_intensity"), path = {"QingRemasterOptions", "Debug", "DynamicLightingIntensity"}, speed = 0.05, min = 0, max = 3, fmt = "%.2f", home = true},
			{key = "soft", kind = "drag_float", label = text("dynamic_lighting_soft"), path = {"QingRemasterOptions", "Debug", "DynamicLightingSoft"}, speed = 0.01, min = 0, max = 1, fmt = "%.2f", home = false},
			{key = "color_r", kind = "drag_float", label = text("dynamic_lighting_color_r"), path = {"QingRemasterOptions", "Debug", "DynamicLightingColorR"}, speed = 0.05, min = 0, max = 2, fmt = "%.2f", home = false},
			{key = "color_g", kind = "drag_float", label = text("dynamic_lighting_color_g"), path = {"QingRemasterOptions", "Debug", "DynamicLightingColorG"}, speed = 0.05, min = 0, max = 2, fmt = "%.2f", home = false},
			{key = "color_b", kind = "drag_float", label = text("dynamic_lighting_color_b"), path = {"QingRemasterOptions", "Debug", "DynamicLightingColorB"}, speed = 0.05, min = 0, max = 2, fmt = "%.2f", home = false},
		}
		local lighting_group = start_mod("visual_dynamic_lighting", DEBUG_PAGE.visual, text("group_dynamic_lighting"), "QingRemasterOptions_GroupDynamicLighting", {
			path = {"Dynamic Lighting"}, kind = "tool",
			controls = LIGHTING_CONTROLS,
			home = {enabled = true, controls = {"enabled", "ambient", "radius", "intensity"}},
			footer = {restore_label = text("restore_item_defaults"), restore = restore_lighting},
		})
		add_text(lighting_group, text("dynamic_lighting_help"))
		imgui_layout.render_control_spec(lighting_group, "visual_dynamic_lighting", LIGHTING_CONTROLS, "main")
	end

	-- Dev: Font Awesome icon verification gallery
	imgui_layout.add_icon_gallery(visual_tab)
	do
		-- RGON 1.1.3: ordinary Text paths are literal; expected on-screen == input (not doubled %).
		local fmt_group = "QingRemasterOptions_GroupFormatEscapeTest"
		ImGui.AddElement(visual_tab, fmt_group, ImGuiElement.CollapsingHeader, "ImGui Format Test")
		add_text(fmt_group, "Ordinary Text must match input exactly (100% stays 100%, not 100%%):")
		local samples = {"100%", "%s", "%d", "%p", "%%", "Chance 12.5%", "HP 50%"}
		for i, sample in ipairs(samples) do
			local n = tostring(i)
			imgui_layout.add_plain_text(fmt_group, "QingRemasterOptions_FormatText_" .. n, "Text: " .. sample)
			imgui_layout.add_wrapped_text(fmt_group, "QingRemasterOptions_FormatWrapped_" .. n, "Wrapped: " .. sample)
			imgui_layout.add_bullet_text(fmt_group, "QingRemasterOptions_FormatBullet_" .. n, "Bullet: " .. sample)
		end
		local tip_id = "QingRemasterOptions_FormatTooltipProbe"
		ImGui.AddButton(fmt_group, tip_id, "Hover: Tooltip % samples", function() end)
		imgui_layout.set_tooltip(tip_id, table.concat(samples, " | "))
		imgui_layout.set_helpmarker(tip_id, "HelpMarker is literal-safe: 100% %s %%")
	end

		do
		local restore_torsion = function()
			item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoPeak"}, 0.1)
			item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoStretch"}, 0.07)
			item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoSlideAng"}, 28)
			item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoSegHalfPx"}, 90)
			item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoTotal"}, 60)
			item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoHold"}, 5)
			item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoAngle"}, -1)
			item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoGap"}, 0.00025)
			item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoSoft"}, 0.042)
			item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoBandPx"}, 70)
		end
		local function torsion_trigger()
			local Shader_holder = require("Qing_Remaster_scripts.others.Shader_holder")
			local dbg = save.ModConfigSettings and save.ModConfigSettings.QingRemasterOptions and save.ModConfigSettings.QingRemasterOptions.Debug
			local angle = dbg and tonumber(dbg.TorsionDemoAngle) or -1
			if angle ~= nil and angle < 0 then angle = nil end
			Shader_holder.Trigger_demo({
				peak = dbg and tonumber(dbg.TorsionDemoPeak) or 0.1,
				stretch = dbg and tonumber(dbg.TorsionDemoStretch) or 0.07,
				slide_ang_deg = dbg and tonumber(dbg.TorsionDemoSlideAng) or 28,
				seg_half_px = dbg and tonumber(dbg.TorsionDemoSegHalfPx) or 90,
				total = dbg and tonumber(dbg.TorsionDemoTotal) or 60,
				hold = dbg and tonumber(dbg.TorsionDemoHold) or 5,
				angle_deg = angle,
				gap = dbg and tonumber(dbg.TorsionDemoGap) or 0.00025,
				soft = dbg and tonumber(dbg.TorsionDemoSoft) or 0.042,
				band_px = dbg and tonumber(dbg.TorsionDemoBandPx) or 70,
			})
		end
		local TORSION_CONTROLS = {
			{key = "peak", kind = "drag_float", label = text("torsion_peak"), path = {"QingRemasterOptions", "Debug", "TorsionDemoPeak"}, speed = 0.002, min = 0.0, max = 0.14, fmt = "%.3f", home = true},
			{key = "stretch", kind = "drag_float", label = text("torsion_stretch"), path = {"QingRemasterOptions", "Debug", "TorsionDemoStretch"}, speed = 0.002, min = 0.0, max = 0.14, fmt = "%.3f", home = true},
			{key = "slide_ang", kind = "drag_float", label = text("torsion_slide_ang"), path = {"QingRemasterOptions", "Debug", "TorsionDemoSlideAng"}, speed = 1, min = -90, max = 200, fmt = "%.0f", home = true},
			{key = "band", kind = "drag_float", label = text("torsion_band"), path = {"QingRemasterOptions", "Debug", "TorsionDemoBandPx"}, speed = 1, min = -90, max = 200, fmt = "%.0f", home = true},
			{key = "total", kind = "drag_float", label = text("torsion_total"), path = {"QingRemasterOptions", "Debug", "TorsionDemoTotal"}, speed = 1, min = 0, max = 180, fmt = "%.0f", home = false},
			{key = "hold", kind = "drag_float", label = text("torsion_hold"), path = {"QingRemasterOptions", "Debug", "TorsionDemoHold"}, speed = 1, min = 0, max = 180, fmt = "%.0f", home = false},
			{key = "angle", kind = "drag_float", label = text("torsion_angle"), path = {"QingRemasterOptions", "Debug", "TorsionDemoAngle"}, speed = 1, min = -1, max = 180, fmt = "%.0f", home = false},
			{key = "gap", kind = "drag_float", label = text("torsion_gap"), path = {"QingRemasterOptions", "Debug", "TorsionDemoGap"}, speed = 0.0001, min = 0.0001, max = 0.12, fmt = "%.4f", home = false},
			{key = "soft", kind = "drag_float", label = text("torsion_soft"), path = {"QingRemasterOptions", "Debug", "TorsionDemoSoft"}, speed = 0.0001, min = 0.0001, max = 0.12, fmt = "%.4f", home = false},
			{key = "seg_half", kind = "drag_float", label = text("torsion_seg_half"), path = {"QingRemasterOptions", "Debug", "TorsionDemoSegHalfPx"}, speed = 5, min = 20, max = 400, fmt = "%.0f", home = false},
		}
		local torsion_group = start_mod("visual_torsion", DEBUG_PAGE.visual, text("group_torsion"), "QingRemasterOptions_GroupTorsion", {
			path = {"Torsion"}, kind = "tool",
			controls = TORSION_CONTROLS,
			home = {
				enabled = true,
				controls = {"peak", "stretch", "slide_ang", "band"},
				actions = {{key = "trigger", label = text("torsion_trigger"), on_click = torsion_trigger}},
			},
			footer = {restore_label = text("restore_item_defaults"), restore = restore_torsion},
		})
		imgui_layout.add_action_row(torsion_group, {
			{id = "QingRemasterOptions_TorsionTrigger", label = text("torsion_trigger"), on_click = function()
				torsion_trigger()
				touch_debug_control("visual_torsion", "trigger", text("torsion_trigger"))
			end},
		})
		local torsion_basic = imgui_layout.add_section(torsion_group, "QingRemasterOptions_TorsionBasic", "Basic")
		imgui_layout.render_control_spec(torsion_basic, "visual_torsion", {
			TORSION_CONTROLS[1], TORSION_CONTROLS[2], TORSION_CONTROLS[3], TORSION_CONTROLS[4],
		}, "main")
		local torsion_timing = imgui_layout.add_section(torsion_group, "QingRemasterOptions_TorsionTiming", "Timing")
		imgui_layout.render_control_spec(torsion_timing, "visual_torsion", {
			TORSION_CONTROLS[5], TORSION_CONTROLS[6], TORSION_CONTROLS[7],
		}, "main")
		local torsion_adv = imgui_layout.add_section(torsion_group, "QingRemasterOptions_TorsionAdvanced", "Advanced")
		imgui_layout.render_control_spec(torsion_adv, "visual_torsion", {
			TORSION_CONTROLS[8], TORSION_CONTROLS[9], TORSION_CONTROLS[10],
		}, "main")
	end

	local anna_torsion_group = start_mod("visual_anna_torsion", DEBUG_PAGE.characters, text("group_anna_torsion"), "QingRemasterOptions_GroupAnnaTorsion", {
		path = {"Anna", "Visual", "Torsion"}, kind = "tool",
		footer = {
			restore_label = text("restore_item_defaults"),
			restore = function()
				item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionPeak"}, 0.1)
				item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionStretchRatio"}, 0.7)
				item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionSlideAng"}, 28)
				item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionGap"}, 0.0002)
				item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionSoft"}, 0.045)
				item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionBandPx"}, 52)
				item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionTotal"}, 14)
				item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionHold"}, 2)
				item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionFrame"}, 5)
			end,
		},
	})
	add_text(anna_torsion_group, text("anna_torsion_help"))
	local anna_basic = imgui_layout.add_section(anna_torsion_group, "QingRemasterOptions_AnnaTorsionBasic", "Basic")
	add_drag_pair_path(anna_basic, "QingRemasterOptions_AnnaTorsionPeak", text("anna_torsion_peak"), {"QingRemasterOptions", "Debug", "AnnaTorsionPeak"}, "QingRemasterOptions_AnnaTorsionStretchRatio", text("anna_torsion_stretch_ratio"), {"QingRemasterOptions", "Debug", "AnnaTorsionStretchRatio"}, {speed = 0.002, min = 0.0, max = 2.0, fmt = "%.3f"})
	add_drag_pair_path(anna_basic, "QingRemasterOptions_AnnaTorsionSlideAng", text("anna_torsion_slide_ang"), {"QingRemasterOptions", "Debug", "AnnaTorsionSlideAng"}, "QingRemasterOptions_AnnaTorsionBandPx", text("anna_torsion_band"), {"QingRemasterOptions", "Debug", "AnnaTorsionBandPx"}, {speed = 1, min = -90, max = 160, fmt = "%.0f"})
	local anna_timing = imgui_layout.add_section(anna_torsion_group, "QingRemasterOptions_AnnaTorsionTiming", "Timing")
	add_drag_pair_path(anna_timing, "QingRemasterOptions_AnnaTorsionTotal", text("anna_torsion_total"), {"QingRemasterOptions", "Debug", "AnnaTorsionTotal"}, "QingRemasterOptions_AnnaTorsionHold", text("anna_torsion_hold"), {"QingRemasterOptions", "Debug", "AnnaTorsionHold"}, {speed = 1, min = 0, max = 60, fmt = "%.0f"})
	add_drag_float(anna_timing, "QingRemasterOptions_AnnaTorsionFrame", text("anna_torsion_frame"), {"QingRemasterOptions", "Debug", "AnnaTorsionFrame"}, nil, 1, 1, 20, "%.0f")
	local anna_adv = imgui_layout.add_section(anna_torsion_group, "QingRemasterOptions_AnnaTorsionAdvanced", "Advanced")
	add_drag_pair_path(anna_adv, "QingRemasterOptions_AnnaTorsionGap", text("anna_torsion_gap"), {"QingRemasterOptions", "Debug", "AnnaTorsionGap"}, "QingRemasterOptions_AnnaTorsionSoft", text("anna_torsion_soft"), {"QingRemasterOptions", "Debug", "AnnaTorsionSoft"}, {speed = 0.0001, min = 0.0001, max = 0.12, fmt = "%.4f"})

	local theseus_group = start_mod("visual_theseus", DEBUG_PAGE.visual, text("group_theseus_notice"), "QingRemasterOptions_GroupTheseusNotice", {
		path = {"Theseus Notice"}, kind = "tool",
		footer = {
			restore_label = text("restore_item_defaults"),
			restore = function()
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeAlwaysShow"}, false)
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeSourceY"}, 0)
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeColonY"}, -7.25)
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeAmountY"}, -7.25)
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeTriggerY"}, -3)
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeArrowY"}, -6)
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeActionY"}, -0.75)
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeSourceScale"}, 0.5)
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeColonScale"}, 1)
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeAmountScale"}, 1)
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeTriggerScale"}, 0.5)
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeArrowScale"}, 1)
				item.set_value({"QingRemasterOptions", "Debug", "TheseusNoticeActionScale"}, 0.5)
			end,
		},
	})
	add_checkbox(theseus_group, "QingRemasterOptions_TheseusNoticeAlwaysShow", text("theseus_always_show"), {"QingRemasterOptions", "Debug", "TheseusNoticeAlwaysShow"}, text("theseus_always_show_help"))
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeSourceY", text("theseus_source_y"), {"QingRemasterOptions", "Debug", "TheseusNoticeSourceY"})
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeColonY", text("theseus_colon_y"), {"QingRemasterOptions", "Debug", "TheseusNoticeColonY"})
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeAmountY", text("theseus_amount_y"), {"QingRemasterOptions", "Debug", "TheseusNoticeAmountY"})
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeTriggerY", text("theseus_trigger_y"), {"QingRemasterOptions", "Debug", "TheseusNoticeTriggerY"})
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeArrowY", text("theseus_arrow_y"), {"QingRemasterOptions", "Debug", "TheseusNoticeArrowY"})
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeActionY", text("theseus_action_y"), {"QingRemasterOptions", "Debug", "TheseusNoticeActionY"})
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeSourceScale", text("theseus_source_scale"), {"QingRemasterOptions", "Debug", "TheseusNoticeSourceScale"}, nil, 0.01, 0.2, 1.2)
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeColonScale", text("theseus_colon_scale"), {"QingRemasterOptions", "Debug", "TheseusNoticeColonScale"}, nil, 0.05, 0.5, 2)
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeAmountScale", text("theseus_amount_scale"), {"QingRemasterOptions", "Debug", "TheseusNoticeAmountScale"}, nil, 0.05, 0.5, 2)
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeTriggerScale", text("theseus_trigger_scale"), {"QingRemasterOptions", "Debug", "TheseusNoticeTriggerScale"}, nil, 0.01, 0.2, 1.2)
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeArrowScale", text("theseus_arrow_scale"), {"QingRemasterOptions", "Debug", "TheseusNoticeArrowScale"}, nil, 0.05, 0.5, 2)
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeActionScale", text("theseus_action_scale"), {"QingRemasterOptions", "Debug", "TheseusNoticeActionScale"}, nil, 0.01, 0.2, 1.2)
	if dev_env.probes_allowed() then
		local ok_hotkey, anim_hotkey = pcall(require, "Qing_Remaster_scripts.debug.player_anim_hotkey_dev")
		if ok_hotkey and anim_hotkey and anim_hotkey.build then
			local zh_hotkey = language_key() == "zh"
			local anim_hotkey_group = start_mod(
				"visual_player_anim_hotkey",
				DEBUG_PAGE.visual,
				zh_hotkey and "玩家动画热键" or "Player Anim Hotkey",
				"QingRemasterOptions_GroupPlayerAnimHotkey",
				{path = {"Player Anim Hotkey"}, kind = "tool"}
			)
			anim_hotkey.build(anim_hotkey_group, api)
		end
	end
	do
		local restore_super_bombs = function()
			item.set_value({"QingRemasterOptions", "Debug", "SuperBombsBombGrowthSeconds"}, 20)
			item.set_value({"QingRemasterOptions", "Debug", "SuperBombsMamaGrowthSeconds"}, 120)
			item.set_value({"QingRemasterOptions", "Debug", "SuperBombsTimerX"}, -5)
			item.set_value({"QingRemasterOptions", "Debug", "SuperBombsTimerY"}, -5)
			item.set_value({"QingRemasterOptions", "Debug", "SuperBombsMamaTimerX"}, 5)
			item.set_value({"QingRemasterOptions", "Debug", "SuperBombsMamaTimerY"}, 9)
		end
		local SUPER_BOMBS_CONTROLS = {
			{key = "bomb_growth", kind = "drag_float", label = text("super_bombs_bomb_seconds"), path = {"QingRemasterOptions", "Debug", "SuperBombsBombGrowthSeconds"}, speed = 1, min = 1, max = 120, fmt = "%.0f s", help = text("super_bombs_bomb_seconds_help"), home = true},
			{key = "mama_growth", kind = "drag_float", label = text("super_bombs_mama_seconds"), path = {"QingRemasterOptions", "Debug", "SuperBombsMamaGrowthSeconds"}, speed = 1, min = 1, max = 600, fmt = "%.0f s", help = text("super_bombs_mama_seconds_help"), home = true},
			{key = "timer_x", kind = "drag_float", label = text("super_bombs_timer_x"), path = {"QingRemasterOptions", "Debug", "SuperBombsTimerX"}, speed = 0.25, min = -100, max = 100, fmt = "%.2f", help = text("super_bombs_timer_x_help"), home = true},
			{key = "timer_y", kind = "drag_float", label = text("super_bombs_timer_y"), path = {"QingRemasterOptions", "Debug", "SuperBombsTimerY"}, speed = 0.25, min = -100, max = 100, fmt = "%.2f", help = text("super_bombs_timer_y_help"), home = true},
			{key = "mama_timer_x", kind = "drag_float", label = text("super_bombs_mama_timer_x"), path = {"QingRemasterOptions", "Debug", "SuperBombsMamaTimerX"}, speed = 0.25, min = -100, max = 100, fmt = "%.2f", help = text("super_bombs_mama_timer_x_help"), home = true},
			{key = "mama_timer_y", kind = "drag_float", label = text("super_bombs_mama_timer_y"), path = {"QingRemasterOptions", "Debug", "SuperBombsMamaTimerY"}, speed = 0.25, min = -100, max = 100, fmt = "%.2f", help = text("super_bombs_mama_timer_y_help"), home = true},
		}
		local super_bombs_group = start_mod("item_super_bombs", DEBUG_PAGE.items, text("group_super_bombs"), "QingRemasterOptions_GroupSuperBombs", {
			path = {"Super Bombs"}, kind = "tool",
			controls = SUPER_BOMBS_CONTROLS,
			home = {enabled = true, controls = {"bomb_growth", "mama_growth", "timer_x", "timer_y", "mama_timer_x", "mama_timer_y"}},
			footer = {restore_label = text("restore_item_defaults"), restore = restore_super_bombs},
		})
		imgui_layout.render_control_spec(super_bombs_group, "item_super_bombs", SUPER_BOMBS_CONTROLS, "main")
	end
	local function restore_blueprint_defaults()
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintDotOffsetX"}, -2)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintDotOffsetY"}, -9)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintBgOffsetX"}, 0)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintBgOffsetY"}, 13)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintAuditTextY"}, 2)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintSlotCount"}, 3)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCostOffsetY"}, 21)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCostExtraCount"}, 0)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCostSlotSize"}, 18)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCostTokenScale"}, 0.5)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCostQmarkOffsetX"}, -2)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCostQmarkOffsetY"}, 1)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCraftGroupY"}, 14)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintTagColOffsetX"}, -36)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintTagColOffsetY"}, 0)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintTagColWidth"}, 56)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintShowSourceMarks"}, false)
		local env = require("Qing_Remaster_scripts.core.dev_environment")
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintAllItemsModeEnabled"}, not env.is_public_release())
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintSettingsVersion"}, 8)
	end
	local blue_print_group = start_mod("item_blueprint", DEBUG_PAGE.items, text("group_blue_print"), "QingRemasterOptions_GroupBluePrint", {path = {"Blueprint"}, kind = "tool", footer = {restore = restore_blueprint_defaults, restore_label = text("restore_item_defaults")}})
	local bp_general = imgui_layout.add_section(blue_print_group, "QingRemasterOptions_BlueprintGeneral", "General")
	add_drag_float(bp_general, "QingRemasterOptions_BlueprintSlotCount", text("blueprint_slot_count"), {"QingRemasterOptions", "Debug", "BlueprintSlotCount"}, text("blueprint_slot_count_help"), 1, 1, 7, "%.0f")
	add_checkbox(bp_general, "QingRemasterOptions_BlueprintShowSourceMarks", text("blueprint_show_source_marks"), {"QingRemasterOptions", "Debug", "BlueprintShowSourceMarks"}, text("blueprint_show_source_marks_help"))
	add_checkbox(bp_general, "QingRemasterOptions_BlueprintAllItemsModeEnabled", text("blueprint_all_items_mode"), {"QingRemasterOptions", "Debug", "BlueprintAllItemsModeEnabled"}, text("blueprint_all_items_mode_help"))

	local bp_ui = imgui_layout.add_section(blue_print_group, "QingRemasterOptions_BlueprintUI", "UI")
	local bp_ui_main = imgui_layout.add_tree(bp_ui, "QingRemasterOptions_BlueprintUIMain", "Main Layout")
	add_drag_pair_path(
		bp_ui_main,
		"QingRemasterOptions_BlueprintDotOffsetX", text("blueprint_dot_x"), {"QingRemasterOptions", "Debug", "BlueprintDotOffsetX"},
		"QingRemasterOptions_BlueprintDotOffsetY", text("blueprint_dot_y"), {"QingRemasterOptions", "Debug", "BlueprintDotOffsetY"},
		{speed = 0.25, min = -40, max = 40, left_help = text("blueprint_dot_help"), right_help = text("blueprint_dot_help")}
	)
	add_drag_pair_path(
		bp_ui_main,
		"QingRemasterOptions_BlueprintBgOffsetX", text("blueprint_bg_x"), {"QingRemasterOptions", "Debug", "BlueprintBgOffsetX"},
		"QingRemasterOptions_BlueprintBgOffsetY", text("blueprint_bg_y"), {"QingRemasterOptions", "Debug", "BlueprintBgOffsetY"},
		{speed = 0.25, min = -80, max = 80, left_help = text("blueprint_bg_help"), right_help = text("blueprint_bg_help")}
	)
	add_drag_float(bp_ui_main, "QingRemasterOptions_BlueprintAuditTextY", text("blueprint_audit_y"), {"QingRemasterOptions", "Debug", "BlueprintAuditTextY"}, text("blueprint_audit_y_help"), 0.5, -40, 80)
	add_drag_float(bp_ui_main, "QingRemasterOptions_BlueprintCraftGroupY", text("blueprint_craft_group_y"), {"QingRemasterOptions", "Debug", "BlueprintCraftGroupY"}, text("blueprint_craft_group_y_help"), 0.5, -60, 80)
	local bp_ui_cost = imgui_layout.add_tree(bp_ui, "QingRemasterOptions_BlueprintUICost", "Cost Layout")
	add_drag_float(bp_ui_cost, "QingRemasterOptions_BlueprintCostOffsetY", text("blueprint_cost_y"), {"QingRemasterOptions", "Debug", "BlueprintCostOffsetY"}, text("blueprint_cost_y_help"), 0.5, -20, 80)
	add_drag_float(bp_ui_cost, "QingRemasterOptions_BlueprintCostExtraCount", text("blueprint_cost_extra"), {"QingRemasterOptions", "Debug", "BlueprintCostExtraCount"}, text("blueprint_cost_extra_help"), 1, 0, 12, "%.0f")
	add_drag_float(bp_ui_cost, "QingRemasterOptions_BlueprintCostSlotSize", text("blueprint_cost_slot_size"), {"QingRemasterOptions", "Debug", "BlueprintCostSlotSize"}, text("blueprint_cost_slot_size_help"), 1, 8, 48, "%.0f")
	add_drag_float(bp_ui_cost, "QingRemasterOptions_BlueprintCostTokenScale", text("blueprint_cost_scale"), {"QingRemasterOptions", "Debug", "BlueprintCostTokenScale"}, text("blueprint_cost_scale_help"), 0.05, 0.15, 1.2)
	add_drag_pair_path(
		bp_ui_cost,
		"QingRemasterOptions_BlueprintCostQmarkOffsetX", text("blueprint_cost_qmark_x"), {"QingRemasterOptions", "Debug", "BlueprintCostQmarkOffsetX"},
		"QingRemasterOptions_BlueprintCostQmarkOffsetY", text("blueprint_cost_qmark_y"), {"QingRemasterOptions", "Debug", "BlueprintCostQmarkOffsetY"},
		{speed = 0.25, min = -20, max = 20, left_help = text("blueprint_cost_qmark_help"), right_help = text("blueprint_cost_qmark_help")}
	)
	local bp_ui_tag = imgui_layout.add_tree(bp_ui, "QingRemasterOptions_BlueprintUITag", "Tag Layout")
	add_drag_pair_path(
		bp_ui_tag,
		"QingRemasterOptions_BlueprintTagColOffsetX", text("blueprint_tag_col_x"), {"QingRemasterOptions", "Debug", "BlueprintTagColOffsetX"},
		"QingRemasterOptions_BlueprintTagColOffsetY", text("blueprint_tag_col_y"), {"QingRemasterOptions", "Debug", "BlueprintTagColOffsetY"},
		{speed = 0.5, min = -120, max = 80, left_help = text("blueprint_tag_col_help"), right_help = text("blueprint_tag_col_help")}
	)
	add_drag_float(bp_ui_tag, "QingRemasterOptions_BlueprintTagColWidth", text("blueprint_tag_col_w"), {"QingRemasterOptions", "Debug", "BlueprintTagColWidth"}, text("blueprint_tag_col_w_help"), 1, 40, 96, "%.0f")

	local bp_manuf = imgui_layout.add_section(blue_print_group, "QingRemasterOptions_BlueprintManufacture", "Manufacture")
	if item.get_value({"QingRemasterOptions", "Debug", "PrototypeSpawnId"}) == nil then
		item.set_value({"QingRemasterOptions", "Debug", "PrototypeSpawnId"}, 118)
	end
	add_drag_float(bp_manuf, "QingRemasterOptions_PrototypeSpawnId", "原型 ID", {"QingRemasterOptions", "Debug", "PrototypeSpawnId"}, "Collectible ID for debug spawn", 1, 1, 732, "%.0f")
	imgui_layout.add_action_row(bp_manuf, {
		{id = "QingRemasterOptions_SpawnPrototype", label = "生成指定原型", on_click = function()
			local ok, proto = pcall(require, "Qing_Remaster_scripts.pickups.pickup_blueprint_prototype")
			local id = math.floor(tonumber(item.get_value({"QingRemasterOptions", "Debug", "PrototypeSpawnId"})) or 118)
			local p = Isaac.GetPlayer(0)
			if ok and proto and proto.spawn_prototype and p then
				proto.spawn_prototype(p.Position, id, {source = "debug", spawner = p})
			end
		end},
		{id = "QingRemasterOptions_ClearPrototypes", label = "清空原型库存", on_click = function()
			local ok, bp = pcall(require, "Qing_Remaster_scripts.items.Item_Blue_Print")
			local p = Isaac.GetPlayer(0)
			if ok and bp and bp.clear_prototypes and p then bp.clear_prototypes(p) end
		end},
		{id = "QingRemasterOptions_ForceCleanProto", label = "强制下次清房掉落原型", on_click = function()
			local ok, proto = pcall(require, "Qing_Remaster_scripts.pickups.pickup_blueprint_prototype")
			if ok and proto then
				proto.force_next_clean = true
				local bp = require("Qing_Remaster_scripts.items.Item_Blue_Print")
				local root = bp.ensure_prototype_root and bp.ensure_prototype_root()
				if root then root.force_next_clean = true end
			end
		end},
	})

	local bp_compat = imgui_layout.add_section(blue_print_group, "QingRemasterOptions_BlueprintCompat", "Compatibility")
	local bp_diag = imgui_layout.add_section(blue_print_group, "QingRemasterOptions_BlueprintDiag", "Tutorial Tools")
	add_text(bp_diag, text("blueprint_tutorial_help"))
	local tut_status_id = "QingRemasterOptions_BlueprintTutorialStatus"
	imgui_layout.add_wrapped_text(bp_diag, tut_status_id, text("blueprint_tutorial_status"))
	ImGui.AddCallback(tut_status_id, ImGuiCallback.Render, function()
		local ok, tut = pcall(require, "Qing_Remaster_scripts.others.blueprint_tutorial")
		local body = (ok and tut and tut.status_text and tut.status_text()) or text("blueprint_tutorial_status")
		imgui_layout.update_text(tut_status_id, body)
	end)
	local function tut_player()
		local n = Game():GetNumPlayers()
		if not n or n < 1 then return Isaac.GetPlayer(0) end
		for i = 0, n - 1 do
			local p = Game():GetPlayer(i)
			if p and p:GetPlayerType() == enums.Players.Spwq then return p end
		end
		return Isaac.GetPlayer(0)
	end
	imgui_layout.add_action_row(bp_diag, {
		{id = "QingRemasterOptions_BlueprintTutorialStart", label = text("blueprint_tutorial_start"), on_click = function()
			local ok, tut = pcall(require, "Qing_Remaster_scripts.others.blueprint_tutorial")
			if ok and tut and tut.start then tut.start(tut_player(), {debug = true}) end
		end},
		{id = "QingRemasterOptions_BlueprintTutorialStartSkip", label = text("blueprint_tutorial_start_skip"), on_click = function()
			local ok, tut = pcall(require, "Qing_Remaster_scripts.others.blueprint_tutorial")
			if ok and tut and tut.start then tut.start(tut_player(), {debug = true, skip_prompt = true}) end
		end},
	})
	imgui_layout.add_small_action_row(bp_diag, {
		{id = "QingRemasterOptions_BlueprintTutorialAbort", label = text("blueprint_tutorial_abort"), on_click = function()
			local ok, tut = pcall(require, "Qing_Remaster_scripts.others.blueprint_tutorial")
			if ok and tut and tut.abort then tut.abort(tut_player()) end
		end},
		{id = "QingRemasterOptions_BlueprintTutorialReset", label = text("blueprint_tutorial_reset"), on_click = function()
			local ok, tut = pcall(require, "Qing_Remaster_scripts.others.blueprint_tutorial")
			if ok and tut and tut.reset_flags then tut.reset_flags(tut_player()) end
		end},
	})
	local bp_data = imgui_layout.add_section(blue_print_group, "QingRemasterOptions_BlueprintData", "Data")

	local craft_fam_group = start_mod("flight_craft_familiar", DEBUG_PAGE.items, text("group_craft_familiar"), "QingRemasterOptions_GroupCraftFamiliar", {parent = bp_compat, path = {"Blueprint", "Compatibility", "Familiar"}, kind = "tool"})
	do
		local status_id = "QingRemasterOptions_CraftFamiliarStatus"
		local function craft_fam_status_text()
			local ok, holder = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
			if not ok or not holder or not holder.debug_snapshot then
				return text("craft_familiar_status")
			end
			local rows = holder.debug_snapshot() or {}
			if #rows == 0 then
				return text("craft_familiar_status")
			end
			local lines = {}
			for i = 1, #rows do
				local r = rows[i]
				local aim = r.aim
				local aim_s = "nil"
				if aim then
					aim_s = string.format("%.0f,%.0f", aim.X or 0, aim.Y or 0)
				end
				lines[#lines + 1] = string.format(
					"uid=%s var=%s ad=%s mode=%s cd=%s shoot=%s aim=(%s) focus=%s st=%s",
					tostring(r.uid), tostring(r.variant), tostring(r.adapter), tostring(r.mode),
					tostring(r.cd), tostring(r.should), aim_s, tostring(r.focus), tostring(r.state)
				)
			end
			return table.concat(lines, "\n")
		end
		-- debug_snapshot 会按所有 adapter Variant 扫描实体；禁止挂常驻 Render 刷新。
		-- 仅用户点击时采一份快照，避免隐藏 ImGui 分组也持续做房间扫描。
		imgui_layout.add_wrapped_text(craft_fam_group, status_id, text("craft_familiar_status"))
		ImGui.AddButton(craft_fam_group, "QingRemasterOptions_CraftFamiliarRefreshStatus", "刷新宝宝状态", function()
			imgui_layout.update_text(status_id, craft_fam_status_text())
		end)
		local freeze_id = "QingRemasterOptions_CraftFamiliarFreezeCd"
		ImGui.AddCheckbox(craft_fam_group, freeze_id, text("craft_familiar_freeze_cd"), nil, false)
		imgui_layout.set_helpmarker(freeze_id, text("craft_familiar_freeze_cd_help"))
		ImGui.AddCallback(freeze_id, ImGuiCallback.Render, function()
			local ok, holder = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
			ImGui.UpdateData(freeze_id, ImGuiData.Value, ok and holder and holder.debug_freeze_cooldown == true)
		end)
		ImGui.AddCallback(freeze_id, ImGuiCallback.Edited, function(value)
			local ok, holder = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
			if ok and holder then holder.debug_freeze_cooldown = value == true end
		end)
		local force_id = "QingRemasterOptions_CraftFamiliarForceFire"
		ImGui.AddCheckbox(craft_fam_group, force_id, text("craft_familiar_force_fire"), nil, false)
		imgui_layout.set_helpmarker(force_id, text("craft_familiar_force_fire_help"))
		ImGui.AddCallback(force_id, ImGuiCallback.Render, function()
			local ok, holder = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
			ImGui.UpdateData(force_id, ImGuiData.Value, ok and holder and holder.debug_force_fire == true)
		end)
		ImGui.AddCallback(force_id, ImGuiCallback.Edited, function(value)
			local ok, holder = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
			if ok and holder then holder.debug_force_fire = value == true end
		end)
		ImGui.AddButton(craft_fam_group, "QingRemasterOptions_CraftFamiliarRestore", text("craft_familiar_restore"), function()
			local ok, holder = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
			if ok and holder then
				holder.debug_freeze_cooldown = false
				holder.debug_force_fire = false
			end
			local ok2, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok2 and air then
				air.debug_move_spd = 0
				air.debug_force_luck = nil
			end
		end)
		local move_id = "QingRemasterOptions_AirFlightDebugMoveSpd"
		ImGui.AddDragFloat(craft_fam_group, move_id, text("air_debug_move_spd"), function(value)
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air then air.debug_move_spd = tonumber(value) or 0 end
		end, 0, 0.05, 0, 3, "%.2f")
		imgui_layout.set_helpmarker(move_id, text("air_debug_move_spd_help"))
		ImGui.AddCallback(move_id, ImGuiCallback.Render, function()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			local v = (ok and air and tonumber(air.debug_move_spd)) or 0
			ImGui.UpdateData(move_id, ImGuiData.Value, v)
		end)
		local luck_id = "QingRemasterOptions_AirFlightForceLuck"
		local hit_id = "QingRemasterOptions_AirFlightHitStatus"
		local function refresh_air_hit_status()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			local body = text("air_debug_hit_status")
			if ok and air then
				-- 禁止在 ImGui Render 里 FindByType；仅按钮/勾选时扫一次，且全程 pcall
				local ok2, s = pcall(function()
					return air.get_hit_rate_summary and air.get_hit_rate_summary() or body
				end)
				if ok2 and type(s) == "string" then
					body = s
				elseif air.get_luck_debug_line then
					local ok3, line = pcall(air.get_luck_debug_line)
					if ok3 and type(line) == "string" then body = line end
				end
			end
			imgui_layout.update_text(hit_id, body)
		end
		ImGui.AddCheckbox(craft_fam_group, luck_id, text("air_debug_force_luck"), function(value)
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air then
				air.debug_force_luck = (value == true) and 99 or nil
			end
			-- 勾选后只刷新幸运行安全文本；完整统计点刷新按钮
			if ok and air and air.get_luck_debug_line then
				local ok2, line = pcall(air.get_luck_debug_line)
				if ok2 and type(line) == "string" then
					imgui_layout.update_text(hit_id, line)
				end
			end
		end, false)
		imgui_layout.set_helpmarker(luck_id, text("air_debug_force_luck_help"))
		ImGui.AddCallback(luck_id, ImGuiCallback.Render, function()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			local on = ok and air and tonumber(air.debug_force_luck) and tonumber(air.debug_force_luck) > 0
			ImGui.UpdateData(luck_id, ImGuiData.Value, on == true)
		end)
		-- 与「宝宝状态」相同：禁止挂常驻 Render 做房间扫描（FindByType 易在 ImGui 重绘时崩）
		imgui_layout.add_wrapped_text(craft_fam_group, hit_id, text("air_debug_hit_status"))
		ImGui.AddButton(craft_fam_group, "QingRemasterOptions_AirFlightHitRefresh", text("air_debug_hit_refresh"), function()
			refresh_air_hit_status()
		end)
	end
	local aura_balance_group = start_mod("flight_aura_balance", DEBUG_PAGE.items, text("group_aura_balance"), "QingRemasterOptions_GroupAuraBalance", {parent = bp_compat, path = {"Blueprint", "Compatibility", "Aura"}, kind = "tool"})
	do
		local function aura_mod()
			local ok, mod = pcall(require, "Qing_Remaster_scripts.others.craft_aura_effects")
			if ok then return mod end
			return nil
		end
		add_text(aura_balance_group, text("aura_balance_help"))
		local function add_aura_float(suffix, label_key, cfg_key, default_v, speed, min_v, max_v, fmt)
			local eid = "QingRemasterOptions_AuraBal_" .. suffix
			ImGui.AddDragFloat(aura_balance_group, eid, text(label_key), function(value)
				local mod = aura_mod()
				if mod and mod.set_cfg then mod.set_cfg(cfg_key, tonumber(value) or default_v) end
			end, default_v, speed, min_v, max_v, fmt)
			ImGui.AddCallback(eid, ImGuiCallback.Render, function()
				local mod = aura_mod()
				local v = default_v
				if mod and mod.get_cfg then
					local cur = tonumber(mod.get_cfg(cfg_key))
					if cur then v = cur end
				end
				ImGui.UpdateData(eid, ImGuiData.Value, v)
			end)
		end
		add_aura_float("MonRadius", "aura_bal_mon_radius", "monstrance_radius", 45, 0.5, 10, 160, "%.1f")
		add_aura_float("MonScale", "aura_bal_mon_scale", "monstrance_fx_scale", 0.5, 0.01, 0.1, 2.0, "%.2f")
		add_aura_float("MonInterval", "aura_bal_mon_interval", "monstrance_interval", 4, 0.25, 1, 30, "%.0f")
		ImGui.AddButton(aura_balance_group, "QingRemasterOptions_AuraBalRestore", text("aura_bal_restore"), function()
			local mod = aura_mod()
			if mod and mod.reset_cfg then
				mod.reset_cfg({"monstrance_radius", "monstrance_fx_scale", "monstrance_interval"})
			end
		end)
	end
	local flight_crash_group = start_mod("flight_crash", DEBUG_PAGE.items, text("group_flight_crash"), "QingRemasterOptions_GroupFlightCrash", {parent = bp_compat, path = {"Blueprint", "Compatibility", "Flight Crash"}, kind = "tool"})
	do
		local function crash_get(key, default)
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air and air.crash_fx and air.crash_fx[key] ~= nil then
				return air.crash_fx[key]
			end
			local cfg = item.get_value({"QingRemasterOptions", "Debug", "FlightCrash_" .. key})
			if cfg ~= nil then return cfg end
			return default
		end
		local function crash_set(key, value)
			value = tonumber(value) or 0
			item.set_value({"QingRemasterOptions", "Debug", "FlightCrash_" .. key}, value)
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air then
				air.crash_fx = air.crash_fx or {}
				air.crash_fx[key] = value
			end
		end
		local function add_crash_float(id, label_key, key, default, speed, min_v, max_v, fmt)
			local eid = "QingRemasterOptions_FlightCrash_" .. id
			ImGui.AddDragFloat(flight_crash_group, eid, text(label_key), function(value)
				crash_set(key, value)
			end, tonumber(crash_get(key, default)) or default, speed or 0.05, min_v or 0, max_v or 40, fmt or "%.2f")
			ImGui.AddCallback(eid, ImGuiCallback.Render, function()
				ImGui.UpdateData(eid, ImGuiData.Value, tonumber(crash_get(key, default)) or default)
			end)
		end
		add_crash_float("FailFrames", "flight_crash_fail_frames", "fail_frames", 7, 1, 4, 16, "%.0f")
		add_crash_float("Gravity", "flight_crash_gravity", "gravity", 0.38, 0.01, 0.1, 1.2, "%.2f")
		add_crash_float("MaxFall", "flight_crash_max_fall", "max_fall_speed", 7.5, 0.1, 2, 14, "%.1f")
		add_crash_float("Drift", "flight_crash_drift", "drift_retain", 0.985, 0.001, 0.9, 1, "%.3f")
		add_crash_float("Slip", "flight_crash_slip", "side_slip_max", 1.8, 0.05, 0, 4, "%.2f")
		add_crash_float("FallSmoke", "flight_crash_fall_smoke", "fall_smoke_interval", 5, 1, 2, 20, "%.0f")
		add_crash_float("TumbleFric", "flight_crash_tumble_fric", "tumble_friction", 0.90, 0.005, 0.7, 0.98, "%.2f")
		add_crash_float("TumbleMax", "flight_crash_tumble_max", "tumble_max_frames", 24, 1, 10, 60, "%.0f")
		add_crash_float("ImpactDust", "flight_crash_impact_dust", "impact_dust_count", 8, 1, 2, 20, "%.0f")
		add_crash_float("DeadMin", "flight_crash_dead_min", "dead_smoke_min", 18, 1, 6, 60, "%.0f")
		add_crash_float("DeadMax", "flight_crash_dead_max", "dead_smoke_max", 30, 1, 6, 90, "%.0f")
		add_crash_float("Shake", "flight_crash_shake", "screen_shake", 4, 1, 0, 12, "%.0f")
		add_crash_float("Cap", "flight_crash_cap", "particle_cap", 10, 1, 2, 30, "%.0f")
		ImGui.AddButton(flight_crash_group, "QingRemasterOptions_FlightCrashForce", text("flight_crash_force"), function()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air and air.debug_force_crash then air.debug_force_crash({}) end
		end)
		ImGui.AddButton(flight_crash_group, "QingRemasterOptions_FlightCrashForceRevive", text("flight_crash_force_revive"), function()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air and air.debug_force_crash then air.debug_force_crash({revive = true}) end
		end)
		ImGui.AddButton(flight_crash_group, "QingRemasterOptions_FlightCrashClear", text("flight_crash_clear"), function()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air and air.debug_clear_crash_fx then air.debug_clear_crash_fx() end
		end)
		ImGui.AddButton(flight_crash_group, "QingRemasterOptions_FlightCrashRestore", text("flight_crash_restore"), function()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air and air.crash_fx_restore_defaults then
				air.crash_fx_restore_defaults()
			end
		end)
	end
	local attack_trigger_group = start_mod("system_attack_trigger", DEBUG_PAGE.systems, text("group_attack_callbacks"), "QingRemasterOptions_GroupAttackCallbacks", {path = {"Attack Trigger"}, kind = "tool"})
	do
		add_checkbox(attack_trigger_group, "QingRemasterOptions_TriggerLaserStart", text("trigger_laser_start"), {"Trigger_LaserStart"}, text("trigger_laser_start_help"))
		add_checkbox(attack_trigger_group, "QingRemasterOptions_TriggerLaserEnd", text("trigger_laser_end"), {"Trigger_LaserEnd"}, text("trigger_laser_end_help"))
		add_checkbox(attack_trigger_group, "QingRemasterOptions_TriggerBrimStart", text("trigger_brim_start"), {"Trigger_BrimStart"}, text("trigger_brim_start_help"))
		add_checkbox(attack_trigger_group, "QingRemasterOptions_TriggerBrimEnd", text("trigger_brim_end"), {"Trigger_BrimEnd"}, text("trigger_brim_end_help"))
	end
	local temp_revive_group = start_mod("audit_temp_revive", DEBUG_PAGE.systems, text("group_temp_revive"), "QingRemasterOptions_GroupTempRevive", {path = {"Temporary Revive"}, kind = "tool"})
	do
		add_text(temp_revive_group, text("temp_revive_help"))
		local log_id = "QingRemasterOptions_TempReviveLog"
		ImGui.AddCheckbox(temp_revive_group, log_id, text("temp_revive_log"), nil, false)
		ImGui.AddCallback(log_id, ImGuiCallback.Render, function()
			local ok, trv = pcall(require, "Qing_Remaster_scripts.others.temporary_revive_manager")
			ImGui.UpdateData(log_id, ImGuiData.Value, ok and trv and trv.debug_log == true)
		end)
		ImGui.AddCallback(log_id, ImGuiCallback.Edited, function(value)
			local ok, trv = pcall(require, "Qing_Remaster_scripts.others.temporary_revive_manager")
			if ok and trv then trv.debug_log = value == true end
		end)
		local status_id = "QingRemasterOptions_TempReviveStatus"
		imgui_layout.add_wrapped_text(temp_revive_group, status_id, text("temp_revive_status"))
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local ok, trv = pcall(require, "Qing_Remaster_scripts.others.temporary_revive_manager")
			local body = (ok and trv and trv.get_debug_text and trv.get_debug_text()) or text("temp_revive_status")
			imgui_layout.update_text(status_id, body)
		end)
		ImGui.AddButton(temp_revive_group, "QingRemasterOptions_TempReviveClear", text("temp_revive_clear"), function()
			local ok, trv = pcall(require, "Qing_Remaster_scripts.others.temporary_revive_manager")
			if ok and trv and trv.clear_spent_for_player then
				trv.clear_spent_for_player(Isaac.GetPlayer(0))
				local ok2, imi = pcall(require, "Qing_Remaster_scripts.callbacks.imitate_item_holder")
				if ok2 and imi and imi.Evaluate_Imitate_Items then
					imi.Evaluate_Imitate_Items(Isaac.GetPlayer(0))
				end
			end
		end)
	end
	local special_dest_group = start_mod("system_special_destinations", DEBUG_PAGE.systems, language_key() == "zh" and "特殊目的地" or "Special Destinations", "QingRemasterOptions_GroupSpecialDest", {path = {"Special Destinations"}, kind = "tool"})
	do
		add_text(special_dest_group, language_key() == "zh" and "Registry 调试（room_index / portal_type 仅此页可见）" or "Registry debug (room_index / portal_type only here)")
		local status_id = "QingRemasterOptions_SpecialDestStatus"
		imgui_layout.add_wrapped_text(special_dest_group, status_id, "")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local ok, reg = pcall(require, "Qing_Remaster_scripts.others.Special_Destination_holder")
			local body = (ok and reg and reg.get_debug_text and reg.get_debug_text()) or "load failed"
			imgui_layout.update_text(status_id, body)
		end)
		local rare_keys = {"error_room", "boss_rush", "black_market", "mega_satan"}
		for i = 1, #rare_keys do
			local key = rare_keys[i]
			ImGui.AddButton(special_dest_group, "QingRemasterOptions_SpecialDestSpawn_"..key, "Spawn "..key, function()
				local ok, reg = pcall(require, "Qing_Remaster_scripts.others.Special_Destination_holder")
				if ok and reg and reg.debug_force_portal then
					reg.debug_force_portal(key)
				end
			end)
		end
		ImGui.AddButton(special_dest_group, "QingRemasterOptions_SpecialDestRareRoll", "Test Rare Roll x1000", function()
			local ok, reg = pcall(require, "Qing_Remaster_scripts.others.Special_Destination_holder")
			if not (ok and reg and reg.debug_test_rare_roll) then return end
			local counts = reg.debug_test_rare_roll(1000, Game():GetFrameCount())
			local parts = {}
			for k, v in pairs(counts) do
				parts[#parts + 1] = string.format("%s=%d", tostring(k), v)
			end
			table.sort(parts)
			push_notice(table.concat(parts, "  "))
		end)
	end
	local consistance_lab_group = start_mod("audit_consistance_test_lab", DEBUG_PAGE.tests, "Consistance Test Lab", "QingRemasterOptions_GroupConsistanceTestLab", {path = {"Consistance Test Lab"}, kind = "test"})
	do
		add_text(consistance_lab_group, "Unique：Native ESSM ≠ Generation。Consumer：GenerationAuditHolder（Empress/Live）。Appear2 已拆除。")
		local lab_core_id = "QingRemasterOptions_ConsistanceLabCoreStatus"
		imgui_layout.add_wrapped_text(consistance_lab_group, lab_core_id, "Core Status")
		ImGui.AddCallback(lab_core_id, ImGuiCallback.Render, function()
			local ok, lab = pcall(require, "Qing_Remaster_scripts.debug.consistance_test_lab")
			local ok2, lt = pcall(require, "Qing_Remaster_scripts.others.Entity_lifetime_holder")
			local body = (ok and lab and lab.get_status_text and lab.get_status_text()) or "无法加载 consistance_test_lab"
			if ok2 and lt and lt.get_debug_snapshot then
				local s = lt.get_debug_snapshot()
				body = string.format("[ESSM available=%s errors=%d]\n", tostring(s.available), tonumber(s.api_errors) or 0) .. body
			end
			imgui_layout.update_text(lab_core_id, body)
		end)
		local consumer_audit_id = "QingRemasterOptions_UniqueConsumerAudit"
		imgui_layout.add_wrapped_text(consistance_lab_group, consumer_audit_id, "Unique Consumer Audit")
		ImGui.AddCallback(consumer_audit_id, ImGuiCallback.Render, function()
			local ok_u, unique = pcall(require, "Qing_Remaster_scripts.others.Unique_holder")
			local ok_a, audit = pcall(require, "Qing_Remaster_scripts.others.Generation_audit_holder")
			local ok_p, perhaps = pcall(require, "Qing_Remaster_scripts.items.Item_Perhaps_Chosen")
			local lines = {}
			if ok_u and unique and unique.get_shadow_snapshot then
				local s = unique.get_shadow_snapshot()
				lines[#lines + 1] = string.format(
					"Unique gen: NEW=%d SAME=%d RESTORED=%d EMPTY=%d unresolved=%d",
					s.gen_new or 0, s.gen_same or 0, s.gen_restored or 0, s.gen_empty or 0, s.unresolved or 0
				)
			end
			if ok_a and audit and audit.get_debug_snapshot then
				local snap = audit.get_debug_snapshot()
				local e = snap.empress or {}
				local l = snap.live_broadcast or {}
				lines[#lines + 1] = string.format(
					"Empress: epoch=%s seen=%s first=%s dup=%s d6=%s cycle=%s restore=%s",
					tostring(e.epoch), tostring(e.seen_count), tostring(e.first_hits),
					tostring(e.duplicate_blocks), tostring(e.d6_new_hits), tostring(e.cycle_blocks), tostring(e.restore_blocks)
				)
				lines[#lines + 1] = string.format(
					"Live: epoch=%s active=%s seen=%s first=%s dup=%s d6=%s cycle=%s restore=%s",
					tostring(l.epoch), tostring(l.active), tostring(l.seen_count), tostring(l.first_hits),
					tostring(l.duplicate_blocks), tostring(l.d6_new_hits), tostring(l.cycle_blocks), tostring(l.restore_blocks)
				)
				local tr = snap.trace or {}
				if #tr > 0 then
					local last = tr[#tr]
					lines[#lines + 1] = string.format(
						"Trace[%d]: owner=%s epoch=%s gen=%s event=%s src=%s",
						#tr, tostring(last.owner), tostring(last.epoch), tostring(last.generation),
						tostring(last.event), tostring(last.source)
					)
				end
			end
			if ok_p and perhaps and perhaps.debug_audit then
				local d = perhaps.debug_audit
				lines[#lines + 1] = string.format(
					"Perhaps: new_host=%s same_block=%s restore_block=%s",
					tostring(d.new_host_hits), tostring(d.same_generation_blocks), tostring(d.restore_blocks)
				)
			end
			imgui_layout.update_text(consumer_audit_id, #lines > 0 and table.concat(lines, "\n") or "Consumer audit unavailable")
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabMorphReg", "Run Morph Regression", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").start_morph_regression()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabFamily", "Run Family Regression", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").start_family_regression()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabEssm", "Run ESSM Lifetime Matrix", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").start_essm_matrix()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabUnique", "Run Unique Shadow Matrix", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").start_unique_shadow()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabNative", "Run Consistance Native Guard", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").start_native_guard()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabIntegration", "Run Integration Suite", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").start_integration()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabAllSafe", "Run All Safe Tests", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").start_all_safe()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabCrossRoom", "Run Cross-room Tests", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").start_cross_room()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabCrossFloor", "Run Cross-floor Tests", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").start_cross_floor()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabPrepareSC", "Prepare Save/Continue Test", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").prepare_save_continue()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabCheckSC", "Check Save/Continue Result", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").check_save_continue()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabSemantics", "Run Morph Semantics Matrix", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").start_semantics()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabEngine", "Run Morph Semantics Regression", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").start_engine_regression()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabEmergency", "Emergency Cleanup", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").emergency_cleanup()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabCopy", "Copy Report to Clipboard", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").copy_report_to_clipboard()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabExport", "Export Report to File", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").export_report_to_file()
		end)
		ImGui.AddButton(consistance_lab_group, "QingRemasterOptions_ConsistanceLabClearReport", "Clear Report History", function()
			require("Qing_Remaster_scripts.debug.consistance_test_lab").clear_report_history(true)
		end)
		local lab_export_id = "QingRemasterOptions_ConsistanceLabExportStatus"
		imgui_layout.add_wrapped_text(consistance_lab_group, lab_export_id, "尚未导出")
		ImGui.AddCallback(lab_export_id, ImGuiCallback.Render, function()
			local ok, lab = pcall(require, "Qing_Remaster_scripts.debug.consistance_test_lab")
			local body = (ok and lab and lab.get_export_status_text and lab.get_export_status_text()) or ""
			imgui_layout.update_text(lab_export_id, body)
		end)
	end
	local consumer_reg_group = start_mod("audit_unique_consumer_regression", DEBUG_PAGE.tests, "Unique Consumer Regression", "QingRemasterOptions_GroupUniqueConsumerReg", {path = {"Unique Consumer Regression"}, kind = "test"})
	do
		add_text(consumer_reg_group, "CR-1 优先 Manual：Prepare -> 正常出房停一下 -> 回房 -> Check。Auto 仅对照。CR-2～7 等 CR-1 可信后再跑。点按钮后请取消暂停。")
		local cr_status_id = "QingRemasterOptions_UniqueConsumerRegStatus"
		imgui_layout.add_wrapped_text(consumer_reg_group, cr_status_id, "Idle")
		ImGui.AddCallback(cr_status_id, ImGuiCallback.Render, function()
			local ok, lab = pcall(require, "Qing_Remaster_scripts.debug.unique_consumer_regression_lab")
			local body = (ok and lab and lab.get_status_text and lab.get_status_text()) or "无法加载 unique_consumer_regression_lab"
			imgui_layout.update_text(cr_status_id, body)
		end)
		ImGui.AddButton(consumer_reg_group, "QingRemasterOptions_UCR_PrepCR1", "Prepare CR-1 Empress Room Return", function()
			require("Qing_Remaster_scripts.debug.unique_consumer_regression_lab").prepare_cr1()
		end)
		ImGui.AddButton(consumer_reg_group, "QingRemasterOptions_UCR_CheckCR1", "Check CR-1 Empress Room Return", function()
			require("Qing_Remaster_scripts.debug.unique_consumer_regression_lab").check_cr1()
		end)
		ImGui.AddButton(consumer_reg_group, "QingRemasterOptions_UCR_CR1", "Run CR-1 Auto (non-authoritative)", function()
			require("Qing_Remaster_scripts.debug.unique_consumer_regression_lab").run_cr1()
		end)
		ImGui.AddButton(consumer_reg_group, "QingRemasterOptions_UCR_CR2", "Run CR-2 Empress D6", function()
			require("Qing_Remaster_scripts.debug.unique_consumer_regression_lab").run_cr2()
		end)
		ImGui.AddButton(consumer_reg_group, "QingRemasterOptions_UCR_CR3", "Run CR-3 Empress Touched->D6", function()
			require("Qing_Remaster_scripts.debug.unique_consumer_regression_lab").run_cr3()
		end)
		ImGui.AddButton(consumer_reg_group, "QingRemasterOptions_UCR_CR4", "Run CR-4 Live Room Return", function()
			require("Qing_Remaster_scripts.debug.unique_consumer_regression_lab").run_cr4()
		end)
		ImGui.AddButton(consumer_reg_group, "QingRemasterOptions_UCR_CR5", "Run CR-5 Live D6", function()
			require("Qing_Remaster_scripts.debug.unique_consumer_regression_lab").run_cr5()
		end)
		ImGui.AddButton(consumer_reg_group, "QingRemasterOptions_UCR_CR6", "Run CR-6 Fool / Hermit", function()
			require("Qing_Remaster_scripts.debug.unique_consumer_regression_lab").run_cr6()
		end)
		ImGui.AddButton(consumer_reg_group, "QingRemasterOptions_UCR_CR7", "Run CR-7 Perhaps", function()
			require("Qing_Remaster_scripts.debug.unique_consumer_regression_lab").run_cr7()
		end)
		ImGui.AddButton(consumer_reg_group, "QingRemasterOptions_UCR_Epoch", "Run Epoch Smoke", function()
			require("Qing_Remaster_scripts.debug.unique_consumer_regression_lab").run_epoch_smoke()
		end)
		ImGui.AddButton(consumer_reg_group, "QingRemasterOptions_UCR_Copy", "Copy Consumer Report", function()
			require("Qing_Remaster_scripts.debug.unique_consumer_regression_lab").copy_report()
		end)
		ImGui.AddButton(consumer_reg_group, "QingRemasterOptions_UCR_Reset", "Reset Consumer Regression", function()
			require("Qing_Remaster_scripts.debug.unique_consumer_regression_lab").reset_tests()
		end)
	end
	local resolve_reg_group = start_mod("audit_unique_resolve_regression", DEBUG_PAGE.tests, "Unique Resolve Regression", "QingRemasterOptions_GroupUniqueResolveReg", {path = {"Unique Resolve Regression"}, kind = "test"})
	do
		add_text(resolve_reg_group, "UR 验证 resolve_generation。先跑 UR-1/UR-4/UR-5；UR-2 Manual Prepare->出房回房->Check。通过后再跑 CR-1。")
		local ur_status_id = "QingRemasterOptions_UniqueResolveRegStatus"
		imgui_layout.add_wrapped_text(resolve_reg_group, ur_status_id, "Idle")
		ImGui.AddCallback(ur_status_id, ImGuiCallback.Render, function()
			local ok, lab = pcall(require, "Qing_Remaster_scripts.debug.unique_resolve_regression_lab")
			local body = (ok and lab and lab.get_status_text and lab.get_status_text()) or "无法加载 unique_resolve_regression_lab"
			imgui_layout.update_text(ur_status_id, body)
		end)
		ImGui.AddButton(resolve_reg_group, "QingRemasterOptions_UR1", "Run UR-1 New Spawn Resolve", function()
			require("Qing_Remaster_scripts.debug.unique_resolve_regression_lab").run_ur1()
		end)
		ImGui.AddButton(resolve_reg_group, "QingRemasterOptions_UR2Prep", "Prepare UR-2 Room Return", function()
			require("Qing_Remaster_scripts.debug.unique_resolve_regression_lab").prepare_ur2()
		end)
		ImGui.AddButton(resolve_reg_group, "QingRemasterOptions_UR2Check", "Check UR-2 Room Return", function()
			require("Qing_Remaster_scripts.debug.unique_resolve_regression_lab").check_ur2()
		end)
		ImGui.AddButton(resolve_reg_group, "QingRemasterOptions_UR4", "Run UR-4 Cycle Same Id", function()
			require("Qing_Remaster_scripts.debug.unique_resolve_regression_lab").run_ur4()
		end)
		ImGui.AddButton(resolve_reg_group, "QingRemasterOptions_UR5", "Run UR-5 D6 New Id", function()
			require("Qing_Remaster_scripts.debug.unique_resolve_regression_lab").run_ur5()
		end)
		ImGui.AddButton(resolve_reg_group, "QingRemasterOptions_UR_Copy", "Copy Resolve Report", function()
			require("Qing_Remaster_scripts.debug.unique_resolve_regression_lab").copy_report()
		end)
		ImGui.AddButton(resolve_reg_group, "QingRemasterOptions_UR_Reset", "Reset Resolve Regression", function()
			require("Qing_Remaster_scripts.debug.unique_resolve_regression_lab").reset_tests()
		end)
	end
	local fresh_reg_group = start_mod("audit_unique_fresh_generation", DEBUG_PAGE.tests, "Unique Fresh Generation", "QingRemasterOptions_GroupUniqueFreshReg", {path = {"Unique Fresh Generation"}, kind = "test"})
	do
		add_text(fresh_reg_group, "FR 验证 is_fresh_generation / birth_room_epoch。FR-2/FR-8 需 Manual 出房回房。")
		local fr_status_id = "QingRemasterOptions_UniqueFreshRegStatus"
		imgui_layout.add_wrapped_text(fresh_reg_group, fr_status_id, "Idle")
		ImGui.AddCallback(fr_status_id, ImGuiCallback.Render, function()
			local ok, lab = pcall(require, "Qing_Remaster_scripts.debug.unique_fresh_generation_lab")
			local body = (ok and lab and lab.get_status_text and lab.get_status_text()) or "无法加载 unique_fresh_generation_lab"
			imgui_layout.update_text(fr_status_id, body)
		end)
		ImGui.AddButton(fresh_reg_group, "QingRemasterOptions_FR1", "Run FR-1 New Spawn", function()
			require("Qing_Remaster_scripts.debug.unique_fresh_generation_lab").run_fr1()
		end)
		ImGui.AddButton(fresh_reg_group, "QingRemasterOptions_FR2Prep", "Prepare FR-2 Room Return", function()
			require("Qing_Remaster_scripts.debug.unique_fresh_generation_lab").prepare_fr2()
		end)
		ImGui.AddButton(fresh_reg_group, "QingRemasterOptions_FR2Check", "Check FR-2", function()
			require("Qing_Remaster_scripts.debug.unique_fresh_generation_lab").check_fr2()
		end)
		ImGui.AddButton(fresh_reg_group, "QingRemasterOptions_FR3", "Run FR-3 Cycle", function()
			require("Qing_Remaster_scripts.debug.unique_fresh_generation_lab").run_fr3()
		end)
		ImGui.AddButton(fresh_reg_group, "QingRemasterOptions_FR4", "Run FR-4 D6", function()
			require("Qing_Remaster_scripts.debug.unique_fresh_generation_lab").run_fr4()
		end)
		ImGui.AddButton(fresh_reg_group, "QingRemasterOptions_FR5", "Run FR-5 Same-Seed Morph", function()
			require("Qing_Remaster_scripts.debug.unique_fresh_generation_lab").run_fr5()
		end)
		ImGui.AddButton(fresh_reg_group, "QingRemasterOptions_FR6", "Run FR-6 Seed Morph", function()
			require("Qing_Remaster_scripts.debug.unique_fresh_generation_lab").run_fr6()
		end)
		ImGui.AddButton(fresh_reg_group, "QingRemasterOptions_FR7", "Run FR-7 Delayed", function()
			require("Qing_Remaster_scripts.debug.unique_fresh_generation_lab").run_fr7()
		end)
		ImGui.AddButton(fresh_reg_group, "QingRemasterOptions_FR8Prep", "Prepare FR-8 Restored", function()
			require("Qing_Remaster_scripts.debug.unique_fresh_generation_lab").prepare_fr8()
		end)
		ImGui.AddButton(fresh_reg_group, "QingRemasterOptions_FR8Run", "Run FR-8 Delayed", function()
			require("Qing_Remaster_scripts.debug.unique_fresh_generation_lab").run_fr8_delayed()
		end)
		ImGui.AddButton(fresh_reg_group, "QingRemasterOptions_FR_Copy", "Copy Fresh Report", function()
			require("Qing_Remaster_scripts.debug.unique_fresh_generation_lab").copy_report()
		end)
		ImGui.AddButton(fresh_reg_group, "QingRemasterOptions_FR_Reset", "Reset Fresh Regression", function()
			require("Qing_Remaster_scripts.debug.unique_fresh_generation_lab").reset_tests()
		end)
	end
	local pe_reg_group = start_mod("audit_pedestal_encounter_regression", DEBUG_PAGE.tests, "Pedestal Encounter Regression", "QingRemasterOptions_GroupPedestalEncounterReg", {path = {"Pedestal Encounter Regression"}, kind = "test"})
	do
		add_text(pe_reg_group, "EN=普通 Encounter；DC=死亡证明陈列。DC-1/DC-3 需在 Death Certificate 维度。")
		local pe_status_id = "QingRemasterOptions_PedestalEncounterRegStatus"
		imgui_layout.add_wrapped_text(pe_reg_group, pe_status_id, "Idle")
		ImGui.AddCallback(pe_status_id, ImGuiCallback.Render, function()
			local ok, lab = pcall(require, "Qing_Remaster_scripts.debug.pedestal_encounter_regression_lab")
			local body = (ok and lab and lab.get_status_text and lab.get_status_text()) or "无法加载 pedestal_encounter_regression_lab"
			imgui_layout.update_text(pe_status_id, body)
		end)
		ImGui.AddButton(pe_reg_group, "QingRemasterOptions_EN1", "Run EN-1 Natural", function()
			require("Qing_Remaster_scripts.debug.pedestal_encounter_regression_lab").run_en1()
		end)
		ImGui.AddButton(pe_reg_group, "QingRemasterOptions_EN2", "Run EN-2 Cycle", function()
			require("Qing_Remaster_scripts.debug.pedestal_encounter_regression_lab").run_en2()
		end)
		ImGui.AddButton(pe_reg_group, "QingRemasterOptions_EN3", "Run EN-3 D6", function()
			require("Qing_Remaster_scripts.debug.pedestal_encounter_regression_lab").run_en3()
		end)
		ImGui.AddButton(pe_reg_group, "QingRemasterOptions_EN4", "Run EN-4 Residue Mark", function()
			require("Qing_Remaster_scripts.debug.pedestal_encounter_regression_lab").run_en4()
		end)
		ImGui.AddButton(pe_reg_group, "QingRemasterOptions_DC1", "Check DC-1 Display Room", function()
			require("Qing_Remaster_scripts.debug.pedestal_encounter_regression_lab").check_dc1()
		end)
		ImGui.AddButton(pe_reg_group, "QingRemasterOptions_DC3", "Run DC-3 Normal In DC", function()
			require("Qing_Remaster_scripts.debug.pedestal_encounter_regression_lab").run_dc3()
		end)
		ImGui.AddButton(pe_reg_group, "QingRemasterOptions_DC4", "Run DC-4 idx1 Outside DC", function()
			require("Qing_Remaster_scripts.debug.pedestal_encounter_regression_lab").run_dc4()
		end)
		ImGui.AddButton(pe_reg_group, "QingRemasterOptions_PE_Copy", "Copy Encounter Report", function()
			require("Qing_Remaster_scripts.debug.pedestal_encounter_regression_lab").copy_report()
		end)
		ImGui.AddButton(pe_reg_group, "QingRemasterOptions_PE_Reset", "Reset Encounter Regression", function()
			require("Qing_Remaster_scripts.debug.pedestal_encounter_regression_lab").reset_tests()
		end)
	end
	local morph_txn_reg_group = start_mod(
		"audit_pickup_morph_txn_regression",
		DEBUG_PAGE.tests,
		"Morph Transaction Regression",
		"QingRemasterOptions_GroupMorphTxnReg",
		{path = {"Morph Transaction Regression"}, kind = "test"}
	)
	do
		add_text(morph_txn_reg_group, "M1–M9：PRE→POST pairing（含 non-collectible / cross-variant）。Run All 即可。")
		local mt_status_id = "QingRemasterOptions_MorphTxnRegStatus"
		imgui_layout.add_wrapped_text(morph_txn_reg_group, mt_status_id, "Idle")
		ImGui.AddCallback(mt_status_id, ImGuiCallback.Render, function()
			local ok, lab = pcall(require, "Qing_Remaster_scripts.debug.pickup_morph_txn_regression_lab")
			local body = (ok and lab and lab.get_status_text and lab.get_status_text()) or "无法加载 pickup_morph_txn_regression_lab"
			imgui_layout.update_text(mt_status_id, body)
		end)
		ImGui.AddButton(morph_txn_reg_group, "QingRemasterOptions_MorphTxnRunAll", "Run All M1–M9", function()
			require("Qing_Remaster_scripts.debug.pickup_morph_txn_regression_lab").run_all()
		end)
		ImGui.AddButton(morph_txn_reg_group, "QingRemasterOptions_MorphTxnCopy", "Copy Morph Txn Report", function()
			require("Qing_Remaster_scripts.debug.pickup_morph_txn_regression_lab").copy_report()
		end)
		ImGui.AddButton(morph_txn_reg_group, "QingRemasterOptions_MorphTxnReset", "Reset Morph Txn Regression", function()
			require("Qing_Remaster_scripts.debug.pickup_morph_txn_regression_lab").reset_tests()
		end)
	end
	local price_ref_reg_group = start_mod(
		"audit_price_refresh_regression",
		DEBUG_PAGE.tests,
		"Price Refresh Regression",
		"QingRemasterOptions_GroupPriceRefreshReg",
		{path = {"Price Refresh Regression"}, kind = "test"}
	)
	do
		add_text(price_ref_reg_group, "PR-1～PR-6：FINALIZE 后下一帧 native Price=Price visual commit 状态机。")
		local pr_status_id = "QingRemasterOptions_PriceRefreshRegStatus"
		imgui_layout.add_wrapped_text(price_ref_reg_group, pr_status_id, "Idle")
		ImGui.AddCallback(pr_status_id, ImGuiCallback.Render, function()
			local ok, lab = pcall(require, "Qing_Remaster_scripts.debug.price_refresh_regression_lab")
			local body = (ok and lab and lab.get_status_text and lab.get_status_text()) or "无法加载 price_refresh_regression_lab"
			imgui_layout.update_text(pr_status_id, body)
		end)
		ImGui.AddButton(price_ref_reg_group, "QingRemasterOptions_PriceRefreshRunAll", "Run All PR-1～PR-6", function()
			require("Qing_Remaster_scripts.debug.price_refresh_regression_lab").run_all()
		end)
		ImGui.AddButton(price_ref_reg_group, "QingRemasterOptions_PriceRefreshCopy", "Copy Price Refresh Report", function()
			require("Qing_Remaster_scripts.debug.price_refresh_regression_lab").copy_report()
		end)
		ImGui.AddButton(price_ref_reg_group, "QingRemasterOptions_PriceRefreshReset", "Reset Price Refresh Regression", function()
			require("Qing_Remaster_scripts.debug.price_refresh_regression_lab").reset_tests()
		end)
	end
		local charon_group = start_mod("item_charon", DEBUG_PAGE.items, text("group_charon_tide"), "QingRemasterOptions_GroupCharonTide", {
		path = {"Charon"}, kind = "tool",
		footer = {
			restore_label = text("restore_item_defaults"),
			restore = function()
		local defaults={
			CharonSpawnInterval=15,
			CharonParticleLifetime=120,
			CharonFadeFrames=20,
			CharonForegroundRate=0.2,
			CharonRowsPerAnchor=1,
			CharonRoomPrefillRatio=0.5,
			CharonRoomFadeFrames=15,
			CharonForceSeijaEnhancement=false,
			CharonSeijaSpeedMultiplier=4,
			CharonPickupProtectRadius=120,
			CharonSettingsVersion=4,
		}
		for key,value in pairs(defaults) do item.set_value({"QingRemasterOptions","Debug",key},value) end
	end,
		},
	})
	add_drag_float(charon_group, "QingRemasterOptions_CharonSpawnInterval", text("charon_spawn_interval"), {"QingRemasterOptions", "Debug", "CharonSpawnInterval"}, text("charon_spawn_interval_help"), 1, 1, 120, "%.0f f")
	add_drag_float(charon_group, "QingRemasterOptions_CharonParticleLifetime", text("charon_particle_lifetime"), {"QingRemasterOptions", "Debug", "CharonParticleLifetime"}, text("charon_particle_lifetime_help"), 1, 10, 600, "%.0f f")
	add_drag_float(charon_group, "QingRemasterOptions_CharonFadeFrames", text("charon_fade_frames"), {"QingRemasterOptions", "Debug", "CharonFadeFrames"}, text("charon_fade_frames_help"), 1, 1, 120, "%.0f f")
	add_drag_float(charon_group, "QingRemasterOptions_CharonForegroundRate", text("charon_foreground_rate"), {"QingRemasterOptions", "Debug", "CharonForegroundRate"}, text("charon_foreground_rate_help"), 0.01, 0, 1, "%.2f")
	add_drag_float(charon_group, "QingRemasterOptions_CharonRowsPerAnchor", text("charon_rows_per_anchor"), {"QingRemasterOptions", "Debug", "CharonRowsPerAnchor"}, text("charon_rows_per_anchor_help"), 1, 1, 8, "%.0f")
	add_drag_float(charon_group, "QingRemasterOptions_CharonRoomPrefillRatio", text("charon_room_prefill"), {"QingRemasterOptions", "Debug", "CharonRoomPrefillRatio"}, text("charon_room_prefill_help"), 0.05, 0, 1, "%.2f")
	add_drag_float(charon_group, "QingRemasterOptions_CharonRoomFadeFrames", text("charon_room_fade"), {"QingRemasterOptions", "Debug", "CharonRoomFadeFrames"}, text("charon_room_fade_help"), 1, 0, 120, "%.0f f")
	add_checkbox(charon_group, "QingRemasterOptions_CharonForceSeijaEnhancement", text("charon_seija_enabled"), {"QingRemasterOptions", "Debug", "CharonForceSeijaEnhancement"}, text("charon_seija_enabled_help"))
	add_drag_float(charon_group, "QingRemasterOptions_CharonSeijaSpeedMultiplier", text("charon_seija_speed"), {"QingRemasterOptions", "Debug", "CharonSeijaSpeedMultiplier"}, text("charon_seija_speed_help"), 0.25, 1, 20, "%.2fx")
	add_drag_float(charon_group, "QingRemasterOptions_CharonPickupProtectRadius", text("charon_pickup_radius"), {"QingRemasterOptions", "Debug", "CharonPickupProtectRadius"}, text("charon_pickup_radius_help"), 1, 0, 240, "%.0f px")
		add_remaster_flip_group(items_tab)

	add_live_broadcast_group(items_tab)

	add_ritual_sting_group(items_tab)

	do
		local orb_group = start_mod("flight_orbital", DEBUG_PAGE.items, "Flight Orbital", "QingRemasterOptions_GroupFlightOrbital", {parent = bp_compat, path = {"Blueprint", "Compatibility", "Orbital"}, kind = "tool"})
		add_text(orb_group, "布局按 Flight+layout_ring 全局均分相位；距离=层表/原实体椭圆×倍率。视觉高度用 render bias，勿改世界半径。批次1：10/57/112/128/172/279/364/508/542。")
		local function orb_mod()
			local ok, mod = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Orbital_holder")
			if ok then return mod end
			return nil
		end
		local function add_orb_float(id, label, key, default, speed, min_v, max_v, fmt)
			local eid = "QingRemasterOptions_FlightOrbital_" .. id
			ImGui.AddDragFloat(orb_group, eid, label, function(value)
				local mod = orb_mod()
				if mod then mod.debug[key] = tonumber(value) or default end
			end, default, speed or 0.01, min_v or 0, max_v or 1, fmt or "%.2f")
			ImGui.AddCallback(eid, ImGuiCallback.Render, function()
				local mod = orb_mod()
				local v = (mod and tonumber(mod.debug[key])) or default
				ImGui.UpdateData(eid, ImGuiData.Value, v)
			end)
		end
		add_orb_float("ContactMul", "普通 contact 基础倍率", "contact_mul", 0.45, 0.01, 0.05, 1.00, "%.2f")
		add_orb_float("HighMul", "高伤 contact 基础倍率", "high_contact_mul", 0.30, 0.01, 0.05, 1.00, "%.2f")
		add_orb_float("Chase", "主动追敌折扣", "chase_discount", 0.65, 0.01, 0.10, 1.00, "%.2f")
		add_orb_float("HitInterval", "命中间隔(逻辑帧)", "hit_interval", 10, 1, 1, 30, "%.0f")
		add_orb_float("DistMul", "全局距离倍率", "orbit_dist_mul", 1.0, 0.05, 0.25, 3.0, "%.2f")
		add_orb_float("MulMeat", "肉块距离倍率", "orbit_mul_meat", 1.0, 0.05, 0.25, 3.0, "%.2f")
		add_orb_float("MulBand", "绷带距离倍率", "orbit_mul_bandage", 1.0, 0.05, 0.25, 3.0, "%.2f")
		add_orb_float("MulBud", "好朋友距离倍率", "orbit_mul_best_bud", 1.0, 0.05, 0.25, 3.0, "%.2f")
		add_orb_float("MulLep", "麻风距离倍率", "orbit_mul_leprosy", 1.0, 0.05, 0.25, 3.0, "%.2f")
		add_orb_float("LayerMeat", "合成肉块 OrbitLayer", "orbit_layer_meat", 0, 1, 0, 8, "%.0f")
		add_orb_float("LayerBand", "合成绷带 OrbitLayer", "orbit_layer_bandage", 0, 1, 0, 8, "%.0f")
		add_orb_float("LayerBud", "合成好朋友 OrbitLayer", "orbit_layer_best_bud", 1, 1, 0, 8, "%.0f")
		add_orb_float("LayerLep", "合成麻风 OrbitLayer", "orbit_layer_leprosy", 0, 1, 0, 8, "%.0f")
		add_orb_float("RenderYBias", "视觉高度 bias(+下)", "orbital_render_y_bias", 0, 0.5, -40, 40, "%.1f")
		add_orb_float("Spring", "弹簧", "spring", 0.28, 0.01, 0.05, 1.00, "%.2f")
		add_orb_float("Damping", "阻尼", "damping", 0.72, 0.01, 0.10, 0.98, "%.2f")
		add_orb_float("MaxSpd", "轨道最大速度", "orbit_max_speed", 16, 0.5, 4, 40, "%.1f")
		add_orb_float("GuardSpd", "守护天使转速倍率", "guardian_orbit_factor", 1.5, 0.05, 0.5, 3.0, "%.2f")
		add_orb_float("FanSpd", "大粉丝转速倍率", "big_fan_orbit_factor", 0.5, 0.05, 0.1, 1.5, "%.2f")
		add_orb_float("RazorBleed", "剃刀流血持续(帧)", "razor_bleed_frames", 150, 5, 30, 600, "%.0f")
		local ball_id = "QingRemasterOptions_FlightOrbital_BallBlocks"
		ImGui.AddCheckbox(orb_group, ball_id, "Ball blocks projectiles", nil, true)
		ImGui.AddCallback(ball_id, ImGuiCallback.Render, function()
			local mod = orb_mod()
			ImGui.UpdateData(ball_id, ImGuiData.Value, not mod or mod.debug.ball_blocks ~= false)
		end)
		ImGui.AddCallback(ball_id, ImGuiCallback.Edited, function(value)
			local mod = orb_mod()
			if mod then mod.debug.ball_blocks = value == true end
		end)
		local status_id = "QingRemasterOptions_FlightOrbital_Status"
		imgui_layout.add_wrapped_text(orb_group, status_id, "无 Flight orbital")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local mod = orb_mod()
			local body = (mod and mod.get_debug_status and mod.get_debug_status()) or "无 Flight orbital"
			imgui_layout.update_text(status_id, body)
		end)
		ImGui.AddButton(orb_group, "QingRemasterOptions_FlightOrbital_Restore", "恢复 Orbital 默认设置", function()
			local mod = orb_mod()
			if mod and mod.restore_debug_defaults then mod.restore_debug_defaults() end
		end)
	end
	-- Items continued (Remaster / Live / Ritual already registered above)
	add_death_sentence_group(items_tab)

	do
				local group = start_mod("item_pareidolia", DEBUG_PAGE.items, "妖心·盈月", "QingRemasterOptions_GroupPareidolia", {
			path = {"Pareidolia"}, kind = "tool",
			footer = {
				restore_label = text("restore_item_defaults"),
				restore = function()
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaPreview"}, false)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaDetailedBack"}, true)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaForceSpin"}, false)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaFxLiftStart"}, 36)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaFxLiftHover"}, 160)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaFxLiftMax"}, 260)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaFxScreenTopPct"}, 0.22)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaFxAscendFrames"}, 48)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaPhaseLift"}, 90)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaFloatRate"}, 0.11)
		end,
			},
		})
		add_text(group, "月亮眼调试：背景贴图 / 高度 / 飘移。正式：注视攒相->缩小升顶->停滞瞄准->光柱预兆->圣光。开睑默认全开。")
		-- 注意：不要再对同一 checkbox 挂第二份 Edited——会覆盖 add_checkbox 的 set_value，导致勾不上。
		-- moon.debug 由 Item_Pareidolia 每帧从 ModConfig 同步。
		add_checkbox(group, "QingRemasterOptions_PareidoliaPreview", "持有时预览月亮眼", {"QingRemasterOptions", "Debug", "PareidoliaPreview"}, "开启后在角色附近循环开合预览（与满月演出独立）。")
		add_checkbox(group, "QingRemasterOptions_PareidoliaDetailedBack", "背景用 0/0 阴影月面", {"QingRemasterOptions", "Debug", "PareidoliaDetailedBack"}, "关闭=128/0 纯色底；开启=0/0 带阴影格。默认开。")
		add_checkbox(group, "QingRemasterOptions_PareidoliaForceSpin", "预览强制旋转", {"QingRemasterOptions", "Debug", "PareidoliaForceSpin"}, "预览时慢速旋转整眼。")
		add_drag_float(group, "QingRemasterOptions_PareidoliaFxLiftHover", "满月偏好高度", {"QingRemasterOptions", "Debug", "PareidoliaFxLiftHover"}, "无房间信息时的回退高度。", 5, 40, 400, "%.0f")
		add_drag_float(group, "QingRemasterOptions_PareidoliaFxLiftMax", "满月高度硬顶", {"QingRemasterOptions", "Debug", "PareidoliaFxLiftMax"}, "抬升搜索上限；真正高度由屏高比例决定。", 5, 120, 480, "%.0f")
		add_drag_float(group, "QingRemasterOptions_PareidoliaFxScreenTopPct", "满月目标屏高比例", {"QingRemasterOptions", "Debug", "PareidoliaFxScreenTopPct"}, "目标屏幕 Y=屏高×此值，近似落在屏顶边界下方。默认 0.22；越小越高。", 0.01, 0.08, 0.40, "%.2f")
		add_drag_float(group, "QingRemasterOptions_PareidoliaFxLiftStart", "满月起始高度", {"QingRemasterOptions", "Debug", "PareidoliaFxLiftStart"}, "无进度月接续、强制满月时的升起起点。", 2, 0, 400, "%.0f")
		add_drag_float(group, "QingRemasterOptions_PareidoliaFxAscendFrames", "蓄力升飞帧数", {"QingRemasterOptions", "Debug", "PareidoliaFxAscendFrames"}, "charge：升飞+远小+光柱渐粗+目标渐白的总帧数。", 1, 8, 120, "%.0f f")
		add_drag_float(group, "QingRemasterOptions_PareidoliaPhaseLift", "进度月基准高度", {"QingRemasterOptions", "Debug", "PareidoliaPhaseLift"}, "0% 月相高度；满相约到 210，需明显升高。", 2, 10, 260, "%.0f")
		add_drag_float(group, "QingRemasterOptions_PareidoliaFloatRate", "追随速率", {"QingRemasterOptions", "Debug", "PareidoliaFloatRate"}, "预测追随的最大速度/加速度；切目标时会短暂加强。", 0.01, 0.02, 0.5, "%.2f")
		ImGui.AddButton(group, "QingRemasterOptions_PareidoliaForceResonance", "强制满月共鸣", function()
			if not Isaac.IsInGame or not Isaac.IsInGame() then
				push_notice(text("start_run_first"), error_notice_type())
				return
			end
			local ok, pare = pcall(require, "Qing_Remaster_scripts.items.Item_Pareidolia")
			if not ok or not pare or not pare.debug_force_resonance then
				push_notice("Pareidolia module unavailable", error_notice_type())
				return
			end
			local player = nil
			for i = 0, Game():GetNumPlayers() - 1 do
				local p = Game():GetPlayer(i)
				if p and p:HasCollectible(pare.entity) then
					player = p
					break
				end
			end
			player = player or Game():GetPlayer(0)
			pare.debug_force_resonance(player)
			push_notice("强制满月已触发")
		end)
			end

	add_book_of_voice_group(items_tab)

	add_book_of_thoth_group(items_tab)

	add_gospel_group(items_tab)

	add_dark_mysticism_group(items_tab)

	add_spectralsword_group(items_tab)

		local multiknife_group = start_mod("item_multiknife", DEBUG_PAGE.items, text("group_multiknife"), "QingRemasterOptions_GroupMultiknife", {
		path = {"Multiknife"}, kind = "tool",
		footer = {
			restore_label = text("restore_item_defaults"),
			restore = function()
		item.set_value({"QingRemasterOptions", "Debug", "MultiknifeHud7"}, 5.5)
		item.set_value({"QingRemasterOptions", "Debug", "MultiknifeHud8"}, 9.5)
		item.set_value({"QingRemasterOptions", "Debug", "MultiknifeHud9"}, 16.5)
		item.set_value({"QingRemasterOptions", "Debug", "MultiknifeHud10"}, 28.0)
		item.set_value({"QingRemasterOptions", "Debug", "MultiknifeHud11"}, 40.0)
		item.set_value({"QingRemasterOptions", "Debug", "MultiknifeHud12"}, 56.0)
		item.set_value({"QingRemasterOptions", "Debug", "MultiknifeLiftX"}, 0)
		item.set_value({"QingRemasterOptions", "Debug", "MultiknifeLiftY"}, -20)
	end,
		},
	})
	add_text(multiknife_group, text("multiknife_help"))
	add_drag_float(multiknife_group, "QingRemasterOptions_MultiknifeHud7", text("multiknife_hud7"), {"QingRemasterOptions", "Debug", "MultiknifeHud7"}, nil, 0.1, 0, 80, "%.2f")
	add_drag_float(multiknife_group, "QingRemasterOptions_MultiknifeHud8", text("multiknife_hud8"), {"QingRemasterOptions", "Debug", "MultiknifeHud8"}, nil, 0.1, 0, 80, "%.2f")
	add_drag_float(multiknife_group, "QingRemasterOptions_MultiknifeHud9", text("multiknife_hud9"), {"QingRemasterOptions", "Debug", "MultiknifeHud9"}, nil, 0.1, 0, 80, "%.2f")
	add_drag_float(multiknife_group, "QingRemasterOptions_MultiknifeHud10", text("multiknife_hud10"), {"QingRemasterOptions", "Debug", "MultiknifeHud10"}, nil, 0.1, 0, 80, "%.2f")
	add_drag_float(multiknife_group, "QingRemasterOptions_MultiknifeHud11", text("multiknife_hud11"), {"QingRemasterOptions", "Debug", "MultiknifeHud11"}, nil, 0.1, 0, 80, "%.2f")
	add_drag_float(multiknife_group, "QingRemasterOptions_MultiknifeHud12", text("multiknife_hud12"), {"QingRemasterOptions", "Debug", "MultiknifeHud12"}, nil, 0.1, 0, 80, "%.2f")
	add_drag_float(multiknife_group, "QingRemasterOptions_MultiknifeLiftX", text("multiknife_lift_x"), {"QingRemasterOptions", "Debug", "MultiknifeLiftX"}, text("multiknife_lift_help"), 0.25, -80, 80, "%.1f")
	add_drag_float(multiknife_group, "QingRemasterOptions_MultiknifeLiftY", text("multiknife_lift_y"), {"QingRemasterOptions", "Debug", "MultiknifeLiftY"}, text("multiknife_lift_help"), 0.25, -80, 80, "%.1f")

	add_pendulum_star_group(items_tab)
	add_my_hat_group(items_tab)
	add_field_group(items_tab)
	add_drama_group(items_tab)
	add_mental_group(items_tab)

	add_suture_needle_group(items_tab)

	add_zeiz_hub_group(characters_tab)

	add_regenesis_group(items_tab)

	add_bloody_map_group(items_tab)

	add_perhaps_chosen_group(items_tab)

	add_zero_presence_group(items_tab)

	add_glaze_crown_group(items_tab)

	add_abiogenesis_group(items_tab)

	add_tianyi_group(items_tab)

	add_ingestion_night_group(items_tab)

	add_golden_slot_group(items_tab)

	add_reserved_judgment_group(items_tab)

	add_diamond_group(items_tab)
	-- Data page: Permanent Data + Item Color Editor only (no empty shells)
	do
		local permanent_shell = start_mod("data_permanent", DEBUG_PAGE.data, text("tab_permanent_data"), "QingRemasterOptions_GroupPermanentDataShell", {path = {"Permanent Data"}, kind = "data", recent = true})
		local restricted_status_id = "QingRemasterOptions_RestrictedStatus"
		imgui_layout.add_plain_text(permanent_shell, restricted_status_id, "")
		ImGui.AddCallback(restricted_status_id, ImGuiCallback.Render, function()
			local unlocked = imgui_layout.can_use("restricted")
			local word = unlocked and text("debug_restricted_unlocked") or text("debug_restricted_locked_word")
			imgui_layout.update_text(restricted_status_id, string.format(text("debug_restricted_status"), word))
		end)
		add_checkbox(permanent_shell, "QingRemasterOptions_RestrictedUnlock", text("debug_restricted_unlock"), {"QingRemasterOptions", "Debug", "RestrictedUnlocked"}, text("debug_restricted_locked"))
		create_permanent_data_panel(permanent_shell)
		local color_shell = start_mod("data_item_colors", DEBUG_PAGE.data, text("tab_item_colors"), "QingRemasterOptions_GroupItemColorsShell", {path = {"Item Color Editor"}, kind = "data"})
		add_item_color_panel(color_shell)
	end

	-- Blueprint Data section: summary + navigate to Data (no duplicate editor)
	do
		add_text(bp_data, "Blueprint-related permanent data (channels, etc.) lives on the Data page.")
		imgui_layout.add_module_link(bp_data, "QingRemasterOptions_BlueprintGotoData", "data_permanent", language_key() == "zh" and "前往 Data" or "Go to Data")
	end

	-- Register unmarked item/character builders that create their own groups
	local function register_built(module_id, page, label, group_id, meta)
		meta = meta or {path = {label}, kind = "tool"}
		register_debug_module(module_id, page, label, group_id, meta)
		if meta.footer then
			set_module_footer(module_id, meta.footer)
		end
	end
	register_built("item_remaster", DEBUG_PAGE.items, text("group_remaster"), "QingRemasterOptions_GroupRemasterFlip", {path = {"Remaster"}, kind = "tool"})
	register_built("item_live_broadcast", DEBUG_PAGE.items, text("live_item"), "QingRemasterOptions_GroupLiveBroadcast", {path = {"Live Broadcast"}, kind = "tool"})
	register_built("item_ritual_sting", DEBUG_PAGE.items, text("group_ritual_sting"), "QingRemasterOptions_GroupRitualSting", {path = {"Ritual Sting"}, kind = "tool"})
	register_built("item_death_sentence", DEBUG_PAGE.items, text("group_death_sentence"), "QingRemasterOptions_GroupDeathSentence", {path = {"Death Sentence"}, kind = "tool"})
	register_built("item_book_of_voice", DEBUG_PAGE.items, text("group_book_of_voice"), "QingRemasterOptions_GroupBookOfVoice", {path = {"Book of Voice"}, kind = "tool"})
	register_built("item_book_of_thoth", DEBUG_PAGE.items, text("group_book_of_thoth"), "QingRemasterOptions_GroupBookOfThoth", {path = {"Book of Thoth"}, kind = "tool"})
	register_built("item_gospel", DEBUG_PAGE.items, text("group_gospel"), "QingRemasterOptions_GroupGospel", {path = {"Gospel"}, kind = "tool"})
	register_built("item_dark_mysticism", DEBUG_PAGE.items, text("group_dark_mysticism"), "QingRemasterOptions_GroupDarkMysticism", {path = {"Dark Mysticism"}, kind = "tool"})
	register_built("item_field", DEBUG_PAGE.items, "逆反力场", "QingRemasterOptions_GroupField", {path = {"Field"}, kind = "tool"})
	register_built("item_drama", DEBUG_PAGE.items, "悲欢之凶剧", "QingRemasterOptions_GroupDrama", {path = {"Drama"}, kind = "tool"})
	register_built("item_mental", DEBUG_PAGE.items, "精神失序", "QingRemasterOptions_GroupMental", {path = {"Mental"}, kind = "tool"})
	register_built("item_suture_needle", DEBUG_PAGE.items, text("group_suture_needle"), "QingRemasterOptions_GroupSutureNeedle", {path = {"Suture Needle"}, kind = "tool"})
	register_built("char_zeiz", DEBUG_PAGE.characters, "Zeiz Control Hub", "QingRemasterOptions_GroupZeizHub", {path = {"Zeiz"}, kind = "tool"})
	register_built("item_regenesis", DEBUG_PAGE.items, text("group_regenesis"), "QingRemasterOptions_GroupRegenesis", {path = {"Regenesis"}, kind = "tool"})
	register_built("item_bloody_map", DEBUG_PAGE.items, text("group_bloody_map"), "QingRemasterOptions_GroupBloodyMap", {path = {"Bloody Map"}, kind = "tool"})
	register_built("item_perhaps_chosen", DEBUG_PAGE.items, text("group_perhaps_chosen"), "QingRemasterOptions_GroupPerhapsChosen", {path = {"Perhaps Chosen"}, kind = "tool"})
	register_built("item_zero_presence", DEBUG_PAGE.items, text("group_zero_presence"), "QingRemasterOptions_GroupZeroPresence", {path = {"Zero Presence"}, kind = "tool"})
	register_built("item_glaze_crown", DEBUG_PAGE.items, text("group_glaze_crown"), "QingRemasterOptions_GroupGlazeCrown", {path = {"Glaze Crown"}, kind = "tool"})
	register_built("item_abiogenesis", DEBUG_PAGE.items, text("group_abiogenesis"), "QingRemasterOptions_GroupAbiogenesis", {path = {"Abiogenesis"}, kind = "tool"})
	register_built("item_tianyi", DEBUG_PAGE.items, text("group_tianyi"), "QingRemasterOptions_GroupTianYi", {path = {"Tianyi"}, kind = "tool"})
	register_built("item_ingestion_night", DEBUG_PAGE.items, text("group_ingestion_night"), "QingRemasterOptions_GroupIngestionNight", {path = {"Ingestion Night"}, kind = "tool"})
	register_built("item_golden_slot", DEBUG_PAGE.items, text("group_golden_slot"), "QingRemasterOptions_GroupGoldenSlot", {
		path = {"Golden Slot"}, kind = "tool",
		home = {enabled = true, controls = {"base_chance", "chance_per_loss", "max_chance"}},
		-- controls already registered in add_golden_slot_group; keep home flag for pinnable
	})
	register_built("item_reserved_judgment", DEBUG_PAGE.items, text("group_reserved_judgment"), "QingRemasterOptions_GroupReservedJudgment", {path = {"Reserved Judgment"}, kind = "tool"})
	register_built("item_diamond", DEBUG_PAGE.items, text("group_diamond"), "QingRemasterOptions_GroupDiamond", {path = {"Diamond"}, kind = "tool"})

	do
		local oblivion = require("Qing_Remaster_scripts.cards.Card_00_Oblivion")
		local common = require("Qing_Remaster_scripts.cards.oblivion_common")
		local group = start_mod("card_oblivion", DEBUG_PAGE.cards, "0 - 忘却", "QingRemasterOptions_GroupCardOblivion", {
			path = {"Cards", "Oblivion"},
			kind = "tool",
		})
		if group then
			local zh = language_key() == "zh"
			local status_id = "QingRemasterOptions_OblivionStatus"
			imgui_layout.add_plain_text(group, status_id, "")
			ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
				local snap = oblivion.debug_get_state()
				local override = oblivion.debug_get_overlay_frame_override()
				if not snap then
					imgui_layout.update_text(status_id, zh and "无玩家" or "No player")
					return
				end
				local pocket
				if snap.is_oblivion then
					pocket = zh and "CARD / 0-忘却" or "CARD / Oblivion"
				elseif snap.primary_card then
					pocket = "CARD / " .. tostring(snap.primary_card)
				else
					pocket = zh and "无主卡牌" or "No primary card"
				end
				local override_text = override == nil and (zh and "关闭" or "off") or tostring(override)
				imgui_layout.update_text(status_id, string.format(
					zh and "主 Pocket: %s\nProgress: %d / %d\nRatio: %.1f%%\nOverlay: %d → %d\nTransition: %.0f%%\nDesc stage: %d\nOverride: %s"
						or "Primary pocket: %s\nProgress: %d / %d\nRatio: %.1f%%\nOverlay: %d → %d\nTransition: %.0f%%\nDesc stage: %d\nOverride: %s",
					pocket,
					snap.progress or 0,
					common.FORGET_FRAMES,
					(snap.ratio or 0) * 100,
					snap.overlay_frame or 0,
					snap.overlay_next_frame or 0,
					(snap.overlay_blend or 0) * 100,
					snap.desc_stage or 0,
					override_text
				))
			end)

			add_text(group, zh and "实际进度" or "Live progress")
			local progress_id = "QingRemasterOptions_OblivionProgress"
			ImGui.AddDragFloat(group, progress_id, zh and "遗忘进度 %" or "Forget progress %", function(value)
				oblivion.debug_set_physical_ratio(nil, (tonumber(value) or 0) / 100)
			end, 0, 1, 0, 100, "%.1f%%")
			ImGui.AddCallback(progress_id, ImGuiCallback.Render, function()
				local snap = oblivion.debug_get_state()
				ImGui.UpdateData(progress_id, ImGuiData.Value, (snap and snap.ratio or 0) * 100)
			end)

			local freeze_id = "QingRemasterOptions_OblivionFreeze"
			ImGui.AddCheckbox(group, freeze_id, zh and "冻结自动推进" or "Freeze auto progress", nil, false)
			ImGui.AddCallback(freeze_id, ImGuiCallback.Render, function()
				ImGui.UpdateData(freeze_id, ImGuiData.Value, oblivion.debug_get_freeze_progress())
			end)
			ImGui.AddCallback(freeze_id, ImGuiCallback.Edited, function(value)
				oblivion.debug_set_freeze_progress(value == true)
			end)

			ImGui.AddButton(group, "QingRemasterOptions_OblivionReset", zh and "重置" or "Reset", function()
				oblivion.debug_reset_physical(nil)
			end)
			ImGui.AddElement(group, "", ImGuiElement.SameLine)
			ImGui.AddButton(group, "QingRemasterOptions_OblivionHalf", "50%", function()
				oblivion.debug_set_physical_ratio(nil, 0.5)
			end)
			ImGui.AddElement(group, "", ImGuiElement.SameLine)
			ImGui.AddButton(group, "QingRemasterOptions_OblivionComplete", zh and "立即完成" or "Complete now", function()
				oblivion.debug_complete_physical(nil)
			end)

			add_text(group, "Overlay Preview")
			ImGui.AddButton(group, "QingRemasterOptions_OblivionOverrideOff", zh and "关闭" or "Off", function()
				oblivion.debug_set_overlay_frame_override(nil)
			end)
			for n = 0, common.FORGET_OVERLAY_FRAMES - 1 do
				local frame = n
				if frame ~= 0 and frame ~= 8 then
					ImGui.AddElement(group, "", ImGuiElement.SameLine)
				end
				ImGui.AddButton(group, "QingRemasterOptions_OblivionFrame" .. frame, tostring(frame), function()
					oblivion.debug_set_overlay_frame_override(frame)
				end)
			end
		end
	end
	require("Qing_Remaster_scripts.debug.hud_layout_audit_ui").build(api)
end

return M

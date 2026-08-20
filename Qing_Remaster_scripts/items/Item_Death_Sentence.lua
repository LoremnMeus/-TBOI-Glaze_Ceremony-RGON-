local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local STAR = "="
local BELIAL_SIX = "6"
local DEFAULT_DEATH_WORD = "FINAL"

local item = {
	ToCall = {},
	pre_ToCall = {},
	entity = enums.Items.Death_Sentence,
	own_key = "Item_Death_Sentence_",
	panel = nil,
	suppress_open_until = -1,
	pending_reopen_until = nil,
	page_size = 8,
	item_names = nil,
	near_miss_limit = 3,
	death_word = DEFAULT_DEATH_WORD,
	death_ready_frames = 10,
	hand_wait = 4,
	rise_frames = 16,
	hover_frames = 12,
	to_orbit_frames = 18,
	gather_frames = 22,
	hold_frames = 28,
	orbit_lerp = 0.18,
	hand_offset = Vector(0,-36),
	peak_lift = 34,
	letter_scale = 1.2,
	letter_peak_scale = 2.0,
	letter_color = KColor(0.82,0.92,1,1),
	letter_death_color = KColor(1,0.12,0.12,1),
	color_have = KColor(0.88,0.92,1,1),
	color_miss = KColor(1,0.35,0.35,1),
	color_star_have = KColor(0.55,1,0.55,1),
	color_star_miss = KColor(1,0.75,0.25,1),
	color_six_have = KColor(1,0.45,0.85,1),
	color_ready = KColor(1,0.85,0.4,1),
	color_near = KColor(0.75,0.75,0.8,1),
	color_death = KColor(1,0.25,0.35,1),
	color_death_sel = KColor(1,0.55,0.2,1),
	color_belial_six = KColor(0.85,0.35,1,1),
}

local state_key = item.own_key.."states"
local visuals_key = item.own_key.."visuals"
local pending_key = item.own_key.."pending"
local death_ready_key = item.own_key.."death_ready"
local selection_key = "DeathSentence"
local letter_weights = {}
local total_letter_weight = 0

local blocked_actions = {
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
	[ButtonAction.ACTION_MENUCONFIRM] = true,
}

local function player_key(player)
	return tostring(player:GetData().__Index or player.InitSeed)
end

local function normalize_letter(ch)
	if ch == "*" or ch == "＊" or ch == "＝" or ch == "=" then return STAR end
	return ch
end

local function deny_sound()
	-- 面板拒绝确认：固定用此音效，勿改成 THUMBS_DOWN。
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ,0.85,1,false,0,2)
end

local function ensure_devil_pool()
	if item._devil_ids then return item._devil_ids end
	local map = {}
	local itempool = Game():GetItemPool()
	if itempool and itempool.GetCollectiblesFromPool then
		local list = itempool:GetCollectiblesFromPool(ItemPoolType.POOL_DEVIL)
		for _,info in pairs(list or {}) do
			local id = type(info) == "table" and info.itemID or info
			if type(id) == "number" and id > 0 then map[id] = true end
		end
	end
	item._devil_ids = map
	return map
end

local function is_devil_item(id)
	if not id then return false end
	return ensure_devil_pool()[id] == true
end

local function ensure_hanzi_pinyin()
	if item._hanzi_pinyin then return item._hanzi_pinyin end
	local chinese_input = require("Qing_Remaster_scripts.others.Chinese_input_holder")
	local map = {}
	for syllable,chars in pairs(chinese_input.data or {}) do
		local upper = string.upper(tostring(syllable))
		for _,ch in ipairs(auxi.spilt_string(chars)) do
			if not map[ch] then map[ch] = upper end
		end
	end
	item._hanzi_pinyin = map
	return map
end

local function migrate_letters(letters)
	if not letters then return end
	for index,letter in ipairs(letters) do
		letters[index] = normalize_letter(letter)
	end
end

local function get_state(player,create)
	save.elses[state_key] = save.elses[state_key] or {}
	local key = player_key(player)
	if create then save.elses[state_key][key] = save.elses[state_key][key] or {letters = {}} end
	local state = save.elses[state_key][key]
	if state then
		state.letters = state.letters or {}
		migrate_letters(state.letters)
	end
	return state
end

local function smoothstep(t)
	t = math.max(0,math.min(1,t))
	return t * t * (3 - 2 * t)
end

local function max_charge()
	local config = Isaac.GetItemConfig():GetCollectible(item.entity)
	return config and config.MaxCharges or 1
end

local function held_item_offset(player)
	if REPENTOGON then
		local sprite = player:GetSprite()
		if sprite then
			local null_frame = nil
			if sprite.GetNullFrame then
				null_frame = sprite:GetNullFrame("PlayerPickup") or sprite:GetNullFrame("PlayerPickupSparkle")
			end
			if (not null_frame) and sprite.GetOverlayNullFrame then
				null_frame = sprite:GetOverlayNullFrame("PlayerPickup") or sprite:GetOverlayNullFrame("PlayerPickupSparkle")
			end
			if null_frame and null_frame.GetPos then
				local pos = null_frame:GetPos()
				if pos and (pos.X ~= 0 or pos.Y ~= 0) then return pos end
			end
		end
	end
	return Vector(item.hand_offset.X,item.hand_offset.Y)
end

local function orbit_offset(index,count,frame)
	count = math.max(1,count)
	local ring = math.floor((index - 1) / 12)
	local ring_index = (index - 1) % 12
	local ring_count = math.min(12,count - ring * 12)
	local angle = frame * 0.025 + ring_index * math.pi * 2 / math.max(1,ring_count)
	local radius = 34 + ring * 13
	return Vector(math.cos(angle) * radius,math.sin(angle) * radius * 0.55 - 24)
end

local function gather_offset(index,count)
	local spacing = 10
	return Vector((index - (count + 1) * 0.5) * spacing,-52)
end

local function orbiting_count(visuals)
	local count = 0
	for _,vis in ipairs(visuals) do
		if vis.phase == "orbit" or vis.phase == "to_orbit" or vis.phase == "rise" or
			vis.phase == "hover" or vis.phase == "wait_hand" then
			count = count + 1
		end
	end
	return count
end

local function reindex_slots(visuals)
	local slot = 1
	for _,vis in ipairs(visuals) do
		if vis.phase ~= "gather" and vis.phase ~= "done" then
			vis.slot = slot
			slot = slot + 1
		end
	end
end

local function rebuild_visuals(player,state)
	local visuals = {}
	local frame = Game():GetFrameCount()
	local count = #state.letters
	for index,letter in ipairs(state.letters) do
		table.insert(visuals,{
			char = letter,
			phase = "orbit",
			slot = index,
			offset = orbit_offset(index,count,frame),
			scale = item.letter_scale,
			timer = 0,
		})
	end
	player:GetData()[visuals_key] = visuals
	player:GetData()[death_ready_key] = nil
	return visuals
end

local function ensure_visuals(player,state)
	local data = player:GetData()
	local visuals = data[visuals_key]
	if visuals then return visuals end
	return rebuild_visuals(player,state)
end

local function is_busy(player)
	return player:GetData()[pending_key] ~= nil
end

local function pattern_chars(pattern)
	return auxi.spilt_string(tostring(pattern or ""))
end

local function char_count(str)
	return #pattern_chars(str)
end

-- 空格忽略；A-Z 保留；汉字拆成拼音字母；其余符号变为 =，由通配符支付。
local function name_pattern(name)
	local pinyin_map = ensure_hanzi_pinyin()
	local chars = {}
	for _,ch in ipairs(auxi.spilt_string(tostring(name or ""))) do
		if ch == " " or ch == "\t" then
			-- skip
		elseif #ch == 1 then
			local upper = string.upper(ch)
			local byte = string.byte(upper)
			if byte >= 65 and byte <= 90 then
				table.insert(chars,upper)
			else
				table.insert(chars,STAR)
			end
		else
			local pinyin = pinyin_map[ch]
			if pinyin then
				for index = 1,#pinyin do
					local letter = string.sub(pinyin,index,index)
					local byte = string.byte(letter)
					if byte >= 65 and byte <= 90 then table.insert(chars,letter) end
				end
			else
				table.insert(chars,STAR)
			end
		end
	end
	return table.concat(chars)
end

local function letter_counts(letters)
	local counts = {}
	for _,letter in ipairs(letters or {}) do
		letter = normalize_letter(letter)
		counts[letter] = (counts[letter] or 0) + 1
	end
	return counts
end

-- 彼列之书：匹配时始终额外提供一个虚拟 6。
local function effective_counts(player,state)
	local counts = letter_counts(state and state.letters)
	if player and auxi.should_do_belial(player) then
		counts[BELIAL_SIX] = (counts[BELIAL_SIX] or 0) + 1
	end
	return counts
end

-- opts.devil_six：恶魔房池道具可用 6 通配任意字符。
local function analyze_pattern(pattern,counts,opts)
	opts = opts or {}
	local avail = {}
	for key,value in pairs(counts or {}) do avail[key] = value end
	local status = {}
	local missing = 0
	local chars = pattern_chars(pattern)
	for index,ch in ipairs(chars) do
		ch = normalize_letter(ch)
		if ch == STAR then
			if (avail[STAR] or 0) > 0 then
				avail[STAR] = avail[STAR] - 1
				status[index] = "star_have"
			elseif opts.devil_six and (avail[BELIAL_SIX] or 0) > 0 then
				avail[BELIAL_SIX] = avail[BELIAL_SIX] - 1
				status[index] = "six_have"
			else
				missing = missing + 1
				status[index] = "star_miss"
			end
		elseif (avail[ch] or 0) > 0 then
			avail[ch] = avail[ch] - 1
			status[index] = "have"
		elseif opts.devil_six and (avail[BELIAL_SIX] or 0) > 0 then
			avail[BELIAL_SIX] = avail[BELIAL_SIX] - 1
			status[index] = "six_have"
		else
			missing = missing + 1
			status[index] = "miss"
		end
	end
	return missing,status,chars
end

local function can_spell(pattern,counts,opts)
	local chars = pattern_chars(pattern)
	if #chars == 0 then return false end
	local missing = analyze_pattern(pattern,counts,opts)
	return missing == 0
end

local function english_name(config)
	local name = config.Name or ""
	if REPENTOGON and Isaac.GetLocalizedString and string.sub(name,1,1) == "#" then
		local localized = Isaac.GetLocalizedString("Items",name,"en")
		if localized and localized ~= "" then name = localized end
	end
	if string.sub(name,1,1) == "#" then return "" end
	return name
end

local function chinese_name(config,fallback_en)
	local name = config.Name or ""
	if REPENTOGON and Isaac.GetLocalizedString and string.sub(name,1,1) == "#" then
		local localized = Isaac.GetLocalizedString("Items",name,"zh")
		if localized and localized ~= "" and string.sub(localized,1,1) ~= "#" then
			return localized
		end
	end
	return fallback_en or english_name(config)
end

local function rebuild_letter_weights()
	local counts = {}
	for code = 65,90 do counts[string.char(code)] = 0 end
	counts[STAR] = 0
	for _,entry in ipairs(item.item_names or {}) do
		for _,ch in ipairs(pattern_chars(entry.word)) do
			ch = normalize_letter(ch)
			if counts[ch] ~= nil then counts[ch] = counts[ch] + 1 end
		end
	end
	letter_weights = {}
	total_letter_weight = 0
	for code = 65,90 do
		local ch = string.char(code)
		local weight = counts[ch] or 0
		if weight > 0 then
			table.insert(letter_weights,{ch,weight})
			total_letter_weight = total_letter_weight + weight
		end
	end
	local star_weight = counts[STAR] or 0
	if star_weight > 0 then
		table.insert(letter_weights,{STAR,star_weight})
		total_letter_weight = total_letter_weight + star_weight
	end
	if total_letter_weight <= 0 then
		letter_weights = {{"E",1}}
		total_letter_weight = 1
	end
end

local function collect_item_names()
	if item.item_names then return item.item_names end
	item.item_names = {}
	local config = Isaac.GetItemConfig()
	local size = config:GetCollectibles().Size
	for id = 1,size - 1 do
		local collectible = config:GetCollectible(id)
		if collectible and collectible:IsCollectible() and id ~= item.entity then
			local name = english_name(collectible)
			local zh = chinese_name(collectible,name)
			local word = name_pattern(name)
			-- 无英文名时用中文名；汉字经拼音拆成字母，未收录汉字回退为 =。
			if word == "" and zh ~= "" then
				word = name_pattern(zh)
				if name == "" then name = zh end
			end
			if name ~= "" and word ~= "" then
				table.insert(item.item_names,{
					id = id,
					name = name,
					zh = zh,
					word = word,
				})
			end
		end
	end
	table.sort(item.item_names,function(a,b)
		local la,lb = char_count(a.word),char_count(b.word)
		if la ~= lb then return la < lb end
		return a.name < b.name
	end)
	rebuild_letter_weights()
	return item.item_names
end

local function get_candidates(state,player)
	player = player or (item.panel and item.panel.player)
	local counts = effective_counts(player,state)
	local ready = {}
	local near = {}
	local belial = player and auxi.should_do_belial(player)

	local death_word = item.get_death_word()
	local d_missing,d_status,d_chars = analyze_pattern(death_word,counts)
	local death_entry = {
		death = true,
		id = nil,
		name = death_word,
		zh = "DEATH",
		word = death_word,
		chars = d_chars,
		missing = d_missing,
		status = d_status,
		ready = d_missing == 0,
	}

	for _,entry in ipairs(collect_item_names()) do
		local devil = belial and is_devil_item(entry.id)
		local missing,status,chars = analyze_pattern(entry.word,counts,{devil_six = devil})
		if missing == 0 then
			table.insert(ready,{
				id = entry.id,
				name = entry.name,
				zh = entry.zh,
				word = entry.word,
				chars = chars,
				missing = 0,
				status = status,
				ready = true,
				devil = devil,
			})
		elseif missing > 0 and missing <= item.near_miss_limit then
			table.insert(near,{
				id = entry.id,
				name = entry.name,
				zh = entry.zh,
				word = entry.word,
				chars = chars,
				missing = missing,
				status = status,
				ready = false,
				devil = devil,
			})
		end
	end
	table.sort(near,function(a,b)
		if a.missing ~= b.missing then return a.missing < b.missing end
		local la,lb = char_count(a.word),char_count(b.word)
		if la ~= lb then return la < lb end
		return a.name < b.name
	end)
	local candidates = {}
	for _,entry in ipairs(ready) do table.insert(candidates,entry) end
	for _,entry in ipairs(near) do table.insert(candidates,entry) end
	-- 死亡词始终入列，放在末尾并用特殊配色提示。
	table.insert(candidates,death_entry)
	return candidates
end

local function same_panel_player(player)
	return item.panel and item.panel.player and player
		and player_key(item.panel.player) == player_key(player)
end

local function close_panel()
	if not item.panel then return end
	local player = item.panel.player
	if player then
		selection_holder.remove_select(player,selection_key)
		if player:Exists() and player:IsHoldingItem() then
			player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
		end
	end
	item.panel = nil
	-- 关闭后短时间内禁止空格再次走 USE_ITEM 开面板（panel=nil 时 ACTION_ITEM 屏蔽失效）。
	item.suppress_open_until = Game():GetFrameCount() + 2
	auxi.time_free(item.own_key)
end

local function open_panel(player)
	if is_busy(player) then return end
	if same_panel_player(player) then return end
	local state = get_state(player,true)
	item.panel = {
		player = player,
		state = state,
		candidates = get_candidates(state,player),
		selected = 1,
		opened_frame = Game():GetFrameCount(),
		wait_ctrl_release = true,
		input_armed = false,
	}
	selection_holder.try_select(player,selection_key)
	player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
	auxi.time_stop(item.own_key)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOOK_PAGE_TURN_12,1,1,false,0,2)
end

local spawn_selected

-- 对齐炼金锅：在 POST_PLAYER_UPDATE 里直接读 Input.IsActionTriggered/Pressed。
local function update_panel_input(player)
	local panel = item.panel
	if not same_panel_player(player) then return end
	if Game():IsPaused() then return end
	local frame = Game():GetFrameCount()
	if frame <= panel.opened_frame then return end
	if is_busy(player) then return end
	local ctrlid = player.ControllerIndex

	if not panel.input_armed then
		local still_held = Input.IsActionPressed(ButtonAction.ACTION_ITEM,ctrlid) or
			Input.IsActionPressed(ButtonAction.ACTION_MENUCONFIRM,ctrlid)
		if not still_held then panel.input_armed = true end
		return
	end

	if panel.wait_ctrl_release then
		if not Input.IsActionPressed(ButtonAction.ACTION_DROP,ctrlid) then
			panel.wait_ctrl_release = false
		end
	elseif Input.IsActionTriggered(ButtonAction.ACTION_DROP,ctrlid) then
		close_panel()
		return
	end

	-- 只用射击方向键翻页（默认方向键），不用 WASD。
	if Input.IsActionTriggered(ButtonAction.ACTION_SHOOTUP,ctrlid) and #panel.candidates > 0 then
		panel.selected = (panel.selected - 2) % #panel.candidates + 1
	elseif Input.IsActionTriggered(ButtonAction.ACTION_SHOOTDOWN,ctrlid) and #panel.candidates > 0 then
		panel.selected = panel.selected % #panel.candidates + 1
	end
	-- 确认：无法生成时只发音效，绝不关面板。
	if Input.IsActionTriggered(ButtonAction.ACTION_ITEM,ctrlid) or
		Input.IsActionTriggered(ButtonAction.ACTION_MENUCONFIRM,ctrlid) then
		spawn_selected()
	end
end

local function finish_pending(player,pending)
	local data = player:GetData()
	data[pending_key] = nil
	data[death_ready_key] = nil
	local visuals = data[visuals_key] or {}
	for index = #visuals,1,-1 do
		if visuals[index].phase == "gather" or visuals[index].phase == "done" then
			table.remove(visuals,index)
		end
	end
	reindex_slots(visuals)

	if pending.kind == "final" then
		local state = get_state(player,true)
		state.letters = {}
		data[visuals_key] = {}
		close_panel()
		player:RemoveCollectible(item.entity)
		player:Die()
		return
	end

	if pending.kind == "item" and pending.item_id then
		local room = Game():GetRoom()
		local position = room:FindFreePickupSpawnPosition(player.Position + Vector(0,50),20,true)
		Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_COLLECTIBLE,
			pending.item_id,
			position,
			Vector.Zero,
			player
		)
		player:AnimateCollectible(pending.item_id,"Pickup","PlayerPickupSparkle")
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_CHOIR_UNLOCK,1,1,false,0,2)
	end
end

local function begin_gather(player,word,pending_info,opts)
	opts = opts or {}
	local state = get_state(player,true)
	local counts = effective_counts(player,state)
	local missing,status,word_chars = analyze_pattern(word,counts,{devil_six = opts.devil_six})
	if missing > 0 then return false end

	local visuals = ensure_visuals(player,state)
	local hand = held_item_offset(player)
	for index,wanted in ipairs(word_chars) do
		wanted = normalize_letter(wanted)
		local st = status[index]
		local pay = wanted
		if st == "star_have" then pay = STAR
		elseif st == "six_have" then pay = BELIAL_SIX
		end

		local removed = false
		for letter_index,letter in ipairs(state.letters) do
			if letter == pay then
				table.remove(state.letters,letter_index)
				removed = true
				break
			end
		end

		local used_vis = false
		if removed then
			for _,vis in ipairs(visuals) do
				if not vis.gathering and vis.char == pay and vis.phase ~= "gather" and vis.phase ~= "done" then
					vis.gathering = true
					vis.phase = "gather"
					vis.timer = 0
					vis.duration = item.gather_frames
					vis.from = Vector(vis.offset.X,vis.offset.Y)
					vis.gather_i = index
					vis.gather_n = #word_chars
					vis.scale = item.letter_scale
					vis.char = wanted
					used_vis = true
					break
				end
			end
		end
		if not used_vis then
			table.insert(visuals,{
				char = wanted,
				phase = "gather",
				gathering = true,
				ephemeral = true,
				slot = 0,
				timer = 0,
				duration = item.gather_frames,
				from = Vector(hand.X,hand.Y),
				offset = Vector(hand.X,hand.Y),
				gather_i = index,
				gather_n = #word_chars,
				scale = item.letter_scale,
			})
		end
	end
	reindex_slots(visuals)
	player:GetData()[pending_key] = {
		kind = pending_info.kind,
		item_id = pending_info.item_id,
		word = word,
		hold = 0,
		arrived = false,
	}
	player:GetData()[death_ready_key] = nil
	return true
end

function item.get_death_word()
	return item.death_word or DEFAULT_DEATH_WORD
end

function item.set_death_word(str)
	local chars = pattern_chars(string.upper(tostring(str or "")))
	local out = {}
	for _,ch in ipairs(chars) do
		ch = normalize_letter(ch)
		if ch == STAR then
			table.insert(out,STAR)
		elseif #ch == 1 then
			local byte = string.byte(ch)
			if byte >= 65 and byte <= 90 then table.insert(out,ch) end
		end
	end
	item.death_word = #out > 0 and table.concat(out) or DEFAULT_DEATH_WORD
end

local function has_death_word(letters)
	return can_spell(item.get_death_word(),letter_counts(letters))
end

local function death_word_match_count(letters)
	local word_chars = pattern_chars(item.get_death_word())
	if #word_chars == 0 then return 0,0 end
	local avail = letter_counts(letters)
	local matched = 0
	for _,ch in ipairs(word_chars) do
		ch = normalize_letter(ch)
		if (avail[ch] or 0) > 0 then
			avail[ch] = avail[ch] - 1
			matched = matched + 1
		end
	end
	return matched,#word_chars
end

local function death_contributor_map(visuals,letters)
	local word_chars = pattern_chars(item.get_death_word())
	local avail = {}
	for _,ch in ipairs(word_chars) do
		ch = normalize_letter(ch)
		avail[ch] = (avail[ch] or 0) + 1
	end
	local map = {}
	-- Prefer letters that currently exist toward the death word.
	local letter_avail = letter_counts(letters)
	for key,value in pairs(avail) do
		avail[key] = math.min(value,letter_avail[key] or 0)
	end
	for _,vis in ipairs(visuals or {}) do
		local ch = normalize_letter(vis.char)
		if vis.phase ~= "gather" and vis.phase ~= "done" and (avail[ch] or 0) > 0 then
			map[vis] = true
			avail[ch] = avail[ch] - 1
		end
	end
	return map
end

local function lerp_color(a,b,t)
	t = math.max(0,math.min(1,t))
	return KColor(
		a.Red + (b.Red - a.Red) * t,
		a.Green + (b.Green - a.Green) * t,
		a.Blue + (b.Blue - a.Blue) * t,
		a.Alpha + (b.Alpha - a.Alpha) * t
	)
end

local function parse_letters_string(str)
	local chars = pattern_chars(string.upper(tostring(str or "")))
	local out = {}
	for _,ch in ipairs(chars) do
		ch = normalize_letter(ch)
		if ch == " " or ch == "\t" or ch == "," then
			-- skip separators
		elseif ch == STAR or ch == BELIAL_SIX then
			table.insert(out,ch)
		elseif #ch == 1 then
			local byte = string.byte(ch)
			if byte >= 65 and byte <= 90 then table.insert(out,ch) end
		end
	end
	return out
end

function item.get_letters_string(player)
	if not player then return "" end
	local state = get_state(player,false)
	if not state then return "" end
	return table.concat(state.letters or {})
end

function item.set_letters_string(player,str)
	if not player then return end
	local state = get_state(player,true)
	state.letters = parse_letters_string(str)
	rebuild_visuals(player,state)
	player:GetData()[pending_key] = nil
	if same_panel_player(player) then
		item.panel.state = state
		item.panel.candidates = get_candidates(state,player)
		item.panel.selected = math.min(item.panel.selected,#item.panel.candidates)
		if item.panel.selected < 1 then item.panel.selected = 1 end
	end
end

function item.reset_debug(player)
	item.set_death_word(DEFAULT_DEATH_WORD)
	if player then item.set_letters_string(player,"") end
end

local function mark_death_ready(player,state)
	if has_death_word(state.letters) then
		local data = player:GetData()
		if not data[death_ready_key] then
			data[death_ready_key] = item.death_ready_frames
		end
	end
end

local function grant_letter(player,chosen,opts)
	opts = opts or {}
	if is_busy(player) and not opts.from_wisp then return end
	chosen = normalize_letter(chosen)
	if chosen ~= STAR and chosen ~= BELIAL_SIX then
		local byte = string.byte(chosen)
		if not byte or byte < 65 or byte > 90 then return end
	end
	local state = get_state(player,true)
	local visuals = ensure_visuals(player,state)
	table.insert(state.letters,chosen)
	local hand = held_item_offset(player)
	local slot = orbiting_count(visuals) + 1
	table.insert(visuals,{
		char = chosen,
		phase = "wait_hand",
		slot = slot,
		offset = Vector(hand.X,hand.Y),
		from = Vector(hand.X,hand.Y),
		scale = 0.35,
		timer = 0,
	})
	reindex_slots(visuals)
	if not opts.silent then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,0.8,1,false,0,2)
	end
	mark_death_ready(player,state)
	if opts.spawn_wisp and auxi.should_spawn_wisp(player,opts.use_flags) then
		local wisp = player:AddWisp(item.entity,player.Position,false,false)
		if wisp then
			wisp:GetData()[item.own_key.."char"] = chosen
		end
	end
	if same_panel_player(player) then
		item.panel.state = state
		item.panel.candidates = get_candidates(state,player)
	end
end

local function summon_letter(player,rng,use_flags)
	if is_busy(player) then return end
	collect_item_names()
	local roll = rng:RandomFloat() * total_letter_weight
	local chosen = "E"
	for _,entry in ipairs(letter_weights) do
		roll = roll - entry[2]
		if roll <= 0 then chosen = entry[1] break end
	end
	grant_letter(player,chosen,{spawn_wisp = true,use_flags = use_flags})
end

spawn_selected = function()
	local panel = item.panel
	if not panel then return false end
	local selected = panel.candidates[panel.selected]
	-- 无法生成：只提示，绝不关闭面板。
	if not selected or not selected.ready then
		deny_sound()
		return false
	end
	if is_busy(panel.player) then
		deny_sound()
		return false
	end
	local player = panel.player
	close_panel()
	if selected.death then
		begin_gather(player,selected.word,{kind = "final"})
	else
		local devil = auxi.should_do_belial(player) and is_devil_item(selected.id)
		begin_gather(player,selected.word,{kind = "item",item_id = selected.id},{devil_six = devil})
	end
	return true
end

local function update_visuals(player)
	local state = get_state(player,true)
	local visuals = ensure_visuals(player,state)
	local data = player:GetData()
	local pending = data[pending_key]
	local frame = Game():GetFrameCount()
	local count = math.max(1,orbiting_count(visuals))
	local all_gathered = pending ~= nil
	local hand = held_item_offset(player)

	for _,vis in ipairs(visuals) do
		if vis.phase == "wait_hand" then
			vis.timer = vis.timer + 1
			vis.offset = Vector(hand.X,hand.Y)
			vis.scale = 0.35
			if vis.timer >= item.hand_wait or player:IsHoldingItem() then
				vis.phase = "rise"
				vis.timer = 0
				vis.from = Vector(hand.X,hand.Y)
				vis.peak = Vector(hand.X,hand.Y - item.peak_lift)
			end
		elseif vis.phase == "rise" then
			vis.timer = vis.timer + 1
			local t = smoothstep(vis.timer / item.rise_frames)
			local peak = vis.peak or Vector(hand.X,hand.Y - item.peak_lift)
			vis.offset = auxi.Lerp(vis.from,peak,t)
			vis.scale = auxi.Lerp(0.35,item.letter_peak_scale,t)
			if vis.timer >= item.rise_frames then
				vis.phase = "hover"
				vis.timer = 0
				vis.offset = peak
				vis.scale = item.letter_peak_scale
			end
		elseif vis.phase == "hover" then
			vis.timer = vis.timer + 1
			vis.offset = vis.peak or vis.offset
			vis.scale = item.letter_peak_scale
			if vis.timer >= item.hover_frames then
				vis.phase = "to_orbit"
				vis.timer = 0
				vis.from = Vector(vis.offset.X,vis.offset.Y)
			end
		elseif vis.phase == "to_orbit" then
			vis.timer = vis.timer + 1
			local target = orbit_offset(vis.slot,count,frame)
			local t = smoothstep(vis.timer / item.to_orbit_frames)
			vis.offset = auxi.Lerp(vis.from,target,t)
			vis.scale = auxi.Lerp(item.letter_peak_scale,item.letter_scale,t)
			if vis.timer >= item.to_orbit_frames then
				vis.phase = "orbit"
				vis.offset = target
				vis.scale = item.letter_scale
			end
		elseif vis.phase == "orbit" then
			local target = orbit_offset(vis.slot,count,frame)
			vis.offset = auxi.Lerp(vis.offset,target,item.orbit_lerp)
			vis.scale = item.letter_scale
		elseif vis.phase == "gather" then
			vis.timer = vis.timer + 1
			local target = gather_offset(vis.gather_i or 1,vis.gather_n or 1)
			local t = smoothstep(vis.timer / math.max(1,vis.duration or item.gather_frames))
			vis.offset = auxi.Lerp(vis.from,target,t)
			vis.scale = item.letter_scale * 1.15
			if vis.timer < (vis.duration or item.gather_frames) then
				all_gathered = false
			else
				vis.offset = target
				vis.phase = "done"
			end
		elseif vis.phase == "done" then
			vis.offset = gather_offset(vis.gather_i or 1,vis.gather_n or 1)
			vis.scale = item.letter_scale * 1.15
		end
	end

	if not pending then
		if has_death_word(state.letters) then
			if not data[death_ready_key] then
				data[death_ready_key] = item.death_ready_frames
			else
				data[death_ready_key] = data[death_ready_key] - 1
				if data[death_ready_key] <= 0 then
					data[death_ready_key] = nil
					close_panel()
					begin_gather(player,item.get_death_word(),{kind = "final"})
					pending = data[pending_key]
					all_gathered = false
				end
			end
		else
			data[death_ready_key] = nil
		end
	end

	if pending and all_gathered then
		pending.arrived = true
		pending.hold = (pending.hold or 0) + 1
		if pending.hold >= item.hold_frames then
			finish_pending(player,pending)
		end
	end
end

local function render_letter_list(player,behind_pass)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	if not auxi.has_have_coll(player,item.entity) and not player:GetData()[pending_key] then return end
	local state = get_state(player,true)
	local visuals = ensure_visuals(player,state)
	local matched,total = death_word_match_count(state.letters)
	local progress = (total > 0) and (matched / total) or 0
	if player:GetData()[death_ready_key] then progress = 1 end
	local contributors = death_contributor_map(visuals,state.letters)
	local base = Isaac.WorldToScreen(player.Position + player.PositionOffset)
	for _,vis in ipairs(visuals) do
		local is_front_phase = vis.phase ~= "orbit"
		local is_behind = (not is_front_phase) and (vis.offset.Y + 24) < 0
		if behind_pass == is_behind then
			local scale = vis.scale or item.letter_scale
			local color = item.letter_color
			if contributors[vis] or vis.phase == "gather" or vis.phase == "done" then
				local t = (vis.phase == "gather" or vis.phase == "done") and 1 or progress
				color = lerp_color(item.letter_color,item.letter_death_color,t)
			end
			gui.draw_ch(base + vis.offset,vis.char,scale,scale,color,true)
		end
	end
end

local function status_color(status)
	if status == "have" then return item.color_have end
	if status == "miss" then return item.color_miss end
	if status == "star_have" then return item.color_star_have end
	if status == "star_miss" then return item.color_star_miss end
	if status == "six_have" then return item.color_six_have end
	return item.color_have
end

local function text_width(str)
	return auxi.get_string_display_length(tostring(str or "")) * 3.2
end

local function draw_pattern_line(pos,prefix,entry,selected,col_pattern,col_missing)
	local prefix_color
	if entry.death then
		prefix_color = selected and item.color_death_sel or item.color_death
	else
		prefix_color = selected and item.color_ready or (entry.ready and item.color_have or item.color_near)
	end
	gui.draw_ch(pos,prefix,1,1,prefix_color,true)

	local name_pos = pos + Vector(16,0)
	local label = entry.name or ""
	if entry.zh and entry.zh ~= "" then
		label = entry.name.."  "..entry.zh
	end
	gui.draw_ch(name_pos,label,1,1,prefix_color,true)

	local pattern_pos = Vector(col_pattern,pos.Y)
	gui.draw_ch(pattern_pos,"[",1,1,prefix_color,true)
	local cursor = pattern_pos + Vector(6,0)
	local chars = entry.chars or pattern_chars(entry.word)
	for index,ch in ipairs(chars) do
		local color = status_color(entry.status and entry.status[index])
		if entry.death then
			color = lerp_color(color,item.color_death,0.55)
		end
		gui.draw_ch(cursor,ch,1,1,color,true)
		cursor = cursor + Vector((#ch > 1) and 10 or 6,0)
	end
	gui.draw_ch(cursor,"]",1,1,prefix_color,true)

	if not entry.ready then
		gui.draw_ch(Vector(col_missing,pos.Y),"(-"..tostring(entry.missing)..")",1,1,item.color_miss,true)
	elseif entry.death then
		gui.draw_ch(Vector(col_missing,pos.Y),"(DIE)",1,1,item.color_death,true)
	end
end

if REPENTOGON and ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE then
	table.insert(item.ToCall,{CallBack = ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE,params = item.entity,
	Function = function(_,slot,player,_)
		if player:GetActiveCharge(slot) <= 0 then return 0 end
		return max_charge()
	end,
	})
end

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_USE_ITEM,params = item.entity,
Function = function(_,_,rng,player,use_flags,active_slot)
	if use_flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then return end
	if use_flags & UseFlag.USE_OWNED ~= UseFlag.USE_OWNED then return end
	active_slot = active_slot or ActiveSlot.SLOT_PRIMARY
	local charge = player:GetActiveCharge(active_slot)
	if charge <= 0 then
		-- 面板已开：确认由 POST_PLAYER_UPDATE 处理，这里绝不再 open_panel。
		if same_panel_player(player) or is_busy(player) then
			return {Discharge = false,ShowAnim = false}
		end
		if Game():GetFrameCount() <= (item.suppress_open_until or -1) then
			return {Discharge = false,ShowAnim = false}
		end
		open_panel(player)
		return {Discharge = false,ShowAnim = false}
	end
	summon_letter(player,rng,use_flags)
	return {Discharge = true,ShowAnim = true}
end,
})

-- 对齐炼金锅：只在 ent~=nil 时拦 TRIGGERED/PRESSED；不拦 GET_ACTION_VALUE，好让 Update 里还能读到键。
table.insert(item.ToCall,{CallBack = ModCallbacks.MC_INPUT_ACTION,params = nil,
Function = function(_,ent,hook,button)
	if ent == nil then return end
	local player = ent:ToPlayer()
	if not player then return end
	if not same_panel_player(player) then return end
	if not blocked_actions[button] then return end
	if hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED then
		return false
	end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,params = nil,
Function = function(_,player)
	if item.room_selection_cleanup then
		selection_holder.remove_select(player,selection_key)
		item.room_selection_cleanup = nil
	end

	-- 换房丢弃 panel 后：仍举着则重开；超时仍举着则放下，避免空举
	if item.pending_reopen_until then
		if Game():GetFrameCount() > item.pending_reopen_until then
			item.pending_reopen_until = nil
			if not item.panel and auxi.has_have_coll(player,item.entity) and player:IsHoldingItem() then
				player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
			end
		elseif not item.panel
			and auxi.has_have_coll(player,item.entity)
			and player:IsHoldingItem()
			and not Game():IsPaused()
			and not is_busy(player)
		then
			item.suppress_open_until = -1
			item.pending_reopen_until = nil
			open_panel(player)
			return
		end
	end

	if auxi.has_have_coll(player,item.entity) or player:GetData()[pending_key] then
		update_visuals(player)
	end

	if same_panel_player(player) then
		-- 不要 ControlsCooldown：会把 IsActionTriggered 一并弄死（炼金锅也不这么干）。
		if not player:IsHoldingItem() then
			player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
		end
		update_panel_input(player)
		return
	end

	if not player:IsExtraAnimationFinished() then return end
	if Game():IsPaused() then return end
	if is_busy(player) then return end
	local needed = max_charge()
	for slot = ActiveSlot.SLOT_PRIMARY,ActiveSlot.SLOT_POCKET do
		if player:GetActiveItem(slot) == item.entity and player:GetActiveCharge(slot) >= needed then
			player:UseActiveItem(item.entity,UseFlag.USE_OWNED,slot)
			if player:GetActiveCharge(slot) >= needed then
				player:DischargeActiveItem(slot)
			end
		end
	end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NEW_ROOM,params = nil,
Function = function(_)
	-- 生命周期边界禁止触碰缓存的 panel.player；Exists() 也不能证明 GetData 安全。
	local was_open = item.panel ~= nil
	item.panel = nil
	item.suppress_open_until = Game():GetFrameCount() + 2
	item.room_selection_cleanup = true
	item.pending_reopen_until = was_open and (Game():GetFrameCount() + 8) or nil
	auxi.time_free(item.own_key)
end,
})

if REPENTOGON and ModCallbacks.MC_PRE_PLAYER_RENDER then
	table.insert(item.ToCall,{CallBack = ModCallbacks.MC_PRE_PLAYER_RENDER,params = nil,
	Function = function(_,player,_)
		render_letter_list(player,true)
	end,
	})
end

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER,params = nil,
Function = function(_,player,_)
	if REPENTOGON and ModCallbacks.MC_PRE_PLAYER_RENDER then
		render_letter_list(player,false)
	else
		render_letter_list(player,true)
		render_letter_list(player,false)
	end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_RENDER,params = nil,
Function = function(_)
	local panel = item.panel
	if not panel then return end
	if REPENTOGON and Game():IsPauseMenuOpen() then return end
	if not panel.player or not panel.player:Exists() then close_panel() return end

	local screen = gui.GetScreenSize()
	local start = math.floor((panel.selected - 1) / item.page_size) * item.page_size + 1
	local finish = math.min(#panel.candidates,start + item.page_size - 1)
	local base = Vector(math.max(18,screen.X * 0.5 - 220),math.max(18,screen.Y - 160))

	local max_name_w = 120
	for index = start,finish do
		local entry = panel.candidates[index]
		local label = entry.name or ""
		if entry.zh and entry.zh ~= "" then label = entry.name.."  "..entry.zh end
		max_name_w = math.max(max_name_w,text_width(label))
	end
	local col_pattern = 16 + max_name_w + 16
	local max_pattern_w = 40
	for index = start,finish do
		local entry = panel.candidates[index]
		local width = text_width("["..(entry.word or "").."]")
		max_pattern_w = math.max(max_pattern_w,width)
	end
	local col_missing = col_pattern + max_pattern_w + 12

	local letter_text = table.concat(panel.state.letters," ")
	if auxi.should_do_belial(panel.player) then
		if letter_text ~= "" then letter_text = letter_text.." " end
		letter_text = letter_text..BELIAL_SIX
	end
	gui.draw_ch(base,"DEATH SENTENCE  ["..letter_text.."]",1,1,KColor(0.9,0.95,1,1),true)
	if #panel.candidates == 0 then
		gui.draw_ch(base + Vector(0,18),"No near/ready names.",1,1,KColor(0.7,0.7,0.7,1),true)
	else
		for index = start,finish do
			local entry = panel.candidates[index]
			local prefix = index == panel.selected and "> " or "  "
			draw_pattern_line(
				base + Vector(0,14 + (index - start + 1) * 13),
				prefix,entry,index == panel.selected,col_pattern,col_missing
			)
		end
	end
	gui.draw_ch(base + Vector(0,132),"Arrows:Select  Active:Summon(ready)  Drop:Exit   red=missing/death  [=]=symbol  6=Belial",1,1,KColor(0.65,0.8,1,1),true)
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_FAMILIAR_RENDER,params = FamiliarVariant.WISP,
Function = function(_,ent,offset)
	if ent.SubType ~= item.entity then return end
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local ch = ent:GetData()[item.own_key.."char"]
	if not ch or ch == "" then return end
	local pos = Isaac.WorldToScreen(ent.Position + ent.PositionOffset) + (offset or Vector.Zero) + Vector(-3,-12)
	gui.draw_ch(pos,ch,0.85,0.85,item.letter_color,true)
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,params = nil,
Function = function(_,ent)
	if ent.Type ~= EntityType.ENTITY_FAMILIAR then return end
	if ent.Variant ~= FamiliarVariant.WISP or ent.SubType ~= item.entity then return end
	local ch = ent:GetData()[item.own_key.."char"]
	if not ch or ch == "" then return end
	local player = ent.Player
	if not player or not player:Exists() then return end
	if not auxi.has_have_coll(player,item.entity) then return end
	grant_letter(player,ch,{from_wisp = true})
end,
})

if EID then
	EID:addDescriptionModifier("qing_death_sentence_hide_eid_panel",function(desc)
		return item.panel ~= nil
	end,function(desc)
		desc.Name = ""
		desc.Description = ""
		desc.Icon = nil
		return desc
	end,1)
end

return item

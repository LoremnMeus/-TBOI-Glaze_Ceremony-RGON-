local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local A2ZFont = require("Qing_Remaster_scripts.others.a2z_font_renderer")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Remaster,
	own_key = "Item_Remaster_",
	panel = nil,
	floor_targets = {},
	pending_reopen_until = nil,
	-- 续关后首个 NEW_LEVEL 不触发回传，避免载入即弹回
	_suppress_return = false,
	-- 动画/特效缺口：后续可在此挂传送门与抵达表现（当前为空实现）
	fx = {},
}

-- 永久渠道：PROFILE.PERMANENT_DATA（跨局）。本局选择索引仍用 ELSES。
local PERM_CHANNELS_KEY = "Item_Remaster_channels"
local LEGACY_ELSES_KEY = "Item_Remaster_channel"
local SELECTION_KEY = "Item_Remaster_selection"

local function display_code(code)
	code = tostring(code or "")
	local body, floor = code:match("^(.-)(%d)$")
	if floor then
		body = body:gsub("%-", "")
		body = string.sub(body, 1, 7)
		return string.rep("-", math.max(0, 7 - #body))..body..floor
	end
	body = code:gsub("%-", "")
	body = string.sub(body, 1, 8)
	return string.rep("-", math.max(0, 8 - #body))..body
end

local function add(code, name, command, seed_stage)
	assert(#code == 8, "Remaster floor code must contain exactly 8 characters: "..code)
	table.insert(item.floor_targets, {
		code = display_code(code),
		name = name,
		command = command,
		seed_stage = seed_stage,
	})
end

-- 八字符 code 会在后续直接映射到 26 字母与连字符贴图。
local chapters = {
	{first = 1, names = {
		{"BASEMNT", "Basement", ""}, {"CELLAR-", "Cellar", "a"}, {"BURNBAS", "Burning Basement", "b"},
		{"DOWNPOR", "Downpour", "c"}, {"DROSS--", "Dross", "d"},
	}},
	{first = 3, names = {
		{"CAVES--", "Caves", ""}, {"CATACMB", "Catacombs", "a"}, {"FLOODCV", "Flooded Caves", "b"},
		{"MINES--", "Mines", "c"}, {"ASHPIT-", "Ashpit", "d"},
	}},
	{first = 5, names = {
		{"DEPTHS-", "Depths", ""}, {"NECROP-", "Necropolis", "a"}, {"DANKDEP", "Dank Depths", "b"},
		{"MAUSOLM", "Mausoleum", "c"}, {"GEHENNA", "Gehenna", "d"},
	}},
	{first = 7, names = {
		{"WOMB---", "Womb", ""}, {"UTERO--", "Utero", "a"}, {"SCARWMB", "Scarred Womb", "b"},
		{"CORPSE-", "Corpse", "c"},
	}},
}

for _, chapter in ipairs(chapters) do
	for floor_offset = 0, 1 do
		local floor_number = floor_offset + 1
		local stage = chapter.first + floor_offset
		for _, variant in ipairs(chapter.names) do
			add(variant[1]..floor_number, variant[2]..(floor_number == 1 and " I" or " II"), tostring(stage)..variant[3], stage)
		end
	end
end

add("BLUEWOMB", "Blue Womb", "9", 9)
add("SHEOL---", "Sheol", "10", 10)
add("CATHEDRL", "Cathedral", "10a", 10)
add("DARKROOM", "Dark Room", "11", 11)
add("CHEST---", "Chest", "11a", 11)
add("VOID----", "Void", "12", 12)
add("HOME----", "Home", "13", 13)

-- ---------- 楼层身份 / 渠道 ----------
local function stage_type_suffix(stage_type)
	if stage_type == StageType.STAGETYPE_WOTL then return "a" end
	if stage_type == StageType.STAGETYPE_AFTERBIRTH then return "b" end
	if stage_type == StageType.STAGETYPE_REPENTANCE then return "c" end
	if stage_type == StageType.STAGETYPE_REPENTANCE_B then return "d" end
	return ""
end

local function suffix_to_stage_type(suffix)
	if suffix == "a" then return StageType.STAGETYPE_WOTL end
	if suffix == "b" then return StageType.STAGETYPE_AFTERBIRTH end
	if suffix == "c" then return StageType.STAGETYPE_REPENTANCE end
	if suffix == "d" then return StageType.STAGETYPE_REPENTANCE_B end
	return StageType.STAGETYPE_ORIGINAL
end

local function parse_command(command)
	command = tostring(command or "")
	local stage_s, suffix = command:match("^(%d+)([abcd]?)$")
	local stage = tonumber(stage_s)
	if not stage then return nil end
	return {
		stage = stage,
		stage_type = suffix_to_stage_type(suffix or ""),
		command = command,
		seed_stage = stage,
	}
end

--- 楼层信息压成纯表，避免枚举 userdata 进 RUN.ELSES 后无法续关还原
local function sanitize_floor_info(info)
	if type(info) ~= "table" then return nil end
	return {
		stage = tonumber(info.stage),
		stage_type = tonumber(info.stage_type) or 0,
		command = tostring(info.command or ""),
		seed_stage = tonumber(info.seed_stage) or tonumber(info.stage),
	}
end

local function capture_current_floor()
	local level = Game():GetLevel()
	local stage = level:GetStage()
	local stage_type = level:GetStageType()
	local command = tostring(stage)..stage_type_suffix(stage_type)
	return sanitize_floor_info({
		stage = stage,
		stage_type = stage_type,
		command = command,
		seed_stage = stage,
	})
end

local function floor_equals(info)
	if not info then return false end
	local level = Game():GetLevel()
	return level:GetStage() == info.stage and level:GetStageType() == info.stage_type
end

local function checkpoint_save(reason)
	if save.RuntimeLoaded == true and type(save.SaveModData) == "function" then
		pcall(save.SaveModData, "remaster:"..tostring(reason or "channel"))
	end
end

local function normalize_channel(ch)
	if type(ch) ~= "table" then return nil end
	local from = sanitize_floor_info(ch.from)
	local to = sanitize_floor_info(ch.to)
	if not from or not to or not from.command or not to.command then return nil end
	if from.command == "" or to.command == "" then return nil end
	return {
		from = from,
		to = to,
		target_code = ch.target_code and tostring(ch.target_code) or nil,
		target_name = ch.target_name and tostring(ch.target_name) or nil,
		armed = ch.armed and true or false,
		skip_arrive_once = ch.skip_arrive_once and true or nil,
		returning = ch.returning and true or nil,
	}
end

local function channels_bag()
	save.PermanentData = save.PermanentData or {}
	local bag = save.PermanentData[PERM_CHANNELS_KEY]
	if type(bag) ~= "table" then
		bag = {list = {}}
		-- 兼容误写入 ELSES 的单渠道旧档
		local legacy = save.elses and save.elses[LEGACY_ELSES_KEY]
		if type(legacy) == "table" then
			local norm = normalize_channel(legacy)
			if norm then bag.list[1] = norm end
			save.elses[LEGACY_ELSES_KEY] = nil
		end
		save.PermanentData[PERM_CHANNELS_KEY] = bag
	end
	if type(bag.list) ~= "table" then bag.list = {} end
	return bag
end

local function get_channels()
	return channels_bag().list
end

local function find_channel_index_by_to(to_command)
	to_command = tostring(to_command or "")
	local list = get_channels()
	for i, ch in ipairs(list) do
		if ch.to and tostring(ch.to.command) == to_command then return i, ch end
	end
	return nil, nil
end

local function write_channels(list, reason)
	local bag = channels_bag()
	bag.list = list or {}
	checkpoint_save(reason or "channels")
end

--- 按目标楼层（to）去重写入；同 to 覆盖旧渠道。
local function upsert_channel(ch)
	local norm = normalize_channel(ch)
	if not norm then return nil end
	local list = get_channels()
	local idx = find_channel_index_by_to(norm.to.command)
	if idx then
		list[idx] = norm
	else
		list[#list + 1] = norm
		idx = #list
	end
	write_channels(list, norm.armed and "arm" or "set")
	return idx, norm
end

local function update_channel_at(index, ch)
	local list = get_channels()
	local norm = normalize_channel(ch)
	if not index or not list[index] or not norm then return false end
	list[index] = norm
	write_channels(list, "update")
	return true
end

local function remove_channel_at(index)
	local list = get_channels()
	index = tonumber(index)
	if not index or not list[index] then return false end
	table.remove(list, index)
	write_channels(list, "remove")
	return true
end

local function clear_all_channels()
	write_channels({}, "clear_all")
end

local function format_channel_label(ch, index)
	if not ch or not ch.from or not ch.to then return tostring(index or "?")..": <invalid>" end
	local state = ch.returning and "RETURNING" or (ch.skip_arrive_once and "OUTBOUND") or (ch.armed and "ARMED") or "IDLE"
	local name = ch.target_code or ch.target_name or ""
	if name ~= "" then name = " "..name end
	return string.format("%d: %s -> %s [%s]%s", index or 0, tostring(ch.from.command), tostring(ch.to.command), state, name)
end

function item.get_channels()
	return get_channels()
end

function item.format_channel_label(ch, index)
	return format_channel_label(ch, index)
end

function item.clear_all_channels()
	clear_all_channels()
	return true
end

function item.remove_channel_at(index)
	return remove_channel_at(index)
end

--- 调试/ImGui：用 stage 命令串添加永久渠道（默认已武装，便于立刻测回传）
function item.debug_add_channel(from_command, to_command, opts)
	opts = opts or {}
	local from = sanitize_floor_info(parse_command(from_command))
	local to = sanitize_floor_info(parse_command(to_command))
	if not from or not to then return nil, "invalid stage command" end
	if from.command == to.command and from.stage_type == to.stage_type then
		return nil, "from and to are the same floor"
	end
	local target_code, target_name
	for _, target in ipairs(item.floor_targets) do
		if target.command == to.command then
			target_code, target_name = target.code, target.name
			break
		end
	end
	local idx, norm = upsert_channel({
		from = from,
		to = to,
		target_code = target_code,
		target_name = target_name,
		armed = opts.armed ~= false,
		skip_arrive_once = opts.skip_arrive_once and true or nil,
	})
	return idx, norm
end

function item.debug_fill_from_current_floor()
	if not Game() or not Game():GetLevel() then return nil end
	local cur = capture_current_floor()
	return cur and cur.command or nil
end

--- 执行 stage 跳转；seed_stage 可选（用于重掷该层种子）
local function execute_stage_travel(floor_info, opts)
	opts = opts or {}
	if not floor_info or not floor_info.command then return end
	if opts.reseed ~= false then
		local new_seed = Random()
		if new_seed == 0 then new_seed = 1 end
		local seeds = Game():GetSeeds()
		local seed_stage = floor_info.seed_stage or floor_info.stage
		if seeds.SetStageSeed and seed_stage then
			seeds:SetStageSeed(seed_stage, new_seed)
		end
	end
	Isaac.ExecuteCommand("stage "..floor_info.command)
end

-- ---------- 特效缺口（默认无表现；后续替换） ----------
function item.fx.before_outbound(ctx)
	-- TODO: 出发侧传送门动画（A 侧）
end

function item.fx.after_outbound(ctx)
	-- TODO: 抵达 B 后的特效
end

function item.fx.before_return(ctx)
	-- TODO: B 侧触发回传时的传送门动画
end

function item.fx.after_return(ctx)
	-- TODO: 回到 A 后的特效
end

--- 供外部/后续动画模块查询（返回永久渠道列表）
function item.get_active_channel()
	local list = get_channels()
	return list[1]
end

function item.has_pending_return()
	for _, ch in ipairs(get_channels()) do
		if ch.armed == true then return true end
	end
	return false
end

-- ---------- 面板 UI ----------
local panel_font
local code_font = A2ZFont.new()
local function get_font()
	if not panel_font then
		panel_font = Font()
		panel_font:Load("font/cjk/lanapixel.fnt")
	end
	return panel_font
end

local function close_panel()
	local panel = item.panel
	if panel and panel.player and panel.player:Exists() and panel.player:IsHoldingItem() then
		panel.player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
	end
	item.panel = nil
end

local function open_panel(player, slot)
	local saved_index = tonumber(save.elses[SELECTION_KEY])
	if not saved_index or saved_index < 1 or saved_index > #item.floor_targets then saved_index = nil end
	item.panel = {
		player = player,
		slot = slot or ActiveSlot.SLOT_PRIMARY,
		index = saved_index,
		input_armed = false,
		transition = nil,
		display_code = saved_index and item.floor_targets[saved_index].code or "REMASTER",
	}
	player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
end

-- Menu input must not be tied to the player entity that opened the panel.
local function is_action_triggered(action)
	for controller = 0, 7 do
		if Input.IsActionTriggered(action, controller) then return true end
	end
	return false
end

local function is_action_pressed(action)
	for controller = 0, 7 do
		if Input.IsActionPressed(action, controller) then return true end
	end
	return false
end

local function menu_input_is_pressed()
	return is_action_pressed(ButtonAction.ACTION_MENUUP)
		or is_action_pressed(ButtonAction.ACTION_MENUDOWN)
		or is_action_pressed(ButtonAction.ACTION_MENULEFT)
		or is_action_pressed(ButtonAction.ACTION_MENURIGHT)
		or is_action_pressed(ButtonAction.ACTION_MENUCONFIRM)
		or Input.IsButtonPressed(Keyboard.KEY_LEFT_CONTROL, 0)
		or Input.IsButtonPressed(Keyboard.KEY_RIGHT_CONTROL, 0)
end

local function ctrl_cancel_triggered()
	return Input.IsButtonTriggered(Keyboard.KEY_LEFT_CONTROL, 0)
		or Input.IsButtonTriggered(Keyboard.KEY_RIGHT_CONTROL, 0)
end

local function alphabet_index(char)
	if type(char) ~= "string" or #char ~= 1 then return nil end
	local b = string.byte(char)
	if b >= 65 and b <= 90 then return b - 64 end
	if b >= 97 and b <= 122 then return b - 96 end
	return nil
end

--- B→D => {B,C,D}；C→B => {C,B}。非字母则直接两帧对切。
local function build_flip_path(from_char, to_char)
	from_char = tostring(from_char or " ")
	to_char = tostring(to_char or " ")
	if from_char == to_char then return {from_char}, 0 end
	local fi, ti = alphabet_index(from_char), alphabet_index(to_char)
	if not fi or not ti then
		return {from_char, to_char}, (string.byte(to_char) or 0) >= (string.byte(from_char) or 0) and 1 or -1
	end
	local path = {}
	local step = ti >= fi and 1 or -1
	for i = fi, ti, step do
		path[#path + 1] = string.char(64 + i)
	end
	return path, step
end

local flip_options_mod
local function get_flip_spacing()
	if flip_options_mod == nil then
		local ok, options = pcall(require, "Qing_Remaster_scripts.callbacks.rgon_imgui_options_holder")
		flip_options_mod = (ok and options) or false
	end
	if flip_options_mod and flip_options_mod.get_value then
		local v = tonumber(flip_options_mod.get_value({"QingRemasterOptions", "Debug", "RemasterCodeFlipSpacing"}))
		if v and v > 0 then return v end
	end
	return 4
end

--- 路径越靠中间的字母步切换越快；spacing 越大整体越慢。
local function segment_duration(seg_index, seg_count, spacing)
	spacing = math.max(0.5, tonumber(spacing) or 4)
	local base = 0.028 * spacing
	if seg_count <= 1 then return base end
	local t = (seg_index - 0.5) / seg_count
	local mid = 1 - 4 * (t - 0.5) * (t - 0.5) -- 端点0、中央1
	return base * (1 - 0.55 * mid)
end

local function begin_code_transition(panel, old_code, new_code)
	old_code = tostring(old_code or "REMASTER")
	new_code = tostring(new_code or "REMASTER")
	if old_code == new_code then
		panel.display_code = new_code
		panel.transition = nil
		return
	end
	local slots = {}
	local any = false
	for i = 1, 8 do
		local a = string.sub(old_code, i, i)
		local b = string.sub(new_code, i, i)
		if a == "" then a = "-" end
		if b == "" then b = "-" end
		if a ~= b then
			local path, dir = build_flip_path(a, b)
			slots[i] = {
				path = path,
				dir = dir >= 0 and 1 or -1,
				segment = 1,
				progress = 0,
			}
			any = true
		end
	end
	panel.display_code = new_code
	if any then
		panel.transition = {
			slots = slots,
			final_code = new_code,
			last_time = ((Isaac.GetTime and Isaac.GetTime()) or 0) / 1000,
		}
	else
		panel.transition = nil
	end
end

local function change_selection(delta)
	local panel = item.panel
	if panel then
		local old_code = panel.display_code or "REMASTER"
		if panel.transition and panel.transition.final_code then
			old_code = panel.transition.final_code
		end
		if not panel.index then
			panel.index = delta < 0 and #item.floor_targets or 1
		else
			panel.index = ((panel.index - 1 + delta) % #item.floor_targets) + 1
		end
		local new = item.floor_targets[panel.index]
		if new then
			begin_code_transition(panel, old_code, new.code)
		end
		save.elses[SELECTION_KEY] = panel.index
	end
end

local function render_code_char(char, index, y, alpha, scale_y)
	if not char or alpha <= 0 then return end
	local frame, _, _, source = code_font:glyph_metrics(char, 0)
	if not frame then return end
	local cell = 15
	local glyph = {
		char = char, frame = frame,
		x = Isaac.GetScreenWidth() * 0.5 + (index - 4.5) * cell,
		y = y,
		edge_layer = source and source.edge_layer or 0,
		glyph_layer = source and source.glyph_layer or 1,
	}
	local color = Color(1, 0.85, 0.35, alpha)
	local edge = Color(1, 1, 1, alpha, 0.32, 0.22, 0.04)
	local scale = Vector(1, math.max(0.05, scale_y or 1))
	code_font:render({glyph},
		function(g) return Vector(g.x, g.y) end,
		function() return edge, scale end,
		function() return color, scale end
	)
end

local function render_selected_code(panel, selected, base_y)
	local transition = panel.transition
	if not transition then
		local code = panel.display_code or (selected and selected.code) or "REMASTER"
		for i = 1, #code do render_code_char(string.sub(code, i, i), i, base_y, 1, 1) end
		return
	end
	local now = ((Isaac.GetTime and Isaac.GetTime()) or 0) / 1000
	local dt = math.max(0, math.min(0.05, now - (transition.last_time or now)))
	transition.last_time = now
	local spacing = get_flip_spacing()
	local travel = 22
	local all_done = true
	local final_code = transition.final_code or panel.display_code or "REMASTER"

	for i = 1, 8 do
		local slot = transition.slots[i]
		local settled = string.sub(final_code, i, i)
		if settled == "" then settled = "-" end
		if not slot then
			render_code_char(settled, i, base_y, 1, 1)
		else
			local path = slot.path
			local seg_count = math.max(1, #path - 1)
			if slot.segment > seg_count then
				render_code_char(path[#path] or settled, i, base_y, 1, 1)
			else
				all_done = false
				local dur = math.max(0.001, segment_duration(slot.segment, seg_count, spacing))
				-- 以秒进位：中间段更快时，溢出时间按新段时长换算，避免中间字母“停一拍”
				local time_acc = (slot.progress or 0) * dur + dt
				while time_acc >= dur and slot.segment <= seg_count do
					time_acc = time_acc - dur
					slot.segment = slot.segment + 1
					if slot.segment <= seg_count then
						dur = math.max(0.001, segment_duration(slot.segment, seg_count, spacing))
					else
						break
					end
				end
				if slot.segment > seg_count then
					slot.progress = 0
					render_code_char(path[#path] or settled, i, base_y, 1, 1)
				else
					slot.progress = time_acc / dur
					local p = math.max(0, math.min(1, slot.progress))
					local cur = path[slot.segment]
					local nxt = path[slot.segment + 1]
					local dir = slot.dir >= 0 and 1 or -1
					-- dir>0：旧字下落、新字自上落入；dir<0：旧字上抛、新字自下升起
					render_code_char(cur, i, base_y + dir * p * travel, 1 - p, 1 - p * 0.88)
					render_code_char(nxt, i, base_y - dir * (1 - p) * travel, p, 0.12 + p * 0.88)
				end
			end
		end
	end
	if all_done then
		panel.display_code = final_code
		panel.transition = nil
	end
end

local function travel_to_selected()
	local panel = item.panel
	if not panel then return end
	local target = item.floor_targets[panel.index]
	local player, slot = panel.player, panel.slot
	if not target then
		return
	end

	local from = capture_current_floor()
	local to = parse_command(target.command)
	if not to then
		close_panel()
		return
	end
	-- 同层不消耗、不建渠道
	if from.stage == to.stage and from.stage_type == to.stage_type then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1, false, 0, 2)
		return
	end

	close_panel()
	if player and player:Exists() then
		player:SetActiveCharge(0, slot)
	end

	local ctx = {
		dir = "outbound", -- A → B
		from = from,
		to = to,
		target = target,
		player = player,
		slot = slot,
	}

	-- 永久渠道写入 PROFILE.PERMANENT_DATA（跨局保留，直至回传消费）
	upsert_channel({
		from = from,
		to = to,
		target_code = target.code,
		target_name = target.name,
		armed = false,
		skip_arrive_once = true, -- 跳过本次 A→B 抵达，避免立刻回传
	})

	pcall(function() item.fx.before_outbound(ctx) end)
	execute_stage_travel(to, {reseed = true})
end

local function arm_channel_after_outbound(index, ch)
	if not ch or not index then return end
	ch.skip_arrive_once = nil
	ch.armed = true
	ch.returning = nil
	update_channel_at(index, ch)
	local ctx = {dir = "outbound_arrive", from = ch.from, to = ch.to, channel = ch}
	pcall(function() item.fx.after_outbound(ctx) end)
end

local function try_trigger_return_channel()
	local list = get_channels()
	if #list == 0 then return end

	-- 续关：只补齐武装状态，不立刻回传
	if item._suppress_return then
		item._suppress_return = false
		for i, ch in ipairs(list) do
			ch.from = sanitize_floor_info(ch.from) or ch.from
			ch.to = sanitize_floor_info(ch.to) or ch.to
			if ch.skip_arrive_once and floor_equals(ch.to) then
				arm_channel_after_outbound(i, ch)
			elseif ch.armed or ch.skip_arrive_once then
				update_channel_at(i, ch)
			end
		end
		return
	end

	local hit_index, hit = nil, nil
	for i, ch in ipairs(list) do
		ch.from = sanitize_floor_info(ch.from) or ch.from
		ch.to = sanitize_floor_info(ch.to) or ch.to
		if floor_equals(ch.to) then
			if ch.skip_arrive_once then
				arm_channel_after_outbound(i, ch)
				return
			end
			if ch.armed and not ch.returning then
				hit_index, hit = i, ch
				break
			end
		end
	end
	if not hit_index or not hit then return end

	hit.returning = true
	update_channel_at(hit_index, hit)

	-- 抵达所选楼层 B：回传出发楼层 A；跳转后再从永久列表移除该渠道
	local ctx = {
		dir = "return", -- B → A
		from = hit.to,
		to = hit.from,
		channel = hit,
		channel_index = hit_index,
	}
	pcall(function() item.fx.before_return(ctx) end)

	delay_buffer.addeffe(function()
		execute_stage_travel(ctx.to, {reseed = true})
		-- 按 to 命令定位，避免列表增删后 index 漂移误删
		local to_cmd = ctx.channel and ctx.channel.to and ctx.channel.to.command
		local idx = to_cmd and select(1, find_channel_index_by_to(to_cmd)) or ctx.channel_index
		if idx then remove_channel_at(idx) end
		delay_buffer.addeffe(function()
			pcall(function() item.fx.after_return(ctx) end)
		end, {}, 1)
	end, {}, 1)
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, _, _, player, use_flags, active_slot)
	if use_flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then return end
	if item.panel then
		return {Discharge = false, ShowAnim = false}
	end
	open_panel(player, active_slot)
	return {Discharge = false, ShowAnim = false}
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local panel = item.panel
	if not panel then
		-- 换层/换房丢弃 panel 后：仍举着则重开；超时则放下
		if item.pending_reopen_until then
			if Game():GetFrameCount() > item.pending_reopen_until then
				item.pending_reopen_until = nil
				for i = 0, Game():GetNumPlayers() - 1 do
					local player = Game():GetPlayer(i)
					if player and player:Exists() and player:HasCollectible(item.entity) and player:IsHoldingItem() then
						player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
					end
				end
			else
				for i = 0, Game():GetNumPlayers() - 1 do
					local player = Game():GetPlayer(i)
					if player and player:Exists() and player:HasCollectible(item.entity) and player:IsHoldingItem() then
						item.pending_reopen_until = nil
						open_panel(player, ActiveSlot.SLOT_PRIMARY)
						break
					end
				end
			end
		end
		return
	end
	local player = panel.player
	if not player or not player:Exists() then
		close_panel()
		return
	end
	player.ControlsCooldown = math.max(player.ControlsCooldown, 2)
	if not player:IsHoldingItem() then
		player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	local panel = item.panel
	if not panel then return end
	if not panel.input_armed then
		if not menu_input_is_pressed() then panel.input_armed = true end
	else
		if is_action_triggered(ButtonAction.ACTION_MENUUP) then change_selection(-1) end
		if is_action_triggered(ButtonAction.ACTION_MENUDOWN) then change_selection(1) end
		if is_action_triggered(ButtonAction.ACTION_MENULEFT) then change_selection(-5) end
		if is_action_triggered(ButtonAction.ACTION_MENURIGHT) then change_selection(5) end
		if is_action_triggered(ButtonAction.ACTION_MENUCONFIRM) then
			travel_to_selected()
		elseif ctrl_cancel_triggered() then
			close_panel()
		end
	end
	panel = item.panel
	if not panel then return end
	local font = get_font()
	local sw, sh = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
	local selected = item.floor_targets[panel.index]
	render_selected_code(panel, selected, sh * 0.22)
	local links = get_channels()
	if #links > 0 then
		local tip = "LINKS:"
		for i, ch in ipairs(links) do
			if i > 3 then
				tip = tip.." +"..tostring(#links - 3)
				break
			end
			if ch.from and ch.to then
				tip = tip.." "..tostring(ch.from.command).."->"..tostring(ch.to.command)
			end
		end
		font:DrawStringUTF8(tip, 0, sh * 0.39, KColor(1, 0.55, 0.55, 1), sw, true)
	end
	local first = panel.index and math.max(1, math.min(math.max(1, #item.floor_targets - 6), panel.index - 3)) or 1
	for index = first, math.min(#item.floor_targets, first + 6) do
		local target = item.floor_targets[index]
		local selected_row = index == panel.index
		local color = selected_row and KColor(1, 0.85, 0.35, 1) or KColor(0.65, 0.65, 0.65, 1)
		font:DrawStringUTF8((selected_row and "> " or "  ")..target.code.."  "..target.name, sw * 0.22, sh * 0.43 + (index - first) * 13, color, sw * 0.7, false)
	end
	font:DrawStringUTF8("UP/DOWN: SELECT   LEFT/RIGHT: PAGE", 0, sh * 0.82, KColor(0.7, 0.7, 0.7, 1), sw, true)
	font:DrawStringUTF8("CONFIRM: TRAVEL   CTRL: CANCEL", 0, sh * 0.87, KColor(0.7, 0.7, 0.7, 1), sw, true)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	-- 与蓝图相同：禁止碰旧 panel.player；仍举着则由 POST_UPDATE 重开
	-- NEW_LEVEL 与 NEW_ROOM 常成对触发：只在当时仍有 panel 时置 pending，勿清掉另一回调已设的标记
	if item.panel then
		item.panel = nil
		item.pending_reopen_until = Game():GetFrameCount() + 8
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	-- 新层边界只丢弃 Lua 缓存，禁止调用旧 panel.player 的原生方法。
	if item.panel then
		item.panel = nil
		item.pending_reopen_until = Game():GetFrameCount() + 8
	end
	try_trigger_return_channel()
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	item.panel = nil
	item.pending_reopen_until = nil
	if continue then
		item._suppress_return = true
	else
		item._suppress_return = false
		-- 永久渠道在 PermanentData，新开局不清空
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_)
	item.panel = nil
	item.pending_reopen_until = nil
end,
})

return item

-- RGON 完成贴纸管理器：本模组角色的原版标记以稳定角色 key 写入本地存档，
-- RGON 负责原生判定/菜单集成并在启动及完成事件时与本地数据审计同步。
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")

local MIGRATE_VERSION = 2
local STORE_KEY = "CompletionMarksV2"
local PLACEHOLDER_MARK_ID = "MomsHeart"

local VANILLA_MARKS = {
	{id = "MomsHeart", completion_type = CompletionType.MOMS_HEART, rgon_field = "MomsHeart"},
	{id = "Isaac", completion_type = CompletionType.ISAAC, rgon_field = "Isaac"},
	{id = "Satan", completion_type = CompletionType.SATAN, rgon_field = "Satan"},
	{id = "BossRush", completion_type = CompletionType.BOSS_RUSH, rgon_field = "BossRush"},
	{id = "BlueBaby", completion_type = CompletionType.BLUE_BABY, rgon_field = "BlueBaby"},
	{id = "Lamb", completion_type = CompletionType.LAMB, rgon_field = "Lamb"},
	{id = "MegaSatan", completion_type = CompletionType.MEGA_SATAN, rgon_field = "MegaSatan"},
	{id = "GreedMode", completion_type = CompletionType.ULTRA_GREED, rgon_field = "UltraGreed", greed = true},
	{id = "Hush", completion_type = CompletionType.HUSH, rgon_field = "Hush"},
	{id = "Delirium", completion_type = CompletionType.DELIRIUM, rgon_field = "Delirium"},
	{id = "Mother", completion_type = CompletionType.MOTHER, rgon_field = "Mother"},
	{id = "Beast", completion_type = CompletionType.BEAST, rgon_field = "Beast"},
}

local WIDGET_LAYERS = {
	Delirium = 0,
	MomsHeart = 1,
	Isaac = 2,
	Satan = 3,
	BossRush = 4,
	BlueBaby = 5,
	Lamb = 6,
	MegaSatan = 7,
	GreedMode = 8,
	Hush = 9,
	Mother = 10,
	Beast = 11,
}

local COMPLETION_TO_MARK = {}
for _,def in ipairs(VANILLA_MARKS) do
	COMPLETION_TO_MARK[def.completion_type] = def.id
end
if CompletionType.ULTRA_GREEDIER then
	COMPLETION_TO_MARK[CompletionType.ULTRA_GREEDIER] = "GreedMode"
end

local VANILLA_BY_ID = {}
for _,def in ipairs(VANILLA_MARKS) do
	VANILLA_BY_ID[def.id] = def
end

local LEGACY_TAINTED_KEY = {
	wq = "Spwq",
	Tecro = "Tecrorun",
	Anna = "annA",
}

local BOSS_ROW_BY_KEY = {
	Maggy = "Magdalene",
	Maggy_B = "Magdalene_B",
	Jacob_and_Esau = "JacobEsau",
	Jacob_and_Esau_B = "Jacob_B",
	wq = "wq",
	Spwq = "wq_B",
	Tecro = "Tecro",
	Tecrorun = "Tecro_B",
	Anna = "Anna",
	annA = "Anna_B",
	Zeis = "Zeis",
	Zeiz = "Zeis_B",
}

local manager = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	characters = {},
	characters_by_type = {},
	characters_by_key = {},
	extra_marks = {},
	extra_marks_sorted = {},
	extra_characters = {},
	extra_characters_by_type = {},
	extra_characters_by_key = {},
	renderers = {},
	rewards = {},
	sprite_cache = {},
	last_seen = {},
	last_audit = {},
	character_page_render_type = nil,
	in_run = false,
	pause_placeholder = nil,
	migrating = false,
	migrated = false,
	completing_vanilla = false,
}

local function clamp_status(status)
	status = math.floor(tonumber(status) or 0)
	if status < 0 then return 0 end
	if status > 2 then return 2 end
	return status
end

local function valid_player_type(player_type)
	return type(player_type) == "number" and player_type >= 0
end

local function achievements_allowed()
	return ModConfig.ModConfigSettings and ModConfig.ModConfigSettings.Achievement_allow == true
end

local function legacy_tracker_enabled()
	local root = ModConfig.ModConfigSettings
	local opts = root and root.QingRemasterOptions
	local achievements = opts and opts.Achievements
	return achievements and achievements.LegacyCompletionTracker == true
end

local function completion_mark_options()
	local root = ModConfig.ModConfigSettings
	local opts = root and root.QingRemasterOptions
	return opts and opts.CompletionMarks or nil
end

local function character_draw_postit()
	local marks = completion_mark_options()
	return marks and marks.CharacterDrawPostit == true
end

local function character_postit_offset()
	local marks = completion_mark_options()
	return Vector(tonumber(marks and marks.CharacterOffsetX) or -70, tonumber(marks and marks.CharacterOffsetY) or 26)
end

local function detect_surface(player_type)
	-- Main-menu APIs may retain CHARACTER after a run starts. The game lifecycle
	-- is the authoritative boundary: completion widgets rendered during a run
	-- belong to the pause menu; outside a run they belong to character select.
	if manager.in_run then return "pause" end
	if manager.character_page_render_type == player_type then return "character" end
	return "character"
end

local get_rgon_status
local legacy_unlock_status

local function layout_adapter_offset()
	if UNINTRUSIVEPAUSEMENU then return Vector(0, 0) end
	if MiniPauseMenu_Mod or MiniPauseMenuPlus_Mod then return Vector(0, 0) end
	return Vector(0, 0)
end

local function extra_mark_offset(scale, surface)
	scale = scale or Vector(1, 1)
	if surface == "character" then return Vector(48 * scale.X, 8 * scale.Y) end
	if UNINTRUSIVEPAUSEMENU then return Vector(50 * scale.X, -50 * scale.Y) end
	if MiniPauseMenu_Mod or MiniPauseMenuPlus_Mod then return Vector(24 * scale.X, -40 * scale.Y) end
	return Vector(172 * scale.X, -5 * scale.Y)
end

local function tracker()
	return package.loaded["Qing_Remaster_scripts.core.achievement_tracker"]
end

local function ensure_store()
	save.PermanentData = save.PermanentData or {}
	local store = save.CompletionMarksV2
	if type(store) ~= "table" then
		store = save.PermanentData[STORE_KEY]
	end
	if type(store) ~= "table" then
		store = {schema = "qing.completion_marks", schema_version = 2, vanilla = {}, extra = {}, pending_rewards = {}, migrate_version = 0}
	end
	store.schema_version = 2
	store.vanilla = store.vanilla or {}
	store.extra = store.extra or {}
	store.pending_rewards = store.pending_rewards or {}
	store.pause_placeholder_recovery = store.pause_placeholder_recovery or nil
	store.migrate_version = store.migrate_version or 0
	save.CompletionMarksV2 = store
	save.PermanentData[STORE_KEY] = store
	return store
end

local function persist()
	ensure_store()
	if save.RuntimeLoaded == true and save.SaveModData then save.SaveModData() end
end

local function extra_bucket(mark_id)
	local store = ensure_store()
	store.extra[mark_id] = store.extra[mark_id] or {}
	return store.extra[mark_id]
end

local function seen_bucket(player_type)
	manager.last_seen[player_type] = manager.last_seen[player_type] or {}
	return manager.last_seen[player_type]
end

local function sort_extra_marks()
	manager.extra_marks_sorted = {}
	for _,def in pairs(manager.extra_marks) do
		table.insert(manager.extra_marks_sorted, def)
	end
	table.sort(manager.extra_marks_sorted, function(a, b)
		local oa, ob = a.order or 0, b.order or 0
		if oa ~= ob then return oa < ob end
		return tostring(a.id) < tostring(b.id)
	end)
end

local function cached_sprite(key, loader)
	local sprite = manager.sprite_cache[key]
	if sprite then return sprite end
	sprite = Sprite()
	loader(sprite)
	manager.sprite_cache[key] = sprite
	return sprite
end

local function postit_sprite()
	return cached_sprite("qing_pause_postit", function(sprite)
		sprite:Load("gfx/ui/content/completion_widget.anm2", false)
		sprite:ReplaceSpritesheet(0, "gfx/ui/content/completion_widget_pause.png")
		sprite:LoadGraphics()
		sprite:Play("Idle", true)
	end)
end

local function character_postit_sprite()
	return cached_sprite("qing_character_postit", function(sprite)
		sprite:Load("gfx/ui/content/completion_widget.anm2", true)
		sprite:Play("Idle", true)
	end)
end

local function extra_sprite(def)
	local anm2 = def.anm2 or "gfx/ui/pause screen completion marks/sample_marks.anm2"
	return cached_sprite("extra:"..tostring(def.id), function(sprite)
		pcall(function()
			sprite:Load(anm2, true)
		end)
	end)
end

legacy_unlock_status = function(record)
	if type(record) ~= "table" then return 0 end
	if record.Hard == true then return 2 end
	if record.Unlock == true then return 1 end
	return 0
end

local function write_legacy_unlock(record, status)
	if type(record) ~= "table" then return end
	record.Unlock = status >= 1
	record.Hard = status >= 2
end

function manager.register_character(def)
	if type(def) ~= "table" or not valid_player_type(def.player_type) or not def.key then
		error("CompletionMarks.register_character requires player_type and key")
	end
	if manager.characters_by_type[def.player_type] or manager.characters_by_key[def.key] then
		error("CompletionMarks.register_character duplicate: "..tostring(def.key))
	end
	def.replace_vanilla = def.replace_vanilla ~= false
	def.pause_renderer = def.pause_renderer or "qing_postit"
	def.character_renderer = def.character_renderer or "qing_menu_marks"
	manager.characters[#manager.characters + 1] = def
	manager.characters_by_type[def.player_type] = def
	manager.characters_by_key[def.key] = def
	manager.register_extra_character({
		player_type = def.player_type,
		key = def.key,
		boss_row = def.boss_row or BOSS_ROW_BY_KEY[def.key] or def.key,
		legacy_boss_key = def.legacy_boss_key or def.legacy_parent_key or def.key,
		legacy_boss_field = def.legacy_boss_field or "Unlock",
	})
	return def
end

function manager.register_extra_character(def)
	if type(def) ~= "table" or not valid_player_type(def.player_type) or not def.key then return end
	if manager.extra_characters_by_type[def.player_type] == nil then
		manager.extra_characters[#manager.extra_characters + 1] = def
		manager.extra_characters_by_type[def.player_type] = def
	end
	manager.extra_characters_by_key[def.key] = manager.extra_characters_by_key[def.key] or def
	return def
end

function manager.register_extra_mark(def)
	if type(def) ~= "table" or not def.id then
		error("CompletionMarks.register_extra_mark requires id")
	end
	if manager.extra_marks[def.id] then
		error("CompletionMarks.register_extra_mark duplicate id: "..tostring(def.id))
	end
	def.order = def.order or 100
	manager.extra_marks[def.id] = def
	sort_extra_marks()
	return def
end

function manager.register_reward(mark_id, resolver)
	manager.rewards[mark_id] = resolver
end

function manager.register_renderer(name, renderer)
	manager.renderers[name] = renderer
end

function manager.get_character(player_type)
	return manager.characters_by_type[player_type]
end

function manager.player_type_from_key(key)
	local def = manager.characters_by_key[key]
	return def and def.player_type or nil
end

function manager.extra_character_key(player_type)
	local def = manager.extra_characters_by_type[player_type]
	return def and def.key or nil
end

local function extra_key_from_legacy(legacy_key, field)
	local tainted = field == "Tainted" or field == "TaintedHard"
	if not tainted then return legacy_key end
	return LEGACY_TAINTED_KEY[legacy_key] or (tostring(legacy_key).."_B")
end

local function boss_row_for_key(character_key)
	return BOSS_ROW_BY_KEY[character_key] or character_key
end

local vanilla_bucket

get_rgon_status = function(player_type, mark_id)
	local def = VANILLA_BY_ID[mark_id]
	if not def then return 0 end
	if REPENTOGON and Isaac.GetCompletionMark then
		if def.greed then
			local greed = Isaac.GetCompletionMark(player_type, CompletionType.ULTRA_GREED) or 0
			local greedier = CompletionType.ULTRA_GREEDIER and (Isaac.GetCompletionMark(player_type, CompletionType.ULTRA_GREEDIER) or 0) or 0
			if greedier >= 2 or greed >= 2 then return 2 end
			if greed >= 1 then return 1 end
			return 0
		end
		return clamp_status(Isaac.GetCompletionMark(player_type, def.completion_type))
	end
	return 0
end

local function set_rgon_status(player_type, mark_id, status)
	status = clamp_status(status)
	local def = VANILLA_BY_ID[mark_id]
	if not def then return status end
	if REPENTOGON and Isaac.SetCompletionMark then
		if def.greed then
			Isaac.SetCompletionMark(player_type, CompletionType.ULTRA_GREED, status >= 1 and (status >= 2 and 2 or 1) or 0)
			if CompletionType.ULTRA_GREEDIER then
				Isaac.SetCompletionMark(player_type, CompletionType.ULTRA_GREEDIER, status >= 2 and 2 or 0)
			end
		else
			Isaac.SetCompletionMark(player_type, def.completion_type, status)
		end
		return status
	end
	return status
end

local function get_vanilla_status(player_type, mark_id)
	if not VANILLA_BY_ID[mark_id] then return 0 end
	local char = manager.characters_by_type[player_type]
	if not char then return 0 end
	return clamp_status(vanilla_bucket(char.key)[mark_id])
end

local function set_vanilla_status(player_type, mark_id, status)
	status = clamp_status(status)
	if not VANILLA_BY_ID[mark_id] then return status end
	local char = manager.characters_by_type[player_type]
	if not char then return status end
	vanilla_bucket(char.key)[mark_id] = status
	set_rgon_status(player_type, mark_id, status)
	return status
end

local function get_extra_status(player_type, mark_id)
	local def = manager.extra_marks[mark_id]
	if not def then return 0 end
	if def.get_status then
		return clamp_status(def.get_status(player_type))
	end
	local key = manager.extra_character_key(player_type)
	if not key then return 0 end
	return clamp_status(extra_bucket(mark_id)[key])
end

local function set_extra_status(player_type, mark_id, status, context)
	status = clamp_status(status)
	local def = manager.extra_marks[mark_id]
	if not def then return status end
	if def.set_status then
		def.set_status(player_type, status, context)
		return status
	end
	local key = manager.extra_character_key(player_type)
	if not key then return status end
	extra_bucket(mark_id)[key] = status
	return status
end

function manager.get_status(player_type, mark_id)
	if VANILLA_BY_ID[mark_id] then return get_vanilla_status(player_type, mark_id) end
	if manager.extra_marks[mark_id] then return get_extra_status(player_type, mark_id) end
	if mark_id == "FullCompletion" then
		local char = manager.characters_by_type[player_type]
		local data = char and auxi.check_if_any(char.legacy_save)
		return legacy_unlock_status(data and data.FullCompletion)
	end
	return 0
end

function manager.set_status(player_type, mark_id, status, context)
	status = clamp_status(status)
	if VANILLA_BY_ID[mark_id] then
		local result = set_vanilla_status(player_type, mark_id, status)
		if not manager.migrating then persist() end
		return result
	end
	if manager.extra_marks[mark_id] then
		local result = set_extra_status(player_type, mark_id, status, context)
		persist()
		return result
	end
	if mark_id == "FullCompletion" then
		local char = manager.characters_by_type[player_type]
		local data = char and auxi.check_if_any(char.legacy_save)
		if data then
			data.FullCompletion = data.FullCompletion or {Unlock = false, Hard = false}
			write_legacy_unlock(data.FullCompletion, status)
			persist()
		end
		return status
	end
	return 0
end

function manager.get_marks(player_type, scope)
	scope = scope or "all"
	local marks = {player_type = player_type, vanilla = {}, extra = {}}
	if scope == "all" or scope == "vanilla" then
		for _,def in ipairs(VANILLA_MARKS) do
			marks.vanilla[def.id] = manager.get_status(player_type, def.id)
			marks[def.id] = marks.vanilla[def.id]
		end
		marks.FullCompletion = manager.get_status(player_type, "FullCompletion")
	end
	if scope == "all" or scope == "extra" then
		for _,def in ipairs(manager.extra_marks_sorted) do
			marks.extra[def.id] = manager.get_status(player_type, def.id)
		end
	end
	return marks
end

function manager.widget_layers(player_type)
	local marks = manager.get_marks(player_type, "vanilla")
	local layers = {}
	for mark_id, layer in pairs(WIDGET_LAYERS) do
		layers[layer] = marks[mark_id] or 0
	end
	return layers
end

function manager.legacy_boss_field_status(mark_id, legacy_key, field)
	local character_key = extra_key_from_legacy(legacy_key, field)
	local extra = extra_bucket(mark_id)
	local status = clamp_status(extra[character_key])
	if field == "Hard" or field == "TaintedHard" then return status >= 2 end
	return status >= 1
end

function manager.set_legacy_boss_field(mark_id, legacy_key, field, value)
	local character_key = extra_key_from_legacy(legacy_key, field)
	local extra = extra_bucket(mark_id)
	local current = clamp_status(extra[character_key])
	local status = current
	if field == "Hard" or field == "TaintedHard" then
		if value == true then status = 2
		elseif current >= 2 then status = 1
		end
	else
		if value == true then
			if current < 1 then status = 1 end
		else
			status = 0
		end
	end
	extra[character_key] = status
	persist()
	return status
end

function manager.is_requirement_unlocked(category, mark, field)
	if category == "Glaze" or category == "BossZeis" then
		local mark_id = category == "BossZeis" and "boss.zeis" or "boss.glaze"
		return manager.legacy_boss_field_status(mark_id, mark, field)
	end
	local char = manager.characters_by_key[category]
	if char then
		local status = manager.get_status(char.player_type, mark)
		if field == "Hard" then return status >= 2 end
		return status >= 1
	end
	local record = save.UnlockData and save.UnlockData[category] and save.UnlockData[category][mark]
	return record and record[field] == true or false
end

local function grant_character_rewards(player_type, mark_id, status, prev)
	local char = manager.characters_by_type[player_type]
	local item = tracker()
	if not char or not item or not item.GrantRewards then return end
	if status >= 1 and prev < 1 then item.GrantRewards(char.key, mark_id, "Unlock") end
	if mark_id == "GreedMode" and status >= 2 and prev < 2 then
		item.GrantRewards(char.key, "GreedMode", "Hard")
	end
end

local function grant_extra_rewards(player_type, mark_id, status, prev)
	local def = manager.extra_marks[mark_id]
	local extra = manager.extra_characters_by_type[player_type]
	local item = tracker()
	if not def or not extra or not item or not item.GrantRewards then return end
	local category = def.reward_category
	if not category then return end
	local field_normal = extra.legacy_boss_field or "Unlock"
	local field_hard = field_normal == "Tainted" and "TaintedHard" or "Hard"
	if status >= 1 and prev < 1 then item.GrantRewards(category, extra.legacy_boss_key, field_normal) end
	if status >= 2 and prev < 2 then item.GrantRewards(category, extra.legacy_boss_key, field_hard) end
end

local function note_seen(player_type, mark_id, status)
	seen_bucket(player_type)[mark_id] = clamp_status(status)
end

vanilla_bucket = function(character_key)
	local store = ensure_store()
	store.vanilla[character_key] = store.vanilla[character_key] or {}
	return store.vanilla[character_key]
end

local function pending_bucket(player_type)
	local store = ensure_store()
	local char = manager.characters_by_type[player_type]
	local key = char and char.key
	if not key then return nil end
	store.pending_rewards[key] = store.pending_rewards[key] or {}
	return store.pending_rewards[key]
end

local function queue_pending_reward(player_type, mark_id, status)
	local bucket = pending_bucket(player_type)
	if not bucket then return end
	bucket[mark_id] = math.max(clamp_status(bucket[mark_id]), clamp_status(status))
	persist()
end

local function clear_pending_reward(player_type, mark_id)
	local store = ensure_store()
	local char = manager.characters_by_type[player_type]
	local key = char and char.key
	if not key then return end
	local bucket = store.pending_rewards[key]
	if not bucket then return end
	bucket[mark_id] = nil
	if next(bucket) == nil then store.pending_rewards[key] = nil end
end

local function grant_or_queue_character_rewards(player_type, mark_id, status, prev)
	if not achievements_allowed() then
		queue_pending_reward(player_type, mark_id, status)
		return false
	end
	grant_character_rewards(player_type, mark_id, status, prev)
	clear_pending_reward(player_type, mark_id)
	return true
end

function manager.complete_extra(mark_id, player_type, status)
	local def = manager.extra_marks[mark_id]
	if not def or not valid_player_type(player_type) then return false end
	if not auxi.is_normal_game() then return false end
	if not achievements_allowed() then return false end
	if not def.get_status and not manager.extra_character_key(player_type) then return false end
	status = clamp_status(status)
	local prev = manager.get_status(player_type, mark_id)
	if status <= prev then return false end
	manager.set_status(player_type, mark_id, status, {source = "complete_extra"})
	grant_extra_rewards(player_type, mark_id, status, prev)
	note_seen(player_type, mark_id, status)
	local resolver = manager.rewards[mark_id]
	if resolver then resolver(player_type, status, prev) end
	return true
end

function manager.complete_extra_all_players(mark_id)
	if not auxi.is_normal_game() then return false end
	local hard = Game().Difficulty == Difficulty.DIFFICULTY_HARD
	local status = hard and 2 or 1
	local changed = false
	for player_num = 0, Game():GetNumPlayers() - 1 do
		if manager.complete_extra(mark_id, Game():GetPlayer(player_num):GetPlayerType(), status) then
			changed = true
		end
	end
	return changed
end

local function on_vanilla_mark_get(completion_type, player_type)
	if manager.migrating or manager.completing_vanilla then return end
	if not auxi.is_normal_game() then return end
	local mark_id = COMPLETION_TO_MARK[completion_type]
	if not mark_id then return end
	local placeholder = manager.pause_placeholder or ensure_store().pause_placeholder_recovery
	if type(placeholder) == "table"
	and placeholder.character_key == manager.extra_character_key(player_type)
	and (placeholder.mark_id or PLACEHOLDER_MARK_ID) == mark_id then
		return
	end
	if not manager.characters_by_type[player_type] then return end
	local rgon_status = get_rgon_status(player_type, mark_id)
	local local_status = manager.get_status(player_type, mark_id)
	local status = math.max(local_status, rgon_status)
	if status ~= local_status then
		local char = manager.characters_by_type[player_type]
		vanilla_bucket(char.key)[mark_id] = status
		persist()
	end
	if status ~= rgon_status then
		manager.completing_vanilla = true
		set_rgon_status(player_type, mark_id, status)
		manager.completing_vanilla = false
	end
	local prev = seen_bucket(player_type)[mark_id]
	if prev == nil then prev = 0 end
	if status <= prev then
		note_seen(player_type, mark_id, math.max(status, prev))
		return
	end
	grant_or_queue_character_rewards(player_type, mark_id, status, prev)
	note_seen(player_type, mark_id, status)
	local resolver = manager.rewards[mark_id]
	if resolver then resolver(player_type, status, prev) end
end

--- 旧房间扫描的统一入口：RGON 下写 Isaac API；非 RGON 回退 legacy save。
function manager.complete_vanilla(player_type, mark_id, status)
	if not valid_player_type(player_type) or not VANILLA_BY_ID[mark_id] then return false end
	if not auxi.is_normal_game() or not achievements_allowed() then return false end
	local prev = manager.get_status(player_type, mark_id)
	status = clamp_status(status)
	if status <= prev then return false end
	manager.completing_vanilla = true
	manager.set_status(player_type, mark_id, status)
	manager.completing_vanilla = false
	local actual = manager.get_status(player_type, mark_id)
	if actual <= prev then return false end
	grant_or_queue_character_rewards(player_type, mark_id, actual, prev)
	note_seen(player_type, mark_id, actual)
	local resolver = manager.rewards[mark_id]
	if resolver then resolver(player_type, actual, prev) end
	return true
end

local function flush_pending_rewards()
	if not achievements_allowed() then return false end
	local store = ensure_store()
	local changed = false
	for player_key, marks in pairs(store.pending_rewards) do
		local char = manager.characters_by_key[player_key]
		local player_type = char and char.player_type
		if player_type then
			for mark_id, queued_status in pairs(marks) do
				local status = math.min(manager.get_status(player_type, mark_id), clamp_status(queued_status))
				if status > 0 then
					grant_character_rewards(player_type, mark_id, status, 0)
					marks[mark_id] = nil
					changed = true
				end
			end
		end
		if not char and tonumber(player_key) then
			-- Runtime PlayerType is not a durable identity. V1 numeric queues cannot
			-- be attributed safely after mod-order changes, so never award them.
			store.pending_rewards[player_key] = nil
			changed = true
		end
		if next(marks) == nil then store.pending_rewards[player_key] = nil end
	end
	if changed then persist() end
	return changed
end

local function snapshot_seen(player_type)
	local bucket = seen_bucket(player_type)
	for _,def in ipairs(VANILLA_MARKS) do
		bucket[def.id] = manager.get_status(player_type, def.id)
	end
	for _,def in ipairs(manager.extra_marks_sorted) do
		bucket[def.id] = manager.get_status(player_type, def.id)
	end
end

local function audit_and_sync_vanilla()
	manager.last_audit = {}
	local changed = false
	local was_migrating = manager.migrating
	manager.migrating = true
	for _,char in ipairs(manager.characters) do
		local local_marks = vanilla_bucket(char.key)
		local legacy = auxi.check_if_any(char.legacy_save)
		local report = {key = char.key, player_type = char.player_type, marks = {}, mismatches = 0}
		for _,def in ipairs(VANILLA_MARKS) do
			local had_local_value = local_marks[def.id] ~= nil
			local local_status = clamp_status(local_marks[def.id])
			local rgon_status = get_rgon_status(char.player_type, def.id)
			local placeholder = manager.pause_placeholder or ensure_store().pause_placeholder_recovery
			if type(placeholder) == "table"
			and placeholder.character_key == char.key
			and (placeholder.mark_id or PLACEHOLDER_MARK_ID) == def.id then
				rgon_status = clamp_status(placeholder.previous_status)
			end
			-- A missing V2 field means this mark was never migrated. Seed it once
			-- from legacy/RGON. Explicit numeric 0 remains an intentional lock and
			-- is not resurrected from stale legacy UnlockData.
			local legacy_status = had_local_value and 0 or legacy_unlock_status(type(legacy) == "table" and legacy[def.id])
			local target = math.max(local_status, rgon_status, legacy_status)
			local action = "equal"
			if local_status < target then
				local_marks[def.id] = target
				action = "rgon_to_local"
				changed = true
			elseif rgon_status < target then
				set_rgon_status(char.player_type, def.id, target)
				action = "local_to_rgon"
			end
			if action ~= "equal" then report.mismatches = report.mismatches + 1 end
			report.marks[def.id] = {local_status = local_status, rgon_status = rgon_status, legacy_status = legacy_status, result = target, action = action}
		end
		manager.last_audit[char.key] = report
	end
	manager.migrating = was_migrating
	if changed then persist() end
	return manager.last_audit
end

function manager.audit_and_sync()
	return audit_and_sync_vanilla()
end

function manager.get_last_audit()
	return manager.last_audit
end

function manager.migrate_legacy_once()
	if manager.migrated then return false end
	local store = ensure_store()
	if store.migrate_version and store.migrate_version >= MIGRATE_VERSION then
		manager.migrated = true
		for _,char in ipairs(manager.characters) do snapshot_seen(char.player_type) end
		return false
	end
	manager.migrating = true
	for _,char in ipairs(manager.characters) do
		local data = auxi.check_if_any(char.legacy_save)
		for _,def in ipairs(VANILLA_MARKS) do
			local local_status = manager.get_status(char.player_type, def.id)
			local legacy = legacy_unlock_status(type(data) == "table" and data[def.id])
			local rgon_status = get_rgon_status(char.player_type, def.id)
			set_vanilla_status(char.player_type, def.id, math.max(local_status, legacy, rgon_status))
		end
		snapshot_seen(char.player_type)
	end
	local function migrate_boss(legacy_category, mark_id)
		local source = save.UnlockData and save.UnlockData[legacy_category]
		if type(source) ~= "table" then return end
		local extra = extra_bucket(mark_id)
		for legacy_key, record in pairs(source) do
			if type(record) == "table" then
				local normal_key = extra_key_from_legacy(legacy_key, "Unlock")
				local tainted_key = extra_key_from_legacy(legacy_key, "Tainted")
				local normal = 0
				if record.Hard == true then normal = 2 elseif record.Unlock == true then normal = 1 end
				local tainted = 0
				if record.TaintedHard == true then tainted = 2 elseif record.Tainted == true then tainted = 1 end
				if normal > clamp_status(extra[normal_key]) then extra[normal_key] = normal end
				if tainted_key ~= normal_key and tainted > clamp_status(extra[tainted_key]) then extra[tainted_key] = tainted end
			end
		end
	end
	migrate_boss("Glaze", "boss.glaze")
	migrate_boss("BossZeis", "boss.zeis")
	store.migrate_version = MIGRATE_VERSION
	manager.migrating = false
	manager.migrated = true
	persist()
	audit_and_sync_vanilla()
	return true
end

function manager.unlock_all()
	manager.migrating = true
	for _,char in ipairs(manager.characters) do
		for _,def in ipairs(VANILLA_MARKS) do
			manager.set_status(char.player_type, def.id, 2)
		end
		manager.set_status(char.player_type, "FullCompletion", 2)
		snapshot_seen(char.player_type)
	end
	for _,mark in ipairs(manager.extra_marks_sorted) do
		local extra = extra_bucket(mark.id)
		for _,char in ipairs(manager.extra_characters) do
			extra[char.key] = 2
		end
	end
	manager.migrating = false
	persist()
end

function manager.lock_all()
	manager.migrating = true
	for _,char in ipairs(manager.characters) do
		for _,def in ipairs(VANILLA_MARKS) do
			manager.set_status(char.player_type, def.id, 0)
		end
		manager.set_status(char.player_type, "FullCompletion", 0)
		snapshot_seen(char.player_type)
	end
	for _,mark in ipairs(manager.extra_marks_sorted) do
		local extra = extra_bucket(mark.id)
		for _,char in ipairs(manager.extra_characters) do
			extra[char.key] = 0
		end
	end
	manager.migrating = false
	persist()
end

local function apply_widget_layers(sprite, player_type)
	local layers = manager.widget_layers(player_type)
	for layer, frame in pairs(layers) do
		sprite:SetLayerFrame(layer, frame)
	end
end

local function render_postit(context, sprite)
	-- Never render the callback-owned RGON Sprite from inside its own PRE
	-- callback. It is mid-render and its sheets/state belong to RGON. We only
	-- consume RGON's position, scale and PlayerType, then draw our own Sprite.
	pcall(function()
		sprite = sprite or postit_sprite()
		apply_widget_layers(sprite, context.player_type)
		local pos = context.position + layout_adapter_offset()
		local backup = sprite.Scale
		if context.scale then sprite.Scale = context.scale end
		sprite:Render(pos, Vector(0, 0), Vector(0, 0))
		sprite.Scale = backup
	end)
end

local function render_extra_marks(context)
	local scale = context.scale or Vector(1, 1)
	local origin = context.position + extra_mark_offset(scale, context.surface)
	local step = context.surface == "character" and Vector(20 * scale.X, 0) or Vector(0, 18 * scale.Y)
	local drawn = 0
	for _, def in ipairs(manager.extra_marks_sorted) do
		local status = manager.get_status(context.player_type, def.id)
		if status > 0 then
			local sprite = extra_sprite(def)
			local anim = status >= 2 and (def.hard_anim or def.normal_anim or "Skull") or (def.normal_anim or "Smiley")
			sprite.Scale = scale
			pcall(function()
				sprite:Play(anim, true)
				sprite:SetFrame(status >= 2 and 2 or 1)
			end)
			local pos = origin + Vector(step.X * drawn, step.Y * drawn)
			sprite:Render(pos, Vector(0, 0), Vector(0, 0))
			drawn = drawn + 1
		end
	end
end

manager.register_renderer("qing_postit", render_postit)
manager.register_renderer("qing_menu_marks", function(context)
	if character_draw_postit() ~= true then return end
	local origin = context.position
	context.position = origin + character_postit_offset()
	render_postit(context, character_postit_sprite())
	context.position = origin
end)

function manager.render(context)
	if Isaac.GetChallenge() > 0 then return end
	if not context or not valid_player_type(context.player_type) then return end
	local char = manager.characters_by_type[context.player_type]
	if char and char.replace_vanilla then
		local renderer_name = context.surface == "character" and char.character_renderer or char.pause_renderer
		local renderer = manager.renderers[renderer_name] or render_postit
		renderer(context)
	end
	if context.surface ~= "character" then
		render_extra_marks(context)
	end
end

local function register_mod_character(player_type, key, opts)
	if not valid_player_type(player_type) then return end
	opts = opts or {}
	manager.register_character({
		player_type = player_type,
		key = key,
		legacy_save = function() return save.UnlockData[opts.legacy_save_key or key] end,
		replace_vanilla = opts.replace_vanilla ~= false,
		pause_renderer = "qing_postit",
		character_renderer = "qing_menu_marks",
		legacy_boss_key = opts.legacy_boss_key or key,
		legacy_boss_field = opts.legacy_boss_field or "Unlock",
		boss_row = opts.boss_row,
	})
end

local function register_vanilla_extra(player_type, key, legacy_key, field, boss_row)
	if not valid_player_type(player_type) then return end
	manager.register_extra_character({
		player_type = player_type,
		key = key,
		legacy_boss_key = legacy_key,
		legacy_boss_field = field or "Unlock",
		boss_row = boss_row or boss_row_for_key(key),
	})
end

register_mod_character(enums.Players.wq, "wq")
register_mod_character(enums.Players.Spwq, "Spwq", {legacy_boss_key = "wq", legacy_boss_field = "Tainted", boss_row = "wq_B"})
register_mod_character(enums.Players.Tecro, "Tecro")
register_mod_character(enums.Players.Tecrorun, "Tecrorun", {legacy_boss_key = "Tecro", legacy_boss_field = "Tainted", boss_row = "Tecro_B"})
register_mod_character(enums.Players.Anna, "Anna")
register_mod_character(enums.Players.annA, "annA", {legacy_boss_key = "Anna", legacy_boss_field = "Tainted", boss_row = "Anna_B"})
register_mod_character(enums.Players.Zeistos, "Zeis")
register_mod_character(enums.Players.Zeiz, "Zeiz", {legacy_boss_key = "Zeis", legacy_boss_field = "Tainted", boss_row = "Zeis_B"})
register_mod_character(enums.Players.Marriano, "Marriano")

register_vanilla_extra(PlayerType.PLAYER_ISAAC, "Isaac", "Isaac", "Unlock", "Isaac")
register_vanilla_extra(PlayerType.PLAYER_ISAAC_B, "Isaac_B", "Isaac", "Tainted", "Isaac_B")
register_vanilla_extra(PlayerType.PLAYER_MAGDALENA, "Maggy", "Maggy", "Unlock", "Magdalene")
register_vanilla_extra(PlayerType.PLAYER_MAGDALENA_B, "Maggy_B", "Maggy", "Tainted", "Magdalene_B")
register_vanilla_extra(PlayerType.PLAYER_CAIN, "Cain", "Cain", "Unlock", "Cain")
register_vanilla_extra(PlayerType.PLAYER_CAIN_B, "Cain_B", "Cain", "Tainted", "Cain_B")
register_vanilla_extra(PlayerType.PLAYER_JUDAS, "Judas", "Judas", "Unlock", "Judas")
register_vanilla_extra(PlayerType.PLAYER_JUDAS_B, "Judas_B", "Judas", "Tainted", "Judas_B")
register_vanilla_extra(PlayerType.PLAYER_XXX, "BlueBaby", "BlueBaby", "Unlock", "BlueBaby")
register_vanilla_extra(PlayerType.PLAYER_XXX_B, "BlueBaby_B", "BlueBaby", "Tainted", "BlueBaby_B")
register_vanilla_extra(PlayerType.PLAYER_EVE, "Eve", "Eve", "Unlock", "Eve")
register_vanilla_extra(PlayerType.PLAYER_EVE_B, "Eve_B", "Eve", "Tainted", "Eve_B")
register_vanilla_extra(PlayerType.PLAYER_SAMSON, "Samson", "Samson", "Unlock", "Samson")
register_vanilla_extra(PlayerType.PLAYER_SAMSON_B, "Samson_B", "Samson", "Tainted", "Samson_B")
register_vanilla_extra(PlayerType.PLAYER_AZAZEL, "Azazel", "Azazel", "Unlock", "Azazel")
register_vanilla_extra(PlayerType.PLAYER_AZAZEL_B, "Azazel_B", "Azazel", "Tainted", "Azazel_B")
register_vanilla_extra(PlayerType.PLAYER_LAZARUS, "Lazarus", "Lazarus", "Unlock", "Lazarus")
register_vanilla_extra(PlayerType.PLAYER_LAZARUS_B, "Lazarus_B", "Lazarus", "Tainted", "Lazarus_B")
register_vanilla_extra(PlayerType.PLAYER_LAZARUS2_B, "Lazarus_B", "Lazarus", "Tainted", "Lazarus_B")
register_vanilla_extra(PlayerType.PLAYER_EDEN, "Eden", "Eden", "Unlock", "Eden")
register_vanilla_extra(PlayerType.PLAYER_EDEN_B, "Eden_B", "Eden", "Tainted", "Eden_B")
register_vanilla_extra(PlayerType.PLAYER_THELOST, "Lost", "Lost", "Unlock", "Lost")
register_vanilla_extra(PlayerType.PLAYER_THELOST_B, "Lost_B", "Lost", "Tainted", "Lost_B")
register_vanilla_extra(PlayerType.PLAYER_LILITH, "Lilith", "Lilith", "Unlock", "Lilith")
register_vanilla_extra(PlayerType.PLAYER_LILITH_B, "Lilith_B", "Lilith", "Tainted", "Lilith_B")
register_vanilla_extra(PlayerType.PLAYER_KEEPER, "Keeper", "Keeper", "Unlock", "Keeper")
register_vanilla_extra(PlayerType.PLAYER_KEEPER_B, "Keeper_B", "Keeper", "Tainted", "Keeper_B")
register_vanilla_extra(PlayerType.PLAYER_APOLLYON, "Apollyon", "Apollyon", "Unlock", "Apollyon")
register_vanilla_extra(PlayerType.PLAYER_APOLLYON_B, "Apollyon_B", "Apollyon", "Tainted", "Apollyon_B")
register_vanilla_extra(PlayerType.PLAYER_THEFORGOTTEN, "Forgotten", "Forgotten", "Unlock", "Forgotten")
register_vanilla_extra(PlayerType.PLAYER_THESOUL, "Forgotten", "Forgotten", "Unlock", "Forgotten")
register_vanilla_extra(PlayerType.PLAYER_THEFORGOTTEN_B, "Forgotten_B", "Forgotten", "Tainted", "Forgotten_B")
register_vanilla_extra(PlayerType.PLAYER_THESOUL_B, "Forgotten_B", "Forgotten", "Tainted", "Forgotten_B")
register_vanilla_extra(PlayerType.PLAYER_BETHANY, "Bethany", "Bethany", "Unlock", "Bethany")
register_vanilla_extra(PlayerType.PLAYER_BETHANY_B, "Bethany_B", "Bethany", "Tainted", "Bethany_B")
register_vanilla_extra(PlayerType.PLAYER_JACOB, "Jacob_and_Esau", "Jacob_and_Esau", "Unlock", "JacobEsau")
register_vanilla_extra(PlayerType.PLAYER_ESAU, "Jacob_and_Esau", "Jacob_and_Esau", "Unlock", "JacobEsau")
register_vanilla_extra(PlayerType.PLAYER_JACOB_B, "Jacob_and_Esau_B", "Jacob_and_Esau", "Tainted", "Jacob_B")

manager.register_extra_mark({
	id = "boss.glaze",
	order = 100,
	reward_category = "Glaze",
	anm2 = "gfx/ui/pause screen completion marks/sample_marks.anm2",
	normal_anim = "Smiley",
	hard_anim = "Eye",
	rewards = {normal = "GlazeNormal", hard = "GlazeHard"},
})

manager.register_extra_mark({
	id = "boss.zeis",
	order = 110,
	reward_category = "BossZeis",
	anm2 = "gfx/ui/pause screen completion marks/sample_marks.anm2",
	normal_anim = "Skull",
	hard_anim = "Skull",
	rewards = {normal = "ZeisNormal", hard = "ZeisHard"},
})

local function render_context(sprite, render_pos, render_scale, player_type)
	return {
		surface = detect_surface(player_type),
		player_type = player_type,
		position = render_pos,
		scale = render_scale,
		sprite = sprite,
	}
end

local function restore_pause_placeholder()
	local placeholder = manager.pause_placeholder
	local store = ensure_store()
	local recovery = placeholder or store.pause_placeholder_recovery
	if type(recovery) ~= "table" then return false end
	local player_type = manager.player_type_from_key(recovery.character_key)
	if valid_player_type(player_type) then
		manager.completing_vanilla = true
		set_rgon_status(player_type, recovery.mark_id or PLACEHOLDER_MARK_ID, recovery.previous_status or 0)
		manager.completing_vanilla = false
	end
	manager.pause_placeholder = nil
	store.pause_placeholder_recovery = nil
	persist()
	return true
end

local function ensure_pause_placeholder(player_type)
	if manager.pause_placeholder then return true end
	local char = manager.characters_by_type[player_type]
	if not (char and char.replace_vanilla) then return false end
	for _,def in ipairs(VANILLA_MARKS) do
		if get_rgon_status(player_type, def.id) > 0 then return false end
	end
	local store = ensure_store()
	local recovery = {character_key = char.key, mark_id = PLACEHOLDER_MARK_ID, previous_status = 0}
	-- Persist recovery before touching RGON so a crash cannot strand the mark.
	store.pause_placeholder_recovery = recovery
	persist()
	manager.pause_placeholder = recovery
	manager.completing_vanilla = true
	set_rgon_status(player_type, PLACEHOLDER_MARK_ID, 1)
	manager.completing_vanilla = false
	return true
end

if REPENTOGON then
	-- RGON does not instantiate CompletionWidget for an all-zero mark set. While
	-- pause is open, write a recoverable placeholder solely to make RGON create
	-- its correctly anchored widget; our PRE renderer still applies local zeros.
	table.insert(manager.ToCall, #manager.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
	Function = function()
		if not manager.in_run or not (PauseMenu and PauseMenu.GetState) then
			restore_pause_placeholder()
			return
		end
		local ok, state = pcall(PauseMenu.GetState)
		if not ok or state ~= PauseMenuStates.OPEN then
			restore_pause_placeholder()
			return
		end
		local player = Game():GetPlayer(0)
		if not player then restore_pause_placeholder() return end
		ensure_pause_placeholder(player:GetPlayerType())
	end,
	})

	table.insert(manager.ToCall, #manager.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
	Function = function()
		manager.in_run = true
		manager.character_page_render_type = nil
	end,
	})

	table.insert(manager.ToCall, #manager.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
	Function = function()
		restore_pause_placeholder()
		manager.in_run = false
		manager.character_page_render_type = nil
	end,
	})

	table.insert(manager.ToCall, #manager.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_END, params = nil,
	Function = function()
		restore_pause_placeholder()
		manager.in_run = false
		manager.character_page_render_type = nil
	end,
	})

	-- Character page PRE/POST form a strict render scope around its child
	-- completion-widget render. This is the reliable way to distinguish it
	-- from the pause menu; menu states and Sprite userdata identity are not.
	table.insert(manager.ToCall, #manager.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_RENDER_CHARACTER_SELECT_PAGE, params = nil,
	Function = function(_, player_type)
		manager.character_page_render_type = player_type
	end,
	})

	table.insert(manager.ToCall, #manager.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER_CHARACTER_SELECT_PAGE, params = nil,
	Function = function(_, player_type)
		if manager.character_page_render_type == player_type then
			manager.character_page_render_type = nil
		end
	end,
	})

	-- RGON CompletionWidget::Render：PRE 返回任意 boolean 都会跳过 super 和 POST。
	-- replace_vanilla 必须在 PRE 里先画完，再 return false。
	table.insert(manager.ToCall, #manager.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_COMPLETION_MARKS_RENDER, params = nil,
	Function = function(_, sprite, render_pos, render_scale, player_type)
		local char = manager.characters_by_type[player_type]
		if not (char and char.replace_vanilla) then return end
		local context = render_context(sprite, render_pos, render_scale, player_type)
		-- Character select already has per-character custom paper art. Cancel only
		-- RGON's completion widget there; the pause menu must always keep its note.
		if context.surface == "character" then
			-- Keep the optional alignment probe, but default character-select
			-- behavior is cancellation only because its paper is custom artwork.
			if character_draw_postit() then manager.render(context) end
			return false
		end
		manager.render(context)
		return false
	end,
	})

	table.insert(manager.ToCall, #manager.ToCall + 1, {CallBack = ModCallbacks.MC_POST_COMPLETION_MARKS_RENDER, params = nil,
	Function = function(_, sprite, render_pos, render_scale, player_type)
		local context = render_context(sprite, render_pos, render_scale, player_type)
		if context.surface ~= "pause" then return end
		render_extra_marks(context)
	end,
	})

	table.insert(manager.ToCall, #manager.ToCall + 1, {CallBack = ModCallbacks.MC_POST_COMPLETION_MARK_GET, params = nil,
	Function = function(_, completion_type, player_type)
		on_vanilla_mark_get(completion_type, player_type)
	end,
	})
end

table.insert(manager.myToCall, #manager.myToCall + 1, {CallBack = enums.Callbacks.POST_PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	-- Recover a placeholder left by an abnormal previous shutdown before any
	-- max-merge audit can mistake it for real progression.
	restore_pause_placeholder()
	manager.migrate_legacy_once()
	audit_and_sync_vanilla()
	flush_pending_rewards()
	for _,char in ipairs(manager.characters) do snapshot_seen(char.player_type) end
end,
})

function manager.use_legacy_tracker()
	return legacy_tracker_enabled()
end

return manager

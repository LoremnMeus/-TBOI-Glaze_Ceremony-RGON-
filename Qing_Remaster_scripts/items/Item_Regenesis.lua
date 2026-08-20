local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Regenesis,
	own_key = "Item_Regenesis_",
	skip_settle = false,
}

local CENTURIES = {
	"Prosperity",
	"War",
	"Abundance",
	"Technology",
	"Faith",
	"Ruin",
}

local NAMES = {
	zh = {
		Prosperity = "繁荣世纪",
		War = "战争世纪",
		Abundance = "丰饶世纪",
		Technology = "技术世纪",
		Faith = "信仰世纪",
		Ruin = "废墟世纪",
	},
	en = {
		Prosperity = "Age of Prosperity",
		War = "Age of War",
		Abundance = "Age of Abundance",
		Technology = "Age of Technology",
		Faith = "Age of Faith",
		Ruin = "Age of Ruin",
	},
}

local EID_SUMMARY = {
	zh = {
		Prosperity = "#{{Coin}} 商业更加繁荣，但商品也更加昂贵",
		War = "#{{Damage}} 战斗能力与战备资源增强，但敌人也更加武装",
		Abundance = "#{{Heart}} 生命资源大量增加，但会挤占其他基础资源",
		Technology = "#{{Battery}} 充能与人工设施更加发达，但天然资源减少",
		Faith = "#{{DevilRoom}} {{AngelRoom}} 超自然力量更加活跃，但下一世必须坚定选择一方",
		Ruin = "#{{TreasureRoom}} 下一世从丰富的重建物资开始，但高级设施更加稀少",
	},
	en = {
		Prosperity = "#{{Coin}} Shops grow larger, but prices rise",
		War = "#{{Damage}} Combat power and supplies grow, but enemies arm up",
		Abundance = "#{{Heart}} Hearts become plentiful, crowding out other drops",
		Technology = "#{{Battery}} Charge and machines flourish, but natural supplies dwindle",
		Faith = "#{{DevilRoom}} {{AngelRoom}} Deals become common, but the next life must pick a side",
		Ruin = "#{{TreasureRoom}} The next life starts with salvage, but advanced facilities stay scarce",
	},
}

local empty_scores = function()
	return {
		Prosperity = 0,
		War = 0,
		Abundance = 0,
		Technology = 0,
		Faith = 0,
		Ruin = 0,
	}
end

local function mix32(n)
	n = math.floor(tonumber(n) or 1) % 4294967296
	n = n ~ math.floor(n / 65536)
	n = (n * 2246822519) % 4294967296
	n = n ~ math.floor(n / 8192)
	n = (n * 3266489917) % 4294967296
	n = n ~ math.floor(n / 16)
	if n == 0 then n = 1 end
	return n
end

local function century_rng(salt)
	local rng = RNG()
	local seed = mix32((Game():GetSeeds():GetStartSeed() + (salt or 0)) % 4294967296)
	rng:SetSeed(seed, 35)
	return auxi.rng_for_sake(rng) or rng
end

local function lang_pack()
	local language = auxi.get_EID_language()
	if language and string.sub(tostring(language), 1, 2) == "zh" then return "zh" end
	return "en"
end

local function century_name(key)
	local pack = NAMES[lang_pack()] or NAMES.en
	return pack[key] or key
end

local function get_permanent()
	save.PermanentData = save.PermanentData or {}
	local key = item.own_key.."legacy"
	if type(save.PermanentData[key]) ~= "table" then
		save.PermanentData[key] = {Century = nil, Pending = false}
	end
	return save.PermanentData[key]
end

local function get_run()
	save.elses = save.elses or {}
	local key = item.own_key.."run"
	local run = save.elses[key]
	if type(run) ~= "table" then
		run = {
			Scores = empty_scores(),
			Caps = {},
			Flags = {},
			CurrentCandidate = nil,
			LastHint = nil,
			AcquiredStage = nil,
			Recording = false,
			EverHeld = false,
			ActiveCentury = nil,
			Applied = false,
			FaithPath = "NONE",
			TechClears = 0,
			Settled = false,
			RuinStreak = 0,
			CoinGained = 0,
			FullHealthClears = 0,
		}
		save.elses[key] = run
	end
	run.Scores = run.Scores or empty_scores()
	run.Caps = run.Caps or {}
	run.Flags = run.Flags or {}
	for _, key_name in ipairs(CENTURIES) do
		run.Scores[key_name] = tonumber(run.Scores[key_name]) or 0
	end
	return run
end

local function any_holder()
	if not Game() then return nil end
	for player_num = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		if player and auxi.has_have_coll(player, item.entity) then return player end
	end
end

local function is_recording()
	local run = get_run()
	return run.Recording == true and any_holder() ~= nil
end

local function is_active_charge_slot(slot)
	slot = tonumber(slot)
	if not slot then return false end
	return slot >= ActiveSlot.SLOT_PRIMARY and slot <= ActiveSlot.SLOT_POCKET
end

local function current_stage()
	local level = Game():GetLevel()
	if not level then return 1 end
	if level.GetAbsoluteStage then return level:GetAbsoluteStage() end
	return level:GetStage() or 1
end

local function formation_threshold(run)
	run = run or get_run()
	local stage = tonumber(run.AcquiredStage) or 1
	if stage <= 2 then return 100 end
	if stage <= 4 then return 80 end
	if stage <= 6 then return 65 end
	return 50
end

local function ranked_scores(run)
	run = run or get_run()
	local list = {}
	for _, key in ipairs(CENTURIES) do
		list[#list + 1] = {key = key, score = tonumber(run.Scores[key]) or 0}
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.key < b.key
	end)
	return list
end

local function leading_century(min_score, ratio, run)
	run = run or get_run()
	local list = ranked_scores(run)
	local first = list[1]
	local second = list[2]
	if not first or first.score < (min_score or 0) then return nil, list end
	local need = (second and second.score or 0) * (ratio or 1.20)
	if first.score + 0.0001 < need then return nil, list end
	return first.key, list
end

local function add_score(key, amount, cap_key, cap)
	if amount == nil or amount == 0 then return 0 end
	if not is_recording() then return 0 end
	local run = get_run()
	if cap_key and cap then
		local used = tonumber(run.Caps[cap_key]) or 0
		if used >= cap then return 0 end
		amount = math.min(amount, cap - used)
		run.Caps[cap_key] = used + amount
	end
	run.Scores[key] = (tonumber(run.Scores[key]) or 0) + amount
	return amount
end

local function set_flag(key, value)
	get_run().Flags[key] = value
end

local function get_flag(key)
	return get_run().Flags[key]
end

local function speak(line1, line2)
	local delay = 90
	gui.general_speak(Vector(0, 0), line1, 0, delay, {R = 1.6, G = 1.4, B = 0.6})
	if line2 and line2 ~= "" then
		delay_buffer.addeffe(function()
			gui.general_speak(Vector(0, 18), line2, 0, delay, {R = 2, G = 1.8, B = 0.4})
		end, {}, 18, true)
	end
end

local function refresh_candidate(force_hint)
	local run = get_run()
	local formed = leading_century(60, 1.20, run)
	if formed ~= run.CurrentCandidate then
		if formed then
			local first_time = run.LastHint == nil
			local turning = run.LastHint ~= nil and run.LastHint ~= formed
			if force_hint or first_time or turning then
				if first_time then
					speak(lang_pack() == "zh" and "时代正在形成……" or "An age is taking shape...", century_name(formed))
				else
					speak(lang_pack() == "zh" and "时代正在转向……" or "The age is turning...", century_name(formed))
				end
				run.LastHint = formed
			end
		end
		run.CurrentCandidate = formed
	end
	return formed
end

local function persist_legacy()
	if save.SaveModData then pcall(save.SaveModData, "regenesis_legacy") end
end

local function heart_fill_ratio(player)
	if not player then return 0 end
	local cur = player:GetHearts() + player:GetSoulHearts() + player:GetEternalHearts()
	local mx = player:GetEffectiveMaxHearts()
	if mx <= 0 then mx = math.max(player:GetSoulHearts(), 2) end
	if mx <= 0 then return 0 end
	return cur / mx
end

local function is_ruin_state(player)
	if not player then return false end
	local hits = 0
	if heart_fill_ratio(player) <= 0.30 then hits = hits + 1 end
	if player:GetNumCoins() <= 3 then hits = hits + 1 end
	if player:GetNumKeys() <= 0 then hits = hits + 1 end
	if player:GetNumBombs() <= 0 then hits = hits + 1 end
	local expected = current_stage() + 1
	if player:GetCollectibleCount() <= expected then hits = hits + 1 end
	return hits >= 2
end

local function any_ruin_state()
	for player_num = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		if player and is_ruin_state(player) then return true end
	end
	return false
end

local function grant_abundance_hearts(player)
	if not player then return end
	if auxi.is_player_only_soul_hearts(player) or player:GetEffectiveMaxHearts() <= 0 then
		auxi.add_soul_heart(player, 4)
	else
		player:AddMaxHearts(2)
		player:AddHearts(2)
	end
end

local function spawn_pickup(variant, subtype, pos)
	pos = Game():GetRoom():FindFreePickupSpawnPosition(pos or Game():GetRoom():GetCenterPos(), 20, true)
	return Isaac.Spawn(EntityType.ENTITY_PICKUP, variant, subtype or 0, pos, Vector(0, 0), nil)
end

local function spawn_ruin_start_supplies()
	local room = Game():GetRoom()
	local rng = century_rng(17001)
	local count = 3 + rng:RandomInt(3)
	local guaranteed = {
		{PickupVariant.PICKUP_KEY, 0},
		{PickupVariant.PICKUP_BOMB, 0},
		{PickupVariant.PICKUP_HEART, 0},
	}
	for i = 1, count do
		local choice = guaranteed[i]
		if not choice then
			local roll = rng:RandomInt(3)
			if roll == 0 then choice = {PickupVariant.PICKUP_COIN, 0}
			elseif roll == 1 then choice = {PickupVariant.PICKUP_KEY, 0}
			else choice = {PickupVariant.PICKUP_HEART, 0} end
		end
		spawn_pickup(choice[1], choice[2], room:GetCenterPos() + Vector((i - 2) * 24, 20))
	end
end

local function spawn_ruin_item_room_supplies()
	local room = Game():GetRoom()
	local rng = century_rng(17002 + Game():GetLevel():GetStage() * 17)
	local count = 2 + rng:RandomInt(2)
	for i = 1, count do
		local roll = rng:RandomInt(5)
		local variant, subtype = PickupVariant.PICKUP_COIN, CoinSubType.COIN_NICKEL
		if roll == 0 then variant, subtype = PickupVariant.PICKUP_KEY, KeySubType.KEY_CHARGED
		elseif roll == 1 then variant, subtype = PickupVariant.PICKUP_BOMB, BombSubType.BOMB_DOUBLEPACK
		elseif roll == 2 then variant, subtype = PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL
		elseif roll == 3 then variant, subtype = PickupVariant.PICKUP_LIL_BATTERY, 1
		end
		spawn_pickup(variant, subtype, room:GetCenterPos() + Vector((i - 1.5) * 32, 40))
	end
end

local function apply_run_start_effects()
	local run = get_run()
	if run.Applied == true or run.ActiveCentury == nil then return end
	run.Applied = true
	if run.ActiveCentury == "Faith" then
		run.FaithPath = "NONE"
	end
	for player_num = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		if player then
			if run.ActiveCentury == "Abundance" and get_flag("abundance_hearts") ~= true then
				grant_abundance_hearts(player)
			end
			if run.ActiveCentury == "War" then
				player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
				player:EvaluateItems()
			end
		end
	end
	if run.ActiveCentury == "Abundance" then set_flag("abundance_hearts", true) end
	if run.ActiveCentury == "Ruin" and get_flag("ruin_start") ~= true then
		set_flag("ruin_start", true)
		delay_buffer.addeffe(function()
			if get_run().ActiveCentury == "Ruin" then spawn_ruin_start_supplies() end
		end, {}, 2)
	end
end

local function consume_pending_into_run()
	local legacy = get_permanent()
	local run = get_run()
	if legacy.Pending == true and legacy.Century then
		run.ActiveCentury = legacy.Century
		run.Applied = false
		legacy.Pending = false
		legacy.Century = nil
		persist_legacy()
	end
end

local function compute_century(run)
	run = run or get_run()
	return leading_century(formation_threshold(run), 1.20, run)
end

function item.settle_run(reason)
	local run = get_run()
	if run.Settled == true then return run.ActiveCentury, "already" end
	if not any_holder() then
		run.Settled = true
		return nil, "no_item"
	end
	if reason == "death" and any_ruin_state() and (tonumber(run.RuinStreak) or 0) >= 5 then
		add_score("Ruin", 15, "ruin_death", 15)
	end
	local century = compute_century(run)
	run.Settled = true
	run.CurrentCandidate = century
	if century then
		local legacy = get_permanent()
		legacy.Century = century
		legacy.Pending = true
		persist_legacy()
	end
	return century, "ok"
end

local function room_key()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if desc and desc.SafeGridIndex then return tostring(desc.SafeGridIndex) end
	return tostring(Game():GetLevel():GetCurrentRoomIndex())
end

local function is_combat_room(room)
	room = room or Game():GetRoom()
	local tp = room:GetType()
	return tp == RoomType.ROOM_DEFAULT or tp == RoomType.ROOM_BOSS or tp == RoomType.ROOM_MINIBOSS or tp == RoomType.ROOM_CHALLENGE
end

local function note_room_enter()
	local room = Game():GetRoom()
	local run = get_run()
	run.Flags.room_enter_frame = Game():GetFrameCount()
	run.Flags.room_hurt = false
	run.Flags.room_enemies = room:GetAliveEnemiesCount()
	run.Flags.room_clear_at_enter = room:IsClear()
end

local function score_room_clear()
	if not is_recording() then return end
	local room = Game():GetRoom()
	if not is_combat_room(room) then return end
	if get_flag("room_clear_at_enter") == true then return end
	local clear_id = "cleared_"..tostring(current_stage()).."_"..room_key()
	if get_flag(clear_id) then return end
	set_flag(clear_id, true)
	local run = get_run()
	local tp = room:GetType()
	local stage = current_stage()
	local elapsed = Game():GetFrameCount() - (tonumber(run.Flags.room_enter_frame) or Game():GetFrameCount())
	local enemies = tonumber(run.Flags.room_enemies) or 0
	local fast_limit = 90 + 15 * math.max(enemies, 1)
	local no_hurt = run.Flags.room_hurt ~= true

	if tp == RoomType.ROOM_DEFAULT or tp == RoomType.ROOM_MINIBOSS then
		add_score("War", 2, "war_clear_"..tostring(stage), 12)
		if no_hurt then add_score("War", 2) end
		if elapsed <= fast_limit then add_score("War", 2) end
	elseif tp == RoomType.ROOM_BOSS then
		add_score("War", 15)
		if no_hurt then add_score("War", 8) end
		if elapsed <= 900 then add_score("War", 7) end
		if any_ruin_state() then add_score("Ruin", 20) end
		local low_hp = false
		for player_num = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(player_num)
			if player then
				local cur = player:GetHearts() + player:GetSoulHearts() + player:GetEternalHearts()
				if cur <= 2 then low_hp = true end
			end
		end
		if low_hp then add_score("Ruin", 10) end
	elseif tp == RoomType.ROOM_CHALLENGE then
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		local boss_challenge = desc and desc.Data and desc.Data.Subtype == 1
		add_score("War", boss_challenge and 12 or 8)
	end

	if any_ruin_state() and (tp == RoomType.ROOM_DEFAULT or tp == RoomType.ROOM_MINIBOSS) then
		add_score("Ruin", 3, "ruin_clear_"..tostring(stage), 15)
		run.RuinStreak = (tonumber(run.RuinStreak) or 0) + 1
		if run.RuinStreak > 0 and run.RuinStreak % 5 == 0 then add_score("Ruin", 8) end
	else
		run.RuinStreak = 0
	end

	local healthy = true
	for player_num = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		if player and heart_fill_ratio(player) < 0.999 then healthy = false end
	end
	if healthy then
		run.FullHealthClears = (tonumber(run.FullHealthClears) or 0) + 1
		if run.FullHealthClears % 5 == 0 then
			add_score("Abundance", 5, "abundance_fullclear", 25)
		end
	end

	if get_run().ActiveCentury == "Technology" then
		run.TechClears = (tonumber(run.TechClears) or 0) + 1
		if run.TechClears > 0 and run.TechClears % 6 == 0 then
			for player_num = 0, Game():GetNumPlayers() - 1 do
				local player = Game():GetPlayer(player_num)
				if player then
					for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
						if player:GetActiveItem(slot) ~= 0 and player:NeedsCharge(slot) then
							player:SetActiveCharge(player:GetActiveCharge(slot) + 1, slot)
							break
						end
					end
				end
			end
		end
	end
	refresh_candidate()
end

local function score_shop_enter()
	if not is_recording() then return end
	if Game():GetRoom():GetType() ~= RoomType.ROOM_SHOP then return end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if desc and desc.VisitedCount > 1 then return end
	add_score("Prosperity", 5, "shop_enter_"..tostring(current_stage()), 5)
	refresh_candidate()
end

local function extra_shop_content()
	local run = get_run()
	local room = Game():GetRoom()
	if room:GetType() ~= RoomType.ROOM_SHOP then return end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if desc and desc.VisitedCount > 1 then return end
	local key = "shop_bonus_"..room_key()
	if get_flag(key) then return end
	set_flag(key, true)
	if run.ActiveCentury == "Prosperity" then
		local pos = room:FindFreePickupSpawnPosition(room:GetCenterPos() + Vector(80, 40), 40, true)
		local seed = room:GetSpawnSeed()
		local id = Game():GetItemPool():GetCollectible(ItemPoolType.POOL_SHOP, true, seed)
		if id and id > 0 then
			local pickup = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, id, pos, Vector(0, 0), nil):ToPickup()
			if pickup then
				pickup.AutoUpdatePrice = true
				pickup.Price = 15
			end
		end
		local rng = century_rng(17010 + seed)
		if rng:RandomFloat() < 0.22 then
			Isaac.Spawn(EntityType.ENTITY_SLOT, 10, 0, room:FindFreePickupSpawnPosition(room:GetCenterPos() + Vector(-80, 40), 40, true), Vector(0, 0), nil)
		end
	end
	if run.ActiveCentury == "Technology" then
		local rng = century_rng(17011 + room:GetSpawnSeed())
		if rng:RandomFloat() < 0.45 then
			spawn_pickup(PickupVariant.PICKUP_LIL_BATTERY, 1, room:GetCenterPos() + Vector(0, 60))
		end
	end
end

local function remap_drop(variant, subtype)
	local run = get_run()
	local century = run.ActiveCentury
	if not century then return end
	local rng = century_rng(17100 + Game():GetFrameCount() + variant * 13 + (subtype or 0))
	local is_heart = variant == PickupVariant.PICKUP_HEART
	local is_coin = variant == PickupVariant.PICKUP_COIN
	local is_key = variant == PickupVariant.PICKUP_KEY
	local is_bomb = variant == PickupVariant.PICKUP_BOMB
	local is_battery = variant == PickupVariant.PICKUP_LIL_BATTERY
	if century == "Prosperity" and (is_key or is_bomb or is_heart) and rng:RandomFloat() < 0.08 then
		return PickupVariant.PICKUP_COIN, 1
	end
	if century == "War" and is_combat_room() and (is_heart or is_coin) and rng:RandomFloat() < 0.16 then
		local roll = rng:RandomInt(3)
		if roll == 0 then return PickupVariant.PICKUP_BOMB, 1 end
		if roll == 1 then return PickupVariant.PICKUP_KEY, 1 end
		return PickupVariant.PICKUP_LIL_BATTERY, 1
	end
	if century == "Abundance" and (is_coin or is_key or is_bomb) and rng:RandomFloat() < 0.12 then
		return PickupVariant.PICKUP_HEART, 1
	end
	if century == "Technology" and (is_coin or is_key or is_bomb) and rng:RandomFloat() < 0.18 then
		return PickupVariant.PICKUP_LIL_BATTERY, 1
	end
	return variant, subtype
end

local function is_tech_collectible(id)
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg then return false end
	if cfg.HasTags then
		if ItemConfig.TAG_TECH and cfg:HasTags(ItemConfig.TAG_TECH) then return true end
		if ItemConfig.TAG_TECH_2 and cfg:HasTags(ItemConfig.TAG_TECH_2) then return true end
		if ItemConfig.TAG_BATTERY and cfg:HasTags(ItemConfig.TAG_BATTERY) then return true end
	end
	return false
end

local function count_tech_support(player)
	local n = 0
	if player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) ~= 0 then n = n + 1 end
	if player:GetActiveItem(ActiveSlot.SLOT_SECONDARY) ~= 0 then n = n + 1 end
	local ids = {
		CollectibleType.COLLECTIBLE_SCHOOLBAG,
		CollectibleType.COLLECTIBLE_BATTERY,
		CollectibleType.COLLECTIBLE_9_VOLT,
		CollectibleType.COLLECTIBLE_JUMPER_CABLES,
		CollectibleType.COLLECTIBLE_SHARP_PLUG,
		CollectibleType.COLLECTIBLE_CHARGED_BABY,
		CollectibleType.COLLECTIBLE_HABIT,
	}
	if CollectibleType.COLLECTIBLE_4_5_VOLT then ids[#ids + 1] = CollectibleType.COLLECTIBLE_4_5_VOLT end
	for _, id in ipairs(ids) do
		if player:HasCollectible(id) then n = n + 1 end
	end
	return n
end

local function lock_faith_path(path)
	local run = get_run()
	if run.ActiveCentury ~= "Faith" then return end
	if run.FaithPath and run.FaithPath ~= "NONE" then return end
	run.FaithPath = path
	local level = Game():GetLevel()
	if not level or not level.AddAngelRoomChance then return end
	local applied = tonumber(run.Flags.angel_mod) or 0
	local want = 0
	if path == "ANGEL" then want = 0.85
	elseif path == "DEVIL" then want = -0.85 end
	level:AddAngelRoomChance(want - applied)
	run.Flags.angel_mod = want
end

function item.get_run_data()
	return get_run()
end

function item.get_legacy()
	return get_permanent()
end

function item.get_active_century()
	return get_run().ActiveCentury
end

function item.set_score(key, value)
	if not NAMES.en[key] then return false end
	get_run().Scores[key] = math.max(0, tonumber(value) or 0)
	refresh_candidate(true)
	return true
end

function item.set_active_century(key)
	local run = get_run()
	if key == "" or key == nil or key == "(none)" then
		run.ActiveCentury = nil
	else
		run.ActiveCentury = key
	end
	run.Applied = false
	apply_run_start_effects()
	for player_num = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		if player then
			player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
			player:EvaluateItems()
		end
	end
	return run.ActiveCentury
end

function item.set_pending_century(key)
	local legacy = get_permanent()
	if key == "" or key == nil or key == "(none)" then
		legacy.Century = nil
		legacy.Pending = false
	else
		legacy.Century = key
		legacy.Pending = true
	end
	persist_legacy()
	return legacy
end

function item.force_settle()
	local run = get_run()
	local century = compute_century(run)
	run.Settled = true
	run.CurrentCandidate = century
	if century then
		local legacy = get_permanent()
		legacy.Century = century
		legacy.Pending = true
		persist_legacy()
	end
	return century, "debug"
end

function item.debug_apply_active()
	local run = get_run()
	run.Applied = false
	apply_run_start_effects()
	return run.ActiveCentury
end

function item.clear_legacy()
	local legacy = get_permanent()
	legacy.Century = nil
	legacy.Pending = false
	persist_legacy()
	return true
end

function item.reset_debug()
	save.elses[item.own_key.."run"] = nil
	item.clear_legacy()
	return get_run()
end

function item.debug_announce()
	refresh_candidate(true)
end

function item.get_debug_status()
	local run = get_run()
	local legacy = get_permanent()
	local lines = {
		"Recording: "..tostring(run.Recording == true and any_holder() ~= nil),
		"Threshold: "..tostring(formation_threshold(run)),
		"Candidate: "..tostring(run.CurrentCandidate or "none"),
		"ActiveCentury: "..tostring(run.ActiveCentury or "none"),
		"FaithPath: "..tostring(run.FaithPath or "NONE"),
		"Pending: "..tostring(legacy.Pending).." / "..tostring(legacy.Century or "none"),
		"Settled: "..tostring(run.Settled),
	}
	for _, key in ipairs(CENTURIES) do
		lines[#lines + 1] = key..": "..tostring(run.Scores[key] or 0)
	end
	return table.concat(lines, "\n")
end

item.CENTURIES = CENTURIES

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	item.skip_settle = false
	if continue ~= true then
		save.elses[item.own_key.."run"] = nil
		consume_pending_into_run()
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_, continue)
	if continue ~= true then
		apply_run_start_effects()
	else
		local run = get_run()
		if run.ActiveCentury == "War" then
			for player_num = 0, Game():GetNumPlayers() - 1 do
				local player = Game():GetPlayer(player_num)
				if player then
					player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
					player:EvaluateItems()
				end
			end
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_, shouldsave)
	if shouldsave ~= true then item.skip_settle = true end
end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_, ent, hook, action)
	if action == ButtonAction.ACTION_RESTART and hook == InputHook.IS_ACTION_TRIGGERED then
		item.skip_settle = true
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_END, params = nil,
Function = function(_, is_game_over)
	if item.skip_settle then
		item.skip_settle = false
		return
	end
	item.settle_run(is_game_over and "death" or "ending")
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_, player, collid, cnt, touched)
	local run = get_run()
	run.Recording = true
	run.EverHeld = true
	if run.AcquiredStage == nil then
		run.AcquiredStage = current_stage()
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_LOSE_COLLECTIBLE, params = item.entity,
Function = function(_, player, collid, cnt, nownum)
	if not any_holder() then
		get_run().Recording = false
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = nil,
Function = function(_, player, collid, cnt, touched)
	if not player or not collid or collid == item.entity then return end
	if not is_recording() then
		if get_run().ActiveCentury == "Faith" then
			local tp = Game():GetRoom():GetType()
			if tp == RoomType.ROOM_DEVIL then lock_faith_path("DEVIL")
			elseif tp == RoomType.ROOM_ANGEL then lock_faith_path("ANGEL") end
		end
		return
	end
	if is_tech_collectible(collid) then
		add_score("Technology", 8, "tech_item_"..tostring(collid), 8)
	end
	if count_tech_support(player) >= 2 then
		add_score("Technology", 10, "tech_support", 10)
	end
	local tp = Game():GetRoom():GetType()
	if tp == RoomType.ROOM_DEVIL then
		add_score("Faith", 20)
		if get_run().ActiveCentury == "Faith" then lock_faith_path("DEVIL") end
	elseif tp == RoomType.ROOM_ANGEL then
		add_score("Faith", 20)
		if get_run().ActiveCentury == "Faith" then lock_faith_path("ANGEL") end
	end
	if collid == CollectibleType.COLLECTIBLE_KEY_PIECE_1 or collid == CollectibleType.COLLECTIBLE_KEY_PIECE_2 then
		add_score("Faith", 15)
	end
	refresh_candidate()
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_CHANGE_BASIC, params = nil,
Function = function(_, player, changetype, count)
	if not is_recording() or not player or not count then return end
	if changetype == "coin" then
		if count > 0 then
			local run = get_run()
			run.CoinGained = (tonumber(run.CoinGained) or 0) + count
			local gained = run.CoinGained
			local last = tonumber(run.Caps.coin_gain_units) or 0
			local units = math.floor(gained / 5)
			if units > last then
				add_score("Prosperity", 2 * (units - last), "prosperity_gain", 30)
				run.Caps.coin_gain_units = units
			end
			if player:GetNumCoins() >= 50 then add_score("Prosperity", 10, "held50", 10) end
			if player:GetNumCoins() >= 99 then add_score("Prosperity", 10, "held99", 10) end
		elseif count < 0 then
			add_score("Prosperity", -count, "prosperity_spend", 50)
		end
	elseif changetype == "mx_heart" and count > 0 then
		add_score("Abundance", 12 * math.floor(count / 2 + 0.1))
	elseif changetype == "sl_heart" and count > 0 then
		add_score("Abundance", 4 * math.floor(count / 2 + 0.1))
	elseif changetype == "bl_heart" and count > 0 then
		add_score("Abundance", 5 * count)
		add_score("Faith", 3 * count, "faith_black", 20)
	elseif changetype == "et_heart" and count > 0 then
		add_score("Abundance", 8 * count)
		add_score("Faith", 5 * count)
	elseif changetype == "rd_heart" and count > 0 then
		local run = get_run()
		run.Caps.heal_half = (tonumber(run.Caps.heal_half) or 0) + count
		local units = math.floor((run.Caps.heal_half) / 4)
		local last = tonumber(run.Caps.heal_units) or 0
		if units > last then
			add_score("Abundance", 2 * (units - last), "abundance_heal", 15)
			run.Caps.heal_units = units
		end
	end
	refresh_candidate()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_USE_ITEM, params = nil,
Function = function(_, collid, rng, player, flags, slot, data)
	if not is_recording() or not player or not is_active_charge_slot(slot) then return end
	local d = player:GetData()
	d[item.own_key.."pre_charge"] = player:GetActiveCharge(slot) + player:GetBatteryCharge(slot)
	d[item.own_key.."pre_full"] = not player:NeedsCharge(slot)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = nil,
Function = function(_, collid, rng, player, flags, slot, data)
	if not is_recording() or not player or not is_active_charge_slot(slot) then return end
	local d = player:GetData()
	local before = tonumber(d[item.own_key.."pre_charge"]) or 0
	local after = player:GetActiveCharge(slot) + player:GetBatteryCharge(slot)
	local spent = math.max(0, before - after)
	if spent <= 0 then return end
	add_score("Technology", spent, "tech_charge", 50)
	if d[item.own_key.."pre_full"] then add_score("Technology", 3) end
	refresh_candidate()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = PickupVariant.PICKUP_LIL_BATTERY,
Function = function(_, pickup, collider)
	if not is_recording() then return end
	local player = collider and collider:ToPlayer()
	if not player or not pickup then return end
	local can_charge = false
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		if player:GetActiveItem(slot) ~= 0 and player:NeedsCharge(slot) then can_charge = true break end
	end
	if not can_charge then return end
	local st = pickup.SubType or 1
	if st == 3 then add_score("Technology", 5)
	elseif st == 1 then add_score("Technology", 3)
	else add_score("Technology", 3) end
	refresh_candidate()
end,
})

if ModCallbacks.MC_POST_PICKUP_SHOP_PURCHASE then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_SHOP_PURCHASE, params = nil,
	Function = function(_, pickup, player, spent)
		if not pickup then return end
		if is_recording() then
			if (spent or 0) > 0 then
				add_score("Prosperity", 6)
				if spent >= 15 then add_score("Prosperity", 4) end
			end
			if pickup.Price and pickup.Price < 0 then
				add_score("Faith", 20)
			end
			refresh_candidate()
		end
		if get_run().ActiveCentury == "Faith" and pickup.Price and pickup.Price < 0 then
			lock_faith_path("DEVIL")
		end
	end,
	})
end

if ModCallbacks.MC_POST_SLOT_COLLISION then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_SLOT_COLLISION, params = nil,
	Function = function(_, slot, collider)
		if not is_recording() or not slot then return end
		local player = collider and collider:ToPlayer()
		if not player then return end
		local seed = tostring(slot.InitSeed)
		local run = get_run()
		local last = tonumber(run.Flags["slot_"..seed]) or -999
		if Game():GetFrameCount() - last < 40 then return end
		run.Flags["slot_"..seed] = Game():GetFrameCount()
		add_score("Technology", 3, "tech_machine", 30)
		if Game():GetRoom():GetType() == RoomType.ROOM_SHOP then
			add_score("Prosperity", 3, "prosperity_machine", 15)
		end
		refresh_candidate()
	end,
	})
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_, ent, val)
	if get_run().ActiveCentury ~= "Prosperity" then return end
	if not val or val <= 0 then return end
	local priced = math.ceil(val * 1.25)
	if priced > 99 then priced = 99 end
	return math.max(1, priced)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_, ent)
	if get_run().ActiveCentury == "Prosperity" and ent and ent:IsShopItem() and ent.Price and ent.Price > 0 then
		price_holder.try_catch_price(ent)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = CacheFlag.CACHE_DAMAGE,
Function = function(_, player, flag)
	if get_run().ActiveCentury == "War" and player then
		player.Damage = player.Damage + 0.75
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	note_room_enter()
	score_shop_enter()
	extra_shop_content()
	local tp = Game():GetRoom():GetType()
	if is_recording() then
		if tp == RoomType.ROOM_DEVIL then add_score("Faith", 8) refresh_candidate()
		elseif tp == RoomType.ROOM_ANGEL then add_score("Faith", 8) refresh_candidate() end
	end
	if get_run().ActiveCentury == "Ruin" and tp == RoomType.ROOM_TREASURE and current_stage() <= 1 and get_flag("ruin_treasure") ~= true then
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		if desc and desc.VisitedCount <= 1 then
			set_flag("ruin_treasure", true)
			spawn_ruin_item_room_supplies()
		end
	end
	if is_recording() and heart_fill_ratio(Game():GetPlayer(0)) >= 0.80 and tp == RoomType.ROOM_BOSS then
		add_score("Abundance", 5)
		refresh_candidate()
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function()
	if is_recording() then
		if any_ruin_state() then add_score("Ruin", 15) end
		for player_num = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(player_num)
			if player and heart_fill_ratio(player) >= 0.80 then
				add_score("Abundance", 8)
			end
			if player and player.Damage >= (3.5 + current_stage() * 0.75) then
				local amt = 5
				if player.Damage >= (6 + current_stage()) then amt = 10 end
				add_score("War", amt, "war_dmg_"..tostring(current_stage()), amt)
			end
		end
		refresh_candidate()
	end
	local run = get_run()
	if run.ActiveCentury == "Faith" and run.FaithPath and run.FaithPath ~= "NONE" then
		local want = run.FaithPath == "ANGEL" and 0.85 or -0.85
		local applied = tonumber(run.Flags.angel_mod) or 0
		if math.abs(want - applied) > 0.001 then
			Game():GetLevel():AddAngelRoomChance(want - applied)
			run.Flags.angel_mod = want
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function()
	score_room_clear()
end,
})

table.insert(item.post_ToCall, #item.post_ToCall + 1, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_, ent, amt, flag, source, cooldown)
	if amt and amt > 0 then
		get_run().Flags.room_hurt = true
	end
	if is_recording() and Game():GetRoom():GetType() == RoomType.ROOM_SACRIFICE and flag and (flag & DamageFlag.DAMAGE_SPIKES) ~= 0 then
		add_score("Faith", 4, "faith_sacrifice", 30)
		refresh_candidate()
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = EntityType.ENTITY_URIEL,
Function = function()
	if is_recording() then add_score("Faith", 12) refresh_candidate() end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = EntityType.ENTITY_GABRIEL,
Function = function()
	if is_recording() then add_score("Faith", 12) refresh_candidate() end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NPC_INIT, params = nil,
Function = function(_, npc)
	if get_run().ActiveCentury ~= "War" or not npc then return end
	npc = npc:ToNPC()
	if not npc or npc:IsBoss() or npc:IsChampion() then return end
	if not npc:IsEnemy() or not npc:IsVulnerableEnemy() then return end
	local rng = RNG()
	rng:SetSeed(mix32(npc.InitSeed + 17033), 35)
	rng = auxi.rng_for_sake(rng) or rng
	if rng:RandomFloat() < 0.025 then
		pcall(function() npc:MakeChampion(npc.InitSeed, -1, true) end)
	end
end,
})

if ModCallbacks.MC_POST_PICKUP_SELECTION then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_SELECTION, params = nil,
	Function = function(_, pickup, variant, subtype, requested_variant)
		if requested_variant and requested_variant ~= 0 then return end
		if pickup and pickup.IsShopItem and pickup:IsShopItem() then return end
		local nv, ns = remap_drop(variant, subtype)
		if nv and (nv ~= variant or ns ~= subtype) then return {nv, ns} end
	end,
	})
end

if ModCallbacks.MC_POST_DEVIL_CALCULATE then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_DEVIL_CALCULATE, params = nil,
	Function = function(_, chance)
		local run = get_run()
		if run.ActiveCentury ~= "Faith" then return end
		chance = (tonumber(chance) or 0) + 0.10
		if run.FaithPath == "DEVIL" then chance = chance + 0.15
		elseif run.FaithPath == "ANGEL" then chance = chance + 0.10 end
		return chance
	end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_ENTITY_SPAWN, params = nil,
Function = function(_, tp, variant, subtype, pos, vel, spawner, seed)
	if get_run().ActiveCentury ~= "Ruin" then return end
	if tp ~= EntityType.ENTITY_SLOT then return end
	local rng = RNG()
	rng:SetSeed(mix32(seed + 17044), 35)
	rng = auxi.rng_for_sake(rng) or rng
	if rng:RandomFloat() < 0.30 then
		return {EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, seed}
	end
end,
})

if EID then
	EID:addDescriptionModifier("qing_item_sync"..tostring(item.entity), function(desc) return true end, function(desc)
		local st = desc.ObjSubType
		if not ((desc.ObjType == 5 and desc.ObjVariant == 100 and st == item.entity) or desc.ObjSubType == item.entity) then
			return desc
		end
		if desc.ObjType == 5 and desc.ObjVariant ~= 100 then return desc end
		local run = get_run()
		local language = lang_pack()
		if any_holder() then
			local copies = 0
			for player_num = 0, Game():GetNumPlayers() - 1 do
				local player = Game():GetPlayer(player_num)
				if player then copies = copies + player:GetCollectibleNum(item.entity) end
			end
			if copies > 1 then
				if language == "zh" then
					EID:appendToDescription(desc, "#{{Collectible}} 多份再世纪没有额外效果")
				else
					EID:appendToDescription(desc, "#{{Collectible}} Extra copies do nothing")
				end
			end
			local candidate = leading_century(60, 1.20, run)
			if candidate then
				local names = NAMES[language] or NAMES.en
				local summary = (EID_SUMMARY[language] or EID_SUMMARY.en)[candidate]
				if language == "zh" then
					EID:appendToDescription(desc, "#当前最可能形成：{{ColorYellow}}"..(names[candidate] or candidate).."{{CR}}")
				else
					EID:appendToDescription(desc, "#Most likely: {{ColorYellow}}"..(names[candidate] or candidate).."{{CR}}")
				end
				if summary then EID:appendToDescription(desc, summary) end
			end
		end
		if run.ActiveCentury then
			local names = NAMES[language] or NAMES.en
			if language == "zh" then
				EID:appendToDescription(desc, "#{{Timer}} 本局遗产：{{ColorYellow}}"..(names[run.ActiveCentury] or "").."{{CR}}")
			else
				EID:appendToDescription(desc, "#{{Timer}} This run's legacy: {{ColorYellow}}"..(names[run.ActiveCentury] or "").."{{CR}}")
			end
		end
		return desc
	end)
end

return item

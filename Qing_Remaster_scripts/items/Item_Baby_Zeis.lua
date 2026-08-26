local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local AI = require("Qing_Remaster_scripts.bosses.Boss_All")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local Baby_Anim = require("Qing_Remaster_scripts.others.Baby_Anim_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Baby_Zeis,
	familiar = enums.Familiars.Baby_Zeis,
	own_key = "Item_Baby_Zeis_",
	float_lock = {
		Wake = true,
	},
	sleep_opts = {
		float_anim = "SleepFloat",
		idle_anim = "SleepIdle",
	},
}

local function level_key()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	return table.concat({tostring(level:GetStage()), tostring(level:GetStageType()), tostring(desc.ListIndex)}, ":")
end

local function persist_bag()
	save.elses[item.own_key.."run"] = save.elses[item.own_key.."run"] or {}
	return save.elses[item.own_key.."run"]
end

local function player_persist_key(player)
	if not player then return nil end
	return tostring(player.InitSeed)
end

local function player_run_bag(player)
	local key = player_persist_key(player)
	if not key then return nil end
	local bag = persist_bag()
	local st = bag[key]
	if type(st) ~= "table" then
		st = {level_key = level_key(), slots = {}}
		bag[key] = st
	end
	if st.level_key ~= level_key() then
		st.level_key = level_key()
		st.slots = {}
	end
	st.slots = st.slots or {}
	return st
end

local function get_phase(player, slot)
	if not slot then return "sleep" end
	local st = player_run_bag(player)
	local slot_st = st and st.slots[slot]
	return (slot_st and slot_st.phase) or "sleep"
end

local function set_phase(player, slot, phase)
	if not slot or not phase then return end
	local st = player_run_bag(player)
	if not st then return end
	local slot_st = st.slots[slot]
	if slot_st and slot_st.phase == phase then return end
	st.slots[slot] = {phase = phase}
end

local function runtime_tg(ent)
	return ent:GetData()[item.own_key.."tg"]
end

local function set_runtime_tg(ent, tg)
	ent:GetData()[item.own_key.."tg"] = tg
end

local function clear_runtime_tg(ent)
	local d = ent:GetData()
	local tg = d[item.own_key.."tg"]
	if tg then
		local ok, td = pcall(function() return tg:GetData() end)
		if ok and td and td[item.own_key.."effect"] ~= nil then
			td[item.own_key.."effect"] = nil
		end
	end
	d[item.own_key.."tg"] = nil
end

local function find_pedestal(ent)
	return auxi.getothers(nil, 5, 100, nil, function(pick)
		if pick.SubType ~= 0 and auxi.check_all_exists(pick:GetData()[item.own_key.."effect"]) ~= true then
			return true
		end
	end)
end

local function target_still_valid(ent)
	return auxi.check_all_exists(runtime_tg(ent)) == true
end

local function slot_index(ent, player)
	local d = ent:GetData()
	if d[item.own_key.."slot"] then
		return d[item.own_key.."slot"]
	end
	local fams = {}
	for _, fam in pairs(auxi.getothers(nil, 3, item.familiar) or {}) do
		local spawner = auxi.check_spawner_player(fam)
		if spawner and auxi.check_for_the_same(spawner, player) then
			table.insert(fams, fam)
		end
	end
	table.sort(fams, function(a, b)
		if a.InitSeed == b.InitSeed then
			return a:GetPtrHash() < b:GetPtrHash()
		end
		return a.InitSeed < b.InitSeed
	end)
	for i, fam in ipairs(fams) do
		fam:GetData()[item.own_key.."slot"] = i
	end
	return d[item.own_key.."slot"]
end

local function begin_sleep(ent, player, slot)
	local s = ent:GetSprite()
	clear_runtime_tg(ent)
	AI.ClearMovement(ent)
	set_phase(player, slot, "sleep")
	Baby_Anim.reset(ent, item.own_key.."float")
	Baby_Anim.reset(ent, item.own_key.."sleep")
	s:Play("SleepFloat", true)
	local d = ent:GetData()
	if not d[item.own_key.."IsFollow"] then
		ent:AddToFollowers()
		d[item.own_key.."IsFollow"] = true
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity) + player:GetEffects():GetCollectibleEffectNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."run"] = {}
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."run"] = {}
	local tgs = auxi.getothers(nil, 3, item.familiar)
	for _, v in pairs(tgs) do
		v:GetData()[item.own_key.."slot"] = nil
		clear_runtime_tg(v)
		Baby_Anim.reset(v, item.own_key.."float")
		Baby_Anim.reset(v, item.own_key.."sleep")
		v:GetSprite():Play("SleepFloat", true)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_, ent)
	local player = auxi.check_spawner_player(ent)
	if not player then return end
	local slot = slot_index(ent, player)
	if not slot then return end
	local d = ent:GetData()
	local s = ent:GetSprite()
	local phase = get_phase(player, slot)

	if phase == "sleep" then
		if not d[item.own_key.."IsFollow"] then
			ent:AddToFollowers()
			d[item.own_key.."IsFollow"] = true
		end
		Baby_Anim.tick_float_idle(ent, item.own_key.."sleep", item.sleep_opts)
		if Baby_Anim.is_float_idle_anim(s:GetAnimation(), item.sleep_opts) then
			ent:FollowParent()
		end

		local tgs = find_pedestal(ent)
		if #tgs > 0 then
			local q = auxi.random_in_table(tgs)
			q:GetData()[item.own_key.."effect"] = ent
			set_runtime_tg(ent, q)
			set_phase(player, slot, "wake")
			Baby_Anim.reset(ent, item.own_key.."sleep")
			s:Play("Wake", true)
		end
		return
	end

	if phase == "wake" then
		if not target_still_valid(ent) then
			begin_sleep(ent, player, slot)
			return
		end
		if not d[item.own_key.."IsFollow"] then
			ent:AddToFollowers()
			d[item.own_key.."IsFollow"] = true
		end
		ent:FollowParent()
		-- 必须先判 IsFinished：播完后 IsPlaying 为 false，若先 Play 会永远重播 Wake
		if s:IsFinished("Wake") then
			if d[item.own_key.."IsFollow"] then
				ent:RemoveFromFollowers()
				d[item.own_key.."IsFollow"] = nil
			end
			set_phase(player, slot, "seek")
			Baby_Anim.reset(ent, item.own_key.."float")
			s:Play("Float", true)
			AI.move2ent(ent, runtime_tg(ent), 30)
		elseif not s:IsPlaying("Wake") then
			s:Play("Wake", true)
		end
		return
	end

	if phase == "seek" then
		if not target_still_valid(ent) then
			begin_sleep(ent, player, slot)
			return
		end
		if d[item.own_key.."IsFollow"] then
			ent:RemoveFromFollowers()
			d[item.own_key.."IsFollow"] = nil
		end
		if s:GetAnimation() ~= "Float" then
			s:Play("Float", true)
		end
		AI.Control_Move(ent)
		if AI.is_clear(ent) then
			if not target_still_valid(ent) then
				begin_sleep(ent, player, slot)
				return
			end
			local room = Game():GetRoom()
			local q = runtime_tg(ent)
			unique_holder.Hold_for_missing(true)
			local copy = Isaac.Spawn(5, 100, q.SubType, room:FindFreePickupSpawnPosition(ent.Position, 10, true), Vector(0, 0), ent):ToPickup()
			auxi.self_morph(copy, {5, 100, q.SubType})
			Isaac.Spawn(1000, 16, 1, copy.Position, Vector(0, 0), nil)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP, 1, 1, false, 0, 2)
			clear_runtime_tg(ent)
			set_phase(player, slot, "done")
			Baby_Anim.reset(ent, item.own_key.."float")
			s:Play("Float", true)
		end
		return
	end

	-- done：该 slot 本层已复制；多只宝宝各自维护 slot 进度
	if not d[item.own_key.."IsFollow"] then
		ent:AddToFollowers()
		d[item.own_key.."IsFollow"] = true
	end
	Baby_Anim.tick_float_idle(ent, item.own_key.."float", {locked = item.float_lock})
	if Baby_Anim.is_float_idle_anim(s:GetAnimation()) then
		ent:FollowParent()
	end
end,
})

return item

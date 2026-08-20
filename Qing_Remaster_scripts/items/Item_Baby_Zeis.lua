local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local AI = require("Qing_Remaster_scripts.bosses.Boss_All")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
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

local function ensure_data(ent)
	local d = ent:GetData()
	d._Data = d._Data or {}
	if type(d._Data[item.own_key]) ~= "table" or d._Data[item.own_key].phase == nil then
		d._Data[item.own_key] = {phase = "sleep"}
	end
	return d, d._Data[item.own_key]
end

local function find_pedestal(ent)
	return auxi.getothers(nil, 5, 100, nil, function(pick)
		if pick.SubType ~= 0 and auxi.check_all_exists(pick:GetData()[item.own_key.."effect"]) ~= true then
			return true
		end
	end)
end

local function release_target(data)
	local tg = data and data.tg
	if tg then
		local ok, td = pcall(function() return tg:GetData() end)
		if ok and td and td[item.own_key.."effect"] ~= nil then
			-- 未完成复制：清标记，允许再次 Sleep 后认领
			td[item.own_key.."effect"] = nil
		end
	end
	if data then data.tg = nil end
end

local function begin_sleep(ent, data)
	local s = ent:GetSprite()
	release_target(data)
	AI.ClearMovement(ent)
	data.phase = "sleep"
	Baby_Anim.reset(ent, item.own_key.."float")
	Baby_Anim.reset(ent, item.own_key.."sleep")
	s:Play("SleepFloat", true)
	local d = ent:GetData()
	if not d[item.own_key.."IsFollow"] then
		ent:AddToFollowers()
		d[item.own_key.."IsFollow"] = true
	end
end

local function target_still_valid(data)
	return auxi.check_all_exists(data and data.tg) == true
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	local tgs = auxi.getothers(nil, 3, item.familiar)
	for _, v in pairs(tgs) do
		local d = v:GetData()
		d._Data = d._Data or {}
		d._Data[item.own_key] = {phase = "sleep"}
		Baby_Anim.reset(v, item.own_key.."float")
		Baby_Anim.reset(v, item.own_key.."sleep")
		v:GetSprite():Play("SleepFloat", true)
		consistance_holder.try_hold_entity(v, item.own_key)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_, ent)
	local player = auxi.check_spawner_player(ent)
	local d, data = ensure_data(ent)
	local s = ent:GetSprite()

	consistance_holder.try_check_entity(ent, item.own_key)
	d._Data = d._Data or {}
	if type(d._Data[item.own_key]) ~= "table" or d._Data[item.own_key].phase == nil then
		d._Data[item.own_key] = {phase = "sleep"}
		data = d._Data[item.own_key]
	else
		data = d._Data[item.own_key]
	end

	if data.phase == "sleep" then
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
			data.tg = q
			data.phase = "wake"
			Baby_Anim.reset(ent, item.own_key.."sleep")
			s:Play("Wake", true)
		end
		return
	end

	if data.phase == "wake" then
		-- 醒来过程中目标丢失：不算成功，回 Sleep 可再认领
		if not target_still_valid(data) then
			begin_sleep(ent, data)
			return
		end
		if not d[item.own_key.."IsFollow"] then
			ent:AddToFollowers()
			d[item.own_key.."IsFollow"] = true
		end
		ent:FollowParent()
		-- 必须先判 IsFinished：播完后 IsPlaying 为 false，若先 Play 会永远重播 Wake
		-- 见 codex_work/notes/sprite_isfinished_before_isplaying.md
		if s:IsFinished("Wake") then
			if d[item.own_key.."IsFollow"] then
				ent:RemoveFromFollowers()
				d[item.own_key.."IsFollow"] = nil
			end
			data.phase = "seek"
			Baby_Anim.reset(ent, item.own_key.."float")
			s:Play("Float", true)
			AI.move2ent(ent, data.tg, 30)
		elseif not s:IsPlaying("Wake") then
			s:Play("Wake", true)
		end
		return
	end

	if data.phase == "seek" then
		if not target_still_valid(data) then
			begin_sleep(ent, data)
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
			-- 抵达时再确认一次：中途被拿走不算成功
			if not target_still_valid(data) then
				begin_sleep(ent, data)
				return
			end
			local room = Game():GetRoom()
			local q = data.tg
			consistance_holder.try_hold_entity(ent, item.own_key)
			unique_holder.Hold_for_missing(true)
			local copy = Isaac.Spawn(5, 100, q.SubType, room:FindFreePickupSpawnPosition(ent.Position, 10, true), Vector(0, 0), ent):ToPickup()
			auxi.self_morph(copy, {5, 100, q.SubType})
			Isaac.Spawn(1000, 16, 1, copy.Position, Vector(0, 0), nil)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP, 1, 1, false, 0, 2)
			-- 成功：保留底座 effect 标记，避免同层再认领；仅清本地 tg
			data.tg = nil
			data.phase = "done"
			Baby_Anim.reset(ent, item.own_key.."float")
			s:Play("Float", true)
		end
		return
	end

	-- done：本层已复制，清醒跟随
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

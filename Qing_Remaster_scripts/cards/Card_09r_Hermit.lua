local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local pedestal_encounter = require("Qing_Remaster_scripts.others.Pedestal_Encounter_holder")
local save_elses_access = require("Qing_Remaster_scripts.auxiliary.save_elses_access")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Hermit_r,
	own_key = "Thoth_cd9r_Her_",
	-- Consumer Regression 只读；禁止业务分支读这些字段
	debug_cr = {
		triggered_new_generation = 0,
		triggered_fresh_generation = 0,
		ignored_same_generation = 0,
		last_generation_id = nil,
	},
	-- Hermit 自管：同 room appearance + OptionsPickupIndex>0 只计一次
	_room_seen_option_groups = {},
	_option_groups_room_epoch = nil,
}

local function get_state()
	local ret = {}
	for _, suffix in ipairs({"effect", "counter", "counter2", "counter3"}) do
		local key = item.own_key .. suffix
		if type(save.elses[key]) ~= "table" then
			save.elses[key] = {}
		end
		ret[suffix] = save.elses[key]
	end
	return ret
end

-- B: counter[idx] exists (incl. 0) => counter2[idx] must be numeric spawn count.
-- counter3[idx] is optional (Tarot Cloth extras; missing == 0).
local function require_pending_spawn_count(counter2, idx)
	local spawn_count = counter2[idx]
	if type(spawn_count) ~= "number" then
		return save_elses_access.state_invariant_fail(
			"Card_09r_Hermit invariant broken: counter exists without counter2"
		)
	end
	return spawn_count
end


function item.reset_debug_cr()
	item.debug_cr.triggered_new_generation = 0
	item.debug_cr.triggered_fresh_generation = 0
	item.debug_cr.ignored_same_generation = 0
	item.debug_cr.last_generation_id = nil
	item._room_seen_option_groups = {}
	item._option_groups_room_epoch = nil
end

function item.get_debug_cr()
	return {
		triggered_new_generation = item.debug_cr.triggered_new_generation or 0,
		triggered_fresh_generation = item.debug_cr.triggered_fresh_generation or 0,
		ignored_same_generation = item.debug_cr.ignored_same_generation or 0,
		last_generation_id = item.debug_cr.last_generation_id,
	}
end

local function sync_option_group_epoch()
	local epoch = unique_holder.get_room_generation_epoch and unique_holder.get_room_generation_epoch() or 0
	if item._option_groups_room_epoch ~= epoch then
		item._option_groups_room_epoch = epoch
		item._room_seen_option_groups = {}
	end
end

--- Hermit 对普通选择组去重（不进 Encounter Holder）。
local function should_consume_hermit_encounter(encounter)
	sync_option_group_epoch()
	local idx = tonumber(encounter and encounter.options_index) or 0
	if idx <= 0 then
		return true
	end
	if item._room_seen_option_groups[idx] then
		return false
	end
	item._room_seen_option_groups[idx] = true
	return true
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item._room_seen_option_groups = {}
	item._option_groups_room_epoch = nil
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."counter"] = {}
		save.elses[item.own_key.."counter2"] = {}
		save.elses[item.own_key.."counter3"] = {}
	end
	local st = get_state()
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	item._room_seen_option_groups = {}
	item._option_groups_room_epoch = nil
end,
})

--- 只消费普通 Pedestal Encounter；不监听 Death Certificate Display。
--- Encounter 已裁决 classification；禁止再用 Touched/Fresh 否决。
--- triggered_* 字段现表示「收到并消费了 normal Encounter」（兼容旧 CR 名）。
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_PEDESTAL_ENCOUNTER, params = nil,
Function = function(_, encounter)
	local st = get_state()
	local effects = st.effect
	if type(effects) ~= "table" or #effects <= 0 then
		return
	end
	local ent = encounter and encounter.pickup
	if not ent or not ent:Exists() then
		return
	end
	if not should_consume_hermit_encounter(encounter) then
		item.debug_cr.ignored_same_generation = (item.debug_cr.ignored_same_generation or 0) + 1
		return
	end

	item.debug_cr.last_generation_id = encounter.generation_id
	item.debug_cr.triggered_fresh_generation = (item.debug_cr.triggered_fresh_generation or 0) + 1
	item.debug_cr.triggered_new_generation = (item.debug_cr.triggered_new_generation or 0) + 1

	local room = Game():GetRoom()
	for i = #effects,1,-1 do
		local v = effects[i]
		v.cnt = (v.cnt or 7) - 1
		if v.cnt <= 0 then
			pedestal_encounter.with_suppressed_encounter(item.own_key, function()
				local q = unique_holder.with_missing(33, function()
					local q = Isaac.Spawn(5,100,v.id,room:FindFreePickupSpawnPosition(ent.Position,10,true),Vector(0,0),ent):ToPickup()
					auxi.self_morph(q,{5,100,v.id,})
					return q
				end)
				q.Touched = true
				q.Charge = (v.Charge or 0)
				pedestal_encounter.mark_suppressed(q, item.own_key)
			end)
			table.remove(effects,i)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	local st = get_state()
	if (st.counter[idx] or 0) > 0 then
		if player:IsExtraAnimationFinished() then
			local rng = player:GetCardRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			local col = auxi.get_random_item_that_player_has(player,rng,{ignore_pocket_item = true,})
			if col then 
				player:AnimateCollectible(col,"LiftItem","PlayerPickup")
				delay_buffer.addeffe(function(params)
					if player:IsHoldingItem() then
						player:AnimateCollectible(col,"HideItem","PlayerPickup")
						local tbl = {cnt = 7,id = col,}
						for slot = 0,1 do if player:GetActiveItem(slot) == col then tbl.Charge = player:GetActiveCharge(slot) + player:GetBatteryCharge(slot) break end end
						local st = get_state()
						table.insert(st.effect,#st.effect + 1,tbl)
						player:RemoveCollectible(col)
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
						local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player)
						local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),player)
						st.counter[idx] = st.counter[idx] - 1
					end
				end,{},15)
			else
				player:AnimateSad()
				st.counter[idx] = st.counter[idx] - 1
			end
		end
	elseif st.counter[idx] then
		local spawn_count = require_pending_spawn_count(st.counter2, idx)
		if not spawn_count then return end
		local room = Game():GetRoom()
		pedestal_encounter.with_suppressed_encounter(item.own_key, function()
			local st = get_state()
			for i = 1,spawn_count do
				local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				pedestal_encounter.mark_suppressed(q, item.own_key)
				if (st.counter3[idx] or 0) > 0 then
					local ndx = option_index_holder.find_a_new_index()
					q.OptionsPickupIndex = ndx
					local q2 = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
					q2.OptionsPickupIndex = ndx
					pedestal_encounter.mark_suppressed(q2, item.own_key)
					st.counter3[idx] = st.counter3[idx] - 1
				end
			end
		end)
		st.counter2[idx] = nil
		st.counter[idx] = nil
		st.counter3[idx] = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local cnt = 3
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then 
			local st = get_state()
			st.counter3[idx] = (st.counter3[idx] or 0) + 1
		end
		st.counter[idx] = (st.counter[idx] or 0) + cnt
		st.counter2[idx] = (st.counter2[idx] or 0) + 1
	end
end,
})


return item

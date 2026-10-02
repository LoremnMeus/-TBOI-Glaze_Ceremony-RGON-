-- 夜之摄取：任意战斗房可蓄力；屏幕噪声+牙吞噬；Blackout 统一结算。无 Shader / NightSlash。

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local night_vis = require("Qing_Remaster_scripts.items.ingestion_night_visual")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Ingestion_to_Night,
	night_vis = night_vis,
	PITCH_CHANCE = 0.25,
	CHARGE_FULL = 180,
	CHARGE_MIN_RELEASE = 90,
}

local STATE = {
	IDLE = "idle",
	CHARGING = "charging",
	RELEASING = "releasing",
	BLACKOUT = "blackout",
	RECOVER = "recover",
}

local DATA_KEY = "Ingestion2n"

local function room_is_pitch_black()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return false end
	return (desc.Flags & RoomDescriptor.FLAG_PITCH_BLACK) ~= 0
end

local function natural_night_blocked()
	-- 太阳：本层不再由本道具制造自然黑夜；摄取仍可用
	return save.elses.sol_use == true
end

local function charge_rate()
	local rate = 1
	if room_is_pitch_black() then rate = rate * 1.5 end
	if save.elses.r_sol_use == true then rate = math.max(rate, 1.5) end
	return rate
end

local function player_state(player, create)
	local d = player:GetData()
	if d[DATA_KEY] == nil and create then
		d[DATA_KEY] = {
			state = STATE.IDLE,
			counter = 0,
			release_t = 0,
			release_charge = 0,
			damage_done = false,
			saved_color = nil,
			input_lock = false,
		}
	end
	return d[DATA_KEY]
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function resolve_ingestion_damage(player, charge)
	if not player or not player:Exists() then return end
	local D = player.Damage
	local t = 0
	if charge >= item.CHARGE_FULL then
		t = 1
	elseif charge > item.CHARGE_MIN_RELEASE then
		t = (charge - item.CHARGE_MIN_RELEASE) / (item.CHARGE_FULL - item.CHARGE_MIN_RELEASE)
	end
	local normal_dmg = lerp(20 + 3 * D, 40 + 6 * D, t)
	local boss_mul = lerp(3, 5, t)
	local boss_pct = lerp(0.04, 0.08, t)
	if save.elses.r_sol_use then
		boss_pct = lerp(0.04, 0.10, t)
	end
	local pct_cap = 40 + 8 * D

	-- 清敌弹
	for _, proj in ipairs(Isaac.FindInRadius(player.Position, 2000, EntityPartition.BULLET)) do
		if proj and proj:Exists() then
			proj:Remove()
		end
	end

	local enemies = Isaac.FindInRadius(player.Position, 2000, EntityPartition.ENEMY)
	for _, ent in ipairs(enemies) do
		if ent:IsVulnerableEnemy() and ent:IsActiveEnemy() and not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			local is_boss = ent:IsBoss()
			local dmg = normal_dmg
			if is_boss then
				local maxhp = ent.MaxHitPoints or ent.HitPoints or 0
				local pct = math.min(pct_cap, maxhp * boss_pct)
				dmg = boss_mul * D + pct
			end
			ent:TakeDamage(dmg, 0, EntityRef(player), 0)
			if (not is_boss) and ent:Exists() and not ent:IsDead() then
				local hp = ent.HitPoints or 0
				if hp <= dmg * 1.25 then
					ent:Kill()
				end
			end
		end
	end

	sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_CARD, 1.0, 0.85, false, 0, 2)
end

local HIDE_PRIO = 220

local function set_player_hidden(player, st, hide)
	-- 禁止用 duration=9999 + GetColor 往返：恢复时短 duration 清不掉长 fade，角色会永久透明。
	st.hidden = hide and true or false
	if hide then
		player:SetColor(Color(1, 1, 1, 0, 0, 0, 0), 2, HIDE_PRIO, false, false)
	else
		-- 同优先级写回不透明，短持续即可覆盖隐藏层
		player:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 8, HIDE_PRIO, false, false)
		st.saved_color = nil
	end
end

local function refresh_player_hidden(player, st)
	if st and st.hidden then
		player:SetColor(Color(1, 1, 1, 0, 0, 0, 0), 2, HIDE_PRIO, false, false)
	end
end

local function begin_release(player, st)
	st.state = STATE.RELEASING
	st.release_t = 0
	st.release_charge = st.counter
	st.damage_done = false
	st.input_lock = true
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_GROW, 0.75, 0.7, false, 0, 1)
end

local function finish_recover(player, st)
	st.state = STATE.IDLE
	st.counter = 0
	st.release_t = 0
	st.release_charge = 0
	st.damage_done = false
	st.input_lock = false
	set_player_hidden(player, st, false)
end

local function tick_release(player, st)
	local p = night_vis.get_params()
	local recover_dur = p.recover_duration or 20
	-- ImGui 冻结 release_t：不推进逻辑，便于检查牙根/角度
	if night_vis.debug_freeze_release_t ~= nil and st.state == STATE.RELEASING then
		st.release_t = night_vis.debug_freeze_release_t
		return
	end
	st.release_t = (st.release_t or 0) + 1
	local t = st.release_t

	if st.state == STATE.RELEASING then
		-- 0–4 冻结；4–bite_move_start 显牙；start–end 合拢；end+ 进入 blackout
		local bite_end = p.bite_move_end or 20
		if t >= bite_end then
			st.state = STATE.BLACKOUT
			st.release_t = 0
			set_player_hidden(player, st, true)
			player:SetMinDamageCooldown(40)
		end
	elseif st.state == STATE.BLACKOUT then
		refresh_player_hidden(player, st)
		if (not st.damage_done) and t >= 4 then
			st.damage_done = true
			resolve_ingestion_damage(player, st.release_charge or st.counter)
		end
		if t >= (p.blackout_duration or 18) then
			st.state = STATE.RECOVER
			st.release_t = 0
			set_player_hidden(player, st, false)
		end
	elseif st.state == STATE.RECOVER then
		if t >= recover_dur then
			finish_recover(player, st)
		end
	end
end

local function pick_visual_focus()
	local best = nil
	local best_score = -1
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if auxi.has_have_coll(player, item.entity) then
			local st = player_state(player, false)
			if st then
				local score = st.counter or 0
				if st.state == STATE.RELEASING or st.state == STATE.BLACKOUT or st.state == STATE.RECOVER then
					score = score + 10000 + (st.release_charge or 0)
				end
				if score > best_score then
					best_score = score
					best = player
				end
			end
		end
	end
	return best
end

local function push_visual()
	local focus = pick_visual_focus()
	if not focus then
		night_vis.set_frame_state({active = false, phase = "idle", counter = 0})
		return
	end
	local st = player_state(focus, true)
	local counter = st.counter
	if st.state == STATE.RELEASING or st.state == STATE.BLACKOUT or st.state == STATE.RECOVER then
		counter = math.max(counter, st.release_charge or counter)
	end
	local active = (st.state ~= STATE.IDLE) or (counter > 0)
	night_vis.set_frame_state({
		active = active,
		counter = counter,
		release_t = st.release_t or 0,
		phase = st.state,
		player_screen = night_vis.world_to_screen(focus.Position + focus.PositionOffset),
		pitch_black = room_is_pitch_black(),
		reverse_sun = save.elses.r_sol_use == true,
		seed = Game():GetRoom():GetSpawnSeed() % 100000,
		damage_resolved = st.damage_done,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cnt <= 0 then return end
	if cacheFlag == CacheFlag.CACHE_FLYING then
		player.CanFly = true
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_, player, collid, cnt, touched)
	if natural_night_blocked() then return end
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
	if desc then
		desc.Flags = desc.Flags | RoomDescriptor.FLAG_PITCH_BLACK
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	night_vis.clear_all()
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		local st = player_state(p, false)
		if st then
			finish_recover(p, st)
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local holder = auxi.have_player_has_collectible(item.entity)
	if not holder then return end
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
	if not desc then return end

	if natural_night_blocked() then
		desc.Flags = desc.Flags & (~RoomDescriptor.FLAG_PITCH_BLACK)
		return
	end

	if save.elses.r_sol_use then
		-- 逆太阳：新战斗房一律黑夜（首次进入）
		if room:IsFirstVisit() then
			desc.Flags = desc.Flags | RoomDescriptor.FLAG_PITCH_BLACK
		end
	elseif room:IsFirstVisit() then
		local rng = holder:GetCollectibleRNG(item.entity)
		if rng:RandomFloat() < item.PITCH_CHANCE then
			desc.Flags = desc.Flags | RoomDescriptor.FLAG_PITCH_BLACK
		end
		rng:Next()
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses.sol_use = false
	save.elses.r_sol_use = false
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses.sol_use = false
		save.elses.r_sol_use = false
	end
	night_vis.clear_all()
end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_, ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if not player or not auxi.has_have_coll(player, item.entity) then return end
	local st = player_state(player, false)
	if not st then return end
	if st.state == STATE.BLACKOUT or st.state == STATE.RELEASING then
		return false
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_CARD, params = Card.CARD_SUN,
Function = function(_, cardtype, player, useflags)
	if not auxi.has_have_coll(player, item.entity) then return end
	save.elses.sol_use = true
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
	if desc then
		desc.Flags = desc.Flags & (~RoomDescriptor.FLAG_PITCH_BLACK)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_CARD, params = Card.CARD_REVERSE_SUN,
Function = function(_, cardtype, player, useflags)
	if not auxi.has_have_coll(player, item.entity) then return end
	save.elses.sol_use = false
	save.elses.r_sol_use = true
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
	if desc then
		desc.Flags = desc.Flags | RoomDescriptor.FLAG_PITCH_BLACK
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if not auxi.has_have_coll(player, item.entity) then goto continue end
		if not auxi.g_dir_can_work(player) then goto continue end
		local st = player_state(player, true)

		if st.state == STATE.RELEASING or st.state == STATE.BLACKOUT or st.state == STATE.RECOVER then
			tick_release(player, st)
			-- 释放中锁定速度
			if st.input_lock then
				player.Velocity = player.Velocity * 0.15
			end
			goto continue
		end

		local ctrlid = player.ControllerIndex
		local act = false
		for a = 4, 7 do
			if Input.IsActionTriggered(a, ctrlid) or Input.IsActionPressed(a, ctrlid) then
				act = true
				break
			end
		end

		if act then
			st.state = STATE.CHARGING
			st.counter = (st.counter or 0) + charge_rate()
		else
			if st.state == STATE.CHARGING then
				if (st.counter or 0) >= item.CHARGE_MIN_RELEASE then
					begin_release(player, st)
				else
					st.counter = 0
					st.state = STATE.IDLE
				end
			end
		end
		::continue::
	end
	push_visual()
end,
})

-- 释放期间拦截射击/道具输入
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_, ent, hook, button)
	local player = ent and ent:ToPlayer()
	if not player then return end
	local st = player_state(player, false)
	if not st or not st.input_lock then return end
	if button >= ButtonAction.ACTION_SHOOTLEFT and button <= ButtonAction.ACTION_SHOOTDOWN then
		if hook == InputHook.GET_ACTION_VALUE then return 0 end
		return false
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	push_visual()
	night_vis.render()

	-- 轻环境音
	local focus = pick_visual_focus()
	if focus and not Game():IsPaused() then
		local st = player_state(focus, false)
		if st and (st.counter or 0) > 40 and st.state == STATE.CHARGING then
			if math.random(10000) > 9200 then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_CARD, math.min(0.45, (st.counter or 0) / 400), 0.9, false, math.random(3) - 2, 2)
			end
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_, player, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	if not auxi.has_have_coll(player, item.entity) then return end
	local st = player_state(player, true)
	if st.state == STATE.RELEASING or st.state == STATE.BLACKOUT or st.state == STATE.RECOVER then return end
	local cnt = st.counter or 0
	-- 兼容旧 Charging_Bar 字段名
	player:GetData()["Ingestion2n_counter"] = cnt
	Charging_Bar_holder.render_me(player, {
		name1 = "Ingestion2n_counter",
		name2 = "Ingestion2n_sprite",
		name3 = "I_2_N",
		loadname = "gfx/effects/chargebar/chargebar_I_t_N.anm2",
		check1 = function() return cnt > 5 end,
		check2 = function() return cnt >= item.CHARGE_FULL end,
		check3 = function() return math.ceil(cnt / 1.8) end,
		signal1 = function() end,
	})
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_, player, collid, count)
	if collid == item.entity and count < 0 then
		Charging_Bar_holder.remove_charge_bar(player, "I_2_N")
		local st = player_state(player, false)
		if st then finish_recover(player, st) end
		night_vis.clear_all()
	end
end,
})

return item

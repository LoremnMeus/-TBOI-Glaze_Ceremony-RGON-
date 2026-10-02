local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Pause_Screen_holder = require("Qing_Remaster_scripts.others.Pause_Screen_holder")
local time_holder = require("Qing_Remaster_scripts.others.Time_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Pause_,
	own_key = "Trinkets_Pause__",
	-- 栏位黑化自旋 → 飞向玩家举起位；无栏位则从正上方旋落
	blacken_frames = 14,
	fly_arrive_dist = 10,
	fly_lerp = 0.2,
	fly_max_frames = 36,
	above_offset = Vector(0, -56),
	spin_blacken = 8,
	spin_fly = 6,
	buffs = {
		[1] = {name = "speed",cache = CacheFlag.CACHE_SPEED,
			toget = function(player) return player.MoveSpeed end,mul = 0.05,},
		[2] = {name = "tear",cache = CacheFlag.CACHE_FIREDELAY,
			toget = function(player) return 30 / (player.MaxFireDelay + 1) end,mul = 0.15,},
		[3] = {name = "damage",cache = CacheFlag.CACHE_DAMAGE,
			toget = function(player) return player.Damage end,mul = 0.5,},
		[4] = {name = "range",cache = CacheFlag.CACHE_RANGE,
			toget = function(player) return player.TearRange end,mul = 1 * 40,},
		[5] = {name = "luck",cache = CacheFlag.CACHE_LUCK,
			toget = function(player) return player.Luck end,mul = 1,},
	},
}

local function pending_tbl()
	save.elses[item.own_key.."pending_break"] = save.elses[item.own_key.."pending_break"] or {}
	return save.elses[item.own_key.."pending_break"]
end

local function player_controllable(player)
	if not player or not player:Exists() then return false end
	if Game():IsPaused() then return false end
	if player:AreControlsEnabled() ~= true then return false end
	if player:IsExtraAnimationFinished() ~= true then return false end
	if player:IsDead() then return false end
	return true
end

local function trinket_base_id(tid)
	tid = tid or 0
	if tid <= 0 then return 0 end
	local golden = TrinketType.TRINKET_GOLDEN_FLAG or 32768
	return tid % golden
end

local function find_pause_slot(player)
	for slot = 0, 1 do
		local tid = player:GetTrinket(slot) or 0
		if trinket_base_id(tid) == item.entity then
			return slot, tid
		end
	end
	return nil, nil
end

local function ceremony_of(player)
	return player:GetData()[item.own_key.."ceremony"]
end

local function clear_ceremony(player)
	player:GetData()[item.own_key.."ceremony"] = nil
end

local function set_hud_hide(player, on, slot)
	local d = player:GetData()
	d[item.own_key.."hide_hud"] = on and true or nil
	if on then
		if slot ~= nil then
			d[item.own_key.."hide_slot"] = slot
		end
	else
		d[item.own_key.."hide_slot"] = nil
	end
end

local function hud_hide_active(player)
	return player:GetData()[item.own_key.."hide_hud"] == true
end

local function hud_hide_slot(player)
	return player:GetData()[item.own_key.."hide_slot"]
end

-- RGON 饰品栏 Position = 32x32 图标框左上角（同主动槽 Offset 语义）。
-- 中心锚点贴图（Idle_midpivot / 愚昧 any.anm2）须 + (16,16)*scale，见 benighted soul ModelingClay。
local function trinket_hud_center(position, scale)
	scale = tonumber(scale) or 1
	return Vector(position.X + 16 * scale, position.Y + 16 * scale)
end

local function pause_in_slot(player, slot)
	if not player or slot == nil then return false end
	return trinket_base_id(player:GetTrinket(slot) or 0) == item.entity
end

local function apply_black_color(sprite, black_t, alpha)
	black_t = math.max(0, math.min(1, black_t or 1))
	alpha = alpha == nil and 1 or alpha
	local dim = 1 - 0.92 * black_t
	local col = Color(dim, dim, dim, alpha, 0, 0, 0)
	if col.SetColorize then
		col:SetColorize(0, 0, 0, black_t)
	end
	sprite.Color = col
end

local function make_black_trinket_sprite(tid)
	local s = auxi.load_trinket(trinket_base_id(tid) > 0 and tid or item.entity, {Anim = "Idle_midpivot"})
	apply_black_color(s, 1, 1)
	return s
end

-- 玩家举起位（屏幕坐标，与透特/法之书同口径）
local function player_hold_screen_pos(player)
	local pos = player.Position
	if player.PositionOffset then
		pos = pos + player.PositionOffset
	end
	return Isaac.WorldToScreen(pos) + Vector(0, -26)
end

-- Sprite.Rotation 绕 pivot；Idle_midpivot 已是几何中心，Render 点即视觉中心
local function render_trinket_at(sprite, pos)
	if not sprite or not pos then return end
	sprite:Render(pos, Vector(0, 0), Vector(0, 0))
end

local function begin_lift(player, tid, hide_slot)
	if not auxi.check_all_exists(player) then return end
	-- 移除前持续屏蔽「原槽」；清掉饰品后仍按 hide_slot return true，避免闪 1 帧
	set_hud_hide(player, true, hide_slot)
	if player:HasTrinket(item.entity, true) then
		player:TryRemoveTrinket(item.entity)
	end
	local s = make_black_trinket_sprite(tid or item.entity)
	player:AnimatePickup(s, true, "LiftItem")
	delay_buffer.addeffe(function()
		if auxi.check_all_exists(player) and player:IsHoldingItem() then
			player:AnimatePickup(s, true, "HideItem")
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF, 1, 1, false, 0, 2)
			Isaac.Spawn(1000, 16, 2, player.Position, Vector(0, 0), player)
			Isaac.Spawn(1000, 16, 1, player.Position, Vector(0, 0), player)
		end
		if auxi.check_all_exists(player) then
			set_hud_hide(player, false)
		end
	end, {}, 18)
end

local function finish_to_lift(player, cer)
	local tid = cer and cer.tid
	local slot = cer and cer.slot
	-- 先开 hide（带槽），再清 ceremony，避免中间帧露栏位 / 丢屏蔽目标
	set_hud_hide(player, true, slot)
	clear_ceremony(player)
	begin_lift(player, tid, slot)
end

local function start_from_above(player, tid)
	local hold = player_hold_screen_pos(player)
	local spr = auxi.load_trinket(tid or item.entity, {Anim = "Idle_midpivot"})
	spr.Rotation = 0
	spr.Scale = Vector(1, 1)
	apply_black_color(spr, 1, 1)
	set_hud_hide(player, true, nil)
	player:GetData()[item.own_key.."ceremony"] = {
		phase = "fly",
		source = "above",
		slot = nil,
		tid = tid or item.entity,
		sprite = spr,
		age = 0,
		rot = 0,
		hud_scale = 1,
		center = hold + item.above_offset,
		hide_hud = true,
	}
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSDOWN_AMPLIFIED, 0.45, 0.9, false, 0, 1)
	return true
end

local function start_ceremony(player)
	if not player:HasTrinket(item.entity, true) then return false end
	local slot, tid = find_pause_slot(player)
	if slot == nil then
		return start_from_above(player, item.entity)
	end
	local spr = auxi.load_trinket(tid, {Anim = "Idle_midpivot"})
	spr.Rotation = 0
	apply_black_color(spr, 0, 1)
	set_hud_hide(player, true, slot)
	player:GetData()[item.own_key.."ceremony"] = {
		phase = "wait_hud",
		source = "hud",
		slot = slot,
		tid = tid,
		sprite = spr,
		age = 0,
		rot = 0,
		hud_pos = nil,
		hud_scale = 1,
		center = nil,
		hide_hud = true,
	}
	return true
end

local function tick_ceremony(player, cer)
	if not cer then return end

	if cer.phase == "wait_hud" then
		cer.age = (cer.age or 0) + 1
		if cer.center then
			cer.phase = "blacken"
			cer.age = 0
			return
		end
		-- HUD 迟迟不给出栏位 → 当作栏位不可见，改上方旋落
		if cer.age > 10 then
			start_from_above(player, cer.tid)
		end
		return
	end

	if cer.phase == "blacken" then
		cer.age = cer.age + 1
		local t = cer.age / item.blacken_frames
		cer.rot = (cer.rot or 0) + item.spin_blacken
		if cer.sprite then
			cer.sprite.Rotation = cer.rot
			apply_black_color(cer.sprite, math.min(1, t), 1)
			local sc = cer.hud_scale or 1
			cer.sprite.Scale = Vector(sc, sc)
		end
		if cer.age >= item.blacken_frames then
			cer.phase = "fly"
			cer.age = 0
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSDOWN_AMPLIFIED, 0.55, 0.85, false, 0, 1)
		end
		return
	end

	if cer.phase == "fly" then
		cer.age = (cer.age or 0) + 1
		cer.rot = (cer.rot or 0) + item.spin_fly
		local dest = player_hold_screen_pos(player)
		cer.center = cer.center or dest
		-- 每帧常数 lerp 追举起位（目标会动，见 hud_screen_fly_vfx_patterns）
		cer.center = cer.center + (dest - cer.center) * item.fly_lerp
		if cer.sprite then
			cer.sprite.Rotation = cer.rot
			apply_black_color(cer.sprite, 1, 1)
			local sc = cer.hud_scale or 1
			if cer.source == "hud" then
				-- 略放大贴近举起尺寸
				local grow = math.min(1.35, 1 + 0.35 * math.min(1, cer.age / 18))
				cer.sprite.Scale = Vector(sc * grow, sc * grow)
			else
				cer.sprite.Scale = Vector(1, 1)
			end
		end
		local dist = (dest - cer.center):Length()
		if dist <= item.fly_arrive_dist or cer.age >= item.fly_max_frames then
			finish_to_lift(player, cer)
		end
		return
	end
end

local function render_ceremony(player, cer)
	if not cer or not cer.sprite then return end
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	if cer.source == "hud" and not Game():GetHUD():IsVisible() then return end
	local center = cer.center
	if not center then return end
	if cer.phase == "wait_hud" then return end
	render_trinket_at(cer.sprite, center)
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	if Game():IsPaused() and auxi.have_player_has_trinket(item.entity, true) then
		if time_holder.IsUpper() ~= true then return end
		local state = Pause_Screen_holder.currentState
		if state and state.name ~= "UNPAUSED" and state.name ~= "IN_BED" then
			local pending = pending_tbl()
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				if player:HasTrinket(item.entity, true) then
					local idx = player:GetData().__Index
					if idx ~= nil then
						pending[tostring(idx)] = true
					end
				end
			end
		end
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		render_ceremony(player, ceremony_of(player))
	end
end,
})

if REPENTOGON and ModCallbacks.MC_PRE_PLAYERHUD_TRINKET_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PLAYERHUD_TRINKET_RENDER, params = nil,
	-- 签名与 Fiend Folio / Book_of_Voice 一致：(_, Slot, Position, Scale, Player, CropOffset)
	Function = function(_, slot, position, scale, player, _)
		if type(slot) ~= "number" or not position or not player then return end
		local hiding = hud_hide_active(player)
		local hide_slot = hud_hide_slot(player)
		local is_pause = pause_in_slot(player, slot)
		-- 移除后 GetTrinket 已空：仍按 hide_slot 屏蔽，杜绝飞完→举起间闪 1 帧
		if not (is_pause or (hiding and hide_slot == slot)) then return end
		if not hiding and not (ceremony_of(player) and ceremony_of(player).hide_hud) then
			return
		end
		local cer = ceremony_of(player)
		if cer and is_pause then
			local sc = tonumber(scale) or 1
			local center = trinket_hud_center(position, sc)
			cer.slot = slot
			cer.hud_pos = Vector(position.X, position.Y)
			cer.hud_scale = sc
			if cer.phase == "wait_hud" or cer.center == nil then
				cer.center = center
				if cer.sprite then
					cer.sprite.Scale = Vector(sc, sc)
					cer.sprite.Rotation = 0
				end
				if cer.phase == "wait_hud" then
					cer.phase = "blacken"
					cer.age = 0
				end
			elseif cer.phase == "blacken" then
				cer.center = center
			end
		end
		return true
	end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	local idx = player:GetData().__Index
	if idx == nil then return end
	local key = tostring(idx)
	local cer = ceremony_of(player)
	if cer then
		if not player:HasTrinket(item.entity, true) and cer.phase ~= "fly" then
			clear_ceremony(player)
			set_hud_hide(player, false)
			pending_tbl()[key] = nil
			return
		end
		tick_ceremony(player, cer)
		return
	end

	-- 举起后已无 ceremony，但仍可能短暂持有：直到真正失去才关屏蔽
	if hud_hide_active(player) and not player:HasTrinket(item.entity, true) then
		set_hud_hide(player, false)
	end

	local pending = pending_tbl()
	if not pending[key] then return end

	local state = Pause_Screen_holder.currentState
	local unpaused = (not Game():IsPaused()) or (state and (state.name == "UNPAUSED" or state.name == "UNPAUSING" or state.name == "MAIN_OUT"))
	if not unpaused then return end
	if not player_controllable(player) then return end
	if not player:HasTrinket(item.entity, true) then
		pending[key] = nil
		return
	end

	if start_ceremony(player) then
		pending[key] = nil
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."pending_break"] = {}
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		clear_ceremony(p)
		set_hud_hide(p, false)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	if player:HasTrinket(item.entity) then
		local mul = math.sqrt(player:GetTrinketMultiplier(item.entity))
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + mul * item.buffs[1].mul
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay, auxi.get_mxdelay_multiplier(player) * mul * item.buffs[2].mul)
		end
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * mul * item.buffs[3].mul
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + mul * item.buffs[4].mul
		end
		if cacheFlag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + mul * item.buffs[5].mul
		end
	end
end,
})

return item

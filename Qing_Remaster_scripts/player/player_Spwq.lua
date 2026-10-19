local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")

local item

local function blueprint_panel_open(player)
	local ok, bp = pcall(require, "Qing_Remaster_scripts.items.Item_Blue_Print")
	if not ok or not bp or not bp.is_panel_open then return false end
	return bp.is_panel_open(player) == true
end

local function get_bandwidth()
	return require("Qing_Remaster_scripts.mimics.Craft_Bandwidth_Manager")
end

local function get_blueprint()
	local ok, bp = pcall(require, "Qing_Remaster_scripts.items.Item_Blue_Print")
	if ok then return bp end
end

local function spawn_command_mark(player, pos)
	local origin = pos or player.Position
	local q = Isaac.Spawn(1000, enums.Entities.QingsMarks, 0, origin, Vector(0, 0), player)
	local md = q:GetData()
	md.Player = player
	q.GridCollisionClass = 3
	q.DepthOffset = item.MARK_DEPTH_OFFSET
	local spr = q:GetSprite()
	if spr then
		-- anm2 Default=GuardLock；显式 Play 保证首帧呼吸轴一致
		if spr.IsPlaying and not spr:IsPlaying("GuardLock") then
			spr:Play("GuardLock", true)
		elseif spr.Play then
			spr:Play("GuardLock", true)
		end
	end
	if origin:Distance(player.Position) <= item.MARK_HIDE_RADIUS then
		md.qing_near_hidden = true
		md.qing_mark_alpha = 0
		q.Position = player.Position
		q.Velocity = Vector.Zero
		q.Visible = false
	end
	return q
end

-- 火控定色相：Lock 冷青蓝 / Suppress 警戒红；阵型只换中心符号
local MARK_LOCK_OUTER = Color(0.388, 0.741, 0.922, 1, 0, 0, 0) -- #63BDEB
local MARK_LOCK_INNER = Color(0.757, 0.898, 0.969, 1, 0, 0, 0) -- #C1E5F7
local MARK_SUPPRESS_OUTER = Color(0.933, 0.361, 0.408, 1, 0, 0, 0) -- #EE5C68
local MARK_SUPPRESS_INNER = Color(0.976, 0.741, 0.757, 1, 0, 0, 0) -- #F9BDC1

local function get_mark_anim(is_guard, is_suppress)
	if is_guard then
		return is_suppress and "GuardSuppress" or "GuardLock"
	end
	return is_suppress and "AttackSuppress" or "AttackLock"
end

--- 切四姿态动画时保留当前帧，避免呼吸环跳回第 0 帧。
local function play_mark_anim_keep_frame(sprite, anim)
	if not sprite or not anim then return end
	local old_anim = sprite.GetAnimation and sprite:GetAnimation() or nil
	if old_anim == anim then
		if sprite.IsPlaying and not sprite:IsPlaying(anim) and sprite.Play then
			sprite:Play(anim, true)
		end
		return
	end
	local old_frame = (sprite.GetFrame and sprite:GetFrame()) or 0
	sprite:Play(anim, true)
	local len = 4
	if sprite.GetCurrentAnimationData then
		local ok, data = pcall(function() return sprite:GetCurrentAnimationData() end)
		if ok and data and data.GetLength then
			local ok2, l = pcall(function() return data:GetLength() end)
			if ok2 and type(l) == "number" and l > 0 then
				len = l
			end
		end
	end
	local frame = math.min(math.max(0, old_frame), math.max(0, len - 1))
	if sprite.SetFrame then
		local ok = pcall(function() sprite:SetFrame(anim, frame) end)
		if not ok then
			pcall(function() sprite:SetFrame(frame) end)
		end
	end
end

local function set_mark_layer_color(sprite, layer_name, color)
	if not sprite or not sprite.GetLayer or not color then return end
	local ok, layer = pcall(function() return sprite:GetLayer(layer_name) end)
	if ok and layer and layer.SetColor then
		layer:SetColor(color)
	end
end

local function apply_mark_visual(sprite, control, alpha)
	if not sprite then return end
	alpha = tonumber(alpha)
	if alpha == nil then alpha = 1 end
	if alpha < 0 then
		alpha = 0
	elseif alpha > 1 then
		alpha = 1
	end
	local BW = get_bandwidth()
	local fire = control and control.fire_control_mode or 0
	local form = control and control.formation_mode or 0
	local is_guard = form == (BW.FORMATION_GUARD or 1)
	local is_suppress = fire == (BW.FIRE_FORCE or 1)
	local anim = get_mark_anim(is_guard, is_suppress)
	play_mark_anim_keep_frame(sprite, anim)

	-- 整体 alpha / 近身缩放；层色按火控：Outer 主色 + Inner 同系高亮
	local scale = 0.75 + 0.25 * alpha
	sprite.Scale = Vector(scale, scale)
	sprite.Color = Color(1, 1, 1, alpha, 0, 0, 0)
	local outer_color, inner_color
	if is_suppress then
		outer_color = MARK_SUPPRESS_OUTER
		inner_color = MARK_SUPPRESS_INNER
	else
		outer_color = MARK_LOCK_OUTER
		inner_color = MARK_LOCK_INNER
	end
	set_mark_layer_color(sprite, "Outer", outer_color)
	set_mark_layer_color(sprite, "Inner", inner_color)
end

local function snap_mark_toward_player(ent, player)
	local delta = player.Position - ent.Position
	if delta:Length() < item.MARK_SNAP_PIN then
		ent.Position = player.Position
	else
		ent.Position = ent.Position + delta * item.MARK_SNAP_BLEND
	end
	ent.Velocity = Vector.Zero
end

local function update_command_mark_near(player, ent, desired_vel, use_mouse)
	local md = ent:GetData()
	local dist = ent.Position:Distance(player.Position)
	local mouse_delta
	local mouse_dist
	if use_mouse then
		mouse_delta = auxi.mouse_world_pos() - player.Position
		mouse_dist = mouse_delta:Length()
	end

	if md.qing_near_hidden == true then
		snap_mark_toward_player(ent, player)
		local should_unhide = false
		local exit_dir
		if use_mouse then
			if mouse_dist >= item.MARK_SHOW_RADIUS then
				should_unhide = true
				exit_dir = mouse_delta:Normalized()
			end
		elseif desired_vel:Length() > item.MARK_UNHIDE_VEL then
			should_unhide = true
			exit_dir = desired_vel:Normalized()
		end
		if should_unhide == true and exit_dir then
			ent.Position = player.Position + exit_dir * item.MARK_SHOW_RADIUS
			ent.Velocity = desired_vel
			md.qing_near_hidden = false
		end
	else
		ent.Velocity = desired_vel
		local want_hide = dist <= item.MARK_HIDE_RADIUS
		if want_hide then
			if use_mouse then
				want_hide = mouse_dist <= item.MARK_HIDE_RADIUS
			else
				want_hide = desired_vel:Length() <= item.MARK_UNHIDE_VEL
			end
		end
		if want_hide then
			md.qing_near_hidden = true
			snap_mark_toward_player(ent, player)
		end
	end

	local target_alpha = (md.qing_near_hidden == true) and 0 or 1
	local alpha = tonumber(md.qing_mark_alpha)
	if alpha == nil then
		alpha = target_alpha
	end
	alpha = alpha + (target_alpha - alpha) * item.MARK_ALPHA_SPEED
	if math.abs(alpha - target_alpha) < 0.02 then
		alpha = target_alpha
	end
	md.qing_mark_alpha = alpha
	ent.Visible = alpha > 0.01
	return alpha
end

local function clear_blueprint_hold(player)
	if not player then return end
	local d = player:GetData()
	d[item.own_key.."bp_hold"] = nil
	Charging_Bar_holder.remove_charge_bar(player, item.own_key, true)
	d[item.own_key.."_Charge_Bar_buff"] = 0
end

local function pause_blocks_formation()
	if Game():IsPaused() then return true end
	if auxi.is_pause_menu_open() then return true end
	return false
end

-- 蓝图关面板的那一次 Ctrl/RMB/MMB 不得立刻切阵型或压制；只记下当前按住状态。
local function seed_formation_hold(player)
	if not player or player:GetPlayerType() ~= item.entity then return end
	local d = player:GetData()
	d[item.own_key.."form_mouse"] = auxi.qing_formation_mouse_down(player)
	d[item.own_key.."fire_mouse"] = auxi.qing_fire_mouse_down(player)
	d[item.own_key.."form_key"] = auxi.qing_formation_key_down(player, ModConfig.ModConfigSettings.Off_air_key)
	d[item.own_key.."form_key_r"] = d[item.own_key.."form_key"]
end

local function apply_formation_toggle(player, d)
	if pause_blocks_formation() then return false end
	if blueprint_panel_open(player) then return false end
	local frame = Game():GetFrameCount()
	if d[item.own_key.."FormShiftFrame"] == frame then return false end
	local debounce = tonumber(d[item.own_key.."FormShift"]) or 0
	if debounce > 0 then return false end
	get_bandwidth().toggle_formation_mode(player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.55, 1.1, false, 0, 2)
	d[item.own_key.."FormShift"] = 8
	d[item.own_key.."FormShiftFrame"] = frame
	return true
end

local function tick_formation_key(player, d, store_key)
	store_key = store_key or (item.own_key.."form_key")
	local down = auxi.qing_formation_key_down(player, ModConfig.ModConfigSettings.Off_air_key)
	local prev = d[store_key] == true
	d[store_key] = down
	if down and not prev then
		apply_formation_toggle(player, d)
	end
end

local function tick_formation_mouse(player, d)
	local down = auxi.qing_formation_mouse_down(player)
	local prev = d[item.own_key.."form_mouse"] == true
	d[item.own_key.."form_mouse"] = down
	if down and not prev then
		apply_formation_toggle(player, d)
	end
end

local function apply_fire_toggle(player, d)
	if pause_blocks_formation() then return false end
	if blueprint_panel_open(player) then return false end
	local frame = Game():GetFrameCount()
	if d[item.own_key.."FireShiftFrame"] == frame then return false end
	local debounce = tonumber(d[item.own_key.."FireShift"]) or 0
	if debounce > 0 then return false end
	get_bandwidth().toggle_fire_control_mode(player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.55, 1.05, false, 0, 2)
	d[item.own_key.."FireShift"] = 8
	d[item.own_key.."FireShiftFrame"] = frame
	return true
end

local function tick_fire_mouse(player, d)
	local down = auxi.qing_fire_mouse_down(player)
	local prev = d[item.own_key.."fire_mouse"] == true
	d[item.own_key.."fire_mouse"] = down
	if down and not prev then
		apply_fire_toggle(player, d)
	end
end

local function blueprint_hold_button(player)
	if player:GetActiveItem(ActiveSlot.SLOT_POCKET) == enums.Items.Blue_Print then
		return ButtonAction.ACTION_PILLCARD
	end
	return ButtonAction.ACTION_ITEM
end

item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Players.Spwq,
	own_key = "Player_Spwq_",
	HOLD_OPEN_FRAMES = 26,
	-- 准星近身：18 吸附隐藏 / 28 推出显示；24 才更新 BW aim（围绕原 note_aim 中线）
	MARK_HIDE_RADIUS = 18,
	MARK_SHOW_RADIUS = 28,
	MARK_AIM_RADIUS = 24,
	MARK_DEPTH_OFFSET = -20,
	MARK_UNHIDE_VEL = 0.5,
	MARK_SNAP_BLEND = 0.45,
	MARK_SNAP_PIN = 1,
	MARK_ALPHA_SPEED = 0.3,
	Special_Des = {
		["zh"] = {
			["Item"] = {
				[enums.Items.Touchstone] = {Name = "弑金刃" , Description = "...",},
				[enums.Items.Cheater_s_Blessing] = {Name = "某人的帽子？",Description = "大小刚好？",},
				[enums.Items.Assassin_s_Eye] = {Name = "某人的左眼？",Description = "死亡在其中！",},
				[enums.Items.Air_Flight] = {Name = "末日之羽",Description = "协我飞升",},
				[enums.Items.The_Watcher] = {Name = "航空管制",Description = "切莫驻足！",},
				[enums.Items.Memory] = {Name = "回忆",Description = "我忘了什么吗？",},
				[enums.Items.My_Best_Friend] = {Name = "最好的朋友？",Description = "是谁呢？",},
				[enums.Items.Air_Terror] = {Name = "末日之泪",Description = "协我飞升",},
				[enums.Items.My_Emblem] = {Name = "某人的纹章？",Description = "它们有家？",},
				[enums.Items.Hypermnesia] = {Name = "超忆症",Description = "我想起来了！",},
			},
		},
		["en"] = {
			["Item"] = {
			},
		},
	},
}

item.seed_formation_hold = seed_formation_hold
item._room_epoch = 0
item._room_epoch_seen = {}

function item.begin_blueprint_hold(player)
	if not player then return end
	local d = player:GetData()
	if type(d[item.own_key.."bp_hold"]) ~= "table" then
		d[item.own_key.."bp_hold"] = {frames = 0, consumed = false}
	end
end

function item.get_control(player)
	return get_bandwidth().get_control(player)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if player:GetPlayerType() == item.entity then
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed - 0.15
		end
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage - 0.5 * auxi.get_damage_multiplier(player)
		end
		if cacheFlag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck * 0.66
		end
		if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange - 20
		end
	end
end,
})

-- 右键/中键必须在 Render 采样：Update 里 RGON/SDL 经常读成未按下。
table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	priority = -10001,
	Function = function()
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and player:GetPlayerType() == item.entity and not player:IsDead() then
				local d = player:GetData()
				if pause_blocks_formation() then
					d[item.own_key.."form_mouse"] = auxi.qing_formation_mouse_down(player)
					d[item.own_key.."fire_mouse"] = auxi.qing_fire_mouse_down(player)
					d[item.own_key.."form_key_r"] = auxi.qing_formation_key_down(player, ModConfig.ModConfigSettings.Off_air_key)
				else
					tick_formation_mouse(player, d)
					tick_fire_mouse(player, d)
					tick_formation_key(player, d, item.own_key.."form_key_r")
				end
			end
		end
	end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = nil,
Function = function(_,ent)
	if ent.Variant == 30 or ent.Variant == 153 or ent.Variant == enums.Entities.QingsMarks then
		local s = ent:GetSprite()
		local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
		local d2 = player:GetData()
		if player:GetPlayerType() == item.entity then
			if d2[item.own_key.."time"] == nil or Game():GetFrameCount() - d2[item.own_key.."time"] > 5 then
				d2[item.own_key.."Focus_target"] = ent
				d2[item.own_key.."time"] = Game():GetFrameCount()
			end
			if ent.Variant == enums.Entities.QingsMarks then
				local mouse_opts = {block_mouse = blueprint_panel_open(player)}
				local desired_vel = auxi.qing_mark_velocity(
					player,
					ent,
					ModConfig.ModConfigSettings.mouseSupport1,
					ModConfig.ModConfigSettings.mouseSupport2,
					mouse_opts
				)
				local use_mouse = auxi.qing_mark_mouse_follow(
					player,
					ModConfig.ModConfigSettings.mouseSupport1,
					ModConfig.ModConfigSettings.mouseSupport2,
					mouse_opts
				)
				local alpha = update_command_mark_near(player, ent, desired_vel, use_mouse)
				ent.DepthOffset = item.MARK_DEPTH_OFFSET
				local BW = get_bandwidth()
				local control = BW.get_control(player)
				local aim = ent.Position - player.Position
				if aim:Length() > item.MARK_AIM_RADIUS then
					BW.note_aim(player, aim)
				end
				apply_mark_visual(s, control, alpha)
			end
		end
	end
end,
})
--[[
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local room = Game():GetRoom()
	if player:GetPlayerType() == item.entity then
		if (room:GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			local d = player:GetData()
			local cnt = d[item.own_key.."Mov_buff"] or 0
			Charging_Bar_holder.render_me(player,{name1 = item.own_key,name2 = item.own_key,name3 = item.own_key,loadname = "gfx/effects/chargebar/chargebar_Qing.anm2",
				check1 = nil,
				check2 = function(val,ent) 
					return cnt > 100 * auxi.get_level_stat_of_spwq() * ((d[item.own_key.."cnt"] or 0) + 1) * 3
				end,
				check3 = function(val,ent)
					return math.ceil(cnt /(auxi.get_level_stat_of_spwq() * ((d[item.own_key.."cnt"] or 0) + 1) * 3))
				end,
				signal1 = function(ent)
					ent:GetData()[item.own_key.."eval"] = true
				end,
			})
		end
	end
end,
})
--]]
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	if player:GetPlayerType() ~= item.entity then return end
	if player:IsDead() then
		clear_blueprint_hold(player)
		return
	end
	local BW = get_bandwidth()
	local epoch = item._room_epoch or 0
	item._room_epoch_seen = item._room_epoch_seen or {}
	local ptr = GetPtrHash(player)
	if item._room_epoch_seen[ptr] ~= epoch then
		item._room_epoch_seen[ptr] = epoch
		clear_blueprint_hold(player)
		pcall(function() BW.save_control(player) end)
		d[item.own_key.."cnt"] = nil
		player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
		d.should_evaluate_on_update_once = true
	end
	BW.ensure_reconcile(player)
	local ctrlidx = player.ControllerIndex

	-- 准星始终存在：换房/失效时直接重建，不要求当帧射击输入
	if auxi.check_all_exists(d[item.own_key.."Focus_target"]) ~= true then
		local q = spawn_command_mark(player, player.Position)
		d[item.own_key.."Focus_target"] = q
		d[item.own_key.."time"] = Game():GetFrameCount()
	end

	-- Ctrl / DROP：键盘在 Player Update 里采。鼠标必须走 Render（RGON 在 Update 里常读不到右键）。
	local debounce = tonumber(d[item.own_key.."FormShift"]) or 0
	if debounce > 0 then
		d[item.own_key.."FormShift"] = debounce - 1
	end
	local fire_debounce = tonumber(d[item.own_key.."FireShift"]) or 0
	if fire_debounce > 0 then
		d[item.own_key.."FireShift"] = fire_debounce - 1
	end
	tick_formation_key(player, d)

	-- 副手蓝图长短按：按下在 MC_USE_ITEM 建档，这里计时/松手裁决
	local hold = d[item.own_key.."bp_hold"]
	if type(hold) == "table" then
		if blueprint_panel_open(player) and hold.consumed == true then
			if not Input.IsActionPressed(blueprint_hold_button(player), ctrlidx) then
				clear_blueprint_hold(player)
			else
				d[item.own_key.."_Charge_Bar_buff"] = 0
			end
		elseif player:GetActiveItem(ActiveSlot.SLOT_POCKET) ~= enums.Items.Blue_Print
			and player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) ~= enums.Items.Blue_Print then
			clear_blueprint_hold(player)
		else
			local btn = blueprint_hold_button(player)
			local pressed = Input.IsActionPressed(btn, ctrlidx)
			if pressed then
				hold.frames = (tonumber(hold.frames) or 0) + 1
				d[item.own_key.."_Charge_Bar_buff"] = hold.frames
				if hold.frames >= item.HOLD_OPEN_FRAMES and hold.consumed ~= true then
					hold.consumed = true
					local bp = get_blueprint()
					if bp and bp.open_for_player then
						bp.open_for_player(player)
					end
					d[item.own_key.."_Charge_Bar_buff"] = 0
				end
			else
				if hold.consumed ~= true then
					BW.toggle_fire_control_mode(player)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.55, 1.05, false, 0, 2)
				end
				clear_blueprint_hold(player)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,_offset)
	if player:GetPlayerType() ~= item.entity then return end
	local room = Game():GetRoom()
	if room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local hold = player:GetData()[item.own_key.."bp_hold"]
	if type(hold) ~= "table" or hold.consumed == true then return end
	local need = item.HOLD_OPEN_FRAMES
	Charging_Bar_holder.render_me(player, {
		name1 = item.own_key,
		name2 = item.own_key,
		name3 = item.own_key,
		loadname = "gfx/effects/chargebar/chargebar_Qing.anm2",
		check1 = function(val) return (tonumber(val) or 0) > 0 end,
		check2 = function(val) return (tonumber(val) or 0) >= need end,
		check3 = function(val) return math.floor(((tonumber(val) or 0) / need) * 100) end,
	})
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	-- 禁止在此访问 Player/Entity userdata。房间工作改到 POST_PLAYER_UPDATE 按 epoch 消费。
	item._room_epoch = (item._room_epoch or 0) + 1
end,
})


table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	if player:GetPlayerType() == item.entity then
		player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
		player:GetData().should_evaluate_on_update_once = true
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	if player:GetPlayerType() == item.entity then
		local ret = nil
		local language = Options.Language
		local infos = (item.Special_Des[language] or {})[tp]
		if infos == nil then return end
		local info = infos[id]
		if info == nil then return end
		ret = {Name = info.Name or value.Name,Description = info.Description or value.Description,}
		return ret
	end
end,
})

return item
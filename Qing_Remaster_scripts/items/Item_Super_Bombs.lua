local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Super_Bombs,
	own_key = "Item_Super_Bombs_",
	default_bomb_growth_seconds = 20,
	default_mama_growth_seconds = 120,
	growth_switch_frame = 24,
	growth_settle_frame = 52,
	growth_giga_end_frame = 72,
	growth_mama_move_end_frame = 82,
	growth_mama_end_frame = 94,
}

local growth_sprite = Sprite()
growth_sprite:Load("gfx/mimics/Super_Bombs/super_bombs_hud.anm2",true)

local timer_h_sprite = Sprite()
timer_h_sprite:Load("gfx/mimics/Super_Bombs/segment_h.anm2",true)
timer_h_sprite:Play("Idle",true)

local timer_v_sprite = Sprite()
timer_v_sprite:Load("gfx/mimics/Super_Bombs/segment_v.anm2",true)
timer_v_sprite:Play("Idle",true)

local timer_dot_sprite = Sprite()
timer_dot_sprite:Load("gfx/mimics/Super_Bombs/segment_dot.anm2",true)
timer_dot_sprite:Play("Idle",true)

local timer_digit_segments = {
	["0"] = {"A","B","C","D","E","F"},
	["1"] = {"B","C"},
	["2"] = {"A","B","D","E","G"},
	["3"] = {"A","B","C","D","G"},
	["4"] = {"B","C","F","G"},
	["5"] = {"A","C","D","F","G"},
	["6"] = {"A","C","D","E","F","G"},
	["7"] = {"A","B","C"},
	["8"] = {"A","B","C","D","E","F","G"},
	["9"] = {"A","B","C","D","F","G"},
}

local timer_segment_positions = {
	A = Vector(1,0),
	F = Vector(0,1),
	B = Vector(6,1),
	G = Vector(1,4),
	E = Vector(0,5),
	C = Vector(6,5),
	D = Vector(1,8),
}

local timer_digit_advance = 8
local timer_dot_position = Vector(1,8)
local timer_dot_advance = 2
local timer_colon_top_position = Vector(0,2)
local timer_colon_bottom_position = Vector(0,5)
local timer_colon_advance = 2

local function get_debug_setting(setting,default_value)
	local root = save.ModConfigSettings
	local debug_settings = root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
	return tonumber(debug_settings and debug_settings[setting]) or default_value
end

local function get_growth_frames(setting,default_seconds)
	-- bomb_timer / mama_timer advance on MC_POST_PLAYER_UPDATE (60Hz).
	local seconds = get_debug_setting(setting,default_seconds)
	return math.max(1,math.floor(seconds * 60 + 0.5))
end

local function get_bomb_growth_frames()
	return get_growth_frames("SuperBombsBombGrowthSeconds",item.default_bomb_growth_seconds)
end

local function get_mama_growth_frames()
	return get_growth_frames("SuperBombsMamaGrowthSeconds",item.default_mama_growth_seconds)
end

local function get_state(player)
	local data = player:GetData()
	data[item.own_key.."state"] = data[item.own_key.."state"] or {
		bomb_timer = 0,
		mama_timer = 0,
	}
	return data[item.own_key.."state"]
end

local function reset_growth(state)
	state.bomb_timer = 0
	state.mama_timer = 0
	state.growth = nil
end

local function has_primary_active(player)
	return player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) ~= CollectibleType.COLLECTIBLE_NULL
end

local function begin_growth(state,growth_type)
	state.growth = {
		type = growth_type,
		frame = 0,
		converted = false,
	}
end

local function can_finish_growth(player,growth_type)
	if growth_type == "giga" then
		return player:GetNumBombs() > 0 and player:GetNumGigaBombs() == 0
	end
	return player:GetNumGigaBombs() > 0 and not has_primary_active(player)
end

local function finish_growth(player,state)
	local growth = state.growth
	if not growth or not can_finish_growth(player,growth.type) then
		reset_growth(state)
		return false
	end

	if growth.type == "giga" then
		-- Giga bombs are a subset of the normal bomb counter.
		player:AddGigaBombs(1)
		state.bomb_timer = 0
	else
		player:AddGigaBombs(-1)
		player:AddBombs(-1)
		player:AddCollectible(CollectibleType.COLLECTIBLE_MAMA_MEGA,0,true,ActiveSlot.SLOT_PRIMARY)
		state.mama_timer = 0
	end

	growth.converted = true
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2)
	return true
end

local function update_growth(player)
	local state = get_state(player)
	local growth = state.growth
	if growth then
		if growth.type == "mama" and growth.converted and
			player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) ~= CollectibleType.COLLECTIBLE_MAMA_MEGA then
			state.growth = nil
			return
		end
		growth.frame = growth.frame + 1
		if not growth.converted and growth.frame >= item.growth_switch_frame then
			if not finish_growth(player,state) then return end
		end
		local end_frame = growth.type == "mama" and item.growth_mama_end_frame or item.growth_giga_end_frame
		if state.growth and growth.frame >= end_frame then
			state.growth = nil
		end
		return
	end

	local has_giga = player:GetNumGigaBombs() > 0
	local has_bombs = player:GetNumBombs() > 0
	if not has_giga and has_bombs then
		state.bomb_timer = state.bomb_timer + 1
		state.mama_timer = 0
		if state.bomb_timer >= get_bomb_growth_frames() then
			begin_growth(state,"giga")
		end
	elseif has_giga and not has_primary_active(player) then
		state.mama_timer = state.mama_timer + 1
		state.bomb_timer = 0
		if state.mama_timer >= get_mama_growth_frames() then
			begin_growth(state,"mama")
		end
	else
		state.bomb_timer = 0
		state.mama_timer = 0
	end
end

local function get_render_info(player)
	local state = get_state(player)
	if state.growth then
		local growth = state.growth
		local maximum = growth.type == "giga" and get_bomb_growth_frames() or get_mama_growth_frames()
		return growth.type,maximum,maximum,state
	end
	if player:GetNumGigaBombs() == 0 and player:GetNumBombs() > 0 then
		return "giga",state.bomb_timer,get_bomb_growth_frames(),state
	end
	if player:GetNumGigaBombs() > 0 and not has_primary_active(player) then
		return "mama",state.mama_timer,get_mama_growth_frames(),state
	end
end

local function round_timer_position(position)
	return Vector(
		math.floor(position.X + 0.5),
		math.floor(position.Y + 0.5)
	)
end

local function get_timer_segment_sprite(segment)
	if segment == "A" or segment == "D" or segment == "G" then
		return timer_h_sprite
	end
	return timer_v_sprite
end

local function render_timer_sprite(sprite,position,color)
	sprite.Scale = Vector(1,1)
	sprite.Color = color
	sprite:Render(
		round_timer_position(position),
		Vector.Zero,
		Vector.Zero
	)
end

local function get_timer_brightness(remaining_seconds)
	local frame = Game():GetFrameCount()

	if remaining_seconds <= 2 then
		if math.floor(frame / 8) % 2 == 0 then
			return 1
		end
		return 0.65
	end

	if remaining_seconds <= 5 then
		local wave = 0.5 + 0.5 * math.sin(frame / 12)
		return 0.85 + 0.15 * wave
	end

	return 1
end

local function render_timer_digit(position,digit,hud_alpha,remaining_seconds)
	local lit_segments = timer_digit_segments[digit]
	if not lit_segments then return end

	local brightness = get_timer_brightness(remaining_seconds)
	local on_color = Color(1,0.05,0.05,hud_alpha * brightness)

	for _,segment in ipairs(lit_segments) do
		local sprite = get_timer_segment_sprite(segment)
		render_timer_sprite(sprite,position + timer_segment_positions[segment],on_color)
	end
end

local function render_timer_dot(position,hud_alpha,remaining_seconds)
	local brightness = get_timer_brightness(remaining_seconds)
	render_timer_sprite(
		timer_dot_sprite,
		position + timer_dot_position,
		Color(1,0.05,0.05,hud_alpha * brightness)
	)
end

local function render_timer_colon(position,hud_alpha,remaining_seconds)
	local brightness = get_timer_brightness(remaining_seconds)
	local color = Color(1,0.05,0.05,hud_alpha * brightness)
	render_timer_sprite(timer_dot_sprite,position + timer_colon_top_position,color)
	render_timer_sprite(timer_dot_sprite,position + timer_colon_bottom_position,color)
end

local function get_timer_character_advance(character)
	if timer_digit_segments[character] then
		return timer_digit_advance
	end
	if character == "." then
		return timer_dot_advance
	end
	if character == ":" then
		return timer_colon_advance
	end
	return 0
end

local function measure_timer_text(text)
	local width = 0
	for index = 1,#text do
		width = width + get_timer_character_advance(string.sub(text,index,index))
	end
	return width
end

local function render_timer_text(position,text,hud_alpha,remaining_seconds)
	local cursor_x = position.X
	for index = 1,#text do
		local character = string.sub(text,index,index)
		local character_position = Vector(cursor_x,position.Y)
		if timer_digit_segments[character] then
			render_timer_digit(character_position,character,hud_alpha,remaining_seconds)
		elseif character == "." then
			render_timer_dot(character_position,hud_alpha,remaining_seconds)
		elseif character == ":" then
			render_timer_colon(character_position,hud_alpha,remaining_seconds)
		end
		cursor_x = cursor_x + get_timer_character_advance(character)
	end
end

local function format_timer(counter,maximum)
	-- counter/maximum are PLAYER_UPDATE ticks (60Hz); growth.frame stays on its own timeline.
	local remaining_seconds = math.max(0,maximum - counter) / 60
	if maximum >= 60 * 60 then
		local seconds = math.ceil(remaining_seconds)
		return string.format(
			"%d:%02d",
			math.floor(seconds / 60),
			seconds % 60
		),remaining_seconds
	end
	local shown = math.ceil(remaining_seconds * 10 - 0.000001) / 10
	return string.format("%.1f",shown),remaining_seconds
end

local function get_timer_position(player,growth_type,timer_width)
	if growth_type == "mama" then
		local anchor = ui.PlayerActiveUIPos(
			player,
			ActiveSlot.SLOT_PRIMARY,
			auxi.GetPlayerOrder(player),
			CollectibleType.COLLECTIBLE_MAMA_MEGA
		)
		local timer_x = get_debug_setting("SuperBombsMamaTimerX",5)
		local timer_y = get_debug_setting("SuperBombsMamaTimerY",9)
		return anchor + Vector(timer_x - timer_width,timer_y)
	end

	local anchor = ui.UIBombPos(auxi.is_double_player())
	local timer_x = get_debug_setting("SuperBombsTimerX",-5)
	local timer_y = get_debug_setting("SuperBombsTimerY",-5)
	return anchor + Vector(timer_x - timer_width,timer_y)
end

local function lerp(a,b,progress)
	return a + (b - a) * math.max(0,math.min(1,progress))
end

local function smoothstep(progress)
	progress = math.max(0,math.min(1,progress))
	return progress * progress * (3 - 2 * progress)
end

local function keyframed_scale(frame,keyframes)
	for index = 1,#keyframes - 1 do
		local from = keyframes[index]
		local to = keyframes[index + 1]
		if frame <= to.frame then
			local progress = (frame - from.frame) / math.max(1,to.frame - from.frame)
			return Vector(lerp(from.x,to.x,progress),lerp(from.y,to.y,progress))
		end
	end
	local last = keyframes[#keyframes]
	return Vector(last.x,last.y)
end

local source_scale_keyframes = {
	{frame = 0,x = 1,y = 1},
	{frame = 9,x = 0.9,y = 1.16},
	{frame = 16,x = 1.36,y = 1.42},
	{frame = 24,x = 1.75,y = 0.2},
}

local target_scale_keyframes = {
	{frame = 24,x = 1.75,y = 0.2},
	{frame = 29,x = 0.72,y = 1.35},
	{frame = 36,x = 1.15,y = 0.88},
	{frame = 44,x = 0.94,y = 1.06},
	{frame = 52,x = 1,y = 1},
}

local function render_growth_icon(position,growth_type,state,hud_alpha,player)
	local growth = state.growth
	local animation = growth_type == "giga" and "Bomb" or "GigaBomb"
	local scale = Vector(1,1)
	local alpha = 1
	local render_position = position

	if growth then
		if growth.frame < item.growth_switch_frame then
			scale = keyframed_scale(growth.frame,source_scale_keyframes)
		else
			animation = growth_type == "giga" and "GigaBomb" or "MamaMega"
			scale = keyframed_scale(growth.frame,target_scale_keyframes)
			if growth_type == "mama" and growth.frame > item.growth_settle_frame then
				local move_progress = smoothstep((growth.frame - item.growth_settle_frame) /
					(item.growth_mama_move_end_frame - item.growth_settle_frame))
				local active_position = ui.PlayerActiveUIPos(
					player,
					ActiveSlot.SLOT_PRIMARY,
					auxi.GetPlayerOrder(player),
					CollectibleType.COLLECTIBLE_MAMA_MEGA
				)
				render_position = position + (active_position - position) * move_progress
				local active_scale = lerp(1,2,move_progress)
				scale = scale * active_scale
			end
		end
	end

	growth_sprite:Play(animation,true)
	growth_sprite.Scale = scale
	growth_sprite.Color = Color(1,1,1,alpha * hud_alpha)
	growth_sprite:Render(render_position,Vector.Zero,Vector.Zero)
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,touched)
	if not touched then
		player:AddGigaBombs(5)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		if not Game():IsPaused() then update_growth(player) end
	else
		player:GetData()[item.own_key.."state"] = nil
	end
end,
})

if REPENTOGON then
	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_USE_BOMB, params = nil,
	Function = function(_,player,bomb)
		if auxi.has_have_coll(player,item.entity) then
			reset_growth(get_state(player))
		end
	end,
	})

	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM, params = CollectibleType.COLLECTIBLE_MAMA_MEGA,
	Function = function(_,player,slot,offset,alpha,scale,charge_bar_offset)
		if slot ~= ActiveSlot.SLOT_PRIMARY or not auxi.has_have_coll(player,item.entity) then return end
		local growth = get_state(player).growth
		if growth and growth.type == "mama" and growth.converted and
			growth.frame < item.growth_mama_move_end_frame then
			return {HideItem = true}
		end
	end,
	})
end

local hud_render_callback = REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER or ModCallbacks.MC_POST_RENDER

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = hud_render_callback, params = nil,
Function = function(_)
	if not Game():GetHUD():IsVisible() then return end
	for player_num = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		if auxi.has_have_coll(player,item.entity) then
			local growth_type,counter,maximum,state = get_render_info(player)
			if growth_type then
				local bomb_position = ui.UIBombPos(auxi.is_double_player())
				local alpha = slot_render_holder.get_alpha()
				-- 成长图标始终从炸弹栏出发；Mama 倒计时单独锚在主主动槽。
				render_growth_icon(bomb_position,growth_type,state,alpha,player)
				if not state.growth then
					local text,remaining_seconds = format_timer(counter,maximum)
					local timer_width = measure_timer_text(text)
					render_timer_text(
						get_timer_position(player,growth_type,timer_width),
						text,
						alpha,
						remaining_seconds
					)
				end
			end
			break
		end
	end
end,
})

return item

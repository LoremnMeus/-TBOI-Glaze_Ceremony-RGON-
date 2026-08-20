-- 蓝图白/黑王冠视觉：挂在 Air Flight 头顶，沿用原版 FloatGlow / FloatNoGlow 明灭。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Crown_holder_",
}

local COL_LIGHT = 415
local COL_DARK = 442
local PATH_LIGHT = "gfx/crownoflight.anm2"
local PATH_DARK = "gfx/darkprincescrown.anm2"
local ANIM_GLOW = "FloatGlow"
local ANIM_DIM = "FloatNoGlow"
-- 双冠时的额外屏幕间距（anm2 内已有约 -30 的头顶偏移）
local STACK_SCREEN_Y = -10

local function get_air_mod()
	return package.loaded["Qing_Remaster_scripts.items.Item_Air_Flight"]
		or require("Qing_Remaster_scripts.items.Item_Air_Flight")
end

local function get_dyn()
	return package.loaded["Qing_Remaster_scripts.others.craft_dynamic_stats"]
		or require("Qing_Remaster_scripts.others.craft_dynamic_stats")
end

local function render_interp_frac()
	if Isaac.GetFrameCount then
		return (Isaac.GetFrameCount() % 2) * 0.5
	end
	return 0.5
end

--- Flight：PO 进 W2S（与 Gemini 脐带同口径）
local function flight_screen_pos(air)
	local vel = air.Velocity or Vector.Zero
	local world = air.Position + vel * render_interp_frac() + (air.PositionOffset or Vector.Zero)
	return Isaac.WorldToScreen(world) + (air.SpriteOffset or Vector.Zero)
end

local function ensure_sprite(d, key, path)
	local spr = d[item.own_key..key]
	if spr then return spr end
	spr = Sprite()
	spr:Load(path, true)
	spr:Play(ANIM_DIM, true)
	d[item.own_key..key] = spr
	return spr
end

local function sync_crown_anim(spr, glowing)
	if not spr then return end
	local want = glowing and ANIM_GLOW or ANIM_DIM
	if not spr:IsPlaying(want) then
		spr:Play(want, true)
	end
end

local function apply_air_scale(spr, air)
	local sx, sy = 1, 1
	if air.SpriteScale then
		sx = tonumber(air.SpriteScale.X) or 1
		sy = tonumber(air.SpriteScale.Y) or 1
	end
	spr.Scale = Vector(sx, sy)
end

local function crown_flags(air)
	local Air = get_air_mod()
	local d = air:GetData()
	local prof = Air and d[Air.own_key.."craft_profile"]
	local counts = prof and prof.counts
	if not counts then return nil end
	local has_light = (counts[COL_LIGHT] or 0) > 0
	local has_dark = (counts[COL_DARK] or 0) > 0
	if not has_light and not has_dark then return nil end
	local player = auxi.check_spawner_player(air) or air.Player
	local Dyn = get_dyn()
	return {
		d = d,
		player = player,
		has_light = has_light,
		has_dark = has_dark,
		light_on = has_light and Dyn and Dyn.crown_of_light_active and Dyn.crown_of_light_active(player) == true,
		dark_on = has_dark and Dyn and Dyn.dark_prince_crown_active and Dyn.dark_prince_crown_active(player) == true,
	}
end

-- 逻辑帧更新动画（约 30Hz），避免在 60Hz Render 里 Update 导致漂浮加倍速
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_UPDATE,
	params = enums.Familiars.QingsAirs,
	Function = function(_, air)
		if not air or not auxi.check_all_exists(air) then return end
		local flags = crown_flags(air)
		if not flags then return end
		if flags.has_light then
			local spr = ensure_sprite(flags.d, "light_spr", PATH_LIGHT)
			sync_crown_anim(spr, flags.light_on)
			apply_air_scale(spr, air)
			spr:Update()
		end
		if flags.has_dark then
			local spr = ensure_sprite(flags.d, "dark_spr", PATH_DARK)
			sync_crown_anim(spr, flags.dark_on)
			apply_air_scale(spr, air)
			spr:Update()
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_FAMILIAR_RENDER,
	params = enums.Familiars.QingsAirs,
	Function = function(_, air, _offset)
		if not air or not auxi.check_all_exists(air) then return end
		if air.Visible == false then return end
		local room = Game():GetRoom()
		if room and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end

		local flags = crown_flags(air)
		if not flags then return end

		local base = flight_screen_pos(air)
		local stack = 0
		if flags.has_light then
			local spr = ensure_sprite(flags.d, "light_spr", PATH_LIGHT)
			sync_crown_anim(spr, flags.light_on)
			apply_air_scale(spr, air)
			spr:Render(base + Vector(0, stack * STACK_SCREEN_Y), Vector(0, 0), Vector(0, 0))
			stack = stack + 1
		end
		if flags.has_dark then
			local spr = ensure_sprite(flags.d, "dark_spr", PATH_DARK)
			sync_crown_anim(spr, flags.dark_on)
			apply_air_scale(spr, air)
			spr:Render(base + Vector(0, stack * STACK_SCREEN_Y), Vector(0, 0), Vector(0, 0))
		end
	end,
})

return item

-- 玩家伪恐惧：不使用原生 AddFear / FLAG_FEAR。
-- 计时 = MC_POST_PLAYER_UPDATE（约 60Hz）；fear_duration = 3*60 ≈ 3 秒（本模组自定义 Player Update timer）。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local custom_attack_manager = require("Qing_Remaster_scripts.player.custom_attack_manager")

local item = {
	ToCall = {},
	own_key = "Player_Pseudo_Fear_",
	-- 自定义 Player Update timer，不是原生 Fear frame。
	fear_duration = 3 * 60,
	fear_shader = "gfx/statuseffects.anm2",
	fear_anim = "Fear",
	-- statuseffects.anm2 Fear：Layer Main/0，帧 X/Y=0，Pivot 16,16（32×16）。
	-- ANM2 自身无头顶位移；引擎状态图标习惯落在角色头顶附近。项目侧注释亦见约 -28 屏像素。
	fear_icon_screen_offset = Vector(0, -28),
	-- 原版 NPC Fear 探针采样（2026-09-01）：Tint=(0.5,0.1,0.5,1) Offset=0 Colorize=0
	fear_color = Color(0.5, 0.1, 0.5, 1, 0, 0, 0),
	fear_color_priority = 8,
	shoot_block_source = "Player_Pseudo_Fear",
}

local TIMER_KEY = item.own_key.."timer"
local SPRITE_KEY = item.own_key.."sprite"
local BLOCK_KEY = item.own_key.."blocked"

local function ensure_fear_sprite(d)
	local sprite = d[SPRITE_KEY]
	if sprite then return sprite end
	sprite = Sprite()
	sprite:Load(item.fear_shader, true)
	sprite:Play(item.fear_anim, true)
	d[SPRITE_KEY] = sprite
	return sprite
end

local function release_shoot_block(player, d)
	if not d[BLOCK_KEY] then return end
	custom_attack_manager.ReleaseShootBlock(player, item.shoot_block_source)
	d[BLOCK_KEY] = nil
end

local function ensure_shoot_block(player, d)
	if d[BLOCK_KEY] then return end
	custom_attack_manager.RequestShootBlock(player, item.shoot_block_source)
	d[BLOCK_KEY] = true
end

local function clear_fear(player)
	if not player then return end
	local d = player:GetData()
	release_shoot_block(player, d)
	d[TIMER_KEY] = nil
	d[SPRITE_KEY] = nil
end

--- 施加 / 刷新玩家伪恐惧（重复触发只取 max，不叠加）。
function item.apply(player, duration)
	if not player or not player:Exists() then return end
	if player:IsDead() then return end
	local d = player:GetData()
	local dur = math.max(1, math.floor(tonumber(duration) or item.fear_duration))
	d[TIMER_KEY] = math.max(d[TIMER_KEY] or 0, dur)
	ensure_fear_sprite(d)
	ensure_shoot_block(player, d)
end

function item.is_active(player)
	if not player then return false end
	local t = player:GetData()[TIMER_KEY]
	return type(t) == "number" and t > 0
end

function item.clear(player)
	clear_fear(player)
end

local function update_player_fear(player)
	local d = player:GetData()
	local timer = d[TIMER_KEY]
	if type(timer) ~= "number" or timer <= 0 then
		if d[BLOCK_KEY] or d[SPRITE_KEY] then clear_fear(player) end
		return
	end
	if player:IsDead() then
		clear_fear(player)
		return
	end

	ensure_shoot_block(player, d)
	local sprite = ensure_fear_sprite(d)
	sprite:Update()

	-- 短 duration 重施，结束时不强行 SetColor(Default)，避免盖掉其他染色。
	player:SetColor(item.fear_color, 2, item.fear_color_priority, false, false)

	timer = timer - 1
	if timer <= 0 then
		clear_fear(player)
	else
		d[TIMER_KEY] = timer
	end
end

local function render_player_fear(player, offset)
	local d = player:GetData()
	local timer = d[TIMER_KEY]
	if type(timer) ~= "number" or timer <= 0 then return end
	if player:IsDead() or not player.Visible then return end
	local sprite = d[SPRITE_KEY] or ensure_fear_sprite(d)
	local world = player.Position + player_offset_holder.GetVisualPositionOffset(player)
	local screen = Isaac.WorldToScreen(world) + (offset or Vector(0, 0)) + item.fear_icon_screen_offset
	sprite:Render(screen, Vector(0, 0), Vector(0, 0))
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		update_player_fear(player)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_RENDER,
	params = nil,
	Function = function(_, player, offset)
		render_player_fear(player, offset)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function(_)
		for _, player in pairs(auxi.GetPlayers()) do
			clear_fear(player)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function(_)
		for _, player in pairs(auxi.GetPlayers()) do
			clear_fear(player)
		end
	end,
})

return item

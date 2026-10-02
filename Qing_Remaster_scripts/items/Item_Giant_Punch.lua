local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Giant_Punch,
	own_key = "Item_Giant_Punch_",
}

local soul_capacity_ghost = Sprite()
soul_capacity_ghost:Load("gfx/ui/ui_hearts.anm2",true)
soul_capacity_ghost:Play("BlueHeartFull",true)

local function get_player_hud(player)
	if player.GetPlayerHUD then return player:GetPlayerHUD() end
	if g.HUD and g.HUD.GetPlayerHUD then
		for i = 0,3 do
			local hud = g.HUD:GetPlayerHUD(i)
			if hud and hud:GetPlayer() and GetPtrHash(hud:GetPlayer()) == GetPtrHash(player) then return hud end
		end
	end
end

local function heart_row_max(hud)
	if hud and hud.GetLayout then local layout = hud:GetLayout() if layout == 2 or layout == 3 then return 3 end end
	return 6
end

local function heart_offset(index,scale,rowmax)
	local row = math.floor((index - 1) / rowmax)
	local column = (index - 1) - row * rowmax
	return Vector(column * 12 * scale,row * 10 * scale)
end

local function get_current_health(player)
	return math.max(0,player:GetHearts() + player:GetSoulHearts() + player:GetEternalHearts())
end

local function baseline_store()
	save.elses[item.own_key.."run"] = save.elses[item.own_key.."run"] or {}
	return save.elses[item.own_key.."run"]
end

local function baseline_key(player)
	return tostring(player.InitSeed)
end

local function get_soul_baseline(player,current)
	local data = player:GetData()
	if data[item.own_key.."baseline_capacity"] then return data[item.own_key.."baseline_capacity"] end
	local store = baseline_store()
	local key = baseline_key(player)
	local baseline = tonumber(store[key])
	if not baseline and current > 0 and auxi.has_have_coll(player,item.entity) then
		baseline = current
		store[key] = baseline
	end
	data[item.own_key.."baseline_capacity"] = baseline
	return baseline
end

local function get_megamorph_state(player)
	if REPENTOGON and player.GetHealthType and HealthType and player:GetHealthType() == HealthType.COIN then
		local coin_hearts = math.max(0,player:GetHearts())
		local coin_capacity = math.max(0,player:GetMaxHearts())
		if coin_capacity <= 0 then return 0 end
		if coin_hearts < coin_capacity then return 1 end
		if coin_hearts > coin_capacity then return -1 end
		return 0
	end
	local current = get_current_health(player)
	local normal_capacity = math.max(0,player:GetMaxHearts() + player:GetBoneHearts() * 2)
	if normal_capacity <= 0 then
		if current <= 0 then return 0 end
		normal_capacity = get_soul_baseline(player,current) or current
	end
	if current < normal_capacity then return 1 end
	if current > normal_capacity then return -1 end
	return 0
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if not continue then save.elses[item.own_key.."run"] = {} end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local state = get_megamorph_state(player)
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			if state > 0 then
				player.Damage = player.Damage * 2
			elseif state < 0 then
				player.Damage = player.Damage * 0.5
			end
		end
		if cacheFlag == CacheFlag.CACHE_SIZE then
			if state > 0 then
				player.SpriteScale = player.SpriteScale * 1.25
			elseif state < 0 then
				player.SpriteScale = player.SpriteScale * 0.75
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local data = player:GetData()
	if auxi.has_have_coll(player,item.entity) then
		local state = get_megamorph_state(player)
		if data[item.own_key.."state"] ~= state then
			data[item.own_key.."state"] = state
			data.should_evaluate_on_update_once = true
			player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SIZE)
		end
	elseif data[item.own_key.."state"] ~= nil or data[item.own_key.."baseline_capacity"] ~= nil then
		data[item.own_key.."state"] = nil
		data[item.own_key.."baseline_capacity"] = nil
		data.should_evaluate_on_update_once = true
		player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SIZE)
	end
end,
})

if REPENTOGON and ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS then
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS, params = nil,
Function = function(_,offset,heartsSprite,position,spriteScale,player)
	if not auxi.can_render_health_hud() then return end
	if not player or not auxi.has_have_coll(player,item.entity) or player:GetMaxHearts() + player:GetBoneHearts() * 2 > 0 then return end
	local baseline = get_soul_baseline(player,get_current_health(player))
	if not baseline or baseline <= 0 then return end
	local state = get_megamorph_state(player)
	if state == 0 then return end
	local hud = get_player_hud(player)
	if not hud then return end
	local slots = math.ceil(baseline / 2)
	local phase = 0.5 + 0.5 * math.sin(Game():GetFrameCount() * 0.16)
	local pulse = state > 0 and (0.08 + 0.12 * phase) or (0.68 + 0.27 * phase)
	local callback_alpha = heartsSprite and heartsSprite.Color and heartsSprite.Color.A or 1
	local color = state < 0 and Color(1,1,1,pulse * callback_alpha,0.08,0.2,0.38) or Color(1,1,1,pulse * callback_alpha,0,0,0)
	if color.SetColorize then
		if state < 0 then
			color:SetColorize(0.8,1.45,2.0,1)
		else
			color:SetColorize(0.12,0.35,0.65,0.22)
		end
	end
	soul_capacity_ghost.Color = color
	local scale = spriteScale or 1
	if heartsSprite and heartsSprite.Scale then scale = heartsSprite.Scale.X end
	soul_capacity_ghost.Scale = heartsSprite and heartsSprite.Scale and Vector(heartsSprite.Scale.X,heartsSprite.Scale.Y) or Vector(scale,scale)
	soul_capacity_ghost:SetFrame("BlueHeartFull",0)
	local rowmax = heart_row_max(hud)
	for i = 1,slots do
		soul_capacity_ghost:Render(position + heart_offset(i,scale,rowmax),Vector.Zero,Vector.Zero)
	end
end,
})
end

return item

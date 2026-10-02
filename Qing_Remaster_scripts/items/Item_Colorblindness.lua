local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	pre_ToCall = {},
	myToCall = {},
	ToCall = {},
	entity = enums.Items.Colorblindness,
	own_key = "Item_Colorblindness_",
	range = 82,
	-- Hover / cooldown tick on MC_POST_PLAYER_UPDATE (60 Hz).
	hover_time = 40,
	rate_cooldown = 36,
	flying_items = {},
	pending_pool_items = {},
	start_ban_flights = {},
}

local function get_next_run_bans()
	save.PermanentData = save.PermanentData or {}
	local key = item.own_key.."next_run_bans"
	if type(save.PermanentData[key]) ~= "table" then
		save.PermanentData[key] = {}
	end
	return save.PermanentData[key]
end

function item.get_next_run_bans()
	return get_next_run_bans()
end

function item.clear_next_run_bans()
	save.PermanentData = save.PermanentData or {}
	save.PermanentData[item.own_key.."next_run_bans"] = {}
	if save.SaveModData then pcall(save.SaveModData, "colorblind_clear_bans") end
	return true
end

function item.remove_next_run_ban(id)
	id = tonumber(id)
	if not id then return false end
	get_next_run_bans()[tostring(id)] = nil
	if save.SaveModData then pcall(save.SaveModData, "colorblind_remove_ban") end
	return true
end

function item.list_next_run_bans()
	local bans = get_next_run_bans()
	local list = {}
	for key,_ in pairs(bans) do
		local id = tonumber(key)
		if id then list[#list + 1] = id end
	end
	table.sort(list)
	return list
end

local function get_liked_pool_items()
	save.elses[item.own_key.."liked_pool_items"] = save.elses[item.own_key.."liked_pool_items"] or {}
	return save.elses[item.own_key.."liked_pool_items"]
end

local function player_has_item(player)
	return player and auxi.has_have_coll(player,item.entity)
end

local function is_valid_collectible(pickup)
	if pickup == nil or pickup.Type ~= EntityType.ENTITY_PICKUP or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return false end
	if pickup.SubType == nil or pickup.SubType <= 0 then return false end
	if pickup:Exists() ~= true then return false end
	local p = pickup:ToPickup()
	if p and p.IsBlind and p:IsBlind() then return false end
	local d = pickup:GetData()
	if d[item.own_key.."rated"] then return false end
	return true
end

local function find_target(player)
	local best
	local best_dist = item.range
	for _,ent in ipairs(Isaac.GetRoomEntities()) do
		if is_valid_collectible(ent) then
			local dist = (ent.Position - player.Position):Length()
			if dist < best_dist then
				best = ent:ToPickup()
				best_dist = dist
			end
		end
	end
	return best,best_dist
end

local function get_current_pool(pickup)
	local room = Game():GetRoom()
	if room.GetItemPool then
		local pool = room:GetItemPool(pickup and pickup.InitSeed or Random(),false)
		if pool and pool >= 0 then return pool end
	end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local pool = Game():GetItemPool():GetPoolForRoom(room:GetType(),desc.SpawnSeed)
	if pool == nil or pool < 0 then pool = ItemPoolType.POOL_TREASURE end
	return pool
end

local function make_pool_item(pool,id)
	local ret = {
		itemID = id,
		weight = 1,
		decreaseBy = 0.5,
		removeOn = 0.1,
	}
	local itempool = Game():GetItemPool()
	if itempool.GetCollectiblesFromPool then
		local pool_items = itempool:GetCollectiblesFromPool(pool)
		for _,info in pairs(pool_items or {}) do
			if info.itemID == id then
				ret.weight = info.initialWeight or info.weight or ret.weight
				ret.decreaseBy = info.decreaseBy or ret.decreaseBy
				ret.removeOn = info.removeOn or ret.removeOn
				break
			end
		end
	end
	return ret
end

local function like_collectible(player,pickup)
	local pool = get_current_pool(pickup)
	local pool_item = make_pool_item(pool,pickup.SubType)
	local itempool = Game():GetItemPool()
	if itempool.AddTemporaryCollectible then
		itempool:AddTemporaryCollectible(pool,pool_item)
	end
	local liked = get_liked_pool_items()
	liked[tostring(pickup.SubType)] = (liked[tostring(pickup.SubType)] or 0) + 1
	pickup:GetData()[item.own_key.."rated"] = "like"
	player:AnimateHappy()
	SFXManager():Play(SoundEffect.SOUND_THUMBSUP,1,0,false,1)
end

local function make_collectible_sprite(id,color)
	local config = Isaac.GetItemConfig():GetCollectible(id)
	if config == nil then return nil end
	local sprite = Sprite()
	sprite:Load("gfx/dropping_collectible.anm2",true)
	sprite:Play("Idle",true)
	sprite:ReplaceSpritesheet(0,config.GfxFileName)
	sprite:LoadGraphics()
	sprite.Color = color or Color(1,1,1,1)
	return sprite
end

local function add_flying_item(id,pos,velocity,color)
	local sprite = make_collectible_sprite(id,color)
	if sprite then
		table.insert(item.flying_items,{sprite = sprite,pos = pos,velocity = velocity,frame = 0,})
	end
end

local function spawn_ban_flight(id,pos,dir)
	dir = dir or Vector(1,-0.2)
	if dir:Length() < 0.01 then dir = Vector(1,-0.2) end
	local side = dir.X
	if math.abs(side) < 0.01 then side = auxi.choose(1,-1) end
	side = side > 0 and 1 or -1
	add_flying_item(id,pos,Vector(2.8 * side,-3.2),Color(0.5,1,0.55,1,0,0.5,0))
end

local function dislike_collectible(player,pickup)
	local id = pickup.SubType
	local itempool = Game():GetItemPool()
	if itempool.RemoveCollectible then itempool:RemoveCollectible(id) end
	get_next_run_bans()[tostring(id)] = true
	if save.SaveModData then pcall(save.SaveModData, "colorblind_ban") end
	pickup:GetData()[item.own_key.."rated"] = "dislike"
	player:AnimateSad()
	SFXManager():Play(SoundEffect.SOUND_THUMBS_DOWN,1,0,false,1)
	spawn_ban_flight(id,pickup.Position,pickup.Position - player.Position)
end

-- Single vote-action vocabulary. Gameplay + suppression + HUD highlights all read this.
-- Detection never uses Keyboard.KEY_*; remaps of Drop/Bomb/PillCard are respected.
local VOTE_ACTIONS = {
	modifier = ButtonAction.ACTION_DROP,
	like = ButtonAction.ACTION_BOMB,
	dislike = ButtonAction.ACTION_PILLCARD,
}

local function get_vote_input(player)
	local ctrlid = player.ControllerIndex
	if not Input.IsActionPressed(VOTE_ACTIONS.modifier, ctrlid) then return end
	if Input.IsActionTriggered(VOTE_ACTIONS.like, ctrlid) then
		return "like"
	end
	if Input.IsActionTriggered(VOTE_ACTIONS.dislike, ctrlid) then
		return "dislike"
	end
end

local function get_input_state(player)
	local ctrlid = player.ControllerIndex
	return {
		modifier = Input.IsActionPressed(VOTE_ACTIONS.modifier, ctrlid),
		like = Input.IsActionPressed(VOTE_ACTIONS.like, ctrlid),
		dislike = Input.IsActionPressed(VOTE_ACTIONS.dislike, ctrlid),
	}
end

local function update_hover_state(player,target)
	local d = player:GetData()
	if target then
		if d[item.own_key.."hover_seed"] == target.InitSeed then
			d[item.own_key.."hover"] = math.min(item.hover_time,(d[item.own_key.."hover"] or 0) + 1)
		else
			d[item.own_key.."hover_seed"] = target.InitSeed
			d[item.own_key.."hover"] = 1
		end
	else
		d[item.own_key.."hover_seed"] = nil
		d[item.own_key.."hover"] = 0
	end
	if (d[item.own_key.."cooldown"] or 0) > 0 then d[item.own_key.."cooldown"] = d[item.own_key.."cooldown"] - 1 end
end

local function tick_player_vote(player)
	if player_has_item(player) ~= true or player:AreControlsEnabled() ~= true then
		update_hover_state(player,nil)
		player:GetData()[item.own_key.."has_target"] = nil
		return
	end
	local target = find_target(player)
	update_hover_state(player,target)
	local d = player:GetData()
	d[item.own_key.."has_target"] = target ~= nil
	if target and (d[item.own_key.."cooldown"] or 0) <= 0 then
		local vote = get_vote_input(player)
		if vote == "like" then
			like_collectible(player,target)
			d[item.own_key.."cooldown"] = item.rate_cooldown
		elseif vote == "dislike" then
			dislike_collectible(player,target)
			d[item.own_key.."cooldown"] = item.rate_cooldown
		end
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.flying_items = {}
	item.pending_pool_items = {}
	item.start_ban_flights = {}
	if continue ~= true then
		save.elses[item.own_key.."liked_pool_items"] = {}
		local bans = get_next_run_bans()
		local itempool = Game():GetItemPool()
		for id,_ in pairs(bans) do
			local num = tonumber(id)
			if num then
				if itempool.RemoveCollectible then itempool:RemoveCollectible(num) end
				table.insert(item.start_ban_flights,num)
			end
		end
		item.clear_next_run_bans()
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,action)
	if action ~= VOTE_ACTIONS.modifier and action ~= VOTE_ACTIONS.like and action ~= VOTE_ACTIONS.dislike then return end
	if ent == nil then return end
	local player = ent:ToPlayer()
	if player == nil or player_has_item(player) ~= true then return end
	local d = player:GetData()
	if d[item.own_key.."has_target"] ~= true then return end
	local ctrlid = player.ControllerIndex
	local modifier_pressed = Input.IsActionPressed(VOTE_ACTIONS.modifier, ctrlid)
	local like_pressed = Input.IsActionPressed(VOTE_ACTIONS.like, ctrlid)
	local dislike_pressed = Input.IsActionPressed(VOTE_ACTIONS.dislike, ctrlid)
	local should_block = false
	if action == VOTE_ACTIONS.modifier and (like_pressed or dislike_pressed) then
		should_block = true
	elseif (action == VOTE_ACTIONS.like or action == VOTE_ACTIONS.dislike) and modifier_pressed then
		should_block = true
	end
	if should_block then
		if hook == InputHook.GET_ACTION_VALUE then return 0 end
		return false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GET_COLLECTIBLE, params = nil,
Function = function(_,colid,pooltp,decrease,seed)
	local liked = get_liked_pool_items()
	if colid and liked[tostring(colid)] and liked[tostring(colid)] > 0 then
		item.pending_pool_items[colid] = item.pending_pool_items[colid] or {}
		table.insert(item.pending_pool_items[colid],{frame = Game():GetFrameCount(),room = Game():GetLevel():GetCurrentRoomDesc().GridIndex,pool = pooltp,seed = seed,})
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_COLLECTIBLE,
Function = function(_,pickup)
	if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE or pickup.SubType <= 0 then return end
	local queue = item.pending_pool_items[pickup.SubType]
	if queue == nil or #queue <= 0 then return end
	local now_frame = Game():GetFrameCount()
	local room_index = Game():GetLevel():GetCurrentRoomDesc().GridIndex
	for i = 1,#queue do
		local info = queue[i]
		if info.room == room_index and now_frame - info.frame >= 0 and now_frame - info.frame <= 3 then
			table.remove(queue,i)
			pickup:GetData()[item.own_key.."pool_glow"] = true
			pickup:SetColor(Color(1,1,1,1,0.85,0,0),45,1,true,false)
			Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.POOF01,0,pickup.Position,Vector(0,0),pickup):GetSprite().Color = Color(1,0.25,0.25,1,0.5,0,0)
			break
		end
	end
	if #queue <= 0 then item.pending_pool_items[pickup.SubType] = nil end
end,
})

-- Global VFX / start-of-run ban flights only. Interactive vote sampling is on PLAYER_UPDATE.
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	if #item.start_ban_flights <= 0 then return end
	local player = Game():GetPlayer(0)
	if player then
		for i,id in ipairs(item.start_ban_flights) do
			local angle = i * 53
			spawn_ban_flight(id,player.Position + auxi.get_by_rotate(nil,angle,26),auxi.get_by_rotate(nil,angle,1))
		end
		item.start_ban_flights = {}
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	tick_player_vote(player)
end,
})

local function render_prompt_token(text,pos,pressed,base_color,alpha)
	local color = base_color or {1,1,1}
	local mult = pressed and 1 or 0.45
	Isaac.RenderText(text,pos.X,pos.Y,color[1] * mult,color[2] * mult,color[3] * mult,alpha)
end

-- Display-only default keyboard hint (CTRL + Q / E) for all devices.
-- Gameplay remains ButtonAction-based and remap-aware; do not branch on ControllerIndex here.
local function render_vote_prompt(pos,state,alpha)
	render_prompt_token("CTRL",pos + Vector(-39,-10),state.modifier,{1,1,1},alpha)
	render_prompt_token("+",pos + Vector(-8,-10),state.modifier,{1,1,1},alpha)
	render_prompt_token("Q",pos + Vector(5,-10),state.dislike,{1,0.35,0.35},alpha)
	render_prompt_token("/",pos + Vector(18,-10),false,{1,1,1},alpha)
	render_prompt_token("E",pos + Vector(29,-10),state.like,{0.35,1,0.45},alpha)
	render_prompt_token("-",pos + Vector(-24,0),state.dislike,{1,0.25,0.25},alpha)
	render_prompt_token("+",pos + Vector(22,0),state.like,{0.25,1,0.35},alpha)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function()
	for playerNum = 1,Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		if player_has_item(player) and (d[item.own_key.."hover"] or 0) > 0 and d[item.own_key.."hover_seed"] then
			local alpha = math.min(1,(d[item.own_key.."hover"] or 0) / item.hover_time)
			local bob = math.sin(Isaac.GetFrameCount() / 8) * 2
			local pos = Isaac.WorldToScreen(player.Position + Vector(0,-58 - alpha * 12 + bob)) - Game().ScreenShakeOffset
			render_vote_prompt(pos,get_input_state(player),alpha)
		end
	end
	for i = #item.flying_items,1,-1 do
		local info = item.flying_items[i]
		info.frame = info.frame + 1
		local shake = auxi.get_by_rotate(nil,info.frame * 151,math.max(0,3 - info.frame * 0.06))
		info.pos = info.pos + info.velocity + shake
		info.velocity = info.velocity * 0.96 + Vector(0,-0.035)
		local alpha = math.max(0,1 - info.frame / 58)
		info.sprite.Color = Color(0.5,1,0.55,alpha,0,0.5,0)
		info.sprite:Update()
		info.sprite:Render(Isaac.WorldToScreen(info.pos) - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
		if info.frame >= 58 then table.remove(item.flying_items,i) end
	end
end,
})

return item

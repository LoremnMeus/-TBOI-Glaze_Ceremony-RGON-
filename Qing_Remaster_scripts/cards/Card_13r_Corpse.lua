local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Corpse_r,
	own_key = "Thoth_cd13r_Cor_",
}

local HEART_HOLD = item.own_key.."heart"
local POISON_FADE_TIMEOUT = 15
-- 距腐心过远则不复用（打包盒拆出常见）；绑定时始终瞬移贴心
local POISON_REUSE_MAX_DIST = 40

local function is_our_poison(ent)
	local d = ent and ent:GetData()
	return d and d[item.own_key.."effect"] == true
end

local function find_heart_by_seed(seed)
	if seed == nil then return nil end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_ROTTEN, false, false)) do
		if ent.InitSeed == seed and auxi.check_all_exists(ent) then
			return ent:ToPickup()
		end
	end
	return nil
end

local function find_poison_by_heart_seed(seed)
	if seed == nil then return nil end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.SMOKE_CLOUD, -1, false, false)) do
		if is_our_poison(ent) then
			local d = ent:GetData()
			-- 消散中/已拆绑的不得再认领（否则打包盒拆出又从原处飘来）
			if d[item.own_key.."heart_seed"] == seed and not d[item.own_key.."fading"] then
				return ent:ToEffect()
			end
		end
	end
	return nil
end

--- 真正结束毒雾：清 seed、Timeout，并在倒计时后 Remove（SMOKE_CLOUD 仅 Timeout 常不够）
local function begin_poison_fade(poison)
	if auxi.check_all_exists(poison) ~= true then return end
	local d = poison:GetData()
	if d[item.own_key.."fading"] then return end
	d[item.own_key.."fading"] = true
	d[item.own_key.."linker"] = nil
	d[item.own_key.."heart_seed"] = nil -- 禁止拆盒后按 seed 救活
	if poison.SetTimeout then
		poison:SetTimeout(POISON_FADE_TIMEOUT)
	end
	d[item.own_key.."fade_left"] = POISON_FADE_TIMEOUT
end

local function finish_poison_remove(poison)
	if auxi.check_all_exists(poison) ~= true then return end
	local d = poison:GetData()
	d[item.own_key.."effect"] = nil
	d[item.own_key.."linker"] = nil
	d[item.own_key.."heart_seed"] = nil
	d[item.own_key.."fading"] = nil
	d[item.own_key.."fade_left"] = nil
	poison:Remove()
end

--- SMOKE_CLOUD 不随离房清掉：靠 heart_seed 重绑；无腐心则消散并最终 Remove。
local function bind_poison_to_heart(poison, heart)
	if auxi.check_all_exists(poison) ~= true or auxi.check_all_exists(heart) ~= true then return false end
	local pd = poison:GetData()
	if pd[item.own_key.."fading"] then return false end
	local hd = heart:GetData()
	pd[item.own_key.."effect"] = true
	pd[item.own_key.."linker"] = heart
	pd[item.own_key.."heart_seed"] = heart.InitSeed
	hd[item.own_key.."effect"] = true
	hd[item.own_key.."poison"] = poison
	-- 强制瞬移到腐心，避免打包盒拆出后从旧坐标飘过来
	poison.Position = heart.Position
	poison.Velocity = heart.Velocity
	if poison.SetTimeout then
		poison:SetTimeout(999999)
	end
	return true
end

local function ensure_poison_cloud(heart, spawner)
	if auxi.check_all_exists(heart) ~= true then return nil end
	local d = heart:GetData()
	d[item.own_key.."effect"] = true
	local seed = heart.InitSeed

	local function too_far(p)
		return p and (p.Position - heart.Position):Length() > POISON_REUSE_MAX_DIST
	end

	local poison = nil
	local cached = d[item.own_key.."poison"]
	if auxi.check_all_exists(cached) and is_our_poison(cached) then
		local cd = cached:GetData()
		if cd[item.own_key.."fading"] or too_far(cached) then
			finish_poison_remove(cached)
		else
			poison = cached
		end
	end
	if not poison then
		poison = find_poison_by_heart_seed(seed)
		if too_far(poison) then
			finish_poison_remove(poison)
			poison = nil
		end
	end
	if poison then
		if bind_poison_to_heart(poison, heart) then
			return poison
		end
		finish_poison_remove(poison)
	end

	-- 同 seed 残留全清，再在腐心处生成
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.SMOKE_CLOUD, -1, false, false)) do
		if is_our_poison(ent) then
			local pd = ent:GetData()
			if pd[item.own_key.."heart_seed"] == seed then
				finish_poison_remove(ent:ToEffect())
			end
		end
	end
	poison = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		EffectVariant.SMOKE_CLOUD,
		0,
		heart.Position,
		heart.Velocity,
		spawner
	):ToEffect()
	bind_poison_to_heart(poison, heart)
	return poison
end

--- 进房后：腐心重绑毒雾；找不到腐心的毒雾消散
local function rebind_or_fade_room_poisons()
	local hearts = Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_ROTTEN, false, false)
	for _, ent in ipairs(hearts) do
		local heart = ent:ToPickup()
		if heart and consistance_holder.try_check_entity(heart, HEART_HOLD) then
			ensure_poison_cloud(heart, heart.SpawnerEntity)
		end
	end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.SMOKE_CLOUD, -1, false, false)) do
		if is_our_poison(ent) then
			local d = ent:GetData()
			if d[item.own_key.."fading"] then
			else
				local heart = find_heart_by_seed(d[item.own_key.."heart_seed"])
				if heart and consistance_holder.try_check_entity(heart, HEART_HOLD) then
					if (ent.Position - heart.Position):Length() > POISON_REUSE_MAX_DIST then
						ensure_poison_cloud(heart, heart.SpawnerEntity)
					elseif not bind_poison_to_heart(ent:ToEffect(), heart) then
						begin_poison_fade(ent:ToEffect())
					end
				elseif auxi.check_all_exists(d[item.own_key.."linker"]) then
				else
					begin_poison_fade(ent:ToEffect())
				end
			end
		end
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."effect2"] = {}
		save.elses[item.own_key.."effect3"] = {}
		save.elses[item.own_key.."multi"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."effect2"] = save.elses[item.own_key.."effect2"] or {}
	save.elses[item.own_key.."effect3"] = save.elses[item.own_key.."effect3"] or {}
	save.elses[item.own_key.."multi"] = save.elses[item.own_key.."multi"] or {}
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		if cacheFlag == CacheFlag.CACHE_SIZE then
			save.elses[item.own_key.."multi"] = save.elses[item.own_key.."multi"] or {}
			local mul = save.elses[item.own_key.."multi"][idx]
			if mul then
				player.SpriteScale = player.SpriteScale * mul
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = PickupVariant.PICKUP_HEART,
Function = function(_,ent,col,low)
	if ent.SubType == HeartSubType.HEART_ROTTEN then
		local d = ent:GetData()
		if d[item.own_key.."effect"] and ent.FrameCount < 3 then
			return false
		end
	end
end,
})

--- 腐心再 INIT（进房/小退）：恢复标记并重绑/重挂毒雾
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_HEART,
Function = function(_,ent)
	if ent.SubType ~= HeartSubType.HEART_ROTTEN then return end
	if not consistance_holder.try_check_entity(ent,HEART_HOLD) then return end
	ensure_poison_cloud(ent, ent.SpawnerEntity)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	rebind_or_fade_room_poisons()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = EffectVariant.SMOKE_CLOUD,
Function = function(_,ent)
	if not is_our_poison(ent) then return end
	local d = ent:GetData()
	if d[item.own_key.."fading"] then return end
	local heart = find_heart_by_seed(d[item.own_key.."heart_seed"])
	if heart and consistance_holder.try_check_entity(heart, HEART_HOLD) then
		bind_poison_to_heart(ent, heart)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = EffectVariant.SMOKE_CLOUD,
Function = function(_,ent)
	local d = ent:GetData()
	if not d[item.own_key.."effect"] then return end
	if d[item.own_key.."fading"] then
		ent.Velocity = ent.Velocity * 0.75
		local left = (tonumber(d[item.own_key.."fade_left"]) or 0) - 1
		d[item.own_key.."fade_left"] = left
		-- Timeout  alone 对 SMOKE_CLOUD 不可靠；倒计时结束强制 Remove，避免拆盒救活
		if left <= 0 or (ent.Timeout ~= nil and ent.Timeout >= 0 and ent.Timeout <= 0) then
			finish_poison_remove(ent)
		end
		return
	end
	local linker = d[item.own_key.."linker"]
	if auxi.check_all_exists(linker) ~= true then
		local heart = find_heart_by_seed(d[item.own_key.."heart_seed"])
		if heart and consistance_holder.try_check_entity(heart, HEART_HOLD) then
			if bind_poison_to_heart(ent, heart) then
				linker = heart
			else
				begin_poison_fade(ent)
				return
			end
		else
			begin_poison_fade(ent)
			return
		end
	end
	local dir = (linker.Position + linker.Velocity - ent.Position)
	if dir:Length() > POISON_REUSE_MAX_DIST then
		-- 异常远离（拆盒等）：直接贴心，不慢飘
		ent.Position = linker.Position
		ent.Velocity = linker.Velocity
	elseif dir:Length() > 0.1 then
		ent.Velocity = dir:Normalized() * math.min(15 + math.min(20,ent.FrameCount),dir:Length() * 0.4)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	if save.elses[item.own_key.."effect"][idx] then
		save.elses[item.own_key.."multi"][idx] = (save.elses[item.own_key.."multi"][idx] or 1) * 0.9 + 3 * 0.1
		if math.abs(save.elses[item.own_key.."multi"][idx] - 3) > 0.03 then
		else
			if save.elses[item.own_key.."multi"][idx] ~= 3 then
				save.elses[item.own_key.."multi"][idx] = 3
				save.elses[item.own_key.."effect"][idx] = nil
			end
		end
		player:AddCacheFlags(CacheFlag.CACHE_SIZE)
		d.should_evaluate_on_update_once = true
	elseif save.elses[item.own_key.."multi"][idx] then
		if save.elses[item.own_key.."effect2"][idx] then
			save.elses[item.own_key.."multi"][idx] = (save.elses[item.own_key.."multi"][idx] or 1) * 0.95 + 1 * 0.05
			if math.abs(save.elses[item.own_key.."multi"][idx] - 1) > 0.02 then
			else
				save.elses[item.own_key.."effect2"][idx] = nil
				save.elses[item.own_key.."effect3"][idx] = nil
				save.elses[item.own_key.."multi"][idx] = nil
			end
		else
			save.elses[item.own_key.."multi"][idx] = (save.elses[item.own_key.."multi"][idx] or 1) - 0.03
			local rng = player:GetCardRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			if Game():GetFrameCount() % 5 == 2 then
				local should_shoot = false
				local mxn = 100
				if save.elses[item.own_key.."effect3"][idx] then mxn = 250 end
				if player:GetHearts() > 2 or ((player:GetSoulHearts() > 0 or player:GetBoneHearts() > 0) and player:GetHearts() > 0) then
					player:AddHearts(-2)
					should_shoot = true
				elseif rng:RandomInt(1000) < mxn then
					should_shoot = true
				end
				if should_shoot then
					local dir = auxi.ggdir(player,false,false,nil,nil,{ignore_canwork = true,})
					if dir:Length() < 0.01 then dir = player.Velocity:Normalized() end
					dir = - dir
					local pos = player.Position + dir * 15
					local vel = dir * (10 + math.random(1000)/1000 * 3) + auxi.MakeVector(math.random(360)) * math.random(1000)/1000 * (2 + math.random(1000)/1000 * 2)
					local q = Isaac.Spawn(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_HEART,HeartSubType.HEART_ROTTEN,pos,vel,player):ToPickup()
					q:Morph(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_HEART,HeartSubType.HEART_ROTTEN,true,true,true)
					local s = q:GetSprite()
					local hd = q:GetData()
					s:SetLastFrame()
					hd[item.own_key.."effect"] = true
					local height = -20 + math.random(1000)/1000 * (-25)
					q.PositionOffset = Vector(0,height)
					for i = 1,20 do
						delay_buffer.addeffe(function(params)
							local id = params.id or 1
							if q and q:Exists() and not q:IsDead() then
								q.PositionOffset = Vector(0,height * (1 - id * 0.05))
							end
						end,{id = i,},i + 1)
					end
					consistance_holder.try_hold_entity(q,HEART_HOLD)
					ensure_poison_cloud(q, player)
				end
				Game():Fart(player.Position,64 * save.elses[item.own_key.."multi"][idx],player,(save.elses[item.own_key.."multi"][idx] + 1) * 0.5,0)
			end
			if save.elses[item.own_key.."multi"][idx] > 0.8 then
			else
				save.elses[item.own_key.."effect2"][idx] = true
			end
		end
		player:AddCacheFlags(CacheFlag.CACHE_SIZE)
		d.should_evaluate_on_update_once = true
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local d = player:GetData()
	local idx = d.__Index

	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			save.elses[item.own_key.."effect3"][idx] = true
		end
		player:AddCacheFlags(CacheFlag.CACHE_SIZE)
		player:GetData().should_evaluate_on_update_once = true
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		save.elses[item.own_key.."effect"][idx] = true
		save.elses[item.own_key.."effect2"][idx] = nil
	end
end,
})


return item

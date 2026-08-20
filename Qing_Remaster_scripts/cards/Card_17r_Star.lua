local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Star_r,
	own_key = "Thoth_cd17r_Sta_",
}

function item.assign_star(v)
	local q = Isaac.Spawn(1000,112,0,v.Position,Vector(0,0),nil):ToEffect() 
	local s = q:GetSprite() 
	s.Offset = Vector(0,-5)
	local d2 = q:GetData()
	d2[item.own_key.."effect"] = true
	q.Parent = v
	return q
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = nil
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = nil
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_,ent)
	item[item.own_key.."effect"] = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = nil,
Function = function(_,ent)
	if save.elses[item.own_key.."effect"] or (ent.Variant == 300 and ent.SubType == item.entity) then
		local q = item.assign_star(ent)
		q:GetSprite().Color = Color(0,0,0,0)
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		local mul = d[item.own_key.."effect"] or 0
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage * (1 + mul * 0.8)
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay / (1 + mul * 1.5)
		end
		if cacheFlag == CacheFlag.CACHE_TEARFLAG then
			if mul > 0.5 then
				player.TearFlags = player.TearFlags | BitSet128(1<<2,0)
			end
		end
		if cacheFlag == CacheFlag.CACHE_TEARCOLOR then
			player.TearColor = auxi.AddColor(player.TearColor,Color(1.5,2,2,1),1 - mul,mul)
			--if mul > 0 then player.LaserColor = auxi.AddColor(player.LaserColor,Color(1.5,2,2,1),1 - mul,mul) end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	local n_entity = Isaac.GetRoomEntities()
	local mx_cnt = 0
	for u,v in pairs(n_entity) do	
		if v.Variant == 112 and v.Type == 1000 and (v.Position - player.Position):Length() < 100 then
			local d2 = v:GetData()
			if d2[item.own_key.."effect"] then
				mx_cnt = math.max(v:GetSprite().Color.A,mx_cnt)
			end
		end
	end
	d[item.own_key.."effect"] = d[item.own_key.."effect"] or mx_cnt
	if math.abs(d[item.own_key.."effect"] - mx_cnt) > 0.01 then 
		d[item.own_key.."effect"] = d[item.own_key.."effect"] * 0.75 + mx_cnt * 0.25
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	elseif d[item.own_key.."effect"] ~= mx_cnt then 
		d[item.own_key.."effect"] = mx_cnt
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player then
		local d = player:GetData()
		local idx = d.__Index
		if (d[item.own_key.."effect"] or 0) > 0.5 then
			local rng = player:GetCardRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			if rng:RandomInt(1000) > 500 then
				player:SetMinDamageCooldown(cooldown)
				local mx = 8
				for i = 1,mx do
					delay_buffer.addeffe(function(params)
						player:GetSprite().Color = auxi.AddColor(Color(1,1,1,1,0.25,0.25,0.5),Color(1,1,1,1),(mx - i)/mx,i/mx)
					end,{},i)
				end
				return false
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = nil,
Function = function(_,ent)
	if (Game():GetRoom():GetFrameCount() > 1 and item[item.own_key.."effect"]) or save.elses[item.own_key.."effect"] then
		local q = item.assign_star(ent)
		q:GetSprite().Color = Color(0,0,0,0)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 112,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local s = ent:GetSprite()
		local v = ent.Parent
		if auxi.check_all_exists(v) == false then ent.Parent = nil return end
		local d2 = v:GetData()
		d2[item.own_key.."child"] = d2[item.own_key.."child"] or ent
		if auxi.check_for_the_same(d2[item.own_key.."child"],ent) ~= true then
			if auxi.check_all_exists(d2[item.own_key.."child"]) then ent.Parent = nil return
			else d2[item.own_key.."child"] = ent end
		end
		local dir = (v.Position - ent.Position)
		if dir:Length() > 100 then
			ent.Position = v.Position
			ent.Velocity = v.Velocity
		elseif dir:Length() > 0.1 then
			ent.Velocity = dir:Normalized() * math.min(15 + math.min(20,ent.FrameCount),dir:Length() * 0.4)
		end
		if v:ToNPC() then
			if v:IsVulnerableEnemy() and v:IsActiveEnemy() then
				s.Color = auxi.AddColor(s.Color,Color(1,1,1,1),0.9,0.1)
			else
				s.Color = auxi.AddColor(s.Color,Color(0,0,0,0),0.9,0.1)
			end
		else
			if v.Variant == 300 and v.SubType == item.entity then
				s.Color = auxi.AddColor(s.Color,Color(1,1,1,0.5),0.9,0.1)
			else
				s.Color = auxi.AddColor(s.Color,Color(1,1,1,1),0.9,0.1)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local n_entity = Isaac.GetRoomEntities()
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then 
			save.elses[item.own_key.."effect"] = true
			for u,v in pairs(n_entity) do
				if v:ToPickup() then
					item.assign_star(v)
				end
			end
		end
		item[item.own_key.."effect"] = true
		for u,v in pairs(n_entity) do
			if v:ToNPC() and v:IsActiveEnemy() then
				item.assign_star(v)
			end
		end
	end
end,
})

return item
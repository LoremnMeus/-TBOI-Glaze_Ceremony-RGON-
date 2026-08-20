local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Time_holder = require("Qing_Remaster_scripts.others.Time_holder")
local item_pool_holder = require("Qing_Remaster_scripts.callbacks.item_pool_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local every_entity_holder = require("Qing_Remaster_scripts.callbacks.every_entity_holder")
local player_Anna = require("Qing_Remaster_scripts.player.player_Anna")
local card_06r_lover = require("Qing_Remaster_scripts.cards.Card_06r_lover")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Slots.Rift_beggar,
	entity2 = enums.Entities.Rift_Beggar_Helper,
	own_key = "Slot_Rift_beggar_",
	limit = 25,
	reward_info = {
		{frame = 0,scale = Vector(0,0),A = 0,pos = Vector(0,-32),},
		{frame = 2,scale = Vector(0,0),A = 0,pos = Vector(0,-32),},
		{frame = 3,scale = Vector(0.4,1.6),A = 1,pos = Vector(0,-32),},
		{frame = 5,scale = Vector(1,1),A = 1,pos = Vector(0,-48),},
		{frame = 7,scale = Vector(1,1),A = 1,pos = Vector(0,-48),},
		{frame = 11,scale = Vector(1,1),A = 1,pos = Vector(0,-12),},
		{frame = 13,scale = Vector(1,1),A = 1,pos = Vector(0,-10),},
		{frame = 19,scale = Vector(1,1),A = 1,pos = Vector(0,-10),},
		{frame = 20,scale = Vector(1,1),A = 0,pos = Vector(0,-10),},
	},
	wordinfo = {
		["zh"] = {
			[1] = "还要",
			[2] = "个",
		},
		["en"] = {
			[1] = "Needs ",
			[2] = "pickups.",
		},
	},
}

function item.select_items(rng)
	local ret = {}
	local tbl1 = card_06r_lover.get_pool(4)
	local tbl2 = card_06r_lover.get_pool(3)
	for u,v in pairs(tbl1) do if not auxi.have_player_has_collectible(v) then table.insert(ret,#ret + 1,v) end end
	--for u,v in pairs(tbl2) do if not auxi.have_player_has_collectible(v) then table.insert(ret,#ret + 1,v) end end
	if #ret == 0 then return tbl1[1] or tbl2[1] end
	return auxi.random_in_table(ret,rng)
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_INIT, params = item.entity.Variant,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	s.Offset = Vector(0,5)
	local q = Isaac.Spawn(1000,item.entity2,0,ent.Position,Vector(0,0),nil):ToEffect()
	q.Parent = ent
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if not succ then
		consistance_holder.try_hold_over_entity(ent,item.own_key)
		consistance_holder.try_hold_entity(ent,item.own_key)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = item.entity2,
Function = function(_,ent)
	local s = ent:GetSprite()
	s:Play("Appear",true)
	ent.DepthOffset = -10
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.entity2,
Function = function(_,ent)
	local s = ent:GetSprite()
	local anim = s:GetAnimation()
	local frame = s:GetFrame()
	if auxi.check_all_exists(ent.Parent) ~= true then
		if anim ~= "Disappear" then s:Play("Disappear",true) end
		if s:IsFinished("Disappear") then ent:Remove() return end
		ent.Velocity = ent.Velocity * 0.5
	else
		ent.Position = ent.Parent.Position
		ent.Velocity = ent.Parent.Velocity
		ent.PositionOffset = ent.Parent.PositionOffset
	end
	if s:IsFinished("Appear") then s:Play("Opened",true) end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_COLLISION, params = item.entity.Variant,
Function = function(_,ent,col,low)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local rng = ent:GetDropRNG()
	if s:IsPlaying("Idle") then 
		--if rng:RandomFloat() > 0.3 then s:Play("PayPrize",true)	
		--else s:Play("PayNothing",true) end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_UPDATE, params = item.entity.Variant,
Function = function(_,ent)
	local s = ent:GetSprite()
	local anim = s:GetAnimation()
	local frame = s:GetFrame()
	local d = ent:GetData()
	local rng = ent:GetDropRNG()
	if s:IsFinished("Teleport") then ent:Remove() return end
	if s:IsFinished("Death") then local q = Isaac.Spawn(5,10,6,ent.Position,auxi.RoundVector(rng,5),nil) ent:Remove() return end
	if s:IsFinished("Prize") then 
		local room = Game():GetRoom()
		local colid = item.select_items(rng)
		local q = Isaac.Spawn(5,100,colid,room:FindFreePickupSpawnPosition(ent.Position + Vector(0,40),10,true),Vector(0,0),ent)
		local succ = false
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			if player:GetPlayerType() == item.entity and auxi.has_have_coll(player,619) then succ = true break end
		end
		if rng:RandomFloat() > 0.25 and succ ~= true then s:Play("Teleport",true) end
	end
	if anim == "PayNothing" or anim == "PayPrize" then
		if auxi.check_all_exists(d[item.own_key.."tg"]) then
			local tg = d[item.own_key.."tg"]
			tg.Position = ent.Position
			tg.Velocity = Vector(0,0)
			tg.DepthOffset = 20
			local info = auxi.check_lerp(frame,item.reward_info)
			tg.Color = auxi.table2color(info)
			tg:GetSprite().Scale = info.scale
			tg.PositionOffset = ent.PositionOffset + info.pos
			if frame >= 21 then tg:Remove() d[item.own_key.."tg"] = nil end
		end
	end
	local tgs = auxi.getothers(nil,5,nil,nil,function(ent) if ent.Variant ~= 100 then return true end end)	--and ent:ToPickup().Price == 0
	for u,v in pairs(tgs) do 
		local dir = ent.Position - v.Position
		dir = dir:Normalized() * math.max(0,dir:Length() - ent.Size)
		if dir:Length() < 100 + ent.Size then
			
			if dir:Length() < ent.Size + v.Size + 10 then
				if s:IsPlaying("Idle") then
					local succ = consistance_holder.try_check_entity(ent,item.own_key)
					if not succ then consistance_holder.try_hold_over_entity(ent,item.own_key) end
					d._Data[item.own_key]["Counter"] = (d._Data[item.own_key]["Counter"] or 0) + 1
					if d._Data[item.own_key]["Counter"] < item.limit then 
						s:Play("PayNothing",true)
					else 
						d._Data[item.own_key]["Counter"] = 0
						s:Play("PayPrize",true) 
					end 
					consistance_holder.try_hold_entity(ent,item.own_key)
					local q = player_Anna.replace_with(v,{Sprite = true,Position = ent.Position,})
					auxi.safely_remove(v)
					d[item.own_key.."tg"] = q
				end
			end
			if ent.FrameCount % 10 == 5 then
				v.Velocity = v.Velocity * 0.7 + dir * 0.3 * 0.5
			end
			if v.TargetPosition:Length() > 1 then v.TargetPosition = v.TargetPosition + dir * 0.1 end
		end
	end
	if s:IsFinished("Prize") or s:IsFinished("PayNothing") then s:Play("Idle",true) end
	if s:IsFinished("PayPrize") then s:Play("Prize",true) end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_KILL, params = item.entity.Variant,
Function = function(_,ent,killer)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local rng = ent:GetDropRNG()
	s:Play("Death",true)
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	Game():GetLevel():SetStateFlag(LevelStateFlag.STATE_EVIL_BUM_KILLED,true)
	if auxi.check_all_exists(d[item.own_key.."tg"]) then d[item.own_key.."tg"]:Remove() end
	local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v:ToPickup() and v.FrameCount == 0 then v:Remove() end end
end,
})
--[[
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_INIT, params = 5,
Function = function(_,ent)
	local room = Game():GetRoom()
	if ent.FrameCount == 0 and (room:IsFirstVisit() or room:GetFrameCount() ~= 0) then 
		local rng = ent:GetDropRNG()
		if rng:RandomInt(100) <= 2 then
			local q = Isaac.Spawn(item.entity.Type,item.entity.Variant,0,ent.Position,Vector(0,0),nil)
			every_entity_holder.init_slot(q)
			ent:Remove()
		end
	end
end,
})
--]]

if EID then
	EID:addDescriptionModifier("qing_slot_desc", function(desc) return true end, function(desc)
		if auxi.check_all_exists(desc.Entity) and desc.Entity.Type == 6 and desc.Entity.Variant == item.entity.Variant then
			local d = desc.Entity:GetData()
			local language = Options.Language 
			if item.wordinfo[language] == nil then language = "zh" end
			local infomap = item.wordinfo[language]
			local info = infomap[1]..tostring(item.limit - (((d._Data or {})[item.own_key] or {})["Counter"] or 0))..infomap[2]
            if info and info ~= "" then
				if string.sub(info,0,1) ~= "#" then info = "#"..info end
                --local repl = "#{{Player"..item.entity.."}} "
               -- info = string.gsub(info, "#", repl)
                EID:appendToDescription(desc, info)
            end
        end
        return desc
	end)
end

return item
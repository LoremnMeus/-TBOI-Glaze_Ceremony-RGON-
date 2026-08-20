local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Time_holder = require("Qing_Remaster_scripts.others.Time_holder")
local item_pool_holder = require("Qing_Remaster_scripts.callbacks.item_pool_holder")
local every_entity_holder = require("Qing_Remaster_scripts.callbacks.every_entity_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Slots.Time_beggar,
	own_key = "Slot_Time_Beggar_",
	reward = {
		[1] = {
			work = function(ent,rng,info,item) 
				local rnd = rng:RandomInt(1) + 1
				for i = 1,rnd do Isaac.Spawn(5,20,0,ent.Position,auxi.RoundVector(rng,3,{leg2 = 3,ang = 120,ang2 = 30,}),ent) end
			end,
			weigh = 30,
		},
		[2] = {
			work = function(ent,rng,info,item) 
				local room = Game():GetRoom()
				local colid = item_pool_holder.get_coll_from(item.own_key,true,rng)
				Isaac.Spawn(5,100,colid,room:FindFreeTilePosition(ent.Position + Vector(0,40),10),Vector(0,0),ent)
				return true
			end,
			weigh = 6,
		},
		[3] = {
			work = function(ent,rng,info,item) 
				local room = Game():GetRoom()
				if save.elses[item.own_key.."Trinket"] ~= true then
					save.elses[item.own_key.."Trinket"] = true
					Isaac.Spawn(5,350,79,ent.Position,auxi.RoundVector(rng,3,{leg2 = 3,ang = 120,ang2 = 30,}),ent)
					return true
				end
			end,
			weigh = 2,
		},
	},
	target = {
		[CollectibleType.COLLECTIBLE_STEVEN] = {id = CollectibleType.COLLECTIBLE_STEVEN,weigh = 1,},
		[CollectibleType.COLLECTIBLE_XRAY_VISION] = {id = CollectibleType.COLLECTIBLE_XRAY_VISION,weigh = 1,},
		[CollectibleType.COLLECTIBLE_LITTLE_STEVEN] = {id = CollectibleType.COLLECTIBLE_LITTLE_STEVEN,weigh = 1,},
		[CollectibleType.COLLECTIBLE_STOP_WATCH] = {id = CollectibleType.COLLECTIBLE_STOP_WATCH,weigh = 1,},
		[CollectibleType.COLLECTIBLE_BROKEN_WATCH] = {id = CollectibleType.COLLECTIBLE_BROKEN_WATCH,weigh = 1,},
		[CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS] = {id = CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS,weigh = 1,},
		[enums.Items.Memory] = {id = enums.Items.Memory,weigh = 1,},
		[enums.Items.Book_of_Future] = {id = enums.Items.Book_of_Future,weigh = 1,},
		[enums.Items.Theseus_s_Sign] = {id = enums.Items.Theseus_s_Sign,weigh = 1,},
		[enums.Items.Hypermnesia] = {id = enums.Items.Hypermnesia,weigh = 1,},
		[enums.Items.Ending_Count] = {id = enums.Items.Ending_Count,weigh = 1,},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_ITEMPOOL, params = nil,
Function = function(_,name,val)
	val[item.own_key] = {list = auxi.deepCopy(item.target),default = CollectibleType.COLLECTIBLE_STEVEN,}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_INIT, params = item.entity.Variant,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	s.Offset = Vector(0,5)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_COLLISION, params = item.entity.Variant,
Function = function(_,ent,col,low)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local rng = ent:GetDropRNG()
	if s:IsPlaying("Idle") then 
		if rng:RandomFloat() > 0.3 then	s:Play("PayPrize",true)	
		else s:Play("PayNothing",true) end
		col:SetColor(Color(-0.2,-0.2,-0.2,1),45,10,true,false)
		Time_holder.settime(-30 * 60)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_UPDATE, params = item.entity.Variant,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local rng = ent:GetDropRNG()
	if s:IsFinished("Teleport") then ent:Remove() return end
	if s:IsFinished("Prize") then 
		local info = auxi.random_in_weighed_table(item.reward,rng)
		local succ = auxi.check_if_any(info.work,ent,rng,info,item)
		if succ then 
			s:Play("Teleport",true)
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
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
	s:Play("Teleport",true)
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	Game():GetLevel():SetStateFlag(LevelStateFlag.STATE_BUM_KILLED,true)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_INIT, params = 4,
Function = function(_,ent)
	local room = Game():GetRoom()
	if ent.FrameCount == 0 and (room:IsFirstVisit() or room:GetFrameCount() ~= 0) then 
		local rng = ent:GetDropRNG()
		local rnd = rng:RandomInt(50)
		if rnd < auxi.get_player_s_max_item() then
			local q = Isaac.Spawn(item.entity.Type,item.entity.Variant,0,ent.Position,Vector(0,0),nil)
			every_entity_holder.init_slot(q)
			ent:Remove()
		end
	end
end,
})

return item
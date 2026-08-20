local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Sage_r,
	own_key = "Thoth_cd1r_Sag_",
	fire_info = {
		[1] = {
			{Variant = 0,weigh = 200,},
			{Variant = 1,weigh = 75,},
			{Variant = 2,weigh = 30,},
			{Variant = 3,weigh = 15,},
			{Variant = 4,weigh = 1,},
		},
		[2] = {
			{Variant = 0,weigh = 100,},
			{Variant = 1,weigh = 45,},
			{Variant = 2,weigh = 50,},
			{Variant = 3,weigh = 25,},
			{Variant = 4,weigh = 1,},
		},
	},
	ignores = {
		[1] = true,
		[2] = true,
		[3] = true,
		[4] = true,
		[7] = true,
		[8] = true,
		[9] = true,
		[1000] = true,
	},
	dirs = {
		Vector(0,10),
		Vector(0,-10),
		Vector(10,0),
		Vector(-10,0),
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 33,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d[item.own_key.."effect"] and ent.State ~= 3 then
		local players = Isaac.FindInRadius(ent.Position,40,EntityPartition.PLAYER)
		if #players > 0 then ent:TakeDamage(1,DamageFlag.DAMAGE_EXPLOSION,EntityRef(v),0) end
	end
	if d[item.own_key.."effect2"] then
		s.Color = auxi.AddColor(Color(1,1,1,1),Color(1,1,1,0),math.min(1,ent.FrameCount/30),math.max(0,1 - ent.FrameCount/30))
		if ent.FrameCount >= 30 then d[item.own_key.."effect2"] = nil end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local info = item.fire_info[1]
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then info = item.fire_info[2] end
		local room = Game():GetRoom()
		local n_fires = Isaac.FindByType(33,-1)
		for u,v in pairs(n_fires) do if v.Variant <= 3 then 
			v:GetData()[item.own_key.."effect"] = true 
			v.HitPoints = v.MaxHitPoints
			v:ToNPC().State = 8 
		end end
		local n_entity = Isaac.GetRoomEntities()
		local pool = {}
		for u,v in pairs(n_entity) do if auxi.check_if_any(item.ignores[v.Type],v) ~= true then 
			local gidx = room:GetGridIndex(v.Position)
			pool[gidx] = 0 
			for uu,vv in pairs(item.dirs) do
				local gidx2 = room:GetGridIndex(room:GetGridPosition(gidx) + vv * 4)
				pool[gidx2] = (pool[gidx2] or 1)
			end
		end end
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			for u,v in pairs(item.dirs) do pool[room:GetGridIndex(player.Position + v)] = 0 end
		end
		for i = 1,room:GetGridSize() do
			local pos = room:GetGridPosition(i)
			if room:IsPositionInRoom(pos,0) and (room:FindFreePickupSpawnPosition(pos,10,true) - pos):Length() < 0.1 and pool[i] == 1 then
				local q = Isaac.Spawn(33,auxi.random_in_weighed_table(info,rng).Variant,0,pos,Vector(0,0),nil)
				local d2 = q:GetData()
				if q.Variant ~= 4 then d2[item.own_key.."effect"] = true end
				d2[item.own_key.."effect2"] = true
				q:GetSprite().Color = Color(0,0,0,0)
			end
		end
		
	end
end,
})

return item
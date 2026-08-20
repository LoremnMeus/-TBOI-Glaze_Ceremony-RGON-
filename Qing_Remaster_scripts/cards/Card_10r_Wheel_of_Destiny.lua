local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Wheel_of_Destiny_r,
	own_key = "Thoth_cd10r_Whe_",
	check_variant = {
		[10] = true,
		[20] = true,
		[30] = true,
		[40] = true,
		[42] = true,
		[69] = true,
		[70] = true,
		[90] = true,
		[300] = true,
		[350] = true,
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	for u,v in pairs(save.elses[item.own_key.."effect"]) do
		if type(v) == "table" then
			local tg_pos = nil
			for i = #v,1,-1 do
				local q = v[i]
				if auxi.check_all_exists(q) == false then 
					table.remove(v,i)
				else 
					tg_pos = (tg_pos or Vector(0,0)) + q.Position 
				end
			end
			if #v == 0 then
				save.elses[item.own_key.."effect"][u] = nil
			else
				tg_pos = tg_pos / (#v)
				save.elses[item.own_key.."effect"][u].position = (save.elses[item.own_key.."effect"][u].position or tg_pos) * 0.7 + tg_pos * 0.3
				save.elses[item.own_key.."effect"][u].angle = (save.elses[item.own_key.."effect"][u].angle or math.random(360)) + 10
				for i = 1,#v do
					local q = v[i]
					q:GetData()[item.own_key.."orderposition"] = save.elses[item.own_key.."effect"][u].position + auxi.MakeVector(i * 360/(#v) + save.elses[item.own_key.."effect"][u].angle) * 10 * ((#v) + 1)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = nil,
Function = function(_,ent)
	if item.check_variant[ent.Variant] then
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ then
			local d = ent:GetData()
			d[item.own_key.."addme"] = true
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	if item.check_variant[ent.Variant] then
		local d = ent:GetData()
		if d[item.own_key.."orderposition"] then
			local dir = (ent:GetData()[item.own_key.."orderposition"] - ent.Position)
			if dir:Length() > 0.1 then
				if ent.Price ~= 0 or (ent.Type == 20 and ent.Variant == 6) then
					ent.TargetPosition = ent.TargetPosition * 0.5 + ent:GetData()[item.own_key.."orderposition"] * 0.5
				else
					ent.Velocity = dir:Normalized() * math.min(25,dir:Length() * 0.4)
				end
			end
			ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
		end
		if d[item.own_key.."addme"] then	
			d[item.own_key.."addme"] = nil
			local ndx = ent.OptionsPickupIndex
			if ndx then
				save.elses[item.own_key.."effect"][ndx] = save.elses[item.own_key.."effect"][ndx] or {}
				table.insert(save.elses[item.own_key.."effect"][ndx],#save.elses[item.own_key.."effect"][ndx] + 1,ent)
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
		local cnt = 3 + rng:RandomInt(3)
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then cnt = 5 + rng:RandomInt(3) end
		local n_entity = Isaac.GetRoomEntities()
		for u,v in pairs(n_entity) do
			if v.Type == 5 and item.check_variant[v.Variant] then
				v = v:ToPickup()
				local ndx = v.OptionsPickupIndex
				if ndx <= 0 then ndx = option_index_holder.find_a_new_index() end
				local price = v.Price
				local pos = v.Position
				local nidx = math.random(360)
				consistance_holder.try_remove_entity(v,item.own_key)
				for i = 1,cnt do
					local q = Isaac.Spawn(5,0,1,pos + auxi.MakeVector(i * 360/cnt + nidx) * 5,Vector(0,0),player):ToPickup()
					q.OptionsPickupIndex = ndx
					q.Price = price
					consistance_holder.try_hold_entity(q,item.own_key)
					save.elses[item.own_key.."effect"][ndx] = save.elses[item.own_key.."effect"][ndx] or {}
					table.insert(save.elses[item.own_key.."effect"][ndx],#save.elses[item.own_key.."effect"][ndx] + 1,q)
				end
				v:Remove()
			end
		end
	end
end,
})

return item
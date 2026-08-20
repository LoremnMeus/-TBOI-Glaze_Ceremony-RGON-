local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Blood_Wing,
	own_key = "Item_Blood_Wing_",
	time_counter = 60,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		if cacheFlag == CacheFlag.CACHE_FLYING then
			player.CanFly = true
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local room = Game():GetRoom()
	local s = player:GetSprite()
	local d = player:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		if auxi.has_have_coll(player,item.entity) then
			d[item.own_key.."counter"] = d[item.own_key.."counter"] or 0
			local cnt = d[item.own_key.."counter"]
			d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
			if cnt > 5 or d[item.own_key.."fire"] then
				local ccnt = cnt/item["time_counter"]
				if d[item.own_key.."fire"] then ccnt = (d[item.own_key.."fire"].counter/30) end
				local pos = Isaac.WorldToScreen(player.Position + player_offset_holder.GetPlayerOffset(player)) + Vector(0,-12) * player.SpriteScale.Y
				local dir = auxi.getdir(player)
				if dir:Length() < 0.05 then dir = auxi.getmov(player) end
				if dir:Length() < 0.05 then dir = auxi.MakeVector(d[item.own_key.."effect"]["dir"]) end
				d[item.own_key.."effect"]["dir"] = auxi.checkrounded(d[item.own_key.."effect"]["dir"] or (dir:GetAngleDegrees()),(dir:GetAngleDegrees()),0.8,0.2,360)
				local ddir = auxi.MakeVector(d[item.own_key.."effect"]["dir"])
				d[item.own_key.."sprite"] = d[item.own_key.."sprite"] or {}
				for i = 1,5 do
					d[item.own_key.."effect"][i] = d[item.own_key.."effect"][i] or {}
					if ccnt > i/5 then
						if d[item.own_key.."sprite"][i] == nil then 
							local s = Sprite()
							s:Load("gfx/mimics/Blood_Wing/Wing.anm2")
							s:Play("Appear")
							d[item.own_key.."sprite"][i] = s
						end
					elseif d[item.own_key.."sprite"][i] then 
						d[item.own_key.."sprite"][i].Color = auxi.MulColor(d[item.own_key.."sprite"][i].Color,Color(1,1,1,0.5))
						if d[item.own_key.."sprite"][i].Color.A < 0.01 then d[item.own_key.."sprite"][i] = nil end
					end
					local mv = auxi.get_by_rotate(ddir,90,i * 20 - (1 - player.SpriteScale.X) * 10)
					local tv = Vector(0,-math.abs(ddir.X) * 10 * player.SpriteScale.Y)
					local tpos = pos + mv + tv
					local tpos2 = pos - mv + tv
					
					local s = d[item.own_key.."sprite"][i]
					if s then
						if d[item.own_key.."Update"] then s:Update() end
						if s:IsFinished("Appear") then s:Play("Idle",true) end
						s.Rotation = ddir:GetAngleDegrees() + 90
						d[item.own_key.."effect"][i].pos1 = auxi.real_ScreenToWorld(tpos)
						d[item.own_key.."effect"][i].pos2 = auxi.real_ScreenToWorld(tpos2)
						s:Render(tpos,Vector(0,0),Vector(0,0))
						s:Render(tpos2,Vector(0,0),Vector(0,0))
					end
				end
				d[item.own_key.."Update"] = nil
			else
				d[item.own_key.."sprite"] = {}
				d[item.own_key.."effect"] = {}
			end
			Charging_Bar_holder.render_me(player,{name1 = item.own_key.."counter",name2 = item.own_key.."sprite",name3 = item.own_key,loadname = "gfx/effects/chargebar/chargebar_Blood_Wing.anm2",
				check1 = function(val,ent)
					return cnt > 5
				end,
				check2 = function(val,ent) 
					return cnt > item["time_counter"]
				end,
				check3 = function(val,ent)
					return math.ceil(cnt/item["time_counter"] * 100)
				end,
				signal1 = function(ent)
					d[item.own_key.."active"] = true
				end,
			})
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	if collid == item.entity and count < 0 then
		Charging_Bar_holder.remove_charge_bar(player,item.own_key)
	end
end,
})

function item.real_collideswithgrid(player)
	if player:CollidesWithGrid() then return true end
	local mov = player:GetMovementInput()
	for u,v in pairs(auxi.splitvector(mov)) do
		local pos = player.Position + v * (player.Size + 1)
		local room = Game():GetRoom()
		if room:GetGridCollisionAtPos(pos) == GridCollisionClass.COLLISION_WALL then return true end		--player.Velocity:Length() < 1 and 
	end
	return false
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		local d = player:GetData()
		d[item.own_key.."Update"] = true
		if d[item.own_key.."fire"] then
			player:SetMinDamageCooldown(math.max(0,3 - player:GetDamageCooldown()))
			if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] == nil then d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = Attribute_holder.try_hold_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) end
			d[item.own_key.."fire"].counter = (d[item.own_key.."fire"].counter or 0) - 1
			local dir = auxi.MakeVector((d[item.own_key.."effect"] or {})["dir"]) or auxi.getdir(player)
			player.Velocity = dir * 15
			local succ = nil
			for i = 1,5 do
				d[item.own_key.."effect"][i] = d[item.own_key.."effect"][i] or {}
				if d[item.own_key.."sprite"][i] and d[item.own_key.."sprite"][i].Color.A > 0.1 then 
					for j = 1,2 do 
						if auxi.check_all_exists(d[item.own_key.."effect"][i]["laser"..tostring(j)]) ~= true then
							local q = player:FireBrimstone(-dir,nil,0.3)
							q.Parent = nil
							q.PositionOffset = Vector(0,0)
							d[item.own_key.."effect"][i]["laser"..tostring(j)] = q
							q:SetTimeout(120)
							if Game():GetRoom():GetFrameCount() == 0 then succ = true end
						end
						local q = d[item.own_key.."effect"][i]["laser"..tostring(j)]
						q.Position = d[item.own_key.."effect"][i]["pos"..tostring(j)]
						q.Angle = dir:GetAngleDegrees() + 180
						q.Color = d[item.own_key.."sprite"][i].Color
					end
				else
					for j = 1,2 do
						local q = d[item.own_key.."effect"][i]["laser"..tostring(j)]
						if auxi.check_all_exists(q) then 
							q.Color = Color(1,1,1,0)
							q:SetTimeout(2) 
							d[item.own_key.."effect"][i]["laser"..tostring(j)] = nil 
						end
					end
				end
			end
			if succ then delay_buffer.addeffe(function(params) SFXManager():Stop(7) end,{},1) end
			if d[item.own_key.."fire"].counter <= 0 then 
				if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] then Attribute_holder.try_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = nil end
				d[item.own_key.."fire"] = nil 
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local ctrlid = player.ControllerIndex
		local d = player:GetData()
		if auxi.g_dir_can_work(player) then
			if auxi.has_have_coll(player,item.entity) and d[item.own_key.."fire"] == nil then
				if item.real_collideswithgrid(player) then d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1 
				else 
					if d[item.own_key.."active"] then d[item.own_key.."active"] = nil d[item.own_key.."fire"] = {counter = 2 * 60,} d[item.own_key.."counter"] = 0 end
					d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) * 0.5 
					if d[item.own_key.."counter"] <= 5 then d[item.own_key.."counter"] = 0 end
				end
			end
		end
	end
end,
})

return item
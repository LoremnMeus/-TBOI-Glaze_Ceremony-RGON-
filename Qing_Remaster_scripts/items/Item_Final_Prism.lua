local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Habit_holder = require("Qing_Remaster_scripts.mimics.Habit_holder")
local Plug_holder = require("Qing_Remaster_scripts.mimics.Plug_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Final_Prism,
	own_key = "Item_Final_Prism_",
	limit = 6,
	step = 3,
	posinfo = {
		{frame = 0,leg = 20,aleg = 20,rate = 0.01,colorrate = 0,Orate = 0,},
		{frame = 60,leg = 20,aleg = 10,rate = 0.05,colorrate = 0,Orate = 0,},
		{frame = 5 * 60,leg = 20,aleg = 5,rate = 0.1,colorrate = 0.25,Orate = 0.1,},
		{frame = 10 * 60,leg = 20,aleg = 2,rate = 0.2,colorrate = 0.5,Orate = 0.2,},
		{frame = 20 * 60,leg = 20,aleg = 0.5,rate = 1,colorrate = 1,Orate = 0.5,},
		{frame = 40 * 60,leg = 20,aleg = 0,rate = 1,colorrate = 1,Orate = 1,},
	},
	Colorinfo = {
		{frame = 0 * 6,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 6,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 6,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 6,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 6,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 6,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		
		{frame = 6 * 6,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 6,
	},
}

Habit_holder.Additem(item.entity,30)
Plug_holder.Additem(item.entity,30)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	local d = player:GetData()
	d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		if d[item.own_key.."effect"][activeSlot] then
			d[item.own_key.."effect"][activeSlot].limit = (d[item.own_key.."effect"][activeSlot].limit or item.limit) + item.step
			if activeSlot == -1 then d[item.own_key.."effect"][activeSlot].Timeout = (d[item.own_key.."effect"][activeSlot].Timeout or 10 * 60) + 2 * 60 end
		else
			d[item.own_key.."effect"][activeSlot] = {}
			d[item.own_key.."effect"][activeSlot].limit = item.limit
			if activeSlot == -1 then d[item.own_key.."effect"][activeSlot].Timeout = 5 * 60 end
		end
	else
		if d[item.own_key.."effect"][activeSlot] then
			player:SetActiveCharge(math.max(0,player:GetActiveCharge(activeSlot) + player:GetBatteryCharge(activeSlot) - 10),activeSlot)
			d[item.own_key.."effect"][activeSlot].limit = (d[item.own_key.."effect"][activeSlot].limit or item.limit) + item.step
			if activeSlot == -1 then d[item.own_key.."effect"][activeSlot].Timeout = (d[item.own_key.."effect"][activeSlot].Timeout or 10 * 60) + 5 * 60 end
		else
			d[item.own_key.."effect"][activeSlot] = {}
			d[item.own_key.."effect"][activeSlot].limit = item.limit
			if activeSlot == -1 then d[item.own_key.."effect"][activeSlot].Timeout = 10 * 60 end
		end
		if auxi.should_spawn_wisp(player,useFlags) then player:AddWisp(item.entity,player.Position,false,false) end
	end
	ret = {Discharge = false,ShowAnim = true,}
	return ret
end,
})

function item.fire_prim_beam(pos,vel,player,params)
	params = params or {}
	local q = Isaac.Spawn(7,1,0,pos or Vector(200,200),vel or Vector(0,0),player):ToLaser()
	local s = q:GetSprite()
	if auxi.should_do_belial(player) then
		s:Load("gfx/mimics/Final_prism/Red_laser.anm2",true)
		s:Play("LargeRedLaser",true)
	else
		s:Load("gfx/laser_concerter.anm2",true)
		s:Play("LargeRedLaser",true)
		for i = 0,1 do s:ReplaceSpritesheet(i,"gfx/effects/lasers/prism_brimstone.png") end s:LoadGraphics() 
	end
	q.Variant = 5
	q.Angle = params.angle or -90
	if Game():GetRoom():GetFrameCount() == 0 then delay_buffer.addeffe(function(params) SFXManager():Stop(276) end,{},1) end
	return q
end

function item.free(data)
	for i = (data.limit or item.limit),1,-1 do
		if auxi.check_all_exists(data[i]) then data[i]:SetTimeout(1) data[i] = nil end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if Game():GetFrameCount() % 10 == 5 then
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local d = player:GetData()
			if auxi.has_have_coll(player,item.entity) then
				for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do 
					if player:GetActiveItem(slot) == item.entity then
						if d[item.own_key.."effect"] and d[item.own_key.."effect"][slot] then
							player:SetActiveCharge(math.max(0,player:GetActiveCharge(slot) + player:GetBatteryCharge(slot) - 1),slot)
							if player:GetActiveCharge(slot) + player:GetBatteryCharge(slot) == 0 then 
								item.free(d[item.own_key.."effect"][slot])
								d[item.own_key.."effect"][slot] = nil 
							end
						else
							if auxi.should_real_charge(player,slot) then
								for i = 1,2 do 
									if auxi.should_real_charge(player,slot) then player:SetActiveCharge(player:GetActiveCharge(slot) + player:GetBatteryCharge(slot) + 1,slot) end
								end
								if not auxi.should_real_charge(player,slot) then sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE,1,1,false,0,2) end
							end
						end
					end
				end
			elseif d[item.own_key.."effect"] then 
				for slot = -1,ActiveSlot.SLOT_POCKET do 
					if d[item.own_key.."effect"][slot] and not d[item.own_key.."effect"][slot].Timeout then
						item.free(d[item.own_key.."effect"][slot])
						d[item.own_key.."effect"][slot] = nil 
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	if d[item.own_key.."effect"] then
		for slot = -1, ActiveSlot.SLOT_POCKET do 
			if d[item.own_key.."effect"][slot] then
				d[item.own_key.."effect"][slot].counter = (d[item.own_key.."effect"][slot].counter or 0) + 1
				local info = auxi.check_lerp(d[item.own_key.."effect"][slot].counter,item.posinfo)
				local ggdir = auxi.ggdir(player,false,true)
				if ggdir:Length() > 0.05 then d[item.own_key.."effect"][slot].dir = ggdir end
				local dir = d[item.own_key.."effect"][slot].dir or Vector(0,-1)
				local lim = d[item.own_key.."effect"][slot].limit or item.limit
				for i = 1,lim do
					if auxi.check_all_exists(d[item.own_key.."effect"][slot][i]) ~= true then
						d[item.own_key.."effect"][slot][i] = item.fire_prim_beam(player.Position,Vector(0,0),player,{angle = dir:GetAngleDegrees(),})
					else
						local colinfo = auxi.check_lerp((d[item.own_key.."effect"][slot].counter + i * item.Colorinfo.total/lim) % item.Colorinfo.total,item.Colorinfo)
						local ve = d[item.own_key.."effect"][slot][i]
						local ang = d[item.own_key.."effect"][slot].counter * 5 + i * 360/lim + slot * 3
						local vang = auxi.MakeVector(ang)
						local ddir = Vector(1,0) * info.leg + Vector(0,vang.Y * info.aleg)
						ve.Angle = auxi.AddAngle(ve.Angle,dir:GetAngleDegrees() + ddir:GetAngleDegrees(),0.5,0.5)
						ve.Position = player.Position
						ve.CollisionDamage = player.Damage * info.rate
						local se = ve:GetSprite()
						local orate = math.abs(vang.X) * info.Orate
						se.Color = auxi.AddColor(auxi.UpColor(auxi.table2color(colinfo),info.colorrate),Color(1,1,1,1,1,1,1),1 - orate,orate)
					end
				end
				if d[item.own_key.."effect"][slot].Timeout and d[item.own_key.."effect"][slot].counter > d[item.own_key.."effect"][slot].Timeout then
					item.free(d[item.own_key.."effect"][slot])
					d[item.own_key.."effect"][slot] = nil 
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.WISP,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.WISP and ent.SubType == item.entity then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
		local d2 = player:GetData()
		if d2[item.own_key.."effect"] then
			d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
			for slot = -1, ActiveSlot.SLOT_POCKET do 
				if d2[item.own_key.."effect"][slot] then
					d[item.own_key.."effect"][slot] = d[item.own_key.."effect"][slot] or {}
					local dir = d2[item.own_key.."effect"][slot].dir or Vector(0,-1)
					local lim = math.ceil((d2[item.own_key.."effect"][slot].limit or item.limit)* 0.3)
					local info = auxi.check_lerp(d2[item.own_key.."effect"][slot].counter,item.posinfo)
					for i = 1,lim do
						if auxi.check_all_exists(d[item.own_key.."effect"][slot][i]) ~= true then
							d[item.own_key.."effect"][slot][i] = item.fire_prim_beam(player.Position,Vector(0,0),player,{angle = dir:GetAngleDegrees(),})
						else
							local colinfo = auxi.check_lerp((d2[item.own_key.."effect"][slot].counter + i * item.Colorinfo.total/lim) % item.Colorinfo.total,item.Colorinfo)
							local ve = d[item.own_key.."effect"][slot][i]
							local ang = d2[item.own_key.."effect"][slot].counter * 5 + i * 360/lim + slot * 3
							local vang = auxi.MakeVector(ang)
							local ddir = Vector(1,0) * info.leg + Vector(0,vang.Y * info.aleg) * 0.5
							ve.Angle = auxi.AddAngle(ve.Angle,dir:GetAngleDegrees() + ddir:GetAngleDegrees(),0.5,0.5)
							ve.Position = ent.Position
							ve.CollisionDamage = player.Damage * 0.2 * info.rate
							local se = ve:GetSprite()
							local orate = math.abs(vang.X) * info.Orate
							se.Color = auxi.AddColor(auxi.UpColor(auxi.table2color(colinfo),info.colorrate),Color(1,1,1,1,1,1,1),1 - orate,orate)
						end
					end
				elseif d[item.own_key.."effect"][slot] then
					item.free(d[item.own_key.."effect"][slot])
					d[item.own_key.."effect"][slot] = nil
				end
			end
		end
	end
end,
})
--l local q = Isaac.Spawn(7,1,0,Vector(200,200),Vector(0,0),nil) local s = q:GetSprite() s:Load("gfx/laser_concerter.anm2",true) s:Play("LargeRedLaser",true) for i = 0,1 do s:ReplaceSpritesheet(i,"gfx/effects/lasers/prism_brimstone.png") end s:LoadGraphics() q.Variant = 5

return item
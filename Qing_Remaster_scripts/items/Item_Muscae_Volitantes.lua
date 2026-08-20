local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Eraser_holder = require("Qing_Remaster_scripts.others.Eraser_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Muscae_Volitantes,
	own_key = "Item_Muscae_Volitantes_",
	target_layer = {
		{val = 1,dis = 0,},
		{val = 5,dis = 15,},
		{val = 8,dis = 30,},
		{val = 11,dis = 40,},
		{val = 15,dis = 50,},
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

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local pos = Game():GetRoom():FindFreePickupSpawnPosition(player.Position,10,true)
		local rnd = rng:RandomFloat()
		local belial = auxi.should_do_belial(player)
		local virtue = auxi.should_spawn_wisp(player,useFlags)
		if rnd < 0.66 then
			item.try_generate(pos,player,function()
				if virtue or belial then
					if belial then
						local q = Isaac.Spawn(3,43,1,pos,Vector(0,0),nil) q:ClearEntityFlags(EntityFlag.FLAG_APPEAR) 
						local s = q:GetSprite() s:Load("gfx/mimics/Muscae_Volitantes/Muscae_Fly.anm2",true) s:Play("Idle",true)
						local d = q:GetData() d[item.own_key.."effect"] = {counter = auxi.random_1() * item.Colorinfo.total,}
						if belial then d[item.own_key.."effect"].belial = true end
					end
					if virtue then
						local q = player:AddWisp(colid,pos,true) --q:Update() 
						Eraser_holder.add_eraser_spawner_effect(q)
						local s = q:GetSprite() s:Load("gfx/mimics/Muscae_Volitantes/Muscae_Fly.anm2",true) s:Play("Idle",true)
						local d = q:GetData() d[item.own_key.."effect"] = {counter = auxi.random_1() * item.Colorinfo.total,}
						if belial then d[item.own_key.."effect"].belial = true end
					end
				else
					local rnd = math.random(2) + 1
					for i = 1,rnd do
						local q = Isaac.Spawn(auxi.choose(13,18),0,0,pos,Vector(0,0),nil):ToNPC() q:ClearEntityFlags(EntityFlag.FLAG_APPEAR) q:AddEntityFlags(EntityFlag.FLAG_AMBUSH)
						local s = q:GetSprite() s:Load("gfx/mimics/Muscae_Volitantes/Muscae_Fly.anm2",true) s:Play("Idle",true)
						local d = q:GetData() d[item.own_key.."effect"] = {counter = auxi.random_1() * item.Colorinfo.total,}
						if belial then d[item.own_key.."effect"].belial = true end
					end
				end
			end)
		elseif rnd < 0.99 then
			item.try_generate(pos,player,function()
				local q = Isaac.Spawn(5,350,0,pos,Vector(0,0),nil):ToPickup() local s = q:GetSprite() s:SetLastFrame()
				return q
			end)
		else 
			item.try_generate(pos,player,function()
				local q = Isaac.Spawn(5,100,0,pos,Vector(0,0),nil):ToPickup()
				Eraser_holder.add_eraser_spawner_effect(q)
				return q
			end)
		end
	end
	return ret
end,
})

function item.try_generate(pos,player,spawner)
	local tbl = {}
	local belial = auxi.should_do_belial(player)
	for u,v in pairs(item.target_layer) do
		local starter = math.ceil(auxi.random_1() * item.Colorinfo.total)
		local rnd = auxi.random_1() * 360
		for i = 1,v.val do
			table.insert(tbl,{pos = auxi.get_by_rotate(nil,i/v.val * 360 + rnd,v.dis * (1 + auxi.random_2() * 0.1)),starter = starter + i/v.val * item.Colorinfo.total,})
		end
	end
	local marker = auxi.randomTable(tbl)
	for i = 1,40 do
		local q = Isaac.Spawn(1000,enums.Entities.Muscae_Helper,0,pos + 100 * auxi.random_v2() + 500 * auxi.random_r(),Vector(0,0),nil):ToEffect()
		local d = q:GetData()
		d[item.own_key.."effect"] = {pos = pos + marker[i].pos,start_counter = marker[i].starter,counter = 0,belial = belial,}
	end
	delay_buffer.addeffe(function()
		auxi.check_if_any(spawner,player)
	end,{},40,{remove_now = true,})
end

function item.add_2_red_color(color,r1,r2)
	r1 = r1 or 0.2 r2 = r2 or 0.4
	return Color(color.R + color.G * r1 + color.B * r2,0,0,color.A,color.RO + color.GO * r1 + color.BO * r2,0,0)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 13,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		local s = ent:GetSprite()
		local color = auxi.check_lerp(d[item.own_key.."effect"].counter % item.Colorinfo.total,item.Colorinfo)
		s.Color = auxi.UpColor(color,1)
		if d[item.own_key.."effect"].belial then s.Color = item.add_2_red_color(s.Color) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 18,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		local s = ent:GetSprite()
		local color = auxi.check_lerp(d[item.own_key.."effect"].counter % item.Colorinfo.total,item.Colorinfo)
		s.Color = auxi.UpColor(color,1)
		if d[item.own_key.."effect"].belial then s.Color = item.add_2_red_color(s.Color) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = 43,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		local s = ent:GetSprite()
		local color = auxi.check_lerp(d[item.own_key.."effect"].counter % item.Colorinfo.total,item.Colorinfo)
		s.Color = auxi.UpColor(color,1)
		if d[item.own_key.."effect"].belial then s.Color = item.add_2_red_color(s.Color) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = enums.Entities.Muscae_Helper,
Function = function(_,ent)
	local s = ent:GetSprite()
	s.Color = Color(1,1,1,0)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Muscae_Helper,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d[item.own_key.."effect"] then
		local tgpos = d[item.own_key.."effect"].pos
		if tgpos then
			local dir = (tgpos - ent.Position)
			ent.Velocity = ent.Velocity * 0.8 + dir:Normalized() * math.max(0,math.min(24,(dir:Length())/2)) * 0.2
		end
		ent.Velocity = auxi.apply_friction(ent.Velocity,1)
		d[item.own_key.."effect"].start_counter = (d[item.own_key.."effect"].start_counter or 0) + 1
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		local color = auxi.check_lerp(d[item.own_key.."effect"].start_counter % item.Colorinfo.total,item.Colorinfo)
		local a = s.Color.A
		if d[item.own_key.."effect"].counter < 60 then s.Color = auxi.AddColor(Color(0,0,0,1 - a),auxi.UpColor(color,1),-0.8,1)
		else s.Color = auxi.AddColor(Color(0,0,0,a - 2),auxi.UpColor(color,1),0.5,1) end
		if d[item.own_key.."effect"].counter > 80 then ent:Remove() end
		if d[item.own_key.."effect"].belial then 
			s.Color = item.add_2_red_color(s.Color) 
			local n_enemy = auxi.getenemies(Isaac.FindInRadius(ent.Position,20,1<<3))
			for u,v in pairs(n_enemy) do v:TakeDamage(1.5,0,EntityRef(ent),0) end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = FamiliarVariant.WISP,
Function = function(_,ent)
	if ent.SubType == item.entity then
		local s = ent:GetSprite() s:Load("gfx/mimics/Muscae_Volitantes/Muscae_Fly.anm2",true) s:Play("Idle",true)
		local d = ent:GetData() d[item.own_key.."effect"] = {counter = auxi.random_1() * item.Colorinfo.total,}
		if auxi.should_do_belial(auxi.check_spawner_player(ent)) then d[item.own_key.."effect"].belial = true end
	end
end,
})


table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.WISP,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		local s = ent:GetSprite()
		local color = auxi.check_lerp(d[item.own_key.."effect"].counter % item.Colorinfo.total,item.Colorinfo)
		s.Color = auxi.UpColor(color,1)
		if d[item.own_key.."effect"].belial then s.Color = item.add_2_red_color(s.Color) end
	end
end,
})

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local glaze_curse = require("Qing_Remaster_scripts.pickups.pickup_glaze_curse")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local item = {
	pickup = enums.Pickups.Glaze_grabbag,
	pre_ToCall = {},
	ToCall = {},
	own_key = "Pickup_glaze_enemy_",
	Colorinfo = {
		{frame = 0,R = 0.2,G = 1,B = 1,A = 1,RO = 0,GO = 0,BO = 0,scale = Vector(1,1),},
		{frame = 3,R = 1,G = 0.2,B = 1,A = 1,RO = 0,GO = 0,BO = 0,scale = Vector(1,1),},
		{frame = 6,R = 1,G = 1,B = 0.2,A = 1,RO = 0,GO = 0,BO = 0,scale = Vector(1,1),},
		{frame = 9,R = 0.2,G = 1,B = 1,A = 1,RO = 0,GO = 0,BO = 0,scale = Vector(1,1),},
		{frame = 12,R = 1,G = 0.2,B = 1,A = 1,RO = 0,GO = 0,BO = 0.5,scale = Vector(0.8,1.2),},
		{frame = 15,R = 1,G = 1,B = 0.2,A = 1,RO = 0,GO = 0.7,BO = 1,scale = Vector(1.2,0.8),},
		{frame = 18,R = 0.2,G = 1,B = 1,A = 1,RO = 0,GO = 0,BO = 0,scale = Vector(1,1),},
		total = 18,
	},
}

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
    local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if flag & DamageFlag.DAMAGE_CLONES ~= DamageFlag.DAMAGE_CLONES then
			d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
			if d[item.own_key.."effect"].counter == 1 then return false
			else
				ent:TakeDamage(amt * math.min(0.8,(d[item.own_key.."effect"].counter/10)),flag | DamageFlag.DAMAGE_CLONES,source,cooldown)
				--if source.Entity and source.Entity:ToPlayer() then print(player.SamsonBerserkCharge) end		没有找到修理狂暴头的方法
				return false
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if d[item.own_key.."effect"].Init ~= true then 
			d[item.own_key.."effect"].Init = true
			d[item.own_key.."effect"].RecordColor = Color(1,1,1,1,1,1,1)--auxi.copyColor(ent:GetColor())
			d[item.own_key.."effect"].RecordScale = auxi.copyVec(ent.SpriteScale)
			if d[item.own_key.."effect"].RecordScale:Length() < 0.1 and ent.FrameCount < 2 then d[item.own_key.."effect"].RecordScale = nil end
			local n_entities = auxi.get_linked(ent) 
			for u,v in pairs(n_entities) do	if v.FrameCount == ent.FrameCount then v:GetData()[item.own_key.."effect"] = v:GetData()[item.own_key.."effect"] or {} end end
		end
		d[item.own_key.."effect"].RecordScale = d[item.own_key.."effect"].RecordScale or auxi.copyVec(ent.SpriteScale)
		if ent.FrameCount < 2 and d[item.own_key.."effect"].RecordScale:Length() < 0.1 then d[item.own_key.."effect"].RecordScale = nil end
		local info = auxi.check_lerp(ent.FrameCount % item.Colorinfo.total,item.Colorinfo)
		if ent.Type == 963 then 
			--if d[item.own_key.."Color"] then Attribute_holder.try_rewind_attribute(ent,"Color",d[item.own_key.."Color"],{protect = true,toget = function(ent) return ent:GetColor() end,tochange = function(ent,value) ent:SetColor(value,10,99,false,false) end,tocompare = function(v1,v2) return math.abs(v1.R - v2.R) < 0.01 and math.abs(v1.G - v2.G) < 0.01 and math.abs(v1.B - v2.B) < 0.01 and math.abs(v1.A - v2.A) < 0.01 end,}) d[item.own_key.."Color"] = nil end 
			--if d[item.own_key.."Scale"] then Attribute_holder.try_rewind_attribute(ent,"SpriteScale",d[item.own_key.."Scale"],{protect = true,}) d[item.own_key.."Scale"] = nil end
		end
		--auxi.PrintColor(ent.Color)
		d[item.own_key.."effect"].Color = auxi.MulColor(d[item.own_key.."effect"].RecordColor,auxi.table2color(info))
		d[item.own_key.."effect"].Scale = auxi.mul_t(d[item.own_key.."effect"].RecordScale or Vector(1,1),info.scale)
		d[item.own_key.."Color"] = d[item.own_key.."Color"] or Attribute_holder.try_hold_attribute(ent,"Color",function(ent) if ent.Type == 963 then return Color(0.8,0.8,0.8,1,0.3,0.5,0.8) else return (ent:GetData()[item.own_key.."effect"] or {})["Color"] or ent:GetColor() end end,Attribute_holder.descriptors.color({protect = true}))
		d[item.own_key.."Scale"] = d[item.own_key.."Scale"] or Attribute_holder.try_hold_attribute(ent,"SpriteScale",function(ent) return (ent:GetData()[item.own_key.."effect"] or {})["Scale"] or ent.SpriteScale end,{protect = true,})
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local room = Game():GetRoom()
	if d[item.own_key.."effect"] and room:IsFirstVisit() and ent:CanShutDoors() then
		if (not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and (not ent:IsBoss()) and (not ent:HasEntityFlags(EntityFlag.FLAG_NO_REWARD)) and (not Game():IsGreedMode())then
			local info = item.pickup
			local rng = ent:GetDropRNG()
			rng = auxi.rng_for_sake(rng)
			if rng:RandomInt(30) < ent.MaxHitPoints then
				local wei = 0
				for u,v in pairs(enums.Pickups) do
					wei = wei + v.wei
				end
				wei = rng:RandomInt(wei)
				for u,v in pairs(enums.Pickups) do
					if v.wei > 0 then
						wei = wei - v.wei
						if wei <= 0 then
							info = v
							if u == "Glaze_bomb" and auxi.has_poop_player() then
								info = enums.Pickups.Glaze_big_poop
							end
							break
						end
					end
				end
				local q = Isaac.Spawn(5,info.Variant,info.SubType,ent.Position,math.random(1000)/500 * auxi.MakeVector(math.random(36000)/100),nil)
				auxi.special_morph(q,info)
			end
		end
	end
end,
})

function item.Make_Glazed_Enemy(ent)
	ent:GetData()[item.own_key.."effect"] = {} 
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = nil,
Function = function(_,ent)
	if auxi.isenemies(ent) and Unlocker.should_any_be_done("Pickup","Glaze_Enemy",nil,"Pickup_allow") and ent.Type ~= 996 then
		local d = ent:GetData()
		local rng = ent:GetDropRNG()
		rng = auxi.rng_for_sake(rng)
		local rand = rng:RandomInt(100)		--1/100的概率转化；冠冕不再直接提高敌人琉璃化率
		if rand == 1 then 
			d[item.own_key.."effect"] = {} 
		end
	end
end,
})

return item

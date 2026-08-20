local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	own_key = "Item_grid_trapdoor_",
}

function item.spawn_trapdoor(pos,params)
	local q = auxi.fire_nil(pos or Game():GetRoom():GetCenterPos(),Vector(0,0),{cooldown = 999999,})
	local d2 = q:GetData() local s2 = q:GetSprite() q.DepthOffset = -1000 q.SortingLayer = 0
	d2[item.own_key.."effect"] = {pos = pos,params = params,}
	q:GetData()[Nil_holder.own_key.."work"] = function(ent)
		local d = ent:GetData()
		if d[item.own_key.."effect"] then
			ent.Position = d[item.own_key.."effect"].pos or ent.Position
			if auxi.check_all_exists(d[item.own_key.."effect"].catcher) then else
				local room = Game():GetRoom()
				local gidx = room:GetGridIndex(ent.Position)
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					if room:GetGridIndex(player.Position) == gidx and player:IsExtraAnimationFinished() then	
						d[item.own_key.."effect"].catcher = player
						player:GetData()[item.own_key.."effect"] = {linker = ent,}
					end
				end
			end
		else ent:Remove() return true end
	end
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData() local s = player:GetSprite()
	for i = 1,1 do if d[item.own_key.."effect"] then
		if auxi.check_all_exists(d[item.own_key.."effect"].linker) then
			if player:IsExtraAnimationFinished() then player:PlayExtraAnimation("Trapdoor") end
			if s:IsEventTriggered("Poof") then
				auxi.check_if_any((d[item.own_key.."effect"].linker:GetData()[item.own_key.."effect"] or {}).params,player)
				item.finish_trapdoor(player)
				d[item.own_key.."effect"] = nil 
				break
			end
			player.Position = player.Position * 0.5 + d[item.own_key.."effect"].linker.Position * 0.5
			player.Velocity = Vector(0,0)
			player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
			player:SetMinDamageCooldown(math.max(0,3 - player:GetDamageCooldown()))
			d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] or Attribute_holder.try_hold_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK))
			d[item.own_key.."EntityCollision"] = d[item.own_key.."EntityCollision"] or Attribute_holder.try_hold_attribute(player,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
		else 
			item.finish_trapdoor(player)
			d[item.own_key.."effect"] = nil 
		end
	end end
end,
})

function item.finish_trapdoor(player)
	local d = player:GetData()
	if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] then Attribute_holder.try_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = nil end
	if d[item.own_key.."EntityCollision"] then Attribute_holder.try_rewind_attribute(player,"EntityCollisionClass",d[item.own_key.."EntityCollision"]) d[item.own_key.."EntityCollision"] = nil end
end

return item

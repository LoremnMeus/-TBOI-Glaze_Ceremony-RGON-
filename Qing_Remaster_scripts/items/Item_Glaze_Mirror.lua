local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Glaze_Mirror,
	own_key = "Item_Glaze_Mirror_",
	flash_info = {
		{frame = 0,RO = 0,GO = 0,BO = 0,},
		{frame = 5,RO = 0,GO = 0,BO = 0,},
		{frame = 10,RO = 1,GO = 1,BO = 1,},
		{frame = 14,RO = 0.1,GO = 0.1,BO = 0.1,},
		{frame = 15,RO = 0,GO = 0,BO = 0,},
	},
	flash_info2 = {
		{frame = 0,A = -1,RO = 0,GO = 0,BO = 0,scale = Vector(0,0),},
		{frame = 3,A = 0,RO = 0,GO = 0,BO = 0,scale = Vector(1,0),},
		{frame = 5,A = 0,RO = 1,GO = 1,BO = 1,scale = Vector(1.2,1),},
		{frame = 10,A = 0,RO = 0,GO = 0,BO = 0,scale = Vector(1,1.2),},
		{frame = 12,A = 0,RO = 0,GO = 0,BO = 0,scale = Vector(0,1),},
		{frame = 15,A = -1,RO = 0,GO = 0,BO = 0,scale = Vector(0,0),},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,touched)
	if not touched then
		local room = Game():GetRoom()
		local rng = player:GetCollectibleRNG(item.entity)
		local cnt = 4 + rng:RandomInt(4)
		for i = 1,cnt do
			local info = auxi.random_glaze_pickup({rng = rng,Glaze_heart = 200,Glaze_battery = 1,Glaze_coin = 50,Glaze_chest = 10,})
			local q = Isaac.Spawn(5,info.Variant,info.SubType,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil)
			auxi.special_morph(q,info)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local s = player:GetSprite()
	local d = player:GetData()
	if auxi.has_have_coll(player,item.entity) and Game():GetFrameCount() % 5 == 2 then
		local n_entity = Isaac.GetRoomEntities()
		local n_proj = auxi.getothers(n_entity,9)
		for u,v in pairs(n_proj) do	
			if (v.Position - player.Position):Length() < player.Size + v.Size + 20 and v:GetData()[item.own_key.."effect"] == nil then 
				v:GetData()[item.own_key.."effect"] = {}
				if auxi.check_rand(player.Luck,40,20,3) then
					v:GetData()[item.own_key.."effect"].counter = 15
					local dir = v.Position - player.Position
					v.Velocity = auxi.get_by_rotate(dir:Normalized() * 2 + v.Velocity:Normalized(),auxi.random_2() * 20,v.Velocity:Length())
					local q = auxi.fire_nil(v.Position,Vector(0,0),{cooldown = 15,})
					q.PositionOffset = v.PositionOffset
					auxi.load_item(item.entity,{sprite = q:GetSprite(),})
					q:GetSprite().Rotation = dir:GetAngleDegrees() - 45
					q:GetSprite().Scale = Vector(0,0)
					q:GetData()[Nil_holder.own_key.."work"] = function(ent) 
						local ed = ent:GetData()
						ed[item.own_key.."effect"] = ed[item.own_key.."effect"] or {}
						ed[item.own_key.."effect"].counter = (ed[item.own_key.."effect"].counter or 0) + 1
						local info = auxi.check_lerp(ed[item.own_key.."effect"].counter,item.flash_info2)
						ent:GetSprite().Color = auxi.AddColor(Color(1,1,1,1),auxi.table2color(info),1,1)
						ent:GetSprite().Scale = info.scale * 0.75
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PROJECTILE_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then 
		if (d[item.own_key.."effect"].counter or 0) > 0 then
			d[item.own_key.."effect"].counter = d[item.own_key.."effect"].counter - 1
			local info = auxi.check_lerp(d[item.own_key.."effect"].counter,item.flash_info)
			d[item.own_key.."effect"].color = d[item.own_key.."effect"].color or auxi.color2table(ent:GetSprite().Color)
			ent:GetSprite().Color = auxi.AddColor(auxi.table2color(d[item.own_key.."effect"].color),auxi.table2color(info),1,1)
		end
	end
end,
})

return item
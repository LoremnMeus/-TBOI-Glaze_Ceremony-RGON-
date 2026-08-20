local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	entity = enums.Challenges.Fusion_Destiny,
	own_key = "Challange_Fusion_Destiny_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_INIT, params = nil,
Function = function(_,ent)
	if Game().Challenge == item.entity then
		local d = ent:GetData()
		local s = ent:GetSprite()
		if ent.Type == 8 and ent.Variant == 4 then
			for i = 0,1 do s:ReplaceSpritesheet(i,"gfx/effects/challange_fustion_bagofcrafting.png") end
			s:LoadGraphics()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE, params = nil,
Function = function(_,ent)
	if Game().Challenge == item.entity then
		local d = ent:GetData()
		local s = ent:GetSprite()
		if ent.Type == 8 and ent.Variant == 4 then
			local player = auxi.check_spawner_player(ent)
			if player and s:GetFrame() >= 2 and s:GetFrame() <= 8 then
				local tg_pos = player.Position + auxi.get_by_rotate(Vector(1,0),ent.Rotation,math.max(0,player.TearRange - 260)/100 * 15 + 6 + 30)
				local tg_pos2 = player.Position + auxi.get_by_rotate(Vector(1,0),ent.Rotation,4)
				if (tg_pos2 - ent.Position):Length() < 0.001 then
					local n_enemies = auxi.getenemies(Isaac.FindInRadius(tg_pos,100,1<<3))
					for u,v in pairs(n_enemies) do
						local d2 = v:GetData()
						if (v.Position - tg_pos):Length() < v.Size + 30 and auxi.check_for_the_same(d2[item.own_key.."effect"],ent) ~= true then 
							local rng = v:GetDropRNG()
							local info = auxi.get_random_pickup(rng)
							local q = Isaac.Spawn(5,info.Variant,auxi.check_if_any(info.SubType,info,rng),tg_pos,Vector(0,0),nil):ToPickup()
							q.Visible = false
							local s = q:GetSprite()
							s:SetLastFrame()
							q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL 
							q:Update()
							if v:IsBoss() then
								--v.HitPoints = math.max(0,v.HitPoints - v.MaxHitPoints * 0.05)
								d2[item.own_key.."effect"] = ent
								local rnd = rng:RandomInt(2) + 1
								for i = 1,rnd do
									local info = auxi.get_random_pickup(rng)
									local q = Isaac.Spawn(5,info.Variant,auxi.check_if_any(info.SubType,info,rng),v.Position,auxi.get_by_rotate(Vector(1,0),ent.Rotation,5) + auxi.RoundVector(rng,4),nil):ToPickup()
								end
							else
								v:Remove()
							end
						end
					end
				end
			end
		end
	end
end,
})

return item

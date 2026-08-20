local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	entity = enums.Items.The_Watcher,
	own_key = "Item_The_Watcher_",
	limit = 255,
	limit2 = 55,
	distance = 100,
}
auxi.add_to_seija(item.entity)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_,ent,offset)
	local room = Game():GetRoom()
	local to_player = Game():GetPlayer(0)
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		local d = ent:GetData()
		if d[item.own_key.."shoot"] then
			if d[item.own_key.."shoot"].sprite == nil then 
				d[item.own_key.."shoot"].sprite = Sprite()
				d[item.own_key.."shoot"].sprite:Load("gfx/mimics/The_Watcher/the_watcher.anm2", true)
				d[item.own_key.."shoot"].sprite:Play("Shoot",true)
			end
			local s = d[item.own_key.."shoot"].sprite
			s:SetFrame("Shoot",math.floor(d[item.own_key.."shoot"].frame))
			s:Render(Isaac.WorldToScreen(ent.Position + ent.PositionOffset + Vector(0,-10)) - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
		else
			if d[item.own_key.."sprite"] == nil then
				d[item.own_key.."sprite"] = Sprite()
				d[item.own_key.."sprite"]:Load("gfx/mimics/The_Watcher/the_watcher.anm2", true)
				d[item.own_key.."sprite"]:Play("Idle",true)
			end
			local s = d[item.own_key.."sprite"]
			s:Update()
			local cnt = ((d[item.own_key.."effect"] or {}).counter or 0)
			s.Color = Color(1,1,1,cnt/item.limit2)
			s:Render(Isaac.WorldToScreen(ent.Position + ent.PositionOffset + Vector(0,-10) - ent.Velocity * (3 - cnt/100)) - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		d[item.own_key.."effect"].frame = (d[item.own_key.."effect"].frame or 0) - 1
		if (d[item.own_key.."effect"].counter or 0) > item.limit2 then
			d[item.own_key.."shoot"] = d[item.own_key.."shoot"] or {frame = 0,player = d[item.own_key.."effect"].player or auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0),}
			d[item.own_key.."effect"].counter = -1
		end
		if d[item.own_key.."effect"].frame <= 0 then d[item.own_key.."effect"].counter = math.max(0,(d[item.own_key.."effect"].counter or 0) - 5) end
		if (d[item.own_key.."effect"].counter or 0) < 0 then d[item.own_key.."effect"] = nil end
	end
	if d[item.own_key.."shoot"] then
		d[item.own_key.."effect"] = nil
		d[item.own_key.."shoot"].frame = (d[item.own_key.."shoot"].frame or 0) + 1
		if d[item.own_key.."shoot"].frame == 35 then
			local player = d[item.own_key.."shoot"].player or auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
			Game():BombExplosionEffects(ent.Position,player.Damage * 5,TearFlags.TEAR_NORMAL,Color(1,1,1,1,-1,-1,-1),player,0.5,false,false,0)
		end
		if d[item.own_key.."shoot"].frame >= 70 then d[item.own_key.."shoot"] = nil end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local room = Game():GetRoom()
	if auxi.has_have_coll(player,item.entity) then
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			local d = player:GetData()
			if d[item.own_key.."shoot"] then
				if d[item.own_key.."shoot"].sprite == nil then 
					d[item.own_key.."shoot"].sprite = Sprite()
					d[item.own_key.."shoot"].sprite:Load("gfx/mimics/The_Watcher/the_watcher.anm2", true)
					d[item.own_key.."shoot"].sprite:Play("Shoot",true)
				end
				local s = d[item.own_key.."shoot"].sprite
				s:SetFrame("Shoot",math.floor(d[item.own_key.."shoot"].frame))
				s:Render(Isaac.WorldToScreen(player.Position + player_offset_holder.GetPlayerOffset(player) + Vector(0,-10)) - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
			else
				if d[item.own_key.."sprite"] == nil then
					d[item.own_key.."sprite"] = Sprite()
					d[item.own_key.."sprite"]:Load("gfx/mimics/The_Watcher/the_watcher.anm2", true)
					d[item.own_key.."sprite"]:Play("Idle",true)
				end
				local s = d[item.own_key.."sprite"]
				s:Update()
				s.Color = Color(1,1,1,(d[item.own_key.."counter"] or 0)/item.limit)
				s:Render(Isaac.WorldToScreen(player.Position + player_offset_holder.GetPlayerOffset(player) + Vector(0,-10) - player.Velocity * (6 - (d[item.own_key.."counter"] or 0)/50)) - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) and not Game():IsPaused() then
		if player.MoveSpeed < 1.5 then player.MoveSpeed = 1.5 end		--这个效果类似于石头底座
		local d = player:GetData()
		if player.Velocity:Length() > 4 then d[item.own_key.."counter"] = math.max(0,(d[item.own_key.."counter"] or 0) - 1)
		else d[item.own_key.."counter"] = math.min(item.limit,(d[item.own_key.."counter"] or 0) + 1) end
		if d[item.own_key.."counter"] >= item.limit then
			d[item.own_key.."shoot"] = d[item.own_key.."shoot"] or {frame = 0,}
			d[item.own_key.."counter"] = 0
		end
		if d[item.own_key.."shoot"] then
			d[item.own_key.."shoot"].frame = (d[item.own_key.."shoot"].frame or 0) + 1
			d[item.own_key.."counter"] = 0
			if d[item.own_key.."shoot"].frame == 35 then
				Game():BombExplosionEffects(player.Position,player.Damage * 5,TearFlags.TEAR_NORMAL,Color(1,1,1,1,-1,-1,-1),player,0.5,false,true)
			end
			if d[item.own_key.."shoot"].frame >= 70 then d[item.own_key.."shoot"] = nil end
		end
		local n_enemy = auxi.getenemies()
		for u,v in pairs(n_enemy) do
			local dis = item.distance
			if auxi.should_do_Seija(player,true) then dis = 10000 end
			if (v.Position - player.Position):Length() < dis then
				local d2 = v:GetData()
				d2[item.own_key.."effect"] = d2[item.own_key.."effect"] or {player = player,frame = 5,counter = 0,}
				d2[item.own_key.."effect"].counter = (d2[item.own_key.."effect"].counter or 0) + 1
				d2[item.own_key.."effect"].player = player
				d2[item.own_key.."effect"].frame = 5
			end
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent, amt, flag, source, cooldown)
	if ent:ToPlayer() then
		local player = ent:ToPlayer()
		if amt > 0 and flag & DamageFlag.DAMAGE_EXPLOSION == DamageFlag.DAMAGE_EXPLOSION and auxi.has_have_coll(player,item.entity) then
			if auxi.should_do_Seija(player,true) then return false end
		end
	end
end,
})

return item
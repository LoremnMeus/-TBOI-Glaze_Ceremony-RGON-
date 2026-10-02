local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	enemy = enums.Enemies.chess_board,
	own_key = "enemies_check_board_",
	now_hold = nil,
}

function item.start_(pos)
	if auxi.check_all_exists(item.now_hold) then return item.now_hold
	else 
		local q = Isaac.Spawn(1000,item.enemy,0,pos,Vector(0,0),nil)
		local d = q:GetData() d[item.own_key.."pos"] = pos
		return q
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = item.enemy,
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
		if auxi.check_all_exists(item.now_hold) == true then ent:Remove() return
		else item.now_hold = ent end
		ent.DepthOffset = -1000
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.enemy,
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite() local d = ent:GetData()
		local room = Game():GetRoom()
		local sz = room:GetGridSize()
		d[item.own_key.."find_place"] = d[item.own_key.."find_place"] or {}
		d[item.own_key.."delta"] = d[item.own_key.."delta"] or {}
		for i = 1,sz do 
			if room:GetGridCollision(i) == GridCollisionClass.COLLISION_NONE and room:IsPositionInRoom(room:GetGridPosition(i),0) then
				local delta = 1
				if d[item.own_key.."pos"] then 
					delta = d[item.own_key.."delta"][i] or 100/((room:GetGridPosition(i) - (d[item.own_key.."pos"] or ent.Position)):Length() + 1) + 1
					d[item.own_key.."delta"][i] = delta
				end
				d[item.own_key.."find_place"][i] = math.min(100,(d[item.own_key.."find_place"][i] or 0) + delta)
			else
				d[item.own_key.."find_place"][i] = math.max(0,(d[item.own_key.."find_place"][i] or 0) - 1)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = item.enemy,
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite() local d = ent:GetData()
		local room = Game():GetRoom()
		local sz = room:GetGridSize()
		d[item.own_key.."find_place"] = d[item.own_key.."find_place"] or {}
		if d[item.own_key.."sprite"] == nil then d[item.own_key.."sprite"] = Sprite() d[item.own_key.."sprite"]:Load(s:GetFilename()) end
		for i = 1,sz do 
			local wd_pos = room:GetGridPosition(i)
			if room:IsPositionInRoom(wd_pos,10) then
				local s2 = d[item.own_key.."sprite"]
				local dx = i - (i //2) * 2
				if room:GetRoomShape() >= 6 and (i//28) - (i//28)//2 * 2 == 1 then dx = 1 - dx end
				if dx == 1 then	s2:Play("Idle1") else s2:Play("Idle2") end
				s2:SetFrame(math.floor(d[item.own_key.."find_place"][i] or 0))
				s2:RenderLayer(0,room:WorldToScreenPosition(wd_pos))
			end
		end
	end
end,
})

return item
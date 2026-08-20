local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	ToCall = {},
	own_key = "player_offset_holder_",
	entity = enums.Entities.PlayerNil,
}
--l local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder") player_offset_holder.LoadPlayer(nil,true)
function item.LoadPlayer(player,value)
	player = player or Game():GetPlayer(0)
	local d = player:GetData()
	if value == true then d[item.own_key.."Open"] = d[item.own_key.."Open"] or {}
	else d[item.own_key.."Open"] = nil end
end

function item.GetPlayerOffset(player)
	local d = player:GetData()
	if d[item.own_key.."Open"] then return ui.Screen2ScaleWorld((d[item.own_key.."Open"].Info or {}).Offset or Vector(0,0))
	else return player.PositionOffset end
end

--此处管理的是角色贴图的位置（用于实现角色的Z坐标位移）
function item.TrickOnPlayer(player)
	local d = player:GetData()
	if d[item.own_key.."Open"] then
		if auxi.check_all_exists(d[item.own_key.."effect"]) ~= true then 
			local q = Isaac.Spawn(1000,enums.Entities.PlayerNil,100,player.Position,player.Velocity,player)
			--local q = Isaac.Spawn(5,350,0x8000 + 1,player.Position,player.Velocity,player)
			local s2 = q:GetSprite()
			local d2 = q:GetData()
			d[item.own_key.."effect"] = q
			d2[item.own_key.."effect"] = player
			if player:IsDead() then player.Visible = true		--这里似乎可以用Attribute_holder
			else player.Visible = false end
		else
			d[item.own_key.."effect"].Position = player.Position
			d[item.own_key.."effect"].Velocity = player.Velocity
		end
	else
		if d[item.own_key.."effect"] and player.Visible == false then 
			if auxi.check_all_exists(d[item.own_key.."effect"]) then d[item.own_key.."effect"]:Remove() end
			player.Visible = true 
			d[item.own_key.."effect"] = nil 
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	item.TrickOnPlayer(player)
end,
})

--[[
414 344 14 -28
472 344 -14 -28		+58	-> -28	==> +2 -> -1
652 344 
540	344	-48 -28
540 375 -48 -44		+31 -> -16	==> +2 -> -1

--]]

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = enums.Entities.PlayerNil,
Function = function(_,ent,offset)
	local d = ent:GetData()
	if auxi.check_all_exists(d[item.own_key.."effect"]) then	-- and (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT)
		local player = d[item.own_key.."effect"]
		if player and player:GetData()[item.own_key.."Open"] then
			local ret = callback_manager.work_with_result("POST_CHECK_PLAYER_POSITIONOFFSET",function(funct,params,value) if params == nil or params == player:GetPlayerType() then return funct(nil,player,value) end end,{Offset = Vector(0,0),Remove = true,})
			local posoffset = ret.Offset
			local pos = player.Position + player.PositionOffset
			if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then ---Isaac.WorldToScreen(pos) + Isaac.WorldToRenderPosition(player.Position) + 
				posoffset = auxi.GetWaterRenderOffset() + Vector(posoffset.X,-posoffset.Y) - ((item.render_d2 or Isaac.WorldToScreen(Vector(0,0))) - (item.render_d1 or Isaac.WorldToScreen(Vector(0,0)))) * 0.5
			else posoffset = Isaac.WorldToScreen(pos) - Isaac.WorldToRenderPosition(player.Position) + posoffset - ((item.render_d2 or Isaac.WorldToScreen(Vector(0,0))) - (item.render_d1 or Isaac.WorldToScreen(Vector(0,0)))) * 0.5 end
			player.Visible = true
			if not player:HasEntityFlags(EntityFlag.FLAG_HELD) then 
				player:Render(posoffset) 
			end
			player.Visible = false
			player:GetData()[item.own_key.."Open"].Info = ret
			if ret.Remove then item.LoadPlayer(player,nil) end
		else ent:Remove() return end
	else ent:Remove() return end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_,offset)
	item.render_d2 = item.render_d1 or Isaac.WorldToScreen(Vector(0,0))
	item.render_d1 = Isaac.WorldToScreen(Vector(0,0))
end,
})

return item
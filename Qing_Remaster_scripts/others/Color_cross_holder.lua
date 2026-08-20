local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	ToCall = {},
	own_key = "Color_holder_",
}

function item.try_add_edge_color(ent,col,params)
	params = params or {}
	local d = ent:GetData()
	if auxi.check_all_exists(d[item.own_key.."linker"]) ~= true then 
		local q = auxi.fire_nil(ent.Position,Vector(0,0),{cooldown = 9999999,}) 
		q.DepthOffset = math.min(0,ent.DepthOffset) - 10
		q.SortingLayer = ent.SortingLayer
		local d2 = q:GetData()
		d2.nil_mode = "color_cross"
		d2[item.own_key.."effect"] = {linker = ent,color = col,cnt = params.cnt,work = params.work,}
		d2.follower = ent
		d[item.own_key.."linker"] = q
	else
		local q = d[item.own_key.."linker"] local d2 = q:GetData()
		d2[item.own_key.."effect"].color = col 
	end
	return d[item.own_key.."linker"]
end

Nil_holder.register("color_cross", {
	detect = function(d) return d[item.own_key.."effect"] end,
	update = function(ent, d, s, player)
		if auxi.check_all_exists(d[item.own_key.."effect"].linker) ~= true then ent:Remove() return
		else
			local tg = d[item.own_key.."effect"].linker
			if ent.DepthOffset > tg.DepthOffset then ent.DepthOffset = tg.DepthOffset - 10 end
			ent.SortingLayer = tg.SortingLayer
		end
	end,
	render = function(ent, d, s, player)
		if auxi.check_all_exists(d[item.own_key.."effect"].linker) then
			local tg = d[item.own_key.."effect"].linker
			if tg.Visible then
				local s2 = auxi.copy_sprite(tg:GetSprite())
				if auxi.check_if_any(Nil_holder.Color_remove_overlay[tg.Type],tg) then s2:RemoveOverlay() end
				local alpha = s2.Color.A
				local scale = Vector(s2.Scale.X,s2.Scale.Y)
				local cnt = d[item.own_key.."effect"].cnt or 3
				local rpos = Isaac.WorldToScreen(tg.Position + tg.PositionOffset)
				auxi.check_if_any(d[item.own_key.."effect"].work,ent,tg,rpos)
				for i = 1,cnt do
					s2.Scale = scale * (1.03 + i * 0.01)
					s2.Color = auxi.MulColor(Color(1,1,1,alpha * (cnt - i + 1)/cnt,1,1,1),d[item.own_key.."effect"].color or Color(0,0,0,1,1,1,1))
					s2:Render(rpos,Vector(0,0),Vector(0,0))
				end
				if auxi.check_if_any(Nil_holder.Color_rendertype[tg.Type],tg) then tg:GetSprite():Render(rpos,Vector(0,0),Vector(0,0)) end
			end
		end
	end,
})

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local console_holder = require("Qing_Remaster_scripts.others.Console_holder")

local modReference
local item = {
	ToCall = {},
	challange = enums.Challenges.Cookie_Clicker,
	mouse_lock = false,
	c_s = Sprite(),
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if Game().Challenge == item.challange then
		if Input.IsMouseBtnPressed(0) then
			if item.mouse_lock then
			else
				local room = Game():GetRoom()
				local pos = Input.GetMousePosition(true)
				local player = Game():GetPlayer(0)
				local dmg = player.Damage
				local n_entity = Isaac.GetRoomEntities()
				for u,v in pairs(n_entity) do
					if (v.Position - pos):Length() < 30 then
						if v.Type == 1 then
							v:TakeDamage(1,0,EntityRef(player),0)
						else
							v:TakeDamage(dmg * 0.5,0,EntityRef(player),0)
						end
					end
				end
				local posid = room:GetGridIndex(pos)
				if posid then
					local grid = room:GetGridEntity(posid)
					if grid then
						room:DamageGrid(posid,1)
					end
				end
				item.mouse_lock = true
			end
		else
			item.mouse_lock = false
		end
	end
end,
})

item.c_s:Load("gfx/challenges/Cookie_Clicker/Cookie_clicker_ring.anm2")
item.c_s:Play("Idle",true)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_,name)
	if name == "Qing_HelpfulShader" then
		if Game().Challenge == item.challange then
			if Input.IsMouseBtnPressed(0) then
				item.c_s:Play("Clicked",true)
			else
				item.c_s:Play("Idle",true)
			end
			item.c_s:Render(Isaac.WorldToScreen(Input.GetMousePosition(true)) - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else	
		if Game().Challenge == item.challange then console_holder.try_set_option("MouseControl",true) end
	end

end,
})


return item

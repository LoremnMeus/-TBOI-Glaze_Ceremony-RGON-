local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Illumination,
	own_key = "Item_Illumination_",
	button2dir = {
		[4] = 0,
		[5] = 2,
		[6] = 1,
		[7] = 3,
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	local d = player:GetData()
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d[item.own_key.."effect"] == nil then 
			player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
			d[item.own_key.."effect"] = {slot = activeSlot,}
			return {Discharge = false,}
		else
			d[item.own_key.."effect"] = nil
			player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
			return {Discharge = false,}
		end
	end
	return ret
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local room = Game():GetRoom()
	if d[item.own_key.."effect"] then
		if player:IsHoldingItem() == false then d[item.own_key.."effect"] = nil
		else
			local dir = nil
			local ctrlid = player.ControllerIndex
			for u,i in pairs({4,5,6,7,}) do
				if (Input.IsActionTriggered(i,ctrlid) or Input.IsActionPressed(i,ctrlid)) then
					dir = i
				end
			end
			if dir then
				dir = item.button2dir[dir]
				local slot = d[item.own_key.."effect"].slot or -1
				if player:GetActiveItem(slot) ~= item.entity then slot = auxi.check_slot_with_item(player,item.entity) end
				player:UseActiveItem(item.entity,UseFlag.USE_OWNED,slot)
				player:RemoveCollectible(item.entity)
				local level = Game():GetLevel()
				local sgid = auxi.pos2safegridindex(player.Position)
				local desc = level:GetRoomByIdx(sgid)
				local succ = true
				while succ == true do 
					local ssid = auxi.move_in_gridroom(sgid,dir)
					local desc2 = level:GetRoomByIdx(ssid)
					if ssid == sgid then level:MakeRedRoomDoor(sgid,dir) break
					else
						if desc2 and desc2.Data then
						else 
							local ddir = auxi.sgid_ctrl_dir(sgid,dir)
							if desc and desc.Data and desc.Data.Doors & (1<<ddir) == (1<<ddir) then succ = level:MakeRedRoomDoor(sgid,ddir)
							else succ = false end
						end
					end
					sgid = ssid
					desc = level:GetRoomByIdx(sgid)
				end
			end
		end
	end
end,
})

return item
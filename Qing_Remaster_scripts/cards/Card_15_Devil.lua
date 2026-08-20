local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Devil,
	own_key = "Thoth_cd15_Dev_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
	end
end,
})

function item.transport_to_devil_room(player)
	local desc = Game():GetLevel():GetRoomByIdx(-1) 
	if desc.Data == nil then Game():GetLevel():InitializeDevilAngelRoom(false,true) end
	Room_holder.Trans_to(-1, Direction.NO_DIRECTION, RoomTransitionAnim.TELEPORT, player)
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_PLAYER_KILL, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local cardslot = auxi.has_card(player,item.entity)
	if cardslot or d[item.own_key.."effect"] then
		local ret = {should_revive = true,on_revive = function(player,tp)
			item.transport_to_devil_room(player)
			if cardslot then player:SetCard(cardslot,0) end
			if d[item.own_key.."effect2"] then
				player:AddCard(item.entity)
				d[item.own_key.."effect2"] = nil
			end
			delay_buffer.addeffe(function(params)
				player:AnimateCard(item.entity,"Pickup")
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2)
			end,{},2)
		end,}
		d[item.own_key.."effect"] = nil
		return ret 
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	if d[item.own_key.."sprite"] then
		if Game():GetFrameCount() ~= d[item.own_key.."gameframe"] then
			d[item.own_key.."gameframe"] = Game():GetFrameCount() 
			d[item.own_key.."sprite"]:Update()
			--[[
			if d[item.own_key.."sprite2"] then d[item.own_key.."sprite2"]:Update() end
			if d[item.own_key.."sprite"]:GetFrame() == 3 then 
				d[item.own_key.."sprite2"] = Sprite()
				d[item.own_key.."sprite2"]:Load("gfx/cards/cd15_dev_knife.anm2",true)
				d[item.own_key.."sprite2"]:ReplaceSpritesheet(0,"gfx/effects/cd15_dev_knife2.png")
				d[item.own_key.."sprite2"]:LoadGraphics()
				d[item.own_key.."sprite2"]:Play("Appear",true)
			end
			--]]
			if d[item.own_key.."sprite"]:IsFinished("Appear") then
				d[item.own_key.."sprite"] = nil
				d[item.own_key.."sprite2"] = nil
				player:Kill()
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local d = player:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		if d[item.own_key.."sprite2"] then d[item.own_key.."sprite2"]:Render(Isaac.WorldToScreen(player.Position),Vector(0,0),Vector(0,0)) end
		if d[item.own_key.."sprite"] then d[item.own_key.."sprite"]:Render(Isaac.WorldToScreen(player.Position),Vector(0,0),Vector(0,0)) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then d[item.own_key.."effect2"] = true end
		d[item.own_key.."effect"] = true
		d[item.own_key.."sprite"] = Sprite()
		d[item.own_key.."sprite"]:Load("gfx/cards/cd15_dev_knife.anm2",true)
		d[item.own_key.."sprite"]:Play("Appear",true)
	end
end,
})


return item
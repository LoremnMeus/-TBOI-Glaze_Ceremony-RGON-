local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	should_add_cloth_ = {
	},
}
local s = Sprite()
s:Load("gfx/cards/lootcard_fronts.anm2",true)
s:Play("Idle",true)

function item.should_add_cloth(id)
	if auxi.is_thoth_card(id) then return true end
	if item.should_add_cloth_[id] then return true end
end

function item.render_hud()
	local hud = Game():GetHUD()
	if hud and hud.IsVisible and not hud:IsVisible() then
		return
	end

	local alpha = slot_render_holder.get_alpha()
	s.Scale = Vector(1, 1)
	local game = Game()
	for i = 0, game:GetNumPlayers() - 1 do
		local player = game:GetPlayer(i)
		if player then
			local cardtype = player:GetCard(0)
			if auxi.has_have_coll(player, CollectibleType.COLLECTIBLE_TAROT_CLOTH)
				and cardtype > 0
				and item.should_add_cloth(cardtype) then
				local pos = ui.CardOverlayPos(player, "tarot_cloth")
				if pos then
					s.Color = Color(1, 1, 1, alpha, 0, 0, 0)
					s:Render(pos, Vector(0, 0), Vector(0, 0))
				end
			end
		end
	end
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = nil,	
Function = function(_,cardtype,player,useFlags)
	local d = player:GetData()
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		d.tarot_cloth_used = cardtype
	else
		if d.tarot_cloth_used then d.tarot_cloth_used = nil	end
	end
end,
})

if ModCallbacks.MC_POST_HUD_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_HUD_RENDER,
		params = nil,
		Function = function(_)
			item.render_hud()
		end,
	})
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,	
Function = function(_)
	s:Update()
end,
})



return item
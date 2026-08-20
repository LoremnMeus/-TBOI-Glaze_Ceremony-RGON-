local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Invoker,
	own_key = "Thoth_cd1_Inv_",
	offset_info = {
		[1] = Vector(0,-60),
		[2] = Vector(40,-40),
		[3] = Vector(-40,-40),
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = nil,
Function = function(_,cardtype,player,useFlags)
	if save.elses[item.own_key.."effect"][cardtype] then
		local rng = player:GetCardRNG(item.entity)
		local room = Game():GetRoom()
		local tbl = {}
		local config = Isaac:GetItemConfig()
		for i = 1,save.elses[item.own_key.."effect"][cardtype] do
			local pos = room:FindFreePickupSpawnPosition(player.Position,10,true)
			local id = Game():GetItemPool():GetCard(rng:GetSeed(),false,false,false)
			rng:Next()
			if id then
				local cardinfo = config:GetCard(id)
				local s2 = Sprite()
				if cardinfo.HudAnim == "" then
					s2:Load("gfx/ui/ui_cardspills.anm2",true)
					s2:SetFrame("CardFronts",id)
				else
					s2:Load("gfx/ui/content/ui_cardfronts.anm2",true)
					s2:SetFrame(cardinfo.HudAnim,0)
				end
				local q = auxi.reveal_item2(player,pos,33,{replace_renderer = s2,revealee_end = function(eent,params)
					if player:Exists() then
						if eent:Exists() == false then eent = {Position = Game():GetRoom():FindFreePickupSpawnPosition(player.Position,10,true),} end
						local q2 = Isaac.Spawn(5,300,id,eent.Position,Vector(0,0),nil):ToPickup()
						local e = Isaac.Spawn(1000,EffectVariant.CRACK_THE_SKY,0,q2.Position,Vector(0,0),player):ToEffect()
						e.Parent = player
						e.CollisionDamage = 0
						e:GetSprite().Scale = Vector(1.5,1)
					end
				end})
				local bombinfo = enums.Pickups.Glaze_bomb
				local q3 = Isaac.Spawn(5,bombinfo.Variant,bombinfo.SubType,pos,Vector(0,0),nil)
				table.insert(tbl,#tbl + 1,q3)
			end
		end
		for u,v in pairs(tbl) do v:Remove() end
		local q = Isaac.Spawn(5,300,item.entity,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),nil):ToPickup()
		q:Morph(5,300,item.entity,true,true,true)
		save.elses[item.own_key.."effect"][cardtype] = nil
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
		local cnt = 1
		local config = Isaac:GetItemConfig()
		local tbl = auxi.randomTable(auxi.get_tarot_cards(),rng)
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then cnt = 3 end
		for i = 1,cnt do
			local id = tbl[1]
			local s2 = Sprite()
			local cardinfo = config:GetCard(id)
			if cardinfo.HudAnim == "" then
				s2:Load("gfx/ui/ui_cardspills.anm2",true)
				s2:SetFrame("CardFronts",id)
			else
				s2:Load("gfx/ui/content/ui_cardfronts.anm2",true)
				s2:SetFrame(cardinfo.HudAnim,0)
			end
			auxi.reveal_item(player,player.Position,33,{offset = item.offset_info[i],replace_renderer = s2,})
			save.elses[item.own_key.."effect"][id] = (save.elses[item.own_key.."effect"][id] or 0) + 1
			if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then save.elses[item.own_key.."effect"][id] = (save.elses[item.own_key.."effect"][id] or 0) + 1 end
			table.remove(tbl,1)
		end
	end
end,
})


return item
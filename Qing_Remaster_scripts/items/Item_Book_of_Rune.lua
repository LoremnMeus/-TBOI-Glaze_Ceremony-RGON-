local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Book_of_Rune,
	own_key = "Item_Book_of_Rune_",
	Colorinfo = {
		{frame = 0 * 18,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 18,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 18,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 18,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 18,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 18,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		
		{frame = 6 * 18,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 18,
	},
}
auxi.add_to_seija(item.entity)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local cnt = math.min(3,save.elses[item.own_key.."effect"] or 0)
		local room = Game():GetRoom()
		for i = 1,cnt do 
			local id = Game():GetItemPool():GetCard(rng:GetSeed(),false,true,true)
			rng:Next()
			if auxi.should_do_Seija(player) and rng:RandomFloat() > 0.1 then id = 55 end
			local q = Isaac.Spawn(5,300,id,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
		end
		if cnt > 0 and auxi.should_spawn_wisp(player,useFlags) then
			player:AddWisp(colid,player.Position,true)
		end
		save.elses[item.own_key.."effect"] = nil
	end
	return ret
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = nil,
Function = function(_,card,player,useFlags)
	local rng = player:GetCardRNG(card)
	rng = auxi.rng_for_sake(rng)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	if auxi.has_have_coll(player,item.entity) and useFlags & (UseFlag.USE_OWNED) == UseFlag.USE_OWNED and useFlags & UseFlag.USE_CARBATTERY ~= UseFlag.USE_CARBATTERY then
		local config = Isaac.GetItemConfig()
		local cardinfo = config:GetCard(card)
		if cardinfo.CardType == 2 then 
			save.elses[item.own_key.."effect"] = (save.elses[item.own_key.."effect"] or 0) + 1
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	if auxi.has_have_coll(player,item.entity) then 
		for i = 0,3 do 
			local cid = player:GetCard(i)
			local config = Isaac.GetItemConfig()
			local cardinfo = config:GetCard(cid)
			if cardinfo.CardType == 2 then 
				value[454] = math.max(1,value[454] or 0)
				break
			end
		end
	end
end,
})

local ffont = Font()
ffont:Load("font/luaminioutlined.fnt")

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_,player,tp,cid,slot)
	if cid == item.entity then
		local pos = ui.PlayerActiveUIPos(player,slot,auxi.GetPlayerOrder(player),cid)
		local c = slot_render_holder.get_alpha()
		local col = auxi.MulColor(Color(c,c,c,1,c,c,c),auxi.table2color(auxi.check_lerp(Game():GetFrameCount() % item.Colorinfo.total,item.Colorinfo)))
		local idx = player:GetData().__Index
		local counter = math.min(3,save.elses[item.own_key.."effect"] or 0)
		local str = tostring(counter)
		gui.draw_ch(pos + Vector(-8,-16),str,1,1,auxi.Color_2_KColor(col),true,ffont)
	end
end,
})

return item
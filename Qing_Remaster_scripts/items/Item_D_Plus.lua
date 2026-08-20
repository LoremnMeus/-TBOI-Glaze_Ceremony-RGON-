local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")
local GiantBook_holder = require("Qing_Remaster_scripts.others.GiantBook_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.D_Plus,
	own_key = "Item_D_Plus_",
	Loadinfos = {
		{id = -1,check = function(val) if val < 0 then return true else return false end end,replacename = "gfx/items/collectibles/D_Plus/D-1.png",colid = 723,},
		{id = 4,replacename = "gfx/items/collectibles/D_Plus/D4.png",colid = 284,special = function() GiantBook_holder.PlayGiantBook({Loader = "gfx/ui/giantbook/giantbook.anm2",Anim = "Shake",Init = function(s,info) s:ReplaceSpritesheet(0,"gfx/ui/giantbook/giantbook_rebirth_003_d4.png") s:LoadGraphics() end}) end,},
		{id = 6,replacename = "gfx/items/collectibles/D_Plus/D6.png",colid = 105,},
		{id = 7,replacename = "gfx/items/collectibles/D_Plus/D7.png",colid = 437,},
		{id = 12,replacename = "gfx/items/collectibles/D_Plus/D12.png",colid = 386,special = function() GiantBook_holder.PlayGiantBook({Loader = "gfx/ui/giantbook/giantbook.anm2",Anim = "Shake",Init = function(s,info) s:ReplaceSpritesheet(0,"gfx/ui/giantbook/giantbook_rebirth_013_d12.png") s:LoadGraphics() end}) end,},
		{id = 20,replacename = "gfx/items/collectibles/D_Plus/D20.png",colid = 166,},
		{id = 10,replacename = "gfx/items/collectibles/D_Plus/D10.png",colid = 285,special = function() GiantBook_holder.PlayGiantBook({Loader = "gfx/ui/giantbook/giantbook.anm2",Anim = "Shake",Init = function(s,info) s:ReplaceSpritesheet(0,"gfx/ui/giantbook/giantbook_rebirth_004_d10.png") s:LoadGraphics() end}) end,},
		{id = 8,replacename = "gfx/items/collectibles/D_Plus/D8.png",colid = 406,special = function() GiantBook_holder.PlayGiantBook({Loader = "gfx/ui/giantbook/giantbook.anm2",Anim = "Shake",Init = function(s,info) s:ReplaceSpritesheet(0,"gfx/ui/giantbook/giantbook_rebirth_012_d8.png") s:LoadGraphics() end}) end,},
		{id = 100,replacename = "gfx/items/collectibles/D_Plus/D100.png",colid = 283,special = function() GiantBook_holder.PlayGiantBook({Loader = "gfx/ui/giantbook/giantbook.anm2",Anim = "Shake",Init = function(s,info) s:ReplaceSpritesheet(0,"gfx/ui/giantbook/giantbook_rebirth_006_d100.png") s:LoadGraphics() end}) end,},
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

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	for u,v in pairs(item.Loadinfos) do
		if auxi.check_if_any(v.check or function(val) return val % v.id == 0 end,save.elses[item.own_key.."effect"].id or 1) then
			player:UseActiveItem(v.colid,UseFlag.USE_NOANIM,0)
			auxi.check_if_any(v.special)
		end
	end
	player:UseActiveItem(476,UseFlag.USE_NOANIM,0)
	save.elses[item.own_key.."effect"].id = (save.elses[item.own_key.."effect"].id or 1) + 1
	return ret
end,
})

function item.get_sprites(id)
	local ret = {}
	for u,v in pairs(item.Loadinfos) do
		if auxi.check_if_any(v.check or function(val) return val % v.id == 0 end,id) then
			local s = Sprite()
			s:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2")
			s:Play("Idle",true)
			s:ReplaceSpritesheet(0,v.replacename or "gfx/items/collectibles/collectibles_D_Upper.png")
			s:LoadGraphics()
			table.insert(ret,{s = s,replacename = v.replacename or "gfx/items/collectibles/collectibles_D_Upper.png",})
		end
	end
	return ret
end

local ffont = Font()
ffont:Load("font/luaminioutlined.fnt")

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_,player,tp,cid,slot)
	if cid == item.entity then
		local pos = ui.PlayerActiveUIPos(player,slot,auxi.GetPlayerOrder(player),cid)
		local infos = item.get_sprites(save.elses[item.own_key.."effect"].id or 1)
		local c = slot_render_holder.get_alpha()
		local col = Color(c,c,c,1)
		if auxi.check_can_use(player,slot,cid) then for u,v in pairs(infos) do auxi.render_border(pos,v,{color = col,}) end end
		for u,v in pairs(infos) do
			v.s.Color = col
			v.s:Render(pos,Vector(0,0),Vector(0,0))
		end
		gui.draw_ch(pos + Vector(-16,-16),tostring(save.elses[item.own_key.."effect"].id or 1),1,1,auxi.Color_2_KColor(col),true,ffont)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	if tp == "Item" and id == item.entity then
		value.Name = "D+"..tostring(save.elses[item.own_key.."effect"].id or 1)
		return value
	end
end,
})

return item
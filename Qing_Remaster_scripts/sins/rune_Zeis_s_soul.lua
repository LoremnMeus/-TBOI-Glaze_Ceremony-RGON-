local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
local player_Zeis = require("Qing_Remaster_scripts.player.player_Zeis")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local record_holder = require("Qing_Remaster_scripts.others.Record_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")

local item = {
	entity = enums.Cards.Zeis_s_Soul,
	own_key = "sins_Zeis_s_Soul_",
	myToCall = {},
	ToCall = {},
	dirs = {
		Vector(0,40),
		Vector(0,-40),
		Vector(40,0),
		Vector(-40,0),
	},
	Shift_info = {
		{frame = 0,alpha = 0,},
		{frame = 15,alpha = 1,},
		total = 15,
	},
	color_info = {
		{frame = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 40,A = 0.8,RO = 0.25,GO = 0.25,BO = 0.4,},
		{frame = 80,A = 0.6,RO = -0.3,GO = -0.3,BO = 0.1,},
		{frame = 150,A = 0.25,RO = -0.8,GO = -0.8,BO = 0,},
	},
	Ignorers = {
		[enums.Items.Skiel] = true,
		[enums.Items.Wisel] = true,
		[enums.Items.Granel] = true,
	},
	words = {
		zh = {
			"贪得无厌！", 
		},
		en = {
			"Too greedy to take it！", 
		},
	},
}

function item.check_available(pos)
	local room = Game():GetRoom()
	local tgpos = room:FindFreePickupSpawnPosition(pos,10,true)
	if (tgpos - pos):Length() < 5 then return true end
	return false
end

function item.check_all_available(pos)
	local succ = item.check_available(pos)
	for i = 1,4 do
		if item.check_available(pos + item.dirs[i]) ~= true then return false end
	end
	return succ
end

function item.record_over(ent)
	local id = ent.SubType
	local rd_name = consistance_holder.try_check_entity(ent,item.own_key,true).name
	local st = ent.SubType 
	local vr = ent.Variant
	record_holder.try_hold(ent,{check = function(et) 
		if et.SubType ~= st or et.Variant ~= vr then return true,"Turn" end
	end,Function = function(tp,et)
		if tp == "Turn" then 
			if et:ToPickup().OptionsPickupIndex ~= 0 and not (item.Ignorers[et.SubType] and item.Ignorers[st]) then
				local q = Isaac.Spawn(1000,15,0,et.Position,Vector(0,0),nil) 
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2) 
				if item.display_distance == nil then
					local language = Options.Language
					local wdinfo = item.words[language] or item.words["en"]
					item_displaying_holder.check_and_description("CardDesc",item.entity,wdinfo[1],"",player)
					item.display_distance = true
				end
				et:Remove() 
			end
			if rd_name then consistance_holder.try_remove_entity(ent,item.own_key,{names = {rd_name,},}) end
		end
	end,})
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item.display_distance = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 100,
Function = function(_,ent)
	if ent.FrameCount == 1 then 
		local d = ent:GetData()
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ then 
			d[item.own_key.."effect"] = d._Data[item.own_key][item.own_key.."effect"]
			item.record_over(ent) 
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,card,player,useflags)	
	local tgs = auxi.getothers(5,100)
	local room = Game():GetRoom()
	for u,v in pairs(tgs) do
		if v.SubType ~= 0 and player_Zeis.available(v.SubType) then
			v = v:ToPickup()
			local pos = v.Position
			local config = Isaac:GetItemConfig()
			local ndx = v.OptionsPickupIndex
			if ndx == 0 then ndx = option_index_holder.find_a_new_index() end
			local succ = false
			local jid = v.SubType
			local tbl = {[0] = jid,}
			for k = 1,20 do 
				jid = player_Zeis.prev_item(jid,{no_protect = true,}) 
				tbl[-k] = jid
			end
			jid = v.SubType
			for k = 1,20 do 
				jid = player_Zeis.next_item(jid,{no_protect = true,}) 
				tbl[k] = jid
			end
			for j_ = 0,2 do for _j = -1,1,2 do
				local j = j_ * _j
				for i_ = 0,2 do for _i = -1,1,2 do
					local i = i_ * _i
					local iid = tbl[j * 7 + i]
					local colinfo = config:GetCollectible(iid)
					if colinfo then
						local tgpos = pos + Vector(i,j) * 40
						if item.check_all_available(tgpos) then
							unique_holder.Hold_for_missing(true)
							local q = Isaac.Spawn(5,100,iid,room:FindFreePickupSpawnPosition(tgpos,10,true),Vector(0,0),ent):ToPickup()
							auxi.self_morph(q,{5,100,iid,})
							q.OptionsPickupIndex = ndx
							local d = q:GetData()
							d[item.own_key.."effect"] = {leg = (v.Position - tgpos):Length(),tg = v,price = v.Price,}
							succ = true
							consistance_holder.try_hold_over_entity(q,item.own_key)
							d._Data[item.own_key][item.own_key.."effect"] = q:GetData()[item.own_key.."effect"]
							consistance_holder.try_hold_entity(q,item.own_key)
							item.record_over(q)
							if v.Price ~= 0 then q.Price = v.Price price_holder.catch_price_over(q) end
							unique_holder.Hold_for_missing()
						end
					end
				end end
			end end
			if succ then
				local d = v:GetData()
				d[item.own_key.."effect"] = {}
				v.OptionsPickupIndex = ndx
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = 100,
Function = function(_,ent,val)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local pr = nil
		if d[item.own_key.."effect"].price then pr = d[item.own_key.."effect"].price end 
		if auxi.check_all_exists(d[item.own_key.."effect"].tg) then
			local tg = d[item.own_key.."effect"].tg:ToPickup()
			if tg then pr = tg.Price end
		end
		if pr > 0 then 
			local config = Isaac:GetItemConfig()
			local collectibleinfo = config:GetCollectible(ent.SubType)
			if collectibleinfo then return collectibleinfo.ShopPrice 
			else return 15 end
		elseif pr < 0 then return auxi.get_acceptible_devil_price(ent,val) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 100,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local s = ent:GetSprite()
		if d[item.own_key.."effect"].color == nil then d[item.own_key.."effect"].color = auxi.color2table(s.Color) end
		local color = auxi.table2color(auxi.check_lerp(d[item.own_key.."effect"].leg or 0,item.color_info))
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		if d[item.own_key.."effect"].color and d[item.own_key.."effect"].counter < item.Shift_info.total then
			local r1 = auxi.check_lerp(d[item.own_key.."effect"].counter,item.Shift_info).alpha
			color = auxi.AddColor(color,d[item.own_key.."effect"].color,r1,(1 - r1))
		end
		s.Color = color
	end
end,
})

return item
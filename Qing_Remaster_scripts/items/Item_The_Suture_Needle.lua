local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.The_Suture_Needle,
	entity2 = enums.Items.Fresh_Death,
	own_key = "Item_The_Suture_Needle_",
	banisher = {
		[11] = 12,
		[81] = 82,
		[161] = 162,
		[311] = 118,
		[332] = 331,
		[688] = 689,
		[enums.Items.Fresh_Death] = 1,
	},
}
auxi.add_to_seija(item.entity)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		player:AddBrokenHearts(1)
		if auxi.should_do_Seija(player) then player:AddBrokenHearts(2) end
		player:AddHearts(-99)
		if auxi.get_absolute_heart(player) == 0 then 
			if auxi.is_player_difficult(player) then player:AddHearts(2)
			else player:AddHearts(1) end
		end
		local n_item = auxi.getothers(Isaac.GetRoomEntities(),5,100)
		local tbl = {}
		for u,v in pairs(n_item) do
			local ent = v:ToPickup()
			local id = ent.SubType
			if id ~= 0 then 
				unique_holder.Hold_for_missing(true) 
				ent:Morph(5,100,item.entity2,true,true,true)
				auxi.self_morph(ent,{5,100,item.entity2,})
				local q = auxi.initialize_item(ent)
				q:GetSprite().Color = Color(1,0,0,1)
				unique_holder.Hold_for_missing() 
			end
		end
		unique_holder.try_spawn_shop_item()
	end
	return ret
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	if tp == "Item" and id == item.entity2 then
		local num = player:GetCollectibleNum(item.entity2,true) + 1
		local idx = player:GetData().__Index
		local ret = {Name = "",Description = "",}
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {} 
		save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
		for i = num * 3 - 2,num * 3 do
			local ii = i - num * 3 + 3
			local colid = save.elses[item.own_key.."effect"][idx][i]
			if colid == nil then 
				colid = item.get_random_item(player)
				save.elses[item.own_key.."effect"][idx][i] = colid
			end
			local col = Isaac.GetItemConfig():GetCollectible(colid)
			if col then
				local info = item_displaying_holder.check_description("UnItem",colid,auxi.check_name_data(col.Name),auxi.check_name_data(col.Description),player)
				local tbl = auxi.spilt_string(info.Name)
				ret.Name = ret.Name .. auxi.collect_table_to_string(tbl,math.floor(#tbl * (ii - 1)/3) + 1,math.floor(#tbl * ii/3))
				local tbl = auxi.spilt_string(info.Description)
				ret.Description = ret.Description .. auxi.collect_table_to_string(tbl,math.floor(#tbl * (ii - 1)/3) + 1,math.floor(#tbl * ii/3))
			end
		end
		if ret.Name == "" then ret.Name = value.Name end
		if ret.Description == "" then ret.Description = value.Description end
		return ret
	end
end,
})

function item.get_random_item(player)
	local config = Isaac.GetItemConfig()
	local tbl = {}
	local rng = player:GetCollectibleRNG(item.entity2)
	if auxi.should_do_belial(player) then table.insert(tbl,3) end
	if auxi.should_spawn_wisp(player) then table.insert(tbl,4) end
	local tp = auxi.random_in_table(tbl)
	local colid = auxi.get_item_from_pool(tp,true,rng) rng:Next()
	for j = 1,5 do 
		local colinfo = config:GetCollectible(colid)
		if colinfo.Type ~= ItemType.ITEM_ACTIVE then break end
		colid = auxi.get_item_from_pool(tp,true,rng) rng:Next()
	end
	if item.banisher[colid] then colid = item.banisher[colid] end
	return colid
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity2,
Function = function(_,player,colid,cnt,touched,curNum,known)
	local idx = player:GetData().__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {} 
	save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
	for i = curNum * 3 + 1,curNum * 3 + cnt * 3 do
		local colid = save.elses[item.own_key.."effect"][idx][i]
		if colid == nil then 
			colid = item.get_random_item(player)
			save.elses[item.own_key.."effect"][idx][i] = colid
		end
		auxi.spawn_item_dust(player,player.Position + auxi.get_by_rotate(nil,i * 120/cnt,30 + cnt * 5),colid,Color(1,0,0,1),Color(0,1,1,1))
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_LOSE_COLLECTIBLE, params = item.entity2,
Function = function(_,player,collid,cnt,nownum)
	local idx = player:GetData().__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {} 
	save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
	for i = 1,3 * cnt do
		if #save.elses[item.own_key.."effect"][idx] > 0 then table.remove(save.elses[item.own_key.."effect"][idx],#save.elses[item.own_key.."effect"][idx])
		else break end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	local idx = player:GetData().__Index
	if save.elses[item.own_key.."effect"] and save.elses[item.own_key.."effect"][idx] then
		for u,v in pairs(save.elses[item.own_key.."effect"][idx]) do
			value[v] = (value[v] or 0) + 1
		end
	end
end,
})

do
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	-- 鲜活死者：腐烂绿 Colorize
	item.temp_hud_color = Color(1,1,1,0.55,0,0,0,0.55,1.85,0.45,1)
	temp_hud.register_provider(function(player)
		local idx = player:GetData() and player:GetData().__Index
		if not idx then return end
		local bag = save.elses[item.own_key.."effect"]
		local list = bag and bag[idx]
		if not list then return end
		local counts = {}
		for _,colid in pairs(list) do
			local cid = tonumber(colid)
			if cid and cid > 0 then
				counts[cid] = (counts[cid] or 0) + 1
			end
		end
		return counts
	end,{
		color = item.temp_hud_color,
		exclusive = true,
		source_item = item.entity2,
	})
end

if EID then

EID:addDescriptionModifier("qing_item_sync"..tostring(item.entity), function(desc) return true end, function(desc)
	local id = desc.ObjType
	local vr = desc.ObjVariant
	local st = desc.ObjSubType
	if (id == 5 and vr == 100 and st == item.entity2) then
		local info = ""
		for u,v in pairs(save.elses[item.own_key.."effect"] or {}) do
			for uu,vv in pairs(v) do
				if info ~= "" then info = info .. "、" end
				info = info .. "{{Collectible"..tostring(vv).."}}"
			end
		end
		if info ~= "" then
			info = "已获得道具：" .. info
			EID:appendToDescription(desc,info)
		end
	end
	return desc
end)

end

return item
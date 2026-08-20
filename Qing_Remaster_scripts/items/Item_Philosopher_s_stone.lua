local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Philosopher_s_stone,
	own_key = "Item_Philosopher_s_stone_",
	light_info = {
		{pos = Vector(-10,10),Scale = Vector(0.3,2),Rotation = -45,Color = Color(-1,-1,-1,1),},
		{pos = Vector(-10,-10),Scale = Vector(0.3,2),Rotation = -25,Color = Color(1,1,1,1),},
		{pos = Vector(0,0),Scale = Vector(0.3,2),Rotation = 0,Color = Color(1,1,1,1),},
		{pos = Vector(10,-10),Scale = Vector(0.3,2),Rotation = 25,Color = Color(1,1,0,1),},
		{pos = Vector(10,10),Scale = Vector(0.3,2),Rotation = 45,Color = Color(1,0,0,1),},
	},
	list = {},
	Colorinfo = {
		{frame = 0 * 4,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 4,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 4,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 4,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 4,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 4,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		
		{frame = 6 * 4,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 4,
	},
}
auxi.add_to_seija(item.entity)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local n_item = auxi.getothers(Isaac.GetRoomEntities(),5,100,nil,function(ent) if ent.SubType ~= 0 then return true end end)
		local tg = auxi.get_nearest(n_item)
		if tg then
			local succ = true
			if auxi.should_do_Seija(player) and rng:RandomFloat() > 0.5 then succ = false end
			if succ then
				for u,v in pairs(n_item) do if u ~= tg.tu then v:AddEntityFlags(EntityFlag.FLAG_NO_QUERY) end end
				save.elses[item.own_key.."record"] = tg.tg.SubType
				auxi.self_morph(tg.tg)
				for i = 1,5 do player:UseCard(81,1|(1<<8)) end
				local q = Isaac.Spawn(1000,16,2,tg.tg.Position,Vector(0,0),player)
				for u,v in pairs(item.light_info) do
					local q = Isaac.Spawn(1000,EffectVariant.CRACK_THE_SKY,0,tg.tg.Position + v.pos,Vector(0,0),player):ToEffect()
					local s = q:GetSprite()
					s.Scale = v.Scale
					s.Color = v.Color
					s.Rotation = v.Rotation
					if u == 3 then q:GetData()[item.own_key.."effect"] = {} end
				end
				save.elses[item.own_key.."record"] = nil
				for u,v in pairs(n_item) do v:ClearEntityFlags(EntityFlag.FLAG_NO_QUERY) end
			else
				local room = Game():GetRoom()
				room:SpawnGridEntity(room:GetGridIndex(tg.tg.Position),14,4,tg.tg.InitSeed,0)
				local q = Isaac.Spawn(1000,16,2,tg.tg.Position,Vector(0,0),player)
				for u,v in pairs(item.light_info) do
					local q = Isaac.Spawn(1000,EffectVariant.CRACK_THE_SKY,0,tg.tg.Position + v.pos,Vector(0,0),player):ToEffect()
					local s = q:GetSprite()
					s.Scale = v.Scale
					s.Color = Color(-1,-1,-1,1)
					s.Rotation = v.Rotation
				end
				tg.tg:Remove()
			end
		end
	end
	return ret
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 19,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d[item.own_key.."effect"] then
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		s.Color = auxi.table2color(auxi.check_lerp(d[item.own_key.."effect"].counter % item.Colorinfo.total,item.Colorinfo))
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil,
Function = function(_,pooltp,decrease,seed)
	if save.elses[item.own_key.."record"] then
		save.elses[item.own_key.."record"] = item.get_follow_list(save.elses[item.own_key.."record"])
		return save.elses[item.own_key.."record"]
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 100,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	if player and ent.SubType == 0 and auxi.has_have_coll(player,item.entity) then
		for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do 
			if player:GetActiveItem(slot) == item.entity and auxi.should_real_charge(player,slot) then
				player:SetActiveCharge(player:GetActiveCharge(slot) + player:GetBatteryCharge(slot) + 1,slot)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE,1,1,false,0,2)
				local q = Isaac.Spawn(1000,16,2,ent.Position,Vector(0,0),player)
				q:GetSprite().Color = Color(-1,-1,-1,1)
				ent:Remove()
				break
			end
		end
	end
end,
})

function item.get_follow_list(id)
	if item.list[id] then return item.list[id] end
	local ret = id - 1
	local config = Isaac:GetItemConfig()
	local cnt = 10
	while(ret > 0 and cnt > 0) do
		local col = config:GetCollectible(ret)
		if col and (col.Hidden ~= true) and (col.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST) then
			item.list[id] = ret
			return ret
		end
		ret = ret - 1
		cnt = cnt - 1
	end
	return id
end

if EID then
	EID:addDescriptionModifier("qing_item_sync"..tostring(item.entity), function(desc) if auxi.have_player_has_collectible(item.entity) then return true end end, function(desc)
		if auxi.check_all_exists(desc.Entity) and desc.ObjType == 5 and desc.ObjVariant == 100 then
			local info = "#{{Collectible"..tostring(desc.ObjSubType).."}}"
			local stid = desc.ObjSubType
			for i = 1,5 do stid = item.get_follow_list(stid) info = info .. "->".. "{{Collectible"..tostring(stid).."}}" end
			if info then
				local repl = "#{{Collectible"..tostring(item.entity).."}} "
				info = string.gsub(info, "#", repl)
				EID:appendToDescription(desc, info)
			end
		end
		return desc
	end)
end

return item
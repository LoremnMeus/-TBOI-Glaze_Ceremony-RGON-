local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 
local record_holder = require("Qing_Remaster_scripts.others.Record_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Nihilistic_Artificial_Eye,
	own_key = "Item_NAEye_",
	words = {
		zh = {
			"我看错了吗？", 
		},
		en = {
			"Did I mis-watch?", 
		},
	},
	Ignorers = {
		[enums.Items.Skiel] = true,
		[enums.Items.Wisel] = true,
		[enums.Items.Granel] = true,
	},
}
auxi.add_to_seija(item.entity)

function item.is_option_pending_remove(ent)
	if auxi.check_all_exists(ent) ~= true then return true end
	local pickup = ent:ToPickup()
	if not pickup then return true end
	local d = pickup:GetData()
	return d.OptionsPickupIndex_should_remove == true or d[option_index_holder.own_key.."Remove"] == true or d[option_index_holder.own_key.."Pick"] == true
end

function item.remove_linked_effects(ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		for i = 1,3 do
			local effect = d[item.own_key.."effect"][i]
			if auxi.check_all_exists(effect) then
				effect:Remove()
			end
			d[item.own_key.."effect"][i] = nil
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local mul = player:GetCollectibleNum(item.entity)
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * mul * 0.33
		end
	end
end,
})

function item.record_entity(ent)
	local id = ent.SubType
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
		end
	end,})
end

function item.try_find(ent,id)
	if item.is_option_pending_remove(ent) then return nil end
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	local d = ent:GetData()
	if succ then
		d._Data[item.own_key]["effect"] = d._Data[item.own_key]["effect"] or {}
		local data = ent:GetData()._Data[item.own_key]["effect"]
		if data[id] == "Removed" then return end
		local tgs = auxi.getothers(5,100)
		for u,v in pairs(tgs) do
			if item.is_option_pending_remove(v) then goto continue end
			if data[id] == consistance_holder.get_name(v,{params_name_only = true,})[1] then 
				v = v:ToPickup()
				v.OptionsPickupIndex = ent.OptionsPickupIndex
				local d2 = v:GetData()
				d2[item.own_key.."record"] = {tg = ent,price = ent.Price,}
				if ent.Price ~= 0 then v.Price = ent.Price price_holder.catch_price_over(v) end
				item.record_entity(v)
				return v
			end
			::continue::
		end
	else
		local room = Game():GetRoom()
		consistance_holder.try_hold_over_entity(ent,item.own_key)
		d._Data[item.own_key]["effect"] = {}
		d._Data[item.own_key]["counter"] = d._Data[item.own_key]["counter"] or 0
		local rng = ent:GetDropRNG()
		for i = 1,3 do
			local colid = auxi.get_item_from_pool(nil,true,rng)
			if colid == item.entity and #(auxi.getothers(5,100,item.entity)) > 10 then colid = enums.Items.Hypermnesia end
			unique_holder.Hold_for_missing(true) 
			local q = Isaac.Spawn(5,100,colid,item.get_rotation_pos(ent,i),Vector(0,0),nil):ToPickup()
			auxi.self_morph(q,{5,100,colid,})
			q.OptionsPickupIndex = ent.OptionsPickupIndex
			local d2 = q:GetData()
			d._Data[item.own_key]["effect"][i] = consistance_holder.get_name(q,{params_name_only = true,})[1]
			d[item.own_key.."effect"][i] = q
			item.record_entity(q)
			d2[item.own_key.."record"] = {tg = ent,price = ent.Price,}
			q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
			if ent.Price ~= 0 then q.Price = ent.Price price_holder.catch_price_over(q) end
			unique_holder.Hold_for_missing() 
		end
		consistance_holder.try_hold_entity(ent,item.own_key)
		return d[item.own_key.."effect"][id]
	end
end

function item.get_rotation_pos(ent,id)
	local d = ent:GetData()
	local speed = 5
	if auxi.should_do_Seija_all() then speed = 20 end
	return ent.Position + auxi.get_by_rotate(nil,id * 120 + (d[item.own_key.."effect"].counter or 0) * speed,60)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 100,
Function = function(_,ent)
	local d = ent:GetData()
	if ent.SubType == item.entity then
		if item.is_option_pending_remove(ent) then
			item.remove_linked_effects(ent)
			return
		end
		if ent.OptionsPickupIndex == 0 then 
			local ndx = option_index_holder.find_a_new_index()
			ent.OptionsPickupIndex = ndx
		end
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ then 
			consistance_holder.try_hold_over_entity(ent,item.own_key)
			d[item.own_key.."effect"].counter = (d._Data[item.own_key]["counter"] or 0) + 1
			d._Data[item.own_key]["counter"] = d[item.own_key.."effect"].counter
			consistance_holder.try_hold_entity(ent,item.own_key)
		end
		for i = 1,3 do
			if auxi.check_all_exists(d[item.own_key.."effect"][i]) ~= true then
				d[item.own_key.."effect"][i] = item.try_find(ent,i)
				if auxi.check_all_exists(d[item.own_key.."effect"][i]) ~= true then 
					consistance_holder.try_hold_over_entity(ent,item.own_key)
					d._Data[item.own_key]["effect"] = d._Data[item.own_key]["effect"] or {}
					ent:GetData()._Data[item.own_key]["effect"][i] = "Removed"
					consistance_holder.try_hold_entity(ent,item.own_key)
				end
			end
			if auxi.check_all_exists(d[item.own_key.."effect"][i]) then
				local v = d[item.own_key.."effect"][i]
				local d2 = v:GetData()
				d2[item.own_key.."record"] = d2[item.own_key.."record"] or {}
				d2[item.own_key.."record"].pos = item.get_rotation_pos(ent,i)
			end
		end
		
	end
	if d[item.own_key.."record"] then
		local tg = d[item.own_key.."record"].tg
		if item.is_option_pending_remove(ent) or item.is_option_pending_remove(tg) or (auxi.check_all_exists(tg) and tg.SubType ~= item.entity) then
			Isaac.Spawn(1000,15,0,ent.Position,Vector(0,0),nil)
			ent:Remove()
			return
		end
		local tgpos = d[item.own_key.."record"].pos
		if tgpos then 
			ent.TargetPosition = tgpos
			ent.Position = tgpos
			ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYERONLY
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = 100,
Function = function(_,ent,val)
	local d = ent:GetData()
	if d[item.own_key.."record"] then
		local pr = nil
		if d[item.own_key.."record"].price then pr = d[item.own_key.."record"].price end 
		if auxi.check_all_exists(d[item.own_key.."record"].tg) then
			local tg = d[item.own_key.."record"].tg:ToPickup()
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

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,colid,cnt,touched)
	if touched ~= true then
		save.elses[item.own_key.."effect"] = (save.elses[item.own_key.."effect"] or 0) + 2
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil,
Function = function(_,pool,decrease,seed)
	if (save.elses[item.own_key.."effect"] or 0) > 0 and Game():GetFrameCount() > 5 then
		local rng = RNG()
		rng:SetSeed(seed,0)
		rng = auxi.rng_for_sake(rng)
		local rnd = rng:RandomInt(10)
		if rnd == 1 then
			if decrease == true then save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] - 1 end
			return item.entity
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GET_COLLECTIBLE_FROM_POOL, params = nil,
Function = function(_,colid,pool,decrease,seed)
	if (save.elses[item.own_key.."effect"] or 0) > 0 and Game():GetFrameCount() > 5 then
		local rng = RNG()
		rng:SetSeed(seed,0)
		rng = auxi.rng_for_sake(rng)
		local rnd = rng:RandomInt(10)
		if rnd == 1 then
			if decrease == true then save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] - 1 end
			return item.entity
		end
	end
end,
})

return item

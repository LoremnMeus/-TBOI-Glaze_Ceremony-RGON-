local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local record_holder = require("Qing_Remaster_scripts.others.Record_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Lover_r,
	own_key = "Thoth_cd6r_Lov_",
	own_key2 = "Thoth_cd6r_Lov2_",
	pools = {[0] = {},[1] = {},[2] = {},[3] = {},[4] = {},},
	words = {
		zh = {
			[1] = {
				"你背叛了我！", 
				"你背叛了我，混蛋！",
				"背叛我之人需要惩罚！",
				"你破坏了我们的爱！",
				"你不爱我！",
				"我不允许三心二意！",
				"你不爱我，混蛋！",
				"我恨不忠者！",
				"我才是你唯一的爱人！",
				suffix = "的妒火",
			},
			[2] = {
				"你利用了我！", 
				"你居然利用我们！", 
				"我们难道不值得珍惜吗！", 
				"利用他人就要付出代价！",  
				suffix = "的怒火",
			},
			[3] = {
				"我是你唯一的爱人啊！", 
				"你可不要三心二意哦！", 
				"其他道具们可以滚了！", 
				"我是你的唯一！",  
				suffix = "的爱意",
				suffix2 = "受到排挤！",
			},
		},
		en = {
			[1] = {
				"You betrayed my love!",
				"Damn, You betrayed me!",
				"Those who betray me will be punished!",
				"You have destroyed our love!",
				"You don't love me!",
				"I don't allow half hearted!",
				"Damn it, You don't love me!",
				"I hate disloyal people!",
				"I'm your only lover!",
				suffix = "'s envy",
			},		
			[2] = {
				"You exploited me!",
				"How dare you exploit us!",
				"Aren't we worth cherishing?",
				"Taking advantage of others will cost yourself!",
				suffix = "'s warth",
			},
			[3] = {
				"I am your only lover!",
				"Don't be half hearted!",
				"Other items can go away!",
				"My lover!",
				suffix = "'s love",
				suffix2 = "is excluded！",
			},
		},
	},
}

function item.remake_pool()
	item.pools = {[0] = {},[1] = {},[2] = {},[3] = {},[4] = {},[5] = {},}
	local itemConfig = Isaac.GetItemConfig()
	local sz = itemConfig:GetCollectibles().Size
	for id = 1,sz do
		local collectible = itemConfig:GetCollectible(id)
		if (collectible and not collectible.Hidden and not collectible:HasTags(1<<15) and collectible.Type ~= ItemType.ITEM_ACTIVE) then
			local qual = collectible.Quality
			table.insert(item.pools[qual],#item.pools[qual] + 1,id)
		end
	end
	for i = 0,4 do if save.elses[item.own_key.."pool"][i] then item.pools[i] = {save.elses[item.own_key.."pool"][i],} end end
end

function item.get_pool(id)
	item.remake_pool()
	return item.pools[id]
end

function item.check_pool(player)
	player = player or Game():GetPlayer(0)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."love"][idx] = save.elses[item.own_key.."love"][idx] or {}
	save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
	if #save.elses[item.own_key.."love"][idx] == 0 then
		if auxi.check_table_not_empty(save.elses[item.own_key.."effect"][idx]) then
			local itemConfig = Isaac.GetItemConfig()
			local sz = itemConfig:GetCollectibles().Size
			for id = 1,sz do
				local collectible = itemConfig:GetCollectible(id)
				if (collectible and not collectible.Hidden and not collectible:HasTags(1<<15) and collectible.Type ~= ItemType.ITEM_ACTIVE) and player:HasCollectible(id,true) then
					local qual = collectible.Quality
					if save.elses[item.own_key.."effect"][idx][qual] and id ~= save.elses[item.own_key.."effect"][idx][qual] then
						table.insert(save.elses[item.own_key.."love"][idx],#save.elses[item.own_key.."love"][idx] + 1,{id = save.elses[item.own_key.."effect"][idx][qual],id2 = id,wdid = 3,})
						break
					end
				end
			end
		end
	end
end

function item.record_over(ent,player)
	local id = ent.SubType
	local rd_name = consistance_holder.try_check_entity(ent,item.own_key,true).name
	record_holder.try_hold(ent,{check = function(et) 
		if et.SubType ~= id then
			if et.SubType == 0 then
				return true,"Lost"
			else
				return true,"Turn"
			end
		end
		return false,nil
	end,Function = function(tp,et)
		local should_blame = false
		if tp == "Turn" then			
			should_blame = true
		elseif tp == "Lost" then		--变化的场合，必然生效
			local succ = consistance_holder.try_check_entity(et,item.own_key2,nil,{record_subtype = id,})
			if succ then
			else
				should_blame = true
			end
		end
		if should_blame then
			player = auxi.check_on_all_exists(player) or Game():GetPlayer(0)
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."blame"][idx] = save.elses[item.own_key.."blame"][idx] or {}
			table.insert(save.elses[item.own_key.."blame"][idx],#save.elses[item.own_key.."blame"][idx] + 1,{id = id,wdid = 2,})
			if rd_name then 
				consistance_holder.try_remove_entity(ent,item.own_key,{names = {rd_name,},}) 
			end
		end
	end,})
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."pool"] = {}
		save.elses[item.own_key.."blame"] = {}
		save.elses[item.own_key.."love"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."pool"] = save.elses[item.own_key.."pool"] or {}
	save.elses[item.own_key.."blame"] = save.elses[item.own_key.."blame"] or {}
	save.elses[item.own_key.."love"] = save.elses[item.own_key.."love"] or {}
	item.remake_pool()
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_ALL_COLLECTIBLE, params = nil,
Function = function(_,player)
	item.check_pool(player)
end,
})

function item.try_take_on_lover(player,ent)
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ then
		local d = player:GetData()
		local idx = d.__Index
		local d2 = ent:GetData()
		local qual = d2._Data[item.own_key].qual or 0
		save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
		save.elses[item.own_key.."blame"][idx] = save.elses[item.own_key.."blame"][idx] or {}
		for i = 0,4 do
			if save.elses[item.own_key.."effect"][idx][i] and (i ~= qual or save.elses[item.own_key.."effect"][idx][i] ~= ent.SubType) then 
				table.insert(save.elses[item.own_key.."blame"][idx],#save.elses[item.own_key.."blame"][idx] + 1,{id = save.elses[item.own_key.."effect"][idx][i],wdid = 1,})
			end
		end
		save.elses[item.own_key.."effect"][idx][qual] = ent.SubType
		save.elses[item.own_key.."pool"][qual] = ent.SubType
		item.remake_pool()
		item.check_pool(player)
		consistance_holder.try_remove_entity(ent,item.own_key)
		consistance_holder.try_hold_entity(ent,item.own_key2)
		local n_entity = Isaac.GetRoomEntities()
		for u,v in pairs(n_entity) do 
			if v:ToPickup() and v.Variant == 100 then
				if v:ToPickup().OptionsPickupIndex == ent.OptionsPickupIndex then
					consistance_holder.try_remove_entity(v,item.own_key)
				end
			end 
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 100,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	if player and auxi.will_pick_up(player,ent) then
		item.try_take_on_lover(player,ent)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."blame"][idx] = save.elses[item.own_key.."blame"][idx] or {}
	if #save.elses[item.own_key.."blame"][idx] > 0 then
		if player:IsExtraAnimationFinished() then
			local rng = player:GetCardRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			player:AnimateSad()
			player:AddBrokenHearts(1)
			local iifo = save.elses[item.own_key.."blame"][idx][1]
			local colid = iifo.id
			local col = Isaac.GetItemConfig():GetCollectible(colid)
			if col then
				local info = item_displaying_holder.check_description("UnItem",colid,auxi.check_name_data(col.Name),auxi.check_name_data(col.Description),player)
				local language = Options.Language
				local wdinfo = item.words[language] or item.words["en"]
				local desc = auxi.random_in_table(wdinfo[iifo.wdid or 1],rng)
				item_displaying_holder.check_and_description("CardDesc",item.entity,info.Name..wdinfo[iifo.wdid or 1].suffix,desc,player)
			end
			table.remove(save.elses[item.own_key.."blame"][idx],1)
		end
	end
	save.elses[item.own_key.."love"][idx] = save.elses[item.own_key.."love"][idx] or {}
	if #save.elses[item.own_key.."love"][idx] > 0 then
		if player:IsExtraAnimationFinished() then
			local rng = player:GetCardRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			local iifo = save.elses[item.own_key.."love"][idx][1]
			local colid = iifo.id
			local colid2 = iifo.id2
			local col = Isaac.GetItemConfig():GetCollectible(colid)
			local col2 = Isaac.GetItemConfig():GetCollectible(colid2)
			if col and col2 and player:GetCollectibleNum(colid2,true) > 0 then
				player:AnimateCollectible(colid2,"LiftItem","PlayerPickup")
				sound_tracker.PlayStackedSound(285,1,1,false,0,2)
				local info = item_displaying_holder.check_description("UnItem",colid,auxi.check_name_data(col.Name),auxi.check_name_data(col.Description),player)
				local info2 = item_displaying_holder.check_description("UnItem",colid2,auxi.check_name_data(col2.Name),auxi.check_name_data(col2.Description),player)
				local language = Options.Language
				local wdinfo = item.words[language] or item.words["en"]
				local desc = auxi.random_in_table(wdinfo[iifo.wdid or 3],rng)
				item_displaying_holder.check_and_description("CardDesc",item.entity,info.Name..wdinfo[iifo.wdid or 3].suffix,desc,player)
				delay_buffer.addeffe(function(params)
					player:AnimateCollectible(colid2,"HideItem","PlayerPickup")
					local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player)
					local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),player)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
					local cnt = player:GetCollectibleNum(colid2,true)
					for i = 1,cnt do
						player:RemoveCollectible(colid2)
						local q = player:AddItemWisp(colid2,player.Position,true)
					end
					item_displaying_holder.check_and_description("CardDesc",item.entity,info2.Name..wdinfo[iifo.wdid or 3].suffix2,nil,player)
				end,{},15)
			end
			table.remove(save.elses[item.own_key.."love"][idx],1)
			item.check_pool(player)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 100,
Function = function(_,ent)
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ then item.record_over(ent) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = nil,
Function = function(_,ent)
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ then
		if Game():GetRoom():GetFrameCount() ~= 0 then
			delay_buffer.addeffe(function(params)
				local player = Game():GetPlayer(0)
				local d = player:GetData()
				local idx = d.__Index
				save.elses[item.own_key.."blame"][idx] = save.elses[item.own_key.."blame"][idx] or {}
				table.insert(save.elses[item.own_key.."blame"][idx],#save.elses[item.own_key.."blame"][idx] + 1,{id = ent.SubType,wdid = 2,})
			end,{},1)
			consistance_holder.try_remove_entity(ent,item.own_key)
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil,
Function = function(_,pool,decrease,seed)
	if item.should_trigger == nil and Game():GetFrameCount() > 2 and auxi.HasTable(save.elses[item.own_key.."pool"]) then
		item.should_trigger = true
		local colid = Game():GetItemPool():GetCollectible(pool,false,seed)
		local collectible = Isaac.GetItemConfig():GetCollectible(colid)
		if collectible and save.elses[item.own_key.."pool"][collectible.Quality] then 
			item.should_trigger = nil
			return save.elses[item.own_key.."pool"][collectible.Quality] 
		end
		item.should_trigger = nil
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
		local mul = 1
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then mul = 2 end
		local copy_pool = auxi.deepCopy(item.pools)
		local ndx = option_index_holder.find_a_new_index()
		for i = 1,mul do
			for j = 0,4 do 
				local id = auxi.random_on_table(1,#copy_pool[j],rng)
				local colid = copy_pool[j][id]
				if colid then
					if #copy_pool[j] > 1 then table.remove(copy_pool[j],id) end
					unique_holder.Hold_for_missing(true)
					local q = Isaac.Spawn(5,100,colid,room:FindFreePickupSpawnPosition(player.Position + i * Vector(0,40) + (j - 2) * Vector(40,0),10,true),Vector(0,0),ent):ToPickup()
					auxi.self_morph(q,{5,100,colid,})
					unique_holder.Hold_for_missing()
					q.OptionsPickupIndex = ndx
					local d2 = q:GetData()
					consistance_holder.try_hold_over_entity(q,item.own_key)
					d2._Data[item.own_key].qual = j
					consistance_holder.try_hold_entity(q,item.own_key)
					item.record_over(q,player)
				end
			end
		end
	end
end,
})

return item
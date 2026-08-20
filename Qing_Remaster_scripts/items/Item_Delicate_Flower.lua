local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local card_01_wizard = require("Qing_Remaster_scripts.cards.Card_01_Wizard")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local Item_Disequilibrium = require("Qing_Remaster_scripts.items.Item_Disequilibrium")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Delicate_Flower,
	own_key = "Item_Delicate_Flower_",
	costumes = enums.Costumes.Delicate_Flower_Head,
	Name_info = {
		["zh"] = {
			[1] = "撒旦先生",
			[2] = "天使小姐",
			[3] = "店长",
		},
		["en"] = {
			[1] = "Mr. Satan",
			[2] = "Miss Angel",
			[3] = "Keeper",
		},
	},
	Desc_info = {
		["zh"] = {
			[1] = {Desc = "赠送给撒旦先生：#降价房间中所有恶魔交易道具#撒旦先生赠送出若干红箱子",},
			[2] = {Desc = "赠送给天使小姐：#下层天使房转化率提高50%#天使小姐赠送出若干白箱子",},
			[3] = {Desc = "赠送给店长：#送出数个福袋",},
			[4] = {Desc = "赠送给上吊店长：#开启一道随机特殊房间传送门",},
			[5] = {Desc = "赠送给错误店长：#生成随机一个错误道具",},
			[13] = {Desc = "赠送给商店店长：#生成一台补货机",},
			[14] = {Desc = "赠送给商店上吊店长：#稍微降价房间中的交易道具",},
			[23] = {Desc = "赠送给隐藏店长：#生成一个随机道具",},
			[24] = {Desc = "赠送给隐藏上吊店长：#送出数张卡牌",},
		},
		["en"] = {
			[1] = {Desc = "Presented to Mr. Satan:#Reduce all price in the room#Give you several red chests",},
			[2] = {Desc = "Presented to Miss Angel:#Increase conversion rate of the angel room of next level by 50%#Give you several white chests",},
			[3] = {Desc = "Presented to Mr. Keeper:#Give you several grabbags.",},
			[4] = {Desc = "Presented to Mr. Keeper:#Open a teleport portal to random room",},
			[5] = {Desc = "Presented to Error Keeper:#Give you an error item",},
			[13] = {Desc = "Presented to Mr. Keeper:#Spawn a restock machine",},
			[14] = {Desc = "Presented to Mr. Keeper:#Reduce all price in the room",},
			[23] = {Desc = "Presented to Mr. Keeper:#Spawn a random item",},
			[24] = {Desc = "Presented to Mr. Keeper:#Give you several cards",},
		},
	},
	Thanks_info = {
		["zh"] = {
			[1] = {
				{Desc = "谢谢你的小花！",},
				{Desc = "以后要常来啊！",},
				{Desc = "谢谢，我很喜欢！",},
				{Desc = "谢谢！",},
				{Desc = "好久没人送花给我了呢！",},
			},
			[2] = {
				[1] = "撒旦先生的祝福",
				[2] = "天使小姐的祝福",
				[3] = "店长的祝福",
			},
		},
		["en"] = {
			[1] = {
				{Desc = "Thank you for your flower!",},
				{Desc = "Come often in the future!",},
				{Desc = "Thank you, I like it very much!",},
				{Desc = "Thanks!",},
				{Desc = "No one has sent me flowers for a long time!",},
			},
			[2] = {
				[1] = "Satan's Blessing",
				[2] = "Angel's Blessing",
				[3] = "Keeper's Blessing",
			},
		},
	},
	accepts = {
		[17] = function(ent)
			local s = ent:GetSprite()
			local iid = 0
			if Game():GetRoom():GetType() == RoomType.ROOM_SHOP then iid = iid + 10 end
			if Game():GetRoom():GetType() == RoomType.ROOM_SECRET or Game():GetRoom():GetType() == ROOM_SUPERSECRET then iid = iid + 20 end
			if ent.Variant == 0 and s:GetAnimation() ~= "Shopkeeper 9" then return {id = 3 + iid,Auto = "gfx/mimics/Delicate_Flower/k1.png",} end
			if ent.Variant == 1 and s:GetAnimation() ~= "Guy7" then return {id = 4 + iid,Auto = "gfx/mimics/Delicate_Flower/k2.png",} end
			if ent.Variant == 2 then return {id = 5,loader = "gfx/mimics/Delicate_Flower/017.003_errorkeeper.anm2",Anim = "Happy",} end
			if ent.Variant == 3 then return {id = 3 + iid,Auto = "gfx/mimics/Delicate_Flower/k3.png",} end
			if ent.Variant == 4 and s:GetAnimation() ~= "Guy7" then return {id = 4 + iid,Auto = "gfx/mimics/Delicate_Flower/k4.png",} end
		end,
		[1000] = function(ent)
			if ent.Variant == EffectVariant.DEVIL then 
				local ret = {id = 1,loader = "gfx/mimics/Delicate_Flower/084.000_satan.anm2",Anim = "Happy",}
				if ent:GetData()[Item_Disequilibrium.own_key.."equal"] then ret.Replace = "gfx/mimics/Delicate_Flower/devilangel.png" end
				return ret
			end
			if ent.Variant == EffectVariant.ANGEL then 
				local ret = {id = 2,loader = "gfx/mimics/Delicate_Flower/1000.009_angelstatue.anm2",Anim = "Happy",}
				if ent:GetData()[Item_Disequilibrium.own_key.."equal"] then ret.Replace = "gfx/mimics/Delicate_Flower/angeldevil.png" end
				return ret
			end
		end,
	},
	frame_info = {
		{frame = 0,scale = Vector(1,1),},
		{frame = 4,scale = Vector(1.12,0.88),},
		{frame = 6,scale = Vector(0.82,1.18),},
		{frame = 8,scale = Vector(0.82,1.18),},
		{frame = 10,scale = Vector(1,1),},
		{frame = 27,scale = Vector(1.12,0.88),},
		{frame = 29,scale = Vector(0.82,1.18),},
		{frame = 31,scale = Vector(1,1),},
		{frame = 32,scale = Vector(1,1),},
	},
	Swap_info = {
		[8] = 1,
		[27] = 2,
	},
	Bonuses = {
		[1] = function(ent,item)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_GROW,1,1,false,0,2)
			local rng = ent:GetDropRNG()
			local rnd = rng:RandomInt(5) + 3
			for i = 1,rnd do
				local q = Isaac.Spawn(5,360,0,ent.Position,auxi.MakeVector(30 + (i - 0.5)/rnd * 120) * 10,nil)
			end
			local n_entity = Isaac.GetRoomEntities()
			for u,v in pairs(n_entity) do
				if v:ToPickup() then
					v = v:ToPickup()
					if v.Price ~= 0 then 
						price_holder.catch_price_over(v)
						consistance_holder.try_hold_entity(v,item.own_key) 
					end
				end
			end
		end,
		[2] = function(ent,item)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,1,1,false,0,2)
			save.elses[item.own_key.."Angel"] = true
			local rng = ent:GetDropRNG()
			local rnd = rng:RandomInt(4) + 3
			for i = 1,rnd do
				local q = Isaac.Spawn(5,53,0,ent.Position,auxi.MakeVector(30 + (i - 0.5)/rnd * 120) * 10,nil)
			end
		end,
		[3] = function(ent,item)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,1,1,false,0,2)
			local rng = ent:GetDropRNG()
			local rnd = rng:RandomInt(3) + 2
			for i = 1,rnd do
				local q = Isaac.Spawn(5,69,0,ent.Position,auxi.MakeVector(30 + (i - 0.5)/rnd * 120) * 5,nil)
			end
		end,
		[4] = function(ent,item)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,1,1,false,0,2)
			local level = Game():GetLevel()
			local rooms = level:GetRooms()
			local rng = ent:GetDropRNG()
			local dimen = auxi.GetDimension()
			local tbl = {}
			for i = 1, rooms.Size do
				local targ = rooms:Get(i - 1)
				if targ and dimen == auxi.GetDimension(targ) then
					local desc = level:GetRoomByIdx(targ.SafeGridIndex)
					if desc and desc.SafeGridIndex ~= Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex then
						local tp = desc.Data.Type
						if tp ~= RoomType.ROOM_DEFAULT then table.insert(tbl,#tbl + 1,{id = i,tp = tp,gidx = targ.SafeGridIndex,}) end
					end
				end
			end
			local info = auxi.random_in_table(tbl,rng)
			if info then card_01_wizard.spawn_a_fool_port(Game():GetRoom():FindFreePickupSpawnPosition(ent.Position + Vector(0,40)),{info = info,}) end
		end,
		[5] = function(ent,item)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,1,1,false,0,2)
			local adder = false
			local player = Game():GetPlayer(0)
			if auxi.have_player_has_collectible(CollectibleType.COLLECTIBLE_TMTRAINER) then
			else
				adder = true 
				Imitate_item_holder.assign_fake_item(player,CollectibleType.COLLECTIBLE_TMTRAINER,true)
			end
			local q = Isaac.Spawn(5,100,0,Game():GetRoom():FindFreePickupSpawnPosition(ent.Position + Vector(0,40)),Vector(0,0),nil)
			if adder then Imitate_item_holder.re_assign_fake_item() end
		end,
		[13] = function(ent,item)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,1,1,false,0,2)
			Isaac.Spawn(6,10,0,Game():GetRoom():FindFreeTilePosition(ent.Position + Vector(0,40),10),Vector(0,0),nil)
		end,
		[14] = function(ent,item)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,1,1,false,0,2)
			local n_entity = Isaac.GetRoomEntities()
			for u,v in pairs(n_entity) do
				if v:ToPickup() then
					v = v:ToPickup()
					if v.Price ~= 0 then 
						price_holder.catch_price_over(v)
						consistance_holder.try_hold_entity(v,item.own_key) 
					end
				end
			end
		end,
		[23] = function(ent,item)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,1,1,false,0,2)
			Isaac.Spawn(5,100,0,Game():GetRoom():FindFreePickupSpawnPosition(ent.Position + Vector(0,40)),Vector(0,0),nil)
		end,
		[24] = function(ent,item)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,1,1,false,0,2)
			local rng = ent:GetDropRNG()
			local rnd = rng:RandomInt(3) + 3
			for i = 1,rnd do
				local q = Isaac.Spawn(5,300,0,ent.Position,auxi.MakeVector(30 + (i - 0.5)/rnd * 120) * 5,nil)
			end
		end,
	},
	Price_down = {
		[-1] = -7,
		[-2] = -1,
		[-3] = -8,
		[-4] = -9,
		[-5] = -1000,
		[-7] = -5,
		[-8] = -7,
		[-9] = -8,
	},
	list = {},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local d = ent:GetData()
	if consistance_holder.try_check_entity(ent,item.own_key) then 
		if val > 0 then return math.ceil(val * 0.7) end
		return item.Price_down[val] 
	end
end,
})

function item.find_target(player,range)
	item.list = item.list or {}
	for u,v in pairs(item.list) do
		if auxi.check_all_exists(v) and (v.Position - player.Position):Length() < (range or 60) and auxi.check_for_the_same(v,player) ~= true then
			local succ = auxi.check_if_any(item.accepts[v.Type],v)
			if succ and consistance_holder.try_check_entity(v,item.own_key) ~= true then return {info = succ,ent = v,} end
		end
	end
	for i = #item.list,1,-1 do
		if auxi.check_all_exists(item.list[i]) ~= true then table.remove(item.list,i) end
	end
end

function item.Bonus(id,ent)
	id = id or 1
	if not ent then return end
	auxi.check_if_any(item.Bonuses[id],ent,item)
	local language = Options.Language
	if item.Thanks_info[language] == nil then language = "en" end
	local name = item.Thanks_info[language][2][id] or item.Thanks_info[language][2][3]
	local desc = auxi.random_in_table(item.Thanks_info[language][1])
	item_displaying_holder.check_and_description("ItemDesc",item.entity,name,desc.Desc,Game():GetPlayer(0))
end

function item.PlayHappy(ent,info)
	local s = ent:GetSprite()
	local d = ent:GetData()
	if info.Auto then
		d[item.own_key.."Autoeffect"] = info.Auto
	else
		d[item.own_key.."Filename"] = s:GetFilename()
		d[item.own_key.."Anim"] = s:GetAnimation()
		s:Load(info.loader,true)
		if info.Replace then s:ReplaceSpritesheet(0,info.Replace) s:LoadGraphics() end
		s:Play(info.Anim or "Happy",true)
	end
	d[item.own_key.."effect"] = true
	d[item.own_key.."id"] = info.id
end

function item.can_send()
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local idx = player:GetData().__Index
		if (save.elses[item.own_key.."effect"][idx] or 0) > 0 then return true end
	end
	return false
end

function item.Update_effect(ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	if item.can_send() and d[item.own_key.."EID_des"] ~= true then 
		local succ = auxi.check_if_any(item.accepts[ent.Type],ent)
		if succ then
			local d2 = d
			if ent.Type == 1000 then
				local q = Isaac.Spawn(1000,enums.Entities.EID_Descriptier,0,ent.Position,Vector(0,0),nil)
				d2 = q:GetData()
				q.Parent = ent
			end
			local language = Options.Language
			local name = item.Name_info[language][succ.id] or item.Name_info[language][3]
			d2.EID_Description = d2.EID_Description or {Name = name,Description = "",}
			d2[item.own_key.."EID_des"] = true
			if item.Desc_info[language] == nil then language = "en" end
			local repl = "#{{Collectible"..tostring(item.entity).."}} "
			local info = item.Desc_info[language][succ.id].Desc
			d2.EID_Description.Description = d2.EID_Description.Description .. repl..string.gsub(info, "#", repl) 
			table.insert(item.list,#item.list + 1,ent)
		end
	end
	if d[item.own_key.."effect"] then
		if d[item.own_key.."Finish"] then return end
		if d[item.own_key.."Autoeffect"] then
			d[item.own_key.."Frame"] = (d[item.own_key.."Frame"] or 0) + 1
			local frinfo = auxi.check_lerp(d[item.own_key.."Frame"],item.frame_info)
			delay_buffer.addeffe(function(params) s.Scale = frinfo.scale end,{},1)
			local spid = auxi.check_if_any(item.Swap_info[d[item.own_key.."Frame"]])
			if spid == 1 then 
				s:ReplaceSpritesheet(0,d[item.own_key.."Autoeffect"])
				s:LoadGraphics()
			elseif spid == 2 then
				local anim = s:GetAnimation()
				s:Load(s:GetFilename(),true)
				s:Play(anim,true)
			end
			if d[item.own_key.."Frame"] == 10 then item.Bonus(d[item.own_key.."id"],ent) end
			if d[item.own_key.."Frame"] > 32 then d[item.own_key.."Finish"] = true end
		else
			if s:IsEventTriggered("Bonus") then item.Bonus(d[item.own_key.."id"],ent) end
			if s:IsFinished(s:GetAnimation()) then
				s:Load(d[item.own_key.."Filename"] or s:GetFilename(),true)
				s:Play(d[item.own_key.."Anim"] or s:GetAnimation(),true)
				if d[Item_Disequilibrium.own_key.."equal"] and ent.Type == 1000 then 
					if ent.Variant == 6 then s:ReplaceSpritesheet(0,"gfx/mimics/Delicate_Flower/devilangel.png") s:LoadGraphics() end
					if ent.Variant == 9 then 
						auxi.copy_sprite(auxi.copy_sprite(s,nil,{filename = "gfx/mimics/Delicate_Flower/1000.009_angelstatue.anm2",}),s,{Play = true,PlayOverlay = true,})
						for i = 0,4 do s:ReplaceSpritesheet(i,"gfx/mimics/Delicate_Flower/angeldevil.png") end
						s:LoadGraphics()
					end
				end
				d[item.own_key.."Finish"] = true
			end
		end
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			local idx = player:GetData().__Index
			save.elses[item.own_key.."effect"][idx] = player:GetCollectibleNum(item.entity)
			player:AddNullCostume(item.costumes)
		end
	end
	if save.elses[item.own_key.."Angel"] then
		save.elses[item.own_key.."Angel"] = nil
		Game():GetLevel():AddAngelRoomChance(0.5)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,touched)
	local idx = player:GetData().__Index
	save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0) + cnt
	player:AddNullCostume(item.costumes)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_LOSE_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,nownum)
	local idx = player:GetData().__Index
	if (save.elses[item.own_key.."effect"][idx] or 0) > 0 then
		save.elses[item.own_key.."effect"][idx] = math.max(0,save.elses[item.own_key.."effect"][idx] - cnt)
		if save.elses[item.own_key.."effect"][idx] <= 0 then player:TryRemoveNullCostume(item.costumes) end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if amt > 0 and auxi.is_damage_from_enemy(ent,amt,flag,source,cooldown) and player and auxi.has_have_coll(player,item.entity) then
		local idx = player:GetData().__Index
		if (save.elses[item.own_key.."effect"][idx] or 0) > 0 then
			save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] - 1
			if save.elses[item.own_key.."effect"][idx] <= 0 then player:TryRemoveNullCostume(item.costumes) end
			local q = Isaac.Spawn(1000,2,0,player.Position,Vector(0,0),nil):ToEffect()
			q:GetSprite().Color = Color(1,1,1,1,1,1,1)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_POT_BREAK_2,1,1.5,false,0,2)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	if selection_holder.check_select(player,item.own_key) and player:IsHoldingItem() == false then selection_holder.remove_select(player,item.own_key) end
	if (save.elses[item.own_key.."effect"][idx] or 0) > 0 then
		local succinfo = item.find_target(player)
		if succinfo then
			if auxi.check_for_the_same((d[item.own_key.."targ"] or {}).ent,succinfo.ent) ~= true and Game():GetRoom():GetFrameCount() > 5 then
				selection_holder.check_and_try_select(player,item.own_key)
				player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
			end
			if (player.Position - succinfo.ent.Position):Length() < 20 and player:IsHoldingItem() then
				item.PlayHappy(succinfo.ent,succinfo.info)
				consistance_holder.try_hold_entity(succinfo.ent,item.own_key)
				player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
				selection_holder.remove_select(player,item.own_key)
				save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] - 1
				if save.elses[item.own_key.."effect"][idx] <= 0 then player:TryRemoveNullCostume(item.costumes) end
			end
		elseif player:IsHoldingItem() and selection_holder.check_select(player,item.own_key) then
			player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
			selection_holder.remove_select(player,item.own_key)
		end
		d[item.own_key.."targ"] = succinfo
	elseif player:IsHoldingItem() and selection_holder.check_select(player,item.own_key) then
		player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
		selection_holder.remove_select(player,item.own_key)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 6,
Function = function(_,ent)
	if ent.SpawnerType ~= 1 and ent.SubType == 0 then item.Update_effect(ent) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 9,
Function = function(_,ent)
	item.Update_effect(ent)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 17,
Function = function(_,ent)
	item.Update_effect(ent)
end,
})

return item
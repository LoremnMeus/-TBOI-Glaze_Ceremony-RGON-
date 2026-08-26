local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Book_of_Future,
	goal = 50,
	empty_pool_sentinel = CollectibleType.COLLECTIBLE_KEY_PIECE_1,
	pools = {[0] = {},[1] = {},[2] = {},[3] = {},[4] = {},[5] = {},},
	q2c = {
		[0] = Color(1,1,1,1),
		[1] = Color(0,1,0.5,1),
		[2] = Color(0,0.5,1,1),
		[3] = Color(0.5,0,1,1),
		[4] = Color(1,0.5,0,1),
		[5] = Color(1,0,0,1),
	},
	special_pools = {		--记录一些首先删除的道具
		--[ItemPoolType.POOL_TREASURE] = {4,12,52,105,149,169,223,234,245,261,395,581,678,710,711,},		--
		[ItemPoolType.POOL_SHOP] = {232,619,347,716,enums.Items.More_Options___},		--
		[ItemPoolType.POOL_DEVIL] = {114,118,292,360,399,698,706,},		--441/477
		[ItemPoolType.POOL_ANGEL] = {98,108,182,313,331,415,643,691,},		--477
		[ItemPoolType.POOL_SECRET] = {168,489,625,628,636,664,689,723,},		--
		[ItemPoolType.POOL_GREED_DEVIL] = {114,118,292,360,399,698,706,},
		[ItemPoolType.POOL_GREED_ANGEL] = {98,108,182,313,331,415,643,691,},
	},
	pool_decrease = {
		[ItemPoolType.POOL_LIBRARY] = 0.1,
		[ItemPoolType.POOL_GOLDEN_CHEST] = 0.4,
		[ItemPoolType.POOL_RED_CHEST] = 0.4,
		[ItemPoolType.POOL_BEGGAR] = 0.5,
		[ItemPoolType.POOL_DEMON_BEGGAR] = 0.5,
		[ItemPoolType.POOL_CURSE] = 0.5,
		[ItemPoolType.POOL_KEY_MASTER] = 0.5,
		[ItemPoolType.POOL_BATTERY_BUM] = 0.5,
		[ItemPoolType.POOL_MOMS_CHEST] = 0.5,
		[ItemPoolType.POOL_GREED_CURSE] = 0.5,
		[ItemPoolType.POOL_CRANE_GAME] = 0.1,
		[ItemPoolType.POOL_ULTRA_SECRET] = 0.4,
		[ItemPoolType.POOL_BOMB_BUM] = 0.5,
		[ItemPoolType.POOL_OLD_CHEST] = 0.4,
	},
	has_removed = {},
	own_key = "Item_B_o_F",
}
auxi.add_to_seija(item.entity)

if true then
	local itemConfig = Isaac.GetItemConfig()
	local sz = itemConfig:GetCollectibles().Size
	for id = 1,sz do
		local collectible = itemConfig:GetCollectible(id)
		if (collectible and not collectible.Hidden and not collectible:HasTags(1<<15)) then
			local qual = collectible.Quality
			if item.pools[qual] then table.insert(item.pools[qual],#item.pools[qual] + 1,{id = id,}) end
		end
	end
end

function item.get_progress()
	local progress = tonumber(save.PermanentData.Book_of_Future_progress) or 0
	return math.max(0,math.min(item.goal,math.floor(progress)))
end

function item.set_progress(progress)
	save.PermanentData.Book_of_Future_progress = math.max(0,math.min(item.goal,math.floor(tonumber(progress) or 0)))
	if save.SaveModData then pcall(save.SaveModData,"book_of_future_progress") end
end

function item.draw_from_current_pool(rng)
	local pool = Game():GetItemPool()
	local pool_type = pool:GetPoolForRoom(Game():GetRoom():GetType(),Game():GetLevel():GetCurrentRoomDesc().SpawnSeed)
	if pool_type == ItemPoolType.POOL_NULL then pool_type = ItemPoolType.POOL_TREASURE end
	local collectible = pool:GetCollectible(pool_type,true,rng:GetSeed(),item.empty_pool_sentinel)
	if collectible == item.empty_pool_sentinel then return nil end
	return collectible
end

local function setup_escape_sprite(ent,alpha)
	local config = Isaac.GetItemConfig():GetCollectible(item.entity)
	local s = ent:GetSprite()
	s:Load("gfx/005.100_collectible.anm2",true)
	s:Play("Idle",true)
	if config and config.GfxFileName then s:ReplaceSpritesheet(1,config.GfxFileName) s:LoadGraphics() end
	s.Color = Color(1,1,1,alpha or 1,0.15,0.2,0.35)
	return s
end

local function show_escape_message()
	local hud = Game():GetHUD()
	if not hud or not hud.ShowItemText then return end
	if auxi.get_EID_language() == "zh_cn" then
		hud:ShowItemText("未来之书","未来逃逸了")
	else
		hud:ShowItemText("Book of Future","The future escaped")
	end
end

function item.spawn_escape(player)
	show_escape_message()
	local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,enums.Entities.AnnaHelper,0,player.Position,Vector(0,0),player):ToEffect()
	if not q then return end
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	q.PositionOffset = Vector(0,-22)
	q.DepthOffset = 100
	setup_escape_sprite(q,1)
	q:GetData()[item.own_key.."escape"] = {frame = 0,rotation = auxi.choose(-1,1) * 2.5,origin = auxi.ProtectVector(player.Position),}
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.AnnaHelper,
Function = function(_,ent)
	local d = ent:GetData()
	local info = d[item.own_key.."escape"]
	local afterimage = d[item.own_key.."escape_afterimage"]
	if info then
		info.frame = (info.frame or 0) + 1
		if info.frame <= 18 then
			ent.Velocity = ent.Velocity * 0.45
		else
			ent.Velocity = ent.Velocity + Vector(0,-0.52)
		end
		local s = ent:GetSprite()
		s.Rotation = s.Rotation + (info.rotation or 0)
		local alpha = math.max(0,1 - math.max(0,info.frame - 28)/18)
		s.Color = Color(1,1,1,alpha,0.15,0.2,0.35)
		if info.frame % 3 == 0 and info.frame <= 40 then
			local trail = Isaac.Spawn(EntityType.ENTITY_EFFECT,enums.Entities.AnnaHelper,0,ent.Position,Vector(0,0),ent.SpawnerEntity):ToEffect()
			if trail then
				trail.PositionOffset = auxi.ProtectVector(ent.PositionOffset)
				trail.DepthOffset = ent.DepthOffset - 1
				local ts = setup_escape_sprite(trail,0.32)
				ts.Rotation = s.Rotation
				ts.Scale = auxi.ProtectVector(s.Scale)
				trail:GetData()[item.own_key.."escape_afterimage"] = {frame = 0,}
			end
		end
		if info.frame >= 46 then
			local column = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.CRACK_THE_SKY,0,info.origin or ent.Position,Vector(0,0),ent.SpawnerEntity):ToEffect()
			if column then
				column.CollisionDamage = 0
				column.PositionOffset = Vector(0,0)
				column.SpriteScale = Vector(1.35,1.6)
				local black = Color(1,1,1,0.9)
				black:SetColorize(0.025,0.015,0.045,1)
				column:GetSprite().Color = black
			end
			ent:Remove()
		end
	elseif afterimage then
		afterimage.frame = (afterimage.frame or 0) + 1
		local alpha = math.max(0,0.32 * (1 - afterimage.frame/10))
		ent:GetSprite().Color = Color(1,1,1,alpha,0.15,0.2,0.35)
		if afterimage.frame >= 10 then ent:Remove() end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local pending = d[item.own_key.."pending_escape"]
	if not pending then return end
	pending.frame = (pending.frame or 0) + 1
	if player:IsHoldingItem() then pending.holding_frames = (pending.holding_frames or 0) + 1 end
	if (pending.holding_frames or 0) >= 6 or pending.frame >= 26 then
		player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
		item.spawn_escape(player)
		player:RemoveCollectible(item.entity,true,pending.active_slot or ActiveSlot.SLOT_PRIMARY,false)
		d[item.own_key.."pending_escape"] = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	if coltyp == item.entity then
		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			local useinfo = player:GetData()[item.own_key.."last_use"]
			if not (useinfo and useinfo.success and useinfo.frame == Game():GetFrameCount()) then return false end
			local room = Game():GetRoom()
			for i = 1,2 do
				local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
				q.OptionsPickupIndex = save.elses.Book_of_Future_cnt
			end
			return true
		else
			local itemConfig = Isaac.GetItemConfig()
			local rng = player:GetCollectibleRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			local room = Game():GetRoom()
			local targets = {}
			local cnt = 0
			local progress = item.get_progress()
			while(progress < item.goal and cnt < 50) do
				local tg = item.draw_from_current_pool(rng)
				if not tg then break end
				local config = itemConfig:GetCollectible(tg)
				progress = progress + (config and config.Quality or 0)
				cnt = cnt + 1
				table.insert(targets,#targets+1,{id = tg,})
			end
			local i_cnt = 0
			local ii_cnt = 0
			local limi = rng:RandomInt(10) + 15
			for u,v in pairs(targets) do
				--Game():GetItemPool():RemoveCollectible(v.id)
				local mx_cnt = math.max(1,math.min(limi,cnt - ii_cnt * limi))
				local pos = player.Position + auxi.MakeVector(360/mx_cnt*i_cnt) * (100 * (ii_cnt * 0.3 + 1))
				
				auxi.spawn_item_dust(player,pos,v.id,item.q2c[itemConfig:GetCollectible(v.id).Quality],Color(0.2,0.2,0.2,0.3,-0.8,-0.8,-0.8))
				i_cnt = i_cnt + 1
				if i_cnt >= limi then
					i_cnt = 0 
					ii_cnt = ii_cnt + 1
				end
				
			end
			local success = progress >= item.goal
			player:GetData()[item.own_key.."last_use"] = {frame = Game():GetFrameCount(),success = success,}
			if success then
				item.set_progress(0)
				local ndx = option_index_holder.find_a_new_index()
				local choice_count = 4
				if auxi.should_do_Seija(player) then choice_count = 1 end
				for i = 1,choice_count do
					local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
					q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
					q.OptionsPickupIndex = ndx
				end
				local q = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player)
				q.SpriteScale = Vector(2,2)
				save.elses.Book_of_Future_cnt = ndx
				if auxi.should_do_belial(player) then
					for i = 1,2 do
						local colid = auxi.get_item_from_pool(3,true,rng)
						local q2 = Isaac.Spawn(5,100,colid,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						q2:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
						q2.OptionsPickupIndex = ndx
					end
				end
				if auxi.should_spawn_wisp(player,useFlags) and #targets > 0 then
					local rnd = rng:RandomInt(#targets) + 1
					player:AddItemWisp(targets[rnd].id,player.Position,true)
				end
				return true
			end
			item.set_progress(progress)
			player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
			player:GetData()[item.own_key.."pending_escape"] = {frame = 0,active_slot = activeSlot,}
			if auxi.should_spawn_wisp(player,useFlags) and #targets > 0 then
				local rnd = rng:RandomInt(#targets) + 1
				player:AddItemWisp(targets[rnd].id,player.Position,true)
			end
			return {Discharge = true, Remove = false, ShowAnim = false}
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,colid,count)
	save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
	save.elses[item.own_key.."counter"][colid] = 1
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GET_COLLECTIBLE, params = nil,
Function = function(_,colid,pooltp,decrease,seed)
	if decrease then
		local dc = item.pool_decrease[pooltp] 
		if dc == nil then dc = 1 end
		save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
		save.elses[item.own_key.."counter"][colid] = (save.elses[item.own_key.."counter"][colid] or 0) + dc
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses.Book_of_Future_cnt = 200
		save.elses[item.own_key.."counter"] = {}
	end
	save.elses.Book_of_Future_fail = nil
	save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
end,
})

if EID then
	EID:addDescriptionModifier("qing_book_of_future_progress", function(desc)
		return desc.ObjType == 5 and desc.ObjVariant == 100 and desc.ObjSubType == item.entity and item.get_progress() > 0
	end, function(desc)
		-- 跨局保存的累计品质决定本次仍需抽取的动态数值；静态说明继续由 translate.lua 提供。
		local remaining = item.goal - item.get_progress()
		desc.Name = "{{ColorSilver}}-"..tostring(remaining).."{{CR}} "..(desc.Name or "")
		return desc
	end)
end

return item

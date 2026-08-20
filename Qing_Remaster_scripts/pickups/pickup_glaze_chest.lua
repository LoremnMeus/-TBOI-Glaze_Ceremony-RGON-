local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local glaze_curse = require("Qing_Remaster_scripts.pickups.pickup_glaze_curse")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local glaze_crown = require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze")

local item = {
	pickup = enums.Pickups.Glaze_chest,
	ToCall = {},
	familiar = enums.Familiars.Glaze_Chest_Key,
	familiar2 = enums.Familiars.Glaze_Chest_Key2,
	own_key = "Glaze_Chest",
}

local minimap_icon_registered = false

--- 任一房间任务表里是否已有该箱子 InitSeed 的钥匙任务（防小退/重 INIT 双钥匙）
local function find_task_for_chest(chest_seed)
	if chest_seed == nil then return nil, nil, nil end
	local tsk = save.elses[item.own_key.."Tsk"]
	if type(tsk) ~= "table" then return nil, nil, nil end
	for lsid, list in pairs(tsk) do
		if type(list) == "table" then
			for idx, rec in pairs(list) do
				if type(rec) == "table" and rec.chest_seed == chest_seed and not rec.Remove then
					return lsid, idx, rec
				end
			end
		end
	end
	return nil, nil, nil
end

local function register_key_task_for_chest(ent)
	if not ent then return false end
	local seed = ent.InitSeed
	if find_task_for_chest(seed) then
		return false
	end
	-- 兼容旧存档：认领无 chest_seed 的孤儿任务，避免小退后「旧空槽+新槽」双钥匙
	local tsk = save.elses[item.own_key.."Tsk"]
	if type(tsk) == "table" then
		for lsid, list in pairs(tsk) do
			if type(list) == "table" then
				for _, rec in pairs(list) do
					if type(rec) == "table" and not rec.Remove and rec.chest_seed == nil then
						rec.chest_seed = seed
						local d = ent:GetData()
						d[item.own_key.."key_room"] = lsid
						d[item.own_key.."chest_seed"] = seed
						return false
					end
				end
			end
		end
	end
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local tgs = {}
	for i = 0, rooms.Size do
		local targ = rooms:Get(i)
		if targ ~= nil and targ.SafeGridIndex >= 0 and targ.ListIndex >= 0 then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex, -1)
			if desc and desc.Data and desc.Data.Type ~= RoomType.ROOM_ULTRASECRET
				and desc.ListIndex ~= level:GetCurrentRoomDesc().ListIndex
				and desc.ListIndex == targ.ListIndex then
				table.insert(tgs, #tgs + 1, desc.ListIndex)
			end
		end
	end
	if #tgs <= 0 then return false end
	local rng = ent:GetDropRNG()
	rng = auxi.rng_for_sake(rng)
	local tg = tgs[rng:RandomInt(#tgs) + 1]
	save.elses[item.own_key.."Tsk"] = save.elses[item.own_key.."Tsk"] or {}
	save.elses[item.own_key.."Tsk"][tg] = save.elses[item.own_key.."Tsk"][tg] or {}
	table.insert(save.elses[item.own_key.."Tsk"][tg], {
		chest_seed = seed,
	})
	local d = ent:GetData()
	d[item.own_key.."key_room"] = tg
	d[item.own_key.."chest_seed"] = seed
	return true
end

--- 开箱时回收该箱对应的未捡钥匙任务（避免「箱已开、房里钥匙还在」与计数错乱）
local function clear_task_for_chest(chest_seed)
	local lsid, idx = find_task_for_chest(chest_seed)
	if lsid and idx and save.elses[item.own_key.."Tsk"] and save.elses[item.own_key.."Tsk"][lsid] then
		save.elses[item.own_key.."Tsk"][lsid][idx] = nil
	end
end

--- ImGui 审计：钥匙计数 / 任务表 / 房内实体对照
function item.get_key_audit_text()
	local lines = {}
	local key_cnt = save.elses[item.own_key.."key_cnt"] or {}
	local key_fake = save.elses[item.own_key.."key_cnt_fake"] or {}
	local tsk = save.elses[item.own_key.."Tsk"] or {}

	table.insert(lines, "=== 琉璃宝箱钥匙审计 ===")
	local any_cnt = false
	for idx, n in pairs(key_cnt) do
		any_cnt = true
		table.insert(lines, string.format("玩家[%s] key_cnt=%s  fake待合并=%s",
			tostring(idx), tostring(n), tostring(key_fake[idx] or 0)))
	end
	for idx, n in pairs(key_fake) do
		if key_cnt[idx] == nil then
			any_cnt = true
			table.insert(lines, string.format("玩家[%s] key_cnt=(无)  fake待合并=%s", tostring(idx), tostring(n)))
		end
	end
	if not any_cnt then table.insert(lines, "key_cnt：空") end

	local pending = 0
	local orphan = 0
	local task_lines = {}
	for lsid, list in pairs(tsk) do
		if type(list) == "table" then
			for i, rec in pairs(list) do
				if type(rec) == "table" and not rec.Remove then
					pending = pending + 1
					if rec.chest_seed == nil then orphan = orphan + 1 end
					table.insert(task_lines, string.format("  房ListIndex=%s slot=%s chest_seed=%s",
						tostring(lsid), tostring(i), tostring(rec.chest_seed)))
				end
			end
		end
	end
	table.insert(lines, string.format("未捡钥匙任务：%d（无 chest_seed 孤儿=%d）", pending, orphan))
	local shown = 0
	for _, row in ipairs(task_lines) do
		shown = shown + 1
		if shown <= 16 then table.insert(lines, row) end
	end
	if #task_lines > 16 then
		table.insert(lines, string.format("  …另有 %d 条未列出", #task_lines - 16))
	end

	local chests = 0
	local open_chests = 0
	local wait_keys = 0
	local follow_keys = 0
	local n_entity = Isaac.GetRoomEntities()
	for _, ent in pairs(n_entity) do
		if ent.Type == EntityType.ENTITY_PICKUP and ent.Variant == item.pickup.Variant then
			chests = chests + 1
			if ent.SubType == 0 then open_chests = open_chests + 1 end
		elseif ent.Type == EntityType.ENTITY_FAMILIAR then
			if ent.Variant == item.familiar then
				local d = ent:GetData()
				if d[item.own_key.."Waiting"] then wait_keys = wait_keys + 1
				else follow_keys = follow_keys + 1 end
			elseif ent.Variant == item.familiar2 then
				follow_keys = follow_keys + 1
			end
		end
	end
	table.insert(lines, string.format("本房：箱=%d（已开=%d） 等待钥匙=%d 跟随钥匙=%d",
		chests, open_chests, wait_keys, follow_keys))
	local cur = Game():GetLevel():GetCurrentRoomDesc()
	if cur then
		table.insert(lines, string.format("当前 ListIndex=%s", tostring(cur.ListIndex)))
	end
	return table.concat(lines, "\n")
end

--- MinimapAPI 掉落图标（不是 RGON `Minimap`）。
--- 旧代码 Load 本模组不存在的 gfx/ui/minimap_icons.anm2 → 空白。
--- 正确：用 MinimapAPI.SpriteIcons（IconChest）或自带 custom anm2（Epiphany 做法）。
local function register_minimap_icon()
	if minimap_icon_registered then return end
	if not MinimapAPI or not MinimapAPI.AddIcon or not MinimapAPI.AddPickup then
		return
	end
	local icons = MinimapAPI.SpriteIcons
	if not icons then return end

	local glaze_tint = Color(0.55, 0.9, 1, 1, 0.08, 0.12, 0.2)
	MinimapAPI:AddIcon(
		"QingRemasterGlazeChest",
		icons,
		"IconChest",
		4,
		glaze_tint
	)
	local not_collected = MinimapAPI.PickupChestNotCollected or MinimapAPI.PickupNotCollected
	MinimapAPI:AddPickup(
		"QingRemasterGlazeChest",
		"QingRemasterGlazeChest",
		EntityType.ENTITY_PICKUP,
		item.pickup.Variant,
		item.pickup.SubType or -1,
		not_collected,
		"chests",
		7500
	)
	minimap_icon_registered = true
end

register_minimap_icon()
if REPENTOGON and ModCallbacks.MC_POST_MODS_LOADED then
	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_MODS_LOADED, params = nil,
	Function = function(_)
		register_minimap_icon()
	end,
	})
end
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_)
	register_minimap_icon()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		local idx = player:GetData().__Index
		player:CheckFamiliar(item.familiar, (save.elses[item.own_key.."key_cnt"] or {})[idx] or 0, player:GetCollectibleRNG(33))	
		local d = player:GetData()
		if d[item.own_key.."Reset"] then 
			player:CheckFamiliar(item.familiar2, 0, player:GetCollectibleRNG(33))
			d[item.own_key.."Reset"] = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = item.pickup.Variant,
Function = function(_,ent, col, low)
    local player = col:ToPlayer()
	if player and ent.SubType ~= 0 then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local idx = player:GetData().__Index
		if s:IsPlaying("Idle") then
			if auxi.check_all_exists(d[item.own_key.."TgKey"]) ~= true and ((save.elses[item.own_key.."key_cnt"] or {})[idx] or 0)> 0 then
				local tgs1 = auxi.getothers(nil,3,item.familiar)
				for u,v in pairs(tgs1) do
					local d2 = v:GetData()
					if not (d2[item.own_key.."Waiting"] and not d2[item.own_key.."Follow"]) then
						d2[item.own_key.."Tg"] = ent
						d[item.own_key.."TgKey"] = v
						break
					end
				end
			end
			if auxi.check_all_exists(d[item.own_key.."TgKey"]) ~= true and ((save.elses[item.own_key.."key_cnt_fake"] or {})[idx] or 0)> 0 then
				local tgs2 = auxi.getothers(nil,3,item.familiar2)
				for u,v in pairs(tgs2) do
					local d2 = v:GetData()
					if not (d2[item.own_key.."Waiting"] and not d2[item.own_key.."Follow"]) then
						d2[item.own_key.."Tg"] = ent
						d[item.own_key.."TgKey"] = v
						break
					end
				end
			end
		end
		return false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_,ent)
	if ent.Variant == item.familiar then
		local s = ent:GetSprite()
		s:Play("Float",true)
		ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local room = Game():GetRoom()
	if auxi.check_all_exists(d[item.own_key.."Tg"]) ~= true then
		if d[item.own_key.."Tg"] ~= nil and not s:IsPlaying("Float") then s:Play("Float",true) end
		if d[item.own_key.."Waiting"] then
			if s:IsPlaying("Idle") then
				if auxi.check_all_exists(d[item.own_key.."Player"]) ~= true then
					for playerNum = 1, Game():GetNumPlayers() do
						local player = Game():GetPlayer(playerNum - 1)
						if (player.Position - ent.Position):Length() < 20 then
							ent.Player = player
							d[item.own_key.."Player"] = player
							d[item.own_key.."Follow"] = true
							local idx = player:GetData().__Index
							if idx ~= nil then
								save.elses[item.own_key.."key_cnt_fake"] = save.elses[item.own_key.."key_cnt_fake"] or {}
								save.elses[item.own_key.."key_cnt_fake"][idx] = (save.elses[item.own_key.."key_cnt_fake"][idx] or 0) + 1
							end
							s:Play("Idle_Float",true)
							break
						end
					end
				end
				d[item.own_key.."Pos"] = d[item.own_key.."Pos"] or ent.Position
				ent:FollowPosition(d[item.own_key.."Pos"])
			end
			if s:IsFinished("Idle_Float") then s:Play("Float",true)	end
			if s:IsPlaying("Float") or s:IsPlaying("Idle_Float") then
				if auxi.check_all_exists(ent.Player) then
					if not d[item.own_key.."IsFollow"] then
						ent:AddToFollowers()
						d[item.own_key.."IsFollow"] = true
					end
					ent:FollowParent()
				else
					if d[item.own_key.."IsFollow"] then
						ent:RemoveFromFollowers()
						d[item.own_key.."IsFollow"] = false
					end
					d[item.own_key.."Follow"] = false
					s:Play("Idle",true)
				end
			end
		else
			if not d[item.own_key.."IsFollow"] then
				ent:AddToFollowers()
				d[item.own_key.."IsFollow"] = true
			end
			ent:FollowParent()
		end
	else
		if d[item.own_key.."Follow"] then
			ent:RemoveFromFollowers()
			d[item.own_key.."Follow"] = nil
		end
		if (ent.Position - d[item.own_key.."Tg"].Position):Length() < 70 then
			if not s:IsPlaying("Open") and not s:IsFinished("Open") then s:Play("Open",true) end
			ent.Position = ent.Position * 0.8 + d[item.own_key.."Tg"].Position * 0.2
			ent.Velocity = ent.Velocity * 0.5
		else
			ent:FollowPosition(d[item.own_key.."Tg"].Position)	
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar2,
Function = function(_,ent)
	if ent.Variant == item.familiar2 then
		ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar2,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local room = Game():GetRoom()
	if auxi.check_all_exists(d[item.own_key.."Tg"]) ~= true then
		if d[item.own_key.."Tg"] ~= nil and not s:IsPlaying("Float") then s:Play("Float",true) end
		if d[item.own_key.."Waiting"] then
			if s:IsPlaying("Idle") then
				if auxi.check_all_exists(d[item.own_key.."Player"]) ~= true then
					for playerNum = 1, Game():GetNumPlayers() do
						local player = Game():GetPlayer(playerNum - 1)
						if (player.Position - ent.Position):Length() < 20 then
							ent.Player = player
							d[item.own_key.."Player"] = player
							d[item.own_key.."Follow"] = true
							local idx = player:GetData().__Index
							if idx ~= nil then
								save.elses[item.own_key.."key_cnt_fake"] = save.elses[item.own_key.."key_cnt_fake"] or {}
								save.elses[item.own_key.."key_cnt_fake"][idx] = (save.elses[item.own_key.."key_cnt_fake"][idx] or 0) + 1
							end
							s:Play("Idle_Float",true)
							if d[item.own_key.."record"] then d[item.own_key.."record"].Remove = true end
							break
						end
					end
				end
				d[item.own_key.."Pos"] = d[item.own_key.."Pos"] or ent.Position
				ent:FollowPosition(d[item.own_key.."Pos"])
			end
			if s:IsFinished("Idle_Float") then s:Play("Float",true)	end
			if s:IsPlaying("Float") or s:IsPlaying("Idle_Float") then
				if auxi.check_all_exists(ent.Player) then
					if not d[item.own_key.."IsFollow"] then
						ent:AddToFollowers()
						d[item.own_key.."IsFollow"] = true
					end
					ent:FollowParent()
				else
					if d[item.own_key.."IsFollow"] then
						ent:RemoveFromFollowers()
						d[item.own_key.."IsFollow"] = false
					end
					d[item.own_key.."Follow"] = false
					s:Play("Idle",true)
				end
			end
		else
			if not d[item.own_key.."IsFollow"] then
				ent:AddToFollowers()
				d[item.own_key.."IsFollow"] = true
			end
			ent:FollowParent()
		end
	else
		if d[item.own_key.."Follow"] then
			ent:RemoveFromFollowers()
			d[item.own_key.."Follow"] = nil
		end
		if (ent.Position - d[item.own_key.."Tg"].Position):Length() < 70 then
			if not s:IsPlaying("Open") and not s:IsFinished("Open") then s:Play("Open",true) end
			ent.Position = ent.Position * 0.8 + d[item.own_key.."Tg"].Position * 0.2
			ent.Velocity = ent.Velocity * 0.5
		else
			ent:FollowPosition(d[item.own_key.."Tg"].Position)	
		end
	end
end,
})

function item.try_open(player,ent)
	if player == nil then player = Game():GetPlayer(0) end
	if ent == nil then return end
	local rng = ent:GetDropRNG()
	rng = auxi.rng_for_sake(rng)
	local rnd = rng:RandomInt(100)
	local level = Game():GetLevel()
	if level:GetStage() == LevelStage.STAGE6 then rnd = 1 end
	if rnd > 40 then				--生成基础
		local cnt = rng:RandomInt(4) + 4
		if glaze_crown.should_empower(player) then cnt = cnt + 4 end
		local idx = player:GetData().__Index
		if idx ~= nil then
			if save.elses["curse_of_glaze"..tostring(idx)] == nil then save.elses["curse_of_glaze"..tostring(idx)] = 0 end
			save.elses["curse_of_glaze"..tostring(idx)] = save.elses["curse_of_glaze"..tostring(idx)] + item.pickup.heavy
		end
		for i = 1,cnt do
			local info = item.pickup
			local wei = 0
			for u,v in pairs(enums.Pickups) do
				wei = wei + v.wei
			end
			wei = rng:RandomInt(wei)
			for u,v in pairs(enums.Pickups) do
				wei = wei - v.wei
				if wei <= 0 then
					info = v
					if u == "Glaze_bomb" and auxi.has_poop_player() then
						info = enums.Pickups.Glaze_big_poop
					end
					break
				end
			end
			local q = Isaac.Spawn(5,info.Variant,info.SubType,ent.Position,math.random(1000)/500 * auxi.MakeVector(math.random(36000)/100),nil)
			auxi.special_morph(q,info)
		end
	else
		local target = auxi.get_random_item_that_player_has(nil,rng)
		if target == nil then target = enums.Items.It_s_a_trick end
		local q = Isaac.Spawn(5,100,target,ent.Position,Vector(0,0),nil):ToPickup()
		q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
		local d1 = q:GetData()
		consistance_holder.try_hold_entity(q,item.own_key,{ignore_subtype = true})
		local s1 = q:GetSprite()
		s1:ReplaceSpritesheet(5,"gfx/items/to_item_altar.png")
		s1:LoadGraphics()
		s1:SetOverlayFrame("Alternates", 4)
		consistance_holder.try_remove_entity(ent,item.own_key)
		ent:Remove()
	end
	auxi.try_start_ambush()
	glaze_crown.notify_pickup(player)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 100,
Function = function(_,ent)
	if ent.Type == 5 and ent.Variant == 100 then
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		local d = ent:GetData()
		if succ then
			local s = ent:GetSprite()
			s:ReplaceSpritesheet(5,"gfx/items/to_item_altar.png")
			s:LoadGraphics()
			s:SetOverlayFrame("Alternates", 4)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = item.pickup.Variant,
Function = function(_,ent)
	if ent.SubType ~= 0 then
		local s = ent:GetSprite()
		local d = ent:GetData()
		if s:IsEventTriggered("DropSound") then	sound_tracker.PlayStackedSound(SoundEffect.SOUND_CHEST_DROP,1,1,false,0,2) end
		if s:IsPlaying("Idle") then
			if auxi.check_all_exists(d[item.own_key.."TgKey"]) then
				local v = d[item.own_key.."TgKey"]
				local dis = ent.Position - v.Position
				local s2 = v:GetSprite()
				local d2 = v:GetData()
				if dis:Length() < 40 and s2:IsFinished("Open") then
					auxi.remove_others_option_pickup(ent)
					ent.SubType = 0
					local player = v:ToFamiliar().Player or Game():GetPlayer(0)
					local idx = player:GetData().__Index
					item.try_open(player,ent)
					s:Play("Open",true)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_UNLOCK00,1,1,false,0,2)
					d._Data = d._Data or {}
					d._Data[item.own_key] = d._Data[item.own_key] or {}
					d._Data[item.own_key].remove_this_chest = true
					consistance_holder.try_hold_entity(ent,item.own_key)
					
					if d2[item.own_key.."Waiting"] ~= true and (save.elses[item.own_key.."key_cnt"] or {})[idx] then
						save.elses[item.own_key.."key_cnt"][idx] = save.elses[item.own_key.."key_cnt"][idx] - 1
					elseif d2[item.own_key.."Follow"] then
						if d2[item.own_key.."record"] then
							d2[item.own_key.."record"].Remove = true
						end
					end
					-- 无论用跟随钥匙还是房内钥匙：回收该箱登记的任务，保证 1 箱 ↔ 1 钥匙
					clear_task_for_chest(ent.InitSeed)
					d[item.own_key.."TgKey"]:Remove()
				end
			end
		end
		if s:IsFinished("Open") then s:Play("Opened",true) end
		if ent.Velocity:Length() > 0.1 then	ent.Velocity = ent.Velocity * 0.8 end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = item.pickup.Variant,
Function = function(_,ent)
	if ent.SubType == 0 then ent:Remove()
	else
		if consistance_holder.try_check_entity(ent,item.own_key) then
			local d = ent:GetData()
			if d._Data[item.own_key].remove_this_chest then
				local succ = consistance_holder.try_remove_entity(ent,item.own_key)
				ent:Remove()
			end
		else
			consistance_holder.try_hold_entity(ent,item.own_key)
			-- 仅首次为该 InitSeed 登记一把钥匙；小退/换房重 INIT 不得再插 Tsk
			register_key_task_for_chest(ent)
		end
		if Epiphany then Epiphany.PersistentDataHelper:GetPickupData(ent).TRK_HasMidasImmunity = true end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	local lsid = desc.ListIndex 
	local tgs = auxi.getothers(nil,3,item.familiar2)
	for u,v in pairs(tgs) do v:Remove() end 
	if lsid >= 0 and desc.SafeGridIndex >= 0 then
		if (save.elses[item.own_key.."Tsk"] or {})[lsid] then
			for u,v in pairs(save.elses[item.own_key.."Tsk"][lsid]) do
				if v.Remove then save.elses[item.own_key.."Tsk"][lsid][u] = nil
				else
					local pos 
					if v.pos then pos = auxi.ProtectVector(v.pos)
					else pos = room:GetGridPosition(auxi.random_in_table(auxi.check_path_from_door())) v.pos = auxi.Vector2Table(pos) end
					local q = Isaac.Spawn(3,item.familiar2,0,pos,Vector(0,0),nil):ToFamiliar()
					local d = q:GetData()
					d[item.own_key.."record"] = v
					local s = q:GetSprite()
					s:Play("Idle",true)
					d[item.own_key.."Waiting"] = true
				end
			end
		end
	end
	save.elses[item.own_key.."key_cnt"] = save.elses[item.own_key.."key_cnt"] or {}
	for u,v in pairs(save.elses[item.own_key.."key_cnt_fake"] or {}) do
		save.elses[item.own_key.."key_cnt"][u] = (save.elses[item.own_key.."key_cnt"][u] or 0) + v
	end
	save.elses[item.own_key.."key_cnt_fake"] = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."key_cnt"] = {}
	save.elses[item.own_key.."key_cnt_fake"] = {}
	save.elses[item.own_key.."Tsk"] = {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		d[item.own_key.."Reset"] = true
		player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
		d.should_evaluate_on_update_once = true
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."Tsk"] = {}
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local d = player:GetData()
			d[item.own_key.."Reset"] = true
			player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
			d.should_evaluate_on_update_once = true
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = nil,
Function = function(_,ent)
	if (ent.Variant >= 50 and ent.Variant <= 60) and ent.SubType ~= 0 then
		if Unlocker.should_any_be_done("Pickup","Glaze_Chest",nil,"Pickup_allow") then
			local rng = ent:GetDropRNG()
			rng = auxi.rng_for_sake(rng)
			if glaze_crown.roll_convert(rng, 80) then		-- 原 1/80
				ent:Morph(5,item.pickup.Variant,item.pickup.SubType,true)
			end
		end
	end
end,
})

return item

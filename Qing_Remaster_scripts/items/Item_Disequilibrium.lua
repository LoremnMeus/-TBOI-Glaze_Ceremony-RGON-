local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local grid_wall = require("Qing_Remaster_scripts.grids.grid_wall")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Disequilibrium,
	own_key = "Item_Disequilibrium_",
	middleinfo = {
		ReplaceGrid = {
			
		},
		PreReplace = {
			[5] = function(vr,st,gid,seed)
			end,
			[33] = function(vr,st,gid,seed)
				if vr < 4 then return {33,4,0,} end
			end,
			[999] = function(vr,st,gid,seed)
			end,
		},
		ReplaceEnt = {
		},
	},
	description = {
		[CollectibleType.COLLECTIBLE_DUALITY] = {desc = "天使恶魔房与恶魔天使房将同时开启",},
		[enums.Items.Heart_Change] = {desc = "开启的房间同时视为天使房与恶魔房",},
	},
	Reloadname = {
		["gfx/grid/Door_07_DevilRoomDoor.anm2"] = "gfx/stage/Disequilibrium_room/door_07_devilroomdoor.anm2",
		["gfx/grid/Door_07_HolyRoomDoor.anm2"] = "gfx/stage/Disequilibrium_room/door_07_holyroomdoor.anm2",
	},
	move_type = {
		[RoomType.ROOM_DEVIL] = {Floor = "gfx/stage/Disequilibrium_room/10_cathedral.png",Wall = "gfx/stage/Disequilibrium_room/10_cathedral.png",
			ReplaceGrid = {
				[1] = function(grid)
					local s = grid:GetSprite()
					local anim = s:GetAnimation()
					s:Load("gfx/grid/props_10_cathedral.anm2",true)
					s:Play(anim,true)
				end,
				[7] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/grid_pit_cathedral.png") s:LoadGraphics() end,
				[24] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_cathedral.png") s:LoadGraphics() end,
				[25] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_cathedral.png") s:LoadGraphics() end,
				[26] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_cathedral.png") s:LoadGraphics() end,
				[27] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_cathedral.png") s:LoadGraphics() end,
				[6] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_cathedral.png") s:LoadGraphics() end,
				[5] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_cathedral.png") s:LoadGraphics() end,
				[4] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_cathedral.png") s:LoadGraphics() end,
				[3] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_cathedral.png") s:LoadGraphics() end,
				[2] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_cathedral.png") s:LoadGraphics() end,
			},
			PreReplace = {
				[5] = function(vr,st,gid,seed)
					if vr == 10 and st == 6 then return {5,10,3,} end
					if vr == 10 and st == 11 then return {5,10,4,} end
					if vr == 69 and st == 1 then return {5,69,0,} end
					if vr == 360 then return {5,53,st} end
					if vr == 150 then return {999,enums.Entities.Disequilibrium_helper,0,} end
				end,
				[6] = function(vr,st,gid,seed)
					if vr == 5 then return {6,4,0,} end
				end,
				[33] = function(vr,st,gid,seed)
					if vr == 0 then return 2 end
					if vr == 1 then return 3 end
				end,
				[61] = function(vr,st,gid,seed) if vr == 2 then return {61,5,0,} end end,
				[251] = function(vr,st,gid,seed) return {55,2,0,} end,
				[252] = function(vr,st,gid,seed) return {60,2,0,} end,
				[259] = function(vr,st,gid,seed) return {38,1,0,} end,
				[279] = function(vr,st,gid,seed) return {805,0,0,} end,
				[219] = function(vr,st,gid,seed) return {833,0,0,} end,
				[999] = function(vr,st,gid,seed)
				end,
				[1930] = function(vr,st,gid,seed) return {4000,0,0} end,
				[3000] = function(vr,st,gid,seed) return {1900,0,0} end,
				[5000] = function(vr,st,gid,seed) return {5001,0,0} end,
			},
			ReplaceEnt = {
			},
			Replace2Ent = {
				[1000] = function(ent,item)
					if ent.Variant == 6 then 
						local s = ent:GetSprite()
						for i = 0,4 do s:ReplaceSpritesheet(i,"gfx/mimics/Delicate_Flower/devilangel.png") end
						s:LoadGraphics()
						local d = ent:GetData()
						d[item.own_key.."equal"] = true
					end
				end,
			},
			ReloadDoor = {
				[1] = "gfx/stage/Disequilibrium_room/door_07_devilroomdoor.anm2",
				[2] = "gfx/grid/Door_07_HolyRoomDoor.anm2",
				[3] = "gfx/stage/Disequilibrium_room/door_07_holyroomdoor.anm2",
			},
			movepool = {
				[ItemPoolType.POOL_DEVIL] = ItemPoolType.POOL_ANGEL,
			},
		},
		[RoomType.ROOM_ANGEL] = {Floor = "gfx/stage/Disequilibrium_room/09_sheol.png",Wall = "gfx/stage/Disequilibrium_room/09_sheol.png",
			ReplaceGrid = {
				[1] = function(grid)
					local s = grid:GetSprite()
					local anim = s:GetAnimation()
					s:Load("gfx/grid/props_09_sheol.anm2",true)
					s:Play(anim,true)
				end,
				[7] = function(grid) local s = grid:GetSprite()	s:ReplaceSpritesheet(0,"gfx/grid/grid_pit_depths.png") s:LoadGraphics() end,
				[24] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_sheol.png") s:LoadGraphics() end,
				[25] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_sheol.png") s:LoadGraphics() end,
				[26] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_sheol.png") s:LoadGraphics() end,
				[27] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_sheol.png") s:LoadGraphics() end,
				[6] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_sheol.png") s:LoadGraphics() end,
				[5] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_sheol.png") s:LoadGraphics() end,
				[4] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_sheol.png") s:LoadGraphics() end,
				[3] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_sheol.png") s:LoadGraphics() end,
				[2] = function(grid) local s = grid:GetSprite() s:ReplaceSpritesheet(0,"gfx/grid/rocks_sheol.png") s:LoadGraphics() end,
			},
			PreReplace = {
				[5] = function(vr,st,gid,seed)
					if vr == 10 and st == 3 then return {5,10,6,} end
					if vr == 10 and st == 4 then return {5,10,11,} end
					if vr == 53 then return {5,360,st} end
					if vr == 100 or vr == 150 then return {999,enums.Entities.Disequilibrium_helper,0,} end
				end,
				[6] = function(vr,st,gid,seed)
					if vr == 4 then return {6,5,0,} end
				end,
				[33] = function(vr,st,gid,seed)
					if vr == 2 then return 0 end
					if vr == 3 then return 1 end
				end,
				[999] = function(vr,st,gid,seed)
				end,
				[4000] = function(vr,st,gid,seed) return {1930,0,0} end,
				[1900] = function(vr,st,gid,seed) return {3000,0,0} end,
				[5001] = function(vr,st,gid,seed) return {5000,0,0} end,
			},
			ReplaceEnt = {
			},
			Replace2Ent = {
				[1000] = function(ent,item)
					if ent.Variant == 9 then 
						local s = ent:GetSprite()
						auxi.copy_sprite(auxi.copy_sprite(s,nil,{filename = "gfx/mimics/Delicate_Flower/1000.009_angelstatue.anm2",}),s,{Play = true,PlayOverlay = true,})
						for i = 0,4 do s:ReplaceSpritesheet(i,"gfx/mimics/Delicate_Flower/angeldevil.png") end
						s:LoadGraphics()
						local d = ent:GetData()
						d[item.own_key.."equal"] = true
					end
				end,
			},
			ReloadDoor = {
				[1] = "gfx/stage/Disequilibrium_room/door_07_holyroomdoor.anm2",
				[2] = "gfx/grid/Door_07_DevilRoomDoor.anm2",
				[3] = "gfx/stage/Disequilibrium_room/door_07_devilroomdoor.anm2",
			},
			movepool = {
				[ItemPoolType.POOL_ANGEL] = ItemPoolType.POOL_DEVIL,
			},
		},
	},
	set_over = nil,
	get_over = nil,
}
auxi.add_EID_item_synic(item.entity,item.description)
--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do print(v.Type.." "..v.Variant.." "..v.SubType) print(v.Position) end
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	if auxi.has_have_coll(player,item.entity) then value[498] = (value[498] or 0) + 1 end
end,
})

function item.is_dual_room()
	if (auxi.have_player_has_collectible(item.entity) and item.move_type[Game():GetRoom():GetType()]) then return true
	else return false end
end

function item.special_morph(ent,force)
	consistance_holder.try_hold_over_entity(ent,item.own_key)
	ent:GetData()._Data[item.own_key]["effect"] = true
	if Game():GetRoom():GetType() == RoomType.ROOM_ANGEL then 
		if force then ent.Price = -1 end
		price_holder.catch_price_over(ent)
		ent:GetData()._Data[item.own_key]["effect2"] = true
	else
		if force then 
			item.record_option_index = item.record_option_index or option_index_holder.find_a_new_index()
			ent.OptionsPickupIndex = item.record_option_index
		end
	end
	consistance_holder.try_hold_entity(ent,item.own_key,{ignore_subtype = true,})
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local d = ent:GetData()
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ and d._Data[item.own_key]["effect2"] then
		return auxi.get_acceptible_devil_price(ent)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = nil,
Function = function(_,ent)
	if auxi.have_player_has_collectible(item.entity) and item.move_type[Game():GetRoom():GetType()] then
		local room = Game():GetRoom()
		local gid = room:GetGridIndex(ent.Position)
		local wd = room:GetGridWidth()
		if gid % wd > math.floor(wd/2) and ent.FrameCount == 0 then
			-- 已转换过：只恢复 Consistance 数据，禁止再 Morph / Remove+Spawn（小退会 FrameCount==0）
			if consistance_holder.try_check_entity(ent,item.own_key) then
				return
			end
			if ent.Variant == 100 then
				if (save.elses[item.own_key.."record"] or {})[ent.SubType] == 2 then
					item.set_over = true
					ent:Morph(5,100,0,true,true)
					item.special_morph(ent)
					item.set_over = nil
				end
			else
				delay_buffer.addeffe(function(params)
					if auxi.check_all_exists(ent) and ent.Price ~= 0 then
						if consistance_holder.try_check_entity(ent,item.own_key) then return end
						item.set_over = true
						local pos = ent.Position
						ent:Remove()
						ent = Isaac.Spawn(5,100,0,pos,Vector(0,0),nil):ToPickup()
						item.special_morph(ent,true)
						item.set_over = nil
					end
				end,{},1)
			end
		end
	end
end,
})
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GET_COLLECTIBLE, params = nil,
Function = function(_,colid,tp,decrease,seed)
	if item.move_type[Game():GetRoom():GetType()] then
		save.elses[item.own_key.."record"] = save.elses[item.own_key.."record"] or {}
		if item.set_over then save.elses[item.own_key.."record"][colid] = 1
		else save.elses[item.own_key.."record"][colid] = 2 end
		--print(save.elses[item.own_key.."record"][colid].." "..colid)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil,
Function = function(_,tp,decrease,seed)
	if item.set_over and item.move_type[Game():GetRoom():GetType()] then
		local info = item.move_type[Game():GetRoom():GetType()]
		if info.movepool[tp] then return auxi.get_item_from_pool(info.movepool[tp],decrease,seed) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = enums.Entities.Disequilibrium_helper,
Function = function(_,ent)
	item.set_over = true
	local q = Isaac.Spawn(5,100,0,ent.Position,Vector(0,0),nil):ToPickup()
	item.special_morph(q,true)
	item.set_over = nil
	ent:Remove()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, params = nil,
Function = function(_,tp,vr,st,gid,seed)
	if auxi.have_player_has_collectible(item.entity) then
		local room = Game():GetRoom()
		local info = item.move_type[room:GetType()]
		local wd = room:GetGridWidth()
		if info then
			if gid % wd > math.floor(wd/2) then
				local ret = auxi.check_if_any(info.PreReplace[tp],vr,st,gid,seed)
				--print(tp)
				if type(ret) == "number" then ret = {tp,ret,st,} end
				if ret then return ret end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,rng,pos)
	if auxi.have_player_has_collectible(item.entity) then
		local room = Game():GetRoom()
		local tbl = {}
		for i = 0,7 do
			local door = room:GetDoor(i)
			if door and item.Reloadname[door:GetSprite():GetFilename()] then
				auxi.copy_sprite(auxi.copy_sprite(door:GetSprite(),nil,{filename = item.Reloadname[door:GetSprite():GetFilename()],}),door:GetSprite(),{Play = true,PlayOverlay = true,})
				if door.TargetRoomIndex == -1 then table.insert(tbl,#tbl + 1,i) end
			end
		end
		if #tbl > 1 and auxi.get_player_have_collectible_num(498) == auxi.get_player_have_collectible_num(item.entity,nil,{counter = 1,}) then 
			for j = 2,#tbl do 
				local door = room:GetDoor(tbl[j])
				local n_entity = Isaac.GetRoomEntities()
				for u,v in pairs(n_entity) do
					if v.Type == 1000 and v.Variant == 59 and (v.Position - door.Position):Length() < 100 then v:Remove() end
				end
				room:RemoveDoor(tbl[j]) 
			end
		end
	end
end,
})

function item.check_for_room()
	local room = Game():GetRoom()
	local info = item.move_type[room:GetType()]
	if info then
		grid_wall.ChangeBackdrop({WallAnm2 = "gfx/stage/Disequilibrium_room/WallBackdrop.anm2",FloorAnm2 = "gfx/stage/Disequilibrium_room/FloorBackdrop.anm2",
			Floors = {info.Floor,},
			Walls = {info.Wall,},
		})
		local wd = room:GetGridWidth()
		local ht = room:GetGridHeight()
		for x = math.ceil(wd/2),wd do
			for y = 0,ht - 1 do
				local id = x + y * wd
				local grid = room:GetGridEntity(id)
				if grid then auxi.check_if_any(info.ReplaceGrid[grid:GetType()],grid,info) end
			end
		end
		local n_entity = Isaac.GetRoomEntities()
		for u,v in pairs(n_entity) do
			local gid = room:GetGridIndex(v.Position)
			if gid % wd > math.floor(wd/2) then
				auxi.check_if_any(info.ReplaceEnt[v.Type],v)
				--print("Ent:"..v.Type.." "..v.Variant.." "..gid)
			elseif gid % wd == math.floor(wd/2) then
				auxi.check_if_any(info.Replace2Ent[v.Type],v,item)
				--print("Ent2:"..v.Type.." "..v.Variant)
			end
		end
		for i = 0,7 do
			local door = room:GetDoor(i)
			if door and info.ReloadDoor[i % 4] then
				auxi.copy_sprite(auxi.copy_sprite(door:GetSprite(),nil,{filename = info.ReloadDoor[i % 4],}),door:GetSprite(),{Play = true,PlayOverlay = true,})
			end
		end
	else
		local tbl = {}
		for i = 0,7 do
			local door = room:GetDoor(i)
			if door and item.Reloadname[door:GetSprite():GetFilename()] then
				auxi.copy_sprite(auxi.copy_sprite(door:GetSprite(),nil,{filename = item.Reloadname[door:GetSprite():GetFilename()],}),door:GetSprite(),{Play = true,PlayOverlay = true,})
				if door.TargetRoomIndex == -1 then table.insert(tbl,#tbl + 1,i) end
			end
		end
		if #tbl > 1 and auxi.get_player_have_collectible_num(498) == auxi.get_player_have_collectible_num(item.entity,nil,{counter = 1,}) then 
			for j = 2,#tbl do room:RemoveDoor(tbl[j]) end
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if auxi.have_player_has_collectible(item.entity) then 
		item.check_for_room()
	end
	item.record_option_index = nil
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,touched,curnum)
	if curnum == 0 then item.check_for_room() end
end,
})

--l local door = Game():GetRoom():GetDoor(i) print(door:GetSprite():GetFilename())

return item
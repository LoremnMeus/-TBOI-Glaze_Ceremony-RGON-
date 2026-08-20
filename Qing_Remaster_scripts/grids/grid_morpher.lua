local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local save = require("Qing_Remaster_scripts.core.savedata")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	myToCall = {},
	ToCall = {},
	grid_table = {},
	own_key = "grid_morpher",
	rock_grid = {
		[GridEntityType.GRID_ROCK] = {info = true,},
		[GridEntityType.GRID_ROCKB] = {info = true,replace_type = GridEntityType.GRID_ROCK,metal_sound = true,},		--
		[GridEntityType.GRID_ROCKT] = {info = true,},
		[GridEntityType.GRID_ROCK_BOMB] = {info = true,},
		[GridEntityType.GRID_ROCK_ALT] = {info = true,alt = true,},
		[GridEntityType.GRID_ROCK_SS] = {info = true,},
		[GridEntityType.GRID_ROCK_SPIKED] = {info = true,replace_type = GridEntityType.GRID_ROCK,metal_sound = true,},
		[GridEntityType.GRID_ROCK_ALT2] = {info = true,},
		[GridEntityType.GRID_ROCK_GOLD] = {info = true,},
		[GridEntityType.GRID_PILLAR] = {info = true,replace_type = GridEntityType.GRID_ROCK,},		--
		
		[GridEntityType.GRID_POOP] = {},
		[GridEntityType.GRID_LOCK] = {replace_type = GridEntityType.GRID_DECORATION,metal_sound = true,},		--
		[GridEntityType.GRID_TNT] = {},
		--[[
		[GridEntityType.GRID_SPIDERWEB] = true,
		[GridEntityType.GRID_STATUE] = true,
		--]]
	},
	room_rock_info = {
		[RoomType.ROOM_SHOP] = {name = "gfx/grid/rocks_basement.png",alt = 1,},
		[RoomType.ROOM_ERROR] = {name = "gfx/grid/rocks_basement.png",alt = 1,},
		[RoomType.ROOM_SECRET] = {name = "gfx/grid/rocks_secretroom.png",alt = 2,},
		[RoomType.ROOM_SUPERSECRET] = function(info) local ret = auxi.get_grid_by_backdrop_info() return info[ret.u][ret.v] or info[ret.u][0] or info[1][0] end,
		[RoomType.ROOM_ARCADE] = {name = "gfx/grid/rocks_basement.png",alt = 1,},
		[RoomType.ROOM_CURSE] = {name = "gfx/grid/rocks_sheol.png",alt = 3,},
		[RoomType.ROOM_SACRIFICE] = {name = "gfx/grid/rocks_sheol.png",alt = 3,},
		[RoomType.ROOM_DEVIL] = {name = "gfx/grid/rocks_sheol.png",alt = 3,},
		[RoomType.ROOM_ANGEL] = {name = "gfx/grid/rocks_cathedral.png",alt = 1,},
		[RoomType.ROOM_BOSSRUSH] = {name = "gfx/grid/rocks_depths.png",alt = 3,},
		[RoomType.ROOM_ISAACS] = {name = "gfx/grid/rocks_basement.png",alt = 1,},
		[RoomType.ROOM_BARREN] = {name = "gfx/grid/rocks_basement.png",alt = 1,},
		[RoomType.ROOM_CHEST] = {name = "gfx/grid/rocks_basement.png",alt = 1,},
		[RoomType.ROOM_DICE] = {name = "gfx/grid/rocks_basement.png",alt = 1,},
		[RoomType.ROOM_BLACK_MARKET] = {name = "gfx/grid/rocks_sheol.png",alt = 3,},
		[RoomType.ROOM_SECRET_EXIT] = function(info) print(Game():GetRoom():GetBackdropType()) end,
		[RoomType.ROOM_BLUE] = {name = "gfx/grid/rocks_bluewomb.png",alt = 4,},
	},
	rock_info = {
		[1] = {
			[0] = {name = "gfx/grid/rocks_basement.png",alt = 1,},
			[1] = {name = "gfx/grid/rocks_cellar.png",alt = 1,},
			[2] = {name = "gfx/grid/rocks_burningbasement.png",alt = 1,},
			[4] = {name = "gfx/grid/rocks_downpour.png",alt = 5,},
			[5] = {name = "gfx/grid/rocks_dross.png",alt = 6,},
		},
		[2] = {
			[0] = {name = "gfx/grid/rocks_caves.png",alt = 2,},
			[1] = {name = "gfx/grid/rocks_catacombs.png",alt = 2,},
			[2] = {name = "gfx/grid/rocks_drownedcaves.png",alt = 2,},
			[4] = {name = "gfx/grid/rocks_secretroom.png",alt = 2,},
			[5] = {name = "gfx/grid/rocks_ashpit.png",alt = 2,},
		},
		[3] = {
			[0] = {name = "gfx/grid/rocks_depths.png",alt = 3,},
			[1] = {name = "gfx/grid/rocks_depths.png",alt = 3,},
			[2] = {name = "gfx/grid/rocks_depths.png",alt = 3,},
			[4] = {name = "gfx/grid/rocks_mausoleum.png",alt = 3,},
			[5] = {name = "gfx/grid/rocks_gehenna.png",alt = 3,},
		},
		[4] = {
			[0] = {name = "gfx/grid/rocks_womb.png",alt = 4,},
			[1] = {name = "gfx/grid/rocks_utero.png",alt = 4,},
			[2] = {name = "gfx/grid/rocks_scarredwomb.png",alt = 4,},
			[4] = {name = "gfx/grid/rocks_corpse.png",alt = 4,},
			[5] = {name = "gfx/grid/rocks_corpse2.png",alt = 4,},
			[6] = {name = "gfx/grid/rocks_corpse3.png",alt = 4,},
			[7] = {name = "gfx/grid/rocks_corpseentrance.png",alt = 3,},
		},
		[5] = {
			[0] = {name = "gfx/grid/rocks_bluewomb.png",alt = 4,},
		},
		[6] = {
			[0] = {name = "gfx/grid/rocks_sheol.png",alt = 3,},
			[1] = {name = "gfx/grid/rocks_cathedral.png",alt = 1,},
		},
		[7] = {
			[0] = {name = "gfx/grid/rocks_sheol.png",alt = 3,},
			[1] = {name = "gfx/grid/rocks_cathedral.png",alt = 1,},
		},
		[8] = {
			[0] = function(info)
				local ret = auxi.get_grid_by_stage_info()
				return info[ret.u][ret.v] or info[ret.u][0] or info[1][0]
			end,
		},
		[9] = {
			[0] = {name = "gfx/grid/rocks_basement.png",alt = 1,},
		},
		[10] = {
			[0] = {name = "gfx/grid/rocks_basement.png",alt = 1,},
		},
		--rocks_secretroom
		--rocks_corpseentrance
	},
	poop_info = {
		[0] = function() return auxi.random_in_table({"gfx/grid/grid_poop_1.png","gfx/grid/grid_poop_2.png","gfx/grid/grid_poop_3.png",}) end,
		[1] = function() return auxi.random_in_table({"gfx/grid/grid_poop_red_1.png","gfx/grid/grid_poop_red_2.png","gfx/grid/grid_poop_red_3.png",}) end,
		[2] = "gfx/grid/grid_poop_corn.png",
		[3] = "gfx/grid/grid_poop_gold.png",
		[4] = "gfx/grid/grid_poop_rainbow.png",
		[5] = "gfx/grid/grid_poop_black.png",
		[6] = function() return auxi.random_in_table({"gfx/grid/grid_poop_white_1.png","gfx/grid/grid_poop_white_2.png","gfx/grid/grid_poop_white_3.png",}) end,
		
		[8] = "gfx/effects/nill.png",
		[9] = "gfx/effects/nill.png",
		[10] = "gfx/effects/nill.png",
		[11] = "gfx/grid/grid_poop_charming.png",
		[12] = "gfx/grid/grid_poop_stone.png",
		[13] = "gfx/grid/grid_poop_flaming.png",
		[14] = "gfx/grid/grid_poop_stinky.png",
	},
	alt_info = {
		[1] = {},
		[2] = {on_death = function(ent,info,item)
			local rnd = auxi.random_in_weighed_table(info.trails,ent:GetDropRNG())
			if rnd.work then rnd.work(ent,rnd,info,item) end
		end,particles = true,alt = true,sound = SoundEffect.SOUND_MUSHROOM_POOF_2,trails = {
			{work = function(ent,iinfo,info,item) Game():Fart(ent.Position,64,ent,1,0) end,weigh = 1933,},
			{work = function(ent,iinfo,info,item) local q = Isaac.Spawn(5,70,0,ent.Position,Vector(0,0),ent) end,weigh = 967,},
			{work = function(ent,iinfo,info,item) if save.elses[item.own_key.."effect"][3] == nil then local q = Isaac.Spawn(5,350,32,ent.Position,Vector(0,0),ent) end end,weigh = 250,},
			{work = function(ent,iinfo,info,item) if save.elses[item.own_key.."effect"][5] == nil then local q = Isaac.Spawn(5,100,12,Game():GetRoom():FindFreeTilePosition(ent.Position,10),Vector(0,0),ent) q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE) end end,weigh = 5,},
			{work = function(ent,iinfo,info,item) if save.elses[item.own_key.."effect"][7] == nil then local q = Isaac.Spawn(5,100,71,Game():GetRoom():FindFreeTilePosition(ent.Position,10),Vector(0,0),ent) q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE) end end,weigh = 5,},
			{work = function(ent,iinfo,info,item) local desc = Game():GetLevel():GetCurrentRoomDesc() if desc and desc.Data.Type == RoomType.ROOM_SECRET then local q = Isaac.Spawn(5,100,582,Game():GetRoom():FindFreeTilePosition(ent.Position,10),Vector(0,0),ent) q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE) end end,weigh = 1,},
			{weigh = 6839,},
		},},
		[3] = {on_death = function(ent,info,item)
			local rnd = auxi.random_in_weighed_table(info.trails,ent:GetDropRNG())
			if rnd.work then rnd.work(ent,rnd,info,item) end
		end,particles = true,alt = true,sound = SoundEffect.SOUND_ROCK_CRUMBLE,trails = {
			{work = function(ent,iinfo,info,item) local q = Isaac.Spawn(27,0,0,ent.Position,Vector(0,0),ent) end,weigh = 1933,},
			{work = function(ent,iinfo,info,item) local q = Isaac.Spawn(5,300,0,ent.Position,Vector(0,0),ent) end,weigh = 967,},
			{work = function(ent,iinfo,info,item) local q = Isaac.Spawn(5,10,6,ent.Position,Vector(0,0),ent) end,weigh = 250,},
			{work = function(ent,iinfo,info,item) if save.elses[item.own_key.."effect"][11] == nil then local q = Isaac.Spawn(5,100,265,Game():GetRoom():FindFreeTilePosition(ent.Position,10),Vector(0,0),ent) q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE) end end,weigh = 5,},
			{work = function(ent,iinfo,info,item) if save.elses[item.own_key.."effect"][8] == nil then local q = Isaac.Spawn(5,100,163,Game():GetRoom():FindFreeTilePosition(ent.Position,10),Vector(0,0),ent) q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE) end end,weigh = 5,},
			{weigh = 6840,},
		},},
		[4] = {on_death = function(ent,info,item)
			local rnd = auxi.random_in_weighed_table(info.trails,ent:GetDropRNG())
			if rnd.work then rnd.work(ent,rnd,info,item) end
		end,particles = true,alt = true,sound = SoundEffect.SOUND_MEATY_DEATHS,trails = {
		--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 9 then v = v:ToProjectile() print(v.Velocity) print(v.Velocity:Length()) print(v.Height) end end
		--l local q = Isaac.Spawn(9,0,0,Vector(200,200),Vector(0,10),nil):ToProjectile() q.Height = -26.4952
			{work = function(ent,iinfo,info,item) local dir = math.random(360) for i = 1,6 do local q = Isaac.Spawn(9,0,0,ent.Position,10 * auxi.MakeVector(dir + i * 360/6),nil):ToProjectile() q.Height = -26.4952 end local q = Isaac.Spawn(1000,22,0,ent.Position,Vector(0,0),nil) end,weigh = 1932,},
			{work = function(ent,iinfo,info,item) local q = Isaac.Spawn(5,10,auxi.random_in_table({1,2,}),ent.Position,Vector(0,0),ent) end,weigh = 968,},
			{work = function(ent,iinfo,info,item) if save.elses[item.own_key.."effect"][4] == nil then local q = Isaac.Spawn(5,350,33,ent.Position,Vector(0,0),ent) end end,weigh = 250,},
			{work = function(ent,iinfo,info,item) if save.elses[item.own_key.."effect"][10] == nil then local q = Isaac.Spawn(5,100,254,Game():GetRoom():FindFreeTilePosition(ent.Position,10),Vector(0,0),ent) q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE) end end,weigh = 5,},
			{work = function(ent,iinfo,info,item) if save.elses[item.own_key.."effect"][9] == nil then local q = Isaac.Spawn(5,100,218,Game():GetRoom():FindFreeTilePosition(ent.Position,10),Vector(0,0),ent) q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE) end end,weigh = 5,},
			{weigh = 6840,},
		},},
		[5] = {on_death = function(ent,info,item)
			local rnd = auxi.random_in_weighed_table(info.trails,ent:GetDropRNG())
			if rnd.work then rnd.work(ent,rnd,info,item) end
		end,particles = true,alt = true,sound = SoundEffect.SOUND_POT_BREAK,trails = {
		--l local q = Isaac.Spawn(5,20,0,Vector(200,200),math.random(1000)/1000 * 3,nil)
		--l local q = Isaac.Spawn(870,0,0,Vector(200,200),Vector(0,0),nil):ToNPC() local cnt = 0 while(q.State ~= 4 and cnt < 20) do q:Update() cnt = cnt + 1 end
		--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 87 then print(v.State) end end
		--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local q = EntityNPC.ThrowSpider(Vector(200,200), nil, Vector(200,200) + auxi.MakeVector(math.random(360)) * math.random(8,35), false, -100) q:ToNPC():Morph(810,0,0,-1) print(q.Velocity) --q.Velocity = auxi.MakeVector(math.random(360)) * math.random(8,35) / 10
			{work = function(ent,iinfo,info,item) local mul = math.random(2) local tp = auxi.random_in_table({814,810,},ent:GetDropRNG()) for i = 1,mul do local q = EntityNPC.ThrowSpider(ent.Position,nil,ent.Position + auxi.MakeVector(math.random(360)) * math.random(8,35), false, -(math.random(40) + 40)) q:ToNPC():Morph(tp,0,0,-1) end end,weigh = 1933,},
			{work = function(ent,iinfo,info,item) local mul = math.random(2) for i = 1,mul do local q = Isaac.Spawn(5,20,0,ent.Position,auxi.MakeVector(math.random(360)) * math.random(1000)/1000 * 3,ent) end end,weigh = 967,},
			{work = function(ent,iinfo,info,item) if save.elses[item.own_key.."effect"][1] == nil then local q = Isaac.Spawn(5,350,1,ent.Position,Vector(0,0),ent) end end,weigh = 250,},
			{work = function(ent,iinfo,info,item) if save.elses[item.own_key.."effect"][12] == nil then local q = Isaac.Spawn(5,100,270,Game():GetRoom():FindFreeTilePosition(ent.Position,10),Vector(0,0),ent) q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE) end end,weigh = 5,},
			{weigh = 6845,},
		},},
		[6] = {on_death = function(ent,info,item)
			local rnd = auxi.random_in_weighed_table(info.trails,ent:GetDropRNG())
			if rnd.work then rnd.work(ent,rnd,info,item) end
		end,particles = true,alt = true,sound = SoundEffect.SOUND_POT_BREAK,trails = {
			{work = function(ent,iinfo,info,item) local mul = math.random(2) local q = Isaac.Spawn(870,0,0,ent.Position,Vector(0,0),nil):ToNPC() local cnt = 0 while(q.State ~= 4 and cnt < 20) do q:Update() cnt = cnt + 1 end end,weigh = 1932,},
			{work = function(ent,iinfo,info,item) local mul = math.random(2) for i = 1,mul do local q = Isaac.Spawn(5,20,0,ent.Position,auxi.MakeVector(math.random(360)) * math.random(1000)/1000 * 3,ent) end end,weigh = 968,},
			{work = function(ent,iinfo,info,item) if save.elses[item.own_key.."effect"][2] == nil then local q = Isaac.Spawn(5,350,24,ent.Position,Vector(0,0),ent) end end,weigh = 250,},
			{work = function(ent,iinfo,info,item) if save.elses[item.own_key.."effect"][6] == nil then local q = Isaac.Spawn(5,100,36,Game():GetRoom():FindFreeTilePosition(ent.Position,10),Vector(0,0),ent) q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE) end end,weigh = 5,},
			{weigh = 6845,},
		},},
	},
	trinket_record = {
		[1] = 1,
		[24] = 2,
		[32] = 3,
		[33] = 4,
	},
	item_record = {
		[12] = 5,
		[36] = 6,
		[71] = 7,
		[163] = 8,
		[218] = 9,
		[254] = 10,
		[265] = 11,
		[270] = 12,
	},
}

function item.get_morph_dir()
	--[[
	local lev = auxi.get_level_door_info()
	local lvtp = Game():GetLevel():GetStageType()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local rk_info = auxi.check_if_any(item.rock_info[lev][lvtp],item.rock_info) or auxi.check_if_any(item.rock_info[lev][0],item.rock_info) or item.rock_info[1][0]
	if item.room_rock_info[desc.Data.Type] then rk_info = auxi.check_if_any(item.room_rock_info[desc.Data.Type],item.rock_info) or rk_info end
	--]]
	local ret = auxi.get_grid_by_backdrop_info()
	local rk_info = auxi.check_if_any(item.rock_info[ret.u][ret.v],item.rock_info) or auxi.check_if_any(item.rock_info[ret.u][0],item.rock_info) or item.rock_info[1][0]
	return rk_info
end

function item.morph_info(info,params)
	params = params or {}
	local rk_info = params.rk_info or item.get_morph_dir()
	local rgridType = info.tp
	local gridType = rgridType
	local grid_info = item.rock_grid[gridType] or {}
	local s = auxi.table2sprite(info.s)
	local gridAnim = s:GetAnimation()
	local now_grid_info = nil
	if grid_info.replace_type then gridType = auxi.check_if_any(grid_info.replace_type,grid_info) end
	local gridFrame = s:GetFrame()
	if gridAnim == "big" then
		gridAnim = "normal"
		gridFrame = math.random(3)
	end
	if rgridType == GridEntityType.GRID_POOP then
		gridFrame = info.Variant
		now_grid_info = auxi.check_if_any(item.poop_info[gridFrame],item.poop_info)
	end
	if rgridType == GridEntityType.GRID_ROCK_ALT and item.alt_info[rk_info.alt or 1].alt then gridType = GridEntityType.GRID_ROCKB end
	local q = params.ent
	if params.anti then q = q or Isaac.Spawn(9,8,(gridType * 65536) + gridFrame,params.pos or auxi.ProtectVector(info.Position),params.vel or Vector(0,0),params.spawner):ToProjectile()
	else q = q or Isaac.Spawn(2,40,(gridType * 65536) + gridFrame,params.pos or auxi.ProtectVector(info.Position),params.vel or Vector(0,0),params.spawner):ToTear() end
	auxi.copy_sprite(s,q:GetSprite())
	local d = q:GetData()
	local s2 = q:GetSprite()
	if s2:GetAnimation() == "Appear" then s2:SetLastFrame() end
	if grid_info.info then s2:ReplaceSpritesheet(0,rk_info.name) s2:LoadGraphics() end
	if grid_info.alt then d[item.own_key.."rk_info"] = rk_info end
	if grid_info.metal_sound then d[item.own_key.."metal_sound"] = true end
	if now_grid_info then s2:ReplaceSpritesheet(0,now_grid_info) s2:LoadGraphics() end
	return q
end

function item.gent2info(gent)
	local ret = {Type = 1001,tp = gent:GetType(),Variant = gent:GetVariant(),SubType = 0,Position = auxi.Vector2Table(gent.Position),s = auxi.sprite2table(gent:GetSprite()),}
	return ret
end

function item.morph_grid(gent,params)
	if gent == nil then return end
	params = params or {}
	local rk_info = params.rk_info or item.get_morph_dir()
	local rgridType = gent:GetType()
	local gridType = rgridType
	local grid_info = item.rock_grid[gridType] or {}
	local s = gent:GetSprite()
	local gridAnim = s:GetAnimation()
	local now_grid_info = nil
	if grid_info.replace_type then gridType = auxi.check_if_any(grid_info.replace_type,grid_info) end
	local gridFrame = s:GetFrame()
	if gridAnim == "big" then
		gridAnim = "normal"
		gridFrame = math.random(3)
	end
	if rgridType == GridEntityType.GRID_POOP then
		gridFrame = gent:GetVariant()
		now_grid_info = auxi.check_if_any(item.poop_info[gridFrame],item.poop_info)
	end
	if rgridType == GridEntityType.GRID_ROCK_ALT and item.alt_info[rk_info.alt or 1].alt then gridType = GridEntityType.GRID_ROCKB end
	local q = params.ent
	if params.anti then q = q or Isaac.Spawn(9,8,(gridType * 65536) + gridFrame,params.pos or gent.Position,params.vel or Vector(0,0),params.spawner):ToProjectile()
	else q = q or Isaac.Spawn(2,40,(gridType * 65536) + gridFrame,params.pos or gent.Position,params.vel or Vector(0,0),params.spawner):ToTear() end
	auxi.copy_sprite(s,q:GetSprite())
	local d = q:GetData()
	local s2 = q:GetSprite()
	if s2:GetAnimation() == "Appear" then s2:SetLastFrame() end
	if grid_info.info then s2:ReplaceSpritesheet(0,rk_info.name) s2:LoadGraphics() end
	if grid_info.alt then d[item.own_key.."rk_info"] = rk_info end
	if grid_info.metal_sound then d[item.own_key.."metal_sound"] = true end
	if now_grid_info then s2:ReplaceSpritesheet(0,now_grid_info) s2:LoadGraphics() end
	return q
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

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 350,
Function = function(_,ent)
	local id = auxi.check_if_any(item.trinket_record[ent.SubType],ent)
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	if id then save.elses[item.own_key.."effect"][id] = true end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 100,
Function = function(_,ent)
	local id = auxi.check_if_any(item.item_record[ent.SubType],ent)
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	if id then save.elses[item.own_key.."effect"][id] = true end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = 40,
Function = function(_,ent)
	if ent:IsDead() then
		local d = ent:GetData()
		if d[item.own_key.."rk_info"] then
			local alt_info = item.alt_info[d[item.own_key.."rk_info"].alt or 1]
			if alt_info.on_death then alt_info.on_death(ent,alt_info,item) end
			if alt_info.particles then
				local d = ent:GetData()
				for i = 1,4 do
					--l local q = Isaac.Spawn(1000, 4, 1, Vector(200,200),Vector(0,0),nil) q:Update() local s2 = q:GetSprite() s2:SetFrame("rubble_alt",math.random(4) - 1) q:Update()
					local q = Isaac.Spawn(1000, 4, 0, ent.Position, auxi.MakeVector(math.random(360)) * math.random(8,35) / 10, ent)
					local s2 = q:GetSprite()
					s2:ReplaceSpritesheet(0,d[item.own_key.."rk_info"].name or "gfx/grid/rocks_basement.png")
					s2:LoadGraphics()
					s2.Rotation = math.random(360)
					q:Update()
					s2:SetFrame("rubble_alt",math.random(4) - 1)
				end
			end
			if alt_info.sound then sound_tracker.PlayStackedSound(alt_info.sound,1,1,false,0,2)	end
		end
		if d[item.own_key.."metal_sound"] then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_METAL_BLOCKBREAK,1,1,false,0,2)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PROJECTILE_UPDATE, params = 8,
Function = function(_,ent)
	if ent:IsDead() then
		local d = ent:GetData()
		if d[item.own_key.."rk_info"] then
			local alt_info = item.alt_info[d[item.own_key.."rk_info"].alt or 1]
			if alt_info.on_death then alt_info.on_death(ent,alt_info,item) end
			if alt_info.particles then
				local d = ent:GetData()
				for i = 1,4 do
					--l local q = Isaac.Spawn(1000, 4, 1, Vector(200,200),Vector(0,0),nil) q:Update() local s2 = q:GetSprite() s2:SetFrame("rubble_alt",math.random(4) - 1) q:Update()
					local q = Isaac.Spawn(1000, 4, 0, ent.Position, auxi.MakeVector(math.random(360)) * math.random(8,35) / 10, ent)
					local s2 = q:GetSprite()
					s2:ReplaceSpritesheet(0,d[item.own_key.."rk_info"].name or "gfx/grid/rocks_basement.png")
					s2:LoadGraphics()
					s2.Rotation = math.random(360)
					q:Update()
					s2:SetFrame("rubble_alt",math.random(4) - 1)
				end
			end
			if alt_info.sound then sound_tracker.PlayStackedSound(alt_info.sound,1,1,false,0,2)	end
		end
		if d[item.own_key.."metal_sound"] then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_METAL_BLOCKBREAK,1,1,false,0,2)
		end
	end
end,
})

return item
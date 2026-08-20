local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local card_01_wizard = require("Qing_Remaster_scripts.cards.Card_01_Wizard")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Emperor,
	own_key = "Thoth_cd4_Emp_",
	allow_grid = {
		[GridEntityType.GRID_DECORATION] = true,
		[GridEntityType.GRID_SPIKES] = true,
		[GridEntityType.GRID_SPIKES_ONOFF] = true,
		[GridEntityType.GRID_SPIDERWEB] = true,
		[GridEntityType.GRID_TNT] = true,
		[GridEntityType.GRID_POOP] = true,
		[GridEntityType.GRID_TRAPDOOR] = true,
		[GridEntityType.GRID_STAIRS] = true,
		[GridEntityType.GRID_PRESSURE_PLATE] = true,
		[GridEntityType.GRID_TELEPORTER] = true,
		
		[GridEntityType.GRID_PIT] = function(player) if player.CanFly then return true end end,
		[GridEntityType.GRID_ROCK] = function(player) if player.CanFly then return true end end,
		[GridEntityType.GRID_ROCKB] = function(player) if player.CanFly then return true end end,
		[GridEntityType.GRID_ROCKT] = function(player) if player.CanFly then return true end end,
		[GridEntityType.GRID_ROCK_BOMB] = function(player) if player.CanFly then return true end end,
		[GridEntityType.GRID_ROCK_ALT] = function(player) if player.CanFly then return true end end,
		[GridEntityType.GRID_ROCK_SS] = function(player) if player.CanFly then return true end end,
		[GridEntityType.GRID_ROCK_SPIKED] = function(player) if player.CanFly then return true end end,
		[GridEntityType.GRID_ROCK_ALT2] = function(player) if player.CanFly then return true end end,
		[GridEntityType.GRID_ROCK_GOLD] = function(player) if player.CanFly then return true end end,
	},
	secret_doors = {
		["gfx/grid/door_08_holeinwall _darkroom.anm2"] = true,
		["gfx/grid/Door_08_HoleInWall.anm2"] = true,
	},
	special_doors = {
		[1] = {id = -7,tp = 105,},
		[2] = {id = -5,tp = 17,},
	},
	other_doors = {
		[1] = {id = -1,special = function() 
			local desc = Game():GetLevel():GetRoomByIdx(-1) 
			if desc.Data == nil then Game():GetLevel():InitializeDevilAngelRoom(false,false) end
		end,tp = function() 
			local desc = Game():GetLevel():GetRoomByIdx(-1)
			return desc.Data.Type
		end,},
		[2] = {id = -2,tp = 3,},
		[3] = {id = -4,tp = 16,},
		[5] = {id = -6,tp = 22,},
		[7] = {id = -13,tp = 16,},
		[8] = {id = -18,tp = 15,},
	},
	--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local s = Sprite() s:Load("gfx/grid/door_01_normaldoor.anm2",true) s:Play("Opened",true) auxi.PrintKColor(s:GetTexel(Vector(0,0),Vector(0,0),1))
	--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local q = auxi.fire_nil(Vector(160,120),Vector(0,0),{cooldown = 6 * 30,}) q:AddEntityFlags(EntityFlag.FLAG_RENDER_WALL | EntityFlag.FLAG_RENDER_FLOOR | EntityFlag.FLAG_NO_REMOVE_ON_TEX_RENDER) local s = q:GetSprite() s.Offset = Vector(0,15) s:Load("gfx/grid/door_01_normaldoor.anm2",true) for i = 0,4 do s:ReplaceSpritesheet(i,"gfx/grid/door_27_drownedcaves.png") end s:LoadGraphics() s:Play("Opened",true) auxi.PrintKColor(s:GetTexel(Vector(0,0),Vector(0,0),1))
	--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if (v.Position - Vector(160,120)):Length() < 40 then print(1) end end
	--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local room = Game():GetRoom() for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do local door = room:GetDoor(slot) if door then local s = door:GetSprite() auxi.PrintKColor(s:GetTexel(Vector(0,0),Vector(0,0),1)) end end
	--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local room = Game():GetRoom() for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do local door = room:GetDoor(slot) if door then local s = door:GetSprite() print(s:GetFileName()) end end
	door_type_infos = {
		[1] = {
			door_name = function(info)
				local lev = auxi.get_level_door_info()
				if lev == 9 then return "gfx/grid/door_house.anm2" end
				return "gfx/grid/door_01_normaldoor.anm2"
			end,
			load_name = function(info)
				local lev = auxi.get_level_door_info()
				local lvtp = Game():GetLevel():GetStageType()
				return auxi.check_if_any(info.refer_map[lev][lvtp],info.refer_map[lev])
			end,
			refer_map = {
				[1] = {
					[0] = "gfx/grid/door_01_normaldoor.png",
					[1] = "gfx/grid/door_12_cellardoor.png",
					[2] = "gfx/grid/door_01_burningbasement.png",
					[4] = "gfx/grid/door_01_normaldoor.png",
					[5] = "gfx/grid/door_01_corpsedoor.png",
				},
				[2] = {
					[2] = "gfx/grid/door_27_drownedcaves.png",
					[4] = "gfx/grid/door_01_minesdoor.png",
					[5] = "gfx/grid/door_01_corpse2door.png",
				},
				[3] = {
					[0] = "gfx/grid/door_14_depthsdoor.png",
					[1] = "gfx/grid/door_14_depthsdoor.png",
					[2] = "gfx/grid/door_14_depthsdoor.png",
					[4] = "gfx/grid/door_01_mausoleumdoor.png",
					[5] = "gfx/grid/door_01_gehennadoor.png",
				},
				[4] = {
					[0] = "gfx/grid/door_25_wombdoor.png",
					[1] = "gfx/grid/door_25_wombdoor.png",
					[2] = "gfx/grid/door_28_scarredroomdoor.png",
					[4] = "gfx/grid/door_01_corpsedoor.png",
					[5] = "gfx/grid/door_01_corpse2door.png",
				},
				[5] = {
					[0] = "gfx/grid/door_01_bluewombdoor.png",
				},
				[6] = {
					[0] = "gfx/grid/door_19_sheoldoor.png",
					[1] = "gfx/grid/door_22_cathedraldoor.png",
				},
				[7] = {
					[0] = "gfx/grid/door_21_darkroomdoor.png",
					[1] = "gfx/grid/door_23_chestdoor.png",
				},
				[8] = {
					[0] = function(info)
						return auxi.random_in_table(info.tbl)
					end,
					tbl = {
						"gfx/grid/door_01_normaldoor.png",
						"gfx/grid/door_12_cellardoor.png",
						"gfx/grid/door_01_burningbasement.png",
						"gfx/grid/door_27_drownedcaves.png",
						"gfx/grid/door_01_minesdoor.png",
						"gfx/grid/door_01_corpse2door.png",
						"gfx/grid/door_14_depthsdoor.png",
						"gfx/grid/door_01_mausoleumdoor.png",
						"gfx/grid/door_01_gehennadoor.png",
						"gfx/grid/door_25_wombdoor.png",
						"gfx/grid/door_28_scarredroomdoor.png",
						"gfx/grid/door_01_corpsedoor.png",
						"gfx/grid/door_01_corpse2door.png",
						"gfx/grid/door_01_bluewombdoor.png",
						"gfx/grid/door_19_sheoldoor.png",
						"gfx/grid/door_22_cathedraldoor.png",
						"gfx/grid/door_21_darkroomdoor.png",
						"gfx/grid/door_23_chestdoor.png",
					},
				},
				[9] = {
					
				},
				[10] = {
					[0] = "gfx/grid/door_00_shopdoor.png",
				},
			},
		},
		[2] = {
			door_name = "gfx/grid/door_01_normaldoor.anm2",
			load_name = "gfx/grid/door_00_shopdoor.png",
		},
		[3] = {
			door_name = "gfx/grid/door_01x_ghostexit.anm2",
		},
		[4] = {
			door_name = "gfx/grid/door_02_treasureroomdoor.anm2",
		},
		[5] = {
			door_name = "gfx/grid/door_10_bossroomdoor.anm2",
		},
		[7] = {
			door_name = function(info)
				local lev = auxi.get_level_door_info()
				local lvtp = Game():GetLevel():GetStageType()
				if lev == 7 and lvtp == 0 then return "gfx/grid/door_08_holeinwall _darkroom.anm2"
				else return "gfx/grid/door_08_holeinwall.anm2" end
			end,
			load_name = function(info)
				local lev = auxi.get_level_door_info()
				local lvtp = Game():GetLevel():GetStageType()
				if lev == 2 and lvtp <= 3 then return "gfx/grid/door_08_holeinwall_caves.png" end
				if lev == 3 and lvtp <= 3 then return "gfx/grid/door_08_holeinwall_depths.png" end
				if lev == 4 and lvtp == 0 then return "gfx/grid/door_08_holeinwall_womb.png" end
				if lev == 4 and lvtp == 1 then return "gfx/grid/door_08_holeinwall_utero.png" end
				if lev == 4 and lvtp > 3 then return "gfx/grid/door_08_holeinwall_corpse.png" end
				if lev == 6 and lvtp == 1 then return "gfx/grid/door_08_holeinwall_cathedral.png" end
				if lev == 6 and lvtp == 0 then return "gfx/grid/door_08_holeinwall_depths.png" end
				if lev == 7 and lvtp == 0 then return "gfx/grid/door_08_holeinwall_darkroom.png" end
			end,
			offset = 5,
		},
		[8] = {
			door_name = function(info)
				local lev = auxi.get_level_door_info()
				local lvtp = Game():GetLevel():GetStageType()
				if lev == 7 and lvtp == 0 then return "gfx/grid/door_08_holeinwall _darkroom.anm2"
				else return "gfx/grid/door_08_holeinwall.anm2" end
			end,
			load_name = function(info)
				local lev = auxi.get_level_door_info()
				local lvtp = Game():GetLevel():GetStageType()
				if lev == 2 and lvtp <= 3 then return "gfx/grid/door_08_holeinwall_caves.png" end
				if lev == 3 and lvtp <= 3 then return "gfx/grid/door_08_holeinwall_depths.png" end
				if lev == 4 and lvtp == 0 then return "gfx/grid/door_08_holeinwall_womb.png" end
				if lev == 4 and lvtp == 1 then return "gfx/grid/door_08_holeinwall_utero.png" end
				if lev == 4 and lvtp > 3 then return "gfx/grid/door_08_holeinwall_corpse.png" end
				if lev == 6 and lvtp == 1 then return "gfx/grid/door_08_holeinwall_cathedral.png" end
				if lev == 6 and lvtp == 0 then return "gfx/grid/door_08_holeinwall_depths.png" end
				if lev == 7 and lvtp == 0 then return "gfx/grid/door_08_holeinwall_darkroom.png" end
			end,
			offset = 5,
		},
		[9] = {
			door_name = "gfx/grid/door_05_arcaderoomdoor.anm2",
		},
		[10] = {
			door_name = "gfx/grid/door_04_selfsacrificeroomdoor.anm2",
			load_name = function(info)
				if auxi.have_player_has_trinket(TrinketType.TRINKET_FLAT_FILE) then
					return "gfx/grid/door_04_selfsacrificeroomdoor_nospikes.png"
				end
			end,
			dmgself = function(info)
				if auxi.have_player_has_trinket(TrinketType.TRINKET_FLAT_FILE) then
				else
					return true
				end
			end,
		},
		[11] = {
			door_name = "gfx/grid/door_01_normaldoor.anm2",
			load_name = function(info)
				if Game():GetLevel():HasBossChallenge() then 
					return "gfx/grid/door_09_bossambushroomdoor.png"
				else
					return "gfx/grid/door_03_ambushroomdoor.png"
				end
			end,
		},
		[12] = {
			door_name = "gfx/grid/door_01_normaldoor.anm2",
			load_name = "gfx/grid/door_13_librarydoor.png",
		},
		[13] = {
			door_name = "gfx/grid/door_01_normaldoor.anm2",
			load_name = "gfx/grid/door_00_sacrificeroomdoor.png",
		},
		[14] = {
			door_name = "gfx/grid/door_07_devilroomdoor.anm2",
		},
		[15] = {
			door_name = "gfx/grid/door_07_holyroomdoor.anm2",
		},
		[16] = {
			door_name = function(info)
				local lev = auxi.get_level_door_info()
				local lvtp = Game():GetLevel():GetStageType()
				if lev == 7 and lvtp == 0 then return "gfx/grid/door_08_holeinwall _darkroom.anm2"
				else return "gfx/grid/door_08_holeinwall.anm2" end
			end,
			load_name = function(info)
				local lev = auxi.get_level_door_info()
				local lvtp = Game():GetLevel():GetStageType()
				if lev == 2 and lvtp <= 3 then return "gfx/grid/door_08_holeinwall_caves.png" end
				if lev == 3 and lvtp <= 3 then return "gfx/grid/door_08_holeinwall_depths.png" end
				if lev == 4 and lvtp == 0 then return "gfx/grid/door_08_holeinwall_womb.png" end
				if lev == 4 and lvtp == 1 then return "gfx/grid/door_08_holeinwall_utero.png" end
				if lev == 4 and lvtp > 3 then return "gfx/grid/door_08_holeinwall_corpse.png" end
				if lev == 6 and lvtp == 1 then return "gfx/grid/door_08_holeinwall_cathedral.png" end
				if lev == 6 and lvtp == 0 then return "gfx/grid/door_08_holeinwall_depths.png" end
				if lev == 7 and lvtp == 0 then return "gfx/grid/door_08_holeinwall_darkroom.png" end
			end,
			offset = 5,
		},
		[17] = {
			door_name = "gfx/grid/door_15_bossrushdoor.anm2",
		},
		[18] = {
			door_name = "gfx/grid/door_house.anm2",
		},
		[19] = {
			door_name = "gfx/grid/door_house.anm2",
			load_name = "gfx/grid/door_house_cracked.png",
		},
		[20] = {
			door_name = "gfx/grid/door_01_normaldoor.anm2",
			load_name = "gfx/grid/door_02b_chestroomdoor.png",
		},
		[21] = {
			door_name = "gfx/grid/door_01_normaldoor.anm2",
			load_name = "gfx/grid/door_00_diceroomdoor.png",
		},
		[22] = {
			door_name = "gfx/grid/door_01_normaldoor.anm2",
			load_name = "gfx/grid/door_19_sheoldoor.png",
		},
		[23] = {
			door_name = "gfx/grid/door_32_exitdoor.anm2",
		},
		[24] = {
			door_name = "gfx/grid/door_00x_planetariumdoor.anm2",
		},
		[27] = {
			door_name = function(info) 
				local info = info.door_maps[auxi.get_special_door_id() or 1]
				return info
			end,
			door_maps = {
				[1] = "gfx/grid/door_downpour.anm2",
				[2] = "gfx/grid/door_mines.anm2",
				[3] = "gfx/grid/door_mausoleum.anm2",
				[4] = "gfx/grid/door_mausoleum_alt.anm2",
				[5] = "gfx/grid/door_momsheart.anm2",
			},
			door_map2 = {
				[1] = "gfx/grid/door_downpour_mirror.anm2",
				[2] = "gfx/grid/door_mines_mineshaft_dark.anm2",
			},
		},
		[29] = {
			door_name = "gfx/grid/door_01_normaldoor.anm2",
			load_name = "gfx/grid/door_00_reddoor.png",
		},
		[105] = {
			door_name = "gfx/grid/door_24_megasatandoor.anm2",
		},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	if save.elses[item.own_key.."effect"] then
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if (door) then
				local s = door:GetSprite()
				if s:IsFinished("Hidden") then
				elseif item.secret_doors[s:GetFilename()] then
					s:Play("Close",true) 
					s:SetLastFrame()
				else 
					s:Play("Closed",true)
				end
				door.CollisionClass = GridCollisionClass.COLLISION_WALL
			end
		end
	end
end,
})

function item.open_doors(player,params)
	player = player or Game():GetPlayer(0)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	params = params or {}
	if params.DontClose ~= true then save.elses[item.own_key.."effect"] = true end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_DOOR_HEAVY_OPEN,1,1,false,0,2)
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local size = room:GetGridSize()
	local dir_j = room:GetGridWidth()
	local dirs = {[0] = {delta = 1,dir = 0,},[1] = {delta = dir_j,dir = 1,},[2] = {delta = -1,dir = 2,},[3] = {delta = -dir_j,dir = 3,},}
	local succ_tbl = {}
	local thre = params.thre or 950
	for i = 0,size - 1 do
		local gent = room:GetGridEntity(i)
		if gent and gent:GetType() == GridEntityType.GRID_WALL and room:IsPositionInRoom(room:GetGridPosition(i),0) == false then
			local dirinfo = nil
			for u,dir in pairs(dirs) do
				local iidx = i + dir.delta
				if room:IsPositionInRoom(room:GetGridPosition(iidx),0) then
					local gent = room:GetGridEntity(iidx)
					if gent == nil or auxi.check_if_any(item.allow_grid[gent:GetType()],player) then
						dirinfo = dir
						break
					end
				end
			end
			if dirinfo then
				succ_tbl[i] = {dir = dirinfo.dir,id = i,}
			end
		end
	end
	local cnt = 0
	if not ((level:IsAscent() or auxi.get_level_door_info() == 9)) then
		local mxn = 2
		if auxi.get_level_door_info() == 5 then mxn = 1 end
		for u,v in pairs(succ_tbl) do
			local near_dirs = {dirs[(v.dir + 3) % 4],dirs[(v.dir + 1) % 4]}
			local should_work = true
			for uu,vv in pairs(near_dirs) do
				if (succ_tbl[vv.delta + u] or {}).dir ~= v.dir then should_work = false break end
			end
			if should_work then
				if rng:RandomInt(1000) > thre then 
					for uu,vv in pairs(near_dirs) do
						succ_tbl[vv.delta + u] = nil
					end
					v.special_door = true
					cnt = cnt + 1
					if cnt >= mxn then break end
				end
			end
		end
	end
	if params.special then 
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local pos = room:GetDoorSlotPosition(slot)
			local iidx = room:GetGridIndex(pos)
			succ_tbl[iidx] = nil
		end
	end
	local room_tbl = {}
	local dimen = auxi.GetDimension()
	for i = 1, rooms.Size do
		local targ = rooms:Get(i - 1)
		if targ and dimen == auxi.GetDimension(targ) then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex)
			if desc then
				local tp = desc.Data.Type
				table.insert(room_tbl,#room_tbl + 1,{id = i,tp = tp,gidx = targ.SafeGridIndex,})
			end
		end
	end
	for u,v in pairs(item.other_doors) do
		if math.random(1000) > thre then
			if v.special then v.special() end
			table.insert(room_tbl,#room_tbl + 1,{id = nil,tp = auxi.check_if_any(v.tp,nil),gidx = v.id,})
		end
	end
	local special_tbl = auxi.randomTable({1,2,},rng)
	if params.special then succ_tbl = auxi.randomOverTable(succ_tbl,rng) end
	--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") auxi.PrintTable(auxi.randomOverTable({[3] = 1,[5] = 3,})) auxi.PrintTable(auxi.randomTable({1,2,3,}))
	for u,v in pairs(succ_tbl) do
		if v.special_door then
			local door_info = item.special_doors[special_tbl[1]]
			table.remove(special_tbl,1)
			if auxi.get_level_door_info() == 5 then door_info = item.special_doors[1] end
			grid_door.try_spawn_grid_door(room,nil,v.id,{check_and_leave = function(doorinfo,player)
				Room_holder.Trans_to(door_info.id,Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player)
			end,should_update = true,loadname = item.door_type_infos[door_info.tp].door_name,playname = "Opened",dir = v.dir,})
		else
			local rnd = auxi.random_in_table(room_tbl,rng)
			if rnd then
				local door_info = item.door_type_infos[rnd.tp] or item.door_type_infos[1]
				local dmgself = auxi.check_if_any(door_info.dmgself,nil)
				grid_door.try_spawn_grid_door(room,nil,v.id,{check_and_leave = function(doorinfo,player)
					if dmgself and player.CanFly == false then player:TakeDamage(1,DamageFlag.DAMAGE_CURSED_DOOR | DamageFlag.DAMAGE_NO_PENALTIES,EntityRef(player),30) end
					Room_holder.Trans_to(rnd.gidx,Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player)
					if rnd.gidx == -6 then
						delay_buffer.addeffe(function(params)
							card_01_wizard.spawn_a_fool_port(Vector(320,280))
						end,{},1)
					elseif rnd.gidx == -7 then
						delay_buffer.addeffe(function(params)
							local room = Game():GetRoom()
							if room:IsClear() then
								card_01_wizard.spawn_a_fool_port(room:GetCenterPos())
							end
						end,{},1)
					end
				end,should_update = true,loadname = auxi.check_if_any(door_info.door_name,door_info),playname = "Opened",dir = v.dir,on_render = true,spritename = auxi.check_if_any(door_info.load_name,door_info),mov = door_info.offset,scale = Vector(0.8,0.8),inner = 10,})
			end
		end
		if params.special then 
			params.special = (params.special or 0) - 1
			if params.special <= 0 then return end
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local d = player:GetData()
	local idx = d.__Index
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local thre = 950
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then thre = 0 end
		item.open_doors(player,{thre = thre,})
	end
end,
})


return item

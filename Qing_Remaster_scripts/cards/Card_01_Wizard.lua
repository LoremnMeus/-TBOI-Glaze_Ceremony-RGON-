local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Wizard,
	own_key = "Thoth_cd1_Wiz_",
	offset_info = {
		[1] = Vector(0,-60),
		[2] = Vector(40,-40),
		[3] = Vector(-40,-40),
	},
	tarot_buffs = {
		[1] = {id = -1,special = function() 
			local desc = Game():GetLevel():GetRoomByIdx(-1) 
			if desc.Data == nil then Game():GetLevel():InitializeDevilAngelRoom(false,false) end
		end,tp = function() 
			local desc = Game():GetLevel():GetRoomByIdx(-1)
			return desc.Data.Type
		end,},
		[2] = {id = -2,tp = 3,},
		[3] = {id = -4,tp = 16,},
		[4] = {id = -5,tp = 17,ignore_ascent = true,ignore_hush = true,},
		[5] = {id = -6,tp = 22,},
		[6] = {id = -7,tp = 114,replace_tp = 30,ignore_ascent = true,},
		[7] = {id = -13,tp = 116,replace_tp = 31,},
		[8] = {id = -18,tp = 115,replace_tp = 32,},
	},
	port_desc = {
		["zh_cn"] = {
			[2] = {Name = "商店传送旋涡",Description = "#{{Shop}} 将你传送到商店",},
			[3] = {Name = "错误传送旋涡",Description = "#{{ErrorRoom}} 将你传送到错误房",},
			[4] = {Name = "宝箱传送旋涡",Description = "#{{TreasureRoom}} 将你传送到宝箱房",},
			[5] = {Name = "决战传送旋涡",Description = "#{{BossRoom}} 将你传送到Boss房",},
			[6] = {Name = "七罪传送旋涡",Description = "#{{MiniBoss}} 将你传送到小Boss房",},
			[7] = {Name = "隐藏传送旋涡",Description = "#{{SecretRoom}} 将你传送到隐藏房",},
			[8] = {Name = "超级隐藏传送旋涡",Description = "#{{SuperSecretRoom}} 将你传送到超级隐藏房",},
			[9] = {Name = "游戏传送旋涡",Description = "#{{ArcadeRoom}} 将你传送到游戏房",},
			[10] = {Name = "诅咒传送旋涡",Description = "#{{CursedRoom}} 将你传送到诅咒房",},
			[11] = {Name = "挑战传送旋涡",Description = "#{{ChallengeRoom}} 将你传送到挑战房",},
			[12] = {Name = "图书传送旋涡",Description = "#{{Library}} 将你传送到图书馆",},
			[13] = {Name = "献祭传送旋涡",Description = "#{{SacrificeRoom}} 将你传送到献祭房",},
			[14] = {Name = "恶魔传送旋涡",Description = "#{{DevilRoom}} 将你传送到恶魔房",},
			[15] = {Name = "天使传送旋涡",Description = "#{{AngelRoom}} 将你传送到天使房",},
			[16] = {Name = "大地传送旋涡",Description = "#{{LadderRoom}} 将你传送到地下室",},
			[17] = {Name = "究极挑战传送旋涡",Description = "#{{BossRushRoom}} 将你传送到BossRush房",},
			[18] = {Name = "睡房传送旋涡",Description = "#{{IsaacsRoom}} 将你传送到睡房",},
			[19] = {Name = "坏睡房传送旋涡",Description = "#{{BarrenRoom}} 将你传送到坏睡房",},
			[20] = {Name = "大宝箱传送旋涡",Description = "#{{ChestRoom}} 将你传送到双锁宝箱房",},
			[21] = {Name = "骰子传送旋涡",Description = "#{{DiceRoom}} 将你传送到骰子房",},
			[22] = {Name = "黑市传送旋涡",Description = "#将你传送到黑市",},
			[23] = {Name = "出口传送旋涡",Description = "#将你传送到本层出口",},
			[24] = {Name = "星座传送旋涡",Description = "#{{Planetarium}} 将你传送到星象房",},
			[29] = {Name = "究极之红传送旋涡",Description = "#{{UltraSecretRoom}} 将你传送到红隐藏房",},
			[114] = {Name = "五芒星传送旋涡",Description = "#将你传送到最终boss超级撒旦#胜利后获得天使、恶魔、Boss房道具各一个并开启返回通道",},
			[115] = {Name = "天使商店传送旋涡",Description = "#{{AngelRoom}} 将你传送到天使商店",},
			[116] = {Name = "地下商店传送旋涡",Description = "#将你传送到地下商店",},
			[117] = {Name = "愚者传送旋涡",Description = "#{{Card1}} 将你传送到初始房间",},
			[118] = {Name = "彩虹传送旋涡",Description = "#{{ColorRainbow}} 将你传送到随机特殊房间{{CR}}",},
			[119] = {Name = "死亡证明传送旋涡",Description = "#{{Collectible628}} 将你传送到死亡证明层",},
			[120] = {Name = "管理员中枢旋涡",Description = "#将你传送到控制中枢",},
		},
		["en_us"] = {
			[2] = {Name = "Shop portal",Description = "#{{Shop}} Teleport you to the shop",},
			[3] = {Name = "Error portal",Description = "#{{ErrorRoom}} Teleport you to the error room",},
			[4] = {Name = "Treasure portal",Description = "#{{TreasureRoom}} Teleport you to the treasure room",},
			[5] = {Name = "Boss portal",Description = "#{{BossRoom}} Teleport you to the boss room",},
			[6] = {Name = "Sins portal",Description = "#{{MiniBoss}} Teleport you to the mini boss room",},
			[7] = {Name = "Secret portal",Description = "#{{SecretRoom}} Teleport you to the secret room",},
			[8] = {Name = "Super secret portal",Description = "#{{SuperSecretRoom}} Teleport you to the super secret room",},
			[9] = {Name = "Arcade portal",Description = "#{{ArcadeRoom}} Teleport you to the arcade",},
			[10] = {Name = "Cursed portal",Description = "#{{CursedRoom}} Teleport you to the cursed room",},
			[11] = {Name = "Challenge portal",Description = "#{{ChallengeRoom}} Teleport you to the challenge room",},
			[12] = {Name = "Library portal",Description = "#{{Library}} Teleport you to the library",},
			[13] = {Name = "Sacrifice portal",Description = "#{{SacrificeRoom}} Teleport you to the sacrifice room",},
			[14] = {Name = "Devil portal",Description = "#{{DevilRoom}} Teleport you to the devil room",},
			[15] = {Name = "Angel portal",Description = "#{{AngelRoom}} Teleport you to the angel room",},
			[16] = {Name = "Ground portal",Description = "#{{LadderRoom}} Teleport you to the dungeon",},
			[17] = {Name = "Ultra Challenge portal",Description = "#{{BossRushRoom}} Teleport you to the Boss Rush room",},
			[18] = {Name = "Sleeping portal",Description = "#{{IsaacsRoom}} Teleport you to the sleeping room",},
			[19] = {Name = "Barren portal",Description = "#{{BarrenRoom}} Teleport you to the broken sleeping room",},
			[20] = {Name = "Chest portal",Description = "#{{ChestRoom}} Teleport you to the chest room",},
			[21] = {Name = "Dice portal",Description = "#{{DiceRoom}} Teleport you to the dice room",},
			[22] = {Name = "Market portal",Description = "#Teleport you to the black market",},
			[23] = {Name = "Exit portal",Description = "#Teleport you to the exit room",},
			[24] = {Name = "Planet portal",Description = "#{{Planetarium}} Teleport you to the planetrium room",},
			[29] = {Name = "Ultra secret portal",Description = "#{{UltraSecretRoom}} Teleport you to the ultra secret room",},
			[114] = {Name = "Pentacle portal",Description = "#Teleport you to the final boss Mega Satan",},
			[115] = {Name = "Angel shop portal",Description = "#{{AngelRoom}} Teleport you to the angel shop",},
			[116] = {Name = "Secret shop portal",Description = "#Teleport you to the secret shop",},
			[117] = {Name = "Fool's portal",Description = "#{{Card1}} Teleport you to the start room",},
			[118] = {Name = "Rainbow portal",Description = "#{{ColorRainbow}} Teleport you to a random room{{CR}}",},
			[119] = {Name = "Death portal",Description = "#{{Collectible628}} Teleport you to Death certification level",},
			[120] = {Name = "Control Hub portal",Description = "#Teleport you to the Control Hub",},
		},
	},
}

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
	save.elses[item.own_key.."effect"] = {}
end,
})

function item.spawn_a_fool_port(pos,params)
	params = params or {}
	local info = params.info or {id = -1,tp = 117,gidx = 84,dim = 0,}
	local q = Isaac.Spawn(1000,161,item.entity,pos,Vector(0,0),nil):ToEffect()
	local s = q:GetSprite()
	s:Load("gfx/cards/cd01_wiz_port.anm2",true)
	s:Play("Appear",true)
	for i = 0,5 do s:ReplaceSpritesheet(i,"gfx/effects/portals/cd01_wiz_port_"..tostring(info.tp)..".png") end
	s:LoadGraphics()
	local d = q:GetData()
	d[item.own_key.."effect"] = info
	d[item.own_key.."others"] = params
	if EID then
		local language = EID.UserConfig.Language
		if language == "auto" then language = "zh_cn" end
		if item.port_desc[language] and item.port_desc[language][info.tp] then q:GetData().EID_Description = item.port_desc[language][info.tp] end
	end
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,rng,pos)
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if desc.SafeGridIndex == -7 and Game():GetLevel():GetStage() ~= LevelStage.STAGE6 then
		local room = Game():GetRoom()
		local itempool = Game():GetItemPool()
		item.spawn_a_fool_port(Game():GetRoom():GetCenterPos())
		local seed = rng:GetSeed()
		local colid = itempool:GetCollectible(3,true,seed)
		rng:Next()
		if colid and colid ~= 0 then
			local q = Isaac.Spawn(5,100,colid,room:FindFreePickupSpawnPosition(pos + Vector(-40,0),10,true),Vector(0,0),player):ToPickup()
			q:Morph(5,100,colid,true,true,true)
		end
		local seed = rng:GetSeed()
		local colid = itempool:GetCollectible(4,true,seed)
		rng:Next()
		if colid and colid ~= 0 then
			local q = Isaac.Spawn(5,100,colid,room:FindFreePickupSpawnPosition(pos + Vector(40,0),10,true),Vector(0,0),player):ToPickup()
			q:Morph(5,100,colid,true,true,true)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if (save.elses[item.own_key.."effect"][desc.Data.Type] or 0) & 1 == 1 then 
		local tbl = {}
		local level = Game():GetLevel()
		local rooms = level:GetRooms()
		local room = Game():GetRoom()
		local player = Game():GetPlayer(0)
		local rng = player:GetCardRNG(item.entity)
		rng = auxi.rng_for_sake(rng)
		local cnt = math.random(2) + 3
		local dimen = auxi.GetDimension()
		
		for i = 1, rooms.Size do
			local targ = rooms:Get(i - 1)
			if targ and dimen == auxi.GetDimension(targ) then
				local desc = level:GetRoomByIdx(targ.SafeGridIndex)
				if desc then
					local tp = desc.Data.Type
					if tp ~= RoomType.ROOM_DEFAULT then table.insert(tbl,#tbl + 1,{id = i,tp = tp,gidx = targ.SafeGridIndex,}) end
				end
			end
		end
		if save.elses[item.own_key.."effect"][desc.Data.Type] & 2 == 2 or rng:RandomInt(1000) > 750 then 
			for u,v in pairs(item.tarot_buffs) do
				if v.special then v.special() end
				for i = 1,1 do
					if v.ignore_ascent and (level:IsAscent() or auxi.get_level_door_info() == 9) then break end
					if v.ignore_hush and auxi.get_level_door_info() == 5 then break end
					table.insert(tbl,#tbl + 1,{id = -1,tp = auxi.check_if_any(v.tp,nil),gidx = v.id,replace_tp = v.replace_tp,})
				end
			end
			cnt = cnt + 2
		else
			local v = auxi.random_in_table(item.tarot_buffs)
			if v.special then v.special() end
			if v.ignore_ascent and (level:IsAscent() or auxi.get_level_door_info() == 9) then
			else
				table.insert(tbl,#tbl + 1,{id = -1,tp = auxi.check_if_any(v.tp,nil),gidx = v.id,replace_tp = v.replace_tp,})
			end
		end
		tbl = auxi.randomTable(tbl,rng)
		cnt = math.min(cnt,#tbl)
		local pos = room:GetCenterPos()
		local st = math.random(360)
		for i = 1,cnt do
			if #tbl > 0 then
				local info = tbl[1]
				local s2 = Sprite()
				s2:Load("gfx/cards/cd01_wiz_map.anm2",true)
				s2:SetFrame("Idle",info.replace_tp or info.tp or 1)
				local q = auxi.reveal_item2(player,pos + auxi.MakeVector(st + i * 360 / cnt) * 60,33,{replace_renderer = s2,scale = Vector(2.5,2.5),offset = Vector(-1,0),revealee_end = function(eent,params)
					if eent:Exists() then
						local q = item.spawn_a_fool_port(eent.Position,{info = info,})
						
						local grid = room:GetGridEntity(room:GetGridIndex(q.Position))
						if grid then
							if grid:ToPoop() or grid:ToRock() then
								grid:Destroy(true)
							end
							if grid:ToPit() and grid:ToPit().HasLadder == false then
								grid:ToPit():SetLadder(true)
								grid:ToPit().HasLadder = true
								Isaac.Spawn(1000,8,0,grid.Position,Vector(0,0),nil)
							end
						end
					end
				end})
				table.remove(tbl,1)
			end
		end
		save.elses[item.own_key.."effect"][desc.Data.Type] = 2
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GET_TELEPORT, params = "portal",
Function = function(_,player, tp, params)
	if params.id == item.entity then
		local ent = params.ent
		if ent == nil then return end
		local d = ent:GetData()
		if d[item.own_key.."effect"] then
			auxi.check_if_any(d[item.own_key.."others"].Special,player,item)
			Room_holder.Trans_to(d[item.own_key.."effect"].gidx,Direction.NO_DIRECTION,RoomTransitionAnim.PORTAL_TELEPORT,player,d[item.own_key.."effect"].dim or -1,d[item.own_key.."others"])
			if d[item.own_key.."effect"].gidx == -6 then 
				delay_buffer.addeffe(function(params)
					item.spawn_a_fool_port(Vector(320,280))
				end,{},1)
			end
			if d[item.own_key.."effect"].gidx == -7 then
				delay_buffer.addeffe(function(params)
					local room = Game():GetRoom()
					if room:IsClear() then
						item.spawn_a_fool_port(room:GetCenterPos())
					end
				end,{},1)
			end
		end
		--l Game():GetLevel():InitializeDevilAngelRoom(true,false)
		--l local desc = Game():GetLevel():GetRoomByIdx(-1) desc.Data = nil desc.OverrideData = nil Game():GetLevel():InitializeDevilAngelRoom(true,false)
		--l local desc = Game():GetLevel():GetRoomByIdx(-2) if desc then Game():StartRoomTransition(desc.SafeGridIndex, Direction.NO_DIRECTION, RoomTransitionAnim.PORTAL_TELEPORT, Game():GetPlayer(0)) end for i = 1,60 do Game():GetRoom():Update() end local desc = Game():GetLevel():GetRoomByIdx(84) if desc then Game():StartRoomTransition(desc.SafeGridIndex, Direction.NO_DIRECTION, RoomTransitionAnim.PORTAL_TELEPORT, Game():GetPlayer(0)) end
		--l local desc = Game():GetLevel():GetRoomByIdx(-7) if desc and desc.Data then Game():StartRoomTransition(desc.SafeGridIndex, Direction.NO_DIRECTION, RoomTransitionAnim.PORTAL_TELEPORT, Game():GetPlayer(0)) end
		--l for i = 1,60 do Game():GetRoom():Update() end
		--Game():StartRoomTransition(84, Direction.NO_DIRECTION, RoomTransitionAnim.PORTAL_TELEPORT, player)		--有趣的是，传送到当前房间会出现问题，除非处于黑洞内
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
		local level = Game():GetLevel()
		local rooms = level:GetRooms()
		local dimen = auxi.GetDimension()
		local tbl = {}
		for i = 1, rooms.Size do
			local targ = rooms:Get(i - 1)
			if targ and dimen == auxi.GetDimension(targ) then
				local desc = level:GetRoomByIdx(targ.SafeGridIndex)
				if desc then
					local tp = desc.Data.Type
					if tp ~= RoomType.ROOM_DEFAULT and save.elses[item.own_key.."effect"][tp] == nil then table.insert(tbl,#tbl + 1,{id = i,tp = tp,}) end
				end
			end
		end
		if #tbl > 0 then
			local rnd = auxi.random_in_table(tbl,rng)
			for i = 1, rooms.Size do
				local targ = rooms:Get(i - 1)
				if targ and dimen == auxi.GetDimension(targ) then
					local desc = level:GetRoomByIdx(targ.SafeGridIndex)
					if desc then
						local tp = desc.Data.Type
						if tp == rnd.tp then
							desc.DisplayFlags = 5
						end
					end
					level:UpdateVisibility()
				end
			end
			if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then 
				save.elses[item.own_key.."effect"][rnd.tp] = 3
			else
				save.elses[item.own_key.."effect"][rnd.tp] = 1
			end
			local s2 = Sprite()
			s2:Load("gfx/cards/cd01_wiz_map.anm2",true)
			s2:SetFrame("Idle",rnd.tp or 1)
			auxi.reveal_item(player,player.Position,33,{offset = item.offset_info[1],replace_renderer = s2,scale = Vector(2.5,2.5),linkedoffset = Vector(-1,0),})
		else
			player:AnimateHappy()
			for i = 1, rooms.Size do
				local targ = rooms:Get(i - 1)
				local desc = level:GetRoomByIdx(targ.SafeGridIndex)
				desc.DisplayFlags = 5
			end
			level:UpdateVisibility()
		end
	end
end,
})

return item
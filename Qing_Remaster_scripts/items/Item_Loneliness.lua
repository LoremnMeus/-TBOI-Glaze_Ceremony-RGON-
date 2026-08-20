local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local revive_holder = require("Qing_Remaster_scripts.callbacks.revive_holder")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Loneliness,
	own_key = "Item_Loneliness_",
	PlayerType = {
		[PlayerType.PLAYER_ISAAC] = 0,
		[PlayerType.PLAYER_MAGDALENE] = 1,
		[PlayerType.PLAYER_CAIN] = 2,
		[PlayerType.PLAYER_JUDAS] = 3,
		[PlayerType.PLAYER_BLUEBABY] = 4,
		[PlayerType.PLAYER_EVE] = 5,
		[PlayerType.PLAYER_SAMSON] = 6,
		[PlayerType.PLAYER_AZAZEL] = 7,
		[PlayerType.PLAYER_LAZARUS] = 8,
		[PlayerType.PLAYER_EDEN] = 9,
		[PlayerType.PLAYER_THELOST] = 10,
		[PlayerType.PLAYER_LAZARUS2] = 11,
		[PlayerType.PLAYER_BLACKJUDAS] = 12,
		[PlayerType.PLAYER_LILITH] = 13,
		[PlayerType.PLAYER_KEEPER] = 14,
		[PlayerType.PLAYER_APOLLYON] = 15,
		[PlayerType.PLAYER_THEFORGOTTEN] = 16,
		--[PlayerType.PLAYER_THESOUL] = 17,

		-- Repentance
		[PlayerType.PLAYER_BETHANY] = 18,
		--[PlayerType.PLAYER_JACOB] = 19,
		[PlayerType.PLAYER_ESAU] = 20,
		[PlayerType.PLAYER_ISAAC_B] = 21,
		[PlayerType.PLAYER_MAGDALENE_B] = 22,
		[PlayerType.PLAYER_CAIN_B] = 23,
		[PlayerType.PLAYER_JUDAS_B] = 24,
		[PlayerType.PLAYER_BLUEBABY_B] = 25,
		[PlayerType.PLAYER_EVE_B] = 26,
		[PlayerType.PLAYER_SAMSON_B] = 27,
		[PlayerType.PLAYER_AZAZEL_B] = 28,
		--[PlayerType.PLAYER_LAZARUS_B] = 29,
		[PlayerType.PLAYER_EDEN_B] = 30,
		[PlayerType.PLAYER_THELOST_B] = 31,
		[PlayerType.PLAYER_LILITH_B] = 32,
		[PlayerType.PLAYER_KEEPER_B] = 33,
		[PlayerType.PLAYER_APOLLYON_B] = 34,
		--[PlayerType.PLAYER_THEFORGOTTEN_B] = 35,
		[PlayerType.PLAYER_BETHANY_B] = 36,
		[PlayerType.PLAYER_JACOB_B] = 37,
		--[PlayerType.PLAYER_LAZARUS2_B] = 38,
		--[PlayerType.PLAYER_JACOB2_B] = 39,
		--[PlayerType.PLAYER_THESOUL_B] = 40,
	},
	Flight_info = {
		{frame = 0,val = 0,},
		{frame = 30,val = 0,},
		{frame = 60,val = -60,},
		{frame = 80,val = -70,},
		{frame = 120,val = -70,},
		{frame = 200,val = -70,},
		{frame = 220,val = -50,},
		{frame = 235,val = 0,},
		{frame = 250,val = 0,},
		Light = 10,
		DeathSound = 14,
		total = 250,
		Friend = 120,
	},
	Fflight_info = {
		{frame = 0,val = -200,},
		{frame = 120,val = -200,},
		{frame = 160,val = -100,},
		{frame = 200,val = -70,},
		{frame = 220,val = -60,},
		{frame = 235,val = 0,},
		{frame = 250,val = 0,},
		total = 250,
		Usetime = 210,
		Usetime2 = 224,
	},
	Fitem_info = {
		{frame = 0,val = -25,},
		{frame = 210,val = -25,},
		{frame = 214,val = -23,},
		{frame = 218,val = -10,},
		total = 224,
	},
	Move = Vector(22,0),
}

function item.random_player_id(id,rng)
	local tbl = auxi.deepCopy(item.PlayerType) for u,v in pairs(enums.Players) do if v > 0 then tbl[v] = v end end tbl[id] = nil tbl[enums.Players.Lu] = nil tbl[enums.Players.Autio] = nil tbl[enums.Players.Zeistos] = nil
	local tab = {} for u,v in pairs(tbl) do table.insert(tab,v) end
	return auxi.random_in_table(tab,rng)
end

function item.find_main_friend()
	for playerNum = 1,Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1) local tidx = player:GetData().__Index local sidx = save.get_sub_idx(player)
		if auxi.check_all_exists(player) and ((save.elses[item.own_key.."effect"][tidx] and not save.elses[item.own_key.."effect"][tidx].Friend) or (save.elses[item.own_key.."effect"][sidx] and not save.elses[item.own_key.."effect"][sidx].Friend)) then return player end
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then else save.elses[item.own_key.."effect"] = {} end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	if shouldsave then
		local t_player = item.find_main_friend()
		if t_player then
			for _, player in pairs(Isaac.FindByType(1)) do
				player = player:ToPlayer()
				local idx = player:GetData().__Index
				if save.elses[item.own_key.."effect"][idx] and save.elses[item.own_key.."effect"][idx].Friend and player.Parent == nil then
					save.elses[item.own_key.."effect"][idx].Help = {}
					player.Parent = t_player
					--if auxi.check_for_the_same(player:GetMainTwin(),player) then player.Parent = t_player else player.Parent = player:GetMainTwin() end
					save.elses[item.own_key.."effect"].Help = {}
				end
			end
		end
	end
end,
})
--l print(Game():GetPlayer(1):GetData().__Index
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,priority = 20,
Function = function(_,player)
	if save.elses[item.own_key.."effect"].Help then
		local friend = item.find_main_friend()
		Game():GetHUD():AssignPlayerHUDs() 
		for playerNum = 1, Game():GetNumPlayers() do
			local t_player = Game():GetPlayer(playerNum - 1)
			local idx = t_player:GetData().__Index
			save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
			if save.elses[item.own_key.."effect"][idx] and save.elses[item.own_key.."effect"][idx].Help then 
				t_player.Parent = nil 
				save.elses[item.own_key.."effect"][idx].Help = nil
			end
			if friend then t_player.Position = Game():GetRoom():GetClampedPosition(friend.Position + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,40),0) end
		end
		save.elses[item.own_key.."effect"].Help = nil
	end
	local idx = player:GetData().__Index
	if save.elses[item.own_key.."effect"][idx] and save.elses[item.own_key.."effect"][idx].Friend then
		if Input.IsActionTriggered(ButtonAction.ACTION_BOMB, player.ControllerIndex) and not player:HasGoldenBomb() then
			local valid = 0	for _, bomb in pairs(Isaac.FindByType(4)) do if bomb.FrameCount < 1 then valid = valid + 1 end end if valid > 1 then player:AddBombs(1)
			elseif valid == 1 then Isaac.Spawn(4, 0, 0, player.Position, Vector.Zero, player):ToBomb().Flags = player:GetBombFlags() end
		end
	end
	local d = player:GetData()
	for i = 1,1 do if d[item.own_key.."Helpeffect"] then
		local tg = d[item.own_key.."Helpeffect"].linker
		if auxi.check_all_exists(tg) ~= true or tg:GetData()[item.own_key.."deffect"] == nil then
			if d[item.own_key.."entitycollision_succ"] then Attribute_holder.try_rewind_attribute(player,"EntityCollisionClass",d[item.own_key.."entitycollision_succ"]) d[item.own_key.."entitycollision_succ"] = nil end
			if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] then Attribute_holder.try_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = nil end
			d[item.own_key.."Helpeffect"] = nil break 
		end
		player_offset_holder.LoadPlayer(player,true)
		player.Position = tg.Position + Vector(0,-1) + item.Move * tg.SpriteScale.X
		player.Velocity = Vector(0,0)
        player:SetMinDamageCooldown(3)
		d[item.own_key.."entitycollision_succ"] = d[item.own_key.."entitycollision_succ"] or Attribute_holder.try_hold_attribute(player,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
		d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] or Attribute_holder.try_hold_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK))
		player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
	end end
	if d[item.own_key.."deffect"] then 
		if (d[item.own_key.."deffect"].counter or 0) > item.Flight_info.Light and auxi.check_all_exists(d[item.own_key.."deffect"].Light) ~= true then 
			d[item.own_key.."deffect"].Light = auxi.fire_nil(player.Position + item.Move * player.SpriteScale.X,Vector(0,0),{cooldown = 999,}) 
			local q = d[item.own_key.."deffect"].Light q.DepthOffset = 5 
			local s = q:GetSprite() s:Load("gfx/1000.039_heaven door.anm2",true) s:Play("Appear",true)
			local dq = q:GetData() dq[item.own_key.."Light"] = {linker = player,}
			dq[Nil_holder.own_key.."work"] = function(ent)
				local de = ent:GetData() local s = ent:GetSprite()
				if de[item.own_key.."Remove"] then
					if s:IsFinished("Disappear") then ent:Remove() return true else return end
				end
				local tg = de[item.own_key.."Light"].linker 
				if auxi.check_all_exists(tg) ~= true or tg:GetData()[item.own_key.."deffect"] == nil then de[item.own_key.."Remove"] = {} s:Play("Disappear",true) return end
				q.Position = tg.Position + item.Move * tg.SpriteScale.X q.Velocity = Vector(0,0)
				--local cnt = tg:GetData()[item.own_key.."deffect"].counter or 0
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local friend = item.find_main_friend()
	if friend then
		for playerNum = 1, Game():GetNumPlayers() do
			local t_player = Game():GetPlayer(playerNum - 1) local idx = t_player:GetData().__Index
			if (friend.Position - t_player.Position):Length() < 10 and save.elses[item.own_key.."effect"][idx] and save.elses[item.own_key.."effect"][idx].Friend then t_player.Position = Game():GetRoom():GetClampedPosition(friend.Position + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,40),0) end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_REWIND, params = nil,
Function = function(_,tp)
	local friend = item.find_main_friend()
	if friend then
		Game():GetHUD():AssignPlayerHUDs() 
		for playerNum = 1, Game():GetNumPlayers() do
			local t_player = Game():GetPlayer(playerNum - 1) local idx = t_player:GetData().__Index
			if save.elses[item.own_key.."effect"][idx] and save.elses[item.own_key.."effect"][idx].Friend then 
				t_player.Parent = nil 
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHECK_PLAYER_POSITIONOFFSET, params = nil,
Function = function(_,player,value)
	local d = player:GetData()
	if d[item.own_key.."deffect"] then
		local s = player:GetSprite()
		local cnt = d[item.own_key.."deffect"].counter or 0
		local info = auxi.check_lerp(cnt,item.Flight_info)
		value.Offset = value.Offset + Vector(0,info.val or 0)
		value.Remove = false
		if cnt >= item.Flight_info.total - 21 then s:SetFrame("Death",math.max(0,item.Flight_info.total - cnt))
		elseif cnt >= 42 then s:SetFrame("Death",21) else s:SetFrame("Death",math.ceil(cnt/2)) end
		return value
	end
	if d[item.own_key.."Helpeffect"] then
		local s = player:GetSprite()
		local tg = d[item.own_key.."Helpeffect"].linker
		if auxi.check_all_exists(tg) ~= true or tg:GetData()[item.own_key.."deffect"] == nil then return end
		local cnt = tg:GetData()[item.own_key.."deffect"].counter or 0
		local info = auxi.check_lerp(cnt,item.Fflight_info)
		value.Offset = value.Offset + Vector(0,info.val or 0) + (d[item.own_key.."Helpeffect"].offset or Vector(0,0))
		value.Remove = false
		if d[item.own_key.."Helpeffect"].Sub ~= true then
			if cnt <= item.Fflight_info.Usetime then s:SetFrame("UseItem",5)
			elseif cnt < item.Fflight_info.Usetime2 then s:SetFrame("UseItem",9 + math.ceil((cnt - item.Fflight_info.Usetime)/2))
			elseif cnt == item.Fflight_info.Usetime2 then d[item.own_key.."Helpeffect"].Finish = true end
		end
		d[item.own_key.."Helpeffect"].cnt = cnt
		return value
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local d = player:GetData() local s = player:GetSprite()
	if d[item.own_key.."deffect"] then player:PlayExtraAnimation("Death") end
	if d[item.own_key.."Helpeffect"] and not d[item.own_key.."Helpeffect"].Finish and not d[item.own_key.."Helpeffect"].Sub then 
		player:PlayExtraAnimation("UseItem") 
		local info = auxi.check_lerp(d[item.own_key.."Helpeffect"].cnt or 0,item.Fitem_info)
		if (d[item.own_key.."Helpeffect"].cnt or 0) < item.Fitem_info.total then local s = auxi.load_item(11) s:Render(Isaac.WorldToRenderPosition(player.Position) + offset + Vector(0,info.val),Vector(0,0),Vector(0,0)) end
	end
end,
})

function item.make_friend(player)
	player:RemoveCollectible(item.entity)
	local id = item.random_player_id(player:GetPlayerType(),player:GetCollectibleRNG(item.entity))
	Isaac.ExecuteCommand("addplayer " .. id .. " " .. player.ControllerIndex)
	local friend = Isaac.GetPlayer(Game():GetNumPlayers() - 1) 
	friend.Parent = player Game():GetHUD():AssignPlayerHUDs() friend.Parent = nil
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."effect"][player:GetData().__Index] = {}
	save.elses[item.own_key.."effect"][friend:GetData().__Index] = {Friend = true,}
	for u,v in pairs({player,friend}) do if v:GetOtherTwin() then save.elses[item.own_key.."effect"][v:GetOtherTwin():GetData().__Index] = {Friend = (u == 2),} end end
	return friend
end

function item.remove_friends(player)
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_PLAYER_KILL, params = nil,
Function = function(_,player)
	if not player:WillPlayerRevive() then
		local rplayer = auxi.has_or_have_coll_(player,item.entity)
		if rplayer then
			local ret = {should_revive = true,on_revive = function(player,tp)
				local d = player:GetData() local dr = rplayer:GetData() 
				if d[item.own_key.."deffect"].Friend == nil then item.make_friend(rplayer) end
				d[item.own_key.."deffect"] = nil player:StopExtraAnimation() player:SetFullHearts()
				if tp ~= "exit" then 
					Attribute_holder.try_hold_and_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,60,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK))
					player:AnimateCollectible(11,"Pickup","PlayerPickupSparkle")
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_1UP,1,1,false,0,2)
				end
			end,on_revive_update = function(player)
				local d = player:GetData() local s = player:GetSprite()
				player_offset_holder.LoadPlayer(player,true)
				d[item.own_key.."deffect"] = d[item.own_key.."deffect"] or {}
				d[item.own_key.."deffect"].counter = (d[item.own_key.."deffect"].counter or 0) + 1
				if d[item.own_key.."deffect"].counter == item.Flight_info.DeathSound then sound_tracker.PlayStackedSound(SoundEffect.SOUND_ISAACDIES,1,1,false,0,2) end
				if d[item.own_key.."deffect"].counter == item.Flight_info.Friend then 
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SUPERHOLY,1,1,false,0,2)
					local friend = item.make_friend(rplayer) friend.Position = player.Position + Vector(0,-1) + item.Move * player.SpriteScale.X  friend:GetData()[item.own_key.."Helpeffect"] = {linker = player,} d[item.own_key.."deffect"].Friend = true player_offset_holder.LoadPlayer(friend,true) player_offset_holder.TrickOnPlayer(friend) 
					if friend:GetOtherTwin() then local friend2 = friend:GetOtherTwin() friend2.Position = player.Position + Vector(0,-11) + item.Move * player.SpriteScale.X friend2:GetData()[item.own_key.."Helpeffect"] = {linker = player,Sub = true,offset = Vector(-10,0),} d[item.own_key.."deffect"].Friend = true player_offset_holder.LoadPlayer(friend2,true) player_offset_holder.TrickOnPlayer(friend2) end
				end
			end,revive_time = 240,}
			local d = player:GetData()
			d[item.own_key.."deffect"] = {}
			player:StopExtraAnimation() player:PlayExtraAnimation("Death")
			return ret
		end
	end
end,
})

table.insert(item.post_myToCall,#item.post_myToCall + 1,{CallBack = enums.Callbacks.PRE_PLAYER_KILL, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index local sidx = save.get_sub_idx(player)
	if not player:WillPlayerRevive() and (save.elses[item.own_key.."effect"][idx] or save.elses[item.own_key.."effect"][sidx]) then
		for playerNum = 1,Game():GetNumPlayers() do
			local t_player = Game():GetPlayer(playerNum - 1) 
			if auxi.check_all_exists(t_player) then local tidx = t_player:GetData().__Index local stidx = save.get_sub_idx(t_player)
				if (tidx ~= idx and save.elses[item.own_key.."effect"][tidx]) or (stidx ~= idx and save.elses[item.own_key.."effect"][stidx]) then player:AddMaxHearts(-player:GetMaxHearts()) player.Parent = t_player save.elses[item.own_key.."effect"][tidx] = {} save.elses[item.own_key.."effect"][stidx] = {} break end
			end
		end
	end
end,
})
--l if Game():GetPlayer(0).Parent then print(1) end
return item
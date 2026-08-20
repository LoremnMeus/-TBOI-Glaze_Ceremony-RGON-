local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Subera_Light,
	familiar = enums.Familiars.Subera_Torch,
	time_counter = 60,
	own_key = "Item_Subera_Light_",
	Colorinfo = {
		{frame = 0 * 6,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 6,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 6,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 6,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 6,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 6,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		
		{frame = 6 * 6,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 6,
	},
	Color_base_info = {
		{frame = 0,A = 0,},
		{frame = 30,A = 0.5,},
		{frame = 60,A = 1,},
	},
	step_time = 3,
}
auxi.add_to_seija(item.entity)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local room = Game():GetRoom()
	local s = player:GetSprite()
	local d = player:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		if auxi.has_have_coll(player,item.entity) then
			d[item.own_key.."counter"] = d[item.own_key.."counter"] or 0
			local cnt = d[item.own_key.."counter"]
			Charging_Bar_holder.render_me(player,{name1 = item.own_key.."counter",name2 = item.own_key.."sprite",name3 = item.own_key,loadname = "gfx/effects/chargebar/chargebar_Subera_Light.anm2",
				check1 = function(val,ent)
					return cnt > 5
				end,
				check2 = function(val,ent) 
					return cnt > item["time_counter"]
				end,
				check3 = function(val,ent)
					return math.ceil(cnt/item["time_counter"] * 100)
				end,
				signal1 = function(ent)
					d[item.own_key.."active"] = true
				end,
			})
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,count)
	if count < 0 then
		Charging_Bar_holder.remove_charge_bar(player,item.own_key)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local ctrlid = player.ControllerIndex
		local d = player:GetData()
		if auxi.g_dir_can_work(player) then
			if auxi.has_have_coll(player,item.entity) then
				local act = false
				for i = 4,7 do
					if (Input.IsActionTriggered(i,ctrlid)) or (Input.IsActionPressed(i,ctrlid)) then
						act = true
					end
				end
				if act then d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1 
				else 
					if d[item.own_key.."active"] then d[item.own_key.."active"] = nil d[item.own_key.."fire"] = true end
					d[item.own_key.."counter"] = 0 
				end
			end
		end
		if d[item.own_key.."fired"] then 
			d[item.own_key.."fired"].counter = (d[item.own_key.."fired"].counter or 0) - item.step_time
			if d[item.own_key.."fired"].counter < 0 then d[item.own_key.."fired"] = nil end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = math.min(player:GetCollectibleNum(item.entity),1)
	local d = player:GetData()
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_FAMILIAR_RENDER, params = item.familiar,
Function = function(_,ent,offset)
	local player = auxi.check_spawner_player(ent)
	local d = ent:GetData()
	local d2 = player:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		local pos = Isaac.WorldToScreen(player.Position + player_offset_holder.GetPlayerOffset(player)) + Vector(0,-16) * player.SpriteScale.Y
		d[item.own_key.."sprite"] = d[item.own_key.."sprite"] or {}
		d[item.own_key.."record"] = d[item.own_key.."record"] or {}
		for i = 1,2 do
			if d[item.own_key.."sprite"][i] == nil then 
				local s = Sprite()
				s:Load("gfx/mimics/Subera_Light/Torch.anm2")
				s:Play("Part"..tostring(i))
				d[item.own_key.."sprite"][i] = s
			end
		end
		local tg = auxi.get_nearest_enemy(nil,ent.Position,function(leg,v) 
			if auxi.check_all_exists(d[item.own_key.."tg"]) and auxi.check_for_the_same(d[item.own_key.."tg"],v) then return leg - 50 end
		end)
		local ddir = nil
		if tg then ddir = (tg.Position - ent.Position):GetAngleDegrees() end
		d[item.own_key.."tg"] = tg
		local gdir = (d[item.own_key.."dir"] or Vector(1,0)):GetAngleDegrees()
		local mx = 6 + (player:GetCollectibleNum(item.entity) - 1) * 2
		if auxi.should_do_Seija(player) then mx = 1 + (player:GetCollectibleNum(item.entity) - 1) end
		for i = 1,mx do
			d[item.own_key.."record"][i] = d[item.own_key.."record"][i] or {}
			local dir = ddir
			local s1 = d[item.own_key.."sprite"][1]
			local s2 = d[item.own_key.."sprite"][2]
			local ii = i * 6/mx
			if auxi.should_do_Seija(player) then ii = ii + (d[item.own_key.."counter"] or 0) end
			local rot = (ii * 60 + gdir) % 360
			local col = auxi.table2color(auxi.check_lerp((ii * 6) % item.Colorinfo.total,item.Colorinfo))
			d[item.own_key.."record"][i][0] = auxi.checkrounded(d[item.own_key.."record"][i][0] or rot,rot,0.8,0.2,360)
			s1.Rotation = d[item.own_key.."record"][i][0]
			local cnt = math.max((d2[item.own_key.."fired"] or {}).counter or d2[item.own_key.."counter"] or 0,d2[item.own_key.."counter"] or 0)
			local basecolor = Color(1,1,1,auxi.check_lerp(cnt,item.Color_base_info).A or 0)
			if player:GetData()[item.own_key.."fire"] then basecolor = Color(1,1,1,1) end
			col = auxi.MulColor(col,basecolor)
			s1.Color = auxi.AddColor(basecolor,col,0.8,0.2)
			s1:Render(pos,Vector(0,0),Vector(0,0))
			local tpos = pos
			for j = 1,3 do
				tpos = tpos + auxi.get_by_rotate(nil,s1.Rotation - 90,16)
				d[item.own_key.."record"][i][j] = auxi.checkrounded(d[item.own_key.."record"][i][j] or s1.Rotation,auxi.round_aver(dir or s1.Rotation,s1.Rotation),0.8,0.2,360)
				s1.Rotation = d[item.own_key.."record"][i][j]
				s1.Color = auxi.AddColor(s1.Color,col,0.5,0.5)
				s1:Render(tpos,Vector(0,0),Vector(0,0))
			end
			tpos = tpos + auxi.get_by_rotate(nil,d[item.own_key.."record"][i][3] - 90,16)
			d[item.own_key.."record"][i][10] = auxi.myScreenToWorld(tpos) + Isaac.ScreenToWorld(Vector(0,0)) - auxi.myScreenToWorld(Vector(0,0))
			local dddir = dir
			if tg then dddir = (tg.Position - d[item.own_key.."record"][i][10]):GetAngleDegrees() end
			d[item.own_key.."record"][i][9] = auxi.checkrounded(d[item.own_key.."record"][i][9] or s1.Rotation,dddir or s1.Rotation,0.7,0.3,360)
			s2.Rotation = d[item.own_key.."record"][i][9]
			s2.Color = col
			s2:Render(tpos,Vector(0,0),Vector(0,0))
		end
	end
end,
})
--[[
if d[item.own_key.."record"][i][10] then 
	tg = auxi.get_nearest_enemy(nil,d[item.own_key.."record"][i][10])
	if tg then dir = (tg.Position - d[item.own_key.."record"][i][10]):GetAngleDegrees() end
end
--]]
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local d2 = player:GetData()
	ent.Position = player.Position + Vector(0,-1)
	ent.Velocity = Vector(0,0)
	ent.DepthOffset = -10
	d[item.own_key.."record"] = d[item.own_key.."record"] or {}
	local ggdir = auxi.ggdir(player)
	if ggdir:Length() > 0.05 then d[item.own_key.."dir"] = ggdir end
	local gdir = (d[item.own_key.."dir"] or Vector(1,0)):GetAngleDegrees()
	local mx = 6 + (player:GetCollectibleNum(item.entity) - 1) * 2
	if auxi.should_do_Seija(player) then 
		d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 0.02
		mx = 1 + (player:GetCollectibleNum(item.entity) - 1)
	end
	if d2[item.own_key.."fire"] then
		for i = 1,mx do
			d[item.own_key.."record"][i] = d[item.own_key.."record"][i] or {}
			local pos = d[item.own_key.."record"][i][10] or player.Position
			local ii = i * 6/mx
			if auxi.should_do_Seija(player) then ii = ii + (d[item.own_key.."counter"] or 0) end
			local dir = auxi.get_by_rotate(nil,ii * 60 + gdir - 90)
			local tg = d[item.own_key.."tg"]
			if auxi.check_all_exists(tg) then dir = (tg.Position - pos):Normalized() end
			local q = player:FireBrimstone(dir,nil,0.3)
			q.Variant = 5
			q.Parent = nil
			d[item.own_key.."record"][i].brim = q
			q.Position = pos
			q.PositionOffset = Vector(0,0)
			local colinfo = auxi.check_lerp((ii * 6) % item.Colorinfo.total,item.Colorinfo)
			q.Color = auxi.table2color(colinfo)
			q:SetTimeout(20)
			local s = q:GetSprite()
			s:Load("gfx/laser_concerter.anm2",true)
			s:Play("LargeRedLaser",true)
			for i = 0,1 do s:ReplaceSpritesheet(i,"gfx/effects/lasers/subera_brimstone.png") end s:LoadGraphics() 
			--for i = 0,1 do s:ReplaceSpritesheet(i,"gfx/effects/lasers/tecro_laser_brimstone.png") end s:LoadGraphics() 
		end
		delay_buffer.addeffe(function(params) SFXManager():Stop(276) end,{},1)
		d2[item.own_key.."fire"] = nil
		d2[item.own_key.."fired"] = {counter = 60 + 20 * item.step_time,}
	end
	for i = 1,mx do
		d[item.own_key.."record"][i] = d[item.own_key.."record"][i] or {}
		if auxi.check_all_exists(d[item.own_key.."record"][i].brim) then
			local q = d[item.own_key.."record"][i].brim
			local pos = d[item.own_key.."record"][i][10] or player.Position
			local ii = i * 6/mx
			if auxi.should_do_Seija(player) then 
				ii = ii + (d[item.own_key.."counter"] or 0)
				local colinfo = auxi.check_lerp((ii * 6) % item.Colorinfo.total,item.Colorinfo)
				q.Color = auxi.table2color(colinfo)
			end
			local dir = auxi.get_by_rotate(nil,ii * 60 + gdir - 90)
			local tg = d[item.own_key.."tg"]
			if auxi.check_all_exists(tg) then dir = (tg.Position - pos):Normalized() end
			q.Position = pos
			q.Angle = auxi.checkrounded(q.Angle,dir:GetAngleDegrees(),0.8,0.2,360)
		end
	end
end,
})

return item
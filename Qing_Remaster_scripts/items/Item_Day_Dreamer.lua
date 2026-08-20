local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local console_holder = require("Qing_Remaster_scripts.others.Console_holder")
local card_06r_lover = require("Qing_Remaster_scripts.cards.Card_06r_lover")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Day_Dreamer,
	own_key = "Item_Day_Dreamer_",
	limit1 = 60 * 5,
	limit2 = 60 * 60,
	description = {
		[CollectibleType.COLLECTIBLE_DREAM_CATCHER] = {desc = "改为进入你的梦境，在其中选择最爱的道具#梦境中按方向键可以行走",},
		[CollectibleType.COLLECTIBLE_PJS] = {desc = "大幅提升进入梦境的速度",},
		[CollectibleType.COLLECTIBLE_BLANKET] = {desc = "翻倍梦境道具的刷新速度",},
	},
	banish_button = {
		[0] = true,
		[1] = true,
		[2] = true,
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		[7] = true,
		[8] = true,
		[9] = true,
		[10] = true,
		[11] = true,
	},
	shining_map = {
		{frame = 0,R = 0,G = 0,B = 0,},
		{frame = 6,R = 0.5,G = 0,B = 0,},
		{frame = 12,R = 0.8,G = 0.3,B = 0,},
		{frame = 18,R = 0.5,G = 0,B = 0,},
		{frame = 24,R = 0,G = 0,B = 0,},
	},
	floating_map = {
		{frame = 0,X = 0,Y = 0,},
		{frame = 6,X = 0,Y = -2,},
		{frame = 12,X = 0,Y = 2,},
		{frame = 18,X = 0,Y = 0,},
		{frame = 24,X = 0,Y = 0,},
	},
	drop_info_map = {
		{frame = 0,Offset = Vector(0,-25),A = 1,Scale = Vector(1,1),},
		{frame = 0.1,Offset = Vector(0,-25),A = 1,Scale = Vector(1,1),},
		{frame = 0.25,Offset = Vector(0,-15),A = 0.6,Scale = Vector(1.2,1.2),},
		{frame = 0.5,Offset = Vector(0,-100),A = 0.3,Scale = Vector(0.5,0.5),},
		{frame = 1,Offset = Vector(0,-400),A = 0.1,Scale = Vector(0.1,0.1),},
	},
	display_info = {
		["zh"] = {
			"我连做梦都是一个失败者",
		},
		["en"] = {
			"I fail even on my dreaming",
		},
	},
}
auxi.add_to_seija(item.entity)

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."buff"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = {}
	save.elses[item.own_key.."buff"] = {}
	delay_buffer.addeffe(function(params)
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local d = player:GetData()
			if auxi.has_have_coll(player,item.entity) then
				local idx = d.__Index
				save.elses[item.own_key.."effect"][idx] = true
			end
		end
	end,{},1)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
	if save.elses[item.own_key.."buff"][idx] then value[save.elses[item.own_key.."buff"][idx]] = (value[save.elses[item.own_key.."buff"][idx]] or 0) + 1 end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		if d[item.own_key.."effect"] then 
			d[item.own_key.."effect"] = nil
			if d[item.own_key.."Mouse"] then d[item.own_key.."Mouse"] = nil console_holder.try_set_temp_option("MouseControl",true) end
		end
		if d[item.own_key.."effect3"] then 
			d[item.own_key.."effect3"] = nil
			if d[item.own_key.."Mouse"] then d[item.own_key.."Mouse"] = nil console_holder.try_set_temp_option("MouseControl",true) end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local d = player:GetData()
	if Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT then
		if d[item.own_key.."effect"] then
			local fr = (d[item.own_key.."effect"]["c1"] or 0) - 60
			if fr >= 0 then
				local s = Sprite()
				s:Load("gfx/mimics/Day_Dreamer/dreaming.anm2",true)
				s:SetFrame("Scene",math.min(18,math.floor(fr/2)))
				s.Scale = Vector(0.3,0.3)
				local rpos = Isaac.WorldToScreen(player.Position + Vector(0,-50))
				s:Render(rpos,Vector(0,0),Vector(0,0))
				if (d[item.own_key.."effect"]["c3"] or 0) > 0 and d[item.own_key.."effect"]["buff"] then
					local fr3 = d[item.own_key.."effect"]["c3"]
					local inval = math.min(1,math.max(0,fr3/60))
					local s = Sprite()
					s:Load("gfx/mimics/Day_Dreamer/dreaming.anm2",true)
					s:ReplaceSpritesheet(3,Isaac.GetItemConfig():GetCollectible(d[item.own_key.."effect"]["buff"]).GfxFileName)
					s:LoadGraphics()
					s:SetFrame("Selection",0)
					s.Color = Color(1,1,1,inval)
					local info = auxi.check_lerp(math.floor(fr/2) % 24,item.floating_map)
					local rpos3 = Isaac.WorldToScreen(player.Position + Vector(0,-65) + Vector(info.X,info.Y))
					s:Render(rpos3,Vector(0,0),Vector(0,0))
				end
				if (d[item.own_key.."effect"]["c2"] or 0) > 0 then
					local fr2 = d[item.own_key.."effect"]["c2"]
					s:SetFrame("Restock",0)
					s.Rotation = (fr * 3) % 360
					s.Scale = Vector(1,1)
					local info = auxi.check_lerp(math.floor(fr/2) % 24,item.shining_map)
					local inval = math.min(1,math.max(0,(fr2/60 - 0.8) * 5))
					s.Color = Color(1,1,1,math.min(1,fr2/60),info.R * inval,info.G * inval,info.B * inval)
					local rpos2 = Isaac.WorldToScreen(player.Position + Vector(35,-65))
					s:Render(rpos2,Vector(0,0),Vector(0,0))
				end
			end
		end
		if d[item.own_key.."effect3"] then
			local fr = (d[item.own_key.."effect3"]["c1"] or 0) - 60
			if fr >= 0 then
				local s = Sprite()
				s:Load("gfx/mimics/Day_Dreamer/dreaming.anm2",true)
				s:SetFrame("Scene",math.min(18,math.floor(fr/2)))
				local rpos = auxi.GetScreenSize() * 0.5
				s:Render(rpos,Vector(0,0),Vector(0,0))
				if fr - 40 > 0 then
					local iv1 = math.min(1,(fr - 40)/20)
					if iv1 > 0.8 then
						local s2 = Sprite()
						s2:Load("gfx/mimics/Day_Dreamer/dreaming.anm2",true)
						for u,v in pairs(d[item.own_key.."effect3"]["tgs"] or {}) do
							local dir = (v.pos or Vector(0,0)) - (d[item.own_key.."effect3"]["pos"] or Vector(0,0))
							local iv2 = dir:Length()
							iv2 = math.max(0,(40 - iv2)/40)
							s2:ReplaceSpritesheet(3,Isaac.GetItemConfig():GetCollectible(v.id or 33).GfxFileName)
							s2:LoadGraphics()
							s2:SetFrame("Selection",0)
							s2.Color = Color(1,1,1,iv2)
							s2:Render(rpos + Vector(0,-30) + dir * 2,Vector(0,0),Vector(0,0))
						end
						s:SetFrame("Targ",0)
						s.Color = Color(1,1,1,(iv1 - 0.8)/0.2)
						local dir = d[item.own_key.."effect3"]["dirs"] or Vector(0,0)
						if dir:Length() > 0.3 then s.Rotation = dir:GetAngleDegrees() - 90 end
						s:Render(rpos + Vector(0,-30) + dir * 20,Vector(0,0),Vector(0,0))
					end
					s:SetFrame("Face",0)
					s.Color = Color(1,1,1,iv1)
					s:Render(rpos + Vector(0,-30),Vector(0,0),Vector(0,0))
				end
			end
		end
		if d[item.own_key.."effect2"] then
			local s = Sprite()
			s:Load("gfx/mimics/Day_Dreamer/dreaming.anm2",true)
			s:SetFrame("Scene",0)
			s:SetLastFrame()
			local ival = (d[item.own_key.."effect2"]["c1"] or 1)/(d[item.own_key.."effect2"]["c2"] or 1)
			s.Color = Color(1,1,1,ival)
			if d[item.own_key.."effect2"]["e3"] then
				local rpos = auxi.GetScreenSize() * 0.5
				s:Render(rpos,Vector(0,0),Vector(0,0))
			else
				s.Scale = Vector(0.3,0.3)
				local rpos = Isaac.WorldToScreen(player.Position + Vector(0,-50))
				s:Render(rpos,Vector(0,0),Vector(0,0))
			end
			if d[item.own_key.."effect2"]["id"] then
				local s = Sprite()
				s:Load("gfx/mimics/Day_Dreamer/dreaming.anm2",true)
				s:ReplaceSpritesheet(3,Isaac.GetItemConfig():GetCollectible(d[item.own_key.."effect2"]["id"]).GfxFileName)
				s:LoadGraphics()
				s:SetFrame("Selection",0)
				local info = auxi.check_lerp(ival,item.drop_info_map)
				s.Color = Color(1,1,1,info.A)
				s.Scale = info.Scale
				s.Offset = info.Offset
				local rpos3 = Isaac.WorldToScreen(player.Position + Vector(0,-10))
				s:Render(rpos3,Vector(0,0),Vector(0,0))
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local s = player:GetSprite()
	local rng = player:GetCollectibleRNG(item.entity)
	local idx = d.__Index
	if (save.elses[item.own_key.."effect"] or {})[idx] and not d[item.own_key.."effect"] then
		local succ = (input_holder.all_nill(player) and player.Velocity:Length() < 0.01)
		if succ then d[item.own_key.."counter1"] = (d[item.own_key.."counter1"] or 0) + 1
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_PJS) then d[item.own_key.."counter1"] = (d[item.own_key.."counter1"] or 0) + 5 end
		else d[item.own_key.."counter1"] = 0 end
		if d[item.own_key.."counter1"] >= item.limit1 then 
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DREAM_CATCHER) then
				d[item.own_key.."effect3"] = {}
				save.elses[item.own_key.."effect"][idx] = nil
			else
				d[item.own_key.."effect"] = {} 
			end
			d[item.own_key.."counter1"] = nil
			if Options.MouseControl then d[item.own_key.."Mouse"] = true console_holder.try_set_temp_option("MouseControl",false) end		--猜猜这个细节是为了什么
		end
	end
	if d[item.own_key.."effect"] then
		player:PlayExtraAnimation("DeathTeleport")
		d[item.own_key.."effect"]["c1"] = (d[item.own_key.."effect"]["c1"] or 0) + 1
		if d[item.own_key.."effect"]["c1"] > 96 then 
			if (d[item.own_key.."effect"]["c4"] or 0) > 0 then
				d[item.own_key.."effect"]["c4"] = d[item.own_key.."effect"]["c4"] - 1
				if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BLANKET) then d[item.own_key.."effect"]["c4"] = d[item.own_key.."effect"]["c4"] - 1 end
			else
				d[item.own_key.."effect"]["c3"] = (d[item.own_key.."effect"]["c3"] or 0) + 1
				local cval = 4
				if auxi.should_do_Seija(player) then cval = 0 end
				d[item.own_key.."effect"]["buff"] = d[item.own_key.."effect"]["buff"] or auxi.random_in_table(card_06r_lover.get_pool(cval),rng)
			end
		end
		if (d[item.own_key.."effect"]["c3"] or 0) > 60 * 3 then 
			d[item.own_key.."effect"]["c2"] = (d[item.own_key.."effect"]["c2"] or 0) + 1
		end
		local ctrlid = player.ControllerIndex
		if (d[item.own_key.."effect"]["c2"] or 0) > 60 then
			local sel = Input.IsActionTriggered(9,ctrlid) or Input.IsActionPressed(9,ctrlid)
			if sel then
				d[item.own_key.."effect"]["c2"] = nil
				d[item.own_key.."effect"]["c3"] = nil
				d[item.own_key.."effect"]["c4"] = 60 * 4 + math.random(60 * 4)
				d[item.own_key.."effect"]["buff"] = nil
				sound_tracker.PlayStackedSound(237,1,1,false,0,2)
			end
		end
		s:SetLastFrame()
		local fr = s:GetFrame()
		fr = math.min(fr,math.floor(d[item.own_key.."effect"]["c1"]/2))
		s:SetFrame("DeathTeleport",fr)
		if d[item.own_key.."effect"]["c1"] >= item.limit2 or (Input.IsActionTriggered(11,ctrlid) or Input.IsActionPressed(11,ctrlid) and (auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_PJS) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BLANKET))) then
			d[item.own_key.."effect2"] = {}
			d[item.own_key.."effect2"]["id"] = d[item.own_key.."effect"]["buff"]
			d[item.own_key.."effect2"]["c1"] = fr
			d[item.own_key.."effect2"]["c2"] = fr
			d[item.own_key.."effect"] = nil
			save.elses[item.own_key.."effect"][idx] = nil
			if d[item.own_key.."Mouse"] then d[item.own_key.."Mouse"] = nil console_holder.try_set_temp_option("MouseControl",true) end
		end
	end
	if d[item.own_key.."effect3"] then
		player:PlayExtraAnimation("DeathTeleport")
		d[item.own_key.."effect3"]["c1"] = (d[item.own_key.."effect3"]["c1"] or 0) + 1
		s:SetLastFrame()
		local fr = s:GetFrame()
		fr = math.min(fr,math.floor(d[item.own_key.."effect3"]["c1"]/2))
		s:SetFrame("DeathTeleport",fr)
		local sel = nil
		if d[item.own_key.."effect3"]["c1"] > 120 then
			d[item.own_key.."effect3"]["dir"] = auxi.ggrealdir(player)
			d[item.own_key.."effect3"]["dirs"] = (d[item.own_key.."effect3"]["dirs"] or Vector(0,0)) * 0.8 + d[item.own_key.."effect3"]["dir"] * 0.2
			d[item.own_key.."effect3"]["pos"] = (d[item.own_key.."effect3"]["pos"] or Vector(0,0)) + d[item.own_key.."effect3"]["dirs"]
			d[item.own_key.."effect3"]["tgs"] = d[item.own_key.."effect3"]["tgs"] or {}
			for i = #d[item.own_key.."effect3"]["tgs"],1,-1 do 
				local v = d[item.own_key.."effect3"]["tgs"][i]
				if (v.pos - d[item.own_key.."effect3"]["pos"]):Length() > 100 then table.remove(d[item.own_key.."effect3"]["tgs"],i) end
			end
			for u,v in pairs(d[item.own_key.."effect3"]["tgs"]) do 
				if sel == nil or (d[item.own_key.."effect3"]["tgs"][sel].pos - d[item.own_key.."effect3"]["pos"]):Length() > (v.pos - d[item.own_key.."effect3"]["pos"]):Length() then 
					if (v.pos - d[item.own_key.."effect3"]["pos"]):Length() < 10 then sel = u end
				end
			end
			if sel and d[item.own_key.."effect3"]["dir"]:Length() < 0.05 then d[item.own_key.."effect3"]["pos"] = d[item.own_key.."effect3"]["pos"] + (d[item.own_key.."effect3"]["tgs"][sel].pos - d[item.own_key.."effect3"]["pos"]) * 0.3 end
			if #d[item.own_key.."effect3"]["tgs"] < 15 then
				local succ = true
				local select_pos = d[item.own_key.."effect3"]["pos"] + auxi.RoundVector(rng,50,{leg2 = 50,})
				for u,v in pairs(d[item.own_key.."effect3"]["tgs"]) do if (v.pos - select_pos):Length() < 20 then succ = false break end end
				local cval = 4
				if auxi.should_do_Seija(player) then cval = 0 end
				if succ then table.insert(d[item.own_key.."effect3"]["tgs"],#d[item.own_key.."effect3"]["tgs"] + 1,{pos = select_pos,id = auxi.random_in_table(card_06r_lover.get_pool(cval),rng),}) end
			end
		end
		local ctrlid = player.ControllerIndex
		if d[item.own_key.."effect3"]["c1"] >= item.limit2 or (Input.IsActionTriggered(11,ctrlid) or Input.IsActionPressed(11,ctrlid)) then
			d[item.own_key.."effect2"] = {}
			if sel then d[item.own_key.."effect2"]["id"] = (d[item.own_key.."effect3"]["tgs"][sel] or {}).id end
			d[item.own_key.."effect2"]["c1"] = fr
			d[item.own_key.."effect2"]["c2"] = fr
			d[item.own_key.."effect2"]["e3"] = true
			d[item.own_key.."effect3"] = nil
			if d[item.own_key.."Mouse"] then d[item.own_key.."Mouse"] = nil console_holder.try_set_temp_option("MouseControl",true) end
		end
	end
	if d[item.own_key.."effect2"] then
		player:PlayExtraAnimation("DeathTeleport")
		d[item.own_key.."effect2"]["c1"] = d[item.own_key.."effect2"]["c1"] - 0.5
		local fr = math.max(0,math.floor(d[item.own_key.."effect2"]["c1"] or 0))
		s:SetFrame("DeathTeleport",fr)
		if fr <= 0 then
			if d[item.own_key.."effect2"]["id"] then
				save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
				save.elses[item.own_key.."buff"][idx] = d[item.own_key.."effect2"]["id"]
				Imitate_item_holder.Evaluate_Imitate_Items(player)
				player:AnimateCollectible(d[item.own_key.."effect2"]["id"],"Pickup","PlayerPickupSparkle")
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2)
			else 
				player:AnimateSad() 
				local language = Options.Language
				local displayinfo = item.display_info[language] or item.display_info["en"]
				item_displaying_holder.check_and_description("ItemDesc",item.entity,displayinfo[1],"",player)
			end
			d[item.own_key.."effect2"] = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if ent ~= nil then
		local player = ent:ToPlayer()
		if player and (player:GetData()[item.own_key.."effect"] or player:GetData()[item.own_key.."effect3"]) then
			if item.banish_button[button] then
				if (hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED) then return false
				elseif hook == InputHook.GET_ACTION_VALUE then return 0 end
			end
		end
	end
end,
})

if EID then
	EID:addDescriptionModifier("qing_item_sync"..tostring(item.entity), function(desc) local ret = auxi.have_player_has_collectible(item.entity) if ret then return true end end, function(desc)
		local tp = desc.ObjType
		local vr = desc.ObjVariant
		local st = desc.ObjSubType
		if (tp == 5 and vr == 100 and item.description[st]) then
			local info = item.description[st].desc
			if (info) then
				info = "#"..info
				local repl = "#{{Collectible"..tostring(item.entity).."}} "
				info = string.gsub(info, "#", repl)
				EID:appendToDescription(desc, info)
			end
		end
		return desc
	end)
	for u,v in pairs(item.description) do
		if u ~= item.entity then
			EID:addDescriptionModifier("qing_item_sync"..tostring(item.entity).."_r_"..tostring(u), function(desc) local ret = auxi.have_player_has_collectible(u) if ret then return true end end, function(desc)
				local tp = desc.ObjType
				local vr = desc.ObjVariant
				local st = desc.ObjSubType
				if (tp == 5 and vr == 100 and st == item.entity) then
					local info = item.description[u].desc
					if (info) then
						info = "#"..info
						local repl = "#{{Collectible"..tostring(u).."}} "
						info = string.gsub(info, "#", repl)
						EID:appendToDescription(desc, info)
					end
				end
				return desc
			end)
		end
	end
end

do
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	temp_hud.register_provider(function(player)
		local idx = player:GetData() and player:GetData().__Index
		if not idx then return end
		local buff = save.elses[item.own_key.."buff"]
		local id = buff and tonumber(buff[idx])
		if not id or id <= 0 then return end
		return {[id] = 1}
	end,{
		rainbow_cellular = true,
		rainbow_seed = 0.17,
		exclusive = true,
		source_item = item.entity,
	})
end

return item
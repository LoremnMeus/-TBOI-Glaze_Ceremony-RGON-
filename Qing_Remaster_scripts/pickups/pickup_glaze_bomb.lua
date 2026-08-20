local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local glaze_key = require("Qing_Remaster_scripts.pickups.pickup_glaze_key")
local glaze_curse = require("Qing_Remaster_scripts.pickups.pickup_glaze_curse")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")
local glaze_crown = require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze")

local item = {
	pickup = enums.Pickups.Glaze_bomb,
	ToCall = {},
	own_key = "Glaze_Bomb",
	morph_vr = {
		[0] = true,
		[1] = true,
		[7] = true,
		[8] = true,
		[11] = true,
		[17] = true,
		[19] = true,
		[20] = true,
	},
	morph_vr2 = {
		[0] = true,
		[17] = true,
		[19] = true,
		[20] = true,
	},
	color_rand = {
		Color(0,0,0.3,0.3,-0.3,-0.3,0.3),
		Color(0,0.3,0,0.3,-0.3,0.3,-0.3),
		Color(0.3,0,0,0.3,0.3,-0.3,-0.3),
		Color(0,0,0,0.3,-0.3,-0.3,-0.3),
	},
}

local frame = 0
local bomb_ui = Sprite()
local bomb_ui2 = Sprite()
bomb_ui:Load("gfx/Glaze/glazed_bomb.anm2", true)
bomb_ui2:Load("gfx/Glaze/glazed_bomb_2.anm2", true)
bomb_ui:Play("Idle",true)
bomb_ui2:Play("Idle",true)
bomb_ui.Scale = Vector(0.4,0.4)
bomb_ui2.Scale = Vector(0.5,0.5)

function item.try_collect(player,ent)
	if ent:IsShopItem() and auxi.check_shop_pickup(ent,player) then return nil end
	if player:HasGoldenBomb() == false then
		player:AddBombs(1)
	end
	save.elses.glaze_bombs = math.min(99,(save.elses.glaze_bombs or 0) + 1)
	glaze_crown.notify_pickup(player)
	return true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = item.pickup.Variant,
Function = function(_,ent, col, low)
    local player = col:ToPlayer()
	if ent.SubType == item.pickup.SubType then
		if player then
			local should_collect = item.try_collect(player,ent)
			if should_collect then
				glaze_curse.cast_a_glaze(player,ent)
				ent.Velocity = Vector(0,0)
				ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_FETUS_FEET,1,1,false,0,2)
				auxi.remove_others_option_pickup(ent)
				if ent:IsShopItem() then auxi.buy_a_pickup(ent,player)
				else ent:GetSprite():Play("Collect", true) end
				return true
			elseif ent:IsShopItem() then return nil 
			else return false end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = item.pickup.Variant,
Function = function(_,ent)
	if ent.SubType == item.pickup.SubType then
		if ent:GetSprite():IsEventTriggered("DropSound") then sound_tracker.PlayStackedSound(SoundEffect.SOUND_FETUS_LAND,1,1,false,0,2) end
		if ent:GetSprite():IsFinished("Collect") or ent:GetSprite():IsEventTriggered("Remove") then	ent:Remove() end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
    if continue then
	else
		save.elses.glaze_bombs = 0
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_BOMB_UPDATE, params = nil,
Function = function(_,ent)
	local s = ent:GetSprite()					
	local d = ent:GetData()
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
    if ent.FrameCount == 0 and item.morph_vr[ent.Variant] and (ent.SpawnerEntity and ent.SpawnerEntity.Type == 1) then
		if ent.IsFetus == false then
			if succ ~= true and (save.elses.glaze_bombs or 0) > 0 then
				succ = true
				consistance_holder.try_hold_entity(ent,item.own_key)
				save.elses.glaze_bombs = save.elses.glaze_bombs - 1
			end
			if succ then
				if item.morph_vr2[ent.Variant] then
					d.colo = auxi.random_in_table(item.color_rand)
					ent:SetColor(d.colo,-1,99,false,false)
				else
					s:ReplaceSpritesheet(0,"gfx/Glaze/glaze_bomb.png")
					s:LoadGraphics()
				end
			end
		end
	end
	
	if succ then
		local should_erase = glaze_crown.any_complete()
		if s:GetFrame() % 10 == 7 then
			d.colo = auxi.random_in_table(item.color_rand)
			ent:SetColor(d.colo,-1,99,false,false)
		end
		
		if (s:IsPlaying("Explode") and s:GetFrame() == 0) or (s:IsPlaying("Pulse") and (should_erase and s:GetFrame()%10 == 7)) then
			local n_entity = Isaac.GetRoomEntities()
			local n_proj = auxi.getothers(n_entity,9)
			for i = 1,#n_proj do 
				Isaac.Spawn(1000,15,0,n_proj[i].Position,Vector(0,0),nil)
				n_proj[i]:Remove()
			end
			consistance_holder.try_remove_entity(ent,item.own_key)
		end
		
		if s:IsPlaying("Pulse") and s:GetFrame() == 56 then
			local level = Game():GetLevel()
			local room = Game():GetRoom()
			local desc = level:GetCurrentRoomDesc()
			if desc.Data.Type == RoomType.ROOM_DEFAULT and desc.Data.Variant >= 10000 and desc.Data.Variant <= 10500 then
				for i = 0,7 do
					local room = Game():GetRoom()
					local door = room:GetDoor(i)
					if door ~= nil and door.TargetRoomIndex == -100 then
						local dis = (ent.Position - door.Position):Length()
						if door.Desc.Variant ~= 8 and dis < 100 then
							save.elses.mirror = true
							save.elses.is_mirror = room:IsMirrorWorld()
						end
					end
				end
			end
		end
	end
	
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_BOMB_COLLISION, params = nil,
Function = function(_,ent,col,low)	
	local room = Game():GetRoom()
	if ent.IsFetus == false then
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ and room:IsMirrorWorld() and save.UnlockData.Others.Ending1.Unlock == true and col.Type == EntityType.ENTITY_FIREPLACE and col.Variant == 4 then
			local s = ent:GetSprite()
			if s:IsPlaying("Pulse") then
				local player = Game():GetPlayer(0)
				if player:GetPlayerType() ~= 25 then
					Isaac.Spawn(5,item.pickup.Variant,item.pickup.SubType,ent.Position,ent.Velocity,nil)
				else
					Isaac.Spawn(5,enums.Pickups.Glaze_big_poop.Variant,enums.Pickups.Glaze_big_poop.SubType,ent.Position,ent.Velocity,nil)
				end
				ent:Remove()
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 40,
Function = function(_,ent)
	if Unlocker.should_any_be_done("Pickup","Glaze_Bomb",nil,"Pickup_allow") then
		if ent.SubType == 1 or ent.SubType == 2 then
			local rng = ent:GetDropRNG()
			rng = auxi.rng_for_sake(rng)
			if glaze_crown.roll_convert(rng, 20) then		-- 原 1/20
				ent:Morph(5,item.pickup.Variant,item.pickup.SubType,true)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = Card.CARD_CLUBS_2,
Function = function(_,card,player,flag)	
	if card == Card.CARD_CLUBS_2 then
		if save.elses.glaze_bombs and save.elses.glaze_bombs > 0 then
			save.elses.glaze_bombs = math.min(99,save.elses.glaze_bombs * 2)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_PILL, params = PillEffect.PILLEFFECT_BOMBS_ARE_KEYS,
Function = function(_,pill,player,flag)	
	if pill == PillEffect.PILLEFFECT_BOMBS_ARE_KEYS then
		if save.elses.glaze_bombs and save.elses.glaze_bombs > 0 then
			for i = 1,save.elses.glaze_bombs do
				glaze_key.reveal_map(player)
			end
			if player:GetPill(0) < PillColor.PILL_GIANT_FLAG then
				save.elses.glaze_bombs = 0
			end
		end
	end
end,
})

local function render_glaze_bomb_hud()
	if not save.elses.glaze_bombs or save.elses.glaze_bombs <= 0 or not Game():GetHUD():IsVisible() then return end
	if Game():IsPaused() == false then frame = frame + 1
	else frame = frame - 1 end
	if frame > 47 then frame = 0 end
	if frame < 0 then frame = 47 end
	bomb_ui:SetFrame(frame)
	local pos = ui.UIBombPos(auxi.is_double_player())
	local ext = save.elses.glaze_bombs - 1
	local player = Game():GetPlayer(0)
	if player:GetNumGigaBombs() == 0 then
		bomb_ui2:Play("Idle",true)
	else
		bomb_ui2:Play("Idle2",true)
	end
	bomb_ui2:SetFrame(frame)
	local alpha = slot_render_holder.get_alpha()
	bomb_ui2.Color = Color(1,1,1,alpha)
	bomb_ui2:Render(pos,Vector(0,0),Vector(0,0))
	if ext > 0 then
		local i_pos = math.ceil(ext/10)
		for i = 1,i_pos do
			local j_pos = ext - (i - 1) * 10
			local dt = 0
			if j_pos > 10 then j_pos = 10 end
			if i > 5 then dt = 1
			else dt = 0 end
			for j = 1,j_pos do
				local tg_fr = frame + math.ceil((j - 1) * 48 / j_pos)
				while tg_fr > 47 do tg_fr = tg_fr - 48 end
				bomb_ui:SetFrame(tg_fr)
				bomb_ui:Render(pos - 5 * auxi.MakeVector(360/j_pos * j + 90) - Vector(10,0) + (i - 1 - dt * 4.5) * Vector(0,16) + dt * Vector(-12,0),Vector(0,0),Vector(0,0))
			end
		end
	end
end

if REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER then
	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_HUD_RENDER, params = nil,
	Function = function(_)
		render_glaze_bomb_hud()
	end,
	})
else
	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
	Function = function(_,shadername)
		if shadername == "Qing_HelpfulShader" then render_glaze_bomb_hud() end
	end,
	})
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if (save.elses.glaze_bombs or 0) > 0 then
		local player = Game():GetPlayer(0)
		if player then
			local bombnun = player:GetNumBombs()
			if player:HasGoldenBomb() and bombnun == 0 then
				bombnun = 1
			end
			if save.elses.glaze_bombs > bombnun then
				save.elses.glaze_bombs = bombnun
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = CollectibleType.COLLECTIBLE_GENESIS,
Function = function(_,collect,rng,player,useFlags,activeSlot,varData)
	save.elses.glaze_bombs = 0
end,
})

return item

local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Priestess_r,
	own_key = "Thoth_cd2r_Pri_",
	costumes = {
		29,31,39,199,200,				--228,
	},
	Priestess_hand_info = {
		[1] = {
			[1] = {frame = 0,offset = Vector(0,0),},
			[2] = {frame = 4,offset = Vector(0,0),},
			[3] = {frame = 14,offset = Vector(0,-200),},
		},
		[2] = {
			{frame = 0,offset = Vector(0,-400),},
			{frame = 6,offset = Vector(0,-150),},
			{frame = 12,offset = Vector(0,0),},
			{frame = 17,offset = Vector(0,0),},
		},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."effect2"] = nil
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	if save.elses[item.own_key.."effect"][idx] then
		if (save.elses[item.own_key.."effect"][idx] or 0) > 0 then
			save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0) - 1
			if (d[item.own_key.."counter"] or 0) > 0 then d[item.own_key.."counter"] = d[item.own_key.."counter"] - 1
			else
				local dir = auxi.ggdir(player,false,true)
				if dir:Length() > 0.05 then
					local q = auxi.fire_nil(player.Position,player.ShotSpeed * 10 * dir,{cooldown = 120,})
					q.DepthOffset = -100
					q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
					local s = q:GetSprite()
					s:Load("gfx/cards/cd02r_Pri_target.anm2",true)
					s:Play("Idle")
					local d2 = q:GetData()
					d2.nil_mode = "card_02r_priestess"
					d2[item.own_key.."effect"] = true
					d2.Params = d2.Params or {}
					d2.Params.HomingDistance = 50
					d2.Params.Homing = true
					d2.Params.Homing2 = true
					d2.Params.checkhoming = function(ent) if auxi.check_all_exists(ent:GetData()[item.own_key.."catched"]) ~= true then return true end end
					
					d[item.own_key.."counter"] = player.MaxFireDelay * 3
				end
			end
		elseif save.elses[item.own_key.."effect"][idx] <= 0 then
			save.elses[item.own_key.."effect"][idx] = nil
			local itemConfig = Isaac.GetItemConfig()
			for u,v in pairs(item.costumes) do
				player:RemoveCostume(itemConfig:GetCollectible(v))
			end
		end
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
		if idx then
			save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
			local tm = 30 * 60
			if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then save.elses[item.own_key.."effect2"] = true else save.elses[item.own_key.."effect2"] = nil end
			save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0) + tm
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MOM_VOX_EVILLAUGH,1,1,false,0,2)
			local itemConfig = Isaac.GetItemConfig()
			for u,v in pairs(item.costumes) do
				player:AddCostume(itemConfig:GetCollectible(v),false)
			end
		end
	end
end,
})

Nil_holder.register("card_02r_priestess", {
	detect = function(d) return d[item.own_key.."effect"] end,
	update = function(ent, d, s)
		if ent:CollidesWithGrid() or d[item.own_key.."linker"] then d[item.own_key.."remove"] = true end
		if d[item.own_key.."remove"] then
			ent.Velocity = ent.Velocity * 0.5
			s.Scale = s.Scale - Vector(0.1,0.1)
			s.Color = auxi.AddColor(s.Color,Color(1,1,1,0),0.9,0.1)
			if s.Color.A < 0.3 then ent:Remove() return end
		else
			local tg = auxi.get_by_nearest_enemy(ent.Position,function(en) if auxi.check_all_exists(en:GetData()[item.own_key.."catched"]) ~= true then return true end end)
			if tg and (tg.Position - ent.Position):Length() < 10 then
				d[item.own_key.."linker"] = tg
				d.follower = tg
				local q = auxi.fire_nil(tg.Position,Vector(0,0),{cooldown = 300,})
				q.DepthOffset = 30
				local d2 = q:GetData()
				d2.nil_mode = "card_02r_priestess_hand"
				d2.follower = tg
				d2[item.own_key.."effect2"] = true
				local s2 = q:GetSprite()
				s2:Load("gfx/cards/cd02r_Pri_hand.anm2",true)
				s2:Play("JumpDown",true)
				tg:GetData()[item.own_key.."catched"] = q
			end
		end
	end,
})

Nil_holder.register("card_02r_priestess_hand", {
	detect = function(d) return d[item.own_key.."effect2"] end,
	update = function(ent, d, s)
		if s:IsFinished("Leave") or s:IsFinished("JumpUp") then ent:Remove() return end
		if auxi.check_all_exists(d.follower) then
			local d3 = d.follower:GetData()
			if s:IsPlaying("Leave") then
				local fr = s:GetFrame()
				if save.elses[item.own_key.."effect2"] and not d.follower:IsBoss() then
					if fr >= 4 then
						d.follower:GetSprite().Offset = auxi.check_lerp(fr,item.Priestess_hand_info[1]).offset
					end
					if fr == 14 then
						d.follower:AddEntityFlags(EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_CHARM)
						local room = Game():GetRoom()
						local pos = room:GetRandomPosition(0)
						if d.follower.GridCollisionClass ~= EntityGridCollisionClass.GRIDCOLL_NONE then pos = room:FindFreeTilePosition(pos,10) end
						d.follower.Position = pos
						local q = auxi.fire_nil(d.follower.Position,Vector(0,0),{cooldown = 300,})
						q.DepthOffset = 30
						local d2 = q:GetData()
						d2.nil_mode = "card_02r_priestess_drop"
						d2.follower = d.follower
						d2[item.own_key.."effect3"] = true
						local s2 = q:GetSprite()
						s2:Load("gfx/cards/cd02r_Pri_hand.anm2",true)
						s2:Play("JumpDown",true)
						d.follower:GetSprite().Offset = Vector(0,-400)
					end
				else
					if fr == 4 then
						if d3[item.own_key.."FREEZE"] then
							Attribute_holder.try_rewind_attribute(d.follower,"EntityFlag_FLAG_FREEZE",d3[item.own_key.."FREEZE"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
							d3[item.own_key.."FREEZE"] = nil
						end
					end
				end
			end
			if s:IsPlaying("Grab") then
				d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) - 1
				if d[item.own_key.."counter"] <= 0 then s:Play("Leave",true) end
			end
			if s:IsFinished("JumpDown") then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_FORESTBOSS_STOMPS,1,1,false,0,2)
				local ti = 3 * 30
				d[item.own_key.."counter"] = ti
				s:Play("Grab",true)
				d3[item.own_key.."FREEZE"] = d3[item.own_key.."FREEZE"] or Attribute_holder.try_hold_attribute(d.follower,"EntityFlag_FLAG_FREEZE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
			end
		else
			if s:IsFinished("JumpDown") then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_FORESTBOSS_STOMPS,1,1,false,0,2)
				s:Play("JumpUp",true)
			end
			if s:IsPlaying("Grab") then
				s:Play("Leave",true)
			end
		end
	end,
})

Nil_holder.register("card_02r_priestess_drop", {
	detect = function(d) return d[item.own_key.."effect3"] end,
	update = function(ent, d, s)
		if s:IsFinished("JumpUp") then ent:Remove() return end
		if auxi.check_all_exists(d.follower) then
			local d3 = d.follower:GetData()
			if s:IsPlaying("JumpDown") then
				local fr = s:GetFrame()
				d.follower:GetSprite().Offset = auxi.check_lerp(fr,item.Priestess_hand_info[2]).offset
			end
			if s:IsFinished("JumpDown") then
				if d3[item.own_key.."FREEZE"] then
					Attribute_holder.try_rewind_attribute(d.follower,"EntityFlag_FLAG_FREEZE",d3[item.own_key.."FREEZE"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
					d3[item.own_key.."FREEZE"] = nil
					if ent.TargetPosition:Length() > 20 then ent.TargetPosition = ent.Position end
				end
			end
		end
		if s:IsFinished("JumpDown") then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_FORESTBOSS_STOMPS,1,1,false,0,2)
			s:Play("JumpUp",true)
		end
	end,
})

return item
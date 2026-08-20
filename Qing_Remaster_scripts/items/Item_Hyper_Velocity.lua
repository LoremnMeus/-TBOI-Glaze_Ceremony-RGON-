local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")

local item = {
	ToCall = {},
	entity = enums.Items.Hyper_Velocity,
	own_key = "Items_Hyper_Velocity_",
	familiar = enums.Entities.Harmony,
	color_map = {
		{frame = 0,A = 0,},
		{frame = 30,A = 1,},
		{frame = 2 * 30,A = 1,},
		{frame = 3 * 30,A = 0,},
		total = 3 * 30,
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local d = player:GetData()
		if (useFlags & (UseFlag.USE_MIMIC | UseFlag.USE_OWNED | UseFlag.USE_NOANIM) == UseFlag.USE_MIMIC | UseFlag.USE_OWNED | UseFlag.USE_NOANIM) then
		else
			if d.is_holding_H_V_item ~= true then
				player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
				d.is_holding_H_V_item = true
			else
				player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
				d.is_holding_H_V_item = false
			end
			return {Discharge = false}
		end
	end
end,
})

function item.Fire_Harmony(player,pos,vel)
	local room = Game():GetRoom()
	player = player or Game():GetPlayer(0)
	local pos = room:GetClampedPosition(pos - vel * 600,5)
	local q = Isaac.Spawn(996,item.familiar,0,pos - vel * 500,Vector(10,0),nil)
	local d = q:GetData()
	local s = q:GetSprite()
	s:Play("Carin",true)
	q:SetSize(28,Vector(1,5),1)
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL 
	d.del_velocity = vel
	d.velocity_cnt = 30
	d.player = player
	local q2 = Isaac.Spawn(1000,enums.Entities.Hyper_Velocity_Track,0,pos,Vector(0,0),nil)
	q2.TargetPosition = pos
	q2.SortingLayer = 0
	local s2= q2:GetSprite()
	s2:Load("gfx/mimics/Hyper_Velocity/Hyper_Velocity.anm2",true)
	s2:Play("TrackLight",true)
	s2.Rotation = vel:GetAngleDegrees() - 90
	s2.Color = Color(0,0,0,0)
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local room = Game():GetRoom()
	if d.is_holding_H_V_item == true then
		if player:IsHoldingItem() == false then
			d.is_holding_H_V_item = false
		else
			local dir = 0
			local ctrlid = player.ControllerIndex
			for i = 4,7 do
				if (Input.IsActionPressed(i,ctrlid) and input_holder.actionsData[tostring(ctrlid)] and input_holder.actionsData[tostring(ctrlid)][i] and input_holder.actionsData[tostring(ctrlid)][i].ActionHoldTime and input_holder.actionsData[tostring(ctrlid)][i].ActionHoldTime == 1) then
					dir = i
				end
			end
			if dir > 0 then
				local vel = Vector(0,0)
				if room:IsMirrorWorld() == true and (dir == 4 or dir == 5) then dir = 9 - dir end
				if dir == 4 then vel = vel + Vector(-1,0)
				elseif dir == 5 then vel = vel + Vector(1,0)
				elseif dir == 6 then vel = vel + Vector(0,-1)
				elseif dir == 7 then vel = vel + Vector(0,1) end
				if d.is_holding_H_V_card then
					player:AnimateCard(d.is_holding_H_V_card,"HideItem")
					d.is_holding_H_V_card = nil
				else
					local slot = auxi.check_slot_with_item(player,item.entity)
					player:UseActiveItem(item.entity,UseFlag.USE_MIMIC | UseFlag.USE_OWNED | UseFlag.USE_NOANIM,slot)
					player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
					player:SetActiveCharge(player:GetBatteryCharge(slot), slot)
					if auxi.should_spawn_wisp(player) then 
						for i = 1,2 do
							player:AddWisp(item.entity,player.Position,false,false) 
						end
					end
				end
				d.is_holding_H_V_item = false
				item.Fire_Harmony(player,player.Position,vel)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Hyper_Velocity_Track,
Function = function(_,ent)
	ent.Velocity = Vector(0,0)
	ent.Position = ent.TargetPosition
	local info = auxi.check_lerp(ent.FrameCount,item.color_map)
	local s = ent:GetSprite()
	s.Color = auxi.table2color(info)
	if ent.FrameCount > item.color_map.total then ent:Remove() end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,
Function = function(_,ent)
	if ent.Variant == item.familiar then
		ent:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS | EntityFlag.FLAG_NO_DAMAGE_BLINK)	--| EntityFlag.FLAG_NO_QUERY
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,
Function = function(_,ent)
	if ent.Variant == item.familiar then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local room = Game():GetRoom()
		if ent.FrameCount % 20 == 1 then
			if d.del_velocity then
				ent.Velocity = d.del_velocity * d.velocity_cnt
				d.velocity_cnt = d.velocity_cnt + 5
			end
		end
		local posid = room:GetGridIndex(ent.Position)
		if posid ~= -1 then
			local dir = auxi.GetDirectionByAngle(ent.Velocity:GetAngleDegrees())
			local posid2 = auxi.GetOffsetedGridIndex(posid,auxi.reverse_the_dir(dir))
			local grid = room:GetGridEntity(posid)
			local grid2 = room:GetGridEntity(posid2)
			if grid and auxi.iswall(grid) then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS,1.5,1,false,0,2)
				Game():BombExplosionEffects(room:GetGridPosition(posid),10,0,Color(1,1,1,1),ent,math.min(3,(d.velocity_cnt - 30)/50 + 1),false,false)
			end
			for i = 1,6 do
				if posid == -1 then break end
				posid = auxi.GetOffsetedGridIndex(posid,dir)
				local grid2 = room:GetGridEntity(posid)
				if grid2 and auxi.issolid(grid2) then
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS,1.5,1,false,0,2)
					Game():BombExplosionEffects(room:GetGridPosition(posid),10,0,Color(1,1,1,1),ent,math.min(3,(d.velocity_cnt - 30)/50 + 1),false,false)
				end
				room:DestroyGrid(posid)
			end
			if grid2 and auxi.issolid(grid2) then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS,1.5,1,false,0,2)
				Game():BombExplosionEffects(room:GetGridPosition(posid2),10,0,Color(1,1,1,1),ent,math.min(3,(d.velocity_cnt - 30)/50 + 1),false,false)
			end
		end
		local ang = ent.Velocity:GetAngleDegrees()
		s.Rotation = ang - 90
		if ent.FrameCount > 1500 then
			ent:Remove()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if (d[item.own_key.."counter"] or 0) > 0 then d[item.own_key.."counter"] = d[item.own_key.."counter"] - 1 end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_NPC_COLLISION, params = 996,
Function = function(_,ent,col,low)
	if ent.Variant == item.familiar then
		local d = ent:GetData()
		local d2 = col:GetData()
		local player = d.player
		if d.velocity_cnt == nil then d.velocity_cnt = 10 end
		if player == nil then player = Game():GetPlayer(0) end
		if col.Type == 996 and col.Variant == item.familiar then		--撞车事故！
			if col.FrameCount > 30 and not d.should_not_explode then
				Game():BombExplosionEffects(col.Position,1000,0,Color(1,1,1,1),ent,5,false,false)
				Game():ShakeScreen(60)
				col:Kill()
				if d.del_velocity then
					ent.Velocity = d.del_velocity * d.velocity_cnt
				end
				delay_buffer.addeffe(function(params)
					local ent = params.ent
					if ent and ent:Exists() and ent:IsDead() == false then
						local d = ent:GetData()
						if d.del_velocity then
							ent.Velocity = d.del_velocity * d.velocity_cnt
						end
						d.velocity_cnt = d.velocity_cnt + 10
					end
				end,{ent = ent,},1)
			else
				if d.del_velocity then
					ent.Velocity = d.del_velocity * d.velocity_cnt
					col.Velocity = Vector(0,0)
				end
			end
		else
			if (d2[item.own_key.."counter"] or 0) <= 0 then		--似乎还有不能被撞到的敌人。
				col:AddEntityFlags(EntityFlag.FLAG_EXTRA_GORE | EntityFlag.FLAG_KNOCKED_BACK)
				if col:IsVulnerableEnemy() then			--撞上会受伤的敌人
					col:TakeDamage(5 * player.Damage + 250,DamageFlag.DAMAGE_IGNORE_ARMOR,EntityRef(player),0)
					Game():ShakeScreen(5)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS,1.5,1,false,0,2)
					d2[item.own_key.."counter"] = 3
				elseif col.Type ~= 1 then
					if auxi.check_for_the_same(d2[item.own_key.."effect"],ent) then
					else
						Game():BombExplosionEffects(col.Position,10,0,Color(1,1,1,1),ent,math.min(3,(d.velocity_cnt - 30)/50 + 1),false,false)
						Game():ShakeScreen(5)
						d2[item.own_key.."effect"] = ent
						--if col.FrameCount > 10 and not col:GetSprite():IsPlaying("Appear") and col.MaxHitPoints == col.HitPoints then		--似乎是不受伤的敌人
							--if (col:IsBoss() == true and col.Type ~= EntityType.ENTITY_GIDEON) or (col.Type == 960 and col.Variant == 4) then end
						--end
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS,2,1,false,1,2)
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS,2,1,false,-1,2)
					end
				end
				if col.Type == 1 then
					delay_buffer.addeffe(function(params)
						local tg_player = col:ToPlayer()
						if tg_player and tg_player:GetHearts() + player:GetSoulHearts() + player:GetBoneHearts() <= 0 then
							Unlocker.unlock_achievement(save.UnlockData.Others.Crushed,"Unlock",{Achievement_page = "gfx/ui/Some achievements/" .. enums.AchievementGraphics.others.Crush .. ".png",})
						end
					end,{},1)
				end
			else
				Attribute_holder.try_hold_and_rewind_attribute(col,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE,10)
				Game():BombExplosionEffects(col.Position,10,0,Color(1,1,1,1),ent,math.min(3,(d.velocity_cnt - 30)/50 + 1),false,false)
				Game():ShakeScreen(5)
			end
		end
		if d.del_velocity then
			ent.Velocity = d.del_velocity * d.velocity_cnt
			delay_buffer.addeffe(function(params)
				local ent = params.ent
				if ent and ent:Exists() and ent:IsDead() == false then
					local d = ent:GetData()
					if d.del_velocity then
						ent.Velocity = d.del_velocity * d.velocity_cnt
					end
					d.velocity_cnt = d.velocity_cnt + 10
				end
			end,{ent = ent,},1)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player then
		if amt >= 2 then
			local n_wisp = auxi.get_wisps(player,item.entity)
			if #n_wisp > 0 then
				for u,v in pairs(n_wisp) do
					v:Remove()
				end
				player:SetMinDamageCooldown(cooldown)
				return false
			end
		end
	end
end,
})

return item
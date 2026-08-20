local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local tear_trigger_holder = require("Qing_Remaster_scripts.callbacks.tear_trigger_holder")

local item = {
	myToCall = {},
	ToCall = {},
	post_ToCall = {},
	entity = enums.Items.Tears_of_Pearl,
}

function item.fire_pearl_tear(ent,pos,vel,player)
	local q = ent or Isaac.Spawn(2,0,0,pos,vel,player):ToTear()
	local s2 = q:GetSprite()
	s2:Load("gfx/mimics/Tears_of_Pearl/Pearl_Tear.anm2",true)
	s2:Play("Idle",true)
	q:GetData().is_pearl_tear = true
	q.TearFlags = q.TearFlags & (~BitSet128(1<<60,0))
	return q
end

--table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_FIRE_TRIGGER, params = nil,
--Function = function(_,tp,ent,pos,player,dir)
--	if tear_trigger_holder.framecheck(tp,ent,player) then
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_FIRE_TRIGGER_IN_FRAME, params = nil,
Function = function(_,tp,ent,pos,player,dir)
		if player and (auxi.has_have_coll(player,item.entity)) then
			if auxi.check_rand(player.Luck,15,5,15) then
				if tp == "Tear" then 
					local q = ent
					local d = ent:GetData()
					if d.Ignore_me_flag == nil then
						if not d.Dont_Remove then q = item.fire_pearl_tear(ent,nil,nil,player)
						else q = item.fire_pearl_tear(nil,ent.Position,ent.Velocity,player) end
					end
				else
					local mulinfo = tear_trigger_holder.multi_check(tp,ent,player)
					local rounded = mulinfo.rounded
					if dir == nil or dir:Length() < 0.01 then rounded = true end
					local ddir = tear_trigger_holder.dir_info_check(tp,ent,dir)
					for i = 1,mulinfo.cnt do
						local tdir = tear_trigger_holder.dir_info_check(tp,ent,dir)
						if rounded then tdir = auxi.get_by_rotate(ddir,i * 360/mulinfo.cnt) end
						item.fire_pearl_tear(nil,pos or ent.Position,tdir * player.ShotSpeed * 10,player)
					end
				end
			end
		end
--	end
end,
})
--[[
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_FIRE_TEAR, params = nil,
Function = function(_,ent)
	local room = Game():GetRoom()
	local s = ent:GetSprite()
	local d = ent:GetData()
	if d.Tears_of_Pearl_conter == nil and d.Ignore_me_flag == nil then
		d.Tears_of_Pearl_conter = true
		local player = auxi.check_spawner_player(ent)
		if player and (auxi.has_have_coll(player,item.entity)) then
			if auxi.check_rand(player.Luck,15,5,15) then
				if not d.Dont_Remove then 
					s:Load("gfx/mimics/Tears_of_Pearl/Pearl_Tear.anm2",true)
					s:Play("Idle",true)
					d.is_pearl_tear = true
					ent.TearFlags = ent.TearFlags & (~BitSet128(1<<60,0))
				else
					local q = Isaac.Spawn(2,0,0,ent.Position,ent.Velocity,nil):ToTear()
					local s2 = q:GetSprite()
					s2:Load("gfx/mimics/Tears_of_Pearl/Pearl_Tear.anm2",true)
					s2:Play("Idle",true)
					q:GetData().is_pearl_tear = true
					q.TearFlags = q.TearFlags & (~BitSet128(1<<60,0))
				end
			end
		end
	end
end,
})
--]]
table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local d = ent:GetData()
	if d.is_pearl_tear then
		d.pearl_bounce_counter = (d.pearl_bounce_counter or 0) + 1
	end
end,
})


table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	if d.is_pearl_tear then
		if d.Pearl_state_2 or ent.Height > -5 then
			d.Pearl_state_2 = true
			ent.TearFlags = ent.TearFlags & (~BitSet128(1<<1,0))
			ent.Height = -5
			ent.FallingSpeed = 0
			d.Pearl_acce_del = (d.Pearl_acce_del or 0.6) * 0.98 + 0.6 * 0.02
			ent.Velocity = ent.Velocity * d.Pearl_acce_del
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				local dir = player.Position - ent.Position
				if dir:Length() < 20 then
					ent.Velocity = ent.Velocity - dir * 0.2 + player.Velocity * 0.4
					d.Pearl_acce_del = 1
				end
			end
			local n_entity = Isaac.GetRoomEntities()
			local n_proj = auxi.getothers(n_entity,9)
			for u,v in pairs(n_proj) do
				if (v.Position - ent.Position):Length() < 20 then
					v = v:ToProjectile()
					local q = Isaac.Spawn(2,0,0,v.Position,-v.Velocity,nil):ToTear()
					local s2 = v:GetSprite()
					local s3 = q:GetSprite()
					s3:Load(s2:GetFilename(),true)
					s3:Play(s2:GetAnimation(),true)
					s3.Color = s2.Color
					s3.Scale = s2.Scale
					q.Height = v.Height
					q.FallingSpeed = v.FallingSpeed
					q.FallingAcceleration = v.FallingAccel
					local q2 = Isaac.Spawn(1000,133,0,ent.Position,Vector(0,0),nil)
					d.pearl_bounce_counter = (d.pearl_bounce_counter or 0) + 1
					v:Remove()
				end
			end
			if (d.pearl_bounce_counter or 0) < 5 then
				ent.TearFlags = ent.TearFlags | BitSet128(1<<19,0)
			else
				ent.TearFlags = ent.TearFlags & (~BitSet128(1<<19,0))
			end
		end
	end
end,
})

return item
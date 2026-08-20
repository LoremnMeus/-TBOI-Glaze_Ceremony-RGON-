local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Laser_holder = require("Qing_Remaster_scripts.mimics.Laser_holder")
local tear_trigger_holder = require("Qing_Remaster_scripts.callbacks.tear_trigger_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Evil_Intervention,
	own_key = "Item_Evil_Intervention_",
	tear_sprite = "gfx/mimics/Evil_Intervention/Evil_I_Tear.anm2",
}

function item.have_Ev_I_tear()
	local n_entity = Isaac.GetRoomEntities()
	local n_tear = auxi.getothers(n_entity,2)
	for u,v in pairs(n_tear) do if v:GetData()[item.own_key.."effect"] then return true end end
end

function item.load_tear_sprite(q)
	if not q then return end
	local s2 = q:GetSprite()
	s2:Load(item.tear_sprite,true)
	s2:Play("Idle",true)
	return q
end

function item.fire_fetus_tear(player,pos,vel,params)
	params = params or {}
	local q = auxi.fire_fetus(nil,player,pos,vel,true,true,{dmg = params.dmg,tearflags = params.tearflags,should_not_sound = params.should_not_sound,})
	item.load_tear_sprite(q)
	q.TearFlags = q.TearFlags | BitSet128(1<<0,0) | BitSet128(1<<1,0)
	return q
end

function item.fire_Ev_I_tear(q,pos,vel,player)
	q = q or Isaac.Spawn(2,0,0,pos,vel,player):ToTear()
	item.load_tear_sprite(q)
	q:GetData()[item.own_key.."effect"] = {}
	q.TearFlags = q.TearFlags & (~BitSet128(1<<60,0))
	q.TearFlags = q.TearFlags | BitSet128(1<<1,0) | BitSet128(1<<0,0) | BitSet128(1<<2,0) | BitSet128(0,1<<(114-64))
	q.FallingSpeed = q.FallingSpeed - auxi.random_1() * 2
	q.FallingAcceleration = q.FallingAcceleration - auxi.random_1() * 0.1
	return q
end

--table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_FIRE_TRIGGER, params = nil,
--Function = function(_,tp,ent,pos,player,dir)
--	if tear_trigger_holder.framecheck(tp,ent,player) then
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_FIRE_TRIGGER_IN_FRAME, params = nil,
Function = function(_,tp,ent,pos,player,dir)
		if player and (auxi.has_have_coll(player,item.entity)) and unique_holder.quest_signal_hash(item.own_key) ~= true then
			if auxi.check_rand(player.Luck,20,5,7) then
				if tp == "Tear" then 
					local q = ent
					local d = ent:GetData()
					if d.Ignore_me_flag == nil then
						if not d.Dont_Remove then q = item.fire_Ev_I_tear(ent,nil,nil,player)
						else q = item.fire_Ev_I_tear(nil,ent.Position,ent.Velocity,player) end
					end
				else
					local mulinfo = tear_trigger_holder.multi_check(tp,ent,player)
					local rounded = mulinfo.rounded
					if dir == nil or dir:Length() < 0.01 then rounded = true end
					local ddir = tear_trigger_holder.dir_info_check(tp,ent,dir)
					for i = 1,mulinfo.cnt do
						local tdir = tear_trigger_holder.dir_info_check(tp,ent,dir)
						if rounded then tdir = auxi.get_by_rotate(ddir,i * 360/mulinfo.cnt) end
						item.fire_Ev_I_tear(nil,pos or ent.Position,tdir * player.ShotSpeed * 10,player)
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
	if d[item.own_key.."counter"] == nil and d.Ignore_me_flag == nil then
		d[item.own_key.."counter"] = {}
		local player = auxi.check_spawner_player(ent)
		if player and (auxi.has_have_coll(player,item.entity)) then
			if auxi.check_rand(player.Luck,30,10,5) then
				local q = ent
				if not d.Dont_Remove then q = item.fire_Ev_I_tear(ent,nil,nil,player)
				else q = item.fire_Ev_I_tear(nil,ent.Position,ent.Velocity,player) end
			end
		end
	end
end,
})
--]]
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local n_entity = Isaac.GetRoomEntities()
		local n_proj = auxi.getothers(n_entity,9)
		for u,v in pairs(n_proj) do
			if (v.Position - ent.Position):Length() < ent.Size + v.Size + 5 and math.abs(v.PositionOffset.Y - ent.PositionOffset.Y) < 30 then
				d[item.own_key.."effect"].tear = (d[item.own_key.."effect"].tear or 0) + 1
				v:Remove()
			end
		end
		--ent:GetSprite().Scale = Vector(1,1) * math.sqrt((d[item.own_key.."effect"].size or ent.Size)/ent.Size)
		--ent.Scale = (d[item.own_key.."effect"].size or ent.Size)/ent.Size
		--ent:ResetSpriteScale()
		local n_laser = auxi.getothers(n_entity,7)
		for u,v in pairs(n_laser) do
			if v.SubType == 0 and auxi.check_spawner_player(v) == nil and auxi.check_all_exists(v:GetData()[item.own_key.."Linker"]) ~= true then
				if auxi.on_laser_path(v:ToLaser(),ent.Position,{margin = ent.Size + v.Size,}) then v:GetData()[item.own_key.."Linker"] = ent v:ToLaser().TearFlags = BitSet128(0,0) d[item.own_key.."effect"].Attached = true end
			end
		end
		if d[item.own_key.."effect"].Attached then 
			if not d[item.own_key.."effect"].ChangeFlag then 
				ent.TearFlags = ent.TearFlags | BitSet128(0,1<<(82-64)) 
				ent.TearFlags = ent.TearFlags & ~(BitSet128(1<<2,0)|BitSet128(0,1<<(114-64)))
			end
		end
		if ent:IsDead() then 
			local player = auxi.check_spawner_player(ent)
			unique_holder.signal_hash(item.own_key,true)
			for i = 1,(d[item.own_key.."effect"].tear or 0) do
				local q = player:FireTear(ent.Position,auxi.random_r() * player.ShotSpeed * 10,true,true,true)
			end
			local cnt2 = 3 * math.ceil(d[item.own_key.."effect"].laser or 0)
			for i = 1,cnt2 do
				local q = player:FireBrimstone(auxi.random_r(),nil,0.5)
				q.DisableFollowParent = true
				q.TearFlags = q.TearFlags & ~(BitSet128(1<<19,0))
				q.Position = ent.Position
			end
			unique_holder.signal_hash(item.own_key,nil)
		end
		--d[item.own_key.."effect"].height = d[item.own_key.."effect"].height or ent.Height
		--ent.Height = d[item.own_key.."effect"].height
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_LASER_INIT_2_UPDATE, params = nil,
Function = function(_,v)
	if v.SubType == 0 and auxi.check_spawner_player(v) == nil and Laser_holder.is_new_laser(v) and auxi.check_all_exists(v:GetData()[item.own_key.."Linker"]) ~= true and item.have_Ev_I_tear() then
		local ep = EntityLaser.CalculateEndPoint(v.Position,auxi.get_by_rotate(Vector(1,0),v.Angle),v.PositionOffset,v.Parent,0)
		local n_tear = auxi.getothers(n_entity,2)
		for uu,vv in pairs(n_tear) do if vv:GetData()[item.own_key.."effect"] then
			if auxi.on_laser_path(v:ToLaser(),vv.Position,{margin = vv.Size + v.Size,ep = ep,}) then
			v:GetData()[item.own_key.."Linker"] = vv v:ToLaser().TearFlags = BitSet128(0,0) vv:GetData()[item.own_key.."effect"].Attached = true 
			Laser_holder.ProtectLaser(v) v:GetData()[item.own_key.."Protected"] = true 
			--v:Update()
			break end
		end end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if auxi.check_all_exists(d[item.own_key.."Linker"]) then
		local tg = d[item.own_key.."Linker"] local d2 = tg:GetData() 
		if d2[item.own_key.."effect"] then d2[item.own_key.."effect"].laser = (d2[item.own_key.."effect"].laser or 0) + 0.1 end
		local dir = tg.Position - ent.Position
		ent.Angle = dir:GetAngleDegrees()
		ent.MaxDistance = math.max(0,dir:Length() - ent.Size)
	end
	if d[item.own_key.."Protected"] then Laser_holder.UnProtectLaser(ent) end
end,
})

return item

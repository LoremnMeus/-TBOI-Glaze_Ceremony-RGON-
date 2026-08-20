local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	post_ToCall = {},
	entity = enums.Items.Field,
	effect = enums.Entities.trans_field_door,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local cnt = player:GetCollectibleNum(item.entity)
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * cnt)
        end
	end
end,
})
--[[
table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_,ent,col,low)
	if ent:GetData().field_first_count == nil then
		ent:GetData().field_first_count = 1
	else
		ent:GetData().field_first_count = ent:GetData().field_first_count + 1
	end
end,
})
--]]
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d.field_now_color then
		ent.Color = d.field_now_color
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_RENDER, params = nil,
Function = function(_,ent)
	local should_count = false
	local should_fly = false
	local player = Game():GetPlayer(0)
	for playerNum = 1, Game():GetNumPlayers() do
		local t_player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(t_player,item.entity) then
			should_count = true
			if auxi.getmov(t_player):Length() < 1e-2 then
				should_fly = true
			end
			player = t_player
		end
	end
	if ent:GetData().ignore_field then should_count = false end
	if should_count and Game():IsPaused() == false and ent.PositionOffset.Y < -15 and ent.TearFlags & BitSet128(1<<59,0) ~= BitSet128(1<<59,0) then
		local d = ent:GetData()
		if d.field_pre_speed == nil then d.field_pre_speed = 0 end
		if should_fly then
			d.field_pre_acce_speed = -(player.ShotSpeed - 0.3) * 0.3
			if d.pre_velocity == nil then
				d.pre_velocity = ent.Velocity
			end
			if ent.Velocity:Length() > 1e-4 then
				ent.Velocity = ent.Velocity * 0.95
			end
		else
			d.field_pre_acce_speed = 0.03
			if d.field_pre_speed < 0 then
				d.field_pre_speed = 0
			end
			if ent.Height < -60 and ent.Velocity:Length() < 15 then
				ent.Velocity = ent.Velocity * (-ent.Height + 3000)/3000
			end
		end
		ent.Height = ent.Height + d.field_pre_speed
		d.field_pre_speed = math.max(-7,math.min(7,d.field_pre_acce_speed + d.field_pre_speed))
		if d.field_color == nil then d.field_color = ent.Color end
		if (5 + Isaac.WorldToScreen(ent.Position).Y) ~= 0 then
			ent.Color = auxi.AddColor(d.field_color,Color(0.5,0.5,0.5,0.8,0.5,0,0.5),1 + ent.PositionOffset.Y/(5 + Isaac.WorldToScreen(ent.Position).Y), - ent.PositionOffset.Y/(5 + Isaac.WorldToScreen(ent.Position).Y))
			d.field_now_color = ent.Color
		end
		if Isaac.WorldToScreen(ent.Position + ent.PositionOffset).Y < 0 and (d.field_trans_door == nil or d.field_trans_door:Exists() == false) then
			local q = Isaac.Spawn(1000,item.effect,0,ent.Position,Vector(0,0),player):ToEffect()
			local d2 = q:GetData()
			d.field_trans_door = q
			d2.field_trans_tear = ent
			if ent.Velocity:Length() > 1e-4 then
				ent.Velocity = ent.Velocity:Normalized() * 0.25
			end
		end
		if ent.Height > -10 then
			if ent.TearFlags & BitSet128(0,1<<63) == BitSet128(0,1<<63) then
				ent.Height = -10
			end
		end
		--print(ent.Height.." "..ent.FallingSpeed.." "..ent.FallingAcceleration.." "..ent.PositionOffset.X.." "..ent.PositionOffset.Y)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.effect,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	if d.field_trans_tear == nil or d.field_trans_tear:Exists() == false then
		ent:Remove()
	else
		if s:IsFinished("Appear") then
			s:Play("Spawn",true)
			local tear = d.field_trans_tear
			local d2 = tear:GetData()
			tear.Position = ent.Position
			if d2.pre_velocity then
				tear.Velocity = d2.pre_velocity
			end
			tear.Height = -10
			if d2.field_pre_speed then
				d2.field_pre_speed = math.max(-1,math.min(1,d2.field_pre_speed))
			end
		end
		if s:IsFinished("Spawn") then
			ent:Remove()
		end
	end
end,
})

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	enemy = enums.Enemies.Bum_spear,
}

local function add_flip(npc)
	local v = npc.Velocity
    if v.X < -0.0005 then
        npc:GetSprite().FlipX = true
    elseif v.X > 0.0005 then
        npc:GetSprite().FlipX = false
    end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,	--初始化
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
		if d.State == nil then
			d.State = 0
		end
		d.invi = 0
		s:Play("Idle",true)
		ent:SetSize(8,Vector(1,4),0)
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS
		ent.GridCollisionClass = GridCollisionClass.COLLISION_NONE
		ent:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 996,	--自己写个减伤
Function = function(_,ent,amt,flag,source,cooldown)
	if ent.Variant == item.enemy then
		return false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = 996,	--死亡
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 996,	--移除
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = 45,
Function = function(_,ent,col,low)
	if col.Variant == item.enemy and col.Type == 996 then
		return false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,		--速度、位移调整
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,		--行为、战斗控制
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local player = Game():GetPlayer(0)
		local hud = Game():GetHUD()
		if d.State == nil then
			d.State = 0
		end
		if d.owner and d.owner:Exists() == false then
			ent:Remove()
		end
		if d.owner then
			local d2 = d.owner:GetData()
			if d2.position_control then
				ent.Position = ent.Position * 0.9 + (d2.position_control) * 0.1
			elseif d2.velocity_offset then
				ent.Position = ent.Position * 0.9 + (d.owner.Position + auxi.MakeVector(d2.velocity_offset) * (90)) * 0.1
			else
				ent.Position = ent.Position * 0.9 + (d.owner.Position + d.owner.Velocity:Normalized() * (30)) * 0.1
			end
			ent.Velocity = d.owner.Velocity
			if d2.rotate_control then
				s.Rotation = auxi.checkrounded(s.Rotation,d2.rotate_control,0.8,0.2,360)
			elseif d2.rotate_target then
				s.Rotation = auxi.checkrounded(s.Rotation,(d2.rotate_target.Position - ent.Position):GetAngleDegrees() + 90 + (d2.rotate_target_offset or 0),0.8,0.2,360)
			elseif d2.velocity_offset then
				s.Rotation = auxi.checkrounded(s.Rotation,d2.velocity_offset + 90,0.8,0.2,360)
			else
				s.Rotation = auxi.checkrounded(s.Rotation,ent.Velocity:GetAngleDegrees() + 90,0.8,0.2,360)
			end
			s.Rotation = s.Rotation % 360
			if d2.rotate_control_Offset then
				s.Offset = d2.rotate_control_Offset
			else
				s.Offset = Vector(0,0)
			end
		end
		if s:IsPlaying("Idle") then
			
		end
	end
end,
})

return item
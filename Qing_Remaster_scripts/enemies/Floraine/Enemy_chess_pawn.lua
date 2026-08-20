local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	enemy = enums.Enemies.chess_piece,
	own_key = "Enemies_chess_piece_",
	info = {		--所有棋子的行为逻辑
		[1] = {
			sprite = "gfx/boss/Floraine/queen_pieces.png",
			vel = 0.1,
			target = {Vector(40,0),Vector(-40,0),Vector(40,40),Vector(40,-40),Vector(-40,40),Vector(-40,-40),Vector(0,40),Vector(0,-40),},
			multi = 5,
		},
		[2] = {
			sprite = "gfx/boss/Floraine/vehicle_pieces.png",
			vel = 0.2,
			target = {Vector(40,0),Vector(-40,0),Vector(0,40),Vector(0,-40),},
			multi = 7,
		},
		[3] = {
			sprite = "gfx/boss/Floraine/bishop_pieces.png",
			vel = 0.15,
			target = {Vector(40,40),Vector(-40,40),Vector(40,-40),Vector(-40,-40),},
			multi = 5,
		},
		[4] = {
			sprite = "gfx/boss/Floraine/knight_pieces.png",
			vel = 0.07,
			target = {Vector(80,40),Vector(80,-40),Vector(40,80),Vector(-40,80),Vector(-80,40),Vector(-80,-40),Vector(40,-80),Vector(-40,-80),},
		},
		[5] = {
			sprite = "gfx/boss/Floraine/pawn_pieces.png",
			vel = 0.5,
			target = {Vector(40,0),Vector(-40,0),Vector(40,40),Vector(40,-40),Vector(-40,40),Vector(-40,-40),Vector(0,40),Vector(0,-40),},
		},
	},
	check_point = {},
}
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.check_point = {}
end,
})
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item.check_point = {}
end,
})

function item.generate_pawn(id,pos,params)		--删去了所有意义不明的参数
	id = id or 1
	params = params or {}
	local q = Isaac.Spawn(996,item.enemy,id,pos,params.vel or Vector(0,0),params.spawner) local d = q:GetData()
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,		--初始化
Function = function(_,ent)
	if ent.Variant == item.enemy then
		ent.State = ent.State or 0
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE ent.GridCollisionClass = GridCollisionClass.COLLISION_NONE
		local s = ent:GetSprite() local d = ent:GetData()
		s:Play("Appearing",true)
		ent:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
		local info = item.info[ent.SubType] or item.info[1]
		
		local s = ent:GetSprite()
		s:ReplaceSpritesheet(0,info.sprite or "gfx/boss/Floraine/queen_pieces.png")
		s:LoadGraphics()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = 45,	--防止橡皮擦
Function = function(_,ent,col,low)
	if col.Variant == item.enemy and col.Type == 996 then
		if auxi.check_all_exists(col.Spawner) and col.Spawner.Type == 996 then
			local Floraine = require("Qing_Remaster_scripts.enemies.Floraine.Enemy_Floraine")
			Floraine.add_word(col.Spawner,5)
		end
		return false
	end
end,
})

function item.check_available(pos)
	local room = Game():GetRoom()
	local gidx = room:GetGridIndex(pos)
	if room:GetGridPath(gidx) <= 100 and auxi.check_all_exists(item.check_point[gidx]) ~= true then return true 
	else return false end
end

function item.check_line(ent)
	local ret = {}
	local info = item.info[ent.SubType] or item.info[1]
	for i = 1,(info.multi or 1) do 
		for j = 1,#info.target do
			local dir = i * info.target[j]
			if item.check_available(ent.Position + dir) then table.insert(ret,ent.Position + dir) end
		end
	end
	return ret
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local room = Game():GetRoom()
		local gidx = room:GetGridIndex(ent.Position)
		
for i = 1,1 do 
		if s:IsPlaying("Idle") then
			local move_line = item.check_line(ent)
			local target = auxi.get_acceptible_target(ent)
			if target then d[item.own_key.."target"] = target end
			local selected = auxi.draw_scan(function(val,info) if (val - target.Position):LengthSquared() < (info.val - target.Position):LengthSquared() then info.val = val end return info end,move_line,{val = ent.Position,})
			if (selected.val - ent.Position):LengthSquared() < 0.01 then else 
				local tgid = room:GetGridIndex(selected.val)
				d[item.own_key.."target"] = {start_pos = ent.Position,end_pos = selected.val,tgid = tgid,}
				s:Play("Float",true) 
				item.check_point[tgid] = ent
				break
			end
			room:SetGridPath(gidx,500)
			ent.Velocity = ent.Velocity * 0.5
		end
		if s:IsPlaying("Floating") then
			local tginfo = d[item.own_key.."target"] if tginfo == nil then s:Play("Down",true) break end
			ent.Velocity = ent.Velocity * 0.6 + 0.4 * (tginfo.end_pos - ent.Position):Normalized() * ((tginfo.end_pos - tginfo.start_pos):Length()/5 * 0.3 + (tginfo.end_pos - ent.Position):Length() * 0.5 * 0.6)
			if (tginfo.end_pos - ent.Position):Length() < 2 then s:Play("Down",true) end
		end
end
		if s:IsPlaying("Float") then if s:IsEventTriggered("Float") then ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE end end
		if s:IsPlaying("Down") then ent.Velocity = ent.Velocity * 0.5 if s:IsEventTriggered("Down") then ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS end end
		if s:IsFinished("Float") then s:Play("Floating") end
		if s:IsFinished("Appearing") then s:Play("Idle",true) ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS end
		if s:IsFinished("Down") then s:Play("Idle",true) 
			if d[item.own_key.."target"] then item.check_point[d[item.own_key.."target"].tgid or -1] = nil end 
			room:SetGridPath(gidx,500)
		end
		ent.Velocity = auxi.apply_friction(ent.Velocity,1)
	end
end,
})

	
return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Air_Terror,
	familiar = enums.Familiars.Air_Terror,
	own_key = "Item_Air_Terror_",
	angle2bonus = {
		{frame = 0,val = 0,},
		{frame = 60,val = 0.2,},
		{frame = 90,val = 0.75,},
		{frame = 180,val = 1,},
	},
	base_offset = Vector(0,-30),
}

local function get_blueprint()
	return require("Qing_Remaster_scripts.items.Item_Blue_Print")
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		local bp = get_blueprint()
		local cnt = (bp and bp.familiar_check_count and bp.familiar_check_count(player, item.entity))
			or player:GetCollectibleNum(item.entity)
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent)
	local s = ent:GetSprite()
	ent.PositionOffset = Vector(0,-30)
	local ed = ent:GetData() 
	ed[item.own_key.."effect"] = ed[item.own_key.."effect"] or {counter = 0,}
	local d = player:GetData()
	d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
	local cnt = #d[item.own_key.."effect"] + 1
	for i = #d[item.own_key.."effect"],1,-1 do if auxi.check_all_exists(d[item.own_key.."effect"][i]) ~= true then table.remove(d[item.own_key.."effect"],i) end end
	table.insert(d[item.own_key.."effect"],ent)
	for i = 1,#d[item.own_key.."effect"] do 
		local v = d[item.own_key.."effect"][i]
		v:GetData()[item.own_key.."effect"].counter = ((d[item.own_key.."effect"][1]:GetData()[item.own_key.."effect"] or {}).counter or 0) + (i-1)/(#d[item.own_key.."effect"]) * 360
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local room = Game():GetRoom()
	local player = auxi.check_spawner_player(ent)
	--local dir = player:GetFireDirection()
	d[item.own_key.."effect"] = d[item.own_key.."effect"] or {counter = 0,}
	d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
	
	local target = nil
	local rotate = nil
	local cut_off = -20
	local veldir = ent.Velocity
	local tgs = auxi.getothers(9,nil,nil,nil,function(et) if (et.Position - ent.Position):Length() < 200 then return true else return false end end)
	for i = #tgs,1,-1 do local v = tgs[i] if (v.Position - ent.Position):Length() < 20 then 
		local q = Isaac.Spawn(2,0,0,v.Position,Vector(0,0),player):ToTear() q.FallingAcceleration = v:ToProjectile().FallingAccel q.Height = auxi.offset2height(Vector(0,auxi.height2offset(v:ToProjectile().Height,v:ToProjectile().FallingAccel)),q.FallingAcceleration) q.TearFlags = BitSet128(1<<31,0) q:GetSprite().Color = Color(1,1,1,1,0.5,0.5,0) q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE q:Update()
		v:Remove() end end
	if auxi.check_all_exists(d[item.own_key.."effect"].target) ~= true then d[item.own_key.."effect"].target = nil end
	local target = d[item.own_key.."effect"].target 
	if target == nil then 
		target = auxi.get_nearest_(auxi.getothers(9,nil,nil,nil,function(et) if (et.Position - ent.Position):Length() < 200 then return true else return false end end),function(tg) 
			local dis = (tg.Position - ent.Position)
			local angle = auxi.vec2dangle(dis,veldir)
			local dis_dir = dis:Length() * (auxi.check_lerp(angle,item.angle2bonus).val + 1)
			local d = tg:GetData()
			if d[item.own_key.."effect"] then if auxi.check_all_exists(d[item.own_key.."effect"]) then dis_dir = dis_dir * 2 else d[item.own_key.."effect"] = nil end end
			return dis_dir
		end) if target then target = target.tg d[item.own_key.."effect"].target = target target:GetData()[item.own_key.."effect"] = ent end
	end
	if target then
		ent.PositionOffset = ent.PositionOffset * 0.6 + target.PositionOffset * 0.4
	else 
		target = player
		cut_off = 5
		ent.PositionOffset = ent.PositionOffset * 0.7 + item.base_offset * 0.3
		rotate = true
	end
	if target then
		local pos = target.Position --+ target.Velocity
		if rotate then pos = pos + auxi.get_by_rotate(nil,(d[item.own_key.."effect"].counter) * 5,50) end
		local dir = (pos - ent.Position)
		if dir:Length() < math.abs(cut_off) then cut_off = -dir:Length() end
		ent.Velocity = ent.Velocity * 0.6 + dir:Normalized() * math.max(0,math.min(25,(dir:Length() - cut_off))) * 0.4
	end
	
	ent.Velocity = auxi.apply_friction(ent.Velocity,1)
	local vel = ent.Velocity
	s.Rotation = vel:GetAngleDegrees() + 90
end,
})

return item
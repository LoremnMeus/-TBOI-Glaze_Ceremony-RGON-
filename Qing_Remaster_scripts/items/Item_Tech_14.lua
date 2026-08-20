local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Tech_14,
	own_key = "Item_Tech_14_",
	dirs = {
		{dir = Vector(0,40),},
		{dir = Vector(0,-40),},
		{dir = Vector(40,0),},
		{dir = Vector(-40,0),},
	},
	show_radius = 120,
	hide_radius = 160,
	appear_speed = 0.14,
	hide_speed = 0.06,
}

function item.room_enemies()
	local frame = Game():GetFrameCount()
	if item._enemy_frame == frame then return item._enemies end
	item._enemy_frame = frame
	item._enemies = auxi.getenemies()
	return item._enemies
end

function item.enemy_near(pos, radius)
	local enemies = item.room_enemies()
	local r2 = radius * radius
	for i = 1, #enemies do
		local ent = enemies[i]
		if ent and ent:Exists() and not ent:IsDead() then
			local dlt = ent.Position - pos
			if dlt:LengthSquared() <= r2 then return true end
		end
	end
	return false
end

function item.player_near(pos, radius, parent)
	local r2 = radius * radius
	local function near(p)
		return p and p:Exists() and (p.Position - pos):LengthSquared() <= r2
	end
	if near(parent) then return true end
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and auxi.has_have_coll(p, item.entity) and near(p) then return true end
	end
	return false
end

function item.reveal_near(pos, radius, parent)
	return item.enemy_near(pos, radius) or item.player_near(pos, radius, parent)
end

function item.apply_vis(ent, vis)
	local s = ent:GetSprite()
	local col = auxi.copy_color(s.Color)
	col.A = vis
	s.Color = col
	local sc = 0.4 + 0.6 * vis
	s.Scale = Vector(sc, sc)
end

function item.update_vis(ent, want_show)
	local d = ent:GetData()
	local parent = ent.Parent
	local vis = d[item.own_key.."vis"]
	if vis == nil then vis = 1 end
	local shown = d[item.own_key.."shown"]
	if shown == nil then shown = true end
	if want_show then
		shown = true
	elseif shown then
		if not item.reveal_near(ent.Position, item.hide_radius, parent) then
			shown = false
		end
	else
		shown = item.reveal_near(ent.Position, item.show_radius, parent)
	end
	d[item.own_key.."shown"] = shown
	local target = shown and 1 or 0
	local speed = shown and item.appear_speed or item.hide_speed
	if vis < target then vis = math.min(target, vis + speed)
	elseif vis > target then vis = math.max(target, vis - speed) end
	d[item.own_key.."vis"] = vis
	item.apply_vis(ent, vis)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = enums.Entities.Tech_14_pointer,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	s:Play("Idle",true)
	d[item.own_key.."vis"] = 1
	d[item.own_key.."shown"] = true
	item.apply_vis(ent, 1)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Tech_14_pointer,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d[item.own_key.."Pos"] == nil then ent:Remove() return
	else 
		local dir = d[item.own_key.."Pos"] - ent.Position
		local player = ent.Parent or Game():GetPlayer(0)
		ent.Velocity = dir:Normalized() * math.min(20,dir:Length() * 0.4)
		local room = Game():GetRoom()
		local founders = {}
		local d2 = player:GetData()
		d2[item.own_key.."effect"] = d2[item.own_key.."effect"] or {}
		for u,v in pairs(item.dirs) do
			local gidx = room:GetGridIndex(ent.Position + v.dir)
			if auxi.check_all_exists(d2[item.own_key.."effect"][gidx]) then table.insert(founders,#founders + 1,{ent = d2[item.own_key.."effect"][gidx],Angle = v.dir:GetAngleDegrees(),}) end
		end
		if auxi.check_all_exists(d[item.own_key.."Linked"]) ~= true and #founders > 0 then
			local n_entity = Isaac.FindInRadius(ent.Position,20,EntityPartition.ENEMY)
			for u,v in pairs(n_entity) do
				if auxi.isenemies(v) then
					for uu,vv in pairs(founders) do
						if math.abs(auxi.get_correct_angle((v.Position - ent.Position):GetAngleDegrees() - vv.Angle)) < 15 then
							local q = Isaac.Spawn(7,2,4,ent.Position,Vector(0,0),player):ToLaser()
							q.CollisionDamage = 1
							q.Angle = vv.Angle
							q.MaxDistance = 40
							q:SetTimeout(5)
							q.OneHit = true
							d[item.own_key.."Linked"] = q
							d[item.own_key.."vis"] = 1
							d[item.own_key.."shown"] = true
							item.apply_vis(ent, 1)
							s:Play("Disappear",true)
						end
					end
				end
			end
		end
	end
	if s:IsFinished("Disappear") then ent:Remove() return end
	if s:GetAnimation() == "Disappear" then
		d[item.own_key.."vis"] = 1
		d[item.own_key.."shown"] = true
		item.apply_vis(ent, 1)
	else
		item.update_vis(ent, false)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		local room = Game():GetRoom()
		local d = player:GetData()
		local gidx = room:GetGridIndex(player.Position)
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		if auxi.check_all_exists(d[item.own_key.."effect"][gidx]) ~= true then
			local q = Isaac.Spawn(1000,enums.Entities.Tech_14_pointer,0,player.Position,Vector(0,0),player):ToEffect()
			local d2 = q:GetData()
			d[item.own_key.."effect"][gidx] = q
			d2[item.own_key.."Pos"] = room:GetGridPosition(gidx)
			q.Parent = player
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		if ent.State == -1 then
			local room = Game():GetRoom()
			local player = auxi.check_spawner_player(ent)
			local d = player:GetData()
			local gidx = room:GetGridIndex(ent.Position)
			d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
			if auxi.check_all_exists(d[item.own_key.."effect"][gidx]) ~= true then
				local q = Isaac.Spawn(1000,enums.Entities.Tech_14_pointer,0,ent.Position,Vector(0,0),player):ToEffect()
				local d2 = q:GetData()
				d[item.own_key.."effect"][gidx] = q
				d2[item.own_key.."Pos"] = room:GetGridPosition(gidx)
				q.Parent = player
			end
		end
	end
end,
})

return item
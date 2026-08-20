local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	enemy = enums.Enemies.wildwind,
	own_key = "Enemies_Zennith_wind",
	winds = {},
	now_hold = nil,
	wind_cnt = 0,
	power = 0,
	render_mode = 1,
	end_frame = {
		["Idle1"] = 30,
		["Idle2"] = 16,
		["Idle3"] = 8,
		["Idle4"] = 30,
		["Idle5"] = 16,
	},
}

function item.start_(pos)
	if auxi.check_exists(item.now_hold) ~= true then 
		local q = Isaac.Spawn(1000,item.enemy,0,Vector(0,-100),Vector(0,0),nil):ToEffect()
		local d = q:GetData() d[item.own_key.."effect"] = {pos = pos,}
		item.now_hold = q
	end
	return item.now_hold
end

function item.clear_wind()
	item.now_hold:Remove()
	item.now_hold = nil
end

function item.change_control(mode,params)
	local q = item.start_() local d = q:GetData()
	mode = mode or 1 params = params or {}
	if mode == 1 then				--单向风
		d[item.own_key.."effect"].pos = nil
		params.ang = params.ang or ((params.dir or 1) * 90 - 90)
		d[item.own_key.."effect"].ang = params.ang or 0
		d[item.own_key.."effect"].delta_rotation = 0
		d[item.own_key.."effect"].follower = nil
	elseif mode == 2 then			--环绕式风向
		d[item.own_key.."effect"].pos = params.pos
		d[item.own_key.."effect"].delta_rotation = params.delta_rotation
		d[item.own_key.."effect"].ang = 0
		d[item.own_key.."effect"].follower = nil
	elseif mode == 3 then			--跟随的环绕式风向
		d[item.own_key.."effect"].pos = params.pos
		d[item.own_key.."effect"].delta_rotation = params.delta_rotation
		d[item.own_key.."effect"].ang = 0
		d[item.own_key.."effect"].follower = params.ent
	end
	item.render_mode = mode
	--if params.delta_rotation and (params.delta_rotation == 0 or params.delta_rotation == 180) then item.render_mode = 1 end
	d[item.own_key.."effect"].power = params.power or d[item.own_key.."effect"].power		--风力就是熏距离此房间的距离。0是最大值，26是最小值
	d[item.own_key.."effect"].delta_pos = d[item.own_key.."effect"].delta_pos or params.delta_pos
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = item.enemy,	--初始化
Function = function(_,ent)
	local s = ent:GetSprite() local d = ent:GetData()
	d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
end,
})

function item.draw_wind_desc(d)
	local p = d[item.own_key.."effect"].power or 0
	local ang = d[item.own_key.."effect"].ang or 0
	local tab = {frame = 0,}
	tab.Scale = Vector(auxi.random_1() * 0.5 + 0.5,auxi.random_1() * 0.1 + 0.95)
	tab.Rotation = ang
	tab.pos = Game():GetRoom():GetRandomPosition(10) + auxi.random_v2() * 30
	if d[item.own_key.."effect"].pos then
		tab.Rotation = (d[item.own_key.."effect"].pos - tab.pos):GetAngleDegrees() + 90 + (d[item.own_key.."effect"].delta_rotation or 0)
	end
	local rnd = auxi.random_1() * 0.5 + 0.1 + p / 30 * 0.4
	tab.Color = Color(auxi.random_1() * 0.1 + 0.95,auxi.random_1() * 0.1 + 0.95,auxi.random_1() * 0.1 + 0.95,rnd)
	tab.sgid = Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex
	tab.mode = item.render_mode
	return tab
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.enemy,
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite() local d = ent:GetData()
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		local p = d[item.own_key.."effect"].power or 0
		local ang = d[item.own_key.."effect"].ang or 0
		if auxi.check_all_exists(d[item.own_key.."effect"].follower) then
			d[item.own_key.."effect"].pos = d[item.own_key.."effect"].follower.Position + d[item.own_key.."effect"].follower.Velocity * 0.5 + (d[item.own_key.."effect"].delta_pos or Vector(0,0))
		else --??
		end
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		
		local mx_p_rate = math.ceil((26 - p)/4) + math.max(0,math.ceil((6 - p) * 0.8)) + math.max(0,(3 - p) * 5)
		for i = 1,mx_p_rate do
			if item.render_mode == 1 then
				if math.random(1000) > 500 + p * 20 then 
					local anim = "Idle1"
					if math.random(1000) > p * 35 or p < 3 then anim = "Idle2"
						if math.random(1000) > 600 + p * 50 or p == 1 then anim = "Idle3" end
					end
					local tab = item.draw_wind_desc(d)
					tab.anim = anim 
					table.insert(item.winds,#item.winds + 1,tab)
				end
			end
			for i = 1,3 + math.max(0,math.ceil((10 - p)/5)) do
				if math.random(1000) > 300 + p * 15 then
					local anim = "Idle4"
					if math.random(1000) > 300 + p * 30 or p < 5 then anim = "Idle5" end
					local tab = item.draw_wind_desc(d)
					tab.anim = anim tab.delta_rotation = d[item.own_key.."effect"].delta_rotation
					if auxi.check_all_exists(d[item.own_key.."effect"].follower) then
						tab.follower = d[item.own_key.."effect"].follower
						tab.Special = function(tb)
							if auxi.check_all_exists(tb.follower) then tb.Rotation = (tb.follower.Position + tb.follower.Velocity * 0.5 - tb.pos):GetAngleDegrees() + 90 + (tb.delta_rotation or 0)	end
						end
					end
					table.insert(item.winds,#item.winds + 1,tab)
				end
			end
			
			if d[item.own_key.."effect"].counter % 3 == 1 then
				local n_entity = Isaac.GetRoomEntities()
				for i = 1, #n_entity do
					local tent = n_entity[i]
					if tent.Type == 1000 then
					elseif (tent.Type == 996 and tent.Variant == enums.Enemies.Zennith) then
					elseif (tent.Type == 33) or (tent.Type == 17) or (tent.Type == 86) or (tent.Type == 5 and tent:ToPickup():IsShopItem() == true) or (tent.Type == 6) or (tent.Type == 7) or (tent.Type == 8) then
					elseif (tent.SpawnerEntity and tent.SpawnerEntity.Type == 996 and tent.SpawnerEntity.Variant == enums.Enemies.Zennith) then
						if tent:GetData()[item.own_key.."rate"] then 
							local dang = ang
							if d[item.own_key.."effect"].pos then 
								dang = (d[item.own_key.."effect"].pos - tent.Position):GetAngleDegrees() + 90 + (d[item.own_key.."effect"].delta_rotation or 0) 
								if tent:GetData()[item.own_key.."test_remove"] and (d[item.own_key.."effect"].pos - tent.Position):Length() < 80 then tent:GetData()[item.own_key.."try_remove"] = true end
							end
							tent.Velocity = tent.Velocity + auxi.MakeVector(dang + 90) * (30 - p)/150 * 0.5 * tent:GetData()[item.own_key.."rate"]
						end
					elseif (tent:GetData().dont_over_write_velocity) then
					else
						local dang = ang
						if d[item.own_key.."effect"].pos then dang = (d[item.own_key.."effect"].pos - tent.Position):GetAngleDegrees() + 90 + (d[item.own_key.."effect"].delta_rotation or 0) end
						
						tent.Velocity = tent.Velocity + auxi.MakeVector(dang + 90) * (30 - p)/150 * 0.5 
					end
				end
			end
		end
	end
end,
})

function item.copy_wind_sprite(s,info)
	s.Rotation = info.Rotation
	s.Scale = info.Scale
	s.Color = info.Color
	return s
end

local render_sprite = Sprite()
render_sprite:Load("gfx/boss/Zennith/wildwind.anm2",true)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = item.enemy,
Function = function(_,ent)
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	for i = #(item.winds),1,-1 do
		local v = item.winds[i]
		render_sprite:SetFrame(v.anim,v.counter or 0)
		if (v.counter or 0) > (item.end_frame[v.anim] or 16) or desc.SafeGridIndex ~= v.sgid then table.remove(item.winds,i) 
		else
			local s = item.copy_wind_sprite(render_sprite,v)
			s:Render(Isaac.WorldToScreen(v.pos),Vector(0,0),Vector(0,0))
			if v.Special then v.Special(v) end
			v.counter = (v.counter or 0) + 1
		end
	end
end,
})

function item.grow_slow()
	item.slow_down = true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_,ent)
	if item.slow_down and Game():GetFrameCount() % 15 == 1 then 
		if auxi.check_all_exists(item.now_hold) then 
			local d = item.now_hold:GetData() d[item.own_key.."effect"].power = (d[item.own_key.."effect"].power or 0) + 1
			if d[item.own_key.."effect"].power > 26 then item.slow_down = nil item.clear_wind() end
		end
	end
end,
})

return item
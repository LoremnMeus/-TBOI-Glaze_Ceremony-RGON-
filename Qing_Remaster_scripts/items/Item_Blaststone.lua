local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Blaststone,
	own_key = "Item_Blaststone_",
	vel_adder = {
		[4] = Vector(-4,0),
		[5] = Vector(4,0),
		[6] = Vector(0,-4),
		[7] = Vector(0,4),
	},
	ATTRACT_FULL = 100,
	ATTRACT_MAX = 300,
	STOP_DIST_SQ = 30 * 30,
}

-- 在 n 束均分射线中选出约 4 个中心均分的玩家发射下标（优先 4，否则 3/5）
local function player_fire_marks(n)
	local marks = {}
	if n <= 0 then return marks end
	local k = nil
	local best = nil
	for _,cand in ipairs({4,3,5}) do
		if cand <= n and n % cand == 0 then
			local score = math.abs(cand - 4)
			if not best or score < best then
				best = score
				k = cand
			end
		end
	end
	if not k then k = math.min(4,n) end
	for j = 0,k - 1 do
		marks[1 + math.floor(j * n / k)] = true
	end
	return marks
end

-- 射速对蓄力取根号软化：默认泪弹延迟附近与线性接近，两端不至于过快/过慢
local function charge_delay_frames(player)
	local ref = 10
	local tear = math.max(player.MaxFireDelay,0.01)
	local tear_scaled = math.sqrt(tear * ref)
	return math.ceil((tear_scaled * 35 + 3) * 1.5)
end

local STRIP_FLAGS = BitSet128(1 << 17,0) | BitSet128(1 << 6,0)

-- 仅颜色（含 Colorize / 图层色），可每帧调用
local function sync_color_from(dst, src)
	if not auxi.check_all_exists(dst) or not auxi.check_all_exists(src) then return end
	local c = auxi.copy_color(src:GetColor())
	dst:SetColor(c,-1,99,false,false)
	dst.Color = c
	local rs = src:GetSprite()
	local ss = dst:GetSprite()
	ss.Color = auxi.copy_color(rs.Color)
	pcall(function()
		local n = rs:GetLayerCount()
		for i = 0,(n or 1) - 1 do
			local rl = rs:GetLayer(i)
			local sl = ss:GetLayer(i)
			if rl and sl and sl.SetColor then
				sl:SetColor(auxi.copy_color(rl:GetColor()))
			end
		end
	end)
end

-- anm2 / spritesheet 只在需要时拷一次
local function sync_sprite_assets_from(dst, src)
	if not auxi.check_all_exists(dst) or not auxi.check_all_exists(src) then return end
	local rs = src:GetSprite()
	local ss = dst:GetSprite()
	local anm2 = rs:GetFilename()
	local need_reload = anm2 and anm2 ~= "" and anm2 ~= ss:GetFilename()
	if need_reload then
		ss:Load(anm2,false)
	end
	local replaced = false
	pcall(function()
		local n = rs:GetLayerCount()
		for i = 0,(n or 1) - 1 do
			local rl = rs:GetLayer(i)
			if rl then
				local path = rl:GetSpritesheetPath()
				if path and path ~= "" then
					pcall(function() ss:ReplaceSpritesheet(i,path) end)
					replaced = true
				end
			end
		end
	end)
	if need_reload or replaced then
		ss:LoadGraphics()
	end
	if need_reload then
		local anim = rs:GetAnimation()
		if anim and anim ~= "" then
			ss:Play(anim,true)
			pcall(function() ss:SetFrame(rs:GetFrame()) end)
		end
	end
end

-- 豆浆等：光束 + 末端冲击（Child / LASER_IMPACT）一并同步
local function sync_spawn_color_from_ref(spawn, ref)
	if not auxi.check_all_exists(spawn) or not auxi.check_all_exists(ref) then return end
	sync_color_from(spawn,ref)
	local ref_end = ref.Child
	local spawn_end = spawn.Child
	if auxi.check_all_exists(ref_end) and auxi.check_all_exists(spawn_end) then
		local d2 = spawn:GetData()
		if not d2[item.own_key.."end_sheet"] then
			sync_sprite_assets_from(spawn_end,ref_end)
			d2[item.own_key.."end_sheet"] = true
		end
		sync_color_from(spawn_end,ref_end)
	elseif auxi.check_all_exists(spawn_end) then
		local c = auxi.copy_color(spawn:GetColor())
		spawn_end:SetColor(c,-1,99,false,false)
		spawn_end.Color = c
		spawn_end:GetSprite().Color = auxi.copy_color(spawn:GetSprite().Color)
	end
end

-- FireBrimstone 的染色常在 Colorize / Layer，不只是 Tint
local function capture_brim_template(laser)
	if not laser then return nil end
	local s = laser:GetSprite()
	local sheets = {}
	local layer_colors = {}
	local sheet_count = 0
	local n = 0
	pcall(function() n = s:GetLayerCount() end)
	for i = 0,math.max((n or 1) - 1,3) do
		pcall(function()
			local layer = s:GetLayer(i)
			if not layer then return end
			local path = layer:GetSpritesheetPath()
			if path and path ~= "" then
				sheets[i] = path
				sheet_count = sheet_count + 1
			end
			local lc = layer:GetColor()
			if lc then layer_colors[i] = auxi.color2table(lc) end
		end)
	end
	return {
		variant = laser.Variant,
		subtype = laser.SubType,
		size = laser.Size,
		sx = laser.SpriteScale.X,
		sy = laser.SpriteScale.Y,
		ox = laser.PositionOffset.X,
		oy = laser.PositionOffset.Y,
		get_color = auxi.color2table(laser:GetColor()),
		color = auxi.color2table(laser.Color),
		sprite_color = auxi.color2table(s.Color),
		shrink = laser.Shrink,
		tear_flags = laser.TearFlags,
		anm2 = s:GetFilename(),
		anim = s:GetAnimation(),
		frame = s:GetFrame(),
		sheets = sheets,
		sheet_count = sheet_count,
		layer_colors = layer_colors,
	}
end

local function apply_spawn_brim_visual(laser, tmpl)
	if not tmpl then return false end
	laser.PositionOffset = Vector(tmpl.ox,tmpl.oy)
	laser.Size = tmpl.size
	laser.SpriteScale = Vector(tmpl.sx,tmpl.sy)
	if tmpl.shrink ~= nil then laser.Shrink = tmpl.shrink end
	if tmpl.tear_flags then laser.TearFlags = tmpl.tear_flags end

	local s = laser:GetSprite()
	if tmpl.anm2 and tmpl.anm2 ~= "" then
		s:Load(tmpl.anm2,false)
		if tmpl.sheets then
			for i,path in pairs(tmpl.sheets) do
				if path and path ~= "" then
					pcall(function() s:ReplaceSpritesheet(i,path) end)
				end
			end
		end
		s:LoadGraphics()
		if tmpl.anim and tmpl.anim ~= "" then
			s:Play(tmpl.anim,true)
			if tmpl.frame then pcall(function() s:SetFrame(tmpl.frame) end) end
		end
	end
	if tmpl.layer_colors then
		for i,lc in pairs(tmpl.layer_colors) do
			pcall(function()
				local layer = s:GetLayer(i)
				if layer and layer.SetColor then layer:SetColor(auxi.table2color(lc)) end
			end)
		end
	end

	local col = auxi.table2color(tmpl.get_color or tmpl.color)
	local scol = auxi.table2color(tmpl.sprite_color or tmpl.get_color or tmpl.color)
	laser:SetColor(col,-1,99,false,false)
	laser.Color = col
	s.Color = scol
	return true
end

local function setup_fire_brim(player,ent,start_angle,timeout,dmg)
	local q = player:FireBrimstone(auxi.MakeVector(start_angle),player,1):ToLaser()
	q.Parent = ent
	q.ParentOffset = Vector.Zero
	q.Position = ent.Position
	q:SetTimeout(timeout)
	q.CollisionDamage = dmg
	q.MaxDistance = 0
	q.TearFlags = q.TearFlags & (~STRIP_FLAGS)
	q.Angle = start_angle
	return q
end

-- Spawner 必须是爆破石特效本身，不能是 player；否则 FF Emoji Glasses 等会在
-- MC_POST_LASER_INIT 里把 SpawnerEntity:ToPlayer() 当成角色发射激光
local function setup_spawn_brim(player,ent,start_angle,timeout,dmg,tmpl,info)
	local variant = (tmpl and tmpl.variant) or info.tp
	local subtype = (tmpl and tmpl.subtype) or 0
	local q = Isaac.Spawn(7,variant,subtype,ent.Position,Vector.Zero,ent):ToLaser()
	q.Angle = start_angle
	q.AngleDegrees = start_angle
	q.Parent = ent
	q.ParentOffset = Vector.Zero
	q.Position = ent.Position
	q:SetTimeout(timeout)
	q.CollisionDamage = dmg
	q.MaxDistance = 0
	apply_spawn_brim_visual(q,tmpl)
	return q
end

-- dist>ATTRACT_FULL 后平滑衰减，超过 ATTRACT_MAX 为 0
local function attract_pull(dist, mass)
	if mass <= 0 then mass = 1 end
	if dist < 1 then dist = 1 end
	local full = item.ATTRACT_FULL
	local maxd = item.ATTRACT_MAX
	if dist >= maxd then return 0 end
	local base = math.min(2000 / dist / mass, 5)
	if dist <= full then return base end
	local t = (dist - full) / (maxd - full)
	local fade = (1 - t)
	fade = fade * fade
	return base * fade
end

function item.fire_blast_stone(player,dir)
	player = player or Game():GetPlayer(0)
	local d = player:GetData()
	d[item.own_key.."delay"] = d[item.own_key.."delay"] or 0
	if d[item.own_key.."delay"] > 0 then return end
	local mxn = charge_delay_frames(player)
	local vel = player.Velocity/3
	local room = Game():GetRoom()
	if room:IsMirrorWorld() and (dir == 4 or dir == 5) then dir = 9 - dir end
	vel = vel + (item.vel_adder[dir] or Vector(0,0))
	local q = Isaac.Spawn(1000,enums.Entities.Blaststone,0,player.Position+Vector(0,-10),vel,player)
	q:SetColor(player.LaserColor,60,99,true,false)
	sound_tracker.PlayStackedSound(278,1,1,false,0,2)
	player:AddVelocity(-vel:Normalized() * 5)

	d[item.own_key.."delay"] = mxn
	d[item.own_key.."maxdelay"] = mxn
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Blaststone,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	if s:IsEventTriggered("Shoot") then
		local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
		local rnd = ({6,8,8,8,10})[math.random(5)]
		local stag1 = math.random(360)
		local stag2 = 100
		local timeout = math.ceil(math.random(1000)/1000 * 10 + 25)
		local bonu1 = (math.random(2)*2-3) * (3 + math.random(1000)/1000 * 1.5)
		local bonu4 = 0.5 + math.random(1000)/1000/4
		local bonu5 = rnd + 5 + math.random(4)
		local dmg = (player.Damage/6) or 2
		local fire_marks = player_fire_marks(rnd)
		local info = auxi.judge_by_brimstone(player)
		d[item.own_key.."brimstone"] = d[item.own_key.."brimstone"] or {}
		d[item.own_key.."pending_waves"] = 3
		for i = 1,3 do
			local allow_player_fire = (i == 1)
			delay_buffer.addeffe(function(params)
				if not auxi.check_all_exists(params.ent) then return end
				local ent = params.ent
				local d = ent:GetData()
				local list = d[item.own_key.."brimstone"]
				if not list then
					list = {}
					d[item.own_key.."brimstone"] = list
				end
				local tmpl = d[item.own_key.."brim_tmpl"]
				local silenced = false
				for id = 1,rnd do
					local start_angle = stag1 + (id-1) * 360/rnd
					local q
					local is_spawn = false
					if allow_player_fire and fire_marks[id] then
						q = setup_fire_brim(player,ent,start_angle,timeout,dmg)
						if not silenced then
							silenced = true
							delay_buffer.addeffe(function() SFXManager():Stop(7) end,{},1)
						end
						d[item.own_key.."brim_ref"] = q
						-- 豆浆等 Colorize 常在下一帧才写上；延迟抓模板
						delay_buffer.addeffe(function(p)
							if not auxi.check_all_exists(p.laser) or not auxi.check_all_exists(p.ent) then return end
							p.ent:GetData()[item.own_key.."brim_tmpl"] = capture_brim_template(p.laser)
						end,{laser = q,ent = ent,},1)
					else
						is_spawn = true
						q = setup_spawn_brim(player,ent,start_angle,timeout,dmg,tmpl,info)
					end
					local d2 = q:GetData()
					d2.bonus_angle = bonu1
					d2.start_angle = start_angle
					d2.start_leng = stag2
					d2.bonus_leng = stag2 * bonu4
					d2.bonus_leng2 = bonu5
					d2[item.own_key.."time"] = 0
					d2[item.own_key.."spawn_copy"] = is_spawn
					q.Angle = start_angle
					list[#list + 1] = q
				end
				d[item.own_key.."pending_waves"] = math.max(0,(d[item.own_key.."pending_waves"] or 1) - 1)
			end,{ent = ent,},(i-1) * 7)
		end
	end

	if s:WasEventTriggered("Shoot") then
		local speed = ent.Velocity:LengthSquared()
		if speed > 0.000025 then ent.Velocity = ent.Velocity * 0.9 end
		local list = d[item.own_key.."brimstone"]
		if not list then return end
		local ref = d[item.own_key.."brim_ref"]
		local alive = 0
		for i = #list,1,-1 do
			local v = list[i]
			if auxi.check_all_exists(v) then
				alive = alive + 1
				local d2 = v:GetData()
				-- 豆浆等：跟参考 Fire 激光每帧同步颜色
				if d2[item.own_key.."spawn_copy"] then
					sync_spawn_color_from_ref(v,ref)
				end
				local t = (d2[item.own_key.."time"] or 0) + 1
				d2[item.own_key.."time"] = t
				v.Angle = (d2.start_angle or 0) + (d2.bonus_angle or 0) * t
				v.MaxDistance = (d2.start_leng or 0) * math.min((t - 1)/5,1)
					+ (d2.bonus_leng or 0) * math.sin(math.rad(t * (d2.bonus_leng2 or 0)))
			else
				table.remove(list,i)
			end
		end
		if alive == 0 and (d[item.own_key.."pending_waves"] or 0) <= 0 then
			ent:Remove()
		end
	else
		local pos = ent.Position
		local enemies = Isaac.FindInRadius(pos,item.ATTRACT_MAX,EntityPartition.ENEMY)
		local frame = s:GetFrame()
		local check_stop = frame < 37 and not d[item.own_key.."stop"]
		for i = 1,#enemies do
			local v = enemies[i]
			if auxi.isenemies(v) then
				local offset = pos - v.Position
				local dist_sq = offset:LengthSquared()
				if check_stop and dist_sq < item.STOP_DIST_SQ then
					d[item.own_key.."stop"] = true
					check_stop = false
				end
				local dist = math.sqrt(dist_sq)
				local pull = attract_pull(dist,v.Mass)
				if pull > 0 then
					local dir = offset / dist
					local spd_sq = v.Velocity:LengthSquared()
					if spd_sq > 25 then
						local spd = math.sqrt(spd_sq)
						v.Velocity = (v.Velocity + dir * pull):Normalized() * spd
					else
						v:AddVelocity(dir * pull)
					end
				end
			end
		end
		local ent_spd = ent.Velocity:LengthSquared()
		if ent_spd > 0 then
			if not d[item.own_key.."stop"] then
				local spd = math.sqrt(ent_spd)
				ent.Velocity = ent.Velocity:Normalized() * math.min(10,spd * 1.03)
			elseif ent_spd > 0.0025 then
				ent.Velocity = ent.Velocity * 0.98
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local d = player:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		if auxi.has_have_coll(player,item.entity) then
			d[item.own_key.."maxdelay"] = d[item.own_key.."maxdelay"] or charge_delay_frames(player)
			d[item.own_key.."delay"] = d[item.own_key.."delay"] or 0
			local mx_cnt = d[item.own_key.."maxdelay"]
			local cnt = mx_cnt + 5 - d[item.own_key.."delay"]
			Charging_Bar_holder.render_me(player,{name1 = "Blaststone_Charge",name2 = "Blaststone_Charge_Sprite",name3 = "Blaststone",loadname = "gfx/effects/chargebar/chargebar_Blaststone.anm2",
				check1 = function(val,ent)
					return cnt > 5
				end,
				check2 = function(val,ent)
					return cnt > mx_cnt
				end,
				check3 = function(val,ent)
					return math.ceil(cnt/math.max(mx_cnt/100,0.001))
				end,
				signal1 = function(ent)
				end,
			})
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	if collid == item.entity and count < 0 then
		Charging_Bar_holder.remove_charge_bar(player,"Blaststone")
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	if auxi.g_dir_can_work(player) and auxi.has_have_coll(player,item.entity) then
		local ctrlid = player.ControllerIndex
		local dir = nil
		for i = 4,7 do
			if (Input.IsActionTriggered(i,ctrlid) or Input.IsActionPressed(i,ctrlid)) then
				dir = i
			end
		end
		d[item.own_key.."delay"] = (d[item.own_key.."delay"] or 0)
		d[item.own_key.."delay2"] = (d[item.own_key.."delay2"] or 0)
		if dir then
			if (dir == (d[item.own_key.."record"] or 0)) and (d[item.own_key.."delay2"] > 0) and (d[item.own_key.."delay2"] < 19) then
				item.fire_blast_stone(player,dir)
				d[item.own_key.."record"] = nil
				d[item.own_key.."delay2"] = 0
			else
				d[item.own_key.."record"] = dir
				d[item.own_key.."delay2"] = 20
			end
		end
		if d[item.own_key.."delay"] == 3 then
			player:SetColor(Color(1.0,1.0,1.0,1.0,1,0.0,0.0),5,-1,true,false)
			sound_tracker.PlayStackedSound(171,1,0.8,false,0,2)
		end
		if d[item.own_key.."delay"] > 0 then d[item.own_key.."delay"] = d[item.own_key.."delay"] - 1 end
		if d[item.own_key.."delay2"] > 0 then d[item.own_key.."delay2"] = d[item.own_key.."delay2"] - 1 end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local d = ent:GetData()
		if (d[item.own_key.."counter"] or 0) > 0 then d[item.own_key.."counter"] = d[item.own_key.."counter"] - 1 end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent,col,low)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local player = auxi.check_spawner_player(ent)
		local d = ent:GetData()
		if (d[item.own_key.."counter"] or 0) <= 0 and auxi.isenemies(col) and ent.State == -1 then
			d[item.own_key.."counter"] = 10 * 30
			local rd = auxi.random_0()
			for i = 1,4 do
				local q = player:FireBrimstone(auxi.get_by_rotate(ent.Velocity,i * 90),nil,0.5)
				q.MaxDistance = 50
				q.Parent = ent
				q:SetActiveRotation(0,180 * rd,10 * rd,false)
				q:SetTimeout(8)
			end
		end
	end
end,
})

return item

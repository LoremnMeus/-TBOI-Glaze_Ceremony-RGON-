local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")

local item = {
	ToCall = {},
	own_key = "Nil_holder",
	handlers = {},
	grid_grounder = {
		[EntityGridCollisionClass.GRIDCOLL_GROUND] = true,
		[EntityGridCollisionClass.GRIDCOLL_BULLET] = true,
	},
	qing_fetus_map = {
		[0] = "IdleX1",
		[1] = "IdleY1",
		[2] = "IdleX2",
		[3] = "IdleY2",
	},
	revealer_info = {
		["Appear"] = {
			check = function(frame,info)
				local st = #info
				local ed = #info
				for i = 1,#info do
					local v = info[i]
					if frame <= v.frame then
						st = math.max(1,i - 1)
						ed = i
						break
					end
				end
				local lerper = (frame - info[st].frame)/math.max(1,(info[ed].frame - info[st].frame))
				local ret = {}
				for u,v in pairs(info[st]) do
					ret[u] = auxi.Lerp(info[st][u],info[ed][u],lerper)
				end
				return ret
			end,
			[1] = {frame = 0,scale = Vector(0,0),alpha = 0,rotation = -360,},
			[2] = {frame = 8,scale = Vector(0.6,0.6),alpha = 100/255,rotation = -210,},
			[3] = {frame = 16,scale = Vector(1.2,1.2),alpha = 200/255,rotation = -60,},
			[4] = {frame = 19,scale = Vector(1.1,1.1),alpha = 200/255,rotation = 30,},
			[5] = {frame = 21,scale = Vector(1,1),alpha = 1,rotation = 0,},
		},
		["Idle"] = {
			check = function(frame,info)
				local ret = {scale = Vector(1,1),alpha = 1,rotation = 0,}
				return ret
			end,
		},
		["Disappear"] = {
			check = function(frame,info)
				local st = #info
				local ed = #info
				for i = 1,#info do
					local v = info[i]
					if frame <= v.frame then
						st = math.max(1,i - 1)
						ed = i
						break
					end
				end
				local lerper = (frame - info[st].frame)/math.max(1,(info[ed].frame - info[st].frame))
				local ret = {}
				for u,v in pairs(info[st]) do
					ret[u] = auxi.Lerp(info[st][u],info[ed][u],lerper)
				end
				return ret
			end,
			[1] = {frame = 0,scale = Vector(1,1),alpha = 1,rotation = 0,},
			[2] = {frame = 5,scale = Vector(1.2,1.2),alpha = 200/255,rotation = 60,},
			[3] = {frame = 13,scale = Vector(0.6,0.6),alpha = 100/255,rotation = 210,},
			[4] = {frame = 21,scale = Vector(0,0),alpha = 0,rotation = 360,},
		},
	},
	revealee_info = {
		["Appear"] = {
			check = function(frame,info)
				local st = #info
				local ed = #info
				for i = 1,#info do
					local v = info[i]
					if frame <= v.frame then
						st = math.max(1,i - 1)
						ed = i
						break
					end
				end
				local lerper = (frame - info[st].frame)/math.max(1,(info[ed].frame - info[st].frame))
				local ret = {}
				for u,v in pairs(info[st]) do
					ret[u] = auxi.Lerp(info[st][u],info[ed][u],lerper)
				end
				return ret
			end,
			[1] = {frame = 0,scale = Vector(0,0),alpha = 0,rotation = 0,},
			[2] = {frame = 8,scale = Vector(0.6,0.6),alpha = 100/255,rotation = 0,},
			[3] = {frame = 12,scale = Vector(1.2,1.2),alpha = 1,rotation = 0,},
			[4] = {frame = 17,scale = Vector(1.5,1.5),alpha = 100/255,rotation = 0,},
			[5] = {frame = 21,scale = Vector(2,2),alpha = 0,rotation = 0,},
		},
	},
	-- 供 Color / Boss_Sprite 等描边渲染共用
	Color_remove_overlay = {
		[835] = true,
		[886] = true,
		[950] = true,
	},
	Color_rendertype = {
		[807] = true,
		[810] = true,
		[950] = function(ent)
			if ent.Variant == 1 then return true end
		end,
		[951] = true,
	},
}

--- 注册 MeusNIL 模式。spec = { detect?, update?, render?, remove? }
--- detect(d) 用于未写 nil_mode 时的兼容推断；update/render 签名 (ent, d, s, player[, offset])
function item.register(mode, spec)
	if type(mode) ~= "string" or type(spec) ~= "table" then return end
	item.handlers[mode] = spec
end

function item.resolve_mode(d)
	if d.nil_mode then return d.nil_mode end
	for mode, h in pairs(item.handlers) do
		if h.detect and h.detect(d) then
			d.nil_mode = mode
			return mode
		end
	end
	return nil
end

function item.run_lifetime(ent, d, player)
	d.Params = d.Params or {}
	d.removecd = d.removecd or 60
	if d.removecd > 0 then d.removecd = d.removecd - 1 end
	-- 长驻视觉体（如 DVF 箔片）可跳过；大房间里 >1000 会误杀
	if not d.skip_nil_distance_cull and (player.Position - ent.Position):Length() > 1000 then d.removecd = 0 end
	if d.removecd <= 0 then
		if d.Params.removeanimate then
			if ent.Child then
				local q1 = Isaac.Spawn(1000,15,0,ent.Child.Position,Vector(0,0),nil):ToEffect()
				q1:GetSprite().Scale = ent.Child:GetSprite().Scale:Length() * Vector(1,1)
			end
		end
		ent:Remove()
		return true
	end
	if d.Params.remove_with_ent and auxi.check_all_exists(d.Params.remove_with_ent) ~= true then
		ent:Remove()
		return true
	end
	return false
end

function item.run_motion(ent, d, player)
	if d.next_pos then ent.Position = d.next_pos d.next_pos = nil end
	if d.follower then
		if d.follower:Exists() then
			d.nw_follow_pos = d.nw_follow_pos or ent.Position - d.follower.Position
			if d.ignore_follower_distance then d.nw_follow_pos = Vector(0,0) end
			ent.Position = d.follower.Position + d.nw_follow_pos
			if d.ignore_follower_velocity then
			else ent.Velocity = d.follower.Velocity end
		else
			if ent.Velocity:Length() > 0.05 then
				if (d.continue_after_follower and d.continue_after_follower == true) then
					if d.continue_and_resetvel ~= nil then
						ent.Velocity = d.continue_and_resetvel
					end
					d.follower = nil
				else
					d.Params.Accerate = -1
					if d.Accerate_flag == nil or d.Accerate_flag == false then
						d.Accerate_flag = true
					end
					d.follower = nil
				end
			end
		end
		return
	end

	local nowpos = ent.Position
	if ent.Child then nowpos = ent.Child.Position end
	if d.Params.FollowInput and d.Params.FollowInput == true then
		local gdir = auxi.ggdir(player,true,ModConfig.ModConfigSettings.allow_mouse_control)
		if gdir:Length() < 0.05 and ent.Velocity:Length() > 0.0005 then
			ent.Velocity = ent.Velocity * 0.85
		else
			ent.Velocity = (gdir + ent.Velocity:Normalized()):Normalized() * math.min(20,(ent.Velocity:Length() * 1.5))
		end
	elseif d.Params.Accerate then
		if d.Params.Way_Accerate then
			ent.Velocity = ent.Velocity * (d.Params.Way_Accerate_mul or 1) + d.Params.Way_Accerate:Normalized() * d.Params.Accerate
		else
			if d.Accerate_flag == nil then
				d.Accerate_flag = true
			end
			if d.Accerate_avoid_lock == nil then
				d.Accerate_avoid_lock = false
			end
			if d.Accerate_flag == true or d.Accerate_avoid_lock == true then
				local leg_vel = ent.Velocity:Length() + d.Params.Accerate
				if leg_vel < 0.001 and d.Accerate_avoid_lock ~= true then
					ent.Velocity = ent.Velocity / 100000
					d.Accerate_flag = false
				else
					ent:AddVelocity(ent.Velocity:Normalized() * d.Params.Accerate)
				end
			end
		end
	end
	if d.Params.target_pos then
		local dir = (d.Params.target_pos - nowpos)
		ent.Velocity = dir:Normalized() * math.min(20,dir:Length() * 0.4)
	end
	if d.Params.Homing then
		local shouldHome = false

		if auxi.check_all_exists(d.Params.Homing_target) ~= true then
			d.Params.Homing_target = nil
			local tg = auxi.get_by_nearest_enemy(nowpos,d.Params.checkhoming)
			if tg and (tg.Position - nowpos):Length() < (d.Params.HomingDistance or 99999) then d.Params.Homing_target = tg end
		end
		if auxi.check_all_exists(d.Params.Homing_target) then shouldHome = true end

		if shouldHome then
			local dir = (d.Params.Homing_target.Position - nowpos)
			if d.Params.Homing2 then
				ent.Velocity = dir:Normalized() * math.min(20,dir:Length() * 0.4)
			else
				if d.Params.HomingAcce == nil then
					d.Params.HomingAcce = d.Params.Accerate or 0
					d.Params.Accerate = 0
				end
				d.Params.HomingSpeed = (d.Params.HomingSpeed or 15) + d.Params.HomingAcce * 0.4
				if dir:Length() < 70 then
					if dir:Length() < 30 then
						ent.Velocity = ent.Velocity * 1.1 + d.Params.Homing_target.Velocity * 0.2
						d.nill_homing_dont_repeat = math.max(16,(d.nill_homing_dont_repeat or -1) - 1)
					else
						d.nill_homing_dont_repeat = math.min(16,(d.nill_homing_dont_repeat or -1) + 1)
						ent.Velocity = ent.Velocity * (3 + d.nill_homing_dont_repeat) / 20 + (dir:Normalized() * math.max(ent.Velocity:Length()* 1.05,d.Params.HomingSpeed * 1.3)) * (17 - d.nill_homing_dont_repeat) / 20
					end
				else
					d.nill_homing_dont_repeat = -1
					if ent.Velocity:Length() > d.Params.HomingSpeed * 0.6 then
						ent.Velocity = ent.Velocity * 0.9 + (dir:Normalized() * math.max(ent.Velocity:Length() * 1.05,d.Params.HomingSpeed)) * 0.1
					else
						ent.Velocity = ent.Velocity * 0.75 + (dir:Normalized() * math.max(ent.Velocity:Length() * 1.2,d.Params.HomingSpeed)) * 0.25
					end
				end
			end
		end
	end
end

-- 内置：仅运动/寿命，无特性逻辑（DVF 箔片等可用 work 或此 mode）
item.register("visual_only", {
	update = function() end,
})

item.register("qing_fetus", {
	detect = function(d) return d.Is_Qing_Fetus end,
	update = function(ent, d, s)
		if d[item.own_key.."Fetus_loaded"] ~= true then
			d[item.own_key.."Fetus_loaded"] = true
			s:Load("gfx/player/qing/qing_fetus.anm2")
			s:Play("IdleX1",true)
			s.Scale = d.fetus_scale or Vector(0.75,0.75)
		end
		local ang = ent.Velocity:GetAngleDegrees()
		if (ent.Velocity:Length() < 0.05 or auxi.check_all_exists(d.follower)) and ent.Child then ang = (ent.Child.Position - ent.Position):GetAngleDegrees() end
		local dir = auxi.GetDirectionByAngle(ang)
		if item.qing_fetus_map[dir] and s:GetAnimation() ~= item.qing_fetus_map[dir] then s:Play(item.qing_fetus_map[dir],true) end
	end,
})

item.register("fired_knife", {
	detect = function(d) return d.fired_knife end,
	update = function(ent, d)
		if d.Params.remove_color then
			local alpha = d.removecd/(d.Params.cooldown or 60)
			d.fired_knife:GetSprite().Color = auxi.AddColor(d.Params.Color or Color(1,1,1,1),Color(0,0,0,d.Params.Color.A),1,alpha - 1)
		end
		local d2 = d.fired_knife:GetData()
		-- 与 Knife_holder 互补：父体侧也保持高度，避免 Shoot 阶段 offset 被清零
		if d.Params.PosOffset then
			ent.PositionOffset = d.Params.PosOffset
			if d.fired_knife:Exists() then
				d.fired_knife.PositionOffset = d.Params.PosOffset
			end
		end
		if d2.link_brimstone and d2.Knife_link_brimstone:Exists() then
			d2.Knife_link_brimstone.Angle = 180 + ent.Velocity:GetAngleDegrees()
		end
		if d2.tail and d2.tail:Exists() then
			d2.tail.Position = d.fired_knife.Position + (d2.tail_pos_offset or Vector(0,0))
		end
		if d2.Tecro_blade_linked_knife and auxi.check_all_exists(d2.Tecro_blade_linked_knife) == false then ent:Remove() return true end
	end,
})

item.register("spike", {
	detect = function(d) return d.is_spike end,
	update = function(ent, d, s)
		if s:IsFinished("Summon") or s:IsFinished("SummonWomb") then
			local str = s:GetAnimation()
			local playname = "Unsummon"
			if string.find(str,"Womb") then playname = playname.."Womb" end
			s:Play(playname,true)
			local dmg = d.recorded_damage or 3.5
			local n_enemy = auxi.getenemies(Isaac.FindInRadius(ent.Position,35,1<<3))
			for u,v in pairs(n_enemy) do
				if item.grid_grounder[v.GridCollisionClass] then
					v:TakeDamage(dmg,0,EntityRef(ent),0)
				end
			end
		end
	end,
})

item.register("revealer", {
	detect = function(d) return d.is_revealer end,
	update = function(ent, d, s)
		ent.Velocity = ent.Velocity * 0.5
		if s:IsFinished("Appear") then s:Play("Idle",true) end
		if s:IsFinished("Idle") then s:Play("Disappear",true) end
		if s:IsFinished("Disappear") then ent:Remove() return true end
	end,
	render = function(ent, d, s)
		if d.linked_sprite then
			local amin = s:GetAnimation()
			local frame = s:GetFrame()
			local infos = item.revealer_info[amin]
			local info = infos.check(frame,infos)
			d.linked_sprite.Offset = s.Offset
			d.linked_sprite.Scale = auxi.mul_t(d.replace_scale,info.scale)
			d.linked_sprite.Rotation = info.rotation
			d.linked_sprite.Color = Color(1,1,1,info.alpha)
			d.linked_sprite:Render(Isaac.WorldToScreen(ent.Position) + (d.replace_offset or Vector(0,0)),Vector(0,0),Vector(0,0))
		end
	end,
})

item.register("revealee", {
	detect = function(d) return d.is_revealee end,
	update = function(ent, d, s)
		ent.Velocity = ent.Velocity * 0.5
		if s:IsEventTriggered("Drop") then
			if d.revealee_end then d.revealee_end(ent) d.revealee_end = nil end
		end
		if s:IsFinished("Appear") then ent:Remove() return true end
	end,
	render = function(ent, d, s)
		if d.linked_sprite then
			local amin = s:GetAnimation()
			local frame = s:GetFrame()
			local infos = item.revealee_info[amin]
			local info = infos.check(frame,infos)
			d.linked_sprite.Offset = s.Offset
			d.linked_sprite.Scale = auxi.mul_t(d.replace_scale,info.scale)
			d.linked_sprite.Rotation = info.rotation
			d.linked_sprite.Color = Color(1,1,1,info.alpha)
			d.linked_sprite:Render(Isaac.WorldToScreen(ent.Position) + (d.replace_offset or Vector(0,0)),Vector(0,0),Vector(0,0))
		end
	end,
	remove = function(ent, d)
		if d.revealee_end then
			delay_buffer.addeffe(function(params)
				d.revealee_end(ent)
			end,{},1)
		end
	end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.ID_EFFECT_MeusNIL,
Function = function(_,ent)
	if ent.Variant ~= enums.Entities.ID_EFFECT_MeusNIL then return end
	local d = ent:GetData()
	local s = ent:GetSprite()
	local player = (d.Params and d.Params.player) or Game():GetPlayer(0)
	if item.run_lifetime(ent, d, player) then return end

	local ret = auxi.check_if_any(d[item.own_key.."work"],ent) if ret then return end
	local ret2 = auxi.check_if_any(d[item.own_key.."work_addon"],ent) if ret2 then return end

	item.run_motion(ent, d, player)

	local mode = item.resolve_mode(d)
	local h = mode and item.handlers[mode]
	if h and h.update then
		h.update(ent, d, s, player)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 1000,
Function = function(_,ent)
	if ent.Variant ~= enums.Entities.ID_EFFECT_MeusNIL then return end
	local d = ent:GetData()
	local mode = item.resolve_mode(d)
	local h = mode and item.handlers[mode]
	if h and h.remove then
		h.remove(ent, d)
	elseif d.is_revealee and d.revealee_end then
		-- detect 可能尚未写入 nil_mode
		delay_buffer.addeffe(function(params)
			d.revealee_end(ent)
		end,{},1)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = enums.Entities.ID_EFFECT_MeusNIL,
Function = function(_,ent,offset)
	if (Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT) then return end
	local d = ent:GetData()
	local s = ent:GetSprite()
	local player = (d.Params and d.Params.player) or Game():GetPlayer(0)
	local mode = item.resolve_mode(d)
	local h = mode and item.handlers[mode]
	if h and h.render then
		h.render(ent, d, s, player, offset)
	end
end,
})

return item

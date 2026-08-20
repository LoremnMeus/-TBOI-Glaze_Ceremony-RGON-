local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Bomb_holder_",
}

--炸弹有很多需要修复的地方
function item.prevent_damage(ent,val)		--暂时只做角色的免疫
	local d = ent:GetData()
	d[item.own_key.."damage"] = val
end

--- 制造档案：给博士炸弹挂副效果（§14.7.2/5/6/9；§15.3/15.4）
function item.attach_craft_aux(bomb, profile, player, opts)
	if not bomb or not profile then return end
	opts = opts or {}
	local syn = profile.synergy or {}
	local d = bomb:GetData()
	local craft = d[item.own_key.."craft"] or {}
	local dmg_mul = opts.damage_mul or 1
	local size_mul = opts.size_mul or 1
	craft.profile = profile
	craft.player = player
	craft.dmg = ((profile.stats and profile.stats.damage) or 3.5) * dmg_mul
	craft.flags = profile.flag_mask
	craft.damage_mul = dmg_mul
	craft.size_mul = size_mul
	craft.haemo = CraftProfile.profile_has_haemolacria(profile)
	if syn.dr_brim then craft.brim_burst = true end
	if syn.dr_techx then craft.techx_ring = true end
	if syn.dr_tech then craft.tech_follow = true end
	if syn.dr_sword then
		craft.sword_near = true
		craft.sword_cd = 0
		craft.sword_hit = {}
	end
	d[item.own_key.."craft"] = craft
	CraftProfile.apply_bomb_item_effects(bomb, profile)

	-- size_mul 已是完整弹体尺寸（含豆浆 scale）；再套一次炸弹体型保险
	if size_mul and size_mul ~= 1 then
		CraftProfile.apply_bomb_scale(bomb, size_mul)
	end
	if craft.techx_ring then
		local Laser_holder = require("Qing_Remaster_scripts.mimics.Laser_holder")
		local q2 = Laser_holder.fire_follow_techx_ring({
			pos = bomb.Position,
			parent = bomb,
			source = player,
			radius = 40 * size_mul,
			dmg = (craft.dmg or 3.5) * 0.35,
			pos_offset = bomb.PositionOffset,
		})
		craft.techx_ent = q2
	end
	if craft.tech_follow and player then
		local q2 = player:FireTechLaser(bomb.Position, 1, Vector(1, 0), false, false, nil, 0.4)
		q2.DisableFollowParent = true
		local ld = q2:GetData()
		ld.followParent = bomb
		ld.craft_clear_if_dead = bomb
		q2:SetTimeout(9999)
		craft.tech_ent = q2
	end
end

local function clear_craft_lasers(craft)
	if not craft then return end
	if craft.techx_ent and craft.techx_ent:Exists() then
		craft.techx_ent:Remove()
	end
	craft.techx_ent = nil
	if craft.tech_ent and craft.tech_ent:Exists() then
		craft.tech_ent:Remove()
	end
	craft.tech_ent = nil
end

local function trigger_brim_burst(pos, player, dmg)
	if not player then return end
	local q2 = auxi.fire_nil(pos, Vector(0, 0), {cooldown = 45})
	local cnt = 6
	local rnd = math.random(36000) / 100
	for i = 0, cnt - 1 do
		local q1 = player:FireBrimstone(auxi.MakeVector(360 / cnt * i + rnd))
		q1.Parent = q2
		q1.Position = q2.Position
		q1.CollisionDamage = dmg * 0.6
	end
end

local function trigger_sword_slash(pos, player, dmg, flags)
	if not player then return end
	dmg = dmg or 3.5
	local dir = auxi.RoundVector()
	auxi.fire_dosome_knife(
		pos,
		dir:Normalized() / 1000,
		{TearFlags = flags or BitSet128(0, 0), TearColor = player.TearColor, TearDamage = dmg, TearScale = 1},
		"SpinUp",
		{player = player, dmgmul = 0.5, Flip = auxi.random_bool(), list = {}, dmg = dmg},
		nil
	)
end

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_,ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if player and player:GetPlayerType() == item.entity then
		if source and source.Entity then
			local d = source.Entity:GetData()
			if d[item.own_key.."damage"] then return false end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_BOMB_UPDATE, params = nil,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if d[item.own_key.."effect"].Sprite then 
			s:Load(d[item.own_key.."effect"].Sprite,true)
			s:Play("Pulse",true)
			d[item.own_key.."effect"].Sprite = nil 
		end
		if (d[item.own_key.."effect"].FVel or 0) > 0 then
			ent.PositionOffset = ent.PositionOffset + Vector(0,-d[item.own_key.."effect"].FVel)
			d[item.own_key.."effect"].FVel = d[item.own_key.."effect"].FVel - (d[item.own_key.."effect"].FAcce or 2)
		end
	end

	local craft = d[item.own_key.."craft"]
	if not craft then return end

	-- 血泪爆裂小炸弹：PO.Y 抛物线上飞（探针 Y0=-3，vy+=0.8）
	local jump = craft.hae_jump
	if jump and not jump.done then
		local y = (tonumber(jump.y) or -3) + (tonumber(jump.vy) or 0)
		local vy = (tonumber(jump.vy) or 0) + (tonumber(jump.accel) or 0.8)
		if y >= 0 then
			y = 0
			vy = 0
			jump.done = true
		end
		jump.y = y
		jump.vy = vy
		local po = ent.PositionOffset or Vector(0, 0)
		ent.PositionOffset = Vector(po.X, y)
	end

	local function trigger_craft_explode_fx()
		if craft.brim_burst and not craft.brim_done then
			craft.brim_done = true
			trigger_brim_burst(ent.Position, craft.player, craft.dmg or 3.5)
		end
		if craft.haemo and not craft.haemo_done then
			craft.haemo_done = true
			CraftProfile.spawn_craft_haemolacria_burst(
				craft.profile,
				ent.Position,
				ent.Velocity,
				craft.player,
				{
					player = craft.player,
					damage_mul = 0.45 * (craft.damage_mul or 1),
					size_mul = craft.size_mul or 1,
					tear_flags = craft.flags,
				}
			)
		end
		clear_craft_lasers(craft)
	end

	-- 炸弹消失：清跟随激光；若刚爆炸则触发硫磺爆 / 血泪
	if ent:IsDead() or not ent:Exists() then
		trigger_craft_explode_fx()
		d[item.own_key.."craft"] = nil
		return
	end

	-- Sprite 进入爆炸帧时也触发（部分炸弹 IsDead 偏晚）
	if (craft.brim_burst and not craft.brim_done) or (craft.haemo and not craft.haemo_done) then
		local anim = s:GetAnimation()
		if anim == "Explode" or s:IsPlaying("Explode") then
			trigger_craft_explode_fx()
		end
	end

	if craft.sword_near then
		craft.sword_cd = (craft.sword_cd or 0) - 1
		if craft.sword_cd <= 0 then
			local enemies = auxi.getenemies(Isaac.FindInRadius(ent.Position, 70, EntityPartition.ENEMY))
			for _, enemy in ipairs(enemies or {}) do
				local ptr = GetPtrHash(enemy)
				if enemy and enemy:Exists() and not enemy:IsDead() and not craft.sword_hit[ptr] then
					craft.sword_hit[ptr] = true
					craft.sword_cd = 18
					local epos = enemy.Position
					local player = craft.player
					local dmg = craft.dmg or 3.5
					local flags = craft.flags
					delay_buffer.addeffe(function()
						if enemy and enemy:Exists() and not enemy:IsDead() then
							trigger_sword_slash(enemy.Position, player, dmg, flags)
						elseif epos then
							trigger_sword_slash(epos, player, dmg, flags)
						end
					end, {}, 4)
					break
				end
			end
		end
	end
end,
})

return item

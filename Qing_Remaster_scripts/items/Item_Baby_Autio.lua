local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Baby_Anim = require("Qing_Remaster_scripts.others.Baby_Anim_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Baby_Autio,
	familiar = enums.Familiars.Baby_Autio,
	own_key = "Item_Baby_Autio_",
	ignore_type = {
		[1] = true,
		[3] = true,
	},
	float_lock = {
		Hide = true,
		Appear = true,
	},
	fear_range = 80,
	height_offset = Vector(0, -15),
	-- Halo_Autio：32px 图在动画内 XScale=400 → 半径 16*4=64
	halo_base_radius = 64,
	halo_anm2 = "gfx/effects/Halo/Halo_Autio.anm2",
	halo_fade_in = 0.11,
	halo_fade_out = 0.18,
	link_fade_in = 0.26,
	link_fade_out = 0.20,
	stay_time = 90,
	cooldown_time = 45,
	arrival_land_frame = 12,
	aura_damage_interval = 30,
	aura_damage_per_tick = 7 / 3,
	fear_refresh = 15,
}

local link_layer_ids = {1, 2, 3}

local function link_target_for_state(state)
	return state == "follow" and 0 or 1
end

local function sync_link_layers(s, effect)
	if not s or not s.GetLayer then
		return
	end
	local mul = effect.link_t or 0
	for _, lid in ipairs(link_layer_ids) do
		pcall(function()
			local lay = s:GetLayer(lid)
			if not lay then
				return
			end
			if mul <= 0 then
				if lay.SetVisible then
					lay:SetVisible(false)
				end
				if lay.SetColor then
					lay:SetColor(Color(1, 1, 1, 0, 0, 0, 0))
				end
				return
			end
			if lay.SetVisible then
				lay:SetVisible(true)
			end
			if lay.SetColor then
				lay:SetColor(Color(1, 1, 1, mul, 0, 0, 0))
			end
		end)
	end
end

local function tick_link_vis(effect)
	local target = link_target_for_state(effect.state)
	effect.link_target = target
	local cur = effect.link_t or 0
	local rate = target > cur and item.link_fade_in or item.link_fade_out
	effect.link_t = cur + (target - cur) * rate
	if target <= 0 and effect.link_t < 0.005 then
		effect.link_t = 0
	elseif target >= 1 and effect.link_t > 0.995 then
		effect.link_t = 1
	end
end

local seg_delays = {4, 4, 4, 4, 4}
local hide_head_y = {-5, -5, -69, -169, -269, -269}
local appear_head_y = {-269, -169, -69, -5, -5, -5}

local function smoothstep(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

local function sample_keyframe_y(frame, ys, delays)
	local acc = 0
	for i, d in ipairs(delays) do
		if frame < acc + d then
			local t = smoothstep((frame - acc) / d)
			local y0 = ys[i]
			local y1 = ys[i + 1] or ys[#ys]
			return y0 + (y1 - y0) * t
		end
		acc = acc + d
	end
	return ys[#ys]
end

local function anim_visual_offset(s)
	local anim = s:GetAnimation()
	local root_y = item.height_offset.Y
	if anim == "Idle" or anim == "Float" then
		return Vector(0, root_y - 5)
	end
	if anim == "Hide" then
		return Vector(0, root_y + sample_keyframe_y(s:GetFrame(), hide_head_y, seg_delays))
	end
	if anim == "Appear" then
		return Vector(0, root_y + sample_keyframe_y(s:GetFrame(), appear_head_y, seg_delays))
	end
	return Vector(0, root_y - 5)
end

local function halo_world_pos(ent, s)
	return ent.Position
		+ (ent.PositionOffset or Vector.Zero)
		+ anim_visual_offset(s)
end

local function halo_mul(effect)
	return smoothstep(effect.halo_t or 0)
end

local function halo_visible(effect)
	return (effect.halo_t or 0) > 0.008
end

local function begin_halo_in(effect)
	effect.halo_target = 1
end

local function begin_halo_out(effect)
	effect.halo_target = 0
end

local function ensure_halo_sprite(d)
	local sp = d[item.own_key.."halo"]
	if sp == nil then
		sp = Sprite()
		sp:Load(item.halo_anm2, true)
		sp:Play("Idle", true)
		d[item.own_key.."halo"] = sp
	end
	return sp
end

local function sync_halo_visual(sp, effect)
	local full = item.fear_range / item.halo_base_radius
	local mul = halo_mul(effect)
	local scale = full * mul
	sp.Scale = Vector(scale, scale)
	sp.Color = Color(1, 1, 1, mul)
end

local function tick_halo(ent, d, effect)
	local target = effect.halo_target or 0
	local cur = effect.halo_t or 0
	local rate = target > cur and item.halo_fade_in or item.halo_fade_out
	effect.halo_t = cur + (target - cur) * rate
	if target <= 0 and effect.halo_t < 0.01 then
		effect.halo_t = 0
	elseif target >= 1 and effect.halo_t > 0.99 then
		effect.halo_t = 1
	end
	if not halo_visible(effect) then
		return
	end
	local sp = ensure_halo_sprite(d)
	sync_halo_visual(sp, effect)
	local frame = Game():GetFrameCount()
	if d[item.own_key.."halo_clock"] ~= frame then
		sp:Update()
		d[item.own_key.."halo_clock"] = frame
	end
end

local function apply_fear_only(ent)
	local pos = ent.Position
	local range = item.fear_range
	for _, v in pairs(Isaac.GetRoomEntities()) do
		if (v.Position - pos):Length() < range then
			if auxi.isenemies(v) then
				v:AddFear(EntityRef(ent), item.fear_refresh)
			end
		end
	end
end

local function apply_aura_damage_tick(ent)
	local pos = ent.Position
	local range = item.fear_range
	local dmg = item.aura_damage_per_tick
	for _, v in pairs(Isaac.GetRoomEntities()) do
		if (v.Position - pos):Length() < range then
			if auxi.isenemies(v) then
				v:TakeDamage(dmg, 0, EntityRef(ent), 0)
				v:AddFear(EntityRef(ent), item.fear_refresh)
			elseif (not v:HasEntityFlags(EntityFlag.FLAG_FRIENDLY))
				and auxi.check_if_any(item.ignore_type[v.Type], v) ~= true
				and v.HitPoints < 10 then
				v:TakeDamage(2.5, 0, EntityRef(ent), 0)
			end
		end
	end
end

local function tick_aura_combat(ent, effect)
	apply_fear_only(ent)
	if not effect.aura_active then
		return
	end
	effect.aura_damage_cd = (effect.aura_damage_cd or item.aura_damage_interval) - 1
	if effect.aura_damage_cd <= 0 then
		apply_aura_damage_tick(ent)
		effect.aura_damage_cd = item.aura_damage_interval
	end
end

local function begin_aura_combat(effect)
	effect.aura_active = true
	effect.aura_damage_cd = item.aura_damage_interval
end

local function end_aura_combat(effect)
	effect.aura_active = false
	effect.aura_damage_cd = nil
end

local function detach_follow(ent, d)
	if d[item.own_key.."IsFollow"] then
		ent:RemoveFromFollowers()
		d[item.own_key.."IsFollow"] = nil
	end
end

local function attach_follow(ent, d)
	if not d[item.own_key.."IsFollow"] then
		ent:AddToFollowers()
		d[item.own_key.."IsFollow"] = true
	end
end

local function play_locked(ent, anim_name)
	Baby_Anim.reset(ent, item.own_key.."float")
	ent:GetSprite():Play(anim_name, true)
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity) + player:GetEffects():GetCollectibleEffectNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

-- 在宝宝本体之前画光圈，保证叠在身下
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_FAMILIAR_RENDER, params = item.familiar,
Function = function(_, ent, offset)
	local d = ent:GetData()
	local effect = d[item.own_key.."effect"]
	local s = ent:GetSprite()
	if effect then
		sync_link_layers(s, effect)
	end
	if not effect or not halo_visible(effect) then
		return
	end
	local room = Game():GetRoom()
	if room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	local sp = ensure_halo_sprite(d)
	sync_halo_visual(sp, effect)
	sp:Update()
	local pos = room:WorldToScreenPosition(halo_world_pos(ent, s))
		+ offset
		- room:GetRenderScrollOffset()
	sp:Render(pos, Vector(0, 0), Vector(0, 0))
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_, ent)
	local player = auxi.check_spawner_player(ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	d[item.own_key.."effect"] = d[item.own_key.."effect"] or {
		state = "follow",
		stay = 0,
		cooldown = 0,
		halo_t = 0,
		halo_target = 0,
		link_t = 1,
		link_target = 0,
	}
	local effect = d[item.own_key.."effect"]

	if auxi.check_all_exists(d[item.own_key.."tg"]) ~= true then
		d[item.own_key.."tg"] = auxi.choose2(auxi.getenemies())
	end
	local tg = d[item.own_key.."tg"]

	-- 光圈淡入淡出在状态机之前推进；线轴透明度在状态机之后推进
	tick_halo(ent, d, effect)

	if effect.state == "follow" then
		effect.halo_target = 0
		effect.halo_land_started = nil
		attach_follow(ent, d)
		Baby_Anim.tick_float_idle(ent, item.own_key.."float", {locked = item.float_lock})
		if Baby_Anim.is_float_idle_anim(s:GetAnimation()) then
			ent:FollowParent()
		end
		effect.cooldown = math.max(0, (effect.cooldown or 0) - 1)
		if effect.cooldown <= 0 and auxi.check_all_exists(tg) and Baby_Anim.is_float_idle_anim(s:GetAnimation()) then
			detach_follow(ent, d)
			effect.warp_pos = tg.Position + RandomVector() * 20
			play_locked(ent, "Hide")
			effect.state = "to_enemy_hide"
		end

	elseif effect.state == "to_enemy_hide" then
		ent.Velocity = Vector(0, 0)
		if s:IsFinished("Hide") then
			if effect.warp_pos then
				ent.Position = effect.warp_pos
				effect.warp_pos = nil
			elseif auxi.check_all_exists(tg) then
				ent.Position = tg.Position + RandomVector() * 20
			elseif player then
				ent.Position = player.Position
			end
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME, 0.7, 1.05, false, 0, 2)
			play_locked(ent, "Appear")
			end_aura_combat(effect)
			effect.halo_land_started = nil
			effect.stay = item.stay_time
			effect.state = "to_enemy_appear"
		end

	elseif effect.state == "to_enemy_appear" then
		ent.Velocity = Vector(0, 0)
		if s:GetFrame() >= item.arrival_land_frame then
			if not effect.halo_land_started then
				ensure_halo_sprite(d):Play("Idle", true)
				begin_halo_in(effect)
				effect.halo_land_started = true
			end
			if not effect.aura_active then
				begin_aura_combat(effect)
			end
		end
		tick_aura_combat(ent, effect)
		if s:IsFinished("Appear") then
			Baby_Anim.reset(ent, item.own_key.."float")
			s:Play("Float", true)
			effect.state = "at_enemy"
		end

	elseif effect.state == "at_enemy" then
		ent.Velocity = Vector(0, 0)
		tick_aura_combat(ent, effect)
		Baby_Anim.tick_float_idle(ent, item.own_key.."float", {locked = item.float_lock})
		effect.stay = (effect.stay or 0) - 1
		local leave = effect.stay <= 0 or auxi.check_all_exists(tg) ~= true
		if leave then
			end_aura_combat(effect)
			begin_halo_out(effect)
			if player then
				effect.warp_pos = player.Position
			end
			play_locked(ent, "Hide")
			effect.state = "to_player_hide"
		end

	elseif effect.state == "to_player_hide" then
		ent.Velocity = Vector(0, 0)
		if s:IsFinished("Hide") then
			if effect.warp_pos then
				ent.Position = effect.warp_pos
				effect.warp_pos = nil
			elseif player then
				ent.Position = player.Position
			end
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_SUMMON_POOF, 0.7, 1.05, false, 0, 2)
			play_locked(ent, "Appear")
			attach_follow(ent, d)
			effect.state = "to_player_appear"
		end

	elseif effect.state == "to_player_appear" then
		effect.halo_target = 0
		ent:FollowParent()
		if s:IsFinished("Appear") then
			Baby_Anim.reset(ent, item.own_key.."float")
			s:Play("Float", true)
			effect.cooldown = item.cooldown_time
			effect.link_t = 1
			effect.state = "follow"
		end

	else
		effect.state = "follow"
	end

	tick_link_vis(effect)
end,
})

return item

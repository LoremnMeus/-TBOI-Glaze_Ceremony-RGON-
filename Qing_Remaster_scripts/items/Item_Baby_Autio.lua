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
	-- Halo_Autio：32px 图在动画内 XScale=400 → 半径 16*4=64
	halo_base_radius = 64,
	halo_anm2 = "gfx/effects/Halo/Halo_Autio.anm2",
	halo_fade_time = 12,
	stay_time = 90,
	cooldown_time = 45,
	arrival_damage = 7,
	fear_refresh = 15,
}

local function smoothstep(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

local function halo_mul(effect)
	return smoothstep(effect.halo_t or 0)
end

local function halo_visible(effect)
	return (effect.halo_t or 0) > 0.001
end

local function begin_halo_in(effect)
	effect.halo_t = effect.halo_t or 0
	effect.halo_dir = 1
end

local function begin_halo_out(effect)
	effect.halo_dir = -1
end

local function clear_halo(effect)
	effect.halo_t = 0
	effect.halo_dir = 0
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
	if effect.halo_dir and effect.halo_dir ~= 0 then
		local speed = 1 / item.halo_fade_time
		effect.halo_t = (effect.halo_t or 0) + effect.halo_dir * speed
		if effect.halo_t >= 1 then
			effect.halo_t = 1
			effect.halo_dir = 0
		elseif effect.halo_t <= 0 then
			effect.halo_t = 0
			effect.halo_dir = 0
		end
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

local function apply_fear_burst(ent, do_damage)
	local pos = ent.Position
	local range = item.fear_range
	for _, v in pairs(Isaac.GetRoomEntities()) do
		if (v.Position - pos):Length() < range then
			if auxi.isenemies(v) then
				if do_damage then
					v:TakeDamage(item.arrival_damage, 0, EntityRef(ent), 0)
				end
				v:AddFear(EntityRef(ent), item.fear_refresh)
			elseif (not v:HasEntityFlags(EntityFlag.FLAG_FRIENDLY))
				and auxi.check_if_any(item.ignore_type[v.Type], v) ~= true
				and v.HitPoints < 10 then
				if do_damage then
					for i = 1, 4 do
						v:TakeDamage(2.5, 0, EntityRef(ent), 0)
					end
				end
			end
		end
	end
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
	local cnt = player:GetCollectibleNum(item.entity)
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
	if not effect or not halo_visible(effect) then
		return
	end
	local room = Game():GetRoom()
	if room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	local sp = ensure_halo_sprite(d)
	sync_halo_visual(sp, effect)
	local pos = room:WorldToScreenPosition(ent.Position) + offset - Game().ScreenShakeOffset
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
		halo_dir = 0,
	}
	local effect = d[item.own_key.."effect"]

	if auxi.check_all_exists(d[item.own_key.."tg"]) ~= true then
		d[item.own_key.."tg"] = auxi.choose2(auxi.getenemies())
	end
	local tg = d[item.own_key.."tg"]

	-- 光圈淡入淡出在各阶段都推进
	tick_halo(ent, d, effect)

	if effect.state == "follow" then
		clear_halo(effect)
		attach_follow(ent, d)
		Baby_Anim.tick_float_idle(ent, item.own_key.."float", {locked = item.float_lock})
		if Baby_Anim.is_float_idle_anim(s:GetAnimation()) then
			ent:FollowParent()
		end
		effect.cooldown = math.max(0, (effect.cooldown or 0) - 1)
		if effect.cooldown <= 0 and auxi.check_all_exists(tg) and Baby_Anim.is_float_idle_anim(s:GetAnimation()) then
			detach_follow(ent, d)
			play_locked(ent, "Hide")
			effect.state = "to_enemy_hide"
		end

	elseif effect.state == "to_enemy_hide" then
		ent.Velocity = Vector(0, 0)
		if s:IsFinished("Hide") then
			if auxi.check_all_exists(tg) then
				local offset = RandomVector() * 20
				ent.Position = tg.Position + offset
			elseif player then
				ent.Position = player.Position
			end
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEMON_HIT, 1, 1, false, 0, 2)
			play_locked(ent, "Appear")
			ensure_halo_sprite(d):Play("Idle", true)
			begin_halo_in(effect)
			apply_fear_burst(ent, true)
			effect.stay = item.stay_time
			effect.state = "to_enemy_appear"
		end

	elseif effect.state == "to_enemy_appear" then
		ent.Velocity = Vector(0, 0)
		apply_fear_burst(ent, false)
		if s:IsFinished("Appear") then
			Baby_Anim.reset(ent, item.own_key.."float")
			s:Play("Float", true)
			effect.state = "at_enemy"
		end

	elseif effect.state == "at_enemy" then
		ent.Velocity = Vector(0, 0)
		apply_fear_burst(ent, false)
		Baby_Anim.tick_float_idle(ent, item.own_key.."float", {locked = item.float_lock})
		effect.stay = (effect.stay or 0) - 1
		local leave = effect.stay <= 0 or auxi.check_all_exists(tg) ~= true
		if leave then
			begin_halo_out(effect)
			play_locked(ent, "Hide")
			effect.state = "to_player_hide"
		end

	elseif effect.state == "to_player_hide" then
		ent.Velocity = Vector(0, 0)
		-- 等光圈基本收完再传送，避免光圈带到玩家身边
		local can_warp = (effect.halo_t or 0) <= 0.05 or s:GetFrame() >= 10
		if s:IsFinished("Hide") and can_warp then
			clear_halo(effect)
			if player then
				ent.Position = player.Position
			end
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_HELL_PORTAL1, 0.6, 1, false, 0, 2)
			play_locked(ent, "Appear")
			effect.state = "to_player_appear"
		elseif s:IsFinished("Hide") and not can_warp then
			-- Hide 已播完但光圈未收完：停在末帧继续收
			s:SetFrame(s:GetLastFrame())
		end

	elseif effect.state == "to_player_appear" then
		ent.Velocity = Vector(0, 0)
		clear_halo(effect)
		if s:IsFinished("Appear") then
			attach_follow(ent, d)
			Baby_Anim.reset(ent, item.own_key.."float")
			s:Play("Float", true)
			effect.cooldown = item.cooldown_time
			effect.state = "follow"
		end

	else
		effect.state = "follow"
	end
end,
})

return item

local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Lung_laser_holder_",
}

local function lung_fire_opts(params, reason, damage_multiplier)
	params = params or {}
	if params.attack_ctx then
		local ctx = {
			mode = params.attack_ctx.mode or "inherit",
			attack = params.attack_ctx.attack,
			attack_id = params.attack_ctx.attack_id,
			emitter = params.attack_ctx.emitter,
			role = params.attack_ctx.role or "derived",
			reason = params.attack_ctx.reason or reason,
			damage_multiplier = params.attack_ctx.damage_multiplier or damage_multiplier,
			Source = params.attack_ctx.Source or params.player,
			offset_id = params.attack_ctx.offset_id,
			one_hit = params.attack_ctx.one_hit,
		}
		return ctx
	end
	if params.attack then
		return {
			mode = "inherit",
			attack = params.attack,
			emitter = params.emitter,
			role = "derived",
			reason = reason,
			damage_multiplier = damage_multiplier,
			Source = params.player,
			one_hit = true,
		}
	end
	if params.expected_attack then
		attack_holder.warn_missing_parent_once(
			reason or "lung_laser",
			"[AttackHolder] Lung laser emitted without parent Attack; fallback to untracked."
		)
	end
	return {
		mode = "untracked",
		reason = reason,
		damage_multiplier = damage_multiplier,
		Source = params.player,
		one_hit = true,
	}
end

function item.fire_one_lung_laser(player,pos,id,dir,leg,params)
	params = params or {}
	player = player or params.player or Game():GetPlayer(0)
	local dmgmul = auxi.choose(0.5,1,2,2,4)
	local opts = lung_fire_opts(params, "lung_laser", dmgmul)
	opts.offset_id = id or opts.offset_id or 0
	opts.one_hit = true
	opts.Source = opts.Source or player
	local q = attack_holder.FireTechLaser(player, pos or player.Position, dir or Vector(1,0), opts)
	if not q then return nil end
	q.PositionOffset = params.Posoffset or q.PositionOffset
	q.CollisionDamage = (params.dmg or q.CollisionDamage)/dmgmul * (params.Dmgmul or 1)
	q:SetMaxDistance(leg)
	q.SubType = 4
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	if ent.FrameCount >= 2 then
		local d = ent:GetData()
		if d[item.own_key.."effect"] and (d[item.own_key.."effect"].mul or 0) > 0 then
			local samples = ent:GetSamples()
			local dpos = auxi.MakeVector(ent.Angle)
			if #samples > 1 then dpos = samples:Get(#samples - 1) - samples:Get(#samples - 2) end
			local effect = d[item.own_key.."effect"]
			-- Branch lasers share the parent Attack when provided.
			if not effect.attack and not effect.attack_ctx then
				local parent_attack = select(1, attack_holder.GetAttackForMember(ent))
				if parent_attack then effect.attack = parent_attack end
			end
			local q = item.fire_one_lung_laser(effect.player,ent.EndPoint,0,auxi.get_by_rotate(dpos,auxi.random_2() * (effect.angle or 40)),(effect.legth or 80) + auxi.random_2() * (effect.leg2 or 50),effect)
			if q then
				q.TearFlags = q.TearFlags & ~(BitSet128(1<<8,0) | BitSet128(1<<16,0) | BitSet128(1<<17,0))
				local d2 = q:GetData()
				d2[item.own_key.."effect"] = auxi.copy(effect)
				d2[item.own_key.."effect"].mul = d2[item.own_key.."effect"].mul - 1
				d2[item.own_key.."effect"].angle = (d2[item.own_key.."effect"].angle or 40) + 30
				if d2[item.own_key.."effect"].mul <= 0 then q.SubType = 0 end
			end
			d[item.own_key.."effect"] = nil
		end
	end
end,
})

return item

-- 本模组宝宝：只做 register_compat / adapter 声明 + 薄控制源 API。
-- 无 callback。真正移动 owner 仍是 Craft_Familiar_holder + Familiar_Control_Selector.BLUEPRINT。
-- 复杂宝宝的状态机留在各自 Item 文件；这里只登记 Marri / Lu / Regenesis 这类纯跟随项。
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Familiar_Control_Selector = require("Qing_Remaster_scripts.mimics.Familiar_Control_Selector")
local H = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Qing_Familiars_holder_",
}

function item.blueprint_owned(ent)
	return Familiar_Control_Selector.is_owner(ent, Familiar_Control_Selector.BLUEPRINT) == true
end

function item.home_entity(ent, player)
	if item.blueprint_owned(ent) then
		local ctx = H.get_control_context(ent)
		if ctx and auxi.check_all_exists(ctx.air) then
			return ctx.air
		end
	end
	return player
end

function item.home_position(ent, player)
	local home = item.home_entity(ent, player)
	if home and home.Position then
		return home.Position
	end
	if player then return player.Position end
	return nil
end

function item.store_last_aim(ent, dir)
	if not ent or not dir or not dir.Length or dir:Length() < 0.01 then return end
	ent:GetData()[item.own_key .. "last_aim"] = dir:Normalized()
end

function item.last_aim(ent)
	return ent and ent:GetData()[item.own_key .. "last_aim"] or nil
end

function item.resolve_control_dir(ent, player, vanilla_dir)
	if item.blueprint_owned(ent) then
		local ctx = H.get_control_context(ent)
		local aim = ctx and ctx.intent and ctx.intent.aim_direction
		if aim and aim:Length() >= 0.01 then
			item.store_last_aim(ent, aim)
			return aim:Normalized()
		end
		return item.last_aim(ent)
	end
	if vanilla_dir and vanilla_dir.Length and vanilla_dir:Length() >= 0.01 then
		item.store_last_aim(ent, vanilla_dir)
		return vanilla_dir:Normalized()
	end
	return vanilla_dir
end

--- Flight attack-window：满蓄自动放；窗口提前结束只取消。玩家模式保持松手发射。
function item.resolve_attack_control(ent, player, vanilla_aim)
	if item.blueprint_owned(ent) then
		local ctx = H.get_control_context(ent)
		local intent = ctx and ctx.intent or {}
		local aim = item.resolve_control_dir(ent, player, nil)
		return {
			mode = "flight",
			want = intent.should_shoot == true and aim ~= nil and aim:Length() >= 0.01,
			aim = aim,
			auto_fire_when_full = true,
			cancel_on_window_end = true,
		}
	end
	return {
		mode = "player",
		want = vanilla_aim ~= nil,
		aim = vanilla_aim,
		release_on_falling_edge = true,
	}
end

function item.should_player_follow(ent)
	return item.blueprint_owned(ent) ~= true
end

function item.recipe_copies(ent, collectible_id, fallback)
	fallback = tonumber(fallback) or 1
	if item.blueprint_owned(ent) then
		local ctx = H.get_control_context(ent)
		if ctx and ctx.profile and ctx.profile.counts then
			local n = tonumber(ctx.profile.counts[collectible_id])
				or tonumber(ctx.profile.counts[tostring(collectible_id)])
			if n and n > 0 then return n end
		end
		return math.max(1, fallback)
	end
	return fallback
end

function item.register_mod_familiar(opts)
	if type(opts) ~= "table" then return end
	local collectible = opts.collectible
	local variant = opts.variant
	local key = opts.key
	if not collectible or not variant or type(key) ~= "string" then return end
	CraftProfile.register_compat({
		id = collectible,
		key = key,
		zh = opts.zh or key,
		en = opts.en or key,
		category = "familiar",
		movement = opts.movement or "follow",
		runtime_adapter = "craft:qfamiliar:" .. key,
		status = opts.status,
	})
	local adapter = {
		name = key,
		extra_key = key,
		collectible = collectible,
		-- 漏写不得当成 full：自家状态机必须继续跑。需要 full 时必须显式声明。
		control_mode = opts.control_mode or "move_only",
		no_fire = opts.no_fire ~= false,
		custom_animation = opts.custom_animation ~= false,
		custom_move = opts.custom_move == true,
		exclude_from_formation = opts.exclude_from_formation == true,
		supports_bffs = opts.supports_bffs == true,
		supports_lullaby = opts.supports_lullaby == true,
		is_leaving_formation = opts.is_leaving_formation,
		desired_count = opts.desired_count,
		instances = opts.instances,
		spawn = opts.spawn,
		update = opts.update,
	}
	H.register_adapter(variant, adapter)
	CraftProfile.register_runtime_adapter(key, "craft:qfamiliar:" .. key)
end

item.register_mod_familiar({
	collectible = enums.Items.Baby_Marri,
	variant = enums.Familiars.Baby_Marri,
	key = "baby_marri",
	zh = "宝宝玛丽",
	en = "Baby Marri",
	movement = "follow",
	control_mode = "move_only",
})

item.register_mod_familiar({
	collectible = enums.Items.Baby_Lu,
	variant = enums.Familiars.Baby_Lu,
	key = "baby_lu",
	zh = "宝宝露",
	en = "Baby Lu",
	movement = "follow",
	control_mode = "move_only",
})

item.register_mod_familiar({
	collectible = enums.Items.Regenesis,
	variant = enums.Familiars.Regenesis,
	key = "regenesis",
	zh = "再世纪",
	en = "Regenesis",
	movement = "follow",
	control_mode = "move_only",
})

return item

-- 自定义角色攻击对 Incubus / Cain's Other Eye / Twisted Pair 的统一复用入口。
-- 只提供「哪些宝宝应复制、发射原点和伤害倍率」，具体攻击仍由角色自己的统一攻击入口生成。
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Craft_Familiar_holder = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
local Craft_Advanced = require("Qing_Remaster_scripts.mimics.Craft_Advanced_Familiars_holder")

local Familiar_Control_Selector = require("Qing_Remaster_scripts.mimics.Familiar_Control_Selector")
local Familiar_Follower_Arbiter = require("Qing_Remaster_scripts.mimics.Familiar_Follower_Arbiter")

local item = {pre_ToCall = {}, ToCall = {}, myToCall = {}, own_key = "Character_Advanced_Familiars_holder_"}
local BLUEPRINT_BIND_KEY = "Craft_Familiar_holder_bind"

item.supported_players = {
	[enums.Players.wq] = true,        -- 表 Qing；里 Qing 由蓝图/Air Flight 独立处理
	[enums.Players.Tecro] = true,
	[enums.Players.annA] = true,      -- 里 Anna；明确不含表 Anna (enums.Players.Anna)
}

local function belongs_to(fam, player)
	local owner = fam and (fam.Player or auxi.check_spawner_player(fam))
	if owner and auxi.check_for_the_same(owner, player) then return true end
	if owner and owner.ControllerIndex ~= nil and player.ControllerIndex ~= nil
	and owner.ControllerIndex == player.ControllerIndex then return true end
	return (not owner) and Game():GetNumPlayers() == 1
end

local function is_supported_variant(variant)
	return variant == FamiliarVariant.INCUBUS
		or variant == FamiliarVariant.CAINS_OTHER_EYE
		or variant == FamiliarVariant.TWISTED_BABY
end

local function controlled_by_character(fam)
	if not fam or not is_supported_variant(fam.Variant) then return false end
	if fam:GetData()[BLUEPRINT_BIND_KEY] ~= nil then return false end
	local player = fam.Player or auxi.check_spawner_player(fam)
	if not player and Game():GetNumPlayers() == 1 then player = Isaac.GetPlayer(0) end
	return player and item.supported_players[player:GetPlayerType()] == true
end

item.CONTROLLER = "character_advanced_familiar"

local FIRE_DELAY_SENTINEL = 999999

local function suppress_familiar_weapons(fam, d)
	if not fam then return end
	-- Gello 同款：有 GetWeapon 时压 Charge/FireDelay，避免妈刀仍跟随宝宝
	if fam.GetWeapon then
		local ok_w, weapon = pcall(function() return fam:GetWeapon() end)
		if ok_w and weapon then
			pcall(function()
				if weapon.SetCharge then weapon:SetCharge(0) end
				if weapon.SetFireDelay then weapon:SetFireDelay(FIRE_DELAY_SENTINEL) end
			end)
		end
	end
	local fam_hash = GetPtrHash(fam)
	for _, kn in ipairs(Isaac.FindByType(EntityType.ENTITY_KNIFE, -1, -1, false, false)) do
		local knife = kn:ToKnife() or kn
		if knife and knife:Exists() then
			local parent = knife.Parent
			local spawner = knife.SpawnerEntity
			local match = (parent and GetPtrHash(parent) == fam_hash)
				or (spawner and GetPtrHash(spawner) == fam_hash)
			if match then
				local kd = knife:GetData()
				-- 制造射出的刀带 knife_flight，不要压制
				if kd.knife_flight then
				else
					if not kd[item.own_key.."weapon_suppressed"] then
						kd[item.own_key.."weapon_suppressed"] = true
						kd[item.own_key.."vis_was"] = knife.Visible ~= false
						kd[item.own_key.."coll_was"] = knife.EntityCollisionClass
					end
					knife.Visible = false
					knife.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
					knife.Velocity = Vector.Zero
					knife.Position = fam.Position
				end
			end
		end
	end
end

local function restore_familiar_weapons(fam, d)
	if not fam then return end
	if fam.GetWeapon then
		local ok_w, weapon = pcall(function() return fam:GetWeapon() end)
		if ok_w and weapon and weapon.SetFireDelay then
			pcall(function() weapon:SetFireDelay(0) end)
		end
	end
	for _, kn in ipairs(Isaac.FindByType(EntityType.ENTITY_KNIFE, -1, -1, false, false)) do
		local knife = kn:ToKnife() or kn
		if knife and knife:Exists() then
			local kd = knife:GetData()
			if kd[item.own_key.."weapon_suppressed"] then
				knife.Visible = kd[item.own_key.."vis_was"] ~= false
				if kd[item.own_key.."coll_was"] ~= nil then
					knife.EntityCollisionClass = kd[item.own_key.."coll_was"]
				end
				kd[item.own_key.."weapon_suppressed"] = nil
				kd[item.own_key.."vis_was"] = nil
				kd[item.own_key.."coll_was"] = nil
			end
		end
	end
end

Familiar_Control_Selector.register(item.CONTROLLER, 150, controlled_by_character, {
	on_gain = function(fam)
		Familiar_Follower_Arbiter.claim(fam, item.CONTROLLER, {followers = true})
	end,
	on_lost = function(fam)
		restore_familiar_weapons(fam, fam:GetData())
		Familiar_Follower_Arbiter.release(fam, item.CONTROLLER)
	end,
})

local CONTROLLED_VARIANTS = {
	FamiliarVariant.INCUBUS,
	FamiliarVariant.CAINS_OTHER_EYE,
	FamiliarVariant.TWISTED_BABY,
}

local roster_frame, roster = -1, {}
local king_frame, kings = -1, {}
local supported_last_frame = false

local function live_familiar(ent)
	local fam = ent and ent:ToFamiliar()
	if not fam then return nil end
	local ok, alive = pcall(function() return fam:Exists() and not fam:IsDead() end)
	return ok and alive and fam or nil
end

local function controlled_roster(force)
	local frame = Game():GetFrameCount()
	if not force and roster_frame == frame then return roster end
	roster_frame, roster = frame, {}
	for _, variant in ipairs(CONTROLLED_VARIANTS) do
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant, -1, false, false)) do
			local fam = live_familiar(ent)
			if fam then roster[#roster + 1] = fam end
		end
	end
	return roster
end

local function king_roster()
	local frame = Game():GetFrameCount()
	if king_frame == frame then return kings end
	king_frame, kings = frame, {}
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.KING_BABY, -1, false, false)) do
		local fam = live_familiar(ent)
		if fam then kings[#kings + 1] = fam end
	end
	return kings
end

local function has_supported_player()
	for i = 0, Game():GetNumPlayers() - 1 do
		if item.supported_players[Isaac.GetPlayer(i):GetPlayerType()] then return true end
	end
	return false
end

local function add_variant(out, player, variant, damage_mul, aim_mode)
	for _, fam in ipairs(controlled_roster()) do
		if fam.Variant == variant and belongs_to(fam, player)
			and fam:GetData()[BLUEPRINT_BIND_KEY] == nil
		then
			local bffs = player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS)
			local aim_dir = nil
			if aim_mode == "cain_random" then
				aim_dir = Craft_Advanced.random_cain_other_eye_aim(player)
			end
			out[#out + 1] = {
				familiar = fam,
				position = fam.Position,
				damage_mul = damage_mul * (bffs and 2 or 1),
				aim_dir = aim_dir,
			}
		end
	end
end

function item.get_attack_copies(player)
	local out = {}
	if not player or not item.supported_players[player:GetPlayerType()] then return out end
	add_variant(out, player, FamiliarVariant.INCUBUS, 0.75)
	-- 始终 75%；与 Lilith 无关。
	add_variant(out, player, FamiliarVariant.CAINS_OTHER_EYE, 0.75, "cain_random")
	-- Twisted Pair 本身会生成两个实体，每个各复制 37.5%。
	add_variant(out, player, FamiliarVariant.TWISTED_BABY, 0.375)
	return out
end

function item.for_each_attack_copy(player, callback)
	if type(callback) ~= "function" then return end
	for _, copy in ipairs(item.get_attack_copies(player)) do
		copy.familiar:GetData()[item.own_key.."drive_state"] = copy.familiar:GetData()[item.own_key.."drive_state"] or {}
		copy.familiar:GetData()[item.own_key.."drive_state"].head_delay = 8
		callback(copy.familiar, copy.damage_mul, copy.position, false, copy.aim_dir)
		-- 原版摇篮曲提高宝宝射速；角色攻击是离散统一入口，以第二份宝宝攻击提供等价输出。
		if player:HasTrinket(TrinketType.TRINKET_FORGOTTEN_LULLABY) then
			local aim2 = copy.aim_dir and Craft_Advanced.random_cain_other_eye_aim(player) or nil
			callback(copy.familiar, copy.damage_mul, copy.position, true, aim2 or copy.aim_dir)
		end
	end
end

function item.apply_familiar_tear_flags(player, flags)
	flags = flags or BitSet128(0, 0)
	if player and player:HasTrinket(TrinketType.TRINKET_BABY_BENDER)
	and not player:HasCollectible(CollectibleType.COLLECTIBLE_SPOON_BENDER) then
		flags = flags | TearFlags.TEAR_HOMING
	end
	return flags
end

-- 角色攻击 Provider：Gello 等宝宝统一分发入口（不复制 Qing/Tecro/Anna 武器分支）
item._attack_providers = {}

function item.register_attack_provider(player_type, provider)
	player_type = tonumber(player_type)
	if not player_type or type(provider) ~= "function" then return end
	item._attack_providers[player_type] = provider
end

function item.has_attack_provider(player)
	if not player then return false end
	return item._attack_providers[player:GetPlayerType()] ~= nil
end

--- request = {familiar_kind, source, origin, aim_dir, target, damage_mul, weapon_snapshot, suppress_player_cost}
--- 返回 {fired=, delay=, spawned=} 或 false
function item.dispatch_familiar_attack(player, request)
	if not player or type(request) ~= "table" then return {fired = false} end
	local provider = item._attack_providers[player:GetPlayerType()]
	if not provider then return {fired = false} end
	local ok, ret = pcall(provider, player, request)
	if not ok then return {fired = false} end
	if type(ret) ~= "table" then
		return {fired = ret and true or false}
	end
	return ret
end

local function get_player(fam)
	local player = fam and (fam.Player or auxi.check_spawner_player(fam))
	if not player and Game():GetNumPlayers() == 1 then player = Isaac.GetPlayer(0) end
	return player
end

local function get_anchor_and_aim(player)
	local anchor = player
	local input = player:GetShootingInput()
	local has_shoot_input = input and input:Length() >= 0.01
	local aim = has_shoot_input and input or Vector(0, 1)
	if player:HasCollectible(CollectibleType.COLLECTIBLE_KING_BABY) then
		for _, ent in ipairs(king_roster()) do
			if belongs_to(ent, player) then anchor = ent break end
		end
	end
	local ptype = player:GetPlayerType()
	if has_shoot_input and (ptype == enums.Players.Tecro or ptype == enums.Players.Tecrorun) then
		local cached_aim = player:GetData().now_dir
		if cached_aim and cached_aim:Length() >= 0.01 then aim = cached_aim end
	elseif (not has_shoot_input) and (ptype == enums.Players.Tecro or ptype == enums.Players.Tecrorun) then
		-- canShoot=false 时 GetShootingInput 可能为空，仍用缓存朝向（邪眼延迟开火）。
		local cached_aim = player:GetData().now_dir
		if cached_aim and cached_aim:Length() >= 0.01 then aim = cached_aim end
	end
	if not aim or aim:Length() < 0.01 then aim = Vector(0, 1) end
	return anchor, aim:Normalized(), has_shoot_input
end

local function twisted_side_index(fam, player)
	local list = {}
	for _, ent in ipairs(controlled_roster()) do
		if ent.Variant == FamiliarVariant.TWISTED_BABY
		and belongs_to(ent, player) and ent:GetData()[BLUEPRINT_BIND_KEY] == nil then list[#list + 1] = ent end
	end
	table.sort(list, function(a, b) return (a.InitSeed or 0) < (b.InitSeed or 0) end)
	for i, ent in ipairs(list) do if GetPtrHash(ent) == GetPtrHash(fam) then return i end end
	return 1
end

local function controlled_index(fam, player)
	local list = {}
	for _, ent in ipairs(controlled_roster()) do
		if belongs_to(ent, player) and ent:GetData()[BLUEPRINT_BIND_KEY] == nil then list[#list + 1] = ent end
	end
	table.sort(list, function(a, b) return (a.InitSeed or 0) < (b.InitSeed or 0) end)
	for i, ent in ipairs(list) do if GetPtrHash(ent) == GetPtrHash(fam) then return i, #list end end
	return 1, math.max(1, #list)
end

local function update_controlled(fam)
	if auxi.is_time_stopped() then
		fam.Velocity = Vector(0, 0)
		return
	end
	local player = get_player(fam)
	if not player then return end
	local anchor, aim, has_shoot_input = get_anchor_and_aim(player)
	-- 该隐另一只眼：射击时持续随机转向（原版也会一直换朝向）。
	if fam.Variant == FamiliarVariant.CAINS_OTHER_EYE and has_shoot_input then
		aim = Craft_Advanced.random_cain_other_eye_aim(player)
	end
	local d = fam:GetData()
	local target
	if player:HasTrinket(TrinketType.TRINKET_DUCT_TAPE) then
		d[item.own_key.."duct_position"] = d[item.own_key.."duct_position"] or Vector(fam.Position.X, fam.Position.Y)
		target = d[item.own_key.."duct_position"]
	elseif player:HasTrinket(TrinketType.TRINKET_FRIENDSHIP_NECKLACE) then
		d[item.own_key.."duct_position"] = nil
		local index, count = controlled_index(fam, player)
		local angle = Game():GetFrameCount() * 2 + (index - 1) * 360 / count
		target = player.Position + Vector.FromAngle(angle) * 44
	elseif fam.Variant == FamiliarVariant.TWISTED_BABY then
		d[item.own_key.."duct_position"] = nil
		local side = Vector(-aim.Y, aim.X)
		local sign = twisted_side_index(fam, player) % 2 == 1 and -1 or 1
		target = anchor.Position + aim * 2 + side * (18 * sign)
	else
		d[item.own_key.."duct_position"] = nil
		-- 普通 follower：超过外圈才追赶，进入内圈后停止，避免边界反复启停。
		local leashed = player:HasTrinket(TrinketType.TRINKET_CHILD_LEASH)
		local start_distance = leashed and 20 or 40
		local stop_distance = leashed and 10 or 20
		d[item.own_key.."follow_state"] = d[item.own_key.."follow_state"] or {}
		target = Craft_Familiar_holder.external_chain_target(
			anchor, fam, start_distance, stop_distance, d[item.own_key.."follow_state"]
		)
	end
	Familiar_Follower_Arbiter.claim(fam, item.CONTROLLER, {followers = true})
	d[item.own_key.."drive_state"] = d[item.own_key.."drive_state"] or {allow_snap = false}
	local drive_state = d[item.own_key.."drive_state"]
	if fam.Variant == FamiliarVariant.TWISTED_BABY then
		drive_state.distance_bias = 0
		-- 作孽双子需要紧贴左右槽位：接近旧版 delta*0.35，只保留少量速度混合防止硬跳。
		drive_state.speed_gain = 0.35
		drive_state.response = 0.45
		drive_state.max_speed = 14
	else
		drive_state.distance_bias = player:HasTrinket(TrinketType.TRINKET_CHILD_LEASH) and 10 or 20
		drive_state.speed_gain = 0.14
		drive_state.response = 0.16
		drive_state.max_speed = 10
	end
	if not has_shoot_input then drive_state.head_delay = 0 end
	-- 换房 SNAP：仅本帧允许硬拉；平时 keep allow_snap=false 以免软跟随抖动
	local room_snap = drive_state.need_snap == true
	if room_snap then drive_state.allow_snap = true end
	Craft_Familiar_holder.drive_external(fam, target, aim, drive_state)
	if room_snap then drive_state.allow_snap = false end
	fam.FireCooldown = 999999
	suppress_familiar_weapons(fam, d)
	d[item.own_key.."controlled"] = true
end

-- 完整接管：跳过原版移动/开火，POST_UPDATE 按角色控制源复写位置。
table.insert(item.pre_ToCall, {
	CallBack = ModCallbacks.MC_PRE_FAMILIAR_UPDATE,
	params = nil,
	Function = function(_, fam)
		if not controlled_by_character(fam) then return end
		return true
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		if not has_supported_player() then return end
		for _, fam in ipairs(controlled_roster(true)) do
			if controlled_by_character(fam) then
				local d = fam:GetData()
				d[item.own_key.."drive_state"] = d[item.own_key.."drive_state"] or {allow_snap = false}
				d[item.own_key.."drive_state"].need_snap = true
			end
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function(_)
		local supported_now = has_supported_player()
		-- 非支持角色常态下零扫描；若刚失去支持角色，仍做最后一帧清理并归还 follower。
		if not supported_now and not supported_last_frame then return end
		supported_last_frame = supported_now
		for _, fam in ipairs(controlled_roster()) do
			local d = fam:GetData()
			if controlled_by_character(fam) then
				update_controlled(fam)
			elseif d[item.own_key.."controlled"] then
				restore_familiar_weapons(fam, d)
				d[item.own_key.."controlled"] = nil
				d[item.own_key.."drive_state"] = nil
				fam.FireCooldown = 0
				Familiar_Follower_Arbiter.release(fam, item.CONTROLLER)
			end
		end
	end,
})

return item

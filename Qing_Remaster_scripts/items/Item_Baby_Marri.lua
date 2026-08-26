local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Baby_Anim = require("Qing_Remaster_scripts.others.Baby_Anim_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Baby_Marri,
	familiar = enums.Familiars.Baby_Marri,
	own_key = "Item_Baby_Marri_",
	deal_boost = 0.15,
}

local function persist_bag()
	save.elses[item.own_key.."run"] = save.elses[item.own_key.."run"] or {}
	return save.elses[item.own_key.."run"]
end

local function marri_count(player)
	if not player then return 0 end
	return player:GetCollectibleNum(item.entity) + player:GetEffects():GetCollectibleEffectNum(item.entity)
end

local function player_state(player)
	if not player then return nil end
	local bag = persist_bag()
	local key = tostring(player.InitSeed)
	local st = bag[key]
	if type(st) ~= "table" then
		st = {mode = "angel"}
		bag[key] = st
	end
	return st
end

--- 天使形态：Level:AddAngelRoomChance（天魔房开启后的天使转化率，非独立出现率）
local function angel_conversion_total()
	local total = 0
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player then
			local cnt = marri_count(player)
			if cnt > 0 then
				local st = player_state(player)
				if st and st.mode == "angel" then
					total = total + item.deal_boost * cnt
				end
			end
		end
	end
	return total
end

local function sync_level_angel_conversion()
	local level = Game():GetLevel()
	if not level or not level.AddAngelRoomChance then return end
	local bag = persist_bag()
	local want = angel_conversion_total()
	local applied = tonumber(bag.level_angel_applied) or 0
	if want ~= applied then
		level:AddAngelRoomChance(want - applied)
		bag.level_angel_applied = want
	end
end

local function reset_floor_angel_applied()
	persist_bag().level_angel_applied = 0
end

local function loop_anim(mode)
	return (mode == "devil") and "Float" or "Idle"
end

local function transition_anim(mode)
	return (mode == "devil") and "ToDevil" or "ToAngel"
end

local function is_transition_anim(anim)
	return anim == "ToDevil" or anim == "ToAngel"
end

local function trigger_visual_toggle(player, new_mode)
	local anim = transition_anim(new_mode)
	for _, fam in pairs(auxi.getothers(nil, 3, item.familiar) or {}) do
		if auxi.check_for_the_same(auxi.check_spawner_player(fam), player) then
			Baby_Anim.reset(fam, item.own_key.."float")
			fam:GetSprite():Play(anim, true)
		end
	end
end

local function toggle_mode(player)
	if marri_count(player) <= 0 then return end
	local st = player_state(player)
	st.mode = (st.mode == "devil") and "angel" or "devil"
	sync_level_angel_conversion()
	trigger_visual_toggle(player, st.mode)
end

--- 恶魔形态：MC_POST_DEVIL_CALCULATE 叠加天魔房总开启率（先于转化率结算）
local function devil_spawn_bonus_total()
	local bonus = 0
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player then
			local cnt = marri_count(player)
			if cnt > 0 then
				local st = player_state(player)
				if st and st.mode == "devil" then
					bonus = bonus + item.deal_boost * cnt
				end
			end
		end
	end
	return bonus
end

local function apply_devil_spawn_bonus(chance)
	local bonus = devil_spawn_bonus_total()
	if bonus <= 0 then return end
	return (tonumber(chance) or 0) + bonus
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	local cnt = marri_count(player)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
		sync_level_angel_conversion()
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."run"] = {}
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	reset_floor_angel_applied()
	sync_level_angel_conversion()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_, ent)
	local player = auxi.check_spawner_player(ent)
	if not player then return end
	local d = ent:GetData()
	local s = ent:GetSprite()
	if not d[item.own_key.."IsFollow"] then
		ent:AddToFollowers()
		d[item.own_key.."IsFollow"] = true
	end
	local st = player_state(player)
	local mode = (st and st.mode) or "angel"
	local anim = s:GetAnimation()

	if is_transition_anim(anim) then
		ent:FollowParent()
		if s:IsFinished(anim) then
			s:Play(loop_anim(mode), true)
			d[item.own_key.."shown_mode"] = mode
		end
		return
	end

	local shown = d[item.own_key.."shown_mode"]
	if shown ~= mode then
		if shown == nil then
			s:Play(loop_anim(mode), true)
			d[item.own_key.."shown_mode"] = mode
		end
	elseif anim ~= loop_anim(mode) then
		s:Play(loop_anim(mode), true)
	end

	ent:FollowParent()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_, ent, amount)
	if (tonumber(amount) or 0) <= 0 then return end
	local player = ent:ToPlayer()
	if player and marri_count(player) > 0 then
		toggle_mode(player)
	end
end,
})

if ModCallbacks.MC_POST_DEVIL_CALCULATE then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_DEVIL_CALCULATE, params = nil,
	Function = function(_, chance)
		return apply_devil_spawn_bonus(chance)
	end,
	})
end

return item

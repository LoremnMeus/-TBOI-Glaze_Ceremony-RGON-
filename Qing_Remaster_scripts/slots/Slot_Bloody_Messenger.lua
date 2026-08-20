local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Bloody_Map = require("Qing_Remaster_scripts.items.Item_Bloody_Map")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Slots.Bloody_Messenger,
	own_key = "Slot_Bloody_Messenger_",
}

local function is_soul_style(player)
	return auxi.is_player_only_soul_hearts(player) or auxi.is_soul_player(player)
end

-- 红心半额：floor(红心/2)，且至少保留半颗红心；红心不足则不可付。
local function calc_red_half_pay(player)
	local hearts = player:GetHearts()
	if hearts <= 0 then return nil end
	local pay = math.floor(hearts / 2)
	if hearts - pay < 1 then
		pay = hearts - 1
	end
	if pay < 1 then return nil end
	return pay
end

local function try_pay(player, ent)
	if not player or not player:Exists() then return nil end

	local soul = is_soul_style(player)
	local red_pay = calc_red_half_pay(player)

	if soul then
		-- 魂心角色：有红心则按红心半额付；否则付半颗血。收益始终走弱档。
		if red_pay then
			player:AddHearts(-red_pay)
			player:TakeDamage(0, DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_FAKE, EntityRef(ent), 30)
			return {boosted = false, paid_red = true}
		end
		local hp = player:GetHearts() + player:GetSoulHearts() + player:GetBoneHearts() * 2 + player:GetEternalHearts()
		if auxi.is_player_lost_(player) then
			player:TakeDamage(1, DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(ent), 30)
			return {boosted = false, paid_red = false}
		end
		if hp <= 1 then return nil end
		player:TakeDamage(1, DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(ent), 30)
		return {boosted = false, paid_red = false}
	end

	-- 普通角色：必须有红心，支付一半红心。
	if not red_pay then return nil end
	player:AddHearts(-red_pay)
	player:TakeDamage(0, DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_FAKE, EntityRef(ent), 30)
	return {boosted = true, paid_red = true}
end

local function spawn_cracked_key(ent, rng)
	local room = Game():GetRoom()
	local pos = room:FindFreePickupSpawnPosition(ent.Position + Vector(0, 40), 10, true)
	Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_CRACKED_KEY, pos, Vector(0, 0), ent)
end

local function spawn_ultra_item(ent, rng)
	local room = Game():GetRoom()
	local pool = Game():GetItemPool()
	local colid = pool:GetCollectible(ItemPoolType.POOL_ULTRASECRET, true, rng:Next())
	local pos = room:FindFreePickupSpawnPosition(ent.Position + Vector(0, 40), 10, true)
	Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, colid, pos, Vector(0, 0), ent)
	return true
end

local function show_ultra_grant_text(amount)
	local lang = Options.Language
	if lang == "zh" or lang == "zh_cn" then
		Game():GetHUD():ShowItemText("下层红隐藏 +"..tostring(amount), "")
	else
		Game():GetHUD():ShowItemText("Extra Ultra Secret +"..tostring(amount), "Next floor")
	end
end

local function reward_defs(boosted)
	return {
		{
			key = "nothing",
			weigh = function() return Bloody_Map.get_reward_weight("nothing", false) end,
			work = function() end,
		},
		{
			key = "ultra_room",
			weigh = function() return Bloody_Map.get_reward_weight("ultra_room", boosted) end,
			check = function() return Bloody_Map.can_grant_extra_ultra() end,
			work = function()
				local amount = Bloody_Map.queue_extra_ultra()
				if amount then show_ultra_grant_text(amount) end
			end,
		},
		{
			key = "cracked_key",
			weigh = function() return Bloody_Map.get_reward_weight("cracked_key", boosted) end,
			work = function(e, r)
				spawn_cracked_key(e, r)
			end,
		},
		{
			key = "ultra_item",
			weigh = function() return Bloody_Map.get_reward_weight("ultra_item", boosted) end,
			work = function(e, r)
				return spawn_ultra_item(e, r)
			end,
		},
	}
end

local function roll_one_reward(ent, rng, boosted, used)
	used = used or {}
	local candidates = {}
	for _, v in ipairs(reward_defs(boosted)) do
		if used[v.key] then
		elseif boosted and v.key == "nothing" then
		elseif (not v.check or v.check()) and (v.weigh() or 0) > 0 then
			table.insert(candidates, #candidates + 1, {weigh = v.weigh(), info = v})
		end
	end
	local pick = auxi.random_in_weighed_table(candidates, rng)
	if not pick then return nil, false end
	local leave = auxi.check_if_any(pick.info.work, ent, rng, pick.info, item) == true
	return pick.info.key, leave
end

local function roll_rewards(ent, rng, boosted)
	local used = {}
	local leave = false
	local key, leave1 = roll_one_reward(ent, rng, boosted, used)
	if key then
		used[key] = true
		leave = leave or leave1
	end
	if boosted and rng:RandomFloat() < Bloody_Map.get_double_reward_chance() then
		local _, leave2 = roll_one_reward(ent, rng, boosted, used)
		leave = leave or leave2
	end
	return leave
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_INIT, params = item.entity.Variant,
Function = function(_,ent)
	local s = ent:GetSprite()
	s.Offset = Vector(0, 5)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_COLLISION, params = item.entity.Variant,
Function = function(_,ent,col,low)
	local s = ent:GetSprite()
	local d = ent:GetData()
	if not s:IsPlaying("Idle") then return end
	local player = col and col:ToPlayer()
	if not player then return end

	local paid = try_pay(player, ent)
	if not paid then return end

	d[item.own_key.."boosted"] = paid.boosted == true
	local rng = ent:GetDropRNG()
	if not paid.boosted and rng:RandomFloat() < Bloody_Map.get_pay_nothing_chance() then
		s:Play("PayNothing", true)
	else
		s:Play("PayPrize", true)
	end
	player:SetColor(Color(0.8, 0.1, 0.1, 1), 30, 10, true, false)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_UPDATE, params = item.entity.Variant,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local rng = ent:GetDropRNG()
	if s:IsFinished("Teleport") then
		ent:Remove()
		return
	end
	if s:IsFinished("Prize") then
		local leave = roll_rewards(ent, rng, d[item.own_key.."boosted"] == true)
		if leave then
			s:Play("Teleport", true)
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			return
		end
	end
	if s:IsFinished("Prize") or s:IsFinished("PayNothing") then
		s:Play("Idle", true)
	end
	if s:IsFinished("PayPrize") then
		s:Play("Prize", true)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_KILL, params = item.entity.Variant,
Function = function(_,ent,killer)
	local s = ent:GetSprite()
	s:Play("Teleport", true)
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	Game():GetLevel():SetStateFlag(LevelStateFlag.STATE_BUM_KILLED, true)
end,
})

local function eid_lang()
	if EID and EID.UserConfig and EID.UserConfig.Language and EID.UserConfig.Language ~= "auto" then
		return EID.UserConfig.Language
	end
	local lang = Options.Language
	if lang == "zh" then return "zh_cn" end
	if lang == "en" then return "en_us" end
	return lang or "en_us"
end

local function build_messenger_eid(player)
	local zh = eid_lang() == "zh_cn" or eid_lang() == "zh"
	local soul = player and (auxi.is_player_only_soul_hearts(player) or auxi.is_soul_player(player))
	local has_red = player and player:GetHearts() > 0
	if soul then
		if has_red then
			if zh then
				return "{{Heart}} 支付一半红心（下取整）"..
					"#可能一无所获"..
					"#{{Card78}} 红钥匙碎片"..
					"#下层额外{{UltraSecretRoom}}红隐藏（整局有限次）"..
					"#{{UltraSecretRoom}}红隐藏房道具，然后离开"
			end
			return "{{Heart}} Pay half your red hearts (floored)"..
				"#May give nothing"..
				"#{{Card78}} Cracked Key"..
				"#Extra {{UltraSecretRoom}} next floor (limited per run)"..
				"#{{UltraSecretRoom}} item, then leaves"
		end
		if zh then
			return "{{SoulHeart}} 支付半颗血"..
				"#可能一无所获"..
				"#{{Card78}} 红钥匙碎片"..
				"#下层额外{{UltraSecretRoom}}红隐藏（整局有限次）"..
				"#{{UltraSecretRoom}}红隐藏房道具，然后离开"
		end
		return "{{SoulHeart}} Pay half a heart"..
			"#May give nothing"..
			"#{{Card78}} Cracked Key"..
			"#Extra {{UltraSecretRoom}} next floor (limited per run)"..
			"#{{UltraSecretRoom}} item, then leaves"
	end
	if zh then
		return "{{Heart}} 支付一半红心（下取整）"..
			"#{{Card78}} 红钥匙碎片"..
			"#下层额外{{UltraSecretRoom}}红隐藏（整局有限次）"..
			"#{{UltraSecretRoom}}红隐藏房道具，然后离开"..
			"#有概率连续获得2种不同奖励"
	end
	return "{{Heart}} Pay half your red hearts (floored)"..
		"#{{Card78}} Cracked Key"..
		"#Extra {{UltraSecretRoom}} next floor (limited per run)"..
		"#{{UltraSecretRoom}} item, then leaves"..
		"#Chance to grant 2 different rewards"
end

if EID then
	EID:addDescriptionModifier("qing_bloody_messenger_eid", function(desc)
		return desc.ObjType == 6 and desc.ObjVariant == item.entity.Variant
	end, function(desc)
		local player = (EID and EID.player) or Game():GetPlayer(0)
		desc.Description = build_messenger_eid(player)
		return desc
	end)
end

return item

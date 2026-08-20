local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Hypermnesia,
	own_key = "Item_Hypermnesia_",
	buffs = {
		[1] = {name = "speed",cache = CacheFlag.CACHE_SPEED,
			toget = function(player) return player.MoveSpeed end,mul = 0.05,},
		[2] = {name = "tear",cache = CacheFlag.CACHE_FIREDELAY,
			toget = function(player) return 30 / (player.MaxFireDelay + 1) end,mul = 0.15,},
		[3] = {name = "damage",cache = CacheFlag.CACHE_DAMAGE,
			toget = function(player) return player.Damage end,mul = 0.5,},
		[4] = {name = "range",cache = CacheFlag.CACHE_RANGE,
			toget = function(player) return player.TearRange end,mul = 1 * 40,},
		[5] = {name = "luck",cache = CacheFlag.CACHE_LUCK,
			toget = function(player) return player.Luck end,mul = 1,},
	},
	Colorinfo = {
		{frame = 0 * 18,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 18,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 18,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 18,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 18,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 18,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		
		{frame = 6 * 18,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 18,
	},
	stat_cache = CacheFlag.CACHE_SPEED | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_RANGE | CacheFlag.CACHE_LUCK,
}

local function is_stat_cache(cacheFlag)
	return cacheFlag == CacheFlag.CACHE_SPEED
		or cacheFlag == CacheFlag.CACHE_FIREDELAY
		or cacheFlag == CacheFlag.CACHE_DAMAGE
		or cacheFlag == CacheFlag.CACHE_RANGE
		or cacheFlag == CacheFlag.CACHE_LUCK
end

local function get_duplicate_mul(player)
	local d = player:GetData()
	local frame = Game():GetFrameCount()
	local count = player:GetCollectibleCount()
	if d[item.own_key.."mul_frame"] == frame and d[item.own_key.."mul_count"] == count and d[item.own_key.."mul"] ~= nil then
		return d[item.own_key.."mul"]
	end
	local mul = auxi.get_player_s_item_count(player)
	d[item.own_key.."mul"] = mul
	d[item.own_key.."mul_frame"] = frame
	d[item.own_key.."mul_count"] = count
	return mul
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if not is_stat_cache(cacheFlag) then return end
	if auxi.has_have_coll(player,item.entity) then
		local mul = get_duplicate_mul(player)
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + mul * item.buffs[1].mul
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * mul * item.buffs[2].mul)
		end
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * mul * item.buffs[3].mul
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + mul * item.buffs[4].mul
		end
		if cacheFlag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + mul * item.buffs[5].mul
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	if player:HasCollectible(item.entity) or collid == item.entity then
		player:GetData()[item.own_key.."mul"] = nil
		player:AddCacheFlags(item.stat_cache)
		player:GetData().should_evaluate_on_update_once = true
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local d = ent:GetData()
		d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
		ent:GetSprite().Color = auxi.table2color(auxi.check_lerp(d[item.own_key.."counter"] % item.Colorinfo.total,item.Colorinfo))
	end
end,
})

return item
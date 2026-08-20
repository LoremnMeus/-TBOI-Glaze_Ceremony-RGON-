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
	entity = enums.Trinkets.Puncture_Symbol,
	own_key = "Trinkets_Puncture_Symbol_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_TRINKET, params = item.entity,
Function = function(_,player,tid,cnt,touched,curNum,known,golden,total)
	local cnt = total or cnt
	if (not known and curNum ~= 0) or player:HasTrinket(item.entity) ~= true then cnt = 0 end
	cnt = cnt * 2
	delay_buffer.addeffe(function(params)
		for i = 1,cnt do 
			player:TakeDamage(1,DamageFlag.DAMAGE_INVINCIBLE | DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_SPIKES | DamageFlag.DAMAGE_NO_MODIFIERS,EntityRef(player),0)
			player:ResetDamageCooldown()
			Isaac.Spawn(1000,2,auxi.choose(0,3,4),player.Position,Vector(0,0),nil)
		end
	end,{},30)
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		if cacheFlag == CacheFlag.CACHE_TEARFLAG then
			if player:GetTrinketMultiplier(item.entity) > 0 then
				player.TearFlags = player.TearFlags | BitSet128(1<<0,0) | BitSet128(1<<1,0)
			end
		end
	end
end,
})

return item
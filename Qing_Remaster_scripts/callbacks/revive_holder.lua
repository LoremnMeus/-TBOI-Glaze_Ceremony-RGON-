local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	own_key = "Callback_revive_",
	mx_counter = 95,
	revive_time_map = {
		["LostDeath"] = 60,
	},
}

function item.revive_player(player,tp)
	tp = tp or "Unknown"
	local d = player:GetData()
	local heart = (player:GetBoneHearts() + player:GetSoulHearts() + player:GetHearts()) > 0
	local only_bone_hearts = auxi.is_player_only_bone_hearts(player)
	local only_red_hearts = auxi.is_player_only_red_hearts(player)
	if (not heart) then
		if(only_bone_hearts) then player:AddBoneHearts(1)
		elseif(only_red_hearts) then
			if player:GetMaxHearts() <= 0 then player:AddMaxHearts(2) end
			player:AddHearts(1)
		end
		if player:GetMaxHearts() > 0 then
			if player:GetHearts() <= 0 then player:AddHearts(1 - player:GetHearts()) end
		else
			if player:GetSoulHearts() <= 0 then	auxi.add_soul_heart(player,1) end
		end
	end
	player:SetMinDamageCooldown(60)
	if d[item.own_key.."entitycollision_succ"] then Attribute_holder.try_rewind_attribute(player,"EntityCollisionClass",d[item.own_key.."entitycollision_succ"]) d[item.own_key.."entitycollision_succ"] = nil end
	if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] then Attribute_holder.try_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = nil end
	player:StopExtraAnimation()
	if d[item.own_key.."effect"].info and d[item.own_key.."effect"].info.on_revive then d[item.own_key.."effect"].info.on_revive(player,tp) end
	d[item.own_key.."effect"] = nil
	d[item.own_key.."Animation"] = nil
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
    if d[item.own_key.."effect"] then
        player.Velocity = Vector(0,0)
        player:SetMinDamageCooldown(60)
		d[item.own_key.."entitycollision_succ"] = d[item.own_key.."entitycollision_succ"] or Attribute_holder.try_hold_attribute(player,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
		d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] or Attribute_holder.try_hold_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK))
		player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		if d[item.own_key.."effect"].info and d[item.own_key.."effect"].info.on_revive_update then d[item.own_key.."effect"].info.on_revive_update(player,d[item.own_key.."effect"].counter) end
		if (d[item.own_key.."effect"].counter or 0) > (d[item.own_key.."effect"].mx_counter or item.mx_counter) then item.revive_player(player,"normal") end
    end
end,
})

function item.fake_revive(player,params)
	params = params or {}
	local d = player:GetData()
	local heart = (player:GetBoneHearts() + player:GetSoulHearts() + player:GetHearts()) > 0
	local isForgottenB = player:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN_B
	local has_add_heart_container = false
	local only_bone_hearts = auxi.is_player_only_bone_hearts(player)
	local only_red_hearts = auxi.is_player_only_red_hearts(player)
	if not heart then
		if only_bone_hearts then player:AddBoneHearts(1)
		elseif only_red_hearts then
			if player:GetMaxHearts() <= 0 then 
				player:AddMaxHearts(2)
				has_add_heart_container = true
			end
			player:AddHearts(2)
		end
	end
	player:Revive()
	auxi.check_if_any(params,player)
	if isForgottenB then if not player.Visible then player.Visible = true end end
	if only_red_hearts and has_add_heart_container then player:AddMaxHearts(-2)	end
	if not heart then
		if player:GetHearts() > 0 then player:AddHearts(-player:GetHearts()) end
		if player:GetBoneHearts() > 0 then player:AddBoneHearts(-player:GetBoneHearts()) end
		local soulHearts = player:GetSoulHearts()
		if player:GetSoulHearts() > 0 then auxi.add_soul_heart(player, -player:GetSoulHearts())	end
	end
end

function item.on_revive_update(player)
	local d = player:GetData()
	if d[item.own_key.."Animation"] then player:PlayExtraAnimation(d[item.own_key.."Animation"]) d[item.own_key.."Animation"] = nil end
	if (player:GetSprite():IsEventTriggered("DeathSound")) then	sound_tracker.PlayStackedSound(SoundEffect.SOUND_ISAACDIES,1,1,false,0,2) end
end

function item.on_revive_init(player)
	local d = player:GetData()
	d[item.own_key.."Animation"] = auxi.get_death_animation_to_play(player)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = 1,
Function = function(_,ent)
	local player = ent:ToPlayer()
	if player == nil then return end
	local d = player:GetData()
	local ret = (d[item.own_key.."effect"] or {}).info or callback_manager.work_with_result("PRE_PLAYER_KILL",function(funct,params,value) if params == nil or params == player.Variant then return funct(nil,player) end end,{},function(ret) if (ret or {}).should_revive then return true end end)
	if ret.should_revive then
		ret.reviver = ret.reviver or item.fake_revive ret.reviver(player) 
		ret.init_revive = ret.init_revive or item.on_revive_init 
		ret.on_revive_update = ret.on_revive_update or item.on_revive_update
		 if d[item.own_key.."effect"] == nil then ret.init_revive(player) end
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {counter = 0,mx_counter = ret.revive_time or item.revive_time_map[auxi.get_death_animation_to_play(player)] or item.mx_counter,info = ret,}
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		if d[item.own_key.."effect"] then
			item.revive_player(player,"exit")
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = InputHook.IS_ACTION_TRIGGERED,
Function = function(_,ent, hook, action)
	if ent ~= nil then
		local player = ent:ToPlayer()
		if player then
			local d = player:GetData()
			if d[item.own_key.."effect"] then
				if action <= ButtonAction.ACTION_DROP then
					return false
				end
			end
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_NPC_COLLISION, params = nil,
Function = function(_,ent, col, low)
	 if col:ToPlayer() then
        local d = col:GetData()
        if d[item.own_key.."effect"] then return false end
    end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PLAYER_COLLISION, params = nil,
Function = function(_,player, col, low)
	local d = player:GetData()
	if d[item.own_key.."effect"] then return false end
end,
})

return item

local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local custom_attack_manager = require("Qing_Remaster_scripts.player.custom_attack_manager")
local player_wq = require("Qing_Remaster_scripts.player.player_wq")

local item = {
	ToCall = {},
	post_ToCall = {},
	entity = enums.Items.Touchstone,
	own_key = "Item_Touchstone_",
	mode_id = "touchstone_qing",
}

function item.GetModeState(state)
	state.flags[item.mode_id] = state.flags[item.mode_id] or {
		delay = 0,
		maxDelay = 0,
		state = 0,
		delayPenalty = nil,
		uses = 0,
		bookOfBelial = false,
	}
	return state.flags[item.mode_id]
end

function item.SetActive(player,active)
	if not player then return end
	local d = player:GetData()
	d[item.own_key.."active"] = active == true
	if not active then
		d[item.own_key.."active"] = nil
	end
end

function item.IsActive(player)
	return player and player:GetData()[item.own_key.."active"] == true
end

function item.FireQingAttack(player,state,input)
	local mode_state = item.GetModeState(state)
	mode_state.delay = math.max(0,(mode_state.delay or 0) - 1)
	local gdir = (input and input.fireDir) or Vector.Zero
	if gdir:Length() < 0.05 then
		mode_state.state = 0
		if (mode_state.delayPenalty or 0) > 0 then
			mode_state.delay = mode_state.delay + mode_state.delayPenalty
			mode_state.delayPenalty = nil
		end
		return
	end

	if mode_state.delay > 0 then return end

	local list = auxi.get_qing_list(player)
	if mode_state.bookOfBelial then
		list.brimstone = math.max(list.brimstone or 0,1)
	end
	local weap = auxi.get_weapon(player)
	local attack_params = auxi.get_Qing_multishots(player,list,{allowrand = true,extraTearsFallback = mode_state.uses or 0})
	for i = #attack_params,1,-1 do
		local info = attack_params[i]
		local dir = auxi.MakeVector(info.dir + gdir:GetAngleDegrees()) * math.max(0.6,math.min(3,0.7 * player.ShotSpeed + 0.3 + math.log(player.TearRange/260)))
		local weap_listinfo = auxi.check_if_any(player_wq.attack_list[weap],player_wq) or player_wq.attack_list[1]
		mode_state.state = auxi.check_if_any(weap_listinfo.state_trans,mode_state.state,list) or mode_state.state
		local weapinfo = player_wq.attack_list[info.Anim] or weap_listinfo[mode_state.state] or player_wq.attack_list[1][0]
		local tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
		local params = {
			tearflag = info.tearflag,
			color = info.color,
			state = mode_state.state,
			weap = weap,
			list = list,
			charge = 1,
		}
		local ret = auxi.check_if_any(weapinfo,player,dir,tearHitParams,weapinfo,player_wq,params) or {delay = player.MaxFireDelay}
		if type(ret) == "number" then ret = {mul = ret} end
		if ret.special then
			auxi.check_if_any(ret.special,player,dir,tearHitParams,ret.special,player_wq,params)
		end
		if weap_listinfo.special then
			auxi.check_if_any(weap_listinfo.special,player,dir,tearHitParams,ret.special,player_wq,params)
		end
		if i == 1 then
			mode_state.state = ret.state or (mode_state.state + 1)
			mode_state.delay = ret.delay or (player.MaxFireDelay * (ret.mul or 1)) * (auxi.check_if_any(weap_listinfo.delaymul,player) or 1)
			mode_state.delay = auxi.check_if_any(weap_listinfo.delay,player,mode_state.delay) or mode_state.delay
			mode_state.maxDelay = mode_state.delay
			mode_state.delayPenalty = auxi.check_if_any((ret.punimul or 0) * player.MaxFireDelay)
		end
	end
end

custom_attack_manager.RegisterMode(item.mode_id,{
	id = item.mode_id,
	kind = "replacement",
	priority = 20,
	is_active = function(player,state,reason)
		return item.IsActive(player)
	end,
	enter = function(player,state,previousMode,reason)
		local mode_state = item.GetModeState(state)
		mode_state.delay = 0
		mode_state.maxDelay = 0
		mode_state.state = 0
		mode_state.delayPenalty = nil
		custom_attack_manager.SetVanillaShootSuppressed(player,state,true,item.mode_id)
	end,
	update = function(player,state,context)
		custom_attack_manager.SetVanillaShootSuppressed(player,state,true,item.mode_id)
		item.FireQingAttack(player,state,(context or {}).input)
	end,
	exit = function(player,state,nextMode,reason)
		custom_attack_manager.SetVanillaShootSuppressed(player,state,false,item.mode_id)
		item.SetActive(player,false)
		if state and state.flags then
			state.flags[item.mode_id] = nil
		end
	end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	item.SetActive(player,true)
	local state = custom_attack_manager.GetState(player)
	local use_count = 1
	if state then
		local old_mode_state = state.flags and state.flags[item.mode_id]
		use_count = (old_mode_state and old_mode_state.uses or 0) + 1
		state.flags[item.mode_id] = nil
	end
	custom_attack_manager.SwitchMode(player,item.mode_id,"touchstone_use")
	state = custom_attack_manager.GetState(player)
	if state then
		local mode_state = item.GetModeState(state)
		mode_state.uses = use_count
		mode_state.bookOfBelial = true
	end
	return true
end,
})

if ModCallbacks.MC_EVALUATE_MULTI_SHOT_PARAMS then
	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_MULTI_SHOT_PARAMS,
	Function = function(_,player,multiShotParams,weaponType)
		if weaponType ~= WeaponType.WEAPON_TEARS or not item.IsActive(player) or not multiShotParams then return end
		local state = custom_attack_manager.GetState(player)
		local mode_state = state and item.GetModeState(state)
		local uses = mode_state and mode_state.uses or 0
		if uses <= 0 then return end
		local ok,num = pcall(function() return multiShotParams:GetNumTears() end)
		if not ok then return end
		multiShotParams:SetNumTears(math.max(1,num + uses))
		return multiShotParams
	end,
	})
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local d = ent:GetData()
		if (d[item.own_key.."counter"] or 0) > 0 then d[item.own_key.."counter"] = d[item.own_key.."counter"] - 1 end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent,col,low)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local player = auxi.check_spawner_player(ent)
		local d = ent:GetData()
		if (d[item.own_key.."counter"] or 0) <= 0 and auxi.isenemies(col) and ent.State == -1 then 
			d[item.own_key.."counter"] = 5 * 30
			local dir = ent.Velocity:Normalized() * 10
			auxi.fire_dosome_knife(ent.Position,dir,nil,"StabDown",{player = player,repel = dir * 0.5,dmgmul = 0.5,no_co_repel = true,},nil)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for i = 0,Game():GetNumPlayers() - 1 do
		item.SetActive(Game():GetPlayer(i),false)
	end
end,
})

return item

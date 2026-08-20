local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Annihilation,
	entity2 = enums.Items.Annihilation_,
	own_key = "Item_Annihilation_",
	player_info = {
		[PlayerType.PLAYER_ISAAC] = "任务：#使用{{Collectible105}}D6重置13个道具III奖励：#{{Collectible105}}D6可以对空底座生效",
		[PlayerType.PLAYER_MAGDALENE] = "#拾取时+2{{EmptyHeart}}心之容器III任务：#一次性恢复或失去6格{{Heart}}红心III奖励：#3倍{{Heart}}红心恢复量",
		[PlayerType.PLAYER_CAIN] = "任务：#III奖励：#{{Luck}} +5幸运",
		[PlayerType.PLAYER_JUDAS] = "任务：#与{{DevilRoom}}恶魔交易并死亡III奖励：#以{{Player12}}犹大之影的形态复活",
		[PlayerType.PLAYER_BLUEBABY] = "此任务可重复进行III任务：#摧毁10个{{POOP}}便便III奖励：#!!! 在当前房间内无限制脱出便便",
		[PlayerType.PLAYER_EVE] = "此任务可重复进行III任务：#保持仅有半颗红心的状态连续完成10个房间III奖励：#",
		[PlayerType.PLAYER_SAMSON] = "任务：#不受任何伤害完成一整层III奖励：",
		[PlayerType.PLAYER_AZAZEL] = "此任务可重复进行III任务：#炸毁恶魔雕像，并战胜撒旦III奖励：#生成一个随机恶魔房道具",
		[PlayerType.PLAYER_LAZARUS] = "任务：#复活3次III奖励：复活后额外获得一颗魂心",
		[PlayerType.PLAYER_EDEN] = "#拾取时：生成一张{{Card78}}#此任务可重复进行III任务：#{{UltraSecretRoom}} 进入红隐藏III奖励：#生成3张{{Card78}}",
		[PlayerType.PLAYER_THELOST] = "任务：#使用{{Collectible609}}使10个道具消失III奖励：#失去{{Collectible313}}神圣斗篷后，随机恐惧/燃烧/减速/魅惑全场敌人20s",
		[PlayerType.PLAYER_LAZARUS2] = "任务：#复活3次III奖励：复活后额外获得一颗魂心",
		[PlayerType.PLAYER_BLACKJUDAS] = "此任务可重复进行III任务：#拾取2颗黑心III奖励：#+1攻击",
		[PlayerType.PLAYER_LILITH] = "任务：#持有10个以上的宝宝III奖励：你的攻击方式改为操纵宝宝纵队进行战斗",
		[PlayerType.PLAYER_KEEPER] = "#持有此道具也视为角色拥有{{Collectible416}}III任务：#持有99金币III奖励：#在每层的初始房间生成一个投资乞丐和至多3个商品",
		[PlayerType.PLAYER_APOLLYON] = "任务：#放下{{Collectible477}}III奖励：生成一张{{Card41}}#拾取{{Collectible477}}时自动使用一次{{Card41}}",
		[PlayerType.PLAYER_THEFORGOTTEN] = "任务：#切换灵魂与身体100次III奖励：身体变大5次",
		[PlayerType.PLAYER_THESOUL] = "任务：#切换灵魂与身体100次III奖励：灵魂变小5次",
		[PlayerType.PLAYER_BETHANY] = "任务：#积攒30格魂心充能III奖励：#失去的恶魔房概率时消耗5格魂心修复#死亡时消耗10格魂心复活",
		[PlayerType.PLAYER_JACOB] = "任务：#用你的炸弹击杀{{Player20}}III奖励：#以单独一人形态复活",
		[PlayerType.PLAYER_ESAU] = "任务：#用你的炸弹击杀{{Player19}}III奖励：#以单独一人形态复活",
		
		[PlayerType.PLAYER_ISAAC_B] = "任务：#持有3个或以上非剧情4级道具III奖励：#你的四级道具不再占据背包上限，但也无法取出",
		[PlayerType.PLAYER_MAGDALENE_B] = "任务：#受到超过100次来自敌人的伤害III奖励：#敌人的生命也会缓缓流失，敌人也能拾取红心回血",
		[PlayerType.PLAYER_CAIN_B] = "任务：连续4次合成相同道具III奖励：#可以正常拾取所有地上的道具",
		[PlayerType.PLAYER_JUDAS_B] = "任务：#连续切中20个目标III奖励：视为角色拥有{{Collectible"..enums.Items.Assassin_s_Eye.."}}",
		[PlayerType.PLAYER_BLUEBABY_B] = "任务：#过量拾取30个{{PoopPickup}}III奖励：靠近你掷出的{{PoopSpell1}}等可以将其收回",
		[PlayerType.PLAYER_EVE_B] = "任务：#献祭20个小史莱姆III奖励：#你可以献祭最弱小的小史莱姆来让所有史莱姆提升血上限并恢复满血",
		[PlayerType.PLAYER_SAMSON_B] = "任务：#暴怒状态下击杀100个敌人III奖励：#永久获得暴怒状态#受伤后暴怒状态立即消失，直到下个房间或是怒气条充满",
		[PlayerType.PLAYER_AZAZEL_B] = "持有此道具时，视为角色拥有{{Collectible420}}III任务：#使用{{Collectible420}}献祭50个敌人III奖励：{{Collectible420}}自动布置法阵伤害敌人",
		[PlayerType.PLAYER_LAZARUS_B] = "任务：#使用{{Collectible711}}30次III奖励：{{Collectible711}}只需要3充能",
		[PlayerType.PLAYER_EDEN_B] = "任务：#无伤超过5分钟III奖励：#50%概率抵消受到的伤害并生成一个环绕物",
		[PlayerType.PLAYER_THELOST_B] = "此任务可重复进行III任务：失去一层{{Collectible313}}III奖励：生成一个随机天使房道具",
		[PlayerType.PLAYER_LILITH_B] = "任务：III奖励：#",
		[PlayerType.PLAYER_KEEPER_B] = "持有此道具也视为角色拥有{{Collectible376}}III任务：#找到一个价格为99硬币或更高的商品III奖励：受伤后生成一个快速消失的硬币",
		[PlayerType.PLAYER_APOLLYON_B] = "任务：#持有10只飞蝗III奖励：#失去所有飞蝗，你的攻击方式彻底转化为飞蝗攻击",
		[PlayerType.PLAYER_THEFORGOTTEN_B] = "任务：",
		[PlayerType.PLAYER_BETHANY_B] = "任务：#持有10个道具魂火III奖励：#道具魂火坚硬程度提升3倍",
		[PlayerType.PLAYER_JACOB_B] = "任务：#使用哥哥击杀3个BossIII奖励：#你的攻击方式改为控制哥哥进行战斗",
		[PlayerType.PLAYER_LAZARUS2_B] = "任务：#使用{{Collectible711}}30次III奖励：{{Collectible711}}只需要3充能",
		[PlayerType.PLAYER_JACOB2_B] = "任务：#活下去III该任务没有奖励",
		[PlayerType.PLAYER_THESOUL_B] = "",
		
		[enums.Players.wq] = "",
		[enums.Players.Spwq] = "",
		[enums.Players.Tecro] = "",
		[enums.Players.Tecrorun] = "",
		[enums.Players.Anna] = "",
		[enums.Players.Zeistos] = "",
		[enums.Players.Marriano] = "",
	},
	ReloadInfo = {
		
	},
	missioninfo = {
		[0] = {},
	},
}

function item.reward(player)
	local idx = player:GetData().__Index
	save.elses[item.own_key.."Reward"] = save.elses[item.own_key.."Reward"] or {}
	save.elses[item.own_key.."Reward"][idx] = {}
end

function item.success(player)
	local idx = player:GetData().__Index
	save.elses[item.own_key.."Reward"] = save.elses[item.own_key.."Reward"] or {}
	return save.elses[item.own_key.."Reward"][idx]
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = 105,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
	end
	if auxi.has_have_coll(player,item.entity) and player:GetPlayerType() == 0 then
		local idx = player:GetData().__Index
		save.elses[item.own_key.."Reward"] = save.elses[item.own_key.."Reward"] or {}
		if item.success(player) then
			local tgs = auxi.getothers(5,100,0)
			for u,v in pairs(tgs) do 
				v:ToPickup():Morph(5,100,0)
				auxi.initialize_item(v)
			end
		else
			save.elses[item.own_key.."record"] = save.elses[item.own_key.."record"] or {}
			local tgs = auxi.getothers(5,100,nil,function(ent) if ent.SubType ~= 0 then return true end end)
			save.elses[item.own_key.."record"][idx] = (save.elses[item.own_key.."record"][idx] or 0) + (#tgs)
			if save.elses[item.own_key.."record"][idx] >= 15 then item.reward(player) end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_BASIC, params = nil,
Function = function(_,player,changetype,count)
	if auxi.has_have_coll(player,item.entity) and player:GetPlayerType() == 1 then
		if changetype == "rd_heart" then
			if item.success(player) then
				if count > 0 and (item.MaggyAdder or 0) < Game():GetFrameCount() then 
					player:AddHearts(count * 2) 
					item.MaggyAdder = Game():GetFrameCount() + 5
				end
			else if count >= 2 * 6 or count <= - 2 * 6 then item.reward(player)	end	end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player and auxi.has_have_coll(player,item.entity) and player:GetPlayerType() == 3 then
		if flag & DamageFlag.DAMAGE_DEVIL == DamageFlag.DAMAGE_DEVIL then
			local idx = player:GetData().__Index
			if player:IsDead() then item.reward(player) end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item.MaggyAdder = nil
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,colid,cnt,touched)
	if player:GetActiveItem(2) == 0 then player:SetPocketActiveItem(item.entity2,2,false) end
	if player:GetPlayerType() == 1 and touched == false then 
		player:AddMaxHearts(4,true)
		player:AddHearts(4)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_PLAYER_SHIFT, params = nil,
Function = function(_,player,tp)
	if auxi.has_have_coll(player,item.entity) then
		local idx = player:GetData().__Index
		save.elses[item.own_key.."record"] = save.elses[item.own_key.."record"] or {}
		save.elses[item.own_key.."Reward"] = save.elses[item.own_key.."Reward"] or {}
		save.elses[item.own_key.."record"][idx] = nil
		save.elses[item.own_key.."Reward"][idx] = nil
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_LOSE_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,nownum)
	local idx = player:GetData().__Index
	if player:GetActiveItem(2) == item.entity2 and nownum == cnt then player:RemoveCollectible(item.entity2) end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_LOSE_COLLECTIBLE, params = item.entity2,
Function = function(_,player,collid,cnt,nownum)
	if player:GetActiveItem(2) == 0 and auxi.has_have_coll(player,item.entity) then
		player:SetPocketActiveItem(item.entity2,2,false)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_SLOT_RENDER, params = "Active",
Function = function(_,player,tp,cid,slot)
	if auxi.has_have_coll(player,item.entity) and slot == 2 and cid ~= item.entity2 then
		local s = auxi.load_item(item.entity2)
		local pos = ui.PlayerActiveUIPos(player,slot,auxi.GetPlayerOrder(player),cid)
		s.Color = Color(1,1,1,slot_render_holder.get_alpha())
		s:Render(pos + Vector(0,16),Vector(0,0),Vector(0,0))
	end
end,
})

if EID then

EID:addDescriptionModifier("qing_item_sync"..tostring(item.entity), function(desc) return true end, function(desc)
	local id = desc.ObjType
	local vr = desc.ObjVariant
	local st = desc.ObjSubType
	if (id == 5 and vr == 100 and (st == item.entity2 or st == item.entity)) then
		local player = auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
		local info = item.player_info[player:GetPlayerType()]
		if info then
			if string.sub(info,1,1) ~= "#" then info = "III" .. info end
			local repl = "#{{Collectible"..tostring(item.entity).."}} "
			info = string.gsub(info, "#", repl)
			info = string.gsub(info, "III", "#")
			EID:appendToDescription(desc, info)			
		end
	end
	return desc
end)

end

return item
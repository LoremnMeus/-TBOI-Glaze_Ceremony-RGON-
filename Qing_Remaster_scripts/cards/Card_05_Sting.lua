local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Sting,
	own_key = "Thoth_cd5_Sti_",
	Sting_info = {
		{frame = 0,c = 1,},
		{frame = 5,c = 0,},
	},
	Trigger_info = {
		[1] = function(ent,cnt,rng,player,item)
			local room = Game():GetRoom()
			local cnt = rng:RandomInt(5)
			for i = 1,cnt do 
				local q = Isaac.Spawn(5,20,0,room:FindFreePickupSpawnPosition(ent.Position + Vector(0,40),10,true),Vector(0,0),nil)
			end
		end,
		[2] = function(ent,cnt,rng,player,item)
			local room = Game():GetRoom()
			local cnt = rng:RandomFloat()
			if cnt > 0.5 then
				local q = Isaac.Spawn(5,50,0,room:FindFreePickupSpawnPosition(ent.Position + Vector(0,40),10,true),Vector(0,0),nil)
			end
		end,
		[3] = function(ent,cnt,rng,player,item)
			local room = Game():GetRoom()
			local level = Game():GetLevel()
			level:SetStateFlag(LevelStateFlag.STATE_REDHEART_DAMAGED,false)
		end,
		[4] = function(ent,cnt,rng,player,item)
			local room = Game():GetRoom()
			local cnt = rng:RandomFloat()
			if cnt > 0.7 then 
				local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(ent.Position + Vector(0,40),10,true),Vector(0,0),nil)
			end
		end,
		[5] = function(ent,cnt,rng,player,item)
			local room = Game():GetRoom()
			for i = 1,3 do
				local q = Isaac.Spawn(5,360,0,room:FindFreePickupSpawnPosition(ent.Position + Vector(0,40),10,true),Vector(0,0),nil)
			end
		end,
		[6] = function(ent,cnt,rng,player,item)
			local cnt = rng:RandomFloat()
			if cnt > 0.5 then player:UseCard(31,1|(1<<8)) end
		end,
	},
	sting_desc = {
		["zh_cn"] = {
			["basic"] = "简易献祭阵",
			[0] = "下次献祭：生成0-4枚{{Coin}}硬币",
			[1] = "下次献祭：50%概率生成一个{{Chest}}箱子",
			[2] = "下次献祭：修复本层{{DevilRoom}}恶魔房概率",
			[3] = "下次献祭：30%概率生成一个随机道具",
			[4] = "下次献祭：生成3个红箱子",
			[5] = "下次献祭：50%概率传送到{{DevilRoom}}恶魔房",
		},
		["en_us"] = {
			["basic"] = "Sacrifice Formation",
			[0] = "Next time：0-4 {{Coin}} coins",
			[1] = "Next time：50% chance to spawn a {{Chest}} chest",
			[2] = "Next time：Repairing the chance of Devil Room",
			[3] = "Next time：30% chance to spawn a random item",
			[4] = "Next time：spawn 3 red chest",
			[5] = "Next time：50% chance to teleport to Devil Room",
		},
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local q = Isaac.Spawn(1000,enums.Entities.S_Pentagram,0,room:FindFreePickupSpawnPosition(player.Position + Vector(0,-40),10,true),Vector(0,0),nil):ToEffect()
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then 
			q:GetData()[item.own_key.."effect"] = q:GetData()[item.own_key.."effect"] or {}
			q:GetData()[item.own_key.."effect"].double = true
		end
	end
end,
})

function item.trigger_counter(ent,cnt,player)
	local info = item.Trigger_info[cnt]
	local rng = ent:GetDropRNG()
	auxi.check_if_any(info,ent,cnt,rng,player,item)
	if ent:GetData()[item.own_key.."effect"].double and rng:RandomFloat() < 0.3 then 
		local q = Isaac.Spawn(5,10,3,Game():GetRoom():FindFreePickupSpawnPosition(ent.Position + Vector(0,40),10,true),Vector(0,0),nil)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = enums.Entities.S_Pentagram,
Function = function(_,ent)
	local language = EID.UserConfig.Language
	if language == "auto" then language = "zh_cn" end
	local info = item.sting_desc[language].basic
	ent:GetData().EID_Description = {Name = info.Name,Description = info.Description,}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.S_Pentagram,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local anim = s:GetAnimation()
	d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
	ent.Velocity = Vector(0,0)
	if s:IsFinished("Appear") then s:Play("Idle",true) end
	ent.DepthOffset = -40
	ent.SortingLayer = 0
	if anim == "Idle" then
		local room = Game():GetRoom()
		local idx = room:GetGridIndex(ent.Position)
		room:SetGridPath(idx,900)
		local succ = false
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			if room:GetGridIndex(player.Position) == idx and player:GetDamageCooldown() == 0 then
				player:TakeDamage(1,DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_RED_HEARTS,EntityRef(player),30)
				d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
				item.trigger_counter(ent,d[item.own_key.."effect"].counter,player)
				succ = true
			end
		end
		if succ then d.EID_Description = nil end
	end
	d[item.own_key.."effect"].rc = (d[item.own_key.."effect"].rc or 0) * 0.9 + (d[item.own_key.."effect"].counter or 0) * 0.1
	local info = auxi.check_lerp(d[item.own_key.."effect"].rc,item.Sting_info)
	s.Color = Color(1,info.c,info.c,1,(1 - info.c) * 0.5,0,0)
	if anim == "Idle" and d[item.own_key.."effect"].rc >= 5 then s:Play("DisAppear",true) end
	if anim == "DisAppear" and s:IsFinished(anim) then ent:Remove() end
end,
})

if EID then
	EID:addDescriptionModifier("qing_item_sync_cd"..tostring(item.entity), function(desc) if desc.ObjType == 1000 and desc.ObjVariant == enums.Entities.S_Pentagram and desc.Entity then return true end end, function(desc)
		local data = desc.Entity:GetData()[item.own_key.."effect"]
		if data then
			local language = EID.UserConfig.Language
			if language == "auto" then language = "zh_cn" end
			local desc = (item.sting_desc[language] or {})[(data.counter or 0)] 
			local info = (item.sting_desc[language] or {}).basic
			return {Name = info or "",Description = desc or "",}
		end
		return desc
	end)
end

return item
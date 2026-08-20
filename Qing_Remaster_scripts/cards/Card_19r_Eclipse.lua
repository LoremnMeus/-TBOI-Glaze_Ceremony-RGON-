local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Eclipse_r,
	own_key = "Thoth_cd19r_Ecl_",
	posinfo = {
		{frame = 0,delta = 0.5,rate = 0.03,r2 = 0.3,},
		{frame = 10 * 30,delta = 0.75,rate = 0.1,r2 = 0.4,},
		{frame = 60 * 30,delta = 1,rate = 0.3,r2 = 0.6,},
		{frame = 3 * 60 * 30,delta = 2,rate = 0.8,r2 = 1,},
	},
}

local Eclipse_effect = Sprite()
Eclipse_effect:Load("gfx/cards/cd19r_Ecl_sun.anm2",true)
Eclipse_effect:Play("Idle",true)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	local scz = auxi.GetScreenSize()
	if save.elses[item.own_key.."effect"] then
		Eclipse_effect.Color = auxi.AddColor(Eclipse_effect.Color,Color(1,1,1,1,0,0,0),0.9,0.1)
	else
		Eclipse_effect.Color = auxi.AddColor(Eclipse_effect.Color,Color(1,1,1,0,0,0,0),0.9,0.1)
	end
	if Eclipse_effect.Color.A > 0.05 then
		local info = auxi.check_lerp(save.elses[item.own_key.."InitCounter"] or 0,item.posinfo)
		Eclipse_effect:Render(auxi.GetScreenCenter() * info.delta,Vector(0,0),Vector(0,0))
	else save.elses[item.own_key.."InitCounter"] = nil end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if save.elses[item.own_key.."effect"] then
		save.elses[item.own_key.."effect"].Counter = save.elses[item.own_key.."effect"].Counter - 1
		save.elses[item.own_key.."InitCounter"] = (save.elses[item.own_key.."InitCounter"] or 0) + 1
		local player = Game():GetPlayer(0)
		local rng = player:GetCardRNG(item.entity)
		if Game():GetFrameCount() % 5 == 3 then
			local rate = auxi.check_lerp(save.elses[item.own_key.."InitCounter"],item.posinfo).rate
			if rng:RandomFloat() < rate then
				local tg = auxi.random_in_table(auxi.getenemies(nil,function(ent) if auxi.check_all_exists(ent:GetData()[item.own_key.."effect"]) ~= true then return true end end),rng)
				local pos = Game():GetRoom():GetRandomPosition(0)
				if tg then pos = tg.Position end
				local q = Isaac.Spawn(1000,19,2,pos,Vector(0,0),player):ToEffect()
				q.Parent = player
				q.CollisionDamage = player.Damage * 3
				if save.elses[item.own_key.."Tarot"] then q.CollisionDamage = q.CollisionDamage * 2 end
				local s = q:GetSprite()
				s.Color = Color(1,0.3,0.3,1,0,0,0)
				local d = q:GetData()
				d[item.own_key.."effect"] = {tg = tg,}
				if tg then tg:GetData()[item.own_key.."effect"] = q end
			end
			--print(ui.myRenderPositionToWorld(Vector(0,0)))
		end
		local q = Isaac.Spawn(1000,66,0,Vector(ui.myRenderPositionToWorld(ui.GetScreenSize() * rng:RandomFloat()).X,rng:RandomFloat() * 60 - ui.myRenderPositionToWorld(Vector(0,0)).Y),Vector(0,10) + auxi.RoundVector(rng,5),nil)
		if Game():GetFrameCount() % 10 == 3 then
			local info = auxi.check_lerp(save.elses[item.own_key.."InitCounter"],item.posinfo)
			if rng:RandomFloat() < info.r2 * info.rate then 
				local q = Isaac.Spawn(1000,19,2,player.Position,Vector(0,0),nil)
				local s = q:GetSprite()
				s.Color = Color(1,0.5,0,1,0,0,0)
				Game():MakeShockwave(player.Position,0.035,0.025,10) 
			end
		end
		if save.elses[item.own_key.."effect"].Counter <= 0 then save.elses[item.own_key.."effect"] = nil end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 19,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if auxi.check_all_exists(d[item.own_key.."effect"].tg) then ent.Position = d[item.own_key.."effect"].tg.Position end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then save.elses[item.own_key.."Tarot"] = true
		else save.elses[item.own_key.."Tarot"] = nil end
		save.elses[item.own_key.."effect"] = {Counter = 3 * 60 * 30,}
		save.elses[item.own_key.."InitCounter"] = save.elses[item.own_key.."InitCounter"] or 0
	end
end,
})


return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Empress,
	own_key = "Thoth_cd3_Emp_",
	Empress_size_info = {
		[1] = {frame = 0,scale = Vector(0,0),},
		[2] = {frame = 5,scale = Vector(0.5,0.5),},
		[3] = {frame = 15,scale = Vector(0,0),},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = nil
	end
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
		local mul = 0.1
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then mul = 0.2 end
		local n_enemy = auxi.getenemies(Isaac.GetRoomEntities(),function(ent) if ent:IsBoss() == false then return true end end)
		local targ = auxi.getenemies(Isaac.GetRoomEntities(),function(ent) if ent:IsBoss() then return true end end)[1]
		if #n_enemy > 0 or targ then
			if targ == nil then 
				targ = n_enemy[1]
				for i = 2,#n_enemy do
					local v = n_enemy[i]
					if v.HitPoints > targ.HitPoints then targ = v end
					if v:GetData()[item.own_key.."effect2"] then targ = v break end
				end
			end
			targ = targ:ToNPC()
			local d2 = targ:GetData()
			if d2[item.own_key.."effect2"] ~= true then
				targ:MakeChampion(-1,25,true)
				targ.HitPoints = targ.MaxHitPoints
				d2[item.own_key.."effect2"] = true
			end
			for u,v in pairs(n_enemy) do
				if v:GetData()[item.own_key.."effect2"] then
				else
					local delta = v.HitPoints - v.MaxHitPoints * mul
					if delta > 0 then
						local rnd = math.random(3) + 1
						for i = 1,rnd do
							local q = auxi.fire_nil(v.Position,auxi.MakeVector(math.random(360)) * (math.random(1000)/1000 * 15 + 10),{cooldown = 600,})
							local s = q:GetSprite()
							s:Load("gfx/cards/cd03_emp_tear.anm2",true)
							s:Play("RegularTear6",true)
							s.Offset = Vector(0,-20)
							local d3 = q:GetData()
							d3.nil_mode = "card_03_empress"
							d3[item.own_key.."effect"] = true
							d3[item.own_key.."value"] = delta/rnd
							d3[item.own_key.."target"] = targ
						end
						
						v.HitPoints = v.HitPoints - delta
					end
					v:AddEntityFlags(EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_CHARM)
				end
			end
		end
	end
end,
})

Nil_holder.register("card_03_empress", {
	detect = function(d) return d[item.own_key.."effect"] end,
	update = function(ent, d, s)
		local targ = d[item.own_key.."target"]
		if auxi.check_all_exists(targ) then
			if (targ.Position - ent.Position):Length() < 15 then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_SOUL_PICKUP,0.3,1,false,0,2)
				targ.MaxHitPoints = targ.MaxHitPoints + (d[item.own_key.."value"] or 10) * 2
				targ.HitPoints = targ.HitPoints + (d[item.own_key.."value"] or 10) * 2 + targ.MaxHitPoints * 0.1
				targ:SetColor(Color(1,0.6,0.6,1,0.5,0.3,0.3),15,50,true,false)
				local s2 = targ:GetSprite()
				local scale = s2.Scale
				for i = 1,15 do
					delay_buffer.addeffe(function(params)
						local scaleinfo = auxi.check_lerp(i,item.Empress_size_info).scale
						s2.Scale = scale + scaleinfo
					end,{},i)
				end
				ent:Remove()
				return
			elseif (targ.Position - ent.Position):Length() < 50 then
				ent.Velocity = (targ.Position - ent.Position):Normalized() * math.max(math.max(4,targ.Velocity:Length() * 1.2),ent.Velocity:Length() * 0.98)
			else
				ent.Velocity = (ent.Velocity:Normalized() * math.max(0,1 - ent.FrameCount/50) + (targ.Position - ent.Position):Normalized() * math.min(1,ent.FrameCount/50)):Normalized() * (ent.Velocity:Length() + 1.5) * 0.9
			end
		else
			s.Color = auxi.AddColor(s.Color,Color(0,0,0,0),0.95,0.05)
			if s.Color.A < 0.1 then ent:Remove() return end
		end
		if auxi.check_all_exists(d[item.own_key.."tail"]) then
			d[item.own_key.."tail"].Position = ent.Position
			d[item.own_key.."tail"]:GetSprite().Color = Color(1,0.6,0.6,s.Color.A,0.5,0.3,0.3)
		else
			local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL, 0, ent.Position, Vector(0,0), ent):ToEffect()
			d[item.own_key.."tail"] = q
			q.MinRadius = 0.2
			q.MaxRadius = 0.15
			q.SpriteScale = Vector(1,1)
			q.Parent = ent
			q:GetSprite().Color = Color(1,0.6,0.6,s.Color.A,0.5,0.3,0.3)
		end
	end,
})

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local danger_data = require("Qing_Remaster_scripts.others.Danger_Data")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Eclipse,
	own_key = "Thoth_cd19_Ecl_",
	Port_info = {
		[1] = {
			{frame = 0,C = 255,},
			{frame = 2,C = 281,},
			{frame = 4,C = 306,},
			{frame = 6,C = 319,},
			{frame = 8,C = 306,},
			{frame = 10,C = 281,},
			{frame = 12,C = 255,},
			{frame = 14,C = 230,},
			{frame = 16,C = 204,},
			{frame = 18,C = 191,},
			{frame = 20,C = 204,},
			{frame = 22,C = 230,},
			{frame = 24,C = 255,},
		},
		[2] = {
			{frame = 0,C = 148,},
			{frame = 2,C = 167,},
			{frame = 4,C = 185,},
			{frame = 6,C = 204,},
			{frame = 8,C = 222,},
			{frame = 10,C = 231,},
			{frame = 12,C = 222,},
			{frame = 14,C = 204,},
			{frame = 16,C = 185,},
			{frame = 18,C = 167,},
			{frame = 20,C = 148,},
			{frame = 22,C = 139,},
			{frame = 24,C = 148,},
		},
		[3] = {
			{frame = 0,C = 92,},
			{frame = 2,C = 86,},
			{frame = 4,C = 92,},
			{frame = 6,C = 104,},
			{frame = 8,C = 115,},
			{frame = 10,C = 127,},
			{frame = 12,C = 138,},
			{frame = 14,C = 144,},
			{frame = 16,C = 138,},
			{frame = 18,C = 127,},
			{frame = 20,C = 115,},
			{frame = 22,C = 104,},
			{frame = 24,C = 92,},
		},
		[4] = {
			{frame = 0,C = 45,},
			{frame = 2,C = 41,},
			{frame = 4,C = 36,},
			{frame = 6,C = 34,},
			{frame = 8,C = 36,},
			{frame = 10,C = 41,},
			{frame = 12,C = 45,},
			{frame = 14,C = 50,},
			{frame = 16,C = 54,},
			{frame = 18,C = 56,},
			{frame = 20,C = 54,},
			{frame = 22,C = 50,},
			{frame = 24,C = 45,},
		},
	},
	Colorinfo = {
		{frame = 0,R = 1,G = 0.5,B = 0,A = 1,RO = 0.5,GO = 0,BO = 0,},
		{frame = 4,R = 1,G = 0,B = -1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
	},
	Eclipse_falling_offset = {
		{frame = 0,offset = -10,},
		{frame = 20,offset = 0,},
		{frame = 40,offset = 10,},
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
		local q = Isaac.Spawn(1000,180,0,player.Position,Vector(0,0),nil):ToEffect()
		q:GetData()[item.own_key.."effect"] = {limit = 15 * 30,}
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then 
			q:GetData()[item.own_key.."effect"].limit = 30 * 30
		end
		local s = q:GetSprite()
		s:Load("gfx/player/anna/_anna_port.anm2",true)
		s:Play("Appear",true)
		q.DepthOffset = -40
	end
end,
})

function item.Catch(ent)
	local d = ent:GetData()
	d[item.own_key.."Visible"] = d[item.own_key.."Visible"] or Attribute_holder.try_hold_attribute(ent,"Visible",false)
	d[item.own_key.."GridCollisionClass"] = d[item.own_key.."GridCollisionClass"] or Attribute_holder.try_hold_attribute(ent,"GridCollisionClass",EntityGridCollisionClass.GRIDCOLL_NONE)
	d[item.own_key.."EntityCollisionClass"] = d[item.own_key.."EntityCollisionClass"] or Attribute_holder.try_hold_attribute(ent,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
end

function item.Release(ent)
	local d = ent:GetData()
	if d[item.own_key.."Visible"] then Attribute_holder.try_rewind_attribute(ent,"Visible",d[item.own_key.."Visible"]) d[item.own_key.."Visible"] = nil end
	if d[item.own_key.."GridCollisionClass"] then Attribute_holder.try_rewind_attribute(ent,"GridCollisionClass",d[item.own_key.."GridCollisionClass"]) d[item.own_key.."GridCollisionClass"] = nil end
	if d[item.own_key.."EntityCollisionClass"] then Attribute_holder.try_rewind_attribute(ent,"EntityCollisionClass",d[item.own_key.."EntityCollisionClass"]) d[item.own_key.."EntityCollisionClass"] = nil end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 180,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local s = ent:GetSprite()
		local anim = s:GetAnimation()
		local fr = s:GetFrame()
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		if anim == "Opened" and (d[item.own_key.."effect"].counter or 0) > (d[item.own_key.."effect"].limit or 10) then s:Play("Disappear",true) end
		if anim == "Opened" then
			local n_entity = Isaac.GetRoomEntities() 
			for u,v in pairs(n_entity) do
				if auxi.isenemies(v) and (v.Position - ent.Position):Length() < 30 and not v:GetData()[item.own_key.."effect"] then
					local q = auxi.fire_nil(v.Position,auxi.RoundVector(nil,5,{leg2 = 2.5,}),{cooldown = 999,})
					local d2 = q:GetData()
					d2.nil_mode = "card_19_eclipse"
					d2[item.own_key.."effect"] = {Renderer = v,counter = auxi.choose(5,6,7,8),}
					item.Catch(v)
					v:GetData()[item.own_key.."effect"] = {tg = q,}
				end
			end
		end
		if s:IsFinished("Appear") then s:Play("Opened",true) end
		if s:IsFinished("Disappear") then ent:Remove() return end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d[item.own_key.."effect"] and auxi.check_all_exists(d[item.own_key.."effect"].tg) ~= true then 
		item.Release(ent)
		d[item.own_key.."effect"] = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = 180,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] and (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		local s = ent:GetSprite()
		local anim = s:GetAnimation()
		local fr = s:GetFrame()
		local rpos = Isaac.WorldToScreen(ent.Position + ent.PositionOffset)
		s.Color = Color(1,0.5,0,1)
		if anim == "Opened" then
			if d[item.own_key.."Vx"] == nil then 
				d[item.own_key.."Vx"] = Sprite()
				d[item.own_key.."Vx"]:Load("gfx/1000.180_rift.anm2",true)
				d[item.own_key.."Vx"]:Play("Vortex",true)
				d[item.own_key.."Vx"].Color = Color(1,0.5,0,1,1,0.5,0)
			end
			d[item.own_key.."Vx"]:SetFrame("Vortex",(d[item.own_key.."effect"].counter or 0) % 36)
			d[item.own_key.."Vx"]:Render(rpos,Vector(0,0),Vector(0,0))
			for i = 5,1,-1 do 
				local anim = "R"..tostring(i)
				d[item.own_key..anim] = d[item.own_key..anim] or auxi.copy_sprite(s,d[item.own_key..anim])
				local info = auxi.check_lerp(i,item.Colorinfo)
				local st = d[item.own_key..anim]
				st:SetFrame(anim,fr)
				if item.Port_info[i] then 
					local pinfo = auxi.check_lerp(fr,item.Port_info[i])
					local c = pinfo.C/255
					st.Color = auxi.MulColor(Color(c,c,c,1),auxi.table2color(info))
				else
					st.Color = auxi.table2color(info)
				end
				st:Render(rpos,Vector(0,0),Vector(0,0))
			end
			
		end
	end
end,
})

Nil_holder.register("card_19_eclipse", {
	detect = function(d) local e = d[item.own_key.."effect"] return e and e.Renderer end,
	update = function(ent, d, s)
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		if auxi.check_all_exists(d[item.own_key.."effect"].Renderer) then
			local tg = d[item.own_key.."effect"].Renderer
			local dy = ent.PositionOffset.Y
			ent.PositionOffset = Vector(ent.PositionOffset.X,math.min(0,dy + auxi.check_lerp(d[item.own_key.."effect"].counter,item.Eclipse_falling_offset).offset))
			tg.Position = ent.Position
			auxi.fix_position(tg)
			if ent.PositionOffset.Y >= 0 and d[item.own_key.."effect"].counter > 5 then
				item.Release(tg)
				tg:TakeDamage(15,0,EntityRef(ent),0)
				Isaac.Spawn(1000,17,1,ent.Position,Vector(0,0),nil):ToEffect()
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEAT_JUMPS,1,1,false,0,2)
				ent:Remove()
				return
			end
			local dinfo = danger_data.check_data(tg) or {}
			local deltaoffset = Vector(0,-10)
			if (dinfo.i2 or "") == "flyable" then deltaoffset = Vector(0,-20) end
			if auxi.check_all_exists(d[item.own_key.."tail"]) then
				d[item.own_key.."tail"].Position = ent.Position + ent.PositionOffset + tg.PositionOffset + deltaoffset
				d[item.own_key.."tail"]:GetSprite().Color = auxi.AddColor(d[item.own_key.."tail"]:GetSprite().Color,Color(1,0.5,0,1,0,0,0),0.5,0.5)
			else
				local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL, 0, ent.Position + ent.PositionOffset + deltaoffset, Vector(0,0), ent):ToEffect()
				local s2 = q:GetSprite()
				s2:Play("Idle",true)
				s2.Color = Color(1,0.5,0,0,0,0,0)
				d[item.own_key.."tail"] = q
				q.MinRadius = 0.1
				q.MaxRadius = 0.1
				q.SpriteScale = Vector(1,1)
				q.Parent = ent
			end
		elseif d[item.own_key.."effect"].Renderer then item.Release(d[item.own_key.."effect"].Renderer) ent:Remove() return end
	end,
	render = function(ent, d, s, player, offset)
		if auxi.check_all_exists(d[item.own_key.."effect"].Renderer) then
			d[item.own_key.."effect"].Renderer:GetSprite():Render(Isaac.WorldToScreen(ent.Position + ent.PositionOffset),Vector(0,0),Vector(0,0))
		end
	end,
})

return item
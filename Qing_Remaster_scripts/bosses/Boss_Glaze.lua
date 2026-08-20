local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local AI = require("Qing_Remaster_scripts.bosses.Boss_All")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local Color_holder = require("Qing_Remaster_scripts.others.Color_cross_holder")
local CompletionMarks = require("Qing_Remaster_scripts.core.completion_marks_manager")

local item = {
	ToCall = {},
	entity = enums.Enemies.Prince_Glaze,
	own_key = "Boss_Glaze_",
	Swapper = {
		["Appear"] = "Idle",
	},
	AnimInfo = {
		["Appear"] = {
			{frame = 0,offset = -300,},
			{frame = 5,offset = -150,},
			{frame = 10,offset = -85,},
			{frame = 15,offset = -38,},
			{frame = 18,offset = -12,},
			{frame = 21,offset = -6,},
			{frame = 24,offset = -3,},
			{frame = 27,offset = 0,},
			total = 27,
		},
		["Idle"] = {
			{frame = 0,offset = 0,},
			{frame = 2,offset = 5,},
			{frame = 4,offset = 5,},
			{frame = 9,offset = 2,},
			{frame = 10,offset = -3,},
			{frame = 11,offset = -8,},
			{frame = 13,offset = -12,},
			{frame = 21,offset = -12,},
			{frame = 29,offset = 0,},
			total = 29,
		},
		["Attack1"] = {
			{frame = 0,offset = 0,},
			{frame = 2,offset = 5,},
			{frame = 4,offset = 5,},
			{frame = 9,offset = 2,},
			{frame = 10,offset = -3,},
			{frame = 11,offset = -8,},
			{frame = 13,offset = -12,},
			{frame = 21,offset = -12,},
			{frame = 41,offset = 0,},
			total = 41,
		},
		["Attack2"] = {
			{frame = 0,offset = 0,},
			{frame = 2,offset = 5,},
			{frame = 4,offset = 0,},
			{frame = 9,offset = -5,},
			{frame = 13,offset = -7,},
			{frame = 21,offset = -12,},
			{frame = 29,offset = -11,},
			{frame = 34,offset = 5,},
			{frame = 39,offset = 0,},
			{frame = 41,offset = 0,},
			total = 41,
		},
	},
	Allow_Offset = {
		["Attack2"] = {},
	},
	AttackInfo = {
		["Attack1"] = {},
	},
	word_list = {
		zh = {
			[1] = {
				{
					"琉璃王子：",
					{word = "光明..",colorful = 0,doublerender = Vector(1,-1),},
				},
			},
		},
		en = {

		},
	},
}
item.AnimInfo["Idle_Speaking"] = item.AnimInfo["Idle"] item.AnimInfo["Idle_Shake_Head"] = item.AnimInfo["Idle"]

function item.start(ent)
	local music = MusicManager()
	if (music:GetCurrentMusicID() ~= enums.Music.Light_and_Dark) then
		music:Play(enums.Music.Light_and_Dark,0)
		music:UpdateVolume()
	end
	local tgs = auxi.getothers(996,item.entity)
	if #tgs == 0 and auxi.check_all_exists(ent) ~= true then 
		ent = Isaac.Spawn(996,item.entity,0,Game():GetRoom():GetCenterPos(),Vector(0,0),nil)
	else
		for i = 1,#tgs do tgs[i]:Remove() end
	end
	return ent
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local anim = s:GetAnimation()
		local frame = s:GetFrame()
		
		d[item.own_key.."Render"] = {}
		if d[AI.own_key.."Move"] == nil then AI.move2pos(ent,Vector(320,240),15) end
		Color_holder.try_add_edge_color(ent,Color(0,0,0,0),{cnt = 0,work = function(ent,tg,rpos)
			local d = tg:GetData() if d[item.own_key.."WingSprite"] == nil then local s = Sprite() s:Load("gfx/boss/Glaze/Prince_Glaze.anm2",true) s:Play("Wing",true) d[item.own_key.."WingSprite"] = s end
			local info = auxi.check_lerp(s:GetFrame(),item.AnimInfo[s:GetAnimation()] or {{frame = 0,offset = 0,},})
			local s2 = d[item.own_key.."WingSprite"] s2:Render(rpos + Vector(0,info.offset + 3),Vector(0,0),Vector(0,0)) 
			if d[item.own_key.."Render"] and d[item.own_key.."Render"].Wing == nil then s2:Update() d[item.own_key.."Render"].Wing = true end
		end,})
		local info = auxi.check_lerp(s:GetFrame(),item.AnimInfo[s:GetAnimation()] or {{frame = 0,offset = 0,},})
		if item.Allow_Offset[anim] then s.Offset = Vector(0,info.offset) else s.Offset = Vector(0,0) end
		AI.Control_Move(ent)
		if s:IsFinished(anim) then
			local tg = auxi.check_if_any(item.Swapper[anim],ent) or "Idle"
			if ___QING___.Attack1 then ___QING___.Attack1 = nil tg = "Attack1" end
			if ___QING___.Attack2 then ___QING___.Attack2 = nil tg = "Attack2" end
			s:Play(tg,true)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = 996,
Function = function(_,ent,offset)
	if ent.Variant == item.entity then
		local d = ent:GetData()
		local s = ent:GetSprite()
		if d[item.own_key.."CrownSprite"] == nil then local s = Sprite() s:Load("gfx/boss/Glaze/Prince_Glaze.anm2",true) s:Play("Crown",true) s.Rotation = -15 d[item.own_key.."CrownSprite"] = s end
		local info = auxi.check_lerp(s:GetFrame(),item.AnimInfo[s:GetAnimation()] or {{frame = 0,offset = 0,},})
		local rpos = Isaac.WorldToScreen(ent.Position + ent.PositionOffset)
		local s2 = d[item.own_key.."CrownSprite"] s2:Render(rpos + Vector(-6,info.offset - 26),Vector(0,0),Vector(0,0)) 
		if d[item.own_key.."Render"] and d[item.own_key.."Render"].Crown == nil then s2:Update() d[item.own_key.."Render"].Crown = true end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
		item.start(ent)
		ent.PositionOffset = Vector(0,-25)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		CompletionMarks.complete_extra_all_players("boss.glaze")
	end
end,
})

return item

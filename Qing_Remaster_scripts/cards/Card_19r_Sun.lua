local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local card_01_wizard = require("Qing_Remaster_scripts.cards.Card_01_Wizard")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Sun_r,
	own_key = "Thoth_cd19r_Sun_",
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
		{frame = 0 * 18,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 18,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 18,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 18,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 18,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 18,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		
		{frame = 6 * 18,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 18,
	},
	Offset = {
		[0] = -6 * 2,
		[5] = -6 * 6,
	}
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
	end
end,
})

function item.spawn_a_ranbow_port(pos,rng,params)
	params = params or {}
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local dimen = auxi.GetDimension()
	local tbl,tbl2,tbl3 = {},{},{}
	for i = 1, rooms.Size do
		local targ = rooms:Get(i - 1)
		if targ and dimen == auxi.GetDimension(targ) then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex)
			if desc then
				local tp = desc.Data.Type
				if tp ~= 1 then 
					if params.focus then
						if desc.VisitedCount ~= 0 then 
							if desc.Clear ~= true then table.insert(tbl2,#tbl2 + 1,targ.SafeGridIndex) 
							else table.insert(tbl3,#tbl3 + 1,targ.SafeGridIndex) end
						else table.insert(tbl,#tbl + 1,targ.SafeGridIndex) 	end
					else table.insert(tbl,#tbl + 1,targ.SafeGridIndex) end
				end
			end
		end
	end
	if #tbl == 0 then tbl = tbl2 end
	if #tbl == 0 then tbl = tbl3 end
	local ret = auxi.random_in_table(tbl,rng)
	local p = {info = {id = -1,gidx = 84,tp = 118,},}
	if ret then p = {info = {id = -1,gidx = ret,tp = 118,},} end
	local q = card_01_wizard.spawn_a_fool_port(pos,p)
	q:GetData()[item.own_key.."effect"] = true
	local s = q:GetSprite()
	s:Load("gfx/player/anna/_anna_port.anm2",true)
	s:Play("Appear",true)
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local double = false
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then double = true end
		local q = item.spawn_a_ranbow_port(room:FindFreePickupSpawnPosition(player.Position,10,true),rng,{focus = double,})
		save.elses[item.own_key.."record"] = save.elses[item.own_key.."record"] or {}
		local gdx = auxi.get_acceptible_index()
		save.elses[item.own_key.."record"][gdx] = save.elses[item.own_key.."record"][gdx] or {}
		table.insert(save.elses[item.own_key.."record"][gdx],#save.elses[item.own_key.."record"][gdx] + 1,{pos = auxi.Vector2Table(q.Position),double = double,})
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."record"] = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local gdx = auxi.get_acceptible_index()
	save.elses[item.own_key.."record"] = save.elses[item.own_key.."record"] or {}
	local rng = Game():GetPlayer(0):GetCardRNG(item.entity)
	for u,v in pairs(save.elses[item.own_key.."record"][gdx] or {}) do 
		local pos = auxi.ProtectVector(v.pos)
		item.spawn_a_ranbow_port(pos,rng,{focus = v.double,})
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = 161,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] and (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		local s = ent:GetSprite()
		local anim = s:GetAnimation()
		local fr = s:GetFrame()
		local rpos = Isaac.WorldToScreen(ent.Position + ent.PositionOffset)
		local info = auxi.check_lerp((ent.FrameCount + item.Offset[0]) % item.Colorinfo.total,item.Colorinfo)
		s.Color = auxi.table2color(info)
		if anim == "Opened" then
			for i = 5,1,-1 do 
				local anim = "R"..tostring(i)
				local frame = i * 6 + ent.FrameCount + (item.Offset[i] or 0)
				d[item.own_key..anim] = d[item.own_key..anim] or auxi.copy_sprite(s,d[item.own_key..anim])
				local st = d[item.own_key..anim]
				st:SetFrame(anim,fr)
				local info = auxi.check_lerp(frame % item.Colorinfo.total,item.Colorinfo)
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

return item
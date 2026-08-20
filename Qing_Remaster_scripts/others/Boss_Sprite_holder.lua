local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Color_holder = require("Qing_Remaster_scripts.others.Color_cross_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	ToCall = {},
	own_key = "Boss_Sprite_holder_",
	display_info = {
		["Qing"] = {unique_name = "Qing",Background = "gfx/ui/boss/Background.png",Portrait = "gfx/ui/boss/WQingPortrait2.png",name = "gfx/ui/boss/bossname_qing.png",pos = Vector(0,-100),dpos = Vector(1.5,1),anim = "Boss",},
		["Glaze"] = {unique_name = "Glaze",Background = "gfx/ui/boss/Background_glaze.png",Portrait = "gfx/ui/boss/portrait_Prince_glaze.png",name = "gfx/ui/boss/bossname_glaze.png",pos = Vector(0,0),dpos = Vector(1.5,1),anim = "Boss2",},
	},
	max_counter = 35,
	screen_display_info = {
		{frame = 0,val = 0,},
		{frame = 10,val = 0.75,},
		{frame = 15,val = 1,},
	},
	sprite_linker = nil,
	alpha_info = {
		[0] = 1,
		[1] = 0.3,
		[2] = 0.2,
		[3] = 0.1,
	},
	session_serial = 0,
	session = nil,
}
--用于绘制Boss对战大图

function item.control_boss_screen(ent,info)
	info = info or {} 
	local d = ent:GetData() if d[item.own_key.."finished"] then return end
	if ent.Type == 996 and ent.Variant == enums.Enemies.Boss_Qing then info = item.display_info["Qing"] end
	if ent.Type == 996 and ent.Variant == enums.Enemies.Prince_Glaze then info = item.display_info["Glaze"] end
	if d[item.own_key.."effect"] == nil then
		if item.try_start_screen(ent,info) then d[item.own_key.."effect"] = true end
	else 
		item.screen_update(ent,info) 
	end
end

local function finish_session(expected_id, remove_linker)
	local session = item.session
	if not session or (expected_id ~= nil and session.id ~= expected_id) then return false end
	item.session = nil
	if item.on_sprite == session.boss then item.on_sprite = nil end
	if auxi.check_for_the_same(item.sprite_linker, session.linker) then item.sprite_linker = nil end
	auxi.time_free(session.stop_key)
	if remove_linker and auxi.check_all_exists(session.linker) then session.linker:Remove() end
	if session.boss then
		local ok, d = pcall(function() return session.boss:GetData() end)
		if ok and d and auxi.check_for_the_same(d[item.own_key.."linker"], session.linker) then d[item.own_key.."linker"] = nil end
	end
	return true
end

function item.try_start_screen(ent,info)
	info = info or {} local col = Color(0,0,0,0)
	if item.session then
		if auxi.check_for_the_same(item.session.boss, ent) then return true end
		return false -- 另一场演出结束后，本 Boss 的 update 会再次申请。
	end
	item.session_serial = item.session_serial + 1
	local session_id = item.session_serial
	local stop_key = item.own_key..(info.unique_name or "").."_"..tostring(session_id)
	auxi.time_stop(stop_key)
	item.on_sprite = ent
	local d = ent:GetData()
	if auxi.check_all_exists(d[item.own_key.."linker"]) ~= true then 
		local q = auxi.fire_nil(ent.Position,Vector(0,0),{cooldown = 999999,}) 
		if not q then auxi.time_free(stop_key) return false end
		q.DepthOffset = math.min(0,ent.DepthOffset) - 1000
		q.SortingLayer = ent.SortingLayer
		local d2 = q:GetData()
		d2.nil_mode = "boss_sprite"
		d[item.own_key.."info"] = info
		d2[item.own_key.."effect"] = {linker = ent,color = col,render_work = function(ent,tg,rpos)
			if not item.session or item.session.id ~= session_id then return end
			if d[item.own_key.."background"] == nil then 
				local s = Sprite() s:Load("gfx/ui/boss/BossScreen.anm2",true) if info.Background then s:ReplaceSpritesheet(0,info.Background) end s:LoadGraphics() s:Play("Idle",true)
				d[item.own_key.."background"] = s 
			end
			local s = d[item.own_key.."background"] s:SetFrame("Idle",d[item.own_key.."counter"] or 0)
			s:Render(rpos,Vector(0,0),Vector(0,0))
			d[item.own_key.."rpos"] = rpos
		end,work = function(ent,tg)
			if not item.session or item.session.id ~= session_id then ent:Remove() return end
			local d = tg:GetData()
			d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
			if d[item.own_key.."counter"] > item.max_counter then
				d[item.own_key.."finished"] = true
				finish_session(session_id, true)
			end
		end,}
		d2.follower = ent
		d[item.own_key.."linker"] = q
		item.sprite_linker = q
		item.session = {id = session_id, boss = ent, linker = q, stop_key = stop_key, info = info}
		delay_buffer.addeffe(function(params)
			finish_session(params.id, true)
		end,{id = session_id},item.max_counter + 30)
		return true
	else
		-- 旧 linker 不得复用到新 generation；清掉后重新建立。
		d[item.own_key.."linker"]:Remove()
		d[item.own_key.."linker"] = nil
		auxi.time_free(stop_key)
		return item.try_start_screen(ent, info)
	end
end

function item.screen_update(ent,info)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
	if item.session and auxi.check_all_exists(item.session.boss) then
		return false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	local session = item.session
	if session and auxi.check_all_exists(session.linker) and auxi.check_all_exists(session.boss) then
		local d = session.boss:GetData() local info = session.info or d[item.own_key.."info"]
		if info then
			if d[item.own_key.."body"] == nil then 
				local s = Sprite() s:Load("gfx/ui/boss/BossScreen.anm2",true) if info.Portrait then s:ReplaceSpritesheet(1,info.Portrait) end if info.name then s:ReplaceSpritesheet(2,info.name) end s:LoadGraphics() s:Play(info.anim or "Boss",true)
				d[item.own_key.."body"] = s 
			end
			for i = 0,3 do
				local id = math.max(0,(d[item.own_key.."counter"] or 0) - i)
				local s = d[item.own_key.."body"] s:SetFrame(info.anim or "Boss",id) s.Color = Color(1,1,1,item.alpha_info[i])
				local rinfo = auxi.check_lerp(id,item.screen_display_info)
				local tgpos = auxi.mul_t(auxi.GetScreenCenter(),info.dpos or Vector(1,1))
				local rpos = d[item.own_key.."rpos"] or Isaac.WorldToScreen(session.boss.Position + session.boss.PositionOffset)
				local dpos = rpos + (info.pos or Vector(0,0))
				s:Render(auxi.onLerp(dpos,tgpos,rinfo.val),Vector(0,0),Vector(0,0))
			end
		end
	elseif session then finish_session(session.id, true) end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil, Function = function()
	if item.session then finish_session(item.session.id, true) end
end})
table.insert(item.ToCall,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil, Function = function()
	if item.session then finish_session(item.session.id, true) end
end})
table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_GAME_END, params = nil, Function = function()
	if item.session then finish_session(item.session.id, true) end
end})

Nil_holder.register("boss_sprite", {
	detect = function(d) return d[item.own_key.."effect"] end,
	update = function(ent, d, s, player)
		if auxi.check_all_exists(d[item.own_key.."effect"].linker) ~= true then ent:Remove() return
		else
			local tg = d[item.own_key.."effect"].linker
			if ent.DepthOffset > tg.DepthOffset then ent.DepthOffset = tg.DepthOffset - 10 end
			ent.SortingLayer = tg.SortingLayer
			auxi.check_if_any(d[item.own_key.."effect"].work,ent,tg)
		end
	end,
	render = function(ent, d, s, player)
		if auxi.check_all_exists(d[item.own_key.."effect"].linker) then
			local tg = d[item.own_key.."effect"].linker
			if tg.Visible then
				local s2 = auxi.copy_sprite(tg:GetSprite())
				if auxi.check_if_any(Nil_holder.Color_remove_overlay[tg.Type],tg) then s2:RemoveOverlay() end
				local alpha = s2.Color.A
				local scale = Vector(s2.Scale.X,s2.Scale.Y)
				local cnt = d[item.own_key.."effect"].cnt or 0
				local rpos = Isaac.WorldToScreen(tg.Position + tg.PositionOffset)
				auxi.check_if_any(d[item.own_key.."effect"].render_work,ent,tg,rpos)
				for i = 1,cnt do
					s2.Scale = scale * (1.03 + i * 0.01)
					s2.Color = auxi.MulColor(Color(1,1,1,alpha * (cnt - i + 1)/cnt,1,1,1),d[item.own_key.."effect"].color or Color(0,0,0,1,1,1,1))
					s2:Render(rpos,Vector(0,0),Vector(0,0))
				end
				if auxi.check_if_any(Nil_holder.Color_rendertype[tg.Type],tg) then tg:GetSprite():Render(rpos,Vector(0,0),Vector(0,0)) end
			end
		end
	end,
})

return item

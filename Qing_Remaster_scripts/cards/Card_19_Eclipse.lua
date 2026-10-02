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
	-- 高空坠落表现：只改视觉/状态结构，不改旋涡范围、持续与落地伤害强度
	Eclipse_Fall = {
		hold_min = 8,
		hold_max = 12,
		fall_frames = 22,
		start_height = -192,
		landing_spread = 12,
		impact_damage = 15,
		fall_curve = {
			{frame = 0, offset = -192},
			{frame = 4, offset = -180},
			{frame = 8, offset = -150},
			{frame = 12, offset = -108},
			{frame = 16, offset = -60},
			{frame = 19, offset = -24},
			{frame = 21, offset = -8},
			{frame = 22, offset = 0},
		},
		shadow_curve = {
			{frame = 0, scale = 0.45, alpha = 0.20},
			{frame = 8, scale = 0.55, alpha = 0.30},
			{frame = 14, scale = 0.70, alpha = 0.45},
			{frame = 18, scale = 0.85, alpha = 0.65},
			{frame = 22, scale = 1.00, alpha = 0.85},
		},
	},
	SHADOW_ANM2 = "gfx/shadow_replace.anm2",
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
	Attribute_holder.ensure_hold_token(ent, d, item.own_key.."Visible", "Visible", false)
	Attribute_holder.ensure_hold_token(ent, d, item.own_key.."GridCollisionClass", "GridCollisionClass", EntityGridCollisionClass.GRIDCOLL_NONE)
	Attribute_holder.ensure_hold_token(ent, d, item.own_key.."EntityCollisionClass", "EntityCollisionClass", EntityCollisionClass.ENTCOLL_NONE)
end

function item.Release(ent)
	local d = ent:GetData()
	local failed = false
	if not Attribute_holder.rewind_hold_token(ent, d, item.own_key.."Visible", "Visible") then failed = true end
	if not Attribute_holder.rewind_hold_token(ent, d, item.own_key.."GridCollisionClass", "GridCollisionClass") then failed = true end
	if not Attribute_holder.rewind_hold_token(ent, d, item.own_key.."EntityCollisionClass", "EntityCollisionClass") then failed = true end
	if failed then
		ent.Visible = true
		Attribute_holder.force_clear_freeze_entity(ent)
	end
end

-- 异常中断：表现可失败，但绝不能永久隐藏敌人
function item.AbortCapture(tg, landing_pos)
	if not auxi.check_all_exists(tg) then return end
	if landing_pos then
		tg.Position = landing_pos
		auxi.fix_position(tg)
	end
	tg.Velocity = Vector.Zero
	item.Release(tg)
	tg:GetData()[item.own_key.."effect"] = nil
end

function item.EnsureShadowSprite(d)
	local spr = d[item.own_key.."shadow"]
	if spr then return spr end
	spr = Sprite()
	spr:Load(item.SHADOW_ANM2, true)
	spr:Play("Idle", true)
	spr:SetFrame("Idle", 0)
	d[item.own_key.."shadow"] = spr
	return spr
end

function item.MakeFallRng(seed_ent)
	local rng = RNG()
	local seed = 1
	if seed_ent and seed_ent.InitSeed and seed_ent.InitSeed ~= 0 then
		seed = seed_ent.InitSeed
	else
		seed = Random()
		if seed == 0 then seed = 1 end
	end
	rng:SetSeed(seed, 35)
	-- 同 InitSeed / 同帧多敌捕获时错开 hold / 落点
	local mix = (Game():GetFrameCount() % 997) + 1 + (seed_ent and (seed_ent.Index or 0) or 0)
	for _ = 1, mix % 7 + 1 do
		rng:Next()
	end
	return rng
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
			local fall = item.Eclipse_Fall
			local room = Game():GetRoom()
			local nearby = Isaac.FindInRadius(ent.Position,30,EntityPartition.ENEMY)
			for u,v in pairs(nearby) do
				if auxi.isenemies(v) and (v.Position - ent.Position):Length() < 30 and not v:GetData()[item.own_key.."effect"] then
					local rng = item.MakeFallRng(v)
					local offset = Vector(
						rng:RandomInt(fall.landing_spread * 2 + 1) - fall.landing_spread,
						rng:RandomInt(17) - 8
					)
					local landing_pos = room:GetClampedPosition(ent.Position + offset, (v.Size or 13) + 8)
					local q = auxi.fire_nil(landing_pos, Vector.Zero, {cooldown = 999,})
					local d2 = q:GetData()
					d2.nil_mode = "card_19_eclipse"
					d2.skip_nil_distance_cull = true
					d2[item.own_key.."effect"] = {
						Renderer = v,
						state = "swallowed",
						counter = 0,
						hold = rng:RandomInt(fall.hold_max - fall.hold_min + 1) + fall.hold_min,
						landing_pos = landing_pos,
						shadow_base = math.min(0.22, math.max(0.09, (v.Size or 13) * 0.012)),
					}
					q.Position = landing_pos
					q.PositionOffset = Vector.Zero
					q.Velocity = Vector.Zero
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
	if d[item.own_key.."effect"] and auxi.check_all_exists(d[item.own_key.."effect"].tg) ~= true then
		item.AbortCapture(ent, nil)
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
		local effect = d[item.own_key.."effect"]
		if not effect then
			ent:Remove()
			return
		end
		local fall = item.Eclipse_Fall
		local tg = effect.Renderer
		if not auxi.check_all_exists(tg) then
			if tg then item.Release(tg) end
			ent:Remove()
			return
		end

		local landing = effect.landing_pos or ent.Position
		effect.landing_pos = landing
		ent.Velocity = Vector.Zero
		-- 钉住隐藏 NPC，避免 AI 在不可见时走动；视觉高度只走 Nil.PositionOffset
		tg.Position = landing
		tg.Velocity = Vector.Zero
		auxi.fix_position(tg)
		effect.counter = (effect.counter or 0) + 1
		local state = effect.state or "falling"

		if state == "swallowed" then
			ent.Position = landing
			ent.PositionOffset = Vector.Zero
			if effect.counter >= (effect.hold or fall.hold_min) then
				effect.state = "falling"
				effect.counter = 0
				ent.Position = landing
				ent.PositionOffset = Vector(0, fall.start_height)
			end
			return
		end

		if state == "falling" then
			local info = auxi.check_lerp(effect.counter, fall.fall_curve)
			ent.Position = landing
			ent.PositionOffset = Vector(0, info.offset)
			if effect.counter >= fall.fall_frames then
				effect.state = "impact"
				ent.Position = landing
				ent.PositionOffset = Vector.Zero
				-- 先恢复位置，再恢复碰撞
				tg.Position = landing
				auxi.fix_position(tg)
				tg.Velocity = Vector.Zero
				item.Release(tg)
				tg:GetData()[item.own_key.."effect"] = nil
				tg:TakeDamage(fall.impact_damage, 0, EntityRef(ent), 0)
				Isaac.Spawn(1000, 17, 1, landing, Vector(0, 0), nil):ToEffect()
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEAT_JUMPS, 1, 1, false, 0, 2)
				ent:Remove()
			end
			return
		end

		-- 未知状态：安全释放
		item.AbortCapture(tg, landing)
		ent:Remove()
	end,
	render = function(ent, d, s, player, offset)
		local effect = d[item.own_key.."effect"]
		if not effect or not auxi.check_all_exists(effect.Renderer) then return end
		if effect.state ~= "falling" then return end

		local landing = effect.landing_pos or ent.Position
		local fall = item.Eclipse_Fall
		local shadow_info = auxi.check_lerp(effect.counter or 0, fall.shadow_curve)
		local spr = item.EnsureShadowSprite(d)
		local base = effect.shadow_base or 0.12
		local sc = base * (shadow_info.scale or 1)
		spr.Scale = Vector(sc, sc)
		spr.Color = Color(0, 0, 0, shadow_info.alpha or 0.5)
		spr:Render(Isaac.WorldToScreen(landing), Vector.Zero, Vector.Zero)

		effect.Renderer:GetSprite():Render(
			Isaac.WorldToScreen(ent.Position + ent.PositionOffset),
			Vector.Zero,
			Vector.Zero
		)
	end,
	remove = function(ent, d)
		local effect = d[item.own_key.."effect"]
		if not effect then return end
		local tg = effect.Renderer
		if auxi.check_all_exists(tg) and tg:GetData()[item.own_key.."effect"] then
			item.AbortCapture(tg, effect.landing_pos)
		end
		d[item.own_key.."effect"] = nil
	end,
})

return item

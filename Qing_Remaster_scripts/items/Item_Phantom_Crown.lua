local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
--l local player = Game():GetPlayer(0) local Phantom_Crown = require("Qing_Remaster_scripts.items.Item_Phantom_Crown") local q = Phantom_Crown.fire_phantom(player,player.Position,Vector(10,0)) print(q:GetSprite():GetAnimation())
local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Phantom_Crown,
	own_key = "Item_Phantom_Crown_",
	dir_map = {
		["WalkDown"] = {dir = Vector(0,1),headname = "HeadDown",},
		["WalkRight"] = {dir = Vector(1,0),headname = "HeadRight",},
		["WalkUp"] = {dir = Vector(0,-1),headname = "HeadUp",},
		["WalkLeft"] = {dir = Vector(-1,0),headname = "HeadLeft",},
	},
	no_fly_blacklist = {
		[1] = true,
		[2] = true,
		[3] = true,
		[4] = true,
	},
	Colorinfo = {
		{frame = 0 * 6,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 6,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 6,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 6,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 6,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 6,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 6 * 6,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 6,
	},
	cut_mul_info = {
		{frame = 0,val = 2,},
		{frame = 70,val = 4,},
		{frame = 120,val = 6,},
		{frame = 200,val = 10,},
	},
	time_counter = function(player,item) return player.MaxFireDelay * 5 + 20 end,
}
auxi.add_to_seija(item.entity)

function item.fire_phantom(player,pos,vel,params)
	params = params or {}
	if auxi.should_do_Seija(player) then vel = vel * 2.5 end
	local q = Isaac.Spawn(1000,enums.Entities.Phantom,0,pos,vel,player):ToEffect()
	local s = q:GetSprite()
	local d = q:GetData()
	auxi.copy_sprite(player:GetSprite(),s)
	local color = params.color or Color(1,1,1,0.5,-1,-1,-1)
	if auxi.should_do_Seija(player) then color = auxi.MulColor(color,Color(1,1,1,0.1,1,1,1)) end
	d[item.own_key.."Base"] = {color = color,}
	d[item.own_key.."effect"] = {}
	local str = s:GetAnimation()
	for u,v in pairs(item.dir_map) do
		if string.sub(str,-(#u)) == u then 
			for uu,vv in pairs(item.dir_map) do
				if auxi.do_t(vel:Normalized(),vv.dir) > 0.7 then 
					s:Play(string.sub(str,1,(#str) - (#u))..uu,true)
					s:PlayOverlay(vv.headname,true)
					break
				end
			end
			break
		end
	end
	s.Color = color
	return q
end

function item.flash(player,target)
	local d = player:GetData() local d2 = target:GetData()
	local dmg = player.Damage 
	d[item.own_key.."effect"] = {dmg = dmg * 2.5,linker = target,} d2[item.own_key.."step"] = {}
	local cnt = 2 local mul = 10 --if auxi.should_do_Seija(player) then cnt = 3 mul = 15 end
	local dir = (target.Position - player.Position):Normalized() local tdir = auxi.get_by_rotate(dir,auxi.random_0() * 90)
	local pos1 = player.Position local pos2 = target.Position local leg = (target.Position - player.Position):Length()
	mul = math.ceil(auxi.check_lerp(leg,item.cut_mul_info).val)
	local tbl = auxi.make_lerp({cnt = cnt,mul = mul,})
	tbl = auxi.set_to(tbl,auxi.cut_by(function(val) return auxi.Bezier({pos1,pos1 - tdir * leg * 0.1,(pos1 + pos2) * 0.5,pos2 + tdir * leg * 0.1,pos2},val) end,mul),"pos")
	d[item.own_key.."effect"].info = tbl
	if d[item.own_key.."gridcollision_succ"] == nil then d[item.own_key.."gridcollision_succ"] = Attribute_holder.try_hold_attribute(player,"GridCollisionClass",EntityGridCollisionClass.GRIDCOLL_NONE) end
	player:SetMinDamageCooldown(cnt * mul + 30)
	Attribute_holder.try_hold_and_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,cnt * mul + 10,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK))
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MIRROR_ENTER,1,1,false,0,2)
end

function item.end_flash(player)
	local d = player:GetData()
	if d[item.own_key.."gridcollision_succ"] then Attribute_holder.try_rewind_attribute(player,"GridCollisionClass",d[item.own_key.."gridcollision_succ"]) d[item.own_key.."gridcollision_succ"] = nil end
	if auxi.check_all_exists(d[item.own_key.."effect"].linker) then d[item.own_key.."effect"].linker:GetData()[item.own_key.."effect"].Remove = true end
	local e1 = Isaac.Spawn(1000,16,3,player.Position,Vector(0,0),player) e1:GetSprite().Color = Color(1,1,1,1,-1,-1,-1) local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),player) e2:GetSprite().Color = Color(1,1,1,1,-1,-1,-1) 
	local n_entity = Isaac.GetRoomEntities()
	for u,v in pairs(n_entity) do 
		if (v.Position - player.Position):Length() < 100 + v.Size then
			if auxi.isenemies(v) then 
				v:TakeDamage(2 * (d[item.own_key.."effect"].dmg or 3.5),0,EntityRef(player),0)
			end
		end
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
	d[item.own_key.."phantom"] = nil
	d[item.own_key.."effect"] = nil 
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local s = player:GetSprite()
	local d = player:GetData()
	if d[item.own_key.."effect"] then
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		local cnt = d[item.own_key.."effect"].counter
		local info = auxi.check_lerp(cnt,d[item.own_key.."effect"].info)
		local color = auxi.check_lerp(player.FrameCount % item.Colorinfo.total,item.Colorinfo)
		color = auxi.UpColor(color,1)
		player.Position = info.pos
		local q = Isaac.Spawn(1000,enums.Entities.Phantom,0,player.Position,Vector(0,0),player):ToEffect()
		local s2 = q:GetSprite() auxi.copy_sprite(player:GetSprite(),s2) local d2 = q:GetData()
		d2[item.own_key.."Reflect"] = {}
		d2[item.own_key.."Base"] = {color = color,}
		if cnt > d[item.own_key.."effect"].info.total then item.end_flash(player) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for playerNum = 1,Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player:GetData()[item.own_key.."effect"] then item.end_flash(player) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Phantom,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
	if d[item.own_key.."effect"] then
		--local dcol = auxi.check_lerp(player.FrameCount % item.Colorinfo.total,item.Colorinfo)
		local col = d[item.own_key.."Base"].color	--auxi.MulColor(d[item.own_key.."Base"].color,auxi.UpColor(dcol,1))
		if d[item.own_key.."effect"].Remove then
			d[item.own_key.."effect"].Removecounter = (d[item.own_key.."effect"].Removecounter or 0) + 1
			ent.Color = auxi.AddColor(col,Color(0,0,0,1),1,-d[item.own_key.."effect"].Removecounter / 30)
			if ent.Color.A <= 0 then ent:Remove() end
		else
			ent.Color = col
			if d[item.own_key.."step"] then
				ent.Velocity = Vector(0,0)
				if d[item.own_key.."step"].finished then d[item.own_key.."effect"].Remove = true end
			else
				local room = Game():GetRoom()
				local n_enemy = auxi.getenemies()
				for u,v in pairs(n_enemy) do 
					if (v.Position - ent.Position):Length() < ent.Size + v.Size then
						v:TakeDamage(d[item.own_key.."effect"].dmg or 3.5,0,EntityRef(player),0)
					end
				end
				if room:IsPositionInRoom(ent.Position + ent.Velocity,0) ~= true or (player.CanFly == false and item.no_fly_blacklist[room:GetGridCollisionAtPos(ent.Position + ent.Velocity)]) then
					d[item.own_key.."effect"].Remove = true
					ent.Velocity = Vector(0,0) local s2 = ent:GetSprite() s2:SetFrame(s2:GetAnimation(),s2:GetFrame())
				end
			end
		end
	end
	if d[item.own_key.."Reflect"] then
		d[item.own_key.."Reflect"].counter = (d[item.own_key.."Reflect"].counter or 0) + 1
		ent.Color = auxi.AddColor(d[item.own_key.."Base"].color,Color(0,0,0,1),1,-d[item.own_key.."Reflect"].counter / 10)
		if d[item.own_key.."Reflect"].counter > 10 then ent:Remove() end
		ent.Velocity = Vector(0,0)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		local d = player:GetData()
		if d[item.own_key.."fire"] then
			local dir = d[item.own_key.."recorddir"] or Vector(1,0)
			local q = item.fire_phantom(player,player.Position,player.ShotSpeed * 5 * dir)
			d[item.own_key.."fire"] = nil
			if auxi.check_all_exists(d[item.own_key.."phantom"]) then d[item.own_key.."phantom"]:GetData()[item.own_key.."effect"].Remove = true end
			d[item.own_key.."phantom"] = q
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local room = Game():GetRoom()
	local s = player:GetSprite()
	local d = player:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		if auxi.has_have_coll(player,item.entity) then
			local cnt = d[item.own_key.."counter"] or 0
			Charging_Bar_holder.render_me(player,{name1 = item.own_key.."counter",name2 = item.own_key.."sprite",name3 = item.own_key,loadname = "gfx/effects/chargebar/chargebar_Phamton_Crown.anm2",
				check1 = function(val,ent)
					return cnt > 5
				end,
				check2 = function(val,ent) 
					return cnt > auxi.check_if_any(item["time_counter"],player,item)
				end,
				check3 = function(val,ent)
					return math.ceil(cnt/auxi.check_if_any(item["time_counter"],player,item) * 100)
				end,
				signal1 = function(ent)
					d[item.own_key.."active"] = true
				end,
			})
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	if collid == item.entity and count < 0 then
		Charging_Bar_holder.remove_charge_bar(player,item.own_key)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local ctrlid = player.ControllerIndex
		local d = player:GetData()
		if auxi.g_dir_can_work(player) then
			if auxi.has_have_coll(player,item.entity) and d[item.own_key.."effect"] == nil then
				local act = false
				for i = 4,7 do
					if (Input.IsActionTriggered(i,ctrlid)) or (Input.IsActionPressed(i,ctrlid)) then
						act = true
					end
				end
				if act then 
					d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1 
					if d[item.own_key.."active"] then
						local dir = auxi.ggdir(player,true,true)
						if dir:Length() > 0.05 then d[item.own_key.."recorddir"] = dir end
					end
				else 
					if d[item.own_key.."active"] then d[item.own_key.."active"] = nil d[item.own_key.."fire"] = {} end
					d[item.own_key.."counter"] = 0
				end
			end
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if amt > 0 and auxi.is_damage_from_enemy(ent,amt,flag,source,cooldown) and player and auxi.has_have_coll(player,item.entity) then
		local d = player:GetData()
		if auxi.check_all_exists(d[item.own_key.."phantom"]) then
			local d2 = d[item.own_key.."phantom"]:GetData()
			if d2[item.own_key.."effect"] and not d[item.own_key.."effect"] then		--and not d2[item.own_key.."effect"].Remove 
				item.flash(player,d[item.own_key.."phantom"])
				return false
			end
		end
	end
end,
})

return item
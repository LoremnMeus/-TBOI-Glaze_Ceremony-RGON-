local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Aquarius_holder = require("Qing_Remaster_scripts.mimics.Aquarius_holder")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Pathetique,
	own_key = "Item_Pathetique_",
	Qual2wei = {
		[0] = 100,
		[1] = 60,
		[2] = 20,
		[3] = 5,
		[4] = 1,
	},
	render_info = {
		{frame = 0,dis = 100,rot = 8,alpha = 0,scale = 0,offset = Vector(0,0),},
		{frame = 30,dis = 100,rot = 8,alpha = 0,scale = 0,offset = Vector(0,-10),},
		{frame = 40,dis = 90,rot = 5,alpha = 1,scale = 1,offset = Vector(0,-40),},
		{frame = 120,dis = 50,rot = 2,alpha = 1,scale = 0.6,offset = Vector(0,-60),},
		{frame = 160,dis = 10,rot = 1,alpha = 1,scale = 0.1,offset = Vector(0,-55),},
		{frame = 170,dis = 0,rot = 0,alpha = 1,scale = 0,offset = Vector(0,-50),},
		{frame = 180,dis = 0,rot = 0,alpha = 1,scale = 0,offset = Vector(0,0),},
		total = 180,
	},
}
auxi.add_to_seija(item.entity)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local idx = player:GetData().__Index
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		local mul = 0.5
		if auxi.should_do_Seija(player) then mul = 0 end
		local cnt = #(save.elses[item.own_key.."effect"][idx] or {})
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * cnt * mul)
        end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if amt > 0 and auxi.is_damage_from_enemy(ent, amt, flag, source, cooldown) then
		if player and auxi.has_have_coll(player,item.entity) then
			local idx = player:GetData().__Index
			if idx then
				save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
				save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
				local rng = player:GetCollectibleRNG(item.entity)
				local col = auxi.get_random_item_that_player_has(player,rng,{ignore_active_item = true,ignore_pool = {[item.entity] = 1,},by_weight = function(val,id) local collectible = Isaac:GetItemConfig():GetCollectible(id) if collectible then return item.Qual2wei[collectible.Quality] or 1 end end,})
				if col == nil and player:GetCollectibleNum(item.entity,true) > 0 then col = item.entity end
				if col then
					table.insert(save.elses[item.own_key.."effect"][idx],#save.elses[item.own_key.."effect"][idx] + 1,{id = col,})
					player:RemoveCollectible(col)
					player:SetMinDamageCooldown(cooldown)
					player:AnimateCollectible(col,"UseItem","PlayerPickup")
					player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
					player:GetData().should_evaluate_on_update_once = true
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SUPERHOLY,1,1,false,0,2)
					local cnt = 6
					local rrnd = auxi.random_1() * 90
					for i = 1,4 do 
						local qt = Isaac.Spawn(2,0,0,player.Position,auxi.get_by_rotate(nil,i * 90 + rrnd,10),player):ToTear()
						qt.Scale = 2.5
						qt:ResetSpriteScale()
						for j = 1,cnt do 
							local q = Isaac.Spawn(1000,54,0,player.Position + auxi.get_by_rotate(nil,i * 90 + rrnd,(j - 1) * 20),Vector(0,0),player):ToEffect()
							q.CollisionDamage = player.Damage
							Aquarius_holder.help_control(q,{special = function(ent)
								ent:GetSprite().Color = auxi.MulColor(Color(1,1,1,1),Color(1,1,1,(1 - j/cnt) * math.min(1,ent.Timeout/60),1,1,1))
							end,init = true,})
						end 
					end
					local q2 = auxi.spawn_item_dust(player,player.Position,col,Color(1,0,0,1),Color(1,0.1,0.1,1),true)
					q2.Parent = player
					q2.CollisionDamage = player.Damage * 3
					local s2 = q2:GetSprite()
					s2.Scale = Vector(1.5,1.5)
					s2.Color = Color(1,0,0,1)
					return false
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local d = player:GetData()
	if d[item.own_key.."effect"] and d[item.own_key.."effect"].start then
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			local cnt = d[item.own_key.."effect"].start.counter or 0
			local innerframe = d[item.own_key.."effect"].frame or 0
			local info = auxi.check_lerp(cnt,item.render_info)
			local mx = #d[item.own_key.."effect"].start
			local pos = player.Position + player_offset_holder.GetPlayerOffset(player)
			for i = 1,mx do 
				local v = d[item.own_key.."effect"].start[i]
				v.Color = Color(1,1,1,info.alpha)
				v.Scale = Vector(1,1) * info.scale
				v:Render(Isaac.WorldToScreen(pos + auxi.get_by_rotate(nil,innerframe * 3 + i * 360/mx,info.dis)),Vector(0,0),Vector(0,0))
			end
			d[item.own_key.."effect"].frame = (d[item.own_key.."effect"].frame or 0) + info.rot
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHECK_PLAYER_POSITIONOFFSET, params = nil,
Function = function(_,player,value)
	local d = player:GetData()
	if d[item.own_key.."effect"] and d[item.own_key.."effect"].start then
		value.Remove = false
		local cnt = d[item.own_key.."effect"].start.counter or 0
		local info = auxi.check_lerp(cnt,item.render_info)
		value.Offset = value.Offset + info.offset
	end
	return value
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	if auxi.has_have_coll(player,item.entity) ~= true and (save.elses[item.own_key.."effect"] and save.elses[item.own_key.."effect"][idx]) and not d[item.own_key.."effect"] and Game():GetRoom():GetFrameCount() > 1 then
		d[item.own_key.."effect"] = {}
	end
	if d[item.own_key.."effect"] then
		if player:IsExtraAnimationFinished() then 
			player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
			d[item.own_key.."effect"].start = {}
			for i = #((save.elses[item.own_key.."effect"][idx] or {})),1,-1 do
				local v = save.elses[item.own_key.."effect"][idx][i]
				local col = v.id
				if col ~= item.entity then 
					local s = auxi.load_item(col)
					table.insert(d[item.own_key.."effect"].start,#d[item.own_key.."effect"].start + 1,s)
				end
			end
			player_offset_holder.LoadPlayer(nil,true)
		else
			if d[item.own_key.."effect"].start then
				d[item.own_key.."effect"].start.counter = (d[item.own_key.."effect"].start.counter or 0) + 1
				player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
				player:SetMinDamageCooldown(math.max(0,3 - player:GetDamageCooldown()))
				if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] == nil then d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = Attribute_holder.try_hold_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) end
				if d[item.own_key.."EntityCollision"] == nil then d[item.own_key.."EntityCollision"] = Attribute_holder.try_hold_attribute(player,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)	end
				if d[item.own_key.."effect"].start.counter >= item.render_info.total then
					player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
					if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] then Attribute_holder.try_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = nil end
					if d[item.own_key.."EntityCollision"] then Attribute_holder.try_rewind_attribute(player,"EntityCollisionClass",d[item.own_key.."EntityCollision"]) d[item.own_key.."EntityCollision"] = nil end
					local config = Isaac.GetItemConfig()
					for i = #((save.elses[item.own_key.."effect"][idx] or {})),1,-1 do
						local v = save.elses[item.own_key.."effect"][idx][i]
						local col = v.id
						if col ~= item.entity then
							if auxi.REPENTENCE_PLUS() then
								player:AddCollectible(col, 0, false)  -- 新版本使用AddCollectible
							else
								player:QueueItem(config:GetCollectible(col), 0, true)  -- 旧版本保持QueueItem
								player:FlushQueueItem()
							end
						end
						table.remove(save.elses[item.own_key.."effect"][idx],i)
					end
					d[item.own_key.."effect"] = nil
					save.elses[item.own_key.."effect"][idx] = nil
					player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
					player:GetData().should_evaluate_on_update_once = true
					local q = Isaac.Spawn(1000,144,1,player.Position,Vector(0,0),nil)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEMON_HIT,1,1,false,0,2)
				end
			end
		end
	end
end,
})

return item
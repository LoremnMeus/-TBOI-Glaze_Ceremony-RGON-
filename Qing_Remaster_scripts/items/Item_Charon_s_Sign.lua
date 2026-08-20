local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Charon_s_Sign,
	own_key = "Item_Charon_s_Sign_",
	time_info = {
		{frame = 0,counter = -1,},
		{frame = 45 * 30,counter = 0,},
		{frame = 60 * 30 * (20 + 45/60),counter = 40,},
	},
	back_rate = 0.2,
	protect_distance = 120,
	pickup_protect_distance = 120,
	seija_time_multiplier = 4,
	tide_damage = 7,
	tide_spawn_interval = 15,
	remove_list = {[4] = true,[5] = true,},
	tide_particles = {},
	render_buckets = {},
	render_anchors = {},
	render_anchor_rows = nil,
	tide_spawn_frames = {},
	room_positions = {},
	holder_cache = nil,
}

-- 本道具有独立设计的 Seija 效果，排除 Reverie 对普通模组道具的默认反转处理。
auxi.add_to_seija(item.entity)

local function debug_number(key,default,min,max)
	local root=save.ModConfigSettings
	local options=root and root.QingRemasterOptions
	local debug=options and options.Debug
	local value=tonumber(debug and debug[key]) or default
	if min then value=math.max(min,value) end
	if max then value=math.min(max,value) end
	return value
end

local function debug_boolean(key,default)
	local root=save.ModConfigSettings
	local options=root and root.QingRemasterOptions
	local debug=options and options.Debug
	local value=debug and debug[key]
	if value==nil then return default end
	return value==true
end

local function tide_settings()
	return {
		spawn_interval=math.floor(debug_number("CharonSpawnInterval",item.tide_spawn_interval,1,120)+0.5),
		lifetime=math.floor(debug_number("CharonParticleLifetime",120,10,600)+0.5),
		fade_frames=math.floor(debug_number("CharonFadeFrames",20,1,120)+0.5),
		foreground_rate=debug_number("CharonForegroundRate",item.back_rate,0,1),
		rows_per_anchor=math.floor(debug_number("CharonRowsPerAnchor",1,1,8)+0.5),
		room_prefill=debug_number("CharonRoomPrefillRatio",0.5,0,1),
		room_fade_frames=math.floor(debug_number("CharonRoomFadeFrames",15,0,120)+0.5),
		seija_multiplier=debug_number("CharonSeijaSpeedMultiplier",item.seija_time_multiplier,1,20),
		pickup_radius=debug_number("CharonPickupProtectRadius",item.pickup_protect_distance,0,240),
		force_seija=debug_boolean("CharonForceSeijaEnhancement",false),
	}
end

local function holder_info()
	local frame=Game():GetFrameCount()
	if item.holder_cache and item.holder_cache.frame==frame then
		return item.holder_cache.holders,item.holder_cache.seija
	end
	local holders = {}
	local force_seija=tide_settings().force_seija
	local seija = force_seija
	for player_index=0,Game():GetNumPlayers()-1 do
		local player=Game():GetPlayer(player_index)
		if auxi.has_have_coll(player,item.entity) then
			table.insert(holders,player)
			if auxi.should_do_Seija(player) then seija=true end
		end
	end
	item.holder_cache={frame=frame,holders=holders,seija=seija}
	return holders,seija
end

local function tide_counter()
	local elapsed=Game():GetFrameCount()-(save.elses[item.own_key] or 0)
	local _,seija=holder_info()
	if seija then elapsed=elapsed*tide_settings().seija_multiplier end
	return auxi.check_lerp(elapsed,item.time_info).counter
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key] = Game():GetFrameCount()
	item.level_info = nil
	item.level_info_safe = nil
	item.level_info_safe_ = nil
	item.tide_particles = {}
	item.render_buckets = {}
	item.render_anchors = {}
	item.render_anchor_rows = nil
	item.tide_spawn_frames = {}
	item.room_positions = {}
	if auxi.have_player_has_collectible(item.entity) then item.check_level() end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.level_info = nil
	item.level_info_safe = nil
	item.level_info_safe_ = nil
end,
})

function item.check_level()		--检查全层并做好标记		每次开启红房间后立刻重置
	item.level_info = {}
	item.level_info_safe = {}
	item.level_info_safe_ = {}
	local loop_tbl = {{id = 84,val = 0,},}
	item.level_info[84] = 0
	item.level_info_safe[84] = 0
	item.level_info_safe_[84] = 0
	local level = Game():GetLevel()
	local head=1
	while loop_tbl[head] do
		local tab = loop_tbl[head]
		for i = 0,3 do 
			local idx = auxi.move_in_gridroom(tab.id,i)
			--local safe = auxi.is_safe_move_in_gridroom(tab.id,idx)
			local ddesc = level:GetRoomByIdx(idx)
			if idx ~= tab.id and ddesc.Data and item.level_info[idx] == nil then 
				table.insert(loop_tbl,{id = idx,val = tab.val + 1,})
				item.level_info[idx] = tab.val + 1
				item.level_info_safe[ddesc.SafeGridIndex] = math.max(item.level_info_safe[ddesc.SafeGridIndex] or 0,tab.val + 1)		--最大值
				item.level_info_safe_[ddesc.SafeGridIndex] = math.min(item.level_info_safe_[ddesc.SafeGridIndex] or 9999,tab.val + 1)		--最小值
			end
		end
		head=head+1
	end
	return item.level_info
end
--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local item = require("Qing_Remaster_scripts.items.Item_Charon_s_Sign") item.check_level() auxi.PrintTable(item.level_info)

local function particle_alpha_at_age(color_alpha,age,lifetime,fade_frames)
	local solid_frames=math.max(0,lifetime-fade_frames)
	local solid_age=math.min(age,solid_frames)
	local alpha=color_alpha*(1-0.8^solid_age)
	if age>solid_frames then alpha=alpha*0.8^(age-solid_frames) end
	return alpha
end

function item.generate_black_tide(pos,vel,force,initial_age)
	local settings=tide_settings()
	local age=math.max(0,math.floor(initial_age or (force and 1 or 0)))
	local color_alpha=auxi.random_1()*0.5+0.5
	local particle={
		position=pos+auxi.random_v2()*20,
		age=age,
		lifetime=settings.lifetime,
		alpha=particle_alpha_at_age(color_alpha,age,settings.lifetime,settings.fade_frames),
		color_alpha=color_alpha,
		scale=Vector(auxi.random_1(),auxi.random_1())+Vector(1.5,1.5),
		rotation=auxi.random_1()*360,
		foreground=auxi.random_1()<settings.foreground_rate,
		animation_frame=math.min(7,math.floor(auxi.random_1()*8)),
	}
	table.insert(item.tide_particles,particle)
	return particle
end

function item.check_room(cnt)
	cnt = cnt or tide_counter()
	local room = Game():GetRoom() local level = Game():GetLevel()
	local idx = level:GetCurrentRoomDesc().SafeGridIndex
	if item.level_info_safe[idx] + 1 < cnt then return {all = true,} end
	--if item.level_info_safe_[idx] - 1 > cnt then return {none = true,} end
	local set_tbl = {}
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		local door = room:GetDoor(slot)
		if door then 
			local didx = door.TargetRoomIndex 
			if didx >= 0 and didx < 169 then
				local val = item.level_info[didx]
				if val and val < cnt then table.insert(set_tbl,{id = door:GetGridIndex(),val = (item.level_info_safe_[idx] - 1) - val,}) end
			end
		end
	end
	if #set_tbl == 0 then table.insert(set_tbl,{id = room:GetGridIndex(room:GetCenterPos()),val = 0,}) end
	table.sort(set_tbl,function(a,b) return a.val < b.val end)
	local ret_table = {}
	local loop_tbl = {{id = set_tbl[1].id,val = set_tbl[1].val,},}
	ret_table[loop_tbl[1].id] = loop_tbl[1].val
	table.remove(set_tbl,1)
	local width = room:GetGridWidth()
	local height = room:GetGridHeight()
	local head=1
	while loop_tbl[head] do
		local tab = loop_tbl[head]
		for i = 0,3 do 
			local idx = auxi.move_in_roomgrid(tab.id,i,width,height)
			if idx ~= tab.id and idx >= 0 and idx <= width * height and ret_table[idx] == nil then
				table.insert(loop_tbl,{id = idx,val = tab.val + 1/10,})
				ret_table[idx] = tab.val + 1/10
				while (set_tbl[1] and set_tbl[1].val <= tab.val + 1/10) do 
					local source={id=set_tbl[1].id,val=set_tbl[1].val}
					table.insert(loop_tbl,source)
					ret_table[source.id]=source.val
					table.remove(set_tbl,1)
				end
			end
		end
		head=head+1
	end
	return ret_table
end

local function distance_squared(a,b)
	local delta=a-b
	return delta.X*delta.X+delta.Y*delta.Y
end

local function protected_positions()
	local positions={}
	local holders,seija=holder_info()
	for _,player in ipairs(holders) do
		table.insert(positions,{position=player.Position,radius=item.protect_distance})
	end
	-- 类型6包含机器、乞丐等可互动实体：所有模式下都形成安全区，且不再被黑潮移除。
	for _,slot in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
		if slot:Exists() and not slot:IsDead() then
			table.insert(positions,{position=slot.Position,radius=item.protect_distance})
		end
	end
	if seija then
		local pickup_radius=tide_settings().pickup_radius
		for _,pickup in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do
			if pickup:Exists() and not pickup:IsDead() then
				table.insert(positions,{position=pickup.Position,radius=pickup_radius})
			end
		end
	end
	return positions,seija
end

local function is_protected(pos,positions)
	for _,entry in ipairs(positions) do
		if distance_squared(pos,entry.position)<entry.radius*entry.radius then return true end
	end
	return false
end

function item.try_remove_grid(i,force,positions)
	local room = Game():GetRoom()
	local gent = room:GetGridEntity(i)
	if not gent then return end
	local pos = item.room_positions[i] or room:GetGridPosition(i)
	if not force and is_protected(pos,positions or protected_positions()) then return end
	if gent and auxi.is_removeable_grid(gent) then
		room:RemoveGridEntity(i,0,true)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if auxi.have_player_has_collectible(item.entity) then 
		item.level_info = item.check_level() 
		item.check_room_list = item.check_room() 
		item.tide_particles = {}
		item.render_buckets = {}
		item.render_anchors = {}
		item.render_anchor_rows = nil
		item.tide_spawn_frames = {}
		item.room_positions = {}
		local room=Game():GetRoom()
		for grid_index=0,room:GetGridSize()-1 do item.room_positions[grid_index]=room:GetGridPosition(grid_index) end
		item.check_black_tide(true)
	else item.check_room_list = nil end
end,
})

local anchor_key=item.own_key.."render_anchor"
local invisible=Color(1,1,1,0)

local function remove_render_anchors()
	for _,anchor in pairs(item.render_anchors) do
		if anchor and anchor:Exists() then anchor:Remove() end
	end
	item.render_anchors={}
end

local function particle_bucket(particle,rows_per_anchor)
	if not particle.foreground then return "background" end
	local room=Game():GetRoom()
	local grid_index=math.max(0,room:GetGridIndex(particle.position))
	local row=math.floor(grid_index/math.max(1,room:GetGridWidth()))
	return "foreground_"..math.floor(row/rows_per_anchor)
end

local function anchor_position(key,rows_per_anchor)
	local room=Game():GetRoom()
	if key=="background" then return room:GetCenterPos() end
	local band=tonumber(string.match(key,"(%d+)$")) or 0
	local width=math.max(1,room:GetGridWidth())
	local row=band*rows_per_anchor+math.floor((rows_per_anchor-1)/2)
	local index=math.min(room:GetGridSize()-1,row*width+math.floor(width/2))
	return room:GetGridPosition(math.max(0,index))
end

local function ensure_render_anchors(rows_per_anchor)
	if item.render_anchor_rows~=rows_per_anchor then
		remove_render_anchors()
		item.render_anchor_rows=rows_per_anchor
	end
	for key,_ in pairs(item.render_buckets) do
		local anchor=item.render_anchors[key]
		if not anchor or not anchor:Exists() or anchor:IsDead() then
			anchor=Isaac.Spawn(EntityType.ENTITY_EFFECT,59,0,anchor_position(key,rows_per_anchor),Vector.Zero,nil):ToEffect()
			anchor.Timeout=120
			anchor.LifeSpan=120
			anchor.DepthOffset=key=="background" and -1000 or 0
			anchor.EntityCollisionClass=EntityCollisionClass.ENTCOLL_NONE
			anchor.GridCollisionClass=EntityGridCollisionClass.GRIDCOLL_NONE
			anchor:SetShadowSize(0)
			anchor:GetData()[anchor_key]=key
			anchor.Color=invisible
			item.render_anchors[key]=anchor
		end
	end
end

local function update_particle_sprites()
	local settings=tide_settings()
	local room_frame=math.max(0,Game():GetRoom():GetFrameCount())
	local room_opacity=settings.room_fade_frames<=0 and 1 or math.min(1,room_frame/settings.room_fade_frames)
	for key,particles in pairs(item.render_buckets) do
		local anchor=item.render_anchors[key]
		if anchor and anchor:Exists() then
			local source=anchor:GetSprite()
			for _,particle in ipairs(particles) do
				local sprite=particle.sprite
				if not sprite then
					sprite=Sprite()
					sprite:Load(source:GetFilename(),true)
					sprite.Scale=particle.scale
					sprite.Rotation=particle.rotation
					particle.sprite=sprite
				end
				-- Clouds 的 8 帧是 8 张独立尘云图，不是连续动画；生成时随机一次并永久固定。
				sprite:SetFrame("Clouds",particle.animation_frame)
				sprite.Color=Color(-1,-1,-1,particle.alpha*room_opacity)
			end
		end
	end
end

local function update_tide_particles()
	local settings=tide_settings()
	local protections=protected_positions()
	local live={}
	local buckets={}
	for _,particle in ipairs(item.tide_particles) do
		particle.age=particle.age+1
		if particle.age<=particle.lifetime then
			local target=particle.age<=particle.lifetime-settings.fade_frames and particle.color_alpha or 0
			if is_protected(particle.position,protections) then target=math.min(target,0.05) end
			particle.alpha=particle.alpha*0.8+target*0.2
			local key=particle_bucket(particle,settings.rows_per_anchor)
			buckets[key]=buckets[key] or {}
			table.insert(buckets[key],particle)
			table.insert(live,particle)
		end
	end
	item.tide_particles=live
	item.render_buckets=buckets
	ensure_render_anchors(settings.rows_per_anchor)
	update_particle_sprites()
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 59,
Function = function(_,ent)
	if ent:GetData()[anchor_key] then
		ent.Timeout=120
		ent.LifeSpan=120
		ent.Color=invisible
		local sprite=ent:GetSprite()
		local animation=sprite:GetAnimation()
		if sprite:IsFinished(animation) then sprite:Play(animation,true) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = 59,
Function = function(_,ent,offset)
	local key=ent:GetData()[anchor_key]
	if not key then return end
	for _,particle in ipairs(item.render_buckets[key] or {}) do
		if particle.sprite then
			-- WorldToScreen 已包含大房间镜头位置；回调 offset 属于锚点实体，重复相加会造成镜头移动时漂移。
			particle.sprite:Render(Isaac.WorldToScreen(particle.position),Vector.Zero,Vector.Zero)
		end
	end
end,
})

function item.check_black_tide(force)
	local counter = tide_counter()
	item.level_info = item.level_info or item.check_level()
	item.check_room_list = item.check_room_list or item.check_room()
	local room = Game():GetRoom()
	local frame=Game():GetFrameCount()
	local settings=tide_settings()
	local protections=protected_positions()
	local base_chance = 0.1
	local layer_count=1
	if force then
		layer_count=math.max(1,math.floor(settings.lifetime*settings.room_prefill/settings.spawn_interval+0.5))
	end
	local layer_chances={}
	for layer=1,layer_count do layer_chances[layer]=1 end
	local function try_generate(pos)
		local generated=false
		for layer=1,layer_count do
			if auxi.random_1()<layer_chances[layer] then
				local age=force and (layer-1)*settings.spawn_interval or 0
				item.generate_black_tide(pos,Vector.Zero,force,age)
				layer_chances[layer]=layer_chances[layer]*0.5+base_chance*0.5
				generated=true
			end
		end
		return generated
	end
	if item.check_room_list.all then 
		local width = room:GetGridWidth()
		local height = room:GetGridHeight()
		for i = 0,width - 1 do
			for j = 0,height - 1 do
				local idx = i + j * width
				local pos=item.room_positions[idx] or room:GetGridPosition(idx)
				if room:IsPositionInRoom(pos,-20) then
					local can_spawn=force or (frame-(item.tide_spawn_frames[idx] or -9999)>=settings.spawn_interval)
					if can_spawn and not is_protected(pos,protections) and try_generate(pos) then
						item.tide_spawn_frames[idx]=frame
					end
					item.try_remove_grid(idx,force,protections)
				end
			end
		end
	else
		local idx = Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex
		for u,v in pairs(item.check_room_list) do
			if counter - item.level_info_safe_[idx] > v - 0.5 then 
				local pos=item.room_positions[u] or room:GetGridPosition(u)
				local can_spawn=force or (frame-(item.tide_spawn_frames[u] or -9999)>=settings.spawn_interval)
				if can_spawn and not is_protected(pos,protections) and try_generate(pos) then
					item.tide_spawn_frames[u]=frame
				end
				item.try_remove_grid(u,force,protections)
			end
		end
	end
end

function item.check_remove_pos(pos)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) and (pos - player.Position):Length() < item.protect_distance then return false end
	end
	item.level_info = item.level_info or item.check_level()
	item.check_room_list = item.check_room_list or item.check_room()
	if item.check_room_list.all then return true
	else
		local counter = tide_counter()
		local idx = Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex
		local id = Game():GetRoom():GetGridIndex(pos)
		if counter - item.level_info_safe_[idx] > item.check_room_list[id] - 0.5 then
			return true
		end
	end
	return false
end

function item.should_remove(ent)
	if ent.Type==EntityType.ENTITY_PICKUP then
		local _,seija=holder_info()
		if seija then return false end
	end
	if item.remove_list[ent.Type] then return true end
	return false 
end

function item.check_remove(ent)
	if auxi.have_player_has_collectible(item.entity) and Game():GetRoom():GetFrameCount() % 30 == 5 then
		if auxi.check_all_exists(ent) and item.should_remove(ent) and item.check_remove_pos(ent.Position) then
			local d = ent:GetData()
			d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
			ent:SetColor(Color(-1,-1,-1,0),10 * (d[item.own_key.."counter"] * 0.5 + 1),99,true,false)
			if d[item.own_key.."counter"] >= 3 then ent:Remove() return end
		end
	end
end

function item.is_burning_fireplace(ent)
	-- 原版火堆会在 1 HP 保留最后一次扑灭判定；State 3 才是真正熄灭。
	if ent.Type~=EntityType.ENTITY_FIREPLACE or ent.Variant==11 or ent:IsDead() or ent.State==3 then
		return false
	end
	local animation=ent:GetSprite():GetAnimation() or ""
	return string.sub(animation,1,6)~="NoFire" and string.sub(animation,1,9)~="Dissapear"
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local player = auxi.have_player_has_collectible(item.entity)
	if player and Game():GetRoom():GetFrameCount() % 30 == 5 then
		local is_fireplace_type=ent.Type==EntityType.ENTITY_FIREPLACE
		local is_fireplace=item.is_burning_fireplace(ent)
		local is_environment=is_fireplace or ent.Type==EntityType.ENTITY_SHOPKEEPER
		-- 熄灭后的火堆仍会保留为 NPC，不能再从普通敌人分支受到重复伤害。
		local can_damage=(not is_fireplace_type and auxi.isenemies(ent)) or is_environment
		if auxi.check_all_exists(ent) and item.check_remove_pos(ent.Position) and can_damage then
			if is_fireplace then
				-- 一次伤害覆盖火堆当前生命值，由原版受伤逻辑负责熄灭与掉落。
				ent:TakeDamage(math.max(1,ent.HitPoints),DamageFlag.DAMAGE_IGNORE_ARMOR,EntityRef(player),0)
			else
				local damage=ent.Type==EntityType.ENTITY_SHOPKEEPER and 1 or item.tide_damage
				ent:TakeDamage(damage,DamageFlag.DAMAGE_IGNORE_ARMOR,EntityRef(player),0)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	item.check_remove(ent)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_UPDATE, params = nil,
Function = function(_,ent)
	item.check_remove(ent)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if auxi.have_player_has_collectible(item.entity) then
		update_tide_particles()
		if Game():GetFrameCount() % 15 == 1 then
			item.check_black_tide()
		end
	elseif #item.tide_particles>0 or next(item.render_anchors) then
		item.tide_particles={}
		item.render_buckets={}
		remove_render_anchors()
	end
end,
})

return item

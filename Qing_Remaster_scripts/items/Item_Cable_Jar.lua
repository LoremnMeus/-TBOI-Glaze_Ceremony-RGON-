local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Cable_Jar,
	own_key = "Item_Cable_Jar_",
	min_charge_limit = 2,
	max_normalized_charge = 12,
	failed_use_delay = 18,
	damage_warning_frames = 15,
	tear_flag_buff = {
		[0] = TearFlags.TEAR_BONE,			--分裂1
		[1] = TearFlags.TEAR_SLOW,			--减速2
		[2] = TearFlags.TEAR_HOMING,		--追踪3
		[3] = TearFlags.TEAR_FEAR,			--恐惧4
		[4] = BitSet128(0,1<<(65-64)),		--冰冻5
		[5] = TearFlags.TEAR_POISON,		--中毒6
		[6] = BitSet128(0,1<<(66-64)),		--磁力7
		[7] = TearFlags.TEAR_ACID,			--硫酸8
		[8] = TearFlags.TEAR_GODS_FLESH,	--缩小
		[9] = TearFlags.TEAR_CONFUSION,		--眩晕
	},
	tear_color_buff = {
		[0] = Color(1,1,1,0.7,0,0,0),
		[1] = Color(1,0,0,0.7,0.5,0,0),
		[2] = Color(1,0.1,0.5,0.7,0.5,0,0.2),
		[3] = Color(1,0,1,0.7,0.2,0,0.2),
		[4] = Color(0.4,0,1,0.7,0,0,0.3),
		[5] = Color(0,0.5,1,0.7,0,0.2,0.5),
		[6] = Color(0.5,0.5,0,0.7,0.2,0.2,0),
		[7] = Color(0.4,0.6,0,0.8,0.1,0.3,0),
		[8] = Color(1,1,0,0.7,0.5,0.4,0),
		[9] = Color(1,0.7,0,0.7,0.5,0.2,0),
	},
}

local energy_save_key = item.own_key.."energy_records"
local energy_record_key = item.own_key.."energy_record"

local function get_room_key()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	return tostring(auxi.GetDimension())..":"..tostring(desc.SafeGridIndex)
end

local function get_energy_store(create)
	if create then
		save.elses[energy_save_key] = save.elses[energy_save_key] or {
			next_id = 0,
			rooms = {},
		}
	end
	return save.elses[energy_save_key]
end

local function bind_energy_record(player,tear,color_id,record_id)
	local store = get_energy_store(true)
	local room_key = get_room_key()
	store.rooms[room_key] = store.rooms[room_key] or {}
	if record_id == nil then
		store.next_id = (store.next_id or 0) + 1
		record_id = tostring(store.next_id)
	end
	local record = store.rooms[room_key][record_id] or {}
	record.position = {X = tear.Position.X,Y = tear.Position.Y}
	record.velocity = nil
	record.color_id = color_id
	record.target_seed = tostring(player.InitSeed)
	store.rooms[room_key][record_id] = record
	tear:GetData()[energy_record_key] = {
		room_key = room_key,
		id = record_id,
	}
end

local function update_energy_record(tear)
	local reference = tear:GetData()[energy_record_key]
	local store = get_energy_store(false)
	local room = store and store.rooms and store.rooms[reference and reference.room_key]
	local record = room and room[reference.id]
	if not record then return end
	record.position = {X = tear.Position.X,Y = tear.Position.Y}
	record.velocity = nil
end

local function remove_energy_record(tear)
	local reference = tear:GetData()[energy_record_key]
	local store = get_energy_store(false)
	local room = store and store.rooms and store.rooms[reference and reference.room_key]
	if room then room[reference.id] = nil end
end

function item.make_cable_tear(player,q,pos,vel,id,record_id)
	q = q or Isaac.Spawn(2,0,0,pos,vel,player):ToTear()
	local s2 = q:GetSprite()
	local color_id = id or (math.random(10) - 1)
	s2.Color = item.tear_color_buff[color_id]
	local d2 = q:GetData()
	d2[item.own_key.."effect"] = {target = player,}
	d2.Ignore_me_flag = true
	d2.ignore_field = true
	q.TearFlags = q.TearFlags | BitSet128(1<<1,0) | BitSet128(1<<0,0) 
	q.CollisionDamage = 2.5
	bind_energy_record(player,q,color_id,record_id)
	return q
end

local state_save_key = item.own_key.."charge_limits"
local cap_overflow_key = item.own_key.."cap_overflow"

local function get_player_state_key(player)
	return tostring(player:GetData().__Index or player.InitSeed)
end

local function get_charge_states(player,create)
	save.elses[state_save_key] = save.elses[state_save_key] or {}
	local key = get_player_state_key(player)
	local seed_key = tostring(player.InitSeed)
	if key ~= seed_key and save.elses[state_save_key][key] == nil and save.elses[state_save_key][seed_key] ~= nil then
		save.elses[state_save_key][key] = save.elses[state_save_key][seed_key]
		save.elses[state_save_key][seed_key] = nil
	end
	if create then save.elses[state_save_key][key] = save.elses[state_save_key][key] or {} end
	return save.elses[state_save_key][key]
end

local function get_charge_state(player,collectible,create)
	local states = get_charge_states(player,create)
	if not states then return nil end
	local key = tostring(collectible)
	if create then
		states[key] = states[key] or {limit = item.min_charge_limit,}
		states[key].limit = math.max(item.min_charge_limit,states[key].limit or item.min_charge_limit)
	end
	return states[key]
end

local function get_normalized_original_charge(raw_charge,charge_type)
	if charge_type == 1 then return 1 end
	return math.max(1,math.min(item.max_normalized_charge,raw_charge or 0))
end

-- 蓝图等 maxcharges=0 的始终可用主动、以及透特之书（条上是启示资源，不是使用成本）：不要改上限、不要抽干。
local function ignores_active(collectible)
	if not collectible or collectible <= 0 then return true end
	if collectible == enums.Items.Book_of_Thoth then return true end
	local config = Isaac.GetItemConfig():GetCollectible(collectible)
	if not config then return true end
	return (config.MaxCharges or 0) <= 0
end

local function update_original_charge(state,collectible,current_max)
	local config = Isaac.GetItemConfig():GetCollectible(collectible)
	local raw_charge = current_max
	if raw_charge == nil and config then raw_charge = config.MaxCharges end
	raw_charge = math.max(0,raw_charge or 0)
	state.original_raw = raw_charge
	state.charge_type = config and config.ChargeType or 0
	state.original_charge = get_normalized_original_charge(raw_charge,state.charge_type)
end

local function get_total_capacity(player,state)
	local capacity = state.limit
	if state.charge_type ~= 1 and player:HasCollectible(CollectibleType.COLLECTIBLE_BATTERY) then
		capacity = capacity * 2
	end
	return capacity
end

local function clamp_primary_charge(player,state)
	local slot = ActiveSlot.SLOT_PRIMARY
	local active_charge = player:GetActiveCharge(slot)
	local battery_charge = player:GetBatteryCharge(slot)
	local total = active_charge + battery_charge
	local capacity = get_total_capacity(player,state)
	if REPENTOGON and player.GetActiveMaxCharge then
		local shown = player:GetActiveMaxCharge(slot)
		if type(shown) == "number" and shown > 0 then
			capacity = shown
			if state.charge_type ~= 1 and player:HasCollectible(CollectibleType.COLLECTIBLE_BATTERY) then
				capacity = shown * 2
			end
		end
	end
	local overflow = math.max(0,total - capacity)
	local kept_charge = math.min(total,capacity)
	local expected_active = math.min(kept_charge,state.limit)
	if overflow > 0 or active_charge ~= expected_active then player:SetActiveCharge(kept_charge,slot) end
	return overflow
end

function item.spawn_storm(player,count,spawn_energy)
	count = math.max(0,math.floor(count or 0))
	if count <= 0 then return end
	local rng = player:GetCollectibleRNG(item.entity)
	for _ = 1,count do
		local angle = math.random(3600)/10
		local color_id = rng:RandomInt(10)
		local laser = Isaac.Spawn(7,2,4,player.Position,Vector(0,0),player):ToLaser()
		local sprite = laser:GetSprite()
		sprite:Load("gfx/laser_coverer.anm2",true)
		sprite:Play("Laser"..(math.random(4) - 1),true)
		sprite.Color = item.tear_color_buff[color_id]
		laser.Angle = angle
		laser:SetTimeout(5)
		laser.TearFlags = laser.TearFlags | item.tear_flag_buff[color_id]
		laser.PositionOffset = Vector(0,0)
		laser.CollisionDamage = player.Damage * 0.7 + 3
		laser:SetOneHit(true)

		local end_position = player.Position + auxi.MakeVector(angle) * (100 + math.random(50))
		delay_buffer.addeffe(function(params)
			if not auxi.check_all_exists(params.player) then return end
			for i = 1,4 do
				local branch_angle = params.angle + 130 + 20 * i
				local branch_color_id = params.rng:RandomInt(10)
				local branch = Isaac.Spawn(7,2,4,params.end_position,Vector(0,0),params.player):ToLaser()
				local branch_sprite = branch:GetSprite()
				branch_sprite:Load("gfx/laser_coverer.anm2",true)
				branch_sprite:Play("Laser"..(math.random(4) - 1),true)
				branch_sprite.Color = item.tear_color_buff[branch_color_id]
				branch.Angle = branch_angle
				branch:SetTimeout(7)
				branch.TearFlags = branch.TearFlags | item.tear_flag_buff[branch_color_id]
				branch.PositionOffset = Vector(0,0)
				branch.CollisionDamage = params.player.Damage * 0.2 + 0.5
				branch:SetOneHit(true)
			end
		end,{player = player,rng = rng,angle = angle,end_position = end_position,},1)

		if spawn_energy then
			item.spawn_leak_laser(player,end_position,color_id)
			item.make_cable_tear(player,nil,end_position,auxi.MakeVector(angle) * (1.5 + math.random(1000)/1000),color_id)
		end
	end
end

function item.spawn_leak_laser(player,end_position,color_id)
	local offset = end_position - player.Position
	local distance = offset:Length()
	if distance <= 0 then return end
	local laser = Isaac.Spawn(
		EntityType.ENTITY_LASER,
		10,
		4,
		player.Position,
		Vector.Zero,
		player
	):ToLaser()
	local color = item.tear_color_buff[color_id]
	laser.AngleDegrees = offset:GetAngleDegrees()
	laser.TearFlags = BitSet128(0,0)
	laser.PositionOffset = Vector(0,-24)
	laser:SetTimeout(2)
	laser.Parent = player
	laser.CollisionDamage = player.Damage * 0.7 + 3
	laser:SetOneHit(true)
	laser:SetMaxDistance(distance)
	laser.Color = color
	laser:GetSprite().Color = color
end

function item.spawn_energy_balls(player,count)
	count = math.max(0,math.floor(count or 0))
	if count <= 0 then return end
	local rng = player:GetCollectibleRNG(item.entity)
	for _ = 1,count do
		local angle = rng:RandomInt(3600)/10
		local color_id = rng:RandomInt(10)
		local end_position = player.Position + auxi.MakeVector(angle) * (70 + rng:RandomInt(40))
		item.spawn_leak_laser(player,end_position,color_id)
		item.make_cable_tear(
			player,
			nil,
			end_position,
			auxi.MakeVector(angle) * (1.5 + rng:RandomFloat()),
			color_id
		)
	end
end

local failed_use_key = item.own_key.."failed_use"
local damage_leak_key = item.own_key.."damage_leak"
local warning_blink_color = Color(1,1,1,0.18,0.05,0.1,0.3)

local function queue_failed_use(player,collectible,storm_count)
	player:AnimateCollectible(collectible,"UseItem","PlayerPickupSparkle")
	player:GetData()[failed_use_key] = {
		timer = item.failed_use_delay,
		storm_count = storm_count,
	}
end

local function queue_damage_leak(player,storm_count)
	local pending = player:GetData()[damage_leak_key] or {
		storm_count = 0,
	}
	pending.timer = item.damage_warning_frames
	pending.elapsed = 0
	pending.next_blink = 0
	pending.blink_hidden = false
	pending.storm_count = pending.storm_count + storm_count
	player:GetData()[damage_leak_key] = pending
end

local function update_pending_effects(player)
	local data = player:GetData()
	local failed_use = data[failed_use_key]
	if failed_use then
		failed_use.timer = failed_use.timer - 1
		if failed_use.timer <= 0 then
			player:StopExtraAnimation()
			player:PlayExtraAnimation("Hit")
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_ISAAC_HURT_GRUNT,1,1,false,0,2)
			item.spawn_storm(player,failed_use.storm_count,true)
			data[failed_use_key] = nil
		end
	end

	local damage_leak = data[damage_leak_key]
	if damage_leak then
		damage_leak.timer = damage_leak.timer - 1
		damage_leak.elapsed = damage_leak.elapsed + 1
		if damage_leak.elapsed >= damage_leak.next_blink then
			damage_leak.blink_hidden = not damage_leak.blink_hidden
			local interval = math.max(1,4 - math.floor(damage_leak.elapsed / 5))
			damage_leak.next_blink = damage_leak.elapsed + interval
		end
		if damage_leak.blink_hidden then
			player:SetColor(warning_blink_color,1,100,false,false)
		end
		if damage_leak.timer <= 0 then
			item.spawn_energy_balls(player,damage_leak.storm_count)
			data[damage_leak_key] = nil
		end
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if not continue then
		save.elses[state_save_key] = {}
		save.elses[energy_save_key] = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[energy_save_key] = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local store = get_energy_store(false)
	local records = store and store.rooms and store.rooms[get_room_key()]
	if not records then return end

	local players = {}
	for i = 0,Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		players[tostring(player.InitSeed)] = player
	end
	for record_id,record in pairs(records) do
		local player = players[record.target_seed] or Isaac.GetPlayer(0)
		item.make_cable_tear(
			player,
			nil,
			Vector(record.position.X,record.position.Y),
			Vector.Zero,
			record.color_id,
			record_id
		)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = item.entity,
Function = function(_,player,collectible,count,last_number)
	if not auxi.has_have_coll(player,item.entity) then
		local key = get_player_state_key(player)
		if save.elses[state_save_key] then save.elses[state_save_key][key] = nil end
	end
end,
})

if REPENTOGON then
	table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_PLAYER_GET_ACTIVE_MAX_CHARGE, params = nil,
	Function = function(_,collectible,player,var_data,current_max)
		if not player or not auxi.has_have_coll(player,item.entity) then return end
		if ignores_active(collectible) then return end
		local slot = ActiveSlot.SLOT_PRIMARY
		if player:GetActiveItem(slot) ~= collectible then return end
		local desc = player:GetActiveItemDesc(slot)
		if desc and desc.Item == collectible and desc.VarData ~= var_data then return end
		local state = get_charge_state(player,collectible,true)
		update_original_charge(state,collectible,current_max)
		local cap = state.limit
		if type(current_max) == "number" and current_max > 0 then
			cap = math.min(cap, current_max)
		end
		local capacity = cap
		if state.charge_type ~= 1 and player:HasCollectible(CollectibleType.COLLECTIBLE_BATTERY) then
			capacity = cap * 2
		end
		local total_charge = player:GetActiveCharge(slot) + player:GetBatteryCharge(slot)
		local overflow = math.max(0,total_charge - capacity)
		if overflow > 0 then
			player:GetData()[cap_overflow_key] = math.max(
				player:GetData()[cap_overflow_key] or 0,
				overflow
			)
		end
		return cap
	end,
	})

	table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_USE_ITEM, params = nil,
	Function = function(_,collectible,rng,player,flags,slot,var_data)
		if not player or slot ~= ActiveSlot.SLOT_PRIMARY then return end
		if not auxi.has_have_coll(player,item.entity) then return end
		if player:GetActiveItem(slot) ~= collectible then return end
		if flags & UseFlag.USE_OWNED == 0 or flags & UseFlag.USE_VOID > 0 or flags & UseFlag.USE_MIMIC > 0 then return end
		if ignores_active(collectible) then return end

		local voice = require("Qing_Remaster_scripts.items.Item_Book_of_Voice")
		if collectible == voice.entity and voice.is_answer_use and voice.is_answer_use(player) then
			return
		end

		local state = get_charge_state(player,collectible,true)
		if not state.original_charge then update_original_charge(state,collectible,nil) end
		local frame = Game():GetFrameCount()
		if flags & UseFlag.USE_CARBATTERY > 0 then
			if state.block_use_frame == frame then return true end
			return
		end

		local chance = math.min(1,state.limit/math.max(1,state.original_charge))
		if rng:RandomFloat() < chance then
			state.block_use_frame = nil
			if state.original_charge <= 1 then
				local original_cost = state.charge_type == 1 and 1 or state.original_raw
				local excess_charge = math.max(0,state.limit - original_cost)
				item.spawn_storm(player,excess_charge,false)
			end
			return
		end

		local storm_count = player:GetActiveCharge(slot) + player:GetBatteryCharge(slot)
		player:SetActiveCharge(0,slot)
		state.limit = math.min(item.max_normalized_charge,state.limit + 2)
		state.block_use_frame = frame
		queue_failed_use(player,collectible,storm_count)
		return true
	end,
	})

	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
		Function = function(_,entity,amount,flags,source,countdown,extra_source)
		local player = entity:ToPlayer()
		if not player or amount <= 0 or not auxi.has_have_coll(player,item.entity) then return end
		local collectible = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY)
		if collectible <= 0 or ignores_active(collectible) then return end
		local state = get_charge_state(player,collectible,true)
		if not state.original_charge then update_original_charge(state,collectible,nil) end
		local old_limit = state.limit
		state.limit = math.max(item.min_charge_limit,state.limit - 2)
		if state.limit < old_limit then
			local overflow = clamp_primary_charge(player,state)
			player:GetData()[cap_overflow_key] = nil
			queue_damage_leak(player,overflow)
		end
	end,
	})

	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
	Function = function(_,player)
		update_pending_effects(player)
		if not auxi.has_have_coll(player,item.entity) then return end
		local collectible = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY)
		if collectible <= 0 or ignores_active(collectible) then return end
		local state = get_charge_state(player,collectible,true)
		if not state.original_charge then update_original_charge(state,collectible,nil) end
		local overflow = clamp_primary_charge(player,state)
		overflow = math.max(overflow,player:GetData()[cap_overflow_key] or 0)
		player:GetData()[cap_overflow_key] = nil
		item.spawn_energy_balls(player,overflow)
	end,
	})

	local success_font = Font()
	success_font:Load("font/luaminioutlined.fnt")

	table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
	Function = function(_,player,tp,cid,slot)
		if slot ~= ActiveSlot.SLOT_PRIMARY or not auxi.has_have_coll(player,item.entity) then return end
		if ignores_active(cid) then return end
		local voice = require("Qing_Remaster_scripts.items.Item_Book_of_Voice")
		if cid == voice.entity and voice.is_answer_use and voice.is_answer_use(player) then return end
		local state = get_charge_state(player,cid,true)
		if not state.original_charge then update_original_charge(state,cid,nil) end
		local chance = math.min(1,state.limit/math.max(1,state.original_charge))
		local text = tostring(math.floor(chance * 100 + 0.5)).."%"
		local pos = ui.PlayerActiveUIPos(player,slot,auxi.GetPlayerOrder(player),cid)
		local alpha = slot_render_holder.get_alpha()
		local text_width = success_font:GetStringWidthUTF8(text)
		gui.draw_ch(pos + Vector(12 - text_width,-16),text,1,1,KColor(1,1,1,alpha),true,success_font)
	end,
	})
end

local function get_charge_room(player)
	local slot = ActiveSlot.SLOT_PRIMARY
	local collectible = player:GetActiveItem(slot)
	if collectible <= 0 then return nil end
	local config = Isaac.GetItemConfig():GetCollectible(collectible)
	local max_charge = config and config.MaxCharges or 0
	if REPENTOGON and player.GetActiveMaxCharge then max_charge = player:GetActiveMaxCharge(slot) end
	if max_charge <= 0 then return nil end
	local capacity = max_charge
	if (not config or config.ChargeType ~= 1) and player:HasCollectible(CollectibleType.COLLECTIBLE_BATTERY) then
		capacity = capacity * 2
	end
	local before = player:GetActiveCharge(slot) + player:GetBatteryCharge(slot)
	return {
		slot = slot,
		before = before,
		capacity = capacity,
	}
end

local function can_receive_charge(player)
	local charge_room = get_charge_room(player)
	return charge_room ~= nil and charge_room.before < charge_room.capacity
end

local function reward(player)
	local charge_room = get_charge_room(player)
	if not charge_room or charge_room.before >= charge_room.capacity then return false end
	if REPENTOGON and player.AddActiveCharge then
		return player:AddActiveCharge(1,charge_room.slot,true,false,true) > 0
	end
	player:SetActiveCharge(charge_room.before + 1,charge_room.slot)
	return player:GetActiveCharge(charge_room.slot) + player:GetBatteryCharge(charge_room.slot) > charge_room.before
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local s = ent:GetSprite()
		local player = auxi.check_spawner_player(ent)
		-- SPRITE_TRAIL samples world position; mirror the old trail's proven -24 sprite offset.
		local render_position = ent.Position + Vector(0,-24)
		if auxi.check_all_exists(d[item.own_key.."effect"].tail) then
			d[item.own_key.."effect"].tail.Position = render_position
			d[item.own_key.."effect"].tail.Velocity = ent.Velocity
			d[item.own_key.."effect"].tail.PositionOffset = Vector.Zero
		else
			local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL,0,render_position,ent.Velocity,ent):ToEffect()
			d[item.own_key.."effect"].tail = q
			q.MinRadius = 0.05
			q.MaxRadius = 0.11
			q.SpriteScale = Vector(0.65,0.65)
			q.Parent = ent
			q.PositionOffset = Vector.Zero
			q.Color = Color(
				s.Color.R,s.Color.G,s.Color.B,0.45,
				s.Color.RO * 0.55,s.Color.GO * 0.55,s.Color.BO * 0.55
			)
			ent.Child = q
		end
		s.Rotation = ent.Velocity:GetAngleDegrees()
		ent.FallingSpeed = 0
		ent.Height = - 24
		if d[item.own_key.."effect"].target then
			local target = d[item.own_key.."effect"].target
			local target_distance = (target.Position - ent.Position):Length()
			local player = target:ToPlayer()
			if player and not can_receive_charge(player) then
				ent.Velocity = ent.Velocity * 0.5
			elseif target_distance < 20 then
				if player then 
					local ret = reward(player)
					if ret == true then 
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_SOUL_PICKUP,0.3,1,false,0,2)
						remove_energy_record(ent)
						ent:Remove()
						return
					end
				end
				ent.Velocity = ent.Velocity * 0.5
			else
				local outside_room = not Game():GetRoom():IsPositionInRoom(ent.Position,0)
				local attraction_range = outside_room and 1000 or 50
				if target_distance < attraction_range then
					local minimum_speed = outside_room and 6 or 2.5
					local speed = math.max(
						minimum_speed,
						math.min(6,target.Velocity:Length() * 1.2),
						ent.Velocity:Length() * 0.98
					)
					ent.Velocity = (target.Position - ent.Position):Normalized() * speed
				else
					ent.Velocity = ent.Velocity * 0.95
				end
			end
		end
		update_energy_record(ent)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local d = ent:GetData()
		if (d[item.own_key.."counter"] or 0) > 0 then d[item.own_key.."counter"] = d[item.own_key.."counter"] - 1 end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent,col,low)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local player = auxi.check_spawner_player(ent)
		local d = ent:GetData()
		if (d[item.own_key.."counter"] or 0) <= 0 and auxi.isenemies(col) and ent.State == -1 and ent:GetDropRNG():RandomFloat() > 0.9 then 
			d[item.own_key.."counter"] = 15 * 30
			local q = item.make_cable_tear(player,nil,ent.Position,ent.Velocity * 0.5)
		end
	end
end,
})

return item

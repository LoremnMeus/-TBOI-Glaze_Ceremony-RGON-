-- 焚火：按住攻击蓄力，松开后喷火。火焰几何仍由 flame_session 负责。
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local session = require("Qing_Remaster_scripts.items.incandescence_flame.flame_session")
local visual = require("Qing_Remaster_scripts.items.incandescence_flame.flame_visual")
local regions = require("Qing_Remaster_scripts.items.incandescence_flame.flame_regions")
local cycle = require("Qing_Remaster_scripts.items.incandescence_flame.flame_cycle")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local player_visual_render = require("Qing_Remaster_scripts.callbacks.player_visual_render_holder")

local BAR_ANM2 = "gfx/effects/chargebar/chargebar_Flame.anm2"
local SHOOT_ACTIONS = {
	ButtonAction.ACTION_SHOOTLEFT,
	ButtonAction.ACTION_SHOOTRIGHT,
	ButtonAction.ACTION_SHOOTUP,
	ButtonAction.ACTION_SHOOTDOWN,
}

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Incandescence_Flame,
	own_key = "Item_Incandescence_Flame_",
}

local driver_hash = nil
local drew_behind = false

local function state_of(player)
	local data = player:GetData()
	local key = item.own_key .. "state"
	local st = data[key]
	if type(st) ~= "table" then
		st = cycle.blank()
		data[key] = st
	end
	return st
end

local function ent_key(ent)
	if GetPtrHash then
		return GetPtrHash(ent)
	end
	return tostring(ent.Type) .. ":" .. tostring(ent.InitSeed)
end

local function enemy_radius(ent)
	local size = ent.Size or 0
	if ent.SizeMulti and ent.SizeMulti.X then
		size = size * ent.SizeMulti.X
	end
	if size < 0 then
		size = 0
	end
	return size
end

local function is_flame_breakable_ent(ent)
	if not ent then
		return false
	end
	local t = ent.Type
	if t == EntityType.ENTITY_SHOPKEEPER then
		return true
	end
	if EntityType.ENTITY_MOVABLE_TNT and t == EntityType.ENTITY_MOVABLE_TNT then
		return true
	end
	-- Fallback if enum missing in older stubs.
	if t == 292 then
		return true
	end
	return false
end

local function hurt_grids(player, st, built, do_hit)
	local room = Game():GetRoom()
	if not room or not room.GetGridSize then
		return
	end
	local size = room:GetGridSize()
	for i = 0, size - 1 do
		local grid = room:GetGridEntity(i)
		if grid and grid.Position then
			local gt = grid:GetType()
			if regions.overlaps_circle(built, grid.Position.X, grid.Position.Y, 20) then
				if gt == GridEntityType.GRID_SPIDERWEB then
					-- Burn webs away once per spray contact.
					if cycle.mark_burn(st, "gridweb:" .. tostring(i)) and grid.Destroy then
						grid:Destroy(true)
					end
				elseif do_hit and (gt == GridEntityType.GRID_TNT or gt == GridEntityType.GRID_POOP) then
					if grid.Hurt then
						grid:Hurt(1)
					end
				end
			end
		end
	end
end

local function hurt(player, st, do_hit)
	local built = session.state().region_build
	if not built or not Isaac.GetRoomEntities then
		return
	end
	local dmg = (player.Damage or 0) * cycle.HIT_SCALE
	local burn_dmg = (player.Damage or 0) * cycle.BURN_SCALE
	local ref = EntityRef(player)
	local ents = Isaac.GetRoomEntities()
	for i = 1, #ents do
		local ent = ents[i]
		if ent and ent.Position and not (ent.IsDead and ent:IsDead()) then
			local enemy = auxi.isenemies(ent)
			local breakable = is_flame_breakable_ent(ent)
			if (enemy or breakable)
				and regions.overlaps_circle(built, ent.Position.X, ent.Position.Y, enemy_radius(ent)) then
				if enemy then
					if cycle.mark_burn(st, ent_key(ent)) and ent.AddBurn then
						ent:AddBurn(ref, cycle.BURN_FRAMES, burn_dmg)
					end
				end
				if do_hit and ent.TakeDamage then
					local flags = DamageFlag.DAMAGE_FIRE or 0
					if breakable and not enemy and DamageFlag.DAMAGE_IGNORE_ARMOR then
						flags = flags | DamageFlag.DAMAGE_IGNORE_ARMOR
					end
					ent:TakeDamage(dmg, flags, ref, 0)
				end
			end
		end
	end
	hurt_grids(player, st, built, do_hit)
end

local function update()
	if Isaac.IsInGame and not Isaac.IsInGame() then
		return
	end
	local game = Game()
	if not game or not game.GetNumPlayers then
		return
	end
	local busy = session.state().phase ~= "idle"
	local driving = false
	local saw_driver = false
	for i = 0, game:GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		if player and player.HasCollectible and player:HasCollectible(item.entity) and not (player.IsDead and player:IsDead()) then
			local st = state_of(player)
			local hash = GetPtrHash and GetPtrHash(player) or i
			local flags = cycle.step(st, (not busy) or hash == driver_hash)
			if flags.start then
				driver_hash = hash
				busy = true
				if st.has_dir then
					session.note_dir(st.dir_x, st.dir_y)
				end
				session.clear_forced_dir()
				session.fire_continuous(player)
			end
			if (st.phase == "fire" or st.phase == "fade") and hash ~= driver_hash and session.state().phase == "idle" then
				cycle.note_idle(st, true)
			end
			if (st.phase == "fire" or st.phase == "fade") and hash == driver_hash then
				saw_driver = true
				driving = true
				session.set_item_owner(true)
				session.tick(player)
				hurt(player, st, flags.hit)
				if flags.stop then
					session.stop()
				end
				if cycle.note_idle(st, session.state().phase == "idle") then
					driver_hash = nil
					saw_driver = false
					driving = false
					busy = false
				end
			end
		end
	end
	if driver_hash ~= nil and not saw_driver then
		session.clear("owner_lost")
		driver_hash = nil
		driving = false
	end
	session.set_item_owner(driving)
end

local function draw_flame()
	if Isaac.IsInGame and not Isaac.IsInGame() then
		return false
	end
	local room = Game():GetRoom()
	if room and room.GetRenderMode and RenderMode and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return false
	end
	if not session.item_owner() or session.state().phase == "idle" then
		return false
	end
	visual.render(session.state(), session.config())
	return true
end

local function flame_behind_active(player)
	if not session.draws_behind_player() or not player then
		return false
	end
	local hash = GetPtrHash and GetPtrHash(player) or nil
	return hash ~= nil and hash == driver_hash
end

local function render_behind(ctx)
	local player = ctx and ctx.player
	if not flame_behind_active(player) then
		return
	end
	if draw_flame() then
		drew_behind = true
	end
end

player_visual_render.register({
	id = "incandescence_flame",
	behind = {
		active = flame_behind_active,
		render = render_behind,
	},
})

local function render()
	local skip = drew_behind
	drew_behind = false
	if skip then
		return
	end
	draw_flame()
end

local function on_room()
	session.on_room_change()
	driver_hash = nil
	drew_behind = false
	session.set_item_owner(false)
	local game = Game()
	if not game or not game.GetNumPlayers then
		return
	end
	for i = 0, game:GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		if player and player.HasCollectible and player:HasCollectible(item.entity) then
			cycle.on_room(state_of(player))
		end
	end
end

local function attack_held(player)
	local ctrl = player.ControllerIndex or 0
	for i = 1, #SHOOT_ACTIONS do
		if Input.IsActionPressed(SHOOT_ACTIONS[i], ctrl) then
			return true
		end
	end
	-- MouseControl: left click fires; ACTION_SHOOT* often stays unpressed.
	if ctrl == 0 and Options and Options.MouseControl and Input.IsMouseBtnPressed(0) then
		return true
	end
	return false
end

local function aim_axes(player, held)
	local aim = player.GetAimDirection and player:GetAimDirection() or nil
	local ax = aim and aim.X or 0
	local ay = aim and aim.Y or 0
	if held and (ax * ax + ay * ay) < 1e-6
		and (player.ControllerIndex or 0) == 0
		and Options and Options.MouseControl
		and auxi.mouse_world_pos
		and player.Position then
		local delta = auxi.mouse_world_pos() - player.Position
		if delta:Length() > 1 then
			ax, ay = delta.X, delta.Y
		end
	end
	return ax, ay
end

local function sample_player_input(_, player)
	if not player or not player.HasCollectible or not player:HasCollectible(item.entity) then
		return
	end
	local held = attack_held(player)
	local ax, ay = aim_axes(player, held)
	cycle.sample_input(state_of(player), held, ax, ay)
end

local function render_charge_bar(_, player)
	local room = Game():GetRoom()
	if room and room.GetRenderMode and RenderMode and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	if not auxi.has_have_coll(player, item.entity) then
		return
	end
	local st = state_of(player)
	local charging = st.phase == "charge" or st.phase == "ready"
	local charge = st.charge or 0
	Charging_Bar_holder.render_me(player, {
		name1 = item.own_key .. "bar",
		name2 = item.own_key .. "bar_sprite",
		name3 = item.own_key .. "bar",
		loadname = BAR_ANM2,
		check1 = function()
			return charging and (charge > 0 or st.phase == "ready")
		end,
		check2 = function()
			return st.phase == "ready"
		end,
		check3 = function()
			return math.ceil(charge / cycle.CHARGE_FRAMES * 100)
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = sample_player_input,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = update,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_RENDER,
	params = nil,
	Function = render_charge_bar,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = render,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = on_room,
})

Charging_Bar_holder.register_bar({id = item.own_key .. "bar", owner = {type = "collectible", collectible = item.entity}})
return item

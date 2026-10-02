local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local particle = require("Qing_Remaster_scripts.cards.art.art_particle")
local art_craft = require("Qing_Remaster_scripts.cards.art.art_craft")

local overlay = Sprite()
overlay:Load("gfx/cards/Tarot_Art_effect.anm2", true)
overlay:Play("Idle", true)

local item = {
	pre_ToCall = {}, ToCall = {}, post_ToCall = {}, myToCall = {},
	entity = enums.Cards.Art,
	own_key = "Thoth_cd14_Art_",
	render_counter = 0,
}

local function player_key(player)
	local data = player and player:GetData()
	return tostring((data and data.__Index) or (player and player.ControllerIndex) or 0)
end

local function until_table()
	save.elses = save.elses or {}
	local value = save.elses[item.own_key.."until"]
	if type(value) ~= "table" then value = {} save.elses[item.own_key.."until"] = value end
	return value
end

local function craft_save_table()
	save.elses = save.elses or {}
	local value = save.elses[item.own_key.."craft"]
	if type(value) ~= "table" then value = {} save.elses[item.own_key.."craft"] = value end
	return value
end

local function effect_active(player)
	return player ~= nil and Game():GetFrameCount() < (until_table()[player_key(player)] or 0)
end

local function any_effect_active()
	for i = 0, Game():GetNumPlayers() - 1 do
		if effect_active(Game():GetPlayer(i)) then return true end
	end
	return false
end

table.insert(item.myToCall, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
	Function = function(_, continued)
	save.elses = save.elses or {}
	if not continued then
		save.elses[item.own_key.."until"] = {}
		save.elses[item.own_key.."boss_paid"] = {}
		save.elses[item.own_key.."craft"] = {}
	end
	until_table()
	local persisted_craft = craft_save_table()
	save.elses[item.own_key.."boss_paid"] = save.elses[item.own_key.."boss_paid"] or {}
	overlay.Color = Color(1, 1, 1, 0)
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		art_craft.reset_runtime(player, persisted_craft[player_key(player)])
	end
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
	Function = function(_, cardtype, player, use_flags)
	-- Skip the synthetic second fire from Car Battery-style re-entry.
	if use_flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return
	end
	-- Game():GetFrameCount() is 30 Hz → N seconds = N * 30 frames.
	local duration = 30 * 30
	local d = player:GetData()
	if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
		duration = 45 * 30
	end
	local active_until = until_table()
	local key = player_key(player)
	active_until[key] = math.max(active_until[key] or 0, Game():GetFrameCount() + duration)
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
	Function = function(_, entity)
	if not any_effect_active() then return end
	local npc = entity:ToNPC()
	if not npc then return end
	local count = 1
	if npc:IsBoss() then
		local paid = save.elses[item.own_key.."boss_paid"] or {}
		local key = tostring(npc.InitSeed)
		if paid[key] then return end
		paid[key] = true
		save.elses[item.own_key.."boss_paid"] = paid
		count = 3
	elseif npc:IsChampion() then count = 2 end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if effect_active(player) then
			for _ = 1, count do art_craft.spawn_pigment(player, npc.Position + auxi.random_v2() * 8) end
		end
	end
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
	Function = function(_, player)
	art_craft.tick(player, effect_active(player))
	if art_craft.is_dirty(player) then
		craft_save_table()[player_key(player)] = art_craft.snapshot(player)
		art_craft.clear_dirty(player)
	end
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
	Function = function()
	for i = 0, Game():GetNumPlayers() - 1 do art_craft.on_new_room(Game():GetPlayer(i)) end
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = particle.VARIANT,
	Function = function(_, effect) particle.update(effect) end})

-- Glow behind ghost body: PRE draws halo, return nil so engine still draws host.
table.insert(item.ToCall, {CallBack = ModCallbacks.MC_PRE_EFFECT_RENDER, params = particle.VARIANT,
	Function = function(_, effect, offset)
	particle.render_ghost_glow(effect, offset)
	return nil
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
	Function = function(_, pickup) art_craft.tick_pickup_bounce(pickup) end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
	Function = function()
	local target = any_effect_active() and Color(1, 1, 1, 1, 0.3, 0.3, 0.3) or Color(1, 1, 1, 0, 0, 0, 0)
	overlay.Color = auxi.AddColor(overlay.Color, target, 0.9, 0.1)
	if overlay.Color.A > 0.05 then
		local size = auxi.GetScreenSize()
		overlay:Render(auxi.GetScreenCenter() / 2 - Game().ScreenShakeOffset, Vector.Zero, Vector.Zero)
		overlay:Update()
		overlay.Rotation = overlay.Rotation - 0.3
		overlay.Scale = Vector(size.X / 205 * (1 + 0.3 * math.sin(math.rad(item.render_counter + 81))), size.Y / 205 * (1 + 0.3 * math.cos(0.8 * math.rad(item.render_counter + 145))))
	end
	item.render_counter = item.render_counter + 0.1
end})

return item

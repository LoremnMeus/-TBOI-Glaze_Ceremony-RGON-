local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")
local options = require("Qing_Remaster_scripts.others.Option_Index_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Universe,
	own_key = "Thoth_cd21_Uni_",
	place_radius = 85,
	touch_dist = 28,
	alpha_near = 0.85,
	alpha_far = 0.22,
	alpha_near_dist = 40,
	alpha_far_dist = 160,
	bob_amp = 6,
	flame_anm2 = "gfx/mimics/Iliaster/granel_flame.anm2",
	flame_sheet = "gfx/effects/flames/flame4.png", -- 原生紫火，不染色
}

local COSMIC_POOL = {
	588, 589, 590, 591, 592, 593, 594, 595, 596, 597, 598,
	233, 651, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 318,
	enums.Items.Pendulum_Star,
}

local function session_of(player)
	return player:GetData()[item.own_key.."session"]
end

local function clear_session(player)
	local sess = session_of(player)
	if not sess then return end
	for _, ph in ipairs(sess.entities or {}) do
		if auxi.check_all_exists(ph) then
			local d = ph:GetData()
			if auxi.check_all_exists(d[item.own_key.."flame"]) then
				d[item.own_key.."flame"]:Remove()
			end
			if auxi.check_all_exists(d[item.own_key.."eid"]) then
				d[item.own_key.."eid"]:Remove()
			end
			ph:Remove()
		end
	end
	player:GetData()[item.own_key.."session"] = nil
end

local function held(player)
	local out = {}
	local cfg = Isaac.GetItemConfig():GetCollectibles()
	for id = 1, cfg.Size - 1 do
		if player:GetCollectibleNum(id, true) > 0 then
			out[#out + 1] = id
		end
	end
	return out
end

local function take(list, n, rng)
	for i = #list, 2, -1 do
		local j = rng:RandomInt(i) + 1
		list[i], list[j] = list[j], list[i]
	end
	local out = {}
	for i = 1, math.min(n, #list) do
		out[i] = list[i]
	end
	return out
end

local function cosmic(rng, avoid)
	for _ = 1, #COSMIC_POOL * 2 do
		local id = COSMIC_POOL[rng:RandomInt(#COSMIC_POOL) + 1]
		if id and not avoid[id] and Isaac.GetItemConfig():GetCollectible(id) then
			return id
		end
	end
	return CollectibleType.COLLECTIBLE_ZODIAC
end

local function reward(player, cloth, rng)
	local room = Game():GetRoom()
	local avoid = {}
	local id = cosmic(rng, avoid)
	avoid[id] = true
	local q = Isaac.Spawn(5, 100, id, room:FindFreePickupSpawnPosition(player.Position, 20, true), Vector.Zero, player):ToPickup()
	if cloth then
		local q2 = Isaac.Spawn(5, 100, cosmic(rng, avoid), room:FindFreePickupSpawnPosition(player.Position + Vector(40, 0), 20, true), Vector.Zero, player):ToPickup()
		local idx = options.find_a_new_index()
		q.OptionsPickupIndex = idx
		q2.OptionsPickupIndex = idx
	end
end

local function dist_alpha(dist)
	if dist <= item.alpha_near_dist then return item.alpha_near end
	if dist >= item.alpha_far_dist then return item.alpha_far end
	local t = (dist - item.alpha_near_dist) / (item.alpha_far_dist - item.alpha_near_dist)
	return item.alpha_near + (item.alpha_far - item.alpha_near) * t
end

local function flicker(base_a, frame, seed)
	local wobble = 0.06 * math.sin((frame + seed) * 0.055) + 0.035 * math.sin((frame + seed) * 0.12)
	return math.max(0.08, math.min(1, base_a + wobble))
end

local function place_positions(player, count)
	local out = {}
	for i = 1, count do
		local ang = -90 + (i - 1) * (360 / count)
		out[i] = player.Position + auxi.MakeVector(ang) * item.place_radius
	end
	return out
end

local function spawn_flame(pos, player)
	local flame = auxi.fire_nil(pos, Vector(0, 0), {cooldown = 99999, player = player})
	local d = flame:GetData()
	d.nil_mode = "card_21_universe_flame"
	d[item.own_key.."flame_tag"] = true
	d.skip_nil_distance_cull = true
	d[Nil_holder.own_key.."work"] = function() return true end
	d.EID_Hide = true
	local s = flame:GetSprite()
	s:Load(item.flame_anm2, true)
	s:ReplaceSpritesheet(0, item.flame_sheet)
	s:LoadGraphics()
	s:Play("Idle", true)
	s.Scale = Vector(0.55, 0.7)
	flame.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	flame.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	flame.SortingLayer = 0
	return flame
end

local function spawn_eid_anchor(pos, colid)
	if not EID or not colid then return nil end
	local q = Isaac.Spawn(1000, enums.Entities.EID_Descriptier, 0, pos, Vector(0, 0), nil)
	q.Visible = false
	q.Size = 22
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	local d = q:GetData()
	d[item.own_key.."eid_anchor"] = true
	local desc = EID:getDescriptionObj(5, 100, colid, nil, true)
	if desc then
		d.EID_Description = desc
	end
	return q
end

local function remove_eid_anchor(d)
	if not d then return end
	if auxi.check_all_exists(d[item.own_key.."eid"]) then
		d[item.own_key.."eid"]:Remove()
	end
	d[item.own_key.."eid"] = nil
end

local function spawn_phantom(player, colid, home)
	local q = auxi.fire_nil(home, Vector(0, 0), {cooldown = 99999, player = player})
	local s = q:GetSprite()
	auxi.load_item(colid, {sprite = s})
	local d = q:GetData()
	d.nil_mode = "card_21_universe"
	d.skip_nil_distance_cull = true
	d[item.own_key.."id"] = colid
	d[item.own_key.."owner"] = player
	d[item.own_key.."home"] = Vector(home.X, home.Y)
	d[item.own_key.."seed"] = math.random(1000)
	d[item.own_key.."flame"] = spawn_flame(home, player)
	d[item.own_key.."eid"] = spawn_eid_anchor(home, colid)
	d.EID_Hide = true
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	s.Color = Color(1, 1, 1, 0.45, 0.18, 0.08, 0.28)
	return q
end

local function spawn_session_phantoms(player)
	local sess = session_of(player)
	if not sess or not sess.ids or #sess.ids == 0 then return end
	-- 换房重建前清掉旧实体，避免重复虚影
	for _, ph in ipairs(sess.entities or {}) do
		if auxi.check_all_exists(ph) then
			local d = ph:GetData()
			if auxi.check_all_exists(d[item.own_key.."flame"]) then d[item.own_key.."flame"]:Remove() end
			remove_eid_anchor(d)
			ph:Remove()
		end
	end
	local homes = place_positions(player, #sess.ids)
	sess.entities = {}
	for i, id in ipairs(sess.ids) do
		sess.entities[#sess.entities + 1] = spawn_phantom(player, id, homes[i])
	end
end

local function begin_sacrifice(player, ent, colid)
	local sess = session_of(player)
	if not sess or sess.resolving then return end
	if player:GetCollectibleNum(colid, true) <= 0 then
		local d = ent:GetData()
		if auxi.check_all_exists(d[item.own_key.."flame"]) then d[item.own_key.."flame"]:Remove() end
		remove_eid_anchor(d)
		ent:Remove()
		return
	end
	sess.resolving = true
	local rng, cloth = sess.rng, sess.cloth
	-- 立刻收起全部虚影；道具失去改走命运式举起表演
	clear_session(player)
	player:AnimateCollectible(colid, "LiftItem", "PlayerPickup")
	delay_buffer.addeffe(function()
		if not auxi.check_all_exists(player) then return end
		if not player:IsHoldingItem() then return end
		player:AnimateCollectible(colid, "HideItem", "PlayerPickup")
		local before = player:GetCollectibleNum(colid, true)
		if before <= 0 then return end
		player:RemoveCollectible(colid)
		if player:GetCollectibleNum(colid, true) >= before then return end
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF, 1, 1, false, 0, 2)
		Isaac.Spawn(1000, 16, 2, player.Position, Vector(0, 0), player)
		Isaac.Spawn(1000, 16, 1, player.Position, Vector(0, 0), player)
		reward(player, cloth, rng)
	end, {}, 15)
end

Nil_holder.register("card_21_universe_flame", {
	detect = function(d) return d[item.own_key.."flame_tag"] end,
	update = function(ent, d, s)
		if s and s.Update then s:Update() end
	end,
})

Nil_holder.register("card_21_universe", {
	detect = function(d) return d[item.own_key.."id"] ~= nil end,
	update = function(ent, d, s)
		local player = d[item.own_key.."owner"]
		if not auxi.check_all_exists(player) then
			if auxi.check_all_exists(d[item.own_key.."flame"]) then d[item.own_key.."flame"]:Remove() end
			remove_eid_anchor(d)
			ent:Remove()
			return
		end
		local sess = session_of(player)
		if not sess then
			if auxi.check_all_exists(d[item.own_key.."flame"]) then d[item.own_key.."flame"]:Remove() end
			remove_eid_anchor(d)
			ent:Remove()
			return
		end

		local home = d[item.own_key.."home"] or ent.Position
		local bob = math.sin((Game():GetFrameCount() + (d[item.own_key.."seed"] or 0)) * 0.08) * item.bob_amp
		ent.Position = home
		ent.Velocity = Vector.Zero
		ent.PositionOffset = Vector(0, bob - 10)

		local flame = d[item.own_key.."flame"]
		if auxi.check_all_exists(flame) then
			flame.Position = home
			flame.Velocity = Vector.Zero
			flame.PositionOffset = Vector(0, bob - 4)
			if flame:GetSprite().Update then flame:GetSprite():Update() end
		end

		local eid = d[item.own_key.."eid"]
		if auxi.check_all_exists(eid) then
			eid.Position = home
			eid.Velocity = Vector.Zero
			eid.PositionOffset = Vector(0, bob - 10)
		elseif EID and d[item.own_key.."id"] then
			d[item.own_key.."eid"] = spawn_eid_anchor(home, d[item.own_key.."id"])
		end

		local dist = (player.Position - home):Length()
		local a = flicker(dist_alpha(dist), Game():GetFrameCount(), d[item.own_key.."seed"] or 0)
		s.Color = Color(1, 1, 1, a, 0.18, 0.08, 0.28)
		if auxi.check_all_exists(flame) then
			-- 只调透明度，保留 flame4 原生紫色
			flame:GetSprite().Color = Color(1, 1, 1, a * 0.9, 0, 0, 0)
		end

		if dist <= item.touch_dist and player:IsExtraAnimationFinished() and not sess.resolving then
			begin_sacrifice(player, ent, d[item.own_key.."id"])
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	Function = function()
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if session_of(player) then
				spawn_session_phantoms(player)
			end
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = item.entity,
	Function = function(_, cardtype, player, useFlags)
		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			return
		end
		clear_session(player)
		local rng = auxi.rng_for_sake(player:GetCardRNG(item.entity))
		local ids = take(held(player), 3, rng)
		if #ids == 0 then
			Isaac.Spawn(5, 300, item.entity, player.Position, Vector.Zero, player)
			return
		end
		player:GetData()[item.own_key.."session"] = {
			ids = ids,
			rng = rng,
			cloth = player:GetData().tarot_cloth_used == cardtype,
			entities = {},
			resolving = false,
		}
		spawn_session_phantoms(player)
	end,
})

return item

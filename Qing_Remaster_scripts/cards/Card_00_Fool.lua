local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Fool,
	own_key = "Thoth_cd0_Foo_",
	sample_cap = 40,
	-- 固定环半径（相对使用时玩家位置），之后不再跟随
	place_radius = 85,
	touch_dist = 28,
	-- 距离 → 透明度（近实远虚，类似死亡证明层思路）
	alpha_near = 0.85,
	alpha_far = 0.22,
	alpha_near_dist = 40,
	alpha_far_dist = 160,
	bob_amp = 6,
	flame_anm2 = "gfx/mimics/Iliaster/granel_flame.anm2",
	flame_sheet = "gfx/effects/flames/flame3.png",
}

local function session_of(player)
	return player:GetData()[item.own_key.."session"]
end

local function clear_session(player)
	local sess = session_of(player)
	if not sess then return end
	for _, ph in ipairs(sess.phantoms or {}) do
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

local function sample_summonable(pool_type, rng, avoid)
	local itempool = Game():GetItemPool()
	local config = Isaac.GetItemConfig()
	for _ = 1, item.sample_cap do
		local seed = rng:GetSeed()
		local colid = itempool:GetCollectible(pool_type, false, seed)
		rng:Next()
		local info = config:GetCollectible(colid)
		if info and (info.Tags & ItemConfig.TAG_SUMMONABLE) == ItemConfig.TAG_SUMMONABLE and not avoid[colid] then
			return colid
		end
	end
	return nil
end

local function dist_alpha(dist)
	if dist <= item.alpha_near_dist then return item.alpha_near end
	if dist >= item.alpha_far_dist then return item.alpha_far end
	local t = (dist - item.alpha_near_dist) / (item.alpha_far_dist - item.alpha_near_dist)
	return item.alpha_near + (item.alpha_far - item.alpha_near) * t
end

-- 在 MC_POST_EFFECT_UPDATE（游戏帧）里推进；系数按 30fps 约 0.3–0.6Hz，避免过快闪烁
local function flicker(base_a, frame, seed)
	local wobble = 0.06 * math.sin((frame + seed) * 0.055) + 0.035 * math.sin((frame + seed) * 0.12)
	return math.max(0.08, math.min(1, base_a + wobble))
end

local function place_positions(player, count)
	local out = {}
	-- 使用瞬间固定在玩家周围几何环上；虚影不是掉落物，不要 snap 到可掉落格
	for i = 1, count do
		local ang = -90 + (i - 1) * (360 / count)
		out[i] = player.Position + auxi.MakeVector(ang) * item.place_radius
	end
	return out
end

local function spawn_flame(pos, player)
	local flame = auxi.fire_nil(pos, Vector(0, 0), {cooldown = 99999, player = player})
	local d = flame:GetData()
	d.nil_mode = "card_00_fool_flame"
	d[item.own_key.."flame_tag"] = true
	d.skip_nil_distance_cull = true
	d[Nil_holder.own_key.."work"] = function() return true end
	-- 火焰不参与 EID：隐藏以免挡住道具虚影说明
	d.EID_Hide = true
	local s = flame:GetSprite()
	s:Load(item.flame_anm2, true)
	s:ReplaceSpritesheet(0, item.flame_sheet)
	s:LoadGraphics()
	s:Play("Idle", true)
	-- 蓝色火焰
	s.Color = Color(0.35, 0.65, 1, 0.75, 0.05, 0.2, 0.55)
	s.Scale = Vector(0.55, 0.7)
	flame.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	flame.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	flame.SortingLayer = 0
	return flame
end

-- 虚影本体是 MeusNil（不在 EID.effectList）。挂已登记的 EID_Descriptier 锚点承载说明。
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
	d.nil_mode = "card_00_fool"
	d.skip_nil_distance_cull = true
	d[item.own_key.."effect"] = true
	d[item.own_key.."colid"] = colid
	d[item.own_key.."owner"] = player
	d[item.own_key.."home"] = Vector(home.X, home.Y)
	d[item.own_key.."seed"] = math.random(1000)
	d[item.own_key.."fading"] = false
	d[item.own_key.."flame"] = spawn_flame(home, player)
	d[item.own_key.."eid"] = spawn_eid_anchor(home, colid)
	-- 虚影自身不进 EID 扫描，避免与锚点重复
	d.EID_Hide = true
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	s.Color = Color(1, 1, 1, 0.45, 0.1, 0.15, 0.25)
	return q
end

local function begin_select(player, ent, colid)
	local sess = session_of(player)
	if not sess or sess.selected then return end
	sess.selected = true
	sess.selecting = true
	-- 其余虚影淡出
	for _, ph in ipairs(sess.phantoms or {}) do
		if auxi.check_all_exists(ph) and GetPtrHash(ph) ~= GetPtrHash(ent) then
			ph:GetData()[item.own_key.."fading"] = true
		end
	end
	-- 圣光
	local flash = Isaac.Spawn(1000, EffectVariant.CRACK_THE_SKY, 0, ent.Position, Vector(0, 0), player):ToEffect()
	flash.CollisionDamage = 0
	flash:GetSprite().Scale = Vector(1.35, 1.1)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SUPERHOLY, 1, 1, false, 0, 2)

	-- 选中虚影立刻藏起，改由玩家举起道具表演
	local d = ent:GetData()
	remove_eid_anchor(d)
	if auxi.check_all_exists(d[item.own_key.."flame"]) then
		d[item.own_key.."flame"]:Remove()
	end
	ent:Remove()

	player:AnimateCollectible(colid, "LiftItem", "PlayerPickup")
	delay_buffer.addeffe(function()
		if not auxi.check_all_exists(player) then return end
		if player:IsHoldingItem() then
			player:AnimateCollectible(colid, "HideItem", "PlayerPickup")
		end
		Game():GetItemPool():RemoveCollectible(colid)
		player:AddItemWisp(colid, player.Position, true)
		local s2 = session_of(player)
		if s2 then s2.selecting = false end
	end, {}, 20)
end

Nil_holder.register("card_00_fool_flame", {
	detect = function(d) return d[item.own_key.."flame_tag"] end,
	update = function(ent, d, s)
		-- work 跳过默认运动；火焰由 phantom 驱动位置
		if s and s.Update then s:Update() end
	end,
})

Nil_holder.register("card_00_fool", {
	detect = function(d) return d[item.own_key.."effect"] end,
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

		local flame = d[item.own_key.."flame"]
		if d[item.own_key.."fading"] then
			remove_eid_anchor(d)
			s.Color = auxi.AddColor(s.Color, Color(1, 1, 1, 0), 0.82, 0.18)
			if auxi.check_all_exists(flame) then
				flame:GetSprite().Color = auxi.AddColor(flame:GetSprite().Color, Color(0.35, 0.65, 1, 0), 0.82, 0.18)
			end
			if s.Color.A < 0.06 then
				if auxi.check_all_exists(flame) then flame:Remove() end
				ent:Remove()
			end
			return
		end

		if sess.selected then
			d[item.own_key.."fading"] = true
			remove_eid_anchor(d)
			return
		end

		local home = d[item.own_key.."home"] or ent.Position
		local bob = math.sin((Game():GetFrameCount() + (d[item.own_key.."seed"] or 0)) * 0.08) * item.bob_amp
		ent.Position = home
		ent.Velocity = Vector(0, 0)
		ent.PositionOffset = Vector(0, bob - 10)

		if auxi.check_all_exists(flame) then
			flame.Position = home
			flame.Velocity = Vector(0, 0)
			-- Y 负向上；相对原先再抬约 10px
			flame.PositionOffset = Vector(0, bob - 4)
			if flame:GetSprite().Update then flame:GetSprite():Update() end
		end

		local eid = d[item.own_key.."eid"]
		if auxi.check_all_exists(eid) then
			eid.Position = home
			eid.Velocity = Vector(0, 0)
			eid.PositionOffset = Vector(0, bob - 10)
		elseif EID and d[item.own_key.."colid"] then
			d[item.own_key.."eid"] = spawn_eid_anchor(home, d[item.own_key.."colid"])
		end

		local dist = (player.Position - home):Length()
		local a = flicker(dist_alpha(dist), Game():GetFrameCount(), d[item.own_key.."seed"] or 0)
		-- 半透明幽灵白，不用品质染色
		s.Color = Color(1, 1, 1, a, 0.12, 0.18, 0.28)
		if auxi.check_all_exists(flame) then
			flame:GetSprite().Color = Color(0.35, 0.65, 1, a * 0.9, 0.05, 0.2, 0.55)
		end

		if dist <= item.touch_dist and player:IsExtraAnimationFinished() and not sess.selecting then
			begin_select(player, ent, d[item.own_key.."colid"])
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	for i = 0, Game():GetNumPlayers() - 1 do
		clear_session(Game():GetPlayer(i))
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_, cardtype, player, useFlags)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return
	end
	clear_session(player)
	local d = player:GetData()
	local rng = auxi.rng_for_sake(player:GetCardRNG(item.entity))
	local cnt = 5
	if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then cnt = 8 end
	local itempool = Game():GetItemPool()
	local typ = itempool:GetPoolForRoom(Game():GetRoom():GetType(), Game():GetLevel():GetCurrentRoomDesc().SpawnSeed)
	if typ == -1 then typ = 0 end

	local homes = place_positions(player, cnt)
	local avoid = {}
	local phantoms = {}
	for i = 1, cnt do
		local colid = sample_summonable(typ, rng, avoid)
		if colid then
			avoid[colid] = true
			phantoms[#phantoms + 1] = spawn_phantom(player, colid, homes[i])
		end
	end
	if #phantoms == 0 then
		player:AnimateSad()
		return
	end
	d[item.own_key.."session"] = {
		phantoms = phantoms,
		selected = false,
		selecting = false,
	}
end,
})

return item

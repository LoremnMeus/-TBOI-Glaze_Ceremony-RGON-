-- 精神失序：进房错认一个掉落物 / 敌人 / 已有被动，同时只存在一个错误事实
-- 视觉：全屏 Mental Desync（短）、假实体轻 glitch、揭穿 Reality Tear、离房 HUD 追缴
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")

local ERR_PICKUP = "PICKUP"
local ERR_ENEMY = "ENEMY"
local ERR_ITEM = "ITEM"
local ROLL_CHANCE = 25
local ROLL_DELAY = 3
local W_PICKUP = 50
local W_ENEMY = 35
local W_ITEM = 15
local DESYNC_SHADER = "Qing_Mental_Desync"
local DESYNC_MAX_DEFAULT = 10
local DESYNC_LEAVE_FRAMES = 3

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Mental_Disorder,
	own_key = "Item_Mental_Disorder_",
	screen_glitch = nil,
	-- GetPtrHash -> {left, next} 真实干扰实体，本房只 glitch 1～2 次
	decoy_glitch = {},
	reality_tears = {},
	reclaim_fx = nil,
	hud_ghost_flip = false,
	hud_ghost_next = 0,
	band_spr = nil,
}

local ITEM_BLACKLIST = {
	[item.entity] = true,
	[CollectibleType.COLLECTIBLE_1UP] = true,
	[CollectibleType.COLLECTIBLE_DEAD_CAT] = true,
	[CollectibleType.COLLECTIBLE_GUPPYS_COLLAR] = true,
	[CollectibleType.COLLECTIBLE_ANKH] = true,
	[CollectibleType.COLLECTIBLE_JUDAS_SHADOW] = true,
	[CollectibleType.COLLECTIBLE_LAZARUS_RAGS] = true,
	[CollectibleType.COLLECTIBLE_INNER_CHILD] = true,
	[CollectibleType.COLLECTIBLE_SCHOOLBAG] = true,
	[CollectibleType.COLLECTIBLE_MOMS_PURSE] = true,
	[CollectibleType.COLLECTIBLE_BELLY_BUTTON] = true,
	[CollectibleType.COLLECTIBLE_STARTER_DECK] = true,
	[CollectibleType.COLLECTIBLE_LITTLE_BAGGY] = true,
	[CollectibleType.COLLECTIBLE_POLYDACTYLY] = true,
	[CollectibleType.COLLECTIBLE_DEEP_POCKETS] = true,
	[CollectibleType.COLLECTIBLE_BIRTHRIGHT] = true,
	[CollectibleType.COLLECTIBLE_TMTRAINER] = true,
	[CollectibleType.COLLECTIBLE_MISSING_NO] = true,
	[CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE] = true,
	[CollectibleType.COLLECTIBLE_HOLY_MANTLE] = true,
	[CollectibleType.COLLECTIBLE_WHORE_OF_BABYLON] = true,
	[CollectibleType.COLLECTIBLE_CROWN_OF_LIGHT] = true,
	[CollectibleType.COLLECTIBLE_DARK_PRINCES_CROWN] = true,
	[CollectibleType.COLLECTIBLE_EMPTY_VESSEL] = true,
	[CollectibleType.COLLECTIBLE_ASTRAL_PROJECTION] = true,
	[CollectibleType.COLLECTIBLE_MARS] = true,
	[CollectibleType.COLLECTIBLE_EXPERIMENTAL_TREATMENT] = true,
	[CollectibleType.COLLECTIBLE_LUSTY_BLOOD] = true,
	[CollectibleType.COLLECTIBLE_CAMO_UNDIES] = true,
	[CollectibleType.COLLECTIBLE_GLITCHED_CROWN] = true,
	[CollectibleType.COLLECTIBLE_SPINDOWN_DICE] = true,
}

if enums.Items.It_s_a_trick then ITEM_BLACKLIST[enums.Items.It_s_a_trick] = true end

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

function item.force_error()
	local debug = debug_root()
	return debug and debug.MentalForceError == true
end

local function empty_virtual()
	return {
		Coins = 0, Bombs = 0, Keys = 0,
		Hearts = 0, Soul = 0, Black = 0, Bone = 0, Rotten = 0, Golden = 0, Eternal = 0,
		Battery = 0, Card = 0, CardSlot = nil, Pill = 0, PillSlot = nil,
	}
end

local function empty_error()
	return {
		Type = nil,
		Seed = nil,
		Virtual = empty_virtual(),
		CopiedItem = nil,
		CopiedPlayer = nil,
	}
end

local function error_state()
	save.elses[item.own_key.."error"] = save.elses[item.own_key.."error"] or empty_error()
	local st = save.elses[item.own_key.."error"]
	st.Virtual = st.Virtual or empty_virtual()
	return st
end

local function player_idx(player)
	if not player then return 0 end
	if player.GetPlayerIndex then return player:GetPlayerIndex() end
	local d = player:GetData()
	if d.__Index ~= nil then return d.__Index end
	return 0
end

local function owner_player()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and auxi.has_have_coll(player, item.entity) then return player end
	end
	return nil
end

local function collectible_rng(player)
	player = player or owner_player() or Game():GetPlayer(0)
	return auxi.rng_for_sake(player:GetCollectibleRNG(item.entity))
end

local function tagged(ent)
	return ent and ent:GetData()[item.own_key.."illusion"] == true
end

local function mark_illusion(ent, st)
	if not ent then return end
	ent:GetData()[item.own_key.."illusion"] = true
	if st then st.Seed = ent.InitSeed end
end

local function px_uv(px, axis)
	local m = auxi.check_screen_multi(Vector(1, 1)) * 256
	local den = axis == "y" and m.Y or m.X
	if den < 1 then den = 256 end
	return px / den
end

local function empty_desync_params()
	return {
		P1 = {0, 0, 0, 0},
		P2 = {0, 0, 0, 0},
		P3 = {0, 0, 0, 0},
	}
end

--- 启动全屏 Mental Desync；mild 用于离房/拾取假物的极轻闪
function item.trigger_desync(frames, mild)
	frames = math.max(1, math.floor(tonumber(frames) or DESYNC_MAX_DEFAULT))
	local seed = Game():GetFrameCount() + (Game():GetRoom():GetDecorationSeed() or 0)
	local rng = RNG()
	rng:SetSeed(math.max(1, seed % 2147483646), 35)
	local function band_y(lo, hi)
		local y0 = lo + rng:RandomFloat() * (hi - lo)
		local h = 0.04 + rng:RandomFloat() * 0.04
		return y0, math.min(0.98, y0 + h)
	end
	local b1a, b1b = band_y(0.16, 0.28)
	local b2a, b2b = band_y(0.48, 0.58)
	local b3 = 0.68 + rng:RandomFloat() * 0.12
	local sign1 = rng:RandomInt(2) == 0 and 1 or -1
	local sign2 = -sign1
	item.screen_glitch = {
		timer = frames,
		max = frames,
		mild = mild == true,
		seed = seed,
		band1 = {b1a, b1b},
		band2 = {b2a, b2b},
		band3_y = b3,
		off1 = sign1 * (0.005 + rng:RandomFloat() * 0.004),
		off2 = sign2 * (0.007 + rng:RandomFloat() * 0.005),
		off3 = sign1 * (0.012 + rng:RandomFloat() * 0.006),
		global = {
			(rng:RandomFloat() - 0.5) * px_uv(2, "x"),
			(rng:RandomFloat() - 0.5) * px_uv(1.5, "y"),
		},
	}
end

local function desync_strength(gch)
	if not gch or (gch.timer or 0) <= 0 then return 0 end
	if gch.mild then
		return 0.08 + 0.04 * (gch.timer / math.max(1, gch.max))
	end
	local t = gch.timer
	if t >= 8 then return 0.25
	elseif t >= 5 then return 0.65
	elseif t >= 3 then return 0.35
	else return 0.12 end
end

local function pack_desync_params()
	local gch = item.screen_glitch
	if not gch or (gch.timer or 0) <= 0 then return empty_desync_params() end
	local strength = desync_strength(gch)
	local chromatic = px_uv(gch.mild and 1.2 or 2.4, "x")
	-- 中段略加强色差，仍 ≤ ~4px
	if not gch.mild and gch.timer >= 5 and gch.timer < 8 then
		chromatic = px_uv(3.2, "x")
	end
	-- 5～8 帧区间加一次极小全局跳动（timer 倒计时：3～5）
	local gx, gy = gch.global[1], gch.global[2]
	if not gch.mild and gch.timer >= 3 and gch.timer < 6 then
		gx = gx * 2.2
		gy = gy * 2.2
	elseif gch.timer >= 8 then
		gx, gy = gx * 0.25, gy * 0.25
	end
	return {
		P1 = {strength, chromatic, gch.off1, gch.off2},
		P2 = {gch.band1[1], gch.band1[2], gch.band2[1], gch.band2[2]},
		P3 = {gx, gy, gch.band3_y, gch.off3},
	}
end

local function get_band_sprite()
	if not item.band_spr then
		item.band_spr = Sprite()
		item.band_spr:Load("gfx/Black.anm2", true)
		item.band_spr:Play("Idle", true)
	end
	return item.band_spr
end

local function spawn_afterimage(ent)
	if not ent or not ent:Exists() then return end
	local spr = ent:GetSprite()
	if not spr then return end
	local ghost = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		enums.Entities.ID_EFFECT_MeusNIL,
		0,
		ent.Position,
		Vector.Zero,
		nil
	)
	if not ghost then return end
	local d = ghost:GetData()
	d.removecd = 2
	d[item.own_key.."afterimage"] = true
	local gs = ghost:GetSprite()
	local fname = spr:GetFilename()
	if fname and fname ~= "" then
		gs:Load(fname, true)
		local anim = spr:GetAnimation()
		if anim and anim ~= "" then
			gs:Play(anim, true)
			if spr.GetFrame and gs.SetFrame then gs:SetFrame(spr:GetFrame()) end
		end
	end
	local ox = (math.random(0, 1) == 0 and -1 or 1) * (2 + math.random() * 2)
	local oy = (math.random() - 0.5) * 2
	ghost.SpriteOffset = (ent.SpriteOffset or Vector.Zero) + Vector(ox, oy)
	ghost.SpriteScale = ent.SpriteScale
	gs.Color = Color(1, 1, 1, 0.25, 0.02, 0, -0.02)
	ghost.DepthOffset = (ent.DepthOffset or 0) - 1
end

local COLOR_GLITCHES = {
	function(a) return Color(1, 1, 1, a, 0.05, 0, -0.02) end,
	function(a) return Color(1, 1, 1, a, -0.02, 0, 0.05) end,
	function(a) return Color(1, 1, 1, a, 0, -0.04, 0.02) end,
}

local function apply_glitch_burst(ent, opts)
	opts = opts or {}
	if not ent or not ent:Exists() then return end
	local d = ent:GetData()
	local gch = d[item.own_key.."glitch"]
	if not gch then
		gch = {next = 45 + math.random(0, 30), left = 0, so = Vector(0, 0)}
		d[item.own_key.."glitch"] = gch
	end
	gch.left = opts.left or math.random(1, 2)
	gch.so = ent.SpriteOffset or Vector.Zero
	local mode = opts.mode or math.random(1, 4)
	gch.mode = mode
	local spr = ent:GetSprite()
	if mode == 1 or mode == 4 then
		local dx = (math.random(0, 1) == 0 and -1 or 1) * (1 + math.random())
		local dy = (math.random() - 0.5) * 2
		ent.SpriteOffset = gch.so + Vector(dx, dy)
	end
	if mode == 2 or mode == 4 then
		if spr then
			local a = 0.9 + math.random() * 0.08
			spr.Color = COLOR_GLITCHES[math.random(1, #COLOR_GLITCHES)](a)
		end
	end
	if mode == 3 and spr and spr.GetFrame and spr.SetFrame then
		gch.freeze_frame = spr:GetFrame()
	end
	if mode == 4 and math.random() < 0.55 then
		spawn_afterimage(ent)
	elseif mode ~= 4 and math.random() < 0.18 then
		spawn_afterimage(ent)
	end
end

local function tick_glitch(ent, interval_lo, interval_hi)
	if not ent or not ent:Exists() then return end
	local d = ent:GetData()
	local gch = d[item.own_key.."glitch"]
	interval_lo = interval_lo or 45
	interval_hi = interval_hi or 75
	if not gch then
		gch = {
			next = interval_lo + math.random(0, math.max(0, interval_hi - interval_lo)),
			left = 0,
			so = Vector(0, 0),
		}
		d[item.own_key.."glitch"] = gch
	end
	local spr = ent:GetSprite()
	if gch.left > 0 then
		if gch.freeze_frame and spr and spr.SetFrame then
			spr:SetFrame(gch.freeze_frame)
		end
		gch.left = gch.left - 1
		if gch.left <= 0 then
			ent.SpriteOffset = gch.so
			gch.freeze_frame = nil
			if spr then spr.Color = Color(1, 1, 1, 1) end
		end
		return
	end
	gch.next = gch.next - 1
	if gch.next > 0 then return end
	gch.next = interval_lo + math.random(0, math.max(0, interval_hi - interval_lo))
	apply_glitch_burst(ent)
end

local function tick_decoy_glitch(ent)
	local key = GetPtrHash(ent)
	local info = item.decoy_glitch[key]
	if not info then return end
	if not ent:Exists() or ent:IsDead() then
		item.decoy_glitch[key] = nil
		return
	end
	if (info.left_bursts or 0) <= 0 then return end
	info.next = (info.next or 1) - 1
	if info.next > 0 then return end
	info.next = 90 + math.random(0, 120)
	info.left_bursts = info.left_bursts - 1
	apply_glitch_burst(ent, {left = 1})
	-- 刷新 canonical wrapper
	item.decoy_glitch[key] = info
	info.ent = ent
end

local function register_decoy_glitches(rng)
	item.decoy_glitch = {}
	local candidates = {}
	local ents = Isaac.GetRoomEntities()
	for i = 1, #ents do
		local ent = ents[i]
		if ent and not tagged(ent) then
			local npc = ent:ToNPC()
			local pickup = ent:ToPickup()
			local ok = false
			if npc and not npc:IsBoss() and auxi.isenemies(ent) then ok = true end
			if pickup and not pickup:IsShopItem() and not (pickup.Price and pickup.Price ~= 0) then ok = true end
			if ok then candidates[#candidates + 1] = ent end
		end
	end
	if #candidates == 0 then return end
	local count = math.min(#candidates, 1 + rng:RandomInt(3))
	for _ = 1, count do
		if #candidates == 0 then break end
		local idx = rng:RandomInt(#candidates) + 1
		local ent = table.remove(candidates, idx)
		item.decoy_glitch[GetPtrHash(ent)] = {
			ent = ent,
			left_bursts = 1 + rng:RandomInt(2),
			next = 40 + rng:RandomInt(80),
		}
	end
end

--- 几何 Reality Tear：白线 / 半透明带 / 色差矩形，不依赖专用 anm2
local function spawn_reality_tear(pos, size)
	size = math.max(24, tonumber(size) or 40)
	item.reality_tears[#item.reality_tears + 1] = {
		pos = Vector(pos.X, pos.Y),
		size = size,
		timer = 0,
		max = 7,
		seed = Game():GetFrameCount() + math.floor(pos.X + pos.Y),
	}
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_EDEN_GLITCH, 0.55, 1.15, false, 0, 2)
end

local function render_reality_tears()
	if not item.reality_tears or #item.reality_tears == 0 then return end
	local spr = get_band_sprite()
	local remain = {}
	for i = 1, #item.reality_tears do
		local tear = item.reality_tears[i]
		tear.timer = tear.timer + 1
		local t = tear.timer
		local screen = Isaac.WorldToScreen(tear.pos)
		local w = tear.size * 1.4
		local h = tear.size * 1.1
		local alpha = 1 - (t / tear.max)
		if t <= 2 then
			spr.Color = Color(1, 1, 1, 0.55 * alpha)
			spr.Scale = Vector(w / 16, h / 16)
			spr:Render(screen, Vector.Zero, Vector.Zero)
		end
		local bands = {
			{y = -0.35, ox = t >= 3 and 6 or 0},
			{y = 0, ox = t >= 3 and -4 or 0},
			{y = 0.32, ox = t >= 3 and 5 or 0},
		}
		for _,band in ipairs(bands) do
			spr.Color = Color(1, 1, 1, 0.7 * alpha)
			spr.Scale = Vector(w / 14, 0.12)
			spr:Render(screen + Vector(band.ox, band.y * h), Vector.Zero, Vector.Zero)
		end
		if t >= 4 then
			spr.Color = Color(1, 0.35, 0.35, 0.35 * alpha)
			spr.Scale = Vector(w / 18, h / 20)
			spr:Render(screen + Vector(3, -1), Vector.Zero, Vector.Zero)
			spr.Color = Color(0.35, 0.9, 1, 0.35 * alpha)
			spr:Render(screen + Vector(-3, 1), Vector.Zero, Vector.Zero)
		end
		if t >= 5 then
			for k = -2, 2 do
				spr.Color = Color(1, 1, 1, 0.4 * alpha)
				spr.Scale = Vector(w / 12, 0.06)
				spr:Render(screen + Vector(0, k * 4), Vector.Zero, Vector.Zero)
			end
		end
		if t < tear.max then remain[#remain + 1] = tear end
	end
	item.reality_tears = remain
end

local function snapshot_player(player)
	if not player then return nil end
	local charges = 0
	if player.GetActiveCharge then charges = player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY) or 0 end
	return {
		Coins = player:GetNumCoins(),
		Bombs = player:GetNumBombs(),
		Keys = player:GetNumKeys(),
		Hearts = player:GetHearts(),
		Soul = player:GetSoulHearts(),
		Black = 0,
		Bone = player:GetBoneHearts(),
		Rotten = player:GetRottenHearts(),
		Golden = player:GetGoldenHearts(),
		Eternal = player:GetEternalHearts(),
		Battery = charges,
	}
end

local function spend_virtual(virt, key, lost)
	if lost <= 0 then return end
	virt[key] = math.max(0, (virt[key] or 0) - lost)
end

local function claw_amount(player, add_fn, get_fn, amount)
	if amount <= 0 or not player then return end
	local have = get_fn(player) or 0
	add_fn(player, -math.min(amount, have))
end

local function is_copyable_pickup(ent)
	if not ent or not ent:ToPickup() then return false end
	local pickup = ent:ToPickup()
	if tagged(pickup) then return false end
	if pickup:IsShopItem() then return false end
	if pickup.Price and pickup.Price ~= 0 then return false end
	if pickup:IsDead() then return false end
	local v = pickup.Variant
	if v == PickupVariant.PICKUP_COIN then
		local s = pickup.SubType
		if s == CoinSubType.COIN_STICKYNICKEL or s == CoinSubType.COIN_GOLDEN or s == CoinSubType.COIN_LUCKYPENNY then return false end
		return true
	elseif v == PickupVariant.PICKUP_KEY then
		return pickup.SubType ~= KeySubType.KEY_GOLDEN
	elseif v == PickupVariant.PICKUP_BOMB then
		local s = pickup.SubType
		return s == BombSubType.BOMB_NORMAL or s == BombSubType.BOMB_DOUBLEPACK
	elseif v == PickupVariant.PICKUP_HEART then
		return true
	elseif v == PickupVariant.PICKUP_LIL_BATTERY then
		return pickup.SubType ~= BatterySubType.BATTERY_GOLDEN
	elseif v == PickupVariant.PICKUP_TAROTCARD or v == PickupVariant.PICKUP_PILL then
		return true
	end
	return false
end

local function is_copyable_enemy(ent)
	if not auxi.isenemies(ent) then return false end
	local npc = ent:ToNPC()
	if not npc then return false end
	if tagged(npc) then return false end
	if npc:IsBoss() or npc:IsChampion() then return false end
	if npc.Parent and npc.Parent:Exists() and not npc.Parent:ToPlayer() then return false end
	if npc.Type == EntityType.ENTITY_SHOPKEEPER or npc.Type == EntityType.ENTITY_FIREPLACE then return false end
	return true
end

local function is_copyable_item(player, id)
	if not id or ITEM_BLACKLIST[id] then return false end
	local config = Isaac.GetItemConfig():GetCollectible(id)
	if not config or config.Hidden or config.Special then return false end
	if config.Type ~= ItemType.ITEM_PASSIVE and config.Type ~= ItemType.ITEM_FAMILIAR then return false end
	if config.Tags & ItemConfig.TAG_QUEST == ItemConfig.TAG_QUEST then return false end
	if ItemConfig.TAG_UNIQUE_FAMILIAR and config.Tags & ItemConfig.TAG_UNIQUE_FAMILIAR == ItemConfig.TAG_UNIQUE_FAMILIAR then return false end
	if not player:HasCollectible(id, true) then return false end
	return true
end

local function list_copyable_pickups()
	local ret = {}
	local ents = Isaac.FindByType(EntityType.ENTITY_PICKUP)
	for i = 1, #ents do
		if is_copyable_pickup(ents[i]) then ret[#ret + 1] = ents[i] end
	end
	return ret
end

local function list_copyable_enemies()
	local ret = {}
	local ents = Isaac.GetRoomEntities()
	for i = 1, #ents do
		if is_copyable_enemy(ents[i]) then ret[#ret + 1] = ents[i] end
	end
	return ret
end

local function list_copyable_items(player)
	local ret = {}
	if not player then return ret end
	local config = Isaac.GetItemConfig()
	local sz = config:GetCollectibles().Size
	for id = 1, sz do
		if is_copyable_item(player, id) then ret[#ret + 1] = id end
	end
	return ret
end

local function can_collect_pickup(player, pickup)
	if not player or not pickup then return false end
	local v = pickup.Variant
	local s = pickup.SubType
	if v == PickupVariant.PICKUP_HEART then
		if s == HeartSubType.HEART_SOUL or s == HeartSubType.HEART_HALF_SOUL then return player:CanPickSoulHearts()
		elseif s == HeartSubType.HEART_BLACK then return player:CanPickBlackHearts()
		elseif s == HeartSubType.HEART_GOLDEN then return player:CanPickGoldenHearts()
		elseif s == HeartSubType.HEART_BONE then return player:CanPickBoneHearts()
		elseif s == HeartSubType.HEART_ROTTEN then return player:CanPickRottenHearts()
		elseif s == HeartSubType.HEART_BLENDED then return player:CanPickSoulHearts() or player:CanPickRedHearts()
		elseif s == HeartSubType.HEART_ETERNAL then return true
		else return player:CanPickRedHearts() end
	end
	return true
end

local function record_pickup_virtual(player, pickup)
	local st = error_state()
	local virt = st.Virtual
	st.PickupPlayer = player_idx(player)
	local v = pickup.Variant
	local s = pickup.SubType
	if v == PickupVariant.PICKUP_COIN then
		local add = 1
		if s == CoinSubType.COIN_NICKEL then add = 5
		elseif s == CoinSubType.COIN_DIME then add = 10
		elseif s == CoinSubType.COIN_DOUBLEPACK then add = 2 end
		virt.Coins = (virt.Coins or 0) + add
	elseif v == PickupVariant.PICKUP_KEY then
		virt.Keys = (virt.Keys or 0) + (s == KeySubType.KEY_DOUBLEPACK and 2 or 1)
	elseif v == PickupVariant.PICKUP_BOMB then
		virt.Bombs = (virt.Bombs or 0) + (s == BombSubType.BOMB_DOUBLEPACK and 2 or 1)
	elseif v == PickupVariant.PICKUP_HEART then
		if s == HeartSubType.HEART_HALF then virt.Hearts = virt.Hearts + 1
		elseif s == HeartSubType.HEART_FULL or s == HeartSubType.HEART_SCARED then virt.Hearts = virt.Hearts + 2
		elseif s == HeartSubType.HEART_DOUBLEPACK then virt.Hearts = virt.Hearts + 4
		elseif s == HeartSubType.HEART_SOUL then virt.Soul = virt.Soul + 2
		elseif s == HeartSubType.HEART_HALF_SOUL then virt.Soul = virt.Soul + 1
		elseif s == HeartSubType.HEART_BLACK then virt.Black = virt.Black + 2
		elseif s == HeartSubType.HEART_BONE then virt.Bone = virt.Bone + 1
		elseif s == HeartSubType.HEART_ROTTEN then virt.Rotten = virt.Rotten + 1
		elseif s == HeartSubType.HEART_GOLDEN then virt.Golden = virt.Golden + 1
		elseif s == HeartSubType.HEART_ETERNAL then virt.Eternal = virt.Eternal + 1
		elseif s == HeartSubType.HEART_BLENDED then virt.Soul = virt.Soul + 2
		else virt.Hearts = virt.Hearts + 2 end
	elseif v == PickupVariant.PICKUP_LIL_BATTERY then
		local before = player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY) or 0
		delay_buffer.addeffe(function()
			if not auxi.check_all_exists(player) then return end
			local after = player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY) or 0
			local st2 = error_state()
			st2.Virtual.Battery = math.max(0, after - before)
			player:GetData()[item.own_key.."snap"] = snapshot_player(player)
		end, nil, 0)
	elseif v == PickupVariant.PICKUP_TAROTCARD then
		local before = {}
		for slot = 0, 3 do before[slot] = player:GetCard(slot) end
		delay_buffer.addeffe(function()
			if not auxi.check_all_exists(player) then return end
			for slot = 0, 3 do
				local card = player:GetCard(slot)
				if card and card ~= 0 and card ~= before[slot] then
					error_state().Virtual.Card = card
					error_state().Virtual.CardSlot = slot
					break
				end
			end
			player:GetData()[item.own_key.."snap"] = snapshot_player(player)
		end, nil, 0)
	elseif v == PickupVariant.PICKUP_PILL then
		local before = {}
		for slot = 0, 3 do before[slot] = player:GetPill(slot) end
		delay_buffer.addeffe(function()
			if not auxi.check_all_exists(player) then return end
			for slot = 0, 3 do
				local pill = player:GetPill(slot)
				if pill and pill ~= 0 and pill ~= before[slot] then
					error_state().Virtual.Pill = pill
					error_state().Virtual.PillSlot = slot
					break
				end
			end
			player:GetData()[item.own_key.."snap"] = snapshot_player(player)
		end, nil, 0)
	end
	player:GetData()[item.own_key.."snap"] = snapshot_player(player)
	-- 拾取假物：极轻一帧色差，不揭穿
	item.trigger_desync(2, true)
end

local function remove_copied_item(st)
	if not st.CopiedItem or st.CopiedPlayer == nil then return end
	local player = Game():GetPlayer(st.CopiedPlayer)
	if auxi.check_all_exists(player) then
		local effects = player:GetEffects()
		if effects and effects:HasCollectibleEffect(st.CopiedItem) then
			effects:RemoveCollectibleEffect(st.CopiedItem, 1)
		end
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:EvaluateItems()
		player:GetData()[item.own_key.."copied"] = nil
	end
	st.CopiedItem = nil
	st.CopiedPlayer = nil
end

local function build_reclaim_fx(virt, player)
	local parts = {}
	local function add(kind, amount, pos)
		if (amount or 0) <= 0 then return end
		parts[#parts + 1] = {
			kind = kind,
			amount = amount,
			pos = Vector(pos.X, pos.Y),
			text = "-"..tostring(amount),
		}
	end
	if not player then return parts end
	add("coin", virt.Coins, ui.UI_Pos("coin", 1))
	add("bomb", virt.Bombs, ui.UIBombPos(false))
	add("key", virt.Keys, ui.UI_Pos("key", 1))
	if virt.Card and virt.Card ~= 0 then
		local slot = (virt.CardSlot or 0) + 1
		parts[#parts + 1] = {
			kind = "card",
			amount = 1,
			pos = ui.UICardPos(slot),
			text = "×",
			card = true,
		}
	end
	if virt.Pill and virt.Pill ~= 0 then
		local slot = (virt.PillSlot or 0) + 1
		parts[#parts + 1] = {
			kind = "pill",
			amount = 1,
			pos = ui.UICardPos(slot),
			text = "×",
			card = true,
		}
	end
	local heart_amt = (virt.Hearts or 0) + (virt.Soul or 0) + (virt.Black or 0)
		+ (virt.Bone or 0) + (virt.Rotten or 0) + (virt.Golden or 0) + (virt.Eternal or 0)
	if heart_amt > 0 then
		add("heart", heart_amt, ui.UIHeartPos(1, player))
	end
	return parts
end

local function start_reclaim_fx(virt, player)
	local parts = build_reclaim_fx(virt, player)
	if #parts == 0 and not (virt.CopiedItem) then
		if (virt.Battery or 0) <= 0 then return end
	end
	if (virt.Battery or 0) > 0 then
		parts[#parts + 1] = {
			kind = "battery",
			amount = virt.Battery,
			pos = ui.UIChargeBarPos(0),
			text = "-"..tostring(virt.Battery),
		}
	end
	if #parts == 0 then return end
	local center = auxi.GetScreenSize() * 0.5
	item.reclaim_fx = {
		timer = 0,
		max = 16,
		parts = parts,
		center = center,
	}
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BEEP, 0.45, 0.85, false, 0, 1)
end

local function render_reclaim_fx()
	local fx = item.reclaim_fx
	if not fx then return end
	fx.timer = fx.timer + 1
	local u = fx.timer / math.max(1, fx.max)
	local alpha = 1 - u
	local center = fx.center
	for _,part in ipairs(fx.parts) do
		local pos = auxi.Lerp(part.pos, center, math.min(1, u * 1.15))
		local split = (1 - u) * 4
		local col_main = KColor(0.85, 0.88, 0.92, alpha)
		local col_r = KColor(1, 0.35, 0.35, alpha * 0.45)
		local col_c = KColor(0.35, 0.9, 1, alpha * 0.45)
		if part.card then
			-- 卡牌：横向错位白闪
			gui.draw_ch(pos + Vector(-split, 0), part.text, 1.2, 1.2, col_r, true)
			gui.draw_ch(pos + Vector(split, 0), part.text, 1.2, 1.2, col_c, true)
			gui.draw_ch(pos, part.text, 1.1, 1.1, col_main, true)
		else
			gui.draw_ch(pos + Vector(-split, -1), part.text, 1, 1, col_r, true)
			gui.draw_ch(pos + Vector(split, 1), part.text, 1, 1, col_c, true)
			gui.draw_ch(pos, part.text, 1, 1, col_main, true)
		end
	end
	if fx.timer >= fx.max then item.reclaim_fx = nil end
end

local function claw_virtual(st)
	local virt = st.Virtual or empty_virtual()
	local player = owner_player() or Game():GetPlayer(0)
	if not auxi.check_all_exists(player) then return end
	start_reclaim_fx(virt, player)
	claw_amount(player, function(p, n) p:AddCoins(n) end, function(p) return p:GetNumCoins() end, virt.Coins or 0)
	claw_amount(player, function(p, n) p:AddBombs(n) end, function(p) return p:GetNumBombs() end, virt.Bombs or 0)
	claw_amount(player, function(p, n) p:AddKeys(n) end, function(p) return p:GetNumKeys() end, virt.Keys or 0)
	claw_amount(player, function(p, n) p:AddHearts(n) end, function(p) return p:GetHearts() end, virt.Hearts or 0)
	claw_amount(player, function(p, n) p:AddSoulHearts(n) end, function(p) return p:GetSoulHearts() end, virt.Soul or 0)
	claw_amount(player, function(p, n) p:AddBlackHearts(n) end, function(p) return p:GetBlackHearts() end, virt.Black or 0)
	claw_amount(player, function(p, n) p:AddBoneHearts(n) end, function(p) return p:GetBoneHearts() end, virt.Bone or 0)
	claw_amount(player, function(p, n) p:AddRottenHearts(n) end, function(p) return p:GetRottenHearts() end, virt.Rotten or 0)
	claw_amount(player, function(p, n) p:AddGoldenHearts(n) end, function(p) return p:GetGoldenHearts() end, virt.Golden or 0)
	claw_amount(player, function(p, n) p:AddEternalHearts(n) end, function(p) return p:GetEternalHearts() end, virt.Eternal or 0)
	if (virt.Battery or 0) > 0 then
		local cur = player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY) or 0
		player:SetActiveCharge(math.max(0, cur - virt.Battery), ActiveSlot.SLOT_PRIMARY)
	end
	if virt.Card and virt.Card ~= 0 then
		if virt.CardSlot and player:GetCard(virt.CardSlot) == virt.Card then
			player:SetCard(virt.CardSlot, 0)
		else
			for slot = 0, 3 do
				if player:GetCard(slot) == virt.Card then player:SetCard(slot, 0) break end
			end
		end
	end
	if virt.Pill and virt.Pill ~= 0 then
		if virt.PillSlot and player:GetPill(virt.PillSlot) == virt.Pill then
			player:SetPill(virt.PillSlot, 0)
		else
			for slot = 0, 3 do
				if player:GetPill(slot) == virt.Pill then player:SetPill(slot, 0) break end
			end
		end
	end
	player:GetData()[item.own_key.."snap"] = nil
end

local function remove_illusion_entities()
	local ents = Isaac.GetRoomEntities()
	for i = 1, #ents do
		local ent = ents[i]
		if tagged(ent) then
			if ent:ToPickup() and not ent:ToPickup():IsDead() then
				ent:Remove()
			elseif ent:ToNPC() then
				ent:Remove()
			elseif ent:ToProjectile() then
				ent:Remove()
			end
		end
	end
end

function item.clear_error(reclaim)
	local st = error_state()
	local had = st.Type ~= nil or (st.Virtual and (
		(st.Virtual.Coins or 0) > 0 or (st.Virtual.Bombs or 0) > 0 or (st.Virtual.Keys or 0) > 0
		or (st.Virtual.Hearts or 0) > 0 or (st.Virtual.Soul or 0) > 0 or (st.Virtual.Card or 0) ~= 0
		or (st.Virtual.Pill or 0) ~= 0 or st.CopiedItem
	))
	if reclaim ~= false then claw_virtual(st) end
	remove_copied_item(st)
	remove_illusion_entities()
	item.decoy_glitch = {}
	save.elses[item.own_key.."error"] = empty_error()
	if reclaim ~= false and had then
		item.trigger_desync(DESYNC_LEAVE_FRAMES, true)
	end
end

local function spawn_pickup_error(src, rng)
	if not src then return false end
	local room = Game():GetRoom()
	local offset = Vector((rng:RandomInt(17) - 8) * 2, (rng:RandomInt(17) - 8) * 2)
	if offset:Length() < 12 then offset = Vector(24, 0) end
	local pos = room:FindFreePickupSpawnPosition(src.Position + offset, 8, true)
	local q = Isaac.Spawn(EntityType.ENTITY_PICKUP, src.Variant, src.SubType, pos, Vector.Zero, nil):ToPickup()
	if not q then return false end
	if q.SubType ~= src.SubType or q.Variant ~= src.Variant then
		q:Morph(EntityType.ENTITY_PICKUP, src.Variant, src.SubType, false, true, true)
	end
	local st = error_state()
	st.Type = ERR_PICKUP
	st.Virtual = empty_virtual()
	mark_illusion(q, st)
	return true
end

local function spawn_enemy_error(src)
	if not src then return false end
	local room = Game():GetRoom()
	local pos = room:FindFreeTilePosition(src.Position + Vector(28, 0), 20)
	local npc = Isaac.Spawn(src.Type, src.Variant, src.SubType, pos, Vector.Zero, src):ToNPC()
	if not npc then return false end
	npc.CanShutDoors = false
	npc:AddEntityFlags(EntityFlag.FLAG_NO_REWARD)
	npc.HitPoints = math.max(1, math.min(npc.HitPoints, src.HitPoints))
	local st = error_state()
	st.Type = ERR_ENEMY
	st.Virtual = empty_virtual()
	mark_illusion(npc, st)
	return true
end

local function spawn_item_error(player, id)
	if not player or not id then return false end
	player:GetEffects():AddCollectibleEffect(id, true, 1)
	player:AddCacheFlags(CacheFlag.CACHE_ALL)
	player:EvaluateItems()
	player:GetData()[item.own_key.."copied"] = id
	local st = error_state()
	st.Type = ERR_ITEM
	st.Virtual = empty_virtual()
	st.CopiedItem = id
	st.CopiedPlayer = player_idx(player)
	st.Seed = nil
	return true
end

local function pick_weighted(rng, options)
	local total = 0
	for i = 1, #options do total = total + (options[i].w or 0) end
	if total <= 0 then return nil end
	local roll = rng:RandomInt(total)
	local acc = 0
	for i = 1, #options do
		acc = acc + options[i].w
		if roll < acc then return options[i] end
	end
	return options[#options]
end

function item.create_error(force_kind)
	local player = owner_player()
	if not player then return false end
	item.clear_error(true)
	local rng = collectible_rng(player)
	local pickups = list_copyable_pickups()
	local enemies = list_copyable_enemies()
	local items = list_copyable_items(player)
	local options = {}
	if force_kind == ERR_PICKUP and #pickups > 0 then options[1] = {kind = ERR_PICKUP, w = 1}
	elseif force_kind == ERR_ENEMY and #enemies > 0 then options[1] = {kind = ERR_ENEMY, w = 1}
	elseif force_kind == ERR_ITEM and #items > 0 then options[1] = {kind = ERR_ITEM, w = 1}
	else
		if #pickups > 0 then options[#options + 1] = {kind = ERR_PICKUP, w = W_PICKUP} end
		if #enemies > 0 then options[#options + 1] = {kind = ERR_ENEMY, w = W_ENEMY} end
		if #items > 0 then options[#options + 1] = {kind = ERR_ITEM, w = W_ITEM} end
	end
	local chosen = pick_weighted(rng, options)
	if not chosen then return false end
	local ok = false
	if chosen.kind == ERR_PICKUP then
		ok = spawn_pickup_error(pickups[rng:RandomInt(#pickups) + 1], rng)
	elseif chosen.kind == ERR_ENEMY then
		ok = spawn_enemy_error(enemies[rng:RandomInt(#enemies) + 1])
	else
		ok = spawn_item_error(player, items[rng:RandomInt(#items) + 1])
	end
	if ok then
		item.trigger_desync(DESYNC_MAX_DEFAULT, false)
		register_decoy_glitches(rng)
	end
	return ok
end

function item.try_roll_error()
	local player = owner_player()
	if not player then return false end
	local rng = collectible_rng(player)
	if not item.force_error() then
		if rng:RandomInt(100) >= ROLL_CHANCE then return false end
	end
	return item.create_error()
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."error"] = empty_error()
	end
	save.elses[item.own_key.."error"] = save.elses[item.own_key.."error"] or empty_error()
	item.screen_glitch = nil
	item.decoy_glitch = {}
	item.reality_tears = {}
	item.reclaim_fx = nil
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	item.clear_error(true)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item.decoy_glitch = {}
	item.reality_tears = {}
	if not owner_player() then return end
	delay_buffer.addeffe(function()
		item.try_roll_error()
	end, nil, ROLL_DELAY)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil,
Function = function(_, pickup, collider, low)
	if not tagged(pickup) then return end
	local player = collider and collider:ToPlayer()
	if not player then return end
	if not can_collect_pickup(player, pickup) then return end
	if pickup:GetData()[item.own_key.."counted"] then return end
	pickup:GetData()[item.own_key.."counted"] = true
	record_pickup_virtual(player, pickup)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	local st = error_state()
	if st.Type ~= ERR_PICKUP then return end
	if st.PickupPlayer ~= nil and player_idx(player) ~= st.PickupPlayer then return end
	local virt = st.Virtual
	local snap = player:GetData()[item.own_key.."snap"]
	if not snap then
		player:GetData()[item.own_key.."snap"] = snapshot_player(player)
		return
	end
	local now = snapshot_player(player)
	spend_virtual(virt, "Coins", snap.Coins - now.Coins)
	spend_virtual(virt, "Bombs", snap.Bombs - now.Bombs)
	spend_virtual(virt, "Keys", snap.Keys - now.Keys)
	spend_virtual(virt, "Hearts", snap.Hearts - now.Hearts)
	spend_virtual(virt, "Soul", snap.Soul - now.Soul)
	if (virt.Black or 0) > 0 and snap.Soul > now.Soul then
		local lost = snap.Soul - now.Soul
		local use = math.min(virt.Black, lost)
		virt.Black = virt.Black - use
	end
	spend_virtual(virt, "Bone", snap.Bone - now.Bone)
	spend_virtual(virt, "Rotten", snap.Rotten - now.Rotten)
	spend_virtual(virt, "Golden", snap.Golden - now.Golden)
	spend_virtual(virt, "Eternal", snap.Eternal - now.Eternal)
	spend_virtual(virt, "Battery", snap.Battery - now.Battery)
	if virt.Card and virt.Card ~= 0 and virt.CardSlot and player:GetCard(virt.CardSlot) ~= virt.Card then
		virt.Card = 0
		virt.CardSlot = nil
	end
	if virt.Pill and virt.Pill ~= 0 and virt.PillSlot and player:GetPill(virt.PillSlot) ~= virt.Pill then
		virt.Pill = 0
		virt.PillSlot = nil
	end
	player:GetData()[item.own_key.."snap"] = now
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_, ent, amt, flag, source, cooldown)
	if amt <= 0 then return end
	if flag & DamageFlag.DAMAGE_FAKE == DamageFlag.DAMAGE_FAKE then return end
	if not tagged(ent) or not ent:ToNPC() then return end
	spawn_reality_tear(ent.Position, (ent.Size or 20) * 2.2)
	ent:Remove()
	local st = error_state()
	if st.Type == ERR_ENEMY then
		st.Type = nil
		st.Seed = nil
	end
	return false
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_, ent)
	if tagged(ent) then
		ent.CanShutDoors = false
		tick_glitch(ent, 45, 75)
		return
	end
	tick_decoy_glitch(ent)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_, ent)
	if tagged(ent) then
		tick_glitch(ent, 45, 75)
	else
		tick_decoy_glitch(ent)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PROJECTILE_INIT, params = nil,
Function = function(_, proj)
	local spawner = proj.SpawnerEntity
	if spawner and tagged(spawner) then
		mark_illusion(proj, nil)
		local c = proj:GetSprite().Color
		proj:GetSprite().Color = Color(c.R, c.G, c.B, math.min(c.A, 0.88), 0.03, 0, -0.03)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PROJECTILE_UPDATE, params = nil,
Function = function(_, proj)
	if tagged(proj) then tick_glitch(proj, 50, 90) end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local gch = item.screen_glitch
	if gch and (gch.timer or 0) > 0 then
		gch.timer = gch.timer - 1
		if gch.timer <= 0 then item.screen_glitch = nil end
	end
	if item.hud_ghost_next and item.hud_ghost_next > 0 then
		item.hud_ghost_next = item.hud_ghost_next - 1
	else
		item.hud_ghost_flip = not item.hud_ghost_flip
		item.hud_ghost_next = 30 + math.random(0, 30)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_, name)
	if name ~= DESYNC_SHADER then return end
	if Game():IsPauseMenuOpen() then return empty_desync_params() end
	return pack_desync_params()
end,
})

local hud_cb = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER
table.insert(item.ToCall, #item.ToCall + 1, {CallBack = hud_cb, params = nil,
Function = function(_)
	if not Game():GetHUD():IsVisible() then return end
	render_reclaim_fx()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	render_reality_tears()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then return end
	local st = error_state()
	if not st.Seed then return end
	delay_buffer.addeffe(function()
		local ents = Isaac.GetRoomEntities()
		for i = 1, #ents do
			if ents[i].InitSeed == st.Seed then
				ents[i]:GetData()[item.own_key.."illusion"] = true
				if ents[i]:ToNPC() then ents[i]:ToNPC().CanShutDoors = false end
			end
		end
		if st.CopiedItem and st.CopiedPlayer ~= nil then
			local player = Game():GetPlayer(st.CopiedPlayer)
			if auxi.check_all_exists(player) then player:GetData()[item.own_key.."copied"] = st.CopiedItem end
		end
	end, nil, 1)
end,
})

do
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	temp_hud.register_provider(function(player)
		local id = player:GetData()[item.own_key.."copied"]
		id = tonumber(id)
		if not id or id <= 0 then return end
		local effects = player:GetEffects()
		if not effects or not effects:HasCollectibleEffect(id) then
			player:GetData()[item.own_key.."copied"] = nil
			return
		end
		return {[id] = 1}
	end, {
		color = Color(1, 1, 1, 0.65, 0, 0, 0, 0.2, 0.15, 0.28, 0.35),
		source_item = item.entity,
		ghost = true,
		ghost_alpha = 0.2,
		ghost_fn = function()
			if item.hud_ghost_flip then return Vector(-2, 1) end
			return Vector(2, -1)
		end,
	})
end

return item

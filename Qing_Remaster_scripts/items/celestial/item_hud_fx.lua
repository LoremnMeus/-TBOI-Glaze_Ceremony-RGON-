-- Ketu / Rahu helpers for active-charge ledger, Block* ownership, icon tears,
-- and HUD tint redraw (History Extra HUD + physical trinket slots).
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local CraftTearParams = require("Qing_Remaster_scripts.others.craft_tear_params_data")
local CraftFamiliar = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")

local M = {}

M.KETU_ACTIVE_BONUS = 4
M.RAHU_ACTIVE_COST = 1
M.RAHU_ACTIVE_INTERVAL = 12 -- PEFFECT 30Hz → 0.4s
M.RAHU_ITEM_INTERVAL = 18
M.RAHU_ITEM_DAMAGE_MULT = 3.25
M.RAHU_TEAR_HEIGHT = -23.75
M.RAHU_ITEM_RANGE = 1040

-- HUD tint modes: Colorize on near-white Tint (see color_tint_colorize_offset_pitfalls).
M.HUD_TINT = {
	-- Rahu extract / block
	purple = Color(1, 1, 1, 1, 0, 0, 0, 0.55, 0.22, 1.15, 1),
	-- Ketu amplify (direct target)
	gold = Color(1, 1, 1, 1, 0.12, 0.06, 0, 1.25, 0.95, 0.35, 1),
	-- Same-ID siblings self-drawn without gold mark
	neutral = Color(1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0),
}

local GOLD = TrinketType.TRINKET_GOLDEN_FLAG or 32768
local _collectible_sprites = {}
local _trinket_sprites = {}

function M.compose_trinket_id(base, golden)
	base = tonumber(base) or 0
	if golden then
		return base | GOLD
	end
	return base
end

function M.split_trinket_id(raw)
	raw = tonumber(raw) or 0
	local golden = (raw & GOLD) ~= 0
	local base = raw & 0x7FFF
	return base, golden
end

local function set_charges(player, slot, main, battery)
	main = math.max(0, math.floor(tonumber(main) or 0))
	battery = math.max(0, math.floor(tonumber(battery) or 0))
	if player.SetActiveCharge then
		player:SetActiveCharge(main, slot)
	end
	if battery > 0 and player.AddActiveCharge then
		player:AddActiveCharge(battery, slot, false, true, true)
	end
end

function M.read_charges(player, slot)
	local main = (player.GetActiveCharge and player:GetActiveCharge(slot)) or 0
	local bat = (player.GetBatteryCharge and player:GetBatteryCharge(slot)) or 0
	return main, bat, main + bat
end

--- Grant charge. Overcharge stays on the yellow bar; normal charge refills the green bar.
--- Returns the amount the engine actually added.
function M.grant_charge(player, slot, amount, overcharge)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 or not player or not player.AddActiveCharge then
		return 0
	end
	local added = player:AddActiveCharge(amount, slot, false, overcharge == true, true)
	if type(added) ~= "number" then
		return amount
	end
	return math.max(0, math.floor(added))
end

--- Grant overcharge (The Battery yellow bar) without merging into green.
function M.grant_temp_charge(player, slot, amount)
	return M.grant_charge(player, slot, amount, true)
end

--- Put an unspent Rahu drain back on the bars it came from.
function M.restore_drained_charge(player, slot, main, battery)
	local got_main = M.grant_charge(player, slot, main, false)
	local got_bat = M.grant_charge(player, slot, battery, true)
	return got_main, got_bat
end

--- Remove up to `amount` from battery first, then main. Returns removed count.
function M.reduce_charge(player, slot, amount)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 or not player then
		return 0
	end
	local main, bat = M.read_charges(player, slot)
	local take_bat = math.min(amount, bat)
	local take_main = math.min(amount - take_bat, main)
	set_charges(player, slot, main - take_main, bat - take_bat)
	return take_bat + take_main
end

--- Prefer spending Ketu temp ledger remaining on this slot; then real charge.
--- `ketu_eff` may be nil. Mutates ketu_eff.charge_remaining when present.
function M.spend_charge_prefer_temp(player, slot, amount, ketu_eff)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then
		return 0
	end
	local from_temp = 0
	if ketu_eff and type(ketu_eff.charge_remaining) == "number" and ketu_eff.charge_remaining > 0 then
		from_temp = math.min(amount, ketu_eff.charge_remaining)
		ketu_eff.charge_remaining = ketu_eff.charge_remaining - from_temp
		amount = amount - from_temp
		-- Temp was already on the bar as overcharge; remove it from the bar too.
		if from_temp > 0 then
			M.reduce_charge(player, slot, from_temp)
		end
	end
	local from_real = 0
	if amount > 0 then
		from_real = M.reduce_charge(player, slot, amount)
	end
	return from_temp + from_real
end

--- Claim BlockCollectible if free / already ours. Returns true if we own a claim.
function M.claim_block_collectible(st, player, item_id, token)
	item_id = tonumber(item_id) or 0
	if item_id <= 0 or not player or not player.BlockCollectible then
		return false
	end
	st.block_collectible = st.block_collectible or {}
	local row = st.block_collectible[item_id]
	if row then
		row.tokens = row.tokens or {}
		row.tokens[token] = true
		row.count = (row.count or 0) + 1
		return true
	end
	if player.IsCollectibleBlocked and player:IsCollectibleBlocked(item_id) then
		-- Foreign block: do not claim; caller may still fire visuals.
		return false, "foreign"
	end
	player:BlockCollectible(item_id)
	st.block_collectible[item_id] = {
		count = 1,
		tokens = {[token] = true},
	}
	if player.AddCacheFlags then
		player:AddCacheFlags(CacheFlag.CACHE_ALL, true)
	end
	return true
end

function M.release_block_collectible(st, player, item_id, token)
	item_id = tonumber(item_id) or 0
	if item_id <= 0 or not st.block_collectible then
		return
	end
	local row = st.block_collectible[item_id]
	if not row then
		return
	end
	if token and row.tokens then
		if not row.tokens[token] then
			return
		end
		row.tokens[token] = nil
	end
	row.count = math.max(0, (row.count or 1) - 1)
	if row.count > 0 then
		return
	end
	st.block_collectible[item_id] = nil
	if player and player.UnblockCollectible and player.IsCollectibleBlocked
		and player:IsCollectibleBlocked(item_id) then
		player:UnblockCollectible(item_id)
		if player.AddCacheFlags then
			player:AddCacheFlags(CacheFlag.CACHE_ALL, true)
		end
	end
end

function M.claim_block_trinket(st, player, trinket_id, token)
	trinket_id = tonumber(trinket_id) or 0
	if trinket_id <= 0 or not player or not player.BlockTrinket then
		return false
	end
	st.block_trinket = st.block_trinket or {}
	local row = st.block_trinket[trinket_id]
	if row then
		row.tokens = row.tokens or {}
		row.tokens[token] = true
		row.count = (row.count or 0) + 1
		return true
	end
	if player.IsTrinketBlocked and player:IsTrinketBlocked(trinket_id) then
		return false, "foreign"
	end
	player:BlockTrinket(trinket_id)
	st.block_trinket[trinket_id] = {
		count = 1,
		tokens = {[token] = true},
	}
	if player.AddCacheFlags then
		player:AddCacheFlags(CacheFlag.CACHE_ALL, true)
	end
	return true
end

function M.release_block_trinket(st, player, trinket_id, token)
	trinket_id = tonumber(trinket_id) or 0
	if trinket_id <= 0 or not st.block_trinket then
		return
	end
	local row = st.block_trinket[trinket_id]
	if not row then
		return
	end
	if token and row.tokens then
		if not row.tokens[token] then
			return
		end
		row.tokens[token] = nil
	end
	row.count = math.max(0, (row.count or 1) - 1)
	if row.count > 0 then
		return
	end
	st.block_trinket[trinket_id] = nil
	if player and player.UnblockTrinket and player.IsTrinketBlocked
		and player:IsTrinketBlocked(trinket_id) then
		player:UnblockTrinket(trinket_id)
		if player.AddCacheFlags then
			player:AddCacheFlags(CacheFlag.CACHE_ALL, true)
		end
	end
end

function M.is_collectible_blocked_by_us(st, item_id)
	return st.block_collectible and st.block_collectible[tonumber(item_id) or -1] ~= nil
end

function M.is_trinket_blocked_by_us(st, trinket_id)
	return st.block_trinket and st.block_trinket[tonumber(trinket_id) or -1] ~= nil
end

local function load_icon_onto_tear(tear, gfx_path)
	if not tear or not gfx_path or gfx_path == "" then
		return false
	end
	local s = tear:GetSprite()
	if not s then
		return false
	end
	-- Centered icon host (Rooted Demon flying icon); collision stays on EntityTear.
	s:Load("gfx/mimics/Rooted_Demon/flying_icon.anm2", true)
	s:ReplaceSpritesheet(0, gfx_path)
	s:LoadGraphics()
	s:Play("Idle", true)
	return true
end

function M.apply_collectible_icon(tear, collectible_id)
	local cfg = Isaac.GetItemConfig():GetCollectible(tonumber(collectible_id) or 0)
	if not cfg or not cfg.GfxFileName then
		return false
	end
	return load_icon_onto_tear(tear, cfg.GfxFileName)
end

function M.apply_trinket_icon(tear, trinket_id)
	local base = M.split_trinket_id(trinket_id)
	local cfg = Isaac.GetItemConfig():GetTrinket(base)
	if not cfg or not cfg.GfxFileName then
		return false
	end
	return load_icon_onto_tear(tear, cfg.GfxFileName)
end

function M.fire_icon_tear(player, origin, direction, opts)
	opts = opts or {}
	if not player or not origin or not direction then
		return nil
	end
	local speed = tonumber(opts.speed) or 11
	local dir = direction:Normalized()
	if dir:Length() < 0.01 then
		dir = Vector(0, -1)
	end
	local vel = dir * speed
	local tear = attack_holder.FireTear(player, origin, vel, {
		mode = "untracked",
		damage_multiplier = tonumber(opts.damage_mult) or M.RAHU_ITEM_DAMAGE_MULT,
		can_be_eye = false,
		can_trigger_streak_end = false,
	})
	if not tear then
		return nil
	end
	local h = M.RAHU_TEAR_HEIGHT
	local fa, fs, fall_meta = CraftTearParams.falling_for_range_vanilla(
		h, M.RAHU_ITEM_RANGE, nil, speed
	)
	tear.Height = (fall_meta and fall_meta.height) or h
	tear.FallingAcceleration = fa
	tear.FallingSpeed = fs
	if EntityGridCollisionClass and EntityGridCollisionClass.GRIDCOLL_NONE then
		tear.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	end
	if CraftFamiliar and CraftFamiliar.arm_tear_cancel_po_y_fade then
		CraftFamiliar.arm_tear_cancel_po_y_fade(tear, 8)
	end
	if opts.jacobs and tear.AddTearFlags then
		tear:AddTearFlags(TearFlags.TEAR_JACOBS)
	end
	if opts.spectral ~= false and tear.AddTearFlags then
		tear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
	end
	if opts.collectible_id then
		M.apply_collectible_icon(tear, opts.collectible_id)
	elseif opts.trinket_id then
		M.apply_trinket_icon(tear, opts.trinket_id)
	end
	tear.Scale = tonumber(opts.scale) or 1.15
	return tear
end

local function hud_scale()
	return (Options.ExtraHUDStyle or 1) == 2 and 0.5 or 1
end

local function tint_color(mode)
	return M.HUD_TINT[mode] or M.HUD_TINT.neutral
end

local function collectible_sprite(id)
	id = tonumber(id) or 0
	if id <= 0 then
		return nil
	end
	local s = _collectible_sprites[id]
	if s then
		return s
	end
	s = Sprite()
	-- Centered 16×16 host (same as icon tears); Render at icon center.
	s:Load("gfx/mimics/Rooted_Demon/flying_icon.anm2", true)
	if EntityPickup and EntityPickup.SetupCollectibleGraphics then
		EntityPickup.SetupCollectibleGraphics(s, 0, id, false, 1, true)
	else
		local cfg = Isaac.GetItemConfig():GetCollectible(id)
		if cfg and cfg.GfxFileName then
			s:ReplaceSpritesheet(0, cfg.GfxFileName)
			s:LoadGraphics()
		end
	end
	s:Play("Idle", true)
	_collectible_sprites[id] = s
	return s
end

local function trinket_sprite(trinket_id)
	local base = M.split_trinket_id(trinket_id)
	if base <= 0 then
		return nil
	end
	local s = _trinket_sprites[base]
	if s then
		return s
	end
	s = Sprite()
	s:Load("gfx/mimics/Rooted_Demon/flying_icon.anm2", true)
	local cfg = Isaac.GetItemConfig():GetTrinket(base)
	if cfg and cfg.GfxFileName then
		s:ReplaceSpritesheet(0, cfg.GfxFileName)
		s:LoadGraphics()
	end
	s:Play("Idle", true)
	_trinket_sprites[base] = s
	return s
end

--- Draw collectible icon centered at `center` with tint mode purple|gold|neutral.
function M.draw_collectible_hud_icon(collectible_id, center, scale, mode)
	if not center then
		return
	end
	local s = collectible_sprite(collectible_id)
	if not s then
		return
	end
	scale = tonumber(scale) or hud_scale()
	s.Color = tint_color(mode)
	s.Scale = Vector(scale, scale)
	s:Render(center, Vector.Zero, Vector.Zero)
	s.Color = Color(1, 1, 1, 1)
end

--- Physical trinket HUD: `position` is vanilla top-left of 32×32 slot.
function M.draw_trinket_hud_icon(trinket_id, position, scale, mode)
	if not position then
		return
	end
	scale = tonumber(scale) or 1
	local center = position + Vector(16 * scale, 16 * scale)
	local s = trinket_sprite(trinket_id)
	if not s then
		return
	end
	s.Color = tint_color(mode)
	s.Scale = Vector(scale, scale)
	s:Render(center, Vector.Zero, Vector.Zero)
	s.Color = Color(1, 1, 1, 1)
end

--- History Extra HUD cell: anchor is icon center (base + offset + (16,16)*scale).
function M.draw_history_collectible(collectible_id, center, mode)
	M.draw_collectible_hud_icon(collectible_id, center, hud_scale(), mode)
end

function M.draw_history_trinket(trinket_id, center, mode)
	if not center then
		return
	end
	local s = trinket_sprite(trinket_id)
	if not s then
		return
	end
	local scale = hud_scale()
	s.Color = tint_color(mode)
	s.Scale = Vector(scale, scale)
	s:Render(center, Vector.Zero, Vector.Zero)
	s.Color = Color(1, 1, 1, 1)
end

return M

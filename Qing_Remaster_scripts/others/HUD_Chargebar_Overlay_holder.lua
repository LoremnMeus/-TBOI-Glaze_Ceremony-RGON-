-- HUD 主动充能条格线：原版 ui_chargebar 没有的上限（目前 10 格）叠在 ChargeBarOffset 上。
-- 倍增重刃 XML 10 格、罐中雷暴把上限改到 10 时都会走到这里。
local time_holder = require("Qing_Remaster_scripts.others.Time_holder")

local item = {
	ToCall = {},
	post_ToCall = {},
	anm2 = "gfx/ui/other_chargebar.anm2",
}

-- 原版 gfx/ui/ui_chargebar.anm2 已有的 BarOverlay。
local VANILLA_OVERLAY = {
	[1] = true, [2] = true, [3] = true, [4] = true,
	[5] = true, [6] = true, [8] = true, [12] = true,
}

local CUSTOM_ANIM = {
	[10] = "BarOverlay10",
}

local overlay_spr = nil
local overlay_loaded = false

local function ensure_sprite()
	if overlay_loaded then return overlay_spr end
	overlay_spr = Sprite()
	overlay_spr:Load(item.anm2, true)
	overlay_spr.PlaybackSpeed = 0
	overlay_loaded = true
	return overlay_spr
end

local function displayed_max_charge(player, slot, cid)
	local max_charge = nil
	if player.GetActiveMaxCharge then
		max_charge = player:GetActiveMaxCharge(slot)
	end
	if type(max_charge) ~= "number" or max_charge <= 0 then
		local cfg = cid and Isaac.GetItemConfig():GetCollectible(cid)
		max_charge = cfg and cfg.MaxCharges or 0
	end
	return math.floor(tonumber(max_charge) or 0)
end

function item.overlay_anim(max_charge)
	max_charge = math.floor(tonumber(max_charge) or 0)
	if max_charge <= 0 then return nil end
	if VANILLA_OVERLAY[max_charge] then return nil end
	return CUSTOM_ANIM[max_charge]
end

function item.render(player, slot, charge_bar_offset, alpha, scale, cid)
	if not player or not charge_bar_offset then return end
	cid = cid or player:GetActiveItem(slot)
	if not cid or cid <= 0 then return end
	local cfg = Isaac.GetItemConfig():GetCollectible(cid)
	if not cfg then return end
	if (cfg.MaxCharges or 0) <= 0 then return end
	-- 计时充能没有格线。
	if (cfg.ChargeType or 0) == 1 then return end
	local anim = item.overlay_anim(displayed_max_charge(player, slot, cid))
	if not anim then return end
	alpha = tonumber(alpha)
	if alpha == nil then alpha = 1 end
	if alpha <= 0 then return end
	scale = tonumber(scale) or 1
	local spr = ensure_sprite()
	spr:SetFrame(anim, 0)
	spr.Scale = Vector(scale, scale)
	spr.Color = Color(1, 1, 1, alpha)
	spr:Render(charge_bar_offset, Vector(0, 0), Vector(0, 0))
end

if REPENTOGON and ModCallbacks.MC_POST_PLAYERHUD_RENDER_ACTIVE_ITEM then
	table.insert(item.post_ToCall, #item.post_ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PLAYERHUD_RENDER_ACTIVE_ITEM,
		params = nil,
		Function = function(_, player, slot, _, alpha, scale, charge_bar_offset)
			if time_holder.IsUpper() ~= true then return end
			local hud = Game():GetHUD()
			if hud and hud.IsVisible and not hud:IsVisible() then return end
			item.render(player, slot, charge_bar_offset, alpha, scale)
		end,
	})
end

return item

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")
local GiantBook_holder = require("Qing_Remaster_scripts.others.GiantBook_holder")

-- 堆叠覆盖序：前者盖后者 → 渲染时按逆序（后者先画）
-- D8 > D20 > D100 > D10 > D12 > D-1 > D7 > D4 > D6 > D1
local STACK_COVER_ORDER = {8, 20, 100, 10, 12, -1, 7, 4, 6, 1}
local BASE_SHEET = "gfx/items/collectibles/collectibles_D_Upper.png"

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.D_Plus,
	own_key = "Item_D_Plus_",
	max_charge = 6,
	Loadinfos = {
		-- 按 STACK_COVER_ORDER 的逆序排列（先画的在下）
		{id = 1, check = function(val) return val >= 1 end, replacename = "gfx/items/collectibles/D_Plus/collectibles_D1.png", colid = 476},
		{id = 6, replacename = "gfx/items/collectibles/D_Plus/D6.png", colid = 105},
		{id = 4, replacename = "gfx/items/collectibles/D_Plus/D4.png", colid = 284, special = function() GiantBook_holder.PlayGiantBook({Loader = "gfx/ui/giantbook/giantbook.anm2", Anim = "Shake", Init = function(s, info) s:ReplaceSpritesheet(0, "gfx/ui/giantbook/giantbook_rebirth_003_d4.png") s:LoadGraphics() end}) end},
		{id = 7, replacename = "gfx/items/collectibles/D_Plus/D7.png", colid = 437},
		{id = -1, check = function(val) return val < 0 end, replacename = "gfx/items/collectibles/D_Plus/D-1.png", colid = 723},
		{id = 12, replacename = "gfx/items/collectibles/D_Plus/D12.png", colid = 386, special = function() GiantBook_holder.PlayGiantBook({Loader = "gfx/ui/giantbook/giantbook.anm2", Anim = "Shake", Init = function(s, info) s:ReplaceSpritesheet(0, "gfx/ui/giantbook/giantbook_rebirth_013_d12.png") s:LoadGraphics() end}) end},
		{id = 10, replacename = "gfx/items/collectibles/D_Plus/D10.png", colid = 285, special = function() GiantBook_holder.PlayGiantBook({Loader = "gfx/ui/giantbook/giantbook.anm2", Anim = "Shake", Init = function(s, info) s:ReplaceSpritesheet(0, "gfx/ui/giantbook/giantbook_rebirth_004_d10.png") s:LoadGraphics() end}) end},
		{id = 100, replacename = "gfx/items/collectibles/D_Plus/D100.png", colid = 283, special = function() GiantBook_holder.PlayGiantBook({Loader = "gfx/ui/giantbook/giantbook.anm2", Anim = "Shake", Init = function(s, info) s:ReplaceSpritesheet(0, "gfx/ui/giantbook/giantbook_rebirth_006_d100.png") s:LoadGraphics() end}) end},
		{id = 20, replacename = "gfx/items/collectibles/D_Plus/D20.png", colid = 166},
		{id = 8, replacename = "gfx/items/collectibles/D_Plus/D8.png", colid = 406, special = function() GiantBook_holder.PlayGiantBook({Loader = "gfx/ui/giantbook/giantbook.anm2", Anim = "Shake", Init = function(s, info) s:ReplaceSpritesheet(0, "gfx/ui/giantbook/giantbook_rebirth_012_d8.png") s:LoadGraphics() end}) end},
	},
}

local function effect_bag()
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	return save.elses[item.own_key.."effect"]
end

--- 旧存档 `id` = 下一次使用时判定因数的 D（显示值）；新语义 `current_d` = 已达到的 D（初始 0）。
local function migrate_effect(bag)
	if bag.current_d ~= nil then
		return
	end
	local old_id = bag.id
	if old_id == nil then
		bag.current_d = 0
	else
		bag.current_d = math.max(0, math.floor(tonumber(old_id) or 1) - 1)
	end
	bag.id = nil
end

function item.get_current_d()
	local bag = effect_bag()
	migrate_effect(bag)
	return math.max(0, math.floor(tonumber(bag.current_d) or 0))
end

function item.set_current_d(val)
	local bag = effect_bag()
	migrate_effect(bag)
	bag.current_d = math.max(0, math.floor(tonumber(val) or 0))
	bag.id = nil
end

--- 预览：当前充能全部用于步长后的 D
function item.preview_after_d(player, slot)
	local cur = item.get_current_d()
	if not player then
		return cur, 0
	end
	slot = slot or ActiveSlot.SLOT_PRIMARY
	local charge = math.floor(tonumber(player:GetActiveCharge(slot)) or 0)
	if charge < 1 then
		return cur, 0
	end
	return cur + charge, charge
end

local function factor_matches(info, val)
	return auxi.check_if_any(info.check or function(n) return n % info.id == 0 end, val)
end

local function make_face_sprite(info)
	local s = Sprite()
	s:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2")
	s:Play("Idle", true)
	local sheet = info.replacename or BASE_SHEET
	s:ReplaceSpritesheet(0, sheet)
	s:LoadGraphics()
	return {s = s, replacename = sheet}
end

local info_by_id = {}
for _, v in ipairs(item.Loadinfos) do
	info_by_id[v.id] = v
end

--- 按堆叠覆盖序取会触发的面（返回表为自下而上渲染序）
function item.get_sprites(d_value)
	local ret = {}
	d_value = math.floor(tonumber(d_value) or 0)
	if d_value == 0 then
		return ret
	end
	-- STACK_COVER_ORDER 前者盖后者 → 逆序先画
	for i = #STACK_COVER_ORDER, 1, -1 do
		local id = STACK_COVER_ORDER[i]
		local info = info_by_id[id]
		if info and factor_matches(info, d_value) then
			table.insert(ret, make_face_sprite(info))
		end
	end
	return ret
end

--- EID 预览：会触发的原版骰子 Collectible id（小号在前）
local EID_FACTOR_ORDER = {1, 4, 6, 7, 8, 10, 12, 20, 100, -1}
function item.get_trigger_colids(d_value)
	local ret = {}
	d_value = math.floor(tonumber(d_value) or 0)
	if d_value == 0 then
		return ret
	end
	for _, id in ipairs(EID_FACTOR_ORDER) do
		local info = info_by_id[id]
		if info and factor_matches(info, d_value) then
			ret[#ret + 1] = info.colid
		end
	end
	return ret
end

local function find_d_plus_slot(player)
	if not player then
		return nil
	end
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		if player:GetActiveItem(slot) == item.entity then
			return slot
		end
	end
	return nil
end

local function trigger_factors(player, d_value)
	d_value = math.floor(tonumber(d_value) or 0)
	if d_value <= 0 then
		return
	end
	for _, v in ipairs(item.Loadinfos) do
		if factor_matches(v, d_value) then
			player:UseActiveItem(v.colid, UseFlag.USE_NOANIM, 0)
			auxi.check_if_any(v.special)
		end
	end
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."effect"] = {}
	end
	local bag = effect_bag()
	migrate_effect(bag)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, colid, rng, player, useFlags, activeSlot, customVarData)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return {Discharge = false, ShowAnim = false}
	end
	activeSlot = activeSlot or ActiveSlot.SLOT_PRIMARY
	local charge = math.floor(tonumber(player:GetActiveCharge(activeSlot)) or 0)
	if charge < 1 then
		return {Discharge = false, ShowAnim = false}
	end
	local new_d = item.get_current_d() + charge
	item.set_current_d(new_d)
	trigger_factors(player, new_d)
	return {Discharge = true, ShowAnim = true}
end,
})

if REPENTOGON and ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE, params = item.entity,
	Function = function(_, _, _, _)
		return 1
	end,
	})
end

-- 取消原版主动图标/白边；暗底 + 可用骰子改由 POST_SLOT_RENDER 自绘
if ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM, params = item.entity,
	Function = function(_, player, slot)
		if player:GetActiveItem(slot) ~= item.entity then
			return
		end
		return {HideItem = true, HideOutline = true}
	end,
	})
end

local ffont = Font()
ffont:Load("font/luaminioutlined.fnt")

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_, player, tp, cid, slot)
	if cid ~= item.entity then
		return
	end
	local pos = ui.PlayerActiveUIPos(player, slot, auxi.GetPlayerOrder(player), cid)
	local cur = item.get_current_d()
	local after_d, spent = item.preview_after_d(player, slot)
	local preview_d = (spent >= 1) and after_d or cur
	local c = slot_render_holder.get_alpha()
	local shadow_col = Color(c * 0.38, c * 0.38, c * 0.38, 1)
	local lit_col = Color(c, c, c, 1)

	-- 暗色完整底座（D_Upper 已是全骰拼合）
	local base = make_face_sprite({replacename = BASE_SHEET})
	base.s.Color = shadow_col
	base.s:Render(pos, Vector(0, 0), Vector(0, 0))

	-- 可用骰：先全部白边，再按堆叠序画本体（后者先画、前者盖上）
	local lit = item.get_sprites(preview_d)
	if spent >= 1 then
		for _, v in ipairs(lit) do
			auxi.render_border(pos, v, {color = lit_col})
		end
	end
	for _, v in ipairs(lit) do
		v.s.Color = lit_col
		v.s:Render(pos, Vector(0, 0), Vector(0, 0))
	end

	gui.draw_ch(pos + Vector(-8, -16), tostring(preview_d), 1, 1, auxi.Color_2_KColor(lit_col), true, ffont)
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_, player, tp, id, value)
	if tp == "Item" and id == item.entity then
		local after_d, spent = item.preview_after_d(player, ActiveSlot.SLOT_PRIMARY)
		if spent >= 1 then
			value.Name = "D+" .. tostring(after_d)
		else
			value.Name = "D+" .. tostring(item.get_current_d())
		end
		return value
	end
end,
})

if EID then
	-- 持有时追加：当前充能结算后的 D 与会触发的骰子图标
	EID:addDescriptionModifier("qing_d_plus_preview", function(desc)
		return desc.ObjType == 5 and desc.ObjVariant == 100 and desc.ObjSubType == item.entity
			and auxi.have_player_has_collectible(item.entity)
	end, function(desc)
		local player = auxi.have_player_has_collectible(item.entity)
		local slot = find_d_plus_slot(player)
		if not player or not slot then
			return desc
		end
		local after_d, spent = item.preview_after_d(player, slot)
		if spent < 1 then
			return desc
		end
		local colids = item.get_trigger_colids(after_d)
		if #colids < 1 then
			return desc
		end
		local lang = auxi.get_EID_language()
		local zh = lang == "zh_cn" or lang == "zh" or (type(lang) == "string" and string.sub(lang, 1, 2) == "zh")
		local line = zh
			and ("#{{Collectible" .. tostring(item.entity) .. "}} 本次→D" .. tostring(after_d) .. "：")
			or ("#{{Collectible" .. tostring(item.entity) .. "}} Next→D" .. tostring(after_d) .. ": ")
		for _, cid in ipairs(colids) do
			line = line .. "{{Collectible" .. tostring(cid) .. "}}"
		end
		EID:appendToDescription(desc, line)
		return desc
	end)
end

return item

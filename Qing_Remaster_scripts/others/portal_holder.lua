-- Fool / Wizard portal config owner：捕获可序列化目的地，回房 / rewind 后重新绑到 Effect 1000/161。
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local special_dest = require("Qing_Remaster_scripts.others.Special_Destination_holder")

local M = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	own_key = "Portal_holder_",
	effect_variant = 161,
	anm2 = "gfx/cards/cd01_wiz_port.anm2",
	sheet_prefix = "gfx/effects/portals/cd01_wiz_port_",
}

-- 必须与 Card_01_Wizard PRE_GET_TELEPORT 读取的 GetData 键一致
M.runtime_effect_key = "Thoth_cd1_Wiz_effect"
M.runtime_others_key = "Thoth_cd1_Wiz_others"
M.config_key = M.own_key.."portal_config"
M.debug = {
	probe_enabled = false,
	sink = nil,
}

local side_effects = {}

local function portal_ptr(ent)
	local h
	pcall(function()
		h = GetPtrHash(ent)
	end)
	return h
end

local function emit_portal(event, ent, extra)
	if M.debug.probe_enabled ~= true then
		return
	end
	local row = {
		source = "portal_holder",
		event = tostring(event or "?"),
	}
	pcall(function()
		row.frame = Isaac.GetFrameCount()
	end)
	pcall(function()
		row.room_frame = Game():GetRoom():GetFrameCount()
	end)
	pcall(function()
		row.room = Game():GetLevel():GetCurrentRoomIndex()
	end)
	if ent then
		row.ptr = portal_ptr(ent)
		row.init_seed = ent.InitSeed
		row.type = ent.Type
		row.variant = ent.Variant
		row.subtype = ent.SubType
		local d = ent.GetData and ent:GetData()
		row.runtime_config = d and d[M.runtime_effect_key] ~= nil
		local info = d and d[M.runtime_effect_key]
		if type(info) == "table" then
			row.gidx = info.gidx
			row.dim = info.dim
			row.tp = info.tp
		end
	end
	local n
	pcall(function()
		n = select(1, consistance_holder.count_owner_records(M.config_key))
	end)
	row.portal_records = n or 0
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			row[k] = v
		end
	end
	local probe = package.loaded["Qing_Remaster_scripts.debug.portal_restore_rewind_probe"]
	if type(probe) == "table" and type(probe.record_external) == "function" then
		pcall(probe.record_external, row)
	end
end

local function is_scalar(v)
	local t = type(v)
	return t == "number" or t == "string" or t == "boolean"
end

local function copy_plain(value, depth)
	depth = depth or 0
	if depth > 4 then
		return nil
	end
	if is_scalar(value) then
		return value
	end
	if type(value) ~= "table" then
		return nil
	end
	local out = {}
	for k, v in pairs(value) do
		if type(k) == "number" or type(k) == "string" then
			local copied = copy_plain(v, depth + 1)
			if copied ~= nil then
				out[k] = copied
			end
		end
	end
	return out
end

local function sanitize_info(info)
	if type(info) ~= "table" then
		return nil
	end
	local out = {}
	for _, key in ipairs({"id", "tp", "gidx", "dim", "replace_tp", "special_id"}) do
		if is_scalar(info[key]) then
			out[key] = info[key]
		end
	end
	return out
end

local function sanitize_others(params)
	if type(params) ~= "table" then
		return {}
	end
	local out = {}
	if is_scalar(params.special_id) then
		out.special_id = params.special_id
	end
	local place = copy_plain(params.Record_place)
	if place then
		out.Record_place = place
	end
	return out
end

local function infer_special_id(info, others)
	if others.special_id then
		return others.special_id
	end
	if info and info.special_id then
		return info.special_id
	end
	if info and info.gidx ~= nil then
		local def = special_dest.get_by_room_index(info.gidx)
		if def and def.key then
			return def.key
		end
	end
	return nil
end

local function rebuild_others(stored)
	local others = sanitize_others(stored)
	local sid = others.special_id
	if sid then
		local spec = side_effects[sid]
		if spec then
			others.Special = spec.Special
			others.On_Arrive = spec.On_Arrive
		end
	end
	return others
end

local function apply_eid(ent, info)
	if not EID or not ent or not info then
		return
	end
	local language = EID.UserConfig and EID.UserConfig.Language or "zh_cn"
	if language == "auto" then
		language = "zh_cn"
	end
	local eid = special_dest.get_portal_eid(info.tp, language)
	if not eid then
		local wiz = package.loaded["Qing_Remaster_scripts.cards.Card_01_Wizard"]
		if wiz and wiz.port_desc and wiz.port_desc[language] then
			eid = wiz.port_desc[language][info.tp]
		end
	end
	if eid then
		ent:GetData().EID_Description = eid
	end
end

function M.register_side_effect(id, spec)
	if type(id) ~= "string" or type(spec) ~= "table" then
		return false
	end
	side_effects[id] = spec
	return true
end

function M.is_fool_portal(ent)
	if not ent then
		return false
	end
	if ent.Type ~= EntityType.ENTITY_EFFECT then
		return false
	end
	if ent.Variant ~= M.effect_variant then
		return false
	end
	return ent.SubType == enums.Cards.Wizard
end

function M.apply_portal_config(ent, info, params, opts)
	if not M.is_fool_portal(ent) then
		return false
	end
	opts = opts or {}
	info = info or {id = -1, tp = 117, gidx = 84, dim = 0}
	params = params or {}
	local s = ent:GetSprite()
	s:Load(M.anm2, true)
	if opts.restored then
		s:Play("Idle", true)
	else
		s:Play("Appear", true)
	end
	local tp = info.tp or 117
	for i = 0, 5 do
		s:ReplaceSpritesheet(i, M.sheet_prefix..tostring(tp)..".png")
	end
	s:LoadGraphics()
	local d = ent:GetData()
	d[M.runtime_effect_key] = auxi.deepCopy(info)
	if opts.restored then
		d[M.runtime_others_key] = rebuild_others(params)
	else
		d[M.runtime_others_key] = params
	end
	apply_eid(ent, info)
	return true
end

function M.capture_portal_config(ent, info, params)
	if not M.is_fool_portal(ent) then
		return false
	end
	local d = ent:GetData()
	info = sanitize_info(info or d[M.runtime_effect_key])
	if not info then
		return false
	end
	local others = sanitize_others(params or d[M.runtime_others_key])
	local sid = infer_special_id(info, others)
	if sid then
		others.special_id = sid
		info.special_id = info.special_id or sid
	end
	d._Data = d._Data or {}
	d._Data[M.config_key] = {
		info = info,
		others = others,
	}
	consistance_holder.try_hold_entity(ent, M.config_key, {
		room_restore_persistent = true,
		consistance = true,
	})
	local extra = {
		gidx = info.gidx,
		dim = info.dim,
		tp = info.tp,
	}
	pcall(function()
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		extra.room_type = desc.Data.Type
		local save = package.loaded["Qing_Remaster_scripts.core.savedata"]
		local wiz = save and save.elses and save.elses["Thoth_cd1_Wiz_effect"]
		if type(wiz) == "table" then
			extra.wizard_value = wiz[desc.Data.Type]
		end
	end)
	emit_portal("PORTAL_CAPTURE", ent, extra)
	return true
end

function M.restore_portal_config(ent)
	if not M.is_fool_portal(ent) then
		return false
	end
	local d = ent:GetData()
	if d[M.runtime_effect_key] then
		emit_portal("PORTAL_RESTORE_RESULT", ent, {success = true, reason = "already"})
		return true
	end
	local ok = consistance_holder.try_check_entity(ent, M.config_key)
	if not ok then
		emit_portal("PORTAL_RESTORE_RESULT", ent, {success = false, reason = "miss"})
		return false
	end
	local stored = d._Data and d._Data[M.config_key]
	if not stored or not stored.info then
		emit_portal("PORTAL_RESTORE_RESULT", ent, {success = false, reason = "data_missing"})
		return false
	end
	M.apply_portal_config(ent, stored.info, stored.others, {restored = true})
	M.capture_portal_config(ent, stored.info, stored.others)
	emit_portal("PORTAL_RESTORE_RESULT", ent, {
		success = true,
		reason = "hit",
		gidx = stored.info.gidx,
		dim = stored.info.dim,
		tp = stored.info.tp,
		restored_info = stored.info,
	})
	return true
end

table.insert(M.ToCall, {
	CallBack = ModCallbacks.MC_POST_EFFECT_INIT,
	params = M.effect_variant,
	Function = function(_, ent)
		if M.is_fool_portal(ent) then
			local d = ent:GetData()
			emit_portal("PORTAL_EFFECT_INIT", ent, {
				runtime_config = d and d[M.runtime_effect_key] ~= nil,
			})
		end
		M.restore_portal_config(ent)
	end,
})

table.insert(M.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		local list = Isaac.FindByType(EntityType.ENTITY_EFFECT, M.effect_variant, enums.Cards.Wizard)
		for _, ent in ipairs(list) do
			M.restore_portal_config(ent)
		end
	end,
})

return M

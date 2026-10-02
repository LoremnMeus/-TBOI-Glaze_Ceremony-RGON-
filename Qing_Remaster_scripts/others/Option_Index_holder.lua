local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Option_Index_holder_",
	--- Short-lived Option-selection evidence (runtime only; never saved).
	selection_txns = {},
	next_selection_id = 0,
}

--- Option selection evidence retention, derived from observed loser cleanup (P2: write→Record Remove ≈4f);
--- not a gameplay delay. Only retains already-established selection truth.
local SELECTION_EVIDENCE_FRAMES = 8

--- Loser-selection truth is owned by Option_Index_holder transaction state.
--- Entity GetData Remove/Pick flags are compatibility/live hints only and must
--- not be used as authoritative evidence after entity lifetime ends.

function item.find_a_new_index()
	local ret = 0
	local banned = {}
	local n_entity = Isaac.GetRoomEntities()
	local n_pickups = auxi.getpickups(n_entity,false)
	for u,v in pairs(n_pickups) do
		local pk = v:ToPickup()
		if pk then
			if pk.OptionsPickupIndex then
				banned[pk.OptionsPickupIndex] = true
			end
		end
	end
	for i = 1,1000 do
		if banned[i] ~= true then
			return i
		end
	end
	return ret		--查询失败
end

local function game_frame()
	local ok, n = pcall(function() return Game():GetFrameCount() end)
	return ok and n or -1
end

local function soft_field(ent, field)
	if not ent then return nil end
	local ok, v = pcall(function() return ent[field] end)
	if ok then return v end
	return nil
end

--- Compact identity while entity is alive / for stale-wrapper correlation.
--- SubType excluded: cycle/STATE_SWITCH may change presentation.
local function entity_identity(ent)
	if not ent then return nil end
	local typ = soft_field(ent, "Type")
	local variant = soft_field(ent, "Variant")
	local init_seed = soft_field(ent, "InitSeed")
	local options_index = soft_field(ent, "OptionsPickupIndex")
	if typ == nil or variant == nil or init_seed == nil or options_index == nil then
		return nil
	end
	return {
		type = typ,
		variant = variant,
		init_seed = init_seed,
		options_index = options_index,
	}
end

local function identity_key(id)
	if not id then return nil end
	return tostring(id.type) .. ":" .. tostring(id.variant) .. ":"
		.. tostring(id.init_seed) .. ":" .. tostring(id.options_index)
end

local function txn_all_consumed(txn)
	if not txn or type(txn.losers) ~= "table" then return true end
	for _, loser in pairs(txn.losers) do
		if loser and loser.consumed ~= true then
			return false
		end
	end
	return true
end

local function prune_selection_txns()
	local frame = game_frame()
	local kept = {}
	for i = 1, #item.selection_txns do
		local txn = item.selection_txns[i]
		if txn then
			local age = frame - (txn.frame or frame)
			local expired = age < 0 or age > SELECTION_EVIDENCE_FRAMES
			if not expired and not txn_all_consumed(txn) then
				kept[#kept + 1] = txn
			end
		end
	end
	item.selection_txns = kept
end

function item.clear_selection_txns()
	item.selection_txns = {}
end

--- Public owner API: was this entity an explicit sibling loser of a recent Option selection?
--- Does NOT require readable GetData on a dead wrapper.
function item.was_rejected_by_selection(ent)
	prune_selection_txns()
	local id = entity_identity(ent)
	if not id then return false, nil end
	local key = identity_key(id)
	if not key then return false, nil end
	for i = 1, #item.selection_txns do
		local txn = item.selection_txns[i]
		local slot = txn and txn.losers and txn.losers[key]
		if slot and slot.consumed ~= true then
			slot.consumed = true
			local evidence = {
				selection_id = txn.id,
				frame = txn.frame,
				option_index = txn.option_index,
				picked = txn.picked,
				loser = slot.identity,
			}
			if txn_all_consumed(txn) then
				table.remove(item.selection_txns, i)
			end
			return true, evidence
		end
	end
	return false, nil
end

local function begin_selection_txn(picked, option_index, loser_ents)
	prune_selection_txns()
	item.next_selection_id = (item.next_selection_id or 0) + 1
	local frame = game_frame()
	local picked_id = entity_identity(picked)
	local losers = {}
	for i = 1, #loser_ents do
		local p = loser_ents[i]
		local lid = entity_identity(p)
		local key = identity_key(lid)
		if key and lid then
			losers[key] = {
				identity = lid,
				consumed = false,
			}
		end
	end
	local txn = {
		id = item.next_selection_id,
		frame = frame,
		option_index = option_index,
		picked = picked_id,
		losers = losers,
	}
	item.selection_txns[#item.selection_txns + 1] = txn
	return txn
end

--- Programmatic / collision Options acquisition: begin txn + mark sibling losers.
--- opts.skip_will_collect: Death Field 等外部取得已自行校验，跳过 will_collect
--- opts.remove_siblings: 立即 Remove sibling（程序化吸收必须；真实碰撞留给引擎）
--- opts.effect: remove 时是否 poof（默认 true）
function item.commit_selection(picked, player, opts)
	opts = opts or {}
	local pickup = picked and picked:ToPickup()
	if not pickup then
		return nil, {}
	end
	if (pickup.OptionsPickupIndex or 0) == 0 then
		return nil, {}
	end
	if not opts.skip_will_collect then
		if not player or not auxi.will_collect_pickup(player, pickup) then
			return nil, {}
		end
	end
	local d = pickup:GetData()
	local option_index = pickup.OptionsPickupIndex
	if d[item.own_key .. "Remove"] then
		d[item.own_key .. "Pick"] = true
		return nil, {}
	end

	local n_pickups = auxi.getpickups(nil, false)
	local sibling_ents = {}
	for _, v in pairs(n_pickups) do
		local p = v:ToPickup()
		if p and not auxi.check_for_the_same(p, pickup) and p.OptionsPickupIndex == pickup.OptionsPickupIndex then
			sibling_ents[#sibling_ents + 1] = p
		end
	end

	local txn = begin_selection_txn(pickup, option_index, sibling_ents)
	d[item.own_key .. "Pick"] = true

	local do_remove = opts.remove_siblings == true
	local effect = opts.effect
	if effect == nil then
		effect = true
	end
	for i = 1, #sibling_ents do
		local p = sibling_ents[i]
		if p then
			p:GetData()[item.own_key .. "Remove"] = true
			if do_remove and p:Exists() then
				if effect then
					Isaac.Spawn(1000, 15, 0, p.Position, Vector.Zero, nil)
				end
				p:Remove()
			end
		end
	end
	return txn, sibling_ents
end

--- 同组可以是任意 Type=5 掉落物（心/钥匙/卡牌等），不限底座。
--- 被选中者标 Pick；同组其它成员标 Remove（legacy live hint）。
--- 权威 sibling-reject 证据：selection_txns（跨死亡可查询）。
--- 拾取判定用 auxi.will_collect_pickup（非 will_pick_up）。
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	local pickup = ent and ent:ToPickup()
	if not player or not pickup then return end
	-- 真实碰撞：只建 txn + 标 Remove，sibling 由引擎清
	item.commit_selection(pickup, player, {remove_siblings = false})
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	params = nil,
	Function = function()
		item.clear_selection_txns()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		item.clear_selection_txns()
		item.next_selection_id = 0
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function()
		item.clear_selection_txns()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_END,
	params = nil,
	Function = function()
		item.clear_selection_txns()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		if #item.selection_txns > 0 then
			prune_selection_txns()
		end
	end,
})

return item

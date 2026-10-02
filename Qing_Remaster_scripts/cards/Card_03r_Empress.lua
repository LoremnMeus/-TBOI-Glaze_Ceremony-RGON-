local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local gen_audit = require("Qing_Remaster_scripts.others.Generation_audit_holder")

local EMPRESS_AUDIT_OWNER = "Empress"
local QUESTION_SHEET = "gfx/items/collectibles/to_be_question_mark.png"
local EMPRESS_PROBE_PATH = "Qing_Remaster_scripts.debug.empress_d6_timeline_probe"

--- 只读挂钩：仅 package.loaded，禁止 require 探针。
local function empress_probe_obs(kind, ent, extra)
	local probe = package.loaded[EMPRESS_PROBE_PATH]
	if type(probe) == "table" and probe.observe_empress then
		pcall(probe.observe_empress, kind, ent, extra)
	end
end

local function empress_probe_suppresses()
	local probe = package.loaded[EMPRESS_PROBE_PATH]
	return type(probe) == "table"
		and probe.suppresses_empress_decisions
		and probe.suppresses_empress_decisions() == true
end

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Empress_r,
	own_key = "Thoth_cd3r_Emp_",
	own_key2 = "Thoth_cd3r_Emp2_",
	-- Consumer Regression 只读统计；禁止业务分支读这些字段
	debug_cr = {
		first_seen_consumed = 0,
		applied = 0,
		skipped_touched = 0,
		retry_scheduled = 0,
		retry_applied = 0,
		last_generation_id = nil,
		last_source = nil,
	},
}

function item.reset_debug_cr()
	item.debug_cr.first_seen_consumed = 0
	item.debug_cr.applied = 0
	item.debug_cr.skipped_touched = 0
	item.debug_cr.retry_scheduled = 0
	item.debug_cr.retry_applied = 0
	item.debug_cr.last_generation_id = nil
	item.debug_cr.last_source = nil
end

function item.get_debug_cr()
	return {
		first_seen_consumed = item.debug_cr.first_seen_consumed or 0,
		applied = item.debug_cr.applied or 0,
		skipped_touched = item.debug_cr.skipped_touched or 0,
		retry_scheduled = item.debug_cr.retry_scheduled or 0,
		retry_applied = item.debug_cr.retry_applied or 0,
		last_generation_id = item.debug_cr.last_generation_id,
		last_source = item.debug_cr.last_source,
	}
end

--- debug-only：真正接管某 generation 的 first-seen 消费时 +1；业务禁止读此字段
--- 无 gid 不得计数（否则会把「等 Unique」误记成消费）
local function empress_debug_note_first_seen(gid, source)
	if gid == nil then return end
	item.debug_cr.first_seen_consumed = (item.debug_cr.first_seen_consumed or 0) + 1
	item.debug_cr.last_generation_id = gid
	item.debug_cr.last_source = source
end

--- 已摸过的底座（含换下主动）永不套女帝问号/标价。
--- opts.log_probe：仅 Morph/INIT 等关键路径打 ELIGIBILITY，避免 can_affect 被价检刷屏。
local function empress_can_affect(ent, opts)
	opts = opts or {}
	local pickup = ent and (ent.ToPickup and ent:ToPickup() or ent) or nil
	local result = false
	local reject = "other"
	local gid = nil
	repeat
		if not pickup then reject = "other"; break end
		if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then reject = "invalid_variant"; break end
		if (pickup.SubType or 0) <= 0 then reject = "empty"; break end
		if pickup.Touched then reject = "touched"; break end
		local config = Isaac:GetItemConfig()
		local collectibleinfo = config:GetCollectible(pickup.SubType)
		if not collectibleinfo then reject = "other"; break end
		if collectibleinfo.Tags & ItemConfig.TAG_QUEST == ItemConfig.TAG_QUEST then reject = "quest"; break end
		result = true
		reject = "ok"
	until true
	if opts.log_probe then
		local gen = pickup and unique_holder.get_generation(pickup) or nil
		gid = gen and gen.id
		local d = pickup and pickup:GetData() or nil
		empress_probe_obs("EMPRESS_ELIGIBILITY_CHECK", pickup, {
			result = result,
			reject_reason = reject,
			Touched = pickup and pickup.Touched == true,
			SubType = pickup and pickup.SubType,
			generation_id = gid,
			effect = d and d[item.own_key .. "effect"] == true,
		})
	end
	return result
end

--- 女帝人造价 / 默认 ShopItemId=0：必须改成 -1，否则 D6 按房间货位滚成卡/心。
--- 原本就是商店货位的则保留 ShopItemId。real_shop 写入 Consistance，防 Morph 清 Data。
local function empress_stamp_shop_identity(ent)
	local d = ent:GetData()
	if d[item.own_key .. "shop_stamped"] then
		if d[item.own_key .. "real_shop"] ~= true then
			ent.ShopItemId = -1
			ent.AutoUpdatePrice = false
		end
		return
	end
	-- Morph 后优先从 Consistance 恢复身份
	local succ2 = consistance_holder.try_check_entity(ent, item.own_key2)
	if succ2 and d._Data and d._Data[item.own_key2]
		and d._Data[item.own_key2][item.own_key .. "real_shop"] ~= nil
	then
		local real = d._Data[item.own_key2][item.own_key .. "real_shop"] == true
		d[item.own_key .. "real_shop"] = real
		d[item.own_key .. "shop_stamped"] = true
		if real then
			local sid = d._Data[item.own_key2][item.own_key .. "shop_id"]
			if type(sid) == "number" then
				ent.ShopItemId = sid
			end
		else
			ent.ShopItemId = -1
			ent.AutoUpdatePrice = false
		end
		return
	end
	local price_before = ent.Price or 0
	local sid = ent.ShopItemId
	-- 仅「标价前已是商店货」算真货位；女帝刚写的 Price 不能用来判断
	local real = price_before ~= 0 and ent:IsShopItem() and type(sid) == "number" and sid >= 0
	d[item.own_key .. "real_shop"] = real == true
	d[item.own_key .. "shop_stamped"] = true
	if real then
		d[item.own_key .. "shop_id"] = sid
	else
		ent.ShopItemId = -1
		ent.AutoUpdatePrice = false
	end
end

--- RGON：SetForceBlind；问号 sheet 作贴图兜底。
--- 注意：对真商店货避免 ReloadGraphics（易按当前 ShopItemIdx 重绑货位）。
local function empress_set_blind(ent, on)
	local pickup = ent and (ent.ToPickup and ent:ToPickup() or ent) or nil
	if not pickup then return end
	local d = pickup:GetData()
	local real_shop = d[item.own_key .. "real_shop"] == true
	if on then
		if pickup.SetForceBlind then
			pcall(function()
				pickup:SetForceBlind(true)
			end)
		end
		-- 非真商店才 ReloadGraphics；真商店只换 sheet，避免 ShopItemId 被房间 Idx 污染
		if not real_shop and pickup.ReloadGraphics then
			pcall(function()
				pickup:ReloadGraphics(false)
			end)
		end
		local s = pickup:GetSprite()
		if s then
			s:ReplaceSpritesheet(1, QUESTION_SHEET)
			s:LoadGraphics()
		end
		if d[item.own_key .. "real_shop"] ~= true then
			pickup.ShopItemId = -1
		end
	else
		if pickup.SetForceBlind then
			pcall(function()
				pickup:SetForceBlind(false)
			end)
		end
	end
end

--- price_holder 在 POST_NEW_ROOM 会 reset；标价必须在其后（延迟 1 游戏帧）。
--- 延迟回调仍须 !Touched：换下主动后绝不能再写价。
local function empress_schedule_price(ent)
	delay_buffer.addeffe(function()
		if auxi.check_all_exists(ent) ~= true then return end
		if not empress_can_affect(ent) then return end
		local d = ent:GetData()
		if not (save.elses[item.own_key .. "effect"] and d[item.own_key .. "effect"]) then return end
		empress_stamp_shop_identity(ent)
		if not price_holder.have_catched_price(ent) then
			if ent.Price == 0 then ent.Price = 15 end
			price_holder.catch_price_over(ent)
		elseif ent.Price == 0 then
			ent.Price = 15
			price_holder.catch_price_over(ent)
		end
		if d[item.own_key .. "real_shop"] ~= true then
			ent.ShopItemId = -1
			ent.AutoUpdatePrice = false
		end
	end, {}, 1)
end

local function empress_hold_consistance(ent)
	local d = ent:GetData()
	consistance_holder.try_hold_entity(ent, item.own_key)
	consistance_holder.try_hold_over_entity(ent, item.own_key2)
	if d._Data and d._Data[item.own_key2] then
		d._Data[item.own_key2][item.own_key .. "record"] = ent.SubType
		d._Data[item.own_key2][item.own_key .. "real_shop"] = d[item.own_key .. "real_shop"] == true
		if d[item.own_key .. "real_shop"] == true then
			d._Data[item.own_key2][item.own_key .. "shop_id"] = d[item.own_key .. "shop_id"] or ent.ShopItemId
		end
	end
	consistance_holder.try_hold_entity(ent, item.own_key2, { ignore_subtype = true })
end

local function empress_apply_question(ent, opts)
	opts = opts or {}
	if not empress_can_affect(ent) then return false end
	if empress_probe_suppresses() then
		empress_probe_obs("EMPRESS_APPLY", ent, { suppressed = true })
		return false
	end
	local d = ent:GetData()
	local price_before = ent.Price
	local effect_before = d[item.own_key .. "effect"] == true
	local gen = unique_holder.get_generation(ent)
	empress_stamp_shop_identity(ent)
	empress_hold_consistance(ent)
	empress_set_blind(ent, true)
	d[item.own_key .. "effect"] = true
	if opts.immediate_price then
		if ent.Price == 0 then ent.Price = 15 end
		price_holder.catch_price_over(ent)
		if d[item.own_key .. "real_shop"] ~= true then
			ent.ShopItemId = -1
			ent.AutoUpdatePrice = false
		end
	else
		empress_schedule_price(ent)
	end
	empress_probe_obs("EMPRESS_APPLY", ent, {
		generation_id = gen and gen.id,
		Touched = ent.Touched == true,
		price_before = price_before,
		price_after = ent.Price,
		effect_before = effect_before,
		effect_after = true,
	})
	item.debug_cr.applied = (item.debug_cr.applied or 0) + 1
	item.debug_cr.last_generation_id = gen and gen.id
	item.debug_cr.last_source = "apply"
	return true
end

--- 换下主动 / 摸过后：撤女帝价、问号、Consistance，恢复可白嫖。
local function empress_strip_touched(ent)
	if not ent then return end
	local d = ent:GetData()
	local gen = unique_holder.get_generation(ent)
	local had_effect = d[item.own_key .. "effect"] == true
	local had_consistance = consistance_holder.try_check_entity(ent, item.own_key) == true
		or consistance_holder.try_check_entity(ent, item.own_key2) == true
	local had = had_effect
		or had_consistance
		or price_holder.have_catched_price(ent)
	-- 无事可撤时不打探针（否则 Touched 底座每帧刷屏）
	if not had then return end
	local price_before = ent.Price
	empress_probe_obs("EMPRESS_STRIP", ent, {
		generation_id = gen and gen.id,
		Touched = ent.Touched == true,
		had_effect = had_effect,
		had_consistance = had_consistance,
		price_before = price_before,
		will_strip = true,
		suppressed = empress_probe_suppresses(),
	})
	if empress_probe_suppresses() then return end
	empress_set_blind(ent, false)
	if price_holder.have_catched_price(ent) then
		consistance_holder.try_remove_entity(ent, price_holder.own_key, { ignore_subtype = true })
	end
	consistance_holder.try_remove_entity(ent, item.own_key)
	consistance_holder.try_remove_entity(ent, item.own_key2)
	-- 非真商店人造价：清价；真商店保留原货位价逻辑给引擎
	if d[item.own_key .. "real_shop"] ~= true then
		ent.AutoUpdatePrice = true
		ent.Price = 0
		ent.ShopItemId = -1
	end
	d[item.own_key .. "effect"] = nil
	d[item.own_key .. "shop_stamped"] = nil
	d[item.own_key .. "real_shop"] = nil
	d[item.own_key .. "shop_id"] = nil
end

local function empress_ensure_epoch()
	if save.elses[item.own_key .. "effect"] and not gen_audit.is_active(EMPRESS_AUDIT_OWNER) then
		gen_audit.begin_epoch(EMPRESS_AUDIT_OWNER)
	end
end

local function empress_try_first_seen(ent, source_hint)
	if not save.elses[item.own_key .. "effect"] then return false end
	empress_ensure_epoch()
	if not gen_audit.is_active(EMPRESS_AUDIT_OWNER) then return false end
	if not empress_can_affect(ent) then return false end
	local gen = unique_holder.resolve_generation(ent)
	local gid = gen and gen.id
	local src = source_hint or (gen and gen.source) or "UNKNOWN"
	local epoch = gen_audit.get_epoch(EMPRESS_AUDIT_OWNER)
	if not gid then
		-- resolve nil = 真正 unresolved；不得当成 first-seen
		empress_probe_obs("EMPRESS_FIRST_SEEN_CHECK", ent, {
			generation_id = nil,
			epoch = epoch,
			seen_before = false,
			source = src,
			first_seen_result = false,
			unresolved = true,
		})
		return false
	end
	local seen_before = gen_audit.has_seen(EMPRESS_AUDIT_OWNER, gid) == true
	local first = gen_audit.check_and_mark(EMPRESS_AUDIT_OWNER, gid, { source = src })
	empress_probe_obs("EMPRESS_FIRST_SEEN_CHECK", ent, {
		generation_id = gid,
		epoch = epoch,
		seen_before = seen_before,
		source = src,
		first_seen_result = first == true,
	})
	return first
end

local function empress_sweep_room(source_hint, opts)
	opts = opts or {}
	if not save.elses[item.own_key .. "effect"] then return end
	empress_ensure_epoch()
	local n_entity = Isaac.GetRoomEntities()
	for _, v in pairs(n_entity) do
		if v.Type == 5 and v.Variant == 100 then
			local p = v:ToPickup()
			if p and p.Touched then
				empress_strip_touched(p)
			elseif empress_can_affect(p) then
				local d = p:GetData()
				local already = d[item.own_key .. "effect"] == true
				local blind_ok = (not p.IsBlind) or p:IsBlind()
				local succ = consistance_holder.try_check_entity(p, item.own_key) == true
				local gen = unique_holder.resolve_generation(p)
				empress_probe_obs("EMPRESS_SWEEP_CHECK", p, {
					source = source_hint or "epoch_scan",
					already = already,
					succ = succ,
					generation_id = gen and gen.id,
					generation_kind = gen and gen.kind,
				})
				-- 价/盲盒已齐：只维持商店身份，不重跑 apply
				if already and blind_ok and price_holder.have_catched_price(p) and (p.Price or 0) ~= 0 then
					if d[item.own_key .. "real_shop"] ~= true then
						p.ShopItemId = -1
					end
				else
					-- CR-1：already/Consistance 不得绕过 epoch audit，否则回房会二次 apply_question
					local first = empress_try_first_seen(p, source_hint or "epoch_scan")
					if first then
						empress_debug_note_first_seen(gen and gen.id, source_hint or "epoch_scan")
						empress_apply_question(p, opts)
					elseif already or succ then
						empress_probe_obs("EMPRESS_STALE_SKIP", p, {
							reason = already and "effect_flag" or "consistance_succ",
							generation_id = gen and gen.id,
							generation_kind = gen and gen.kind,
							touched = false,
							source = source_hint or "epoch_scan",
						})
						empress_stamp_shop_identity(p)
						empress_set_blind(p, true)
						d[item.own_key .. "effect"] = true
						if d[item.own_key .. "real_shop"] ~= true then
							p.ShopItemId = -1
						end
					end
				end
			end
		end
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = nil
		if gen_audit.is_active(EMPRESS_AUDIT_OWNER) then
			gen_audit.end_epoch(EMPRESS_AUDIT_OWNER)
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = nil
	if gen_audit.is_active(EMPRESS_AUDIT_OWNER) then
		gen_audit.end_epoch(EMPRESS_AUDIT_OWNER)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = 100,
Function = function(_,ent,val)
	local d = ent:GetData()
	if save.elses[item.own_key.."effect"] and d[item.own_key.."effect"] and not ent.Touched then
		local config = Isaac:GetItemConfig()
		local collectibleinfo = config:GetCollectible(ent.SubType)
		if collectibleinfo then
			if val == -1000 then val = 0 end
			if val >= 0 then
				local ret = math.ceil(collectibleinfo.Quality * (save.elses[item.own_key.."effect"] or 7) * val / 15)
				if ret == 0 then ret = -1000 end
				return ret
			end
		end
	end
end,
})

local PENDING_RETRY_KEY = "pending_untouched_retry"

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 100,
Function = function(_,ent)
	-- 换下主动：Touched 后立刻撤价，不能只靠 PRE_CHECK_PRICE（Price 字段仍可能是 15）
	if ent.Touched then
		empress_strip_touched(ent)
		return
	end
	if not save.elses[item.own_key .. "effect"] then return end

	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		d[item.own_key .. PENDING_RETRY_KEY] = nil
		local succ2 = consistance_holder.try_check_entity(ent,item.own_key2)
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ2 then
			if succ ~= true then
				consistance_holder.try_remove_entity(ent,item.own_key,{record_subtype = d._Data[item.own_key2][item.own_key.."record"],})
				consistance_holder.try_remove_entity(ent,item.own_key2)
			end
		else
			if ent.SubType == 0 then
				empress_set_blind(ent, false)
				local s = ent:GetSprite()
				s:ReplaceSpritesheet(1,"gfx/effects/nill.png")
				s:LoadGraphics()
			end
			d[item.own_key.."effect"] = nil	
		end
		return
	end

	-- T1：Morph 当帧 Touched 残留 → strip + pending；引擎清 Touched 后在此重试
	local pending = d[item.own_key .. PENDING_RETRY_KEY] == true
	if not empress_can_affect(ent) then return end
	if (not pending) and consistance_holder.try_check_entity(ent, item.own_key) == true then
		return
	end
	if empress_try_first_seen(ent, "pickup_update_retry") then
		local gen = unique_holder.resolve_generation(ent)
		empress_debug_note_first_seen(gen and gen.id, "pickup_update_retry")
		local applied = empress_apply_question(ent, { immediate_price = true })
		d[item.own_key .. PENDING_RETRY_KEY] = nil
		if applied and pending then
			item.debug_cr.retry_applied = (item.debug_cr.retry_applied or 0) + 1
			item.debug_cr.last_source = "pickup_update_retry"
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 100,
Function = function(_,ent)
	if not save.elses[item.own_key.."effect"] then return end
	if ent.Touched then
		empress_can_affect(ent, { log_probe = true })
		empress_strip_touched(ent)
		return
	end
	if not empress_can_affect(ent, { log_probe = true }) then return end
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	local succ2 = consistance_holder.try_check_entity(ent,item.own_key2)
	local d = ent:GetData()
	local gen = unique_holder.resolve_generation(ent)
	local first = empress_try_first_seen(ent, nil)
	if (not first) and succ and gen and gen.kind == "GEN_NEW" then
		empress_probe_obs("EMPRESS_STALE_SKIP", ent, {
			reason = "consistance_succ",
			generation_id = gen.id,
			generation_kind = gen.kind,
			touched = false,
		})
	end
	if first and not succ2 then
		empress_debug_note_first_seen(gen and gen.id, "pickup_init")
		unique_holder.try_spawn_shop_item()
		empress_stamp_shop_identity(ent)
		empress_hold_consistance(ent)
		empress_schedule_price(ent)
	elseif first then
		empress_debug_note_first_seen(gen and gen.id, "pickup_init")
	elseif succ and not price_holder.have_catched_price(ent) then
		empress_schedule_price(ent)
	end
	if succ or first then
		empress_stamp_shop_identity(ent)
		empress_set_blind(ent, true)
		d[item.own_key.."effect"] = true
	end
end,
})

-- D6 / Morph：!Touched 可套女帝；Touched 当帧只 strip（真换下主动）。
-- 探针已证：Touched→D6 时 Morph 常仍见 Touched 残留，引擎稍后清 false —— 由 POST_PICKUP_UPDATE retry。
if ModCallbacks.MC_POST_PICKUP_MORPH then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PICKUP_MORPH,
		params = nil,
		Function = function(_, pickup)
			if not save.elses[item.own_key .. "effect"] then return end
			local p = pickup and (pickup.ToPickup and pickup:ToPickup() or pickup) or nil
			if not p then return end
			if p.Touched then
				empress_can_affect(p, { log_probe = true }) -- 记 reject=touched（Morph 早退）
				empress_strip_touched(p)
				-- 真换下主动会一直 Touched；D6 残留会在随后 UPDATE 变 false → retry
				p:GetData()[item.own_key .. PENDING_RETRY_KEY] = true
				item.debug_cr.skipped_touched = (item.debug_cr.skipped_touched or 0) + 1
				item.debug_cr.retry_scheduled = (item.debug_cr.retry_scheduled or 0) + 1
				item.debug_cr.last_source = "morph_touched_pending"
				return
			end
			if not empress_can_affect(p, { log_probe = true }) then return end
			if empress_try_first_seen(p, "morph_replacement") then
				local gen = unique_holder.resolve_generation(p)
				empress_debug_note_first_seen(gen and gen.id, "morph_replacement")
				empress_apply_question(p, { immediate_price = true })
			elseif p:GetData()[item.own_key .. "effect"] then
				empress_stamp_shop_identity(p)
				empress_set_blind(p, true)
			else
				empress_stamp_shop_identity(p)
				if p:GetData()[item.own_key .. "real_shop"] ~= true then
					p.ShopItemId = -1
				end
			end
		end,
	})
end

-- 进房后扫一次：INIT 可能早于 Unique/Consistance 就绪；并补回被 reset_price 清掉的价
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		if not save.elses[item.own_key .. "effect"] then return end
		delay_buffer.addeffe(function()
			empress_sweep_room("room_enter", {})
		end, {}, 1)
	end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local d = player:GetData()
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return
	end
	Game():RerollLevelCollectibles()
	player:UseActiveItem(105, false, true, true, false)
	if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
		save.elses[item.own_key .. "effect"] = 1
	else
		save.elses[item.own_key .. "effect"] = 5
	end
	gen_audit.begin_epoch(EMPRESS_AUDIT_OWNER)
	-- 用卡当帧：同房可立即标价（不经过 NEW_ROOM reset）
	empress_sweep_room("epoch_scan", { immediate_price = true })
	delay_buffer.addeffe(function()
		empress_sweep_room("epoch_scan", { immediate_price = true })
	end, {}, 0)
	unique_holder.try_spawn_shop_item()
end,
})

-- 不做 DescriptionModifier：EID 走 IsBlind → addQuestionMarkDescription。

return item

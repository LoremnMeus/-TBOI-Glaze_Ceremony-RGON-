-- 里小青蓝图首次使用教学：分步锁定控件、审计模拟材料、结束清理练习机。
-- 贴图后续再补；当前全部用文本框 / 按钮占位。
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local save = require("Qing_Remaster_scripts.core.savedata")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")

local Tut = {
	ToCall = {},
	own_key = "blueprint_tutorial_",
	COL_BRIMSTONE = 118,
	COL_SACRED_HEART = 182,
	COL_KNIFE = 114,
	COL_TWISTED = 698,
	COL_TECH = 68,
	COL_TECH_2 = 152,
	COL_SOY = 330,
	COL_TINY_PLANET = 233,
	STEP = {
		ASK = "ask",
		CRAFT_TAB = "craft_tab",
		CRAFT_BASE = "craft_base",
		CRAFT_MODULE = "craft_module",
		CRAFT_CONFIRM = "craft_confirm",
		TEST_CRAFT = "test_craft",
		FORM_IN = "form_in",
		FORM_OUT = "form_out",
		FORM_CLOSE = "form_close",
		TEST_FORM = "test_form",
		STOCK_TAB = "stock_tab",
		STOCK_OPEN = "stock_open",
		STOCK_SWAP = "stock_swap",
		STOCK_BACK = "stock_back",
		STOCK_DELETE = "stock_delete",
		DONE = "done",
	},
}

local sessions = {}

local HINTS = {
	ask = {
		zh = "第一次拆开蓝图？\n要不要我先手把手带你过一遍？",
		en = "First time cracking this open?\nWant me to walk you through it?",
	},
	craft_tab = {
		zh = "先点上面的「制造」。我们从一架机体开始。",
		en = "Tap Build up top. We'll start with one craft.",
	},
	craft_base = {
		zh = "把圣心拖到机体底下，当作底座。\n底座决定机体框架：品质越高，模块槽越多。\n你自己造的第一架可以不放底座。",
		en = "Drag Sacred Heart under the craft as its base.\nThe base sets the frame: higher quality means more module slots.\nYour first real craft can skip the base.",
	},
	craft_module = {
		zh = "硫磺火是模块，拖进上面的模块槽。\n底座决定机体有多好；模块决定它会什么。",
		en = "Brimstone is a module. Drop it into a module slot.\nThe base sets how strong the craft is; modules set what it can do.",
	},
	craft_confirm = {
		zh = "点「确认制造」。这次走练习通道，\n不会真的扣你背包里的东西。",
		en = "Hit Confirm. This is a practice run —\nit won't take your real items.",
	},
	test_craft = {
		zh = "成了。用射击指挥它打几下。\n中键或 Ctrl 切换巡航/护卫。右键切换自动/压制。打完再打开蓝图。",
		en = "It's live. Fire to command it.\nMMB or Ctrl toggles Cruise / Guard. RMB toggles Auto / Force. Then reopen Blueprint.",
	},
	form_in = {
		zh = "硫磺那架留在上面的出战队列。\n把下面三架练习机（妈刀+扭曲双子 / 科技+科技2 / 豆浆+小小星球）都拖上去。\n队列顺序就是带宽不足时的出战优先级。",
		en = "Keep the Brimstone craft in the deployment queue.\nDrag up the three practice crafts (Knife+Twisted Pair / Tech+Tech 2 / Soy+Tiny Planet).\nQueue order is deployment priority when bandwidth runs short.",
	},
	form_out = {
		zh = "再从队列里任选一架拖回待命。\n待命机不会丢失，只是暂时不出战。\n留下的两架，出去就能对比不同弹种。",
		en = "Now drag any one back down to standby.\nStandby crafts are kept, but do not fight for now.\nThe two left in queue will show different weapons.",
	},
	form_close = {
		zh = "关掉蓝图（右键或放下）。\n关掉后：中键或 Ctrl 切巡航/护卫，右键切自动/压制。",
		en = "Close the Blueprint (right-click or drop it).\nAfter closing: MMB or Ctrl: Cruise / Guard. RMB: Auto / Force.",
	},
	test_form = {
		zh = "指挥剩下的练习机打几下，感受弹种差别。\n中键或 Ctrl 切巡航/护卫，右键切自动/压制。打完再打开蓝图。",
		en = "Command the remaining crafts and feel the weapons.\nMMB or Ctrl: Cruise / Guard. RMB: Auto / Force. Then reopen Blueprint.",
	},
	stock_tab = {
		zh = "点「仓库」。已经造好的机体还能在这里改装或拆除。",
		en = "Open Stock. Built crafts can still be refitted or scrapped here.",
	},
	stock_open = {
		zh = "点开硫磺那架，看看底座和模块怎么放的。",
		en = "Open the Brimstone craft and look at its base and module.",
	},
	stock_swap = {
		zh = "把机体上已经装着的底座和模块对调：\n硫磺拖到下面当底座，圣心拖进上面的模块槽。",
		en = "Swap the pieces already on the craft:\nBrimstone down to the base, Sacred Heart up into a module slot.",
	},
	stock_back = {
		zh = "对调完了就点「返回」，回到列表。",
		en = "When the swap's done, hit Back.",
	},
	stock_delete = {
		zh = "点「删」拆掉练习机。拆一架就会把剩下的一起收走。",
		en = "Hit Del on a practice craft.\nScrapping one clears the rest.",
	},
	done = {
		zh = "教完了，练习机和模拟材料都已经收走。\n你自己造的第一架不用放底座；以后也能随时回仓库改装。",
		en = "Lesson complete. The practice crafts and simulated materials are gone.\nYour first real craft needs no base, and you can refit it later in Stock.",
	},
}

local function get_bp()
	return require("Qing_Remaster_scripts.items.Item_Blue_Print")
end

local function get_bw()
	return require("Qing_Remaster_scripts.mimics.Craft_Bandwidth_Manager")
end

local function lang_zh()
	return Options.Language == "zh" or Options.Language == "zh_cn"
end

local function pick_text(tab)
	if not tab then return "" end
	return lang_zh() and (tab.zh or tab.en) or (tab.en or tab.zh)
end

local function is_spwq(player)
	return player and player:GetPlayerType() == enums.Players.Spwq
end

local function persist_player_key(player)
	local BW = get_bw()
	if BW and BW.persist_player_key then
		return BW.persist_player_key(player)
	end
	if not player then return nil end
	local ok, idx = pcall(function()
		return player:GetData().__Index
	end)
	if ok and idx ~= nil then return tostring(idx) end
	return nil
end

local function session_of(player)
	local k = persist_player_key(player)
	return k and sessions[k] or nil
end

local function panel_player()
	local BP = get_bp()
	return BP.panel and BP.panel.player or nil
end

local function current_session(player)
	player = player or panel_player()
	if player then return session_of(player), player end
	return nil, nil
end

local function each_spwq(fn)
	local n = Game():GetNumPlayers()
	if not n or n < 1 then return end
	for i = 0, n - 1 do
		local p = Game():GetPlayer(i)
		if is_spwq(p) then fn(p) end
	end
end

local FORM_CAP_STEPS = {
	[Tut.STEP.FORM_IN] = true,
	[Tut.STEP.FORM_OUT] = true,
	[Tut.STEP.FORM_CLOSE] = true,
}

local function set_session_step(player, s, step)
	if not s then return end
	local before = FORM_CAP_STEPS[s.step] and 1 or 0
	s.step = step
	local after = FORM_CAP_STEPS[s.step] and 1 or 0
	if before ~= after and player then
		pcall(function() get_bw().mark_dirty(player, "tut_cap") end)
	end
end

local function flags_for(player)
	local BP = get_bp()
	if not player or not BP.get_tutorial_save then return nil end
	return BP.get_tutorial_save(player)
end

local function checkpoint(reason)
	if save.RuntimeLoaded ~= true or type(save.SaveModData) ~= "function" then return end
	pcall(save.SaveModData, "blueprint_tutorial:"..tostring(reason or "unknown"))
end

local function recs_of(player)
	local BP = get_bp()
	local out = {}
	for _, rec in ipairs(BP.get_craft_store(player) or {}) do
		if type(rec) == "table" and rec.uid ~= nil then
			out[#out + 1] = rec
		end
	end
	return out
end

local function uid_is_active(snap, uid)
	return uid ~= nil and snap and snap.effective_active and snap.effective_active[tostring(uid)] == true
end

local function count_dummy_active(player)
	local s = session_of(player)
	if not s or not player then return 0 end
	local snap = get_bw().get_snapshot(player)
	local n = 0
	for _, uid in ipairs(s.dummy_uids or {}) do
		if uid_is_active(snap, uid) then n = n + 1 end
	end
	return n
end

--- 教学机总数（硫磺机 + 练习机）。FORM_OUT「任选一架拖回」必须用这个，不能只数练习机。
local function count_lesson_active(player)
	local s = session_of(player)
	if not s or not player then return 0 end
	local snap = get_bw().get_snapshot(player)
	local n = 0
	if uid_is_active(snap, s.brim_uid) then n = n + 1 end
	for _, uid in ipairs(s.dummy_uids or {}) do
		if uid_is_active(snap, uid) then n = n + 1 end
	end
	return n
end

local function craft_has_col(craft, where, col)
	if not craft or not col then return false end
	if where == "cost" then
		for _, tid in ipairs(craft.cost_ids or {}) do
			local tok = craft.token_map and craft.token_map[tid]
			if tok and tok.collectible == col then return true end
		end
		return false
	end
	for _, slot in ipairs(craft.slots or {}) do
		local tok = slot.token and craft.token_map and craft.token_map[slot.token]
		if tok and tok.collectible == col then return true end
	end
	return false
end

local function pause_real_crafts(player)
	local s = session_of(player)
	if not s or not player then return end
	local BW = get_bw()
	local snap = BW.get_snapshot(player)
	s.saved_wanted = {}
	local changes = {}
	for _, rec in ipairs(recs_of(player)) do
		if rec.tutorial ~= true then
			local k = tostring(rec.uid)
			local wanted = snap.wanted_active[k]
			if wanted == nil then wanted = snap.effective_active[k] == true end
			s.saved_wanted[k] = wanted == true
			changes[k] = false
		end
	end
	BW.apply_wanted_batch(player, changes, "tut_pause")
end

local function restore_real_crafts(player)
	local s = session_of(player)
	if not s or not s.saved_wanted or not player then return end
	get_bw().apply_wanted_batch(player, s.saved_wanted, "tut_restore")
	s.saved_wanted = nil
end

local function cleanup_lesson(player)
	if not player then return end
	restore_real_crafts(player)
	local BP = get_bp()
	if BP.delete_tutorial_crafts then
		BP.delete_tutorial_crafts(player)
	end
	checkpoint("cleanup")
end

local function apply_dummy_names(rec, spec)
	if not rec or not spec then return end
	rec.display_name = spec.zh
	rec.display_name_en = spec.en
end

local DUMMY_SPECS = {
	{zh = "练习机·妈刀双", en = "Practice Knife Pair", kind = "knife", ids = {Tut.COL_KNIFE, Tut.COL_TWISTED}},
	{zh = "练习机·双科技", en = "Practice Dual Tech", kind = "tech", ids = {Tut.COL_TECH, Tut.COL_TECH_2}},
	{zh = "练习机·豆浆星", en = "Practice Soy Planet", kind = "soy", ids = {Tut.COL_SOY, Tut.COL_TINY_PLANET}},
}

local function audit_ingredients(ids)
	local ing = {}
	for i, id in ipairs(ids or {}) do
		ing[i] = {id = id, source = "audit"}
	end
	return ing
end

local function dummy_ids_match(rec, spec)
	if not rec or not spec then return false end
	local want = spec.ids or {}
	local have = {}
	for _, entry in pairs(rec.ingredients or {}) do
		local id = CraftProfile.ingredient_id(entry)
		if id and id > 0 then have[#have + 1] = id end
	end
	if #have ~= #want then return false end
	table.sort(have)
	local sorted = {}
	for i = 1, #want do sorted[i] = want[i] end
	table.sort(sorted)
	for i = 1, #want do
		if have[i] ~= sorted[i] then return false end
	end
	return true
end

local function apply_dummy_spec(player, rec, spec)
	if not rec or not spec then return end
	apply_dummy_names(rec, spec)
	rec.tutorial = true
	rec.lesson_kind = spec.kind or "dummy"
	rec.ingredients = audit_ingredients(spec.ids)
	rec.cost_items = rec.cost_items or {}
	rec.profile = CraftProfile.build_profile(rec.ingredients, {
		player = player,
		rec = rec,
		commit_state = true,
		base_quality = rec.base_quality,
	})
end

local function setup_formation(player)
	local s = session_of(player)
	if not s or not player then return end
	local BP = get_bp()
	local BW = get_bw()
	if not s.brim_uid then
		for _, rec in ipairs(recs_of(player)) do
			if rec.tutorial == true and rec.lesson_kind == "brim" then
				s.brim_uid = rec.uid
				break
			end
		end
	end
	s.dummy_uids = s.dummy_uids or {}
	if #s.dummy_uids < 3 then
		for i = #s.dummy_uids + 1, 3 do
			local spec = DUMMY_SPECS[i]
			local rec = BP.create_audit_craft(player, {
				target = enums.Items.Air_Flight,
				ingredients = audit_ingredients(spec and spec.ids),
				cost_items = {},
				required_cost = 0,
				audit = true,
				tutorial = true,
				lesson_kind = spec and spec.kind or "dummy",
				active = false,
				skip_eval = true,
				display_name = spec and spec.zh,
				display_name_en = spec and spec.en,
			})
			if rec then
				apply_dummy_spec(player, rec, spec)
				s.dummy_uids[#s.dummy_uids + 1] = rec.uid
			end
		end
	end
	for i, uid in ipairs(s.dummy_uids) do
		local rec = BP.find_craft and BP.find_craft(player, uid)
		local spec = DUMMY_SPECS[i]
		if rec and spec and not dummy_ids_match(rec, spec) then
			apply_dummy_spec(player, rec, spec)
		elseif rec and spec then
			apply_dummy_names(rec, spec)
		end
	end
	local changes = {}
	if s.brim_uid then
		changes[tostring(s.brim_uid)] = true
	end
	for _, uid in ipairs(s.dummy_uids) do
		changes[tostring(uid)] = false
	end
	BW.apply_wanted_batch(player, changes, "tut_form_setup")
	-- 面板开着时不要 EvaluateItems：一次刷出三架练习机会把编队页卡死。
	s.form_active_n = count_dummy_active(player)
	s.form_lesson_n = count_lesson_active(player)
end

--- 编队教学：硫磺机留在队列时，再塞进三架练习机需要临时 +1 带宽。
function Tut.extra_capacity_slots(player)
	local s = session_of(player)
	if not s then return 0 end
	if FORM_CAP_STEPS[s.step] then
		return 1
	end
	return 0
end

local function begin_session(player, opts)
	opts = opts or {}
	local key = persist_player_key(player)
	if not key then return end
	if sessions[key] then
		cleanup_lesson(player)
	end
	sessions[key] = {
		owner_key = key,
		step = opts.skip_prompt and Tut.STEP.CRAFT_TAB or Tut.STEP.ASK,
		debug = opts.debug == true,
		brim_uid = nil,
		dummy_uids = {},
		open_uid = nil,
		delete_uid = nil,
		form_active_n = 0,
		form_lesson_n = 0,
		opened_edit = false,
		done_until = -1,
		saved_wanted = nil,
	}
	if opts.skip_prompt then
		pause_real_crafts(player)
	end
end

function Tut.is_active(player)
	local s = select(1, current_session(player))
	return s ~= nil and s.step ~= nil and s.step ~= Tut.STEP.DONE
end

function Tut.is_locking(player)
	local s = select(1, current_session(player))
	if not s then return false end
	local step = s.step
	return step ~= nil and step ~= Tut.STEP.TEST_CRAFT and step ~= Tut.STEP.TEST_FORM and step ~= Tut.STEP.DONE
end

function Tut.step(player)
	local s = select(1, current_session(player))
	return s and s.step or nil
end

function Tut.is_lesson_craft(player)
	local s = select(1, current_session(player))
	return s ~= nil and s.step == Tut.STEP.CRAFT_CONFIRM
end

function Tut.filters_list(player)
	local s = select(1, current_session(player))
	if not s then return false end
	local step = s.step
	return step == Tut.STEP.FORM_IN or step == Tut.STEP.FORM_OUT or step == Tut.STEP.FORM_CLOSE
		or step == Tut.STEP.STOCK_TAB or step == Tut.STEP.STOCK_OPEN
		or step == Tut.STEP.STOCK_SWAP or step == Tut.STEP.STOCK_BACK
		or step == Tut.STEP.STOCK_DELETE
end

function Tut.should_show_rec(rec)
	if not Tut.filters_list() then return true end
	return rec and rec.tutorial == true
end

function Tut.bag_collectibles()
	local s = select(1, current_session())
	if not s then return nil end
	local step = s.step
	if step == Tut.STEP.CRAFT_BASE or step == Tut.STEP.CRAFT_MODULE or step == Tut.STEP.CRAFT_CONFIRM then
		return {Tut.COL_SACRED_HEART, Tut.COL_BRIMSTONE}
	end
	-- 仓库步骤背包永远是空的：对调已装件，不要让玩家从仓库/目录再拖一份。
	if step == Tut.STEP.STOCK_TAB or step == Tut.STEP.STOCK_OPEN or step == Tut.STEP.STOCK_SWAP
		or step == Tut.STEP.STOCK_BACK or step == Tut.STEP.STOCK_DELETE then
		return {}
	end
	return nil
end

--- 教学机 / 教学步骤强制真实背包，禁止打开全道具审计目录。
function Tut.uses_lesson_bag(edit_rec)
	if Tut.bag_collectibles() ~= nil then return true end
	local s = select(1, current_session())
	return s ~= nil and edit_rec ~= nil and edit_rec.tutorial == true
end

--- 教学锁定期间跳过全道具完整性扫描（仓库页每帧扫一遍会卡）。
function Tut.skips_integrity_scan()
	return Tut.is_locking() == true
end

function Tut.blocks_close(player)
	local s = select(1, current_session(player))
	if not Tut.is_locking(player) then return false end
	return s.step ~= Tut.STEP.FORM_CLOSE
end

function Tut.allows_close(player)
	local s = select(1, current_session(player))
	if not s then return true end
	if s.step == Tut.STEP.FORM_CLOSE or s.step == Tut.STEP.DONE then return true end
	if s.step == Tut.STEP.ASK then return false end
	return not Tut.is_locking(player)
end

--- 关面板尝试：已满足当前编队步骤时先推进，再由调用方看 blocks_close。返回是否推进了步骤。
function Tut.note_close_attempt(player)
	player = player or panel_player()
	local s = session_of(player)
	if not s then return false end
	if s.step == Tut.STEP.FORM_IN then
		if count_dummy_active(player) >= 3 then
			s.form_active_n = count_dummy_active(player)
			s.form_lesson_n = count_lesson_active(player)
			set_session_step(player, s, Tut.STEP.FORM_OUT)
			return true
		end
		return false
	end
	if s.step == Tut.STEP.FORM_OUT then
		local n = count_lesson_active(player)
		if n < (s.form_lesson_n or 4) then
			s.form_lesson_n = n
			s.form_active_n = count_dummy_active(player)
			set_session_step(player, s, Tut.STEP.FORM_CLOSE)
			return true
		end
		return false
	end
	return false
end

function Tut.hint(player)
	local s = select(1, current_session(player))
	if not s then return "" end
	return pick_text(HINTS[s.step] or HINTS.ask)
end

function Tut.token_label(_tok)
	return nil
end

function Tut.stamp_lesson_craft(rec)
	if not rec then return end
	rec.tutorial = true
	rec.lesson_kind = "brim"
	rec.display_name = "教学·硫磺空行"
	rec.display_name_en = "Lesson Brimstone"
	local s = select(1, current_session())
	if s then s.brim_uid = rec.uid end
end

function Tut.allow_confirm(craft)
	local s = select(1, current_session())
	if not s then return true end
	if s.step ~= Tut.STEP.CRAFT_CONFIRM then return false end
	return craft_has_col(craft, "cost", Tut.COL_SACRED_HEART)
		and craft_has_col(craft, "slot", Tut.COL_BRIMSTONE)
end

function Tut.allows_token(tok)
	local s = select(1, current_session())
	if not Tut.is_locking() then return true end
	if not tok then return false end
	-- 已入座的不要按“当前步骤可拖”染暗，否则模块槽里的硫磺会看起来像失效。
	if tok.slot or tok.cost then return true end
	local step = s and s.step
	if step == Tut.STEP.CRAFT_BASE then
		return tok.collectible == Tut.COL_SACRED_HEART and tok.cost ~= true
	end
	if step == Tut.STEP.CRAFT_MODULE then
		return tok.collectible == Tut.COL_BRIMSTONE and tok.slot == nil and tok.cost ~= true
	end
	if step == Tut.STEP.STOCK_SWAP then
		return tok.collectible == Tut.COL_SACRED_HEART or tok.collectible == Tut.COL_BRIMSTONE
	end
	return false
end

function Tut.allows_cost_assign(tok)
	local s = select(1, current_session())
	if not Tut.is_locking() then return true end
	if s.step == Tut.STEP.STOCK_SWAP then
		return tok and (tok.collectible == Tut.COL_SACRED_HEART or tok.collectible == Tut.COL_BRIMSTONE)
	end
	if s.step ~= Tut.STEP.CRAFT_BASE then return false end
	return tok and tok.collectible == Tut.COL_SACRED_HEART
end

function Tut.allows_slot_assign(tok)
	local s = select(1, current_session())
	if not Tut.is_locking() then return true end
	if s.step == Tut.STEP.STOCK_SWAP then
		return tok and (tok.collectible == Tut.COL_SACRED_HEART or tok.collectible == Tut.COL_BRIMSTONE)
	end
	if s.step ~= Tut.STEP.CRAFT_MODULE then return false end
	return tok and tok.collectible == Tut.COL_BRIMSTONE
end

local function dummy_set(s)
	local set = {}
	if s then
		for _, uid in ipairs(s.dummy_uids or {}) do
			set[uid] = true
			set[tostring(uid)] = true
		end
	end
	return set
end

function Tut.allows(id)
	local s = select(1, current_session())
	if not Tut.is_locking() then return true end
	if id == nil or not s then return false end
	local step = s.step
	if id == "modal_dim" or id == "panel_body" then
		return step == Tut.STEP.FORM_CLOSE
	end
	if id == "tut_yes" or id == "tut_no" then
		return step == Tut.STEP.ASK
	end
	if id == "tab_2" then
		return step == Tut.STEP.CRAFT_TAB
	end
	if id == "tab_3" then
		return step == Tut.STEP.STOCK_TAB
	end
	if id == "cost_slot" then
		return step == Tut.STEP.CRAFT_BASE or step == Tut.STEP.STOCK_SWAP
	end
	if type(id) == "string" and id:sub(1, 6) == "cslot_" then
		return step == Tut.STEP.CRAFT_MODULE or step == Tut.STEP.STOCK_SWAP
	end
	if id == "btn_confirm" then
		return step == Tut.STEP.CRAFT_CONFIRM
	end
	if id == "btn_back" then
		return step == Tut.STEP.STOCK_BACK
	end
	if id == "btn_quality" then
		return step == Tut.STEP.CRAFT_BASE or step == Tut.STEP.CRAFT_MODULE
			or step == Tut.STEP.CRAFT_CONFIRM or step == Tut.STEP.STOCK_OPEN
			or step == Tut.STEP.STOCK_SWAP or step == Tut.STEP.STOCK_BACK
	end
	if id == "form_queue" or (type(id) == "string" and id:sub(1, 10) == "form_dock_") then
		return step == Tut.STEP.FORM_IN
	end
	if id == "form_bench" then
		return step == Tut.STEP.FORM_OUT
	end
	if type(id) == "string" and id:sub(1, 7) == "form_b_" then
		if step ~= Tut.STEP.FORM_IN then return false end
		local key = id:sub(8)
		local set = dummy_set(s)
		return set[key] == true or (tonumber(key) ~= nil and set[tonumber(key)] == true)
	end
	if type(id) == "string" and id:sub(1, 7) == "form_q_" then
		return step == Tut.STEP.FORM_OUT
	end
	if type(id) == "string" and id:sub(1, 10) == "stock_del_" then
		if step ~= Tut.STEP.STOCK_DELETE then return false end
		local uid = tonumber(id:sub(11))
		if uid == s.brim_uid then return true end
		local set = dummy_set(s)
		return set[uid] == true or set[tostring(uid)] == true or set[id:sub(11)] == true
	end
	if type(id) == "string" and id:sub(1, 6) == "stock_" then
		if step ~= Tut.STEP.STOCK_OPEN then return false end
		return id == "stock_"..tostring(s.open_uid)
	end
	local BP = get_bp()
	local panel = BP.panel
	if panel and panel.craft and panel.craft.token_map then
		local tok = panel.craft.token_map[id]
		if tok then return Tut.allows_token(tok) end
	end
	return false
end

function Tut.status_text()
	local s = select(1, current_session())
	if not s then
		return lang_zh() and "教学：未开始" or "Tutorial: idle"
	end
	local zh = lang_zh()
	return (zh and "教学步骤：" or "Tutorial step: ")..tostring(s.step)
end

function Tut.prepare_overlay(panel, panel_rect)
	local s = panel and session_of(panel.player) or select(1, current_session())
	if not s or not panel_rect then return nil end
	local overlay = {
		hint = Tut.hint(panel and panel.player),
		buttons = {},
		box = nil,
	}
	if s.step == Tut.STEP.ASK then
		local box = {
			x = panel_rect.x + 36,
			y = panel_rect.y + 52,
			w = panel_rect.w - 72,
			h = 118,
		}
		overlay.box = box
		local bw, bh = 108, 18
		local by = box.y + box.h - 28
		overlay.buttons = {
			{
				id = "tut_yes",
				rect = {x = box.x + 24, y = by, w = bw, h = bh},
				label = lang_zh() and "带我过一遍" or "Walk me through",
			},
			{
				id = "tut_no",
				rect = {x = box.x + box.w - 24 - bw, y = by, w = bw, h = bh},
				label = lang_zh() and "我自己摸索" or "I'll figure it out",
			},
		}
	end
	return overlay
end

function Tut.accept(player)
	player = player or panel_player()
	local s = session_of(player)
	if not player or not s then return end
	if s.owner_key and s.owner_key ~= persist_player_key(player) then return end
	local flags = flags_for(player)
	if flags then
		flags.offered = true
		flags.declined = false
		checkpoint("accept")
	end
	pause_real_crafts(player)
	set_session_step(player, s, Tut.STEP.CRAFT_TAB)
end

function Tut.decline(player)
	player = player or panel_player()
	if player then
		local flags = flags_for(player)
		if flags then
			flags.offered = true
			flags.declined = true
			checkpoint("decline")
		end
		local key = persist_player_key(player)
		if key then sessions[key] = nil end
	end
end

function Tut.on_craft_confirmed(rec)
	local s = select(1, current_session())
	if not s then return end
	Tut.stamp_lesson_craft(rec)
	set_session_step(panel_player(), s, Tut.STEP.TEST_CRAFT)
end

function Tut.on_craft_deleted(player, uid)
	player = player or panel_player()
	local s = session_of(player)
	if not s or s.step ~= Tut.STEP.STOCK_DELETE then return end
	if uid == s.delete_uid then
		Tut.complete(player)
	end
end

function Tut.on_panel_opened(player)
	if not player or not is_spwq(player) then return end
	local s = session_of(player)
	if s then
		if s.step == Tut.STEP.TEST_CRAFT then
			set_session_step(player, s, Tut.STEP.FORM_IN)
			setup_formation(player)
			local BP = get_bp()
			if BP.panel then
				BP.panel.tab = 1
				BP.panel.view = "list"
				BP.panel.craft = nil
			end
		elseif s.step == Tut.STEP.TEST_FORM then
			set_session_step(player, s, Tut.STEP.STOCK_TAB)
			if s.brim_uid then
				s.open_uid = s.brim_uid
			end
			s.delete_uid = (s.dummy_uids and s.dummy_uids[1]) or s.brim_uid
		end
		return
	end
	local flags = flags_for(player)
	if not flags then return end
	if flags.offered or flags.done then return end
	begin_session(player, {skip_prompt = false})
end

function Tut.on_panel_closed(player)
	local s = session_of(player)
	if not s then return end
	if s.step == Tut.STEP.FORM_CLOSE then
		set_session_step(player, s, Tut.STEP.TEST_FORM)
		-- 练习机创建时 skip_eval，避免编队页一次刷三架卡死。
		-- 关面板后再 imitate：扭曲双子等审计宝宝才会生成临时实体。
		local BP = get_bp()
		if BP.refresh_audit_simulates then
			BP.refresh_audit_simulates(player)
		elseif player and player.AddCacheFlags then
			player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
			player:EvaluateItems()
		end
	elseif s.step == Tut.STEP.CRAFT_CONFIRM then
		-- confirm_craft 已切到 TEST_CRAFT；此处只兜底
		set_session_step(player, s, Tut.STEP.TEST_CRAFT)
	elseif Tut.blocks_close(player) then
		-- 被强制关掉时不推进
	end
end

function Tut.observe_panel(panel)
	if not panel then return end
	local player = panel.player
	local s = session_of(player)
	if not s then return end
	local step = s.step
	local BP = get_bp()
	if step == Tut.STEP.CRAFT_TAB and panel.tab == 2 and not panel.craft then
		set_session_step(player, s, Tut.STEP.CRAFT_BASE)
		if BP.open_tutorial_craft_view then
			BP.open_tutorial_craft_view(panel)
		end
		return
	end
	local craft = panel.craft
	if craft then
		if step == Tut.STEP.CRAFT_BASE and craft_has_col(craft, "cost", Tut.COL_SACRED_HEART) then
			set_session_step(player, s, Tut.STEP.CRAFT_MODULE)
		elseif step == Tut.STEP.CRAFT_MODULE then
			if not craft_has_col(craft, "cost", Tut.COL_SACRED_HEART) then
				set_session_step(player, s, Tut.STEP.CRAFT_BASE)
			elseif craft_has_col(craft, "slot", Tut.COL_BRIMSTONE) then
				set_session_step(player, s, Tut.STEP.CRAFT_CONFIRM)
			end
		elseif step == Tut.STEP.CRAFT_CONFIRM then
			if not craft_has_col(craft, "slot", Tut.COL_BRIMSTONE) then
				set_session_step(player, s, Tut.STEP.CRAFT_MODULE)
			elseif not craft_has_col(craft, "cost", Tut.COL_SACRED_HEART) then
				set_session_step(player, s, Tut.STEP.CRAFT_BASE)
			end
		end
	end
	if step == Tut.STEP.FORM_IN or step == Tut.STEP.FORM_OUT or step == Tut.STEP.FORM_CLOSE then
		if panel.tab ~= 1 or panel.craft then
			panel.tab = 1
			panel.view = "list"
			panel.craft = nil
			panel.drag = nil
		end
	end
	if step == Tut.STEP.FORM_IN then
		if count_dummy_active(player) >= 3 then
			s.form_active_n = count_dummy_active(player)
			s.form_lesson_n = count_lesson_active(player)
			set_session_step(player, s, Tut.STEP.FORM_OUT)
		end
	elseif step == Tut.STEP.FORM_OUT then
		local n = count_lesson_active(player)
		if n < (s.form_lesson_n or 4) then
			s.form_lesson_n = n
			s.form_active_n = count_dummy_active(player)
			set_session_step(player, s, Tut.STEP.FORM_CLOSE)
		end
	elseif step == Tut.STEP.STOCK_TAB and panel.tab == 3 then
		set_session_step(player, s, Tut.STEP.STOCK_OPEN)
		if not s.open_uid then s.open_uid = s.brim_uid end
	elseif step == Tut.STEP.STOCK_OPEN then
		if craft and craft.edit_uid then
			s.opened_edit = true
			set_session_step(player, s, Tut.STEP.STOCK_SWAP)
		end
	elseif step == Tut.STEP.STOCK_SWAP then
		if craft and craft_has_col(craft, "cost", Tut.COL_BRIMSTONE)
			and craft_has_col(craft, "slot", Tut.COL_SACRED_HEART) then
			set_session_step(player, s, Tut.STEP.STOCK_BACK)
		end
	elseif step == Tut.STEP.STOCK_BACK then
		if s.opened_edit and not craft then
			set_session_step(player, s, Tut.STEP.STOCK_DELETE)
		end
	end
end

function Tut.complete(player)
	player = player or panel_player()
	local key = persist_player_key(player)
	local old = key and sessions[key] or nil
	if player then
		cleanup_lesson(player)
		local flags = flags_for(player)
		if flags then
			flags.offered = true
			flags.done = true
			flags.declined = false
			checkpoint("done")
		end
	end
	if key then
		sessions[key] = {
			owner_key = key,
			step = Tut.STEP.DONE,
			done_until = Game():GetFrameCount() + 90,
			debug = old and old.debug,
		}
	end
end

function Tut.abort(player)
	player = player or panel_player()
	local key = persist_player_key(player)
	if player then cleanup_lesson(player) end
	if key then sessions[key] = nil end
end

function Tut.start(player, opts)
	opts = opts or {}
	player = player or panel_player()
	if not player then return false end
	begin_session(player, opts)
	local flags = flags_for(player)
	if flags and opts.debug then
		flags.offered = true
		checkpoint("debug_start")
	end
	if opts.skip_prompt then
		pause_real_crafts(player)
		local s = session_of(player)
		if s then set_session_step(player, s, Tut.STEP.CRAFT_TAB) end
	end
	local BP = get_bp()
	if BP.panel then
		-- 已打开：保留面板，直接进入询问或制造页
	elseif BP.open_for_player then
		BP.open_for_player(player)
	end
	return true
end

function Tut.reset_flags(player)
	player = player or panel_player()
	if not player then return false end
	local flags = flags_for(player)
	if not flags then return false end
	flags.offered = false
	flags.done = false
	flags.declined = false
	checkpoint("reset_flags")
	return true
end

function Tut.sweep_orphans(player)
	if player then
		if session_of(player) then return end
		local BP = get_bp()
		if BP.delete_tutorial_crafts then
			BP.delete_tutorial_crafts(player)
		end
		return
	end
	each_spwq(Tut.sweep_orphans)
end

local function draw_lines(x, y, text, color, box_w)
	if not text or text == "" then return y end
	color = color or KColor(1, 0.95, 0.78, 1)
	local font = gui.f
	local line_h = (font.GetLineHeight and font:GetLineHeight() or 12) + 1
	box_w = box_w or 0
	for line in string.gmatch(text.."\n", "([^\n]*)\n") do
		if box_w > 0 then
			font:DrawStringScaledUTF8(line, x, y, 1, 1, color, box_w, true)
		else
			font:DrawStringScaledUTF8(line, x, y, 1, 1, color, 0, false)
		end
		y = y + line_h
	end
	return y
end

local function tutorial_world_text_blocked()
	if Game():IsPaused() then return true end
	if REPENTOGON and Game().IsPauseMenuOpen and Game():IsPauseMenuOpen() then return true end
	return false
end

--- 贴屏幕底部，避开页签、暂停/选项字幕和顶部拾取名。暂停检查由调用方负责。
function Tut.draw_bottom_hint(hint, color)
	if not hint or hint == "" then return end
	local screen = gui.GetScreenSize and gui.GetScreenSize() or Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight())
	local w = screen.X or 480
	local h = screen.Y or 270
	local font = gui.f
	local line_h = (font.GetLineHeight and font:GetLineHeight() or 12) + 1
	local n = 0
	for _ in string.gmatch(hint.."\n", "([^\n]*)\n") do
		n = n + 1
	end
	if n < 1 then n = 1 end
	local y = math.max(8, h - 8 - n * line_h)
	draw_lines(8, y, hint, color or KColor(1, 0.94, 0.7, 1), math.floor(w - 16))
end

function Tut.render_hud()
	local frame = Game():GetFrameCount()
	local any = false
	for key, s in pairs(sessions) do
		if s and s.step == Tut.STEP.DONE and frame > (s.done_until or 0) then
			sessions[key] = nil
		elseif s then
			any = true
		end
	end
	if not any then return end
	if tutorial_world_text_blocked() then return end
	local BP = get_bp()
	local player = BP.panel and BP.panel.player
	if player and Tut.is_locking(player) then return end
	local s = select(1, current_session(player))
	if not s then
		for _, row in pairs(sessions) do
			if row and (row.step == Tut.STEP.TEST_CRAFT or row.step == Tut.STEP.TEST_FORM or row.step == Tut.STEP.DONE) then
				s = row
				break
			end
		end
	end
	if not s then return end
	local step = s.step
	if step ~= Tut.STEP.TEST_CRAFT and step ~= Tut.STEP.TEST_FORM and step ~= Tut.STEP.DONE then
		return
	end
	Tut.draw_bottom_hint(pick_text(HINTS[step] or HINTS.ask))
end

table.insert(Tut.ToCall, #Tut.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		Tut.render_hud()
	end,
})

table.insert(Tut.ToCall, #Tut.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		sessions = {}
		Tut.sweep_orphans()
	end,
})

table.insert(Tut.ToCall, #Tut.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function()
		each_spwq(function(p)
			if session_of(p) then Tut.abort(p) end
		end)
		sessions = {}
	end,
})

return Tut

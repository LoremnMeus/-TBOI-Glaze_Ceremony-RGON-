-- Coin-thread BankRun state machine (Greed Branch v1).
-- No UI / entity ownership here — Slot_Bank_Branch / bank_branch consume this API.

local save = require("Qing_Remaster_scripts.core.savedata")

local bank = {}

local INTEREST_RATE = 0.10
local VALUE_BY_QUALITY = {
	[0] = 5,
	[1] = 8,
	[2] = 12,
	[3] = 18,
	[4] = 25,
}

local function empty_stats()
	return {
		total_deposited = 0,
		total_withdrawn = 0,
		total_borrowed = 0,
		total_repaid = 0,
		loans_issued = 0,
		loans_repaid = 0,
		assets_seized = 0,
		robberies = 0,
	}
end

local function empty_branch()
	return {
		closed_pending = false,
		last_cycle_id = nil,
		spawned_cycle_id = nil,
		current_cycle_id = nil,
	}
end

local function empty_hq()
	return {
		entered = false,
		settled = false,
		deposit_claimed = false,
		treasury_spawned = false,
	}
end

local function empty_run()
	return {
		deposit = 0,
		deposit_cycles = 0,
		interest_earned = 0,
		active_loan = nil,
		seized_assets = {},
		next_seized_id = 1,
		branch = empty_branch(),
		headquarters = empty_hq(),
		stats = empty_stats(),
	}
end

function bank.get()
	local root = save.elses
	if type(root.BankRun) ~= "table" then
		root.BankRun = empty_run()
	end
	local b = root.BankRun
	b.deposit = tonumber(b.deposit) or 0
	b.deposit_cycles = tonumber(b.deposit_cycles) or 0
	b.interest_earned = tonumber(b.interest_earned) or 0
	b.seized_assets = b.seized_assets or {}
	b.next_seized_id = tonumber(b.next_seized_id) or 1
	b.branch = b.branch or empty_branch()
	b.headquarters = b.headquarters or empty_hq()
	b.stats = b.stats or empty_stats()
	return b
end

function bank.in_headquarters()
	local hq = bank.get().headquarters
	return hq and hq.entered == true
end

--- Freeze ordinary branch network once the player reaches HQ.
function bank.enter_headquarters()
	local b = bank.get()
	local hq = b.headquarters
	if hq.entered then
		return false, "already"
	end
	hq.entered = true
	-- Stop producing new closed-branch cycles while HQ is active.
	b.branch.closed_pending = false
	return true
end

function bank.can_enter_boss()
	local b = bank.get()
	if b.active_loan ~= nil then
		return false
	end
	return b.headquarters and b.headquarters.settled == true
end

function bank.mark_settled()
	local hq = bank.get().headquarters
	hq.settled = true
	return true
end

function bank.next_seized_id()
	local b = bank.get()
	local id = b.next_seized_id or 1
	b.next_seized_id = id + 1
	return id
end

function bank.withdraw_all(player)
	local amount = bank.get_deposit()
	if amount <= 0 then return false, "empty" end
	return bank.withdraw(player, amount)
end

function bank.claim_seized_asset(record_id)
	if record_id == nil then return false, "no_id" end
	local b = bank.get()
	local assets = b.seized_assets or {}
	for i = #assets, 1, -1 do
		local row = assets[i]
		if row and row.id == record_id then
			table.remove(assets, i)
			return true, row
		end
	end
	return false, "missing"
end

function bank.find_seized_asset(record_id)
	for _, row in ipairs(bank.get().seized_assets or {}) do
		if row and row.id == record_id then
			return row
		end
	end
	return nil
end

function bank.debug_add_seized(item_id, owner_index)
	item_id = tonumber(item_id)
	if not item_id or item_id <= 0 then return false, "bad_item" end
	local b = bank.get()
	local row = {
		id = bank.next_seized_id(),
		item_id = item_id,
		count = 1,
		source = "debug",
		owner_index = owner_index,
	}
	b.seized_assets[#b.seized_assets + 1] = row
	b.stats.assets_seized = (b.stats.assets_seized or 0) + 1
	return true, row
end

function bank.debug_clear_seized()
	bank.get().seized_assets = {}
	return true
end

function bank.reset_headquarters()
	bank.get().headquarters = empty_hq()
	return true
end

function bank.reset()
	save.elses.BankRun = empty_run()
	return save.elses.BankRun
end

function bank.get_deposit()
	return bank.get().deposit
end

function bank.preview_interest(deposit)
	deposit = tonumber(deposit) or bank.get_deposit()
	if deposit <= 0 then return 0 end
	return math.max(1, math.floor(deposit * INTEREST_RATE))
end

function bank.interest_rate()
	return INTEREST_RATE
end

local function owner_key(player)
	if not player then return nil end
	local ok, d = pcall(function() return player:GetData() end)
	if ok and type(d) == "table" and d.__Index ~= nil then
		return d.__Index
	end
	return player.ControllerIndex
end

function bank.resolve_owner(loan)
	if type(loan) ~= "table" or loan.owner_index == nil then
		return Game():GetPlayer(0)
	end
	local n = Game():GetNumPlayers()
	for i = 0, n - 1 do
		local p = Game():GetPlayer(i)
		if p then
			local ok, d = pcall(function() return p:GetData() end)
			if ok and type(d) == "table" and d.__Index == loan.owner_index then
				return p
			end
		end
	end
	-- Fallback: ControllerIndex match, then player 0.
	for i = 0, n - 1 do
		local p = Game():GetPlayer(i)
		if p and p.ControllerIndex == loan.owner_index then
			return p
		end
	end
	return Game():GetPlayer(0)
end

function bank.deposit(player, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 or not player then return false, "bad_amount" end
	if player:GetNumCoins() < amount then return false, "insufficient_coins" end
	player:AddCoins(-amount)
	local b = bank.get()
	b.deposit = b.deposit + amount
	b.stats.total_deposited = (b.stats.total_deposited or 0) + amount
	return true
end

function bank.withdraw(player, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 or not player then return false, "bad_amount" end
	local b = bank.get()
	if b.deposit < amount then return false, "insufficient_deposit" end
	b.deposit = b.deposit - amount
	player:AddCoins(amount)
	b.stats.total_withdrawn = (b.stats.total_withdrawn or 0) + amount
	return true
end

function bank.apply_interest()
	local b = bank.get()
	if b.deposit <= 0 then return 0 end
	local gain = bank.preview_interest(b.deposit)
	b.deposit = b.deposit + gain
	b.interest_earned = (b.interest_earned or 0) + gain
	b.deposit_cycles = (b.deposit_cycles or 0) + 1
	return gain
end

function bank.has_active_loan()
	return bank.get().active_loan ~= nil
end

function bank.get_active_loan()
	return bank.get().active_loan
end

function bank.value_of(collectible_id)
	local cfg = Isaac.GetItemConfig():GetCollectible(collectible_id)
	if not cfg then return VALUE_BY_QUALITY[0] end
	local q = cfg.Quality or 0
	return VALUE_BY_QUALITY[q] or VALUE_BY_QUALITY[0]
end

function bank.collateral_eligible(player, collectible_id)
	if not player or not collectible_id or collectible_id <= 0 then return false end
	local cfg = Isaac.GetItemConfig():GetCollectible(collectible_id)
	if not cfg then return false end
	if cfg.Hidden then return false end
	if cfg.Type ~= ItemType.ITEM_PASSIVE then return false end
	if cfg.Tags and (cfg.Tags & ItemConfig.TAG_QUEST) == ItemConfig.TAG_QUEST then return false end
	if player:GetCollectibleNum(collectible_id, true) <= 0 then return false end
	return true
end

function bank.list_collateral_candidates(player)
	local list = {}
	if not player then return list end
	local item_config = Isaac.GetItemConfig()
	local max_id = item_config:GetCollectibles().Size - 1
	for id = 1, max_id do
		local cfg = item_config:GetCollectible(id)
		if cfg and bank.collateral_eligible(player, id) then
			list[#list + 1] = {
				id = id,
				count = player:GetCollectibleNum(id, true),
				value = bank.value_of(id),
				name = cfg.Name,
				gfx = cfg.GfxFileName,
			}
		end
	end
	table.sort(list, function(a, b)
		if a.value ~= b.value then return a.value > b.value end
		return a.id < b.id
	end)
	return list
end

function bank.list_replacement_candidates(player, loan)
	loan = loan or bank.get_active_loan()
	local need = loan and (loan.remaining or loan.principal or 0) or 0
	local out = {}
	for _, row in ipairs(bank.list_collateral_candidates(player)) do
		if row.value >= need then
			out[#out + 1] = row
		end
	end
	return out
end

function bank.collateral_still_present(player, loan)
	loan = loan or bank.get_active_loan()
	if not loan then return true end
	player = player or bank.resolve_owner(loan)
	if not player then return false end
	local count = player:GetCollectibleNum(loan.item_id, true)
	return count >= (loan.count_at_issue or 1)
end

function bank.check_collateral(_observer)
	-- Always resolve the loan owner. Do not trust callback observer players
	-- (another player gaining/losing items must not flip secured).
	local loan = bank.get_active_loan()
	if not loan then return true end
	local owner = bank.resolve_owner(loan)
	if not bank.collateral_still_present(owner, loan) then
		loan.secured = false
		return false
	end
	loan.secured = true
	return true
end

function bank.issue_loan(player, item_id)
	if not player or not item_id then return false, "bad_args" end
	local b = bank.get()
	if b.headquarters and b.headquarters.entered then
		return false, "headquarters"
	end
	if b.active_loan then return false, "loan_exists" end
	if not bank.collateral_eligible(player, item_id) then return false, "ineligible" end
	local value = bank.value_of(item_id)
	local count = player:GetCollectibleNum(item_id, true)
	local cycle = b.branch.current_cycle_id or b.branch.last_cycle_id
	b.active_loan = {
		item_id = item_id,
		count_at_issue = count,
		principal = value,
		remaining = value,
		issued_cycle = cycle,
		secured = true,
		payment_due = false,
		owner_index = owner_key(player),
	}
	player:AddCoins(value)
	b.stats.total_borrowed = (b.stats.total_borrowed or 0) + value
	b.stats.loans_issued = (b.stats.loans_issued or 0) + 1
	return true
end

function bank.repay_loan(player)
	local b = bank.get()
	local loan = b.active_loan
	if not loan then return false, "no_loan" end
	player = player or bank.resolve_owner(loan)
	if not player then return false, "no_player" end
	local due = loan.remaining or loan.principal or 0
	if player:GetNumCoins() < due then return false, "insufficient_coins" end
	player:AddCoins(-due)
	b.stats.total_repaid = (b.stats.total_repaid or 0) + due
	b.stats.loans_repaid = (b.stats.loans_repaid or 0) + 1
	b.active_loan = nil
	if b.headquarters and b.headquarters.entered then
		bank.mark_settled()
	end
	return true
end

function bank.replace_collateral(player, item_id)
	local b = bank.get()
	local loan = b.active_loan
	if not loan then return false, "no_loan" end
	player = player or bank.resolve_owner(loan)
	if not player then return false, "no_player" end
	if not bank.collateral_eligible(player, item_id) then return false, "ineligible" end
	local value = bank.value_of(item_id)
	local need = loan.remaining or loan.principal or 0
	if value < need then return false, "value_too_low" end
	loan.item_id = item_id
	loan.count_at_issue = player:GetCollectibleNum(item_id, true)
	loan.secured = true
	loan.owner_index = owner_key(player)
	return true
end

function bank.seize_collateral(player, loan)
	local b = bank.get()
	loan = loan or b.active_loan
	if not loan then return false, "no_loan" end
	player = player or bank.resolve_owner(loan)
	if player and bank.collateral_still_present(player, loan) then
		player:RemoveCollectible(loan.item_id)
	end
	b.seized_assets[#b.seized_assets + 1] = {
		id = bank.next_seized_id(),
		item_id = loan.item_id,
		count = 1,
		source = "loan_default",
		owner_index = loan.owner_index,
	}
	b.stats.assets_seized = (b.stats.assets_seized or 0) + 1
	b.active_loan = nil
	if b.headquarters and b.headquarters.entered then
		bank.mark_settled()
	end
	return true
end

function bank.forfeit_collateral(player)
	return bank.seize_collateral(player, bank.get_active_loan())
end

function bank.mark_next_branch_closed()
	bank.get().branch.closed_pending = true
end

--- Consume pending closure for the arriving cycle. Returns whether this branch should spawn Closed.
function bank.consume_branch_closure(_cycle_id)
	local br = bank.get().branch
	if br.closed_pending then
		br.closed_pending = false
		return true
	end
	return false
end

function bank.rob(player, branch_ent)
	local b = bank.get()
	local loan = b.active_loan
	local rng = nil
	if branch_ent and branch_ent.GetDropRNG then
		rng = branch_ent:GetDropRNG()
	elseif player and player.GetDropRNG then
		rng = player:GetDropRNG()
	else
		rng = RNG()
		rng:SetSeed(Random(), 35)
	end
	local min_c, max_c
	if not loan then
		min_c, max_c = 6, 10
	elseif loan.secured ~= false then
		min_c, max_c = 2, 4
	else
		min_c, max_c = 1, 2
	end
	local amount = min_c
	if max_c > min_c then
		amount = min_c + rng:RandomInt(max_c - min_c + 1)
	end
	local deposit_loss = math.min(b.deposit, amount)
	b.deposit = b.deposit - deposit_loss
	b.stats.robberies = (b.stats.robberies or 0) + 1
	bank.mark_next_branch_closed()
	local room = Game():GetRoom()
	local pos = (branch_ent and branch_ent.Position) or (player and player.Position) or room:GetCenterPos()
	for _ = 1, amount do
		Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_COIN,
			CoinSubType.COIN_PENNY,
			room:FindFreePickupSpawnPosition(pos, 40, true),
			RandomVector() * 2,
			branch_ent
		)
	end
	return amount, deposit_loss
end

--- Arrive at a bank cycle node. Settles interest once per cycle_id.
--- Closed branches still earn interest; loan due is deferred until an open branch.
--- Headquarters freezes ordinary branch cycles.
function bank.on_branch_arrival(cycle_id, is_closed)
	if cycle_id == nil or cycle_id == "" then return false, "no_cycle" end
	local b = bank.get()
	if b.headquarters and b.headquarters.entered then
		return false, "headquarters"
	end
	local br = b.branch
	br.current_cycle_id = cycle_id
	if br.last_cycle_id == cycle_id then
		return false, "same_cycle"
	end
	bank.apply_interest()
	br.last_cycle_id = cycle_id
	bank.check_collateral()
	if not is_closed then
		local loan = b.active_loan
		if loan and loan.issued_cycle ~= nil and loan.issued_cycle ~= cycle_id then
			loan.payment_due = true
		end
	end
	return true
end

--- Call when leaving a bank node room while a due loan was not resolved.
function bank.on_leave_unresolved_due()
	local loan = bank.get_active_loan()
	if loan and loan.payment_due then
		bank.forfeit_collateral()
		return true
	end
	return false
end

function bank.debug_snapshot()
	local b = bank.get()
	local loan = b.active_loan
	local hq = b.headquarters or {}
	return {
		cycle_id = b.branch.current_cycle_id,
		last_cycle_id = b.branch.last_cycle_id,
		deposit = b.deposit,
		interest_earned = b.interest_earned,
		deposit_cycles = b.deposit_cycles,
		closed_pending = b.branch.closed_pending == true,
		active_loan = loan ~= nil,
		loan_item = loan and loan.item_id or nil,
		loan_remaining = loan and loan.remaining or nil,
		secured = loan and loan.secured,
		payment_due = loan and loan.payment_due,
		seized_count = #(b.seized_assets or {}),
		hq_entered = hq.entered == true,
		hq_settled = hq.settled == true,
		hq_deposit_claimed = hq.deposit_claimed == true,
		stats = b.stats,
	}
end

return bank

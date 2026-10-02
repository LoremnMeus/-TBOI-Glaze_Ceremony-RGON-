-- Thin Slot manager adapter for Bank Branch.
local enums = require("Qing_Remaster_scripts.core.enums")
local bank_branch = require("Qing_Remaster_scripts.threads.bank.bank_branch")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Slots.Bank_Branch,
	own_key = "Slot_Bank_Branch_",
}

bank_branch.install(item)

return item

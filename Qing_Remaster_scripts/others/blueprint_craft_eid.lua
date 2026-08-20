-- 持有蓝图时，自动给已接线道具追加 Flight/制造兼容 EID。
-- 正式句式由 craft_eid_copy 生成；无正式文案则不追加。
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")

local item = {
	ToCall = {},
	own_key = "blueprint_craft_eid_",
	_registered = false,
}

local function eid_is_zh()
	local lang = auxi.get_EID_language and auxi.get_EID_language() or "en_us"
	return lang == "zh_cn" or lang == "zh" or lang == "chinese"
end

local function should_append(desc)
	if not desc or desc.ObjType ~= 5 or desc.ObjVariant ~= 100 then return false end
	local id = tonumber(desc.ObjSubType)
	if not id or id <= 0 then return false end
	local bp = enums.Items.Blue_Print
	local af = enums.Items.Air_Flight
	if id == bp or id == af then return false end
	if not auxi.have_player_has_collectible(bp) then return false end
	local lines = CraftProfile.collectible_craft_eid_lines(id, eid_is_zh())
	return lines ~= nil and #lines > 0
end

function item.register()
	if item._registered or not EID or not EID.addDescriptionModifier then return end
	item._registered = true
	local bp = enums.Items.Blue_Print
	EID:addDescriptionModifier("qing_blueprint_craft_eid", should_append, function(desc)
		local lines = CraftProfile.collectible_craft_eid_lines(desc.ObjSubType, eid_is_zh())
		if not lines then return desc end
		local prefix = "#{{Collectible"..tostring(bp).."}} "
		for _, line in ipairs(lines) do
			EID:appendToDescription(desc, prefix..line)
		end
		return desc
	end)
end

item.register()

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		item.register()
	end,
})

return item

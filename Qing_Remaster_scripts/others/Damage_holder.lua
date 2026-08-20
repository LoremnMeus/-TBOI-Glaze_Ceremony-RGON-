local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	own_key = "Damage_holder_",
}
--现在只在导入的情况下才会记录

function item.on_damage(ent,amt,flag,source,cooldown)
	local d = ent:GetData()
	if (d[item.own_key.."hitpoint"] or 0) ~= ent.HitPoints then
		d[item.own_key.."hitpoint"] = ent.HitPoints
		d[item.own_key.."damage"] = 0
	end
	d[item.own_key.."damage"] = d[item.own_key.."damage"] + amt
	return d[item.own_key.."damage"]
end

return item
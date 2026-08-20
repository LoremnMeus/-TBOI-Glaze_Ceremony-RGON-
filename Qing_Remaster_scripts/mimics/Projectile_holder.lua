local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Projectile_holder_",
}
--这里主要是模仿tear生成的projectile
function item.addflag(ent,flag)
	local d = ent:GetData()
	d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
	d[item.own_key.."effect"].flag = (d[item.own_key.."effect"].flag or 0) | flag
end

function item.setflag(ent,flag)
	local d = ent:GetData()
	d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
	d[item.own_key.."effect"].flag = flag
end

function item.getflag(ent,flag)
	local d = ent:GetData()
	return (d[item.own_key.."effect"] or {}).flag or 0
end

return item
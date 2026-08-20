local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local tear_trigger_holder = require("Qing_Remaster_scripts.callbacks.tear_trigger_holder")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Aquarius_holder_",
}

function item.help_control(ent,params)
	local d = ent:GetData()
	d[item.own_key.."effect"] = params
	if params.init then item.work(ent) end
end

function item.work(ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		auxi.check_if_any(d[item.own_key.."effect"].special,ent)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 54,
Function = function(_,ent)
	item.work(ent)
	if ent.FrameCount == 1 and ent.SpawnerEntity and ent.SpawnerEntity.Type == EntityType.ENTITY_PLAYER then
		tear_trigger_holder.trigger_tear("Aquarius",ent,nil,ent.SpawnerEntity:ToPlayer(),nil)
	end
end,
})

return item
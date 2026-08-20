local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	own_key = "Entity_holder_",
}

function item.generate()
	return {
		GetData = function(ent) return ent.Data end,Data = {},
		PositionOffset = Vector(0,0),Position = Vector(200,200),
		GetSprite = function(ent) return Sprite() end,
		Exists = function(ent) return true end,IsDead = function(ent) return false end,
		Type = 1099,Variant = 1099,SubType = 1099,
		Render = function(ent) end,Update = function(ent) end,
	}
end

return item
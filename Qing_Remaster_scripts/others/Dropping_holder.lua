local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
}

function item.try_drop(pos,vel,params)		--params可以传入：ent、load_name、play_name、sprite、spawner
	if vel == nil then vel = auxi.MakeVector(math.random(36000)/100) * (math.random(10000)/10000 * 1.5 + 1) end
	if pos == nil then pos = Vector(200,200) end
	local spawner = nil
	if params.spawner then spawner = params.spawner end
	if params.ent then params.sprite = params.ent:GetData() end
	if params.sprite then params.load_name = params.sprite:GetFilename() end
	if params.play_name == nil then params.play_name = "Appear" end
	local ent = Isaac.Spawn(1000,15,100,pos,vel,spawner)
	if params.load_name then
		local s = ent:GetSprite()
		s:Load(params.load_name,true)
	end
	if params.play_name then
		local s = ent:GetSprite()
		s:Play(params.play_name)
	end
	local d = ent:GetData()
	d.is_dropping_item = true
	return ent
end

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Tech_5_holder_",
	buff_list = {
		BitSet128(1<<2,0),
		BitSet128(1<<16,0),
		BitSet128(1<<30,0),
		BitSet128(1<<19,0),
		BitSet128(1<<33,0),
		BitSet128(0,1<<5),
	},
}
--未挂载
function item.work_on_tech_5(player,params)
	player = player or Game():GetPlayer(0)
	params = params or {}
	local dir = auxi.ggdir(player,true,true,nil,nil,{ignore_canwork = true,real = true,})
	if auxi.check_rand(player.Luck,30,10,5) then
		local q = player:FireTechLaser(params.pos or player.Position,0,params.dir or dir,true,false,nil,params.charge or 1)
		q.Parent = player
		for u,v in pairs(item.buff_list) do 
			if math.random(1000) > 700 then
				q:AddTearFlags(v)
			end
		end
	end
	return q
end

return item
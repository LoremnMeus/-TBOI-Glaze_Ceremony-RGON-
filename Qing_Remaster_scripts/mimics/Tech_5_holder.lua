local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")

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
	local q
	if auxi.check_rand(player.Luck,30,10,5) then
		local opts
		if params.attack_ctx then
			opts = params.attack_ctx
		elseif params.attack then
			opts = {
				mode = "inherit",
				attack = params.attack,
				emitter = params.emitter,
				role = "derived",
				reason = "tech5",
				damage_multiplier = params.charge or 1,
				left_eye = true,
			}
		else
			if params.expected_attack then
				attack_holder.warn_missing_parent_once(
					"tech5",
					"[AttackHolder] Tech5 emitted without parent Attack; fallback to untracked."
				)
			end
			opts = {
				mode = "untracked",
				reason = "tech5_proc",
				damage_multiplier = params.charge or 1,
				left_eye = true,
			}
		end
		opts.offset_id = opts.offset_id or 0
		opts.left_eye = true
		q = attack_holder.FireTechLaser(player, params.pos or player.Position, params.dir or dir, opts)
		if q then
			q.Parent = player
			for u,v in pairs(item.buff_list) do
				if math.random(1000) > 700 then
					q:AddTearFlags(v)
				end
			end
		end
	end
	return q
end

return item

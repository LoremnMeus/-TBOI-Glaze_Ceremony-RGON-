local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Dull = require("Qing_Remaster_scripts.items.Zeiz.Item_Dull_items")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.D_Key,
	own_key = "Item_D_Key_",
	chance_rate = {
		{frame = -10,val = 0,},
		{frame = 0,val = 5,},
		{frame = 5,val = 20,},
		{frame = 20,val = 75,},
	},
	tgs = {
		{tp = 5,vr = 20,st = 0,},
		{tp = 5,vr = 30,st = 0,},
		{tp = 5,vr = 40,st = 0,},
		{tp = 5,vr = 350,st = 0,},
	},
}

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,rng,pos)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			local cnt = Dull.get_point(player)
			local chance = auxi.check_lerp(cnt,item.chance_rate).val
			if rng:RandomInt(100) < chance then
				local ndx = option_index_holder.find_a_new_index()
				local rnd = auxi.random_1() * 360
				for u,v in pairs(item.tgs) do
					local q = Isaac.Spawn(v.tp,v.vr,v.st,pos + auxi.get_by_rotate(nil,rnd + u * 360/(#item.tgs),10),Vector(0,0),player)
					auxi.self_morph(q)
					q.OptionsPickupIndex = ndx
				end
				return true
			end
		end
	end
end,
})

return item
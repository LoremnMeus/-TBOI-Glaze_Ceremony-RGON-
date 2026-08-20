local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local glaze_crown = require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze")
local glaze_enemy = require("Qing_Remaster_scripts.pickups.pickup_glaze_enemy")

local item = {
	familiar = {Variant = 73,SubType = 0,},
	familiar2 = {Variant = 43,SubType = 0,},
	ToCall = {},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = item.familiar.Variant,
Function = function(_,ent, col, low)
	if ent.Variant == item.familiar.Variant then
		local should_glaze = glaze_crown.any_infect()
		local d = ent:GetData()
		if d.is_glazed_familiar and d.is_glazed_familiar == true then
			if col:IsVulnerableEnemy() and col:IsActiveEnemy() and (not col:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and col:CanShutDoors() == true then
				col:AddFreeze(EntityRef(ent),90)
				if should_glaze then
					glaze_enemy.Make_Glazed_Enemy(col)
				end
				d.is_glazed_familiar = false
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = item.familiar2.Variant,
Function = function(_,ent, col, low)
	if ent.Variant == item.familiar2.Variant then
		local should_glaze = glaze_crown.any_infect()
		local d = ent:GetData()
		if d.is_glazed_familiar and d.is_glazed_familiar == true then
			if col:IsVulnerableEnemy() and col:IsActiveEnemy() and not col:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) and col:CanShutDoors() == true then
				col:AddFreeze(EntityRef(ent),60)
				if should_glaze then
					glaze_enemy.Make_Glazed_Enemy(col)
				end
				d.is_glazed_familiar = false
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar.Variant,
Function = function(_,ent, col, low)
	if ent.Variant == item.familiar.Variant then
		local d = ent:GetData()
		if d.is_glazed_familiar and d.is_glazed_familiar == true then
			
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar2.Variant,
Function = function(_,ent, col, low)
	if ent.Variant == item.familiar2.Variant then
		local d = ent:GetData()
		if d.is_glazed_familiar and d.is_glazed_familiar == true then
			
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar.Variant,
Function = function(_,ent)
	if Unlocker.should_any_be_done("Pickup","Glaze_Spider",nil,"Pickup_allow") then
		local rng = ent:GetDropRNG()
		rng = auxi.rng_for_sake(rng)
		if glaze_crown.roll_convert(rng, 35) then		-- 原 1/35
			local d = ent:GetData()
			local s = ent:GetSprite()
			d.is_glazed_familiar = true
			s:Load("gfx/Glaze/glaze_spider.anm2", true)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar2.Variant,
Function = function(_,ent)
	if Unlocker.should_any_be_done("Pickup","Glaze_Spider",nil,"Pickup_allow") then
		local rng = ent:GetDropRNG()
		rng = auxi.rng_for_sake(rng)
		if glaze_crown.roll_convert(rng, 25) then		-- 原 1/25
			local d = ent:GetData()
			local s = ent:GetSprite()
			d.is_glazed_familiar = true
			s:Load("gfx/Glaze/glaze_fly.anm2", true)
			s:Play("Idle")
		end
	end
end,
})

return item
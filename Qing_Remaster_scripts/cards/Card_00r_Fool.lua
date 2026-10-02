local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local pedestal_encounter = require("Qing_Remaster_scripts.others.Pedestal_Encounter_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Fool_r,
	own_key = "Thoth_cd0r_Foo_",
	-- Consumer Regression 只读；禁止业务分支读这些字段
	debug_cr = {
		triggered_new_generation = 0,
		triggered_fresh_generation = 0,
		ignored_same_generation = 0,
		last_generation_id = nil,
	},
}

function item.reset_debug_cr()
	item.debug_cr.triggered_new_generation = 0
	item.debug_cr.triggered_fresh_generation = 0
	item.debug_cr.ignored_same_generation = 0
	item.debug_cr.last_generation_id = nil
end

function item.get_debug_cr()
	return {
		triggered_new_generation = item.debug_cr.triggered_new_generation or 0,
		triggered_fresh_generation = item.debug_cr.triggered_fresh_generation or 0,
		ignored_same_generation = item.debug_cr.ignored_same_generation or 0,
		last_generation_id = item.debug_cr.last_generation_id,
	}
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

--- 只消费普通 Pedestal Encounter；不监听 Death Certificate Display。
--- triggered_* 现表示「收到 normal Encounter」（兼容旧 CR 名）；不再自判 fresh。
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_PEDESTAL_ENCOUNTER, params = nil,
Function = function(_, encounter)
	local effects = save.elses[item.own_key.."effect"]
	if type(effects) ~= "table" or #effects <= 0 then
		return
	end
	local ent = encounter and encounter.pickup
	if not ent or not ent:Exists() then
		return
	end
	item.debug_cr.last_generation_id = encounter.generation_id
	item.debug_cr.triggered_fresh_generation = (item.debug_cr.triggered_fresh_generation or 0) + 1
	item.debug_cr.triggered_new_generation = (item.debug_cr.triggered_new_generation or 0) + 1

	local room = Game():GetRoom()
	local ndx = ent.OptionsPickupIndex
	if ndx <= 0 then ndx = option_index_holder.find_a_new_index() end
	ent.OptionsPickupIndex = ndx
	local tbl = {}
	pedestal_encounter.with_suppressed_encounter(item.own_key, function()
		for i = 1,#effects do
			local v = effects[i]
			local colid = v.id
			local pos = room:FindFreePickupSpawnPosition(ent.Position,10,true)
			local player = Game():GetPlayer(0)
			local q = auxi.reveal_item2(player,pos,colid,{revealee_end = function(eent)
				if ent and ent:Exists() and ent.SubType > 0 and player:Exists() then
					local e = Isaac.Spawn(1000,EffectVariant.CRACK_THE_SKY,0,eent.Position,Vector(0,0),player):ToEffect()
					e.Parent = player
					e.CollisionDamage = 0
					e:GetSprite().Scale = Vector(1.5,1)
					pedestal_encounter.with_suppressed_encounter(item.own_key, function()
						local q2 = Isaac.Spawn(5,100,colid,eent.Position,Vector(0,0),nil):ToPickup()
						q2:Morph(5,100,colid,true,true,true)
						q2:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
						q2.OptionsPickupIndex = ndx
						if ent.Price ~= 0 then unique_holder.try_spawn_shop_item() end
						q2.Price = ent.Price
						pedestal_encounter.mark_suppressed(q2, item.own_key)
					end)
				end
			end})
			local bombinfo = enums.Pickups.Glaze_bomb
			local q3 = Isaac.Spawn(5,bombinfo.Variant,bombinfo.SubType,pos,Vector(0,0),nil)
			table.insert(tbl,#tbl + 1,q3)
		end
	end)
	for u,v in pairs(tbl) do v:Remove()	end
	save.elses[item.own_key.."effect"] = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local itempool = Game():GetItemPool()
		local typ = itempool:GetPoolForRoom(Game():GetRoom():GetType(),Game():GetLevel():GetCurrentRoomDesc().SpawnSeed)
		if typ == -1 then typ = 0 end
		local seed = rng:GetSeed()
		local colid = itempool:GetCollectible(typ,true,seed)
		table.insert(save.elses[item.own_key.."effect"],#save.elses[item.own_key.."effect"] + 1,{id = colid,})
		rng:Next()
		auxi.reveal_item(player,player.Position,colid,{offset = Vector(0,-60),})
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			for i = 1,2 do
				local seed = rng:GetSeed()
				local colid = itempool:GetCollectible(typ,true,seed)
				table.insert(save.elses[item.own_key.."effect"],#save.elses[item.own_key.."effect"] + 1,{id = colid,})
				rng:Next()
				auxi.reveal_item(player,player.Position,colid,{offset = Vector((i * 2 - 3) * 40,-40),})
			end
		end
	end
end,
})

return item

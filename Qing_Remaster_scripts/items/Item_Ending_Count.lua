local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Ending_Count,
	own_key = "Item_Ending_Count_",
	count = 30 * 60,
	droping_map = {
		{frame = 0,A = 0,sx = 0,sy = 0,Y = -10,},
		{frame = 0.1,A = 1.1,sx = 1,sy = 1.1,Y = -20,},
		{frame = 0.11,A = 1,sx = 1,sy = 1,Y = -21,},
		{frame = 0.89,A = 1,sx = 1,sy = 1,Y = -189,},
		{frame = 0.9,A = 1,sx = 1.1,sy = 1.1,Y = -190,},
		{frame = 1,A = 0,sx = 0,sy = 0,Y = -200,},
	},
	random_table = {},
	quality_map = {
		[0] = 20,
		[1] = 16,
		[2] = 12,
		[3] = 9,
		[4] = 5,
		[5] = 1,
	},
	charge_map = {
		[0] = 50,
		[1] = 100,
		[2] = 100,
		[3] = 90,
		[4] = 80,
		[5] = 60,
		[6] = 50,
		[7] = 50,
		[8] = 50,
		[9] = 45,
		[10] = 40,
		[11] = 30,
		[12] = 20,
	},
	specials = {
		[352] = 0,
		[475] = 0,
		[622] = 15,
		[628] = 4,
	},
}

if true then
	local itemConfig = Isaac.GetItemConfig()
	local sz = itemConfig:GetCollectibles().Size
	for id = 1,sz do
		local collectible = itemConfig:GetCollectible(id)
		if collectible and collectible.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST and collectible.Type == ItemType.ITEM_ACTIVE and not collectible.Hidden then
			local qual = item.quality_map[collectible.Quality]
			local charge = item.charge_map[collectible.MaxCharges] or 30
			if collectible.Special then charge = charge * 0.3 end
			table.insert(item.random_table,#item.random_table + 1,{id = id,weigh = item.specials[id] or qual * charge,})
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local d = player:GetData()
	local ret = true
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		if d[item.own_key.."effect"] and #d[item.own_key.."effect"] > 0 then
			d[item.own_key.."effect"][#d[item.own_key.."effect"]].twice = true
		end
	else
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		local rnd = auxi.random_in_weighed_table(item.random_table or {{id = 33,},},rng).id
		table.insert(d[item.own_key.."effect"],#d[item.own_key.."effect"] + 1,{id = rnd,cnt = item.count,})
	end
	return ret
end,
})
--[[
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player then
		local d = player:GetData()
		if d[item.own_key.."effect"] and #d[item.own_key.."effect"] > 0 then
			for u,v in pairs(d[item.own_key.."effect"]) do
				v.kill = v.kill or 15
			end
		end
	end
end,
})
--]]
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local ctrlid = player.ControllerIndex
	local d = player:GetData()
	if #(d[item.own_key.."effect"] or {}) > 0 then
		for i = #d[item.own_key.."effect"],1,-1 do
			local v = d[item.own_key.."effect"][i]
			v.cnt = v.cnt - 1
			if i ~= #d[item.own_key.."effect"] and (d[item.own_key.."effect"][i + 1].cnt - v.cnt) < 60 * 3 then v.cnt = v.cnt - 0.2 * (60 * 3 - (d[item.own_key.."effect"][i + 1].cnt - v.cnt)) end
			if v.cnt <= 0 then 
				player:UseActiveItem(v.id,UseFlag.USE_MIMIC,0)
				if v.twice then player:UseActiveItem(v.id,UseFlag.USE_MIMIC | UseFlag.USE_CARBATTERY,0) end
				table.remove(d[item.own_key.."effect"],i) 
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local ctrlid = player.ControllerIndex
	local d = player:GetData()
	if #(d[item.own_key.."effect"] or {}) > 0 then
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			local config = Isaac:GetItemConfig()
			for	u,v in pairs(d[item.own_key.."effect"]) do 
				local info = config:GetCollectible(v.id)
				if v.id == enums.Items.It_s_a_trick then info = config:GetCollectible(save.elses.glazed_trick or 32) or config:GetCollectible(32) end
				local s = Sprite()
				s:Load("gfx/mimics/Ending_Count/ending_count_item.anm2",true)
				s:ReplaceSpritesheet(0,info.GfxFileName)
				s:LoadGraphics()
				s:Play("Idle",true)
				local sinfo = auxi.check_lerp(v.cnt/item.count,item.droping_map)
				s.Color = Color(1,1,1,sinfo.A)
				s.Scale = Vector(sinfo.sx,sinfo.sy)
				s:Render(Isaac.WorldToScreen(player.Position) + Vector(0,sinfo.Y),Vector(0,0),Vector(0,0))
			end
		end
	end
end,
})

return item
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Book_of_Vision,
	own_key = "Item_Book_of_Vision_",
	should_duplicate = nil,
	duplicate_filter = {},
	should_check_for_the_same = {
		"bomb",
		"key",
		"coin",
		"gbomb",
		"gkey",
	},
	check_over = {
		[10] = true,
		[20] = true,
		[30] = true,
		[40] = true,
	},
	limit = 50,
	offset = Vector(-3,-5),
	offset2 = Vector(5,-7),
}

local function should_render(ent)
	local d = ent:GetData()
	local chance = math.random(1000)
	if (d[item.own_key.."effect"] or 0) > 0 then 
		d[item.own_key.."effect"] = d[item.own_key.."effect"] - 1
		return false
	end
	if chance > item.limit then return true end
	d[item.own_key.."effect"] = math.random(5)
	return false
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = nil,
Function = function(_,ent)
	if item.should_duplicate and auxi.check_if_any(item.check_over[ent.Variant],ent) and should_render(ent) and (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		local s = auxi.copy_sprite(ent:GetSprite())
		s.Color = auxi.MulColor(s.Color,Color(1,1,1,0.225))
		s:Render(Isaac.WorldToScreen(ent.Position + ent.PositionOffset) + item.offset,Vector(0,0),Vector(0,0))
		if auxi.should_do_belial() then
			local s = auxi.copy_sprite(ent:GetSprite(),nil,{filename = "gfx/005.016_black heart.anm2",})
			s.Color = auxi.MulColor(s.Color,Color(1,1,1,0.15))
			s:Render(Isaac.WorldToScreen(ent.Position + ent.PositionOffset) + item.offset2,Vector(0,0),Vector(0,0))
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	if coltyp == item.entity then
		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			item.should_duplicate = (item.should_duplicate or 0) + 1
		else
			item.should_duplicate = (item.should_duplicate or 0) + 1
		end
		return ret
	end
end,
})

local function check_the_same(player,changetype)
	if item.should_check_for_the_same[changetype] == nil then return true end
	return auxi.check_for_the_same(player,Game():GetPlayer(0))
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_BASIC, params = nil,
Function = function(_,player,changetype,count)
	local n_wisp = auxi.get_wisps(player,item.entity)
	if ((item.should_duplicate and item.should_duplicate > 0) or (#n_wisp > 0 and count > 0)) and check_the_same(player,changetype) then
		local cnt = (item.should_duplicate or 0)
		if (#n_wisp > 0 and count > 0) then 
			cnt = cnt + (#n_wisp)
			for u,v in pairs(n_wisp) do v:Remove() end 
		end
		local idx = player:GetData().__Index
		if idx then
			if (item.duplicate_filter[changetype] or 0) < Game():GetFrameCount() then
				if changetype == "bomb" then
					player:AddBombs(count * cnt)
				elseif changetype == "key" then
					player:AddKeys(count * cnt)
				elseif changetype == "coin" then
					player:AddCoins(count * cnt)
				elseif changetype == "gbomb" then
					player:AddBombs(count * 3 * cnt)
					item.duplicate_filter["bomb"] = Game():GetFrameCount() + 5
				elseif changetype == "gkey" then
					player:AddKeys(count * 3 * cnt)
					item.duplicate_filter["key"] = Game():GetFrameCount() + 5
				elseif changetype == "rd_heart" then
					player:AddHearts(count * cnt)
				elseif changetype == "gd_heart" then
					player:AddGoldenHearts(count * cnt)
				elseif changetype == "sl_heart" then
					auxi.add_soul_heart(player,count * cnt)
				elseif changetype == "et_heart" then
					player:AddEternalHearts(count * cnt)
				elseif changetype == "rt_heart" then
					player:AddRottenHearts(count * cnt)
				elseif changetype == "bone_heart" then
					player:AddBoneHearts(count * cnt)
				end
				if auxi.should_do_belial(player) and #changetype > 5 and string.sub(changetype,#changetype - 5,#changetype) == "_heart" then
					player:AddBlackHearts(1)
				end
				item.duplicate_filter[changetype] = Game():GetFrameCount() + 5
			else
				item.duplicate_filter[changetype] = nil
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item.should_duplicate = nil
	item.duplicate_filter = {}
end,
})

return item
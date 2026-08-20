local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	own_key = "Time_Freeze_holder_",
	eventlist = {
		"Explosion",
		"Shoot",
		"Jump",
		"Land",
		"BloodStart",
		"BloodStop",
		--"Heartbeat",
		"Lift",
		"Stop",
		"Slide",
		"Spawn",
		"Shoot2",
		"DeathSound",
		"DropSound",
		"Disappear",
		"Prize",
		--"Shuffle",
		--"CoinInsert",
	},
	target = {		--只控制强制转移的敌人
		[6] = true,
		[17] = true,
		[30] = true,
		[33] = true,
		[36] = true,
		[40] = true,		--很特殊哦
		[42] = true,
		[45] = true,
		[56] = true,
		[59] = true,
		[60] = true,
		--[61] = true,		--目标坐标
		--[63] = true,
		--[65] = true,
		[84] = true,
		[78] = true,
		[96] = true,
		[101] = true,
		[102] = true,
		[201] = true,
		[202] = true,
		[203] = true,
		[209] = true,
		[218] = true,
		[221] = true,
		[228] = true,
		[231] = true,
		[235] = true,
		[236] = true,
		[240] = true,
		[241] = true,
		[242] = true,
		[244] = true,
		[245] = true,
		[251] = true,
		[255] = true,
		[262] = true,
		[263] = true,
		[266] = true,
		[270] = true,
		[273] = function(ent) if ent.Variant == 10 then return true end end,
		[274] = true,
		[275] = true,
		[276] = true,
		[289] = true,
		[292] = true,
		[294] = true,
		[298] = true,
		[300] = true,
		[304] = true,
		[306] = true,
		[307] = true,
		[309] = true,
		[406] = function(ent) if ent.State == 9000 or ent.State == 9001 then return true end end,
		[804] = true,
		[805] = true,
		[809] = true,
		[825] = true,
		[829] = true,
		[832] = function(ent) if ent.Variant == 1 and ent.SubType > 0 and (ent.State == 16 or ent.State == 5) then return true end end,
		[837] = true,
		[852] = true,
		[856] = true,
		[861] = true,
		[862] = true,
		[877] = true,
		[880] = true,
		[881] = true,
		[889] = true,
		[900] = true,
		[904] = function(ent) if ent.Variant == 1 then return true end end,
		[905] = function(ent) if ent.State == 6 then return true end end,
		[906] = true,
		[907] = true,
		[911] = true,
		[912] = function(ent) if ent.Variant < 100 then return true end end,
		[914] = true,
		[917] = true,
		--919
		[921] = true,
		[950] = function(ent) if ent.Variant == 1 or ent.Variant == 2 then return true end end,
		[951] = function(ent) if ent.Variant == 0 or ent.Variant == 1 then return true end end,
		[960] = true,
		[964] = true,
		[965] = true,
		[967] = true,
	},
	middle_target = {
		[29] = true,		--
		[54] = true,		--
		[86] = true,		--
		[215] = true,		--
		[246] = true,		--
		[250] = true,		--
		[305] = true,		--
		[840] = true,		--
		[851] = true,		--
		--[869] = true,		--
		--[20] = true,		--
		--[100] = true,		--
		--[68] = true,		--
		--[264] = true,		--
		--[43] = true,		--
		[410] = true,		--
	},
}

function item.stop_time(ent,key)
	if ent == nil then return end
	local d = ent:GetData()
	local s = ent:GetSprite()
	for u,v in pairs(item.eventlist) do if s:IsEventTriggered(v) ~= false then s:Update() end end
	if d[item.own_key..key.."flag_freeze_succ"] == nil then
		d[item.own_key..key.."flag_freeze_succ"] = Attribute_holder.try_hold_attribute(ent,"EntityFlag_FLAG_FREEZE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
	end
	if d[item.own_key..key.."flag_no_sprite_update_succ"] == nil then
		d[item.own_key..key.."flag_no_sprite_update_succ"] = Attribute_holder.try_hold_attribute(ent,"EntityFlag_FLAG_NO_SPRITE_UPDATE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_SPRITE_UPDATE))
	end
	if d[item.own_key..key.."flag_no_query_succ"] == nil and ent.Type ~= 3 then
		d[item.own_key..key.."flag_no_query_succ"] = Attribute_holder.try_hold_attribute(ent,"EntityFlag_FLAG_FLAG_NO_QUERY",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_QUERY))
	end
	if d[item.own_key..key.."flag_gridcollision_succ"] == nil then
		d[item.own_key..key.."flag_gridcollision_succ"] = Attribute_holder.try_hold_attribute(ent,"GridCollisionClass",EntityGridCollisionClass.GRIDCOLL_NONE)
	end
	if d[item.own_key..key.."flag_entitycollision_succ"] == nil then
		d[item.own_key..key.."flag_entitycollision_succ"] = Attribute_holder.try_hold_attribute(ent,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
	end
end

function item.time_free(ent,key)
	if ent == nil then return end
	local d = ent:GetData()
	if d[item.own_key..key.."flag_freeze_succ"] then
		local succ = Attribute_holder.try_rewind_attribute(ent,"EntityFlag_FLAG_FREEZE",d[item.own_key..key.."flag_freeze_succ"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
		d[item.own_key..key.."flag_freeze_succ"] = nil
	end
	if d[item.own_key..key.."flag_no_sprite_update_succ"] then
		Attribute_holder.try_rewind_attribute(ent,"EntityFlag_FLAG_NO_SPRITE_UPDATE",d[item.own_key..key.."flag_no_sprite_update_succ"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_SPRITE_UPDATE))
		d[item.own_key..key.."flag_no_sprite_update_succ"] = nil
	end
	if d[item.own_key..key.."flag_no_query_succ"] then
		Attribute_holder.try_rewind_attribute(ent,"EntityFlag_FLAG_FLAG_NO_QUERY",d[item.own_key..key.."flag_no_query_succ"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_QUERY))
		d[item.own_key..key.."flag_no_query_succ"] = nil
	end
	if d[item.own_key..key.."flag_gridcollision_succ"] then
		Attribute_holder.try_rewind_attribute(ent,"GridCollisionClass",d[item.own_key..key.."flag_gridcollision_succ"])
		d[item.own_key..key.."flag_gridcollision_succ"] = nil
	end
	if d[item.own_key..key.."flag_entitycollision_succ"] then
		Attribute_holder.try_rewind_attribute(ent,"EntityCollisionClass",d[item.own_key..key.."flag_entitycollision_succ"])
		d[item.own_key..key.."flag_entitycollision_succ"] = nil
	end
	if auxi.check_if_any(item.target[ent.Type],ent) and not ent:IsBoss() then ent.TargetPosition = Game():GetRoom():FindFreeTilePosition(ent.Position,ent.Size) end
	if auxi.check_if_any(item.middle_target[ent.Type],ent) then ent.TargetPosition = Game():GetRoom():FindFreeTilePosition(ent.Position * 0.9 + Game():GetPlayer(0).Position * 0.1,10) end
end

-- 全局 auxi.time_stop：原版宝宝 FollowPosition 与自驱宝宝都会压过 FLAG_FREEZE。
-- PRE 跳过内部 AI；post POST 在编队驱动之后再钉一次位速。
local function pin_familiar_during_time_stop(fam)
	if not fam then return end
	local pos, held = Attribute_holder.get_effective_value(fam, "Position")
	if held and pos then fam.Position = Vector(pos.X, pos.Y) end
	fam.Velocity = Vector(0, 0)
end

if ModCallbacks.MC_PRE_FAMILIAR_UPDATE then
	table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_FAMILIAR_UPDATE,
		params = nil,
		priority = -2000,
		Function = function(_, fam)
			if not auxi.is_time_stopped() then return end
			pin_familiar_during_time_stop(fam)
			return true
		end,
	})
end

table.insert(item.post_ToCall, #item.post_ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function(_)
		if not auxi.is_time_stopped() then return end
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, -1, -1, false, false)) do
			pin_familiar_during_time_stop(ent:ToFamiliar())
		end
	end,
})

return item

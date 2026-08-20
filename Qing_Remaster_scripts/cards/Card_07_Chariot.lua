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
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Chariot,
	own_key = "Thoth_cd7_Cha_",
}

local function fire_giga_rocket(player,pos,dir)
	player = player or Game():GetPlayer(0)
	pos = pos or player.Position
	dir = dir or Vector(1,0)
	local q = player:FireBomb(pos,dir * 10 * player.ShotSpeed)
	local s = q:GetSprite()
	q.IsFetus = false
	q.ExplosionDamage = 300
	q.Variant = 20
	s:Load("gfx/004.020_Giga Rocket.anm2",true)
	s:Play("Pulse",true)
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local adder = false
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ROCKET_IN_A_JAR) == false then	adder = true Imitate_item_holder.assign_fake_item(player,CollectibleType.COLLECTIBLE_ROCKET_IN_A_JAR,true) end
		local dir = auxi.ggdir(player,false,false,nil,nil,{ignore_canwork = true,})
		if dir:Length() < 0.01 then dir = player.Velocity:Normalized() end
		local infos = {{delta = 0,},}
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			table.insert(infos,#infos + 1,{delta = -30,})
			table.insert(infos,#infos + 1,{delta = 30,})
		end
		for u,v in pairs(infos) do
			fire_giga_rocket(player,player.Position,auxi.MakeVector(dir:GetAngleDegrees() + (v.delta or 0)))
		end
		if adder then Imitate_item_holder.re_assign_fake_item() end
	end
end,
})


return item
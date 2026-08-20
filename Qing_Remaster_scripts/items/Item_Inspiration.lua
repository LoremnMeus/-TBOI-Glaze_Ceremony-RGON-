local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Inspiration,
	own_key = "Item_Inspiration_",
	target = enums.Pickups.Inspiration_helper,
	heartval2num = {
		{frame = 0,val = 1.3,},
		{frame = 1,val = 1,},
		{frame = 2,val = 0.5,},
		{frame = 4,val = 0.2,},
		{frame = 12,val = 0,},
	},
	info = {
		[1] = {
			sprite = "gfx/005.015_double heart.anm2",
			tospawn = function(ent) local q = Isaac.Spawn(5,10,5,ent.Position,ent.Velocity,nil):ToPickup() return q end,
			weigh = 5,
		},
		[2] = {
			sprite = "gfx/005.013_heart (soul).anm2",
			tospawn = function(ent) local q = Isaac.Spawn(5,10,3,ent.Position,ent.Velocity,nil):ToPickup() return q end,
			weigh = 10,
		},
		[3] = {
			sprite = "gfx/005.017_goldheart.anm2",
			tospawn = function(ent) local q = Isaac.Spawn(5,10,7,ent.Position,ent.Velocity,nil):ToPickup() return q end,
			weigh = 1,
		},
		[4] = {
			sprite = "gfx/005.014_heart (eternal).anm2",
			tospawn = function(ent) local q = Isaac.Spawn(5,10,4,ent.Position,ent.Velocity,nil):ToPickup() return q end,
			weigh = 1,
		},
		[5] = {
			sprite = "gfx/005.022_nickel.anm2",
			tospawn = function(ent) local q = Isaac.Spawn(5,20,2,ent.Position,ent.Velocity,nil):ToPickup() return q end,
			weigh = 8,
		},
		[6] = {
			sprite = "gfx/005.023_dime.anm2",
			tospawn = function(ent) local q = Isaac.Spawn(5,20,3,ent.Position,ent.Velocity,nil):ToPickup() return q end,
			weigh = 3,
		},
		[7] = {
			sprite = "gfx/005.032_golden key.anm2",
			tospawn = function(ent) local q = Isaac.Spawn(5,30,2,ent.Position,ent.Velocity,nil):ToPickup() return q end,
			weigh = 1,
		},
		[8] = {
			sprite = "gfx/005.034_chargedkey.anm2",
			tospawn = function(ent) local q = Isaac.Spawn(5,30,4,ent.Position,ent.Velocity,nil):ToPickup() return q end,
			weigh = 4,
		},
		[9] = {
			sprite = "gfx/005.042_double bomb.anm2",
			tospawn = function(ent) local q = Isaac.Spawn(5,40,2,ent.Position,ent.Velocity,nil):ToPickup() return q end,
			weigh = 4,
		},
		[10] = {
			sprite = "gfx/005.043_golden bomb.anm2",
			tospawn = function(ent) local q = Isaac.Spawn(5,40,4,ent.Position,ent.Velocity,nil):ToPickup() return q end,
			weigh = 1,
		},
		[11] = {
			sprite = "gfx/005.069_grabbag.anm2",
			tospawn = function(ent) local q = Isaac.Spawn(5,69,0,ent.Position,ent.Velocity,nil):ToPickup() return q end,
			weigh = 3,
		},
		[12] = {
			sprite = function(s,data) local id = data.subtype s:Load("gfx/mimics/Inspiration/Inspiration_collectible.anm2",true) auxi.illustrate_sprite({Type = 5,Variant = 100,SubType = id,},s) end,
			tospawn = function(ent,data) local q = Isaac.Spawn(5,100,data.subtype,ent.Position,ent.Velocity,nil):ToPickup() return q end,
			weigh = 7,
			item = true,
			--anim = "Idle",
			posoffset = Vector(0,20),
		},
	},
}

for u,v in pairs(item.info) do v["id"] = u end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,rng,pos)
	local player = auxi.have_player_has_collectible(item.entity)
	if player then
		local room = Game():GetRoom()
		local rnd = rng:RandomFloat()
		if rnd > 0.4 then
			local q = Isaac.Spawn(5,item.target.Variant,item.target.SubType,room:FindFreePickupSpawnPosition(pos,10,true),Vector(0,0),player):ToPickup()
		end
	end
end,
})
--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 5 and v.Variant == 2439 then v.Color = Color(0.3,0.3,0.3,0.3) end end
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = item.target.Variant,
Function = function(_,ent)
	if ent.SubType == item.target.SubType then
		local s = ent:GetSprite()
		local rng = ent:GetDropRNG()
		local info = item.info[1]
		if consistance_holder.try_check_entity(ent,item.own_key) then 
			info = item.info[ent:GetData()._Data[item.own_key]["id"]]
		else
			info = auxi.random_in_weighed_table(item.info,rng)
			consistance_holder.try_hold_over_entity(ent,item.own_key)
			ent:GetData()._Data[item.own_key]["id"] = info.id
			if info.item then ent:GetData()._Data[item.own_key]["subtype"] = auxi.get_item_from_pool(nil,true,rng) end
			consistance_holder.try_hold_entity(ent,item.own_key) 
		end
		auxi.check_if_any(info.sprite,s,ent:GetData()._Data[item.own_key])
		if type(info.sprite) == "string" then s:Load(info.sprite) end
		if Game():GetRoom():GetFrameCount() == -1 then s:Play("Idle",true)
		else s:Play(info.anim or "Appear",true) end
		if info.posoffset then ent.PositionOffset = info.posoffset end
		s.Color = Color(0.3,0.3,0.3,0.3)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = item.target.Variant,
Function = function(_,ent)
	if ent.SubType == item.target.SubType then
		local s = ent:GetSprite()
		if s:IsFinished("Appear") then
			s:Play("Idle",true)
		end
		if ent.FrameCount % 3 == 1 then
			local rnd = auxi.random_2()
			local player = auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
			local val = auxi.get_absolute_heart(player)
			local info = auxi.check_lerp(val,item.heartval2num)
			s.Color = Color(0.3 + 0.4 * info.val,0.3 + 0.4 * info.val,0.3 + 0.4 * info.val,rnd * 0.3 + info.val * 0.5 + 0.2)
			for playerNum = 1, Game():GetNumPlayers() do
				local t_player = Game():GetPlayer(playerNum - 1)
				if auxi.get_absolute_heart(t_player) > 1 and (t_player.Position - ent.Position):Length() < 60 then
					ent.Velocity = ent.Velocity + (ent.Position - t_player.Position) / 10
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = item.target.Variant,
Function = function(_,ent,col,low)
	if ent.SubType == item.target.SubType then
		local player = col:ToPlayer()
		if player then
			if auxi.get_absolute_heart(player) <= 1 then
				local e = Isaac.Spawn(1000,97,0,player.Position,Vector(0,0),player):ToEffect() local es = e:GetSprite() es.Color = Color(200/255,1,1,1) es.Scale = Vector(2,2)
				if consistance_holder.try_check_entity(ent,item.own_key) then 
					local info = item.info[ent:GetData()._Data[item.own_key]["id"] or 1]
					item[item.own_key.."sprite"]:Play("Flash",true)
					local q = auxi.check_if_any(info.tospawn,ent,ent:GetData()._Data[item.own_key])
					auxi.self_morph(q)
				end
				ent:Remove()
			end
		end
	end
end,
})

function item.reload_sprite()
	item[item.own_key.."sprite"] = Sprite()
	item[item.own_key.."sprite"]:Load("gfx/mimics/Inspiration/Blackout_Inspiration.anm2",true)
	item[item.own_key.."sprite"]:Play("Flash",true)
	item[item.own_key.."sprite"]:SetLastFrame()
	item[item.own_key.."sprite"]:Update()
	item[item.own_key.."sprite"].Color = Color(1,1,1,0.3)
end
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.reload_sprite()
end,
})
item.reload_sprite()

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	if item[item.own_key.."sprite"]:IsFinished("Flash") == false then
		item[item.own_key.."sprite"]:Render(Vector(0,0),Vector(0,0),Vector(0,0))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if item[item.own_key.."sprite"]:IsFinished("Flash") == false then
		item[item.own_key.."sprite"]:Update()
		if item[item.own_key.."sprite"]:IsEventTriggered("Freeze") then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MIRROR_ENTER,1,1,false,0,2)
		end
	end
end,
})

return item
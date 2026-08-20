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
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Witch,
	own_key = "Thoth_cd1_Wit_",
	speed_map = {
		[1] = 3,
		[2] = 2,
		[3] = 1.5,
		[4] = 1.2,
	},
	color = Color(0.4,0.4,0.7,1,0.1,0.1,0.3),
	localizer = {},
}

local function get_pos_info(id,mxn)		--层级算法
	local mmxn = mxn
	local iid = id
	item.localizer[mxn] = item.localizer[mxn] or {}
	if item.localizer[mxn] and item.localizer[mxn][id] then return item.localizer[mxn][id] end
	local ret = {row = 1,col = 1,}
	local mcnt = 5
	while(iid > mcnt) do
		ret.col = ret.col + 1
		iid = iid - mcnt
		mmxn = mmxn - mcnt
		mcnt = mcnt + 3
	end
	mcnt = math.min(mcnt,mmxn)
	ret.row = 360 / mcnt * iid
	item.localizer[mxn][id] = ret
	return ret
end

function item.reload_sprite()
	item[item.own_key.."sprite"] = Sprite()
	item[item.own_key.."sprite"]:Load("gfx/cards/Blackout_cd1_Witch.anm2",true)
	item[item.own_key.."sprite"]:Play("Flash",true)
	item[item.own_key.."sprite"]:SetLastFrame()
	item[item.own_key.."sprite"]:Update()
	item[item.own_key.."sprite"].Color = Color(1,1,1,0.4)
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.reload_sprite()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	for ii = 1,1 do if d[item.own_key.."effect"] then
		d[item.own_key.."effect_s"] = (d[item.own_key.."effect_s"] or 0) + 1
		for i = #(d[item.own_key.."effect"]),1,-1 do
			local v = d[item.own_key.."effect"][i]
			if auxi.check_all_exists(v) == false then table.remove(d[item.own_key.."effect"],i) end
		end
		if #(d[item.own_key.."effect"]) == 0 then d[item.own_key.."effect"] = nil break end
		local n_entity = Isaac.GetRoomEntities()
		local n_enemy = auxi.getenemies(n_entity)
		for u,v in pairs(n_enemy) do
			local d3 = v:GetData()
			if auxi.check_all_exists(d3[item.own_key.."target"]) == false and v:HasEntityFlags(EntityFlag.FLAG_FREEZE) == false then
				d3[item.own_key.."target"] = d[item.own_key.."effect"][1]
				d[item.own_key.."effect"][1]:GetData()[item.own_key.."target"] = v
				d[item.own_key.."effect"][1]:GetData()[item.own_key.."position"] = nil
				table.remove(d[item.own_key.."effect"],1)
			end
			if #d[item.own_key.."effect"] == 0 then break end
		end
		
		for u,v in pairs(d[item.own_key.."effect"]) do
			local d2 = v:GetData()
			--local del = u * 360 / #d[item.own_key.."effect"]
			local pos_info = get_pos_info(u,#d[item.own_key.."effect"])
			d2[item.own_key.."position"] = player.Position + (10 + (pos_info.col) * 15 + 8 * math.sin(d[item.own_key.."effect_s"]/180 * 3.14 * 5)) * auxi.MakeVector(d[item.own_key.."effect_s"] * 3 * (item.speed_map[#d[item.own_key.."effect"]] or 1) + pos_info.row)		--#d[item.own_key.."effect"]
			--d2[item.own_key.."velocity"] = auxi.Get_rotate(auxi.MakeVector(d[item.own_key.."effect_s"] * 3)):Normalized()
		end
	end end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect_s"] then
		ent.Height = - 24
		local player = d[item.own_key.."player"] or Game():GetPlayer(0)
		--if d[item.own_key.."position"] then ent.Position = ent.Position * 0.8 + d[item.own_key.."position"] * 0.2 end
		if d[item.own_key.."target"] then
			if auxi.check_all_exists(d[item.own_key.."target"]) then d[item.own_key.."position"] = d[item.own_key.."target"].Position 
			else 
				d[item.own_key.."target"] = nil
				local d2 = player:GetData()
				d2[item.own_key.."effect"] = d2[item.own_key.."effect"] or {}
				table.insert(d2[item.own_key.."effect"],#d2[item.own_key.."effect"] + 1,ent)
			end
		end
		if d[item.own_key.."position"] then
			local dir = (d[item.own_key.."position"] - ent.Position)
			if dir:Length() > 0.1 then
				ent.Velocity = dir:Normalized() * math.min(15 + math.min(20,ent.FrameCount),dir:Length() * 0.4)
			end
		end
		--if d[item.own_key.."velocity"] then	ent.Velocity = d[item.own_key.."velocity"] end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local d = ent:GetData()
	if d[item.own_key.."effect_s"] then
		if col:ToNPC() and auxi.isenemies(col) and col:IsDead() == false and not col:HasEntityFlags(EntityFlag.FLAG_FREEZE) then
			col = col:ToNPC()
			local d2 = col:GetData()
			local color = item.color
			local ti = 5 * 30
			d2[item.own_key.."effect"] = true
			d2[item.own_key.."colorer"] = Attribute_holder.try_hold_and_rewind_attribute(col,"Color",color,ti,Attribute_holder.descriptors.color())		--重载不等号
			Attribute_holder.try_hold_and_rewind_attribute(col,"EntityFlag_FLAG_FREEZE",true,ti,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
		end
	end
end,
})

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
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_FREEZE,1.2,1,false,0,2)
			local n_entity = Isaac.GetRoomEntities()
			local n_enemy = auxi.getenemies(n_entity)
			for u,v in pairs(n_enemy) do
				v:AddSlowing(EntityRef(player),30 * 5,0.9,Color(0.8,0.8,1,1,0.15,0.15,0.3))
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] and ent:HasEntityFlags(EntityFlag.FLAG_FREEZE) and ent.Type ~= 963 then
		local player = Game():GetPlayer(0)
		ent:AddEntityFlags(EntityFlag.FLAG_ICE)
		item[item.own_key.."sprite"]:Play("Flash",true)
		--立即结束
		Attribute_holder.try_rewind_attribute(ent,"Color",d[item.own_key.."colorer"],Attribute_holder.descriptors.color())
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		local cnt = 4
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then cnt = 8 end
		for i = 1,cnt do
			local q = Isaac.Spawn(2,41,0,player.Position,Vector(0,0),player):ToTear()
			local d2 = q:GetData()
			d2.Ignore_me_flag = true
			d2[item.own_key.."player"] = player
			d2[item.own_key.."effect_s"] = true
			q.CollisionDamage = player.Damage
			q.TearFlags = BitSet128(1<<0,0)
			if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then q.CollisionDamage = player.Damage * 3 q:GetSprite().Scale = Vector(1.5,1.5) end
			table.insert(d[item.own_key.."effect"],#d[item.own_key.."effect"] + 1,q)
		end
	end
end,
})

item.reload_sprite()

return item
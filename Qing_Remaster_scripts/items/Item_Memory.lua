local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	myToCall = {},
	ToCall = {},
	entity = enums.Items.Memory,
	own_key = "Item_Memory_",
	ignorers = {
		[enums.Items.Hypermnesia] = true,
	},
	buffers = {},
	memory_colors = {
		[1] = Color(1,0,0,0.7,0.5,0,0),
		[2] = Color(1,0.1,0.5,0.7,0.5,0,0.2),
		[3] = Color(1,0,1,0.7,0.2,0,0.2),
		[4] = Color(0.4,0,1,0.7,0,0,0.3),
		[5] = Color(0,0.5,1,0.7,0,0.2,0.5),
		[6] = Color(0.5,0.5,0,0.7,0.2,0.2,0),
		[7] = Color(0.4,0.6,0,0.8,0.1,0.3,0),
		[8] = Color(1,1,0,0.7,0.5,0.4,0),
		[9] = Color(1,0.7,0,0.7,0.5,0.2,0),
		[10] = Color(1,1,1,0.7,0,0,0),
	},
	belial_colors = function(c)
		return Color(c.R + c.G * 0.3 + c.B * 0.3,c.G * 0.3,c.B * 0.3,1,c.RO,c.GO,c.BO)
	end,
	Colorinfo = {
		{frame = 0 * 18,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 1 * 18,R = 0,G = 1,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 2 * 18,R = 0.5,G = 1,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 3 * 18,R = 1,G = 0.5,B = 0,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 4 * 18,R = 1,G = 0,B = 0.5,A = 1,RO = 0,GO = 0,BO = 0,},
		{frame = 5 * 18,R = 0.5,G = 0,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		
		{frame = 6 * 18,R = 0,G = 0.5,B = 1,A = 1,RO = 0,GO = 0,BO = 0,},
		total = 6 * 18,
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	for u,v in pairs(item.buffers) do
		local s = v.sprite
		s:Render(v.pos,Vector(0,0),Vector(0,0))
		auxi.check_if_any(v.Update,v)
	end
	for i = #item.buffers,1,-1 do
		if item.buffers[i].remove_me then table.remove(item.buffers,i) end
	end
end,
})

function item.add_memory_bubble(params)
	params = params or {}
	local s = Sprite()
	s:Load("gfx/mimics/Memory/memory_bubble.anm2",true)
	s:Play("Idle"..tostring(math.random(9)),true)
	s.Color = auxi.random_in_table(item.memory_colors)
	if params.belial then s.Color = item.belial_colors(s.Color) end
	table.insert(item.buffers,{sprite = s,pos = params.pos,acce = params.acce,fade = params.fade,
	Update = function(v)
		v.vel = (v.vel or Vector(0,0)) + (v.acce or Vector(0,-1))
		v.pos = (v.pos or Vector(auxi.GetScreenSize().X/2,auxi.GetScreenSize().Y)) + v.vel
		if v.pos.Y < 0 then v.remove_me = true end
		if v.fade then v.sprite.Color = auxi.AddColor(v.sprite.Color,auxi.MulColor(v.sprite.Color,Color(1,1,1,0,1,1,1)),0.98,0.02) end
	end,})
	if #item.buffers > 1024 then table.remove(item.buffers,1) end
end

function item.add_memory(cnt1,cnt2,params2)
	params2 = params2 or {}
	for j = 1,cnt1 do
		delay_buffer.addeffe(function(params)
			for i = 1,cnt2 do 
				item.add_memory_bubble({pos = Vector(math.random(10000)/10000 * auxi.GetScreenSize().X,auxi.GetScreenSize().Y),acce = Vector(0,-(math.random(1000)/1000 * 0.3 + 0.001)),fade = params2.fade,belial = params2.belial,})
			end
		end,{},j * 5 - math.random(5))
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,collect,rng,player,useFlags,activeSlot,varData)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		save.elses[item.own_key.."effect"] = true
		Game():Darken(1,300)
		Game():ShakeScreen(150)
		local belial = auxi.should_do_belial(player)
		save.elses[item.own_key.."belial"] = belial
		item.add_memory(15,25,{belial = belial,})
		return {Remove = true, ShowAnim = true}
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = nil
	end
	item.buffers = {}
	item.Counter = math.max(3,Game():GetFrameCount())
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GET_COLLECTIBLE_FROM_POOL, params = nil,
Function = function(_,colid,pool,decrease,seed)
	if save.elses[item.own_key.."effect"] and Game():GetFrameCount() > (item.Counter or 3) and auxi.check_if_any(item.ignorers[colid]) ~= true and item.seted ~= true then
		item.seted = true
		local rng = RNG()
		rng:SetSeed(seed,1)
		local ret = auxi.get_random_item_that_player_has(nil,rng)
		local belialsucc = (save.elses[item.own_key.."belial"] and rng:RandomInt(2) == 1)
		if belialsucc then ret = auxi.get_item_from_pool(3,decrease,rng) end
		item.seted = nil
		if ret then 
			item.add_memory(5,10,{fade = true,belial = belialsucc,})
			return ret 
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GET_COLLECTIBLE, params = nil,
Function = function(_,colid,pool,decrease,seed)
	if save.elses[item.own_key.."effect"] and Game():GetFrameCount() > (item.Counter or 3) and auxi.check_if_any(item.ignorers[colid]) ~= true and item.seted ~= true then
		item.seted = true
		local rng = RNG()
		rng:SetSeed(seed,1)
		local ret = auxi.get_random_item_that_player_has(nil,rng)
		local belialsucc = (save.elses[item.own_key.."belial"] and rng:RandomInt(2) == 1)
		if belialsucc then ret = auxi.get_item_from_pool(3,decrease,rng) end
		item.seted = nil
		if ret then 
			item.add_memory(5,10,{fade = true,belial = belialsucc,})
			return ret 
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = nil,
Function = function(_,player,collid,cnt,touched)
	if save.elses[item.own_key.."effect"] and touched == false then
		if player:GetCollectibleNum(collid,true) ~= cnt then
			local n_wisp = auxi.get_wisps(player,item.entity)
			if #n_wisp > 0 then 
				for u,v in pairs(n_wisp) do
					local d = v:GetData()
					local s = v:GetSprite()
					d.Memory_mul = (d.Memory_mul or 0) + cnt
					v.MaxHitPoints = v.MaxHitPoints + (cnt * 2)
					v.HitPoints = v.HitPoints + (cnt * 2)
					d.Memory_scale = (d.Memory_scale or Vector(0,0)) * 1.5
					s.Color = Color(1,1,1,1,1,1,1)
					local e = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.POOF02,2,v.Position,Vector(0,0),nil)
					local s2 = e:GetSprite()
					s2.Scale = s.Scale
					s2.Color = Color(-1,-1,-1,1)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.WISP and ent.SubType == item.entity then
		if save.elses[item.own_key.."effect"] then
			Game():Darken(1,300)
			Game():ShakeScreen(60)
			save.elses[item.own_key.."effect"] = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.WISP,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.WISP and ent.SubType == item.entity then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local mul = d.Memory_mul or 0
		d.Memory_scale = (d.Memory_scale or Vector(1,1)) * 0.98 + Vector(mul * 0.05 + 1,mul * 0.05 + 1) * 0.02
		s.Scale = d.Memory_scale
		s.Color = auxi.AddColor(s.Color,Color(1,1,1,1),0.98,0.02)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local n_wisp = auxi.get_wisps(nil,item.entity)
	if #n_wisp > 0 then 
		for u,v in pairs(n_wisp) do
			v.HitPoints = v.MaxHitPoints
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local d = ent:GetData()
		d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
		ent:GetSprite().Color = auxi.table2color(auxi.check_lerp(d[item.own_key.."counter"] % item.Colorinfo.total,item.Colorinfo))
	end
end,
})

return item
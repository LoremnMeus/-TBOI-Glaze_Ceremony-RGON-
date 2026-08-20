local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local grid_morpher = require("Qing_Remaster_scripts.grids.grid_morpher")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Tower_r,
	own_key = "Thoth_cd16r_Tow_",
	grid_info = {
		[1] = {
			loadname = "gfx/grid/grid_rock.anm2",
			playname = {
				[1] = {name = "normal",frame = {0,1,2,},tp = 2,weigh = 250,},
				[2] = {name = "black",frame = {0,},tp = 3,weigh = 30,},
				[3] = {name = "tinted",frame = {0,},tp = 4,weigh = 3,},
				[4] = {name = "alt",frame = {0,1,2,},tp = 6,weigh = 30,},
				[5] = {name = "bombrock",frame = {0,},tp = 5,weigh = 50,},
				[6] = {name = "superspecial",frame = {0,},tp = 22,weigh = 2,},
				[7] = {name = "pillar",frame = {0,1,},tp = 24,weigh = 50,},
				[8] = {name = "spiked",frame = {0,1,},tp = 25,weigh = 50,},
				[9] = {name = "alt2",frame = {0,},tp = 26,weigh = 1,},
				[10] = {name = "foolsgold",frame = {0,1,2,},tp = 27,weigh = 5,},
			},
			vr = 0,
			weigh = 250,
			toget = function(info,rng)
				local ret = {}
				local s = Sprite()
				local rock_info = auxi.random_in_weighed_table(auxi.deepCopy(info.playname),rng)
				s:Load(info.loadname,true)
				s:SetFrame(rock_info.name,auxi.random_in_table(rock_info.frame,rng))
				ret.GetSprite = function(self) return s end
				ret.GetType = function(self) return rock_info.tp end
				ret.GetVariant = function(self) return info.vr end
				return ret
			end,
		},
		[2] = {
			loadname = "gfx/grid/grid_poop.anm2",
			playname = {"State1","State2","State3","State4",},
			tp = 14,
			vr = {
				[1] = {id = 0,weigh = function() local ret = auxi.get_grid_by_backdrop_info() if ret.u == 4 and ret.v <= 2 then return 10 else return 100 end end,},
				[2] = {id = 1,weigh = function() local ret = auxi.get_grid_by_backdrop_info() if ret.u == 4 and ret.v <= 2 then return 100 else return 10 end end,},
				[3] = {id = 2,weigh = 10,},
				[4] = {id = 3,weigh = 5,},
				[5] = {id = 4,weigh = 3,},
				[6] = {id = 5,weigh = 5,},
				[7] = {id = 6,weigh = 15,},
				[8] = {id = 11,weigh = 10,},
				[9] = {id = 12,weigh = 25,},
				[10] = {id = 13,weigh = 25,},
				[11] = {id = 14,weigh = 25,},
			},
			weigh = 40,
			toget = function(info,rng)
				local ret = {}
				local s = Sprite()
				s:Load(info.loadname,true)
				s:Play(auxi.random_in_table(info.playname,rng),true)
				s:SetLastFrame()
				local vr = auxi.random_in_weighed_table(info.vr,rng).id
				ret.GetSprite = function(self) return s end
				ret.GetType = function(self) return info.tp end
				ret.GetVariant = function(self) return vr end
				return ret
			end,
		},
		[3] = {
			loadname = "gfx/grid/grid_locks.anm2",
			playname = "Idle",
			tp = 11,
			vr = 0,
			weigh = 5,
			toget = function(info,rng)
				local ret = {}
				local s = Sprite()
				s:Load(info.loadname,true)
				s:Play(info.playname,true)
				s:SetLastFrame()
				ret.GetSprite = function(self) return s end
				ret.GetType = function(self) return info.tp end
				ret.GetVariant = function(self) return info.vr end
				return ret
			end,
		},
		[4] = {
			loadname = {"gfx/grid/grid_tnt.anm2","gfx/grid/grid_redtnt.anm2",},
			playname = {"Idle","IdleMedium","ReadyToExplode",},
			tp = 12,
			vr = 0,
			weigh = 5,
			toget = function(info,rng)
				local ret = {}
				local s = Sprite()
				s:Load(auxi.random_in_table(info.loadname,rng),true)
				s:Play(auxi.random_in_table(info.playname,rng),true)
				s:SetLastFrame()
				ret.GetSprite = function(self) return s end
				ret.GetType = function(self) return info.tp end
				ret.GetVariant = function(self) return info.vr end
				return ret
			end,
		},
		[5] = {
			loadname = "gfx/grid/grid_poop_giant.anm2",
			playname = {"State1","State2","State3","State4",},
			tp = 14,
			vr = 7,
			weigh = 1,
			toget = function(info,rng)
				local ret = {}
				local s = Sprite()
				s:Load(info.loadname,true)
				s:Play(auxi.random_in_table(info.playname,rng),true)
				s:SetLastFrame()
				ret.GetSprite = function(self) return s end
				ret.GetType = function(self) return info.tp end
				ret.GetVariant = function(self) return info.vr end
				return ret
			end,
		},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if ent.Height > -50 then 
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL 
		else
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE 
		end
		if auxi.check_all_exists(d[item.own_key.."target"]) then
			local dir = d[item.own_key.."target"].Position - ent.Position
			ent.Velocity = dir:Normalized() * math.min(25,dir:Length() * 0.4)
		else
			d[item.own_key.."target"] = nil
			ent.Velocity = ent.Velocity * 0.9
		end
	end
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
		local cnt = 10
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then cnt = 16 end
		local rk_info = grid_morpher.get_morph_dir()
		Game():ShakeScreen(10)
		for i = 1,cnt do
			delay_buffer.addeffe(function(params)
				local rnd = rng:RandomInt(4 + i * 2) + 1
				for j = 1,rnd do
					local infos = auxi.random_in_weighed_table(auxi.deepCopy(item.grid_info),rng)
					local fake_grid = infos.toget(infos,rng)
					local targ = auxi.random_in_table(auxi.getenemies(),rng)
					fake_grid.Position = room:GetRandomPosition(0)
					--if rng:RandomInt(1000) > 800 then fake_grid.Position = ((targ or {}).Position or fake_grid.Position) end -- + auxi.MakeVector(math.random(360)) * math.random(8,35)
					local q = grid_morpher.morph_grid(fake_grid,{rk_info = rk_info,spawner = player,})
					q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE 
					q.Height = -1000
					q.FallingAcceleration = math.random(1000)/1000 * (3 + i * 0.3) + 2
					
					local d2 = q:GetData()
					d2[item.own_key.."effect"] = true
					if rng:RandomInt(1000) > 500 then d2[item.own_key.."target"] = targ end
				end
			end,{},(i - 1) * 5)
		end
	end
end,
})

function item.fire_fake_rocks(player,pos,rng,params)
	params = params or {}
	local infos = auxi.random_in_weighed_table(auxi.deepCopy(item.grid_info),rng)
	local fake_grid = infos.toget(infos,rng)
	fake_grid.Position = pos
	local q = grid_morpher.morph_grid(fake_grid,{spawner = player,})
	return q
end

return item
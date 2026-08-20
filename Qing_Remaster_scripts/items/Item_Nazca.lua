local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	post_ToCall = {},
	entity = enums.Items.Nazca,
	familiar = enums.Familiars.Nazca,
	dirs = {
		Up = {move = Vector(1,0),dir_move = 0,},
		Right = {move = Vector(0,1),dir_move = 90,},
		Left = {move = Vector(0,-1),dir_move = -90,},
		Down = {move = Vector(-1,0),dir_move = 180,},
	},
	record_dirs = {
		"Up","Right","Left","Down",
	},
	muloffset = 12,
	allocate_map = {},
	move_stag = {
		[1] = {								--道
			stag = function(ent)
				local d = ent:GetData()
				local counter = d.counter
				local mx_counter = d.mx_counter
				local r = "Right"
				local l = "Left"
				if counter == 0 then
					if d.dir_dice and d.ignore_dice_counter then
						d.ignore_dice_counter = nil
					else
						d.dir_dice = math.random(2)
					end
					d.counter_dis_part = math.floor(mx_counter/2) - 1 + math.floor(mx_counter/8) * (math.random(2) * 2 - 3)
					d.counter_dis_part2 = math.max(1,d.counter_dis_part - math.random(3))
				end
				if d.dir_dice == 1 then 
					l = "Right" 
					r = "Left"
				end
				if d.counter_dis_part == nil then d.counter_dis_part = math.floor(mx_counter/2) - 1 + math.floor(mx_counter/8) * (math.random(2) * 2 - 3) end
				if counter == d.counter_dis_part - 1 or counter == d.counter_dis_part then
					return l
				end
				if counter == mx_counter - 2 or counter == mx_counter - 1 then
					return r 
				end
				return "Up"
			end,
			mx_counter = function()
				return math.random(6) + 8
			end,
			trans_stag = function(d)
				if math.random(1000) < 850 then 
					d.ignore_dice_counter = true
					return 1
				end
				if math.random(1000) < 400 then 
					return 3
				end
			end,
		},
		[2] = {								--直线
			stag = function(ent)
				return "Up"
			end,
			mx_counter = function()
				return math.random(7)
			end,
			trans_stag = function(d)
				if math.random(1000) < 400 then 
					return 3
				end
				if math.random(1000) < 200 then 
					return 4
				end
			end,
		},
		[3] = {								--转弯
			stag = function(ent)
				if math.random(2) == 1 then
					return "Right"
				else 
					return "Left"
				end
			end,
			mx_counter = function()
				return 1
			end,
			trans_stag = function(d)
				if math.random(1000) < 400 then 
					return 2
				end
				if math.random(1000) < 300 then 
					return 1
				end
				return 5
			end,
		},
		[4] = {								--环
			stag = function(ent)
				local d = ent:GetData()
				local counter = d.counter
				local mx_counter = d.mx_counter
				local r = "Right"
				local l = "Left"
				if counter == 0 then d.dir_dice = math.random(2) end
				if d.dir_dice and d.dir_dice == 1 then 
					l = "Right" 
					r = "Left"
				end
				if counter == 0 or counter == mx_counter - 1 then return l end
				if counter == math.floor(mx_counter * 0.125) or counter == math.floor(mx_counter * 0.375) or counter == math.floor(mx_counter * 0.625) or counter == math.floor(mx_counter * 0.875) then return r end
				return "Up"
			end,
			mx_counter = function()
				return math.random(10) + 14
			end,
			trans_stag = function(d)
				if math.random(1000) < 500 then 
					return 2
				end
			end,
		},
		[5] = {								--初始
			stag = function(ent)
				return "Up"
			end,
			mx_counter = function()
				return 3
			end,
			trans_stag = function(d)
				return 2
			end,
		},
		[6] = {								--向敌人方向进攻
			stag = function(ent)
				local d = ent:GetData()
				if d.target == nil or d.target:Exists() == false or d.target:IsDead() == true then
				else
					d.target = auxi.get_by_nearest_enemy(ent.Position)
				end
				if d.target then
					return auxi.Get_dir_name(auxi.Get_direction_by_angle((d.target.Position - ent.Position):GetAngleDegrees() - d.now_dir))
				else
					local player = ent.Player
					if player == nil then player = Game():GetPlayer(0) end
					return auxi.Get_dir_name(auxi.Get_direction_by_angle((player.Position - ent.Position):GetAngleDegrees() - d.now_dir))
				end
				return "Up"
			end,
			mx_counter = function()
				return 5 + math.random(10)
			end,
			trans_stag = function(d)
			end,
		},
	},
}
auxi.add_to_seija(item.entity)

local function insert_map(pos,dir,value)
	pos = auxi.GetChampPosition(pos,item.muloffset)
	if value == nil then value = 0 end
	if dir then 
		item.allocate_map[""..pos.X.."_"..pos.Y..dir] = math.max(value, (item.allocate_map[""..pos.X.."_"..pos.Y..dir] or 0) + 1)
	else 
		item.allocate_map[""..pos.X.."_"..pos.Y] = math.max(value, (item.allocate_map[""..pos.X.."_"..pos.Y] or 0) + 1)
	end
end

local function check_map(pos,dir)
	pos = auxi.GetChampPosition(pos,item.muloffset)
	if dir == nil then
		return item.allocate_map[""..pos.X.."_"..pos.Y] or 0
	else
		return item.allocate_map[""..pos.X.."_"..pos.Y..dir] or 0
	end
	return 0
end

local function check_multi_map(pos)
	local ret = 0
	for i = 1,3 do
		for j = 1,3 do
			ret = ret + check_map(Vector(pos.X + (i-2) * item.muloffset,pos.Y + (j-2) * item.muloffset))
		end
	end
	return ret / 9
end

local function insert_movable_map(pos,dir,value)
	insert_map(pos + item.dirs[dir].move * item.muloffset,nil,value)
end

local function check_kind(pos,dir)
	return check_map(pos + item.dirs[dir].move * item.muloffset,nil)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cnt > 0 then cnt = cnt * 2 + 4 + math.floor(Game():GetLevel():GetStage()/2) end
	if auxi.should_do_Seija(player) then cnt = math.min(1,cnt) end
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
	local d = player:GetData()
	local counter = check_multi_map(player.Position)
	if d.Nazca_counter_delay == nil then d.Nazca_counter_delay = 0 end
	d.Nazca_counter_delay = d.Nazca_counter_delay * 0.7 + counter * 0.3
	counter = d.Nazca_counter_delay
	if counter > 0 then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage * (math.log(counter + 1) / math.log(10) * 0.5 + 1)
		end
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + (math.sqrt(counter + 10) - math.sqrt(10)) * 0.03
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local should_count = false
	local player = Game():GetPlayer(0)
	for playerNum = 1, Game():GetNumPlayers() do
		local t_player = Game():GetPlayer(playerNum - 1)
		if t_player:HasCollectible(item.entity) or t_player:GetEffects():GetCollectibleEffectNum(item.entity) > 0 then
			player = t_player
			should_count = true
			break
		end
	end
	if should_count then
		if ent:IsVulnerableEnemy() and ent:IsActiveEnemy() and not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			local counter = check_multi_map(ent.Position)
			if counter >= 1 then
				if ent:IsFrame(10,0) == true then
					ent:TakeDamage(math.sqrt(counter) * math.sqrt(player.Damage) * 0.1,0,EntityRef(player),0)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local should_count = false
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			should_count = true
		end
	end
	if should_count then
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SPEED)
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	s:Play("Up",true)
	d.dont_over_write_velocity = true
	d.now_dir = 0
	d.threshold = 0 
	ent.Position = auxi.GetChampPosition(ent.Position,item.muloffset)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item.allocate_map = {}
	local n_entity = Isaac.GetRoomEntities()
	local targ = auxi.getothers(n_entity,3,item.familiar,nil)
	for u,v in pairs(targ) do
		v:GetData().threshold = 0
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.allocate_map = {}
end,
})

local function check_dirs(ent,lsttype)
	local room = Game():GetRoom()
	local tbl = {}
	local r_tbl = {}
	local d = ent:GetData()
	local player = ent.Player
	if player == nil then player = Game():GetPlayer(0) end
	local t_posid = room:GetGridIndex(ent.Position)
	local grid = room:GetGridEntity(t_posid)
	for u,v in pairs(item.dirs) do
		local t_pos = ent.Position + item.muloffset * (v.move)
		if room:GetGridCollisionAtPos(t_pos) ~= GridCollisionClass.COLLISION_NONE or room:IsPositionInRoom(t_pos,5) ~= true then
		else
			table.insert(tbl,u)
			r_tbl[u] = true
		end
	end
	if #tbl == 0 then		--四周都是死路，只能向角色移动
		local dir = auxi.Get_dir_name(auxi.Get_direction_by_angle((player.Position - ent.Position):GetAngleDegrees() - d.now_dir))
		d.move_state = 5
		d.mx_counter = 6
		d.counter = 0
		d.state = 1
		d.dir_stack = 0
		d.threshold = math.max(20,d.threshold + 2)
		if grid then room:DamageGrid(t_posid,1) end
		ent.Position = auxi.GetChampPosition(player.Position,item.muloffset)
		d.should_render_self = true
		return dir
	else
		if d.state == nil then d.state = 0 end
		if d.counter == nil then d.counter = 0 end
		if d.move_state == nil then d.move_state = 5 end
		if d.mx_counter == nil then d.mx_counter = 1 end
		if d.threshold == nil then d.threshold = 1 end
		if d.dir_stack == nil then d.dir_stack = 0 end
		d.counter = d.counter + 1
		if d.state == 0 then 		--通常情况，按照随机程式绘制地线
			--print(d.move_state)
			local info = item.move_stag[d.move_state]
			if d.counter >= d.mx_counter then 		--向下转移
				--print("switch")
				local Move_state = nil
				if info.trans_stag then
					Move_state = info.trans_stag(d)
				end
				if Move_state == nil then
					Move_state = math.random(#item.move_stag)
				end
				d.move_state = Move_state
				info = item.move_stag[d.move_state]
				d.counter = 0
				d.mx_counter = info.mx_counter()
			end
			if d.threshold > 70 then
				if math.random(1000) > 700 then
					d.move_state = 6
					info = item.move_stag[d.move_state]
					d.counter = 0
					d.mx_counter = info.mx_counter()
				end
			end
			local dir = info.stag(ent)
			local ignore_it = false
			if r_tbl[dir] ~= true then		--与地形冲突，优先解决地形问题。
				if math.random(1000) > 200 then
					--print("Collide with grid and move")
					local l = "Left"
					local r = "Right"
					if math.random(2) == 1 then 
						l = "Right"
						r = "Left"
					end
					if r_tbl[l] then dir = l
					elseif r_tbl[r] then dir = r
					elseif r_tbl["Up"] then dir = "Up"
					else dir = "Down" end
				else
					--print("Collide with grid and ignore")
					ignore_it = true
				end
			end
			if dir == "Left" then d.dir_stack = d.dir_stack + 1 end
			if dir == "Right" then d.dir_stack = d.dir_stack - 1 end
			if dir == "Down" then d.dir_stack = - d.dir_stack end
			if dir == "Up" then d.dir_stack = d.dir_stack * 0.9 end
			if d.dir_stack > 2.5 and r_tbl["Right"] then 
				dir = "Right"
				d.dir_stack = 2
			elseif d.dir_stack < -2.5 and r_tbl["Left"] then
				dir = "Left"
				d.dir_stack = -2
			end
			if ignore_it ~= true and check_kind(ent.Position,auxi.Direction_Plus(dir,d.now_dir)) >= 1 then		--与原有图线冲突，优先绘制未被绘制地带。
				--print("Collide "..dir)
				local checked = 1000000
				for u,v in pairs(tbl) do
					local offset = 0
					if v == "Down" then offset = 2 end
					local ck = check_kind(ent.Position,auxi.Direction_Plus(v,d.now_dir)) + offset
					if checked > ck then
						checked = ck
						dir = v
					end
				end
				if checked < 1000000 then	
					--print("checked "..dir)
					--d.threshold = math.max(0,d.threshold - 1)
					d.threshold = d.threshold + 1
				else
					--print("unchecked")
					--ent.Position = auxi.GetChampPosition(player.Position,item.muloffset)
				end
			else
				d.threshold = math.max(0,d.threshold - 1)
			end
			insert_movable_map(ent.Position,auxi.Direction_Plus(dir,d.now_dir),d.threshold)
			return dir
		elseif d.state == 1 then		--出现冲突，尝试寻找合理地址继续绘制
			local info = item.move_stag[d.move_state]
			if d.counter >= d.mx_counter then 		--向下转移
				local Move_state = nil
				if info.trans_stag then
					Move_state = info.trans_stag(d)
				end
				if Move_state == nil then
					Move_state = math.random(#item.move_stag)
				end
				d.move_state = Move_state
				info = item.move_stag[d.move_state]
				d.counter = 0
				d.mx_counter = info.mx_counter()
				d.state = 0
			end
			local dir = info.stag(d)
			insert_movable_map(ent.Position,auxi.Direction_Plus(dir,d.now_dir),d.threshold)
			return dir
		elseif d.state == 2 then		--混乱模式，随机绘图
			if math.random(1000) > 300 then 
				return lsttype 
			else
				return item.record_dirs[math.random(#item.record_dirs)]
			end
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d.now_dir == nil then d.now_dir = 0 end
	s.Rotation = d.now_dir
	ent.Velocity = Vector(0,0)
	local finish_type = nil
	for u,v in pairs(item.dirs) do
		if s:IsFinished(u) then
			finish_type = u
			break
		end
	end
	if finish_type then
		--print(finish_type)
		local info = item.dirs[finish_type]
		ent.Position = auxi.GetChampPosition(ent.Position,item.muloffset)
		if d.should_render_self then
			local q = auxi.fire_nil(ent.Position,Vector(0,0))
			local s2 = q:GetSprite()
			s2:Load("gfx/mimics/Nazca/Nazca.anm2",true)
			s2:Play("SignedHead",true)
			s2.Color = s.Color
			q:AddEntityFlags(EntityFlag.FLAG_RENDER_FLOOR)
			d.should_render_self = nil
		end
		local q = auxi.fire_nil(ent.Position,Vector(0,0))
		local s2 = q:GetSprite()
		s2:Load("gfx/mimics/Nazca/Nazca.anm2",true)
		s2:Play("Signed"..finish_type,true)
		s2.Rotation = d.now_dir
		if s2.Rotation == 270 then 
			if q.Position.X % 60 == 24 or q.Position.X % 60 == 36 then
				q.Position = q.Position + Vector(1,0)
			end
		end
		if s2.Rotation == 90 then 
			if q.Position.Y % 60 == 24 or q.Position.Y % 60 == 36 then
				q.Position = q.Position + Vector(0,1)
			end
		end
		s2.Color = s.Color
		q:AddEntityFlags(EntityFlag.FLAG_RENDER_FLOOR)
		
		ent.Position = auxi.GetChampPosition(ent.Position + item.muloffset * auxi.get_by_rotate(info.move,d.now_dir),item.muloffset)
		d.now_dir = (d.now_dir + info.dir_move) % 360
		s.Rotation = d.now_dir
		if d.threshold == nil then d.threshold = 0 end
		local dir = check_dirs(ent,finish_type)
		local col_dd = math.min(1,math.sqrt(d.threshold)/33)
		s.Color = auxi.AddColor(Color(1,1,1,1),Color(1,0,0,1,1,0,0),1 - col_dd,col_dd)
		s:Play(dir,true)
	end
end,
})

return item
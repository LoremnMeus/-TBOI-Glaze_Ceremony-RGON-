local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local item = {
	ToCall = {},
	entity = enums.Items.Gold_Rush,
	own_key = "Item_Gold_Rush_",
	familiar = {Variant = 73,SubType = 0,},
	fools_gold_chance = {
		base = 0.12,
		decay = 0.62,
		min = 0.018,
		extra = 0.025,
	},
	reset_rooms = {min = 3,max = 5,},
	spider_no_collision_frames = 10,
	spider_throw = {
		speed = 6.5,
		up_speed = -6.5,
		gravity = 0.55,
		start_offset = -12,
	},
}

local golden_spider_color = Color(1,1,1,1,0.8,0.8,0)

local function set_golden_spider(spider)
	local sprite = spider:GetSprite()
	local data = spider:GetData()
	data.is_golden = true
	sprite.Color = golden_spider_color
end

local function hold_golden_spider(spider)
	local data = spider:GetData()
	consistance_holder.try_hold_over_entity(spider,item.own_key)
	data._Data[item.own_key].is_golden = true
	consistance_holder.try_hold_entity(spider,item.own_key,{consistance = true,})
end

local function restore_golden_spider(spider)
	local data = spider:GetData()
	if data.is_golden == true then return true end
	if consistance_holder.try_check_entity(spider,item.own_key) then
		local info = data._Data and data._Data[item.own_key]
		if info and info.is_golden == true then
			set_golden_spider(spider)
			return true
		end
	end
	return false
end

local function remove_golden_spider_record(spider)
	local data = spider:GetData()
	data.is_golden = false
	if data._Data and data._Data[item.own_key] then
		data._Data[item.own_key].is_golden = false
	end
	consistance_holder.try_remove_entity(spider,item.own_key)
end

local function can_change(grid)
	local tp = grid:GetType()
	local coll = grid.CollisionClass
	if (tp == GridEntityType.GRID_ROCK or tp == GridEntityType.GRID_ROCKB or tp == GridEntityType.GRID_ROCKT or tp == GridEntityType.GRID_ROCK_ALT or tp == GridEntityType.GRID_ROCK_SPIKED or tp == GridEntityType.GRID_ROCK_ALT2) then
        if (coll == GridCollisionClass.COLLISION_SOLID or coll == GridCollisionClass.COLLISION_OBJECT) then
            return true;
        end
    end
    return false;
end

local function get_gold_rush_count()
	local cnt = 0
	local player = Game():GetPlayer(0)
	for playerNum = 1, Game():GetNumPlayers() do
		local to_player = Game():GetPlayer(playerNum - 1)
		if to_player:HasCollectible(item.entity) or to_player:GetEffects():GetCollectibleEffectNum(item.entity) > 0 then
			cnt = cnt + to_player:GetCollectibleNum(item.entity) + to_player:GetEffects():GetCollectibleEffectNum(item.entity)
			player = to_player
		end
	end
	return cnt,player
end

local function get_fools_gold_chance(generated,count_bonus)
	local info = item.fools_gold_chance
	local base = info.base + math.max(0,(count_bonus or 1) - 1) * info.extra
	return math.max(info.min,base * (info.decay ^ generated))
end

local function get_decay_state()
	save.elses[item.own_key.."fools_gold_decay"] = save.elses[item.own_key.."fools_gold_decay"] or {}
	return save.elses[item.own_key.."fools_gold_decay"]
end

local function reroll_reset_rooms(state,rng)
	local info = item.reset_rooms
	state.rooms_left = rng:RandomInt(info.max - info.min + 1) + info.min
end

local function prepare_decay_state(rng)
	local state = get_decay_state()
	if state.rooms_left == nil then
		state.generated = state.generated or 0
		reroll_reset_rooms(state,rng)
	elseif state.rooms_left <= 0 then
		state.generated = 0
		reroll_reset_rooms(state,rng)
	end
	return state
end

local function collect_changeable_grids(room)
	local ret = {}
	local size = room:GetGridSize()
	for i = 0,size - 1 do
		local gent = room:GetGridEntity(i)
		if gent then
			local s = gent:GetSprite()
			if s:IsPlaying("big") == false and can_change(gent) == true then
				table.insert(ret,#ret + 1,gent)
			end
		end
	end
	return ret
end

local function shuffle_grids(grids,rng)
	for i = #grids,2,-1 do
		local j = rng:RandomInt(i) + 1
		grids[i],grids[j] = grids[j],grids[i]
	end
end

local function update_rock_neighbors(room,grid_index)
	local width = room:GetGridWidth()
	local indexes = {grid_index,grid_index - width,grid_index + width,}
	if grid_index % width ~= 0 then
		table.insert(indexes,#indexes + 1,grid_index - 1)
	end
	if grid_index % width ~= width - 1 then
		table.insert(indexes,#indexes + 1,grid_index + 1)
	end
	for _,index in ipairs(indexes) do
		local grid = room:GetGridEntity(index)
		local rock = grid and grid:ToRock()
		if rock and rock.UpdateNeighbors then
			rock:UpdateNeighbors()
		end
	end
end

local function make_grid_fools_gold(room,gent,rng)
	local frame = rng:RandomInt(60)
	local grid_index = gent:GetGridIndex()
	gent:SetType(GridEntityType.GRID_ROCK_GOLD)
	gent:GetSprite():SetFrame("foolsgold",frame)
	update_rock_neighbors(room,grid_index)
end

local function try_make_fools_gold(room,rng,count_bonus,generated_offset)
	local grids = collect_changeable_grids(room)
	shuffle_grids(grids,rng)
	local generated = 0
	for _,gent in ipairs(grids) do
		if rng:RandomFloat() < get_fools_gold_chance((generated_offset or 0) + generated,count_bonus) then
			make_grid_fools_gold(room,gent,rng)
			generated = generated + 1
		end
	end
	return generated
end

local function make_golden_spider(player,pos)
	local spider = player:AddBlueSpider(pos)
	set_golden_spider(spider)
	hold_golden_spider(spider)
	return spider
end

local function throw_golden_spider(spider,dir,rng)
	local d = spider:GetData()
	d[item.own_key.."no_collision_frames"] = item.spider_no_collision_frames
	d[item.own_key.."entity_collision"] = spider.EntityCollisionClass
	d[item.own_key.."throw_height_speed"] = item.spider_throw.up_speed - rng:RandomFloat()
	d[item.own_key.."throw_gravity"] = item.spider_throw.gravity
	spider.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	spider.PositionOffset = Vector(0,item.spider_throw.start_offset)
	spider.Velocity = dir:Resized(item.spider_throw.speed + rng:RandomFloat() * 1.5)
end

local function spawn_golden_spiders(player,pos,rng,count_bonus)
	rng = auxi.rng_for_sake(rng)
	local count = 2 + rng:RandomInt(3) + math.max(0,(count_bonus or 1) - 1)
	local dirs = {Vector(1,0),Vector(-1,0),Vector(0,1),Vector(0,-1),}
	local offset = rng:RandomInt(4)
	for i = 1,count do
		local dir = dirs[((i + offset - 1) % #dirs) + 1]
		local spider = make_golden_spider(player,pos + dir * 4)
		throw_golden_spider(spider,dir,rng)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	if room:IsFirstVisit() then
		local player = auxi.have_player_has_collectible(item.entity)
		if player then
			local cnt = get_gold_rush_count()
			cnt = math.max(1,cnt or 1)
			local rng = player:GetCollectibleRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			local state = prepare_decay_state(rng)
			local generated = try_make_fools_gold(room,rng,cnt,state.generated or 0)
			state.generated = (state.generated or 0) + generated
			state.rooms_left = (state.rooms_left or 1) - 1
		end
	end
end,
})

if ModCallbacks.MC_POST_GRID_ROCK_DESTROY then
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GRID_ROCK_DESTROY, params = GridEntityType.GRID_ROCK_GOLD,
Function = function(_,rock,grid_type,immediate,source)
	local cnt,player = get_gold_rush_count()
	if cnt <= 0 or player == nil then return end
	local rng = rock:GetRNG()
	if source and source.Entity then
		player = auxi.check_spawner_player(source.Entity) or player
		rng = source.Entity:GetDropRNG() or rng
	end
	rng = auxi.rng_for_sake(rng)
	if rng:RandomInt(100) < 33 then
		spawn_golden_spiders(player,rock.Position,rng,cnt)
	end
end,
})
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar.Variant,
Function = function(_,ent)
	if ent.Variant ~= item.familiar.Variant then return end
	restore_golden_spider(ent)
	local d = ent:GetData()
	local key = item.own_key.."no_collision_frames"
	if (d[key] or 0) > 0 then
		d[key] = d[key] - 1
		if d[key] <= 0 then
			if d[item.own_key.."entity_collision"] then ent.EntityCollisionClass = d[item.own_key.."entity_collision"] end
			d[item.own_key.."entity_collision"] = nil
		end
	end
	if d[item.own_key.."throw_height_speed"] then
		local height_speed = d[item.own_key.."throw_height_speed"]
		ent.PositionOffset = Vector(ent.PositionOffset.X,math.min(0,ent.PositionOffset.Y + height_speed))
		d[item.own_key.."throw_height_speed"] = height_speed + (d[item.own_key.."throw_gravity"] or item.spider_throw.gravity)
		ent.Velocity = ent.Velocity * 0.93
		if ent.PositionOffset.Y >= 0 and d[item.own_key.."throw_height_speed"] > 0 then
			ent.PositionOffset = Vector(ent.PositionOffset.X,0)
			d[item.own_key.."throw_height_speed"] = nil
			d[item.own_key.."throw_gravity"] = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar.Variant,
Function = function(_,ent)
	if ent.Variant ~= item.familiar.Variant then return end
	restore_golden_spider(ent)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = item.familiar.Variant,
Function = function(_,ent, col, low)
	if ent.Variant == item.familiar.Variant then
		local d = ent:GetData()
		if d.is_golden and d.is_golden == true then
			if (d[item.own_key.."no_collision_frames"] or 0) > 0 then return {Collide = false,SkipCollisionEffects = true,} end
			if col:IsVulnerableEnemy() and col:IsActiveEnemy() and (not col:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and col:CanShutDoors() == true then
				col:AddMidasFreeze(EntityRef(ent),150)
				remove_golden_spider_record(ent)
			end
		end
	end
end,
})
--l local player = Game():GetPlayer(0);local spider = player:AddBlueSpider(player.Position);local s = spider:GetSprite();spider:SetColor(Color(1,1,1,1,1,1,0),-1,99,false,false);

return item

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Tzolkin,
	own_key = "Item_Tzolkin_",
	button_list = {4,5,6,7,9,11},
	dir_time_limit = 20,
	start_pos = Vector(0,-36),
	mov_pos = Vector(28,0),
	mov_pos2 = Vector(0,28),
	-- Tint 近白 + Colorize 血红（临时道具 / 三选一底座）
	hud_tint = Color(1,1,1,0.62,0,0,0,2.65,0.65,0.5,1),
	option_key = "tzolkin_option",
	quality_anm2 = "gfx/ui/EID/eid_quality.anm2",
	-- 品质图标相对道具格子中心的偏移（贴图 pivot 在左上）
	quality_icon_offset = Vector(6,6),
}

-- Quality 动画：0-4 = 品质 0-4；5 = 负品质（含 -1）；6 = 5 及以上
local function quality_to_frame(quality)
	local q = tonumber(quality)
	if q == nil then return 5 end
	if q >= 0 and q <= 4 then return math.floor(q) end
	if q < 0 then return 5 end
	return 6
end

local quality_sprite
local function get_quality_sprite()
	if quality_sprite then return quality_sprite end
	quality_sprite = Sprite()
	quality_sprite:Load(item.quality_anm2,true)
	quality_sprite:Play("Quality",true)
	return quality_sprite
end

local function render_quality_icon(pos,quality)
	local s = get_quality_sprite()
	s:SetFrame("Quality",quality_to_frame(quality))
	s:Render(pos + item.quality_icon_offset,Vector.Zero,Vector.Zero)
end

local assoc_key = item.own_key.."assoc"
local pending_key = item.own_key.."pending_restore"
local pool_force_key = item.own_key.."pool_force"
local pending_options_key = item.own_key.."pending_options"

local function copy_counts(src)
	local out = {}
	if not src then return out end
	for id,count in pairs(src) do
		local cid = tonumber(id)
		local n = tonumber(count) or 0
		if cid and cid > 0 and n > 0 then out[cid] = n end
	end
	return out
end

local function get_assoc(idx,create)
	save.elses[assoc_key] = save.elses[assoc_key] or {}
	if create then
		save.elses[assoc_key][idx] = save.elses[assoc_key][idx] or {}
	end
	return save.elses[assoc_key][idx]
end

local function add_assoc(idx,collectible,amount)
	amount = amount or 1
	local bag = get_assoc(idx,true)
	bag[collectible] = (bag[collectible] or 0) + amount
end

local function refresh_imitate(player)
	Imitate_item_holder.Evaluate_Imitate_Items(player)
end

function item.get_hud_draw_color(alpha_mul)
	local t = auxi.color2table(item.hud_tint)
	t.A = (alpha_mul or 1) * (t.A or 0.62)
	return auxi.table2color(t)
end

local function apply_option_tint(pickup)
	if not pickup then return end
	local s = pickup:GetSprite()
	s.Color = item.get_hud_draw_color(1)
end

local function mark_option_pickup(pickup,owner_idx,options_index)
	local d = pickup:GetData()
	d._Data = d._Data or {}
	d._Data[item.own_key] = {
		option = true,
		owner_idx = owner_idx,
		options_index = options_index,
	}
	d[item.option_key] = true
	apply_option_tint(pickup)
	consistance_holder.try_hold_entity(pickup,item.own_key,{keep_level = true,})
end

local function is_option_pickup(pickup)
	if not pickup then return false end
	local d = pickup:GetData()
	if d[item.option_key] then return true end
	if consistance_holder.try_check_entity(pickup,item.own_key) then
		local info = d._Data and d._Data[item.own_key]
		if info and info.option then
			d[item.option_key] = true
			return true
		end
	end
	return false
end

local function clear_option_group(options_index,except)
	local room = Game():GetRoom()
	for _,ent in ipairs(Isaac.FindByType(5,100,-1,false,false)) do
		local pickup = ent:ToPickup()
		if pickup and pickup ~= except and is_option_pickup(pickup)
			and pickup.OptionsPickupIndex == options_index then
			consistance_holder.try_remove_entity(pickup,item.own_key)
			pickup:Remove()
		end
	end
end

local function collect_quality_pool(quality,exclude)
	exclude = exclude or {}
	local pool = {}
	local config = Isaac.GetItemConfig()
	local sz = config:GetCollectibles().Size
	for id = 1,sz do
		if not exclude[id] and id ~= item.entity then
			local col = config:GetCollectible(id)
			if col and not col.Hidden
				and (col.Tags & ItemConfig.TAG_QUEST) ~= ItemConfig.TAG_QUEST
				and col.Quality == quality
				and (col.Type == ItemType.ITEM_PASSIVE or col.Type == ItemType.ITEM_FAMILIAR) then
				pool[#pool + 1] = id
			end
		end
	end
	return pool
end

-- 从指定品质池抽满 count；不足时向相邻品质扩张（±1、±2…），再扫常见品质表
local function pick_quality_ids(quality,count,rng,exclude)
	quality = tonumber(quality) or 0
	local out = {}
	local taken = {}
	for id,_ in pairs(exclude or {}) do
		local cid = tonumber(id)
		if cid then taken[cid] = true end
	end

	local function take_from_pool(pool)
		while #out < count and #pool > 0 do
			local idx = rng:RandomInt(#pool) + 1
			local id = pool[idx]
			out[#out + 1] = id
			taken[id] = true
			table.remove(pool,idx)
		end
	end

	local tried = {}
	local function try_quality(q)
		q = tonumber(q)
		if q == nil or tried[q] then return end
		tried[q] = true
		local pool = {}
		for _,id in ipairs(collect_quality_pool(q,taken)) do
			if not taken[id] then pool[#pool + 1] = id end
		end
		take_from_pool(pool)
	end

	try_quality(quality)
	for delta = 1,8 do
		if #out >= count then break end
		try_quality(quality + delta)
		if #out >= count then break end
		try_quality(quality - delta)
	end
	-- 仍不足时扫常见/扩展品质（含模组 -1 / 5）
	for _,q in ipairs({0,1,2,3,4,-1,5,6,-2,7}) do
		if #out >= count then break end
		try_quality(q)
	end
	return out
end

-- 找 count 个横向相邻（间隔 1 格=40）的可生成空地，优先靠近 prefer_pos
local function is_option_spawn_tile(room,pos,reserved)
	if not room:IsPositionInRoom(pos,0) then return false end
	local gi = room:GetGridIndex(pos)
	if gi < 0 then return false end
	if reserved and reserved[gi] then return false end
	if room:GetGridCollision(gi) ~= GridCollisionClass.COLLISION_NONE then return false end
	for _,ent in ipairs(Isaac.FindByType(5,100,-1,false,false)) do
		if ent.Position:Distance(pos) < 24 then return false end
	end
	return true
end

local function find_horizontal_option_positions(room,count,prefer_pos)
	count = count or 3
	local step = 40
	local best,best_score = nil,math.huge
	local width = room:GetGridWidth()
	local height = room:GetGridHeight()
	for y = 0,height - 1 do
		for x = 0,width - count do
			local positions = {}
			local ok = true
			for i = 0,count - 1 do
				local pos = room:GetGridPosition(x + i + y * width)
				if not is_option_spawn_tile(room,pos,nil) then
					ok = false
					break
				end
				positions[#positions + 1] = pos
			end
			if ok then
				local mid = positions[math.ceil(count / 2)]
				local score = mid:DistanceSquared(prefer_pos)
				if score < best_score then
					best_score = score
					best = positions
				end
			end
		end
	end
	if best then return best end
	-- 回退：以空地为中心向两侧找，再不行才逐个 FindFree
	local positions = {}
	local base = room:FindFreePickupSpawnPosition(prefer_pos,40,true)
	local center = room:GetGridPosition(room:GetGridIndex(base))
	for i = 0,count - 1 do
		local target = center + Vector(step * (i - (count - 1) / 2),0)
		positions[#positions + 1] = room:FindFreePickupSpawnPosition(target,0,true)
	end
	return positions
end

local function spawn_option_choices(player,quality,exclude)
	local idx = player:GetData().__Index
	local rng = player:GetCollectibleRNG(item.entity)
	local ids = pick_quality_ids(quality,3,rng,exclude)
	if #ids == 0 then return false end
	local ndx = option_index_holder.find_a_new_index()
	local room = Game():GetRoom()
	local positions = find_horizontal_option_positions(room,#ids,player.Position)
	for i,colid in ipairs(ids) do
		local pos = positions[i] or room:FindFreePickupSpawnPosition(player.Position,10,true)
		local q = Isaac.Spawn(5,100,colid,pos,Vector(0,0),player):ToPickup()
		q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
		q.OptionsPickupIndex = ndx
		mark_option_pickup(q,idx,ndx)
	end
	save.elses[pending_options_key] = save.elses[pending_options_key] or {}
	save.elses[pending_options_key][idx] = {
		ids = ids,
		quality = quality,
		options_index = ndx,
	}
	return true
end

local function get_column(player,number)
	local ret = math.max(3,math.ceil(math.sqrt(number)))
	local delpos = Isaac.WorldToScreen(player.Position) + item.start_pos - item.mov_pos2 * 0.5
	local mxn = math.max(1,math.ceil(delpos.Y / 32))
	ret = math.max(math.ceil(number / mxn),ret)
	return ret
end

local function makeitemlist(player)
	local d = player:GetData()
	d[item.own_key.."list"] = {}
	local config = Isaac.GetItemConfig()
	local sz = config:GetCollectibles().Size
	for i = 1,sz do
		local col = config:GetCollectible(i)
		if col and not col.Hidden
			and (col.Tags & ItemConfig.TAG_QUEST) ~= ItemConfig.TAG_QUEST
			and i ~= item.entity
			and (col.Type == ItemType.ITEM_PASSIVE or col.Type == ItemType.ITEM_FAMILIAR) then
			local num = player:GetCollectibleNum(i,true)
			if num > 0 then
				if i == enums.Items.It_s_a_trick then
					col = config:GetCollectible(save.elses.glazed_trick or 32) or config:GetCollectible(32)
				end
				if col then
					for _ = 1,num do
						d[item.own_key.."list"][#d[item.own_key.."list"] + 1] = {
							id = i,
							spritename = col.GfxFileName,
							quality = col.Quality or 0,
						}
					end
				end
			end
		end
	end
end

local function render_selector(player)
	local d = player:GetData()
	if d[item.own_key.."list"] == nil then makeitemlist(player) end
	local list = d[item.own_key.."list"]
	local sl = d[item.own_key.."select"] or 0
	local column = get_column(player,#list + 1)
	local mxn = math.ceil((#list + 1) / column) * column
	local spos = Isaac.WorldToScreen(player.Position) + item.start_pos
		- item.mov_pos * ((column - 1) / 2)
		- item.mov_pos2 * (mxn / column)
	for ii = 1,mxn do
		local info = list[ii] or {id = 0,spritename = "gfx/ui/math/exclude_mark.png"}
		if info.spritename then
			local s = Sprite()
			s:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true)
			s:Play("Idle",true)
			s:ReplaceSpritesheet(0,info.spritename)
			s:LoadGraphics()
			local iii = ii - 1
			local i = iii % column
			local j = math.floor(iii / column)
			local tpos = spos + item.mov_pos * i + item.mov_pos2 * j
			s:Render(tpos,Vector(0,0),Vector(0,0))
			-- 框选在道具之上、品质角标之下，避免遮住角标
			if iii == sl then
				local s2 = Sprite()
				s2:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true)
				s2:Play("Idle",true)
				s2:ReplaceSpritesheet(0,"gfx/ui/math/catch_mark.png")
				s2:LoadGraphics()
				s2:Render(tpos,Vector(0,0),Vector(0,0))
			end
			if info.id and info.id > 0 then
				render_quality_icon(tpos,info.quality)
			end
		end
	end
end

local function move(player,dir)
	local d = player:GetData()
	if d[item.own_key.."list"] == nil then makeitemlist(player) end
	local column = get_column(player,#d[item.own_key.."list"] + 1)
	local raw = math.ceil((#d[item.own_key.."list"] + 1) / column)
	local sl = d[item.own_key.."select"] or 0
	local i = sl % column
	local j = math.floor(sl / column)
	if dir == 5 then i = (i + 1) % column
	elseif dir == 4 then i = (i + column - 1) % column
	elseif dir == 7 then j = (j + 1) % raw
	elseif dir == 6 then j = (j + raw - 1) % raw
	end
	d[item.own_key.."select"] = i + j * column
	makeitemlist(player)
	return 0
end

local function close_selector(player,discharge)
	local d = player:GetData()
	d[item.own_key.."effect"] = nil
	d[item.own_key.."lift"] = nil
	selection_holder.remove_select(player,item.own_key)
	if player:IsHoldingItem() then
		player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
	end
	if discharge then
		local slot = auxi.check_slot_with_item(player,item.entity,true)
		if slot ~= nil and slot >= 0 then
			player:DischargeActiveItem(slot)
		end
	end
end

local function confirm_selection(player)
	local d = player:GetData()
	local idx = d.__Index
	if not idx then return false end
	if d[item.own_key.."list"] == nil then makeitemlist(player) end
	local info = d[item.own_key.."list"][(d[item.own_key.."select"] or 0) + 1]
	if not info or not info.id or info.id <= 0 then
		sound_tracker.PlayStackedSound(187,1,1,false,0,2)
		return false
	end
	local colid = info.id
	if player:GetCollectibleNum(colid,true) <= 0 then
		sound_tracker.PlayStackedSound(187,1,1,false,0,2)
		makeitemlist(player)
		return false
	end
	local cfg = Isaac.GetItemConfig():GetCollectible(colid)
	local quality = (cfg and cfg.Quality) or 0
	player:RemoveCollectible(colid)
	add_assoc(idx,colid,1)
	refresh_imitate(player)
	spawn_option_choices(player,quality,{[colid] = true})
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_BLAST,0.85,1.2,false,0,2)
	auxi.spawn_item_dust(player,player.Position,colid,item.hud_tint,nil,true)
	close_selector(player,true)
	return true
end

local function strip_assoc_temps(player,idx)
	local bag = get_assoc(idx,false)
	if not bag then return end
	-- 清空申报表后 Evaluate 会去掉 imitate
	save.elses[assoc_key][idx] = {}
	refresh_imitate(player)
end

local function restore_assoc_from_pending(player,idx)
	save.elses[pending_key] = save.elses[pending_key] or {}
	local pending = save.elses[pending_key][idx]
	if not pending then return end
	save.elses[assoc_key] = save.elses[assoc_key] or {}
	save.elses[assoc_key][idx] = copy_counts(pending)
	save.elses[pending_key][idx] = nil
	refresh_imitate(player)
end

local function on_hit_lose(player)
	local idx = player:GetData().__Index
	if not idx then return end
	local bag = copy_counts(get_assoc(idx,false))
	save.elses[pending_key] = save.elses[pending_key] or {}
	save.elses[pending_key][idx] = bag
	strip_assoc_temps(player,idx)
	-- 清未结算三选一
	save.elses[pending_options_key] = save.elses[pending_options_key] or {}
	local pending_opt = save.elses[pending_options_key][idx]
	if pending_opt and pending_opt.options_index then
		clear_option_group(pending_opt.options_index)
	end
	save.elses[pending_options_key][idx] = nil
	if auxi.has_have_coll(player,item.entity) then
		player:RemoveCollectible(item.entity)
	end
	save.elses[pool_force_key] = true
	auxi.spawn_item_dust(player,player.Position,item.entity,nil,nil,true)
	player:AnimateSad()
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if not continue then
		save.elses[assoc_key] = {}
		save.elses[pending_key] = {}
		save.elses[pool_force_key] = nil
		save.elses[pending_options_key] = {}
		save.elses.Tzolikn_respawn = nil
		save.elses[item.own_key.."buff"] = nil
	end
	save.elses[assoc_key] = save.elses[assoc_key] or {}
	save.elses[pending_key] = save.elses[pending_key] or {}
	save.elses[pending_options_key] = save.elses[pending_options_key] or {}
	save.elses[item.own_key.."last_open_dir"] = {}
	save.elses[item.own_key.."last_open_dir_counter"] = {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	local idx = player:GetData().__Index
	if not idx then return end
	local bag = get_assoc(idx,false)
	if not bag then return end
	for id,count in pairs(bag) do
		local cid = tonumber(id)
		local n = tonumber(count) or 0
		if cid and n > 0 then value[cid] = (value[cid] or 0) + n end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,flags,slot,vardata)
	if flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then return end
	local d = player:GetData()
	if d[item.own_key.."effect"] then
		close_selector(player,false)
		return {Discharge = false}
	end
	d[item.own_key.."effect"] = true
	d[item.own_key.."lift"] = true
	d[item.own_key.."select"] = 0
	-- 打开时预置 last_open_dir=射击键，避免举起瞬间仍按着射击被当成确认
	save.elses[item.own_key.."last_open_dir"] = save.elses[item.own_key.."last_open_dir"] or {}
	save.elses[item.own_key.."last_open_dir_counter"] = save.elses[item.own_key.."last_open_dir_counter"] or {}
	save.elses[item.own_key.."last_open_dir"][player.ControllerIndex] = 9
	save.elses[item.own_key.."last_open_dir_counter"][player.ControllerIndex] = 0
	makeitemlist(player)
	return {Discharge = false,ShowAnim = false}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if not ent then return end
	local player = ent:ToPlayer()
	if not player then return end
	if player:GetData()[item.own_key.."effect"] and selection_holder.check_select(player,item.own_key) then
		for _,i in ipairs(item.button_list) do
			if button == i and (hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED) then
				return false
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local ctrlid = player.ControllerIndex
	if d[item.own_key.."lift"] and player:IsExtraAnimationFinished() then
		player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
		selection_holder.check_and_try_select(player,item.own_key)
		d[item.own_key.."lift"] = nil
		makeitemlist(player)
		d[item.own_key.."select"] = 0
		-- 举起完成时再钉一次，防止 lift 期间 last_open_dir 被清掉
		save.elses[item.own_key.."last_open_dir"][ctrlid] = 9
		save.elses[item.own_key.."last_open_dir_counter"][ctrlid] = 0
	end
	if not d[item.own_key.."effect"] or d[item.own_key.."lift"] then return end
	if not player:IsHoldingItem() then
		d[item.own_key.."effect"] = false
		selection_holder.remove_select(player,item.own_key)
		return
	end
	if not selection_holder.check_select(player,item.own_key) or Game():IsPaused() then return end
	local dir = nil
	for _,i in ipairs(item.button_list) do
		if Input.IsActionTriggered(i,ctrlid) or Input.IsActionPressed(i,ctrlid) then
			dir = i
		end
	end
	local should_count = false
	save.elses[item.own_key.."last_open_dir"] = save.elses[item.own_key.."last_open_dir"] or {}
	save.elses[item.own_key.."last_open_dir_counter"] = save.elses[item.own_key.."last_open_dir_counter"] or {}
	local last = save.elses[item.own_key.."last_open_dir"][ctrlid]
	local counter = save.elses[item.own_key.."last_open_dir_counter"]
	counter[ctrlid] = counter[ctrlid] or 0
	if dir then
		if dir == 11 then
			close_selector(player,false)
			return
		end
		-- 与 Alchemy 相同：同键需超过 dir_time_limit 才连发；换键立刻生效
		if dir == last then
			counter[ctrlid] = counter[ctrlid] + 1
			if counter[ctrlid] > item.dir_time_limit and counter[ctrlid] % 8 == 1 then
				should_count = true
			end
		else
			counter[ctrlid] = 0
			should_count = true
		end
	end
	save.elses[item.own_key.."last_open_dir"][ctrlid] = dir
	if not should_count then return end
	if dir == 9 then
		confirm_selection(player)
		return
	end
	move(player,dir)
	if dir == 5 or dir == 6 then
		sound_tracker.PlayStackedSound(195,1,1,false,0,2)
	elseif dir == 4 or dir == 7 then
		sound_tracker.PlayStackedSound(194,1,1,false,0,2)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local d = player:GetData()
	if d[item.own_key.."effect"] and player:IsHoldingItem() and selection_holder.check_select(player,item.own_key) then
		render_selector(player)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_COLLECTIBLE,
Function = function(_,pickup)
	if consistance_holder.try_check_entity(pickup,item.own_key) then
		local info = pickup:GetData()._Data and pickup:GetData()._Data[item.own_key]
		if info and info.option then
			pickup:GetData()[item.option_key] = true
			apply_option_tint(pickup)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = PickupVariant.PICKUP_COLLECTIBLE,
Function = function(_,pickup)
	if is_option_pickup(pickup) then apply_option_tint(pickup) end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = PickupVariant.PICKUP_COLLECTIBLE,priority = -140,
Function = function(_,pickup,collider)
	local player = collider:ToPlayer()
	if not player or not is_option_pickup(pickup) then return end
	if not auxi.will_pick_up(player,pickup) then return end
	local idx = player:GetData().__Index
	local info = pickup:GetData()._Data and pickup:GetData()._Data[item.own_key]
	if not info or info.owner_idx ~= idx then return end
	local colid = pickup.SubType
	local options_index = pickup.OptionsPickupIndex
	add_assoc(idx,colid,1)
	refresh_imitate(player)
	clear_option_group(options_index,pickup)
	consistance_holder.try_remove_entity(pickup,item.own_key)
	pickup:Remove()
	save.elses[pending_options_key] = save.elses[pending_options_key] or {}
	save.elses[pending_options_key][idx] = nil
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2)
	player:AnimateCollectible(colid,"Pickup","PlayerPickupSparkle")
	auxi.spawn_item_dust(player,player.Position,colid,item.hud_tint,nil,true)
	return false
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if not player then return end
	if not auxi.has_have_coll(player,item.entity) then return end
	if amt <= 0 or not auxi.is_damage_from_enemy(ent,amt,flag,source,cooldown) then return end
	on_hit_lose(player)
	player:SetMinDamageCooldown(math.max(cooldown or 0,30))
	return false
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil,
Function = function(_,pool,decrease,seed)
	if save.elses[pool_force_key] and Game():GetFrameCount() > 5 then
		return item.entity
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,touched)
	local idx = player:GetData().__Index
	if save.elses[pool_force_key] then save.elses[pool_force_key] = nil end
	save.elses.Tzolikn_respawn = nil
	if idx then restore_assoc_from_pending(player,idx) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for i = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player then refresh_imitate(player) end
	end
	-- 未结算三选一：若底座丢失则按存档重刷
	save.elses[pending_options_key] = save.elses[pending_options_key] or {}
	for idx,pending in pairs(save.elses[pending_options_key]) do
		if pending and pending.ids and #pending.ids > 0 then
			local found = 0
			for _,ent in ipairs(Isaac.FindByType(5,100,-1,false,false)) do
				local pickup = ent:ToPickup()
				if pickup and is_option_pickup(pickup) then found = found + 1 end
			end
			if found == 0 then
				local player = nil
				for p = 0,Game():GetNumPlayers() - 1 do
					local pl = Game():GetPlayer(p)
					if pl and pl:GetData().__Index == idx then player = pl break end
				end
				if player and auxi.has_have_coll(player,item.entity) then
					local ndx = option_index_holder.find_a_new_index()
					local room = Game():GetRoom()
					local positions = find_horizontal_option_positions(room,#pending.ids,player.Position)
					for i,colid in ipairs(pending.ids) do
						local pos = positions[i] or room:FindFreePickupSpawnPosition(player.Position,10,true)
						local q = Isaac.Spawn(5,100,colid,pos,Vector(0,0),player):ToPickup()
						q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
						q.OptionsPickupIndex = ndx
						mark_option_pickup(q,idx,ndx)
					end
					pending.options_index = ndx
				end
			end
		end
	end
end,
})

do
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	temp_hud.register_provider(function(player)
		local idx = player:GetData().__Index
		if not idx then return end
		return copy_counts(get_assoc(idx,false))
	end,{
		color = item.hud_tint,
		exclusive = true,
		source_item = item.entity,
	})
	-- 三选一底座尚未入手时也标「临时道具」
	temp_hud.register_temp_entity_checker(function(entity)
		local pickup = entity and entity:ToPickup()
		return pickup ~= nil and is_option_pickup(pickup)
	end)
end

return item

local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")

local item = {
	ToCall = {},
	post_ToCall = {},
	id_counter = 10000,
	pos_ = {
		Vector(-8,-35),
		Vector(-16,-24),
		Vector(-18,-11),
	},
	else_pos_ext = Vector(-12,-3),
	to_render = {},
	add_to_render = {},
	definitions = {},
	families = {},
}

-- Definitions are module-level; instances remain on the native entity's GetData().
local function validate_owner(owner)
	assert(type(owner) == "table", "charge bar owner must be a table")
	local kind = owner.type
	if kind == "collectible" then
		assert(type(owner.collectible) == "number", "collectible charge bar requires collectible ID")
	elseif kind == "player_type" then
		assert(type(owner.player_type) == "number", "player_type charge bar requires player type ID")
	elseif kind == "challenge" then
		assert(type(owner.challenge) == "number", "challenge charge bar requires challenge ID")
	elseif kind == "custom" then
		assert(type(owner.valid) == "function", "custom charge bar requires valid(ent)")
	else
		assert(kind == "entity", "unknown charge bar owner type: " .. tostring(kind))
	end
end

function item.register_bar(def)
	assert(type(def) == "table" and type(def.id) == "string" and def.id ~= "")
	validate_owner(def.owner)
	if def.entity_owner then validate_owner(def.entity_owner) end
	assert(item.definitions[def.id] == nil, "duplicate charge bar: " .. def.id)
	for _, family in ipairs(item.families) do
		assert(def.id:sub(1, #family.prefix) ~= family.prefix, "charge bar ID overlaps family: " .. def.id)
	end
	item.definitions[def.id] = def
end

function item.register_family(def)
	assert(type(def) == "table" and type(def.prefix) == "string" and def.prefix ~= "")
	validate_owner(def.owner)
	for _, family in ipairs(item.families) do
		assert(def.prefix:sub(1, #family.prefix) ~= family.prefix
			and family.prefix:sub(1, #def.prefix) ~= def.prefix, "overlapping charge bar family: " .. def.prefix)
	end
	for id in pairs(item.definitions) do
		assert(id:sub(1, #def.prefix) ~= def.prefix, "charge bar family overlaps ID: " .. id)
	end
	item.families[#item.families + 1] = def
end

local function definition_for(id)
	if item.definitions[id] then return item.definitions[id] end
	for _, def in ipairs(item.families) do
		if id:sub(1, #def.prefix) == def.prefix then return def end
	end
end

local function clear_visual(d, id)
	local instances = d.charge_bar_holder_instances
	local instance = instances and instances[id]
	if not instance then return end
	d[instance.sprite_key] = nil
	d[instance.sprite_key .. "_Clock"] = nil
	instances[id] = nil
end

function item.get_sprite(ent, id)
	local d = ent:GetData()
	local instance = (d.charge_bar_holder_instances or {})[id .. "_C_B"]
	return instance and instance.sprite or nil
end

local function owner_for(def, ent)
	if not ent:ToPlayer() and def.entity_owner then return def.entity_owner end
	return def.owner
end

local function owner_valid(def, ent)
	local owner = owner_for(def, ent)
	if owner.type == "collectible" then
		local player = ent:ToPlayer()
		return player and player:GetCollectibleNum(owner.collectible) > 0
	elseif owner.type == "player_type" then
		local player = ent:ToPlayer()
		return player and player:GetPlayerType() == owner.player_type
	elseif owner.type == "challenge" then
		return Game().Challenge == owner.challenge
	elseif owner.type == "custom" then
		return owner.valid(ent)
	end
	-- Entity-owned bars disappear with their native entity.
	assert(owner.type == "entity", "unvalidated charge bar owner")
	return true
end

local function cleanup_invalid_bars(_, ent)
	local d = ent:GetData()
	local instances = d.charge_bar_holder_instances
	if not instances then return end
	local expired = {}
	for id in pairs(instances) do
		local def = definition_for(id:sub(1, -5))
		if def and not owner_valid(def, ent) then expired[#expired + 1] = id end
	end
	for _, id in ipairs(expired) do item.remove_charge_bar(ent, id, true) end
end

item.ToCall[#item.ToCall + 1] = {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	Function = cleanup_invalid_bars,
}
item.ToCall[#item.ToCall + 1] = {
	CallBack = ModCallbacks.MC_POST_FAMILIAR_UPDATE,
	Function = cleanup_invalid_bars,
}

function item.try_get_charge_bar_pos(ent,id,acco_t_p)
	if ent == nil then return -1 end
	if id == nil then return -1 end
	local d = ent:GetData()
	if d.charge_bar_holder_i_list == nil then d.charge_bar_holder_i_list = {} end
	if d.charge_bar_holder_i_list[id] == nil then item.allocate_charge_bar_pos(ent,id) end
	for i = 1,#d.charge_bar_holder_list do
		if d.charge_bar_holder_list[i].id == id then
			local li = math.floor((i-1)/(#item.pos_))
			local ri = (i - 1) % (#item.pos_) + 1
			local ret = item.pos_[ri] + item.else_pos_ext * li
			if acco_t_p then
				ret = (ret - item.pos_[1]) + auxi.mul_t(item.pos_[1],auxi.ProtectVector(ent.SpriteScale))
			end
			return ret
		end
	end
	return -1
end

function item.get_charge_bar_pos(ent,id)
	if ent == nil then return -1 end
	if id == nil then return -1 end
	local d = ent:GetData()
	if d.charge_bar_holder_i_list == nil then d.charge_bar_holder_i_list = {} end
	if d.charge_bar_holder_i_list[id] == nil then return -1 end
	if d.charge_bar_holder_list == nil then d.charge_bar_holder_list = {} end
	for i = 1,#d.charge_bar_holder_list do
		if d.charge_bar_holder_list[i].id == id then
			local li = math.floor((i - 1) / #item.pos_)
			local ri = (i - 1) % #item.pos_ + 1
			return item.pos_[ri] + item.else_pos_ext * li
		end
	end
end

function item.remove_charge_bar(ent,id,skip)
	if ent == nil then return -1 end
	if id == nil then return -1 end
	if not skip then id = id .. "_C_B" end
	local d = ent:GetData()
	clear_visual(d, id)
	if d.charge_bar_holder_i_list == nil then d.charge_bar_holder_i_list = {} end
	if d.charge_bar_holder_i_list[id] == nil then return -1 end
	if d.charge_bar_holder_list == nil then d.charge_bar_holder_list = {} end
	for i = 1,#d.charge_bar_holder_list do
		if d.charge_bar_holder_list[i].id == id then
			d.charge_bar_holder_i_list[id] = nil
			table.remove(d.charge_bar_holder_list,i)
			break
		end
	end
	return 1
end

function item.allocate_charge_bar_pos(ent,id)
	if ent == nil then return -1 end
	if id == nil then return -1 end
	local d = ent:GetData()
	if d.charge_bar_holder_list == nil then d.charge_bar_holder_list = {} end
	if d.charge_bar_holder_i_list == nil then d.charge_bar_holder_i_list = {} end
	if d.charge_bar_holder_i_list[id] == nil then 
		local tab = {id = id,}
		table.insert(d.charge_bar_holder_list,#d.charge_bar_holder_list+1,tab)
		d.charge_bar_holder_i_list[id] = tab
	end
end

local function preview_charge_bar_pos(ent)
	local d = ent:GetData()
	local next_index = #(d.charge_bar_holder_list or {})
	local li = math.floor(next_index / #item.pos_)
	local ri = next_index % #item.pos_ + 1
	local pos = item.pos_[ri] + item.else_pos_ext * li
	return (pos - item.pos_[1]) + auxi.mul_t(item.pos_[1], auxi.ProtectVector(ent.SpriteScale))
end

function item.render_me(ent,params)
	local room = Game():GetRoom()
	local d = ent:GetData()
	local name1 = (params.name1 or "") .. "_Charge_Bar_buff"
	local name2 = (params.name2 or params.name1 or "") .. "_Charge_Bar"
	local name3 = (params.name3 or params.name2 or params.name1 or "") .. "_C_B"
	local def = definition_for(params.name3 or params.name2 or params.name1 or "")
	if def and not owner_valid(def, ent) then
		item.remove_charge_bar(ent, name3, true)
		return {pos = Vector(0, 0)}
	end
	local check1 = params.check1 or (function(val) return val > 5 end)
	local check2 = params.check2 or (function(val) return val >= 300 end)
	local check3 = params.check3 or (function(val) return math.ceil(val/3) end)
	local signal1 = params.signal1 or (function() end)
	local loadname = params.loadname or "gfx/effects/chargebar/chargebar_Qing.anm2"
	d[name1] = d[name1] or 0
	local active = check1(d[name1], ent)
	local instance = d.charge_bar_holder_instances and d.charge_bar_holder_instances[name3]
	if not active and not instance then
		return {pos = params.offset or preview_charge_bar_pos(ent)}
	end
	if not instance then
		instance = {sprite_key = name2}
		d.charge_bar_holder_instances = d.charge_bar_holder_instances or {}
		d.charge_bar_holder_instances[name3] = instance
	end
	instance.last_render_frame = Game():GetFrameCount()
	instance.offset = params.offset
	local init_pos = ent.Position
	if ent:ToPlayer() and params.NoOffset ~= true then init_pos = init_pos + player_offset_holder.GetPlayerOffset(ent:ToPlayer()) if ent:ToPlayer().CanFly then init_pos = init_pos + Vector(0,-6) end end
	init_pos = params.position or init_pos
	local pos = params.offset or item.try_get_charge_bar_pos(ent,name3,true)
	local posoffset = room:WorldToScreenPosition(init_pos) + pos - Game().ScreenShakeOffset
	if (Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT) then
		posoffset = auxi.GetWaterRenderOffset() + room:WorldToScreenPosition(init_pos) + Vector(pos.X,-pos.Y) - Game().ScreenShakeOffset
	end
	
	if active then
		if instance.sprite == nil then
			instance.sprite = Sprite()
			instance.sprite:Load(loadname,true)
			instance.sprite:Play("Charging",true)
		end
		if check2(d[name1],ent) then
			if instance.sprite:IsPlaying("Charging") or instance.sprite:IsFinished("Charging") then
				instance.sprite:Play("StartCharged",true)
				signal1(ent)
			elseif instance.sprite:IsFinished("StartCharged") or instance.sprite:IsPlaying("Disappear") or instance.sprite:IsFinished("Disappear") then
				instance.sprite:Play("Charged",true)
			end
			instance.clock = instance.clock or Game():GetFrameCount()
			if instance.clock ~= Game():GetFrameCount() then instance.sprite:Update() instance.clock = Game():GetFrameCount() end
		else
			local frame = math.max(0, math.floor(tonumber(check3(d[name1],ent)) or 0))
			instance.sprite:SetFrame("Charging",frame)
		end
		instance.sprite.Color = params.color or Color.Default
		instance.sprite:Render(posoffset,Vector(0,0),Vector(0,0))
	else
		if instance.sprite == nil then
			instance.sprite = Sprite()
			instance.sprite:Load(loadname,true)
			instance.sprite:SetFrame("Disappear",8)
		end
		if instance.sprite:IsPlaying("Disappear") == false and instance.sprite:IsFinished("Disappear") == false then
			instance.sprite:Play("Disappear",true)
		end
		if instance.sprite:IsPlaying("Disappear") == true then
			instance.sprite.Color = params.color or Color.Default
			instance.sprite:Render(posoffset,Vector(0,0),Vector(0,0))
			instance.clock = instance.clock or Game():GetFrameCount()
			if instance.clock ~= Game():GetFrameCount() then instance.sprite:Update() instance.clock = Game():GetFrameCount() end
		else
			item.remove_charge_bar(ent,name3,true)
		end
	end
	return {pos = pos,}
end

function item.debug_snapshot()
	if not g.is_gameplay_world_active() then return {} end
	local rows = {}
	local function inspect(ent, label)
		local d = ent:GetData()
		for id, instance in pairs(d.charge_bar_holder_instances or {}) do
			local def = definition_for(id:sub(1, -5))
			local sprite = instance.sprite
			local pos = instance.offset or item.get_charge_bar_pos(ent, id)
			local slot = "none"
			if (type(pos) == "userdata" or type(pos) == "table") and type(pos.X) == "number" and type(pos.Y) == "number" then
				slot = (instance.offset and "fixed " or "allocated ") .. tostring(pos.X) .. "," .. tostring(pos.Y)
			end
			rows[#rows + 1] = string.format("%s %s | %s | valid=%s | anim=%s | frame=%s | slot=%s",
				label, id:sub(1, -5), def and owner_for(def, ent).type or "legacy",
				tostring(not def or owner_valid(def, ent)),
				sprite and sprite:GetAnimation() or "-", tostring(instance.last_render_frame or "-"), slot)
		end
	end
	local game = Game()
	for i = 0, game:GetNumPlayers() - 1 do inspect(Isaac.GetPlayer(i), "P" .. i) end
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent:ToFamiliar() or ent:ToNPC() then inspect(ent, "E" .. ent.Type .. ":" .. ent.Variant) end
	end
	table.sort(rows)
	return rows
end

return item

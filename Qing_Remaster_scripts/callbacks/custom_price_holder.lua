local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local PICKUP_COLLECTIBLE = PickupVariant and PickupVariant.PICKUP_COLLECTIBLE or 100
local PRICE_FREE = PickupPrice and PickupPrice.PRICE_FREE or -1000

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Custom_price_holder_",
	prices = {},
	order = {},
	next_sentinel = -9100,
	price_offset = Vector(0,0),
	sprite_anim = "Hearts",
	price_icon_frames = {
		one_black = 0,
		two_black = 1,
		one_black_two_soul = 3,
		one_black_one_soul = 7,
	},
	restore_basic = {
		mx_heart = true,
		gd_heart = true,
		rt_heart = true,
		et_heart = true,
		bl_heart = true,
		rd_heart = true,
		sl_heart = true,
		bk_heart = true,
		lim_heart = true,
		bn_heart = true,
	},
}

local price_sprite = Sprite()
price_sprite:Load("gfx/005.150_shop item.anm2", true)
for layer = 0,2 do
	price_sprite:ReplaceSpritesheet(layer,"gfx/items/shop_price_01.png")
end
price_sprite:LoadGraphics()
price_sprite:SetFrame(item.sprite_anim,0)
item.price_sprite = price_sprite

function item.register_price(id,info)
	if id == nil or info == nil then return end
	if item.prices[id] == nil then
		table.insert(item.order,#item.order + 1,id)
	end
	info.id = id
	info.sentinel = info.sentinel or (item.next_sentinel - #item.order)
	item.prices[id] = info
	return info
end

local function get_data(ent)
	local d = ent:GetData()
	d[item.own_key] = d[item.own_key] or {}
	return d[item.own_key]
end

local function get_active_info(ent)
	local data = ent:GetData()[item.own_key]
	if data and data.id then return item.prices[data.id],data end
end

function item.restore_price(ent)
	local data = ent:GetData()[item.own_key]
	if data then
		if data.base_price ~= nil and ent.Price == data.sentinel then
			ent.Price = data.base_price
		end
		ent.AutoUpdatePrice = true
		ent:GetData()[item.own_key] = nil
	end
end

local function find_price(ent,base_price)
	for _,id in ipairs(item.order) do
		local info = item.prices[id]
		if info and (info.variant == nil or info.variant == ent.Variant) then
			local price_data = info.check and info.check(ent,base_price)
			if price_data and info.can_any_pay and not info.can_any_pay(ent,price_data) then
				price_data = nil
			end
			if price_data then return info,price_data end
		end
	end
end

function item.refresh_pickup(ent)
	if ent == nil or ent.Price == 0 then
		if ent then item.restore_price(ent) end
		return
	end
	local data = ent:GetData()[item.own_key]
	local base_price = data and data.base_price or ent.Price
	if data and ent.Price == data.sentinel then
		base_price = data.base_price
	end
	local info,price_data = find_price(ent,base_price)
	if info and price_data then
		data = get_data(ent)
		data.id = info.id
		data.base_price = base_price
		data.price_data = price_data
		data.sentinel = info.sentinel
		ent.AutoUpdatePrice = false
		ent.Price = info.sentinel
	else
		item.restore_price(ent)
	end
end

function item.register_price_icon(id,frame)
	if id == nil or frame == nil then return end
	item.price_icon_frames[id] = frame
end

local function render_price_icon(frame,pos)
	item.price_sprite:SetFrame(item.sprite_anim,frame)
	item.price_sprite.Color = Color(1,1,1,1,0,0,0)
	item.price_sprite:Render(pos,Vector.Zero,Vector.Zero)
end

function item.default_render(ent,price_data,render_offset)
	if price_data == nil then return end
	local room = Game():GetRoom()
	if room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local pos = Isaac.WorldToScreen(ent.Position + ent.PositionOffset) + (render_offset or Vector.Zero) + item.price_offset
	local frame = price_data.price_frame or item.price_icon_frames[price_data.price_icon]
	if frame == nil then return end
	render_price_icon(frame,pos)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	if ent and ent:IsShopItem() then
		item.refresh_pickup(ent)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil, priority = -120,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	local info,data = get_active_info(ent)
	if player and info and data and ent.Price == data.sentinel then
		if auxi.will_pick_up(player,ent) then
			if info.can_pay and info.can_pay(player,ent,data.price_data) then
				local paid = true
				if info.pay then
					paid = info.pay(player,ent,data.price_data) ~= false
				end
				if paid then
					ent.Price = PRICE_FREE
					return nil
				end
				item.refresh_pickup(ent)
			end
			return true
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = nil,
Function = function(_,ent,renderOffset)
	local info,data = get_active_info(ent)
	if info and data and ent.Price == data.sentinel then
		if info.render then
			info.render(ent,data.price_data,renderOffset)
		else
			item.default_render(ent,data.price_data,renderOffset)
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_BASIC, params = nil,
Function = function(_,player,changetype,count)
	if item.restore_basic[changetype] then
		for _,ent in pairs(auxi.getothers(nil,5)) do
			if ent:ToPickup() then item.refresh_pickup(ent:ToPickup()) end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function()
	for _,ent in pairs(auxi.getothers(nil,5)) do
		if ent:ToPickup() then item.refresh_pickup(ent:ToPickup()) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	for _,ent in pairs(auxi.getothers(nil,5)) do
		if ent:ToPickup() then item.refresh_pickup(ent:ToPickup()) end
	end
end,
})

return item

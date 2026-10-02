local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")

local item = {
	ToCall = {},
	pre_myToCall = {},
	myToCall = {},
	entity = enums.Items.It_s_a_trick,
	delay_time = nil,
	own_key = "Item_glaze_item_",
	room_temp_key = "Item_glaze_item_room_temp",
	flash_until = {},
	-- 真核亮相 → 交叉淡入伪装，约 0.9s，避免硬切图标
	FLASH_DUR = 28,
	-- 开局临时入池：低权重，避免玩家默认怀疑所有道具
	POOL_WEIGHT = 0.12,
	POOL_DECREASE = 0.05,
	POOL_REMOVE_ON = 0.05,
	POOL_TYPES = {
		ItemPoolType.POOL_TREASURE,
		ItemPoolType.POOL_SHOP,
		ItemPoolType.POOL_BOSS,
		ItemPoolType.POOL_DEVIL,
		ItemPoolType.POOL_ANGEL,
		ItemPoolType.POOL_SECRET,
		ItemPoolType.POOL_LIBRARY,
		ItemPoolType.POOL_PLANETARIUM,
	},
}

local HUD_OUTLINE_OFFS = {
	Vector(-1, 0), Vector(1, 0), Vector(0, -1), Vector(0, 1),
	Vector(-1, -1), Vector(1, -1), Vector(-1, 1), Vector(1, 1),
}

local function get_mimicked_collectible()
	local collectible = tonumber(save.elses.glazed_trick) or 32
	if collectible == item.entity or Isaac.GetItemConfig():GetCollectible(collectible) == nil then
		collectible = 32
	end
	return collectible
end

local function any_player_has_trick()
	for i = 0, Game():GetNumPlayers() - 1 do
		if Game():GetPlayer(i):HasCollectible(item.entity) then
			return true
		end
	end
	return false
end

local function get_room_stacks(player)
	if not player then return nil end
	local d = player:GetData()
	local stacks = d[item.room_temp_key]
	if type(stacks) ~= "table" then
		stacks = {}
		d[item.room_temp_key] = stacks
	end
	return stacks
end

local function clear_room_stacks(player)
	if not player then return end
	player:GetData()[item.room_temp_key] = nil
end

local function add_room_stack(player, collectible_id)
	local stacks = get_room_stacks(player)
	if not stacks then return 0 end
	local id = tonumber(collectible_id)
	if not id or id <= 0 then return 0 end
	stacks[id] = (tonumber(stacks[id]) or 0) + 1
	return stacks[id]
end

local function refresh_imitate(player)
	-- Evaluate_Imitate_Items 内部已 CACHE_ALL + should_evaluate_on_update_once（Unique_holder 归一化）
	Imitate_item_holder.Evaluate_Imitate_Items(player)
end

local function player_flash_key(player)
	return tostring(player:GetData().__Index or auxi.GetPlayerOrder(player) or 0)
end

local function trigger_flash(player)
	if not player then return end
	item.flash_until[player_flash_key(player)] = Game():GetFrameCount() + item.FLASH_DUR
end

-- 返回 0..1 进度；不在闪烁中则 nil
local function flash_progress(player)
	local until_frame = item.flash_until[player_flash_key(player)]
	if not until_frame then return nil end
	local left = until_frame - Game():GetFrameCount()
	if left < 0 then
		item.flash_until[player_flash_key(player)] = nil
		return nil
	end
	return 1 - (left / item.FLASH_DUR)
end

local function hud_ready_outline_color(alpha)
	-- Thoth：Tint 黑 + Offset 白 = 实心白剪影，画在本体底下
	local pulse = 0.62 + 0.38 * (0.5 + 0.5 * math.sin(Game():GetFrameCount() * 0.14))
	local col = Color(0, 0, 0, (alpha or 1) * pulse, 1, 1, 1)
	if col.SetColorize then col:SetColorize(0, 0, 0, 0) end
	return col
end

local function active_fully_charged(player, slot)
	local maxc = 0
	pcall(function() maxc = player:GetActiveMaxCharge(slot) end)
	if not maxc or maxc <= 0 then
		local cfg = Isaac.GetItemConfig():GetCollectible(item.entity)
		maxc = cfg and cfg.MaxCharges or 0
	end
	if maxc <= 0 then return false end
	return player:GetActiveCharge(slot) >= maxc
end

local function true_gfx()
	local cfg = Isaac.GetItemConfig():GetCollectible(item.entity)
	return (cfg and cfg.GfxFileName) or "gfx/items/collectibles/collectibles_Glaze_Collectible.png"
end

local function mimic_gfx()
	local cfg = Isaac.GetItemConfig():GetCollectible(get_mimicked_collectible())
	return (cfg and cfg.GfxFileName) or true_gfx()
end

-- glazed_item.anm2：Pivot (16,16)，与旧版一致，必须配 PlayerActiveUIPos
local gl_s = Sprite()
gl_s:Load("gfx/mimics/Glaze_Item/glazed_item.anm2", true)
gl_s:Play("Idle", true)
local gl_s_fx = Sprite()
gl_s_fx:Load("gfx/mimics/Glaze_Item/glazed_item.anm2", true)
gl_s_fx:Play("Idle", true)
local glaze_anim_frame = 0
local last_sheet = {main = nil, fx = nil}

local function ensure_sheet(spr, gfx, cache_key)
	if last_sheet[cache_key] == gfx then return end
	spr:ReplaceSpritesheet(0, gfx)
	spr:LoadGraphics()
	last_sheet[cache_key] = gfx
end

local function damp_bounce_scale(slot_scale)
	-- anm2 层内仍有轻微弹跳；Sprite.Scale 只乘槽位缩放，避免再放大错位
	return Vector(slot_scale, slot_scale)
end

local function render_icon_at(spr, pos, col, slot_scale)
	spr.Color = col
	spr.Scale = damp_bounce_scale(slot_scale)
	spr:Render(pos, Vector.Zero, Vector.Zero)
	spr.Scale = Vector(1, 1)
	spr.Color = Color(1, 1, 1, 1)
end

local function render_outline_under(spr, pos, alpha, slot_scale)
	-- 先白边（底下），后本体；与当前弹跳帧同步
	local outline = hud_ready_outline_color(alpha)
	spr.Color = outline
	spr.Scale = Vector(slot_scale, slot_scale)
	for i = 1, #HUD_OUTLINE_OFFS do
		spr:Render(pos + HUD_OUTLINE_OFFS[i] * slot_scale, Vector.Zero, Vector.Zero)
	end
	spr.Scale = Vector(1, 1)
	spr.Color = Color(1, 1, 1, 1)
end

local function render_active_mimic(player, slot, cid)
	local info = ui.GetActiveSlotRenderInfo(player, slot)
	local slot_scale = (info and tonumber(info.scale)) or 1
	local alpha = (info and tonumber(info.alpha)) or 1
	-- 与修改前相同：中心锚点 anm2 → 框中心
	local pos = ui.PlayerActiveUIPos(player, slot, auxi.GetPlayerOrder(player), cid)

	if Game():IsPaused() == false then
		glaze_anim_frame = glaze_anim_frame + 1
		if glaze_anim_frame > 47 then glaze_anim_frame = 0 end
	end
	gl_s:SetFrame(glaze_anim_frame)
	gl_s_fx:SetFrame(glaze_anim_frame)

	local t = flash_progress(player)
	local charged = active_fully_charged(player, slot)
	-- 稳态琉璃色交给 glazed_item.anm2 帧内 Tint，与改前一致
	local steady = Color(1, 1, 1, alpha)

	if t == nil then
		ensure_sheet(gl_s, mimic_gfx(), "main")
		if charged then
			render_outline_under(gl_s, pos, alpha, slot_scale)
		end
		render_icon_at(gl_s, pos, steady, slot_scale)
		return
	end

	-- 闪烁三段：真核亮相 → 交叉淡入 → 落稳伪装
	if t < 0.28 then
		local u = t / 0.28
		local bloom = 1 + 0.12 * math.sin(u * math.pi)
		local flash_a = alpha * (0.75 + 0.25 * math.sin(u * math.pi))
		ensure_sheet(gl_s, true_gfx(), "main")
		local col = Color(1, 1, 1, flash_a, 0.25 * (1 - u), 0.45 * (1 - u), 0.55 * (1 - u))
		if col.SetColorize then col:SetColorize(0.6, 1.4, 1.6, 1) end
		gl_s:SetFrame(0)
		gl_s.Scale = Vector(slot_scale * bloom, slot_scale * bloom)
		gl_s.Color = col
		gl_s:Render(pos, Vector.Zero, Vector.Zero)
		gl_s.Scale = Vector(1, 1)
		gl_s.Color = Color(1, 1, 1, 1)
		gl_s:SetFrame(glaze_anim_frame)
	elseif t < 0.62 then
		local u = (t - 0.28) / (0.62 - 0.28)
		ensure_sheet(gl_s, mimic_gfx(), "main")
		ensure_sheet(gl_s_fx, true_gfx(), "fx")
		render_icon_at(gl_s, pos, Color(1, 1, 1, alpha * (0.35 + 0.65 * u)), slot_scale)
		local core_a = alpha * (1 - u) * 0.95
		local core_col = Color(1, 1, 1, core_a, 0.15 * (1 - u), 0.3 * (1 - u), 0.35 * (1 - u))
		if core_col.SetColorize then core_col:SetColorize(0.5, 1.2, 1.4, 1 - u) end
		gl_s_fx:SetFrame(0)
		render_icon_at(gl_s_fx, pos, core_col, slot_scale)
		gl_s_fx:SetFrame(glaze_anim_frame)
	else
		local u = (t - 0.62) / (1 - 0.62)
		ensure_sheet(gl_s, mimic_gfx(), "main")
		if charged and u > 0.45 then
			render_outline_under(gl_s, pos, alpha * u, slot_scale)
		end
		render_icon_at(gl_s, pos, steady, slot_scale)
	end
end

local function inject_pools()
	if not REPENTOGON then return end
	local pool = Game():GetItemPool()
	if not pool or not pool.AddTemporaryCollectible then return end
	pcall(function() pool:RemoveCollectible(item.entity) end)
	local entry = {
		itemID = item.entity,
		weight = item.POOL_WEIGHT,
		decreaseBy = item.POOL_DECREASE,
		removeOn = item.POOL_REMOVE_ON,
	}
	for i = 1, #item.POOL_TYPES do
		local pt = item.POOL_TYPES[i]
		if pt ~= nil then
			pcall(function() pool:AddTemporaryCollectible(pt, entry) end)
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GET_COLLECTIBLE, params = nil,
Function = function(_,coltyp,pooltyp,decrease,seed)
	if coltyp == item.entity then
		if Game():GetFrameCount() > 3 and (item.delay_time ~= nil and Game():GetFrameCount() > item.delay_time + 3) then
			local rng = RNG()
			rng:SetSeed(seed,0)
			rng = auxi.rng_for_sake(rng)
			local trk = Game():GetItemPool():GetCollectible(pooltyp, true, seed)
			if pooltyp ~= 6 then
				for i = 1,10 do
					if Isaac.GetItemConfig():GetCollectible(trk).Type == ItemType.ITEM_ACTIVE then
						trk = Game():GetItemPool():GetCollectible(pooltyp, true,rng:Next())
					else
						break
					end
				end
			else
				trk = 584
			end
			if Isaac.GetItemConfig():GetCollectible(trk).Type == ItemType.ITEM_ACTIVE then
				save.elses.glazed_trick = 32
			else
				save.elses.glazed_trick = trk
			end
		end
	end
end,
})

table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = 100,
Function = function(_,ent,val)
	if ent.Variant == 100 and ent.SubType == item.entity then
		if val < 0 then
			local price = val
			local price2 = - Isaac.GetItemConfig():GetCollectible(save.elses.glazed_trick).DevilPrice
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				if player:HasTrinket(TrinketType.TRINKET_YOUR_SOUL) then
					price = -6
				end
			end
			if price ~= -6 then
				if price2 < -1 then
					for playerNum = 1, Game():GetNumPlayers() do
						local player = Game():GetPlayer(playerNum - 1)
						if player:HasTrinket(TrinketType.TRINKET_JUDAS_TONGUE) then
							price = -1
						end
					end
					local player = Game():GetPlayer(0)
					if(price == -1 or price == -2) and (player:GetMaxHearts() + player:GetBoneHearts() == 0 or auxi.is_soul_player(player) == true) then
						price = -3
					end
					if price == -2 and player:GetMaxHearts() + player:GetBoneHearts() == 2 then
						price = -4
					end
				end
			end
			return price
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = 100,
Function = function(_,ent)
	if ent.Variant == 100 and ent.SubType == item.entity then
		if auxi.isBlindPickup(ent) == false then
			if ent:GetData()[item.own_key.."sprite"] ~= true then
				local s = ent:GetSprite()
				s:ReplaceSpritesheet(1, Isaac.GetItemConfig():GetCollectible(save.elses.glazed_trick).GfxFileName)
				s:LoadGraphics()
				ent:GetData()[item.own_key.."sprite"] = true
				price_holder.try_catch_price(ent)
			end
		end
	else
		if ent:GetData()[item.own_key.."sprite"] then ent:GetData()[item.own_key.."sprite"] = nil end
	end
end,
})

if ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM, params = item.entity,
	Function = function(_, player, slot)
		if player:GetActiveItem(slot) ~= item.entity then return end
		-- 取消本体图标与原版白边，改画伪装道具的琉璃化版本
		return {HideItem = true, HideOutline = true}
	end,
	})
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_, player, tp, cid, slot)
	if cid ~= item.entity then return end
	render_active_mimic(player, slot, cid)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
		item.delay_time = Game():GetFrameCount()
	else
		item.delay_time = 0
		save.elses.glazed_trick = 32
		item.flash_until = {}
		inject_pools()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.delay_time = nil
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	if collid == item.entity and count > 0 then
		trigger_flash(player)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	if coltyp == item.entity then
		rng = auxi.rng_for_sake(rng)
		local mimicked = get_mimicked_collectible()
		trigger_flash(player)
		if rng:RandomFloat() < 0.05 then
			clear_room_stacks(player)
			refresh_imitate(player)
			player:AddCollectible(mimicked)
			player:RemoveCollectible(item.entity)
		else
			-- 本模组临时/模拟道具：叠层后走 imitate 评估（非原版 CollectibleEffect）
			add_room_stack(player, mimicked)
			refresh_imitate(player)
		end
		if auxi.should_spawn_wisp(player,useFlags) then
			local rnd = rng:RandomInt(10)
			if rnd == 1 then
				player:AddItemWisp(mimicked,player.Position,true)
			end
		end
		player:AnimateCollectible(mimicked,"UseItem", "PlayerPickupSparkle")
		return false
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	for i = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player then clear_room_stacks(player) end
	end
	-- imitate_item_holder 换房会延迟 Evaluate；清栈后由其统一同步
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,_,value)
	local stacks = player:GetData()[item.room_temp_key]
	if type(stacks) ~= "table" then return end
	for id, n in pairs(stacks) do
		local cid = tonumber(id)
		local count = tonumber(n) or 0
		if cid and count > 0 then
			-- display 交给 temp_hud 琉璃化绘制；costume 默认跟随是否被 HUD 展示
			Imitate_item_holder.add(value, cid, count, {display = false, costume = false})
		end
	end
end,
})

do
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	temp_hud.register_provider(function(player)
		local stacks = player:GetData()[item.room_temp_key]
		if type(stacks) ~= "table" then return end
		local counts = {}
		local any = false
		for id, n in pairs(stacks) do
			local cid = tonumber(id)
			local count = tonumber(n) or 0
			if cid and count > 0 then
				counts[cid] = count
				any = true
			end
		end
		if not any then return end
		return counts
	end,{
		glaze = true,
		exclusive = true,
		source_item = item.entity,
	})
end

if EID then
	EID:addDescriptionModifier(item.own_key .. "mimicked_eid", function(desc)
		return desc.ObjType == 5 and desc.ObjVariant == 100 and desc.ObjSubType == item.entity
	end, function(desc)
		local mimicked = get_mimicked_collectible()
		local mimicked_desc = EID:getDescriptionObj(5, 100, mimicked, nil, true)
		if mimicked_desc == nil then
			return desc
		end

		desc.Icon = mimicked_desc.Icon
		desc.Quality = mimicked_desc.Quality
		desc.Transformation = mimicked_desc.Transformation
		desc.ModName = mimicked_desc.ModName
		desc.ItemPoolType = mimicked_desc.ItemPoolType
		desc.ItemType = mimicked_desc.ItemType
		desc.ChargeType = mimicked_desc.ChargeType
		desc.Charges = mimicked_desc.Charges

		if not any_player_has_trick() then
			desc.Name = mimicked_desc.Name
			desc.Description = mimicked_desc.Description
			return desc
		end

		local language = EID:getLanguage()
		if language == "zh_cn" then
			desc.Name = "伪饰的" .. mimicked_desc.Name
			desc.Description = "{{Room}} 使用后，本房间获得其伪装道具的效果"
				.. "#每次使用有5%概率永久变为该道具"
				.. "#" .. mimicked_desc.Description
		else
			desc.Name = "Disguised " .. mimicked_desc.Name
			desc.Description = "{{Room}} On use, gain the disguised item's effect for the room"
				.. "#Each use has a 5% chance to permanently become that item"
				.. "#" .. mimicked_desc.Description
		end
		return desc
	end)
end

return item

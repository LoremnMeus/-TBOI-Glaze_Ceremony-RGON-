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
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")

-- 倒位宇宙核心规则：
-- 本局只有第一次使用会移除并记录一件道具。
-- 此后每次使用都只是生成该记录道具的副本。
-- 复制绝不能清空或替换记录。
-- 建立记录后，每个新楼层都重新生成一张倒位宇宙。
--
-- Universe_r design invariant:
-- The FIRST use permanently records one removed collectible for this run.
-- Every later use COPIES that recorded collectible.
-- Copying NEVER clears or replaces the stored collectible.
-- Once a record exists, a new Universe_r is granted every new floor.
--
-- save.elses[own_key.."effect"][idx] == nil/0 → 尚未记录
-- save.elses[own_key.."effect"][idx] == collectibleId → 本局宇宙记录
-- effect_s 是旧的一次性“等待返还”字段；新逻辑不再读写。

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Universe_r,
	own_key = "Thoth_cd21r_Uni_",
	base_desc = nil,
	_hud_desc_state = nil,
}

-- Flavor subtitle stages are presentation-only and per-player for the run.
-- They must never share storage with the collectible Universe record.
local DESC_STEPS = {
	zh = {
		[0] = "不管离开多远",
		[1] = "不管时间如何流逝",
		[2] = "你永远都是属于我的",
	},
	en = {
		[0] = "No matter how far you go",
		[1] = "No matter how much time passes",
		[2] = "You will always belong to me",
	},
}

local function get_effect_root()
	local key = item.own_key .. "effect"
	local root = save.elses[key]
	if type(root) ~= "table" then
		root = {}
		save.elses[key] = root
	end
	return root
end

local function get_desc_stage_root()
	local key = item.own_key .. "desc_stage"
	local root = save.elses[key]
	if type(root) ~= "table" then
		root = {}
		save.elses[key] = root
	end
	return root
end

local function get_desc_stage(idx)
	local root = get_desc_stage_root()
	return math.max(0, math.min(2, tonumber(root[idx]) or 0))
end

local function set_desc_stage(idx, stage)
	if idx == nil then
		return
	end
	local root = get_desc_stage_root()
	local next_stage = math.max(0, math.min(2, math.floor(tonumber(stage) or 0)))
	local cur = tonumber(root[idx]) or 0
	-- Stage only advances within a run; new games clear the table.
	if next_stage < cur then
		next_stage = cur
	end
	root[idx] = next_stage
end

local function get_desc_language()
	local lang = Options and Options.Language
	if lang == "zh"
		or lang == "cn"
		or lang == "schinese"
		or lang == "tchinese"
	then
		return "zh"
	end
	if EID and EID.Config and EID.Config["Language"] then
		local eid_lang = tostring(EID.Config["Language"])
		if eid_lang:find("zh") or eid_lang:find("chinese") then
			return "zh"
		end
	end
	return "en"
end

local function get_dynamic_desc(player)
	local lang = get_desc_language()
	local steps = DESC_STEPS[lang] or DESC_STEPS.en
	if not player then
		return steps[0]
	end
	local idx = player:GetData().__Index
	if idx == nil then
		return steps[0]
	end
	return steps[get_desc_stage(idx)] or steps[0]
end

-- PocketItem-aware primary-card check (same semantics as oblivion_common).
local function get_primary_card(player)
	if not player then
		return nil
	end
	local slot = PillCardSlot and PillCardSlot.PRIMARY or 0
	if player.GetPocketItem then
		local pocket = player:GetPocketItem(slot)
		if not pocket then
			return nil
		end
		local pocket_slot = pocket:GetSlot()
		if pocket_slot == 0 then
			return nil
		end
		if not PocketItemType or pocket:GetType() ~= PocketItemType.CARD then
			return nil
		end
		return pocket_slot
	end
	local card = player:GetCard(0)
	if card and card > 0 then
		return card
	end
	return nil
end

local function has_primary_card(player, card_id)
	return get_primary_card(player) == card_id
end

local function hud_desc_cache()
	if type(item._hud_desc_state) ~= "table" then
		item._hud_desc_state = {
			active = false,
			stage = nil,
			language = nil,
			player_index = nil,
		}
	end
	return item._hud_desc_state
end

local function capture_base_desc()
	if item.base_desc ~= nil then
		return
	end
	local cfg = Isaac.GetItemConfig():GetCard(item.entity)
	if cfg then
		item.base_desc = cfg.Description or ""
	end
end

local function restore_base_desc()
	local cache = item._hud_desc_state
	if not cache or not cache.active then
		return
	end
	capture_base_desc()
	local cfg = Isaac.GetItemConfig():GetCard(item.entity)
	if cfg and item.base_desc ~= nil then
		cfg.Description = item.base_desc
	end
	cache.active = false
	cache.stage = nil
	cache.language = nil
	cache.player_index = nil
end

local function force_restore_base_desc()
	capture_base_desc()
	local cfg = Isaac.GetItemConfig():GetCard(item.entity)
	if cfg and item.base_desc ~= nil then
		cfg.Description = item.base_desc
	end
	local cache = hud_desc_cache()
	cache.active = false
	cache.stage = nil
	cache.language = nil
	cache.player_index = nil
end

-- Config-backed display owner: lowest player index whose primary card is Universe_r.
-- ItemConfig.Card is global — never loop every player and overwrite Description repeatedly.
local function find_config_display_owner()
	local best = nil
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and has_primary_card(player, item.entity) then
			-- First match is the lowest index because the loop is ascending.
			best = player
			break
		end
	end
	return best
end

-- Persistent / Config-backed Description only. Pickup ShowItemText uses PRE_DESCRIPT_ITEM.
local function sync_config_description()
	capture_base_desc()
	local cache = hud_desc_cache()
	local player = find_config_display_owner()
	if not player then
		if cache.active then
			restore_base_desc()
		end
		return
	end
	local idx = player:GetData().__Index
	local stage = get_desc_stage(idx)
	local language = get_desc_language()
	if cache.active
		and cache.stage == stage
		and cache.language == language
		and cache.player_index == idx
	then
		return
	end
	local cfg = Isaac.GetItemConfig():GetCard(item.entity)
	if not cfg then
		return
	end
	local desc = get_dynamic_desc(player)
	if cfg.Description ~= desc then
		cfg.Description = desc
	end
	cache.active = true
	cache.stage = stage
	cache.language = language
	cache.player_index = idx
end

local function migrate_desc_stage_from_effects()
	local effects = get_effect_root()
	local stages = get_desc_stage_root()
	for idx, stored in pairs(effects) do
		if (tonumber(stored) or 0) ~= 0 and stages[idx] == nil then
			-- Old saves cannot prove the copy stage already happened.
			stages[idx] = 1
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	local effects = get_effect_root()
	local room = Game():GetRoom()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		local idx = player:GetData().__Index
		local stored = effects[idx] or 0
		-- 只要本局已经建立宇宙记录，每层都重新生成倒位宇宙
		if stored ~= 0 then
			local q = Isaac.Spawn(
				5,
				300,
				item.entity,
				room:FindFreePickupSpawnPosition(player.Position, 10, true),
				Vector.Zero,
				player
			):ToPickup()
			q:Morph(5, 300, item.entity, true, true, true)
			q.PositionOffset = Vector(0, -600)
			local qd = q:GetData()
			qd[item.own_key.."effect"] = true
			qd[item.own_key.."player_idx"] = idx
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	capture_base_desc()
	if not continue then
		-- 新开一局：清空宇宙记录与风味阶段
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."desc_stage"] = {}
	end

	-- 旧存档：全局单值 → 迁移给 Player 0
	if type(save.elses[item.own_key.."effect"]) ~= "table" then
		local old_effect = save.elses[item.own_key.."effect"]
		save.elses[item.own_key.."effect"] = {}
		if (old_effect or 0) ~= 0 then
			local idx = Game():GetPlayer(0):GetData().__Index
			local effects = get_effect_root()
			effects[idx] = old_effect
		end
	end

	migrate_desc_stage_from_effects()
	force_restore_base_desc()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 300,
Function = function(_,ent,col,low)
	local owner_idx = ent:GetData()[item.own_key.."player_idx"]
	local player = col:ToPlayer()
	if owner_idx ~= nil and player and player:GetData().__Index ~= owner_idx then return false end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 300,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if d.add_vel == nil then d.add_vel = 0 end
		if d.add_acce == nil then d.add_acce = 7 end
		d.add_vel = d.add_vel + d.add_acce
		local ymx = ent.PositionOffset.Y + d.add_vel
		if ymx > 0 then
			d.add_vel = - d.add_vel * 0.7
			if d.add_vel < 10 then
				d.add_acce = 0
				d.add_vel = 0
			end
			ymx = 0
		end
		ent.PositionOffset = Vector(ent.PositionOffset.X, ymx)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_, cardtype, player, useFlags)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return
	end

	local room = Game():GetRoom()
	local rng = player:GetCardRNG(cardtype)
	rng = auxi.rng_for_sake(rng)
	local d = player:GetData()
	local idx = d.__Index
	local effects = get_effect_root()
	local stored = effects[idx] or 0

	------------------------------------------------
	-- 第一次使用：送入宇宙（只记录一次）
	------------------------------------------------
	if stored == 0 then
		local col = auxi.get_random_item_that_player_has(player, rng, {
			ignore_pocket_item = true,
			by_weight = function(val, id)
				local collectible = Isaac:GetItemConfig():GetCollectible(id)
				if collectible then
					return collectible.Quality + 2
				end
				return 1
			end,
		})

		if not col then
			return
		end

		player:AnimateCollectible(col, "LiftItem", "PlayerPickup")
		delay_buffer.addeffe(function()
			local effects = get_effect_root()
			if not player:IsHoldingItem() then
				return
			end

			player:AnimateCollectible(col, "HideItem", "PlayerPickup")

			local before = player:GetCollectibleNum(col, true)
			if before <= 0 then
				return
			end

			player:RemoveCollectible(col)

			local after = player:GetCollectibleNum(col, true)
			if after >= before then
				return
			end

			-- 只记录一次，之后永不因复制而清除
			effects[idx] = col
			set_desc_stage(idx, 1)

			sound_tracker.PlayStackedSound(
				SoundEffect.SOUND_BLACK_POOF,
				1,
				1,
				false,
				0,
				2
			)
			Isaac.Spawn(1000, 16, 2, player.Position, Vector.Zero, player)
			Isaac.Spawn(1000, 16, 1, player.Position, Vector.Zero, player)
		end, {}, 15)
		return
	end

	------------------------------------------------
	-- 后续使用：复制宇宙中的记录道具（不清除记录）
	------------------------------------------------
	unique_holder.with_missing(33, function()
		local q = Isaac.Spawn(
			5,
			100,
			stored,
			room:FindFreePickupSpawnPosition(player.Position, 10, true),
			Vector.Zero,
			player
		):ToPickup()
		if not q then
			return
		end

		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			-- 塔罗牌布：保留正常新生成 pedestal 状态
		else
			-- 普通倒位宇宙：复制品视为已触碰，主动无充能
			auxi.self_morph(q, {5, 100, stored})
			q.Touched = true
			q.Charge = 0
		end

		-- First successful copy advances flavor to the final stage.
		set_desc_stage(idx, 2)
	end)
	-- 关键：不清除 effect[idx]；宇宙记录持续整局
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM,
	params = nil,
	Function = function(_, player, tp, id, value)
		if tp ~= "Card" then
			return
		end
		if id ~= item.entity then
			return
		end
		if not player or type(value) ~= "table" then
			return
		end
		value.Description = get_dynamic_desc(player)
		return value
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function(_)
		sync_config_description()
	end,
})

if ModCallbacks.MC_PRE_GAME_EXIT then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
		params = nil,
		Function = function(_)
			force_restore_base_desc()
		end,
	})
end

if ModCallbacks.MC_POST_GAME_END then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_GAME_END,
		params = nil,
		Function = function(_)
			force_restore_base_desc()
		end,
	})
end

return item

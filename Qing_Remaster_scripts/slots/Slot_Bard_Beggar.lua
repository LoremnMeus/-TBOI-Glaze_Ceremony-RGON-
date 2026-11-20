local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local slot_manager = require("Qing_Remaster_scripts.core.slot_manager")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local every_entity_holder = require("Qing_Remaster_scripts.callbacks.every_entity_holder")
local slot_offer_lift = require("Qing_Remaster_scripts.slots.slot_offer_lift")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")

local item = {
	myToCall = {},
	post_myToCall = {},
	ToCall = {},
	entity = enums.Slots.Bard_beggar,
	own_key = "Slot_Bard_Beggar_",
	Talking_Pos_Offset = Vector(30,-50),
	Dialogue = {
		zh = {
			greeting = {
				first = {"啊，终于有人肯为一首歌停下脚步！", "我不卖宝物，只把旅人的馈赠谱成曲子。", "下一段路上，你会听见它的回响。"},
				repeat_meet = {"嘿！看来我们的旅途又交汇了。", "这一次，你想听一首什么样的歌？"},
			},
			songs = {
				coin = {title = "富饶之歌", verses = {"叮当作响的钱币，最懂得世间的曲调。", "愿你付出的每一枚，都换来更丰厚的回报。"}, blessing = "愿微薄的钱币，换来丰厚的收获。"},
				key = {title = "旅途之歌", verses = {"一把钥匙，能打开的可不止一扇门。", "愿迷途的旅人，总能寻到通往宝藏的道路。"}, blessing = "通往宝藏的道路，已为你敞开。"},
				bomb = {title = "战歌", verses = {"让战鼓响起，让敌人的哀号成为旋律！", "愿最先倒下的敌人，为你的胜利敲响战鼓！"}, blessing = "以敌人的陨落，奏响胜利的序曲。"},
				heart = {title = "安魂曲", verses = {"血肉终会消散，歌声却能穿越生死。", "愿逝去的生命，化作守护你的微光。"}, blessing = "逝去的生命，亦将化作灵魂的馈赠。"},
			},
		},
		en = {
			greeting = {
				first = {"Ah, someone finally stopped to hear a song!", "I sell no treasures; I turn a traveler's gift into music.", "On the road ahead, you'll hear it echo."},
				repeat_meet = {"Hey! Our paths have crossed again.", "What sort of song would you like this time?"},
			},
			songs = {
				coin = {title = "Song of Plenty", verses = {"Clinking coins know the world's tune best.", "May every coin you give return in greater measure."}, blessing = "May a few coins bring a plentiful return."},
				key = {title = "Song of the Road", verses = {"A key can open more than the door before you.", "May every lost traveler find the road to treasure."}, blessing = "The road to treasure lies open before you."},
				bomb = {title = "War Song", verses = {"Let the drums sound, and enemies' cries become the tune!", "May the first enemy to fall beat the drum of your victory!"}, blessing = "An enemy's fall begins the song of victory."},
				heart = {title = "Requiem", verses = {"Flesh will fade, but song can cross the veil of death.", "May lost life return as a gentle light to guard you."}, blessing = "Lost life shall return as a gift to the soul."},
			},
		},
	},
}
local try_greet, utter_next

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_INIT, params = item.entity.Variant,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ then
	else
		consistance_holder.try_hold_over_entity(ent,item.own_key)
		consistance_holder.try_hold_entity(ent,item.own_key)
	end
	d._Data = d._Data or {}
	d._Data[item.own_key] = d._Data[item.own_key] or {}
	-- Accepted 只表示交易已经完成。回房后直接接现有离场，不重播支付和献唱。
	if d._Data[item.own_key].Accepted == true then
		s:Play("Teleport", true)
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	else
		s:Play("Idle", true)
	end
	d._Data[item.own_key]["State"] = true
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_UPDATE, params = item.entity.Variant,
Function = function(_,ent)
	local room = Game():GetRoom()
	local s = ent:GetSprite()
	local d = ent:GetData()
	local rng = ent:GetDropRNG()
	local anim = s:GetAnimation()
	if anim == "Idle0" or anim == "Appearing" then
		s:Play("Idle",true)
	end
	if d._say_cd and d._say_cd > 0 then
		d._say_cd = d._say_cd - 1
	end
	-- 进房后自顾自开场，不依赖交易或举物会话。
	try_greet(ent)
	if d.tosay == nil or #d.tosay == 0 then d.should_prize = false end
	if s:IsPlaying("Idle") then
		utter_next(ent)
		if d.should_prize then s:Play("Prize",true) end
	end
	if s:IsPlaying("Prize") then
		if s:IsEventTriggered("Sing") then
			d._say_cd = 0
		end
		utter_next(ent)
	end

	if s:IsFinished("Teleport") then ent:Remove() return end
	if s:IsFinished("Prize") then
		if d._Data and d._Data[item.own_key] and d._Data[item.own_key].Accepted then
			-- 献唱台词说完再离开；多句时循环 Prize。
			if (d.tosay and #d.tosay > 0) or (d._say_cd or 0) > 0 then
				s:Play("Prize",true)
				return
			end
			s:Play("Teleport",true)
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			return
		end
		s:Play("Idle",true)
	end
	if s:IsFinished("PayPrize") then s:Play("Prize",true) end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_KILL, params = item.entity.Variant,
Function = function(_,ent,killer)
	local s = ent:GetSprite()
	local level = Game():GetLevel()
	s:Play("Teleport",true)
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	level:SetStateFlag(LevelStateFlag.STATE_BUM_KILLED,true)
end,
})

local function dialogue_lang()
	local language = Options.Language
	if item.Dialogue[language] == nil then language = "zh" end
	return language
end

local function queue_dialogue(ent, lines)
	if not lines or #lines == 0 then return end
	local d = ent:GetData()
	d.tosay = d.tosay or {}
	for i = 1, #lines do
		table.insert(d.tosay, lines[i])
	end
end

local function queue_open_dialogue(ent)
	local greeting = item.Dialogue[dialogue_lang()].greeting
	if not save.elses[item.own_key.."met"] then
		-- met 只表示已经见过吟游乞丐，与是否完成交易无关。
		save.elses[item.own_key.."met"] = true
		queue_dialogue(ent, greeting.first)
	else
		queue_dialogue(ent, greeting.repeat_meet)
	end
end

-- 台词气泡约 60 帧；间隙略短，便于连说又不叠成一团。
local SAY_GAP = 50

utter_next = function(ent)
	local d = ent:GetData()
	if (d._say_cd or 0) > 0 then return false end
	if not d.tosay or not d.tosay[1] then return false end
	local line = d.tosay[1]
	table.remove(d.tosay, 1)
	gui.draw_ch_with_time_to_dispair(
		ent.Position + item.Talking_Pos_Offset + Vector(-(#line) / 2, 0),
		Vector(0, -50),
		line,
		60
	)
	d._say_cd = SAY_GAP
	if #d.tosay == 0 then
		consistance_holder.try_hold_over_entity(ent, item.own_key)
		consistance_holder.try_hold_entity(ent, item.own_key)
	end
	return true
end

try_greet = function(ent)
	local d = ent:GetData()
	if d._greeted then return end
	if d._Data and d._Data[item.own_key] and d._Data[item.own_key].Accepted then
		d._greeted = true
		return
	end
	local player = Game():GetNearestPlayer(ent.Position)
	if not player then return end
	d._greeted = true
	queue_open_dialogue(ent)
end

local function queue_offer_dialogue(ent, opt)
	local song = item.Dialogue[dialogue_lang()].songs[opt.id]
	-- 接在尚未说完的简短问候之后，支付不会截断登场对白。
	if song then queue_dialogue(ent, song.verses) end
end

local function bless_hud_text(kind)
	local song = item.Dialogue[dialogue_lang()].songs[kind]
	if song then return song.title, song.blessing end
	if dialogue_lang() == "zh" then return "吟游祝福", "本层生效" end
	return "Bard Blessing", "Active this floor"
end

local function blessing_bag()
	return save.elses[item.own_key.."bless"]
end

local function set_blessing(kind, rng)
	save.elses[item.own_key.."bless"] = {
		kind = kind,
		pending = true,
		room_uses = {},
		heart_rolls = {},
	}
end

local function clear_blessing()
	save.elses[item.own_key.."bless"] = nil
end

local function can_pay_heart(player)
	return player:GetHearts() >= 2 or player:GetSoulHearts() >= 2
end

local function pay_heart(player)
	if player:GetHearts() >= 2 then
		player:AddHearts(-2)
	else
		player:AddSoulHearts(-2)
	end
end

local OFFERS = {
	{
		id = "coin",
		anm2 = "gfx/005.021_penny.anm2",
		replacer = "gfx/items/slots/item_to_pay_coin.png",
		hud_num = "5",
		title_zh = "富饶之歌",
		title_en = "Song of Plenty",
		eid_zh = "{{Coin}} 富饶之歌#支付5枚硬币#下一层商店商品的硬币价格降低2",
		eid_en = "{{Coin}} Song of Plenty#Pay 5 coins#Shop coin prices are 2 lower next floor",
		can = function(player) return player:GetNumCoins() >= 5 end,
		take = function(player) player:AddCoins(-5) end,
	},
	{
		id = "key",
		anm2 = "gfx/005.031_key.anm2",
		replacer = "gfx/items/slots/item_to_pay_key.png",
		hud_num = "1",
		title_zh = "旅途之歌",
		title_en = "Song of the Road",
		eid_zh = "{{Key}} 旅途之歌#支付1把钥匙#下一层揭示通往宝箱房的最短路线，并持续开启沿途的门",
		eid_en = "{{Key}} Song of the Road#Pay 1 key#Next floor reveals the shortest route to the {{TreasureRoom}} and keeps the doors along it open",
		can = function(player) return player:GetNumKeys() >= 1 end,
		take = function(player) player:AddKeys(-1) end,
	},
	{
		id = "bomb",
		anm2 = "gfx/005.041_bomb.anm2",
		replacer = "gfx/items/slots/item_to_pay_bomb.png",
		hud_num = "1",
		title_zh = "战歌",
		title_en = "War Song",
		eid_zh = "{{Bomb}} 战歌#支付1个炸弹#下一层每个房间首个敌人死亡时引发爆炸",
		eid_en = "{{Bomb}} War Song#Pay 1 bomb#Next floor, the first enemy death in each room causes an explosion",
		can = function(player) return player:GetNumBombs() >= 1 end,
		take = function(player) player:AddBombs(-1) end,
	},
	{
		id = "heart",
		anm2 = "gfx/005.011_heart.anm2",
		anm2_fn = function(player)
			if player:GetHearts() >= 2 then
				return "gfx/005.011_heart.anm2"
			end
			return "gfx/005.013_heart (soul).anm2"
		end,
		replacer = "gfx/items/slots/item_to_pay_heart.png",
		replacer_fn = function(player)
			if player:GetHearts() >= 2 then
				return "gfx/items/slots/item_to_pay_heart.png"
			end
			return "gfx/items/slots/item_to_pay_soulheart.png"
		end,
		hud_num = "1",
		title_zh = "安魂曲",
		title_en = "Requiem",
		eid_zh = "{{Heart}} 安魂曲#支付1颗心#下一层生成的红心有25%概率变成魂心",
		eid_en = "{{Heart}} Requiem#Pay 1 heart#Red hearts generated next floor have a 25% chance to become soul hearts",
		can = can_pay_heart,
		take = pay_heart,
	},
}

spec = {
	key = item.own_key,
	variant = item.entity.Variant,
	range = 48,
	render_hud = false,
	on_open = function(player, ent)
		-- 开场台词由 UPDATE 的 try_greet 自顾自触发；此处仅兜底。
		try_greet(ent)
	end,
	can_open = function(ent)
		if not ent or not ent:Exists() then return false end
		local s = ent:GetSprite()
		if not s:IsPlaying("Idle") then return false end
		local d = ent:GetData()
		if d.should_prize then return false end
		if d._Data and d._Data[item.own_key] and d._Data[item.own_key].Accepted then return false end
		return true
	end,
	get_options = function(player,ent)
		local list = {}
		for _,info in ipairs(OFFERS) do
			if info.can(player) then list[#list + 1] = info end
		end
		return list
	end,
	on_confirm = function(player,ent,opt)
		if not opt or not opt.take then return end
		if opt.can and not opt.can(player) then return end
		local s = ent:GetSprite()
		local replacer = opt.replacer
		if opt.replacer_fn then replacer = opt.replacer_fn(player) end
		if replacer then
			s:ReplaceSpritesheet(2, replacer)
			s:LoadGraphics()
		end
		opt.take(player)
		set_blessing(opt.id,ent:GetDropRNG())
		local d = ent:GetData()
		queue_offer_dialogue(ent, opt)
		s:Play("PayPrize",true)
		d.should_prize = true
		consistance_holder.try_hold_over_entity(ent,item.own_key)
		d._Data[item.own_key] = d._Data[item.own_key] or {}
		d._Data[item.own_key].Accepted = true
		consistance_holder.try_hold_entity(ent,item.own_key)
		local hud = Game():GetHUD()
		if hud and hud.ShowItemText then
			if slot_offer_lift.lang_zh() then
				hud:ShowItemText(opt.title_zh or "吟游乞丐", "")
			else
				hud:ShowItemText(opt.title_en or "Bard Beggar", "")
			end
		end
	end,
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_COLLISION, params = item.entity.Variant,
Function = function(_,ent,col,low)
	local player = col and col:ToPlayer()
	if not player then return end
	local s = ent:GetSprite()
	local d = ent:GetData()
	if s:IsPlaying("Idle") and d.should_prize ~= true then
		spec.variant = item.entity.Variant
		slot_offer_lift.try_confirm(player,ent,spec)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	local stage = Game():GetLevel():GetStage()
	local seed = Game():GetSeeds():GetStageSeed(stage)
	if room:GetType() == RoomType.ROOM_SECRET_EXIT and room:IsFirstVisit() then
		local rng = RNG()
		rng:SetSeed(seed,0)
		local rnd = rng:RandomInt(100)
		if rnd > 50 then
			local q = Isaac.Spawn(item.entity.Type,item.entity.Variant,0,room:FindFreeTilePosition(room:GetRandomPosition(10),10),Vector(0,0),nil)
			every_entity_holder.init_slot(q)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	spec.variant = item.entity.Variant
	slot_offer_lift.tick(player,spec)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if ent == nil then return end
	local player = ent:ToPlayer()
	if not player then return end
	return slot_offer_lift.block_input(player,item.own_key,hook,button)
end,
})

local debug_state = {
	overrides = {coin = nil, key = nil, bomb = nil, heart = nil},
	room_uses = {}, heart_rolls = {}, route = nil,
	stats = {discounts = 0, explosions = 0, heart_rolls = 0, heart_converts = 0},
	lifecycle = {}, price_quotes = {},
}

local DEBUG_KINDS = {coin = true, key = true, bomb = true, heart = true}

local function floor_key()
	local level = Game():GetLevel()
	local stage = level:GetStage()
	local stage_seed = Game():GetSeeds():GetStageSeed(stage)
	return table.concat({stage, level:GetStageType(), auxi.GetDimension() or 0, stage_seed}, ":")
end

local function formal_active(kind)
	local bless = blessing_bag()
	return bless and bless.active and bless.kind == kind
end

local function debug_active(kind)
	return debug_state.overrides[kind] == floor_key()
end

local function effect_active(kind)
	return formal_active(kind) or debug_active(kind)
end

local function room_key()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	return floor_key() .. ":" .. tostring(desc and desc.SafeGridIndex or -1)
end

local function allowed_connection(desc, slot)
	return desc and desc.AllowedDoors and (desc.AllowedDoors & (1 << slot)) ~= 0
end

local function actual_neighbors(desc)
	local ret = {}
	if not desc or not desc.GetNeighboringRooms then return ret end
	for slot, neighbor in pairs(desc:GetNeighboringRooms()) do
		if neighbor and allowed_connection(desc, slot) then
			local reverse_slot = nil
			for other_slot, back in pairs(neighbor:GetNeighboringRooms()) do
				if back and back.SafeGridIndex == desc.SafeGridIndex and allowed_connection(neighbor, other_slot) then
					reverse_slot = other_slot
					break
				end
			end
			if reverse_slot ~= nil then
				ret[#ret + 1] = {desc = neighbor, from_slot = slot, to_slot = reverse_slot}
			end
		end
	end
	return ret
end

local function build_treasure_route()
	local level = Game():GetLevel()
	local dimension = auxi.GetDimension() or 0
	local start = level:GetRoomByIdx(level:GetStartingRoomIndex(), dimension)
	if not start then return nil end
	local queue, head = {start}, 1
	local seen = {[start.SafeGridIndex] = true}
	local parent = {}
	local target = nil
	while queue[head] do
		local desc = queue[head]
		head = head + 1
		if desc.Data and desc.Data.Type == RoomType.ROOM_TREASURE then
			target = desc
			break
		end
		for _, edge in ipairs(actual_neighbors(desc)) do
			local idx = edge.desc.SafeGridIndex
			if not seen[idx] then
				seen[idx] = true
				parent[idx] = {from = desc.SafeGridIndex, from_slot = edge.from_slot, to_slot = edge.to_slot}
				queue[#queue + 1] = edge.desc
			end
		end
	end
	if not target then return nil end
	local edges, cursor = {}, target.SafeGridIndex
	while cursor ~= start.SafeGridIndex do
		local p = parent[cursor]
		if not p then return nil end
		table.insert(edges, 1, {from = p.from, to = cursor, from_slot = p.from_slot, to_slot = p.to_slot})
		cursor = p.from
	end
	return {floor = floor_key(), start = start.SafeGridIndex, target = target.SafeGridIndex, edges = edges}
end

local function reveal_route(route)
	if not route then return end
	local level = Game():GetLevel()
	local dimension = auxi.GetDimension() or 0
	local indices = {[route.start] = true, [route.target] = true}
	for _, edge in ipairs(route.edges or {}) do indices[edge.from] = true indices[edge.to] = true end
	for idx in pairs(indices) do
		local desc = level:GetRoomByIdx(idx, dimension)
		if desc then desc.DisplayFlags = desc.DisplayFlags | 5 end
	end
	level:UpdateVisibility()
end

local function active_route()
	local bless = blessing_bag()
	if formal_active("key") then return bless.route end
	if debug_active("key") then return debug_state.route end
end

local function rebuild_route()
	local route = build_treasure_route()
	if formal_active("key") then blessing_bag().route = route end
	if debug_active("key") then debug_state.route = route end
	reveal_route(route)
	return route
end

local function open_route_doors()
	local route = active_route()
	if not route or route.floor ~= floor_key() then return end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local room = Game():GetRoom()
	for _, edge in ipairs(route.edges or {}) do
		local slot = nil
		if desc.SafeGridIndex == edge.from then slot = edge.from_slot end
		if desc.SafeGridIndex == edge.to then slot = edge.to_slot end
		if slot ~= nil then
			local door = room:GetDoor(slot)
			if door then door:Open() end
		end
	end
end

local function reset_prices()
	price_holder.reset_price()
end

local COIN_QUOTE_KEY = item.own_key .. "coin_quote"

local function clear_coin_quote_states()
	for _, entity in ipairs(auxi.getothers(nil, EntityType.ENTITY_PICKUP)) do
		local pickup = entity:ToPickup()
		if pickup then pickup:GetData()[COIN_QUOTE_KEY] = nil end
	end
end

table.insert(item.post_myToCall, {CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_, ent, val)
	if effect_active("coin") and ent and ent:IsShopItem() and type(val) == "number" and val > 0 then
		local data = ent:GetData()
		local previous = data[COIN_QUOTE_KEY]
		local reused = previous ~= nil and previous.floor == floor_key() and val == previous.final
		local base = reused and previous.base or val
		local final = math.max(1, base - 2)
		local source = formal_active("coin") and "formal" or "debug"
		data[COIN_QUOTE_KEY] = {floor = floor_key(), base = base, final = final, source = source}
		debug_state.stats.discounts = debug_state.stats.discounts + 1
		debug_state.price_quotes[tostring(GetPtrHash(ent))] = {
			floor = floor_key(), room = room_key(), input = val, base = base, final = final,
			reused_base = reused, source = source, frame = Game():GetFrameCount(),
		}
		return final
	end
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_, ent)
	if effect_active("coin") and ent:IsShopItem() then price_holder.try_catch_price(ent) end
end})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	local bless = blessing_bag()
	if bless and bless.active and not bless.floor then
		bless.floor = floor_key()
		bless.room_uses = {}
		bless.heart_rolls = {}
		if bless.kind == "key" then rebuild_route() end
		local hud = Game():GetHUD()
		if hud and hud.ShowItemText then
			local title, subtitle = bless_hud_text(bless.kind)
			if title then hud:ShowItemText(title, subtitle or "") end
		end
	end
	if debug_active("key") then rebuild_route() end
	reset_prices()
end,
})

table.insert(item.myToCall, {CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function()
	local old_floor = floor_key()
	debug_state.overrides = {coin = nil, key = nil, bomb = nil, heart = nil}
	debug_state.room_uses = {}
	debug_state.heart_rolls = {}
	debug_state.route = nil
	debug_state.price_quotes = {}
	debug_state.lifecycle[#debug_state.lifecycle + 1] = {event = "pre_new_level", floor = old_floor}
	clear_coin_quote_states()
	local bless = blessing_bag()
	if bless then
		if bless.pending then
			bless.pending = false
			bless.active = true
			bless.floor = nil
		else
			clear_blessing()
		end
	end
end})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	reveal_route(active_route())
	open_route_doors()
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = nil,
Function = function(_, npc)
	if not effect_active("bomb") or not npc:IsEnemy() or npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return end
	local key = room_key()
	local bless = blessing_bag()
	if formal_active("bomb") then
		bless.room_uses = bless.room_uses or {}
		if bless.room_uses[key] then return end
		bless.room_uses[key] = true
	elseif debug_state.room_uses[key] then
		return
	else
		debug_state.room_uses[key] = true
	end
	debug_state.stats.explosions = debug_state.stats.explosions + 1
	debug_state.last_enemy = {type = npc.Type, variant = npc.Variant, subtype = npc.SubType, room = key}
	Game():BombExplosionEffects(npc.Position, 100, BitSet128(0, 0), Color.Default, Game():GetPlayer(0), 1, false, false)
end})

local function heart_roll_store(key)
	local bless = blessing_bag()
	if formal_active("heart") then
		bless.heart_rolls = bless.heart_rolls or {}
		return bless.heart_rolls
	end
	return debug_state.heart_rolls
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_HEART,
Function = function(_, pickup)
	if not effect_active("heart") then return end
	local subtype = pickup.SubType
	if subtype ~= HeartSubType.HEART_FULL and subtype ~= HeartSubType.HEART_HALF then return end
	local key = table.concat({room_key(), pickup.InitSeed, subtype}, ":")
	local rolls = heart_roll_store(key)
	if rolls[key] ~= nil then return end
	local roll = pickup:GetDropRNG():RandomFloat()
	local convert = roll < 0.25
	rolls[key] = convert
	debug_state.stats.heart_rolls = debug_state.stats.heart_rolls + 1
	debug_state.last_heart = {
		key = key, roll = roll, convert = convert, source = formal_active("heart") and "formal" or "debug",
		floor = floor_key(), room = room_key(), subtype = subtype,
	}
	if convert then
		debug_state.stats.heart_converts = debug_state.stats.heart_converts + 1
		local target = subtype == HeartSubType.HEART_FULL and HeartSubType.HEART_SOUL or HeartSubType.HEART_HALF_SOUL
		pickup:Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, target, true, true, true)
	end
end})

table.insert(item.myToCall, {CallBack = enums.Callbacks.POST_REWIND, params = nil,
Function = function()
	debug_state.room_uses = {}
	debug_state.heart_rolls = {}
	debug_state.price_quotes = {}
	debug_state.lifecycle[#debug_state.lifecycle + 1] = {event = "post_rewind", floor = floor_key(), room = room_key()}
	clear_coin_quote_states()
	reset_prices()
	if debug_active("key") then rebuild_route() end
end})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	debug_state = {
		overrides = {coin = nil, key = nil, bomb = nil, heart = nil},
		room_uses = {}, heart_rolls = {}, route = nil,
		stats = {discounts = 0, explosions = 0, heart_rolls = 0, heart_converts = 0},
		lifecycle = {{event = continue and "continue" or "new_run", floor = floor_key()}}, price_quotes = {},
	}
	if continue then
	else
		clear_blessing()
	end
end,
})

function item.debug_get_state() return debug_state end
function item.debug_is_override(kind) return debug_active(kind) end
function item.debug_set_override(kind, enabled)
	if not DEBUG_KINDS[kind] then return false end
	debug_state.overrides[kind] = enabled == true and floor_key() or nil
	debug_state.lifecycle[#debug_state.lifecycle + 1] = {
		event = enabled == true and "debug_enable" or "debug_disable", kind = kind, floor = floor_key(), room = room_key(),
	}
	if kind == "coin" then
		clear_coin_quote_states()
		reset_prices()
	end
	if kind == "key" and enabled then rebuild_route() end
	return true
end
function item.debug_schedule(kind)
	set_blessing(kind)
	return true
end
function item.debug_rebuild_route() return rebuild_route() end
function item.debug_reset_prices() reset_prices() end
function item.debug_spawn_bard()
	local player = Game():GetPlayer(0)
	local ent = Isaac.Spawn(item.entity.Type, item.entity.Variant, 0, player.Position + Vector(80, 0), Vector.Zero, player)
	every_entity_holder.init_slot(ent)
	return ent
end
function item.debug_spawn_hearts(count)
	local player = Game():GetPlayer(0)
	for i = 1, (count or 40) do
		local subtype = i % 2 == 0 and HeartSubType.HEART_FULL or HeartSubType.HEART_HALF
		local pos = Game():GetRoom():FindFreePickupSpawnPosition(player.Position + Vector((i % 8 - 4) * 30, math.floor(i / 8) * 24), 0, true)
		Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, subtype, pos, Vector.Zero, player)
	end
end
function item.debug_copy_summary()
	local output = require("Qing_Remaster_scripts.debug.probe_output")
	return output.copy_summary({
		floor = floor_key(), room = room_key(),
		overrides = {
			coin = debug_active("coin"), key = debug_active("key"),
			bomb = debug_active("bomb"), heart = debug_active("heart"),
		},
		stats = debug_state.stats,
		last_heart = debug_state.last_heart,
		route = debug_state.route and {target = debug_state.route.target, edges = #debug_state.route.edges} or nil,
	})
end
function item.debug_copy_full_report()
	local output = require("Qing_Remaster_scripts.debug.probe_output")
	return output.copy_json({debug = debug_state, formal = blessing_bag(), floor = floor_key(), room = room_key()})
end

local function static_eid()
	if slot_offer_lift.lang_zh() then
		return "交付一份资源，获得下一层的祝福"..
			"#靠近后左右切换馈赠，走进确认"..
			"#按{{ButtonRT}}取消"
	end
	return "Offer a resource for a blessing on the next floor"..
		"#Switch gifts with left/right, walk in to confirm"..
		"#Press {{ButtonRT}} to cancel"
end

local function option_eid(player, opt)
	if slot_offer_lift.lang_zh() then
		return opt.eid_zh or static_eid()
	end
	return opt.eid_en or static_eid()
end

slot_offer_lift.install_eid("qing_bard_beggar_eid", item.entity.Variant, item.own_key, static_eid, option_eid)

return item

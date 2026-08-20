local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Wavering_Eyes = require("Qing_Remaster_scripts.items.Item_Wavering_Eyes")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local card_01_wizard = require("Qing_Remaster_scripts.cards.Card_01_Wizard")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local card_06r_lover = require("Qing_Remaster_scripts.cards.Card_06r_lover")
local player_All = require("Qing_Remaster_scripts.player.player_All")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local dev_env = require("Qing_Remaster_scripts.core.dev_environment")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Players.Zeistos,
	own_key = "Player_Zeistos_",
	Special_Des = {
		["zh"] = {
			["Item"] = {
				[CollectibleType.COLLECTIBLE_INNER_EYE] = {Name = "第三只眼",Description = "窥探真神",},
				[CollectibleType.COLLECTIBLE_TELEPORT] = {Name = "传送！",Description = "进入高维！",},
				[CollectibleType.COLLECTIBLE_XRAY_VISION] = {Name = "扫视",Description = "秘密已暴露",},
				[CollectibleType.COLLECTIBLE_POLYPHEMUS] = {Name = "巨眼",Description = "穿透性视觉",},
				[CollectibleType.COLLECTIBLE_20_20] = {Name = "近视",Description = "这可不好..",},
				[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {Name = "远视",Description = "因此停步",},
				[CollectibleType.COLLECTIBLE_GODHEAD] = {Name = "真视",Description = "被神明祝福了！",},
				[CollectibleType.COLLECTIBLE_DIPLOPIA] = {Name = "复视",Description = "机会翻倍！",},
				[CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE] = {Name = "死亡证明",Description = "跨越时间与空间",},
				[enums.Items.Cheater_s_Blessing] = {Name = "我的祝福",Description = "作弊无可厚非",},
				[enums.Items.Book_of_6_sin] = {Name = "论傲慢",Description = "无垠之野望",},
				[enums.Items.Contemplation] = {Name = "凝视",Description = "<0>",},
				[enums.Items.Nihilistic_Artificial_Eye] = {Name = "我的左眼",Description = "看到你了！",},
			},
		},
		["en"] = {
			["Item"] = {
			},
		},
	},
	banished = {
		[628] = true,
		[668] = true,
	},
	Collid_limit = 32,
	color_info = {
		[0] = {
			{frame = 0,A = 0,RO = -1,GO = -1,BO = -1,},
			{frame = 100,A = 0.25,RO = -0.8,GO = -0.8,BO = 0,},
			{frame = 300,A = 0.5,RO = -0.4,GO = -0.4,BO = 0,},
			{frame = 800,A = 1,RO = 0,GO = 0,BO = 0,},
		},
		[1] = {
			{frame = 0,A = 0.75,RO = 0.25,GO = 0.25,BO = 0.5,},
			{frame = 100,A = 0.6,RO = 0.125,GO = 0.125,BO = 0.25,},
			{frame = 300,A = 0.45,RO = 0.05,GO = 0.05,BO = 0.1,},
			{frame = 800,A = 0.3,RO = 0,GO = 0,BO = 0.05,},
		},
		[2] = {
			{frame = 0,A = 1,RO = 0.5,GO = 0.5,BO = 0.75,},
			{frame = 100,A = 0.8,RO = 0.25,GO = 0.25,BO = 0.5,},
			{frame = 300,A = 0.6,RO = 0.1,GO = 0.1,BO = 0.25,},
			{frame = 800,A = 0.4,RO = 0,GO = 0,BO = 0.1,},
		},
	},
	Shift_info = {
		{frame = 0,alpha = 0,},
		{frame = 15,alpha = 1,},
		total = 15,
	},
	Teleportinfo = {
		{frame = 0,scale = Vector(0.9,1.1),A1 = 0,offset = Vector(0,0),},
		{frame = 1,scale = Vector(0.9,1.1),A1 = 1,offset = Vector(0,0),},
		{frame = 2,scale = Vector(1.4,0.6),A1 = 0,offset = Vector(0,0),},
		{frame = 3,scale = Vector(1.4,0.6),A1 = 1,offset = Vector(0,0),},
		{frame = 4,scale = Vector(1.8,0.5),A1 = 0,offset = Vector(0,0),},
		{frame = 5,scale = Vector(0.5,2.2),A1 = 1,offset = Vector(0,0),},
		{frame = 6,scale = Vector(0.3,3.0),A1 = 0,offset = Vector(0,-60),},
		{frame = 7,scale = Vector(0.1,8.0),A1 = 1,offset = Vector(0,-150),},
		{frame = 8,scale = Vector(0,1),A1 = 0,offset = Vector(0,-300),},
		total = 8,
	},
	Item_Desc = {
		["zh"] = {
			[0] = "{{ColorBlue}}目前无法拾取{{CR}}",
			[1] = "{{ColorGray}}拾取后效果持续一层{{CR}}",
			[2] = "可以正常拾取",
			Special = {
				["MaxHeart"] = "不获得{{EmptyHeart}}心之容器",
				["Heart"] = "改为治疗1{{Heart}}红心",
				["SoulHeart"] = "改为+1{{SoulHeart}}魂心",
				["BlackHeart"] = "改为+1{{BlackHeart}}黑心",
				["Key"] = function(num) return "改为+"..tostring(num).."{{Key}}钥匙，但下层失去"..tostring(num).."{{Key}}钥匙" end,
				["Coin"] = function(num) return "改为+"..tostring(num).."{{Coin}}硬币，但下层失去"..tostring(num).."{{Coin}}硬币" end,
				["Bomb"] = function(num) return "改为+"..tostring(num).."{{Bomb}}炸弹，但下层失去"..tostring(num).."{{Bomb}}炸弹" end,
				["Init"] = "并获得如下额外效果：",
			},
			Other = {
				[CollectibleType.COLLECTIBLE_BOX] = "生成一个随机掉落物",
				[CollectibleType.COLLECTIBLE_PAGEANT_BOY] = "只生成一枚{{Coin}}金币",
				[CollectibleType.COLLECTIBLE_MOMS_COIN_PURSE] = "只生成一枚{{Pill}}药丸",
				[CollectibleType.COLLECTIBLE_EXPERIMENTAL_TREATMENT] = "随机提升1项属性直到下层",
				[CollectibleType.COLLECTIBLE_BATTERY_PACK] = "只生成一个{{Battery}}电池",
				[CollectibleType.COLLECTIBLE_CONSOLATION_PRIZE] = "只生成一份{{Coin}}硬币、{{Key}}钥匙、{{Bomb}}炸弹三选一掉落物",
			},
		},
		["en"] = {
			[0] = "{{ColorBlue}}Currently unable to pickup{{CR}}",
			[1] = "{{ColorGray}}Lasts for one level after pickup{{CR}}",
			[2] = "Can be picked up normally",
			Special = {
				["Heart"] = "Gain 1 red heart",
				["SoulHeart"] = "Gain 1 soul heart",
				["BlackHeart"] = "Gain 1 black heart",
				["Key"] = function(num) 
					if num == 1 then return "Gain "..tostring(num).."{{Key}} key, but lose it next level."
					else return "Gain "..tostring(num).."{{Key}} keys, but lose them next level." end end,
				["Coin"] = function(num) 
					if num == 1 then return "Gain "..tostring(num).."{{Coin}} coin, but lose it next level."
					else return "Gain "..tostring(num).."{{Coin}} coins, but lose them next level." end end,
				["Bomb"] = function(num) 
					if num == 1 then return "Gain "..tostring(num).."{{Bomb}} bomb, but lose it next level."
					else return "Gain "..tostring(num).."{{Bomb}} bombs, but lose them next level." end end,
				["Init"] = "and gain：",
			},
			Other = {
				[CollectibleType.COLLECTIBLE_BOX] = "Generate a random pickup",
				[CollectibleType.COLLECTIBLE_PAGEANT_BOY] = "Generate a {{Coin}} coin",
				[CollectibleType.COLLECTIBLE_MOMS_COIN_PURSE] = "Generate a {{Pill}} pill",
				[CollectibleType.COLLECTIBLE_EXPERIMENTAL_TREATMENT] = "Randomly increase 1 stats until next floor",
				[CollectibleType.COLLECTIBLE_BATTERY_PACK] = "Generate only 1 {{Battery}} battery",
				[CollectibleType.COLLECTIBLE_CONSOLATION_PRIZE] = "Generate only one {{Coin}} coin, {{Key}} key, and {{Bomb}} bomb that can be picked one out of three",
			},
		},
	},
	Item_Checker = {
		["AddMaxHearts"] = {name = "MaxHeart",},
		["AddHearts"] = {name = "Heart",Special = function(player,val)
			player:AddHearts(2)
		end,},	--checker = function(val,config) if config.AddHearts - config.AddMaxHearts == 2 then return true end end,},
		["AddSoulHearts"] = {name = "SoulHeart",checker = function(val) if val == 2 then return true end end,Special = function(player,val)
			auxi.add_soul_heart(player,2)
		end,},
		["AddBlackHearts"] = {name = "BlackHeart",checker = function(val) if val == 2 then return true end end,Special = function(player,val)
			player:AddBlackHearts(2)
		end,},
		["AddBombs"] = {name = "Bomb",Special = function(player,val,item)
			player:AddBombs(val)
			save.elses[item.own_key.."Bomb"] = (save.elses[item.own_key.."Bomb"] or 0) + val
		end,},
		["AddKeys"] = {name = "Key",Special = function(player,val,item)
			player:AddKeys(val)
			save.elses[item.own_key.."Key"] = (save.elses[item.own_key.."Key"] or 0) + val
		end,},
		["AddCoins"] = {name = "Coin",Special = function(player,val,item)
			player:AddCoins(val)
			save.elses[item.own_key.."Coin"] = (save.elses[item.own_key.."Coin"] or 0) + val
		end,},
	},
	Special_items = {
		[CollectibleType.COLLECTIBLE_TREASURE_MAP] = function(player)
			Game():GetLevel():ApplyMapEffect()
		end,
		[CollectibleType.COLLECTIBLE_COMPASS] = function(player)
			Game():GetLevel():ApplyCompassEffect()
		end,
		[CollectibleType.COLLECTIBLE_BLUE_MAP] = function(player)
			Game():GetLevel():ApplyBlueMapEffect()
		end,
		[CollectibleType.COLLECTIBLE_MIND] = function(player)
			local level = Game():GetLevel()
			level:ApplyBlueMapEffect()
			level:ApplyCompassEffect()
			level:ApplyMapEffect()
		end,
		[CollectibleType.COLLECTIBLE_EXPERIMENTAL_TREATMENT] = function(player,item)
			save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
			local idx = player:GetData().__Index
			save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
			local rnd = auxi.choose(1,2,3,4,5)
			save.elses[item.own_key.."buff"][idx][rnd] = (save.elses[item.own_key.."buff"][idx][rnd] or 0) + 1
			player:AddCacheFlags(CacheFlag.CACHE_ALL)
			player:GetData().should_evaluate_on_update_once = true
		end,
		[CollectibleType.COLLECTIBLE_BATTERY_PACK] = function(player)
			local room = Game():GetRoom()
			local q = Isaac.Spawn(5,90,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
		end,
		[CollectibleType.COLLECTIBLE_BOX] = function(player)
			local room = Game():GetRoom()
			local q = Isaac.Spawn(5,0,3,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
		end,
		[CollectibleType.COLLECTIBLE_PAGEANT_BOY] = function(player)
			local room = Game():GetRoom()
			local q = Isaac.Spawn(5,20,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
		end,
		[CollectibleType.COLLECTIBLE_MOMS_COIN_PURSE] = function(player)
			local room = Game():GetRoom()
			local q = Isaac.Spawn(5,70,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
		end,
		[CollectibleType.COLLECTIBLE_CONSOLATION_PRIZE] = function(player)
			local room = Game():GetRoom()
			local infos = {
				[1] = {vr = 20,st = 1,},
				[2] = {vr = 30,st = 1,},
				[3] = {vr = 40,st = 1,},
			}
			local free_pos = room:FindFreePickupSpawnPosition(player.Position,10,true)
			local ndx = option_index_holder.find_a_new_index()
			local nidx = math.random(360)
			for j = 1,3 do
				local info = infos[j]
				local q = Isaac.Spawn(5,info.vr,info.st,free_pos + auxi.MakeVector(j * 360/3 + nidx) * 5,Vector(0,0),player):ToPickup()
				q:Morph(5,info.vr,info.st,true,true,true)
				q.OptionsPickupIndex = ndx
			end
		end,
	},
	buffs = {
		[1] = {name = "speed",cache = CacheFlag.CACHE_SPEED,
			toget = function(player) return player.MoveSpeed end,mul = 0.05,},
		[2] = {name = "tear",cache = CacheFlag.CACHE_FIREDELAY,
			toget = function(player) return 30 / (player.MaxFireDelay + 1) end,mul = 0.15,},
		[3] = {name = "damage",cache = CacheFlag.CACHE_DAMAGE,
			toget = function(player) return player.Damage end,mul = 0.5,},
		[4] = {name = "range",cache = CacheFlag.CACHE_RANGE,
			toget = function(player) return player.TearRange end,mul = 1 * 40,},
		[5] = {name = "luck",cache = CacheFlag.CACHE_LUCK,
			toget = function(player) return player.Luck end,mul = 1,},
	},
}

-- 与原版死亡证明填充一致：跳过 Hidden / 本模组 banished / 贪婪禁项 / 未解锁或被 tag 屏蔽
local function dc_skips_collectible(colinfo,id)
	if colinfo == nil then return true end
	if colinfo.Hidden == true then return true end
	if item.banished[id] then return true end
	if Game():IsGreedMode() and colinfo.Tags & ItemConfig.TAG_NO_GREED == ItemConfig.TAG_NO_GREED then
		return true
	end
	-- IsAvailable：未解锁，或本局被 item tag 屏蔽（挑战/贪婪等）
	if not colinfo:IsAvailable() then return true end
	return false
end

function item.next_item(id,params)
	params = params or {}
	local config = Isaac:GetItemConfig()
	local size = config:GetCollectibles().Size
	id = id + 1
	local colinfo = config:GetCollectible(id)
	while id <= size and dc_skips_collectible(colinfo,id) do
		id = id + 1
		colinfo = config:GetCollectible(id)
	end
	if id >= size and params.no_protect ~= true then return size end
	return id
end

function item.available(id)
	local config = Isaac:GetItemConfig()
	local colinfo = config:GetCollectible(id)
	local size = config:GetCollectibles().Size
	if id > 0 and id <= size and not dc_skips_collectible(colinfo,id) then return true end
	return false
end

function item.prev_item(id,params)
	params = params or {}
	local config = Isaac:GetItemConfig()
	local size = config:GetCollectibles().Size
	id = id - 1
	local colinfo = config:GetCollectible(id)
	while id > 0 and dc_skips_collectible(colinfo,id) do
		id = id - 1
		colinfo = config:GetCollectible(id)
	end
	if id <= 0 and params.no_protect ~= true then return 0 end
	return id
end

-- Real 拾取：REP+ 用 AddCollectible；非 REP+ 保持 QueueItem
function item.give_collectible(player,colinfo,charge,touched)
	if not colinfo then return end
	charge = charge or 0
	touched = touched or false
	if auxi.REPENTENCE_PLUS() then
		player:AddCollectible(colinfo.ID,charge,not touched)
	else
		player:QueueItem(colinfo,charge,touched)
	end
end

function item.check_special_effect(id,player)
	local config = Isaac:GetItemConfig():GetCollectible(id)
	for u,v in pairs(item.Item_Checker) do
		local val = config[u] or 0
		if val > 0 then
			auxi.check_if_any(v.Special,player,val,item)
		end
	end
	auxi.check_if_any(item.Special_items[id],player,item)
end

function item.check_special_info(id)
	local language = Options.Language 
	if item.Item_Desc[language] == nil then language = "zh" end
	local info = item.Item_Desc[language].Special
	local config = Isaac:GetItemConfig():GetCollectible(id)
	local ret = ""
	for u,v in pairs(item.Item_Checker) do
		local val = config[u] or 0
		if val > 0 and auxi.check_if_any(v.checker,val,config) ~= true then
			ret = ret .. "#{{ColorGray}}" .. auxi.check_if_any(info[v.name],val) .. "{{CR}}"
		end
	end
	local postfix = auxi.check_if_any(item.Item_Desc[language].Other[id],player)
	if postfix then ret = ret .. "#{{ColorGray}}" .. postfix .. "{{CR}}" end
	if ret ~= "" then ret = "{{ColorGray}}".. info.Init .. "{{CR}}" .. ret end
	return ret
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local idx = player:GetData().__Index
	if save.elses[item.own_key.."buff"] and save.elses[item.own_key.."buff"][idx] then
		local mul = save.elses[item.own_key.."buff"][idx]
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + (mul[1] or 0) * item.buffs[1].mul
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * (mul[2] or 0) * item.buffs[2].mul)
		end
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * (mul[3] or 0) * item.buffs[3].mul
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + (mul[4] or 0) * item.buffs[4].mul
		end
		if cacheFlag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + (mul[5] or 0) * item.buffs[5].mul
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if player:GetPlayerType() == item.entity then
		local d = player:GetData()
		local s = player:GetSprite()
		if d[item.own_key.."Sprite"] then
			d[item.own_key.."Sprite"].counter = (d[item.own_key.."Sprite"].counter or 45) - 1
			if (d[item.own_key.."Sprite"].counter or 0) < 0 then
				local q = Isaac.Spawn(1000,enums.Entities.ZeistosHelper,0,player.Position,Vector(0,0),nil)
				q:GetData()[item.own_key.."Teleporter"] = {}
				q.DepthOffset = 20
				q.PositionOffset = Vector(0,player.SpriteScale.Y * -40)
				auxi.copy_sprite(d[item.own_key.."Sprite"].s,q:GetSprite())
				auxi.illustrate_sprite_(d[item.own_key.."Sprite"].info,q:GetSprite())
				d[item.own_key.."Sprite"] = nil
			end
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if player:GetPlayerType() == item.entity then
	end
end,
})

function item.get_item_range(player)
	player = player or item.get_zeis()
	return 150
end

function item.get_fake_counter(player)
	if auxi.has_have_coll(player,619) then return 2 end
	return 1
end

function item.check_linker(e1,e2)
	local st = e1.SubType
	save.elses[item.own_key.."Record"] = save.elses[item.own_key.."Record"] or {}
	if save.elses[item.own_key.."Record"][st] and (save.elses[item.own_key.."Record"][st].Real or 0) - (save.elses[item.own_key.."Record"][st].Fkcounter or 0) > 0 then
		if (e1.Position - e2.Position):Length() <= item.get_item_range() then return true end
	end
	return false
end

function item.get_zeis()
	for playerNum = 1,Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player:GetPlayerType() == item.entity then return player end
	end
end

function item.specialize(player)
	local idx = player:GetData().__Index
	save.elses[item.own_key.."First"] = save.elses[item.own_key.."First"] or {}
	local level = Game():GetLevel()
	if save.elses[item.own_key.."First"][idx] == nil and (level:GetStage() == 1 and level:GetStageType() <= 2 or auxi.has_have_coll(player,619)) then return true end
end

function item.is_active(ent)
	local colinfo = Isaac.GetItemConfig():GetCollectible(ent.SubType)
	-- 未解锁与 Hidden 同等对待：不参与 Zeis 链接/首抽等特殊逻辑
	return colinfo and colinfo.Type ~= ItemType.ITEM_ACTIVE and colinfo.Hidden ~= true and colinfo:IsAvailable()
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	local level = Game():GetLevel()
	if item.get_zeis() and level:GetStage() == 1 and level:GetStageType() <= 2 then
		local player = item.get_zeis()
		player:UseActiveItem(CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE, UseFlag.USE_NOANIM)
		player:StopExtraAnimation()
		delay_buffer.addeffe(function(params)
			local level = Game():GetLevel()
			if level:GetStage() == 1 and level:GetStageType() <= 2 then
				if auxi.GetDimension() ~= 2 then
					Room_holder.Trans_to(80,Direction.NO_DIRECTION,RoomTransitionAnim.MINECART,player,2,{On_Arrive = function() 
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = Game():GetRoom():GetCenterPos()
							player:PlayExtraAnimation("Appear")
							player:AddControlsCooldown(30)
						end
						local q = player_All.spawn_desc_info(item.entity,{pos = Game():GetRoom():GetGridPosition(auxi.choose(51,66,81)),})
						if auxi.check_all_exists(q) then
							q:GetSprite().Rotation = -90
						end
					end,})
				else
					local q = player_All.spawn_desc_info(item.entity,{pos = Game():GetRoom():GetGridPosition(auxi.choose(51,66,81)),})
					if auxi.check_all_exists(q) then
						local s = q:GetSprite()
						s.Rotation = -90
						s.Color = Color(1,1,1,0.8,-0.4,-0.4,0)
					end
				end
			end
		end,{},1)
	end
	save.elses[item.own_key.."Zeis_curse"] = nil
	save.elses[item.own_key.."First"] = nil
	save.elses[item.own_key.."buff"] = nil
	local player = Game():GetPlayer(0)
	if save.elses[item.own_key.."Bomb"] then player:AddBombs(-save.elses[item.own_key.."Bomb"]) save.elses[item.own_key.."Bomb"] = nil end
	if save.elses[item.own_key.."Key"] then player:AddKeys(-save.elses[item.own_key.."Key"]) save.elses[item.own_key.."Key"] = nil end
	if save.elses[item.own_key.."Coin"] then player:AddCoins(-save.elses[item.own_key.."Coin"]) save.elses[item.own_key.."Coin"] = nil end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 100,priority = -100,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	if player and player:GetPlayerType() == item.entity then
		local d = ent:GetData()
		local d2 = player:GetData()
		local idx = d2.__Index
		local st = ent.SubType
		local colinfo = Isaac.GetItemConfig():GetCollectible(ent.SubType)
		if auxi.GetDimension() == 2 and ent.OptionsPickupIndex == 1 then
			-- 未解锁 / Hidden：不拦截，交给原版拾取
			if not colinfo or colinfo.Hidden == true or not colinfo:IsAvailable() then
				return
			end
			if auxi.will_pick_up(player,ent) then
				save.elses[item.own_key.."Record"] = save.elses[item.own_key.."Record"] or {}
				save.elses[item.own_key.."Record"][st] = save.elses[item.own_key.."Record"][st] or {}
				local succ = {Val = false,Real = false,}
				local tinfo = save.elses[item.own_key.."Record"][st]
				for i = 1,1 do 
					if (tinfo.Real or 0) - (tinfo.Fkcounter or 0) > 0 then succ.Val = true succ.Real = true tinfo.Real = tinfo.Real - 1 break end
					if (tinfo.counter or 0) < item.get_fake_counter(player) and auxi.check_all_exists(d[item.own_key.."Linker"]) and item.check_linker(d[item.own_key.."Linker"],ent) then
						local ttinfo = save.elses[item.own_key.."Record"][d[item.own_key.."Linker"].SubType]
						ttinfo.Fkcounter = (ttinfo.Fkcounter or 0) + 1
						succ.Val = true break
					end
					if item.is_active(ent) and item.specialize(player) then save.elses[item.own_key.."First"][idx] = true succ.Val = true break end
				end
				if succ.Val == true then
					player:AnimateCollectible(st,"Pickup","PlayerPickupSparkle")
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2)
					if succ.Real == true then
						if colinfo.Type == ItemType.ITEM_ACTIVE and auxi.would_replace_active(player) then
							local actid = player:GetActiveItem(0)
							save.elses[item.own_key.."Record"] = save.elses[item.own_key.."Record"] or {}
							save.elses[item.own_key.."Record"][actid] = save.elses[item.own_key.."Record"][actid] or {}
							local tinfo = save.elses[item.own_key.."Record"][actid]
							tinfo.Real = (tinfo.Real or 0) + 1
							tinfo.Detail = tinfo.Detail or {}
							table.insert(tinfo.Detail,#tinfo.Detail + 1,{charge = player:GetActiveCharge(0) + player:GetBatteryCharge(0),touched = true,})
							d2[item.own_key.."Sprite"] = {s = auxi.copy_sprite(ent:GetSprite()),info = {Type = 5,Variant = 100,SubType = actid,},}
							item.mark_dc_map_dirty()
							item.check_room()
						end
						if (tinfo.Detail or {})[1] then
							item.give_collectible(
								player,
								colinfo,
								tinfo.Detail[1].charge or ent.Charge,
								tinfo.Detail[1].touched or ent.Touched
							)
							table.remove(tinfo.Detail, 1)
						else
							item.give_collectible(player,colinfo,ent.Charge,ent.Touched)
						end
						item_displaying_holder.display_item(player,st)
					else
						tinfo.counter = (tinfo.counter or 0) + 1
						save.elses[item.own_key.."Imitate"] = save.elses[item.own_key.."Imitate"] or {}
						save.elses[item.own_key.."Imitate"][idx] = save.elses[item.own_key.."Imitate"][idx] or {}
						save.elses[item.own_key.."Imitate"][idx][st] = (save.elses[item.own_key.."Imitate"][idx][st] or 0) + 1
						Imitate_item_holder.Evaluate_Imitate_Items(player)
						item_displaying_holder.display_item(player,st)
						item.check_special_effect(st,player)
					end
					d[item.own_key.."Colli"] = {}
					if item.refresh_dc_pickup_visuals then item.refresh_dc_pickup_visuals() end
				end
			end
			if d[item.own_key.."Colli"] then return false
			else return true end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 100,priority = -80,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	if player and player:GetPlayerType() == item.entity then
		local d = ent:GetData()
		local d2 = player:GetData()
		local idx = d2.__Index
		local st = ent.SubType
		local colinfo = Isaac.GetItemConfig():GetCollectible(ent.SubType)
		if auxi.GetDimension() == 2 and ent.OptionsPickupIndex == 1 then
		else
			if colinfo and (colinfo.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST and colinfo.Hidden ~= true and colinfo:IsAvailable() and not item.banished[st]) and auxi.may_pick_up(player,ent) and ent.SubType < 2^31 then
				if not d[item.own_key.."effect"] and auxi.can_buy(ent,player) then
					if ent.Price ~= 0 then 
						auxi.buy_a_pickup(ent,player,{NoAnim = true,}) 
						player:AnimatePickup(ent:GetSprite())
						d2[item.own_key.."Sprite"] = {s = auxi.copy_sprite(ent:GetSprite()),info = {Type = 5,Variant = 100,SubType = ent.SubType,B = auxi.isBlindPickup(ent),},}
					else
						local q = Isaac.Spawn(1000,enums.Entities.ZeistosHelper,0,ent.Position,Vector(0,0),nil)
						q:GetData()[item.own_key.."Teleporter"] = {}
						auxi.copy_sprite(ent:GetSprite(),q:GetSprite())
						auxi.illustrate_sprite(ent,q:GetSprite())
					end
					if auxi.can_start_ambush(ent) then auxi.try_start_ambush() end
					card_06r_lover.try_take_on_lover(player,ent)
					auxi.remove_others_option_pickup(ent)
					d[item.own_key.."effect"] = {}
					save.elses[item.own_key.."Record"] = save.elses[item.own_key.."Record"] or {}
					save.elses[item.own_key.."Record"][st] = save.elses[item.own_key.."Record"][st] or {}
					local tinfo = save.elses[item.own_key.."Record"][st]
					tinfo.Real = (tinfo.Real or 0) + 1
					if ent.Touched == true then 
						tinfo.Detail = tinfo.Detail or {}
						table.insert(tinfo.Detail,#tinfo.Detail + 1,{charge = ent.Charge,touched = ent.Touched,})
					end
					auxi.safely_remove(ent)
					if auxi.GetDimension() == 2 then
						item.mark_dc_map_dirty()
						item.check_room()
						if item.refresh_dc_pickup_visuals then item.refresh_dc_pickup_visuals() end
					end
				end
				if d[item.own_key.."Colli"] then return false
				else return true end
			else 
				if auxi.will_pick_up(player,ent) and st == 628 and auxi.can_buy(ent,player) then
					if ent.Price ~= 0 then auxi.buy_a_pickup(ent,player,{NoAnim = true,}) end
					if auxi.can_start_ambush(ent) then auxi.try_start_ambush() end
					card_06r_lover.try_take_on_lover(player,ent)
					auxi.remove_others_option_pickup(ent)
					player:AnimateCollectible(st,"Pickup","PlayerPickupSparkle")
					player:SetPocketActiveItem(st,2,false)
					save.elses[item.own_key.."Death_C"] = true
					auxi.safely_remove(ent)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local player = item.get_zeis()
	if player then
		local room = Game():GetRoom()
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		local level = Game():GetLevel()
		if auxi.GetDimension() == 2 and desc.SafeGridIndex == 80 and not room:IsFirstVisit() then
			local q = card_01_wizard.spawn_a_fool_port(room:GetCenterPos(),{On_Arrive = function() 
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					local current_room = Game():GetRoom()
					local center = current_room:GetCenterPos()
					local bottom_right = current_room:GetBottomRightPos()
					player.Position = Vector(center.X,(center.Y + bottom_right.Y) * 0.5)
					player:PlayExtraAnimation("Appear")
					player:AddControlsCooldown(30)
				end
			end,})
		end
		if (auxi.has_have_coll(player,619) or room:IsFirstVisit()) and auxi.GetDimension() == 0 and desc.SafeGridIndex == 84 then
			local center = room:GetCenterPos()
			local top_left = room:GetTopLeftPos()
			local portal_position = Vector(center.X,(center.Y + top_left.Y) * 0.5)
			local q = card_01_wizard.spawn_a_fool_port(portal_position,{info = {id = -1,tp = 119,gidx = 80,dim = 2,},Special = function(player,info)
				player:UseActiveItem(CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE, UseFlag.USE_NOANIM)
				player:StopExtraAnimation()
			end,On_Arrive = function() 
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					player.Position = Game():GetRoom():GetCenterPos()
					player:PlayExtraAnimation("Appear")
					player:AddControlsCooldown(30)
				end
			end,})
		end
		if auxi.GetDimension() == 2 then
			local curse = level:GetCurses()
			if curse & (1<<2) == (1<<2) then
				save.elses[item.own_key.."Zeis_curse"] = true
				level:RemoveCurses(1<<2)
			end
		elseif save.elses[item.own_key.."Zeis_curse"] then
			save.elses[item.own_key.."Zeis_curse"] = nil
			level:AddCurse(1<<2,false)
		end
	end
end,
})
--l local card_01_wizard = require("Qing_Remaster_scripts.cards.Card_01_Wizard") card_01_wizard.spawn_a_fool_port(Vector(200,200))
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."Imitate"] = nil
	save.elses[item.own_key.."Aim"] = nil
	if save.elses[item.own_key.."Record"] then
		for u,v in pairs(save.elses[item.own_key.."Record"]) do
			for uu,vv in pairs(v) do
				v.Fkcounter = nil
			end
		end
	end
	if save.elses[item.own_key.."Death_C"] then
		local player = item.get_zeis()
		player:SetPocketActiveItem(628,2,false)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, params = nil,
Function = function(_,tp,vr,st,gidx,seed)
	local room = Game():GetRoom()
	if auxi.have_player(item.entity) and auxi.GetDimension() == 2 then
		if tp == 5 then
			if vr ~= 20 then return {1940,0,0,}	--{999,enums.Entities.Remover,0,}
			else return {5,20,1,} end
		end
	end
end,
})

-- 小地图标记用；仅在 Record 变化或进房时重算（避免大房间每次拾取都全图扫）
item._dc_map_dirty = true
function item.mark_dc_map_dirty()
	item._dc_map_dirty = true
end

function item.check_room(force)
	if not force and not item._dc_map_dirty then return end
	item._dc_map_dirty = false
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local tbl = {}
	local cnt = 0
	for i = 1, rooms.Size do
		local targ = rooms:Get(i - 1)
		if auxi.GetDimension(targ) == 2 then
			tbl[#tbl + 1] = targ
		end
	end
	local sgid = level:GetCurrentRoomDesc().SafeGridIndex
	local record = save.elses[item.own_key.."Record"] or {}
	for _,v in ipairs(tbl) do
		local spawns = v.Data.Spawns
		local sz = spawns.Size
		local succ = false
		local work = false
		local ddesc = level:GetRoomByIdx(v.SafeGridIndex)
		for i = 1,sz do
			local entinfo = spawns:Get(i - 1):PickEntry(0)
			if entinfo.Type == 5 and entinfo.Variant == 100 and entinfo.Subtype == 0 then
				cnt = item.next_item(cnt)
				work = true
				local info = record[cnt] or {}
				if (info.Real or 0) - (info.Fkcounter or 0) > 0 then succ = true end
			end
		end
		if work then
			if succ then
				ddesc.DisplayFlags = 5
				ddesc.Clear = true
				ddesc.VisitedCount = 1
			else
				if ddesc.SafeGridIndex ~= sgid then ddesc.Clear = false end
				ddesc.VisitedCount = 0
			end
		end
	end
	level:UpdateVisibility()
end

--[=[ DC prediction/compare diagnostics (disabled; kept for reference)
-- ===== 死亡证明层：预测 vs 实际道具对照日志 =====
item.enable_dc_room_log = true

local function dc_json_escape(s)
	return tostring(s):gsub("\\","\\\\"):gsub("\"","\\\""):gsub("\n","\\n")
end

local function dc_encode_row(tbl)
	local parts = {}
	local keys = {}
	for k in pairs(tbl) do keys[#keys + 1] = k end
	table.sort(keys,function(a,b) return tostring(a) < tostring(b) end)
	for _,k in ipairs(keys) do
		local v = tbl[k]
		if type(v) == "number" then
			parts[#parts + 1] = string.format("\"%s\":%s",k,(v == math.floor(v)) and tostring(math.floor(v)) or string.format("%.4f",v))
		elseif type(v) == "boolean" then
			parts[#parts + 1] = string.format("\"%s\":%s",k,v and "true" or "false")
		elseif type(v) == "table" then
			local inner = {}
			for i,x in ipairs(v) do
				if type(x) == "number" then inner[i] = tostring(x)
				elseif type(x) == "table" then
					local bits = {}
					for kk,vv in pairs(x) do
						bits[#bits + 1] = tostring(kk).."="..tostring(vv)
					end
					inner[i] = "\""..dc_json_escape(table.concat(bits,";")).."\""
				else inner[i] = "\""..dc_json_escape(x).."\"" end
			end
			parts[#parts + 1] = string.format("\"%s\":[%s]",k,table.concat(inner,","))
		elseif v == nil then
			parts[#parts + 1] = string.format("\"%s\":null",k)
		else
			parts[#parts + 1] = string.format("\"%s\":\"%s\"",k,dc_json_escape(v))
		end
	end
	return "{"..table.concat(parts,",").."}"
end

local function dc_append_log(row)
	if not dev_env.probes_allowed() then return end
	if not item.enable_dc_room_log then return end
	row.game_frame = Game():GetFrameCount()
	row.seed = Game():GetSeeds():GetStartSeed()
	local line = dc_encode_row(row)
	Isaac.DebugString("[Qing Zeis DC] "..line)
	print("[Qing Zeis DC] "..line)
	pcall(function()
		if not io or not io.open then return end
		local paths = {
			"mods/Qing_remaster/codex_work/logs/zeis_dc_rooms.jsonl",
			"../mods/Qing_remaster/codex_work/logs/zeis_dc_rooms.jsonl",
		}
		for _,path in ipairs(paths) do
			local ok,f = pcall(io.open,path,"a")
			if ok and f then
				f:write(line.."\n")
				f:close()
				return
			end
		end
	end)
end

local function dc_collectible_name(id)
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	return (cfg and cfg.Name) or ("#"..tostring(id))
end

-- FF 道具 ID 区间（成就系统可能动态改 Hidden，运行时再扫一遍）
local function dc_ff_id_range()
	local FF = rawget(_G,"FiendFolio")
	local mn,mx = nil,nil
	if FF and FF.ITEM and type(FF.ITEM.COLLECTIBLE) == "table" then
		for _,id in pairs(FF.ITEM.COLLECTIBLE) do
			if type(id) == "number" and id > 0 then
				mn = mn and math.min(mn,id) or id
				mx = mx and math.max(mx,id) or id
			end
		end
	end
	return mn,mx
end

local function dc_ids_hit_range(ids,mn,mx)
	if not mn or not mx or not ids then return false end
	for _,id in ipairs(ids) do
		if id >= mn and id <= mx then return true end
	end
	return false
end

local function dc_ff_hidden_stats(mn,mx)
	local visible,hidden,missing = 0,0,0
	local FF = rawget(_G,"FiendFolio")
	if not (FF and FF.ITEM and FF.ITEM.COLLECTIBLE) then
		return {visible = 0,hidden = 0,missing = 0,note = "FiendFolio global missing"}
	end
	local seen = {}
	for _,id in pairs(FF.ITEM.COLLECTIBLE) do
		if type(id) == "number" and id > 0 and not seen[id] then
			seen[id] = true
			local cfg = Isaac.GetItemConfig():GetCollectible(id)
			if not cfg then
				missing = missing + 1
			elseif cfg.Hidden then
				hidden = hidden + 1
			else
				visible = visible + 1
			end
		end
	end
	return {
		visible = visible,
		hidden = hidden,
		missing = missing,
		ff_min = mn,
		ff_max = mx,
		inaba_hidden_flag = FF.InabaUnlocksHidden == true,
	}
end

-- 按与 check_room 相同的过滤收集 dim2 房间；返回 ipairs 顺序表 + GetRooms 原始下标
local function dc_collect_dim2_rooms()
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local tbl = {}
	for i = 1,rooms.Size do
		local targ = rooms:Get(i - 1)
		if auxi.GetDimension(targ) == 2 then
			tbl[#tbl + 1] = {
				desc = targ,
				rooms_get_index = i - 1,
				safe = targ.SafeGridIndex,
				grid = targ.GridIndex,
				list = targ.ListIndex,
			}
		end
	end
	return tbl
end

-- 对一张房间描述扫 Spawns，按 next_item 推进 cnt，返回本房预测道具列表与新 cnt
local function dc_scan_room_spawns(room_desc,cnt)
	local predicted = {}
	local spawns = room_desc.Data and room_desc.Data.Spawns
	if not spawns then return predicted,cnt end
	local sz = spawns.Size or 0
	for i = 1,sz do
		local spawn = spawns:Get(i - 1)
		local entinfo = spawn:PickEntry(0)
		if entinfo.Type == 5 and entinfo.Variant == 100 and entinfo.Subtype == 0 then
			cnt = item.next_item(cnt)
			predicted[#predicted + 1] = {
				id = cnt,
				name = dc_collectible_name(cnt),
				spawn_i = i - 1,
				sx = spawn.X,
				sy = spawn.Y,
			}
		end
	end
	return predicted,cnt
end

function item.build_dc_prediction_map(order_mode)
	local tbl = dc_collect_dim2_rooms()
	if order_mode == "list" then
		table.sort(tbl,function(a,b) return a.list < b.list end)
	elseif order_mode == "safe" then
		table.sort(tbl,function(a,b) return a.safe < b.safe end)
	elseif order_mode == "grid" then
		table.sort(tbl,function(a,b) return a.grid < b.grid end)
	end
	local cnt = 0
	local by_safe = {}
	local ordered = {}
	for ord,info in ipairs(tbl) do
		local predicted
		predicted,cnt = dc_scan_room_spawns(info.desc,cnt)
		local ids = {}
		for _,p in ipairs(predicted) do ids[#ids + 1] = p.id end
		local entry = {
			ord = ord,
			rooms_get_index = info.rooms_get_index,
			safe = info.safe,
			grid = info.grid,
			list = info.list,
			predicted = predicted,
			ids = ids,
			order_mode = order_mode or "rooms",
		}
		ordered[#ordered + 1] = entry
		by_safe[info.safe] = entry
	end
	return ordered,by_safe,cnt
end

local function dc_actual_collectibles_in_room()
	local out = {}
	for _,ent in ipairs(Isaac.FindByType(5,100,-1,false,false)) do
		local pickup = ent:ToPickup()
		if pickup and pickup.SubType and pickup.SubType > 0 then
			out[#out + 1] = {
				id = pickup.SubType,
				name = dc_collectible_name(pickup.SubType),
				opt = pickup.OptionsPickupIndex or 0,
				x = math.floor(pickup.Position.X + 0.5),
				y = math.floor(pickup.Position.Y + 0.5),
				gi = Game():GetRoom():GetGridIndex(pickup.Position),
			}
		end
	end
	table.sort(out,function(a,b)
		if a.gi ~= b.gi then return a.gi < b.gi end
		return a.id < b.id
	end)
	return out
end

local function dc_ids_equal(a,b)
	if #a ~= #b then return false end
	local ca,cb = {},{}
	for _,id in ipairs(a) do ca[id] = (ca[id] or 0) + 1 end
	for _,id in ipairs(b) do cb[id] = (cb[id] or 0) + 1 end
	for id,n in pairs(ca) do if (cb[id] or 0) ~= n then return false end end
	for id,n in pairs(cb) do if (ca[id] or 0) ~= n then return false end end
	return true
end

-- 只摘要「预测 ID 落在 FF 段」的房间
local function dc_summarize_ff_rooms(ordered,ff_min,ff_max)
	local summary = {}
	for _,e in ipairs(ordered) do
		if dc_ids_hit_range(e.ids,ff_min,ff_max) then
			summary[#summary + 1] = string.format(
				"#%d safe=%d list=%d n=%d first=%s last=%s ids=[%s]",
				e.ord,e.safe,e.list,#e.ids,
				tostring(e.ids[1]),tostring(e.ids[#e.ids]),
				table.concat(e.ids,",")
			)
		end
	end
	return summary
end

function item.log_dc_room_compare(tag)
	if not item.enable_dc_room_log then return end
	if not auxi.have_player(item.entity) then return end
	if auxi.GetDimension() ~= 2 then return end

	local ff_min,ff_max = dc_ff_id_range()
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	local ordered,by_safe = item.build_dc_prediction_map("rooms")
	local pred = by_safe[cur.SafeGridIndex]
	local actual = dc_actual_collectibles_in_room()
	local actual_ids = {}
	for _,a in ipairs(actual) do actual_ids[#actual_ids + 1] = a.id end
	local pred_ids = pred and pred.ids or {}

	local touches_ff = dc_ids_hit_range(pred_ids,ff_min,ff_max) or dc_ids_hit_range(actual_ids,ff_min,ff_max)
	-- 无 FF 全局时：用启发式（原版大致 <733）兜底，只打 pred/actual 最大值过线的房
	if not ff_min then
		local cutoff = 733
		local function over(ids)
			for _,id in ipairs(ids or {}) do if id >= cutoff then return true end end
			return false
		end
		touches_ff = over(pred_ids) or over(actual_ids)
		ff_min,ff_max = cutoff,999999
	end

	-- 首次进 DC：FF Hidden 运行时统计（成就会改 ItemConfig.Hidden）
	if not item._dc_ff_stats_logged then
		item._dc_ff_stats_logged = true
		local stats = dc_ff_hidden_stats(ff_min,ff_max)
		stats.event = "dc_ff_hidden_stats"
		stats.tag = tag or "enter"
		dc_append_log(stats)
		-- 只 dump FF 段房间预测
		dc_append_log({
			event = "dc_ff_prediction_slice",
			tag = tag or "enter",
			order_mode = "rooms",
			ff_min = ff_min,
			ff_max = ff_max,
			map = dc_summarize_ff_rooms(ordered,ff_min,ff_max),
		})
	end

	if not touches_ff then return end

	local alt_matches = {}
	for _,mode in ipairs({"rooms","list"}) do
		local _,by2 = item.build_dc_prediction_map(mode)
		local p2 = by2[cur.SafeGridIndex]
		local ids2 = p2 and p2.ids or {}
		alt_matches[#alt_matches + 1] = string.format(
			"%s:match=%s ids=[%s]",
			mode,tostring(dc_ids_equal(ids2,actual_ids)),table.concat(ids2,",")
		)
	end

	local function cfg_avail_str(id)
		local cfg = Isaac.GetItemConfig():GetCollectible(id)
		if not cfg then return "nil" end
		return string.format("H=%s Av=%s",tostring(cfg.Hidden == true),tostring(cfg:IsAvailable()))
	end

	-- 分叉诊断：预测多算 / 实际多算的 ID 的 Hidden+IsAvailable
	local pred_set,act_set = {},{}
	for _,id in ipairs(pred_ids) do pred_set[id] = true end
	for _,id in ipairs(actual_ids) do act_set[id] = true end
	local only_pred,only_act = {},{}
	for _,id in ipairs(pred_ids) do
		if not act_set[id] then only_pred[#only_pred + 1] = id .. ":" .. cfg_avail_str(id) end
	end
	for _,id in ipairs(actual_ids) do
		if not pred_set[id] then only_act[#only_act + 1] = id .. ":" .. cfg_avail_str(id) end
	end

	dc_append_log({
		event = "dc_ff_room_compare",
		tag = tag or "enter",
		cur_safe = cur.SafeGridIndex,
		cur_list = cur.ListIndex,
		ff_min = ff_min,
		ff_max = ff_max,
		pred_ord = pred and pred.ord or -1,
		predicted_ids = pred_ids,
		actual_ids = actual_ids,
		match_rooms_order = dc_ids_equal(pred_ids,actual_ids),
		alt_order_matches = alt_matches,
		only_pred_avail = only_pred,
		only_act_avail = only_act,
	})
end

-- 进房后延迟一帧再对比（等底座生成/Morph 完成）
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if not item.enable_dc_room_log then return end
	if not auxi.have_player(item.entity) then return end
	if auxi.GetDimension() ~= 2 then return end
	delay_buffer.addeffe(function()
		item.log_dc_room_compare("enter")
	end,{},1)
end,
})
]=]

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if auxi.have_player(item.entity) and auxi.GetDimension() == 2 and save.elses[item.own_key.."Record"] then
		item.mark_dc_map_dirty()
		-- 避开进房黑屏过渡帧：延迟再扫全图小地图，避免与底座着色抢同一帧
		delay_buffer.addeffe(function()
			if auxi.GetDimension() == 2 and save.elses[item.own_key.."Record"] then
				item.check_room(true)
			end
		end,{},20)
	end
end,
})
--l print(Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex)
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.ZeistosHelper,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d[item.own_key.."Teleporter"] then
		d[item.own_key.."Teleporter"].counter = (d[item.own_key.."Teleporter"].counter or 0) + 1
		local tinfo = auxi.check_lerp(d[item.own_key.."Teleporter"].counter,item.Teleportinfo)
		s.Scale = tinfo.scale
		local a = tinfo.A1
		s.Color = Color(a,a,a,1,a,a,a)
		s.Offset = tinfo.offset
		if d[item.own_key.."Teleporter"].counter > item.Teleportinfo.total then sound_tracker.PlayStackedSound(SoundEffect.SOUND_HELL_PORTAL2,1,1,false,0,2) ent:Remove() return end
	end
	if d[item.own_key.."Ring"] then
		if auxi.check_all_exists(ent.Parent) then ent.Position = ent.Parent.Position end
		if d[item.own_key.."Ring"].Remove or auxi.check_all_exists(ent.Parent) ~= true or (auxi.check_for_the_same(ent,ent.Parent:GetData()[item.own_key.."Ring"]) ~= true) then
			s.Color = auxi.AddColor(s.Color,Color(1,1,1,0),0.9,0.1)
			if s.Color.A <= 0.05 then ent:Remove() end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	local idx = player:GetData().__Index
	save.elses[item.own_key.."Imitate"] = save.elses[item.own_key.."Imitate"] or {}
	save.elses[item.own_key.."Imitate"][idx] = save.elses[item.own_key.."Imitate"][idx] or {}
	for u,v in pairs(save.elses[item.own_key.."Imitate"][idx]) do value[u] = v end
end,
})

-- 底座上只保留轻量计数；DC 着色/链接改到每帧一次的 POST_UPDATE，避免大房间 O(n^2)
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 100,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."Colli"] then
		d[item.own_key.."Colli"].counter = (d[item.own_key.."Colli"].counter or 0) + 1
		if d[item.own_key.."Colli"].counter > item.Collid_limit then d[item.own_key.."Colli"] = nil end
	end
	if d[item.own_key.."effect"] then
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
	end
end,
})

-- 距离着色：近处精细/lerp，远处粗 LUT
local DC_COLOR_MAX = 800
local DC_NEAR_LERP = 120   -- 此内每帧精确 lerp（通常只有身边几个底座）
local DC_MID_END = 300
local DC_MID_BAND = 40
local DC_FAR_BAND = 40
local DC_COLOR_LUT = nil
local DC_SCREEN_MARGIN = 64 -- 底座精灵略高出脚点，留边避免擦边漏刷

local function dc_band_key(dist)
	if dist <= DC_NEAR_LERP then
		return math.floor(dist * 0.5) * 2 -- 2px 粒度，用于跳过判断
	elseif dist <= DC_MID_END then
		return math.floor(dist / DC_MID_BAND) * DC_MID_BAND
	end
	return math.floor(dist / DC_FAR_BAND) * DC_FAR_BAND
end

local function dc_ensure_color_lut()
	if DC_COLOR_LUT then return end
	DC_COLOR_LUT = {}
	for cid = 0,2 do
		local row = {}
		local info = item.color_info[cid]
		for dist = DC_NEAR_LERP + DC_MID_BAND,DC_MID_END,DC_MID_BAND do
			local t = auxi.check_lerp(dist,info)
			row[dist] = Color(t.R or 1,t.G or 1,t.B or 1,t.A or 1,t.RO or 0,t.GO or 0,t.BO or 0)
		end
		for dist = DC_MID_END + DC_FAR_BAND,DC_COLOR_MAX,DC_FAR_BAND do
			local t = auxi.check_lerp(dist,info)
			row[dist] = Color(t.R or 1,t.G or 1,t.B or 1,t.A or 1,t.RO or 0,t.GO or 0,t.BO or 0)
		end
		-- 边界点
		local t_mid = auxi.check_lerp(DC_MID_END,info)
		row[DC_MID_END] = Color(t_mid.R or 1,t_mid.G or 1,t_mid.B or 1,t_mid.A or 1,t_mid.RO or 0,t_mid.GO or 0,t_mid.BO or 0)
		local t_max = auxi.check_lerp(DC_COLOR_MAX,info)
		row[DC_COLOR_MAX] = Color(t_max.R or 1,t_max.G or 1,t_max.B or 1,t_max.A or 1,t_max.RO or 0,t_max.GO or 0,t_max.BO or 0)
		DC_COLOR_LUT[cid] = row
	end
end

local function dc_color_at(cid,dist)
	if dist < 0 then dist = 0 end
	if dist > DC_COLOR_MAX then dist = DC_COLOR_MAX end
	local key = dc_band_key(dist)
	if dist <= DC_NEAR_LERP then
		local t = auxi.check_lerp(dist,item.color_info[cid])
		return Color(t.R or 1,t.G or 1,t.B or 1,t.A or 1,t.RO or 0,t.GO or 0,t.BO or 0),key
	end
	dc_ensure_color_lut()
	local col = DC_COLOR_LUT[cid][key]
	if not col then
		local t = auxi.check_lerp(key,item.color_info[cid])
		col = Color(t.R or 1,t.G or 1,t.B or 1,t.A or 1,t.RO or 0,t.GO or 0,t.BO or 0)
		DC_COLOR_LUT[cid][key] = col
	end
	return col,key
end

local is_active_cache = {}
local function dc_is_active_cached(pickup)
	local st = pickup.SubType
	local cached = is_active_cache[st]
	if cached ~= nil then return cached end
	local ok = item.is_active(pickup) and true or false
	is_active_cache[st] = ok
	return ok
end

-- 画面判定用渲染坐标（与 Isaac.WorldToScreen 一致）；勿用 HUD 用的 GetScreenSize
local function dc_screen_size()
	if Isaac.GetScreenWidth and Isaac.GetScreenHeight then
		return Isaac.GetScreenWidth(),Isaac.GetScreenHeight()
	end
	local s = auxi.GetScreenSize()
	return s.X,s.Y
end

local function dc_pos_on_screen(pos,screen_w,screen_h,margin)
	local sp = Isaac.WorldToScreen(pos)
	return sp.X >= -margin and sp.Y >= -margin and sp.X <= screen_w + margin and sp.Y <= screen_h + margin
end

-- 会滚屏/超单屏的房间才做画面裁剪；1x1/窄条小房整房刷新
local DC_SCREEN_CULL_SHAPES = {
	[RoomShape.ROOMSHAPE_1x2] = true,
	[RoomShape.ROOMSHAPE_IIV] = true,
	[RoomShape.ROOMSHAPE_2x1] = true,
	[RoomShape.ROOMSHAPE_IIH] = true,
	[RoomShape.ROOMSHAPE_2x2] = true,
	[RoomShape.ROOMSHAPE_LTL] = true,
	[RoomShape.ROOMSHAPE_LTR] = true,
	[RoomShape.ROOMSHAPE_LBL] = true,
	[RoomShape.ROOMSHAPE_LBR] = true,
}

-- 画面外少量轮询：保证滚入前颜色大致跟上，又不抢进房尖峰
local dc_offscreen_cursor = 0
local DC_OFFSCREEN_BATCH = 6

local function zeis_apply_pedestal_visual(pickup,player,record,specialize,fake_limit,range,px,py)
	local d = pickup:GetData()
	local s = pickup:GetSprite()
	local st = pickup.SubType
	local tinfo = record[st] or {}
	local colorid = 0
	if (tinfo.Real or 0) - (tinfo.Fkcounter or 0) > 0 then
		colorid = 2
	elseif d[item.own_key.."Linker"] then
		if (tinfo.counter or 0) < fake_limit then colorid = 1 end
	elseif specialize and dc_is_active_cached(pickup) then
		colorid = 1
	end

	local dx = px - pickup.Position.X
	local dy = py - pickup.Position.Y
	local dist = math.sqrt(dx * dx + dy * dy)
	local base_color,band = dc_color_at(colorid,dist)
	d[item.own_key.."Color_Info"] = d[item.own_key.."Color_Info"] or {}
	local cinfo = d[item.own_key.."Color_Info"]
	local shifting = (cinfo.colorid or -1) ~= colorid or (cinfo.counter or 0) < item.Shift_info.total
	if shifting then
		if (cinfo.colorid or -1) ~= colorid then
			cinfo.counter = 0
			cinfo.colorid = colorid
			cinfo.color = auxi.color2table(s.Color)
		end
		local color = base_color
		if cinfo.color and (cinfo.counter or 0) < item.Shift_info.total then
			local r1 = auxi.check_lerp(cinfo.counter,item.Shift_info).alpha
			color = auxi.AddColor(base_color,cinfo.color,r1,(1 - r1))
			cinfo.counter = (cinfo.counter or 0) + 1
		end
		s.Color = color
		cinfo.band = band
	elseif cinfo.band ~= band then
		s.Color = base_color
		cinfo.band = band
	end

	d[item.own_key.."colorid"] = colorid
	if colorid == 2 then
		if not auxi.check_all_exists(d[item.own_key.."Ring"]) then
			local q = Isaac.Spawn(1000,enums.Entities.ZeistosHelper,0,pickup.Position,Vector(0,0),nil)
			local d2 = q:GetData()
			local s2 = q:GetSprite()
			d2[item.own_key.."Ring"] = {}
			s2:Load("gfx/effects/Halo/Halo_zeis_ring.anm2",true)
			s2:Play("Idle",true)
			s2.Scale = s2.Scale * range / 100
			q.Parent = pickup
			q.SortingLayer = 0
			d[item.own_key.."Ring"] = q
		end
	elseif auxi.check_all_exists(d[item.own_key.."Ring"]) then
		d[item.own_key.."Ring"]:GetData()[item.own_key.."Ring"].Remove = true
		d[item.own_key.."Ring"] = nil
	end
end

-- 光环/可拾取状态相关：必须当帧更新，不能进屏外队列
local function dc_needs_immediate_visual(pickup,d,record,px,py,imm_range_sq,sw,sh,use_screen_cull)
	local tinfo = record[pickup.SubType] or {}
	if (tinfo.Real or 0) - (tinfo.Fkcounter or 0) > 0 then return true end
	if d[item.own_key.."Linker"] then return true end
	if d[item.own_key.."Ring"] then return true end -- 正在消光环也要立刻
	local dx = px - pickup.Position.X
	local dy = py - pickup.Position.Y
	if dx * dx + dy * dy <= imm_range_sq then return true end
	if not use_screen_cull then return true end
	return dc_pos_on_screen(pickup.Position,sw,sh,DC_SCREEN_MARGIN)
end

local function zeis_update_dc_pedestal_visuals()
	if auxi.GetDimension() ~= 2 then return end
	local player = item.get_zeis()
	if not player then return end

	local room = Game():GetRoom()
	local shape = room:GetRoomShape()
	local use_screen_cull = DC_SCREEN_CULL_SHAPES[shape] == true

	local range = item.get_item_range()
	local range_sq = range * range
	-- 比链接半径略大，保证可拾取变色/光环进范围当帧跟上
	local imm_range_sq = (range * 1.5) * (range * 1.5)
	local record = save.elses[item.own_key.."Record"] or {}
	local ents = Isaac.FindByType(5,100,-1,false,false)
	local pedestals = {}
	local sources = {}
	for _,ent in ipairs(ents) do
		local pickup = ent:ToPickup()
		if pickup and pickup.OptionsPickupIndex == 1 then
			pedestals[#pedestals + 1] = pickup
			local tinfo = record[pickup.SubType] or {}
			if (tinfo.Real or 0) - (tinfo.Fkcounter or 0) > 0 then
				sources[#sources + 1] = pickup
			end
		end
	end
	local n = #pedestals
	if n == 0 then return end

	-- Linker：无 Real 源时整段跳过
	if #sources > 0 then
		for _,pickup in ipairs(pedestals) do
			local d = pickup:GetData()
			local linker = d[item.own_key.."Linker"]
			if linker and (not auxi.check_all_exists(linker) or not item.check_linker(linker,pickup)) then
				d[item.own_key.."Linker"] = nil
			end
		end
		for _,src in ipairs(sources) do
			local sp = src.Position
			for _,pickup in ipairs(pedestals) do
				if pickup ~= src then
					local d = pickup:GetData()
					if d[item.own_key.."Linker"] == nil then
						local dx = sp.X - pickup.Position.X
						local dy = sp.Y - pickup.Position.Y
						if dx * dx + dy * dy < range_sq and dc_is_active_cached(pickup) then
							d[item.own_key.."Linker"] = src
						end
					end
				end
			end
		end
	else
		-- Real 全无后清掉残留 Linker，避免可拾取状态卡住
		for _,pickup in ipairs(pedestals) do
			local d = pickup:GetData()
			if d[item.own_key.."Linker"] then d[item.own_key.."Linker"] = nil end
		end
	end

	local specialize = item.specialize(player)
	local fake_limit = item.get_fake_counter(player)
	local px,py = player.Position.X,player.Position.Y
	local sw,sh = dc_screen_size()
	local deferred = {}

	for _,pickup in ipairs(pedestals) do
		local d = pickup:GetData()
		if dc_needs_immediate_visual(pickup,d,record,px,py,imm_range_sq,sw,sh,use_screen_cull) then
			zeis_apply_pedestal_visual(pickup,player,record,specialize,fake_limit,range,px,py)
		else
			deferred[#deferred + 1] = pickup
		end
	end

	-- 其余画面外：每帧少量轮询错峰（仅大房间 cull 时会有）
	local off_n = #deferred
	if off_n > 0 then
		local batch = math.min(DC_OFFSCREEN_BATCH,off_n)
		dc_offscreen_cursor = dc_offscreen_cursor % off_n
		for step = 1,batch do
			local idx = ((dc_offscreen_cursor + step - 1) % off_n) + 1
			zeis_apply_pedestal_visual(deferred[idx],player,record,specialize,fake_limit,range,px,py)
		end
		dc_offscreen_cursor = (dc_offscreen_cursor + batch) % off_n
	end
end

-- Record/拾取变化后立刻刷新光环（不必等下一帧 POST_UPDATE）
function item.refresh_dc_pickup_visuals()
	zeis_update_dc_pedestal_visuals()
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if not auxi.have_player(item.entity) then return end
	zeis_update_dc_pedestal_visuals()
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	if player:GetPlayerType() == item.entity then
		local ret = nil
		local language = Options.Language
		local infos = (item.Special_Des[language] or {})[tp]
		if infos == nil then return end
		local info = infos[id]
		if info == nil then return end
		ret = {Name = info.Name or value.Name,Description = info.Description or value.Description,}
		return ret
	end
end,
})

if EID then
	EID:addDescriptionModifier("qing_player_desc_sync_Zeis", function(desc) local ret = auxi.have_player(item.entity) return ret end, function(desc)
		if auxi.check_all_exists(desc.Entity) and desc.Entity.Type == 5 then
			local ent = desc.Entity
			local language = Options.Language 
			if item.Item_Desc[language] == nil then language = "zh" end
			local info = item.Item_Desc[language]
			local id = ent:GetData()[item.own_key.."colorid"]
            if info and info[id] then
				info = info[id]
				if id == 1 then info = info .. item.check_special_info(desc.Entity.SubType) end
				if string.sub(info,0,1) ~= "#" then info = "#"..info end
                local repl = "#{{Player"..item.entity.."}} "
                info = string.gsub(info, "#", repl)
                EID:appendToDescription(desc, info)
            end
        end
        return desc
	end)
end


if REPENTOGON then

local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
local DOGMA_SHADER = temp_hud.DOGMA_CHROMATIC_SHADER
local STATIC_FLAG = 1 << 5
local GOLD_FLAG = 1 << 7

-- 用自定义 chromatic dogma 替代 AnimRenderFlags.STATIC：
-- 原版 STATIC→coloroffset_dogma 会吃全局 PixelationAmount，房间像素化后偶发残留成马赛克；
-- 自定义 shader 忽略像素化，且对所有非灰阶像素生效（不依赖蓝/绿键色皮肤）。
local function apply_zeis_dogma_sprite(sprite,glitch)
	if not sprite or not sprite.SetCustomShader then return end
	if sprite.GetRenderFlags and sprite.SetRenderFlags then
		local flags = sprite:GetRenderFlags() or 0
		local cleared = flags & ~(STATIC_FLAG | GOLD_FLAG)
		if cleared ~= flags then sprite:SetRenderFlags(cleared) end
	end
	temp_hud.apply_sprite_shader(sprite,DOGMA_SHADER)
	local col = sprite.Color
	local t = temp_hud.dogma_shader_time()
	glitch = glitch or 0
	if col.SetColorize then
		local next_col = Color(col.R,col.G,col.B,col.A,col.RO,col.GO,col.BO)
		next_col:SetColorize(glitch,0,0,t)
		sprite.Color = next_col
	else
		sprite.Color = Color(col.R,col.G,col.B,col.A,col.RO,col.GO,col.BO,glitch,0,0,t)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if player:GetPlayerType() ~= item.entity then return end
	apply_zeis_dogma_sprite(player:GetSprite(),0)
	local desc = player:GetCostumeSpriteDescs()
	for _,v in pairs(desc) do
		apply_zeis_dogma_sprite(v:GetSprite(),0)
	end
end,
})

end

do
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	-- Extra HUD：教条黑白闪烁（chromatic），不再用靛紫 Colorize
	temp_hud.register_provider(function(player)
		local idx = player:GetData() and player:GetData().__Index
		if not idx then return end
		local bag = save.elses[item.own_key.."Imitate"]
		local counts = bag and bag[idx]
		if not counts then return end
		local out = {}
		for id,count in pairs(counts) do
			local cid = tonumber(id)
			local n = tonumber(count) or 0
			if cid and cid > 0 and n > 0 then out[cid] = n end
		end
		return out
	end,{
		dogma_chromatic = true,
		exclusive = true,
		source_icon = "{{Player"..tostring(item.entity).."}}",
	})
end

return item

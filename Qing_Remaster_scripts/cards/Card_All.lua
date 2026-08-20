local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local Cards = enums.Cards
local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	own_key = "Thoth_cd_All_",
	-- 默认出现率：1=保留托特卡；0=映射回原版。旧全局 morph_rate 语义为「替换掉托特卡」概率。
	default_appear_rate = 1,
	announcer = {
		[Cards.Round_trip_Rail_Ticket] = {id = enums.SoundEffect.Railway_Ticket,delay = 15,},
		[Cards.One_way_Rail_Ticket] = {id = enums.SoundEffect.Railway_Ticket,delay = 15,},
		[Cards.Qing_s_Soul] = {id = enums.SoundEffect.Soul_of_Qing,},
		[Cards.Tecro_s_Soul] = {id = enums.SoundEffect.Soul_of_Tecro,},
		[Cards.Anna_s_Soul] = {id = enums.SoundEffect.Soul_of_Anna,},
		[Cards.Zeis_s_Soul] = {id = enums.SoundEffect.Soul_of_Zeis,},
		[Cards.Adjustment] = {id = enums.SoundEffect.Adjustment,},
		[Cards.Art] = {id = enums.SoundEffect.Art,},
		[Cards.Faint] = {id = enums.SoundEffect.Faint,},
		[Cards.Lure] = {id = enums.SoundEffect.Lure,},
		[Cards.Aeon] = {id = enums.SoundEffect.The_Aeon,},
		[Cards.Eclipse] = {id = enums.SoundEffect.The_Eclipse,},
		[Cards.Invoker] = {id = enums.SoundEffect.The_Invoker,},
		[Cards.Profound] = {id = enums.SoundEffect.The_Profound,},
		[Cards.Sting] = {id = enums.SoundEffect.The_Sting,},
		[Cards.Universe] = {id = enums.SoundEffect.The_Universe,},
		[Cards.Witch] = {id = enums.SoundEffect.The_Witch,},
		[Cards.Wizard] = {id = enums.SoundEffect.The_Wizard,},
		[Cards.Adjustment_r] = {id = enums.SoundEffect.Adjustment_r,},
		[Cards.Art_r] = {id = enums.SoundEffect.Art_r,},
		[Cards.Faint_r] = {id = enums.SoundEffect.Faint_r,},
		[Cards.Lure_r] = {id = enums.SoundEffect.Lure_r,},
		[Cards.Aeon_r] = {id = enums.SoundEffect.The_Aeon_r,},
		[Cards.Corpse_r] = {id = enums.SoundEffect.The_Corpse_r,},
		[Cards.Eclipse_r] = {id = enums.SoundEffect.The_Eclipse_r,},
		[Cards.Profound_r] = {id = enums.SoundEffect.The_Profound_r,},
		[Cards.Sage_r] = {id = enums.SoundEffect.The_Sage_r,},
		[Cards.Sting_r] = {id = enums.SoundEffect.The_Sting_r,},
		[Cards.Universe_r] = {id = enums.SoundEffect.The_Universe_r,},
	},
}

local function options_root()
	return save.ModConfigSettings
end

local function appear_rates_bag()
	local root = options_root()
	if type(root) ~= "table" then return nil end
	root.QingRemasterOptions = root.QingRemasterOptions or {}
	local opts = root.QingRemasterOptions
	opts.CardAppearRates = opts.CardAppearRates or {}
	return opts.CardAppearRates
end

local function migrate_legacy_global_morph()
	save.PermanentData = save.PermanentData or {}
	local legacy_key = item.own_key.."val1"
	local legacy = save.PermanentData[legacy_key]
	if legacy == nil then return end
	local morph = tonumber(legacy)
	save.PermanentData[legacy_key] = nil
	if morph == nil then return end
	local bag = appear_rates_bag()
	if not bag then return end
	local appear = math.max(0, math.min(1, 1 - morph))
	for _, card_id in pairs(Cards) do
		if type(card_id) == "number" and auxi.is_thoth_card(card_id) then
			local key = tostring(card_id)
			if bag[key] == nil then bag[key] = appear end
		end
	end
	if save.SaveModData then pcall(save.SaveModData, "card_appear_migrate") end
end

function item.list_configurable_cards()
	local list = {}
	for name, card_id in pairs(Cards) do
		if type(card_id) == "number" and auxi.is_thoth_card(card_id) then
			list[#list + 1] = {name = name, id = card_id}
		end
	end
	table.sort(list, function(a, b)
		if a.id == b.id then return tostring(a.name) < tostring(b.name) end
		return a.id < b.id
	end)
	return list
end

function item.get_card_appear_rate(card_id)
	migrate_legacy_global_morph()
	card_id = tonumber(card_id)
	if not card_id then return item.default_appear_rate end
	local bag = appear_rates_bag()
	local v = bag and tonumber(bag[tostring(card_id)])
	if v == nil then return item.default_appear_rate end
	return math.max(0, math.min(1, v))
end

function item.set_card_appear_rate(card_id, rate)
	card_id = tonumber(card_id)
	if not card_id then return false end
	local bag = appear_rates_bag()
	if not bag then return false end
	rate = math.max(0, math.min(1, tonumber(rate) or item.default_appear_rate))
	if math.abs(rate - item.default_appear_rate) < 1e-6 then
		bag[tostring(card_id)] = nil
	else
		bag[tostring(card_id)] = rate
	end
	if save.SaveModData then pcall(save.SaveModData, "card_appear") end
	return true
end

function item.reset_card_appear_rates()
	local root = options_root()
	if type(root) ~= "table" or type(root.QingRemasterOptions) ~= "table" then return false end
	root.QingRemasterOptions.CardAppearRates = {}
	save.PermanentData = save.PermanentData or {}
	save.PermanentData[item.own_key.."val1"] = nil
	if save.SaveModData then pcall(save.SaveModData, "card_appear_reset") end
	return true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = nil,
Function = function(_,cardtype,player,useFlags)
	local info = item.announcer[cardtype]
	if info then
		local willRandomPlay = Random() % 2 == 1
		local announcerMode = Options.AnnouncerVoiceMode
		if (announcerMode == 2 or (announcerMode == 0 and willRandomPlay)) then
			sound_tracker.PlayStackedSound(info.id,1,1,false,0,info.delay or 10)
		end 
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_GET_CARD, params = nil,
Function = function(_,rng,card,playing,rune,onlyrune)
	local ret = card
	if auxi.is_origin_card_map(card) then
		rng = auxi.rng_for_sake(rng)
		local rnd = rng:RandomInt(10)
		if rnd < 10 then ret = auxi.get_origin_card_map(card,rng) end
	end
	if auxi.is_thoth_card(ret) then
		rng = auxi.rng_for_sake(rng)
		local rnd = rng:RandomInt(1000)/1000
		-- 出现率：低于该概率则映射回原版对应卡
		if rnd >= item.get_card_appear_rate(ret) then
			local mapped = auxi.get_maped_card(card,rng)
			if mapped then ret = mapped end
		end
	end
	if ret ~= card then return ret end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_,cmd,params)
	if string.lower(cmd) == "qing" and params ~= nil then
		local args={}
		for str in string.gmatch(params, "([^ ]+)") do
			table.insert(args, str)
		end
		if args[1] and args[2] then
			if args[1] == "set" and args[2] == "cardrate" then
				local val = item.default_appear_rate
				if args[3] then val = tonumber(args[3]) or val end
				val = math.max(0,math.min(1,val))
				-- 兼容旧命令：参数仍是「全局 morph 掉托特卡」概率；写入为出现率 1-morph
				local appear = 1 - val
				for _, entry in ipairs(item.list_configurable_cards()) do
					item.set_card_appear_rate(entry.id, appear)
				end
				print("Set card appear rates to "..tostring(appear).." (from morph "..tostring(val).."), default appear is 1.")
			end
		end
	end
end,
})

return item

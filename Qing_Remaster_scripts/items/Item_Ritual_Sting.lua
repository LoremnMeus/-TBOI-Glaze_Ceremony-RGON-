local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local item_color_holder = require("Qing_Remaster_scripts.others.Item_color_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Ritual_Sting,
	own_key = "Item_Ritual_Sting_",
	dir_time_limit = 20,
	colors = {
		[1] = {R = 1,G = 0,B = 0,A = 1,},
		[2] = {R = 1,G = 0.5,B = 0,A = 1,},
		[3] = {R = 1,G = 1,B = 0,A = 1,},
		[4] = {R = 0,G = 1,B = 0,A = 1,},
		[5] = {R = 0,G = 0,B = 1,A = 1,},
		[6] = {R = 0.5,G = 0,B = 0.5,A = 1,},
	},
	start_pos = Vector(0,-90),
	mov_pos = Vector(15,0),
	mov_pos2 = Vector(0,15),
	EID_Info = {
		zh = {
			[1] = {
				[1] = "翻倍受伤",
				[2] = "-0.2{{Damage}}攻击倍率",
				[3] = "+0.5{{Damage}}攻击倍率",
				[4] = "+3{{Damage}}攻击",
				[5] = "视为拥有{{Collectible118}}硫磺火",
				color = "{{ColorRed}}",
				name = "红色",
			},
			[2] = {
				[1] = "幸运不高于-7",
				[2] = "-2{{Luck}}幸运",
				[3] = "+4{{Luck}}幸运",
				[4] = "2倍房间清理奖励",
				[5] = "2倍道具生成",
				color = "{{ColorOrange}}",
				name = "橙色",
			},
			[3] = {
				[1] = "被圣光追击",
				[2] = "-2{{Range}}射程",
				[3] = "+5{{Range}}射程",
				[4] = "1.5倍颜色条增长",
				color = "{{ColorYellow}}",
				name = "黄色",
			},
			[4] = {
				[1] = "失去飞行",
				[2] = "-0.2{{Speed}}移速",
				[3] = "+0.5{{Speed}}移速",
				[4] = "飞行",
				[5] = "{{Collectible333}}开启全图",
				color = "{{ColorGreen}}",
				name = "绿色",
			},
			[5] = {
				[1] = "怪物留下水迹",
				[2] = "-0.5{{Tears}}射速",
				[3] = "+2{{Tears}}射速",
				[4] = "1.5倍{{Tears}}射速倍率",
				[5] = "攻击留下水迹",
				color = "{{ColorBlue}}",
				name = "蓝色",
			},
			[6] = {
				[1] = "3倍颜色条流失速度",
				[2] = "+20%人物大小",
				[3] = "-20%人物大小",
				[4] = "33%概率免伤",
				[5] = "大幅提升精英敌人的出现概率",
				color = "{{ColorPurple}}",
				name = "紫色",
			},
			basic = {
				[1] = "0%：",
				[2] = "低于50%：",
				[3] = "高于90%：",
				[4] = "高于150%：",
				[5] = "高于250%：",
			},
		},
		en = {
			[1] = {[1] = "Double damage taken",[2] = "-0.2{{Damage}} Damage multiplier",[3] = "+0.5{{Damage}} Damage multiplier",[4] = "+3{{Damage}} Damage",[5] = "Counts as having {{Collectible118}} Brimstone",color = "{{ColorRed}}",name = "Red",},
			[2] = {[1] = "Luck capped at -7",[2] = "-2{{Luck}} Luck",[3] = "+4{{Luck}} Luck",[4] = "Double room-clear rewards",[5] = "Double collectible generation",color = "{{ColorOrange}}",name = "Orange",},
			[3] = {[1] = "Chased by holy light",[2] = "-2{{Range}} Range",[3] = "+5{{Range}} Range",[4] = "1.5x color gain",color = "{{ColorYellow}}",name = "Yellow",},
			[4] = {[1] = "Flight disabled",[2] = "-0.2{{Speed}} Speed",[3] = "+0.5{{Speed}} Speed",[4] = "Flight",[5] = "{{Collectible333}} Full mapping",color = "{{ColorGreen}}",name = "Green",},
			[5] = {[1] = "Enemies leave creep",[2] = "-0.5{{Tears}} Tears",[3] = "+2{{Tears}} Tears",[4] = "1.5x{{Tears}} Tears multiplier",[5] = "Attacks leave creep",color = "{{ColorBlue}}",name = "Blue",},
			[6] = {[1] = "3x color drain",[2] = "+20% character size",[3] = "-20% character size",[4] = "33% chance to block damage",[5] = "Greatly increases champion enemy chance",color = "{{ColorPurple}}",name = "Purple",},
			basic = {[1] = "0%: ",[2] = "Below 50%: ",[3] = "Above 90%: ",[4] = "Above 150%: ",[5] = "Above 250%: ",},
		},
	},
}

local ritual_color_labels = {"red","orange","yellow","green","blue","purple"}
local ritual_color_weights = {
	-- A primary label fully feeds its own bar and partially feeds its two neighbors.
	red =    {1,0.25,0,0,0,0.25},
	orange = {0.25,1,0.25,0,0,0},
	yellow = {0,0.25,1,0.25,0,0},
	green =  {0,0,0.25,1,0.25,0},
	blue =   {0,0,0,0.25,1,0.25},
	purple = {0.25,0,0,0,0.25,1},
	pink =   {0.5,0,0,0,0,0.5},
	brown =  {0.35,0.65,0,0,0,0},
	black =  {0.2,0,0,0,0.3,0.5},
	white =  {0.5,0.5,0.5,0.5,0.5,0.5},
	grey =   {0.25,0.25,0.25,0.25,0.25,0.25},
	others = {1,1,1,1,1,1},
}

local champion_source_weights = {
	[0] = {red = 1},                         -- red
	[1] = {yellow = 1},                      -- yellow
	[2] = {green = 1},                       -- green
	[3] = {orange = 1},                      -- orange
	[4] = {blue = 1},                        -- blue
	[5] = {black = 1},                       -- black
	[6] = {white = 1},                       -- white
	[7] = {grey = 1},                        -- grey
	[8] = {white = 0.5,others = 0.5},        -- transparent
	[9] = {others = 1},                      -- flicker
	[10] = {pink = 1},                       -- pink
	[11] = {purple = 1},                     -- purple
	[12] = {red = 1},                        -- dark red
	[13] = {blue = 1},                       -- light blue
	[14] = {green = 0.5,brown = 0.5},        -- camo
	[15] = {green = 1},                      -- pulse green
	[16] = {grey = 1},                       -- pulse grey
	[17] = {yellow = 0.5,others = 0.5},      -- fly protected
	[18] = {others = 1},                     -- tiny
	[19] = {others = 1},                     -- giant
	[20] = {red = 1},                        -- pulse red
	[21] = {others = 1},                     -- size pulse
	[22] = {yellow = 1},                     -- king
	[23] = {black = 1},                      -- death
	[24] = {brown = 1},                      -- brown
	[25] = {red = 1,orange = 1,yellow = 1,green = 1,blue = 1,purple = 1}, -- rainbow
}

local function map_source_weights(label_weights)
	local result = {0,0,0,0,0,0,}
	for tag,source_weight in pairs(label_weights or {}) do
		local weights = ritual_color_weights[tag]
		if weights then
			for color_id = 1,#ritual_color_labels do
				result[color_id] = math.min(1,result[color_id] + weights[color_id] * source_weight)
			end
		end
	end
	return result
end

function item.get_color_counts(collectible_id)
	local label_weights = item_color_holder.get_label_weights(collectible_id,true) or {}
	return map_source_weights(label_weights)
end

function item.get_champion_color_counts(npc)
	return map_source_weights(champion_source_weights[npc:GetChampionColorIdx()] or {others = 1})
end

function item.get_values(player)
	local idx = player:GetData().__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
	local values = save.elses[item.own_key.."effect"][idx]
	for color_id = 1,6 do
		if values[color_id] == nil then values[color_id] = 10 end
	end
	return values
end

local function effect_signature(values)
	local result = {}
	for color_id = 1,6 do
		local value = values[color_id]
		result[color_id] = value <= 0 and 0 or value < 5 and 1 or value > 25 and 5 or
			value > 15 and 4 or value > 9 and 3 or 2
	end
	return table.concat(result,":")
end

function item.refresh_effects(player,force)
	local d = player:GetData()
	local values = item.get_values(player)
	local signature = effect_signature(values)
	local color_signature_parts = {}
	for color_id = 1,6 do color_signature_parts[color_id] = math.floor(values[color_id] * 100 + 0.5) end
	local color_signature = table.concat(color_signature_parts,":")
	local brimstone_active = values[1] > 25
	if d[item.own_key.."brimstone_active"] ~= brimstone_active then
		d[item.own_key.."brimstone_active"] = brimstone_active
		imitate_item_holder.Evaluate_Imitate_Items(player,CollectibleType.COLLECTIBLE_BRIMSTONE)
	end
	local effect_changed = force or d[item.own_key.."effect_signature"] ~= signature
	local color_changed = force or d[item.own_key.."tear_color_signature"] ~= color_signature
	if effect_changed or color_changed then
		d[item.own_key.."effect_signature"] = signature
		d[item.own_key.."tear_color_signature"] = color_signature
		local flags = CacheFlag.CACHE_TEARCOLOR
		if effect_changed then flags = flags | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_LUCK |
			CacheFlag.CACHE_RANGE | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_FIREDELAY |
			CacheFlag.CACHE_FLYING | CacheFlag.CACHE_SIZE end
		player:AddCacheFlags(flags)
		player:EvaluateItems()
	end
end

local function find_holder(color_id,test)
	for player_num = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		if player:HasCollectible(item.entity) then
			local value = item.get_values(player)[color_id]
			if test(value) then return player,value end
		end
	end
end

function item.check_EID_info(player)
	local d = player:GetData()
	local idx = d.__Index
	local id = math.floor(Game():GetFrameCount() / 90) % 6 + 1
	local language = Options.Language
	if item.EID_Info[language] == nil then language = "zh" end
	local ret = ""
	local dinfo = item.EID_Info[language]
	local info = dinfo[id]
	if info then
		local val = ((save.elses[item.own_key.."effect"] or {})[idx] or {})[id] or 10
		ret = ret .. "#" .. info.color .. info.name .. ": " .. tostring(math.floor(val * 10 + 0.5)) .. "%{{CR}}"
		for i = 1,#info do
			local suc = (i == 1 and val <= 0) or (i == 2 and val < 5) or
				(i == 3 and val > 9) or (i == 4 and val > 15) or (i == 5 and val > 25)
			if suc then ret = ret .. "#" .. info["color"] .. dinfo.basic[i] .. info[i] .. "{{CR}}"
			else ret = ret .. "#{{ColorGray}}" .. dinfo.basic[i] .. info[i] .. "{{CR}}" end
		end
	end
	return ret
end

function item.get_column(player,number)
	local ret = math.max(3,math.ceil(math.sqrt(number)))
	local delpos = Isaac.WorldToScreen(player.Position) + item.start_pos - item.mov_pos2 * 0.5 	--ui.GetScreenSize()
	local mxn = math.max(1,math.ceil(delpos.Y / 20))
	ret = math.max(math.ceil(number / mxn),ret)
	return ret
end

function item.makeitemlist(player)
	local d = player:GetData()
	local config = Isaac:GetItemConfig()
	local sz = config:GetCollectibles().Size
	local ret = {}
	for i = 1,sz do
		local col = config:GetCollectible(i)
		if col and (col.Hidden ~= true) and (col.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST) and (i ~= item.entity) then
			local num = player:GetCollectibleNum(i,true)
			if num > 0 then
				if i == enums.Items.It_s_a_trick then col = config:GetCollectible(save.elses.glazed_trick or 32) or config:GetCollectible(32) end
				if num > 0 then table.insert(ret,#ret + 1,{id = i,spritename = col.GfxFileName,}) end
			end
		end
	end
	return ret
end

function item.render_selector2(player,offset)
	local d = player:GetData()
	local stpos = Isaac.WorldToScreen(player.Position) + item.start_pos
	local list = d[item.own_key.."effect"].list or item.makeitemlist(player)
	local sl = d[item.own_key.."effect"].sel or 0
	local column = item.get_column(player,#list + 1)
	local mxn = math.ceil((#list + 1)/column) * column
	local spos = Isaac.WorldToScreen(player.Position) + (offset or item.start_pos) - item.mov_pos * ((column - 1)/2) - item.mov_pos2 * (mxn/column)
	for ii = 1,mxn do
		local info = list[ii] or {id = 0,spritename = "gfx/ui/math/exclude_mark.png",}
		if info.spritename then
			local s = Sprite()
			s:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true)
			s:Play("Idle",true)
			s:ReplaceSpritesheet(0,info.spritename)
			s:LoadGraphics()
			s.Scale = Vector(0.5,0.5)
			local iii = ii - 1
			local i = iii % column
			local j = math.floor(iii/column)
			local tpos = spos + item.mov_pos * i + item.mov_pos2 * j
			s:Render(tpos,Vector(0,0),Vector(0,0))
			if iii == sl then
				local s2 = Sprite()
				s2.Scale = Vector(0.5,0.5)
				s2:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true)
				s2:Play("Idle",true)
				s2:ReplaceSpritesheet(0,"gfx/ui/math/catch_mark.png")
				s2:LoadGraphics()
				s2:Render(tpos,Vector(0,0),Vector(0,0))
			end
		end
	end
end

local ffont = Font()
ffont:Load("font/luaminioutlined.fnt")

local function get_progress_sprites()
	if item.progress_sprites then return item.progress_sprites end
	local base = Sprite()
	base:Load("gfx/mimics/Ritual_Sting/Colorinfo.anm2",true)
	base:Play("Idle",true)
	local bar = Sprite()
	bar:Load("gfx/mimics/Ritual_Sting/Colorinfo.anm2",true)
	item.progress_sprites = {base = base,bar = bar,}
	return item.progress_sprites
end

function item.render_selector(player)
	local sprites = get_progress_sprites()
	local s = sprites.bar
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {} 
	local ang = d[item.own_key.."effect"].ang or 0
	local s2
	if d[item.own_key.."effect"].seled then s2 = auxi.load_item(d[item.own_key.."effect"].seled.id,{Anm = "gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",}) end
	local pos = Isaac.WorldToScreen(player.Position) + Vector(0,-40)
	sprites.base.Rotation = ang
	sprites.base.Scale = Vector(1,1)
	sprites.base.Color = Color(0.18,0.18,0.18,0.72,0,0,0)
	sprites.base:Render(pos,Vector(0,0),Vector(0,0))
	for i = 1,6 do
		local dang = ang + (i - 1) * 60 + 180
		local value = save.elses[item.own_key.."effect"][idx][i] or 10
		local step = math.max(0,math.min(30,math.ceil(value)))
		local c = auxi.table2color(item.colors[i])
		-- Draw the complete capacity first so empty progress remains clearly visible.
		s:SetFrame("Step",30)
		s.Rotation = dang
		s.Scale = Vector(1,1)
		s.Color = Color(c.R * 0.12,c.G * 0.12,c.B * 0.12,0.82,0,0,0)
		s:Render(pos,Vector(0,0),Vector(0,0))
		s:SetFrame("Step",step)
		s.Scale = Vector(1,1)
		s.Color = auxi.UpColor(c)
		s:Render(pos,Vector(0,0),Vector(0,0))
	end
	for i = 1,6 do
		local ideal = (i == (-(d[item.own_key.."effect"].id or 0)) % 6 + 1)
		local dang = ang + (i - 1) * 60 + 180
		local value = save.elses[item.own_key.."effect"][idx][i] or 10
		local step = math.max(0,math.min(30,math.ceil(value)))
		local c = auxi.table2color(item.colors[i])
		local uc = auxi.UpColor(c)
		local rsp2 = pos + auxi.get_by_rotate(Vector(0,step + 20),dang)
		local label_radius = 56
		if ideal then
			s:SetFrame("Step",step)
			s.Rotation = dang
			s.Scale = Vector(1,1)
			s.Color = auxi.MulColor(uc,Color(1,1,1,0.42,0.35,0.35,0.35))
			s:Render(pos,Vector(0,0),Vector(0,0))
			label_radius = step + 42
			if not s2 then
				local s3 = Sprite()
				s3:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true)
				s3:Play("Idle",true)
				s3:ReplaceSpritesheet(0,"gfx/items/collectibles/questionmark.png")
				s3.Rotation = dang + 180
				s3.Color = auxi.AddColor(c,uc,0.7,0.3)
				s3:Render(rsp2,Vector(0,0),Vector(0,0))
			else
				local info = item.get_color_counts(d[item.own_key.."effect"].seled.id)
				local step2 = math.min(30,math.ceil(step + info[i] * 10))
				s:SetFrame("Step",step2)
				s.Scale = Vector(1,1)
				s.Color = auxi.MulColor(uc,Color(1,1,1,0.5,1,1,1))
				s.Rotation = dang
				s:Render(pos,Vector(0,0),Vector(0,0))
				rsp2 = pos + auxi.get_by_rotate(Vector(0,step2 + 20),dang)
				label_radius = step2 + 42
				local addinfo = math.ceil(info[i] * 100 * 100)/100
				gui.draw_ch(rsp2 + Vector(15,-15),"+"..tostring(addinfo).."%",1,1,KColor(c.R,c.G,c.B,1),true,ffont)
				
				s2.Rotation = dang + 180
				s2.Color = auxi.AddColor(c,uc,0.7,0.3)
				s2:Render(rsp2,Vector(0,0),Vector(0,0))
			end
			
			local s4 = Sprite()
			s4:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true)
			s4:Play("Idle",true)
			s4:ReplaceSpritesheet(0,"gfx/ui/math/catch_mark.png")
			s4:LoadGraphics()
			s4.Rotation = dang + 180
			s4:Render(rsp2,Vector(0,0),Vector(0,0))
			
			if d[item.own_key.."effect"].toselect then
				item.render_selector2(player,rsp2 + Vector(0,-10) - Isaac.WorldToScreen(player.Position))
			end			
		else
			if s2 then
				s2.Rotation = dang + 180
				s2.Color = auxi.AddColor(c,auxi.UpColor(c),0.7,0.3)
				s2:Render(rsp2,Vector(0,0),Vector(0,0))
			end
		end
		-- Draw labels last. Only the selected label moves outside its item/preview icon.
		local label_pos = pos + auxi.get_by_rotate(Vector(0,label_radius),dang)
		gui.draw_ch(label_pos + Vector(-14,-5),string.format("%.1f%%",value * 10),1,1,KColor(c.R,c.G,c.B,1),true,ffont)
	end
end

function item.move(player,dir)
	local d = player:GetData()
	if not d[item.own_key.."effect"] then return end
	d[item.own_key.."effect"].id = d[item.own_key.."effect"].id or 0
	if d[item.own_key.."effect"].toselect == nil then
		if dir == 4 then d[item.own_key.."effect"].id = (d[item.own_key.."effect"].id + 1) % 6
		elseif dir == 5 then d[item.own_key.."effect"].id = (d[item.own_key.."effect"].id + 5) % 6
		elseif dir == 6 or dir == 7 then
			d[item.own_key.."effect"].toselect = {}
			d[item.own_key.."effect"].list = item.makeitemlist(player)
		elseif dir == 9 then
			if d[item.own_key.."effect"].seled == nil then
				d[item.own_key.."effect"].toselect = {}
				d[item.own_key.."effect"].list = item.makeitemlist(player)
			else
				d[item.own_key.."effect2"] = {tg = d[item.own_key.."effect"].seled,id = (-(d[item.own_key.."effect"].id or 0)) % 6 + 1,}
				local slot = auxi.check_slot_with_item(player,item.entity)
				player:UseActiveItem(item.entity,UseFlag.USE_OWNED,slot)
				return -2
			end
		end
	else
		local column = item.get_column(player,#d[item.own_key.."effect"].list + 1)
		local raw = math.ceil((#d[item.own_key.."effect"].list + 1) / column)
		local sl = d[item.own_key.."effect"].sel or 0
		local i = sl % column
		local j = math.floor(sl/column)
		if dir == 5 then i = (i + 1) % column
		elseif dir == 4 then i = (i + column - 1)% column
		elseif dir == 7 then j = (j + 1) % raw
		elseif dir == 6 then j = (j + raw - 1) % raw end
		d[item.own_key.."effect"].sel = i + j * column
		if dir == 9 then
			d[item.own_key.."effect"].seled = d[item.own_key.."effect"].list[(d[item.own_key.."effect"].sel or 0) + 1]
			d[item.own_key.."effect"].toselect = nil
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cache_flag)
	if not player:HasCollectible(item.entity) then return end
	local values = item.get_values(player)
	if cache_flag == CacheFlag.CACHE_DAMAGE then
		if values[1] < 5 then player.Damage = player.Damage - 0.2 * auxi.get_damage_multiplier(player) end
		if values[1] > 9 then player.Damage = player.Damage + 0.5 * auxi.get_damage_multiplier(player) end
		if values[1] > 15 then player.Damage = player.Damage + 3 end
	elseif cache_flag == CacheFlag.CACHE_LUCK then
		if values[2] <= 0 then player.Luck = math.min(player.Luck,-7) end
		if values[2] < 5 then player.Luck = player.Luck - 2 end
		if values[2] > 9 then player.Luck = player.Luck + 4 end
	elseif cache_flag == CacheFlag.CACHE_RANGE then
		if values[3] < 5 then player.TearRange = player.TearRange - 2 * 40 end
		if values[3] > 9 then player.TearRange = player.TearRange + 5 * 40 end
	elseif cache_flag == CacheFlag.CACHE_SPEED then
		if values[4] < 5 then player.MoveSpeed = player.MoveSpeed - 0.2 end
		if values[4] > 9 then player.MoveSpeed = player.MoveSpeed + 0.5 end
	elseif cache_flag == CacheFlag.CACHE_FLYING then
		if values[4] <= 0 then player.CanFly = false
		elseif values[4] > 15 then player.CanFly = true end
	elseif cache_flag == CacheFlag.CACHE_FIREDELAY then
		local tears = 30 / (player.MaxFireDelay + 1)
		if values[5] < 5 then tears = tears - 0.5 end
		if values[5] > 9 then tears = tears + 2 end
		if values[5] > 15 then tears = tears * 1.5 end
		player.MaxFireDelay = 30 / math.max(0.1,tears) - 1
	elseif cache_flag == CacheFlag.CACHE_SIZE then
		if values[6] < 5 then player.SpriteScale = player.SpriteScale * 1.2
		elseif values[6] > 9 then player.SpriteScale = player.SpriteScale * 0.8 end
	elseif cache_flag == CacheFlag.CACHE_TEARCOLOR then
		local mean = 0
		for color_id = 1,6 do mean = mean + values[color_id] / 6 end
		local weights,total = {},0
		for color_id = 1,6 do
			weights[color_id] = math.max(0,values[color_id] - mean)
			total = total + weights[color_id]
		end
		if total > 0.01 then
			local red,green,blue = 0,0,0
			for color_id = 1,6 do
				local color = item.colors[color_id]
				red = red + color.R * weights[color_id] / total
				green = green + color.G * weights[color_id] / total
				blue = blue + color.B * weights[color_id] / total
			end
			local strength = math.min(0.75,total / 20)
			local target = Color(red,green,blue,1,red * 0.25,green * 0.25,blue * 0.25)
			player.TearColor = auxi.AddColor(player.TearColor,target,1 - strength,strength)
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,priority = -50,
Function = function(_,ent,amount,flags,source,countdown)
	local player = ent:ToPlayer()
	if not player or not player:HasCollectible(item.entity) then return end
	local data = player:GetData()
	if data[item.own_key.."repeat_damage"] then return end
	local values = item.get_values(player)
	if values[6] > 15 and player:GetCollectibleRNG(item.entity):RandomFloat() < 1/3 then
		return false
	end
	if values[1] <= 0 and amount > 0 then
		data[item.own_key.."repeat_damage"] = true
		player:TakeDamage(amount * 2,flags,source,countdown)
		data[item.own_key.."repeat_damage"] = nil
		return false
	end
end,
})

local spawn_champion_conversion

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,npc)
	if npc:IsVulnerableEnemy() and not npc:IsDead() and npc.FrameCount % 12 == 0 and
		find_holder(5,function(value) return value <= 0 end) then
		local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.CREEP_RED,0,npc.Position,Vector(0,0),npc):ToEffect()
		if creep then creep.Timeout = 45 creep.Scale = 0.7 creep:Update() end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,npc)
	local data = npc:GetData()
	if data[item.own_key.."champion_roll"] or npc.FrameCount < 2 then return end
	data[item.own_key.."champion_roll"] = true
	if npc:IsChampion() or npc:IsBoss() or not npc:IsVulnerableEnemy() or
		not npc:IsActiveEnemy(false) or npc.CanShutDoors ~= true or
		npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_CHARM | EntityFlag.FLAG_NO_TARGET) or
		not find_holder(6,function(value) return value > 25 end) then return end
	-- Purple tier five adds a fixed roll; it deliberately does not inspect sprite colors.
	if npc:GetDropRNG():RandomFloat() < 1/3 then
		local player = find_holder(6,function(value) return value > 25 end)
		if player then spawn_champion_conversion(player,npc) end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = CollectibleType.COLLECTIBLE_BRIMSTONE,
Function = function(_,player,colid,value)
	if player:HasCollectible(item.entity) and item.get_values(player)[1] > 25 then
		value[CollectibleType.COLLECTIBLE_BRIMSTONE] = math.max(1,value[CollectibleType.COLLECTIBLE_BRIMSTONE] or 0)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_FIRE_TRIGGER_IN_FRAME, params = nil,
Function = function(_,tp,ent,pos,player,dir)
	if not player or not player:HasCollectible(item.entity) or item.get_values(player)[5] <= 25 then return end
	local data = ent and ent:GetData()
	if data and data[item.own_key.."water_trail"] then return end
	if data then data[item.own_key.."water_trail"] = true end
	local origin = pos or (ent and ent.Position) or player.Position
	local direction = dir or (ent and ent.Velocity) or Vector(0,0)
	if direction:Length() > 0.01 then direction = direction:Normalized() else direction = Vector(0,0) end
	for distance = 0,40,20 do
		local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL,0,
			origin + direction * distance,Vector(0,0),player):ToEffect()
		if creep then
			creep.CollisionDamage = player.Damage * 0.66
			creep:Update()
		end
	end
end,
})

local function find_reward_player(player_index)
	for player_num = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		if player:GetData().__Index == player_index then return player end
	end
end

local function apply_champion_conversion(data,arrived)
	if not data or data.converted then return end
	data.converted = true
	local target = data.target
	if not auxi.check_all_exists(target) or target:IsChampion() or target:IsBoss() then return end
	target:MakeChampion(target.InitSeed,-1,true)
	if arrived then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SOUL_PICKUP,0.65,1.1,false,0,2)
		target:SetColor(Color(0.7,0.25,1,1,0.35,0,0.5),12,50,true,false)
	end
end

spawn_champion_conversion = function(player,target)
	local direction = target.Position - player.Position
	if direction:Length() < 0.01 then direction = Vector(0,-1) end
	local rng = target:GetDropRNG()
	local launch_direction = direction:Rotated(rng:RandomInt(71) - 35)
	local launch_speed = 12 + rng:RandomFloat() * 8
	local chase_speed = 20 + rng:RandomFloat() * 8
	local particle = auxi.fire_nil(player.Position,launch_direction:Resized(launch_speed),{cooldown = 9999,player = player,})
	if not particle then target:MakeChampion(target.InitSeed,-1,true) return end
	local color = Color(0.65,0.1,1,1,0.35,0,0.55)
	particle.Color = color
	local sprite = particle:GetSprite()
	sprite:Load("gfx/cards/cd03_emp_tear.anm2",true)
	sprite:Play("RegularTear6",true)
	sprite.Scale = Vector(1.25,1.25)
	sprite.Color = color
	particle:GetData()[item.own_key.."champion_conversion"] = {target = target,chase_speed = chase_speed,}
end

local function collect_champion_reward(data,arrived)
	if not data or data.collected then return end
	data.collected = true
	local player = find_reward_player(data.player_index)
	if not player or not player:HasCollectible(item.entity) then return end
	local values = item.get_values(player)
	local gain_multiplier = values[3] > 15 and 1.5 or 1
	for color_id = 1,6 do
		values[color_id] = math.min(30,values[color_id] + (data.color_counts[color_id] or 0) * 0.5 * gain_multiplier)
	end
	item.refresh_effects(player,true)
	if arrived then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SOUL_PICKUP,0.65,1,false,0,2)
		player:SetColor(Color(1,1,1,1,0.35,0.35,0.35),12,50,true,false)
	end
end

local function spawn_champion_reward(npc,player,color_counts)
	-- Reuse Chiastolite's proven nil-particle carrier and tear sprite instead of a
	-- vanilla effect that can finish itself before the homing animation is visible.
	local particle = auxi.fire_nil(npc.Position,auxi.MakeVector(math.random(360)) * 10,
		{cooldown = 9999,player = player,})
	if not particle then return end
	local data = particle:GetData()
	data[item.own_key.."champion_reward"] = {
		player_index = player:GetData().__Index,
		color_counts = color_counts,
	}
	local red,green,blue,total = 0,0,0,0
	for color_id = 1,6 do
		local weight = color_counts[color_id] or 0
		local color = item.colors[color_id]
		red,green,blue,total = red + color.R * weight,green + color.G * weight,blue + color.B * weight,total + weight
	end
	if total > 0 then particle.Color = Color(red / total,green / total,blue / total,1,0.2,0.2,0.2) end
	local sprite = particle:GetSprite()
	sprite:Load("gfx/cards/cd03_emp_tear.anm2",true)
	sprite:Play("RegularTear6",true)
	sprite.Scale = Vector(1.25,1.25)
	sprite.Color = particle.Color
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.ID_EFFECT_MeusNIL,
Function = function(_,effect)
	local data = effect:GetData()
	local reward = data[item.own_key.."champion_reward"]
	local conversion = data[item.own_key.."champion_conversion"]
	if not reward and not conversion then return end
	local trail = data[item.own_key.."champion_reward_trail"]
	if data[item.own_key.."trail_fade"] then
		local frames = data[item.own_key.."trail_fade"] - 1
		data[item.own_key.."trail_fade"] = frames
		effect.Velocity = Vector(0,0)
		effect:GetSprite().Color = Color(1,1,1,0,0,0,0)
		if auxi.check_all_exists(trail) then
			local factor = math.max(0,frames / 12)
			trail.Position = effect.Position
			trail.Velocity = Vector(0,0)
			trail.MinRadius = 0.15 * factor
			trail.MaxRadius = 0.15 * factor
			trail.SpriteScale = Vector(2 * factor,2 * factor)
			trail:SetColor(Color(effect.Color.R,effect.Color.G,effect.Color.B,1.4 * factor,
				effect.Color.RO,effect.Color.GO,effect.Color.BO),-1,0)
		end
		if frames <= 0 then
			if auxi.check_all_exists(trail) then trail:Remove() end
			effect:Remove()
		end
		return
	end
	if effect.FrameCount >= 180 then effect:Remove() return end
	local direction
	if conversion then
		local target = conversion.target
		if not auxi.check_all_exists(target) or target:IsChampion() then effect:Remove() return end
		direction = target.Position - effect.Position
		if direction:Length() <= target.Size + 14 then
			apply_champion_conversion(conversion,true)
			effect.Position = target.Position
			data[item.own_key.."trail_fade"] = 12
			return
		end
	else
		local player = find_reward_player(reward.player_index)
		if not player then effect:Remove() return end
		direction = player.Position - effect.Position
		if direction:Length() <= player.Size + 10 then
			collect_champion_reward(reward,true)
			effect.Position = player.Position
			data[item.own_key.."trail_fade"] = 12
			return
		end
	end
	if conversion and direction:Length() < 80 then
		-- Snap to strong terminal guidance so the particle cannot orbit near its target.
		effect.Velocity = direction:Resized(math.max(conversion.chase_speed or 24,
			conversion.target.Velocity:Length() + 10))
	elseif conversion then
		effect.Velocity = effect.Velocity * 0.55 + direction:Resized(conversion.chase_speed or 24) * 0.45
	else
		effect.Velocity = effect.Velocity * 0.65 + direction:Resized(math.min(12,5 + effect.FrameCount * 0.25)) * 0.35
	end
	if auxi.check_all_exists(trail) then
		trail.Position = effect.Position
		-- Position is sampled manually every frame; copying the carrier velocity
		-- makes SPRITE_TRAIL integrate once more and render one velocity ahead.
		trail.Velocity = Vector(0,0)
		trail:SetColor(Color(effect.Color.R,effect.Color.G,effect.Color.B,1.4,
			effect.Color.RO,effect.Color.GO,effect.Color.BO),-1,0)
	else
		-- Match Chiastolite's binding lifecycle: create/recreate from the update,
		-- bind the trail to the carrier, then keep sampling its world position.
		trail = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL,0,
			effect.Position,Vector(0,0),effect):ToEffect()
		if trail then
			data[item.own_key.."champion_reward_trail"] = trail
			trail.MinRadius = 0.15
			trail.MaxRadius = 0.15
			trail.SpriteScale = Vector(2,2)
			trail.Parent = effect
			effect.Child = trail
			trail:SetColor(Color(effect.Color.R,effect.Color.G,effect.Color.B,1.4,
				effect.Color.RO,effect.Color.GO,effect.Color.BO),-1,0)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = EntityType.ENTITY_EFFECT,
Function = function(_,effect)
	local data = effect:GetData()
	local reward = data[item.own_key.."champion_reward"]
	if reward then collect_champion_reward(reward) end
	local conversion = data[item.own_key.."champion_conversion"]
	if conversion then apply_champion_conversion(conversion) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = nil,
Function = function(_,npc)
	if not npc:IsChampion() then return end
	local color_counts = item.get_champion_color_counts(npc)
	for player_num = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		if player:HasCollectible(item.entity) then
			spawn_champion_reward(npc,player,color_counts)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,rng,position)
	for player_num = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		if player:HasCollectible(item.entity) then
			local values = item.get_values(player)
			local drain = values[6] <= 0 and 0.9 or 0.3
			for color_id = 1,6 do values[color_id] = math.max(0,values[color_id] - drain) end
			item.refresh_effects(player,false)
		end
	end
	if not find_holder(2,function(value) return value > 15 end) then return end
	local old_seeds = {}
	for _,entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do old_seeds[entity.InitSeed] = true end
	delay_buffer.addeffe(function()
		for _,entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do
			local pickup = entity:ToPickup()
			if pickup and not old_seeds[pickup.InitSeed] and pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE and
				not pickup:GetData()[item.own_key.."reward_copy"] then
				local copy = Isaac.Spawn(pickup.Type,pickup.Variant,pickup.SubType,
					Game():GetRoom():FindFreePickupSpawnPosition(pickup.Position + Vector(20,0),10,true),Vector(0,0),nil)
				copy:GetData()[item.own_key.."reward_copy"] = true
			end
		end
	end,{},1)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_COLLECTIBLE,
Function = function(_,pickup)
	if item.spawning_item_copy or pickup.SubType <= 0 then return end
	-- GetData 在小退会丢；用 Consistance 记「已是副本 / 已当源复制过」
	if pickup:GetData()[item.own_key.."item_copy"]
		or consistance_holder.try_check_entity(pickup,item.own_key.."item_copy") then
		return
	end
	if consistance_holder.try_check_entity(pickup,item.own_key.."item_copy_source") then
		return
	end
	if not find_holder(2,function(value) return value > 25 end) then return end
	pickup:GetData()[item.own_key.."item_copy_source"] = true
	consistance_holder.try_hold_entity(pickup,item.own_key.."item_copy_source",{ignore_subtype = true})
	delay_buffer.addeffe(function()
		if not pickup or not pickup:Exists() then return end
		item.spawning_item_copy = true
		local copy = Isaac.Spawn(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE,pickup.SubType,
			Game():GetRoom():FindFreePickupSpawnPosition(pickup.Position + Vector(40,0),20,true),Vector(0,0),pickup):ToPickup()
		item.spawning_item_copy = nil
		if copy then
			copy:GetData()[item.own_key.."item_copy"] = true
			consistance_holder.try_hold_entity(copy,item.own_key.."item_copy",{ignore_subtype = true})
			copy.Price = pickup.Price
		end
	end,{},1)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = enums.Items.Ritual_Sting,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local d = player:GetData()
		if d[item.own_key.."effect"] == nil then
			d[item.own_key.."effect"] = {Lift = true,}
			return {Discharge = false}
		else
			player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
			selection_holder.remove_select(player,item.own_key)
			d[item.own_key.."effect"] = nil
			return {Discharge = false}
		end
	end
	return ret
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if ent ~= nil then
		local player = ent:ToPlayer()
		if player then
			if player:GetData()[item.own_key.."effect"] and selection_holder.check_select(player,item.own_key) then
				for u,i in pairs({4,5,6,7,9,11}) do
					if button == i and (hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED) then
						return false
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local ctrlid = player.ControllerIndex
	local d = player:GetData()
	local room = Game():GetRoom()
	if player:HasCollectible(item.entity) then
		local values = item.get_values(player)
		item.refresh_effects(player,false)
		if values[4] > 25 and player.FrameCount % 30 == 0 then
			local level = Game():GetLevel()
			level:ApplyMapEffect()
			level:ApplyCompassEffect()
			level:ApplyBlueMapEffect()
		end
		if values[3] <= 0 and not room:IsClear() and player.FrameCount % 120 == 0 then
			local target = player.Position
			delay_buffer.addeffe(function()
				local beam = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.CRACK_THE_SKY,0,target,Vector(0,0),player)
				if player and player:Exists() and (player.Position - target):Length() < 28 then
					player:TakeDamage(1,DamageFlag.DAMAGE_NO_PENALTIES,EntityRef(beam),30)
				end
			end,{},20)
		end
	end
	for _ = 1,1 do if d[item.own_key.."effect"] then
		if d[item.own_key.."effect"].Lift then
			if player:IsExtraAnimationFinished() then
				player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
				selection_holder.check_and_try_select(player,item.own_key)
				d[item.own_key.."effect"].Lift = nil
				d[item.own_key.."effect"].Render = true
				--reflush_selector(player)
			end
		else
			if player:IsHoldingItem() == false then
				d[item.own_key.."effect"] = nil
				selection_holder.remove_select(player,item.own_key)
			else
				if selection_holder.check_select(player,item.own_key) and Game():IsPaused() == false then
					local dir = nil
					for u,i in pairs({4,5,6,7,9,11}) do
						if (Input.IsActionTriggered(i,ctrlid) or Input.IsActionPressed(i,ctrlid)) then
							dir = i
						end
					end
					local should_count = false
					if dir then
						if dir == 11 then
							local slot = auxi.check_slot_with_item(player,item.entity)
							player:UseActiveItem(item.entity,UseFlag.USE_OWNED,slot)
							break
						end
						if dir == item.last_open_dir then
							item.last_open_dir_counter = (item.last_open_dir_counter or 0) + 1
							if item.last_open_dir_counter > item.dir_time_limit and item.last_open_dir_counter % 8 == 1 then
								should_count = true
							end
						else
							item.last_open_dir_counter = 0
							should_count = true
						end
					end
					item.last_open_dir = dir
					if should_count then
						local succ = item.move(player,dir)
						if succ == -1 then
							sound_tracker.PlayStackedSound(187,1,1,false,0,2)
						elseif succ == -2 then
							break
						else
							if dir == 5 or dir == 6 then
								sound_tracker.PlayStackedSound(195,1,1,false,0,2)
							elseif dir == 4 or dir == 7 then
								sound_tracker.PlayStackedSound(194,1,1,false,0,2)
							elseif dir == 9 then
								sound_tracker.PlayStackedSound(285,1,1,false,0,2)
							end
						end
					end
					
					local ang = d[item.own_key.."effect"].ang or 0
					ang = auxi.checkrounded(ang,(d[item.own_key.."effect"].id or 0) * 60,0.75,0.25,360)
					d[item.own_key.."effect"].ang = ang
					
				end
			end
		end
	end end
	if d[item.own_key.."effect2"] then
		if player:IsExtraAnimationFinished() then
			local idx = d.__Index
			local tg = (d[item.own_key.."effect2"].tg or {}).id
			if tg then
				local id = d[item.own_key.."effect2"].id or 0
				player:AnimateCollectible(tg,"UseItem","PlayerPickup")
				player:RemoveCollectible(tg)
				delay_buffer.addeffe(function()
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
					local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),nil)
					local s = e1:GetSprite()
					s.Color = auxi.UpColor(auxi.table2color(item.colors[id]))
					local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),nil)
					local s = e2:GetSprite()
					s.Color = auxi.UpColor(auxi.table2color(item.colors[id]))
				end,{},10)
				local values = item.get_values(player)
				local gain_multiplier = values[3] > 15 and 1.5 or 1
				values[id] = math.min(30,values[id] + item.get_color_counts(tg)[id] * 10 * gain_multiplier)
				item.refresh_effects(player,true)
			end
			d[item.own_key.."effect2"] = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local room = Game():GetRoom()
	local s = player:GetSprite()
	local d = player:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) and d[item.own_key.."effect"] then
		if d[item.own_key.."effect"].Render and player:IsHoldingItem() then
			if selection_holder.check_select(player,item.own_key) then
				item.render_selector(player)
			end
		end
	end
end,
})

if EID then

EID:addDescriptionModifier("qing_item_sync"..tostring(item.entity), function(desc) return true end, function(desc)
	local id = desc.ObjType
	local vr = desc.ObjVariant
	local st = desc.ObjSubType
	if (id == 5 and vr == 100 and st == item.entity) then
		local player = auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
		local info = item.check_EID_info(player)
		if info then
			local repl = "#{{Collectible"..tostring(item.entity).."}} "
			info = string.gsub(info, "#", repl)
			EID:appendToDescription(desc, info)			
		end
	end
	return desc
end)

end

return item

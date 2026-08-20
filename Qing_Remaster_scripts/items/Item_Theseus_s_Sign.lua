local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")

local item = {
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Theseus_s_Sign,
	own_key = "Item_Theseus_sign_",
	heart_changetypes = {
		["sl_heart"] = true,
		["rd_heart"] = true,
		["et_heart"] = true,
		["bn_heart"] = true,
	},
	resource_types = {
		coin = { factor = 3, spread = 5, icon = "coin" },
		key = { factor = 2, spread = 2, icon = "key" },
		bomb = { factor = 3, spread = 3, icon = "bomb" },
	},
	notice_duration = 180,
	notice_fade = 30,
	icon_sprites = {},
}

local trigger_order = {
	"damage",
	"heal",
	"gain_coin",
	"lose_coin",
	"gain_key",
	"lose_key",
	"gain_bomb",
	"lose_bomb",
}

local trigger_text = {
	zh_cn = {
		damage = "受到%d次伤害",
		heal = "恢复%d点生命",
		gain_coin = "获得%d枚硬币",
		lose_coin = "失去%d枚硬币",
		gain_key = "获得%d把钥匙",
		lose_key = "失去%d把钥匙",
		gain_bomb = "获得%d颗炸弹",
		lose_bomb = "失去%d颗炸弹",
		gain_item = "生成一个随机道具",
		lose_item = "随机失去一个道具",
	},
	en_us = {
		damage = "Take damage %d times",
		heal = "Heal %d health",
		gain_coin = "Gain %d coins",
		lose_coin = "Lose %d coins",
		gain_key = "Gain %d keys",
		lose_key = "Lose %d keys",
		gain_bomb = "Gain %d bombs",
		lose_bomb = "Lose %d bombs",
		gain_item = "spawn a random item",
		lose_item = "remove a random item",
	},
}

local morph_text = {
	zh_cn = {
		name = {
			{"忒","修","斯","之","印"},
			{"此","船","非","彼","船"},
			{"旧","名","新","印","痕"},
			{"谁","仍","是","原","样"},
		},
		desc = {
			{"船","已","不","是","船"},
			{"条","款","正","改","写"},
			{"旧","我","被","替","换"},
			{"名","字","仍","漂","流"},
		},
	},
	en_us = {
		name = {
			{"T","h","e","s","e","u","s"},
			{"N","o","t","S","a","m","e"},
			{"N","e","w","S","h","i","p"},
			{"R","e","b","u","i","l","t"},
		},
		desc = {
			{"S","t","i","l","l"," ","s","h","i","p","?"},
			{"T","e","r","m","s"," ","d","r","i","f","t"},
			{"O","l","d"," ","s","e","l","f","?","?","?"},
			{"N","a","m","e"," ","s","h","i","f","t","s"},
		},
	},
}

local function join_chars(chars)
	return table.concat(chars or {})
end

local function lang_key()
	local language = auxi.get_EID_language and auxi.get_EID_language() or "en_us"
	if language == "zh_cn" or language == "zh" then return "zh_cn" end
	return "en_us"
end

local function option_lang_key()
	local language = Options and Options.Language
	if language == "zh_cn" or language == "zh" then return "zh_cn" end
	return "en_us"
end

local function random_from(tbl,rng)
	if rng then return tbl[rng:RandomInt(#tbl) + 1] end
	return tbl[math.random(#tbl)]
end

local function ensure_anim_state()
	save.elses[item.own_key.."anim"] = save.elses[item.own_key.."anim"] or {}
	local state = save.elses[item.own_key.."anim"]
	for lang,info in pairs(morph_text) do
		state[lang] = state[lang] or {
			name = auxi.deepCopy(info.name[1]),
			desc = auxi.deepCopy(info.desc[1]),
		}
	end
	return state
end

local function step_chars(current,target,rng)
	local diff = {}
	for i = 1,#target do
		if current[i] ~= target[i] then table.insert(diff,i) end
	end
	if #diff > 0 then
		local chosen = rng and diff[rng:RandomInt(#diff) + 1] or diff[math.random(#diff)]
		current[chosen] = target[chosen]
	end
end

local function step_anim_text(rng)
	local state = ensure_anim_state()
	for lang,info in pairs(morph_text) do
		step_chars(state[lang].name,random_from(info.name,rng),rng)
		step_chars(state[lang].desc,random_from(info.desc,rng),rng)
	end
end

local function get_anim_text(language)
	local anim = ensure_anim_state()[language or "en_us"] or ensure_anim_state().en_us
	return join_chars(anim.name),join_chars(anim.desc)
end

local function clone_clause(clause)
	return auxi.deepCopy(clause)
end

local function threshold_for_clause(clause)
	local trigger = clause.trigger
	local resource = string.match(trigger,"^gain_(.+)$") or string.match(trigger,"^lose_(.+)$")
	local info = resource and item.resource_types[resource]
	if info then return math.max(1,clause.value * info.factor + (clause.offset or 0)) end
	return clause.value
end

local function new_clause(kind,trigger,value)
	return {
		kind = kind,
		trigger = trigger,
		value = value,
		base = value,
		min_value = math.max(1,value - 1),
		offset = 0,
		count = 0,
	}
end

local function ensure_player_state(player)
	save.elses[item.own_key.."players"] = save.elses[item.own_key.."players"] or {}
	local idx = player:GetData().__Index
	if not idx then return nil end
	save.elses[item.own_key.."players"][idx] = save.elses[item.own_key.."players"][idx] or {
		clauses = {
			new_clause("gain_item","damage",4),
			new_clause("lose_item","heal",5),
		},
	}
	for _,clause in ipairs(save.elses[item.own_key.."players"][idx].clauses or {}) do
		if clause.min_value == nil then clause.min_value = math.max(1,(clause.base or clause.value or 1) - 1) end
	end
	return save.elses[item.own_key.."players"][idx],idx
end

local function set_resource_offset(clause,rng)
	local resource = string.match(clause.trigger,"^gain_(.+)$") or string.match(clause.trigger,"^lose_(.+)$")
	local info = resource and item.resource_types[resource]
	if info then
		clause.offset = rng:RandomInt(info.spread * 2 + 1) - info.spread
	else
		clause.offset = 0
	end
end

local function preserve_progress(clause,old_threshold,old_count)
	local new_threshold = threshold_for_clause(clause)
	if old_threshold and old_threshold > 0 then
		local ratio = math.max(0,math.min(1,(old_count or 0) / old_threshold))
		clause.count = math.floor(ratio * new_threshold)
		if clause.count >= new_threshold then clause.count = math.max(0,new_threshold - 1) end
	end
end

local function mutate_clause(player)
	local state = ensure_player_state(player)
	if not state or not state.clauses then return end
	local rng = player:GetCollectibleRNG(item.entity)
	local clause = state.clauses[rng:RandomInt(#state.clauses) + 1]
	local old_clause = clone_clause(clause)
	local old_threshold = threshold_for_clause(clause)
	local old_count = clause.count or 0
	local mode = rng:RandomInt(3) + 1
	if mode == 1 then
		local delta = rng:RandomInt(2) == 0 and -1 or 1
		if (clause.value or clause.base or 1) <= (clause.min_value or clause.base or 1) and delta < 0 then delta = 1 end
		clause.value = math.max(clause.min_value or clause.base or 1,(clause.value or clause.base or 1) + delta)
	elseif mode == 2 then
		local old = clause.trigger
		local candidates = {}
		for _,trigger in ipairs(trigger_order) do
			if trigger ~= old then table.insert(candidates,trigger) end
		end
		clause.trigger = candidates[rng:RandomInt(#candidates) + 1]
		set_resource_offset(clause,rng)
	else
		local sign,resource = string.match(clause.trigger,"^(gain)_(.+)$")
		if sign then
			clause.trigger = "lose_"..resource
		else
			sign,resource = string.match(clause.trigger,"^(lose)_(.+)$")
			if sign then
				clause.trigger = "gain_"..resource
			else
				local candidates = {}
				for _,trigger in ipairs(trigger_order) do
					if trigger ~= clause.trigger then table.insert(candidates,trigger) end
				end
				clause.trigger = candidates[rng:RandomInt(#candidates) + 1]
				set_resource_offset(clause,rng)
			end
		end
	end
	preserve_progress(clause,old_threshold,old_count)
	return old_clause,clone_clause(clause),state
end

local function run_clause_effect(player,clause)
	if clause.kind == "gain_item" then
		local room = Game():GetRoom()
		local pickup = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
		if pickup then auxi.initialize_item(pickup) end
	elseif clause.kind == "lose_item" then
		player:GetData().should_theseus_remove_sign = true
	end
end

local show_clause_update
local show_clause_progress

local function advance_trigger(player,trigger,amount)
	if amount <= 0 then return end
	local state = ensure_player_state(player)
	if not state or not state.clauses then return end
	for _,clause in ipairs(state.clauses) do
		if clause.trigger == trigger then
			local old_clause = clone_clause(clause)
			clause.count = (clause.count or 0) + amount
			local threshold = threshold_for_clause(clause)
			if clause.count >= threshold then
				clause.count = 0
				run_clause_effect(player,clause)
				local old_clause,new_clause = mutate_clause(player)
				show_clause_update(player,old_clause,new_clause)
			else
				show_clause_progress(player,old_clause,clone_clause(clause))
			end
		end
	end
end

local function describe_clause(clause,language)
	local texts = trigger_text[language] or trigger_text.en_us
	local threshold = threshold_for_clause(clause)
	local count = math.min(clause.count or 0,threshold)
	if language == "zh_cn" then
		return string.format("#{{Timer}} %s：%s（%d/%d）",string.format(texts[clause.trigger] or "%d",threshold),texts[clause.kind] or "",count,threshold)
	end
	return string.format("#{{Timer}} %s: %s (%d/%d)",string.format(texts[clause.trigger] or "%d",threshold),texts[clause.kind] or "",count,threshold)
end

local function describe_clause_plain(clause,language)
	local texts = trigger_text[language] or trigger_text.en_us
	local threshold = threshold_for_clause(clause)
	local count = math.min(clause.count or 0,threshold)
	local trigger = string.format(texts[clause.trigger] or "%d",threshold)
	local effect = texts[clause.kind] or ""
	if language == "zh_cn" then
		return string.format("%s -> %s（%d/%d）",trigger,effect,count,threshold)
	end
	return string.format("%s -> %s (%d/%d)",trigger,effect,count,threshold)
end

local function get_trigger_label(clause,language)
	local texts = trigger_text[language] or trigger_text.en_us
	local threshold = threshold_for_clause(clause)
	return string.format(texts[clause.trigger] or "%d",threshold)
end

local function get_action_label(clause,language)
	local texts = trigger_text[language] or trigger_text.en_us
	return texts[clause.kind] or ""
end

local function get_progress_label(clause)
	local threshold = threshold_for_clause(clause)
	return tostring(math.min(clause.count or 0,threshold)).."/"..tostring(threshold)
end

local function get_trigger_icon(clause)
	if clause.trigger == "damage" then return "damage" end
	if clause.trigger == "heal" then return "heal" end
	local resource = string.match(clause.trigger,"^gain_(.+)$") or string.match(clause.trigger,"^lose_(.+)$")
	return resource or "damage"
end

local function get_action_icon(clause)
	if clause.kind == "gain_item" then return "gain_item" end
	return "lose_item"
end

local icon_paths = {
	damage = "gfx/005.016_black heart.anm2",
	heal = "gfx/005.011_heart.anm2",
	coin = "gfx/005.021_penny.anm2",
	key = "gfx/005.031_key.anm2",
	bomb = "gfx/005.041_bomb.anm2",
}

local function get_icon_sprite(icon)
	item.icon_sprites[icon] = item.icon_sprites[icon] or {}
	local cached = item.icon_sprites[icon]
	if cached.sprite then return cached.sprite end
	if icon == "gain_item" or icon == "lose_item" then
		cached.sprite = auxi.load_item(item.entity)
	else
		local s = Sprite()
		s:Load(icon_paths[icon] or icon_paths.damage,true)
		s:Play("Idle",true)
		cached.sprite = s
	end
	cached.sprite.Scale = Vector(0.38,0.38)
	return cached.sprite
end

local function render_icon(icon,pos,alpha,color)
	local sprite = get_icon_sprite(icon)
	if not sprite then return end
	color = color or Color(1,1,1,1)
	sprite.Color = Color(color.R,color.G,color.B,alpha,color.RO or 0,color.GO or 0,color.BO or 0)
	sprite:Render(pos,Vector(0,0),Vector(0,0))
end

local function queue_clause_notice(player,old_clause,new_clause,notice_type)
	if not player or not old_clause or not new_clause then return end
	local idx = player:GetData().__Index
	save.elses[item.own_key.."notices"] = save.elses[item.own_key.."notices"] or {}
	table.insert(save.elses[item.own_key.."notices"],{
		old = clone_clause(old_clause),
		new = clone_clause(new_clause),
		type = notice_type or "rewrite",
		player_idx = idx,
		frame = 0,
	})
end

show_clause_update = function(player,old_clause,new_clause)
	queue_clause_notice(player,old_clause,new_clause,"rewrite")
end

show_clause_progress = function(player,old_clause,new_clause)
	queue_clause_notice(player,old_clause,new_clause,"progress")
end

local function clamp01(v)
	return math.max(0,math.min(1,v or 0))
end

local function get_notice_player(notice)
	if notice and notice.player_idx then
		for playerNum = 1,Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			if player and player:GetData().__Index == notice.player_idx then return player end
		end
	end
	return Game():GetPlayer(0)
end

local function sign_color(clause,is_action,alpha)
	local kind = is_action and clause.kind or clause.trigger
	if kind == "gain_item" or kind == "heal" or string.match(kind or "","^gain_") then
		return Color(0.35,1,0.45,alpha,0,0,0)
	end
	if kind == "lose_item" or kind == "damage" or string.match(kind or "","^lose_") then
		return Color(1,0.32,0.28,alpha,0,0,0)
	end
	return Color(1,1,1,alpha,0,0,0)
end

local function get_debug_options()
	local root = save.ModConfigSettings
	local debug = root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
	return debug or {}
end

local token_option_keys = {
	source = {y = "TheseusNoticeSourceY",scale = "TheseusNoticeSourceScale",default_y = 0,default_scale = 0.5},
	colon = {y = "TheseusNoticeColonY",scale = "TheseusNoticeColonScale",default_y = -7.25,default_scale = 1},
	amount = {y = "TheseusNoticeAmountY",scale = "TheseusNoticeAmountScale",default_y = -7.25,default_scale = 1},
	trigger = {y = "TheseusNoticeTriggerY",scale = "TheseusNoticeTriggerScale",default_y = -3,default_scale = 0.5},
	arrow = {y = "TheseusNoticeArrowY",scale = "TheseusNoticeArrowScale",default_y = -6,default_scale = 1},
	action = {y = "TheseusNoticeActionY",scale = "TheseusNoticeActionScale",default_y = -0.75,default_scale = 0.5},
	progress = {y = "TheseusNoticeAmountY",scale = "TheseusNoticeAmountScale",default_y = -7.25,default_scale = 1},
}

local function get_token_adjust(key)
	local info = token_option_keys[key] or {}
	local debug = get_debug_options()
	return tonumber(debug[info.y]) or info.default_y or 0,tonumber(debug[info.scale]) or info.default_scale or 1
end

local function render_small_text(text,pos,alpha,color,scale)
	local kcol = KColor(color.R,color.G,color.B,alpha)
	gui.draw_ch(pos,text,scale or 1,scale or 1,kcol,true,gui.f)
end

local function text_width(text)
	return math.max(7,#tostring(text or "") * 5)
end

local function make_clause_tokens(clause,paired_clause,show_progress)
	local threshold = tostring(threshold_for_clause(clause))
	local paired_threshold = paired_clause and tostring(threshold_for_clause(paired_clause)) or threshold
	local trigger_color = sign_color(clause,false,1)
	local action_color = sign_color(clause,true,1)
	local tokens = {
		{key = "source",type = "icon",value = "gain_item",width = 15,color = Color(0.85,0.85,1,1)},
		{key = "colon",type = "text",value = ":",width = 8,color = Color(1,1,1,1)},
		{key = "amount",type = "text",value = threshold,width = math.max(9,text_width(threshold),text_width(paired_threshold)),color = trigger_color},
		{key = "trigger",type = "icon",value = get_trigger_icon(clause),width = 15,color = trigger_color},
		{key = "arrow",type = "text",value = "->",width = 18,color = Color(1,1,1,1)},
		{key = "action",type = "icon",value = get_action_icon(clause),width = 15,color = action_color},
	}
	if show_progress then
		local progress = "("..get_progress_label(clause)..")"
		local paired_progress = paired_clause and "("..get_progress_label(paired_clause)..")" or progress
		table.insert(tokens,{key = "progress",type = "text",value = progress,width = math.max(text_width(progress),text_width(paired_progress)) + 4,color = Color(1,1,1,1)})
	end
	return tokens
end

local function token_changed(old_token,new_token)
	if not old_token or not new_token then return true end
	return old_token.value ~= new_token.value or old_token.color.R ~= new_token.color.R or old_token.color.G ~= new_token.color.G or old_token.color.B ~= new_token.color.B
end

local function render_token(token,pos,alpha)
	if not token or alpha <= 0 then return end
	local color = token.color or Color(1,1,1,1)
	local y_offset,scale = get_token_adjust(token.key)
	if token.type == "icon" then
		local sprite = get_icon_sprite(token.value)
		if sprite then sprite.Scale = Vector(scale,scale) end
		render_icon(token.value,pos + Vector(6,6 + y_offset),alpha,color)
	else
		render_small_text(token.value,pos + Vector(0,-2 + y_offset),alpha,color,scale)
	end
end

local function notice_roll_state(age)
	local hold = 55
	local appear = 35
	local roll = 38
	local fade = 36
	if age < hold then
		return "hold",0
	elseif age < hold + appear then
		return "appear",(age - hold) / appear
	elseif age < hold + appear + roll then
		return "roll",(age - hold - appear) / roll
	elseif age < hold + appear + roll + fade then
		return "fade",(age - hold - appear - roll) / fade
	end
	return "done",1
end

local function render_slot_token(old_token,new_token,pos,opacity,age)
	local line_height = 13
	local changed = token_changed(old_token,new_token)
	if not changed then
		render_token(new_token,pos,opacity)
		return
	end
	local state,p = notice_roll_state(age)
	p = clamp01(p)
	if state == "hold" then
		render_token(old_token,pos,opacity)
	elseif state == "appear" then
		render_token(old_token,pos,opacity)
		render_token(new_token,pos + Vector(0,-line_height),opacity * p)
	elseif state == "roll" then
		render_token(old_token,pos + Vector(0,line_height * p),opacity)
		render_token(new_token,pos + Vector(0,-line_height + line_height * p),opacity)
	elseif state == "fade" then
		render_token(new_token,pos,opacity)
		render_token(old_token,pos + Vector(0,line_height),opacity * (1 - p))
	else
		render_token(new_token,pos,opacity)
	end
end

local function notice_height(notice)
	if notice and notice.type == "rewrite" then return 30 end
	return 17
end

local function token_total_width(tokens,paired_tokens)
	local total_width = 0
	for i = 1,#tokens do
		total_width = total_width + math.max(tokens[i].width,(paired_tokens and paired_tokens[i] and paired_tokens[i].width) or 0)
	end
	return total_width
end

local function render_progress_notice(notice,player,pos,opacity,age)
	local old_clause = notice.old
	local new_clause = clone_clause(notice.new)
	local duration = 42
	local p = clamp01(age / duration)
	local old_count = old_clause.count or 0
	local new_count = notice.new.count or 0
	new_clause.count = math.floor(old_count + (new_count - old_count) * p)
	if p >= 1 then new_clause.count = new_count end
	local tokens = make_clause_tokens(new_clause,notice.new,true)
	for i = 1,#tokens do
		render_token(tokens[i],pos,opacity)
		pos = pos + Vector(tokens[i].width,0)
	end
end

local function render_notice(notice,y_offset)
	local age = notice.frame or 0
	local duration = item.notice_duration
	local opacity = math.min(1,age / 18)
	opacity = math.min(opacity,(duration - age) / item.notice_fade)
	opacity = clamp01(opacity)
	if opacity <= 0 then return end
	local player = get_notice_player(notice)
	if not player then return end
	local old_clause = notice.old
	local new_clause = notice.new
	local old_tokens = make_clause_tokens(old_clause,new_clause,notice.type == "progress")
	local new_tokens = make_clause_tokens(new_clause,old_clause,notice.type == "progress")
	local total_width = token_total_width(new_tokens,old_tokens)
	local pos = Isaac.WorldToScreen(player.Position + player.PositionOffset) + Vector(-total_width * 0.5,-58 - (y_offset or 0))
	if notice.type == "progress" then
		render_progress_notice(notice,player,pos,opacity,age)
		return
	end
	for i = 1,#new_tokens do
		local width = math.max(old_tokens[i].width,new_tokens[i].width)
		render_slot_token(old_tokens[i],new_tokens[i],pos,opacity,age)
		pos = pos + Vector(width,0)
	end
end

local function render_static_clause(clause,player,y_offset,alpha)
	if not clause or not player then return end
	local tokens = make_clause_tokens(clause,clause,true)
	local total_width = token_total_width(tokens)
	local pos = Isaac.WorldToScreen(player.Position + player.PositionOffset) + Vector(-total_width * 0.5,-58 - (y_offset or 0))
	for i = 1,#tokens do
		render_token(tokens[i],pos,alpha or 1)
		pos = pos + Vector(tokens[i].width,0)
	end
end

local function get_desc_player()
	return auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player and auxi.has_have_coll(player,item.entity) then
		advance_trigger(player,"damage",1)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_BASIC, params = nil,
Function = function(_,player,changetype,count)
	if not auxi.has_have_coll(player,item.entity) then return end
	if item.heart_changetypes[changetype] and count > 0 then
		advance_trigger(player,"heal",count)
	elseif item.resource_types[changetype] then
		if count > 0 then
			advance_trigger(player,"gain_"..changetype,count)
		elseif count < 0 then
			advance_trigger(player,"lose_"..changetype,-count)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		ensure_player_state(player)
		if player:IsExtraAnimationFinished() and player:GetData().should_theseus_remove_sign then
			local id = auxi.get_random_item_that_player_has(player,player:GetCollectibleRNG(item.entity),{ignore_pocket_item = true,})
			if id then
				auxi.spawn_item_dust(player,player.Position,id,Color(-1,-1,-1,1),nil,nil)
				player:RemoveCollectible(id)
				player:AnimateSad()
			end
			player:GetData().should_theseus_remove_sign = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function()
	for playerNum = 1,Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player and auxi.has_have_coll(player,item.entity) then
			local old_clause,new_clause = mutate_clause(player)
			show_clause_update(player,old_clause,new_clause)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	local rng = RNG()
	rng:SetSeed(Game():GetSeeds():GetStartSeed() + Game():GetFrameCount(),35)
	step_anim_text(rng)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function()
	if not Game():GetHUD():IsVisible() then return end
	local notices = save.elses[item.own_key.."notices"]
	local y_offset = 0
	if notices then
		for i = #notices,1,-1 do
			local notice = notices[i]
			if notice.frame and notice.frame <= item.notice_duration then
				render_notice(notice,y_offset)
				notice.frame = notice.frame + 1
				y_offset = y_offset + notice_height(notice)
			else
				table.remove(notices,i)
			end
		end
	end
	if get_debug_options().TheseusNoticeAlwaysShow == true then
		for playerNum = 1,Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			if player and auxi.has_have_coll(player,item.entity) then
				local state = ensure_player_state(player)
				if state and state.clauses then
					for i,clause in ipairs(state.clauses) do
						render_static_clause(clause,player,y_offset,0.95)
						y_offset = y_offset + 17
					end
				end
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if not continue then
		save.elses[item.own_key.."players"] = {}
		save.elses[item.own_key.."anim"] = nil
		save.elses[item.own_key.."notices"] = nil
	end
	save.elses[item.own_key.."players"] = save.elses[item.own_key.."players"] or {}
	save.elses[item.own_key.."notices"] = save.elses[item.own_key.."notices"] or {}
	ensure_anim_state()
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = "Item",
Function = function(_,player,tp,id,value)
	if id == item.entity then
		local name,desc = get_anim_text(option_lang_key())
		return {Name = name,Description = desc,}
	end
end,
})

if EID then
	EID:addDescriptionModifier("qing_item_sync"..tostring(item.entity), function(desc)
		return desc.ObjType == 5 and desc.ObjVariant == 100 and desc.ObjSubType == item.entity
	end, function(desc)
		local language = lang_key()
		local name = get_anim_text(language)
		desc.Name = name
		local player = get_desc_player()
		local state = player and ensure_player_state(player)
		if state and state.clauses then
			local header = language == "zh_cn" and "#{{Collectible"..tostring(item.entity).."}} 当前条款：" or "#{{Collectible"..tostring(item.entity).."}} Current clauses:"
			local info = header
			for _,clause in ipairs(state.clauses) do
				info = info..describe_clause(clause,language)
			end
			EID:appendToDescription(desc,info)
		end
		return desc
	end)
end

return item

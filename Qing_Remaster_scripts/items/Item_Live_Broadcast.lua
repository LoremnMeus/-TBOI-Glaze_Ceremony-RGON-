local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local data4 = require("Qing_Remaster_scripts.translations.data4")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local record_holder = require("Qing_Remaster_scripts.others.Record_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")

local function can_afford_visible_price(player,price)
	if not player or price == nil or price == 0 or price == (PickupPrice and PickupPrice.PRICE_FREE or -1000) then return true end
	if price > 0 then return player:GetNumCoins() >= price end
	if price == -1 or price == -2 or price == -4 or price == -9 then
		return player:GetEffectiveMaxHearts() + player:GetBoneHearts() * 2 >= 2
	end
	return true
end

local function has_working_donation_machine()
	if Game():GetRoom():GetType() ~= RoomType.ROOM_SHOP then return false end
	local donation_variant = SlotVariant and SlotVariant.DONATION_MACHINE or 8
	for _,entity in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT,donation_variant,-1,false,false)) do
		local sprite = entity:GetSprite()
		local animation = string.lower(sprite:GetAnimation() or "")
		local destroyed = animation:find("broken",1,true) or animation:find("death",1,true)
			or animation:find("jam",1,true)
		if REPENTOGON and entity.ToSlot then
			local slot = entity:ToSlot()
			destroyed = destroyed or (slot and slot:GetState() == (SlotState and SlotState.DESTROYED or 3))
		end
		if entity:Exists() and not entity:IsDead() and not destroyed then return true end
	end
	return false
end

local function get_collectible_reference(player,pickup,blind,name)
	if not blind and name and name ~= "" then
		return name,name
	end
	local delta = pickup.Position - player.Position
	if math.abs(delta.X) > math.abs(delta.Y) then
		if delta.X < 0 then return "左边的道具","the item on the left" end
		return "右边的道具","the item on the right"
	end
	if delta.Y < 0 then return "上边的道具","the item above" end
	return "下边的道具","the item below"
end

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	pre_myToCall = {},
	myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Live_Broadcast,
	own_key = "Item_Live_Broad_",
	color_offset = {
		[1] = Color(1,1,1,1),
		[2] = Color(0.4,1,0.8,1),
		[3] = Color(0.4,0.76,0.87,1),
		[4] = Color(0.3,0.38,1,1),
		[5] = Color(0.57,0.38,1,1),
		[6] = Color(0.73,0.34,0.52,1),
		[7] = Color(1,0.54,0.09,1),
		[8] = Color(1,1,0.1,1),
	},
	heat_list = {
		[1] = {delay = 250,bust = 1,steak = 0.02,buff = 0.5,gift = 0.3,},
		[2] = {delay = 75,bust = 3,steak = 0.1,buff = 0.8,gift = 0.5,},
		[3] = {delay = 30,bust = 12,steak = 0.25,buff = 1,gift = 0.8,},
		[4] = {delay = 15,bust = 60,steak = 0.65,buff = 1.5,gift = 1,},
		[5] = {delay = 7,bust = 360,steak = 0.90,buff = 2,gift = 1.3,},
		[6] = {delay = 5,bust = 2520,steak = 0.98,buff = 5,gift = 1.7,},
		[7] = {delay = 3,bust = 20160,steak = 0.99,buff = 10,gift = 2,},
	},
	event_list = {			--事件的消散一般总是悄无声息，因此不需要对remove进行处理
		[1] = {								--运气不错
			normal_ret = function()
				local ret = {tp = 5,vr = 1,}
				local rnd =  math.random(1000)
				if rnd > 980 then ret.vr = 2
				elseif rnd > 950 then ret.vr = 3
				elseif rnd > 925 then ret.vr = 4
				elseif rnd > 900 then ret.vr = 5
				elseif rnd > 850 then ret.tp = 3;ret.vr = 4
				end
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				local rnd = math.random(10) + 10
				rnd = math.ceil(buff * rnd)
				table.insert(buf,{tp = 5,vr = 1,counter = rnd,})
				hht(nil,rnd)
				if params.typename == "item" then
					local rnd = math.random(3) + 5
					table.insert(buf,{tp = 3,vr = 5,counter = rnd,params = {name = params.itemname,}})
					hht(nil,rnd)
				end
				return true
			end,
		},
		[2] = {								--操作优秀
			normal_ret = function()
				local ret = {tp = 6,}
				return ret
			end,
			on_update = nil,
			on_pickup = nil,
		},
		[3] = {								--运气不佳
			normal_ret = function()
				local ret = {tp = 1,}
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				if math.random(1000) > 950 then
					local rnd = math.random(3) + 5
					rnd = math.ceil(buff * rnd)
					table.insert(buf,{tp = 1,counter = rnd,})
					hht(nil,rnd)
				else
					local rnd = math.random(1) + 1
					rnd = math.ceil(buff * rnd)
					table.insert(buf,{tp = 1,counter = rnd,})
					hht(nil,rnd)
				end
				if params.typename == "pill" then
					local rnd = math.random(3)
					rnd = math.ceil(buff * rnd)
					table.insert(buf,{tp = 4,vr = 5,counter = rnd,})
					hht(nil,rnd)
				end
				return true
			end,
		},
		[4] = {								--操作不佳
			normal_ret = function()
				local ret = {tp = 1,}
				if math.random(1000) > 800 then 
					ret = {tp = 3,vr = auxi.random_in_table({1,3,4,6,7})}
				end
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				if math.random(1000) > 950 then
					local rnd = math.random(2) + 3
					rnd = math.ceil(buff * rnd)
					for i = 1,rnd do
						table.insert(buf,{tp = 3,vr = auxi.random_in_table({1,3,4,6,7}),counter = 1,})
					end
					hht(nil,rnd)
				else
					local rnd = auxi.choose(0,0,0,1,2)
					rnd = math.ceil(buff * rnd)
					for i = 1,rnd do
						table.insert(buf,{tp = 3,vr = auxi.random_in_table({1,3,4,6,7}),counter = 1,})
					end
					hht(nil,rnd)
				end
				return true
			end,
		},
		[5] = {								--考试开始
			normal_ret = function()
				local ret = {tp = 8,}
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				if math.random(1000) > 500 then
					local rnd = math.random(3) + 5
					rnd = math.ceil(buff * rnd)
					table.insert(buf,{tp = 8,counter = rnd,})
					hht(nil,rnd)
				else
					local rnd = math.random(1) + 1
					rnd = math.ceil(buff * rnd)
					table.insert(buf,{tp = 8,counter = rnd,})
					hht(nil,rnd)
				end
				return true
			end,
		},
		[6] = {								--危机时刻
			normal_ret = function()
				local ret = {tp = 7,}
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				if params.weigh > 4 then 
					local rnd = math.random(4) + 4
					rnd = math.ceil(buff * rnd)
					table.insert(buf,{tp = 7,counter = rnd,})
					hht(nil,rnd)
				end
			end,
		},
		[7] = {								--开始直播
			normal_ret = function()
				local ret = {tp = 2,}
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				local rnd = math.random(10) + 10
				rnd = math.ceil(buff * rnd)
				table.insert(buf,{tp = 2,counter = rnd,})
				hht(nil,rnd)
				return true
			end,
		},
		[8] = {								--结束直播
			normal_ret = function()
				local ret = {tp = 14,}
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				local rnd = math.random(15) + 10
				rnd = math.ceil(buff * rnd)
				table.insert(buf,{tp = 14,counter = rnd,})
				hht(nil,rnd)
				return true
			end,
		},
		[9] = {								--角色死亡
			normal_ret = function()
				local ret = {tp = 11,}
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				local rnd = math.random(10) + 10
				rnd = math.ceil(buff * rnd)
				table.insert(buf,{tp = 11,counter = rnd,})
				hht(nil,rnd)
				return true
			end,
		},
		[10] = {							--为何不拿
			normal_ret = function()
				local ret = {tp = 5,}
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff,info,item)
				local function add_context_comment(variant,count)
					count = math.max(1,math.ceil(buff * (count or math.random(2))))
					table.insert(buf,{tp = 17,vr = variant,counter = count,params = params,})
					hht(nil,count)
				end
				local rnd = math.random(2) + 1
				rnd = math.ceil(buff * rnd)
				table.insert(buf,{tp = 5,vr = 1,counter = rnd,})
				hht(nil,rnd)
				if params.typename == "item" then
					local id = params.id or 33
					local collectibleinfo = Isaac:GetItemConfig():GetCollectible(id)
					local quality = collectibleinfo and collectibleinfo.Quality or 0
					local rnd = 1 + math.random(math.max(1,math.floor(quality * 1.5)))
					if params.unaffordable then rnd = 1 end
					if Game():GetRoom():GetFrameCount() == -1 then 
						if item.limit > 0 then rnd = auxi.choose(0,0,0,math.floor(quality/2),1)
						else rnd = 0 end
						item.limit = (item.limit or 0) - rnd
						--!!		记录，并在下层后提醒
					end
					if rnd > 0 then
						table.insert(buf,{tp = 3,vr = 2,counter = rnd,params = {
							name = params.itemname,
							target_zh = params.target_zh,
							target_en = params.target_en,
						}})
						hht(nil,rnd)
					end
					if params.is_active and params.has_active and not params.blind then add_context_comment(1) end
					if params.unaffordable then
						add_context_comment(2)
						if params.has_donation_machine then add_context_comment(3,1) end
					end
					if params.is_option then
						if params.blind then add_context_comment(7)
						elseif quality >= 3 then add_context_comment(4)
						elseif quality <= 1 then add_context_comment(5)
						else add_context_comment(6) end
					end
				end
				return true
			end,
		},
		[11] = {							--麦片事件
			normal_ret = function()
				local ret = {tp = 9,vr = auxi.random_in_table({2,3})}
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				local rnd = math.random(3)
				rnd = math.ceil(buff * rnd)
				table.insert(buf,{tp = 9,vr = 1,counter = rnd,})
				hht(nil,rnd)
				local cnt = 5
				cnt = math.ceil(buff * cnt)
				for i = 1,cnt do
					delay_buffer.addeffe(function(params)
						local rnd = math.random(3)
						table.insert(buf,{tp = 9,vr = auxi.random_in_table({2,3}),counter = rnd,})
						hht(nil,rnd)
					end,{},(i - 0.5) * 10)
				end
				return true
			end,
		},
		[12] = {							--问路事件
			normal_ret = function()
				local ret = {tp = 4,vr = auxi.random_in_table({3,4})}
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				local rnd = math.random(2)
				rnd = math.ceil(buff * rnd)
				table.insert(buf,{tp = 4,vr = auxi.random_in_table({1,2}),counter = rnd,})
				hht(nil,rnd)
				local cnt = 3
				cnt = math.ceil(buff * cnt)
				for i = 1,cnt do
					delay_buffer.addeffe(function(params)
						local rnd = math.random(3)
						table.insert(buf,{tp = 4,vr = auxi.random_in_table({3,4}),counter = rnd,})
						hht(nil,rnd)
					end,{},(i - 0.5) * 10)
				end
				return true
			end,
		},
		[13] = {							--投喂事件
			normal_ret = function()
				local ret = {tp = 13,vr = 1}
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				params = params or {}
				table.insert(buf,{tp = 13,vr = 2,params = {name = params.name,word = params.word,}})
				local rnd = math.random(2)
				rnd = math.ceil(buff * rnd)
				table.insert(buf,{tp = 13,vr = 1,counter = rnd,params = {name = params.name,}})
				hht(nil,rnd + 1)
				return true
			end,
		},
		[14] = {							--特殊道具
			normal_ret = function()
				local ret = {tp = 5,vr = 1}
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				params = params or {}
				local rnd = math.random(10) + 5
				rnd = math.ceil(buff * rnd)
				table.insert(buf,{tp = 15,counter = rnd,params = {name = params.name,}})
				hht(nil,rnd)
				return true
			end,
		},
		[15] = {							--小罗死亡
			normal_ret = function()
				local ret = {tp = 12,}
				return ret
			end,
			on_update = nil,
			on_pickup = function(buf,hht,params,buff)
				params = params or {}
				local rnd = math.random(5) + 2
				rnd = math.ceil(buff * rnd)
				table.insert(buf,{tp = 12,counter = rnd,})
				hht(nil,rnd)
				return true
			end,
		},
		[16] = {							--长期不操作
			normal_ret = function()
				local ret = {tp = 10,}
				return ret
			end,
			on_update = nil,
			on_pickup = nil,
		},
		[17] = {							--死亡证明
			normal_ret = function()
				local ret = {tp = 16,}
				return ret
			end,
			on_update = nil,
			on_pickup = nil,
		},
	},
	event_name_list = {
		["GoodLuck"] = 1,
		["GoodOperate"] = 2,
		["BadLuck"] = 3,
		["BadOperate"] = 4,
		["RedKey"] = 5,
		["Dangerous"] = 6,
		["Start"] = 7,
		["End"] = 8,
		["Death"] = 9,
		["Whynot"] = 10,
	},
	event_weigh = {
		100,50,20,10,5,3,3,2,2,2,1,1,1,1,1,
	},
	feed_name = {
		[1] = {id = 1,name = {zh = "小心心",en = "little hearts",},weigh = 10,},
		[2] = {id = 2,name = {zh = "小花花",en = "little flowers",},weigh = 10,},
		[3] = {id = 3,name = {zh = "这个好诶",en = "cheers",},weigh = 10,},
		[4] = {id = 4,name = {zh = "小电池",en = "little batteries",},weigh = 2,},
	},
	record_items = {
		[CollectibleType.COLLECTIBLE_GENESIS] = {word = "创",},
		[CollectibleType.COLLECTIBLE_MAGIC_SKIN] = {word = "磨",},
		[CollectibleType.COLLECTIBLE_D100] = {word = "Roll",},
		[CollectibleType.COLLECTIBLE_D4] = {word = "Roll",},
		[CollectibleType.COLLECTIBLE_DAMOCLES] = {word = "达摩",},
		[CollectibleType.COLLECTIBLE_WIRE_COAT_HANGER] = {word = "鸭架",},
		[CollectibleType.COLLECTIBLE_C_SECTION] = {word = "剖",},
		[CollectibleType.COLLECTIBLE_LIBRA] = {word = "风",},
		[CollectibleType.COLLECTIBLE_EDENS_BLESSING] = {word = "玫瑰",},
		[CollectibleType.COLLECTIBLE_R_KEY] = {word = "R",},
	},
	event_buffer = {},
	tp_buffer = {},
	block_map = {},
	live_bullets = {},
	live_bullet_soft_limit = 72,
	live_bullet_hard_limit = 120,
	focus_entity = enums.Entities.Feeding_gift,
	gift_infos = {
		[1] = {name = "luck",cache = CacheFlag.CACHE_LUCK,},
		[2] = {name = "tear",cache = CacheFlag.CACHE_FIREDELAY,},
		[3] = {name = "damage",cache = CacheFlag.CACHE_DAMAGE,},
		[4] = {special = function(player)
			for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
				if player:NeedsCharge(slot) then
					local rnd = math.random(3)
					player:SetActiveCharge(player:GetActiveCharge(slot) + player:GetBatteryCharge(slot) + rnd, slot)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE,1,1,false,0,2)
					break
				end
			end
		end,},
	},
	render_frame_offset = {
		[1] = {frame = 0,alpha = 1,},
		[2] = {frame = 0.2,alpha = 0.5,},
		[3] = {frame = 0.6,alpha = 0.2,},
		[4] = {frame = 1,alpha = 0.5,},
		[5] = {frame = 1.5,alpha = 1,},
	},
}

local function get_live_language()
	local language = string.lower(tostring((Options and Options.Language) or "en"))
	if language == "zh" or language == "zh_cn" or language == "chinese" or string.sub(language,1,2) == "zh" then
		return "zh"
	end
	return "en"
end

local function get_live_option(key,default)
	local root = ModConfig.ModConfigSettings or {}
	local options = root.QingRemasterOptions and root.QingRemasterOptions.Live
	local value = options and tonumber(options[key])
	return value or default
end

local function get_player_with_live()
	local frame = Game():GetFrameCount()
	if item.live_player_cache_frame == frame then return item.live_player_cache end
	item.live_player_cache_frame = frame
	if ModConfig.ModConfigSettings.Auto_Live then
		item.live_player_cache = Game():GetPlayer(0)
	else
		item.live_player_cache = auxi.have_player_has_collectible(item.entity)
	end
	return item.live_player_cache
end

local function has_player_with_live(player)
	if auxi.has_have_coll(player,item.entity) then return true end
	if ModConfig.ModConfigSettings.Auto_Live then return true end
end

if true then
	item.live_sprite = Sprite()
	item.live_sprite:Load("gfx/mimics/Live_Broadcast/Live_sign.anm2",true)
	item.live_sprite:Play("Idle",true)
end

local function get_heat(hea)
	hea = hea or save.elses.Live_heat_counter
	return math.ceil(hea/10)
end

local function get_something_from_heat(hea,sth,offset)
	offset = offset or 1
	sth = sth or "delay"
	hea = get_heat(hea)
	local i = math.log(math.max(1,hea))/math.log(10)
	local ii = math.ceil(i)
	local ret = offset
	if math.random(1000)/1000 > ii - i then
		if item.heat_list[ii] then
			ret = item.heat_list[ii][sth]
		end
	else
		if item.heat_list[ii - 1] then
			ret = item.heat_list[ii - 1][sth]
		end
	end
	return ret
end

local function get_live_message_delay()
	return math.max(1,math.floor(get_something_from_heat(nil,"delay",600) * get_live_option("MessageIntervalScale",1)))
end

local function get_fire_bullet_position(word)
	local sz = auxi.get_string_display_length(word or "")
	local uf = ui.GetScreenTopRight()
	local limit = math.ceil(ui.GetScreenCenter().Y * 0.8 / 10)
	local id = math.random(limit)
	if id > limit / 2 then id = math.random(id) end
	--id = 1
	if (item.block_map[id] or -1000) > Game():GetFrameCount() then
		for i = 1,limit do
			if (item.block_map[i] or -1000) < (item.block_map[id] or -1000) then 
				id = i
				if (item.block_map[id] or -1000) <= Game():GetFrameCount() then break end
			end
		end
	end
	local del_pos_x = math.max(0,(item.block_map[id] or -1000) - Game():GetFrameCount()) * 1.5
	--print(del_pos_x .. " " .. sz)
	if del_pos_x < 60 then
		local ret = Vector(del_pos_x + uf.X,uf.Y + (id - 0.5) * 10)
		item.block_map[id] = math.max(item.block_map[id] or -1000,Game():GetFrameCount()) + sz
		--print(item.block_map[id] .. " " .. Game():GetFrameCount() .. " ".. tostring(sz))
		return ret
	else
		return nil
	end
end

local function get_color_by_level(level,rand)
	local p_level = math.ceil((level + 1)/5)
	if p_level > 8 then p_level = 8 end
	if rand then p_level = math.random(p_level) end
	return item.color_offset[p_level]
end

local function get_level_by_popularity(pop)
	pop = pop or math.max(0,save.elses.Live_popularity_counter)
	local cnt1 = math.ceil(math.log(pop + 2)/math.log(2))
	if cnt1 > 10 and math.random(1000) > 900 then cnt1 = cnt1 + 20 end
	local rnd = math.max(0,math.min(40,math.random(cnt1)))
	return rnd
end

local function fire_bullet_screen(player,level,language,tp,vr,params)			--10帧可以生成3个字符
	level = level or 0
	local bullet_count = #item.live_bullets
	local soft_limit = math.max(1,math.floor(get_live_option("BulletSoftLimit",item.live_bullet_soft_limit)))
	local hard_limit = math.max(soft_limit + 1,math.floor(get_live_option("BulletHardLimit",item.live_bullet_hard_limit)))
	if bullet_count >= hard_limit then return nil end
	if bullet_count >= soft_limit then
		local room = hard_limit - soft_limit
		local acceptance = (hard_limit - bullet_count)/room
		if math.random(1000)/1000 > acceptance then return nil end
	end
	local wd = data4.get_a_word(language,tp,vr,params) or ""
	local col = get_color_by_level(level)
	local pos = get_fire_bullet_position(wd)
	if pos == nil then
		return nil
	else
		table.insert(item.live_bullets,{
			pos = pos,
			dir = Vector(-get_live_option("BulletSpeed",1.5),0),
			word = wd,
			color = col,
			alpha = math.max(0,math.min(1,((1 - pos.Y/ui.GetScreenCenter().Y) + 0.2))),
		})
	end
end

local function render_live_bullets()
	local screen_size = auxi.GetScreenSize()
	local paused = Game():IsPaused()
	local bullet_count = #item.live_bullets
	local scale = math.max(0.1,get_live_option("BulletScale",1))
	local opacity = math.max(0,math.min(1,get_live_option("BulletOpacity",1)))
	local write_index = 1
	for read_index = 1,bullet_count do
		local bullet = item.live_bullets[read_index]
		local ratio = math.max(0,math.min(1,bullet.pos.X/screen_size.X))
		local alpha = bullet.alpha * auxi.check_lerp(ratio,item.render_frame_offset).alpha * opacity
		gui.draw_ch(
			bullet.pos,
			bullet.word,
			scale,
			scale,
			KColor(bullet.color.R,bullet.color.G,bullet.color.B,alpha),
			true
		)
		if not paused then bullet.pos = bullet.pos + bullet.dir end
		local expired = bullet.pos.X < -120 or bullet.pos.Y < -120
			or bullet.pos.X > screen_size.X + 120 or bullet.pos.Y > screen_size.Y + 120
		if not expired then
			item.live_bullets[write_index] = bullet
			write_index = write_index + 1
		end
	end
	for i = bullet_count,write_index,-1 do item.live_bullets[i] = nil end
end

local function hit_heat_burst(cnt1,cnt2)
	cnt1 = cnt1 or 100
	cnt2 = cnt2 or 3
	cnt1 = cnt1 * get_something_from_heat(nil,"bust",1)
	save.elses.Live_popularity_adder = (save.elses.Live_popularity_adder or 0) + cnt1
	save.elses.Live_add_offset = (save.elses.Live_add_offset or 0) + cnt2
end

local function cause_event(tp,weigh,params)
	--print("Cause "..tp)
	params = params or {}
	weigh = weigh or math.random(12)
	params.weigh = params.weigh or weigh
	if type(tp) == "string" then tp = item.event_name_list[tp] or 1 end
	local info = item.event_list[tp]
	local buff = get_something_from_heat(nil,"buff",1)
	buff = (math.random(1000)/1000 * 0.3 + 0.85) * buff
	local should_cause = true
	if info.on_pickup then should_cause = info.on_pickup(item.tp_buffer,hit_heat_burst,params,buff,info,item) end
	if should_cause and Game():GetFrameCount() > 0 then
		table.insert(item.event_buffer,1,{tp = tp,weigh = weigh,params = params})
		if math.random(1000) > math.max(100,950 - weigh * 3 * buff) and params.no_gift ~= true then
			local gift = get_something_from_heat(nil,"gift",1)
			local cnt = math.random(math.ceil(gift * 5))
			local feed_info = auxi.random_in_weighed_table(item.feed_name)
			for i = 1,cnt do
				local q = Isaac.Spawn(1000,item.focus_entity,0,Game():GetRoom():GetRandomPosition(10),Vector(0,0),nil)
				local s = q:GetSprite()
				local d = q:GetData()
				d.type_state = feed_info.id
				s:Play("Idle"..tostring(d.type_state),true)
			end
			local id = auxi.random_in_table(auxi.GetItemList())
			local col = Isaac.GetItemConfig():GetCollectible(id)
			local info = {Name = "",}
			if col then info = item_displaying_holder.check_description("UnItem",id,auxi.check_name_data(col.Name),auxi.check_name_data(col.Description),player) end
			local language = get_live_language()
			local gift_name = feed_info.name[language] or feed_info.name.zh
			local supporter = data4.get_a_description(language)
			local tbl = {}
			if language == "zh" then
				tbl.name = supporter .. "的" .. info.Name
				tbl.word = tostring(cnt) .. "个" .. gift_name
			else
				tbl.name = supporter .. " " .. info.Name
				tbl.word = tostring(cnt) .. " " .. gift_name
			end
			cause_event(13,10,tbl)
		end
	end
	if #item.event_buffer > 7 then table.remove(item.event_buffer,8) end
end

function item.reward(player,tp)
	local idx = player:GetData().__Index
	if idx then
		save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
		save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
		local info = item.gift_infos[tp]
		if info.special then
			info.special(player)
		elseif info.name and info.cache then
			save.elses[item.own_key.."buff"][idx][info.name] = (save.elses[item.own_key.."buff"][idx][info.name] or 0) + math.random(1000)/1000 * 1 + 1
			player:AddCacheFlags(info.cache)
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end

local function get_normal_pr()
	local ret = {tp = 1}
	if math.random(1000) > 900 then ret = {tp = 2} end
	if math.random(1000) > 900 then ret = {tp = 6} end
	if math.random(1000) > 900 then ret = {tp = 3,vr = auxi.random_in_table({1,4,6})} end
	return ret
end

local function get_pr_from_event(mul)
	mul = mul or 5
	local tbl = {}
	for i = 1,#item.event_buffer do
		local v = item.event_buffer[i]
		table.insert(tbl,{tp = v.tp,weigh = v.weigh * (item.event_weigh[i] or 1),params = v.params,id = i})
	end
	if #tbl ~= 0 then
		for i = 1,mul do
			local stag = auxi.random_in_weighed_table(tbl)
			local event_info = item.event_list[stag.tp] or item.event_list[1]
			local ret = auxi.check_if_any(event_info.normal_ret or get_normal_pr(),nil)
			if event_info.on_update then event_info.on_update(item.tp_buffer,hit_heat_burst) end		--事件被选中的时候可能会提升热度。
			item.event_buffer[stag.id].weigh = item.event_buffer[stag.id].weigh - 1
			table.insert(item.tp_buffer,ret)
		end
		for i = #item.event_buffer,1,-1 do
			if item.event_buffer[i].weigh <= 0 then table.remove(item.event_buffer,i) end
		end
	end
end

local function get_bullet_by_random()
	if #item.tp_buffer > 20 then for i = #item.tp_buffer,20,-1 do table.remove(item.tp_buffer,i) end end
	if #item.tp_buffer == 0 then
		get_pr_from_event()
	end
	if item.tp_buffer[1] then
		local info = item.tp_buffer[1]
		item.tp_buffer[1].counter = (item.tp_buffer[1].counter or 0) - 1
		if item.tp_buffer[1].counter <= 0 then
			table.remove(item.tp_buffer,1)
		end
		return info
	else
		return get_normal_pr()
	end
end

local function fire_bullet(player)
	local ret = get_bullet_by_random()
	fire_bullet_screen(player,get_level_by_popularity(),get_live_language(),ret.tp or 1,ret.vr,ret.params)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item.limit = 0
	item.block_map = {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.block_map = {}
	item.live_bullets = {}
	item.live_player_cache_frame = nil
	item.live_player_cache = nil
	save.elses.Live_heat_counter = 0
	save.elses.Live_heat_delay = 0
	save.elses.Live_popularity_adder = 0
	save.elses.Live_add_offset = 0
	item.event_buffer = {}
	item.record_good_item = {}
	item.tp_buffer = {}
	if continue then
	else
		save.elses[item.own_key.."buff"] = {}
		save.elses.Live_popularity_counter = math.min(100,(save.elses.Live_popularity_counter or 0)/100)				--模式1
	end
	local player = get_player_with_live()
	if player then cause_event(7) end
	save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local idx = player:GetData().__Index
	if idx ~= nil then
		save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
		if save.elses[item.own_key.."buff"][idx] then
			if cacheFlag == CacheFlag.CACHE_DAMAGE then
				player.Damage = player.Damage + auxi.get_damage_multiplier(player) * (math.sqrt((save.elses[item.own_key.."buff"][idx].damage or 0) + 4) - 2)
			end
			if cacheFlag == CacheFlag.CACHE_FIREDELAY then
				player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * (math.sqrt((save.elses[item.own_key.."buff"][idx].tear or 0) + 9) - 3))
			end
			if cacheFlag == CacheFlag.CACHE_LUCK then
				player.Luck = player.Luck + (save.elses[item.own_key.."buff"][idx].luck or 0) * 0.33
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = item.focus_entity,
Function = function(_,ent)
	if ent.Variant == item.focus_entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYERONLY
		ent.PositionOffset = Vector(0,-600)
		d.type_state = math.random(4)
		d.rotate_dir = math.random(2) * 2 - 3
		d.rotate_ang = 10 + math.random(1000)/1000 * 5
		s:Play("Idle"..tostring(d.type_state),true)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.focus_entity,
Function = function(_,ent)
	if ent.Variant == item.focus_entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
		if ent.PositionOffset.Y < 0 then
			ent.PositionOffset = ent.PositionOffset + Vector(0,10)
		else
			d.rotate_ang = (d.rotate_ang or 10) * 0.9
		end
		s.Rotation = s.Rotation + (d.rotate_dir or 1) * (d.rotate_ang or 10)
		s:Play("Idle"..tostring(d.type_state or 1),true)
		if ent.PositionOffset.Y > -100 and get_player_with_live() == nil then 
			ent.Color = auxi.AddColor(ent.Color,Color(0,0,0,0),0.98,0.02)
		end
		if ent.PositionOffset.Y >= 0 and (d.rotate_ang or 10) < 3 then
			if get_player_with_live() == nil then ent:Remove() return end
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				if (player.Position - ent.Position):Length() < 15 then
					item.reward(player,d.type_state or 1)
					player:AnimateHappy()
					ent:Remove() 
					return
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 110,
Function = function(_,ent)
	local player = get_player_with_live()
	if player then consistance_holder.try_hold_entity(ent,item.own_key,{ignore_subtype = true,ignore_variant = true}) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 300,		--红隐		--!!
Function = function(_,ent)
	if ent.SubType == Card.CARD_CRACKED_KEY then
		local player = get_player_with_live()
		if player then
			-- 先 claim 再播报：小退 Consistance 命中时不得再 cause_event
			local succ = consistance_holder.try_check_entity(ent,item.own_key)
			if not succ then
				consistance_holder.try_hold_entity(ent,item.own_key,{})
				cause_event(5,math.random(6))
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 100,		--!!
Function = function(_,ent)
	local player = get_player_with_live()
	if player then
		local id = ent.SubType
		if id > 0 then
			local col = Isaac.GetItemConfig():GetCollectible(id)
			if (col and not col:HasTags(1<<15) and auxi.GetDimension() ~= 2) then
				local qual = col.Quality
				local d = ent:GetData()
				local succ = d.first_appear2
				if succ then
					delay_buffer.addeffe(function(params)
						if auxi.check_all_exists(ent) ~= true then return end
						local blind = auxi.isBlindPickup(ent)
						if blind or ent.Touched then
						else
							if qual >= 4 then
								local info = item_displaying_holder.check_description("UnItem",id,auxi.check_name_data(col.Name),auxi.check_name_data(col.Description),player)
								cause_event(1,nil,{typename = "item",itemname = info.Name or "",itemDesc = info.Description or "",})
							end
							if id == CollectibleType.COLLECTIBLE_RED_KEY then cause_event(5,math.random(10) + 4) end
							if item.record_items[id] and item.record_items[id].word then cause_event(14,8,{name = item.record_items[id].word}) end
						end
						record_holder.try_hold(ent,{check = function(et) 
							if et.SubType ~= id then
								if et.SubType <= 0 then
									return true,"Lost"
								else
									return true,"Turn"
								end
							end
							return false,nil
						end,Function = function(tp,et)
							for i = 1,1 do 
								if et.FrameCount <= 0 then break end
								if tp == "Turn" then
									if auxi.have_player_queue_collectible(id) then break end
								elseif tp == "Remove" then
									if et:IsShopItem() then
										if auxi.have_player_queue_collectible(id) then break end
									end
								elseif tp == "Lost" then
									break
								end
								local info = item_displaying_holder.check_description("UnItem",id,auxi.check_name_data(col.Name),auxi.check_name_data(col.Description),player)
								local target_zh,target_en = get_collectible_reference(player,et,blind,info.Name)
								local price = et.Price
								local is_shop_item = et:IsShopItem()
								local unaffordable = is_shop_item and not can_afford_visible_price(player,price)
								cause_event(10,nil,{
									typename = "item",
									itemname = blind and "" or (info.Name or ""),
									itemDesc = blind and "" or (info.Description or ""),
									target_zh = target_zh,
									target_en = target_en,
									id = id,
									ent = et,
									blind = blind,
									is_active = col.Type == ItemType.ITEM_ACTIVE,
									has_active = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) > 0,
									is_option = et.OptionsPickupIndex ~= 0,
									unaffordable = unaffordable,
									payment_kind = price > 0 and "coin" or "heart",
									has_donation_machine = unaffordable and price > 0 and has_working_donation_machine(),
								})
							end
						end,})
					end,{},1)
				end
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,count)
	item.live_player_cache_frame = nil
	item.live_player_cache = nil
	if count > 0 and player:GetCollectibleNum(item.entity,true) == count then
		cause_event(7)
	end
	if player:GetCollectibleNum(item.entity,true) == 0 then
		cause_event(8)
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player then
		if has_player_with_live(player) then
			local d = player:GetData()
			if auxi.is_damage_from_enemy(ent, amt, flag, source, cooldown) then
				cause_event(4,math.random(6) + 1)
				if math.random(1000) > 300 then
					cause_event(3,math.random(3))
				end
				d[item.own_key.."DamageToken"] = 3600
			end
			local now_heart = auxi.get_absolute_heart(player)
			if now_heart - amt <= 1 then
				cause_event(6,math.random(6) + 1)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,rng,pos)
	local player = get_player_with_live()
	if player then
		local level = Game():GetLevel()
		local room = Game():GetRoom()
		local desc = level:GetCurrentRoomDesc()
		if desc.Data.Type == 5 then
			cause_event(2,math.random(8) + 6)
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_USE_PILL, params = nil,
Function = function(_,pill,player,flag)	
	if has_player_with_live(player) then
		if auxi.is_bad_pill(pill) then 
			cause_event(3,math.random(6),{typename = "pill"})
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.LOST_SOUL,
Function = function(_,ent)
	local player = ent.Player
	if player and has_player_with_live(player) then
		local s = ent:GetSprite()
		if s:IsPlaying("Death") and s:GetFrame() == 1 then
			cause_event(15,10)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = 1,
Function = function(_,ent)
	if ent:ToPlayer() then
		local player = ent:ToPlayer()
		if has_player_with_live(player) then
			if auxi.is_found_soul(player) then 
				cause_event(15,16)
			else
				cause_event(9,20)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if has_player_with_live(player) then
		local d = player:GetData()
		local s = player:GetSprite()
		local room = Game():GetRoom()
		d[item.own_key.."DamageToken"] = d[item.own_key.."DamageToken"] or 3600
		if room:IsClear() == false then d[item.own_key.."DamageToken"] = d[item.own_key.."DamageToken"] - 1 end
		if d[item.own_key.."DamageToken"] <= 0 then 
			if math.random(1000) > 990 then
				cause_event(2,math.random(10) + 4)
			end
		end
		if input_holder.all_nill(player) then
			d[item.own_key.."NoAction"] = (d[item.own_key.."NoAction"] or 0) + 1
			if d[item.own_key.."NoAction"] > 900 then
				if math.random(1000) > 800 then
					local tbl = {}
					if math.random(1000) > 100 then tbl.no_gift = true end
					cause_event(16,6,tbl)
				end
			end
		else
			d[item.own_key.."NoAction"] = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local player = get_player_with_live()
	if player then
		local level = Game():GetLevel()
		local room = Game():GetRoom()
		local desc = level:GetCurrentRoomDesc()
		if Game():GetFrameCount() % 10 == 5 then
			save.elses.Live_popularity_counter = (save.elses.Live_popularity_counter or 0) + save.elses.Live_popularity_adder * 0.01
			save.elses.Live_heat_counter = ((save.elses.Live_heat_counter or 0) - save.elses.Live_popularity_counter) * 0.95 + save.elses.Live_popularity_counter + save.elses.Live_popularity_adder * 0.1
			save.elses.Live_popularity_adder = save.elses.Live_popularity_adder * 0.9
		end
		local heat = get_heat()
		if (save.elses.Live_heat_delay or -1) < 0 then
			save.elses.Live_heat_delay = math.random(get_live_message_delay())
			fire_bullet(player)
			save.elses.Live_popularity_counter = (save.elses.Live_popularity_counter or 0) + 1
		else
			if save.elses.Live_heat_delay > get_live_message_delay() + 20 then save.elses.Live_heat_delay = math.random(get_live_message_delay()) end
			save.elses.Live_heat_delay = save.elses.Live_heat_delay - 1
		end
		if (save.elses.Live_add_offset or 0) > 0 and Game():GetFrameCount() % 3 == 1 then		--爆发式的弹幕
			local cnt = math.ceil(save.elses.Live_add_offset / 10)
			for i = 1,cnt do fire_bullet(player) end
			save.elses.Live_add_offset = (save.elses.Live_add_offset or 0) - cnt
			save.elses.Live_heat_counter = save.elses.Live_heat_counter + cnt * 10
		end
		if Game():GetFrameCount() % 60 == 5 or (Game():GetFrameCount() % 45 == 5 and desc.Data.Type == 5) then
			if auxi.is_player_lost(player) then
				if auxi.is_player_has_mantle(player) == false and math.random(1000) > 500 then 
					cause_event(6,math.random(3))
				end
			elseif auxi.get_absolute_heart(player) <= 1 and math.random(1000) > 500 then cause_event(6,1) end
		end
		if auxi.GetDimension() == 2 and save.elses.Live_heat_delay % 30 == 1 then
			if math.random(1000) > 750 then
				cause_event(17,math.random(10))
			end
		end
		if save.elses.Live_heat_delay % 60 == 1 then
			if math.random(1000) > 999 then
				cause_event(11,math.random(10) + 10)
			end
		end
		if save.elses.Live_heat_delay % 35 == 1 then
			if math.random(1000) > 998 then
				cause_event(12,math.random(10) + 10)
			end
		end
		if save.elses.Live_heat_delay % 75 == 1 then
			local cnt = auxi.get_stats_counter(player)
			if math.random(1000) < cnt then
				if math.random(1000) > 900 then
					cause_event(2,math.random(8))
				end
			end
		end
		if save.elses.Live_heat_delay % 65 == 1 then
			local should_test = false
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				for cardslot = 0,2 do
					local cd = player:GetCard(cardslot)
					if cd == Card.CARD_CRACKED_KEY then
						should_test = true
						break
					end
				end
				if should_test then break end
				for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
					if (player:GetActiveItem(slot) == CollectibleType.COLLECTIBLE_RED_KEY) then
						should_test = true
						break
					end
				end
				if should_test then break end
			end
			if should_test then
				if math.random(1000) > 900 then
					cause_event(5,math.random(3))
				end
			end
		end
	end
	
	if Game():GetFrameCount() % 30 == 5 then
		local decay = 0.99 ^ 3
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local idx = player:GetData().__Index
			if idx then
				if save.elses[item.own_key.."buff"][idx] then
					local cache_flags = 0
					for name,value in pairs(save.elses[item.own_key.."buff"][idx]) do
						local next_value = value * decay
						if next_value < 0.001 then next_value = nil end
						save.elses[item.own_key.."buff"][idx][name] = next_value
						local info = name == "damage" and item.gift_infos[3]
							or name == "tear" and item.gift_infos[2]
							or name == "luck" and item.gift_infos[1]
						if info and info.cache then cache_flags = cache_flags | info.cache end
					end
					if cache_flags ~= 0 then
						player:AddCacheFlags(cache_flags)
						player:GetData().should_evaluate_on_update_once = true
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	render_live_bullets()
	local player = get_player_with_live()
	if player then
		local pos = ui.GetScreenBottomLeft()
		item.live_sprite:Render(pos + Vector(10,-10),Vector(0,0),Vector(0,0))
		local counter = get_heat()
		local str = tostring(counter)
		gui.draw_ch(pos + Vector(20,-18) + Vector((#str) / 2,0),str,1,1,KColor(1,1,1,0.5),true)
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_,str,params)
	if string.lower(str) == "live" and params ~= nil then
		local args={}
		for str in string.gmatch(params, "([^ ]+)") do
			table.insert(args, str)
		end
		if args[1] then
			if args[1] and args[1] == "set" and args[2] and tonumber(args[2]) then
				save.elses.Live_popularity_counter = tonumber(args[2])
				print("Successfully set to "..tostring(save.elses.Live_popularity_counter))
			end
			if args[1] and args[1] == "mode" and args[2] and tonumber(args[2]) then
				local md = tonumber(args[2])
				print("Set to " .. tostring(md))
				if md >= 0 and md <= 1 then md = 1 - md end
				data4.set_mode(md)
			end
		end
	end
	if string.lower(str) == "meus" and params ~= nil then
		local args={}
		for str in string.gmatch(params, "([^ ]+)") do
			table.insert(args, str)
		end
		if args[1] then
			if string.lower(args[1]) == "please" then
				if args[2] and args[3] then
					if args[2] == "reset" and args[3] == "live" then
						print("Ok.")
						save.elses.Live_popularity_counter = 0
					end
					if args[2] == "set" and args[3] == "live" and args[4] then
						print("Ok.")
						local num = tonumber(args[4])
						if type(num) == "number" then 
							print("Successfully set it to "..tostring(num))
							save.elses.Live_popularity_counter = num
						end
					end
					if args[2] == "check" and args[3] == "live" then
						print("Ok. "..tostring(save.elses.Live_popularity_counter or 0) .. " " .. tostring(save.elses.Live_heat_counter or 0) .. " " .. tostring(save.elses.Live_popularity_adder or 0) )
					end
				end
			end
		end
	end
end,
})

--打招呼的场合：直播开始后概率逐渐降低
--表示快乐的场合：根据热度进行额外计算；运气不佳
--指指点点的场合：根据热度进行额外计算；血量充裕；见到道具但没有拾取
--云的场合：根据热度进行额外计算；
--发强的场合：残血无伤敌人、瞬间造成大量伤害等
--发问号的场合：遇见4级道具、星象房、低概率开恶魔、见到特殊红房间
--考试的场合：持有红钥匙、碎片、该隐符文等。
--危机的场合：丝血、罗斯特破盾
--小罗死亡的场合
--投喂内容包括：小花花、牛哇牛哇、小心心等，拾取它们可以带来属性小幅提升。
--投喂火箭可以生成一个发射出去的火箭炸弹？
--投喂打call可以提升弹幕量？
--点播内容是固定格式的，要求包括：1.给某一个道具 2.失去某个道具 还可以有更多？

return item

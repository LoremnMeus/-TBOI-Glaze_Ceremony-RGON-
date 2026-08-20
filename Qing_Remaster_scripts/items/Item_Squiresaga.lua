local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local grid_entity = require("Qing_Remaster_scripts.grids.grid_entity")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

-- Grid 统一入口：每次只取一次；nil / 类型不符返回 nil（勿对结果连续解引用而不判空）
-- RGON：空格/过渡帧可能给出「无法索引」的 userdata；禁止用 grid.Method 做存在探测（见 repentogon_holder）。
local SAGA_GRID_KIND = {
	door = function(g) return g.ToDoor and g:ToDoor() end,
	poop = function(g) return g.ToPoop and g:ToPoop() end,
	pit = function(g) return g.ToPit and g:ToPit() end,
	pressureplate = function(g) return g.ToPressurePlate and g:ToPressurePlate() end,
	tnt = function(g) return g.ToTNT and g:ToTNT() end,
	spikes = function(g) return g.ToSpikes and g:ToSpikes() end,
}

local function saga_grid_usable(grid)
	if grid == nil then return false end
	local ok = pcall(function()
		return grid:GetType()
	end)
	return ok == true
end

local function saga_grid_type(grid)
	if not saga_grid_usable(grid) then return nil end
	local ok, t = pcall(function() return grid:GetType() end)
	if ok then return t end
	return nil
end

local function saga_grid_sprite(grid)
	if not saga_grid_usable(grid) then return nil end
	local ok, s = pcall(function() return grid:GetSprite() end)
	if ok then return s end
	return nil
end

local function saga_grid_is_open(grid)
	if not saga_grid_usable(grid) then return false end
	local ok, open = pcall(function() return grid:IsOpen() end)
	return ok and open == true
end

local function saga_get_grid(ent, expected)
	if not ent or type(ent.get_grid) ~= "function" then return nil end
	local ok, grid = pcall(function() return ent:get_grid() end)
	if not ok or not saga_grid_usable(grid) then return nil end
	if expected == nil then return grid end
	if type(expected) == "number" then
		local ok2, gt = pcall(function() return grid:GetType() end)
		if not ok2 or gt ~= expected then return nil end
		return grid
	end
	if type(expected) == "string" then
		local fn = SAGA_GRID_KIND[expected]
		if not fn then return grid end
		local ok2, match = pcall(fn, grid)
		if not ok2 or not match then return nil end
		return grid
	end
	if type(expected) == "function" then
		local ok2, match = pcall(expected, grid)
		if not ok2 or not match then return nil end
		return grid
	end
	return grid
end

local function saga_grid_state_params(descriptor_key, expected)
	return {
		descriptor_key = descriptor_key,
		toget = function(ent)
			local grid = saga_get_grid(ent, expected)
			if not grid then return 0 end
			local ok, st = pcall(function() return grid.State end)
			return (ok and tonumber(st)) or 0
		end,
		tochange = function(ent, val)
			local grid = saga_get_grid(ent, expected)
			if not grid then return end
			pcall(function()
				if grid.Desc then grid.Desc.State = val end
				grid.State = val
			end)
		end,
	}
end

local function saga_grid_sprite_anim_params(descriptor_key, expected)
	return {
		descriptor_key = descriptor_key,
		toget = function(ent)
			local grid = saga_get_grid(ent, expected)
			if not grid then return "" end
			local ok, s = pcall(function() return grid:GetSprite() end)
			if not ok or not s then return "" end
			local ok2, anim = pcall(function() return s:GetAnimation() end)
			return (ok2 and anim) or ""
		end,
		tochange = function(ent, val)
			local grid = saga_get_grid(ent, expected)
			if not grid then return end
			local ok, s = pcall(function() return grid:GetSprite() end)
			if not ok or not s then return end
			pcall(function()
				if s.Play then s:Play(val, true) end
				if s.SetLastFrame then s:SetLastFrame() end
			end)
		end,
	}
end

-- 门 / 陷阱门 / 地窖门 / 尖刺：各自独立 descriptor_key，避免混用
local saga_door_open_params = {
	descriptor_key = "saga_grid:door_open",
	toget = function(ent)
		local grid = saga_get_grid(ent, "door")
		if not grid then return false end
		local ok, open = pcall(function() return grid:IsOpen() end)
		return ok and open == true
	end,
	tochange = function(ent, val)
		local grid = saga_get_grid(ent, "door")
		if not grid then return end
		if val == true then
			pcall(function()
				if grid.Open then grid:Open() end
			end)
		else
			pcall(function()
				local s = grid:GetSprite()
				if s then
					if s.Play then s:Play("Close", true) end
					if s.SetLastFrame then s:SetLastFrame() end
				end
				if grid.Close then grid:Close() end
			end)
		end
	end,
}

local saga_trapdoor_state_params = saga_grid_state_params("saga_grid:trapdoor_state", 17)
local saga_trapdoor_sprite_params = saga_grid_sprite_anim_params("saga_grid:trapdoor_sprite", 17)
local saga_basement_state_params = saga_grid_state_params("saga_grid:basement_state", 18)
local saga_basement_sprite_params = saga_grid_sprite_anim_params("saga_grid:basement_sprite", 18)
local saga_spikes_state_params = saga_grid_state_params("saga_grid:spikes_state", "spikes")
local saga_spikes_sprite_params = saga_grid_sprite_anim_params("saga_grid:spikes_sprite", "spikes")

local Language = {
    current = "zh",  -- 默认语言
    translations = {
        zh = {
            collision = {
                none = "无碰撞",
                player_only = "仅玩家",
                friendly = "友方单位",
                enemies = "敌方单位",
                all = "所有实体",
                pit = "陷坑",
                object = "实物",
                solid = "固体",
                wall = "墙",
                wall_except_player = "可通行墙"
            },
			prices = {
				one_red_heart = "一颗红心",
				two_red_hearts = "两颗红心",
				three_soul_hearts = "三颗魂心",
				one_red_two_soul = "一红心两魂心",
				spike_damage = "被刺扎",
				little_ro = "小罗",
				one_soul_heart = "一颗魂心",
				two_soul_hearts = "两颗魂心",
				one_red_one_soul = "一颗红心一颗魂心",
				free = "零元购！"
			},
			layers = {
				floor = "地板",
				wall = "墙体",
				normal = "正常"
			},
			champions = {
				none = "无",
				red = "红色",
				yellow = "黄色",
				green = "绿色",
				orange = "橙色",
				dark_blue = "深蓝色",
				dark_green = "深绿色",
				pure_white = "纯白色",
				gray = "灰色",
				transparent_white = "透明白色",
				black = "黑色",
				pink = "粉色",
				purple = "紫色",
				dark_red = "深红色",
				light_blue = "浅蓝色",
				camouflage = "保护色",
				blinking_green = "闪烁绿色",
				blinking_gray = "闪烁灰色",
				light_white = "浅白色",
				small = "小",
				large = "大",
				blinking_red = "闪烁红色",
				size_changing = "大小变",
				crown = "皇冠",
				skeleton = "骷髅",
				brown = "棕色",
				rainbow = "彩虹"
			},
			status = {
				seconds = "秒",
				yes = "是",
				no = "否"
			},
			buffs = {
				poison = "中毒",
				charm = "魅惑",
				confusion = "混乱",
				midas_freeze = "点金",
				fear = "恐惧",
				burn = "燃烧",
				shrink = "收缩",
				brimstone_marked = "硫磺印",
				no_reward = "无奖励"
			},
			fireplaces = {
				unknown = "未知火堆",
				normal = "火堆",
				red = "红火堆",
				blue = "蓝火堆",
				purple = "紫火堆",
				white = "白火堆"
			},
			heart_types = {
				unknown = "未知心",
				red = "红心",
				half_red = "半红心",
				soul = "魂心",
				eternal = "白心",
				double_red = "双红心",
				black = "黑心",
				gold = "金心",
				half_soul = "半魂心",
				scared = "胆小心",
				blended = "混合心",
				bone = "骨心",
				rotten = "腐心",
				glaze = "琉璃之心",
				half_glaze = "琉璃之半心"
			},
			keys = {
                unknown = "未知钥匙",
                normal = "钥匙",
                golden = "金钥匙",
                double = "双钥匙",
                charged = "充能钥匙",
                glaze = "琉璃钥匙"
            },
			bombs = {
                unknown = "未知炸弹",
                normal = "炸弹",
                double = "双炸弹",
                golden = "金炸弹",
                giga = "超大炸弹",
                glaze = "琉璃炸弹",
				explosion_damage = "爆炸伤害：",
                explosion_radius = "爆炸范围：",
                collision_damage = "碰撞伤害："
            },
			bomb_types = {
                unknown = "未知陆夫人",
                troll = "陆夫人",
                mega_troll = "跟踪陆夫人",
                brimstone = "硫磺地雷",
                bloody_sad = "血泪炸弹",
                golden_troll = "金色陆夫人"
            },
			grabbags = {
                unknown = "未知福袋",
                normal = "福袋",
                black = "黑福袋",
                glaze = "琉璃福袋"
            },
			batteries = {
                unknown = "未知电池",
                medium = "中电池",
                small = "小电池",
                large = "大电池",
                golden = "金电池",
                glaze = "琉璃电池"
            },
			pills = {
                small = "小",
                large = "大",
                form = "药丸形态：",
                color = "药丸颜色：",
                unknown = "未知药丸",
                blue_blue = "蓝-蓝",
                white_blue = "白-蓝",
                orange_orange = "橙-橙",
                white_white = "白-白",
                dots_red = "点-红",
                pink_red = "粉-红",
                blue_cadetblue = "蓝-深蓝",
                yellow_orange = "黄-橙",
                dots_white = "点-白",
                white_azure = "白-天蓝",
                black_yellow = "黑-黄",
                white_black = "白-黑",
                white_yellow = "白-黄",
                gold = "金色"
            },
			poop = {
                unknown = "未知便便",
                small = "小便便",
                big = "大便便",
                glaze = "琉璃便便"
            },
			coins = {
                unknown = "未知硬币",
                penny = "硬币",
                nickel = "5分币",
                dime = "10分币",
                double_penny = "双币",
                lucky_penny = "幸运币",
                sticky_nickel = "粘币",
                golden_penny = "金金币",
                glaze_coin = "琉璃硬币"
            },
			cards = {
                card_id = "卡牌编号：",
                unknown = "未知卡牌"
            },
			grid = {
                terrain = "地形",
                size = "大小：",
                color = "颜色：",
                rotation = "旋转角：",
                collision_type = "碰撞类型："
            },
			poop = {
                normal = "便便",
                red = "红便便",
                corn = "棕便便",
                gold = "金便便",
                rainbow = "彩虹便便",
                black = "黑便便",
                holy = "神圣便便",
                giant = "巨型便便",
                charming = "微笑便便"
            },
			poop_states = {
                appear = "出现",
                intact = "完好",
                small_damage = "小破",
                half_damage = "半破",
                large_damage = "大破",
                destroyed = "毁坏"
            },
			door_states = {
                closed = "关闭",
                open = "开启"
            },
			ladder = {
                label = "梯子：",
                has = "有",
                none = "无"
            },
			button = {
                status = "按钮状态："
            },
            button_states = {
                unpressed = "未按下",
                pressed = "已按下",
                unknown = "未知"
            },
			tnt = {
                status = "TNT状态："
            },
            tnt_states = {
                normal = "正常",
                small_damage = "小破",
                expanding = "膨胀",
                about_to_explode = "即将引爆",
                exploded = "已引爆"
            },
			lock = {
                status = "锁状态："
            },
            lock_states = {
                locked = "未开启",
                unlocked = "开启"
            },
			trap_door = {
                status = "下层通道状态："
            },
            trap_door_states = {
                closed = "关闭",
                open = "开启"
            },
			basement_door = {
                status = "地下室通道状态："
            },
            basement_door_states = {
                closed = "关闭",
                open = "开启"
            },
			web = {
                status = "蛛网状态："
            },
            web_states = {
                normal = "正常",
                damaged = "损坏"
            },
			spike = {
                status = "刺状态："
            },
            spike_states = {
                extended = "探出",
                retracted = "缩回"
            },
			other = {
				health = "生命：",
				size = "大小：",
				friction = "滑动性：",
				color = "颜色：",
				rotation = "旋转角：",
				collision_damage = "碰撞伤害：",
				collision_type = "碰撞类型：",
				layer = "图层：",
				champion = "变异：",
				negative_status = "负面状态：",
				type = "类型：",
				price = "价格：",
				item_id = "道具编号：",
				charge = "充能：",
				touched = "摸过：",
				trinket_id = "饰品编号：",
				golden_trinket = "金饰品：",
				status = "状态：",
            },
        },
        en = {
			spike = {
                status = "Spike Status:"
            },
            spike_states = {
                extended = "Extended",
                retracted = "Retracted"
            },
			web = {
                status = "Web Status:"
            },
            web_states = {
                normal = "Normal",
                damaged = "Damaged"
            },
			basement_door = {
                status = "Basement Door Status:"
            },
            basement_door_states = {
                closed = "Closed",
                open = "Open"
            },
			trap_door = {
                status = "Trap Door Status:"
            },
            trap_door_states = {
                closed = "Closed",
                open = "Open"
            },
			lock = {
                status = "Lock Status:"
            },
            lock_states = {
                locked = "Locked",
                unlocked = "Unlocked"
            },
			tnt = {
                status = "TNT Status:"
            },
            tnt_states = {
                normal = "Normal",
                small_damage = "Small Damage",
                expanding = "Expanding",
                about_to_explode = "About to Explode",
                exploded = "Exploded"
            },
			button = {
                status = "Button Status:"
            },
            button_states = {
                unpressed = "Unpressed",
                pressed = "Pressed",
                unknown = "Unknown"
            },
			door_states = {
                closed = "Closed",
                open = "Open"
            },
			ladder = {
                label = "Ladder:",
                has = "Yes",
                none = "No"
            },
			cards = {
                card_id = "Card ID:",
                unknown = "Unknown Card"
            },
			other = {
				health = "HP:",
				size = "Size:",
				friction = "Friction:",
				color = "Color:",
				rotation = "Rotation:",
				collision_damage = "Collision Damage:",
				collision_type = "Collision Type:",
				layer = "Layer:",
				champion = "Champion:",
				negative_status = "Negative Status:",
				type = "Type:",
				price = "Price:",
				item_id = "Item ID:",
				charge = "Charge:",
				touched = "Touched:",
				trinket_id = "Trinket ID:",
				golden_trinket = "Golden Trinket:",
				status = "Status:",
			},
			poop_states = {
                appear = "Appear",
                intact = "Intact",
                small_damage = "Small Damage",
                half_damage = "Half Damage",
                large_damage = "Large Damage",
                destroyed = "Destroyed"
            },
            collision = {
                none = "No Collision",
                player_only = "Player Only",
                friendly = "Friendly",
                enemies = "Enemies",
                all = "All Entities",
                pit = "Pit",
                object = "Object",
                solid = "Solid",
                wall = "Wall",
                wall_except_player = "Passable Wall"
            },
            prices = {
				one_red_heart = "One Red Heart",
				two_red_hearts = "Two Red Hearts",
				three_soul_hearts = "Three Soul Hearts",
				one_red_two_soul = "One Red and Two Soul Hearts",
				spike_damage = "Spike Damage",
				little_ro = "Little Ro",
				one_soul_heart = "One Soul Heart",
				two_soul_hearts = "Two Soul Hearts",
				one_red_one_soul = "One Red and One Soul Heart",
				free = "Free!"
			},
			champions = {
				none = "None",
				red = "Red",
				yellow = "Yellow",
				green = "Green",
				orange = "Orange",
				dark_blue = "Dark Blue",
				dark_green = "Dark Green",
				pure_white = "Pure White",
				gray = "Gray",
				transparent_white = "Transparent White",
				black = "Black",
				pink = "Pink",
				purple = "Purple",
				dark_red = "Dark Red",
				light_blue = "Light Blue",
				camouflage = "Camouflage",
				blinking_green = "Blinking Green",
				blinking_gray = "Blinking Gray",
				light_white = "Light White",
				small = "Small",
				large = "Large",
				blinking_red = "Blinking Red",
				size_changing = "Size Changing",
				crown = "Crown",
				skeleton = "Skeleton",
				brown = "Brown",
				rainbow = "Rainbow"
			},
			layers = {
				floor = "Floor",
				wall = "Wall",
				normal = "Normal"
			},
			status = {
				seconds = "s",
				yes = "Yes",
				no = "No"
			},
			buffs = {
				poison = "Poison",
				charm = "Charm",
				confusion = "Confusion",
				midas_freeze = "Midas Freeze",
				fear = "Fear",
				burn = "Burn",
				shrink = "Shrink",
				brimstone_marked = "Brimstone Marked",
				no_reward = "No Reward"
			},
			fireplaces = {
				unknown = "Unknown Fireplace",
				normal = "Fireplace",
				red = "Red Fireplace",
				blue = "Blue Fireplace",
				purple = "Purple Fireplace",
				white = "White Fireplace"
			},
			heart_types = {
				unknown = "Unknown Heart",
				red = "Red Heart",
				half_red = "Half Red Heart",
				soul = "Soul Heart",
				eternal = "Eternal Heart",
				double_red = "Double Red Heart",
				black = "Black Heart",
				gold = "Gold Heart",
				half_soul = "Half Soul Heart",
				scared = "Scared Heart",
				blended = "Blended Heart",
				bone = "Bone Heart",
				rotten = "Rotten Heart",
				glaze = "Glaze Heart",
				half_glaze = "Half Glaze Heart"
			},
			keys = {
                unknown = "Unknown Key",
                normal = "Key",
                golden = "Golden Key",
                double = "Double Key",
                charged = "Charged Key",
                glaze = "Glaze Key",
				explosion_damage = "Explosion Damage:",
                explosion_radius = "Explosion Radius:",
                collision_damage = "Collision Damage:"
            },
			bombs = {
                unknown = "Unknown Bomb",
                normal = "Bomb",
                double = "Double Bomb",
                golden = "Golden Bomb",
                giga = "Giga Bomb",
                glaze = "Glaze Bomb"
            },
			bomb_types = {
                unknown = "Unknown Troll Bomb",
                troll = "Troll Bomb",
                mega_troll = "Mega Troll Bomb",
                brimstone = "Brimstone Bomb",
                bloody_sad = "Bloody Sad Bomb",
                golden_troll = "Golden Troll Bomb"
            },
			grabbags = {
                unknown = "Unknown Grabbag",
                normal = "Grabbag",
                black = "Black Sack",
                glaze = "Glaze Grabbag"
            },
			batteries = {
                unknown = "Unknown Battery",
                medium = "Medium Battery",
                small = "Small Battery",
                large = "Large Battery",
                golden = "Golden Battery",
                glaze = "Glaze Battery"
            },
			pills = {
                small = "Small",
                large = "Large",
                form = "Pill Form:",
                color = "Pill Color:",
                unknown = "Unknown Pill",
                blue_blue = "Blue-Blue",
                white_blue = "White-Blue",
                orange_orange = "Orange-Orange",
                white_white = "White-White",
                dots_red = "Dots-Red",
                pink_red = "Pink-Red",
                blue_cadetblue = "Blue-Cadetblue",
                yellow_orange = "Yellow-Orange",
                dots_white = "Dots-White",
                white_azure = "White-Azure",
                black_yellow = "Black-Yellow",
                white_black = "White-Black",
                white_yellow = "White-Yellow",
                gold = "Gold"
            },
			poop = {
                unknown = "Unknown Poop",
                small = "Small Poop",
                big = "Big Poop",
                glaze = "Glazed Poop"
            },
			coins = {
                unknown = "Unknown Coin",
                penny = "Penny",
                nickel = "Nickel",
                dime = "Dime",
                double_penny = "Double Penny",
                lucky_penny = "Lucky Penny",
                sticky_nickel = "Sticky Nickel",
                golden_penny = "Golden Penny",
                glaze_coin = "Glazed Coin"
            },
			grid = {
                terrain = "Terrain",
                size = "Size:",
                color = "Color:",
                rotation = "Rotation:",
                collision_type = "Collision Type:"
            },
			poop = {
                normal = "Poop",
                red = "Red Poop",
                corn = "Corn Poop",
                gold = "Golden Poop",
                rainbow = "Rainbow Poop",
                black = "Black Poop",
                holy = "Holy Poop",
                giant = "Giant Poop",
                charming = "Charming Poop"
            },
        }
    }
}

function Language:setLanguage(lang)
    self.current = lang or "zh"
end

function Language:getText(category, key)
    local langTable = self.translations[self.current]
    if langTable and langTable[category] then
        return langTable[category][key] or ("[MISSING:"..key.."]")
    end
    return "[MISSING:"..category.."."..key.."]"
end

Language:setLanguage(Options.Language or "zh")

local item = {
	ToCall = {},
	pre_ToCall = {},
	myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Squiresaga,
	own_key = "Item_Squiresaga_",
	targ = nil,
	targ_counter = 0,
	mx_rm = 0.05,
	now_display_rm = 0,
	now_display_pos = nil,
	stoped = false,
	render_sprite_pos = nil,
	now_display_dir = Vector(1,0),
	dir_time_limit = 20,
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
	unstopable = {
		[EntityType.ENTITY_PLAYER] = true,
		--[EntityType.ENTITY_TEAR] = true,
		[EntityType.ENTITY_LASER] = true,
		--[EntityType.ENTITY_MINECART] = true,
		[EntityType.ENTITY_KNIFE] = true,
		[EntityType.ENTITY_PROJECTILE] = true,
		[EntityType.ENTITY_TEXT] = true,
		[EntityType.ENTITY_EFFECT] = true,
	},
	uncheckable = {
		[EntityType.ENTITY_PLAYER] = true,
		[EntityType.ENTITY_TEAR] = true,
		[EntityType.ENTITY_LASER] = true,
		--[EntityType.ENTITY_MINECART] = true,
		[EntityType.ENTITY_KNIFE] = true,
		[EntityType.ENTITY_PROJECTILE] = true,
		[EntityType.ENTITY_TEXT] = true,
		[EntityType.ENTITY_EFFECT] = true,
	},
	grid_filter = {
		[1] = true,
		[15] = true,
	},
	changeable_state = {
		[2] = {	--normal
			[1] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "health"),})
					local d = ent:GetData()
					d.saga_modifier_hitpoint_vr = d.saga_modifier_hitpoint_vr or 1
					local vr = d.saga_modifier_hitpoint_vr
					local offset = Vector(0,0)
					
					local wd1 = tostring(math.ceil(ent.HitPoints * 10)/10)
					if choosed and vr == 1 then wd1 = "<="..wd1.."=>" offset = offset + Vector(-5,0) end
					local wd2 = tostring(math.ceil(ent.MaxHitPoints * 10)/10)
					if choosed and vr == 2 then wd2 = "<="..wd2.."=>" offset = offset + Vector(-5,0) end
					local wd = wd1.."/"..wd2
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local d = ent:GetData()
					local vr = d.saga_modifier_hitpoint_vr
					if dir == 1 then 
						if vr == 1 then
							if ent.HitPoints < ent.MaxHitPoints then
								ent.HitPoints = math.min(ent.MaxHitPoints,ent.HitPoints + ent.MaxHitPoints * 0.01)
								return 0
							else
								return -1
							end
						elseif vr == 2 then
							ent.MaxHitPoints = math.max(ent.MaxHitPoints + 1,ent.MaxHitPoints * 1.01)
							return 0
						end
					elseif dir == -1 then
						if vr == 1 then
							local isboss = ent:IsBoss()
							if (isboss == false and ent.HitPoints > ent.MaxHitPoints * 0.3) or (isboss == true and ent.HitPoints > ent.MaxHitPoints * 0.7) then
								ent.HitPoints = ent.HitPoints - ent.MaxHitPoints * 0.01
								return 0
							else
								return -1
							end
						elseif vr == 2 then
							if ent.MaxHitPoints > ent.HitPoints * 1.2 then
								ent.MaxHitPoints = ent.MaxHitPoints / 1.01
								return 0
							else
								return -1
							end
						end
					elseif dir == 2 or dir == -2 then
						d.saga_modifier_hitpoint_vr = 3 - d.saga_modifier_hitpoint_vr
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					if ent.MaxHitPoints == 0 then return false end
					return true
				end,
			},
			[2] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "size"),})
					local d = ent:GetData()
					d.saga_modifier_size_vr = d.saga_modifier_size_vr or 1
					local vr = d.saga_modifier_size_vr
					
					local offset = Vector(0,0)
					local wd1 = tostring(math.floor(ent.SpriteScale.X * 100)/100)
					if choosed and vr == 2 then wd1 = "<="..wd1.."=>" offset = offset + Vector(-5,0) end
					local wd2 = tostring(math.floor(ent.SpriteScale.Y * 100)/100)
					if choosed and vr == 3 then wd2 = "<="..wd2.."=>" offset = offset + Vector(-5,0) end
					local wd = wd1.."X"..wd2
					if choosed and vr == 1 then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					
					return ret
				end,
				move = function(info,ent,dir)
					local d = ent:GetData()
					local succc = ent:GetData().saga_modifier_sprite_size
					local succc2 = ent:GetData().saga_modifier_size
					local spritesize = ent.SpriteScale
					if dir == 1 then 
						if d.saga_modifier_size_vr == 1 then
							local succ2 = Attribute_holder.try_hold_attribute(ent,"Size",ent.Size * 1.04)
							if succc2 then Attribute_holder.try_rewind_attribute(ent,"Size",succc2) end
							d.saga_modifier_size = succ2
							spritesize = spritesize * 1.05
						elseif d.saga_modifier_size_vr == 2 then
							local succ2 = Attribute_holder.try_hold_attribute(ent,"Size",ent.Size * math.sqrt(1.04))
							if succc2 then Attribute_holder.try_rewind_attribute(ent,"Size",succc2) end
							d.saga_modifier_size = succ2
							spritesize = Vector(spritesize.X * 1.05,spritesize.Y)
						elseif d.saga_modifier_size_vr == 3 then
							local succ2 = Attribute_holder.try_hold_attribute(ent,"Size",ent.Size * math.sqrt(1.04))
							if succc2 then Attribute_holder.try_rewind_attribute(ent,"Size",succc2) end
							d.saga_modifier_size = succ2
							spritesize = Vector(spritesize.X,spritesize.Y * 1.05)
						end
						local succ = Attribute_holder.try_hold_attribute(ent,"SpriteScale",spritesize)
						if succc then Attribute_holder.try_rewind_attribute(ent,"SpriteScale",succc) end
						d.saga_modifier_sprite_size = succ
						return 0
					elseif dir == -1 then
						if d.saga_modifier_size_vr == 1 then
							if spritesize.X - 0.00001 > 0.2 and spritesize.Y - 0.00001 > 0.2 then
								local succ2 = Attribute_holder.try_hold_attribute(ent,"Size",math.max(math.min(0.2,ent.Size),ent.Size/1.04))
								if succc2 then Attribute_holder.try_rewind_attribute(ent,"Size",succc2) end
								d.saga_modifier_size = succ2
								spritesize = math.max(math.min(0.2 * math.sqrt(2),ent.SpriteScale:Length()),ent.SpriteScale:Length() / 1.05) * ent.SpriteScale:Normalized()
							else
								return -1
							end
						elseif d.saga_modifier_size_vr == 2 then
							if spritesize.X - 0.00001 > 0.2 then
								local succ2 = Attribute_holder.try_hold_attribute(ent,"Size",math.max(math.min(0.2,ent.Size),ent.Size/ math.sqrt(1.04)))
								if succc2 then Attribute_holder.try_rewind_attribute(ent,"Size",succc2) end
								d.saga_modifier_size = succ2
								spritesize = Vector(math.max(math.min(0.2,spritesize.X),spritesize.X / 1.05),spritesize.Y)
							else
								return -1
							end
						elseif d.saga_modifier_size_vr == 3 then
							if spritesize.Y - 0.00001 > 0.2 then
								local succ2 = Attribute_holder.try_hold_attribute(ent,"Size",math.max(math.min(0.2,ent.Size),ent.Size/ math.sqrt(1.04)))
								if succc2 then Attribute_holder.try_rewind_attribute(ent,"Size",succc2) end
								d.saga_modifier_size = succ2
								spritesize = Vector(spritesize.X,math.max(math.min(0.2,spritesize.Y),spritesize.Y / 1.05))
							else
								return -1
							end
						end
						local succ = Attribute_holder.try_hold_attribute(ent,"SpriteScale",spritesize)
						if succc then Attribute_holder.try_rewind_attribute(ent,"SpriteScale",succc) end
						d.saga_modifier_sprite_size = succ
						return 0
					elseif dir == 2 then
						d.saga_modifier_size_vr = d.saga_modifier_size_vr % 3 + 1
						return 0
					elseif dir == -2 then
						d.saga_modifier_size_vr = (d.saga_modifier_size_vr + 3 - 2) % 3 + 1
						return 0
					end
					return 1
				end,
			},
			[3] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "friction"),})
					local wd = tostring(math.floor(ent.Friction * 100)/100)
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local d = ent:GetData()
					local succc = ent:GetData().saga_modifier_friction
					local fri = ent.Friction
					if dir == 1 then 
						if ent.Friction < 1.2 then
							local succ = Attribute_holder.try_hold_attribute(ent,"Friction",fri + 0.01)
							if succc then Attribute_holder.try_rewind_attribute(ent,"Friction",succc) end
							d.saga_modifier_friction = succ
							return 0
						else
							return -1
						end
					elseif dir == -1 then
						if ent.Friction > 0.8 then
							local succ = Attribute_holder.try_hold_attribute(ent,"Friction",math.max(0,fri - 0.01))
							if succc then Attribute_holder.try_rewind_attribute(ent,"Friction",succc) end
							d.saga_modifier_friction =succ
							return 0
						else
							return -1
						end
					end
					return 1
				end,
			},
			[4] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "color"),})
					local d = ent:GetData()
					d.saga_modifier_color_vr = d.saga_modifier_color_vr or 1
					local vr = d.saga_modifier_color_vr
					for i = 1,7 do
						local wd = info.colormap[i]..":"..tostring(math.floor((ent.Color[info.colormap[i]]) * 255))
						local offset = Vector(0,0)
						if choosed and vr == i then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
						table.insert(ret,#ret + 1,{wd = wd,offset = offset,col = auxi.AddColor(info.colorsmap[i],Color(0.5,0.5,0.5,1),ent.Color[info.colormap[i]],1-ent.Color[info.colormap[i]]),})
					end
					return ret
				end,
				move = function(info,ent,dir)
					local d = ent:GetData()
					d.saga_modifier_color_vr = d.saga_modifier_color_vr or 1
					local succc = ent:GetData().saga_modifier_color
					if dir == 1 then
						local col = ent.Color
						col[info.colormap[d.saga_modifier_color_vr]] = col[info.colormap[d.saga_modifier_color_vr]] + 5/255
						local succ = Attribute_holder.try_hold_attribute(ent,"Color",col)
						if succc then Attribute_holder.try_rewind_attribute(ent,"Color",succc) end
						d.saga_modifier_color = succ
						return 0
					elseif dir == -1 then
						local col = ent.Color
						col[info.colormap[d.saga_modifier_color_vr]] = col[info.colormap[d.saga_modifier_color_vr]] - 5/255
						local succ = Attribute_holder.try_hold_attribute(ent,"Color",col)
						if succc then Attribute_holder.try_rewind_attribute(ent,"Color",succc) end
						d.saga_modifier_color = succ
						return 0
					elseif dir == 2 then
						d.saga_modifier_color_vr = d.saga_modifier_color_vr % 7 + 1
						return 0
					elseif dir == -2 then
						d.saga_modifier_color_vr = (d.saga_modifier_color_vr + 7 - 2) % 7 + 1
						return 0
					end
					return 1
				end,
				colormap = {
					[1] = "R",
					[2] = "G",
					[3] = "B",
					[4] = "A",
					[5] = "RO",
					[6] = "GO",
					[7] = "BO",
				},
				colorsmap = {
					[1] = Color(1,0,0,1),
					[2] = Color(0,1,0,1),
					[3] = Color(0,0,1,1),
					[4] = Color(1,1,1,0.5),
					[5] = Color(1,0.5,0.5,1),
					[6] = Color(0.5,1,0.5,1),
					[7] = Color(0.5,0.5,1,1),
				},
			},
			[5] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "rotation"),})
					local wd = tostring(math.floor(ent.SpriteRotation * 100)/100)
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local d = ent:GetData()
					local val = ent.SpriteRotation
					if dir == 1 then 
						ent.SpriteRotation = val + 5
						return 0
					elseif dir == -1 then
						ent.SpriteRotation = val - 5
						return 0
					end
					return 1
				end,
			},
			[6] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "collision_damage"),})
					local wd = tostring(math.floor(ent.CollisionDamage * 100)/100)
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local d = ent:GetData()
					local val = ent.CollisionDamage
					if dir == 1 then 
						ent.CollisionDamage = (ent.CollisionDamage)% 6 + 1
						return 0
					elseif dir == -1 then
						ent.CollisionDamage = (ent.CollisionDamage + 4)% 6 + 1
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					if ent:ToFamiliar() == nil and ent:ToBomb() == nil and ent.CollisionDamage > 0 then return true end
					return false
				end,
			},
			[7] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "collision_type"),})
					local wd = info.collisionmap[ent.EntityCollisionClass] or "？"
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local d = ent:GetData()
					local val = ent.EntityCollisionClass
					
					if dir == 1 then 
						ent.EntityCollisionClass = (val + 1) % 5
						return 0
					elseif dir == -1 then
						ent.EntityCollisionClass = (val + 4) % 5
						return 0
					end
					return 1
				end,
				collisionmap = {
					[EntityCollisionClass.ENTCOLL_NONE] = Language:getText("collision", "none"),
					[EntityCollisionClass.ENTCOLL_PLAYERONLY] = Language:getText("collision", "player_only"),
					[EntityCollisionClass.ENTCOLL_PLAYEROBJECTS] = Language:getText("collision", "friendly"),
					[EntityCollisionClass.ENTCOLL_ENEMIES] = Language:getText("collision", "enemies"),
					[EntityCollisionClass.ENTCOLL_ALL] = Language:getText("collision", "all"),
				},
				check = function(info,ent)
					if ent.IsGrid ~= nil then return false end
					return true
				end,
			},
			[8] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "layer"),})
					local wd = info.map[ent.SortingLayer] or "？"
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local d = ent:GetData()
					local val = ent.SortingLayer
					
					if dir == 1 then 
						ent.SortingLayer = (val + 1) % 3
						return 0
					elseif dir == -1 then
						ent.SortingLayer = (val + 2) % 3
						return 0
					end
					return 1
				end,
				map = {
					[0] = Language:getText("layers", "floor"),
					[1] = Language:getText("layers", "wall"),
					[2] = Language:getText("layers", "normal"),
				},
			},
			check = function(info,ent)
				if ent.IsGrid ~= nil then return false end
				return true
			end,
		},
		[3] = {	--enemy
			[1] = {
				name = function(info,ent,choosed)
					ent = ent:ToNPC()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "champion"),})
					local wd = tostring(info.champions[ent:GetChampionColorIdx()])
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToNPC()
					local d = ent:GetData()
					local succc = ent:GetData().saga_modifier_friction
					local val = ent:GetChampionColorIdx()
					if dir == 1 then 
						val = val + 1
						if val > 25 then val = 0 end
						local mxhp = ent.MaxHitPoints
						ent:MakeChampion(-1,val,true)
						ent.MaxHitPoints = mxhp
						return 0
					elseif dir == -1 then
						val = val - 1
						if val < 0 then val = 25 end
						local mxhp = ent.MaxHitPoints
						ent:MakeChampion(-1,val,true)
						ent.MaxHitPoints = mxhp
						return 0
					end
					return 1
				end,
				champions = {
					[-1] = Language:getText("champions", "none"),
					[0] = Language:getText("champions", "red"),
					[1] = Language:getText("champions", "yellow"),
					[2] = Language:getText("champions", "green"),
					[3] = Language:getText("champions", "orange"),
					[4] = Language:getText("champions", "dark_blue"),
					[5] = Language:getText("champions", "dark_green"),
					[6] = Language:getText("champions", "pure_white"),
					[7] = Language:getText("champions", "gray"),
					[8] = Language:getText("champions", "transparent_white"),
					[9] = Language:getText("champions", "black"),
					[10] = Language:getText("champions", "pink"),
					[11] = Language:getText("champions", "purple"),
					[12] = Language:getText("champions", "dark_red"),
					[13] = Language:getText("champions", "light_blue"),
					[14] = Language:getText("champions", "camouflage"),
					[15] = Language:getText("champions", "blinking_green"),
					[16] = Language:getText("champions", "blinking_gray"),
					[17] = Language:getText("champions", "light_white"),
					[18] = Language:getText("champions", "small"),
					[19] = Language:getText("champions", "large"),
					[20] = Language:getText("champions", "blinking_red"),
					[21] = Language:getText("champions", "size_changing"),
					[22] = Language:getText("champions", "crown"),
					[23] = Language:getText("champions", "skeleton"),
					[24] = Language:getText("champions", "brown"),
					[25] = Language:getText("champions", "rainbow"),
				},
			},
			[2] = {
				name = function(info,ent,choosed)
					ent = ent:ToNPC()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "negative_status"),})
					local d = ent:GetData()
					d.saga_modifier_buff_vr = d.saga_modifier_buff_vr or 1
					local vr = d.saga_modifier_buff_vr
					
					for i = 1,#(info.buffs) do
						local v = info.buffs[i]
						local wd = tostring(v.tm)..Language:getText("status", "seconds")..v.name.."："
						local wd1 = ent:HasEntityFlags(v.val)
						if wd1 then 
							wd1 = Language:getText("status", "yes") 
						else 
							wd1 = Language:getText("status", "no") 
						end
						local offset = Vector(-10,0)
						if choosed and vr == i then wd1 = "<="..wd1.."=>" offset = offset + Vector(-5,0) end
						wd = wd..wd1
						table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					end
					
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToNPC()
					local d = ent:GetData()
					local succc = ent:GetData().saga_modifier_friction
					local val = ent:GetChampionColorIdx()
					local vr = d.saga_modifier_buff_vr
					local buff = info.buffs[vr]
					
					if dir == 1 then 
						if ent:HasEntityFlags(buff.val) == false then
							d["saga_buff_"..tostring(vr).."_succ"] = Attribute_holder.try_hold_and_rewind_attribute(ent,"EntityFlag_"..buff.flagname,true,buff.tm * 30,Attribute_holder.descriptors.entity_flag(buff.val))
							return 0
						else
							return -1
						end
					elseif dir == -1 then
						if ent:HasEntityFlags(buff.val) then
							if d["saga_buff_"..tostring(vr).."_succ"] then
								Attribute_holder.try_rewind_attribute(ent,"EntityFlag_"..buff.flagname,d["saga_buff_"..tostring(vr).."_succ"],Attribute_holder.descriptors.entity_flag(buff.val))
							end
							ent:ClearEntityFlags(buff.val)
							return 0
						else
							return -1
						end
					elseif dir == 2 then
						d.saga_modifier_buff_vr = d.saga_modifier_buff_vr % #(info.buffs) + 1
						return 0
					elseif dir == -2 then
						d.saga_modifier_buff_vr = (d.saga_modifier_buff_vr + #(info.buffs) - 2) % #(info.buffs) + 1
						return 0
					end
					return 1
				end,
				buffs = {
					--[1] = {name = Language:getText("buffs", "poison"),val = EntityFlag.FLAG_POISON,tm = 10,flagname = "FLAG_POISON",},
					[1] = {name = Language:getText("buffs", "charm"),val = EntityFlag.FLAG_CHARM,tm = 10,flagname = "FLAG_CHARM",},
					[2] = {name = Language:getText("buffs", "confusion"),val = EntityFlag.FLAG_CONFUSION,tm = 10,flagname = "FLAG_CONFUSION",},
					--[3] = {name = Language:getText("buffs", "midas_freeze"),val = EntityFlag.FLAG_MIDAS_FREEZE,tm = 5,flagname = "FLAG_MIDAS_FREEZE",special_tochange = function(ent,tm) ent:AddMidasFreeze(EntityRef(ent),tm) end},
					[3] = {name = Language:getText("buffs", "fear"),val = EntityFlag.FLAG_FEAR,tm = 10,flagname = "FLAG_FEAR",},
					--[6] = {name = Language:getText("buffs", "burn"),val = EntityFlag.FLAG_BURN,tm = 10,flagname = "FLAG_BURN",},
					--[4] = {name = Language:getText("buffs", "shrink"),val = EntityFlag.FLAG_SHRINK,tm = 10,flagname = "FLAG_SHRINK",},
					[4] = {name = Language:getText("buffs", "brimstone_marked"),val = EntityFlag.FLAG_BRIMSTONE_MARKED,tm = 10,flagname = "FLAG_BRIMSTONE_MARKED",},
					--[8] = {name = Language:getText("buffs", "no_reward"),val = EntityFlag.FLAG_NO_REWARD,tm = 20,flagname = "FLAG_NO_REWARD",},
				},
				check = function(info,ent)
					if ent:IsVulnerableEnemy() and ent:IsActiveEnemy() then return true end
					return false
				end,
			},
			[3] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "type"),})
					local vr = info.mindtype(ent)
					local wd = (info.hearttype[vr] or {name = Language:getText("fireplaces", "unknown"),}).name

					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local d = ent:GetData()
					local s = ent:GetSprite()
					local vr = info.mindtype(ent)
					local val = (info.hearttype[vr] or {id = 0,}).id or vr
					local vval = info.tpmap[val] or val
					
					if dir == 1 then 
						val = val % info.mxn + 1
						val = info.tpmap[val] or val
					elseif dir == -1 then
						val = (val + info.mxn - 2) % info.mxn + 1
						val = info.tpmap[val] or val
					end
					if dir == 1 or dir == -1 then
						if (info.hearttype[vval].special_toturn) then
							info.hearttype[vval].special_toturn(ent,false)
						end
						if (info.hearttype[val].special_toturn) then
							info.hearttype[val].special_toturn(ent,true)
						else
							ent.Variant = val
						end
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					if ent.Type == 33 and ent.Variant <= 8 then return true end
					return false
				end,
				hearttype = {
					[0] = {name = Language:getText("fireplaces", "normal"),id = 1,loadname = "gfx/033.000_fireplace.anm2",},
					[1] = {name = Language:getText("fireplaces", "red"),id = 2,loadname = "gfx/033.001_red fireplace.anm2",},
					[2] = {name = Language:getText("fireplaces", "blue"),id = 3,loadname = "gfx/033.002_blue fireplace.anm2",},
					[3] = {name = Language:getText("fireplaces", "purple"),id = 4,loadname = "gfx/033.003_purple fireplace.anm2",},
					[4] = {name = Language:getText("fireplaces", "white"),id = 5,loadname = "gfx/033.004_white fireplace.anm2",},
				},
				mindtype = function(ent)
					return ent.Variant
				end,
				tpmap = {
					[1] = 0,
					[2] = 1,
					[3] = 2,
					[4] = 3,
					[5] = 4,
				},
				mxn = 5,
			},
			check = function(info,ent)
				if ent.IsGrid ~= nil then return false end
				if ent:ToNPC() then return true end
				return false
			end,
		},
		[1] = {	--pickup
			[16] = {
				name = function(info,ent,choosed,item)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "price"),})
					consistance_holder.try_hold_over_entity(ent,item.own_key)
					local price = ent:GetData()._Data[item.own_key]["Price"] or ent.Price
					if info.price_map[price] then price = info.price_map[price] else price = tostring(price) end
					local wd = price
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir,item)
					ent = ent:ToPickup()
					local d = ent:GetData()
					consistance_holder.try_hold_over_entity(ent,item.own_key)
					local price = ent:GetData()._Data[item.own_key]["Price"] or ent.Price
					price_holder.try_catch_price(ent)
					if dir == 1 then 
						if price == -1000 then
							return -1
						elseif price == -9 then
							return -1
						elseif price == 0 then
							price = 1
						elseif price >= 999 then
							price = -1000
						elseif price < 0 then 
							price = -((-price) % 8 + 1)
						else
							price = math.min(999,price + math.max(math.floor(price * 0.05),1))
						end
					elseif dir == -1 then
						if price == -1000 then
							return -1
						elseif price == 1 then
							return -1
						elseif price == -9 then
							return -1
						elseif price < 0 then 
							price = -((-price + 8 - 2) % 8 + 1)
						else
							price = price - math.max(math.floor(price * 0.05),1)
						end
					end
					ent:GetData()._Data[item.own_key]["Price"] = price
					consistance_holder.try_hold_entity(ent,item.own_key,{ignore_subtype = true,})
					price_holder.reset_price({ent})
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					--return true
					if ent.Price ~= 0 then return true end
					return false
				end,
				price_map = {
					[-1] = Language:getText("prices", "one_red_heart"),
					[-2] = Language:getText("prices", "two_red_hearts"),
					[-3] = Language:getText("prices", "three_soul_hearts"),
					[-4] = Language:getText("prices", "one_red_two_soul"),
					[-5] = Language:getText("prices", "spike_damage"),
					[-6] = Language:getText("prices", "little_ro"),
					[-7] = Language:getText("prices", "one_soul_heart"),
					[-8] = Language:getText("prices", "two_soul_hearts"),
					[-9] = Language:getText("prices", "one_red_one_soul"),
					[-1000] = Language:getText("prices", "free"),
				},
			},
			[2] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "item_id"),})
					local val = ent.SubType
					
					local wd = val
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local val = ent.SubType
					local config = Isaac.GetItemConfig()
					local sz = config:GetCollectibles().Size
					
					if dir == 1 then 
						val = val + 1
						while((val < sz or (val > 2^31 and val < 2^32)) and (config:GetCollectible(val) == nil or config:GetCollectible(val).Hidden or config:GetCollectible(val).Tags & ItemConfig.TAG_QUEST == ItemConfig.TAG_QUEST)) do
							val = val + 1
						end
					elseif dir == -1 then
						val = val - 1
						while(val > 0 and val < sz and (config:GetCollectible(val) == nil or config:GetCollectible(val).Hidden or config:GetCollectible(val).Tags & ItemConfig.TAG_QUEST == ItemConfig.TAG_QUEST)) do
							val = val - 1
						end
					elseif dir == 2 then
						if (val > 2^31 and val < 2^32) then return -1 end
						val = val + 100
						while((val < sz or (val > 2^31 and val < 2^32)) and (config:GetCollectible(val) == nil or config:GetCollectible(val).Hidden or config:GetCollectible(val).Tags & ItemConfig.TAG_QUEST == ItemConfig.TAG_QUEST)) do
							val = val + 1
						end
					elseif dir == -2 then
						if (val > 2^31 and val < 2^32) then return -1 end
						val = val - 100
						if val <= 0 then return -1 end
						while(val > 0 and val < sz and (config:GetCollectible(val) == nil or config:GetCollectible(val).Hidden or config:GetCollectible(val).Tags & ItemConfig.TAG_QUEST == ItemConfig.TAG_QUEST)) do
							val = val - 1
						end
					end
					if dir == 1 or dir == -1 or dir == 2 or dir == -2 then
						local col = config:GetCollectible(val)
						local pcol = config:GetCollectible(ent.SubType)
						if col then
							local mxcharge = col.MaxCharges
							local pmxcharge = pcol.MaxCharges
							local charge = ent.Charge
							ent.SubType = val
							s:ReplaceSpritesheet(1,config:GetCollectible(val).GfxFileName)
							s:LoadGraphics()
							ent.Charge = math.floor(charge/math.max(1,pmxcharge) * mxcharge)
							return 0
						else
							return -1
						end
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 100 and ent.SubType ~= 0 then return true end
					return false
				end,
			},
			[3] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "charge"),})
					local val = ent.SubType
					local config = Isaac.GetItemConfig()
					local col = config:GetCollectible(val)
					
					local wd = ent.Charge
					local wd1 = col.MaxCharges
					if wd1 > 12 then wd = math.floor(wd/wd1 * 100)/100 wd1 = 1 end
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					wd = wd .."/".. tostring(wd1)
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local val = ent.Charge
					local config = Isaac.GetItemConfig()
					local col = config:GetCollectible(ent.SubType)
					local mxval = col.MaxCharges
					
					if dir == 1 then 
						if val < mxval * 2 then 
							val = math.min(mxval * 2,val + math.max(1,math.floor(mxval/12))) 
						else
							return -1
						end
						ent.Charge = val
						return 0
					elseif dir == -1 then
						if val > 0 then 
							val = math.max(0,val - math.max(1,math.floor(mxval/12))) 
						else
							return -1
						end
						ent.Charge = val
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 100 and ent.SubType ~= 0 then 
						local config = Isaac.GetItemConfig()
						local col = config:GetCollectible(ent.SubType)
						if col then
							if col.MaxCharges > 0 then
								return true 
							end
						end
					end
					return false
				end,
			},
			[4] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "touched"),})
					local val = ent.Touched
					
					local wd = Language:getText("status", "no")
					if val == true then 
						wd = Language:getText("status", "yes") 
					end
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local val = ent.Touched
					
					if dir == 1 then 
						ent.Touched = not ent.Touched
						return 0
					elseif dir == -1 then
						ent.Touched = not ent.Touched
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 100 and ent.SubType ~= 0 then 
						return true
					end
					return false
				end,
			},
			[5] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "type"),})
					local vr = ent.SubType
					local wd = (info.hearttype[vr] or {name = Language:getText("heart_types", "unknown"),}).name

					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local heart = info.hearttype[ent.SubType]
					local val = (info.hearttype[ent.SubType] or {id = 0,}).id or ent.SubType
					
					if dir == 1 then 
						val = val % info.mxn + 1
						val = info.tpmap[val] or val
						ent.SubType = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					elseif dir == -1 then
						val = (val + info.mxn - 2) % info.mxn + 1
						val = info.tpmap[val] or val
						ent.SubType = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 10 then 
						return true
					end
					return false
				end,
				hearttype = {
					[1] = {name = Language:getText("heart_types", "red"),loadname = "gfx/005.011_heart.anm2",},
					[2] = {name = Language:getText("heart_types", "half_red"),loadname = "gfx/005.012_heart (half).anm2",},
					[3] = {name = Language:getText("heart_types", "soul"),loadname = "gfx/005.013_heart (soul).anm2",},
					[4] = {name = Language:getText("heart_types", "eternal"),loadname = "gfx/005.014_heart (eternal).anm2",},
					[5] = {name = Language:getText("heart_types", "double_red"),loadname = "gfx/005.015_double heart.anm2",},
					[6] = {name = Language:getText("heart_types", "black"),loadname = "gfx/005.016_black heart.anm2",},
					[7] = {name = Language:getText("heart_types", "gold"),loadname = "gfx/005.017_goldheart.anm2",},
					[8] = {name = Language:getText("heart_types", "half_soul"),loadname = "gfx/005.018_heart (halfsoul).anm2",},
					[9] = {name = Language:getText("heart_types", "scared"),loadname = "gfx/005.020_scared heart.anm2",},
					[10] = {name = Language:getText("heart_types", "blended"),loadname = "gfx/005.019_blended heart.anm2",},
					[11] = {name = Language:getText("heart_types", "bone"),loadname = "gfx/005.01a_bone heart.anm2",},
					[12] = {name = Language:getText("heart_types", "rotten"),loadname = "gfx/005.01b_rotten heart.anm2",},
					[enums.Pickups.Glaze_heart.SubType] = {name = Language:getText("heart_types", "glaze"),id = 13,loadname = "gfx/Glaze/glaze_heart.anm2",},
					[enums.Pickups.Glaze_heart_half.SubType] = {name = Language:getText("heart_types", "half_glaze"),id = 14,loadname = "gfx/Glaze/glaze_heart_half.anm2",},
				},
				tpmap = {
					[13] = enums.Pickups.Glaze_heart.SubType,
					[14] = enums.Pickups.Glaze_heart_half.SubType,
				},
				mxn = 14,
			},
			[7] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "trinket_id"),})
					local val = ent.SubType % 32768
					
					local wd = val
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local val = ent.SubType % 32768
					local golden = math.floor(ent.SubType / 32768)
					local config = Isaac.GetItemConfig()
					local sz = config:GetTrinkets().Size
					
					if dir == 1 then 
						val = val + 1
						while((val < sz) and (config:GetTrinket(val) == nil or config:GetTrinket(val).Hidden)) do
							val = val + 1
						end
					elseif dir == -1 then
						val = val - 1
						while(val > 0 and val < sz and (config:GetTrinket(val) == nil or config:GetTrinket(val).Hidden)) do
							val = val - 1
						end
					elseif dir == 2 then
						val = val + 20
						while((val < sz) and (config:GetTrinket(val) == nil or config:GetTrinket(val).Hidden)) do
							val = val + 1
						end
					elseif dir == -2 then
						val = val - 20
						while(val > 0 and val < sz and (config:GetTrinket(val) == nil or config:GetTrinket(val).Hidden)) do
							val = val - 1
						end
					end
					if dir == 1 or dir == -1 or dir == 2 or dir == -2 then
						if config:GetTrinket(val) then
							ent.SubType = val + golden * 32768
							s:ReplaceSpritesheet(0,config:GetTrinket(val).GfxFileName)
							s:LoadGraphics()
							return 0
						else
							return -1
						end
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 350 then return true end
					return false
				end,
			},
			[6] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "golden_trinket"),})
					local val = math.floor(ent.SubType / 32768)
					
					local wd = Language:getText("status", "no")
					if val > 0 then wd = Language:getText("status", "yes") end
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local val = ent.SubType % 32768
					local golden = math.floor(ent.SubType / 32768)
					local config = Isaac.GetItemConfig()
					local sz = config:GetTrinkets().Size
					
					if dir == 1 or dir == -1 then
						golden = 1 - golden
						if config:GetTrinket(val) then
							local anima
							ent.SubType = val + golden * 32768
							local Animation = s:GetAnimation()
							local frame = s:GetFrame()
							ent:Morph(ent.Type,ent.Variant,ent.SubType,true,true,true)
							ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
							s:SetFrame(Animation,frame)
							s:Play(Animation)
							return 0
						else
							return -1
						end
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 350 then return true end
					return false
				end,
			},
			[1] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "type")})
					local vr = ent.SubType
					local wd = (info.hearttype[vr] or {name = Language:getText("keys", "unknown"),}).name

					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local heart = info.hearttype[ent.SubType]
					local val = (info.hearttype[ent.SubType] or {id = 0,}).id or ent.SubType
					
					if dir == 1 then 
						val = val % info.mxn + 1
						val = info.tpmap[val] or val
						ent.SubType = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					elseif dir == -1 then
						val = (val + info.mxn - 2) % info.mxn + 1
						val = info.tpmap[val] or val
						ent.SubType = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 30 then 
						return true
					end
					return false
				end,
				hearttype = {
					[1] = {name = Language:getText("keys", "normal"), loadname = "gfx/005.031_key.anm2"},
					[2] = {name = Language:getText("keys", "golden"), loadname = "gfx/005.032_golden key.anm2"},
					[3] = {name = Language:getText("keys", "double"), loadname = "gfx/005.033_keyring.anm2"},
					[4] = {name = Language:getText("keys", "charged"), loadname = "gfx/005.034_chargedkey.anm2"},
					[enums.Pickups.Glaze_key.SubType] = {name = Language:getText("keys", "glaze"), id = 5, loadname = "gfx/Glaze/glaze_key.anm2"},
				},
				tpmap = {
					[5] = enums.Pickups.Glaze_key.SubType,
				},
				mxn = 5,
			},
			[8] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "type")})
					local vr = ent.SubType
					local wd = (info.hearttype[vr] or {name = Language:getText("bombs", "unknown"),}).name

					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local heart = info.hearttype[ent.SubType]
					local val = (info.hearttype[ent.SubType] or {id = 0,}).id or ent.SubType
					
					if dir == 1 then 
						val = val % info.mxn + 1
						val = info.tpmap[val] or val
						ent.SubType = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					elseif dir == -1 then
						val = (val + info.mxn - 2) % info.mxn + 1
						val = info.tpmap[val] or val
						ent.SubType = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 40 then 
						return true
					end
					return false
				end,
				hearttype = {
					[1] = {name = Language:getText("bombs", "normal"), loadname = "gfx/005.041_bomb.anm2"},
					[2] = {name = Language:getText("bombs", "double"), loadname = "gfx/005.042_double bomb.anm2"},
					[4] = {name = Language:getText("bombs", "golden"), id = 3, loadname = "gfx/005.043_golden bomb.anm2"},
					[7] = {name = Language:getText("bombs", "giga"), id = 4, loadname = "gfx/005.047_giga bomb.anm2"},
					[enums.Pickups.Glaze_bomb.SubType] = {name = Language:getText("bombs", "glaze"), id = 5, loadname = "gfx/Glaze/glaze_bomb.anm2"},
				},
				tpmap = {
					[3] = 4,
					[4] = 7,
					[5] = enums.Pickups.Glaze_bomb.SubType,
				},
				mxn = 5,
			},
			[9] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "type")})
					local vr = ent.SubType
					local wd = (info.hearttype[vr] or {name = Language:getText("grabbags", "unknown"),}).name

					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local heart = info.hearttype[ent.SubType]
					local val = (info.hearttype[ent.SubType] or {id = 0,}).id or ent.SubType
					
					if dir == 1 then 
						val = val % info.mxn + 1
						val = info.tpmap[val] or val
						ent.SubType = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					elseif dir == -1 then
						val = (val + info.mxn - 2) % info.mxn + 1
						val = info.tpmap[val] or val
						ent.SubType = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 69 then 
						return true
					end
					return false
				end,
				hearttype = {
					[1] = {name = Language:getText("grabbags", "normal"), loadname = "gfx/005.069_grabbag.anm2"},
					[2] = {name = Language:getText("grabbags", "black"), loadname = "gfx/005.069_black sack.anm2"},
					[enums.Pickups.Glaze_grabbag.SubType] = {name = Language:getText("grabbags", "glaze"), id = 3, loadname = "gfx/Glaze/glaze_grabbag.anm2"},
				},
				tpmap = {
					[3] = enums.Pickups.Glaze_grabbag.SubType,
				},
				mxn = 3,
			},
			[10] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "type")})
					local vr = ent.SubType
					local wd = (info.hearttype[vr] or {name = Language:getText("batteries", "unknown"),}).name

					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local heart = info.hearttype[ent.SubType]
					local val = (info.hearttype[ent.SubType] or {id = 0,}).id or ent.SubType
					
					if dir == 1 then 
						val = val % info.mxn + 1
						val = info.tpmap[val] or val
						ent.SubType = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					elseif dir == -1 then
						val = (val + info.mxn - 2) % info.mxn + 1
						val = info.tpmap[val] or val
						ent.SubType = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 90 then 
						return true
					end
					return false
				end,
				hearttype = {
					[1] = {name = Language:getText("batteries", "medium"), loadname = "gfx/005.090_littlebattery.anm2"},
					[2] = {name = Language:getText("batteries", "small"), loadname = "gfx/005.090_microbattery.anm2"},
					[3] = {name = Language:getText("batteries", "large"), loadname = "gfx/005.090_megabattery.anm2"},
					[4] = {name = Language:getText("batteries", "golden"), loadname = "gfx/005.090_golden battery.anm2"},
					[enums.Pickups.Glaze_battery.SubType] = {name = Language:getText("batteries", "glaze"), id = 5, loadname = "gfx/Glaze/glaze_littlebattery.anm2"},
				},
				tpmap = {
					[5] = enums.Pickups.Glaze_battery.SubType,
				},
				mxn = 5,
			},
			[12] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("pills", "color")})
					local vr = ent.SubType % 2048
					local wd = (info.hearttype[vr] or {name = Language:getText("pills", "unknown"),}).name

					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local heart = info.hearttype[ent.SubType]
					local vr = ent.SubType % 2048
					local large = math.floor(ent.SubType / 2048)
					local val = (info.hearttype[vr] or {id = 0,}).id or vr
					
					if dir == 1 then 
						val = val % info.mxn + 1
						val = info.tpmap[val] or val
					elseif dir == -1 then
						val = (val + info.mxn - 2) % info.mxn + 1
						val = info.tpmap[val] or val
					end
					if dir == 1 or dir == -1 then
						ent.SubType = val + large * 2048
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						local name = info.hearttype[val].loadname or ""
						if large and large > 0 then name = name .."horse " end
						name = name .. (info.hearttype[val].loadname2 or "")
						s:Load(name,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 70 then 
						return true
					end
					return false
				end,
				hearttype = {
					[1] = {name = Language:getText("pills", "blue_blue"), loadname = "gfx/005.071_", loadname2 = "pill blue-blue.anm2"},
					[2] = {name = Language:getText("pills", "white_blue"), loadname = "gfx/005.072_", loadname2 = "pill white-blue.anm2"},
					[3] = {name = Language:getText("pills", "orange_orange"), loadname = "gfx/005.073_", loadname2 = "pill orange-orange.anm2"},
					[4] = {name = Language:getText("pills", "white_white"), loadname = "gfx/005.074_", loadname2 = "pill white-white.anm2"},
					[5] = {name = Language:getText("pills", "dots_red"), loadname = "gfx/005.075_", loadname2 = "pill dots-red.anm2"},
					[6] = {name = Language:getText("pills", "pink_red"), loadname = "gfx/005.076_", loadname2 = "pill pink-red.anm2"},
					[7] = {name = Language:getText("pills", "blue_cadetblue"), loadname = "gfx/005.077_", loadname2 = "pill blue-cadetblue.anm2"},
					[8] = {name = Language:getText("pills", "yellow_orange"), loadname = "gfx/005.078_", loadname2 = "pill yellow-orange.anm2"},
					[9] = {name = Language:getText("pills", "dots_white"), loadname = "gfx/005.079_", loadname2 = "pill dots-white.anm2"},
					[10] = {name = Language:getText("pills", "white_azure"), loadname = "gfx/005.080_", loadname2 = "pill white-azure.anm2"},
					[11] = {name = Language:getText("pills", "black_yellow"), loadname = "gfx/005.081_", loadname2 = "pill black-yellow.anm2"},
					[12] = {name = Language:getText("pills", "white_black"), loadname = "gfx/005.082_", loadname2 = "pill white-black.anm2"},
					[13] = {name = Language:getText("pills", "white_yellow"), loadname = "gfx/005.083_", loadname2 = "pill white-yellow.anm2"},
					[14] = {name = Language:getText("pills", "gold"), loadname = "gfx/005.084_", loadname2 = "pill gold-gold.anm2"},
				},
				tpmap = {
				},
				mxn = 14,
			},
			[11] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("pills", "form")})
					local vr = math.floor(ent.SubType / 2048)
					local wd = Language:getText("pills", "small")
					if vr and vr > 0 then wd = Language:getText("pills", "large") end
					
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local heart = info.hearttype[ent.SubType]
					local vr = ent.SubType % 2048
					local large = math.floor(ent.SubType / 2048)
					local val = (info.hearttype[vr] or {id = 0,}).id or vr
					
					if dir == 1 or dir == -1 then
						large = 1 - large
						ent.SubType = val + large * 2048
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						local name = info.hearttype[val].loadname or ""
						if large and large > 0 then name = name .."horse " end
						name = name .. (info.hearttype[val].loadname2 or "")
						s:Load(name,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 70 then 
						return true
					end
					return false
				end,
				hearttype = {
					[1] = {name = Language:getText("pills", "blue_blue"), loadname = "gfx/005.071_", loadname2 = "pill blue-blue.anm2"},
					[2] = {name = Language:getText("pills", "white_blue"), loadname = "gfx/005.072_", loadname2 = "pill white-blue.anm2"},
					[3] = {name = Language:getText("pills", "orange_orange"), loadname = "gfx/005.073_", loadname2 = "pill orange-orange.anm2"},
					[4] = {name = Language:getText("pills", "white_white"), loadname = "gfx/005.074_", loadname2 = "pill white-white.anm2"},
					[5] = {name = Language:getText("pills", "dots_red"), loadname = "gfx/005.075_", loadname2 = "pill dots-red.anm2"},
					[6] = {name = Language:getText("pills", "pink_red"), loadname = "gfx/005.076_", loadname2 = "pill pink-red.anm2"},
					[7] = {name = Language:getText("pills", "blue_cadetblue"), loadname = "gfx/005.077_", loadname2 = "pill blue-cadetblue.anm2"},
					[8] = {name = Language:getText("pills", "yellow_orange"), loadname = "gfx/005.078_", loadname2 = "pill yellow-orange.anm2"},
					[9] = {name = Language:getText("pills", "dots_white"), loadname = "gfx/005.079_", loadname2 = "pill dots-white.anm2"},
					[10] = {name = Language:getText("pills", "white_azure"), loadname = "gfx/005.080_", loadname2 = "pill white-azure.anm2"},
					[11] = {name = Language:getText("pills", "black_yellow"), loadname = "gfx/005.081_", loadname2 = "pill black-yellow.anm2"},
					[12] = {name = Language:getText("pills", "white_black"), loadname = "gfx/005.082_", loadname2 = "pill white-black.anm2"},
					[13] = {name = Language:getText("pills", "white_yellow"), loadname = "gfx/005.083_", loadname2 = "pill white-yellow.anm2"},
					[14] = {name = Language:getText("pills", "gold"), loadname = "gfx/005.084_", loadname2 = "pill gold-gold.anm2"},
				},
				tpmap = {
				},
				mxn = 14,
			},
			[13] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "type")})
					
					local vr = ent.SubType
					local wd = (info.hearttype[vr] or {name = Language:getText("poop", "unknown"),}).name

					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local heart = info.hearttype[ent.SubType]
					local val = (info.hearttype[ent.SubType] or {id = 0,}).id or ent.SubType
					
					if dir == 1 then 
						val = val % info.mxn + 1
						val = info.tpmap[val] or val
						ent.SubType = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					elseif dir == -1 then
						val = (val + info.mxn - 2) % info.mxn + 1
						val = info.tpmap[val] or val
						ent.SubType = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 42 then 
						return true
					end
					return false
				end,
				hearttype = {
					[0] = {name = Language:getText("poop", "small"), id = 1, loadname = "gfx/005.042_poop nugget.anm2"},
					[1] = {name = Language:getText("poop", "big"), id = 2, loadname = "gfx/005.042_big poop nugget.anm2"},
					[enums.Pickups.Glaze_big_poop.SubType] = {name = Language:getText("poop", "glaze"), id = 3, loadname = "gfx/Glaze/glaze_big poop nugget.anm2"},
				},
				tpmap = {
					[1] = 0,
					[2] = 1,
					[3] = enums.Pickups.Glaze_big_poop.SubType,
				},
				mxn = 3,
			},
			[14] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "type")})
					local vr = info.mindtype(ent)
					local wd = (info.hearttype[vr] or {name = Language:getText("coins", "unknown"),}).name

					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local vr = info.mindtype(ent)
					local val = (info.hearttype[vr] or {id = 0,}).id or vr
					local vval = info.tpmap[val] or val
					
					if dir == 1 then 
						val = val % info.mxn + 1
						val = info.tpmap[val] or val
					elseif dir == -1 then
						val = (val + info.mxn - 2) % info.mxn + 1
						val = info.tpmap[val] or val
					end
					if dir == 1 or dir == -1 then
						if (info.hearttype[vval].special_toturn) then
							info.hearttype[vval].special_toturn(ent,false)
						end
						if (info.hearttype[val].special_toturn) then
							info.hearttype[val].special_toturn(ent,true)
						else
							ent.SubType = val
						end
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 20 then 
						return true
					end
					return false
				end,
				hearttype = {
					[1] = {name = Language:getText("coins", "penny"), loadname = "gfx/005.021_penny.anm2"},
					[2] = {name = Language:getText("coins", "nickel"), loadname = "gfx/005.022_nickel.anm2"},
					[3] = {name = Language:getText("coins", "dime"), loadname = "gfx/005.023_dime.anm2"},
					[4] = {name = Language:getText("coins", "double_penny"), loadname = "gfx/005.024_double penny.anm2"},
					[5] = {name = Language:getText("coins", "lucky_penny"), loadname = "gfx/005.026_lucky penny.anm2"},
					[6] = {name = Language:getText("coins", "sticky_nickel"), loadname = "gfx/005.025_sticky nickel.anm2"},
					[7] = {name = Language:getText("coins", "golden_penny"), loadname = "gfx/005.027_golden penny.anm2"},
					[8] = {name = Language:getText("coins", "glaze_coin"), loadname = "gfx/Glaze/glaze_coin.anm2", special_toturn = function(ent,inout)
						if inout == true then ent.SubType = 4 end
						auxi.special_turn(ent,enums.Pickups.Glaze_coin,inout)
					end},
				},
				mindtype = function(ent)
					if ent.SubType == 4 and enums.Pickups.Glaze_coin.special_to_check(ent) then return 8 end
					return ent.SubType
				end,
				tpmap = {
				},
				mxn = 8,
			},
			[15] = {
				name = function(info,ent,choosed)
					ent = ent:ToPickup()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("cards", "card_id")})

					local vr = ent.SubType
					local wd = ({name = tostring(vr),} or {name = Language:getText("cards", "unknown"),}).name
					
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToPickup()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local val = ent.SubType
					local config = Isaac.GetItemConfig()
					local sz = config:GetCards().Size
					
					if dir == 1 then 
						val = val + 1
						while((val < sz) and (config:GetCard(val) == nil or config:GetCard(val).Hidden)) do
							val = val + 1
						end
					elseif dir == -1 then
						val = val - 1
						while(val > 0 and val < sz and (config:GetCard(val) == nil or config:GetCard(val).Hidden)) do
							val = val - 1
						end
					elseif dir == 2 then
						val = val + 20
						while((val < sz) and (config:GetCard(val) == nil or config:GetCard(val).Hidden)) do
							val = val + 1
						end
					elseif dir == -2 then
						val = val - 20
						while(val > 0 and val < sz and (config:GetCard(val) == nil or config:GetCard(val).Hidden)) do
							val = val - 1
						end
					end
					if dir == 1 or dir == -1 or dir == 2 or dir == -2 then
						if config:GetCard(val) and val > 0 then
							ent.SubType = val
							local Animation = s:GetAnimation()
							local frame = s:GetFrame()
							ent:Morph(ent.Type,ent.Variant,ent.SubType,true,true,true)
							ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
							s:SetFrame(Animation,frame)
							s:Play(Animation)
							return 0
						else
							return -1
						end
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToPickup()
					if ent.Variant == 300 then 
						return true
					end
					return false
				end,
				hearttype = {
				},
				tpmap = {
				},
				mxn = 14,
			},
			check = function(info,ent)
				if ent.IsGrid ~= nil then return false end
				if ent:ToPickup() == nil then return false end
				return true
			end,
		},
		[4] = {	--bomb
			[2] = {
				name = function(info,ent,choosed)
					ent = ent:ToBomb()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("bombs", "explosion_damage")})
					local wd = tostring(math.floor(ent.ExplosionDamage * 100)/100)
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToBomb()
					local d = ent:GetData()
					local dmg = ent.ExplosionDamage
					
					if dir == 1 then 
						ent.ExplosionDamage = math.max(dmg + 1,dmg * 1.05)
						return 0
					elseif dir == -1 then
						if ent.ExplosionDamage > 0.00001 then
							ent.ExplosionDamage = math.max(0,math.min(dmg - 1,dmg / 1.05))
						else
							return -1
						end
						return 0
					end
					return 1
				end,
			},
			[3] = {
				name = function(info,ent,choosed)
					ent = ent:ToBomb()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("bombs", "explosion_radius")})

					local wd = tostring(math.floor(ent.RadiusMultiplier * 100))
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToBomb()
					local d = ent:GetData()
					local val = ent.RadiusMultiplier
					
					if dir == 1 then 
						ent.RadiusMultiplier = math.max(val + 0.05,val * 1.05)
						return 0
					elseif dir == -1 then
						if ent.RadiusMultiplier > 0.10001 then
							ent.RadiusMultiplier = math.max(0.1,math.min(val - 0.05,val / 1.05))
						else
							return -1
						end
						return 0
					end
					return 1
				end,
			},
			[4] = {
				name = function(info,ent,choosed)
					ent = ent:ToBomb()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("bombs", "collision_damage")})
					local wd = tostring(math.floor(ent.CollisionDamage * 100)/100)
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToBomb()
					local d = ent:GetData()
					local val = ent.CollisionDamage
					
					if dir == 1 then 
						ent.CollisionDamage = math.max(val + 1,val * 1.05)
						return 0
					elseif dir == -1 then
						if val > 0.10001 then
							ent.CollisionDamage = math.max(0,math.min(val - 1,val / 1.05))
						else
							return -1
						end
						return 0
					end
					return 1
				end,
			},
			[1] = {
				name = function(info,ent,choosed)
					ent = ent:ToBomb()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "type")})
					local vr = ent.Variant
					local wd = (info.hearttype[vr] or {name = Language:getText("bomb_types", "unknown"),}).name
					
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToBomb()
					local d = ent:GetData()
					local s = ent:GetSprite()
					local heart = info.hearttype[ent.Variant]
					local val = (info.hearttype[ent.Variant] or {id = 0,}).id or ent.Variant
					
					if dir == 1 then 
						val = val % info.mxn + 1
						val = info.tpmap[val] or val
						ent.Variant = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					elseif dir == -1 then
						val = (val + info.mxn - 2) % info.mxn + 1
						val = info.tpmap[val] or val
						ent.Variant = val
						local Animation = s:GetAnimation()
						local frame = s:GetFrame()
						s:Load(info.hearttype[val].loadname,true)
						s:SetFrame(Animation,frame)
						s:Play(Animation)
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					ent = ent:ToBomb()
					if info.hearttype[ent.Variant] ~= nil then 
						return true
					end
					return false
				end,
				hearttype = {
					[3] = {name = Language:getText("bomb_types", "troll"), id = 1, loadname = "gfx/004.003_troll bomb.anm2"},
					[4] = {name = Language:getText("bomb_types", "mega_troll"), id = 2, loadname = "gfx/004.004_megatroll bomb.anm2"},
					[15] = {name = Language:getText("bomb_types", "brimstone"), id = 3, loadname = "gfx/004.015_brimstone bomb.anm2"},
					[16] = {name = Language:getText("bomb_types", "bloody_sad"), id = 4, loadname = "gfx/004.016_bloody sad bomb.anm2"},
					[18] = {name = Language:getText("bomb_types", "golden_troll"), id = 5, loadname = "gfx/004.018_golden troll bomb.anm2"},
				},
				tpmap = {
					[1] = 3,
					[2] = 4,
					[3] = 15,
					[4] = 16,
					[5] = 18,
				},
				mxn = 5,
			},
			check = function(info,ent)
				if ent.IsGrid ~= nil then return false end
				if ent:ToBomb() == nil then return false end
				return true
			end,
		},
		[5] = {	--slot
			check = function(info,ent)
				if ent.IsGrid ~= nil then return false end
				if ent.Type == 6 then return true end
				return false
			end,
		},
		[6] = {	--familiar
			[1] = {
				name = function(info,ent,choosed)
					ent = ent:ToFamiliar()
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("bombs", "collision_damage")})
					local wd = tostring(math.floor(ent.CollisionDamage * 100)/100)
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					ent = ent:ToFamiliar()
					local d = ent:GetData()
					local val = ent.CollisionDamage
					
					if dir == 1 then 
						ent.CollisionDamage = math.max(val + 1,val * 1.05)
						return 0
					elseif dir == -1 then
						if val > 0.10001 then
							ent.CollisionDamage = math.max(0,math.min(val - 1,val / 1.05))
						else
							return -1
						end
						return 0
					end
					return 1
				end,
			},
			check = function(info,ent)
				if ent.IsGrid ~= nil then return false end
				if ent:ToFamiliar() then return true end
				return false
			end,
		},
		[8] = {	--grid
			[10] = {		--不可用?
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("grid", "terrain")})
					local grid = saga_get_grid(ent)
					local wd = tostring(saga_grid_type(grid) or "?")
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent)
					if not grid then return 1 end
					--print(grid.State.." "..grid.Desc.VarData.." "..grid.Desc.State.." "..grid:GetSprite():GetAnimation())
					return 1
				end,
			},
			[1] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("grid", "size")})
					local d = ent:GetData()
					d.saga_modifier_size_vr = d.saga_modifier_size_vr or 1
					local vr = d.saga_modifier_size_vr
					
					local offset = Vector(0,0)
					local wd1 = tostring(math.floor(ent:GetSprite().Scale.X * 100)/100)
					if choosed and vr == 2 then wd1 = "<="..wd1.."=>" offset = offset + Vector(-5,0) end
					local wd2 = tostring(math.floor(ent:GetSprite().Scale.Y * 100)/100)
					if choosed and vr == 3 then wd2 = "<="..wd2.."=>" offset = offset + Vector(-5,0) end
					local wd = wd1.."X"..wd2
					if choosed and vr == 1 then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					
					return ret
				end,
				move = function(info,ent,dir)
					local d = ent:GetData()
					local succc = ent:GetData().saga_modifier_sprite_size
					local succc2 = ent:GetData().saga_modifier_size
					local spritesize = ent:GetSprite().Scale
					if dir == 1 then 
						if d.saga_modifier_size_vr == 1 then
							spritesize = spritesize * 1.05
						elseif d.saga_modifier_size_vr == 2 then
							spritesize = Vector(spritesize.X * 1.05,spritesize.Y)
						elseif d.saga_modifier_size_vr == 3 then
							spritesize = Vector(spritesize.X,spritesize.Y * 1.05)
						end
						ent:GetSprite().Scale = spritesize
						return 0
					elseif dir == -1 then
						if d.saga_modifier_size_vr == 1 then
							if spritesize.X - 0.00001 > 0.2 and spritesize.Y - 0.00001 > 0.2 then
								spritesize = math.max(math.min(0.2 * math.sqrt(2),spritesize:Length()),spritesize:Length() / 1.05) * spritesize:Normalized()
							else
								return -1
							end
						elseif d.saga_modifier_size_vr == 2 then
							if spritesize.X - 0.00001 > 0.2 then
								spritesize = Vector(math.max(math.min(0.2,spritesize.X),spritesize.X / 1.05),spritesize.Y)
							else
								return -1
							end
						elseif d.saga_modifier_size_vr == 3 then
							if spritesize.Y - 0.00001 > 0.2 then
								spritesize = Vector(spritesize.X,math.max(math.min(0.2,spritesize.Y),spritesize.Y / 1.05))
							else
								return -1
							end
						end
						ent:GetSprite().Scale = spritesize
						return 0
					elseif dir == 2 then
						d.saga_modifier_size_vr = d.saga_modifier_size_vr % 3 + 1
						return 0
					elseif dir == -2 then
						d.saga_modifier_size_vr = (d.saga_modifier_size_vr + 3 - 2) % 3 + 1
						return 0
					end
					return 1
				end,
			},
			[2] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("grid", "color")})
					local d = ent:GetData()
					d.saga_modifier_color_vr = d.saga_modifier_color_vr or 1
					local vr = d.saga_modifier_color_vr
					for i = 1,7 do
						local wd = info.colormap[i]..":"..tostring(math.floor((ent:GetSprite().Color[info.colormap[i]]) * 255))
						local offset = Vector(0,0)
						if choosed and vr == i then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
						table.insert(ret,#ret + 1,{wd = wd,offset = offset,col = auxi.AddColor(info.colorsmap[i],Color(0.5,0.5,0.5,1),ent:GetSprite().Color[info.colormap[i]],1-ent:GetSprite().Color[info.colormap[i]]),})
					end
					return ret
				end,
				move = function(info,ent,dir)
					local d = ent:GetData()
					d.saga_modifier_color_vr = d.saga_modifier_color_vr or 1
					local col = auxi.AddColor(ent:GetSprite().Color,Color(0,0,0,0),1,0)
					local succc = ent:GetData().saga_modifier_color
					
					if dir == 1 then
						col[info.colormap[d.saga_modifier_color_vr]] = col[info.colormap[d.saga_modifier_color_vr]] + 5/255
						local succ = Attribute_holder.try_hold_attribute(ent,"Color",col,{toget = function(ent) return ent:GetSprite().Color end,tochange = function(ent,value) ent:GetSprite().Color = value end,})
						if succc then Attribute_holder.try_rewind_attribute(ent,"Color",succc,{toget = function(ent) return ent:GetSprite().Color end,tochange = function(ent,value) ent:GetSprite().Color = value end,}) end
						d.saga_modifier_color = succ
						return 0
					elseif dir == -1 then
						col[info.colormap[d.saga_modifier_color_vr]] = col[info.colormap[d.saga_modifier_color_vr]] - 5/255
						local succ = Attribute_holder.try_hold_attribute(ent,"Color",col,{toget = function(ent) return ent:GetSprite().Color end,tochange = function(ent,value) ent:GetSprite().Color = value end,})
						if succc then Attribute_holder.try_rewind_attribute(ent,"Color",succc,{toget = function(ent) return ent:GetSprite().Color end,tochange = function(ent,value) ent:GetSprite().Color = value end,}) end
						d.saga_modifier_color = succ
						return 0
					elseif dir == 2 then
						d.saga_modifier_color_vr = d.saga_modifier_color_vr % 7 + 1
						return 0
					elseif dir == -2 then
						d.saga_modifier_color_vr = (d.saga_modifier_color_vr + 7 - 2) % 7 + 1
						return 0
					end
					return 1
				end,
				colormap = {
					[1] = "R",
					[2] = "G",
					[3] = "B",
					[4] = "A",
					[5] = "RO",
					[6] = "GO",
					[7] = "BO",
				},
				colorsmap = {
					[1] = Color(1,0,0,1),
					[2] = Color(0,1,0,1),
					[3] = Color(0,0,1,1),
					[4] = Color(1,1,1,0.5),
					[5] = Color(1,0.5,0.5,1),
					[6] = Color(0.5,1,0.5,1),
					[7] = Color(0.5,0.5,1,1),
				},
			},
			[3] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("grid", "rotation")})
					local wd = tostring(math.floor(ent:GetSprite().Rotation * 100)/100)
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local d = ent:GetData()
					local val = ent:GetSprite().Rotation
					
					if dir == 1 then 
						val = val + 5
						ent:GetSprite().Rotation = val
						return 0
					elseif dir == -1 then
						val = val - 5
						ent:GetSprite().Rotation = val
						return 0
					end
					return 1
				end,
			},
			[4] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("grid", "collision_type")})
					local d = ent:GetData()
					local coll = d.saga_held_collisionclass
					if coll == nil then
						local grid = saga_get_grid(ent)
						coll = grid and grid.CollisionClass
					end
					local wd = info.collisionmap[coll] or "？"
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent)
					if not grid then return 1 end
					local d = ent:GetData()
					-- 以已锁定目标为准，避免被 Rock:UpdateCollision 等每帧回写干扰读数
					local base = tonumber(d.saga_held_collisionclass)
					if base == nil then base = tonumber(grid.CollisionClass) or 0 end
					local succc = d.saga_modifier_collisionclass
					local desc = info.collision_attr
					local val

					if dir == 1 then
						val = (base + 1) % info.mxn
					elseif dir == -1 then
						val = (base + info.mxn - 1) % info.mxn
					else
						return 1
					end

					-- 先撤旧 token，再 hold 新值（V2）；protect 防止 origin 被引擎回写污染
					if succc then
						Attribute_holder.try_rewind_attribute(ent, "CollisionClass", succc, desc)
						grid = saga_get_grid(ent) or grid
					end
					local succ = Attribute_holder.try_hold_attribute(ent, "CollisionClass", val, desc)
					d.saga_held_collisionclass = val
					d.saga_modifier_collisionclass = succ
					-- hold 失败时仍直接写入；成功时 apply 已写，再写一次无害
					if grid then grid.CollisionClass = val end
					return 0
				end,
				collision_attr = {
					descriptor_key = "saga_grid_CollisionClass",
					protect = true,
					toget = function(e)
						local g = saga_get_grid(e)
						return (g and tonumber(g.CollisionClass)) or 0
					end,
					tochange = function(e, value)
						local g = saga_get_grid(e)
						if not g then return end
						g.CollisionClass = value
						local data = e.Data
						if data then data.saga_held_collisionclass = value end
					end,
				},
				collisionmap = {
					[GridCollisionClass.COLLISION_NONE] = Language:getText("collision", "none"),
					[GridCollisionClass.COLLISION_PIT] = Language:getText("collision", "pit"),
					[GridCollisionClass.COLLISION_OBJECT] = Language:getText("collision", "object"),
					[GridCollisionClass.COLLISION_SOLID] = Language:getText("collision", "solid"),
					[GridCollisionClass.COLLISION_WALL] = Language:getText("collision", "wall"),
					[GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER] = Language:getText("collision", "wall_except_player"),
				},
				mxn = 6,
			},
			check = function(info,ent)
				if ent.IsGrid ~= nil then return true end
				return false
			end,
		},
		[7] = {	--grid
			[1] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "type")})
					local grid = saga_get_grid(ent, "poop")
					if not grid then return ret end
					local desc = info.hearttype[grid:GetVariant()]
					if not desc then return ret end
					local wd = desc.name
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent, "poop")
					if not grid then return 1 end
					local val = grid:GetVariant()
					local vval = info.hearttype[val].id or val
					local s = grid:GetSprite()
					
					if dir == 1 then 
						vval = (vval + 1) % info.mxn
					elseif dir == -1 then
						vval = (vval + info.mxn - 1) % info.mxn
					end
					if dir == 1 or dir == -1 then
						vval = info.tpmap[vval] or vval
						grid:SetVariant(vval)
						local desc = info.hearttype[val]
						if desc then
							if info.hearttype[vval].special_toturn then info.hearttype[vval].special_toturn(ent,false) end
							if (desc.special_toturn) then desc.special_toturn(ent,true) end
							s:ReplaceSpritesheet(0,auxi.random_in_table(desc.pngname))
							s:LoadGraphics()
							if grid.Desc then grid:Init(grid.Desc.SpawnSeed) end
							grid:PostInit()
						end
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					local grid = saga_get_grid(ent, "poop")
					return grid ~= nil and info.hearttype[grid:GetVariant()] ~= nil
				end,
				hearttype = {
					[0] = {name = Language:getText("poop", "normal"), id = 0, pngname = {"gfx/grid/grid_poop_1.png","gfx/grid/grid_poop_2.png","gfx/grid/grid_poop_3.png"}},
					[1] = {name = Language:getText("poop", "red"), id = 1, pngname = {"gfx/grid/grid_poop_red_1.png","gfx/grid/grid_poop_red_2.png","gfx/grid/grid_poop_red_3.png"}},
					[2] = {name = Language:getText("poop", "corn"), id = 2, pngname = "gfx/grid/grid_poop_corn.png"},
					[3] = {name = Language:getText("poop", "gold"), id = 3, pngname = "gfx/grid/grid_poop_gold.png"},
					[4] = {name = Language:getText("poop", "rainbow"), id = 4, pngname = "gfx/grid/grid_poop_rainbow.png"},
					[5] = {name = Language:getText("poop", "black"), id = 5, pngname = "gfx/grid/grid_poop_black.png"},
					[6] = {name = Language:getText("poop", "holy"), id = 6, pngname = {"gfx/grid/grid_poop_white_1.png","gfx/grid/grid_poop_white_2.png","gfx/grid/grid_poop_white_3.png"}},
					[7] = {name = Language:getText("poop", "giant"), id = 7, pngname = "gfx/grid/grid_poop_giant.png", special_toturn = function(ent,inout)
						local grid = saga_get_grid(ent, "poop")
						if grid then
							local s = grid:GetSprite()
							if inout then
								s:Load("gfx/grid/grid_poop_giant.anm2",true)
							else
								s:Load("gfx/grid/grid_poop.anm2",true)
							end
						end
					end},
					[11] = {name = Language:getText("poop", "charming"), id = 8, pngname = "gfx/grid/grid_poop_charming.png"},
				},
				tpmap = {
					[8] = 11,
				},
				mxn = 9,
			},
			[2] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "status")})
					local desc = info.statemap[ent:GetSprite():GetAnimation()]
					if not desc then return ret end
					local wd = desc.name
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent, "poop")
					if not grid then return 1 end
					local desc = info.statemap[ent:GetSprite():GetAnimation()]
					if not desc then return 1 end
					local val = desc.id
					local vval = val
					local s = grid:GetSprite()
					
					if dir == 1 then 
						val = val + 1
						if val > info.mxn then return -1 end
					elseif dir == -1 then
						val = val - 1
						if val < 1 then return -1 end
					end
					if dir == 1 or dir == -1 then
						grid.State = (val - 1) * 250
						if grid.Desc then grid.Desc.State = grid.State end
						if val == info.mxn or vval == info.mxn then 
							if grid.Desc then grid:Init(grid.Desc.SpawnSeed) end
							grid:PostInit()
						end
						s:Play(info.tpmap[val].name,true)
						return 0
					end
					return 1
				end,
				check = function(info,ent)
					return saga_get_grid(ent, "poop") ~= nil
				end,
				statemap = {
					["Appear"] = {name = Language:getText("poop_states", "appear"), id = 0},
					["State1"] = {name = Language:getText("poop_states", "intact"), id = 1},
					["State2"] = {name = Language:getText("poop_states", "small_damage"), id = 2},
					["State3"] = {name = Language:getText("poop_states", "half_damage"), id = 3},
					["State4"] = {name = Language:getText("poop_states", "large_damage"), id = 4},
					["State5"] = {name = Language:getText("poop_states", "destroyed"), id = 5},
				},
				tpmap = {
					[0] = {name = "Appear",},
					[1] = {name = "State1",},
					[2] = {name = "State2",},
					[3] = {name = "State3",},
					[4] = {name = "State4",},
					[5] = {name = "State5",},
				},
				mxn = 5,
			},
			[3] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("other", "status")})
					local grid = saga_get_grid(ent, "door")
					if not grid then return ret end
					local desc = info.state_check(info,grid)
					local wd = tostring(info.statemap[desc] or "")
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent, "door")
					if not grid then return 1 end
					local desc = info.state_check(info,grid)
					local succc = ent:GetData().saga_modifier_door_open
					if dir == 1 then 
						if desc == 1 then return -1 end
						desc = 1
					elseif dir == -1 then
						if desc == 0 then return -1 end
						desc = 0
					end
					if dir == 1 or dir == -1 then
						if desc == 1 then
							if grid:CanBlowOpen() then grid:TryBlowOpen(false,nil) end
							grid:TryUnlock(Game():GetPlayer(0),true)
							local succ = Attribute_holder.try_hold_attribute(ent,"Door_Open",true,saga_door_open_params)
							if succc then Attribute_holder.try_rewind_attribute(ent,"Door_Open",succc,saga_door_open_params) end
							ent:GetData().saga_modifier_door_open = succ
						else
							local succ = Attribute_holder.try_hold_attribute(ent,"Door_Open",false,saga_door_open_params)
							if succc then Attribute_holder.try_rewind_attribute(ent,"Door_Open",succc,saga_door_open_params) end
							ent:GetData().saga_modifier_door_open = succ
						end
						return 0
					end
					return 1
				end,
				statemap = {
					[0] = Language:getText("door_states", "closed"),
					[1] = Language:getText("door_states", "open"),
				},
				check = function(info,ent)
					return saga_get_grid(ent, "door") ~= nil
				end,
				state_check = function(info,grid)
					local ret = 0
					if saga_grid_is_open(grid) then ret = ret | 1 end
					return ret
				end,
			},
			[4] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("ladder", "label")})
					local grid = saga_get_grid(ent, "pit")
					if not grid then return ret end
					local desc = tostring(grid.HasLadder)
					local wd = tostring(info.statemap[desc] or "")
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent, "pit")
					if not grid then return 1 end
					local desc = grid.HasLadder
					if dir == 1 then 
						if desc == true then return -1 end
						desc = true
					elseif dir == -1 then
						if desc == false then return -1 end
						desc = false
					end
					if dir == 1 or dir == -1 then
						if desc then 
							grid:SetLadder(true)
							local q = Isaac.Spawn(1000,8,0,grid.Position,Vector(0,0),nil)
							ent:GetData().Ladder = q
						else
							if ent:GetData().Ladder and ent:GetData().Ladder:Exists() then
								ent:GetData().Ladder:Remove()
								ent:GetData().Ladder = nil
							end
						end
						grid.HasLadder = desc
						return 0
					end
					return 1
				end,
				statemap = {
					["true"] = Language:getText("ladder", "has"),
					["false"] = Language:getText("ladder", "none"),
				},
				check = function(info,ent)
					return saga_get_grid(ent, "pit") ~= nil
				end,
			},
			[5] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("button", "status")})
					local grid = saga_get_grid(ent, "pressureplate")
					if not grid then return ret end
					local wd = (info.statemap[grid.State] or {name = "",}).name
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent, "pressureplate")
					if not grid then return 1 end
					local desc = grid.State
					if dir == 1 then 
						if desc == 3 then return -1 end
						desc = 3
					elseif dir == -1 then
						if desc == 0 then return -1 end
						desc = 0
					end
					if dir == 1 or dir == -1 then
						grid.State = desc
						if grid.Desc then grid.Desc.State = desc end
						local descinfo = info.statemap[desc]
						local s = saga_grid_sprite(grid)
						if s and descinfo and descinfo.playname then s:Play(descinfo.playname,true) end
						return 0
					end
					return 1
				end,
				statemap = {
					[0] = {name = Language:getText("button_states", "unpressed"), playname = "Off"},
					[1] = {name = Language:getText("button_states", "unknown")},
					[2] = {name = Language:getText("button_states", "unknown")},
					[3] = {name = Language:getText("button_states", "pressed"), playname = "On"},
				},
				mxn = 4,
				check = function(info,ent)
					local grid = saga_get_grid(ent, "pressureplate")
					return grid ~= nil and (function()
						local ok, v = pcall(function() return grid.NextGreedAnimation end)
						return ok and v == ""
					end)()
				end,
			},
			[6] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("tnt", "status")})
					local grid = saga_get_grid(ent, "tnt")
					if not grid then return ret end
					local wd = (info.statemap[grid.State] or {name = "",}).name
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent, "tnt")
					if not grid then return 1 end
					local desc = grid.State
					if dir == 1 then 
						if desc == 4 then return -1 end
						desc = desc + 1
					elseif dir == -1 then
						if desc == 0 then return -1 end
						desc = desc - 1
					end
					if dir == 1 or dir == -1 then
						grid.State = desc
						if grid.Desc then grid.Desc.State = desc end
						if desc < 4 then grid.FrameCnt = 3 end
						return 0
					end
					return 1
				end,
				statemap = {
					[0] = {name = Language:getText("tnt_states", "normal"), playname = "Idle"},
					[1] = {name = Language:getText("tnt_states", "small_damage"), playname = "Idle"},
					[2] = {name = Language:getText("tnt_states", "expanding"), playname = "IdleMedium"},
					[3] = {name = Language:getText("tnt_states", "about_to_explode"), playname = "ReadyToExplode"},
					[4] = {name = Language:getText("tnt_states", "exploded"), playname = "Blown"},
				},
				mxn = 5,
				check = function(info,ent)
					return saga_get_grid(ent, "tnt") ~= nil
				end,
			},
			[7] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("lock", "status")})
					local grid = saga_get_grid(ent, 11)
					if not grid then return ret end
					local wd = (info.statemap[grid.State] or {name = "",}).name
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent, 11)
					if not grid then return 1 end
					local desc = grid.State
					if dir == 1 then 
						if desc == info.mxn - 1 then return -1 end
						desc = desc + 1
					elseif dir == -1 then
						if desc == 0 then return -1 end
						desc = desc - 1
					end
					if dir == 1 or dir == -1 then
						grid.State = desc
						if grid.Desc then grid.Desc.State = desc end
						local descinfo = info.statemap[desc]
						local s = saga_grid_sprite(grid)
						if s and descinfo then s:Play(descinfo.playname,true) end
						if descinfo then grid.CollisionClass = descinfo.collision end
						return 0
					end
					return 1
				end,
				statemap = {
					[0] = {name = Language:getText("lock_states", "locked"), playname = "Idle", collision = GridCollisionClass.COLLISION_WALL},
					[1] = {name = Language:getText("lock_states", "unlocked"), playname = "Broken", collision = GridCollisionClass.COLLISION_NONE},
				},
				mxn = 2,
				check = function(info,ent)
					return saga_get_grid(ent, 11) ~= nil
				end,
			},
			[8] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("trap_door", "status")})
					local grid = saga_get_grid(ent, 17)
					if not grid then return ret end
					local wd = (info.statemap[grid.State] or {name = "",}).name
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent, 17)
					if not grid then return 1 end
					local desc = grid.State
					local succc = ent:GetData().saga_modifier_trap_door_open
					local succc2 = ent:GetData().saga_modifier_trap_door_open_sprite
					
					if dir == 1 then 
						if desc == info.mxn - 1 then return -1 end
						desc = desc + 1
					elseif dir == -1 then
						if desc == 0 then return -1 end
						desc = desc - 1
					end
					if dir == 1 or dir == -1 then
						if grid.Desc then grid.Desc.State = desc end
						grid.State = desc
						local descinfo = info.statemap[desc]
						local s = saga_grid_sprite(grid)
						if s and descinfo then s:Play(descinfo.playname,true) end
						local succ = Attribute_holder.try_hold_attribute(ent,"Trapdoor_Open",desc,saga_trapdoor_state_params)
						if succc then Attribute_holder.try_rewind_attribute(ent,"Trapdoor_Open",succc,saga_trapdoor_state_params) end
						ent:GetData().saga_modifier_trap_door_open = succ
						local succ2 = Attribute_holder.try_hold_attribute(ent,"Trapdoor_Open_Sprite",descinfo.playname,saga_trapdoor_sprite_params)
						if succc2 then Attribute_holder.try_rewind_attribute(ent,"Trapdoor_Open_Sprite",succc2,saga_trapdoor_sprite_params) end
						ent:GetData().saga_modifier_trap_door_open_sprite = succ2
						return 0
					end
					return 1
				end,
				statemap = {
					[0] = {name = Language:getText("trap_door_states", "closed"), playname = "Closed"},
					[1] = {name = Language:getText("trap_door_states", "open"), playname = "Opened"},
				},
				mxn = 2,
				check = function(info,ent)
					return saga_get_grid(ent, 17) ~= nil
				end,
			},
			[9] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("basement_door", "status")})
					local grid = saga_get_grid(ent, 18)
					if not grid then return ret end
					local wd = (info.statemap[grid.State] or {name = "",}).name
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent, 18)
					if not grid then return 1 end
					local desc = grid.State
					local succc = ent:GetData().saga_modifier_trap_door_open
					local succc2 = ent:GetData().saga_modifier_trap_door_open_sprite
					
					if dir == 1 then 
						if desc == info.mxn - 1 then return -1 end
						desc = desc + 1
					elseif dir == -1 then
						if desc == 0 then return -1 end
						desc = desc - 1
					end
					if dir == 1 or dir == -1 then
						if grid.Desc then grid.Desc.State = desc end
						grid.State = desc
						local descinfo = info.statemap[desc]
						local s = saga_grid_sprite(grid)
						if s and descinfo then s:Play(descinfo.playname,true) end
						local succ = Attribute_holder.try_hold_attribute(ent,"Basement_Open",desc,saga_basement_state_params)
						if succc then Attribute_holder.try_rewind_attribute(ent,"Basement_Open",succc,saga_basement_state_params) end
						ent:GetData().saga_modifier_trap_door_open = succ
						local succ2 = Attribute_holder.try_hold_attribute(ent,"Basement_Open_Sprite",descinfo.playname,saga_basement_sprite_params)
						if succc2 then Attribute_holder.try_rewind_attribute(ent,"Basement_Open_Sprite",succc2,saga_basement_sprite_params) end
						ent:GetData().saga_modifier_trap_door_open_sprite = succ2
						return 0
					end
					return 1
				end,
				statemap = {
					[0] = {name = Language:getText("basement_door_states", "closed"), playname = "Closed"},
					[1] = {name = Language:getText("basement_door_states", "open"), playname = "Opened"},
				},
				mxn = 2,
				check = function(info,ent)
					return saga_get_grid(ent, 18) ~= nil
				end,
			},
			[10] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("web", "status")})
					local grid = saga_get_grid(ent, 10)
					if not grid then return ret end
					local wd = (info.statemap[grid.State] or {name = "",}).name
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent, 10)
					if not grid then return 1 end
					local desc = grid.State
					if dir == 1 then 
						if desc == info.mxn - 1 then return -1 end
						desc = desc + 1
					elseif dir == -1 then
						if desc == 0 then return -1 end
						desc = desc - 1
					end
					if dir == 1 or dir == -1 then
						if grid.Desc then grid.Desc.State = desc end
						grid.State = desc
						local descinfo = info.statemap[desc]
						local s = saga_grid_sprite(grid)
						if s and descinfo then s:Play(descinfo.playname,true) end
						return 0
					end
					return 1
				end,
				statemap = {
					[0] = {name = Language:getText("web_states", "normal"), playname = "Idle"},
					[1] = {name = Language:getText("web_states", "damaged"), playname = "Bombed"},
				},
				mxn = 2,
				check = function(info,ent)
					return saga_get_grid(ent, 10) ~= nil
				end,
			},
			[11] = {
				name = function(info,ent,choosed)
					local ret = {}
					table.insert(ret,#ret + 1,{wd = Language:getText("spike", "status")})
					local grid = saga_get_grid(ent, "spikes")
					if not grid then return ret end
					local wd = (info.statemap[info.tpmap[grid.State]] or {name = "",}).name
					local offset = Vector(0,0)
					if choosed then wd = "<="..wd.."=>" offset = offset + Vector(-5,0) end
					table.insert(ret,#ret + 1,{wd = wd,offset = offset,})
					return ret
				end,
				move = function(info,ent,dir)
					local grid = saga_get_grid(ent, "spikes")
					if not grid then return 1 end
					local desc = info.tpmap[grid.State]
					local succc = ent:GetData().saga_modifier_spike_open
					local succc2 = ent:GetData().saga_modifier_spike_open_sprite
					
					if dir == 1 then 
						if desc == info.mxn - 1 then return -1 end
						desc = desc + 1
					elseif dir == -1 then
						if desc == 0 then return -1 end
						desc = desc - 1
					end
					if dir == 1 or dir == -1 then
						local descinfo = info.statemap[desc]
						local s = saga_grid_sprite(grid)
						local str = ""
						if s then
							local ok_a, anim = pcall(function() return s:GetAnimation() end)
							if ok_a and anim then str = anim end
						end
						local playname = descinfo.playname
						if string.find(str,"Womb") then playname = playname.."Womb" end
						if s then s:Play(playname,true) end
						local succ = Attribute_holder.try_hold_attribute(ent,"Spike_Open",descinfo.id,saga_spikes_state_params)
						if succc then Attribute_holder.try_rewind_attribute(ent,"Spike_Open",succc,saga_spikes_state_params) end
						ent:GetData().saga_modifier_spike_open = succ
						local succ2 = Attribute_holder.try_hold_attribute(ent,"Spike_Open_Sprite",playname,saga_spikes_sprite_params)
						if succc2 then Attribute_holder.try_rewind_attribute(ent,"Spike_Open_Sprite",succc2,saga_spikes_sprite_params) end
						ent:GetData().saga_modifier_spike_open_sprite = succ2
						return 0
					end
					return 1
				end,
				statemap = {
					[1] = {name = Language:getText("spike_states", "extended"), id = 0, playname = "Summon"},
					[0] = {name = Language:getText("spike_states", "retracted"), id = 1, playname = "Unsummon"},
				},
				tpmap = {
					[1] = 0,
					[0] = 1,
				},
				mxn = 2,
				check = function(info,ent)
					return saga_get_grid(ent, "spikes") ~= nil
				end,
			},
			check = function(info,ent)
				if ent.IsGrid ~= nil then return true end
				return false
			end,
		},
	},
	eventlist = {
		"Explosion",
		"Shoot",
		"Jump",
		"Land",
		"BloodStart",
		"BloodStop",
		--"Heartbeat",
		"Lift",
		"Stop",
		"Slide",
		"Spawn",
		"Shoot2",
		"DeathSound",
		"DropSound",
		"Disappear",
		"Prize",
		--"Shuffle",
		--"CoinInsert",
	},
	color_offset = {
		[0] = Color(1,1,1,1,1,1,1),
		[1] = Color(1,1,1,0.7,1,1,1),
		[2] = Color(1,1,1,0.5,1,1,1),
		[3] = Color(1,1,1,0.4,1,1,1),
		[4] = Color(1,1,1,0.3,1,1,1),
		[5] = Color(1,1,1,0.2,1,1,1),
		[6] = Color(1,1,1,0.1,1,1,1),
	},
	type_priority = {
		[EntityType.ENTITY_BOMB] = -2,
		[EntityType.ENTITY_SLOT] = 2,
		[EntityType.ENTITY_PICKUP] = 3,
		[EntityType.ENTITY_FAMILIAR] = 4,
	},
}
auxi.add_to_seija(item.entity)

local function check_screen_size(v)
	local screensize = ui.GetScreenSize()
	while(screensize.X > 256) do 
		screensize.X = screensize.X / 2 
		v.X = v.X / 2
	end
	while(screensize.Y > 256) do 
		screensize.Y = screensize.Y / 2 
		v.Y = v.Y / 2
	end
	return v
end

local function check_screen_multi(v)
	local screensize = ui.GetScreenSize()
	while(screensize.X > 256) do 
		screensize.X = screensize.X / 2 
		v.X = v.X * 2
	end
	while(screensize.Y > 256) do 
		screensize.Y = screensize.Y / 2 
		v.Y = v.Y * 2
	end
	return v
end
	
local function get_screensize_multi()
	local ret = 4
	local screensize = ui.GetScreenSize()
	while(screensize.X > 256) do 
		screensize.X = screensize.X / 2 
		ret = ret / 2
	end 
	return ret
end
--l local q = Isaac.Spawn(5,40,1,Vector(200,200),Vector(0,0),nil) q.SubType = 2
local function get_type_priority(ent)
	local ret = item.type_priority[ent.Type] or 0
	return ret
end

local function get_color_offset(idx)
	if item.color_offset[idx] then return item.color_offset[idx]
	else return item.color_offset[#item.color_offset] end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local d = player:GetData()
		if d.is_holding_S_Q_item ~= true then
			player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
			d.is_holding_S_Q_item = true
		else
			player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
			d.is_holding_S_Q_item = false
		end
	end
end,
})

local function try_find_target(pos,dir)
	local n_entity = Isaac.GetRoomEntities()
	local ret = nil
	local dis = -1
	for u,v in pairs(n_entity) do
		if (v.Position - (pos + dir)):Length() < 20 + v.Size and (ret == nil or (v.Position - (pos + dir)):Length() < dis) then
			dis = (v.Position - (pos + dir)):Length()
			ret = v
		end
	end
	return ret
end

local function makelist(ent)
	local d = ent:GetData()
	d.saga_list = {}
	local idx = 1
	for k = 1,#(item.changeable_state) do
		local v = item.changeable_state[k]
		if v.check == nil or v.check(v,ent) == true then
			for i = 1,#(v) do
				if v[i].check == nil or v[i].check(v[i],ent) == true then
					d.saga_list[idx] = {tp = k,vr = i,}
					idx = idx + 1
				end
			end
		end
	end
	d.saga_now_tp_id = math.max(1,math.min(idx - 1,d.saga_now_tp_id or 1))
	d.saga_mx_tp = idx - 1
end

local function get_safe_name(ent,name)
	local ret = ent[name]
	if type(ret) == "function" then ret = ret(ent) end
	return ret
end

local function get_saga_grid_info(pos,dir)
	local ret = {}
	dir = dir or 120
	if dir < 0 then dir = - dir end
	if pos ~= nil then
		dir = math.ceil(dir/40)
		local room = Game():GetRoom()
		local orig_idx = room:GetGridIndex(pos)
		local orig_pos = room:GetGridPosition(orig_idx)
		local dx = 1
		local dy = room:GetGridIndex(orig_pos + Vector(0,40)) - orig_idx
		local lr = orig_idx - dx * dir - dy * dir
		for i = 1,dir * 2 do
			for j = 1,dir * 2 do
				local grididx = lr + dx * (i - 1) + dy * (j - 1)
				if grididx >= 0 then
					local grid = room:GetGridEntity(grididx)
					if grid and item.grid_filter[grid:GetType()] == nil then
						table.insert(ret,{grid = grid,idx = grididx,})
					end
				end
			end
		end
	end
	return ret
end

-- Rock/门等会在 Grid Update 里 UpdateCollision 盖掉 CollisionClass。
-- 在 RGON 的 MC_POST_GRID_ENTITY_*_UPDATE 末尾回写，时机正好在引擎更新之后。
local function apply_held_collision_for_grid(grid)
	if not saga_grid_usable(grid) then return end
	local ok_idx, idx = pcall(function()
		return grid:GetGridIndex()
	end)
	if not ok_idx or type(idx) ~= "number" then return end
	local wrap = grid_entity.get_grid_entity(grid, idx)
	if not wrap then return end
	local data = wrap.Data
	local held = data and data.saga_held_collisionclass
	if held == nil then return end
	local ok_cc, cur = pcall(function()
		return grid.CollisionClass
	end)
	if not ok_cc then return end
	if cur ~= held then
		pcall(function()
			grid.CollisionClass = held
		end)
	end
end

local SAGA_GRID_UPDATE_CALLBACKS = {
	ModCallbacks.MC_POST_GRID_ENTITY_DECORATION_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_DOOR_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_FIRE_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_GRAVITY_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_LOCK_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_PIT_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_POOP_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_PRESSUREPLATE_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_ROCK_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_SPIKES_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_STAIRCASE_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_STATUE_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_TELEPORTER_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_TNT_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_TRAPDOOR_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_WEB_UPDATE,
}

for _, cb in ipairs(SAGA_GRID_UPDATE_CALLBACKS) do
	if cb ~= nil then
		table.insert(item.ToCall, #item.ToCall + 1, {
			CallBack = cb,
			params = nil,
			Function = function(_, grid)
				apply_held_collision_for_grid(grid)
			end,
		})
	end
end

table.insert(item.post_myToCall,#item.post_myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ then
		return (ent:GetData()._Data[item.own_key]["Price"] or val)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) and auxi.should_do_Seija(player) then
		local idx = player:GetData().__Index
		local mul = ((save.elses[item.own_key.."buff"] or {})[idx] or 0) * - 0.03
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + mul * item.buffs[1].mul
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * mul * item.buffs[2].mul)
		end
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * mul * item.buffs[3].mul
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + mul * item.buffs[4].mul
		end
		if cacheFlag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + mul * item.buffs[5].mul
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local ctrlid = player.ControllerIndex
	local d = player:GetData()
	local room = Game():GetRoom()
	if d.is_holding_S_Q_item == true then
		if player:IsHoldingItem() == false then
			d.is_holding_S_Q_item = false
		else
			local dir = 0
			for i = 4,7 do
				if (Input.IsActionPressed(i,ctrlid) and input_holder.actionsData[tostring(ctrlid)] and input_holder.actionsData[tostring(ctrlid)][i] and input_holder.actionsData[tostring(ctrlid)][i].ActionHoldTime and input_holder.actionsData[tostring(ctrlid)][i].ActionHoldTime == 1) then
					dir = i
				end
			end
			if dir > 0 then
				local vel = Vector(0,0)
				if room:IsMirrorWorld() == true and (dir == 4 or dir == 5) then dir = 9 - dir end
				if dir == 4 then vel = vel + Vector(-1,0)
				elseif dir == 5 then vel = vel + Vector(1,0)
				elseif dir == 6 then vel = vel + Vector(0,-1)
				elseif dir == 7 then vel = vel + Vector(0,1) end
				local vel_adder = player.Velocity
				if vel_adder:Length() < 0.3 then 
					vel_adder = Vector(0,0) 
				else
					vel_adder = vel_adder:Normalized()
				end
				vel = (vel:Normalized() * 2 + vel_adder):Normalized()
				player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
				d.is_holding_S_Q_item = false
				auxi.fire_dosome_knife(player.Position + player.Velocity,vel/1000,nil,"AttackUp",{list = {saga = 1,},anti_tearflag = ~BitSet128(0,0),dmg = 0,color = Color(1,1,1,1),saga = true,no_repel = true,no_open = true,no_grid = true,Flip = auxi.random_bool(),},nil)
			end
		end
	end
	if selection_holder.check_select(player,"Squiresaga") and Game():IsPaused() == false and item.targ ~= nil and item.now_display_rm * 20 > 0.5 then
		if (Input.IsActionTriggered(11,ctrlid) or Input.IsActionPressed(11,ctrlid)) then
			item.should_remove_targ = true
		end
		local dir = nil
		for u,i in pairs({4,5,6,7,9,10,13}) do
			if (Input.IsActionTriggered(i,ctrlid) or Input.IsActionPressed(i,ctrlid)) then
				dir = i
			end
		end
		local should_count = false
		if dir then
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
			if dir and auxi.should_do_Seija(player) then 
				local idx = player:GetData().__Index
				save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
				save.elses[item.own_key.."buff"][idx] = (save.elses[item.own_key.."buff"][idx] or 0) + 1
				player:AddCacheFlags(CacheFlag.CACHE_ALL)
				player:GetData().should_evaluate_on_update_once = true
			end
			local d = item.targ:GetData()
			if d.saga_list == nil then makelist(item.targ) end
			d.saga_now_tp_id = d.saga_now_tp_id or 1
			local info = item.changeable_state[d.saga_list[d.saga_now_tp_id].tp][d.saga_list[d.saga_now_tp_id].vr]
			if dir == 4 then
				local succ = info.move(info,item.targ,-1,item)
				if succ == 0 then sound_tracker.PlayStackedSound(195,1,1,false,0,2)
				elseif succ == -1 then sound_tracker.PlayStackedSound(187,1,1,false,0,2) end
			elseif dir == 5 then
				local succ = info.move(info,item.targ,1,item)
				if succ == 0 then sound_tracker.PlayStackedSound(194,1,1,false,0,2)
				elseif succ == -1 then sound_tracker.PlayStackedSound(187,1,1,false,0,2) end
			elseif dir == 6 then
				local succ = info.move(info,item.targ,-3,item)
				if succ == 1 then
					if d.saga_now_tp_id == 1 then
						d.saga_now_tp_id = d.saga_mx_tp
					else
						d.saga_now_tp_id = d.saga_now_tp_id - 1
					end
					sound_tracker.PlayStackedSound(195,0.8,1,false,0,2)
				end
			elseif dir == 7 then
				local succ = info.move(info,item.targ,3,item)
				if succ == 1 then
					if d.saga_now_tp_id == d.saga_mx_tp then
						d.saga_now_tp_id = 1
					else
						d.saga_now_tp_id = d.saga_now_tp_id + 1
					end
					sound_tracker.PlayStackedSound(194,0.8,1,false,0,2)
				end
			elseif dir == 13 then
				local succ = info.move(info,item.targ,2,item)
				if succ == 0 then sound_tracker.PlayStackedSound(195,1,1.05,false,0,2)
				elseif succ == -1 then sound_tracker.PlayStackedSound(187,1,1,false,0,2) end
			elseif dir == 10 then
				local succ = info.move(info,item.targ,-2,item)
				if succ == 0 then sound_tracker.PlayStackedSound(194,1,0.95,false,0,2)
				elseif succ == -1 then sound_tracker.PlayStackedSound(187,1,1,false,0,2) end
			elseif dir == 9 then
				info.move(info,item.targ,0,item)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if ent.Variant == enums.Entities.StabberKnife then
		if d.params and d.params.saga then
			if (s:IsPlaying("AttackUp") and s:IsFinished("AttackUp") == false) or (s:IsPlaying("AttackUp2") and s:IsFinished("AttackUp2") == false) then
				if d.inner_frame == 6 then
					if item.targ == nil then
						local n_entity = Isaac.GetRoomEntities()
						local player = Game():GetPlayer(0)
						if d.player then
							player = d.player
						elseif d.params and d.params.player then
							player = d.params.player
						end
						local nearest = nil
						local range = ent:GetSprite().Scale:Length()
						
						for u,v in pairs(n_entity) do
							if (ent.Position - v.Position):Length() < (40 * range + v.Size) and auxi.MakeVector((ent.Position - v.Position):GetAngleDegrees() - ent.RotationOffset).X < 0.05 and auxi.check_all_exists(v) then
								if item.uncheckable[v.Type] == nil and (nearest == nil or get_type_priority(nearest) < get_type_priority(v) or ((nearest.Position - player.Position):Length() > (v.Position - player.Position):Length() and get_type_priority(nearest) <= get_type_priority(v)))then
									nearest = v
								end
							end
						end
						
						if nearest == nil then
							local room = Game():GetRoom()
							local grids = get_saga_grid_info(ent.Position,55 * range)
							for u,v in pairs(grids) do
								if (ent.Position - room:GetGridPosition(v.idx)):Length() < 55 * range and auxi.MakeVector((ent.Position - room:GetGridPosition(v.idx)):GetAngleDegrees() - ent.RotationOffset).X < 0.05 then
									if nearest == nil or (ent.Position - room:GetGridPosition(v.idx)):Length() < ((ent.Position - room:GetGridPosition(nearest.idx)):Length()) then
										nearest = v
									end
								end
							end
							if nearest then nearest = grid_entity.get_grid_entity(nearest.grid,nearest.idx) end
						end
						
						if nearest then
							item.targ = nearest
							makelist(nearest)
							local dir = (get_safe_name(nearest,"Position") - player.Position):Normalized()
							for i = 1,3 do
								if dir.Y > 0 then 
									dir.Y = dir.Y + 2
								else 
									dir.Y = dir.Y - 2
								end
								dir = dir:Normalized()
							end
							local fk_dir = auxi.SafeVector(auxi.MakeVector(dir:GetAngleDegrees() - 90 + math.random(1000)/1000 * 4 - 2))
							item.now_display_dir = fk_dir
							sound_tracker.PlayStackedSound(SoundEffect.SOUND_TOOTH_AND_NAIL,math.random(1000)/10000 + 0.95,math.random(1000)/10000 + 0.95,false,0,2)
						end
						--d2.saga_has_modified = true
					end
				end
			end
		end
	end
end,
})

-- forward：PRE_GAME_STARTED 在 time_free 定义前注册，实际清理见 force_release_saga_ui
local force_release_saga_ui

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
	end
	if force_release_saga_ui then force_release_saga_ui() end
end,
})

local function time_stop()
	local n_entity = Isaac.GetRoomEntities() 
	for u,v in pairs(n_entity) do 
		if item.unstopable[v.Type] == nil then
			--print(v.Type.." "..v.Variant)
			local s = v:GetSprite()
			for u,v in pairs(item.eventlist) do
				if s:IsEventTriggered(v) ~= false then 
					s:Update()
				end
			end
			local d = v:GetData()
			if d.saga_flag_freeze_succ == nil then
				d.saga_flag_freeze_succ = Attribute_holder.try_hold_attribute(v,"EntityFlag_FLAG_FREEZE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
			end
			if d.saga_flag_no_sprite_update_succ == nil then
				d.saga_flag_no_sprite_update_succ = Attribute_holder.try_hold_attribute(v,"EntityFlag_FLAG_NO_SPRITE_UPDATE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_SPRITE_UPDATE))
			end
			-- protect：与 auxi.time_stop 对齐，避免外部改 Position 把冻结原点吸走
			if d.saga_flag_position_succ == nil then
				d.saga_flag_position_succ = Attribute_holder.try_hold_attribute(v,"Position",Vector(v.Position.X,v.Position.Y),{protect = true,tocompare = function(v1,v2) return (v1 - v2):Length() < 0.001 end,})
			end
			if d.saga_flag_velocity_succ == nil then
				d.saga_flag_velocity_succ = Attribute_holder.try_hold_attribute(v,"Velocity",Vector(0,0),{protect = true,tocompare = function(v1,v2) return (v1 - v2):Length() < 0.001 end,})
			end
		end
	end
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		if d.saga_flag_entitycollisionclass_none_succ == nil then
			d.saga_flag_entitycollisionclass_none_succ = Attribute_holder.try_hold_attribute(player,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
		end
		if d.saga_data_should_not_attack_succ == nil then
			d.saga_data_should_not_attack_succ = Attribute_holder.try_hold_attribute(player,"Data_should_not_attack",true,Attribute_holder.descriptors.data_field("should_not_attack"))
		end
	end
end

local function time_free()
	local n_entity = Isaac.GetRoomEntities() 
	for u,v in pairs(n_entity) do 
		if item.unstopable[v.Type] == nil then
			local d = v:GetData()
			if d.saga_flag_freeze_succ then
				Attribute_holder.try_rewind_attribute(v,"EntityFlag_FLAG_FREEZE",d.saga_flag_freeze_succ,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
				d.saga_flag_freeze_succ = nil
			end
			if d.saga_flag_no_sprite_update_succ then
				Attribute_holder.try_rewind_attribute(v,"EntityFlag_FLAG_NO_SPRITE_UPDATE",d.saga_flag_no_sprite_update_succ,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_SPRITE_UPDATE))
				d.saga_flag_no_sprite_update_succ = nil
			end
			if d.saga_flag_position_succ then
				Attribute_holder.try_rewind_attribute(v,"Position",d.saga_flag_position_succ,{tocompare = function(v1,v2) return (v1 - v2):Length() < 0.001 end,})
				d.saga_flag_position_succ = nil
			end
			if d.saga_flag_velocity_succ then
				Attribute_holder.try_rewind_attribute(v,"Velocity",d.saga_flag_velocity_succ,{tocompare = function(v1,v2) return (v1 - v2):Length() < 0.001 end,})
				d.saga_flag_velocity_succ = nil
			end
		end
	end
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		if d.saga_flag_entitycollisionclass_none_succ then
			Attribute_holder.try_rewind_attribute(player,"EntityCollisionClass",d.saga_flag_entitycollisionclass_none_succ)
			d.saga_flag_entitycollisionclass_none_succ = nil
		end
		if d.saga_data_should_not_attack_succ then
			Attribute_holder.try_rewind_attribute(player,"Data_should_not_attack",d.saga_data_should_not_attack_succ,{toget = function(ent) return ent:GetData().should_not_attack end,tochange = function(ent,value) ent:GetData().should_not_attack = value end,})
			d.saga_data_should_not_attack_succ = nil
		end
	end
end

force_release_saga_ui = function()
	-- 重开/续关/换房兜底：解开时停 hold 与选物锁，否则 should_not_attack 会让准星（含鼠标）永久失灵
	for i = 0, Game():GetNumPlayers() - 1 do
		pcall(function()
			local p = Game():GetPlayer(i)
			if p then
				selection_holder.remove_select(p, "Squiresaga")
				-- Attribute rewind 失败时仍强制清禁攻标记
				local d = p:GetData()
				if d.should_not_attack == true and d.saga_data_should_not_attack_succ == nil then
					d.should_not_attack = nil
				end
			end
		end)
	end
	pcall(time_free)
	item.now_display_rm = 0
	item.now_display_pos = nil
	item.now_display_pos_r = nil
	item.now_display_dir = Vector(1,0)
	item.stoped = false
	item.should_remove_targ = nil
	item.targ = nil
	item.render_sprite_pos = nil
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil, priority = 10,
Function = function(_)
	-- 换房/下层：解除时停 hold，避免玩家 ENTCOLL_NONE 与门 Door_Open 残留
	if item.stoped or item.now_display_rm > 0.001 then
		force_release_saga_ui()
	end
	item.targ = nil
	item.render_sprite_pos = nil
	item.should_remove_targ = nil
	item.now_display_rm = 0
	item.now_display_pos = nil
	item.now_display_pos_r = nil
end,
})

local function renderbox(offset,alpha)
	local render_idx = 1
	--local move_dir = check_screen_size(Vector(- item.now_display_dir.Y / item.now_display_dir.X * 1.8,1)):Normalized() * 10
	local move_dir = check_screen_multi(Vector(- item.now_display_dir.Y / item.now_display_dir.X,1)):Normalized() * 10
	if item.targ == nil then return end
	local d = item.targ:GetData()
	if d.saga_list == nil then makelist(item.targ) end
	local idx = d.saga_now_tp_id or 1
	for i = idx,d.saga_mx_tp do
		local selected = (i == idx)
		local info = item.changeable_state[d.saga_list[i].tp][d.saga_list[i].vr]
		local names = info.name(info,item.targ,selected,item)
		for j = 1,#names do
			local word = names[j].wd or ""
			local offset2 = names[j].offset or Vector(0,0)
			local col = names[j].col or Color(1,1,1,1)
			col = auxi.MulColor(col,get_color_offset(math.abs(i - idx)))
			local real_pos = offset + render_idx * move_dir + offset2
			d["saga_render_box_pos_"..tostring(i).."_"..tostring(j)] = (d["saga_render_box_pos_"..tostring(i).."_"..tostring(j)] or real_pos) * 0.9 + real_pos * 0.1
			d["saga_render_box_col_"..tostring(i).."_"..tostring(j)] = auxi.AddColor((d["saga_render_box_col_"..tostring(i).."_"..tostring(j)] or col),col,0.9,0.1)
			gui.draw_ch(d["saga_render_box_pos_"..tostring(i).."_"..tostring(j)],word,1,1,auxi.AddColor(d["saga_render_box_col_"..tostring(i).."_"..tostring(j)],Color(0,0,0,0),alpha,1-alpha,true),true)
			render_idx = render_idx + 1
		end
		render_idx = render_idx + 0.5
	end
	for i = 1,idx - 1 do
		local selected = (i == idx)
		local info = item.changeable_state[d.saga_list[i].tp][d.saga_list[i].vr]
		local names = info.name(info,item.targ,selected,item)
		for j = 1,#names do
			local word = names[j].wd
			local offset2 = names[j].offset or Vector(0,0)
			local col = names[j].col or Color(1,1,1,1)
			col = auxi.MulColor(col,get_color_offset(math.abs(d.saga_mx_tp + i - idx)))
			local real_pos = offset + render_idx * move_dir + offset2
			d["saga_render_box_pos_"..tostring(i).."_"..tostring(j)] = (d["saga_render_box_pos_"..tostring(i).."_"..tostring(j)] or real_pos) * 0.9 + real_pos * 0.1
			d["saga_render_box_col_"..tostring(i).."_"..tostring(j)] = auxi.AddColor((d["saga_render_box_col_"..tostring(i).."_"..tostring(j)] or col),col,0.9,0.1)
			gui.draw_ch(d["saga_render_box_pos_"..tostring(i).."_"..tostring(j)],word,1,1,auxi.AddColor(d["saga_render_box_col_"..tostring(i).."_"..tostring(j)],Color(0,0,0,0),alpha,1-alpha,true),true)
			render_idx = render_idx + 1
		end
		render_idx = render_idx + 0.5
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,		--璁板綍鏁板瓧
Function = function(_,name)
	if name == "Squiresaga" then
		if item.targ and (item.targ:Exists() == false or item.targ:IsDead() == true) then
			item.targ = nil
			item.render_sprite_pos = nil
		end
		local should_render = (item.targ ~= nil and Game():IsPaused() == false and item.should_remove_targ == nil)
		local screensize = ui.GetScreenSize()
		if should_render then
			item.now_display_pos = Isaac.WorldToScreen(get_safe_name(item.targ,"Position") + item.targ.PositionOffset)
			item.now_display_pos_r = (item.now_display_pos_r or item.now_display_pos) * 0.96 + item.now_display_pos * 0.04
			local delta = item.now_display_pos_r.Y - screensize.Y * 0.1
			item.render_sprite_pos = (item.render_sprite_pos or item.now_display_pos_r) * 0.94 + Vector(item.now_display_pos_r.X + delta * item.now_display_dir.Y / item.now_display_dir.X,screensize.Y * 0.1) * 0.06
			item.now_display_rm = item.now_display_rm * 0.96 + item.mx_rm * 0.04
		else
			item.now_display_rm = item.now_display_rm * 0.92 + 0 * 0.08
			if item.targ then
				item.now_display_pos = Isaac.WorldToScreen(get_safe_name(item.targ,"Position") + item.targ.PositionOffset)
				item.now_display_pos_r = (item.now_display_pos_r or item.now_display_pos) * 0.92 + item.now_display_pos * 0.08
				local delta = item.now_display_pos.Y - screensize.Y * 0.2
				item.render_sprite_pos = (item.render_sprite_pos or item.now_display_pos_r) * 0.9 + item.now_display_pos_r * 0.1
			end
		end
		if item.now_display_rm > 0.001 then
			local player = Game():GetPlayer(0)
			local succ = selection_holder.check_and_try_select(player,"Squiresaga")
			if succ then
				item.stoped = true
				time_stop()
				local r_pos = item.now_display_pos_r
				if r_pos then
					local t_pos = check_screen_size(r_pos/256)
					--print(t_pos)
					local A = item.now_display_dir.X
					local B = item.now_display_dir.Y
					local C = -(t_pos.X * A + t_pos.Y * B)
					local D = item.now_display_rm * get_screensize_multi()
					--print(tostring(A).." "..B.." "..C.." "..D)
					local ret_info = {A,B,C,D,}
					local mul = ret_info[4]/(ret_info[1] * ret_info[1] + ret_info[2] * ret_info[2])
					local ret_info2 = {ret_info[1] * mul,ret_info[2] * mul,0,0,}
					if item.targ then
						renderbox(item.render_sprite_pos + Vector(-20,0),item.now_display_rm * 20)
						local s = item.targ:GetSprite()
						--print(s.Offset)
						local offset = Vector(0,math.min(0,s.Offset.Y * 0.5))
						if item.targ.IsGrid ~= nil then offset = offset + Vector(0,-10) end
						s:Render(item.render_sprite_pos + offset,Vector(0,0),Vector(0,0))
					end
					return {
						info1 = ret_info,
						info2 = ret_info2,
						should_work = 1,
					}
				end
			end
		else
			item.now_display_pos = nil
			item.now_display_pos_r = nil
			if item.should_remove_targ ~= nil then
				item.targ = nil
				item.render_sprite_pos = nil
				item.should_remove_targ = nil
			end
		end
		if item.stoped then
			local p = player or Game():GetPlayer(0)
			selection_holder.remove_select(p,"Squiresaga")
			time_free()
			item.stoped = false
		end
		return {
			info1 = {0,0,0,0,},
			info2 = {0,0,0,0,},
			should_work = 0,
		}
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if ent ~= nil then
		local player = ent:ToPlayer()
		-- 必须同时 stoped：仅靠 selection 残留会永久挡射击；面板关后 stoped 会清掉
		if player and item.stoped and player:HasCollectible(item.entity) and selection_holder.check_select(player,"Squiresaga") then
			-- 含 ACTION_PILLCARD(Q)：口袋主动/卡牌；缺它时口袋蓝图仍能打开
			local blocked = {
				[ButtonAction.ACTION_SHOOTLEFT] = true,
				[ButtonAction.ACTION_SHOOTRIGHT] = true,
				[ButtonAction.ACTION_SHOOTUP] = true,
				[ButtonAction.ACTION_SHOOTDOWN] = true,
				[ButtonAction.ACTION_BOMB] = true,
				[ButtonAction.ACTION_ITEM] = true,
				[ButtonAction.ACTION_PILLCARD] = true,
				[ButtonAction.ACTION_DROP] = true,
				[ButtonAction.ACTION_MAP] = true,
			}
			if blocked[button] and (hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED) then
				return false
			end
		end
	end
end,
})

--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do v:AddEntityFlags(EntityFlag.FLAG_FREEZE | EntityFlag.FLAG_NO_SPRITE_UPDATE) end
--l local item = RegisterMod("EXTRA_CODE",1) local tbl = {} item:AddPriorityCallback(ModCallbacks.MC_GET_SHADER_PARAMS,-100, function(_,name) if name == "Squiresaga" and tbl[1] == nil then tbl[1] = 1 print(1) end end)
return item

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local glaze_enemy = require("Qing_Remaster_scripts.pickups.pickup_glaze_enemy")

-- 在右侧 Found HUD / Extra HUD 之后，半透明绘制本模组临时（imitate）道具
-- 原点：有原版格时用 HistoryHUD Get*Offsets 左上；空列表时从 (0,0) 起排。
-- 仅保留 Pad / Step。各来源可通过 register_provider 指定配色（优先 Colorize）。
local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Temp_item_hud_",
	providers = {},
	-- function(entity) -> bool；用于尚未入手、但已被标记为临时的底座等
	entity_checkers = {},
	sprite_cache = {},
	_eid_registered = false,
	-- 通用 imitate 默认：Tint 近白 + 柔和青灰 Colorize（非琉璃化）
	default_color = Color(1,1,1,0.52,0,0,0,0.95,1.35,1.55,1),
	default_large_pad = Vector(16,38),
	default_mini_pad = Vector(8,19),
	eid_category_id = "QingTempItems",
	_eid_category_registered = false,
	-- id -> {resolver, source_icon}
	_eid_entry_meta = {},
	-- 琉璃化关键点表（与 glaze_enemy / glaze 掉落 anm2 一致）
	glaze_colorinfo = glaze_enemy.Colorinfo,
}

-- provider(player) -> {[id]=count} 或 {items={[id]=count}, color?=Color, exclusive?=bool}
-- opts: {
--   color, color_fn, scale_fn, exclusive,
--   glaze=true 使用琉璃化闪烁/跳动,
--   dogma_chromatic=true / rainbow_cellular=true（或显式 shader=）,
--   rainbow_seed=0..1 基础种子（可与 collectible id 再混合）,
--   shader="shaders/..." RGON Sprite:SetCustomShader（相对 resources/）,
--   source_item=collectibleId 或 source_icon="{{CollectibleN}}" 供 EID 名字后标注来源
-- }
item.DOGMA_CHROMATIC_SHADER = "shaders/qing_dogma_chromatic"
item.RAINBOW_CELLULAR_SHADER = "shaders/qing_rainbow_cellular"
-- 完整彩虹 Hue 一圈：1200 帧 ≈ 40s（30 FPS）
item.RAINBOW_PHASE_CYCLE_FRAMES = 1200

function item.dogma_shader_time()
	return (Game():GetFrameCount() % 10000) / 10000
end

-- Colorize.r=扭曲强度（默认 0，便于确认像素抖是否来自 glitch），Colorize.a=噪点时钟
function item.make_dogma_chromatic_color(alpha,glitch)
	alpha = alpha or 0.58
	glitch = glitch or 0
	return Color(1,1,1,alpha,0,0,0,glitch,0,0,item.dogma_shader_time())
end

function item.rainbow_shader_phase()
	local cycle = math.max(1, math.floor(tonumber(item.RAINBOW_PHASE_CYCLE_FRAMES) or 1200))
	return (Game():GetFrameCount() % cycle) / cycle
end

--- Colorize.r=seed，Colorize.a=phase（与 dogma 传时通道一致；Offset 保持 0）
--- 必须经 SetColorize 写入；仅靠构造函数多余参数在部分路径上不会每帧推进 phase。
function item.make_rainbow_cellular_color(alpha,seed)
	alpha = alpha or 0.58
	seed = tonumber(seed) or 0.37
	seed = seed % 1
	if seed < 0 then seed = seed + 1 end
	local phase = item.rainbow_shader_phase()
	local col = Color(1,1,1,alpha,0,0,0)
	if col.SetColorize then
		col:SetColorize(seed,0,0,phase)
	else
		col = Color(1,1,1,alpha,0,0,0,seed,0,0,phase)
	end
	return col
end

function item.rainbow_seed_for_collectible(base_seed,collectible_id)
	base_seed = tonumber(base_seed) or 0.37
	local id = tonumber(collectible_id) or 0
	local mixed = base_seed + id * 0.6180339887
	mixed = mixed % 1
	if mixed < 0 then mixed = mixed + 1 end
	return mixed
end

function item.apply_sprite_shader(sprite,shader_path)
	if not REPENTOGON or not sprite or type(shader_path) ~= "string" or shader_path == "" then return end
	if not sprite.SetCustomShader then return end
	-- STATIC/GOLD 会屏蔽自定义 coloroffset shader
	if sprite.GetRenderFlags and sprite.SetRenderFlags then
		local flags = sprite:GetRenderFlags() or 0
		local cleared = flags & ~((1 << 5) | (1 << 7))
		if cleared ~= flags then sprite:SetRenderFlags(cleared) end
	end
	if sprite.HasCustomShader and sprite:HasCustomShader(shader_path) then return end
	sprite:SetCustomShader(shader_path)
end

function item.clear_sprite_shader(sprite)
	if not REPENTOGON or not sprite or not sprite.ClearCustomShader then return end
	if sprite.HasCustomShader and sprite:HasCustomShader() then
		sprite:ClearCustomShader()
	end
end

function item.register_provider(provider,opts)
	if type(provider) ~= "function" then return end
	opts = opts or {}
	local source_icon = opts.source_icon
	if not source_icon and opts.source_item then
		source_icon = "{{Collectible"..tostring(opts.source_item).."}}"
	end
	local color_fn = type(opts.color_fn) == "function" and opts.color_fn or nil
	local scale_fn = type(opts.scale_fn) == "function" and opts.scale_fn or nil
	if opts.glaze then
		color_fn = color_fn or function()
			local col = item.get_glaze_visual()
			return col
		end
		scale_fn = scale_fn or function()
			local _,sc = item.get_glaze_visual()
			return sc
		end
	end
	if opts.dogma_chromatic then
		opts.shader = opts.shader or item.DOGMA_CHROMATIC_SHADER
		color_fn = color_fn or function()
			if REPENTOGON then
				return item.make_dogma_chromatic_color(0.58,0)
			end
			-- 无 RGON 时退回靛紫 Colorize
			return Color(1,1,1,0.58,0,0,0,1.55,0.9,2.5,1)
		end
	end
	if opts.rainbow_cellular then
		opts.shader = opts.shader or item.RAINBOW_CELLULAR_SHADER
		local base_seed = tonumber(opts.rainbow_seed) or 0.37
		color_fn = color_fn or function(collectible_id)
			if REPENTOGON then
				local seed = item.rainbow_seed_for_collectible(base_seed,collectible_id)
				return item.make_rainbow_cellular_color(0.58,seed)
			end
			-- 无 RGON：高饱和品红/青 Colorize 兜底
			return Color(1,1,1,0.58,0,0,0,2.2,0.55,2.4,1)
		end
	end
	item.providers[#item.providers + 1] = {
		fn = provider,
		color = opts.color,
		color_fn = color_fn,
		scale_fn = scale_fn,
		exclusive = opts.exclusive == true,
		source_icon = source_icon,
		source_card = opts.source_card,
		glaze = opts.glaze == true,
		shader = opts.shader,
		-- ghost=true / ghost_fn() -> Vector：主图标后画一层半透明错位残影（精神失序等）
		ghost = opts.ghost == true or type(opts.ghost_fn) == "function",
		ghost_fn = type(opts.ghost_fn) == "function" and opts.ghost_fn or nil,
		ghost_alpha = tonumber(opts.ghost_alpha) or 0.2,
	}
end

function item.register_temp_entity_checker(checker)
	if type(checker) ~= "function" then return end
	item.entity_checkers[#item.entity_checkers + 1] = checker
end

-- EID「由…提供」用卡牌图标：青模组卡面多为 18x32@50%(≈9px 宽)，槽位按 16 计，需右移居中
-- 键名刻意不含 "Card"，避免 EID createItemIconObject 的 gsub("Card") 误伤
function item.make_card_source_icon(card_id)
	card_id = tonumber(card_id)
	if not card_id then return "" end
	if not EID or not EID.InlineIcons then
		return "{{Card"..card_id.."}}"
	end
	local key = "QingTmpSrcK"..tostring(card_id)
	if not EID.InlineIcons[key] then
		local base = EID.InlineIcons["Card"..tostring(card_id)]
		if type(base) == "table" then
			EID.InlineIcons[key] = {
				base[1],
				base[2],
				base[3] or 16,
				base[4] or 16,
				4, -- 相对默认 0 右移，对齐窄塔罗卡面
				base[6] or 1,
				base[7],
			}
		else
			return "{{Card"..card_id.."}}"
		end
	end
	return "{{"..key.."}}"
end

-- 琉璃化：按 glaze_enemy.Colorinfo 插值 Tint/Offset + Scale（闪烁并跳动）
function item.get_glaze_visual(frame)
	local info_tbl = item.glaze_colorinfo or glaze_enemy.Colorinfo
	frame = frame or (Game and Game():GetFrameCount()) or 0
	local total = (info_tbl and info_tbl.total) or 18
	local info = auxi.check_lerp(frame % total,info_tbl)
	local col = auxi.table2color(info)
	local t = auxi.color2table(col)
	-- 对齐 glazed_item.anm2 的 AlphaTint≈125
	t.A = (t.A or 1) * 0.5
	local scale = info.scale or Vector(1,1)
	return auxi.table2color(t),scale
end

function item.get_glaze_color(frame)
	local col = item.get_glaze_visual(frame)
	return col
end

local function gameplay_cfg()
	local cfg = save.ModConfigSettings
	return cfg and cfg.QingRemasterOptions and cfg.QingRemasterOptions.Gameplay
end

local function option_enabled()
	local g = gameplay_cfg()
	if g and g.ShowTempItemHUD == false then return false end
	return true
end

local function hud_style_ready()
	if not REPENTOGON then return false end
	if not Game():GetHUD():IsVisible() then return false end
	local style = Options.ExtraHUDStyle or 0
	return style > 0
end

local function num(v,default)
	v = tonumber(v)
	if v == nil then return default end
	return v
end

local function copy_color(c)
	return auxi.copy_color(c or item.default_color)
end

local function layout_settings()
	local g = gameplay_cfg() or {}
	local mini = (Options.ExtraHUDStyle or 1) == 2
	local pad_default = mini and item.default_mini_pad or item.default_large_pad
	local pad = Vector(
		num(mini and g.TempHUD_MiniPadX or g.TempHUD_LargePadX, pad_default.X),
		num(mini and g.TempHUD_MiniPadY or g.TempHUD_LargePadY, pad_default.Y)
	)
	local columns = math.max(1,(Options.ExtraHUDStyle or 1) * 2)
	local scale = mini and 0.5 or 1
	local step = num(mini and g.TempHUD_MiniStep or g.TempHUD_LargeStep, 32 * scale)
	return {
		mini = mini,
		pad = pad,
		columns = columns,
		scale = scale,
		step = step,
	}
end

local function normalize_provider_result(ret,fallback_color)
	if type(ret) ~= "table" then return {},fallback_color,false end
	local counts = ret.items or ret
	local color = ret.color or fallback_color
	local exclusive = ret.exclusive == true
	if ret.items == nil and (ret.color ~= nil or ret.exclusive ~= nil or ret.source_icon ~= nil) then
		counts = {}
		for k,v in pairs(ret) do
			if k ~= "color" and k ~= "exclusive" and k ~= "items" and k ~= "source_icon" then
				counts[k] = v
			end
		end
	end
	return counts,color,exclusive
end

local function append_counts(entries,counts,color,exclusive_counts,meta)
	meta = meta or {}
	if not counts then return end
	for id,count in pairs(counts) do
		local cid = tonumber(id)
		local n = tonumber(count) or 0
		if cid and cid > 0 and n > 0 then
			if exclusive_counts then
				exclusive_counts[cid] = (exclusive_counts[cid] or 0) + n
			end
			entries[#entries + 1] = {
				id = cid,
				count = n,
				color = copy_color(color),
				color_fn = meta.color_fn,
				scale_fn = meta.scale_fn,
				source_icon = meta.source_icon,
				source_card = meta.source_card,
				glaze = meta.glaze,
				shader = meta.shader,
				ghost = meta.ghost,
				ghost_fn = meta.ghost_fn,
				ghost_alpha = meta.ghost_alpha,
			}
		end
	end
end

local function resolve_entry_color(entry)
	if entry.color_fn then
		local ok,col = pcall(entry.color_fn,entry and entry.id)
		if ok and col then return col end
	end
	return entry.color or copy_color(item.default_color)
end

local function resolve_entry_scale_mul(entry)
	if entry.scale_fn then
		local ok,sc = pcall(entry.scale_fn)
		if ok and sc then return sc end
	end
	return Vector(1,1)
end

local function collect_from_imitate_recorder(player)
	local idx = player:GetData() and player:GetData().__Index
	if not idx then return {} end
	local recorder = save.elses and save.elses["Imi_item_r_recorder"]
	return recorder and recorder[idx] or {}
end

local function collect_from_imitate_meta(player)
	local idx = player:GetData() and player:GetData().__Index
	if not idx then return {} end
	local meta = save.elses and save.elses["Imi_item_r_meta"]
	return meta and meta[idx] or {}
end

-- 仅扫 register_provider，不含 meta.display（避免与 costume 默认判断循环）
function item.id_shown_by_providers(player,collectible_id)
	collectible_id = tonumber(collectible_id)
	if not player or not collectible_id then return false end
	for _,provider in ipairs(item.providers) do
		local ok,ret = pcall(provider.fn,player)
		if ok and ret then
			local counts = normalize_provider_result(ret,provider.color or item.default_color)
			local n = tonumber(counts[collectible_id]) or tonumber(counts[tostring(collectible_id)]) or 0
			if n > 0 then return true end
		end
	end
	return false
end

-- opts.include_actives：EID 临时页需要；Extra HUD 默认仍排除主动
function item.collect_temp_entries(player,opts)
	opts = opts or {}
	local include_actives = opts.include_actives == true
	local entries = {}
	local exclusive_counts = {}
	local provider_ids = {}

	for _,provider in ipairs(item.providers) do
		local ok,ret = pcall(provider.fn,player)
		if ok and ret then
			local counts,color,exclusive = normalize_provider_result(ret,provider.color or item.default_color)
			for id,count in pairs(counts or {}) do
				local cid = tonumber(id)
				local n = tonumber(count) or 0
				if cid and cid > 0 and n > 0 then
					provider_ids[cid] = true
				end
			end
			append_counts(
				entries,
				counts,
				color,
				(provider.exclusive or exclusive) and exclusive_counts or nil,
				{
					color_fn = provider.color_fn,
					scale_fn = provider.scale_fn,
					source_icon = provider.source_icon,
					source_card = provider.source_card,
					glaze = provider.glaze,
					shader = provider.shader,
					ghost = provider.ghost,
					ghost_fn = provider.ghost_fn,
					ghost_alpha = provider.ghost_alpha,
				}
			)
		end
	end

	-- callback 显式 display=true：无 provider 覆盖时用默认配色追加
	local recorder = collect_from_imitate_recorder(player)
	local meta_bag = collect_from_imitate_meta(player)
	local display_counts = {}
	for id,count in pairs(recorder) do
		local cid = tonumber(id)
		local n = tonumber(count) or 0
		if cid and cid > 0 and n > 0 then
			local m = meta_bag[cid] or meta_bag[id] or meta_bag[tostring(cid)]
			if m and m.display == true and not provider_ids[cid] and not exclusive_counts[cid] then
				display_counts[cid] = n
			end
		end
	end
	append_counts(entries,display_counts,item.default_color,nil,{})

	local list = {}
	for _,entry in ipairs(entries) do
		local cfg = Isaac.GetItemConfig():GetCollectible(entry.id)
		if cfg and (include_actives or cfg.Type ~= ItemType.ITEM_ACTIVE) then
			list[#list + 1] = entry
		end
	end
	table.sort(list,function(a,b)
		if a.id ~= b.id then return a.id < b.id end
		return false
	end)
	return list
end

-- 展开为 id 列表（按数量重复），并刷新 EID 元数据
function item.collect_temp_id_list(player,opts)
	local ids = {}
	item._eid_entry_meta = {}
	item._eid_tint_resolvers = {}
	for _,entry in ipairs(item.collect_temp_entries(player,opts)) do
		local source_icon = entry.source_icon
		if (not source_icon or source_icon == "") and entry.source_card then
			source_icon = item.make_card_source_icon(entry.source_card)
		end
		item._eid_entry_meta[entry.id] = {
			source_icon = source_icon,
			resolver = function()
				local col = resolve_entry_color(entry)
				-- EID 行内图标走默认 coloroffset：清掉自定义 shader 控制通道（Colorize / Offset）
				if entry.shader and col then
					return Color(col.R,col.G,col.B,col.A)
				end
				return col
			end,
		}
		item._eid_tint_resolvers[entry.id] = item._eid_entry_meta[entry.id].resolver
		for _ = 1,entry.count do
			ids[#ids + 1] = entry.id
		end
	end
	return ids
end

-- 兼容旧调用
function item.collect_temp_collectibles(player)
	local merged = {}
	for _,entry in ipairs(item.collect_temp_entries(player)) do
		merged[entry.id] = (merged[entry.id] or 0) + entry.count
	end
	local list = {}
	for id,count in pairs(merged) do
		list[#list + 1] = {id = id,count = count}
	end
	table.sort(list,function(a,b) return a.id < b.id end)
	return list
end

local function get_item_sprite(collectible)
	local cached = item.sprite_cache[collectible]
	if cached then return cached end
	local sprite = Sprite()
	sprite:Load("gfx/005.100_collectible.anm2",false)
	if EntityPickup.SetupCollectibleGraphics then
		EntityPickup.SetupCollectibleGraphics(sprite,1,collectible,false,1,true)
	else
		local cfg = Isaac.GetItemConfig():GetCollectible(collectible)
		if cfg and cfg.GfxFileName then
			sprite:ReplaceSpritesheet(1,cfg.GfxFileName)
			sprite:LoadGraphics()
		end
	end
	sprite:Play(sprite:GetDefaultAnimation(),true)
	item.sprite_cache[collectible] = sprite
	return sprite
end

local function offset_for_slot(slot_index,origin,columns,step)
	local col = (slot_index - 1) % columns
	local row = math.floor((slot_index - 1) / columns)
	return Vector(origin.X + step * col,origin.Y + step * row)
end

local function read_history_offsets(historyHUD,player_index)
	local offsets = {}
	if historyHUD.GetItems then
		local ok,items = pcall(function() return historyHUD:GetItems(player_index,false) end)
		if ok and type(items) == "table" then
			for _,hud_item in ipairs(items) do
				if hud_item.GetRenderoffset and not (hud_item.IsTrinket and hud_item:IsTrinket()) then
					offsets[#offsets + 1] = hud_item:GetRenderoffset()
				end
			end
		end
	end
	if #offsets == 0 and historyHUD.GetCollectibleOffsets then
		local ok,ret = pcall(function()
			return historyHUD:GetCollectibleOffsets(player_index)
		end)
		if ok and type(ret) == "table" then
			for _,off in ipairs(ret) do offsets[#offsets + 1] = off end
		end
	end
	return offsets
end

local function offsets_top_left(offsets)
	local ox,oy = offsets[1].X,offsets[1].Y
	for i = 2,#offsets do
		local o = offsets[i]
		if o.X < ox then ox = o.X end
		if o.Y < oy then oy = o.Y end
	end
	return Vector(ox,oy)
end

local function grid_from_history(historyHUD,player_index,layout)
	local columns,step = layout.columns,layout.step
	local offsets = read_history_offsets(historyHUD,player_index)
	local filled = #offsets
	local origin = (#offsets > 0) and offsets_top_left(offsets) or Vector(0,0)

	if #offsets >= 2 then
		local best_dx
		for i = 1,#offsets do
			for j = i + 1,#offsets do
				local dx = math.abs(offsets[i].X - offsets[j].X)
				local dy = math.abs(offsets[i].Y - offsets[j].Y)
				if dx > 1 and dy < 1 and (not best_dx or dx < best_dx) then best_dx = dx end
			end
		end
		if best_dx and best_dx > 1 then step = best_dx end
	end
	return origin,filled,columns,layout.scale,step,layout.pad
end

local function resolve_entry_ghost_offset(entry)
	if entry.ghost_fn then
		local ok,off = pcall(entry.ghost_fn,entry and entry.id)
		if ok and off then return off end
	end
	if entry.ghost then return Vector(2,-1) end
	return nil
end

local function render_temp_list(historyHUD,renderPos,player_index)
	local player = historyHUD:GetPlayer(player_index)
	if not player then return end
	local temps = item.collect_temp_entries(player)
	if #temps == 0 then return end

	local layout = layout_settings()
	local origin,filled,columns,scale,step,pad = grid_from_history(historyHUD,player_index,layout)
	local drawn = 0
	for _,entry in ipairs(temps) do
		for _ = 1,entry.count do
			drawn = drawn + 1
			local off = offset_for_slot(filled + drawn,origin,columns,step) + pad
			local pos = renderPos + off
			local sprite = get_item_sprite(entry.id)
			local mul = resolve_entry_scale_mul(entry)
			sprite.Scale = Vector(scale * (mul.X or 1),scale * (mul.Y or 1))
			local ghost_off = resolve_entry_ghost_offset(entry)
			if ghost_off then
				local ghost_a = tonumber(entry.ghost_alpha) or 0.2
				local main = resolve_entry_color(entry)
				sprite.Color = Color(main.R,main.G,main.B,ghost_a,0,0,0)
				item.clear_sprite_shader(sprite)
				sprite:Render(pos + ghost_off,Vector.Zero,Vector.Zero)
			end
			sprite.Color = resolve_entry_color(entry)
			if entry.shader then
				item.apply_sprite_shader(sprite,entry.shader)
			else
				item.clear_sprite_shader(sprite)
			end
			sprite:Render(pos,Vector.Zero,Vector.Zero)
		end
	end
end

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_HISTORYHUD_RENDER, params = nil,
Function = function(_,historyHUD,renderPos)
	if not option_enabled() or not hud_style_ready() then return end
	renderPos = renderPos or historyHUD:GetPosition()
	render_temp_list(historyHUD,renderPos,0)
	local twin = historyHUD:GetPlayer(1)
	local p0 = historyHUD:GetPlayer(0)
	if twin and p0 and GetPtrHash(twin) ~= GetPtrHash(p0) then
		render_temp_list(historyHUD,renderPos,1)
	end
end,
})

local function eid_lang_is_zh()
	-- 与模组其它 EID 一致：走 Config + LanguageMap，避免 UserConfig/英文误判
	local lang = "en_us"
	if auxi.get_EID_language then
		lang = auxi.get_EID_language()
	elseif EID and EID.getLanguage then
		local ok,got = pcall(function() return EID:getLanguage() end)
		if ok and got then lang = got end
	end
	lang = string.lower(tostring(lang or "en"))
	return lang == "zh" or lang == "zh_cn" or string.sub(lang,1,2) == "zh"
end

local function count_in_map(counts,collectible_id)
	if type(counts) ~= "table" then return 0 end
	local n = tonumber(counts[collectible_id]) or tonumber(counts[tostring(collectible_id)]) or 0
	return n
end

-- EID/判定用：含主动，不只依赖 Extra HUD 过滤后的列表
function item.has_temp_collectible(collectible_id)
	collectible_id = tonumber(collectible_id)
	if not collectible_id or collectible_id <= 0 then return false end
	if not Game then return false end
	-- 仅统计可展示 provider，不含马刀/二元性等机制用模拟
	for i = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player then
			for _,provider in ipairs(item.providers) do
				local ok,ret = pcall(provider.fn,player)
				if ok and ret then
					local counts = normalize_provider_result(ret,provider.color or item.default_color)
					if count_in_map(counts,collectible_id) > 0 then return true end
				end
			end
		end
	end
	return false
end

function item.is_temp_marked_entity(entity)
	if not entity then return false end
	for _,checker in ipairs(item.entity_checkers) do
		local ok,ret = pcall(checker,entity)
		if ok and ret then return true end
	end
	return false
end

local function eid_apply_sprite_color(sprite,base)
	if not sprite then return end
	local t = auxi.color2table(base or item.default_color)
	local tr = 1
	if EID and EID.Config and EID.Config["Transparency"] then
		tr = EID.Config["Transparency"]
	end
	t.A = (t.A or 1) * tr
	sprite.Color = auxi.table2color(t)
end

local function ensure_eid_tint_icon(collectible_id)
	if not EID or not EID.InlineIcons then return end
	local key = "QingTempTint"..tostring(collectible_id)
	if EID.InlineIcons[key] then return key end
	EID.InlineIcons[key] = function(_)
		EID._NextIconModifier = function(sprite)
			local meta = item._eid_entry_meta[collectible_id]
			local col = item.default_color
			if meta and meta.resolver then
				local ok,got = pcall(meta.resolver)
				if ok and got then col = got end
			end
			eid_apply_sprite_color(sprite,col)
		end
		return {"Blank",0,0,0}
	end
	return key
end

-- 滚动条用：可带染色前缀。说明行首只用单 Collectible，避免 Blank 子弹默认 ·
local function eid_temp_scroll_icon_markup(collectible_id)
	local tint = ensure_eid_tint_icon(collectible_id)
	if tint then
		return "{{"..tint.."}}{{Collectible"..collectible_id.."}}"
	end
	return "{{Collectible"..collectible_id.."}}"
end

local function inject_eid_category_names()
	if not EID or not EID.descriptions then return end
	local zh = eid_lang_is_zh()
	local title_zh,title_en = "临时道具","Temporary Items"
	local en_names = EID.getDescriptionEntryEnglish and EID:getDescriptionEntryEnglish("ItemReminder","CategoryNames")
	if type(en_names) == "table" then
		en_names[item.eid_category_id] = title_en
	end
	-- 当前语言包必须自带键，否则 getDescriptionEntry 会整表回落到英文
	local lang = nil
	if EID.getLanguage then
		local ok,got = pcall(function() return EID:getLanguage() end)
		if ok then lang = got end
	end
	lang = lang or (auxi.get_EID_language and auxi.get_EID_language()) or "en_us"
	local pack = EID.descriptions[lang]
	if type(pack) ~= "table" and zh then
		pack = EID.descriptions["zh_cn"] or EID.descriptions["zh"]
	end
	if type(pack) == "table" then
		pack.ItemReminder = pack.ItemReminder or {}
		if type(pack.ItemReminder.CategoryNames) ~= "table" then
			-- 从英文拷一份再改，避免缺表时回落
			local copy = {}
			if type(en_names) == "table" then
				for k,v in pairs(en_names) do copy[k] = v end
			end
			pack.ItemReminder.CategoryNames = copy
		end
		pack.ItemReminder.CategoryNames[item.eid_category_id] = zh and title_zh or title_en
	end
	for code,p in pairs(EID.descriptions) do
		if type(p) == "table" and type(code) == "string" then
			local is_zh = code == "zh_cn" or string.sub(code,1,2) == "zh"
			if p.ItemReminder and type(p.ItemReminder.CategoryNames) == "table" then
				p.ItemReminder.CategoryNames[item.eid_category_id] = is_zh and title_zh or title_en
			end
		end
	end
end

local function format_source_suffix(source_icon)
	if not source_icon or source_icon == "" then return "" end
	if eid_lang_is_zh() then
		return " {{ColorGray}}由"..source_icon.."提供{{CR}}"
	end
	return " {{ColorGray}}Provided by "..source_icon.."{{CR}}"
end

local function build_temp_scrollbar(ids)
	if not EID or not ids or #ids <= (EID.Config["ItemReminderMaxEntriesCount"] or 3) then
		return nil
	end
	local selected = EID.ItemReminderSelectedItems[EID.ItemReminderSelectedCategory] or 0
	selected = selected % #ids
	local max_show = (EID.Config["ItemReminderMaxEntriesCount"] or 3) + 1
	local desc = "{{Blank}} {{NoLB}}"..(EID.ButtonToIconMap[EID.Config["ItemReminderNavigateUpButton"]] or "")
	local startIndex = #ids - selected
	local stopIndex = startIndex - max_show
	for i = startIndex,stopIndex,-1 do
		local index = ((i - 1) % #ids) + 1
		local id = ids[index]
		if i < 1 and index == startIndex then break end
		desc = desc..eid_temp_scroll_icon_markup(id).." "
	end
	desc = desc.."("..(selected + 1).."/"..#ids..")"
	return desc..(EID.ButtonToIconMap[EID.Config["ItemReminderNavigateDownButton"]] or "").."#"
end

local function unique_temp_ids(ids)
	local out,seen = {},{}
	for _,id in ipairs(ids or {}) do
		if not seen[id] then
			seen[id] = true
			out[#out + 1] = id
		end
	end
	return out
end

local function print_temp_descriptions(player,ids)
	if not EID or not ids or #ids == 0 then return end
	inject_eid_category_names()
	local unique = unique_temp_ids(ids)
	local selected = EID.ItemReminderSelectedItems[EID.ItemReminderSelectedCategory] or 0
	local focus = ids[((#ids - (selected % #ids) - 1) % #ids) + 1]
	local startIndex = 0
	for i,id in ipairs(unique) do
		if id == focus then startIndex = i - 1 break end
	end
	local shown = 0
	while shown < #unique and EID:ItemReminderCanAddMoreToView() do
		local id = unique[(startIndex % #unique) + 1]
		local descObj = EID:getDescriptionObj(5,100,id)
		local name = descObj and descObj.Name or tostring(id)
		local meta = item._eid_entry_meta[id]
		if meta then
			name = name..format_source_suffix(meta.source_icon)
		end
		local description = descObj and descObj.Description or ""
		-- 行首只用单个 Collectible，作为 bullet icon（与被动页一致，无额外 ·）
		EID:ItemReminderAddTempDescriptionEntry("{{Collectible"..id.."}}",name,description,"5.100."..id)
		startIndex = startIndex + 1
		shown = shown + 1
	end
end

local function register_eid_item_reminder()
	if not EID or not EID.ItemReminderCategories then return end
	inject_eid_category_names()
	if item._eid_category_registered then return end
	for _,category in ipairs(EID.ItemReminderCategories) do
		if category.id == item.eid_category_id then
			item._eid_category_registered = true
			return
		end
	end
	table.insert(EID.ItemReminderCategories,{
		id = item.eid_category_id,
		isScrollable = true,
		hideInOverview = function(player)
			local ids = item.collect_temp_id_list(player,{include_actives = true})
			return #ids == 0
		end,
		entryGenerators = {
			function(player)
				local ids = item.collect_temp_id_list(player,{include_actives = true})
				print_temp_descriptions(player,ids)
			end,
		},
		scrollbarGenerator = function(player)
			inject_eid_category_names()
			local ids = item.collect_temp_id_list(player,{include_actives = true})
			return build_temp_scrollbar(ids)
		end,
	})
	if EID.ResetItemReminderSelectedItems then
		EID:ResetItemReminderSelectedItems()
	end
	item._eid_category_registered = true
end

local function register_eid_modifier()
	if not EID or not EID.addDescriptionModifier then return end
	if not item._eid_registered then
		item._eid_registered = true
		EID:addDescriptionModifier("qing_temp_item_marker", function(desc)
			-- 仅标注神历三选一底座实体，不按「是否持有临时道具」扫全图道具
			if EID.InsideItemReminder then return false end
			if not desc or desc.ObjType ~= 5 or desc.ObjVariant ~= 100 then return false end
			return desc.Entity ~= nil and item.is_temp_marked_entity(desc.Entity)
		end, function(desc)
			local marker = enums.Items.Tzolkin or 0
			local line = eid_lang_is_zh()
				and ("#{{Collectible"..marker.."}} {{ColorRed}}临时道具{{CR}}")
				or ("#{{Collectible"..marker.."}} {{ColorRed}}Temporary item{{CR}}")
			EID:appendToDescription(desc, line)
			return desc
		end)
	end
	register_eid_item_reminder()
end

register_eid_modifier()

table.insert(item.myToCall,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_)
	item.sprite_cache = {}
	item._eid_registered = false
	item._eid_category_registered = false
	register_eid_modifier()
end,
})

return item

local item_color_data = require("Qing_Remaster_scripts.others.item_color_data")
local save = require("Qing_Remaster_scripts.core.savedata")

local holder = {
	ToCall = {},
	batch_size = 1,
	static_pools = {},
	static_tags = {},
	analyzed_tags = {},
	analyzed_weights = {},
	counted_ids = {},
	effective_pools = {},
	effective_tags = {},
	queue = {},
	queue_index = 1,
	stats = {},
	cache_sig = nil,
	cache_dirty = false,
	CACHE_VERSION = 1,
}

local LABEL_ORDER = item_color_data.labels
local LABEL_BIT = {}
local BIT_LABEL = {}
for i,label in ipairs(LABEL_ORDER) do
	local bit = 1 << (i - 1)
	LABEL_BIT[label] = bit
	BIT_LABEL[bit] = label
end
local CHROMATIC_LABELS = {
	red = true,orange = true,yellow = true,green = true,blue = true,
	purple = true,pink = true,brown = true,
}

local function copy_array(source)
	local result = {}
	for i = 1,#(source or {}) do result[i] = source[i] end
	return result
end

local function contains(list, value)
	for i = 1,#(list or {}) do
		if list[i] == value then return true end
	end
	return false
end

local function add_unique(list, value)
	if not contains(list, value) then list[#list + 1] = value end
end

local function valid_collectible(id)
	local collectible = Isaac.GetItemConfig():GetCollectible(id)
	return collectible and not collectible.Hidden and
		not collectible:HasTags(ItemConfig.TAG_QUEST or (1 << 15))
end

local function reset_stats(state)
	holder.stats = {
		state = state or (REPENTOGON and "waiting" or "unavailable"),
		processed = 0,
		total = 0,
		succeeded = 0,
		failed = 0,
		compared = 0,
		overlap = 0,
		exact = 0,
		conflict = 0,
		cached = 0,
		last_id = 0,
		last_name = "",
		failures = {},
		category_counts = {},
	}
end

reset_stats()

local function hash_mix(h, value)
	h = (h ~ (value % 4294967296)) * 16777619
	return h % 4294967296
end

local function hash_string(h, text)
	text = text or ""
	for i = 1,#text do
		h = hash_mix(h, string.byte(text,i))
	end
	return h
end

local function tags_to_mask(tags)
	local mask = 0
	for _,label in ipairs(tags or {}) do
		local bit = LABEL_BIT[label]
		if bit then mask = mask | bit end
	end
	return mask
end

local function mask_to_tags(mask)
	local tags = {}
	if type(mask) ~= "number" then return tags end
	mask = math.floor(mask)
	for _,label in ipairs(LABEL_ORDER) do
		local bit = LABEL_BIT[label]
		if (mask & bit) ~= 0 then tags[#tags + 1] = label end
	end
	return tags
end

function holder.compute_fingerprint()
	local config = Isaac.GetItemConfig()
	local size = config:GetCollectibles().Size
	local first_mod_id = CollectibleType.NUM_COLLECTIBLES or 733
	local count = 0
	local h = 2166136261
	for id = first_mod_id,size do
		if valid_collectible(id) and not holder.static_tags[id] then
			count = count + 1
			local collectible = config:GetCollectible(id)
			h = hash_mix(h, id)
			h = hash_string(h, collectible and collectible.GfxFileName or "")
		end
	end
	return string.format("%d:%d:%u", size, count, h)
end

local function hydrate_tags(id, tags)
	if type(id) ~= "number" or type(tags) ~= "table" or #tags == 0 then return end
	holder.analyzed_tags[id] = copy_array(tags)
	local effective = holder.static_tags[id] or tags
	holder.effective_tags[id] = copy_array(effective)
	for _,label in ipairs(effective) do
		holder.effective_pools[label] = holder.effective_pools[label] or {}
		add_unique(holder.effective_pools[label], id)
	end
	if not holder.counted_ids[id] then
		holder.counted_ids[id] = true
		for _,label in ipairs(effective) do
			holder.stats.category_counts[label] = (holder.stats.category_counts[label] or 0) + 1
		end
	end
end

local function recount_from_analyzed()
	holder.counted_ids = {}
	holder.stats.category_counts = {}
	holder.stats.cached = 0
	for id,tags in pairs(holder.analyzed_tags) do
		holder.stats.cached = holder.stats.cached + 1
		local effective = holder.static_tags[id] or tags
		holder.counted_ids[id] = true
		for _,label in ipairs(effective) do
			holder.stats.category_counts[label] = (holder.stats.category_counts[label] or 0) + 1
		end
	end
end

function holder.export_cache()
	local packed = {}
	local n = 0
	for id,tags in pairs(holder.analyzed_tags) do
		local mask = tags_to_mask(tags)
		if mask > 0 then
			packed[tostring(id)] = mask
			n = n + 1
		end
	end
	return {
		v = holder.CACHE_VERSION,
		sig = holder.cache_sig or holder.compute_fingerprint(),
		n = n,
		t = packed,
	}
end

function holder.import_cache(blob)
	if type(blob) ~= "table" or blob.v ~= holder.CACHE_VERSION or type(blob.t) ~= "table" then
		return false
	end
	local sig = holder.compute_fingerprint()
	if blob.sig ~= sig then return false end
	holder.cache_sig = sig
	local cached = 0
	for id_str,mask in pairs(blob.t) do
		local id = tonumber(id_str)
		local tags = mask_to_tags(mask)
		if id and #tags > 0 and not holder.static_tags[id] then
			hydrate_tags(id, tags)
			cached = cached + 1
		end
	end
	holder.stats.cached = cached
	return true
end

function holder.try_load_disk_cache()
	if save.ItemColorCache and save.ItemColorCache.v then
		return holder.import_cache(save.ItemColorCache)
	end
	local blob = save.PeekItemColorCache and save.PeekItemColorCache()
	if blob then return holder.import_cache(blob) end
	return false
end

function holder.persist_cache()
	holder.cache_sig = holder.compute_fingerprint()
	local blob = holder.export_cache()
	save.ItemColorCache = blob
	holder.cache_dirty = false
	if save.SaveItemColorCache then
		save.SaveItemColorCache(blob)
	elseif save.SaveModData then
		save.SaveModData()
	end
end

local function rebuild_effective_pools()
	holder.effective_pools = {}
	holder.effective_tags = {}

	for _,label in ipairs(LABEL_ORDER) do
		holder.effective_pools[label] = {}
	end
	for label,ids in pairs(holder.static_pools) do
		holder.effective_pools[label] = holder.effective_pools[label] or {}
		for _,id in ipairs(ids) do
			add_unique(holder.effective_pools[label], id)
		end
	end

	for id,tags in pairs(holder.static_tags) do
		holder.effective_tags[id] = copy_array(tags)
	end
	for id,tags in pairs(holder.analyzed_tags) do
		local effective = holder.static_tags[id] or tags
		holder.effective_tags[id] = copy_array(effective)
		for _,label in ipairs(effective) do
			holder.effective_pools[label] = holder.effective_pools[label] or {}
			add_unique(holder.effective_pools[label], id)
		end
	end
end

function holder.configure_static_pools(source)
	holder.static_pools = {}
	holder.static_tags = {}
	for label,ids in pairs(source or {}) do
		holder.static_pools[label] = {}
		for _,id in pairs(ids) do
			if type(id) == "number" and id > 0 and valid_collectible(id) then
				add_unique(holder.static_pools[label], id)
				holder.static_tags[id] = holder.static_tags[id] or {}
				add_unique(holder.static_tags[id], label)
			end
		end
	end
	rebuild_effective_pools()
end

holder.configure_static_pools(item_color_data.pools)

local function hue_bucket(red, green, blue, value, saturation)
	local minimum = math.min(red,green,blue)
	local delta = value - minimum
	if delta <= 0 then return "grey" end

	local hue
	if value == red then
		hue = 60 * (((green - blue) / delta) % 6)
	elseif value == green then
		hue = 60 * (((blue - red) / delta) + 2)
	else
		hue = 60 * (((red - green) / delta) + 4)
	end
	if hue < 0 then hue = hue + 360 end

	if hue >= 5 and hue < 42 and saturation >= 0.16 and saturation <= 0.62 and value >= 0.42 then
		return "pink"
	elseif value < 0.48 and saturation > 0.25 and (hue < 70 or hue >= 345) then
		return "brown"
	elseif hue < 15 or hue >= 350 then
		return "red"
	elseif hue < 45 then
		return "orange"
	elseif hue < 70 then
		return "yellow"
	elseif hue < 165 then
		return "green"
	elseif hue < 255 then
		return "blue"
	elseif hue < 340 then
		return "purple"
	end
	return "pink"
end

local function classify_texels(raw, width, height)
	-- REPENTOGON's documentation currently claims four 32-bit floats per pixel,
	-- but the runtime implementation returns packed RGBA8 (four bytes). Keep this
	-- byte decoding unless the engine behavior itself changes; see the project note.
	local bytes_per_pixel = 4
	local expected_size = width * height * bytes_per_pixel
	if type(raw) ~= "string" or #raw < expected_size then
		return nil,"incomplete texel data: "..tostring(type(raw) == "string" and #raw or 0)..
			"/"..tostring(expected_size)
	end

	local weights = {}
	local total_weight = 0
	local chromatic_weight = 0
	local visible_alpha = 0
	local black_alpha = 0
	local sampled_labels = {}
	local sample_step = math.max(1,math.ceil(math.sqrt((width * height) / 1024)))

	for y = 0,height - 1,sample_step do
		for x = 0,width - 1,sample_step do
			local byte_index = (y * width + x) * bytes_per_pixel + 1
			local red,green,blue,alpha = string.byte(raw,byte_index,byte_index + 3)
			if alpha and alpha > 12.75 then
				red = red / 255
				green = green / 255
				blue = blue / 255
				alpha = alpha / 255
				local value = math.max(red,green,blue)
				local minimum = math.min(red,green,blue)
				local saturation = value > 0 and (value - minimum) / value or 0
				local label
				local weight
				visible_alpha = visible_alpha + alpha

				if value < 0.075 then
					label = "black"
					weight = alpha * 0.08
					black_alpha = black_alpha + alpha
				elseif saturation < 0.20 then
					if value > 0.84 then label = "white"
					else label = "grey" end
					weight = alpha * 0.55
				else
					label = hue_bucket(red,green,blue,value,saturation)
					weight = alpha * (0.5 + saturation * 0.5)
					chromatic_weight = chromatic_weight + weight
				end

				weights[label] = (weights[label] or 0) + weight
				total_weight = total_weight + weight
				if CHROMATIC_LABELS[label] then
					sampled_labels[y * width + x] = label
				end
			end
		end
	end

	if total_weight <= 0 then return {"others"} end
	if visible_alpha > 0 and black_alpha / visible_alpha > 0.82 then
		local old_black_weight = weights.black or 0
		local new_black_weight = black_alpha * 0.65
		weights.black = new_black_weight
		total_weight = total_weight + new_black_weight - old_black_weight
	end
	local red_white = (weights.red or 0) + (weights.white or 0)
	if (weights.red or 0) >= total_weight * 0.18 and
		(weights.white or 0) >= total_weight * 0.10 and
		red_white >= total_weight * 0.50 then
		weights.pink = math.max(weights.pink or 0,red_white * 0.78)
		weights.red = (weights.red or 0) * 0.28
		weights.white = (weights.white or 0) * 0.28
	end

	local significant_count = 0
	local dominant_chromatic = 0
	for label in pairs(CHROMATIC_LABELS) do
		local weight = weights[label] or 0
		if weight >= chromatic_weight * 0.10 and weight >= total_weight * 0.045 then
			significant_count = significant_count + 1
		end
		dominant_chromatic = math.max(dominant_chromatic,weight)
	end
	local transitions = 0
	local comparisons = 0
	for y = 0,height - 1,sample_step do
		for x = 0,width - 1,sample_step do
			local label = sampled_labels[y * width + x]
			if label then
				local left = x >= sample_step and sampled_labels[y * width + x - sample_step] or nil
				local above = y >= sample_step and sampled_labels[(y - sample_step) * width + x] or nil
				if left then
					comparisons = comparisons + 1
					if left ~= label then transitions = transitions + 1 end
				end
				if above then
					comparisons = comparisons + 1
					if above ~= label then transitions = transitions + 1 end
				end
			end
		end
	end
	local fragmentation = comparisons > 0 and transitions / comparisons or 0
	if chromatic_weight >= total_weight * 0.35 and significant_count >= 3 and
		(significant_count >= 4 or fragmentation >= 0.28) and
		dominant_chromatic <= chromatic_weight * 0.62 then
		weights.others = math.max(weights.others or 0,chromatic_weight * 0.70)
	end

	local ranked = {}
	for label,weight in pairs(weights) do
		ranked[#ranked + 1] = {label = label,weight = weight}
	end
	table.sort(ranked,function(a,b) return a.weight > b.weight end)

	local result = {}
	local strongest = ranked[1] and ranked[1].weight or 0
	for _,entry in ipairs(ranked) do
		if #result >= 3 then break end
		if entry == ranked[1] or
			(entry.weight >= total_weight * 0.13 and entry.weight >= strongest * 0.42) then
			result[#result + 1] = entry.label
		end
	end
	if #result == 0 then result[1] = "others" end
	local normalized_weights = {}
	if total_weight > 0 then
		for label,weight in pairs(weights) do normalized_weights[label] = weight / total_weight end
	end
	return result,nil,normalized_weights
end

function holder.analyze_collectible(id)
	if not REPENTOGON or not Renderer then
		return nil,"REPENTOGON image API unavailable"
	end
	local collectible = Isaac.GetItemConfig():GetCollectible(id)
	if not collectible then return nil,"missing ItemConfig entry" end
	if collectible.GfxFileName == nil or collectible.GfxFileName == "" then
		return nil,"missing GfxFileName"
	end

	local ok,result,reason,weights = pcall(function()
		local sprite = Sprite()
		sprite:Load("gfx/effects/nil_effect.anm2",false)
		sprite:ReplaceSpritesheet(0,collectible.GfxFileName)
		sprite:LoadGraphics()
		local image = sprite:GetSpritesheet(0)
		if not image then return nil,"spritesheet unavailable" end
		local width = math.floor(image:GetWidth())
		local height = math.floor(image:GetHeight())
		if width <= 0 or height <= 0 then return nil,"empty spritesheet" end
		if width > 512 or height > 512 then return nil,"spritesheet is unexpectedly large" end
		local raw = image:GetTexelRegion(0,0,width,height)
		return classify_texels(raw,width,height)
	end)
	if not ok then return nil,tostring(result) end
	return result,reason,weights
end

local function compare_tags(analyzed,manual)
	if not analyzed or not manual then return false,false end
	local overlap = false
	for _,tag in ipairs(analyzed) do
		if contains(manual,tag) then overlap = true break end
	end
	if #analyzed ~= #manual then return overlap,false end
	for _,tag in ipairs(analyzed) do
		if not contains(manual,tag) then return overlap,false end
	end
	return overlap,true
end

local function register_analysis(id,tags)
	holder.analyzed_tags[id] = copy_array(tags)
	if holder.counted_ids[id] then return end
	holder.counted_ids[id] = true
	for _,label in ipairs(tags) do
		holder.stats.category_counts[label] = (holder.stats.category_counts[label] or 0) + 1
	end
	local manual = holder.static_tags[id]
	if manual then
		holder.stats.compared = holder.stats.compared + 1
		local overlap,exact = compare_tags(tags,manual)
		if overlap then holder.stats.overlap = holder.stats.overlap + 1
		else holder.stats.conflict = holder.stats.conflict + 1 end
		if exact then holder.stats.exact = holder.stats.exact + 1 end
	end
	local effective = holder.static_tags[id] or tags
	holder.effective_tags[id] = copy_array(effective)
	for _,label in ipairs(effective) do
		holder.effective_pools[label] = holder.effective_pools[label] or {}
		add_unique(holder.effective_pools[label],id)
	end
end

-- force=true：忽略磁盘缓存，全量重扫并覆盖 ITEM_COLOR_CACHE
function holder.start_scan(force)
	reset_stats(REPENTOGON and "scanning" or "unavailable")
	holder.queue = {}
	holder.queue_index = 1
	holder.analyzed_weights = {}

	local sig = holder.compute_fingerprint()
	if force then
		holder.analyzed_tags = {}
		holder.counted_ids = {}
		holder.cache_sig = nil
		holder.cache_dirty = false
		save.ItemColorCache = nil
		rebuild_effective_pools()
	else
		-- 指纹变了：丢弃内存缓存，再尝试磁盘（磁盘签名不匹配时 import 会失败）
		if holder.cache_sig and holder.cache_sig ~= sig then
			holder.analyzed_tags = {}
			holder.counted_ids = {}
		end
		rebuild_effective_pools()
		if next(holder.analyzed_tags) then
			recount_from_analyzed()
		else
			holder.try_load_disk_cache()
		end
	end

	if not REPENTOGON or not Renderer then
		holder.stats.state = "unavailable"
		return
	end

	holder.cache_sig = sig
	local config = Isaac.GetItemConfig()
	local size = config:GetCollectibles().Size
	local first_mod_id = CollectibleType.NUM_COLLECTIBLES or 733
	for id = first_mod_id,size do
		if valid_collectible(id) and not holder.static_tags[id] and not holder.analyzed_tags[id] then
			holder.queue[#holder.queue + 1] = id
		end
	end
	holder.stats.total = #holder.queue
	if holder.stats.total == 0 then
		holder.stats.state = "complete"
		-- 全命中缓存时不必重写盘；仅 force 或本轮有新结果时 persist
		if force or holder.cache_dirty then holder.persist_cache() end
	else
		holder.cache_dirty = true
	end
end

function holder.process_scan_batch()
	if holder.stats.state ~= "scanning" then return end
	for _ = 1,holder.batch_size do
		local id = holder.queue[holder.queue_index]
		if not id then
			holder.stats.state = "complete"
			if holder.cache_dirty then holder.persist_cache() end
			return
		end
		holder.queue_index = holder.queue_index + 1
		holder.stats.processed = holder.stats.processed + 1
		holder.stats.last_id = id
		local collectible = Isaac.GetItemConfig():GetCollectible(id)
		holder.stats.last_name = collectible and collectible.Name or ""
		local tags = holder.analyzed_tags[id]
		local reason
		local weights
		if not tags then tags,reason,weights = holder.analyze_collectible(id) end
		if tags then
			holder.analyzed_weights[id] = weights or holder.analyzed_weights[id]
			holder.stats.succeeded = holder.stats.succeeded + 1
			register_analysis(id,tags)
			holder.cache_dirty = true
		else
			holder.stats.failed = holder.stats.failed + 1
			if #holder.stats.failures < 20 then
				holder.stats.failures[#holder.stats.failures + 1] = {
					id = id,
					name = holder.stats.last_name,
					reason = reason or "unknown error",
				}
			end
		end
	end
end

function holder.analyze_now(id)
	if holder.analyzed_tags[id] then return holder.analyzed_tags[id] end
	local tags,_,weights = holder.analyze_collectible(id)
	if tags then
		holder.analyzed_weights[id] = weights
		register_analysis(id,tags)
	end
	return tags
end

function holder.get_analyzed_weights(id,analyze_unknown)
	if holder.analyzed_weights[id] then return holder.analyzed_weights[id] end
	if analyze_unknown and REPENTOGON then
		holder.analyze_now(id)
		return holder.analyzed_weights[id]
	end
	return nil
end

function holder.get_label_weights(id,analyze_unknown)
	local static = holder.static_tags[id]
	if static then
		local result = {}
		for _,label in ipairs(static) do result[label] = 1 end
		return result
	end
	local analyzed = holder.get_analyzed_weights(id,analyze_unknown)
	if analyzed then return analyzed end
	local tags = holder.get_tags(id,analyze_unknown)
	if not tags then return nil end
	local result = {}
	for _,label in ipairs(tags) do result[label] = 1 end
	return result
end

function holder.get_tags(id,analyze_unknown)
	if holder.static_tags[id] then return holder.static_tags[id] end
	if holder.analyzed_tags[id] then return holder.analyzed_tags[id] end
	if analyze_unknown and REPENTOGON then return holder.analyze_now(id) end
	return nil
end

function holder.get_pool(label)
	return holder.effective_pools[label] or {}
end

function holder.choose_replacement(id,rng)
	local tags = holder.get_tags(id,true)
	if not tags or #tags == 0 then return nil end
	local start = rng and rng:RandomInt(#tags) + 1 or math.random(#tags)
	for offset = 0,#tags - 1 do
		local label = tags[(start + offset - 1) % #tags + 1]
		local candidates = {}
		for _,candidate in ipairs(holder.get_pool(label)) do
			if candidate ~= id and valid_collectible(candidate) then
				candidates[#candidates + 1] = candidate
			end
		end
		if #candidates > 0 then
			local index = rng and rng:RandomInt(#candidates) + 1 or math.random(#candidates)
			return candidates[index],label
		end
	end
	return nil
end

function holder.get_stats()
	return holder.stats
end

function holder.get_category_summary()
	local parts = {}
	for _,label in ipairs(LABEL_ORDER) do
		local count = holder.stats.category_counts[label] or 0
		if count > 0 then parts[#parts + 1] = label..":"..tostring(count) end
	end
	return table.concat(parts,"  ")
end

function holder.print_report()
	local stats = holder.stats
	print("QING:: ItemColor state="..tostring(stats.state)..
		" processed="..tostring(stats.processed).."/"..tostring(stats.total)..
		" success="..tostring(stats.succeeded).." failed="..tostring(stats.failed)..
		" cached="..tostring(stats.cached or 0)..
		" compared="..tostring(stats.compared).." overlap="..tostring(stats.overlap)..
		" exact="..tostring(stats.exact).." conflict="..tostring(stats.conflict))
	print("QING:: ItemColor sig="..tostring(holder.cache_sig or holder.compute_fingerprint()))
	print("QING:: ItemColor categories "..holder.get_category_summary())
	for _,failure in ipairs(stats.failures) do
		print("QING:: ItemColor failure id="..tostring(failure.id)..
			" name="..tostring(failure.name).." reason="..tostring(failure.reason))
	end
end

if REPENTOGON and ModCallbacks.MC_POST_MODS_LOADED then
	table.insert(holder.ToCall,#holder.ToCall + 1,{CallBack = ModCallbacks.MC_POST_MODS_LOADED,params = nil,
	Function = function(_)
		holder.start_scan(false)
	end,
	})
end

table.insert(holder.ToCall,#holder.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE,params = nil,
Function = function(_)
	holder.process_scan_batch()
end,
})

return holder

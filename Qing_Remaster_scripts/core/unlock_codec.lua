-- 成就解锁矩阵：运行时仍用嵌套 UnlockData；落盘用 schema 位图压缩。
-- 不依赖把整棵嵌套表 deepCopy 进 SAVE_STATE。

local codec = {
	VERSION = 1,
}

local TEMPLATE_FIELDS = {
	UnlocksTemplate = {"Unlock", "Hard"},
	boss_players = {"Unlock", "Hard", "Tainted", "TaintedHard"},
	others_achievements = {"Unlock"},
}

local function template_fields(template_name, sample)
	local preset = TEMPLATE_FIELDS[template_name]
	if preset then return preset end
	-- 动态 boss 板等：按样本键排序，缺省仅 Unlock
	if type(sample) == "table" then
		local fields = {}
		for field in pairs(sample) do
			fields[#fields + 1] = field
		end
		table.sort(fields)
		if #fields > 0 then return fields end
	end
	return {"Unlock"}
end

local function ordered_codes(template_table)
	local codes = {}
	for code in pairs(template_table or {}) do
		codes[#codes + 1] = code
	end
	table.sort(codes)
	return codes
end

function codec.build_schema(over_unlock_info, Unlock_info)
	local schema = {cats = {}, order = {}}
	for cat, template_name in pairs(over_unlock_info or {}) do
		local template = Unlock_info[template_name] or {}
		local sample = nil
		for _,row in pairs(template) do sample = row break end
		local entry = {
			cat = cat,
			template = template_name,
			codes = ordered_codes(template),
			fields = template_fields(template_name, sample),
		}
		schema.cats[cat] = entry
		schema.order[#schema.order + 1] = cat
	end
	table.sort(schema.order)
	return schema
end

local function pack_bools(bools)
	local chunks = {}
	local cur = 0
	local n = 0
	for i = 1,#bools do
		if bools[i] then
			cur = cur | (1 << n)
		end
		n = n + 1
		if n >= 31 then
			chunks[#chunks + 1] = cur
			cur = 0
			n = 0
		end
	end
	if n > 0 or #chunks == 0 then
		chunks[#chunks + 1] = cur
	end
	return chunks
end

local function unpack_bools(chunks, count)
	local bools = {}
	local idx = 1
	for _,cur in ipairs(chunks or {}) do
		local value = math.floor(tonumber(cur) or 0)
		for bit = 0,30 do
			if idx > count then return bools end
			bools[idx] = (value & (1 << bit)) ~= 0
			idx = idx + 1
		end
	end
	while #bools < count do
		bools[#bools + 1] = false
	end
	return bools
end

function codec.pack(UnlockData, schema)
	schema = schema or codec._schema
	local out = {v = codec.VERSION, b = {}}
	local overflow = nil
	for _,cat in ipairs(schema.order) do
		local entry = schema.cats[cat]
		local src = (UnlockData and UnlockData[cat]) or {}
		local bools = {}
		local known = {}
		for _,code in ipairs(entry.codes) do
			known[code] = true
			local cell = src[code] or {}
			for _,field in ipairs(entry.fields) do
				bools[#bools + 1] = cell[field] == true
			end
		end
		out.b[cat] = pack_bools(bools)
		for code,cell in pairs(src) do
			if not known[code] and type(cell) == "table" then
				overflow = overflow or {}
				overflow[cat] = overflow[cat] or {}
				overflow[cat][code] = {}
				for field,value in pairs(cell) do
					overflow[cat][code][field] = value == true
				end
			end
		end
	end
	if overflow then out.x = overflow end
	return out
end

function codec.unpack(packed, schema)
	schema = schema or codec._schema
	local data = {}
	if type(packed) ~= "table" or type(packed.b) ~= "table" then
		return data
	end
	for _,cat in ipairs(schema.order) do
		local entry = schema.cats[cat]
		local bit_count = #entry.codes * #entry.fields
		local bools = unpack_bools(packed.b[cat], bit_count)
		local cat_data = {}
		local idx = 1
		for _,code in ipairs(entry.codes) do
			local cell = {}
			for _,field in ipairs(entry.fields) do
				cell[field] = bools[idx] == true
				idx = idx + 1
			end
			cat_data[code] = cell
		end
		data[cat] = cat_data
	end
	if type(packed.x) == "table" then
		for cat,codes in pairs(packed.x) do
			data[cat] = data[cat] or {}
			for code,cell in pairs(codes) do
				data[cat][code] = data[cat][code] or {}
				if type(cell) == "table" then
					for field,value in pairs(cell) do
						data[cat][code][field] = value == true
					end
				end
			end
		end
	end
	return data
end

-- 旧存档：顶层 wq / Glaze / BossBoard_* 等嵌套表
function codec.from_legacy_save(SAVE_STATE, over_unlock_info)
	local data = {}
	for cat,_ in pairs(over_unlock_info or {}) do
		if type(SAVE_STATE[cat]) == "table" then
			data[cat] = SAVE_STATE[cat]
		end
	end
	return data
end

function codec.bind_schema(schema)
	codec._schema = schema
end

return codec

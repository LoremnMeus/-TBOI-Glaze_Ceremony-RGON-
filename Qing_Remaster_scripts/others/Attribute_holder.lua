local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {ToCall = {}, own_key = "Attribute_holder_", state_key = "Attribute_holder_V2", descriptors = {},
	debug = {probe_enabled = false, last_report = nil, error_count = 0}}
local remove_probe_observer = nil

function item.set_remove_probe_observer(observer)
	remove_probe_observer = type(observer) == "function" and observer or nil
end
-- 禁止弱键：Isaac 实体 userdata 仅被弱表引用时，任意分配触发的 GC 会清掉 active 条目，
-- 但 GetData 里的 claim / saga token 仍在 → FREEZE/Position 不再每帧回写，NO_SPRITE 却可能残留。
-- 强键必须在重开/实体指针复用时 drop：否则旧 FREEZE/Position claim 会套到新准星等 Effect 上。
local active = {}
local identities = {}
local identity_index = {}
-- 同一原生实体可在不同回调中得到多份 userdata wrapper，但 GetData binder 共享。
-- 每个 binder 只允许一个 canonical wrapper 进入强表，否则每次 get_effective_value 都会复制 active 键。
local canonical_by_binder = {}
local live_tokens, next_token, next_order = {}, 0, 0

-- auxiliary.functions imports Attribute_holder at module scope. Keep this side
-- lazy so startup preload cannot form Attribute_holder <-> functions recursion.
local auxi
local function get_auxi()
	if not auxi then auxi = require("Qing_Remaster_scripts.auxiliary.functions") end
	return auxi
end

local function valid(ent)
	if ent == nil then return false end
	if type(ent.Exists) == "function" then local ok, v = pcall(ent.Exists, ent); if not ok or not v then return false end end
	if type(ent.IsDead) == "function" then local ok, v = pcall(ent.IsDead, ent); if ok and v then return false end end
	return true
end

--- 实体身份指纹：强表跨重开后 userdata 指针可被引擎复用，Exists() 仍为 true。
local function read_identity(ent)
	if ent == nil or ent.IsGrid then return nil end
	local id = {}
	local ok, v
	ok, v = pcall(function() return ent.Type end); if ok then id.Type = v end
	ok, v = pcall(function() return ent.Variant end); if ok then id.Variant = v end
	ok, v = pcall(function() return ent.SubType end); if ok then id.SubType = v end
	ok, v = pcall(function() return ent.InitSeed end); if ok then id.InitSeed = v end
	ok, v = pcall(function() return ent.Index end); if ok then id.Index = v end
	return id
end

local function identity_matches(ent, id)
	if id == nil then return true end
	local cur = read_identity(ent)
	if cur == nil then return false end
	return cur.Type == id.Type
		and cur.Variant == id.Variant
		and cur.SubType == id.SubType
		and cur.InitSeed == id.InitSeed
		and cur.Index == id.Index
end

local function identity_key(id)
	if not id then return nil end
	return table.concat({
		tostring(id.Type), tostring(id.Variant), tostring(id.SubType),
		tostring(id.InitSeed), tostring(id.Index),
	}, ":")
end

local function index_identity(ent, id)
	local key = identity_key(id)
	if not key then return end
	local bucket = identity_index[key]
	if not bucket then bucket = {}; identity_index[key] = bucket end
	bucket[ent] = true
end

local function unindex_identity(ent, id)
	local key = identity_key(id)
	local bucket = key and identity_index[key]
	if not bucket then return end
	bucket[ent] = nil
	if not next(bucket) then identity_index[key] = nil end
end

local function copy(v, copier)
	if copier then local ok, result = pcall(copier, v); if ok then return result end end
	local ok_color, is_color = pcall(function() return v ~= nil and v.R ~= nil and v.G ~= nil and v.B ~= nil and v.A ~= nil end)
	if ok_color and is_color then
		local ok_c, copied = pcall(get_auxi().copy_color, v)
		if ok_c then return copied end
	end
	local ok_t, copied = pcall(get_auxi().TryCopy, v)
	if ok_t then return copied end
	return v
end
-- 动态 claim（function / {Function=...}）必须原样保存；常量则拷贝，避免 Position=Vector 别名被引擎就地改写。
local function store_claim_value(v, attr)
	if type(v) == "function" then return v end
	if type(v) == "table" and v.Function then return v end
	return copy(v, attr and attr.copier)
end
local function equal(a, b, comparer)
	if comparer then local ok, v = pcall(comparer, a, b); return ok and v == true end
	if a == b then return true end
	if a == nil or b == nil then return false end
	local ok, v = pcall(function() return a.X ~= nil and b.X ~= nil and math.abs(a.X-b.X)<0.0001 and math.abs(a.Y-b.Y)<0.0001 end)
	return ok and v
end
local function get(ent, name, attr)
	local ok, v
	if attr.getter then ok, v = pcall(attr.getter, ent) else ok, v = pcall(function() return ent[name] end) end
	if not ok then item.debug.error_count = item.debug.error_count + 1 end
	return ok, v
end
local function set(ent, name, attr, v)
	local ok
	if attr.setter then ok = pcall(attr.setter, ent, v) else ok = pcall(function() ent[name] = v end) end
	if not ok then item.debug.error_count = item.debug.error_count + 1 end
	return ok
end
local function eval(v, ent)
	local ok, result = pcall(get_auxi().check_if_any, v, ent)
	if not ok then item.debug.error_count = item.debug.error_count + 1 end
	return ok, result
end
local function top(attr)
	local best
	for _, claim in pairs(attr.claims) do if not best or claim.order > best.order then best = claim end end
	return best
end
local function protected(attr)
	for _, claim in pairs(attr.claims) do if claim.protect then return true end end
	return false
end
local function binder(ent)
	local ok, v = pcall(ent.GetData, ent); if ok then return v end
end
local function link_active(ent, bind, s)
	local canonical = canonical_by_binder[bind]
	if canonical and active[canonical] then
		active[canonical][bind] = s
		return canonical
	end
	canonical_by_binder[bind] = ent
	active[ent] = active[ent] or {}
	active[ent][bind] = s
	if identities[ent] == nil and not ent.IsGrid then
		identities[ent] = read_identity(ent)
		index_identity(ent, identities[ent])
	end
	return ent
end
local function state(ent, bind, create)
	if not bind then return nil end
	local s = bind[item.state_key]
	if not s and create then
		s = {attrs = {}, binder = bind}
		bind[item.state_key] = s
	end
	-- 已有 Data state 时也必须挂回 active（防历史弱键丢失 / 外部只写 Data 的恢复）
	if s then link_active(ent, bind, s) end
	return s
end
local function sync_origin(ent, name, attr)
	local ok, current = get(ent, name, attr)
	if ok and attr.has_last and not equal(current, attr.last_applied, attr.comparer) and not protected(attr) then attr.origin = copy(current, attr.copier) end
end
local function apply(ent, name, attr)
	local claim = top(attr); if not claim then return false end
	local ok, wanted = eval(claim.value, ent); if not ok then return false end
	local got, current = get(ent, name, attr)
	if got and not equal(current, wanted, attr.comparer) then set(ent, name, attr, wanted) end
	attr.last_applied, attr.has_last = copy(wanted, attr.copier), true
	return true
end
local function cleanup(ent, bind, s)
	if next(s.attrs) then return end
	bind[item.state_key] = nil
	local canonical = canonical_by_binder[bind] or ent
	canonical_by_binder[bind] = nil
	local es = active[canonical]; if es then es[bind] = nil; if not next(es) then
		active[canonical] = nil
		unindex_identity(canonical, identities[canonical])
		identities[canonical] = nil
	end end
end
local function drop_entity(ent, states)
	for _, s in pairs(states) do
		for _, attr in pairs(s.attrs) do
			for token in pairs(attr.claims) do live_tokens[tostring(token)] = nil end
		end
		if s.binder then s.binder[item.state_key] = nil end
		if s.binder and canonical_by_binder[s.binder] == ent then canonical_by_binder[s.binder] = nil end
	end
	active[ent] = nil
	unindex_identity(ent, identities[ent])
	identities[ent] = nil
end

local function drop_removed_entity(removed)
	local id = read_identity(removed)
	local key = identity_key(id)
	local bucket = key and identity_index[key]
	if not bucket then
		if remove_probe_observer then pcall(remove_probe_observer, id, 0, 0, 0) end
		return 0
	end
	local targets = {}
	for ent in pairs(bucket) do targets[#targets + 1] = ent end
	local dropped, attrs, claims = 0, 0, 0
	for i = 1, #targets do
		local ent = targets[i]
		local states = active[ent]
		if states then
			if remove_probe_observer then
				for _, state in pairs(states) do
					for _, attr in pairs(state.attrs) do
						attrs = attrs + 1
						for _ in pairs(attr.claims) do claims = claims + 1 end
					end
				end
			end
			drop_entity(ent, states)
			dropped = dropped + 1
		end
	end
	if remove_probe_observer then pcall(remove_probe_observer, id, dropped, attrs, claims) end
	return dropped
end

--- 丢弃全部活动 claim（重开/退出局）。强表跨局残留 + userdata 复用会导致新实体被旧 FREEZE/Position 冻住。
function item.drop_all()
	for ent, states in pairs(active) do
		drop_entity(ent, states)
	end
	active = {}
	identities = {}
	identity_index = {}
	canonical_by_binder = {}
	live_tokens = {}
end

function item.Init()
	local assemble = require("Qing_Remaster_scripts.others.Assemble_holder")
	assemble.register_on(item.own_key, item, {force = true})
end
function item.try_hold_attribute(ent, name, change_to, params)
	params = params or {}; if not valid(ent) or name == nil or change_to == nil then return nil end
	-- 指针复用：拒绝在身份已变的 userdata 上继续挂旧 binder
	if identities[ent] and not identity_matches(ent, identities[ent]) then
		local stale = active[ent]
		if stale then drop_entity(ent, stale) end
	end
	local bind = binder(ent); local s = state(ent, bind, true); if not s then return nil end
	local attr = s.attrs[name]
	if not attr then
		attr = {claims = {}, getter = params.toget, setter = params.tochange, comparer = params.tocompare,
			copier = params.copy, descriptor_key = params.descriptor_key}
		local ok, origin = get(ent, name, attr); if not ok then cleanup(ent, bind, s); return nil end
		attr.origin = copy(origin, attr.copier); s.attrs[name] = attr
	else
		if attr.descriptor_key and params.descriptor_key and attr.descriptor_key ~= params.descriptor_key then
			item.debug.error_count = item.debug.error_count + 1; return nil
		end
		sync_origin(ent, name, attr)
	end
	local token
	repeat next_token = next_token + 1; token = next_token until not live_tokens[tostring(token)]
	next_order = next_order + 1
	attr.claims[token] = {value = store_claim_value(change_to, attr), protect = params.protect == true, order = next_order}
	live_tokens[tostring(token)] = true; apply(ent, name, attr); return token
end
function item.try_rewind_attribute(ent, name, id, params)
	params = params or {}; if ent == nil or name == nil or id == nil then return false end
	local bind = binder(ent); local s = state(ent, bind, false); local attr = s and s.attrs[name]
	if not attr or not attr.claims[id] then return false end
	sync_origin(ent, name, attr); attr.claims[id] = nil; live_tokens[tostring(id)] = nil
	if next(attr.claims) then apply(ent, name, attr) else set(ent, name, attr, copy(attr.origin, attr.copier)); s.attrs[name] = nil; cleanup(ent, bind, s) end
	return true
end
function item.try_hold_and_rewind_attribute(ent, name, change_to, cooldown, params)
	local token = item.try_hold_attribute(ent, name, change_to, params)
	if token ~= nil then delay_buffer.addeffe(function(v) if valid(v.ent) then item.try_rewind_attribute(v.ent,v.name,v.token,v.params) end end,
		{ent=ent,name=name,token=token,params=params}, cooldown) end
	return token
end
function item.assign_attribute()
	for ent, states in pairs(active) do
		if not valid(ent) then
			drop_entity(ent, states)
		elseif not ent.IsGrid and identities[ent] and not identity_matches(ent, identities[ent]) then
			-- 重开/生成后指针复用：旧 claim 不得施加到新实体（典型：准星 Effect 被冻在出生点）
			drop_entity(ent, states)
		elseif ent.IsGrid then
			-- visit_epoch / room_key 失效或 get_grid 为空：停止 apply，避免跨房 Open
			local grid_ok = false
			if ent.get_grid then
				local ok, g = pcall(function() return ent:get_grid() end)
				grid_ok = ok and g ~= nil
			end
			if not grid_ok then
				drop_entity(ent, states)
			else
				for _, s in pairs(states) do
					for name, attr in pairs(s.attrs) do
						sync_origin(ent, name, attr)
						apply(ent, name, attr)
					end
				end
			end
		else
			for _, s in pairs(states) do
				for name, attr in pairs(s.attrs) do
					sync_origin(ent, name, attr)
					apply(ent, name, attr)
				end
			end
		end
	end
end
function item.get_debug_stats()
	local result = {entities=0,binders=0,attrs=0,claims=0,errors=item.debug.error_count}
	for _, states in pairs(active) do result.entities=result.entities+1; for _, s in pairs(states) do result.binders=result.binders+1; for _, a in pairs(s.attrs) do result.attrs=result.attrs+1; for _ in pairs(a.claims) do result.claims=result.claims+1 end end end end
	return result
end
function item.get_effective_value(ent, name, params)
	params = params or {}
	local bind = binder(ent); local s = state(ent, bind, false); local attr = s and s.attrs[name]
	local claim = attr and top(attr); if not claim then return nil, false end
	local ok, value = eval(claim.value, ent); if not ok then return nil, false end
	return value, true
end

local flag_descriptors, sprite_descriptors, data_descriptors = {}, {}, {}
function item.descriptors.entity_flag(flag)
	if not flag_descriptors[flag] then
		flag_descriptors[flag] = {
			descriptor_key = "entity_flag:"..tostring(flag),
			toget = function(ent) return ent:HasEntityFlags(flag) end,
			tochange = function(ent, value) if value == true then ent:AddEntityFlags(flag) else ent:ClearEntityFlags(flag) end end,
		}
	end
	return flag_descriptors[flag]
end
local function descriptor_options(base, options)
	if type(options) ~= "table" then return base end
	local result = {}; for k,v in pairs(base) do result[k] = v end; for k,v in pairs(options) do result[k] = v end
	return result
end
function item.descriptors.color(options)
	if not item.descriptors._color then
		item.descriptors._color = {
			descriptor_key = "entity_color", toget = function(ent) return ent:GetColor() end,
			tochange = function(ent, value) ent:SetColor(value, 10, 99, false, false) end,
			copy = function(value) return get_auxi().copy_color(value) end,
			tocompare = function(a,b)
				local aa, bb = get_auxi().color2table(a), get_auxi().color2table(b)
				for _,k in ipairs({"R","G","B","A","RO","GO","BO","RC","GC","BC","AC"}) do
					if math.abs((aa[k] or 0)-(bb[k] or 0)) >= 0.01 then return false end
				end
				return true
			end,
		}
	end
	return descriptor_options(item.descriptors._color, options)
end
function item.descriptors.sprite_field(field)
	if not sprite_descriptors[field] then sprite_descriptors[field] = {
		descriptor_key = "sprite:"..tostring(field), toget = function(ent) return ent:GetSprite()[field] end,
		tochange = function(ent,value) ent:GetSprite()[field] = value end,
	} end
	return sprite_descriptors[field]
end
function item.descriptors.data_field(field)
	if not data_descriptors[field] then data_descriptors[field] = {
		descriptor_key = "data:"..tostring(field), toget = function(ent) return ent:GetData()[field] end,
		tochange = function(ent,value) ent:GetData()[field] = value end,
	} end
	return data_descriptors[field]
end
function item.run_self_test()
	local checks = {}; local function check(n,v) checks[#checks+1]={n=n,v=v==true} end
	local function fake(v) local e={Value=v,virtual=v,data={}}; function e:GetData() return self.data end; function e:Exists() return true end; function e:IsDead() return false end; return e end
	local e=fake(1); local a=item.try_hold_attribute(e,"Value",10); check("single/apply",e.Value==10); item.try_rewind_attribute(e,"Value",a); check("single/restore",e.Value==1)
	e=fake(1); a=item.try_hold_attribute(e,"Value",10); local b=item.try_hold_attribute(e,"Value",20); item.try_rewind_attribute(e,"Value",b); check("nested/top",e.Value==10); item.try_rewind_attribute(e,"Value",a); check("nested/top-restore",e.Value==1)
	e=fake(1); a=item.try_hold_attribute(e,"Value",10); b=item.try_hold_attribute(e,"Value",20); item.try_rewind_attribute(e,"Value",a); check("nested/non-top",e.Value==20); item.try_rewind_attribute(e,"Value",b); check("nested/non-top-restore",e.Value==1)
	e=fake(1); local d=4; a=item.try_hold_attribute(e,"Value",function() return d end); d=7; item.assign_attribute(); check("dynamic",e.Value==7); item.try_rewind_attribute(e,"Value",a)
	e=fake(1); a=item.try_hold_attribute(e,"Value",10); e.Value=6; item.assign_attribute(); item.try_rewind_attribute(e,"Value",a); check("external/free",e.Value==6)
	e=fake(1); a=item.try_hold_attribute(e,"Value",10,{protect=true}); e.Value=6; item.assign_attribute(); item.try_rewind_attribute(e,"Value",a); check("external/protected",e.Value==1)
	e=fake(3); local p={toget=function(x)return x.virtual end,tochange=function(x,v)x.virtual=v end}; a=item.try_hold_attribute(e,"Virtual",9,p); item.try_rewind_attribute(e,"Virtual",a,p); check("accessor",e.virtual==3); check("duplicate",item.try_rewind_attribute(e,"Virtual",a,p)==false)
	local passed, failures=0,{}; for _,c in ipairs(checks) do if c.v then passed=passed+1 else failures[#failures+1]=c.n end end
	item.debug.last_report={passed=passed,total=#checks,failures=failures,frame=Game and Game():GetFrameCount() or -1}; return item.debug.last_report
end

local function wipe_session_state()
	item.drop_all()
	local ok, a = pcall(get_auxi)
	if ok and a and type(a._time_stop_active) == "table" then
		a._time_stop_active = {}
		a._time_stop_refresh_frame = {}
	end
end

-- 蓝图开面板时停 → 暂停菜单重开：旧 claim 留在强表里，准星 Effect 复用指针后会被 Position/FREEZE 钉死
table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function() wipe_session_state() end,
})
table.insert(item.ToCall, {CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function() wipe_session_state() end,
})

table.insert(item.ToCall,{CallBack=ModCallbacks.MC_POST_UPDATE,params=nil,Function=item.assign_attribute})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_POST_ENTITY_REMOVE,params=nil,
Function = function(_, ent)
	-- 移除回调可能给出另一份 userdata wrapper；按完整身份索引裁断，禁止 `ent == tracked`。
	drop_removed_entity(ent)
end,
})
return item

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {ToCall={},myToCall={},pre_myToCall={},own_key="h_c_",debug={probe_enabled=false,errors=0,migrations=0,migration_orphans=0,parameter_conflicts=0,ambiguous_matches=0,similarity_resolutions=0,ambiguous_fallbacks=0,last_error=nil,last_event="not initialized"}}
local SCHEMA_VERSION,duplicate_key=2,"___hci_"
local runtime={claims={},pending_remove={},tracked={},tracked_entities={},next_claim_token=1,room_epoch=0}

function item.reset_debug_stats()
	item.debug.errors=0 item.debug.migrations=0 item.debug.migration_orphans=0 item.debug.parameter_conflicts=0
	item.debug.ambiguous_matches=0 item.debug.similarity_resolutions=0 item.debug.ambiguous_fallbacks=0
	item.debug.last_error=nil item.debug.last_report=nil item.debug.last_duplicate_test=nil item.debug.last_event="debug reset"
end

local function note_error(where,err) item.debug.errors=item.debug.errors+1 item.debug.last_error=tostring(where)..": "..tostring(err) end
local function safe_get_data(ent)
	if ent==nil then return nil end
	local ok,data=pcall(function() return ent:GetData() end)
	if not ok then note_error("GetData",data) return nil end
	return data
end
-- Used only while the entity is valid to index its runtime tracking slot.
-- Removal detection retains that slot key and never tries to recompute it from removed userdata.
local function entity_ptr_hash(ent)
	if ent==nil then return nil end
	local ok,value=pcall(GetPtrHash,ent)
	if not ok or value==nil then return nil end
	return tostring(value)
end
local function new_store() return {schema_version=SCHEMA_VERSION,next_record_id=1,records={},index={},migration_orphans={},cross_floor_seeds={}} end
local function count(tbl) local n=0 for _ in pairs(tbl or {}) do n=n+1 end return n end
local function normalize_scope(params)
	params=params or {}
	if params.one_room==true and params.keep_level==true then item.debug.parameter_conflicts=item.debug.parameter_conflicts+1 end
	if params.one_room==true then return "room" end
	if params.keep_level==true then return "run" end
	return "level"
end
local function normalize_match(params)
	params=params or {}
	return {ignore_type=params.ignore_type==true,ignore_variant=params.ignore_type~=true and params.ignore_variant==true,ignore_subtype=params.ignore_type~=true and params.ignore_variant~=true and params.ignore_subtype==true,record_subtype=params.record_subtype}
end
local function identity_from_entity(ent,params)
	params=params or {}
	return {init_seed=ent.InitSeed,type=ent.Type,variant=ent.Variant,subtype=params.record_subtype or ent.SubType or ent.Subtype}
end
local function current_room_key()
	local ok,key=pcall(function()
		local level=Game():GetLevel() local desc=level:GetCurrentRoomDesc()
		return table.concat({tostring(level:GetStage()),tostring(level:GetStageType()),tostring(desc.ListIndex),tostring(desc.GridIndex)},":")
	end)
	return ok and key or nil
end
local function related_seed(ent,field)
	local ok,seed=pcall(function() local related=ent[field] return related and related.InitSeed or nil end)
	return ok and seed or nil
end
local function evidence_from_entity(ent)
	local evidence={room_key=current_room_key()}
	local ok,pos=pcall(function() return {x=ent.Position.X,y=ent.Position.Y} end)
	if ok then evidence.x=pos.x evidence.y=pos.y end
	evidence.spawner_seed=related_seed(ent,"SpawnerEntity")
	evidence.parent_seed=related_seed(ent,"Parent")
	return evidence
end
local function update_record_evidence(record,ent)
	if record and record.evidence_enabled==true and ent then record.evidence=evidence_from_entity(ent) end
end
local function fingerprint(identity,match)
	match=match or {}
	local parts={"I",tostring(identity.init_seed)}
	if not match.ignore_type then
		table.insert(parts,"T") table.insert(parts,tostring(identity.type))
		if not match.ignore_variant then
			table.insert(parts,"V") table.insert(parts,tostring(identity.variant))
			if not match.ignore_subtype then table.insert(parts,"S") table.insert(parts,tostring(identity.subtype)) end
		end
	end
	return table.concat(parts,"|")
end
local function make_legacy_name(ent,params)
	params=params or {}
	local ret=""
	if params.ignore_type~=true then
		ret=ret..tostring(ent.Type).."_T_"
		if params.ignore_variant~=true then
			ret=ret..tostring(ent.Variant).."_V_"
			if params.ignore_subtype~=true then ret=ret..tostring(params.record_subtype or ent.SubType or ent.Subtype).."_S_" end
		end
	end
	return ret..tostring(ent.InitSeed).."_I_"
end
function item.get_name(ent,params,checkname)
	if ent==nil then return {} end
	params=params or {}
	local ret={make_legacy_name(ent,params)}
	if not params.params_name_only then
		table.insert(ret,make_legacy_name(ent,{ignore_subtype=true,record_subtype=params.record_subtype}))
		table.insert(ret,make_legacy_name(ent,{ignore_variant=true,record_subtype=params.record_subtype}))
		table.insert(ret,make_legacy_name(ent,{ignore_type=true,record_subtype=params.record_subtype}))
	end
	return ret
end
local function parse_legacy_identity(raw_name)
	local name=tostring(raw_name):gsub(duplicate_key.."%d+$","")
	local t,v,s,seed=name:match("^(-?%d+)_T_(-?%d+)_V_(-?%d+)_S_(-?%d+)_I_$")
	if t then return {type=tonumber(t),variant=tonumber(v),subtype=tonumber(s),init_seed=tonumber(seed)},normalize_match({}) end
	t,v,seed=name:match("^(-?%d+)_T_(-?%d+)_V_(-?%d+)_I_$")
	if t then return {type=tonumber(t),variant=tonumber(v),subtype=0,init_seed=tonumber(seed)},normalize_match({ignore_subtype=true}) end
	t,seed=name:match("^(-?%d+)_T_(-?%d+)_I_$")
	if t then return {type=tonumber(t),variant=0,subtype=0,init_seed=tonumber(seed)},normalize_match({ignore_variant=true}) end
	seed=name:match("^(-?%d+)_I_$")
	if seed then return {type=0,variant=0,subtype=0,init_seed=tonumber(seed)},normalize_match({ignore_type=true}) end
	return nil,nil
end
local function rebuild_index(store)
	store.index={}
	local normalized,max_id={},0
	for raw_id,record in pairs(store.records or {}) do
		local id=tostring(raw_id)
		normalized[id]=record
		if type(record)=="table" and type(record.identity)=="table" then
			record.id=id record.match=record.match or normalize_match({}) record.fingerprint=fingerprint(record.identity,record.match)
			store.index[record.fingerprint]=store.index[record.fingerprint] or {}
			table.insert(store.index[record.fingerprint],id)
			max_id=math.max(max_id,tonumber(id) or 0)
		end
	end
	store.records=normalized
	for _,ids in pairs(store.index) do table.sort(ids,function(a,b) return (tonumber(a) or 0)<(tonumber(b) or 0) end) end
	for _,ids in pairs(store.index) do
		local owner_counts={}
		for _,id in ipairs(ids) do local record=store.records[tostring(id)] if record then owner_counts[record.owner]=(owner_counts[record.owner] or 0)+1 end end
		for _,id in ipairs(ids) do
			local record=store.records[tostring(id)]
			if record then record.evidence_enabled=(owner_counts[record.owner] or 0)>=2 if not record.evidence_enabled then record.evidence=nil end end
		end
	end
	store.next_record_id=math.max(tonumber(store.next_record_id) or 1,max_id+1)
end
local function migrate_legacy(old)
	local store,rows=new_store(),{}
	for legacy_name,bucket in pairs(old or {}) do
		if type(bucket)=="table" then table.insert(rows,{name=tostring(legacy_name),bucket=bucket,suffix=tonumber(tostring(legacy_name):match(duplicate_key.."(%d+)$")) or 1}) end
	end
	table.sort(rows,function(a,b) if a.name==b.name then return a.suffix<b.suffix end return a.name<b.name end)
	for _,row in ipairs(rows) do
		local identity,match=parse_legacy_identity(row.name)
		if identity then
			for owner,desc in pairs(row.bucket) do
				if type(desc)=="table" then
					local id=tostring(store.next_record_id) store.next_record_id=store.next_record_id+1
					store.records[id]={id=id,owner=owner,data=auxi.deepCopy(desc.data or {}),identity=auxi.deepCopy(identity),match=auxi.deepCopy(match),scope=desc.one_room and "room" or (desc.kplv and "run" or "level"),retain_on_remove=desc.c==true,legacy_name=row.name}
				end
			end
		else
			store.migration_orphans[row.name]=auxi.deepCopy(row.bucket) item.debug.migration_orphans=item.debug.migration_orphans+1
		end
	end
	rebuild_index(store) item.debug.migrations=item.debug.migrations+1 item.debug.last_event="legacy store migrated"
	return store
end
local function ensure_store()
	save.elses=save.elses or {}
	local store=save.elses.Consistance_holder
	if type(store)~="table" then store=new_store() save.elses.Consistance_holder=store
	elseif store.schema_version~=SCHEMA_VERSION then store=migrate_legacy(store) save.elses.Consistance_holder=store
	else store.records=store.records or {} store.index=store.index or {} store.migration_orphans=store.migration_orphans or {} store.cross_floor_seeds=store.cross_floor_seeds or {} store.next_record_id=tonumber(store.next_record_id) or 1 end
	return store
end
local function clear_claims() runtime.claims={} runtime.pending_remove={} runtime.tracked={} runtime.tracked_entities={} runtime.room_epoch=runtime.room_epoch+1 end
local function get_runtime_names_from_data(data) data._Consistance_holder_names=data._Consistance_holder_names or {} return data._Consistance_holder_names end
local function get_runtime_names(ent) local data=safe_get_data(ent) return data and get_runtime_names_from_data(data) or nil end
local function claim_record(id)
	id=tostring(id) if runtime.claims[id]~=nil then return nil end
	local token=runtime.next_claim_token runtime.next_claim_token=token+1 runtime.claims[id]=token return token
end
local function release_record_claim(id) if id~=nil then runtime.claims[tostring(id)]=nil end end
local function remove_from_index(store,record)
	local ids=record and record.fingerprint and store.index[record.fingerprint]
	if not ids then return end
	for i=#ids,1,-1 do if tostring(ids[i])==tostring(record.id) then table.remove(ids,i) end end
	if #ids==0 then store.index[record.fingerprint]=nil
	else
		local owner_counts={}
		for _,id in ipairs(ids) do local candidate=store.records[tostring(id)] if candidate then owner_counts[candidate.owner]=(owner_counts[candidate.owner] or 0)+1 end end
		for _,id in ipairs(ids) do
			local candidate=store.records[tostring(id)]
			if candidate then candidate.evidence_enabled=(owner_counts[candidate.owner] or 0)>=2 if not candidate.evidence_enabled then candidate.evidence=nil end end
		end
	end
end
local function drop_record(id)
	local store=ensure_store() id=tostring(id)
	local record=store.records[id] if not record then return false end
	remove_from_index(store,record) store.records[id]=nil release_record_claim(id) runtime.pending_remove[id]=nil return true
end
function item.drop_record(id) return drop_record(id) end
local function add_record(owner,data,identity,match,params,ent)
	local store=ensure_store() local id=tostring(store.next_record_id) store.next_record_id=store.next_record_id+1
	local record={id=id,owner=owner,data=auxi.deepCopy(data or {}),identity=identity,match=match,scope=normalize_scope(params),retain_on_remove=params and params.consistance==true or false,evidence_enabled=false}
	record.fingerprint=fingerprint(identity,match) store.records[id]=record store.index[record.fingerprint]=store.index[record.fingerprint] or {} table.insert(store.index[record.fingerprint],id)
	local ids=store.index[record.fingerprint] local same_owner_ids={}
	for _,record_id in ipairs(ids) do local candidate=store.records[tostring(record_id)] if candidate and candidate.owner==owner then table.insert(same_owner_ids,record_id) end end
	if #same_owner_ids>=2 then
		for _,record_id in ipairs(same_owner_ids) do local candidate=store.records[tostring(record_id)] if candidate then candidate.evidence_enabled=true end end
		for ptr,snapshot in pairs(runtime.tracked) do
			local tracked_ent=runtime.tracked_entities[ptr]
			for _,entry in ipairs(snapshot.entries or {}) do
				local candidate=store.records[tostring(entry.id)]
				if tracked_ent and candidate and candidate.fingerprint==record.fingerprint and candidate.owner==owner then
					local ok,valid=pcall(function() return tracked_ent:Exists() and not tracked_ent:IsDead() end)
					if ok and valid then local evidence=evidence_from_entity(tracked_ent) candidate.evidence=evidence snapshot.evidence=evidence end
				end
			end
		end
		update_record_evidence(record,ent)
	end
	return record
end
local function candidate_fingerprints(ent,params)
	local identity=identity_from_entity(ent,params)
	return {fingerprint(identity,normalize_match({})),fingerprint(identity,normalize_match({ignore_subtype=true})),fingerprint(identity,normalize_match({ignore_variant=true})),fingerprint(identity,normalize_match({ignore_type=true}))}
end
local function records_from_names(store,names,owner,include_claimed)
	local ret,seen={},{}
	for _,raw_name in ipairs(names or {}) do
		local name=tostring(raw_name) local direct=store.records[name] local ids=direct and {name} or store.index[name]
		if ids==nil then local identity,match=parse_legacy_identity(name) if identity then ids=store.index[fingerprint(identity,match)] end end
		for _,id in ipairs(ids or {}) do
			id=tostring(id) local record=store.records[id]
			if record and not seen[id] and (owner==nil or record.owner==owner) and runtime.pending_remove[id]~=true and (include_claimed or runtime.claims[id]==nil) then seen[id]=true table.insert(ret,record) end
		end
	end
	table.sort(ret,function(a,b) return (tonumber(a.id) or 0)<(tonumber(b.id) or 0) end) return ret
end
local function find_candidates(ent,owner,params,include_claimed)
	local store=ensure_store()
	local records
	if params and params.names then records=records_from_names(store,params.names,owner,include_claimed)
	else
		records={}
		for _,fp in ipairs(candidate_fingerprints(ent,params)) do
			records=records_from_names(store,{fp},owner,include_claimed)
			if #records>0 then break end
		end
	end
	if #records<=1 then return records end
	item.debug.ambiguous_matches=item.debug.ambiguous_matches+1
	local current=evidence_from_entity(ent)
	local function score(record)
		local old=record.evidence
		local match=record.match or {}
		local specificity=match.ignore_type and 1000000 or (match.ignore_variant and 2000000 or (match.ignore_subtype and 3000000 or 4000000))
		if type(old)~="table" then return specificity,false end
		local value,has=specificity,false
		if current.room_key and old.room_key then value=value+(current.room_key==old.room_key and 100000 or -100000) has=true end
		if current.spawner_seed and old.spawner_seed then value=value+(current.spawner_seed==old.spawner_seed and 20000 or -20000) has=true end
		if current.parent_seed and old.parent_seed then value=value+(current.parent_seed==old.parent_seed and 10000 or -10000) has=true end
		if current.x and current.y and old.x and old.y and (not current.room_key or not old.room_key or current.room_key==old.room_key) then
			local dx,dy=current.x-old.x,current.y-old.y value=value-dx*dx-dy*dy has=true
		end
		return value,has
	end
	local scored={}
	for _,record in ipairs(records) do local value,has=score(record) table.insert(scored,{record=record,value=value,has=has}) end
	table.sort(scored,function(a,b) if a.value~=b.value then return a.value>b.value end return (tonumber(a.record.id) or 0)<(tonumber(b.record.id) or 0) end)
	local resolved=scored[1].has and (#scored==1 or scored[1].value~=scored[2].value)
	if resolved then item.debug.similarity_resolutions=item.debug.similarity_resolutions+1 else item.debug.ambiguous_fallbacks=item.debug.ambiguous_fallbacks+1 end
	local sorted={} for _,row in ipairs(scored) do table.insert(sorted,row.record) end return sorted
end
local function refresh_tracked_entity(ent,data)
	local ptr=entity_ptr_hash(ent)
	if not ptr then return end
	data=data or safe_get_data(ent)
	if not data or type(data._Consistance_holder_names)~="table" then runtime.tracked[ptr]=nil runtime.tracked_entities[ptr]=nil return end
	local store=ensure_store() local snapshot={entries={},evidence=nil} local needs_evidence=false
	for owner,raw_id in pairs(data._Consistance_holder_names) do
		local id=tostring(raw_id)
		if store.records[id] then
			if store.records[id].evidence_enabled==true then needs_evidence=true end
			local payload=data._Data and data._Data[owner]
			-- 保留 Lua Data 表引用，使业务后续原地修改仍能被移除快照看到；不保留或访问实体字段。
			table.insert(snapshot.entries,{owner=owner,id=id,data=payload or {}})
		end
	end
	if needs_evidence then snapshot.evidence=evidence_from_entity(ent) end
	if #snapshot.entries>0 then runtime.tracked[ptr]=snapshot runtime.tracked_entities[ptr]=ent else runtime.tracked[ptr]=nil runtime.tracked_entities[ptr]=nil end
end

function item.try_hold_over_entity(ent,checkname)
	if ent==nil or checkname==nil then return nil end
	local data=safe_get_data(ent) if not data then return nil end
	data._Data=data._Data or {} data._Data[checkname]=data._Data[checkname] or {} return data._Data[checkname]
end

local function seed_key(seed)
	if seed == nil then return nil end
	local n = tonumber(seed)
	if n ~= nil then return tostring(n) end
	return tostring(seed)
end

local function cross_floor_seed_set(store)
	store = store or ensure_store()
	store.cross_floor_seeds = store.cross_floor_seeds or {}
	return store.cross_floor_seeds
end

local function remember_cross_floor_seed(seed, store)
	local key = seed_key(seed)
	if not key then return end
	cross_floor_seed_set(store)[key] = true
end

local function forget_cross_floor_seed(seed, store)
	local key = seed_key(seed)
	if not key then return end
	local set = cross_floor_seed_set(store)
	set[key] = nil
end

local function demote_cross_floor_if_needed(record)
	if not record or not record._promoted_cross_floor then return end
	forget_cross_floor_seed(record.identity and record.identity.init_seed)
	record.scope = record._scope_before_promote or "level"
	record.retain_on_remove = record._retain_before_promote == true
	record._promoted_cross_floor = nil
	record._scope_before_promote = nil
	record._retain_before_promote = nil
end

local function promote_cross_floor_record(record)
	if not record then return false end
	if not record._promoted_cross_floor then
		record._promoted_cross_floor = true
		record._scope_before_promote = record.scope
		record._retain_before_promote = record.retain_on_remove == true
	end
	record.scope = "run"
	record.retain_on_remove = true
	remember_cross_floor_seed(record.identity and record.identity.init_seed)
	return true
end

function item.try_hold_entity(ent,checkname,params,params2)
	checkname=checkname or "Check" params=params or {}
	if ent==nil then note_error("try_hold_entity","nil entity") return nil end
	local data=safe_get_data(ent) if not data then return nil end
	data._Data=data._Data or {} data._Data[checkname]=data._Data[checkname] or {}
	local names=get_runtime_names_from_data(data) local store=ensure_store()
	local id=names[checkname] and tostring(names[checkname]) or nil local record=id and store.records[id] or nil
	if record==nil then local candidates=find_candidates(ent,checkname,params,false) record=candidates[1] if record then id=record.id end end
	if record==nil then record=add_record(checkname,data._Data[checkname],identity_from_entity(ent,params),normalize_match(params),params,ent) id=record.id
	else
		record.data=auxi.deepCopy(data._Data[checkname])
		update_record_evidence(record,ent)
		if params.one_room~=nil or params.keep_level~=nil then record.scope=normalize_scope(params) end
		if params.consistance~=nil then record.retain_on_remove=params.consistance==true end
	end
	if runtime.claims[id]==nil then claim_record(id) end names[checkname]=id refresh_tracked_entity(ent,data) if params.printname then print(id) end return id
end
function item.try_check_entity(ent,checkname,testing,params)
	if ent==nil then return nil end params=params or {}
	local data=safe_get_data(ent) if not data then return nil end data._Data=data._Data or {}
	local names=get_runtime_names_from_data(data) local store=ensure_store()
	if checkname and not testing and data._Data[checkname]~=nil then
		local id=names[checkname] and tostring(names[checkname]) or nil if id and store.records[id] and runtime.claims[id]==nil then claim_record(id) end
		if id and store.records[id] then demote_cross_floor_if_needed(store.records[id]) end
		refresh_tracked_entity(ent,data) return true
	end
	local bound_id=checkname and names[checkname] and tostring(names[checkname]) or nil local bound=bound_id and store.records[bound_id] or nil
	if bound and (testing or runtime.pending_remove[bound_id]~=true) then
		if testing then return {desc=bound,name=bound_id} end
		data._Data[checkname]=auxi.deepCopy(bound.data) if runtime.claims[bound_id]==nil then claim_record(bound_id) end
		demote_cross_floor_if_needed(bound)
		update_record_evidence(bound,ent) refresh_tracked_entity(ent,data) return true
	end
	local candidates=find_candidates(ent,checkname,params,testing==true) local record=candidates[1] if not record then return nil end
	if testing then return {desc=record,name=record.id} end
	if checkname then
		data._Data[checkname]=auxi.deepCopy(record.data) names[checkname]=record.id claim_record(record.id)
		demote_cross_floor_if_needed(record)
		update_record_evidence(record,ent) refresh_tracked_entity(ent,data)
	else return {desc=record,name=record.id} end
	return true
end
function item.release_claim(ent,checkname)
	local names=get_runtime_names(ent) if not names then return false end local id=names[checkname] if id==nil then return false end
	release_record_claim(id) return true
end
local function resolve_remove_ids(ent,checkname,params,names)
	local store=ensure_store() local ids,seen={},{}
	local function add(id) id=id and tostring(id) or nil if id and store.records[id] and not seen[id] then seen[id]=true table.insert(ids,id) end end
	if params.names then
		local all_direct=true
		for _,raw_name in ipairs(params.names) do if store.records[tostring(raw_name)]==nil then all_direct=false break end end
		if all_direct then for _,raw_name in ipairs(params.names) do add(raw_name) end
		else local candidates=find_candidates(ent,checkname,params,false) if candidates[1] then add(candidates[1].id) end end
	elseif checkname and names[checkname] then add(names[checkname])
	elseif checkname then local candidates=find_candidates(ent,checkname,params,false) if candidates[1] then add(candidates[1].id) end
	else for owner,id in pairs(names) do if checkname==nil or owner==checkname then add(id) end end end
	return ids
end
function item.try_remove_entity(ent,checkname,params)
	if ent==nil then return false end params=params or {}
	local data=safe_get_data(ent) if not data then return false end data._Data=data._Data or {}
	local names=get_runtime_names_from_data(data) local ids=resolve_remove_ids(ent,checkname,params,names) local removed=false
	for _,id in ipairs(ids) do removed=drop_record(id) or removed end
	if checkname then data._Data[checkname]=nil names[checkname]=nil else data._Data={} data._Consistance_holder_names={} end
	refresh_tracked_entity(ent,data)
	if params.printname then for _,id in ipairs(ids) do print(id) end end return removed
end

local function cleanup_scope(event)
	local store=ensure_store() local remove={}
	for id,record in pairs(store.records) do
		if event=="room" and record.scope=="room" then table.insert(remove,id)
		elseif event=="level" and record.scope~="run" then table.insert(remove,id) end
		-- 临时 promote（scope=run + _promoted_cross_floor）在 PRE_NEW_LEVEL 里先清旧再 preserve，此处勿再删
	end
	for _,id in ipairs(remove) do drop_record(id) end item.debug.last_event=event.." cleanup: "..tostring(#remove) return #remove
end
function item.cleanup_scope(event) return cleanup_scope(event) end

--- RGON：勿忘草 / 搬家盒 中的 InitSeed 集合（无可 API 时返回空）
local function iter_entities_save_states(vec, fn)
	if vec == nil or fn == nil then return end
	local seen = {}
	local function accept(st)
		if not st then return end
		local ok_seed, seed = pcall(function() return st:GetInitSeed() end)
		local key = (ok_seed and seed_key(seed)) or tostring(st)
		if seen[key] then return end
		seen[key] = true
		fn(st)
	end
	local len = 0
	pcall(function() len = #vec end)
	if type(len) ~= "number" or len < 0 then len = 0 end
	pcall(function()
		if type(vec.Size) == "number" then len = math.max(len, vec.Size) end
	end)
	-- 同时尝试 0-based / 1-based；#vec 为 0 时至少探一次 Get(0)/Get(1)
	local last = math.max(len, 1)
	for i = 0, last do
		local ok, st = pcall(function() return vec:Get(i) end)
		if ok then accept(st) end
	end
end

local function collect_cross_floor_init_seeds()
	local seeds = {}
	if not REPENTOGON then return seeds end
	local function add_vec(vec)
		iter_entities_save_states(vec, function(st)
			local ok, seed = pcall(function() return st:GetInitSeed() end)
			local key = ok and seed_key(seed) or nil
			if key then seeds[key] = true end
		end)
	end
	pcall(function() add_vec(Game():GetLevel():GetMyosotisPickups()) end)
	local n = Game():GetNumPlayers()
	for i = 0, n - 1 do
		local player = Game():GetPlayer(i)
		if player then pcall(function() add_vec(player:GetMovingBoxContents()) end) end
	end
	return seeds
end

local function union_keep_seeds(live_seeds)
	local keep = {}
	for key in pairs(live_seeds or {}) do keep[key] = true end
	for key in pairs(cross_floor_seed_set()) do keep[key] = true end
	return keep
end

--- 将命中勿忘草/搬家盒 InitSeed 的记录临时升为 run + retain，换层后 try_check rematch 再降回
function item.preserve_cross_floor_records()
	local seeds = collect_cross_floor_init_seeds()
	for key in pairs(seeds) do remember_cross_floor_seed(key) end
	local keep = union_keep_seeds(seeds)
	if next(keep) == nil then
		item.debug.last_event = "cross-floor preserve: 0 seeds"
		item.debug.last_cross_floor_preserved = 0
		item.debug.last_cross_floor_seed_count = 0
		return 0
	end
	local store = ensure_store()
	local n = 0
	for _, record in pairs(store.records) do
		local key = seed_key(record.identity and record.identity.init_seed)
		if key and keep[key] then
			if promote_cross_floor_record(record) then n = n + 1 end
		end
	end
	item.debug.last_event = "cross-floor preserve: "..tostring(n)
	item.debug.last_cross_floor_preserved = n
	item.debug.last_cross_floor_seed_count = count(keep)
	return n
end

local function promote_entity_records(ent)
	if ent == nil then return 0 end
	local data = safe_get_data(ent)
	local names = data and get_runtime_names_from_data(data) or nil
	if not names then return 0 end
	local store = ensure_store()
	local n = 0
	for _, raw_id in pairs(names) do
		local record = store.records[tostring(raw_id)]
		if record and promote_cross_floor_record(record) then n = n + 1 end
	end
	return n
end

--- 搬家盒打包前：房间里已登记实体即将被 Remove，此时盒内向量可能还是空的，必须先 promote
--- 不能只扫 runtime.tracked：进房 clear_claims 后若尚未 try_check，tracked 可能为空
function item.promote_tracked_before_moving_box_pack()
	local n = 0
	local seen = {}
	local function visit(ent)
		if ent == nil then return end
		local ptr = entity_ptr_hash(ent)
		if ptr and seen[ptr] then return end
		if ptr then seen[ptr] = true end
		local ok, exists = pcall(function() return ent:Exists() end)
		if ok and exists then n = n + promote_entity_records(ent) end
	end
	for _, ent in pairs(runtime.tracked_entities) do visit(ent) end
	pcall(function()
		for _, ent in ipairs(Isaac.GetRoomEntities()) do visit(ent) end
	end)
	item.debug.last_event = "moving-box pre-pack promote: "..tostring(n)
	item.debug.last_cross_floor_seed_count = count(cross_floor_seed_set())
	return n
end

--- 打包完成后：仍活着的实体说明没进盒，降回原 scope；已进盒的靠 seed 快照跨层
function item.reconcile_moving_box_after_use(packed)
	if packed then
		local store = ensure_store()
		local function demote_if_alive(ent)
			local ok, exists = pcall(function() return ent:Exists() and not ent:IsDead() end)
			if not (ok and exists) then return end
			local data = safe_get_data(ent)
			local names = data and get_runtime_names_from_data(data) or nil
			if not names then return end
			for _, raw_id in pairs(names) do
				demote_cross_floor_if_needed(store.records[tostring(raw_id)])
			end
		end
		for _, ent in pairs(runtime.tracked_entities) do demote_if_alive(ent) end
		pcall(function()
			for _, ent in ipairs(Isaac.GetRoomEntities()) do demote_if_alive(ent) end
		end)
	end
	item.preserve_cross_floor_records()
end

local function drop_stale_cross_floor_promotions(keep_seeds)
	keep_seeds = keep_seeds or {}
	if next(keep_seeds) == nil then
		-- 向量读空时绝不能当「全是孤儿」——会误删盒内/勿忘草记录
		item.debug.last_event = "cross-floor drop-stale skipped: empty keep"
		return 0
	end
	local store = ensure_store()
	local stale = {}
	for id, record in pairs(store.records) do
		if record._promoted_cross_floor then
			local key = seed_key(record.identity and record.identity.init_seed)
			if key == nil or keep_seeds[key] ~= true then
				table.insert(stale, id)
			end
		end
	end
	for _, id in ipairs(stale) do
		local record = store.records[id]
		if record then forget_cross_floor_seed(record.identity and record.identity.init_seed) end
		drop_record(id)
	end
	return #stale
end

local function process_removed_snapshot(snapshot)
	local store=ensure_store()
	local transfer_seeds=nil
	local function seeds()
		if transfer_seeds==nil then transfer_seeds=union_keep_seeds(collect_cross_floor_init_seeds()) end
		return transfer_seeds
	end
	for _,entry in ipairs(snapshot.entries or {}) do
		local ok,err=pcall(function()
			local record=store.records[entry.id]
			if record then
				local key=seed_key(record.identity and record.identity.init_seed)
				local in_transfer=key~=nil and seeds()[key]==true
				-- 搬家盒：PRE_USE 可能已 promote，此时向量仍空；勿因 not in_transfer 而 drop
				if record.retain_on_remove or in_transfer or record._promoted_cross_floor then
					record.data=auxi.deepCopy(entry.data) record.evidence=auxi.deepCopy(snapshot.evidence)
					if in_transfer or record._promoted_cross_floor then
						promote_cross_floor_record(record)
					end
				else drop_record(entry.id) end
			end
		end)
		if not ok then note_error("removed record "..tostring(entry.id),err) end
		runtime.pending_remove[entry.id]=nil
	end
end
local function sweep_removed_tracked_entities()
	-- Only entities actually registered with Consistance are inspected. This deliberately
	-- avoids MC_POST_ENTITY_REMOVE, whose userdata wrapper/ptr hash is not stable enough
	-- for cross-callback lookup and which would otherwise run for every short-lived tear.
	local removed={}
	for ptr,ent in pairs(runtime.tracked_entities) do
		local ok,exists=pcall(function() return ent:Exists() end)
		if not ok or not exists then table.insert(removed,ptr) end
	end
	for _,ptr in ipairs(removed) do
		local snapshot=runtime.tracked[ptr]
		runtime.tracked[ptr]=nil
		runtime.tracked_entities[ptr]=nil
		if snapshot then
			for _,entry in ipairs(snapshot.entries or {}) do release_record_claim(entry.id) runtime.pending_remove[entry.id]=true end
			local success,err=pcall(process_removed_snapshot,snapshot)
			if not success then note_error("removed tracked snapshot",err) end
		end
	end
end
function item.run_duplicate_spawn_test()
	if Game():GetRoom():GetFrameCount()==0 then item.debug.last_duplicate_test={ok=false,phase="room_frame_zero",record_ids={}} return false end
	local previous=item.debug.last_duplicate_test
	if previous and previous.record_ids then for _,id in ipairs(previous.record_ids) do drop_record(id) end end
	for _,ent in ipairs(runtime.duplicate_test_entities or {}) do
		local ok,exists=pcall(function() return ent:Exists() end)
		if ok and exists then pcall(function() ent:Remove() end) end
	end
	runtime.duplicate_test_entities={}
	local room=Game():GetRoom() local center=room:GetCenterPos()
	local left,right=center+Vector(-80,0),center+Vector(80,0)
	local seed=((tonumber(room:GetSpawnSeed()) or 1)+(tonumber(Game():GetFrameCount()) or 0))%2147483646+1
	local owner="_ConsistanceV2DuplicateTest_"..tostring(seed)
	local function spawn(pos)
		local ent=Game():Spawn(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COIN,pos,Vector.Zero,nil,CoinSubType.COIN_PENNY,seed)
		return ent and ent:ToPickup() or nil
	end
	local a,b=spawn(left),spawn(right)
	if not a or not b then item.debug.last_duplicate_test={ok=false,phase="spawn_failed",seed=seed,record_ids={}} return false end
	local da,db=safe_get_data(a),safe_get_data(b)
	da._Data=da._Data or {} db._Data=db._Data or {}
	da._Data[owner]={tag="LEFT"} db._Data[owner]={tag="RIGHT"}
	local id_a=item.try_hold_entity(a,owner,{one_room=true,consistance=true})
	local id_b=item.try_hold_entity(b,owner,{one_room=true,consistance=true})
	local original_seed_a,original_seed_b=a.InitSeed,b.InitSeed
	item.debug.last_duplicate_test={ok=nil,phase="waiting_remove",seed=seed,actual_a=original_seed_a,actual_b=original_seed_b,record_ids={id_a,id_b},original_removed_a=false,original_removed_b=false}
	runtime.duplicate_test_entities={a,b}
	a:Remove() b:Remove()
	local function rebuild_after_remove(attempt)
		local ok_a,exists_a=pcall(function() return a:Exists() end)
		local ok_b,exists_b=pcall(function() return b:Exists() end)
		local removed_a=not ok_a or not exists_a
		local removed_b=not ok_b or not exists_b
		item.debug.last_duplicate_test.original_removed_a=removed_a
		item.debug.last_duplicate_test.original_removed_b=removed_b
		local released=runtime.claims[tostring(id_a)]==nil and runtime.claims[tostring(id_b)]==nil and runtime.pending_remove[tostring(id_a)]~=true and runtime.pending_remove[tostring(id_b)]~=true
		item.debug.last_duplicate_test.records_released=released
		if not (removed_a and removed_b and released) then
			item.debug.last_duplicate_test.phase=(removed_a and removed_b) and "waiting_release" or "waiting_remove"
			if attempt<12 then delay_buffer.addeffe(function() rebuild_after_remove(attempt+1) end,{},1)
			else item.debug.last_duplicate_test.ok=false item.debug.last_duplicate_test.phase=(removed_a and removed_b) and "release_timeout" or "remove_timeout" end
			return
		end
		item.debug.last_duplicate_test.phase="rebuilding"
		local new_right,new_left=spawn(right),spawn(left)
		if not new_right or not new_left then item.debug.last_duplicate_test.ok=false item.debug.last_duplicate_test.phase="rebuild_spawn_failed" return end
		local ok_right=item.try_check_entity(new_right,owner)==true
		local ok_left=item.try_check_entity(new_left,owner)==true
		local dr,dl=safe_get_data(new_right),safe_get_data(new_left)
		local right_tag=dr and dr._Data and dr._Data[owner] and dr._Data[owner].tag
		local left_tag=dl and dl._Data and dl._Data[owner] and dl._Data[owner].tag
		item.debug.last_duplicate_test.ok=ok_right and ok_left and right_tag=="RIGHT" and left_tag=="LEFT" and original_seed_a==original_seed_b and new_right.InitSeed==new_left.InitSeed and new_right.InitSeed==original_seed_a
		item.debug.last_duplicate_test.phase="complete"
		item.debug.last_duplicate_test.restored_right=right_tag
		item.debug.last_duplicate_test.restored_left=left_tag
		item.debug.last_duplicate_test.check_right=ok_right
		item.debug.last_duplicate_test.check_left=ok_left
		item.debug.last_duplicate_test.rebuilt_seed_a=new_right.InitSeed
		item.debug.last_duplicate_test.rebuilt_seed_b=new_left.InitSeed
		runtime.duplicate_test_entities={new_right,new_left}
	end
	delay_buffer.addeffe(function() rebuild_after_remove(1) end,{},1)
	return true
end
function item.get_debug_snapshot()
	local store=ensure_store() local scopes={room=0,level=0,run=0} local retained,index_buckets,index_links,evidence_records=0,0,0,0 local evidence_groups={}
	for _,record in pairs(store.records) do
		scopes[record.scope]=(scopes[record.scope] or 0)+1
		if record.retain_on_remove then retained=retained+1 end
		if record.evidence_enabled then evidence_records=evidence_records+1 evidence_groups[tostring(record.fingerprint).."|"..tostring(record.owner)]=true end
	end
	for _,ids in pairs(store.index) do index_buckets=index_buckets+1 index_links=index_links+#ids end
	return {schema_version=store.schema_version,records=count(store.records),index_buckets=index_buckets,index_links=index_links,claims=count(runtime.claims),pending_remove=count(runtime.pending_remove),room=scopes.room or 0,level=scopes.level or 0,run=scopes.run or 0,retained=retained,orphans=count(store.migration_orphans),evidence_records=evidence_records,evidence_groups=count(evidence_groups),errors=item.debug.errors,parameter_conflicts=item.debug.parameter_conflicts,ambiguous_matches=item.debug.ambiguous_matches,similarity_resolutions=item.debug.similarity_resolutions,ambiguous_fallbacks=item.debug.ambiguous_fallbacks,last_error=item.debug.last_error,last_event=item.debug.last_event}
end
function item.run_integrity_audit()
	local store=ensure_store()
	local failures={}
	local failure_count=0
	local function fail(message) failure_count=failure_count+1 if #failures<20 then table.insert(failures,message) end end
	local indexed={}
	for fp,ids in pairs(store.index) do
		for _,raw_id in ipairs(ids) do
			local id=tostring(raw_id) local record=store.records[id]
			if not record then fail("dangling index "..id)
			elseif record.fingerprint~=fp then fail("wrong bucket "..id)
			elseif indexed[id] then fail("duplicate index "..id)
			else indexed[id]=true end
		end
	end
	for id,record in pairs(store.records) do
		if not indexed[tostring(id)] then fail("unindexed record "..tostring(id)) end
		if record.scope~="room" and record.scope~="level" and record.scope~="run" then fail("bad scope "..tostring(id)) end
	end
	for id in pairs(runtime.claims) do if not store.records[tostring(id)] then fail("dangling claim "..tostring(id)) end end
	for id in pairs(runtime.pending_remove) do if not store.records[tostring(id)] then fail("dangling pending "..tostring(id)) end end
	local report={ok=failure_count==0,failure_count=failure_count,failures=failures,records=count(store.records),index_links=0,frame=Game():GetFrameCount()}
	for _,ids in pairs(store.index) do report.index_links=report.index_links+#ids end
	item.debug.last_report=report item.debug.last_event="integrity audit"
	return report
end
function item.check_table()
	local s=item.get_debug_snapshot()
	print(string.format("Consistance V%d records=%d buckets=%d claims=%d pending=%d room=%d level=%d run=%d retained=%d errors=%d",s.schema_version,s.records,s.index_buckets,s.claims,s.pending_remove,s.room,s.level,s.run,s.retained,s.errors))
end

table.insert(item.pre_myToCall,{CallBack=enums.Callbacks.PRE_GAME_STARTED,params=nil,Function=function(_,continue)
	item.reset_debug_stats() clear_claims() if not continue then save.elses.Consistance_holder=new_store() end local store=ensure_store() rebuild_index(store) item.debug.last_event=continue and "continued run initialized" or "new run initialized"
end})
table.insert(item.pre_myToCall,{CallBack=enums.Callbacks.PRE_NEW_ROOM,params=nil,Function=function() clear_claims() cleanup_scope("room") end})
-- 新层 PRE_NEW_ROOM 阶段尽早 preserve（勿忘草向量可能在实体生成后被清空）
table.insert(item.pre_myToCall,{CallBack=enums.Callbacks.PRE_PRE_NEW_LEVEL,params=nil,Function=function()
	item.preserve_cross_floor_records()
end})
table.insert(item.pre_myToCall,{CallBack=enums.Callbacks.PRE_NEW_LEVEL,params=nil,Function=function()
	-- 换层：keep = 当前向量 ∪ 打包时记下的 InitSeed；向量读空时不删 promote
	clear_claims()
	local live = collect_cross_floor_init_seeds()
	local keep = union_keep_seeds(live)
	local dropped = drop_stale_cross_floor_promotions(keep)
	item.preserve_cross_floor_records()
	cleanup_scope("level")
	item.debug.last_event = string.format("new-level keep=%d dropped=%d", count(keep), dropped)
end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_POST_UPDATE,params=nil,Function=function()
	if not item[item.own_key.."filter"] and Game():GetRoom():GetFrameCount()>0 then sweep_removed_tracked_entities() end
end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_POST_NEW_ROOM,params=nil,Function=function() item[item.own_key.."filter"]=nil end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_USE_ITEM,params=CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS,Function=function() item[item.own_key.."filter"]=true item.debug.last_event="glowing hourglass filter enabled" end})
-- 搬家盒：打包前先 promote；USE 后对仍存活实体 demote，并刷新 seed 快照
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_PRE_USE_ITEM,params=CollectibleType.COLLECTIBLE_MOVING_BOX,Function=function()
	local empty = true
	pcall(function()
		for i = 0, Game():GetNumPlayers() - 1 do
			local vec = Game():GetPlayer(i):GetMovingBoxContents()
			if vec and #vec > 0 then empty = false break end
		end
	end)
	item[item.own_key.."moving_box_was_empty"] = empty
	if empty then
		item.promote_tracked_before_moving_box_pack()
	else
		item.preserve_cross_floor_records()
	end
end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_USE_ITEM,params=CollectibleType.COLLECTIBLE_MOVING_BOX,Function=function()
	local packed = item[item.own_key.."moving_box_was_empty"] == true
	item[item.own_key.."moving_box_was_empty"] = nil
	item.reconcile_moving_box_after_use(packed)
end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_PRE_GAME_EXIT,params=nil,Function=function() cleanup_scope("room") clear_claims() end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_POST_GAME_END,params=nil,Function=function(_,shouldsave) clear_claims() if not shouldsave then save.elses.Consistance_holder=new_store() end end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_EXECUTE_CMD,params=nil,Function=function(_,str,params)
	if string.lower(str)=="meus" and params~=nil then local command=tostring(params):match("^%s*(%S+)") if command=="check" then item.check_table() end end
end})

return item

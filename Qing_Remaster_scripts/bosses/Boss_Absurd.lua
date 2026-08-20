local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sprite_regions = require("Qing_Remaster_scripts.bosses.sprite_regions")
local PathFinding = require("Qing_Remaster_scripts.bosses.Path_Finding")

local item = {
	ToCall = {},
	entity = enums.Enemies.Absurd,
	own_key = "Boss_Absurd_",
	base_skeleton = {
		length = 700, -- 总长度
		segmentCount = 40, -- 分段数量
		thickness = 24, -- 基础厚度
		wiggleFactor = 0.5, -- 摆动幅度
	},
	base_skin = {
		patchDensity = 5, -- 每段贴图密度
	},
	Yid2scale = {
		{frame = -1,val = 15,},
		{frame = 0,val = 20,},
		{frame = 1,val = 25,},
	},
	i2alpha = {
		{frame = 0,val = 1,},
		{frame = 30,val = 1,},
		{frame = 40,val = 0,},
	},
	Index2rnd = {
		{frame = 0,val = 0.35,},
		{frame = 10,val = 0.25,},
		{frame = 30,val = 0.1,},
		{frame = 33,val = 0,},
	},
	MoveAction = {
		[1] = {
			{frame = 0,Z = -10,S = 5,P = 0,},
			{frame = 3,Z = 0,S = 8,P = 0,},
			{frame = 10,Z = 60,S = 16,P = 2,},
			{frame = 15,Z = 200,S = 24,P = 4,},
			{frame = 30,Z = 250,S = 8,P = 6,},
			{frame = 40,Z = 250,S = 0,P = 6,},
			{frame = 45,Z = 240,S = 4,P = 4,},
			{frame = 55,Z = 200,S = 16,P = 4,},
			{frame = 60,Z = 60,S = 24,P = 2,},
			{frame = 67,Z = 0,S = 16,P = 0,},
			{frame = 70,Z = -10,S = 3,P = 15,},
			total = 70,
		},
		[2] = {
			{frame = 0,Z = -10,S = 3,P = 10,},
			total = 30,
		},
	},
	PosWeight = {
		[1] = {
			DISTANCE_FROM_PLAYER = {
				{frame = 0,value = -2,},
				{frame = 100,value = -0.75,},
				{frame = 150,value = 0,},
				{frame = 300,value = 0.5,},
				{frame = 500,value = 2.5,},
			},
			DISTANCE_FROM_ENT = {
				{frame = 0,value = -2,},
				{frame = 60,value = -1.5,},
				{frame = 120,value = -1,},
				{frame = 200,value = -0.5,},
				{frame = 400,value = 0.25,},
				{frame = 1000,value = 1,},
			},
			PATH_SAFETY = 0.6,            -- 路径安全性
			CENTER_AVOID = -0.8,          -- 避免房间中心
			WALL_DISTANCE = {
				{frame = 0,value = -1,},
				{frame = 1,value = -0.5,},
				{frame = 2,value = 0,},
				{frame = 4,value = 0.5,},
				{frame = 6,value = 0,},
				{frame = 8,value = -0.25,},
			},           -- 与墙壁保持适当距离
		},
	},
}

local sn = Sprite() sn:Load("gfx/boss/Absurd/global.anm2",true) 
-- 初始化骨架
function item.init_skeleton(ent,tbl)
	tbl = tbl or auxi.deepCopy(item.base_skeleton)
	tbl.segments = tbl.segments or {}
    for i = 1, tbl.segmentCount do
        tbl.segments[i] = {
            position = ent.Position, --+ Vector(0, (i-1) * (tbl.length/tbl.segmentCount)), -- 初始位置
            direction = Vector(0, 1), -- 初始方向
            thickness = tbl.thickness * (1 + 0.2 * math.sin(i/3)), -- 厚度变化
			Zoffset = Vector(0,0),
        }
    end
	return tbl
end

-- 为每个骨架段生成皮肤贴图
function item.generateForSegment(ent,skeleton,skin,segment,index,last_info)
    local patches = {}
    local circumference = 2 * math.pi * segment.thickness
    
	local fid = ent.FrameCount
    for i = 1, skin.patchDensity do
        local angle = (i-1) * (2*math.pi/skin.patchDensity) + 3 * index/180 * math.pi
		local texture = ((last_info[index - 1] or {})[i] or {}).texture
		if texture == nil or (auxi.random_1() < auxi.check_lerp(index,item.Index2rnd).val) then 
			texture = item.id_texture(math.floor((fid * 0.35 + index * 0.75)) % 12 + 1) 
		end
        local patch = {
            position = segment.position - segment.Zoffset,
			Zoffset = segment.Zoffset,
            pos2 = Vector(math.cos(angle), math.sin(angle)) * segment.thickness,
            texture = texture,
            direction = segment.direction,
			normal = Vector(math.cos(angle), math.sin(angle)), -- 法线方向
            uv = Vector((i-1)/skin.patchDensity, index/skeleton.segmentCount) -- UV坐标
        }
        patches[i] = patch
    end
    
    return patches
end

function item.is_suitable_Zoffset(val)
	if val >= 0 and val <= 60 then return true 
	else return false end
end

function item.move_in_dpos(data)
	local tbl = {}
	local mcnt = 30
	local mxn = math.ceil(data[#data].dpos/mcnt)
	for i = 1,mxn do
		local mvinfo = auxi.check_lerp(i * mcnt,data,"dpos")
		if item.is_suitable_Zoffset(mvinfo.Zoffset.Y) then
			table.insert(tbl,mvinfo.position)
		end
	end
	return tbl
end

local function normalize_score(score, all_scores)
    local min_score = math.min(table.unpack(all_scores))
    local max_score = math.max(table.unpack(all_scores))
    if max_score == min_score then return 0.5 end  -- 避免除零
    return (score - min_score) / (max_score - min_score)
end

local function filter_candidates(tg, method, threshold_or_k)
    if method == "top_k" then
        table.sort(tg, function(a, b) return a.weigh > b.weigh end)
        return {table.unpack(tg, 1, math.min(threshold_or_k, #tg))}
    else -- "threshold"
        local filtered = {}
        for _, candidate in ipairs(tg) do
            if candidate.weigh >= threshold_or_k then
                table.insert(filtered, candidate)
            end
        end
        return filtered
    end
end

local function softmax_weights(tg, temperature)
    temperature = temperature or 1.0  -- 默认温度=1
    local exp_sum = 0
    local max_score = -math.huge
    for _, candidate in ipairs(tg) do
        max_score = math.max(max_score, candidate.weigh)
    end
    for _, candidate in ipairs(tg) do
        candidate.exp = math.exp((candidate.weigh - max_score) / temperature)
        exp_sum = exp_sum + candidate.exp
    end
    for _, candidate in ipairs(tg) do
        candidate.weigh = math.ceil(candidate.exp / exp_sum * 500)
    end
    return tg
end

function item.electposition(ent,WEIGHTS,params)
	params = params or {}
	local tg = params.tg or auxi.get_acceptible_target(ent)
	local tgpos = params.tgpos or tg.Position
	local desiredDistance = 240
	
	-- 计算远离玩家的方向
	local retreatDir = (ent.Position - tgpos):Normalized()
	local retreatPos = Game():GetRoom():GetClampedPosition(tgpos + retreatDir * desiredDistance,20)

	local room = Game():GetRoom()
	local width = room:GetGridWidth()
	local height = room:GetGridHeight()
	local bestPos = retreatPos  -- 默认回退位置
	
	-- 权重计算参数
	WEIGHTS = WEIGHTS or auxi.deepCopy(item.PosWeight[1])
	if params.posweight then 
		for u,v in pairs(params.posweight) do
			WEIGHTS[u] = auxi.deepCopy(v)
		end
	end
	
	local tg = {}

	-- 采样房间内可通行点
	for i = 0, width - 1 do
		for j = 0, height - 1 do
			local idx = i + j * width
			local gridPos = room:GetGridPosition(idx)
			local gent = room:GetGridEntity(idx)
			
			-- 只考虑可通行的格子
			if (not gent or gent.CollisionClass == GridCollisionClass.COLLISION_NONE) then
				-- 计算各项权重
				local score = 0
				
				-- 远离玩家权重
				local distToPlayer = (gridPos - tgpos):Length()
				score = score + auxi.check_lerp(distToPlayer,WEIGHTS.DISTANCE_FROM_PLAYER).value

				-- 距离本体权重
				local distToEnt = (gridPos - (params.entpos or ent.Position)):Length()
				score = score + auxi.check_lerp(distToEnt,WEIGHTS.DISTANCE_FROM_ENT).value
				
				if WEIGHTS.PATH_SAFETY ~= 0 then
					-- 2. 路径安全性(到当前位置是否有畅通路径)
					local path = PathFinding:FindPath(
						room:GetGridIndex(ent.Position),
						idx,
						{PassCheck = function(i) return PathFinding:CanPass(i) end}
					)
					if path and #path > 0 then
						score = score + WEIGHTS.PATH_SAFETY * (1 - (#path / 100))
					end
				end
				
				-- 3. 避免房间中心
				local roomCenter = room:GetCenterPos()
				local centerDist = (gridPos - roomCenter):Length()
				score = score + (centerDist / 100) * WEIGHTS.CENTER_AVOID
				
				-- 4. 与墙壁保持适当距离
				local wallDist = auxi.GetMinWallDistance(gridPos)
				score = score + auxi.check_lerp(wallDist,WEIGHTS.WALL_DISTANCE).value
				
				table.insert(tg, {pos = gridPos, weigh = score})  -- 注意：此处直接使用 score
			end
		end
	end
	
	-- 改进部分：标准化 + 筛选 + 柔性权重
    if #tg > 0 then
        -- 1. 标准化分数到 [0,1]
        local all_scores = {}
        for _, candidate in ipairs(tg) do
            table.insert(all_scores, candidate.weigh)
        end
        for _, candidate in ipairs(tg) do
            candidate.weigh = normalize_score(candidate.weigh, all_scores)
        end

        -- 2. 筛选候选（例如保留前 10% 或分数 >0.7）
        local filtered = filter_candidates(tg, "threshold", 0.7)

        -- 3. 转换为概率分布（温度越高越均匀）
        if #filtered > 0 then
            softmax_weights(filtered, 0.5)  -- 温度=0.5 强化高分差异
            bestPos = auxi.random_in_weighed_table(filtered)
			bestPos = bestPos.pos
        end
    end

    return bestPos
end

function item.updateSkeleton(ent,skeleton,mvinfo,params)
	params = params or {}
	mvinfo = mvinfo or {P = 0,}
	skeleton.segmentdata = skeleton.segmentdata or {}
	local prevdata = skeleton.segmentdata[1] or skeleton.segments[1]
	local dleg = (prevdata.position - skeleton.segments[1].position):Length() + (prevdata.Zoffset - skeleton.segments[1].Zoffset):Length()
	local rleg = (prevdata.position - skeleton.segments[1].position):Length()
	if true then --(#skeleton.segmentdata == 0) or (dleg > 0.1) then
		table.insert(skeleton.segmentdata,1,{position = skeleton.segments[1].position,direction = skeleton.segments[1].direction,Zoffset = skeleton.segments[1].Zoffset,frame = 0,dpos = 0,})
		for i = #skeleton.segmentdata,2,-1 do
			skeleton.segmentdata[i].frame = skeleton.segmentdata[i].frame + dleg + mvinfo.P + (params.P or 0)
			skeleton.segmentdata[i].dpos = skeleton.segmentdata[i].dpos + rleg
			if (skeleton.segmentdata[i].frame > skeleton.length) and skeleton.segmentdata[i + 1] then 
				table.remove(skeleton.segmentdata,i + 1)
			end
		end
	end
    -- 传播运动到后续段
    for i = 2, skeleton.segmentCount do
        local prevSeg = skeleton.segments[i-1]
        local currSeg = skeleton.segments[i]
        
        -- 添加一些随机摆动
        local wiggle = Vector(
            math.random() * skeleton.wiggleFactor * 2 - skeleton.wiggleFactor,
            math.random() * skeleton.wiggleFactor * 2 - skeleton.wiggleFactor
        )
        
		local idx = i * (skeleton.length/skeleton.segmentCount)
		local iinfo = auxi.check_lerp(idx,skeleton.segmentdata)
		currSeg.direction = iinfo.direction
		currSeg.position = iinfo.position
		currSeg.Zoffset = iinfo.Zoffset
        --currSeg.direction = (prevSeg.position - currSeg.position + wiggle):Normalized()
        --currSeg.position = prevSeg.position - currSeg.direction * (skeleton.length/skeleton.segmentCount)
    end
    
    -- 更新皮肤贴图
	skeleton.skin = skeleton.skin or {}
    skeleton.skin.texturePatches = skeleton.skin.texturePatches or {}
    for i = skeleton.segmentCount,1,-1 do
        skeleton.skin.texturePatches[i] = item.generateForSegment(ent,skeleton,skeleton.skininfo or item.base_skin,skeleton.segments[i],i,skeleton.skin.texturePatches)
    end
	skeleton.updated = true
end

function item.updateBoss(ent,skeleton)
	local tg = auxi.get_acceptible_target(ent)
	local tgpos = tg.Position
    -- 更新头部运动
	local d = ent:GetData()
	d[item.own_key.."actinfo"] = d[item.own_key.."actinfo"] or {id = 1,cnt = 0,}
	d[item.own_key.."actinfo"].cnt = d[item.own_key.."actinfo"].cnt + 1
	if d[item.own_key.."actinfo"].cnt > item.MoveAction[d[item.own_key.."actinfo"].id].total then 
		d[item.own_key.."actinfo"].id = auxi.choose(1,2) 
		d[item.own_key.."actinfo"].cnt = 1 
	end
	if d[item.own_key.."actinfo"].id == 1 then 
		if d[item.own_key.."actinfo"].cnt == 1 then
			skeleton.segments[1].position = item.electposition(ent,nil,{posweight = {
				DISTANCE_FROM_ENT = {
					{frame = 0,value = 0,},
				},
			}})
			d[item.own_key.."actinfo"].electTarget = item.electposition(ent,nil,{entpos = skeleton.segments[1].position,posweight = {
				DISTANCE_FROM_PLAYER = {
					{frame = 0,value = 2,},
					{frame = 100,value = 0.75,},
					{frame = 150,value = 0,},
					{frame = 300,value = -0.5,},
					{frame = 500,value = -1,},
				},
				DISTANCE_FROM_ENT = {
					{frame = 0,value = -4,},
					{frame = 60,value = -3,},
					{frame = 120,value = -2,},
					{frame = 200,value = -1,},
					{frame = 400,value = 0,},
					{frame = 1000,value = 1,},
				},
				CENTER_AVOID = -0.2,
			}})
		end
		if d[item.own_key.."actinfo"].cnt == 30 then
			d[item.own_key.."actinfo"].electTarget = tgpos
		end
		if d[item.own_key.."actinfo"].cnt == 40 then
			local q = Isaac.Spawn(9,0,0,ent.Position,(tg.Position - ent.Position):Normalized() * 4,ent):ToProjectile()
			local qd = q:GetData() qd[item.own_key.."effect"] = item.init_skeleton(q,{
				skininfo = {
					patchDensity = 1,
				},
				length = 60, -- 总长度
				segmentCount = 6, -- 分段数量
				thickness = 10, -- 基础厚度
				wiggleFactor = 0.2, -- 摆动幅度
			})
			qd[item.own_key.."einfo"] = {Zoffset = auxi.ProtectVector(skeleton.segments[1].Zoffset),}
		end
		tgpos = d[item.own_key.."actinfo"].electTarget 
	end
    skeleton.segments[1].direction = (tgpos - skeleton.segments[1].position):Normalized()

	local mvaction = item.MoveAction[d[item.own_key.."actinfo"].id]
	local mvinfo = auxi.check_lerp(d[item.own_key.."actinfo"].cnt,mvaction)

    skeleton.segments[1].Zoffset = Vector(0,mvinfo.Z)
    skeleton.segments[1].position = skeleton.segments[1].position + skeleton.segments[1].direction * mvinfo.S
	ent.Position = skeleton.segments[1].position
	ent.Velocity = Vector(0,0)
	if item.is_suitable_Zoffset(skeleton.segments[1].Zoffset.Y) then ent.EntityCollisionClass = 4
	else ent.EntityCollisionClass = 0 end

	item.updateSkeleton(ent,skeleton,mvinfo)

	local dinfo = item.move_in_dpos(skeleton.segmentdata)
	d[item.own_key.."hitboxs"] = d[item.own_key.."hitboxs"] or {}
	if #dinfo < #d[item.own_key.."hitboxs"] then 
		for i = #d[item.own_key.."hitboxs"],#dinfo + 1,-1 do
			local q = d[item.own_key.."hitboxs"][i]
			q:Remove()
			d[item.own_key.."hitboxs"][i] = nil
		end
	end
	for i = 1,#dinfo do
		local ipos = dinfo[i]
		if not auxi.check_all_exists(d[item.own_key.."hitboxs"][i]) then
			if d[item.own_key.."hitboxs"][i] and d[item.own_key.."hitboxs"][i]:Exists() then d[item.own_key.."hitboxs"][i]:Remove() end
			local q = Isaac.Spawn(996,item.entity,1,ipos,Vector(0,0),ent):ToNPC() q:ClearEntityFlags(EntityFlag.FLAG_APPEAR) q:AddEntityFlags(EntityFlag.FLAG_DONT_COUNT_BOSS_HP)
			d[item.own_key.."hitboxs"][i] = q
		end
		local q = d[item.own_key.."hitboxs"][i]
		q.Position = ipos
		q.Velocity = Vector(0,0)
	end
end

function item.renderBoss(ent,skeleton)
	if not skeleton.updated then return end
	--local bpos = Isaac.WorldToScreen(ent.Position + ent.PositionOffset)
    for i, segmentPatches in ipairs(skeleton.skin.texturePatches) do
        for j, patch in ipairs(segmentPatches) do
			local rpos = Isaac.WorldToScreen(patch.position + patch.pos2 + ent.PositionOffset)
            local ifinfo = patch.texture or item.random_texture() local info = ifinfo.info
			sn:ReplaceSpritesheet(0,ifinfo.name) sn:LoadGraphics() sn:SetFrame("GlobalFrames_0",0) 
			local dir = patch.direction:GetAngleDegrees()
			local sc = auxi.check_lerp(auxi.get_by_rotate(patch.pos2,-dir).X,item.Yid2scale).val
			local c = auxi.check_lerp(i,skeleton.alphainfo or item.i2alpha).val
			sn.Scale = Vector(sc/(info.r - info.l),sc/(info.b - info.t))
			sn.Color = Color(1,1,1,c)
			sn.Rotation = dir
			local ipos2 = auxi.get_by_rotate(- Vector((info.x + (info.r + info.l) * 0.5) * sn.Scale.X,(info.y + (info.b + info.t) * 0.5) * sn.Scale.Y),sn.Rotation)
			if patch.Zoffset.Y >= 0 then 
				sn:Render(rpos + ipos2,Vector(info.x + info.l,info.y + info.t),Vector(1200 - info.x - info.r,1200 - info.y - info.b))
			end
        end
    end
end

function item.get_texture(rnd)
	local path = sprite_regions.pid_to_path[rnd[1]]
	if path:sub(1,1) == "/" then path = "gfx".. path
	else path = "gfx/".. path end
	local ret = {name = path,info = sprite_regions.sprite_regions[rnd[1]][rnd[2]],rnd = rnd,}
	return ret
end

function item.id_texture(id)
	local rnd = auxi.choose2(sprite_regions.color_index.hue_groups[id]) or {1,1}
	return item.get_texture(rnd)
end

function item.random_texture()
	local rnd = auxi.choose2(sprite_regions.color_index.all_frames)
	return item.get_texture(rnd)
end


table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_NPC_COLLISION, params = 996,
Function = function(_,ent,col,low)
	if ent.Variant == item.entity and (col.Type == 996 and col.Variant == item.entity) then
		return true
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 996,
Function = function(_,ent,amt,flag,source,cooldown)
	if ent.Variant == item.entity and ent.SubType == 1 then
		if auxi.check_all_exists(ent.SpawnerEntity) and ent.SpawnerEntity.Type == 996 and ent.SpawnerEntity.Variant == item.entity and ent.SpawnerEntity.SubType == 0 then
			ent.SpawnerEntity:TakeDamage(amt,flag,source,cooldown)
			return false
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PROJECTILE_UPDATE, params = nil,
Function = function(_,ent,offset)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d[item.own_key.."effect"] then
		ent.Height = -24
		ent.FallingAcceleration = 0
		local skeleton = d[item.own_key.."effect"]
		skeleton.segments[1].Zoffset = d[item.own_key.."einfo"].Zoffset
		d[item.own_key.."einfo"].Zvel = (d[item.own_key.."einfo"].Zvel or 0) + (d[item.own_key.."einfo"].Zavel or (Zavel or 3))
		d[item.own_key.."einfo"].Zoffset = Vector(0,math.max(0,d[item.own_key.."einfo"].Zoffset.Y - d[item.own_key.."einfo"].Zvel))
		if d[item.own_key.."einfo"].Zoffset.Y < 60 then ent.EntityCollisionClass = 4 else ent.EntityCollisionClass = 0 end
		if d[item.own_key.."einfo"].Zoffset.Y <= 0 then
            -- 反向速度并衰减（弹起）
            d[item.own_key.."einfo"].Zvel = -d[item.own_key.."einfo"].Zvel * 0.6  -- 衰减系数
            d[item.own_key.."einfo"].Zoffset = Vector(0, 0)
            
            -- 如果速度过小，停止弹跳
            if math.abs(d[item.own_key.."einfo"].Zvel) < 1 then
                d[item.own_key.."einfo"].Zvel = 0
                d[item.own_key.."einfo"].Zavel = 0
            end
        end
		ent.Color = Color(0,0,0,0)
    	skeleton.segments[1].position = ent.Position
		skeleton.segments[1].direction = ent.Velocity:Normalized()
		item.updateSkeleton(ent,skeleton)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PROJECTILE_RENDER, params = nil,
Function = function(_,ent,offset)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d[item.own_key.."effect"] then
		item.renderBoss(ent,d[item.own_key.."effect"])
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = 996,
Function = function(_,ent,offset)
	if ent.Variant == item.entity and ent.SubType == 0 then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local anim = s:GetAnimation()
		local frame = s:GetFrame()
		local rpos = Isaac.WorldToScreen(ent.Position + ent.PositionOffset)
		d[item.own_key.."skeleton"] = d[item.own_key.."skeleton"] or item.init_skeleton(ent)
		item.renderBoss(ent,d[item.own_key.."skeleton"])
		
		if true then return end
		d[item.own_key.."sinfo"] = d[item.own_key.."sinfo"] or {}
		for i = 1,30 do
			local ifinfo = d[item.own_key.."sinfo"][i] or item.random_texture() local info = ifinfo.info
			sn:ReplaceSpritesheet(0,ifinfo.name) sn:LoadGraphics() sn:SetFrame("GlobalFrames_0",0) 
			sn.Scale = Vector(20/(info.r - info.l),20/(info.b - info.t))
			local ipos2 = - Vector((info.x + (info.r + info.l) * 0.5) * sn.Scale.X,(info.y + (info.b + info.t) * 0.5) * sn.Scale.Y)
			if not (TEST_DONT_RENDER or {})[i] then
				sn:Render(rpos + Vector(i * 10 - 30 * 10 * 0.5,0) + ipos2,Vector(info.x + info.l,info.y + info.t),Vector(1200 - info.x - info.r,1200 - info.y - info.b))
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity and ent.SubType == 0 then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local anim = s:GetAnimation()
		local frame = s:GetFrame()
		d[item.own_key.."skeleton"] = d[item.own_key.."skeleton"] or item.init_skeleton(ent)
		item.updateBoss(ent,d[item.own_key.."skeleton"])
		
		if true then return end
		d[item.own_key.."sinfo"] = d[item.own_key.."sinfo"] or {}
		if ent.FrameCount % 30 == 1 then
			for i = 1,30 do
				d[item.own_key.."sinfo"][i] = item.id_texture(1 + (math.floor(ent.FrameCount/30) % 15))
				print(d[item.own_key.."sinfo"][i].name.." "..d[item.own_key.."sinfo"][i].rnd[1].." "..d[item.own_key.."sinfo"][i].rnd[2])
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
	end
end,
})

return item

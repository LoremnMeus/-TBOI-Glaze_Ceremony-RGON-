local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local AI = require("Qing_Remaster_scripts.bosses.Boss_All")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local Color_holder = require("Qing_Remaster_scripts.others.Color_cross_holder")
local Dialog_holder = require("Qing_Remaster_scripts.others.Dialog_holder")
local Nil = require("Qing_Remaster_scripts.others.Nil_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Damage_holder = require("Qing_Remaster_scripts.others.Damage_holder")
local Boss_Sprite_holder = require("Qing_Remaster_scripts.others.Boss_Sprite_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local grid_doors = require("Qing_Remaster_scripts.grids.grid_doors")
local qing_knife = require("Qing_Remaster_scripts.bosses.Boss_Qing_knife")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")

local item = {
	ToCall = {},
	entity = enums.Enemies.Boss_Qing,
	own_key = "Boss_Qing_",
	Swapper = {
		["Appear"] = "Idle",
		["Attack4"] = "Fire4",
		["Attack4Back"] = "Idle",
	},
	Air_Swapper = {
		["Appear"] = "Idle",
		["Charge"] = "Idle",
	},
	AnimInfo = {
		["Appear"] = {
			{frame = 0,offset = -800,},
			{frame = 5,offset = -200,},
			{frame = 10,offset = -50,},
			{frame = 15,offset = -30,},
			{frame = 20,offset = -20,},
			total = 25,
		},
		["Idle"] = {
			{frame = 0,offset = -20,},
			{frame = 5,offset = -25,},
			{frame = 10,offset = -18,},
			{frame = 15,offset = -20,},
			total = 20,
		},
		["Attack1"] = {
			{frame = 0,offset = -20,},
			{frame = 5,offset = -10,},
			{frame = 10,offset = -25,},
			{frame = 15,offset = -20,},
			total = 20,
		},
		["Attack2"] = {
			{frame = 0,offset = -20,},
			{frame = 5,offset = -10,},
			{frame = 10,offset = -25,},
			{frame = 15,offset = -20,},
			{frame = 28,offset = -25,},
			{frame = 33,offset = -10,},
			{frame = 40,offset = -20,},
		},
		["Attack3"] = {
			{frame = 0,offset = -20,},
			{frame = 5,offset = -10,},
			{frame = 10,offset = -25,},
			{frame = 15,offset = -20,},
			{frame = 28,offset = -25,},
			{frame = 33,offset = -10,},
			{frame = 40,offset = -20,},
		},
		["Break"] = {
			{frame = 0,offset = -20,},
			{frame = 5,offset = -50,},
			{frame = 10,offset = -70,},
			{frame = 15,offset = -60,},
		},
		["Attack4"] = {
			{frame = 0,offset = -20,},
			{frame = 5,offset = -10,},
			{frame = 10,offset = -25,},
			{frame = 15,offset = -20,},
		},
		["Fire4"] = {
			{frame = 0,offset = -20,},
			{frame = 2,offset = -22,},
			{frame = 4,offset = -20,},
			{frame = 6,offset = -22,},
			{frame = 8,offset = -20,},
			{frame = 10,offset = -22,},
			{frame = 12,offset = -20,},
			{frame = 14,offset = -22,},
		},
		["Attack4Back"] = {
			{frame = 0,offset = -20,},
			{frame = 5,offset = -25,},
			{frame = 10,offset = -10,},
			{frame = 15,offset = -20,},
		},
	},
	strategies = {				--攻击策略列表
		["Idle"] = {anim = "Idle",},
		["part_free"] = {anim = "Attack1",task = {["state"] = 1,["half"] = true,},},
		["switch_plan_A1"] = {anim = "Attack1",task = {["state"] = 1,},},
		["switch_plan_A2"] = {anim = "Attack2",task = {["state"] = 0,},},
		
		["attack_plan_A0"] = {anim = "Attack1",task = {["state"] = -1,},},
		["attack_plan_A1"] = {anim = "Attack1",task = {["state"] = 0,},},
		["attack_plan_A2"] = {anim = "Attack2",task = {["state"] = 2,},},
		["attack_plan_A3"] = {anim = "Attack2",task = {["state"] = 1,},},
		
		["Mode_Switch_1"] = {anim = "Attack1",task = {["state"] = 11,},},		--生成武器
		["Mode_Switch_2"] = {anim = "Attack1",task = {["state"] = 21,},},		--生成光剑
		["Mode_Switch_3"] = {anim = "Attack1",task = {["state"] = 22,},},		--光剑完全展开
		
		["attack_plan_B1"] = {anim = "Attack3",task = {["state"] = 1,},},		--三阶段
		["attack_plan_B2"] = {anim = "Attack3",task = {["state"] = 2,},},
		
		["attack_plan_C1"] = {anim = "Attack1",task = {["state"] = 101,},},		--四阶段
		["attack_plan_C2"] = {anim = "Attack1",task = {["state"] = 102,},},
		["attack_plan_C3"] = {anim = "Attack1",task = {["state"] = 103,},},
		
		["attack_plan_D1"] = {anim = "Attack4",task = {["state"] = 1,},},		--飞剑
	},
	Allow_Offset = {},
	num2color = {
		[1] = "gfx/boss/Qing/Air_Flig",
		[2] = "gfx/boss/Qing/Air_Devo",
		[3] = "gfx/boss/Qing/Air_Conv",
		[4] = "gfx/boss/Qing/Air_Lemo",
		[5] = "gfx/boss/Qing/Air_Panl",
	},
	num2realcolor = {
		[1] = Color(1,0,0,1,0.5,0,0),
		[2] = Color(0,1,0,1,0,0.5,0),
		[3] = Color(1,1,0,1,1,0.5,0),
		[4] = Color(0,1,1,1,0,0.5,1),
		[5] = Color(1,0.2,0.4,1,0.8,0,0.4),
	},
	base_pos = Vector(320,240),
	word_list = {
		zh = {
			[1] = {
				{
					"青？：",
					{word = "入侵者正在激烈反抗",color = Color(1,0,0,1),},
					{word = "正在接入武器组",color = Color(1,0,0,1),scaler = Vector(2,2),},
				},
			},
			[2] = {
				{
					"青？：",
					{word = "警告！痛觉神经过载..",color = Color(1,0,0,1),scaler = Vector(1.2,1.2),},
					{word = "接入蓝图系统",color = Color(0,0,1,1),scaler = Vector(2,2),},
				},
			},
			[3] = {
				{
					"青？：",
					{word = "警告！损毁警告！机体即将坠毁！",color = Color(1,0,0,1),scaler = Vector(2,2),},
					{word = "正在载入战斗模块",color = Color(0,1,0,1),scaler = Vector(2,2),},
				},
			},
			[4] = {
				{
					"青？：",
					{word = "你...你战胜了我...",color = Color(1,0,0,0.5),scaler = Vector(2,2),},
					{word = "阻止...琉璃...",color = Color(1,0,0,0.2),scaler = Vector(1,1),},
					{word = "快...",color = Color(1,0,0,0.1),scaler = Vector(0.5,0.5),},
				},
			},
			[5] = {
				{
					"青？：",
					{word = "正在申请最高战斗权限...",color = Color(1,0,0,1),scaler = Vector(2,2),},
					{word = "火力全开！！！！",color = Color(1,0,0,1),scaler = Vector(2,2),inner_step_multi = 8,},
				},
			},
		},
		en = {
			[1] = {
				{
					"Qing？：",
					{word = "The invaders are fiercely resisting",color = Color(1,0,0,1),},
					{word = "Attempt to access the weapon group",color = Color(1,0,0,1),scaler = Vector(2,2),},
					{word = "Success",color = Color(1,1,0,1),},
				},
			},
			[2] = {
				{
					"Qing?:",
					{word = "Warning!Pain sensing nervous system is overloaded",color = Color(1,0,0,1),scaler = Vector(1.2,1.2),},
					{word = "Attempt to access the Blue-Print System",color = Color(0,0,1,1),scaler = Vector(2,2),},
					{word = "Success",color = Color(1,1,0,1),},
				},
			},
			[3] = {
				{
					"Qing?:",
					{word = "Warning!Warning!",color = Color(1,0,0,1),scaler = Vector(2,2),},
					{word = "Attempt to load the combat module.",color = Color(0,1,0,1),scaler = Vector(2,2),},
				},
			},
			[4] = {
				{
					"Qing?:",
					{word = "You've defeated me...",color = Color(1,0,0,0.5),scaler = Vector(2,2),},
					{word = "Stop the Glaze...",color = Color(1,0,0,0.2),scaler = Vector(1,1),},
					{word = "Please...",color = Color(1,0,0,0.1),scaler = Vector(0.5,0.5),},
				},
			},
			[5] = {
				{
					"Qing?:",
					{word = "Accessing to Highest Level...",color = Color(1,0,0,1),scaler = Vector(2,2),},
					{word = "Fire!!!!",color = Color(1,0,0,1),scaler = Vector(3,3),inner_step_multi = 8,},
				},
			},
		},
	},
	weapon_offset = {
		Vector(-100,-80),
		Vector(-40,-120),
		Vector(40,-120),
		Vector(100,-80),
	},
	aim_info = {
		{frame = 1,val = 80,},
		{frame = 5,val = 50,},
		{frame = 10,val = 30,},
		{frame = 15,val = 15,},
		{frame = 20,val = 6,},
		{frame = 25,val = 2,},
		{frame = 28,val = 0,},
	},
	rocket_frame = 30,
	multi_slot_offset = {
		Vector(0,0),
		Vector(5,0),
		Vector(-5,0),
	},
	wing_info = {
		[1] = {pos = Vector(-5,-3),},
		[2] = {pos = Vector(-10,-4.5),delay = 1,},
		[3] = {pos = Vector(-15,-6),delay = 2,},
		[4] = {pos = Vector(5,-3),flip = -1,},
		[5] = {pos = Vector(10,-4.5),flip = -1,delay = 1,},
		[6] = {pos = Vector(15,-6),flip = -1,delay = 2,},
		
		[7] = {pos = Vector(-20,-7.5),delay = 3,},
		[8] = {pos = Vector(-25,-9.5),delay = 5,},
		[9] = {pos = Vector(-30,-11.5),delay = 7,},
		[10] = {pos = Vector(20,-7.5),flip = -1,delay = 3,},
		[11] = {pos = Vector(25,-9.5),flip = -1,delay = 5,},
		[12] = {pos = Vector(30,-11.5),flip = -1,delay = 7,},
	},
	decay_2_scale = {
		{frame = 0,val = 1,rotate_rate = 0,},
		{frame = 10,val = 3,rotate_rate = 0.6,},
		{frame = 13,val = 5.2,rotate_rate = 1.2,},
		{frame = 15,val = 5,rotate_rate = 1,},
		total = 15,
	},
	decay_back_info = {
		{frame = 0,c = 0,},
		{frame = 30,c = 1,},
	},
}

function item.get_air_texture(subtype, suffix)
	return (item.num2color[subtype] or item.num2color[1]) .. (suffix or ".png")
end

function item.get_word(id,force)
	local language = Options.Language
	if item.word_list[language] == nil then language = "zh" end
	if force then return auxi.copy(item.word_list[language][id]) end
	return item.word_list[language][id]
end

function item.random_pos(val)
	local tbl = {} local room = Game():GetRoom()
	for i = 1,val do table.insert(tbl,room:GetRandomPosition(40)) end
	return tbl
end

function item.start(ent)
	local music = MusicManager()
	if (music:GetCurrentMusicID() ~= enums.Music.Origin_1) then
		music:Play(enums.Music.Origin_1,0)
		music:UpdateVolume()
	end
	local tgs = auxi.getothers(996,item.entity)
	if #tgs == 0 and auxi.check_all_exists(ent) ~= true then 
		ent = Isaac.Spawn(996,item.entity,0,Game():GetRoom():GetCenterPos(),Vector(0,0),nil)
	else
		for i = 1,#tgs do tgs[i]:Remove() end
	end
	return ent
end

function item.all_set_to(d,val)		--item.all_set_to(d,1)		--将所有飞行器控制到轨道1
	--print("Set to "..tostring(val))
	for k = 1,#d[item.own_key.."effect"].air_list do for i = #d[item.own_key.."effect"].air_list[k],1,-1 do 
		if d[item.own_key.."effect"].air_list[k].skip_adder then break end
		local v = d[item.own_key.."effect"].air_list[k][i] 
		if v.ent and v.ent:GetData()[item.own_key.."effect"] then
			if v.ent:GetData()[item.own_key.."effect"].skip_adder then else 
				v.ent:GetData()[item.own_key.."effect"].air_list_id = val v.ent:GetData()[item.own_key.."effect"].shift_counter = 15
				if k ~= val and val and d[item.own_key.."effect"].air_list[val] then table.insert(d[item.own_key.."effect"].air_list[val],{ent = v.ent,}) end
			end
		end
	end end
end

function item.set_part_free(d,val)
	for i = #d[item.own_key.."effect"].air_list[1],1,-1 do 
		local v = d[item.own_key.."effect"].air_list[1][i] 
		if auxi.random_1() < (val or 0.5) then v.ent:GetData()[item.own_key.."effect"].air_list_id = nil end
	end
end

function item.generate_weapon(id,ent)
	local q = Isaac.Spawn(996,enums.Enemies.QingHelper2,id,ent.Position + (item.weapon_offset[id] or item.weapon_offset[1]) * 0.5,Vector(0,0),ent):ToNPC()
	local d = q:GetData() d[item.own_key.."effect"] = {linker = ent,}
	return q
end

function item.activate_weapon_task(tbl,params)
	params = params or {} local hp_rate = params.hp_rate or 1-- params.mode = 2
	if tbl.id == 1 then 
		tbl.ent:GetData()[item.own_key.."task"] = {multi = auxi.choose(3,4,5,6),base_counter = auxi.choose(20,30,40),mode = params.mode or 1,}
		if hp_rate < 0.5 then tbl.ent:GetData()[item.own_key.."task"].base_counter = auxi.choose(35,40) end
	end
	if tbl.id == 2 then 
		tbl.ent:GetData()[item.own_key.."task"] = {multi = auxi.choose(1,2,3),base_counter = 0,mode = params.mode or 1,}
	end
	if tbl.id == 3 then 
		tbl.ent:GetData()[item.own_key.."task"] = {multi = auxi.choose(1,2,3),base_counter = auxi.choose(20,30,40),mode = params.mode or 1,}
	end
	if tbl.id == 4 then 
		tbl.ent:GetData()[item.own_key.."task"] = {mode = params.mode or 1,}		--这个没有这些参数
	end
end

function item.check_word_(ent,id)
	local d = ent:GetData()
	if d[item.own_key.."word"..tostring(id)] == nil then 
		local data = item.get_word(id,true) d[item.own_key.."word"..tostring(id)] = true 
		for u,v in pairs(data) do Dialog_holder.add_word({data = v,header = {sprite_name = "WQing"},step_by = true,line_inside_delay = 30,}) end
	end
end

function item.calculate_hitbox(ent)
    local s = ent:GetSprite() local anim = s:GetAnimation() local scaler = 10
	if anim == "SpinUp" then scaler = 20 end
    local collision_boxes = qing_knife.get_collision_boxes_with_a_delay_frame(ent,scaler)
    if not collision_boxes then return end
    
    -- 弹开力度
    local knockbackStrength = 10
    
    -- 遍历所有玩家
    for playerNum = 1, Game():GetNumPlayers() do
        local player = Game():GetPlayer(playerNum - 1)
        local playerPos = player.Position
        local playerSize = player.Size
        
        -- 检查每个碰撞箱
        for _, box in ipairs(collision_boxes) do
            -- 计算玩家到碰撞箱中心的相对位置
            local relativePos = playerPos - box.center
            
            -- 根据碰撞箱旋转角度调整相对位置
            local angle = math.rad(-box.rotation)
            local rotatedX = relativePos.X * math.cos(angle) - relativePos.Y * math.sin(angle)
            local rotatedY = relativePos.X * math.sin(angle) + relativePos.Y * math.cos(angle)
            
            -- 计算碰撞箱半宽高
            local boxHalfWidth = box.scaleX / 2
            local boxHalfHeight = box.scaleY / 2
            
            -- 计算玩家半宽高
            local playerHalfWidth = playerSize / 2
            local playerHalfHeight = playerSize / 2
            
            -- 检查是否发生碰撞
            if math.abs(rotatedX) < (boxHalfWidth + playerHalfWidth) and
               math.abs(rotatedY) < (boxHalfHeight + playerHalfHeight) then
                -- 计算弹开方向
                local toPlayer = (playerPos - ent.Position):Normalized()  -- 从实体中心指向玩家的方向
                local toBox = (playerPos - box.center):Normalized()       -- 从碰撞箱指向玩家的方向
                
                -- 结合两个方向，权重可以根据需要调整
                local knockbackDirection = (toPlayer * 0.7 + toBox * 0.3):Normalized()
                
                -- 施加弹开力
                player.Velocity = player.Velocity + knockbackDirection * knockbackStrength
                
                -- 处理碰撞逻辑
				-- 善良之刃
                --player:TakeDamage(1, DamageFlag.DAMAGE_NO_PENALTIES, EntityRef(ent), 0)
				local rng = player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_SAD_ONION)  -- 使用任意一个道具作为RNG种子
                local cnt = auxi.choose(1,1,1,2)
				for i = 1,cnt do
					local numCoins = player:GetNumCoins()
                    local numKeys = player:GetNumKeys()
                    local numBombs = player:GetNumBombs()
					local availableDrops = {}
                    if numCoins > 0 then
                        table.insert(availableDrops, 0)  -- 硬币
                    end
                    if numKeys > 0 then
                        table.insert(availableDrops, 1)  -- 钥匙
                    end
                    if numBombs > 0 then
                        table.insert(availableDrops, 2)  -- 炸弹
                    end
                    
                    -- 如果有可掉落的物品
                    if #availableDrops > 0 then
                        -- 随机选择一个可掉落的物品
                        local dropType = availableDrops[rng:RandomInt(#availableDrops) + 1]
						local dir = auxi.get_by_rotate(knockbackDirection,auxi.random_1() * 90 - 45) * knockbackStrength * (auxi.random_1() * 0.5 + 0.75)
						if dropType == 0 and numCoins > 0 then
							player:AddCoins(-1)
							local q = Isaac.Spawn(5, 20, 1, player.Position, dir, nil) auxi.self_morph(q)
						elseif dropType == 1 and numKeys > 0 then
							player:AddKeys(-1)
							local q = Isaac.Spawn(5, 30, 1, player.Position, dir, nil) auxi.self_morph(q)
						elseif dropType == 2 and numBombs > 0 then
							player:AddBombs(-1)
							local q = Isaac.Spawn(5, 40, 1, player.Position, dir, nil) auxi.self_morph(q)
						end
					end
				end
                break  -- 如果已经碰撞，不需要检查其他碰撞箱
            end
        end
    end
end

--l local item = require("Qing_Remaster_scripts.bosses.Boss_Qing")  local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local Nil = require("Qing_Remaster_scripts.others.Nil_holder") local q = auxi.fire_nil(Vector(200,200),Vector(0,0),{cooldown = 30,}) local qd = q:GetData() qd[Nil.own_key.."work"] = function(self) local ss = self:GetSprite() local sanim = ss:GetAnimation() if ss:IsFinished(sanim) then self:Remove() return end item.calculate_hitbox(self) end local qs = q:GetSprite() qs:Load("gfx/boss/Qing/StabKnife.anm2",true) qs:Play("AttackUp",true) qs.Rotation = 0 q.PositionOffset = Vector(0,0)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local anim = s:GetAnimation()
		local frame = s:GetFrame()
		
		d[item.own_key.."RenderCounter"] = (d[item.own_key.."RenderCounter"] or 0) + 1
		d[item.own_key.."task"] = d[item.own_key.."task"] or {}
		d[item.own_key.."state"] = d[item.own_key.."state"] or {}
		local info = auxi.check_lerp(s:GetFrame(),item.AnimInfo[s:GetAnimation()] or {{frame = 0,offset = 0,},})
		--if item.Allow_Offset[anim] then s.Offset = Vector(0,info.offset) else s.Offset = Vector(0,0) end
		Color_holder.try_add_edge_color(ent,Color(0,0,0,0),{cnt = 0,work = function(ent,tg,rpos)
			local d = tg:GetData() if d[item.own_key.."BackSprite"] == nil then local s = Sprite() s:Load("gfx/boss/Qing/Qing.anm2",true) s:Play("Back",true) d[item.own_key.."BackSprite"] = s end
			local info = auxi.check_lerp(s:GetFrame(),item.AnimInfo[s:GetAnimation()] or {{frame = 0,offset = 0,},})
			local s2 = d[item.own_key.."BackSprite"] s2:Play("Back",true) --if d[item.own_key.."linked_knife_init"] then s2:Play("Back2",true) else s2:Play("Back",true) end
			s2:Render(rpos + Vector(0,info.offset - 20),Vector(0,0),Vector(0,0)) 
			if d[item.own_key.."linked_knife_init"] then 
				local cnt = d[item.own_key.."linked_knife_init"].cnt or 6
				local scnt = 20
				if d[item.own_key.."BackWing"] == nil then local s = Sprite() s:Load("gfx/boss/Qing/Qing.anm2",true) s:Play("Sword_wing",true) d[item.own_key.."BackWing"] = s end
				local s2 = d[item.own_key.."BackWing"] 
				if d[item.own_key.."FloatSword"] then
					for u,v in pairs({Vector(-5,0),Vector(-7,3),}) do 
						for i = 1,cnt do
							local winfo = item.wing_info[i] if winfo.flip then s2.FlipX = true else s2.FlipX = false end
							local frame = (d[item.own_key.."RenderCounter"] - (winfo.delay or 0))% 21
							if d[item.own_key.."FloatSword"][i + u * scnt] == nil and frame == 0 then d[item.own_key.."FloatSword"][i + u * scnt] = {cnt = d[item.own_key.."RenderCounter"] - (winfo.delay or 0),} end
							if d[item.own_key.."FloatSword"][i + u * scnt] then
								if d[item.own_key.."FloatSword"][i + u * scnt].linker then
									if auxi.check_all_exists(d[item.own_key.."FloatSword"][i + u * scnt].linker) then
									else
										if d[item.own_key.."SwordCounter"] then d[item.own_key.."FloatSword"][i + u * scnt] = {decay_alpha = 0,} 
											d[item.own_key.."SwordCounter"] = d[item.own_key.."SwordCounter"] - 1
											if d[item.own_key.."SwordCounter"] <= 0 then d[item.own_key.."SwordCounter"] = nil end
										end
										if d[item.own_key.."SwordCounter"] == nil then d[item.own_key.."FloatSword"][i + u * scnt] = {decay_back = 0} end
									end
								elseif d[item.own_key.."FloatSword"][i + u * scnt].decay_back then
									d[item.own_key.."FloatSword"][i + u * scnt].decay_back = d[item.own_key.."FloatSword"][i + u * scnt].decay_back + 1
									local decay_back_info = auxi.check_lerp(d[item.own_key.."FloatSword"][i + u * scnt].decay_back,item.decay_back_info)
									s2.Color = Color(1,1,1,decay_back_info.c)
									s2.Rotation = 0
									s2:SetFrame("Sword_wing",(d[item.own_key.."RenderCounter"] - (winfo.delay or 0))% 21)
									s2:Render(rpos + Vector(0,info.offset - 20 + 32) + winfo.pos + v * (winfo.flip or 1),Vector(0,0),Vector(0,0)) 
									s2.Color = Color(1,1,1,1)
									if d[item.own_key.."FloatSword"][i + u * scnt].decay_back > 30 then d[item.own_key.."FloatSword"][i + u * scnt].finish_sword = true end
								else
									d[item.own_key.."FloatSword"][i + u * scnt].cnt = d[item.own_key.."FloatSword"][i + u * scnt].cnt or (d[item.own_key.."RenderCounter"] - (winfo.delay or 0))
									local decay_cnt = d[item.own_key.."RenderCounter"] - (winfo.delay or 0) - d[item.own_key.."FloatSword"][i + u * scnt].cnt
									if decay_cnt > item.decay_2_scale.total then d[item.own_key.."FloatSword"][i + u * scnt].decay_finished = true end
									local decay_info = auxi.check_lerp(decay_cnt,item.decay_2_scale)
									local tgpos = rpos + Vector(0,info.offset - 20 + 32) + decay_info.val * (winfo.pos + v * (winfo.flip or 1))
									local dtgang = auxi.checkrounded2((tgpos - rpos):GetAngleDegrees(),Vector(0,1):GetAngleDegrees(),1,-1,360)
									local dangle = dtgang * decay_info.rotate_rate * (winfo.flip or 1)
									if d[item.own_key.."FloatSword"][i + u * scnt].decay_alpha then 
										d[item.own_key.."FloatSword"][i + u * scnt].decay_alpha = d[item.own_key.."FloatSword"][i + u * scnt].decay_alpha + 1
										s2.Color = Color(1,1,1,auxi.check_lerp(d[item.own_key.."FloatSword"][i + u * scnt].decay_alpha,item.decay_back_info).c) 
									end
									s2:SetFrame("Sword",0) s2.Rotation = dangle - 90
									s2:Render(tgpos,Vector(0,0),Vector(0,0)) 
									s2.Color = Color(1,1,1,1)
									d[item.own_key.."FloatSword"][i + u * scnt].pos = tgpos d[item.own_key.."FloatSword"][i + u * scnt].ang = dangle - 90 if s2.FlipX then d[item.own_key.."FloatSword"][i + u * scnt].fliped = true end
								end
							else
								s2.Rotation = 0
								s2:SetFrame("Sword_wing",(d[item.own_key.."RenderCounter"] - (winfo.delay or 0))% 21)
								s2:Render(rpos + Vector(0,info.offset - 20 + 32) + winfo.pos + v * (winfo.flip or 1),Vector(0,0),Vector(0,0)) 
							end
						end
					end
				else
					for u,v in pairs({Vector(-5,0),Vector(-7,3),}) do 
						for i = 1,cnt do 
							local winfo = item.wing_info[i] if winfo.flip then s2.FlipX = true else s2.FlipX = false end
							s2.Rotation = 0
							s2:SetFrame("Sword_wing",(d[item.own_key.."RenderCounter"] - (winfo.delay or 0))% 21)
							s2:Render(rpos + Vector(0,info.offset - 20 + 32) + winfo.pos + v * (winfo.flip or 1),Vector(0,0),Vector(0,0)) 
						end
					end
				end
			end
		end,})
		local hp_rate = ent.HitPoints / ent.MaxHitPoints
		local target = auxi.get_acceptible_target(ent) or ent
		local dir = target.Position - ent.Position
		if anim == "Idle" then
			if not d[Boss_Sprite_holder.own_key.."finished"] then Boss_Sprite_holder.control_boss_screen(ent,info) end
			if not d[item.own_key.."colse_door"] then grid_doors.force_door_anim() d[item.own_key.."colse_door"] = true end
		end
		if (anim == "Idle" and s:IsFinished(anim)) or d[item.own_key.."gothrough"] then		--核心控制
			local find_s = {{name = "Idle",weigh = 15,},}
			
			d[item.own_key.."switch_bonus"] = (d[item.own_key.."switch_bonus"] or 0) - 1
			if d[item.own_key.."switch_bonus"] < 0 then d[item.own_key.."switch_bonus"] = nil end
			local switch_bonus = (d[item.own_key.."switch_bonus"] == nil)		--防止反复过快切换飞行器
			
			local n_air_cnt = 0
			local n_air = auxi.getothers(996,enums.Enemies.QingHelper) for u,v in pairs(n_air) do if v:GetData()[item.own_key.."effect"].skip_adder then else n_air_cnt = n_air_cnt + 1 end end
			if n_air_cnt <= 2 then find_s = {{name = "attack_plan_A0",weigh = 40,},} end
			local move_rate = 0.3
			table.insert(find_s,{name = "attack_plan_A1",weigh = math.max(0,2 * (8 - #n_air)),})
			if hp_rate < 0.5 then table.insert(find_s,{name = "attack_plan_A1",weigh = math.max(0,(16 - #n_air)),}) end
			if #(((d[item.own_key.."effect"] or {}).air_list or {})[1] or {}) > 0 then			--存在环绕物
				--if hp_rate < 0.5 then table.insert(find_s,{name = "part_free",weigh = 2,}) end		--太乱来了
				table.insert(find_s,{name = "switch_plan_A2",weigh = 4,})						--修改环绕模式
				if hp_rate > 0.8 then table.insert(find_s,{name = "switch_plan_A1",weigh = 8,}) end
				move_rate = 1
			else 
				d[item.own_key.."state"].all_contract = nil 
				if switch_bonus then table.insert(find_s,{name = "switch_plan_A1",weigh = 8,}) end
				if hp_rate < 0.3 and switch_bonus then table.insert(find_s,{name = "switch_plan_A1",weigh = 8,}) end
			end
			
			table.insert(find_s,{name = "attack_plan_A2",weigh = 3,})
			table.insert(find_s,{name = "attack_plan_A3",weigh = 4,})
			--if ___QING___.Attack1 then ___QING___.Attack1 = nil find_s = {{name = "attack_plan_A1",weigh = 10,},}  end
			--if true then
			if hp_rate < 0.8 then			--二阶段
				item.check_word_(ent,1)

				d[item.own_key.."linked_weapon"] = d[item.own_key.."linked_weapon"] or {}
				d[item.own_key.."linked_weapon"].weapons = d[item.own_key.."linked_weapon"].weapons or {}
				if d[item.own_key.."linked_weapon"].init ~= true then 
					find_s = {{name = "Mode_Switch_1",weigh = 10,},}
					d[item.own_key.."linked_weapon"].init = true 
				else
					local task_tbl = {}
					for i = 1,4 do 
						if auxi.check_all_exists(d[item.own_key.."linked_weapon"].weapons[i]) ~= true then d[item.own_key.."linked_weapon"].weapons[i] = item.generate_weapon(i,ent) end --ent.HitPoints = math.max(0,ent.HitPoints - 300) end		--支付300血重生
						local di = d[item.own_key.."linked_weapon"].weapons[i]:GetData() if di[item.own_key.."task"] == nil then table.insert(task_tbl,{id = i,ent = d[item.own_key.."linked_weapon"].weapons[i],}) end
					end
					if #task_tbl > 0 then
						if #task_tbl == 4 and auxi.random_1() < 0.75 then
							local rnd = auxi.random_in_table(task_tbl)
							item.activate_weapon_task(rnd,{hp_rate = hp_rate,})
						end
						if hp_rate < 0.8 and #task_tbl == 3 and auxi.random_1() < 0.5 then
							local rnd = auxi.random_in_table(task_tbl)
							if hp_rate < 0.5 then item.activate_weapon_task(rnd,{mode = auxi.choose(1,2),hp_rate = hp_rate,})
							else item.activate_weapon_task(rnd) end
						end
						if hp_rate < 0.5 and #task_tbl == 2 and auxi.random_1() < 0.5 then
							local rnd = auxi.random_in_table(task_tbl)
							item.activate_weapon_task(rnd,{mode = auxi.choose(1,2),hp_rate = hp_rate,})
						end
						if hp_rate < 0.3 and #task_tbl == 1 and auxi.random_1() < 0.3 then
							local rnd = auxi.random_in_table(task_tbl)
							item.activate_weapon_task(rnd,{mode = 2,hp_rate = hp_rate,})
						end
					end
				end
				
			end
			--if true then
			if hp_rate < 0.65 then			--三阶段
				item.check_word_(ent,2)
				d[item.own_key.."move_1"] = true
				if #d[item.own_key.."effect"].air_list[2] == 0 then table.insert(find_s,{name = "attack_plan_B1",weigh = 8,}) end
				table.insert(find_s,{name = "attack_plan_B2",weigh = 6,})
			end
			--if true then
			if hp_rate < 0.5 then 			--四阶段
				item.check_word_(ent,3)
				if d[item.own_key.."linked_knife_init"] == nil then find_s = {{name = "Mode_Switch_2",weigh = 10,},} else 
					if d[item.own_key.."state"].moved2 == nil then
						table.insert(find_s,{name = "attack_plan_C1",weigh = 8,})
						table.insert(find_s,{name = "attack_plan_C2",weigh = 8,})
						table.insert(find_s,{name = "attack_plan_C3",weigh = 8,})
						
						if d[item.own_key.."FloatSword"] == nil then
							table.insert(find_s,{name = "attack_plan_D1",weigh = 8,})
						end
					end
				end
			end

			if hp_rate < 0.25 then 			--五阶段
				item.check_word_(ent,5)
				if d[item.own_key.."linked_knife_init2"] ~= true then find_s = {{name = "Mode_Switch_3",weigh = 10,},} else 
					if d[item.own_key.."state"].moved2 == nil then
						if d[item.own_key.."FloatSword"] == nil then
							table.insert(find_s,{name = "attack_plan_D1",weigh = 16,})
						end
					end
				end
			end
			
			if auxi.random_1() < move_rate or (d[item.own_key.."state"].move0 and auxi.random_1() < 0.75) then		--基础位移
				d[item.own_key.."state"].move0 = nil
				if d[item.own_key.."state"].moved1 ~= true then
					d[item.own_key.."state"].moved1 = true
					if auxi.random_1() < 0.75 then 
						local base = dir:GetAngleDegrees() + 180 + (auxi.random_1() - 0.5) * 90 local flip = auxi.choose(1,-1) local speed = auxi.choose(1,2,3) local range = auxi.choose(150,200,250) local r1 = auxi.choose(0,25,50) local b1 = auxi.random_1() * 360 local s1 = auxi.choose(3,6,9)
						if hp_rate < 0.8 then 
							range = range + 50 speed = auxi.random_1() * 1.2 
							if auxi.random_1() < 0.75 then base = auxi.random_1() * 90 - 45 end 
						end	
						AI.ClearMovement(ent)
						AI.move2ent(ent,target,auxi.choose(120,180,240,360),nil,{pos_offset = function(ent,frame,info) return auxi.MakeVector((base + flip * frame * speed) % 360) * (range + r1 * (math.cos(math.rad(frame * s1 + b1)) + 1)) end,mxvel = 10,mvrate = 0,start_mvrate = 0.5,})
					else
						local base = dir:GetAngleDegrees() + 180 + auxi.choose(0,45,90,270,315) local flip = auxi.choose(1,-1) local speed = auxi.choose(3,6,9) local range = auxi.choose(150,200,250) local r2 = auxi.choose(15,30,45) local b2 = auxi.random_1() * 360
						if hp_rate < 0.8 then range = range + 50 if auxi.random_1() < 0.75 then base = auxi.random_1() * 90 - 45 end end
						AI.ClearMovement(ent)
						AI.move2ent(ent,target,auxi.choose(120,180),nil,{pos_offset = function(ent,frame,info) return auxi.MakeVector((base + flip * math.cos(math.rad(frame * speed + b2)) * r2) % 360) * range end,mxvel = 10,mvrate = 0,start_mvrate = 0.5,})
						d[AI.own_key.."Move"] = nil
					end
				end
			end
			
			if d[item.own_key.."init"] == nil then d[item.own_key.."init"] = true find_s = {{name = "attack_plan_A0",weigh = 10,},} end
			
			--find_s = {{name = "attack_plan_C3",weigh = 10,},}
			local stag = auxi.random_in_weighed_table(find_s)
			
			if not d[item.own_key.."gothrough"] then
				local sinfo = item.strategies[stag.name]
				s:Play(sinfo.anim,true) auxi.check_if_any(sinfo.extra,ent,item)
				d[item.own_key.."task"] = {}
				for u,v in pairs(sinfo.task or {}) do d[item.own_key.."task"][u] = v end
			end
			d[item.own_key.."gothrough"] = nil
		end
		if s:IsFinished(anim) then
			local tg = auxi.check_if_any(item.Swapper[anim],ent) or "Idle"
			s:Play(tg,true)
		end
		if anim == "Attack1" then
			if (d[item.own_key.."task"].state or 0) == 0 then		--基本召唤
				if s:IsEventTriggered("Summon") then
					d[item.own_key.."summon_counter"] = (d[item.own_key.."summon_counter"] or 0) + 1		--生成的飞行器血量渐增
					local cnt = 1 if hp_rate < 0.8 then cnt = auxi.choose(1,1,2) end if hp_rate < 0.5 then cnt = auxi.choose(1,2,3) end if hp_rate < 0.3 then cnt = auxi.choose(3,4) end
					for i = 1,cnt do 
						local q = Isaac.Spawn(996,enums.Enemies.QingHelper,0,ent.Position,ent.Velocity,ent):ToNPC()
						q:GetData()[item.own_key.."effect"] = {linker = ent,} 
						if d[item.own_key.."state"].all_contract then 
							table.insert(d[item.own_key.."effect"].air_list[1],{ent = q,})
							q:GetData()[item.own_key.."effect"].air_list_id = 1
						end
						q.MaxHitPoints = q.MaxHitPoints + d[item.own_key.."summon_counter"] * 15
						q.HitPoints = q.HitPoints + d[item.own_key.."summon_counter"] * 15
					end
				end
			end
			if (d[item.own_key.."task"].state or 0) == -1 then		--立刻生成5份
				if s:IsEventTriggered("Summon") then
					d[item.own_key.."summon_counter"] = (d[item.own_key.."summon_counter"] or 0) + 1
					for i = 1,5 do 
						local q = Isaac.Spawn(996,enums.Enemies.QingHelper,i,ent.Position + auxi.get_by_rotate(nil,i*360/5,30),ent.Velocity,ent):ToNPC()
						q:GetData()[item.own_key.."effect"] = {linker = ent,}
						q.MaxHitPoints = q.MaxHitPoints + d[item.own_key.."summon_counter"] * 15
						q.HitPoints = q.HitPoints + d[item.own_key.."summon_counter"] * 15
					end
				end
			end
			if (d[item.own_key.."task"].state or 0) == 1 then		--切换环绕目标，并向玩家移动
				if s:IsEventTriggered("Summon") then
					d[item.own_key.."switch_bonus"] = 15
					if d[item.own_key.."state"].all_contract then 
						if d[item.own_key.."task"].half then item.set_part_free(d,0.3)
						else d[item.own_key.."state"].all_contract = nil item.all_set_to(d,nil) end
					else d[item.own_key.."state"].all_contract = true item.all_set_to(d,1) end
				end
			end
			if (d[item.own_key.."task"].state or 0) == 11 then		--生成武器
				if s:IsEventTriggered("Summon") then
					for i = 1,4 do 
						if auxi.check_all_exists(d[item.own_key.."linked_weapon"].weapons[i]) ~= true then d[item.own_key.."linked_weapon"].weapons[i] = item.generate_weapon(i,ent) end
					end
				end
			end
			if (d[item.own_key.."task"].state or 0) == 21 then		--生成武器
				if s:IsEventTriggered("Summon") then
					d[item.own_key.."linked_knife_init"] = {cnt = 6,} 
					local e = Isaac.Spawn(1000,15,0,ent.Position,Vector(0,0),nil):ToEffect() e.SpriteScale = Vector(2,2)
				end
			end
			if (d[item.own_key.."task"].state or 0) == 22 then		--生成武器
				if s:IsEventTriggered("Summon") then
					d[item.own_key.."linked_knife_init2"] = true 
					d[item.own_key.."linked_knife_init"] = {cnt = 12,} 
					local e = Isaac.Spawn(1000,15,0,ent.Position,Vector(0,0),nil):ToEffect() e.SpriteScale = Vector(2,2)
				end
			end
			if (d[item.own_key.."task"].state or 0) == 101 then		--斩击角色
				if s:IsEventTriggered("Summon") then
					d[item.own_key.."state"].moved1 = true
					if d[item.own_key.."state"].moved2 == nil then 
						d[item.own_key.."state"].moved2 = true
						AI.ClearMovement(ent) d[item.own_key.."state"].fliped = (d[item.own_key.."state"].fliped or 1) * -1
						AI.move2pos(ent,target.Position + dir:Normalized() * 160 + auxi.get_by_rotate(dir:Normalized(),90 * d[item.own_key.."state"].fliped,120),15,function(ent,frame,info) 
							if frame == math.floor(info.mxframe * 0.5) then
								local q = auxi.fire_nil(ent.Position,Vector(0,0),{cooldown = 30,remove_with_ent = ent,}) local qd = q:GetData() qd[Nil.own_key.."work"] = function(self)
									local ss = self:GetSprite() local sanim = ss:GetAnimation() if ss:IsFinished(sanim) then self:Remove() return end
									if auxi.check_all_exists(ent) then self.Position = ent.Position end
									item.calculate_hitbox(self)
								end
								local qs = q:GetSprite() qs:Load("gfx/boss/Qing/StabKnife.anm2",true) qs:Play("AttackUp",true) qs.Rotation = dir:GetAngleDegrees() q.PositionOffset = ent.PositionOffset if d[item.own_key.."state"].fliped == 1 then qs.FlipX = true end
								sound_tracker.PlayStackedSound(SoundEffect.SOUND_SWORD_SPIN,1,1,false,0,2)
							end
						end)
					end
				end
			end
			if (d[item.own_key.."task"].state or 0) == 102 then		--三重斩击
				if s:IsEventTriggered("Summon") then
					d[item.own_key.."state"].moved1 = true
					if d[item.own_key.."state"].moved2 == nil then
						d[item.own_key.."state"].moved2 = true
						AI.ClearMovement(ent) d[item.own_key.."state"].fliped = (d[item.own_key.."state"].fliped or 1) * -1
						local tgpos = target.Position + dir:Normalized() * 160 + auxi.get_by_rotate(dir:Normalized(),90 * d[item.own_key.."state"].fliped,120)
						local total_frame = 15 if (ent.Position - tgpos):Length() > 300 then total_frame = 25 end
						AI.move2pos(ent,tgpos,total_frame,function(ent,frame,info) 
							if frame == math.floor(info.mxframe * 0.3) then
								local q = auxi.fire_nil(ent.Position,Vector(0,0),{cooldown = 30,remove_with_ent = ent,}) local qd = q:GetData() qd[Nil.own_key.."work"] = function(self)
									local ss = self:GetSprite() local sanim = ss:GetAnimation() if ss:IsFinished(sanim) then self:Remove() return end
									if auxi.check_all_exists(ent) then self.Position = ent.Position end
									item.calculate_hitbox(self)
								end
								local qs = q:GetSprite() qs:Load("gfx/boss/Qing/StabKnife.anm2",true) qs:Play("AttackUp",true) qs.Rotation = info.dir:GetAngleDegrees() q.PositionOffset = ent.PositionOffset if d[item.own_key.."state"].fliped == 1 then qs.FlipX = true end
								sound_tracker.PlayStackedSound(SoundEffect.SOUND_SWORD_SPIN,1,1,false,0,2)
							end
							if frame >= info.mxframe then
								if auxi.check_all_exists(ent) and auxi.check_all_exists(target) and (info.task_counter or 0) > 0 then 
									info.task_counter = info.task_counter - 1
									local dir = target.Position - ent.Position 
									info.dir = dir
									info.mxframe = 15 info.frame = 0 info.reload = true info.pos = target.Position + dir:Normalized() * 160 + auxi.get_by_rotate(dir:Normalized(),90 * d[item.own_key.."state"].fliped,120)
								end
							end
						end,{task_counter = 2,dir = dir,})
					end
				end
			end
			if (d[item.own_key.."task"].state or 0) == 103 then		--冲刺后环斩
				if s:IsEventTriggered("Summon") then
					d[item.own_key.."state"].moved1 = true
					if d[item.own_key.."state"].moved2 == nil then
						d[item.own_key.."state"].moved2 = true
						AI.ClearMovement(ent) d[item.own_key.."state"].fliped = (d[item.own_key.."state"].fliped or 1) * -1
						AI.move2pos(ent,ent.Position - dir:Normalized() * 120,8,function(ent,frame,info) 
							if info.task_counter > 0 then
							elseif frame == math.floor(info.mxframe * 0.6) then
								local q = auxi.fire_nil(ent.Position,Vector(0,0),{cooldown = 30,remove_with_ent = ent,}) local qd = q:GetData() qd[Nil.own_key.."work"] = function(self)
									local ss = self:GetSprite() local sanim = ss:GetAnimation() if ss:IsFinished(sanim) then self:Remove() return end
									if auxi.check_all_exists(ent) then self.Position = ent.Position end
									item.calculate_hitbox(self)
								end
								local qs = q:GetSprite() qs:Load("gfx/boss/Qing/StabKnife.anm2",true) qs:Play("SpinUp",true) qs.Rotation = dir:GetAngleDegrees() q.PositionOffset = ent.PositionOffset if d[item.own_key.."state"].fliped == 1 then qs.FlipX = true end
								sound_tracker.PlayStackedSound(SoundEffect.SOUND_SWORD_SPIN,1,1,false,0,2)
							end
							if frame >= info.mxframe then
								if auxi.check_all_exists(ent) and auxi.check_all_exists(target) and (info.task_counter or 0) > 0 then 
									info.task_counter = info.task_counter - 1
									local dir = target.Position - ent.Position 
									info.frame = 0 info.reload = true info.pos = target.Position + dir:Normalized() * 160 + auxi.get_by_rotate(dir:Normalized(),90 * d[item.own_key.."state"].fliped,120)
								end
							end
						end,{task_counter = 1,})
					end
				end
			end
		end
		if anim == "Attack2" then
			if (d[item.own_key.."task"].state or 0) == 0 then		--修改环绕模式
				if s:IsEventTriggered("Target") then
					d[item.own_key.."effect"].air_list[1].range = auxi.choose(75,100,150,200)
					d[item.own_key.."effect"].air_list[1].counter_adder = auxi.choose(2,3,4,-2,-3,-4)
				end
			end
			if (d[item.own_key.."task"].state or 0) == 1 then		--依次发射
				if s:IsEventTriggered("Summon") then
					local tot = 0
					for k = 1,#d[item.own_key.."effect"].air_list do 
						for i = 1,#d[item.own_key.."effect"].air_list[k] do 
							local v = d[item.own_key.."effect"].air_list[k][i]
							if auxi.check_all_exists(v.ent) then 
								v.ent:GetData()[item.own_key.."effect"].plan_on_next_time = {delay = 30 + tot * 3,} 
								tot = tot + 1
							end
						end
					end
				end
			end
			if (d[item.own_key.."task"].state or 0) == 2 then		--发出一轮齐射
				if s:IsEventTriggered("Summon") then
					for k = 1,#d[item.own_key.."effect"].air_list do 
						for i = 1,#d[item.own_key.."effect"].air_list[k] do 
							local v = d[item.own_key.."effect"].air_list[k][i]
							if auxi.check_all_exists(v.ent) then 
								v.ent:GetData()[item.own_key.."effect"].plan_on_next_time = {delay = 30,} 
							end
						end
					end
				end
			end
		end
		if anim == "Attack3" then
			if s:IsEventTriggered("Sound") then sound_tracker.PlayStackedSound(enums.SoundEffect.Qing_alarm,1,1,false,0,2) end
			if (d[item.own_key.."task"].state or 0) == 1 then
				if s:IsEventTriggered("Summon") and #d[item.own_key.."effect"].air_list[2] == 0 then
					local tg = auxi.get_acceptible_target(ent)
					local cnt = auxi.choose(7,10,15)
					local erase_time = auxi.choose(120) local total = 120
					local vel = (tg.Position - ent.Position):Normalized() * auxi.choose(10,12,15) * auxi.choose(1,-1)
					local start_pos = tg.Position - vel:Normalized() * 600 + tg.Velocity * 5
					local stid = auxi.choose(0,0,0,1,2,3,4,5)
					for i = 1,cnt do 
						local q = Isaac.Spawn(996,enums.Enemies.QingHelper,stid,start_pos + auxi.get_by_rotate(vel,i/cnt * 360,60),Vector(0,0),ent):ToNPC() q:GetSprite():Play("Idle",true)
						q:GetData()[item.own_key.."effect"] = {linker = ent,erased = erase_time,try_charge = true,} q:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
						table.insert(d[item.own_key.."effect"].air_list[2],{ent = q,})
						q:GetData()[item.own_key.."effect"].air_list_id = 2
					end
					d[item.own_key.."effect"].air_list[2].line = {erased = erase_time,p1 = start_pos,vel = vel,total = total,}
					d[item.own_key.."effect"].air_list[2].counter = 0 
					d[item.own_key.."effect"].air_list[2].skip_adder = true 
				end
			end
			if (d[item.own_key.."task"].state or 0) == 2 then
				if s:IsEventTriggered("Summon") then
					if auxi.check_all_exists(d[item.own_key.."largeone"]) ~= true then
						local stid = auxi.choose(0,0,0,1,2,3,4,5)
						local q = Isaac.Spawn(996,enums.Enemies.QingHelper,stid,ent.Position,Vector(0,0),ent):ToNPC() --q:GetSprite():Play("Idle",true)
						q:GetData()[item.own_key.."effect"] = {linker = ent,skip_adder = true,largeone = true,} q:ClearEntityFlags(EntityFlag.FLAG_APPEAR) q.MaxHitPoints = q.MaxHitPoints * 10 q.HitPoints = q.MaxHitPoints
						local succ = item.try_insert_target_list(d[item.own_key.."effect"].air_list,q) local list = d[item.own_key.."effect"].air_list[succ] list.range = 75
						q:GetData()[item.own_key.."effect"].air_list_id = succ d[item.own_key.."largeone"] = q
						local filename = item.get_air_texture(q.SubType, "_" .. ".png") local qs = q:GetSprite() --qs.Scale = Vector(3,3)
						qs:Load("gfx/boss/Qing/Air.anm2",true) qs:ReplaceSpritesheet(0,filename) qs:LoadGraphics() qs:Play("Appear",true)
						local cnt = auxi.choose(3,4,5,6,7)
						for i = 1,cnt do
							local q2 = Isaac.Spawn(996,enums.Enemies.QingHelper,stid,q.Position + auxi.get_by_rotate(nil,i/cnt * 360,60),Vector(0,0),ent):ToNPC() --q:GetSprite():Play("Idle",true)
							q2:GetData()[item.own_key.."effect"] = {linker = ent,skip_adder = true,} q2:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
							table.insert(list,{ent = q2,}) q2:GetData()[item.own_key.."effect"].air_list_id = succ
						end
					else
						local q = d[item.own_key.."largeone"] local succ = item.try_insert_target_list(d[item.own_key.."effect"].air_list,q) local list = d[item.own_key.."effect"].air_list[succ] list.range = auxi.choose(75,125,200)
						local cnt = auxi.choose(1,2) local stid = q.SubType
						for i = 1,cnt do
							local q2 = Isaac.Spawn(996,enums.Enemies.QingHelper,stid,q.Position + auxi.get_by_rotate(nil,i/cnt * 360,60),Vector(0,0),ent):ToNPC() --q:GetSprite():Play("Idle",true)
							q2:GetData()[item.own_key.."effect"] = {linker = ent,skip_adder = true,} q2:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
							table.insert(list,{ent = q2,}) q2:GetData()[item.own_key.."effect"].air_list_id = succ
						end
					end
				end
			end
		end
		if anim == "Attack4" then
			if s:IsEventTriggered("Target") then d[item.own_key.."FloatSword"] = {} d[item.own_key.."SwordCounter"] = auxi.choose(0,12,24,36) end
			if s:IsEventTriggered("Summon") then d[item.own_key.."state"].nomove = true AI.ClearMovement(ent) end
		end
		if anim == "Fire4" then
			if s:IsEventTriggered("Summon") then
				local all_finished = true
				local cnt = (d[item.own_key.."linked_knife_init"] or {}).cnt or 6
				for i = 1,cnt do
					for k = 1,2 do
						local id = k * 20 + i
						if d[item.own_key.."FloatSword"][id] then
							if d[item.own_key.."FloatSword"][id].decay_finished then		--生成并发射
								local q = Isaac.Spawn(996,enums.Enemies.QingKnife,0,auxi.real_ScreenToWorld(d[item.own_key.."FloatSword"][id].pos),Vector(0,0),nil):ToNPC() auxi.safely_init(q)
								local sq = q:GetSprite() sq.Rotation = d[item.own_key.."FloatSword"][id].ang sq:Load("gfx/boss/Qing/Qing.anm2",true) sq:Play("Sword",true) if d[item.own_key.."FloatSword"][id].fliped then sq.Rotation = - sq.Rotation sq:Play("Sword_Fliped",true) end
								local dq = q:GetData() dq[item.own_key.."effect"] = {linker = ent,}
								d[item.own_key.."FloatSword"][id] = {linker = q,}
							end
							if d[item.own_key.."FloatSword"][id].finish_sword then else all_finished = false end
						end
					end
				end
				if all_finished then s:Play("Attack4Back",true) end
				d[item.own_key.."gothrough"] = true
			end
		end
		if anim == "Attack4Back" then
			if s:IsEventTriggered("Summon") then d[item.own_key.."SwordCounter"] = nil d[item.own_key.."SwordContinue"] = nil d[item.own_key.."FloatSword"] = nil d[item.own_key.."state"].nomove = nil end
		end
		if anim == "Break" then
			if d[item.own_key.."effect"].should_leave then
				item.check_word_(ent,4)
				local qent = auxi.fire_nil(ent.Position,Vector(0,0),{cooldown = 999,})
				local qents = qent:GetSprite() qents:Load("gfx/boss/Qing/Qing.anm2",true) qents:Play("Break",true)
				local qentd = qent:GetData() qentd[Nil.own_key.."work"] = function(qself)
					local qss = qself:GetSprite()
					if qss:WasEventTriggered("Summon") then
						local cnt = auxi.choose(0,1,1,1,2,2,3,4)
						for i = 1,cnt do
							local q = auxi.fire_nil(qself.Position + auxi.random_v2() * 240,Vector(0,0),{cooldown = 30,})
							local qs = q:GetSprite() qs:Load("gfx/boss/Qing/Qing.anm2",true) qs:Play("Spark",true) qs.Color = item.num2realcolor[auxi.choose(1,2,3,4,5)]
							local qd = q:GetData() qd[Nil.own_key.."work"] = function(self)
								local ss = self:GetSprite()
								if ss:IsFinished(ss:GetAnimation()) then self:Remove() end
							end
						end
					end
					if qss:IsEventTriggered("Target") then
						local cnt = 3
						local room = Game():GetRoom()
						for i = 1,cnt do
							local colid = auxi.get_quality_item(3)
							local q = Isaac.Spawn(5,100,colid,room:FindFreePickupSpawnPosition(qself.Position + auxi.MakeVector(i/cnt * 360) * 60),Vector(0,0),nil):ToPickup() 
							--local ndx = option_index_holder.find_a_new_index()
							--q.OptionsPickupIndex = ndx
						end
						local colid = auxi.get_quality_item(4)
						local q = Isaac.Spawn(5,100,colid,room:FindFreePickupSpawnPosition(qself.Position),Vector(0,0),nil):ToPickup()
						cnt = 6
						for i = 1,cnt do
							local q = Isaac.Spawn(5,10,3,room:FindFreePickupSpawnPosition(qself.Position + auxi.MakeVector(i/cnt * 360) * 120),Vector(0,0),nil):ToPickup()
						end
						qself:Remove()
						grid_doors.force_door_anim("Open")
						save.elses[item.own_key.."finished"] = true
					end
				end
				ent:Remove()
			end
		end
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		d[item.own_key.."effect"].air_list = d[item.own_key.."effect"].air_list or {{target = ent,},{target = ent,},}		--1对应环绕自身，2+对应环绕玩家
		if d[item.own_key.."effect"].air_list[1].line then d[item.own_key.."effect"].air_list[1].line.erased = (d[item.own_key.."effect"].air_list[1].line.erased or 0) - 1 if d[item.own_key.."effect"].air_list[1].line.erased < 0 then d[item.own_key.."effect"].air_list[1].line = nil end end
		for k = 1,#d[item.own_key.."effect"].air_list do 				--控制飞行器
			d[item.own_key.."effect"].air_list[k].counter = (d[item.own_key.."effect"].air_list[k].counter or 0) + (d[item.own_key.."effect"].air_list[k].counter_adder or 2)
			local cnt1 = #d[item.own_key.."effect"].air_list[k]
			for i = #d[item.own_key.."effect"].air_list[k],1,-1 do 
				if auxi.check_all_exists(d[item.own_key.."effect"].air_list[k][i].ent) ~= true or d[item.own_key.."effect"].air_list[k][i].removed then table.remove(d[item.own_key.."effect"].air_list[k],i) 
				elseif d[item.own_key.."effect"].air_list[k][i].ent:GetData()[item.own_key.."effect"].air_list_id ~= k then table.remove(d[item.own_key.."effect"].air_list[k],i) 
				else d[item.own_key.."effect"].air_list[k][i].pid = i end
			end
			local cnt2 = #d[item.own_key.."effect"].air_list[k]
			for i = 1,#d[item.own_key.."effect"].air_list[k] do 
				local v = d[item.own_key.."effect"].air_list[k][i]
				if math.ceil((v.pid * 360/cnt1)/360) > math.ceil(((v.pid - 1) * 360/cnt1)/360) then
					d[item.own_key.."effect"].air_list[k].rotation_offset = (d[item.own_key.."effect"].air_list[k].rotation_offset or 0) - ((i * 360/cnt2) - (v.pid * 360/cnt1))
					break
				end
			end
		end
		
		if AI.is_clear(ent) then 
			d[item.own_key.."state"].move0 = true
			d[item.own_key.."state"].moved1 = nil
			d[item.own_key.."state"].moved2 = nil
			AI.move2pos(ent,auxi.choose2(auxi.find_suitable_pos_list(item.random_pos(8),{ent.Position,})),auxi.choose(60,80,120),nil,{mvrate = 0.5,})
		end
		if d[item.own_key.."state"].nomove then ent.Velocity = ent.Velocity * 0.5
		else AI.Control_Move(ent) end
	end
	if ent.Variant == enums.Enemies.QingHelper then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local anim = s:GetAnimation()
		local frame = s:GetFrame()
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		if d[item.own_key.."effect"].shift_counter then d[item.own_key.."effect"].shift_counter = d[item.own_key.."effect"].shift_counter - 1 if d[item.own_key.."effect"].shift_counter <= 0 then d[item.own_key.."effect"].shift_counter = nil end end
		if d[item.own_key.."hit_counter"] then d[item.own_key.."hit_counter"] = d[item.own_key.."hit_counter"] - 1 if d[item.own_key.."hit_counter"] <= 0 then d[item.own_key.."hit_counter"] = nil end end
		
		local tg = d[item.own_key.."effect"].target 
		if auxi.check_all_exists(tg) ~= true or ent.FrameCount % 300 == 20 then 
			tg = auxi.get_acceptible_target(ent)	-- ent:GetPlayerTarget() or Game():GetPlayer(0) 
			d[item.own_key.."effect"].target = tg
		end
		if tg then
			local td = tg:GetData() 
			local dir = (tg.Position + tg.Velocity - ent.Position) 
			d[item.own_key.."record_dir"] = dir
			
			local linker = d[item.own_key.."effect"].linker			--linker 是 小青
			if auxi.check_all_exists(linker) ~= true then ent:Remove() return end
			local td = linker:GetData()
			td[item.own_key.."effect"] = td[item.own_key.."effect"] or {}
			td[item.own_key.."effect"].air_list = td[item.own_key.."effect"].air_list or {}
			local largeone = d[item.own_key.."effect"].largeone
			local air_list = td[item.own_key.."effect"].air_list
			local id = -1 
			if largeone then 
				d[item.own_key.."effect"].air_list_id = d[item.own_key.."effect"].air_list_id or item.try_insert_target_list(air_list,ent)
			else
				if d[item.own_key.."effect"].air_list_id then 			--成功找到
					for i = 1,#(air_list[d[item.own_key.."effect"].air_list_id]) do local v = air_list[d[item.own_key.."effect"].air_list_id][i] if auxi.check_for_the_same(v.ent,ent) == true then id = i break end end
				end
				if id == -1 then
					local succ = item.try_insert_target_list(air_list,tg)	--第2次检查，此时tg一定是mvtg
					for i = 1,#(air_list[succ]) do local v = air_list[succ][i] if auxi.check_for_the_same(v.ent,ent) == true then id = i break end end
					d[item.own_key.."effect"].air_list_id = succ
					if id ~= -1 then 
					else 
						local dang = dir:GetAngleDegrees() local mxang = 999 local vvi = 0
						for i = 1,#air_list[succ] + 1 do 
							local vi = i/(#air_list[succ] + 1) * 360 + (air_list[succ].rotation_offset or 0) + (air_list[succ].counter or 0)
							local via = math.abs(auxi.checkrounded2(dang,vi,1,-1,360))
							if via < mxang then mxang = via id = i vvi = vi end
						end
						table.insert(air_list[succ],id,{ent = ent,})
						air_list[succ].rotation_offset = (air_list[succ].rotation_offset or 0) - (vvi - dang)
					end
				end
			end
			
			local rair_list = air_list[d[item.own_key.."effect"].air_list_id]
			local mvtg = rair_list.target		--行动的参考对象
			local dir2 = (mvtg.Position + mvtg.Velocity - ent.Position)
			local range = rair_list.range or 200
			
			local target_dir = dir2 + auxi.get_by_rotate(nil,(rair_list.rotation_offset or 0) + (rair_list.counter or 0) + id * 360/math.max(1,#(rair_list)),range)
			local move_rate = 2
			local real_dir = target_dir
			
			if rair_list.line then
				local delta_rate = id / math.max(1,#(rair_list))
				local total = rair_list.line.total or 30
				local cnt = rair_list.counter + (delta_rate - 1) * (total)
				local vel = rair_list.line.vel if rair_list.line.p2 then vel = (rair_list.line.p2 - rair_list.line.p1)/total end
				local tgpos = rair_list.line.p1 + vel * cnt
				--move_rate = 4
				--if d[item.own_key.."lined"] == nil then d[item.own_key.."lined"] = true ent.Position = tgpos end
				real_dir = vel
				target_dir = tgpos - ent.Position
			else d[item.own_key.."lined"] = nil	end
			
			if anim ~= "Appear" then s.Rotation = dir:GetAngleDegrees() - 90 end
			if largeone then
				d[item.own_key.."Scale"] = d[item.own_key.."Scale"] or Attribute_holder.try_hold_attribute(ent,"SpriteScale",function(ent) return Vector(2,2) end,{protect = true,})
				--ent.SpriteScale = Vector(3,3)--s.Scale = Vector(3,3)
				ent.Velocity = dir:Normalized() * math.sqrt(math.max(0,(dir:Length() - 200))) * move_rate
				ent.PositionOffset = ent.PositionOffset * 0.9 + Vector(0,-10) * 0.1
			else
				if anim == "Idle" or (anim ~= "Appear" and td[item.own_key.."move_1"]) then 
					ent.Velocity = target_dir:Normalized() * math.sqrt(math.max(0,(target_dir:Length() - 20))) * move_rate
					ent.PositionOffset = ent.PositionOffset * 0.9 + Vector(0,-25) * 0.1
				else ent.Velocity = ent.Velocity * 0.5 end
			end
			ent.Velocity = auxi.apply_friction(ent.Velocity,1)
			local should_charge = (anim == "Idle") and (d[item.own_key.."effect"].shift_counter == nil)
			
			d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
			if d[item.own_key.."effect"].erased then d[item.own_key.."effect"].erased = d[item.own_key.."effect"].erased - 1 if d[item.own_key.."effect"].erased <= 0 then ent:Remove() end end
			if d[item.own_key.."effect"].try_charge then 
				should_charge = false
				if d[item.own_key.."effect"].should_shoot == nil and d[item.own_key.."effect"].counter > 3 then
					local dis = (ent.Position - tg.Position) local should_shoot = nil
					if dis:Length() < 120 and Game():GetRoom():IsPositionInRoom(ent.Position,80) then should_shoot = true end
					local dang = dis:GetAngleDegrees() local vang = real_dir:GetAngleDegrees()
					local min_ang = math.min(math.abs(auxi.checkrounded2(dang,vang,1,-1,360)),math.abs(auxi.checkrounded2(180 + dang,vang,1,-1,360)))
					if min_ang > 75 then should_shoot = true end
					if should_shoot then d[item.own_key.."effect"].should_shoot = auxi.choose(1,2) end
				end
				if d[item.own_key.."effect"].should_shoot then
					d[item.own_key.."effect"].should_shoot = d[item.own_key.."effect"].should_shoot - 1
					if d[item.own_key.."effect"].should_shoot <= 0 then 
						item.trigger_shoot(ent.SubType,ent,dir,{power = auxi.random_1() * 1 + 1,mode = 2,}) d[item.own_key.."effect"].try_charge = nil d[item.own_key.."effect"].should_shoot = nil
					end
				end
			end
			if d[item.own_key.."effect"].plan_on_next_time then	
				should_charge = false
				d[item.own_key.."effect"].plan_on_next_time.delay = (d[item.own_key.."effect"].plan_on_next_time.delay or 0) - 1
				if d[item.own_key.."effect"].plan_on_next_time["color"] == nil and (d[item.own_key.."effect"].plan_on_next_time.delay < 30) then ent:SetColor(Color(1,1,1,1,1,0,0),45,99,true,true) d[item.own_key.."effect"].plan_on_next_time["color"] = true end
				if d[item.own_key.."effect"].plan_on_next_time.delay <= 0 then s:Play("Charge1",true) d[item.own_key.."effect"].plan_on_next_time = nil end
			end
			if anim == "Charge1" and s:IsEventTriggered("Shoot") then item.trigger_shoot(ent.SubType,ent,dir,{largeone = largeone,}) end
			if ent.SubType == 1 then
				if Game():GetFrameCount() % 60 == 1 and auxi.random_1() < 0.5 and should_charge then s:Play("Charge1",true) end
			end
			if ent.SubType == 2 then
				if Game():GetFrameCount() % 120 == 1 and should_charge then s:Play("Charge1",true) end
			end
			if ent.SubType == 3 then
				if Game():GetFrameCount() % 30 == 1 and auxi.random_1() < 0.3 and should_charge then s:Play("Charge1",true) end
			end
			if ent.SubType == 4 then
				if Game():GetFrameCount() % 60 == 1 and auxi.random_1() < 0.3 and should_charge then s:Play("Charge1",true) end
			end
			if ent.SubType == 5 then
				if Game():GetFrameCount() % 90 == 1 and auxi.random_1() < 0.5 and should_charge then s:Play("Charge1",true) end
			end
			if s:IsFinished(anim) then
				local tg = auxi.check_if_any(item.Air_Swapper[anim],ent) or "Idle"
				s:Play(tg,true)
			end
		end
	end
	if ent.Variant == enums.Enemies.QingHelper2 then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local anim = s:GetAnimation()
		local frame = s:GetFrame()
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		if d[item.own_key.."hit_counter"] then d[item.own_key.."hit_counter"] = d[item.own_key.."hit_counter"] - 1 if d[item.own_key.."hit_counter"] <= 0 then d[item.own_key.."hit_counter"] = nil end end
		
		local linker = d[item.own_key.."effect"].linker
		if auxi.check_all_exists(linker) ~= true then ent:Remove() return end
		
		local tg = d[item.own_key.."effect"].target 
		if auxi.check_all_exists(tg) ~= true or ent.FrameCount % 300 == 20 then 
			tg = auxi.get_acceptible_target(ent) or linker
			d[item.own_key.."effect"].target = tg
		end
		if tg then
			local dir = (tg.Position + tg.Velocity - ent.Position) 
			
			s.Rotation = dir:GetAngleDegrees() - 90 - 45
			local target_pos = auxi.get_by_rotate(item.weapon_offset[ent.SubType],dir:GetAngleDegrees() - 90) + linker.Position - ent.Position
			if d[item.own_key.."task"] then 
				ent.Velocity = ent.Velocity * 0.5 + target_pos * 0.1 * 0.5 * math.max(30 - (d[item.own_key.."task"].counter or 0),0)/30
			else ent.Velocity = ent.Velocity * 0.5 + target_pos * 0.1 * 0.5 end
			ent.Velocity = auxi.apply_friction(ent.Velocity,1)
			
			--d[item.own_key.."task"] = d[item.own_key.."task"] or {multi = 5,}
			for _ = 1,1 do 
			if ent.SubType == 1 then
				if d[item.own_key.."task"] then
					if d[item.own_key.."task"].delay then d[item.own_key.."task"].delay = d[item.own_key.."task"].delay - 1 if d[item.own_key.."task"].delay <= 0 then d[item.own_key.."task"].delay = nil else break end end
					d[item.own_key.."task"].counter = (d[item.own_key.."task"].counter or 0) + 1
					if d[item.own_key.."task"].init == nil then
						if dir:Length() < 180 then 		--过近时暂时取消
							d[item.own_key.."task"].delay = (d[item.own_key.."task"].delay or 0) + auxi.choose(15,30)
							d[item.own_key.."task"].counter = 0
							break
						else
							d[item.own_key.."task"].init = true
							for i = 1,2 do 
								local q = auxi.fire_nil(ent.Position,Vector(0,0),{cooldown = 60,remove_with_ent = ent,}) 
								local qs = q:GetSprite() qs:Load("gfx/boss/Qing/Guideline.anm2",true) qs:Play("Idle",true) q.DepthOffset = -100
								d[item.own_key.."task"][i] = q
							end
						end
					end
					local delta = auxi.check_lerp(d[item.own_key.."task"].counter,item.aim_info).val
					for i = 1,2 do 
						if auxi.check_exists(d[item.own_key.."task"][i]) then
							d[item.own_key.."task"][i]:GetSprite().Rotation = (i * 2 - 3) * delta + dir:GetAngleDegrees() + 90
							d[item.own_key.."task"][i].Position = ent.Position
							--d[item.own_key.."task"][i].Velocity = ent.Velocity
							d[item.own_key.."task"][i].PositionOffset = ent.PositionOffset
						end
					end
					local should_shoot = false local should_end = false
					local counter = d[item.own_key.."task"].counter
					if d[item.own_key.."task"].mode == 1 then if counter == 45 then should_shoot = true should_end = true end
					else
						if counter >= 45 and counter % 3 == 1 then should_shoot = true end
						if counter == 55 then should_end = true end
					end
					if should_shoot then
						local q = Isaac.Spawn(9,0,0,ent.Position,dir:Normalized() * 50,ent):ToProjectile() q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.NO_WALL_COLLIDE auxi.protect_projectile(ent,q)
						local qs = q:GetSprite() qs:Load("gfx/boss/Qing/Guideline.anm2",true) qs:Play("shoot",true) qs.Rotation = dir:GetAngleDegrees() + 90 q.Mass = 0
						local qd = q:GetData() qd[item.own_key.."weapon"] = {remove_self = true,}
						sound_tracker.PlayStackedSound(enums.SoundEffect.Qing_smack,1,1,false,0,2)
					end
					if should_end then
						d[item.own_key.."task"][1]:Remove() d[item.own_key.."task"][2]:Remove()
						d[item.own_key.."task"].multi = (d[item.own_key.."task"].multi or 0) - 1
						if d[item.own_key.."task"].multi <= 0 then d[item.own_key.."task"] = nil 
						else d[item.own_key.."task"].init = nil d[item.own_key.."task"].counter = d[item.own_key.."task"].base_counter or 0 end
					end
				end
			end
			if ent.SubType == 2 then
				if d[item.own_key.."task"] then
					local skip_2_end = nil
for _ = 1,1 do 
					if d[item.own_key.."task"].delay then d[item.own_key.."task"].delay = d[item.own_key.."task"].delay - 1 if d[item.own_key.."task"].delay <= 0 then d[item.own_key.."task"].delay = nil else break end end
					d[item.own_key.."task"].counter = (d[item.own_key.."task"].counter or 0) + 1
					if d[item.own_key.."task"].init == nil then
						d[item.own_key.."task"].init = true
						d[item.own_key.."task"][1] = item.fire_weapon_target(ent.Position,ent)
					end
					d[item.own_key.."task"].fire = d[item.own_key.."task"].fire or {}
					d[item.own_key.."task"].fired = d[item.own_key.."task"].fired or {}
					local none = true
					for i = 1,5,2 do
						if auxi.check_exists(d[item.own_key.."task"][i]) then
							local q1d = d[item.own_key.."task"][i]:GetData()
							q1d[item.own_key.."target"] = tg
							if q1d[item.own_key.."valid"] then d[item.own_key.."task"].fire[i] = true end		--接近时可以发射
							none = false
						end
					end
					if none then skip_2_end = true break end
					for i = 1,5,2 do 
						if auxi.check_all_exists(d[item.own_key.."task"][i]) and d[item.own_key.."task"][i].FrameCount > 15 and (d[item.own_key.."task"].counter >= 60 or d[item.own_key.."task"].fire[i]) and d[item.own_key.."task"].fired[i] == nil then 
							local q = auxi.fire_nil(ent.Position,Vector(0,0),{cooldown = 999,remove_with_ent = ent,}) 
							sound_tracker.PlayStackedSound(enums.SoundEffect.Qing_rocket,1,1,false,0,2)
							local qs = q:GetSprite() qs:Load("gfx/boss/Qing/rocket.anm2",true) qs:Play("Idle",true) 
							local qd = q:GetData() qd[Nil.own_key.."work"] = function(self)
								local sd = self:GetData()
								if auxi.check_all_exists(sd[item.own_key.."target"]) then 
									local sftg = sd[item.own_key.."target"] local dir = sftg.Position - self.Position
									sd[item.own_key.."counter"] = (sd[item.own_key.."counter"] or 0) + 1
									local div = (item.rocket_frame - sd[item.own_key.."counter"]) if math.abs(div) < 1 then div = 1 end
									self.Velocity = dir/div
									local height = -auxi.calculate_height_base_on_rate(sd[item.own_key.."counter"]/item.rocket_frame,400)
									self.PositionOffset = Vector(0,height)
									local delta = Vector(0,- height - auxi.calculate_height_base_on_rate((sd[item.own_key.."counter"] + 1)/item.rocket_frame,400)) + self.Velocity
									self:GetSprite().Rotation = delta:GetAngleDegrees()
								end
							end
							qd[item.own_key.."target"] = d[item.own_key.."task"][i]	d[item.own_key.."task"][i + 1] = q 
							d[item.own_key.."task"][i]:GetData()[item.own_key.."missle"] = q
							d[item.own_key.."task"].fired[i] = {}
							if d[item.own_key.."task"].mode == 2 and i < 5 and auxi.check_all_exists(d[item.own_key.."task"][i + 2]) ~= true then
								d[item.own_key.."task"][i + 2] = item.fire_weapon_target((tg.Position + d[item.own_key.."task"][i].Position) * 0.5,ent)
							end
						end
					end
					local cnt = 0 local rcnt = 0
					for i = 1,5,2 do 
						if auxi.check_all_exists(d[item.own_key.."task"][i]) then cnt = cnt + 1 end
						if d[item.own_key.."task"].fired[i] then
							if auxi.check_all_exists(d[item.own_key.."task"][i + 1]) then
								local q2d = d[item.own_key.."task"][i + 1]:GetData()
								if (q2d[item.own_key.."counter"] or 0) >= 30 then 
									Game():BombExplosionEffects(d[item.own_key.."task"][i + 1].Position,60,BitSet128(0,0))
									d[item.own_key.."task"][i + 1]:Remove()
									d[item.own_key.."task"][i]:GetData()[item.own_key.."stay"] = true
									d[item.own_key.."task"].fired[i].fired = true
								end
							end
							if d[item.own_key.."task"].fired[i].fired then rcnt = rcnt + 1 end
						end
					end
					if cnt > 0 and cnt == rcnt then skip_2_end = true end
end
					if skip_2_end then
						for i = 1,5,2 do if auxi.check_all_exists(d[item.own_key.."task"][i + 1]) then d[item.own_key.."task"][i + 1]:Remove() end end
						for i = 3,5,2 do if auxi.check_all_exists(d[item.own_key.."task"][i]) then d[item.own_key.."task"][i]:Remove() end end
						if auxi.check_all_exists(d[item.own_key.."task"][1]) then d[item.own_key.."task"][1]:GetData()[item.own_key.."stay"] = nil end
						d[item.own_key.."task"].multi = (d[item.own_key.."task"].multi or 0) - 1
						if d[item.own_key.."task"].multi <= 0 then 
							for i = 1,5,2 do if auxi.check_all_exists(d[item.own_key.."task"][i]) then d[item.own_key.."task"][i]:Remove() end end
							d[item.own_key.."task"] = nil 
						else 
							d[item.own_key.."task"].counter = d[item.own_key.."task"].base_counter or 0 d[item.own_key.."task"].fired = {} d[item.own_key.."task"].fire = {}		--d[item.own_key.."task"].init = nil 
						end
					end
				end
			end
			if ent.SubType == 3 then
				if d[item.own_key.."task"] then
					if d[item.own_key.."task"].delay then d[item.own_key.."task"].delay = d[item.own_key.."task"].delay - 1 if d[item.own_key.."task"].delay <= 0 then d[item.own_key.."task"].delay = nil else break end end
					d[item.own_key.."task"].counter = (d[item.own_key.."task"].counter or 0) + 1
					if d[item.own_key.."task"].init == nil then
						if dir:Length() < 120 then 		--过近时暂时取消
							d[item.own_key.."task"].delay = (d[item.own_key.."task"].delay or 0) + auxi.choose(15,30)
							d[item.own_key.."task"].counter = 0
							break
						else
							d[item.own_key.."task"].init = true
							for i = 1,1 do 
								local q = auxi.fire_nil(ent.Position,Vector(0,0),{cooldown = 60,remove_with_ent = ent,}) 
								local qs = q:GetSprite() qs:Load("gfx/boss/Qing/Guideline.anm2",true) qs:Play("Idle",true) q.DepthOffset = -100
								d[item.own_key.."task"][i] = q
							end
						end
					end
					for i = 1,1 do 
						if auxi.check_exists(d[item.own_key.."task"][i]) then
							d[item.own_key.."task"][i]:GetSprite().Rotation = dir:GetAngleDegrees() + 90
							d[item.own_key.."task"][i].Position = ent.Position
							--d[item.own_key.."task"][i].Velocity = ent.Velocity
							d[item.own_key.."task"][i].PositionOffset = ent.PositionOffset-- + auxi.get_by_rotate(item.multi_slot_offset[i],dir:GetAngleDegrees())
						end
					end
					if d[item.own_key.."task"].counter == 45 then 
						local ret = auxi.fire_anti_lung(ent.Position,dir:Normalized() * 25,ent,{cnt = math.random(10) + 12,})
						sound_tracker.PlayStackedSound(enums.SoundEffect.Qing_gunshoots,1,1,false,0,2)
						for u,v in pairs(ret) do v = v:ToProjectile() end
						for i = 1,1 do d[item.own_key.."task"][i]:Remove() end
						d[item.own_key.."task"].multi = (d[item.own_key.."task"].multi or 0) - 1
						if d[item.own_key.."task"].multi <= 0 then d[item.own_key.."task"] = nil 
						else d[item.own_key.."task"].init = nil d[item.own_key.."task"].counter = d[item.own_key.."task"].base_counter or 0 end
					end
				end
			end
			if ent.SubType == 4 then
				if d[item.own_key.."task"] then
					if d[item.own_key.."task"].delay then d[item.own_key.."task"].delay = d[item.own_key.."task"].delay - 1 if d[item.own_key.."task"].delay <= 0 then d[item.own_key.."task"].delay = nil else break end end
					d[item.own_key.."task"].counter = (d[item.own_key.."task"].counter or 0) + 1
					if d[item.own_key.."task"].init == nil then
						if dir:Length() < 120 then 		--过近时暂时取消
							d[item.own_key.."task"].delay = (d[item.own_key.."task"].delay or 0) + auxi.choose(15,30)
							d[item.own_key.."task"].counter = 0
							break
						else
							d[item.own_key.."task"].init = true
							local q = auxi.fire_nil(ent.Position,Vector(0,0),{cooldown = 120,remove_with_ent = ent,}) 
							local qs = q:GetSprite() qs:Load("gfx/boss/Qing/Guideline.anm2",true) qs:Play("BrimstoneIdle",true) q.DepthOffset = -100
							d[item.own_key.."task"][1] = q
						end
					end
					d[item.own_key.."task"].dir = auxi.move_in_round((d[item.own_key.."task"].dir or dir:GetAngleDegrees()),dir:GetAngleDegrees(),0.6,360)
					local tdir = d[item.own_key.."task"].dir
					s.Rotation = tdir - 90 - 45
					if d[item.own_key.."task"].counter >= 45 and d[item.own_key.."task"].fire == nil then 
						d[item.own_key.."task"].fire = true
						local cnt_list = {1,} if d[item.own_key.."task"].mode == 2 then cnt_list = {1,2,3,} end
						for u,v in pairs(cnt_list) do
							local q = Isaac.Spawn(7,1,0,ent.Position,Vector(0,0),ent):ToLaser() q.Timeout = 30 q.CollisionDamage = 0.1 q.Parent = ent
							if auxi.check_all_exists(d[item.own_key.."task"][v]) then d[item.own_key.."task"][v]:Remove() end
							d[item.own_key.."task"][v] = q
						end
					end
					local should_end = true
					for u,v in pairs({1,2,3}) do
						if d[item.own_key.."task"][v] then
							if auxi.check_exists(d[item.own_key.."task"][v]) then
								local ttsk = d[item.own_key.."task"][v]
								if ttsk.Type == 7 then 
									ttsk.Angle = tdir
									if v == 2 then ttsk.Angle = tdir + 60
									elseif v == 3 then ttsk.Angle = tdir - 60 end
								else 
									ttsk:GetSprite().Rotation = tdir + 90
									ttsk.Position = ent.Position
								end
								d[item.own_key.."task"][v].PositionOffset = ent.PositionOffset + auxi.get_by_rotate(Vector(10,0),tdir)
								should_end = false
							else
								d[item.own_key.."task"][v] = nil
							end
						end
					end
					if should_end then d[item.own_key.."task"] = nil end
				end
			end
			end
		end
	end
	if ent.Variant == enums.Enemies.QingKnife then
		local d = ent:GetData() local s = ent:GetSprite()
		local linker = d[item.own_key.."effect"].linker
		if auxi.check_all_exists(linker) ~= true then ent:Remove() return end
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		
		if d[item.own_key.."effect"].dir == nil then
			local tg = auxi.get_acceptible_target(ent) or linker
			local tgdir = tg.Position - ent.Position
			s.Rotation = auxi.move_in_round(s.Rotation + 90,tgdir:GetAngleDegrees(),5,360) - 90
			if math.abs(auxi.checkrounded2(s.Rotation + 90,tgdir:GetAngleDegrees(),1,-1,360)) < 0.2 or d[item.own_key.."effect"].counter > 30 * 6 then
				d[item.own_key.."effect"].dir = s.Rotation + 90
			end
		end
		if d[item.own_key.."effect"].dir then
			s.Rotation = d[item.own_key.."effect"].dir - 90
			ent.Velocity = ent.Velocity * 0.8 + 50 * auxi.MakeVector(d[item.own_key.."effect"].dir) * 0.2
			d[item.own_key.."effect"].counter2 = (d[item.own_key.."effect"].counter2 or 0) + 1
			if d[item.own_key.."effect"].counter2 > 30 * 20 or (linker.Position - ent.Position):Length() > 1000 then
				ent:Remove()
			end
		end
		
		ent.Velocity = auxi.apply_friction(ent.Velocity,1)
	end
end,
})

function item.fire_weapon_target(pos,ent)
	local q = auxi.fire_nil(pos,Vector(0,0),{cooldown = 999,remove_with_ent = ent,}) 
	local qs = q:GetSprite() qs:Load("gfx/boss/Qing/Target.anm2",true) qs:Play("Appear",true) q.DepthOffset = -10
	local qd = q:GetData() qd[Nil.own_key.."work"] = function(self)
		local sd = self:GetData()
		if auxi.check_all_exists(sd[item.own_key.."target"]) then 
			if auxi.check_all_exists(sd[item.own_key.."missle"]) or sd[item.own_key.."stay"] then self.Velocity = Vector(0,0)	--Missile拼错了
			else
				local sftg = sd[item.own_key.."target"] local dir = sftg.Position - self.Position
				self.Velocity = dir:Normalized() * math.min(dir:Length(),20) self.Velocity = auxi.apply_friction(self.Velocity,1)
				if dir:Length() < 30 then sd[item.own_key.."valid"] = true
				else sd[item.own_key.."valid"] = nil end
			end
		else ent.Velocity = ent.Velocity  * 0.5 end
	end
	return q
end

function item.trigger_shoot(id,ent,dir,params)
	--sound_tracker.PlayStackedSound(enums.SoundEffect.Qing_shoot,1,1,false,0,2)
	params = params or {} local power = params.power or 1 local mode = params.mode or 1 local addscale = params.addscale or 0
	if params.largeone then power = 2 addscale = 2 mode = 2 end
	if id == 1 then
		local ddir = dir:Normalized()
		local q = Isaac.Spawn(9,0,0,ent.Position,ddir * 10 * power,ent):ToProjectile() local d = q:GetData() d[item.own_key.."effect"] = {spread_tear = true,} auxi.protect_projectile(ent,q) q:AddScale(addscale)
		local q = Isaac.Spawn(9,0,0,ent.Position - ddir * 10 + auxi.get_by_rotate(ddir,90,10),ddir * 10 * power,ent):ToProjectile() local d = q:GetData() d[item.own_key.."effect"] = {} auxi.protect_projectile(ent,q) q:AddScale(addscale)
		local q = Isaac.Spawn(9,0,0,ent.Position - ddir * 10 + auxi.get_by_rotate(ddir,-90,10),ddir * 10 * power,ent):ToProjectile() local d = q:GetData() d[item.own_key.."effect"] = {} auxi.protect_projectile(ent,q) q:AddScale(addscale)
	end
	if id == 2 then 
		local q = Isaac.Spawn(9,4,0,ent.Position,dir:Normalized() * auxi.choose(5,10) * power,ent):ToProjectile() auxi.protect_projectile(ent,q) q:AddScale(addscale)
		q.Color = Color(0,1,0,1,0,0.5,0) 
		local d = q:GetData()
		d[item.own_key.."effect"] = {green_creep = true,}
	end
	if id == 3 then
		local rnd = auxi.choose(2,3) local mxcnt = 8 if mode == 2 then mxcnt = 4 end
		for i = 1,mxcnt do 
			local q = Isaac.Spawn(9,0,0,ent.Position,auxi.get_by_rotate(dir,(i - (mxcnt + 1)/2) * 15,rnd * power),ent):ToProjectile() auxi.protect_projectile(ent,q) q:AddScale(addscale)
			q.Color = Color(1,1,0,1,1,0.5,0) q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.SHIELDED 
			if mode == 2 then q.FallingAccel = -0.1 end
			local d = q:GetData() d[item.own_key.."effect"] = {}
		end
	end
	if id == 4 then
		local rnd = auxi.choose(3,5,7) local delay = 6 if mode == 2 then delay = 15 dir = auxi.random_r() end
		local q = Isaac.Spawn(9,0,0,ent.Position,auxi.get_by_rotate(dir,-60,rnd * power),ent):ToProjectile() q.Color = Color(0,1,1,1,0,0.5,1) q:GetData()[item.own_key.."effect"] = {shoot = {dir = auxi.get_by_rotate(dir,90,10),delay = delay,},offset = 0,} auxi.protect_projectile(ent,q) q:AddScale(addscale)
		local q = Isaac.Spawn(9,0,0,ent.Position,auxi.get_by_rotate(dir,60,rnd * power),ent):ToProjectile() q.Color = Color(0,1,1,1,0,0.5,1) q:GetData()[item.own_key.."effect"] = {shoot = {dir = auxi.get_by_rotate(dir,-90,10),delay = delay,},offset = 3,} auxi.protect_projectile(ent,q) q:AddScale(addscale)
	end
	if id == 5 then
		local q = Isaac.Spawn(9,0,0,ent.Position,auxi.get_by_rotate(dir,0,4 * power),ent):ToProjectile() q.Color = Color(1,0.2,0.4,1,0.8,0,0.4) q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.SMART auxi.protect_projectile(ent,q) q:AddScale(addscale)
		local d = q:GetData() d[item.own_key.."effect"] = {}
		if mode == 2 then q.FallingAccel = -0.08 end
	end
end

function item.try_insert_target_list(list,tg)
	for u,v in pairs(list) do 
		if auxi.check_for_the_same(v.target,tg) == true then return u end
	end
	table.insert(list,{target = tg,})
	return #list
end
--l local q = Isaac.Spawn(9,0,0,Vector(200,200),Vector(10,0),nil):ToProjectile() q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.ORBIT_PARENT q.SpawnerEntity = Game():GetPlayer(0)
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PROJECTILE_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if d[item.own_key.."effect"].green_creep and ent.FrameCount % 5 == 3 then
			local q = Isaac.Spawn(1000,23,0,ent.Position,Vector(0,0),ent):ToEffect() q.Timeout = 50
		end
		if d[item.own_key.."effect"].spread_tear and ent.FrameCount % 6 == 3 then
			local q = Isaac.Spawn(9,0,0,ent.Position,Vector(0,0),ent):ToProjectile() auxi.protect_projectile(ent,q)
		end	
		if d[item.own_key.."effect"].shoot then 
			if ((d[item.own_key.."effect"].offset or 0) + ent.FrameCount) % (d[item.own_key.."effect"].shoot.delay or 6) == 3 then
				local q = Isaac.Spawn(9,0,0,ent.Position,d[item.own_key.."effect"].shoot.dir,ent):ToProjectile() q.Color = Color(0,0.7,0.7,1,0,0.3,0.7) auxi.protect_projectile(ent,q)
			end
		end
		if ent:IsDead() and auxi.random_1() < 0.3 then
			local q = Isaac.Spawn(1000,5,0,ent.Position,Vector(0,0),ent):ToEffect() q.Color = ent.Color
		end
	end
	if d[item.own_key.."weapon"] then
		if d[item.own_key.."weapon"].remove_self and ent:IsDead() then
			ent:Remove() return
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PROJECTILE_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local d = ent:GetData()
	if d[item.own_key.."weapon"] then
		if d[item.own_key.."weapon"].remove_self then
			ent:Remove() return
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_NPC_COLLISION, params = 996,
Function = function(_,ent,col,low)
	if ent.Variant == enums.Enemies.QingHelper2 and (col.Type == 996) then return true end
	if col.Variant == enums.Enemies.QingHelper2 and col.Type == 996 and (ent.Type == 996) then return true end
	
	if ent.Variant == enums.Enemies.QingHelper and (col.Type == 1 or col.Type == 996) then return true end
	if col.Variant == enums.Enemies.QingHelper and col.Type == 996 and (ent.Type == 996 or ent.Type == 1) then return true end
end,
})
--d[item.own_key.."effect"].flip = d[item.own_key.."effect"].flip or auxi.choose(1,-1)
--ent.Velocity = (auxi.get_by_rotate(dir,90 * d[item.own_key.."effect"].flip,100) * (1 - prate) + dir:Normalized() * (dir:Length() - 100)) * 0.2
--local prate = math.min(1,math.abs(dir:Length() - 100)/100)
--ent.Velocity = ent.Velocity * 0.6 + target_dir:Normalized() * (target_dir:Length() - 20)) * 0.2
--local dang = auxi.checkrounded2(((td[item.own_key.."effect"].counter or 0) + id * 360/math.max(1,#td[item.own_key.."effect"].air_list)),dir:GetAngleDegrees(),1,-1,360)
--local prate = 1 - math.min(1,math.abs(dir:Length() - 100)/100) - dang/360 * 2
--ent.Velocity = ent.Velocity * 0.5 + 0.5 * ((auxi.get_by_rotate(dir,90 * 1,100) * prate + dir:Normalized() * (dir:Length() - 100)) * 0.2)
--l local player = Game():GetPlayer(0) local d = player:GetData() local item = require("Qing_Remaster_scripts.bosses.Boss_Qing") print(#d[item.own_key.."effect"].air_list)

function item.load_air(filename,ent)
	filename = filename or item.get_air_texture(ent.SubType)
	s:Load("gfx/boss/Qing/Air.anm2",true) s:ReplaceSpritesheet(0,filename) s:LoadGraphics() s:Play("Idle",true)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 996,
Function = function(_,ent,amt,flag,source,cooldown)
	if ent.Variant == enums.Enemies.QingHelper or ent.Variant == enums.Enemies.QingHelper2 then
		--local d = ent:GetData() d[item.own_key.."hitsound"] = d[item.own_key.."hitsound"] or auxi.choose(0.7,0.75,0.8)
		--if d[item.own_key.."hit_counter"] == nil then sound_tracker.PlayStackedSound(enums.SoundEffect.Qing_Hit,auxi.choose(1.4,1.5,1.6),d[item.own_key.."hitsound"],false,0,2) d[item.own_key.."hit_counter"] = auxi.choose(0,2,4,6) end
	end
	if ent.Variant == item.entity then
		local d = ent:GetData()
		local total_damage = Damage_holder.on_damage(ent,amt,flag,source,cooldown)
		if d[item.own_key.."effect"].should_leave then return false end
		if total_damage > ent.HitPoints then ent.HitPoints = 1 d[item.own_key.."effect"].should_leave = true local s = ent:GetSprite() s:Play("Break",true) return false end
	end
end,
})
	
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = 996,
Function = function(_,ent)
	if ent.Variant == enums.Enemies.QingHelper or ent.Variant == enums.Enemies.QingHelper2 then
		local rnd = auxi.choose(0,3,5)
		for i = 1,rnd do
			local q = Isaac.Spawn(1000,86,0,ent.Position,auxi.random_r() * auxi.random_1() * 6,nil):ToEffect() q.FallingSpeed = auxi.random_1() * 12 - 6
			local s = q:GetSprite() local anim = s:GetAnimation() s:ReplaceSpritesheet(0,"gfx/effects/gibs/metal_gibs.png") s:LoadGraphics() s:SetFrame(anim,0)
		end
		if ent.Variant == enums.Enemies.QingHelper then
			local d = ent:GetData() local dir = d[item.own_key.."record_dir"] or auxi.random_r()
			local rnd = auxi.choose(1,2)
			for i = 1,rnd do
				local q = Isaac.Spawn(1000,86,0,ent.Position,dir:Normalized() * 10 + auxi.random_r() * auxi.random_1() * 3,nil):ToEffect() q.FallingSpeed = auxi.random_1() * 12 - 12
				local s = q:GetSprite() local anim = s:GetAnimation() s:ReplaceSpritesheet(0,"gfx/effects/gibs/metal_gibs.png") s:LoadGraphics() s:SetFrame(anim,0) s.Color = item.num2realcolor[ent.SubType] or Color(1,1,1,1)
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
		item.start(ent)
		ent.PositionOffset = Vector(0,-10)
		ent.SizeMulti = Vector(1,1.5)
		--AI.move2pos(ent,,15)
	end
	if ent.Variant == enums.Enemies.QingHelper then
		local s = ent:GetSprite() 
		if ent.SubType == 0 then ent.SubType = auxi.choose(1,2,3,4,5) end
		local filename = item.get_air_texture(ent.SubType)
		s:Load("gfx/boss/Qing/Air.anm2",true) s:ReplaceSpritesheet(0,filename) s:LoadGraphics() s:Play("Appear",true)
		s.Rotation = 0
		ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
		ent.PositionOffset = Vector(0,-100)
	end
	if ent.Variant == enums.Enemies.QingHelper2 then
		local s = ent:GetSprite() 
		if ent.SubType == 0 then ent.SubType = auxi.choose(1,2,3,4) end
		local filename = "gfx/boss/Qing/Air_Hand" .. tostring(ent.SubType) .. ".png"
		s:Load("gfx/boss/Qing/Arms.anm2",true) s:ReplaceSpritesheet(0,filename) s:LoadGraphics() s:Play("Idle",true)
		s.Rotation = 0
		ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
		ent.PositionOffset = Vector(0,-20)
	end
end,
})

return item

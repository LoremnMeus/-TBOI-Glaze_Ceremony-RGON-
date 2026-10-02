local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local collector = require("Qing_Remaster_scripts.others.Parent_Collect_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local own_key = "Extra_Mixture_data_"

-- 全局调试：查询 MIX50 当前/历史中间量。
-- 用法：
--   _G.MIX50_probe(ent)                 -- 传入 Entity/NPC
--   _G.MIX50_probe_by_ptr(ptrHash)      -- 传入 ent:GetPtrHash()，会在房间里查找
-- 返回 table 并打印一行摘要。
--
-- prev1/prev2/closing 在 item[1][50].set_offset 里推进。MIX50_probe 会先调用该 set_offset(0, ent)
-- 用当前 PositionOffset 同步 hist，再读数打印（与 Boss 管线里算 offset 后的状态一致）。
_G.MIX50_probe = function(ent)
    if ent == nil then
        ent = _G.MIX50_last_ent
    end
    if not ent or (ent.Exists and not ent:Exists()) then
        print("[MIX50] invalid entity")
        return nil
    end
    local blended = nil
    if _G.MIX50_apply_offset_hist then
        blended = _G.MIX50_apply_offset_hist(ent)
    end
    local d = ent:GetData()
    local hist = (d and d.MIX50_hist) or {}
    local y = ent.PositionOffset and ent.PositionOffset.Y or 0
    local y1 = hist.prev1_y or y
    local y2 = hist.prev2_y or y1
    local close_y = hist.closing_y
    local gfc = Game():GetFrameCount()
    local rfc = Game():GetRoom():GetFrameCount()

    -- 与 item[1][50].set_offset 一致（仅影响打印；hist 已由 set_offset 更新）
    local POS_W = (_G.MIX50_POS_W ~= nil) and _G.MIX50_POS_W or 0.5
    local VEL_W_GT0 = (_G.MIX50_VEL_W_GT0 ~= nil) and _G.MIX50_VEL_W_GT0 or 5
    local VEL_W_LE0 = (_G.MIX50_VEL_W_LE0 ~= nil) and _G.MIX50_VEL_W_LE0 or 3
    local VEL_ADD = (_G.MIX50_VEL_ADD ~= nil) and _G.MIX50_VEL_ADD or 0.2
    local ACC_FIX = (_G.MIX50_ACC_FIX ~= nil) and _G.MIX50_ACC_FIX or 0.4
    local ADD = (_G.MIX50_ADD ~= nil) and _G.MIX50_ADD or 0

    local pos_term = POS_W * y
    local vel_raw = (y - y1)
    local vel_adj = vel_raw + VEL_ADD
    local VEL_W = (vel_adj > 0) and VEL_W_GT0 or VEL_W_LE0
    local vel_term = VEL_W * vel_adj
    local acc_raw = (y - 2 * y1 + y2)
    local acc_term = ACC_FIX
    local total = pos_term + vel_term + acc_term + ADD

    local ret = {
        ptr = ent.GetPtrHash and ent:GetPtrHash() or nil,
        type = ent.Type, variant = ent.Variant, subtype = ent.SubType,
        frame = gfc, room_frame = rfc,
        y = y, y_prev1 = y1, y_prev2 = y2, closing_y = close_y,
        pos_w = POS_W, vel_w = VEL_W, vel_w_gt0 = VEL_W_GT0, vel_w_le0 = VEL_W_LE0,
        vel_add = VEL_ADD, vel_adj = vel_adj, acc_fix = ACC_FIX, add = ADD,
        vel_raw = vel_raw, acc_raw = acc_raw,
        pos_term = pos_term, vel_term = vel_term, acc_term = acc_term,
        result = total,
        set_offset_blend = blended,
    }
    local blend_s = (blended ~= nil) and string.format("%.3f", blended) or "n/a"
    print(string.format(
        "[MIX50] ptr=%s tvs=%s.%s.%s gfc=%d rfc=%d y=%.3f p1=%.3f p2=%.3f close=%s blend=%s | d1=%.3f adj=%.3f vw=%.3f d2=%.3f | pos=%.3f vel=%.3f acc=%.3f add=%.3f total=%.3f",
        tostring(ret.ptr), tostring(ret.type), tostring(ret.variant), tostring(ret.subtype),
        gfc, rfc,
        ret.y, ret.y_prev1, ret.y_prev2, close_y ~= nil and string.format("%.3f", close_y) or "nil",
        blend_s,
        ret.vel_raw, ret.vel_adj, ret.vel_w, ret.acc_raw,
        ret.pos_term, ret.vel_term, ret.acc_term, ret.add, ret.result
    ))
    return ret
end

_G.MIX50_probe_by_ptr = function(ptr)
    if ptr == nil then
        print("[MIX50] ptr is nil")
        return nil
    end
    local ents = Isaac.GetRoomEntities()
    for _, e in pairs(ents) do
        if e and e.GetPtrHash and e:GetPtrHash() == ptr then
            return _G.MIX50_probe(e)
        end
    end
    print("[MIX50] ptr not found: "..tostring(ptr))
    return nil
end

--copy_sprite 似乎会让内存泄漏？或许得修复一下
local item = {
    [1] = {
        [1] = {
            level = 1,          --最早出现的章节（1-6），默认值是1。
            strength = 100,     --主观强度评分，默认值50，100为强大（只对Boss评分）。强度主要取决于招式复杂度/复制数量等。对于敌人的某些部件，强度评级不会高于30。会对于sin标签的敌人，计算方式不太一致。每层level大概会使strength评分+10。
            --需要设置，让subtype相同的敌人均分稍大一点的概率，而不是享有总和N倍的概率
            is_multi = true,    --is_multi参数标记所有“必须是复数出现”的敌人。在Danger的生成中，会出现复数份拷贝。
            --缝合敌人中最多只能有1个部分具有这个标签？
            --有些敌人会生成自己的复制，用can_multi标记。当他们与is_multi/can_multi标签的敌人组合时，那些复制不会追加部件（防止复数复制）

            --no_conduct条件下，is_multi表现与can_multi一致，不对本身的拷贝进行复制。
            --非no_conduct条件下，复制后生成结果必然是no_conduct条件。
            larry = true,
            AfterHitpoints = function(val)      --要加入吗？
                return val * auxi.choose(0.3,0.5,0.7)
            end,
            NotSelf = true,
            swap_weight = 5,      --用于指导位置所占用的offset强度。5意味着极高。
            is_offset = true,       --这个参数让其offset作为基础值而不是参与作差。（需要保证这个值不会变化）
            order = function(ent) if ent.ParentNPC then return 999 else return -1 end end,
            rnds = 0.7,
            rnds_add = 0.3,
            check_parent = true,        --!!这个标签是做什么用的？
            follow_gridcollision = function(ent,tgent)      --需要保证，无缝合的体节也能跟随
                local room = Game():GetRoom()
                if ent.ParentNPC and (tgent.Position - room:GetClampedPosition(tgent.Position,-20)):Length() > 0.1 then return true end
            end,
            protect_pos = true,
            delta_pos = function(ent)
                local thisd = ent:GetData()
                if ent.ParentNPC then
                    local last_p = auxi.get_last_parentnpc(ent)
                    local controller = require("Qing_Remaster_scripts.auxiliary.native_mixture.controller")
                    local linker = controller.get_linker_for(last_p)
                    if auxi.check_all_exists(linker) then
                        return (linker.Position - last_p.Position) + auxi.ProtectVector(thisd[own_key.."AddPos"] or Vector(0,0))
                    end
                end
            end,
            special_collision = function(ent,col,low,ment)      --用于修复过近时对玩家造成伤害的bug
                if ent.ParentNPC then
                    local succ = false
                    for playerNum = 1, Game():GetNumPlayers() do
                        local player = Game():GetPlayer(playerNum - 1)
                        if (ent.Position - player.Position):Length() < 40 then succ = true break end
                    end
                    if succ then
                        local colclass = ent.EntityCollisionClass
                        local last_p = auxi.get_last_parentnpc(ent)
                        local controller = require("Qing_Remaster_scripts.auxiliary.native_mixture.controller")
                        local linker = controller.get_linker_for(last_p)
                        if auxi.check_all_exists(linker) then
                            colclass = linker.EntityCollisionClass
                        else
                            colclass = last_p.EntityCollisionClass
                        end

                        if col:ToPlayer() and colclass == 0 then return {ret = true,} end
                    end
                end
                if col:ToNPC() and ent:ToNPC() then
                    if collector.is_in_the_same_npc_group(col:ToNPC(), ent)
                        or auxi.check_for_the_same(auxi.get_last_parentnpc(col:ToNPC()), auxi.get_last_parentnpc(ent))
                    then
                        return {ret = true,}
                    end
                end
            end,
            --实测，两只Larry Jr应该可以互相穿过才对。
            check_collisionclass = function(ent,colclass)
                if ent.ParentNPC then
                    local last_p = auxi.get_last_parentnpc(ent)
                    local controller = require("Qing_Remaster_scripts.auxiliary.native_mixture.controller")
                    local siblings = controller.get_sibling_linkees(ent)
                    if #siblings > 0 then
                        for i = 1, #siblings do
                            local sibling = siblings[i]
                            if auxi.check_all_exists(sibling) then
                                colclass = sibling.EntityCollisionClass
                            end
                        end
                    else
                        colclass = last_p.EntityCollisionClass
                    end
                    return colclass
                end
            end,
            special = function(ent)
                local thisd = ent:GetData()
                thisd[own_key.."Pos"] = auxi.Vector2Table(ent.Position)
                if ent.ParentNPC then
                    thisd[own_key.."GridCollision"] = thisd[own_key.."GridCollision"] or Attribute_holder.try_hold_attribute(ent,"GridCollisionClass",function(ent)
                        local c1 = auxi.get_last_parentnpc(ent).GridCollisionClass
                        local room = Game():GetRoom()
                        local controller = require("Qing_Remaster_scripts.auxiliary.native_mixture.controller")
                        local ment = controller.get_linker_for(ent)
                        if auxi.check_all_exists(ment) then
                            local grid = room:GetGridEntity(room:GetGridIndex(ment.Position))
                            if grid and grid:ToPoop() then c1 = 0 end
                            c1 = controller.elect_grid_collision(c1,ment.GridCollisionClass)
                        end
                        return c1
                    end)
                    --l local tgs = Isaac.GetRoomEntities() for u,v in pairs(tgs) do if v.Type == 19 then v = v:ToNPC() local room = Game():GetRoom() local grid = room:GetGridEntity(room:GetGridIndex(v:GetData()["MSE_Boss_Mixturer_linkee"].linker.Position)) if grid and grid:ToPoop() then print(0) end end end
                    local last_p = auxi.get_last_parentnpc(ent)
                    local dpos = auxi.ProtectVector(last_p:GetData()[own_key.."Pos"] or last_p.Position)
                    local room = Game():GetRoom()
                    if thisd[own_key.."AddPos"] then
                        local p1 = auxi.ProtectVector(thisd[own_key.."AddPos"]) + ent.Position
                        local p2 = room:GetClampedPosition(p1,0)
                        ent.Position = p2
                        local dp = p1 - p2
                        if dp:Length() < 0.1 then thisd[own_key.."AddPos"] = nil
                        else thisd[own_key.."AddPos"] = auxi.Vector2Table(dp) end
                    end
                    if (last_p.Position - dpos):Length() > 100 then
                        local p1 = ent.Position + last_p.Position - dpos local p2 = room:GetClampedPosition(p1,0)
                        thisd[own_key.."AddPos"] = auxi.Vector2Table(auxi.ProtectVector(thisd[own_key.."AddPos"] or Vector(0,0)) + p1 - p2)
                        ent.Position = p2
                    end
                else
                    if thisd[own_key.."GridCollision"] then Attribute_holder.try_rewind_attribute(ent,"GridCollisionClass",thisd[own_key.."GridCollision"]) thisd[own_key.."GridCollision"] = nil end
                end
            end,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                if source and source.Entity then
                    local se = source.Entity
                    while(se:ToNPC() == nil and se.SpawnerEntity) do
                        se = se.SpawnerEntity
                    end
                    if se:ToNPC() then
                        if collector.is_in_the_same_npc_group(se:ToNPC(), tent or ent)
                            or auxi.check_for_the_same(auxi.get_last_parentnpc(se:ToNPC()), auxi.get_last_parentnpc(ent))
                        then
                            return false
                        end
                    end
                end
            end,
            --不移动(-2)<任意移动(-1)<接近玩家(0)<向玩家冲刺(0.5)<大冲刺(1)<大跳/传送(2-5)<跟随父节点(999)
            --控制者发生传送/大跳时已停止另一方的运动
            --已设置，造成的伤害不会涉及同一链路上的本体。
            --奇怪的情况，pin的血量怎么是单独计算的
            --如何突破敌人生成小怪数量的限制？只能手动操作。
            --UpdateDirtColor 这个函数对pin无效
            --例如饥荒的冲刺时，从另一侧出现的效果已应用到同一条链路上的所有个体。
            --已规制，防止larry jr到达房间之外，否则其尝试生成地形时会发生崩溃。
            --78 妈心无法使其生成
        },
        [2] = {
            check = 1,
            alt = true,
        },
        [3] = {
            check = 1,
            alt = true,
        },
        [4] = {
            level = 2,
            check = 1,
            Replace_with_sprite = true,     --换掉吧
            special_render_ = function(ent,linker,is_main,is_update)      --手动修正了斜向移动的情况，否则贴图会出问题
                if BACK then return end
                --if ent.V1:Length() > 0 and ent.V1.X * ent.V1.Y ~= 0 then ent.V1 = auxi.choose(Vector(5,0),Vector(0,5)) end
                local s = ent:GetSprite() local d = ent:GetData()
                local anim = s:GetAnimation()
                local animlist = {WalkBodyHori = true,WalkBodyUp = true,WalkBodyDown = true,Butt = true,}
                local dangle = math.atan(ent.V1.X/ent.V1.Y)
                local dir = ent.Velocity
                d[own_key.."Position"] = d[own_key.."Position"] or {}
                local tgid = 10
                if animlist[anim] then
                    if dir.Y * dir.X < 0 then
                        s.Rotation = 15
                    elseif dir.Y * dir.X > 0 then
                        s.Rotation = -15
                    end
                    if s.FlipX then s.Rotation = - s.Rotation end
                elseif anim == "WalkHeadHori" then
                    if ent.Velocity.Y > 0 then s.Rotation = -15 elseif ent.Velocity.Y < 0 then s.Rotation = 0 end
                else s.Rotation = 0 end
            end
        },
        [5] = {
            check = 4,
            alt = true,
        },
        [6] = {
            check = 4,
            alt = true,
        },
        [7] = {
            check = 4,
            alt = true,
        },
        [8] = {
            level = 1,
            rider = true,
            on_rider_update = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "JumpUp" and s:WasEventTriggered("Jump") then
                    ent.State = 8
                elseif anim == "JumpDown" and s:WasEventTriggered("Land") ~= true then
                    ent.State = 8
                end
            end,
            swap_weight = function(ent)
                if ent.State == 8 then return 1 end
                return 9
            end,
            special_ = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                print(ent.State.." "..anim.." "..s:GetFrame().." "..tostring(s:IsFinished(anim)))
            end,
            order = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if (anim == "JumpUp" and s:WasEventTriggered("Jump")) or (anim == "JumpDown" and s:WasEventTriggered("Land") ~= true) then return 2 end
                if ent.State == 8 then return -2
                else return -0.25 end
            end,
        },
        [9] = {
            can_multi = true,
            strength = 66,
            check = 8,
            alt = true,
        },
        [10] = {
            check = 8,
            alt = true,
        },
        [11] = {
            level = 2,
            strength = 75,
            special_collision = function(ent,col,low)
                if ent:ToNPC().ParentNPC == nil then
                    if col.Type == 4 then return {ret = nil,} end
                    if col.Type == 23 then return {ret = nil,} end
                end
            end,
            rnds = function(ent)
                if ent.State == 8 then return 1.5 end
            end,
            order = function(ent)
                if ent.ParentNPC then return 999
                else
                    if ent.State == 8 then return 1
                    else return -1 end
                end
            end,
            reload = true,
            on_search = function(info,v1,v2,v3)
                if v1 == info.type and v2 == info.variant and (v3 == info.subtype or v3 == 1000) then return true end
            end,
            special_on_uncheck = function()     --!!应该要追加老妇人生成时，为剩余体节生成
            end,
            check = 1,
        },
        [12] = {
            check = 11,
            alt = true,
        },
        [13] = {
            check = 11,
            alt = true,
        },
        [14] = {
            check = 11,
        },
        [15] = {
            special_damage = function(ent,amt,flag,source,cooldown)
                if flag & DamageFlag.DAMAGE_POOP ~= 0 then return false end
            end,
            check = 11,
        },
        [16] = {
            check = 15,
            alt = true,
        },
        [17] = {
            level = 2,
            order = -2,
            KeepTarget = true,

            rider = true,
        },
        [18] = {
            check = 17,
            alt = true,
        },
        [19] = {
            --sin = true,
            strength = 10,
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim == "Vanish" and fr > 4 then return false end
                if anim == "Vanish2" and fr < 3 then return false end
                return true
            end,
            order = function(ent,info)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if info.set_visible(ent) == false then return 5 end
                if anim == "Attack" then return -2 end
            end,
            rnds = 0.3,
        },
        [20] = {
            level = 3,
            check = 8,
            Catch_Laser = true,
        },
        [21] = {
            check = 20,
            alt = true,
        },
        [22] = {
            check = 20,
        },
        [23] = {
            level = 3,
            swap_weight = 3,
            check_all_type = true,
            is_multi = true,
            NotSpawn = true,
            follow_rotate = true,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if anim == "ArmOpen" then return {1,} end
                return {1,0,}
            end,
            pre_render = function(ent,offset1,offset2,info)
                local s = ent:GetSprite() local d = ent:GetData() d[own_key.."replace_sprite"] = d[own_key.."replace_sprite"] or Sprite()
                local anim = s:GetAnimation()
                if anim == "ArmOpen" and (s:WasEventTriggered("Appear") and s:WasEventTriggered("Disappear") == false) then
                    local s2 = auxi.copy_sprite(s,d[own_key.."replace_sprite"],{filename = "gfx/"..info.name..".anm2",on_replace = function(ts,es,params)
                        ts:ReplaceSpritesheet(1,"gfx/SE_shadow.png") ts:LoadGraphics()
                    end,})
                    s2:Render(offset2)
                end
            end,
            order = 1999,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State ~= 10 then
                    d[own_key.."rnd"] = d[own_key.."rnd"] or auxi.choose(240,300,360,480)
                    d[own_key.."base_counter"] = (d[own_key.."base_counter"] or 0) + 1
                    if d[own_key.."base_counter"] > d[own_key.."rnd"] then d[own_key.."rnd"] = auxi.choose(240,300,360,480) info.force_move(ent) end
                else d[own_key.."base_counter"] = nil end
            end,
            force_move = function(ent)
                ent.State = 10
                ent:GetSprite():Play(auxi.choose("Fat01","Fat02"),true)
            end,
            AfterHitpoints = function(val)
                return val * 0.5
            end,
            on_damage = function(ent,amt,flag,source,cooldown,tent)
                local tgs = Isaac.GetRoomEntities()
                if flag & DamageFlag.DAMAGE_CLONES == 0 then
                    for u,v in pairs(tgs) do
                        if v.Type == 45 and v.Variant == 10 then
                            local controller = require("Qing_Remaster_scripts.auxiliary.native_mixture.controller")
                            local linker = controller.get_linker_for(v)
                            if auxi.check_all_exists(linker) then
                                linker:TakeDamage(amt,flag | DamageFlag.DAMAGE_CLONES,source,cooldown)
                            else
                                v:TakeDamage(amt,flag | DamageFlag.DAMAGE_CLONES,source,cooldown)
                            end
                            break
                        end
                    end
                end
            end,
        },
        [24] = {
            check = 23,
            alt = true,
        },
        [25] = {
            check = 23,
            alt = true,
        },
        [26] = {
            level = 3,
            strength = 120,
            NotSpawn = true,
            DontSpawn = true,
            --KeepUpdate = true,
            is_multi = true,
            --!妈腿的血量要可控制
            --release_self = true,
            swap_weight = 9,
            check_all_type = true,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if s:WasEventTriggered("Shoot") == false or s:WasEventTriggered("Lift") then return false end
                return true
            end,
            HideAll = true,
            order = function(ent,info)
                if info.set_visible(ent) == false then return 5 end
                return -2
            end,
        },
        [27] = {
            check = 26,
            alt = true,
        },
        [28] = {
            check = 26,
            alt = true,
        },
        [29] = {
            sin = true,
            strength = 40,
            rnds = 0.8,
        },
        [30] = {
            level = 2,
            check = 29,
        },
        [31] = {
            level = 3,
            strength = 50,
            check = 29,
        },
        [32] = {
            sin = true,
            order = 0,
            rnds = 1.5,
        },
        [33] = {
            level = 2,
            check = 32,
        },
        [34] = {
            sin = true,
            order = -0.75,
        },
        [35] = {
            level = 1,
            check = 34,
        },
        [36] = {
            sin = true,
            Catch_Laser = true,
            rnds = 0.4,
            order = function(ent,info)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim:sub(1,6) == "Attack" then return -2 end
                if anim:sub(1,3) == "Fat" then return -2 end
            end,
        },
        [37] = {
            level = 2,
            check = 36,
        },
        [38] = {
            sin = true,
            rnds = 0.5,
        },
        [39] = {
            level = 2,
            check = 38,
        },
        [40] = {
            sin = true,
            strength = 90,
            rnds = 0.75,
            order = -0.75,
            spawn_power = 1,
            only_split = function(se,sinfo,iinfo)
                local rate = sinfo.spawn_power or 1
                local ret = 0.5
                if iinfo then
                    if iinfo.is_multi then ret = ret * (1 - rate) + rate * 0.1 end
                    if iinfo.can_multi then ret = ret * (1 - rate) + rate * 0.2 end
                end
                return ret
            end,
        },
        [41] = {
            check = 40,
            spawn_power = 0.7,
            strength = 60,
        },
        [42] = {
            check = 40,
            spawn_power = 0.4,
            strength = 30,
        },
        [43] = {
            check = 40,
            spawn_power = 0.2,
            strength = 10,
        },
        [44] = {
            level = 2,
            check = 40,
        },
        [45] = {
            level = 2,
            check = 41,
        },
        [46] = {
            level = 2,
            check = 42,
        },
        [47] = {
            level = 2,
            check = 43,
        },
        [48] = {
            sin = true,
            rnds = 0.7,
        },
        [49] = {
            level = 2,
            check = 48,
        },
        [50] = {
            level = 1,
            DontSpawn = nil,
            NotSpawn = nil,
            strength = 150,
            is_multi = true,
            no_shade = true,
            swap_weight = 5,
            swap_rate = 999,
            check_parent = true,
            --- 由 Parent_Collect_holder.search_for_linkage 连通的缝合部件 + 链上未进 effect 的实体，与 Boss_Mixturer.apply_shared_link_hp 同步血量并共死
            shared_link_hp = true,
            --- POST_NPC_INIT 时精灵尚未稳定：只打 defer_mix_rider 标记，首帧 NPC_UPDATE 再缝合/骑乘；背景节 anim 为 Ground 时不触发
            defer_mix_rider_first_update = true,
            defer_mix_rider_skip_anim = "Ground",
            defer_mix_rider_ready = function(ent, info)
                local anim = ent:GetSprite() and ent:GetSprite():GetAnimation() or ""
                local skip = info.defer_mix_rider_skip_anim or "Ground"
                if type(skip) == "table" then
                    for _, a in ipairs(skip) do
                        if anim == a then return false end
                    end
                    return true
                end
                if anim == skip then return false end
                return true
            end,
            Nature_Spawner = 1,
            set_offset = function(val,ent)
                local anim = ent:GetSprite():GetAnimation()
                if anim:sub(1,6) == "Attack" then
                    local dd = ent:GetData()
                    if dd then
                        dd.MIX50_hist = nil
                    end
                    return 0
                end
                -- 自动记录当前被计算实体，便于 _G.MIX50_probe() 直接查看
                _G.MIX50_last_ent = ent
                if ent and ent.GetPtrHash then _G.MIX50_last_ptr = ent:GetPtrHash() end
                -- 位置项：POS_W * y(t)
                -- 一阶项：VEL_W * (y(t)-y(t-1)+VEL_ADD)；vel_adj>0 时用 MIX50_VEL_W_GT0，否则 MIX50_VEL_W_LE0
                -- 加速度项：固定 ACC_FIX；差分二阶在边界不可信，不再使用
                local POS_W = (_G.MIX50_POS_W ~= nil) and _G.MIX50_POS_W or 0.5
                local VEL_W_GT0 = (_G.MIX50_VEL_W_GT0 ~= nil) and _G.MIX50_VEL_W_GT0 or 5
                local VEL_W_LE0 = (_G.MIX50_VEL_W_LE0 ~= nil) and _G.MIX50_VEL_W_LE0 or 3
                local VEL_ADD = (_G.MIX50_VEL_ADD ~= nil) and _G.MIX50_VEL_ADD or 0.2
                local ACC_FIX = (_G.MIX50_ACC_FIX ~= nil) and _G.MIX50_ACC_FIX or 0.4
                local ADD = (_G.MIX50_ADD ~= nil) and _G.MIX50_ADD or 0
                local self_y = ent.PositionOffset.Y
                local d = ent:GetData()
                d.MIX50_hist = d.MIX50_hist or {}
                local hist = d.MIX50_hist
                local fc = Game():GetFrameCount()

                -- 同一帧会多次调用 set_offset：用上一拍结束时的 closing_y 滚 prev，避免 prev1 卡死。
                -- 控制台下调 GetFrameCount() 可能不变；若当前 y 与上次记录 closing_y 不同，视为又前进了一拍（如 Room:Update）。
                if hist.last_fc == nil then
                    hist.prev1_y = self_y
                    hist.prev2_y = self_y
                    hist.closing_y = self_y
                    hist.last_fc = fc
                elseif fc < hist.last_fc then
                    hist.prev1_y = self_y
                    hist.prev2_y = self_y
                    hist.closing_y = self_y
                    hist.last_fc = fc
                elseif fc > hist.last_fc or self_y ~= hist.closing_y then
                    local y_close = hist.closing_y
                    if y_close == nil then
                        y_close = hist.prev1_y
                    end
                    hist.prev2_y = hist.prev1_y
                    hist.prev1_y = y_close
                    hist.last_fc = fc
                end

                local prev1 = hist.prev1_y or self_y
                local vel_adj = self_y - prev1 + VEL_ADD
                local VEL_W = (vel_adj > 0) and VEL_W_GT0 or VEL_W_LE0
                hist.closing_y = self_y

                return POS_W * self_y + VEL_W * vel_adj + ADD
            end,
            set_anm2 = {0,1,},
            --set_scale = true,
            set_visible = function(ent)
                if ent.ParentNPC == nil then
                    local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                    if anim == "Attack1" then if fr >= 86 then return false else return true end end
                end
                if ent.ParentNPC and ent.PositionOffset.Y == ent.ParentNPC.PositionOffset.Y and ent.PositionOffset.Y > 14 then return false end
                if ent.PositionOffset.Y > 5 then return false else return true end
            end,
            rnds = 2,
            order = function(ent,info)
                if ent.ParentNPC then return 999
                elseif info.set_visible(ent) == false then return 999 else
                    local anim = ent:GetSprite():GetAnimation()
                    if anim == "Attack1" then return -1 else return 2 end
                end
            end,
        },
        [51] = {
            check = 50,
            alt = true,
        },
        [52] = {
            level = 4,
            check = 50,
            set_anm2 = {0,1,2,},
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim == "Attack1" then if fr >= 89 then return false else return true end end
                if anim == "Attack2" then if fr >= 54 then return false else return true end end
                if ent.ParentNPC and ent.PositionOffset.Y == ent.ParentNPC.PositionOffset.Y and ent.PositionOffset.Y > 14 then return false end
                if ent.PositionOffset.Y > 5 then return false else return true end
            end,
            order = function(ent,info)
                if ent.ParentNPC then return 999
                elseif info.set_visible(ent) == false then return 999 else
                    local anim = ent:GetSprite():GetAnimation()
                    if anim == "Attack1" or anim == "Attack2" then return -1 else return 2 end
                end
            end,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if anim == "Attack1" then return {0,2,} end
            end,
        },
        [53] = {
            level = 2,
            check = 50,
            set_anm2 = {0,1,2,3,4,5},
            load_anm2 = function(id,ent,prefix)
                local ve = auxi.get_parentnpc_list(ent)[1] or ent
                if ve.I2 ~= 0 then
                    if id < 5 then return "gfx/Bosses/Afterbirth/Boss_TheFrail2.png" end
                end
            end,
            order = function(ent,info)
                if ent.ParentNPC then return 999
                elseif info.set_visible(ent) == false then return 999 else
                    local anim = ent:GetSprite():GetAnimation()
                    if anim == "Attack1" or anim == "Attack2" or anim == "Attack3Charge" then return 0
                    elseif string.sub(anim, 1, 12) == "Attack3Shoot" then return -1
                    else return 2 end
                end
            end,
            protect_self = true,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if anim == "Attack2" or anim == "Attack3Charge" then return {0,1,} end
                if string.sub(anim, 1, 12) == "Attack3Shoot" then return {0,1,} end
            end,
        },
        [54] = {
            check = 53,
            load_anm2 = function(id,ent,prefix)
                if id < 5 then return "gfx/Bosses/Afterbirth/Boss_TheFrail2_black.png" end
            end,
            alt = true,
        },
        [55] = {
            level = 1,
            is_dash = true,
            is_offset = true,
            rnds = function(ent,info)
                if ent.State == 8 then return 1
                else return 0.5 end
            end,
            order = function(ent,info)
                if ent.State == 8 then return 1 end
                if ent.State == 9 then return -2 end
            end,
            no_overlay = true,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State == 8 and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 13
                ent:GetSprite():Play("Attack1",true)
            end,
        },
        [56] = {
            check = 55,
            alt = true,
        },
        [57] = {
            level = 2,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if string.sub(anim,1,8) == "Headless" then return {0,}
                else return {0,1,} end
            end,
            rnd = 0.6,
            is_offset = true,
        },
        [58] = {
            check = 57,
            alt = true,
        },
        [59] = {        --切阶段时会换颜色？
            level = 3,
            is_dash = true,
            check_all_type = true,
            special_on_uncheck = function(ent)
                ent.SubType = 0
            end,
            real_tg_layer = {2,0,},
            swap_weight = function(ent)
                if ent.State == 6 then return 9 end
            end,
            order = function(ent,info)
                if ent.State == 6 then return 2 end
                if ent.State == 9 then return 1 end
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State == 9 and not is_main then
                    d[own_key.."rnd"] = d[own_key.."rnd"] or auxi.choose(120,180,240)
                    d[own_key.."base_counter"] = (d[own_key.."base_counter"] or 0) + 1
                    if d[own_key.."base_counter"] > d[own_key.."rnd"] then d[own_key.."rnd"] = auxi.choose(120,180,240) info.force_move(ent) end
                else d[own_key.."base_counter"] = nil end
            end,
            force_move = function(ent)
                ent.State = 9
                ent:GetSprite():Play("Attack2",true)
            end,
        },
        [60] = {
            check = 59,
            special_on_uncheck = function(ent)
                ent.SubType = 1
            end,
            alt = true,
        },
        [61] = {
            level = 4,
            check = 59,
            Force_Not_Spawn_Info = function(ent,es)
                if es.Type == 65 then return true end
            end,
        },
        [62] = {
            level = 3,
            strength = 15,
            reload = true,
            real_tg_layer = {1,0,},
            order = 0,
            rnds = 0.3,
            --NoDeliTexture = function(str)     --它没有下半身的替换贴图
            --end,
        },
        [63] = {
            check = 62,
            alt = true,
        },
        [64] = {
            level = 4,
            check_all_type = true,
            is_offset = true,
            special_on_uncheck = function(ent)
                ent.SubType = 0
            end,
            order = -2,
        },
        [65] = {
            check = 64,
            special_on_uncheck = function(ent)
                ent.SubType = 1
            end,
            alt = true,
        },
        [66] = {
            level = 4,
            order = -0.75,
            strength = 5,
            --NotSpawn = true,
        },
        [67] = {
            check = 66,
            alt = true,
        },
        [68] = {
            level = 4,
            strength = 25,
            order = -2,
            reload = true,
        },
        [69] = {
            check = 68,
            alt = true,
        },
        [70] = {
            level = 1,
            is_offset = true,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State ~= 13 then
                    d[own_key.."rnd"] = d[own_key.."rnd"] or auxi.choose(180,240,300)
                    d[own_key.."base_counter"] = (d[own_key.."base_counter"] or 0) + 1
                    if d[own_key.."base_counter"] > d[own_key.."rnd"] then d[own_key.."rnd"] = auxi.choose(180,240,300) info.force_move(ent) end
                else d[own_key.."base_counter"] = nil end
            end,
            order = -1,
            rnds = 0.5,
            force_move = function(ent)
                ent.State = 13
                ent:GetSprite():Play("Attack1",true)
            end,
        },
        [71] = {
            check = 70,
            alt = true,
        },
        [72] = {
            check = 70,
            alt = true,
        },
        [73] = {
            level = 2,
            rnds = 0.75,
            check = 70,
        },
        [74] = {
            check = 73,
            alt = true,
        },
        [75] = {
            check = 73,
            order = -0.75,
            alt = true,
        },
        [76] = {
            level = 2,
            swap_weight = function(ent)
                if ent.State == 6 or ent.State == 7 then return 9 end
            end,
            order = function(ent,info)
                if ent.State == 6 or ent.State == 7 then return 2 end
            end,
            rnds = 0.3,
            check_reload = function(ent)
                local d = ent:GetData()
                if (d[own_key.."eye"] or 0) ~= ent.I1 then return true end
            end,
            on_reload = function(ent)
                local d = ent:GetData()
                d[own_key.."eye"] = ent.I1
            end,
            get_anm2 = {0,},
            load_anm2 = function(id,ent,prefix,info)
                if id == 0 then
                    if ent.I1 == 0 then return "gfx/Bosses/Classic/Boss_027_Peep.png"
                    elseif ent.I1 == 1 then return "gfx/Bosses/Classic/Boss_027_Peep_b.png"
                    else return "gfx/Bosses/Classic/Boss_027_Peep_c.png" end
                end
            end,
            rnds = 0.3,
        },
        [77] = {
            check = 76,
            load_anm2 = function(id,ent,prefix,info)
                if id == 0 then
                    if ent.I1 == 0 then return "gfx/Bosses/Classic/Boss_027_Peep_yellow.png"
                    elseif ent.I1 == 1 then return "gfx/Bosses/Classic/Boss_027_Peep_b_yellow.png"
                    else return "gfx/Bosses/Classic/Boss_027_Peep_c_yellow.png" end
                end
            end,
            alt = true,
        },
        [78] = {
            check = 76,
            load_anm2 = function(id,ent,prefix,info)
                if id == 0 then
                    if ent.I1 == 0 then return "gfx/Bosses/Classic/Boss_027_Peep_cyan.png"
                    elseif ent.I1 == 1 then return "gfx/Bosses/Classic/Boss_027_Peep_b_cyan.png"
                    else return "gfx/Bosses/Classic/Boss_027_Peep_c_cyan.png" end
                end
            end,
            alt = true,
        },
        [79] = {
            level = 3,
            strength = 65,
            swap_weight = function(ent)
                if ent.State == 6 or ent.State == 7 then return 9 end
            end,
            order = function(ent,info)
                if ent.State == 6 or ent.State == 7 then return 2 end
            end,
            rnds = 0.3,
        },
        [80] = {
            check = 79,
            alt = true,
        },
        [81] = {
            level = 3,
            strength = 40,
            swap_weight = function(ent)
                if ent.State == 6 or ent.State == 7 then return 9 end
            end,
            order = function(ent,info)
                if ent.State == 6 or ent.State == 7 then return 2 end
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State ~= 8 then
                    d[own_key.."rnd"] = d[own_key.."rnd"] or auxi.choose(450,540,600)
                    d[own_key.."base_counter"] = (d[own_key.."base_counter"] or 0) + 1
                    if d[own_key.."base_counter"] > d[own_key.."rnd"] then d[own_key.."rnd"] = auxi.choose(450,540,600) info.force_move(ent) end
                else d[own_key.."base_counter"] = nil end
            end,
            force_move = function(ent)
                ent.State = 8
                ent:GetSprite():Play("Attack2",true)
            end,
        },
        [82] = {
            need_multi = {2,},
            level = 4,
            check = 81,
        },
        [83] = {
            level = 2,
            Replace_with_sprite = true,
            is_offset = true,
            spawn_power = 1,
            only_split = function(se,sinfo,iinfo)
                local rate = sinfo.spawn_power or 1
                local ret = 0.5
                if iinfo then
                    if iinfo.is_multi then ret = ret * (1 - rate) + rate * 0.1 end
                    if iinfo.can_multi then ret = ret * (1 - rate) + rate * 0.2 end
                end
                return ret
            end,
            check_all_type = true,
            protect_self = true,
        },
        [84] = {
            check = 83,
            alt = true,
        },
        [85] = {
            check = 83,
        },
        [86] = {
            strength = 30,
            check = 83,
            spawn_power = 0.6,
        },
        [87] = {
            check = 86,
            alt = true,
            need_multi = {1,2,3,},
        },
        [88] = {
            check = 86,
        },
        [89] = {
            strength = 10,
            check = 83,
            spawn_power = 0.3,
        },
        [90] = {
            check = 89,
            alt = true,
        },
        [91] = {
            check = 89,
        },
        [92] = {
            level = 4,
            real_tg_layer = {0,},
            Replace_with_sprite = true,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if (anim == "JumpUp" and s:WasEventTriggered("Jump")) or (anim == "JumpDown" and s:WasEventTriggered("Land") ~= true) then return 9 end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if (anim == "JumpUp" and s:WasEventTriggered("Jump")) or (anim == "JumpDown" and s:WasEventTriggered("Land") ~= true) then return 2 end
            end,
        },
        [93] = {
            strength = 30,
            check = 92,
        },
        [94] = {
            strength = 10,
            check = 92,
        },
        [95] = {
            level = 4,
            strength = 65,
            KeepTarget = true,
            rnds = 0.4,
            order = -2,
            CoverDetail = {
                [0] = {
                    [1] = {
                        st = 27 - 14,
                        ed = 89,
                    },
                },
            },
            --[[
            special = function(ent)
                if Game():GetFrameCount() % 15 == 5 then
                    local enemies = auxi.getallenemies()
                    local allents = auxi.getothers(nil,78)
                    --print(#allents)
                    local tgs = collector.search_for_linkage(ent,nil,nil,{check_parent = true,take_linker = true,stack = allents,})
                    --print(#tgs)
                    --print(#enemies)
                    if #tgs >= #enemies then
                        --print("Try Update")
                        delay_buffer.addeffe(function()
                            collector.update_npc(ent,nil,(EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_PERSISTENT | EntityFlag.FLAG_CHARM | EntityFlag.FLAG_NO_TARGET))
                        end,{},1)
                    end
                end
            end,
            special = function(ent) --!!只能手写旋转硫磺火了
                --if ent.V1.X <= -50 then print("Update") collector.update_npc(ent) end
                if ent.HitPoints/ent.MaxHitPoints < 0.4 and ent.FrameCount % 60 == 1 then
                    local enemies = auxi.getenemies()
                    local tgs = collector.search_for_linkage(ent)
                    if #tgs == #enemies then
                        delay_buffer.addeffe(function()
                            local i_flag = EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_PERSISTENT | EntityFlag.FLAG_CHARM | EntityFlag.FLAG_FREEZE | EntityFlag.FLAG_NO_SPRITE_UPDATE
                            for u,v in pairs(tgs) do
                                if auxi.check_for_the_same(ent,v) ~= true then
                                    v:AddEntityFlags(i_flag)
                                end
                            end
                            Game():GetRoom():Update()
                            for u,v in pairs(tgs) do
                                if auxi.check_for_the_same(ent,v) ~= true then
                                    v:ClearEntityFlags(i_flag)
                                    v.Target = nil
                                end
                            end
                        end,{},1)
                    end
                end
            end,
            --]]
            --l local tgs = Isaac.GetRoomEntities() local v1 = nil for u,v in pairs(tgs) do if v.Type == 20 and v.Variant == 0 then v1 = v:ToNPC() break end end local v2 = nil for u,v in pairs(tgs) do if v.Type == 78 and v.Variant == 0 then v2 = v:ToNPC() break end end local i_flag = EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_PERSISTENT | EntityFlag.FLAG_CHARM | EntityFlag.FLAG_FREEZE | EntityFlag.FLAG_NO_SPRITE_UPDATE if v1 and v2 then v1:AddEntityFlags(i_flag) Game():GetRoom():Update() v1:ClearEntityFlags(i_flag) v1.Target = nil end
        },
        [96] = {
            check = 95,
            CoverDetail = {
                [0] = {
                    [1] = {
                        st = 27 - 14,
                        ed = 94 - 14,
                    },
                },
            },
        },
        [97] = {
            level = 1,
            can_multi = true,
            KeepUpdate = true,
            special_damage = function(ent,amt,flag,source,cooldown)
                if source and source.Entity then
                    local se = source.Entity
                    if se.Type == 79 then return false end
                    if se.SpawnerEntity then
                        se = se.SpawnerEntity
                        if se.Type == 79 then return false end
                    end
                end
            end,
            NoDeliTexture = true,
        },
        [98] = {
            check = 97,
            alt = true,
        },
        [99] = {
            check = 97,
            alt = true,
        },
        [100] = {
            level = 1,
            can_multi = true,
        },
        [101] = {       --!!精神错乱好像没有它的皮肤？
            level = 2,
            check = 100,
        },
        [102] = {
            level = 1,
            strength = 25,
            KeepUpdate = true,
            is_offset = true,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Walk02" then return 0.25
                else return -0.75 end
            end,
            rnds = 0.5,
            CoverDetail = {
                [0] = {
                    [4] = {
                        st = 3,
                        ed = 24,
                    },
                    [5] = {
                        st = 3,
                        ed = 23,
                    },
                    [6] = {
                        st = 3,
                        ed = 23,
                    },
                    [7] = {
                        st = 3,
                        ed = 23,
                    },
                },
            },
            Force_Spawn_Info = function(ent,es)
                if es.Type == 79 then return true end
            end,
        },
        [103] = {
            check = 102,
            alt = true,
        },
        [104] = {
            check = 102,
            alt = true,
        },
        [105] = {
            level = 1,
            strength = 30,
            is_offset = true,
            rnds = 1.5,
            order = function(ent)
                local anim = ent:GetSprite():GetAnimation()
                if anim == "Rage" or anim == "Walk02" then return 0
                else return -1 end
            end,
            naturally_move_back = 0.3,
            prevent_velocity = true,
            CoverDetail = {
                [0] = {
                    [4] = {
                        st = 3,
                        ed = 24,
                    },
                    [5] = {
                        st = 3,
                        ed = 23,
                    },
                    [6] = {
                        st = 3,
                        ed = 23,
                    },
                    [7] = {
                        st = 3,
                        ed = 23,
                    },
                },
            },
            Force_Spawn_Info = function(ent,es)
                if es.Type == 79 then return true end
            end,
        },
        [106] = {
            level = 2,
            NotSpawn = true,
            NoKill = true,
            order = function(ent)
                local anim = ent:GetSprite():GetAnimation()
                if anim == "Attack01" then return -2
                else return -1 end
            end,
            Force_Spawn_Info = function(ent,es)
                if es.Type == 79 then return true end
            end,
        },
        [107] = {   --!!恶魔会在到处出现，不过一般还是属于第3层比较多
            level = 3,
            Catch_Laser = true,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State == 9 then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 120 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 10
                ent:GetSprite():Play("Attack2",true)
            end,
            order = function(ent)
                if ent.State == 9 then return 1 end
            end,
        },
        [108] = {
            level = 3,
            Catch_Laser = true,
            check = 107,
            CoverDetail = {
                [0] = {
                    [23] = {
                        st = 19,
                        ed = 54,
                    },
                },
            },
            --!!好像要写独立的order？
        },
        [109] = {
            level = 1,
            can_multi = true,
            strength = 66,
            rnds = 0.3,
            CoverDetail = {
                [0] = {
                    [1] = {
                        st = 11,
                        ed = 33,
                    },
                    [2] = {
                        st = 10,
                        ed = 36,
                    },
                    [3] = {
                        st = 7,
                        ed = 34,
                    },
                    [4] = {
                        st = 9,
                        ed = 34,
                    },
                },
            },
        },
        [110] = {
            level = 1,
            is_dash = true,
            order = function(ent)
                if ent.State == 8 then return 1 end
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State == 8 and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 9
                ent:GetSprite():Play("Attack",true)
            end,
        },
        [111] = {
            level = 5,
            strength = 80,
            KeepTarget = function(ent)
                local anim = ent:GetSprite():GetAnimation()
                if anim == "SmallIdle" or anim == "Change" then return true end
            end,
            InitTarget = true,
            rnds = 0.5,
            InitPosoffset = Vector(0,-80),
            no_appear_flag = true,
            protect_self = true,
            naturally_move_back = 0.5,
            check_all_type = true,
            order = function(ent)
                if ent:GetSprite():GetAnimation() == "SmallIdle" then return -2 end
            end,
            special_on_own_update = function(ent,info)
                local d = ent:GetData()
                if info.KeepTarget(ent) or d[own_key.."Keep"] then
                    local room = Game():GetRoom()
                    local idx1 = room:GetGridIndex(ent.Position)
                    local idx2 = room:GetGridIndex(auxi.ProtectVector(d[own_key.."Record_pos"] or (ent.Position + Vector(0,80))))
                    local tbl = {idx1,idx2}
                    if ent.FrameCount <= 25 then local idx3 = room:GetGridIndex(ent.Position + Vector(0,80)) table.insert(tbl,idx3) end
                    for u,v in pairs(tbl) do
                        if room:GetGridPath(v) >= 1000 then room:SetGridPath(v,0) end
                        delay_buffer.addeffe(function()
                            if room:GetGridPath(v) >= 1000 then room:SetGridPath(v,0) end
                        end,{},1)
                        delay_buffer.addeffe(function()
                            if room:GetGridPath(v) >= 1000 then room:SetGridPath(v,0) end
                        end,{},1,true)
                    end
                    d[own_key.."Record_pos"] = auxi.Vector2Table(ent.Position)
                    ent.TargetPosition = ent.Position
                    d[own_key.."Keep"] = 2
                end
                if d[own_key.."Keep"] then d[own_key.."Keep"] = d[own_key.."Keep"] - 1 if d[own_key.."Keep"] <= 0 then d[own_key.."Keep"] = nil end end
            end,
            HitPoints = 600,
            special = function(ent,ment,is_main,info)
                local s = ent:GetSprite() local d = ent:GetData() local anim = s:GetAnimation()
                if anim == "SmallIdle" then
                    d[own_key.."base_counter"] = (d[own_key.."base_counter"] or 0) + 1
                    if ent.I1 == 1 or d[own_key.."base_counter"] > 500 then -- then
                        local tgs = Isaac.GetRoomEntities()
                        for u,v in pairs(tgs) do
                            if v.Type == 81 and v.Variant == 0 then
                                if collector.is_in_the_same_npc_group(v:ToNPC(),ent) ~= true then
                                    return
                                end
                            end      --如果撒旦和恶魔合体了呢？需要检查是否存在于同一链上
                        end
                        d[own_key.."HelpChange"] = true
                        s:Play("Change",true)
                        ent.MaxHitPoints = 600
                        ent.HitPoints = 600
                        MusicManager():Crossfade(23)
                    end
                else
                    if d[own_key.."HelpChange"] then
                        if anim == "Change" and s:IsEventTriggered("Sound") then
                            sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_RISE_UP,1,1,false,0,1)
                        end
                        if anim == "Change" and s:IsFinished(anim) then
                            ent.State = 11 s:Play("Attack03",true)
                            ent.I1 = 2 ent.I2 = 11 ent.V1 = Vector(1,0)
                            d[own_key.."HelpChange"] = nil
                        end
                    end
                    d[own_key.."base_counter"] = nil
                end
            end,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                if tent:GetSprite():GetAnimation() == "SmallIdle" then return false end
            end,
            --需要限制强度，一个批次的撒旦只有1只会召唤
        },
        [112] = {
            level = 5,
            strength = 66,
            can_multi = true,
            swap_weight = 9,
            order = 2,
        },
        [113] = {
            level = 3,
            strength = 66,
            can_multi = true,
            order = function(ent)
                if ent.I1 == 1 then return 1 end
            end,
        },
        [114] = {
            check = 113,
            alt = true,
        },
        [115] = {
            level = 3,
            strength = 66,
            can_multi = true,
            rnds = 0.3,
            CoverDetail = {
                [0] = {
                    [1] = {
                        st = 17,
                        ed = 58,
                    },
                    [2] = {
                        st = 17,
                        ed = 58,
                    },
                }
            },
        },
        [116] = {
            check = 115,
            alt = true,
        },
        [117] = {
            level = 2,
            order = function(ent)
                if ent.State == 8 then return 1 end
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State ~= 10 then
                    d[own_key.."rnd"] = d[own_key.."rnd"] or auxi.choose(450,540,600)
                    d[own_key.."base_counter"] = (d[own_key.."base_counter"] or 0) + 1
                    if d[own_key.."base_counter"] > d[own_key.."rnd"] then d[own_key.."rnd"] = auxi.choose(450,540,600) info.force_move(ent) end
                else d[own_key.."base_counter"] = nil end
            end,
            force_move = function(ent)
                ent.State = 10
                ent:GetSprite():Play("Attack01",true)
            end,
            special_collision = function(ent,col,low)
                if ent:ToNPC().ParentNPC == nil then
                    if col.Type == 14 then return {ret = nil,} end
                end
            end,
        },
        [118] = {
            check = 117,
            can_multi = true,
            alt = true,
        },
        [119] = {
            check = 117,
            alt = true,
        },
        [120] = {
            real_tg_layer = {1,},
            rnds = 1.2,
            swap_weight = function(ent)
                if ent.State == 6 then return 9 end
                return 1
            end,
            order = function(ent)
                if ent.State == 6 then return 1 end
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State ~= 9 and ent.State ~= 8 then
                    d[own_key.."rnd"] = d[own_key.."rnd"] or auxi.choose(450,540,600)
                    d[own_key.."base_counter"] = (d[own_key.."base_counter"] or 0) + 1
                    if d[own_key.."base_counter"] > d[own_key.."rnd"] then d[own_key.."rnd"] = auxi.choose(450,540,600) info.force_move(ent) end
                else d[own_key.."base_counter"] = nil end
            end,
            force_move = function(ent)
                ent.State = auxi.choose(8,9)
                if ent.State == 8 then ent:GetSprite():Play("Attack01",true)
                else ent:GetSprite():Play("Attack02",true) end
            end,
        },
        [121] = {
            check = 120,
            alt = true,
        },
        [122] = {
            check = 120,
            alt = true,
        },
        [123] = {
            level = 2,
            check = 120,
        },
        [124] = {
            level = 4,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation()
                if anim == "StompArm" or anim == "StompLeg" then        --这两个动画需要去掉
                else return {1,} end
            end,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if ent.State == 6 or anim == "Down" then return 9 end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if ent.State == 6 or anim == "Down" then return 2 end
                if info.set_visible(ent) == false then return 5 end
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "StompArm" or anim == "StompLeg" then return false end
                return true
            end,
            real_anm2 = "gfx/101.000_daddy long legs.anm2",
            special_on_invisible = function(ent,offset,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "StompArm" or anim == "StompLeg" then
                    local s2 = auxi.copy_sprite(s,nil,{filename = info.real_anm2,SetScale = true,SetOffset = true,SetRotation = true,})
                    s2:ReplaceSpritesheet(5,"gfx/SE_shadow.png") s2:LoadGraphics()
                    s2:Render(offset)
                end
            end,
        },
        [125] = {
            check = 124,
            real_anm2 = "gfx/101.001_triachnid.anm2",
        },
        [126] = {
            level = 5,
            KeepTarget = true,
            HideAll = true,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "3FBAttack3" and s:IsFinished(anim) then return false end
                return true
            end,
            order = function(ent,info)
                if info.set_visible(ent) == false then return 5 end
                return -2
            end,
        },
        [127] = {
            --!!缺少gfuel的皮肤
            check = 126,
            order = function(ent,info)
                if info.set_visible(ent) == false then return 5 end
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,1) == "2" then return -0.75 end
                return -2
            end,
        },
        [128] = {       --!!这个亡语会召唤凹凸，要删掉吗？
            level = 6,
            check = 127,
            clear_another = true,
        },
        [129] = {       --别忘了小怪版本
            level = 1,
            strength = 35,
            real_tg_layer = {1,},
            order = function(ent,info)
                if ent.State == 8 then return 1 end
            end,
        },
        [130] = {
            check = 129,
            alt = true,
        },
        [131] = {
            check = 129,
            alt = true,
        },
        [132] = {
            check = 129,
        },
        [133] = {
            level = 1,
            strength = 75,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                local anim = tent:GetSprite():GetAnimation()
                if anim == "IdleSkin" or anim == "AngrySkin" then return false end
            end,
            --KeepTarget = true,
            order = function(ent,info)
                if ent.State == 9 then return 1 end
            end,
            Catch_Laser = true,
            naturally_move_back = true,
            set_color = true,
            --如果能让它在切换控制权后逐渐后退，就能放松order了
        },
        [134] = {
            check = 133,
            alt = true,
        },
        [135] = {
            check = 133,
            alt = true,
        },
        [136] = {
            order = function(ent,info)
                if ent.State == 4 then return 1 end
                return -2
            end,
            protect_pos = true,
            --rnds = 0.5,
        },
        [137] = {
            check = 136,
            special_damage = function(ent,amt,flag,source,cooldown)
                if flag & DamageFlag.DAMAGE_POOP ~= 0 then return false end
            end,
            alt = true,
        },
        [138] = {
            check = 136,
            alt = true,
        },
        [139] = {
            check = 136,
            reload = true,
        },
        [140] = {
            level = 2,
            order = -2,
            KeepTarget = true,
            CoverDetail = {
                [0] = {
                    [5] = {
                        st = 412-384,--23,
                        ed = 107,
                    },
                    [6] = {
                        st = 199-128,--17,
                        ed = 153,
                    },
                    [7] = {
                        st = 381-320,--4,
                        ed = 149,
                    },
                    [8] = {
                        st = 395-320,--11,
                        ed = 152,
                    },
                }
            },
        },
        [141] = {
            strength = 60,
            check = 140,
            alt = true,
        },
        [142] = {
            check = 140,
            alt = true,
        },
        [143] = {
            level = 3,
            order = -2,
            KeepTarget = true,
        },
        [144] = {
            check = 143,
            alt = true,
        },
        [145] = {
            check = 143,
            alt = true,
        },
        [146] = {
            level = 2,
            real_tg_layer = {0,1,},
            KeepTarget = function(ent)
                local anim = ent:GetSprite():GetAnimation()
                if (anim == "Jumping") and ent.TargetPosition:Length() > 10 then return true end
                --if anim == "Jump" or anim == "Walk" then return true end
            end,
            swap_weight = function(ent)
                if ent.State == 7 or ent.State == 6 then return 9 end
            end,
            order = function(ent,info)
                if ent.State == 7 or ent.State == 6 then return 2 end
                return -2
            end,
        },
        [147] = {
            check = 146,
            alt = true,
        },
        [148] = {
            check = 146,
            alt = true,
        },
        [149] = {
            level = 3,
            KeepTarget = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "JumpLoop" or anim == "Landing" then return true end
            end,
            swap_weight = function(ent)
                if ent.State == 7 or ent.State == 6 then return 9 end
            end,
            order = function(ent,info)
                if ent.State == 7 or ent.State == 6 then return 2 end
                if ent.State == 8 then return 1 end
                return -1
            end,
        },
        [150] = {
            check = 149,
            alt = true,
        },
        [151] = {
            check = 149,
            alt = true,
        },
        [152] = {
            level = 4,
            order = function(ent,info)
                if ent.State == 10 then return 1 end
            end,
            naturally_move_back = true,
        },
        [153] = {
            level = 2,
            is_dash = true,     --被标记为dash的敌人应该需要保护反转方向？
            order = function(ent,info)
                if ent.State == 10 then return 1 end
            end,
            protect_flip = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Charge" or anim == "Charge Shake" then return true end
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State == 10 and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 8
                ent:GetSprite():Play("Attack1",true)
            end,
        },
        [154] = {
            level = 3,
            check = 153,
            swap_weight = function(ent)
                if ent.State == 6 then return 9 end
            end,
            order = function(ent,info)
                if ent.State == 6 then return 2 end
            end,
            protect_flip = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Attack2Right" or anim == "Attack2Left" then return true end
            end,
            CoverDetail = {
                [0] = {
                    [21] = {
                        st = 31,--16,
                        ed = 70,
                    },
                },
            },
        },
        [155] = {
            level = 2,
            set_ground = true,      --需要设置dirt颜色
            order = function(ent,info)
                if info.set_visible(ent) == false then return 5 end
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Dirt" or (anim == "ComeUp" and fr <= 2) or (anim == "GoUnder" and fr >= 7) then return false end
                return true
            end,
            real_anm2 = "gfx/269.000_polycephalus.anm2",
            special_on_invisible = function(ent,offset,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then
                    local s2 = auxi.copy_sprite(s,nil,{filename = info.real_anm2,SetScale = true,SetOffset = true,SetRotation = true,})
                    --s2:ReplaceSpritesheet(5,"gfx/SE_shadow.png") s2:LoadGraphics()
                    s2:Render(offset)
                end
            end,
        },
        [156] = {
            check = 155,
            alt = true,
        },
        [157] = {
            check = 155,
            alt = true,
            can_multi = true,
            Force_Spawn_Info = function(ent,es)
                if es.Type == 269 then return true end
            end,
        },
        [158] = {
            level = 4,
            strength = 35,
            real_tg_layer = {0,1,},
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Dissapear" and fr >= 10 then return false end     --Double s? Lack p?
                if anim == "Appear" and fr <= 4 then return false end     --Double s? Lack p?
                return true
            end,
            real_anm2 = "gfx/270.000_megafred.anm2",
            special_on_invisible = function(ent,offset,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false and (s:IsFinished(anim) ~= true) then
                    local s2 = auxi.copy_sprite(s,nil,{filename = info.real_anm2,SetScale = true,SetOffset = true,SetRotation = true,})
                    --s2:ReplaceSpritesheet(5,"gfx/SE_shadow.png") s2:LoadGraphics()
                    s2:Render(offset)
                end
            end,
            naturally_move_back = 0.5,
            order = function(ent,info)
                if info.set_visible(ent) == false then return 5 end
                return -2
            end,
        },
        [159] = {
            level = 2,
            rnds = 0.5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Float" then return -2 end
                return -0.75
            end,
            Catch_Laser = true,
        },
        [160] = {
            level = 3,
            check = 159,
        },
        [161] = {
            check = 159,
        },
        [162] = {
            level = 3,
            check = 159,
        },
        [163] = {
            level = 5,
            rnds = 0.4,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,8) == "HeadDash" then return 1.5 end
                if anim == "Idle" or anim == "HeadIdle" then return -1 end
                return -2
            end,
        },
        [164] = {
            level = 5,
            strength = 25,
            KeepTarget = true,
            NoKill = true,
            should_release = true,
            order = -2,
        },
        [165] = {
            level = 6,
            naturally_move_back = 0.3,
            --protect_self = true,
            NoMulti = true,
            Nature_Spawner = 1,
            should_release = true,
            clear_another = true,
            check_all_type = true,
            special = function(ent)
                if ent.State == 13 and Game():GetFrameCount() % 30 == 5 then
                    local enemies = auxi.getallenemies()
                    local allents = auxi.getothers(nil,274)
                    --print(#allents)
                    local tgs = collector.search_for_linkage(ent,nil,nil,{check_parent = true,take_linker = true,stack = allents,})
                    --print(#tgs)
                    --print(#enemies)
                    if #tgs >= #enemies then
                        --print("Try Update")
                        collector.update_npc(ent)
                    end
                end
            end,
            special_All = function(ent,info)
                auxi.check_if_any(info.special,ent)
                local d = ent:GetData()
                if ent.Type == 274 then
                    if d[own_key.."UnInit"] == nil then
                        d[own_key.."Init"] = true
                    end
                elseif d[own_key.."Init"] and ent.Type == 275 and ent:GetSprite():GetAnimation() ~= "Appear" then
                    -- Stitch Base_holder.init = full mix.generate_mixture pipeline; unsupported here.
                    local native_reinit = require("Qing_Remaster_scripts.auxiliary.native_mixture.native_reinit")
                    native_reinit.reinitialize(ent, "entry_1_165_type_transition")
                    d[own_key.."Init"] = nil
                end
                d[own_key.."UnInit"] = true
            end,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                if tent.State == 13 then return false end
            end,
            order = function(ent)
                if ent.State == 2 then return 999 end
            end,
            --l local tgs = Isaac.GetRoomEntities() for u,v in pairs(tgs) do if v.Type == 869 then v = v:ToNPC() print(v.State) print(v:GetSprite():GetAnimation()) print(v.I1.." "..v.I2) print(v.V1) print(v.V2) print(v:GetSprite():GetFrame()) print(v.TargetPosition) end end
            --l local tgs = Isaac.GetRoomEntities() local v1 = nil for u,v in pairs(tgs) do if v.Type == 20 and v.Variant == 0 then v1 = v:ToNPC() break end end local v2 = nil for u,v in pairs(tgs) do if v.Type == 78 and v.Variant == 0 then v2 = v:ToNPC() break end end local i_flag = EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_PERSISTENT | EntityFlag.FLAG_CHARM | EntityFlag.FLAG_FREEZE | EntityFlag.FLAG_NO_SPRITE_UPDATE if v1 and v2 then v1:AddEntityFlags(i_flag) Game():GetRoom():Update() v1:ClearEntityFlags(i_flag) v1.Target = nil end
            --v1:AddEntityFlags(i_flag) Game():GetRoom():Update() v1:ClearEntityFlags(i_flag)
            --v2.HitPoints = v2.MaxHitPoints * 0.3
            --l local collector = require("Mixturer_Extra_scripts.others.Parent_Collect_holder") local mix = require("Mixturer_Extra_scripts.bosses.Boss_Mixturer")  local tgs = Isaac.GetRoomEntities() for u,v in pairs(tgs) do if v.Type == 19 and v:ToNPC().ParentNPC == nil then local ret = collector.search_for_linkage(v,mix.own_key,mix.targets) for u,v in pairs(ret) do print(v.Type.." "..v.Variant) end end end
        },
        [166] = {
            level = 6,
            clear_another = true,
            reload = true,
            naturally_move_back = 0.3,
            on_death = function(ent)
                ent:Remove()
            end,
        },
        [167] = {
            level = 2,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "DirtDisappear" or anim == "Dirt" or (anim == "ComeUp" and fr <= 3) or (anim == "ComeUp2" and fr <= 3) or (anim == "GoUnder" and fr > 7) or (anim == "GoUnder2" and fr >= 13) or (anim == "Appear" and fr <= 1) then return false end
                return true
            end,
            real_anm2 = "gfx/401.000_thestain.anm2",
            --window_size = 8,
            check = 155,
        },
        [168] = {
            check = 167,
            alt = true,
        },
        [169] = {
            level = 3,
            check_all_type = true,
            swap_weight = function(ent)
                if ent:GetSprite():GetAnimation() == "Appear" then return 9 end
            end,
            order = function(ent)
                if ent.State == 10 then return 0 end
            end,
        },
        [170] = {
            check = 169,
            alt = true,
        },
        [171] = {
            level = 2,
            rnds = 0.5,
        },
        [172] = {
            check = 171,
            alt = true,
        },
        [173] = {
            level = 1,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim == "Teleport" and fr >= 11) or (anim == "Return" and fr <= 10) or (anim == "Appear" and fr <= 10) then return false end
                return true
            end,
            real_anm2 = "gfx/404.000_littlehorn.anm2",
            special_on_invisible = function(ent,offset,info,doffset)
                local s = ent:GetSprite() local anim = s:GetAnimation() local d = ent:GetData()
                if info.set_visible(ent) == false and (s:IsFinished(anim) ~= true) then
                    local s2 = auxi.copy_sprite(s,nil,{filename = info.real_anm2,SetScale = true,SetOffset = true,SetRotation = true,})
                    --s2:ReplaceSpritesheet(5,"gfx/SE_shadow.png") s2:LoadGraphics()
                    s2:Render(offset)
                    --无效
                    --[[
                    local fr = s:GetFrame() local finished = s:IsFinished(anim)
                    s:Load(info.real_anm2,true) s.Scale = Vector(1,1) s.Offset = Vector(0,0) s.Rotation = 0
                    s:Play(anim,true) s:SetFrame(fr) if finished then s:Update() end
                    d[own_key.."Reload"] = true
                    ent:Render(doffset)
                    --]]
                end
            end,
            check_reload_ = function(ent)
                local d = ent:GetData() local ret = false
                if d[own_key.."Reload"] then ret = true end
                d[own_key.."Reload"] = nil
                return ret
            end,
            order = function(ent,info)
                if info.set_visible(ent) == false then return 5 end
            end,
        },
        [174] = {
            check = 173,
            alt = true,
        },
        [175] = {
            check = 173,
            alt = true,
        },
        [176] = {
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if string.sub(anim,1,10) == "WalkNoHead" then return {1,} end
                return {1,0,}
            end,
            --[[
            pre_render = function(ent,offset1,offset2,info)     --!!未验证
                local s = ent:GetSprite() local d = ent:GetData() d[own_key.."replace_sprite"] = d[own_key.."replace_sprite"] or Sprite()
                local s2 = auxi.copy_sprite(s,d[own_key.."replace_sprite"],{filename = "gfx/"..info.name..".anm2",on_replace = function(ts,es,params)
                    ts:ReplaceSpritesheet(1,"gfx/SE_shadow.png") ts:LoadGraphics()
                end,})
                s2:Render(offset2)
            end,
            --]]
            protect_flip = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if string.sub(anim,1,8) == "Shooting" then return true end
            end,
            rnds = 0.3,
        },
        [177] = {
            check = 176,
            alt = true,
        },
        [178] = {
            check = 176,
            alt = true,
        },
        [179] = {
            level = 6,
            clear_another = true,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if anim == "WalkingUp" or anim == "ShootUp" or anim == "Guarding" or string.sub(anim,1,10) == "GuardFlash" then return {0,} end
                if anim == "Final" then return {1,} end
                if anim == "Hanging" or anim == "Appearing" then return {0,2,} end
                return {0,1,2,}
            end,
            protect_flip = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "ShootRight" or anim == "ShootLeft" then return true end
            end,
            should_release = true,
            NoDeliTexture = true,
        },
        [180] = {
            check = 179,
        },
        [181] = {
            level = 6,
            clear_another = true,
            Force_Spawn_Info = function(ent,es)
                if es.Type == 102 then return true end
            end,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                local s = tent:GetSprite() local anim = s:GetAnimation()
                if anim == "Appear" or anim == "Concave" or anim == "MovingConcave" or anim == "MovingConcaveEyesOpen" then return false end
            end,
            --[[
            Replace_with_sprite = true,
            set_anm2 = {0,1,2,3,4,},
            special_on_replace_with = function(_s,info,offset,ent)
                local s = ent:GetSprite() local d = ent:GetData() d[own_key.."replace_sprite"] = d[own_key.."replace_sprite"] or Sprite()
                local s2 = auxi.copy_sprite(s,d[own_key.."replace_sprite"],{filename = (info.anm2):gsub("_left.anm2","_replace_left.anm2"):gsub("_right.anm2","_replace_right.anm2"),})
                print((info.anm2):gsub("_left.anm2","_replace_left.anm2"):gsub("_right.anm2","_replace_right.anm2"))
                s2:Render(offset)
            end,
            --]]
            order = function(ent,info)
                local s = ent:GetSprite()
                if s:GetAnimation() == "Appear" then return 5 end
            end,
            rnds = 0.3,
            protect_flip = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if string.sub(anim,-5) == "Right" or string.sub(anim,-4) == "Left" then return true end
            end,
            --这个敌人的渲染比较奇怪，需要调整Overlay
        },
        [182] = {
            level = 2,
            is_offset = true,
            order = -1,
            special_damage_over = function(ent,amt,flag,source,cooldown,tent)
                if tent:GetSprite():GetAnimation() == "Covered" then return false end
            end,
        },
        [183] = {
            level = 3,
            check = 151,
            Catch_Laser = true,
            Force_Spawn_Info = function(ent,es)
                if es.Type == 265 then return true end
            end,
            KeepTarget = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "JumpLoop" or anim == "Landing" then return true end
            end,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Jumping" or anim == "JumpLoop" or anim == "Landing" then return 9 end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Jumping" or anim == "JumpLoop" or anim == "Landing" then return 2 end
                if ent.State == 7 or ent.State == 6 then return 2 end
                if ent.State == 8 or ent.State == 9 then return 0.5 end
                return -1
            end,
            protect_flip = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "LaserStartSide" or anim == "LaserLoopSide" then return true end
            end,
            special_damage = function(ent,amt,flag,source,cooldown,tent)        --这个免伤可以简单点
                if source and source.Entity then
                    local se = source.Entity
                    if se.Type == 410 then return false end
                    if se.SpawnerEntity then
                        local sse = se.SpawnerEntity
                        if sse.Type == 410 then return false end
                    end
                end
            end,
        },
        [184] = {
            level = 2,
            real_tg_layer = {0,},
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                if anim == "BombDizzy" or anim == "DizzyLoop" or anim == "DizzyEnd" then return -2 end
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim == "Null") or (anim == "Appear" and fr <= 3) or (anim == "BigHoleOpen") or (anim == "SmallHoleOpen") or (anim == "BigHoleClose") or (anim == "SmallHoleClose") then return false end
                return true
            end,
            special_collision = function(ent,col,low)
                if ent:ToNPC().ParentNPC == nil then
                    if col.Type == 4 then return {ret = nil,} end
                end
            end,
        },
        [185] = {
            level = 6,
            clear_another = true,
            NoMulti = true,
            set_visible = function()
                return true
            end,
            Recheck = function(ent)
                -- Stitch Bossanimlist is a separate DELIRIUM_ANIM_REGISTRY (not linker infra).
                local reg = require("Qing_Remaster_scripts.auxiliary.native_mixture.compat.delirium_anim_registry")
                if not reg.is_available() then
                    return nil
                end
                local s = ent:GetSprite() local filename = s:GetFilename()
                local skip_name = string.sub(filename,5,-6)   --"gfx/XXXXX.anm2"
                if string.sub(skip_name,1,7) == "output/" then skip_name = string.sub(skip_name,8,-1) end
                if string.sub(skip_name,-5) == "_left" then skip_name = string.sub(skip_name,1,-6) end
                if string.sub(skip_name,-6) == "_right" then skip_name = string.sub(skip_name,1,-7) end
                if skip_name ~= "412.000_Delirium" then
                    return reg.get(skip_name)
                end
            end,
            DealwithRecheck = function(info)
                if info.DeliriumData then return info.DeliriumData end
                local ret = {}
                for u,v in pairs(info) do
                    ret[u] = v
                end
                ret.KeepUpdate = true
                --ret.NoKill = true
                ret.reload = true
                ret.only_count = true
                --ret.clear_another = true
                local prev_visi = ret.set_visible
                ret.set_visible = function(ent)
                    local ret = auxi.check_if_any(prev_visi,ent)
                    if ret == nil then return true else return ret end
                end
                local prev_load = ret.load_anm2
                ret.load_anm2 = function(id,ent,prefix,info)
                    local base_data = info.anm2_data
                    if not info.NoDeliTexture then
                        local ret = string.gsub(auxi.check_if_any(prev_load,id,ent,prefix,info) or ("gfx/"..base_data.Spritesheets[base_data.Layers[id]]),"gfx/Bosses/",""):gsub("gfx/Monsters/",""):gsub("gfx/bosses/",""):gsub("gfx/monsters/","")
                        if PRINT_DELI then print(ret) end
                        return "gfx/Bosses/AfterbirthPlus/DeliriumForms/" .. ret
                    elseif type(info.NoDeliTexture) == "function" then
                        local succ = auxi.check_if_any(info.NoDeliTexture)
                    end
                end
                ret.set_anm2 = function(info)
                    local base_data = info.anm2_data
                    local ret = {}
                    for u,v in pairs(base_data.Layers) do table.insert(ret,u) end
                    return ret
                end
                ret.dont_set_anm2 = true
                info.DeliriumData = ret
                return ret
            end,
            reload = true,
            --NoKill = true,
            only_count = true,
            ProtectMyData = true,
            KeepUpdate = true,
            --l local tgs = {19,20,407,404,}
            --l Game():GetRoom():Update() local tgs = Isaac.GetRoomEntities() for u,v in pairs(tgs) do if v.Type == 7 then print(v.Position) end end
        },
        [186] = {
            level = 4,
            strength = 60,
            swap_weight = function(ent)
                local anim = ent:GetSprite():GetAnimation()
                if anim == "Jump" or anim == "Jump2" or anim == "AirFlinch" then return 9 end
            end,
            rnds = 0.4,
            order = -1,
            check_all_type = true,
        },
        [187] = {
            level = 2.5,
            check = 1,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                local s = tent:GetSprite() local anim = s:GetAnimation()
                if flag & DamageFlag.DAMAGE_EXPLOSION ~= 0 then return true end
                if string.sub(anim,-1,-1) ~= "B" then return false end
            end,
        },
        [188] = {
            --need_multi = {},
            level = 2.5,
            check = 4,
            special_on_replace_with = function(s,info,render_offset)
                s:RenderLayer(0,render_offset)
            end,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                local s = tent:GetSprite() local anim = s:GetAnimation()
                if flag & DamageFlag.DAMAGE_EXPLOSION ~= 0 then return true end
                if anim == "HeadRotate" or anim == "BodyRotate" then return false end
            end,
        },
        [189] = {
            --need_multi = {},
            level = 1.5,
            check = 50,
            on_search = function(info,v1,v2,v3)
                if v1 == info.type and v2 == info.variant and (v3 <= 5) then return true end
            end,
        },
        [190] = {
            level = 2.5,
            check = 155,
            order = function(ent,info)
                if info.set_visible(ent) == false then return 5 end
                if ent.State == 9 then return 1 end
                return -1
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "DirtShrink" or anim == "Dirt" or (anim == "ComeUp" and fr <= 2) or (anim == "GoUnder" and fr >= 7) then return false end
                return true
            end,
            real_anm2 = "gfx/269.001_polycephalus2.anm2",
            special = function(ent,ment,is_main,info)
                local d = ent:GetData() local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "ChargeLoop" and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 10 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 13
                ent:GetSprite():Play("Attack3",true)
            end,
        },
        [191] = {
            level = 3,
            naturally_move_back = 0.3,
            Reset_counter = true,
            AddVelocity = function(ent)
                return Vector(ent.V1.X,0)
            end,
            Catch_Laser = true,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData() local s = ent:GetSprite() local anim = s:GetAnimation()
                if (anim == "DashLeftLoop" or anim == "DashRightLoop") and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 30 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 8
                ent:GetSprite():Play("Attack2",true)
            end,
            order = function(ent)
                local d = ent:GetData() local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,4) == "Dash" then return 1 end
                --return -3
                --if ent.State == 3 then return -3 end
            end,    --这玩意的位移控制像屎一样
            KeepTarget_Special = true,
            prevent_velocity = true,
            --Replace_with_sprite = true,
            --KeepTarget = true,
            --l local tgs = Isaac.GetRoomEntities() for u,v in pairs(tgs) do if v.Type == 58 then v = v:ToNPC() print(v:GetSprite():GetFilename()) print(v:GetSprite():GetAnimation()) print(v.State) print(v.I1.." "..v.I2) print(v.V1) print(v.V2) print(v.Position) end end
        },
        [192] = {
            level = 1.5,
            swap_weight = function(ent)
                local d = ent:GetData() local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Attack04" then return 9 end
                return 1
            end,
            order = function(ent)
                local d = ent:GetData() local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Attack04" then return 0 end
            end,
            rnds = 0.5,
        },
        [193] = {
            level = 1.5,
            order = -2,
            real_tg_layer = {0,1,2,},
        },
        [194] = {
            level = 3.5,
            can_multi = true,
            order = -1,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                if tent.State == 100 then return false end
            end,
            --l local tgs = Isaac.GetRoomEntities() for u,v in pairs(tgs) do if v.Type == 903 and v.Variant <= 1 then v = v:ToNPC() print(v:GetSprite():GetFilename()) print(v:GetSprite():GetAnimation()) print(v.State) print(v.I1.." "..v.I2) print(v.V1) print(v.V2) print(v.Position) if v.Parent then print("Parent") print(v.Parent.Variant) end end end
        },
        [195] = {
            level = 3.5,
            order = function(ent,info)
                if info.set_visible(ent) == false then return 5 end
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if string.sub(anim,1,5) == "Slash" then return 1 end
                return -1
            end,
            KeepTarget = true,
            KeepTarget_ = function(ent)
                if string.sub(ent:GetSprite():GetAnimation(),1,7) == "Attack1" then return true end
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim == "Teleport" and fr >= 22) or (anim == "TeleportEnd" and fr <= 8) then return false end
                return true
            end,
            real_anm2 = "gfx/904.000_Siren.anm2",
            special_on_invisible = function(ent,offset,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false and (s:IsFinished(anim) ~= true) then
                    local s2 = auxi.copy_sprite(s,nil,{filename = info.real_anm2,SetScale = true,SetOffset = true,SetRotation = true,})
                    --s2:ReplaceSpritesheet(5,"gfx/SE_shadow.png") s2:LoadGraphics()
                    s2:Render(offset)
                end
            end,
        },
        [196] = {
            level = 3.5,
            set_color = true,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if string.sub(anim,1,4) == "Exit" or string.sub(anim,1,6) == "Charge" then return 1 end
                return -1
            end,
            protect_flip = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if string.sub(anim,1,4) == "Exit" or string.sub(anim,1,6) == "Charge" then return true end
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim == "Summoning" and fr <= 40) then return false end
                return true
            end,
            real_anm2 = "gfx/905.000_Heretic.anm2",
            special_on_invisible = function(ent,offset,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false and (s:IsFinished(anim) ~= true) then
                    local s2 = auxi.copy_sprite(s,nil,{filename = info.real_anm2,SetScale = true,SetOffset = true,SetRotation = true,})
                    s2:ReplaceSpritesheet(3,"gfx/SE_shadow.png") s2:LoadGraphics()
                    s2:Render(offset)
                end
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData() local s = ent:GetSprite() local anim = s:GetAnimation()
                if (string.sub(anim,1,4) == "Exit") and not is_main then info.force_move(ent) return end
                if string.sub(anim,1,6) == "Charge" and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 60 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                local d = ent:GetData() local s = ent:GetSprite() local anim = s:GetAnimation()
                ent.State = 14 --ent.TargetPosition =
                ent:GetSprite():Play("Attack2",true)
            end,
        },
        [197] = {
            level = 1,
            strength = 55,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Attack2" then return 9 end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if ent.State == 10 then return 1 end
            end,
            rnds = 0.75,
            on_damage = function(ent,amt,flag,source,cooldown,tent)
                tent:TakeDamage(0.1,0,source,666)
            end,
        },
        [198] = {
            level = 4.5,
            strength = 65,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                if source and source.Entity then
                    local se = source.Entity
                    while(se:ToNPC() == nil and se.SpawnerEntity) do
                        se = se.SpawnerEntity
                    end
                    if se.Type == 909 then return false end
                    --if se:ToNPC() and collector.is_in_the_same_npc_group(se:ToNPC(),tent) then return false end
                end
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData() local s = ent:GetSprite()
                local anim = s:GetAnimation() local fr = ent:GetSprite():GetFrame()
                if (anim == "TrapDown" or (anim:sub(1,9) ~= "SlicePull" and anim:sub(1,5) == "Slice")) and s:WasEventTriggered("Shoot") == false then
                    local tgs = auxi.getothers(nil,909,0,0)
                    local cnts = 0
                    for u,v in pairs(tgs) do
                        local vs = v:ToNPC():GetSprite() local vanim = vs:GetAnimation()
                        if vanim:sub(1,4) == "Trap" or vanim:sub(1,5) == "Slice" then cnts = cnts + 1 end
                    end
                    if cnts >= 2 then
                        info.force_move(ent)
                    end
                end
            end,
            force_move = function(ent)
                ent.State = 11
                ent:GetSprite():Play("BroccoliAttack",true)
            end,
            order = function(ent,info)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim:sub(1,5) == "Hover" then return -2 end
                if anim:sub(1,5) == "Slice" or anim:sub(1,4) == "Trap" then return 0.5 end
            end,
            --!! 太阴了，要调整一下
        },
        [199] = {
            level = 4.5,
            Animlist = {
                [1] = {
                    ["Appear"] = true,
                },
                [2] = {
                    ["HeadIdle"] = true,
                    ["HeadCharge"] = true,
                    ["HeadAngry"] = true,
                    ["HeadTrip"] = true,
                    ["HeadAttack"] = true,
                },
            },
            Overlay_Add_With = 2,
            Replace_with_sprite = true,
            no_overlay_info = {
                ["FallBack"] = function(s)
                    local fr = s:GetFrame()
                    if fr >= 4 and fr <= 68 then return true end
                end,
                ["Leap"] = function(s)
                    local fr = s:GetFrame()
                    if fr >= 4 and fr <= 66 then return true end
                end,
                ["SpitFly"] = function(s)
                    local fr = s:GetFrame()
                    if fr >= 4 and fr <= 54 then return true end
                end,
            },
            no_overlay = function(ent)
                local s = ent:GetSprite()
                local overlayanim = s:GetOverlayAnimation()
                if overlayanim ~= "" and s:IsOverlayFinished(overlayanim) then return true end
            end,
            special_on_replace_with = function(s,info,render_offset,ent)
                local overlayanim = s:GetOverlayAnimation()
                if overlayanim ~= "" and ent:GetSprite():IsOverlayFinished(overlayanim) ~= true then       --and not auxi.check_if_any(info.no_overlay_info[s:GetAnimation()],s)
                    s:RenderLayer(0,render_offset)
                    --print(1)
                    --local s2 =
                    local animinfo = info.anm2_data.Animations[s:GetAnimation()].LayerAnimations[2]
                    if #animinfo > 0 then
                        local nanimlerpedinfo = auxi.check_lerp(s:GetFrame(),animinfo,{banlist = {["Visible"] = true,["Interpolated"] = true,},shouldlerp = function(v1,v2) if v1.Interpolated == true then return true else return false end end,})
                        if nanimlerpedinfo.Visible then
                            local dpos = Vector(nanimlerpedinfo.XPosition * s.Scale.X,nanimlerpedinfo.YPosition * s.Scale.Y)

                            local s2 = auxi.copy_sprite(s,nil,{SetOverLayFrame = true,Anim = s:GetOverlayAnimation(),Frame = s:GetOverlayFrame(),})
                            s2:Render(render_offset + dpos)
                        end
                    end
                else
                    s:RemoveOverlay()
                    s:Render(render_offset)
                end
            end,
            real_tg_layer = function(s,isoverlay,info)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if info.Animlist[1][anim] then return end
                if info.Animlist[2][anim] then return {1,} end
                return {0,2,}
            end,
            rnds = 1.5,
            order = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Leap" then return 2 end
                if string.sub(anim,1,3) == "Run" then return 0 end
                if string.sub(anim,1,4) == "Walk" or string.sub(anim,1,4) == "Trip" then return -1 end
                return -2
            end,
            check_all_type = true,
        },
        [200] = {
            strength = 30,
            check = 199,
            rnds_add = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if string.sub(anim,1,4) == "Roll" then return 0.5 end
            end,
            on_swap = function(ent,info,is_in)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if is_in and string.sub(anim,1,4) == "Roll" then
                    if ent.Velocity:Length() < 0.1 then ent.Velocity = auxi.random_r() * 5 end
                end
            end,
            order = function(ent)       --!!不知道为什么，和Larry的配合不对
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if string.sub(anim,1,9) == "Brimstone" then return 2 end
                if string.sub(anim,1,4) == "Roll" or string.sub(anim,1,3) == "Run" then return 0 end
                if string.sub(anim,1,4) == "Walk" or string.sub(anim,1,4) == "Trip" then return -1 end
                return -2
            end,
        },
        [201] = {
            level = 4.5,
            strength = 30,
            order = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if string.sub(anim,1,6) == "Charge" then return 1 end
                if anim == "Shoot" then return -2 end
                return 0
            end,
            KeepTarget = true,
        },
        [202] = {
            level = 4.5,
            strength = 30,
            KeepTarget = true,
            order = -2,
            on_death = function(ent)
                ent:Remove()
            end,
            should_release = true,
        },
        [203] = {
            level = 4.5,
            strength = 30,
            order = -2,
            KeepTarget = true,
            protect_flip = true,
            Catch_Laser = true,
            init = function(ent)
                ent:Update()
                local tgs = Isaac.GetRoomEntities() for u,v in pairs(tgs) do if v.Type == 1000 and v.Variant == 6 and v:GetSprite():GetFilename() == "gfx/1000.006_rotgut detail.anm2" then v:Remove() end end
            end,
            on_death = function(ent)
                ent:Remove()
            end,
        },
        [204] = {
            level = 4.5,
            strength = 30,
            order = -2,
            KeepTarget = true,
        },
        [205] = {
            level = 6,
            Replace_with_sprite = true,
            clear_another = true,
            protect_self = true,
            --is_offset = true,
            set_anm2 = {0,1,2,3,},
            special = function(ent)
                --ent.PositionOffset = Vector(0,0)
                local tgs = collector.collect(ent) or {}
                for u,v in pairs(tgs) do
                    v.EntityCollisionClass = 0
                    v.Size = 10
                end
            end,
            special_All = function(ent,info)
                local d = ent:GetData()
                if ent.Variant == 0 then
                    if d[own_key.."UnInit"] == nil then
                        d[own_key.."Init"] = true
                    end
                elseif ent.Variant == 10 then
                    if d[own_key.."Init"] then
                        -- Stitch Base_holder.init = full mix.generate_mixture pipeline; unsupported here.
                        local native_reinit = require("Qing_Remaster_scripts.auxiliary.native_mixture.native_reinit")
                        native_reinit.reinitialize(ent, "entry_1_205_variant_transition")
                        d[own_key.."Init"] = nil
                    end
                end
                d[own_key.."UnInit"] = true
            end,
            KeepTarget = true,
            order = -1,
            check_all_type = true,
            on_death = function(ent)
                ent:Remove()
            end,
            --它的亡语会杀死本体，所以也删了
        },
        [206] = {
            level = 6,
            reload = true,
            clear_another = true,
            Force_Spawn_Info = function(ent,es)
                if es.Type == 912 then return true end
            end,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                --if string.sub(anim,1,4) == "Spin" then return {0,1,} end
                return {0,1,}
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                local s = ent:GetSprite() local anim = s:GetAnimation()
                ent.PositionOffset = Vector(0,0)
                if anim == "ShootBegin" then
                    ent.State = 11
                    ent:GetSprite():Play("ShootRightBegin",true)
                end
                if string.sub(anim,1,6) == "Charge" and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 8
                ent:GetSprite():Play("SpinBegin",true)
            end,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if string.sub(anim,1,4) == "Jump" then return 9 end
            end,
            order = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if string.sub(anim,1,6) == "Charge" then return 2 end
                if string.sub(anim,1,4) == "Jump" then return 0 end
                return -1
            end,
        },
        [207] = {
            level = 1.5,
            real_anm2 = "gfx/913.000_Min Min.anm2",
            tg_anim_list = {
                ["Appear"] = true,
                ["Walk"] = true,
                ["Spit"] = true,
                ["Summon"] = true,
                ["Spin"] = true,
                ["SpinReverse"] = true,
                ["Transition"] = true,
            },
            real_tg_layer = function(s,isoverlay,info)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if info.tg_anim_list[anim] then return {1,0,3,} end
                --if string.sub(anim,1,4) == "Spin" then return {0,3,4} end
            end,
            pre_render_ = function(ent,o1,o2,info)
                local s = ent:GetSprite() local d = ent:GetData() d[own_key.."replace_sprite"] = d[own_key.."replace_sprite"] or Sprite()
                local s2 = auxi.copy_sprite(s,d[own_key.."replace_sprite"],{filename = info.real_anm2,})
                s2:RenderLayer(1,o2)
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim == "Dive" and fr > 15) then return false end
                return true
            end,
            special_on_invisible = function(ent,offset,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false and (s:IsFinished(anim) ~= true) then
                    local s2 = auxi.copy_sprite(s,nil,{filename = info.real_anm2,SetScale = true,SetOffset = true,SetRotation = true,})
                    --s2:ReplaceSpritesheet(3,"gfx/SE_shadow.png") s2:LoadGraphics()
                    s2:Render(offset)
                end
            end,
            order = function(ent,info)
                if info.set_visible(ent) == false then return 5 end
                return -1
            end,
        },
        [208] = {
            level = 1.5,
            order = -2,
            KeepTarget = true,
            real_tg_layer = {0,4,},
        },
        [209] = {
            level = 2.5,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim == "SuperBlast" and fr > 37) then return false end
                return true
            end,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "SuperBlastEnd" or anim == "SuperBlast" then return 9 end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Run" then return 1 end
                if anim == "SuperBlast" then return 2 end
            end,
        },
        [210] = {
            level = 2,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,6) == "Charge" then return 1 end
            end,
            rnds = 1.5,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,6) == "Charge" and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 5
                ent:GetSprite():Play("WallImpact",true)
            end,
            NoDeliTexture = true,
        },
        [211] = {
            level = 1.5,
            tg_anim_list = {
                ["Idle"] = true,
                ["Attack"] = true,
                ["Pop"] = true,
                ["Appear"] = true,
            },
            real_tg_layer = function(s,isoverlay,info)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if info.tg_anim_list[anim] then return {0,1,} end
                if string.sub(anim,1,6) == "Charge" then return {0,1} end
                return {1,}
            end,
            order = function(ent,info)
                if info.set_visible(ent) == false then return 5 end
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,6) == "Charge" then return 1 end
            end,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Dive" or anim == "Pop" or anim == "GoUnder" or anim == "Apppear" then return 9 end
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim == "Dive" and (fr > 20 or fr < 1)) or (anim == "Pop" and fr > 37) or (anim == "Attack2" and (fr > 47 or fr < 2)) or (anim == "GoUnder" and fr > 7) or (anim == "Attack2" and fr > 67) or (anim == "Surface" and fr < 2) or (anim == "Appear" and fr < 17) then return false end
                return true
            end,
            KeepTarget = true,
        },
        [212] = {
            level = 1.5,
            strength = 75,
            check = 1,
            order = 999,
        },
        [213] = {
            level = 3.5,
            real_tg_layer = {0,1,},
            Replace_with_sprite = true,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,4) == "Dash" then return 1 end
            end,
            Catch_Laser = true,
            KeepTarget = true,
            --l local tgs = Isaac.GetRoomEntities() for u,v in pairs(tgs) do if v.Type == 919 then v = v:ToNPC() print(v:GetSprite():GetAnimation()) print(v.State) print(v.I1.." "..v.I2) print(v.V1) print(v.V2) print(v.Position) end end
        },
        [214] = {
            level = 3.5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,8) == "Teleport" then return 2 end
                return -1
            end,
        },
        [215] = {
            level = 2.5,
            can_multi = true,
            order = function(ent,info)
                if info.set_visible(ent) == false then return 5 end
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,4) == "Move" then return 1 end
                if string.sub(anim,1,4) == "Stun" then return -2 end
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if s:IsFinished("Possess") then return false end
                return true
            end,
            no_overlay = true,
            --!! 尾巴要想办法修一修
        },
        [216] = {
            level = 6,
            is_multi = true,
            no_overlay = true,
            order = -0.5,
            protect_self = true,
            check_all_type = true,
            --Force_Spawn_Info = function(ent,es)
            --    if es.Type == 960 then return true end
            --end,              --崩溃
            NotSpawn = true,    --!!需要想办法修复cord
        },
        [217] = {
            level = 6,
            KeepTarget = true,
            Force_Spawn_Info = function(ent,es)
                if es.Type == 950 then return true end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,4) == "Ring" then return 1 end
                if anim == "SpreadAttack" then return 0 end
                return -1
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,4) == "Ring" and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 120 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 8
                ent:GetSprite():Play("SpreadAttack",true)
            end,
            on_death = function(ent)
                ent:Remove()
            end,
        },
        [218] = {
            level = 5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,4) == "Dash" or anim == "Reverse" then return 1 end
                if ent.State == 16 then return -2 end
                return -1
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,4) == "Dash" or (anim == "Reverse" and s:IsFinished(anim)) and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 60 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
                if ent.HitPoints/ent.MaxHitPoints < 0.4 and d[own_key.."Swap"] ~= true then
                    d[own_key.."Swap"] = true
                    ent.State = 16
                    s:Play("Transition",true)
                end
            end,
            force_move = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Reverse" then
                    ent.State = 3
                    ent:GetSprite():Play("Idle",true)
                else
                    ent.State = 9
                    ent:GetSprite():Play("Reverse",true)
                end
            end,
        },
        [219] = {
            level = 5,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if string.sub(anim,1,8) == "Headless" or anim == "HorseSpit" then return {1,}
                else return {1,0,} end
            end,
            rnds = 0.5,
            --!! 64 瘟疫的头消失后没有立即确认？
            --!! 为什么头消失后没有对齐？
        },
        [220] = {
            level = 5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,4) == "Dash" or anim == "Knockback" then return 1 end
                if string.sub(anim,1,5) == "Lunge" then return 0 end
                if ent.State == 16 then return -2 end
                return -1
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (string.sub(anim,1,4) == "Dash" or anim == "Knockback") and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 120 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
                if ent.HitPoints/ent.MaxHitPoints < 0.4 and d[own_key.."Swap"] ~= true then
                    d[own_key.."Swap"] = true
                    ent.State = 16
                    s:Play("Transition",true)
                end
            end,
            force_move = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Knockback" then
                    ent.State = 7 ent.I1 = 1
                    ent:GetSprite():Play("LungeShort",true)
                else
                    ent.State = 8
                    ent:GetSprite():Play("ThrowBomb",true)
                end
            end,
        },
        [221] = {
            level = 5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,5) == "Swing" then return 2 end
                return -1
            end,
            set_color = true,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim == "Idle") and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 150 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 16
                ent:GetSprite():Play("SwingPrepare",true)
            end,
            --!!需要打断招式
        },
        [222] = {       --!!似乎还有bug
            level = 6,
            DontSpawn = function(ent)
                local d = ent:GetData()
                if d[own_key.."Init"] then return false end
                return true
            end,
            clear_another = true,
            special = function(ent,ment,is_main,info)
                local tgs = auxi.getothers(nil,951,1)
                for u,v in pairs(tgs) do
                    if v.SpawnerEntity and auxi.check_for_the_same(v.SpawnerEntity,ent) then
                        --if v.SubType == 0 then v.TargetPosition = Vector(v.TargetPosition.X,math.min(v.TargetPosition.Y,60))
                        --else v.TargetPosition = Vector(v.TargetPosition.X,math.max(v.TargetPosition.Y,560)) end
                        if ent.FlipX then
                            v.Velocity = Vector(-5,0)
                            v.TargetPosition = v.TargetPosition + v.Velocity
                            if v.Position.X < -100 then v:Remove() end
                        else
                            v.Velocity = Vector(5,0)
                            v.TargetPosition = v.TargetPosition + v.Velocity
                            if v.Position.X > ent.Position.X + 400 then v:Remove() end
                        end
                    end
                end
                local d = ent:GetData()
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                else
                    if d[own_key.."skip_dash"] then
                        d[own_key.."skip_dash"] = d[own_key.."skip_dash"] - 0.2
                        if d[own_key.."skip_dash"] <= 0 then d[own_key.."skip_dash"] = nil end
                    end
                 end
            end,
            special_All = function(ent)
                local d = ent:GetData()
                if ent.State == 16 then
                    if d[own_key.."UnInit"] == nil then
                        d[own_key.."Init"] = true
                    end
                else
                    if d[own_key.."Init"] then
                        -- Stitch Base_holder.init = full mix.generate_mixture pipeline; unsupported here.
                        local native_reinit = require("Qing_Remaster_scripts.auxiliary.native_mixture.native_reinit")
                        native_reinit.reinitialize(ent, "entry_1_222_state_transition")
                        d[own_key.."Init"] = nil
                    end
                end
                d[own_key.."UnInit"] = true
            end,
            force_move = function(ent)
                ent:GetSprite():Play("MoveEndTurn",true)
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Dive" and fr > 25 then return false end
                return true
            end,
            order = function(ent,info)
                --if true then return 20 end
                if info.set_visible(ent) == false then return 5 end
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                local d = ent:GetData()
                if (d[own_key.."skip_dash"] or 0) > 60 then return 999 end
                if anim:sub(1,4) == "Move" then return 1 end
                return 0.25
            end,
            protect_flip = true,
            on_death = function(ent)
                ent:Remove()
            end,
        },



        [223] = {
            check = 23,
        },
        [224] = {
            check = 26,
        },
        [225] = {
            level = 2.5,
            NotSpawn = true,
            DontSpawn = true,
            order = 2999,
            protect_pos = function() end,
        },
        [226] = {
            level = 2.5,
            strength = 10,
            NotSpawn = true,
        },
        [227] = {
            check = 95,
            rnds = 0.8,
        },
        [228] = {
            level = 6,
            NotSpawn = true,
            const_spawner = true,
            --is_offset = true,
            order = function(ent)
                if ent.State == 2 then return 999 end
            end,
        },
        [229] = {
            check = 228,
        },
        [230] = {
            level = 6,
            order = -2,
            is_multi = true,
            NoKill = true,
            NotSpawn = true,
            KeepTarget = true,
        },
        [231] = {
            level = 2.5,
            NotSpawn = true,
            DontSpawn = true,
            KeepTarget = true,
            order = -2,
            NoKill = true,
            stone = true,
            Nature_Spawner = 1,
            HitPoints = 300,
            special = function(ent)
                if Game():GetFrameCount() % 15 == 5 then
                    local enemies = auxi.getallenemies()
                    local allents = auxi.getothers(nil,907)
                    --print(#allents)
                    local tgs = collector.search_for_linkage(ent,nil,nil,{check_parent = true,take_linker = true,stack = allents,})
                    --print(#tgs)
                    --print(#enemies)
                    if #tgs >= #enemies then
                        --print("Try Update")
                        collector.update_npc(ent)
                    end
                end
            end,
        },
        [232] = {
            level = 6,
            order = -2,
            NoKill = true,
            DontSpawn = true,
            NotSpawn = true,
            KeepTarget = true,
            NoDeliTexture = true,
        },
    },
    [2] = {
        [1] = {
            check_all_type = true,
            protect_self = true,
            order = 0,
            rnds = 0.4,
        },
        [2] = {
            check = 1,
        },
        [3] = {
            check = 1,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if anim.sub(1,4) == "Walk" then return {0,} end
                if anim == "Head" then return {1,} end
            end,
        },
        [4] = {
            no_overlay = true,
            reload = true,
            rnds = 0.3,
        },
        [5] = {
            check = 4,
        },
        [6] = {
            order = -2,
        },
        [7] = {
            is_offset = true,
            check_all_type = true,
            tiny = true,
            order = -2,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 12,
                        ed = 20,
                    },
                },
            },
        },
        [8] = {
            order = -2,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 10,
                        ed = 23,
                    },
                    [3] = {
                        st = 10,
                        ed = 22,
                    },
                    [4] = {
                        st = 10,
                        ed = 22,
                    },
                    [7] = {
                        st = 10,
                        ed = 19,
                    },
                    [8] = {
                        st = 10,
                        ed = 19,
                    },
                    [9] = {
                        st = 10,
                        ed = 25,
                    },
                    [10] = {
                        st = 10,
                        ed = 24,
                    },
                    [12] = {
                        st = 10,
                        ed = 22,
                    },
                    [14] = {
                        st = 10,
                        ed = 23,
                    },
                    [16] = {
                        st = 10,
                        ed = 23,
                    },
                },
            },
        },
        [9] = {
            check = 8,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 10,
                        ed = 26,
                    },
                    [3] = {
                        st = 10,
                        ed = 22,
                    },
                    [4] = {
                        st = 10,
                        ed = 22,
                    },
                    [7] = {
                        st = 10,
                        ed = 19,
                    },
                    [8] = {
                        st = 10,
                        ed = 19,
                    },
                    [9] = {
                        st = 10,
                        ed = 27,
                    },
                    [10] = {
                        st = 10,
                        ed = 24,
                    },
                    [12] = {
                        st = 10,
                        ed = 25,
                    },
                    [14] = {
                        st = 10,
                        ed = 24,
                    },
                    [16] = {
                        st = 10,
                        ed = 24,
                    },
                },
            },
        },
        [10] = {
            order = -0.8,
            rnds = 0.4,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State == 4 and ent:GetSprite():GetAnimation() == "Hop" then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    d[own_key.."counter"] = d[own_key.."counter"] or auxi.choose(0,0,15,30)
                    if d[own_key.."skip_dash"] > d[own_key.."counter"] then d[own_key.."counter"] = auxi.choose(0,0,15,30) info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 8 ent:GetSprite():Play("Attack",true)
            end,
        },
        [11] = {
            check = 10,
        },
        [12] = {
            check = 10,
        },
        [13] = {
            rnds = 0.5,
            order = -0.8,
        },
        [14] = {
            check = 13,
        },
        [15] = {
            check = 13,
            order = 0.2,
        },
        [16] = {
            order = -0.05,
            is_offset = true,
            tiny = true,
            rnds = 0.3,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 12,
                        ed = 20,
                    },
                    [4] = {
                        st = 12,
                        ed = 20,
                    },
                },
            },
        },
        [17] = {
            order = -0.5,
        },
        [18] = {
            check = 13,
        },
        [19] = {
            level = 2,
            check = 13,
        },
        [20] = {
            level = 2,
            order = function(ent)
                if ent.State == 8 then return 1 end
            end,
            rnds = 0.5,
            protect_flip = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Attack Hori" then return true end
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State == 8 and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 4
                ent:GetSprite():Play("Move Hori",true)
            end,
        },
        [21] = {
            check = 20,
        },
        [22] = {
            check = 20,
        },
        [23] = {
            level = 3,
            check = 20,
        },
        [24] = {
            level = 2,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if string.sub(anim,1,5) == "ReGen" then return -2 end
                return 0.15
            end,
            rnds = 0.5,
            protect_self = true,
            on_death = function(ent)
                ent:Remove()
            end,
            protect_time = 3,       --因为复活后扣血上限写起来很麻烦，不如就限制复活次数吧
        },
        [25] = {
            check = 24,
            rnds = 0.7,
        },
        [26] = {
            level = 3,
            check = 24,
            rnds = 0.5,
        },
        [27] = {
            level = 2,
            order = -0.75,
            rnds = 0.5,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 6,
                        ed = 27,
                    },
                },
            },
        },
        [28] = {
            check = 27,
        },
        [29] = {
            check = 27,
        },
        [30] = {
            level = 2,
            rnds = 0.3,
        },
        [31] = {
            check = 30,
        },
        [32] = {
            level = 3,
            check = 30,
        },
        [33] = {
            level = 2,
            order = -2,
            special_damage_over = function(ent,amt,flag,source,cooldown,tent)
                local s = tent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if tent.SubType == 0 then
                    if anim ~= "Shoot" then return false end
                    if fr < 10 or fr > 55 then return false end
                end
            end,
            --check_all_type = true,
        },
        [34] = {
            level = 3,
            order = -2,
        },
        [35] = {
            level = 2,
            KeepTarget = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim == "Hop" and fr >= 5) or anim:sub(1,7) == "BigJump" then return true end
            end,
            swap_weight = 9,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(1,7) == "BigJump" then return 2 end
                if anim == "Hop" and (fr > 4 and fr < 18) then return 0 end
            end,
        },
        [36] = {
            level = 1,
            check = 35,
        },
        [37] = {
            KeepTarget = true,
            order = -2,
            AutoRegen = true,       --这个标签的敌人需要实现自我恢复，就每5帧恢复1点血吧？
        },
        [38] = {
            check = 37,
        },
        [39] = {
            check = 37,
        },
        [40] = {
            level = 2,
            rnds = 0.8,
        },
        [41] = {
            level = 3,
            rnds = 0.9,
        },
        [42] = {
            level = 3,
            check = 35,
        },
        [43] = {
            level = 3,
            check_all_type = true,
            order = function(ent)
                if ent.State == 8 then return -2 end
            end,
        },
        [44] = {
            level = 3,
            check_all_type = true,
            order = 0,
            rnds = 0.6,
        },
        [45] = {
            check = 43,
        },
        [46] = {
            check = 44,
        },
        [47] = {
            level = 3,
            strength = 50,
            check = {v1 = 1,v2 = 19,},
        },
        [48] = {
            level = 4,
            check = 47,
        },
        [49] = {
            level = 3,
            Catch_Laser = true,
            real_tg_layer = {1,0,},
            rnds = 0.3,
            order = -1.5,
        },
        [50] = {
            check = 49,
        },
        [51] = {
            level = 4,
            check = 49,
        },
        [52] = {
            level = 4,
            check = 49,
        },
        [53] = {
            level = 3,
            rnds = 0.6,
            on_swap = function(ent,info,is_in)
                if is_in then
                    local room = Game():GetRoom()
                    local tpos = room:GetGridPosition(room:GetGridIndex(ent.Position))
                    ent.TargetPosition = tpos
                    ent.I1 = auxi.choose(0,1,2,3)
                    ent:Update()
                end
            end,
            naturally_move_back = 3,
            order = -0.5,
        },
        [54] = {
            level = 4,
            check = 53,
        },
        [55] = {
            level = 2,
            order = function(ent)
                if ent.State == 8 then return 1 end
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State == 8 and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 4
            end,
            protect_flip = true,
            special_damage_over = function(ent,amt,flag,source,cooldown,tent)
                local s = tent:GetSprite() local anim = s:GetAnimation()
                local dir = Vector(0,1)
                if anim == "Up" then dir = Vector(0,-1)
                elseif anim == "Hori" then if s.FlipX then dir = Vector(-1,0) else dir = Vector(1,0) end end
                if source and source.Entity then
                    local se = source.Entity
                    if se.Type == 2 then
                        local dir2 = ((se.Position - se.Velocity) - tent.Position):Normalized()
                        local cos_theta = (dir.X * dir2.X + dir.Y * dir2.Y)
                        local angle = math.acos(cos_theta) * 180 / math.pi
                        if angle < 60 then
                            return false
                        end
                    end
                end
            end,
        },
        [56] = {
            check = 55,
        },
        [57] = {
            KeepTarget = true,
            order = -2,
            NoKill = true,
            init = function(ent)
                local pos = auxi.Vector2Table(ent.Position)
                ent.Position = Vector(0,0) ent:Update()
                ent.TargetPosition = auxi.ProtectVector(pos)
                ent.Position = auxi.ProtectVector(pos)
            end,
            stone = true,
        },
        [58] = {
            check = 57,
        },
        [59] = {
            NoKill = true,
            order = -1,
            rnds = 0.5,
            HitPoints = 20,
            stone = true,
        },
        [60] = {
            check = 59,
            rnds = 0.75,
            order = function(ent)
                if ent.State == 8 then return 1 end
                return -2
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State == 4 then ent.V1 = ment.Position end
                if not is_main then
                    if ent.State == 8 then
                        d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                        if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                    else d[own_key.."skip_dash"] = nil end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 4
            end,
        },
        [61] = {
            level = 4,
            Replace_with_sprite = true,
            Recheck_on_init = true,
            order = -1,
            naturally_move_back = 0.3,
        },      --无法生成复数只
        [62] = {
            level = 5,
            check = 61,
        },
        [63] = {
            real_tg_layer = {1,},
            check_all_type = true,
            check = 35,
        },
        [64] = {
            level = 3,
            order = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if string.sub(anim,1,4) == "Dash" then return 1 end
            end,
            rnds = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if string.sub(anim,1,4) == "Dash" then return 1 end
                return 0.5
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                if ent.State == 8 and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 4
                ent:GetSprite():Play("Hori",true)
            end,
        },
        [65] = {
            level = 4,
            check = 64,
        },
        [66] = {
            level = 4,
            check = 64,
        },
        [67] = {
            level = 4,
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim == "Emerge" and fr <= 4 then return false end
                if anim == "Hide" and fr >= 4 then return false end
                return true
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                return -2
            end,
            KeepTarget = true,
            HideAll = true,
            prevent_velocity = true,
        },
        [68] = {
            level = 4,
            rnds = 0.3,
        },
        [69] = {
            check = 68,
        },
        [70] = {
            level = 4,
            --order = 0,
        },
        [71] = {
            check = 70,
        },
        [72] = {
            level = 4,
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim == "DigUp" and fr <= 4 then return false end
                if anim == "DigDown" and fr >= 7 then return false end
                if anim:sub(1,4) == "Jump" and fr >= 30 then return false end
                return true
            end,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,4) == "Jump" then return 9 end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                if anim:sub(1,4) == "Jump" then return -1 end
                return -2
            end,
            KeepTarget = true,
            HideAll = true,
        },
        [73] = {
            level = 4,
            order = -2,
            Catch_Laser = true,
            KeepTarget = true,
            Replace_with_sprite = true,     --原版会修改眼睛位置，换掉
        },  --!!
        [74] = {
            check = 73,
        },
        [75] = {
            level = 2,
            order = 0,
            rnds = 0.3,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 8,
                        ed = 22,
                    },
                },
            },
        },
        [76] = {
            level = 2,
            check = 75,
        },
        [77] = {
            level = 4,
            order = -1,
            rnds = 0.7,
            check = 75,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 8,
                        ed = 28,
                    },
                    [4] = {
                        st = 8,
                        ed = 27,
                    },
                    [6] = {
                        st = 8,
                        ed = 29,
                    },
                },
            },
        },
        [78] = {        --!!是否要留下来呢？
            NotSpawn = true,
            strength = 10,
            level = 3,
            order = 0,
        },
        [79] = {
            swap_weight = 3,
            order = -1.25,
            rnds = 0.2,
        },
        [80] = {
            order = 0,
            rnds = 0.1,
            tiny = true,
            is_offset = true,
        },
        [81] = {
            order = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Walk" then return 0
                else return -2 end
            end,
            --KeepTarget = true,
            naturally_move_back = 3,
            rnds = 0.75,
            rnds_add = 0.2,
            check_reload = function(ent)
                local s = ent:GetSprite()
                if s:GetFilename():sub(-9,-1) == "left.anm2" or s:GetFilename():sub(-10,-1) == "right.anm2" then
                else return true end
            end,
            spider = true,
        },
        [82] = {
            level = 2,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,4) == "Jump" then return 5 end
            end,
            KeepTarget = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim:sub(1,4) == "Jump" and fr <= 20) then return true end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,4) == "Jump" then return 0 end
                return -2
            end,
        },
        [83] = {
            level = 2,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,4) == "Walk" then return 0 end
                return -2
            end,
            rnds = 0.5,
        },
        [84] = {
            level = 2,
            rnds = 0.5,
        },
        [85] = {
            check = 84,
        },
        [86] = {
            check = 84,
        },
        [87] = {
            level = 2,
            order = function(ent) if ent.ParentNPC then return 999 else return -1 end end,
        },
        [88] = {
            level = 3,
            rnds = 0.6,
        },
        [89] = {
            level = 2,
            rnds = 0.4,
        },
        [90] = {
            level = 3,
            rnds = 0.5,
        },
        [91] = {
            --can_multi = true,
            NoKill = true,
            level = 3,
            order = function(ent)
                if ent.I1 == 1 then return 1 end
            end,
            --l local tgs = Isaac.GetRoomEntities() for u,v in pairs(tgs) do if v.Type == 93 then v = v:ToNPC() print(v:GetSprite():GetFilename()) print(v:GetSprite():GetAnimation()) print(v.State) print(v.I1.." "..v.I2) print(v.V1) print(v.V2) print(v.Position) end end
        },
        [92] = {
            check = 81,
        },
        [93] = {
            NotSpawn = true,
            NoKill = true,
            HitPoints = 10,
            protect_pos = function() end,
            --KeepTarget = true,
            order = -2,
            check = 7,
            check_all_type = true,
            naturally_move_back = 0.3,
            --protect_self = true,
            stone = true,
        },
        [94] = {
            level = 3,
            KeepTarget = true,
            order = -2,
            NoKill = true,
            Catch_Laser = true,
            HitPoints = 25,
            init = function(ent)
                local pos = auxi.Vector2Table(ent.Position)
                ent.Position = Vector(0,0) ent:Update()
                ent.TargetPosition = auxi.ProtectVector(pos)
                ent.Position = auxi.ProtectVector(pos)
            end,
            stone = true,
        },
        [95] = {
            level = 2,
            KeepTarget = true,
            order = -2,
            NoKill = true,
            HitPoints = 20,
            init = function(ent)
                local pos = auxi.Vector2Table(ent.Position)
                ent.Position = Vector(0,0) ent:Update()
                ent.TargetPosition = auxi.ProtectVector(pos)
                ent.Position = auxi.ProtectVector(pos)
            end,
            stone = true,
        },
        [96] = {
            check = 95,
        },
        [97] = {
            check = 95,
        },
        [98] = {
            check = 95,
        },
        [99] = {
            check = 95,
        },
        [100] = {
            level = 5,
            HitPoints = 15,
            check = 95,
        },
        [101] = {
            level = 4,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if anim == "Appear" then return {0,1,} end
            end,
            special_damage_over = function(ent,amt,flag,source,cooldown,tent)
                local s = tent:GetSprite() local anim = s:GetOverlayAnimation() local fr = s:GetOverlayFrame()
                if tent.SubType == 0 and (anim ~= "Shoot" or (fr < 10 or fr > 53)) then return false end
            end,
            rnds = 0.6,
        },
        [102] = {
            check = 13,
        },
        [103] = {
            rnds = 0.8,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Attack" or anim == "Lay Egg" then return -2 end
            end,
        },
        [104] = {
            level = 2,
            check = 103,
        },
        [105] = {
            check = 103,
        },
        [106] = {
            level = 2,
            check = 103,
        },
        [107] = {
            order = -0.3,
            rnds = 0.3,
        },
        [108] = {
            level = 2,
            check = 107,
            check_all_type = true,
            protect_self = true,
        },
        [109] = {
            check_all_type = true,
            no_overlay = true,
            check = 107,
        },
        [110] = {
            level = 3,
            real_tg_layer = {0,1,},
            check = 107,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Jump" or anim == "Land" then return 9 end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim == "Jump" and fr >= 4) or (anim == "Land" and fr <= 5) then return 2 end
                return -1
            end,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                if source and source.Entity then
                    local se = source.Entity
                    if se.Type == 82 then return false end
                end
            end,
            check_all_type = true,
            protect_self = true,
        },
        [111] = {
            level = 2,
            check_all_type = true,
            protect_self = true,
        },
        [112] = {
            level = 2,
        },
        [113] = {
            level = 3,
            order = -0.7,
            NoKill = true,
        },
        [114] = {
            level = 3,
            order = -0.7,
        },
        [115] = {
            level = 3,
            swap_weight = 5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim == "JumpDown" and fr >= 12) or (anim == "JumpUp" and fr <= 9) or anim == "Stunned" or anim == "Grab" then return -2 end
                return 5
            end,
        },
        [116] = {
            order = 0,
            rnds = 0.4,
        },
        [117] = {
            KeepTarget = function(ent)
                local d = ent:GetData()
                if (d[own_key.."count"] or 0) > 30 then return true end
            end,
            special = function(ent)
                local s = ent:GetSprite() local d = ent:GetData()
                if s:IsPlaying("Walk") then d[own_key.."count"] = (d[own_key.."count"] or 0) + 1
                else d[own_key.."count"] = 0 end
            end,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Jump" or anim == "InAir" then return 5 end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Walk" then return -0.5 end
                if anim == "Jump" or anim == "InAir" then return 0 end
                return -2
            end,
        },
        [118] = {
            level = 3,
        },
        [119] = {
            level = 3,
            NotSpawn = true,
        },
        [120] = {
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Move" then return 0 end
            end,
            rnds = 0.75,
        },
        [121] = {
            check = 120,
        },
        [122] = {
            check = 120,
        },
        [123] = {
            level = 2,
            NoKill = true,
            order = -0.75,
            KeepTarget = true,
            HitPoints = 20,
            stone = true,
            --l local tgs = Isaac.GetRoomEntities() for u,v in pairs(tgs) do if v.Type == 218 then v = v:ToNPC() print(v:GetSprite():GetFilename()) print(v:GetSprite():GetAnimation()) print(v.State) print(v.I1.." "..v.I2) print(v.V1) print(v.V2) print(v.TargetPosition) end end
        },
        [124] = {
            level = 3,
            HideAll = true,
            Force_Not_Spawn_Info = function(ent,es)
                if es.Type == 101 then return true end
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(1,6) == "Appear" and fr <= 5 then return false end
                if anim:sub(1,6) == "Vanish" and fr >= 7 then return false end
                return true
            end,
            order = function(ent,info)
                if info.set_visible(ent) == false then return 5 end
                return -2
            end,
            Replace_with_sprite = true,
            special_on_invisible = function(ent,offset,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then
                    local s2 = auxi.copy_sprite(s,nil,{filename = "gfx/"..info.name..".anm2",SetScale = true,SetOffset = true,SetRotation = true,})
                    --s2:ReplaceSpritesheet(5,"gfx/SE_shadow.png") s2:LoadGraphics()
                    s2:Render(offset)
                end
            end,
            set_anm2 = {0,1,},
        },
        [125] = {
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Attack01" and fr >= 35 then return 0 end
                if anim == "Slide" then return 0 end
                return -2
            end,
        },
        [126] = {
            level = 3,
            check = 125,
        },
        [127] = {
            level = 4,
            KeepTarget = true,
            order = -2,
            special_damage_over = function(ent,amt,flag,source,cooldown,tent)
                local s = tent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Appear" or anim == "Attack" or anim == "Pulse" or (anim == "DigIn" and fr >= 10) or (anim == "DigOut" and fr <= 10) then return false end
            end,
        },
        [128] = {
            need_multi = {1,2,3,4,5,},
            check = 16,
            order = -0.15,
        },
        [129] = {
            level = 2,
            order = -2,
        },
        [130] = {
            level = 4,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Charge Shake" or (anim == "Charge" and fr > 20) then return 1 end
                if anim == "Spawn" or (anim == "Charge" and fr <= 20) then return -2 end
                return -1
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if ent.State == 8 and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 13
                ent:GetSprite():Play("Spawn",true)
            end,
        },
        [131] = {
            level = 5,
            check = 130,
        },
        [132] = {
            rnds = 0.3,
            order = -0.5,
        },
        [133] = {
            check = 132,
            level = 2,
            protect_self = true,
            check_all_type = true,
        },
        [134] = {
            check = 132,
            rnds = 0.75,
            order = function(ent)
                local hprate = ent.HitPoints/ent.MaxHitPoints
                if hprate < 0.5 then return 1 end
            end,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if anim:sub(1,4) == "Head" then return {1,} end
            end,
            on_damage = function(ent,amt,flag,source,cooldown,tent)
                tent:TakeDamage(0.1,0,EntityRef(tent),666)
            end,
        },
        [135] = {
            level = 3,
            order = function(ent)
                if ent.State == 8 then return -2
                else return -0.5 end
            end,
        },
        [136] = {
            level = 4,
            KeepTarget = true,
            order = function(ent)
            end,
        },
        [137] = {
            level = 4,
            rnds = 0.3,
        },
        [138] = {
            level = 5,
            check = 137,
            Catch_Laser = true,
        },
        [139] = {
            order = -2,
            level = 4,
            KeepTarget = true,
        },
        [140] = {
            check = 139,
        },
        [141] = {
            level = 2,
            order = function(ent)
                if ent.State == 8 then return -0.5
                else return -1 end
            end,
        },
        [142] = {
            level = 2,
            KeepTarget = true,
            order = -2,
            NoKill = true,
            init = function(ent)
                local pos = auxi.Vector2Table(ent.Position)
                ent.Position = Vector(0,0) ent:Update()
                ent.TargetPosition = auxi.ProtectVector(pos)
                ent.Position = auxi.ProtectVector(pos)
            end,
            CoverDetail = {
                [0] = {
                    [3] = {
                        st = -999,
                        ed = -999 + 60,
                    },
                    [4] = {
                        st = -999,
                        ed = -999 + 60,
                    },
                    [5] = {
                        st = -999,
                        ed = -999 + 60,
                    },
                },
            },
            stone = true,
            HitPoints = 20,
        },
        [143] = {
            check = 142,
            CoverDetail = {
                [0] = {
                    [4] = {
                        st = -999,
                        ed = -999 + 60,
                    },
                    [5] = {
                        st = -999,
                        ed = -999 + 60,
                    },
                    [6] = {
                        st = -999,
                        ed = -999 + 60,
                    },
                },
            },
        },
        [144] = {
            check = {v1 = 1,v2 = 129,},
        },
        [145] = {
            level = 2,
            check = 4,
        },
        [146] = {
            level = 2,
            check = {v1 = 1,v2 = 1,},
        },
        [147] = {
            level = 2,
            follow_rotate = true,
            naturally_move_back = 0.1,
            Reset_counter = true,
            rnds = 0.4,
            KeepTarget_Special = true,
            prevent_velocity = true,
            protect_flip = true,
            protect_flipY = true,
            --所有蜘蛛好像都共享一个代码。但是表现非常奇怪
        },
        [148] = {
            check = 147,
            Catch_Laser = true,
        },
        [149] = {
            check = 147,
        },
        [150] = {
            level = 2,
            rnds = 0.5,
        },
        [151] = {
            level = 2,
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim == "DigIn" and fr >= 4 then return false end
                if anim == "DigOut" and fr <= 2 then return false end
                return true
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                return -2
            end,
            KeepTarget = true,
            HideAll = true,
            prevent_velocity = true,
        },
        [152] = {
            check = 151,
        },
        [153] = {
            level = 3,
            check = 35,
            KeepTarget = function(ent)
                if ent.State == 4 then return true end
            end,
        },
        [154] = {
            level = 1,
            check = 153,
        },
        [155] = {
            level = 4,
            rnds = 0.4,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if anim == "Appear" then return {0,1,} end
            end,
        },
        [156] = {
            level = 3,
            check = 6,
        },
        [157] = {
            order = -0.5,
        },
        [158] = {
            level = 1,
            check = 117,
        },
        [159] = {
            level = 5,
            check = 136,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if anim == "Head" or anim == "Awaken" then return {1,2,} end
            end,
            set_color = true,
            on_damage = function(ent,amt,flag,source,cooldown,tent)
                tent:TakeDamage(0.1,0,EntityRef(tent),666)
            end,
        },
        [160] = {
            level = 3,
            set_color = true,
            on_damage = function(ent,amt,flag,source,cooldown,tent)
                tent:TakeDamage(0.1,0,EntityRef(tent),666)
            end,
        },
        [161] = {
            level = 5,
            check = 137,
        },
        [162] = {
            level = 3,
            check = 55,
        },
        [163] = {
            level = 2,
            check = 151,
        },
        [164] = {
            order = -0.5,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 11,
                        ed = 21,
                    },
                },
            },
        },
        [165] = {
            level = 2,
            rnds = 0.3,
            check_all_type = true,
            protect_self = true,
            order = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,6) == "Attack" then return -2 end
            end,
        },
        [166] = {
            level = 5,
            check = 165,
        },
        [167] = {
            check = 141,
        },
        [168] = {
            level = 3,
            check = {v1 = 1,v2 = 19,},
        },
        [169] = {
            level = 3,
            set_color = true,
            order = function(ent)
                if ent.State == 3 then return -2 end
            end,
            naturally_move_back = true,
        },
        [170] = {
            check = 151,
            rnds = 0.2,
        },
        [171] = {
            check = 135,
        },
        [172] = {
            level = 3,
            order = -0.25,
        },
        [173] = {
            level = 3,
            strength = 30,
            rnds = 0.5,
        },
        [174] = {
            level = 3,
            check = 4,
        },
        [175] = {
            can_multi = true,
            rnds = 0.5,
            check = 16,
            order = 0,
            --KeepTarget = true,
            KeepTarget_Special = function(ent)
                local room = Game():GetRoom()
                if room:IsPositionInRoom(ent.TargetPosition,-20) ~= true then return true end
            end,
            naturally_move_back = true,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 12,
                        ed = 20,
                    },
                    [4] = {
                        st = 12,
                        ed = 20,
                    },
                    [17] = {
                        st = 12,
                        ed = 20,
                    },
                },
            },
        },
        [176] = {
            level = 3,
            order = -2,
        },
        [177] = {
            level = 3,
            check = 55,
        },
        [178] = {
            check = 1,
        },
        [179] = {
            level = 5,
            Catch_Laser = true,
            check = 124,
        },
        [180] = {
            level = 4,
            check = 114,
        },
        [181] = {
            level = 4,
            check = 115,
        },
        [182] = {
            level = 2,
            order = -0.75,
            rnds = 0.5,
        },
        [183] = {
            level = 1,
            check = 151,
        },
        [184] = {
            level = 4,
            order = -2,
            protect_self = true,
            check_all_type = true,
        },
        [185] = {
            level = 3,
            DontSpawn = true,
            NotSpawn = true,        --!!这个坑很奇怪
            NoKill = true,
            order = -2,
        },
        [186] = {
            check = 185,
        },
        [187] = {
            check = 185,
        },
        [188] = {
            --NotSpawn = true,
            can_multi = true,
            level = 3,
            strength = 10,
            rnds = 0.4,
        },
        [189] = {
            check = 188,
        },
        [190] = {
            NotSpawn = true,
            level = 2,
            order = -2,
        },
        [191] = {
            need_multi = {1,2,3,4,},
            kill_self = true,
            --can_multi = true,
            level = 4,
            check = 16,
            order = -0.5,
        },
        [192] = {
            level = 4,
            check = 1,
        },
        [193] = {
            level = 4,
            check = 37,
        },
        [194] = {
            level = 3,
            check = 1,
        },
        [195] = {
            level = 2,
            order = -2,
            KeepTarget = true,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                if flag & DamageFlag.DAMAGE_CLONES ~= 0 then
                else
                    if tent:GetSprite():GetAnimation() == "Blocking" then
                        ent:TakeDamage(amt * 0.3,flag | DamageFlag.DAMAGE_CLONES,source,cooldown)
                        return false
                    end
                end
            end,
        },
        [196] = {
            level = 3,
        },
        [197] = {
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Pant" then return -2 end
                return -0.5
            end,
            NoKill = true,
            HitPoints = 30,
            stone = true,
        },
        [198] = {
            level = 3,
            check = 197,
            Overlay_Add_With = 0,
            Overlay_Adder = function(s,animdata)
                return animdata.NullAnimations[2].Frames
            end,
        },
        [199] = {
            level = 2,
            check = 35,
        },
        [200] = {
            check = 147,
            real_tg_layer = {0,1,},
            CoverDetail = {
                [0] = {
                    [10] = {
                        st = 6,
                        ed = 24,
                    },
                    [11] = {
                        st = 6,
                        ed = 24,
                    },
                    [12] = {
                        st = 6,
                        ed = 24,
                    },
                    [13] = {
                        st = 6,
                        ed = 24,
                    },
                    [14] = {
                        st = 6,
                        ed = 24,
                    },
                    [15] = {
                        st = 6,
                        ed = 24,
                    },
                    [16] = {
                        st = 6,
                        ed = 24,
                    },
                    [17] = {
                        st = 6,
                        ed = 24,
                    },
                    [22] = {
                        st = 6,
                        ed = 24,
                    },
                },
            }
        },
        [201] = {
            swap_weight = 9,
            KeepTarget = function(ent)
                local anim = ent:GetSprite():GetAnimation()
                if anim == "Hop" or anim == "BigJump" then return true end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Hop" and (fr > 4 and fr < 18) then return 0 end
                if anim == "Attack" then return -2 end
            end,
            rnds = 0.5,
        },
        [202] = {
            level = 5,
            skip_rotate = true,
            KeepTarget = true,
            order = -2,
            Replace_with_sprite = true,
            pre_render = function(ent,offset1,offset2,info)
                local s = ent:GetSprite() local d = ent:GetData() d[own_key.."replace_sprite"] = d[own_key.."replace_sprite"] or Sprite()
                local s2 = auxi.copy_sprite(s,d[own_key.."replace_sprite"],{filename = "gfx/"..info.name..".anm2",})
                s2:Render(offset2)
            end,
            kill_self = true,
            on_anim = function(animinfo,ent,info)
                local s = ent:GetSprite()
                return {
                    XPosition = animinfo.XPosition,
                    YPosition = animinfo.YPosition,
                    XScale = 100,
                    YScale = 100,
                    Rotation = animinfo.Rotation,
                    CombinationID = animinfo.CombinationID,
                    frame = animinfo.frame,
                    Visible = animinfo.Visible,
                    Interpolated = animinfo.Interpolated,
                }
            end,
            special_on_replace_with = function(s,info,offset,ent)
            end,
            real_tg_layer = {1,0,2,3,4,},
            --!! 需要修复
        },
        [203] = {
            level = 3,
            KeepTarget = true,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                return -2
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if (anim == "Teleport" and fr >= 8) or (anim == "TeleportEnd" and fr <= 4) then return false end
                return true
            end,
        },
        [204] = {
            NotSpawn = true,
            DontSpawn = true,
        },
        [205] = {
            level = 4,
            strength = 30,
            order = 0,
            should_release = true,
        },
        [206] = {
            level = 3,
            check = 37,
        },
        [207] = {
            level = 4,
            check = 13,
            check_all_type = true,
            protect_self = true,
            on_damage = function(ent,amt,flag,source,cooldown,tent)
                tent:TakeDamage(0.1,0,EntityRef(tent),666)
            end,
        },
        [208] = {
            check = 207,
        },
        [209] = {
            check = 207,
        },
        [210] = {
            check = 207,
        },
        [211] = {
            check = 205,
            strength = 10,
        },
        [212] = {
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim == "DigIn" and fr >= 10 then return false end
                if anim == "DigOut" and fr <= 2 then return false end
                return true
            end,
            order = 666,
            --[[
                order = function(ent,info)
                    local s = ent:GetSprite() local anim = s:GetAnimation()
                    if info.set_visible(ent) == false then return 5 end
                    if ent.State == 8 then return -0.5 end
                    if ent.State == 4 then return -2 end
                end,
            ]]
            NotSpawn = true,
            --!!代码非常奇怪，需要修复
            rnds = 0.5,
            special = function(ent,ment)
                --[[
                local tgs = collector.collect_all_parents(ent)
                for u,v in pairs(tgs) do
                    if auxi.check_for_the_same(ent,v) ~= true then
                        v.Velocity = Vector(0,0)
                        v.Position = ent.TargetPosition + dpos/8 * v:ToNPC().V1.X
                    end
                end
                --]]
                if (ent.TargetPosition - ent.Position):Length() > 40 and ent.State ~= 8 then
                    ent:GetSprite():Play("Idle",true)
                    ent.State = 8
                end
            end,
                --[[
                local thisd = ent:GetData()
                local room = Game():GetRoom()
                local p1 = auxi.ProtectVector(thisd[own_key.."AddPos"] or Vector(0,0)) + ent.Position
                local d1 = p1 - ent.TargetPosition
                local p2 = ent.TargetPosition + d1:Normalized() * math.min(100,d1:Length())
                ent.Position = p2
                local dp = p1 - p2
                if dp:Length() < 0.1 then thisd[own_key.."AddPos"] = nil
                else thisd[own_key.."AddPos"] = auxi.Vector2Table(dp) end
            end,
            protect_pos = function()
            end,
            delta_pos = function(ent)
                local thisd = ent:GetData()
                if thisd[own_key.."AddPos"] then
                   return auxi.ProtectVector(thisd[own_key.."AddPos"] or Vector(0,0))
                end
            end,
            --]]
            --KeepTarget = true,
        },
        [213] = {
            strength = 10,
            order = -0.5,
            is_offset = true,
        },
        [214] = {
            strength = 5,
            pre_render = function(ent,offset1,offset2,info)
                local s = ent:GetSprite() local d = ent:GetData() d[own_key.."replace_sprite"] = d[own_key.."replace_sprite"] or Sprite()
                local s2 = auxi.copy_sprite(s,d[own_key.."replace_sprite"],{filename = "gfx/"..info.name..".anm2",})
                s2:Render(offset2)
            end,
            Replace_with_sprite = true,
            special_on_replace_with = function(s,info,offset,ent)
            end,
        },
        [215] = {
            level = 4,
            check = 1,
            --set_anm2 = {0,1,},
        },
        [216] = {
            check = 215,
        },
        [217] = {
            check = 215,
        },
        [218] = {
            check = 215,
        },
        [219] = {
            check = 215,
        },
        [220] = {
            check = 215,
            --l local tgs = Isaac.GetRoomEntities() for u,v in pairs(tgs) do if v.Type == 40 then v = v:ToNPC() print(v:GetSprite():GetFilename()) print(v:GetSprite():GetAnimation()) print(v.State) print(v.I1.." "..v.I2) print(v.V1) print(v.V2) print(v.TargetPosition) end end
        },
        [221] = {
            level = 5.5,
            order = -2,
        },
        [222] = {
            level = 1.5,
            check = 10,
            check_all_type = true,
        },
        [223] = {
            level = 5,
            check = 13,
        },
        [224] = {
            level = 5.5,
            check = 13,
        },
        [225] = {
            check = 20,
            level = 3,
        },
        [226] = {
            level = 3.5,
            check = 24,
            Cause_multi = true,
            Force_Not_Spawn_Info = function(ent,es)
                if es.Type == 24 then return true end
            end,
        },
        [227] = {
            level = 2.5,
            check = 27,
        },
        [228] = {
            check = 227,
        },
        [229] = {
            level = 2.5,
            check = 27,
            order = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Attack" then return -2 end
            end,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 7,
                        ed = 27,
                    },
                    [4] = {
                        st = 6,
                        ed = 28,
                    },
                },
            },
        },
        [230] = {
            level = 4.5,
            check = 27,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 7,
                        ed = 29,
                    },
                },
            },
        },
        [231] = {
            level = 5.5,
            check = 27,
            should_release = true,
            CoverDetail = {
                [0] = {
                    [1] = {
                        st = 8,
                        ed = 39,
                    },
                },
            },
        },
        [232] = {
            level = 2.5,
            check = 33,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Idle" then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 240 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 8
                ent:GetSprite():Play("Shoot",true)
            end,
        },
        [233] = {
            level = 3,
            check = 35,
            should_release = true,
        },
        [234] = {
            level = 5.5,
            check = 35,
        },
        [235] = {
            level = 5.5,
            check = 40,
            protect_flip = true,
        },
        [236] = {
            level = 2,
            check = 42,
        },
        [237] = {
            check = 47,
        },
        [238] = {
            level = 4.5,
            check = 47,
            order = function(ent,info)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if info.set_visible(ent) == false then return 5 end
                if anim:sub(1,4) == "Dash" then return 1 end
                if anim == "Attack" then return -2 end
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim:sub(1,4) == "Dash" and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 8
                ent:GetSprite():Play("Attack",true)
            end,
        },
        [239] = {
            level = 5,
            order = -2,
            KeepTarget = true,
        },
        [240] = {
            level = 2.5,
            check = 83,
        },
        [241] = {
            level = 5,
            check = 135,
        },
        [242] = {
            level = 4,
            check = 137,
        },
        [243] = {
            level = 5.5,
            check = 151,
        },
        [244] = {
            NotSpawn = true,
            DontSpawn = true,
        },
        [245] = {
            level = 5.5,
            check = 151,
        },
        [246] = {
            level = 3,
            check = 53,
        },
        [247] = {
            level = 3.5,
            check = 55,
            on_damage = function(ent,amt,flag,source,cooldown,tent)
                tent:TakeDamage(0.1,0,EntityRef(tent),666)
            end,
        },
        [248] = {
            level = 3.5,
            check = 55,
            rnds = 1.5,
        },
        [249] = {
            level = 2,
            check = 57,
        },
        [250] = {
            level = 3,
            check = 75,
        },
        [251] = {
            level = 4.5,
            check = 68,
        },
        [252] = {
            level = 4,
            check = 75,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 12,
                        ed = 39,
                    },
                    [4] = {
                        st = 12,
                        ed = 38,
                    },
                    [6] = {
                        st = 12,
                        ed = 37,
                    },
                    [8] = {
                        st = 12,
                        ed = 38,
                    },
                    [10] = {
                        st = 12,
                        ed = 39,
                    },
                    [12] = {
                        st = 12,
                        ed = 37,
                    },
                    [14] = {
                        st = 12,
                        ed = 37,
                    },
                    [16] = {
                        st = 12,
                        ed = 38,
                    },
                },
            },
        },
        [253] = {
            level = 1,
            order = function(ent,info)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim == "Dash" then return 0.5 end
                return -2
            end,
            special_collision = function(ent,col,low)
                if col and col:ToPlayer() then return {ret = nil,} end
            end,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 10,
                        ed = 24,
                    },
                    [4] = {
                        st = 10,
                        ed = 24,
                    },
                    [6] = {
                        st = 10,
                        ed = 24,
                    },
                },
            },
        },
        [254] = {
            level = 4.5,
            order = 0.5,
            CollisionDamage = 2,
            CoverDetail = {
                [0] = {
                    [2] = {
                        st = 10,
                        ed = 24,
                    },
                    [4] = {
                        st = 10,
                        ed = 24,
                    },
                    [6] = {
                        st = 10,
                        ed = 24,
                    },
                },
            },
        },
        [255] = {
            level = 5.5,
            check = 75,
            order = -1,
            CoverDetail = {
                [0] = {
                    [1] = {
                        st = 10,
                        ed = 40,
                    },
                    [3] = {
                        st = 10,
                        ed = 43,
                    },
                },
            },
        },
        [256] = {
            level = 3.5,
            check = 90,
        },
        [257] = {
            check = 256,
        },
        [258] = {       --!!这里也要考虑面具
            level = 3.5,
            check = 91,
        },
        [259] = {
            level = 3.5,
            check = 113,
        },
        [260] = {
            level = 5,
            check = 113,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(1,6) == "Attack" then return -2 end
                return -0.7
            end,
        },
        [261] = {
            level = 3.5,
            check = 114,
            real_tg_layer = {0,1,},
        },
        [262] = {
            level = 2.5,
            check = 147,
        },
        [263] = {
            level = 3.5,
            check = 147,
        },
        [264] = {
            level = 5.5,
            check = 147,
        },
        [265] = {
            level = 3.5,
            check = 148,
        },
        [266] = {
            check = 202,
            pre_render = function(ent,offset1,offset2,info)
                local s = ent:GetSprite() local d = ent:GetData() d[own_key.."replace_sprite"] = d[own_key.."replace_sprite"] or Sprite()
                local s2 = auxi.copy_sprite(s,d[own_key.."replace_sprite"],{filename = "gfx/"..info.name..".anm2",})
                --s2.Rotation = 0
                local offset_adder = s2.Offset
                --s2.Offset = Vector(0,0)
                --s2:Render(offset2 + offset_adder)
                s2:Render(offset2)
            end,
            on_search = function(info,v1,v2,v3)
                if v1 == info.type and v2 == info.variant then return true end
            end,
            on_anim = function(animinfo,ent,info)
            end,
            real_tg_layer = {0,1,2,3,4,},
        },
        [267] = {
            level = 2.5,
            check = 57,
        },
        [268] = {
            check = 267,
        },
        [269] = {
            check = 267,
        },
        [270] = {
            check = 267,
        },
        [271] = {       --!!需要修复
            level = 3.5,
            NotSpawn = true,
            DontSpawn = true,
        },
        [272] = {
            level = 1.5,
            order = -0.75,
        },
        [273] = {
            --underwater = true,      --!!需要检查
            level = 1.5,
            check = 1,
            --set_color = true,     --无效
            Replace_with_sprite = true,
        },
        [274] = {
            level = 1.5,
            --check = 7,
            --need_multi = {1,2,3,},
            CoverDetail = {
                [0] = {
                    [7] = {
                        st = 6,
                        ed = 20,
                    },
                    [9] = {
                        st = 6,
                        ed = 20,
                    },
                },
            },
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim == "UnderwaterAttack" and (fr <= 3 or fr >= 33) then return false end
                if anim == "UnderwaterSpawn" and (fr <= 3) then return false end
                if anim == "UnderwaterDive" and (fr >= 7) then return false end
                return true
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                if anim:sub(1,10) == "Underwater" then return -2 end
                return 1.5
            end,
            pre_render = function(ent,offset1,offset2,info)
                local s = ent:GetSprite() local d = ent:GetData() d[own_key.."replace_sprite"] = d[own_key.."replace_sprite"] or Sprite()
                local s2 = auxi.copy_sprite(s,d[own_key.."replace_sprite"],{filename = "gfx/"..info.name..".anm2",on_replace = function(ts,es,params)
                    ts:ReplaceSpritesheet(0,"gfx/SE_shadow.png") ts:LoadGraphics()
                end,})
                s2:Render(offset2)
            end,
        },
        [275] = {
            level = 2.5,
            KeepTarget = true,
            order = -2,
            NoKill = true,
            init = function(ent)
                local pos = auxi.Vector2Table(ent.Position)
                ent.Position = Vector(0,0) ent:Update()
                local tgs = auxi.getothers(nil,5,41,0)
                for u,v in pairs(tgs) do if auxi.check_for_the_same(v.SpawnerEntity,ent) then v:Remove() end end
                ent.TargetPosition = auxi.ProtectVector(pos)
                ent.Position = auxi.ProtectVector(pos)
            end,
            stone = true,
            --check = 57,       --糟糕的bug
        },
        [276] = {
            level = 1.5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(1,3) == "Hop" then return -0.75 end
                return -0.25
            end,
            Replace_with_sprite = true,
        },
        [277] = {
            level = 1.5,
            check = 1,
            DontSpawn = true,       --!!糟糕！它不会因为其他敌人都消失而出现，需要修复
            NotSpawn = true,
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if ent.State == 3 then return false end
                return true
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                return -0.5
            end,
            HideAll = true,
        },
        [278] = {
            check = 277,
        },
        [279] = {
            check = 277,
        },
        [280] = {
            check = 277,
        },
        [281] = {
            check = 277,
        },
        [282] = {
            check = 277,
        },
        [283] = {
            check = 277,
        },
        [284] = {
            level = 1.5,
            order = -0.75,
            on_damage = function(ent,amt,flag,source,cooldown,tent)
                tent:TakeDamage(0.1,0,EntityRef(tent),666)
            end,
        },
        [285] = {
            level = 5.5,
            check = 284,
        },
        [286] = {
            level = 1.5,
            order = function(ent,info)
                if ent.State == 16 then return -0.25 end
            end,
            check = 1,
            rnds = 0.5,
        },
        [287] = {
            level = 1.5,
            order = function(ent,info)
                if Game():GetRoom():HasWater() then return 0.2 end
                return -0.5
            end,
        },
        [288] = {
            level = 1.5,
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if ent.State == 16 then return false end
                if anim == "PotAppear" and fr <= 15 then return false end
                return true
            end,
            Force_Spawn_Info = function(ent,es)
                if es.Type == 5 then return true end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                return 0
            end,
            HideAll = true,
            real_tg_layer = {0,1,},
            special_on_invisible = function(ent,offset,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false and (anim ~= "Idle") then
                    local s2 = auxi.copy_sprite(s,nil,{filename = "gfx/"..info.name..".anm2",SetScale = true,SetOffset = true,SetRotation = true,})
                    --s2:ReplaceSpritesheet(5,"gfx/SE_shadow.png") s2:LoadGraphics()
                    s2:Render(offset)
                end
            end,
            --Replace_with_sprite = true,
            HelpVelocity = true,
        },
        [289] = {
            level = 3.5,
            check = 288,
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if ent.State == 16 then return false end
                if anim == "SpecialAppear" and fr <= 5 then return false end
                return true
            end,
            init = function(ent)
                ent.State = 3
                ent:GetSprite():Play("Idle",true)
            end,
        },
        [290] = {
            level = 1.5,
            check = 13,
        },
        [291] = {
            check = 290,
        },
        [292] = {
            level = 2.5,
            check = 81,
            set_anm2 = {0,},
            protect_self = true,
            check_all_type = true,
            --Replace_with_sprite = true,
        },
        [293] = {
            check = 292,
        },
        [294] = {
            check = 292,
        },
        [295] = {
            check = 292,
        },
        [296] = {
            check = 292,
        },
        [297] = {
            check = 292,
        },
        [298] = {
            check = 292,
        },
        [299] = {
            check = 292,
        },
        [300] = {
            check = 292,
        },
        [301] = {
            check = 292,
        },
        [302] = {
            check = 292,
        },
        [303] = {
            check = 292,
        },
        [304] = {
            level = 2.5,
            order = -0.25,      --!!不会碰撞后爆炸，是否要保留这个性质呢？
        },
        [305] = {
            level = 3.5,
            check = 304,
            NotSpawn = true,
        },
        [306] = {
            level = 2.5,
        },
        [307] = {
            check = 306,
        },
        [308] = {
            check = 306,
        },
        [309] = {
            level = 2.5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if ent.State == 16 then return 0.25 end
                return -0.25
            end,
            real_tg_layer = function(s,isoverlay)
                local anim = s:GetAnimation() if isoverlay then anim = s:GetOverlayAnimation() end
                if anim:sub(1,4) == "Head" then return {1,} end
            end,
        },
        [310] = {
            level = 2.5,
            check = 107,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,4) == "Jump" then return 9 end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Jump" then return 0.5 end
            end,
        },
        [311] = {
            level = 2.5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if ent.State == 8 then return 0.25 end
                return -0.25
            end,
        },
        [312] = {
            check = 311,
        },
        [313] = {
            --!! 和水雷头一样的bug
            NotSpawn = true,
            --DontSpawn = true,
            level = 2.5,
            check = 151,
            order = 666,
        },
        [314] = {
            level = 2.5,
            check = 125,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(1,6) == "Attack" and fr >= 35 then return 0.25 end
                if anim:sub(1,5) == "Slide" then return 0.5 end
                return -2
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(1,5) == "Slide" and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 16
                local anim = "Hit1"
                --if ent.I2 >= 1 and ent.I2 <= 3 then anim = "Hit"..tostring(ent.I2) end
                ent:GetSprite():Play(anim,true)
            end,
        },
        [315] = {
            level = 2.5,
            check = 1,
            rnds = 0.6,
        },
        [316] = {
            level = 5.5,
            check = 315,
        },
        [317] = {
            level = 2.5,
            order = -2,
            --!! render_back
        },
        [318] = {
            level = 2.5,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,4) == "Jump" then return 9 end
            end,
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim == "Appear" then return false end
                if anim:sub(1,6) == "DigOut" and fr <= 5 then return false end
                if anim:sub(1,4) == "Jump" and fr >= 22 then return false end
                return true
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                return -0.5
            end,
            KeepTarget = true,
            protect_pos = true,
        },
        [319] = {
            level = 5.5,
            check = 318,
        },
        [320] = {
            level = 2.5,
            rnds = 0.3,
        },
        [321] = {
            level = 4.5,
            rnds = 0.3,
            real_tg_layer = {0,1,2,},
        },
        [322] = {
            level = 4.5,
            rnds = 0.3,
            strength = 20,
        },
        [323] = {
            level = 3.5,
            rnds = 0.3,
        },
        [324] = {
            level = 3.5,
            rnds = 0.3,
            protect_self = true,
            check_all_type = true,
        },
        [325] = {
            level = 3.5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Attack" then return -2 end
                return -0.5
            end,
        },
        [326] = {
            level = 3.5,
            Replace_with_sprite = true,
            order = 0,
            pre_render = function(ent,offset1,offset2,info)
                local s = ent:GetSprite() local d = ent:GetData() d[own_key.."replace_sprite"] = d[own_key.."replace_sprite"] or Sprite()
                local s2 = auxi.copy_sprite(s,d[own_key.."replace_sprite"],{filename = "gfx/"..info.name..".anm2",on_replace = function(ts,es,params)
                    ts:ReplaceSpritesheet(0,"gfx/SE_shadow.png") ts:ReplaceSpritesheet(1,"gfx/SE_shadow.png") ts:LoadGraphics()
                end,})
                s2:Render(offset2)
            end,
            special_on_replace_with = function(_s,info,offset,ent)
                local s = ent:GetSprite() local d = ent:GetData() d[own_key.."replace_sprite"] = d[own_key.."replace_sprite"] or Sprite()
                local s2 = auxi.copy_sprite(s,d[own_key.."replace_sprite"],{on_replace = function(ts,es,params)
                    ts:ReplaceSpritesheet(2,"gfx/SE_shadow.png") ts:LoadGraphics()
                end,})
                s2:Render(offset)
            end,
        },
        [327] = {
            check = 326,
        },
        [328] = {
            check = 326,
        },
        [329] = {
            level = 4.5,
            rnds = 0.3,
        },
        [330] = {
            level = 3.5,
            real_tg_layer = {0,1,},
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Attack" then return -2 end
                return -1
            end,
            rnds = 0.3,
        },
        [331] = {
            level = 1.5,
            NotSpawn = true,
            strength = 0.1,
            order = -2,
            KeepTarget = true,
        },
        [332] = {
            --!!它会绕着自己转！
            --check = 274,
            level = 1.5,
            NotSelf = true,
            order = -20,
            pre_render = function(ent,offset1,offset2,info)
                local s = ent:GetSprite() local d = ent:GetData() d[own_key.."replace_sprite"] = d[own_key.."replace_sprite"] or Sprite()
                local s2 = auxi.copy_sprite(s,d[own_key.."replace_sprite"],{filename = "gfx/"..info.name..".anm2",on_replace = function(ts,es,params)
                    ts:ReplaceSpritesheet(0,"gfx/SE_shadow.png") ts:LoadGraphics()
                end,})
                s2:Render(offset2)
            end,
            KeepTarget = true,
        },
        [333] = {
            level = 3.5,
            strength = 30,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Hop" then return 0.5 end
                return -1
            end,
        },
        [334] = {
            level = 3.5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetOverlayAnimation()
                if anim:sub(1,6) == "Attack" then return -2 end
                return -1
            end,
            rnds = 0.3,
            Replace_with_sprite = true,
        },
        [335] = {
            check = 334,
        },
        [336] = {
            level = 2.5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,6) == "Attack" then return -2 end
                return -1
            end,
            rnds = 0.3,
        },
        [337] = {
            level = 4.5,
            Replace_with_sprite = true,
            protect_self = true,
            check_all_type = true,
        },
        [338] = {
            level = 4.5,
            order = -2,
        },
        [339] = {
            level = 4.5,
            strength = 30,
            order = -0.5,
            rnds = 1.2,
        },
        [340] = {
            level = 4.5,
            KeepTarget = function(ent)
                local anim = ent:GetSprite():GetAnimation()
                if (anim == "Jump") and ent.TargetPosition:Length() > 10 then return true end
            end,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,4) == "Jump" then return 9 end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Jump" then return 0.5 end
                return -0.5
            end,
        },
        [341] = {
            level = 4.5,
            order = -0.75,
            NoKill = true,
            NotSpawn = true,
            stone = true,
        },
        [342] = {
            --!! 特殊的敌人
            level = 4.5,
            strength = 1,
            order = -2,
            can_multi = true,
        },
        [343] = {
            level = 4.5,
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim == "Burrow" and fr >= 22 then return false end
                if anim == "ChargeDown" and fr <= 12 then return false end
                return true
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                if anim:sub(1,6) == "Charge" then return 1.5 end
                return -0.25
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if ent.State == 8 and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 3
                --ent:GetSprite():Play("ChargeHit",true)
            end,
        },
        [344] = {
            level = 5.5,
            check = 20,
            protect_flip = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,6) == "Attack" then return true end
            end,
        },
        [345] = {
            check = 344,
        },
        [346] = {
            level = 4.5,
            order = -2,
            KeepTarget = true,
        },
        [347] = {
            level = 4.5,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,4) == "Jump" then return 9 end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Jump" then return 0.5 end
                if anim:sub(1,6) == "Attack" then return -2 end
                return -0.5
            end,
        },
        [348] = {
            level = 4,
            check = 33,
            order = -0.5,
        },
        [349] = {
            level = 4.5,
            set_visible = function(ent)
                local anim = ent:GetSprite():GetAnimation() local fr = ent:GetSprite():GetFrame()
                if anim == "Teleport" and fr >= 6 then return false end
                if anim == "TeleportEnd" and fr <= 2 then return false end
                return true
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                return -0.25
            end,
        },
        [350] = {
            level = 4.5,
            check = 37,
        },
        [351] = {
            level = 4.5,
            check = 53,
        },
        [352] = {
            level = 3.5,
            --Replace_with_sprite = true,
            set_anm2 = {0,1,},
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Move" or anim == "Wake" then return 0.25 end
                return -2
            end,
        },
        [353] = {
            check = 352,
        },
        [354] = {
            check = 352,
        },
        [355] = {
            level = 3.5,
            real_tg_layer = {3,1,},
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Idle" or anim == "Open" or anim == "Close" then return 0.25 end
                return -2
            end,
            KeepTarget = true,
        },
        [356] = {
            level = 4.5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,6) == "Attack" then return -2 end
                return -1
            end,
            rnds = 0.3,
            real_tg_layer = {1,0,},
        },
        [357] = {
            NotSelf = true,
            need_multi = {2,3,4,},
            --can_multi = true,
            NoMulti = true,
            order = function(ent) if ent.ParentNPC then return 0.5 else return -0.5 end end,
            check = 16,
        },
        [358] = {
            KeepTarget = function(ent)
                local anim = ent:GetSprite():GetAnimation()
                if (anim == "Jump" or anim == "Walk") and ent.TargetPosition:Length() > 10 then return true end
                --if anim == "Jump" or anim == "Walk" then return true end
            end,
            swap_weight = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,4) == "Jump" then return 9 end
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim == "Jump" then return 0.5 end
                if anim == "Walk" then return -0.75 end
                return -2
            end,
            rnds = 1,
        },
        [359] = {
            level = 1.5,
            check = 120,
        },
        [360] = {
            level = 1.5,
            check = 125,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Attack01" and fr >= 35 then return 0 end
                if anim == "Attack02" and fr >= 8 then return 0 end
                if anim == "Slide" then return 0 end
                return -2
            end,
        },
        [361] = {
            level = 1.5,
            check = 10,
        },
        [362] = {
            --!!这个生成时自带苍蝇
            level = 1.5,
            rnds = 0.3,
        },
        [363] = {
            level = 1.5,
            check = 13,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetOverlayAnimation()
                if anim == "HeadAttack" then return 0 end
                return -1
            end,
        },
        [364] = {
            level = 1.5,
            check = 120,
        },
        [365] = {
            --!!非常神秘的实现方式
            level = 1.5,
            no_overlay = true,
            on_anim = function(animinfo,ent,info)
                local s = ent:GetSprite() local anim = s:GetOverlayAnimation() local fr = s:GetOverlayFrame()
                if anim:sub(-7,-1) == "Overlay" then
                    local ainfo = info.anm2_data.Animations[anim].NullAnimations[1].Frames
                    local alerpedinfo = auxi.check_lerp(fr,ainfo,{banlist = {["CombinationID"] = true,["Interpolated"] = true,["Visible"] = true,},shouldlerp = function(v1,v2) if v1.Interpolated == true then return true else return false end end,})
                    local ret = {
                        XPosition = alerpedinfo.XPosition + animinfo.XPosition,
                        YPosition = alerpedinfo.YPosition + animinfo.YPosition,
                        XScale = alerpedinfo.XScale/100 * animinfo.XScale,
                        YScale = alerpedinfo.YScale/100 * animinfo.YScale,
                        Rotation = animinfo.Rotation,
                        CombinationID = animinfo.CombinationID,
                        frame = animinfo.frame,
                        Visible = animinfo.Visible,
                        Interpolated = animinfo.Interpolated,
                    }
                    return ret
                end
            end,
            on_damage = function(ent,amt,flag,source,cooldown,tent)
                tent:TakeDamage(0.1,flag,source,666)
            end,
        },
        [366] = {
            level = 1.5,
            should_release = true,
            rnds = 0.3,
        },
        [367] = {
            level = 1.5,
            strength = 30,
            order = -0.5,
            rnds = 0.5,
        },
        [368] = {
            level = 3.5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetOverlayAnimation()
                if ent.State == 8 then return 1 end
                return -2
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData() local s = ent:GetSprite() local anim = s:GetAnimation()
                if ent.State == 8 and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 60 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 4
            end,
            NoKill = true,
            KeepTarget = true,
            stone = true,
            HitPoints = 60,
        },
        [369] = {
            level = 3,
            check = 87,
        },
        [370] = {
            level = 1.5,
            rnds = 0.3,
        },
        [371] = {
            level = 2.5,
            order = -0.5,
            KeepTarget = true,
            on_overlayanim = function(animinfo,ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                local ainfo = info.anm2_data.Animations[anim].NullAnimations[1].Frames
                local alerpedinfo = auxi.check_lerp(fr,ainfo,{banlist = {["CombinationID"] = true,["Interpolated"] = true,["Visible"] = true,},shouldlerp = function(v1,v2) if v1.Interpolated == true then return true else return false end end,})
                local ret = {
                    XPosition = alerpedinfo.XPosition + animinfo.XPosition,
                    YPosition = alerpedinfo.YPosition + animinfo.YPosition,
                    XScale = alerpedinfo.XScale/100 * animinfo.XScale,
                    YScale = alerpedinfo.YScale/100 * animinfo.YScale,
                    Rotation = animinfo.Rotation,
                    CombinationID = animinfo.CombinationID,
                    frame = animinfo.frame,
                    Visible = animinfo.Visible,
                    Interpolated = animinfo.Interpolated,
                }
                return ret
            end,
        },
        [372] = {
            --!! 小pin，好像也很难修
            --NotSpawn = true,
            --DontSpawn = true,
            level = 2,
            anm2_name = "881.000_needle_replace",
            set_anm2 = {0,1,2,3,},
            --Replace_with_sprite = true,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if ent.State == 3 and (anim == "Idle" or anim == "IdleBack") then return false end
                if anim == "DigOut" and fr <= 4 then return false end
                return true
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                if anim == "DigOut" then return -2 end
                return 1
            end,
            HideAll = true,
            CoverDetail = {
                [0] = {
                    [5] = {
                        st = 13,
                        ed = 25 - 7 + 13,
                    },
                },
            },
        },
        [373] = {
            level = 2.5,
            anm2_name = "881.001_pasty_replace",
            check = 372,
            CoverDetail = {
                [0] = {
                    [5] = {
                        st = 13,
                        ed = 23 - 7 + 13,
                    },
                },
            },
        },
        [374] = {
            level = 2.5,
            HideAll = true,
            special_color = function(ent,c1)
                local c2 = Color(1,1,1,ent.V1.X)
                return auxi.MulColor2(c1,c2)
            end,
            set_visible = function(ent)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Poof" and fr >= 6 then return false end
                if ent.V1.X <= 0.1 then return false end
                return true
            end,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if info.set_visible(ent) == false then return 5 end
                return 0
            end,
        },
        [375] = {
            level = 3.5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation()
                if anim:sub(1,5) == "Chase" then return 0.5 end
                if anim:sub(1,6) == "Attack" then return -2 end
            end,
        },
        [376] = {
            need_multi = {2,3,4,},
            NoMulti = true,
            --can_multi = true,
            --KeepTarget = true,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(1,3) == "Hop" then return 0 end
            end,
        },
        [377] = {
            level = 3.5,
            rnds = 0.3,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Attack" or anim == "Respawn" then return -2 end
            end,
            KeepTarget = true,
        },
        [378] = {
            check = 377,
        },
        [379] = {
            --!! 连接带需要重绘
            level = 3.5,
            can_multi = true,       --!!是否是呢
            --need_multi = {},
            no_overlay = true,
            Catch_Laser = true,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(1,4) == "Rage" then return -0.25 end
            end,
            rnds = 0.3,
        },
        [380] = {
            level = 3.5,
            strength = 30,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(1,4) == "Rage" then return 0 end
                return -0.75
            end,
            rnds = 0.5,
        },
        [381] = {
            level = 2.5,
            kill_self = true,
            NoKill = true,
            can_multi = true,
            --stone = true,
        },
        [382] = {
            level = 5,
            rnds = 0.3,
        },
        [383] = {
            level = 2.5,
            protect_self = true,
            protect_time = 3,
            --NoKill = true,
            order = function(ent,info)
                if ent.SubType == 1 then return -2 else return 0 end
            end,
            --!!需要设计复活内容
            KeepTarget = function(ent)
                if ent.SubType == 1 then return true end
            end,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                local s = tent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim == "Collapse" then return false end
            end,
        },
        [384] = {
            level = 3.5,
            check = 1,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(1,6) == "Attack" then return -2 end
            end,
        },
        [385] = {
            check = 384,
        },
        [386] = {
            level = 3.5,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(1,6) == "Attack" then return -2 end
                if anim:sub(1,4) == "Dash" then return 0.25 end
            end,
            special = function(ent,ment,is_main,info)
                local d = ent:GetData()
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(1,4) == "Dash" and not is_main then
                    d[own_key.."skip_dash"] = (d[own_key.."skip_dash"] or 0) + 1
                    if d[own_key.."skip_dash"] > 90 then info.force_move(ent) end
                else d[own_key.."skip_dash"] = nil end
            end,
            force_move = function(ent)
                ent.State = 8       --!!
                ent:GetSprite():Play("AttackHori",true)
            end,
        },
        [387] = {
            check = 386,
            Catch_Laser = true,
            force_move = function(ent)
                ent.State = 8       --!!
                ent:GetSprite():Play("Attack2",true)
            end,
        },
        [388] = {
            level = 3.5,
            rnds = 0.3,
            order = function(ent,info)
                local s = ent:GetSprite() local anim = s:GetAnimation() local fr = s:GetFrame()
                if anim:sub(-1,-1) == "4" then return -0.25
                else return -0.75 end
            end,
            kill_self = true,
            special_damage = function(ent,amt,flag,source,cooldown,tent)
                local anim = tent:GetSprite():GetAnimation()
                if anim:sub(-1,-1) == "4" then
                else tent:TakeDamage(amt,0,source,666) return false end
            end,
            on_damage = function(ent,amt,flag,source,cooldown,tent)
                tent:TakeDamage(0.1,0,source,666)
            end,
        },
        [389] = {
            level = 3.5,
            strength = 30,
            no_overlay = true,
            NotSpawn = true,
            DontSpawn = true,
            on_search = function(info,v1,v2,v3)
                if v1 == info.type and v2 == info.variant then return true end
            end,
            NoKill = true,
            NoOverlayonKill = true,
            --!!        好像有bug。需要检查
        },
        [390] = {
            level = 3.5,
            strength = 10,
            order = -0.75,
            rnds = 0.3,
            need_multi = {1,2,3,},
        },
        [391] = {
            level = 3.5,
            strength = 5,
            KeepTarget = true,
            order = -2,
            NoKill = true,
        },
        [392] = {
            level = 4.5,
            strength = 10,
            order = -1,
        },
        [393] = {
            level = 3.5,
            strength = 5,
            order = -2,
            rnds = 0.3,
            NoKill = true,
        },
        [394] = {
            --need_multi = {},
            level = 5,
            order = 1,
            kill_self = true,
        },
        [395] = {
            level = 5.5,
            NotSpawn = true,
            DontSpawn = true,
            KeepTarget = true,
        },
        [396] = {
            level = 5.5,
            NotSpawn = true,
            DontSpawn = true,
        },
        [397] = {
            level = 5.5,
            need_multi = {1,2,3,},
        },
        [398] = {
            level = 5.5,
            need_multi = {1,2,3,},
        },
        [399] = {
            level = 5.5,
        },
        [400] = {
            level = 5.5,
            NotSpawn = true,
            order = -0.75,
            kill_self = true,
        },


        [401] = {
            check = 95,
        },
        [402] = {
            check = 95,
        },
        [403] = {
            check = 95,
        },
        [404] = {
            check = 100,
        },
        [405] = {
            check = 100,
        },
        [406] = {
            check = 100,
        },
        [407] = {
            check = 381,
        },
        [408] = {
            check = 336,
        },
        [409] = {
            check = 341,
        },
        [410] = {
            check = 341,
        },
        [411] = {
            check = 341,
        },
        [412] = {
            order = -2,
            DontLoad = true,
            DontSpawn = true,
            NotSpawn = true,
            Killnow = true,
            on_search = function(ent)
                if ent.Type == 963 then return true end
            end,
        },
    },
}
do
    local m50 = item[1] and item[1][50]
    if m50 and type(m50.set_offset) == "function" then
        _G.MIX50_apply_offset_hist = function(e)
            return m50.set_offset(0, e)
        end
    end
end
return item

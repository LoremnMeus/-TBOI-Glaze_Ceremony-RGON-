local item = {
    scaler = 10,
    posscaler = 2,
    hit_info = {
        SpinUp = {
            -- 第0帧 (Layer0 delay=2)
            {x1 = 18, y1 = 18, x2 = 18, y2 = 18, 
             rot1 = 45, rot2 = 67,
             scaleX1 = 450, scaleY1 = 100, scaleX2 = 450, scaleY2 = 100},
            
            {x1 = 18, y1 = 18, x2 = 18, y2 = 18, 
             rot1 = 45, rot2 = 67,
             scaleX1 = 450, scaleY1 = 100, scaleX2 = 450, scaleY2 = 100},
            
            -- 第1帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = 0, y1 = 24, x2 = 9, y2 = 22,
             rot1 = 90, rot2 = 67,
             scaleX1 = 450, scaleY1 = 300, scaleX2 = 450, scaleY2 = 100},
            
            -- 第2帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = -18, y1 = 18, x2 = -10, y2 = 23,
             rot1 = 135, rot2 = 112,
             scaleX1 = 450, scaleY1 = 400, scaleX2 = 450, scaleY2 = 300},
            
            -- 第3帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = -24, y1 = 0, x2 = -23, y2 = 10,
             rot1 = 180, rot2 = 157,
             scaleX1 = 450, scaleY1 = 400, scaleX2 = 450, scaleY2 = 400},
            
            -- 第4帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = -18, y1 = -18, x2 = -24, y2 = -10,
             rot1 = 225, rot2 = 202,
             scaleX1 = 450, scaleY1 = 400, scaleX2 = 450, scaleY2 = 400},
            
            -- 第5帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = 0, y1 = -24, x2 = -10, y2 = -21,
             rot1 = 270, rot2 = 247,
             scaleX1 = 450, scaleY1 = 400, scaleX2 = 450, scaleY2 = 400},
            
            -- 第6帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = 18, y1 = -18, x2 = 10, y2 = -23,
             rot1 = 315, rot2 = 292,
             scaleX1 = 450, scaleY1 = 400, scaleX2 = 450, scaleY2 = 400},
            
            -- 第7帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = 24, y1 = 0, x2 = 23, y2 = -11,
             rot1 = 0, rot2 = -23,
             scaleX1 = 450, scaleY1 = 400, scaleX2 = 450, scaleY2 = 400},
            
            -- 第8帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = 18, y1 = 18, x2 = 23, y2 = 9,
             rot1 = 45, rot2 = 22,
             scaleX1 = 450, scaleY1 = 300, scaleX2 = 450, scaleY2 = 400},
            
            -- 第9帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = 0, y1 = 24, x2 = 11, y2 = 21,
             rot1 = 90, rot2 = 67,
             scaleX1 = 450, scaleY1 = 100, scaleX2 = 450, scaleY2 = 300},
            
            -- 第10帧 (Layer1 delay=1)
            {x1 = nil, y1 = nil, x2 = 0, y2 = 24,
             rot1 = nil, rot2 = 112,
             scaleX1 = nil, scaleY1 = nil, scaleX2 = 450, scaleY2 = 100}
        },
        AttackUp = {
            -- 第0帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = 24, y1 = 0, x2 = 24, y2 = 0,
             rot1 = 0, rot2 = 0,
             scaleX1 = 450, scaleY1 = 100, scaleX2 = 450, scaleY2 = 100},
            
            -- 第1帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = 18, y1 = 18, x2 = 21, y2 = 11,
             rot1 = 45, rot2 = 22,
             scaleX1 = 450, scaleY1 = 300, scaleX2 = 450, scaleY2 = 300},
            
            -- 第2帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = 0, y1 = 24, x2 = 11, y2 = 21,
             rot1 = 90, rot2 = 67,
             scaleX1 = 450, scaleY1 = 400, scaleX2 = 450, scaleY2 = 300},
            
            -- 第3帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = -18, y1 = 18, x2 = -10, y2 = 24,
             rot1 = 135, rot2 = 112,
             scaleX1 = 450, scaleY1 = 300, scaleX2 = 450, scaleY2 = 400},
            
            -- 第4帧 (Layer0 delay=2, Layer1 delay=1)
            {x1 = -24, y1 = 0, x2 = -21, y2 = 11,
             rot1 = 180, rot2 = 157,
             scaleX1 = 450, scaleY1 = 100, scaleX2 = 450, scaleY2 = 300},
            
            -- 第5帧 (Layer0 delay=1, Layer1 delay=1)
            {x1 = -24, y1 = 0, x2 = -24, y2 = 0,
             rot1 = 180, rot2 = 180,
             scaleX1 = 450, scaleY1 = 100, scaleX2 = 450, scaleY2 = 100}
        },
    },
}
--l local item = require("Qing_Remaster_scripts.bosses.Boss_Qing_knife") item.scaler = 20

function item.get_hitbox(ent,currentFrame)
    local hitboxes = {}
    local sprite = ent:GetSprite()
    local currentAnim = sprite:GetAnimation()
    local currentFrame = currentFrame or sprite:GetFrame()
    
    -- 根据当前动画获取对应的Hit层信息
    if item.hit_info[currentAnim] then
        hitboxes = item.hit_info[currentAnim]
    end
    
    -- 返回当前帧的碰撞箱信息
    return hitboxes[currentFrame + 1] or {}
end

function item.get_collision_boxes(ent,scaler,posscaler,hitbox,collision_boxes)
    posscaler = posscaler or item.posscaler
    scaler = scaler or item.scaler
    hitbox = hitbox or item.get_hitbox(ent)
    if not hitbox.x1 then return nil end  -- 如果当前帧没有碰撞箱
    
    local pos = ent.Position
    local sprite = ent:GetSprite()
    local rot = sprite.Rotation  -- 角度制
    local scale = sprite.Scale
    local flipX = sprite.FlipX and -1 or 1
    local flipY = sprite.FlipY and -1 or 1
    collision_boxes = collision_boxes or {}
    
    -- 将百分制scale转换为实际比例
    local scaleFactorX = scale.X 
    local scaleFactorY = scale.Y 
    
    -- 将角度转换为弧度
    local radRot = math.rad(rot)
    local cosRot = math.cos(radRot)
    local sinRot = math.sin(radRot)
    
    -- 计算第一个层的碰撞箱
    if hitbox.x1 then
        -- 计算未旋转前的相对位置
        local relX = hitbox.x1 * scaleFactorX * flipX * posscaler
        local relY = hitbox.y1 * scaleFactorY * flipY * posscaler
        
        -- 应用旋转
        local rotatedX = relX * cosRot - relY * sinRot
        local rotatedY = relX * sinRot + relY * cosRot
        
        local box1 = {
            center = Vector(
                pos.X + rotatedX,
                pos.Y + rotatedY
            ),
            rotation = (flipX == -1 and (180 - hitbox.rot1) or hitbox.rot1) * flipY + rot,
            scaleX = (hitbox.scaleX1 or 100) / 100 * scaleFactorX * math.abs(flipX) * scaler,
            scaleY = (hitbox.scaleY1 or 100) / 100 * scaleFactorY * math.abs(flipY) * scaler
        }
        table.insert(collision_boxes, box1)
    end
    
    -- 计算第二个层的碰撞箱
    if hitbox.x2 then
        -- 计算未旋转前的相对位置
        local relX = hitbox.x2 * scaleFactorX * flipX * posscaler
        local relY = hitbox.y2 * scaleFactorY * flipY * posscaler
        
        -- 应用旋转
        local rotatedX = relX * cosRot - relY * sinRot
        local rotatedY = relX * sinRot + relY * cosRot
        
        local box2 = {
            center = Vector(
                pos.X + rotatedX,
                pos.Y + rotatedY
            ),
            rotation = (flipX == -1 and (180 - hitbox.rot2) or hitbox.rot2) * flipY + rot,
            scaleX = (hitbox.scaleX2 or 100) / 100 * scaleFactorX * math.abs(flipX) * scaler,
            scaleY = (hitbox.scaleY2 or 100) / 100 * scaleFactorY * math.abs(flipY) * scaler
        }
        table.insert(collision_boxes, box2)
    end
    
    return collision_boxes
end

function item.get_collision_boxes_with_a_delay_frame(ent,scaler,posscaler)
    collision_boxes = item.get_collision_boxes(ent,scaler,posscaler)
    collision_boxes = item.get_collision_boxes(ent,scaler,posscaler,item.get_hitbox(ent,ent:GetSprite():GetFrame() - 1),collision_boxes)
    return collision_boxes
end

return item
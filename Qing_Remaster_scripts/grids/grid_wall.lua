local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	ShapeToName = {
		[RoomShape.ROOMSHAPE_IV] = "IV",
		[RoomShape.ROOMSHAPE_1x2] = "1x2",
		[RoomShape.ROOMSHAPE_2x2] = "2x2",
		[RoomShape.ROOMSHAPE_IH] = "IH",
		[RoomShape.ROOMSHAPE_LTR] = "LTR",
		[RoomShape.ROOMSHAPE_LTL] = "LTL",
		[RoomShape.ROOMSHAPE_2x1] = "2x1",
		[RoomShape.ROOMSHAPE_1x1] = "1x1",
		[RoomShape.ROOMSHAPE_LBL] = "LBL",
		[RoomShape.ROOMSHAPE_LBR] = "LBR",
		[RoomShape.ROOMSHAPE_IIH] = "IIH",
		[RoomShape.ROOMSHAPE_IIV] = "IIV"
	},
	ShapeToWallAnm2Layers = {
		["1x2"] = 58,
		["2x2"] = 63,
		["2x2X"] = 21,
		["IIH"] = 62,
		["LTR"] = 63,
		["LTRX"] = 19,
		["2x1"] = 63,
		["2x1X"] = 7,
		["1x1"] = 44,
		["LTL"] = 63,
		["LTLX"] = 19,
		["LBR"] = 63,
		["LBRX"] = 19,
		["LBL"] = 63,
		["LBLX"] = 19,
		["IIV"] = 42,
		["IH"] = 36,
		["IV"] = 28
	},
	BackdropRNG = RNG(),
}

--在这里拷贝了一部分stage api的内容，这样就不必选用不能完全掌控的前置mod了。

function item.LoadBackdropSprite(sprite, backdrop, mode) -- modes are 1 (walls A), 2 (floors), 3 (walls B)
    sprite = sprite or Sprite()
    local needsExtra
    local roomShape = Game():GetRoom():GetRoomShape()
    local shapeName = item.ShapeToName[roomShape]
    if item.ShapeToWallAnm2Layers[shapeName .. "X"] then needsExtra = true end
    if mode == 3 then shapeName = shapeName .. "X" end
    if backdrop.PreLoadFunc then
        local ret = backdrop.PreLoadFunc(sprite, backdrop, mode, shapeName)
        if ret then mode = ret end
    end
    if mode == 1 or mode == 3 then
        sprite:Load(backdrop.WallAnm2 or "gfx/stage/WallBackdrop.anm2", false)
        if backdrop.PreWallSheetFunc then
            backdrop.PreWallSheetFunc(sprite, backdrop, mode, shapeName)
        end
        local corners
        local walls
        if backdrop.WallVariants then
            walls = backdrop.WallVariants[auxi.random_on_table(1, #backdrop.WallVariants,item.BackdropRNG)]
            corners = walls.Corners or backdrop.Corners
        else
            walls = backdrop.Walls
            corners = backdrop.Corners
        end
        if walls then
            for num = 1, item.ShapeToWallAnm2Layers[shapeName] do
                local wall_to_use = walls[auxi.random_on_table(1, #walls,item.BackdropRNG)]
                sprite:ReplaceSpritesheet(num, wall_to_use)
            end
        end
        if corners and string.sub(shapeName, 1, 1) == "L" then
            local corner_to_use = corners[auxi.random_on_table(1, #corners,item.BackdropRNG)]
            sprite:ReplaceSpritesheet(0, corner_to_use)
        end
    elseif mode == 2 then
        sprite:Load(backdrop.FloorAnm2 or "gfx/stage/FloorBackdrop.anm2", false)
        if backdrop.PreFloorSheetFunc then backdrop.PreFloorSheetFunc(sprite, backdrop, mode, shapeName) end
        local floors
        if backdrop.FloorVariants then
            floors = backdrop.FloorVariants[auxi.random_on_table(1, #backdrop.FloorVariants,item.BackdropRNG)]
        else
            floors = backdrop.Floors or backdrop.Walls
        end
        if floors then
            local numFloors
            if roomShape == RoomShape.ROOMSHAPE_1x1 then
                numFloors = 4
            elseif roomShape == RoomShape.ROOMSHAPE_1x2 or roomShape == RoomShape.ROOMSHAPE_2x1 then
                numFloors = 8
            elseif roomShape == RoomShape.ROOMSHAPE_2x2 then
                numFloors = 16
            end
            if numFloors then
                for i = 0, numFloors - 1 do
                    sprite:ReplaceSpritesheet(i, floors[auxi.random_on_table(1, #floors,item.BackdropRNG)])
                end
            end
        end
        if backdrop.NFloors and string.sub(shapeName, 1, 1) == "I" then
            for num = 18, 19 do
                sprite:ReplaceSpritesheet(num, backdrop.NFloors[auxi.random_on_table(1, #backdrop.NFloors,item.BackdropRNG)])
            end
        end
        if backdrop.LFloors and string.sub(shapeName, 1, 1) == "L" then
            for num = 16, 17 do
                sprite:ReplaceSpritesheet(num, backdrop.LFloors[auxi.random_on_table(1, #backdrop.LFloors,item.BackdropRNG)])
            end
        end
    end
    sprite:LoadGraphics()
    local renderPos = Game():GetRoom():GetTopLeftPos()
    if mode ~= 2 then
        renderPos = renderPos - Vector(80, 80)
    end
    sprite:Play(shapeName, true)
    return renderPos, needsExtra, sprite
end

function item.ChangeBackdrop(backdrop, justWalls, storeBackdropEnts)
    if type(backdrop) == "number" then		--基础内容
        Game():ShowHallucination(0, backdrop)
        SFXManager():Stop(SoundEffect.SOUND_DEATH_CARD)
        return
    end
	local room = Game():GetRoom()
	item.BackdropRNG:SetSeed(room:GetDecorationSeed(), 1)
    local needsExtra, backdropEnts, renderPos
    if storeBackdropEnts then
        backdropEnts = {}
    end
    for i = 1, 3 do
        if justWalls and i == 2 then i = 3 end
        if i == 3 and not needsExtra then break end
        local backdropEntity = Isaac.Spawn(1000,enums.Entities.BackDropNil, 0,Vector(0,0),Vector(0,0), nil)
        local sprite = backdropEntity:GetSprite()
        renderPos, needsExtra = item.LoadBackdropSprite(sprite, backdrop, i)
        backdropEntity.SpriteOffset = (renderPos / 40) * 26
        if i == 1 or i == 3 then
            backdropEntity:AddEntityFlags(EntityFlag.FLAG_RENDER_WALL)
        else
            backdropEntity:AddEntityFlags(EntityFlag.FLAG_RENDER_FLOOR)
        end
        if storeBackdropEnts then
            backdropEnts[#backdropEnts + 1] = backdropEntity
        end
    end
    return backdropEnts
end

--[[
function item.ChangeStageShadow(prefix, count)
    prefix = prefix or "stageapi/floors/catacombs/overlays/"
    count = count or 5
	local room = Game():GetRoom()
	
    local shadows = Isaac.FindByType(1000,enums.Entities.ShadowNil, -1, false, false)
    for u,v in ipairs(shadows) do v:Remove() end
    local roomShape = room:GetRoomShape()
    local anim
    if roomShape == RoomShape.ROOMSHAPE_1x1 or roomShape == RoomShape.ROOMSHAPE_IH or roomShape == RoomShape.ROOMSHAPE_IV then anim = "1x1"
    elseif roomShape == RoomShape.ROOMSHAPE_1x2 or roomShape == RoomShape.ROOMSHAPE_IIV then anim = "1x2"
    elseif roomShape == RoomShape.ROOMSHAPE_2x1 or roomShape == RoomShape.ROOMSHAPE_IIH then anim = "2x1"
    elseif roomShape == RoomShape.ROOMSHAPE_2x2 or roomShape == RoomShape.ROOMSHAPE_LBL or roomShape == RoomShape.ROOMSHAPE_LBR or roomShape == RoomShape.ROOMSHAPE_LTL or roomShape == RoomShape.ROOMSHAPE_LTR then anim = "2x2"
    end

    if anim then
        --StageAPI.StageShadowRNG:SetSeed(shared.Room:GetDecorationSeed(), 0)
        --local usingShadow = StageAPI.Random(1, count, StageAPI.StageShadowRNG)
        local sheet = prefix .. anim .. "_overlay_" .. tostring(usingShadow) .. ".png"

        local ent = Isaac.Spawn(1000,enums.Entities.ShadowNil, 0,Vector(0,0),Vector(0,0), nil)
		local d = ent:GetData()
        d.Sheet = sheet
		d.Animation = anim
        ent.Position = auxi.Lerp(room:GetTopLeftPos(),room:GetBottomRightPos(), 0.5)
        ent:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE)
    end
end
--]]

function item.ChangeRoomGfx(roomgfx)
    item.BackdropRNG:SetSeed(Game():GetRoom():GetDecorationSeed(), 0)
    if roomgfx.Backdrops then
        if type(roomgfx.Backdrops) ~= "number" and #roomgfx.Backdrops > 0 then
            local backdrop = auxi.random_on_table(1, #roomgfx.Backdrops, item.BackdropRNG)
            item.ChangeBackdrop(roomgfx.Backdrops[backdrop])
        else
            item.ChangeBackdrop(roomgfx.Backdrops)
        end
    end

    if roomgfx.Grids then
        --item.ChangeGrids(roomgfx.Grids)
    end
end

return item
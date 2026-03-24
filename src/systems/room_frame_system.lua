-- Draws a grid-framed room shell and leaves wall slots for side doors.
local RoomFrameSystem = {}

local DEFAULT_CELL = 96
local DEFAULT_WALL_THICKNESS = 18

local function getBounds(roomBounds)
    local bounds = roomBounds or {}
    local minX = math.floor(bounds.minX or 0)
    local minY = math.floor(bounds.minY or 0)
    local maxX = math.floor(bounds.maxX or minX)
    local maxY = math.floor(bounds.maxY or minY)
    return minX, minY, maxX, maxY
end

local function drawInteriorGrid(minX, minY, maxX, maxY, cell)
    local width = math.max(0, maxX - minX)
    local height = math.max(0, maxY - minY)
    if width <= 0 or height <= 0 then
        return
    end

    love.graphics.setColor(0.22, 0.32, 0.50, 0.22)
    for x = minX, maxX, cell do
        love.graphics.line(x, minY, x, maxY)
    end
    for y = minY, maxY, cell do
        love.graphics.line(minX, y, maxX, y)
    end
end

local function overlapsDoorSlot(x, y, w, h, doors)
    local doorData = doors or {}
    local doorList = { doorData.entry, doorData.exit }
    for _, door in ipairs(doorList) do
        if door then
            local dx = (door.x or 0) - 6
            local dy = (door.y or 0) - 6
            local dw = (door.width or 0) + 12
            local dh = (door.height or 0) + 12
            if x < (dx + dw) and (x + w) > dx and y < (dy + dh) and (y + h) > dy then
                return true
            end
        end
    end
    return false
end

local function drawWallBoxes(minX, minY, maxX, maxY, cell, wallThickness, doors)
    local edgeFill = { 0.09, 0.13, 0.22, 0.72 }
    local edgeLine = { 0.38, 0.52, 0.78, 0.72 }

    love.graphics.setColor(edgeFill)
    for x = minX, maxX - wallThickness, cell do
        local boxW = math.min(cell, math.max(wallThickness, maxX - x))
        if not overlapsDoorSlot(x, minY, boxW, wallThickness, doors) then
            love.graphics.rectangle("fill", x, minY, boxW, wallThickness)
        end
        if not overlapsDoorSlot(x, maxY - wallThickness, boxW, wallThickness, doors) then
            love.graphics.rectangle("fill", x, maxY - wallThickness, boxW, wallThickness)
        end
    end
    for y = minY, maxY - wallThickness, cell do
        local boxH = math.min(cell, math.max(wallThickness, maxY - y))
        if not overlapsDoorSlot(minX, y, wallThickness, boxH, doors) then
            love.graphics.rectangle("fill", minX, y, wallThickness, boxH)
        end
        if not overlapsDoorSlot(maxX - wallThickness, y, wallThickness, boxH, doors) then
            love.graphics.rectangle("fill", maxX - wallThickness, y, wallThickness, boxH)
        end
    end

    love.graphics.setColor(edgeLine)
    for x = minX, maxX - wallThickness, cell do
        local boxW = math.min(cell, math.max(wallThickness, maxX - x))
        if not overlapsDoorSlot(x, minY, boxW, wallThickness, doors) then
            love.graphics.rectangle("line", x, minY, boxW, wallThickness)
        end
        if not overlapsDoorSlot(x, maxY - wallThickness, boxW, wallThickness, doors) then
            love.graphics.rectangle("line", x, maxY - wallThickness, boxW, wallThickness)
        end
    end
    for y = minY, maxY - wallThickness, cell do
        local boxH = math.min(cell, math.max(wallThickness, maxY - y))
        if not overlapsDoorSlot(minX, y, wallThickness, boxH, doors) then
            love.graphics.rectangle("line", minX, y, wallThickness, boxH)
        end
        if not overlapsDoorSlot(maxX - wallThickness, y, wallThickness, boxH, doors) then
            love.graphics.rectangle("line", maxX - wallThickness, y, wallThickness, boxH)
        end
    end
end

function RoomFrameSystem.draw(roomBounds, doors, context)
    local minX, minY, maxX, maxY = getBounds(roomBounds)
    local cfg = context or {}
    local cell = math.max(32, math.floor(cfg.roomGridCellSize or DEFAULT_CELL))
    local wallThickness = math.max(10, math.floor(cfg.roomWallThickness or DEFAULT_WALL_THICKNESS))

    drawInteriorGrid(minX, minY, maxX, maxY, cell)
    drawWallBoxes(minX, minY, maxX, maxY, cell, wallThickness, doors)
end

return RoomFrameSystem

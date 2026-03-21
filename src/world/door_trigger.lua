-- Door-trigger helpers for generated room transitions.
local CollisionSystem = require("src/systems/collision_system")

local DoorTrigger = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function DoorTrigger.createFromDoor(door, roomBounds, opts)
    if not door then
        return nil
    end

    local cfg = opts or {}
    local rb = roomBounds or {}
    local depth = math.max(6, math.floor(cfg.depth or 34))
    local pad = math.max(0, math.floor(cfg.pad or 0))
    local minX = rb.minX or 0
    local minY = rb.minY or 0
    local maxX = rb.maxX or math.max(minX, (door.x or 0) + (door.width or 0))
    local maxY = rb.maxY or math.max(minY, (door.y or 0) + (door.height or 0))

    local x = (door.x or 0) - pad
    local y = (door.y or 0) - pad
    local width = (door.width or 0) + (pad * 2)
    local height = (door.height or 0) + (pad * 2)

    if door.edge == "top" then
        y = door.y or 0
        height = depth
    elseif door.edge == "bottom" then
        y = (door.y or 0) + math.max(0, (door.height or 0) - depth)
        height = depth
    elseif door.edge == "left" then
        x = door.x or 0
        width = depth
    elseif door.edge == "right" then
        x = (door.x or 0) + math.max(0, (door.width or 0) - depth)
        width = depth
    end

    x = clamp(x, minX, maxX)
    y = clamp(y, minY, maxY)
    width = math.max(1, math.min(width, maxX - x))
    height = math.max(1, math.min(height, maxY - y))

    return {
        x = x,
        y = y,
        width = width,
        height = height,
        edge = door.edge
    }
end

function DoorTrigger.createFromDoors(doors, roomBounds, opts)
    local data = doors or {}
    return {
        entry = DoorTrigger.createFromDoor(data.entry, roomBounds, opts),
        exit = DoorTrigger.createFromDoor(data.exit, roomBounds, opts)
    }
end

function DoorTrigger.playerTouchesTrigger(trigger, player, playerSize)
    if not trigger or not player then
        return false
    end

    local size = playerSize or 35
    return CollisionSystem.overlaps(
        player.x or 0,
        player.y or 0,
        size,
        size,
        trigger.x or 0,
        trigger.y or 0,
        trigger.width or 0,
        trigger.height or 0
    )
end

return DoorTrigger

-- Handles room-transition door spawning, overlap checks, and rendering.
local CollisionSystem = require("src/systems/collision_system")

local DoorSystem = {}

local door = nil

local function randomInt(minValue, maxValue)
    local rng = (love and love.math and love.math.random) or math.random
    return rng(minValue, maxValue)
end

function DoorSystem.reset()
    door = nil
end

function DoorSystem.isActive()
    return door ~= nil
end

function DoorSystem.spawnRandomDoor(playWidth, playHeight, config)
    local cfg = config or {}
    local w = math.max(0, math.floor(playWidth or 0))
    local h = math.max(0, math.floor(playHeight or 0))
    if w <= 0 or h <= 0 then
        door = nil
        return nil
    end

    local margin = math.max(0, math.floor(cfg.doorEdgeMargin or 8))
    local thickness = math.max(20, math.floor(cfg.doorThickness or 28))
    local horizontalSize = math.max(90, math.floor(w * (cfg.doorWidthFactor or 0.18)))
    local verticalSize = math.max(90, math.floor(h * (cfg.doorHeightFactor or 0.18)))
    local side = randomInt(1, 4)

    local x = 0
    local y = 0
    local width = thickness
    local height = thickness
    local edge = "top"

    if side == 1 then
        -- Top edge.
        edge = "top"
        width = math.min(horizontalSize, math.max(thickness, w - margin * 2))
        height = thickness
        x = randomInt(margin, math.max(margin, w - width - margin))
        y = 0
    elseif side == 2 then
        -- Bottom edge.
        edge = "bottom"
        width = math.min(horizontalSize, math.max(thickness, w - margin * 2))
        height = thickness
        x = randomInt(margin, math.max(margin, w - width - margin))
        y = math.max(0, h - height)
    elseif side == 3 then
        -- Left edge.
        edge = "left"
        width = thickness
        height = math.min(verticalSize, math.max(thickness, h - margin * 2))
        x = 0
        y = randomInt(margin, math.max(margin, h - height - margin))
    else
        -- Right edge.
        edge = "right"
        width = thickness
        height = math.min(verticalSize, math.max(thickness, h - margin * 2))
        x = math.max(0, w - width)
        y = randomInt(margin, math.max(margin, h - height - margin))
    end

    door = {
        x = x,
        y = y,
        width = width,
        height = height,
        edge = edge
    }
    return door
end

function DoorSystem.getDoor()
    return door
end

function DoorSystem.isPlayerOverlapping(player, playerSize)
    if not door or not player then
        return false
    end

    local size = playerSize or 35
    return CollisionSystem.overlaps(
        player.x or 0,
        player.y or 0,
        size,
        size,
        door.x,
        door.y,
        door.width,
        door.height
    )
end

function DoorSystem.tryEnter(player, playerSize)
    if DoorSystem.isPlayerOverlapping(player, playerSize) then
        return true
    end
    return false
end

function DoorSystem.getPrompt(player, playerSize)
    if not door then
        return nil
    end
    if DoorSystem.isPlayerOverlapping(player, playerSize) then
        return "MOVE THROUGH THE DOOR TO ENTER NEXT ROOM"
    end
    return nil
end

function DoorSystem.draw()
    if not door then
        return
    end

    love.graphics.setColor(0.35, 0.95, 0.72, 0.28)
    love.graphics.rectangle("fill", door.x, door.y, door.width, door.height, 5, 5)
    love.graphics.setColor(0.72, 1.0, 0.84, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", door.x, door.y, door.width, door.height, 5, 5)
    love.graphics.setLineWidth(1)
end

return DoorSystem

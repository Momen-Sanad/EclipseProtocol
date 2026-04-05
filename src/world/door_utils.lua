-- Shared door geometry and edge helpers used by runtime and generation systems.
local DoorUtils = {}

local EDGES = { "top", "bottom", "left", "right" }

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function defaultRandomInt(minValue, maxValue)
    local rng = (love and love.math and love.math.random) or math.random
    return rng(minValue, maxValue)
end

function DoorUtils.getEdges()
    return EDGES
end

function DoorUtils.normalizeEdge(edge)
    if edge == "top" or edge == "bottom" or edge == "left" or edge == "right" then
        return edge
    end
    return nil
end

function DoorUtils.oppositeEdge(edge)
    if edge == "top" then
        return "bottom"
    end
    if edge == "bottom" then
        return "top"
    end
    if edge == "left" then
        return "right"
    end
    if edge == "right" then
        return "left"
    end
    return nil
end

function DoorUtils.cloneDoor(door)
    if not door then
        return nil
    end
    return {
        x = door.x,
        y = door.y,
        width = door.width,
        height = door.height,
        edge = door.edge
    }
end

function DoorUtils.sameDoor(a, b)
    if not a or not b then
        return false
    end
    return
        a.edge == b.edge
        and a.x == b.x
        and a.y == b.y
        and a.width == b.width
        and a.height == b.height
end

function DoorUtils.chooseRandomEdge(rng, excluded)
    local randomInt = rng or defaultRandomInt
    local candidates = {}
    for _, edge in ipairs(EDGES) do
        if not (excluded and excluded[edge]) then
            candidates[#candidates + 1] = edge
        end
    end
    if #candidates == 0 then
        return EDGES[randomInt(1, #EDGES)]
    end
    return candidates[randomInt(1, #candidates)]
end

function DoorUtils.buildDoorForEdge(edge, roomWidth, roomHeight, cfg, rng)
    local context = cfg or {}
    local randomInt = rng or defaultRandomInt
    local width = math.max(0, math.floor(roomWidth or 0))
    local height = math.max(0, math.floor(roomHeight or 0))
    if width <= 0 or height <= 0 then
        return nil
    end

    local margin = math.max(0, math.floor(context.doorEdgeMargin or 8))
    local thickness = math.max(20, math.floor(context.doorThickness or 28))
    local horizontalSize = math.max(90, math.floor(width * (context.doorWidthFactor or 0.18)))
    local verticalSize = math.max(90, math.floor(height * (context.doorHeightFactor or 0.18)))
    local side = DoorUtils.normalizeEdge(edge) or DoorUtils.chooseRandomEdge(randomInt, nil)

    local x = 0
    local y = 0
    local doorWidth = thickness
    local doorHeight = thickness

    if side == "top" then
        doorWidth = math.min(horizontalSize, math.max(thickness, width - (margin * 2)))
        doorHeight = thickness
        x = randomInt(margin, math.max(margin, width - doorWidth - margin))
        y = 0
    elseif side == "bottom" then
        doorWidth = math.min(horizontalSize, math.max(thickness, width - (margin * 2)))
        doorHeight = thickness
        x = randomInt(margin, math.max(margin, width - doorWidth - margin))
        y = math.max(0, height - doorHeight)
    elseif side == "left" then
        doorWidth = thickness
        doorHeight = math.min(verticalSize, math.max(thickness, height - (margin * 2)))
        x = 0
        y = randomInt(margin, math.max(margin, height - doorHeight - margin))
    else
        doorWidth = thickness
        doorHeight = math.min(verticalSize, math.max(thickness, height - (margin * 2)))
        x = math.max(0, width - doorWidth)
        y = randomInt(margin, math.max(margin, height - doorHeight - margin))
    end

    return {
        x = x,
        y = y,
        width = doorWidth,
        height = doorHeight,
        edge = side
    }
end

function DoorUtils.clampDoorToSafeBounds(door, roomWidth, roomHeight, cfg)
    if type(door) ~= "table" then
        return nil
    end

    local context = cfg or {}
    local edge = DoorUtils.normalizeEdge(door.edge)
    if not edge then
        return nil
    end

    local width = math.max(1, math.floor(roomWidth or 1))
    local height = math.max(1, math.floor(roomHeight or 1))
    local margin = math.max(0, math.floor(context.doorEdgeMargin or 8))
    local clamped = {
        x = math.floor(door.x or 0),
        y = math.floor(door.y or 0),
        width = math.max(1, math.floor(door.width or 1)),
        height = math.max(1, math.floor(door.height or 1)),
        edge = edge
    }

    if edge == "top" or edge == "bottom" then
        clamped.width = math.min(clamped.width, math.max(1, width - (margin * 2)))
        clamped.height = math.min(clamped.height, math.max(1, height))
        clamped.x = clamp(clamped.x, margin, math.max(margin, width - clamped.width - margin))
        clamped.y = (edge == "top") and 0 or math.max(0, height - clamped.height)
    else
        clamped.width = math.min(clamped.width, math.max(1, width))
        clamped.height = math.min(clamped.height, math.max(1, height - (margin * 2)))
        clamped.y = clamp(clamped.y, margin, math.max(margin, height - clamped.height - margin))
        clamped.x = (edge == "left") and 0 or math.max(0, width - clamped.width)
    end

    return clamped
end

return DoorUtils

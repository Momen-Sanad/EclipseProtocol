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

local function rangesOverlap(aStart, aEnd, bStart, bEnd)
    return aStart < bEnd and bStart < aEnd
end

local function buildEvacZoneRect(roomWidth, roomHeight, cfg)
    local context = cfg or {}
    local zoneWidthFactor = math.max(0.1, math.min(1.0, context.evacuationZoneWidthFactor or 0.5))
    local zoneHeight = math.max(12, math.floor(context.evacuationZoneHeight or 56))
    local zoneTop = math.max(0, math.floor(context.evacuationZoneTop or 0))
    local zoneW = math.max(48, math.floor(roomWidth * zoneWidthFactor))
    local zoneH = math.max(18, zoneHeight)
    local zoneY = math.max(0, math.min(roomHeight - zoneH, zoneTop))
    local zoneX = math.floor((roomWidth - zoneW) * 0.5)

    return {
        x = zoneX,
        y = zoneY,
        width = zoneW,
        height = zoneH
    }
end

local function chooseCoordinateOutsideBlocked(minPos, maxPos, doorSize, blockStart, blockEnd, randomInt)
    local intervals = {}
    local leftMax = math.min(maxPos, math.floor(blockStart - doorSize))
    if leftMax >= minPos then
        intervals[#intervals + 1] = { min = minPos, max = leftMax }
    end

    local rightMin = math.max(minPos, math.ceil(blockEnd))
    if rightMin <= maxPos then
        intervals[#intervals + 1] = { min = rightMin, max = maxPos }
    end

    if #intervals == 0 then
        return nil
    end

    if #intervals == 1 then
        return randomInt(intervals[1].min, intervals[1].max)
    end

    local totalSlots = 0
    for _, interval in ipairs(intervals) do
        totalSlots = totalSlots + (interval.max - interval.min + 1)
    end

    local pick = randomInt(1, totalSlots)
    for _, interval in ipairs(intervals) do
        local span = interval.max - interval.min + 1
        if pick <= span then
            return interval.min + (pick - 1)
        end
        pick = pick - span
    end

    return randomInt(intervals[1].min, intervals[1].max)
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
    local evacZone = buildEvacZoneRect(width, height, context)
    local evacPad = math.max(0, math.floor(context.doorEvacZonePadding or 4))
    local evacX0 = (evacZone.x or 0) - evacPad
    local evacX1 = (evacZone.x or 0) + (evacZone.width or 0) + evacPad
    local evacY0 = (evacZone.y or 0) - evacPad
    local evacY1 = (evacZone.y or 0) + (evacZone.height or 0) + evacPad
    local preferredSide = DoorUtils.normalizeEdge(edge) or DoorUtils.chooseRandomEdge(randomInt, nil)

    local function buildForSide(side, enforceEvacExclusion)
        local x = 0
        local y = 0
        local doorWidth = thickness
        local doorHeight = thickness

        if side == "top" then
            doorWidth = math.min(horizontalSize, math.max(thickness, width - (margin * 2)))
            doorHeight = thickness
            y = 0
            local minX = margin
            local maxX = math.max(margin, width - doorWidth - margin)
            if enforceEvacExclusion and rangesOverlap(y, y + doorHeight, evacY0, evacY1) then
                local safeX = chooseCoordinateOutsideBlocked(minX, maxX, doorWidth, evacX0, evacX1, randomInt)
                if safeX == nil then
                    return nil
                end
                x = safeX
            else
                x = randomInt(minX, maxX)
            end
        elseif side == "bottom" then
            doorWidth = math.min(horizontalSize, math.max(thickness, width - (margin * 2)))
            doorHeight = thickness
            y = math.max(0, height - doorHeight)
            local minX = margin
            local maxX = math.max(margin, width - doorWidth - margin)
            if enforceEvacExclusion and rangesOverlap(y, y + doorHeight, evacY0, evacY1) then
                local safeX = chooseCoordinateOutsideBlocked(minX, maxX, doorWidth, evacX0, evacX1, randomInt)
                if safeX == nil then
                    return nil
                end
                x = safeX
            else
                x = randomInt(minX, maxX)
            end
        elseif side == "left" then
            doorWidth = thickness
            doorHeight = math.min(verticalSize, math.max(thickness, height - (margin * 2)))
            x = 0
            local minY = margin
            local maxY = math.max(margin, height - doorHeight - margin)
            if enforceEvacExclusion and rangesOverlap(x, x + doorWidth, evacX0, evacX1) then
                local safeY = chooseCoordinateOutsideBlocked(minY, maxY, doorHeight, evacY0, evacY1, randomInt)
                if safeY == nil then
                    return nil
                end
                y = safeY
            else
                y = randomInt(minY, maxY)
            end
        else
            doorWidth = thickness
            doorHeight = math.min(verticalSize, math.max(thickness, height - (margin * 2)))
            x = math.max(0, width - doorWidth)
            local minY = margin
            local maxY = math.max(margin, height - doorHeight - margin)
            if enforceEvacExclusion and rangesOverlap(x, x + doorWidth, evacX0, evacX1) then
                local safeY = chooseCoordinateOutsideBlocked(minY, maxY, doorHeight, evacY0, evacY1, randomInt)
                if safeY == nil then
                    return nil
                end
                y = safeY
            else
                y = randomInt(minY, maxY)
            end
        end

        return {
            x = x,
            y = y,
            width = doorWidth,
            height = doorHeight,
            edge = side
        }
    end

    local candidateSides = { preferredSide }
    local alternatives = {}
    for _, candidate in ipairs(EDGES) do
        if candidate ~= preferredSide then
            alternatives[#alternatives + 1] = candidate
        end
    end
    for i = #alternatives, 2, -1 do
        local j = randomInt(1, i)
        alternatives[i], alternatives[j] = alternatives[j], alternatives[i]
    end
    for _, candidate in ipairs(alternatives) do
        candidateSides[#candidateSides + 1] = candidate
    end

    for _, side in ipairs(candidateSides) do
        local door = buildForSide(side, true)
        if door then
            return door
        end
    end

    return buildForSide(preferredSide, false)
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

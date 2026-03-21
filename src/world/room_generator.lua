-- Procedural room generator with deterministic door + spawn-anchor output.
local DoorTrigger = require("src/world/door_trigger")

local RoomGenerator = {}

local DEFAULT_ROOM_MARGIN = 8
local DEFAULT_SPAWN_MARGIN = 18
local DEFAULT_DOOR_THICKNESS = 28
local DEFAULT_DOOR_WIDTH_FACTOR = 0.18
local DEFAULT_DOOR_HEIGHT_FACTOR = 0.18
local EDGES = { "top", "bottom", "left", "right" }

local function createRng(seed)
    local state = math.floor(seed or 1) % 2147483647
    if state <= 0 then
        state = state + 2147483646
    end

    return function(minValue, maxValue)
        state = (state * 16807) % 2147483647
        local value = state / 2147483647
        if minValue ~= nil and maxValue ~= nil then
            if maxValue <= minValue then
                return minValue
            end
            return minValue + math.floor(value * ((maxValue - minValue) + 1))
        end
        return value
    end
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function normalizeEdge(edge)
    if edge == "top" or edge == "bottom" or edge == "left" or edge == "right" then
        return edge
    end
    return nil
end

local function copyBounds(bounds)
    local b = bounds or {}
    return {
        minX = b.minX or 0,
        minY = b.minY or 0,
        maxX = b.maxX or 0,
        maxY = b.maxY or 0
    }
end

local function ensureBounds(bounds)
    if bounds.maxX < bounds.minX then
        bounds.maxX = bounds.minX
    end
    if bounds.maxY < bounds.minY then
        bounds.maxY = bounds.minY
    end
    return bounds
end

local function chooseEdge(rng, excluded)
    local candidates = {}
    for _, edge in ipairs(EDGES) do
        if not (excluded and excluded[edge]) then
            candidates[#candidates + 1] = edge
        end
    end
    if #candidates == 0 then
        return EDGES[rng(1, #EDGES)]
    end
    return candidates[rng(1, #candidates)]
end

local function buildDoorForEdge(edge, roomWidth, roomHeight, cfg, rng)
    local margin = math.max(0, math.floor(cfg.doorEdgeMargin or DEFAULT_ROOM_MARGIN))
    local thickness = math.max(20, math.floor(cfg.doorThickness or DEFAULT_DOOR_THICKNESS))
    local horizontalSize = math.max(90, math.floor(roomWidth * (cfg.doorWidthFactor or DEFAULT_DOOR_WIDTH_FACTOR)))
    local verticalSize = math.max(90, math.floor(roomHeight * (cfg.doorHeightFactor or DEFAULT_DOOR_HEIGHT_FACTOR)))
    local side = normalizeEdge(edge) or chooseEdge(rng, nil)

    local x = 0
    local y = 0
    local width = thickness
    local height = thickness

    if side == "top" then
        width = math.min(horizontalSize, math.max(thickness, roomWidth - (margin * 2)))
        height = thickness
        x = rng(margin, math.max(margin, roomWidth - width - margin))
        y = 0
    elseif side == "bottom" then
        width = math.min(horizontalSize, math.max(thickness, roomWidth - (margin * 2)))
        height = thickness
        x = rng(margin, math.max(margin, roomWidth - width - margin))
        y = math.max(0, roomHeight - height)
    elseif side == "left" then
        width = thickness
        height = math.min(verticalSize, math.max(thickness, roomHeight - (margin * 2)))
        x = 0
        y = rng(margin, math.max(margin, roomHeight - height - margin))
    else
        width = thickness
        height = math.min(verticalSize, math.max(thickness, roomHeight - (margin * 2)))
        x = math.max(0, roomWidth - width)
        y = rng(margin, math.max(margin, roomHeight - height - margin))
    end

    return {
        x = x,
        y = y,
        width = width,
        height = height,
        edge = side
    }
end

local function normalizeDoorSnapshot(door, roomBounds)
    if type(door) ~= "table" then
        return nil
    end

    local edge = normalizeEdge(door.edge)
    if not edge then
        return nil
    end

    local rb = roomBounds
    local x = clamp(math.floor(door.x or 0), rb.minX, rb.maxX)
    local y = clamp(math.floor(door.y or 0), rb.minY, rb.maxY)
    local width = math.max(1, math.floor(door.width or 1))
    local height = math.max(1, math.floor(door.height or 1))
    width = math.min(width, math.max(1, rb.maxX - x))
    height = math.min(height, math.max(1, rb.maxY - y))

    return {
        x = x,
        y = y,
        width = width,
        height = height,
        edge = edge
    }
end

local function shrinkBounds(bounds, padding)
    local pad = math.max(0, math.floor(padding or 0))
    local shrunk = {
        minX = bounds.minX + pad,
        minY = bounds.minY + pad,
        maxX = bounds.maxX - pad,
        maxY = bounds.maxY - pad
    }
    return ensureBounds(shrunk)
end

local function applyDoorExclusion(spawnBounds, door, padding, roomBounds)
    if not door then
        return spawnBounds
    end

    local pad = math.max(0, math.floor(padding or 0))
    local bounds = copyBounds(spawnBounds)
    if door.edge == "top" then
        local blockTo = (door.y or roomBounds.minY) + (door.height or 0) + pad
        bounds.minY = math.max(bounds.minY, blockTo)
    elseif door.edge == "bottom" then
        local blockFrom = (door.y or roomBounds.maxY) - pad
        bounds.maxY = math.min(bounds.maxY, blockFrom)
    elseif door.edge == "left" then
        local blockTo = (door.x or roomBounds.minX) + (door.width or 0) + pad
        bounds.minX = math.max(bounds.minX, blockTo)
    elseif door.edge == "right" then
        local blockFrom = (door.x or roomBounds.maxX) - pad
        bounds.maxX = math.min(bounds.maxX, blockFrom)
    end
    return ensureBounds(bounds)
end

local function buildPlayerAnchor(playerBounds)
    return {
        x = math.floor((playerBounds.minX + playerBounds.maxX) * 0.5),
        y = math.floor((playerBounds.minY + playerBounds.maxY) * 0.5)
    }
end

local function buildObstacles(rng, bounds)
    local obstacles = {}
    local spanX = math.max(0, bounds.maxX - bounds.minX)
    local spanY = math.max(0, bounds.maxY - bounds.minY)
    if spanX < 120 or spanY < 120 then
        return obstacles
    end

    local count = rng(0, 2)
    for _ = 1, count do
        local width = rng(70, math.max(70, math.floor(spanX * 0.25)))
        local height = rng(50, math.max(50, math.floor(spanY * 0.22)))
        local x = rng(bounds.minX, math.max(bounds.minX, bounds.maxX - width))
        local y = rng(bounds.minY, math.max(bounds.minY, bounds.maxY - height))
        obstacles[#obstacles + 1] = { x = x, y = y, width = width, height = height }
    end

    return obstacles
end

function RoomGenerator.generate(opts)
    local cfg = opts or {}
    local context = cfg.context or {}
    local roomWidth = math.max(200, math.floor(cfg.width or 1280))
    local roomHeight = math.max(120, math.floor(cfg.height or 720))
    local roomIndex = math.max(1, math.floor(cfg.index or 1))
    local roomsCleared = math.max(0, math.floor(cfg.roomsCleared or 0))
    local roomsToEscape = math.max(1, math.floor(cfg.roomsToEscape or 1))
    local hasEntryDoor = roomIndex > 1
    local hasExitDoor = roomIndex < roomsToEscape
    local rng = createRng(cfg.seed or ((os.time() or 1) + roomIndex))

    local roomBounds = {
        minX = DEFAULT_ROOM_MARGIN,
        minY = DEFAULT_ROOM_MARGIN,
        maxX = math.max(DEFAULT_ROOM_MARGIN, roomWidth - DEFAULT_ROOM_MARGIN),
        maxY = math.max(DEFAULT_ROOM_MARGIN, roomHeight - DEFAULT_ROOM_MARGIN)
    }

    local entryDoor = nil
    if hasEntryDoor then
        entryDoor = normalizeDoorSnapshot(cfg.entryDoor, roomBounds)
        if not entryDoor then
            entryDoor = buildDoorForEdge(nil, roomWidth, roomHeight, context, rng)
        end
    end

    local exitDoor = nil
    if hasExitDoor then
        local excluded = {}
        if entryDoor and entryDoor.edge then
            excluded[entryDoor.edge] = true
        end
        local exitEdge = chooseEdge(rng, excluded)
        exitDoor = buildDoorForEdge(exitEdge, roomWidth, roomHeight, context, rng)
    end

    local spawnBase = shrinkBounds(roomBounds, DEFAULT_SPAWN_MARGIN)
    local doorSpawnPad = math.max(30, math.floor(math.min(roomWidth, roomHeight) * 0.08))
    spawnBase = applyDoorExclusion(spawnBase, entryDoor, doorSpawnPad, roomBounds)
    spawnBase = applyDoorExclusion(spawnBase, exitDoor, doorSpawnPad, roomBounds)

    local nodeArea = shrinkBounds(spawnBase, 16)
    local hunterArea = shrinkBounds(spawnBase, 6)
    local playerArea = shrinkBounds(spawnBase, 12)

    local doors = {
        entry = entryDoor,
        exit = exitDoor
    }

    return {
        id = ("room_%d_%d"):format(roomIndex, math.abs((cfg.seed or roomIndex) % 100000)),
        index = roomIndex,
        seed = cfg.seed,
        bounds = roomBounds,
        doors = doors,
        doorTriggers = DoorTrigger.createFromDoors(doors, roomBounds, {
            depth = context.doorTriggerDepth or 36,
            pad = context.doorTriggerPadding or 0
        }),
        spawn = {
            bounds = spawnBase,
            player = playerArea,
            playerAnchor = buildPlayerAnchor(playerArea),
            cells = spawnBase,
            patrol = spawnBase,
            hunters = hunterArea,
            nodes = nodeArea
        },
        obstacles = buildObstacles(rng, spawnBase),
        meta = {
            roomsClearedAtGeneration = roomsCleared,
            roomsToEscape = roomsToEscape
        }
    }
end

return RoomGenerator

-- Procedural room generator with deterministic door + spawn-anchor output.
local DoorTrigger = require("src/world/door_trigger")
local DoorUtils = require("src/world/door_utils")
local MathUtils = require("src/utils/math_utils")

local RoomGenerator = {}

local DEFAULT_ROOM_MARGIN = 8
local DEFAULT_SPAWN_MARGIN = 18
local DEFAULT_PLAYER_SIZE = 35

local function createRng(seed)
    local state = math.floor(seed or 1) % 2147483647
    if state <= 0 then
        state = state + 2147483646
    end

    local function nextFloat()
        state = (state * 16807) % 2147483647
        return state / 2147483647
    end

    -- Warm up once to avoid low-seed first-draw bias (room-1 door edge sticking to top).
    nextFloat()

    return function(minValue, maxValue)
        local value = nextFloat()
        if minValue ~= nil and maxValue ~= nil then
            if maxValue <= minValue then
                return minValue
            end
            return minValue + math.floor(value * ((maxValue - minValue) + 1))
        end
        return value
    end
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

local function normalizeDoorSnapshot(door, roomWidth, roomHeight, cfg)
    if type(door) ~= "table" then
        return nil
    end

    local edge = DoorUtils.normalizeEdge(door.edge)
    if not edge then
        return nil
    end

    return DoorUtils.clampDoorToSafeBounds({
        x = math.floor(door.x or 0),
        y = math.floor(door.y or 0),
        width = math.max(1, math.floor(door.width or 1)),
        height = math.max(1, math.floor(door.height or 1)),
        edge = edge
    }, roomWidth, roomHeight, cfg)
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

local function buildDoorEntrySpawn(door, roomBounds, playerSize)
    if not door then
        return nil
    end

    local size = math.max(1, math.floor(playerSize or DEFAULT_PLAYER_SIZE))
    local halfSize = size * 0.5
    local inset = math.max(6, math.floor(size * 0.35))
    local centerX = (door.x or 0) + ((door.width or 0) * 0.5)
    local centerY = (door.y or 0) + ((door.height or 0) * 0.5)
    local x = centerX - halfSize
    local y = centerY - halfSize

    if door.edge == "top" then
        y = (door.y or 0) + (door.height or 0) + inset
    elseif door.edge == "bottom" then
        y = (door.y or 0) - size - inset
    elseif door.edge == "left" then
        x = (door.x or 0) + (door.width or 0) + inset
    elseif door.edge == "right" then
        x = (door.x or 0) - size - inset
    end

    x = MathUtils.clamp(math.floor(x), roomBounds.minX, math.max(roomBounds.minX, roomBounds.maxX - size))
    y = MathUtils.clamp(math.floor(y), roomBounds.minY, math.max(roomBounds.minY, roomBounds.maxY - size))
    return {
        x = x,
        y = y,
        edge = door.edge,
        size = size
    }
end

local function buildEntrySafeZone(entrySpawn, roomBounds, context)
    if not entrySpawn then
        return nil
    end

    local cfg = context or {}
    local size = math.max(1, math.floor(entrySpawn.size or cfg.playerSize or DEFAULT_PLAYER_SIZE))
    local padding = math.max(0, math.floor(cfg.entrySpawnSafePadding or math.max(10, size * 0.45)))
    local x0 = (entrySpawn.x or 0) - padding
    local y0 = (entrySpawn.y or 0) - padding
    local x1 = (entrySpawn.x or 0) + size + padding
    local y1 = (entrySpawn.y or 0) + size + padding

    local minX = MathUtils.clamp(x0, roomBounds.minX, roomBounds.maxX)
    local minY = MathUtils.clamp(y0, roomBounds.minY, roomBounds.maxY)
    local maxX = MathUtils.clamp(x1, roomBounds.minX, roomBounds.maxX)
    local maxY = MathUtils.clamp(y1, roomBounds.minY, roomBounds.maxY)

    return {
        x = math.floor(minX),
        y = math.floor(minY),
        width = math.max(1, math.floor(maxX - minX)),
        height = math.max(1, math.floor(maxY - minY))
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
    local playerSize = math.max(1, math.floor(context.playerSize or DEFAULT_PLAYER_SIZE))
    local rng = createRng(cfg.seed or ((os.time() or 1) + roomIndex))

    local roomBounds = {
        minX = DEFAULT_ROOM_MARGIN,
        minY = DEFAULT_ROOM_MARGIN,
        maxX = math.max(DEFAULT_ROOM_MARGIN, roomWidth - DEFAULT_ROOM_MARGIN),
        maxY = math.max(DEFAULT_ROOM_MARGIN, roomHeight - DEFAULT_ROOM_MARGIN)
    }

    local entryDoor = nil
    if hasEntryDoor then
        entryDoor = normalizeDoorSnapshot(cfg.entryDoor, roomWidth, roomHeight, context)
        if not entryDoor then
            entryDoor = DoorUtils.buildDoorForEdge(nil, roomWidth, roomHeight, context, rng)
        end
    end

    local exitDoor = nil
    if hasExitDoor then
        local excludedEdges = {}
        if entryDoor and entryDoor.edge then
            excludedEdges[entryDoor.edge] = true
        end

        local function canUseExitDoor(candidate)
            if not candidate then
                return false
            end
            if entryDoor and candidate.edge == entryDoor.edge then
                return false
            end
            if DoorUtils.sameDoor(candidate, entryDoor) then
                return false
            end
            return true
        end

        local attempts = 0
        repeat
            local exitEdge = DoorUtils.chooseRandomEdge(rng, excludedEdges)
            exitDoor = DoorUtils.buildDoorForEdge(exitEdge, roomWidth, roomHeight, context, rng)
            attempts = attempts + 1
        until attempts >= 24 or canUseExitDoor(exitDoor)

        if not canUseExitDoor(exitDoor) then
            local edges = DoorUtils.getEdges()
            for _, edge in ipairs(edges) do
                if not excludedEdges[edge] then
                    local edgeAttempts = 0
                    repeat
                        exitDoor = DoorUtils.buildDoorForEdge(edge, roomWidth, roomHeight, context, rng)
                        edgeAttempts = edgeAttempts + 1
                    until edgeAttempts >= 6 or canUseExitDoor(exitDoor)
                    if canUseExitDoor(exitDoor) then
                        break
                    end
                end
            end
        end

        if not canUseExitDoor(exitDoor) then
            for _, edge in ipairs(DoorUtils.getEdges()) do
                local edgeAttempts = 0
                repeat
                    exitDoor = DoorUtils.buildDoorForEdge(edge, roomWidth, roomHeight, context, rng)
                    edgeAttempts = edgeAttempts + 1
                until edgeAttempts >= 6 or canUseExitDoor(exitDoor)
                if canUseExitDoor(exitDoor) then
                    break
                end
            end
        end
    end

    local spawnBase = shrinkBounds(roomBounds, DEFAULT_SPAWN_MARGIN)
    local doorSpawnPad = math.max(30, math.floor(math.min(roomWidth, roomHeight) * 0.08))
    spawnBase = applyDoorExclusion(spawnBase, entryDoor, doorSpawnPad, roomBounds)
    spawnBase = applyDoorExclusion(spawnBase, exitDoor, doorSpawnPad, roomBounds)

    local nodeArea = shrinkBounds(spawnBase, 16)
    local hunterArea = shrinkBounds(spawnBase, 6)
    local playerArea = shrinkBounds(spawnBase, 12)
    local entrySpawn = buildDoorEntrySpawn(entryDoor, roomBounds, playerSize)
    local entrySafeZone = buildEntrySafeZone(entrySpawn, roomBounds, context)
    local playerAnchor = entrySpawn or buildPlayerAnchor(playerArea)

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
            playerAnchor = playerAnchor,
            entryPoint = entrySpawn,
            entrySafeZone = entrySafeZone,
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

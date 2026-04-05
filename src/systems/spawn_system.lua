-- Provides safe spawn placement checks for player start/room transitions.
local EnemySystem = require("src/systems/enemy_system")
local PowerNodeSystem = require("src/systems/power_node_system")
local CollisionSystem = require("src/systems/collision_system")
local Kinematics = require("src/utils/kinematics")
local MathUtils = require("src/utils/math_utils")
local SearchUtils = require("src/utils/search_utils")

local SpawnSystem = {}

local SAFE_SPAWN_PADDING = 12
local SAFE_SPAWN_RANDOM_ATTEMPTS = 140
local DEFAULT_PLAYER_SIZE = 35

local function overlapsAnyRectEntity(x, y, size, entities)
    for _, entity in ipairs(entities or {}) do
        if CollisionSystem.overlaps(
            x,
            y,
            size,
            size,
            entity.x or 0,
            entity.y or 0,
            entity.width or 0,
            entity.height or 0
        ) then
            return true
        end
    end
    return false
end

local function clampSpawnPoint(x, y, playerSize, playWidth, playHeight)
    local size = math.max(1, math.floor(playerSize or DEFAULT_PLAYER_SIZE))
    local maxX = math.max(0, math.floor((playWidth or 0) - size))
    local maxY = math.max(0, math.floor((playHeight or 0) - size))
    local clampedX = MathUtils.clamp(math.floor(x or 0), 0, maxX)
    local clampedY = MathUtils.clamp(math.floor(y or 0), 0, maxY)
    return clampedX, clampedY
end

local function addCandidate(candidates, seen, x, y, playerSize, playWidth, playHeight)
    local cx, cy = clampSpawnPoint(x, y, playerSize, playWidth, playHeight)
    local key = ("%d:%d"):format(cx, cy)
    if seen[key] then
        return
    end
    seen[key] = true
    candidates[#candidates + 1] = { x = cx, y = cy }
end

local function buildDoorEntryCandidates(entryDoor, playerSize, playWidth, playHeight)
    if type(entryDoor) ~= "table" then
        return {}
    end

    local size = math.max(1, math.floor(playerSize or DEFAULT_PLAYER_SIZE))
    local inset = math.max(6, math.floor(size * 0.35))
    local lateral = math.max(8, math.floor(size * 0.45))
    local centerX = (entryDoor.x or 0) + ((entryDoor.width or 0) * 0.5)
    local centerY = (entryDoor.y or 0) + ((entryDoor.height or 0) * 0.5)
    local offsets = { 0, -lateral, lateral, -(lateral * 2), lateral * 2 }
    local depths = { inset, inset + math.floor(size * 0.5), inset + size }
    local candidates = {}
    local seen = {}

    if entryDoor.edge == "top" or entryDoor.edge == "bottom" then
        for _, depth in ipairs(depths) do
            local baseY = (entryDoor.edge == "top")
                    and ((entryDoor.y or 0) + (entryDoor.height or 0) + depth)
                or ((entryDoor.y or 0) - size - depth)
            for _, offset in ipairs(offsets) do
                addCandidate(
                    candidates,
                    seen,
                    (centerX - (size * 0.5)) + offset,
                    baseY,
                    size,
                    playWidth,
                    playHeight
                )
            end
        end
    elseif entryDoor.edge == "left" or entryDoor.edge == "right" then
        for _, depth in ipairs(depths) do
            local baseX = (entryDoor.edge == "left")
                    and ((entryDoor.x or 0) + (entryDoor.width or 0) + depth)
                or ((entryDoor.x or 0) - size - depth)
            for _, offset in ipairs(offsets) do
                addCandidate(
                    candidates,
                    seen,
                    baseX,
                    (centerY - (size * 0.5)) + offset,
                    size,
                    playWidth,
                    playHeight
                )
            end
        end
    else
        addCandidate(candidates, seen, centerX - (size * 0.5), centerY - (size * 0.5), size, playWidth, playHeight)
    end

    return candidates
end

local function inHunterDetectionRange(x, y, playerSize, hunter)
    local px, py = MathUtils.rectCenter(x, y, playerSize, playerSize)
    local hx, hy = MathUtils.rectCenter(hunter.x or 0, hunter.y or 0, hunter.width or 0, hunter.height or 0)
    local distSq = MathUtils.distanceSquared(px, py, hx, hy)
    local range = math.max(0, hunter.visionRange or 0) + (playerSize * 0.35)
    return distSq <= (range * range)
end

local function inPatrolLine(x, y, playerSize, patrol)
    local playerCenterX = x + (playerSize / 2)
    local playerCenterY = y + (playerSize / 2)
    local patrolCenterY = (patrol.y or 0) + ((patrol.height or 0) / 2)
    local lineBand = math.max(playerSize * 0.5, (patrol.height or playerSize) * 0.55)
    if math.abs(playerCenterY - patrolCenterY) > lineBand then
        return false
    end

    local startX = patrol.x1 or patrol.x or 0
    local endX = patrol.x2 or patrol.x or 0
    local minX = math.min(startX, endX) - (playerSize * 0.35)
    local maxX = math.max(startX, endX) + (patrol.width or playerSize) + (playerSize * 0.35)
    return playerCenterX >= minX and playerCenterX <= maxX
end

function SpawnSystem.isSafePlayerSpawn(x, y, playerSize)
    local drones = EnemySystem.getDrones()
    local hunters = EnemySystem.getHunters()
    local nodes = PowerNodeSystem.getNodes()

    for _, hunter in ipairs(hunters) do
        if inHunterDetectionRange(x, y, playerSize, hunter) then
            return false
        end
    end

    for _, drone in ipairs(drones) do
        if inPatrolLine(x, y, playerSize, drone) then
            return false
        end
    end

    -- Also avoid immediate overlap with solid power nodes and enemy bodies.
    if overlapsAnyRectEntity(x, y, playerSize, nodes) then
        return false
    end
    if overlapsAnyRectEntity(x, y, playerSize, drones) then
        return false
    end
    if overlapsAnyRectEntity(x, y, playerSize, hunters) then
        return false
    end

    return true
end

function SpawnSystem.findSafePlayerSpawn(playWidth, playHeight, playerSize, spawnBounds, opts)
    local w = playWidth or 0
    local h = playHeight or 0
    local size = math.max(1, math.floor(playerSize or DEFAULT_PLAYER_SIZE))
    local bounds = spawnBounds or {}
    local options = opts or {}
    local minX = math.max(SAFE_SPAWN_PADDING, math.floor(bounds.minX or SAFE_SPAWN_PADDING))
    local minY = math.max(SAFE_SPAWN_PADDING, math.floor(bounds.minY or SAFE_SPAWN_PADDING))
    local maxDefaultX = math.max(minX, w - size - SAFE_SPAWN_PADDING)
    local maxDefaultY = math.max(minY, h - size - SAFE_SPAWN_PADDING)
    local maxX = bounds.maxX and math.floor(bounds.maxX - size) or maxDefaultX
    local maxY = bounds.maxY and math.floor(bounds.maxY - size) or maxDefaultY
    maxX = math.max(minX, math.min(maxDefaultX, maxX))
    maxY = math.max(minY, math.min(maxDefaultY, maxY))
    local centerX = math.floor((w - size) / 2)
    local centerY = math.floor((h - size) / 2)
    centerX = math.max(minX, math.min(maxX, centerX))
    centerY = math.max(minY, math.min(maxY, centerY))

    if type(options.preferredSpawn) == "table" then
        local preferredX, preferredY = clampSpawnPoint(options.preferredSpawn.x, options.preferredSpawn.y, size, w, h)
        if SpawnSystem.isSafePlayerSpawn(preferredX, preferredY, size) then
            return preferredX, preferredY
        end
    end

    local entryCandidates = buildDoorEntryCandidates(options.entryDoor, size, w, h)
    for _, candidate in ipairs(entryCandidates) do
        if SpawnSystem.isSafePlayerSpawn(candidate.x, candidate.y, size) then
            return candidate.x, candidate.y
        end
    end

    if SpawnSystem.isSafePlayerSpawn(centerX, centerY, size) then
        return centerX, centerY
    end

    local x, y = SearchUtils.findRandomThenGrid(
        { minX = minX, maxX = maxX, minY = minY, maxY = maxY },
        SAFE_SPAWN_RANDOM_ATTEMPTS,
        math.max(10, math.floor(size * 0.75)),
        function(candidateX, candidateY)
            return SpawnSystem.isSafePlayerSpawn(candidateX, candidateY, size)
        end
    )
    if x ~= nil and y ~= nil then
        return x, y
    end

    return centerX, centerY
end

function SpawnSystem.placePlayerInSafeSpawn(player, playWidth, playHeight, playerSize, spawnBounds, opts)
    local spawnX, spawnY = SpawnSystem.findSafePlayerSpawn(playWidth, playHeight, playerSize, spawnBounds, opts)
    player.x = spawnX
    player.y = spawnY
    Kinematics.stop(player)
end

return SpawnSystem

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
    for _, node in ipairs(nodes) do
        if CollisionSystem.overlaps(x, y, playerSize, playerSize, node.x or 0, node.y or 0, node.width or 0, node.height or 0) then
            return false
        end
    end
    for _, drone in ipairs(drones) do
        if CollisionSystem.overlaps(x, y, playerSize, playerSize, drone.x or 0, drone.y or 0, drone.width or 0, drone.height or 0) then
            return false
        end
    end
    for _, hunter in ipairs(hunters) do
        if CollisionSystem.overlaps(x, y, playerSize, playerSize, hunter.x or 0, hunter.y or 0, hunter.width or 0, hunter.height or 0) then
            return false
        end
    end

    return true
end

function SpawnSystem.findSafePlayerSpawn(playWidth, playHeight, playerSize, spawnBounds)
    local w = playWidth or 0
    local h = playHeight or 0
    local bounds = spawnBounds or {}
    local minX = math.max(SAFE_SPAWN_PADDING, math.floor(bounds.minX or SAFE_SPAWN_PADDING))
    local minY = math.max(SAFE_SPAWN_PADDING, math.floor(bounds.minY or SAFE_SPAWN_PADDING))
    local maxDefaultX = math.max(minX, w - playerSize - SAFE_SPAWN_PADDING)
    local maxDefaultY = math.max(minY, h - playerSize - SAFE_SPAWN_PADDING)
    local maxX = bounds.maxX and math.floor(bounds.maxX - playerSize) or maxDefaultX
    local maxY = bounds.maxY and math.floor(bounds.maxY - playerSize) or maxDefaultY
    maxX = math.max(minX, math.min(maxDefaultX, maxX))
    maxY = math.max(minY, math.min(maxDefaultY, maxY))
    local centerX = math.floor((w - playerSize) / 2)
    local centerY = math.floor((h - playerSize) / 2)
    centerX = math.max(minX, math.min(maxX, centerX))
    centerY = math.max(minY, math.min(maxY, centerY))

    if SpawnSystem.isSafePlayerSpawn(centerX, centerY, playerSize) then
        return centerX, centerY
    end

    local x, y = SearchUtils.findRandomThenGrid(
        { minX = minX, maxX = maxX, minY = minY, maxY = maxY },
        SAFE_SPAWN_RANDOM_ATTEMPTS,
        math.max(10, math.floor(playerSize * 0.75)),
        function(candidateX, candidateY)
            return SpawnSystem.isSafePlayerSpawn(candidateX, candidateY, playerSize)
        end
    )
    if x ~= nil and y ~= nil then
        return x, y
    end

    return centerX, centerY
end

function SpawnSystem.placePlayerInSafeSpawn(player, playWidth, playHeight, playerSize, spawnBounds)
    local spawnX, spawnY = SpawnSystem.findSafePlayerSpawn(playWidth, playHeight, playerSize, spawnBounds)
    player.x = spawnX
    player.y = spawnY
    Kinematics.stop(player)
end

return SpawnSystem

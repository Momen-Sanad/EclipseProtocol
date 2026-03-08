-- Owns enemy spawning, per-frame updates, collision hooks, and rendering.
local CollisionSystem = require("src/systems/collision_system")
local PatrolDrone = require("src/entities/patrol_drone")
local HunterDrone = require("src/entities/hunter_drone")

local EnemySystem = {}

local drones = {}
local hunters = {}

local DEFAULT_DRONE_SIZE = 90
local DEFAULT_HUNTER_SIZE = 90
local DEFAULT_DRONE_COUNT = 1
local DEFAULT_HUNTER_COUNT = 1
local DEFAULT_DRONE_SPEED = 170
local DEFAULT_HUNTER_SPEED = 180
local DEFAULT_HUNTER_VISION_RANGE = 420
local DEFAULT_DRONE_DAMAGE = 12
local DEFAULT_HUNTER_DAMAGE = 15

local function clampCount(value, fallback)
    local n = tonumber(value)
    if not n then
        return fallback
    end
    return math.max(0, math.floor(n))
end

function EnemySystem.reset(playWidth, playHeight, opts)
    opts = opts or {}
    drones = {}
    hunters = {}

    local w = playWidth or 0
    local h = playHeight or 0
    local droneSize = opts.droneSize or DEFAULT_DRONE_SIZE
    local hunterSize = opts.hunterSize or DEFAULT_HUNTER_SIZE
    local droneCount = clampCount(opts.droneCount, DEFAULT_DRONE_COUNT)
    local hunterCount = clampCount(opts.hunterCount, DEFAULT_HUNTER_COUNT)
    local droneSpeed = opts.droneSpeed or DEFAULT_DRONE_SPEED
    local hunterSpeed = opts.hunterSpeed or DEFAULT_HUNTER_SPEED
    local hunterVisionRange = opts.hunterVisionRange or DEFAULT_HUNTER_VISION_RANGE
    local droneDamage = opts.droneDamage or DEFAULT_DRONE_DAMAGE
    local hunterDamage = opts.hunterDamage or DEFAULT_HUNTER_DAMAGE

    local droneMargin = droneSize + 40
    local x1 = droneMargin
    local x2 = math.max(droneMargin, w - droneMargin)

    for i = 1, droneCount do
        local t = i / (droneCount + 1)
        local laneY = math.floor(h * (0.18 + (0.58 * t)))
        local startsForward = (i % 2) == 1
        local startX = startsForward and x1 or x2

        drones[#drones + 1] = PatrolDrone.new({
            x = startX,
            y = laneY,
            x1 = x1,
            y1 = laneY,
            x2 = x2,
            y2 = laneY,
            forward = startsForward,
            size = droneSize,
            speed = droneSpeed,
            damage = droneDamage,
            invulDuration = 1.5,
            color = { 0.95, 0.4, 0.25, 1.0 }
        })
    end

    local hunterMinX = math.max(16, math.floor(w * 0.12))
    local hunterMaxX = math.max(hunterMinX + 1, math.floor(w * 0.34))
    for i = 1, hunterCount do
        local t = i / (hunterCount + 1)
        local spawnY = math.floor(h * (0.20 + (0.58 * t)))
        local xRatio = ((i - 1) % 3) / 2
        local spawnX = math.floor(hunterMinX + (hunterMaxX - hunterMinX) * xRatio)

        hunters[#hunters + 1] = HunterDrone.new({
            x = spawnX,
            y = spawnY,
            size = hunterSize,
            speed = hunterSpeed,
            visionRange = hunterVisionRange,
            dotThreshold = 0.5,
            damage = hunterDamage,
            invulDuration = 1.5,
            color = { 0.2, 0.85, 1.0, 1.0 },
            coneColor = { 0.2, 0.8, 1.0, 0.18 },
            lineColor = { 0.9, 0.9, 1.0, 0.7 },
            lookColor = { 0.2, 0.9, 1.0, 0.9 }
        })
    end
end

function EnemySystem.update(player, dt, playerSize)
    for _, drone in ipairs(drones) do
        drone.prevX = drone.x
        drone.prevY = drone.y
        drone:update(dt)
    end

    for _, hunter in ipairs(hunters) do
        hunter.prevX = hunter.x
        hunter.prevY = hunter.y
        hunter:update(player, dt, playerSize)
    end
end

function EnemySystem.resolvePlayerCollisions(player, playerSize)
    CollisionSystem.stopPlayerOnEnemies(drones, player, playerSize)
    CollisionSystem.stopPlayerOnEnemies(hunters, player, playerSize)
    CollisionSystem.stopEnemiesOnPlayer(drones, player, playerSize)
    CollisionSystem.stopEnemiesOnPlayer(hunters, player, playerSize)
end

function EnemySystem.resolveObstacleCollisions(obstacle)
    CollisionSystem.stopEnemiesOnObstacle(drones, obstacle)
    CollisionSystem.stopEnemiesOnObstacle(hunters, obstacle)
end

function EnemySystem.draw(player, playerSize)
    for _, drone in ipairs(drones) do
        drone:draw()
    end
    for _, hunter in ipairs(hunters) do
        hunter:draw(player, (playerSize or 35) / 2)
    end
end

function EnemySystem.getDrones()
    return drones
end

function EnemySystem.getHunters()
    return hunters
end

return EnemySystem

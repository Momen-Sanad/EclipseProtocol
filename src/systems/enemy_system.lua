-- Owns enemy spawning, per-frame updates, collision hooks, and rendering.
local CollisionSystem = require("src/systems/collision_system")
local PatrolDrone = require("src/entities/patrol_drone")
local HunterDrone = require("src/entities/hunter_drone")

local EnemySystem = {}

local drones = {}
local hunters = {}

local DEFAULT_DRONE_SIZE = 90
local DEFAULT_HUNTER_SIZE = 90

function EnemySystem.reset(playWidth, playHeight, opts)
    opts = opts or {}
    drones = {}
    hunters = {}

    local w = playWidth or 0
    local h = playHeight or 0
    local droneSize = opts.droneSize or DEFAULT_DRONE_SIZE
    local hunterSize = opts.hunterSize or DEFAULT_HUNTER_SIZE

    local margin = droneSize + 40
    local x1 = margin
    local y1 = math.floor(h * 0.3)
    local x2 = math.max(margin, w - margin)
    local y2 = y1

    drones[#drones + 1] = PatrolDrone.new({
        x = x1,
        y = y1,
        x1 = x1,
        y1 = y1,
        x2 = x2,
        y2 = y2,
        size = droneSize,
        speed = 180,
        damage = 12,
        invulDuration = 1.5,
        color = { 0.95, 0.4, 0.25, 1.0 }
    })

    hunters[#hunters + 1] = HunterDrone.new({
        x = math.floor(w * 0.2),
        y = math.floor(h * 0.7),
        size = hunterSize,
        speed = 220,
        visionRange = 420,
        dotThreshold = 0.5,
        damage = 15,
        invulDuration = 1.5,
        color = { 0.2, 0.85, 1.0, 1.0 },
        coneColor = { 0.2, 0.8, 1.0, 0.18 },
        lineColor = { 0.9, 0.9, 1.0, 0.7 },
        lookColor = { 0.2, 0.9, 1.0, 0.9 }
    })
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

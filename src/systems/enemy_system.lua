-- Owns enemy spawning, per-frame updates, collision hooks, and rendering.
local CollisionSystem = require("src/systems/collision_system")
local PatrolDrone = require("src/entities/patrol_drone")
local HunterDrone = require("src/entities/hunter_drone")

local EnemySystem = {}

local drones = {}
local hunters = {}

local DEFAULT_DRONE_SIZE = 90
local DEFAULT_HUNTER_SIZE = 90
local DEFAULT_PATROL_SPEED = 170
local DEFAULT_HUNTER_SPEED = 180
local DEFAULT_HUNTER_VISION = 420
local DEFAULT_PATROL_DAMAGE = 12
local DEFAULT_HUNTER_DAMAGE = 15
local DEFAULT_PATROL_NODE_MIN_DISTANCE = 260
local DEFAULT_PATROL_LINE_NODE_CLEARANCE = 24
local DEFAULT_PATROL_ROUTE_MIN_FRACTION = 0.24
local DEFAULT_PATROL_ROUTE_MAX_FRACTION = 0.62

local function aabb(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function overlapsRepairNodes(x, y, w, h, repairNodes, padding)
    if type(repairNodes) ~= "table" or #repairNodes == 0 then
        return false
    end

    local pad = math.max(0, padding or 0)
    for _, node in ipairs(repairNodes) do
        local nx = (node.x or 0) - pad
        local ny = (node.y or 0) - pad
        local nw = (node.width or 0) + (pad * 2)
        local nh = (node.height or 0) + (pad * 2)
        if aabb(x, y, w, h, nx, ny, nw, nh) then
            return true
        end
    end

    return false
end

local function overlapsExistingPatrols(x, y, w, h, padding)
    local pad = math.max(0, padding or 0)
    local px = (x or 0) - pad
    local py = (y or 0) - pad
    local pw = (w or 0) + (pad * 2)
    local ph = (h or 0) + (pad * 2)

    for _, drone in ipairs(drones) do
        local dx = (drone.x or 0) - pad
        local dy = (drone.y or 0) - pad
        local dw = (drone.width or w or 0) + (pad * 2)
        local dh = (drone.height or h or 0) + (pad * 2)
        if aabb(px, py, pw, ph, dx, dy, dw, dh) then
            return true
        end
    end

    return false
end

local function getNodeCenter(node)
    return (node.x or 0) + ((node.width or 0) / 2), (node.y or 0) + ((node.height or 0) / 2)
end

local function isPatrolSpawnTooCloseToNodes(x, y, repairNodes, minDistance)
    if type(repairNodes) ~= "table" or #repairNodes == 0 then
        return false
    end

    local threshold = math.max(0, minDistance or 0)
    local thresholdSq = threshold * threshold
    for _, node in ipairs(repairNodes) do
        local nx, ny = getNodeCenter(node)
        local dx = x - nx
        local dy = y - ny
        if ((dx * dx) + (dy * dy)) < thresholdSq then
            return true
        end
    end
    return false
end

local function doesPatrolLineCrossNodes(y, droneSize, repairNodes, extraClearance)
    -- Patrol routes are horizontal lines; keep the whole lane away from node bodies.
    if type(repairNodes) ~= "table" or #repairNodes == 0 then
        return false
    end

    local halfThickness = math.max(8, math.floor((droneSize or DEFAULT_DRONE_SIZE) * 0.25))
    local clearance = math.max(0, extraClearance or DEFAULT_PATROL_LINE_NODE_CLEARANCE)
    local minLineY = y - halfThickness - clearance
    local maxLineY = y + halfThickness + clearance

    for _, node in ipairs(repairNodes) do
        local nodeMinY = node.y or 0
        local nodeMaxY = nodeMinY + (node.height or 0)
        if maxLineY >= nodeMinY and minLineY <= nodeMaxY then
            return true
        end
    end
    return false
end

local function resolvePatrolLineY(baseY, minY, maxY, droneSize, repairNodes, opts)
    -- If a lane intersects a node, shift it up/down until the line is clear.
    local y = math.max(minY, math.min(maxY, baseY))
    local clearance = opts.patrolLineNodeClearance or DEFAULT_PATROL_LINE_NODE_CLEARANCE
    if not doesPatrolLineCrossNodes(y, droneSize, repairNodes, clearance) then
        return y
    end

    local step = math.max(12, math.floor((droneSize or DEFAULT_DRONE_SIZE) * 0.35))
    local maxSteps = math.max(1, math.floor((maxY - minY) / step))
    for i = 1, maxSteps do
        local upY = math.max(minY, y - (i * step))
        if not doesPatrolLineCrossNodes(upY, droneSize, repairNodes, clearance) then
            return upY
        end

        local downY = math.min(maxY, y + (i * step))
        if not doesPatrolLineCrossNodes(downY, droneSize, repairNodes, clearance) then
            return downY
        end
    end

    -- Last resort: keep original lane if map is too dense.
    return y
end

local function resolvePatrolOverlapY(x, y, droneSize, minY, maxY, padding)
    if not overlapsExistingPatrols(x, y, droneSize, droneSize, padding) then
        return y
    end

    local step = math.max(8, math.floor(droneSize * 0.5))
    local maxSteps = math.max(1, math.floor((maxY - minY) / step) + 2)
    for i = 1, maxSteps do
        local upY = clamp(y - (i * step), minY, maxY)
        if not overlapsExistingPatrols(x, upY, droneSize, droneSize, padding) then
            return upY
        end

        local downY = clamp(y + (i * step), minY, maxY)
        if not overlapsExistingPatrols(x, downY, droneSize, droneSize, padding) then
            return downY
        end
    end

    return y
end

local function buildPatrolRouteX(w, droneSize, lane, opts, rng)
    local minX = 8
    local maxX = math.max(minX, w - droneSize - 8)
    local routeMinFrac = opts.patrolRouteMinFraction or DEFAULT_PATROL_ROUTE_MIN_FRACTION
    local routeMaxFrac = opts.patrolRouteMaxFraction or DEFAULT_PATROL_ROUTE_MAX_FRACTION
    local minRouteLen = math.max(droneSize * 2, math.floor(w * routeMinFrac))
    local maxRouteLen = math.max(minRouteLen, math.floor(w * routeMaxFrac))
    local routeLen = rng(minRouteLen, maxRouteLen)
    local anchorX = math.floor(w * (0.1 + (0.8 * lane)))
    local jitterX = math.max(24, math.floor(w * 0.12))
    local maxStartX = math.max(minX, maxX - routeLen)
    local x1 = clamp(anchorX - math.floor(routeLen * 0.5) + rng(-jitterX, jitterX), minX, maxStartX)
    local x2 = x1 + routeLen
    if x2 > maxX then
        x2 = maxX
        x1 = math.max(minX, x2 - routeLen)
    end
    return x1, x2
end

local function spawnPatrolDrone(w, h, droneSize, index, total, opts)
    -- Spread patrols vertically with randomization, while keeping distance from repair nodes.
    local x1 = 8
    local x2 = math.max(x1 + droneSize, w - droneSize - 8)
    local minY = droneSize + 8
    local maxY = math.max(minY, h - droneSize - 8)
    local rng = (love and love.math and love.math.random) or math.random
    local lane = index / (total + 1)
    x1, x2 = buildPatrolRouteX(w, droneSize, lane, opts, rng)
    local laneBaseY = math.floor(h * (0.15 + (0.7 * lane)))
    local laneJitter = math.floor(h * 0.08)
    local minDistance = opts.patrolMinDistanceToNode or DEFAULT_PATROL_NODE_MIN_DISTANCE
    local repairNodes = opts.repairNodes
    local patrolPadding = math.max(0, opts.patrolSpawnPadding or 2)
    local y = math.max(minY, math.min(maxY, laneBaseY))
    local placed = false

    for _ = 1, 60 do
        local candidateY = math.max(
            minY,
            math.min(maxY, laneBaseY + rng(-laneJitter, laneJitter))
        )
        if
            not isPatrolSpawnTooCloseToNodes(x1, candidateY, repairNodes, minDistance)
            and not overlapsRepairNodes(x1, candidateY, droneSize, droneSize, repairNodes, 4)
            and not overlapsExistingPatrols(x1, candidateY, droneSize, droneSize, patrolPadding)
        then
            y = candidateY
            placed = true
            break
        end
    end

    if not placed then
        -- Fallback search across full height if local lane jitter fails.
        for _ = 1, 60 do
            local candidateY = rng(minY, maxY)
            if
                not isPatrolSpawnTooCloseToNodes(x1, candidateY, repairNodes, minDistance)
                and not overlapsRepairNodes(x1, candidateY, droneSize, droneSize, repairNodes, 4)
                and not overlapsExistingPatrols(x1, candidateY, droneSize, droneSize, patrolPadding)
            then
                y = candidateY
                break
            end
        end
    end

    y = resolvePatrolLineY(y, minY, maxY, droneSize, repairNodes, opts)
    if
        overlapsRepairNodes(x1, y, droneSize, droneSize, repairNodes, 4)
        or overlapsExistingPatrols(x1, y, droneSize, droneSize, patrolPadding)
    then
        local foundSafe = false
        for _ = 1, 80 do
            local candidateY = rng(minY, maxY)
            if
                not doesPatrolLineCrossNodes(candidateY, droneSize, repairNodes, opts.patrolLineNodeClearance)
                and not overlapsRepairNodes(x1, candidateY, droneSize, droneSize, repairNodes, 4)
                and not overlapsExistingPatrols(x1, candidateY, droneSize, droneSize, patrolPadding)
            then
                y = candidateY
                foundSafe = true
                break
            end
        end

        if not foundSafe then
            local step = math.max(8, math.floor(droneSize * 0.5))
            for candidateY = minY, maxY, step do
                if
                    not doesPatrolLineCrossNodes(candidateY, droneSize, repairNodes, opts.patrolLineNodeClearance)
                    and not overlapsRepairNodes(x1, candidateY, droneSize, droneSize, repairNodes, 4)
                    and not overlapsExistingPatrols(x1, candidateY, droneSize, droneSize, patrolPadding)
                then
                    y = candidateY
                    break
                end
            end
        end
    end

    -- Final hard guarantee: separate patrol bodies from each other even if node-friendly searches fail.
    y = resolvePatrolOverlapY(x1, y, droneSize, minY, maxY, patrolPadding)

    drones[#drones + 1] = PatrolDrone.new({
        x = x1,
        y = y,
        x1 = x1,
        y1 = y,
        x2 = x2,
        y2 = y,
        size = droneSize,
        speed = opts.patrolSpeed or DEFAULT_PATROL_SPEED,
        damage = opts.patrolDamage or DEFAULT_PATROL_DAMAGE,
        invulDuration = opts.enemyInvulDuration or 1.5,
        color = { 0.95, 0.4, 0.25, 1.0 }
    })
end

local function spawnHunterDrone(w, h, hunterSize, index, total, opts)
    -- Spread hunters across the lower half so they pressure approach angles.
    local rng = (love and love.math and love.math.random) or math.random
    local repairNodes = opts.repairNodes
    local lane = index / (total + 1)
    local minX = 8
    local maxX = math.max(minX, w - hunterSize - 8)
    local minY = 8
    local maxY = math.max(minY, h - hunterSize - 8)
    local laneX = math.floor(w * (0.15 + (0.7 * lane)))
    local laneY = math.floor(h * (0.62 + (0.18 * ((index % 2) * 2 - 1))))
    local x = clamp(laneX, minX, maxX)
    local y = clamp(laneY, minY, maxY)

    local function isSafeSpawn(candidateX, candidateY)
        return not overlapsRepairNodes(candidateX, candidateY, hunterSize, hunterSize, repairNodes, 6)
    end

    if not isSafeSpawn(x, y) then
        local placed = false
        local jitterX = math.max(24, math.floor(w * 0.12))
        local jitterY = math.max(24, math.floor(h * 0.12))

        for _ = 1, 90 do
            local candidateX = clamp(laneX + rng(-jitterX, jitterX), minX, maxX)
            local candidateY = clamp(laneY + rng(-jitterY, jitterY), minY, maxY)
            if isSafeSpawn(candidateX, candidateY) then
                x = candidateX
                y = candidateY
                placed = true
                break
            end
        end

        if not placed then
            for _ = 1, 140 do
                local candidateX = rng(minX, maxX)
                local candidateY = rng(minY, maxY)
                if isSafeSpawn(candidateX, candidateY) then
                    x = candidateX
                    y = candidateY
                    placed = true
                    break
                end
            end
        end

        if not placed then
            local step = math.max(8, math.floor(hunterSize * 0.5))
            for candidateY = minY, maxY, step do
                if placed then
                    break
                end
                for candidateX = minX, maxX, step do
                    if isSafeSpawn(candidateX, candidateY) then
                        x = candidateX
                        y = candidateY
                        placed = true
                        break
                    end
                end
            end
        end
    end

    hunters[#hunters + 1] = HunterDrone.new({
        x = x,
        y = y,
        size = hunterSize,
        speed = opts.hunterSpeed or DEFAULT_HUNTER_SPEED,
        visionRange = opts.hunterVisionRange or DEFAULT_HUNTER_VISION,
        dotThreshold = opts.hunterDotThreshold or 0.5,
        damage = opts.hunterDamage or DEFAULT_HUNTER_DAMAGE,
        invulDuration = opts.enemyInvulDuration or 1.5,
        color = { 0.2, 0.85, 1.0, 1.0 },
        coneColor = { 0.2, 0.8, 1.0, 0.18 },
        lineColor = { 0.9, 0.9, 1.0, 0.7 },
        lookColor = { 0.2, 0.9, 1.0, 0.9 }
    })
end

function EnemySystem.reset(playWidth, playHeight, opts)
    -- Rebuilds enemy lists using scaled counts/damage values provided by caller.
    opts = opts or {}
    EnemySystem.resetPatrols(playWidth, playHeight, opts)
    EnemySystem.resetHunters(playWidth, playHeight, opts)
end

function EnemySystem.resetPatrols(playWidth, playHeight, opts)
    -- Rebuild patrol drones first so other systems can consume finalized lanes.
    opts = opts or {}
    drones = {}
    hunters = {}

    local w = playWidth or 0
    local h = playHeight or 0
    local droneSize = opts.droneSize or DEFAULT_DRONE_SIZE
    local patrolCount = math.max(1, math.floor(opts.patrolCount or 1))

    for i = 1, patrolCount do
        spawnPatrolDrone(w, h, droneSize, i, patrolCount, opts)
    end
end

function EnemySystem.resetHunters(playWidth, playHeight, opts)
    -- Spawn/rebuild hunters without touching finalized patrol list.
    opts = opts or {}
    hunters = {}

    local w = playWidth or 0
    local h = playHeight or 0
    local hunterSize = opts.hunterSize or DEFAULT_HUNTER_SIZE
    local hunterCount = math.max(1, math.floor(opts.hunterCount or 1))

    for i = 1, hunterCount do
        spawnHunterDrone(w, h, hunterSize, i, hunterCount, opts)
    end
end

function EnemySystem.getPatrolLanes()
    -- Snapshot finalized horizontal patrol segments for systems that must avoid those lanes.
    local lanes = {}
    for _, drone in ipairs(drones) do
        local x1 = drone.x1 or drone.x or 0
        local x2 = drone.x2 or x1
        local y1 = drone.y1 or drone.y or 0
        local y2 = drone.y2 or y1
        lanes[#lanes + 1] = {
            x1 = math.min(x1, x2),
            x2 = math.max(x1, x2),
            y = (y1 + y2) * 0.5,
            thickness = math.max(drone.height or 0, drone.width or 0, 1)
        }
    end
    return lanes
end

function EnemySystem.update(player, dt, playerSize)
    -- Advances enemy movement/AI while caching previous positions for collision correction.
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
    -- Keeps player/enemy bodies separated and returns contact events for damage processing.
    local _, droneHits = CollisionSystem.stopPlayerOnEnemies(drones, player, playerSize)
    local _, hunterHits = CollisionSystem.stopPlayerOnEnemies(hunters, player, playerSize)
    CollisionSystem.stopEnemiesOnPlayer(drones, player, playerSize)
    CollisionSystem.stopEnemiesOnPlayer(hunters, player, playerSize)

    local hitEvents = {}
    for _, event in ipairs(droneHits or {}) do
        hitEvents[#hitEvents + 1] = event
    end
    for _, event in ipairs(hunterHits or {}) do
        hitEvents[#hitEvents + 1] = event
    end
    return hitEvents
end

function EnemySystem.resolveObstacleCollisions(obstacle)
    -- Resolves enemy overlap against a single obstacle rectangle.
    CollisionSystem.stopEnemiesOnObstacle(drones, obstacle)
    CollisionSystem.stopEnemiesOnObstacle(hunters, obstacle)
end

function EnemySystem.draw(player, playerSize)
    -- Draw order keeps patrol drones below hunter debug/cone overlay output.
    for _, drone in ipairs(drones) do
        drone:draw()
    end
    for _, hunter in ipairs(hunters) do
        hunter:draw(player, playerSize or 35)
    end
end

function EnemySystem.getDrones()
    -- Accessor used by ability/collision systems.
    return drones
end

function EnemySystem.getHunters()
    -- Accessor used by ability/collision systems.
    return hunters
end

return EnemySystem

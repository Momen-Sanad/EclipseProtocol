-- Owns enemy spawning, per-frame updates, collision hooks, and rendering.
local CollisionSystem = require("src/systems/collision_system")
local PatrolDrone = require("src/entities/patrol_drone")
local HunterDrone = require("src/entities/hunter_drone")
local MathUtils = require("src/utils/math_utils")
local SearchUtils = require("src/utils/search_utils")

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
local DEFAULT_ENEMY_SPAWN_PADDING = 4

local function buildConfig(opts)
    local raw = opts or {}
    return {
        droneSize = raw.droneSize or raw.patrolSize or raw.enemySize or DEFAULT_DRONE_SIZE,
        hunterSize = raw.hunterSize or raw.enemySize or DEFAULT_HUNTER_SIZE,
        patrolCount = math.max(1, math.floor(raw.patrolCount or raw.droneCount or 1)),
        hunterCount = math.max(1, math.floor(raw.hunterCount or raw.enemyCount or 1)),
        patrolSpeed = raw.patrolSpeed or DEFAULT_PATROL_SPEED,
        hunterSpeed = raw.hunterSpeed or DEFAULT_HUNTER_SPEED,
        hunterVisionRange = raw.hunterVisionRange or DEFAULT_HUNTER_VISION,
        hunterDotThreshold = raw.hunterDotThreshold or 0.5,
        patrolDamage = raw.patrolDamage or DEFAULT_PATROL_DAMAGE,
        hunterDamage = raw.hunterDamage or DEFAULT_HUNTER_DAMAGE,
        enemyInvulDuration = raw.enemyInvulDuration or raw.invulDuration or 1.5,
        repairNodes = raw.repairNodes or raw.powerNodes or raw.nodes,
        patrolMinDistanceToNode = raw.patrolMinDistanceToNode or DEFAULT_PATROL_NODE_MIN_DISTANCE,
        patrolLineNodeClearance = raw.patrolLineNodeClearance or DEFAULT_PATROL_LINE_NODE_CLEARANCE,
        patrolRouteMinFraction = raw.patrolRouteMinFraction or DEFAULT_PATROL_ROUTE_MIN_FRACTION,
        patrolRouteMaxFraction = raw.patrolRouteMaxFraction or DEFAULT_PATROL_ROUTE_MAX_FRACTION,
        patrolSpawnPadding = math.max(0, raw.patrolSpawnPadding or 2),
        hunterSpawnPadding = math.max(0, raw.hunterSpawnPadding or raw.enemySpawnPadding or DEFAULT_ENEMY_SPAWN_PADDING),
        crossSpawnPadding = math.max(0, raw.crossSpawnPadding or raw.enemySpawnPadding or DEFAULT_ENEMY_SPAWN_PADDING),
        playerSpawn = raw.playerSpawn,
        playerSpawnSize = math.max(1, math.floor(raw.playerSpawnSize or raw.playerSize or 35)),
        playerSpawnSafetyPadding = math.max(0, raw.playerSpawnSafetyPadding or 0),
        protectedZones = raw.protectedZones,
        protectedZonePadding = math.max(0, raw.protectedZonePadding or 0)
    }
end

local function overlapsProtectedZones(x, y, w, h, zones, padding)
    if type(zones) ~= "table" or #zones == 0 then
        return false
    end

    local pad = math.max(0, padding or 0)
    for _, zone in ipairs(zones) do
        local zx = (zone.x or 0) - pad
        local zy = (zone.y or 0) - pad
        local zw = (zone.width or zone.size or 0) + (pad * 2)
        local zh = (zone.height or zone.size or 0) + (pad * 2)
        if CollisionSystem.overlaps(x, y, w, h, zx, zy, zw, zh) then
            return true
        end
    end

    return false
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
        if CollisionSystem.overlaps(x, y, w, h, nx, ny, nw, nh) then
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
        if CollisionSystem.overlaps(px, py, pw, ph, dx, dy, dw, dh) then
            return true
        end
    end

    return false
end

local function overlapsExistingHunters(x, y, w, h, padding)
    local pad = math.max(0, padding or 0)
    local px = (x or 0) - pad
    local py = (y or 0) - pad
    local pw = (w or 0) + (pad * 2)
    local ph = (h or 0) + (pad * 2)

    for _, hunter in ipairs(hunters) do
        local hx = (hunter.x or 0) - pad
        local hy = (hunter.y or 0) - pad
        local hw = (hunter.width or w or 0) + (pad * 2)
        local hh = (hunter.height or h or 0) + (pad * 2)
        if CollisionSystem.overlaps(px, py, pw, ph, hx, hy, hw, hh) then
            return true
        end
    end

    return false
end

local function doesPatrolRouteThreatenPlayerSpawn(x1, x2, y, droneSize, playerSpawn, playerSize)
    if type(playerSpawn) ~= "table" then
        return false
    end

    local size = math.max(1, math.floor(playerSize or 35))
    local playerCenterX = (playerSpawn.x or 0) + (size * 0.5)
    local playerCenterY = (playerSpawn.y or 0) + (size * 0.5)
    local patrolCenterY = (y or 0) + ((droneSize or 0) * 0.5)
    local lineBand = math.max(size * 0.5, (droneSize or size) * 0.55)
    if math.abs(playerCenterY - patrolCenterY) > lineBand then
        return false
    end

    local minX = math.min(x1 or 0, x2 or 0) - (size * 0.35)
    local maxX = math.max(x1 or 0, x2 or 0) + (droneSize or size) + (size * 0.35)
    return playerCenterX >= minX and playerCenterX <= maxX
end

local function hunterCanImmediatelyDetectPlayerSpawn(x, y, hunterSize, visionRange, playerSpawn, playerSize, extraPadding)
    if type(playerSpawn) ~= "table" then
        return false
    end

    local spawnSize = math.max(1, math.floor(playerSize or 35))
    local hx, hy = MathUtils.rectCenter(x or 0, y or 0, hunterSize or 0, hunterSize or 0)
    local px, py = MathUtils.rectCenter(playerSpawn.x or 0, playerSpawn.y or 0, spawnSize, spawnSize)
    local range = math.max(0, visionRange or DEFAULT_HUNTER_VISION) + (spawnSize * 0.35) + math.max(0, extraPadding or 0)
    local rangeSq = range * range
    return MathUtils.distanceSquared(hx, hy, px, py) <= rangeSq
end

local function hunterVisionThreatensProtectedZones(x, y, hunterSize, visionRange, zones, padding)
    if type(zones) ~= "table" or #zones == 0 then
        return false
    end

    local hx, hy = MathUtils.rectCenter(x or 0, y or 0, hunterSize or 0, hunterSize or 0)
    local pad = math.max(0, padding or 0)
    local range = math.max(0, visionRange or DEFAULT_HUNTER_VISION)
    local rangeSq = range * range

    for _, zone in ipairs(zones) do
        local zx = (zone.x or 0) - pad
        local zy = (zone.y or 0) - pad
        local zw = (zone.width or zone.size or 0) + (pad * 2)
        local zh = (zone.height or zone.size or 0) + (pad * 2)
        local closestX = MathUtils.clamp(hx, zx, zx + zw)
        local closestY = MathUtils.clamp(hy, zy, zy + zh)
        if MathUtils.distanceSquared(hx, hy, closestX, closestY) <= rangeSq then
            return true
        end
    end

    return false
end

local function resolveLookAwayFromPlayerSpawn(x, y, bodySize, playerSpawn, playerSize)
    if type(playerSpawn) ~= "table" then
        return 1, 0
    end

    local spawnSize = math.max(1, math.floor(playerSize or 35))
    local cx, cy = MathUtils.rectCenter(x or 0, y or 0, bodySize or 0, bodySize or 0)
    local px, py = MathUtils.rectCenter(playerSpawn.x or 0, playerSpawn.y or 0, spawnSize, spawnSize)
    local dx = cx - px
    local dy = cy - py
    local distSq = (dx * dx) + (dy * dy)
    if distSq <= 0 then
        return 1, 0
    end
    local distance = math.sqrt(distSq)
    return dx / distance, dy / distance
end

local function getNodeCenter(node)
    return MathUtils.rectCenter(node.x or 0, node.y or 0, node.width or 0, node.height or 0)
end

local function isPatrolSpawnTooCloseToNodes(x, y, repairNodes, minDistance)
    if type(repairNodes) ~= "table" or #repairNodes == 0 then
        return false
    end

    local threshold = math.max(0, minDistance or 0)
    local thresholdSq = threshold * threshold
    for _, node in ipairs(repairNodes) do
        local nx, ny = getNodeCenter(node)
        if MathUtils.distanceSquared(x, y, nx, ny) < thresholdSq then
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
        local upY = MathUtils.clamp(y - (i * step), minY, maxY)
        if not overlapsExistingPatrols(x, upY, droneSize, droneSize, padding) then
            return upY
        end

        local downY = MathUtils.clamp(y + (i * step), minY, maxY)
        if not overlapsExistingPatrols(x, downY, droneSize, droneSize, padding) then
            return downY
        end
    end

    return y
end

local function buildPatrolRouteX(minX, maxX, droneSize, lane, opts, rng)
    local safeMinX = minX or 8
    local safeMaxX = math.max(safeMinX, maxX or safeMinX)
    local spanX = math.max(1, safeMaxX - safeMinX)
    local routeMinFrac = opts.patrolRouteMinFraction or DEFAULT_PATROL_ROUTE_MIN_FRACTION
    local routeMaxFrac = opts.patrolRouteMaxFraction or DEFAULT_PATROL_ROUTE_MAX_FRACTION
    local minRouteLen = math.max(droneSize * 2, math.floor(spanX * routeMinFrac))
    local maxRouteLen = math.max(minRouteLen, math.floor(spanX * routeMaxFrac))
    minRouteLen = math.min(minRouteLen, spanX)
    maxRouteLen = math.min(maxRouteLen, spanX)
    local routeLen = rng(minRouteLen, maxRouteLen)
    local anchorX = safeMinX + math.floor(spanX * (0.1 + (0.8 * lane)))
    local jitterX = math.max(18, math.floor(spanX * 0.12))
    local maxStartX = math.max(safeMinX, safeMaxX - routeLen)
    local x1 = MathUtils.clamp(anchorX - math.floor(routeLen * 0.5) + rng(-jitterX, jitterX), safeMinX, maxStartX)
    local x2 = x1 + routeLen
    if x2 > safeMaxX then
        x2 = safeMaxX
        x1 = math.max(safeMinX, x2 - routeLen)
    end
    return x1, x2
end

local function spawnPatrolDrone(w, h, droneSize, index, total, opts)
    -- Spread patrols vertically with randomization, while keeping distance from repair nodes.
    local patrolBounds = opts.patrolSpawnBounds or opts.spawnBounds or {}
    local minX = math.max(8, math.floor(patrolBounds.minX or 8))
    local maxX = patrolBounds.maxX and math.floor(patrolBounds.maxX - droneSize) or math.floor(w - droneSize - 8)
    maxX = math.max(minX, math.min(math.max(minX, w - droneSize), maxX))
    local minY = math.max(8, math.floor(patrolBounds.minY or (droneSize + 8)))
    local maxY = patrolBounds.maxY and math.floor(patrolBounds.maxY - droneSize) or math.floor(h - droneSize - 8)
    maxY = math.max(minY, math.min(math.max(minY, h - droneSize), maxY))
    local x1 = minX
    local x2 = math.max(x1 + droneSize, maxX)
    local rng = (love and love.math and love.math.random) or math.random
    local lane = index / (total + 1)
    x1, x2 = buildPatrolRouteX(minX, maxX, droneSize, lane, opts, rng)
    local spanY = math.max(1, maxY - minY)
    local laneBaseY = minY + math.floor(spanY * (0.15 + (0.7 * lane)))
    local laneJitter = math.max(8, math.floor(spanY * 0.08))
    local minDistance = opts.patrolMinDistanceToNode or DEFAULT_PATROL_NODE_MIN_DISTANCE
    local repairNodes = opts.repairNodes
    local patrolPadding = math.max(0, opts.patrolSpawnPadding or 2)
    local playerSpawn = opts.playerSpawn
    local playerSpawnSize = opts.playerSpawnSize or 35
    local protectedZones = opts.protectedZones
    local protectedZonePadding = opts.protectedZonePadding or 0
    local y = math.max(minY, math.min(maxY, laneBaseY))
    local function isRouteSafeAtY(candidateY)
        return
            not isPatrolSpawnTooCloseToNodes(x1, candidateY, repairNodes, minDistance)
            and not doesPatrolLineCrossNodes(candidateY, droneSize, repairNodes, opts.patrolLineNodeClearance)
            and not overlapsRepairNodes(x1, candidateY, droneSize, droneSize, repairNodes, 4)
            and not overlapsExistingPatrols(x1, candidateY, droneSize, droneSize, patrolPadding)
            and not overlapsProtectedZones(x1, candidateY, droneSize, droneSize, protectedZones, protectedZonePadding)
            and not doesPatrolRouteThreatenPlayerSpawn(x1, x2, candidateY, droneSize, playerSpawn, playerSpawnSize)
    end

    local function isBodySafeAtY(candidateY)
        return
            not isPatrolSpawnTooCloseToNodes(x1, candidateY, repairNodes, minDistance)
            and not overlapsRepairNodes(x1, candidateY, droneSize, droneSize, repairNodes, 4)
            and not overlapsExistingPatrols(x1, candidateY, droneSize, droneSize, patrolPadding)
            and not overlapsProtectedZones(x1, candidateY, droneSize, droneSize, protectedZones, protectedZonePadding)
            and not doesPatrolRouteThreatenPlayerSpawn(x1, x2, candidateY, droneSize, playerSpawn, playerSpawnSize)
    end

    local jitterMinY = math.max(minY, laneBaseY - laneJitter)
    local jitterMaxY = math.min(maxY, laneBaseY + laneJitter)
    local jitterY = SearchUtils.findRandomValue(jitterMinY, jitterMaxY, 60, isBodySafeAtY, rng)
    if jitterY ~= nil then
        y = jitterY
    else
        -- Fallback search across full height if local lane jitter fails.
        local fallbackY = SearchUtils.findRandomValue(minY, maxY, 60, isBodySafeAtY, rng)
        if fallbackY ~= nil then
            y = fallbackY
        end
    end

    y = resolvePatrolLineY(y, minY, maxY, droneSize, repairNodes, opts)
    if not isRouteSafeAtY(y) then
        local resolvedY = SearchUtils.findRandomThenGridValue(
            minY,
            maxY,
            80,
            math.max(8, math.floor(droneSize * 0.5)),
            isRouteSafeAtY,
            rng
        )
        if resolvedY ~= nil then
            y = resolvedY
        end
    end

    -- Final hard guarantee: separate patrol bodies from each other even if node-friendly searches fail.
    y = resolvePatrolOverlapY(x1, y, droneSize, minY, maxY, patrolPadding)
    if not isRouteSafeAtY(y) then
        local strictY = SearchUtils.findGridValue(
            minY,
            maxY,
            math.max(8, math.floor(droneSize * 0.5)),
            isRouteSafeAtY
        )
        if strictY ~= nil then
            y = strictY
        end
    end

    if overlapsExistingPatrols(x1, y, droneSize, droneSize, patrolPadding) then
        return
    end
    if doesPatrolRouteThreatenPlayerSpawn(x1, x2, y, droneSize, playerSpawn, playerSpawnSize) then
        return
    end

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
    local hunterPadding = math.max(0, opts.hunterSpawnPadding or DEFAULT_ENEMY_SPAWN_PADDING)
    local crossPadding = math.max(0, opts.crossSpawnPadding or DEFAULT_ENEMY_SPAWN_PADDING)
    local playerSpawn = opts.playerSpawn
    local playerSpawnSize = opts.playerSpawnSize or 35
    local playerSpawnSafetyPadding = opts.playerSpawnSafetyPadding or 0
    local protectedZones = opts.protectedZones
    local protectedZonePadding = opts.protectedZonePadding or 0
    local hunterVisionRange = opts.hunterVisionRange or DEFAULT_HUNTER_VISION
    local lane = index / (total + 1)
    local hunterBounds = opts.hunterSpawnBounds or opts.spawnBounds or {}
    local minX = math.max(8, math.floor(hunterBounds.minX or 8))
    local maxX = hunterBounds.maxX and math.floor(hunterBounds.maxX - hunterSize) or math.floor(w - hunterSize - 8)
    maxX = math.max(minX, math.min(math.max(minX, w - hunterSize), maxX))
    local minY = math.max(8, math.floor(hunterBounds.minY or 8))
    local maxY = hunterBounds.maxY and math.floor(hunterBounds.maxY - hunterSize) or math.floor(h - hunterSize - 8)
    maxY = math.max(minY, math.min(math.max(minY, h - hunterSize), maxY))
    local spanX = math.max(1, maxX - minX)
    local spanY = math.max(1, maxY - minY)
    local laneX = minX + math.floor(spanX * (0.15 + (0.7 * lane)))
    local laneY = minY + math.floor(spanY * (0.62 + (0.18 * ((index % 2) * 2 - 1))))
    local x = MathUtils.clamp(laneX, minX, maxX)
    local y = MathUtils.clamp(laneY, minY, maxY)

    local function isSafeSpawn(candidateX, candidateY)
        return
            not overlapsRepairNodes(candidateX, candidateY, hunterSize, hunterSize, repairNodes, 6)
            and not overlapsExistingHunters(candidateX, candidateY, hunterSize, hunterSize, hunterPadding)
            and not overlapsExistingPatrols(candidateX, candidateY, hunterSize, hunterSize, crossPadding)
            and not overlapsProtectedZones(candidateX, candidateY, hunterSize, hunterSize, protectedZones, protectedZonePadding)
            and not hunterVisionThreatensProtectedZones(
                candidateX,
                candidateY,
                hunterSize,
                hunterVisionRange,
                protectedZones,
                protectedZonePadding
            )
            and not hunterCanImmediatelyDetectPlayerSpawn(
                candidateX,
                candidateY,
                hunterSize,
                hunterVisionRange,
                playerSpawn,
                playerSpawnSize,
                playerSpawnSafetyPadding
            )
    end

    if not isSafeSpawn(x, y) then
        local jitterX = math.max(24, math.floor(w * 0.12))
        local jitterY = math.max(24, math.floor(h * 0.12))
        local jitterCandidateX, jitterCandidateY = SearchUtils.findRandom(
            {
                minX = MathUtils.clamp(laneX - jitterX, minX, maxX),
                maxX = MathUtils.clamp(laneX + jitterX, minX, maxX),
                minY = MathUtils.clamp(laneY - jitterY, minY, maxY),
                maxY = MathUtils.clamp(laneY + jitterY, minY, maxY)
            },
            90,
            isSafeSpawn,
            rng
        )

        if jitterCandidateX ~= nil and jitterCandidateY ~= nil then
            x = jitterCandidateX
            y = jitterCandidateY
        else
            local fallbackX, fallbackY = SearchUtils.findRandomThenGrid(
                { minX = minX, maxX = maxX, minY = minY, maxY = maxY },
                140,
                math.max(8, math.floor(hunterSize * 0.5)),
                isSafeSpawn,
                { rng = rng }
            )
            if fallbackX ~= nil and fallbackY ~= nil then
                x = fallbackX
                y = fallbackY
            end
        end
    end

    if not isSafeSpawn(x, y) then
        local strictX, strictY = SearchUtils.findGrid(
            { minX = minX, maxX = maxX, minY = minY, maxY = maxY },
            math.max(8, math.floor(hunterSize * 0.5)),
            isSafeSpawn,
            { randomStart = true, wrap = true, rng = rng }
        )
        if strictX ~= nil and strictY ~= nil then
            x = strictX
            y = strictY
        end
    end

    if not isSafeSpawn(x, y) then
        -- Fail-safe: enforce non-overlap/safe-spawn guarantees even if a dense room reduces enemy count.
        return
    end

    local lookX, lookY = resolveLookAwayFromPlayerSpawn(x, y, hunterSize, playerSpawn, playerSpawnSize)

    hunters[#hunters + 1] = HunterDrone.new({
        x = x,
        y = y,
        lookX = lookX,
        lookY = lookY,
        size = hunterSize,
        speed = opts.hunterSpeed or DEFAULT_HUNTER_SPEED,
        visionRange = hunterVisionRange,
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
    local cfg = buildConfig(opts)
    EnemySystem.resetPatrols(playWidth, playHeight, cfg)
    EnemySystem.resetHunters(playWidth, playHeight, cfg)
end

function EnemySystem.resetPatrols(playWidth, playHeight, opts)
    -- Rebuild patrol drones first so other systems can consume finalized lanes.
    local cfg = buildConfig(opts)
    drones = {}
    hunters = {}

    local w = playWidth or 0
    local h = playHeight or 0
    local droneSize = cfg.droneSize
    local patrolCount = cfg.patrolCount

    for i = 1, patrolCount do
        spawnPatrolDrone(w, h, droneSize, i, patrolCount, cfg)
    end
end

function EnemySystem.resetHunters(playWidth, playHeight, opts)
    -- Spawn/rebuild hunters without touching finalized patrol list.
    local cfg = buildConfig(opts)
    hunters = {}

    local w = playWidth or 0
    local h = playHeight or 0
    local hunterSize = cfg.hunterSize
    local hunterCount = cfg.hunterCount

    for i = 1, hunterCount do
        spawnHunterDrone(w, h, hunterSize, i, hunterCount, cfg)
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
        local bodyW = drone.width or 0
        local bodyH = drone.height or 0
        local left = math.min(x1, x2)
        local right = math.max(x1, x2) + bodyW
        local top = math.min(y1, y2)
        local bottom = math.max(y1, y2) + bodyH
        lanes[#lanes + 1] = {
            x1 = math.min(x1, x2),
            x2 = math.max(x1, x2),
            y = (top + bottom) * 0.5,
            thickness = math.max(bottom - top, 1),
            left = left,
            right = right,
            top = top,
            bottom = bottom
        }
    end
    return lanes
end

function EnemySystem.update(player, dt, playerSize, worldBounds)
    -- Advances enemy movement/AI while caching previous positions for collision correction.
    local minX = worldBounds and worldBounds.minX or nil
    local minY = worldBounds and worldBounds.minY or nil
    local maxX = worldBounds and worldBounds.maxX or nil
    local maxY = worldBounds and worldBounds.maxY or nil

    for _, drone in ipairs(drones) do
        drone.prevX = drone.x
        drone.prevY = drone.y
        drone:update(dt)
    end

    for _, hunter in ipairs(hunters) do
        hunter.prevX = hunter.x
        hunter.prevY = hunter.y
        hunter:update(player, dt, playerSize)

        -- Keep hunters inside the play area even when reroute logic chooses aggressive offsets.
        if minX ~= nil and maxX ~= nil then
            local bodyW = hunter.width or 0
            local hunterMaxX = math.max(minX, maxX - bodyW)
            hunter.x = MathUtils.clamp(hunter.x or 0, minX, hunterMaxX)
        end
        if minY ~= nil and maxY ~= nil then
            local bodyH = hunter.height or 0
            local hunterMaxY = math.max(minY, maxY - bodyH)
            hunter.y = MathUtils.clamp(hunter.y or 0, minY, hunterMaxY)
        end
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

function EnemySystem.syncWorld(world)
    if not world or not world.entities then
        return
    end
    world.entities.drones = drones
    world.entities.hunters = hunters
end

function EnemySystem.resetWorld(world, playWidth, playHeight, opts)
    EnemySystem.reset(playWidth, playHeight, opts)
    EnemySystem.syncWorld(world)
end

return EnemySystem

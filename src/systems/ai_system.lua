-- Enemy AI / movement intent logic.
-- Keeps behavior decisions out of entity constructors and animation code.
local Kinematics = require("src/utils/kinematics")
local MathUtils = require("src/utils/math_utils")
local CollisionSystem = require("src/systems/collision_system")

local AISystem = {}

AISystem.HUNTER_STATES = {
    IDLE = "idle",
    CHASE = "chase"
}

local function updateStunState(enemy, dt)
    local timer = math.max(0, (enemy and enemy.stunTimer or 0) - (dt or 0))
    enemy.stunTimer = timer
    if timer > 0 then
        enemy.isStunned = true
        enemy.pauseTimer = math.max(enemy.pauseTimer or 0, timer)
    else
        enemy.isStunned = false
    end
end

local function getExpandedBlockedNodeBounds(enemy, blockedNode)
    local ox = blockedNode and blockedNode.x or 0
    local oy = blockedNode and blockedNode.y or 0
    local ow = blockedNode and blockedNode.width or 0
    local oh = blockedNode and blockedNode.height or 0
    local halfW = (enemy and enemy.width or 0) * 0.5
    local halfH = (enemy and enemy.height or 0) * 0.5
    local pad = math.max(8, math.floor(math.max(halfW, halfH) * 0.15))
    local rx = ox - halfW - pad
    local ry = oy - halfH - pad
    local rw = ow + ((halfW + pad) * 2)
    local rh = oh + ((halfH + pad) * 2)
    return rx, ry, rw, rh
end

local function hasClearPathToPlayer(enemy, playerX, playerY, blockedNode)
    if not blockedNode then
        return true
    end

    local cx = (enemy.x or 0) + ((enemy.width or 0) / 2)
    local cy = (enemy.y or 0) + ((enemy.height or 0) / 2)
    local rx, ry, rw, rh = getExpandedBlockedNodeBounds(enemy, blockedNode)
    return not MathUtils.segmentIntersectsAabb(cx, cy, playerX, playerY, rx, ry, rw, rh)
end

local function chooseFallbackReroute(enemy, targetX, targetY)
    local cx = (enemy.x or 0) + ((enemy.width or 0) / 2)
    local cy = (enemy.y or 0) + ((enemy.height or 0) / 2)
    local step = math.max(enemy.width or 0, enemy.height or 0, 36)

    if math.abs((targetX or cx) - cx) >= math.abs((targetY or cy) - cy) then
        local dirY = ((targetY or cy) >= cy) and 1 or -1
        return "y", dirY, step
    end

    local dirX = ((targetX or cx) >= cx) and 1 or -1
    return "x", dirX, step
end

local function chooseNodeReroute(enemy, blockedNode, targetX, targetY)
    if not blockedNode then
        return chooseFallbackReroute(enemy, targetX, targetY)
    end

    local ew = enemy.width or 0
    local eh = enemy.height or 0
    local halfW = ew / 2
    local halfH = eh / 2
    local cx = (enemy.x or 0) + halfW
    local cy = (enemy.y or 0) + halfH
    local ox = blockedNode.x or 0
    local oy = blockedNode.y or 0
    local ow = blockedNode.width or 0
    local oh = blockedNode.height or 0
    local nodeCx = ox + (ow * 0.5)
    local nodeCy = oy + (oh * 0.5)
    local cornerBuffer = enemy.rerouteCornerBuffer or 16
    local nodeSpan = math.max(ow, oh, ew, eh, 40)
    local step = nodeSpan + math.max(18, math.floor(nodeSpan * 0.35)) + cornerBuffer
    local rx, ry, rw, rh = getExpandedBlockedNodeBounds(enemy, blockedNode)
    local candidates = {
        { axis = "x", dir = 1, x = cx + step, y = cy },
        { axis = "x", dir = -1, x = cx - step, y = cy },
        { axis = "y", dir = 1, x = cx, y = cy + step },
        { axis = "y", dir = -1, x = cx, y = cy - step }
    }

    local bestAxis = nil
    local bestDir = nil
    local bestScore = math.huge
    for _, candidate in ipairs(candidates) do
        local ex = candidate.x - halfW
        local ey = candidate.y - halfH
        if not CollisionSystem.overlaps(ex, ey, ew, eh, ox, oy, ow, oh) then
            local toTarget = MathUtils.distanceSquared(candidate.x, candidate.y, targetX, targetY)
            local clearPathFromCandidate = not MathUtils.segmentIntersectsAabb(candidate.x, candidate.y, targetX, targetY, rx, ry, rw, rh)
            local score = toTarget - (MathUtils.distanceSquared(candidate.x, candidate.y, nodeCx, nodeCy) * 0.05)
            if clearPathFromCandidate then
                score = score - 1000000
            end
            if score < bestScore then
                bestScore = score
                bestAxis = candidate.axis
                bestDir = candidate.dir
            end
        end
    end

    if bestAxis and bestDir then
        return bestAxis, bestDir, step
    end

    return chooseFallbackReroute(enemy, targetX, targetY)
end

local function getPatrolTarget(enemy)
    if enemy.forward then
        return enemy.x2, enemy.y2
    end
    return enemy.x1, enemy.y1
end

function AISystem.updatePatrol(enemy, dt)
    if not enemy then
        return
    end

    dt = dt or 0
    updateStunState(enemy, dt)

    enemy.state = enemy.state or "patrol"

    if enemy.pauseTimer and enemy.pauseTimer > 0 then
        enemy.pauseTimer = math.max(0, enemy.pauseTimer - dt)
        Kinematics.stop(enemy)
        enemy.chasing = false
        return
    end

    local tx, ty = getPatrolTarget(enemy)
    local dx = tx - enemy.x
    local dy = ty - enemy.y
    local nx, ny, dist = Kinematics.normalize(dx, dy)
    local speed = enemy.speed or 0

    if dist <= (enemy.arriveThreshold or 0) or speed <= 0 then
        enemy.x, enemy.y = tx, ty
        Kinematics.stop(enemy)
        enemy.forward = not enemy.forward
        if (enemy.pauseDuration or 0) > 0 then
            enemy.pauseTimer = enemy.pauseDuration
        end
        return
    end

    local step = speed * dt
    if step >= dist then
        enemy.x, enemy.y = tx, ty
        Kinematics.stop(enemy)
        enemy.forward = not enemy.forward
        if (enemy.pauseDuration or 0) > 0 then
            enemy.pauseTimer = enemy.pauseDuration
        end
        return
    end

    Kinematics.setVelocity(enemy, nx * speed, ny * speed)
    Kinematics.integrate(enemy, dt)
end

function AISystem.updateHunter(enemy, player, dt, playerSize)
    if not enemy then
        return
    end

    dt = dt or 0
    updateStunState(enemy, dt)

    enemy.rerouteTimer = math.max(0, (enemy.rerouteTimer or 0) - dt)
    if enemy.rerouteTimer <= 0 then
        enemy.rerouteX = nil
        enemy.rerouteY = nil
        enemy.rerouteAxis = nil
        enemy.rerouteDir = nil
        enemy.rerouteStep = nil
    end

    enemy.chaseMemoryTimer = math.max(0, (enemy.chaseMemoryTimer or 0) - dt)

    enemy.blockedNodeTimer = math.max(0, (enemy.blockedNodeTimer or 0) - dt)
    if enemy.blockedNodeTimer <= 0 then
        enemy.lastBlockedNode = nil
    end

    enemy.state = enemy.state or AISystem.HUNTER_STATES.IDLE

    if enemy.pauseTimer and enemy.pauseTimer > 0 then
        enemy.pauseTimer = enemy.pauseTimer - dt
        Kinematics.stop(enemy)
        enemy.chasing = false
        enemy.state = AISystem.HUNTER_STATES.IDLE
        enemy.detectedPlayer = false
        return
    end

    local size = playerSize or 35
    local px = (player and player.x or 0) + size / 2
    local py = (player and player.y or 0) + size / 2
    local cx = enemy.x + (enemy.width or 0) / 2
    local cy = enemy.y + (enemy.height or 0) / 2

    enemy.lastTargetX = px
    enemy.lastTargetY = py

    local toPlayerX = px - cx
    local toPlayerY = py - cy
    local playerDirX, playerDirY, playerDist = Kinematics.normalize(toPlayerX, toPlayerY)

    local inRange = playerDist <= (enemy.visionRange or 0)
    local facing = MathUtils.dot(enemy.lookX or 1, enemy.lookY or 0, playerDirX, playerDirY) >= (enemy.dotThreshold or 0.5)
    local canChase = inRange and facing

    local targetX = px
    local targetY = py
    local usingReroute = enemy.rerouteTimer > 0 and enemy.rerouteAxis ~= nil and enemy.rerouteDir ~= nil
    if usingReroute then
        local blockedNode = enemy.lastBlockedNode
        if hasClearPathToPlayer(enemy, px, py, blockedNode) then
            enemy.rerouteTimer = 0
            enemy.rerouteX = nil
            enemy.rerouteY = nil
            enemy.rerouteAxis = nil
            enemy.rerouteDir = nil
            enemy.rerouteStep = nil
            usingReroute = false
        else
            local step = enemy.rerouteStep or math.max(enemy.width or 0, enemy.height or 0, 36)
            if enemy.rerouteAxis == "x" then
                targetX = cx + (enemy.rerouteDir * step)
                targetY = cy
            else
                targetX = cx
                targetY = cy + (enemy.rerouteDir * step)
            end
            enemy.rerouteX = targetX
            enemy.rerouteY = targetY
        end
    end

    local toTargetX = targetX - cx
    local toTargetY = targetY - cy
    local dirX, dirY = Kinematics.normalize(toTargetX, toTargetY)

    if canChase or usingReroute then
        enemy.chaseMemoryTimer = math.max(enemy.chaseMemoryTimer or 0, enemy.chaseMemoryDuration or 1.1)
    end

    local hasChaseMemory = (enemy.chaseMemoryTimer or 0) > 0
    local shouldChase = canChase or usingReroute or (hasChaseMemory and inRange)

    if shouldChase then
        enemy.state = AISystem.HUNTER_STATES.CHASE
        enemy.detectedPlayer = true
        enemy.chasing = true
        Kinematics.setVelocity(enemy, dirX * (enemy.speed or 0), dirY * (enemy.speed or 0))
        enemy.lookX, enemy.lookY = dirX, dirY
        enemy.spinAngle = math.atan(enemy.lookY, enemy.lookX)
    else
        enemy.state = AISystem.HUNTER_STATES.IDLE
        enemy.detectedPlayer = false
        enemy.chasing = false
        Kinematics.stop(enemy)
        enemy.spinAngle = enemy.spinAngle or math.atan(enemy.lookY or 0, enemy.lookX or 1)
        enemy.spinAngle = enemy.spinAngle + (enemy.spinSpeed or 0) * dt
        if enemy.spinAngle > math.pi * 2 then
            enemy.spinAngle = enemy.spinAngle - math.pi * 2
        end
        enemy.lookX, enemy.lookY = MathUtils.rotate(1, 0, enemy.spinAngle)
    end

    if enemy.chasing then
        local sampleX = enemy.stuckSampleX or enemy.x or 0
        local sampleY = enemy.stuckSampleY or enemy.y or 0
        local minMove = enemy.stuckMoveEpsilon or 4
        if MathUtils.distanceSquared(enemy.x or 0, enemy.y or 0, sampleX, sampleY) <= (minMove * minMove) then
            enemy.stuckTimer = (enemy.stuckTimer or 0) + dt
        else
            enemy.stuckTimer = 0
            enemy.stuckSampleX = enemy.x
            enemy.stuckSampleY = enemy.y
        end

        if (enemy.stuckTimer or 0) >= (enemy.stuckThreshold or 0.4) then
            local rerouteAxis, rerouteDir, rerouteStep = chooseNodeReroute(enemy, enemy.lastBlockedNode, px, py)
            local rerouteX = cx
            local rerouteY = cy
            if rerouteAxis == "x" then
                rerouteX = cx + (rerouteDir * rerouteStep)
            else
                rerouteY = cy + (rerouteDir * rerouteStep)
            end
            enemy.rerouteAxis = rerouteAxis
            enemy.rerouteDir = rerouteDir
            enemy.rerouteStep = rerouteStep
            enemy.rerouteX = rerouteX
            enemy.rerouteY = rerouteY
            enemy.rerouteTimer = enemy.rerouteDuration or 0.9
            enemy.stuckTimer = 0
            enemy.stuckSampleX = enemy.x
            enemy.stuckSampleY = enemy.y

            local newDx = rerouteX - cx
            local newDy = rerouteY - cy
            local newNx, newNy = Kinematics.normalize(newDx, newDy)
            Kinematics.setVelocity(enemy, newNx * (enemy.speed or 0), newNy * (enemy.speed or 0))
            enemy.lookX, enemy.lookY = newNx, newNy
            usingReroute = true
        end
    else
        enemy.stuckTimer = 0
        enemy.stuckSampleX = enemy.x
        enemy.stuckSampleY = enemy.y
    end

    if enemy.vx ~= 0 or enemy.vy ~= 0 then
        local nx, ny = Kinematics.normalize(enemy.vx, enemy.vy)
        if nx ~= 0 or ny ~= 0 then
            enemy.lookX, enemy.lookY = nx, ny
        end
    end

    if enemy.chasing and (not usingReroute) and playerDist < 40 then
        Kinematics.stop(enemy)
        return
    end

    Kinematics.integrate(enemy, dt)
end

return AISystem

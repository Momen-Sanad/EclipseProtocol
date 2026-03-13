-- Enemy AI / movement intent logic.
-- Keeps behavior decisions out of entity constructors and animation code.
local AISystem = {}

AISystem.HUNTER_STATES = {
    IDLE = "idle",
    CHASE = "chase"
}

local function normalize(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then
        return 0, 0, 0
    end
    return dx / len, dy / len, len
end

local function dot(ax, ay, bx, by)
    return ax * bx + ay * by
end

local function rotate(dx, dy, angle)
    local c = math.cos(angle)
    local s = math.sin(angle)
    return dx * c - dy * s, dx * s + dy * c
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

    enemy.state = enemy.state or "patrol"

    if enemy.pauseTimer and enemy.pauseTimer > 0 then
        enemy.pauseTimer = math.max(0, enemy.pauseTimer - dt)
        enemy.vx = 0
        enemy.vy = 0
        enemy.chasing = false
        return
    end

    local tx, ty = getPatrolTarget(enemy)
    local dx = tx - enemy.x
    local dy = ty - enemy.y
    local nx, ny, dist = normalize(dx, dy)
    local speed = enemy.speed or 0

    if dist <= (enemy.arriveThreshold or 0) or speed <= 0 then
        enemy.x, enemy.y = tx, ty
        enemy.vx, enemy.vy = 0, 0
        enemy.forward = not enemy.forward
        if (enemy.pauseDuration or 0) > 0 then
            enemy.pauseTimer = enemy.pauseDuration
        end
        return
    end

    local step = speed * dt
    if step >= dist then
        enemy.x, enemy.y = tx, ty
        enemy.vx, enemy.vy = 0, 0
        enemy.forward = not enemy.forward
        if (enemy.pauseDuration or 0) > 0 then
            enemy.pauseTimer = enemy.pauseDuration
        end
        return
    end

    enemy.vx = nx * speed
    enemy.vy = ny * speed
    enemy.x = enemy.x + enemy.vx * dt
    enemy.y = enemy.y + enemy.vy * dt
end

function AISystem.updateHunter(enemy, player, dt, playerSize)
    if not enemy then
        return
    end

    dt = dt or 0

    enemy.state = enemy.state or AISystem.HUNTER_STATES.IDLE

    if enemy.pauseTimer and enemy.pauseTimer > 0 then
        enemy.pauseTimer = enemy.pauseTimer - dt
        enemy.vx, enemy.vy = 0, 0
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

    local toPx = px - cx
    local toPy = py - cy
    local dirX, dirY, dist = normalize(toPx, toPy)

    local inRange = dist <= (enemy.visionRange or 0)
    local facing = dot(enemy.lookX or 1, enemy.lookY or 0, dirX, dirY) >= (enemy.dotThreshold or 0.5)
    local canChase = inRange and facing

    if canChase then
        enemy.state = AISystem.HUNTER_STATES.CHASE
        enemy.detectedPlayer = true
        enemy.chasing = true
        enemy.vx = dirX * (enemy.speed or 0)
        enemy.vy = dirY * (enemy.speed or 0)
        enemy.lookX, enemy.lookY = dirX, dirY
        enemy.spinAngle = math.atan(enemy.lookY, enemy.lookX)
    else
        enemy.state = AISystem.HUNTER_STATES.IDLE
        enemy.detectedPlayer = false
        enemy.chasing = false
        enemy.vx, enemy.vy = 0, 0
        enemy.spinAngle = enemy.spinAngle or math.atan(enemy.lookY or 0, enemy.lookX or 1)
        enemy.spinAngle = enemy.spinAngle + (enemy.spinSpeed or 0) * dt
        if enemy.spinAngle > math.pi * 2 then
            enemy.spinAngle = enemy.spinAngle - math.pi * 2
        end
        enemy.lookX, enemy.lookY = rotate(1, 0, enemy.spinAngle)
    end

    if enemy.vx ~= 0 or enemy.vy ~= 0 then
        local nx, ny = normalize(enemy.vx, enemy.vy)
        if nx ~= 0 or ny ~= 0 then
            enemy.lookX, enemy.lookY = nx, ny
        end
    end

    if enemy.chasing and dist < 40 then
        enemy.vx, enemy.vy = 0, 0
        return
    end

    enemy.x = enemy.x + enemy.vx * dt
    enemy.y = enemy.y + enemy.vy * dt
end

return AISystem

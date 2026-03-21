-- Collision helpers for player/enemy overlap resolution and collectible pickup checks.
local Kinematics = require("src/utils/kinematics")

local CollisionSystem = {}

local function resetEnemyAfterPlayerContact(enemy, pauseDuration)
    -- Shared post-contact recovery to prevent immediate re-penetration.
    Kinematics.moveTo(enemy, enemy.prevX, enemy.prevY)
    Kinematics.stop(enemy)
    enemy.pauseTimer = math.max(enemy.pauseTimer or 0, pauseDuration or 1.0)
    enemy.chasing = false
    if enemy.state ~= nil then
        enemy.state = "idle"
    end
end

local function clearVelocityAgainstNormal(body, normalX, normalY)
    if not body then
        return
    end

    local nx = normalX or 0
    local ny = normalY or 0
    if nx == 0 and ny == 0 then
        return
    end

    local vx = body.vx or 0
    local vy = body.vy or 0
    local into = (vx * nx) + (vy * ny)
    if into < 0 then
        body.vx = vx - (into * nx)
        body.vy = vy - (into * ny)
    end

    local inputX = body.vx_input
    local inputY = body.vy_input
    if inputX ~= nil and ((inputX * nx) + ((inputY or 0) * ny)) < 0 then
        body.vx_input = inputX - (((inputX * nx) + ((inputY or 0) * ny)) * nx)
        body.vy_input = (inputY or 0) - (((inputX * nx) + ((inputY or 0) * ny)) * ny)
    end

    local impulseX = body.vx_impulse
    local impulseY = body.vy_impulse
    if impulseX ~= nil and ((impulseX * nx) + ((impulseY or 0) * ny)) < 0 then
        body.vx_impulse = impulseX - (((impulseX * nx) + ((impulseY or 0) * ny)) * nx)
        body.vy_impulse = (impulseY or 0) - (((impulseX * nx) + ((impulseY or 0) * ny)) * ny)
    end
end

local function computeObstacleSeparation(entity, entityW, entityH, obstacle)
    if not entity or not obstacle then
        return nil
    end

    local ex = entity.x or 0
    local ey = entity.y or 0
    local ew = entityW or 0
    local eh = entityH or 0
    local ox = obstacle.x or 0
    local oy = obstacle.y or 0
    local ow = obstacle.width or 0
    local oh = obstacle.height or 0

    if not CollisionSystem.overlaps(ex, ey, ew, eh, ox, oy, ow, oh) then
        return nil
    end

    local overlapX = math.min(ex + ew, ox + ow) - math.max(ex, ox)
    local overlapY = math.min(ey + eh, oy + oh) - math.max(ey, oy)
    if overlapX <= 0 or overlapY <= 0 then
        return nil
    end

    local prevX = entity.prevX
    local prevY = entity.prevY
    local dx = 0
    local dy = 0
    local usedPrev = false

    if prevX ~= nil and prevY ~= nil then
        local prevLeft = prevX
        local prevRight = prevX + ew
        local prevTop = prevY
        local prevBottom = prevY + eh
        local obstacleLeft = ox
        local obstacleRight = ox + ow
        local obstacleTop = oy
        local obstacleBottom = oy + oh

        if prevRight <= obstacleLeft then
            dx = -overlapX
            usedPrev = true
        elseif prevLeft >= obstacleRight then
            dx = overlapX
            usedPrev = true
        elseif prevBottom <= obstacleTop then
            dy = -overlapY
            usedPrev = true
        elseif prevTop >= obstacleBottom then
            dy = overlapY
            usedPrev = true
        end
    end

    if not usedPrev then
        local moveX = ex - (prevX or ex)
        local moveY = ey - (prevY or ey)
        if math.abs(moveX) > math.abs(moveY) then
            dx = (moveX >= 0) and -overlapX or overlapX
        elseif math.abs(moveY) > 0 then
            dy = (moveY >= 0) and -overlapY or overlapY
        else
            local entityCenterX = ex + (ew / 2)
            local entityCenterY = ey + (eh / 2)
            local obstacleCenterX = ox + (ow / 2)
            local obstacleCenterY = oy + (oh / 2)

            if overlapX < overlapY then
                dx = (entityCenterX < obstacleCenterX) and -overlapX or overlapX
            else
                dy = (entityCenterY < obstacleCenterY) and -overlapY or overlapY
            end
        end
    end

    local normalX = 0
    local normalY = 0
    if dx ~= 0 then
        normalX = (dx > 0) and 1 or -1
    elseif dy ~= 0 then
        normalY = (dy > 0) and 1 or -1
    end

    return {
        dx = dx,
        dy = dy,
        normalX = normalX,
        normalY = normalY
    }
end

function CollisionSystem.overlaps(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

function CollisionSystem.playerEnemyOverlap(player, enemy, playerSize)
    -- Treat the player as a square hitbox and compare it against the enemy bounds.
    if not player or not enemy then
        return false
    end
    local size = playerSize or 35
    local ew = enemy.width or 0
    local eh = enemy.height or 0
    return CollisionSystem.overlaps(
        player.x, player.y, size, size,
        enemy.x or 0, enemy.y or 0, ew, eh
    )
end

function CollisionSystem.stopPlayerOnEnemies(enemies, player, playerSize)
    -- Resolve penetration and return contact events; damage is handled by higher-level systems.
    if not enemies or not player then
        return false, {}
    end
    local size = playerSize or 35
    local blocked = false
    local hitEvents = {}

    for _, enemy in ipairs(enemies) do
        if CollisionSystem.playerEnemyOverlap(player, enemy, size) then
            blocked = true

            local px = player.x
            local py = player.y
            local ex = enemy.x or 0
            local ey = enemy.y or 0
            local ew = enemy.width or 0
            local eh = enemy.height or 0

            local overlapX = math.min(px + size, ex + ew) - math.max(px, ex)
            local overlapY = math.min(py + size, ey + eh) - math.max(py, ey)

            -- resolve overlap (MTV) so the player is not stuck inside the enemy
            if overlapX < overlapY then
                if px < ex then
                    Kinematics.translate(player, -overlapX, 0)
                else
                    Kinematics.translate(player, overlapX, 0)
                end
            else
                if py < ey then
                    Kinematics.translate(player, 0, -overlapY)
                else
                    Kinematics.translate(player, 0, overlapY)
                end
            end

            hitEvents[#hitEvents + 1] = {
                type = "player_enemy_contact",
                enemy = enemy
            }

            -- Pause and rewind so enemy does not immediately re-enter the player.
            resetEnemyAfterPlayerContact(enemy, 1.0)
        end
    end

    return blocked, hitEvents
end

function CollisionSystem.stopEnemiesOnPlayer(enemies, player, playerSize)
    -- Push enemies back to their previous positions after a contact frame.
    if not enemies or not player then
        return false
    end
    local size = playerSize or 35
    local blocked = false
    for _, enemy in ipairs(enemies) do
        if CollisionSystem.playerEnemyOverlap(player, enemy, size) then
            blocked = true
            resetEnemyAfterPlayerContact(enemy, 1.0)
        end
    end
    return blocked
end

function CollisionSystem.resolveEntityOnObstacle(entity, entityW, entityH, obstacle, opts)
    -- Resolve overlap and preserve tangential velocity so node contact behaves like ice.
    local resolution = computeObstacleSeparation(entity, entityW, entityH, obstacle)
    if not resolution then
        return false, nil
    end

    Kinematics.translate(entity, resolution.dx, resolution.dy)

    local cfg = opts or {}
    if cfg.slideOnContact ~= false then
        clearVelocityAgainstNormal(entity, resolution.normalX, resolution.normalY)
    end

    return true, resolution
end

function CollisionSystem.stopEnemiesOnObstacle(enemies, obstacle, pauseDuration)
    -- Keep enemies outside obstacle bounds while preserving slide along obstacle faces.
    if not enemies or not obstacle then
        return false
    end

    local ox = obstacle.x or 0
    local oy = obstacle.y or 0
    local ow = obstacle.width or 0
    local oh = obstacle.height or 0
    local pause = pauseDuration or 0.04
    local blocked = false

    for _, enemy in ipairs(enemies) do
        local ew = enemy.width or 0
        local eh = enemy.height or 0
        local resolved, resolution = CollisionSystem.resolveEntityOnObstacle(enemy, ew, eh, obstacle, {
            slideOnContact = true
        })
        if resolved then
            blocked = true
            if enemy.isHunter then
                local inChase = enemy.chasing or enemy.state == "chase"
                if inChase then
                    enemy.lastBlockedNode = {
                        x = ox,
                        y = oy,
                        width = ow,
                        height = oh
                    }
                    local memory = enemy.blockedNodeMemory or 1.2
                    enemy.blockedNodeTimer = math.max(enemy.blockedNodeTimer or 0, memory)
                    if enemy.rerouteAxis ~= nil and enemy.rerouteDir ~= nil and (enemy.rerouteTimer or 0) > 0 then
                        enemy.failedRerouteAxis = enemy.rerouteAxis
                        enemy.failedRerouteDir = enemy.rerouteDir
                        enemy.failedRerouteCount = math.min(6, (enemy.failedRerouteCount or 0) + 1)
                        local failureMemory = enemy.failedRerouteMemory or 1.4
                        enemy.failedRerouteTimer = math.max(enemy.failedRerouteTimer or 0, failureMemory)
                        enemy.rerouteTimer = 0
                        enemy.rerouteX = nil
                        enemy.rerouteY = nil
                        enemy.rerouteAxis = nil
                        enemy.rerouteDir = nil
                        enemy.rerouteStep = nil
                    end
                end
                enemy.pauseTimer = math.max(enemy.pauseTimer or 0, math.min(0.02, pause))
            else
                -- Patrol drones only move on a line; flip direction when a node blocks their lane.
                if enemy.forward ~= nil and (enemy.pauseTimer or 0) <= 0 then
                    enemy.forward = not enemy.forward
                end
                enemy.pauseTimer = math.max(enemy.pauseTimer or 0, math.min(0.04, pause))
            end

            if resolution and resolution.normalX ~= 0 then
                enemy.x = math.floor((enemy.x or 0) + 0.5)
            elseif resolution and resolution.normalY ~= 0 then
                enemy.y = math.floor((enemy.y or 0) + 0.5)
            end
        end
    end

    return blocked
end

function CollisionSystem.collectCells(player, cells, playerSize)
    -- Backward-compatible wrapper; energy-cell logic now lives in src/entities/energy_cell.lua.
    local EnergyCell = require("src/entities/energy_cell")
    return EnergyCell.collect(player, cells, playerSize)
end

return CollisionSystem

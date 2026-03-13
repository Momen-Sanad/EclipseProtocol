-- Collision helpers for player/enemy overlap resolution and collectible pickup checks.
local Kinematics = require("src/utils/kinematics")
local EnergyCell = require("src/entities/energy_cell")

local CollisionSystem = {}

local function aabb(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

function CollisionSystem.overlaps(x1, y1, w1, h1, x2, y2, w2, h2)
    return aabb(x1, y1, w1, h1, x2, y2, w2, h2)
end

function CollisionSystem.playerEnemyOverlap(player, enemy, playerSize)
    -- Treat the player as a square hitbox and compare it against the enemy bounds.
    if not player or not enemy then
        return false
    end
    local size = playerSize or 35
    local ew = enemy.width or 0
    local eh = enemy.height or 0
    return aabb(
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

            -- rewind enemy to previous pos (prevents tunneling) and pause it briefly
            Kinematics.moveTo(enemy, enemy.prevX, enemy.prevY)
            Kinematics.stop(enemy)

            -- pause the enemy so they don't immediately try to re-enter the player.
            -- We'll decrement this in the enemy update. Default to invulDuration as pause length.
            enemy.pauseTimer = 1.0
            enemy.chasing = false
            if enemy.state ~= nil then
                enemy.state = "idle"
            end
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
            Kinematics.moveTo(enemy, enemy.prevX, enemy.prevY)
            Kinematics.stop(enemy)

            -- set a short pause so enemy won't immediately chase again
            enemy.pauseTimer = 1.0
            enemy.chasing = false
            if enemy.state ~= nil then
                enemy.state = "idle"
            end
        end
    end
    return blocked
end

function CollisionSystem.resolveEntityOnObstacle(entity, entityW, entityH, obstacle)
    -- Resolve overlap between one axis-aligned entity and one axis-aligned obstacle.
    if not entity or not obstacle then
        return false
    end

    local ex = entity.x or 0
    local ey = entity.y or 0
    local ew = entityW or 0
    local eh = entityH or 0
    local ox = obstacle.x or 0
    local oy = obstacle.y or 0
    local ow = obstacle.width or 0
    local oh = obstacle.height or 0

    if not aabb(ex, ey, ew, eh, ox, oy, ow, oh) then
        return false
    end

    local overlapX = math.min(ex + ew, ox + ow) - math.max(ex, ox)
    local overlapY = math.min(ey + eh, oy + oh) - math.max(ey, oy)
    if overlapX <= 0 or overlapY <= 0 then
        return false
    end

    local entityCenterX = ex + (ew / 2)
    local entityCenterY = ey + (eh / 2)
    local obstacleCenterX = ox + (ow / 2)
    local obstacleCenterY = oy + (oh / 2)

    if overlapX < overlapY then
        if entityCenterX < obstacleCenterX then
            Kinematics.translate(entity, -overlapX, 0)
        else
            Kinematics.translate(entity, overlapX, 0)
        end
    else
        if entityCenterY < obstacleCenterY then
            Kinematics.translate(entity, 0, -overlapY)
        else
            Kinematics.translate(entity, 0, overlapY)
        end
    end

    return true
end

function CollisionSystem.stopEnemiesOnObstacle(enemies, obstacle, pauseDuration)
    -- Rewind enemies on obstacle overlap to keep static obstacles solid.
    if not enemies or not obstacle then
        return false
    end

    local ox = obstacle.x or 0
    local oy = obstacle.y or 0
    local ow = obstacle.width or 0
    local oh = obstacle.height or 0
    local pause = pauseDuration or 0.2
    local blocked = false

    for _, enemy in ipairs(enemies) do
        local ew = enemy.width or 0
        local eh = enemy.height or 0
        if aabb(enemy.x or 0, enemy.y or 0, ew, eh, ox, oy, ow, oh) then
            blocked = true
            Kinematics.moveTo(enemy, enemy.prevX, enemy.prevY)
            Kinematics.stop(enemy)
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
                end
                enemy.pauseTimer = math.max(enemy.pauseTimer or 0, math.min(0.06, pause))
            else
                enemy.pauseTimer = math.max(enemy.pauseTimer or 0, pause)
                enemy.chasing = false
                if enemy.state ~= nil then
                    enemy.state = "idle"
                end
            end
        end
    end

    return blocked
end

function CollisionSystem.collectCells(player, cells, playerSize)
    -- Backward-compatible wrapper; energy-cell logic now lives in src/entities/energy_cell.lua.
    return EnergyCell.collect(player, cells, playerSize)
end

return CollisionSystem

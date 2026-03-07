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
    -- Resolve penetration, then apply damage, knockback, and temporary invulnerability.
    if not enemies or not player then
        return false
    end
    local size = playerSize or 35
    local blocked = false

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

            -- Only apply damage/knockback if the player is NOT currently invulnerable
            if not player.invulTimer or player.invulTimer <= 0 then
                local reactionDuration = math.max(0.01, player.damageFlickerDuration or 0.4)
                local hitInvulDuration = enemy.invulDuration or 1.0

                -- 1) apply damage directly (so we know it happens)
                if enemy.damage and player.health then
                    player.health = math.max(0, player.health - (enemy.damage or 0))
                end

                -- 2) trigger optional hit callback (VFX/SFX hooks)
                if type(enemy.onHit) == "function" then
                    pcall(enemy.onHit, enemy, player)
                end

                -- 3) knockback via velocity impulse (smooth)
                local cx = player.x + (size / 2)
                local cy = player.y + (size / 2)
                local ex_c = ex + (ew / 2)
                local ey_c = ey + (eh / 2)
                local dx = cx - ex_c
                local dy = cy - ey_c
                local len = 0
                dx, dy, len = Kinematics.normalize(dx, dy)
                if len == 0 then
                    dx, dy = 0, -1
                end

                -- use velocity knockback so the movement system handles collisions & walls
                local knockback = enemy.knockback or 300      -- impulse magnitude (pixels/sec)
                local immediate = enemy.immediateKnockback or 8 -- small immediate positional nudge (pixels)

                -- 1) add to impulse components (movement system integrates + decays these)
                Kinematics.addImpulse(player, dx * knockback, dy * knockback)
                Kinematics.composeVelocity(player)

                -- 2) small immediate position nudge so knockback is visible this frame
                Kinematics.translate(player, dx * immediate, dy * immediate)

                -- debug print for knockback values
                -- print(("KNOCK: dx=%.2f dy=%.2f imp=(%.1f,%.1f) immediate=%.1f"):format(dx,dy, player.vx_impulse, player.vy_impulse, immediate))

                -- 4) start the brief hit reaction (blink + movement lock) and invulnerability.
                player.damageFlickerTimer = math.max(player.damageFlickerTimer or 0, reactionDuration)
                player.damageLockTimer = math.max(player.damageLockTimer or 0, reactionDuration)
                player.invulTimer = math.max(player.invulTimer or 0, hitInvulDuration, reactionDuration)
                player.invulnerable = true
                player.hitThisFrame = true
            end

            -- rewind enemy to previous pos (prevents tunneling) and pause it briefly
            Kinematics.moveTo(enemy, enemy.prevX, enemy.prevY)
            Kinematics.stop(enemy)

            -- pause the enemy so they don't immediately try to re-enter the player.
            -- We'll decrement this in the enemy update. Default to invulDuration as pause length.
            enemy.pauseTimer = 1.0
            enemy.chasing = false
        end
    end

    return blocked
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
            enemy.pauseTimer = math.max(enemy.pauseTimer or 0, pause)
            enemy.chasing = false
        end
    end

    return blocked
end

function CollisionSystem.collectCells(player, cells, playerSize)
    -- Backward-compatible wrapper; energy-cell logic now lives in src/entities/energy_cell.lua.
    return EnergyCell.collect(player, cells, playerSize)
end

return CollisionSystem

local CollisionSystem = {}

local function aabb(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

function CollisionSystem.overlaps(x1, y1, w1, h1, x2, y2, w2, h2)
    return aabb(x1, y1, w1, h1, x2, y2, w2, h2)
end

function CollisionSystem.playerEnemyOverlap(player, enemy, playerSize)
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
                    player.x = player.x - overlapX
                else
                    player.x = player.x + overlapX
                end
            else
                if py < ey then
                    player.y = player.y - overlapY
                else
                    player.y = player.y + overlapY
                end
            end

            -- Only apply damage/knockback if the player is NOT currently invulnerable
            if not player.invulTimer or player.invulTimer <= 0 then
                -- 1) apply damage directly (so we know it happens)
                if enemy.damage and player.health then
                    player.health = player.health - (enemy.damage or 0)
                end

                -- 2) call enemy:onCollision for sounds/particles
                if enemy.onCollision then
                    enemy:onCollision(player)
                end

                -- 3) knockback via velocity impulse (smooth)
                local cx = player.x + (size / 2)
                local cy = player.y + (size / 2)
                local ex_c = ex + (ew / 2)
                local ey_c = ey + (eh / 2)
                local dx = cx - ex_c
                local dy = cy - ey_c
                local len = math.sqrt(dx * dx + dy * dy)
                if len == 0 then
                    dx, dy = 0, -1
                    len = 1
                end
                dx = dx / len
                dy = dy / len

                -- use velocity knockback so the movement system handles collisions & walls
                local knockback = enemy.knockback or 300      -- impulse magnitude (pixels/sec)
                local immediate = enemy.immediateKnockback or 8 -- small immediate positional nudge (pixels)

                -- 1) add to impulse components (movement system integrates + decays these)
                player.vx_impulse = (player.vx_impulse or 0) + dx * knockback
                player.vy_impulse = (player.vy_impulse or 0) + dy * knockback

                -- 2) small immediate position nudge so knockback is visible this frame
                player.x = player.x + dx * immediate
                player.y = player.y + dy * immediate

                -- debug print for knockback values
                print(("KNOCK: dx=%.2f dy=%.2f imp=(%.1f,%.1f) immediate=%.1f"):format(dx,dy, player.vx_impulse, player.vy_impulse, immediate))

                -- 4) set invulnerability using the enemy's configured duration
                player.invulTimer = enemy.invulDuration or 1.0
                player.invulnerable = true
                player.hitThisFrame = true
            end

            -- rewind enemy to previous pos (prevents tunneling) and pause it briefly
            if enemy.prevX ~= nil then enemy.x = enemy.prevX end
            if enemy.prevY ~= nil then enemy.y = enemy.prevY end

            enemy.vx = 0
            enemy.vy = 0

            -- pause the enemy so they don't immediately try to re-enter the player.
            -- We'll decrement this in the enemy update. Default to invulDuration as pause length.
            enemy.pauseTimer = enemy.invulDuration or 0.6
            enemy.chasing = false
        end
    end

    return blocked
end

function CollisionSystem.stopEnemiesOnPlayer(enemies, player, playerSize)
    if not enemies or not player then
        return false
    end
    local size = playerSize or 35
    local blocked = false
    for _, enemy in ipairs(enemies) do
        if CollisionSystem.playerEnemyOverlap(player, enemy, size) then
            blocked = true
            if enemy.prevX ~= nil then
                enemy.x = enemy.prevX
            end
            if enemy.prevY ~= nil then
                enemy.y = enemy.prevY
            end
            enemy.vx = 0
            enemy.vy = 0

            -- set a short pause so enemy won't immediately chase again
            enemy.pauseTimer = enemy.invulDuration or 0.6
            enemy.chasing = false
        end
    end
    return blocked
end

function CollisionSystem.collectCells(player, cells, playerSize)
    if not player or not cells then
        return 0
    end

    local size = playerSize or 35
    local collected = 0

    for i = #cells, 1, -1 do
        local cell = cells[i]
        if aabb(
            player.x, player.y, size, size,
            cell.x, cell.y, cell.width, cell.height
        ) then
            table.remove(cells, i)
            collected = collected + 1
        end
    end

    return collected
end

return CollisionSystem

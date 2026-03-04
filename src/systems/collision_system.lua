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

function CollisionSystem.stopPlayerOnEnemies(player, enemies, playerSize)
    if not player or not enemies then
        return false
    end
    local size = playerSize or 35
    local blocked = false
    for _, enemy in ipairs(enemies) do
        if CollisionSystem.playerEnemyOverlap(player, enemy, size) then
            blocked = true
            local prevX = player.prevX
            local prevY = player.prevY
            local resolved = false
            if prevX ~= nil then
                local testX = prevX
                local testY = player.y
                if not CollisionSystem.overlaps(
                    testX, testY, size, size,
                    enemy.x or 0, enemy.y or 0, enemy.width or 0, enemy.height or 0
                ) then
                    player.x = testX
                    resolved = true
                end
            end

            if not resolved and prevY ~= nil then
                local testX = player.x
                local testY = prevY
                if not CollisionSystem.overlaps(
                    testX, testY, size, size,
                    enemy.x or 0, enemy.y or 0, enemy.width or 0, enemy.height or 0
                ) then
                    player.y = testY
                    resolved = true
                end
            end

            if not resolved then
                if prevX ~= nil then
                    player.x = prevX
                end
                if prevY ~= nil then
                    player.y = prevY
                end
            end
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

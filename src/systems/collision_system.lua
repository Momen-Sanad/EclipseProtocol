local CollisionSystem = {}

local function aabb(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
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

-- Power node entity helpers: spawn, repair state progression, and placeholder rendering.
local PowerNode = {}

PowerNode.DEFAULT_SIZE = 120
PowerNode.DEFAULT_COUNT = 3
PowerNode.DEFAULT_REPAIR_DURATION = 5.0
PowerNode.DEFAULT_INTERACT_RANGE = 170

function PowerNode.new(opts)
    opts = opts or {}
    return {
        x = opts.x or 0,
        y = opts.y or 0,
        width = opts.width or opts.size or PowerNode.DEFAULT_SIZE,
        height = opts.height or opts.size or PowerNode.DEFAULT_SIZE,
        interactRange = opts.interactRange or PowerNode.DEFAULT_INTERACT_RANGE,
        repairDuration = opts.repairDuration or PowerNode.DEFAULT_REPAIR_DURATION,
        repairTimer = 0,
        isRepairing = false,
        isRepaired = false
    }
end

function PowerNode.buildGrid(playWidth, playHeight, opts)
    opts = opts or {}
    local w = playWidth or 0
    local h = playHeight or 0
    local size = opts.size or PowerNode.DEFAULT_SIZE
    local count = math.max(1, math.floor(opts.count or PowerNode.DEFAULT_COUNT))

    local cols = math.ceil(math.sqrt(count))
    local rows = math.ceil(count / cols)
    local padX = math.max(100, size)
    local padY = math.max(100, size)
    local usableW = math.max(0, w - (padX * 2))
    local usableH = math.max(0, h - (padY * 2))

    local nodes = {}
    for i = 1, count do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cx = padX + ((cols > 1) and (usableW * (col / (cols - 1))) or (usableW * 0.5))
        local cy = padY + ((rows > 1) and (usableH * (row / (rows - 1))) or (usableH * 0.5))
        nodes[#nodes + 1] = PowerNode.new({
            x = math.floor(cx - (size / 2)),
            y = math.floor(cy - (size / 2)),
            width = size,
            height = size,
            interactRange = opts.interactRange,
            repairDuration = opts.repairDuration
        })
    end
    return nodes
end

function PowerNode.isPlayerStationarySinceLastFrame(player)
    if not player then
        return false
    end
    local prevX = player.prevX
    local prevY = player.prevY
    if prevX == nil or prevY == nil then
        return true
    end
    return (player.x == prevX) and (player.y == prevY)
end

local function getPlayerCenter(player, playerSize)
    local size = playerSize or 35
    local px = (player and player.x or 0) + (size / 2)
    local py = (player and player.y or 0) + (size / 2)
    return px, py
end

function PowerNode.getNearestInRange(player, nodes, playerSize)
    if not player or not nodes then
        return nil
    end

    local px, py = getPlayerCenter(player, playerSize)
    local closestNode = nil
    local closestDistSq = nil

    for _, node in ipairs(nodes) do
        if not node.isRepaired then
            local nx = (node.x or 0) + ((node.width or 0) / 2)
            local ny = (node.y or 0) + ((node.height or 0) / 2)
            local dx = px - nx
            local dy = py - ny
            local distSq = (dx * dx) + (dy * dy)
            local range = node.interactRange or PowerNode.DEFAULT_INTERACT_RANGE
            if distSq <= (range * range) and (closestDistSq == nil or distSq < closestDistSq) then
                closestNode = node
                closestDistSq = distSq
            end
        end
    end

    return closestNode
end

function PowerNode.getActive(nodes)
    if not nodes then
        return nil
    end
    for _, node in ipairs(nodes) do
        if node.isRepairing then
            return node
        end
    end
    return nil
end

function PowerNode.allRepaired(nodes)
    if not nodes or #nodes == 0 then
        return false
    end
    for _, node in ipairs(nodes) do
        if not node.isRepaired then
            return false
        end
    end
    return true
end

function PowerNode.startRepair(node)
    if not node then
        return
    end
    node.isRepairing = true
    node.repairTimer = 0
end

function PowerNode.cancelRepair(node)
    if not node then
        return
    end
    node.isRepairing = false
    node.repairTimer = 0
end

function PowerNode.updateRepair(node, dt)
    if not node then
        return false
    end
    node.repairTimer = math.min(
        node.repairDuration,
        (node.repairTimer or 0) + (dt or 0)
    )
    if node.repairTimer >= node.repairDuration then
        node.isRepairing = false
        node.isRepaired = true
        node.repairTimer = node.repairDuration
        return true
    end
    return false
end

function PowerNode.getPrompt(player, nodes, playerSize)
    if not nodes or #nodes == 0 or PowerNode.allRepaired(nodes) then
        return nil
    end

    local active = PowerNode.getActive(nodes)
    if active then
        local pct = 0
        if active.repairDuration > 0 then
            pct = math.floor((active.repairTimer / active.repairDuration) * 100)
        end
        return ("Repairing power node... %d%%"):format(math.max(0, math.min(100, pct)))
    end

    if PowerNode.getNearestInRange(player, nodes, playerSize) then
        return "Press Enter to repair power node"
    end

    return nil
end

function PowerNode.draw(node)
    if not node then
        return
    end

    local nx = node.x
    local ny = node.y
    local nw = node.width
    local nh = node.height
    local cx = nx + (nw / 2)
    local cy = ny + (nh / 2)

    -- Placeholder body until a dedicated power node sprite is added.
    love.graphics.setColor(0.14, 0.20, 0.28, 0.95)
    love.graphics.rectangle("fill", nx, ny, nw, nh, 12, 12)
    love.graphics.setColor(0.55, 0.85, 1.0, 1.0)
    love.graphics.rectangle("line", nx, ny, nw, nh, 12, 12)

    if node.isRepaired then
        love.graphics.setColor(0.25, 0.95, 0.35, 0.28)
        love.graphics.circle("fill", cx, cy, node.interactRange)
        love.graphics.setColor(0.45, 1.0, 0.55, 0.95)
        love.graphics.circle("line", cx, cy, node.interactRange)
    elseif node.isRepairing then
        love.graphics.setColor(0.20, 0.55, 1.0, 0.28)
        love.graphics.circle("fill", cx, cy, node.interactRange)
        love.graphics.setColor(0.35, 0.75, 1.0, 0.95)
        love.graphics.circle("line", cx, cy, node.interactRange)
    else
        love.graphics.setColor(1.0, 0.20, 0.20, 0.22)
        love.graphics.circle("fill", cx, cy, node.interactRange)
        love.graphics.setColor(1.0, 0.35, 0.35, 0.9)
        love.graphics.circle("line", cx, cy, node.interactRange)
    end

    if node.isRepairing then
        local pct = 0
        if node.repairDuration > 0 then
            pct = math.max(0, math.min(1, node.repairTimer / node.repairDuration))
        end
        local barW = nw
        local barH = 10
        local barX = nx
        local barY = ny - 18
        love.graphics.setColor(0.05, 0.08, 0.12, 0.9)
        love.graphics.rectangle("fill", barX, barY, barW, barH, 3, 3)
        love.graphics.setColor(0.35, 0.9, 1.0, 0.95)
        love.graphics.rectangle("fill", barX + 1, barY + 1, math.max(0, (barW - 2) * pct), barH - 2, 3, 3)
    end
end

return PowerNode

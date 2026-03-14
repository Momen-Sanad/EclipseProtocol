-- Power node entity helpers: spawn, repair state progression, and placeholder rendering.
local CollisionSystem = require("src/systems/collision_system")
local MathUtils = require("src/utils/math_utils")

local PowerNode = {}

PowerNode.DEFAULT_SIZE = 120
PowerNode.DEFAULT_COUNT = 3
PowerNode.DEFAULT_REPAIR_DURATION = 5.0
PowerNode.DEFAULT_INTERACT_RANGE = 170

function PowerNode.new(opts)
    -- Creates one repairable obstacle node with interaction/repair metadata.
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

function PowerNode.buildRandom(playWidth, playHeight, opts)
    -- Randomly distributes nodes while keeping spacing so repair zones do not overlap excessively.
    opts = opts or {}
    local w = playWidth or 0
    local h = playHeight or 0
    local size = opts.size or PowerNode.DEFAULT_SIZE
    local count = math.max(1, math.floor(opts.count or PowerNode.DEFAULT_COUNT))
    local pad = math.max(40, math.floor(size * 0.5))
    local minSpacing = math.max(size * 1.15, opts.minSpacing or (size + 40))
    local minSpacingSq = minSpacing * minSpacing
    local maxAttemptsPerNode = 80
    local rng = (love and love.math and love.math.random) or math.random
    local patrolLanes = opts.patrolLanes
    local lanePadding = math.max(0, opts.patrolLanePadding or math.floor(size * 0.15))

    local nodes = {}

    local function makeNodeAt(x, y)
        return PowerNode.new({
            x = x,
            y = y,
            width = size,
            height = size,
            interactRange = opts.interactRange,
            repairDuration = opts.repairDuration
        })
    end

    local function isFarEnough(x, y)
        local cx = x + (size / 2)
        local cy = y + (size / 2)
        for _, node in ipairs(nodes) do
            local nx = (node.x or 0) + ((node.width or size) / 2)
            local ny = (node.y or 0) + ((node.height or size) / 2)
            if MathUtils.distanceSquared(cx, cy, nx, ny) < minSpacingSq then
                return false
            end
        end
        return true
    end

    local function intersectsPatrolLane(x, y)
        if type(patrolLanes) ~= "table" or #patrolLanes == 0 then
            return false
        end

        for _, lane in ipairs(patrolLanes) do
            local laneLeft = lane.left
            local laneRight = lane.right
            local laneTop = lane.top
            local laneBottom = lane.bottom

            if laneLeft == nil or laneRight == nil or laneTop == nil or laneBottom == nil then
                -- Backward compatibility for older lane snapshots.
                laneLeft = math.min(lane.x1 or 0, lane.x2 or 0)
                laneRight = math.max(lane.x1 or 0, lane.x2 or 0)
                local laneThickness = math.max(8, math.floor((lane.thickness or size) * 0.45))
                laneTop = (lane.y or 0) - laneThickness
                laneBottom = (lane.y or 0) + laneThickness
            end

            local lx = laneLeft - lanePadding
            local ly = laneTop - lanePadding
            local lw = math.max(1, (laneRight - laneLeft) + (lanePadding * 2))
            local lh = math.max(1, (laneBottom - laneTop) + (lanePadding * 2))
            if CollisionSystem.overlaps(x, y, size, size, lx, ly, lw, lh) then
                return true
            end
        end

        return false
    end

    local function isValidPlacement(x, y)
        return isFarEnough(x, y) and (not intersectsPatrolLane(x, y))
    end

    local minX = pad
    local maxX = math.max(minX, w - size - pad)
    local minY = pad
    local maxY = math.max(minY, h - size - pad)

    local candidatePoints = {}
    local scanStep = math.max(8, math.floor(size * 0.4))
    for y = minY, maxY, scanStep do
        for x = minX, maxX, scanStep do
            if not intersectsPatrolLane(x, y) then
                candidatePoints[#candidatePoints + 1] = { x = x, y = y }
            end
        end
    end

    for i = #candidatePoints, 2, -1 do
        local j = rng(1, i)
        candidatePoints[i], candidatePoints[j] = candidatePoints[j], candidatePoints[i]
    end

    for _ = 1, count do
        local placed = false

        for _ = 1, maxAttemptsPerNode do
            local x = rng(minX, maxX)
            local y = rng(minY, maxY)
            if isValidPlacement(x, y) then
                nodes[#nodes + 1] = makeNodeAt(x, y)
                placed = true
                break
            end
        end

        if not placed then
            for _, point in ipairs(candidatePoints) do
                if isValidPlacement(point.x, point.y) then
                    nodes[#nodes + 1] = makeNodeAt(point.x, point.y)
                    placed = true
                    break
                end
            end
        end

        if not placed then
            -- Keep spacing/route guarantees strict; stop adding nodes if no valid slots remain.
            break
        end
    end

    return nodes
end

function PowerNode.buildGrid(playWidth, playHeight, opts)
    -- Backward-compatible alias kept for existing call sites.
    return PowerNode.buildRandom(playWidth, playHeight, opts)
end

function PowerNode.getNodeCenters(nodes)
    -- Returns center points for systems that need spawn constraints around nodes.
    local centers = {}
    if not nodes then
        return centers
    end

    for _, node in ipairs(nodes) do
        centers[#centers + 1] = {
            x = (node.x or 0) + ((node.width or 0) / 2),
            y = (node.y or 0) + ((node.height or 0) / 2),
            node = node
        }
    end
    return centers
end

function PowerNode.isPlayerStationarySinceLastFrame(player)
    -- Repair only progresses while the player remains still.
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
    -- Computes player center used for range checks.
    local size = playerSize or 35
    local px = (player and player.x or 0) + (size / 2)
    local py = (player and player.y or 0) + (size / 2)
    return px, py
end

function PowerNode.getNearestInRange(player, nodes, playerSize)
    -- Finds the closest unrepaired node inside interaction radius.
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
    -- Returns node currently being repaired (if any).
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
    -- Win-condition helper used by the power node system.
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
    -- Begins repair progress from zero.
    if not node then
        return
    end
    node.isRepairing = true
    node.repairTimer = 0
end

function PowerNode.cancelRepair(node)
    -- Interrupts repair when player moves away.
    if not node then
        return
    end
    node.isRepairing = false
    node.repairTimer = 0
end

function PowerNode.updateRepair(node, dt)
    -- Advances timer and marks node repaired when duration is reached.
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
    -- Produces context-sensitive HUD prompt for repair interaction.
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
    -- Renders node body, interaction range tint, and repair progress bar.
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

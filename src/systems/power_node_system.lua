-- Coordinates power-node lifecycle, interaction, obstacle collisions, and prompts.
local CollisionSystem = require("src/systems/collision_system")
local PowerNode = require("src/entities/power_node")

local PowerNodeSystem = {}

local nodes = {}

function PowerNodeSystem.reset(playWidth, playHeight, context)
    -- Creates a new node set for the current run using context overrides.
    local cfg = context or {}
    nodes = PowerNode.buildGrid(playWidth, playHeight, {
        size = cfg.powerNodeSize or cfg.nodeSize,
        count = cfg.powerNodeCount or cfg.nodeCount,
        interactRange = cfg.powerNodeInteractRange or cfg.nodeInteractRange,
        repairDuration = cfg.powerNodeRepairDuration or cfg.nodeRepairDuration
    })
end

function PowerNodeSystem.resolveObstacleCollisions(player, playerSize, drones, hunters)
    -- Treat power nodes as solid obstacles for player and enemies.
    for _, node in ipairs(nodes) do
        CollisionSystem.resolveEntityOnObstacle(player, playerSize, playerSize, node)
        CollisionSystem.stopEnemiesOnObstacle(drones, node)
        CollisionSystem.stopEnemiesOnObstacle(hunters, node)
    end
end

function PowerNodeSystem.update(player, playerSize, input, dt)
    -- Handles repair start/cancel/progress and reports win condition.
    if not nodes or #nodes == 0 then
        return false
    end

    local playerStill = PowerNode.isPlayerStationarySinceLastFrame(player)
    local activeNode = PowerNode.getActive(nodes)

    if not activeNode and playerStill and input and input.interactPressed and input.interactPressed() then
        local candidateNode = PowerNode.getNearestInRange(player, nodes, playerSize)
        if candidateNode then
            PowerNode.startRepair(candidateNode)
            activeNode = candidateNode
        end
    end

    if activeNode then
        if not playerStill then
            PowerNode.cancelRepair(activeNode)
        else
            PowerNode.updateRepair(activeNode, dt)
        end
    end

    return PowerNode.allRepaired(nodes)
end

function PowerNodeSystem.getPrompt(player, playerSize)
    -- UI helper for contextual interaction text.
    return PowerNode.getPrompt(player, nodes, playerSize)
end

function PowerNodeSystem.draw()
    -- Draws all node visuals, including interaction radii and repair bars.
    for _, node in ipairs(nodes) do
        PowerNode.draw(node)
    end
end

function PowerNodeSystem.getNodes()
    -- Exposes raw node list for advanced systems/debugging.
    return nodes
end

return PowerNodeSystem

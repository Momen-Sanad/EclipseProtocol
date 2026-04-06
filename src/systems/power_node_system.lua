-- Coordinates power-node lifecycle, interaction, obstacle collisions, and prompts.
local CollisionSystem = require("src/systems/collision_system")
local PowerNode = require("src/entities/power_node")

local PowerNodeSystem = {}

local nodes = {}

function PowerNodeSystem.reset(playWidth, playHeight, context)
    -- Creates a new node set for the current run using context overrides.
    local cfg = context or {}
    nodes = PowerNode.buildRandom(playWidth, playHeight, {
        size = cfg.powerNodeSize or cfg.nodeSize,
        count = cfg.powerNodeCount or cfg.nodeCount,
        interactRange = cfg.powerNodeInteractRange or cfg.nodeInteractRange,
        repairDuration = cfg.powerNodeRepairDuration or cfg.nodeRepairDuration,
        minSpacing = cfg.powerNodeMinSpacing or cfg.nodeMinSpacing,
        patrolLanes = cfg.patrolLanes,
        patrolLanePadding = cfg.patrolLanePadding,
        protectedZones = cfg.protectedZones,
        protectedZonePadding = cfg.protectedZonePadding
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
        -- Fail-safe: strict spawn constraints can produce no valid nodes for a room.
        return true, false
    end

    local playerStill = PowerNode.isPlayerStationarySinceLastFrame(player)
    local activeNode = PowerNode.getActive(nodes)
    local canceledByMovement = false

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
            canceledByMovement = true
        else
            PowerNode.updateRepair(activeNode, dt)
        end
    end

    return PowerNode.allRepaired(nodes), canceledByMovement
end

function PowerNodeSystem.getPrompt(player, playerSize)
    -- UI helper for contextual interaction text.
    return PowerNode.getPrompt(player, nodes, playerSize)
end

function PowerNodeSystem.getObjectivePrompt()
    -- UI helper for room objective reminder when no context-specific prompt is active.
    if not nodes or #nodes == 0 then
        return nil
    end

    local remaining = 0
    for _, node in ipairs(nodes) do
        if not node.isRepaired then
            remaining = remaining + 1
        end
    end

    if remaining <= 0 then
        return nil
    end

    if remaining == 1 then
        return "Repair the final power node to open the exit"
    end

    return ("Repair all power nodes (%d remaining) to open the exit"):format(remaining)
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

function PowerNodeSystem.syncWorld(world)
    if not world or not world.entities then
        return
    end
    world.entities.powerNodes = nodes
end

function PowerNodeSystem.resetWorld(world, playWidth, playHeight, context)
    PowerNodeSystem.reset(playWidth, playHeight, context)
    PowerNodeSystem.syncWorld(world)
end

return PowerNodeSystem

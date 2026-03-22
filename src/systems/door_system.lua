-- Handles room-transition door spawning, overlap checks, and rendering.
local CollisionSystem = require("src/systems/collision_system")
local DoorUtils = require("src/world/door_utils")

local DoorSystem = {}

local entryDoor = nil
local exitDoor = nil
local exitOpen = false

local function overlapsDoor(player, playerSize, door)
    if not door or not player then
        return false
    end
    local size = playerSize or 35
    return CollisionSystem.overlaps(
        player.x or 0,
        player.y or 0,
        size,
        size,
        door.x,
        door.y,
        door.width,
        door.height
    )
end

local function drawDoor(door, isOpen)
    if not door then
        return
    end

    local baseFill = { 0.82, 0.12, 0.16, 0.30 }
    local baseEdge = { 1.0, 0.30, 0.32, 0.92 }
    if isOpen then
        local t = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
        local pulse = 0.55 + (0.45 * math.abs(math.sin(t * 7.5)))
        baseFill = { 1.0, 1.0, 1.0, 0.18 + (0.22 * pulse) }
        baseEdge = { 1.0, 1.0, 1.0, 0.55 + (0.45 * pulse) }
    end

    love.graphics.setColor(baseFill)
    love.graphics.rectangle("fill", door.x, door.y, door.width, door.height, 5, 5)
    love.graphics.setColor(baseEdge)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", door.x, door.y, door.width, door.height, 5, 5)
    love.graphics.setLineWidth(1)
end

local function normalizeDoorSnapshot(door)
    if type(door) ~= "table" then
        return nil, nil
    end
    local snapshotEdge = DoorUtils.normalizeEdge(door.edge)
    if not snapshotEdge then
        return nil, nil
    end

    local normalized = DoorUtils.cloneDoor(door)
    normalized.edge = snapshotEdge
    return normalized, snapshotEdge
end

function DoorSystem.getOppositeEdge(edge)
    return DoorUtils.oppositeEdge(edge)
end

function DoorSystem.reset()
    entryDoor = nil
    exitDoor = nil
    exitOpen = false
end

function DoorSystem.setupRoom(playWidth, playHeight, config)
    local cfg = config or {}
    local hasEntry = cfg.hasEntryDoor and true or false
    local hasExit = cfg.hasExitDoor and true or false
    local usedEdges = {}
    local entryEdge = DoorUtils.normalizeEdge(cfg.entryEdge)
    local exitEdge = DoorUtils.normalizeEdge(cfg.exitEdge)
    local entrySnapshot = cfg.entryDoor
    local exitSnapshot = cfg.exitDoor
    entryDoor = nil
    exitDoor = nil

    if hasEntry then
        entryDoor, entryEdge = normalizeDoorSnapshot(entrySnapshot)
        if not entryEdge then
            entryEdge = DoorUtils.normalizeEdge(cfg.entryEdge)
        end

        if not entryDoor then
            if not entryEdge then
                entryEdge = DoorUtils.chooseRandomEdge(nil, nil)
            end
            entryDoor = DoorUtils.buildDoorForEdge(entryEdge, playWidth, playHeight, cfg, nil)
        end

        if entryDoor then
            usedEdges[entryDoor.edge] = true
        end
    else
        entryDoor = nil
    end

    if hasExit then
        exitDoor, exitEdge = normalizeDoorSnapshot(exitSnapshot)
        if not exitEdge then
            exitEdge = DoorUtils.normalizeEdge(cfg.exitEdge)
        end

        if not exitDoor then
            if not exitEdge then
                exitEdge = DoorUtils.chooseRandomEdge(nil, usedEdges)
            end
            exitDoor = DoorUtils.buildDoorForEdge(exitEdge, playWidth, playHeight, cfg, nil)
        end
    else
        exitDoor = nil
    end

    exitOpen = cfg.exitInitiallyOpen and true or false
end

function DoorSystem.setExitOpen(isOpen)
    if not exitDoor then
        exitOpen = false
        return
    end
    exitOpen = isOpen and true or false
end

function DoorSystem.isExitOpen()
    return exitOpen and exitDoor ~= nil
end

function DoorSystem.getExitEdge()
    return exitDoor and exitDoor.edge or nil
end

function DoorSystem.getExitDoor()
    return DoorUtils.cloneDoor(exitDoor)
end

function DoorSystem.tryUseExit(player, playerSize, input)
    if not DoorSystem.isExitOpen() then
        return false
    end
    if not input or not input.interactPressed or not input.interactPressed() then
        return false
    end
    if overlapsDoor(player, playerSize, exitDoor) then
        return true
    end
    return false
end

function DoorSystem.getDoors()
    return {
        entry = DoorUtils.cloneDoor(entryDoor),
        exit = DoorUtils.cloneDoor(exitDoor)
    }
end

function DoorSystem.syncWorld(world)
    if not world or not world.entities then
        return
    end
    world.entities.doors = DoorSystem.getDoors()
end

function DoorSystem.getPrompt(player, playerSize)
    if overlapsDoor(player, playerSize, exitDoor) then
        if DoorSystem.isExitOpen() then
            return "PRESS ENTER TO USE THE DOOR"
        end
        return "DOOR LOCKED: REPAIR ALL POWER NODES"
    end
    if overlapsDoor(player, playerSize, entryDoor) then
        return "DOOR LOCKED"
    end
    return nil
end

function DoorSystem.draw()
    drawDoor(entryDoor, false)
    drawDoor(exitDoor, DoorSystem.isExitOpen())
end

return DoorSystem

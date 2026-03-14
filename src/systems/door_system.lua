-- Handles room-transition door spawning, overlap checks, and rendering.
local CollisionSystem = require("src/systems/collision_system")

local DoorSystem = {}

local entryDoor = nil
local exitDoor = nil
local exitOpen = false
local EDGES = { "top", "bottom", "left", "right" }

local function randomInt(minValue, maxValue)
    local rng = (love and love.math and love.math.random) or math.random
    return rng(minValue, maxValue)
end

local function normalizeEdge(edge)
    if edge == "top" or edge == "bottom" or edge == "left" or edge == "right" then
        return edge
    end
    return nil
end

local function cloneDoor(door)
    if not door then
        return nil
    end
    return {
        x = door.x,
        y = door.y,
        width = door.width,
        height = door.height,
        edge = door.edge
    }
end

local function oppositeEdge(edge)
    if edge == "top" then
        return "bottom"
    end
    if edge == "bottom" then
        return "top"
    end
    if edge == "left" then
        return "right"
    end
    if edge == "right" then
        return "left"
    end
    return nil
end

local function chooseRandomEdge(excluded)
    local candidates = {}
    for _, edge in ipairs(EDGES) do
        if not (excluded and excluded[edge]) then
            candidates[#candidates + 1] = edge
        end
    end
    if #candidates == 0 then
        return EDGES[randomInt(1, #EDGES)]
    end
    return candidates[randomInt(1, #candidates)]
end

local function buildDoorForEdge(edge, playWidth, playHeight, config)
    local cfg = config or {}
    local w = math.max(0, math.floor(playWidth or 0))
    local h = math.max(0, math.floor(playHeight or 0))
    local side = normalizeEdge(edge) or chooseRandomEdge(nil)
    if w <= 0 or h <= 0 then
        return nil
    end

    local margin = math.max(0, math.floor(cfg.doorEdgeMargin or 8))
    local thickness = math.max(20, math.floor(cfg.doorThickness or 28))
    local horizontalSize = math.max(90, math.floor(w * (cfg.doorWidthFactor or 0.18)))
    local verticalSize = math.max(90, math.floor(h * (cfg.doorHeightFactor or 0.18)))

    local x = 0
    local y = 0
    local width = thickness
    local height = thickness

    if side == "top" then
        -- Top edge.
        width = math.min(horizontalSize, math.max(thickness, w - margin * 2))
        height = thickness
        x = randomInt(margin, math.max(margin, w - width - margin))
        y = 0
    elseif side == "bottom" then
        -- Bottom edge.
        width = math.min(horizontalSize, math.max(thickness, w - margin * 2))
        height = thickness
        x = randomInt(margin, math.max(margin, w - width - margin))
        y = math.max(0, h - height)
    elseif side == "left" then
        -- Left edge.
        width = thickness
        height = math.min(verticalSize, math.max(thickness, h - margin * 2))
        x = 0
        y = randomInt(margin, math.max(margin, h - height - margin))
    else
        -- Right edge.
        width = thickness
        height = math.min(verticalSize, math.max(thickness, h - margin * 2))
        x = math.max(0, w - width)
        y = randomInt(margin, math.max(margin, h - height - margin))
    end

    return {
        x = x,
        y = y,
        width = width,
        height = height,
        edge = side
    }
end

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

function DoorSystem.getOppositeEdge(edge)
    return oppositeEdge(edge)
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
    local entryEdge = normalizeEdge(cfg.entryEdge)
    local exitEdge = normalizeEdge(cfg.exitEdge)
    local entrySnapshot = cfg.entryDoor
    entryDoor = nil
    exitDoor = nil

    if hasEntry then
        if type(entrySnapshot) == "table" then
            local snapshotEdge = normalizeEdge(entrySnapshot.edge)
            if snapshotEdge then
                entryDoor = {
                    x = entrySnapshot.x,
                    y = entrySnapshot.y,
                    width = entrySnapshot.width,
                    height = entrySnapshot.height,
                    edge = snapshotEdge
                }
                entryEdge = snapshotEdge
            end
        end

        if not entryDoor then
            if not entryEdge then
                entryEdge = chooseRandomEdge(nil)
            end
            entryDoor = buildDoorForEdge(entryEdge, playWidth, playHeight, cfg)
        end

        if entryDoor then
            usedEdges[entryDoor.edge] = true
        end
    else
        entryDoor = nil
    end

    if hasExit then
        if not exitEdge then
            exitEdge = chooseRandomEdge(usedEdges)
        end
        exitDoor = buildDoorForEdge(exitEdge, playWidth, playHeight, cfg)
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
    return cloneDoor(exitDoor)
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

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

local function getDoorPalette(style, pulse)
    if style == "open" then
        return {
            frameFill = { 0.08, 0.16, 0.22, 0.88 },
            frameEdge = { 0.58, 0.92, 1.0, 0.95 },
            frameGlow = { 0.28, 0.86, 1.0, 0.16 + (0.12 * pulse) },
            recess = { 0.03, 0.07, 0.10, 0.82 },
            barrier = { 0.28, 0.90, 1.0, 0.18 + (0.18 * pulse) },
            beam = { 0.85, 1.0, 1.0, 0.88 },
            detail = { 0.62, 0.96, 1.0, 0.55 + (0.25 * pulse) }
        }
    end

    if style == "locked" then
        return {
            frameFill = { 0.16, 0.10, 0.12, 0.9 },
            frameEdge = { 0.96, 0.34, 0.38, 0.96 },
            frameGlow = { 1.0, 0.22, 0.26, 0.14 + (0.06 * pulse) },
            recess = { 0.08, 0.04, 0.05, 0.84 },
            barrier = { 0.88, 0.18, 0.22, 0.26 + (0.10 * pulse) },
            beam = { 1.0, 0.66, 0.66, 0.92 },
            detail = { 1.0, 0.48, 0.50, 0.48 + (0.18 * pulse) }
        }
    end

    return {
        frameFill = { 0.10, 0.12, 0.18, 0.84 },
        frameEdge = { 0.58, 0.66, 0.82, 0.9 },
        frameGlow = { 0.42, 0.56, 0.90, 0.08 + (0.04 * pulse) },
        recess = { 0.04, 0.06, 0.10, 0.8 },
        barrier = { 0.54, 0.68, 0.92, 0.16 },
        beam = { 0.86, 0.92, 1.0, 0.75 },
        detail = { 0.70, 0.82, 0.98, 0.32 }
    }
end

local function drawDoorSegments(x, y, w, h, isVertical, color, pulse)
    local alpha = (color[4] or 1) * pulse
    love.graphics.setColor(color[1], color[2], color[3], alpha)

    if isVertical then
        local segmentH = math.max(16, math.floor(h * 0.16))
        love.graphics.rectangle("fill", x, y + 6, w, segmentH, 3, 3)
        love.graphics.rectangle("fill", x, y + h - segmentH - 6, w, segmentH, 3, 3)
        love.graphics.rectangle("fill", x, y + math.floor((h - segmentH) * 0.5), w, segmentH, 3, 3)
    else
        local segmentW = math.max(16, math.floor(w * 0.16))
        love.graphics.rectangle("fill", x + 6, y, segmentW, h, 3, 3)
        love.graphics.rectangle("fill", x + w - segmentW - 6, y, segmentW, h, 3, 3)
        love.graphics.rectangle("fill", x + math.floor((w - segmentW) * 0.5), y, segmentW, h, 3, 3)
    end
end

local function drawDoor(door, style)
    if not door then
        return
    end

    local x = door.x or 0
    local y = door.y or 0
    local w = door.width or 0
    local h = door.height or 0
    local isVertical = not (door.edge == "top" or door.edge == "bottom")
    local t = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
    local pulse = 0.55 + (0.45 * math.abs(math.sin(t * 4.8)))
    local palette = getDoorPalette(style, pulse)

    local framePad = 7
    local frameX = x - framePad
    local frameY = y - framePad
    local frameW = w + (framePad * 2)
    local frameH = h + (framePad * 2)
    local innerX = x + 2
    local innerY = y + 2
    local innerW = math.max(8, w - 4)
    local innerH = math.max(8, h - 4)

    love.graphics.setColor(palette.frameFill)
    love.graphics.rectangle("fill", frameX, frameY, frameW, frameH, 5, 5)
    love.graphics.setColor(palette.frameGlow)
    if isVertical then
        love.graphics.rectangle("fill", frameX + 3, frameY + 8, frameW - 6, 4, 2, 2)
        love.graphics.rectangle("fill", frameX + 3, frameY + frameH - 12, frameW - 6, 4, 2, 2)
    else
        love.graphics.rectangle("fill", frameX + 8, frameY + 3, frameW - 16, 4, 2, 2)
        love.graphics.rectangle("fill", frameX + 8, frameY + frameH - 7, frameW - 16, 4, 2, 2)
    end
    love.graphics.setColor(palette.frameEdge)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", frameX, frameY, frameW, frameH, 5, 5)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(palette.recess)
    love.graphics.rectangle("fill", innerX, innerY, innerW, innerH, 3, 3)

    if style == "open" then
        if isVertical then
            local railW = math.max(4, math.floor(innerW * 0.28))
            love.graphics.setColor(palette.barrier)
            love.graphics.rectangle("fill", innerX, innerY, railW, innerH, 3, 3)
            love.graphics.rectangle("fill", innerX + innerW - railW, innerY, railW, innerH, 3, 3)
            drawDoorSegments(innerX + 1, innerY + 2, railW - 2, innerH - 4, true, palette.detail, pulse)
            drawDoorSegments(innerX + innerW - railW + 1, innerY + 2, railW - 2, innerH - 4, true, palette.detail, pulse)
        else
            local railH = math.max(4, math.floor(innerH * 0.28))
            love.graphics.setColor(palette.barrier)
            love.graphics.rectangle("fill", innerX, innerY, innerW, railH, 3, 3)
            love.graphics.rectangle("fill", innerX, innerY + innerH - railH, innerW, railH, 3, 3)
            drawDoorSegments(innerX + 2, innerY + 1, innerW - 4, railH - 2, false, palette.detail, pulse)
            drawDoorSegments(innerX + 2, innerY + innerH - railH + 1, innerW - 4, railH - 2, false, palette.detail, pulse)
        end
    else
        love.graphics.setColor(palette.barrier)
        love.graphics.rectangle("fill", innerX, innerY, innerW, innerH, 3, 3)
        drawDoorSegments(innerX + 2, innerY + 2, innerW - 4, innerH - 4, isVertical, palette.detail, 0.9)

        love.graphics.setColor(palette.beam)
        if isVertical then
            local beamX = innerX + math.floor((innerW - 4) * 0.5)
            love.graphics.rectangle("fill", beamX, innerY + 3, 4, innerH - 6, 2, 2)
        else
            local beamY = innerY + math.floor((innerH - 4) * 0.5)
            love.graphics.rectangle("fill", innerX + 3, beamY, innerW - 6, 4, 2, 2)
        end
    end
end

local function normalizeDoorSnapshot(door, playWidth, playHeight, cfg)
    if type(door) ~= "table" then
        return nil, nil
    end
    local snapshotEdge = DoorUtils.normalizeEdge(door.edge)
    if not snapshotEdge then
        return nil, nil
    end

    local normalized = DoorUtils.clampDoorToSafeBounds(door, playWidth, playHeight, cfg) or DoorUtils.cloneDoor(door)
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
        entryDoor, entryEdge = normalizeDoorSnapshot(entrySnapshot, playWidth, playHeight, cfg)
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
        exitDoor, exitEdge = normalizeDoorSnapshot(exitSnapshot, playWidth, playHeight, cfg)
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
            return "PRESS ENTER TO GO TO THE NEXT ROOM"
        end
        return "DOOR LOCKED: REPAIR ALL POWER NODES"
    end
    if overlapsDoor(player, playerSize, entryDoor) then
        return "DOOR LOCKED"
    end
    return nil
end

function DoorSystem.draw()
    drawDoor(entryDoor, "entry")
    drawDoor(exitDoor, DoorSystem.isExitOpen() and "open" or "locked")
end

return DoorSystem

-- Owns evacuation lifecycle, countdown, and escape-zone completion.
local EvacuationSystem = {}
local CollisionSystem = require("src/systems/collision_system")

EvacuationSystem.STATES = {
    INACTIVE = "inactive",
    ACTIVE = "active",
    SUCCESS = "success",
    FAILED = "failed"
}

local state = EvacuationSystem.STATES.INACTIVE
local evacuationActive = false
local timeLimitSeconds = 0
local timeRemainingSeconds = 0
local roomClearTimeBonusSeconds = 0
local startedAtRemainingSeconds = 0
local resultAnnounced = false
local escapeZone = nil
local escapeZoneWidthFactor = 0.5
local escapeZoneHeight = 56
local escapeZoneTop = 0
local escapePrompt = "PRESS ENTER TO EVACUATE"
local labelFont = nil

local function clampToNonNegative(value)
    return math.max(0, value or 0)
end

local function ensureLabelFont()
    if labelFont then
        return
    end

    labelFont = love.graphics.newFont("assets/fonts/Minecraftia-Regular.ttf", 26)
    labelFont:setFilter("nearest", "nearest")
end

local function drawDoorIndicator(x, y, radius, color)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.22)
    love.graphics.circle("fill", x, y, radius + 5)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.circle("fill", x, y, radius)
end

local function rebuildEscapeZone(playWidth, playHeight)
    local w = math.max(0, math.floor(playWidth or 0))
    local h = math.max(0, math.floor(playHeight or 0))
    local zoneW = math.max(48, math.floor(w * escapeZoneWidthFactor))
    local zoneH = math.max(18, math.floor(escapeZoneHeight))
    local zoneY = math.max(0, math.min(h - zoneH, math.floor(escapeZoneTop or 0)))
    local zoneX = math.floor((w - zoneW) * 0.5)
    escapeZone = {
        x = zoneX,
        y = zoneY,
        width = zoneW,
        height = zoneH
    }
end

function EvacuationSystem.beginRun(config)
    local cfg = config or {}
    timeLimitSeconds = clampToNonNegative(cfg.timeLimitSeconds)
    timeRemainingSeconds = timeLimitSeconds
    roomClearTimeBonusSeconds = clampToNonNegative(cfg.roomClearTimeBonusSeconds)
    escapeZoneWidthFactor = math.max(0.1, math.min(1.0, cfg.evacuationZoneWidthFactor or 0.5))
    escapeZoneHeight = math.max(12, cfg.evacuationZoneHeight or 56)
    escapeZoneTop = math.max(0, cfg.evacuationZoneTop or 0)
    escapePrompt = cfg.evacuationPrompt or "PRESS ENTER TO EVACUATE"
    escapeZone = nil
    startedAtRemainingSeconds = 0
    evacuationActive = false
    state = EvacuationSystem.STATES.ACTIVE
    resultAnnounced = false
end

function EvacuationSystem.update(dt)
    if state ~= EvacuationSystem.STATES.ACTIVE then
        return nil
    end

    local step = clampToNonNegative(dt)
    if step <= 0 then
        return nil
    end

    timeRemainingSeconds = math.max(0, timeRemainingSeconds - step)
    if timeRemainingSeconds <= 0 then
        state = EvacuationSystem.STATES.FAILED
        return EvacuationSystem.STATES.FAILED
    end

    return nil
end

function EvacuationSystem.onRoomCleared()
    if state ~= EvacuationSystem.STATES.ACTIVE then
        return
    end

    timeRemainingSeconds = timeRemainingSeconds + roomClearTimeBonusSeconds
end

function EvacuationSystem.startEvacuation()
    if state ~= EvacuationSystem.STATES.ACTIVE or evacuationActive then
        return false
    end

    evacuationActive = true
    startedAtRemainingSeconds = timeRemainingSeconds
    return true
end

function EvacuationSystem.isEvacuationActive()
    return evacuationActive and state == EvacuationSystem.STATES.ACTIVE
end

function EvacuationSystem.configureEscapeZone(playWidth, playHeight)
    rebuildEscapeZone(playWidth, playHeight)
end

function EvacuationSystem.getEscapeZone()
    return escapeZone
end

function EvacuationSystem.isPlayerInEscapeZone(player, playerSize)
    if not escapeZone or not player then
        return false
    end

    local size = playerSize or 35
    return CollisionSystem.overlaps(
        player.x or 0,
        player.y or 0,
        size,
        size,
        escapeZone.x,
        escapeZone.y,
        escapeZone.width,
        escapeZone.height
    )
end

function EvacuationSystem.tryComplete(player, playerSize, input)
    if not EvacuationSystem.isEvacuationActive() then
        return false
    end
    if not EvacuationSystem.isPlayerInEscapeZone(player, playerSize) then
        return false
    end

    if not input or not input.interactPressed or not input.interactPressed() then
        return false
    end

    evacuationActive = false
    state = EvacuationSystem.STATES.SUCCESS
    return true
end

function EvacuationSystem.getState()
    return state
end

function EvacuationSystem.getTimeRemaining()
    return timeRemainingSeconds
end

function EvacuationSystem.getTimeLimit()
    return timeLimitSeconds
end

function EvacuationSystem.getRoomClearTimeBonus()
    return roomClearTimeBonusSeconds
end

function EvacuationSystem.getStartedAtRemainingSeconds()
    return startedAtRemainingSeconds
end

function EvacuationSystem.consumeResult()
    if resultAnnounced then
        return nil
    end

    if state == EvacuationSystem.STATES.SUCCESS or state == EvacuationSystem.STATES.FAILED then
        resultAnnounced = true
        return state
    end

    return nil
end

function EvacuationSystem.getPhaseLabel()
    if state == EvacuationSystem.STATES.SUCCESS then
        return "COMPLETE"
    end
    if state == EvacuationSystem.STATES.FAILED then
        return "FAILED"
    end
    if evacuationActive then
        return "EVACUATE"
    end
    return "STABILIZE"
end

function EvacuationSystem.syncWorld(world)
    if not world then
        return
    end
    world.flags = world.flags or {}
    world.flags.evacuationActive = EvacuationSystem.isEvacuationActive()
    world.flags.victory = state == EvacuationSystem.STATES.SUCCESS
    world.flags.gameOver = state == EvacuationSystem.STATES.FAILED
end

function EvacuationSystem.getPrompt(player, playerSize)
    if not EvacuationSystem.isEvacuationActive() then
        return nil
    end

    if EvacuationSystem.isPlayerInEscapeZone(player, playerSize) then
        return escapePrompt
    end

    return nil
end

function EvacuationSystem.draw()
    if not escapeZone or state == EvacuationSystem.STATES.INACTIVE then
        return
    end

    local isActive = EvacuationSystem.isEvacuationActive()
    local t = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
    local pulse = 0.55 + (0.45 * math.abs(math.sin(t * 4.8)))
    local x = escapeZone.x
    local y = escapeZone.y
    local w = escapeZone.width
    local h = escapeZone.height
    local jambW = math.max(16, math.floor(w * 0.04))
    local headerH = math.max(14, math.floor(h * 0.26))
    local innerX = x + jambW + 8
    local innerY = y + headerH
    local innerW = math.max(24, w - ((jambW + 8) * 2))
    local innerH = math.max(12, h - headerH - 6)

    local frameFill = isActive and { 0.08, 0.16, 0.22, 0.9 } or { 0.16, 0.12, 0.14, 0.92 }
    local frameEdge = isActive and { 0.56, 0.94, 1.0, 0.95 } or { 0.98, 0.54, 0.58, 0.94 }
    local frameGlow = isActive
        and { 0.28, 0.88, 1.0, 0.12 + (0.12 * pulse) }
        or { 1.0, 0.30, 0.34, 0.08 + (0.08 * pulse) }
    local recess = isActive and { 0.03, 0.07, 0.10, 0.88 } or { 0.08, 0.05, 0.06, 0.88 }
    local barrier = isActive
        and { 0.28, 0.90, 1.0, 0.18 + (0.18 * pulse) }
        or { 0.92, 0.18, 0.22, 0.28 + (0.08 * pulse) }
    local detail = isActive
        and { 0.84, 1.0, 1.0, 0.85 }
        or { 1.0, 0.74, 0.74, 0.9 }
    local label = isActive and "EVAC DOOR OPEN" or "EVAC DOOR LOCKED"

    love.graphics.setColor(frameFill)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setColor(frameGlow)
    love.graphics.rectangle("fill", x + 12, y + 7, w - 24, 4, 3, 3)
    love.graphics.setColor(frameFill)
    love.graphics.rectangle("fill", x + 6, y + 6, jambW, h - 12, 4, 4)
    love.graphics.rectangle("fill", x + w - jambW - 6, y + 6, jambW, h - 12, 4, 4)
    love.graphics.rectangle("fill", innerX - 2, y + 6, innerW + 4, headerH - 4, 4, 4)
    love.graphics.setColor(frameEdge)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(recess)
    love.graphics.rectangle("fill", innerX, innerY, innerW, innerH, 4, 4)
    if isActive then
        local railH = math.max(4, math.floor(innerH * 0.3))
        love.graphics.setColor(barrier)
        love.graphics.rectangle("fill", innerX, innerY, innerW, railH, 3, 3)
        love.graphics.rectangle("fill", innerX, innerY + innerH - railH, innerW, railH, 3, 3)
        love.graphics.setColor(detail[1], detail[2], detail[3], 0.35 + (0.25 * pulse))
        for cx = innerX + 18, innerX + innerW - 18, math.max(26, math.floor(innerW * 0.14)) do
            love.graphics.rectangle("fill", cx, innerY + 4, 4, innerH - 8, 2, 2)
        end
    else
        love.graphics.setColor(barrier)
        love.graphics.rectangle("fill", innerX, innerY, innerW, innerH, 4, 4)
        love.graphics.setColor(detail)
        for slatY = innerY + 5, innerY + innerH - 8, 10 do
            love.graphics.rectangle("fill", innerX + 8, slatY, innerW - 16, 4, 2, 2)
        end
        love.graphics.setColor(1.0, 0.82, 0.82, 0.92)
        love.graphics.rectangle("fill", innerX + math.floor((innerW - 6) * 0.5), innerY + 4, 6, innerH - 8, 2, 2)
    end

    drawDoorIndicator(x + 18, y + 18, 5, detail)
    drawDoorIndicator(x + w - 18, y + 18, 5, detail)

    ensureLabelFont()
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(labelFont)
    local textW = labelFont:getWidth(label)
    local textY = y + math.max(2, math.floor((headerH - labelFont:getHeight()) * 0.5))
    love.graphics.setColor(0.92, 0.98, 1.0, 0.95)
    love.graphics.print(label, x + (w - textW) * 0.5, textY)
    love.graphics.setFont(prevFont)
end

return EvacuationSystem

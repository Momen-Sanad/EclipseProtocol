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

local function clampToNonNegative(value)
    return math.max(0, value or 0)
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
    local fill = isActive and { 0.23, 0.72, 0.96, 0.33 } or { 0.30, 0.33, 0.38, 0.3 }
    local edge = isActive and { 0.45, 0.92, 1.0, 0.95 } or { 0.72, 0.75, 0.8, 0.85 }
    local label = isActive and "EVAC ZONE" or "EVAC LOCKED"

    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", escapeZone.x, escapeZone.y, escapeZone.width, escapeZone.height, 6, 6)
    love.graphics.setColor(edge)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", escapeZone.x, escapeZone.y, escapeZone.width, escapeZone.height, 6, 6)
    love.graphics.setLineWidth(1)

    local font = love.graphics.getFont()
    local textW = font:getWidth(label)
    love.graphics.setColor(0.92, 0.98, 1.0, 0.95)
    love.graphics.print(label, escapeZone.x + (escapeZone.width - textW) * 0.5, escapeZone.y + 6)
end

return EvacuationSystem

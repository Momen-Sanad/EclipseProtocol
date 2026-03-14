-- Owns evacuation lifecycle and countdown outcome.
local EvacuationSystem = {}

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

local function clampToNonNegative(value)
    return math.max(0, value or 0)
end

function EvacuationSystem.beginRun(config)
    local cfg = config or {}
    timeLimitSeconds = clampToNonNegative(cfg.timeLimitSeconds)
    timeRemainingSeconds = timeLimitSeconds
    roomClearTimeBonusSeconds = clampToNonNegative(cfg.roomClearTimeBonusSeconds)
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
    if timeRemainingSeconds > 0 then
        return nil
    end

    if evacuationActive then
        state = EvacuationSystem.STATES.SUCCESS
        return EvacuationSystem.STATES.SUCCESS
    end

    state = EvacuationSystem.STATES.FAILED
    return EvacuationSystem.STATES.FAILED
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

return EvacuationSystem

-- Shared urgency progression helpers for time-based visual/audio escalation.
local UrgencyUtils = {}

function UrgencyUtils.clamp01(value)
    if value <= 0 then
        return 0
    end
    if value >= 1 then
        return 1
    end
    return value
end

function UrgencyUtils.windowProgress(timeRemaining, startSeconds)
    local start = math.max(1, startSeconds or 60)
    local remaining = math.max(0, timeRemaining or 0)
    if remaining > start then
        return 0, false
    end
    return UrgencyUtils.clamp01(1 - (remaining / start)), true
end

function UrgencyUtils.smoothstep01(value)
    local t = UrgencyUtils.clamp01(value)
    return t * t * (3 - (2 * t))
end

return UrgencyUtils

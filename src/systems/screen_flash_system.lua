-- Lightweight full-screen color flash used for damage and other impact events.
local UrgencyUtils = require("src/utils/urgency_utils")

local ScreenFlashSystem = {}

local flashColor = { 1.0, 0.15, 0.15 }
local flashAlpha = 0
local flashDuration = 0
local flashTimer = 0
local warningTimer = 0

local DEFAULT_WARNING_START_SECONDS = 60
local WARNING_MIN_BLINK_HZ = 1.2
local WARNING_MAX_BLINK_HZ = 6.8
local WARNING_MIN_ALPHA = 0.10
local WARNING_MAX_ALPHA = 0.70
local WARNING_BASE_THICKNESS = 6
local WARNING_MAX_THICKNESS_FACTOR = 0.16

local function lerp(a, b, t)
    return a + ((b - a) * UrgencyUtils.clamp01(t))
end

function ScreenFlashSystem.reset()
    -- Clears any active flash so new states start from a clean visual baseline.
    flashAlpha = 0
    flashDuration = 0
    flashTimer = 0
    warningTimer = 0
end

function ScreenFlashSystem.trigger(color, alpha, duration)
    -- Starts a new flash using caller overrides with safe defaults/clamping.
    local nextDuration = math.max(0.01, duration or 0.12)
    local nextAlpha = math.max(0, math.min(1, alpha or 0.35))
    local c = color or flashColor

    flashColor[1] = c[1] or 1.0
    flashColor[2] = c[2] or 0.15
    flashColor[3] = c[3] or 0.15
    flashAlpha = nextAlpha
    flashDuration = nextDuration
    flashTimer = nextDuration
end

function ScreenFlashSystem.update(dt)
    -- Decreases timer each frame; draw intensity is derived from remaining time.
    warningTimer = warningTimer + math.max(0, dt or 0)

    if flashTimer <= 0 then
        return
    end
    flashTimer = math.max(0, flashTimer - (dt or 0))
end

function ScreenFlashSystem.drawEvacuationWarning(timeRemaining, opts)
    -- Draws a blinking red edge warning that intensifies during the final minute.
    local config = opts or {}
    local startSeconds = math.max(1, config.startSeconds or DEFAULT_WARNING_START_SECONDS)
    local remaining = math.max(0, timeRemaining or 0)
    if remaining > startSeconds then
        return
    end

    local w, h = love.graphics.getDimensions()
    if w <= 0 or h <= 0 then
        return
    end

    local urgency = UrgencyUtils.windowProgress(remaining, startSeconds)
    local blinkHz = lerp(WARNING_MIN_BLINK_HZ, WARNING_MAX_BLINK_HZ, urgency)
    local pulse = 0.5 + (0.5 * math.sin((warningTimer * blinkHz) * math.pi * 2))
    local alpha = lerp(WARNING_MIN_ALPHA, WARNING_MAX_ALPHA, urgency) * (0.3 + (0.7 * pulse))
    local maxThickness = math.max(WARNING_BASE_THICKNESS + 1, math.floor(math.min(w, h) * WARNING_MAX_THICKNESS_FACTOR))
    local thickness = math.floor(lerp(WARNING_BASE_THICKNESS, maxThickness, urgency) + 0.5)

    local color = config.color or { 1.0, 0.08, 0.08 }
    love.graphics.setColor(color[1] or 1.0, color[2] or 0.08, color[3] or 0.08, alpha)
    love.graphics.rectangle("fill", 0, 0, w, thickness)
    love.graphics.rectangle("fill", 0, h - thickness, w, thickness)
    love.graphics.rectangle("fill", 0, thickness, thickness, math.max(0, h - (thickness * 2)))
    love.graphics.rectangle("fill", w - thickness, thickness, thickness, math.max(0, h - (thickness * 2)))
    love.graphics.setColor(1, 1, 1, 1)
end

function ScreenFlashSystem.draw()
    -- Renders a full-screen tinted overlay that fades out linearly over duration.
    if flashTimer <= 0 or flashDuration <= 0 or flashAlpha <= 0 then
        return
    end

    local intensity = flashTimer / flashDuration
    local alpha = flashAlpha * intensity
    if alpha <= 0 then
        return
    end

    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(flashColor[1], flashColor[2], flashColor[3], alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

return ScreenFlashSystem

-- Lightweight full-screen color flash used for damage and other impact events.
local ScreenFlashSystem = {}

local flashColor = { 1.0, 0.15, 0.15 }
local flashAlpha = 0
local flashDuration = 0
local flashTimer = 0

function ScreenFlashSystem.reset()
    -- Clears any active flash so new states start from a clean visual baseline.
    flashAlpha = 0
    flashDuration = 0
    flashTimer = 0
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
    if flashTimer <= 0 then
        return
    end
    flashTimer = math.max(0, flashTimer - (dt or 0))
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

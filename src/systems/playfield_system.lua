-- Handles playfield background fill and play-area sizing.
local PlayfieldSystem = {}

local windowWidth = 0
local windowHeight = 0
local DEFAULT_PLAYFIELD_COLOR = { 0.12, 0.20, 0.36, 1.0 }

local function refreshViewport()
    -- Recomputes the cached viewport size whenever window dimensions change.
    local w, h = love.graphics.getDimensions()
    if w == windowWidth and h == windowHeight then
        return
    end

    windowWidth = w
    windowHeight = h
end

function PlayfieldSystem.ensureBackground()
    -- Keeps cached viewport dimensions current for gameplay sizing.
    refreshViewport()
end

function PlayfieldSystem.getPlayAreaSize(fallbackWidth, fallbackHeight)
    -- Returns current render size; falls back when window info is not ready.
    refreshViewport()

    local w = windowWidth
    local h = windowHeight

    if w <= 0 or h <= 0 then
        w = fallbackWidth or 1280
        h = fallbackHeight or 720
    end

    return w, h
end

function PlayfieldSystem.drawBackground(color)
    -- Draws a flat playfield color behind all gameplay layers.
    PlayfieldSystem.ensureBackground()

    local fill = color or DEFAULT_PLAYFIELD_COLOR
    love.graphics.setColor(fill[1] or DEFAULT_PLAYFIELD_COLOR[1], fill[2] or DEFAULT_PLAYFIELD_COLOR[2], fill[3] or DEFAULT_PLAYFIELD_COLOR[3], fill[4] or 1)
    love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)
    love.graphics.setColor(1, 1, 1, 1)
end

return PlayfieldSystem

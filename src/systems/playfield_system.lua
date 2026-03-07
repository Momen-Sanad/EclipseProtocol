-- Handles playfield background loading/scaling and play-area sizing.
local PlayfieldSystem = {}

local bg = nil
local bgPath = nil
local bgScale = 1
local bgOffsetX = 0
local bgOffsetY = 0
local windowWidth = 0
local windowHeight = 0

local function refreshBackground()
    if not bg then
        return
    end

    local w, h = love.graphics.getDimensions()
    if w == windowWidth and h == windowHeight then
        return
    end

    windowWidth = w
    windowHeight = h

    local bgW = bg:getWidth()
    local bgH = bg:getHeight()
    bgScale = math.max(windowWidth / bgW, windowHeight / bgH)
    bgOffsetX = (windowWidth - bgW * bgScale) / 2
    bgOffsetY = (windowHeight - bgH * bgScale) / 2
end

function PlayfieldSystem.ensureBackground(path)
    local nextPath = path or "assets/ui/background.png"
    if not bg or bgPath ~= nextPath then
        bg = love.graphics.newImage(nextPath)
        bgPath = nextPath
        windowWidth = 0
        windowHeight = 0
    end
    refreshBackground()
end

function PlayfieldSystem.getPlayAreaSize(fallbackWidth, fallbackHeight)
    refreshBackground()

    local w = windowWidth
    local h = windowHeight

    if w <= 0 or h <= 0 then
        w = fallbackWidth or 1280
        h = fallbackHeight or 720
    end

    return w, h
end

function PlayfieldSystem.drawBackground(path)
    PlayfieldSystem.ensureBackground(path)
    if not bg then
        return
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg, bgOffsetX, bgOffsetY, 0, bgScale, bgScale)
end

return PlayfieldSystem

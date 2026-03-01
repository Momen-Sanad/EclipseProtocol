local StateManager = require("src/core/state_manager")

local GameOverState = {}

local font = nil
local fadeTime = 0
local fadeDuration = 1.0

local function ensureFont()
    if font then
        return
    end
    font = love.graphics.newFont("assets/fonts/Minecraftia-Regular.ttf", 72)
    font:setFilter("nearest", "nearest")
end

function GameOverState.enter()
    ensureFont()
    fadeTime = 0
end

function GameOverState.update(dt)
    if fadeTime < fadeDuration then
        fadeTime = math.min(fadeDuration, fadeTime + dt)
    end
end

function GameOverState.keypressed(key)
    local _ = key
    StateManager.change("menu")
end

function GameOverState.draw()
    ensureFont()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setFont(font)
    local alpha = 1.0
    if fadeDuration > 0 then
        alpha = math.max(0, math.min(1, fadeTime / fadeDuration))
    end
    love.graphics.setColor(0.90, 0.20, 0.20, alpha)
    local text = "GAME OVER"
    local x = math.floor((w - font:getWidth(text)) / 2)
    local y = math.floor((h - font:getHeight()) / 2)
    love.graphics.print(text, x, y)
end

return GameOverState

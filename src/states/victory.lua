local StateManager = require("src/core/state_manager")

local VictoryState = {}

local font = nil

local function ensureFont()
    if font then
        return
    end
    font = love.graphics.newFont("assets/fonts/Minecraftia-Regular.ttf", 72)
    font:setFilter("nearest", "nearest")
end

function VictoryState.enter()
    ensureFont()
end

function VictoryState.keypressed(key)
    local _ = key
    StateManager.change("menu")
end

function VictoryState.draw()
    ensureFont()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setFont(font)
    love.graphics.setColor(0.20, 0.90, 0.45, 1.0)
    local text = "VICTORY"
    local x = math.floor((w - font:getWidth(text)) / 2)
    local y = math.floor((h - font:getHeight()) / 2)
    love.graphics.print(text, x, y)
end

return VictoryState

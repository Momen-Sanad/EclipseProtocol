local HealthBar = require("src/ui/health_bar")
local EnergyBar = require("src/ui/energy_bar")

local Hud = {}

local font = nil

local function ensureFont()
    if font then
        return
    end
    font = love.graphics.newFont("assets/fonts/Minecraftia-Regular.ttf", 14)
    font:setFilter("nearest", "nearest")
end

local function formatTime(seconds)
    local total = math.max(0, math.floor(seconds or 0))
    local mins = math.floor(total / 60)
    local secs = total % 60
    return string.format("%02d:%02d", mins, secs)
end

function Hud.draw(player, elapsedTime)
    if not player then
        return
    end

    ensureFont()
    love.graphics.setFont(font)

    local padding = 24
    local barW = 360
    local barH = 34

    HealthBar.draw(padding, padding, barW, barH, player.health, player.maxHealth, "HEALTH")

    local energyY = padding + barH + 14
    EnergyBar.draw(padding, energyY, barW, barH, player.energy, player.maxEnergy, "ENERGY")

    if elapsedTime ~= nil then
        local w = love.graphics.getWidth()
        local label = "TIME " .. formatTime(elapsedTime)
        local textW = font:getWidth(label)
        love.graphics.setColor(0.78, 0.90, 0.95, 1.0)
        love.graphics.print(label, w - textW - padding, padding)
    end
end

return Hud

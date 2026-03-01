local HealthBar = require("src/ui/health_bar")
local EnergyBar = require("src/ui/energy_bar")

local Hud = {}

local font = nil

local function ensureFont()
    if font then
        return
    end
    font = love.graphics.newFont(12)
    font:setFilter("nearest", "nearest")
end

function Hud.draw(player)
    if not player then
        return
    end

    ensureFont()
    love.graphics.setFont(font)

    local padding = 24
    local barW = 260
    local barH = 16

    HealthBar.draw(padding, padding, barW, barH, player.health, player.maxHealth)
    love.graphics.setColor(0.78, 0.90, 0.95, 1.0)
    love.graphics.print("HP", padding + barW + 10, padding - 2)

    local energyY = padding + barH + 12
    EnergyBar.draw(padding, energyY, barW, barH, player.energy, player.maxEnergy)
    love.graphics.setColor(0.78, 0.90, 0.95, 1.0)
    love.graphics.print("EN", padding + barW + 10, energyY - 2)
end

return Hud

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

function Hud.draw(player)
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
end

return Hud

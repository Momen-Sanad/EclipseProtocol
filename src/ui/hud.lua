local HealthBar = require("src/ui/health_bar")
local EnergyBar = require("src/ui/energy_bar")

local Hud = {}

local font = nil
local dashIcon = nil

local function ensureFont()
    if font then
        return
    end
    font = love.graphics.newFont("assets/fonts/Minecraftia-Regular.ttf", 14)
    font:setFilter("nearest", "nearest")
end

local function ensureDashIcon()
    if dashIcon then
        return
    end
    dashIcon = love.graphics.newImage("assets/ui/Dash.png")
end

local function formatTime(seconds)
    local total = math.max(0, math.floor(seconds or 0))
    local mins = math.floor(total / 60)
    local secs = total % 60
    return string.format("%02d:%02d", mins, secs)
end

local function drawDashCooldown(x, y, radius, remaining, total, font)
    local cooldown = total or 0
    local timeLeft = math.max(0, remaining or 0)
    if cooldown <= 0 then
        return
    end

    local progress = 1 - (timeLeft / cooldown)
    progress = math.max(0, math.min(1, progress))

    if timeLeft <= 0 then
        return
    end

    local startAngle = -math.pi / 2
    local endAngle = startAngle + (math.pi * 2 * progress)

    love.graphics.setLineWidth(6)
    love.graphics.setColor(0.10, 0.18, 0.26, 0.8)
    love.graphics.circle("line", x, y, radius)

    love.graphics.setLineWidth(10)
    love.graphics.setColor(0.12, 0.55, 0.9, 0.18)
    love.graphics.arc("line", "open", x, y, radius + 2, startAngle, endAngle)

    love.graphics.setLineWidth(5)
    love.graphics.setColor(0.35, 0.85, 1.0, 0.95)
    love.graphics.arc("line", "open", x, y, radius, startAngle, endAngle)

    local label = string.format("%.1f", timeLeft)
    local textW = font:getWidth(label)
    local textH = font:getHeight()
    love.graphics.setColor(0.05, 0.12, 0.18, 0.9)
    love.graphics.print(label, x - textW / 2 + 1, y - textH / 2 + 1)
    love.graphics.setColor(0.82, 0.94, 1.0, 1.0)
    love.graphics.print(label, x - textW / 2, y - textH / 2)

    love.graphics.setLineWidth(1)
end

function Hud.draw(player, elapsedTime, score)
    if not player then
        return
    end

    ensureFont()
    ensureDashIcon()
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

        local fpsLabel = "FPS " .. tostring(love.timer.getFPS())
        local fpsW = font:getWidth(fpsLabel)
        love.graphics.setColor(0.70, 0.82, 0.88, 1.0)
        love.graphics.print(fpsLabel, w - fpsW - padding, padding + font:getHeight() + 6)

        if player.dashCooldown and dashIcon then
            local iconW = dashIcon:getWidth()
            local iconH = dashIcon:getHeight()
            local iconTarget = 300
            local iconScale = iconTarget / math.max(iconW, iconH)
            local drawW = iconW * iconScale
            local drawH = iconH * iconScale
            local panelPad = 12
            local panelW = drawW + panelPad * 2
            local panelH = drawH + panelPad * 2
            local px = padding
            local py = love.graphics.getHeight() - panelH - padding
            local ix = px + panelPad
            local iy = py + panelPad

            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.draw(dashIcon, ix, iy, 0, iconScale, iconScale)

            local radius = math.max(drawW, drawH) * 0.36
            local cx = ix + drawW / 2
            local cy = iy + drawH / 2
            drawDashCooldown(cx, cy, radius, player.dashCooldownTimer or 0, player.dashCooldown, font)
        end
    end

    if score ~= nil then
        local scoreLabel = "CELLS " .. tostring(score)
        love.graphics.setColor(0.90, 0.92, 0.96, 1.0)
        love.graphics.print(scoreLabel, padding, energyY + barH + 12)
    end
end

return Hud

-- High-level HUD renderer for bars, timer, score, and dash cooldown feedback.
local HealthBar = require("src/ui/health_bar")
local EnergyBar = require("src/ui/energy_bar")

local Hud = {}

local font = nil
local dashIcon = nil

local function ensureFont()
    -- Lazily load HUD assets so entering the module does not allocate immediately.
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
    -- Draw a radial timer on top of the dash icon while the ability is cooling down.
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

local function drawStunGunPanel(player, x, y, w, h)
    local cost = math.max(0, math.floor(player.stunGunEnergyCost or 0))
    local cooldownTotal = math.max(0, player.stunGunCooldown or 0)
    local cooldownLeft = math.max(0, player.stunGunCooldownTimer or 0)
    local hasEnergy = (player.energy or 0) >= cost
    local onCooldown = cooldownLeft > 0
    local ready = (not onCooldown) and hasEnergy

    local panelCol = { 0.10, 0.13, 0.18, 0.85 }
    local edgeCol = { 0.28, 0.34, 0.42, 0.95 }
    local textCol = { 0.88, 0.92, 0.98, 1.0 }
    local readyCol = { 0.30, 0.92, 0.45, 1.0 }
    local waitCol = { 0.95, 0.78, 0.26, 1.0 }
    local blockedCol = { 1.0, 0.35, 0.35, 1.0 }

    love.graphics.setColor(panelCol)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setColor(edgeCol)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)

    love.graphics.setColor(textCol)
    love.graphics.print("STUN GUN (Q)", x + 10, y + 6)
    love.graphics.print("COST " .. tostring(cost) .. " EN", x + 10, y + 22)

    local statusLabel = "READY"
    local statusCol = readyCol
    if onCooldown then
        statusLabel = string.format("COOLDOWN %.1fs", cooldownLeft)
        statusCol = waitCol
    elseif not hasEnergy then
        statusLabel = "NOT ENOUGH ENERGY"
        statusCol = blockedCol
    end

    love.graphics.setColor(statusCol)
    love.graphics.print(statusLabel, x + 10, y + 36)

    local barX = x + 10
    local barY = y + h - 10
    local barW = w - 20
    local barH = 6
    love.graphics.setColor(0.14, 0.18, 0.24, 1.0)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 2, 2)

    local cooldownFill = 1
    if cooldownTotal > 0 then
        cooldownFill = 1 - (cooldownLeft / cooldownTotal)
    end
    cooldownFill = math.max(0, math.min(1, cooldownFill))
    love.graphics.setColor(statusCol[1], statusCol[2], statusCol[3], 0.95)
    love.graphics.rectangle("fill", barX, barY, barW * cooldownFill, barH, 2, 2)
end

function Hud.draw(player, elapsedTime, score)
    -- The HUD reads player state only; it does not mutate gameplay state.
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
    if player.stunGunCooldown ~= nil or player.stunGunEnergyCost ~= nil then
        local panelW = 230
        local panelH = 62
        local px = love.graphics.getWidth() - panelW - padding
        local py = love.graphics.getHeight() - panelH - padding
        drawStunGunPanel(player, px, py, panelW, panelH)
    end
        -- The timer and score are drawn after the bars so they appear on top. They read from the same player state but do not affect it, so they can be safely rendered in any order.
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

        -- Draw the dash cooldown indicator in the bottom left corner if the player has the ability and it is on cooldown.
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

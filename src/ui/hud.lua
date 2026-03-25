-- High-level HUD renderer for player resources, telemetry, and ability readiness.
local HealthBar = require("src/ui/health_bar")
local EnergyBar = require("src/ui/energy_bar")

local Hud = {}

local font = nil
local smallFont = nil
local dashIcon = nil

local COL = {
    panel = { 0.08, 0.12, 0.18, 0.84 },
    panelEdge = { 0.48, 0.60, 0.78, 0.9 },
    panelGlow = { 0.52, 0.74, 0.98, 0.12 },
    text = { 0.90, 0.95, 1.0, 1.0 },
    textDim = { 0.68, 0.79, 0.92, 0.95 },
    textMuted = { 0.56, 0.68, 0.80, 0.92 }
}

local function ensureFonts()
    -- Lazily load HUD fonts so the play state only allocates them on demand.
    if font and smallFont then
        return
    end

    font = love.graphics.newFont("assets/fonts/Minecraftia-Regular.ttf", 14)
    smallFont = love.graphics.newFont("assets/fonts/Minecraftia-Regular.ttf", 12)
    font:setFilter("nearest", "nearest")
    smallFont:setFilter("nearest", "nearest")
end

local function ensureDashIcon()
    -- Dash icon texture is reused every frame once loaded.
    if dashIcon then
        return
    end
    dashIcon = love.graphics.newImage("assets/ui/Dash.png")
end

local function formatTime(seconds)
    -- Converts elapsed seconds into MM:SS string for HUD display.
    local total = math.max(0, math.floor(seconds or 0))
    local mins = math.floor(total / 60)
    local secs = total % 60
    return string.format("%02d:%02d", mins, secs)
end

local function drawShadowedText(fontObj, text, x, y, color, shadow)
    love.graphics.setFont(fontObj)
    love.graphics.setColor(shadow[1], shadow[2], shadow[3], shadow[4] or 1)
    love.graphics.print(text, x + 1, y + 1)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.print(text, x, y)
end

local function drawPanel(x, y, w, h)
    love.graphics.setColor(COL.panel)
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)
    love.graphics.setColor(COL.panelGlow)
    love.graphics.rectangle("fill", x + 10, y + 8, w - 20, 4, 3, 3)
    love.graphics.setColor(COL.panelEdge)
    love.graphics.rectangle("line", x, y, w, h, 10, 10)
end

local function drawDashCooldown(x, y, radius, remaining, total, fontObj)
    -- Draw a radial timer on top of the dash icon while the ability is cooling down.
    local cooldown = total or 0
    local timeLeft = math.max(0, remaining or 0)
    if cooldown <= 0 or timeLeft <= 0 then
        return
    end

    local progress = 1 - (timeLeft / cooldown)
    progress = math.max(0, math.min(1, progress))

    local startAngle = -math.pi / 2
    local endAngle = startAngle + (math.pi * 2 * progress)

    love.graphics.setLineWidth(6)
    love.graphics.setColor(0.08, 0.13, 0.20, 0.88)
    love.graphics.circle("line", x, y, radius)

    love.graphics.setLineWidth(10)
    love.graphics.setColor(0.12, 0.55, 0.9, 0.16)
    love.graphics.arc("line", "open", x, y, radius + 2, startAngle, endAngle)

    love.graphics.setLineWidth(5)
    love.graphics.setColor(0.35, 0.85, 1.0, 0.95)
    love.graphics.arc("line", "open", x, y, radius, startAngle, endAngle)

    local label = string.format("%.1f", timeLeft)
    local textW = fontObj:getWidth(label)
    local textH = fontObj:getHeight()
    drawShadowedText(
        fontObj,
        label,
        x - (textW / 2),
        y - (textH / 2),
        COL.text,
        { 0.03, 0.06, 0.1, 0.95 }
    )

    love.graphics.setLineWidth(1)
end

local function drawCellsChip(x, y, w, h, cellsCollected)
    drawPanel(x, y, w, h)

    local value = tostring(math.max(0, math.floor(cellsCollected or 0)))
    drawShadowedText(smallFont, "CELLS", x + 12, y + 7, COL.textDim, { 0.02, 0.04, 0.08, 0.95 })
    drawShadowedText(
        font,
        value,
        x + w - 12 - font:getWidth(value),
        y + 5,
        COL.text,
        { 0.02, 0.04, 0.08, 0.95 }
    )
end

local function drawTelemetryPanel(x, y, w, elapsedTime, options)
    local lines = {}
    if elapsedTime ~= nil then
        table.insert(lines, {
            label = "RUN",
            value = formatTime(elapsedTime),
            color = COL.text
        })
    end

    if options and options.timeRemaining ~= nil then
        table.insert(lines, {
            label = options.timerLabel or "TIMER",
            value = formatTime(options.timeRemaining),
            color = options.timerColor or COL.text
        })
    end

    if options and options.showDebug then
        table.insert(lines, {
            label = "FPS",
            value = tostring(love.timer.getFPS()),
            color = COL.textMuted
        })
    end

    if #lines == 0 then
        return
    end

    local rowH = font:getHeight() + 8
    local panelH = 12 + (#lines * rowH) + 8
    drawPanel(x, y, w, panelH)

    for i, line in ipairs(lines) do
        local rowY = y + 10 + ((i - 1) * rowH)
        drawShadowedText(smallFont, line.label, x + 12, rowY + 2, COL.textDim, { 0.02, 0.04, 0.08, 0.95 })
        drawShadowedText(
            font,
            line.value,
            x + w - 12 - font:getWidth(line.value),
            rowY,
            line.color,
            { 0.02, 0.04, 0.08, 0.95 }
        )
    end
end

local function drawStunGunPanel(player, x, y, w, h)
    -- Bottom-right panel showing stun gun cost/cooldown/readiness.
    local cost = math.max(0, math.floor(player.stunGunEnergyCost or 0))
    local cooldownTotal = math.max(0, player.stunGunCooldown or 0)
    local cooldownLeft = math.max(0, player.stunGunCooldownTimer or 0)
    local hasEnergy = (player.energy or 0) >= cost
    local onCooldown = cooldownLeft > 0

    local readyCol = { 0.32, 0.94, 0.48, 1.0 }
    local waitCol = { 1.0, 0.82, 0.34, 1.0 }
    local blockedCol = { 1.0, 0.42, 0.42, 1.0 }

    drawPanel(x, y, w, h)

    drawShadowedText(smallFont, "STUN GUN", x + 12, y + 8, COL.text, { 0.02, 0.04, 0.08, 0.95 })
    drawShadowedText(smallFont, "Q", x + w - 18 - smallFont:getWidth("Q"), y + 8, COL.textDim, { 0.02, 0.04, 0.08, 0.95 })
    drawShadowedText(smallFont, "COST " .. tostring(cost) .. " EN", x + 12, y + 28, COL.textDim, { 0.02, 0.04, 0.08, 0.95 })

    local statusLabel = "READY"
    local statusCol = readyCol
    if onCooldown then
        statusLabel = string.format("COOLDOWN %.1fs", cooldownLeft)
        statusCol = waitCol
    elseif not hasEnergy then
        statusLabel = "NOT ENOUGH ENERGY"
        statusCol = blockedCol
    end

    drawShadowedText(smallFont, statusLabel, x + 12, y + 46, statusCol, { 0.02, 0.04, 0.08, 0.95 })

    local barX = x + 12
    local barY = y + h - 12
    local barW = w - 24
    local barH = 6
    love.graphics.setColor(0.12, 0.16, 0.24, 1.0)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 3, 3)

    local cooldownFill = 1
    if cooldownTotal > 0 then
        cooldownFill = 1 - (cooldownLeft / cooldownTotal)
    end
    cooldownFill = math.max(0, math.min(1, cooldownFill))
    love.graphics.setColor(statusCol[1], statusCol[2], statusCol[3], 0.95)
    love.graphics.rectangle("fill", barX, barY, barW * cooldownFill, barH, 3, 3)
end

function Hud.draw(player, elapsedTime, cellsCollected, options)
    -- The HUD reads player state only; it does not mutate gameplay state.
    if not player then
        return
    end

    ensureFonts()
    ensureDashIcon()
    love.graphics.setFont(font)

    local padding = 24
    local barW = 360
    local barH = 32

    local leftX = padding
    local topY = padding
    local clusterX = leftX - 10
    local clusterY = topY - 10
    local energyY = topY + barH + 12
    local cellsH = 30
    local cellsY = energyY + barH + 10
    local clusterH = (cellsY - clusterY) + cellsH + 12
    drawPanel(clusterX, clusterY, barW + 20, clusterH)

    HealthBar.draw(leftX, topY, barW, barH, player.health, player.maxHealth, "HEALTH")
    EnergyBar.draw(leftX, energyY, barW, barH, player.energy, player.maxEnergy, "ENERGY")
    drawCellsChip(leftX, cellsY, 150, cellsH, cellsCollected)

    drawTelemetryPanel(
        love.graphics.getWidth() - 200 - padding,
        padding,
        200,
        elapsedTime,
        options
    )

    if player.dashCooldown and dashIcon then
        -- Keep the dash affordance large and icon-first so it matches the earlier presentation.
        local iconW = dashIcon:getWidth()
        local iconH = dashIcon:getHeight()
        local iconTarget = 300
        local iconScale = iconTarget / math.max(iconW, iconH)
        local drawW = iconW * iconScale
        local drawH = iconH * iconScale
        local panelPad = 12
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

    if player.stunGunCooldown ~= nil or player.stunGunEnergyCost ~= nil then
        local panelW = 238
        local panelH = 76
        local px = love.graphics.getWidth() - panelW - padding
        local py = love.graphics.getHeight() - panelH - padding
        drawStunGunPanel(player, px, py, panelW, panelH)
    end
end

return Hud

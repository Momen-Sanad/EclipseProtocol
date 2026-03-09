-- Segmented HUD widget for the player's health resource.
local HealthBar = {}

local function drawLabel(text, x, y, color)
    -- Draw text with a 1px shadow-style outline for readability.
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.print(text, x - 1, y)
    love.graphics.print(text, x + 1, y)
    love.graphics.print(text, x, y - 1)
    love.graphics.print(text, x, y + 1)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.print(text, x, y)
end

function HealthBar.draw(x, y, w, h, current, max, label)
    -- The fill is quantized into segments so changes are easy to read at a glance.
    local value = current or 0
    local maxValue = max or 1
    local pct = 0
    if maxValue > 0 then
        pct = math.max(0, math.min(1, value / maxValue))
    end

    local frameCol = { 0.32, 0.36, 0.42, 0.95 }
    local insetCol = { 0.12, 0.14, 0.18, 0.9 }
    local slotCol = { 0.22, 0.25, 0.30, 1.0 }
    local fillCol = { 0.35, 0.95, 0.45, 0.95 }
    local glowCol = { 0.40, 0.95, 0.55, 0.35 }
    local labelCol = { 0.45, 0.98, 0.60, 1.0 }

    love.graphics.setColor(frameCol)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)

    love.graphics.setColor(insetCol)
    love.graphics.rectangle("fill", x + 4, y + 4, w - 8, h - 8, 6, 6)

    love.graphics.setColor(glowCol)
    love.graphics.rectangle("fill", x + 2, y + 3, 4, h - 6, 2, 2)
    love.graphics.rectangle("fill", x + w - 6, y + 3, 4, h - 6, 2, 2)

    love.graphics.setColor(0.70, 0.80, 0.90, 0.12)
    love.graphics.rectangle("fill", x + 8, y + 6, w - 16, 2, 2, 2)

    local labelText = label or "HEALTH"
    local labelX = x + 14
    local labelY = y + math.floor((h - love.graphics.getFont():getHeight()) / 2)
    drawLabel(labelText, labelX, labelY, labelCol)

    local labelArea = 120
    local barX = x + labelArea
    local barY = y + 6
    local barW = w - labelArea - 10
    local barH = h - 12
    if barW < 40 then
        barW = 40
    end

    local segments = 10
    local gap = 4
    local segW = math.floor((barW - gap * (segments - 1)) / segments)
    local segH = barH
    if segW < 6 then
        segW = 6
    end

    local filled = math.floor(pct * segments + 0.0001)

    for i = 1, segments do
        local sx = barX + (i - 1) * (segW + gap)
        love.graphics.setColor(slotCol)
        love.graphics.rectangle("fill", sx, barY, segW, segH, 2, 2)
        if i <= filled then
            love.graphics.setColor(fillCol)
            love.graphics.rectangle("fill", sx + 1, barY + 1, segW - 2, segH - 2, 2, 2)
        end
    end

    love.graphics.setColor(0.45, 0.50, 0.58, 0.9)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
end

return HealthBar

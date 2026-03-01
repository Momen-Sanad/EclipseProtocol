local EnergyBar = {}

function EnergyBar.draw(x, y, w, h, current, max)
    local value = current or 0
    local maxValue = max or 1
    local pct = 0
    if maxValue > 0 then
        pct = math.max(0, math.min(1, value / maxValue))
    end

    love.graphics.setColor(0.10, 0.13, 0.17, 0.85)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)

    love.graphics.setColor(0.90, 0.80, 0.20, 0.9)
    love.graphics.rectangle("fill", x, y, w * pct, h, 6, 6)

    love.graphics.setColor(0.32, 0.42, 0.52, 0.9)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
end

return EnergyBar

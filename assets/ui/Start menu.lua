local StartMenu = {}

local bg = nil
local bgScale = 1
local bgOffsetX = 0
local bgOffsetY = 0

local windowWidth = 0
local windowHeight = 0

local titleFont = nil
local menuFont = nil
local hudFont = nil

local menu = {
    items = { "Start", "Options", "Quit" },
    selected = 1
}

local anim = {
    time = 0
}

local COL = {
    panel = { 0.10, 0.13, 0.17, 0.92 },
    panelEdge = { 0.32, 0.42, 0.52, 0.9 },
    panelGlow = { 0.10, 0.55, 0.60, 0.22 },
    accent = { 0.18, 0.78, 0.78, 1.0 },
    accentDim = { 0.12, 0.50, 0.50, 0.8 },
    amber = { 0.95, 0.65, 0.20, 1.0 },
    red = { 0.85, 0.22, 0.22, 1.0 },
    text = { 0.78, 0.90, 0.95, 1.0 },
    textDim = { 0.55, 0.70, 0.75, 0.9 }
}

local function setColor(col)
    love.graphics.setColor(col[1], col[2], col[3], col[4] or 1)
end

local function drawOutlinedText(font, text, x, y, color, outlineColor)
    love.graphics.setFont(font)
    setColor(outlineColor)
    love.graphics.print(text, x - 2, y)
    love.graphics.print(text, x + 2, y)
    love.graphics.print(text, x, y - 2)
    love.graphics.print(text, x, y + 2)
    setColor(color)
    love.graphics.print(text, x, y)
end

local function drawBolt(x1, y1, x2, y2, segments, amp, time)
    local points = {}
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    local nx = 0
    local ny = 0
    if len > 0 then
        nx = -dy / len
        ny = dx / len
    end

    for i = 0, segments do
        local t = i / segments
        local x = x1 + dx * t
        local y = y1 + dy * t
        local wave = math.sin(t * 12 + time * 5) * amp
        local jitter = love.math.random(-amp * 0.2, amp * 0.2)
        x = x + nx * (wave + jitter)
        y = y + ny * (wave + jitter)
        points[#points + 1] = x
        points[#points + 1] = y
    end
    love.graphics.line(points)
end

function StartMenu:load(cfg)
    bg = cfg.bg
    bgScale = cfg.bgScale
    bgOffsetX = cfg.bgOffsetX
    bgOffsetY = cfg.bgOffsetY
    windowWidth = cfg.windowWidth
    windowHeight = cfg.windowHeight

    titleFont = love.graphics.newFont(46)
    menuFont = love.graphics.newFont(26)
    hudFont = love.graphics.newFont(14)

    titleFont:setFilter("nearest", "nearest")
    menuFont:setFilter("nearest", "nearest")
    hudFont:setFilter("nearest", "nearest")
end

function StartMenu:update(dt)
    anim.time = anim.time + dt
end

function StartMenu:keypressed(key)
    if key == "up" or key == "w" then
        menu.selected = menu.selected - 1
        if menu.selected < 1 then
            menu.selected = #menu.items
        end
    elseif key == "down" or key == "s" then
        menu.selected = menu.selected + 1
        if menu.selected > #menu.items then
            menu.selected = 1
        end
    elseif key == "return" or key == "kpenter" then
        local choice = menu.items[menu.selected]
        if choice == "Start" then
            return "start"
        elseif choice == "Quit" then
            return "quit"
        end
    end

    return nil
end

function StartMenu:draw()
    love.graphics.draw(bg, bgOffsetX, bgOffsetY, 0, bgScale, bgScale)

    setColor({ 0.06, 0.08, 0.10, 0.45 })
    love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)

    local panelX = 70
    local panelY = 130
    local panelW = 440
    local panelH = 460

    setColor(COL.panel)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    setColor(COL.panelEdge)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)

    setColor(COL.panelGlow)
    love.graphics.rectangle("fill", panelX + 12, panelY + 12, panelW - 24, 6, 4, 4)

    local titleX = 780
    local titleY = 40
    drawOutlinedText(titleFont, "ECLIPSE", titleX, titleY, COL.text, { 0.05, 0.09, 0.12, 0.9 })
    drawOutlinedText(titleFont, "PROTOCOL", titleX, titleY + 48, COL.text, { 0.05, 0.09, 0.12, 0.9 })

    local boltY = 560 + math.sin(anim.time * 2.3) * 6
    setColor({ 0.20, 0.85, 0.95, 0.8 })
    love.graphics.setLineWidth(2)
    drawBolt(420, boltY, 1200, boltY - 30, 16, 10, anim.time)
    love.graphics.setLineWidth(1)

    local startY = panelY + 130
    local gap = 70
    love.graphics.setFont(menuFont)

    for i, item in ipairs(menu.items) do
        local y = startY + (i - 1) * gap
        local labelColor = COL.textDim
        if i == menu.selected then
            local pulse = 0.5 + 0.5 * math.sin(anim.time * 4.2)
            setColor({ 0.10, 0.45 + 0.25 * pulse, 0.50 + 0.25 * pulse, 0.25 })
            love.graphics.rectangle("fill", panelX + 30, y - 18, panelW - 60, 44, 8, 8)
            setColor(COL.accent)
            love.graphics.rectangle("line", panelX + 30, y - 18, panelW - 60, 44, 8, 8)
            setColor(COL.text)
            love.graphics.print(">", panelX + 44, y - 10)
            labelColor = COL.text
        end

        setColor(labelColor)
        love.graphics.print(item, panelX + 80, y - 10)
    end

    for y = 0, windowHeight, 4 do
        setColor({ 0, 0, 0, 0.08 })
        love.graphics.line(0, y, windowWidth, y)
    end

    for i = 1, 80 do
        local x = love.math.random(0, windowWidth)
        local y = love.math.random(0, windowHeight)
        setColor({ 0.22, 0.60, 0.65, 0.18 })
        love.graphics.rectangle("fill", x, y, 1, 1)
    end
end

return StartMenu

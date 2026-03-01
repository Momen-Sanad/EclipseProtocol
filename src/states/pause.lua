local AudioSystem = require("src/systems/audio_system")
local StateManager = require("src/core/state_manager")

local PauseState = {}

local windowWidth = 0
local windowHeight = 0

local titleFont = nil
local menuFont = nil
local hudFont = nil

local loaded = false
local view = "main"
local menu = {
    items = { "Resume", "Options", "Victory", "Game Over", "Main Menu" },
    selected = 1
}

local anim = {
    time = 0
}

local musicVolume = 0.8
local volumeStep = 0.05

local COL = {
    panel = { 0.10, 0.13, 0.17, 0.92 },
    panelEdge = { 0.32, 0.42, 0.52, 0.9 },
    panelGlow = { 0.10, 0.55, 0.60, 0.22 },
    accent = { 0.18, 0.78, 0.78, 1.0 },
    accentDim = { 0.12, 0.50, 0.50, 0.8 },
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

local function refreshDimensions()
    local w, h = love.graphics.getDimensions()
    windowWidth = w
    windowHeight = h
end

local function setMusicVolume(value)
    musicVolume = math.max(0, math.min(1, value))
    AudioSystem.setMusicVolume(musicVolume)
end

local function ensureLoaded()
    if loaded then
        return
    end

    refreshDimensions()
    local fontPath = "assets/fonts/Minecraftia-Regular.ttf"
    titleFont = love.graphics.newFont(fontPath, 42)
    menuFont = love.graphics.newFont(fontPath, 26)
    hudFont = love.graphics.newFont(fontPath, 14)

    titleFont:setFilter("nearest", "nearest")
    menuFont:setFilter("nearest", "nearest")
    hudFont:setFilter("nearest", "nearest")

    loaded = true
end

function PauseState.enter(context)
    ensureLoaded()
    view = "main"
    menu.selected = 1
    anim.time = 0
    refreshDimensions()

    if AudioSystem.getMusicVolume then
        musicVolume = AudioSystem.getMusicVolume()
    end
end

function PauseState.update(dt)
    anim.time = anim.time + dt
end

function PauseState.keypressed(key)
    if view == "main" then
        if key == "escape" then
            StateManager.change("transition", "game")
            return nil
        end
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
            if choice == "Resume" then
                StateManager.change("transition", "game")
            elseif choice == "Options" then
                view = "options"
            elseif choice == "Victory" then
                StateManager.change("victory")
            elseif choice == "Game Over" then
                StateManager.change("gameover")
            elseif choice == "Main Menu" then
                StateManager.change("transition", "menu")
            end
        end
        return nil
    end

    if view == "options" then
        if key == "escape" or key == "backspace" then
            view = "main"
            return nil
        end

        if key == "left" or key == "a" then
            setMusicVolume(musicVolume - volumeStep)
        elseif key == "right" or key == "d" then
            setMusicVolume(musicVolume + volumeStep)
        end
    end

    return nil
end

function PauseState.draw()
    StateManager.drawState("game")
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)

    local panelW = 440
    local panelH = 500
    local panelX = math.floor((windowWidth - panelW) / 2)
    local panelY = math.floor((windowHeight - panelH) / 2)

    setColor(COL.panel)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    setColor(COL.panelEdge)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)

    setColor(COL.panelGlow)
    love.graphics.rectangle("fill", panelX + 12, panelY + 12, panelW - 24, 6, 4, 4)

    local titleX = math.floor((windowWidth - titleFont:getWidth("PAUSED")) / 2)
    local titleY = panelY - titleFont:getHeight() - 18
    if titleY < 20 then
        titleY = 20
    end
    drawOutlinedText(titleFont, "PAUSED", titleX, titleY, COL.text, { 0.05, 0.09, 0.12, 0.9 })

    if view == "main" then
        local startY = panelY + 90
        local gap = 58
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

        return
    end

    if view == "options" then
        local contentX = panelX + 40
        local contentY = panelY + 60

        love.graphics.setFont(menuFont)
        setColor(COL.text)
        love.graphics.print("OPTIONS", contentX, contentY - 10)

        setColor(COL.textDim)
        love.graphics.setFont(hudFont)
        love.graphics.print("Controls", contentX, contentY + 36)
        love.graphics.print("W/A/S/D - Move", contentX, contentY + 58)
        love.graphics.print("Space - Dash", contentX, contentY + 78)

        love.graphics.setFont(menuFont)
        setColor(COL.text)
        love.graphics.print("MUSIC VOLUME", contentX, contentY + 120)

        local barW = panelW - 80
        local barH = 16
        local barX = contentX
        local barY = contentY + 160

        setColor(COL.panelEdge)
        love.graphics.rectangle("line", barX, barY, barW, barH, 6, 6)
        setColor(COL.accentDim)
        love.graphics.rectangle("fill", barX, barY, barW * musicVolume, barH, 6, 6)

        local percent = tostring(math.floor(musicVolume * 100 + 0.5)) .. "%"
        love.graphics.setFont(hudFont)
        setColor(COL.textDim)
        love.graphics.print(percent, barX + barW - hudFont:getWidth(percent), barY - 18)
        love.graphics.print("Left/Right to adjust", barX, barY + 24)
        love.graphics.print("Esc to return", barX, barY + 44)
    end
end

return PauseState

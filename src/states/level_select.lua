-- Level selection screen shown between main menu and gameplay.
local StateManager = require("src/core/state_manager")

local LevelSelectState = {}

local bg = nil
local bgScaleX = 1
local bgScaleY = 1
local bgOffsetX = 0
local bgOffsetY = 0

local windowWidth = 0
local windowHeight = 0

local titleFont = nil
local menuFont = nil
local bodyFont = nil

local loaded = false
local selected = 1
local animTime = 0
local levelItems = {}

local FALLBACK_LEVELS = {
    {
        id = "level_1",
        label = "Level 1 - Training Deck",
        description = "Lower threat layout for warm-up runs."
    },
    {
        id = "level_2",
        label = "Level 2 - Core Sector",
        description = "Balanced station pressure."
    },
    {
        id = "level_3",
        label = "Level 3 - Reactor Wing",
        description = "Dense patrols with aggressive hunters."
    }
}

local COL = {
    panel = { 0.10, 0.13, 0.17, 0.92 },
    panelEdge = { 0.32, 0.42, 0.52, 0.9 },
    panelGlow = { 0.10, 0.55, 0.60, 0.22 },
    accent = { 0.18, 0.78, 0.78, 1.0 },
    text = { 0.78, 0.90, 0.95, 1.0 },
    textDim = { 0.55, 0.70, 0.75, 0.9 }
}

local function setColor(col)
    -- Small helper so palette tables can be passed directly.
    love.graphics.setColor(col[1], col[2], col[3], col[4] or 1)
end

local function refreshDimensions()
    -- Keeps background and panel math in sync with current window size.
    local w, h = love.graphics.getDimensions()
    windowWidth = w
    windowHeight = h

    if bg then
        bgScaleX = windowWidth / bg:getWidth()
        bgScaleY = windowHeight / bg:getHeight()
        bgOffsetX = 0
        bgOffsetY = 0
    end
end

local function ensureLoaded()
    -- Lazy-load images/fonts once for this state.
    if loaded then
        return
    end

    bg = love.graphics.newImage("assets/ui/start menu.jpg")
    refreshDimensions()

    local fontPath = "assets/fonts/Minecraftia-Regular.ttf"
    titleFont = love.graphics.newFont(fontPath, 42)
    menuFont = love.graphics.newFont(fontPath, 24)
    bodyFont = love.graphics.newFont(fontPath, 16)

    titleFont:setFilter("nearest", "nearest")
    menuFont:setFilter("nearest", "nearest")
    bodyFont:setFilter("nearest", "nearest")

    loaded = true
end

local function resolveLevels(context)
    -- Uses configured level presets, falling back to hardcoded defaults.
    local presets = context and context.levelPresets
    if type(presets) == "table" and #presets > 0 then
        return presets
    end
    return FALLBACK_LEVELS
end

local function clampSelection()
    -- Wraps selection index so up/down navigation loops cleanly.
    local count = #levelItems
    if count <= 0 then
        selected = 1
        return
    end

    if selected < 1 then
        selected = count
    elseif selected > count then
        selected = 1
    end
end

function LevelSelectState.enter(context)
    -- Refreshes list and applies previously selected level when reopening.
    ensureLoaded()
    refreshDimensions()
    animTime = 0
    levelItems = resolveLevels(context)
    selected = (context and context.selectedLevelIndex) or 1
    clampSelection()
end

function LevelSelectState.update(dt)
    -- Drives small pulse animation used by selected row highlight.
    animTime = animTime + dt
end

function LevelSelectState.keypressed(key, context)
    -- Handles level list navigation and commit/cancel actions.
    if key == "up" or key == "w" then
        selected = selected - 1
        clampSelection()
        return
    end

    if key == "down" or key == "s" then
        selected = selected + 1
        clampSelection()
        return
    end

    if key == "escape" or key == "backspace" then
        StateManager.change("menu")
        return
    end

    if key == "return" or key == "kpenter" then
        local chosen = levelItems[selected]
        if context and chosen then
            context.selectedLevelIndex = selected
            context.selectedLevelId = chosen.id
            context.selectedLevelLabel = chosen.label
        end
        StateManager.change("transition", "game")
    end
end

function LevelSelectState.draw()
    -- Draws background, selection panel, and mission brief text.
    local w, h = love.graphics.getDimensions()
    if w ~= windowWidth or h ~= windowHeight then
        refreshDimensions()
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg, bgOffsetX, bgOffsetY, 0, bgScaleX, bgScaleY)

    local panelW = math.min(860, windowWidth - 120)
    local panelH = math.min(620, windowHeight - 120)
    local panelX = math.floor((windowWidth - panelW) / 2)
    local panelY = math.floor((windowHeight - panelH) / 2)

    setColor(COL.panel)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    setColor(COL.panelEdge)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)

    setColor(COL.panelGlow)
    love.graphics.rectangle("fill", panelX + 12, panelY + 12, panelW - 24, 6, 4, 4)

    love.graphics.setFont(titleFont)
    setColor(COL.text)
    local title = "SELECT LEVEL"
    love.graphics.print(title, math.floor((windowWidth - titleFont:getWidth(title)) / 2), panelY + 30)

    local listX = panelX + 46
    local listY = panelY + 120
    local rowH = 72

    love.graphics.setFont(menuFont)
    for i, item in ipairs(levelItems) do
        local y = listY + (i - 1) * rowH
        local rowW = panelW - 92
        if i == selected then
            local pulse = 0.5 + 0.5 * math.sin(animTime * 4.0)
            setColor({ 0.10, 0.45 + 0.22 * pulse, 0.50 + 0.22 * pulse, 0.25 })
            love.graphics.rectangle("fill", listX, y - 10, rowW, 52, 8, 8)
            setColor(COL.accent)
            love.graphics.rectangle("line", listX, y - 10, rowW, 52, 8, 8)
            setColor(COL.text)
            love.graphics.print(">", listX + 14, y + 2)
            love.graphics.print(item.label or ("Level " .. tostring(i)), listX + 48, y + 2)
        else
            setColor(COL.textDim)
            love.graphics.print(item.label or ("Level " .. tostring(i)), listX + 48, y + 2)
        end
    end

    local chosen = levelItems[selected]
    local desc = ""
    if chosen and chosen.description then
        desc = chosen.description
    end

    local descY = panelY + panelH - 160
    love.graphics.setFont(bodyFont)
    setColor(COL.text)
    love.graphics.print("MISSION BRIEF", listX, descY)
    setColor(COL.textDim)
    love.graphics.printf(desc, listX, descY + 28, panelW - 92, "left")

    setColor(COL.textDim)
    love.graphics.printf("Enter: Confirm level    Esc: Back to main menu", listX, panelY + panelH - 48, panelW - 92, "left")
end

return LevelSelectState

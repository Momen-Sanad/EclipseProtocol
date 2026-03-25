-- Shared result-screen factory for victory and game-over presentations.
local AudioSystem = require("src/systems/audio_system")
local ScoreSystem = require("src/systems/score_system")
local StateManager = require("src/core/state_manager")

local RunResultScreen = {}

local function drawShadowedText(font, text, x, y, color, shadow, alpha)
    love.graphics.setFont(font)
    love.graphics.setColor(shadow[1], shadow[2], shadow[3], (shadow[4] or 1) * alpha)
    love.graphics.print(text, x + 2, y + 2)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
    love.graphics.print(text, x, y)
end

local function drawCenteredText(font, text, x, y, w, h, color, shadow, alpha)
    local textW = font:getWidth(text)
    local textH = font:getHeight()
    local drawX = x + ((w - textW) * 0.5)
    local drawY = y + ((h - textH) * 0.5)
    drawShadowedText(font, text, drawX, drawY, color, shadow, alpha)
end

function RunResultScreen.new(config)
    local cfg = config or {}
    local state = {}

    local bg = nil
    local bgScaleX = 1
    local bgScaleY = 1
    local bgOffsetX = 0
    local bgOffsetY = 0
    local windowWidth = 0
    local windowHeight = 0

    local valueFont = nil
    local statFont = nil
    local actionFont = nil

    local fadeTime = 0
    local fadeDuration = 1.0
    local musicFadeTime = 0
    local musicFadeDuration = 1.0
    local musicTargetVolume = 0.8
    local soundPath = nil
    local summary = nil

    local function ensureAssets()
        if not bg then
            bg = love.graphics.newImage(cfg.backgroundPath)
        end
        if valueFont then
            return
        end

        local fontPath = "assets/fonts/Minecraftia-Regular.ttf"
        valueFont = love.graphics.newFont(fontPath, cfg.valueFontSize or 34)
        statFont = love.graphics.newFont(fontPath, cfg.scoreFontSize or cfg.valueFontSize or 34)
        actionFont = love.graphics.newFont(fontPath, cfg.actionFontSize or 20)

        valueFont:setFilter("nearest", "nearest")
        statFont:setFilter("nearest", "nearest")
        actionFont:setFilter("nearest", "nearest")
    end

    local function refreshBackground()
        local w, h = love.graphics.getDimensions()
        if w == windowWidth and h == windowHeight then
            return
        end

        windowWidth = w
        windowHeight = h

        if bg then
            local bw = bg:getWidth()
            local bh = bg:getHeight()
            bgScaleX = windowWidth / bw
            bgScaleY = windowHeight / bh
            bgOffsetX = 0
            bgOffsetY = 0
        end
    end

    local function toScreenRect(rect)
        local box = rect or {}
        return
            bgOffsetX + ((box.x or 0) * bgScaleX),
            bgOffsetY + ((box.y or 0) * bgScaleY),
            (box.w or 0) * bgScaleX,
            (box.h or 0) * bgScaleY
    end

    local function hasRect(rect)
        return type(rect) == "table" and (rect.w or 0) > 0 and (rect.h or 0) > 0
    end

    local function getActionBounds()
        return toScreenRect(cfg.actionRect or cfg.scoreBoxRect)
    end

    local function resolveSummary(context)
        local current = context and context.runSummary or nil
        if type(current) == "table" and current.result == cfg.result then
            return current
        end
        return ScoreSystem.emptySummary(cfg.result)
    end

    function state.enter(context)
        ensureAssets()
        refreshBackground()
        summary = resolveSummary(context)

        fadeTime = 0
        musicFadeTime = 0
        fadeDuration = (context and context.gameOverTextFadeDuration) or 1.0
        musicFadeDuration = (context and context.gameOverMusicFadeDuration) or 1.0
        musicTargetVolume = (AudioSystem.getMusicVolume and AudioSystem.getMusicVolume()) or 0.8
        soundPath = (context and context[cfg.musicContextKey]) or cfg.defaultMusicPath

        AudioSystem.playMusic(soundPath, { loop = true, volume = 0 })
    end

    function state.update(dt)
        if fadeTime < fadeDuration then
            fadeTime = math.min(fadeDuration, fadeTime + dt)
        end

        if musicFadeTime < musicFadeDuration then
            musicFadeTime = math.min(musicFadeDuration, musicFadeTime + dt)
            local t = 1.0
            if musicFadeDuration > 0 then
                t = musicFadeTime / musicFadeDuration
            end
            AudioSystem.setCurrentMusicVolume(musicTargetVolume * t)
        end
    end

    function state.keypressed(key)
        if key == "return" or key == "kpenter" or key == "space" then
            StateManager.change("transition", "game")
            return
        end
        if key == "escape" then
            StateManager.change("transition", "menu")
            return
        end
    end

    function state.mousepressed(x, y, button)
        if button ~= 1 then
            return
        end

        ensureAssets()
        refreshBackground()
        local bx, by, bw, bh = getActionBounds()
        if x >= bx and x <= (bx + bw) and y >= by and y <= (by + bh) then
            StateManager.change("transition", "game")
        end
    end

    function state.draw(context)
        ensureAssets()
        refreshBackground()

        love.graphics.setColor(1, 1, 1, 1)
        if bg then
            love.graphics.draw(bg, bgOffsetX, bgOffsetY, 0, bgScaleX, bgScaleY)
        end

        local alpha = 1.0
        if fadeDuration > 0 then
            alpha = math.max(0, math.min(1, fadeTime / fadeDuration))
        end

        summary = resolveSummary(context)

        local valueColor = cfg.valueColor or { 0.92, 0.98, 1.0, 1.0 }
        local valueShadow = cfg.valueShadow or { 0.04, 0.08, 0.12, 0.9 }
        local actionColor = cfg.actionColor or cfg.hintColor or { 0.72, 0.80, 0.86, 0.95 }
        local actionShadow = cfg.actionShadow or cfg.hintShadow or { 0.02, 0.04, 0.06, 0.9 }

        if hasRect(cfg.timeValueRect or cfg.leftValueRect) then
            local timeX, timeY, timeW, timeH = toScreenRect(cfg.timeValueRect or cfg.leftValueRect)
            drawCenteredText(valueFont, summary.formattedTime, timeX, timeY, timeW, timeH, valueColor, valueShadow, alpha)
        end

        if hasRect(cfg.scoreValueRect) then
            local scoreX, scoreY, scoreW, scoreH = toScreenRect(cfg.scoreValueRect)
            drawCenteredText(statFont, summary.formattedScore, scoreX, scoreY, scoreW, scoreH, valueColor, valueShadow, alpha)
        end

        if hasRect(cfg.cellsValueRect or cfg.rightValueRect) then
            local cellsX, cellsY, cellsW, cellsH = toScreenRect(cfg.cellsValueRect or cfg.rightValueRect)
            drawCenteredText(valueFont, summary.formattedCells, cellsX, cellsY, cellsW, cellsH, valueColor, valueShadow, alpha)
        end

        if hasRect(cfg.actionRect or cfg.scoreBoxRect) then
            local boxX, boxY, boxW, boxH = getActionBounds()
            drawCenteredText(
                actionFont,
                cfg.actionLabel or "PLAY AGAIN",
                boxX,
                boxY,
                boxW,
                boxH,
                actionColor,
                actionShadow,
                alpha
            )
        end
    end

    return state
end

return RunResultScreen

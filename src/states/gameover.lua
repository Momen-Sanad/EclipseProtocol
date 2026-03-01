local AudioSystem = require("src/systems/audio_system")
local StateManager = require("src/core/state_manager")

local GameOverState = {}

local bg = nil
local bgScaleX = 1
local bgScaleY = 1
local bgOffsetX = 0
local bgOffsetY = 0
local windowWidth = 0
local windowHeight = 0

local font = nil
local fadeTime = 0
local fadeDuration = 1.0
local promptFont = nil
local musicFadeTime = 0
local musicFadeDuration = 1.0
local musicTargetVolume = 0.8
local soundPath = nil
local retryScale = 3
local retryYRatio = 0.86

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

local function ensureFont()
    if font then
        return
    end
    font = love.graphics.newFont("assets/fonts/Minecraftia-Regular.ttf", 72)
    font:setFilter("nearest", "nearest")
    promptFont = love.graphics.newFont("assets/fonts/Minecraftia-Regular.ttf", 18)
    promptFont:setFilter("nearest", "nearest")
end

local function getRetryBounds(w, h)
    local label = "RETRY"
    local labelW = promptFont:getWidth(label) * retryScale
    local labelH = promptFont:getHeight() * retryScale
    local x = math.floor((w - labelW) / 2)
    local y = math.floor(h * retryYRatio)
    return x, y, labelW, labelH
end

function GameOverState.enter(context)
    ensureFont()
    if not bg then
        bg = love.graphics.newImage("assets/Game Over.jpg")
    end
    refreshBackground()
    fadeTime = 0
    musicFadeTime = 0
    fadeDuration = (context and context.gameOverTextFadeDuration) or 1.0
    musicFadeDuration = (context and context.gameOverMusicFadeDuration) or 1.0
    musicTargetVolume = (AudioSystem.getMusicVolume and AudioSystem.getMusicVolume()) or 0.8
    soundPath = (context and context.gameOverSoundPath) or "assets/audio/sfx/Game Over.mp3"

    AudioSystem.playMusic(soundPath, { loop = true, volume = 0 })
end

function GameOverState.update(dt)
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

function GameOverState.keypressed(key)
    if key == "return" or key == "kpenter" or key == "space" then
        StateManager.change("transition", "game")
        return
    end
    if key == "escape" then
        StateManager.change("transition", "menu")
        return
    end
end

function GameOverState.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    ensureFont()
    refreshBackground()
    local w = windowWidth
    local h = windowHeight
    local bx, by, bw, bh = getRetryBounds(w, h)
    if x >= bx and x <= (bx + bw) and y >= by and y <= (by + bh) then
        StateManager.change("transition", "game")
    end
end

function GameOverState.draw()
    ensureFont()
    refreshBackground()
    local w = windowWidth
    local h = windowHeight
    love.graphics.setColor(1, 1, 1, 1)
    if bg then
        love.graphics.draw(bg, bgOffsetX, bgOffsetY, 0, bgScaleX, bgScaleY)
    end

    local alpha = 1.0
    if fadeDuration > 0 then
        alpha = math.max(0, math.min(1, fadeTime / fadeDuration))
    end

    love.graphics.setFont(promptFont)
    local label = "RETRY"
    local lx, ly = getRetryBounds(w, h)
    love.graphics.setColor(0.95, 0.25, 0.25, alpha)
    love.graphics.print(label, lx, ly, 0, retryScale, retryScale)
end

return GameOverState

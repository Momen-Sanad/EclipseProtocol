local AudioSystem = require("src/systems/audio_system")
local StateManager = require("src/core/state_manager")

local GameOverState = {}

local font = nil
local fadeTime = 0
local fadeDuration = 1.0
local promptFont = nil
local musicFadeTime = 0
local musicFadeDuration = 1.0
local musicTargetVolume = 0.8
local soundPath = nil

local function ensureFont()
    if font then
        return
    end
    font = love.graphics.newFont("assets/fonts/Minecraftia-Regular.ttf", 72)
    font:setFilter("nearest", "nearest")
    promptFont = love.graphics.newFont("assets/fonts/Minecraftia-Regular.ttf", 18)
    promptFont:setFilter("nearest", "nearest")
end

function GameOverState.enter(context)
    ensureFont()
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

function GameOverState.draw()
    ensureFont()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setFont(font)
    local alpha = 1.0
    if fadeDuration > 0 then
        alpha = math.max(0, math.min(1, fadeTime / fadeDuration))
    end
    love.graphics.setColor(0.90, 0.20, 0.20, alpha)
    local text = "GAME OVER"
    local x = math.floor((w - font:getWidth(text)) / 2)
    local y = math.floor((h - font:getHeight()) / 2)
    love.graphics.print(text, x, y)

    love.graphics.setFont(promptFont)
    love.graphics.setColor(0.78, 0.90, 0.95, alpha)
    local prompt = "PRESS ENTER TO RETRY"
    local px = math.floor((w - promptFont:getWidth(prompt)) / 2)
    local py = y + font:getHeight() + 26
    love.graphics.print(prompt, px, py)
    local prompt2 = "ESC TO MAIN MENU"
    local px2 = math.floor((w - promptFont:getWidth(prompt2)) / 2)
    love.graphics.print(prompt2, px2, py + 24)
end

return GameOverState

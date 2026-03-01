local InputSystem = require("src/systems/input_system")
local MovementSystem = require("src/systems/movement_system")
local AudioSystem = require("src/systems/audio_system")
local MenuState = require("src/states/menu")
local SpriteSheet = require("src/utils/sprite_sheet")

WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

VIRTUAL_WIDTH = 2
VIRTUAL_HEIGHT = 1

PLAYER_SIZE = 35

local state = "menu"

local Player = {}

local BG = nil
local PlayerSprite = nil
local PlayerFrames = nil
local BG_SCALE = 1
local BG_OFFSET_X = 0
local BG_OFFSET_Y = 0
local MENU_MUSIC_PATH = "assets/audio/music/StartMenu.mp3"
local GAME_MUSIC_PATH = nil
local TRANSITION_DURATION = 2.5
local FADE_DURATION = 0.5
local transitionTime = 0
local transitionMusicStartVolume = 0.8

local function startTransitionToGame()
    transitionTime = TRANSITION_DURATION
    state = "transition"
    if AudioSystem.getMusicVolume then
        transitionMusicStartVolume = AudioSystem.getMusicVolume()
    end
end

local function updateTransition(dt)
    transitionTime = transitionTime - dt
    local elapsed = TRANSITION_DURATION - transitionTime
    local fadeTime = math.min(FADE_DURATION, TRANSITION_DURATION / 2)
    if fadeTime > 0 then
        if elapsed <= fadeTime then
            local t = math.min(1, elapsed / fadeTime)
            AudioSystem.setCurrentMusicVolume(transitionMusicStartVolume * (1 - t))
        else
            AudioSystem.setCurrentMusicVolume(0)
        end
    end
    if transitionTime <= 0 then
        transitionTime = 0
        state = "game"
        AudioSystem.playMusic(GAME_MUSIC_PATH)
    end
end

local function drawGame()
    
    love.graphics.setColor(1, 1, 1)    
    love.graphics.draw(BG, BG_OFFSET_X, BG_OFFSET_Y, 0, BG_SCALE, BG_SCALE)
    
    love.graphics.setColor(1, 1, 1)
    local frame = Player.frames and Player.frames[Player.frameIndex]
    if frame then
        love.graphics.draw(
            Player.sprite,
            frame.quad,
            Player.x,
            Player.y,
            0,
            Player.scale,
            Player.scale,
            frame.w / 2,
            frame.h / 2
        )
    else
        love.graphics.draw(Player.sprite, Player.x, Player.y)
    end

end

local function drawTransition()
    local w, h = love.graphics.getDimensions()
    local elapsed = TRANSITION_DURATION - transitionTime
    local fadeTime = math.min(FADE_DURATION, TRANSITION_DURATION / 2)
    local holdTime = math.max(0, TRANSITION_DURATION - (fadeTime * 2))
    local alpha = 1

    if elapsed < fadeTime then
        MenuState.draw()
        alpha = elapsed / fadeTime
    elseif elapsed < (fadeTime + holdTime) then
        MenuState.draw()
        alpha = 1
    else
        drawGame()
        local t = (elapsed - fadeTime - holdTime) / fadeTime
        alpha = 1 - t
    end

    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
end

function love.load()
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, { fullscreen = true })
    love.graphics.setDefaultFilter("linear", "linear", 16)
    love.math.setRandomSeed(os.time())

    BG = love.graphics.newImage("assets/background.png")
    local sheet = SpriteSheet.buildFrames("assets/sprites/player/Robot.png")
    PlayerSprite = sheet.image
    PlayerFrames = sheet.frames
    AudioSystem.init({
        music = MENU_MUSIC_PATH,
        musicVolume = 0.8,
        sfxVolume = 0.9
    })

    local bgW = BG:getWidth()
    local bgH = BG:getHeight()
    BG_SCALE = math.max(WINDOW_WIDTH / bgW, WINDOW_HEIGHT / bgH)
    BG_OFFSET_X = (WINDOW_WIDTH - bgW * BG_SCALE) / 2
    BG_OFFSET_Y = (WINDOW_HEIGHT - bgH * BG_SCALE) / 2

    local maxW = 0
    local maxH = 0
    for _, frame in ipairs(PlayerFrames) do
        if frame.w > maxW then
            maxW = frame.w
        end
        if frame.h > maxH then
            maxH = frame.h
        end
    end
    local baseSize = math.max(1, math.max(maxW, maxH))
    local drawScale = PLAYER_SIZE / baseSize

    Player = {
        x = WINDOW_WIDTH / 2,
        y = WINDOW_HEIGHT / 2,
        speed = 300,
        sprite = PlayerSprite,
        frames = PlayerFrames,
        frameIndex = 1,
        frameTimer = 0,
        frameDuration = 0.12,
        scale = drawScale
    }
    MenuState.load({
        windowWidth = WINDOW_WIDTH,
        windowHeight = WINDOW_HEIGHT,
        bg = BG,
        bgScale = BG_SCALE,
        bgOffsetX = BG_OFFSET_X,
        bgOffsetY = BG_OFFSET_Y
    })
end

function love.update(dt)
    if state == "menu" then
        MenuState.update(dt)
    elseif state == "transition" then
        updateTransition(dt)
    elseif state == "game" then

        MovementSystem.update(
            Player,
            InputSystem,
            dt,
            {
                minX = 8,
                minY = 8,
                maxX = WINDOW_WIDTH - PLAYER_SIZE,
                maxY = WINDOW_HEIGHT - PLAYER_SIZE
            }
        )

        if Player.frames and #Player.frames > 1 then
            Player.frameTimer = Player.frameTimer + dt
            if Player.frameTimer >= Player.frameDuration then
                Player.frameTimer = Player.frameTimer - Player.frameDuration
                Player.frameIndex = (Player.frameIndex % #Player.frames) + 1
            end
        end
    end

    InputSystem.update()
end

function love.keyreleased(key)
    InputSystem.keyreleased(key)
end

function love.keypressed(key)

     InputSystem.keypressed(key)
    if key == "escape" then
        if state == "game" then
            state = "menu"
            AudioSystem.playMusic(MENU_MUSIC_PATH)
            return
        end
    end

    if state == "menu" then
        if MenuState then
            local action = MenuState.keypressed(key)
            if action == "start" then
                startTransitionToGame()
            elseif action == "quit" then
                love.event.quit()
            end
        end
    end
end


function love.draw()
    if state == "menu" then
        MenuState.draw()
    elseif state == "transition" then
        drawTransition()
    else
        drawGame()
    end
end

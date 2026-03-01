local InputSystem = require("src/systems/input_system")
local MovementSystem = require("src/systems/movement_system")
local AudioSystem = require("src/systems/audio_system")

WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

VIRTUAL_WIDTH = 2
VIRTUAL_HEIGHT = 1

PLAYER_SIZE = 35

local state = "menu"

local Player = {}

local BG = nil
local Parrot = nil
local BG_SCALE = 1
local BG_OFFSET_X = 0
local BG_OFFSET_Y = 0
local MENU_MUSIC_PATH = "assets/audio/music/StartMenu.mp3"
local GAME_MUSIC_PATH = nil

local StartMenu = nil

function love.load()
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, { fullscreen = true })
    love.graphics.setDefaultFilter("linear", "linear", 16)
    love.math.setRandomSeed(os.time())

    BG = love.graphics.newImage("assets/background.png")
    Parrot = love.graphics.newImage("assets/sprites/parrot.png")
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


    Player = {
        x = WINDOW_WIDTH / 2,
        y = WINDOW_HEIGHT / 2,
        speed = 300,
        sprite = Parrot,
        
        quad = love.graphics.newQuad(
            0, 0,              -- x, y inside the image
            100, 100,          -- width, height of the rectangle
            100,
            100
        )
    }
    StartMenu = love.filesystem.load("assets/ui/Start menu.lua")()
    StartMenu:load({
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
        StartMenu:update(dt)
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
        else
            love.event.quit()
        end
        return
    end

    if state == "menu" then
        if(StartMenu) then 
            local action = StartMenu:keypressed(key)
            if action == "start" then
                state = "game"
                AudioSystem.playMusic(GAME_MUSIC_PATH)
            elseif action == "quit" then
                love.event.quit()
            end
        end
    end
end

local function drawGame()
    
    love.graphics.setColor(1, 1, 1)    
    love.graphics.draw(BG, BG_OFFSET_X, BG_OFFSET_Y, 0, BG_SCALE, BG_SCALE)
    
    love.graphics.setColor(1, 1, 1)

    love.graphics.draw(
        Player.sprite,
        Player.quad,
        Player.x,
        Player.y,
        0,                 -- rotation
        0.5, 0.5,              -- scale
        25, 25             -- origin (center of the quad)
    )

end

function love.draw()
    if state == "menu" then
        StartMenu:draw()
    else
        drawGame()
    end
end

WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

VIRTUAL_WIDTH = 2
VIRTUAL_HEIGHT = 1

PLAYER_SIZE = 35

local state = "menu"

local Player = {}
local Speed = 180

local BG = nil
local Parrot = nil
local BG_SCALE = 1
local BG_OFFSET_X = 0
local BG_OFFSET_Y = 0

local StartMenu = nil

function love.load()
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
    love.graphics.setDefaultFilter("linear", "linear", 16)
    love.math.setRandomSeed(os.time())

    BG = love.graphics.newImage("assets/background.png")
    Parrot = love.graphics.newImage("assets/sprites/parrot.png")

    local bgW = BG:getWidth()
    local bgH = BG:getHeight()
    BG_SCALE = math.max(WINDOW_WIDTH / bgW, WINDOW_HEIGHT / bgH)
    BG_OFFSET_X = (WINDOW_WIDTH - bgW * BG_SCALE) / 2
    BG_OFFSET_Y = (WINDOW_HEIGHT - bgH * BG_SCALE) / 2

    Player.x = WINDOW_WIDTH / 2
    Player.y = WINDOW_HEIGHT / 2
    Player.sprite = Parrot

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
        if love.keyboard.isDown("a") and Player.x > PLAYER_SIZE then
            Player.x = Player.x - Speed * dt
        end
        if love.keyboard.isDown("d") and Player.x < WINDOW_WIDTH - PLAYER_SIZE then
            Player.x = Player.x + Speed * dt
        end
        if love.keyboard.isDown("w") and Player.y > PLAYER_SIZE then
            Player.y = Player.y - Speed * dt
        end
        if love.keyboard.isDown("s") and Player.y < WINDOW_HEIGHT - PLAYER_SIZE then
            Player.y = Player.y + Speed * dt
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        if state == "game" then
            state = "menu"
        else
            love.event.quit()
        end
        return
    end

    if state == "menu" then
        local action = StartMenu:keypressed(key)
        if action == "start" then
            state = "game"
        elseif action == "quit" then
            love.event.quit()
        end
    end
end

local function drawGame()
    love.graphics.draw(BG, BG_OFFSET_X, BG_OFFSET_Y, 0, BG_SCALE, BG_SCALE)
    love.graphics.draw(Player.sprite, Player.x, Player.y, 0, 0.5, 0.5, 65, 65)
end

function love.draw()
    if state == "menu" then
        StartMenu:draw()
    else
        drawGame()
    end
end

require "src/input"
WINDOW_WIDTH = 800
WINDOW_HEIGHT = 600

-- VIRTUAL_WIDTH = 2
-- VIRTUAL_HEIGHT = 1

function love.keypressed(key)
    Input.keypressed(key)
end

function love.keyreleased(key)
    Input.keyreleased(key)
end

PLAYER_SIZE = 55

function love.load()

    Player = {}
    Player.x = 400
    Player.y = 300
    Player.width = 50
    Player.height = 50

    Player.Speed = 10

    Box = {}
    Box.x = 500
    Box.y = 300
    Box.width = 90
    Box.height = 90

    Coins = {}

    Parrot = love.graphics.newImage("assets/sprites/parrot.png")
    BG = love.graphics.newImage("assets/background.png")

    Player.sprite = Parrot;

    Score = 0

    for i = 1, 10 do
        SpawnCoin()
    end
end

function love.update()
    
    local moveX, moveY = Input.getMoveDir()

    if moveX < 0 and Player.x > 8 then
        Player.x = Player.x - Player.Speed
    elseif moveX > 0 and Player.x < WINDOW_WIDTH - PLAYER_SIZE then
        Player.x = Player.x + Player.Speed
    end

    if moveY < 0 and Player.y > 8 then
        Player.y = Player.y - Player.Speed
    elseif moveY > 0 and Player.y < WINDOW_HEIGHT - PLAYER_SIZE then
        Player.y = Player.y + Player.Speed
    end

    if Input.quitRequested() then
        love.event.quit()
    end

    for i = #Coins, 1, -1 do
        local coin = Coins[i]

        if CheckCollision(
            Player.x, Player.y, Player.width, Player.height,
            coin.x, coin.y, coin.width, coin.height
        ) then
            table.remove(Coins, i)
            Score = Score + 1
        end
    end
    Input.update()
end

function love.draw()

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(BG, 0, 0)
    -- love.graphics.setColor(0, 0.5, 1)

    love.graphics.setColor(0, 1, 1)
    love.graphics.rectangle("fill", Player.x, Player.y, Player.width, Player.height)

     if CheckCollision(
        Player.x, Player.y, Player.width, Player.height,
        Box.x, Box.y, Box.width, Box.height
    ) then
        love.graphics.setColor(0, 1, 0) -- green
    else
        love.graphics.setColor(1, 1, 1) 
    end

    love.graphics.rectangle("fill", Box.x, Box.y, Box.width, Box.height)

    for i, coin in ipairs(Coins) do

        -- if CheckCollision(
        --     Player.x, Player.y, Player.width, Player.height,
        --     coin.x, coin.y, coin.width, coin.height
        -- ) then

        --     table.remove(Coins, i)
        
        -- end

        love.graphics.setColor(1, 1, 0) 
        love.graphics.rectangle("fill", coin.x, coin.y, coin.width, coin.height)
    end
    
    love.graphics.setColor(1, 1, 1)
    -- love.graphics.print("Score: " ..(5 - #Coins), 10, 10)
    love.graphics.print("Score: " ..(Score), 10, 10)
    -- love.graphics.draw(Player.sprite, Player.x, Player.y, 0, 0.5, 0.5, 70, 70)

    love.graphics.setColor(1, 1, 1)

end

-- AABB collision checker
function CheckCollision(x1, y1, width1, height1, x2, y2, width2, height2)
    return x1 < x2 + width2  and
           x2 < x1 + width1  and
           y1 < y2 + height2 and
           y2 < y1 + height1
    
end

function SpawnCoin()
    local coin = {}
    coin.x = love.math.random(0, WINDOW_WIDTH - 20)
    coin.y = love.math.random(0, WINDOW_HEIGHT - 20)
    coin.width = 20
    coin.height = 20

    table.insert(Coins, coin)
end
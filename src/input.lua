-- WINDOW_WIDTH = 1280
-- WINDOW_HEIGHT = 720

-- VIRTUAL_WIDTH = 2
-- VIRTUAL_HEIGHT = 1

-- PLAYER_SIZE = 35

-- function love.load()

--     love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)

--     Player = {}
--     Player.x = WINDOW_WIDTH / 2
--     Player.y = WINDOW_HEIGHT / 2
--     Speed = 10

--     love.graphics.setDefaultFilter("linear", "linear", 16)

--     BG = love.graphics.newImage("assets/background.png")
--     Parrot = love.graphics.newImage("assets/sprites/parrot.png")

--     Player.sprite = Parrot;
-- end

-- function love.update()
    
--     if love.keyboard.isDown("a") and Player.x > PLAYER_SIZE then
--         Player.x = Player.x - Speed
--     end

--     if love.keyboard.isDown("d") and Player.x < WINDOW_WIDTH - PLAYER_SIZE then
--         Player.x = Player.x + Speed
--     end

--     if love.keyboard.isDown("w") and Player.y > PLAYER_SIZE then
--         Player.y = Player.y - Speed
--     end

--     if love.keyboard.isDown("s") and Player.y < WINDOW_HEIGHT - PLAYER_SIZE then
--         Player.y = Player.y + Speed
--     end

--     if love.keyboard.isDown("escape") then
--         love.event.quit()
--     end
-- end

-- function love.draw()

--     love.graphics.draw(BG, 0, 0)
--     love.graphics.draw(Player.sprite, Player.x, Player.y, 0, 0.5, 0.5, 65, 65)
    
-- end

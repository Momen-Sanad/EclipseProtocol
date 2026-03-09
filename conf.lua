-- LÖVE startup configuration applied before `main.lua` runs.
function love.conf(t)
    -- Borderless fullscreen at desktop resolution keeps aspect handling simple in-game.
    t.window.fullscreen = true
    t.window.fullscreentype = "desktop"
    t.window.resizable = false
end

-- Compatibility adapter: legacy "game" state forwards to canonical play state.
local PlayState = require("src/states/play")

local GameState = {}

function GameState.preload(context)
    return PlayState.preload(context)
end

function GameState.enter(context, prevName)
    return PlayState.enter(context, prevName)
end

function GameState.update(dt, context)
    return PlayState.update(dt, context)
end

function GameState.draw(context)
    return PlayState.draw(context)
end

function GameState.keypressed(key)
    return PlayState.keypressed(key)
end

function GameState.keyreleased(key)
    return PlayState.keyreleased(key)
end

function GameState.exit(context, nextName)
    return PlayState.exit(context, nextName)
end

return GameState

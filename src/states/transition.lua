-- Simple fade transition that bridges two registered states and manages music handoff.
local AudioSystem = require("src/systems/audio_system")
local StateManager = require("src/core/state_manager")

local TransitionState = {}

local timeLeft = 0
local duration = 2.5
local fadeDuration = 0.5
local fromState = "menu"
local toState = "game"

function TransitionState.enter(context, prevName, nextName)
    -- Store both endpoints so draw() can render the outgoing state before the swap completes.
    duration = context.transitionDuration or 2.5
    fadeDuration = context.fadeDuration or 0.5
    timeLeft = duration
    fromState = prevName or "menu"
    toState = nextName or "game"

    -- Transition screens should be silent until the destination state takes over.
    if AudioSystem.stopAll then
        AudioSystem.stopAll()
    else
        AudioSystem.stopMusic()
    end

    local nextState = StateManager.getState(toState)
    if nextState and nextState.preload then
        nextState.preload(context)
    end
end

function TransitionState.update(dt, context)
    timeLeft = timeLeft - dt

    if timeLeft <= 0 then
        timeLeft = 0
        StateManager.change(toState)
        if toState == "game" and context.gameMusicPath then
            -- Gameplay music starts only after the transition completes.
            AudioSystem.playMusic(context.gameMusicPath)
        end
    end
end

function TransitionState.draw(context)
    -- Fade to black, hold briefly, then reveal the destination state's first frame.
    local w, h = love.graphics.getDimensions()
    local elapsed = duration - timeLeft
    local fadeTime = math.min(fadeDuration, duration / 2)
    local holdTime = math.max(0, duration - (fadeTime * 2))
    local alpha = 1

    if elapsed < fadeTime then
        StateManager.drawState(fromState)
        alpha = elapsed / fadeTime
    elseif elapsed < (fadeTime + holdTime) then
        StateManager.drawState(fromState)
        alpha = 1
    else
        StateManager.drawState(toState)
        local t = (elapsed - fadeTime - holdTime) / fadeTime
        alpha = 1 - t
    end

    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
end

return TransitionState

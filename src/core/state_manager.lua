-- Lightweight state router that shares one context table across all screens.
local StateManager = {
    states = {},
    current = nil,
    currentName = nil,
    context = {}
}

function StateManager.init(context)
    StateManager.context = context or {}
end

function StateManager.register(name, state)
    StateManager.states[name] = state
end

function StateManager.getState(name)
    return StateManager.states[name]
end

function StateManager.getCurrentName()
    return StateManager.currentName
end

function StateManager.change(name, ...)
    local nextState = StateManager.states[name]
    if not nextState then
        return
    end

    -- Exit the previous state before entering the next one so transitions stay ordered.
    local prevName = StateManager.currentName
    if StateManager.current and StateManager.current.exit then
        StateManager.current.exit(StateManager.context, name)
    end

    StateManager.current = nextState
    StateManager.currentName = name
    if nextState.enter then
        nextState.enter(StateManager.context, prevName, ...)
    end
end

function StateManager.update(dt)
    if StateManager.current and StateManager.current.update then
        StateManager.current.update(dt, StateManager.context)
    end
end

function StateManager.draw()
    if StateManager.current and StateManager.current.draw then
        StateManager.current.draw(StateManager.context)
    end
end

function StateManager.drawState(name)
    -- Used by transition/pause screens when they need another state's visual output.
    local state = StateManager.states[name]
    if state and state.draw then
        state.draw(StateManager.context)
    end
end

function StateManager.keypressed(key)
    if StateManager.current and StateManager.current.keypressed then
        return StateManager.current.keypressed(key, StateManager.context)
    end
    return nil
end

function StateManager.keyreleased(key)
    if StateManager.current and StateManager.current.keyreleased then
        StateManager.current.keyreleased(key, StateManager.context)
    end
end

function StateManager.mousepressed(x, y, button, istouch, presses)
    if StateManager.current and StateManager.current.mousepressed then
        StateManager.current.mousepressed(x, y, button, istouch, presses, StateManager.context)
    end
end

return StateManager

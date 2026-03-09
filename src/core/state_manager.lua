-- Lightweight state router that shares one context table across all screens.
local StateManager = {
    states = {},
    current = nil,
    currentName = nil,
    context = {}
}

function StateManager.init(context)
    -- Shared mutable context passed to all states.
    StateManager.context = context or {}
end

function StateManager.register(name, state)
    -- Registers a state module under a routing key.
    StateManager.states[name] = state
end

function StateManager.getState(name)
    -- Returns a registered state table by name.
    return StateManager.states[name]
end

function StateManager.getCurrentName()
    -- Exposes the currently active state's routing key.
    return StateManager.currentName
end

function StateManager.change(name, ...)
    -- Performs ordered state swap: exit old state, then enter new state.
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
    -- Delegates per-frame logic to the active state.
    if StateManager.current and StateManager.current.update then
        StateManager.current.update(dt, StateManager.context)
    end
end

function StateManager.draw()
    -- Delegates rendering to the active state.
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
    -- Returns handler result when states need to consume input explicitly.
    if StateManager.current and StateManager.current.keypressed then
        return StateManager.current.keypressed(key, StateManager.context)
    end
    return nil
end

function StateManager.keyreleased(key)
    -- Forwards key release events to the active state.
    if StateManager.current and StateManager.current.keyreleased then
        StateManager.current.keyreleased(key, StateManager.context)
    end
end

function StateManager.mousepressed(x, y, button, istouch, presses)
    -- Forwards mouse press events to the active state.
    if StateManager.current and StateManager.current.mousepressed then
        StateManager.current.mousepressed(x, y, button, istouch, presses, StateManager.context)
    end
end

return StateManager

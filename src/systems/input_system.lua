-- Input buffer that separates held keys from one-frame button presses.
InputSystem = {}

InputSystem.keysHeld = {}
InputSystem.keysPressed = {}

-- callbacks forward here
function InputSystem.keypressed(key)
    InputSystem.keysHeld[key] = true
    InputSystem.keysPressed[key] = true
end

function InputSystem.keyreleased(key)
    InputSystem.keysHeld[key] = false
end

-- Intention getters
function InputSystem.getMoveDir()
    -- Convert raw WASD state into a normalized intent vector consumed by movement code.
    local x, y = 0, 0

    if InputSystem.keysHeld["a"] then x = x - 1 end
    if InputSystem.keysHeld["d"] then x = x + 1 end
    if InputSystem.keysHeld["w"] then y = y - 1 end
    if InputSystem.keysHeld["s"] then y = y + 1 end

    return x, y
end

function InputSystem.dashPressed()
    return InputSystem.keysPressed["space"] == true
end

function InputSystem.interactPressed()
    return InputSystem.keysPressed["return"] == true or InputSystem.keysPressed["kpenter"] == true
end

function InputSystem.quitRequested()
    return InputSystem.keysPressed["escape"] == true
end

-- Clear pressed state once per frame
function InputSystem.update()
    -- Edge-triggered actions like dash and pause should only fire once per press.
    InputSystem.keysPressed = {}
end

return InputSystem

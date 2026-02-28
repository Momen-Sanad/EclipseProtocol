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
    local x, y = 0, 0

    if InputSystem.keysHeld["a"] then x = x - 1 end
    if InputSystem.keysHeld["d"] then x = x + 1 end
    if InputSystem.keysHeld["w"] then y = y - 1 end
    if InputSystem.keysHeld["s"] then y = y + 1 end

    return x, y
end

function InputSystem.quitRequested()
    return InputSystem.keysPressed["escape"] == true
end

-- Clear pressed state once per frame
function InputSystem.update()
    InputSystem.keysPressed = {}
end

return InputSystem
Input = {}

Input.keysHeld = {}
Input.keysPressed = {}

function Input.keypressed(key)
    Input.keysHeld[key] = true
    Input.keysPressed[key] = true
end

function Input.keyreleased(key)
    Input.keysHeld[key] = false
end

function Input.update()
    -- clear pressed keys at end of frame
    Input.keysPressed = {}
end

function Input.getMoveDir()
    local x, y = 0, 0

    if Input.keysHeld["a"] then x = x - 1 end
    if Input.keysHeld["d"] then x = x + 1 end
    if Input.keysHeld["w"] then y = y - 1 end
    if Input.keysHeld["s"] then y = y + 1 end

    return x, y
end

function Input.quitRequested()
    return Input.keysPressed["escape"] == true
end
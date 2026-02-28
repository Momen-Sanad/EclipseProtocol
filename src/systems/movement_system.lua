local MovementSystem = {}

function MovementSystem.update(player, input, dt, bounds)
    local moveX, moveY = input.getMoveDir()

    if moveX ~= 0 then
        player.x = player.x + moveX * player.speed * dt
    end

    if moveY ~= 0 then
        player.y = player.y + moveY * player.speed * dt
    end

    -- Window bounds
    if bounds then
        player.x = math.max(bounds.minX, math.min(player.x, bounds.maxX))
        player.y = math.max(bounds.minY, math.min(player.y, bounds.maxY))
    end
end

return MovementSystem
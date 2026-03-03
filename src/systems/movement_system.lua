local AudioSystem = require("src/systems/audio_system")

local MovementSystem = {}

function MovementSystem.update(player, input, dt, bounds)
    local moveX, moveY = 0, 0
    if input and input.getMoveDir then
        moveX, moveY = input.getMoveDir()
    end

    local dashPressed = input and input.dashPressed and input.dashPressed() or false

    if player then
        if moveX ~= 0 or moveY ~= 0 then
            player.lastMoveX = moveX
            player.lastMoveY = moveY
        end

        if player.dashCooldownTimer and player.dashCooldownTimer > 0 then
            player.dashCooldownTimer = math.max(0, player.dashCooldownTimer - dt)
        end

        if dashPressed and not player.isDashing and (player.dashCooldownTimer or 0) <= 0 then
            local dirX, dirY = moveX, moveY
            if dirX == 0 and dirY == 0 then
                dirX = player.lastMoveX or 0
                dirY = player.lastMoveY or 0
            end
            if dirX ~= 0 or dirY ~= 0 then
                local len = math.sqrt(dirX * dirX + dirY * dirY)
                dirX = dirX / len
                dirY = dirY / len
                player.isDashing = true
                player.dashTimer = player.dashDuration or 0.18
                player.dashDirX = dirX
                player.dashDirY = dirY
                player.dashCooldownTimer = player.dashCooldown or 0.35
                AudioSystem.playSfx(player.dashSoundPath or "assets/audio/sfx/Dash.mp3")
            end
        end
    end

    local speed = player and player.speed or 0
    local finalX, finalY = moveX, moveY

    if player and player.isDashing then
        finalX = player.dashDirX or finalX
        finalY = player.dashDirY or finalY
        speed = player.dashSpeed or (player.speed * 2.5)
        player.dashTimer = (player.dashTimer or 0) - dt
        if player.dashTimer <= 0 then
            player.isDashing = false
            player.dashTimer = 0
        end
    end

    if player then
        player.moveX = finalX
        player.moveY = finalY
        player.isMoving = (finalX ~= 0 or finalY ~= 0) or player.isDashing
    end

    if finalX ~= 0 then
        player.x = player.x + finalX * speed * dt
    end

    if finalY ~= 0 then
        player.y = player.y + finalY * speed * dt
    end

    -- Window bounds
    if bounds then
        player.x = math.max(bounds.minX, math.min(player.x, bounds.maxX))
        player.y = math.max(bounds.minY, math.min(player.y, bounds.maxY))
    end
end

return MovementSystem
